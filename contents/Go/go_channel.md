![](https://img.halfrost.com/Blog/ArticleImage/149_0.png)

# 深入 Go 并发原语 — Channel 底层实现

作为 Go 并发原语的第一篇文章，一定绕不开 Go 的并发哲学。从 Tony Hoare 写的 Communicating Sequential Processes 这篇文章说起，这篇经典论文算是 Go 语言并发原语的根基。

## 一. What is CSP

CSP 的全程是 Communicating Sequential Processes，直译，通信顺序进程。这一概念起源自 1978 年 ACM 期刊中 Charles Antony Richard Hoare 写的经典同名论文。感兴趣的读者可以看 Reference 中的第一个链接看原文。在这篇文章中，Hoare 在文中用 CSP 来描述通信顺序进程能力，姑且认为这是一个虚构的编程语言。该语言描述了并发过程之间的交互作用。从历史上看，软件的进步主要依靠硬件的改进，这些改进可以使 CPU 更快，内存更大。Hoare 认识到，想通过硬件提高使得代码运行速度快 10 倍，需要付出 10 倍以上的机器资源。这并没有从根本改善问题。

### 1. 术语和一些例子

尽管并发相对于传统的顺序编程具有许多优势，但由于其会出错的性质，它未能获得广泛的欢迎。Hoare 借助 CSP 引入了一种精确的理论，可以在数学上保证程序摆脱并发的常见问题。Hoare 在他的 Learning CSP（这是计算机科学中引用第三多的神书！）一书中，使用“进程微积分”来表明可以处理死锁和不确定性，就像它们是普通进程中的最终事件一样。进程微积分是一种对并发系统进行数学化建模的方式，并且提供了代数法则来进行这些系统的变换来分析它们的不同属性，并发和效率。

为了防止数据被多线程破坏，Hoare 提出了临界区的概念。进程进入临界区后可以获得对共享数据的访问。在进入临界区之前，所有其他的进程必须验证和更新这一共享变量的值。退出临界区时，进程必须再次验证所有进程具有相同的值。

保持数据完整性的另一种技术是通过使用互斥信号量或互斥量。互斥锁是信号量的特定子类，它仅允许一个进程一次访问该变量。信号量是一个受限制的访问变量，它是防止并发中竞争的经典解决方案。其他尝试访问该互斥锁的进程将被阻止，并且必须等待直到当前进程释放该互斥锁。释放互斥锁后，只有一个等待的进程可以访问该变量，所有其他进程继续等待。

1970年代初期，Hoare 基于互斥量的概念开发了一种称为监视器的概念。根据 IBM 编写的 Java 编程语言 CSP 教程：

> “A monitor is a body of code whose access is guarded by a mutex. Any process wishing to execute this code must acquire the associated mutex at the top of the code block and release it at the bottom. Because only one thread can own a mutex at a given time, this effectively ensures that only the owing thread can execute a monitor block of code.”


monitor 可以帮助防止数据被破坏和线程死锁。在 CSP 论文中为了说明清楚进程之间的通信，Hoare 利用 ？和 ！号代表了输入和输出。！代表发送输入到一个进程，？号代表读取一个进程的输出。每个指令需要指定具体是一个输出变量(从一个进程中读取一个变量的情况)，还是目的地(将输入发送到一个进程的情况)。一个进程的输出应该直接流向另一个进程的输入。



![](https://img.halfrost.com/Blog/ArticleImage/149_3.png)

上图是从 CSP 文章中截图的一些例子，Hoare 简单的举了下面这个例子：

```go
[c:character; west?c ~ east!c] 
```

上述代码的意思是读取 west 输出的所有字符，然后把它们一个个的输出到 east 中。这个过程不断的重复，直到 west 终止。从描述上看，这一特性完完全全是 channel 的雏形。


### 2. 哲学家问题


文章的最后，回到了经典的哲学家问题。


![](https://img.halfrost.com/Blog/ArticleImage/149_2.jpeg)

在哲学家问题中，Hoare 将 philosopher 的行为描述如下：

```go
PHIL = *[... during ith lifetime ... --->,
THINK;
room!enter( );
fork(0!pickup( ); fork((/+ 1) rood 5)!pickup( );
EAT;
fork(i)!putdown( ); fork((/+ 1) mod 5)!putdown( );
room!exit( )
]
```

每个叉子由坐在两边的哲学家使用或者放下：

```go
FORK =
*[phil(0?pickup( )--* phil(0?putdown( )
0phil((i - 1)rood 5)?pickup( ) --* phil((/- l) raod 5)?putdown( )
]
```

整个哲学家在房间中的行为可以描述为：

```go
ROOM = occupancy:integer; occupancy .--- 0;
,[(i:0..4)phil(0?enter ( ) --* occupancy .--- occupancy + l
11(i:0..4)phil(0?exit ( ) --~ occupancy .--- occupancy - l
] 
```


决定如何向等待的进程分配资源的任务称为调度。Hoare 将调度分为两个事件：

- processes 请求资源
- 将资源分配给 processes

那么这个哲学家问题可以转换成 PHIL 和 FORK 这两个组件并发的过程：

```go
[room::ROOM I [fork( i:0..4)::FORK I Iphil( i:0..4)::PHIL]. 
```

从请求到授予资源的时间就是等待时间。在 CSP 中，有几种技术可以防止无限的等待时间。

- 限制资源使用并提高资源可用性。
- 先进先出(FIFO)将资源分配给等待时间最长的进程。
- 面包店算法[Carnegie Melon. Bakery Algorithm](https://www.cs.cmu.edu/~410-s14/lectures/L08b_Synch.pdf)


### 3. 缺陷

在确定性程序中，如果环境恒定，结果将是相同的。 由于并发基于非确定性，因此环境不会影响程序。给定所选的路径，程序则可以运行几次并收到不同的结果。为了确保并发程序的准确性，程序员必须能够在整体水平上考虑其程序的执行。

但是，尽管 Hoare 引入了正式的方法，但仍然缺少任何验证正确程序的证明方法。CSP 只能发现已知问题，而不能发现未知问题。虽然基于 CSP 的商业应用程序（例如ConAn）可以检测到错误的存在，但无法检测到错误的存在。尽管 CSP 为我们提供了编写可以避免常见并发错误的程序的工具，但是正确程序的证明仍然是 CSP 中尚未解决的领域。


### 4. 未来

CSP 在生物学和化学领域具有巨大的潜力，可以对自然界中的复杂系统进行建模。 由于该行业面临许多现存的逻辑问题，因此尚未在行业中广泛使用。在关于 CSP 开发 25 周年的会议上，Hoare 指出，尽管有许多由 Microsoft 资助的研究项目，但比尔·盖茨（Bill Gates）忽略了 Microsoft 何时能够将 CSP 的研究成果商业化的[问题](https://sites.google.com/site/jpbowen/)。

Hoare 提醒他的听众，动态过程领域仍然需要更多的研究。当前，计算机科学界陷入了顺序思维的范式。随着 Hoare 建立正式的并发方法的基础，科学界已做好准备成为并行编程的下一个革命。


### 5. Go 并发哲学


在 Go 语言发布之前，很少有语言从底层为并发原语提供支持。大多数语言还是支持共享和内存访问同步到 CSP 的消息传递方法。Go 语言算是最早将 CSP 原则纳入其核心的语言之一。内存访问同步的方式并不是不好，只是在高并发的场景下有时候难以正确的使用，特别是在超大型，巨型的程序中。基于此，并发能力被认为是 Go 语言天生优势之一。追其根本，还是因为 Go 基于 CSP 创造出来的一系列易读，方便编写的并发原语。

Go 语言除了 CSP 并发原语以外，还支持通过内存访问同步。sync 与其他包中的结构体与方法可以让开发者创建 WaitGroup，互斥锁和读写锁，cond，once，sync.Pool。在 Go 语言的官方 FAQ 中，描述了如何选择这些并发原语：

> 为了尊重 mutex，sync 包实现了 mutex，但是我们希望 Go 语言的编程风格将会激励人们尝试更高等级的技巧。尤其是考虑构建你的程序，以便一次只有一个 goroutine 负责某个特定的数据。
> 

**不要通过共享内存进行通信。建议，通过通信来共享内存。**这是 Go 语言并发的哲学座右铭。相对于使用 sync.Mutex 这样的并发原语。虽然大多数锁的问题可以通过 channel 或者传统的锁两种方式之一解决，但是 Go 语言核心团队更加推荐使用 CSP 的方式。

![](https://img.halfrost.com/Blog/ArticleImage/149_4.png)


关于如何选择并发原语的问题，本文作为第一篇文章必然需要解释清楚。Go 中的并发原语主要分为 2 大类，一个是 sync 包里面的，另一个是 channel。sync 包里面主要是 WaitGroup，互斥锁和读写锁，cond，once，sync.Pool 这一类。在 2 种情况下推荐使用 sync 包：

- 对性能要求极高的临界区
- 保护某个结构内部状态和完整性

关于保护某个结构内部的状态和完整性。例如 Go 源码中如下代码：

```go
var sum struct {
	sync.Mutex
	i int
}

//export Add
func Add(x int) {
	defer func() {
		recover()
	}()
	sum.Lock()
	sum.i += x
	sum.Unlock()
	var p *int
	*p = 2
}
```

sum 这个结构体不想将内部的变量暴露在结构体之外，所以使用 sync.Mutex 来保护线程安全。

相对于 sync 包，channel 也有 2 种情况：

- 输出数据给其他使用方
- 组合多个逻辑

输出数据给其他使用方的目的是转移数据的使用权。并发安全的实质是保证同时只有一个并发上下文拥有数据的所有权。channel 可以很方便的将数据所有权转给其他使用方。另一个优势是组合型。如果使用 sync 里面的锁，想实现组合多个逻辑并且保证并发安全，是比较困难的。但是使用 channel + select 实现组合逻辑实在太方便了。以上就是 CSP 的基本概念和何时选择 channel 的时机。下一章从 channel 基本数据结构开始详细分析 channel 底层源码实现。


## 二. 基本数据结构

## 三. 创建 Channel


## 四. 发送数据

||Channel status|result|
|:-----:|:-----:|:-----:|:-----:|
| Write | nil|阻塞|
| Write |打开但填满|阻塞|
| Write | 打开但未满|成功写入值|
| Write | 关闭|**panic**|
| Write | 只读|Compile Error|


## 五. 接收数据


||Channel status|result|
|:-----:|:-----:|:-----:|:-----:|
| Read | nil|阻塞|
| Read | 打开且非空|读取到值|
| Read | 打开但为空|阻塞|
| Read | 关闭|<默认值>, false|
| Read | 只读|Compile Error|



## 六. 关闭 Channel


“Channel 有几种优雅的关闭方法？” 这种问题常常出现在面试题中，究其原因是因为 Channel 创建容易，但是关闭“不易”：

- 在不改变 Channel 自身状态的条件下，无法知道它是否已经关闭。“不易”之一，关闭时机未知。
- 如果一个 Channel 已经关闭，重复关闭 Channel 会导致 panic。“不易”之二，不能无脑关闭。
- 往一个 close 的 Channel 内写数据，也会导致 panic。“不易”之三，写数据之前也需要关注是否 close 的状态。

||Channel status|result|
|:-----:|:-----:|:-----:|:-----:|
|close| nil|**panic**|
|close|打开且非空|关闭 Channel；读取成功，直到 Channel 耗尽数据，然后读取产生值的默认值|
|close| 打开但为空|关闭 Channel；读到生产者的默认值|
|close| 关闭|**panic**|
|close| 只读|Compile Error|

那究竟什么时候关闭 Channel 呢？由上面三个“不易”，可以浓缩为 2 点：

- 不能简单的从消费者侧关闭 Channel。
- 如果有多个生产者，它们不能关闭 Channel。

解释一下这 2 个问题。第一个问题，消费者不知道 Channel 何时该关闭。如果关闭了已经关闭的 Channel 会导致 panic。而且分布式应用通常有多个消费者，每个消费者的行为一致，这么多消费者都尝试关闭 Channel 必然会导致 panic。第二个问题，如果有多个生产者往 Channel 内写入数据，这些生产者的行为逻辑也都一致，如果其中一个生产者关闭了 Channel，其他的生产者还在往里写，这个时候会 panic。所以为了防止 panic，必须解决上面这 2 个问题。

关闭 Channel 的方式就 2 种：  

- Context
- done channel

Context 的方式在本篇文章不详细展开，详细的可以查看笔者 Context 的那篇文章。本节聊聊 done channel 的做法。假设有多个生产者，有多个消费者。在生产者和消费者之间增加一个额外的辅助控制 channel，用来传递关闭信号。

```go
type session struct {
	done     chan struct{}
	doneOnce sync.Once
	data     chan int
}

func (sess *session) Serve() {
	go sess.loopRead()
	sess.loopWrite()
}

func (sess *session) loopRead() {
	defer func() {
		if err := recover(); err != nil {
			sess.doneOnce.Do(func() { close(sess.done) })
		}
	}()

	var err error
	for {
		select {
		case <-sess.done:
			return
		default:
		}

		if err == io.ErrUnexpectedEOF || err == io.EOF {
			goto failed
		}
	}
failed:
	sess.doneOnce.Do(func() { close(sess.done) })
}

func (sess *session) loopWrite() {
	defer func() {
		if err := recover(); err != nil {
			sess.doneOnce.Do(func() { close(sess.done) })
		}
	}()

	var err error
	for {
		select {
		case <-sess.done:
			return
		case sess.data <- rand.Intn(100):
		}
		
		if err != nil {
			goto done
		}
	}
done:
	if err != nil {
		log("sess: loop write failed: %v, %s", err, sess)
	}
}
```

消费者侧发送关闭 done channel，由于消费者有多个，如果每一个都关闭 done channel，会导致 panic。所以这里用 doneOnce.Do() 保证只会关闭 done channel 一次。这解决了第一个问题。生产者收到 done channel 的信号以后自动退出。多个生产者退出时间不同，但是最终肯定都会退出。当生产者全部退出以后，data channel 最终没有引用，会被 gc 回收。这也解决了第二个问题，生产者不会去关闭 data channel，防止出现 panic。

![](https://img.halfrost.com/Blog/ArticleImage/149_1.png)


总结一下 done channel 的做法：消费者利用辅助的 done channel 发送信号，并先开始退出协程。生产者接收到 done channel 的信号，也开始退出协程。最终 data channel 无人持有，被 gc 回收关闭。


---------------------------------
Reference：

[ACM Communicating sequential processes](https://dl.acm.org/doi/10.1145/359576.359585)  
[Stanford project about csp](https://cs.stanford.edu/people/eroberts/courses/soco/projects/2008-09/tony-hoare/csp.html)
