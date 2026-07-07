# Analysis of the Underlying Implementation of Cold and Hot RACSignal Signals in ReactiveCocoa

![](https://img.halfrost.com/Blog/ArticleTitleImage/34_0_.jpg)


### Preface

Among articles about cold and hot signals in ReactiveCocoa v2.5, the most well-known are the three articles on cold and hot signals written by Zang Chengwei from Meituan:

[An In-Depth Look at Cold and Hot Signals in ReactiveCocoa (Part 1)](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html)  
[An In-Depth Look at Cold and Hot Signals in ReactiveCocoa (Part 2): Why Distinguish Between Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)  
[An In-Depth Look at Cold and Hot Signals in ReactiveCocoa (Part 3): How to Handle Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-3.html)  

Since I have recently been writing articles analyzing the underlying implementation of RACSignal, I naturally cannot avoid analyzing operations related to cold and hot signals. This article will analyze the underlying implementation of how a cold signal is converted into a hot signal.


### Table of Contents

- 1. Concepts of cold and hot signals
- 2. RACSignal hot signals
- 3. RACSignal cold signals
- 4. How cold signals are converted into hot signals


### 1. Concepts of Cold and Hot Signals

![](https://img.halfrost.com/Blog/ArticleImage/34_1.png)


The concepts of cold and hot signals originate from Hot Observable and Cold Observable in the .NET framework [Reactive Extensions(RX)](https://msdn.microsoft.com/en-us/library/hh242985.aspx).


> A Hot Observable is active. Even if you have not subscribed to events, it keeps pushing values continuously, just like mouse movement. A Cold Observable is passive. It publishes messages only when you subscribe to it.

> A Hot Observable can have multiple subscribers; it is one-to-many, and the sequence can share information with its subscribers. A Cold Observable can only be one-to-one. When there are different subscribers, the messages are resent in full from the beginning.


This article, [An In-Depth Look at Cold and Hot Signals in ReactiveCocoa (Part 1)](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html), analyzes the characteristics of cold and hot signals in detail:

**A hot signal is active. Even if you have not subscribed to events, it still keeps pushing values continuously. A cold signal is passive. It sends messages only when you subscribe to it.**

**A hot signal can have multiple subscribers; it is one-to-many, and the signal can share information with its subscribers. A cold signal can only be one-to-one. When there are different subscribers, the messages will be resent in full from the beginning.**

### 2. RACSignal Hot Signals


![](https://img.halfrost.com/Blog/ArticleImage/34_2.png)


In the RACSignal family, the following signals match the characteristics of hot signals.

#### 1.RACSubject
```objectivec


@interface RACSubject : RACSignal <RACSubscriber>

@property (nonatomic, strong, readonly) NSMutableArray *subscribers;
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;
+ (instancetype)subject;

@end

```
First, let’s look at the definition of `RACSubject`.

`RACSubject` inherits from `RACSignal`, and it also conforms to the `RACSubscriber` protocol. This means it can both subscribe to signals and send signals.

Inside `RACSubject`, there is an `NSMutableArray` that contains all subscribers to the signal. In addition, there is a `RACCompoundDisposable` that contains the `RACDisposable` instances for all subscribers to the signal.

The reason `RACSubject` can be considered a hot signal is that it must satisfy the definition of a hot signal described above. Let’s look at its implementation to see how it does so.
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
RACSubject stores all of its subscribers in an `NSMutableArray`. Since it stores every subscriber, `sendNext`, `sendError`, and `sendCompleted` need to change accordingly.
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
`enumerateSubscribersUsingBlock:` retrieves all subscribers of a `RACSubject` and invokes the input `block()` method on them one by one.

For the subscription and sending flow of `RACSubject`, you can refer to the [first article](https://halfrost.com/reactivecocoa_racsignal/). The overall process is largely the same; the main difference is that it sends signals to its own subscribers in sequence.

`RACSubject` satisfies the characteristics of a hot signal. Even if it has no subscribers, because it conforms to the `RACSubscriber` protocol through inheritance, it can send signals by itself. A cold signal can send signals only after it has been subscribed to.

`RACSubject` can have many subscribers, and it stores all of them in its own array. When `RACSubject` sends signals later, the subscribers are like people watching TV together: programs that have already aired can no longer be watched, and signals that have already been sent can no longer be received. By contrast, when a `RACSignal` sends signals, subscribers can only receive them from the beginning, like watching video on demand—every time you watch, you start from the beginning.


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
For a detailed analysis of groupBy, see this [article](https://halfrost.com/reactivecocoa_racsignal_operations2/)


#### 3. RACBehaviorSubject
```objectivec

@interface RACBehaviorSubject : RACSubject
@property (nonatomic, strong) id currentValue;
+ (instancetype)behaviorSubjectWithDefaultValue:(id)value;
@end

```
This signal stores an object, `currentValue`, which holds the latest value of the signal.

Of course, you can also call the class method `behaviorSubjectWithDefaultValue`.
```objectivec

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value {
    RACBehaviorSubject *subject = [self subject];
    subject.currentValue = value;
    return subject;
}


```
Store the default value in this method. If `RACBehaviorSubject` has not received any value, this signal will send the default value.

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
`sendNext` always sends the stored `currentValue`. Calling `sendNext` invokes `sendNext` in `RACSubject`, which in turn sends the signal value to each subscriber in the subscribers array in sequence.

When `RACBehaviorSubject` sends `sendNext` to a subscriber:
```objectivec

- (void)sendNext:(id)value {
    @synchronized (self) {
        self.currentValue = value;
        [super sendNext:value];
    }
}

```
RACBehaviorSubject updates the sent value into `currentValue`. The next time it sends a value, it will send the most recently updated value.


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
RACReplaySubject stores historical values up to a capacity of RACReplaySubjectUnlimitedCapacity.
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
During `RACReplaySubject` initialization, an array of size `capacity` is initialized.
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
In `sendNext`, `valuesReceived` stores each value received. Calling `super`’s `sendNext` sends the values to each subscriber in sequence.

It also checks how many values are stored in the array. If the number of stored values exceeds `capacity`, it removes the first few values starting from index 0, ensuring that the array contains only `capacity` values.


The difference between `RACReplaySubject` and `RACSubject` is that `RACReplaySubject` also stores historical signal values and sends them to subscribers. In this respect, `RACReplaySubject` is more like a combination of `RACSingnal` and `RACSubject`. `RACSignal` is a cold signal: once subscribed to, it sends all of its values to the subscriber. `RACReplaySubject` is the same as `RACSignal` in this regard. However, `RACReplaySubject` also has the characteristics of `RACSubject`: it sends all values to multiple subscribers. After `RACReplaySubject` finishes sending the previously stored historical values, its subsequent signal-sending behavior is exactly the same as `RACSubject`.


### III. `RACSignal` Cold Signals


![](https://img.halfrost.com/Blog/ArticleImage/34_3.png)


In ReactiveCocoa v2.5, besides `RACsignal` signals, there are also some special cold signals.

#### 1. `RACEmptySignal`
```objectivec

@interface RACEmptySignal : RACSignal
+ (RACSignal *)empty;
@end

```
This signal has only one `empty` method.
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
In debug mode, returns a signal named `empty`. In release mode, returns a singleton `empty` signal.
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```
Once a RACEmptySignal is subscribed to, it sends sendCompleted.


#### 2. RACReturnSignal
```objectivec


@interface RACReturnSignal : RACSignal
@property (nonatomic, strong, readonly) id value;
+ (RACSignal *)return:(id)value;
@end

```
The definition of the RACReturnSignal signal is also very simple: it directly returns an RACSignal based on the value.
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
In debug mode, it directly creates a new `RACReturnSignal` whose stored value is the input parameter `value`. In release mode, it creates the corresponding singleton `RACReturnSignal` depending on whether `value` is `nil`.
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);

 return [RACScheduler.subscriptionScheduler schedule:^{
    [subscriber sendNext:self.value];
    [subscriber sendCompleted];
 }];
}

```
RACReturnSignal sends only a single value when it is subscribed to, and then calls sendCompleted after sending it.


#### 3. RACDynamicSignal


This signal is what is actually created by RACSignal createSignal:. For the detailed process of RACDynamicSignal, see [the first article](https://halfrost.com/reactivecocoa_racsignal/).


#### 4. RACErrorSignal
```objectivec

@interface RACErrorSignal : RACSignal
@property (nonatomic, strong, readonly) NSError *error;
+ (RACSignal *)error:(NSError *)error;
@end

```
An RACErrorSignal stores an NSError.
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
During initialization, `RACErrorSignal` saves the `Error` passed in from the outside. When it is subscribed to, it sends that `Error` out.


#### 5. RACChannelTerminal
```objectivec

@interface RACChannelTerminal : RACSignal <RACSubscriber>

- (id)init __attribute__((unavailable("Instantiate a RACChannel instead")));

@property (nonatomic, strong, readonly) RACSignal *values;
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;
- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

```
RACChannelTerminal is used for two-way binding in day-to-day RAC development. Like RACSubject, it both inherits from RACSignal and conforms to the RACSubscriber protocol. Although it has RACSubject’s characteristics of sending and receiving signals, it is still a cold signal, because it cannot support one-to-many delivery; any signal it sends can still only be one-to-one.

RACChannelTerminal cannot be initialized manually; it must be initialized via RACChannel.
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
During the initialization of RACChannel, RACChannelTerminal’s initWithValues: method is called, and the arguments passed in here are all of type RACReplaySubject. Therefore, when subscribing to RACChannelTerminal:
```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    return [self.values subscribe:subscriber];
}

```
`self.values` is essentially an `RACReplaySubject`, so this is equivalent to subscribing to an `RACReplaySubject`. The subscription process is the same as the `RACReplaySubject` subscription process described above.
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
`self.otherTerminal` is also of type `RACReplaySubject`. Both ends of the `RACChannelTerminal` pipe are signals of type `RACReplaySubject`. When `RACChannelTerminal` starts `sendNext`, `sendError`, or `sendCompleted`, it calls the corresponding operations on the `RACReplaySubject` of the other end of the pipe.

A common use case for `RACChannelTerminal` is two-way binding between the View and the ViewModel.

For example, on a login screen, two-way binding between the password `TextField` and the ViewModel’s `Password`.
```objectivec


    RACChannelTerminal *passwordTerminal = [_passwordTextField rac_newTextChannel];
    RACChannelTerminal *viewModelPasswordTerminal = RACChannelTo(_viewModel, password);
    [viewModelPasswordTerminal subscribe:passwordTerminal];
    [passwordTerminal subscribe:viewModelPasswordTerminal];

```
Both signals in a two-way binding will receive new signals as a result of changes in the other.


At this point, all the categories of `RACSignal` have been clarified, including the classification into cold signals and hot signals.

![](https://img.halfrost.com/Blog/ArticleImage/34_4.png)


### 4. How Cold Signals Are Converted into Hot Signals

![](https://img.halfrost.com/Blog/ArticleImage/34_5.png)


Why do we sometimes need to convert a cold signal into a hot signal? For details, see the example in this article: [A Closer Look at ReactiveCocoa Cold Signals and Hot Signals (Part 2): Why Distinguish Between Cold and Hot Signals](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)


Based on the process by which `RACSignal` is subscribed to and sends signals, we know that every time a cold `RACSignal` is subscribed to, the `didSubscribe` closure is executed once. This is where problems may arise. If the `RACSignal` is used for a network request, the request will be repeated inside the `didSubscribe` closure. The article above mentions that if the signal is subscribed to 6 times, the network request will also be made 6 times. This is not what we want. The network request only needs to be made once.

To ensure that the signal executes the `didSubscribe` closure only once, the key point is that a cold `RACSignal` can only be subscribed to once. Since a cold signal can only be one-to-one, if we want one-to-many, we have to hand that off to a hot signal. This is when we need to convert the cold signal into a hot signal.

In ReactiveCocoa v2.5, converting a cold signal into a hot signal requires using the `RACMulticastConnection` class.
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
Take a look at the definition of the `RACMulticastConnection` class. The most important part is that it stores two signals: one is `RACSubject`, and the other is `sourceSignal` (of type `RACSignal`). What is exposed externally in the `.h` file is `RACSignal`, while what is actually used in the `.m` file is `RACSubject`. From its definition, you can infer what it is going to do next: use `sourceSignal` to send signals, internally use `RACSubject` to subscribe to `sourceSignal`, and then have `RACSubject` forward the values from `sourceSignal` to its subscribers one by one.


![](https://img.halfrost.com/Blog/ArticleImage/34_6.png)


Using a somewhat imperfect analogy to describe `RACMulticastConnection`, it is like the “Earth” at the center of the diagram above. The “Earth” is the `RACSubject` that has subscribed to `sourceSignal`, and `RACSubject` sends values to each of its “connections” (subscribers). `sourceSignal` has only one subscriber internally—the `RACSubject`—so this achieves what we want: execute the `didSubscribe` closure only once, while still being able to send values to multiple subscribers.


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
The initializer stores the externally passed-in `RACSignal` as `sourceSignal`, and stores the externally passed-in `RACSubject` as its own `signal` property.

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
An uncommon function appears here: OSAtomicCompareAndSwap32Barrier. It is an operator for atomic operations, mainly used for **Compare and swap**. Its prototype is as follows:
```objectivec

bool    OSAtomicCompareAndSwap32Barrier( int32_t __oldValue, int32_t __newValue, volatile int32_t *__theValue );

```
The keyword `volatile` only ensures that each time a `volatile` variable is read, it is loaded from memory instead of using the value in a register; however, it does not guarantee that the code accesses the variable correctly.

If we implement this function in pseudocode:
```objectivec

f (*__theValue == __oldValue) {  
    *__theValue = __newValue;  
    return 1;  
} else {  
    return 0;  
} 

```
If \_hasConnected is 0, it means there is no connection. `OSAtomicCompareAndSwap32Barrier` returns 1, so `shouldConnect` should connect. If \_hasConnected is 1, it means it has already connected before. `OSAtomicCompareAndSwap32Barrier` returns 0, so `shouldConnect` will not connect again.

The so-called connection process is that `RACMulticastConnection` internally uses `RACSubject` to subscribe to `self.sourceSignal`. `sourceSignal` is an `RACSignal`; it saves the subscriber `RACSubject` in `RACPassthroughSubscriber`. When `sendNext` is called, it will call `RACSubject sendNext`, at which point all signals from `sourceSignal` will be sent to each subscriber.
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
OSAtomicIncrement32Barrier and OSAtomicDecrement32Barrier are also atomic operation operators, performing +1 and -1 operations respectively. In autoconnect, to ensure thread safety, a `volatile` variable similar to a semaphore, `subscriberCount`, is used to ensure that the first subscriber can connect. Subscribers of the newly returned signal subscribe to RACSubject, and RACSubject also subscribes to the internal sourceSignal.

There are five ways to convert a cold signal into a hot signal, and all five use RACMulticastConnection. Next, we will analyze their concrete implementations one by one.


#### 1. multicast:
```objectivec

- (RACMulticastConnection *)multicast:(RACSubject *)subject {
	[subject setNameWithFormat:@"[%@] -multicast: %@", self.name, subject.name];
	RACMulticastConnection *connection = [[RACMulticastConnection alloc] initWithSourceSignal:self subject:subject];
	return connection;
}

```
multicast: initializes an RACMulticastConnection object, with SourceSignal set to self and the internal RACSubject set to the input parameter subject.
```objectivec

    RACMulticastConnection *connection = [signal multicast:[RACSubject subject]];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```
Calling multicast: to convert a cold signal into a hot signal has one inconvenience: you need to manually call connect yourself. Note that after conversion, the hot signal is in the signal property of RACMulticastConnection, so the one you need to subscribe to is connection.signal.


#### 2. publish
```objectivec

- (RACMulticastConnection *)publish {
	RACSubject *subject = [[RACSubject subject] setNameWithFormat:@"[%@] -publish", self.name];
	RACMulticastConnection *connection = [self multicast:subject];
	return connection;
}

```
The `publish` method simply calls the `multicast:` method. Internally, `publish` creates a new `RACSubject` and passes it as an argument to `RACMulticastConnection`.
```objectivec

    RACMulticastConnection *connection = [signal publish];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```
Similarly, the publish method also requires manually calling the connect method.


#### 3. replay
```objectivec

- (RACSignal *)replay {
	RACReplaySubject *subject = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -replay", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}


```
The `replay` method passes `RACReplaySubject` into `RACMulticastConnection` as its `RACSubject`, initializes the `RACMulticastConnection`, then automatically calls the `connect` method. The signal returned is the converted hot signal, that is, the `RACSubject` signal inside `RACMulticastConnection`.

Here it must be `RACReplaySubject`, because `connect` is called first inside the `replay` method. If `RACSubject` were used, after `connect`, the original signal would be sent through `RACSubject` to each subscriber. Using `RACReplaySubject` stores the signal values, so even if `connect` is called first inside the `replay` method, subscribers that subscribe later can still receive the previous signal values.

#### 4. replayLast
```objectivec

- (RACSignal *)replayLast {
	RACReplaySubject *subject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"[%@] -replayLast", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}

```
The implementation of replayLast is basically the same as that of replay; the only difference is that the Capacity of the RACReplaySubject passed in is 1, which means it can only retain the latest value. Therefore, when using replayLast, after subscribing you can only receive the latest value from the original signal.


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
The implementation of replayLazily is also very similar to those of replayLast and replay. The only difference is that connect is placed inside the defer operation.

The defer operation is implemented as follows:
```objectivec


+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

```
The literal meaning of the word defer is “delay.” That also matches the effect implemented by this function. Only when the new signal returned by defer is subscribed to will the input `block( )` closure be executed. The subscriber will subscribe to the `RACSignal` returned by this `block( )` closure.

The `RACSignal` is created lazily by the `block( )` closure — this is defer. If the `block( )` closure contains time-related operations or side effects, and you want to delay their execution, you can use defer.

There is another similar operator: then.
```objectivec

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameWithFormat:@"[%@] -then:", self.name];
}

```
The then operation is also a form of deferral; it just delays the block( ) closure until after the original signal sends complete. The new signal obtained through the then signal transformation will not send any values during the time when the original signal is sending values, because ignoreValues has been applied. Once the original signal has sent sendComplete, it is immediately followed by the signal produced by the block( ) closure.

Returning to the replayLazily operation, its purpose is likewise to convert a cold signal into a hot signal; the difference is that sourceSignal is not subscribed to until the returned new signal is subscribed to for the first time. The reason is that defer delays execution of the block( ) closure.


### Finally

In ReactiveCocoa v2.5, even after a cold signal is converted into a hot signal, that hot signal can become a cold signal again in subsequent transformations. Therefore, in v2.5 there are many operations that convert cold signals into hot signals. In versions after ReactiveCocoa v3.0, a mechanism was added so that a hot signal remains hot after transformations, which makes things much more convenient and avoids adding a lot of unnecessary code to convert cold signals into hot signals.

For RACSignal transformation operations, only higher-order signal operations remain. I’ll continue the analysis in the next article. Finally, I welcome your feedback.