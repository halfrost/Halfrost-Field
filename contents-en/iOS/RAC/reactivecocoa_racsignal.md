# How RACSignal Sends Signals in ReactiveCocoa

![](https://img.halfrost.com/Blog/ArticleTitleImage/31_0_.png)


#### Preface

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) is an open-source library that brought the functional reactive programming paradigm to Objective-C—perhaps the first to do so. ReactiveCocoa was written by the great [Josh Abernathy](https://github.com/joshaber) and [Justin Spahr-Summers](https://github.com/jspahrsummers) during the development of [GitHub for Mac](http://mac.github.com/). [Justin Spahr-Summers](https://github.com/jspahrsummers) made the first commit at 12:35 PM on November 13, 2011, and released the [1.0 release](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v1.0.0) at 3:05 AM on February 13, 2013, reaching its first major milestone. The ReactiveCocoa community is also very active. The latest version has now reached ReactiveCocoa 5.0.0-alpha.3, and 5.0.0-alpha.4 is currently under development.

ReactiveCocoa v2.5 is widely regarded as the most stable Objective-C version, so it has been adopted by many client-side teams whose primary language is OC. ReactiveCocoa v3.x is mainly based on Swift 1.2, while ReactiveCocoa v4.x is mainly based on Swift 2.x. ReactiveCocoa 5.0 will fully support Swift 3.0, and perhaps even Swift 4.0 in the future. In the next few blog posts, we will use ReactiveCocoa v2.5 as an example to analyze the concrete implementation of the OC version of RAC. (Maybe by the time the analysis is finished, RAC 5.0 will have arrived.) Consider this a blessing written on the eve of the official ReactiveCocoa 5.0 release.


#### Table of Contents
- 1.What is ReactiveCocoa?
- 2.The core RACSignal sending and subscription flow in RAC
- 3.The core bind implementation for RACSignal operations
- 4.The implementation of basic RACSignal operations concat and zipWith
- 5.Conclusion

#### I. What is ReactiveCocoa?

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) (abbreviated as RAC) is a new framework open-sourced by [Github](https://github.com/blog/1107-reactivecocoa-for-a-better-world) for iOS and OS X development. RAC has the characteristics of functional programming (FP) and reactive programming (RP). Its design and implementation are primarily inspired by .NET’s [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609).

The goal of ReactiveCocoa is “Streams of values over time”: data streams that continuously flow as time changes.

ReactiveCocoa mainly solves the following problems:

- UI data binding

UI controls usually need to bind to an event, and RAC makes it very convenient to bind any data stream to a control.

- User interaction event binding

RAC provides a series of methods for interactive UI controls that can send Signals. These data streams are passed around during user interaction.

- Solving excessive state and inter-state dependency problems

With RAC bindings, you no longer need to worry about all kinds of complex states such as isSelect, isFinish, and so on. It also solves the problem that these states are difficult to maintain later.

- Unifying message-passing mechanisms

Originally, there were several message-passing mechanisms in OC programming: Delegate, Block Callback, Target-Action, Timers, and KVO. There is an article on objc about how to choose among these five message-passing approaches in OC: [Communication Patterns](https://www.objccn.io/issue-7-4/). I recommend reading it. Now, with RAC, all five of the above approaches can be handled uniformly with RAC.

#### II. The core RACSignal in RAC

One of the most central concepts in ReactiveCocoa is the signal, RACStream. RACStream has two subclasses: RACSignal and RACSequence. This article first analyzes RACSignal.


We often see code like the following:
```objectivec

RACSignal *signal = [RACSignal createSignal:
                     ^RACDisposable *(id<RACSubscriber> subscriber)
{
    [subscriber sendNext:@1];
    [subscriber sendNext:@2];
    [subscriber sendNext:@3];
    [subscriber sendCompleted];
    return [RACDisposable disposableWithBlock:^{
        NSLog(@"signal dispose");
    }];
}];
RACDisposable *disposable = [signal subscribeNext:^(id x) {
    NSLog(@"subscribe value = %@", x);
} error:^(NSError *error) {
    NSLog(@"error: %@", error);
} completed:^{
    NSLog(@"completed");
}];

[disposable dispose];


```
This is the complete process of an `RACSignal` being subscribed to. What exactly happens during the subscription process?
```objectivec

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
 return [RACDynamicSignal createSignal:didSubscribe];
}

```
When `createSignal` is called on `RACSignal`, it invokes the `createSignal` method of `RACDynamicSignal`.


![](https://img.halfrost.com/Blog/ArticleImage/31_1.png)


`RACDynamicSignal` is a subclass of `RACSignal`. The parameter following `createSignal` is a block.
```objectivec

(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe

```
The block’s return value is of type `RACDisposable`, and the block is named `didSubscribe`. The block’s only parameter is `subscriber`, of type `id<RACSubscriber>`. This `subscriber` must conform to the `RACSubscriber` protocol.

`RACSubscriber` is a protocol that defines the following 4 protocol methods:
```objectivec

@protocol RACSubscriber <NSObject>
@required

- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)disposable;

@end

```
So the responsibility for creating new `Signal`s falls entirely to `RACDynamicSignal`, a subclass of `RACSignal`.
```objectivec


@interface RACDynamicSignal ()
// The block to invoke for each subscriber.
@property (nonatomic, copy, readonly) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);
@end

```
The `RACDynamicSignal` class is very simple; it just stores a block named `didSubscribe`.
```objectivec


+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
     RACDynamicSignal *signal = [[self alloc] init];
     signal->_didSubscribe = [didSubscribe copy];
     return [signal setNameWithFormat:@"+createSignal:"];
}

```
This method creates a new RACDynamicSignal object, signal, and stores the passed-in didSubscribe block in the didSubscribe property of the newly created signal object. Finally, it names signal \+createSignal:.
```objectivec

- (instancetype)setNameWithFormat:(NSString *)format, ... {
 if (getenv("RAC_DEBUG_SIGNAL_NAMES") == NULL) return self;

   NSCParameterAssert(format != nil);

   va_list args;
   va_start(args, format);

   NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
   va_end(args);

   self.name = str;
   return self;
}


```
`setNameWithFormat` is a method in `RACStream`. Since `RACDynamicSignal` inherits from `RACSignal`, it can also call this method.

![](https://img.halfrost.com/Blog/ArticleImage/31_2.png)

The `block` of `RACSignal` is saved this way. So when will it be executed?

![](https://img.halfrost.com/Blog/ArticleImage/31_3.png)

The `block` closure is only “released” when it is subscribed to.

`RACSignal` calls the `subscribeNext` method and returns an `RACDisposable`.
```objectivec

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
   NSCParameterAssert(nextBlock != NULL);
   NSCParameterAssert(errorBlock != NULL);
   NSCParameterAssert(completedBlock != NULL);
 
   RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
   return [self subscribe:o];
}


```
This method creates a new `RACSubscriber` object and passes in `nextBlock`, `errorBlock`, and `completedBlock`.
```objectivec

@interface RACSubscriber ()

// These callbacks should only be accessed while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

@end


```
The RACSubscriber class is very simple. It has only four properties: nextBlock, errorBlock, completedBlock, and a RACCompoundDisposable signal.
```objectivec

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
 RACSubscriber *subscriber = [[self alloc] init];

   subscriber->_next = [next copy];
   subscriber->_error = [error copy];
   subscriber->_completed = [completed copy];

   return subscriber;
}


```
![](https://img.halfrost.com/Blog/ArticleImage/31_4.png)


The `subscriberWithNext` method stores each of the three incoming blocks in its corresponding block property.


When `RACSignal` calls the `subscribeNext` method, it ultimately calls `[self subscribe:o]` when returning. In practice, this invokes the `subscribe` method in the `RACDynamicSignal` class.
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
RACDisposable has three subclasses, one of which is RACCompoundDisposable.


![](https://img.halfrost.com/Blog/ArticleImage/31_5.png)
```objectivec


@interface RACCompoundDisposable : RACDisposable
+ (instancetype)compoundDisposable;
+ (instancetype)compoundDisposableWithDisposables:(NSArray *)disposables;
- (void)addDisposable:(RACDisposable *)disposable;
- (void)removeDisposable:(RACDisposable *)disposable;
@end

```
Although `RACCompoundDisposable` is a subclass of `RACDisposable`, it can contain multiple `RACDisposable` objects. When necessary, you can call `dispose` on all of them at once to tear down the signals. When a `RACCompoundDisposable` object is disposed, it also automatically disposes all `RACDisposable` objects in the container.

`RACPassthroughSubscriber` is a private class.
```objectivec

@interface RACPassthroughSubscriber : NSObject <RACSubscriber>
@property (nonatomic, strong, readonly) id<RACSubscriber> innerSubscriber;
@property (nonatomic, unsafe_unretained, readonly) RACSignal *signal;
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;
- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber signal:(RACSignal *)signal disposable:(RACCompoundDisposable *)disposable;
@end

```
The `RACPassthroughSubscriber` class has only this one method. Its purpose is to forward all signal events from one subscriber to another subscriber that has not yet been disposed.

The `RACPassthroughSubscriber` class holds three very important objects: `RACSubscriber`, `RACSignal`, and `RACCompoundDisposable`. `RACSubscriber` is the subscriber of the signal to be forwarded. `RACCompoundDisposable` is the subscriber’s disposal object; once it has been disposed, `innerSubscriber` will no longer receive the event stream.

One thing to note here is that it also keeps an internal `RACSignal`, and its property is `unsafe_unretained`. This differs from the other two properties, which are both `strong`. The reason it is not `weak` is that the reference to `RACSignal` is only used as a probe for DTrace dynamic tracing. If it were set to `weak`, it would introduce unnecessary performance overhead. Therefore, `unsafe_unretained` is sufficient here.
```objectivec

- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber signal:(RACSignal *)signal disposable:(RACCompoundDisposable *)disposable {
   NSCParameterAssert(subscriber != nil);

   self = [super init];
   if (self == nil) return nil;

   _innerSubscriber = subscriber;
   _signal = signal;
   _disposable = disposable;

   [self.innerSubscriber didSubscribeWithDisposable:self.disposable];
   return self;
}

```
Back in the `subscribe` method of the `RACDynamicSignal` class, the `RACCompoundDisposable` and `RACPassthroughSubscriber` objects have now been created.
```objectivec

 if (self.didSubscribe != NULL) {
  RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
   RACDisposable *innerDisposable = self.didSubscribe(subscriber);
   [disposable addDisposable:innerDisposable];
  }];

  [disposable addDisposable:schedulingDisposable];
 }


```
RACScheduler.subscriptionScheduler is a global singleton.
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
RACScheduler then continues to call the schedule method.
```objectivec


- (RACDisposable *)schedule:(void (^)(void))block {
   NSCParameterAssert(block != NULL);
   if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];
   block();
   return nil;
}

```

```objectivec


+ (BOOL)isOnMainThread {
 return [NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue] || [NSThread isMainThread];
}

+ (instancetype)currentScheduler {
 RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
 if (scheduler != nil) return scheduler;
 if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

 return nil;
}

```
When retrieving `currentScheduler`, it checks whether `currentScheduler` exists and whether execution is on the main thread. If neither is true, it calls the background `backgroundScheduler` to execute `schedule`.

The input parameter to `schedule` is a block. When `schedule` is executed, it runs that block. In other words, it executes:
```objectivec

RACDisposable *innerDisposable = self.didSubscribe(subscriber);
   [disposable addDisposable:innerDisposable];

```
These two statements are critical. The block previously stored in the signal is “released” and executed here. The statement self.didSubscribe(subscriber) executes the didSubscribe closure stored by the signal.

Inside the didSubscribe closure, there are sendNext, sendError, and sendCompleted calls. Executing these statements invokes the corresponding methods in RACPassthroughSubscriber.
```objectivec

- (void)sendNext:(id)value {
 if (self.disposable.disposed) return;
 if (RACSIGNAL_NEXT_ENABLED()) {
  RACSIGNAL_NEXT(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description), cleanedDTraceString([value description]));
 }
 [self.innerSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
 if (self.disposable.disposed) return;
 if (RACSIGNAL_ERROR_ENABLED()) {
  RACSIGNAL_ERROR(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description), cleanedDTraceString(error.description));
 }
 [self.innerSubscriber sendError:error];
}

- (void)sendCompleted {
 if (self.disposable.disposed) return;
 if (RACSIGNAL_COMPLETED_ENABLED()) {
  RACSIGNAL_COMPLETED(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description));
 }
 [self.innerSubscriber sendCompleted];
}


```
At this point, the subscriber is `RACPassthroughSubscriber`. The `innerSubscriber` inside `RACPassthroughSubscriber` is the actual final subscriber, and `RACPassthroughSubscriber` will continue forwarding the values to `innerSubscriber`.
```objectivec

- (void)sendNext:(id)value {
 @synchronized (self) {
  void (^nextBlock)(id) = [self.next copy];
  if (nextBlock == nil) return;

  nextBlock(value);
 }
}

- (void)sendError:(NSError *)e {
 @synchronized (self) {
  void (^errorBlock)(NSError *) = [self.error copy];
  [self.disposable dispose];

  if (errorBlock == nil) return;
  errorBlock(e);
 }
}

- (void)sendCompleted {
 @synchronized (self) {
  void (^completedBlock)(void) = [self.completed copy];
  [self.disposable dispose];

  if (completedBlock == nil) return;
  completedBlock();
 }
}

```
`innerSubscriber` is an `RACSubscriber`. When `sendNext` is called, it first copies its own `self.next` closure and then invokes it. The entire process is also thread-safe, protected by `@synchronized`. The final subscriber’s closure is invoked here.

`sendError` and `sendCompleted` work the same way.

To summarize:

![](https://img.halfrost.com/Blog/ArticleImage/31_6.png)


1. `RACSignal` calls the `subscribeNext` method and creates a new `RACSubscriber`.
2. The newly created `RACSubscriber` copies `nextBlock`, `errorBlock`, and `completedBlock` into its own instance properties.
3. The `RACSignal` subclass `RACDynamicSignal` calls the `subscribe` method.
4. New `RACCompoundDisposable` and `RACPassthroughSubscriber` objects are created. `RACPassthroughSubscriber` holds references to `RACSignal`, `RACSubscriber`, and `RACCompoundDisposable` respectively. Note that its reference to `RACSignal` is `unsafe\_unretained`.
5. `RACDynamicSignal` invokes the `didSubscribe` closure. It first calls the corresponding `sendNext`, `sendError`, and `sendCompleted` methods on `RACPassthroughSubscriber`.
6. `RACPassthroughSubscriber` then calls `self.innerSubscriber`, that is, the `nextBlock`, `errorBlock`, and `completedBlock` of `RACSubscriber`. Note that this invocation also first copies the closure and then executes it.


#### 3. The Core `bind` Implementation for `RACSignal` Operations


![](https://img.halfrost.com/Blog/ArticleImage/31_7.png)


The `RACSignal` source code includes two basic operations: `concat` and `zipWith`. Before analyzing those two operations, however, let’s first look at a more fundamental function: the `bind` operation.

First, let’s describe what the `bind` function does:
1. It subscribes to the original signal.
2. Whenever the original signal sends a value, the bound block transforms it once.
3. Once the bound block transforms the value into a signal, that signal is subscribed to immediately, and its value is sent to the subscriber.
4. Once the bound block decides to terminate the binding, the original signal completes.
5. When all signals have completed, a `completed` signal is sent to the subscriber.
6. If any signal produces an error along the way, that error is sent to the subscriber.
```objectivec

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block {
 NSCParameterAssert(block != NULL);

 return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
  RACStreamBindBlock bindingBlock = block();

  NSMutableArray *signals = [NSMutableArray arrayWithObject:self];

  RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

  void (^completeSignal)(RACSignal *, RACDisposable *) = ^(RACSignal *signal, RACDisposable *finishedDisposable) { /*omitted here for now*/ };
  void (^addSignal)(RACSignal *) = ^(RACSignal *signal) { /*omitted here for now*/ };

  @autoreleasepool {
   RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
   [compoundDisposable addDisposable:selfDisposable];

   RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
    // Manually check disposal to handle synchronous errors.
    if (compoundDisposable.disposed) return;

    BOOL stop = NO;
    id signal = bindingBlock(x, &stop);

    @autoreleasepool {
     if (signal != nil) addSignal(signal);
     if (signal == nil || stop) {
      [selfDisposable dispose];
      completeSignal(self, selfDisposable);
     }
    }
   } error:^(NSError *error) {
    [compoundDisposable dispose];
    [subscriber sendError:error];
   } completed:^{
    @autoreleasepool {
     completeSignal(self, selfDisposable);
    }
   }];

   selfDisposable.disposable = bindingDisposable;
  }

  return compoundDisposable;
 }] setNameWithFormat:@"[%@] -bind:", self.name];
}

```
To figure out exactly what the bind function does, write the following test code:
```objectivec

    RACSignal *signal = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
    {
        [subscriber sendNext:@1];
        [subscriber sendNext:@2];
        [subscriber sendNext:@3];
        [subscriber sendCompleted];
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"signal dispose");
        }];
    }];
    
    RACSignal *bindSignal = [signal bind:^RACStreamBindBlock{
        return ^RACSignal *(NSNumber *value, BOOL *stop){
            value = @(value.integerValue * 2);
            return [RACSignal return:value];
        };
    }];
    
    [bindSignal subscribeNext:^(id x) {
        NSLog(@"subscribe value = %@", x);
    }];


```
Since the first chapter already explained the entire process of creating and subscribing to `RACSignal` in detail, and also covered the relevant methods, the creation of `RACDynamicSignal`, `RACCompoundDisposable`, and `RACPassthroughSubscriber` is omitted here. This section focuses on analyzing how the various closures in `bind` are passed around, created, and subscribed to.

To prevent the following analysis from becoming confusing, let’s first number the blocks that will be used.
```objectivec

    RACSignal *signal = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
    {
        // block 1
    }

    RACSignal *bindSignal = [signal bind:^RACStreamBindBlock{
        // block 2
        return ^RACSignal *(NSNumber *value, BOOL *stop){
            // block 3
        };
    }];

    [bindSignal subscribeNext:^(id x) {
        // block 4
    }];

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block {
        // block 5
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        // block 6
        RACStreamBindBlock bindingBlock = block();
        NSMutableArray *signals = [NSMutableArray arrayWithObject:self];
        
        void (^completeSignal)(RACSignal *, RACDisposable *) = ^(RACSignal *signal, RACDisposable *finishedDisposable) {
        // block 7
        };
        
        void (^addSignal)(RACSignal *) = ^(RACSignal *signal) {
        // block 8
            RACDisposable *disposable = [signal subscribeNext:^(id x) {
            // block 9
            }];
        };
        
        @autoreleasepool {
            RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
                // block 10
                id signal = bindingBlock(x, &stop);
                
                @autoreleasepool {
                    if (signal != nil) addSignal(signal);
                    if (signal == nil || stop) {
                        [selfDisposable dispose];
                        completeSignal(self, selfDisposable);
                    }
                }
            } error:^(NSError *error) {
                [compoundDisposable dispose];
                [subscriber sendError:error];
            } completed:^{
                @autoreleasepool {
                    completeSignal(self, selfDisposable);
                }
            }];
        }
        return compoundDisposable;
    }] ;
}
```
First create a `signal`; `didSubscribe` copies and stores `block1`.

When `bind` is called on the signal to perform the binding, `block5` is invoked, and `didSubscribe` copies and stores `block6`.

When a subscriber starts subscribing to `bindSignal`, the flow is as follows:  
1. `bindSignal` executes the `didSubscribe` block, i.e. executes `block6`.
2. The first line of code in `block6` calls `RACStreamBindBlock bindingBlock = block()`. Here, `block` is the externally passed-in `block2`, so `block2` starts executing. After `block2` finishes, it returns a `RACStreamBindBlock` object.
3. Because `bind` is called on `signal`, `self` inside the `bind` function is `signal`. Inside `bind`, it subscribes to `signal`. Therefore, `subscribeNext` will execute `block1`.
4. When `block1` executes, `sendNext` calls the subscriber’s `nextBlock`, so `block10` starts executing.
5. `block10` first calls `bindingBlock`, which is the return value from the earlier call to `block2`. This `RACStreamBindBlock` object stores `block3`, so `block3` starts executing.
6. In `block3`, the input parameter is a `value`. This `value` is the value emitted by `sendNext` in `signal`. In `block3`, the `value` can be transformed. After the transformation is complete, a new signal `signal'` is returned.
7. If the returned `signal'` is empty, `completeSignal` is called, i.e. `block7` is invoked. `block7` sends `sendCompleted`. If the returned `signal'` is not empty, `addSignal` is called, i.e. `block8` is invoked. `block8` continues subscribing to `signal'`. Since `signal'` is the return value from the external `bind` function, and the returned signal is of type `RACReturnSignal`, it will call `sendNext` as soon as it is subscribed to, which executes `block9`.
8. `block9` calls `sendNext`. Here, `subscriber` is the input parameter of `block6`, so calling `sendNext` on `subscriber` invokes `block4` of `bindSignal`’s subscriber.
9. After `block9` finishes executing `sendNext`, it also calls `sendCompleted`. Here, it is executing the `completed` closure inside `block9`: `completeSignal(signal, selfDisposable);`. Then `completeSignal` is called again, i.e. `block7`.
10. After `block7` finishes executing, the entire process of `signal` sending one `sendNext` event is complete.


The entire `bind` flow is then complete.


#### IV. Implementation of the Basic RACSignal Operations concat and zipWith

Next, let’s analyze two other basic operations in `RACSignal`.

##### 1. concat


![](https://img.halfrost.com/Blog/ArticleImage/31_8.png)


Write the test code:
```objectivec


    RACSignal *signal = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
    {
        [subscriber sendNext:@1];
        [subscriber sendCompleted];
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"signal dispose");
        }];
    }];


    RACSignal *signals = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
    {
        [subscriber sendNext:@2];
        [subscriber sendNext:@3];
        [subscriber sendNext:@6];
        [subscriber sendCompleted];
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"signal dispose");
        }];
    }];

    RACSignal *concatSignal = [signal concat:signals];
    
    [concatSignal subscribeNext:^(id x) {
        NSLog(@"subscribe value = %@", x);
    }];

```
The `concat` operation merges two signals. Note that the merge order matters.

![](https://img.halfrost.com/Blog/ArticleImage/31_9.png)
```objectivec

- (RACSignal *)concat:(RACSignal *)signal {
   return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

    RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
     // Send the value of the first signal
     [subscriber sendNext:x];
    } error:^(NSError *error) {
     [subscriber sendError:error];
    } completed:^{
     // Subscribe to the second signal
     RACDisposable *concattedDisposable = [signal subscribe:subscriber];
     serialDisposable.disposable = concattedDisposable;
  }];

    serialDisposable.disposable = sourceDisposable;
    return serialDisposable;
 }] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

```
Before merging, both `signal` and `signals` copy and store their respective `didSubscribe`.

After merging, the `didSubscribe` of the newly merged signal copies and stores the block.

When the merged signal is subscribed to:

1. Call the `didSubscribe` of the new merged signal.
2. Because the `concat` method is called on the first signal, `self` in the block is the previous signal, `signal`. The merged signal’s `didSubscribe` first subscribes to `signal`.
3. Because `signal` is subscribed to, `signal` starts executing its `didSubscribe`, `sendNext`, and `sendError`.
4. After the previous signal, `signal`, sends `sendCompleted`, it starts subscribing to the subsequent signal, `signals`, and calls `signals`’s `didSubscribe`.
5. Because the subsequent signal is subscribed to, the subsequent signal, `signals`, starts sending `sendNext`, `sendError`, and `sendCompleted`.

In this way, the two signals are concatenated together in order.

There are two points to note here:  

1. Values from the second signal can only be received after the first signal completes, because the second signal is subscribed to inside the first signal’s `completed` closure. Therefore, if the first signal does not finish, the second signal will not be subscribed to either.
2. After two signals are concatenated together, the completion signal of the new signal is only sent when the second signal completes. As described in the figure above, the send length of the new signal is equal to the sum of the lengths of the two preceding signals, and the completion signal of the new signal after `concat` is the completion signal of the second signal.

`concat` is an ordered composition: the second signal is sent only after the first signal completes.


##### 2. zipWith


![](https://img.halfrost.com/Blog/ArticleImage/31_10.png)


Write the test code:
```objectivec


    RACSignal *concatSignal = [signal zipWith:signals];
    
    [concatSignal subscribeNext:^(id x) {
        NSLog(@"subscribe value = %@", x);
    }];


```
![](https://img.halfrost.com/Blog/ArticleImage/31_11.png)


The source code is as follows:
```objectivec

- (RACSignal *)zipWith:(RACSignal *)signal {
    NSCParameterAssert(signal != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block BOOL selfCompleted = NO;
        NSMutableArray *selfValues = [NSMutableArray array];
        
        __block BOOL otherCompleted = NO;
        NSMutableArray *otherValues = [NSMutableArray array];
        
        void (^sendCompletedIfNecessary)(void) = ^{
            @synchronized (selfValues) {
                BOOL selfEmpty = (selfCompleted && selfValues.count == 0);
                BOOL otherEmpty = (otherCompleted && otherValues.count == 0);
                
                // If either signal has completed and its array is empty, the whole signal is complete
                if (selfEmpty || otherEmpty) [subscriber sendCompleted];
            }
        };
        
        void (^sendNext)(void) = ^{
            @synchronized (selfValues) {
                
                // Return if either array is empty.
                if (selfValues.count == 0) return;
                if (otherValues.count == 0) return;
                
                // Each time, take the values at index 0 from both arrays and pack them into a tuple
                RACTuple *tuple = RACTuplePack(selfValues[0], otherValues[0]);
                [selfValues removeObjectAtIndex:0];
                [otherValues removeObjectAtIndex:0];
                
                // Send the tuple
                [subscriber sendNext:tuple];
                sendCompletedIfNecessary();
            }
        };
        
        // Subscribe to the first signal
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
            @synchronized (selfValues) {
                
                // Add the first signal's value to the array
                [selfValues addObject:x ?: RACTupleNil.tupleNil];
                sendNext();
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            @synchronized (selfValues) {
                
                // When subscription completes, check whether to send completion
                selfCompleted = YES;
                sendCompletedIfNecessary();
            }
        }];
        
        // Subscribe to the second signal
        RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
            @synchronized (selfValues) {
                
                // Add the second signal's value to the array
                [otherValues addObject:x ?: RACTupleNil.tupleNil];
                sendNext();
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            @synchronized (selfValues) {
                
                // When subscription completes, check whether to send completion
                otherCompleted = YES;
                sendCompletedIfNecessary();
            }
        }];
        
        return [RACDisposable disposableWithBlock:^{
            
            // Dispose of both signals
            [selfDisposable dispose];
            [otherDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -zipWith: %@", self.name, signal];
}

```
After two signals are combined with `zipWith`, it looks like the figure above: the two sides of the zipper are pulled together by the slider in the middle. Since it is a zipper, the positions correspond one-to-one: the first position on the upper zipper can only match the first position on the lower zipper. Only then can the zipper be pulled together.

Implementation details:

Inside `zipWith`, there are two arrays, which store the values from the two signals respectively.

1. Once the signal returned by `zipWith` is subscribed to, the `didSubscribe` closure starts executing.
2. Inside the closure, it first subscribes to the first signal. Here, assume the first signal emits a value before the second signal does. Every value emitted by the first signal is appended to the first array and stored there, then the `sendNext( )` closure is invoked. In the `sendNext( )` closure, it first checks whether either of the two arrays is empty. If either array is empty, it returns. Since the second signal has not emitted any value yet—that is, the array for the second signal is empty—the first value cannot be sent here. Therefore, after the first signal is subscribed to, the values it emits are stored in the first array and are not sent out.
3. The value from the second signal is emitted immediately afterward. Each time the second signal emits a value, that value is also stored in the second array. However, when the `sendNext( )` closure is invoked at this point, it no longer returns, because both arrays now contain values: position 0 in both arrays has a value. Once values are available, they are packaged into an `RACTuple` and sent out. Then the values stored at position 0 in both arrays are cleared.
4. From then on, whenever either signal emits a value, it is first stored in its array. As long as there is a “matching” value from the other signal, the two values are packaged together into an `RACTuple` and sent out. As can also be seen from the figure, for the new signal produced by `zipWith`, each emission time is equal to the later emission time of the two source signals.
5. The new signal completes when either of the two signals has completed and its corresponding array is empty. So the final value `5` emitted by the first signal is discarded.

The values `1`, `2`, `3`, and `4` emitted in sequence by the first signal are combined one-to-one with the values `A`, `B`, `C`, and `D` emitted in sequence by the second signal, just like a zipper pulling them together. Since `5` cannot be paired, the zipper can no longer be closed.


#### V. Finally

Originally, I wanted to analyze `Map`, `combineLatest`, `flattenMap`, and `flatten` in this article as well. But after seeing that `RACSingnal` has quite a few operations, I decided to split the analysis according to the source files. Here, I first finished analyzing all the operations in the `RACSignal` file. The main operations in the `RACSignal` file are `bind`, `concat`, and `zipWith`. In the next article, I will analyze all the operations in the `RACSignal\+Operations` file.

Feedback and suggestions are welcome.