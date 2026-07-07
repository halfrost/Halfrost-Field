+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "ReactiveCocoa", "RAC", "RACSignal"]
date = 2016-12-04T22:15:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/34_0_.jpg"
slug = "reactivecocoa_hot_cold_signal"
tags = ["iOS", "ReactiveCocoa", "RAC", "RACSignal"]
title = "Analysis of the Underlying Implementation of Cold and Hot RACSignal Signals in ReactiveCocoa"

+++


### Preface

Among articles about cold and hot signals in ReactiveCocoa v2.5, the most famous are the three articles on cold and hot signals written by Mr. Zang Chengwei from Meituan:

[A Closer Look at Cold and Hot Signals in ReactiveCocoa (Part 1)](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html)  
[A Closer Look at Cold and Hot Signals in ReactiveCocoa (Part 2): Why Distinguish Between Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)  
[A Closer Look at Cold and Hot Signals in ReactiveCocoa (Part 3): How to Handle Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-3.html)  

Since I have recently been writing articles analyzing the underlying implementation of `RACSignal`, I naturally cannot avoid analyzing operations related to cold and hot signals. This article intends to analyze the underlying implementation of converting a cold signal into a hot signal.


### Table of Contents

- 1. Concepts of cold signals and hot signals
- 2. `RACSignal` hot signals
- 3. `RACSignal` cold signals
- 4. How cold signals are converted into hot signals


### 1. Concepts of Cold Signals and Hot Signals

