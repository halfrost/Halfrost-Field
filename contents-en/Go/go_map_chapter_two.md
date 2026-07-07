# How to Design and Implement a Thread-Safe Map? (Part 2)

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a09c131eb02323fe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In the previous part, we discussed how to implement a Map, and also covered many optimization points. In this second part, we will continue by discussing how to implement a thread-safe Map. When talking about thread safety, we need to start with the concept itself.


![](http://upload-images.jianshu.io/upload_images/1194012-a50cce475fe9b0b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Thread safety means that if there are multiple threads running concurrently in the process where your code block resides, those threads may execute this code at the same time. If every execution produces the same result as a single-threaded execution, and the values of other variables are also as expected, then the code is thread-safe.

If a code block contains updates to shared data, then that code block may not be thread-safe. But if all such operations in the code block are inside a critical section, then the code block is thread-safe.


There are usually two categories of approaches to avoiding race conditions and achieving thread safety:

#### Category 1 — Avoid Shared State

1. Re-entrancy [Re-entrancy](https://en.wikipedia.org/wiki/Reentrant_(subroutine)) 

In discussions of thread safety, the most common kind of code block is usually a function. The most effective way to make a function thread-safe is to make it reentrant. If all threads in a process can call a function concurrently, and regardless of the actual execution interleaving of those calls, the function can still produce the expected result, then the function can be said to be reentrant.

If a function uses shared data as its return value or includes shared data in its returned result, then that function is definitely not reentrant. Any function that contains code operating on shared data is not reentrant.

To implement a thread-safe function, it is feasible to place all code inside a critical section. However, using a mutex always consumes some system resources and time, and there are always trade-offs involved in using mutexes. So use mutexes judiciously to protect code that operates on shared data.

**Note**: Reentrancy is a sufficient but not necessary condition for thread safety; it is **not a necessary and sufficient condition**. A counterexample will be discussed below.

2. Thread-local storage

If variables have been localized so that each thread has its own private copy, these variables retain their values across subroutines and other code boundaries, and are thread-safe because they are stored locally for each thread. Even if the code that accesses them may be executed simultaneously by another thread, they remain thread-safe.

3. Immutable variables

Once an object has been initialized, it cannot be changed. This means only read-only data is shared, which also provides inherent thread safety. Mutable (non-constant) operations can be implemented by creating new objects for them instead of modifying existing ones. String implementations in Java, C#, and Python use this approach.


#### Category 2 — Thread Synchronization

The approaches in the first category are relatively simple and can be implemented through code refactoring. But if shared data between threads is unavoidable, the first category of approaches cannot solve the problem. This is where the second category of solutions comes in: using thread synchronization to address thread-safety issues.

Today, we will start with thread synchronization.


---------------------------------------------


## 1. Thread Synchronization Theory

In multithreaded programs, shared data is often used as the means of passing data between threads. Since a substantial portion of a process’s virtual memory address space can be shared by all threads in that process, most shared data uses memory space as its carrier. If two threads read the same shared memory at the same time but obtain different data, the program can easily run into bugs.

To ensure consistency of shared data, the simplest and most thorough approach is to make the data immutable. Of course, this absolute approach is infeasible in most cases. For example, a function may use a counter to record how many times it has been called; such a counter certainly cannot be made constant. In cases where the data must be mutable while still maintaining consistency, this leads to the concept of a critical section.


![](http://upload-images.jianshu.io/upload_images/1194012-ca316bda95dfa59a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


A critical section exists to ensure that a region can only be accessed or executed serially. A critical section can be a resource, or it can be a piece of code. The most effective way to protect a critical section is to use a thread synchronization mechanism.


Let’s first introduce two methods for synchronizing shared data.


### 1. Mutex

The constraint that only one thread is allowed to be inside a critical section at the same time is called mutual exclusion. Before entering the critical section, each thread must first lock some object. Only the thread that successfully locks the object is allowed to enter the critical section; otherwise, it will be blocked. This object is called a mutex object, or mutex.


The mutex locks we commonly talk about serve this purpose.

There can be multiple mutexes, and the critical sections they protect can also be multiple. Let’s start with the simplest case: one mutex and one critical section.

#### (1) One Mutex and One Critical Section


![](http://upload-images.jianshu.io/upload_images/1194012-566294bb7943ad2f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The figure above is an example of one mutex and one critical section. When thread 1 enters the critical section first, the current critical section is unlocked, so it locks the critical section. Thread 1 then obtains the value inside the critical section.

At this point, thread 2 is ready to enter the critical section. Because thread 1 has locked the critical section, thread 2 fails to enter it, and thread 2 transitions from the ready state to the sleeping state. Thread 1 continues to write to the shared data in the critical section.

After thread 1 completes all operations, thread 1 calls the unlock operation. Once the critical section is unlocked, the system will try to wake up the sleeping thread 2. After thread 2 is awakened, it transitions from the sleeping state back to the ready state. Thread 2 prepares to enter the critical section; since the critical section is currently unlocked, thread 2 locks it.

After a series of read and write operations, it will eventually unlock when leaving the critical section.


When a thread leaves a critical section, it must remember to unlock the corresponding mutex. This gives other threads that were put to sleep because the critical section was locked a chance to be awakened. Therefore, locking and unlocking the same mutex variable must occur in pairs. You must neither lock the same mutex variable repeatedly nor unlock the same mutex variable multiple times.


![](http://upload-images.jianshu.io/upload_images/1194012-954e90ad96649b88.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Locking the same mutex variable multiple times may cause the critical section to remain blocked forever. Some people may ask: what happens if you unlock an unlocked mutex variable multiple times?

Before Go 1.8, although unlocking a mutex variable multiple times would not block any goroutine, it could trigger a runtime panic. In versions before Go 1.8, it was possible to attempt to recover from this panic, but after recovery, it could lead to a series of problems. For example, the goroutine that performed the repeated unlock operation could become permanently blocked. Therefore, after Go 1.8, this kind of runtime panic became unrecoverable. So repeatedly unlocking a mutex variable will cause a runtime panic, and the program will eventually exit abnormally.


#### (2) Multiple Mutexes and One Critical Section

In this situation, thread deadlocks are extremely easy to produce. Therefore, try not to let critical sections protected by different mutexes overlap.


![](http://upload-images.jianshu.io/upload_images/1194012-1755b35e29c8d8ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the example above, there are two mutexes in one critical section: mutex A and mutex
 B.

Thread 1 locks mutex A first, and then thread 2 locks mutex B. Thread 1 will never release mutex A before it successfully locks mutex B. Similarly, thread 2 will never release mutex B before it successfully locks mutex A. At this point, both thread 1 and thread 2 are unable to lock the mutex they need, so they both transition from the ready state to the sleep state. This is how a thread deadlock occurs.


Thread deadlocks can be caused by the following:

- 1. Competition for system resources    
- 2. Illegal process execution order    
- 3. Necessary conditions for deadlock (if any one of the necessary conditions is not satisfied, deadlock will not occur)  
(1). Mutual exclusion condition    
(2). No preemption condition  
(3). Hold-and-wait condition  
(4). Circular wait condition  

There are several ways to avoid thread deadlocks:

- 1. Deadlock prevention    
(1). Ordered resource allocation method (break the circular wait condition)    
(2). Atomic resource allocation method (break the hold-and-wait condition)    

- 2. Deadlock avoidance  
Banker’s algorithm  

- 3. Deadlock detection  
Deadlock theorem (resource allocation graph reduction method). Although this method can detect deadlocks, it cannot prevent them. After a deadlock is detected, it still needs to be combined with a method for resolving the deadlock.

There are several ways to fully resolve deadlocks:

- 1. Preempt resources  
- 2. Terminate processes  
- 3. Try-lock — rollback  
If executing a code block requires locking two variables one after another (with no fixed order), then after successfully locking one mutex, you should use a try-lock method to lock the other variable. If trying to lock the second mutex fails, unlock the first mutex that has already been locked, and then retry locking and try-locking the two mutexes.


![](http://upload-images.jianshu.io/upload_images/1194012-e5592ec6aba7f454.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown above, when thread 2 locks mutex B and then tries to lock mutex A, the lock attempt fails, so it also unlocks mutex B. Then thread 1 will lock mutex A. At this point, no deadlock will occur.    
- 4. Lock in a fixed order  


![](http://upload-images.jianshu.io/upload_images/1194012-40be5bc5d521fb37.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This approach makes both thread 1 and thread 2 lock mutexes in the same order: only after successfully locking mutex 1 can they proceed to lock mutex 2. This ensures that before one thread has completely left these overlapping critical sections, no other thread that also needs to lock those mutexes will enter there.

#### (3) Multiple Mutexes and Multiple Critical Sections


![](http://upload-images.jianshu.io/upload_images/1194012-4585db03a0799d1a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


For multiple critical sections and multiple mutexes, it depends on whether there are conflicting regions. If overlapping conflicting regions appear, the thread that enters the critical section later will enter the sleeping state until the thread in that critical section completes its task, at which point it will be awakened.

In general, mutexes should be used as sparingly as possible. The critical section protected by each mutex should be within a reasonable scope and as large as possible. However, if you find that multiple threads frequently enter and exit a relatively large critical section, and access conflicts often occur among them, then you should divide the large critical section into smaller ones and protect them with different mutexes. The purpose of doing this is to reduce the number of threads waiting to enter the same critical section, thereby lowering the probability of threads being blocked and reducing the time they are forced to spend in the sleeping state. To some extent, this improves the overall performance of the program.

Before discussing another thread synchronization method, let’s answer a question raised at the beginning of the article: reentrancy is a sufficient but not necessary condition for thread safety; it is not a necessary and sufficient condition. A counterexample will be discussed below.


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
In the code above, the function increment\_counter can be called from multiple threads because a mutex, mutex, synchronizes access to the shared variable counter. However, if this function is used in a reentrant interrupt handler, and another interrupt that calls increment\_counter occurs between
pthread\_mutex\_lock(&mutex) and pthread\_mutex\_unlock(&mutex),
the function will be executed a second time. At that point, because mutex has already been locked, the function will block at pthread\_mutex\_lock(&mutex), and since mutex has no chance to be
unlocked, the block will last forever. In short, the problem is that a [pthread](https://zh.wikipedia.org/wiki/Pthread) mutex is not reentrant.

The solution is to set the PTHREAD\_MUTEX\_RECURSIVE attribute. However, for the problem at hand, using a dedicated mutex to protect a simple increment operation is clearly too expensive. Therefore, [c++11](https://zh.wikipedia.org/wiki/C%2B%2B11) [atomic variables](https://zh.wikipedia.org/w/index.php?title=Atomic_(C%2B%2B%E6%A0%87%E5%87%86%E5%BA%93)&action=edit&redlink=1) provide an alternative that makes this function both thread-safe and reentrant—and also more concise:
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
In Go, a mutex is represented by the `Mutex` struct in the standard library package `sync`. The `sync.Mutex` type exposes only two pointer methods: `Lock` and `Unlock`. The former is used to lock the current mutex, while the latter is used to unlock it.

### 2. Condition Variables

Among thread synchronization mechanisms, there is another synchronization primitive comparable to a mutex: the condition variable.

Unlike a mutex, a condition variable is not used to ensure that only one thread can access a piece of shared data at a time. Instead, when the state of the corresponding shared data changes, it notifies other threads that are blocked because of that state. A condition variable is always used together with a mutex.


This kind of problem is actually very common. Let’s start with the producer-consumer example.


If we do not use a condition variable and use only a mutex, let’s see what happens.

Before a producer thread finishes adding an item, no other producer thread or consumer thread can perform any operation. The same item can also be consumed by only one consumer.

If only a mutex is used, two problems may occur.

- 1. After a producer thread acquires the mutex, it finds that the goods are full and no new item can be added. As a result, the thread keeps waiting. New producers cannot enter the critical section, and consumers cannot enter either. At this point, a deadlock occurs.

- 2. After a consumer thread acquires the mutex, it finds that there are no goods and nothing can be consumed. At this point, the thread also keeps waiting. New producers and consumers cannot enter either. This also results in a deadlock.

This is the problem that cannot be solved by using only a mutex. Among multiple threads, there is an urgent need for a synchronization mechanism that allows these threads to cooperate.

Condition variables are the familiar P-V operations. You should already be quite familiar with this part, so we will go through it briefly.


The P operation is the wait operation. It means blocking the current thread until a notification is received from the condition variable.

The V operation is the signal operation. It means having the condition variable send a notification to at least one thread that is waiting for it, indicating that the state of some shared data has changed.


Broadcast notification means having the condition variable send notifications to all threads waiting for it, indicating that the state of some shared data has changed.

![](http://upload-images.jianshu.io/upload_images/1194012-ce03974690a19433.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

`signal` can be performed multiple times. If it is performed 3 times, it means 3 signal notifications have been sent, as shown in the figure above.


![](http://upload-images.jianshu.io/upload_images/1194012-810ad286a9ec378b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The elegance of the P-V operation design lies in the fact that the number of P operations is the same as the number of V operations. However many times `wait` is called, there are the corresponding number of `signal` calls. Look at the figure above—this loop is exactly that wonderful.

#### Producer-Consumer Problem


![](http://upload-images.jianshu.io/upload_images/1194012-d4ac5739b6c09fb6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This problem can be described visually as in the figure above: a guard protects the safety of the critical section. The ticket office records the current semaphore value, and it also controls whether the guard opens the critical section.


![](http://upload-images.jianshu.io/upload_images/1194012-7b6f8ce24d0d11f6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The critical section allows only one thread to enter. When one thread is already inside, another arriving thread will be locked out. The ticket office also records the current number of blocked threads.


![](http://upload-images.jianshu.io/upload_images/1194012-59bbd810186f2db7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After the previous thread leaves, the ticket office tells the guard to allow one thread to enter the critical section.


Using P-V pseudocode to describe the producer-consumer problem:

Initial variables:
```c

semaphore  mutex = 1; // mutex semaphore for the critical section
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
Although `P` and `V` are not paired within a single producer or consumer routine, across the entire program `P` and `V` are still paired.

#### Readers–writers problem — readers preferred, writers delayed

Readers are given priority, and writer processes are delayed. As long as there is a reader reading, any subsequent readers may enter and read freely.

![](http://upload-images.jianshu.io/upload_images/1194012-f1bad003e57c69f6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

A reader must first enter `rmutex`, inspect `readcount`, then update the value of `readcout`, and finally read the data. For every reader process, it acts as a writer because it modifies the value of `readcount`; therefore, a separate `rmutex` is needed to provide mutual exclusion for that access.

Initial variables:
```c

int readcount = 0;     // number of readers
semaphore  rmutex = 1; // ensure mutually exclusive updates to readcount
semaphore  wmutex = 1; // ensure mutually exclusive file access by readers and writers

```
Reader thread:
```c

reader()
{
  while(1) {
    P(rmutex);              // Prepare to enter, modify readcount, “open the door”
    if(readcount == 0) {    // Indicates this is the first reader
      P(wmutex);            // Get the ”key”, preventing writer threads from writing
    }
    readcount ++;
    V(rmutex);
    reading;
    P(rmutex);              // Prepare to leave
    readcount --;
    if(readcount == 0) {    // Indicates this is the last reader
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

#### Readers-Writers Problem — Writer Priority, Reader Delay

When a writer is writing, subsequent readers are not allowed to read. Readers that arrived before the writer may leave after finishing their reads. As long as any writer is waiting, subsequent readers are prohibited from entering to read.

![](http://upload-images.jianshu.io/upload_images/1194012-a3f5a3cda4ca2e7e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Initial variables:
```c

int readcount = 0;     // number of readers
semaphore  rmutex = 1; // ensure mutually exclusive updates to readcount
semaphore  wmutex = 1; // ensure mutually exclusive file access by readers and writers
semaphore  w = 1;      // used to implement “writer priority”

```
Reader thread:
```c

reader()
{
  while(1) {
    P(w);                   // Can request entry only when there is no writer
    P(rmutex);              // Prepare to enter, update readcount, “open the door”
    if(readcount == 0) {    // Indicates this is the first reader
      P(wmutex);            // Get the ”key” to prevent writer threads from writing
    }
    readcount ++;
    V(rmutex);
    V(w);
    reading;
    P(rmutex);              // Prepare to leave
    readcount --;
    if(readcount == 0) {    // Indicates this is the last reader
      V(wmutex);            // Hand over the ”key” to let writer threads write
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
    P(w);
    P(wmutex);
    writing;
    V(wmutex);
    V(w);
  }
}

```

#### Dining Philosophers Problem


Suppose five philosophers are seated around a circular dining table, doing one of two things: eating or thinking. When they eat, they stop thinking; when they think, they stop eating. In the middle of the table is a large bowl of spaghetti, and between each pair of philosophers is a fork. Because it is difficult to eat spaghetti with only one fork, assume that each philosopher must use two forks to eat. They can only use the two forks to their immediate left and right. The dining philosophers problem is sometimes described using rice and chopsticks instead of spaghetti and forks, because it is obvious that eating rice requires two chopsticks.


![](http://upload-images.jianshu.io/upload_images/1194012-d295fb92ead8bcf7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

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
\*The method set of the sync.Cond type contains three methods: Wait, Signal, and Broadcast.

## II. A Simple Thread-Locking Approach

The simplest way to implement thread safety is to add a lock.

First, let’s look at how to implement a thread-safe dictionary in OC.

In the Weex source code, a thread-safe dictionary is implemented. The class is named WXThreadSafeMutableDictionary.
```objectivec

/**
 *  @abstract Thread safe NSMutableDictionary
 */
@interface WXThreadSafeMutableDictionary<KeyType, ObjectType> : NSMutableDictionary
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableDictionary* dict;
@end

```
The concrete implementation is as follows:
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
During initialization, this thread-safe dictionary creates a new concurrent queue.
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
These read methods all use dispatch\_sync.
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
All write-related methods use dispatch\_barrier\_async.

Next, let’s look at how to implement a simple thread-safe Map in Go using a mutex.

Since we need a mutex, we’ll wrap a Map that contains one.
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
Next, implement the basic methods of Map in a simple way.
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
The implementation idea is fairly simple: add a lock before each operation, and add an unlock in a `defer` at the end of each function.

A thread-safe dictionary implemented with this locking approach has the advantage of being simple, but the disadvantage of poor performance. At the end of the article, we will compare the performance of several implementation approaches. The numbers will make it clear just how poor the performance of this mutex-based locking approach is.

In languages that natively provide a thread-safe Map, their underlying native implementations are not based purely on locking to achieve thread safety. Examples include Java’s ConcurrentHashMap and the `sync.map` added in Go 1.9.

## III. Modern Lock-Free Thread-Safe Approach: CAS

The underlying implementation of Java’s ConcurrentHashMap makes extensive use of Lock-Free techniques such as volatile, final, and CAS to reduce the performance impact of lock contention.


Atomic operations are also used extensively in Go, and CAS is one of them. Compare-and-swap, abbreviated as CAS, means “Compare And Swap”.
```go

func CompareAndSwapInt32(addr *int32, old, new int32) (swapped bool)

func CompareAndSwapInt64(addr *int64, old, new int64) (swapped bool)

func CompareAndSwapUint32(addr *uint32, old, new uint32) (swapped bool)

func CompareAndSwapUint64(addr *uint64, old, new uint64) (swapped bool)

func CompareAndSwapUintptr(addr *uintptr, old, new uintptr) (swapped bool)

func CompareAndSwapPointer(addr *unsafe.Pointer, old, new unsafe.Pointer) (swapped bool)

```
CAS first checks whether the value being operated on, pointed to by the parameter `addr`, is equal to the value of the parameter `old`. If they are equal, the corresponding function replaces the old value with the new value represented by the parameter `new`. Otherwise, the replacement operation is ignored.


![](http://upload-images.jianshu.io/upload_images/1194012-7c1aa0c3d7ce2c51.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This is clearly different from a mutex. CAS always assumes that the value being operated on has not changed, and once it confirms that this assumption holds, it immediately performs the value replacement. A mutex takes a more cautious approach: it always assumes that concurrent operations may modify the value being operated on, and therefore needs to use a lock to protect the relevant operations by placing them in a critical section. You could say that the mutex approach is pessimistic, while the CAS approach is optimistic, similar to optimistic locking.

The biggest advantage of CAS is that it can perform concurrency-safe value replacement without creating a mutex or a critical section. This greatly reduces the impact of thread synchronization operations on program performance. Of course, CAS also has some drawbacks, which will be covered in the next chapter.

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

Consult Intel's [documentation](http://x86.renejeschke.de/html/file_module_x86_id_41.html)

![](http://upload-images.jianshu.io/upload_images/1194012-db7a028dd6f9b8ed.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The documentation says:

Compare the value in eax with the destination operand (the first operand). If they are equal, the ZF flag is set, and the value of the source operand (the second operand) is written to the destination operand. Otherwise, the
ZF flag is cleared, and the value of the destination operand is written back to eax.

This gives us the working principle of CMPXCHG:

Compare the values of \_old and (\*\_\_ptr). If they are equal, the ZF flag is set, and
 the value of \_new is written to (\*\_\_ptr). Otherwise, the ZF flag is cleared, and the value of (\*\_\_ptr) is written back to \_old.

On Intel platforms, this is implemented with LOCK CMPXCHG, where LOCK is a CPU lock.

Intel's manual describes the LOCK prefix as follows:
- 1. It ensures that read-modify-write operations on memory are executed atomically. On Pentium and earlier processors, an instruction with the LOCK prefix locks the bus during execution, temporarily preventing other processors from accessing memory through the bus. Obviously, this incurs significant overhead. Starting with Pentium 4, Intel Xeon, and P6 processors, Intel made a meaningful optimization on top of the original bus lock: if the memory area to be accessed is already locked in the processor's internal cache while the LOCK-prefixed instruction is executing (that is, the cache line containing the memory area is currently in the exclusive or modified state), and the memory area is entirely contained within a single cache line, then the processor executes the instruction directly. Because the cache line remains locked throughout the instruction's execution, other processors cannot read from or write to the memory area accessed by the instruction, so atomicity can be guaranteed. This process is called cache locking. Cache locking greatly reduces the execution overhead of LOCK-prefixed instructions, but when contention between multiple processors is high or the memory address accessed by the instruction is unaligned, the bus may still be locked.
- 2. It prevents this instruction from being reordered with preceding and following read and write instructions.
- 3. It flushes all data in the write buffer to memory.

From this description, we can see that CPU locks mainly fall into two categories: bus locks and cache locks. Bus locks are used on older CPUs, while cache locks are used on newer CPUs.

![](http://upload-images.jianshu.io/upload_images/1194012-153c43829be0a454.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

A bus lock uses a LOCK# signal provided by the CPU. When a processor outputs this signal on the bus, requests from other processors are blocked, allowing that CPU to exclusively use shared memory. With bus locking, the bus is locked during execution, temporarily preventing other processors from accessing memory through the bus. Therefore, bus locking is relatively expensive. Modern processors use cache locking instead of bus locking in certain cases as an optimization.

![](http://upload-images.jianshu.io/upload_images/1194012-410debdcf9cea1b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

"Cache locking" means that if the memory area cached in the processor's cache line is locked during the LOCK operation, then when the locked operation writes back to memory, the processor does not generate a
LOCK# signal on the bus. Instead, it modifies the internal memory address and relies on its cache-coherency mechanism to guarantee atomicity. This is because the cache-coherency mechanism prevents simultaneous modification of memory-region data cached by two or more processors; when another processor writes back data from a locked cache line, that cache line is invalidated.

There are two situations in which the processor cannot use cache locking.

- The first is when the data being operated on cannot be cached inside the processor, or when the data spans multiple cache lines. In that case, the processor uses bus locking.

- The second is when some processors do not support cache locking. Some older CPUs use bus locking even if the locked memory area is in the processor's cache line.

Although cache locking can greatly reduce the execution overhead of CPU locks, the bus may still be locked when contention between multiple processors is high or when the memory address accessed by the instruction is unaligned. Therefore, cache locking and bus locking complement each other and work better together.

In summary, using CAS to guarantee thread safety is much more efficient than using a mutex.

## IV. Drawbacks of CAS

Although CAS is efficient, it still has three major problems.

### 1. The ABA Problem

![](http://upload-images.jianshu.io/upload_images/1194012-7649918f92e26fb0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Thread 1 is about to use CAS to replace the variable's value from A to B. Before that happens, thread 2 changes the variable's value from A to C, and then from C back to A. When thread 1 executes CAS, it finds that the variable's value is still A, so the CAS succeeds. But in reality, the state is no longer the same as it was initially. The diagram also marks the two A values with different colors to distinguish them. Ultimately, thread 2 replaces A with B. This is the classic ABA problem. But what kind of issue can this cause in a project?

![](http://upload-images.jianshu.io/upload_images/1194012-dfb53bb0a25ee4b4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Imagine there is a linked-list stack. The stack stores a linked list; the top of the stack is A, and A's next pointer points to B. In thread 1, we want to use CAS to replace the top element A with B. Then thread 2 comes in and pops out the linked list that previously contained elements A and B. It then pushes in an A - C - D linked list, so the top element of the stack is still A. At this point, thread 1 sees that A has not changed, so it replaces it with B. However, B's next is actually nil. After the replacement completes, the linked list C - D operated on by thread 2 becomes disconnected from the head. In other words, after thread 1's CAS operation finishes, C - D is lost and can never be recovered. The stack is left with only the single element B. This is clearly a bug.

How do we solve this situation? The most common approach is to add a version number for identification.

![](http://upload-images.jianshu.io/upload_images/1194012-2be65ea80910f36e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Add a version number to every operation, and the ABA problem can be solved cleanly.

### 2. The Loop May Run for Too Long

![](http://upload-images.jianshu.io/upload_images/1194012-7d564fa4b0f07ff7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If a spinning CAS does not succeed for a long time, it can impose a very large execution overhead on the CPU. If the CPU-provided Pause instruction is supported, CAS efficiency can be improved to some extent. The Pause instruction has two effects. First, it can delay pipeline execution of instructions (de-pipeline), so that the CPU does not consume too many execution resources. The delay duration depends on the specific implementation; on some processors, the delay is zero. Second, it can avoid a CPU pipeline flush caused by a memory order violation when exiting the loop, thereby improving CPU execution efficiency.

### 3. It Can Only Guarantee Atomic Operations on a Single Shared Variable

CAS operations can only guarantee atomic operations on a single shared variable; they cannot guarantee atomicity for operations on multiple shared variables. The usual approach is to consider using locks.

![](http://upload-images.jianshu.io/upload_images/1194012-280d8d4d40860d2e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

However, you can also use a struct to combine two variables into one. This way, you can still use CAS to guarantee atomic operations.

## V. Example Lock-Free Approaches

Before looking at examples of lock-free approaches, let's first review the mutex-based approach. Above, we implemented a thread-safe Map in Go using a mutex. As for the performance of this Map, we can examine the data in the comparison that follows.

### 1. Non-Lock-Free Approach

If we do not use a lock-free approach, and also do not use a simple mutex-based approach, how can we implement a thread-safe dictionary? The answer is to use a segmented-lock design. Races only exist within the same segment; there is no lock contention between different segment locks. Compared with a design that locks the entire
Map, segmented locking greatly improves processing capability in high-concurrency environments.
```go


type ConcurrentMap []*ConcurrentMapShared


type ConcurrentMapShared struct {
	items        map[string]interface{}
	sync.RWMutex // read-write lock, ensures thread-safe access to the internal map
}

```
A segmented lock Segment has a concurrency level. The concurrency level can be understood as the maximum number of threads that can update ConccurentMap concurrently at runtime without lock contention; in practice, it is the number of segmented locks in ConcurrentMap—that is, the length of the array.
```go

var SHARD_COUNT = 32

```
If the concurrency level is set too low, it can lead to severe lock contention. If the concurrency level is set too high, accesses that would originally fall within the same Segment will be spread across different Segments, reducing the CPU cache hit rate and degrading program performance.


![](http://upload-images.jianshu.io/upload_images/1194012-578493519f8bf005.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Initializing a ConcurrentMap means initializing the array, as well as each map within that array.
```go

func New() ConcurrentMap {
	m := make(ConcurrentMap, SHARD_COUNT)
	for i := 0; i < SHARD_COUNT; i++ {
		m[i] = &ConcurrentMapShared{items: make(map[string]interface{})}
	}
	return m
}

```
ConcurrentMap primarily uses Segments to reduce lock granularity by dividing the Map into multiple Segments. A write lock is required during put operations, while get operations only acquire a read lock.

Since the map is segmented, the logic for determining which segment each key maps to is handled by a hash function.
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
The hash function above computes a different hash value based on the `string` passed in each time.
```go

func (m ConcurrentMap) GetShard(key string) *ConcurrentMapShared {
	return m[uint(fnv32(key))%uint(SHARD_COUNT)]
}

```
Take the hash value modulo the array length to retrieve the ConcurrentMapShared from the ConcurrentMap. The ConcurrentMapShared stores the key \- value pairs corresponding to that segment.
```go


func (m ConcurrentMap) Set(key string, value interface{}) {
	// Get map shard.
	shard := m.GetShard(key)
	shard.Lock()
	shard.items[key] = value
	shard.Unlock()
}

```
The snippet above is the `set` operation of `ConcurrentMap`. The idea is straightforward: first retrieve the corresponding `ConcurrentMapShared` for the segment, then acquire the read-write lock, write the key \- value pair, and release the read-write lock after the write succeeds.
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
The snippet above is the `get` operation of `ConcurrentMap`. The idea is straightforward: first retrieve the corresponding `ConcurrentMapShared` within the segment, then acquire the read lock, read the key-value pair, and release the read lock after the read succeeds.

The difference from the `set` operation here is that only a read lock is needed; there is no need to acquire a read-write lock.
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
The `Count` operation of `ConcurrentMap` traverses every element in each segmented element of the `ConcurrentMap` array and computes the total count.
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

	// Generate the keys array to store all keys
	keys := make([]string, 0, count)
	for k := range ch {
		keys = append(keys, k)
	}
	return keys
}

```
The above returns all keys in the ConcurrentMap, with the result stored in a string array.
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
The code above is an Upsert operation. If the element already exists, it updates it. If it is a new element, it inserts a new one using the UpsertCb function. The idea is also to first locate the corresponding segment based on the string, and then acquire the read-write lock. Here we can only use a read-write lock, because whether it is an update or an insert operation, a write is required. Read the value corresponding to the key, then call the UpsertCb function, and update the result into the value corresponding to the key. Finally, release the read-write lock.

One thing worth noting about the UpsertCb function here is that this callback returns the new element to be inserted into the map. This function is called if and only if the read-write lock is held, so it must not attempt to read other key values from the same map again. Doing so would cause a thread deadlock. The reason for the deadlock is that sync.RWLock in Go is not reentrant.

The complete code is available in [concurrent_map.go](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_map_bench_test/concurrent-map/concurrent_map.go)

Although this sharding approach is much better than simply adding a mutex, because Segment further reduces the scope of locking, that scope is still relatively large. Can the locking scope be reduced even further?

Another point is that the concurrency level must be configured reasonably: it should be neither too large nor too small.

### 2. Lock-Free Solution

In Go 1.9, a thread-safe Map is implemented by default. It abandons the concept of Segment (segmented locking) and instead adopts an entirely new implementation based on the CAS algorithm, namely a Lock-Free solution.

After adopting the Lock-Free solution, the locking scope can be reduced even further compared with the previous solution, segmented locking. Performance is greatly improved.

Next, let’s take a look at how to implement a high-performance thread-safe Map using CAS.

The official description of sync.map is as follows:

>This Map is thread-safe. Reads, inserts, and deletes all maintain constant-time complexity. It is also thread-safe for multiple goroutines to call Map methods concurrently. The zero value of this Map is valid, and the zero value is an empty Map. A thread-safe Map must not be copied after first use.


Here is why it must not be copied. Copying a struct not only creates a copy of the value itself, but also copies its fields. As a result, the concurrent thread-safety protection that should have applied to the original value becomes ineffective.

Assigning it as a source value to another variable, passing it into a function as an argument, returning it from a function as a result value, passing it through a channel as an element value, and similar operations all cause the value to be copied. The correct approach is to use a variable of pointer type pointing to that type.


The data structure of sync.map in Go 1.9 is as follows:
```go


type Map struct {

	mu Mutex

	// Concurrently reading part of the map is thread-safe; this does not require
	// read itself is thread-safe to read because it is atomic. However, storing still requires Mutex
	// Entries stored in read may be updated during concurrent reads; even without the Mutex semaphore, this is thread-safe. But updating a previously deleted entry requires copying the value to the dirty Map and must use Mutex
	read atomic.Value // readOnly

	// dirty contains the part of the map that must be protected by mutex mu to be thread-safe. To allow dirty to be quickly converted into the read map, dirty contains all entries in the read map that have not been deleted
	// Deleted entries are not stored in the dirty map. In the clean map, a deleted entry must not have been deleted before, and when a new value is about to be stored, they will be added to the dirty map.
	// When the dirty map is nil, the next write initializes it with a shallow copy of the clean map that omits old entries.
	dirty map[interface{}]*entry

	// misses records the number of loads after the read map had to lock mutex mu and perform an update to determine whether the key exists.
	// Once misses is large enough to cover the cost of copying the dirty map, the dirty map is promoted to the unmodified read map, and the next store will create a new dirty map.
	misses int
}


```
In this Map, there is a mutex `mu`, an atomic value `read`, and a non-thread-safe dictionary `map`; the key type of this dictionary is `interface{}`, and the value type is `*entry`. Finally, there is also an `int` counter.

First, let’s talk about the atomic value. The `atomic.Value` type has two public pointer methods: `Load` and `Store`. The `Load` method is used to atomically read the value stored in an atomic value instance. It returns a result of type `interface{}` and takes no arguments. The `Store` method is used to atomically store a value in an atomic value instance. It takes an argument of type `interface{}` and returns no result. Before any value has been stored in an atomic value instance via the `Store` method, its `Load` method will always return `nil`.

In this thread-safe dictionary, both `Load` and `Store` operate on a `readOnly` data structure.
```go

// readOnly is an immutable struct, atomically stored in Map.read
type readOnly struct {
	m map[interface{}]*entry
	// Indicates whether the dirty map contains some keys not in m.
	amended bool // true if the dirty map contains some key not in m.
}

```
`readOnly` stores a non-thread-safe map whose type is exactly the same as the `dirty map` described above. The key is of type `interface{}`, and the value is of type `*entry`.
```go

// entry is a slot corresponding to a specific key in the map
type entry struct {
	p unsafe.Pointer // *interface{}
}

```
The p pointer points to the \*interface{} type, which stores the address of the entry. If p == nil, it means the entry has been deleted and m.dirty == nil. If p == expunged, it means the entry has been deleted and m.dirty != nil, so the entry is missing from m.dirty.

Apart from the two cases above, the entry is valid and is recorded in m.read.m[key]. If m.dirty != nil, the entry is stored in m.dirty[key].

An entry can be deleted by atomically replacing it with nil. The next time m.dirty is created, the entry will be atomically replaced from nil with the expunged pointer, and m.dirty[key] will not correspond to any value. As long as p != expunged, an entry can update its associated value via an atomic replace operation. If p == expunged, then for an entry to update its associated value via an atomic replace operation, it can only do so after m.dirty[key] = e has first been set. This is done so that it can be found in the dirty map.


So from the analysis above, we can see that the keys in read are readOnly (the set of keys does not change; deletion only marks a key), and all value operations can be completed atomically, so this structure does not need locking. dirty is a copy of read, and all lock-protected operations happen there, such as adding elements and deleting elements. (A delete operation performed on dirty is a real deletion.) The specific operations are analyzed below.


![](http://upload-images.jianshu.io/upload_images/1194012-1c0e2faffeb6147a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


To summarize, the data structure of sync.map is shown above.

Now let’s look at some operations of the thread-safe sync.map.
```go

func (m *Map) Load(key interface{}) (value interface{}, ok bool) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	// If the value for key does not exist and the dirty map contains keys not in the read map, start reading the dirty map
	if !ok && read.amended {
		// dirty map is not thread-safe, so a mutex is needed
		m.mu.Lock()
		// When m.dirty is promoted, lock here to avoid getting a false miss.
		// If reading the same key again is not a miss, then this key's value is not worth copying to the dirty map.
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			e, ok = m.dirty[key]
			// Record this miss whether or not entry exists.
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
The code above is the `Load` operation. It returns the `value` corresponding to the input `key`. If the `value` does not exist, it returns `nil`. The `dirty map` stores some keys that do not exist in the `read map`, so the `value` corresponding to the `key` needs to be read from the `dirty map`. Note that a mutex must be acquired during the read, because the `dirty map` is not thread-safe.
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
The code above records the number of misses. Only when the number of misses is greater than the length of the dirty map will the dirty map be stored into the read map. It then sets dirty to nil and resets the misses count to zero.

Before looking at the Store operation, let’s first discuss the expunged variable.
```go

// expunged is a pointer to any type, used to mark an entry deleted from the dirty map
var expunged = unsafe.Pointer(new(interface{}))


```
The `expunged` variable is a pointer used to mark entries deleted from the dirty map.
```go

func (m *Map) Store(key, value interface{}) {
	read, _ := m.read.Load().(readOnly)
	// If reading key from the read map fails or the retrieved entry fails to store value, return directly
	if e, ok := read.m[key]; ok && e.tryStore(&value) {
		return
	}

	m.mu.Lock()
	read, _ = m.read.Load().(readOnly)
	if e, ok := read.m[key]; ok {
		// e points to a non-nil value
		if e.unexpungeLocked() {
			// The entry was previously deleted, which means there is a non-empty dirty map that does not contain this entry
			m.dirty[key] = e
		}
		// Before using storeLocked, ensure e has not been expunged
		e.storeLocked(&value)
	} else if e, ok := m.dirty[key]; ok {
		// Already stored in dirty map, meaning e has not been expunged
		e.storeLocked(&value)
	} else {
		if !read.amended {
			// Reaching this else means the current key is being added to the dirty map for the first time.
			// Before storing, check whether the dirty map is empty; if so, make a shallow copy of the read map.
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

If the corresponding key is not found in the read map, it reads from the dirty map. The dirty map directly stores the corresponding value.

Finally, if neither the read map nor the dirty map contains this key, it means the key is being added to the dirty map for the first time. Store the key and its corresponding value in the dirty map.
```go

// Store a value only when entry has not been deleted.
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
The implementation of the tryStore function is similar to the principle behind CAS: it repeatedly loops to check whether entry has been marked as expunged. If entry is successfully replaced with i via a CAS operation, it returns true; otherwise, if it has been marked as expunged, it returns false.
```go


// unexpungeLocked ensures that entry is not marked as expunged.
// If entry was previously expunged, it must be added to the dirty map before the mutex is unlocked.
func (e *entry) unexpungeLocked() (wasExpunged bool) {
	return atomic.CompareAndSwapPointer(&e.p, expunged, nil)
}

```
If `entry`’s `unexpungeLocked` returns `true`, it means `entry` has already been marked as `expunged`, so it will be set to `nil` via a CAS operation.

Now let’s look at the implementation of the delete operation.
```go

func (m *Map) Delete(key interface{}) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	if !ok && read.amended {
		// Since dirty map is not thread-safe, lock before operating
		m.mu.Lock()
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			// Delete the key from dirty map
			delete(m.dirty, key)
		}
		m.mu.Unlock()
	}
	if ok {
		e.delete()
	}
}

```
The implementation of the `delete` operation is relatively straightforward. If the key exists in the read map, it can be deleted directly. If the key does not exist there but exists in the dirty map, then that key needs to be deleted from the dirty map. Remember to acquire the lock first when operating on the dirty map to ensure protection.
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
The concrete implementation for deleting an entry is shown above. All operations in this procedure are atomic. It loops to check whether the entry is nil or has already been marked as expunged. If so, it returns false, indicating that the deletion failed. Otherwise, it performs a CAS operation, sets the entry’s p pointer to nil, and returns true, indicating that the deletion succeeded.


At this point, the implementation of the thread-safe sync.Map built into Go 1.9 has been fully analyzed. The official implementation basically does not use locks; even the mutex lock is based on CAS. The read map is also atomic. Therefore, compared with the previous lock-based implementation, its performance is improved.


If a key in read is deleted, that is, marked as expunged, and the same key is added again later, there is no need to operate on dirty; it can simply be restored directly.

If dirty has no data, and a key in read is deleted, it is likewise marked as expunged. Then, if another different key is added, the dirtyLocked() function copies all existing key-value pairs in read into dirty, and also appends the newly added key in read that is different from the previously deleted one.

This is equivalent to:

When dirty does not exist, read contains all the map data.  
When dirty exists, dirty is the correct map data.  


From the implementation of sync.Map, we can see that its core idea is lock-free reads. Most dictionary operations are reads, and multiple readers can proceed without locks. When misses in read reach a certain level (somewhat like cache hit/miss behavior), it considers directly replacing read with dirty; the whole operation is just an assignment replacement. However, when dirty is regenerated, or when the first dirty is created, it still needs to traverse the entire read map, which incurs a significant performance cost. So what is the actual performance of the official sync.Map?

How strong is Lock \- Free performance, exactly? Next, let’s run some benchmarks.


## V. Performance Comparison

The benchmarks mainly target three aspects: Insert, Get, and Delete. The test subjects are mainly three implementations: a native Map with a simple mutex, a Map with sharded locks, and a Lock \- Free Map.

All benchmark code has been put on GitHub at [here](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_map_bench_test/concurrent-map/concurrent_map_bench_test.go). The command used for benchmarking is:
```go

go test -v -run=^$ -bench . -benchmem

```

### 1. Insert Performance Test
```go

// Insert an absent key (coarse-grained lock)
func BenchmarkSingleInsertAbsentBuiltInMap(b *testing.B) {
	myMap = &MyMap{
		m: make(map[string]interface{}, 32),
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		myMap.BuiltinMapStore(strconv.Itoa(i), "value")
	}
}

// Insert an absent key (sharded lock)
func BenchmarkSingleInsertAbsent(b *testing.B) {
	m := New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Set(strconv.Itoa(i), "value")
	}
}

// Insert an absent key (syncMap)
func BenchmarkSingleInsertAbsentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Store(strconv.Itoa(i), "value")
	}
}

```
Test result:
```go

BenchmarkSingleInsertAbsentBuiltInMap-4     	 2000000	       857 ns/op	     170 B/op	       1 allocs/op
BenchmarkSingleInsertAbsent-4               	 2000000	       651 ns/op	     170 B/op	       1 allocs/op
BenchmarkSingleInsertAbsentSyncMap-4        	 1000000	      1094 ns/op	     187 B/op	       5 allocs/op

```
The experimental results show that segmented locking has the best performance. To explain the test results: `-4` means the test used 4 CPU cores; `2000000` indicates the number of iterations; `857 ns/op` is the average time spent per execution; `170 B/op` is the total heap memory allocated per execution; and `allocs/op` is the number of heap allocations per execution.


![](http://upload-images.jianshu.io/upload_images/1194012-f4205fa15627a3f0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From this perspective, the more iterations, the less time spent, the smaller the total allocated memory, and the fewer allocations, the better the performance. In the performance charts below, the first column—the number of iterations—has been removed, leaving only the remaining three metrics. Therefore, the shorter the bar, the better the performance. The rules for each bar chart below and the meaning of the test results are the same as described here, so they will not be repeated.
```go

// Insert existing key (coarse lock)
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
![](http://upload-images.jianshu.io/upload_images/1194012-b4e71de599377a4a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As can be seen from the figure, `sync.Map` performs worse than the other two in all cases involving `Store`. Whether inserting a non-existent key or an existing key, the sharded-lock implementation currently delivers the best performance.


### 2. Read `Get` Performance Test
```go

// Read existing key (coarse-grained lock)
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

// Read existing key (segmented lock)
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
![](http://upload-images.jianshu.io/upload_images/1194012-13cc2b6ebdcdddda.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As the figure shows, `sync.map` delivers excellent performance for `Load`, far outperforming the other two.


### 3. Performance Test for Concurrent Mixed Inserts and Reads

The next implementation involves concurrent inserts and reads. Due to the particular characteristics of the segmented-lock implementation, the number of segments will affect performance to some extent. Therefore, the following experiment tests the segmented lock with 1, 16, 32, and 256 segments, respectively, to observe how performance changes. The other two thread-safe Map implementations remain unchanged.

Since there is too much concurrent code, it will not be pasted here. If you are interested, you can read it [here](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_map_bench_test/concurrent-map/concurrent_map_bench_test.go)


Here are the test results:

Concurrent insertion of non-existent Key values
```go

BenchmarkMultiInsertDifferentBuiltInMap-4   	 1000000	      2359 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_1_Shard-4     	 1000000	      2039 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_16_Shard-4    	 1000000	      1937 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_32_Shard-4    	 1000000	      1944 ns/op	     330 B/op	      11 allocs/op
BenchmarkMultiInsertDifferent_256_Shard-4   	 1000000	      1991 ns/op	     331 B/op	      11 allocs/op
BenchmarkMultiInsertDifferentSyncMap-4      	 1000000	      3760 ns/op	     635 B/op	      33 allocs/op

```
![](http://upload-images.jianshu.io/upload_images/1194012-bd9d292670764319.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown in the figure, sync.map performs worse than the other two in all cases involving Store. For concurrent insertion of non-existent keys, the number of Segments used by the sharded lock has no impact on performance.


Concurrent insertion of existing key values
```go

BenchmarkMultiInsertSameBuiltInMap-4        	 1000000	      1182 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiInsertSame-4                  	 1000000	      1091 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiInsertSameSyncMap-4           	 1000000	      1809 ns/op	     480 B/op	      30 allocs/op

```
![](http://upload-images.jianshu.io/upload_images/1194012-1d4d34d894512c56.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown in the figure, sync.map performs worse than the other two in all cases involving Store operations.


Concurrent reads of existing Key values
```go

BenchmarkMultiGetSameBuiltInMap-4           	 2000000	       767 ns/op	       0 B/op	       0 allocs/op
BenchmarkMultiGetSame-4                     	 3000000	       481 ns/op	       0 B/op	       0 allocs/op
BenchmarkMultiGetSameSyncMap-4              	 3000000	       464 ns/op	       0 B/op	       0 allocs/op

```
![](http://upload-images.jianshu.io/upload_images/1194012-8f3f2aa8cd1e8fee.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown in the figure, sync.map’s performance for Load far exceeds that of the other two.


Concurrent insertion and reads of nonexistent Key values
```go

BenchmarkMultiGetSetDifferentBuiltInMap-4   	 1000000	      3281 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_1_Shard-4     	 1000000	      3007 ns/op	     338 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_16_Shard-4    	  500000	      2662 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_32_Shard-4    	 1000000	      2732 ns/op	     337 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferent_256_Shard-4   	 1000000	      2788 ns/op	     339 B/op	      12 allocs/op
BenchmarkMultiGetSetDifferentSyncMap-4      	  300000	      8990 ns/op	    1104 B/op	      34 allocs/op

```
![](http://upload-images.jianshu.io/upload_images/1194012-5e55e55f5b84db31.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As the figure shows, sync.map performs worse than the other two in all cases involving Store. For concurrent insertion and reads of non-existent Keys, the number of Segments used by the sharded lock has no impact on performance.


Concurrent insertion and reads of existing Key values
```go

BenchmarkMultiGetSetBlockBuiltInMap-4       	 1000000	      2095 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_1_Shard-4         	 1000000	      1712 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_16_Shard-4        	 1000000	      1730 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_32_Shard-4        	 1000000	      1645 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlock_256_Shard-4       	 1000000	      1619 ns/op	     160 B/op	      10 allocs/op
BenchmarkMultiGetSetBlockSyncMap-4          	  500000	      2660 ns/op	     480 B/op	      30 allocs/op

```
![](http://upload-images.jianshu.io/upload_images/1194012-8ff366f481583cc3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown in the figure, sync.map performs worse than the other two in all cases involving Store. For concurrent inserts and reads of existing Keys, the smaller the Segment partitioning for the sharded lock, the better the performance!


### 4. Delete Performance Test
```go

// Delete existing key (coarse-grained lock)
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

// Delete existing key (sharded lock)
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
Test results:
```go

BenchmarkDeleteBuiltInMap-4                 	10000000	       130 ns/op	       8 B/op	       1 allocs/op
BenchmarkDelete-4                           	20000000	        76.7 ns/op	       8 B/op	       1 allocs/op
BenchmarkDeleteSyncMap-4                    	30000000	        45.4 ns/op	       8 B/op	       0 allocs/op


```
![](http://upload-images.jianshu.io/upload_images/1194012-dab70a82a4826cbb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As the figure shows, sync.map outperforms the other two perfectly on Delete.

## VI. Summary

![](http://upload-images.jianshu.io/upload_images/1194012-c574e8d948c5c276.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This article started with the theoretical foundations of thread safety and discussed several approaches to handling thread safety. It covered concepts related to mutexes and condition variables. We moved from lock-based solutions to lock-free CAS-based solutions. Finally, we analyzed the source code and performance of the newly added sync.map in Go 1.9.

The benchmark results for sync.map, which adopts a lock-free approach, were not as impressive as expected. Except for Load and Delete, where it significantly outperforms the other two, performance for all Store-related operations is lower than the other two Map implementations. That said, there are reasons for this.

Looking at the evolution of Java ConcurrentHashmap:

In JDK 6 and 7, ConcurrentHashmap primarily used Segment to reduce lock granularity. HashMap was divided into multiple Segments. During put, the corresponding Segment needed to be locked; during get, no lock was acquired, and volatile was used to ensure visibility. When global statistics were needed, such as size, it would first try to compute modcount multiple times to determine whether any other thread had performed modifications during those attempts. If not, it would return size directly. If there had been modifications, it would lock all Segments one by one to compute the result.

In JDK 7’s ConcurrentHashmap, when the length became too large, collisions would become very frequent. Add, update, delete, and lookup operations on linked lists would all take a long time and affect performance. Therefore, ConcurrentHashmap was completely rewritten in JDK 8. The code grew from just over 1,000 lines to more than 6,000 lines, and the implementation differs significantly from the original segmented storage design.

The main design changes in JDK 8’s ConcurrentHashmap are as follows: 

- It no longer uses Segment; instead, it uses node, locking the node to reduce lock granularity.
- It introduces the MOVED state. If thread 2 is still putting data during Resize, thread 2 will help with resize.
- It uses three CAS operations to ensure the atomicity of certain node operations, replacing locks with this approach.
- Different values of sizeCtl represent different meanings and play a control role.


As we can see, Go 1.9 abandoned the Segment approach right from its first version and adopted the CAS-based lock-free approach to improve performance. However, it did not design the entire dictionary around something similar to Java’s Node. Still, across the three performance metrics ns/op, B/op, and allocs/op, the overall sync.map is three times worse than a regular native non-thread-safe Map!

That said, I believe Google will continue optimizing this area. After all, there are still several TODOs in the source code. Let’s look forward to the development of future Go versions together; I will continue following it closely as well.


------------------------------------------------------

Reference:  
*Go Concurrent Programming in Practice*     
[Split-Ordered Lists: Lock-Free Extensible Hash Tables](http://people.csail.mit.edu/shanir/publications/Split-Ordered_Lists.pdf)     
[Semaphores are Surprisingly Versatile](http://preshing.com/20150316/semaphores-are-surprisingly-versatile/)  
[Thread Safety](https://zh.wikipedia.org/wiki/%E7%BA%BF%E7%A8%8B%E5%AE%89%E5%85%A8)  
[In-depth Analysis of the Java CAS Principle](http://zl198751.iteye.com/blog/1848575)    
[Java ConcurrentHashMap Summary](https://my.oschina.net/hosee/blog/675884)  

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map\_chapter\_two/](https://halfrost.com/go_map_chapter_two/)