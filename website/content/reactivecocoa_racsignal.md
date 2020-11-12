+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
date = 2016-11-14T09:48:43Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/31_0_.png"
slug = "reactivecocoa_racsignal"
tags = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
title = "ReactiveCocoa 中 RACSignal 是如何发送信号的"

+++


#### 前言

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa)是一个(第一个？)将函数响应式编程范例带入Objective-C的开源库。ReactiveCocoa是由[Josh Abernathy](https://github.com/joshaber)和[Justin Spahr-Summers](https://github.com/jspahrsummers) 两位大神在对[GitHub for Mac](http://mac.github.com/)的开发过程中编写的。[Justin Spahr-Summers](https://github.com/jspahrsummers) 大神在2011年11月13号下午12点35分进行的第一次提交，直到2013年2月13日上午3点05分发布了其[1.0 release](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v1.0.0)，达到了第一个重要里程碑。ReactiveCocoa社区也非常活跃，目前最新版已经完成了ReactiveCocoa 5.0.0-alpha.3，目前在5.0.0-alpha.4开发中。

ReactiveCocoa v2.5 是公认的Objective-C最稳定的版本，因此被广大的以OC为主要语言的客户端选中使用。ReactiveCocoa v3.x主要是基于Swift 1.2的版本，而ReactiveCocoa v4.x 主要基于Swift 2.x，ReactiveCocoa 5.0就全面支持Swift 3.0，也许还有以后的Swift 4.0。接下来几篇博客先以ReactiveCocoa v2.5版本为例子，分析一下OC版的RAC具体实现（也许分析完了RAC 5.0就到来了）。也算是写在ReactiveCocoa 5.0正式版到来前夕的祝福吧。




#### 目录
- 1.什么是ReactiveCocoa？
- 2.RAC中的核心RACSignal发送与订阅流程
- 3.RACSignal操作的核心bind实现
- 4.RACSignal基本操作concat和zipWith实现
- 5.最后

#### 一. 什么是ReactiveCocoa？

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa)（其简称为RAC）是由[Github](https://github.com/blog/1107-reactivecocoa-for-a-better-world) 开源的一个应用于iOS和OS X开发的新框架。RAC具有函数式编程(FP)和响应式编程(RP)的特性。它主要吸取了.Net的 [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609)的设计和实现。

ReactiveCocoa 的宗旨是Streams of values over time ，随着时间变化而不断流动的数据流。

ReactiveCocoa 主要解决了以下这些问题：

- UI数据绑定

UI控件通常需要绑定一个事件，RAC可以很方便的绑定任何数据流到控件上。

- 用户交互事件绑定

RAC为可交互的UI控件提供了一系列能发送Signal信号的方法。这些数据流会在用户交互中相互传递。

- 解决状态以及状态之间依赖过多的问题

有了RAC的绑定之后，可以不用在关心各种复杂的状态，isSelect，isFinish……也解决了这些状态在后期很难维护的问题。

- 消息传递机制的大统一

OC中编程原来消息传递机制有以下几种：Delegate，Block Callback，Target-Action，Timers，KVO，objc上有一篇关于OC中这5种消息传递方式改如何选择的文章[Communication Patterns](https://www.objccn.io/issue-7-4/)，推荐大家阅读。现在有了RAC之后，以上这5种方式都可以统一用RAC来处理。

#### 二. RAC中的核心RACSignal

ReactiveCocoa 中最核心的概念之一就是信号RACStream。RACStream中有两个子类——RACSignal 和 RACSequence。本文先来分析RACSignal。


我们会经常看到以下的代码：

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


这是一个RACSignal被订阅的完整过程。被订阅的过程中，究竟发生了什么？



```objectivec

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
 return [RACDynamicSignal createSignal:didSubscribe];
}

```


RACSignal调用createSignal的时候，会调用RACDynamicSignal的createSignal的方法。


![](https://img.halfrost.com/Blog/ArticleImage/31_1.png)




RACDynamicSignal是RACSignal的子类。createSignal后面的参数是一个block。

```objectivec

(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe

```

block的返回值是RACDisposable类型，block名叫didSubscribe。block的唯一一个参数是id<RACSubscriber>类型的subscriber，这个subscriber是必须遵循RACSubscriber协议的。

RACSubscriber是一个协议，其下有以下4个协议方法：

```objectivec

@protocol RACSubscriber <NSObject>
@required

- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)disposable;

@end

```

所以新建Signal的任务就全部落在了RACSignal的子类RACDynamicSignal上了。


```objectivec


@interface RACDynamicSignal ()
// The block to invoke for each subscriber.
@property (nonatomic, copy, readonly) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);
@end

```

RACDynamicSignal这个类很简单，里面就保存了一个名字叫didSubscribe的block。

```objectivec


+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
     RACDynamicSignal *signal = [[self alloc] init];
     signal->_didSubscribe = [didSubscribe copy];
     return [signal setNameWithFormat:@"+createSignal:"];
}

```

这个方法中新建了一个RACDynamicSignal对象signal，并把传进来的didSubscribe这个block保存进刚刚新建对象signal里面的didSubscribe属性中。最后再给signal命名\+createSignal:。

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

setNameWithFormat是RACStream里面的方法，由于RACDynamicSignal继承自RACSignal，所以它也能调用这个方法。


![](https://img.halfrost.com/Blog/ArticleImage/31_2.png)



RACSignal的block就这样被保存起来了，那什么时候会被执行呢？

![](https://img.halfrost.com/Blog/ArticleImage/31_3.png)



block闭包在订阅的时候才会被“释放”出来。

RACSignal调用subscribeNext方法，返回一个RACDisposable。

```objectivec

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
   NSCParameterAssert(nextBlock != NULL);
   NSCParameterAssert(errorBlock != NULL);
   NSCParameterAssert(completedBlock != NULL);
 
   RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
   return [self subscribe:o];
}


```

在这个方法中会新建一个RACSubscriber对象，并传入nextBlock，errorBlock，completedBlock。


```objectivec

@interface RACSubscriber ()

// These callbacks should only be accessed while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

@end


```

RACSubscriber这个类很简单，里面只有4个属性，分别是nextBlock，errorBlock，completedBlock和一个RACCompoundDisposable信号。


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



subscriberWithNext方法把传入的3个block都保存分别保存到自己对应的block中。


RACSignal调用subscribeNext方法，最后return的时候，会调用[self subscribe:o]，这里实际是调用了RACDynamicSignal类里面的subscribe方法。

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

RACDisposable有3个子类，其中一个就是RACCompoundDisposable。


![](https://img.halfrost.com/Blog/ArticleImage/31_5.png)


```objectivec


@interface RACCompoundDisposable : RACDisposable
+ (instancetype)compoundDisposable;
+ (instancetype)compoundDisposableWithDisposables:(NSArray *)disposables;
- (void)addDisposable:(RACDisposable *)disposable;
- (void)removeDisposable:(RACDisposable *)disposable;
@end

```

RACCompoundDisposable虽然是RACDisposable的子类，但是它里面可以加入多个RACDisposable对象，在必要的时候可以一口气都调用dispose方法来销毁信号。当RACCompoundDisposable对象被dispose的时候，也会自动dispose容器内的所有RACDisposable对象。

RACPassthroughSubscriber是一个私有的类。

```objectivec

@interface RACPassthroughSubscriber : NSObject <RACSubscriber>
@property (nonatomic, strong, readonly) id<RACSubscriber> innerSubscriber;
@property (nonatomic, unsafe_unretained, readonly) RACSignal *signal;
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;
- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber signal:(RACSignal *)signal disposable:(RACCompoundDisposable *)disposable;
@end

```

RACPassthroughSubscriber类就只有这一个方法。目的就是为了把所有的信号事件从一个订阅者subscriber传递给另一个还没有disposed的订阅者subscriber。

RACPassthroughSubscriber类中保存了3个非常重要的对象，RACSubscriber，RACSignal，RACCompoundDisposable。RACSubscriber是待转发的信号的订阅者subscriber。RACCompoundDisposable是订阅者的销毁对象，一旦它被disposed了，innerSubscriber就再也接受不到事件流了。

这里需要注意的是内部还保存了一个RACSignal，并且它的属性是unsafe\_unretained。这里和其他两个属性有区别， 其他两个属性都是strong的。这里之所以不是weak，是因为引用RACSignal仅仅只是一个DTrace probes动态跟踪技术的探针。如果设置成weak，会造成没必要的性能损失。所以这里仅仅是unsafe\_unretained就够了。


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

回到RACDynamicSignal类里面的subscribe方法中，现在新建好了RACCompoundDisposable和RACPassthroughSubscriber对象了。

```objectivec

 if (self.didSubscribe != NULL) {
  RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
   RACDisposable *innerDisposable = self.didSubscribe(subscriber);
   [disposable addDisposable:innerDisposable];
  }];

  [disposable addDisposable:schedulingDisposable];
 }


```


RACScheduler.subscriptionScheduler是一个全局的单例。

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

RACScheduler再继续调用schedule方法。

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

在取currentScheduler的过程中，会判断currentScheduler是否存在，和是否在主线程中。如果都没有，那么就会调用后台backgroundScheduler去执行schedule。

schedule的入参就是一个block，执行schedule的时候会去执行block。也就是会去执行：

```objectivec

RACDisposable *innerDisposable = self.didSubscribe(subscriber);
   [disposable addDisposable:innerDisposable];

```

这两句关键的语句。之前信号里面保存的block就会在此处被“释放”执行。self.didSubscribe(subscriber)这一句就执行了信号保存的didSubscribe闭包。


在didSubscribe闭包中有sendNext，sendError，sendCompleted，执行这些语句会分别调用RACPassthroughSubscriber里面对应的方法。

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

这个时候的订阅者是RACPassthroughSubscriber。RACPassthroughSubscriber里面的innerSubscriber才是最终的实际订阅者，RACPassthroughSubscriber会把值再继续传递给innerSubscriber。

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

innerSubscriber是RACSubscriber，调用sendNext的时候会先把自己的self.next闭包copy一份，再调用，而且整个过程还是线程安全的，用@synchronized保护着。最终订阅者的闭包在这里被调用。

sendError和sendCompleted也都是同理。

总结一下：

![](https://img.halfrost.com/Blog/ArticleImage/31_6.png)




1. RACSignal调用subscribeNext方法，新建一个RACSubscriber。
2. 新建的RACSubscriber会copy，nextBlock，errorBlock，completedBlock存在自己的属性变量中。
3. RACSignal的子类RACDynamicSignal调用subscribe方法。
4. 新建RACCompoundDisposable和RACPassthroughSubscriber对象。RACPassthroughSubscriber分别保存对RACSignal，RACSubscriber，RACCompoundDisposable的引用，注意对RACSignal的引用是unsafe\_unretained的。
5. RACDynamicSignal调用didSubscribe闭包。先调用RACPassthroughSubscriber的相应的sendNext，sendError，sendCompleted方法。
6. RACPassthroughSubscriber再去调用self.innerSubscriber，即RACSubscriber的nextBlock，errorBlock，completedBlock。注意这里调用同样是先copy一份，再调用闭包执行。


#### 三. RACSignal操作的核心bind实现


![](https://img.halfrost.com/Blog/ArticleImage/31_7.png)





在RACSignal的源码里面包含了两个基本操作，concat和zipWith。不过在分析这两个操作之前，先来分析一下更加核心的一个函数，bind操作。

先来说说bind函数的作用：
1. 会订阅原始的信号。
2. 任何时刻原始信号发送一个值，都会绑定的block转换一次。
3. 一旦绑定的block转换了值变成信号，就立即订阅，并把值发给订阅者subscriber。
4. 一旦绑定的block要终止绑定，原始的信号就complete。
5. 当所有的信号都complete，发送completed信号给订阅者subscriber。
6. 如果中途信号出现了任何error，都要把这个错误发送给subscriber


```objectivec

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block {
 NSCParameterAssert(block != NULL);

 return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
  RACStreamBindBlock bindingBlock = block();

  NSMutableArray *signals = [NSMutableArray arrayWithObject:self];

  RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

  void (^completeSignal)(RACSignal *, RACDisposable *) = ^(RACSignal *signal, RACDisposable *finishedDisposable) { /*这里暂时省略*/ };
  void (^addSignal)(RACSignal *) = ^(RACSignal *signal) { /*这里暂时省略*/ };

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

为了弄清楚bind函数究竟做了什么，写出测试代码：

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

由于前面第一章节详细讲解了RACSignal的创建和订阅的全过程，这个也为了方法讲解，创建RACDynamicSignal，RACCompoundDisposable，RACPassthroughSubscriber这些都略过，这里着重分析一下bind的各个闭包传递创建和订阅的过程。

为了防止接下来的分析会让读者看晕，这里先把要用到的block进行编号。

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
先创建信号signal，didSubscribe把block1 copy保存起来。

当信号调用bind进行绑定，会调用block5，didSubscribe把block6 copy保存起来。

当订阅者开始订阅bindSignal的时候，流程如下：  
1. bindSignal执行didSubscribe的block，即执行block6。
2. 在block6 的第一句代码，就是调用RACStreamBindBlock bindingBlock = block()，这里的block是外面传进来的block2，于是开始调用block2。执行完block2，会返回一个RACStreamBindBlock的对象。
3. 由于是signal调用的bind函数，所以bind函数里面的self就是signal，在bind内部订阅了signal的信号。subscribeNext所以会执行block1。
4. 执行block1，sendNext调用订阅者subscriber的nextBlock，于是开始执行block10。
5. block10中会先调用bindingBlock，这个是之前调用block2的返回值，这个RACStreamBindBlock对象里面保存的是block3。所以开始调用block3。
6. 在block3中入参是一个value，这个value是signal中sendNext中发出来的value的值，在block3中可以对value进行变换，变换完成后，返回一个新的信号signal'。
7. 如果返回的signal'为空，则会调用completeSignal，即调用block7。block7中会发送sendCompleted。如果返回的signal'不为空，则会调用addSignal，即调用block8。block8中会继续订阅signal'。由于signal'是外面bind函数的返回值，返回值的信号是RACReturnSignal类型的，所以一订阅就会sendNext，就会执行block9。
8. block9 中会sendNext，这里的subscriber是block6的入参，于是对subscriber调用sendNext，会调用到bindSignal的订阅者的block4中。
9. block9 中执行完sendNext，还会调用sendCompleted。这里的是在执行block9里面的completed闭包。completeSignal(signal, selfDisposable);然后又会调用completeSignal，即block7。
10. 执行完block7，就完成了一次从signal 发送信号sendNext的全过程。


bind整个流程就完成了。


#### 四. RACSignal基本操作concat和zipWith实现

接下来再来分析RACSignal中另外2个基本操作。

##### 1. concat


![](https://img.halfrost.com/Blog/ArticleImage/31_8.png)







写出测试代码：

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

concat操作就是把两个信号合并起来。注意合并有先后顺序。

![](https://img.halfrost.com/Blog/ArticleImage/31_9.png)


```objectivec

- (RACSignal *)concat:(RACSignal *)signal {
   return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

    RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
     // 发送第一个信号的值
     [subscriber sendNext:x];
    } error:^(NSError *error) {
     [subscriber sendError:error];
    } completed:^{
     // 订阅第二个信号
     RACDisposable *concattedDisposable = [signal subscribe:subscriber];
     serialDisposable.disposable = concattedDisposable;
  }];

    serialDisposable.disposable = sourceDisposable;
    return serialDisposable;
 }] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

```


合并前，signal和signals分别都把各自的didSubscribe保存copy起来。
合并之后，合并之后新的信号的didSubscribe会把block保存copy起来。

当合并之后的信号被订阅的时候：

1. 调用新的合并信号的didSubscribe。
2. 由于是第一个信号调用的concat方法，所以block中的self是前一个信号signal。合并信号的didSubscribe会先订阅signal。
3. 由于订阅了signal，于是开始执行signal的didSubscribe，sendNext，sendError。
4. 当前一个信号signal发送sendCompleted之后，就会开始订阅后一个信号signals，调用signals的didSubscribe。
5. 由于订阅了后一个信号，于是后一个信号signals开始发送sendNext，sendError，sendCompleted。

这样两个信号就前后有序的拼接到了一起。

这里有二点需要注意的是：  

1. 只有当第一个信号完成之后才能收到第二个信号的值，因为第二个信号是在第一个信号completed的闭包里面订阅的，所以第一个信号不结束，第二个信号也不会被订阅。
2. 两个信号concat在一起之后，新的信号的结束信号在第二个信号结束的时候才结束。看上图描述，新的信号的发送长度等于前面两个信号长度之和，concat之后的新信号的结束信号也就是第二个信号的结束信号。

concat是有序的组合，第一个信号完成之后才发送第二个信号。


##### 2. zipWith


![](https://img.halfrost.com/Blog/ArticleImage/31_10.png)





写出测试代码：

```objectivec


    RACSignal *concatSignal = [signal zipWith:signals];
    
    [concatSignal subscribeNext:^(id x) {
        NSLog(@"subscribe value = %@", x);
    }];


```

![](https://img.halfrost.com/Blog/ArticleImage/31_11.png)




源码如下：

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
                
                // 如果任意一个信号完成并且数组里面空了，就整个信号算完成
                if (selfEmpty || otherEmpty) [subscriber sendCompleted];
            }
        };
        
        void (^sendNext)(void) = ^{
            @synchronized (selfValues) {
                
                // 数组里面的空了就返回。
                if (selfValues.count == 0) return;
                if (otherValues.count == 0) return;
                
                // 每次都取出两个数组里面的第0位的值，打包成元组
                RACTuple *tuple = RACTuplePack(selfValues[0], otherValues[0]);
                [selfValues removeObjectAtIndex:0];
                [otherValues removeObjectAtIndex:0];
                
                // 把元组发送出去
                [subscriber sendNext:tuple];
                sendCompletedIfNecessary();
            }
        };
        
        // 订阅第一个信号
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
            @synchronized (selfValues) {
                
                // 把第一个信号的值加入到数组中
                [selfValues addObject:x ?: RACTupleNil.tupleNil];
                sendNext();
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            @synchronized (selfValues) {
                
                // 订阅完成时判断是否要发送完成信号
                selfCompleted = YES;
                sendCompletedIfNecessary();
            }
        }];
        
        // 订阅第二个信号
        RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
            @synchronized (selfValues) {
                
                // 把第二个信号加入到数组中
                [otherValues addObject:x ?: RACTupleNil.tupleNil];
                sendNext();
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            @synchronized (selfValues) {
                
                // 订阅完成时判断是否要发送完成信号
                otherCompleted = YES;
                sendCompletedIfNecessary();
            }
        }];
        
        return [RACDisposable disposableWithBlock:^{
            
            // 销毁两个信号
            [selfDisposable dispose];
            [otherDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -zipWith: %@", self.name, signal];
}

```


当把两个信号通过zipWith之后，就像上面的那张图一样，拉链的两边被中间的拉索拉到了一起。既然是拉链，那么一一的位置是有对应的，上面的拉链第一个位置只能对着下面拉链第一个位置，这样拉链才能拉到一起去。

具体实现：

zipWith里面有两个数组，分别会存储两个信号的值。

1. 一旦订阅了zipWith之后的信号，就开始执行didSubscribe闭包。
2. 在闭包中会先订阅第一个信号。这里假设第一个信号比第二个信号先发出一个值。第一个信号发出来的每一个值都会被加入到第一个数组中保存起来，然后调用sendNext( )闭包。在sendNext( )闭包中，会先判断两个数组里面是否都为空，如果有一个数组里面是空的，就return。由于第二个信号还没有发送值，即第二个信号的数组里面是空的，所以这里第一个值发送不出来。于是第一个信号被订阅之后，发送的值存储到了第一个数组里面了，没有发出去。
3. 第二个信号的值紧接着发出来了，第二个信号每发送一次值，也会存储到第二个数组中，但是这个时候再调用sendNext( )闭包的时候，不会再return了，因为两个数组里面都有值了，两个数组的第0号位置都有一个值了。有值以后就打包成元组RACTuple发送出去。并清空两个数组0号位置存储的值。
4. 以后两个信号每次发送一个，就先存储在数组中，只要有“配对”的另一个信号，就一起打包成元组RACTuple发送出去。从图中也可以看出，zipWith之后的新信号，每个信号的发送时刻是等于两个信号最晚发出信号的时刻。
5. 新信号的完成时间，是当两者任意一个信号完成并且数组里面为空，就算完成了。所以最后第一个信号发送的5的那个值就被丢弃了。

第一个信号依次发送的1，2，3，4的值和第二个信号依次发送的A，B，C，D的值，一一的合在了一起，就像拉链把他们拉在一起。由于5没法配对，所以拉链也拉不上了。


#### 五. 最后

本来这篇文章想把Map，combineLatest，flattenMap，flatten这些也一起分析了，但是后来看到RACSingnal的操作实在有点多，于是按照源码的文件分开了，这里先把RACSignal文件里面的操作都分析完了。RACSignal文件里面的操作主要就bind，concat和zipWith三个操作。下一篇再分析分析RACSignal\+Operations文件里面的所有操作。

请大家多多指教。