![](https://img.halfrost.com/Blog/ArticleImage/34_1.png)


The concepts of cold and hot signals originate from Hot Observable and Cold Observable in the .NET framework [Reactive Extensions (RX)](https://msdn.microsoft.com/en-us/library/hh242985.aspx),


>A Hot Observable is active. Even if you have not subscribed to the event, it keeps pushing events all the time, like mouse movement; a Cold Observable is passive. It publishes messages only when you subscribe to it.

>A Hot Observable can have multiple subscribers; it is one-to-many, and the collection can share information with subscribers. A Cold Observable can only be one-to-one; when there are different subscribers, the messages are resent in full from the beginning.


This article, [A Closer Look at Cold and Hot Signals in ReactiveCocoa (Part 1)](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html), analyzes the characteristics of cold and hot signals in detail:

**A hot signal is active. Even if you have not subscribed to the event, it still keeps pushing events all the time. A cold signal is passive. It sends messages only when you subscribe to it.**

**A hot signal can have multiple subscribers; it is one-to-many, and the signal can share information with subscribers. A cold signal can only be one-to-one; when there are different subscribers, the messages are resent in full from the beginning.**

### 2. `RACSignal` Hot Signals


![](https://img.halfrost.com/Blog/ArticleImage/34_2.png)


In the `RACSignal` family, the following signals match the characteristics of hot signals.

#### 1. `RACSubject`
```objectivec


@interface RACSubject : RACSignal <RACSubscriber>

@property (nonatomic, strong, readonly) NSMutableArray *subscribers;
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;
+ (instancetype)subject;

@end

```
First, let's look at the definition of `RACSubject`.

`RACSubject` inherits from `RACSignal`, and it also conforms to the `RACSubscriber` protocol. This means it can both subscribe to signals and send signals.

Inside `RACSubject`, there is an `NSMutableArray` that holds all subscribers to the signal. There is also a `RACCompoundDisposable` that holds the `RACDisposable` instances for all subscribers to the signal.

The reason `RACSubject` can be called a hot signal is that it must satisfy the definition of a hot signal described above. Let's look at its implementation to see how it does so.
```objectivec


- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];
    
    NSMutableArray *subscribers = self.subscribers;
    @synchronized (subscribers) {
        [subscribers addObject:subscriber];
    }
    
    return [RACDisposable disposableWithBlock:^{
        @synchronized (subscribers) {
            NSUInteger index = [subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
                return obj == subscriber;
            }];
            
            if (index != NSNotFound) [subscribers removeObjectAtIndex:index];
        }
    }];
}


```
The above is the implementation of `RACSubject`. The biggest difference between it and `RACSignal` is in these two lines.
```objectivec

NSMutableArray *subscribers = self.subscribers;
@synchronized (subscribers) {
    [subscribers addObject:subscriber];
}

```
RACSubject stores all of its subscribers in an `NSMutableArray`. Since it keeps track of all subscribers, `sendNext`, `sendError`, and `sendCompleted` need to change accordingly.
```objectivec


- (void)sendNext:(id)value {
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendNext:value];
    }];
}

- (void)sendError:(NSError *)error {
    [self.disposable dispose];
    
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendError:error];
    }];
}

- (void)sendCompleted {
    [self.disposable dispose];
    
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendCompleted];
    }];
}


```
From the source code, you can see that `sendNext`, `sendError`, and `sendCompleted` in `RACSubject` all execute the `enumerateSubscribersUsingBlock:` method.
```objectivec

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block {
    NSArray *subscribers;
    @synchronized (self.subscribers) {
        subscribers = [self.subscribers copy];
    }
    
    for (id<RACSubscriber> subscriber in subscribers) {
        block(subscriber);
    }
}

```
The `enumerateSubscribersUsingBlock:` method retrieves all subscribers of the RACSubject and invokes the input `block( )` method on each of them in order.

For the subscription and sending flow of RACSubject, you can refer to the [first article](https://halfrost.com/reactivecocoa_racsignal/). The overall process is largely the same; the main difference is that it sends signals to its own subscribers one by one.

RACSubject satisfies the characteristics of a hot signal. Even if it has no subscribers, because it conforms to the RACSubscriber protocol through inheritance, it can send signals by itself. A cold signal can only send signals after it has been subscribed to.

RACSubject can have many subscribers, and it stores all of these subscribers in its own array. When RACSubject sends signals later, the subscribers are like people watching TV together: programs that have already aired cannot be watched anymore, and signals that have already been sent cannot be received anymore. They receive signals. With RACSignal, however, sending signals and receiving signals by subscribers can only start from the beginning, like watching on-demand content—every time you watch, you start from the beginning.


#### 2. RACGroupedSignal
```objectivec

@interface RACGroupedSignal : RACSubject

@property (nonatomic, readonly, copy) id<NSCopying> key;
+ (instancetype)signalWithKey:(id<NSCopying>)key;
@end

```
First, let's look at the definition of RACGroupedSignal.


RACGroupedSignal is used in the RACsignal method.
```objectivec

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock

```
In this method, the signal is ultimately sent by `RACGroupedSignal` inside `sendNext`.
```objectivec

[groupSubject sendNext:transformBlock != NULL ? transformBlock(x) : x];

```
For a detailed analysis of `groupBy`, see this [article](https://halfrost.com/reactivecocoa_racsignal_operations2/).


#### 3. RACBehaviorSubject
```objectivec

@interface RACBehaviorSubject : RACSubject
@property (nonatomic, strong) id currentValue;
+ (instancetype)behaviorSubjectWithDefaultValue:(id)value;
@end

```
This signal stores an object `currentValue`, which holds the latest value of the signal.

Of course, you can also call the class method `behaviorSubjectWithDefaultValue`.
```objectivec

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value {
    RACBehaviorSubject *subject = [self subject];
    subject.currentValue = value;
    return subject;
}


```
Store the default value in this method. If `RACBehaviorSubject` has not received any value, then this signal will send this default value.

When `RACBehaviorSubject` is subscribed to:
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
`sendNext` always sends the stored `currentValue`. Calling `sendNext` invokes `sendNext` in `RACSubject`, which then sends the signal value to each subscriber in the subscribers array in sequence.

When `RACBehaviorSubject` calls `sendNext` on its subscribers:
```objectivec

- (void)sendNext:(id)value {
    @synchronized (self) {
        self.currentValue = value;
        [super sendNext:value];
    }
}

```
RACBehaviorSubject updates `currentValue` with the value it sends. The next time it sends a value, it will send the most recently updated value.


#### 4. RACReplaySubject
```objectivec


const NSUInteger RACReplaySubjectUnlimitedCapacity = NSUIntegerMax;
@interface RACReplaySubject : RACSubject

@property (nonatomic, assign, readonly) NSUInteger capacity;
@property (nonatomic, strong, readonly) NSMutableArray *valuesReceived;
@property (nonatomic, assign) BOOL hasCompleted;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, strong) NSError *error;
+ (instancetype)replaySubjectWithCapacity:(NSUInteger)capacity;

@end

```
`RACReplaySubject` stores historical values with a capacity of `RACReplaySubjectUnlimitedCapacity`.
```objectivec


+ (instancetype)replaySubjectWithCapacity:(NSUInteger)capacity {
    return [(RACReplaySubject *)[self alloc] initWithCapacity:capacity];
}

- (instancetype)init {
    return [self initWithCapacity:RACReplaySubjectUnlimitedCapacity];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self == nil) return nil;
    
    _capacity = capacity;
    _valuesReceived = (capacity == RACReplaySubjectUnlimitedCapacity ? [NSMutableArray array] : [NSMutableArray arrayWithCapacity:capacity]);
    
    return self;
}


```
During `RACReplaySubject` initialization, an array with the specified `capacity` is initialized.
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
    
    RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
        @synchronized (self) {
            for (id value in self.valuesReceived) {
                if (compoundDisposable.disposed) return;
                
                [subscriber sendNext:(value == RACTupleNil.tupleNil ? nil : value)];
            }
            
            if (compoundDisposable.disposed) return;
            
            if (self.hasCompleted) {
                [subscriber sendCompleted];
            } else if (self.hasError) {
                [subscriber sendError:self.error];
            } else {
                RACDisposable *subscriptionDisposable = [super subscribe:subscriber];
                [compoundDisposable addDisposable:subscriptionDisposable];
            }
        }
    }];
    
    [compoundDisposable addDisposable:schedulingDisposable];
    
    return compoundDisposable;
}

```
When an `RACReplaySubject` is subscribed to, it sends out all the values in the `valuesReceived` array.
```objectivec


- (void)sendNext:(id)value {
    @synchronized (self) {
        [self.valuesReceived addObject:value ?: RACTupleNil.tupleNil];
        [super sendNext:value];
        
        if (self.capacity != RACReplaySubjectUnlimitedCapacity && self.valuesReceived.count > self.capacity) {
            [self.valuesReceived removeObjectsInRange:NSMakeRange(0, self.valuesReceived.count - self.capacity)];
        }
    }
}


```
In `sendNext`, `valuesReceived` stores each received value. Calling `super`’s `sendNext` sends each value to every subscriber in sequence.

It also checks how many values are stored in the array. If the number of stored values exceeds `capacity`, it removes the first few values starting from index 0, ensuring that the array contains only `capacity` values.


The difference between `RACReplaySubject` and `RACSubject` is that `RACReplaySubject` also stores historical signal values and sends them to subscribers. In this respect, `RACReplaySubject` is more like a combination of `RACSingnal` and `RACSubject`. `RACSignal` is a cold signal: once subscribed to, it sends all values to the subscriber. `RACReplaySubject` is the same as `RACSignal` in this regard. However, `RACReplaySubject` also has the characteristics of `RACSubject`: it sends all values to multiple subscribers. After `RACReplaySubject` finishes sending the historical values it previously stored, its subsequent signal-sending behavior is exactly the same as `RACSubject`.


### III. `RACSignal` Cold Signals


![](https://img.halfrost.com/Blog/ArticleImage/34_3.png)


In ReactiveCocoa v2.5, in addition to `RACsignal` signals, there are also some special cold signals.

#### 1. `RACEmptySignal`
```objectivec

@interface RACEmptySignal : RACSignal
+ (RACSignal *)empty;
@end

```
This signal has only one empty method.
```objectivec

+ (RACSignal *)empty {

#ifdef DEBUG
    return [[[self alloc] init] setNameWithFormat:@"+empty"];

#else
    static id singleton;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        singleton = [[self alloc] init];
    });
    
    return singleton;

#endif
}

