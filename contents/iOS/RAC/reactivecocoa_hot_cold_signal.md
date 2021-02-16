# ReactiveCocoa 中 RACSignal 冷信号和热信号底层实现分析

![](https://img.halfrost.com/Blog/ArticleTitleImage/34_0_.jpg)



### 前言

关于ReactiveCocoa v2.5中冷信号和热信号的文章中，最著名的就是美团的臧成威老师写的3篇冷热信号的文章：

[细说ReactiveCocoa的冷信号与热信号（一）](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html)  
[细说ReactiveCocoa的冷信号与热信号（二）：为什么要区分冷热信号](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)  
[细说ReactiveCocoa的冷信号与热信号（三）：怎么处理冷信号与热信号](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-3.html)  

由于最近在写关于RACSignal底层实现分析的文章，当然也逃不了关于冷热信号操作的分析。这篇文章打算分析分析如何从冷信号转成热信号的底层实现。




### 目录

- 1.关于冷信号和热信号的概念
- 2.RACSignal热信号
- 3.RACSignal冷信号
- 4.冷信号是如何转换成热信号的



### 一. 关于冷信号和热信号的概念

![](https://img.halfrost.com/Blog/ArticleImage/34_1.png)




冷热信号的概念是源自于源于.NET框架[Reactive Extensions(RX)](https://msdn.microsoft.com/en-us/library/hh242985.aspx)中的Hot Observable和Cold Observable，


>Hot Observable是主动的，尽管你并没有订阅事件，但是它会时刻推送，就像鼠标移动；而Cold Observable是被动的，只有当你订阅的时候，它才会发布消息。

>Hot Observable可以有多个订阅者，是一对多，集合可以与订阅者共享信息；而Cold Observable只能一对一，当有不同的订阅者，消息是重新完整发送。


在这篇文章[细说ReactiveCocoa的冷信号与热信号（一）](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-1.html)详细分析了冷热信号的特点：

**热信号是主动的，即使你没有订阅事件，它仍然会时刻推送。而冷信号是被动的，只有当你订阅的时候，它才会发送消息。**

**热信号可以有多个订阅者，是一对多，信号可以与订阅者共享信息。而冷信号只能一对一，当有不同的订阅者，消息会从新完整发送。**

### 二. RACSignal热信号


![](https://img.halfrost.com/Blog/ArticleImage/34_2.png)




RACSignal家族中符合热信号的特点的信号有以下几个。

#### 1.RACSubject

```objectivec


@interface RACSubject : RACSignal <RACSubscriber>

@property (nonatomic, strong, readonly) NSMutableArray *subscribers;
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;
+ (instancetype)subject;

@end

```

首先来看看RACSubject的定义。

RACSubject是继承自RACSignal，并且它还遵守RACSubscriber协议。这就意味着它既能订阅信号，也能发送信号。

在RACSubject里面有一个NSMutableArray数组，里面装着该信号的所有订阅者。其次还有一个RACCompoundDisposable信号，里面装着该信号所有订阅者的RACDisposable。


RACSubject之所以能称之为热信号，那么它肯定是符合上述热信号的定义的。让我们从它的实现来看看它是如何符合的。

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

上面是RACSubject的实现，它和RACSignal最大的不同在这两行

```objectivec

NSMutableArray *subscribers = self.subscribers;
@synchronized (subscribers) {
    [subscribers addObject:subscriber];
}

```

RACSubject 把它的所有订阅者全部都保存到了NSMutableArray的数组里。既然保存了所有的订阅者，那么sendNext，sendError，sendCompleted就需要发生改变。


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

从源码可以看到，RACSubject中的sendNext，sendError，sendCompleted都会执行enumerateSubscribersUsingBlock:方法。

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

enumerateSubscribersUsingBlock:方法会取出所有RACSubject的订阅者，依次调用入参的block( )方法。

关于RACSubject的订阅和发送的流程可以参考[第一篇文章](https://halfrost.com/reactivecocoa_racsignal/)，大体一致，其他的不同就是会依次对自己的订阅者发送信号。

RACSubject就满足了热信号的特点，它即使没有订阅者，因为自己继承了RACSubscriber协议，所以自己本身就可以发送信号。冷信号只能被订阅了才能发送信号。

RACSubject可以有很多订阅者，它也会把这些订阅者都保存到自己的数组里。RACSubject之后再发送信号，订阅者就如同一起看电视，播放过的节目就看不到了，发送过的信号也接收不到了。接收信号。而RACSignal发送信号，订阅者接收信号都只能从头开始接受，如同看点播节目，每次看都从头开始看。



#### 2. RACGroupedSignal


```objectivec

@interface RACGroupedSignal : RACSubject

@property (nonatomic, readonly, copy) id<NSCopying> key;
+ (instancetype)signalWithKey:(id<NSCopying>)key;
@end

```

先看看RACGroupedSignal的定义。


RACGroupedSignal是在RACsignal这个方法里面被用到的。

```objectivec

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock

```

在这个方法里面，sendNext里面最后里面是由RACGroupedSignal发送信号。

```objectivec

[groupSubject sendNext:transformBlock != NULL ? transformBlock(x) : x];

```

关于groupBy的详细分析请看这篇[文章](https://halfrost.com/reactivecocoa_racsignal_operations2/)


#### 3. RACBehaviorSubject



```objectivec

@interface RACBehaviorSubject : RACSubject
@property (nonatomic, strong) id currentValue;
+ (instancetype)behaviorSubjectWithDefaultValue:(id)value;
@end

```

这个信号里面存储了一个对象currentValue，这里存储着这个信号的最新的值。

当然也可以调用类方法behaviorSubjectWithDefaultValue

```objectivec

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value {
    RACBehaviorSubject *subject = [self subject];
    subject.currentValue = value;
    return subject;
}


```


在这个方法里面存储默认的值，如果RACBehaviorSubject没有接受到任何值，那么这个信号就会发送这个默认的值。


当RACBehaviorSubject被订阅：

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

sendNext里面会始终发送存储的currentValue值。调用sendNext会调用RACSubject里面的sendNext，也会依次发送信号值给订阅数组里面每个订阅者。

当RACBehaviorSubject向订阅者sendNext的时候：

```objectivec

- (void)sendNext:(id)value {
    @synchronized (self) {
        self.currentValue = value;
        [super sendNext:value];
    }
}

```

RACBehaviorSubject会把发送的值更新到currentValue里面。下次发送值就会发送最后更新的值。



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

RACReplaySubject中会存储RACReplaySubjectUnlimitedCapacity大小的历史值。


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

在RACReplaySubject初始化中会初始化一个capacity大小的数组。


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


当RACReplaySubject被订阅的时候，会把valuesReceived数组里面的值都发送出去。



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


在sendNext中，valuesReceived会保存每次接收到的值。调用super的sendNext，会依次把值都发送到每个订阅者中。

这里还会判断数组里面存储了多少个值。如果存储的值的个数大于了capacity，那么要移除掉数组里面从0开始的前几个值，保证数组里面只装capacity个数的值。


RACReplaySubject 和 RACSubject 的区别在于，RACReplaySubject还会把历史的信号值都存储起来发送给订阅者。这一点，RACReplaySubject更像是RACSingnal 和 RACSubject 的合体版。RACSignal是冷信号，一旦被订阅就会向订阅者发送所有的值，这一点RACReplaySubject和RACSignal是一样的。但是RACReplaySubject又有着RACSubject的特性，会把所有的值发送给多个订阅者。当RACReplaySubject发送完之前存储的历史值之后，之后再发送信号的行为就和RACSubject完全一致了。





### 三. RACSignal冷信号


![](https://img.halfrost.com/Blog/ArticleImage/34_3.png)





在ReactiveCocoa v2.5中除了RACsignal信号以外，还有一些特殊的冷信号。

#### 1.RACEmptySignal

```objectivec

@interface RACEmptySignal : RACSignal
+ (RACSignal *)empty;
@end

```

这个信号只有一个empty方法。

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

在debug模式下，返回一个名字叫empty的信号。在release模式下，返回一个单例的empty信号。


```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```

RACEmptySignal信号一旦被订阅就会发送sendCompleted。



#### 2. RACReturnSignal


```objectivec


@interface RACReturnSignal : RACSignal
@property (nonatomic, strong, readonly) id value;
+ (RACSignal *)return:(id)value;
@end

```

RACReturnSignal信号的定义也很简单，直接根据value的值返回一个RACSignal。


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

在debug模式下直接新建一个RACReturnSignal信号里面的值存储的是入参value。在release模式下，会依照value的值是否是空，来新建对应的单例RACReturnSignal。

```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);

 return [RACScheduler.subscriptionScheduler schedule:^{
    [subscriber sendNext:self.value];
    [subscriber sendCompleted];
 }];
}

```

RACReturnSignal在被订阅的时候，就只会发送一个value值的信号，发送完毕之后就sendCompleted。


#### 3. RACDynamicSignal


这个信号是创建RACSignal createSignal:的真身。关于RACDynamicSignal详细过程请看[第一篇文章](https://halfrost.com/reactivecocoa_racsignal/)。


#### 4. RACErrorSignal

```objectivec

@interface RACErrorSignal : RACSignal
@property (nonatomic, strong, readonly) NSError *error;
+ (RACSignal *)error:(NSError *)error;
@end

```

RACErrorSignal信号里面就存储了一个NSError。

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

RACErrorSignal初始化的时候把外界传进来的Error保存起来。当被订阅的时候就发送这个Error出去。


#### 5. RACChannelTerminal


```objectivec

@interface RACChannelTerminal : RACSignal <RACSubscriber>

- (id)init __attribute__((unavailable("Instantiate a RACChannel instead")));

@property (nonatomic, strong, readonly) RACSignal *values;
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;
- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

```

RACChannelTerminal在RAC日常开发中，用来双向绑定的。它和RACSubject一样，既继承自RACSignal，同样又遵守RACSubscriber协议。虽然具有RACSubject的发送和接收信号的特性，但是它依旧是冷信号，因为它无法一对多，它发送信号还是只能一对一。

RACChannelTerminal无法手动初始化，需要靠RACChannel去初始化。

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


在RACChannel的初始化中会调用RACChannelTerminal的initWithValues:方法，这里的入参都是RACReplaySubject类型的。所以订阅RACChannelTerminal过程的时候：

```objectivec

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    return [self.values subscribe:subscriber];
}

```

self.values其实就是一个RACReplaySubject，就相当于订阅RACReplaySubject。订阅过程同上面RACReplaySubject的订阅过程。

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

self.otherTerminal也是RACReplaySubject类型的，RACChannelTerminal管道两边都是RACReplaySubject类型的信号。当RACChannelTerminal开始sendNext，sendError，sendCompleted是调用的管道另外一个的RACReplaySubject进行这些对应的操作的。


平时使用RACChannelTerminal的地方在View和ViewModel的双向绑定上面。


例如在登录界面，输入密码文本框TextField和ViewModel的Password双向绑定

```objectivec


    RACChannelTerminal *passwordTerminal = [_passwordTextField rac_newTextChannel];
    RACChannelTerminal *viewModelPasswordTerminal = RACChannelTo(_viewModel, password);
    [viewModelPasswordTerminal subscribe:passwordTerminal];
    [passwordTerminal subscribe:viewModelPasswordTerminal];

```

双向绑定的两个信号都会因为对方的改变而收到新的信号。



至此所有的RACSignal的分类就都理顺了，按照冷信号和热信号的分类也分好了。

![](https://img.halfrost.com/Blog/ArticleImage/34_4.png)



### 四. 冷信号是如何转换成热信号的

![](https://img.halfrost.com/Blog/ArticleImage/34_5.png)




为何有时候需要把冷信号转换成热信号呢？详情可以看这篇文章里面举的例子：[细说ReactiveCocoa的冷信号与热信号（二）：为什么要区分冷热信号](http://tech.meituan.com/talk-about-reactivecocoas-cold-signal-and-hot-signal-part-2.html)


根据RACSignal订阅和发送信号的流程，我们可以知道，每订阅一次冷信号RACSignal，就会执行一次didSubscribe闭包。这个时候就是可能出现问题的地方。如果RACSignal是被用于网络请求，那么在didSubscribe闭包里面会被重复的请求。上面文中提到了信号被订阅了6次，网络请求也会请求6次。这并不是我们想要的。网络请求只需要请求1次。

如何做到信号只执行一次didSubscribe闭包，最重要的一点是RACSignal冷信号只能被订阅一次。由于冷信号只能一对一，那么想一对多就只能交给热信号去处理了。这时候就需要把冷信号转换成热信号。

在ReactiveCocoa v2.5中，冷信号转换成热信号需要用到RACMulticastConnection 这个类。


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

看看RACMulticastConnection类的定义。最主要的是保存了两个信号，一个是RACSubject，一个是sourceSignal(RACSignal类型)。在.h中暴露给外面的是RACSignal，在.m中实际使用的是RACSubject。看它的定义就能猜到接下去它会做什么：用sourceSignal去发送信号，内部再用RACSubject去订阅sourceSignal，然后RACSubject会把sourceSignal的信号值依次发给它的订阅者们。


![](https://img.halfrost.com/Blog/ArticleImage/34_6.png)


用一个不恰当的比喻来形容RACMulticastConnection，它就像上图中心的那个“地球”，“地球”就是订阅了sourceSignal的RACSubject，RACSubject把值发送给各个“连接”者(订阅者)。sourceSignal只有内部的RACSubject一个订阅者，所以就完成了我们只想执行didSubscribe闭包一次，但是能把值发送给各个订阅者的愿望。


在看看RACMulticastConnection的初始化

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


初始化方法就是把外界传进来的RACSignal保存成sourceSignal，把外界传进来的RACSubject保存成自己的signal属性。


RACMulticastConnection有两个连接方法。

```objectivec


- (RACDisposable *)connect {
	BOOL shouldConnect = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasConnected);

	if (shouldConnect) {
		self.serialDisposable.disposable = [self.sourceSignal subscribe:_signal];
	}
	return self.serialDisposable;
}

```

这里出现了一个不多见的函数OSAtomicCompareAndSwap32Barrier，它是原子运算的操作符，主要用于**Compare and swap**，原型如下：

```objectivec

bool    OSAtomicCompareAndSwap32Barrier( int32_t __oldValue, int32_t __newValue, volatile int32_t *__theValue );

```

关键字volatile只确保每次获取volatile变量时都是从内存加载变量，而不是使用寄存器里面的值，但是它不保证代码访问变量是正确的。

如果用伪代码去实现这个函数:

```objectivec

f (*__theValue == __oldValue) {  
    *__theValue = __newValue;  
    return 1;  
} else {  
    return 0;  
} 

```

如果\_hasConnected为0，意味着没有连接，OSAtomicCompareAndSwap32Barrier返回1，shouldConnect就应该连接。如果\_hasConnected为1，意味着已经连接过了，OSAtomicCompareAndSwap32Barrier返回0，shouldConnect不会再次连接。



所谓连接的过程就是RACMulticastConnection内部用RACSubject订阅self.sourceSignal。sourceSignal是RACSignal，会把订阅者RACSubject保存到RACPassthroughSubscriber中，sendNext的时候就会调用RACSubject sendNext，这时就会把sourceSignal的信号都发送给各个订阅者了。



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


OSAtomicIncrement32Barrier 和 OSAtomicDecrement32Barrier也是原子运算的操作符，分别是+1和-1操作。在autoconnect为了保证线程安全，用到了一个subscriberCount的类似信号量的volatile变量，保证第一个订阅者能连接上。返回的新的信号的订阅者订阅RACSubject，RACSubject也会去订阅内部的sourceSignal。

把冷信号转换成热信号用以下5种方式，5种方法都会用到RACMulticastConnection。接下来一一分析它们的具体实现。



#### 1. multicast:

```objectivec

- (RACMulticastConnection *)multicast:(RACSubject *)subject {
	[subject setNameWithFormat:@"[%@] -multicast: %@", self.name, subject.name];
	RACMulticastConnection *connection = [[RACMulticastConnection alloc] initWithSourceSignal:self subject:subject];
	return connection;
}

```

multicast：的操作就是初始化一个RACMulticastConnection对象，SourceSignal是self，内部的RACSubject是入参subject。

```objectivec

    RACMulticastConnection *connection = [signal multicast:[RACSubject subject]];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```

调用 multicast:把冷信号转换成热信号有一个点不方便的是，需要自己手动connect。注意转换完之后的热信号在RACMulticastConnection的signal属性中，所以需要订阅的是connection.signal。


#### 2. publish

```objectivec

- (RACMulticastConnection *)publish {
	RACSubject *subject = [[RACSubject subject] setNameWithFormat:@"[%@] -publish", self.name];
	RACMulticastConnection *connection = [self multicast:subject];
	return connection;
}

```


publish方法只不过是去调用了multicast:方法，publish内部会新建好一个RACSubject，并把它当成入参传递给RACMulticastConnection。

```objectivec

    RACMulticastConnection *connection = [signal publish];
    [connection.signal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
    [connection connect];

```

同样publish方法也需要手动的调用connect方法。


#### 3. replay


```objectivec

- (RACSignal *)replay {
	RACReplaySubject *subject = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -replay", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}


```

replay方法会把RACReplaySubject当成RACMulticastConnection的RACSubject传递进去，初始化好了RACMulticastConnection，再自动调用connect方法，返回的信号就是转换好的热信号，即RACMulticastConnection里面的RACSubject信号。


这里必须是RACReplaySubject，因为在replay方法里面先connect了。如果用RACSubject，那信号在connect之后就会通过RACSubject把原信号发送给各个订阅者了。用RACReplaySubject把信号保存起来，即使replay方法里面先connect，订阅者后订阅也是可以拿到之前的信号值的。


#### 4. replayLast


```objectivec

- (RACSignal *)replayLast {
	RACReplaySubject *subject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"[%@] -replayLast", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}

```


replayLast 和 replay的实现基本一样，唯一的不同就是传入的RACReplaySubject的Capacity是1，意味着只能保存最新的值。所以使用replayLast，订阅之后就只能拿到原信号最新的值。


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

replayLazily 的实现也和 replayLast、replay实现很相似。只不过把connect放到了defer的操作里面去了。

defer操作的实现如下：

```objectivec


+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

```

defer 单词的字面意思是延迟的。也和这个函数实现的效果是一致的。只有当defer返回的新信号被订阅的时候，才会执行入参block( )闭包。订阅者会订阅这个block( )闭包的返回值RACSignal。


block( )闭包被延迟创建RACSignal了，这就是defer。如果block( )闭包含有和时间有关的操作，或者副作用，想要延迟执行，就可以用defer。


还有一个类似的操作，then

```objectivec

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameWithFormat:@"[%@] -then:", self.name];
}

```

then的操作也是延迟，只不过它是把block( )闭包延迟到原信号发送complete之后。通过then信号变化得到的新的信号，在原信号发送值的期间的时间内，都不会发送任何值，因为ignoreValues了，一旦原信号sendComplete之后，就紧接着block( )闭包产生的信号。

回到replayLazily操作上来，作用同样是把冷信号转换成热信号，只不过sourceSignal是在返回的新信号第一次被订阅的时候才被订阅。原因就是defer延迟了block( )闭包的执行了。



### 最后

关于ReactiveCocoa v2.5中，冷信号即使转换成了热信号，热信号在之后的变换中还会在变成冷信号，所以在v2.5的版本中会有很多冷信号转成热信号的操作。在ReactiveCocoa v3.0以后的版本中，新增了热信号变换之后还是热信号的机制，如此以来就方便很多，不需要增加很多不必要的冷信号转成热信号的代码。

关于RACSignal的变换操作还剩下高阶信号操作，下篇接着继续分析。最后请大家多多指教。

