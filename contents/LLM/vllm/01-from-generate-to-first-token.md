# vLLM 源码导读：从 `generate()` 到第一个 Token

> 系列基线：[`vllm-project/vllm@6cf7b26bd`](https://github.com/vllm-project/vllm/tree/6cf7b26bd4bff60bf378e1af14044280ac0d214c)。本文基于这一固定 commit 阅读 V1 源码，并与 vLLM 工程博客及稳定版设计文档进行交叉核对。代码摘录均来自该 commit；部分摘录省略了无关行以聚焦重点，每处省略都以 `...` 标记，未标注为伪代码的行均与源码一致。锚点写作 `path:Lstart-Lend`，并链接到 GitHub 上固定的 commit。

## 1. 为什么请求路径是正确的阅读起点

vLLM 是一个庞大的系统：融合 attention kernel、基于 block 的 KV cache manager、continuous batching scheduler、tensor/pipeline/data parallelism、推测解码。人们很容易想从 kernel 开始读，因为正是其中的巧妙设计让 vLLM 声名鹊起。但这不是正确的阅读起点。kernel 是叶子；*请求路径*才是赋予每片叶子意义的树干。PagedAttention kernel 看到的始终只是其他层为它构建的 block table——如果先读 kernel，你看到的就是一个尚未提出的问题的答案。端到端读完一个请求后，后续每个子系统就不再是悬空的优化，而会变成一个有明确名称、负责人和不变量的环节。

解释*为什么这条路径如此重要*，本质上是在讨论内存；值得再次阐明这一点，因为正是它让这条路径不只是一些管道连接。发布文章围绕一个瓶颈来介绍 vLLM：LLM serving 受内存限制，主要由 KV cache 内存主导，而 PagedAttention 的存在就是为了让这部分内存易于分配、共享和复用（[发布](https://vllm.ai/blog/2023-06-20-vllm)）。SOSP 论文对这一机制进行了形式化描述，并报告称，在延迟相当的情况下，相较 FasterTransformer 和 Orca 等先前系统，吞吐量提升了 2–4 倍（[论文](https://arxiv.org/abs/2309.06180)）。但请注意，这种内存管理实际*发生*在哪里：不是在仅仅对 block table 进行解引用的 kernel 中，而是在请求路径沿途——请求准入时分配 block，通过 prefix caching 共享 block，并在请求完成时释放 block。只有跨越这些边界追踪一个请求，才能真正*读懂*那个证明 vLLM 存在价值的瓶颈。这才是应当先读请求路径的真正原因。

因此，贯穿本文的核心问题，正是本系列开篇提出的问题：

> `LLM.generate()` 如何变成一次模型 forward pass 和一个采样得到的 token？

<a href='images/vllm-01-01-request-flow.svg' target='_blank'><img src='images/vllm-01-01-request-flow.svg' alt='vllm-01-01-request-flow'></a>

<p class='figure-caption'>请求流从公开的 `generate()` 调用一路向下到一个 engine 输出，再返回为 `RequestOutput`。</p>

### engine 由四个函数构成

在阅读任何代码之前，先统一术语。架构概览将 engine 描述为四个核心函数，这也是整个系列的骨架（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）：

> “输入处理……调度：‘选择每个步骤中要处理哪些请求’……模型执行：‘管理语言模型的执行’……输出处理：‘处理模型生成的输出，对 token ID 进行 decode’。”

**逐步解读。***输入处理*将原始 prompt 转换为符合 engine 形态的请求——包括 tokenization、多模态预处理和参数定型（[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）。*调度*在每个步骤决定运行哪些请求，以及每个请求获得多少个 token（[第 7 节](#7-调度一个步骤概览)；深度解析文章 05）。*模型执行*在 GPU 上运行 forward pass 并生成 logits（[第 8 节](#8-模型执行从-executor-到-logits概览)–[第 9 节](#9-从隐藏状态到采样-token概览)；文章 08–09）。*输出处理*将 token ID decode 回用户可见的文本（[第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)；文章 04）。后续每篇深度文章都恰好是对这四个函数之一的放大，而文章 01 的目的就是为连接它们的组织结构命名。

**这一框架带来的心智模型。**本系列采用官方架构概览中的四项核心职责——输入处理、调度、模型执行、输出处理——作为组织框架（transport、cache 管理和可观测性等横切关注点，则会在其出现之处单独讨论）。当你之后遇到 prefix-cache hasher、CUDA graph replayer 或异步输出 handler 时，可以把它们分别归入这些标题之一，并知道它们位于哪条边界之后。在阅读任何一个 kernel 之前，这个心智模型就已经稳定下来。

### 这四个函数构成一个反复执行的事务

下面这个观点会重新组织你对整个系统的理解。这四个函数并不是一条每个请求只穿越一次的 pipeline。其中三个——调度、执行、处理——共同构成一个*事务*，engine 会一次又一次地运行它；每次运行对应一个“step”，每轮将正在处理的请求向前推进几个 token，直到各个请求完成。这并非比喻。它实际上就是某个方法的方法体。

[`vllm/v1/engine/core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)（摘录；[第 6 节](#6-engine-step调度执行处理输出) 完整引用了该方法）：

```python
    def step(self) -> tuple[dict[int, EngineCoreOutputs], bool]:
        """Schedule, execute, and make output.

        Returns tuple of outputs and a flag indicating whether the model
        was executed.
        """
        ...
        scheduler_output = self.scheduler.schedule(self._should_throttle_prefills())
        future = self.model_executor.execute_model(scheduler_output, non_block=True)
        ...
            model_output = future.result()
        ...
        self._process_aborts_queue()
        engine_core_outputs = self.scheduler.update_from_output(
            scheduler_output, model_output
        )
        ...
```

<a href='images/vllm-01-11-step-progression.svg' target='_blank'><img src='images/vllm-01-11-step-progression.svg' alt='vllm-01-11-step-progression'></a>

<p class='figure-caption'>continuous batching 的运行过程：每次 `EngineCore.step()` 都会让正在处理的请求前进几个 token，而请求可以跨 step 独立进入和完成——四个函数中的三个（调度、执行、提交）每个 step 重复一次，输入处理则只在最开始运行一次。</p>

**逐步解读。**docstring——“调度、执行并生成输出”——用几个词概括了整个架构。`schedule()` 在不接触 GPU 的情况下决定*哪些请求获得多少个 token*；`execute_model(..., non_block=True)` 启动 forward pass 并返回一个 `Future`，这样 CPU 就能在 *GPU 计算期间*构建 grammar bitmask；`future.result()` 是同步点（如果执行阶段延后了采样，则会通过单独的 `sample_tokens` 调用来运行采样）；`_process_aborts_queue()` 会在提交之前处理帧执行期间到达的任何取消操作，因此在该 step 内被取消的请求绝不会继续推进；而 `update_from_output` 会把采样得到的 token 合并到请求进度中，并释放所有已完成请求的 block。这些调用——再加上方法开头的空 scheduler 守卫，它会统计已经完成但尚未 flush 的请求，以便循环能够干净地排空——共同组成一个事务。[第 6 节](#6-engine-step调度执行处理输出) 对此进行了逐行讲解（其中：文章 05 详解 `schedule()`，文章 08–09 介绍 `execute_model`，文章 10 处理采样，文章 04 解释循环机制）。文章 01 的任务只是确立：这个事务*就是* engine。

**它所保护的不变量。**vLLM 中的每种公开接口——离线的 `LLM.generate`、兼容 OpenAI 的 server、异步的 `AsyncLLM.generate`——都是一层薄适配器，其唯一职责是把工作送入这个事务，再将输出适配后送回。`generate()` 不会调度 token、分配 KV block 或运行 kernel；它只负责验证输入、分配请求 ID，并不断取出持续运行这一循环的 engine 的结果。只要彻底理解一次 `step()`，每个入口点的形态就都变得可以预测：它们最终都归结为“添加一个请求，然后持续拉取输出，直到完成”。

### 这条路径是一连串所有权边界

由于 engine 是一个由适配器包裹的小型事务，因此请求路径可以理解为一连串*所有权边界*，每条边界都保护着一个不变量。公开 API 负责验证、默认值设置以及恢复输入顺序。输入 processor 负责将 prompt 转换为一个拥有明确所有权、所有默认值均已补齐的 wire struct。engine client 负责提供与 transport 无关的接口。`EngineCore` 负责调度/执行/提交事务——但会把所有生命周期状态（哪些请求正在等待、运行或已完成；各个 block 归谁所有）委托给 scheduler。scheduler 负责 token 和内存决策；worker 负责 tensor 和 logits；sampler 负责 token ID；输出 processor 负责 detokenization、stop string 和最终的 `RequestOutput`。这些所有者之间的每一条箭头，都对应后续的一篇文章。预先为它们命名的价值在于，当出现 bug 或功能问题时——“谁决定 `max_tokens`？”、“在哪里检测 stop string？”、“何时释放 block？”——你已经知道应当打开哪条边界。

### 这条路径会跨越进程，但如何跨越取决于部署方式

文章 01 必须尽早面对的一个复杂之处是：这些边界并不全都位于同一个进程中。V1 有意将这四个函数拆分到不同进程，使 CPU 密集型工作（tokenization、多模态预处理、detokenization、流式传输）能够与 GPU 密集型工作重叠执行（[v1](https://vllm.ai/blog/2025-01-27-v1-alpha-release)，[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）。前端进程（`AsyncLLM`）负责 HTTP、输入处理和流式传输；`EngineCore` 进程运行 scheduler、KV cache 和执行协调；worker 运行 forward pass。一个使用四块 GPU 的 tensor parallel 部署，其具体进程数量如下：

> 4-GPU TP=4 部署 = **1 个 API server + 1 个 engine core + 4 个 GPU worker = 6 个进程**（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）；在 data parallelism 下还会增加一个 DP Coordinator 进程。

同一份配置能够一致地传递到全部六个进程，并非偶然——整个技术栈中贯穿着同一个 `VllmConfig` 对象：“通过将所有配置封装到一个对象中，我们可以轻松地在各处传递配置对象，并访问所需的配置”（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）。

下面就是这些衔接机制带来的收益，也是你可以像阅读单进程程序一样阅读请求路径的原因：这种拆分**不会**泄漏到请求语义中。`LLMEngine` 只持有一个指向 engine 的句柄，而传输机制隐藏在该句柄之后。

[`vllm/v1/engine/llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111):

```python
        # EngineCore (gets EngineCoreRequests and gives EngineCoreOutputs)
        self.engine_core = EngineCoreClient.make_client(
            multiprocess_mode=multiprocess_mode,
            asyncio_mode=False,
            vllm_config=vllm_config,
            executor_class=executor_class,
            log_stats=self.log_stats,
        )
```

**逐步解读。** 注释说明了完整契约：客户端“获取 `EngineCoreRequest`s，并给出 `EngineCoreOutputs`。”`make_client` 在构造时根据 `multiprocess_mode` 一次性选择具体实现：要么是直接调用 `EngineCore` 的进程内对象，要么是通过 ZMQ socket 将请求序列化后发送给执行忙等循环的 `EngineCore` 进程的客户端。从这一行之后，请求路径上的任何部分都不知道、也不关心拿到的是哪一种实现——两者的 `add_request` 和 `get_output` 具有完全相同的签名。（这里有一个值得记住的修正：即使是“离线”`LLM`，默认也会使用多进程客户端，因为 `VLLM_ENABLE_V1_MULTIPROCESSING` 默认为 true；进程内路径是需要主动选择的非默认方案。文章 03 会详细讲解这个传输分支。）

**它所保护的内容。** 进程边界是一个*部署*决策，而不是*语义*决策。`EngineCore` 究竟是本地方法调用，还是位于 socket 后方的进程，会改变延迟和故障模式，却不会改变请求的含义。正因为如此，文章 01 才能把该路径追踪为一条逻辑上的单线程——公共 API → 输入处理器 → `EngineCoreRequest` → 客户端 → `EngineCore.step` → scheduler → worker → 采样器 → 输出处理器 → `RequestOutput`——并将真正的 ZMQ 拓扑、DP 路由和并行机制留到文章 03 和 11 再讲。

### 如何阅读本文的其余部分

文章 01 是一张地图，地图上的每一跳都会在后续章节中放大讲解，而不会重复内容。封装 `generate()` 和 OpenAI 服务器的入口点见文章 02；进程架构和 ZMQ 传输见 03；`EngineCore` 循环和请求生命周期见 04；scheduler（continuous batching、chunked prefill）见 05；KV cache 管理器见 06，前缀缓存见 07；PagedAttention kernel 和 attention 后端见 08；worker、model runner 和 CUDA graph 见 09；采样和 logits 处理见 10；分布式推理见 11；推测解码见 12；扩展 vLLM 见 13。先从头到尾通读一遍本文，以确立整体形态和术语体系。然后把后续每一节都视为其中一个方框的图例——地图本身保持不变，变化的只有分辨率。

## 2. LLM.generate()：离线便捷层

从地图顶部开始（[第 1 节](#1-为什么请求路径是正确的阅读起点)）：`LLM.generate()` 是请求路径中的第一个所有权边界，而且它被刻意设计得平淡无奇。它不会调度 token、分配 KV block，也不会启动哪怕一个 CUDA kernel。它的全部职责就是验证调用、具体化采样参数、生成请求 ID、将工作交给 engine，并阻塞至所有结果返回——然后恢复调用方的输入顺序。准确理解这一边界位于何处，以及它建立了哪些不变量，正是本文后续能够将其下方的一切都视为黑盒的原因：这个黑盒消费 `EngineCoreRequest`s，并产出 `RequestOutput`s。

离线接口实际上涉及两个文件。`vllm/entrypoints/llm.py` 负责验证和构造 engine；`vllm/entrypoints/offline_utils.py` 负责“渲染 → 添加 → 排空”这条主干路径。`LLM` 类本身是一个由 mixin 组装而成的 façade：

[`vllm/entrypoints/llm.py:66`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L66)

```python
class LLM(BeamSearchOfflineMixin, PoolingOfflineMixin, OfflineInferenceMixin):
```

<a href='images/vllm-01-12-facade-method-map.svg' target='_blank'><img src='images/vllm-01-12-facade-method-map.svg' alt='vllm-01-12-facade-method-map'></a>

<p class='figure-caption'>离线 façade 中的方法归属：`LLM` 上公开的 `generate` / `chat` / `enqueue` 负责验证、填充默认值和编排，并通过单一的 `LLMEngine` 句柄委托给 `OfflineInferenceMixin` 上的 `_render_and_add_requests → _add_request → _run_engine` 主干路径——façade 之上不存在任何调度、内存或执行逻辑。</p>

公共方法（`generate`、`chat`、`enqueue`）位于 `LLM` 上，负责验证、默认值填充和编排——`enqueue` 确实会执行入队操作：它调用 `_add_completion_requests()` 将请求推入 engine 队列并返回其 ID（[`llm.py:487-530`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L487-L530)）；`generate`/`chat` 则委托给同一条“渲染/添加/排空”路径；添加后排空的机制本身位于 `offline_utils.py` 中的 `OfflineInferenceMixin` 上。**不变量：**面向用户的类不包含任何调度、内存管理或执行逻辑——这些职责严格位于 façade 之下，而且所有路径（`generate`、`chat`、池化）最终都会汇合到同一条 `_render_and_add_requests → _add_request → _run_engine` 调用链。

### 门控、默认值、委托

`generate()` 包含三个动作和一次交接：

[`vllm/entrypoints/llm.py:465-485`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L465-L485)

```python
        runner_type = self.model_config.runner_type
        if runner_type != "generate":
            raise ValueError(
                "LLM.generate() is only supported for generative models. "
                "Try passing `--runner generate` to use the model as a "
                "generative model."
            )

        if sampling_params is None:
            sampling_params = self.get_default_sampling_params()

        return self._run_completion(
            prompts=prompts,
            params=sampling_params,
            output_type=RequestOutput,
            use_tqdm=use_tqdm,
            lora_request=lora_request,
            tokenization_kwargs=tokenization_kwargs,
            priority=priority,
            mm_processor_kwargs=mm_processor_kwargs,
        )
```

按顺序解读。第一，**runner 类型门控**：模型必须以生成式 runner 的形式加载，因此池化/嵌入模型会在这里被拒绝，此时尚未创建任何请求对象。第二，**默认值具体化**：如果调用方传入了 `sampling_params=None`，`get_default_sampling_params()`（[`llm.py:415-420`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L415-L420)）会获取模型自身的 `generation_config` 差异配置（`get_diff_sampling_param()`），否则回退到一个不带额外配置的 `SamplingParams()`。第三，**委托**给 `_run_completion`，并将 `output_type=RequestOutput` 固定为一个参数。

由此得到两个不变量。**仅限生成式模型**会被强制检查两次——一次由上面的门控完成，另一次在排空阶段通过 `assert isinstance(output, output_type)` 完成（见下文），因此意外出现的池化输出会触发断言，而不是悄无声息地泄漏出去。**委托时 Params 绝不会是 `None`**：下游的渲染/添加路径完全不需要防范 `SamplingParams` 缺失。`chat()` 采用相同的结构，也有完全相同的门控和默认值步骤；唯一的区别是，它会先通过聊天模板进行渲染，然后再汇入这条共享路径——关于共享这条路径的入口点家族（CLI、聊天和 OpenAI 服务器），请参见文章 02。

<a href='images/vllm-01-03-generate-layers.svg' target='_blank'><img src='images/vllm-01-03-generate-layers.svg' alt='vllm-01-03-generate-layers'></a>

<p class='figure-caption'>离线栈——`LLM` façade（验证/默认值/ID）位于 `OfflineInferenceMixin`（渲染/添加/排空）之上，后者又位于单一的 `LLMEngine` 句柄之上；每一层都明确命名了它所保护的一个不变量。</p>

### 对齐 batch，然后强制使用 FINAL_ONLY

`_run_completion` 分为两个阶段：先将所有内容入队，然后阻塞并排空 engine。在接纳任何一个请求之前，`_add_completion_requests` 会将四个位置输入——prompts、params、LoRA、priority——规范化为等长序列。标量广播或验证规则是其中的关键：

[`vllm/entrypoints/offline_utils.py:247-256`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L247-L256)

```python
        if isinstance(params, Sequence):
            if len(params) != num_requests:
                raise ValueError(
                    f"The lengths of prompts ({num_requests}) "
                    f"and params ({len(params)}) must be the same."
                )

            return params

        return [params] * num_requests
```

单个 `SamplingParams` 会广播到每个 prompt；如果按 prompt 提供的列表长度与 prompt 数量不相等，则会在添加任何请求**之前**抛出 `ValueError`。`_lora_request_to_seq` 和 `_priority_to_seq` 遵循相同的结构。**规则：**执行完这段代码后，prompts/params/LoRA/priority 是四个长度相同、按位置对齐的序列——索引 `i` 始终指向请求 `i`，因此一个 prompt 绝不可能意外使用相邻请求的采样 params 运行。（随后会以*惰性*方式渲染 prompts：它们作为生成器传递给添加循环，因此在默认多进程模式下，engine 已经可以开始处理 prompt `i` 时，prompt `i+1` 才进行渲染；传入一个已经物化的列表则会触发 `warning_once`，[`offline_utils.py:504-512`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L504-L512)。）

每个对齐后的元组都会到达 `_add_request`，离线路径会在这里写入它的两个标志性决策：

[`vllm/entrypoints/offline_utils.py:559-563`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L563)

```python
        if isinstance(params, SamplingParams):
            # We only care about the final output
            params.output_kind = RequestOutputKind.FINAL_ONLY

        request_id = str(next(self.request_counter))
```

第一，**输出类型被强制设为 `FINAL_ONLY`**，覆盖调用方设置的任何值。该枚举明确给出了三种模式：

[`vllm/sampling_params.py:182-188`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/sampling_params.py#L182-L188)

```python
class RequestOutputKind(Enum):
    # Return entire output so far in every RequestOutput
    CUMULATIVE = 0
    # Return only deltas in each RequestOutput
    DELTA = 1
    # Do not return intermediate RequestOutput
    FINAL_ONLY = 2
```

<a href='images/vllm-01-13-output-kind-matrix.svg' target='_blank'><img src='images/vllm-01-13-output-kind-matrix.svg' alt='vllm-01-13-output-kind-matrix'></a>

<p class='figure-caption'>`RequestOutputKind` 对比：`CUMULATIVE` 会重复发送不断增长的完整结果，`DELTA` 只发出新增切片（使用邮箱 `aggregate=True`），而 `FINAL_ONLY` 会在完成时只发出一次输出——这正是 `_add_request` 为离线 batch 推理强制使用的模式，也是排空循环中的 `if output.finished:` 所依赖的模式。</p>

离线 batch 推理不会进行流式输出；`FINAL_ONLY` 会通知下游的 `OutputProcessor`，只在请求完成时为其发出一次 `RequestOutput`。请注意，这会原地修改调用方的 `SamplingParams` 对象（池化 params 不是 `SamplingParams`，因此不会被修改）。**保证：**engine 只会在请求完成时将其输出暴露一次——这正是排空循环中的 `if output.finished:` 过滤器所依赖的假设。

第二，**请求 ID 是单调递增的十进制字符串**，来自在 `__init__` 中创建的 `Counter()`：`"0"`、`"1"`、`"2"`……顺序与提交顺序一致。最终排序正是利用了这一顺序。

除此之外，还有一个接纳阶段的保证：`_render_and_add_requests` 会捕获 batch 处理中途发生的任何异常，在重新抛出异常之前中止所有已经添加的请求（`abort_request(..., internal=True)`）（[`offline_utils.py:545-548`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L545-L548)）。**不变量（原子性）：**要么整个 batch 都进入 engine，要么失败后不会残留这次调用的任何请求——添加到一半的 batch 绝不可能污染排空过程。

### 阻塞式排空与输入顺序恢复

请求接纳完毕后，`generate()` 会变成一个同步驱动循环，反复执行 engine 自身的 step：

[`vllm/entrypoints/offline_utils.py:594-599, 623-626`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L599)

```python
        while self.llm_engine.has_unfinished_requests():
            step_outputs = self.llm_engine.step()
            for output in step_outputs:
                assert isinstance(output, output_type)
                if output.finished:
                    outputs.append(output)  # type: ignore[arg-type]
        ...
        # Sort the outputs by request ID.
        # This is necessary because some requests may be finished earlier than
        # its previous requests.
        return sorted(outputs, key=lambda x: int(x.request_id))
```

<a href='images/vllm-01-14-order-restore.svg' target='_blank'><img src='images/vllm-01-14-order-restore.svg' alt='vllm-01-14-order-restore'></a>

<p class='figure-caption'>末尾的 `sorted(...)` 为何存在：continuous batching 允许请求以不同于提交顺序的次序完成（scheduler 可以自由交错执行 prefill 和 decode），因此，由 `Counter()` 生成的单调递增十进制 ID 让包装层能够恢复输入顺序——从而避免将“保留提交顺序”放到 scheduler 的热路径上。</p>

逐步来看：循环条件依据的是 *engine 的*记账状态——`has_unfinished_requests()` 由输出处理器提供支持（[`llm_engine.py:188-195`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L188-L195)），而不是一个局部计数器——因此，刚注册的工作会立即可见，循环会持续推进，直到没有任何未完成的工作。每次 `llm_engine.step()` 都是一个完整的 schedule → execute → process-outputs 周期（该封装器在本文的 engine-step 一节中介绍，而它所驱动的 `EngineCore` 循环则在文章 04 中介绍）。`assert isinstance(output, output_type)` 是入口门禁在运行时的对应保障：在 `output_type=RequestOutput` 的情况下，池化输出绝不可能混入其中。由于 params 被强制设为 `FINAL_ONLY`，`if output.finished:` 会对每个请求恰好收集一次。最后，结果会按照整数请求 ID 进行 `sorted`。

末尾的排序正是使用单调递增 ID 的全部意义所在。连续 batching *有意*允许后提交的请求先于先提交的请求完成——scheduler 可以自由地在整个运行集合中交错执行 prefill 和 decode，而无需考虑提交顺序。[`offline_utils.py:623-625`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L623-L625) 中的注释逐字说明了这一理由。**不变量：**该调用是**阻塞/同步的**（只有当 engine 报告不存在未完成请求时才会返回——这是离线契约的定义性特征，与流式 `AsyncLLM` 相对），并且**输出顺序等于输入顺序**，因为 ID 按提交顺序分配，而排序会在封装层恢复该顺序。顺序恢复放在这里，即便利层中，这样 scheduler 就永远不必把“保持提交顺序”当作 GPU 热路径上的约束。文章 05 将介绍为什么这种自由度对吞吐量至关重要。

### 一个用户请求可能变成 n 个 engine 请求

该 façade 还负责维持并行采样的边界。当 `SamplingParams.n > 1` 时，`LLMEngine.add_request` 会将一个逻辑请求扇出为 `n` 个子请求，每个子请求都有自己的 ID 和子 sampling params，但返回的是*父请求的* ID：

[`vllm/v1/engine/llm_engine.py:279-292`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L279-L292)

```python
        # Fan out child requests (for n>1).
        parent_req = ParentRequest(request)
        for idx in range(n):
            request_id, child_params = parent_req.get_child_info(idx)
            child_request = request if idx == n - 1 else copy(request)
            child_request.request_id = request_id
            child_request.sampling_params = child_params

            # Make a new RequestState and queue.
            self.output_processor.add_request(
                child_request, prompt_text, parent_req, idx
            )
            # Add the request to EngineCore.
            self.engine_core.add_request(child_request)
```

每个子请求都会在*两侧*注册——输出处理器侧（用于反分词和聚合）以及 engine core 侧（用于 scheduling）——而 `ParentRequest` 会将这些子请求重新合并为一个用户可见的结果。**不变量：**`n>1` 对应 `n` 个 engine 请求，但恰好只有一个 `RequestOutput`；离线 `tqdm` 的记账会通过将进度条推进 `n = len(output.outputs)` 来预先考虑这一点。子 sampling params 的派生将在文章 10 中介绍；双侧注册将在文章 04 中介绍。

### 这一层是什么，又不是什么

有一个细微之处值得明确说明：“离线”并不意味着“进程内”。同步 `LLM` 默认仍通过 ZMQ 访问一个后台 `EngineCore` 进程——该 façade 恰好拥有一个多态的 `EngineCoreClient` 句柄，其传输方式在构造时根据 `VLLM_ENABLE_V1_MULTIPROCESSING` 默认值（即 `True`）确定，此后绝不会泄漏到 `generate()` 的语义中。这套 engine 边界机制——`make_client` fork、环境变量默认值以及 ZMQ 契约——是[第 4 节](#4-engine-边界进程内-client-与多进程-client)的主题；从便利层的视角来看，engine 只不过是一个你向其执行 `add_request`，并不断执行 `step()` 直至排空的对象。

因此，离线便利层守护的是一份简短而精确的清单：仅生成式输出；params 始终具体，绝不会是 `None`；四个按位置对齐的输入序列；不支持流式传输（`FINAL_ONLY`，每个请求一个输出）；按提交顺序单调递增的 ID，并通过末尾排序恢复输入顺序；batch 原子式准入；每个逻辑请求只有一个用户可见输出；以及一个由其单独拥有的 engine 句柄，其传输方式对上层不可见。`_run_completion` 之后的一切——渲染、scheduler、KV cache、内核、采样器、反分词器——都是黑盒，接下来的各节将逐一打开它们。

## 3. 输入处理：Prompt 如何变成 EngineCoreRequest

上一节结束于 `LLM.generate()` 将原始 prompt 向下传递至 engine。在该公共调用与 scheduler 能够处理的任何内容之间，存在一个转换边界：`InputProcessor.process_inputs`。它的职责是接收一种*异构的*用户输入——裸 `str`、`TextPrompt`、由预先分词 ID 构成的 `TokensPrompt`、由预计算 embedding 构成的 `EmbedsPrompt`、encoder/decoder 对，或多模态数据包——并将其归并为恰好一个统一的、面向传输的结构体：`EngineCoreRequest`。所有下游组件（client、engine core、scheduler、worker）都只使用该结构体进行通信。本节讨论的正是这次跨越，以及它向后续每一层提供的保证。

最重要的架构事实是这项工作在*何处*运行。V1 有意将分词、多模态预处理、反分词和流式传输**移出热执行循环**，使受 CPU 限制的准备工作能够与 GPU 工作重叠执行（[V1 博客](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。`process_inputs` 是这一拆分的前端部分。当请求到达 `EngineCore` 时，分词已经完成，params 已经填入默认值，多模态特征也已经展平——核心循环绝不会接触分词器。

<a href='images/vllm-01-04-input-to-request.svg' target='_blank'><img src='images/vllm-01-04-input-to-request.svg' alt='vllm-01-04-input-to-request'></a>

<p class='figure-caption'>一次 `process_inputs` 调用会将五种 prompt 形态（文本、token、embedding、enc/dec、多模态）汇入单一的 `EngineCoreRequest` 传输结构体。</p>

### 边界及其签名

该转换只有一个入口点。

[`vllm/v1/engine/input_processor.py:242-255`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L242-L255)

```python
    def process_inputs(
        self,
        request_id: str,
        prompt: PromptType | EngineInput,
        params: SamplingParams | PoolingParams,
        supported_tasks: tuple[SupportedTask, ...],
        arrival_time: float | None = None,
        lora_request: LoRARequest | None = None,
        tokenization_kwargs: dict[str, Any] | None = None,
        trace_headers: Mapping[str, str] | None = None,
        priority: int = 0,
        data_parallel_rank: int | None = None,
        resumable: bool = False,
    ) -> EngineCoreRequest:
```

<a href='images/vllm-01-15-process-inputs-stages.svg' target='_blank'><img src='images/vllm-01-15-process-inputs-stages.svg' alt='vllm-01-15-process-inputs-stages'></a>

<p class='figure-caption'>`process_inputs` 内部：按顺序通过层层关卡——验证（`_validate_params` / `_validate_lora` / DP-rank 边界）→ 根据 `isinstance(prompt, dict) and "type" in prompt` 分支（原样使用已渲染的 `EngineInput`，或使用已弃用的 `InputPreprocessor.preprocess()`）→ 拆分 enc/dec 并检查长度 → `params.clone()` + finalize → 展平多模态数据 → 构建 `EngineCoreRequest` → `assign_request_id`，同时包含每个阶段所添加的不变量。</p>

该签名中的两个类型联合承载了整个设计。`prompt: PromptType | EngineInput` 表明输入既可以是*原始的*用户 prompt，也可以是*已经渲染的* `EngineInput`（下文将进一步介绍该分支）。`params: SamplingParams | PoolingParams` 表明 `params` 的运行时类型会为 pipeline 的其余部分选择 task 系列——生成或池化。返回类型是固定的：无条件返回 `EngineCoreRequest`。

该方法由 `LLMEngine.add_request` 调用；后者正是将输入处理与上一节所述 engine 边界衔接起来的接缝。

[`vllm/v1/engine/llm_engine.py:249-263`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L249-L263)

```python
        else:
            request = self.input_processor.process_inputs(
                request_id,
                prompt,
                params,
                supported_tasks=self.get_supported_tasks(),
                arrival_time=arrival_time,
                lora_request=lora_request,
                tokenization_kwargs=tokenization_kwargs,
                trace_headers=trace_headers,
                priority=priority,
            )
            prompt_text, _, _ = extract_prompt_components(self.model_config, prompt)

        self.input_processor.assign_request_id(request)
```

可以将其理解为两步交接：`process_inputs` 构建结构体，然后 `assign_request_id` 为其加上标记（本节末尾会介绍）。只有完成这两步之后，`add_request` 才会在输出处理器和 engine core 上注册请求。

### 验证先于分词执行

`process_inputs` 所做的第一件事就是拒绝格式错误的工作，并且会在为其耗费一次分词器处理之前完成拒绝。

[`vllm/v1/engine/input_processor.py:256-267`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L256-L267)

```python
        self._validate_params(params, supported_tasks)
        self._validate_lora(lora_request)

        parallel_config = self.vllm_config.parallel_config
        dp_size = parallel_config.data_parallel_size
        dp_local_size = parallel_config.data_parallel_size_local
        num_ranks = dp_local_size if parallel_config.local_engines_only else dp_size
        if data_parallel_rank is not None and not (0 <= data_parallel_rank < num_ranks):
            raise ValueError(
                f"data_parallel_rank {data_parallel_rank} "
                f"is out of range [0, {num_ranks})."
            )
```

`_validate_params`（[`input_processor.py:82-144`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L82-L144)）会强制保证 task/参数一致性：`SamplingParams` 必须与 `GENERATION_TASKS` 存在交集——否则执行 `raise ValueError("This model does not support generation")`——而 `PoolingParams` 必须与 `POOLING_TASKS` 存在交集。在此过程中，它会调用 `params.verify(...)`；该方法只进行*验证*（参数不一致时抛出异常——[`sampling_params.py:736-751`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/sampling_params.py#L736-L751) 只是分派到一系列纯 `_validate_*` 检查），但**不会**进行修改；调用方的 params 会一直保持不变，直到它们在 [`input_processor.py:315`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L315) 被克隆，之后的 finalize 也只会修改克隆。`_validate_lora`（`:146-163`）会将未启用 `lora_config` 时提交 LoRA 请求视为硬错误。上面的 DP-rank 边界检查会拒绝超出范围的 engine 目标。

**它所保护的不变量：**除非模型确实声明支持匹配的 task，并且 LoRA/DP 目标合法，否则任何请求都无法进入分词阶段，更不用说进入 engine core。低成本的拒绝会在 pipeline 中尽可能早的位置发生，而且这些检查之后不可能被重新审查，因为 engine core 只会信任它所收到的结构体。

### 分支：已渲染输入与已弃用的原始路径

这里有一个衔接细节，常常令首次阅读 V1 的人感到意外：`InputProcessor` **自身不拥有任何分词器**。分词和 HF 多模态处理器如今都位于 `Renderer` 之后，由入口点在*上游*调用（参见文章 02）。`process_inputs` 更倾向于接收已经由 renderer 处理完成的输入。

[`vllm/v1/engine/input_processor.py:269-296`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L269-L296)

```python
        if isinstance(prompt, dict) and "type" in prompt:
            if tokenization_kwargs:
                logger.warning_once(
                    "Passing tokenization_kwargs to InputProcessor is deprecated "
                    "and will be removed in v0.18. You should instead pass "
                    "them to Renderer.render_cmpl() or Renderer.render_chat()."
                )

            if arrival_time is None:
                arrival_time = prompt.get("arrival_time", time.time())  # type: ignore[assignment]

            processed_inputs: EngineInput = prompt  # type: ignore[assignment]
        else:
            logger.warning_once(
                "Passing raw prompts to InputProcessor is deprecated "
                "and will be removed in v0.18. You should instead pass "
                "the outputs of Renderer.render_cmpl() or Renderer.render_chat()."
            )

            if arrival_time is None:
                arrival_time = time.time()

            processed_inputs = self.input_preprocessor.preprocess(
                prompt,
                tokenization_kwargs=tokenization_kwargs,
            )

        current_platform.validate_request(processed_inputs, params)
```

判别字段是 `isinstance(prompt, dict) and "type" in prompt`。包含 `"type"` 键的 dict 会被视为已经渲染的 `EngineInput`，并被**原样**采用——这里完全不会执行分词；甚至可以直接从 dict 中读出 `arrival_time`。其他所有内容——裸 `str`、`TokensPrompt`、enc/dec dict——都会落入**已弃用的** `InputPreprocessor.preprocess()`，后者会将实际分词工作委托回 renderer（[`vllm/inputs/preprocess.py:68-88`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/inputs/preprocess.py#L68-L88) 展示了 `_tokenize_prompt` 如何代理 `self.renderer`）。两个分支最终都汇入 `current_platform.validate_request(...)`。

**规则：**现代流程会在上游完成渲染（分词 + 运行多模态处理器），并传入处理完毕的 `EngineInput`；原始路径和内联 `tokenization_kwargs` 仅为向后兼容而保留，并已标记为将在 v0.18 中移除。无论运行哪个分支，`processed_inputs` 都是一个带有 `"type"` 判别字段的 `EngineInput`——这是 `process_inputs` 其余部分可以依赖的标准化形态。（关于渲染本身如何进行分词并展开多模态占位符，请参见文章 02；关于 block hasher 随后如何使用该阶段产生的内容，请参见文章 06 和 07。）

### 克隆并 finalize params

在拆分 encoder/decoder 输入，并验证长度和词表（`:298-309`、`:387-484`——decoder prompt 不能为空，不能超过 `max_model_len`；对于 `generate` 模型，也不能恰好达到 `max_model_len`，因为这样甚至无法为一个输出 token 留出空间）之后，sampling params 会被克隆并 finalize。

[`vllm/v1/engine/input_processor.py:311-330`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L311-L330)

```python
        sampling_params = None
        pooling_params = None
        if isinstance(params, SamplingParams):
            # TODO: can we avoid cloning here in multiproc case?
            sampling_params = params.clone()
            # If unset max tokens, then generate up to the max_model_len.
            if sampling_params.max_tokens is None:
                seq_len = length_from_prompt_token_ids_or_embeds(
                    prompt_token_ids, prompt_embeds
                )
                sampling_params.max_tokens = self.model_config.max_model_len - seq_len

            sampling_params.update_from_generation_config(
                self.generation_config_fields,
                self.renderer.get_eos_token_id(),
            )
            if self.tokenizer is not None:
                sampling_params.update_from_tokenizer(self.tokenizer)
        else:
            pooling_params = params.clone()
```

<a href='images/vllm-01-16-sampling-params-budget.svg' target='_blank'><img src='images/vllm-01-16-sampling-params-budget.svg' alt='vllm-01-16-sampling-params-budget'></a>

<p class='figure-caption'>在克隆对象上完成 params 的最终定型：`max_tokens` 默认为 `max_model_len - seq_len`（`[0 .. max_model_len]` 进度条上的确切剩余预算），`update_from_generation_config` 和 `update_from_tokenizer` 会合入模型默认值，并且 `sampling_params` / `pooling_params` 中恰好只有一个最终不是 `None`——因此 engine core 永远不会看到 `None` token 预算。</p>

调用方的 `params` 会被**克隆**，因此针对每个请求的最终定型绝不会修改调用方可能在多个 prompt 之间复用的共享对象。然后，对于 sampling：未设置的 `max_tokens` 会被填充为 `max_model_len - seq_len`（恰好是剩余预算）；通过 `update_from_generation_config` 合入模型的 `generation_config` 默认值和 EOS id；并通过 `update_from_tokenizer` 合入由 tokenizer 派生的 stop token。此后，`sampling_params` / `pooling_params` 中恰好只有一个不是 `None`。

**不变量：**engine core 接收一个*拥有独立所有权且已完整填充默认值*的 params 对象。`max_tokens` 始终是具体值——scheduler 永远不必推理 `None` token 预算，任何下游层也都不需要访问 `model_config` 或 tokenizer 来完成默认值填充。所有模型特有的知识都在前端一次性固化于此。

### 多模态扁平化与双重哈希

多模态输入按模态（`{"image": [...], "audio": [...]}`）组织。此阶段会将其扁平化为一个按序列顺序排列的列表。

[`vllm/v1/engine/input_processor.py:354-368`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L354-L368)

```python
            mm_features = []
            for modality, idx in sorted_mm_idxs:
                base_mm_hash = decoder_mm_hashes[modality][idx]
                mm_features.append(
                    MultiModalFeatureSpec(
                        data=decoder_mm_inputs[modality][idx],
                        modality=modality,
                        identifier=self._get_mm_identifier(
                            base_mm_hash,
                            lora_request,
                        ),
                        mm_position=decoder_mm_positions[modality][idx],
                        mm_hash=base_mm_hash,
                    )
                )
```

<a href='images/vllm-01-17-mm-dual-hash.svg' target='_blank'><img src='images/vllm-01-17-mm-dual-hash.svg' alt='vllm-01-17-mm-dual-hash'></a>

<p class='figure-caption'>每个 `MultiModalFeatureSpec` 内部的多模态双重哈希：`argsort_mm_positions` 将按模态组织的输入扁平化为序列顺序，然后 `mm_hash` 用作与 LoRA 无关的 processor 缓存键，而 `identifier`（`_get_mm_identifier`，可选地加上 `"{lora_name}:{mm_hash}"`）用作 encoder 输出缓存键——因此，不同 LoRA 下相同的像素绝不会发生冲突。</p>

`argsort_mm_positions`（就在上方的 `:352` 处调用）按各项在 token 序列中的偏移量排序，因此 `mm_features` 是一个跨所有模态从左到右读取的扁平列表。每个 `MultiModalFeatureSpec` 都携带一个**双重哈希**：`mm_hash`（用于索引 *processor* 缓存的原始、与 LoRA 无关的哈希）和 `identifier`（用于索引 *encoder 输出*缓存；当 LoRA 能够改变视觉 embedding 时，它可能以 `"{lora_name}:{mm_hash}"` 的形式添加 LoRA 前缀——参见 `_get_mm_identifier`、`:165-181`）。

**性质：**具有相同像素但使用不同 LoRA 的两个请求绝不会在 encoder 输出缓存中发生冲突，而与 LoRA 无关的 processor 缓存仍可共享。这属于前缀缓存正确性的范畴；文章 07 介绍了 `mm_hash`、LoRA 名称和 `cache_salt` 如何成为 block 哈希的额外键。文章 01 的要点更为聚焦：输入处理是这些缓存键被*生成*的地方，而不是它们被使用的地方。

### 输出：无需 GC 的 wire 结构体

所有内容最终汇聚到一个构造函数。

[`vllm/v1/engine/input_processor.py:370-385`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L370-L385)

```python
        return EngineCoreRequest(
            request_id=request_id,
            prompt_token_ids=prompt_token_ids,
            prompt_embeds=prompt_embeds,
            prompt_is_token_ids=prompt_is_token_ids,
            mm_features=mm_features,
            sampling_params=sampling_params,
            pooling_params=pooling_params,
            arrival_time=arrival_time,
            lora_request=lora_request,
            cache_salt=decoder_inputs.get("cache_salt"),
            priority=priority,
            data_parallel_rank=data_parallel_rank,
            trace_headers=trace_headers,
            resumable=resumable,
        )
```

请注意 `cache_salt=decoder_inputs.get("cache_salt")`——salt 经由 `process_inputs` 原样传递，直到之后才会被用作仅适用于第一个 block 的前缀缓存命名空间标签（文章 07）。它构建的结构体被特意设计成适合 wire 传输的形态。

[`vllm/v1/engine/__init__.py:88-102`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L88-L102)

```python
class EngineCoreRequest(
    msgspec.Struct,
    array_like=True,  # type: ignore[call-arg]
    omit_defaults=True,  # type: ignore[call-arg]
    gc=False,
):  # type: ignore[call-arg]
    request_id: str
    prompt_token_ids: list[int] | None
    mm_features: list[MultiModalFeatureSpec] | None
    sampling_params: SamplingParams | None
    pooling_params: PoolingParams | None
    arrival_time: float
    lora_request: LoRARequest | None
    cache_salt: str | None
    data_parallel_rank: int | None
```

这里的关键是三个 `msgspec.Struct` 选项。`array_like=True` 按位置序列化字段（没有字段名开销）；`omit_defaults=True` 在 wire 上跳过采用默认值的字段；`gc=False` 使该结构体不受 Python 循环垃圾回收器管理。这些选择之所以重要，仅仅是因为该结构体会被*序列化，并通过 ZMQ socket 发送*给默认多进程路径中的后台 `EngineCore` 进程——上一节的 `SyncMPClient`/`AsyncMPClient` 就位于这一传输机制之上（拓扑见文章 03，解码它的循环见文章 04）。一个 `.params` property（[`__init__.py:139-145`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L139-L145)）会返回两者中已设置的那个（优先返回 `sampling_params`），并断言至少有一个存在；绝不同时存在的不变量由构造过程保证（[`input_processor.py:311-330`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L311-L330)，恰好只有一个分支会执行），而不是由该 property 保证。

**保证：**`sampling_params` 和 `pooling_params` 绝不会同时设置；`arrival_time` 在每个分支上都会被填充（因此其非 optional 的 `float` 类型成立）；而且该结构体的序列化成本很低。用户输入的异构性——五种 prompt 形态、可选的多模态输入、可选的 LoRA——已经消失。下游代码只需根据 `sampling_params is not None` 分支处理并读取一个扁平的 token ID 列表，除此之外无需处理任何内容。

### 最后的标记：request-id 随机化

`process_inputs` 返回后，回到 `add_request`，请求会在注册前被加上标记（即上方 [`llm_engine.py:263`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L263) 中的 `assign_request_id` 调用）。

[`vllm/v1/engine/input_processor.py:222-240`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L222-L240)

```python
    @staticmethod
    def assign_request_id(request: EngineCoreRequest):
        """Replace the externally supplied request ID with an internal request ID
        that adds 8 random characters in order to ensure uniqueness.
        """
        if request.external_req_id is not None:
            raise ValueError(
                "The external_req_id field should not be set on EngineCoreRequests"
                " passed to vLLM; use the request_id field."
            )
        request.external_req_id = request.request_id
        if envs.VLLM_DISABLE_REQUEST_ID_RANDOMIZATION:
            logger.warning_once(...)
        else:
            request.request_id = f"{request.external_req_id}-{random_uuid():.8}"
```

调用方提供的 id 保存在 `external_req_id` 中，而 `request_id` 会变成 `"{external}-{8 random chars}"`。

**不变量：**即使调用方提交重复的外部 id，每次准入时的内部 `request_id` 也会以极高概率保持唯一（会追加 8 个随机字符，但不会与现有 id 核对），同时外部 id 会保留下来用于输出和 `abort(req_id, internal=False)`。要求 `external_req_id` 必须未设置的 guard 可防止二次加标记。当结果返回时（输出处理一节），用户看到的是*外部* id，而绝不会是随机化后的内部 id。

### 这一边界为后续路径带来了什么

输入处理是一个出口处带有保证的漏斗。上游的 prompt 是异构的，params 只指定了一部分，多模态数据按模态组织。下游——client、engine core、scheduler、worker——每一层接收到的都是单一的 `EngineCoreRequest`：已经依据模型的任务完成验证，携带扁平 token 列表（或 embeds）、拥有独立所有权且已完整填充默认值的 params 对象、按序列排序且缓存键已生成的多模态特征，以及准备跨越进程边界的 wire 形态主体。scheduler 从不执行 tokenization；worker 从不为 `max_tokens` 填充默认值；engine core 从不检查 `model_config` 来完成请求。这正是 V1 能够在前端运行此阶段并使其与 GPU 工作重叠的全部原因——也正因如此，下一节的 engine 边界可以将 `add_request` 视为移动一个已经完成的对象，而不必执行任何实际工作。

## 4. Engine 边界：进程内 Client 与多进程 Client

前几节沿着一个 prompt 的路径，直到它变成 `EngineCoreRequest`——一个已准备好接受调度的紧凑 wire 结构体。现在，它必须抵达负责调度它的组件。这个组件 `EngineCore` 可能与 `LLM.generate()` 位于同一个 Python 进程中，也可能位于 ZMQ socket 另一端的后台进程中，还可能是多个数据并行 engine 之一，每个 engine 都位于自己的进程中。V1 设计的核心事实是，前端代码无法分辨其中的差异。它持有一个 handle，调用相同的方法，而传输方式只在构造时决定一次，此后再也不会改变。本节讨论的正是这一接缝：这个单一 handle 是什么、factory 如何将其分叉、究竟有什么会跨越边界，以及哪条不变量使部署拓扑不会渗入请求语义。

### 一个 handle，一次选择

`LLMEngine`——离线 `LLM` 路径使用的同步 engine——只拥有一条通向调度与执行的 channel。它在构造函数中创建，并被标注为抽象 client 类型，而不是具体的传输类型。

[`vllm/v1/engine/llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111)

```python
        # EngineCore (gets EngineCoreRequests and gives EngineCoreOutputs)
        self.engine_core = EngineCoreClient.make_client(
            multiprocess_mode=multiprocess_mode,
            asyncio_mode=False,
            vllm_config=vllm_config,
            executor_class=executor_class,
            log_stats=self.log_stats,
        )
```

请仔细阅读这里。`self.engine_core` 是 `LLMEngine` 抵达 scheduler、KV cache 和 GPU 的*唯一*途径。每个公共操作——`add_request`、`step`、`abort_request`、`sleep`、`add_lora`、`collective_rpc`——最终都会转发到这个唯一字段上同名的方法。`asyncio_mode=False` 被硬编码，是因为同步 `LLMEngine` 从不使用 asyncio client；在线路径（`AsyncLLM`）才会传入 `True`。唯一的自由变量是 `multiprocess_mode`，它由一个 classmethod 构造函数传入：

[`vllm/v1/engine/llm_engine.py:157`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L157)

```python
            multiprocess_mode=envs.VLLM_ENABLE_V1_MULTIPROCESSING,
```

**不变量。**前端依赖的是一个*接口*，而不是某种传输方式。engine 位于进程内还是 socket 另一端，是一个构造时决策，绝不会泄漏到下游。`add_request`、`step` 或输出路径中没有任何代码根据 `multiprocess_mode` 分支处理——`self.engine_core` 上的多态派发吸收了全部差异。

这个抽象中恰好只有一个有意保留的缺口，而且它受到 guard 保护：

[`vllm/v1/engine/llm_engine.py:123-125`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L123-L125)

```python
        if not multiprocess_mode:
            # for v0 compatibility
            self.model_executor = self.engine_core.engine_core.model_executor  # type: ignore
```

双重跳转 `self.engine_core.engine_core` 会穿过 *client*（`InprocClient`），抵达其持有的真实 `EngineCore` 对象，然后再进入该对象的 `model_executor`。这之所以可行，只是因为进程内模式保证存在一个可访问的实时本地对象。在多进程模式下，不存在本地 `EngineCore`——它位于另一个进程中——因此会跳过该分支。这个例外恰好证明了规则：代码中唯一直接访问 engine 的地方受 `if not multiprocess_mode` 保护。

### Factory 是分叉点

三种传输方式隐藏在同一个抽象基类之后，而 `make_client` 会根据两个布尔值选择拓扑。

[`vllm/v1/engine/core_client.py:82-105`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L82-L105)

```python
    @staticmethod
    def make_client(
        multiprocess_mode: bool,
        asyncio_mode: bool,
        vllm_config: VllmConfig,
        executor_class: type[Executor],
        log_stats: bool,
    ) -> "EngineCoreClient":
        # TODO: support this for debugging purposes.
        if asyncio_mode and not multiprocess_mode:
            raise NotImplementedError(
                "Running EngineCore in asyncio without multiprocessing "
                "is not currently supported."
            )

        if multiprocess_mode and asyncio_mode:
            return EngineCoreClient.make_async_mp_client(
                vllm_config, executor_class, log_stats
            )

        if multiprocess_mode and not asyncio_mode:
            return SyncMPClient(vllm_config, executor_class, log_stats)

        return InprocClient(vllm_config, executor_class, log_stats)
```

<a href='images/vllm-01-18-make-client-fork.svg' target='_blank'><img src='images/vllm-01-18-make-client-fork.svg' alt='vllm-01-18-make-client-fork'></a>

<p class='figure-caption'>将 `make_client` 表示为关于 `(multiprocess_mode, asyncio_mode)` 的真值表：`(F,F)`→`InprocClient`，`(T,F)`→`SyncMPClient`（离线路径的默认值，因为 `VLLM_ENABLE_V1_MULTIPROCESSING` 是 `True`），`(T,T)`→`make_async_mp_client`（`AsyncMPClient` + DP 变体），而 `(F,T)` 会被拒绝——三者共享 `EngineCoreClient` ABC，其基类方法体都会抛出 `NotImplementedError`。</p>

四种组合，三种结果：`(mp=False, async=False)` → `InprocClient`；`(mp=True, async=False)` → `SyncMPClient`（多进程离线路径）；`(mp=True, async=True)` → async 系列（`AsyncMPClient` 及其 DP 变体，即在线服务器路径）；`(mp=False, async=True)` 则会被明确拒绝——不能在 asyncio 下以进程内方式运行 engine。基类的 docstring 在一处说明了这项契约：

[`vllm/v1/engine/core_client.py:71-80`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L71-L80)

```python
class EngineCoreClient(ABC):
    """
    EngineCoreClient: subclasses handle different methods for pushing
        and pulling from the EngineCore for asyncio / multiprocessing.

    Subclasses:
    * InprocClient: In process EngineCore (for V0-style LLMEngine use)
    * SyncMPClient: ZMQ + background proc EngineCore (for LLM)
    * AsyncMPClient: ZMQ + background proc EngineCore w/ asyncio (for AsyncLLM)
    """
```

**契约。** ABC 声明了每个操作——同步操作及其 `_async` 镜像——而基类的方法体会抛出 `NotImplementedError`。因此，前端调用的任何方法都*必须*针对每种传输方式显式实现；不存在任何可能在跨越边界时表现不同的静默回退。同步与异步方法族在命名上相互镜像（`add_request`/`add_request_async`、`get_output`/`get_output_async`、`abort_requests`/`abort_requests_async`），这使离线和在线前端能够共享同一套心智模型。

### 离线模式默认使用多进程，而非进程内运行

人们很容易认为离线 `LLM` 会在进程内运行 engine——毕竟这里没有 HTTP 服务器。但事实并非如此。回顾一下，构造函数的默认值来自 `envs.VLLM_ENABLE_V1_MULTIPROCESSING`，而该环境变量的默认值是 `True`：

[`vllm/envs.py:147`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/envs.py#L147)

```python
    VLLM_ENABLE_V1_MULTIPROCESSING: bool = True
```

[`vllm/envs.py:1311-1313`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/envs.py#L1311-L1313)

```python
    "VLLM_ENABLE_V1_MULTIPROCESSING": lambda: bool(
        int(os.getenv("VLLM_ENABLE_V1_MULTIPROCESSING", "1"))
    ),
```

因此，即使是普通的 `LLM(model=...).generate(...)` 脚本，也会得到 `multiprocess_mode=True` → `SyncMPClient`，这意味着它会通过 ZMQ 访问后台的 `EngineCore` 进程。只有当用户设置 `VLLM_ENABLE_V1_MULTIPROCESSING=0` 时，才会使用 `InprocClient`。（`LLMEngine.__init__` 上裸露的 `multiprocess_mode: bool = False` 默认值只是一个障眼法——classmethod 构造函数 `from_vllm_config`/`from_engine_args` 总会用环境变量值覆盖它。）实际后果是：vLLM V1 中的“离线”模式默认仍会运行两个进程和一个 socket，因此，即使对于 batch 脚本，下面的边界机制也位于热路径上；这也解释了为什么 engine 侧的请求流水线（让语法编译与 GPU 工作重叠）即使在离线模式下也很重要。

<a href='images/vllm-01-05-engine-boundary.svg' target='_blank'><img src='images/vllm-01-05-engine-boundary.svg' alt='vllm-01-05-engine-boundary'></a>

<p class='figure-caption'>一次 `add_request` 调用，两种实现：内联方法调用（InprocClient）与在 engine 的 IO 线程上解码的序列化 ROUTER 帧（SyncMPClient），二者最终汇合到同一对 `preprocess_add_request → scheduler.add_request` 操作。</p>

### InprocClient：边界退化为一次方法调用

当 engine 在进程内运行时，“客户端”只是一个轻量外壳，它*拥有*真正的 `EngineCore` 并直接调用它——没有序列化，没有 socket，也没有忙循环。

[`vllm/v1/engine/core_client.py:289-299`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L289-L299)

```python
    def get_output(self) -> EngineCoreOutputs:
        outputs, model_executed = self.engine_core.step_fn()
        self.engine_core.post_step(model_executed=model_executed)
        return outputs and outputs.get(0) or EngineCoreOutputs()

    def get_supported_tasks(self) -> tuple[SupportedTask, ...]:
        return self.engine_core.get_supported_tasks()

    def add_request(self, request: EngineCoreRequest) -> None:
        req, request_wave = self.engine_core.preprocess_add_request(request)
        self.engine_core.add_request(req, request_wave)
```

由此可得出两点。第一，`add_request` 恰好是在调用方线程上执行的两次内联调用：`preprocess_add_request` 将具有 wire 形态的 `EngineCoreRequest` 转换为内部 `Request`（对其执行 block 哈希并初始化语法），而 `add_request` 将该 `Request` 交给 scheduler。第二，`get_output` 会*驱动* engine 前进一步：`step_fn` 是 engine 自身的 `step`（或在 pipeline parallelism 下为 `step_with_batch_queue`），因此在进程内模式下，前端的 `step()` 调用实际上*就是* engine 的 step——不存在另一个单独推进执行的循环。`outputs.get(0)` 选择 engine 索引 0，因为进程内模式下恰好只有一个 engine。这正是 docstring 中“V0-style”的含义：单线程、阻塞式 `add_request`/`step`，准入与执行串行进行，不存在并发。

### SyncMPClient：同一次调用，被序列化为自描述帧

在多进程模式下，同一个 `add_request` 会变成序列化并发送。*请求*本身没有任何变化；变化的只是其交付方式。

[`vllm/v1/engine/core_client.py:886-889`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L886-L889)

```python
    def add_request(self, request: EngineCoreRequest) -> None:
        if self.is_dp:
            self.engines_running = True
        self._send_input(EngineCoreRequestType.ADD, request)
```

[`vllm/v1/engine/core_client.py:861-873`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L861-L873)

```python
    def _send_input(self, request_type: EngineCoreRequestType, request: Any):
        self.ensure_alive()
        self.free_pending_messages()
        # (Identity, RequestType, SerializedRequest)
        msg = (self.core_engine, request_type.value, *self.encoder.encode(request))

        if len(msg) <= 3:
            # No auxiliary buffers => no tensor backing buffers in request.
            self.input_socket.send_multipart(msg, copy=False)
            return

        tracker = self.input_socket.send_multipart(msg, copy=False, track=True)
        self.add_pending_message(tracker, request)
```

<a href='images/vllm-01-19-zmq-frame.svg' target='_blank'><img src='images/vllm-01-19-zmq-frame.svg' alt='vllm-01-19-zmq-frame'></a>

<p class='figure-caption'>`SyncMPClient` wire 帧：一个有序的 multipart 消息 `(engine_identity, one-byte type tag, *msgpack payload)`，通过 `zmq.ROUTER` 发送到 engine 的 `zmq.DEALER`；当 `len(msg) <= 3` 时，它是普通的零拷贝 `send_multipart`，否则带外 tensor buffer 会迫使 `track=True` + `add_pending_message` 保留该 buffer，直到 ZMQ 完成发送——这一切都由 `ensure_alive()` 提供统一接口。</p>

wire 消息是一个有序、自描述的 multipart 帧：`(engine_identity, one-byte type tag, *msgpack payload)`。identity 帧用于寻址特定 engine（在 data parallelism 下存在多个 engine 时至关重要）；类型字节使接收方无需协商 schema 即可进行 demux；payload 则是 `msgspec` msgpack。这里出现了三项 `InprocClient` 免费获得的实际簿记机制：如果受监控的 engine 进程已经死亡，`ensure_alive()` 会抛出 `EngineDeadError`（因此该边界不仅传递数据，也承载存活性信息）；`len(msg) <= 3` 分支用于保障零拷贝 tensor 的安全——如果编码后的请求携带带外 tensor buffer（多模态），客户端就必须通过 `zmq.MessageTracker` *保留引用*，直到 ZMQ 完成底层内存的传输，否则该内存可能在发送过程中被释放；而 `add_request` 是即发即弃的——它在发送后返回，输出则通过另一个 socket 异步返回。`self.input_socket` 是客户端绑定的 `zmq.ROUTER`；engine 会连接一个 `zmq.DEALER`，这就是 identity 帧位于最前面的原因。更深层的 socket 拓扑——这些 socket 如何连接、DP 协调器、负载均衡路由，以及必须记住每个飞行中请求位于哪个 engine 上的中止路由——是 **article 03** 的主题；这里我们只需了解客户端契约。

### wire 词汇表只有一个字节

边界协议是一个极小的带标签联合。每种请求类型都是一个十六进制字节，因此将其编码进帧中几乎没有成本。

[`vllm/v1/engine/__init__.py:251-264`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L251-L264)

```python
class EngineCoreRequestType(enum.Enum):
    """
    Request types defined as hex byte strings, so it can be sent over sockets
    without separate encoding step.
    """

    ADD = b"\x00"
    ABORT = b"\x01"
    START_DP_WAVE = b"\x02"
    UTILITY = b"\x03"
    # Sentinel used within EngineCoreProc.
    EXECUTOR_FAILED = b"\x04"
    # Sentinel to wake up input_queue.get() during shutdown.
    WAKEUP = b"\x05"
```

<a href='images/vllm-01-20-request-type-routing.svg' target='_blank'><img src='images/vllm-01-20-request-type-routing.svg' alt='vllm-01-20-request-type-routing'></a>

<p class='figure-caption'>`EngineCoreRequestType` 路由：`ADD` / `ABORT` / `UTILITY` 通过 socket 从客户端传到 engine（只有 `ADD` 使用有类型的 `MsgpackDecoder(EngineCoreRequest, ...)`；其余类型共享无类型 decoder），`START_DP_WAVE` 从协调器传到 engine，而 `EXECUTOR_FAILED` / `WAKEUP` 是进程内哨兵，永远不会在线路上传输，但会复用同一条单 demux 分发路径。</p>

`ADD`、`ABORT` 和 `UTILITY` 是实际通过 socket 从客户端传输的类型；`START_DP_WAVE` 从协调器传到 engine；`EXECUTOR_FAILED` 和 `WAKEUP` 是推送到 engine 自身输入队列中的*进程内哨兵*，永远不会在线路上传输——它们复用同一条分发路径，因此忙循环只需要一个 demux。只有 `ADD` 拥有专用的*有类型* decoder——`MsgpackDecoder(EngineCoreRequest, ...)`——因为它会反序列化为有类型的 `EngineCoreRequest` struct；其他所有类型都共享一个无类型的通用 decoder（[`core.py:1494-1497`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1494-L1497)）。（两个 decoder 都使用相同的 `oob_tensor_provider` 构建，因此带外 tensor 能力*并不是*区分二者的因素，尽管实践中只有 `ADD` payload 实际携带 tensor。）有返回值的操作（`get_supported_tasks`、`sleep`、`add_lora`、`collective_rpc`）全都经由 `UTILITY` 传输，使用 `call_id` 标记并关联回 `Future`，从而让本质上异步的 socket 往返呈现为阻塞式 API——在进程内模式下，这些相同方法只是普通的 Python 返回。

### 对称性：相同的生命周期，线程位置不同

两种传输方式之所以能够共享同一份契约，是因为它们会*以相同顺序执行相同的两个操作*——多进程路径只是将它们拆分到线程边界的两侧。`InprocClient.add_request` 会内联调用 `preprocess_add_request`，然后调用绑定到 `scheduler` 的 `add_request`。多进程 engine 执行的正是同一对操作，但 `preprocess_add_request` 运行在专用输入 IO 线程上，由该线程解码帧；得到的 `(Request, wave)` tuple 会经过线程安全队列；而 `add_request` 则运行在忙循环线程上。engine 自身的 docstring 说明了这一设计意图：

[`vllm/v1/engine/core.py:855-860`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L855-L860)

```python
    def preprocess_add_request(self, request: EngineCoreRequest) -> tuple[Request, int]:
        """Preprocess the request.

        This function could be directly used in input processing thread to allow
        request initialization running in parallel with Model forward
        """
```

这就是进程拆分带来的全部收益：繁重的请求初始化——block 哈希、语法编译——可以与 GPU 工作重叠，而不是阻塞它。进程内客户端运行完全相同的代码，却没有这种流水线能力；这是让 engine 运行在调用方线程上所付出的代价。

**统一不变量。** 请求在两种模式下都会经历完全相同的 `preprocess_add_request → scheduler.add_request` 生命周期；多进程模式只是将两个阶段迁移到不同线程上，以便让初始化与模型 forward 重叠。与之对称，`get_output()` 在两种传输方式上都是签名相同的阻塞式“给我下一 batch 输出”调用——在进程内模式下，它会同步地让 engine 执行 step；在多进程模式下，它会阻塞在一个队列上，该队列由守护线程从 PULL socket 持续取数据并填充；甚至 engine 死亡和 decode 错误也会作为 `Exception` 值通过*同一个队列*到达，因此失败会像数据一样，通过同一个方法同步暴露。前端的 `step()` 循环永远不需要知道自己身处哪一种模式。

这是请求路径其余部分所依附的接缝。上游的公共 API 和输入处理器（本文[第 2 节](#2-llmgenerate离线便捷层)–[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）会向客户端交付一个完整构造的 `EngineCoreRequest`，而不关心它将被送往何处。下游的 `EngineCore.step()`——下一节将介绍的 `schedule → execute → commit` 事务——无论是由 `InprocClient.get_output()` 内联调用，还是由后台进程的忙循环调用，其运行方式都完全相同。有关 `SyncMPClient`/`AsyncMPClient` 所隐藏的 socket 拓扑、DP 路由和协调器内部机制，请参阅 **article 03**（进程架构与 ZMQ）；有关 parallelism 如何在同一个客户端背后扩展出多个 engine 和 worker，请参阅 **article 11**。

## 5. add_request：请求进入 EngineCore

上一节已经说明，`LLMEngine` 持有一个多态的 `EngineCoreClient`，而传输方式——进程内调用或 ZMQ 往返——在构造时确定，且绝不会泄漏到请求语义中。本节将跟随请求跨越这条边界：`add_request` 实际注册了什么，为什么要在*两个*位置注册，在哪里“一个用户请求”会悄然变成“n 个 engine 请求”，以及具有 wire 形态的 `EngineCoreRequest` 究竟在哪个时刻变成由 scheduler 拥有的内部 `Request`。这里的一切都是连接组织——各子系统的内部机制（scheduler 准入、KV block、语法编译、子采样）将交由深度文章介绍。

### 一个请求，两个注册方

当控制流到达 `LLMEngine.add_request` 的末尾时，原始 prompt 已经经过 `input_processor.process_inputs`（article 01 [第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)），现在是一个 `EngineCoreRequest`，其中包含已完整填充默认值并完成克隆的 `SamplingParams`。剩下的工作是注册——而且这是刻意设计成双边执行的。

源码定位：[`vllm/v1/engine/llm_engine.py:263-277`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L263-L277)

```python
        self.input_processor.assign_request_id(request)

        req_id = request.request_id

        # Use cloned params that may have been updated in process_inputs()
        params = request.params

        n = params.n if isinstance(params, SamplingParams) else 1

        if n == 1:
            # Make a new RequestState and queue.
            self.output_processor.add_request(request, prompt_text, None, 0)
            # Add the request to EngineCore.
            self.engine_core.add_request(request)
            return req_id
```

逐步解读。`assign_request_id` 标记内部 id（外部 id 加上 8 个随机字符——文章 01 [第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）；`req_id` 在*这里*、任何 fan-out 发生之前被捕获，因此它就是返回给调用方的 id。样本数量 `n` 从采样参数中读取（pooling 请求始终为 `n == 1`）。然后，快速路径严格按照以下顺序执行两件事：

1. `output_processor.add_request(request, prompt_text, None, 0)` ——创建 `RequestState`，后者将执行 detokenize、聚合，并（在线模式下）持有调用方的输出邮箱。这是*返回路径*的注册。
2. `engine_core.add_request(request)` ——将请求交给 client，由其提交请求以进行 scheduling。这是 *forward 路径*的注册。

这个顺序并非偶然。输出侧在请求被提交执行**之前**完成注册，因此对于 `OutputProcessor` 尚未知晓的请求，绝不可能有任何 `EngineCoreOutput` 抵达。这消除了输出先于注册的竞态，否则快速完成的请求可能会丢失第一个 token。出于同样的原因，离线 drain 循环会立即看到该注册：

源码锚点：[`vllm/v1/engine/llm_engine.py:188-195`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L188-L195)

```python
    def get_num_unfinished_requests(self) -> int:
        return self.output_processor.get_num_unfinished_requests()

    def has_unfinished_requests(self) -> bool:
        has_unfinished = self.output_processor.has_unfinished_requests()
        if self.dp_group is None:
            return has_unfinished or self.engine_core.dp_engines_running()
        return self.has_unfinished_requests_dp(has_unfinished)
```

两个“是否仍有剩余工作？”谓词都由 `output_processor` 提供，而不是由 engine core 提供。因此，一旦上面的步骤 (1) 返回，`LLM._run_engine` 的 `while has_unfinished_requests():` 循环（文章 01 [第 2 节](#2-llmgenerate离线便捷层)）就会持续驱动 `step()`，直到该请求完成——即使 engine 进程尚未确认该请求。输出处理器是存活状态的权威；engine core 则是实际执行工作的地方。

### 一个用户请求，n 个 engine 请求

值得关注的情况是 `n > 1`——并行采样，即用户要求针对一个 prompt 生成多个 completion。vLLM 并不会让 scheduler 理解“n 个样本”这一概念。它将单个请求 fan-out 为 `n` 个独立的 engine 请求，并在输出途中将它们重新组装起来。

源码锚点：[`vllm/v1/engine/llm_engine.py:279-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L279-L294)

```python
        # Fan out child requests (for n>1).
        parent_req = ParentRequest(request)
        for idx in range(n):
            request_id, child_params = parent_req.get_child_info(idx)
            child_request = request if idx == n - 1 else copy(request)
            child_request.request_id = request_id
            child_request.sampling_params = child_params

            # Make a new RequestState and queue.
            self.output_processor.add_request(
                child_request, prompt_text, parent_req, idx
            )
            # Add the request to EngineCore.
            self.engine_core.add_request(child_request)

        return req_id
```

逐步解读。一个 `ParentRequest` 包装原始请求。对于每个子请求索引，它都会生成一个子 id 和对应的子采样参数：

源码锚点：[`vllm/v1/engine/parallel_sampling.py:83-94`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/parallel_sampling.py#L83-L94)

```python
    def get_child_info(self, index: int) -> tuple[str, SamplingParams]:
        """Get child request ID and sampling params.

        Args:
          index: index within `n` child requests.

        Returns:
          (request ID, sampling_params) tuple
        """
        child_req_id = f"{index}_{self.request_id}"
        self.child_requests.add(child_req_id)
        return child_req_id, self._get_child_sampling_params(index)
```

每个子 id 都是在父 id 前加上其索引（`0_<parent>`、`1_<parent>`，……）；子采样参数则按子请求派生（每个子请求的 seed 处理以及 `n → 1` 折叠属于采样范畴——文章 01 [第 9 节](#9-从隐藏状态到采样-token概览) / 深度文章 10）。最后一个子请求（`idx == n - 1`）会*复用原始请求对象*而不是复制它，这是一项内存分配优化；之前的子请求则是 `copy(request)`。每个子请求都会在两侧注册，就像 `n == 1` 快速路径所做的那样——但现在每个 `output_processor.add_request` 都会传入共享的 `parent_req` 和该子请求的 `idx`，这样 `OutputProcessor` 稍后就能将 `n` 个流重新合并为一个。

它所保护的不变量是：**并行采样是 `n` 个 engine 请求，但只有一个用户可见的输出。**该函数返回 `req_id`——即循环开始前捕获的父 id——而不是任何子 id。scheduler、KV cache 管理器和 worker 始终只会看到扁平、独立的请求；它们从不携带“兄弟请求”这一概念。对 `n` 个子请求进行聚合、取消和输出排序，完全是 `OutputProcessor` 的职责（文章 01 [第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)）。如果把每个子请求都当成独立的公开请求，这三项都会失效。

### 跨越边界：EngineCoreRequest 变为 Request

`self.engine_core.add_request(child_request)` 看起来只是一次调用，但其内部发生了一次类型转换，而这才是真正进入 engine 所有权的入口。frontend 传入的对象是 `EngineCoreRequest`——一种不依赖 GC 的 msgspec 线格式结构体。engine 的 scheduler 接收到的对象则是 `vllm.v1.request.Request`。转换发生在 `preprocess_add_request` 中：

源码锚点：[`vllm/v1/engine/core.py:855-877`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L855-L877)

```python
    def preprocess_add_request(self, request: EngineCoreRequest) -> tuple[Request, int]:
        """Preprocess the request.

        This function could be directly used in input processing thread to allow
        request initialization running in parallel with Model forward
        """
        ...
        req = Request.from_engine_core_request(request, self.request_block_hasher)
        if req.use_structured_output:
            ...
            self.structured_output_manager.grammar_init(req)
        return req, request.current_wave
```

逐步解读。`Request.from_engine_core_request` 实例化内部请求，并对 prompt token 运行 block 哈希器（为 prefix-cache 查找提供种子——文章 01 [第 7 节](#7-调度一个步骤概览) / 深度文章 07）。对于结构化输出请求，`grammar_init` 会启动 grammar 编译。docstring 逐字陈述了设计意图：这“可以直接用于输入处理线程，使请求初始化能够与模型 forward 并行运行。”这正是两种传输方式产生分歧的地方，如 engine 边界一节所述：`InprocClient.add_request` 在调用方线程上依次内联运行 `preprocess_add_request` 和 `add_request`，而 `EngineCoreProc` 在其输入 IO 线程上运行 `preprocess_add_request`，并让 busy loop 调用 `add_request`——相同的两个操作、相同的顺序，只是被重新安置，以便让 block 哈希和 grammar 编译与 GPU forward pass 重叠（文章 01 [第 4 节](#4-engine-边界进程内-client-与多进程-client)；有关 ZMQ 线程模型，参见深度文章 03）。无论采用哪种方式，最终抵达 engine scheduling 侧的始终是 `Request`，绝不是线格式结构体。

### Engine 侧准入

engine 侧的 `add_request`——busy loop（或 `InprocClient`）最终调用的方法——非常简短，而这种简短本身正是重点。

源码锚点：[`vllm/v1/engine/core.py:372-407`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L372-L407)

```python
    def add_request(self, request: Request, request_wave: int = 0):
        """Add request to the scheduler.

        `request_wave`: indicate which wave of requests this is expected to
        belong to in DP case
        """
        # Validate the request_id type.
        if not isinstance(request.request_id, str):
            raise TypeError(
                f"request_id must be a string, got {type(request.request_id)}"
            )

        if pooling_params := request.pooling_params:
            supported_pooling_tasks = [
                task for task in self.get_supported_tasks() if task in POOLING_TASKS
            ]

            if pooling_params.task not in supported_pooling_tasks:
                raise ValueError(
                    f"Unsupported task: {pooling_params.task!r} "
                    f"Supported tasks: {supported_pooling_tasks}"
                )

        if request.kv_transfer_params is not None and (
            not self.scheduler.get_kv_connector()
        ):
            logger.warning(
                "Got kv_transfer_params, but no KVConnector found. "
                "Disabling KVTransfer for this request."
            )

        self.scheduler.add_request(request)
        if request.abort_immediately:
            # Immediately abort so the connector's request_finished hook runs
            # to free any pre-admission KV-transfer resources.
            self.abort_requests([request.request_id])
```

<a href='images/vllm-01-21-engine-admission.svg' target='_blank'><img src='images/vllm-01-21-engine-admission.svg' alt='vllm-01-21-engine-admission'></a>

<p class='figure-caption'>Engine 侧的 `add_request`：三个 guard（请求 id `str`、pooling 任务成员资格、未配置 connector 时的 KV 传输警告）、一次向 `self.scheduler.add_request(request)` 的移交，以及 `abort_immediately` 这一边缘情况——在此之后，只有 scheduler 拥有 WAITING→RUNNING→FINISHED 状态机，而 abort 只是 `finish_requests(ids, FINISHED_ABORTED)`。</p>

逐步解读。三个 guard、一次移交、一个边缘情况：

- **类型 guard**——请求 id 必须是 `str`；尽管 frontend 已经检查过，这里仍会再次断言，因为在多进程模式下，对象通过 socket 到达，而 engine 不信任任何外部输入。
- **Pooling 任务 guard**——如果请求携带 `pooling_params`，其任务必须属于模型支持的 pooling 任务，否则执行 `ValueError`。生成请求会跳过此项。
- **KV 传输警告**——带有 `kv_transfer_params` 但未配置 `KVConnector` 的请求不会被拒绝；系统会发出警告并静默禁用传输（这属于解耦式 prefill 范畴，参见深度文章 11）。
- **移交**——`self.scheduler.add_request(request)`。仅这一行就完成了向 scheduler 所有权的跨越。从这里开始，请求存在于等待队列中，其 block 由 KV cache 管理器管理，其状态机（WAITING → RUNNING → FINISHED）完全归 scheduler 所有。`EngineCore.add_request` 不会修改计数器、分配 block 或设置状态——它只负责验证并委托。`scheduler.add_request` 如何处理请求——将其入队、向 KV connector 注册、记录 QUEUED 事件——参见文章 01 [第 7 节](#7-调度一个步骤概览) / 深度文章 05。
- **边缘情况**——`abort_immediately`。一个请求可以在同一次调用中先被准入、随后立即被 abort，从而让 KV connector 的 `request_finished` hook 运行，以释放准入前已预留的资源。这并不是后来附加上的错误路径；它是通过*相同的*两个原语表达的准入与 teardown。

### Abort 就是 finish

最后一点可以推广为整个 engine core 的所有权不变量。Abort 没有自己独立的机制：

源码锚点：[`vllm/v1/engine/core.py:409-415`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L409-L415)

```python
    def abort_requests(self, request_ids: list[str]):
        """Abort requests from the scheduler."""

        # TODO: The scheduler doesn't really need to know the
        # specific finish reason, TBD whether we propagate that
        # (i.e. client-aborted vs stop criteria met).
        self.scheduler.finish_requests(request_ids, RequestStatus.FINISHED_ABORTED)
```

逐步解读。abort 一个请求就是 `scheduler.finish_requests(ids, FINISHED_ABORTED)`——与请求正常完成时 scheduler 使用的调用完全相同，唯一差别只是终止状态。系统不存在以不同方式释放 block 的独立“cancel”路径，这正是 abort 能够避免竞态的原因：无论请求是因为遇到 EOS、遇到 stop string（由 `OutputProcessor` 提升，文章 01 [第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)），还是因 client 断开连接而被取消，它都会通过同一个状态机退出，而该状态机拥有所有 block 释放操作（深度文章 04 介绍了 `finish_requests` / `_free_request` 以及延迟的、受 GPU step fence 约束的释放）。`EngineCore` 从不直接释放 block 或推进计数器；每一次生命周期变更都封装在 `self.scheduler` 之后。

### Async 镜像路径

在线路径以相同顺序注册相同的两侧，只有一项新增内容——在提交*之前*创建每请求输出邮箱。

源码锚点：[`vllm/v1/engine/async_llm.py:400-412`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L400-L412)

```python
    async def _add_request(
        self,
        request: EngineCoreRequest,
        prompt: str | None,
        parent_req: ParentRequest | None,
        index: int,
        queue: RequestOutputCollector,
    ):
        # Add the request to OutputProcessor (this process).
        self.output_processor.add_request(request, prompt, parent_req, index, queue)

        # Add the EngineCoreRequest to EngineCore (separate process).
        await self.engine_core.add_request_async(request)
```

逐步解读。调用方（`AsyncLLM.add_request`）首先构建一个 `RequestOutputCollector`——稍后将由 `generate()` drain 的单槽邮箱（文章 01 [第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊)）——并将其作为 `queue` 传入这里。`_add_request` 先向 `OutputProcessor` 注册 `RequestState`（此时它已持有该邮箱），*然后* `await` 向 engine core 提交请求。注释明确指出了进程划分：输出处理位于“此进程”，engine core 位于“单独的进程”。由于两个步骤位于同一条不可交错的 `await` 链中，并且注册发生在等待提交完成之前，因此可以证明，在该请求的任何输出产生之前，邮箱一定已经存在。同步 `LLMEngine.add_request` 自然获得了相同的保证——它的两次注册只是同一线程上的普通顺序调用。先注册再提交是两条路径共同的不变量；asyncio 只是让这种顺序变成必须刻意保证的事项。

<a href='images/vllm-01-06-add-request.svg' target='_blank'><img src='images/vllm-01-06-add-request.svg' alt='vllm-01-06-add-request'></a>

<p class='figure-caption'>`add_request` 在两侧注册请求——`OutputProcessor`（返回路径）和 `EngineCore`→`Scheduler`（forward 路径）——其中 `n>1` 在一个 `ParentRequest` 下 fan-out 为多个子请求，而 `EngineCoreRequest`→`Request` 转换则标志着请求跨入 scheduler 所有权。</p>

### 这一边界带来的收益

请求进入 engine 的瞬间就会建立四个不变量，而后续每个阶段都依赖它们：

- **先注册，再提交。** 输出侧总是在触发 forward 侧之前完成注册，因此输出绝不可能抵达一个未知请求（[`llm_engine.py:274-276`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L274-L276)；[`async_llm.py:409-412`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L409-L412)）。
- **一个用户请求，n 个扁平的 engine 请求。** 并行采样会在一个 `ParentRequest` 下扇出为相互独立的子请求；scheduler 和 worker 永远看不到它们之间的同级关系，而调用方会收到父 ID（[`llm_engine.py:279-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L279-L294)）。
- **类型变化标志着所有权转移。** 传输层的 `EngineCoreRequest` 会在 `preprocess_add_request` 中变成内部的 `Request`；在 `scheduler.add_request` 下游，传输层结构体不再存在（[`core.py:855-877`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L855-L877)，`403`）。
- **接纳与中止共用同一个状态机。** `EngineCore` 负责验证并委托；它本身从不释放 block，也不修改生命周期状态，而中止只是 `finish_requests(..., FINISHED_ABORTED)`（[`core.py:403`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L403)，`409-415`）。从这里开始，一切都归 scheduler 所有——而这正是文章 01 [第 7 节](#7-调度一个步骤概览) 接续展开的地方。

## 6. Engine Step：调度、执行、处理输出

到目前为止的一切都属于适配：外观层规范化了输入，输入处理器构建了一个 `EngineCoreRequest`，而客户端抽象将它跨进程边界传递。现在，我们来到了整个系统围绕其组织的事务。“Inside vLLM”导览直接点明了这一心智模型——每个 engine step 都会“选择请求、运行模型、采样 token、更新请求状态，并在请求完成时释放资源”（[Inside vLLM](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）。在 V1 源码中，这只是一个很小的方法 `EngineCore.step()`，而它的职责就是保持*小巧*：一次守卫检查、一次调度、一次非阻塞执行、一次中止排空，以及一次提交。逐行阅读它，是了解各层分别拥有什么的最快方式。

<a href='images/vllm-01-02-engine-step.svg' target='_blank'><img src='images/vllm-01-02-engine-step.svg' alt='vllm-01-02-engine-step'></a>

<p class='figure-caption'>一个 engine step：schedule → execute → sample → commit 事务，以及它所处的两个所有权边界。</p>

### `EngineCore.step()` 的四项工作

概念：一个 step 就是一个事务。它询问 scheduler 要运行什么，在不阻塞的情况下启动 forward pass，并发准备结构化输出 bitmask，在执行推迟采样时进行采样，排空在当前帧期间抵达的所有中止请求，然后才将采样得到的 token 提交回请求状态。

源码：[`vllm/v1/engine/core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)

```python
    def step(self) -> tuple[dict[int, EngineCoreOutputs], bool]:
        """Schedule, execute, and make output.

        Returns tuple of outputs and a flag indicating whether the model
        was executed.
        """

        # Check for any requests remaining in the scheduler - unfinished,
        # or finished and not yet removed from the batch.
        if not self.scheduler.has_requests():
            return {}, False
        scheduler_output = self.scheduler.schedule(self._should_throttle_prefills())
        future = self.model_executor.execute_model(scheduler_output, non_block=True)
        grammar_output = self.scheduler.get_grammar_bitmask(scheduler_output)
        with (
            self.log_error_detail(scheduler_output),
            self.log_iteration_details(scheduler_output),
        ):
            model_output = future.result()
            if model_output is None:
                model_output = self.model_executor.sample_tokens(grammar_output)

        # Before processing the model output, process any aborts that happened
        # during the model execution.
        self._process_aborts_queue()
        engine_core_outputs = self.scheduler.update_from_output(
            scheduler_output, model_output
        )

        return engine_core_outputs, scheduler_output.total_num_scheduled_tokens > 0
```

逐步解读：

**工作 0——守卫（[`core.py:488-489`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L488-L489)）。** `if not self.scheduler.has_requests(): return {}, False`。scheduler 为空时不会运行模型。它上方的注释——“未完成，或已完成但尚未从 batch 中移除”——至关重要：`has_requests()` 的范围刻意比“仍在生成的请求”更宽。只要仍有尚未刷新给客户端的已完成请求 ID，或者 KV connector 仍在排空，它就会保持 `True`，从而让循环再执行一个 step，以真正*发出*这些完成事件并释放延迟释放的 block，之后才允许进入空闲状态。该谓词的内部机制属于文章 04；这里仅需知道，守卫计算的是请求生命周期的尾部，而不只是其中段。

**工作 1——调度（[`core.py:490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490)）。** `scheduler.schedule(self._should_throttle_prefills())` 返回一个 `SchedulerOutput`，且*不运行任何模型代码*。它决定运行哪些请求、每个请求获得多少个新 token、分配或复用哪些 KV block、抢占哪些请求，以及 worker 需要哪些 attention/采样元数据。`_should_throttle_prefills()` 在基类中是 `False`（[`core.py:474-477`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L474-L477)），只有数据并行 engine 会为 prefill 均衡而覆盖它。“为哪些请求分配多少 token”究竟意味着什么——连续 batching、分块 prefill、prefix-cache 复用——是文章 05 的完整主题；文章 01 只说明，这一次调用就是该 step 的完整调度决策。

**工作 2——执行、重叠、采样（[`core.py:491-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L491-L499)）。** 这是连接各环节的关键技巧。`execute_model(scheduler_output, non_block=True)` 不会阻塞等待 GPU，而是立即返回一个 `Future`。这段空隙由 `get_grammar_bitmask(scheduler_output)` 填补：它会在 forward pass 运行的*同时*，在 CPU 上构建结构化输出 token 掩码。`future.result()` 是同步点。`model_output is None` 哨兵值表示 executor 将采样推迟到单独的调用 `sample_tokens(grammar_output)`，因此结构化输出掩码会在采样时应用于*当前* step 的 logits。`execute_model` 背后的 executor→worker→model-runner→logits 链路属于文章 08/09；`sample_tokens` 背后的 logits→token-ID 步骤属于文章 10。对于端到端路径，有两个事实很重要：语法 bitmask 来自 *scheduler*，而不是 HTTP 层；并且 CPU 掩码准备通常没有额外开销，因为它被隐藏在 GPU 延迟之下。

**中止窗口（[`core.py:501-503`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L501-L503)）。** `self._process_aborts_queue()` 在 `future.result()` *之后*运行——此时 GPU 帧已经完成——但在 `update_from_output` *之前*运行。这个顺序正是关键所在：GPU 忙碌期间抵达的外部取消会在采样 token 被合并进请求状态之前得到处理，因此在帧执行期间被取消的请求绝不会继续推进。排空辅助函数（[`core.py:634-642`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L634-L642)）会将整个队列合并为一次 `abort_requests` 调用；由于中止一个已经完成的请求是幂等的，因此可以安全地将中止请求同时放入两个队列（参见文章 04）。

**工作 3——提交（[`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506)）。** `scheduler.update_from_output(scheduler_output, model_output)` 是采样 token 转化为请求进度的地方：追加输出 ID、设置完成原因、释放已完成的 KV block。它返回一个按所属客户端组织的 `dict[client_index → EngineCoreOutputs]`，而元组的第二个元素——`scheduler_output.total_num_scheduled_tokens > 0`——就是循环包装器所消费的 `model_executed` 标志。

该方法维护的不变量是：**调度是乐观的，但只有得到模型输出后才会提交进度。** 调度会在 GPU 执行前作出决策并进行分配；在 `update_from_output` 根据模型实际产出的结果对计划进行协调之前，请求状态的任何部分——token 数量、完成状态、block 释放——都不会发生变化。在没有 `SchedulerOutput` 的情况下运行模型，或在采样完成前推进计数器，都会使 GPU 工作与 KV/block 记账脱节，并让 block 复用的正确性依赖于时序运气。中止窗口和守卫正是同一规则的两个边界：请求可以一直到提交前进入或离开 batch，但不能在提交期间这样做。

### 为什么调用方看不到这个方法

`EngineCore.step()` 返回的是 `EngineCoreOutputs`——token ID、完成标志、按客户端划分的路由——而不是面向用户的 `RequestOutput`。离线调用方从不直接接触它。`LLM._run_engine` 的排空循环实际调用的是 `LLMEngine.step()`，这是一个同步包装器，与核心循环位于不同文件和不同进程中。

源码：[`vllm/v1/engine/llm_engine.py:296-334`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L296-L334)

```python
    def step(self) -> list[RequestOutput | PoolingRequestOutput]:
        if self.should_execute_dummy_batch:
            self.should_execute_dummy_batch = False
            self.engine_core.execute_dummy_batch()
            return []

        # 1) Get EngineCoreOutput from the EngineCore.
        with record_function_or_nullcontext("llm_engine step: get_output"):
            outputs = self.engine_core.get_output()

        # 2) Process EngineCoreOutputs.
        with record_function_or_nullcontext("llm_engine step: process_outputs"):
            iteration_stats = IterationStats() if self.log_stats else None
            processed_outputs = self.output_processor.process_outputs(
                outputs.outputs,
                engine_core_timestamp=outputs.timestamp,
                iteration_stats=iteration_stats,
            )
            self.output_processor.update_scheduler_stats(outputs.scheduler_stats)

        # 3) Abort any reqs that finished due to stop strings.
        with record_function_or_nullcontext("llm_engine step: abort_requests"):
            self.engine_core.abort_requests(processed_outputs.reqs_to_abort)

        # 4) Record stats
        with record_function_or_nullcontext("llm_engine step: record_stats"):
            if (
                self.logger_manager is not None
                and outputs.scheduler_stats is not None
                and len(outputs.outputs) > 0
            ):
                self.logger_manager.record(
                    scheduler_stats=outputs.scheduler_stats,
                    iteration_stats=iteration_stats,
                    mm_cache_stats=self.renderer.stat_mm_cache(),
                )
                self.do_log_stats_with_interval()

        return processed_outputs.request_outputs
```

<a href='images/vllm-01-22-step-wrapper-feedback.svg' target='_blank'><img src='images/vllm-01-22-step-wrapper-feedback.svg' alt='vllm-01-22-step-wrapper-feedback'></a>

<p class='figure-caption'>`LLMEngine.step()` 对核心循环进行包装：`get_output()`（多态接缝）→ `output_processor.process_outputs(...)` → `engine_core.abort_requests(reqs_to_abort)`，并将由停止字符串触发的完成状态反馈回去，使*下一个* `EngineCore.step()` 在其中止窗口停止这些请求——这就是为什么 `EngineCoreOutput.finished` 与处理器的完成原因可能会在一个 step 内合理地出现分歧。</p>

逐步解读：

- **`get_output()` 是多态接缝（第 304 行）。** 它在两种传输方式上的阻塞签名完全相同（[第 4 节](#4-engine-边界进程内-client-与多进程-client)）。使用 `InprocClient` 时，它会在调用方线程上内联*运行*一个 `EngineCore.step()` 并返回输出；使用 `SyncMPClient` 时，它会阻塞等待一个队列，该队列由后台线程从核心进程的忙循环中填充。离线的 `LLMEngine.step()` 按照 engine 位于本地的方式编写，而无论它实际上是否位于本地，客户端抽象都会让这一假设成立。
- **`process_outputs`（第 309 行）是 token ID 转化为文本的地方。** `OutputProcessor` 进行增量反 token 化、检查停止字符串，并具体化 `RequestOutput`。这是返回路径的边界，归本图谱的文章 10 所有；这里的重点是，它位于 `EngineCore` *之外*。
- **`abort_requests`（第 318 行）闭合了循环。** 停止*字符串*无法在核心内部检测——它们需要反 token 化后的文本——因此 `process_outputs` 返回 `reqs_to_abort`，而这一行会将它们反馈给 engine。这些 ID 会进入 `aborts_queue`，并由*下一个* `EngineCore.step()` 在其中止窗口排空。这就是为什么 `EngineCoreOutput.finished` 与处理器的完成原因可能会在一个 step 内合理地出现分歧。
- **虚拟 batch 快速路径（第 297—300 行）**用于数据并行锁步：即使某个 rank 没有工作，它仍然必须执行一个空 batch，这样其对等 rank 才能继续推进。

不变量是：**`EngineCore` 拥有 schedule/execute/commit 事务；`OutputProcessor` 拥有 API 语义。** 第一个 token 不会直接从核心返回，恰恰是因为“第一个 token”是一个面向用户的概念——它需要进行反 token 化、停止字符串检查以及 `RequestOutput` 构建，而 hot loop 刻意不执行这些操作。将 `EngineCoreOutputs` 暴露给调用方，会把内部调度帧泄漏到 API 级结果中。

### 为后台进程包装同一个 step

在默认的多进程部署中（[第 4 节](#4-engine-边界进程内-client-与多进程-client)），`EngineCore.step()` 根本不在调用方线程上运行——它运行在 engine 进程内部的永久循环中：

源码：[`vllm/v1/engine/core.py:1259-1267`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1259-L1267)

```python
    def run_busy_loop(self):
        """Core busy loop of the EngineCore."""
        while self._handle_shutdown():
            # 1) Poll the input queue until there is work to do.
            self._process_input_queue()
            # 2) Step the engine core and return the outputs.
            self._process_engine_step()

        raise SystemExit
```

每轮都会接收客户端输入，然后通过 `_process_engine_step`（[`core.py:1300-1317`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1300-L1317)）恰好执行一个步骤；该方法会调用 `self.step_fn()`，将每个 `(client_index, EngineCoreOutputs)` 对推入输出队列，供 IO 线程序列化，运行 spec-decode 的 `post_step` hook，并且——如果该步骤没有调度任何可运行内容但仍有请求——休眠 1 ms 以让出 GIL，使后台 KV-transfer 线程能够取得进展。`step_fn` 在构造时就一次性绑定到 `step` 或 pipeline-parallel 的 `step_with_batch_queue`（[`core.py:221-224`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L221-L224)），因此循环不需要在每次迭代时根据并行模式进行分支。忙循环机制、关闭时的排空操作以及已完成请求的记账，是第 04 篇文章深入讨论的主题；第 01 篇文章在此只强调一个结构性结论：**同步离线 `LLMEngine.step()` 与异步忙循环，本质上是同一个 `EngineCore.step()` transaction 的两种不同封装**——对于阻塞式离线调用方，是内联执行并返回；对于流式服务器，则是循环执行并入队。transaction 本身保持不变；变化的只有驱动它的方式。

本步骤内部机制的交叉引用：**05** 介绍 `schedule()` 决定什么；**08/09** 介绍 `execute_model` 背后发生什么；**10** 介绍 `sample_tokens`；**12** 介绍 `post_step` draft-token 反馈；**04** 介绍忙循环、关闭以及已完成请求的生命周期。下一节将放大这些箭头中的第一个——scheduler。

## 7. 调度一个步骤（概览）

我们刚刚看到 `EngineCore.step()` 以一行代码开场——`scheduler.schedule(...)`——随后将一个 `SchedulerOutput` 交给 executor。本节仍保持本文其余部分所采用的概览视角：它解释 *scheduler 决定什么*、让 prefill、decode、chunked prefill、prefix caching 和 speculative decoding 全部共享单一循环的 *一个核心思想*，以及 *每个方向上有哪些内容跨越 scheduler 边界*。内部机制——队列、token 预算记账、`allocate_slots`、抢占——属于第 05 篇文章（Scheduler：Continuous Batching 与 Chunked Prefill）。这里我们只把这个组件接入请求路径。

### scheduler 决定的是 token，而不是 tensor

scheduler 是一个纯规划器。它运行在 EngineCore 进程内的 CPU 上，绝不会接触 GPU。一次调用只回答一个问题：*在我跟踪的请求中，哪些请求要在本步骤运行，每个请求要前进多少个 token？* 答案是一个 `SchedulerOutput`——也就是一份计划。执行这份计划，是同一个 `step()` 中独立且稍后的阶段。

源码定位：[`vllm/v1/engine/core.py:488-490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L488-L490)

```python
        if not self.scheduler.has_requests():
            return {}, False
        scheduler_output = self.scheduler.schedule(self._should_throttle_prefills())
```

源码定位：[`vllm/v1/engine/core.py:474-477`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L474-L477)

```python
    def _should_throttle_prefills(self) -> bool:
        """Whether to defer new prefills this step (DP prefill balancing).
        Overridden by the DP engine core; never throttles otherwise."""
        return False
```

逐步解读：

- `:488-489` 处的保护条件意味着，没有计划时绝不会运行模型；如果 scheduler 中没有任何内容（甚至连已完成但尚未 flush 的请求也没有——参见第 04 篇文章），该步骤就会短路并报告 `model_executed = False`。
- `schedule()` 返回一个 `SchedulerOutput` 后会立即返回——没有 forward pass，也没有 logits。`step()` 中此行之后的所有内容（`execute_model` future、grammar bitmask、`sample_tokens`、`update_from_output`）都在消费这份计划；它们都不属于计划本身。
- 在基类中，`_should_throttle_prefills()` 为 `False`，只有 data-parallel engine core 会覆盖它，以便为了跨 replica 平衡而推迟新的 prefill（第 11 篇文章，分布式推理与并行）。对于你正在追踪的单 engine 路径，该参数恒为 `False`。

这一边界所保护的不变量是：**规划与执行相互解耦，并且只有在模型输出返回后才提交进度。** scheduler 在制定计划时会乐观地推进自身的记账状态（`_update_after_schedule`，[`scheduler.py:1169-1217`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1169-L1217)），但 *token 结果* 要到同一步骤末尾才由 `update_from_output` 合并进来。第 04 篇文章会介绍这条“输出后提交”规则；对于请求路径而言，关键在于可以放心地将 `schedule()` 理解为“做出决定”，它与“运行”完全分离。

### 一个核心思想：没有 prefill 阶段，也没有 decode 阶段

V1 博客这样概括其核心简化：V1 不再将 prefill 和 decode 视为不同的 scheduler 阶段，而是统一处理所有 token，因此一次调度决策在概念上就变成一个字典，即 `{request_id: num_tokens}`。于是 chunked prefill 自然而然地得到支持，因为长 prompt 只不过是一个在本步骤中仅获分配部分 token 预算的请求（[V1 博客](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。`schedule()` 顶部的源码也表达了同一个意思。

源码定位：[`vllm/v1/core/sched/scheduler.py:396-407`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L396-L407)

```python
    def schedule(self, throttle_prefills: bool = False) -> SchedulerOutput:
        self.current_step += 1
        # NOTE(woosuk) on the scheduling algorithm:
        # There's no "decoding phase" nor "prefill phase" in the scheduler.
        # Each request just has the num_computed_tokens and
        # num_tokens_with_spec. num_tokens_with_spec =
        # len(prompt_token_ids) + len(output_token_ids) + len(spec_token_ids).
        # At each step, the scheduler tries to assign tokens to the requests
        # so that each request's num_computed_tokens can catch up its
        # num_tokens_with_spec. This is general enough to cover
        # chunked prefills, prefix caching, speculative decoding,
        # and the "jump decoding" optimization in the future.
```

<a href='images/vllm-01-23-counter-model.svg' target='_blank'><img src='images/vllm-01-23-counter-model.svg' alt='vllm-01-23-counter-model'></a>

<p class='figure-caption'>统一计数器模型：调度通过在本步骤授予一定数量的 token，来缩小 `num_computed_tokens`（已填充的 KV）与 `num_tokens_with_spec`（prompt + output + draft）之间的差距——全新的 prompt、chunked prefill、单 token decode、prefix-cache 跳转以及 speculative draft token，全都是相同的缩小差距操作，因此请求路径只会根据“多少个 token”进行分支。</p>

逐步解读：

- 每个请求都携带两个计数器：`num_computed_tokens`（KV cache 已填充到什么位置）和 `num_tokens_with_spec`（prompt + 已生成 token + 所有 speculative draft token）。调度就是在本步骤中用一定数量的 token 来缩小二者之间的差距。
- 一个全新的 prompt 从 `num_computed_tokens = 0` 开始，并且差距很大，因此看起来像一个很大的 token 需求；一个正在 decode 的请求，其差距为一（在 speculation 下还要加上 draft token）。两者执行的是同一个操作——“推进 `num_computed_tokens`”——区别只在于获批的数量。
- 由于获批数量可以 *小于* 差距，chunked prefill 不需要特殊代码路径：它只是一个没有在单个步骤中获得完整差距额度的 prompt。
- 同一条注释还将 prefix caching 和 speculative decoding 列为这种通用性的具体实例：prefix caching 通过复用已计算的 block 来缩小请求的有效差距（第 07 篇文章，Automatic Prefix Caching）；speculation 则通过加入待验证的 draft token 来增大 `num_tokens_with_spec`（第 12 篇文章，Speculative Decoding）。

不变量是：**一个统一的计数器模型吸收了 V0 中作为独立机制存在的四项功能。** 请求路径绝不会根据“这是 prefill 还是 decode”来分支；它只根据“多少个 token”来分支，而每项高级功能都表示为对 token 数量的调整。

### 优先级：先填满 decode，再处理等待中的 prefill

在每个步骤的 token 预算固定时，scheduler 会优先处理已经位于 `running` 队列中的请求（正在进行的 decode），然后才用剩余预算接纳等待中的 prefill（[深入 vLLM](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）。源码中的循环顺序将这一点直接体现出来。

源码定位：[`vllm/v1/core/sched/scheduler.py:440-442`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L440-L442)

```python
        # First, schedule the RUNNING requests.
        req_index = 0
        while req_index < len(self.running) and token_budget > 0:
```

逐步解读：

- 首先依据 `token_budget` 排空 `running`；第二轮处理（未展示——见第 05 篇文章）会使用所有剩余预算接纳等待中的请求。
- 这正是 continuous batching 与 chunked prefill 能在 *同一个* 循环中共存，而不是在不同阶段间交替执行的原因：一个步骤可以同时承载一批正在进行的 decode，*以及* 一个新 prompt 的一部分 prefill，因为二者都只是针对同一预算授予 token。

规则是：**对延迟敏感、正在进行的 decode，绝不会因为一个新到达的大型 prompt 而得不到 token 预算**——该 prompt 只能使用剩余预算，并在必要时跨多个步骤进行分块。调度算法的队列机制、抢占和预算计算属于第 05 篇文章的主题；请求路径只需要了解这条优先级规则及其单循环结果。

### 向外跨越边界的内容：计划与两个完成通道

`SchedulerOutput` 是请求路径从 CPU 规划传递到 GPU 执行的 payload：它指定新的请求和已缓存的请求、每个请求的 token 数量、KV block 分配、spec-decode token 以及 attention 元数据。但它还携带一个很容易被忽略的带外通道——*自上一步以来已经完成* 的请求集合——以便下游 worker 可以丢弃这些请求各自的状态。

源码定位：[`vllm/v1/core/sched/scheduler.py:1105-1114`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1105-L1114)

```python
            preempted_req_ids=self.reset_preempted_req_ids,
            # finished_req_ids is an existing state in the scheduler,
            # instead of being newly scheduled in this step.
            # It contains the request IDs that are finished in between
            # the previous and the current steps.
            finished_req_ids=self.finished_req_ids,
            free_encoder_mm_hashes=self.encoder_cache_manager.get_freed_mm_hashes(),
            new_block_ids_to_zero=new_block_ids_to_zero,
            num_spec_tokens_to_schedule=num_spec_tokens_to_schedule,
        )
```

每次调度时，该集合通过 *重新赋值* 而不是 `clear()` 来重置，这正是为了让刚刚发出的 `SchedulerOutput` 继续持有自己的引用：

源码定位：[`vllm/v1/core/sched/scheduler.py:1213-1217`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1213-L1217)

```python
        # Clear the finished and preempted request IDs.
        # NOTE: We shouldn't just clear() here because it will also affect
        # the scheduler output.
        self.finished_req_ids = set()
        self.reset_preempted_req_ids = set()
```

请求完成的消息还必须通过第二个通道 *传回客户端*。释放请求时，会按客户端记录其 id，而 `update_from_output` 会将这些 id 附加到传出的 `EngineCoreOutputs.finished_requests`：

源码定位：[`vllm/v1/core/sched/scheduler.py:1833-1845`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1833-L1845)

```python
        finished_req_ids = self.finished_req_ids_dict
        if finished_req_ids:
            # Include ids of requests that finished since last outputs
            # were sent.
            for client_index, finished_set in finished_req_ids.items():
                # Set finished request set in EngineCoreOutputs for this client.
                if (eco := engine_core_outputs.get(client_index)) is not None:
                    eco.finished_requests = finished_set
                else:
                    engine_core_outputs[client_index] = EngineCoreOutputs(
                        finished_requests=finished_set
                    )
            finished_req_ids.clear()
```

逐步解读：

- `finished_req_ids`（一个 `set`）会搭乘 *下一个* `SchedulerOutput`，使 worker 能够从其持久 batch 状态中移除已完成的请求（回想一下 V1 的 differential-batch 设计，其中 worker 会跨步骤缓存请求状态）。
- `finished_req_ids_dict`（按 `client_index` 划分）会搭乘 *传出的* `EngineCoreOutputs`，使 frontend 的输出处理器知道请求已经完成，并能够回收其 `RequestState`。这两个集合都在 `_free_request` 中填充（[`scheduler.py:2116-2118`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L2116-L2118)）。
- 对请求路径而言，其结果是——这里只做概述，详细内容将在第 04 篇文章中展开——**两个消费者会在两个不同的时钟上观察到请求完成。** 面向客户端的通知搭乘 *当前* 步骤的 `EngineCoreOutputs`（`finished_req_ids_dict` 会在当前这个 `update_from_output()` 结束时合并进来，[`scheduler.py:1833-1845`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1833-L1845)），因此 frontend 可以立即关闭 stream。只有 worker 侧的清理需要等待 *下一个* `SchedulerOutput` 来携带 `finished_req_ids`。循环的活性判定条件（`has_requests()`）被刻意设计得足够宽松，以便让 engine 保持唤醒并完成 worker 侧的 flush——它不会延迟客户端通知。

这一性质是：**完成一个请求属于记账操作，它会按照两个时钟分流给两个消费者**——worker（在下一步中丢弃状态）和 client（使用当前步骤的输出关闭流）——而且这两个通道都不是模型的 forward pass。

### 在 GPU 屏障之后释放 block

scheduler 掌握 KV block 的所有权，而释放 block 正是“现在规划、稍后执行”这种分离会带来正确性风险的地方：一个请求可能已经完成，但它所参与的 forward pass 仍在写入其 KV。因此，block 的释放可以被*推迟*，并由正在执行的步骤设置屏障。

源码定位：[`vllm/v1/core/sched/scheduler.py:2138-2151`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L2138-L2151)

```python
    def _free_request_blocks(self, request: Request):
        """Free the request's KV blocks, deferring the return to the block
        pool when an in-flight GPU step may still write them.
        """
        if not self.defer_block_free or (
            # Last scheduled step already processed: no in-flight write remains
            # (always the case for a normal finish), so free now.
            request.last_sched_seq <= self.processed_step_seq
        ):
            self.kv_cache_manager.free(request)
            return
        blocks = self.kv_cache_manager.pop_blocks_for_free(request)
        if blocks:
            self.deferred_frees.append((self.sched_step_seq, blocks))
```

<a href='images/vllm-01-24-finish-fanout.svg' target='_blank'><img src='images/vllm-01-24-finish-fanout.svg' alt='vllm-01-24-finish-fanout'></a>

<p class='figure-caption'>完成操作会按照两个时钟分流：`finished_req_ids` 随*下一个* `SchedulerOutput` 传递，以便 worker 从其持久 batch 中移除该请求；而 `finished_req_ids_dict` 随*当前*步骤的 `EngineCoreOutputs.finished_requests` 传递，以便 client 结束其 `RequestState`——同时，`_free_request_blocks` 要么立即释放，要么将 block 暂存到 `deferred_frees` 中，直至所有正在执行的 GPU 写入完成。</p>

逐步解读：

- 在常见情况下（`not self.defer_block_free`，或者该请求最后一次被调度的步骤已经处理完毕），会立即释放——正常的生成结束总会进入这个分支。
- 当异步调度可能仍有一个 GPU frame 正在写入该请求的 block 时（`last_sched_seq > processed_step_seq`），这些 block 会按步骤序列暂存到 `deferred_frees` 中，并且只有在该步骤完成后才会归还。

从概览层面来看，其不变量是：**只要已入队的 GPU 写入仍可能访问某个 block，该 block 就绝不会被归还到池中**——block 复用的正确性不能依赖时序上的运气。分页机制、空闲 block 队列和 prefix cache 哈希位于文章 06（KV Cache Manager 与 Paged KV Cache）和文章 07（Automatic Prefix Caching）中；请求路径只需要知道，scheduler 是 block 生命周期的唯一所有者，并且释放操作受屏障保护。

### 唯一的循环，以及下一步去向

以上所有内容可以归结为一句话：scheduler 是唯一一个将 continuous batching、chunked prefill、prefix caching 和 speculative decoding 全部纳入同一调度循环的位置，其表现形式是依据每步预算授予 token。请求在 `EngineCore` 调用 `scheduler.schedule(...)` 时进入循环，以供 GPU 使用的 `SchedulerOutput` 计划离开循环，而其完成事件则通过两个旁路通道离开——一个通向 worker，另一个通向 client。这就是文章 01 要求你掌握的全部内容。关于队列算法、预算核算、抢占和 `allocate_slots`，请继续阅读文章 05（Scheduler: Continuous Batching and Chunked Prefill）；关于 block 分配和分页，请阅读文章 06；关于前缀复用，请阅读文章 07；关于草稿 token 调度，请阅读文章 12。下一节（[第 8 节](#8-模型执行从-executor-到-logits概览)）将沿着该 `SchedulerOutput` 计划跨越 executor 边界并进入 GPU。

## 8. 模型执行：从 Executor 到 Logits（概览）

[第 7 节](#7-调度一个步骤概览) 刚刚展示了 scheduler 发出一个 `SchedulerOutput`：该计划指定当前步骤运行哪些请求，以及每个请求贡献多少个 token。本节将沿着该计划跨越 token 出现之前的最后两个所有权边界——`EngineCore` → executor → worker → model runner → logits。本节保持在架构图的概览层次。让 forward pass 变得高效的 PagedAttention kernel 属于文章 08；输入 tensor 的准备和 CUDA graph 属于文章 09；将 logits 转换为 token ID 属于文章 10。这里的任务是说明其连接关系：一个方法调用如何分流到一个或多个 GPU，以及隐藏状态在哪里变成 logits。

回顾 `EngineCore.step()` 中将任务移交给执行阶段的两行代码：

[`vllm/v1/engine/core.py:490-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490-L499)

```python
        scheduler_output = self.scheduler.schedule(self._should_throttle_prefills())
        future = self.model_executor.execute_model(scheduler_output, non_block=True)
        grammar_output = self.scheduler.get_grammar_bitmask(scheduler_output)
        with (
            self.log_error_detail(scheduler_output),
            self.log_iteration_details(scheduler_output),
        ):
            model_output = future.result()
            if model_output is None:
                model_output = self.model_executor.sample_tokens(grammar_output)
```

`self.model_executor` 是一个 `Executor`。下面的所有内容，就是这两个调用——`execute_model` 和 `sample_tokens`——实际到达的地方。

<a href='images/vllm-01-07-execution-path.svg' target='_blank'><img src='images/vllm-01-07-execution-path.svg' alt='vllm-01-07-execution-path'></a>

<p class='figure-caption'>`SchedulerOutput` 通过 `collective_rpc` 跨越 executor 边界，分流到一个或 N 个 worker，并返回唯一权威 worker 的 `ModelRunnerOutput`（最后一个 PP stage 的第一个 TP rank）。</p>

### Executor 边界归结为一个方法：`collective_rpc`

**概念。** 正如 `EngineCoreClient`（[第 4 节](#4-engine-边界进程内-client-与多进程-client)）屏蔽了 engine core 是位于进程内还是位于 ZMQ socket 之后，`Executor` 也屏蔽了模型是在一个 GPU 还是多个 GPU 上运行。engine core 从不直接寻址某个 worker；它指定一个*操作*和一个*目标集合*，并让 executor 进行广播。

**源码定位。** [`vllm/v1/executor/abstract.py:221-227`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L221-L227) 和 `:241-247`。

```python
    def execute_model(
        self, scheduler_output: SchedulerOutput, non_block: bool = False
    ) -> ModelRunnerOutput | None | Future[ModelRunnerOutput | None]:
        output = self.collective_rpc(  # type: ignore[call-overload]
            "execute_model", args=(scheduler_output,), non_block=non_block
        )
        return output[0]
```

```python
    def sample_tokens(
        self, grammar_output: GrammarOutput | None, non_block: bool = False
    ) -> ModelRunnerOutput | Future[ModelRunnerOutput]:
        output = self.collective_rpc(  # type: ignore[call-overload]
            "sample_tokens", args=(grammar_output,), non_block=non_block
        )
        return output[0]
```

**逐步解读。**

- 两个公共 executor 方法都是对 `collective_rpc("<method_name>", args=...)` 的轻量封装。指定的方法（`"execute_model"`、`"sample_tokens"`）会在组内的*每个* worker 上调用；executor 是一种分流原语。
- 此处*展示*的返回值是**抽象**基类的 `return output[0]`，但两个具体 executor 都覆写了这些方法，只向单个 worker 请求回复。`UniProcExecutor` 使用 `collective_rpc(..., single_value=True)`（[`uniproc_executor.py:108-131`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/uniproc_executor.py#L108-L131)）；`MultiprocExecutor` 使用 `unique_reply_rank=self.output_rank`（[`multiproc_executor.py:310-332`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L310-L332)），其中 `output_rank = _get_output_rank()` = `world_size − tp_size × prefill_context_parallel_size`——即*最后一个 PP stage* 的第一个 TP worker（[`multiproc_executor.py:498-512`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L498-L512)）。只有在纯 tensor parallel 或单 GPU 情况下，它才等于 global rank 0。在 tensor parallelism 下，每个 rank 都会在分片权重矩阵上运行相同的 forward pass，并在 all-reduce 后生成相同的 logits，因此任意 TP rank 的 `ModelRunnerOutput` 都具有权威性；在 pipeline parallelism 下，权威输出位于最后一个 stage，executor 只向该 stage 的这一个 rank 请求输出，而不是收集所有输出后再丢弃多余结果。
- `non_block=True` 正是[第 6 节](#6-engine-step调度执行处理输出)中的重叠机制能够工作的原因：`collective_rpc` 返回的是 `Future`，而不是已经物化的 `ModelRunnerOutput`，因此当 GPU forward pass 正在执行时，`EngineCore.step()` 可以在 CPU 上运行 `get_grammar_bitmask`，随后调用 `future.result()` 作为同步点。

**使用哪个具体 executor？** 在构造时，由 `Executor.get_class` 根据 `distributed_executor_backend` 一次性选定：

[`vllm/v1/executor/abstract.py:69-76`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L69-L76)

```python
        elif distributed_executor_backend == "mp":
            from vllm.v1.executor.multiproc_executor import MultiprocExecutor

            executor_class = MultiprocExecutor
        elif distributed_executor_backend == "uni":
            from vllm.v1.executor.uniproc_executor import UniProcExecutor

            executor_class = UniProcExecutor
```

对于单个 GPU，backend 会解析为 `UniProcExecutor`，其 `collective_rpc` 只是在一个进程内 worker 上调用该方法。对于 tensor/pipeline parallelism，backend 会解析为 `MultiprocExecutor`（文档称其为 `MultiProcExecutor`），它会将 RPC 转发给 worker 子进程；此外还存在基于 Ray 的 backend，其全部内容留到文章 11 讨论。架构文档以同样的方式概括了这种划分——tensor parallelism 使用 `MultiProcExecutor`，单 GPU 使用 `UniProcExecutor`（<https://docs.vllm.ai/en/stable/design/arch_overview/>）。

**不变量。** `EngineCore.step()` 中不包含任何针对 GPU 数量、并行度或传输方式的分支。模型执行被表达为“在 worker 组上调用 `execute_model`，并取得唯一权威 worker 的答案”。添加 tensor 或 pipeline parallelism 只会改变所构造的 `Executor` 子类（以及该答案来自哪个 rank），绝不会改变步骤循环。这与 engine client 一样，是一种与传输方式无关的契约，只不过下移了一层。*更深入的并行内部机制——`collective_rpc` 如何到达 worker 进程、TP all-reduce、PP micro-batching——属于文章 11。*

### 从 `SchedulerOutput` 到 forward pass：model runner

**概念。** 每个 worker 恰好拥有一个 model runner，而每个 model runner 恰好封装一个 `torch.nn.Module`——即实际模型（<https://docs.vllm.ai/en/stable/design/arch_overview/>）。当 `collective_rpc("execute_model", ...)` 到达 worker 时，它会调用 `GPUModelRunner.execute_model`；后者的首要任务并不是执行 forward pass，而是将 worker 的持久 batch 与 scheduler 的计划进行协调。

**源码定位。** [`vllm/v1/worker/gpu/model_runner.py:1122-1133`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1122-L1133)（节选；完整的协调过程属于文章 09）。

```python
            self.finish_requests(scheduler_output)
            ...
            self.add_requests(scheduler_output)
            self.update_requests(scheduler_output)
```

**逐步解读。**

- worker 会跨步骤维护一个*持久* batch，并且只是**应用 scheduler 的差异**：它不会在每次迭代时接收新构建的 tensor，而是移除已完成的请求、接纳新请求，并刷新存续请求的位置和 block table。这就是 V1 的“持久 / 差分 batch”，取代了 V0 每步重新创建 tensor 的方式（<https://vllm.ai/blog/2025-01-27-v1-alpha-release>）。上面省略的一个 guard（`total_num_scheduled_tokens == 0`）会直接返回 `kv_connector.no_forward(...)`，因此仅为 KV connector 记账而调度的步骤不会运行模型。完整的协调操作集合——`finish_requests`/`free_states`/`add_requests`/`update_requests`/`apply_staged_writes`——属于文章 09。
- 完成这段前置处理后，runner 会构建扁平化的输入 batch 并运行 module。所有活跃序列都会拼接成一个长“超级序列”；位置索引和 attention 元数据确保每个序列只能关注自身的 token，从而在无需右侧填充的情况下实现 continuous batching（<https://vllm.ai/blog/2025-09-05-anatomy-of-vllm>）。*输入 ID、位置、slot mapping、block table 的构建以及 CUDA graph 的捕获/重放属于文章 09；使用 block table 的 attention kernel 属于文章 08。*

**规则。** scheduler 的决策（`SchedulerOutput`）是 batch 成员关系的唯一事实来源；worker 的本地 batch 是该决策的物化缓存，通过差异进行修改，其自身永远不具有权威性。每一步都传输完整 tensor 虽然在正确性上可行，但会将 CPU 侧的 tensor 构建置于 GPU 的关键路径上——而这正是 V1 所消除的开销。

### 关键转折点：隐藏状态变成 logits

**概念。** 一次 forward pass 会为*每个*被调度的 token 生成隐藏状态，但每个请求只有最后一个位置需要投影到词表空间，以采样下一个 token。model runner 会先选择这些位置，然后执行投影。

**源码定位。** [`vllm/v1/worker/gpu/model_runner.py:1054-1058`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1054-L1058)。

```python
        sample_hidden_states = hidden_states[input_batch.logits_indices]
        logits = self.model.compute_logits(sample_hidden_states)
        if grammar_output is not None:
            # Apply grammar bitmask to the logits in-place.
            assert self.structured_outputs_worker is not None
```

**逐步解读。**

- `hidden_states` 在展平的 batch 中，每个已调度的 token 对应一行。`input_batch.logits_indices` 选出需要下一个 token 分布的行——每个序列的最后一个位置，以及验证推测性 draft token 时的额外位置。这正是惰性计算 logits 的全部意义：词表投影（`compute_logits`，一个 `hidden_dim × vocab_size` matmul）只在少数几行上运行，而不是在长 prefill 的每个 prompt token 上运行。
- `compute_logits` 应用语言模型 head（并且在 tensor parallelism 下，收集分片后的词表）以生成 `[num_sampled_positions, vocab_size]` logits。
- 如果 scheduler 为此步骤附加了 grammar bitmask，它会在采样之前，就在这里**原地**应用到 `logits`。这闭合了[第 6 节](#6-engine-step调度执行处理输出)中开启的循环：`get_grammar_bitmask` 在 forward pass 执行期间，由 engine-core CPU 线程并发计算，经由 `grammar_output` 传递，并准确落到为其调度的 batch 上。结构化输出约束通过遮蔽 logits 来实施，而不是事后过滤 token。

**这一性质。** 只有最终位置（以及 draft 验证位置）的隐藏状态会被投影到词表大小。对于一个包含 10,000 个 token 的 prompt，即使采用分块 prefill，该请求的每个已调度分块仍然只需支付一行词表投影的成本，而不是 10,000 行。并且由于 bitmask 是在生成*这些* logits 的同一次调用中应用的，grammar 约束绝不可能漂移到陈旧或不匹配的 batch 上。

### 执行/采样接缝：为什么采样可以是第二次调用

**概念。** [第 6 节](#6-engine-step调度执行处理输出)展示了 `EngineCore.step()` 调用 `execute_model`，然后——仅当结果为 `None` 时——调用 `sample_tokens(grammar_output)`。这个 `None` 是 worker 发出的一个刻意设计的信号：“我已运行 forward pass 并暂存了隐藏状态；再次调用我以进行采样。”

**源码锚点。** [`vllm/v1/worker/gpu/model_runner.py:1358-1371`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1358-L1371) 和 `:1392-1394`。

```python
    def sample_tokens(
        self, grammar_output: GrammarOutput | None
    ) -> AsyncOutput | ModelRunnerOutput | None:
        if self.execute_model_state is None:
            # The prior execute_model call must have failed.
            return None

        input_batch = self.execute_model_state.input_batch
        attn_metadata = self.execute_model_state.attn_metadata
        slot_mappings_by_layer = self.execute_model_state.slot_mappings_by_layer
        hidden_states = self.execute_model_state.hidden_states
        aux_hidden_states = self.execute_model_state.aux_hidden_states
        finished_req_ids = self.execute_model_state.finished_req_ids
        self.execute_model_state = None
```

```python
        sampler_output, num_sampled, num_rejected = self.sample(
            hidden_states, input_batch, grammar_output
        )
```

**逐步解读。**

- worker 的 `execute_model` 运行 transformer，将采样所需的一切保存到 `self.execute_model_state` 中（`hidden_states`、输入 batch、attention 元数据、已完成请求集合），然后在不采样的情况下返回——这在 executor 处表现为 `output[0] is None`，从而触发 `step()` 中的 `if model_output is None:` 分支。
- 随后，`sample_tokens(grammar_output)` 读取暂存状态并将其清除（因此该接缝在每个步骤中只能使用一次），然后调用 `self.sample(hidden_states, input_batch, grammar_output)`——也就是我们刚刚分析过其 logits 枢纽的同一个 `sample` 方法。
- 将执行与采样拆开可带来两个好处。第一，grammar bitmask 会在 GPU 忙碌时在 CPU 上计算，并且只需在采样调用时准备就绪，因此结构化输出通常不会引入串行 GPU 停顿。第二，它是插入 pipeline parallelism（只有最后一个 PP rank 进行采样；较早的 rank 返回仅包含 KV connector 的输出）和异步调度的自然位置。
- `sample` 方法还会根据 `input_batch.num_draft_tokens` 分叉：没有 draft token 时，它运行普通的 `Sampler`；有 draft token 时，它运行用于推测性 decode 的拒绝采样器。*该分叉属于第 12 篇文章；普通采样器的 temperature / top-p / top-k / penalty pipeline 属于第 10 篇文章。*

**这一设计。** 采样是一个以 `execute_model_state` 为键、可恢复的独立阶段。请求可以被中止，或者在 forward pass 完成与 token 被抽取之间的窗口内计算 grammar mask——这正是[第 6 节](#6-engine-step调度执行处理输出)在 `future.result()` 与 `update_from_output` 之间指出的中止窗口。

### 返回的内容

`sample_tokens` 将抽取的 token ID 封装到一个 `ModelRunnerOutput` 中，executor 再将权威 worker 的副本作为 `model_output` 返回给 `EngineCore.step()`。从这里开始由[第 6 节](#6-engine-step调度执行处理输出)接管：`update_from_output` 将这些 token 纳入请求进度，并释放已完成请求的 KV block。请注意一个会影响下游的重要细节——单个步骤的 `ModelRunnerOutput` 可以为每个请求携带**不止一个**新 token（推测性 decode、多 token 预测），因此“一个步骤、一个 token”只是常见情况，而不是不变量。

### 这里会交接到何处

本节列出了四个边界，并交叉引用其内部机制，而不是重复介绍：

- **Executor 扇出、跨 worker 进程的 `collective_rpc`、TP all-reduce、PP microbatching** → 第 11 篇文章（分布式推理与并行性）。
- **输入 tensor 准备、槽位映射、CUDA graph 捕获/重放** → 第 09 篇文章（worker 与 model runner）。
- **PagedAttention kernel 与 attention backend**，它们使用 block table → 第 08 篇文章。
- 应用于枢纽处所生成 logits 的 **`Sampler`——temperature、top-k/p、penalty、logprobs** → 第 10 篇文章。
- `num_draft_tokens` 分支上的**拒绝采样与 draft-token 验证** → 第 12 篇文章。

需要保留的心智模型是：`execute_model` 和 `sample_tokens` 是两个用于指定操作而非设备的 `collective_rpc` 调用；worker 将 scheduler 的差异转换为展平的 forward pass，只将最终位置投影为 logits，原地应用由 scheduler 持有的 grammar mask，然后进行采样——并返回权威 worker 的 `ModelRunnerOutput`，供 engine core 提交。

## 9. 从隐藏状态到采样 token（概览）

[第 8 节](#8-模型执行从-executor-到-logits概览)留下的请求距离答案还差一个数组：一个包含最终位置隐藏状态的 `[num_scheduled_logits, hidden_size]` tensor，它已被投影为驻留在 GPU 上的 `[·, vocab_size]` logits tensor。本节将补齐 GPU 侧的最后一道缺口——从 logits 到具体 token id——并说明在 V1 中，这道缺口是通过一次*独立且刻意设计为可延迟的*调用跨越的。决定一个 token 是否“良好”的内部机制（penalty、temperature、top-k/top-p、min-p、logprobs）是第 10 篇文章的完整主题；第 01 篇文章的任务仅仅是指出这道接缝、展示入口点，并沿返回路径追踪采样得到的 id。

### 采样被刻意设计为一次独立调用

概念：在 engine 步骤中（[第 6 节](#6-engine-step调度执行处理输出)），`execute_model` 运行 `non_block=True` 并返回一个 `Future`。当该 future 解析为 `None` 时，executor 已经*延迟*了采样，engine 会进行第二次调用——`sample_tokens`——并传入 GPU 忙碌期间在 CPU 上准备的 grammar bitmask。

源码：[`vllm/v1/engine/core.py:497-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L497-L499)

```python
            model_output = future.result()
            if model_output is None:
                model_output = self.model_executor.sample_tokens(grammar_output)
```

逐步解读：

- **`future.result()` 是 forward-pass 同步点。** 如果 worker 内联完成了采样，它会返回一个 `ModelRunnerOutput`；如果 worker 已计算隐藏状态，但在将其转换为 token 之前停止，则返回 `None`。
- **`None` 是延迟执行哨兵。** 它表示：“forward pass 已完成；logits 已存在；请单独请求我进行采样。”第二次调用 `sample_tokens(grammar_output)` 会传入结构化输出 mask——也就是前一行由 `self.scheduler.get_grammar_bitmask(...)` 计算的 `grammar_output`（[第 6 节](#6-engine-step调度执行处理输出)），该计算与 forward pass 并发执行。
- **mask 在采样时与 logits 汇合。** 由于 bitmask 是在 GPU 运行期间于 CPU 上构建的，并且只在这次 `sample_tokens` 调用中应用，因此它会落到*此*步骤、*此*步骤请求对应的 logits 上。

这道接缝所保护的不变量是：**结构化输出 bitmask 会准确应用到为其计算的 batch 上，并且 CPU mask 准备工作会与 forward pass 并发运行，而不是提前串行执行。** 将 forward 与 sample 拆开也为异步调度提供了切入点——engine 可以在步骤 N 的采样仍在进行时，开始调度步骤 N+1——同时不会让某一步的 grammar mask 泄漏到另一步的 logits 上。在不发生拆分的情况下（常见的同步情形），`future.result()` 已经携带采样得到的 `ModelRunnerOutput`，而 `if` 会被跳过；这道接缝在设计上是可选的，而不是强制开销。

### 跨越 executor 边界，与 `execute_model` 对称

概念：`sample_tokens` 使用相同的 `collective_rpc` 形式，跨越与 `execute_model` 相同的 executor 边界。engine loop 不知道也不关心其背后是一块 GPU 还是十六块 GPU。

源码：[`vllm/v1/executor/abstract.py:241-247`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L241-L247)

```python
    def sample_tokens(
        self, grammar_output: GrammarOutput | None, non_block: bool = False
    ) -> ModelRunnerOutput | Future[ModelRunnerOutput]:
        output = self.collective_rpc(  # type: ignore[call-overload]
            "sample_tokens", args=(grammar_output,), non_block=non_block
        )
        return output[0]
```

逐步解读：

- **`collective_rpc("sample_tokens", ...)` 将调用扇出到 worker 组**，而*抽象*基类返回 `output[0]`。两个具体 executor 都对此进行了重写：`MultiprocExecutor` 从单个 `output_rank` 请求回复——即最后一个 PP stage 的第一个 TP worker（[`multiproc_executor.py:310-332`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L310-L332)，`498-512`）——而 `UniProcExecutor` 使用 `single_value=True`（[`uniproc_executor.py:108-131`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/uniproc_executor.py#L108-L131)）；无论哪种方式，都只会返回一个 worker 的 `ModelRunnerOutput`，而不是先 gather 再丢弃。这与 `execute_model` 的模式逐字节完全一致（[`abstract.py:221-227`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L221-L227)）——forward 和 sample 在结构上是完全相同的 RPC，因此 `EngineCore.step()` 可以将它们视为对同一个统一 `Executor` handle 的两次调用。
- **每个 worker 都会进入 `GPUModelRunner.sample_tokens`**（[`model_runner.py:1358-1363`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1358-L1363)），它会取回在 `execute_model`（`self.execute_model_state`）期间暂存的隐藏状态和 `InputBatch`，并在最后一个 pipeline-parallel rank 上调用 `self.sample(hidden_states, input_batch, grammar_output)`（[`model_runner.py:1391-1394`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1391-L1394)）。非最后 PP rank 则会*接收*从最后一个 rank 广播而来的采样 token——采样只在最终隐藏状态所在之处执行一次。

规则是：**采样在隐藏状态所在之处运行，并位于与 forward pass 相同的 executor 契约之后。** engine 从不直接访问 worker；TP/PP 扇出与最后 rank 采样规则属于第 09/11 篇文章的范畴。第 01 篇文章只记录一点：从 logits 到 token 的步骤只是又一次 `collective_rpc`，而不是一条特殊路径。

### 枢纽：从隐藏状态到 logits，再到采样 token

概念：在 model runner 内部，一个方法会将 forward pass 的隐藏状态转换为一个 `SamplerOutput`。这正是“model”结束而“sampling”开始的准确位置。

源码：[`vllm/v1/worker/gpu/model_runner.py:1048-1068`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1048-L1068)

```python
    def sample(
        self,
        hidden_states: torch.Tensor,
        input_batch: InputBatch,
        grammar_output: GrammarOutput | None,
    ) -> tuple[SamplerOutput, torch.Tensor, torch.Tensor]:
        sample_hidden_states = hidden_states[input_batch.logits_indices]
        logits = self.model.compute_logits(sample_hidden_states)
        if grammar_output is not None:
            # Apply grammar bitmask to the logits in-place.
            assert self.structured_outputs_worker is not None
            self.structured_outputs_worker.apply_grammar_bitmask(
                logits,
                input_batch,
                grammar_output.structured_output_request_ids,
                grammar_output.grammar_bitmask,
            )

        if input_batch.num_draft_tokens == 0 or self.rejection_sampler is None:
            assert self.sampler is not None
            sampler_output = self.sampler(logits, input_batch)
```

逐步解读：

- **`hidden_states[input_batch.logits_indices]` 只选择需要 token 的位置。** forward pass 在包含*所有*已调度 token 的扁平化 batch 上运行（[第 8 节](#8-模型执行从-executor-到-logits概览)），但只有每个序列的最后一个位置（以及在 spec decode 下的少数额外位置）需要 logit。`logits_indices` 会精确收集这些行，因此词表投影只针对少数位置完成，而不是整个扁平化 batch。
- **`self.model.compute_logits(sample_hidden_states)`** 是从隐藏状态到词表的投影——即语言模型 head。这一行就是本节标题所指的边界。
- **grammar bitmask 就在这里原地应用。** 这闭合了来自[第 6 节](#6-engine-step调度执行处理输出)的链路：mask 由 scheduler 持有，经由 `sample_tokens` 传递，并在采样器看到 logits *之前*应用到 logits 上——因此，结构化输出请求无法采样其 grammar 禁止的 token。
- **`self.sampler(logits, input_batch)`** 是进入采样器主体的交接点（常见的无 spec decode 分支）。当存在 draft tokens 时，`else` 分支（[`model_runner.py:1069-1078`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1069-L1078)）会路由到 `self.rejection_sampler`——即 speculative decoding，将在第 12 篇文章中讨论。

其性质是：**只有最终位置的隐藏状态会投影到词表。** `[logits_indices]` gather 是保持 decode 低开销的关键——如果在每次 prefill 中为每个 prompt token 计算完整的 `[num_all_tokens, vocab_size]` logits 张量，就会在无人采样的行上浪费内存带宽。gather 使“采样成本”随请求数而非 batch 中的 token 数量增长。

### 采样器入口点

概念：`self.sampler(...)` 调用 `Sampler.__call__`，后者准备每个请求的视图，然后将实际的 token 抽取委托给 `Sampler.sample`。`sample` 是 logits 变为索引的地方；抽取之前的所有步骤都是 logits 处理 pipeline。

源码：[`vllm/v1/worker/gpu/sample/sampler.py:198-216`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L198-L216)（节选；完整 pipeline 见第 10 篇文章）：

```python
    def sample(
        self,
        logits: torch.Tensor,
        ...
    ) -> tuple[torch.Tensor, torch.Tensor]:
        processed_logits = self.apply_sampling_params(
            logits,
            ...
            skip_top_k_top_p=True,
        )
```

<a href='images/vllm-01-25-sampler-pipeline.svg' target='_blank'><img src='images/vllm-01-25-sampler-pipeline.svg' alt='vllm-01-25-sampler-pipeline'></a>

<p class='figure-caption'>从隐藏状态到 token id：`hidden_states[input_batch.logits_indices]` 只选择最终位置，`compute_logits` 投影到词表，原地应用由 scheduler 持有的 grammar bitmask，然后 `apply_sampling_params` 按顺序运行其算子（bias / `min_tokens` → penalties → bad-words → temperature → min-p，top-k/top-p 延后处理），在抽取前对私有 fp32 副本进行处理——因此，采样成本随请求数而非 token 数量增长。</p>

逐步解读：

- **`Sampler.__call__`（[`sampler.py:72-102`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L72-L102)）是来自 model runner 的真正入口。** 它从 `input_batch.logits_indices` 派生 `pos` 和 `input_ids`，判断是否需要 logprobs，调用 `self.sample(...)`，并将结果封装到 `SamplerOutput` 中；其 `sampled_token_ids` 被 reshape 为 `[num_requests, 1]`（[`sampler.py:134-144`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L134-L144)）——在 spec decode 扩展它之前，每个请求每一步对应一个 token。
- **`apply_sampling_params` 是 logits 处理 pipeline。** 其顺序为（[`sampler.py:146-196`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L146-L196)）：先将 logits 复制到新的 fp32 张量，然后应用 logit bias / `allowed_token_ids` / `min_tokens`、penalties（presence、frequency、repetition）、bad-words masking、temperature 和 min-p——这里会延后处理 top-k/top-p（`skip_top_k_top_p=True`），从而让 `sample` 可以将它们路由到 FlashInfer fused 路径或 fallback。上述每个算子都在第 10 篇文章中各有一节；第 01 篇文章仅说明它们的存在及顺序。
- **抽取本身**（[`sampler.py:217-244`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L217-L244)）会在符合条件时选择 FlashInfer 的 fused top-k/top-p 采样器，否则应用 top-k/top-p 并调用 `gumbel_sample`，返回 `(sampled, processed_logits)`。

从 `apply_sampling_params` 的第一行即可看出的不变量是（[`sampler.py:157`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L157)、`torch.empty_like(logits, dtype=torch.float32).copy_(logits)`）：**采样始终在私有 fp32 副本上工作，绝不修改模型的原始 logits。** Penalties 和 temperature 会原地修改该副本，因此原始 logits 得以完整保留，用于计算 logprob，而模型自身的 buffer 也绝不会被采样时的修改破坏。让这个 pipeline 在未明确要求时保持 no-op 的默认值——`temperature=1.0`、`top_p=1.0`、`top_k=0`（所有 tokens）、`min_p=0.0`、`n=1`、`max_tokens=16`——在离线和在线路径中都来自同一个 `SamplingParams` 对象（[SamplingParams API](https://docs.vllm.ai/en/stable/api/vllm/sampling_params.html)）。

### 闭合链路：token id 变为 `new_token_ids`

概念：采样得到的 id 并不会以整数形式返回给调用方。它作为按线格式组织的 `EngineCoreOutput` 的一个字段返回，并由 `update_from_output` 合并到请求进度中（[第 6 节](#6-engine-step调度执行处理输出)）。

源码：[`vllm/v1/engine/__init__.py:181-205`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L181-L205)（两个关键字段；[第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)引用了完整结构体）：

```python
    request_id: str
    new_token_ids: list[int]
    ...
    @property
    def finished(self) -> bool:
        return self.finish_reason is not None
```

逐步解读：

- **是 `new_token_ids: list[int]`，而不是 `int`。** 从采样器到调用方的路径从第一个字段开始就支持多 token。在常见情况下，该列表包含一个 id；在 speculative decoding 或其他多 token 方案下，它包含一步中为一个请求接受的多个 id（第 12 篇文章）。在这个边界上，下游的任何部分——detokenizer、stop-string 检查、`RequestOutput`——都无需对 spec decode 进行特殊处理，因为该类型已经涵盖了这种情况。
- **`finished` 是派生属性，而不是存储的标志。** 当且仅当 `finish_reason` 已设置时，它才是 `True`。engine core 会在因长度/EOS 结束时设置 `finish_reason`；stop-*string* 是否导致结束则稍后由 output processor 基于 detokenize 后的文本决定（[第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)）——因此，`EngineCoreOutput.finished` 与调用方可见的结束状态在某一步中出现合理差异是完全可能的。
- **`num_nans_in_logits`** 是用于检测数据损坏的绊线：采样器会在应用 penalties 和 temperature *之前*计算它（[`sampler.py:84-86`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L84-L86)），因此非零值指向的是模型自身的输出问题，而不是采样问题。

结论是：**采样得到的 token 以 msgspec 结构体上的数据形式离开 GPU，而不是作为沿调用栈向上返回的返回值。** 从隐藏状态到 token 的整个计算都发生在 engine（或 worker）进程中；只有在 `update_from_output` 将其提交到请求状态，并通过 client 将 `EngineCoreOutputs` 路由回来之后，调用方才会收到 `new_token_ids`。具体而言，“首个 token”就是请求发出的第一个携带非空 `new_token_ids` 的 `EngineCoreOutput`；它所标记的从 prefill 到 decode 的转换，会在下一个边界处由 output processor 观察到（[第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput)–[第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊)）。

交叉引用：此处仅提及但未展开的 logits 处理算子——logit bias、penalties、bad words、temperature、min-p、top-k/top-p，以及 logprob 组装——是**第 10 篇文章**（采样与 Logits 处理）的完整主题。`rejection_sampler` 分支和多 token 的 `new_token_ids` 属于**第 12 篇文章**（Speculative Decoding）。`logits_indices` gather 以及它索引的扁平化 batch 布局属于**第 08/09 篇文章**。下一节将沿着 `new_token_ids` 离开 GPU 并进入文本处理。

## 10. 输出处理：从 EngineCoreOutput 到 RequestOutput

之前的每一节都在将请求*向前*推进：façade 对其进行规范化，input processor 将其组织为线格式，client 抽象负责将其运送越过进程边界，engine step 对其进行调度和采样。本节是唯一沿相反方向运行的部分。采样得到的 token ID 以 `EngineCoreOutputs` 的形式离开 `EngineCore.step()`——这是一个面向每个 client、由每个请求的 `EngineCoreOutput` 组成的 bundle——并且必须转换成面向用户的 `RequestOutput`，其中携带解码后的文本、结束原因和 logprobs。这一转换由 `OutputProcessor` 完成，并且有意将其置于热点 engine 循环之外。[第 6 节](#6-engine-step调度执行处理输出)已经从调用方视角展示了这一接缝：`LLMEngine.step()` 调用 `get_output()`，然后调用 `output_processor.process_outputs(...)`，再将返回的 `reqs_to_abort` 送回 engine。本节将展开中间的这次调用，并展示它所维护的不变量。

<a href='images/vllm-01-08-output-path.svg' target='_blank'><img src='images/vllm-01-08-output-path.svg' alt='vllm-01-08-output-path'></a>

<p class='figure-caption'>返回路径：一批 `EngineCoreOutput` → 唯一的 `process_outputs` 循环 → 按请求执行 detokenize / stop-check / materialize → async queue 或 sync list。</p>

### 输入结构体：engine 实际返回的内容

概念：跨越边界的单元有意保持最小化——只包含 token ID 和可选元数据，不包含文本。

源码：[`vllm/v1/engine/__init__.py:175-205`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L175-L205)

```python
class EngineCoreOutput(
    msgspec.Struct,
    array_like=True,  # type: ignore[call-arg]
    omit_defaults=True,  # type: ignore[call-arg]
    gc=False,
):  # type: ignore[call-arg]
    request_id: str
    new_token_ids: list[int]
    ...
    finish_reason: FinishReason | None = None
    stop_reason: int | str | None = None
    ...
    @property
    def finished(self) -> bool:
        return self.finish_reason is not None
```

逐步解读。`new_token_ids` 是一个**列表**，而不是标量——一步可以为每个请求提交多个 token（speculative decoding、multi-token prediction），因此返回路径必须能够一次合并 *N* 个 token，而不能假定只有一个。其后的所有内容都是可选的（`omit_defaults=True`），而 `finished` 是一个*派生*属性：只有当 engine 附加了 `finish_reason`（长度、EOS、stop-token）时，请求才算结束。值得注意的是，其中**没有文本字段**——V1 将 detokenization 移出了 engine 进程，使其能够与 GPU 工作重叠执行（[V1 blog](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。engine 传送 ID；文本由 output processor 负责处理。

此结构所保护的不变量是：**“已结束”意味着“存在结束原因”，而 engine 是这方面的权威——stop *strings* 除外，因为 engine 没有文本，无法看到它们。** 正是这个缺口使返回路径能够将信号*反向*发送给 engine，接下来的几个小节将说明它如何安全地做到这一点。

### 唯一允许处理整个 batch 的循环

概念：V1 尽量减少 Python 层面的逐 batch 循环。只有一个函数会遍历 batch，并且所有逐请求工作都应当位于该函数内部。

源码：[`vllm/v1/engine/output_processor.py:594-601`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L594-L601)

```python
        NOTE FOR DEVELOPERS

        vLLM V1 minimizes the number of python loops over the full
        batch to ensure system overheads are minimized. This is the
        only function that should loop over EngineCoreOutputs.

        If you need to touch every element of the batch, do it from
        within the loop below.
```

该循环首先查找每个请求的状态，并丢弃无法识别的输出。

源码：[`vllm/v1/engine/output_processor.py:606-611`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L606-L611)

```python
        for engine_core_output in engine_core_outputs:
            req_id = engine_core_output.request_id
            req_state = self.request_states.get(req_id)
            if req_state is None:
                # Ignore output for already-aborted request.
                continue
```

逐步解读。`req_state` 是长期存在的每请求累加器（`RequestState`），保存该请求的 detokenizer、logprobs 处理器、prompt 数据以及流式处理的簿记信息。它不存在**并不是错误**——某个请求可能刚刚被中止（原因可能是客户端断开连接、`generate()` 被取消，或先前匹配了 stop string），因此已从 `request_states` 中弹出，而 engine 可能仍在执行中，并为它生成最后一个输出。静默执行 `continue`，使中止操作和输出处理无需锁也能安全应对竞态：两侧最终会收敛，因为缺失条目被定义为意味着“丢弃”，而不是“崩溃”。

规则是：**输出处理器是 `request_states` 的纯函数；对于它不再拥有的请求，其任何输出都会被丢弃。**正因如此，中止操作才能与输出已在途的 step 并发运行。

### Detokenize，并提升 engine 无法看到的 stop string

概念：对于非 pooling 请求，新 ID 会被送入增量 detokenizer，由它追加解码后的文本并检查 stop string。匹配到的 stop string 会在本地*提升*完成状态。

来源：[`vllm/v1/engine/output_processor.py:635-644`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L635-L644)

```python
            if pooling_output is None:
                assert req_state.detokenizer is not None
                assert req_state.logprobs_processor is not None
                # 2) Detokenize the token ids into text and perform stop checks.
                stop_string = req_state.detokenizer.update(
                    new_token_ids, finish_reason == FinishReason.STOP
                )
                if stop_string:
                    finish_reason = FinishReason.STOP
                    stop_reason = stop_string
```

detokenizer 的 `update` 是 token ID 转换为字符的地方。其微妙之处在于，*token* 流和*文本*流被有意允许存在差异。

来源：[`vllm/v1/engine/detokenizer.py:107-142`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/detokenizer.py#L107-L142)（节选；完整的增量 decode 循环见第 10 篇文章）：

```python
        if stop_terminated and not self.include_stop_str_in_output:
            # If stop-terminated, exclude last token from detokenization
            # based on include_stop_str_in_output parameter.
            skipped_stop_token_id = new_token_ids[-1]
            new_token_ids = new_token_ids[:-1]
        else:
            skipped_stop_token_id = None

        # 1) Detokenize the new token ids incrementally.
        stop_check_offset = len(self.output_text)
        ...

        # 2) Evaluate stop strings.
        stop_string = None
        if self.stop and self.num_output_tokens() > self.min_tokens:
            stop = check_stop_strings(
                output_text=self.output_text,
                new_char_count=len(self.output_text) - stop_check_offset,
                stop=self.stop,
                include_in_output=self.include_stop_str_in_output,
            )
            if stop is not None:
                stop_string, truncate_to = stop
                if truncate_to != -1:
                    self.output_text = self.output_text[:truncate_to]

        return stop_string
```

逐步解读。当 engine 因 stop *token* 而停止，并且用户没有要求保留它时，最后一个 ID 会被从 decode 集合（`skipped_stop_token_id`）中取出，使其不产生任何字符，然后再重新追加到 `token_ids`——token 列表仍保持完整，而文本会省略终止符。被省略的增量循环会 decode 每个新 id，并推进 `stop_check_offset`（一个受 `min_tokens` 约束的高水位标记），因此 stop-string 搜索只覆盖*新添加的*字符——每个 step 的匹配复杂度是 O(新增字符数)，而不是 O(完整输出长度)；完整循环见第 10 篇文章。`num_output_tokens() > self.min_tokens` guard 控制整个停止逻辑块，因此**在达到 `min_tokens` 之前，不可能触发任何 stop string**。匹配时，`check_stop_strings` 可能返回一个截断长度，以便裁剪 `output_text` 来移除 stop string（除非返回 `truncate_to == -1`，这表示它正好位于末尾，无需裁剪）。

回到循环中：如果 `update` 返回 stop string，处理器会**将 `finish_reason` 覆盖为 `STOP`，并将 `stop_reason` 设置为匹配到的字符串**。这正是输入结构所预设的分歧：`engine_core_output.finished` 可能仍是 `False`（engine 仍在继续生成），而处理器已经在本地判定请求完成。[第 6 节](#6-engine-step调度执行处理输出) 展示了闭环的另一半——循环会把这样的 `req_id` 追加到 `reqs_to_abort`，而 `LLMEngine.step()` / async `output_handler` 会将它们反馈回去，使*下一个* `EngineCore.step()` 在该请求的中止窗口中将其停止。

不变量是：**(1) `token_ids` 是完整的采样序列；`output_text` 可以省略 stop token/string——二者在设计上允许不一致。** **(2) `min_tokens` 在文本侧也会得到遵守，而不只是在 engine 侧。** **(3) stop-string 检测是返回路径中的概念，而让返回路径停止 engine 的唯一机制是 `reqs_to_abort`。**这可以防止：将 stop string 流式发送给用户、让 stop string 在达到 `min_tokens` 之前结束生成，以及——由于提升操作加上 `reqs_to_abort` 是最终一致的——engine 继续为文本层已经完成的请求消耗 token。

### 决定本 step 是否对外输出任何内容

概念：并非每个 `EngineCoreOutput` 都会变成 `RequestOutput`。`make_request_output` 会应用输出类型门控，并在不应发出任何内容时返回 `None`。

来源：[`vllm/v1/engine/output_processor.py:280-331`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L280-L331)

```python
        finished = finish_reason is not None
        final_only = self.output_kind == RequestOutputKind.FINAL_ONLY

        if not finished and final_only:
            # Only the final output is required in FINAL_ONLY mode.
            return None

        if self.stream_interval > 1:
            assert self.detokenizer is not None
            ...
            if not (
                finished
                or self.sent_tokens_offset == 0
                or self.detokenizer.num_output_tokens() - self.sent_tokens_offset
                >= self.stream_interval
            ):
                return None

            if self.output_kind == RequestOutputKind.DELTA:
                # Send tokens from the offset in DELTA mode, otherwise all
                # tokens are sent.
                new_token_ids = self.detokenizer.output_token_ids[
                    self.sent_tokens_offset :
                ]
                self.sent_tokens_offset = self.detokenizer.num_output_tokens()

        external_req_id = self.external_req_id
        ...
        output = self._new_completion_output(new_token_ids, finish_reason, stop_reason)

        if self.parent_req is None:
            outputs = [output]
        else:
            outputs, finished = self.parent_req.get_outputs(self.request_id, output)
            if not outputs:
                return None
            external_req_id = self.parent_req.external_req_id

        return self._new_request_output(
            external_req_id, outputs, finished, kv_transfer_params
        )
```

逐步解读。`output_kind` 来自 `SamplingParams.output_kind`，用于选择对外输出契约：**`FINAL_ONLY`**（离线默认值——[第 2 节](#2-llmgenerate离线便捷层) 展示了 `_add_request` 如何强制使用它）只在完成时精确发出一个输出，因此每个非最终 step 都返回 `None`；**`DELTA`**（OpenAI 流式传输）只发出新生成的切片；**`CUMULATIVE`** 会重新发送不断增长的完整结果。`stream_interval > 1` 会进一步合并输出：仅在完成时、生成第一个 token 时，或每生成 `stream_interval` 个 token 时发出——而且在 DELTA 模式下，它会把 `new_token_ids` 重新切片为 `output_token_ids[sent_tokens_offset:]` 并推进 `sent_tokens_offset`，因此在静默 step 中跳过的 token 会被一起交付，而不是丢失。最后，parallel sampling（`n>1`）会经过 `parent_req.get_outputs`：子输出会被聚合，空列表意味着“尚未准备好对外输出”→ `None`，而对外输出的 id 会切换为**父请求的**外部 id（[第 5 节](#5-add_request请求进入-enginecore) 中的 fan-out 在此闭环）。

保证是：**`FINAL_ONLY` 恰好产生一个输出；`stream_interval` 会合并输出，但绝不会丢失 delta token（`sent_tokens_offset` 是高水位标记）；parallel-sampling 子请求会统一使用一个父请求 id 对外输出。**这可以防止：离线调用方在每个 step 都收到一个 `RequestOutput`（它只需要一个）、delta 消费者在合并间隔内丢失 token，以及 `n>1` 泄漏成 `n` 个独立的用户结果。

### 封装：始终使用外部 id

概念：最终 wrapper 会将面向用户的标识写入结果。

来源：[`vllm/v1/engine/output_processor.py:363-373`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L363-L373)

```python
        return RequestOutput(
            request_id=external_req_id,  # request_id is what was provided externally
            lora_request=self.lora_request,
            prompt=self.prompt,
            prompt_token_ids=prompt_token_ids,
            prompt_logprobs=prompt_logprobs,
            outputs=cast(list[CompletionOutput], outputs),
            finished=finished,
            kv_transfer_params=kv_transfer_params,
            num_cached_tokens=self.num_cached_tokens,
            metrics=self.stats,
        )
```

逐步解读。回顾[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)：`assign_request_id` 会在内部 id 后追加 8 个随机字符以保证唯一性，同时将调用方的 id 保存在 `external_req_id` 中。在结果到达用户之前的最后一跳，`request_id` 会被设置为 `external_req_id`——绝不会使用内部随机化 id，也绝不会使用 parallel-sampling 子请求 id。在 DELTA 模式下，prompt logprobs 会被*弹出*（恰好对外输出一次）；其他情况下则按引用传递；这部分组装逻辑属于第 10 篇文章的范畴。

不变量是：**每个面向用户的 `RequestOutput.request_id` 都是调用方提交的外部 id。**这可以防止内部 ID 方案（随机后缀、子请求 fan-out）泄漏到 API 响应中，否则会破坏离线排空过程的终止条件 `sorted(..., key=lambda x: int(x.request_id))`（[第 2 节](#2-llmgenerate离线便捷层)），也会破坏任何将结果与自身请求 ID 相关联的客户端逻辑。

### 唯一分叉：async 推送与同步返回

概念：由一个 `if` 决定已物化的输出是被推送到每请求 async 邮箱，还是追加到返回列表。

来源：[`vllm/v1/engine/output_processor.py:650-681`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L650-L681)

```python
            # 4) Create and handle RequestOutput objects.
            if request_output := req_state.make_request_output(
                new_token_ids,
                pooling_output,
                finish_reason,
                stop_reason,
                kv_transfer_params,
            ):
                if req_state.streaming_input:
                    request_output.finished = False

                if req_state.queue is not None:
                    # AsyncLLM: put into queue for handling by generate().
                    req_state.queue.put(request_output)
                else:
                    # LLMEngine: return list of RequestOutputs.
                    request_outputs.append(request_output)

            # Free completed requests.
            if finish_reason is not None:
                if req_state.streaming_input:
                    ...
                else:
                    self._finish_request(req_state)
                    if not engine_core_output.finished:
                        # If req not finished in EngineCore, but Detokenizer
                        # detected stop string, abort needed in EngineCore.
                        reqs_to_abort.append(req_id)
```

逐步解读。`req_state.queue is not None` 是在线与离线返回路径之间的*全部*差异。在 `AsyncLLM` 中，队列是每请求的 `RequestOutputCollector`，由 `generate()` await；在 `LLMEngine` 中，它是 `None`，输出会累积在同步调用方排空的列表中。两个分支都会运行上面完全相同的 detokenize / stop-check / materialize 逻辑——只有最后一步发生分歧。清理过程与此对应：完成时，`_finish_request` 会从每个索引（`request_states`、外部→内部映射、父请求）中弹出状态，而 `not engine_core_output.finished` 检查正是前文 stop-string 闭环的一部分——engine 仍认为该请求处于活动状态，因此其 id 会加入 `reqs_to_abort`。

设计是：**在线与离线共享一条代码路径，仅在一个分支处分叉；流式邮箱内部机制和 async generator 位于[第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊)，深层 async fan-out 则位于第 04 篇文章。**这可以防止两套并行的输出处理实现逐渐产生偏差——对于 `LLM.generate()` 和 OpenAI server，stop-string、delta 与 parallel-sampling 语义都保证完全一致，因为它们运行的是同一个循环。

### 后续需要牢记的内容

输出处理器是 token ID 重新获得语义的地方。它负责 engine 有意不负责的四件事：**增量 detokenization**（ID → 文本，允许 token/文本存在差异，并遵守 `min_tokens`）、**stop-string 检测**（唯一会通过 `reqs_to_abort` *反向*流入 engine 的信号）、**输出类型门控**（FINAL_ONLY / DELTA / CUMULATIVE / stream_interval，用于决定某个 step 是否对外输出任何内容）以及**标识**（始终使用外部 id）。它是一个可安全应对竞态的循环，而其中唯一的 `queue is not None` 分叉正是阻塞式离线收集（[第 2 节](#2-llmgenerate离线便捷层)）与流式在线交付（[第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊)）之间的接缝。后续衔接：**第 10 篇文章**介绍 logprobs 组装与 detokenizer 后端（Rust `DecodeStream` 快速路径与 Python 慢速路径）；**第 04 篇文章**介绍 engine 内部的 async `output_handler` fan-out 与已完成请求的生命周期；**[第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊)**介绍 `RequestOutputCollector` 邮箱，以及第一个 `RequestOutput` 如何成为客户端看到的第一个 token。

## 11. 流式传输、Async Generator，以及为什么第一个 Token 很特殊

我们之前追踪的离线路径最终进入一个阻塞式 `while has_unfinished_requests(): step()` 循环，它会将已完成的输出累积到列表中并进行排序（[`offline_utils.py:594-599`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L599)）。在线服务不能这样做。兼容 OpenAI 的 SSE 流必须在每个 token 被采样后立即将其交付给 HTTP 客户端，同时处理数百个并发请求，并且不能让任何一个缓慢的客户端阻塞 GPU。V1 的解决方案是保持 engine step 完全不变，只改变*返回路径*：同一个逐 step 的 `EngineCoreOutputs` batch 不再被收集到列表中，而是通过 fan-out 分发到每个请求各自的邮箱中，再由每请求一个 asyncio generator 排空其邮箱。本节将沿着这条返回路径展开，然后借此明确“第一个 token”究竟是什么。

在线返回路径是**由 asyncio 解耦并叠加在一起的两个生产者/消费者边界**。边界 A：一个后台任务持有 ZMQ 输出 socket，将每个 frame 解码为一个 `EngineCoreOutputs` batch（每个 engine step 一个，涵盖所有正在处理的请求），并将其推送到 `AsyncMPClient.outputs_queue`，即一个 `asyncio.Queue`（[`core_client.py:973`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L973)、`1005-1062`）。边界 B：每个 `AsyncLLM` 对应一个 `output_handler` task，它等待该队列、运行 `OutputProcessor.process_outputs`，并将每个请求的结果分派到各自的邮箱中。边界 A 背后的 socket 拓扑属于第 03 篇文章的讨论范围；这里我们关注跨越边界 B 并到达调用方的内容。

<a href='images/vllm-01-09-prefill-decode-timeline.svg' target='_blank'><img src='images/vllm-01-09-prefill-decode-timeline.svg' alt='vllm-01-09-prefill-decode-timeline'></a>

<p class='figure-caption'>单个请求的时间线——准入、（可能分块的）prefill、第一个采样 token（TTFT），随后是逐 step decode，每个 step 产生一个 RequestOutput。</p>

### `generate()` 是纯消费者

公开的在线 API `AsyncLLM.generate` 是一个异步生成器。关键在于，它**不会**驱动 engine——它只消费自己的邮箱。

[`vllm/v1/engine/async_llm.py:575-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L575-L586)：

```python
            finished = False
            while not finished:
                # Note: drain queue without await if possible (avoids
                # task switching under load which helps performance).
                out = q.get_nowait() or await q.get()

                # Note: both OutputProcessor and EngineCore handle their
                # own request cleanup based on finished.
                assert isinstance(out, RequestOutput)
                finished = out.finished
                if out is not STREAM_FINISHED:
                    yield out
```

<a href='images/vllm-01-26-async-mailbox.svg' target='_blank'><img src='images/vllm-01-26-async-mailbox.svg' alt='vllm-01-26-async-mailbox'></a>

<p class='figure-caption'>在线返回路径包含两个由 asyncio 解耦的边界：边界 A（后台任务将 ZMQ frame 解码为 `EngineCoreOutputs` 并推送到 `outputs_queue`）和边界 B（一个 `output_handler` 运行 `process_outputs`，并将每个结果分派到各请求的单槽邮箱中，同时合并 `RequestOutputCollector`）；`generate()` 使用 `q.get_nowait() or await q.get()` 将其排空——每个请求最多有一个待处理输出，并且合并是无损的。</p>

逐步解读：

1. `q` 是由 `add_request` 返回的每请求 `RequestOutputCollector`（[`async_llm.py:559`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L559)）；后者还向 `OutputProcessor` 注册了该请求，并在同一条 await 调用链中将其提交给 EngineCore（[第 5 节](#5-add_request请求进入-enginecore)）。当这个循环开始运行时，该邮箱已经接入扇出路径。
2. `out = q.get_nowait() or await q.get()`（L579）会先尝试非阻塞获取；只有邮箱为空时才会执行 `await`。注释（L577-578）说明了其意图：在负载较高时，跳过 event-loop task 切换很重要，因为在高并发下，通常已经有一个 token 正在等待。
3. 终止条件承载在*数据本身之上*：`finished = out.finished`（L584）。生产者会在最后一个 `RequestOutput` 上标记 `finished=True`；消费者在 yield 它之后停止。`generate()` 无需了解 scheduler 或 EngineCore 生命周期的任何信息，就能知道何时停止。
4. `STREAM_FINISHED`（一个 `RequestOutput` 哨兵，其 `finished=True` 且 `outputs` 为空，[`outputs.py:191-199`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/outputs.py#L191-L199)）会被过滤掉（L585）——它会在 streaming 输入完成时解除循环阻塞，而不会发出虚假的空 chunk。

不变量是：**当数据就绪时，消费 task 绝不会阻塞 event loop，并且它恰好在 `finished` 输出处终止。**由于循环条件位于被 yield 的对象上，`generate()` 与其下方的所有进程边界解耦——请求可以由进程内 engine、通过 ZMQ 通信的子进程，或者多个 data-parallel core 之一提供服务（[第 4 节](#4-engine-边界进程内-client-与多进程-client)），而这个循环完全不变。

### 每请求邮箱是一个可合并的单槽缓冲区

从共享的 `output_handler`（生产者）到每请求 `generate()`（消费者）的交接，刻意*没有*使用无界队列。它是一个单槽邮箱外加一个 `asyncio.Event`；如果生产者速度快于消费者，连续输出会**原地合并**。

[`vllm/v1/engine/output_processor.py:62-86`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L62-L86)：

```python
    def put(self, output: RequestOutput | PoolingRequestOutput | Exception) -> None:
        """Non-blocking put operation."""
        if self.output is None or isinstance(output, Exception):
            self.output = output
            self.ready.set()
        elif isinstance(self.output, RequestOutput) and isinstance(
            output, RequestOutput
        ):
            # This ensures that request outputs with different request indexes
            # (if n > 1) do not override each other.
            self.output.add(output, aggregate=self.aggregate)
        elif isinstance(self.output, PoolingRequestOutput) and isinstance(
            output, PoolingRequestOutput
        ):
            self.output = output

    async def get(self) -> RequestOutput | PoolingRequestOutput:
        """Get operation blocks on put event."""
        while (output := self.output) is None:
            await self.ready.wait()
        self.output = None
        self.ready.clear()
        if isinstance(output, Exception):
            raise output
        return output
```

逐步解读：

1. `put()` 从生产者同步运行。如果槽为空（或者该项是 `Exception`），就将其放入并执行 `self.ready.set()`——异常总是会立即占据该槽，并且绝不会在合并中丢失，因此失效的 engine 会立刻向等待方暴露。
2. 如果槽中已经有一个 `RequestOutput`，新的输出会通过 `self.output.add(output, aggregate=self.aggregate)`（L72）折叠进去，而不是覆盖它。只有在 `DELTA` 模式下，`aggregate` 才是 `True`（`self.aggregate = output_kind == RequestOutputKind.DELTA`，L55）。该合并操作（[`outputs.py:145-173`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/outputs.py#L145-L173)）会为 DELTA streaming 拼接文本、token ID 和 logprob；为累积式 streaming 替换整个快照；并对 `finished` 执行 OR 折叠，从而确保即使合并后的 batch 吞掉了终止 chunk，也仍会停止 generate 循环。
3. `get()` 会等待 `self.ready`，直到该槽不再是 `None`，随后清空槽和 event。

其性质是：**任意时刻，每个请求最多有一个待处理输出，并且合并是无损的。**无论慢速客户端落后多少，每请求存活内存始终是 O(1)——邮箱会执行合并，而不是积累 backlog——同时 DELTA 消费者仍会按顺序、不多不少地接收每个 token，因为合并等同于拼接。这正是同步离线列表不需要考虑的背压机制：那里的 driver thread 会立即消费每个 step 的输出，因此不会积累任何内容。

### 一个循环、一个标志：同步与异步在何处分叉

两个 engine 共享 batch 上最热的那个 CPU 循环——`process_outputs`，即“唯一应该遍历 EngineCoreOutputs 的函数”（[`output_processor.py:594-601`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L594-L601)）。第 10 节](#10-输出处理从-enginecoreoutput-到-requestoutput) 已经展示了其中将同步路径与异步路径分开的唯一分支：`if req_state.queue is not None:` 将实体化后的 `RequestOutput` 推送到每请求邮箱（异步），而不是将其追加到返回列表（同步）（[`output_processor.py:650-666`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L650-L666)）。异步 engine 在准入时注册该 `queue`（[第 5 节](#5-add_request请求进入-enginecore)）；同步 engine 则传入 `queue=None`。

真正属于第 11 节](#11-流式传输async-generator以及为什么第一个-token-很特殊) 的内容，是该分支对 streaming 产生的后果。由于存在队列，异步分派可以证明是纯 push 的——因此 `output_handler` 可以 `assert not processed_outputs.request_outputs`（[`async_llm.py:679`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L679)）：只要接入了队列，就绝不会触碰返回列表。因此，streaming 不会为 batch 增加*第二个循环*——它复用了离线路径已经运行的那个循环，只替换最后一条语句。`make_request_output` 所依赖的 detokenization、停止字符串检查和 logprob 组装属于第 10 篇文章的主题；第 04 篇文章详细介绍了已完成请求的记录管理以及 `reqs_to_abort` 路径。

### 为什么第一个 token 很特殊

Prefill 和 decode 是两种不同的 forward pass。根据“Inside vLLM”导览（[Inside vLLM](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）：**prefill** 是“对所有 prompt token 执行一次 forward pass”，通常受计算能力限制；**decode** 是“仅对最近一个 token 执行一次 forward pass”，受内存带宽限制。V1 不会将它们作为独立阶段运行——它统一处理所有 token，而一次调度决策在概念上是 `{request_id: num_tokens}`（[V1 blog](https://vllm.ai/blog/2025-01-27-v1-alpha-release)），因此较长的 prompt 可以拆分到多个 step 中（chunked prefill，第 05 篇文章）。这对 streaming 的影响是：一个请求可能会占用 GPU 一个或多个 step，却不产生任何采样 token，因为只有最后一个 prefill 位置会生成用于采样的 logits。因此，第一个携带真实 `new_token_ids` 的 `EngineCoreOutput` 是一个独立事件，输出处理器会对其进行标记。

[`vllm/v1/engine/output_processor.py:628-633`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L628-L633)：

```python
            if req_state.is_prefilling:
                if engine_core_output.prefill_stats is not None:
                    req_state.num_cached_tokens = (
                        engine_core_output.prefill_stats.num_cached_tokens
                    )
                req_state.is_prefilling = False
```

逐步解读：`is_prefilling` 在构造 `RequestState` 时以 `True` 开始（[`output_processor.py:172`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L172)）；仅当 streaming 输入请求恢复 prefilling 时，它才会被重置为 `True`（`apply_streaming_update`，[`output_processor.py:191-208`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L191-L208)）。到达处理器的第一个输出会一次性捕获 `num_cached_tokens`——该请求的 prefix-cache 命中数，即第 07 篇文章讨论的指标——并将 `is_prefilling` 翻转为 `False`。之后的每个 step 都是 decode。从准入到调用方收到第一个 `RequestOutput` 的耗时，本质上是以下各项之和：首次被调度前在 scheduler 队列中的等待时间、（可能跨多个 step 分块执行的）prefill 延迟、一次采样调用、增量 detokenization，以及通过边界 A 和边界 B 的两跳扇出。这一总和就是 *time-to-first-token*（TTFT），其结构不同于 decode 的 token 间延迟，后者每个 token 对应一个 step。

跨进程边界的完整首 token 链路如下：`EngineCore.step()` 在 `update_from_output` 中提交采样 token，并返回每客户端的 `dict[int, EngineCoreOutputs]`（[`core.py:504-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L508)）；边界 A 将该 batch 入队；`output_handler` 运行 `process_outputs`，后者翻转 `is_prefilling`（见上文），并将第一个 `RequestOutput` 推送到邮箱中；`generate()` 将其 yield 出去（[`async_llm.py:585-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L585-L586)）。没有任何单一调用栈贯穿这条链路——它是在异步客户端、共享 handler、每请求邮箱和消费者 task 之间进行的一次接力。

### 取消操作闭合了整个循环

由于 `generate()` 由可能断开连接的 HTTP 客户端消费，取消操作必须在*两侧*都拆除该请求，否则 engine 会继续 decode 一个已经失效的请求。[`async_llm.py:591-596`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L591-L596) 会捕获 `CancelledError`/`GeneratorExit`，调用 `self.abort(q.request_id, internal=True)`（同时在 OutputProcessor 和 EngineCore 中中止请求），然后重新抛出异常；[`async_llm.py:633-635`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L633-L635) 处的 `finally` 会调用 `q.close()`，以取消任何 streaming 输入 feeder。离线循环不需要对应机制：其 driver thread 拥有这些请求，只需停止迭代即可。

因此，streaming 路径就是将返回通道替换为 asyncio 管道的离线路径：`LLMEngine.step` 是通过 `queue=None` 内联运行并返回列表的 `output_handler` 循环体（[`llm_engine.py:296-334`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L296-L334)），而 `LLM._run_engine` 的 `while has_unfinished_requests(): step()`（[`offline_utils.py:594-599`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L599)）替代了整套 task/queue/yield 机制。engine step、scheduler、worker 和 sampler 从来不需要知道自己正在服务哪一种路径。第 02 篇文章介绍包装 `generate()` 的 OpenAI server；第 03 篇文章介绍边界 A 的 ZMQ client 和 socket 排空 task；第 04 篇文章深入介绍 `process_outputs`、已完成请求的处理，以及 `reqs_to_abort` 闭包。

## 12. 完整的端到端追踪，以及需要记住的要点

现在，我们已经逐一跨越了请求路径上的每一道边界。这个收尾章节做两件事：将这些边界重新组装成一条完整的逻辑主线——从 `LLM.generate()` 到调用者手中的 `RequestOutput`，形成一条不间断的追踪链路——并提炼出几条值得带入后续深度文章的原则。这里没有任何新机制；下面的每个锚点都已在前面的章节中介绍过。将它们作为一条完整链路来阅读，其价值在于让这些*接缝*变得清晰可见：你可以准确看到请求在何处更换所有者、更换表示形式以及跨越进程，也可以说清每道接缝所保障的不变量。

<a href='images/vllm-01-10-full-trace.svg' target='_blank'><img src='images/vllm-01-10-full-trace.svg' alt='vllm-01-10-full-trace'></a>

<p class='figure-caption'>完整的请求路径：`generate()` → input processor → `EngineCoreRequest` → client → `EngineCore.step`（schedule → execute → sample → commit）→ output processor → `RequestOutput`，并标注每一跳的所有者及其不变量。</p>

### 逐跳追踪

跟随一个 prompt。行锚点指向每一跳所执行的确切代码。

1. **`LLM.generate()` 执行验证并委派**——[`vllm/entrypoints/llm.py:465-485`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L465-L485)。runner 类型检查会拒绝非生成式模型，`sampling_params` 会被设为默认值，因此在下游绝不会是 `None`，随后控制权交给 `_run_completion`。不进行 scheduling，也不进行 allocation。*（文章 02。）*

2. **离线 mixin 为请求加上标识并接纳它**——[`vllm/entrypoints/offline_utils.py:559-563`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L563)。`output_kind` 被强制设为 `FINAL_ONLY`，并通过一个 `Counter()` 生成单调递增的十进制 `request_id`。随后，`LLMEngine.add_request`（[`vllm/v1/engine/llm_engine.py:218-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L218-L294)）在*两侧*注册这项工作——output processor 一侧负责 detokenization 和聚合，engine core 一侧负责 scheduling——并且在 `n > 1` 时，将一个逻辑请求拆分成 `n` 个子请求，并置于一个 `ParentRequest` 之下。*（外观层见文章 02，双侧注册见文章 04。）*

3. **input processor 将 prompt 转换为传输 struct**——[`vllm/v1/engine/input_processor.py:242-255`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L242-L255)。`process_inputs(request_id, prompt, params, ...) -> EngineCoreRequest` 会经历完整的验证流程，克隆并最终确定 sampling 参数（从而使 `max_tokens` 成为具体值），执行 tokenization 或接受 token ID，并将所有多模态输入扁平化。其输出是一个 `EngineCoreRequest`——专为跨 socket 传输而设计的紧凑 `msgspec` struct。*（文章 03。）*

4. **client 抽象将其送过进程边界**——[`vllm/v1/engine/llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111)。`LLMEngine` 持有一个多态的 `EngineCoreClient`。在默认的多进程模式下，请求会在一个单字节类型标签之后进行序列化（[`vllm/v1/engine/__init__.py:251-264`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L251-L264)：`ADD = b"\x00"`），然后通过 ZMQ 以 ROUTER 模式发送给一个进行忙循环的 `EngineCore` 进程；使用进程内 client 时，则是直接的方法调用。无论采用哪种方式，对外都是相同的 `add_request`/`get_output` 接口。*（ZMQ 拓扑见文章 03，DP 路由见文章 11。）*

5. **`EngineCore.step()` 执行这项事务**——[`vllm/v1/engine/core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)。依次进行 schedule、以非阻塞方式启动 forward pass、在 GPU 运行期间由 CPU 构建 grammar bitmask、同步、处理 abort，然后 commit。这是整个系统赖以构建并不断重复的心跳，第 6–9 步全部发生在其*内部*。尾部 hook `post_step`（[`core.py:510-517`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L510-L517)）会将 speculative draft token 反馈给 scheduler，供下一步使用。*（文章 04。）*

6. **scheduler 规划的是 token，而不是 tensor**——位于 [`core.py:490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490) 的单次调用 `scheduler.schedule(...)` 回答“哪些请求运行，以及每个请求推进多少个 token”，并使用统一的计数器模型 `{request_id: num_tokens}` 表示结果。它返回一个 `SchedulerOutput` 计划，且完全不触碰 GPU。*（文章 05；KV allocation 见 06，prefix reuse 见 07，draft token 见 12。）*

7. **executor 将计划分发到 GPU**——[`vllm/v1/executor/abstract.py:210-227`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L210-L227)。`execute_model` 是一个 `collective_rpc`，它命名的是一项*操作*，而不是一个设备，因此一个或 N 个 worker 会执行相同的调用，并采用某个权威 worker 的答案（最后一个 PP stage 的第一个 TP rank；[第 8 节](#8-模型执行从-executor-到-logits概览)）。在每个 worker 上，model runner 会协调其持久化 batch，运行扁平化的 forward pass，并在关键转折点（[`vllm/v1/worker/gpu/model_runner.py:1054-1055`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1054-L1055)）选择最终位置的 hidden state，再将其投影为 logits。*（kernel/CUDA graph 见文章 08–09，parallelism 见文章 11。）*

8. **采样器抽取 token ID**——可以内联执行；或者在 worker 推迟该操作时，通过第二个 `collective_rpc`，即位于 [`core.py:497-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L497-L499) 的 `sample_tokens(grammar_output)`，最终到达 `Sampler.sample`（[`vllm/v1/worker/gpu/sample/sampler.py:198-210`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L198-L210)）。在抽取之前，grammar bitmask 会原地应用于*这些* logits。*（文章 10；spec decode 的 rejection sampling 见 12。）*

9. **commit 将 token 纳入进度状态**——位于 [`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506) 的 `scheduler.update_from_output(...)` 会追加采样得到的 ID、设置 finish reason，并释放所有已完成请求的 KV block。其结果是一个 `dict[client_index -> EngineCoreOutputs]`——包含 token ID 和完成标志，*而不是*面向用户的文本。*（文章 04。）*

10. **output processor 将 ID 重新转换为文本**——[`vllm/v1/engine/output_processor.py:576-693`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L576-L693)，这是唯一允许遍历整个 batch 的函数。它进行增量 detokenization，将检测到的 stop *字符串*提升为完成状态（并且如果 core 没有同时停止，则将该 id 追加到 `reqs_to_abort`），然后具现化一个 `RequestOutput`。*（文章 04 和 10。）*

11. **结果通过两种方式返回。**离线模式：drain 循环收集已完成的输出，并通过最终排序恢复输入顺序（[`offline_utils.py:594-626`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L626)）。在线模式：`process_outputs` 将每个 `RequestOutput` 推入对应请求的 mailbox，由 `generate()` async generator 逐个 yield（[`vllm/v1/engine/async_llm.py:576-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L576-L586)）。两者得到的都是*同一个* `process_outputs` 输出，仅由单个 `if req_state.queue is not None:` 分支进行分派。*（离线模式见文章 02，在线 streaming 见 03/11。）*

首尾呼应之处在于：你拿回的 `request_id` 与最初传入的完全相同。

[`vllm/v1/engine/output_processor.py:363-364`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L363-L364)：

```python
        return RequestOutput(
            request_id=external_req_id,  # request_id is what was provided externally
```

**逐步解读。**在内部，一个请求可能为了保证唯一性而被加上随机字符后缀；在 parallel sampling 下，它也可能被拆分成 `n` 个子请求——但对外呈现的 `RequestOutput` 始终携带 `external_req_id`，即调用者自己的 id，而绝不会携带内部 id。**它所保护的不变量：**在路径上的每一次表示形式转换中，身份始终保持稳定。prompt 先变成 `EngineCoreRequest`，再变成 `Request`，然后变成 batched tensor 中的一行扁平化数据，接着变成 token ID，最后成为经过 detokenization 的文本——而供调用者关联结果的 id 在整个过程中始终原样保留。

### 表格形式的追踪链路

| 跳 | 所有者／锚点 | 所保障的不变量 | 深度文章 |
|---|---|---|---|
| `generate()` | [`entrypoints/llm.py:465-485`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L465-L485) | 验证；参数绝不为 `None`；仅限生成式模型 | 02 |
| 接纳 + fan-out | [`offline_utils.py:559-563`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L563), [`llm_engine.py:218-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L218-L294) | `FINAL_ONLY`；单调递增 id；每个逻辑请求只有一个用户输出 | 02, 04 |
| 输入处理 | [`input_processor.py:242-255`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L242-L255) | prompt → 自有且已完全填充默认值的 `EngineCoreRequest` | 03 |
| client 边界 | [`llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111), [`__init__.py:251-264`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L251-L264) | 传输方式是一项部署选择，对语义不可见 | 03, 11 |
| `step()` | [`core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508) | schedule → execute → commit 是一项原子事务 | 04 |
| schedule | [`core.py:490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490) | 处理 token，而非 tensor：`{request_id: num_tokens}` | 05, 06, 07, 12 |
| execute → logits | [`abstract.py:210-227`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L210-L227), [`model_runner.py:1054-1055`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1054-L1055) | 命名一项操作，而非一个设备；只投影最终位置 | 08, 09, 11 |
| sample | [`sampler.py:198-210`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L198-L210), [`core.py:497-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L497-L499) | grammar mask 应用于*这个* batch 的 logits | 10, 12 |
| commit | [`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506) | 只有在获得模型输出后，进度才会推进 | 04 |
| 输出处理 | [`output_processor.py:576-693`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L576-L693) | detok、stop 字符串、external-id `RequestOutput` | 04, 10 |
| 返回 | [`offline_utils.py:594-626`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L626) / [`async_llm.py:576-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L576-L586) | 恢复顺序（离线）／streaming（在线） | 02, 03 |

### 要记住的五件事

**1. engine 是一项不断重复的事务，而不是一条 pipeline。**四个规范函数——输入处理、scheduling、模型执行、输出处理（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）——并不是每个请求只经过一次。其中三个（schedule、execute、commit）构成 `EngineCore.step()`（[`core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)）的主体，会反复运行，每一轮将进行中的请求向前推进几个 token，直到请求完成（[vLLM 内部原理](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）。掌握这一个方法，其他一切的整体形态也就随之清晰。

**2. 本文比较的三个生成入口，本质上都是 `add_request` + drain 之上的 adapter。**离线 `LLM.generate`、异步 `AsyncLLM.generate` 和兼容 OpenAI 的服务器，区别仅在于它们如何*驱动*事务以及如何*收集*输出——要么使用带最终排序的阻塞循环，要么使用异步任务将输出分发到各请求的 mailbox。它们所驱动的事务完全相同。因此，只需学习一次请求路径，就能将理解推广到这三个接口（其他入口——embedding、pooling、tokenization——各有其自身语义；文章 02 对它们进行了梳理）。

**3. 这条路径是一连串所有权边界，每一道边界都保障一个不变量。**公共 API（验证、填充默认值、单调递增 ID、恢复顺序）→ input processor（任务／参数一致性、克隆参数、传输 struct）→ client（与传输方式无关的接口）→ `EngineCore`（schedule/execute/commit 事务，将*所有*生命周期状态委派给 scheduler）→ scheduler（token 和内存决策）→ worker/runner（tensor、logits）→ 采样器（token ID）→ output processor（detok、stop 字符串、external-id `RequestOutput`）。当问题出现时——谁决定 `max_tokens`？stop 字符串在哪里被检测？block 何时释放？——你已经知道应该打开哪一道边界。

**4. 进程边界是部署决策，而非语义决策。** `LLMEngine` 只持有一个 `EngineCoreClient` 句柄（[`llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111)）；transport 在构造时便固定下来，绝不会渗透到请求语义中。请注意这个反直觉的默认行为：即使是“离线”`LLM` 也会运行一个后台 `EngineCore` 进程，因为 `VLLM_ENABLE_V1_MULTIPROCESSING` 默认为 true（[`vllm/envs.py:147`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/envs.py#L147)；通过 [`llm_engine.py:157`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L157) 设置）——进程内 client 才是需要显式选择的非默认选项，而不是默认选项。正因如此，文章 01 才能将这条路径追踪为单一的逻辑线程，并将真实的 ZMQ 拓扑留到文章 03 再讨论。

**5. 只有在模型产生输出后才会提交进度——而一次结束会沿两个时钟向外扩散。** Scheduling 是乐观的，会提前于 GPU 进行分配，但在 `update_from_output` 根据模型实际产生的结果对计划进行校正之前，任何请求状态都不会推进（[`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506)）。中止窗口（[`core.py:501-503`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L501-L503)，在提交*之前*排空）与宽松的存活性守卫（[`core.py:488`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L488)，它会计入已结束但尚未 flush 的请求）构成了这条规则的两个边界：请求可以一直到提交前进入或离开 batch，但绝不能在提交过程中这样做。当请求结束时，client 通知会搭乘*当前*步骤的 `EngineCoreOutputs`（stream 可以立即关闭），而 worker 侧的清理则搭乘*下一个* `SchedulerOutput`——存活性守卫的存在，正是为了让 engine 保持唤醒，以完成第二次面向 worker 的 flush。

### 带定位锚点的关键不变量

为了便于快速查阅，以下列出了本文所依赖的不变量，并分别标注了它们所在的位置：

- **每个请求恰好产生一个离线输出**——`FINAL_ONLY`，位于 [`offline_utils.py:559-561`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L561)。
- **输出顺序等于输入顺序**——位于 [`offline_utils.py:626`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L626) 的最终排序，以单调递增的 ID 为键。
- **Transport 绝不会渗透到语义中**——位于 [`llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111) 的单一 client 句柄。
- **中止操作被隔离在提交之前**——[`core.py:501-503`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L501-L503) 在 `update_from_output` 之前运行。
- **grammar bitmask 归 scheduler 所有**，并在 GPU 延迟期间于 CPU 上构建——[`core.py:492-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L492-L499)。
- **检测到 stop string 会提升结束状态并闭合循环**，这是通过 `reqs_to_abort` 实现的——[`output_processor.py:678-681`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L678-L681)；这就是为什么 `EngineCoreOutput.finished` 与 processor 的结束原因在某一步中可以合理地不一致。
- **对外呈现的 `request_id` 始终是外部的那个**——[`output_processor.py:363-364`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L363-L364)。

### 每个箭头指向何处

文章 01 是总览图；路径上的每一跳都对应一个章节，它会在不重复内容的前提下放大细节。

| 路径上的箭头 | 深入文章 |
|---|---|
| 入口点：`LLM`、CLI、OpenAI server | 02 |
| 进程架构、ZMQ、client transport | 03 |
| `EngineCore` 循环、请求生命周期、输出处理内部机制 | 04 |
| scheduler：连续 batching、分块 prefill | 05 |
| KV cache manager、分页式 KV cache | 06 |
| 自动前缀缓存 | 07 |
| PagedAttention kernel、attention backend | 08 |
| worker、model runner、输入准备、CUDA graph | 09 |
| 采样、logits 处理、logprobs | 10 |
| 分布式推理与并行 | 11 |
| 推测式 decode | 12 |
| 扩展 vLLM：模型与插件 | 13 |

请从头到尾通读本文一次，以建立对整体形态和词汇体系的认知。从这里开始，这张图不会再改变——改变的只有分辨率。开篇提出的问题“`LLM.generate()` 如何变成一次模型 forward pass 和一个采样 token？”，现在可以用一句话回答：它会变成一个 `EngineCoreRequest`，由 client 交给处于忙循环中的 `EngineCore`；后者的 `step()` 事务会调度 token 预算，在 worker 上运行一次扁平化的 forward pass，在任何 grammar mask 的约束下采样一个 token ID，提交该 ID，并让 output processor 将其 detokenize 回 `RequestOutput`，最终把调用方自己的 id 带回去。除此之外的一切，都只是对这些动词之一的近距离观察。

## 13. 参考资料

- https://vllm.ai/blog/2023-06-20-vllm
- https://arxiv.org/abs/2309.06180
- https://docs.vllm.ai/en/stable/design/arch_overview/
- https://vllm.ai/blog/2025-01-27-v1-alpha-release
- https://vllm.ai/blog/2025-09-05-anatomy-of-vllm
- https://docs.vllm.ai/en/stable/api/vllm/sampling_params.html

*所有关于代码的结论均以 [`vllm-project/vllm@6cf7b26bd`](https://github.com/vllm-project/vllm/tree/6cf7b26bd4bff60bf378e1af14044280ac0d214c) 为依据。*