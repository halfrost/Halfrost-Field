# ReactiveCocoa 中 RACCommand 底层实现分析

![](https://img.halfrost.com/Blog/ArticleTitleImage/38_0_.png)



### 前言

在ReactiveCocoa 过程中，除去RACSignal和RACSubject这些信号类以外，有些时候我们可能还需要封装一些固定的操作集合。这些操作集合都是固定的，每次只要一触发就会执行事先定义好的一个过程。在iOS开发过程中，按钮的点击事件就可能有这种需求。那么RACCommand就可以实现这种需求。

当然除了封装一个操作集合以外，RACCommand还能集中处理错误等等功能。今天就来从底层来看看RACCommand是如何实现的。


### 目录

- 1.RACCommand的定义
- 2.initWithEnabled: signalBlock: 底层实现分析
- 3.execute:底层实现分析
- 4.RACCommand的一些Category



### 一. RACCommand的定义

![](https://img.halfrost.com/Blog/ArticleImage/38_1.png)




首先说说RACCommand的作用。
RACCommand 在ReactiveCocoa 中是对一个动作的触发条件以及它产生的触发事件的封装。

- 触发条件：初始化RACCommand的入参enabledSignal就决定了RACCommand是否能开始执行。入参enabledSignal就是触发条件。举个例子，一个按钮是否能点击，是否能触发点击事情，就由入参enabledSignal决定。

- 触发事件：初始化RACCommand的另外一个入参(RACSignal * (^)(id input))signalBlock就是对触发事件的封装。RACCommand每次执行都会调用一次signalBlock闭包。

RACCommand最常见的例子就是在注册登录的时候，点击获取验证码的按钮，这个按钮的点击事件和触发条件就可以用RACCommand来封装，触发条件是一个信号，它可以是验证手机号，验证邮箱，验证身份证等一些验证条件产生的enabledSignal。触发事件就是按钮点击之后执行的事件，可以是发送验证码的网络请求。


RACCommand在ReactiveCocoa中算是很特别的一种存在，因为它的实现并不是FRP实现的，是OOP实现的。RACCommand的本质就是一个对象，在这个对象里面封装了4个信号。





关于RACCommand的定义如下：

```objectivec

@interface RACCommand : NSObject
@property (nonatomic, strong, readonly) RACSignal *executionSignals;
@property (nonatomic, strong, readonly) RACSignal *executing;
@property (nonatomic, strong, readonly) RACSignal *enabled;
@property (nonatomic, strong, readonly) RACSignal *errors;
@property (atomic, assign) BOOL allowsConcurrentExecution;
volatile uint32_t _allowsConcurrentExecution;

@property (atomic, copy, readonly) NSArray *activeExecutionSignals;
NSMutableArray *_activeExecutionSignals;

@property (nonatomic, strong, readonly) RACSignal *immediateEnabled;
@property (nonatomic, copy, readonly) RACSignal * (^signalBlock)(id input);
@end

```

RACCommand中4个最重要的信号就是定义开头的那4个信号，executionSignals，executing，enabled，errors。需要注意的是，**这4个信号基本都是（并不是完全是）在主线程上执行的**。


#### 1. RACSignal *executionSignals

executionSignals是一个高阶信号，所以在使用的时候需要进行降阶操作，降价操作在前面分析过了，在ReactiveCocoa v2.5中只支持3种降阶方式，flatten，switchToLatest，concat。降阶的方式就根据需求来选取。


还有选择原则是，如果在不允许Concurrent并发的RACCommand中一般使用switchToLatest。如果在允许Concurrent并发的RACCommand中一般使用flatten。



#### 2. RACSignal *executing

executing这个信号就表示了当前RACCommand是否在执行，信号里面的值都是BOOL类型的。YES表示的是RACCommand正在执行过程中，命名也说明的是正在进行时ing。NO表示的是RACCommand没有被执行或者已经执行结束。

#### 3. RACSignal *enabled

enabled信号就是一个开关，RACCommand是否可用。这个信号除去以下2种情况会返回NO：

- RACCommand 初始化传入的enabledSignal信号，如果返回NO，那么enabled信号就返回NO。
- RACCommand开始执行中，allowsConcurrentExecution为NO，那么enabled信号就返回NO。

除去以上2种情况以外，enabled信号基本都是返回YES。

#### 4. RACSignal *errors

errors信号就是RACCommand执行过程中产生的错误信号。这里特别需要注意的是：在对RACCommand进行错误处理的时候，**我们不应该使用subscribeError:对RACCommand的executionSignals
进行错误的订阅**，因为executionSignals这个信号是不会发送error事件的，那当RACCommand包裹的信号发送error事件时，我们要怎样去订阅到它呢？应该**用subscribeNext:去订阅错误信号**。


```objectivec

[commandSignal.errors subscribeNext:^(NSError *x) {     
    NSLog(@"ERROR! --> %@",x);
}];

```


#### 5. BOOL allowsConcurrentExecution


![](https://img.halfrost.com/Blog/ArticleImage/38_2.png)




allowsConcurrentExecution是一个BOOL变量，它是用来表示当前RACCommand是否允许并发执行。默认值是NO。

如果allowsConcurrentExecution为NO，那么RACCommand在执行过程中，enabled信号就一定都返回NO，不允许并发执行。如果allowsConcurrentExecution为YES，允许并发执行。

如果是允许并发执行的话，就会出现多个信号就会出现一起发送值的情况。那么这种情况产生的高阶信号一般可以采取flatten(等效于flatten:0，+merge:)的方式进行降阶。

这个变量在具体实现中是用的volatile原子的操作，在实现中重写了它的get和set方法。

```objectivec

// 重写 get方法
- (BOOL)allowsConcurrentExecution {
    return _allowsConcurrentExecution != 0;
}

// 重写 set方法
- (void)setAllowsConcurrentExecution:(BOOL)allowed {
    [self willChangeValueForKey:@keypath(self.allowsConcurrentExecution)];
    
    if (allowed) {
        OSAtomicOr32Barrier(1, &_allowsConcurrentExecution);
    } else {
        OSAtomicAnd32Barrier(0, &_allowsConcurrentExecution);
    }
    
    [self didChangeValueForKey:@keypath(self.allowsConcurrentExecution)];
}


```

OSAtomicOr32Barrier是原子运算，它的意义是进行逻辑的“或”运算。通过原子性操作访问被volatile修饰的\_allowsConcurrentExecution对象即可保障函数只执行一次。相应的OSAtomicAnd32Barrier也是原子运算，它的意义是进行逻辑的“与”运算。


#### 6. NSArray *activeExecutionSignals

这个NSArray数组里面装了一个个有序排列的，执行中的信号。NSArray的数组是可以被KVO监听的。


```objectivec

- (NSArray *)activeExecutionSignals {
    @synchronized (self) {
        return [_activeExecutionSignals copy];
    }
}

```

当然内部还有一个NSMutableArray的版本，NSArray数组是它的copy版本，使用它的时候需要加上线程锁，进行线程安全的保护。


在RACCommand内部，是对NSMutableArray数组进行操作的，在这里可变数组里面进行增加和删除的操作。

```objectivec

- (void)addActiveExecutionSignal:(RACSignal *)signal {
    NSCParameterAssert([signal isKindOfClass:RACSignal.class]);
    
    @synchronized (self) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:_activeExecutionSignals.count];
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
        [_activeExecutionSignals addObject:signal];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
    }
}


```

在往数组里面添加数据的时候是满足KVO的，这里对index进行了NSKeyValueChangeInsertion监听。


```objectivec

- (void)removeActiveExecutionSignal:(RACSignal *)signal {
    NSCParameterAssert([signal isKindOfClass:RACSignal.class]);
    
    @synchronized (self) {
        NSIndexSet *indexes = [_activeExecutionSignals indexesOfObjectsPassingTest:^ BOOL (RACSignal *obj, NSUInteger index, BOOL *stop) {
            return obj == signal;
        }];
        
        if (indexes.count == 0) return;
        
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
        [_activeExecutionSignals removeObjectsAtIndexes:indexes];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
    }
}



```

在移除数组里面也是依照indexes来进行移除的。注意，增加和删除的操作都必须包在@synchronized (self)中保证线程安全。


```objectivec

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return NO;
}


```

从上面增加和删除的操作中我们可以看见了RAC的作者在手动发送change notification，手动调用willChange: 和 didChange:方法。作者的目的在于防止一些不必要的swizzling可能会影响到增加和删除的操作，所以这里选择的手动发送通知的方式。



美团博客上这篇[ReactiveCocoa核心元素与信号流](http://tech.meituan.com/ReactiveCocoaSignalFlow.html)文章里面对activeExecutionSignals的变化引起的一些变化画了一张数据流图：

![](https://img.halfrost.com/Blog/ArticleImage/38_3.png)

除去没有影响到enabled信号，activeExecutionSignals的变化会影响到其他三个信号。


#### 7. RACSignal *immediateEnabled

![](https://img.halfrost.com/Blog/ArticleImage/38_4.png)




这个信号也是一个enabled信号，但是和之前的enabled信号不同的是，它并不能保证在main thread主线程上，它可以在任意一个线程上。



#### 8. RACSignal * (^signalBlock)(id input)

这个闭包返回值是一个信号，这个闭包是在初始化RACCommand的时候会用到，下面分析源码的时候会出现。



```objectivec

- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock;
- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock;
- (RACSignal *)execute:(id)input;

```

RACCommand 暴露出来的就3个方法，2个初始化方法和1个execute:的方法，接下来就来分析一下这些方法的底层实现。


### 二. initWithEnabled: signalBlock: 底层实现分析

![](https://img.halfrost.com/Blog/ArticleImage/38_5.png)





首先先来看看比较短的那个初始化方法。

```objectivec

- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock {
    return [self initWithEnabled:nil signalBlock:signalBlock];
}

```

initWithSignalBlock:方法实际就是调用了initWithEnabled: signalBlock:方法。

```objectivec

- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock {

}


```

initWithSignalBlock:方法相当于第一个参数传的是nil的initWithEnabled: signalBlock:方法。第一个参数是enabledSignal，第二个参数是signalBlock的闭包。enabledSignal如果传的是nil，那么就相当于是传进了[RACSignal return:@YES]。


接下来详细分析一下initWithEnabled: signalBlock:方法的实现。




这个方法的实现非常长，需要分段来分析。RACCommand的初始化就是对自己的4个信号，executionSignals，executing，enabled，errors的初始化。


#### 1. executionSignals信号的初始化




```objectivec

RACSignal *newActiveExecutionSignals = [[[[[self rac_valuesAndChangesForKeyPath:@keypath(self.activeExecutionSignals) options:NSKeyValueObservingOptionNew observer:nil]
                                           
    reduceEach:^(id _, NSDictionary *change) {
    NSArray *signals = change[NSKeyValueChangeNewKey];
    if (signals == nil) return [RACSignal empty];
    
    return [signals.rac_sequence signalWithScheduler:RACScheduler.immediateScheduler];
    }]
   concat]
   publish]
   autoconnect];



```

通过rac\_valuesAndChangesForKeyPath: options: observer: 方法监听self.activeExecutionSignals数组里面是否有增加新的信号。rac\_valuesAndChangesForKeyPath: options: observer: 方法的返回时是一个RACTuple，它的定义是这样的:RACTuplePack(value, change)。


只要每次数组里面加入了新的信号，那么rac\_valuesAndChangesForKeyPath: options: observer: 方法就会把新加的值和change字典包装成RACTuple返回。再对这个信号进行一次reduceEach:操作。

举个例子，change字典可能是如下的样子：


```vim

{
    indexes = "<_NSCachedIndexSet: 0x60000023b8a0>[number of indexes: 1 (in 1 ranges), indexes: (0)]";
    kind = 2;
    new =     (
        "<RACReplaySubject: 0x6000006613c0> name: "
    );
}


```

取出change[NSKeyValueChangeNewKey]就能取出每次变化新增的信号数组，然后把这个数组通过signalWithScheduler:转换成信号。

把原信号中每个值是里面装满RACTuple的信号通过变换，变换成了装满RACSingnal的三阶信号，通过concat进行降阶操作，降阶成了二阶信号。最后通过publish和autoconnect操作，把冷信号转换成热信号。

newActiveExecutionSignals最终是一个二阶热信号。

接下来再看看executionSignals是如何变换而来的。

```objectivec

_executionSignals = [[[newActiveExecutionSignals
                       map:^(RACSignal *signal) {
                           return [signal catchTo:[RACSignal empty]];
                       }]
                      deliverOn:RACScheduler.mainThreadScheduler]
                     setNameWithFormat:@"%@ -executionSignals", self];


```


executionSignals把newActiveExecutionSignals中错误信号都换成空信号。经过map变换之后，executionSignals是newActiveExecutionSignals的无错误信号的版本。由于map只是变换并没有降阶，所以executionSignals还是一个二阶的高阶冷信号。

注意最后加上了deliverOn，**executionSignals信号每个值都是在主线程中发送的。**


#### 2. errors信号的初始化

在RACCommand中会搜集其所有的error信号，都装进自己的errors的信号中。这也是RACCommand的特点之一，能把错误统一处理。


```objectivec

RACMulticastConnection *errorsConnection = [[[newActiveExecutionSignals
                                              flattenMap:^(RACSignal *signal) {
                                                  return [[signal ignoreValues]
                                                          catch:^(NSError *error) {
                                                              return [RACSignal return:error];
                                                          }];
                                              }]
                                             deliverOn:RACScheduler.mainThreadScheduler]
                                             publish];

```


从上面分析中，我们知道，newActiveExecutionSignals最终是一个二阶热信号。这里在errorsConnection的变换中，我们对这个二阶的热信号进行flattenMap:降阶操作，只留下所有的错误信号，最后把所有的错误信号都装在一个低阶的信号中，这个信号中每个值都是一个error。同样，变换中也追加了deliverOn:操作，回到主线程中去操作。最后把这个冷信号转换成热信号，但是注意，还没有connect。


```objectivec

_errors = [errorsConnection.signal setNameWithFormat:@"%@ -errors", self];
[errorsConnection connect];

```

假设某个订阅者在RACCommand中的信号已经开始执行之后才订阅的，如果错误信号是一个冷信号，那么订阅之前的错误就接收不到了。所以错误应该是一个热信号，不管什么时候订阅都可以接收到所有的错误。

error信号就是热信号errorsConnection传出来的一个热信号。**error信号每个值都是在主线程上发送的。**



#### 3. executing信号的初始化

executing这个信号表示了当前RACCommand是否在执行，信号里面的值都是BOOL类型的。那么如何拿到这样一个BOOL信号呢？


```objectivec

RACSignal *immediateExecuting = [RACObserve(self, activeExecutionSignals) map:^(NSArray *activeSignals) {
    return @(activeSignals.count > 0);
}];


```

由于self.activeExecutionSignals是可以被KVO的，所以每当activeExecutionSignals变化的时候，判断当前数组里面是否还有信号，如果数组里面有值，就代表了当前有在执行中的信号。


```objectivec


_executing = [[[[[immediateExecuting
                  deliverOn:RACScheduler.mainThreadScheduler]
                  startWith:@NO]
                  distinctUntilChanged]
                  replayLast]
                  setNameWithFormat:@"%@ -executing", self];



```


immediateExecuting信号表示当前是否有信号在执行。初始值为NO，一旦immediateExecuting不为NO的时候就会发出信号。最后通过replayLast转换成永远只保存最新的一个值的热信号。

**executing信号除去第一个默认值NO，其他的每个值也是在主线程中发送的。**

#### 4. enabled信号的初始化


```objectivec

RACSignal *moreExecutionsAllowed = [RACSignal
                                    if:RACObserve(self, allowsConcurrentExecution)
                                    then:[RACSignal return:@YES]
                                    else:[immediateExecuting not]];


```

先监听self.allowsConcurrentExecution变量是否有变化，allowsConcurrentExecution默认值为NO。如果有变化，allowsConcurrentExecution为YES，就说明允许并发执行，那么就返回YES的RACSignal，allowsConcurrentExecution为NO，就说明不允许并发执行，那么就要看当前是否有正在执行的信号。immediateExecuting就是代表当前是否有在执行的信号，对这个信号取非，就是是否允许执行下一个信号的BOOL值。这就是moreExecutionsAllowed的信号。


```objectivec

if (enabledSignal == nil) {
    enabledSignal = [RACSignal return:@YES];
} else {
    enabledSignal = [[[enabledSignal
                       startWith:@YES]
                       takeUntil:self.rac_willDeallocSignal]
                       replayLast];
}


```

这里的代码就说明了，如果第一个参数传的是nil，那么就相当于传进来了一个[RACSignal return:@YES]信号。

如果enabledSignal不为nil，就在enabledSignal信号前面插入一个YES的信号，目的是为了防止传入的enabledSignal虽然不为nil，但是里面是没有信号的，比如[RACSignal never]，[RACSignal empty]，这些信号传进来也相当于是没用的，所以在开头加一个YES的初始值信号。

最后同样通过replayLast操作转换成只保存最新的一个值的热信号。


```objectivec

_immediateEnabled = [[RACSignal
                      combineLatest:@[ enabledSignal, moreExecutionsAllowed ]]
                      and];

```


这里涉及到了combineLatest:的变换操作，这个操作在[之前的文章](https://halfrost.com/reactivecocoa_racsignal_operations2/)里面分析过了，这里不再详细分析源码实现。combineLatest:的作用就是把后面数组里面传入的每个信号，不管是谁发送出来一个信号，都会把数组里面所有信号的最新的值组合到一个RACTuple里面。immediateEnabled会把每个RACTuple里面的元素都进行逻辑and运算，这样immediateEnabled信号里面装的也都是BOOL值了。

immediateEnabled信号的意义就是每时每刻监听RACCommand是否可以enabled。它是由2个信号进行and操作得来的。每当allowsConcurrentExecution变化的时候就会产生一个信号，此时再加上enabledSignal信号，就能判断这一刻RACCommand是否能够enabled。每当enabledSignal变化的时候也会产生一个信号，再加上allowsConcurrentExecution是否允许并发，也能判断这一刻RACCommand是否能够enabled。所以immediateEnabled是由这两个信号combineLatest:之后再进行and操作得来的。


```objectivec


_enabled = [[[[[self.immediateEnabled
                take:1]
                concat:[[self.immediateEnabled skip:1] deliverOn:RACScheduler.mainThreadScheduler]]
                distinctUntilChanged]
                replayLast]
                setNameWithFormat:@"%@ -enabled", self];


```

由上面源码可以知道，self.immediateEnabled是由enabledSignal, moreExecutionsAllowed组合而成的。根据源码，enabledSignal的第一个信号值一定是[RACSignal return:@YES]，moreExecutionsAllowed是RACObserve(self, allowsConcurrentExecution)产生的，由于allowsConcurrentExecution默认值是NO，所以moreExecutionsAllowed的第一个值是[immediateExecuting not]。

这里比较奇怪的地方是为何要用一次concat操作，把第一个信号值和后面的连接起来。如果直接写[self.immediateEnabled deliverOn:RACScheduler.mainThreadScheduler]，那么整个self.immediateEnabled就都在主线程上了。作者既然没有这么写，肯定是有原因的。

> This signal will send its current value upon subscription, and then all future values on the main thread.


通过查看文档，明白了作者的意图，作者的目的是为了让第一个值以后的每个值都发送在主线程上，所以这里skip:1之后接着deliverOn:RACScheduler.mainThreadScheduler。那第一个值呢？第一个值在一订阅的时候就发送出去了，同订阅者所在线程一致。

distinctUntilChanged保证enabled信号每次状态变化的时候只取到一个状态值。最后调用replayLast转换成只保存最新值的热信号。

从源码上看，**enabled信号除去第一个值以外的每个值也都是在主线程上发送的。**


### 三. execute:底层实现分析


![](https://img.halfrost.com/Blog/ArticleImage/38_6.png)






```objectivec

- (RACSignal *)execute:(id)input {
    // 1
    BOOL enabled = [[self.immediateEnabled first] boolValue];
    if (!enabled) {
        NSError *error = [NSError errorWithDomain:RACCommandErrorDomain code:RACCommandErrorNotEnabled userInfo:@{
                          NSLocalizedDescriptionKey: NSLocalizedString(@"The command is disabled and cannot be executed", nil),RACUnderlyingCommandErrorKey: self }];
        
        return [RACSignal error:error];
    }
    // 2
    RACSignal *signal = self.signalBlock(input);
    NSCAssert(signal != nil, @"nil signal returned from signal block for value: %@", input);
    // 3
    RACMulticastConnection *connection = [[signal subscribeOn:RACScheduler.mainThreadScheduler] multicast:[RACReplaySubject subject]];
    
    @weakify(self);
    // 4
    [self addActiveExecutionSignal:connection.signal];
    [connection.signal subscribeError:^(NSError *error) {
        @strongify(self);
        // 5
        [self removeActiveExecutionSignal:connection.signal];
    } completed:^{
        @strongify(self);
        // 5
        [self removeActiveExecutionSignal:connection.signal];
    }];
    
    [connection connect];
     // 6
    return [connection.signal setNameWithFormat:@"%@ -execute: %@", self, [input rac_description]];
}



```

把上述代码分成6步来分析：

1. self.immediateEnabled为了保证第一个值能正常的发送给订阅者，所以这里用了同步的first的方法，也是可以接受的。调用了first方法之后，根据这第一个值来判断RACCommand是否可以开始执行。如果不能执行就返回一个错误信号。

2. 这里就是RACCommand开始执行的地方。self.signalBlock是RACCommand在初始化的时候传入的一个参数，RACSignal * (^signalBlock)(id input)这个闭包的入参是一个id input，返回值是一个信号。这里正好把execute的入参input传进来。

3. 把RACCommand执行之后的信号先调用subscribeOn:保证didSubscribe block( )闭包在主线程中执行，再转换成RACMulticastConnection，准备转换成热信号。

4. 在最终的信号被订阅者订阅之前，我们需要优先更新RACCommand里面的executing和enabled信号，所以这里要先把connection.signal加入到self.activeExecutionSignals数组里面。

5. 订阅最终结果信号，出现错误或者完成，都要更新self.activeExecutionSignals数组。

6. 这里想说明的是，最终的execute:返回的信号，和executionSignals是一样的。

**这里有一个需要注意的点：**

**executionSignals虽然是一个冷信号，但是它是由内部的addedExecutionSignalsSubject的产生的，这是一个热信号，订阅者订阅它的时候需要在execute:执行之前去订阅，否则这个addedExecutionSignalsSubject热信号对已保存的所有的订阅者发送完信号以后，再订阅就收不到任何信号了。所以需要在热信号发送信号之前订阅，把自己保存到热信号的订阅者数组里。所以executionSignals的订阅要在execute:执行之前。**

**而execute:返回的信号是RACReplaySubject热信号，它会把订阅者保存起来，即使先发送信号，再订阅，订阅者也可以收到之前发送的值。**

**两个信号虽然信号内容都相同，但是订阅的先后次序不同，executionSignals必须在execute:执行之前去订阅，而execute:返回的信号是在execute:执行之后去订阅的。**


### 四. RACCommand的一些Category


![](https://img.halfrost.com/Blog/ArticleImage/38_7.png)




RACCommand在日常iOS开发过程中，很适合上下拉刷新，按钮点击等操作，所以ReactiveCocoa就帮我们在这些UI控件上封装了一个RACCommand属性——rac\_command。


#### 1. UIBarButtonItem+RACCommandSupport


一旦UIBarButtonItem被点击，RACCommand就会执行。

```objectivec

- (RACCommand *)rac_command {
    return objc_getAssociatedObject(self, UIControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
    objc_setAssociatedObject(self, UIControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 检查已经存储过的信号，移除老的，添加一个新的
    RACDisposable *disposable = objc_getAssociatedObject(self, UIControlEnabledDisposableKey);
    [disposable dispose];
    
    if (command == nil) return;
    
    disposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];
    objc_setAssociatedObject(self, UIControlEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self rac_hijackActionAndTargetIfNeeded];
}


```


给UIBarButtonItem添加rac\_command属性用到了runtime里面的AssociatedObject关联对象。这里给UIBarButtonItem类新增了2个关联对象，key分别是UIControlRACCommandKey，UIControlEnabledDisposableKey。UIControlRACCommandKey对应的是绑定的command，UIControlEnabledDisposableKey对应的是command.enabled的disposable信号。


set方法里面最后会调用rac\_hijackActionAndTargetIfNeeded，这个方法需要特别注意：

```objectivec

- (void)rac_hijackActionAndTargetIfNeeded {
    SEL hijackSelector = @selector(rac_commandPerformAction:);
    if (self.target == self && self.action == hijackSelector) return;
    
    if (self.target != nil) NSLog(@"WARNING: UIBarButtonItem.rac_command hijacks the control's existing target and action.");
        
        self.target = self;
        self.action = hijackSelector;
}

- (void)rac_commandPerformAction:(id)sender {
    [self.rac_command execute:sender];
}



```



rac\_hijackActionAndTargetIfNeeded方法是对当前UIBarButtonItem的target和action进行检查。

如果当前UIBarButtonItem的target = self，并且action = @selector(rac\_commandPerformAction:)，那么就算检查通过符合执行RACCommand的前提条件了，直接return。

如果上述条件不符合，就**强制改变**UIBarButtonItem的target = self，并且action = @selector(rac\_commandPerformAction:)，所以这里需要注意的就是，UIBarButtonItem调用rac\_command，会被强制改变它的target和action。

#### 2. UIButton+RACCommandSupport

一旦UIButton被点击，RACCommand就会执行。

```objectivec

- (RACCommand *)rac_command {
    return objc_getAssociatedObject(self, UIButtonRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
    objc_setAssociatedObject(self, UIButtonRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    RACDisposable *disposable = objc_getAssociatedObject(self, UIButtonEnabledDisposableKey);
    [disposable dispose];
    
    if (command == nil) return;
    
    disposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];
    objc_setAssociatedObject(self, UIButtonEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self rac_hijackActionAndTargetIfNeeded];
}


```


这里给UIButton添加绑定2个属性同样也用到了runtime里面的AssociatedObject关联对象。代码和UIBarButtonItem的实现基本一样。同样是给UIButton类新增了2个关联对象，key分别是UIButtonRACCommandKey，UIButtonEnabledDisposableKey。UIButtonRACCommandKey对应的是绑定的command，UIButtonEnabledDisposableKey对应的是command.enabled的disposable信号。


```objectivec


- (void)rac_hijackActionAndTargetIfNeeded {
    SEL hijackSelector = @selector(rac_commandPerformAction:);
    
    for (NSString *selector in [self actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]) {
        if (hijackSelector == NSSelectorFromString(selector)) {
            return;
        }
    }
    
    [self addTarget:self action:hijackSelector forControlEvents:UIControlEventTouchUpInside];
}

- (void)rac_commandPerformAction:(id)sender {
    [self.rac_command execute:sender];
}



```


rac\_hijackActionAndTargetIfNeeded函数的意思和之前的一样，也是检查UIButton的target和action。最终结果的UIButton的target = self，action = @selector(rac\_commandPerformAction:)

#### 3. UIRefreshControl+RACCommandSupport

```objectivec

- (RACCommand *)rac_command {
    return objc_getAssociatedObject(self, UIRefreshControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
    objc_setAssociatedObject(self, UIRefreshControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [objc_getAssociatedObject(self, UIRefreshControlDisposableKey) dispose];
    
    if (command == nil) return;
    
    RACDisposable *enabledDisposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];
    
    RACDisposable *executionDisposable = [[[[self
                                             rac_signalForControlEvents:UIControlEventValueChanged]
                                             map:^(UIRefreshControl *x) {
                                                return [[[command
                                                          execute:x]
                                                          catchTo:[RACSignal empty]]
                                                          then:^{
                                                            return [RACSignal return:x];
                                                        }];
                                            }]
                                            concat]
                                            subscribeNext:^(UIRefreshControl *x) {
                                              [x endRefreshing];
                                            }];
    
    RACDisposable *commandDisposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ enabledDisposable, executionDisposable ]];
    objc_setAssociatedObject(self, UIRefreshControlDisposableKey, commandDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}



```

这里给UIRefreshControl添加绑定2个属性同样也用到了runtime里面的AssociatedObject关联对象。代码和UIBarButtonItem的实现基本一样。同样是给UIButton类新增了2个关联对象，key分别是UIRefreshControlRACCommandKey，UIRefreshControlDisposableKey。UIRefreshControlRACCommandKey对应的是绑定的command，UIRefreshControlDisposableKey对应的是command.enabled的disposable信号。


这里多了一个executionDisposable信号，这个信号是用来结束刷新操作的。

```objectivec

[[[command execute:x] catchTo:[RACSignal empty]] then:^{ return [RACSignal return:x]; }];

```


这个信号变换先把RACCommand执行，执行之后得到的结果信号剔除掉所有的错误。then操作就是忽略掉所有值，在最后添加一个返回UIRefreshControl对象的信号。

[self rac\_signalForControlEvents:UIControlEventValueChanged]之后再map升阶为高阶信号，所以最后用concat降阶。最后订阅这个信号，订阅只会收到一个值，command执行完毕之后的信号发送完所有的值的时候，即收到这个值的时刻就是最终刷新结束的时刻。

所以最终的disposable信号还要加上executionDisposable。



### 最后

关于RACCommand底层实现分析都已经分析完成。最后请大家多多指教。

