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

对象一旦初始化以后就不能改变。这意味着只有只读数据被共享，这也实现了固有的线程安全性。可变（不是常量）操作可以通过为它们创建新对象，而不是修改现有对象的方式去实现。 Java，C＃和 Python 中的字符串的实现就使用了这种方法。


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


![](http://upload-images.jianshu.io/upload_images/1194012-566294bb7943ad2f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




上图就是一个互斥量和一个临界区的例子。当线程1先进入临界区的时候，当前临界区处于未上锁的状态，于是它便先将临界区上锁。线程1获取到临界区里面的值。

这个时候线程2准备进入临界区，由于线程1把临界区上锁了，所以线程2进入临界区失败，线程2由就绪状态转成睡眠状态。线程1继续对临界区的共享数据进行写入操作。

当线程1完成所有的操作以后，线程1调用解锁操作。当临界区被解锁以后，会尝试唤醒正在睡眠的线程2。线程2被唤醒以后，由睡眠状态再次转换成就绪状态。线程2准备进入临界区，当临界区此处处于未上锁的状态，线程2便将临界区上锁。

经过 read、write 一系列操作以后，最终在离开临界区的时候会解锁。


线程在离开临界区的时候，一定要记得把对应的互斥量解锁。这样其他因临界区被上锁而导致睡眠的线程还有机会被唤醒。所以对同一个互斥变量的锁定和解锁必须成对的出现。既不可以对一个互斥变量进行重复的锁定，也不能对一个互斥变量进行多次的解锁。



![](http://upload-images.jianshu.io/upload_images/1194012-954e90ad96649b88.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




如果对一个互斥变量锁定多次可能会导致临界区最终永远阻塞。可能有人会问了，对一个未锁定的互斥变成解锁多次会出现什么问题呢？

在 Go 1.8 之前，虽然对互斥变量解锁多次不会引起任何 goroutine 的阻塞，但是它可能引起一个运行时的恐慌。Go 1.8 之前的版本，是可以尝试恢复这个恐慌的，但是恢复以后，可能会导致一系列的问题，比如重复解锁操作的 goroutine 会永久的阻塞。所以 Go 1.8 版本以后此类运行时的恐慌就变成了不可恢复的了。所以对互斥变量反复解锁就会导致运行时操作，最终程序异常退出。






#### (二) 多个互斥量和一个临界区

在这种情况下，极容易产生线程死锁的情况。所以尽量不要让不同的互斥量所保护的临界区重叠。


![](http://upload-images.jianshu.io/upload_images/1194012-1755b35e29c8d8ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图这个例子中，一个临界区中存在2个互斥量：互斥量 A 和互斥量
 B。

线程1先锁定了互斥量 A ，接着线程2锁定了互斥量 B。当线程1在成功锁定互斥量 B 之前永远不会释放互斥量 A。同样，线程2在成功锁定互斥量 A 之前永远不会释放互斥量 B。那么这个时候线程1和线程2都因无法锁定自己需要锁定的互斥量，都由 ready 就绪状态转换为 sleep 睡眠状态。这是就产生了线程死锁了。


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

彻底解决死锁有以下几种方法：

- 1. 剥夺资源  
- 2. 撤销进程  
- 3. 试锁定 — 回退  
如果在执行一个代码块的时候，需要先后（顺序不定）锁定两个变量，那么在成功锁定其中一个互斥量之后应该使用试锁定的方法来锁定另外一个变量。如果试锁定第二个互斥量失败，就把已经锁定的第一个互斥量解锁，并重新对这两个互斥量进行锁定和试锁定。


![](http://upload-images.jianshu.io/upload_images/1194012-e5592ec6aba7f454.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



如上图，线程2在锁定互斥量 B 的时候，再试锁定互斥量 A，此时锁定失败，于是就把互斥量 B 也一起解锁。接着线程1会来锁定互斥量 A。此时也不会出现死锁的情况。    
- 4. 固定顺序锁定  


![](http://upload-images.jianshu.io/upload_images/1194012-40be5bc5d521fb37.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这种方式就是让线程1和线程2都按照相同的顺序锁定互斥量，都按成功锁定互斥量1以后才能去锁定互斥量2 。这样就能保证在一个线程完全离开这些重叠的临界区之前，不会有其他同样需要锁定那些互斥量的线程进入到那里。

#### (三) 多个互斥量和多个临界区



![](http://upload-images.jianshu.io/upload_images/1194012-4585db03a0799d1a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



多个临界区和多个互斥量的情况就要看是否会有冲突的区域，如果出现相互交集的冲突区域，后进临界区的线程就会进入睡眠状态，直到该临界区的线程完成任务以后，再被唤醒。

一般情况下，应该尽量少的使用互斥量。每个互斥量保护的临界区应该在合理范围内并尽量大。但是如果发现多个线程会频繁出入某个较大的临界区，并且它们之间经常存在访问冲突，那么就应该把这个较大的临界区划分的更小一点，并使用不同的互斥量保护起来。这样做的目的就是为了让等待进入同一个临界区的线程数变少，从而降低线程被阻塞的概率，并减少它们被迫进入睡眠状态的时间，这从一定程度上提高了程序的整体性能。

在说另外一个线程同步的方法之前，回答一下文章开头留下的一个疑问：可重入只是线程安全的充分不必要条件，并不是充要条件。这个反例在下面会讲到。


这个问题最关键的一点在于：**mutex 是不可重入的**。


举个例子：

在下面这段代码中，函数 increment\_counter 是线程安全的，但不是可重入的。

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

上面的代码中，函数 increment\_counter 可以在多个线程中被调用，因为有一个互斥锁 mutex 来同步对共享变量 counter 的访问。但是如果这个函数用在可重入的中断处理程序中，如果在
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

在 Go 中，互斥量在标准库代码包 sync 中的 Mutex 结构体表示的。sync.Mutex 类型只有两个公开的指针方法，Lock 和 Unlock。前者用于锁定当前的互斥量，后者则用于对当前的互斥量进行解锁。

### 2. 条件变量

在线程同步的方法中，还有一个可以与互斥量相提并论的同步方法，条件变量。

条件变量与互斥量不同，条件变量的作用并不是保证在同一时刻仅有一个线程访问某一个共享数据，而是在对应的共享数据的状态发生变化时，通知其他因此而被阻塞的线程。条件变量总是与互斥变量组合使用的。


这类问题其实很常见。先用生产者消费者的例子来举例。


如果不用条件变量，只用互斥量，来看看会发生什么后果。

生产者线程在完成添加操作之前，其他的生产者线程和消费者线程都无法进行操作。同一个商品也只能被一个消费者消费。

如果只用互斥量，可能会出现2个问题。

- 1. 生产者线程获得了互斥量以后，却发现商品已满，无法再添加新的商品了。于是该线程就会一直等待。新的生产者也进入不了临界区，消费者也无法进入。这时候就死锁了。

- 2. 消费者线程获得了互斥量以后，却发现商品是空的，无法消费了。这个时候该线程也是会一直等待。新的生产者和消费者也都无法进入。这时候同样也死锁了。

这就是只用互斥量无法解决的问题。在多个线程之间，急需一套同步的机制，能让这些线程都协作起来。

条件变量就是大家熟悉的 P - V 操作了。这块大家应该比较熟悉，所以简单的过一下。


P 操作就是 wait 操作，它的意思就是阻塞当前线程，直到收到该条件变量发来的通知。

V 操作就是 signal 操作，它的意思就是让该条件变量向至少一个正在等待它通知的线程发送通知，以表示某个共享数据的状态已经变化。


Broadcast 广播通知，它的意思就是让条件变量给正在等待它通知的所有线程发送通知，以表示某个共享数据的状态已经发生改变。

![](http://upload-images.jianshu.io/upload_images/1194012-ce03974690a19433.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

signal 可以操作多次，如果操作3次，就代表发了3次信号通知。如上图。


![](http://upload-images.jianshu.io/upload_images/1194012-810ad286a9ec378b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

P - V 操作设计美妙之处在于，P 操作的次数与 V 操作的次数是相同的。wait 多少次，signal 对应的有多少次。看上图，这个循环就是这么的奇妙。

#### 生产者消费者问题


![](http://upload-images.jianshu.io/upload_images/1194012-d4ac5739b6c09fb6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个问题可以形象的描述成像上图这样，门卫守护着临界区的安全。售票厅记录着当前 semaphone 的值，它也控制着门卫是否打开临界区。


![](http://upload-images.jianshu.io/upload_images/1194012-7b6f8ce24d0d11f6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

临界区只允许一个线程进入，当已经有一个线程了，再来一个线程，就会被 lock 住。售票厅也会记录当前阻塞的线程数。


![](http://upload-images.jianshu.io/upload_images/1194012-59bbd810186f2db7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当之前的线程离开以后，售票厅就会告诉门卫，允许一个线程进入临界区。


用 P-V 伪代码来描述生产者消费者：

初始变量：

```c

semaphore  mutex = 1; // 临界区互斥信号量
semaphore  empty = n; // 空闲缓冲区个数
semaphore  full = 0;  // 缓冲区初始化为空

```


生产者线程：

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

消费者线程：


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

虽然在生产者和消费者单个程序里面 P，V 并不是成对的，但是整个程序里面 P，V 还是成对的。

#### 读者写者问题——读者优先，写者延迟

读者优先，写进程被延迟。只要有读者在读，后来的读者都可以随意进来读。

![](http://upload-images.jianshu.io/upload_images/1194012-f1bad003e57c69f6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

读者要先进入 rmutex ，查看 readcount，然后修改 readcout 的值，最后再去读数据。对于每个读进程都是写者，都要进去修改 readcount 的值，所以还要单独设置一个 rmutex 互斥访问。

初始变量：

```c

int readcount = 0;     // 读者数量
semaphore  rmutex = 1; // 保证更新 readcount 互斥
semaphore  wmutex = 1; // 保证读者和写着互斥的访问文件

```

读者线程：

```c

reader()
{
  while(1) {
    P(rmutex);              // 准备进入，修改 readcount，“开门”
    if(readcount == 0) {    // 说明是第一个读者
      P(wmutex);            // 拿到”钥匙”，阻止写线程来写
    }
    readcount ++;
    V(rmutex);
    reading;
    P(rmutex);              // 准备离开
    readcount --;
    if(readcount == 0) {    // 说明是最后一个读者
      V(wmutex);            // 交出”钥匙”，让写线程来写
    }
    V(rmutex);              // 离开，“关门”
  }
}

```

写者线程：

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


#### 读者写者问题——写者优先，读者延迟

有写者写，禁止后面的读者来读。在写者前的读者，读完就走。只要有写者在等待，禁止后来的读者进去读。

![](http://upload-images.jianshu.io/upload_images/1194012-a3f5a3cda4ca2e7e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

初始变量：

```c

int readcount = 0;     // 读者数量
semaphore  rmutex = 1; // 保证更新 readcount 互斥
semaphore  wmutex = 1; // 保证读者和写着互斥的访问文件
semaphore  w = 1;      // 用于实现“写者优先”

```

读者线程：

```c

reader()
{
  while(1) {
    P(w);                   // 在没有写者的时候才能请求进入
    P(rmutex);              // 准备进入，修改 readcount，“开门”
    if(readcount == 0) {    // 说明是第一个读者
      P(wmutex);            // 拿到”钥匙”，阻止写线程来写
    }
    readcount ++;
    V(rmutex);
    V(w);
    reading;
    P(rmutex);              // 准备离开
    readcount --;
    if(readcount == 0) {    // 说明是最后一个读者
      V(wmutex);            // 交出”钥匙”，让写线程来写
    }
    V(rmutex);              // 离开，“关门”
  }
}

```

写者线程：

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

#### 哲学家进餐问题


假设有五位哲学家围坐在一张圆形餐桌旁，做以下两件事情之一：吃饭，或者思考。吃东西的时候，他们就停止思考，思考的时候也停止吃东西。餐桌中间有一大碗意大利面，每两个哲学家之间有一只餐叉。因为用一只餐叉很难吃到意大利面，所以假设哲学家必须用两只餐叉吃东西。他们只能使用自己左右手边的那两只餐叉。哲学家就餐问题有时也用米饭和筷子而不是意大利面和餐叉来描述，因为很明显，吃米饭必须用两根筷子。


![](http://upload-images.jianshu.io/upload_images/1194012-d295fb92ead8bcf7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

初始变量：

```c

semaphore  chopstick[5] = {1,1,1,1,1}; // 初始化信号量
semaphore  mutex = 1;                  // 设置取筷子的信号量

```

哲学家线程：

```c

Pi()
{
  do {
    P(mutex);                     // 获得取筷子的互斥量
    P(chopstick[i]);              // 取左边的筷子
    P(chopstick[ (i + 1) % 5 ]);  // 取右边的筷子
    V(mutex);                     // 释放取筷子的信号量
    eat;
    V(chopstick[i]);              // 放回左边的筷子
    V(chopstick[ (i + 1) % 5 ]);  // 放回右边的筷子
    think;
  }while(1);
}

```


综上所述，互斥量可以实现对临界区的保护，并会阻止竞态条件的发生。条件变量作为补充手段，可以让多方协作更加有效率。

在 Go 的标准库中，sync 包里面 sync.Cond 类型代表了条件变量。但是和互斥锁和读写锁不同的是，简单的声明无法创建出一个可用的条件变量，还需要用到 sync.NewCond 函数。

```go

func NewCond( l locker) *Cond

```

\*sync.Cond 类型的方法集合中有3个方法，即 Wait、Signal 和 Broadcast 。

## 二. 简单的线程锁方案

实现线程安全的方案最简单的方法就是加锁了。

先看看 OC 中如何实现一个线程安全的字典吧。

在 Weex 的源码中，就实现了一套线程安全的字典。类名叫 WXThreadSafeMutableDictionary。

```objectivec

/**
 *  @abstract Thread safe NSMutableDictionary
 */
@interface WXThreadSafeMutableDictionary<KeyType, ObjectType> : NSMutableDictionary
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableDictionary* dict;
@end

```

具体实现如下：

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

该线程安全的字典初始化的时候会新建一个并发的 queue。

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

读取的这些方法都用 dispatch\_sync 。

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

和写入相关的方法都用 dispatch\_barrier\_async。

再看看 Go 用互斥量如何实现一个简单的线程安全的 Map 吧。

既然要用到互斥量，那么我们封装一个包含互斥量的 Map 。

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

再简单的实现 Map 的基础方法。

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

实现思想比较简单，在每个操作前都加上 lock，在每个函数结束 defer 的时候都加上 unlock。

这种加锁的方式实现的线程安全的字典，优点是比较简单，缺点是性能不高。文章最后会进行几种实现方法的性能对比，用数字说话，就知道这种基于互斥量加锁方式实现的性能有多差了。

在语言原生就自带线程安全 Map 的语言中，它们的原生底层实现都不是通过单纯的加锁来实现线程安全的，比如 Java 的 ConcurrentHashMap，Go 1.9 新加的 sync.map。

## 三. 现代线程安全的 Lock - Free 方案 CAS

在 Java 的 ConcurrentHashMap 底层实现中大量的利用了 volatile，final，CAS 等 Lock-Free 技术来减少锁竞争对于性能的影响。


在 Go 中也大量的使用了原子操作，CAS 是其中之一。比较并交换即 “Compare And Swap”，简称 CAS。

```go

func CompareAndSwapInt32(addr *int32, old, new int32) (swapped bool)

func CompareAndSwapInt64(addr *int64, old, new int64) (swapped bool)

func CompareAndSwapUint32(addr *uint32, old, new uint32) (swapped bool)

func CompareAndSwapUint64(addr *uint64, old, new uint64) (swapped bool)

func CompareAndSwapUintptr(addr *uintptr, old, new uintptr) (swapped bool)

func CompareAndSwapPointer(addr *unsafe.Pointer, old, new unsafe.Pointer) (swapped bool)

```

CAS 会先判断参数 addr 指向的被操作值与参数 old 的值是否相等。如果相当，相应的函数才会用参数 new 代表的新值替换旧值。否则，替换操作就会被忽略。


![](http://upload-images.jianshu.io/upload_images/1194012-7c1aa0c3d7ce2c51.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





这一点与互斥锁明显不同，CAS 总是假设被操作的值未曾改变，并一旦确认这个假设成立，就立即进行值的替换。而互斥锁的做法就更加谨慎，总是先假设会有并发的操作修改被操作的值，并需要使用锁将相关操作放入临界区中加以保护。可以说互斥锁的做法趋于悲观，CAS 的做法趋于乐观，类似乐观锁。

CAS 做法最大的优势在于可以不创建互斥量和临界区的情况下，完成并发安全的值替换操作。这样大大的减少了线程同步操作对程序性能的影响。当然 CAS 也有一些缺点，缺点下一章会提到。

接下来看看源码是如何实现的。以下以64位为例，32位类似。

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


上述实现最关键的一步就是 CMPXCHG。


查询 Intel 的[文档](http://x86.renejeschke.de/html/file_module_x86_id_41.html)

![](http://upload-images.jianshu.io/upload_images/1194012-db7a028dd6f9b8ed.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

文档上说：

比较 eax 和目的操作数(第一个操作数)的值，如果相同，ZF 标志被设置，同时源操作数(第二个操作)的值被写到目的操作数，否则，清
ZF 标志，并且把目的操作数的值写回 eax。

于是也就得出了 CMPXCHG 的工作原理：

比较 \_old 和 (\*\_\_ptr) 的值，如果相同，ZF 标志被设置，同时
 \_new 的值被写到 (\*\_\_ptr)，否则，清 ZF 标志，并且把 (\*\_\_ptr) 的值写回 \_old。



![](http://upload-images.jianshu.io/upload_images/1194012-153c43829be0a454.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




在 Intel 平台下，会用 LOCK CMPXCHG 来实现，这里的 LOCK 是内存总线锁，所谓总线锁就是使用 CPU 提供的一个LOCK＃信号，当一个处理器在总线上输出此信号时，其他处理器的请求将被阻塞住，那么该 CPU 可以独占使用共享内存。

Intel 的手册对 LOCK 前缀的说明如下：
- 1. 确保对内存的读-改-写操作原子执行。在 Pentium 及 Pentium 之前的处理器中，带有 LOCK 前缀的指令在执行期间会锁住总线，使得其他处理器暂时无法通过总线访问内存。很显然，这会带来昂贵的开销。从 Pentium 4，Intel Xeon 及 P6 处理器开始，Intel 在原有总线锁的基础上做了一个很有意义的优化：如果要访问的内存区域（area of memory）在 LOCK 前缀指令执行期间已经在处理器内部的缓存中被锁定（即包含该内存区域的缓存行当前处于独占或以修改状态），并且该内存区域被完全包含在单个缓存行（cache line）中，那么处理器将直接执行该指令。由于在指令执行期间该缓存行会一直被锁定，其它处理器无法读/写该指令要访问的内存区域，因此能保证指令执行的原子性。这个操作过程叫做缓存锁定（cache locking），缓存锁定将大大降低 LOCK 前缀指令的执行开销，但是当多处理器之间的竞争程度很高或者指令访问的内存地址未对齐时，仍然会锁住总线。
- 2. 禁止该指令与之前和之后的读和写指令重排序。
- 3. 把写缓冲区中的所有数据刷新到内存中。

用 CAS 方式来保证线程安全的方式就比用互斥锁的方式效率要高很多。

## 四. ABA 问题

虽然 CAS 的效率高，但是依旧存在3大问题。

### 1. ABA 问题



![](http://upload-images.jianshu.io/upload_images/1194012-7649918f92e26fb0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



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
[JAVA CAS原理深度分析](http://zl198751.iteye.com/blog/1848575)    

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map\_chapter\_two/](https://halfrost.com/go_map_chapter_two/)