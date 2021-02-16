# ReactiveCocoa 中 RACSignal 所有变换操作底层实现分析(中)

![](https://img.halfrost.com/Blog/ArticleTitleImage/33_0_.png)



### 前言



紧接着[上篇](https://halfrost.com/reactivecocoa_racsignal_operations1/)的源码实现分析，继续分析RACSignal的变换操作的底层实现。


### 目录

- 1.过滤操作
- 2.组合操作


### 一. 过滤操作

![](https://img.halfrost.com/Blog/ArticleImage/33_1.png)



过滤操作也属于一种变换，根据过滤条件，过滤出符合条件的值。变换出来的新的信号是原信号的一个子集。

#### 1. filter: (在父类RACStream中定义的)

这个filter:操作在any:的实现中用到过了。

```objectivec


- (instancetype)filter:(BOOL (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    
    return [[self flattenMap:^ id (id value) {  
        if (block(value)) {
            return [class return:value];
        } else {
            return class.empty;
        }
    }] setNameWithFormat:@"[%@] -filter:", self.name];
}

```


![](https://img.halfrost.com/Blog/ArticleImage/33_2.png)





filter:中传入一个闭包，是用筛选的条件。如果满足筛选条件的即返回原信号的值，否则原信号的值被“吞”掉，返回空的信号。这个变换主要是用flattenMap的。


#### 2. ignoreValues


```objectivec

- (RACSignal *)ignoreValues {
    return [[self filter:^(id _) {
        return NO;
    }] setNameWithFormat:@"[%@] -ignoreValues", self.name];
}


```


![](https://img.halfrost.com/Blog/ArticleImage/33_3.png)



由上面filter的实现，这里把筛选判断条件永远的传入NO，那么原信号的值都会被变换成empty信号，故变换之后的信号为空信号。







#### 3. ignore: (在父类RACStream中定义的)


```objectivec

- (instancetype)ignore:(id)value {
    return [[self filter:^ BOOL (id innerValue) {
        return innerValue != value && ![innerValue isEqual:value];
    }] setNameWithFormat:@"[%@] -ignore: %@", self.name, [value rac_description]];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_4.png)


ignore:的实现还是由filter:实现的。传入的筛选判断条件是一个值，当原信号发送的值中是这个值的时候，就替换成空信号。

#### 4. distinctUntilChanged (在父类RACStream中定义的)

```objectivec

- (instancetype)distinctUntilChanged {
    Class class = self.class;
    
    return [[self bind:^{
        __block id lastValue = nil;
        __block BOOL initial = YES;
        
        return ^(id x, BOOL *stop) {
            if (!initial && (lastValue == x || [x isEqual:lastValue])) return [class empty];
            
            initial = NO;
            lastValue = x;
            return [class return:x];
        };
    }] setNameWithFormat:@"[%@] -distinctUntilChanged", self.name];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_5.png)



distinctUntilChanged的实现是用bind来完成的。每次变换中都记录一下原信号上一次发送过来的值，并与这一次进行比较，如果是相同的值，就“吞”掉，返回empty信号。只有和原信号上一次发送的值不同，变换后的新信号才把这个值发送出来。


关于distinctUntilChanged，这里关注的是两两信号之间的值是否不同，有时候我们可能需要一个类似于NSSet的信号集，distinctUntilChanged就无法满足了。在ReactiveCocoa 2.5的这个版本也并没有向我们提供distinct的变换函数。


![](https://img.halfrost.com/Blog/ArticleImage/33_6.png)


我们可以自己实现类似的变换。实现思路也不难，可以把之前每次发送过来的信号都用数组存起来，新来的信号都去数组里面查找一遍，如果找不到，就把这个值发送出去，如果找到了，就返回empty信号。效果如上图。









#### 5. take: (在父类RACStream中定义的)


```objectivec

- (instancetype)take:(NSUInteger)count {
    Class class = self.class;
    
    if (count == 0) return class.empty;
    
    return [[self bind:^{
        __block NSUInteger taken = 0;
        
        return ^ id (id value, BOOL *stop) {
            if (taken < count) {
                ++taken;
                if (taken == count) *stop = YES;
                return [class return:value];
            } else {
                return nil;
            }
        };
    }] setNameWithFormat:@"[%@] -take: %lu", self.name, (unsigned long)count];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_7.png)



take:实现也非常简单，借助bind函数来实现的。入参的count是原信号取值的个数。在bind的闭包中，taken计数从0开始取原信号的值，当taken取到count个数的时候，就停止取值。



在take:的基础上我们还可以继续改造出新的变换方式。比如说，想取原信号中执行的第几个值。类似于elementAt的操作。这个操作在ReactiveCocoa 2.5的这个版本也并没有直接向我们提供出来。


![](https://img.halfrost.com/Blog/ArticleImage/33_8.png)


其实实现很简单，只需要判断taken是否等于我们要取的那个位置就可以了，等于的时候把原信号的值发送出来，并*stop = YES。


```objectivec

// 我自己增加实现的方法
- (instancetype)elementAt:(NSUInteger)index {
    Class class = self.class;
    
    return [[self bind:^{
        __block NSUInteger taken = 0;
        
        return ^ id (id value, BOOL *stop) {
            if (index == 0) {
                *stop = YES;
                return [class return:value];
            }
            if (taken == index) {
                *stop = YES;
                return [class return:value];
            } else if (taken < index){
                taken ++;
                return [class empty];
            }else {
                return nil;
            }
        };
    }] setNameWithFormat:@"[%@] -elementAt: %lu", self.name, (unsigned long)index];
}

```



#### 6. takeLast:

```objectivec

- (RACSignal *)takeLast:(NSUInteger)count {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];
        return [self subscribeNext:^(id x) {
            [valuesTaken addObject:x ? : RACTupleNil.tupleNil];
            
            while (valuesTaken.count > count) {
                [valuesTaken removeObjectAtIndex:0];
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            for (id value in valuesTaken) {
                [subscriber sendNext:value == RACTupleNil.tupleNil ? nil : value];
            }
            
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_9.png)


takeLast:的实现也是按照套路来。先创建一个新信号，return的时候订阅原信号。在函数内部用一个valuesTaken来保存原信号发送过来的值，原信号发多少，就存多少，直到个数溢出入参给定的count，就溢出数组第0位。这样能保证数组里面始终都装着最后count个原信号的值。

当原信号发送completed信号的时候，把数组里面存的值都sendNext出去。这里要注意的也是该变换发送信号的时机。如果原信号一直没有completed，那么takeLast:就一直没法发出任何信号来。

#### 7. takeUntilBlock: (在父类RACStream中定义的)


```objectivec

- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    Class class = self.class;
    
    return [[self bind:^{
        return ^ id (id value, BOOL *stop) {
            if (predicate(value)) return nil;
            
            return [class return:value];
        };
    }] setNameWithFormat:@"[%@] -takeUntilBlock:", self.name];
}


```

takeUntilBlock:是根据传入的predicate闭包作为筛选条件的。一旦predicate( )闭包满足条件，那么新信号停止发送新信号，因为它被置为nil了。和函数名的意思是一样的，take原信号的值，Until直到闭包满足条件。

#### 8. takeWhileBlock: (在父类RACStream中定义的)

```objectivec

- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    return [[self takeUntilBlock:^ BOOL (id x) {
        return !predicate(x);
    }] setNameWithFormat:@"[%@] -takeWhileBlock:", self.name];
}

```


takeWhileBlock:的信号集是takeUntilBlock:的信号集的补集。全集是原信号。takeWhileBlock:底层还是调用takeUntilBlock:，只不过判断条件的是不满足predicate( )闭包的集合。

#### 9. takeUntil:


```objectivec

- (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        void (^triggerCompletion)(void) = ^{
            [disposable dispose];
            [subscriber sendCompleted];
        };
        
        RACDisposable *triggerDisposable = [signalTrigger subscribeNext:^(id _) {
            triggerCompletion();
        } completed:^{
            triggerCompletion();
        }];
        
        [disposable addDisposable:triggerDisposable];
        
        if (!disposable.disposed) {
            RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
                [subscriber sendNext:x];
            } error:^(NSError *error) {
                [subscriber sendError:error];
            } completed:^{
                [disposable dispose];
                [subscriber sendCompleted];
            }];
            
            [disposable addDisposable:selfDisposable];
        }
        
        return disposable;
    }] setNameWithFormat:@"[%@] -takeUntil: %@", self.name, signalTrigger];
}

```


![](https://img.halfrost.com/Blog/ArticleImage/33_10.jpg)





takeUntil:的实现也是“经典套路”——return一个新信号，在新信号中订阅原信号。入参是一个信号signalTrigger，这个信号是一个Trigger。一旦signalTrigger发出第一个信号，就会触发triggerCompletion( )闭包，在这个闭包中，会调用triggerCompletion( )闭包。

```objectivec

  void (^triggerCompletion)(void) = ^{
   [disposable dispose];
   [subscriber sendCompleted];
  };

```

一旦调用了triggerCompletion( )闭包，就会把原信号取消订阅，并给变换的新的信号订阅者sendCompleted。

如果入参signalTrigger一直没有sendNext，那么原信号就会一直sendNext:。


#### 10. takeUntilReplacement:

```objectivec

- (RACSignal *)takeUntilReplacement:(RACSignal *)replacement {
    return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
        
        RACDisposable *replacementDisposable = [replacement subscribeNext:^(id x) {
            [selfDisposable dispose];
            [subscriber sendNext:x];
        } error:^(NSError *error) {
            [selfDisposable dispose];
            [subscriber sendError:error];
        } completed:^{
            [selfDisposable dispose];
            [subscriber sendCompleted];
        }];
        
        if (!selfDisposable.disposed) {
            selfDisposable.disposable = [[self
                                          concat:[RACSignal never]]
                                         subscribe:subscriber];
        }
        
        return [RACDisposable disposableWithBlock:^{
            [selfDisposable dispose];
            [replacementDisposable dispose];
        }];
    }];
}

```


![](https://img.halfrost.com/Blog/ArticleImage/33_11.png)



1. 原信号concat:了一个[RACSignal never]信号，这样原信号就一直不会disposed，会一直等待replacement信号的到来。
2. 控制selfDisposable是否被dispose，控制权来自于入参的replacement信号，一旦replacement信号sendNext，那么原信号就会取消订阅，接下来的事情就会交给replacement信号了。
3. 变换后的新信号sendNext，sendError，sendCompleted全部都由replacement信号来发送，最终新信号完成的时刻也是replacement信号完成的时刻。



#### 11. skip: (在父类RACStream中定义的)


```objectivec

- (instancetype)skip:(NSUInteger)skipCount {
    Class class = self.class;
    
    return [[self bind:^{
        __block NSUInteger skipped = 0;
        
        return ^(id value, BOOL *stop) {
            if (skipped >= skipCount) return [class return:value];
            
            skipped++;
            return class.empty;
        };
    }] setNameWithFormat:@"[%@] -skip: %lu", self.name, (unsigned long)skipCount];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_12.png)



skip:信号集和take:信号集是补集关系，全集是原信号。take:是取原信号的前count个信号，而skip:是从原信号第count + 1位开始取信号。

skipped是一个游标，每次原信号发送一个值，就比较它和入参skipCount的大小。如果不比skipCount大，说明还需要跳过，所以就返回empty信号，否则就把原信号的值发送出来。



通过类比take系列方法，可以发现在ReactiveCocoa 2.5的这个版本也并没有向我们提供skipLast:的变换函数。这个变换函数的实现过程也不难，我们可以类比takeLast:来实现。


实现的思路也不难，原信号每次发送过来的值，都用一个数组存储起来。skipLast:是想去掉原信号最末尾的count个信号。

我们先来分析一下：假设原信号有n个信号，从0 - (n-1)，去掉最后的count个，前面还剩n - count个信号。那么从 原信号的第 count + 1位的信号开始发送，到原信号结束，这样中间就正好是发送了 n - count 个信号。

分析清楚后，代码就很容易了：

```objectivec

// 我自己增加实现的方法
- (RACSignal *)skipLast:(NSUInteger)count {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];
        return [self subscribeNext:^(id x) {
            [valuesTaken addObject:x ? : RACTupleNil.tupleNil];
            
            while (valuesTaken.count > count) {
                [subscriber sendNext:valuesTaken[0] == RACTupleNil.tupleNil ? nil : valuesTaken[0]];
                [valuesTaken removeObjectAtIndex:0];
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{            
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -skipLast: %lu", self.name, (unsigned long)count];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_13.png)


原信号每发送过来一个信号就存入数组，当数组里面的个数大于count的时候，就是需要我们发送信号的时候，这个时候每次都把数组里面第0位发送出去即可，数组维护了一个FIFO的队列。这样就实现了skipLast:的效果了。

#### 12. skipUntilBlock: (在父类RACStream中定义的)

```objectivec

- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    Class class = self.class;
    
    return [[self bind:^{
        __block BOOL skipping = YES;
        
        return ^ id (id value, BOOL *stop) {
            if (skipping) {
                if (predicate(value)) {
                    skipping = NO;
                } else {
                    return class.empty;
                }
            }
            
            return [class return:value];
        };
    }] setNameWithFormat:@"[%@] -skipUntilBlock:", self.name];
}

```

skipUntilBlock: 的实现可以类比takeUntilBlock: 的实现。

skipUntilBlock: 是根据传入的predicate闭包作为筛选条件的。一旦predicate( )闭包满足条件，那么skipping = NO。skipping为NO，以后原信号发送的每个值都原封不动的发送出去。predicate( )闭包不满足条件的时候，即会一直skip原信号的值。和函数名的意思是一样的，skip原信号的值，Until直到闭包满足条件，就不再skip了。



#### 13. skipWhileBlock: (在父类RACStream中定义的)


```objectivec

- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    return [[self skipUntilBlock:^ BOOL (id x) {
        return !predicate(x);
    }] setNameWithFormat:@"[%@] -skipWhileBlock:", self.name];
}

```

skipWhileBlock:的信号集是skipUntilBlock:的信号集的补集。全集是原信号。skipWhileBlock:底层还是调用skipUntilBlock:，只不过判断条件的是不满足predicate( )闭包的集合。




到这里skip系列方法就结束了，对比take系列的方法，少了2个方法，在ReactiveCocoa 2.5的这个版本中 takeUntil: 和 takeUntilReplacement:这两个方法没有与之对应的skip方法。


```objectivec

// 我自己增加实现的方法
- (RACSignal *)skipUntil:(RACSignal *)signalTrigger {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        __block BOOL sendTrigger = NO;
        
        void (^triggerCompletion)(void) = ^{
            sendTrigger = YES;
        };
        
        RACDisposable *triggerDisposable = [signalTrigger subscribeNext:^(id _) {
            triggerCompletion();
        } completed:^{
            triggerCompletion();
        }];
        
        [disposable addDisposable:triggerDisposable];
        
        if (!disposable.disposed) {
            RACDisposable *selfDisposable = [self subscribeNext:^(id x) {

                if (sendTrigger) {
                    [subscriber sendNext:x];
                }
                
            } error:^(NSError *error) {
                [subscriber sendError:error];
            } completed:^{
                [disposable dispose];
                [subscriber sendCompleted];
            }];
            
            [disposable addDisposable:selfDisposable];
        }
        
        return disposable;
    }] setNameWithFormat:@"[%@] -skipUntil: %@", self.name, signalTrigger];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_14.png)



skipUntil实现方法也很简单，当入参的signalTrigger开发发送信号的时候，就让原信号sendNext把值发送出来，否则就把原信号的值“吞”掉。

skipUntilReplacement:就没什么意义了，把原信号经过skipUntilReplacement:变换之后得到的新的信号就是Replacement信号。所以说这个操作也就没意义了。


#### 14. groupBy:transform:


```objectivec

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
    NSCParameterAssert(keyBlock != NULL);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        NSMutableDictionary *groups = [NSMutableDictionary dictionary];
        NSMutableArray *orderedGroups = [NSMutableArray array];
        
        return [self subscribeNext:^(id x) {
            id<NSCopying> key = keyBlock(x);
            RACGroupedSignal *groupSubject = nil;
            @synchronized(groups) {
                groupSubject = groups[key];
                if (groupSubject == nil) {
                    groupSubject = [RACGroupedSignal signalWithKey:key];
                    groups[key] = groupSubject;
                    [orderedGroups addObject:groupSubject];
                    [subscriber sendNext:groupSubject];
                }
            }
            
            [groupSubject sendNext:transformBlock != NULL ? transformBlock(x) : x];
        } error:^(NSError *error) {
            [subscriber sendError:error];
            
            [orderedGroups makeObjectsPerformSelector:@selector(sendError:) withObject:error];
        } completed:^{
            [subscriber sendCompleted];
            
            [orderedGroups makeObjectsPerformSelector:@selector(sendCompleted)];
        }];
    }] setNameWithFormat:@"[%@] -groupBy:transform:", self.name];
}


```

看groupBy:transform:的实现，依旧是老“套路”。return 一个新的RACSignal，在新的信号里面订阅原信号。


groupBy:transform:的重点就在subscribeNext中了。

1. 首先解释一下两个入参。两个入参都是闭包，keyBlock返回值是要作为字典的key，transformBlock的返回值是对原信号发出来的值x进行变换。
2. 先创建一个NSMutableDictionary字典groups，和NSMutableArray数组orderedGroups。
3. 从字典里面取出key对应的value，这里的key对应着keyBlock返回值。value的值是一个RACGroupedSignal信号。如果找不到对应的key值，就新建一个RACGroupedSignal信号，并存入字典对应的key值，与之对应。
4. 新变换之后的信号，订阅之后，RACGroupedSignal进行sendNext，这是一个信号，如果transformBlock不为空，就发送transformBlock变换之后的值。
5. sendError和sendCompleted都要分别对数组orderedGroups里面每个RACGroupedSignal都要进行sendError或者sendCompleted。因为要对数组里面每个信号都执行一个操作，所以需要调用makeObjectsPerformSelector:withObject:方法。


经过groupBy:transform:变换之后，原信号会根据keyBlock进行分组。


写出测试代码，来看看平时应该怎么用。



```objectivec

    RACSignal *signalA = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber)
                         {
                             [subscriber sendNext:@1];
                             [subscriber sendNext:@2];
                             [subscriber sendNext:@3];
                             [subscriber sendNext:@4];
                             [subscriber sendNext:@5];
                             [subscriber sendCompleted];
                             return [RACDisposable disposableWithBlock:^{
                                 NSLog(@"signal dispose");
                             }];
                         }];

    RACSignal *signalGroup = [signalA groupBy:^id<NSCopying>(NSNumber *object) {
        return object.integerValue > 3 ? @"good" : @"bad";
    } transform:^id(NSNumber * object) {
        return @(object.integerValue * 10);
    }];

    [[[signalGroup filter:^BOOL(RACGroupedSignal *value) {
        return [(NSString *)value.key isEqualToString:@"good"];
    }] flatten]subscribeNext:^(id x) {
        NSLog(@"subscribeNext: %@", x);
    }];


```

假设原信号发送的1，2，3，4，5是代表的成绩的5个等级。当成绩大于3的都算“good”，小于3的都算“bad”。

signalGroup是原信号signalA经过groupBy:transform:得到的新的信号，这个信号是一个高阶的信号，因为它里面并不是直接装的是值，signalGroup这个信号里面装的还是信号。signalGroup里面有两个分组，分别是“good”分组和“bad”分组。

想从中取出这两个分组里面的值，需要进行一次filter:筛选。筛选之后得到对应分组的高阶信号。这时还要再进行一个flatten操作，把高阶信号变成低阶信号，再次订阅才能取到其中的值。


订阅新信号的值，输出如下：

```vim

subscribeNext: 40
subscribeNext: 50


```


关于flatten的实现：

```objectivec

- (instancetype)flatten {
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self flattenMap:^(id value) {
        return value;
    }] setNameWithFormat:@"[%@] -flatten", self.name];
}

```

flatten操作就是调用了flattenMap:把值传进去了。


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

flatten是把高阶信号变换成低阶信号的常用操作。flattenMap:具体实现上篇文章分析过了，这里不再赘述。



#### 15. groupBy:

```objectivec


- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
    return [[self groupBy:keyBlock transform:nil] setNameWithFormat:@"[%@] -groupBy:", self.name];
}

```

groupBy:操作就是groupBy:transform:的缩减版，transform传入的为nil。


关于groupBy:可以干的事情很多，可以进行很高级的分组操作。这里可以举一个例子：

```objectivec

    // 简单算法题，分离数组中的相同的元素，如果元素个数大于2，则组成一个新的数组，结果得到多个包含相同元素的数组，
    // 例如[1,2,3,1,2,3]分离成[1,1],[2,2],[3,3]
    RACSignal *signal = @[@1, @2, @3, @4,@2,@3,@3,@4,@4,@4].rac_sequence.signal;

      NSArray * array = [[[[signal groupBy:^NSString *(NSNumber *object) {
          return [NSString stringWithFormat:@"%@",object];
      }] map:^id(RACGroupedSignal *value) {
          return [value sequence];
      }] sequence] map:^id(RACSignalSequence * value) {
          return value.array;
      }].array;
    
    for (NSNumber * num in array) {
        NSLog(@"最后的数组%@",num);
    }
    
   // 最后输出 [1,2,3,4,2,3,3,4,4,4]变成[1],[2,2],[3,3,3],[4,4,4,4]

```




### 二. 组合操作


![](https://img.halfrost.com/Blog/ArticleImage/33_15.png)





#### 1. startWith: (在父类RACStream中定义的)

```objectivec

- (instancetype)startWith:(id)value {
    
    return [[[self.class return:value]
             concat:self]
            setNameWithFormat:@"[%@] -startWith: %@", self.name, [value rac_description]];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/33_16.png)




startWith:的实现很简单，就是先构造一个只发送一个value的信号，然后这个信号发送完毕之后接上原信号。得到的新的信号就是在原信号前面新加了一个值。



#### 2. concat: (在父类RACStream中定义的)

这里说的concat:是在父类RACStream中定义的。

```objectivec

- (instancetype)concat:(RACStream *)stream {
    return nil;
}

```

父类中定义的这个方法就返回一个nil，具体的实现还要子类去重写。


#### 3. concat: (在父类RACStream中定义的)

```objectivec

+ (instancetype)concat:(id<NSFastEnumeration>)streams {
    RACStream *result = self.empty;
    for (RACStream *stream in streams) {
        result = [result concat:stream];
    }
    
    return [result setNameWithFormat:@"+concat: %@", streams];
}


```

这个concat:后面跟着一个数组，数组里面包含这很多信号，concat:依次把这些信号concat:连接串起来。





#### 4. merge:


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

![](https://img.halfrost.com/Blog/ArticleImage/33_17.png)


merge:后面跟一个数组。先会新建一个数组copiedSignals，把传入的信号都装到数组里。然后依次发送数组里面的信号。由于新信号也是一个高阶信号，因为sendNext会把各个信号都依次发送出去，所以需要flatten操作把这个信号转换成值发送出去。

从上图上看，上下两个信号就像被拍扁了一样，就成了新信号的发送顺序。



#### 5. merge:

```objectivec


- (RACSignal *)merge:(RACSignal *)signal {
    return [[RACSignal
             merge:@[ self, signal ]]
            setNameWithFormat:@"[%@] -merge: %@", self.name, signal];
}

```

merge:后面参数也可以跟一个信号，那么merge:就是合并这两个信号。具体实现和merge:多个信号是一样的原理。


#### 6. zip: (在父类RACStream中定义的)

```objectivec


+ (instancetype)zip:(id<NSFastEnumeration>)streams {
    return [[self join:streams block:^(RACStream *left, RACStream *right) {
        return [left zipWith:right];
    }] setNameWithFormat:@"+zip: %@", streams];
}


```

zip:后面可以跟一个数组，数组里面装的是各种信号流。

它的实现是调用了join: block: 实现的。

```objectivec

+ (instancetype)join:(id<NSFastEnumeration>)streams block:(RACStream * (^)(id, id))block {
    RACStream *current = nil;
    // 第一步
    for (RACStream *stream in streams) {

        if (current == nil) {
            current = [stream map:^(id x) {
                return RACTuplePack(x);
            }];
            
            continue;
        }
        
        current = block(current, stream);
    }
    // 第二步
    if (current == nil) return [self empty];
    
    return [current map:^(RACTuple *xs) {

        NSMutableArray *values = [[NSMutableArray alloc] init];
        // 第三步
        while (xs != nil) {
            [values insertObject:xs.last ?: RACTupleNil.tupleNil atIndex:0];
            xs = (xs.count > 1 ? xs.first : nil);
        }
        // 第四步
        return [RACTuple tupleWithObjectsFromArray:values];
    }];
}

```

join: block: 的实现可以分为4步：

1. 依次打包各个信号流，把每个信号流都打包成元组RACTuple。首先第一个信号流打包成一个元组，这个元组里面就一个信号。接着把第一个元组和第二个信号执行block( )闭包里面的操作。传入的block( )闭包执行的是zipWith:的操作。这个操作是把两个信号“压”在一起。具体实现分析请看[第一篇文章](https://halfrost.com/reactivecocoa_racsignal/)里面分析过的，这里就不再赘述了。得到第二个元组，里面装着是第一个元组和第二个信号。之后每次循环都执行类似的操作，再把第二个元组和第三个信号进行zipWith:操作，以此类推下去，直到所有的信号流都循环一遍。

2. 经过第一步的循环操作之后，还是nil，那么肯定就是空信号了，就返回empty信号。

3. 这一步是把之前第一步打包出来的结果，还原回原信号的过程。经过第一步的循环之后，current会是类似这个样子，(((1), 2), 3)，第三步就是为了把这种多重元组解出来，每个信号流都依次按照顺序放在数组里。注意观察current的特点，最外层的元组，是一个值和一个元组，所以从最外层的元组开始，一层一层往里“剥”。while循环每次都取最外层元组的last，即那个单独的值，插入到数组的第0号位置，然后取出first即是里面一层的元组。然后依次循环。由于每次都插入到数组0号的位置，类似于链表的头插法，最终数组里面的顺序肯定也保证是原信号的顺序。

4. 第四步就是把还原成原信号的顺序的数组包装成元组，返回给map操作的闭包。

```objectievec

+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array {
    return [self tupleWithObjectsFromArray:array convertNullsToNils:NO];
}

+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert {
    RACTuple *tuple = [[self alloc] init];
    
    if (convert) {
        NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
        for (id object in array) {
            [newArray addObject:(object == NSNull.null ? RACTupleNil.tupleNil : object)];
        }
        tuple.backingArray = newArray;
    } else {
        tuple.backingArray = [array copy];
    }
    
    return tuple;
}

```


在转换过程中，入参convertNullsToNils的含义是，是否把数组里面的NSNull转换成RACTupleNil。

这里转换传入的是NO，所以就是把数组原封不动的copy一份。


测试代码:

```objectivec

    RACSignal *signalD = [RACSignal interval:3 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalO = [RACSignal interval:1 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalE = [RACSignal interval:4 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalB = [RACStream zip:@[signalD,signalO,signalE]];
    
    [signalB subscribeNext:^(id x) {
        NSLog(@"最后接收到的值 = %@",x);
    }];


```


打印输出：

```vim

2016-11-29 13:07:57.349 最后接收到的值 = <RACTuple: 0x608000011440> (
    "2016-11-29 05:07:56 +0000",
    "2016-11-29 05:07:54 +0000",
    "2016-11-29 05:07:57 +0000"
)

2016-11-29 13:08:01.350 最后接收到的值 = <RACTuple: 0x608000010c60> (
    "2016-11-29 05:07:59 +0000",
    "2016-11-29 05:07:55 +0000",
    "2016-11-29 05:08:01 +0000"
)

2016-11-29 13:08:05.352 最后接收到的值 = <RACTuple: 0x60000001a350> (
    "2016-11-29 05:08:02 +0000",
    "2016-11-29 05:07:56 +0000",
    "2016-11-29 05:08:05 +0000"
)

```

最后输出的信号以时间最长的为主，最后接到的信号是一个元组，里面依次包含zip:数组里每个信号在一次“压”缩周期里面的值。


#### 7. zip: reduce: (在父类RACStream中定义的)

```objectivec

+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    RACStream *result = [self zip:streams];
    if (reduceBlock != nil) result = [result reduceEach:reduceBlock];
    return [result setNameWithFormat:@"+zip: %@ reduce:", streams];
}

```

zip: reduce:是一个组合的方法。具体实现可以拆分成两部分，第一部分是先执行zip:，把数组里面的信号流依次都进行组合。这一过程的实现在上一个变换实现中分析过了。zip:完成之后，紧接着进行reduceEach:操作。


这里有一个判断reduceBlock是否为nil的判断，这个判断是针对老版本的“历史遗留问题”。在ReactiveCocoa 2.5之前的版本，是允许reduceBlock传入nil，这里为了防止崩溃，所以加上了这个reduceBlock是否为nil的判断。


```objectivec

- (instancetype)reduceEach:(id (^)())reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self map:^(RACTuple *t) {
        NSCAssert([t isKindOfClass:RACTuple.class], @"Value from stream %@ is not a tuple: %@", stream, t);
        return [RACBlockTrampoline invokeBlock:reduceBlock withArguments:t];
    }] setNameWithFormat:@"[%@] -reduceEach:", self.name];
}

```

reduceEach:操作在[上篇](https://halfrost.com/reactivecocoa_racsignal_operations1/)已经分析过了。它会动态的构造闭包，对原信号每个元组，执行reduceBlock( )闭包里面的方法。具体分析见上篇。一般用法如下：

```objectivec

   [RACStream zip:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
       return [NSString stringWithFormat:@"%@: %@", string, number];
   }];

```



#### 8. zipWith: (在父类RACStream中定义的)


```objectivec

- (instancetype)zipWith:(RACStream *)stream {
    return nil;
}

```

这个方法就是在父类的RACStream中定义了，具体实现还要看RACStream各个子类的实现。

它就可以类比concat:在父类中的实现，也是直接返回一个nil。

```objectivec

- (instancetype)concat:(RACStream *)stream { return nil;}

```
在[第一篇](https://halfrost.com/reactivecocoa_racsignal/)中分析了concat:和zipWith:在RACSignal子类中具体实现。忘记了具体实现的可以回去看看。

#### 9. combineLatestWith:

```objectivec

- (RACSignal *)combineLatestWith:(RACSignal *)signal {
    NSCParameterAssert(signal != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        // 初始化第一个信号的一些标志变量
        __block id lastSelfValue = nil;
        __block BOOL selfCompleted = NO;
        
        // 初始化第二个信号的一些标志变量
        __block id lastOtherValue = nil;
        __block BOOL otherCompleted = NO;

        // 这里是一个判断是否sendNext的闭包
        void (^sendNext)(void) = ^{ };
        
        // 订阅第一个信号
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) { }];
        [disposable addDisposable:selfDisposable];
        
        // 订阅第二个信号
        RACDisposable *otherDisposable = [signal subscribeNext:^(id x) { }];
        [disposable addDisposable:otherDisposable];
        
        return disposable;
    }] setNameWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
}

```

大体实现思路比较简单，在新信号里面分别订阅原信号和入参signal信号。

```objectivec


RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
    @synchronized (disposable) {
        lastSelfValue = x ?: RACTupleNil.tupleNil;
        sendNext();
    }
} error:^(NSError *error) {
    [subscriber sendError:error];
} completed:^{
    @synchronized (disposable) {
        selfCompleted = YES;
        if (otherCompleted) [subscriber sendCompleted];
    }
}];

```

先来看看原信号订阅的具体实现：

在subscribeNext闭包中，记录下原信号最新发送的x值，并保存到lastSelfValue中。从此lastSelfValue变量每次都保存原信号发送过来的最新的值。然后再调用sendNext( )闭包。

在completed闭包中，selfCompleted中记录下原信号发送完成。这是还要判断otherCompleted是否完成，即入参信号signal是否发送完成，只有两者都发送完成了，组合的新信号才能算全部发送完成。

```objectivec

RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
    @synchronized (disposable) {
        lastOtherValue = x ?: RACTupleNil.tupleNil;
        sendNext();
    }
} error:^(NSError *error) {
    [subscriber sendError:error];
} completed:^{
    @synchronized (disposable) {
        otherCompleted = YES;
        if (selfCompleted) [subscriber sendCompleted];
    }
}];


```

这是对入参信号signal的处理实现。和原信号的处理方式完全一致。现在重点就要看看sendNext( )闭包中都做了些什么。


```objectivec

void (^sendNext)(void) = ^{
    @synchronized (disposable) {
        if (lastSelfValue == nil || lastOtherValue == nil) return;
        [subscriber sendNext:RACTuplePack(lastSelfValue, lastOtherValue)];
    }
};

```

在sendNext( )闭包中，如果lastSelfValue 或者 lastOtherValue 其中之一有一个为nil，就return，因为这个时候无法结合在一起。当两个信号都有值，那么就把这两个信号的最新的值打包成元组发送出来。


![](https://img.halfrost.com/Blog/ArticleImage/33_18.png)



可以看到，每个信号每发送出来一个新的值，都会去找另外一个信号上一个最新的值进行结合。


这里可以对比一下类似的zip:操作


![](https://img.halfrost.com/Blog/ArticleImage/33_19.png)


zip:操作是会把新来的信号的值存起来，放在数组里，然后另外一个信号发送一个值过来就和数组第0位的值相互结合成新的元组信号发送出去，并分别移除数组里面第0位的两个值。zip:能保证每次结合的值都是唯一的，不会一个原信号的值被多次结合到新的元组信号中。但是combineLatestWith:是不能保证这一点的，在原信号或者另外一个信号新信号发送前，每次发送信号都会结合当前最新的信号，这里就会有反复结合的情况。

#### 10. combineLatest:

```objectivec

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
    return [[self join:signals block:^(RACSignal *left, RACSignal *right) {
        return [left combineLatestWith:right];
    }] setNameWithFormat:@"+combineLatest: %@", signals];
}

```

combineLatest:的实现就是把入参数组里面的每个信号都调用一次join: block:方法。传入的闭包是把两个信号combineLatestWith:一下。combineLatest:的实现就是2个操作的组合。具体实现上面也都分析过，这里不再赘述。


#### 11. combineLatest: reduce:

```objectivec

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    RACSignal *result = [self combineLatest:signals];
    if (reduceBlock != nil) result = [result reduceEach:reduceBlock]; 
    return [result setNameWithFormat:@"+combineLatest: %@ reduce:", signals];
}


```

combineLatest: reduce: 的实现可以类比zip: reduce:的实现。

具体实现可以拆分成两部分，第一部分是先执行combineLatest:，把数组里面的信号流依次都进行组合。这一过程的实现在上一个变换实现中分析过了。combineLatest:完成之后，紧接着进行reduceEach:操作。

这里有一个判断reduceBlock是否为nil的判断，这个判断是针对老版本的“历史遗留问题”。在ReactiveCocoa 2.5之前的版本，是允许reduceBlock传入nil，这里为了防止崩溃，所以加上了这个reduceBlock是否为nil的判断。


#### 12. combinePreviousWithStart: reduce:(在父类RACStream中定义的)

这个方法的实现也是多个变换操作组合在一起的。

```objectivec

- (instancetype)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id next))reduceBlock {
    NSCParameterAssert(reduceBlock != NULL);
    return [[[self
              scanWithStart:RACTuplePack(start)
              reduce:^(RACTuple *previousTuple, id next) {
                  id value = reduceBlock(previousTuple[0], next);
                  return RACTuplePack(next, value);
              }]
             map:^(RACTuple *tuple) {
                 return tuple[1];
             }]
            setNameWithFormat:@"[%@] -combinePreviousWithStart: %@ reduce:", self.name, [start rac_description]];
}


```


combinePreviousWithStart: reduce:的实现完全可以类比scanWithStart:reduce:的实现。举个例子来说明他们俩的不同。

```objectivec

      RACSequence *numbers = @[ @1, @2, @3, @4 ].rac_sequence;

      RACSignal *signalA = [numbers combinePreviousWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
          return @(previous.integerValue + next.integerValue);
      }].signal;

    RACSignal *signalB = [numbers scanWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
        return @(previous.integerValue + next.integerValue);
    }].signal;

```


signalA输出如下：

```vim

1
3
5
7

```

signalB输出如下：

```vim

1
3
6
10

```

现在应该不同点应该很明显了。combinePreviousWithStart: reduce:实现的是两两之前的加和，而scanWithStart:reduce:实现的累加。

为什么会这样呢，具体看看combinePreviousWithStart: reduce:的实现。

虽然combinePreviousWithStart: reduce:也是调用了scanWithStart:reduce:，但是初始值是RACTuplePack(start)元组，聚合reduce的过程也有所不同：

```objectivec

id value = reduceBlock(previousTuple[0], next); 
return RACTuplePack(next, value);

```


依次调用reduceBlock( )闭包，传入previousTuple[0], next，这里reduceBlock( )闭包是进行累加的操作，所以就是把前一个元组的第0位加上后面新来的信号的值。得到的值拼成新的元组，新的元组由next和value值构成。

如果打印出上述例子中combinePreviousWithStart: reduce:的加合过程中每个信号的值，如下：

```objectivec

<RACTuple: 0x608000200010> (
    1,
    1
)

<RACTuple: 0x60000001fe70> (
    2,
    3
)
<RACTuple: 0x60000001fe90> (
    3,
    5
)
<RACTuple: 0x60000001feb0> (
    4,
    7
)

```

由于这样拆成元组之后，下次再进行操作的时候，还可以拿到前一个信号的值，这样就不会形成累加的效果。


#### 13. sample:

```objectivec

- (RACSignal *)sample:(RACSignal *)sampler {
    NSCParameterAssert(sampler != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        NSLock *lock = [[NSLock alloc] init];
        __block id lastValue;
        __block BOOL hasValue = NO;
        
        RACSerialDisposable *samplerDisposable = [[RACSerialDisposable alloc] init];
        RACDisposable *sourceDisposable = [self subscribeNext:^(id x) { // 暂时省略 }];
        
        samplerDisposable.disposable = [sampler subscribeNext:^(id _) { // 暂时省略 }];
        
        return [RACDisposable disposableWithBlock:^{
            [samplerDisposable dispose];
            [sourceDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -sample: %@", self.name, sampler];
}

```

sample:内部实现也是对原信号和入参信号sampler分别进行订阅。具体实现就是这两个信号订阅内部都干了些什么。


```objectivec

RACSerialDisposable *samplerDisposable = [[RACSerialDisposable alloc] init];
RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
    [lock lock];
    hasValue = YES;
    lastValue = x;
    [lock unlock];
} error:^(NSError *error) {
    [samplerDisposable dispose];
    [subscriber sendError:error];
} completed:^{
    [samplerDisposable dispose];
    [subscriber sendCompleted];
}];

```

这是对原信号的操作，原信号的操作在subscribeNext中就记录了两个变量的值，hasValue记录原信号有值，lastValue记录了原信号的最新的值。这里加了一层NSLock锁进行保护。

在发生error的时候，先把sampler信号取消订阅，然后再sendError:。当原信号完成的时候，同样是先把sampler信号取消订阅，然后再sendCompleted。



```objectivec

samplerDisposable.disposable = [sampler subscribeNext:^(id _) {
    BOOL shouldSend = NO;
    id value;
    [lock lock];
    shouldSend = hasValue;
    value = lastValue;
    [lock unlock];
    
    if (shouldSend) {
        [subscriber sendNext:value];
    }
} error:^(NSError *error) {
    [sourceDisposable dispose];
    [subscriber sendError:error];
} completed:^{
    [sourceDisposable dispose];
    [subscriber sendCompleted];
}];


```

这是对入参信号sampler的操作。shouldSend默认值是NO，这个变量控制着是否sendNext:值。只有当原信号有值的时候，hasValue = YES，所以shouldSend = YES，这个时候才能发送原信号的值。这里我们并不关心入参信号sampler的值，从subscribeNext:^(id \_)这里可以看出， \_代表并不需要它的值。


在发生error的时候，先把原信号取消订阅，然后再sendError:。当sampler信号完成的时候，同样是先把原信号取消订阅，然后再sendCompleted。


![](https://img.halfrost.com/Blog/ArticleImage/33_20_.png)



经过sample:变换就会变成这个样子。只是把原信号的值都移动到了sampler信号发送信号的时刻，值还是和原信号的值一样。


### 最后

关于RACSignal的变换操作还剩下 冷热信号转换操作，高阶信号操作，下篇接着继续分析。最后请大家多多指教。