```
In debug mode, return a signal named empty. In release mode, return a singleton empty signal.
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```
RACEmptySignal sends sendCompleted as soon as it is subscribed to.


#### 2. RACReturnSignal
```objectivec


@interface RACReturnSignal : RACSignal
@property (nonatomic, strong, readonly) id value;
+ (RACSignal *)return:(id)value;
@end

```
The definition of the RACReturnSignal signal is also very simple: it directly returns an RACSignal based on the value of value.
```objectivec


+ (RACSignal *)return:(id)value {

#ifndef DEBUG
    if (value == RACUnit.defaultUnit) {
        static RACReturnSignal *unitSingleton;
        static dispatch_once_t unitPred;
        
        dispatch_once(&unitPred, ^{
            unitSingleton = [[self alloc] init];
            unitSingleton->_value = RACUnit.defaultUnit;
        });
        
        return unitSingleton;
    } else if (value == nil) {
        static RACReturnSignal *nilSingleton;
        static dispatch_once_t nilPred;
        
        dispatch_once(&nilPred, ^{
            nilSingleton = [[self alloc] init];
            nilSingleton->_value = nil;
        });
        
        return nilSingleton;
    }

#endif
    
    RACReturnSignal *signal = [[self alloc] init];
    signal->_value = value;
    
#ifdef DEBUG
    [signal setNameWithFormat:@"+return: %@", value];

#endif
    
    return signal;
}

```
In debug mode, a new `RACReturnSignal` signal is created directly, and the value it stores is the input argument `value`. In release mode, the corresponding singleton `RACReturnSignal` is created based on whether `value` is `nil`.
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);

 return [RACScheduler.subscriptionScheduler schedule:^{
    [subscriber sendNext:self.value];
    [subscriber sendCompleted];
 }];
}

