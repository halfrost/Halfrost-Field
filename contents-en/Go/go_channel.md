![](https://img.halfrost.com/Blog/ArticleImage/149_0.png)

# A Deep Dive into Go Concurrency Primitives — The Underlying Implementation of Channel

As the first article on Go concurrency primitives, we have to start with Go’s philosophy of concurrency. That begins with Tony Hoare’s paper, Communicating Sequential Processes, a classic paper that can be considered the foundation of Go’s concurrency primitives.

## I. What is CSP

CSP stands for Communicating Sequential Processes. The concept originated from the classic paper of the same name written by Charles Antony Richard Hoare in a 1978 issue of an ACM journal. Interested readers can find the original paper via the first link in the References. In that paper, Hoare used CSP to describe the capabilities of communicating sequential processes; for the purposes of the discussion, it can be regarded as an imaginary programming language. The language described interactions between concurrent processes. Historically, software progress has largely depended on hardware improvements, which made CPUs faster and memory larger. Hoare recognized that making code run 10 times faster through hardware improvements would require more than 10 times the machine resources. That did not fundamentally solve the problem.

### 1. Terminology and Some Examples

Although concurrency has many advantages over traditional sequential programming, it has not gained broad popularity because of its error-prone nature. With CSP, Hoare introduced a precise theory that can mathematically guarantee that programs avoid common concurrency problems. In his book Learning CSP (the third most cited canonical work in computer science!), Hoare used “process calculus” to show that deadlock and nondeterminism can be handled as if they were ordinary terminal events in processes. Process calculus is a way to mathematically model concurrent systems, and it provides algebraic laws for transforming these systems in order to analyze their various properties, concurrency, and efficiency.

To prevent data from being corrupted by multiple threads, Hoare proposed the concept of a critical section. After a process enters a critical section, it can gain access to shared data. Before entering the critical section, all other processes must verify and update the value of this shared variable. When exiting the critical section, the process must again verify that all processes have the same value.

Another technique for maintaining data integrity is to use a mutex semaphore or mutex. A mutex is a specific subclass of semaphore that allows only one process to access the variable at a time. A semaphore is a restricted-access variable and is the classic solution for preventing races in concurrency. Other processes attempting to access the mutex are blocked and must wait until the current process releases it. After the mutex is released, only one waiting process can access the variable, while all other processes continue waiting.

In the early 1970s, based on the concept of mutexes, Hoare developed a concept known as a monitor. According to IBM’s CSP tutorial for the Java programming language:

> “A monitor is a body of code whose access is guarded by a mutex. Any process wishing to execute this code must acquire the associated mutex at the top of the code block and release it at the bottom. Because only one thread can own a mutex at a given time, this effectively ensures that only the owing thread can execute a monitor block of code.”


A monitor can help prevent data corruption and thread deadlock. In the CSP paper, to clearly illustrate communication between processes, Hoare used the symbols ? and ! to represent input and output. ! represents sending input to a process, while ? represents reading the output of a process. Each instruction needs to specify exactly whether it is an output variable (reading a variable from a process) or a destination (sending input to a process). The output of one process should flow directly into the input of another process.


![](https://img.halfrost.com/Blog/ArticleImage/149_3.png)

The figure above shows several examples excerpted from the CSP paper. Hoare gave the following simple example:
```go
[c:character; west?c ~ east!c] 
```
The meaning of the code above is to read all characters output by west, and then output them one by one to east. This process repeats continuously until west terminates. Judging from the description, this feature is, in every respect, the prototype of a channel.


### 2. The Dining Philosophers Problem


At the end of the paper, it returns to the classic dining philosophers problem.


![](https://img.halfrost.com/Blog/ArticleImage/149_2.jpeg)

In the dining philosophers problem, Hoare describes the behavior of a philosopher as follows:
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
Each fork is picked up or put down by the philosophers sitting on either side:
```go
FORK =
*[phil(0?pickup( )--* phil(0?putdown( )
0phil((i - 1)rood 5)?pickup( ) --* phil((/- l) raod 5)?putdown( )
]
```
The philosopher’s overall behavior in the room can be described as:
```go
ROOM = occupancy:integer; occupancy .--- 0;
,[(i:0..4)phil(0?enter ( ) --* occupancy .--- occupancy + l
11(i:0..4)phil(0?exit ( ) --~ occupancy .--- occupancy - l
] 
```
The task of deciding how to allocate resources to waiting processes is called scheduling. Hoare divides scheduling into two events:

- processes request resources
- resources are allocated to processes

Thus, the dining philosophers problem can be transformed into a concurrent process involving the two components PHIL and FORK:
```go
[room::ROOM I [fork( i:0..4)::FORK I Iphil( i:0..4)::PHIL]. 
```
The time from requesting a resource to being granted it is the waiting time. In CSP, several techniques can prevent unbounded waiting times.

- Limit resource usage and increase resource availability.
- First-in, first-out (FIFO) allocates resources to the process that has been waiting the longest.
- Bakery algorithm [Carnegie Mellon. Bakery Algorithm](https://www.cs.cmu.edu/~410-s14/lectures/L08b_Synch.pdf)


### 3. Limitations

In a deterministic program, if the environment remains constant, the result will be the same. Because concurrency is based on nondeterminism, the environment does not determine the program. Given the selected path, the program may run multiple times and produce different results. To ensure the correctness of a concurrent program, programmers must be able to reason about the execution of their program at a global level.

However, although Hoare introduced a formal method, there is still no proof method for verifying correct programs. CSP can only find known problems, not unknown ones. Although commercial CSP-based applications (such as ConAn) can detect the presence of errors, they cannot detect the absence of errors (that is, they cannot verify correctness). Although CSP gives us tools for writing programs that can avoid common concurrency errors, proving program correctness remains an unresolved area in CSP.


### 4. Future

CSP has tremendous potential in biology and chemistry for modeling complex systems in nature. Because the industry still faces many existing logic problems, CSP has not yet been widely used in industry. At a conference marking the 25th anniversary of CSP’s development, Hoare noted that, despite many Microsoft-funded research projects, Bill Gates ignored the [question](https://sites.google.com/site/jpbowen/) of when Microsoft would be able to commercialize CSP research results.

Hoare reminded his audience that the field of dynamic processes still needs more research. Today, the computer science community is stuck in a paradigm of sequential thinking. With Hoare having laid the foundation for formal methods in concurrency, the scientific community is ready for the next revolution in parallel programming.


### 5. Go Concurrency Philosophy


Before Go was released, few languages provided support for concurrency primitives from the ground up. Most languages still favored shared memory and synchronized memory access over CSP’s message-passing approach. Go was one of the first languages to incorporate CSP principles into its core. Synchronizing memory access is not a bad approach; it is just sometimes difficult to use correctly in highly concurrent scenarios, especially in very large, massive programs. For this reason, concurrency is considered one of Go’s inherent strengths. Fundamentally, this is because Go, based on CSP, created a set of readable and easy-to-write concurrency primitives.

In addition to CSP concurrency primitives, Go also supports synchronization through memory access. Types and methods in sync and other packages allow developers to create WaitGroup, mutexes and read-write locks, cond, once, and sync.Pool. Go’s official FAQ describes how to choose among these concurrency primitives:

> Regarding mutexes, the sync package implements mutexes, but we hope Go’s programming style will encourage people to try higher-level techniques. In particular, consider structuring your program so that only one goroutine at a time is responsible for a particular piece of data.
> 

**Do not communicate by sharing memory**. **Instead**, **share memory by communicating**. (**Do not communicate by sharing memory; instead, share memory by communicating**) This is the philosophical motto of concurrency in Go. Compared with using concurrency primitives such as sync.Mutex. Although most locking problems can be solved either with channel or with traditional locks, the Go core team more strongly recommends the CSP approach.

![](https://img.halfrost.com/Blog/ArticleImage/149_4.png)


As for how to choose concurrency primitives, this first article necessarily needs to make that clear. Concurrency primitives in Go are mainly divided into two broad categories: those in the sync package, and channel. The sync package mainly includes things like WaitGroup, mutexes and read-write locks, cond, once, and sync.Pool. The sync package is recommended in two situations:

- Performance-critical critical sections
- Protecting the internal state and integrity of a structure

For example, to protect the internal state and integrity of a structure, consider the following code from the Go source code:
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
The `sum` struct does not want to expose its internal variables outside the struct, so it uses `sync.Mutex` to ensure thread safety.

Compared with the `sync` package, channels also cover two scenarios:

- Outputting data to other consumers
- Composing multiple pieces of logic

The purpose of outputting data to other consumers is to transfer ownership of the data. The essence of concurrency safety is ensuring that only one concurrent context owns the data at any given time. A channel can conveniently transfer data ownership to another consumer. Another advantage is composition. If you use locks from the `sync` package, it is relatively difficult to compose multiple pieces of logic while ensuring concurrency safety. But using `channel` + `select` to implement composition logic is extremely convenient. The above is the basic concept of CSP and when to choose a channel. The next chapter starts with the basic data structures of channels and analyzes the underlying source implementation of channels in detail.

> The following code is based on Go 1.16

## II. Basic Data Structures

The underlying source code and related implementation of channels are in `src/runtime/chan.go`.
```go
type hchan struct {
	qcount   uint           // total number of data items in queue
	dataqsiz uint           // size of the circular queue
	buf      unsafe.Pointer // points to an array of length dataqsiz
	elemsize uint16         // element size
	closed   uint32
	elemtype *_type         // element type
	sendx    uint           // position of the sent element in the circular queue
	recvx    uint           // position of the received element in the circular queue
	recvq    waitq          // receiver wait queue
	sendq    waitq          // sender wait queue

	lock mutex
}
```
The lock protects all fields in hchan, as well as multiple fields in the sudogs blocked on this channel. While holding the lock, it is forbidden to change the state of another G (in particular, do not change a G’s state to ready), because this can deadlock due to stack shrinking.


![](https://img.halfrost.com/Blog/ArticleImage/149_5_.png)

recvq and sendq are wait queues, and waitq is a doubly linked list:
```go
type waitq struct {
	first *sudog
	last  *sudog
}
```
The core data structure of a channel is `sudog`. A `sudog` represents a `g` in a wait queue. `sudog` is a very important data structure in Go because the relationship between `g`s and synchronization objects is many-to-many. A single `g` can appear in many wait queues, so one `g` may have many `sudog`s. Likewise, multiple `g`s may be waiting on the same synchronization object, so one object may have many `sudog`s. `sudog`s are allocated from a special pool. They are allocated and released using `acquireSudog` and `releaseSudog`.
```go
type sudog struct {

	g *g

	next *sudog
	prev *sudog
	elem unsafe.Pointer // points to data (may point to stack)

	acquiretime int64
	releasetime int64
	ticket      uint32

	isSelect bool
	success bool

	parent   *sudog     // semaRoot binary tree
	waitlink *sudog     // g.waiting list or semaRoot
	waittail *sudog     // semaRoot
	c        *hchan     // channel
}
```
All fields in `sudog` are protected by `hchan.lock`. The three fields `acquiretime`, `releasetime`, and `ticket` are never accessed concurrently. For channels, `waitlink` is used only by `g`. For semaphores, these three fields can be accessed only while holding the `semaRoot` lock. `isSelect` indicates whether `g` has been selected; `g.selectDone` must use CAS to win the race when being woken up. `success` indicates whether communication on channel `c` succeeded. If a goroutine is woken up after sending a value on channel `c`, it is `true`; if it is woken up because `c` was closed, it is `false`.


## III. Creating a Channel

Common code for creating a channel:
```go
ch := make(chan int)
```
When compiling the code above, the compiler performs different checks on IR nodes depending on each node’s `op` type, as shown in the source code below:
```go
func walkExpr1(n ir.Node, init *ir.Nodes) ir.Node {
	switch n.Op() {
	default:
		ir.Dump("walk", n)
		base.Fatalf("walkExpr: switch 1 unknown op %+v", n.Op())
		panic("unreachable")

	case ir.OMAKECHAN:
		n := n.(*ir.MakeExpr)
		return walkMakeChan(n, init)

	......
}
```
The compiler checks every type. The implementation of `walkExpr1()` is essentially a `switch-case`, and there is no `return` at the end of the function because every `case` either returns or panics. This is done to distinguish it from cases where the returned value involves a type assertion. The specific logic in `walk` for handling `OMAKECHAN`-type nodes is as follows:
```go
func walkMakeChan(n *ir.MakeExpr, init *ir.Nodes) ir.Node {
	size := n.Len
	fnname := "makechan64"
	argtype := types.Types[types.TINT64]

	if size.Type().IsKind(types.TIDEAL) || size.Type().Size() <= types.Types[types.TUINT].Size() {
		fnname = "makechan"
		argtype = types.Types[types.TINT]
	}

	return mkcall1(chanfn(fnname, 1, n.Type()), n.Type(), init, reflectdata.TypePtr(n.Type()), typecheck.Conv(size, argtype))
}
```
The above code calls `makechan64()` by default. During type checking, if the size of `TIDEAL` is within the range of `int`, size overflow when converting `TUINT` or `TUINTPTR` to `TINT` will be checked at runtime in `makechan`. If the channel size passed to the `make` function is within the range of `int`, using `makechan()` is recommended. This is because `makechan()` is faster and uses less memory on 32-bit platforms.


The function prototypes of `makechan64()` and `makechan()` are as follows:
```go
func makechan64(chanType *byte, size int64) (hchan chan any)
func makechan(chanType *byte, size int) (hchan chan any)
```
The makechan64() function simply checks whether the incoming size argument is still within the range of an int:
```go
func makechan64(t *chantype, size int64) *hchan {
	if int64(int(size)) != size {
		panic(plainError("makechan: size out of range"))
	}

	return makechan(t, int(size))
}
```
The main implementation for creating a channel is in the makechan() function:
```go
func makechan(t *chantype, size int) *hchan {
	elem := t.elem

	// Compiler checks that the element size does not exceed 64KB
	if elem.size >= 1<<16 {
		throw("makechan: invalid channel element type")
	}
	// Check whether alignment is correct
	if hchanSize%maxAlign != 0 || elem.align > maxAlign {
		throw("makechan: bad alignment")
	}
    // Check buffer size and whether it overflows
	mem, overflow := math.MulUintptr(elem.size, uintptr(size))
	if overflow || mem > maxAlloc-hchanSize || size < 0 {
		panic(plainError("makechan: size out of range"))
	}

	var c *hchan
	switch {
	case mem == 0:
		// When the queue or element size is zero
		c = (*hchan)(mallocgc(hchanSize, nil, true))
		// Race detector uses this address for synchronization
		c.buf = c.raceaddr()
	case elem.ptrdata == 0:
		// When elements contain no pointers. Allocate memory for hchan and buf in one go.
		c = (*hchan)(mallocgc(hchanSize+mem, nil, true))
		c.buf = add(unsafe.Pointer(c), hchanSize)
	default:
		// When elements contain pointers
		c = new(hchan)
		c.buf = mallocgc(mem, elem, true)
	}

    // Set properties
	c.elemsize = uint16(elem.size)
	c.elemtype = elem
	c.dataqsiz = uint(size)
	lockInit(&c.lock, lockRankHchan)

	if debugChan {
		print("makechan: chan=", c, "; elemsize=", elem.size, "; dataqsiz=", size, "\n")
	}
	return c
}
```
The primary purpose of the `makechan()` code above is to create an *hchan object. Focus on the three cases in the switch-case:

- When the queue size or element size is 0, `mallocgc()` is called to allocate a block of memory of size hchanSize on the heap for the channel.
- When the element type is not a pointer type, `mallocgc()` is called to allocate a contiguous block of memory of size hchanSize + mem on the heap for both the channel and the underlying buf buffer array.
- In the default case, the element type contains pointers, so `mallocgc()` is called to allocate memory separately on the heap for the channel and the buf buffer.

After the first step of memory allocation is complete, the remaining work is to initialize the other fields of the hchan data structure and initialize the lock. One point worth noting is that when the elements stored in buf do not contain pointers, Hchan also does not contain pointers that the GC cares about. buf points to a block of memory containing elements of the same type, and elemtype is fixed. SudoG instances are referenced from their own threads, so the garbage collector cannot reclaim them. Due to limitations of the garbage collector, a pointer-typed buffer buf needs to be allocated separately. The official implementation adds a TODO here: this logic needs to be reconsidered during garbage collection.

> Precisely because channel creation always calls `mallocgc()` and allocates memory on the heap, the channel itself can be automatically reclaimed by the GC. This property is what enables the graceful channel-closing method discussed later.


## IV. Sending Data

Typical code for sending data to a channel:
```go
ch <- 1
```
When the compiler compiles the code above, while checking IR nodes, it performs different checks based on the node’s `op` type, as shown in the source code below:
```go
func walkExpr1(n ir.Node, init *ir.Nodes) ir.Node {
	switch n.Op() {
	default:
		ir.Dump("walk", n)
		base.Fatalf("walkExpr: switch 1 unknown op %+v", n.Op())
		panic("unreachable")

	case ir.OSEND:
		n := n.(*ir.SendStmt)
		return walkSend(n, init)

	......
}
```
The `walkExpr1()` function was mentioned when creating a channel, so we won’t repeat it here. The operation type is `OSEND`, which corresponds to a call to the `walkSend()` function:
```go
func walkSend(n *ir.SendStmt, init *ir.Nodes) ir.Node {
	n1 := n.Value
	n1 = typecheck.AssignConv(n1, n.Chan.Type().Elem(), "chan send")
	n1 = walkExpr(n1, init)
	n1 = typecheck.NodAddr(n1)
	return mkcall1(chanfn("chansend1", 2, n.Chan.Type()), nil, init, n.Chan, n1)
}

// entry point for c <- x from compiled code
//go:nosplit
func chansend1(c *hchan, elem unsafe.Pointer) {
	chansend(c, elem, true, getcallerpc())
}
```
The main logic in the `walkSend()` function calls `chansend1()`, while `chansend1()` is merely a “wrapper” around `chansend()`. Therefore, the core implementation of sending data on a channel is in `chansend()`. Based on channel blocking and wake-up behavior, the logic can be divided into two parts. Next, we will break the `chansend()` code into four parts for detailed analysis.

### 1. Exception Checks

At the beginning, the `chansend()` function first performs exception checks:
```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
    // Check whether channel is nil
	if c == nil {
		if !block {
			return false
		}
		gopark(nil, nil, waitReasonChanSendNilChan, traceEvGoStop, 2)
		throw("unreachable")
	}

	if debugChan {
		print("chansend: chan=", c, "\n")
	}

	if raceenabled {
		racereadpc(c.raceaddr(), callerpc, funcPC(chansend))
	}

	// Simple fast check
	if !block && c.closed == 0 && full(c) {
		return false
	}
......
}
```
chansend() first checks the channel; if it has been reclaimed by the GC, it becomes nil. Sending data to a nil channel blocks. gopark causes the goroutine to sleep with waitReasonChanSendNilChan as the reason, and then throws an unreachable fatal error. When the channel is not nil, it then checks, without acquiring the lock, for the non-blocking case where the send would fail.

When the channel is not nil and the channel has not been closed, it also needs to check whether the channel is ready for sending at this point, that is, by evaluating full(c).
```go
func full(c *hchan) bool {
	if c.dataqsiz == 0 {
		// Assume pointer reads are approximately atomic
		return c.recvq.first == nil
	}
	// Assume uint reads are approximately atomic
	return c.qcount == c.dataqsiz
}
```
The `full()` method determines whether sending on a channel would block (that is, whether the channel is full). It reads mutable state using single word-sized reads (`recvq.first` and `qcount`). Although the answer may be `true` at a given instant, by the time the caller receives the return value, the correct result may already have changed. One point worth noting is the `dataqsiz` field: after the channel is created, it is immutable, so it can be safely read at any time.

Back to the exceptional-state checks in `chansend()`. A closed channel cannot transition from a “ready to send” state to a “not ready to send” state. Therefore, after checking whether the channel is closed, even if the channel is then closed, it does not affect the result of this check. Some readers may wonder: “Can we reverse the order of the checks? Check `full()` first, then check whether the channel is closed?” Reversing the order can indeed guarantee that the channel is not closed while `full()` is being checked. But this does not make any substantive difference. The channel can still be closed after the close check completes. What we actually rely on is that `chanrecv()` and `closechan()`, after releasing the lock, update this thread’s view of the results of `c.close` and `full()`.

### 2. Synchronous Send

After the channel’s exceptional-state checks, the following code implements the send logic.
```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
......

	lock(&c.lock)

	if c.closed != 0 {
		unlock(&c.lock)
		panic(plainError("send on closed channel"))
	}

	if sg := c.recvq.dequeue(); sg != nil {
		send(c, sg, ep, func() { unlock(&c.lock) }, 3)
		return true
	}

......

}
```
Before sending, acquire the lock to ensure thread safety. Then check once again whether the channel is closed. If it is closed, panic. After the lock is successfully acquired and the channel is confirmed to be open, start sending. If there is a receiver currently blocked and waiting, use `dequeue()` to take the first non-empty `sudog` from the head, then call the `send()` function:
```go
func send(c *hchan, sg *sudog, ep unsafe.Pointer, unlockf func(), skip int) {
	if sg.elem != nil {
		sendDirect(c.elemtype, sg, ep)
		sg.elem = nil
	}
	gp := sg.g
	unlockf()
	gp.param = unsafe.Pointer(sg)
	sg.success = true
	if sg.releasetime != 0 {
		sg.releasetime = cputicks()
	}
	goready(gp, skip+1)
}
```
The `send()` function primarily does two things:

- 1. Calls `sendDirect()` to copy the data to the memory address of the receiving variable.
- 2. Calls `goready()` to change the state of the blocked goroutine waiting to receive from `Gwaiting` or `Gscanwaiting` to `Grunnable`. On the next scheduling cycle, this receiving goroutine will be woken up.

![](https://img.halfrost.com/Blog/ArticleImage/149_6_1.png)

Here, let’s focus on the implementation of `goready()`. Once you understand its source code, you’ll see why data sent to a channel is not necessarily immediately available to the receiver.
```go
func goready(gp *g, traceskip int) {
	systemstack(func() {
		ready(gp, traceskip, true)
	})
}

func ready(gp *g, traceskip int, next bool) {
......

	casgstatus(gp, _Gwaiting, _Grunnable)
	runqput(_g_.m.p.ptr(), gp, next)
	wakep()
	releasem(mp)
}
```
The purpose of the runqput() function is to bind g to the local runnable queue. Here, next is passed as true, which inserts g into the runnext slot so that it will run immediately on the next scheduling cycle. Because of this, although goroutines ensure thread safety, reading data from them is several hundred nanoseconds slower than from an array.


| Read | Channel | Slice |
| :-----:| :-----: | :-----: |
| Time | x * 100 * nanosecond|0|
| Thread safe | Yes| No|


Therefore, when writing test cases, you sometimes need to account for this slight delay and can add sleep() as appropriate. Similarly, when solving LeetCode problems, using goroutines indiscriminately does not necessarily improve runtime. For example, in [509. Fibonacci Number](https://leetcode.com/problems/fibonacci-number/), interested readers can try solving it with goroutines. I implemented a [goroutine solution](https://books.halfrost.com/leetcode/ChapterFour/0500~0599/0509.Fibonacci-Number/), and its performance is far worse than the array-based solution.


### 3. Asynchronous Send

If a buffered asynchronous Channel is created when initializing the channel, then when the receiver queue is empty, it enters the asynchronous send logic:
```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
......

	if c.qcount < c.dataqsiz {
		qp := chanbuf(c, c.sendx)
		if raceenabled {
			racenotify(c, c.sendx, nil)
		}
		typedmemmove(c.elemtype, qp, ep)
		c.sendx++
		if c.sendx == c.dataqsiz {
			c.sendx = 0
		}
		c.qcount++
		unlock(&c.lock)
		return true
	}
	
......
}
```
If `qcount` is not yet full, `chanbuf()` is called to obtain the element pointer at the `sendx` index. The `typedmemmove()` method is then called to copy the value being sent into the buffer `buf`. After the copy completes, the `sendx` index value and the `qcount` count need to be maintained. Here, the `buf` buffer is designed as a ring buffer: if the index reaches the end of the queue, the next position wraps back to the head of the queue.

![](https://img.halfrost.com/Blog/ArticleImage/149_7_.png)

At this point, the two direct-send code paths have been analyzed. Next is the case where sending on the channel blocks.


### 4. Blocking Send

When the channel is open, but there is no receiver, and there is no `buf` buffer queue or the `buf` queue is full, the channel enters a blocking send.
```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
......

	if !block {
		unlock(&c.lock)
		return false
	}
	
	gp := getg()
	mysg := acquireSudog()
	mysg.releasetime = 0
	if t0 != 0 {
		mysg.releasetime = -1
	}
	mysg.elem = ep
	mysg.waitlink = nil
	mysg.g = gp
	mysg.isSelect = false
	mysg.c = c
	gp.waiting = mysg
	gp.param = nil
	c.sendq.enqueue(mysg)
	atomic.Store8(&gp.parkingOnChan, 1)
	gopark(chanparkcommit, unsafe.Pointer(&c.lock), waitReasonChanSend, traceEvGoBlockSend, 2)
	KeepAlive(ep)
......
}
```
- Call the `getg()` method to obtain a pointer to the current goroutine, which is used to bind it to a `sudog`.
- Call the `acquireSudog()` method to obtain a `sudog`. It may be a newly created `sudog`, or it may be retrieved from the cache. Configure the data and state that the `sudog` needs to send, such as the sending Channel, whether it is in a `select`, and the memory address of the data to be sent.
- Call the `c.sendq.enqueue` method to add the configured `sudog` to the send wait queue.
- Set the atomic signal. When the stack is about to shrink, this flag indicates that the current goroutine is still parked in some channel. It is unsafe to shrink the stack in the time window between the `g` state transition and setting the `activeStackChans` state, so this atomic signal needs to be set.
- Call the `gopark` method to suspend the current goroutine, with the state set to `waitReasonChanSend`, blocking while waiting on the channel.
- Finally, `KeepAlive()` ensures that the value being sent remains live until the receiver copies it out. The `sudog` has a pointer to a stack object, but the `sudog` cannot be treated as a root by the stack tracer. The value being sent is allocated on the heap, which prevents it from being reclaimed by the GC.

![](https://img.halfrost.com/Blog/ArticleImage/149_12.png)


Here is a brief note on the two-level cache reuse system for `sudog`. In the `acquireSudog()` method:
```go
func acquireSudog() *sudog {
	mp := acquirem()
	pp := mp.p.ptr()
	// If the local cache is empty
	if len(pp.sudogcache) == 0 {
		lock(&sched.sudoglock)
		// First try to move part of the global central cache to the local cache
		for len(pp.sudogcache) < cap(pp.sudogcache)/2 && sched.sudogcache != nil {
			s := sched.sudogcache
			sched.sudogcache = s.next
			s.next = nil
			pp.sudogcache = append(pp.sudogcache, s)
		}
		unlock(&sched.sudoglock)
		// If the global central cache is empty, allocate a new one
		if len(pp.sudogcache) == 0 {
			pp.sudogcache = append(pp.sudogcache, new(sudog))
		}
	}
	// Pop from the tail and adjust the local cache
	n := len(pp.sudogcache)
	s := pp.sudogcache[n-1]
	pp.sudogcache[n-1] = nil
	pp.sudogcache = pp.sudogcache[:n-1]
	if s.elem != nil {
		throw("acquireSudog: found s.elem != nil in cache")
	}
	releasem(mp)
	return s
}
```
The above code involves two new important structs. Since these two structs are quite complex, for now we will only show the parts related to `acquireSudog()`:
```go
type p struct {
......
	sudogcache []*sudog
	sudogbuf   [128]*sudog
......
}

type schedt struct {
......
	sudoglock  mutex
	sudogcache *sudog
......
}
```
`sched.sudogcache` is the global central cache; you can think of it as the “L1 cache”. It is cleared by `clearpools` when GC runs. `p.sudogcache` can be considered the “L2 cache”; it is a local cache and is not cleared by GC.

The final part of `chansend` contains the logic for clearing the blocked state after the goroutine is woken up:
```go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
......

	if mysg != gp.waiting {
		throw("G waiting list is corrupted")
	}
	gp.waiting = nil
	gp.activeStackChans = false
	closed := !mysg.success
	gp.param = nil
	if mysg.releasetime > 0 {
		blockevent(mysg.releasetime-t0, 2)
	}
	mysg.c = nil
	releaseSudog(mysg)
	if closed {
		if c.closed == 0 {
			throw("chansend: spurious wakeup")
		}
		panic(plainError("send on closed channel"))
	}
	return true
}
```
`sudog` can be considered a wrapper around `g`; it contains the `g`, the data to be sent, and the relevant state. After the goroutine is woken up, it completes the blocked data send on the channel. Once the send is complete, it performs basic parameter checks, removes the channel binding, and releases the `sudog`.
```go
func releaseSudog(s *sudog) {
	if s.elem != nil {
		throw("runtime: sudog with non-nil elem")
	}
	if s.isSelect {
		throw("runtime: sudog with non-false isSelect")
	}
	if s.next != nil {
		throw("runtime: sudog with non-nil next")
	}
	if s.prev != nil {
		throw("runtime: sudog with non-nil prev")
	}
	if s.waitlink != nil {
		throw("runtime: sudog with non-nil waitlink")
	}
	if s.c != nil {
		throw("runtime: sudog with non-nil c")
	}
	gp := getg()
	if gp.param != nil {
		throw("runtime: releaseSudog with non-nil gp.param")
	}
	// Prevent rescheduling to another P
	mp := acquirem() 
	pp := mp.p.ptr()
	// If the local cache is full
	if len(pp.sudogcache) == cap(pp.sudogcache) {
		// Move half of the local cache to the global central cache
		var first, last *sudog
		for len(pp.sudogcache) > cap(pp.sudogcache)/2 {
			n := len(pp.sudogcache)
			p := pp.sudogcache[n-1]
			pp.sudogcache[n-1] = nil
			pp.sudogcache = pp.sudogcache[:n-1]
			if first == nil {
				first = p
			} else {
				last.next = p
			}
			last = p
		}
		lock(&sched.sudoglock)
		// Attach the extracted linked list to the global central cache
		last.next = sched.sudogcache
		sched.sudogcache = first
		unlock(&sched.sudoglock)
	}
	pp.sudogcache = append(pp.sudogcache, s)
	releasem(mp)
}
```
releaseSudog() frees the memory for the sudog, but it is cached by the “secondary cache” `p.sudogcache`.

The `chansend()` function ultimately returns true to indicate that data was successfully sent to the Channel.

### 5. Summary

We have finished analyzing the source-code implementation of sending on a channel. Here is a summary for each channel state.

| | Channel Status | Result |
| :-----:| :-----: | :-----: |
| Write | nil|blocks|
| Write |open but full|blocks|
| Write | open but not full|value written successfully|
| Write | closed|**panic**|
| Write | read-only|Compile Error|
  
  

The channel send process involves two goroutine scheduling operations:

- 1. When there is a sudog in the receive queue and data can be sent directly, `goready()` inserts g into the runnext slot, changing its state from Gwaiting or Gscanwaiting to Grunnable. It will run immediately on the next scheduling cycle.
- 2. When the channel blocks, `gopark()` blocks g and yields the CPU.

It is important to emphasize that channels do not provide a mechanism for protecting data access across goroutines. If a copy of the data is transmitted through a channel, each goroutine holds its own copy, and it is safe for each goroutine to modify its own copy. When what is transmitted is a pointer to the data, and reads and writes are performed by different goroutines, each goroutine still needs additional synchronization.


## V. Receiving Data


Common code for receiving data from a channel:
```go
tmp := <-ch
tmp, ok := <-ch
```
First, consider the case where there is a single value on the left-hand side of the assignment. When compiling the code above, the compiler performs different checks based on the node’s op type while checking IR nodes, as shown in the source code below:
```go
// walkAssign walks an OAS (AssignExpr) or OASOP (AssignOpExpr) node.
func walkAssign(init *ir.Nodes, n ir.Node) ir.Node {
......

	switch as.Y.Op() {
	default:
		as.Y = walkExpr(as.Y, init)

	case ir.ORECV:
		// x = <-c; as.Left is x, as.Right.Left is c.
		// order.stmt made sure x is addressable.
		recv := as.Y.(*ir.UnaryExpr)
		recv.X = walkExpr(recv.X, init)

		n1 := typecheck.NodAddr(as.X)
		r := recv.X // the channel
		return mkcall1(chanfn("chanrecv1", 2, r.Type()), nil, init, r, n1)
		
......
}
```
as is the input ir node cast to the AssignStmt type. AssignStmt is a representation of an assignment:
```go
type AssignStmt struct {
	miniStmt
	X   Node
	Def bool
	Y   Node
}
```
Y is the value on the right-hand side of the equals sign. It is of type Node and contains an op type. `walkAssign` checks assignment statements. If `Y.Op()` is of type `ir.ORECV`, it indicates a channel receive operation, and the `chanrecv1()` function is called. `as.X` is the element on the left-hand side of the assignment statement; it receives the value from the channel, so it must be addressable.

When reading data from a channel and there are two values on the left-hand side of the equals sign, the compiler checks this assignment statement in `walkExpr1`:
```go
func walkExpr1(n ir.Node, init *ir.Nodes) ir.Node {
	switch n.Op() {
	default:
		ir.Dump("walk", n)
		base.Fatalf("walkExpr: switch 1 unknown op %+v", n.Op())
		panic("unreachable")
......

	case ir.OAS2RECV:
		n := n.(*ir.AssignListStmt)
		return walkAssignRecv(init, n)
		
......
}
```
`n.Op()` is of type `ir.OAS2RECV`; cast `n` to the `AssignListStmt` type:
```go
type AssignListStmt struct {
	miniStmt
	Lhs Nodes
	Def bool
	Rhs Nodes
}
```
`AssignListStmt` serves the same purpose as `AssignStmt`; the only difference is that `AssignListStmt` indicates that the assignment statements on both sides of the equals sign are no longer single objects, but multiple ones. Returning to `walkExpr1()`, if the type is `ir.OAS2RECV`, call `walkAssignRecv()` to continue the check.
```go
func walkAssignRecv(init *ir.Nodes, n *ir.AssignListStmt) ir.Node {
	init.Append(ir.TakeInit(n)...)
	r := n.Rhs[0].(*ir.UnaryExpr) // recv
	walkExprListSafe(n.Lhs, init)
	r.X = walkExpr(r.X, init)
	var n1 ir.Node
	if ir.IsBlank(n.Lhs[0]) {
		n1 = typecheck.NodNil()
	} else {
		n1 = typecheck.NodAddr(n.Lhs[0])
	}
	fn := chanfn("chanrecv2", 2, r.X.Type())
	ok := n.Lhs[1]
	call := mkcall1(fn, types.Types[types.TBOOL], init, r.X, n1)
	return typecheck.Stmt(ir.NewAssignStmt(base.Pos, ok, call))
}
```
Lhs[0] is the object that actually receives the channel value, and Lhs[1] is the second bool value on the left-hand side of the assignment statement. Since there is only one channel on the right-hand side of the assignment statement, only Rhs[0] is used here.
```go
//go:nosplit
func chanrecv1(c *hchan, elem unsafe.Pointer) {
	chanrecv(c, elem, true)
}

//go:nosplit
func chanrecv2(c *hchan, elem unsafe.Pointer) (received bool) {
	_, received = chanrecv(c, elem, true)
	return
}
```
Based on the analysis above, the two different forms of channel receive are lowered into calls to two different functions, `runtime.chanrecv1` and `runtime.chanrecv2`, but the core logic ultimately still resides in `runtime.chanrecv`.


### 1. Exception checks

The `chanrecv()` function first performs exception checks:
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
	if debugChan {
		print("chanrecv: chan=", c, "\n")
	}

	if c == nil {
		if !block {
			return
		}
		gopark(nil, nil, waitReasonChanReceiveNilChan, traceEvGoStop, 2)
		throw("unreachable")
	}

	// Simple fast check
	if !block && empty(c) {
		if atomic.Load(&c.closed) == 0 {
			return
		}
		if empty(c) {
			// channel is irreversibly closed and empty
			if raceenabled {
				raceacquire(c.raceaddr())
			}
			if ep != nil {
				typedmemclr(c.elemtype, ep)
			}
			return true, false
		}
	}
```
`chanrecv()` starts by checking the channel. If it has been reclaimed by the GC, it will become `nil`. Receiving from a `nil` channel blocks. `gopark` causes the goroutine to sleep with `waitReasonChanReceiveNilChan` as the reason, and then throws an unreachable fatal error. When the channel is not `nil`, it begins checking for non-blocking operations that would fail to receive without acquiring the lock.

The lightweight fast-path check performed here requires that the state not change during the check. This differs from the `chansend()` function. In the lightweight fast-path check in `chansend()`, changing the order has little effect on the result. Here, however, if the state changes during the check—i.e., if a race occurs—the check may produce a completely opposite, incorrect result. For example: the channel is open and non-empty during the first and second `if` checks, so the function returns inside the second `if`. But at the instant it returns, the channel becomes closed and empty. The check therefore concludes that the channel is open and non-empty, which is clearly incorrect; in reality, the channel is closed and empty. Similarly, a state inversion can also occur when checking whether it is empty. To prevent incorrect check results, both `c.closed` and `empty()` must be checked atomically.
```go
func empty(c *hchan) bool {
	// c.dataqsiz is immutable
	if c.dataqsiz == 0 {
		return atomic.Loadp(unsafe.Pointer(&c.sendq.first)) == nil
	}
	return atomic.Loaduint(&c.qcount) == 0
}
```
Here, `empty()` is checked twice in total, because during the first check, the channel may not yet have been closed, but by the time of the second check it may have been closed, and data pending to be received may have arrived between the two checks. Therefore, two `empty()` checks are required.

However, even with the source-level checks described above, a careful reader might still come up with a counterexample. For example, when closing a synchronous channel that is already blocked, the initial `!block && empty(c)` is `false`, so this check is skipped. This case should not be considered part of the normal `chanrecv()` path. The above describes the failure-to-receive check performed without acquiring the lock. Next, after acquiring the lock, the exceptional cases are checked again.
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
......
	lock(&c.lock)

	if c.closed != 0 && c.qcount == 0 {
		if raceenabled {
			raceacquire(c.raceaddr())
		}
		unlock(&c.lock)
		if ep != nil {
			typedmemclr(c.elemtype, ep)
		}
		return true, false
	}
......
```
If the channel has already been closed and there is no buffered data, clear the data in the `ep` pointer and return. This is also why reading from an already closed channel yields the zero value of that type.


### 2. Synchronous Receive

Similar to the logic in `chansend`, after checking the exceptional cases, the next step is synchronous receive.
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
......

	if sg := c.sendq.dequeue(); sg != nil {
		recv(c, sg, ep, func() { unlock(&c.lock) }, 3)
		return true, true
	}
......
```
A goroutine waiting to send was found in the channel’s send queue. Dequeue the goroutine at the head of the queue. If the buffer size is 0, receive the value directly from the sender. Otherwise, corresponding to the case where the buffer is full, receive data from the head of the queue, and append the sender’s value to the tail of the queue (since the queue is full at this point, both map to the same index in the buffer). The core logic for synchronous receive is shown in the `recv()` function below:
```go
func recv(c *hchan, sg *sudog, ep unsafe.Pointer, unlockf func(), skip int) {
	if c.dataqsiz == 0 {
		if raceenabled {
			racesync(c, sg)
		}
		if ep != nil {
			// Copy data from sender
			recvDirect(c.elemtype, sg, ep)
		}
	} else {
	    // This corresponds to the case where buf is full
		qp := chanbuf(c, c.recvx)
		if raceenabled {
			racenotify(c, c.recvx, nil)
			racenotify(c, c.recvx, sg)
		}
		// Copy data from buf to the receiver's memory address
		if ep != nil {
			typedmemmove(c.elemtype, ep, qp)
		}
		// Copy data from sender to buf
		typedmemmove(c.elemtype, qp, sg.elem)
		c.recvx++
		if c.recvx == c.dataqsiz {
			c.recvx = 0
		}
		c.sendx = c.recvx // c.sendx = (c.sendx+1) % c.dataqsiz
	}
	sg.elem = nil
	gp := sg.g
	unlockf()
	gp.param = unsafe.Pointer(sg)
	sg.success = true
	if sg.releasetime != 0 {
		sg.releasetime = cputicks()
	}
	goready(gp, skip+1)
}
```
It is important to note that because there is a sender waiting, **if a buffer exists, the buffer must be full**. This corresponds to the case where sending is blocked during the send phase. If the buffer still has available slots, the data being sent is placed directly into the buffer; only when the buffer is full will it be packaged as a sudog and inserted into the sendq queue to wait for scheduling. Be sure to understand this case.

Receiving mainly falls into 2 cases: buffered with a full buf, and unbuffered:

- Unbuffered. The ep sending data is not nil, so recvDirect() is called to copy the ep data stored in the sudog in the send queue directly into the receiver’s memory address.


![](https://img.halfrost.com/Blog/ArticleImage/149_10.png)

- Buffered and buf is full. There are 2 copy operations: first, the data at the recvx index in the queue is copied to the receiver’s memory address; then the data at the head of the send queue is copied into the buffer, releasing a goroutine blocked on a sudog.


	In the buffered-and-buf-full case, note that data is taken from the head of the buffer queue, while the sent data is placed at the tail of the queue. Because the buf is full, the recvx pointer for the item being taken and the sendx pointer for the item being sent point to the same index.


![](https://img.halfrost.com/Blog/ArticleImage/149_9.png)


Finally, goready() is called to change the state of the blocked goroutine waiting to receive from Gwaiting or Gscanwaiting to Grunnable. In the next round of scheduling, this sending goroutine will be awakened. This part of the logic is the same as in synchronous sending, so the underlying implementation code of goready() will not be elaborated on again here.

### 3. Asynchronous Receive

If the Channel’s buffer contains some data, receiving data from the Channel will directly take the data from the recvx index position in the buffer and process it:
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
......

	if c.qcount > 0 {
		// Receive directly from the queue
		qp := chanbuf(c, c.recvx)
		if raceenabled {
			racenotify(c, c.recvx, nil)
		}
		if ep != nil {
			typedmemmove(c.elemtype, ep, qp)
		}
		typedmemclr(c.elemtype, qp)
		c.recvx++
		if c.recvx == c.dataqsiz {
			c.recvx = 0
		}
		c.qcount--
		unlock(&c.lock)
		return true, true
	}

	if !block {
		unlock(&c.lock)
		return false, false
	}
......
```
The code above is relatively simple. If the memory address `ep` for receiving data is not nil, it calls `runtime.typedmemmove()` to copy the data from the buffer into memory, and uses `typedmemclr()` to clear the data in the queue.

![](https://img.halfrost.com/Blog/ArticleImage/149_11.png)


It maintains the `recvx` index. If it moves to the tail of the circular queue, the index needs to wrap back to the head. Finally, it decrements the `qcount` counter and releases the lock held on the Channel.


### 4. Blocking receive

If there is no goroutine waiting to send on the channel’s send queue, and there is no data in the buffer, it enters the final phase: blocking receive.
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
......

	gp := getg()
	mysg := acquireSudog()
	mysg.releasetime = 0
	if t0 != 0 {
		mysg.releasetime = -1
	}
	mysg.elem = ep
	mysg.waitlink = nil
	gp.waiting = mysg
	mysg.g = gp
	mysg.isSelect = false
	mysg.c = c
	gp.param = nil
	c.recvq.enqueue(mysg)
	atomic.Store8(&gp.parkingOnChan, 1)
	gopark(chanparkcommit, unsafe.Pointer(&c.lock), waitReasonChanReceive, traceEvGoBlockRecv, 2)
......
```
- Call the `getg()` method to obtain a pointer to the current goroutine, which is used to bind to a `sudog`.
- Call the `acquireSudog()` method to obtain a `sudog`. This may be a newly created `sudog`, or it may be retrieved from the cache. Set the data and state that the `sudog` is going to send, such as the Channel to send on, whether it is in a `select`, and the memory address of the data to be sent.
- Call the `c.recvq.enqueue` method to add the configured `sudog` to the send wait queue.
- Set the atomic signal. When the stack is about to shrink, this flag indicates that the current goroutine is still parked in a channel. It is unsafe to shrink the stack during the time window between the `g` state transition and setting the `activeStackChans` state, so this atomic signal needs to be set.
- Call the `gopark` method to suspend the current goroutine, with the state `waitReasonChanReceive`, blocking while waiting on the channel.

![](https://img.halfrost.com/Blog/ArticleImage/149_8_0.png)

The code above is almost identical to the blocking send path in `chansend()`. The difference is that the final step does not call `KeepAlive(ep)`.
```go
func chanrecv(c *hchan, ep unsafe.Pointer, block bool) (selected, received bool) {
......

	// Woken up
	if mysg != gp.waiting {
		throw("G waiting list is corrupted")
	}
	gp.waiting = nil
	gp.activeStackChans = false
	if mysg.releasetime > 0 {
		blockevent(mysg.releasetime-t0, 2)
	}
	success := mysg.success
	gp.param = nil
	mysg.c = nil
	releaseSudog(mysg)
	return true, success
}
```
A goroutine, after being woken up, completes the blocked receive from the channel. After receiving, it finally performs basic parameter checks, removes the channel binding, and releases the sudog.


### 5. Summary

The source-code implementation of channel receives has now been fully analyzed. Here is a summary of the behavior for each channel state.

| | Channel status | Result |  
| :-----: | :-----: | :-----: |
| Read | nil|Blocked|  
| Read | Open and non-empty|Reads a value|  
| Read | Open but empty|Blocked|  
| Read | Closed|<zero value>, false|  
| Read | Read-only|Compile Error|  


There are several possible return values for chanrecv:
```go
tmp, ok := <-ch
```
| Channel status | Selected | Received |  
| :-----: | :-----: | :-----: |
| nil | false| false |  
| Open and non-empty | true | true |  
| Open but empty | false| false |  
| Closed and the returned value is the zero value | true|false|  


The received value is passed to the bool value ok outside the channel receive operation; the selected value is not used externally.

The channel receive process includes 2 goroutine scheduling-related steps:

1. When the channel is nil, execute gopark() to suspend the current goroutine.
2. When there is a sudog in the send queue and data can be received directly, execute goready() to insert g into the runnext slot. Its state changes from Gwaiting or Gscanwaiting to Grunnable, and it will run immediately the next time it is scheduled.
3. When the channel buffer is empty and there is no sender, the channel blocks. Execute gopark() to block g, yield the CPU, and wait for the scheduler to schedule it.

## VI. Closing a Channel

Common code involving channel:
```go
close(ch)
```
The compiler converts it into the `runtime.closechan()` method.

### 1. Exception Checks
```go
func closechan(c *hchan) {
	if c == nil {
		panic(plainError("close of nil channel"))
	}

	lock(&c.lock)
	if c.closed != 0 {
		unlock(&c.lock)
		panic(plainError("close of closed channel"))
	}

	if raceenabled {
		callerpc := getcallerpc()
		racewritepc(c.raceaddr(), callerpc, funcPC(closechan))
		racerelease(c.raceaddr())
	}
	
	c.closed = 1
......
}
```
Closing a channel involves two important points: if the channel is `nil`, or if you close a channel that has already been closed, the Go runtime will panic immediately. If neither of these two cases applies, the channel’s state is marked as closed.


### 2. Release all readers and writers

The main work involved in closing a channel is releasing all readers and writers.
```go
func closechan(c *hchan) {
......
	var glist gList

	for {
		sg := c.recvq.dequeue()
		if sg == nil {
			break
		}
		if sg.elem != nil {
			typedmemclr(c.elemtype, sg.elem)
			sg.elem = nil
		}
		if sg.releasetime != 0 {
			sg.releasetime = cputicks()
		}
		gp := sg.g
		gp.param = unsafe.Pointer(sg)
		sg.success = false
		if raceenabled {
			raceacquireg(gp, c.raceaddr())
		}
		glist.push(gp)
	}
......
}
```
The code above reclaims the receivers’ `sudog`s. It adds the `sudog` wait queue (`recvq`) of all receivers (`readers`) to the cleanup list `glist`. Note that receivers are reclaimed first here. Even if you read a value from a closed channel, it will not panic; at most, you’ll read the default zero value.
```go
func closechan(c *hchan) {
......

	for {
		sg := c.sendq.dequeue()
		if sg == nil {
			break
		}
		sg.elem = nil
		if sg.releasetime != 0 {
			sg.releasetime = cputicks()
		}
		gp := sg.g
		gp.param = unsafe.Pointer(sg)
		sg.success = false
		if raceenabled {
			raceacquireg(gp, c.raceaddr())
		}
		glist.push(gp)
	}
	unlock(&c.lock)
......
}
```
Next, reclaim the sender writers. The reclamation steps are exactly the same as for receivers: put the `sudog`s in the sender wait queue `sendq` into the pending-cleanup list `glist`. Note that this may trigger a panic. As analyzed in Chapter 4, Sending Data, sending data to a closed channel will cause a panic, so we won’t repeat the details here.


![](https://img.halfrost.com/Blog/ArticleImage/149_13.png)


### 3. Goroutine Scheduling

The final step is to change the goroutine’s state.
```go
func closechan(c *hchan) {
......
	for !glist.empty() {
		gp := glist.pop()
		gp.schedlink = 0
		goready(gp, 3)
	}
......
}
```
Finally, `goready` is called for all blocked goroutines to trigger scheduling. It sets the state of all goroutines in the `glist` from `_Gwaiting` to `_Grunnable`, waiting for the scheduler to schedule them.


### 4. Graceful Shutdown


“How many graceful ways are there to close a Channel?” This kind of question often appears in interviews. The reason is that Channels are easy to create, but not “easy” to close:

- Without changing the Channel’s own state, there is no way to know whether it has already been closed. The first reason it is “not easy”: the timing for closing is unknown.
- If a Channel has already been closed, closing it again will cause a panic. The second reason it is “not easy”: you cannot close it blindly.
- Writing data to a closed Channel will also cause a panic. The third reason it is “not easy”: before writing data, you also need to pay attention to whether it is in the closed state.


| | Channel Status | Result |
| :-----:| :-----: | :-----: |
| close | nil | **panic** |
| close | open and non-empty | Close the Channel; reads succeed until the Channel is drained, then reads yield the zero value |
| close | open but empty | Close the Channel; reads yield the producer’s zero value |
| close | closed | **panic** |
| close | read-only | Compile Error |
 

So when exactly should you close a Channel? The three points above about it being “not easy” can be condensed into two rules:

- You cannot simply close a Channel from the consumer side.
- If there are multiple producers, they must not close the Channel.

Let’s explain these two issues. For the first issue, consumers do not know when the Channel should be closed. Closing an already closed Channel will cause a panic. Moreover, distributed applications typically have multiple consumers, and each consumer behaves the same way. If all these consumers try to close the Channel, it will inevitably cause a panic. For the second issue, if multiple producers write data into a Channel, their behavior and logic are also the same. If one producer closes the Channel while the other producers are still writing to it, a panic will occur. Therefore, to prevent panics, the two issues above must be solved.

There are only two ways to close a Channel:

- Context
- done channel

The Context approach will not be discussed in detail in this article. For details, you can refer to the author’s article on Context. This section discusses the `done channel` approach. Suppose there are multiple producers and multiple consumers. Add an extra auxiliary control channel between the producers and consumers to transmit the shutdown signal.
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
On the consumer side, a closed `done channel` is used to send the shutdown signal. Because there are multiple consumers, if each of them closes the `done channel`, it will cause a panic. Therefore, `doneOnce.Do()` is used here to ensure that the `done channel` is closed only once. This solves the first problem. After producers receive the signal from the `done channel`, they exit automatically. Multiple producers may exit at different times, but eventually they will all exit. After all producers have exited, the `data channel` will eventually have no references and will be reclaimed by the GC. This also solves the second problem: producers do not close the `data channel`, which prevents a panic.

![](https://img.halfrost.com/Blog/ArticleImage/149_1.png)


To summarize the `done channel` approach: consumers use an auxiliary `done channel` to send a signal and begin exiting their goroutines first. After producers receive the signal from the `done channel`, they also begin exiting their goroutines. Eventually, no one holds the `data channel`, and it is reclaimed and closed by the GC.


---------------------------------
Reference:

[ACM Communicating Sequential Processes](https://dl.acm.org/doi/10.1145/359576.359585)  
[Stanford Project About CSP](https://cs.stanford.edu/people/eroberts/courses/soco/projects/2008-09/tony-hoare/csp.html)