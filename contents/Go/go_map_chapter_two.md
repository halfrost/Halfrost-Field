# 如何设计并实现一个线程安全的 Map ？(下篇)

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a09c131eb02323fe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



在上篇中，我们已经讨论过如何去实现一个 Map 了，并且也讨论了诸多优化点。在下篇中，我们将继续讨论如何实现一个线程安全的 Map。说到线程安全，需要从概念开始说起。


![](http://upload-images.jianshu.io/upload_images/1194012-a50cce475fe9b0b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



线程安全就是如果你的代码块所在的进程中有多个线程在同时运行，而这些线程可能会同时运行这段代码。如果每次运行结果和单线程运行的结果是一样的，而且其他的变量的值也和预期的是一样的，就是线程安全的。

如果代码块中包含了对共享数据的更新操作，那么这个代码块就可能是非线程安全的。但是如果代码块中类似操作都处于临界区之中，那么这个代码块就是线程安全的。


通常有以下两类避免竞争条件的方法来实现线程安全：

#### 第一类 —— 避免共享状态

1. 可重入 [Re-entrancy](https://en.wikipedia.org/wiki/Reentrant_(subroutine)) 

通常在线程安全的问题中，最常见的代码块就是函数。让函数具有线程安全的最有效的方式就是使其可重入。如果某个进程中所有线程都可以并发的对函数进行调用，并且无论他们调用该函数的实际执行情况怎么样，该函数都可以产生预期的结果，那么就可以说这个函数是可重入的。

如果一个函数把共享数据作为它的返回结果或者包含在它返回的结果中，那么该函数就肯定不是一个可重入的函数。任何内含了操作共享数据的代码的函数都是不可重入的函数。

为了实现线程安全的函数，把所有代码都置放于临界区中是可行的。但是互斥量的使用总会耗费一定的系统资源和时间，使用互斥量的过程总会存在各种博弈和权衡。所以请合理使用互斥量保护好那些涉及共享数据操作的代码。

**注意**：可重入只是线程安全的充分不必要条件，**并不是充要条件**。这个反例在下面会讲到。

2. 线程本地存储

如果变量已经被本地化，所以每个线程都有自己的私有副本。这些变量通过子程序和其他代码边界保留它们的值，并且是线程安全的，因为这些变量都是每个线程本地存储的，即使访问它们的代码可能被另一个线程同时执行，依旧是线程安全的。

3. 不可变量

对象一旦初始化以后就不能改变。这意味着只有只读数据被共享，这也实现了固有的线程安全性。可变（不是常量）操作可以通过为它们创建新对象，而不是修改现有对象的方式去实现。 Java，C＃和Python 中的字符串的实现就使用了这种方法。


#### 第二类 —— 线程同步

第一类方法都比较简单，通过代码改造就可以实现。但是如果遇到一定要进行线程中共享数据的情况，第一类方法就解决不了了。这时候就出现了第二类解决方案，利用线程同步的方法来解决线程安全问题。

今天就从线程同步开始说起。



---------------------------------------------


## 一. 线程同步理论

在多线程的程序中，多以共享数据作为线程之间传递数据的手段。由于一个进程所拥有的相当一部分虚拟内存地址都可以被该进程中所有线程共享，所以这些共享数据大多是以内存空间作为载体的。如果两个线程同时读取同一块共享内存但获取到的数据却不同，那么程序很容易出现一些 bug。

为了保证共享数据一致性，最简单并且最彻底的方法就是使该数据成为一个不变量。当然这种绝对的方式在大多数情况下都是不可行的。比如函数中会用到一个计数器，记录函数被调用了几次，这个计数器肯定就不能被设为常量。那这种必须是变量的情况下，还要保证共享数据的一致性，这就引出了临界区的概念。


![](http://upload-images.jianshu.io/upload_images/1194012-ca316bda95dfa59a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


临界区的出现就是为了使该区域只能被串行的访问或者执行。临界区可以是某个资源，也可以是某段代码。保证临界区最有效的方式就是利用线程同步机制。


先介绍2种共享数据同步的方法。


### 1. 互斥量

在同一时刻，只允许一个线程处于临界区之内的约束称为互斥，每个线程在进入临界区之前，都必须先锁定某个对象，只有成功锁定对象的线程才能允许进入临界区，否则就会阻塞。这个对象称为互斥对象或者互斥量。


一般我们日常说的互斥锁就能达到这个目的。

互斥量可以有多个，它们所保护的临界区也可以有多个。先从简单的说起，一个互斥量和一个临界区。

#### (一) 一个互斥量和一个临界区




![](http://upload-images.jianshu.io/upload_images/1194012-08ca14f2697f2413.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




上图就是一个互斥量和一个临界区的例子。当线程1先进入临界区的时候，当前临界区处于未上锁的状态，于是它便先将临界区上锁。线程1获取到临界区里面的值。

这个时候线程2准备进入临界区，由于线程1把临界区上锁了，所以线程2进入临界区失败，线程2由就绪状态转成睡眠状态。线程1继续对临界区的共享数据进行写入操作。

当线程1完成所有的操作以后，线程1调用解锁操作。当临界区被解锁以后，会尝试唤醒正在睡眠的线程2。线程2被唤醒以后，由睡眠状态再次转换成就绪状态。线程2准备进入临界区，当临界区此处处于未上锁的状态，线程2便将临界区上锁。

经过 read、write 一系列操作以后，最终在离开临界区的时候会解锁。


线程在离开临界区的时候，一定要记得把对应的互斥量解锁。这样其他因临界区被上锁而导致睡眠的线程还有机会被唤醒。所以对同一个互斥变量的锁定和解锁必须成对的出现。既不可以对一个互斥变量进行重复的锁定，也不能对一个互斥变量进行多次的解锁。



![](http://upload-images.jianshu.io/upload_images/1194012-2fa9eb813fc632bb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)






如果对一个互斥变量锁定多次可能会导致临界区最终永远阻塞。可能有人会问了，对一个未锁定的互斥变成解锁多次会出现什么问题呢？

在 Go 1.8 之前，虽然对互斥变量解锁多次不会引起任何 goroutine 的阻塞，但是它可能引起一个运行时的恐慌。Go 1.8 之前的版本，是可以尝试恢复这个恐慌的，但是恢复以后，可能会导致一系列的问题，比如重复解锁操作的 goroutine 会永久的阻塞。所以 Go 1.8 版本以后此类运行时的恐慌就变成了不可恢复的了。所以对互斥变量反复解锁就会导致运行时操作，最终程序异常退出。






#### (二) 多个互斥量和一个临界区

在这种情况下，极容易产生线程死锁的情况。所以尽量不要让不同的互斥量所保护的临界区重叠。



![](http://upload-images.jianshu.io/upload_images/1194012-4052c41d1fd1ea70.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图这个例子中，一个临界区中存在2个互斥量：互斥量 A 和互斥量
 B。

线程1先锁定了互斥量 A ，接着线程2锁定了互斥量 B。当线程1在成功锁定互斥量 B 之前永远不会释放 互斥量 A。同样，线程2在成功锁定互斥量 A 之前永远不会释放 互斥量 B。那么这个时候线程1和线程2都因无法锁定自己需要锁定的互斥量，都由 ready 就绪状态转换为 sleep 睡眠状态。这是就产生了线程死锁了。


线程死锁的产生原因有以下几种：

- 1. 系统资源竞争
- 2. 进程推荐顺序非法
- 3. 死锁必要条件（必要条件中任意一个不满足，死锁都不会发生）
(1). 互斥条件
(2). 不剥夺条件
(3). 请求和保持条件
(4). 循环等待条件

想避免线程死锁的情况发生有以下几种方法可以解决：

- 1. 预防死锁
(1). 资源有序分配法（破坏环路等待条件）
(2). 资源原子分配法（破坏请求和保持条件）

- 2. 避免死锁
银行家算法

- 3. 检测死锁
死锁定理（资源分配图化简法），这种方法虽然可以检测，但是无法预防，检测出来了死锁还需要配合解除死锁的方法才行。

- 4. 解决死锁
(1). 剥夺资源
(2). 撤销进程
(3). 试锁定 — 回退
如果在执行一个代码块的时候，需要先后（顺序不定）锁定两个变量，那么在成功锁定其中一个互斥量之后应该使用试锁定的方法来锁定另外一个变量。如果试锁定第二个互斥量失败，就把已经锁定的第一个互斥量解锁，并重新对这两个互斥量进行锁定和试锁定。
![](http://upload-images.jianshu.io/upload_images/1194012-9ae74238e184a46f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
如上图，线程2在锁定互斥量 B 的时候，再试锁定互斥量 A，此时锁定失败，于是就把互斥量 B 也一起解锁。接着线程1会来锁定互斥量 A。此时也不会出现死锁的情况。  
(4). 固定顺序锁定
![](http://upload-images.jianshu.io/upload_images/1194012-c23b2f846af7f04b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
这种方式就是让线程1和线程2都按照相同的顺序锁定互斥量，都按成功锁定互斥量1以后才能去锁定互斥量2 。

#### (三) 多个互斥量和多个临界区



![](http://upload-images.jianshu.io/upload_images/1194012-bfc252ce867af304.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

多个临界区和多个互斥量的情况就要看是否会有冲突的区域，如果出现相互交集的冲突区域，后进临界区的线程就会进入睡眠状态，直到该临界区的线程完成任务以后，再被唤醒。

一般情况下，应该尽量少的使用互斥量。每个互斥量保护的临界区应该在合理范围内并尽量大。但是如果发现多个线程会频繁出入某个较大的临界区，并且它们之间经常存在访问冲突，那么就应该把这个较大的临界区划分的更小一点，并使用不同的互斥量保护起来。这样做的目的就是为了让等待进入同一个临界区的线程数变少，从而降低线程被阻塞的概率，并减少它们被迫进入睡眠状态的时间，这从一定程度上提高了程序的整体性能。

在说另外一个线程同步的方法之前，回答一下文章开头留下的一个疑问：可重入只是线程安全的充分不必要条件，并不是充要条件。这个反例在下面会讲到。


这个问题最关键的一点在于：**mutex 是不可重入的**。


举个例子：

在下面这段代码中，函数increment\_counter是线程安全的，但不是可重入的。

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

上面的代码中，函数increment\_counter 可以在多个线程中被调用，因为有一个互斥锁mutex来同步对共享变量 counter 的访问。但是如果这个函数用在可重入的中断处理程序中，如果在
pthread\_mutex\_lock(&mutex) 和 pthread\_mutex\_unlock(&mutex)
之间产生另一个调用函数 increment\_counter 的中断，则会第二次执行此函数，此时由于 mutex 已被 lock，函数会在 pthread\_mutex\_lock(&mutex) 处阻塞，并且由于 mutex 没有机会被
unlock，阻塞会永远持续下去。简言之，问题在于 [pthread](https://zh.wikipedia.org/wiki/Pthread) 的 mutex 是不可重入的。

解决办法是设定 PTHREAD\_MUTEX\_RECURSIVE 属性。然而对于给出的问题而言，专门使用一个 mutex 来保护一次简单的增量操作显然过于昂贵，因此 [c++11](https://zh.wikipedia.org/wiki/C%2B%2B11) 中的 [原子变量](https://zh.wikipedia.org/w/index.php?title=Atomic_(C%2B%2B%E6%A0%87%E5%87%86%E5%BA%93)&action=edit&redlink=1) 提供了一个可使此函数既线程安全又可重入（而且还更简洁）的替代方案：

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


### 2. 条件变量



## 二. 简单的线程锁方案

大量的利用了 volatile，final，CAS 等lock-free技术来减少锁竞争对于性能的影响。


## 三. 现代线程安全的 Lock - Free 方案 CAS


## 四. ABA 问题


## 五. Lock - Free方案举例



## 五. 性能对比


## 六. 总结





```go

type Map struct {
	mu Mutex
	// 并发读取 map 中一部分的内容是线程安全的，这是不需要
	// 读取的部分自身就是线程安全的，但是 Mutex 信号量的值还是需要存储
	// entry 在并发读取过程中是允许更新的，即使没有 Mutex 信号量，但是更新一个以前删除的 entry 就需要把值拷贝到 dirty Map 中，并且必须要带上 Mutex
	// 只读
	read atomic.Value // readOnly

	// dirty 包含一部分 mutex 持有的 map 数据，为了提高 dirty map 读取速度，它包含了所有没有删除的 entry。已经删除的 entry 不存储在 dirty 中，存储在 clean map 中。
	// 如果 dirty map 是 nil，下一次要写入该 map 的时候将会用 clean map 的浅拷贝初始化它，并忽略掉一些旧的 entry
	dirty map[interface{}]*entry

	// misses 记录了 read map 最后更新的次数，为此需要锁住 mutex 去判断 key 是否出现了。
	// 一旦 misses 值足够去复制 dirty map ，那么 dirty map 就被提升到未被修改状态下的 read map，下次存储就会创建一个新的 dirty map。
	misses int
}

```







------------------------------------------------------

Reference：  
《Go 并发实战编程》     
[Split-Ordered Lists: Lock-Free Extensible Hash Tables](http://people.csail.mit.edu/shanir/publications/Split-Ordered_Lists.pdf)     
[Semaphores are Surprisingly Versatile](http://preshing.com/20150316/semaphores-are-surprisingly-versatile/)  
[线程安全](https://zh.wikipedia.org/wiki/%E7%BA%BF%E7%A8%8B%E5%AE%89%E5%85%A8)


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map\_chapter\_two/](https://halfrost.com/go_map_chapter_two/)