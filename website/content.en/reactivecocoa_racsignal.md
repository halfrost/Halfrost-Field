+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
date = 2016-11-14T09:48:43Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/31_0_.png"
slug = "reactivecocoa_racsignal"
tags = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
title = "How RACSignal Sends Signals in ReactiveCocoa"

+++


#### Preface

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) is an open-source library that (the first?) brought the functional reactive programming paradigm to Objective-C. ReactiveCocoa was written by the two great engineers [Josh Abernathy](https://github.com/joshaber) and [Justin Spahr-Summers](https://github.com/jspahrsummers) during the development of [GitHub for Mac](http://mac.github.com/). [Justin Spahr-Summers](https://github.com/jspahrsummers) made the first commit at 12:35 PM on November 13, 2011, and the project reached its first major milestone with the [1.0 release](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v1.0.0) at 3:05 AM on February 13, 2013. The ReactiveCocoa community has also been very active. The latest version has completed ReactiveCocoa 5.0.0-alpha.3 and is currently under development for 5.0.0-alpha.4.

ReactiveCocoa v2.5 is widely regarded as the most stable Objective-C version, and has therefore been adopted by many client-side teams whose primary language is Objective-C. ReactiveCocoa v3.x is primarily based on Swift 1.2, while ReactiveCocoa v4.x is primarily based on Swift 2.x. ReactiveCocoa 5.0 will fully support Swift 3.0, and perhaps Swift 4.0 in the future. In the next few blog posts, I will use ReactiveCocoa v2.5 as an example to analyze the concrete implementation of the Objective-C version of RAC (perhaps by the time the analysis is finished, RAC 5.0 will have arrived). Consider this a blessing written on the eve of the official ReactiveCocoa 5.0 release.


#### Table of Contents
- 1. What is ReactiveCocoa?
- 2. The core `RACSignal` sending and subscription flow in RAC
- 3. The core `bind` implementation of `RACSignal` operations
- 4. The implementation of basic `RACSignal` operations `concat` and `zipWith`
- 5. Conclusion

#### I. What is ReactiveCocoa?

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) (abbreviated as RAC) is a new framework open-sourced by [Github](https://github.com/blog/1107-reactivecocoa-for-a-better-world) for iOS and OS X development. RAC has the characteristics of functional programming (FP) and reactive programming (RP). Its design and implementation are mainly inspired by .NET's [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609).

The purpose of ReactiveCocoa is “Streams of values over time”: data streams that continuously flow as time changes.

ReactiveCocoa primarily solves the following problems:

- UI data binding

UI controls usually need to bind an event, and RAC makes it very convenient to bind any data stream to a control.

- User interaction event binding

RAC provides a series of methods for interactive UI controls that can send `Signal` signals. These data streams are passed among one another during user interaction.

- Solving the problem of excessive state and dependencies between states

With RAC bindings, you no longer need to worry about various complex states such as `isSelect`, `isFinish`, and so on. It also solves the problem that these states become difficult to maintain later on.

- A unified messaging mechanism

In Objective-C programming, there were originally several messaging mechanisms: Delegate, Block Callback, Target-Action, Timers, and KVO. There is an article on objc about how to choose among these five messaging patterns in Objective-C, [Communication Patterns](https://www.objccn.io/issue-7-4/), which I recommend reading. Now that we have RAC, all five of the above approaches can be handled uniformly with RAC.

#### II. The core `RACSignal` in RAC

One of the core concepts in ReactiveCocoa is the signal `RACStream`. `RACStream` has two subclasses: `RACSignal` and `RACSequence`. This article will first analyze `RACSignal`.


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
When RACSignal calls createSignal, it invokes RACDynamicSignal's createSignal method.


![](https://img.halfrost.com/Blog/ArticleImage/31_1.png)


RACDynamicSignal is a subclass of RACSignal. The parameter following createSignal is a block.
```objectivec

(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe

```
The return value of the block is of type `RACDisposable`, and the block is named `didSubscribe`. The block has a single parameter, `subscriber`, of type `id<RACSubscriber>`; this `subscriber` must conform to the `RACSubscriber` protocol.

`RACSubscriber` is a protocol that defines the following four protocol methods:
```objectivec

@protocol RACSubscriber <NSObject>
@required

- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)disposable;

@end

```
Therefore, the task of creating a new `Signal` falls entirely to `RACDynamicSignal`, a subclass of `RACSignal`.
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
This method creates a new `RACDynamicSignal` object, `signal`, and stores the passed-in `didSubscribe` block in the `didSubscribe` property of the newly created `signal` object. Finally, it names `signal` `+createSignal:`.
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


The block of `RACSignal` is saved in this way. So when will it be executed?

![](https://img.halfrost.com/Blog/ArticleImage/31_3.png)


The block closure is only “released” when a subscription is made.

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
The `RACSubscriber` class is very simple. It has only four properties: `nextBlock`, `errorBlock`, `completedBlock`, and a `RACCompoundDisposable` signal.
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


The subscriberWithNext method stores the three blocks passed in, each in its corresponding block.


When RACSignal calls the subscribeNext method, it eventually calls [self subscribe:o] when returning. In practice, this invokes the subscribe method in the RACDynamicSignal class.
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
`RACDisposable` has three subclasses, one of which is `RACCompoundDisposable`.


![](https://img.halfrost.com/Blog/ArticleImage/31_5.png)
```objectivec


@interface RACCompoundDisposable : RACDisposable
+ (instancetype)compoundDisposable;
+ (instancetype)compoundDisposableWithDisposables:(NSArray *)disposables;
- (void)addDisposable:(RACDisposable *)disposable;
- (void)removeDisposable:(RACDisposable *)disposable;
@end

```
Although `RACCompoundDisposable` is a subclass of `RACDisposable`, it can contain multiple `RACDisposable` objects. When needed, you can call `dispose` on all of them at once to tear down the signal. When a `RACCompoundDisposable` object is disposed, it also automatically disposes all `RACDisposable` objects in its container.

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

The `RACPassthroughSubscriber` class holds three very important objects: `RACSubscriber`, `RACSignal`, and `RACCompoundDisposable`. `RACSubscriber` is the subscriber of the signal to be forwarded. `RACCompoundDisposable` is the subscriber’s disposable object; once it has been disposed, the `innerSubscriber` will no longer receive the event stream.

One thing to note here is that it also stores an internal `RACSignal`, and its attribute is `unsafe_unretained`. This differs from the other two properties, which are both `strong`. The reason this is not `weak` is that the reference to `RACSignal` is only a probe for DTrace dynamic tracing. Setting it to `weak` would introduce unnecessary performance overhead. Therefore, `unsafe_unretained` is sufficient here.
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
When retrieving `currentScheduler`, it checks whether `currentScheduler` exists and whether execution is on the main thread. If neither condition is met, it invokes the background `backgroundScheduler` to execute `schedule`.

The input parameter to `schedule` is a block. When `schedule` is executed, it executes that block. In other words, it executes:
```objectivec

RACDisposable *innerDisposable = self.didSubscribe(subscriber);
   [disposable addDisposable:innerDisposable];

```
These two statements are key. The block previously stored in the signal will be “released” and executed here. The statement `self.didSubscribe(subscriber)` executes the `didSubscribe` closure stored by the signal.

Inside the `didSubscribe` closure, there are `sendNext`, `sendError`, and `sendCompleted`; executing these statements will respectively call the corresponding methods in `RACPassthroughSubscriber`.
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
At this point, the subscriber is `RACPassthroughSubscriber`. The `innerSubscriber` inside `RACPassthroughSubscriber` is the actual final subscriber, and `RACPassthroughSubscriber` will continue forwarding the value to `innerSubscriber`.
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
innerSubscriber is a RACSubscriber. When `sendNext` is called, it first makes a copy of its own `self.next` closure and then invokes it. The entire process is also thread-safe, protected by `@synchronized`. This is where the final subscriber’s closure is invoked.

`sendError` and `sendCompleted` work the same way.

To summarize:

![](https://img.halfrost.com/Blog/ArticleImage/31_6.png)


1. RACSignal calls the `subscribeNext` method and creates a new RACSubscriber.
2. The newly created RACSubscriber copies `nextBlock`, `errorBlock`, and `completedBlock` and stores them in its own properties.
3. The RACDynamicSignal subclass of RACSignal calls the `subscribe` method.
4. New RACCompoundDisposable and RACPassthroughSubscriber objects are created. RACPassthroughSubscriber keeps references to RACSignal, RACSubscriber, and RACCompoundDisposable respectively. Note that the reference to RACSignal is `unsafe\_unretained`.
5. RACDynamicSignal invokes the `didSubscribe` closure. It first calls the corresponding `sendNext`, `sendError`, and `sendCompleted` methods on RACPassthroughSubscriber.
6. RACPassthroughSubscriber then calls `self.innerSubscriber`, that is, the `nextBlock`, `errorBlock`, and `completedBlock` of RACSubscriber. Note that this invocation also first makes a copy and then executes the closure.


#### III. Core `bind` Implementation for RACSignal Operations


![](https://img.halfrost.com/Blog/ArticleImage/31_7.png)


The RACSignal source code includes two basic operations: `concat` and `zipWith`. Before analyzing these two operations, however, let’s first look at an even more fundamental function: the `bind` operation.

First, let’s describe what the `bind` function does:
1. It subscribes to the original signal.
2. Whenever the original signal sends a value, the bound block transforms it once.
3. Once the bound block transforms the value into a signal, that signal is immediately subscribed to, and the value is sent to the subscriber.
4. If the bound block wants to terminate the binding, the original signal completes.
5. When all signals have completed, a completed signal is sent to the subscriber.
6. If any error occurs in any signal along the way, that error must be sent to the subscriber.
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
To figure out what the `bind` function actually does, write some test code:
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
Since the first chapter already covered the entire process of creating and subscribing to an `RACSignal` in detail, the creation of `RACDynamicSignal`, `RACCompoundDisposable`, and `RACPassthroughSubscriber` is omitted here as well for the sake of explaining the method. This section focuses on analyzing how each closure in `bind` is passed around, created, and subscribed to.

To prevent the following analysis from becoming confusing for readers, let’s first number the blocks that will be used.
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
First create the `signal`; `didSubscribe` copies and stores `block1`.

When `bind` is called on the signal to perform binding, `block5` is invoked, and `didSubscribe` copies and stores `block6`.

When the subscriber starts subscribing to `bindSignal`, the flow is as follows:  
1. `bindSignal` executes the `didSubscribe` block, i.e. executes `block6`.
2. The first line of code in `block6` calls `RACStreamBindBlock bindingBlock = block()`. Here, `block` is the externally passed-in `block2`, so `block2` starts executing. After `block2` finishes, it returns a `RACStreamBindBlock` object.
3. Because `bind` is called on `signal`, `self` inside the `bind` function is `signal`. Inside `bind`, it subscribes to the `signal`. Therefore, `subscribeNext` executes `block1`.
4. When `block1` executes, `sendNext` calls the subscriber’s `nextBlock`, so `block10` starts executing.
5. In `block10`, it first calls `bindingBlock`, which is the return value from the earlier call to `block2`. This `RACStreamBindBlock` object stores `block3`, so `block3` starts executing.
6. In `block3`, the input parameter is a `value`. This `value` is the value emitted by `sendNext` in `signal`. Inside `block3`, the `value` can be transformed. After the transformation, a new signal `signal'` is returned.
7. If the returned `signal'` is empty, `completeSignal` is called, i.e. `block7` is called. `block7` sends `sendCompleted`. If the returned `signal'` is not empty, `addSignal` is called, i.e. `block8` is called. `block8` continues to subscribe to `signal'`. Since `signal'` is the return value of the external `bind` function, and the returned signal is of type `RACReturnSignal`, it calls `sendNext` as soon as it is subscribed to, which executes `block9`.
8. `block9` calls `sendNext`. Here, `subscriber` is the input parameter of `block6`, so calling `sendNext` on `subscriber` invokes `block4` of `bindSignal`’s subscriber.
9. After `block9` finishes executing `sendNext`, it also calls `sendCompleted`. This happens inside the `completed` closure in `block9`. `completeSignal(signal, selfDisposable);` is then called, which in turn calls `completeSignal`, i.e. `block7`.
10. After `block7` finishes executing, the entire process of `signal` sending a `sendNext` signal once is complete.


The entire `bind` flow is now complete.


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
The `concat` operation merges two signals. Note that the order of merging matters.

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
Before merging, `signal` and `signals` each save and copy their own `didSubscribe`.

After merging, the new merged signal’s `didSubscribe` saves and copies the block.

When the merged signal is subscribed to:

1. The new merged signal’s `didSubscribe` is called.
2. Because the `concat` method is called on the first signal, `self` in the block is the previous signal, `signal`. The merged signal’s `didSubscribe` first subscribes to `signal`.
3. Because `signal` is subscribed to, `signal`’s `didSubscribe` starts executing, sending `sendNext` and `sendError`.
4. After the previous signal, `signal`, sends `sendCompleted`, it starts subscribing to the next signal, `signals`, and calls `signals`’s `didSubscribe`.
5. Because the next signal is subscribed to, the next signal, `signals`, starts sending `sendNext`, `sendError`, and `sendCompleted`.

This way, the two signals are concatenated together in order.

There are two points to note here:  

1. The values from the second signal can only be received after the first signal has completed. Because the second signal is subscribed to inside the completion closure of the first signal, if the first signal does not terminate, the second signal will not be subscribed to either.
2. After the two signals are concatenated together with `concat`, the completion signal of the new signal is only completed when the second signal completes. As shown in the diagram above, the emission length of the new signal equals the sum of the lengths of the two previous signals, and the completion signal of the new signal after `concat` is also the completion signal of the second signal.

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
                
                // If either signal has completed and its array is empty, the whole signal is considered completed
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
                
                // On completion, check whether to send completed
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
                
                // On completion, check whether to send completed
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
After two signals are combined with `zipWith`, it is just like the diagram above: the two sides of the zipper are pulled together by the slider in the middle. Since it is a zipper, the positions must correspond one-to-one: the first position on the upper zipper can only line up with the first position on the lower zipper. Only then can the zipper be pulled together.

Concrete implementation:

Inside `zipWith`, there are two arrays, which store the values from the two signals respectively.

1. Once the signal returned by `zipWith` is subscribed to, the `didSubscribe` closure starts executing.
2. Inside the closure, it first subscribes to the first signal. Suppose here that the first signal emits a value before the second signal does. Every value emitted by the first signal is added to the first array and stored there, and then the `sendNext( )` closure is called. Inside the `sendNext( )` closure, it first checks whether either of the two arrays is empty. If one of them is empty, it returns. Since the second signal has not emitted a value yet—that is, the array for the second signal is empty—the first value cannot be sent at this point. Therefore, after the first signal is subscribed to, the emitted value is stored in the first array and is not sent out.
3. The value from the second signal is emitted immediately afterward. Every time the second signal emits a value, that value is also stored in the second array. But when the `sendNext( )` closure is called at this point, it will no longer return, because both arrays now have values: position 0 in each array contains a value. Once values are available, they are packaged into a `RACTuple` and sent out. Then the values stored at position 0 in both arrays are cleared.
4. After that, every time either signal emits a value, the value is first stored in its array. As long as there is a “paired” value from the other signal, the two values are packaged together into a `RACTuple` and sent out. As can also be seen from the diagram, for the new signal produced by `zipWith`, each emission time is equal to the later emission time of the two original signals.
5. The new signal completes when either of the two original signals completes and its corresponding array is empty. So the final value `5` emitted by the first signal is discarded.

The values `1`, `2`, `3`, `4` emitted in order by the first signal and the values `A`, `B`, `C`, `D` emitted in order by the second signal are combined one-to-one, just like a zipper pulling them together. Since `5` cannot be paired, the zipper cannot be zipped any further.


#### V. Final Notes

Originally, I wanted to analyze `Map`, `combineLatest`, `flattenMap`, and `flatten` in this article as well. But later I saw that `RACSingnal` has quite a lot of operations, so I split the analysis according to the source files. Here, I first finished analyzing all the operations in the `RACSignal` file. The main operations in the `RACSignal` file are `bind`, `concat`, and `zipWith`. In the next article, I will analyze all the operations in the `RACSignal\+Operations` file.

Comments and corrections are welcome.