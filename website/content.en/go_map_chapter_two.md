+++
author = "一缕殇流化隐半边冰霜"
categories = ["Go", "Map"]
date = 2017-10-04T20:58:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/59_0.png"
slug = "go_map_chapter_two"
tags = ["Go", "Map"]
title = "How to Design and Implement a Thread-Safe Map? (Part 2)"

+++


In the previous part, we discussed how to implement a Map and covered many optimization points. In the next part, we will continue discussing how to implement a thread-safe Map. When it comes to thread safety, we need to start with the concept itself.


![](https://img.halfrost.com/Blog/ArticleImage/59_1.png)


Thread safety means that if there are multiple threads running concurrently in the process where your code block resides, those threads may execute this code at the same time. If every execution produces the same result as single-threaded execution, and the values of other variables are also as expected, then it is thread-safe.

If a code block contains operations that update shared data, then the code block may not be thread-safe. However, if all such operations in the code block are inside a critical section, then the code block is thread-safe.


There are usually two categories of methods for avoiding race conditions and achieving thread safety:

#### Category 1 — Avoid Shared State

1.Re-entrancy [Re-entrancy](https://en.wikipedia.org/wiki/Reentrant_(subroutine)) 

In thread-safety problems, the most common kind of code block is usually a function. The most effective way to make a function thread-safe is to make it reentrant. If all threads in a process can call a function concurrently, and the function can produce the expected result regardless of the actual execution of those calls, then the function can be said to be reentrant.

If a function uses shared data as its return value, or includes shared data in the result it returns, then the function is definitely not reentrant. Any function that contains code operating on shared data is non-reentrant.

To implement a thread-safe function, it is feasible to place all code inside a critical section. However, using a mutex always consumes some system resources and time, and there are always trade-offs involved in using mutexes. So use mutexes judiciously to protect code that involves operations on shared data.

**Note**: Reentrancy is only a sufficient but not necessary condition for thread safety; **it is not a necessary and sufficient condition**. A counterexample will be discussed below.

2.Thread-local storage

If variables have been localized so that each thread has its own private copy, then those variables retain their values across subroutines and other code boundaries, and they are thread-safe because they are stored locally for each thread. Even if the code that accesses them may be executed concurrently by another thread, they remain thread-safe.

3.Immutable variables

Once an object is initialized, it cannot be changed. This means that only read-only data is shared, which also provides inherent thread safety. Mutable (non-constant) operations can be implemented by creating new objects for them rather than modifying existing ones. The implementations of strings in Java, C#, and Python use this approach.


#### Category 2 — Thread Synchronization

The first category of methods is relatively simple and can be implemented by refactoring the code. But if you encounter a case where data must be shared between threads, the first category cannot solve it. This is where the second category comes in: using thread synchronization to solve thread-safety problems.

Today, we will start with thread synchronization.


---------------------------------------------


## 1. Thread Synchronization Theory

In multithreaded programs, shared data is often used as the means of passing data between threads. Since a considerable portion of the virtual memory addresses owned by a process can be shared by all threads in that process, most shared data uses memory space as its carrier. If two threads read the same shared memory at the same time but obtain different data, the program can easily run into bugs.

To ensure consistency of shared data, the simplest and most thorough approach is to make the data immutable. Of course, this absolute approach is infeasible in most cases. For example, a function may use a counter to record how many times the function has been called; that counter certainly cannot be made constant. So when something must be a variable, while shared-data consistency still needs to be guaranteed, this leads to the concept of a critical section.


![](https://img.halfrost.com/Blog/ArticleImage/59_2.png)


A critical section exists so that the region can only be accessed or executed serially. A critical section can be a resource or a piece of code. The most effective way to protect a critical section is to use a thread synchronization mechanism.


Let’s first introduce two methods for synchronizing shared data.


### 1. Mutex

The constraint that only one thread is allowed to be inside a critical section at the same time is called mutual exclusion. Before entering the critical section, each thread must first lock a certain object. Only a thread that successfully locks the object is allowed to enter the critical section; otherwise, it will block. This object is called a mutex object, or simply a mutex.


What we usually call a mutex lock in everyday usage can achieve this purpose.

There can be multiple mutexes, and the critical sections they protect can also be multiple. Let’s start with the simple case: one mutex and one critical section.

#### (1) One Mutex and One Critical Section


![](https://img.halfrost.com/Blog/ArticleImage/59_3.png)


The diagram above is an example of one mutex and one critical section. When thread 1 enters the critical section first, the current critical section is unlocked, so it locks the critical section first. Thread 1 obtains the value inside the critical section.

At this point, thread 2 is ready to enter the critical section. Since thread 1 has locked the critical section, thread 2 fails to enter it, and thread 2 transitions from the ready state to the sleeping state. Thread 1 continues writing to the shared data in the critical section.

After thread 1 completes all operations, it calls the unlock operation. Once the critical section is unlocked, the system will attempt to wake up thread 2, which is sleeping. After thread 2 is woken up, it transitions from the sleeping state back to the ready state. Thread 2 prepares to enter the critical section. Since the critical section is now unlocked, thread 2 locks it.

After a series of read and write operations, it will eventually unlock the critical section when leaving it.


When a thread leaves a critical section, it must remember to unlock the corresponding mutex. This gives other threads that were put to sleep because the critical section was locked a chance to be woken up. Therefore, locking and unlocking the same mutex variable must occur in pairs. You must neither repeatedly lock a mutex variable nor unlock a mutex variable multiple times.


![](https://img.halfrost.com/Blog/ArticleImage/59_4.png)


Locking a mutex variable multiple times may cause the critical section to remain blocked forever. Some people may ask: what happens if you unlock an unlocked mutex multiple times?

Before Go 1.8, although unlocking a mutex variable multiple times would not block any goroutine, it could trigger a runtime panic. In versions before Go 1.8, it was possible to attempt to recover from this panic, but after recovery, it could lead to a series of problems. For example, the goroutine that repeatedly performed the unlock operation could become permanently blocked. Therefore, after Go 1.8, this type of runtime panic became unrecoverable. So repeatedly unlocking a mutex variable will cause a runtime operation and eventually make the program exit abnormally.


#### (2) Multiple Mutexes and One Critical Section

In this case, thread deadlock can very easily occur. Therefore, try not to let critical sections protected by different mutexes overlap.

![](https://img.halfrost.com/Blog/ArticleImage/59_5.png)


In the example above, there are two mutexes in one critical section: mutex A and mutex
 B.

Thread 1 first locks mutex A, and then thread 2 locks mutex B. Thread 1 will never release mutex A before successfully locking mutex B. Likewise, thread 2 will never release mutex B before successfully locking mutex A. At this point, both thread 1 and thread 2 cannot lock the mutex they need, so they both transition from the ready state to the sleeping state. This is when thread deadlock occurs.


Thread deadlock can be caused by the following:

- 1.System resource contention    
- 2.Illegal process recommendation order    
- 3.Necessary conditions for deadlock (if any one of these necessary conditions is not satisfied, deadlock will not occur)  
(1). Mutual exclusion condition    
(2). No preemption condition  
(3). Hold-and-wait condition  
(4). Circular wait condition  

To avoid thread deadlock, the following methods can be used:

- 1.Deadlock prevention    
(1). Ordered resource allocation method (break the circular-wait condition)    
(2). Atomic resource allocation method (break the hold-and-wait condition)    

- 2.Deadlock avoidance  
Banker’s algorithm  

- 3.Deadlock detection  
Deadlock theorem (resource-allocation graph reduction method). Although this method can detect deadlocks, it cannot prevent them. After a deadlock is detected, it still needs to be used together with a method for resolving deadlocks.

There are several ways to fully resolve deadlocks:

- 1.Preempt resources  
- 2.Terminate processes  
- 3.Try-lock — back off  
If executing a code block requires locking two variables one after the other (in no fixed order), then after successfully locking one of the mutexes, you should use try-lock to lock the other variable. If trying to lock the second mutex fails, unlock the first mutex that has already been locked, and then retry locking and try-locking the two mutexes.

![](https://img.halfrost.com/Blog/ArticleImage/59_6.png)


As shown above, when thread 2 locks mutex B, it then tries to lock mutex A. At this point the lock attempt fails, so it unlocks mutex B as well. Then thread 1 will lock mutex A. In this case, deadlock will not occur.  
  
- 4.Lock in a fixed order  

![](https://img.halfrost.com/Blog/ArticleImage/59_7.png)


This approach has both thread 1 and thread 2 lock mutexes in the same order: they can only lock mutex 2 after successfully locking mutex 1. This ensures that before one thread completely leaves these overlapping critical sections, no other thread that also needs to lock those mutexes can enter them.

#### (3) Multiple Mutexes and Multiple Critical Sections


![](https://img.halfrost.com/Blog/ArticleImage/59_8.png)


For multiple critical sections and multiple mutexes, you need to check whether there are conflicting regions. If overlapping conflicting regions occur, the thread that enters the critical section later will go into the sleeping state until the thread in that critical section completes its task, and then it will be woken up.

In general, mutexes should be used as sparingly as possible. The critical section protected by each mutex should be within a reasonable scope and as large as possible. However, if you find that multiple threads frequently enter and leave a relatively large critical section, and there are often access conflicts among them, then you should divide that large critical section into smaller ones and protect them with different mutexes. The purpose is to reduce the number of threads waiting to enter the same critical section, thereby lowering the probability that threads are blocked and reducing the time they are forced to spend in the sleeping state. To some extent, this improves the overall performance of the program.

Before discussing another method of thread synchronization, let’s answer the question left at the beginning of the article: reentrancy is only a sufficient but not necessary condition for thread safety, not a necessary and sufficient condition. The counterexample will be discussed below.


The key point of this issue is: **mutex is not reentrant**.


For example:

In the following code, the function increment\_counter is thread-safe, but not reentrant.
```c

#include <pthread.h>

int increment_counter ()
{
	static int counter = 0;
	static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

	pthread_mutex_lock(&mutex);
	
	// only allow one thread to increment at a time
	++counter;
	// store value before any other threads increment it further
	int result = counter;	

	pthread_mutex_unlock(&mutex);
	
	return result;
}


```
In the code above, the function increment\_counter can be called from multiple threads because a mutex, mutex, synchronizes access to the shared variable counter. However, if this function is used in a reentrant interrupt handler, and another interrupt that calls increment\_counter occurs between pthread\_mutex\_lock(&mutex) and pthread\_mutex\_unlock(&mutex), the function will be executed a second time. At that point, because mutex has already been locked, the function will block at pthread\_mutex\_lock(&mutex). Since mutex has no opportunity to be unlocked, the block will last forever. In short, the problem is that a [pthread](https://zh.wikipedia.org/wiki/Pthread) mutex is not reentrant.

The solution is to set the PTHREAD\_MUTEX\_RECURSIVE attribute. However, for the problem at hand, using a dedicated mutex to protect a simple increment operation is clearly too expensive. Therefore, [atomic variables](https://zh.wikipedia.org/w/index.php?title=Atomic_(C%2B%2B%E6%A0%87%E5%87%86%E5%BA%93)&action=edit&redlink=1) in [C++11](https://zh.wikipedia.org/wiki/C%2B%2B11) provide an alternative that makes this function both thread-safe and reentrant—and also more concise:
```c

#include <atomic>

int increment_counter ()
{
	static std::atomic<int> counter(0);
	
	// increment is guaranteed to be done atomically
	int result = ++counter;

	return result;
}

```
In Go, a mutex is represented by the `Mutex` struct in the standard library package `sync`. The `sync.Mutex` type exposes only two pointer methods: `Lock` and `Unlock`. The former is used to lock the current mutex, and the latter is used to unlock it.

### 2. Condition Variables

Among thread synchronization mechanisms, there is another synchronization primitive comparable to a mutex: the condition variable.

Unlike a mutex, a condition variable is not used to ensure that only one thread accesses a piece of shared data at a time. Instead, when the state of the corresponding shared data changes, it notifies other threads that are blocked because of that state. A condition variable is always used together with a mutex.


This kind of problem is actually very common. Let’s use the producer-consumer example first.


If we do not use a condition variable and use only a mutex, let’s see what happens.

Before a producer thread finishes adding an item, no other producer or consumer thread can operate. The same item can also be consumed by only one consumer.

If only a mutex is used, two problems may occur.

- 1.After a producer thread acquires the mutex, it finds that the buffer is full and no new items can be added. So the thread keeps waiting. New producers cannot enter the critical section, and consumers cannot enter either. At this point, a deadlock occurs.

- 2.After a consumer thread acquires the mutex, it finds that the buffer is empty and there is nothing to consume. At this point, the thread also keeps waiting. New producers and consumers are both unable to enter. This also results in a deadlock.

This is the problem that cannot be solved with a mutex alone. Among multiple threads, we urgently need a synchronization mechanism that allows these threads to cooperate.

Condition variables are the familiar P-V operations. This part should be relatively familiar, so we will go through it briefly.


The P operation is the wait operation. It means blocking the current thread until it receives a notification from the condition variable.

The V operation is the signal operation. It means having the condition variable send a notification to at least one thread waiting for it, indicating that the state of some shared data has changed.


Broadcast notification means having the condition variable send notifications to all threads waiting for it, indicating that the state of some shared data has changed.

![](https://img.halfrost.com/Blog/ArticleImage/59_9.png)

signal can be performed multiple times. If it is performed three times, it means three signal notifications have been sent, as shown above.

![](https://img.halfrost.com/Blog/ArticleImage/59_10.png)


The elegance of the P-V operation design lies in the fact that the number of P operations and V operations is the same. However many times wait is called, there are the corresponding number of signal calls. Look at the figure above—this cycle is exactly that fascinating.

#### Producer-Consumer Problem

![](https://img.halfrost.com/Blog/ArticleImage/59_11.png)


This problem can be described visually as shown above: the gatekeeper protects the safety of the critical section. The ticket office records the current value of the semaphore, and it also controls whether the gatekeeper opens the critical section.

![](https://img.halfrost.com/Blog/ArticleImage/59_12.png)

The critical section allows only one thread to enter. When one thread is already inside and another thread arrives, it will be locked out. The ticket office also records the current number of blocked threads.

![](https://img.halfrost.com/Blog/ArticleImage/59_13.png)

After the previous thread leaves, the ticket office tells the gatekeeper to allow one thread to enter the critical section.


Describing the producer-consumer problem using P-V pseudocode:

Initial variables:
```c

semaphore  mutex = 1; // critical-section mutual exclusion semaphore
semaphore  empty = n; // number of free buffers
semaphore  full = 0;  // buffer initialized as empty

```
Producer thread:
```c

producer()
{
  while(1) {
    produce an item in nextp;
    P(empty);
    P(mutex);
    add nextp to buffer;
    V(mutex);
    V(full);
  }
}

```
Consumer thread:
```c


consumer()
{
  while(1) {
    P(full);
    P(mutex);
    remove an item from buffer;
    V(mutex);
    V(empty);
    consume the item;
  }
}

```
Although P and V are not paired within a single producer or consumer routine, across the entire program P and V are still paired.

#### Readers–Writers Problem — Reader Priority, Writer Delay

Readers have priority, and writer processes are delayed. As long as there is a reader currently reading, subsequent readers may freely enter and read as well.

![](https://img.halfrost.com/Blog/ArticleImage/59_14.png)


A reader must first enter `rmutex`, check `readcount`, then modify the value of `readcout`, and finally read the data. For every reader process, it acts as a writer when modifying the value of `readcount`, so a separate `rmutex` is needed to provide mutual exclusion for that access.

Initial variables:
```c

int readcount = 0;     // Number of readers
semaphore  rmutex = 1; // Ensure mutually exclusive updates to readcount
semaphore  wmutex = 1; // Ensure mutually exclusive file access by readers and writers

```
Reader thread:
```c

reader()
{
  while(1) {
    P(rmutex);              // Prepare to enter, modify readcount, “open the door”
    if(readcount == 0) {    // Indicates it is the first reader
      P(wmutex);            // Get the ”key”, preventing writer threads from writing
    }
    readcount ++;
    V(rmutex);
    reading;
    P(rmutex);              // Prepare to leave
    readcount --;
    if(readcount == 0) {    // Indicates it is the last reader
      V(wmutex);            // Hand over the ”key”, allowing writer threads to write
    }
    V(rmutex);              // Leave, “close the door”
  }
}

```
Writer thread:
```c

writer()
{
  while(1) {
    P(wmutex);
    writing;
    V(wmutex);
  }
}

```

#### Readers–Writers Problem — Writer Priority, Reader Delay

When a writer is writing, subsequent readers are forbidden from reading. Readers that arrived before the writer leave after finishing their reads. As long as any writer is waiting, later readers are forbidden from entering to read.


![](https://img.halfrost.com/Blog/ArticleImage/59_15.png)


Initial variables:
```c

int readcount = 0;     // reader count
semaphore  rmutex = 1; // ensure mutual exclusion when updating readcount
semaphore  wmutex = 1; // ensure mutually exclusive file access for readers and writers
semaphore  w = 1;      // used to implement “writer priority”

```
Reader thread:
```c

reader()
{
  while(1) {
    P(w);                   // can request entry only when there is no writer
    P(rmutex);              // prepare to enter, modify readcount, “open the door”
    if(readcount == 0) {    // indicates this is the first reader
      P(wmutex);            // take the ”key”, prevent writer thread from writing
    }
    readcount ++;
    V(rmutex);
    V(w);
    reading;
    P(rmutex);              // prepare to leave
    readcount --;
    if(readcount == 0) {    // indicates this is the last reader
      V(wmutex);            // hand over the ”key”, let writer thread write
    }
    V(rmutex);              // leave, “close the door”
  }
}

```
Writer thread:
```c

writer()
{
  while(1) {
    P(w);
    P(wmutex);
    writing;
    V(wmutex);
    V(w);
  }
}

```

#### Dining Philosophers Problem


Suppose five philosophers are seated around a circular dining table and do one of two things: eat or think. While eating, they stop thinking; while thinking, they stop eating. In the middle of the table is a large bowl of spaghetti, and there is one fork between each pair of philosophers. Because it is difficult to eat spaghetti with a single fork, assume that each philosopher must use two forks to eat. They may use only the two forks to their immediate left and right. The dining philosophers problem is sometimes described using rice and chopsticks instead of spaghetti and forks, because it is obvious that eating rice requires two chopsticks.

![](https://img.halfrost.com/Blog/ArticleImage/59_16.png)


Initial variables:
```c

semaphore  chopstick[5] = {1,1,1,1,1}; // Initialize semaphores
semaphore  mutex = 1;                  // Set the semaphore for picking up chopsticks

```
Philosopher thread:
```c

Pi()
{
  do {
    P(mutex);                     // acquire the mutex for picking up chopsticks
    P(chopstick[i]);              // pick up the left chopstick
    P(chopstick[ (i + 1) % 5 ]);  // pick up the right chopstick
    V(mutex);                     // release the semaphore for picking up chopsticks
    eat;
    V(chopstick[i]);              // put down the left chopstick
    V(chopstick[ (i + 1) % 5 ]);  // put down the right chopstick
    think;
  }while(1);
}

```
In summary, a mutex can protect critical sections and prevent race conditions. Condition variables, as a complementary mechanism, can make collaboration among multiple parties more efficient.

In Go’s standard library, the `sync.Cond` type in the `sync` package represents a condition variable. However, unlike mutexes and read-write locks, a simple declaration cannot create a usable condition variable; you also need to use the `sync.NewCond` function.
```go

func NewCond( l locker) *Cond

```
\*The method set of the `sync.Cond` type contains three methods: `Wait`, `Signal`, and `Broadcast`.

## II. A Simple Thread-Locking Approach

The simplest way to implement thread safety is to use locks.

First, let’s look at how to implement a thread-safe dictionary in OC.

The Weex source code implements a thread-safe dictionary. The class is named `WXThreadSafeMutableDictionary`.
```objectivec

/**
 *  @abstract Thread safe NSMutableDictionary
 */
@interface WXThreadSafeMutableDictionary<KeyType, ObjectType> : NSMutableDictionary
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableDictionary* dict;
@end

```
The specific implementation is as follows:
```objectivec

- (instancetype)initCommon
{
    self = [super init];
    if (self) {
        NSString* uuid = [NSString stringWithFormat:@"com.taobao.weex.dictionary_%p", self];
        _queue = dispatch_queue_create([uuid UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

```
When this thread-safe dictionary is initialized, it creates a new concurrent queue.
```objectivec

- (NSUInteger)count
{
    __block NSUInteger count;
    dispatch_sync(_queue, ^{
        count = _dict.count;
    });
    return count;
}

- (id)objectForKey:(id)aKey
{
    __block id obj;
    dispatch_sync(_queue, ^{
        obj = _dict[aKey];
    });
    return obj;
}

- (NSEnumerator *)keyEnumerator
{
    __block NSEnumerator *enu;
    dispatch_sync(_queue, ^{
        enu = [_dict keyEnumerator];
    });
    return enu;
}

- (id)copy{
    __block id copyInstance;
    dispatch_sync(_queue, ^{
        copyInstance = [_dict copy];
    });
    return copyInstance;
}

```
All of these read methods use dispatch\_sync.
```objectivec

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey
{
    aKey = [aKey copyWithZone:NULL];
    dispatch_barrier_async(_queue, ^{
        _dict[aKey] = anObject;
    });
}

- (void)removeObjectForKey:(id)aKey
{
    dispatch_barrier_async(_queue, ^{
        [_dict removeObjectForKey:aKey];
    });
}

- (void)removeAllObjects{
    dispatch_barrier_async(_queue, ^{
        [_dict removeAllObjects];
    });
}


```
Use `dispatch_barrier_async` for all write-related methods.

Now let’s look at how to implement a simple thread-safe Map in Go using a mutex.

Since we need to use a mutex, we’ll wrap a Map that contains one.
```go

type MyMap struct {
    sync.Mutex
    m map[int]int
}

var myMap *MyMap

func init() {
    myMap = &MyMap{
        m: make(map[int]int, 100),
    }
}

```
Then simply implement the basic methods of Map.
```go

func builtinMapStore(k, v int) {
    myMap.Lock()
    defer myMap.Unlock()
    myMap.m[k] = v
}

func builtinMapLookup(k int) int {
    myMap.Lock()
    defer myMap.Unlock()
    if v, ok := myMap.m[k]; !ok {
        return -1
    } else {
        return v
    }
}

func builtinMapDelete(k int) {
    myMap.Lock()
    defer myMap.Unlock()
    if _, ok := myMap.m[k]; !ok {
        return
    } else {
        delete(myMap.m, k)
    }
}


```
The implementation idea is fairly simple: add a lock before every operation, and add an unlock in a `defer` at the end of every function.

A thread-safe dictionary implemented with this locking approach has the advantage of being simple, but the disadvantage is poor performance. At the end of the article, we will compare the performance of several implementation approaches. The numbers will make it clear just how poor the performance of this mutex-based locking approach is.

In languages that provide a native thread-safe Map, their underlying native implementations do not achieve thread safety simply by locking. Examples include Java’s ConcurrentHashMap and the `sync.map` added in Go 1.9.

## III. Modern Thread-Safe Lock-Free Approach: CAS

The underlying implementation of Java’s ConcurrentHashMap makes extensive use of lock-free techniques such as `volatile`, `final`, and CAS to reduce the impact of lock contention on performance.

Atomic operations are also widely used in Go, and CAS is one of them. Compare-and-swap, abbreviated as CAS, means “Compare And Swap.”
```go

func CompareAndSwapInt32(addr *int32, old, new int32) (swapped bool)

func CompareAndSwapInt64(addr *int64, old, new int64) (swapped bool)

func CompareAndSwapUint32(addr *uint32, old, new uint32) (swapped bool)

func CompareAndSwapUint64(addr *uint64, old, new uint64) (swapped bool)

func CompareAndSwapUintptr(addr *uintptr, old, new uintptr) (swapped bool)

func CompareAndSwapPointer(addr *unsafe.Pointer, old, new unsafe.Pointer) (swapped bool)

```
CAS first checks whether the target value pointed to by the parameter `addr` is equal to the value of the parameter `old`. If they are equal, the corresponding function replaces the old value with the new value represented by the parameter `new`. Otherwise, the replacement operation is ignored.

![](https://img.halfrost.com/Blog/ArticleImage/59_17.png)


This is clearly different from a mutex. CAS always assumes that the target value has not changed, and once it confirms that this assumption holds, it immediately performs the value replacement. A mutex, by contrast, takes a more cautious approach: it always assumes that concurrent operations may modify the target value, and therefore uses a lock to protect the relevant operations inside a critical section. In other words, the mutex approach is pessimistic, while the CAS approach is optimistic, similar to optimistic locking.

The biggest advantage of CAS is that it can perform concurrency-safe value replacement without creating a mutex or a critical section. This greatly reduces the impact of thread synchronization operations on program performance. Of course, CAS also has some drawbacks, which will be discussed in the next chapter.

Next, let’s look at how this is implemented in the source code. The following uses 64-bit as an example; 32-bit is similar.
```c

TEXT ·CompareAndSwapUintptr(SB),NOSPLIT,$0-25
	JMP	·CompareAndSwapUint64(SB)

TEXT ·CompareAndSwapInt64(SB),NOSPLIT,$0-25
	JMP	·CompareAndSwapUint64(SB)

TEXT ·CompareAndSwapUint64(SB),NOSPLIT,$0-25
	MOVQ	addr+0(FP), BP
	MOVQ	old+8(FP), AX
	MOVQ	new+16(FP), CX
	LOCK
	CMPXCHGQ	CX, 0(BP)
	SETEQ	swapped+24(FP)
	RET

```
The most critical step in the implementation above is CMPXCHG.


Looking up Intel's [documentation](http://x86.renejeschke.de/html/file_module_x86_id_41.html):


![](https://img.halfrost.com/Blog/ArticleImage/59_18.png)

The documentation says:

Compare the value in eax with the destination operand (the first operand). If they are equal, the ZF flag is set, and the value of the source operand (the second operand) is written to the destination operand. Otherwise, the ZF flag is cleared, and the value of the destination operand is written back to eax.

This gives us the operating principle of CMPXCHG:

Compare the values of \_old and (\*\_\_ptr). If they are equal, the ZF flag is set, and the value of
 \_new is written to (\*\_\_ptr). Otherwise, the ZF flag is cleared, and the value of (\*\_\_ptr) is written back to \_old.


On Intel platforms, this is implemented with LOCK CMPXCHG, where LOCK is a CPU lock.


Intel's manual describes the LOCK prefix as follows:

- 1.Ensures that read-modify-write operations on memory are executed atomically. On Pentium and earlier processors, an instruction with the LOCK prefix locks the bus while it executes, temporarily preventing other processors from accessing memory through the bus. Obviously, this is expensive. Starting with Pentium 4, Intel Xeon, and P6 processors, Intel introduced a meaningful optimization on top of the original bus lock: if the memory area to be accessed is already locked in the processor's internal cache while the LOCK-prefixed instruction executes (that is, the cache line containing that memory area is currently in the exclusive or modified state), and that memory area is fully contained within a single cache line, then the processor executes the instruction directly. Because the cache line remains locked for the duration of the instruction execution, other processors cannot read or write the memory area accessed by the instruction, thereby guaranteeing atomicity. This process is called cache locking. Cache locking greatly reduces the execution overhead of LOCK-prefixed instructions, but when contention among multiple processors is high or the memory address accessed by the instruction is unaligned, the bus will still be locked.  
- 2.Prevents this instruction from being reordered with preceding and following read and write instructions.  
- 3.Flushes all data in the write buffer to memory.


From this description, we can see that CPU locks mainly fall into two categories: bus locks and cache locks. Bus locks are used on older CPUs, while cache locks are used on newer CPUs.

![](https://img.halfrost.com/Blog/ArticleImage/59_19.png)


A so-called bus lock uses a LOCK# signal provided by the CPU. When a processor outputs this signal on the bus, requests from other processors are blocked, allowing that CPU to use shared memory exclusively. With bus locking, the bus is locked during execution, so other processors temporarily cannot access memory through the bus. Therefore, bus locking is relatively expensive. In certain scenarios, modern processors optimize this by using cache locking instead of bus locking.


![](https://img.halfrost.com/Blog/ArticleImage/59_20.png)


Cache locking means that if the memory area cached in a processor cache line is locked during a LOCK operation, then when the lock operation writes back to memory, the processor does not generate a
LOCK# signal on the bus. Instead, it modifies the internal memory address and relies on its cache-coherency mechanism to guarantee atomicity. This is because the cache-coherency mechanism prevents simultaneous modification of memory-region data cached by more than one processor; when another processor writes back data from a locked cache line, that cache line is invalidated.


There are two cases in which the processor cannot use cache locking.

- The first case is when the data being operated on cannot be cached inside the processor, or when the data spans multiple cache lines. In that case, the processor falls back to bus locking.

- The second case is that some processors do not support cache locking. Some older CPUs will use bus locking even if the locked memory area is in a processor cache line.

Although cache locking can greatly reduce the execution overhead of CPU locks, if contention among multiple processors is high or the memory address accessed by the instruction is unaligned, the bus will still be locked. Therefore, cache locking and bus locking work best when used together.

In summary, using CAS to ensure thread safety is much more efficient than using a mutex.

## 4. Drawbacks of CAS

Although CAS is efficient, it still has three major issues.

### 1. The ABA Problem

![](https://img.halfrost.com/Blog/ArticleImage/59_21.png)


Thread 1 is preparing to use CAS to replace the variable's value from A to B. Before that happens, thread 2 changes the variable's value from A to C, and then from C back to A. When thread 1 executes CAS, it finds that the variable's value is still A, so the CAS succeeds. But in reality, the state at this point is no longer the same as it was initially. In the diagram, the two A values are intentionally marked with different colors to distinguish them. Ultimately, thread 2 replaces A with B. This is the classic ABA problem. But what kind of issue can this cause in a project?


![](https://img.halfrost.com/Blog/ArticleImage/59_22.png)


Imagine such a linked-list stack: the stack stores a linked list, the top of the stack is A, and A's next pointer points to B. In thread 1, we want to use CAS to replace the stack-top element A with B. Then thread 2 comes along and pops out the linked list that previously contained elements A and B. After that, it pushes in an A - C - D linked list, so the stack-top element is still A. At this point, thread 1 observes that A has not changed, so it replaces it with B. But now B's next is actually nil. After the replacement completes, the C - D linked list operated on by thread 2 is disconnected from the list head. In other words, once thread 1's CAS operation finishes, C - D is lost and can never be recovered. The stack is left with only one element, B. This is clearly a bug.


So how do we solve this situation? The most common approach is to add a version number as an identifier.


![](https://img.halfrost.com/Blog/ArticleImage/59_23.png)


Add a version number to every operation, and the ABA problem can be solved cleanly.


### 2. The Loop May Run for Too Long

![](https://img.halfrost.com/Blog/ArticleImage/59_24.png)


If a spinning CAS fails for a long time, it can impose very high execution overhead on the CPU. If the CPU-provided Pause instruction is supported, CAS efficiency can be improved to some extent. The Pause instruction has two effects. First, it can delay pipeline instruction execution (de-pipeline), so the CPU does not consume excessive execution resources. The duration of the delay depends on the specific implementation; on some processors, the delay is zero. Second, it can avoid a CPU pipeline flush caused by a memory order violation when exiting the loop, thereby improving CPU execution efficiency.


### 3. It Can Only Guarantee Atomic Operations on a Single Shared Variable


A CAS operation can only guarantee atomic operations on a single shared variable; it cannot guarantee the atomicity of operations on multiple shared variables. The typical approach is usually to consider using a lock.


![](https://img.halfrost.com/Blog/ArticleImage/59_25.png)


However, you can also use a struct to merge two variables into a single variable. This allows you to continue using CAS to guarantee atomic operations.


## 5. Lock-Free Design Examples


Before looking at Lock-Free design examples, let's first review the mutex-based design. Above, we used a mutex to implement a thread-safe Map in Go. As for the performance of this Map, we can look at the numbers in the comparison that follows.

### 1. A Non-Lock-Free Design

If we do not use a Lock-Free design, and we also do not use a simple mutex-based design, how can we implement a thread-safe dictionary? The answer is to use a segmented-lock design. Race conditions exist only within the same segment, and there is no lock contention between different segment locks. Compared with a design that locks the entire
Map, segmented locking greatly improves processing capability in high-concurrency environments.
```go


type ConcurrentMap []*ConcurrentMapShared


type ConcurrentMapShared struct {
	items        map[string]interface{}
	sync.RWMutex // read-write lock, ensures thread-safe access to the internal map
}

```
A segmented lock Segment has a concurrency level. The concurrency level can be understood as the maximum number of threads that can update `ConccurentMap` simultaneously at runtime without causing lock contention; in practice, it is the number of segmented locks in `ConcurrentMap`—that is, the length of the array.
```go

var SHARD_COUNT = 32

```
If the concurrency level is set too low, it can cause severe lock contention. If it is set too high, accesses that would originally fall within the same Segment will be spread across different Segments, reducing the CPU cache hit rate and thereby degrading program performance.

![](https://img.halfrost.com/Blog/ArticleImage/59_26.png)


Initializing a ConcurrentMap means initializing the array, as well as each dictionary in that array.
```go

func New() ConcurrentMap {
	m := make(ConcurrentMap, SHARD_COUNT)
	for i := 0; i < SHARD_COUNT; i++ {
		m[i] = &ConcurrentMapShared{items: make(map[string]interface{})}
	}
	return m
}

```
ConcurrentMap primarily uses Segment to reduce lock granularity, splitting the Map into multiple Segments. When performing a put, it needs to acquire a write lock; when performing a get, it only acquires a read lock.


Since the Map is segmented, the logic for determining which segment each key belongs to is handled by a hash function.
```go

func fnv32(key string) uint32 {
	hash := uint32(2166136261)
	const prime32 = uint32(16777619)
	for i := 0; i < len(key); i++ {
		hash *= prime32
		hash ^= uint32(key[i])
	}
	return hash
}


```
The hash function above computes a different hash value based on each `string` passed in.
```go

func (m ConcurrentMap) GetShard(key string) *ConcurrentMapShared {
	return m[uint(fnv32(key))%uint(SHARD_COUNT)]
}

```
Take the hash value modulo the array length to obtain the `ConcurrentMapShared` in the `ConcurrentMap`. The `ConcurrentMapShared` stores the key \- value pairs corresponding to that segment.
```go


func (m ConcurrentMap) Set(key string, value interface{}) {
	// Get map shard.
	shard := m.GetShard(key)
	shard.Lock()
	shard.items[key] = value
	shard.Unlock()
}

```
The snippet above is the `set` operation for `ConcurrentMap`. The idea is straightforward: first retrieve the corresponding `ConcurrentMapShared` within the shard, then acquire the read-write lock, write the key \- value pair, and release the read-write lock after the write succeeds.
```go

func (m ConcurrentMap) Get(key string) (interface{}, bool) {
	// Get shard
	shard := m.GetShard(key)
	shard.RLock()
	// Get item from shard.
	val, ok := shard.items[key]
	shard.RUnlock()
	return val, ok
}

```
The snippet above is the `get` operation of `ConcurrentMap`. The idea is straightforward: first retrieve the corresponding `ConcurrentMapShared` within the segment, then acquire a read lock, read the key-value pair, and release the read lock after the read succeeds.

The difference from the `set` operation is that only a read lock is needed here; there is no need to acquire a read-write lock.
```go

func (m ConcurrentMap) Count() int {
	count := 0
	for i := 0; i < SHARD_COUNT; i++ {
		shard := m[i]
		shard.RLock()
		count += len(shard.items)
		shard.RUnlock()
	}
	return count
}


```
The `Count` operation of `ConcurrentMap` traverses every element in each segment of the `ConcurrentMap` array and computes the total count.
```go

func (m ConcurrentMap) Keys() []string {
	count := m.Count()
	ch := make(chan string, count)
	go func() {
		// Iterate over all shards.
		wg := sync.WaitGroup{}
		wg.Add(SHARD_COUNT)
		for _, shard := range m {
			go func(shard *ConcurrentMapShared) {
				// Iterate over all key-value pairs.
				shard.RLock()
				for key := range shard.items {
					ch <- key
				}
				shard.RUnlock()
				wg.Done()
			}(shard)
		}
		wg.Wait()
		close(ch)
	}()

	// Generate the keys slice to store all keys
	keys := make([]string, 0, count)
	for k := range ch {
		keys = append(keys, k)
	}
	return keys
}

```
The above returns all keys in the `ConcurrentMap`, with the result stored in a string array.
```go


type UpsertCb func(exist bool, valueInMap interface{}, newValue interface{}) interface{}

func (m ConcurrentMap) Upsert(key string, value interface{}, cb UpsertCb) (res interface{}) {
	shard := m.GetShard(key)
	shard.Lock()
	v, ok := shard.items[key]
	res = cb(ok, v, value)
	shard.items[key] = res
	shard.Unlock()
	return res
}

```
The code above is an Upsert operation. If the element already exists, it updates it. If it is a new element, it inserts a new one using the UpsertCb function. The idea is also to first locate the corresponding segment based on the string, and then acquire the read-write lock. Here, only a read-write lock can be used, because whether it is an update or an insert operation, writing is required. Read the value corresponding to the key, then call the UpsertCb function, and update the result into the value corresponding to the key. Finally, release the read-write lock.

One thing worth noting about the UpsertCb function here is that this function is a callback that returns the new element to be inserted into the map. This function is called if and only if the read-write lock is held, so it must not attempt to read other key values from the same map again. Doing so would cause a thread deadlock. The reason for the deadlock is that `sync.RWLock` in Go is not reentrant.

The complete code is available in [concurrent_map.go](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_map_bench_test/concurrent-map/concurrent_map.go)

Although this segmentation approach is much better than simply adding a mutex, because Segment further reduces the locked scope, that scope is still relatively large. Can the lock scope be reduced even further?

Another point is that the concurrency level must be set reasonably: it should be neither too large nor too small.

### 2. Lock-Free Approach

In Go 1.9, a thread-safe Map was implemented by default. It abandoned the concept of Segment (segmented locks) and instead adopted an entirely new implementation based on the CAS algorithm, namely a Lock-Free approach.

After adopting the Lock-Free approach, the lock scope can be reduced even further compared with the previous segmented-lock approach. Performance is greatly improved.

Next, let’s look at how to use CAS to implement a thread-safe, high-performance Map.

The official documentation describes `sync.Map` as follows:

>This Map is thread-safe, and reads, inserts, and deletes all maintain constant-time complexity. It is also thread-safe for multiple goroutines to call Map methods concurrently. The zero value of this Map is valid, and the zero value is an empty Map. A thread-safe Map must not be copied after its first use.


Here is an explanation of why it cannot be copied. Copying a struct not only creates a copy of the value itself, but also creates copies of its fields. As a result, the concurrency-safety protection that should have applied to it becomes ineffective.

Assigning it as a source value to another variable, passing it into a function as an argument value, returning it from a function as a result value, or transmitting it through a channel as an element value can all cause the value to be copied. The correct approach is to use a variable of a pointer type pointing to that type.


The data structure of `sync.Map` in Go 1.9 is as follows:
```go


type Map struct {

	mu Mutex

	// Concurrently reading part of the map is thread-safe; this does not require
	// read itself is thread-safe to read because it is atomic. However, storing still requires Mutex
	// Entries stored in read may be updated during concurrent reads, and are thread-safe even without the Mutex semaphore. But updating a previously deleted entry requires copying the value to the dirty Map, and must use Mutex
	read atomic.Value // readOnly

	// dirty contains the part of the map that must be protected by the mutex mu to be thread-safe. To allow dirty to be quickly converted into the read map, dirty contains all entries in the read map that have not been deleted
	// Deleted entries are not stored in the dirty map. In the clean map, a deleted entry must not have been deleted before, and when a new value is about to be stored, they are added to the dirty map.
	// When the dirty map is nil, the next write initializes it from a shallow copy of the clean map, omitting old entries.
	dirty map[interface{}]*entry

	// misses records the number of loads for which the read map had to lock the mutex mu and perform an update to determine whether the key exists.
	// Once misses is large enough to justify the cost of copying the dirty map, the dirty map is promoted to the read map in an unmodified state, and the next store will create a new dirty map.
	misses int
}


```
In this Map, there is a mutex `mu`, an atomic value `read`, and a non-thread-safe dictionary `map`. The dictionary’s key is of type `interface{}`, and its value is of type `*entry`. Finally, there is also an `int` counter.

Let’s first talk about the atomic value. The `atomic.Value` type has two exported pointer methods: `Load` and `Store`. The `Load` method is used to atomically read the value stored in an atomic value instance. It returns a result of type `interface{}` and does not accept any parameters. The `Store` method is used to atomically store a value in an atomic value instance. It accepts a parameter of type `interface{}` and returns no result. Before any value has been stored into an atomic value instance via the `Store` method, its `Load` method will always return `nil`.

In this thread-safe dictionary, both `Load` and `Store` operate on a `readOnly` data structure.
```go

// readOnly is an immutable struct, atomically stored in Map.read
type readOnly struct {
	m map[interface{}]*entry
	// indicates whether the dirty map contains any keys not in m.
	amended bool // true if the dirty map contains some key not in m.
}

```
`readOnly` stores a non-thread-safe dictionary whose type is exactly the same as the `dirty map` above. The key is of type `interface{}`, and the value is of type `*entry`.
```go

// entry is a slot corresponding to a specific key in the map
type entry struct {
	p unsafe.Pointer // *interface{}
}

```
The `p` pointer points to a `*interface{}` type, which stores the address of an `entry`. If `p == nil`, it means the `entry` has been deleted and `m.dirty == nil`. If `p == expunged`, it means the `entry` has been deleted and `m.dirty != nil`, so the `entry` is missing from `m.dirty`.

Aside from the two cases above, the `entry` is valid and is recorded in `m.read.m[key]`. If `m.dirty != nil`, the `entry` is stored in `m.dirty[key]`.

An `entry` can be deleted by atomically replacing it with `nil`. When `m.dirty` is created the next time, the `entry` will be atomically replaced from `nil` to the `expunged` pointer, and `m.dirty[key]` will not correspond to any value. As long as `p != expunged`, an `entry` can update its associated value via an atomic replacement operation. If `p == expunged`, then for an `entry` to update its associated value via an atomic replacement operation, it can only do so after `m.dirty[key] = e` has been set for the first time. This is done so that it can be found in the dirty map.


So from the analysis above, we can see that the keys in `read` are read-only (the set of keys does not change; deletion only marks them). All operations on values can be completed atomically, so this structure does not need locking. `dirty` is a copy of `read`, and all operations that require locking happen here, such as adding elements and deleting elements. (A delete operation performed on `dirty` is a real deletion.) The specific operations are analyzed below.


![](https://img.halfrost.com/Blog/ArticleImage/59_27.png)


To summarize, the data structure of `sync.map` is shown above.

Now let’s look at some operations of the thread-safe `sync.map`.
```go

func (m *Map) Load(key interface{}) (value interface{}, ok bool) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	// If the value for key does not exist and the dirty map contains keys not in the read map, start reading the dirty map 
	if !ok && read.amended {
		// The dirty map is not thread-safe, so a mutex is needed
		m.mu.Lock()
		// When m.dirty is promoted, lock here to avoid a false miss.
		// If reading the same key again does not miss, this key's value is not worth copying to the dirty map.
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			e, ok = m.dirty[key]
			// Record this miss regardless of whether the entry exists.
			// This key will take the slow path until the dirty map is promoted to the read map
			m.missLocked()
		}
		m.mu.Unlock()
	}
	if !ok {
		return nil, false
	}
	return e.load()
}

```
The code above is the `Load` operation. It returns the value corresponding to the input key. If the value does not exist, it returns nil. The `dirty` map may contain some keys that are not present in the `read` map, so the value corresponding to the key must be read from the `dirty` map. Note that a mutex must be acquired when reading, because the `dirty` map is not thread-safe.
```go

func (m *Map) missLocked() {
	m.misses++
	if m.misses < len(m.dirty) {
		return
	}
	m.read.Store(readOnly{m: m.dirty})
	m.dirty = nil
	m.misses = 0
}

```
The code above records the number of misses. Only when the number of misses exceeds the length of the dirty map will the dirty map be stored into the read map. Then dirty is set to nil, and the miss count is reset.

Before looking at the Store operation, let’s first discuss the expunged variable.
```go

// expunged is a pointer to an arbitrary type, used to mark entries deleted from the dirty map
var expunged = unsafe.Pointer(new(interface{}))


```
The `expunged` variable is a pointer used to mark an entry deleted from the dirty map.
```go

func (m *Map) Store(key, value interface{}) {
	read, _ := m.read.Load().(readOnly)
	// If reading key from the read map fails or trying to store value in the retrieved entry fails, return directly
	if e, ok := read.m[key]; ok && e.tryStore(&value) {
		return
	}

	m.mu.Lock()
	read, _ = m.read.Load().(readOnly)
	if e, ok := read.m[key]; ok {
		// e points to a non-nil value
		if e.unexpungeLocked() {
			// entry was previously deleted, which means there is a non-empty dirty map that does not store this entry
			m.dirty[key] = e
		}
		// Before using storeLocked, ensure e has not been expunged
		e.storeLocked(&value)
	} else if e, ok := m.dirty[key]; ok {
		// Already stored in the dirty map, so e has not been expunged
		e.storeLocked(&value)
	} else {
		if !read.amended {
			// Reaching this else means the current key is being added to the dirty map for the first time.
			// Before storing, first check whether the dirty map is empty; if it is, shallow-copy the read map.
			m.dirtyLocked()
			m.read.Store(readOnly{m: read.m, amended: true})
		}
		// Store value in dirty
		m.dirty[key] = newEntry(value)
	}
	m.mu.Unlock()
}


```
`Store` first attempts to read the key from the read map, then stores its value. If the entry is marked as having been deleted from the dirty map, it also needs to be stored back into the dirty map.

If the corresponding key does not exist in the read map, it reads from the dirty map. The dirty map directly stores the corresponding value.

Finally, if neither the read map nor the dirty map contains this key, it means the key is being added to the dirty map for the first time. Store the key and its corresponding value in the dirty map.
```go

// Store a value when entry has not been deleted.
// If entry has been deleted, tryStore returns false and leaves entry unchanged
func (e *entry) tryStore(i *interface{}) bool {
	p := atomic.LoadPointer(&e.p)
	if p == expunged {
		return false
	}
	for {
		if atomic.CompareAndSwapPointer(&e.p, p, unsafe.Pointer(i)) {
			return true
		}
		p = atomic.LoadPointer(&e.p)
		if p == expunged {
			return false
		}
	}
}

```
The implementation of the `tryStore` function is similar to the CAS principle. It repeatedly loops to check whether the `entry` has been marked as `expunged`. If the `entry` is successfully replaced with `i` via a CAS operation, it returns `true`; conversely, if it has been marked as `expunged`, it returns `false`.
```go


// unexpungeLocked ensures that entry is not marked as expunged.
// If entry was previously expunged, it must be added to the dirty map before the mutex is unlocked.
func (e *entry) unexpungeLocked() (wasExpunged bool) {
	return atomic.CompareAndSwapPointer(&e.p, expunged, nil)
}

```
If `entry`'s `unexpungeLocked` returns `true`, it means the `entry` has already been marked as `expunged`, so it will use a CAS operation to set it to `nil`.

Now let's look at the implementation of the delete operation.
```go

func (m *Map) Delete(key interface{}) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	if !ok && read.amended {
		// Since the dirty map is not thread-safe, lock before operating
		m.mu.Lock()
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			// Delete the key from the dirty map
			delete(m.dirty, key)
		}
		m.mu.Unlock()
	}
	if ok {
		e.delete()
	}
}

```
The implementation of the `delete` operation is relatively straightforward. If the key exists in the read map, it can be deleted directly. If the key does not exist there but does exist in the dirty map, then that key needs to be deleted from the dirty map. When operating on the dirty map, remember to acquire the lock first for protection.
```go

func (e *entry) delete() (hadValue bool) {
	for {
		p := atomic.LoadPointer(&e.p)
		if p == nil || p == expunged {
			return false
		}
		if atomic.CompareAndSwapPointer(&e.p, p, nil) {
			return true
		}
	}
}

```
The concrete implementation for deleting an entry is shown above. All operations in this process are atomic. The loop checks whether the entry is `nil` or has already been marked as `expunged`; if so, it returns `false`, indicating that the deletion failed. Otherwise, it performs a CAS operation, sets the entry’s `p` pointer to `nil`, and returns `true`, indicating that the deletion succeeded.


At this point, the implementation of Go 1.9’s built-in thread-safe `sync.map` has been fully analyzed. The official implementation basically does not use locks; even the mutex `lock` is based on CAS. The `read` map is also atomic. Therefore, compared with the earlier lock-based implementation, its performance is improved.


If a key in `read` is deleted—that is, marked as `expunged`—and the same key is added again later, there is no need to operate on `dirty`; it can simply be restored.

If `dirty` contains no data, and a key in `read` is deleted, it is likewise marked as `expunged`. Then, if a different key is added, the `dirtyLocked()` function copies all existing key-value pairs from `read` into `dirty`, and then appends the newly added key from `read`, which is different from the previously deleted key.

This is equivalent to:

When `dirty` does not exist, `read` contains all the map data.  
When `dirty` exists, `dirty` is the correct map data.   


From the implementation of `sync.map`, we can see that its core idea is lock-free reads. Most operations on a map are reads, and multiple readers can proceed without locks. When misses in `read` reach a certain threshold (somewhat like cache hits/misses), it considers directly replacing `read` with `dirty`; this is just a single assignment replacement. However, when `dirty` is regenerated, or when the first `dirty` is created, it still needs to traverse the entire `read`, which can be quite expensive. So what is the actual performance of the official `sync.map`?


How strong is Lock \- Free performance, really? Next, let’s run some performance tests.


## V. Performance Comparison

The performance tests mainly focus on three aspects: Insert, Get, and Delete. The test subjects are mainly three types: the native Map with a simple mutex, the sharded-lock Map, and the Lock \- Free Map.

All the code for the performance tests has been put on GitHub, at [this link](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_map_bench_test/concurrent-map/concurrent_map_bench_test.go). The command used for the performance tests is:
```go

go test -v -run=^$ -bench . -benchmem

```

### 1. Insert Performance Test
```go

// Insert absent key (coarse lock)
func BenchmarkSingleInsertAbsentBuiltInMap(b *testing.B) {
	myMap = &MyMap{
		m: make(map[string]interface{}, 32),
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		myMap.BuiltinMapStore(strconv.Itoa(i), "value")
	}
}

// Insert absent key (sharded lock)
func BenchmarkSingleInsertAbsent(b *testing.B) {
	m := New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Set(strconv.Itoa(i), "value")
	}
}

// Insert absent key (syncMap)
func BenchmarkSingleInsertAbsentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Store(strconv.Itoa(i), "value")
	}
}

```
Test results:
```go

BenchmarkSingleInsertAbsentBuiltInMap-4     	 2000000	       857 ns/op	     170 B/op	       1 allocs/op
BenchmarkSingleInsertAbsent-4               	 2000000	       651 ns/op	     170 B/op	       1 allocs/op
BenchmarkSingleInsertAbsentSyncMap-4        	 1000000	      1094 ns/op	     187 B/op	       5 allocs/op

```
The experimental results show that the segmented-lock implementation has the best performance. To explain the test results: `\-4` means the test used 4 CPU cores; `2000000` represents the number of iterations; `857 ns/op` represents the average time spent per execution; `170 B/op` represents the total amount of heap memory allocated per execution; and `allocs/op` represents the number of heap allocations per execution.


![](https://img.halfrost.com/Blog/ArticleImage/59_28.png)


From this perspective, the more iterations, the less time spent, the smaller the total allocated memory, and the fewer allocation operations, the better the performance. In the performance charts below, the first column—the iteration count—is omitted, and only the remaining three metrics are plotted. Therefore, the shorter the bar chart, the better the performance. The rules for each bar chart below and the meaning of the test results are the same as described here, so they will not be repeated.
```go

// Insert existing key (coarse-grained lock)
func BenchmarkSingleInsertPresentBuiltInMap(b *testing.B) {
	myMap = &MyMap{
		m: make(map[string]interface{}, 32),
	}
	myMap.BuiltinMapStore("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		myMap.BuiltinMapStore("key", "value")
	}
}

// Insert existing key (segmented lock)
func BenchmarkSingleInsertPresent(b *testing.B) {
	m := New()
	m.Set("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Set("key", "value")
	}
}

// Insert existing key (syncMap)
func BenchmarkSingleInsertPresentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	syncMap.Store("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Store("key", "value")
	}
}


```
Test result:
```go

BenchmarkSingleInsertPresentBuiltInMap-4    	20000000	        74.6 ns/op	       0 B/op	       0 allocs/op
BenchmarkSingleInsertPresent-4              	20000000	        61.1 ns/op	       0 B/op	       0 allocs/op
BenchmarkSingleInsertPresentSyncMap-4       	20000000	       108 ns/op	      16 B/op	       1 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_29.png)


As can be seen from the figure, `sync.map` performs worse than the other two in all cases involving `Store`. Whether inserting a non-existent `Key` or an existing `Key`, the sharded-lock implementation currently delivers the best performance.


### 2. Read Get Performance Test
```go

// Read existing key (coarse lock)
func BenchmarkSingleGetPresentBuiltInMap(b *testing.B) {
	myMap = &MyMap{
		m: make(map[string]interface{}, 32),
	}
	myMap.BuiltinMapStore("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		myMap.BuiltinMapLookup("key")
	}
}

// Read existing key (sharded lock)
func BenchmarkSingleGetPresent(b *testing.B) {
	m := New()
	m.Set("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Get("key")
	}
}

// Read existing key (syncMap)
func BenchmarkSingleGetPresentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	syncMap.Store("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Load("key")
	}
}

```
Test results:
```go

BenchmarkSingleGetPresentBuiltInMap-4       	20000000	        71.5 ns/op	       0 B/op	       0 allocs/op
BenchmarkSingleGetPresent-4                 	30000000	        42.3 ns/op	       0 B/op	       0 allocs/op
BenchmarkSingleGetPresentSyncMap-4          	30000000	        40.3 ns/op	       0 B/op	       0 allocs/op


```
![](https://img.halfrost.com/Blog/ArticleImage/59_30.png)


As the figure shows, `sync.Map` performs extremely well for `Load`, far outperforming the other two implementations.


### 3. Concurrent Insert/Read Mixed Performance Test

The next implementation involves concurrent inserts and reads. Due to the characteristics of the sharded-lock implementation, the number of shards will affect performance to some extent. Therefore, the following experiment tests the sharded-lock implementation with 1, 16, 32, and 256 shards to observe how performance changes. The other two thread-safe Map implementations remain unchanged.

Since there is too much concurrent code, it is not included here. Interested readers can refer to [this](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_map_bench_test/concurrent-map/concurrent_map_bench_test.go).


Below are the test results:

Concurrent insertion of non-existent Key values
```go

BenchmarkMultiInsertDifferentBuiltInMap-4   	 1000000	      2359 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_1_Shard-4     	 1000000	      2039 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_16_Shard-4    	 1000000	      1937 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_32_Shard-4    	 1000000	      1944 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_256_Shard-4   	 1000000	      1991 ns/op	     331 B/op	      11 allocs/op
BenchmarkMultiInsertDifferentSyncMap-4      	 1000000	      3760 ns/op	     635 B/op	      33 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_31.png)


As the figure shows, `sync.Map` performs worse than the other two in all cases involving `Store`. When concurrently inserting non-existent keys, the number of `Segment`s used by the sharded-lock implementation has no impact on performance.


Concurrently inserting existing key values
```go

BenchmarkMultiInsertSameBuiltInMap-4        	 1000000	      1182 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiInsertSame-4                  	 1000000	      1091 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiInsertSameSyncMap-4           	 1000000	      1809 ns/op	     480 B/op	      30 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_32.png)


As the figure shows, in cases involving Store, sync.map performs worse than the other two.


Concurrently reading existing Key values
```go

BenchmarkMultiGetSameBuiltInMap-4           	 2000000	       767 ns/op	       0 B/op	       0 allocs/op
BenchmarkMultiGetSame-4                     	 3000000	       481 ns/op	       0 B/op	       0 allocs/op
BenchmarkMultiGetSameSyncMap-4              	 3000000	       464 ns/op	       0 B/op	       0 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_33.png)


As the figure shows, sync.map significantly outperforms the other two in terms of Load performance.


Concurrently inserting and reading non-existent Key values
```go

BenchmarkMultiGetSetDifferentBuiltInMap-4   	 1000000	      3281 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_1_Shard-4     	 1000000	      3007 ns/op	     338 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_16_Shard-4    	  500000	      2662 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_32_Shard-4    	 1000000	      2732 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_256_Shard-4   	 1000000	      2788 ns/op	     339 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferentSyncMap-4      	  300000	      8990 ns/op	    1104 B/op	      34 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_34.png)


As can be seen from the figure, `sync.map` performs worse than the other two in all cases involving Store. For concurrent insertion and reading of non-existent Keys, the number of Segments used by the sharded lock has no impact on performance.


Concurrent insertion and reading of existing Key values
```go

BenchmarkMultiGetSetBlockBuiltInMap-4       	 1000000	      2095 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_1_Shard-4         	 1000000	      1712 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_16_Shard-4        	 1000000	      1730 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_32_Shard-4        	 1000000	      1645 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_256_Shard-4       	 1000000	      1619 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlockSyncMap-4          	  500000	      2660 ns/op	     480 B/op	      30 allocs/op

```
![](https://img.halfrost.com/Blog/ArticleImage/59_35.png)


As can be seen from the figure, sync.map performs worse than the other two in all cases involving Store. For concurrent insertion and reading of existing Keys, the smaller the Segment used for sharded locking, the better the performance!


### 4. Delete Performance Test
```go

// Delete existing key (coarse lock)
func BenchmarkDeleteBuiltInMap(b *testing.B) {
	myMap = &MyMap{
		m: make(map[string]interface{}, 32),
	}
	b.RunParallel(func(pb *testing.PB) {
		r := rand.New(rand.NewSource(time.Now().Unix()))
		for pb.Next() {
			// The loop body is executed b.N times total across all goroutines.
			k := r.Intn(100000000)
			myMap.BuiltinMapDelete(strconv.Itoa(k))
		}
	})
}

// Delete existing key (segmented lock)
func BenchmarkDelete(b *testing.B) {
	m := New()
	b.RunParallel(func(pb *testing.PB) {
		r := rand.New(rand.NewSource(time.Now().Unix()))
		for pb.Next() {
			// The loop body is executed b.N times total across all goroutines.
			k := r.Intn(100000000)
			m.Remove(strconv.Itoa(k))
		}
	})
}

// Delete existing key (syncMap)
func BenchmarkDeleteSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	b.RunParallel(func(pb *testing.PB) {
		r := rand.New(rand.NewSource(time.Now().Unix()))
		for pb.Next() {
			// The loop body is executed b.N times total across all goroutines.
			k := r.Intn(100000000)
			syncMap.Delete(strconv.Itoa(k))
		}
	})
}


```
Test result:
```go

BenchmarkDeleteBuiltInMap-4                 	10000000	       130 ns/op	       8 B/op	       1 allocs/op
BenchmarkDelete-4                           	20000000	        76.7 ns/op	       8 B/op	       1 allocs/op
BenchmarkDeleteSyncMap-4                    	30000000	        45.4 ns/op	       8 B/op	       0 allocs/op


```
![](https://img.halfrost.com/Blog/ArticleImage/59_36.png)


As the figure shows, sync.map’s Delete result completely outperforms the other two.

## VI. Summary


![](https://img.halfrost.com/Blog/ArticleImage/59_37.png)


This article started from the theoretical foundations of thread safety and covered several approaches to handling thread safety, including concepts related to mutexes and condition variables. It moved from Lock-based solutions to Lock \- Free CAS-based solutions. Finally, it analyzed the source code and benchmarked the performance of sync.map, newly added in Go 1.9.

The benchmark results for sync.map, which adopts a Lock \- Free approach, were not as impressive as one might expect. Except for Load and Delete, where it leaves the other two far behind, any operation involving Store performs worse than the other two Map implementations. That said, there are reasons for this.

Looking at the evolution of Java ConcurrentHashmap:

In JDK 6 and 7, ConcurrentHashmap mainly used Segment to reduce lock granularity. It divided HashMap into multiple Segments. During put, the Segment had to be locked; during get, no lock was taken, and volatile was used to guarantee visibility. When global statistics were needed, such as size, it would first try to compute modcount multiple times to determine whether any other thread had performed modifications during those attempts. If not, it returned size directly. If so, it had to lock all Segments one by one to compute the result.

In JDK 7’s ConcurrentHashmap, when the length became too large, collisions would occur frequently. Add, update, delete, and lookup operations on linked lists would all take a long time and hurt performance. Therefore, JDK 8 completely rewrote concurrentHashmap: the codebase grew from just over 1,000 lines to more than 6,000 lines, and the implementation differed greatly from the original segmented storage design.

The main design changes in JDK 8’s ConcurrentHashmap are as follows:

- It no longer uses Segment; instead, it uses node, and locks node to reduce lock granularity.
- It introduced the MOVED state. If thread 2 is still putting data during Resize, thread 2 will help with resize.
- It uses three CAS operations to ensure atomicity for certain node operations, replacing locks with this approach.
- Different values of sizeCtl represent different meanings and serve a control role.


As we can see, Go 1.9 abandoned the Segment approach right from its first version and adopted the CAS-based Lock \- Free approach to improve performance. However, it did not introduce a Java-like Node design for the entire dictionary. Even so, across the three performance metrics—ns/op, B/op, and allocs/op—the overall sync.map is three times that of a regular native non-thread-safe Map!

That said, I believe Google will continue optimizing this area. After all, there are still several TODOs in the source code. Let’s look forward to how future Go versions evolve; I will also continue following this closely.


(As this article was being finalized, I suddenly discovered another segmented-lock Map implementation with even higher performance. It has characteristics such as load balancing and is probably the fastest thread-safe Map implementation in Go that I have seen so far. A source-code analysis of its implementation will have to wait for a separate post next time, or until I have time to analyze it later.)


------------------------------------------------------

Reference:  
*Go Concurrent Programming in Practice*     
[Split-Ordered Lists: Lock-Free Extensible Hash Tables](http://people.csail.mit.edu/shanir/publications/Split-Ordered_Lists.pdf)     
[Semaphores are Surprisingly Versatile](http://preshing.com/20150316/semaphores-are-surprisingly-versatile/)  
[Thread safety](https://zh.wikipedia.org/wiki/%E7%BA%BF%E7%A8%8B%E5%AE%89%E5%85%A8)  
[In-depth Analysis of Java CAS Principles](http://zl198751.iteye.com/blog/1848575)    
[Summary of Java ConcurrentHashMap](https://my.oschina.net/hosee/blog/675884)  

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map\_chapter\_two/](https://halfrost.com/go_map_chapter_two/)