```
When RACReturnSignal is subscribed to, it sends only a signal with a single value. After sending it, it calls sendCompleted.


#### 3. RACDynamicSignal


This signal is the actual implementation behind creating one with RACSignal createSignal:. For the detailed process of RACDynamicSignal, see [the first article](https://halfrost.com/reactivecocoa_racsignal/).


#### 4. RACErrorSignal
```objectivec

@interface RACErrorSignal : RACSignal
@property (nonatomic, strong, readonly) NSError *error;
+ (RACSignal *)error:(NSError *)error;
@end

```
The `RACErrorSignal` signal stores an `NSError`.
```objectivec

+ (RACSignal *)error:(NSError *)error {
    RACErrorSignal *signal = [[self alloc] init];
    signal->_error = error;
    
#ifdef DEBUG
    [signal setNameWithFormat:@"+error: %@", error];

#else
    signal.name = @"+error:";

#endif
    
    return signal;
}

```
When `RACErrorSignal` is initialized, it stores the externally passed-in `Error`. When it is subscribed to, it sends out this `Error`.


#### 5. RACChannelTerminal
```objectivec

@interface RACChannelTerminal : RACSignal <RACSubscriber>

- (id)init __attribute__((unavailable("Instantiate a RACChannel instead")));

@property (nonatomic, strong, readonly) RACSignal *values;
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;
- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

```
RACChannelTerminal is used for bidirectional binding in day-to-day RAC development. Like RACSubject, it both inherits from RACSignal and conforms to the RACSubscriber protocol. Although it has RACSubject’s ability to send and receive signals, it is still a cold signal because it cannot do one-to-many; the signals it sends are still only one-to-one.

RACChannelTerminal cannot be initialized manually; it must be initialized through RACChannel.
```objectivec

- (id)init {
    self = [super init];
    if (self == nil) return nil;
    
    RACReplaySubject *leadingSubject = [[RACReplaySubject replaySubjectWithCapacity:0] setNameWithFormat:@"leadingSubject"];
    RACReplaySubject *followingSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"followingSubject"];
    
    [[leadingSubject ignoreValues] subscribe:followingSubject];
    [[followingSubject ignoreValues] subscribe:leadingSubject];
    
    _leadingTerminal = [[[RACChannelTerminal alloc] initWithValues:leadingSubject otherTerminal:followingSubject] setNameWithFormat:@"leadingTerminal"];
    _followingTerminal = [[[RACChannelTerminal alloc] initWithValues:followingSubject otherTerminal:leadingSubject] setNameWithFormat:@"followingTerminal"];
    
    return self;
}

