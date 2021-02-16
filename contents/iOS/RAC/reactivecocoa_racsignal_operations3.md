# ReactiveCocoa 中 RACSignal 所有变换操作底层实现分析(下)

![](https://img.halfrost.com/Blog/ArticleTitleImage/35_0_.png)



### 前言


紧接着[上篇](https://halfrost.com/reactivecocoa_racsignal_operations2/)的源码实现分析，继续分析RACSignal的变换操作的底层实现。



### 目录

- 1.高阶信号操作
- 2.同步操作
- 3.副作用操作
- 4.多线程操作
- 5.其他操作


### 一. 高阶信号操作


![](https://img.halfrost.com/Blog/ArticleImage/35_1.png)




高阶操作大部分的操作是针对高阶信号的，也就是说信号里面发送的值还是一个信号或者是一个高阶信号。可以类比数组，这里就是多维数组，数组里面还是套的数组。



#### 1. flattenMap: (在父类RACStream中定义的)

flattenMap:在整个RAC中具有很重要的地位，很多信号变换都是可以用flattenMap:来实现的。

map:，flatten，filter，sequenceMany:这4个操作都是用flattenMap:来实现的。然而其他变换操作实现里面用到map:，flatten，filter又有很多。


回顾一下map:的实现：

```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```

map:的操作其实就是直接原信号进行的 flattenMap:的操作，变换出来的新的信号的值是block(value)。


flatten的实现接下去会具体分析，这里先略过。

filter的实现：

```objectivec

- (instancetype)filter:(BOOL (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^ id (id value) {
        block(value) ? return [class return:value] :  return class.empty;
    }] setNameWithFormat:@"[%@] -filter:", self.name];
}

```


filter的实现和map:有点类似，也是对原信号进行 flattenMap:的操作，只不过block(value)不是作为返回值，而是作为判断条件，满足这个闭包的条件，变换出来的新的信号返回值就是value，不满足的就返回empty信号


接下去要分析的高阶操作里面，switchToLatest，try:，tryMap:的实现中也将会使用到flattenMap:。

flattenMap:的源码实现：

```objectivec

- (instancetype)flattenMap:(RACStream * (^)(id value))block {
    Class class = self.class;
    
    return [[self bind:^{
        return ^(id value, BOOL *stop) {
            id stream = block(value) ?: [class empty];
            NSCAssert([stream isKindOfClass:RACStream.class], @"Value returned from -flattenMap: is not a stream: %@", stream);
            
            return stream;
        };
    }] setNameWithFormat:@"[%@] -flattenMap:", self.name];
}


```

flattenMap:的实现是调用了bind函数，对原信号进行变换，并返回block(value)的新信号。关于bind操作的具体流程[这篇文章](https://halfrost.com/reactivecocoa_racsignal/)里面已经分析过了，这里不再赘述。


从flattenMap:的源码可以看到，它是可以支持类似Promise的串行异步操作的，并且flattenMap:是满足Monad中bind部分定义的。flattenMap:没法去实现takeUntil:和take:的操作。

然而，bind操作可以实现take:的操作，bind是完全满足Monad中bind部分定义的。


#### 2. flatten (在父类RACStream中定义的)


flatten的源码实现：

```objectivec

- (instancetype)flatten {
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self flattenMap:^(id value) {
        return value;
    }] setNameWithFormat:@"[%@] -flatten", self.name];
}


```

flatten操作必须是对高阶信号进行操作，如果信号里面不是信号，即不是高阶信号，那么就会崩溃。崩溃信息如下：

```objectivec

*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Value returned from -flattenMap: is not a stream

```

所以flatten是对高阶信号进行的降阶操作。高阶信号每发送一次信号，经过flatten变换，由于flattenMap:操作之后，返回的新的信号的每个值就是原信号中每个信号的值。

![](https://img.halfrost.com/Blog/ArticleImage/35_2.png)





如果对信号A，信号B，信号C进行merge:操作，可以达到和flatten一样的效果。

```objectivec

    [RACSignal merge:@[signalA,signalB,signalC]];

```

merge:操作在[上篇文章](https://halfrost.com/reactivecocoa_racsignal_operations2/)分析过，再来复习一下：


```objectivec

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
    NSMutableArray *copiedSignals = [[NSMutableArray alloc] init];
    for (RACSignal *signal in signals) {
        [copiedSignals addObject:signal];
    }
    
    return [[[RACSignal
              createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
                  for (RACSignal *signal in copiedSignals) {
                      [subscriber sendNext:signal];
                  }
                  
                  [subscriber sendCompleted];
                  return nil;
              }]
             flatten]
            setNameWithFormat:@"+merge: %@", copiedSignals];
}

```

现在在回来看这段代码，copiedSignals虽然是一个NSMutableArray，但是它近似合成了一个上图中的高阶信号。然后这些信号们每发送出来一个信号就发给订阅者。整个操作如flatten的字面意思一样，压平。


![](https://img.halfrost.com/Blog/ArticleImage/35_3.png)





另外，在ReactiveCocoa v2.5中，flatten默认就是flattenMap:这一种操作。



```objectivec

public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
    switch strategy {
    case .merge:
        return self.merge()
        
    case .concat:
        return self.concat()
        
    case .latest:
        return self.switchToLatest()
    }
}

```

而在ReactiveCocoa v3.x，v4.x，v5.x中，flatten的操作是可以选择3种操作选择的。merge，concat，switchToLatest。

#### 3. flatten:

flatten:操作也必须是对高阶信号进行操作，如果信号里面不是信号，即不是高阶信号，那么就会崩溃。



flatten:的实现比较复杂，一步步的来分析：

```objectivec

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *compoundDisposable = [[RACCompoundDisposable alloc] init];
        NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];
        NSMutableArray *queuedSignals = [NSMutableArray array];

        __block BOOL selfCompleted = NO;
        __block void (^subscribeToSignal)(RACSignal *);
        __weak __block void (^recur)(RACSignal *);
        recur = subscribeToSignal = ^(RACSignal *signal) { // 暂时省略};

        void (^completeIfAllowed)(void) = ^{ // 暂时省略};
        
        [compoundDisposable addDisposable:[self subscribeNext:^(RACSignal *signal) {
            if (signal == nil) return;
            
            NSCAssert([signal isKindOfClass:RACSignal.class], @"Expected a RACSignal, got %@", signal);
            
            @synchronized (subscriber) {
                if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) {
                    [queuedSignals addObject:signal];
                    return;
                }
            }
            
            subscribeToSignal(signal);
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            @synchronized (subscriber) {
                selfCompleted = YES;
                completeIfAllowed();
            }
        }]];
        
        return compoundDisposable;
    }] setNameWithFormat:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
}


```

先来解释一些变量，数组的作用

activeDisposables里面装的是当前正在订阅的订阅者们的disposables信号。

queuedSignals里面装的是被暂时缓存起来的信号，它们等待被订阅。

selfCompleted表示高阶信号是否Completed。

subscribeToSignal闭包的作用是订阅所给的信号。这个闭包的入参参数就是一个信号，在闭包内部订阅这个信号，并进行一些操作。

recur是对subscribeToSignal闭包的一个弱引用，防止strong-weak循环引用，在下面会分析subscribeToSignal闭包，就会明白为什么recur要用weak修饰了。


completeIfAllowed的作用是在所有信号都发送完毕的时候，通知订阅者，给订阅者发送completed。

入参maxConcurrent的意思是最大可容纳同时被订阅的信号个数。

再来详细分析一下具体订阅的过程。

flatten:的内部，订阅高阶信号发出来的信号，这部分的代码比较简单：

```objectivec


    [self subscribeNext:^(RACSignal *signal) {
        if (signal == nil) return;
    
        NSCAssert([signal isKindOfClass:RACSignal.class], @"Expected a RACSignal, got %@", signal);
    
        @synchronized (subscriber) {
            // 1
            if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) {
                [queuedSignals addObject:signal];
                return;
            }
        }
        // 2
        subscribeToSignal(signal);
    } error:^(NSError *error) {
        [subscriber sendError:error];
    } completed:^{
        @synchronized (subscriber) {
            selfCompleted = YES;
            // 3
            completeIfAllowed();
        }
    }]];

```


1. 如果当前最大可容纳信号的个数 > 0 ，且，activeDisposables数组里面已经装满到最大可容纳信号的个数，不能再装新的信号了。那么就把当前的信号缓存到queuedSignals数组中。

2. 直到activeDisposables数组里面有空的位子可以加入新的信号，那么就调用subscribeToSignal( )闭包，开始订阅这个新的信号。

3. 最后完成的时候标记变量selfCompleted为YES，并且调用completeIfAllowed( )闭包。

```objectivec

void (^completeIfAllowed)(void) = ^{
    if (selfCompleted && activeDisposables.count == 0) {
        [subscriber sendCompleted];
        subscribeToSignal = nil;
    }
};


```


当selfCompleted = YES 并且activeDisposables数组里面的信号都发送完毕，没有可以发送的信号了，即activeDisposables.count = 0，那么就给订阅者sendCompleted。这里值得一提的是，还需要把subscribeToSignal手动置为nil。因为在subscribeToSignal闭包中强引用了completeIfAllowed闭包，防止completeIfAllowed闭包被提早的销毁掉了。所以在completeIfAllowed闭包执行完毕的时候，需要再把subscribeToSignal闭包置为nil。


那么接下来需要看的重点就是subscribeToSignal( )闭包。

```objectivec

    recur = subscribeToSignal = ^(RACSignal *signal) {
        RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];
        // 1
        @synchronized (subscriber) {
            [compoundDisposable addDisposable:serialDisposable];
            [activeDisposables addObject:serialDisposable];
        }
    
        serialDisposable.disposable = [signal subscribeNext:^(id x) {
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            // 2
            __strong void (^subscribeToSignal)(RACSignal *) = recur;
            RACSignal *nextSignal;
            // 3
            @synchronized (subscriber) {
                [compoundDisposable removeDisposable:serialDisposable];
                [activeDisposables removeObjectIdenticalTo:serialDisposable];
                // 4
                if (queuedSignals.count == 0) {
                    completeIfAllowed();
                    return;
                }
                // 5
                nextSignal = queuedSignals[0];
                [queuedSignals removeObjectAtIndex:0];
            }
            // 6
            subscribeToSignal(nextSignal);
        }];
    };



```

1. activeDisposables先添加当前高阶信号发出来的信号的Disposable( 也就是入参信号的Disposable)
2. 这里会对recur进行__strong，因为下面第6步会用到subscribeToSignal( )闭包，同样也是为了防止出现循环引用。
3. 订阅入参信号，给订阅者发送信号。当发送完毕后，activeDisposables中移除它对应的Disposable。
4. 如果当前缓存的queuedSignals数组里面没有缓存的信号，那么就调用completeIfAllowed( )闭包。
5. 如果当前缓存的queuedSignals数组里面有缓存的信号，那么就取出第0个信号，并在queuedSignals数组移除它。
6. 把第4步取出的信号继续订阅，继续调用subscribeToSignal( )闭包。


总结一下：高阶信号每发送一个信号值，判断activeDisposables数组装的个数是否已经超过了maxConcurrent。如果装不下了就缓存进queuedSignals数组中。如果还可以装的下就开始调用subscribeToSignal( )闭包，订阅当前信号。

每发送完一个信号就判断缓存数组queuedSignals的个数，如果缓存数组里面已经没有信号了，那么就结束原来高阶信号的发送。如果缓存数组里面还有信号就继续订阅。如此循环，直到原高阶信号所有的信号都发送完毕。


整个flatten:的执行流程都分析清楚了，最后，关于入参maxConcurrent进行更进一步的解读。

回看上面flatten:的实现中有这样一句话:

```objectivec

if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) 

```

那么maxConcurrent的值域就是最终决定flatten:表现行为。

如果maxConcurrent < 0，会发生什么？程序会崩溃。因为在源码中有这样一行的初始化的代码:

```objectivec

NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];

```

activeDisposables在初始化的时候会初始化一个大小为maxConcurrent的NSMutableArray。如果maxConcurrent < 0，那么这里初始化就会崩溃。


如果maxConcurrent = 0，会发生什么？那么flatten:就退化成flatten了。

![](https://img.halfrost.com/Blog/ArticleImage/35_4.png)



如果maxConcurrent = 1，会发生什么？那么flatten:就退化成concat了。

![](https://img.halfrost.com/Blog/ArticleImage/35_5.png)


如果maxConcurrent > 1，会发生什么？由于至今还没有遇到能用到maxConcurrent > 1的需求情况，所以这里暂时不展示图解了。maxConcurrent > 1之后，flatten的行为还依照高阶信号的个数和maxConcurrent的关系。如果高阶信号的个数<=maxConcurrent的值，那么flatten:又退化成flatten了。如果高阶信号的个数>maxConcurrent的值，那么多的信号就会进入queuedSignals缓存数组。


#### 4. concat


这里的concat实现是在RACSignal里面定义的。

```objectivec

- (RACSignal *)concat {
    return [[self flatten:1] setNameWithFormat:@"[%@] -concat", self.name];
}

```

一看源码就知道了，concat其实就是flatten:1。


当然在RACSignal中定义了concat:方法，这个方法在之前的[文章](https://halfrost.com/reactivecocoa_racsignal/)已经分析过了，这里回顾对比一下：

```objectivec

- (RACSignal *)concat:(RACSignal *)signal {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			RACDisposable *concattedDisposable = [signal subscribe:subscriber];
			serialDisposable.disposable = concattedDisposable;
		}];

		serialDisposable.disposable = sourceDisposable;
		return serialDisposable;
	}] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/35_6.png)



经过对比可以发现，虽然最终变换出来的结果类似，但是针对的信号的对象是不同的，concat是针对高阶信号进行降阶操作。concat:是把两个信号连接起来的操作。如果把高阶信号按照时间轴，从左往右，依次把每个信号都concat:连接起来，那么结果就是concat。


#### 5. switchToLatest


```objectivec

- (RACSignal *)switchToLatest {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACMulticastConnection *connection = [self publish];
        
        RACDisposable *subscriptionDisposable = [[connection.signal
                                                  flattenMap:^(RACSignal *x) {
                                                      NSCAssert(x == nil || [x isKindOfClass:RACSignal.class], @"-switchToLatest requires that the source signal (%@) send signals. Instead we got: %@", self, x);
                                                      return [x takeUntil:[connection.signal concat:[RACSignal never]]];
                                                  }]
                                                 subscribe:subscriber];
        
        RACDisposable *connectionDisposable = [connection connect];
        return [RACDisposable disposableWithBlock:^{
            [subscriptionDisposable dispose];
            [connectionDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -switchToLatest", self.name];
}

```

switchToLatest这个操作只能用在高阶信号上，如果原信号里面有不是信号的值，那么就会崩溃，崩溃信息如下：

```vim

***** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: '-switchToLatest requires that the source signal (<RACDynamicSignal: 0x608000038ec0> name: ) send signals.

```


在switchToLatest操作中，先把原信号转换成热信号，connection.signal就是RACSubject类型的。对RACSubject进行flattenMap:变换。在flattenMap:变换中，connection.signal会先concat:一个never信号。这里concat:一个never信号的原因是为了内部的信号过早的结束而导致订阅者收到complete信号。

flattenMap:变换中x也是一个信号，对x进行takeUntil:变换，效果就是下一个信号到来之前，x会一直发送信号，一旦下一个信号到来，x就会被取消订阅，开始订阅新的信号。


![](https://img.halfrost.com/Blog/ArticleImage/35_7.png)


一个高阶信号经过switchToLatest降阶操作之后，能得到上图中的信号。


#### 6. switch: cases: default:


switch: cases: default:源码实现如下:

```objectivec


+ (RACSignal *)switch:(RACSignal *)signal cases:(NSDictionary *)cases default:(RACSignal *)defaultSignal {
    NSCParameterAssert(signal != nil);
    NSCParameterAssert(cases != nil);
    
    for (id key in cases) {
        id value __attribute__((unused)) = cases[key];
        NSCAssert([value isKindOfClass:RACSignal.class], @"Expected all cases to be RACSignals, %@ isn't", value);
    }
    
    NSDictionary *copy = [cases copy];
    
    return [[[signal
              map:^(id key) {
                  if (key == nil) key = RACTupleNil.tupleNil;
                  
                  RACSignal *signal = copy[key] ?: defaultSignal;
                  if (signal == nil) {
                      NSString *description = [NSString stringWithFormat:NSLocalizedString(@"No matching signal found for value %@", @""), key];
                      return [RACSignal error:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorNoMatchingCase userInfo:@{ NSLocalizedDescriptionKey: description }]];
                  }
                  
                  return signal;
              }]
             switchToLatest]
            setNameWithFormat:@"+switch: %@ cases: %@ default: %@", signal, cases, defaultSignal];
}


```

实现中有3个断言，全部都是针对入参的要求。入参signal信号和cases字典都不能是nil。其次，cases字典里面所有key对应的value必须是RACSignal类型的。注意，defaultSignal是可以为nil的。

接下来的实现比较简单，对入参传进来的signal信号进行map变换，这里的变换是升阶的变换。

signal每次发送出来的一个值，就把这个值当做key值去cases字典里面去查找对应的value。当然value对应的是一个信号。如果value对应的信号不为空，就把signal发送出来的这个值map成字典里面对应的信号。如果value对应为空，那么就把原signal发出来的值map成defaultSignal信号。

如果经过转换之后，得到的信号为nil，就会返回一个error信号。如果得到的信号不为nil，那么原信号完全转换完成就会变成一个高阶信号，这个高阶信号里面装的都是信号。最后再对这个高阶信号执行switchToLatest转换。




#### 7. if: then: else:

if: then: else:源码实现如下:


```objectivec


+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal {
    NSCParameterAssert(boolSignal != nil);
    NSCParameterAssert(trueSignal != nil);
    NSCParameterAssert(falseSignal != nil);
    
    return [[[boolSignal
              map:^(NSNumber *value) {
                  NSCAssert([value isKindOfClass:NSNumber.class], @"Expected %@ to send BOOLs, not %@", boolSignal, value);
                  
                  return (value.boolValue ? trueSignal : falseSignal);
              }]
             switchToLatest]
            setNameWithFormat:@"+if: %@ then: %@ else: %@", boolSignal, trueSignal, falseSignal];
}


```

入参boolSignal，trueSignal，falseSignal三个信号都不能为nil。

boolSignal里面都必须装的是NSNumber类型的值。

针对boolSignal进行map升阶操作，boolSignal信号里面的值如果是YES，那么就转换成trueSignal信号，如果为NO，就转换成falseSignal。升阶转换完成之后，boolSignal就是一个高阶信号，然后再进行switchToLatest操作。


#### 8. catch:

catch:的实现如下:

```objectivec


- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
    NSCParameterAssert(catchBlock != NULL);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACSerialDisposable *catchDisposable = [[RACSerialDisposable alloc] init];
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            RACSignal *signal = catchBlock(error);
            NSCAssert(signal != nil, @"Expected non-nil signal from catch block on %@", self);
            catchDisposable.disposable = [signal subscribe:subscriber];
        } completed:^{
            [subscriber sendCompleted];
        }];
        
        return [RACDisposable disposableWithBlock:^{
            [catchDisposable dispose];
            [subscriptionDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -catch:", self.name];
}

```

当对原信号进行订阅的时候，如果出现了错误，会去执行catchBlock( )闭包，入参为刚刚产生的error。catchBlock( )闭包产生的是一个新的RACSignal，并再次用订阅者订阅该信号。

这里之所以说是高阶操作，是因为这里原信号发生错误之后，错误会升阶成一个信号。

#### 9. catchTo:

catchTo:的实现如下：

```objectivec

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
}

```

catchTo:的实现就是调用catch:方法，只不过原来catch:方法里面的catchBlock( )闭包，永远都只返回catchTo:的入参，signal信号。


#### 10. try:

```objectivec

- (RACSignal *)try:(BOOL (^)(id value, NSError **errorPtr))tryBlock {
    NSCParameterAssert(tryBlock != NULL);
    
    return [[self flattenMap:^(id value) {
        NSError *error = nil;
        BOOL passed = tryBlock(value, &error);
        return (passed ? [RACSignal return:value] : [RACSignal error:error]);
    }] setNameWithFormat:@"[%@] -try:", self.name];
}

```

try:可以用来进来信号的升阶操作。对原信号进行flattenMap变换，对信号发出来的每个值都调用一遍tryBlock( )闭包，如果这个闭包的返回值是YES，那么就返回[RACSignal return:value]，如果闭包的返回值是NO，那么就返回error。原信号中如果都是值，那么经过try:操作之后，每个值都会变成RACSignal，于是原信号也就变成了高阶信号了。

当然，如果在block的实现中返回一个信号，这时就不会升阶了。返回的信号里面可以不返回信号，而是直接返回值。



#### 11. tryMap:

```objectivec

- (RACSignal *)tryMap:(id (^)(id value, NSError **errorPtr))mapBlock {
    NSCParameterAssert(mapBlock != NULL);
    
    return [[self flattenMap:^(id value) {
        NSError *error = nil;
        id mappedValue = mapBlock(value, &error);
        return (mappedValue == nil ? [RACSignal error:error] : [RACSignal return:mappedValue]);
    }] setNameWithFormat:@"[%@] -tryMap:", self.name];
}

```

tryMap:的实现和try:的实现基本一致，唯一不同的就是入参闭包的返回值不同。在tryMap:中调用mapBlock( )闭包，返回是一个对象，如果这个对象不为nil，就返回[RACSignal return:mappedValue]。如果返回的对象是nil，那么就变换成error信号。

#### 12. timeout: onScheduler:



```objectivec


- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        RACDisposable *timeoutDisposable = [scheduler afterDelay:interval schedule:^{
            [disposable dispose];
            [subscriber sendError:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorTimedOut userInfo:nil]];
        }];
        
        [disposable addDisposable:timeoutDisposable];
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            [disposable dispose];
            [subscriber sendError:error];
        } completed:^{
            [disposable dispose];
            [subscriber sendCompleted];
        }];
        
        [disposable addDisposable:subscriptionDisposable];
        return disposable;
    }] setNameWithFormat:@"[%@] -timeout: %f onScheduler: %@", self.name, (double)interval, scheduler];
}


```

timeout: onScheduler:的实现很简单，它比正常的信号订阅多了一个timeoutDisposable操作。它在信号订阅的内部开启了一个scheduler，经过interval的时间之后，就会停止订阅原信号，并对订阅者sendError。

这个操作的表意和方法名完全一致，经过interval的时间之后，就算timeout，那么就停止订阅原信号，并sendError。



总结一下ReactiveCocoa v2.5中高阶信号的升阶 / 降阶操作：


![](https://img.halfrost.com/Blog/ArticleImage/35_8.png)


**升阶操作**：

1. map( 把值map成一个信号)
2. [RACSignal return:signal]


![](https://img.halfrost.com/Blog/ArticleImage/35_9.png)

**降阶操作**：

1. flatten(等效于flatten:0，+merge:)
2. concat(等效于flatten:1)
3. flatten:1
4. switchToLatest
5. flattenMap:

这5种操作能将高阶信号变为低阶信号，但是最终降阶之后的效果就只有3种：switchToLatest，flatten，concat。具体的图示见上面的分析。









### 二. 同步操作

在ReactiveCocoa中还包含一些同步的操作，这些操作一般我们很少使用，除非真的很确定这样做了之后不会有什么问题，否则胡乱使用会导致线程死锁等一些严重的问题。

#### 1. firstOrDefault: success: error:

```objectivec

- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
    NSCondition *condition = [[NSCondition alloc] init];
    condition.name = [NSString stringWithFormat:@"[%@] -firstOrDefault: %@ success:error:", self.name, defaultValue];
    
    __block id value = defaultValue;
    __block BOOL done = NO;
    
    // Ensures that we don't pass values across thread boundaries by reference.
    __block NSError *localError;
    __block BOOL localSuccess;
    
    [[self take:1] subscribeNext:^(id x) {
        // 加锁
        [condition lock];
        
        value = x;
        localSuccess = YES;
        
        done = YES;
        [condition broadcast];
        // 解锁
        [condition unlock];
    } error:^(NSError *e) {
        // 加锁
        [condition lock];
        
        if (!done) {
            localSuccess = NO;
            localError = e;
            
            done = YES;
            [condition broadcast];
        }
        // 解锁
        [condition unlock];
    } completed:^{
        // 加锁
        [condition lock];
        
        localSuccess = YES;
        
        done = YES;
        [condition broadcast];
        // 解锁
        [condition unlock];
    }];
    // 加锁
    [condition lock];
    while (!done) {
        [condition wait];
    }
    
    if (success != NULL) *success = localSuccess;
    if (error != NULL) *error = localError;
    // 解锁
    [condition unlock];
    return value;
}



```

从源码上看，firstOrDefault: success: error:这种同步的方法很容易导致线程死锁。它在subscribeNext，error，completed的闭包里面都调用condition锁先lock再unlock。如果一个信号发送值过来，都没有执行subscribeNext，error，completed这3个操作里面的任意一个，那么就会执行[condition wait]，等待。

由于对原信号进行了take:1操作，所以只会对第一个值进行操作。执行完subscribeNext，error，completed这3个操作里面的任意一个，又会加一次锁，对外部传进来的入参success和error进行赋值，已便外部可以拿到里面的状态。最终返回信号是原信号中第一个next里面的值，如果原信号第一个值没有，比如直接error或者completed，那么返回的是defaultValue。

done为YES表示已经成功执行了subscribeNext，error，completed这3个操作里面的任意一个。反之为NO。

localSuccess为YES表示成功发送值或者成功发送完了原信号的所有值，期间没有发生错误。

condition的broadcast操作是唤醒其他线程的操作，相当于操作系统里面互斥信号量的signal操作。

入参defaultValue是给内部变量value的一个初始值。当原信号发送出一个值之后，value的值时刻都会与原信号的值保持一致。

success和error是外部变量的地址，从外面可以监听到里面的状态。在函数内部赋值，在函数外面拿到它们的值。



#### 2. firstOrDefault:

```objectivec

- (id)firstOrDefault:(id)defaultValue {
    return [self firstOrDefault:defaultValue success:NULL error:NULL];
}


```

firstOrDefault:的实现就是调用了firstOrDefault: success: error:方法。只不过不需要传success和error，不关心内部的状态。最终返回信号是原信号中第一个next里面的值，如果原信号第一个值没有，比如直接error或者completed，那么返回的是defaultValue。


#### 3. first

```objectivec

- (id)first {
	return [self firstOrDefault:nil];
}

```

first方法就更加省略，连defaultValue也不传。最终返回信号是原信号中第一个next里面的值，如果原信号第一个值没有，比如直接error或者completed，那么返回的是nil。

#### 4. waitUntilCompleted:

```objectivec


- (BOOL)waitUntilCompleted:(NSError **)error {
    BOOL success = NO;
    
    [[[self
       ignoreValues]
      setNameWithFormat:@"[%@] -waitUntilCompleted:", self.name]
     firstOrDefault:nil success:&success error:error];
    
    return success;
}

```


waitUntilCompleted:里面还是调用firstOrDefault: success: error:方法。返回值是success。只要原信号正常的发送完信号，success应该为YES，但是如果发送过程中出现了error，success就为NO。success作为返回值，外部就可以监听到是否发送成功。


虽然这个方法可以监听到发送结束的状态，但是也尽量不要使用，因为它的实现调用了firstOrDefault: success: error:方法，这个方法里面有大量的锁的操作，一不留神就会导致死锁。

#### 5. toArray


```objectivec

- (NSArray *)toArray {
	return [[[self collect] first] copy];
}


```

经过collect之后，原信号所有的值都会被加到一个数组里面，取出信号的第一个值就是一个数组。所以执行完first之后第一个值就是原信号所有值的数组。


### 三. 副作用操作


![](https://img.halfrost.com/Blog/ArticleImage/35_10.png)




ReactiveCocoa v2.5中还为我们提供了一些可以进行副作用操作的函数。

#### 1. doNext:

```objectivec

- (RACSignal *)doNext:(void (^)(id x))block {
    NSCParameterAssert(block != NULL);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [self subscribeNext:^(id x) {
            block(x);
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -doNext:", self.name];
}

```

doNext:能让我们在原信号sendNext之前，能执行一个block闭包，在这个闭包中我们可以执行我们想要执行的副作用操作。


#### 2. doError:

```objectivec

- (RACSignal *)doError:(void (^)(NSError *error))block {
    NSCParameterAssert(block != NULL);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [self subscribeNext:^(id x) {
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            block(error);
            [subscriber sendError:error];
        } completed:^{
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -doError:", self.name];
}


```

doError:能让我们在原信号sendError之前，能执行一个block闭包，在这个闭包中我们可以执行我们想要执行的副作用操作。

#### 3. doCompleted:

```objectivec


- (RACSignal *)doCompleted:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [self subscribeNext:^(id x) {
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            block();
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -doCompleted:", self.name];
}



```


doCompleted:能让我们在原信号sendCompleted之前，能执行一个block闭包，在这个闭包中我们可以执行我们想要执行的副作用操作。


**doNext:,doError:,doCompleted:这3个操作比较有用，要做副作用的操作最好都声明在这里面，让读代码的人能立即清晰的看到这是一个副作用操作。**


#### 4. initially:


```objectivec

- (RACSignal *)initially:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    return [[RACSignal defer:^{
        block();
        return self;
    }] setNameWithFormat:@"[%@] -initially:", self.name];
}

```

initially:能让我们在原信号发送之前，先调用了defer:操作，在return self之前先执行了一个闭包，在这个闭包中我们可以执行我们想要执行的副作用操作。


#### 5. finally:


```objectivec

- (RACSignal *)finally:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    return [[[self
              doError:^(NSError *error) {
                  block();
              }]
             doCompleted:^{
                 block();
             }]
            setNameWithFormat:@"[%@] -finally:", self.name];
}


```

finally:操作调用了doError:和doCompleted:操作，依次在sendError之前，sendCompleted之前，插入一个block( )闭包。这样当信号因为错误而要终止取消订阅，或者，发送结束之前，都能执行一段我们想要执行的副作用操作。


### 四. 多线程操作

在RACSignal里面有3个关于多线程的操作。

![](https://img.halfrost.com/Blog/ArticleImage/35_11.png)



#### 1. deliverOn:


```objectivec


- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [self subscribeNext:^(id x) {
            [scheduler schedule:^{
                [subscriber sendNext:x];
            }];
        } error:^(NSError *error) {
            [scheduler schedule:^{
                [subscriber sendError:error];
            }];
        } completed:^{
            [scheduler schedule:^{
                [subscriber sendCompleted];
            }];
        }];
    }] setNameWithFormat:@"[%@] -deliverOn: %@", self.name, scheduler];
}


```


deliverOn:的入参是一个scheduler，当原信号subscribeNext，sendError，sendCompleted的时候，都去调用scheduler的schedule方法。


```objectivec


- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];

	block();
	return nil;
}

