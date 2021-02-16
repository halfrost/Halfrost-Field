# ReactiveCocoa 中 RACScheduler 是如何封装 GCD 的

![](https://img.halfrost.com/Blog/ArticleTitleImage/37_0_.png)



### 前言

在使用ReactiveCocoa 过程中，[Josh Abernathy](https://github.com/joshaber)和[Justin Spahr-Summers](https://github.com/jspahrsummers) 两位大神为了能让RAC的使用者更畅快的在沉浸在FRP的世界里，更好的进行并发编程，于是就对GCD进行了一次封装，并与RAC的各大组件进行了完美的整合。

自从有了RACScheduler以后，使整个RAC并发编程的代码里面更加和谐统一，更加顺手，更加“ReactiveCocoa”。



### 目录

- 1.RACScheduler是如何封装GCD的
- 2.RACScheduler的一些子类
- 3.RACScheduler是如何“取消”并发任务的
- 4.RACScheduler是如何和RAC其他组件进行完美整合的




#### 一. RACScheduler是如何封装GCD的

RACScheduler在ReactiveCocoa中到底是干嘛的呢？处于什么地位呢？官方给出的定义如下：

```vim

Schedulers are used to control when and where work is performed

```

RACScheduler在ReactiveCocoa中是用来控制一个任务，何时何地被执行。它主要是用来解决ReactiveCocoa中并发编程的问题的。

RACScheduler的实质是对GCD的封装，底层就是GCD实现的。

要分析RACScheduler，先来回顾一下GCD。


![](https://img.halfrost.com/Blog/ArticleImage/37_1.png)





众所周知，在GCD中，Dispatch Queue主要分为2类，Serial Dispatch Queue 和 Concurrent Dispatch Queue 。其中Serial Dispatch Queue是等待现在执行中处理结束的队列，Concurrent Dispatch Queue是不等待现在执行中处理结束的队列。

生成Dispatch Queue的方法也有2种，第一种方式是通过GCD的API生成Dispatch Queue。


生成Serial Dispatch Queue

```objectivec

dispatch_queue_t serialDispatchQueue = dispatch_queue_create("com.gcd.SerialDispatchQueue", DISPATCH_QUEUE_SERIAL);
    


```

生成Concurrent Dispatch Queue

```objectivec


dispatch_queue_t concurrentDispatchQueue = dispatch_queue_create("com.gcd.ConcurrentDispatchQueue", DISPATCH_QUEUE_CONCURRENT);

```

第二种方法是直接获取系统提供的Dispatch Queue。系统提供的也分为2类，Main Dispatch Queue 和 Global Dispatch Queue。Main Dispatch Queue 对应着是Serial Dispatch Queue，Global Dispatch Queue 对应着是Concurrent Dispatch Queue。

Global Dispatch Queue主要分为8种。

![](https://img.halfrost.com/Blog/ArticleImage/37_2.png)




首先是以下4种，分别是优先级对应Qos的情况。

```objectivec

  - DISPATCH_QUEUE_PRIORITY_HIGH:         QOS_CLASS_USER_INITIATED
  - DISPATCH_QUEUE_PRIORITY_DEFAULT:      QOS_CLASS_DEFAULT
  - DISPATCH_QUEUE_PRIORITY_LOW:          QOS_CLASS_UTILITY
  - DISPATCH_QUEUE_PRIORITY_BACKGROUND:   QOS_CLASS_BACKGROUND

```

其次是，是否支持 overcommit。加上上面4个优先级，所以一共8种Global Dispatch Queue。带有 overcommit 的队列表示每当有任务提交时，系统都会新开一个线程处理，这样就不会造成某个线程过载(overcommit)。

![](https://img.halfrost.com/Blog/ArticleImage/37_3.png)




回到RACScheduler中来，RACScheduler既然是对GCD的封装，那么上述说的这些类型也都有其一一对应的封装。


```objectivec

typedef enum : long {
     RACSchedulerPriorityHigh = DISPATCH_QUEUE_PRIORITY_HIGH,
     RACSchedulerPriorityDefault = DISPATCH_QUEUE_PRIORITY_DEFAULT,
     RACSchedulerPriorityLow = DISPATCH_QUEUE_PRIORITY_LOW,
     RACSchedulerPriorityBackground = DISPATCH_QUEUE_PRIORITY_BACKGROUND,
} RACSchedulerPriority;


```

首先是RACScheduler中的优先级，这里只封装了4种，也是分别对应GCD中的DISPATCH\_QUEUE\_PRIORITY\_HIGH，DISPATCH\_QUEUE\_PRIORITY\_DEFAULT，DISPATCH\_QUEUE\_PRIORITY\_LOW，DISPATCH\_QUEUE\_PRIORITY\_BACKGROUND。


RACScheduler有6个类方法，都是用来生成一个queue的。

```objectivec

+ (RACScheduler *)immediateScheduler;
+ (RACScheduler *)mainThreadScheduler;

+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name;
+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority;
+ (RACScheduler *)scheduler;

+ (RACScheduler *)currentScheduler;



```


接下来依次分析一下它们的底层实现。


![](https://img.halfrost.com/Blog/ArticleImage/37_4.png)




##### 1. immediateScheduler

![](https://img.halfrost.com/Blog/ArticleImage/37_5.png)



```objectivec


+ (instancetype)immediateScheduler {
    static dispatch_once_t onceToken;
    static RACScheduler *immediateScheduler;
    dispatch_once(&onceToken, ^{
        immediateScheduler = [[RACImmediateScheduler alloc] init];
    });
    
    return immediateScheduler;
}


```

immediateScheduler底层实现就是生成了一个RACImmediateScheduler的单例。

RACImmediateScheduler 是继承自RACScheduler。

```objectivec

@interface RACImmediateScheduler : RACScheduler
@end

```

在RACScheduler中，每个种类的RACScheduler都会有一个name属性，名字也算是他们的标示。RACImmediateScheduler的name是@"com.ReactiveCocoa.RACScheduler.immediateScheduler"


RACImmediateScheduler的作用和它的名字一样，是立即执行闭包里面的任务。


```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    block();
    return nil;
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(block != NULL);
    
    [NSThread sleepUntilDate:date];
    block();
    
    return nil;
}


```

在schedule:方法中，直接调用执行入参block( )闭包。在after: schedule:方法中，线程先睡眠，直到date的时刻，再醒过来执行入参block( )闭包。

```objectivec

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    NSCAssert(NO, @"+[RACScheduler immediateScheduler] does not support %@.", NSStringFromSelector(_cmd));
    return nil;
}


```

当然RACImmediateScheduler是不可能支持after: repeatingEvery: withLeeway: schedule:方法的。因为它的定义就是立即执行的，不应该repeat。


```objectivec

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock {
    
    for (__block NSUInteger remaining = 1; remaining > 0; remaining--) {
        recursiveBlock(^{
            remaining++;
        });
    }
    return nil;
}

```

RACImmediateScheduler的scheduleRecursiveBlock:方法中只要recursiveBlock闭包存在，就会无限递归调用执行，除非recursiveBlock不存在了。


##### 2. mainThreadScheduler


![](https://img.halfrost.com/Blog/ArticleImage/37_6.png)




mainThreadScheduler也是一个类型是RACTargetQueueScheduler的单例。

```objectivec

+ (instancetype)mainThreadScheduler {
    static dispatch_once_t onceToken;
    static RACScheduler *mainThreadScheduler;
    dispatch_once(&onceToken, ^{
        mainThreadScheduler = [[RACTargetQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
    });
    
    return mainThreadScheduler;
}


```

mainThreadScheduler的名字是@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler"。


RACTargetQueueScheduler继承自RACQueueScheduler

```objectivec


@interface RACTargetQueueScheduler : RACQueueScheduler
- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue;
@end

```

在RACTargetQueueScheduler中，只有一个初始化方法。

```objectivec

- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
    NSCParameterAssert(targetQueue != NULL);
    
    if (name == nil) {
        name = [NSString stringWithFormat:@"com.ReactiveCocoa.RACTargetQueueScheduler(%s)", dispatch_queue_get_label(targetQueue)];
    }
    
    dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
    if (queue == NULL) return nil;
    
    dispatch_set_target_queue(queue, targetQueue);
    
    return [super initWithName:name queue:queue];
}

```

先新建了一个queue，name是@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler"，类型是Serial Dispatch Queue 类型的，然后调用了dispatch\_set\_target\_queue方法。


所以重点就在dispatch\_set\_target\_queue方法里面了。


dispatch\_set\_target\_queue方法主要有两个目的：一是设置dispatch\_queue\_create创建队列的优先级，二是建立队列的执行阶层。

- 当使用dispatch\_queue\_create创建队列的时候，不管是串行还是并行，它们的优先级都是DISPATCH\_QUEUE\_PRIORITY\_DEFAULT级别，而这个API就是可以设置队列的优先级。 
 
举个例子：  

```objectivec

dispatch_queue_t serialQueue = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
//注意：被设置优先级的队列是第一个参数。
dispatch_set_target_queue(serialQueue, globalQueue);

```
通过上面的代码，就把将serailQueue设置成DISPATCH\_QUEUE\_PRIORITY\_HIGH。

- 使用这个dispatch\_set\_target\_queue方法可以设置队列执行阶层，例如dispatch\_set\_target\_queue(queue, targetQueue);
这样设置时，相当于将queue指派给targetQueue，如果targetQueue是串行队列，则queue是串行执行的；如果targetQueue是并行队列，那么queue是并行的。

举个例子：

```objectivec

    dispatch_queue_t targetQueue = dispatch_queue_create("targetQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_queue_t queue1 = dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("queue2", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_set_target_queue(queue1, targetQueue);
    dispatch_set_target_queue(queue2, targetQueue);
    
    dispatch_async(queue1, ^{
        NSLog(@"queue1 1");
    });
    dispatch_async(queue1, ^{
        NSLog(@"queue1 2");
    });
    dispatch_async(queue2, ^{
        NSLog(@"queue2 1");
    });
    dispatch_async(queue2, ^{
        NSLog(@"queue2 2");
    });
    dispatch_async(targetQueue, ^{
        NSLog(@"target queue");
    });



```

如果targetQueue为Serial Dispatch Queue，那么输出结果必定如下：


```vim

queue1 1
queue1 2
queue2 1
queue2 2
target queue


```

如果targetQueue为Concurrent Dispatch Queue，那么输出结果可能如下：

```vim


queue1 1
queue2 1
queue1 2
target queue
queue2 2


```


回到RACTargetQueueScheduler中来，在这里传进来的入参是dispatch\_get\_main\_queue( )，这是一个Serial Dispatch Queue，这里再调用dispatch\_set\_target\_queue方法，相当于把queue的优先级设置的和main\_queue一致。


##### 3. scheduler

![](https://img.halfrost.com/Blog/ArticleImage/37_7.png)





以下三个方法实质是同一个方法。


```objectivec


+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name;
+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority;
+ (RACScheduler *)scheduler;

```

```objectivec


+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name {
    return [[RACTargetQueueScheduler alloc] initWithName:name targetQueue:dispatch_get_global_queue(priority, 0)];
}

+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority {
    return [self schedulerWithPriority:priority name:@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"];
}

+ (instancetype)scheduler {
    return [self schedulerWithPriority:RACSchedulerPriorityDefault];
}


```

通过源码我们能知道，scheduler这一系列的三个方法，是创建了一个 Global Dispatch Queue，对应的属于Concurrent Dispatch Queue。

schedulerWithPriority: name:方法可以指定线程的优先级和名字。

schedulerWithPriority:方法只能执行优先级，名字为默认的@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"。

scheduler方法创建出来的queue的优先级是默认的，名字也是默认的@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"。


**注意**，scheduler和mainThreadScheduler，immediateScheduler这两个单例不同的是，scheduler每次都会创建一个新的Concurrent Dispatch Queue。


##### 4. currentScheduler

![](https://img.halfrost.com/Blog/ArticleImage/37_8.png)





```objectivec

+ (instancetype)currentScheduler {
    RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
    if (scheduler != nil) return scheduler;
    if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;
    return nil;
}


```


首先，在ReactiveCocoa 中定义了这么一个key，@"RACSchedulerCurrentSchedulerKey"，这个用来从线程字典里面存取出对应的RACScheduler。

```objectivec

NSString * const RACSchedulerCurrentSchedulerKey = @"RACSchedulerCurrentSchedulerKey";

```

在currentScheduler这个方法里面看到的是从线程字典里面取出一个RACScheduler。至于什么时候存的，下面会解释到。

如果能从线程字典里面取出一个RACScheduler，就返回取出的RACScheduler。如果字典里面没有，再判断当前的scheduler是否是在主线程上。

```objectivec

+ (BOOL)isOnMainThread {
    return [NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue] || [NSThread isMainThread];
}


```

判断方法如上，只要是NSOperationQueue在mainQueue上，或者NSThread是主线程，都算是在主线程上。

如果是在主线程上，就返回mainThreadScheduler。
如果既不在主线程上，线程字典里面也找不到对应key值对应的value，那么就返回nil。


RACScheduler除了有6个类方法，还有4个实例方法：

```objectivec

- (RACDisposable *)schedule:(void (^)(void))block;
- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block;
- (RACDisposable *)afterDelay:(NSTimeInterval)delay schedule:(void (^)(void))block;
- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block;


```

这4个方法其实从名字上就知道是用来干嘛的。

schedule:是为RACScheduler添加一个任务，入参是一个闭包。

after: schedule:是为RACScheduler添加一个定时任务，在date时间之后才执行任务。

afterDelay: schedule:是为RACScheduler添加一个延时执行的任务，延时delay时间之后才执行任务。

after: repeatingEvery: withLeeway: schedule:是为RACScheduler添加一个定时任务，在date时间之后才开始执行，然后每隔interval秒执行一次任务。

这四个方法会分别在RACScheduler的各个子类里面进行重写。

比如之前提到的immediateScheduler，schedule:方法中会直接立即执行闭包。after: schedule:方法中添加一个定时任务，在date时间之后才执行任务。after: repeatingEvery: withLeeway: schedule:这个方法在RACImmediateScheduler中就直接返回nil。

还有其他子类在下面会分析这4个方法的实现。


另外还有最后3个方法

```objectivec

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock;
- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable
- (void)performAsCurrentScheduler:(void (^)(void))block;


```

前两个方法是实现RACSequence中signalWithScheduler:方法的，具体分析见[这篇文章](http://www.jianshu.com/p/5c2119b3f2eb)

performAsCurrentScheduler:方法是在RACQueueScheduler中使用到了，在下面子类分析里面详细分析。


#### 二. RACScheduler的一些子类

RACScheduler总共有以下5个子类。


![](https://img.halfrost.com/Blog/ArticleImage/37_9.png)


##### 1. RACTestScheduler


![](https://img.halfrost.com/Blog/ArticleImage/37_10.png)




这个类主要是一个测试类，主要用在单元测试中，它是用来验证异步调用没有花费大量的时间等待。RACTestScheduler也可以用在多线程当中，当时一次只能在排队的方法队列中选择一个方法执行。


```objectivec

@interface RACTestSchedulerAction : NSObject
@property (nonatomic, copy, readonly) NSDate *date;
@property (nonatomic, copy, readonly) void (^block)(void);
@property (nonatomic, strong, readonly) RACDisposable *disposable;

- (id)initWithDate:(NSDate *)date block:(void (^)(void))block;
@end

```


在单元测试中，ReactiveCocoa为了方便比较每个方法的调用，新建了一个RACTestSchedulerAction对象，用来更加方便的比较和描述测试的全过程。RACTestSchedulerAction的定义如上。现在再来解释一下参数。

date是一个时间，时间主要是用来比较和决定下一次该轮到哪个闭包要开始执行了。

void (^block)(void)闭包是RACScheduler中的一个任务。

disposable是控制一个action是否可以执行的。一旦disposed了，那么这个action就不会被执行。

initWithDate: block: 方法是初始化一个新的action。

在单元测试过程中，需要调用step方法来进行查看每次调用闭包的情况。


```objectivec

- (void)step {
    [self step:1];
}

- (void)stepAll {
    [self step:NSUIntegerMax];
}

```

step和stepAll方法都是调用step:方法。step只是执行一次RACScheduler中的任务，stepAll是执行所有的RACScheduler中的任务。既然都是调用step:，那接下来分析一下step:的具体实现。


```objectivec

- (void)step:(NSUInteger)ticks {
    @synchronized (self) {
        for (NSUInteger i = 0; i < ticks; i++) {
            const void *actionPtr = NULL;
            if (!CFBinaryHeapGetMinimumIfPresent(self.scheduledActions, &actionPtr)) break;
            
            RACTestSchedulerAction *action = (__bridge id)actionPtr;
            CFBinaryHeapRemoveMinimumValue(self.scheduledActions);
            
            if (action.disposable.disposed) continue;
            
            RACScheduler *previousScheduler = RACScheduler.currentScheduler;
            NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = self;
            
            action.block();
            
            if (previousScheduler != nil) {
                NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = previousScheduler;
            } else {
                [NSThread.currentThread.threadDictionary removeObjectForKey:RACSchedulerCurrentSchedulerKey];
            }
        }
    }
}


```

step:的实现主要就是一个for循环。循环的次数就是入参ticks决定的。首先const void *actionPtr是一个指向函数的指针。在上述实现中有一个很重要的函数——CFBinaryHeapGetMinimumIfPresent。该函数的原型如下：

```objectivec

Boolean CFBinaryHeapGetMinimumIfPresent(CFBinaryHeapRef heap, const void **value)

```

这个函数的主要作用的是在二分堆heap中查找一个最小值。

```objectivec

static CFComparisonResult RACCompareScheduledActions(const void *ptr1, const void *ptr2, void *info) {
    RACTestSchedulerAction *action1 = (__bridge id)ptr1;
    RACTestSchedulerAction *action2 = (__bridge id)ptr2;
    return CFDateCompare((__bridge CFDateRef)action1.date, (__bridge CFDateRef)action2.date, NULL);
}

```

比较规则如上，就是比较两者的date的值。从二分堆中找出这样一个最小值，对应的就是scheduler中的任务。如果最小值有几个相等最小值，就随机返回一个最小值。返回的函数放在actionPtr中。整个函数的返回值是一个BOOL值，如果二分堆不为空，能找到最小值就返回YES，如果二分堆为空，就找不到最小值了，就返回NO。

stepAll方法里面传入了NSUIntegerMax，这个for循环也不会死循环，因为到堆中所有的任务都执行完成之后，CFBinaryHeapGetMinimumIfPresent返回NO，就会执行break，跳出循环。


这里会把currentScheduler保存到线程字典里面。接着会执行action.block，执行任务。

```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != nil);
    
    @synchronized (self) {
        NSDate *uniqueDate = [NSDate dateWithTimeIntervalSinceReferenceDate:self.numberOfDirectlyScheduledBlocks];
        self.numberOfDirectlyScheduledBlocks++;
        
        RACTestSchedulerAction *action = [[RACTestSchedulerAction alloc] initWithDate:uniqueDate block:block];
        CFBinaryHeapAddValue(self.scheduledActions, (__bridge void *)action);
        
        return action.disposable;
    }
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(block != nil);
    
    @synchronized (self) {
        RACTestSchedulerAction *action = [[RACTestSchedulerAction alloc] initWithDate:date block:block];
        CFBinaryHeapAddValue(self.scheduledActions, (__bridge void *)action);
        
        return action.disposable;
    }
}


```

schedule:方法里面会累加numberOfDirectlyScheduledBlocks值，这个值也会初始化成时间，以便比较各个方法该调度的时间。numberOfDirectlyScheduledBlocks最终会代表总共有多少个block任务产生了。然后用CFBinaryHeapAddValue加入到堆中。

after:schedule:就是直接新建RACTestSchedulerAction对象，然后再用CFBinaryHeapAddValue把block闭包加入到堆中。

after: repeatingEvery: withLeeway: schedule:同样也是新建RACTestSchedulerAction对象，然后再用CFBinaryHeapAddValue把block闭包加入到堆中。

##### 2. RACSubscriptionScheduler

RACSubscriptionScheduler是RACScheduler最后一个单例。RACScheduler中唯一的三个单例现在就齐全了：RACImmediateScheduler，RACTargetQueueScheduler ，RACSubscriptionScheduler。

```objectivec


+ (instancetype)subscriptionScheduler {
    static dispatch_once_t onceToken;
    static RACScheduler *subscriptionScheduler;
    dispatch_once(&onceToken, ^{
        subscriptionScheduler = [[RACSubscriptionScheduler alloc] init];
    });
    
    return subscriptionScheduler;
}

```

RACSubscriptionScheduler 的名字是@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"

```objectivec

- (id)init {
    self = [super initWithName:@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"];
    if (self == nil) return nil;
    _backgroundScheduler = [RACScheduler scheduler];  
    return self;
}

```

RACSubscriptionScheduler初始化的时候会新建一个Global Dispatch Queue。


```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];
    block();
    return nil;
}

```

如果RACScheduler.currentScheduler为nil就用backgroundScheduler去调用block闭包，否则就执行block闭包。


```objectivec

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
    RACScheduler *scheduler = RACScheduler.currentScheduler ?: self.backgroundScheduler;
    return [scheduler after:date schedule:block];
}

```

```objectivec

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    RACScheduler *scheduler = RACScheduler.currentScheduler ?: self.backgroundScheduler;
    return [scheduler after:date repeatingEvery:interval withLeeway:leeway schedule:block];
}



```



两个after方法都有取出RACScheduler.currentScheduler，如果为空就用self.backgroundScheduler去调用各自的after的方法。


RACSubscriptionScheduler中的backgroundScheduler的意义就在此，当RACScheduler.currentScheduler不存在的时候就会替换成self.backgroundScheduler。

##### 3. RACImmediateScheduler

这个子类在分析immediateScheduler方法的时候，详细分析过了，这里不再赘述。

##### 4. RACQueueScheduler


![](https://img.halfrost.com/Blog/ArticleImage/37_11.png)





```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    RACDisposable *disposable = [[RACDisposable alloc] init];
    
    dispatch_async(self.queue, ^{
        if (disposable.disposed) return;
        [self performAsCurrentScheduler:block];
    });
    
    return disposable;
}

```

schedule:会调用performAsCurrentScheduler:方法。

```objectivec

- (void)performAsCurrentScheduler:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    RACScheduler *previousScheduler = RACScheduler.currentScheduler;
    NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = self;
    
    @autoreleasepool {
        block();
    }
    
    if (previousScheduler != nil) {
        NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = previousScheduler;
    } else {
        [NSThread.currentThread.threadDictionary removeObjectForKey:RACSchedulerCurrentSchedulerKey];
    }
}



```

performAsCurrentScheduler:方法会先在调用block( )之前，把当前的scheduler存入线程字典中。

试想，如果现在在一个Concurrent Dispatch Queue中，在执行block( )之前需要先切换线程，切换到当前scheduler中。当执行完block闭包之后，previousScheduler如果不为nil，那么就还原现场，线程字典里面再存回原来的scheduler，反之previousScheduler为nil，那么就移除掉线程字典里面的key。


这里需要值得**注意**的是：

scheduler本质其实是一个quene，并不是一个线程。它只能保证里面的线程都是串行执行的，但是它不能保证每个线程不一定都是在同一个线程里面执行。

如上面这段performAsCurrentScheduler:的实现所表现的那样。所以
在scheduler使用Core Data很容易崩溃，很可能跑到子线程上面去了。一旦写数据的时候到了子线程上，很容易就Crash了。一定要记得回到main queue上。

```objectivec

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(block != NULL);
    
    RACDisposable *disposable = [[RACDisposable alloc] init];
    
    dispatch_after([self.class wallTimeWithDate:date], self.queue, ^{
        if (disposable.disposed) return;
        [self performAsCurrentScheduler:block];
    });
    
    return disposable;
}

```

在after中调用dispatch\_after方法，经过date时间之后再调用performAsCurrentScheduler:。

wallTimeWithDate:的实现如下：

```objectivec

+ (dispatch_time_t)wallTimeWithDate:(NSDate *)date {
    NSCParameterAssert(date != nil);
    
    double seconds = 0;
    double frac = modf(date.timeIntervalSince1970, &seconds);
    
    struct timespec walltime = {
        .tv_sec = (time_t)fmin(fmax(seconds, LONG_MIN), LONG_MAX),
        .tv_nsec = (long)fmin(fmax(frac * NSEC_PER_SEC, LONG_MIN), LONG_MAX)
    };
    
    return dispatch_walltime(&walltime, 0);
}

```

dispatch\_walltime函数是由POSIX中使用的struct timespec类型的时间得到dispatch\_time\_t类型的值。dispatch\_time函数通常用于计算相对时间，而dispatch\_walltime函数用于计算绝对时间。

这段代码其实很简单，就是把date的时间转换成一个dispatch\_time\_t类型的。由NSDate类对象获取能传递给dispatch\_after函数的dispatch\_time\_t类型的值。  



```objectivec

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
    NSCParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);
    NSCParameterAssert(block != NULL);
    
    uint64_t intervalInNanoSecs = (uint64_t)(interval * NSEC_PER_SEC);
    uint64_t leewayInNanoSecs = (uint64_t)(leeway * NSEC_PER_SEC);
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(timer, [self.class wallTimeWithDate:date], intervalInNanoSecs, leewayInNanoSecs);
    dispatch_source_set_event_handler(timer, block);
    dispatch_resume(timer);
    
    return [RACDisposable disposableWithBlock:^{
        dispatch_source_cancel(timer);
    }];
}



```

after: repeatingEvery: withLeeway: schedule:方法里面的实现就是用GCD在self.queue上创建了一个Timer，时间间隔是interval，修正时间是leeway。

leeway这个参数是为dispatch source指定一个期望的定时器事件精度，让系统能够灵活地管理并唤醒内核。例如系统可以使用leeway值来提前或延迟触发定时器，使其更好地与其它系统事件结合。创建自己的定时器时，应该尽量指定一个leeway值。不过就算指定leeway值为0，也不能完完全全期望定时器能够按照精确的纳秒来触发事件。

这个定时器在interval执行入参闭包。在取消任务的时候调用dispatch\_source\_cancel取消定时器timer。



##### 5. RACTargetQueueScheduler

这个子类在分析mainThreadScheduler方法的时候，详细分析过了，这里不再赘述。


#### 三. RACScheduler是如何“取消”并发任务的


![](https://img.halfrost.com/Blog/ArticleImage/37_12.png)




既然RACScheduler是对GCD的封装，那么在GCD的上层可以实现一些GCD所无法完成的“特性”。这里的“特性”是打引号的，因为底层是GCD，上层的特性只能通过一些特殊手段来实现看似是新的特性。在这一点上，RACScheduler就实现了GCD没有的特性——“取消”任务。


Operation Queues ：
相对 GCD来说，使用 Operation Queues 会增加一点点额外的开销，但是却换来了非常强大的灵活性和功能，它可以给 operation 之间添加依赖关系、取消一个正在执行的 operation 、暂停和恢复 operation queue 等；

GCD：
是一种更轻量级的，以 FIFO的顺序执行并发任务的方式，使用 GCD时我们可以并不关心任务的调度情况，而让系统帮我们自动处理。但是 GCD的缺陷也是非常明显的，想要给任务之间添加依赖关系、取消或者暂停一个正在执行的任务时就会变得非常棘手。

既然GCD不方便取消一个任务，那么RACScheduler是怎么做到的呢？

这就体现在RACQueueScheduler上。回头看看RACQueueScheduler的schedule:实现 和 after: schedule:实现。

最核心的代码:

```objectivec

 dispatch_async(self.queue, ^{
      if (disposable.disposed) return;
      [self performAsCurrentScheduler:block];
 });

```

在调用performAsCurrentScheduler:之前，加了一个判断，判断当前是否取消了任务，如果取消了任务，就return，不会调用block闭包。这样就实现了取消任务的“假象”。



#### 四. RACScheduler是如何和RAC其他组件进行完美整合的

在整个ReactiveCocoa中，利用RACScheduler实现了很多操作，和RAC是深度整合的。这里就来总结总结ReactiveCocoa中总共有哪些地方用到了RACScheduler。


 ![](https://img.halfrost.com/Blog/ArticleImage/37_13.png)






在ReactiveCocoa 中全局搜索RACScheduler，遍历完所有库，RACScheduler就用在以下10个类中。下面就来看看是如何用在这些地方的。



从下面这些地方使用了Scheduler中，我们就可以了解到哪些操作是在子线程，哪些是在主线程。区分出了这些，对于线程不安全的操作，我们就能心有成足的处理好它们，让它们回到主线程中去操作，这样就可以减少很多莫名的Crash。这些Crash都是因为线程问题导致的。




##### 1. 在RACCommand中

```objectivec

- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock


```

这个方法十分复杂，里面用到了RACScheduler.immediateScheduler，deliverOn:RACScheduler.mainThreadScheduler。具体的源码分析会在下一篇RACCommand源码分析里面详细分析。

```objectivec

- (RACSignal *)execute:(id)input

```

在这个方法中，会调用subscribeOn:RACScheduler.mainThreadScheduler。

##### 2. 在RACDynamicSignal中

```objectivec


- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];
    
    if (self.didSubscribe != NULL) {
        RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
            RACDisposable *innerDisposable = self.didSubscribe(subscriber);
            [disposable addDisposable:innerDisposable];
        }];
        
        [disposable addDisposable:schedulingDisposable];
    }
    
    return disposable;
}

```

在RACDynamicSignal的subscribe:订阅过程中会用到subscriptionScheduler。于是对这个scheduler调用schedule:就会执行下面这段代码：


```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];
    
    block();
    return nil;
}

```

如果currentScheduler不为空，闭包会在currentScheduler中执行，如果currentScheduler为空，闭包就会在backgroundScheduler中执行，这是一个Global Dispatch Queue，优先级是RACSchedulerPriorityDefault。


同理，在RACEmptySignal，RACErrorSignal，RACReturnSignal，RACSignal的相关的signal的订阅中也都会调用subscriptionScheduler。

##### 3. 在RACBehaviorSubject中

```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    RACDisposable *subscriptionDisposable = [super subscribe:subscriber];
    
    RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
        @synchronized (self) {
            [subscriber sendNext:self.currentValue];
        }
    }];
    
    return [RACDisposable disposableWithBlock:^{
        [subscriptionDisposable dispose];
        [schedulingDisposable dispose];
    }];
}


```



在RACBehaviorSubject的subscribe:订阅过程中会用到subscriptionScheduler。于是对这个scheduler调用schedule:，代码在上面分析过了。


同理，如果currentScheduler不为空，闭包会在currentScheduler中执行，如果currentScheduler为空，闭包就会在backgroundScheduler中执行，这是一个Global Dispatch Queue，优先级是RACSchedulerPriorityDefault。


##### 4. 在RACReplaySubject中

它的订阅也同上面信号的订阅一样，会调用subscriptionScheduler。


由于RACReplaySubject是在子线程上，所以建议**在使用Core Data这些不安全库的时候一定要记得加上deliverOn。**


##### 5. 在RACSequence中

在RACSequence中，以下两个方法用到了RACScheduler：

```objectivec

- (RACSignal *)signal {
    return [[self signalWithScheduler:[RACScheduler scheduler]] setNameWithFormat:@"[%@] -signal", self.name];
}


```


```objectivec

- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block RACSequence *sequence = self;
        
        return [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
            if (sequence.head == nil) {
                [subscriber sendCompleted];
                return;
            }
            
            [subscriber sendNext:sequence.head];
            
            sequence = sequence.tail;
            reschedule();
        }];
    }] setNameWithFormat:@"[%@] -signalWithScheduler: %@", self.name, scheduler];
}


```

上面两个方法会调用RACScheduler中的scheduleRecursiveBlock:方法。关于这个方法的源码分析可以看[RACSequence的源码分析](http://www.jianshu.com/p/5c2119b3f2eb)。



##### 6. 在RACSignal+Operations中

这里总共有9个方法用到了Scheduler。

第一个方法：

```objectivec

static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *))

```

在上面这个方法里面用到了

```objectivec

RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];

```

取出currentScheduler或者一个Global Dispatch Queue，然后调用scheduleRecursiveBlock:。


第二个方法：

```objectivec


- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate

```

在上面这个方法中会调用

```objectivec

RACScheduler *scheduler = [RACScheduler scheduler];
RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler

```

在delayScheduler中调用afterDelay: schedule:方法，这也是throttle:valuesPassingTest:方法实现的很重要的一步。


第三个方法：

```objectivec

- (RACSignal *)delay:(NSTimeInterval)interval

```

由于这是一个延迟方法，肯定是会调用Scheduler的after方法。

```objectivec

   RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
   RACDisposable *schedulerDisposable = [delayScheduler afterDelay:interval schedule:block];

```

RACScheduler.currentScheduler ?: scheduler 这个判断在上述几个时间相关的方法都用到了。



所以，这里给一个建议：**delay由于不一定会回到当前线程中，所以delay之后再去订阅可能就在子线程中去执行。所以使用delay的时候最好追加一个deliverOn。**



第四个方法：

```objectivec

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler

```

在这个方法中理所当然的需要调用[scheduler afterDelay:interval schedule:flushValues]这个方法，来达到延迟的目的，从而实现缓冲buffer的效果。


第五个方法：

```objectivec

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler

```

第六个方法：

```objectivec

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway { }

```

第五个方法 和 第六个方法都用传进去的入参scheduler去调用after: repeatingEvery: withLeeway: schedule:方法。


第七个方法：

```objectivec

- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler { }

```

在这个方法中会用入参scheduler调用afterDelay: schedule:，延迟一段时候后，执行[disposable dispose]，从而也实现了超时发送sendError:。

第八个方法：

```objectivec

- (RACSignal *)deliverOn:(RACScheduler *)scheduler { }

```

第九个方法：

```objectivec

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler { }

```

第八个方法 和 第九个方法都是根据入参scheduler去调用schedule:方法。入参是什么类型的scheduler决定了schedule:执行在哪个queue上。




##### 7. 在RACSignal中

在RACSignal也有积极计算和惰性求值的信号。

```objectivec

+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(block != NULL);
    
    RACSignal *signal = [self startLazilyWithScheduler:scheduler block:block];
    [[signal publish] connect];
    return [signal setNameWithFormat:@"+startEagerlyWithScheduler: %@ block:", scheduler];
}


```

startEagerlyWithScheduler中会调用startLazilyWithScheduler产生一个信号signal，然后紧接着转换成热信号。通过startEagerlyWithScheduler产生的信号就直接是一个热信号。

```objectivec

+ (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(block != NULL);
    
    RACMulticastConnection *connection = [[RACSignal
                                           createSignal:^ id (id<RACSubscriber> subscriber) {
                                               block(subscriber);
                                               return nil;
                                           }]
                                          multicast:[RACReplaySubject subject]];
    
    return [[[RACSignal
              createSignal:^ id (id<RACSubscriber> subscriber) {
                  [connection.signal subscribe:subscriber];
                  [connection connect];
                  return nil;
              }]
             subscribeOn:scheduler]
            setNameWithFormat:@"+startLazilyWithScheduler: %@ block:", scheduler];
}

```

上述是startLazilyWithScheduler:的源码实现，在这个方法中和startEagerlyWithScheduler最大的区别就出来了，connect方法在return的信号中，所以Lazily就体现在，通过startLazilyWithScheduler建立出来的信号，只有订阅它之后才能调用到connect，转变成热信号。

在这里调用了subscribeOn:scheduler，这里用到了scheduler。

##### 8. 在NSData+RACSupport中

```objectivec

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler {
    NSCParameterAssert(scheduler != nil);
    
    RACReplaySubject *subject = [RACReplaySubject subject];
    [subject setNameWithFormat:@"+rac_readContentsOfURL: %@ options: %lu scheduler: %@", URL, (unsigned long)options, scheduler];
    
    [scheduler schedule:^{
        NSError *error = nil;
        NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:options error:&error];
        if (data == nil) {
            [subject sendError:error];
        } else {
            [subject sendNext:data];
            [subject sendCompleted];
        }
    }];
    
    return subject;
}


```

在这个方法中，会传入RACQueueScheduler或者RACTargetQueueScheduler的RACScheduler。那么调用schedule方法就会执行到这里：

```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    RACDisposable *disposable = [[RACDisposable alloc] init];
    
    dispatch_async(self.queue, ^{
        if (disposable.disposed) return;
        [self performAsCurrentScheduler:block];
    });
    
    return disposable;
}


```

##### 9. 在NSString+RACSupport中

```objectivec

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL usedEncoding:(NSStringEncoding *)encoding scheduler:(RACScheduler *)scheduler {
    NSCParameterAssert(scheduler != nil);
    
    RACReplaySubject *subject = [RACReplaySubject subject];
    [subject setNameWithFormat:@"+rac_readContentsOfURL: %@ usedEncoding:scheduler: %@", URL, scheduler];
    
    [scheduler schedule:^{
        NSError *error = nil;
        NSString *string = [NSString stringWithContentsOfURL:URL usedEncoding:encoding error:&error];
        if (string == nil) {
            [subject sendError:error];
        } else {
            [subject sendNext:string];
            [subject sendCompleted];
        }
    }];
    
    return subject;
}


```

同NSData+RACSupport中的rac\_readContentsOfURL: options: scheduler:一样，也会传入RACQueueScheduler或者RACTargetQueueScheduler的RACScheduler。

##### 10. 在NSUserDefaults+RACSupport中


```objectivec

RACScheduler *scheduler = [RACScheduler scheduler];

```

在这个方法中也会新建RACTargetQueueScheduler，一个Global Dispatch Queue。优先级是RACSchedulerPriorityDefault。


### 最后

关于RACScheduler底层实现分析都已经分析完成。最后请大家多多指教。