```
During the initialization of `RACChannel`, the `initWithValues:` method of `RACChannelTerminal` is called, and the arguments passed here are all of type `RACReplaySubject`. Therefore, when subscribing to `RACChannelTerminal`:
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    return [self.values subscribe:subscriber];
}

```
`self.values` is essentially a `RACReplaySubject`, which is equivalent to subscribing to a `RACReplaySubject`. The subscription process is the same as the `RACReplaySubject` subscription process described above.
```objectivec

- (void)sendNext:(id)value {
    [self.otherTerminal sendNext:value];
}

- (void)sendError:(NSError *)error {
    [self.otherTerminal sendError:error];
}

- (void)sendCompleted {
    [self.otherTerminal sendCompleted];
}

```
`self.otherTerminal` is also of type `RACReplaySubject`. Both ends of the `RACChannelTerminal` pipe are signals of type `RACReplaySubject`. When `RACChannelTerminal` starts to `sendNext`, `sendError`, or `sendCompleted`, it invokes the corresponding operation on the `RACReplaySubject` of the other side of the pipe.

A common use case for `RACChannelTerminal` is two-way binding between the View and the ViewModel.

For example, on a login screen, the password `TextField` and the ViewModel’s `Password` can be bound bidirectionally.
```objectivec


    RACChannelTerminal *passwordTerminal = [_passwordTextField rac_newTextChannel];
    RACChannelTerminal *viewModelPasswordTerminal = RACChannelTo(_viewModel, password);
    [viewModelPasswordTerminal subscribe:passwordTerminal];
    [passwordTerminal subscribe:viewModelPasswordTerminal];

```
Both signals in a two-way binding will receive new signals as a result of changes from the other side.


At this point, all categories of `RACSignal` have been clarified, and they have also been classified according to cold signals and hot signals.