```

在schedule的方法里面会判断当前currentScheduler是否为nil，如果是nil就调用backgroundScheduler去执行block( )闭包,如果不为nil，当前currentScheduler直接执行block( )闭包。

```objectivec


+ (instancetype)currentScheduler {
	RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
	if (scheduler != nil) return scheduler;
	if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

	return nil;
}

```

判断currentScheduler是否存在，看两点，一是当前线程的字典里面，是否存在RACSchedulerCurrentSchedulerKey( @"RACSchedulerCurrentSchedulerKey" )，如果存在对应的value，返回scheduler，二是看当前的类是不是在主线程，如果在主线程，返回mainThreadScheduler。如果两个条件都不存在，那么当前currentScheduler就不存在，返回nil。


deliverOn:操作的特点是原信号发送sendNext，sendError，sendCompleted所在线程是确定的。


#### 2. subscribeOn:


```objectivec


- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        RACDisposable *schedulingDisposable = [scheduler schedule:^{
            RACDisposable *subscriptionDisposable = [self subscribe:subscriber];
            
            [disposable addDisposable:subscriptionDisposable];
        }];
        
        [disposable addDisposable:schedulingDisposable];
        return disposable;
    }] setNameWithFormat:@"[%@] -subscribeOn: %@", self.name, scheduler];
}


