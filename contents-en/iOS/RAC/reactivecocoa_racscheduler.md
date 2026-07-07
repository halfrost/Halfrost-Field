# How RACScheduler in ReactiveCocoa Wraps GCD

![](https://img.halfrost.com/Blog/ArticleTitleImage/37_0_.png)


### Preface

When using ReactiveCocoa, [Josh Abernathy](https://github.com/joshaber) and [Justin Spahr-Summers](https://github.com/jspahrsummers), two of its key contributors, wrapped GCD so that RAC users could more smoothly immerse themselves in the world of FRP and do concurrent programming more effectively. They also integrated this abstraction seamlessly with the major components of RAC.

Since the introduction of RACScheduler, concurrent programming code across RAC has become more harmonious, more consistent, easier to use, and more “ReactiveCocoa.”


### Table of Contents

- 1. How RACScheduler wraps GCD
- 2. Some subclasses of RACScheduler
- 3. How RACScheduler “cancels” concurrent tasks
- 4. How RACScheduler integrates seamlessly with other RAC components


#### 1. How RACScheduler Wraps GCD

What exactly does RACScheduler do in ReactiveCocoa? What role does it play? The official definition is as follows:
```vim

Schedulers are used to control when and where work is performed

```
RACScheduler in ReactiveCocoa is used to control when and where a task is executed. It is mainly used to address concurrency programming issues in ReactiveCocoa.

RACScheduler is essentially a wrapper around GCD; its underlying implementation is based on GCD.

To analyze RACScheduler, let’s first review GCD.


![](https://img.halfrost.com/Blog/ArticleImage/37_1.png)


As everyone knows, in GCD, Dispatch Queues are mainly divided into two categories: Serial Dispatch Queue and Concurrent Dispatch Queue. A Serial Dispatch Queue is a queue that waits for the currently executing work to finish, while a Concurrent Dispatch Queue is a queue that does not wait for the currently executing work to finish.

There are also two ways to create a Dispatch Queue. The first is to create a Dispatch Queue through the GCD API.


Creating a Serial Dispatch Queue
```objectivec

dispatch_queue_t serialDispatchQueue = dispatch_queue_create("com.gcd.SerialDispatchQueue", DISPATCH_QUEUE_SERIAL);
    


```
Create a Concurrent Dispatch Queue
```objectivec


dispatch_queue_t concurrentDispatchQueue = dispatch_queue_create("com.gcd.ConcurrentDispatchQueue", DISPATCH_QUEUE_CONCURRENT);

```
The second approach is to directly obtain a Dispatch Queue provided by the system. The system-provided queues are also divided into two categories: Main Dispatch Queue and Global Dispatch Queue. Main Dispatch Queue corresponds to a Serial Dispatch Queue, while Global Dispatch Queue corresponds to a Concurrent Dispatch Queue.

Global Dispatch Queue is mainly divided into 8 types.

![](https://img.halfrost.com/Blog/ArticleImage/37_2.png)


First are the following 4 types, which correspond to the QoS levels for each priority.
```objectivec

  - DISPATCH_QUEUE_PRIORITY_HIGH:         QOS_CLASS_USER_INITIATED
  - DISPATCH_QUEUE_PRIORITY_DEFAULT:      QOS_CLASS_DEFAULT
  - DISPATCH_QUEUE_PRIORITY_LOW:          QOS_CLASS_UTILITY
  - DISPATCH_QUEUE_PRIORITY_BACKGROUND:   QOS_CLASS_BACKGROUND

```
Second, whether overcommit is supported. Together with the four priorities above, this gives a total of 8 types of Global Dispatch Queues. A queue with overcommit means that whenever a task is submitted, the system starts a new thread to handle it, so no single thread becomes overloaded (overcommit).

![](https://img.halfrost.com/Blog/ArticleImage/37_3.png)


Back to `RACScheduler`: since `RACScheduler` is a wrapper around GCD, all of the types mentioned above have corresponding wrappers.
```objectivec

typedef enum : long {
     RACSchedulerPriorityHigh = DISPATCH_QUEUE_PRIORITY_HIGH,
     RACSchedulerPriorityDefault = DISPATCH_QUEUE_PRIORITY_DEFAULT,
     RACSchedulerPriorityLow = DISPATCH_QUEUE_PRIORITY_LOW,
     RACSchedulerPriorityBackground = DISPATCH_QUEUE_PRIORITY_BACKGROUND,
} RACSchedulerPriority;


```
First, the priorities in `RACScheduler` are wrapped into four types, corresponding respectively to `DISPATCH_QUEUE_PRIORITY_HIGH`, `DISPATCH_QUEUE_PRIORITY_DEFAULT`, `DISPATCH_QUEUE_PRIORITY_LOW`, and `DISPATCH_QUEUE_PRIORITY_BACKGROUND` in GCD.

`RACScheduler` has six class methods, all used to create a queue.
```objectivec

+ (RACScheduler *)immediateScheduler;
+ (RACScheduler *)mainThreadScheduler;

+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name;
+ (RACScheduler *)schedulerWithPriority:(RACSchedulerPriority)priority;
+ (RACScheduler *)scheduler;

+ (RACScheduler *)currentScheduler;


```
Next, let's analyze their underlying implementations one by one.


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
The underlying implementation of `immediateScheduler` is to create a singleton instance of `RACImmediateScheduler`.

`RACImmediateScheduler` inherits from `RACScheduler`.
```objectivec

@interface RACImmediateScheduler : RACScheduler
@end

```
In `RACScheduler`, each type of `RACScheduler` has a `name` property, and the name can also be considered its identifier. The `name` of `RACImmediateScheduler` is `@"com.ReactiveCocoa.RACScheduler.immediateScheduler"`.

As its name suggests, `RACImmediateScheduler` is used to execute the task inside the closure immediately.
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
In the schedule: method, the block( ) closure passed in as an argument is invoked directly. In the after: schedule: method, the thread first sleeps until the specified date, then wakes up and executes the block( ) closure passed in as an argument.
```objectivec

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    NSCAssert(NO, @"+[RACScheduler immediateScheduler] does not support %@.", NSStringFromSelector(_cmd));
    return nil;
}


```
Of course, RACImmediateScheduler cannot support the after: repeatingEvery: withLeeway: schedule: method. By definition, it executes immediately and should not repeat.
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
In `RACImmediateScheduler`’s `scheduleRecursiveBlock:` method, as long as the `recursiveBlock` closure exists, it will keep invoking itself recursively without end, unless `recursiveBlock` no longer exists.


##### 2. mainThreadScheduler


![](https://img.halfrost.com/Blog/ArticleImage/37_6.png)


`mainThreadScheduler` is also a singleton of type `RACTargetQueueScheduler`.
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
The name of mainThreadScheduler is @"com.ReactiveCocoa.RACScheduler.mainThreadScheduler".


RACTargetQueueScheduler inherits from RACQueueScheduler.
```objectivec


@interface RACTargetQueueScheduler : RACQueueScheduler
- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue;
@end

```
In `RACTargetQueueScheduler`, there is only one initialization method.
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
First, a new queue is created, with the name @"com.ReactiveCocoa.RACScheduler.mainThreadScheduler". Its type is Serial Dispatch Queue, and then the dispatch\_set\_target\_queue method is called.


So the key point lies in the dispatch\_set\_target\_queue method.


The dispatch\_set\_target\_queue method mainly serves two purposes: first, to set the priority of a queue created by dispatch\_queue\_create; second, to establish the execution hierarchy of queues.

- When using dispatch\_queue\_create to create a queue, whether serial or concurrent, its priority is DISPATCH\_QUEUE\_PRIORITY\_DEFAULT by default. This API can be used to set the queue’s priority. 
 
For example: 
```objectivec

dispatch_queue_t serialQueue = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
//Note: The queue whose priority is set is the first parameter.
dispatch_set_target_queue(serialQueue, globalQueue);

```
With the code above, `serailQueue` is set to `DISPATCH\_QUEUE\_PRIORITY\_HIGH`.

- Using the `dispatch\_set\_target\_queue` method, you can set the execution hierarchy of a queue, for example: `dispatch\_set\_target\_queue(queue, targetQueue);`
With this configuration, it is equivalent to assigning `queue` to `targetQueue`. If `targetQueue` is a serial queue, then `queue` executes serially; if `targetQueue` is a concurrent queue, then `queue` executes concurrently.

For example:
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
If `targetQueue` is a Serial Dispatch Queue, the output will always be as follows:
```vim

queue1 1
queue1 2
queue2 1
queue2 2
target queue


```
If `targetQueue` is a Concurrent Dispatch Queue, the output might be as follows:
```vim


queue1 1
queue2 1
queue1 2
target queue
queue2 2


```
Returning to RACTargetQueueScheduler, the input argument passed in here is dispatch\_get\_main\_queue( ), which is a Serial Dispatch Queue. Calling dispatch\_set\_target\_queue here is equivalent to setting the priority of queue to match main\_queue.


##### 3. scheduler

![](https://img.halfrost.com/Blog/ArticleImage/37_7.png)


The following three methods are essentially the same method.
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
From the source code, we can see that this series of three `scheduler` methods creates a Global Dispatch Queue, which corresponds to a Concurrent Dispatch Queue.

The `schedulerWithPriority:name:` method lets you specify the thread priority and name.

The `schedulerWithPriority:` method can only specify the priority; the name defaults to `@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"`.

The queue created by the `scheduler` method uses the default priority, and its name also defaults to `@"com.ReactiveCocoa.RACScheduler.backgroundScheduler"`.


**Note**: unlike the `mainThreadScheduler` and `immediateScheduler` singletons, `scheduler` creates a new Concurrent Dispatch Queue each time it is called.


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
First, ReactiveCocoa defines a key, `@"RACSchedulerCurrentSchedulerKey"`, which is used to store and retrieve the corresponding `RACScheduler` from the thread dictionary.
```objectivec

NSString * const RACSchedulerCurrentSchedulerKey = @"RACSchedulerCurrentSchedulerKey";

```
In the `currentScheduler` method, a `RACScheduler` is retrieved from the thread dictionary. As for when it is stored there, that will be explained below.

If a `RACScheduler` can be retrieved from the thread dictionary, the retrieved `RACScheduler` is returned. If the dictionary does not contain one, it then checks whether the current scheduler is on the main thread.
```objectivec

+ (BOOL)isOnMainThread {
    return [NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue] || [NSThread isMainThread];
}


```
The determination method is as described above: as long as the `NSOperationQueue` is on `mainQueue`, or the `NSThread` is the main thread, it is considered to be on the main thread.

If it is on the main thread, return `mainThreadScheduler`.
If it is not on the main thread and no value corresponding to the given key can be found in the thread dictionary, return `nil`.

In addition to its 6 class methods, `RACScheduler` also has 4 instance methods:
```objectivec

- (RACDisposable *)schedule:(void (^)(void))block;
- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block;
- (RACDisposable *)afterDelay:(NSTimeInterval)delay schedule:(void (^)(void))block;
- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block;


```
These four methods are essentially self-explanatory from their names.

`schedule:` adds a task to `RACScheduler`; its input parameter is a closure.

`after: schedule:` adds a scheduled task to `RACScheduler`; the task is executed only after the specified `date`.

`afterDelay: schedule:` adds a delayed task to `RACScheduler`; the task is executed after a delay of `delay`.

`after: repeatingEvery: withLeeway: schedule:` adds a scheduled task to `RACScheduler`; it starts executing after the specified `date`, and then executes once every `interval` seconds.

These four methods are overridden in the various subclasses of `RACScheduler`.

For example, in the previously mentioned `immediateScheduler`, the closure is executed immediately in `schedule:`. `after: schedule:` adds a scheduled task that executes only after the specified `date`. In `RACImmediateScheduler`, `after: repeatingEvery: withLeeway: schedule:` simply returns `nil`.

The implementations of these four methods in other subclasses will be analyzed below.

There are also the final three methods.
```objectivec

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock;
- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable
- (void)performAsCurrentScheduler:(void (^)(void))block;


```
The first two methods implement the signalWithScheduler: method in RACSequence. For a detailed analysis, see [this article](http://www.jianshu.com/p/5c2119b3f2eb).

The performAsCurrentScheduler: method is used in RACQueueScheduler and will be analyzed in detail in the subclass analysis below.


#### 2. Some RACScheduler Subclasses

RACScheduler has the following five subclasses in total.


![](https://img.halfrost.com/Blog/ArticleImage/37_9.png)


##### 1. RACTestScheduler


![](https://img.halfrost.com/Blog/ArticleImage/37_10.png)


This class is primarily a test class, mainly used in unit tests. It is used to verify that asynchronous calls do not spend a large amount of time waiting. RACTestScheduler can also be used in multithreaded scenarios, but it can only select one method at a time from the queued method queue for execution.
```objectivec

@interface RACTestSchedulerAction : NSObject
@property (nonatomic, copy, readonly) NSDate *date;
@property (nonatomic, copy, readonly) void (^block)(void);
@property (nonatomic, strong, readonly) RACDisposable *disposable;

- (id)initWithDate:(NSDate *)date block:(void (^)(void))block;
@end

```
In unit tests, ReactiveCocoa creates a `RACTestSchedulerAction` object to make it easier to compare each method invocation, and to more conveniently compare and describe the entire testing process. The definition of `RACTestSchedulerAction` is shown above. Now let’s explain the parameters.

`date` is a timestamp. It is mainly used to compare and determine which closure should be executed next.

The `void (^block)(void)` closure is a task in `RACScheduler`.

`disposable` controls whether an action can be executed. Once it has been disposed, the action will no longer be executed.

The `initWithDate: block:` method initializes a new action.

During unit testing, the `step` method needs to be called to inspect each closure invocation.
```objectivec

- (void)step {
    [self step:1];
}

- (void)stepAll {
    [self step:NSUIntegerMax];
}

```
Both the `step` and `stepAll` methods call the `step:` method. `step` executes only one task in `RACScheduler`, while `stepAll` executes all tasks in `RACScheduler`. Since both call `step:`, let’s next analyze the concrete implementation of `step:`.
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
The implementation of step: is essentially a for loop. The number of loop iterations is determined by the input parameter ticks. First, const void *actionPtr is a pointer to a function. In the implementation above, there is a very important function—CFBinaryHeapGetMinimumIfPresent. Its prototype is as follows:
```objectivec

Boolean CFBinaryHeapGetMinimumIfPresent(CFBinaryHeapRef heap, const void **value)

```
The primary purpose of this function is to find the minimum value in the binary heap heap.
```objectivec

static CFComparisonResult RACCompareScheduledActions(const void *ptr1, const void *ptr2, void *info) {
    RACTestSchedulerAction *action1 = (__bridge id)ptr1;
    RACTestSchedulerAction *action2 = (__bridge id)ptr2;
    return CFDateCompare((__bridge CFDateRef)action1.date, (__bridge CFDateRef)action2.date, NULL);
}

```
The comparison rule is as described above: it compares the `date` values of the two entries. It finds the minimum value in the binary heap, which corresponds to the task in the scheduler. If there are multiple equal minimum values, it returns one of them at random. The returned function is stored in `actionPtr`. The overall return value of the function is a `BOOL`: if the binary heap is not empty and a minimum value can be found, it returns `YES`; if the binary heap is empty and no minimum value can be found, it returns `NO`.

The `stepAll` method passes in `NSUIntegerMax`. This `for` loop will not become an infinite loop, because after all tasks in the heap have finished executing, `CFBinaryHeapGetMinimumIfPresent` returns `NO`, so `break` is executed and the loop exits.

Here, `currentScheduler` is saved into the thread dictionary. Then `action.block` is executed to run the task.
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
schedule: accumulates the value of `numberOfDirectlyScheduledBlocks`. This value is also initialized as a timestamp so that the scheduled time of each method can be compared. Eventually, `numberOfDirectlyScheduledBlocks` represents the total number of `block` tasks that have been produced. It is then added to the heap using `CFBinaryHeapAddValue`.

after:schedule: directly creates a new `RACTestSchedulerAction` object, and then uses `CFBinaryHeapAddValue` to add the `block` closure to the heap.

after: repeatingEvery: withLeeway: schedule: likewise creates a new `RACTestSchedulerAction` object, and then uses `CFBinaryHeapAddValue` to add the `block` closure to the heap.

##### 2. RACSubscriptionScheduler

`RACSubscriptionScheduler` is the last singleton in `RACScheduler`. The only three singletons in `RACScheduler` are now all covered: `RACImmediateScheduler`, `RACTargetQueueScheduler`, and `RACSubscriptionScheduler`.
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
The name of `RACSubscriptionScheduler` is `@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"`
```objectivec

- (id)init {
    self = [super initWithName:@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"];
    if (self == nil) return nil;
    _backgroundScheduler = [RACScheduler scheduler];  
    return self;
}

```
When `RACSubscriptionScheduler` is initialized, it creates a new Global Dispatch Queue.
```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];
    block();
    return nil;
}

```
If `RACScheduler.currentScheduler` is `nil`, use `backgroundScheduler` to invoke the `block` closure; otherwise, execute the `block` closure.
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
Both `after` methods retrieve `RACScheduler.currentScheduler`; if it is `nil`, they use `self.backgroundScheduler` to invoke their respective `after` methods.

This is exactly the purpose of `backgroundScheduler` in `RACSubscriptionScheduler`: when `RACScheduler.currentScheduler` does not exist, it is replaced with `self.backgroundScheduler`.

##### 3. RACImmediateScheduler

This subclass was analyzed in detail when analyzing the `immediateScheduler` method, so it will not be repeated here.

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
`schedule:` calls the `performAsCurrentScheduler:` method.
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
performAsCurrentScheduler: first stores the current scheduler in the thread dictionary before invoking block( ).

Imagine that, while running on a Concurrent Dispatch Queue, the thread needs to be switched before executing block( ), switching to the current scheduler. After the block closure finishes executing, if previousScheduler is not nil, the original context is restored and the original scheduler is written back into the thread dictionary. Conversely, if previousScheduler is nil, the key is removed from the thread dictionary.


What is worth **noting** here is:

A scheduler is essentially a queue, not a thread. It can only guarantee that the work inside it executes serially, but it cannot guarantee that every execution happens on the same thread.

This is exactly what the implementation of performAsCurrentScheduler: above demonstrates. Therefore, using Core Data on a scheduler can easily crash, because execution may very well end up on a background thread. Once data writes happen on a background thread, it can easily crash. Be sure to switch back to the main queue.
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
In `after`, the `dispatch_after` method is called, and after the `date` interval has elapsed, `performAsCurrentScheduler:` is invoked.

The implementation of `wallTimeWithDate:` is as follows:
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
The dispatch\_walltime function obtains a value of type dispatch\_time\_t from a time value of type struct timespec used in POSIX. The dispatch\_time function is typically used to calculate relative time, while the dispatch\_walltime function is used to calculate absolute time.

This code is actually very simple: it converts the time from date into a dispatch\_time\_t value. It obtains a dispatch\_time\_t value from an NSDate object that can be passed to the dispatch\_after function.
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
The implementation of the `after: repeatingEvery: withLeeway: schedule:` method uses GCD to create a Timer on `self.queue`, with `interval` as the time interval and `leeway` as the tolerance.

The `leeway` parameter specifies the desired precision for dispatch source timer events, allowing the system to manage and wake the kernel more flexibly. For example, the system can use the `leeway` value to fire the timer earlier or later, so it can be better coalesced with other system events. When creating your own timer, you should specify a `leeway` value whenever possible. However, even if you specify a `leeway` value of 0, you still cannot fully expect the timer to fire with exact nanosecond precision.

This timer executes the input closure every `interval`. When canceling the task, it calls dispatch\_source\_cancel to cancel the `timer`.


##### 5. RACTargetQueueScheduler

This subclass was analyzed in detail when discussing the `mainThreadScheduler` method, so it will not be repeated here.


#### III. How RACScheduler “Cancels” Concurrent Tasks


![](https://img.halfrost.com/Blog/ArticleImage/37_12.png)


Since RACScheduler is a wrapper around GCD, it can implement certain “features” on top of GCD that GCD itself cannot provide. The word “features” is in quotation marks because the underlying mechanism is still GCD; the upper-layer behavior can only be implemented through certain special techniques so that it appears to be a new feature. In this respect, RACScheduler implements a capability that GCD does not have: “canceling” tasks.


Operation Queues:
Compared with GCD, using Operation Queues adds a small amount of overhead, but in exchange it provides very powerful flexibility and functionality. It can add dependencies between operations, cancel an operation that is currently executing, pause and resume an operation queue, and so on.

GCD:
GCD is a more lightweight way to execute concurrent tasks in FIFO order. When using GCD, we do not need to care about task scheduling; the system handles it automatically for us. However, GCD’s limitations are also very obvious: adding dependencies between tasks, or canceling or pausing a task that is already executing, becomes very tricky.

Since GCD does not make it convenient to cancel a task, how does RACScheduler do it?

This is reflected in RACQueueScheduler. Let’s look back at the implementations of `schedule:` and `after: schedule:` in RACQueueScheduler.

The core code:
```objectivec

 dispatch_async(self.queue, ^{
      if (disposable.disposed) return;
      [self performAsCurrentScheduler:block];
 });

```
Before calling `performAsCurrentScheduler:`, a check was added to determine whether the current task has been canceled. If the task has been canceled, it returns immediately and does not invoke the `block` closure. This creates the “illusion” of task cancellation.


#### 4. How RACScheduler Integrates Seamlessly with Other RAC Components

Throughout ReactiveCocoa, RACScheduler is used to implement many operations and is deeply integrated with RAC. This section summarizes all the places in ReactiveCocoa where RACScheduler is used.


 ![](https://img.halfrost.com/Blog/ArticleImage/37_13.png)


If you globally search for RACScheduler in ReactiveCocoa and go through the entire library, you’ll find that RACScheduler is used in the following 10 classes. Let’s take a look at how it is used in each of these places.


By looking at the places where Scheduler is used below, we can understand which operations run on background threads and which run on the main thread. Once we distinguish between them, we can handle thread-unsafe operations with confidence and move them back to the main thread when necessary, which can reduce many inexplicable crashes. These crashes are all caused by threading issues.


##### 1. In RACCommand
```objectivec

- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock


```
This method is quite complex. It uses `RACScheduler.immediateScheduler` and `deliverOn:RACScheduler.mainThreadScheduler`. A detailed source-level analysis will be covered in the next article on the `RACCommand` source code.
```objectivec

- (RACSignal *)execute:(id)input

```
In this method, subscribeOn:RACScheduler.mainThreadScheduler is called.

##### 2. In RACDynamicSignal
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
During the `subscribe:` subscription process of `RACDynamicSignal`, `subscriptionScheduler` is used. Therefore, calling `schedule:` on this scheduler executes the following code:
```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];
    
    block();
    return nil;
}

```
If currentScheduler is not nil, the closure is executed on currentScheduler. If currentScheduler is nil, the closure is executed on backgroundScheduler, which is a Global Dispatch Queue with the priority RACSchedulerPriorityDefault.

Similarly, subscriptionScheduler is also invoked when subscribing to the related signals of RACEmptySignal, RACErrorSignal, RACReturnSignal, and RACSignal.

##### 3. In RACBehaviorSubject
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
In the `subscribe:` subscription process of `RACBehaviorSubject`, `subscriptionScheduler` is used. Therefore, `schedule:` is called on this scheduler; the code was analyzed above.

Similarly, if `currentScheduler` is not empty, the closure will execute on `currentScheduler`; if `currentScheduler` is empty, the closure will execute on `backgroundScheduler`, which is a Global Dispatch Queue with priority `RACSchedulerPriorityDefault`.

##### 4. In `RACReplaySubject`

Its subscription, like the signal subscriptions above, also calls `subscriptionScheduler`.

Since `RACReplaySubject` runs on a child thread, it is recommended that **when using unsafe libraries such as Core Data, you must remember to add `deliverOn`.**

##### 5. In `RACSequence`

In `RACSequence`, the following two methods use `RACScheduler`:
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
The two methods above will call the scheduleRecursiveBlock: method in RACScheduler. For a source-code analysis of this method, see [Source Code Analysis of RACSequence](http://www.jianshu.com/p/5c2119b3f2eb).


##### 6. In RACSignal+Operations

There are nine methods here that use Scheduler.

The first method:
```objectivec

static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *))

```
It is used in the method above.
```objectivec

RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];

```
Retrieve `currentScheduler` or a Global Dispatch Queue, then call `scheduleRecursiveBlock:`.


The second method:
```objectivec


- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate

```
This will be called in the method above.
```objectivec

RACScheduler *scheduler = [RACScheduler scheduler];
RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler

```
Call the afterDelay: schedule: method on delayScheduler; this is also an important step in the implementation of the throttle:valuesPassingTest: method.

The third method:
```objectivec

- (RACSignal *)delay:(NSTimeInterval)interval

```
Since this is a delayed method, it will definitely call the `Scheduler`'s `after` method.
```objectivec

   RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
   RACDisposable *schedulerDisposable = [delayScheduler afterDelay:interval schedule:block];

```
The `RACScheduler.currentScheduler ?: scheduler` check is used in the several time-related methods mentioned above.

So here is a recommendation: **Because `delay` does not necessarily return to the current thread, subscribing after `delay` may execute on a background thread. Therefore, when using `delay`, it is best to append a `deliverOn`.**

The fourth method:
```objectivec

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler

```
In this method, it is of course necessary to call [scheduler afterDelay:interval schedule:flushValues] to achieve the delay, thereby implementing the buffering effect.

Fifth method:
```objectivec

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler

```
The sixth method:
```objectivec

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway { }

```
The fifth and sixth methods both use the passed-in scheduler parameter to call the after:repeatingEvery:withLeeway:schedule: method.


The seventh method:
```objectivec

- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler { }

```
In this method, the input parameter `scheduler` is used to call `afterDelay: schedule:`. After a delay, `[disposable dispose]` is executed, thereby also triggering the timeout to send `sendError:`.

The eighth method:
```objectivec

- (RACSignal *)deliverOn:(RACScheduler *)scheduler { }

```
The ninth method:
```objectivec

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler { }

```
The eighth and ninth methods both call the `schedule:` method based on the input parameter `scheduler`. The type of `scheduler` passed in determines which queue `schedule:` executes on.


##### 7. In RACSignal

RACSignal also has eagerly evaluated and lazily evaluated signals.
```objectivec

+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(block != NULL);
    
    RACSignal *signal = [self startLazilyWithScheduler:scheduler block:block];
    [[signal publish] connect];
    return [signal setNameWithFormat:@"+startEagerlyWithScheduler: %@ block:", scheduler];
}


```
`startEagerlyWithScheduler` calls `startLazilyWithScheduler` to produce a signal, `signal`, and then immediately converts it into a hot signal. The signal produced by `startEagerlyWithScheduler` is therefore directly a hot signal.
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
The above is the source implementation of `startLazilyWithScheduler:`. In this method, the biggest difference from `startEagerlyWithScheduler` becomes apparent: the `connect` method is inside the returned signal. Therefore, the “lazy” behavior is reflected in the fact that a signal created via `startLazilyWithScheduler` can only call `connect` and be converted into a hot signal after it is subscribed to.

Here, `subscribeOn:scheduler` is called, which uses `scheduler`.

##### 8. In NSData+RACSupport
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
In this method, the RACScheduler passed in will be a RACQueueScheduler or RACTargetQueueScheduler. So when the schedule method is called, execution reaches here:
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

##### 9. In NSString+RACSupport
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
As with `rac_readContentsOfURL: options: scheduler:` in `NSData+RACSupport`, an `RACScheduler` of type `RACQueueScheduler` or `RACTargetQueueScheduler` is also passed in.

##### 10. In NSUserDefaults+RACSupport
```objectivec

RACScheduler *scheduler = [RACScheduler scheduler];

```
This method also creates a RACTargetQueueScheduler, which uses a Global Dispatch Queue. Its priority is RACSchedulerPriorityDefault.


### Conclusion

This concludes the analysis of RACScheduler's underlying implementation. Feedback and suggestions are welcome.