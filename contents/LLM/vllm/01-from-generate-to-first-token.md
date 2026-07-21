# vLLM 源码导读：从 `generate()` 到第一个 token

> 系列基线：[`vllm-project/vllm@6cf7b26bd`](https://github.com/vllm-project/vllm/tree/6cf7b26bd4bff60bf378e1af14044280ac0d214c)。本文以这个固定 commit 为准阅读 V1 源码，并与 vLLM 的工程博客和稳定版设计文档相互核对。代码片段均来自该 commit；为聚焦主题，部分片段省略了无关行，所有省略处都以 `...` 标出，除标为伪代码的行外，其余都与源码一致。源码定位采用 `path:Lstart-Lend` 的形式，并链接到 GitHub 上的固定 commit。

## 1. 为什么应该先读请求路径

vLLM 是一个庞大的系统，包含了融合 Attention Kernel（Fused Attention Kernels）、基于 Block 的 KV Cache 管理器（Block-based KV Cache Manager）、连续批处理调度器（Continuous Batching Scheduler）、Tensor / Pipeline / Data 并行，以及 Speculative Decoding 等多个核心模块。

很多人会忍不住从 Kernel 开始阅读，因为 vLLM 最知名的创新大多集中在那里。但这其实并不是一个好的切入点。PagedAttention Kernel 本身只负责根据上层已经构建好的 Block Table 进行计算。如果一开始就去读 Kernel，你看到的只是一个问题的答案，却还不知道这个问题是如何产生的。

更好的方式是，沿着一次请求（request）的完整生命周期，从头到尾走一遍。这样，后面遇到的每一个子系统都不再只是一个孤立的性能优化技巧，而会变成请求处理链路上的一个明确环节——你会知道它负责什么、由谁维护，以及它必须保证哪些不变性（invariants）。

*为什么这条路径值得关注*，归根结底是一个内存问题。值得重申这一点，因为正是它让这条路径不只是简单的流程串接。发布文章把 vLLM 的出发点归结为一个瓶颈：LLM 服务受内存限制，KV cache 占据了内存开销的大头，而 PagedAttention 的目的，就是让这部分内存易于分配、共享和复用（[发布文章](https://vllm.ai/blog/2023-06-20-vllm)）。SOSP 论文对这一机制给出了形式化描述，并报告称，在延迟相当的情况下，相比 FasterTransformer 和 Orca 等此前的系统，吞吐量提升了 2–4 倍（[论文](https://arxiv.org/abs/2309.06180)）。但要注意，这种内存管理真正*发生*在哪里：不是在只负责解引用 block table 的 kernel 中，而是在请求路径上——请求进入时分配 block，通过 prefix caching 共享，并在请求完成时释放。只有跟踪一个请求跨过这些边界，才能看清让 vLLM 得以成立的那个瓶颈。这才是应该先读这条路径的真正原因。

本文围绕的是本系列开篇提出的问题：

> `LLM.generate()` 如何变成一次模型 forward pass 和一个采样得到的 token？

<a href='images/vllm-01-01-request-flow.svg' target='_blank'><img src='images/vllm-01-01-request-flow.svg' alt='vllm-01-01-request-flow'></a>

<p class='figure-caption'>从公开的 `generate()` 调用一路向下得到一次 engine 输出，再以 `RequestOutput` 的形式返回。</p>

### engine 的四项功能

在看任何代码之前，先统一术语。架构概览将 engine 概括为四项核心功能，这也是整个系列的主线（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）：

> “输入处理……调度：‘选择每个 step 要处理哪些请求’……模型执行：‘管理语言模型的执行’……输出处理：‘处理模型生成的输出，对 token ID 进行解码’。”

*输入处理*将原始 prompt 转换成 engine 所需的请求形式，包括 tokenization、多模态预处理和参数的最终确定（[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）。*调度*在每个 step 决定执行哪些请求，以及每个请求获得多少 token（[第 7 节](#7-调度一个-step概览)；深入解析文章 05）。*模型执行*在 GPU 上运行 forward pass 并生成 logits（[第 8 节](#8-模型执行从-executor-到-logits概览)–[第 9 节](#9-从-hidden-states-到采样得到的-token概览)；文章 08–09）。*输出处理*将 token ID 解码回用户可见的文本（[第 10 节](#10-输出处理enginecoreoutput-到-requestoutput)；文章 04）。后续文章会深入介绍这些职责及其边界。

### 这四项功能构成一个反复执行的事务

这四项功能并不是一条每个请求只走一遍的 pipeline。其中三项——调度、执行、处理——构成 engine 反复运行的一个*事务*。这个事务每个“step”执行一次，每轮让执行中的请求前进几个 token，直到各自完成。这不是比喻。它就是一个方法的方法体。

[`vllm/v1/engine/core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)（节选；[第 6 节](#6-engine-step调度执行和处理输出)完整引用了这个方法）：

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

<p class='figure-caption'>continuous batching 的运行过程：每次 `EngineCore.step()` 都会推进本轮获得 token budget 的请求，不同请求会在不同 step 独立进入和完成——四项功能中，调度、执行和提交每个 step 都会重复一次，而输入处理只在开始时执行一次。</p>

docstring 中的 “Schedule, execute, and make output” 用四个词概括了整个架构。`schedule()` 在不接触 GPU 的情况下决定*为哪些请求分配多少 token*；`execute_model(..., non_block=True)` 发起 forward pass 并返回一个 `Future`，因此 CPU 可以*在 GPU 计算的同时*构建语法位掩码；`future.result()` 是同步点（如果执行阶段延后了采样，则会通过单独的 `sample_tokens` 调用来完成）；`_process_aborts_queue()` 会在合并输出之前，处理本轮内新到的取消操作；`update_from_output` 则将采样得到的 token 合入请求进度。第 6 节会逐行回到这个方法。文章 05、08–10 和 04 分别介绍 scheduler、执行、采样和生命周期的细节。

**不变量。** 这里讨论的三个生成入口——离线 `LLM.generate`、`AsyncLLM.generate` 和兼容 OpenAI 的 server——最终都会把任务提交给同一个 EngineCore 事务，并对其输出进行适配。`generate()` 本身并不调度 token、分配 KV block 或运行 kernel；它只负责校验输入、分配请求 ID，以及从 engine 中取出输出。

### 请求路径是一条职责边界链

因为 engine 本质上是一个由 adapter 包裹的小型事务，所以请求路径可以看作一条*职责边界链*，每个边界都守护着一项契约。公共 API 负责校验、补齐默认值以及恢复输入顺序。输入处理器负责把 prompt 转换成一个有明确所有权、默认值已完整补齐的传输结构体。engine client 负责提供与传输方式无关的接口。`EngineCore` 负责调度、执行和提交事务，但把所有生命周期状态交给 scheduler 管理，包括哪些请求正在等待、运行或已经完成，以及哪些 block 归谁所有。scheduler 负责 token 和内存决策；worker 负责 tensor 和 logits；sampler 负责 token ID；输出处理器负责 detokenization、停止字符串以及最终的 `RequestOutput`。这些职责方之间的每一条连线都对应后续一篇文章。提前明确它们的价值在于，当出现 bug 或功能设计问题时——“谁决定 `max_tokens`？”“停止字符串在哪里被检测？”“block 何时释放？”——你已经知道该去看哪个边界。

### 路径会跨进程，但如何跨进程取决于部署方式

文章 01 必须尽早说明的一个复杂之处是，这些边界并不全在同一个进程里。V1 有意将四项功能拆分到多个进程，使 CPU 密集型工作（tokenization、多模态预处理、detokenization、streaming）可以与 GPU 密集型工作重叠执行（[v1](https://vllm.ai/blog/2025-01-27-v1-alpha-release)、[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）。前端进程（`AsyncLLM`）负责 HTTP、输入处理和 streaming；`EngineCore` 进程运行 scheduler、KV cache 并协调执行；worker 负责运行 forward pass。一个使用四张 GPU、tensor 并行度为 4 的部署，具体进程数如下：

> 4-GPU、TP=4 部署 = **1 个 API server + 1 个 engine core + 4 个 GPU worker = 6 个进程**（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）；启用 data 并行时，还会增加一个 DP Coordinator 进程。

同一份配置之所以能够一致地传到全部六个进程，是因为一个 `VllmConfig` 对象会贯穿整个技术栈进行传递：“通过将所有配置封装到一个对象中，我们可以方便地传递配置对象，并访问所需的配置”（[架构](https://docs.vllm.ai/en/stable/design/arch_overview/)）。

这种拆分**不会**暴露到请求语义中。`LLMEngine` 只持有一个指向 engine 的句柄，传输细节封装在这个句柄之后。

[`vllm/v1/engine/llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111)：

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

这条注释完整说明了契约：client“接收 `EngineCoreRequest`，返回 `EngineCoreOutputs`”。`make_client` 在构造时根据 `multiprocess_mode` 一次性选定具体实现：要么是一个直接调用 `EngineCore` 的 in-process 对象，要么是一个将请求序列化后通过 ZMQ socket 发送给持续忙轮询的 `EngineCore` 进程的 client。从这里往后，请求路径上的其他部分既不知道也不关心拿到的是哪一种——在两种实现中，`add_request` 和 `get_output` 的签名完全相同。（有一点值得特别说明：即使是“离线”`LLM`，默认也会使用 multiprocess client，因为 `VLLM_ENABLE_V1_MULTIPROCESSING` 的默认值是 true；in-process 路径是退出这一默认行为后的选择，本身并非默认。文章 03 会详细介绍这个传输分支。）


### 如何阅读本文后续内容

文章 01 是一张地图，地图上的每一跳都会在后续章节中展开。封装 `generate()` 的入口和 OpenAI server 见文章 02；进程架构和 ZMQ 传输见文章 03；`EngineCore` 循环和请求生命周期见文章 04；scheduler（continuous batching、chunked prefill）见文章 05；KV cache manager 见文章 06，prefix caching 见文章 07；PagedAttention kernel 和 attention backend 见文章 08；worker、model runner 和 CUDA graph 见文章 09；采样和 logits 处理见文章 10；分布式推理见文章 11；speculative decoding 见文章 12；扩展 vLLM 见文章 13。这些文章会逐步补充实现细节，但请求路径本身保持不变。

## 2. LLM.generate()：离线便捷层

从图的最上方说起（[第 1 节](#1-为什么应该先读请求路径)）：`LLM.generate()` 是请求路径上的第一个所有权边界，而且它有意设计得平淡无奇。它不调度 token，不分配 KV block，也不启动任何 CUDA kernel。它的全部职责就是校验调用、生成具体的采样参数、创建请求 ID、把任务交给 engine，并阻塞到所有结果都返回，然后恢复调用方的输入顺序。只有准确理解这个边界在哪里，以及它提供了哪些契约保证，本文后续才能把它下面的一切都视为一个黑盒：输入 `EngineCoreRequest`，输出 `RequestOutput`。

离线接口实际上只涉及两个文件。`vllm/entrypoints/llm.py` 负责校验和构建 engine；`vllm/entrypoints/offline_utils.py` 负责 render → add → drain 这条主链路。`LLM` 类本身是一个由多个 mixin 组合而成的门面类：

[`vllm/entrypoints/llm.py:66`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L66)

```python
class LLM(BeamSearchOfflineMixin, PoolingOfflineMixin, OfflineInferenceMixin):
```

<a href='images/vllm-01-12-facade-method-map.svg' target='_blank'><img src='images/vllm-01-12-facade-method-map.svg' alt='vllm-01-12-facade-method-map'></a>

<p class='figure-caption'>离线门面层中的方法归属：`LLM` 上公开的 `generate` / `chat` / `enqueue` 负责校验、补默认值和编排，并通过唯一的 `LLMEngine` 句柄，将工作委托给 `OfflineInferenceMixin` 上的 `_render_and_add_requests → _add_request → _run_engine` 主链路——门面层之上没有任何调度、内存或执行逻辑。</p>

这些公开方法（`generate`、`chat`、`enqueue`）都位于 `LLM` 上，负责校验、补默认值和编排。`enqueue` 会调用 `_add_completion_requests()`，把请求放入 engine queue 并返回其 ID（[`llm.py:487-530`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L487-L530)）；`generate` 和 `chat` 则委托给同一条 render/add/drain 路径。调度、内存管理和执行仍然都在门面层以下。

### 检查、补默认值、委托

`generate()` 分三步完成交接：

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

按顺序来看。第一步是 **runner 类型检查**：模型必须以生成式 runner 的形式加载，因此 pooling/embedding 模型会在这里被拒绝，此时还没有创建任何请求对象。第二步是**生成默认参数**：如果调用方传入 `sampling_params=None`，`get_default_sampling_params()`（[`llm.py:415-420`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L415-L420)）会读取模型自身 `generation_config` 的差异配置（`get_diff_sampling_param()`），或者退回到一个最基本的 `SamplingParams()`。第三步是**委托**给 `_run_completion`，并将 `output_type=RequestOutput` 固定为传入参数。


<a href='images/vllm-01-03-generate-layers.svg' target='_blank'><img src='images/vllm-01-03-generate-layers.svg' alt='vllm-01-03-generate-layers'></a>

<p class='figure-caption'>离线调用栈——`LLM` 门面层（校验/默认值/ID），下接 `OfflineInferenceMixin`（render/add/drain），再下接唯一的 `LLMEngine` 句柄；每一层都标出了自己负责保障的一项契约。</p>

### 对齐 batch，然后强制使用 FINAL_ONLY

`_run_completion` 分为两个阶段：先将所有请求入队，再以阻塞方式 drain engine。在接收任何一个请求之前，`_add_completion_requests` 会把按位置传入的四组输入（prompt、参数、LoRA、优先级）规范化为长度相同的序列。其中最关键的是“标量就广播，否则就校验”这条规则：

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

单个 `SamplingParams` 会广播给所有 prompt；如果按 prompt 提供的列表长度不等于 prompt 数量，就会在添加任何请求**之前**抛出 `ValueError`。`_lora_request_to_seq` 和 `_priority_to_seq` 也遵循相同的规则。经过这一步后，prompt、参数、LoRA 请求和优先级就会按位置对齐，因此长度不匹配会直接被拒绝，而不会把某个 prompt 与相邻 prompt 的配置错误配对。随后会以*惰性*方式 render prompt：在默认的 multiprocess 模式下，engine 已经开始处理 prompt `i` 时，prompt `i+1` 仍可以继续 render。传入已经具体化的列表会触发 `warning_once`（[`offline_utils.py:504-512`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L504-L512)）。

每组对齐后的元组都会送到 `_add_request`。离线路径会在这里确定两项标志性决策：

[`vllm/entrypoints/offline_utils.py:559-563`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L563)

```python
        if isinstance(params, SamplingParams):
            # We only care about the final output
            params.output_kind = RequestOutputKind.FINAL_ONLY

        request_id = str(next(self.request_counter))
```

第一，**输出类型会被强制设为 `FINAL_ONLY`**，覆盖调用方原先设置的值。这个 enum 明确定义了三种模式：

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

<p class='figure-caption'>`RequestOutputKind` 对比：`CUMULATIVE` 会反复发送不断增长的完整结果；`DELTA` 只发送新增的部分（使用 mailbox `aggregate=True`）；`FINAL_ONLY` 只在完成时发送一次输出——这正是 `_add_request` 为离线 batch 推理强制采用的模式，也是 drain 循环中的 `if output.finished:` 所依赖的模式。</p>

离线 batch 推理不使用 streaming；`FINAL_ONLY` 会让下游的 `OutputProcessor` 在请求完成时只发送一个 `RequestOutput`。这会原地修改调用方的 `SamplingParams` 对象（pooling 参数不是 `SamplingParams`，因此不会被修改），而 drain 循环中的 `if output.finished:` 过滤逻辑依赖的正是这种 final-only 行为。

第二，**请求 ID 是单调递增的十进制字符串**，由 `__init__` 中创建的 `Counter()` 依次生成：`"0"`、`"1"`、`"2"`，……顺序与提交顺序一致。最终排序利用的正是这一顺序。

`_render_and_add_requests` 还会捕获 batch 中途出现的异常，终止本次调用已经添加的请求，然后重新抛出异常（[`offline_utils.py:545-548`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L545-L548)）。因此，一次 render 失败不会让同一 batch 中更早的请求继续在后台运行。

### 阻塞式 drain 与输入顺序恢复

请求加入后，`generate()` 会进入同步驱动循环，反复调用 engine 自己的 step：

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

<p class='figure-caption'>为什么最后必须有 `sorted(...)`：continuous batching 允许请求不按提交顺序完成（scheduler 可以自由交错安排 prefill 和 decode），因此，由 `Counter()` 生成的单调递增十进制 ID 可以让封装层恢复输入顺序，避免把“保持提交顺序”放进 scheduler 的热路径。</p>

循环条件使用的是 *engine 自己*维护的状态——`has_unfinished_requests()` 由输出处理器提供依据（[`llm_engine.py:188-195`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L188-L195)），并不是本地计数器。因此，刚刚注册的任务会立即可见，循环会持续执行 step，直到没有任何未完成的任务。每次 `llm_engine.step()` 都会完成一轮完整的调度 → 执行 → 处理输出（这一封装会在本文介绍 engine step 的一节中说明；它所驱动的 `EngineCore` 循环则见文章 04）。`assert isinstance(output, output_type)` 是与入口检查相配套的运行时保障：有了 `output_type=RequestOutput`，pooling 输出会触发这条 assertion，而不会被静默返回。由于参数已被强制设为 `FINAL_ONLY`，`if output.finished:` 对每个请求只会收集一次。最后，结果会通过 `sorted` 按请求 ID 的整数值排序。

最后的排序正是单调递增 ID 存在的意义。continuous batching 允许较晚提交的请求先于较早提交的请求完成，让 scheduler 可以在运行中的请求集合之间自由交错安排 prefill 和 decode。[`offline_utils.py:623-625`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L623-L625) 处的注释说明了这样做的原因。API 调用本身仍然是阻塞式的；engine 完成整个 batch 后，封装层会恢复输入顺序。文章 05 会解释这种自由为什么对 scheduler 有利。

### 一个用户请求可能变成 n 个 engine 请求

门面层也负责约束并行采样。当 `SamplingParams.n > 1` 时，`LLMEngine.add_request` 会把一个逻辑请求展开为 `n` 个子请求，每个子请求都有自己的 ID 和子级采样参数，但返回的仍然是*父请求*的 ID：

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

每个子请求都会在*两侧*注册——输出处理器侧负责 detokenize 和聚合，EngineCore 侧负责调度——而 `ParentRequest` 会将它们合并成一个用户可见的结果。离线 `tqdm` 的计数也反映了这一点：进度条会按 `n = len(output.outputs)` 递增。子级采样参数的派生见文章 10；双侧注册见文章 04。

## 3. 输入处理：prompt 如何变成 EngineCoreRequest

在公开调用与 scheduler 之间的是 `InputProcessor.process_inputs`。它接收多种不同形式的输入——裸 `str`、`TextPrompt`、预先 token 化的 ID、预计算的 embedding、encoder/decoder 对，或者多模态数据包——并生成下游使用的、符合传输格式的 `EngineCoreRequest`。

这里最重要的架构事实是这些工作在*哪里*运行。V1 特意把 tokenization、多模态预处理、detokenize 和 streaming **移出了执行热循环**，让 CPU 密集型的准备工作可以与 GPU 工作重叠执行（[V1 博客](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。`process_inputs` 是这一拆分的前端部分。请求到达 `EngineCore` 时，tokenization 已经完成，参数已经补齐默认值，多模态特征也已经展平——核心循环从不接触 tokenizer。

<a href='images/vllm-01-04-input-to-request.svg' target='_blank'><img src='images/vllm-01-04-input-to-request.svg' alt='vllm-01-04-input-to-request'></a>

<p class='figure-caption'>一次 `process_inputs` 调用会把五种形态的 prompt（文本、token、embedding、encoder/decoder、多模态）汇入统一的 `EngineCoreRequest` 传输结构体。</p>

### 边界及其签名

这一转换只有一个入口。

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

<p class='figure-caption'>`process_inputs` 内部：一组有序关卡——校验（`_validate_params` / `_validate_lora` / DP rank 范围）→ 根据 `isinstance(prompt, dict) and "type" in prompt` 分支（已 render 的 `EngineInput` 原样使用，或者走已弃用的 `InputPreprocessor.preprocess()`）→ 拆分 encoder/decoder 并检查长度 → `params.clone()` + 最终定型 → 展平多模态输入 → 构建 `EngineCoreRequest` → `assign_request_id`；每个阶段都会增加一项契约保证。</p>

这个签名中的两个类型 union 体现了整体设计。`prompt: PromptType | EngineInput` 表示输入既可以是*原始*用户 prompt，也可以是*已经 render* 的 `EngineInput`（下文还会详述这一分支）。`params: SamplingParams | PoolingParams` 表示 `params` 的运行时类型决定了后续 pipeline 的任务类型——生成还是 pooling。返回类型则始终固定为 `EngineCoreRequest`。

这个方法由 `LLMEngine.add_request` 调用，它是输入处理与上一节 engine 边界之间的衔接点。

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

可以把它看作两步交接：`process_inputs` 先构建结构体，然后 `assign_request_id` 再为它补上标记（本节末尾会介绍）。只有这两步都完成后，`add_request` 才会向输出处理器和 engine core 注册请求。

### 校验先于 tokenization 执行

`process_inputs` 做的第一件事就是拒绝格式不合法的请求，而且会在送进 tokenizer 处理一遍*之前*完成这项检查。

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

`_validate_params` ([`input_processor.py:82-144`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L82-L144)) 会强制保证任务与参数一致：`SamplingParams` 必须与 `GENERATION_TASKS` 有交集，否则会抛出 `raise ValueError("This model does not support generation")`；`PoolingParams` 也必须与 `POOLING_TASKS` 有交集。过程中它会调用 `params.verify(...)`。这个方法只做*校验*（参数不一致时会抛出异常——[`sampling_params.py:736-751`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/sampling_params.py#L736-L751) 只是分派到一系列无副作用的 `_validate_*` 检查），但**不会**修改参数；调用方的参数会一直保持不变，直到在 [`input_processor.py:315`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L315) 处被克隆，此后的最终设置过程只修改克隆对象。`_validate_lora` (`:146-163`) 会把在未启用 `lora_config` 时发起 LoRA request 视为硬错误。上面的 DP rank 边界检查会拒绝超出范围的 engine 目标。


### fork：已渲染输入与已弃用的原始路径

这里有个衔接细节，常让第一次阅读 V1 的人感到意外：`InputProcessor` **自己并不持有 tokenizer**。tokenization 和 HF 多模态处理器现在都封装在 `Renderer` 后面，由上游入口调用（见第 02 篇文章）。`process_inputs` 更希望接收已经由渲染器处理完成的输入。

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

判别依据是 `isinstance(prompt, dict) and "type" in prompt`。带有 `"type"` key 的 dict 会被视为已经渲染完成的 `EngineInput`，并被**原样**使用——这里完全不会执行 tokenization；甚至可以直接从 dict 中读出 `arrival_time`。其余所有输入——单独的 `str`、`TokensPrompt`、enc/dec dict——都会落入**已弃用**的 `InputPreprocessor.preprocess()`，后者会把实际的 tokenization 委托回渲染器（[`vllm/inputs/preprocess.py:68-88`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/inputs/preprocess.py#L68-L88) 展示了 `_tokenize_prompt` 如何代理 `self.renderer`）。两条分支最终都会汇合到 `current_platform.validate_request(...)`。

当前路径会在上游完成渲染——包括 tokenization 和多模态处理——然后传入完整的 `EngineInput`。为向后兼容，原始路径和内联的 `tokenization_kwargs` 仍然保留，但已标记为将在 v0.18 中移除。两条分支都会生成带有 `"type"` 判别字段的 `EngineInput`。第 02 篇文章跟踪渲染过程；第 06 和第 07 篇文章跟踪由此产生的 token 和 cache key。

### 克隆参数并完成最终设置

拆分 encoder/decoder 输入并校验长度和词表之后（`:298-309`、`:387-484`——decoder prompt 不能为空，也不能超过 `max_model_len`；长度正好等于 `max_model_len` 时，对于 `generate` 模型同样不允许，因为这样连一个输出 token 的空间都没有），sampling 参数会被克隆并完成最终设置。

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

<p class='figure-caption'>在克隆对象上完成参数的最终设置：`max_tokens` 默认设为 `max_model_len - seq_len`（在 `[0 .. max_model_len]` 这一上限下恰好剩余的预算），`update_from_generation_config` 和 `update_from_tokenizer` 会合并模型默认值，并且 `sampling_params` / `pooling_params` 中最终恰好只有一个不是 `None`——因此 engine core 永远不会看到值为 `None` 的 token 预算。</p>

调用方的 `params` 会被**克隆**，因此每个 request 的最终设置都不会修改调用方可能在多个 prompt 之间复用的共享对象。然后，对于 sampling：未设置的 `max_tokens` 会被填为 `max_model_len - seq_len`（恰好是剩余预算）；模型的 `generation_config` 默认值和 EOS ID 会经由 `update_from_generation_config` 合并；从 tokenizer 得到的 stop token 则经由 `update_from_tokenizer` 合并。此后，`sampling_params` / `pooling_params` 中恰好只有一个不是 `None`。

**不变量。** EngineCore 接收到的是一个由自己拥有、默认值已全部补齐的参数对象。`max_tokens` 已有明确值，因此下游代码无需再依赖 `model_config` 或 tokenizer 来补齐 request 的默认值。

### 多模态扁平化与双 hash

多模态输入到达时按模态分组（`{"image": [...], "audio": [...]}`）。这一阶段会将它们扁平化为一个按序列顺序排列的列表。

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

<p class='figure-caption'>每个 `MultiModalFeatureSpec` 中的双 hash：`mm_hash` 用作与 LoRA 无关的处理器 cache 的 key，而 encoder cache 标识符可以包含 LoRA 名称。</p>

`argsort_mm_positions`（刚在上面的 `:352` 处调用）会根据条目在 token 序列中的偏移量排序，因此 `mm_features` 是一个扁平列表，其中各条目跨所有模态按从左到右的顺序排列。每个 `MultiModalFeatureSpec` 都带有**双 hash**：`mm_hash`（原始、与 LoRA 无关的 hash，用作*处理器* cache 的 key）和 `identifier`（用作*encoder 输出* cache 的 key；当 LoRA 可以改变视觉 embedding 时，还可能像 `"{lora_name}:{mm_hash}"` 那样加上 LoRA 前缀——见 `_get_mm_identifier`、`:165-181`）。

像素完全相同但 LoRA 不同的两个 request 会获得不同的 encoder cache 标识符，而与 LoRA 无关的处理器 cache 仍可共享。第 07 篇文章会继续跟踪这些标识符如何进入 prefix cache key；这里相关的一点是，它们由输入处理阶段创建。

### 输出：一个无需 GC 的传输结构体

所有内容最终都会汇入同一个构造函数。

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

注意 `cache_salt=decoder_inputs.get("cache_salt")`——salt 会在 `process_inputs` 中原样传递，直到后面才作为仅作用于第一个 block 的 prefix cache 命名空间标签使用（第 07 篇文章）。它构造出的结构体有意按传输需求设计。

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

关键就在这三个 `msgspec.Struct` 选项。`array_like=True` 按位置序列化字段（没有字段名开销）；`omit_defaults=True` 在传输时跳过值为默认值的字段；`gc=False` 使这个结构体不受 Python 循环垃圾回收器管理。这些选择很重要，因为在默认的 multiprocess 路径上，该结构体会被序列化并通过 ZMQ 发送（第 03 篇文章介绍拓扑，第 04 篇文章介绍负责解码的循环）。一个 `.params` 属性（[`__init__.py:139-145`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L139-L145)）会返回已赋值的参数字段，并断言其中之一确实存在。构造过程确保 `sampling_params` 与 `pooling_params` 互斥（[`input_processor.py:311-330`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L311-L330)。


### 最后一道标记：request ID 随机化

`process_inputs` 返回后，流程回到 `add_request`，request 会在注册前完成标记（上面的 `assign_request_id` 调用，见 [`llm_engine.py:263`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L263)）。

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

调用方提供的 ID 会保存在 `external_req_id` 中，而 `request_id` 会变为 `"{external}-{8 random chars}"`。


## 4. Engine 边界：in-process 与 multiprocess client

前几节一路跟踪一个 prompt，直到它变成 `EngineCoreRequest`。EngineCore 可以与 `LLM.generate()` 位于同一个进程中，也可以位于 ZMQ socket 后面的后台进程中，还可以位于多个数据并行 engine 进程中的一个。前端统一使用一个 client 接口，而且对每个 client 来说，传输方式在其整个生命周期内固定不变。本节会跟踪这道边界，以及跨越它传输的数据。

### 一个句柄，只选一次

`LLMEngine`（离线 `LLM` 路径使用的同步 engine）只持有一条通往调度与执行的通道。它在构造函数中创建，类型标注为抽象 client，而不是具体的传输实现。

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

`self.engine_core` 是从 `LLMEngine` 通往调度与执行的主要路径。`add_request`、`step`、`abort_request`、`sleep`、`add_lora` 和 `collective_rpc` 等操作都通过这个字段转发。`asyncio_mode=False` 选择同步 client 家族；在线 `AsyncLLM` 路径传入 `True`。`multiprocess_mode` 由一个 classmethod 构造器创建：

[`vllm/v1/engine/llm_engine.py:157`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L157)

```python
            multiprocess_mode=envs.VLLM_ENABLE_V1_MULTIPROCESSING,
```

**不变量。** 前端依赖 `EngineCoreClient` 接口，而不是具体的传输实现。`add_request`、`step` 和输出处理都不会根据 `multiprocess_mode` 做分支判断；这一选择由 client 分派机制处理。

只有一个带保护条件的例外会穿透这层抽象：

[`vllm/v1/engine/llm_engine.py:123-125`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L123-L125)

```python
        if not multiprocess_mode:
            # for v0 compatibility
            self.model_executor = self.engine_core.engine_core.model_executor  # type: ignore
```

`self.engine_core.engine_core` 这次两级访问会穿过 `InprocClient`，进入它的本地 `EngineCore`，再到 `model_executor`。multiprocess client 没有本地 EngineCore 对象，因此这个分支受 `if not multiprocess_mode` 保护。

### 工厂是 fork 点

三种传输实现都由同一个抽象基类统一封装，而 `make_client` 会根据两个布尔值选择拓扑。

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

<p class='figure-caption'>把 `make_client` 看作关于 `(multiprocess_mode, asyncio_mode)` 的真值表：`(F,F)`→`InprocClient`，`(T,F)`→`SyncMPClient`（离线默认值，因为 `VLLM_ENABLE_V1_MULTIPROCESSING` 为 `True`），`(T,T)`→`make_async_mp_client`（`AsyncMPClient` + DP 变体），`(F,T)` 会被拒绝——这三种实现共享 `EngineCoreClient` 这个 ABC，其基类方法体都会抛出 `NotImplementedError`。</p>

四种组合，三种结果：`(mp=False, async=False)` → `InprocClient`；`(mp=True, async=False)` → `SyncMPClient`（multiprocess 离线路径）；`(mp=True, async=True)` → 异步 client 家族（`AsyncMPClient` 及其 DP 变体，也就是在线 server 路径）；`(mp=False, async=True)` 会被明确拒绝——不能在 asyncio 下让 engine 以 in-process 方式运行。基类的 docstring 在一处集中写明了这份约定：

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

ABC 声明每个同步操作及其 `_async` 镜像方法；基类方法体会抛出 `NotImplementedError`。因此，传输实现必须实现它所支持的方法。成对的方法名（`add_request`/`add_request_async`、`get_output`/`get_output_async`、`abort_requests`/`abort_requests_async`）让两条前端路径在结构上保持相似。

### Offline 默认使用 multiprocess，而不是 in-process

人们很容易想当然地认为，离线 `LLM` 会以 in-process 方式运行 engine——毕竟这里没有 HTTP server。事实并非如此。回想一下，构造函数的默认值来自 `envs.VLLM_ENABLE_V1_MULTIPROCESSING`，而该环境变量的默认值是 `True`：

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

因此，在这个基线版本中，普通的 `LLM(model=...).generate(...)` 脚本会得到 `multiprocess_mode=True` → `SyncMPClient`，让 EngineCore 运行在一个通过 ZMQ 访问的后台进程中。禁用 V1 multiprocessing 会选择 `InprocClient`。`multiprocess_mode: bool = False` 这个在 `LLMEngine.__init__` 上直接给出的默认值，会被 `from_vllm_config`/`from_engine_args` 构造函数覆盖。“Offline”描述的是 API 契约，而不是 in-process 拓扑。

<a href='images/vllm-01-05-engine-boundary.svg' target='_blank'><img src='images/vllm-01-05-engine-boundary.svg' alt='vllm-01-05-engine-boundary'></a>

<p class='figure-caption'>同一个 `add_request` 调用，两种实现：内联方法调用（InprocClient）与在 engine 的 IO 线程上解码的序列化 ROUTER 帧（SyncMPClient），最终都会汇入同一个 `preprocess_add_request → scheduler.add_request` 二元组。</p>

### InprocClient：边界缩为一次方法调用

当 engine 以 in-process 方式运行时，“client”只是一层很薄的封装，它*持有*一个真正的 `EngineCore` 并直接调用它——没有序列化，没有 socket，也没有 busy loop。

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

由此可以看出两点。第一，`add_request` 恰好是在调用方线程上进行的两次内联调用：`preprocess_add_request` 将传输形态的 `EngineCoreRequest` 转换为内部的 `Request`（为它计算 block 哈希并初始化 grammar），然后 `add_request` 将这个 `Request` 交给 scheduler。第二，`get_output` 会*推进* engine 执行一个 step：`step_fn` 就是 engine 自己的 `step`（在 pipeline parallelism 下则是 `step_with_batch_queue`），因此在 in-process 模式下，前端调用 `step()` 实际上*就是* engine 的 step——没有其他独立循环负责推进。`outputs.get(0)` 会选择索引为 0 的 engine，因为 in-process 模式下只有一个 engine。这就是 docstring 所说的“V0 风格”：准入和 `step()` 都在调用方线程上执行，没有独立的 EngineCore busy loop。这只描述 frontend 到 EngineCore 的边界——executor 和 worker 是否并发，仍取决于并行配置。

### SyncMPClient：同一个调用，序列化为自描述帧

在 multiprocess 模式下，同一个 `add_request` 会变成序列化后发送。*请求*本身没有任何变化，变的只是传递方式。

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

<p class='figure-caption'>`SyncMPClient` 传输帧：一条有序的 multipart 消息 `(engine_identity, one-byte type tag, *msgpack payload)`，通过 `zmq.ROUTER` 发送到 engine 的 `zmq.DEALER`；在 `len(msg) <= 3` 时，它只是普通的零拷贝 `send_multipart`，否则带外 tensor buffer 会要求 `track=True` + `add_pending_message` 保留该 buffer，直到 ZMQ 完成发送——这些都由 `ensure_alive()` 统一封装。</p>

传输消息是一个有序的、自描述的 multipart 帧：`(engine_identity, one-byte type tag, *msgpack payload)`。identity 帧用于寻址某个特定的 engine（在 data parallelism 下存在多个 engine 时，这一点必不可少）；类型字节让接收方无需 schema 协商即可完成 demux；payload 是 `msgspec` msgpack。这里出现了三项多进程传输特有的状态管理，而 `InprocClient` 不需要处理它们：如果受监控的 engine 进程已经退出，`ensure_alive()` 会抛出 `EngineDeadError`（因此这个边界不只传递数据，也传递存活状态）；`len(msg) <= 3` 分支用于保证零拷贝 tensor 的安全——如果编码后的请求携带带外 tensor buffer（多模态），client 就必须通过 `zmq.MessageTracker` *保留一个引用*，直到 ZMQ 完成对底层内存的发送，否则这块内存可能在发送过程中被释放；`add_request` 采用 fire-and-forget——发送后便返回，输出则通过另一个 socket 异步返回。`self.input_socket` 是由 client 绑定的 `zmq.ROUTER`；engine 会连接一个 `zmq.DEALER`，因此 identity 帧位于最前面。更深层的 socket 拓扑——这些 socket 如何连接、DP coordinator、负载均衡路由，以及必须记住每个进行中请求位于哪个 engine 的 abort 路由——是**文章 03**的主题；这里我们只需要了解 client 契约。

### 传输协议的类型标签只有一个字节

这个边界采用的协议是一个很小的带标签联合类型。每种请求类型本身就是一个十六进制字节，因此放入 frame 前不需要额外的编码步骤。

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

<p class='figure-caption'>`EngineCoreRequestType` 路由：`ADD` / `ABORT` / `UTILITY` 经 socket 从 client→engine 传递（只有 `ADD` 会使用有类型的 `MsgpackDecoder(EngineCoreRequest, ...)`；其余类型共用一个无类型解码器），`START_DP_WAVE` 从 coordinator→engine 传递，而 `EXECUTOR_FAILED` / `WAKEUP` 是 in-process 哨兵，不会经 socket 传输，但会复用同一条单一 demux 分发路径。</p>

`ADD`、`ABORT` 和 `UTILITY` 是实际通过 socket 从 client 传输的类型；`START_DP_WAVE` 从 coordinator 传给 engine；`EXECUTOR_FAILED` 和 `WAKEUP` 则是被放入 engine 自身 input queue 的*in-process 哨兵*，永远不会经 socket 传输——它们复用同一条分发路径，因此 busy loop 只需要一个 demux。只有 `ADD` 配有专用的*有类型*解码器 `MsgpackDecoder(EngineCoreRequest, ...)`，因为它会反序列化为有类型的 `EngineCoreRequest` 结构体；其他所有类型都共用一个无类型的通用解码器（[`core.py:1494-1497`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1494-L1497)）。（两个解码器都使用同一个 `oob_tensor_provider` 构建，因此是否支持带外 tensor *并不是*二者的区别——在接纳路径上 tensor 通常随 `ADD` 一起传递，但协议本身并不限制只有该类型才能携带 tensor。）有返回值的操作（`get_supported_tasks`、`sleep`、`add_lora`、`collective_rpc`）都通过 `UTILITY` 传输，使用 `call_id` 标记，并关联回一个 `Future`，从而让本质上异步的 socket 往返对外呈现为阻塞式 API——在 in-process 模式下，这些方法只是普通的 Python 返回。

### 对称性：生命周期相同，只是线程换了位置

两种传输方式之所以能共用同一份契约，是因为它们会*以相同顺序执行相同的两个操作*——multiprocess 路径只是把这两个操作拆到线程边界两侧。`InprocClient.add_request` 会内联地先调用 `preprocess_add_request`，再调用 `scheduler` 侧的 `add_request`。multiprocess engine 执行的也是完全相同的两个操作，但 `preprocess_add_request` 运行在专用的输入 IO 线程上，由该线程解码帧；生成的 `(Request, wave)` tuple 通过线程安全的 queue 传递；`add_request` 则运行在 busy loop 线程上。engine 自己的 docstring 说明了这样设计的目的：

[`vllm/v1/engine/core.py:855-860`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L855-L860)

```python
    def preprocess_add_request(self, request: EngineCoreRequest) -> tuple[Request, int]:
        """Preprocess the request.

        This function could be directly used in input processing thread to allow
        request initialization running in parallel with Model forward
        """
```

这正是拆分进程带来的好处：较重的请求初始化工作（block 哈希、grammar 编译）可以与 GPU 工作重叠执行，而不再阻塞后者。in-process client 运行的是完全相同的代码，却没有这种流水化；这是让 engine 运行在调用方线程上所付出的代价。

两种模式都会运行 `preprocess_add_request → scheduler.add_request`；multiprocess 模式只是把两部分移到不同线程上，让初始化能够与模型执行重叠。`get_output()` 也保持了相同的阻塞式签名：in-process client 直接让 EngineCore 执行 step，而 multiprocess client 则等待由 socket 排空线程写入的 queue。engine 退出和解码错误会以异常值的形式通过该 queue 到达，因此前端的 step 循环无论获取数据还是接收故障，都使用同一个方法。

这就是请求路径其余部分所依托的边界。上游的公共 API 和输入处理器（本文[第 2 节](#2-llmgenerate离线便捷层)–[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）会把一个完整构造好的 `EngineCoreRequest` 交给 client，而不关心它会去哪里。下游的 `EngineCore.step()`——也就是接下来要讲的 `schedule → execute → commit` 事务——无论由 `InprocClient.get_output()` 内联调用，还是由后台进程的 busy loop 调用，运行方式都完全相同。关于 `SyncMPClient`/`AsyncMPClient` 所隐藏的 socket 拓扑、DP 路由和 coordinator 内部实现，请参阅**文章 03**（进程架构与 ZMQ）；关于并行机制如何在同一个 client 后面扩展出多个 engine 和 worker，请参阅**文章 11**。

## 5. add_request：请求进入 EngineCore

传输方式在构造 client 时就已经确定，不会改变请求的表示形式。本节继续追踪 `add_request`：两侧的注册、并行采样的扇出，以及传输形态的 `EngineCoreRequest` 变成由 scheduler 管理的 `Request` 的位置。scheduler 准入、KV block、grammar 编译和子请求采样将在后续的深入分析中继续展开。

### 一个请求，两个注册点

当执行到 `LLMEngine.add_request` 末尾时，原始 prompt 已经经过 `input_processor.process_inputs`（文章 01 [第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)），现在已经是 `EngineCoreRequest`，其中的 `SamplingParams` 已补齐所有默认值，并且是一个独立副本。剩下的就是注册——而且刻意分为两侧。

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

`assign_request_id` 会写入内部 ID（外部 ID 加 8 个随机字符——文章 01 [第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)）；`req_id` 就在*这里*保存，也就是在所有扇出发生之前，因此调用方最终拿到的就是这个 ID。样本数量 `n` 从采样参数中读取（pooling 请求始终是 `n == 1`）。接着，fast path 严格按以下顺序执行两件事：

1. `output_processor.add_request(request, prompt_text, None, 0)`——创建 `RequestState`，由它负责 detokenize 和聚合，并在在线模式下持有调用方的输出 mailbox。这是*返回路径*注册。
2. `engine_core.add_request(request)`——把请求交给 client，由 client 提交等待调度。这是*forward 路径*注册。

这个顺序并非偶然。输出侧会在请求提交执行**之前**完成注册，因此 `EngineCoreOutput` 绝不会在 `OutputProcessor` 尚未知道某个请求时就为它到达。这样消除了“先输出、后注册”的竞态，否则一个很快完成的请求可能会丢掉首个 token。出于同样的原因，离线模式下的 drain loop 也能立刻看到这项注册：

源码定位：[`vllm/v1/engine/llm_engine.py:188-195`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L188-L195)

```python
    def get_num_unfinished_requests(self) -> int:
        return self.output_processor.get_num_unfinished_requests()

    def has_unfinished_requests(self) -> bool:
        has_unfinished = self.output_processor.has_unfinished_requests()
        if self.dp_group is None:
            return has_unfinished or self.engine_core.dp_engines_running()
        return self.has_unfinished_requests_dp(has_unfinished)
```

两个“是否还有未完成的工作？”判定条件都由 `output_processor` 提供依据，而不是 engine core。因此，上面的步骤 (1) 一返回，`LLM._run_engine` 的 `while has_unfinished_requests():` 循环（文章 01 [第 2 节](#2-llmgenerate离线便捷层)）就会持续调用 `step()`，直到该请求完成——即使 engine 进程尚未确认收到它。请求是否仍处于活动状态，以输出处理器为准；实际工作则在 engine core 中执行。

### 一个用户请求，n 个 engine 请求

值得关注的是 `n > 1`——并行采样，也就是用户希望同一个 prompt 生成多个 completion 的情况。vLLM 不会让 scheduler 理解“n 次采样”这个概念。它会把单个请求扇出为 `n` 个相互独立的 engine 请求，并在返回时重新组装它们。

源码定位：[`vllm/v1/engine/llm_engine.py:279-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L279-L294)

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

`ParentRequest` 会包装原始请求。它会为每个子请求索引生成一个子请求 ID 和一组子请求采样参数：

源码定位：[`vllm/v1/engine/parallel_sampling.py:83-94`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/parallel_sampling.py#L83-L94)

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

每个子请求的 ID 都是在父请求 ID 前加上自身索引（`0_<parent>`、`1_<parent>`，……）；各子请求的 sampling 参数会分别派生（seed 处理和每个子请求的 `n → 1` 折叠都属于 sampling 的内容——文章 01 [第 9 节](#9-从-hidden-states-到采样得到的-token概览) / 深度文章 10）。最后一个子请求（`idx == n - 1`）*复用原始请求对象*而不是复制它，这是为了减少内存分配；前面的子请求则通过 `copy(request)` 得到。每个子请求都会在两侧注册，与 `n == 1` 快速路径的做法一样——但现在每次 `output_processor.add_request` 都会传入共享的 `parent_req` 和该子请求自己的 `idx`；`OutputProcessor` 后续正是凭这些信息，把 `n` 路 stream 重新合并为一路。

**不变量。** 并行 sampling 在一个用户可见请求之下表示为 `n` 个 engine 请求。scheduler 和 worker 处理的是扁平的子请求；`OutputProcessor` 负责聚合、取消和输出排序。

### 跨越边界：EngineCoreRequest 变为 Request

`self.engine_core.add_request(child_request)` 看起来只是一次调用，但其内部发生了一次类型转换，这才是真正进入 engine 所有权范围的地方。前端传入的对象是 `EngineCoreRequest`，即免 GC 的 msgspec 传输结构体。engine 的 scheduler 收到的对象则是 `vllm.v1.request.Request`。转换发生在 `preprocess_add_request` 中：

源码定位：[`vllm/v1/engine/core.py:855-877`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L855-L877)

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

`Request.from_engine_core_request` 会构造内部请求，并让 block 哈希器处理 prompt token（为 prefix cache 查找准备哈希值——文章 01 [第 7 节](#7-调度一个-step概览) / 深度文章 07）。对于结构化输出请求，`grammar_init` 会启动 grammar 编译。docstring 直接说明了设计意图：“可以直接在输入处理线程中使用，让请求初始化与模型 forward 并行运行。”正如 engine 边界一节已经说明的那样，两种传输方式正是在这里分开：`InprocClient.add_request` 会在调用方线程中内联执行 `preprocess_add_request`，再执行 `add_request`；`EngineCoreProc` 则在输入 IO 线程中执行 `preprocess_add_request`，并由 busy loop 调用 `add_request`——仍是相同的两个操作、相同的顺序，只是改变了执行位置，从而让 block 哈希和 grammar 编译可以与 GPU forward pass 重叠执行（文章 01 [第 4 节](#4-engine-边界in-process-与-multiprocess-client)；ZMQ 线程模型见深度文章 03）。无论采用哪种方式，最终到达 engine 调度侧的都是 `Request`，绝不会是传输结构体。

### Engine 侧接纳

engine 侧的 `add_request`——也就是 busy loop（或 `InprocClient`）最终调用的方法——很短，而这恰恰是重点。

源码定位：[`vllm/v1/engine/core.py:372-407`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L372-L407)

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

<p class='figure-caption'>engine 侧的 `add_request`：三项检查（请求 ID `str`、pooling 任务成员关系、未配置 connector 时的 KV 传输警告）、一次移交给 `self.scheduler.add_request(request)`，以及 `abort_immediately` 这个边界情况——此后只有 scheduler 负责 WAITING→RUNNING→FINISHED 状态机，而中止只是 `finish_requests(ids, FINISHED_ABORTED)`。</p>

三项检查、一次移交、一个边界情况：

- **类型检查** — 请求 ID 必须是 `str`；尽管前端已经检查过，这里仍会再次断言，因为在 multiprocess 模式下，对象是通过 socket 传来的，engine 不会默认信任任何输入。
- **Pooling 任务检查** — 如果请求带有 `pooling_params`，其中的 task 必须属于模型支持的 pooling 任务，否则执行 `ValueError`。生成请求会跳过这项检查。
- **KV 传输警告** — 请求带有 `kv_transfer_params`，但没有配置 `KVConnector` 时，不会被拒绝；系统只会留下一条警告并禁用传输（这属于解耦式 prefill 的范畴，见深度文章 11）。
- **移交** — `self.scheduler.add_request(request)`。这一行就是进入 scheduler 所有权范围的分界线。从这里开始，请求会进入 waiting queue，其 block 由 KV cache manager 管理，状态机（WAITING → RUNNING → FINISHED）也完全归 scheduler 所有。`EngineCore.add_request` 不会修改计数器、分配 block 或设置状态——它只负责验证和委托。至于 `scheduler.add_request` 如何处理请求——将其放入 queue、向 KV connector 注册、记录 QUEUED 事件——则是文章 01 [第 7 节](#7-调度一个-step概览) / 深度文章 05 的内容。
- **边界情况** — `abort_immediately`。一个请求可以在同一次调用中先被接纳，随即中止，从而触发 KV connector 的 `request_finished` 钩子，释放接纳前已经预留的资源。这不是额外拼接上去的错误路径，而是通过*同样的*两个原语来表达接纳和清理。

### 中止就是结束

最后一点可以推广为整个 engine core 的所有权约定。中止没有一套独立机制：

源码定位：[`vllm/v1/engine/core.py:409-415`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L409-L415)

```python
    def abort_requests(self, request_ids: list[str]):
        """Abort requests from the scheduler."""

        # TODO: The scheduler doesn't really need to know the
        # specific finish reason, TBD whether we propagate that
        # (i.e. client-aborted vs stop criteria met).
        self.scheduler.finish_requests(request_ids, RequestStatus.FINISHED_ABORTED)
```

中止一个请求就是调用 `scheduler.finish_requests(ids, FINISHED_ABORTED)`——这与 scheduler 在请求正常结束时使用的调用完全相同，区别只在于终止状态。系统不存在一条单独的“取消”路径，以另一种方式释放 block；正因如此，中止操作具备竞态安全性：无论请求是遇到 EOS、命中停止字符串（由 `OutputProcessor` 上报为中止，文章 01 [第 10 节](#10-输出处理enginecoreoutput-到-requestoutput)），还是因为 client 断开连接而被取消，它都会从同一个状态机退出，所有 block 释放也都由该状态机负责。深度文章 04 会讨论 `finish_requests` / `_free_request`，以及延迟、以 GPU step 为栅栏的释放操作。`EngineCore` 从不直接释放 block 或推进计数器；每次生命周期变更都必须通过 `self.scheduler`。

### 异步路径中的对应流程

在线路径会按相同顺序注册相同的两侧，只是多了一步——会在提交*之前*为每个请求创建输出 mailbox。

源码定位：[`vllm/v1/engine/async_llm.py:400-412`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L400-L412)

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

调用方（`AsyncLLM.add_request`）首先创建 `RequestOutputCollector`，即稍后由 `generate()` 读取的单槽位 mailbox（文章 01 [第 11 节](#11-streaming异步生成器以及为什么第一个-token-很特殊)），并在这里将其作为 `queue` 传入。`_add_request` 将 `RequestState`（此时已经持有该 mailbox）注册到 `OutputProcessor`，*然后*对提交到 engine core 的操作执行 `await`。注释明确写出了进程边界：输出处理位于“本进程”，engine core 则位于“独立进程”。由于这两步位于同一条不会交错执行的 `await` 链中，而且注册发生在提交时的 await 之前，因此可以严格保证，在该请求产生任何输出之前，mailbox 已经存在。同步路径中的 `LLMEngine.add_request` 则天然拥有同样的保证——它的两次注册只是同一线程上的普通顺序调用。两条路径遵守的都是“先注册、后提交”这一约定；asyncio 只是要求你显式保证这个顺序。

<a href='images/vllm-01-06-add-request.svg' target='_blank'><img src='images/vllm-01-06-add-request.svg' alt='vllm-01-06-add-request'></a>

<p class='figure-caption'>`add_request` 会在两侧注册请求——`OutputProcessor`（返回路径）和 `EngineCore`→`Scheduler`（forward 路径）——其中 `n>1` 会在同一个 `ParentRequest` 下扇出多个子请求，而 `EngineCoreRequest`→`Request` 的转换标志着请求进入 scheduler 的所有权范围。</p>

## 6. Engine Step：调度、执行和处理输出

此前的所有步骤都在适配或传输请求。到了 `EngineCore.step()`，运行时会调度工作、启动执行、处理 sampling 和中止，并整合输出。“Inside vLLM”这篇导读把同一个循环概括为：选择请求、运行模型、对 token 进行 sampling、更新状态，以及释放已完成请求的资源（[Inside vLLM](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）。

<a href='images/vllm-01-02-engine-step.svg' target='_blank'><img src='images/vllm-01-02-engine-step.svg' alt='vllm-01-02-engine-step'></a>

<p class='figure-caption'>一个 engine step：调度 → 执行 → sampling → 提交这一事务，以及位于其两侧的两个所有权边界。</p>

### `EngineCore.step()` 的四项工作

一个 step 会让 scheduler 决定运行哪些工作，以非阻塞方式启动 forward pass，并发准备结构化输出 bitmask；如果执行阶段延后了 sampling，就在这里完成 sampling；随后处理 queue 中积压的中止请求，最后根据 sampling 得到的 token 更新请求状态。

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


**工作 0——前置检查（[`core.py:488-489`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L488-L489)）。** `if not self.scheduler.has_requests(): return {}, False`。scheduler 为空时不会运行模型。上方注释还把已经结束但尚未从 batch 中移除的请求算在内，因此 `has_requests()` 的含义比“仍在生成的请求”更宽。只要还有请求完成相关工作或 connector 工作需要收尾，它就仍然为真。文章 04 会继续追踪生命周期的这段尾部。

**工作 1——调度（[`core.py:490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490)）。** `scheduler.schedule(self._should_throttle_prefills())` 会返回 `SchedulerOutput`，并且*不运行任何模型代码*。它决定运行哪些请求、每个请求分配多少个新 token、分配或复用哪些 KV block，以及抢占哪些请求。model runner 会根据这些请求变化和 token 分配结果更新持久 batch，并构建执行所需的 attention 与 sampling 状态。在基类中，`_should_throttle_prefills()` 就是 `False`（[`core.py:474-477`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L474-L477)），只有数据并行 engine 会为了平衡 prefill 而覆写它。“给哪些请求分配多少 token”具体意味着什么——continuous batching、chunked prefill、prefix cache 复用——正是文章 05 的全部内容；文章 01 只说明，这一个调用就是该 step 的全部调度决策。

**工作 2——执行、重叠、采样（[`core.py:491-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L491-L499)）。** 这是串联各个环节的关键技巧。`execute_model(scheduler_output, non_block=True)` 会立即返回一个 `Future`，而不会阻塞等待 GPU。`get_grammar_bitmask(scheduler_output)` 会填补这段空档，在 CPU 上构建结构化输出的 token 掩码，*与此同时，forward pass 也在运行*。`future.result()` 是同步点。`model_output is None` 这个哨兵值表示 executor 将采样推迟到了另一次调用 `sample_tokens(grammar_output)` 中，因此采样时会把结构化输出掩码应用到*当前* step 的 logits 上。`execute_model` 背后的 executor→worker→model runner→logits 调用链见文章 08–09；`sample_tokens` 背后的 logits→token ID 步骤见第 10 篇。对于端到端路径，有两个事实很重要：grammar 位掩码来自 *scheduler*，而不是 HTTP 层；CPU 端的掩码准备会与 GPU 执行重叠，其开销能否被部分或完全隐藏，取决于两侧的相对耗时。

**中止窗口（[`core.py:501-503`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L501-L503)）。** `self._process_aborts_queue()` 在 `future.result()` *之后*运行——此时 GPU 帧已经结束——但在 `update_from_output` *之前*运行。这种顺序正是关键所在：如果外部取消请求是在 GPU 忙碌期间到达的，它会在采样得到的 token 写入请求状态之前被处理，因此在一帧执行期间被取消的请求绝不会继续推进。负责清空 queue 的辅助函数（[`core.py:634-642`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L634-L642)）会把整个 queue 合并成一次 `abort_requests` 调用；由于中止已经完成的请求是幂等操作，中止操作可以安全地同时进入两个 queue（见第 04 篇）。

**工作 3——提交（[`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506)）。** 在 `scheduler.update_from_output(scheduler_output, model_output)` 中，采样得到的 token 会转化为请求进度：追加输出 ID、设置结束原因，并启动已完成请求的清理。KV block 会在安全时立即释放；如果仍有 in-flight GPU step 可能引用它们，则先进入 `deferred_frees`。该方法返回一个按所属 client 组织的 `dict[client_index → EngineCoreOutputs]`，而 tuple 的第二个元素——`scheduler_output.total_num_scheduled_tokens > 0`——就是循环包装器会读取的 `model_executed` 标志。

**不变量。** 调度可以在执行前预留 block 并更新计划计数器，但采样得到的 token、终止状态及相应的收尾工作，要等模型输出到达后通过 `update_from_output` 统一更新。在 GPU 帧执行期间排队的中止操作，会在这次更新前被清空。

### 为什么调用方看不到这个方法

`EngineCore.step()` 返回的是 `EngineCoreOutputs`——token ID、结束标志和按 client 路由的信息——而不是面向用户的 `RequestOutput` 对象。离线调用方从不直接接触它。`LLM._run_engine` 的清空循环实际调用的是 `LLMEngine.step()`，这是另一个文件中的同步包装器，而且与核心循环运行在不同的进程中。

来源：[`vllm/v1/engine/llm_engine.py:296-334`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L296-L334)

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

<p class='figure-caption'>`LLMEngine.step()` 对核心循环做了一层包装：`get_output()`（多态衔接点）→ `output_processor.process_outputs(...)` → `engine_core.abort_requests(reqs_to_abort)`，并把因停止字符串而结束的请求反馈回去，使*下一次* `EngineCore.step()` 能在中止窗口将它们终止——因此，`EngineCoreOutput.finished` 与 processor 的结束原因相差一个 step 是完全合理的。</p>


- **`get_output()` 是多态衔接点（第 304 行）。** 它在两种传输方式下都有完全相同的阻塞式调用签名（[第 4 节](#4-engine-边界in-process-与-multiprocess-client)）。使用 `InprocClient` 时，它会在调用方线程上行内运行一次 `EngineCore.step()` 并返回输出；使用 `SyncMPClient` 时，它会阻塞在一个 queue 上，这个 queue 由后台线程从核心进程的忙循环中获取数据并填充。离线 `LLMEngine.step()` 的写法就像 engine 位于本地一样；无论 engine 实际是否在本地，client 抽象都能让这个假设成立。
- **`process_outputs`（第 309 行）是 token ID 转化为文本的地方。** `OutputProcessor` 会增量执行 detokenize、检查停止字符串，并构造出 `RequestOutput` 对象。这是返回路径的边界，在这份路线图中属于第 10 篇；这里的重点是，它位于 `EngineCore` *之外*。
- **`abort_requests`（第 318 行）闭合了整个循环。** 核心内部无法检测停止*字符串*——这需要 detokenize 后的文本——因此 `process_outputs` 会返回 `reqs_to_abort`，而这一行会把它们反馈给 engine。这些 ID 随后进入 `aborts_queue`；*下一次* `EngineCore.step()` 会在中止窗口清空它。因此，`EngineCoreOutput.finished` 与 processor 的结束原因相差一个 step 是完全合理的。
- **dummy batch 快速路径（第 297-300 行）**用于数据并行的锁步执行：即使某个 rank 没有任务，也仍然必须执行一个空 batch，其他 rank 才能继续。


### 同一个 step，在后台进程中的封装方式

在默认的 multiprocess 部署中（[第 4 节](#4-engine-边界in-process-与-multiprocess-client)），`EngineCore.step()` 根本不会在调用方线程上运行——它运行在 engine 进程的常驻循环中：

来源：[`vllm/v1/engine/core.py:1259-1267`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1259-L1267)

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

每一轮都会先接收 client 输入，然后通过 `_process_engine_step` 恰好执行一个 step（[`core.py:1300-1317`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L1300-L1317)）；它会调用 `self.step_fn()`，将每个 `(client_index, EngineCoreOutputs)` 对放入输出 queue，交给 IO 线程序列化，运行 spec-decode 的 `post_step` hook；如果该 step 没有调度任何可运行任务但仍有请求存在，还会休眠 1 毫秒以让出 GIL，使后台 KV 传输线程能够继续推进。`step_fn` 在构造时只会绑定一次，目标要么是 `step`，要么是 pipeline-parallel 版本的 `step_with_batch_queue`（[`core.py:221-224`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L221-L224)），因此循环不需要在每一轮根据并行方式进行分支。忙循环机制、关闭时的清空处理以及已完成请求的状态记录，是第 04 篇深入讨论的内容；第 01 篇在这里只强调结构：**同步离线 `LLMEngine.step()` 与异步忙循环，本质上是同一个 `EngineCore.step()` 事务的两种包装方式**——既可以由 `InprocClient` 在调用方线程中行内推进，也可以由 EngineCore 进程的 busy loop 推进——默认的 `SyncMPClient` 对离线调用方提供阻塞式接口、等待后台循环返回的结果，`AsyncMPClient` 则异步接收并分发结果。事务是契约；变化的只有驱动方式。

这个 step 的内部实现对应以下章节：第 **05** 节介绍 `schedule()` 会做出什么决定；第 **08/09** 节介绍 `execute_model` 背后发生的事情；第 **10** 节介绍 `sample_tokens`；第 **12** 节介绍 `post_step` 的 draft token 反馈；第 **04** 节介绍忙循环、关闭过程和已完成请求的生命周期。下一节会深入第一条箭头所指的部分——scheduler。

## 7. 调度一个 step（概览）

刚才我们看到，`EngineCore.step()` 只用一行开场——`scheduler.schedule(...)`——随后就把一个 `SchedulerOutput` 交给 executor。本节仍停留在本文其余部分采用的概览层级：它会解释 *scheduler 会做出什么决定*、让 prefill、decode、chunked prefill、prefix caching 和 speculative decoding 共用同一个循环的*一个核心思路*，以及 *scheduler 边界双向传递的内容*。内部细节——queue、token 预算核算、`allocate_slots` 和抢占——属于第 05 篇（Scheduler：Continuous Batching 与 Chunked Prefill）。这里我们只把这个模块接入请求路径。

### scheduler 决定的是 token，而不是 tensor

scheduler 只负责规划。它在 EngineCore 进程内的 CPU 上运行，从不接触 GPU。一次调用只回答一个问题：*在我当前跟踪的请求中，哪些会在本 step 运行，每个请求又会推进多少个 token？* 答案是一个 `SchedulerOutput`，也就是一份计划。执行这份计划则是同一 `step()` 中随后进行的独立阶段。

源码位置：[`vllm/v1/engine/core.py:488-490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L488-L490)

```python
        if not self.scheduler.has_requests():
            return {}, False
        scheduler_output = self.scheduler.schedule(self._should_throttle_prefills())
```

源码位置：[`vllm/v1/engine/core.py:474-477`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L474-L477)

```python
    def _should_throttle_prefills(self) -> bool:
        """Whether to defer new prefills this step (DP prefill balancing).
        Overridden by the DP engine core; never throttles otherwise."""
        return False
```


- `:488-489` 处的检查意味着，模型绝不会在没有计划时运行；如果 scheduler 没有维护任何请求（甚至连已完成但尚未 flush 的请求也没有——见第 04 篇），这个 step 会短路，并返回 `model_executed = False`。
- `schedule()` 会立即返回一个 `SchedulerOutput`——没有 forward pass，也没有 logits。`step()` 中这一行之后的所有内容（`execute_model` future、grammar 位掩码、`sample_tokens`、`update_from_output`）都在消费这份计划；它们都不是计划本身。
- 在基类中，`_should_throttle_prefills()` 为 `False`；只有数据并行 engine core 会覆盖它，以便为 replica 间的均衡推迟新的 prefill（第 11 篇“分布式推理与并行”）。对于当前跟踪的单 engine 路径，这个参数始终是 `False`。


### 一个核心思路：不分 prefill 阶段和 decode 阶段

V1 博客这样概括这项核心简化：V1 不再把 prefill 和 decode 视为两个不同的 scheduler 阶段，而是统一处理所有 token，因此一次调度决策在概念上就是一个字典，`{request_id: num_tokens}`。Chunked prefill 使用的也是同一种模型：长 prompt 会拿到本 step 的一部分 token 预算，之后再继续处理（[V1 博客](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。`schedule()` 顶部的源码也表达了同样的思路。

源码位置：[`vllm/v1/core/sched/scheduler.py:396-407`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L396-L407)

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

<p class='figure-caption'>统一计数器模型：调度通过在本 step 分配若干 token，弥合 `num_computed_tokens`（KV 已填充量）与 `num_tokens_with_spec`（prompt + output + draft）之间的差距——无论是新的 prompt、chunked prefill、单 token decode、prefix cache 跳转，还是 speculative draft token，本质上都是同一种弥合差距的操作，因此请求路径只需按“多少个 token”进行分支。</p>

- 每个请求都带有两个计数器：`num_computed_tokens`（KV cache 已填充到什么位置）和 `num_tokens_with_spec`（prompt + 已生成 token + 可能存在的 speculative draft token）。调度就是在当前 step 分配若干 token，以缩小这两个计数器之间的差距。
- 新的 prompt 从 `num_computed_tokens = 0` 开始，差距很大，因此表现为很大的 token 需求；处于 decode 阶段的请求差距为一（启用 speculative decoding 时还要加上 draft token）。两者其实是同一种操作——“推进 `num_computed_tokens`”——区别只在分配到的数量。
- 由于分配数量可以*小于*差距，chunked prefill 不需要单独的 code path：它本质上只是某个 prompt 没有在一个 step 内拿到填补全部差距所需的 token。
- Prefix caching 和 speculative decoding 在同一条注释中被列为这套通用机制的两个例子：prefix caching 通过复用已经算好的 block，缩小请求的有效差距（第 07 篇，Automatic Prefix Caching）；speculative decoding 则用待验证的 draft token 增大 `num_tokens_with_spec`（第 12 篇，Speculative Decoding）。


### 优先级：先推进 running 请求，再接纳 waiting 请求

当每个 step 的 token budget 固定时，scheduler 会先处理已在 `running` queue 中的请求，再用剩余 budget 接纳等待中的 prefill（[vLLM 内部](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）——这通常有利于 decode 延迟，但处于 `running` 的请求也可能仍在完成 chunked prefill。源码中 loop 的顺序直接体现了这一点。

源码定位：[`vllm/v1/core/sched/scheduler.py:440-442`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L440-L442)

```python
        # First, schedule the RUNNING requests.
        req_index = 0
        while req_index < len(self.running) and token_budget > 0:
```


- 首先在 `token_budget` 的约束下逐一处理 `running`；第二轮（未展示——见第 05 篇）再用剩余 budget 接纳等待中的请求。
- 这正是 continuous batching 和 chunked prefill 能共存于*同一个* loop，而不必在两个阶段之间交替的原因：一个 step 可以同时包含一批正在进行的 decode，以及一个新 prompt 的一段 prefill，因为两者都只是在同一个 budget 下分配 token。

在这个 loop 中，正在运行的请求会先于等待中的 prefill 得到考虑。大型 prompt 使用剩余的 token budget，并可能被拆到多个 step 中。第 05 篇会介绍这项策略背后的 queue 运作机制、preemption 和 budget 计算。

### 跨出边界的内容：计划和两条结束信息通道

`SchedulerOutput` 是请求路径上从 CPU 规划阶段送往 GPU 执行阶段的载荷：它列出了新请求和已缓存请求、每个请求的 token 数、KV block 分配以及 spec-decode token（attention 元数据由 model runner 据此构建）。但它还带有一条容易忽略的带外通道——其中保存着*自上一个 step 以来已结束*的请求集合，让下游 worker 能清理各请求的状态。

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

这个集合会在每次调度时通过*重新赋值*来重置，而不是调用 `clear()`，目的正是让刚发出的 `SchedulerOutput` 仍保留自己的引用：

源码定位：[`vllm/v1/core/sched/scheduler.py:1213-1217`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1213-L1217)

```python
        # Clear the finished and preempted request IDs.
        # NOTE: We shouldn't just clear() here because it will also affect
        # the scheduler output.
        self.finished_req_ids = set()
        self.reset_preempted_req_ids = set()
```

请求结束的信息还必须通过第二条通道*传回 client*。释放请求时，会按 client 记录其 id，`update_from_output` 再把这些 id 附加到即将发出的 `EngineCoreOutputs.finished_requests` 上：

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


- `finished_req_ids`（一个 `set`）会随*下一个* `SchedulerOutput` 传递，使 worker 能从持久 batch 状态中移除已结束的请求（回顾一下 V1 的 differential-batch 设计：worker 会跨 step 缓存请求状态）。
- `finished_req_ids_dict`（按 `client_index` 分别记录）会随*发出的* `EngineCoreOutputs` 传递，让 frontend 的输出处理器知道请求已经结束，并回收其 `RequestState`。这两个集合都在 `_free_request` 中填充（[`scheduler.py:2116-2118`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L2116-L2118)）。
- 对请求路径而言，这意味着——此处只作概述，第 04 篇会详细展开——**两个消费者会在两个不同的时钟上看到结束事件。** 面向 client 的通知随*当前* step 的 `EngineCoreOutputs` 传递（`finished_req_ids_dict` 就是在当前这次 `update_from_output()` 的末尾合并进去的，[`scheduler.py:1833-1845`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/core/sched/scheduler.py#L1833-L1845)），因此 frontend 可以立即关闭 stream。只有 worker 侧的清理需要等待*下一个* `SchedulerOutput` 来携带 `finished_req_ids`。loop 的存活性判定（`has_requests()`）刻意设得足够宽松，能让 engine 继续运行以完成 worker 侧的 flush——但这不会延迟发给 client 的通知。

请求结束后，需要按不同的时钟为两个消费者维护记录：client 可以在当前输出中看到请求完成，而 worker 侧的状态则通过后续的 scheduler 反馈移除。

### 释放 block：以 GPU 执行为栅栏

scheduler 负责管理 KV block 的归属，而释放 block 恰恰会让“现在规划、稍后执行”的拆分带来正确性风险：请求可能已经结束，而它参与的某次 forward pass 仍在写入其 KV。因此，block 的释放可以*延后*，由尚未完成的 step 充当栅栏。

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

<p class='figure-caption'>结束信息会按两个时钟分发：`finished_req_ids` 随*下一个* `SchedulerOutput` 传递，使 worker 从持久 batch 中移除该请求；`finished_req_ids_dict` 则随*这个* step 的 `EngineCoreOutputs.finished_requests` 传递，使 client 回收其 `RequestState`——而 `_free_request_blocks` 要么立即释放 block，要么先把它们放入 `deferred_frees`，等仍在执行的 GPU 写操作完成。</p>


- 常见情况（`not self.defer_block_free`，或请求最后一次被调度的 step 已处理完成）会立即释放；正常的生成结束总会走这个分支。
- 如果 async scheduling 下仍可能有 GPU frame 正在写入该请求的 block（`last_sched_seq > processed_step_seq`），这些 block 会按 step 序号暂存于 `deferred_frees`，只有等该 step 完成后才归还。

**不变量。** 只要已入队的 GPU 写操作仍可能引用某个 cache block，就不能把该 block 归还池中。第 06 篇和第 07 篇会介绍这条规则背后的分配器、延迟释放和 prefix-cache 记录维护。

详细的 queue 算法、token budget 记账、preemption 和 `allocate_slots` 见第 05 篇。第 06 篇和第 07 篇继续介绍 cache 分配和 prefix 复用；第 12 篇介绍 draft token 的调度。

## 8. 模型执行：从 executor 到 logits（概览）

[第 7 节](#7-调度一个-step概览)最后给出了一份 `SchedulerOutput`，其中列出了一个 step 的请求及其 token 数。本节会沿着这份计划，依次经过 EngineCore、executor、worker 和 model runner，直到 hidden state 转换成 logits。PagedAttention 将在第 08 篇继续讲解，tensor 准备和 CUDA graph 见第 09 篇，从 logits 到 token 的 sampling 见第 10 篇。

回顾一下 `EngineCore.step()` 中把任务交给执行阶段的两行代码：

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

`self.model_executor` 是一个 `Executor`。下面的内容就是 `execute_model` 和 `sample_tokens` 这两个调用实际会进入的执行路径。

<a href='images/vllm-01-07-execution-path.svg' target='_blank'><img src='images/vllm-01-07-execution-path.svg' alt='vllm-01-07-execution-path'></a>

<p class='figure-caption'>`SchedulerOutput` 通过 `collective_rpc` 跨过 executor 边界，分发到一个或 N 个 worker，并返回唯一权威 worker 的 `ModelRunnerOutput`（最后一个 PP stage 的第一个 TP rank）。</p>

### executor 边界归结为一个方法：`collective_rpc`

`Executor` 屏蔽了模型执行使用一个还是多个 GPU 的差异。EngineCore 指定操作和目标集合；executor 负责分派 worker。

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


- executor 的两个公开方法都只是 `collective_rpc("<method_name>", args=...)` 的薄封装。指定的方法（`"execute_model"`、`"sample_tokens"`）会在组内的*每一个* worker 上调用；executor 是一个 fan-out 原语。
- 这里*展示的*返回值来自**抽象**基类的 `return output[0]`，但两个具体 executor 都覆写了这些方法，只向一个 worker 请求回复。`UniProcExecutor` 使用 `collective_rpc(..., single_value=True)`（[`uniproc_executor.py:108-131`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/uniproc_executor.py#L108-L131)）；`MultiprocExecutor` 使用 `unique_reply_rank=self.output_rank`（[`multiproc_executor.py:310-332`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L310-L332)），其中 `output_rank = _get_output_rank()` = `world_size − tp_size × prefill_context_parallel_size`——也就是位于*最后一个 PP stage* 的第一个 TP worker（[`multiproc_executor.py:498-512`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L498-L512)）。只有纯 TP 或单 GPU 时，它才等于全局 rank 0。在 tensor parallelism 下，每个 rank 都会对分片后的权重矩阵执行同一个 forward pass，并在 all-reduce 后得到相同的 logits，因此任意 TP rank 的 `ModelRunnerOutput` 都可作为最终结果；在 pipeline parallelism 下，权威输出位于最后一个 stage，executor 只向其中一个 rank 请求结果，而不是收集全部结果后再丢弃。
- `non_block=True` 正是[第 6 节](#6-engine-step调度执行和处理输出)中的重叠执行能够成立的原因：`collective_rpc` 返回一个 `Future`，而不是已经构建好的 `ModelRunnerOutput`，因此 `EngineCore.step()` 可以在 GPU forward pass 进行期间在 CPU 上运行 `get_grammar_bitmask`，随后调用 `future.result()` 作为同步点。

**使用哪个具体的 executor？** 它在构造时由 `Executor.get_class` 根据 `distributed_executor_backend` 一次性选定：

[`vllm/v1/executor/abstract.py:69-76`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L69-L76)

```python
        elif distributed_executor_backend == "mp":
            from vllm.v1.executor.multiproc_executor import MultiprocExecutor

            executor_class = MultiprocExecutor
        elif distributed_executor_backend == "uni":
            from vllm.v1.executor.uniproc_executor import UniProcExecutor

            executor_class = UniProcExecutor
```

单 GPU 时，backend 会解析为 `UniProcExecutor`，其 `collective_rpc` 只会在一个 in-process worker 上调用该方法。使用 tensor/pipeline parallelism 时，backend 会解析为 `MultiprocExecutor`（文档称其为 `MultiProcExecutor`），由它把 RPC 转发给 worker 子进程；另外也有基于 Ray 的 backend，相关内容全部留到第 11 篇。架构文档也用同样的方式概括了这种划分——tensor parallelism 使用 `MultiProcExecutor`，单 GPU 使用 `UniProcExecutor`（<https://docs.vllm.ai/en/stable/design/arch_overview/>）。


### 从 `SchedulerOutput` 到 forward pass：model runner

每个 worker 都有一个 model runner，每个 model runner 都封装了模型的 `torch.nn.Module`（<https://docs.vllm.ai/en/stable/design/arch_overview/>）。当 `collective_rpc("execute_model", ...)` 到达 worker 后，`GPUModelRunner.execute_model` 会先让 worker 的持久 batch 与 scheduler 的计划保持一致。

**源码定位。** [`vllm/v1/worker/gpu/model_runner.py:1122-1133`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1122-L1133)（节选；完整的对齐过程见第 09 篇）。

```python
            self.finish_requests(scheduler_output)
            ...
            self.add_requests(scheduler_output)
            self.update_requests(scheduler_output)
```

- worker 会跨多个 step 维护一个*持久* batch，并且只需**应用 scheduler 的差量**：它不会在每次迭代时接收重新构建的 tensor，而是移除已完成的请求、接纳新请求，并为仍在运行的请求刷新位置和 block table。这就是 V1 的“持久 / 差分 batch”，取代了 V0 每个 step 都重新创建 tensor 的做法 (<https://vllm.ai/blog/2025-01-27-v1-alpha-release>)。上面省略的一项保护检查 (`total_num_scheduled_tokens == 0`) 会直接返回 `kv_connector.no_forward(...)`，因此，如果某个 step 的调度纯粹是为了维护 KV connector 状态，就不会执行模型。完整的对齐项集合 — `finish_requests`/`free_states`/`add_requests`/`update_requests`/`apply_staged_writes` — 会在第 09 篇文章中介绍。
- 完成这些前置处理后，runner 会构建展平后的输入 batch 并运行模块。本轮调度到的 token 会被打包成一个长的“超级序列”；位置索引和 attention 元数据会确保每个序列只能关注自己的 token，从而在不做右侧 padding 的情况下实现 continuous batching (<https://vllm.ai/blog/2025-09-05-anatomy-of-vllm>)。*Input-ID/position/slot-mapping/block-table 的构建以及 CUDA graph 的 capture/replay 会在第 09 篇文章中介绍；消费这些 block table 的 attention kernel 会在第 08 篇文章中介绍。*

`SchedulerOutput` 是 batch 成员关系的权威来源。worker 会维护一份具体的本地 batch，并根据差量更新它；如果每个 step 都发送完整 tensor，就会把 CPU 侧的 tensor 构建重新放回执行路径。

### 关键转换：hidden states 变成 logits

一次 forward pass 会为本次调度的 token 生成 hidden states。model runner 会先选出 sampling 所需的位置，再将它们投影到词表空间。

**源码定位。** [`vllm/v1/worker/gpu/model_runner.py:1054-1058`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1054-L1058).

```python
        sample_hidden_states = hidden_states[input_batch.logits_indices]
        logits = self.model.compute_logits(sample_hidden_states)
        if grammar_output is not None:
            # Apply grammar bitmask to the logits in-place.
            assert self.structured_outputs_worker is not None
```


- 在展平后的 batch 中，`hidden_states` 的每一行对应一个已调度 token。`input_batch.logits_indices` 会选出需要下一个 token 分布的那些行 — 每个序列的最后一个位置，以及验证 speculative draft token 时需要的额外位置。这正是按需计算 logits 的意义：词表投影（`compute_logits`，一次 `hidden_dim × vocab_size` matmul）只需在少数几行上运行，而不必处理长 prefill 中的每个 prompt token。
- `compute_logits` 会应用 language-model head，并在 tensor parallelism 下汇总分片后的词表，以生成 `[num_sampled_positions, vocab_size]` logits。
- 如果 scheduler 为这个 step 附带了语法位掩码，就会在这里、sampling 之前，**原地**应用到 `logits`。这就闭合了[第 6 节](#6-engine-step调度执行和处理输出)开启的链路：`get_grammar_bitmask` 由 engine-core 的 CPU 线程在 forward pass 运行期间并发计算，以 `grammar_output` 的形式一路传递，最终准确作用于当初为其调度的那个 batch。结构化输出约束是通过给 logits 加掩码来执行的，而不是事后过滤 token。

runner 只投影 sampling 所需的末尾位置；在需要时，还会投影 draft verification 位置，而不是处理展平 batch 中的每个 hidden state。语法位掩码会传给与这些 logits 对应的 sampling 调用。

### 执行与 sampling 的交接处

有些执行路径会随 forward 结果一起返回采样得到的 token。另一些则会保留执行状态，等 CPU 生成的语法掩码准备好后，再由 EngineCore 调用 `sample_tokens(grammar_output)`。第 9 节会继续追踪这次调用；第 10 和第 12 篇文章分别介绍常规 sampling 和 speculative sampling。

源码：[`vllm/v1/worker/gpu/model_runner.py:1358-1371`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1358-L1371) 和 [`model_runner.py:1392-1394`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1392-L1394)

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

`execute_model` 在推迟 sampling 时，会把 batch、hidden states、attention 元数据和已完成请求的集合存入 `execute_model_state`。`sample_tokens` 会取回该状态，并在调用 `self.sample(...)` 前清空这个字段，确保所存状态在该执行 step 中只能使用一次。EngineCore 准备的 grammar 输出会在这里进入常规 sampler；如果存在 draft token，同一个方法随后会选择第 12 篇文章介绍的 rejection sampling 路径。

### 返回内容

`sample_tokens` 会把选中的 ID 封装进 `ModelRunnerOutput`。启用 speculative decoding 或 multi-token prediction 时，一个 step 可能会为某个请求返回多个 token，因此下游代码会把新 token 当作列表处理。`scheduler.update_from_output` 会记录结果并移除已完成的请求。

### 接下来交给哪里

executor 和分布式集合通信会在第 11 篇文章中继续介绍；tensor 准备和 CUDA graph 见第 09 篇文章；PagedAttention 见第 08 篇文章；sampling 策略见第 10 篇文章；rejection sampling 见第 12 篇文章。这里我们只需关注串联路径：worker 将 scheduler 差量转换为一次展平的 forward pass，把所需位置投影为 logits，在存在语法掩码时应用它，然后返回采样得到的 ID，供 EngineCore 提交。

## 9. 从 hidden states 到采样得到的 token（概览）

[第 8 节](#8-模型执行从-executor-到-logits概览)最后讲到将 hidden states 投影为词表 logits。V1 可以通过一个独立且可延后的调用，完成余下从 logits 到 token 的转换。第 10 篇文章会介绍惩罚项、temperature、top-k/top-p、min-p 和 logprobs；本节则沿着调用边界继续追踪采样得到的 ID。

### Sampling 刻意采用单独调用

在 engine step 中，`execute_model` 会以 `non_block=True` 运行，并返回 `Future`。如果这个 future 的结果是 `None`，就说明 executor 推迟了 sampling，因此 EngineCore 会调用 `sample_tokens`，并传入 forward pass 运行期间准备好的语法位掩码。

源码：[`vllm/v1/engine/core.py:497-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L497-L499)

```python
            model_output = future.result()
            if model_output is None:
                model_output = self.model_executor.sample_tokens(grammar_output)
```


- **`future.result()` 是 forward pass 的同步点。**如果 worker 已在本次调用中完成 sampling，它会返回 `ModelRunnerOutput`；如果 worker 已算出 hidden states，但尚未将其变成 token，则返回 `None`。
- **`None` 是延后处理的哨兵值。**它表示：“forward pass 已完成；logits 已经存在；请另行调用我来完成 sampling。”第二次调用 `sample_tokens(grammar_output)` 会传入结构化输出掩码 — 即 `grammar_output`；它就在上一行由 `self.scheduler.get_grammar_bitmask(...)` 计算出来 ([第 6 节](#6-engine-step调度执行和处理输出))，并且计算过程与 forward pass 并发进行。
- **掩码会在 sampling 时与 logits 汇合。**因为位掩码是在 GPU 运行期间由 CPU 构建，并且只在这次 `sample_tokens` 调用中应用，所以它会准确作用于*这个* step 的 logits，而这些 logits 对应的正是*这个* step 的请求。

**不变量。**由某个 scheduler step 生成的结构化输出位掩码，会被带入同一个 step 的 sampling 操作。EngineCore 会在非阻塞 model future 运行期间准备掩码；如果执行过程已经返回采样结果，就会跳过单独的 `sample_tokens` 调用。

### 跨越 executor 边界，与 `execute_model` 对称

`sample_tokens` 会跨过与 `execute_model` 相同的 executor 边界，并采用相同的 `collective_rpc` 形式。GPU 拓扑仍由 executor 负责。

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


- **`collective_rpc("sample_tokens", ...)` 会把调用分发给 worker group**，而*抽象*基类返回 `output[0]`。两个具体 executor 都会要求一个 worker 返回回复：`MultiprocExecutor` 使用最后一个 PP stage 的第一个 TP worker ([`multiproc_executor.py:310-332`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/multiproc_executor.py#L310-L332), `498-512`)，而 `UniProcExecutor` 使用 `single_value=True` ([`uniproc_executor.py:108-131`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/uniproc_executor.py#L108-L131))。因此，forward 和 sample 使用相同的 RPC 结构。
- **每个 worker 最终都会进入 `GPUModelRunner.sample_tokens`** ([`model_runner.py:1358-1363`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1358-L1363))，取回 hidden states 和 `InputBatch`；这些内容是它在 `execute_model` (`self.execute_model_state`) 期间暂存的。在最后一个 pipeline-parallel rank 上，它还会调用 `self.sample(hidden_states, input_batch, grammar_output)` ([`model_runner.py:1391-1394`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1391-L1394))。其他 PP rank 则会*接收*最后一个 rank 广播的采样 token — sampling 只会在最终 hidden states 所在的位置执行一次。

Sampling 会在 hidden states 所在的位置运行，并通过与 forward pass 相同的 executor 接口触发。executor 负责 TP/PP 分发和回复选择；这些细节会在第 09 和第 11 篇文章中介绍。从 EngineCore 的角度看，从 logits 到 token 只是另一项 `collective_rpc` 操作。

### 关键转换：hidden states 到 logits，再到采样得到的 token

在 model runner 内部，一个方法会把 forward pass 生成的 hidden states 转成 `SamplerOutput`。这就是模型执行与 sampling 之间的代码边界。

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


- **`hidden_states[input_batch.logits_indices]` 只选择需要生成 token 的位置。**forward pass 处理了展平 batch 中*所有*已调度 token ([第 8 节](#8-模型执行从-executor-到-logits概览))，但只有每个序列的最后一个位置（以及 spec decode 下的少量额外位置）需要 logit。`logits_indices` 会精确取出这些行，因此只需对少数位置做词表投影，而不必处理整个展平 batch。
- **`self.model.compute_logits(sample_hidden_states)`** 是从 hidden states 到词表的投影，也就是 language-model head。这一行就是本节标题所说的边界。
- **语法位掩码就在这里原地应用。**这就闭合了[第 6 节](#6-engine-step调度执行和处理输出)留下的链路：掩码归 scheduler 所有，经 `sample_tokens` 传递，并在 sampler 看到 logits *之前*直接应用到 logits 上 — 因此，结构化输出请求无法采样出语法不允许的 token。
- **`self.sampler(logits, input_batch)`** 是进入 sampler 本体的交接处（常规的非 spec decode 分支）。`else` 分支 ([`model_runner.py:1069-1078`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1069-L1078)) 会在存在 draft token 时转到 `self.rejection_sampler` — 也就是 speculative decoding，留到第 12 篇文章介绍。

通过 `[logits_indices]` gather 时，只会投影需要 logits 的位置，而不会为展平 batch 构造完整的 `[num_all_tokens, vocab_size]` tensor。在常规 decode 中，这就是每个请求的最后一个位置；speculative verification 可能还会选择额外位置。

### sampler 入口

`self.sampler(...)` 调用 `Sampler.__call__`。后者为每个请求准备对应的 view，并将 token 抽取交给 `Sampler.sample`。抽取前执行的这些操作构成 logits 处理流水线。

源码：[`vllm/v1/worker/gpu/sample/sampler.py:198-216`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L198-L216)（摘录；完整流水线见第 10 篇文章）：

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

<p class='figure-caption'>从 hidden states 到 token ID：`hidden_states[input_batch.logits_indices]` 只选取需要 logits 的位置，`compute_logits` 将其投影到词表空间，随后原地应用由 scheduler 持有的 grammar bitmask，再由 `apply_sampling_params` 按顺序执行各项操作（bias / `min_tokens` → penalties → bad words → temperature → min-p，top-k/top-p 延后处理）。这些操作会在独立的 fp32 副本上完成，然后再进行抽取，因此采样开销随被选中的 logits 行数增长：普通 decode 中大致每个请求一行，而 speculative verification 会为一个请求评分多个位置。</p>


- **在普通的非 spec-decode 路径中，`Sampler.__call__`（[`sampler.py:72-102`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L72-L102)）是 model runner 进入 sampler 的入口。** 它从 `input_batch.logits_indices` 得到 `pos` 和 `input_ids`，判断是否需要 logprobs，调用 `self.sample(...)`，再将结果封装进 `SamplerOutput`，其中的 `sampled_token_ids` 会 reshape 为 `[num_requests, 1]`（[`sampler.py:134-144`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L134-L144)）——这条分支为每个请求抽取一个 token。带 draft token 的请求会走上文所述的 rejection-sampler 分支。
- **`apply_sampling_params` 是 logits 处理流水线。** 执行顺序如下（[`sampler.py:146-196`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L146-L196)）：先把 logits 复制到一个全新的 fp32 tensor，再依次应用 logit bias / `allowed_token_ids` / `min_tokens`、penalties（presence、frequency、repetition）、bad-words masking、temperature 和 min-p。这里先不处理 top-k/top-p（`skip_top_k_top_p=True`），以便 `sample` 将它们交给 FlashInfer fused 路径或回退实现。每个操作符都在第 10 篇文章中各有一节；第 01 篇文章只说明它们的存在和顺序。
- **真正的抽取**（[`sampler.py:217-244`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L217-L244)）会在条件允许时选择 FlashInfer 的 fused top-k/top-p sampler，否则先应用 top-k/top-p，再调用 `gumbel_sample`，并返回 `(sampled, processed_logits)`。


### 完成闭环：token id 变为 `new_token_ids`

采样得到的 ID 不会以整数形式直接返回给调用方。它装在 `EngineCoreOutput` 中传递，再由 `update_from_output` 计入请求的生成进度。

源码：[`vllm/v1/engine/__init__.py:181-205`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L181-L205)（两个关键字段；[第 10 节](#10-输出处理enginecoreoutput-到-requestoutput)给出了完整结构体）：

```python
    request_id: str
    new_token_ids: list[int]
    ...
    @property
    def finished(self) -> bool:
        return self.finish_reason is not None
```


- **`new_token_ids: list[int]`，不是 `int`。** 从第一个字段起，整条路径就支持多 token。常见情况下，这个 list 只包含一个 ID；使用 speculative decoding 或其他多 token 方案时，它会包含一个 step 中为某个请求接受的多个 ID。下游的 detokenizer、stop-string 检查和 `RequestOutput` 都不需要在这个边界上为 spec decode 编写特殊分支，因为这个类型已经涵盖了这种情况。
- **`finished` 是派生属性，而不是单独存储的标志位。** 当且仅当 `finish_reason` 已设置时，它才是 `True`。engine core 会在因长度上限或 EOS 结束时设置 `finish_reason`；由 stop-*string* 导致的结束则要稍后由输出处理器基于 detokenize 后的文本来判断（[第 10 节](#10-输出处理enginecoreoutput-到-requestoutput)）——因此在某个 step 中，`EngineCoreOutput.finished` 与调用方看到的完成状态不同完全合理。
- **`num_nans_in_logits`** 是检测数据异常的哨兵：sampler 会在施加 penalties 和 temperature *之前*计算它（[`sampler.py:84-86`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L84-L86)），因此非零值指向的是模型自身的输出，而不是采样过程。

采样得到的 token 会作为 engine output 中的数据离开 worker，而不是直接返回给公开调用方。在 `EngineCoreOutputs` 通过 client 传递之前，`update_from_output` 会先将它与请求状态合并。对于某个请求，第一个非空的 `new_token_ids` 标志着输出处理可以将其变成首个可见 token。

交叉引用：这里提到但未展开的 logits 处理操作符——logit bias、penalties、bad words、temperature、min-p、top-k/top-p 以及 logprob 组装——正是**第 10 篇文章**（采样与 Logits 处理）的完整主题。`rejection_sampler` 分支和多 token 的 `new_token_ids` 属于**第 12 篇文章**（Speculative Decoding）。`logits_indices` gather 以及它所索引的扁平 batch 布局属于第 08/09 篇文章。下一节将追踪 `new_token_ids` 如何离开 GPU 并变成文本。

## 10. 输出处理：EngineCoreOutput 到 RequestOutput

之前的每一节都在把请求*向前*推进：门面层对它做规范化，输入处理器将其转换成传输格式，client 抽象将它送过进程边界，engine step 对其进行调度和采样。只有这一节反向而行。采样得到的 token ID 以 `EngineCoreOutputs` 的形式离开 `EngineCore.step()`——这是一个按 client 分组、包含逐请求 `EngineCoreOutput` 的集合——并且必须变成面向用户的 `RequestOutput`，其中包含 decode 后的文本、结束原因和 logprobs。完成这层转换的是 `OutputProcessor`，而且它被有意放在 engine 热循环之外。[第 6 节](#6-engine-step调度执行和处理输出)已经从调用方一侧展示了这个交接处：`LLMEngine.step()` 调用 `get_output()`，接着调用 `output_processor.process_outputs(...)`，再把返回的 `reqs_to_abort` 送回 engine。本节将展开中间这个调用，并说明它所维护的契约。

<a href='images/vllm-01-08-output-path.svg' target='_blank'><img src='images/vllm-01-08-output-path.svg' alt='vllm-01-08-output-path'></a>

<p class='figure-caption'>返回路径：一批 `EngineCoreOutput` → 唯一的 `process_outputs` 循环 → 逐请求 detokenize / stop 检查 / 构造结果 → 异步 queue 或同步 list。</p>

### 输入结构体：engine 实际发回什么

这个边界传递的是 token ID 和可选元数据，而不是文本。

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

`new_token_ids` 是一个 **list**，而不是标量——一个 step 可以为每个请求提交多个 token（speculative decoding、多 token 预测），因此返回路径必须能一次归并 *N* 个 token，不能假定只有一个。它后面的所有字段都是可选的（`omit_defaults=True`），而 `finished` 是一个*派生*属性：只有当 engine 填入 `finish_reason`（达到长度上限、EOS、stop token）时，请求才算完成。值得注意的是，这里**没有文本字段**——V1 把 detokenization 移出了 engine 进程，使其能与 GPU 工作重叠执行（[V1 博客](https://vllm.ai/blog/2025-01-27-v1-alpha-release)）。engine 发送 ID；文本由输出处理器负责。


### 唯一允许处理整个 batch 的循环

V1 将 Python 层逐 batch 的输出工作统一放在 `process_outputs` 中；它的 docstring 明确指出，应当由这个函数遍历 `EngineCoreOutputs`。

源码：[`vllm/v1/engine/output_processor.py:594-601`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L594-L601)

```python
        NOTE FOR DEVELOPERS

        vLLM V1 minimizes the number of python loops over the full
        batch to ensure system overheads are minimized. This is the
        only function that should loop over EngineCoreOutputs.

        If you need to touch every element of the batch, do it from
        within the loop below.
```

循环首先查找每个请求的状态，并丢弃它无法识别的输出。

源码：[`vllm/v1/engine/output_processor.py:606-611`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L606-L611)

```python
        for engine_core_output in engine_core_outputs:
            req_id = engine_core_output.request_id
            req_state = self.request_states.get(req_id)
            if req_state is None:
                # Ignore output for already-aborted request.
                continue
```

`req_state` 是长期存在的逐请求累积器（`RequestState`），其中保存了该请求的 detokenizer、logprobs processor、prompt 数据和 streaming 进度记录。它不存在**并不表示出错**——一个刚刚中止的请求（原因可能是 client 断开连接、已取消的 `generate()`，或此前匹配了 stop string）已经从 `request_states` 中移除，而 engine 可能仍在执行途中，正在为它产出最后一个输出。静默执行 `continue`，可以在不加锁的情况下安全处理请求中止与输出处理之间的竞态：两边最终会收敛到一致状态，因为条目缺失被定义为“丢弃”，而不是“崩溃”。

如果 `request_states` 中已不再包含某个请求，输出处理器就会丢弃该请求迟到的输出。这样，中止操作便可以与一个已经在执行中的 step 发生竞态，而不会重新创建前端状态。

### Detokenize，并将 engine 看不到的 stop string 提升为结束条件

对于非 pooling 请求，新 ID 会送入增量 detokenizer，由它追加文本并检查 stop string。匹配到 stop string 后，本地状态会被标记为完成。

源码：[`vllm/v1/engine/output_processor.py:635-644`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L635-L644)

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

detokenizer 的 `update` 是 token ID 转换成字符的地方。关键在于，设计上允许 *token* 流和 *text* 流彼此不一致。

源码：[`vllm/v1/engine/detokenizer.py:107-142`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/detokenizer.py#L107-L142)（摘录；完整的增量 decode 循环见第 10 篇文章）：

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

当 engine 因 stop *token* 而停止，并且用户没有要求保留它时，会先从待 decode 的集合中取出最后一个 ID（`skipped_stop_token_id`），使它不产生任何字符，随后再将其追加回 `token_ids`——token list 仍然完整，但文本中不包含终止符。上面省略的增量循环会逐个 decode 新 ID，并推进 `stop_check_offset`（一个受 `min_tokens` 控制的高水位标记），使 stop-string 搜索只覆盖*新增的*字符——因此每个 step 的匹配复杂度是 O(新增字符数)，而不是 O(完整输出长度)；完整循环见第 10 篇文章。`num_output_tokens() > self.min_tokens` 这个条件控制整个 stop 处理块是否执行，因此**在达到 `min_tokens` 之前，任何 stop string 都不可能触发**。匹配后，`check_stop_strings` 可能返回一个截断长度，供 `output_text` 截断并移除 stop string（`truncate_to == -1` 时除外；这表示它正好位于最末尾，无需截断）。

回到循环中：如果 `update` 返回 stop string，处理器会**把 `finish_reason` 覆盖为 `STOP`，并把 `stop_reason` 设为匹配到的字符串**。这就是输入结构预留的分歧：`engine_core_output.finished` 可能仍然是 `False`（engine 仍在继续生成），但处理器已经在本地判定请求完成。[第 6 节](#6-engine-step调度执行和处理输出)展示了闭环的另一半——循环会把这类 `req_id` 追加到 `reqs_to_abort`，而 `LLMEngine.step()` / 异步的 `output_handler` 会将它们送回，使*下一次* `EngineCore.step()` 在中止窗口停止该请求。

**不变量。** 即使 `output_text` 省略了 stop token 或 stop string，`token_ids` 仍会保留完整的采样序列。文本侧的 stop 处理遵循 `min_tokens`；当它结束一个 EngineCore 仍认为存活的请求时，会通过 `reqs_to_abort` 返回该请求。

### 决定本 step 是否需要对外输出

并不是每个 `EngineCoreOutput` 都会变成 `RequestOutput`。`make_request_output` 会应用 output kind 的门控条件，并在没有内容需要输出时返回 `None`。

源码：[`vllm/v1/engine/output_processor.py:280-331`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L280-L331)

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

`output_kind` 来自 `SamplingParams.output_kind`，用于选择对外输出约定：**`FINAL_ONLY`**（离线默认值——[第 2 节](#2-llmgenerate离线便捷层)已经展示了 `_add_request` 会强制使用它）只在完成时输出一次，因此所有非最终 step 都返回 `None`；**`DELTA`**（OpenAI streaming）只输出新生成的片段；**`CUMULATIVE`** 则会重新发送不断增长的完整内容。`stream_interval > 1` 还会进一步合并输出：只在完成时、第一个 token 产生时，或每生成 `stream_interval` 个 token 时输出——在 DELTA 模式下，它还会把 `new_token_ids` 重新切片为 `output_token_ids[sent_tokens_offset:]`，并推进 `sent_tokens_offset`，因此在没有输出的 step 中暂缓的 token 会一起投递，而不是被丢弃。最后，parallel sampling（`n>1`）会走 `parent_req.get_outputs`：子输出会被聚合，空列表表示“还不到对外输出的时候”→ `None`，对外输出的 ID 也会切换为**父级的**外部 ID（[第 5 节](#5-add_request请求进入-enginecore)中的 fan-out 在这里闭环）。


### 外层封装：始终使用外部 ID

最后一层封装会把面向用户的身份标识写入结果。

源码：[`vllm/v1/engine/output_processor.py:363-373`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L363-L373)

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

回顾[第 3 节](#3-输入处理prompt-如何变成-enginecorerequest)：`assign_request_id` 会在内部 ID 后追加 8 个随机字符，以显著降低碰撞概率，同时把调用方的 ID 保存在 `external_req_id` 中。这里，在结果到达用户前的最后一跳，`request_id` 会被设为 `external_req_id`——绝不会使用随机化后的内部 ID，也绝不会使用 parallel sampling 的子 ID。在 DELTA 模式下，prompt logprobs 会被*弹出*（只对外输出一次），其他模式下则按引用传递；这部分组装逻辑属于第 10 篇文章的内容。

**不变量。** 面向用户的 `RequestOutput.request_id` 使用调用方提供的外部 ID，而不是随机化后的内部 ID 或 parallel sampling 的子 ID。

### 同步返回或异步投递

完成 detokenization 和 stop 处理后，输出处理器要么把一个 `RequestOutput` 追加到同步返回列表，要么将它推入 request 的异步 mailbox。两种模式共用同一个输出处理循环，区别只在投递方式。第 11 篇会继续讲 mailbox，而第 04 和第 10 篇文章会介绍 request 清理、detokenization 和 logprobs。

源码：[`vllm/v1/engine/output_processor.py:650-681`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L650-L681)

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

`req_state.queue` 在 `AsyncLLM` request 中会被设置，在值为 `None` 时则对应同步 `LLMEngine` 路径。因此，这个分支只会改变投递方式，不会重复执行 detokenization、stop 检查或 `RequestOutput` 的构造逻辑。清理逻辑也走同一个分支：如果输出处理在 EngineCore 把 request 标记为完成之前发现了 stop string，内部 request ID 会通过 `reqs_to_abort` 返回，以便 engine 侧的状态也能随之清理。

## 11. Streaming、异步生成器，以及为什么第一个 token 很特殊

离线路径最终进入一个阻塞式 `while has_unfinished_requests(): step()` 循环，收集已完成的输出并排序（[`offline_utils.py:594-599`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L599)）。在线服务则需要增量投递，同时不能让 engine 的推进受某个 HTTP 消费者牵制。V1 保持 engine step 不变，只改变返回路径：每个 step 的 batch 会 fan-out 到各个 request 的 mailbox，再由异步生成器取走。

在线返回路径由**两层叠在一起、通过 asyncio 解耦的生产者/消费者边界**组成。边界 A：一个后台任务持有 ZMQ 输出 socket，把每一帧解码成一个 `EngineCoreOutputs` batch（每个 engine step 一个，只携带该 step 产生输出的 request，不一定包含所有 in-flight request），再将它推入 `AsyncMPClient.outputs_queue`；后者是一个 `asyncio.Queue`（[`core_client.py:973`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core_client.py#L973)，`1005-1062`）。边界 B：一个 `output_handler` 任务负责一个 `AsyncLLM`，它会 await 这个 queue，运行 `OutputProcessor.process_outputs`，并将每个 request 的结果分发到各自的 mailbox。边界 A 背后的 socket 拓扑属于第 03 篇文章的内容；这里我们关注的是哪些内容穿过边界 B 并到达调用方。

<a href='images/vllm-01-09-prefill-decode-timeline.svg' target='_blank'><img src='images/vllm-01-09-prefill-decode-timeline.svg' alt='vllm-01-09-prefill-decode-timeline'></a>

<p class='figure-caption'>一个 request 的时间线——准入、可能分块执行的 prefill、第一个采样出的 token（TTFT），然后是逐 step 的 decode。某个 step 是否产出一个可见的 RequestOutput，取决于 output-kind gate 和 stream_interval。</p>

### `generate()` 是纯消费者

对外的在线 API `AsyncLLM.generate` 是一个异步生成器。关键在于，它**并不**驱动 engine——只消费自己的 mailbox。

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

<p class='figure-caption'>在线返回路径包含两层由 asyncio 解耦的边界：边界 A（后台任务把 ZMQ 帧解码为 `EngineCoreOutputs` 并推入 `outputs_queue`）；边界 B（一个 `output_handler` 运行 `process_outputs`，把每个结果分发到按 request 划分的单槽、可合并 `RequestOutputCollector` 中），`generate()` 再通过 `q.get_nowait() or await q.get()` 从中取出数据——每个 request 最多只有一个待消费的输出；合并会保留逻辑输出内容，即使它合并了中间输出的事件边界。</p>


1. `q` 是每个 request 独有的 `RequestOutputCollector`，由 `add_request` 返回（[`async_llm.py:559`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L559)）；后者还会在同一条 await 链中把 request 注册到 `OutputProcessor`，并提交给 EngineCore（[第 5 节](#5-add_request请求进入-enginecore)）。这个循环开始运行时，mailbox 已经接入 fan-out 路径。
2. `out = q.get_nowait() or await q.get()`（L579）会先尝试非阻塞获取；只有 mailbox 为空时才需要执行 `await`。注释（L577-578）说明了用意：高负载时，跳过事件循环的任务切换很重要，因为在高并发下，通常已经有 token 在等待。
3. 终止条件附在数据上：`finished = out.finished`（L584）。生产者把 `finished=True` 标在最后一个 `RequestOutput` 上；消费者 yield 它之后便停止。`generate()` 完全不需要感知 scheduler 或 EngineCore 的生命周期，就能知道何时停止。
4. `STREAM_FINISHED`（一个 `finished=True`、`outputs` 为空的哨兵 `RequestOutput`，见 [`outputs.py:191-199`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/outputs.py#L191-L199)）会被过滤掉（L585）——它会在 streaming 输入完成时解除循环的阻塞，但不会产生虚假的空 chunk。


### 每个 request 的 mailbox 都是单槽、可合并的缓冲区

从共享的 `output_handler`（生产者）到每个 request 的 `generate()`（消费者），这段交接刻意*没有*使用无界 queue。它由一个单槽 mailbox 和一个 `asyncio.Event` 组成；如果生产速度超过消费速度，连续的输出就会**原地合并**。

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


1. `put()` 由生产者同步调用。如果槽位为空（或者传入项是 `Exception`），就把它放入槽位并调用 `self.ready.set()`——异常总会立即占据槽位，也绝不会被合并掉，因此 engine 一旦失效，等待方会立即得知。
2. 如果槽位中已经有一个 `RequestOutput`，新输出就会通过 `self.output.add(output, aggregate=self.aggregate)`（L72）合并进去，而不是覆盖旧值。`aggregate` 被设为 `True`，且仅限于 `DELTA` 模式（`self.aggregate = output_kind == RequestOutputKind.DELTA`，L55）。这项合并（[`outputs.py:145-173`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/outputs.py#L145-L173)）会在 DELTA streaming 下拼接文本、token ID 和 logprobs，在 cumulative streaming 下替换整个快照，并对 `finished` 按 OR 聚合，因此即使合并后的 batch 吞并了终止 chunk，generate 循环仍会停止。
3. `get()` 会 await `self.ready`，直到槽位不再是 `None`，随后同时清空槽位并清除 event。

每个 request 的 mailbox 最多只保存一个待消费的 `RequestOutput` 对象。在 DELTA 模式下，合并会拼接 token 增量和文本增量；在 cumulative 模式下，较新的快照会替换较旧的快照。这样既限制了 mailbox 中的对象数量，又不会丢弃合并值所代表的逻辑输出。

### 一个循环，一个标志位：同步与异步在何处分叉

同步和异步路径都复用 `process_outputs` 这段 batch 热循环；源码称它为“唯一应该遍历 EngineCoreOutputs 的函数”（[`output_processor.py:594-601`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L594-L601)）。[第 10 节](#10-输出处理enginecoreoutput-到-requestoutput)已经讲过其中让同步与异步分叉的唯一分支：`if req_state.queue is not None:` 会把组装好的 `RequestOutput` 推入每个 request 的 mailbox（异步），而不是追加到返回列表（同步）（[`output_processor.py:650-666`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L650-L666)）。异步 engine 在准入时注册这个 `queue`（[第 5 节](#5-add_request请求进入-enginecore)）；同步 engine 则传入 `queue=None`。

真正要由[第 11 节](#11-streaming异步生成器以及为什么第一个-token-很特殊)讲清楚的，是这处分叉对 streaming 的影响。由于 queue 存在，可以确定异步分发*只会 push*——这也解释了为什么 `output_handler` 可以执行 `assert not processed_outputs.request_outputs`（[`async_llm.py:679`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L679)）：只要 queue 已接入，返回列表就绝不会被触碰。因此，streaming *不会再为 batch 增加第二个循环*——它会复用离线路径已有的循环，只替换最后一条语句。detokenization、stop string 检查和 logprob 组装是 `make_request_output` 所依赖的逻辑，属于第 10 篇文章的内容；第 04 篇文章则详细介绍已完成 request 的记录维护和 `reqs_to_abort` 路径。

### 为什么第一个 token 很特殊

prefill 和 decode 是两种不同的 forward pass。根据“Inside vLLM”的讲解（[Inside vLLM](https://vllm.ai/blog/2025-09-05-anatomy-of-vllm)）：**prefill** 是“对所有 prompt token 执行一次 forward pass”，通常是 compute-bound；**decode** 是“只对最新的 token 执行一次 forward pass”，是 memory-bandwidth-bound。V1 不会把它们作为两个独立阶段运行——它统一处理所有 token，一次调度决策在概念上就是 `{request_id: num_tokens}`（[V1 blog](https://vllm.ai/blog/2025-01-27-v1-alpha-release)），因此长 prompt 可以拆到多个 step 中执行（chunked prefill，见第 05 篇文章）。这对 streaming 的影响是：一个 request 可能占用 GPU 一个或多个 step，却*不*产生任何采样出的 token，因为只有 prefill 的最后一个位置才会产出可供采样的 logits。因此，`EngineCoreOutput` 第一次携带真正的 `new_token_ids` 时，便构成一个独立事件，输出处理器会对此做标记。

[`vllm/v1/engine/output_processor.py:628-633`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L628-L633)：

```python
            if req_state.is_prefilling:
                if engine_core_output.prefill_stats is not None:
                    req_state.num_cached_tokens = (
                        engine_core_output.prefill_stats.num_cached_tokens
                    )
                req_state.is_prefilling = False
```

`is_prefilling` 的初始值是 `True`，这个值在构造 `RequestState` 时设定（[`output_processor.py:172`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L172)）；streaming 输入更新可以再次把它设为 `True`（[`output_processor.py:191-208`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L191-L208)）。第一次输出会记录 `num_cached_tokens`，并把该标志改为 `False`。如果之后没有 streaming 输入触发新的 prefill，后续输出就是 decode 更新。TTFT 包括 scheduler 等待、所有 chunked-prefill step、采样、增量 detokenize，以及返回路径上的扇出；token 间延迟衡量的是后续各轮 decode。

跨进程边界的完整首 token 链路如下：`EngineCore.step()` 在 `update_from_output` 中提交采样得到的 token，并为每个 client 返回一个 `dict[int, EngineCoreOutputs]`（[`core.py:504-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L508)）；边界 A 将该 batch 放入 queue；`output_handler` 运行 `process_outputs`，后者会翻转 `is_prefilling`（见上文），并把第一个 `RequestOutput` 推入 mailbox；`generate()` 将它产出（[`async_llm.py:585-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L585-L586)）。没有一个调用栈能贯穿整条链路——这是异步 client、共享 handler、每个请求的 mailbox 和消费任务之间的一次接力。

### 取消操作完成闭环

由于 `generate()` 由随时可能断开的 HTTP client 消费，取消操作必须在*两侧*拆除请求，否则 engine 会继续 decode 一个已经失效的请求。[`async_llm.py:591-596`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L591-L596) 会捕获 `CancelledError`/`GeneratorExit`，调用 `self.abort(q.request_id, internal=True)`（它会同时在 OutputProcessor 和 EngineCore 中中止请求），然后重新抛出异常；`finally` 位于 [`async_llm.py:633-635`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L633-L635)，会调用 `q.close()` 取消所有 streaming 输入供给任务。阻塞式离线 API 没有与此对应的逐 client 断连路径：`generate()` 是阻塞调用，而不是调用方可以中途放弃的 iterator，因此离线场景下的取消走的是另一条控制流。

streaming 路径复用同一套 engine 执行逻辑，只是使用异步返回通道。离线 `LLMEngine.step` 通过 `queue=None` 处理输出并返回列表（[`llm_engine.py:296-334`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L296-L334)）；异步路径则把输出推入请求各自的 mailbox。scheduler、worker 和 sampler 都不受这种交付方式选择的影响。第 02 篇介绍 OpenAI server，第 03 篇介绍 ZMQ client，第 04 篇介绍输出处理和请求拆除。

## 12. 完整端到端追踪

到目前为止，我们已经沿请求路径完整走过了一遍所有边界。本节最后会做两件事：先把这些边界重新串成一条逻辑主线——从 `LLM.generate()` 一直到交到调用方手中的 `RequestOutput`，形成一条不中断的链路——再提炼出几条值得带入后续深入章节的原则。这里没有引入任何新机制；下面的每个定位点都已在前文中说明。把它们作为一条完整链路来读，价值在于能看清其中的*交接处*：你可以准确看到请求在何处更换负责方、改变表示形式和切换进程，也可以明确每个交接处提供了什么契约保障。

<a href='images/vllm-01-10-full-trace.svg' target='_blank'><img src='images/vllm-01-10-full-trace.svg' alt='vllm-01-10-full-trace'></a>

<p class='figure-caption'>完整请求路径：`generate()` → 输入处理器 → `EngineCoreRequest` → client → `EngineCore.step`（调度 → 执行 → 采样 → 提交）→ 输出处理器 → `RequestOutput`，并标注每一跳对应的负责方和契约。</p>

### 逐跳追踪

来看一个 prompt 的完整过程。行号锚点指向每一跳实际执行的代码。

1. **`LLM.generate()` 校验并委派** — [`vllm/entrypoints/llm.py:465-485`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/llm.py#L465-L485)。runner 类型检查会拒绝非生成式模型；系统会为 `sampling_params` 补上默认值，确保它传到下游时绝不会是 `None`；随后控制流交给 `_run_completion`。这里不做调度，也不分配资源。*(第 02 篇。)*

2. **离线 mixin 为请求编号并接纳它** — [`vllm/entrypoints/offline_utils.py:559-563`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L559-L563)。`output_kind` 被强制设为 `FINAL_ONLY`，并根据一个 `Counter()` 生成单调递增的十进制 `request_id`。随后，`LLMEngine.add_request`（[`vllm/v1/engine/llm_engine.py:218-294`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L218-L294)）会在*两侧*登记这项工作——输出处理器一侧负责 detokenize 和聚合，engine core 一侧负责调度；当 `n > 1` 时，它还会把一个逻辑请求拆成 `n` 个子请求，并归到一个 `ParentRequest` 名下。*(门面层见第 02 篇，双侧登记见第 04 篇。)*

3. **输入处理器把 prompt 转成传输结构体** — [`vllm/v1/engine/input_processor.py:242-255`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/input_processor.py#L242-L255)。`process_inputs(request_id, prompt, params, ...) -> EngineCoreRequest` 会完成一系列校验，复制 sampling 参数并补齐最终值（使 `max_tokens` 得到确定值），并展平所有多模态输入；它通常接收上游 Renderer 已渲染好的 `EngineInput`，处理 raw prompt 的 tokenize 只在一条 deprecated 兼容路径上保留。它的输出是一个 `EngineCoreRequest`——一种紧凑的 `msgspec` 结构体，专为通过 socket 传输而设计。*(第 03 篇。)*

4. **client 抽象将其送过进程边界** — [`vllm/v1/engine/llm_engine.py:104-111`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/llm_engine.py#L104-L111)。`LLMEngine` 持有一个多态的 `EngineCoreClient`。在默认的 multiprocess 模式下，请求序列化后会带上一个单字节类型标签（[`vllm/v1/engine/__init__.py:251-264`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/__init__.py#L251-L264)：`ADD = b"\x00"`），再通过 ZMQ ROUTER 发送给运行忙循环的 `EngineCore` 进程；使用 in-process client 时，则是直接调用方法。无论哪种方式，对外提供的 `add_request`/`get_output` 接口都相同。*(ZMQ 拓扑见第 03 篇，DP 路由见第 11 篇。)*

5. **`EngineCore.step()` 执行整个事务** — [`vllm/v1/engine/core.py:479-508`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L479-L508)。先调度，再以非阻塞方式启动 forward pass；GPU 运行时，在 CPU 上构建语法位掩码；随后同步、处理待中止项，再提交结果。这是整个系统反复执行的核心循环，step 6–9 全都发生在它的*内部*。末尾的 hook `post_step`（[`core.py:510-517`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L510-L517)）会把推测式 draft token 回送给 scheduler，供下一个 step 使用。*(第 04 篇。)*

6. **scheduler 规划 token，而不是张量** — [`core.py:490`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L490) 处对 `scheduler.schedule(...)` 的一次调用会回答“哪些请求运行，以及每个请求推进多少个 token”，并统一用计数模型 `{request_id: num_tokens}` 表示。它返回一个 `SchedulerOutput` 计划，不会操作 GPU。*(第 05 篇；KV 分配见第 06 篇，prefix 复用见第 07 篇，draft token 见第 12 篇。)*

7. **executor 将计划分发到 GPU** — [`vllm/v1/executor/abstract.py:210-227`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/executor/abstract.py#L210-L227)。`execute_model` 是一个 `collective_rpc`，它指明的是一项*操作*，而不是一个设备，因此一个或 N 个 worker 都会运行同一个调用，最终采用其中一个指定 worker 的结果（最后一个 PP stage 的第一个 TP rank；[第 8 节](#8-模型执行从-executor-到-logits概览)）。在每个 worker 上，model runner 会更新并对齐自己维护的持久 batch，运行展平后的 forward pass，并在关键衔接点（[`vllm/v1/worker/gpu/model_runner.py:1054-1055`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/model_runner.py#L1054-L1055)）选取最后位置的隐藏状态，再将其投影为 logits。*(第 08–09 篇介绍 kernel/CUDA graph，第 11 篇介绍并行机制。)*

8. **sampler 抽取 token ID** — 这一步可能内联执行；如果 worker 将其延后，则会通过第二次 `collective_rpc` 调用，即 [`core.py:497-499`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L497-L499) 处的 `sample_tokens(grammar_output)`，最终到达 `Sampler.sample`（[`vllm/v1/worker/gpu/sample/sampler.py:198-210`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/worker/gpu/sample/sampler.py#L198-L210)）。采样前，语法位掩码会原地应用到*这些* logits 上。*(第 10 篇；推测式 decode 的拒绝采样见第 12 篇。)*

9. **提交阶段把 token 纳入请求进度** — [`core.py:504-506`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/core.py#L504-L506) 处的 `scheduler.update_from_output(...)` 会追加采样得到的 ID、设置结束原因，并开始释放已完成请求的 KV block——安全时立即释放，否则延迟到 in-flight GPU step 之后。它的结果是一个 `dict[client_index -> EngineCoreOutputs]`——其中包含 token ID 和结束标志，*不是*面向用户的文本。*(第 04 篇。)*

10. **输出处理器把 ID 转回文本** — [`vllm/v1/engine/output_processor.py:576-693`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L576-L693)，这是唯一允许遍历整个 batch 的函数。它会增量 detokenize，检测到停止*字符串*后将请求标记为完成；如果核心端尚未同时停止该请求，还会把该 ID 追加到 `reqs_to_abort`；最后构造出一个 `RequestOutput`。*(第 04 和第 10 篇。)*

11. **结果通过两条路径返回。** 离线：排空循环收集已完成的输出，并在最后通过排序恢复输入顺序（[`offline_utils.py:594-626`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/entrypoints/offline_utils.py#L594-L626)）。在线：`process_outputs` 将每个 `RequestOutput` 推入请求各自的 mailbox，再由 `generate()` async generator 将其产出（[`vllm/v1/engine/async_llm.py:576-586`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/async_llm.py#L576-L586)）。二者处理的都是*同一种* `process_outputs` 输出，只通过一个 `if req_state.queue is not None:` fork 分流。*(离线路径见第 02 篇，在线 streaming 见第 03/11 篇。)*

在最后一个边界上，结果会恢复调用方传入的外部请求 ID。

[`vllm/v1/engine/output_processor.py:363-364`](https://github.com/vllm-project/vllm/blob/6cf7b26bd4bff60bf378e1af14044280ac0d214c/vllm/v1/engine/output_processor.py#L363-L364)：

```python
        return RequestOutput(
            request_id=external_req_id,  # request_id is what was provided externally
```

内部请求 ID 可能带上随机后缀，并行采样也可能生成子 ID。结果离开输出处理流程前，`RequestOutput` 会切回 `external_req_id`。

### 要点

- `LLM.generate()` 是同步 API，但不一定是 in-process engine。启用 V1 multiprocessing 时——这是本文基准版本的默认设置——它会使用 `SyncMPClient` 和一个后台 EngineCore 进程。
- 随着负责方切换，请求的表示形式也随之变化：对外输入 → `EngineCoreRequest` → scheduler 的 `Request` → batch 化的张量 → 采样得到的 ID → `RequestOutput`。
- `EngineCore.step()` 是整个系统反复运行的中心。它负责调度工作、启动执行、处理 sampling 衔接、处理中止请求并提交输出。
- scheduler 分配 token 工作量，并负责请求和 cache 的生命周期；model runner 负责张量准备和执行；输出处理器负责 detokenize 和面向 API 的结果。
- 离线调用方和 async 调用方共用同一套输出处理逻辑。区别只在交付方式：前者阻塞排空并返回最终输出，后者为每个请求使用独立的 async mailbox。

## 13. 参考资料

- https://vllm.ai/blog/2023-06-20-vllm
- https://arxiv.org/abs/2309.06180
- https://docs.vllm.ai/en/stable/design/arch_overview/
- https://vllm.ai/blog/2025-01-27-v1-alpha-release
- https://vllm.ai/blog/2025-09-05-anatomy-of-vllm
- https://docs.vllm.ai/en/stable/api/vllm/sampling_params.html

*所有关于代码的结论均以 [`vllm-project/vllm@6cf7b26bd`](https://github.com/vllm-project/vllm/tree/6cf7b26bd4bff60bf378e1af14044280ac0d214c) 为依据。*