```

subscribeOn:操作就是在传入的scheduler的闭包内部订阅原信号的。它与deliverOn:操作就不同：

subscribeOn:操作能够保证didSubscribe block( )闭包在入参scheduler中执行，但是不能保证原信号subscribeNext，sendError，sendCompleted在哪个scheduler中执行。

deliverOn:与subscribeOn:正好反过来，能保证原信号subscribeNext，sendError，sendCompleted在哪个scheduler中执行，但是不能保证didSubscribe block( )闭包在哪个scheduler中执行。

#### 3. deliverOnMainThread

```objectivec


- (RACSignal *)deliverOnMainThread {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block volatile int32_t queueLength = 0;
        
        void (^performOnMainThread)(dispatch_block_t) = ^(dispatch_block_t block) { // 暂时省略};
        
        return [self subscribeNext:^(id x) {
            performOnMainThread(^{
                [subscriber sendNext:x];
            });
        } error:^(NSError *error) {
            performOnMainThread(^{
                [subscriber sendError:error];
            });
        } completed:^{
            performOnMainThread(^{
                [subscriber sendCompleted];
            });
        }];
    }] setNameWithFormat:@"[%@] -deliverOnMainThread", self.name];
}


```


对比deliverOn:的源码实现，发现两者比较相似，只不过这里deliverOnMainThread把sendNext，sendError，sendCompleted都包在了performOnMainThread闭包中执行。


```objectivec

		__block volatile int32_t queueLength = 0;
		
		void (^performOnMainThread)(dispatch_block_t) = ^(dispatch_block_t block) {
			int32_t queued = OSAtomicIncrement32(&queueLength);
			if (NSThread.isMainThread && queued == 1) {
				block();
				OSAtomicDecrement32(&queueLength);
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					block();
					OSAtomicDecrement32(&queueLength);
				});
			}
		};

