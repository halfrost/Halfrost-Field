# 函数响应式编程(FRP)从入门到 "放弃 "——图解 RACSignal 篇


![](https://img.halfrost.com//Blog/ArticleTitleImage/c/ac/7edb67708d620d3fa721e92b330bd.jpg)



#### 目录
- 1.RACSignal的创建
- 2.RACSignal的订阅
- 3.RACSignal各类操作


####一.RACSignal的创建  

1.创建单元信号

```

    NSError *errorObject = [NSError errorWithDomain:@"Something wrong" code:500 userInfo:nil];  

    //基本的4种创建方法
    RACSignal *signal1 = [RACSignal return:@"Some Value"];
    RACSignal *signal2 = [RACSignal error:errorObject];
    RACSignal *signal3 = [RACSignal empty];
    RACSignal *signal4 = [RACSignal never];
```  
  

2.创建动态信号  

```    
    RACSignal *signal5 = [RACSignal createSignal:
                          ^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@1];
        [subscriber sendNext:@2];
        [subscriber sendError:errorObject];
        [subscriber sendCompleted];
        return [RACDisposable disposableWithBlock:^{
        }];
    }];
```

3.通过Cocoa桥接方式获得一个信号  

```

    RACSignal *signal6 = [view rac_signalForSelector:@selector(setFrame:)];
    RACSignal *signal7 = [view rac_signalForControlEvents:UIControlEventTouchUpInside];
    RACSignal *signal8 = [view rac_willDeallocSignal];

    //KVO的原理实现
    RACSignal *signal9 = RACObserve(view, backgroundColor);
```  

4.通过信号变换获得  

```
RACSignal *signal10 = [signal1 map:^id(NSString *value) {
        return [value substringFromIndex:1];
    }];
```

5.通过序列转换获得

```

RACSequence *sequence = @[@"A", @"B", @"C"].rac_sequence;

//这里转换之后获得的signal11是一个很快把信号值吐出的一个信号
RACSignal *signal11 = sequence.signal;
```

####二.RACSignal的订阅  

1.订阅方法 

```

    [signal11 subscribeNext:^(id x) {
        NSLog(@"next value is %@", x);
    } error:^(NSError *error) {
        NSLog(@"Ops! Get some error: %@", error);
    } completed:^{
        NSLog(@"It finished success");
    }];
```

2.绑定方法  

```
//这里相当于KVO，signal每次产生一个color，都是对backgroundColor进行赋值
RAC(view, backgroundColor) = signal10;

```

3.Cocoa桥接  

```

[view rac_liftSelector:@selector(convertPoint:toView:)
               withSignals:signal1, signal2, nil];

[view rac_liftSelector:@selector(convertRect:toView:)
      withSignalsFromArray:@[signal3, signal4]];

[view rac_liftSelector:@selector(convertRect:toLayer:)
     withSignalOfArguments:signal5];
```
值得说明的是:如果selector有返回值，那么调用rac_liftSelector会得到一个新的信号。新的信号是调用selector之后的返回值。

4.订阅过程的执行过程

```

    RACSignal *signal = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
    {
1        [subscriber sendNext:@1];
2        [subscriber sendNext:@2];
3        [subscriber sendCompleted];
4        return [RACDisposable disposableWithBlock:^{
5            NSLog(@"dispose");
        }];
    }];
    
    RACDisposable *disposable = [signal subscribeNext:^(id x) {
6        NSLog(@"next value is %@", x);
    } error:^(NSError *error) {
7        NSLog(@"Ops! Get some error: %@", error);
    } completed:^{
8        NSLog(@"It finished success");
    }];
    
9    [disposable dispose];
```  

如果一个signal信号被订阅，那么就会先进入到信号创建的block中，当运行到sendNext，sendCompleted，sendError，接下来就会走到订阅者的对应的subscribeNext，completed，error对应的block块中。主要顺序还是在signal的创建的block中进行执行，只是到了特性的sendNext，sendCompleted，sendError，才会跳到订阅者的对应的block中去执行。订阅者的相应的block执行完了之后，再次回到signal信号的block中继续往下执行。最后signal信号执行完之后会执行disposable。当signal信号发现了disposable，会立即调用创建signal信号里面RACDisposable的block块。

执行过程：1-6-2-6-3-8-4-5-9


RACStream 和 RACSignal的区别 在于 返回数据还是返回事件。
事件总共3种 ：值，错误，结束。

值可能是OC对象，RACTuple，甚至是一个RACSignal。

先来说一下RACTuple，RACTuple也是RAC定义的一种数据类型，可以说是NSArray的简化版

```

    RACTuple *tuple = RACTuplePack(@1, @"haha");
    
    id first = tuple.first;
    id second = tuple.second;
    id last = tuple.last;
    id index1 = tuple[1];
    
    RACTupleUnpack(NSNumber *num, NSString *str) = tuple;
```

这里有两个宏，RACTuplePack是可以把后面2个对象打包成一个RACTuple。RACTuple也实现了下标访问。使用的过程中并不是id类型，所以需要强转一下类型。类似于这种用法，RACTupleUnpack(NSNumber *num, NSString *str)。

####三.RACSignal的各类操作

先来约定好图例

![](http://upload-images.jianshu.io/upload_images/1194012-31823227ffed454f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####1.单个信号的变换  
- 1.对值的操作
- 2.对数量的操作
- 3.对维度的操作
- 4.对时间间隔的操作


![](http://upload-images.jianshu.io/upload_images/1194012-493f98c66bfdf7cb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1.对值的操作  

- Map操作
- MapReplace操作
- ReduceEach操作
- not操作
- and操作
- or操作
- reduceApply操作
- materialize操作
- dematerialize操作

(1)Map操作  

![](http://upload-images.jianshu.io/upload_images/1194012-9558edfc6d89d701.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *SignalB = [signalA map:^id(NSNumber *value) {
        return @(value.integerValue * 2);
    }];
```

如果Map过程中遇到了Error，Error并不会进行Map，而是直接Error返回

![](http://upload-images.jianshu.io/upload_images/1194012-75fd1b2e7ca6bae4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


(2)MapReplace操作



![](http://upload-images.jianshu.io/upload_images/1194012-adcd0aab1318ee97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```

RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *signalB = [signalA map:^id(id value) {
        return @8;
    }]; // signalB is --8--8--8--8--|
    
RACSignal *signalC = [signalA mapReplace:@8];
    // signalC is --8--8--8--8--| too.
```

(3)ReduceEach操作

![](http://upload-images.jianshu.io/upload_images/1194012-54d88f54d117b0e0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACTuple *a = RACTuplePack(@1, @2);
RACTuple *b = RACTuplePack(@2, @3);
RACTuple *c = RACTuplePack(@3, @5);
    
RACSignal *signalA = @[a, b, c].rac_sequence.signal;
    
RACSignal *signalB = [signalA reduceEach:^id(NSNumber *first,
                                                 NSNumber *second) {
        return @(first.integerValue + second.integerValue);
    }];
```
reduceEach后面可以跟一些具体类型的参数。

(4)not操作


![](http://upload-images.jianshu.io/upload_images/1194012-7628d11ce0b4f366.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

 RACSignal *signalA = @[@0, @1, @1, @0].rac_sequence.signal;
    
 RACSignal *signalB = [signalA not];
```  


(5)and操作


![](http://upload-images.jianshu.io/upload_images/1194012-7ce7facd5d03c956.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



```

    RACTuple *a = RACTuplePack(@0, @1);
    RACTuple *b = RACTuplePack(@0, @0);
    RACTuple *c = RACTuplePack(@1, @1);
    RACTuple *d = RACTuplePack(@1, @0);
    
    RACSignal *signalA = @[a, b, c, d].rac_sequence.signal;
    
    RACSignal *signalB = [signalA and];
```  


(6)or操作  


![](http://upload-images.jianshu.io/upload_images/1194012-b69324ddb36bbc0f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```


    RACTuple *a = RACTuplePack(@0, @1);
    RACTuple *b = RACTuplePack(@0, @0);
    RACTuple *c = RACTuplePack(@1, @1);
    RACTuple *d = RACTuplePack(@1, @0);

    RACSignal *signalA = @[a, b, c, d].rac_sequence.signal;
    
    RACSignal *signalB = [signalA or];
```
 

(7)reduceApply操作
这里把一个block当做RACTuple的first，然后second，third是其他的参数，当执行reduceApply操作的时候，就会取出第一个参数的block，然后把第二个和第三个参数代入这个block中。


(8)materialize操作
这个操作会把普通的Complete，Error，Next事件，都变成普通的值事件传递出来。

(9)dematerialize操作  
RACEvent有一些值
```
RACEventTypeCompleted,
RACEventTypeError,
RACEventTypeNext
```
使用dematerialize操作之后，可以把上面的值重新转换成对应的事件。  

(10)Scan操作


![](http://upload-images.jianshu.io/upload_images/1194012-adb11010c6fb63a3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
    RACSignal *signalB = [signalA scanWithStart:@0
                                         reduce:^id(NSNumber *running,
                                                    NSNumber *next) {
        return @(running.integerValue + next.integerValue);
    }];
```

对比下面对数量操作里面的Aggregate操作，这里的优点很明显，每次“扫描”都可以拿到一个值。  

```
- (RACSignal *)scanWithStart:(id)startingValue   
             reduceWithIndex:(id (^)(id running, id next, NSUInteger index))reduceBlock;
```
上面这个是scan的变种函数。


2.对数量的操作

- Filter操作
- Ignore / IgnoreValues操作
- DistinctUntilChanged操作
- Take操作
- Skip操作
- StartWith操作
- Repeat操作
- Retry操作
- Collect操作
- Aggregate操作


(1)Filter操作

![](http://upload-images.jianshu.io/upload_images/1194012-f3fb1cb8c3aca987.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@"ab", @"hello", @"ppp", @"0"].rac_sequence.signal;
    
    RACSignal *signalB = [signalA filter:^BOOL(NSString *value) {
        return value.length > 2;
    }];
```


(2)Ignore / IgnoreValues操作

Ignore操作

![](http://upload-images.jianshu.io/upload_images/1194012-4646fa07e4ea4c97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```

    RACSignal *signalA = @[@1, @2, @1, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA filter:^BOOL(id value) {
        return ![@1 isEqual:value];
    }];
    
    RACSignal *signalC = [signalA ignore:@1];
```  

IgnoreValues操作

进行这个操作之后，新信号就没有值了，只剩下Error，Complete事件了。

![](http://upload-images.jianshu.io/upload_images/1194012-a951993bccbc6a0d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  

```

    RACSignal *signalA = @[@1, @2, @1, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA ignoreValues];
```

(3)DistinctUntilChanged操作
这个操作其实就是去重操作。

![](http://upload-images.jianshu.io/upload_images/1194012-dfacd25c58482b05.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@1,@1,@2,@2,@3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA distinctUntilChanged];
```  


(4)Take操作


![](http://upload-images.jianshu.io/upload_images/1194012-4c1a699dfe83bde4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA take:2];
```


(5)Skip操作



![](http://upload-images.jianshu.io/upload_images/1194012-d1779d3ae60f7baa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA skip:2];
```

take和Skip变种方法

```

- (RACSignal *)takeLast:(NSUInteger)count;
- (RACSignal *)takeUntilBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)takeWhileBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)skipUntilBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)skipWhileBlock:(BOOL (^)(id x))predicate;
``` 
predicate是传入一个要不要或者跳不跳过的规则。

(6)StartWith操作


![](http://upload-images.jianshu.io/upload_images/1194012-5eb4c8a859ad7de9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalA = @[@"ab", @"hello", @"app", @"1"].rac_sequence.signal;
    
RACSignal *signalB = [signalA startWith:@"Start"];
```

(7)Repeat操作



![](http://upload-images.jianshu.io/upload_images/1194012-3187c446c645f073.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalA = @[@"ab", @"hello"].rac_sequence.signal;
RACSignal *signalB = [signalA repeat];
```

(8)Retry操作

在一些网络请求中，如果我们把网络获取封装成一个信号,网络请求失败的时候，这时候就会抛出一个错误，网络不能连接。这个时候客户端可能会有重新连接的需求。


![](http://upload-images.jianshu.io/upload_images/1194012-5cf8576101a3875c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```
RACSignal *signalA = @[@"ab"].rac_sequence.signal;
RACSignal *signalB = [signalA retry:2];
```
Retry后面是重试的次数

这里会引出副作用操作

```

    RACSignal *signalA = @[@"ab", @"hello", @"ppp", @"0"].rac_sequence.signal;
    
    RACSignal *signalB = [signalA map:^id(id value) {
        // do some thing;
        return value;
    }];
    
    RACSignal *signalC = [signalA doNext:^(id x) {
        // do some thing;
    }];
```
副作用操作就是指的是不影响值，额外做的一些操作，比如说做一些动画，屏幕是打出一些字，弹框等等。
有以下一些便捷方法

```
- (RACSignal *)doError:(void (^)(NSError *error))block;
- (RACSignal *)doCompleted:(void (^)(void))block;
- (RACSignal *)initially:(void (^)(void))block;
- (RACSignal *)finally:(void (^)(void))block;
```  


(9)Collect操作


![](http://upload-images.jianshu.io/upload_images/1194012-f1b01ecbc516c887.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```
RACSignal *signalA = @[@"ab", @"hello", @"ppp", @"0"].rac_sequence.signal;
    
RACSignal *signalB = [signalA collect];
```

(10)Aggregate操作
这个函数其实是一个“折叠函数”

![](http://upload-images.jianshu.io/upload_images/1194012-995c1563638f089b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```
RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *signalB = [signalA aggregateWithStart:@0
                                              reduce:^id(NSNumber *running,
                                                         NSNumber *next) {
        return @(running.integerValue + next.integerValue);
    }];
``` 
值得注意的是，这个函数在终止的时候才有返回，不终止就一直不返回，如果遇到了Repeat信号，那就一直都不会返回了。aggregateWithStart有一个初始值。缺点是变化中拿不到值，只有最后才有值，对比值操作里面的Scan操作，还是Scan操作比较好。

```
 - (RACSignal *)aggregateWithStart:(id)start 
                   reduceWithIndex:(id (^)(id running, id next, NSUInteger index))reduceBlock;
 - (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory 
                                   reduce:(id (^)(id running, id next))reduceBlock;
``` 
这个是aggregate的变种函数。  


3.对时间间隔的操作
- 单位间隔时间信号
- Delay操作
- Throttle操作(节流操作)


(1)单位间隔时间信号

```

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;
+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway;
```
上面这2个方法，会返回以interval为时间间隔的时间信号。每隔interval就会发出一个信号。

(2)Delay操作

将源信号延迟1秒发送。
![](http://upload-images.jianshu.io/upload_images/1194012-736b439f164785be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalB = [signalA delay:1];
```

(3)Throttle操作(节流操作)


![](http://upload-images.jianshu.io/upload_images/1194012-122ce82b819396ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalB = [signalA throttle:2];
```
throttle后面跟着是间隔多少秒。如果间隔多少秒之后都没有值，就把之前监听到的值发出来。比如上述的例子，1发出来之后，间隔2秒，2秒内又来了2，继续监听2秒，2秒内又来了3，继续监听2秒，2秒内没有其他的值了，这时候就把3发送出来。如此道理，会发出5，6。

这个函数在我们开发中会用到的场景是，搜索操作。
用户拼命在搜索框内输入，这个时候如果每输入一次就网络请求一次，那又浪费流量，又没有必要。这个时候就可以用到这个throttle了。用户输完1秒内没有输入了，这个时候就可以去请求网络了。

```

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate;
- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;
```
这些是Throttle的变种函数。


####2.多个信号的组合
- 1.Concat组合操作
- 2.Merge组合操作
- 3.Zip组合操作
- 4.CombineLatest组合操作
- 5.Sample组合操作
- 6.TakeUntil / TakeUntilReplacement组合操作

1.Concat组合操作


![](http://upload-images.jianshu.io/upload_images/1194012-21fdb249e315d32d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```

    RACSignal *signalA = @[@1, @2, @3, @4, @5].rac_sequence.signal;
    RACSignal *signalB = @[@6, @7].rac_sequence.signal;
    
    RACSignal *signalC = [signalA concat:signalB];
```  
Concat工作原理：先订阅A，当A都结束了之后才会继续订阅B，这个时候可以看到，B早已结束了。这里也体现出了一个信号的定义和一个信号的订阅，是分离的。

如果A发生了错误，那就没有B什么事了。

![](http://upload-images.jianshu.io/upload_images/1194012-3930552684a844ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果B发生了一个错误，那么C就会传递这个错误。

![](http://upload-images.jianshu.io/upload_images/1194012-ed1fc826ac7dab4a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


2.Merge组合操作



![](http://upload-images.jianshu.io/upload_images/1194012-33c271814737d904.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```

    RACSignal *signalA = @[@1, @2, @3, @4, @5].rac_sequence.signal;
    RACSignal *signalB = @[@6, @7].rac_sequence.signal;
    
    RACSignal *signalC = [signalA merge:signalB];
    RACSignal *signalC = [RACSignal merge:@[signalA, signalB]];
    RACSignal *signalC = [RACSignal merge:RACTuplePack(signalA, signalB)];
 
```
如果SignalA，SignalB，是2个线程，那么SignalC会穿梭在2个线程中发送。如上图的例子，1，2，3，5发在线程A，4，6，7发在线程B里。

Merge在实际开发中的使用场景可能会出现如下场景：

```

RACSignal *appearSignal = [[self rac_signalForSelector:@selector(viewDidAppear:)]
                               mapReplace:@YES];
RACSignal *disappearSignal = [[self rac_signalForSelector:@selector(viewWillDisappear:)]
                                  mapReplace:@NO];
RACSignal *activeSignal = [RACSignal merge:@[appearSignal, disappearSignal]];
```
activeSignal信号得到的就是app是否在前台的信号。

3.Zip组合操作

![](http://upload-images.jianshu.io/upload_images/1194012-a04d8e0c02c57c7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



```
RACSignal *signalA = @[@1, @2, @3, @5].rac_sequence.signal;
RACSignal *signalB = @[@4, @6, @7].rac_sequence.signal;

RACSignal *signalC = [signalA zipWith:signalB];
RACSignal *signalC = [RACSignal zip:@[signalA, signalB]];
RACSignal *signalC = [RACSignal zip:RACTuplePack(signalA, signalB)];
```
注意图中的RACTuple的颜色。谁来控制终止由谁短来控制。发送的时机是谁更晚，就发送谁。(1，4)4更晚，就在4的时候发送RACTuple，(2，6)6更晚，6的时候发送RACTuple。(3，7)3更晚，3的时候发送RACTuple。


4.CombineLatest组合操作


![](http://upload-images.jianshu.io/upload_images/1194012-723e854a562298a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    RACSignal *signalB = @[@4, @6, @7].rac_sequence.signal;
    
     RACSignal *signalC = [signalA combineLatestWith:signalB];
     RACSignal *signalC = [RACSignal combineLatest:@[signalA, signalB]];
     RACSignal *signalC = [RACSignal combineLatest:RACTuplePack(signalA, signalB)];
```  
永远都结合最新的值作为新值返回。谁来控制终止由谁长来控制。

```
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock;
+ (RACSignal *)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock;
```
这分别是对应的combineLatest和Zip的语法糖似的便捷操作。都只不过是在后面加了一个Reduce。


5.Sample组合操作

![](http://upload-images.jianshu.io/upload_images/1194012-107e725a6813f7c3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```
RACSignal *signalC = [signalA sample:signalB];
```
谁早结束，那么结果信号就跟着谁一起结束。

![](http://upload-images.jianshu.io/upload_images/1194012-13e69a0e9ac4f21b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果遇到了错误，这个函数相当于快门。一样会把Error取得,并返回。


6.TakeUntil / TakeUntilReplacement组合操作



![](http://upload-images.jianshu.io/upload_images/1194012-e6868359cb0ae356.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```

RACSignal *signalC = [signalA takeUntil:signalB];
```
当出现B的时候，就终止A。

![](http://upload-images.jianshu.io/upload_images/1194012-3126818c4567512b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```

RACSignal *signalC = [signalA takeUntilReplacement:signalB];
```  

当出现B的时候，就终止A，后面再紧接着B。