![](https://img.halfrost.com/Blog/ArticleImage/34_4.png)


### IV. How Cold Signals Are Converted into Hot Signals

![](https://img.halfrost.com/Blog/ArticleImage/34_5.png)


Why do we sometimes need to convert a cold signal into a hot signal? For details, see the example in this article: [A Detailed Discussion of Cold Signals and Hot Signals in ReactiveCocoa (Part 2): Why Distinguish Between Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)


Based on the process by which `RACSignal` is subscribed to and sends signals, we know that every time a cold `RACSignal` is subscribed to, the `didSubscribe` closure is executed once. This is where problems can arise. If the `RACSignal` is used for a network request, the request will be executed repeatedly inside the `didSubscribe` closure. The article mentioned above describes a signal being subscribed to 6 times, causing the network request to be made 6 times as well. This is not what we want. The network request only needs to be made once.

To ensure that the signal executes the `didSubscribe` closure only once, the most important point is that a cold `RACSignal` can only be subscribed to once. Since a cold signal can only be one-to-one, if we want one-to-many, we have to hand it over to a hot signal. This is when we need to convert the cold signal into a hot signal.

In ReactiveCocoa v2.5, converting a cold signal into a hot signal requires the `RACMulticastConnection` class.
```objectivec


@interface RACMulticastConnection : NSObject
@property (nonatomic, strong, readonly) RACSignal *signal;
- (RACDisposable *)connect;
- (RACSignal *)autoconnect;
@end


@interface RACMulticastConnection () {
	RACSubject *_signal;
	int32_t volatile _hasConnected;
}
@property (nonatomic, readonly, strong) RACSignal *sourceSignal;
@property (strong) RACSerialDisposable *serialDisposable;
@end

```
Take a look at the definition of the `RACMulticastConnection` class. The most important part is that it stores two signals: one is an `RACSubject`, and the other is `sourceSignal` (of type `RACSignal`). What is exposed externally in the `.h` file is an `RACSignal`, while what is actually used internally in the `.m` file is an `RACSubject`. From its definition, you can already infer what it is going to do next: use `sourceSignal` to send signals, and internally use `RACSubject` to subscribe to `sourceSignal`; then `RACSubject` forwards the signal values from `sourceSignal` to its subscribers in sequence.


![](https://img.halfrost.com/Blog/ArticleImage/34_6.png)


To describe `RACMulticastConnection` with a somewhat imperfect analogy, it is like the “Earth” in the center of the diagram above. The “Earth” is the `RACSubject` that has subscribed to `sourceSignal`, and the `RACSubject` sends values to each “connected” party (subscriber). `sourceSignal` has only one subscriber—the internal `RACSubject`—so this achieves exactly what we want: execute the `didSubscribe` closure only once, while still sending values to each subscriber.


Now let’s look at the initialization of `RACMulticastConnection`.
```objectivec

- (id)initWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject {
	NSCParameterAssert(source != nil);
	NSCParameterAssert(subject != nil);

	self = [super init];
	if (self == nil) return nil;

	_sourceSignal = source;
	_serialDisposable = [[RACSerialDisposable alloc] init];
	_signal = subject;
	
	return self;
}

```
The initialization method saves the externally passed-in `RACSignal` as `sourceSignal`, and saves the externally passed-in `RACSubject` as its own `signal` property.

`RACMulticastConnection` has two connection methods.
```objectivec


- (RACDisposable *)connect {
	BOOL shouldConnect = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasConnected);

	if (shouldConnect) {
		self.serialDisposable.disposable = [self.sourceSignal subscribe:_signal];
	}
	return self.serialDisposable;
}

```
A relatively uncommon function appears here: `OSAtomicCompareAndSwap32Barrier`. It is an atomic operation primitive primarily used for **Compare and swap**. Its prototype is as follows:
```objectivec

bool    OSAtomicCompareAndSwap32Barrier( int32_t __oldValue, int32_t __newValue, volatile int32_t *__theValue );

```
The `volatile` keyword only ensures that whenever a `volatile` variable is read, the variable is loaded from memory rather than using the value in a register; it does not guarantee that the code accesses the variable correctly.

If this function were implemented in pseudocode:
```objectivec

f (*__theValue == __oldValue) {  
    *__theValue = __newValue;  
    return 1;  
} else {  
    return 0;  
} 

```
If \_hasConnected is 0, it means there is no connection. `OSAtomicCompareAndSwap32Barrier` returns 1, so `shouldConnect` should connect. If \_hasConnected is 1, it means it has already connected before. `OSAtomicCompareAndSwap32Barrier` returns 0, so `shouldConnect` will not connect again.


The so-called connection process is that `RACMulticastConnection` internally uses `RACSubject` to subscribe to `self.sourceSignal`. `sourceSignal` is a `RACSignal`; it saves the subscriber `RACSubject` into `RACPassthroughSubscriber`. When `sendNext` is called, it calls `RACSubject sendNext`, at which point all signals from `sourceSignal` are sent to each subscriber.
```objectivec

- (RACSignal *)autoconnect {
	__block volatile int32_t subscriberCount = 0;

	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			OSAtomicIncrement32Barrier(&subscriberCount);

			RACDisposable *subscriptionDisposable = [self.signal subscribe:subscriber];
			RACDisposable *connectionDisposable = [self connect];

			return [RACDisposable disposableWithBlock:^{
				[subscriptionDisposable dispose];

				if (OSAtomicDecrement32Barrier(&subscriberCount) == 0) {
					[connectionDisposable dispose];
				}
			}];
		}]
		setNameWithFormat:@"[%@] -autoconnect", self.signal.name];
}


```
OSAtomicIncrement32Barrier and OSAtomicDecrement32Barrier are also atomic operation operators, performing +1 and -1 operations respectively. In autoconnect, to ensure thread safety, a volatile variable similar to a semaphore, subscriberCount, is used to ensure that the first subscriber can establish the connection. Subscribers of the newly returned signal subscribe to RACSubject, and RACSubject also subscribes to the internal sourceSignal.

There are five ways to convert a cold signal into a hot signal, and all five methods use RACMulticastConnection. Next, we will analyze their concrete implementations one by one.


#### 1. multicast:
```objectivec

- (RACMulticastConnection *)multicast:(RACSubject *)subject {
	[subject setNameWithFormat:@"[%@] -multicast: %@", self.name, subject.name];
	RACMulticastConnection *connection = [[RACMulticastConnection alloc] initWithSourceSignal:self subject:subject];
	return connection;
}

```
`multicast`: initializes a `RACMulticastConnection` object. `SourceSignal` is `self`, and the internal `RACSubject` is the input parameter `subject`.
```objectivec

    RACMulticastConnection *connection = [signal multicast:[RACSubject subject]];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```
Calling multicast: to convert a cold signal into a hot signal has one inconvenience: you need to manually call connect yourself. Note that after the conversion, the hot signal is in the signal property of RACMulticastConnection, so what you need to subscribe to is connection.signal.


#### 2. publish
```objectivec

- (RACMulticastConnection *)publish {
	RACSubject *subject = [[RACSubject subject] setNameWithFormat:@"[%@] -publish", self.name];
	RACMulticastConnection *connection = [self multicast:subject];
	return connection;
}

```
`publish` simply calls `multicast:`. Internally, `publish` creates a new `RACSubject` and passes it as an argument to `RACMulticastConnection`.
```objectivec

    RACMulticastConnection *connection = [signal publish];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```
Likewise, the publish method also requires calling the connect method manually.


#### 3. replay
```objectivec

- (RACSignal *)replay {
	RACReplaySubject *subject = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -replay", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}


```
The `replay` method passes `RACReplaySubject` into `RACMulticastConnection` as the `RACSubject`, initializes the `RACMulticastConnection`, then automatically calls the `connect` method. The signal it returns is the converted hot signal, i.e. the `RACSubject` signal inside `RACMulticastConnection`.


This must be `RACReplaySubject`, because `connect` is called first inside the `replay` method. If `RACSubject` were used, then after `connect`, the original signal would be sent through `RACSubject` to each subscriber. By using `RACReplaySubject` to store the signal, even if `connect` is called first inside the `replay` method and subscribers subscribe later, they can still receive the previously sent signal values.


#### 4. replayLast
```objectivec

- (RACSignal *)replayLast {
	RACReplaySubject *subject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"[%@] -replayLast", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}

```
replayLast is implemented basically the same way as replay. The only difference is that the Capacity of the passed-in RACReplaySubject is 1, which means it can only retain the latest value. Therefore, when using replayLast, after subscribing you can only get the latest value from the original signal.


#### 5. replayLazily
```objectivec

- (RACSignal *)replayLazily {
	RACMulticastConnection *connection = [self multicast:[RACReplaySubject subject]];
	return [[RACSignal
		defer:^{
			[connection connect];
			return connection.signal;
		}]
		setNameWithFormat:@"[%@] -replayLazily", self.name];
}

```
The implementation of `replayLazily` is also very similar to `replayLast` and `replay`. The only difference is that `connect` is placed inside the `defer` operation.

The implementation of the `defer` operation is as follows:
```objectivec


+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

```
The literal meaning of the word defer is “delay,” which is consistent with what this function does. The input `block( )` closure is executed only when the new signal returned by `defer` is subscribed to. The subscriber will subscribe to the `RACSignal` returned by this `block( )` closure.

The creation of the `RACSignal` by the `block( )` closure is deferred—this is `defer`. If the `block( )` closure contains time-related operations or side effects, and you want to delay their execution, you can use `defer`.

There is also a similar operation: `then`.
```objectivec

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameWithFormat:@"[%@] -then:", self.name];
}

```
The `then` operation is also deferred; it simply defers the `block( )` closure until after the original signal sends `complete`. The new signal obtained through the `then` signal transformation will not send any values during the period when the original signal is sending values, because `ignoreValues` is applied. Once the original signal `sendComplete`s, it is immediately followed by the signal produced by the `block( )` closure.

Back to the `replayLazily` operation: its purpose is likewise to convert a cold signal into a hot signal, except that `sourceSignal` is subscribed to only when the newly returned signal is subscribed to for the first time. The reason is that `defer` delays the execution of the `block( )` closure.


### Finally

In ReactiveCocoa v2.5, even if a cold signal is converted into a hot signal, the hot signal may become a cold signal again in subsequent transformations. Therefore, in v2.5 there are many operations that convert cold signals into hot signals. In ReactiveCocoa v3.0 and later, a mechanism was added so that hot signals remain hot after transformation. This makes things much more convenient and avoids adding a lot of unnecessary code for converting cold signals into hot signals.

As for `RACSignal` transformation operations, higher-order signal operations remain to be covered. I’ll continue the analysis in the next article. As always, feedback is welcome.