```

performOnMainThread闭包内部保证了入参block( )闭包一定是在主线程中执行。

OSAtomicIncrement32 和 OSAtomicDecrement32是原子操作，分别代表+1和-1。下面的if-else判断里面，不管是满足哪一条，最终都还是在主线程中执行block( )闭包。

deliverOnMainThread能保证原信号subscribeNext，sendError，sendCompleted都在主线程MainThread中执行。

### 五. 其他操作


![](https://img.halfrost.com/Blog/ArticleImage/35_12.png)





#### 1. setKeyPath: onObject: nilValue:

setKeyPath: onObject: nilValue: 的源码实现如下：


```objectivec

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object nilValue:(id)nilValue {
    NSCParameterAssert(keyPath != nil);
    NSCParameterAssert(object != nil);
    
    keyPath = [keyPath copy];
    
    RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    __block void * volatile objectPtr = (__bridge void *)object;
    
    RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
        // 1
        __strong NSObject *object __attribute__((objc_precise_lifetime)) = (__bridge __strong id)objectPtr;
        [object setValue:x ?: nilValue forKeyPath:keyPath];
    } error:^(NSError *error) {
        __strong NSObject *object __attribute__((objc_precise_lifetime)) = (__bridge __strong id)objectPtr;
        
        NSCAssert(NO, @"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);
        NSLog(@"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);
        
        [disposable dispose];
    } completed:^{
        [disposable dispose];
    }];
    
    [disposable addDisposable:subscriptionDisposable];
    
#if DEBUG
    static void *bindingsKey = &bindingsKey;
    NSMutableDictionary *bindings;
    
    @synchronized (object) {
        // 2
        bindings = objc_getAssociatedObject(object, bindingsKey);
        if (bindings == nil) {
            bindings = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(object, bindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    @synchronized (bindings) {
        NSCAssert(bindings[keyPath] == nil, @"Signal %@ is already bound to key path \"%@\" on object %@, adding signal %@ is undefined behavior", [bindings[keyPath] nonretainedObjectValue], keyPath, object, self);
        
        bindings[keyPath] = [NSValue valueWithNonretainedObject:self];
    }
#endif
    
    RACDisposable *clearPointerDisposable = [RACDisposable disposableWithBlock:^{
#if DEBUG
        @synchronized (bindings) {
            // 3
            [bindings removeObjectForKey:keyPath];
        }
#endif
        
        while (YES) {
            void *ptr = objectPtr;
            // 4
            if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr)) {
                break;
            }
        }
    }];
    
    [disposable addDisposable:clearPointerDisposable];
    
    [object.rac_deallocDisposable addDisposable:disposable];
    
    RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
    return [RACDisposable disposableWithBlock:^{
        [objectDisposable removeDisposable:disposable];
        [disposable dispose];
    }];
}


```

代码虽然有点长，但是逐行读下来不是很难，需要注意的有4点地方，已经在上述代码里面标明了。接下来一一分析。

##### 1. objc\_precise\_lifetime的问题。

作者在这里写了一段注释：

 > Possibly spec, possibly compiler bug, but this \_\_bridge cast does not result in a retain here, effectively an invisible \_\_unsafe\_unretained qualifier. Using objc\_precise\_lifetime gives the \_\_strong reference desired. The explicit use of \_\_strong is strictly defensive.

作者怀疑是编译器的一个bug，即使是显示的调用了\_\_strong，依旧没法保证被强引用了，所以还需要用objc\_precise\_lifetime来保证强引用。

关于这个问题，笔者查询了一下LLVM的文档，在[6.3 precise lifetime semantics](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id42)这一节中提到了这个问题。

通常上，凡是声明了\_\_strong的变量，都会有很确切的生命周期。ARC会维持这些\_\_strong的变量在其生命周期中被retained。

但是自动存储的局部变量是没有确切的生命周期的。这些变量仅仅只是简单的持有一个强引用，强引用着retain对象的指针类型的值。这些值完全受控于本地控制者的如何优化。所以要想改变这些局部变量的生命周期，是不可能的事情。因为有太多的优化，理论上都会导致局部变量的生命周期减少，但是这些优化非常有用。


但是LLVM为我们提供了一个关键字objc\_precise\_lifetime，使用这个可以是局部变量的生命周期变成确切的。这个关键字有时候还是非常有用的。甚至更加极端情况，该局部变量都没有被使用，但是它依旧可以保持一个确定的生命周期。


回到源码上来，接着代码会对入参object进行setValue: forKeyPath:

```objectivec

[object setValue:x ?: nilValue forKeyPath:keyPath];

```

如何x为nil就返回nilValue传进来的值。


##### 2.  AssociatedObject关联对象

如果bindings字典不存在，那么就调用objc\_setAssociatedObject对object进行关联对象。参数是OBJC\_ASSOCIATION\_RETAIN\_NONATOMIC。如果bindings字典存在，就用objc\_getAssociatedObject取出字典。

在字典里面重新更新绑定key-value值，key就是入参keyPath，value是原信号。


##### 3.  取消订阅原信号的时候

```objectivec

[bindings removeObjectForKey:keyPath];

```

当信号取消订阅的时候，移除所有的关联值。

##### 3.  OSAtomicCompareAndSwapPtrBarrier

这个函数属于OSAtomic原子操作，原型如下：

```objectivec

OSAtomicCompareAndSwapPtrBarrier(type __oldValue, type __newValue, volatile type *__theValue)

```


>Compares a variable against the specified old value. If the two values are equal, this function assigns the specified new value to the variable; otherwise, it does nothing. The comparison and assignment are done as one atomic operation and the function returns a Boolean value indicating whether the swap actually occurred.

这个函数用于比较\_\_oldValue是否与\_\_theValue指针指向的内存位置的值匹配，如果匹配，则将\_\_newValue的值存储到\_\_theValue指向的内存位置。整个函数的返回值就是交换是否成功的BOOL值。

```objectivec
	while (YES) {
	void *ptr = objectPtr;
	if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr))   {
		  break;
	}
  }

```

在这个while的死循环里面只有当OSAtomicCompareAndSwapPtrBarrier返回值为YES，才能退出整个死循环。返回值为YES就代表&objectPtr被置为了NULL，这样就确保了在线程安全的情况下，不存在野指针的问题了。


#### 2. setKeyPath: onObject:
```objectivec

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
    return [self setKeyPath:keyPath onObject:object nilValue:nil];
}

```

setKeyPath: onObject:就是调用setKeyPath: onObject: nilValue:方法，只不过nilValue传递的是nil。



### 最后

关于RACSignal的所有操作底层分析实现都已经分析完成。最后请大家多多指教。

