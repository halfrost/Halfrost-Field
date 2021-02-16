# ReactiveCocoa 中 RACSignal 所有变换操作底层实现分析(上)


![](https://img.halfrost.com/Blog/ArticleTitleImage/32_0_.png)



### 前言

在[上篇文章](https://halfrost.com/reactivecocoa_racsignal/)中，详细分析了RACSignal是创建和订阅的详细过程。看到底层源码实现后，就能发现，ReactiveCocoa这个FRP的库，实现响应式（RP）是用Block闭包来实现的，而并不是用KVC / KVO实现的。


在ReactiveCocoa整个库中，RACSignal占据着比较重要的位置，而RACSignal的变换操作更是整个RACStream流操作核心之一。在上篇文章中也详细分析了bind操作的实现。RACsignal很多变换操作都是基于bind操作来实现的。在开始本篇底层实现分析之前，先简单回顾一下上篇文章中分析的bind函数，这是这篇文章分析的基础。


bind函数可以简单的缩写成下面这样子。

```objectivec

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block;
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        RACStreamBindBlock bindBlock = block();
        [self subscribeNext:^(id x) {    //(1)
            BOOL stop = NO;
            RACSignal *signal = (RACSignal *)bindBlock(x, &stop); //(2)
            if (signal == nil || stop) {
                [subscriber sendCompleted];
            } else {
                [signal subscribeNext:^(id x) {
                    [subscriber sendNext:x];  //(3)
                } error:^(NSError *error) {
                    [subscriber sendError:error];
                } completed:^{
                
                }];
            }
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            [subscriber sendCompleted];
        }];
        return nil;
    }];
}


```


当bind变换之后的信号被订阅，就开始执行bind函数中return的block闭包。

1. 在bind闭包中，先订阅原先的信号A。
2. 在订阅原信号A的didSubscribe闭包中进行信号变换，变换中用到的block闭包是外部传递进来的，也就是bind函数的入参。变换结束，得到新的信号B
3. 订阅新的信号B，拿到bind变化之后的信号的订阅者subscriber，对其发送新的信号值。


![](https://img.halfrost.com/Blog/ArticleImage/32_1.png)


简要的过程如上图，bind函数中进行了2次订阅的操作，第一次订阅是为了拿到signalA的值，第二次订阅是为了把signalB的新值发给bind变换之后得到的signalB的订阅者。


回顾完bind底层实现之后，就可以开始继续本篇文章的分析了。

### 目录

- 1.变换操作
- 2.时间操作

### 一.变换操作


![](https://img.halfrost.com/Blog/ArticleImage/32_2.png)



我们都知道RACSignal是继承自RACStream的，而在底层的RACStream上也定义了一些基本的信号变换的操作，所以这些操作在RACSignal上同样适用。如果在RACsignal中没有重写这些方法，那么调用这些操作，实际是调用的父类RACStream的操作。下面分析的时候，会把实际调用父类RACStream的操作的地方都标注出来。

#### 1.Map: (在父类RACStream中定义的)

map操作一般是用来信号变换的。

```objectivec

    RACSignal *signalB = [signalA map:^id(NSNumber *value) {
        return @([value intValue] * 10);
    }];

```

![](https://img.halfrost.com/Blog/ArticleImage/32_3.png)


来看看底层是如何实现的。

```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```

这里实现代码比较严谨，先判断self的类型。因为RACStream的子类中会有一些子类会重写这些方法，所以需要判断self的类型，在回调中可以回调到原类型的方法中去。

由于本篇文章中我们都分析RACSignal的操作，所以这里的self.class是RACDynamicSignal类型的。相应的在return返回值中也返回class，即RACDynamicSignal类型的信号。

从map实现代码上来看，map实现是用了flattenMap函数来实现的。把map的入参闭包，放到了flattenMap的返回值中。

在来看看flattenMap的实现：

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

flattenMap算是对bind函数的一种封装。bind函数的入参是一个RACStreamBindBlock类型的闭包。而flattenMap函数的入参是一个value，返回值RACStream类型的闭包。

在flattenMap中，返回block(value)的信号，如果信号为nil，则返回[class empty]。

先来看看为空的情况。当block(value)为空，返回[RACEmptySignal empty]，empty就是创建了一个RACEmptySignal类型的信号：

```objectivec

+ (RACSignal *)empty {
#ifdef DEBUG
    // Create multiple instances of this class in DEBUG so users can set custom
    // names on each.
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

RACEmptySignal类型的信号又是什么呢？

```objectivec


- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```

RACEmptySignal是RACSignal的子类，一旦订阅它，它就会同步的发送completed完成信号给订阅者。

所以flattenMap返回一个信号，如果信号不存在，就返回一个completed完成信号给订阅者。

再来看看flattenMap返回的信号是怎么变换的。

block(value)会把原信号发送过来的value传递给flattenMap的入参。flattenMap的入参是一个闭包，闭包的参数也是value的：

```objectivec

^(id value) { return [class return:block(value)]; }

```

这个闭包返回一个信号，信号类型和原信号的类型一样，即RACDynamicSignal类型的，值是block(value)。这里的闭包是外面map传进来的：

```objectivec

^id(NSNumber *value) { return @([value intValue] * 10); }

```

在这个闭包中把原信号的value值传进去进行变换，变换结束之后，包装成和原信号相同类型的信号，返回。返回的信号作为bind函数的闭包的返回值。这样订阅新的map之后的信号就会拿到变换之后的值。

#### 2.MapReplace: (在父类RACStream中定义的)

一般用法如下：

```objectivec

RACSignal *signalB = [signalA mapReplace:@"A"];

```

![](https://img.halfrost.com/Blog/ArticleImage/32_4.png)


效果是不管A信号发送什么值，都替换成@“A”。

```objectivec

- (instancetype)mapReplace:(id)object {
    return [[self map:^(id _) {
        return object;
    }] setNameWithFormat:@"[%@] -mapReplace: %@", self.name, [object rac_description]];
}

```

看底层源码就知道，它并不去关心原信号发送的是什么值，原信号发送什么值，都返回入参object的值。


#### 3.reduceEach:   (在父类RACStream中定义的)


reduce是减少，聚合在一起的意思，reduceEach就是每个信号内部都聚合在一起。

```objectivec

    RACSignal *signalB = [signalA reduceEach:^id(NSNumber *num1 , NSNumber *num2){
        return @([num1 intValue] + [num2 intValue]);
    }];


```

![](https://img.halfrost.com/Blog/ArticleImage/32_5.png)

reduceEach后面必须传入一个元组RACTuple类型，否则会报错。

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

这里有两个断言，一个是判断传入的reduceBlock闭包是否为空，另一个断言是判断闭包的入参是否是RACTuple类型的。

```objectivec

@interface RACBlockTrampoline : NSObject
@property (nonatomic, readonly, copy) id block;
+ (id)invokeBlock:(id)block withArguments:(RACTuple *)arguments;
@end

```

RACBlockTrampoline就是一个保存了一个block闭包的对象，它会根据传进来的参数，动态的构造一个NSInvocation，并执行。

reduceEach把入参reduceBlock作为RACBlockTrampoline的入参invokeBlock传进去，以及每个RACTuple也传到RACBlockTrampoline中。

```objectivec

- (id)invokeWithArguments:(RACTuple *)arguments {
    SEL selector = [self selectorForArgumentCount:arguments.count];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
    invocation.selector = selector;
    invocation.target = self;
    
    for (NSUInteger i = 0; i < arguments.count; i++) {
        id arg = arguments[i];
        NSInteger argIndex = (NSInteger)(i + 2);
        [invocation setArgument:&arg atIndex:argIndex];
    }
    
    [invocation invoke];
    
    __unsafe_unretained id returnVal;
    [invocation getReturnValue:&returnVal];
    return returnVal;
}

```

第一步就是先计算入参一个元组RACTuple里面元素的个数。


```objectivec

- (SEL)selectorForArgumentCount:(NSUInteger)count {
    NSCParameterAssert(count > 0);
    
    switch (count) {
        case 0: return NULL;
        case 1: return @selector(performWith:);
        case 2: return @selector(performWith::);
        case 3: return @selector(performWith:::);
        case 4: return @selector(performWith::::);
        case 5: return @selector(performWith:::::);
        case 6: return @selector(performWith::::::);
        case 7: return @selector(performWith:::::::);
        case 8: return @selector(performWith::::::::);
        case 9: return @selector(performWith:::::::::);
        case 10: return @selector(performWith::::::::::);
        case 11: return @selector(performWith:::::::::::);
        case 12: return @selector(performWith::::::::::::);
        case 13: return @selector(performWith:::::::::::::);
        case 14: return @selector(performWith::::::::::::::);
        case 15: return @selector(performWith:::::::::::::::);
    }
    
    NSCAssert(NO, @"The argument count is too damn high! Only blocks of up to 15 arguments are currently supported.");
    return NULL;
}

```

可以看到最多支持元组内元素的个数是15个。

这里我们假设以元组里面有2个元素为例。

```objectivec

- (id)performWith:(id)obj1 :(id)obj2 {
    id (^block)(id, id) = self.block;
    return block(obj1, obj2);
}

```

对应的[Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html)如下：

![](https://img.halfrost.com/Blog/ArticleImage/32_6.png)

argument0和argument1分别对应着隐藏参数self和\_cmd，所以对应着的类型是@和：，从argument2开始，就是入参的Type Encoding了。

所以在构造invocation的参数的时候，argIndex是要偏移2个位置的。即从(i + 2)开始设置参数。

当动态构造了一个invocation方法之后，[invocation invoke]调用这个动态方法，也就是执行了外部的reduceBlock闭包，闭包里面是我们想要信号变换的规则。

闭包执行结束得到returnVal返回值。这个返回值就是整个RACBlockTrampoline的返回值了。这个返回值也作为了map闭包里面的返回值。

接下去的操作就完全转换成了map的操作了。上面已经分析过map操作了，这里就不赘述了。

#### 4. reduceApply

举个例子：

```objectivec

    RACSignal *signalA = [RACSignal createSignal:
                         ^RACDisposable *(id<RACSubscriber> subscriber)
                         {
                             id block = ^id(NSNumber *first,NSNumber *second,NSNumber *third) {
                                 return @(first.integerValue + second.integerValue * third.integerValue);
                             };
                             
                             [subscriber sendNext:RACTuplePack(block,@2 , @3 , @8)];
                             [subscriber sendNext:RACTuplePack((id)(^id(NSNumber *x){return @(x.intValue * 10);}),@9,@10,@30)];

                             [subscriber sendCompleted];
                             return [RACDisposable disposableWithBlock:^{
                                 NSLog(@"signal dispose");
                             }];
                         }];

    RACSignal *signalB = [signalA reduceApply];


```

使用reduceApply的条件也是需要信号里面的值是元组RACTuple。不过这里和reduceEach不同的是，原信号中每个元祖RACTuple的第0位必须要为一个闭包，后面n位为这个闭包的入参，第0位的闭包有几个参数，后面就需要跟几个参数。

如上述例子中，第一个元组第0位的闭包有3个参数，所以第一个元组后面还要跟3个参数。第二个元组的第0位的闭包只有一个参数，所以后面只需要跟一个参数。

当然后面可以跟更多的参数，如第二个元组，闭包后面跟了3个参数，但是只有第一个参数是有效值，后面那2个参数是无效不起作用的。唯一需要注意的就是后面跟的参数个数一定不能少于第0位闭包入参的个数，否则就会报错。

上面例子输出

```vim

26  // 26 = 2 + 3 * 8；
90  // 90 = 9 * 10；

```

看看底层实现：

```objectivec


- (RACSignal *)reduceApply {
    return [[self map:^(RACTuple *tuple) {
        NSCAssert([tuple isKindOfClass:RACTuple.class], @"-reduceApply must only be used on a signal of RACTuples. Instead, received: %@", tuple);
        NSCAssert(tuple.count > 1, @"-reduceApply must only be used on a signal of RACTuples, with at least a block in tuple[0] and its first argument in tuple[1]");
        
        // We can't use -array, because we need to preserve RACTupleNil
        NSMutableArray *tupleArray = [NSMutableArray arrayWithCapacity:tuple.count];
        for (id val in tuple) {
            [tupleArray addObject:val];
        }
        RACTuple *arguments = [RACTuple tupleWithObjectsFromArray:[tupleArray subarrayWithRange:NSMakeRange(1, tupleArray.count - 1)]];
        
        return [RACBlockTrampoline invokeBlock:tuple[0] withArguments:arguments];
    }] setNameWithFormat:@"[%@] -reduceApply", self.name];
}


```

这里也有2个断言，第一个是确保传入的参数是RACTuple类型，第二个断言是确保元组RACTuple里面的元素各种至少是2个。因为下面取参数是直接从1号位开始取的。

reduceApply做的事情和reduceEach基本是等效的，只不过变换规则的block闭包一个是外部传进去的，一个是直接打包在每个信号元组RACTuple中第0位中。


#### 5. materialize

这个方法会把信号包装成RACEvent类型。

```objectivec


- (RACSignal *)materialize {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [self subscribeNext:^(id x) {
            [subscriber sendNext:[RACEvent eventWithValue:x]];
        } error:^(NSError *error) {
            [subscriber sendNext:[RACEvent eventWithError:error]];
            [subscriber sendCompleted];
        } completed:^{
            [subscriber sendNext:RACEvent.completedEvent];
            [subscriber sendCompleted];
        }];
    }] setNameWithFormat:@"[%@] -materialize", self.name];
}

```

sendNext会包装成[RACEvent eventWithValue:x]，error会包装成[RACEvent eventWithError:error]，completed会被包装成RACEvent.completedEvent。注意，当原信号error和completed，新信号都会发送sendCompleted。


#### 6. dematerialize

这个操作是materialize的逆向操作。它会把包装成RACEvent信号重新还原为正常的值信号。


```objectivec

- (RACSignal *)dematerialize {
    return [[self bind:^{
        return ^(RACEvent *event, BOOL *stop) {
            switch (event.eventType) {
                case RACEventTypeCompleted:
                    *stop = YES;
                    return [RACSignal empty];
                    
                case RACEventTypeError:
                    *stop = YES;
                    return [RACSignal error:event.error];
                    
                case RACEventTypeNext:
                    return [RACSignal return:event.value];
            }
        };
    }] setNameWithFormat:@"[%@] -dematerialize", self.name];
}

```

这里的实现也用到了bind函数，它会把原信号进行一个变换。新的信号会根据event.eventType进行转换。RACEventTypeCompleted被转换成[RACSignal empty]，RACEventTypeError被转换成[RACSignal error:event.error]，RACEventTypeNext被转换成[RACSignal return:event.value]。

#### 7. not

```objectivec

- (RACSignal *)not {
    return [[self map:^(NSNumber *value) {
        NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);
        
        return @(!value.boolValue);
    }] setNameWithFormat:@"[%@] -not", self.name];
}


```

not操作需要传入的值都是NSNumber类型的。不是NSNumber类型会报错。not操作会把每个NSNumber按照BOOL的规则，取非，当成新信号的值。


#### 8. and


```objectivec

- (RACSignal *)and {
    return [[self map:^(RACTuple *tuple) {
        NSCAssert([tuple isKindOfClass:RACTuple.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
        NSCAssert(tuple.count > 0, @"-and must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");
        
        return @([tuple.rac_sequence all:^(NSNumber *number) {
            NSCAssert([number isKindOfClass:NSNumber.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);
            
            return number.boolValue;
        }]);
    }] setNameWithFormat:@"[%@] -and", self.name];
}

```

and操作需要原信号的每个信号都是元组RACTuple类型的，因为只有这样，RACTuple类型里面的每个元素的值才能进行&运算。

and操作里面有3处断言。第一处，判断入参是不是元组RACTuple类型的。第二处，判断RACTuple类型里面至少包含一个NSNumber。第三处，判断RACTuple里面是否都是NSNumber类型，有一个不符合，都会报错。

```objectivec

- (RACSequence *)rac_sequence {
    return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

```

RACTuple类型先转换成RACTupleSequence。

```objectivec

+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset {
    NSCParameterAssert(offset <= backingArray.count);
    
    if (offset == backingArray.count) return self.empty;
    
    RACTupleSequence *seq = [[self alloc] init];
    seq->_tupleBackingArray = backingArray;
    seq->_offset = offset;
    return seq;
}

```

backingArray是一个数组NSArry。这里关于RACTupleSequence和RACTuple会在以后的文章中详细分析，本篇以分析RACSignal为主。


RACTuple类型先转换成RACTupleSequence，即存成了一个数组。

```objectivec

- (BOOL)all:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    NSNumber *result = [self foldLeftWithStart:@YES reduce:^(NSNumber *accumulator, id value) {
        return @(accumulator.boolValue && block(value));
    }];
    
    return result.boolValue;
}

- (id)foldLeftWithStart:(id)start reduce:(id (^)(id, id))reduce {
    NSCParameterAssert(reduce != NULL);
    
    if (self.head == nil) return start;
    
    for (id value in self) {
        start = reduce(start, value);
    }
    
    return start;
}

```

for会遍历RACSequence里面存的每一个值，分别都去调用reduce( )闭包。start的初始值为YES。reduce( )闭包是：

```objectivec

^(NSNumber *accumulator, id value) { return @(accumulator.boolValue && block(value)); }

```

这里又会去调用block( )闭包：

```objectivec

^(NSNumber *number) { return number.boolValue; }

```

number是原信号RACTuple的第一个值。第一次循环reduce( )闭包是拿YES和原信号RACTuple的第一个值进行&计算。第二个循环reduce( )闭包是拿原信号RACTuple的第一个值和第二个值进行&计算，得到的值参与下一次循环，与第三个值进行&计算，如此下去。这也是折叠函数的意思，foldLeft从左边开始折叠。fold函数会从左至右，把RACTuple转换成的数组里面每个值都一个接着一个进行&计算。

每个RACTuple都map成这样的一个BOOL值。接下去信号就map成了一个新的信号。

#### 9. or

```objectivec


- (RACSignal *)or {
    return [[self map:^(RACTuple *tuple) {
        NSCAssert([tuple isKindOfClass:RACTuple.class], @"-or must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
        NSCAssert(tuple.count > 0, @"-or must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");
        
        return @([tuple.rac_sequence any:^(NSNumber *number) {
            NSCAssert([number isKindOfClass:NSNumber.class], @"-or must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);
            
            return number.boolValue;
        }]);
    }] setNameWithFormat:@"[%@] -or", self.name];
}

```

or操作的实现和and操作的实现大体类似。3处断言的作用和and操作完全一致，这里就不再赘述了。or操作的重点在any函数的实现上。or操作的入参也必须是RACTuple类型的。

```objectivec


- (BOOL)any:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    return [self objectPassingTest:block] != nil;
}


- (id)objectPassingTest:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    return [self filter:block].head;
}


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

any会依次判断RACTupleSequence数组里面的值，依次每个进行filter。如果value对应的BOOL值是YES，就转换成一个RACTupleSequence信号。如果对应的是NO，则转换成一个empty信号。

只要RACTuple为NO，就一直返回empty信号，直到BOOL值为YES，就返回1。map变换信号后变成成1。找到了YES之后的值就不会再判断了。如果没有找到YES，中间都是NO的话，一直遍历到数组最后一个，信号只能返回0。

#### 10. any:

```objectivec


- (RACSignal *)any:(BOOL (^)(id object))predicateBlock {
    NSCParameterAssert(predicateBlock != NULL);
    
    return [[[self materialize] bind:^{
        return ^(RACEvent *event, BOOL *stop) {
            if (event.finished) {
                *stop = YES;
                return [RACSignal return:@NO];
            }
            
            if (predicateBlock(event.value)) {
                *stop = YES;
                return [RACSignal return:@YES];
            }
            
            return [RACSignal empty];
        };
    }] setNameWithFormat:@"[%@] -any:", self.name];
}

```

原信号会先经过materialize转换包装成RACEvent事件。依次判断predicateBlock(event.value)值的BOOL值，如果返回YES，就包装成RACSignal的新信号，发送YES出去，并且stop接下来的信号。如果返回MO，就返回[RACSignal empty]空信号。直到event.finished，返回[RACSignal return:@NO]。

所以any:操作的目的是找到第一个满足predicateBlock条件的值。找到了就返回YES的RACSignal的信号，如果没有找到，返回NO的RACSignal。

#### 11. any

```objectivec

- (RACSignal *)any {
    return [[self any:^(id x) {
        return YES;
    }] setNameWithFormat:@"[%@] -any", self.name];
}

```

any操作是any:操作中的一种情况。即predicateBlock闭包永远都返回YES，所以any操作之后永远都只能得到一个只发送一个YES的新信号。

#### 12. all:


```objectivec


- (RACSignal *)all:(BOOL (^)(id object))predicateBlock {
    NSCParameterAssert(predicateBlock != NULL);
    
    return [[[self materialize] bind:^{
        return ^(RACEvent *event, BOOL *stop) {
            if (event.eventType == RACEventTypeCompleted) {
                *stop = YES;
                return [RACSignal return:@YES];
            }
            
            if (event.eventType == RACEventTypeError || !predicateBlock(event.value)) {
                *stop = YES;
                return [RACSignal return:@NO];
            }
            
            return [RACSignal empty];
        };
    }] setNameWithFormat:@"[%@] -all:", self.name];
}

```

all:操作和any:有点类似。原信号会先经过materialize转换包装成RACEvent事件。对原信号发送的每个信号都依次判断predicateBlock(event.value)是否是NO 或者event.eventType == RACEventTypeError。如果predicateBlock(event.value)返回NO或者出现了错误，新的信号都返回NO。如果一直都没出现问题，在RACEventTypeCompleted的时候发送YES。

all:可以用来判断整个原信号发送过程中是否有错误事件RACEventTypeError，或者是否存在predicateBlock为NO的情况。可以把predicateBlock设置成一个正确条件。如果原信号出现错误事件，或者不满足设置的错误条件，都会发送新信号返回NO。如果全过程都没有出错，或者都满足predicateBlock设置的条件，则一直到RACEventTypeCompleted，发送YES的新信号。





#### 13. repeat

```objectivec

- (RACSignal *)repeat {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return subscribeForever(self,
                                ^(id x) {
                                    [subscriber sendNext:x];
                                },
                                ^(NSError *error, RACDisposable *disposable) {
                                    [disposable dispose];
                                    [subscriber sendError:error];
                                },
                                ^(RACDisposable *disposable) {
                                    // Resubscribe.
                                });
    }] setNameWithFormat:@"[%@] -repeat", self.name];
}

```

repeat操作返回一个subscribeForever闭包，闭包里面要传入4个参数。

```objectivec

static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *)) {
    next = [next copy];
    error = [error copy];
    completed = [completed copy];
    
    RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
    
    RACSchedulerRecursiveBlock recursiveBlock = ^(void (^recurse)(void)) {
        RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
        [compoundDisposable addDisposable:selfDisposable];
        
        __weak RACDisposable *weakSelfDisposable = selfDisposable;
        
        RACDisposable *subscriptionDisposable = [signal subscribeNext:next error:^(NSError *e) {
            @autoreleasepool {
                error(e, compoundDisposable);
                [compoundDisposable removeDisposable:weakSelfDisposable];
            }
            
            recurse();
        } completed:^{
            @autoreleasepool {
                completed(compoundDisposable);
                [compoundDisposable removeDisposable:weakSelfDisposable];
            }
            
            recurse();
        }];
        
        [selfDisposable addDisposable:subscriptionDisposable];
    };
    
    // Subscribe once immediately, and then use recursive scheduling for any
    // further resubscriptions.
    recursiveBlock(^{
        RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];
        
        RACDisposable *schedulingDisposable = [recursiveScheduler scheduleRecursiveBlock:recursiveBlock];
        [compoundDisposable addDisposable:schedulingDisposable];
    });
    
    return compoundDisposable;
}


```

subscribeForever有4个参数，第一个参数是原信号，第二个是传入的next闭包，第三个是error闭包，最后一个是completed闭包。

subscribeForever一进入这个函数就会调用recursiveBlock( )闭包，闭包中有一个recurse( )的入参的参数。在recursiveBlock( )闭包中对原信号RACSignal进行订阅。next，error，completed分别会先调用传进来的闭包。然后error，completed执行完error( )和completed( )闭包之后，还会继续再执行recurse( )，recurse( )是recursiveBlock的入参。

```objectivec

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock {
    RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    [self scheduleRecursiveBlock:[recursiveBlock copy] addingToDisposable:disposable];
    return disposable;
}

- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable {
    @autoreleasepool {
        RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
        [disposable addDisposable:selfDisposable];
        
        __weak RACDisposable *weakSelfDisposable = selfDisposable;
        
        RACDisposable *schedulingDisposable = [self schedule:^{ // 此处省略 }];
        
        [selfDisposable addDisposable:schedulingDisposable];
    }
}
```

先取到当前的currentScheduler，即recursiveScheduler，执行scheduleRecursiveBlock，在这个函数中，会调用schedule函数。这里的recursiveScheduler是RACQueueScheduler类型的。

```objectivec

- (RACDisposable *)schedule:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
    RACDisposable *disposable = [[RACDisposable alloc] init];
    
    dispatch_async(self.queue, ^{
        if (disposable.disposed) return;
        [self performAsCurrentScheduler:block];
    });
    
    return disposable;
}

```

如果原信号没有disposed，dispatch\_async会继续执行block，在这个block中还会继续原信号的发送。所以原信号只要没有error信号，disposable.disposed就不会返回YES，就会一直调用block。所以在subscribeForever的error和completed的最后都会调用recurse( )闭包。error调用recurse( )闭包是为了结束调用block，结束所有的信号。completed调用recurse( )闭包是为了继续调用block( )闭包，也就是repeat的本质。原信号会继续发送信号，如此无限循环下去。



#### 14. retry:

```objectivec

- (RACSignal *)retry:(NSInteger)retryCount {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block NSInteger currentRetryCount = 0;
        return subscribeForever(self,
                                ^(id x) {
                                    [subscriber sendNext:x];
                                },
                                ^(NSError *error, RACDisposable *disposable) {
                                    if (retryCount == 0 || currentRetryCount < retryCount) {
                                        // Resubscribe.
                                        currentRetryCount++;
                                        return;
                                    }
                                    
                                    [disposable dispose];
                                    [subscriber sendError:error];
                                },
                                ^(RACDisposable *disposable) {
                                    [disposable dispose];
                                    [subscriber sendCompleted];
                                });
    }] setNameWithFormat:@"[%@] -retry: %lu", self.name, (unsigned long)retryCount];
}


```


在retry:的实现中，和repeat实现的区别是中间加入了一个currentRetryCount值。如果currentRetryCount > retryCount的话，就会在error中调用[disposable dispose]，这样subscribeForever就不会再无限循环下去了。

所以retry:操作的用途就是在原信号在出现error的时候，重试retryCount的次数，如果依旧error，那么就会停止重试。

如果原信号没有发生错误，那么原信号在发送结束，subscribeForever也就结束了。retry:操作对于没有任何error的信号相当于什么都没有发生。



#### 15. retry

```objectivec

- (RACSignal *)retry {
    return [[self retry:0] setNameWithFormat:@"[%@] -retry", self.name];
}

```

这里的retry操作就是一个无限重试的操作。因为retryCount设置成0之后，在error的闭包中中，retryCount 永远等于 0，原信号永远都不会被dispose，所以subscribeForever会一直无限重试下去。

同样的，如果对一个没有error的信号调用retry操作，也是不起任何作用的。



#### 16. scanWithStart: reduceWithIndex: (在父类RACStream中定义的)


先写出测试代码:

```objectivec

    RACSignal *signalA = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber)
                         {
                             [subscriber sendNext:@1];
                             [subscriber sendNext:@1];
                             [subscriber sendNext:@4];
                             return [RACDisposable disposableWithBlock:^{
                             }];
                         }];

    RACSignal *signalB = [signalA scanWithStart:@(2) reduceWithIndex:^id(NSNumber * running, NSNumber * next, NSUInteger index) {
        return @(running.intValue * next.intValue + index);
    }];

```

```vim

2    // 2 * 1 + 0 = 2
3    // 2 * 1 + 1 = 3
14   // 3 * 4 + 2 = 14

```

![](https://img.halfrost.com/Blog/ArticleImage/32_7.png)




```objectivec


- (instancetype)scanWithStart:(id)startingValue reduceWithIndex:(id (^)(id, id, NSUInteger))reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    
    Class class = self.class;
    
    return [[self bind:^{
        __block id running = startingValue;
        __block NSUInteger index = 0;
        
        return ^(id value, BOOL *stop) {
            running = reduceBlock(running, value, index++);
            return [class return:running];
        };
    }] setNameWithFormat:@"[%@] -scanWithStart: %@ reduceWithIndex:", self.name, [startingValue rac_description]];
}

```

scanWithStart这个变换由初始值，变换函数reduceBlock( )，和index步进的变量组成。原信号的每个信号都会由变换函数reduceBlock( )进行变换。index每次都是自增。变换的初始值是由入参startingValue传入的。


#### 17. scanWithStart: reduce: (在父类RACStream中定义的)


```objectivec

- (instancetype)scanWithStart:(id)startingValue reduce:(id (^)(id running, id next))reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    
    return [[self
             scanWithStart:startingValue
             reduceWithIndex:^(id running, id next, NSUInteger index) {
                 return reduceBlock(running, next);
             }]
            setNameWithFormat:@"[%@] -scanWithStart: %@ reduce:", self.name, [startingValue rac_description]];
}

```


![](https://img.halfrost.com/Blog/ArticleImage/32_8.png)





scanWithStart: reduce:就是scanWithStart: reduceWithIndex: 的缩略版。变换函数也是外面闭包reduceBlock( )传进来的。只不过变换过程中不会使用index自增的这个变量。


**通过使用scan这一系列的操作，可以有效的消除副作用操作！**

#### 18. aggregateWithStart: reduceWithIndex:

```objectivec

- (RACSignal *)aggregateWithStart:(id)start reduceWithIndex:(id (^)(id, id, NSUInteger))reduceBlock {
    return [[[[self
               scanWithStart:start reduceWithIndex:reduceBlock]
              startWith:start]
             takeLast:1]
            setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduceWithIndex:", self.name, [start rac_description]];
}

```


![](https://img.halfrost.com/Blog/ArticleImage/32_9.png)


aggregate是合计的意思。所以最后变换出来的信号只有最后一个值。
aggregateWithStart: reduceWithIndex:操作调用了scanWithStart: reduceWithIndex:，原理和它完全一致。不同的是多了两步额外的操作，一个是startWith:，一个是takeLast:1。startWith:是在scanWithStart: reduceWithIndex:变换之后的信号之前加上start信号。takeLast:1是取最后一个信号。takeLast:和startWith:的详细分析文章下面会详述。

值得注意的一点是，原信号如果没有发送complete信号，那么该函数就不会输出新的信号值。因为在一直等待结束。

#### 19. aggregateWithStart: reduce:

```objectivec

- (RACSignal *)aggregateWithStart:(id)start reduce:(id (^)(id running, id next))reduceBlock {
    return [[self
             aggregateWithStart:start
             reduceWithIndex:^(id running, id next, NSUInteger index) {
                 return reduceBlock(running, next);
             }]
            setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduce:", self.name, [start rac_description]];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/32_10.png)





aggregateWithStart: reduce:调用aggregateWithStart: reduceWithIndex:函数，只不过没有只用index值。同样，如果原信号没有发送complete信号，也不会输出任何信号。


#### 20. aggregateWithStartFactory: reduce:

```objectivec

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock {
    NSCParameterAssert(startFactory != NULL);
    NSCParameterAssert(reduceBlock != NULL);
    
    return [[RACSignal defer:^{
        return [self aggregateWithStart:startFactory() reduce:reduceBlock];
    }] setNameWithFormat:@"[%@] -aggregateWithStartFactory:reduce:", self.name];
}


```


aggregateWithStartFactory: reduce:内部实现就是调用aggregateWithStart: reduce:，只不过入参多了一个产生start的startFactory( )闭包罢了。

#### 21. collect

```objectivec

- (RACSignal *)collect {
    return [[self aggregateWithStartFactory:^{
        return [[NSMutableArray alloc] init];
    } reduce:^(NSMutableArray *collectedValues, id x) {
        [collectedValues addObject:(x ?: NSNull.null)];
        return collectedValues;
    }] setNameWithFormat:@"[%@] -collect", self.name];
}

```

![](https://img.halfrost.com/Blog/ArticleImage/32_11.png)

collect函数会调用aggregateWithStartFactory: reduce:方法。把所有原信号的值收集起来，保存在NSMutableArray中。


### 二. 时间操作


![](https://img.halfrost.com/Blog/ArticleImage/32_12.png)





#### 1. throttle:valuesPassingTest:

这个操作传入一个时间间隔NSTimeInterval，和一个判断条件的闭包predicate。原信号在一个时间间隔NSTimeInterval之间发送的信号，如果还能满足predicate，则原信号都被“吞”了，直到一个时间间隔NSTimeInterval结束，会再次判断predicate，如果不满足了，原信号就会被发送出来。


![](https://img.halfrost.com/Blog/ArticleImage/32_13.png)


如上图，原信号发送1以后，间隔NSTimeInterval的时间内，没有信号发出，并且predicate也为YES，就把1变换成新的信号发出去。接下去由于原信号发送2，3，4的过程中，都在间隔NSTimeInterval的时间内，所以都被“吞”了。直到原信号发送5之后，间隔NSTimeInterval的时间内没有新的信号发出，所以把原信号的5发送出来。原信号的6也是如此。



再来看看具体实现：

```objectivec

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate {
    NSCParameterAssert(interval >= 0);
    NSCParameterAssert(predicate != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
      
        RACScheduler *scheduler = [RACScheduler scheduler];
       
        __block id nextValue = nil;
        __block BOOL hasNextValue = NO;
        RACSerialDisposable *nextDisposable = [[RACSerialDisposable alloc] init];
        
        void (^flushNext)(BOOL send) = ^(BOOL send) { // 暂时省略 };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // 暂时省略
        } error:^(NSError *error) {
            [compoundDisposable dispose];
            [subscriber sendError:error];
        } completed:^{
            flushNext(YES);
            [subscriber sendCompleted];
        }];
        
        [compoundDisposable addDisposable:subscriptionDisposable];
        return compoundDisposable;
    }] setNameWithFormat:@"[%@] -throttle: %f valuesPassingTest:", self.name, (double)interval];
}


```

看这段实现，里面有2处断言。会先判断传入的interval是否大于0，小于0当然是不行的。还有一个就是传入的predicate闭包不能为空，这个是接下来用来控制流程的。

接下来的实现还是按照套路来，返回值是一个信号，新信号的闭包里面再订阅原信号进行变换。

那么整个变换的重点就落在了flushNext闭包和订阅原信号subscribeNext闭包中了。

当新的信号一旦被订阅，闭包执行到此处，就会对原信号进行订阅。

```objectivec

[self subscribeNext:^(id x) {
    RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
    BOOL shouldThrottle = predicate(x);
    
    @synchronized (compoundDisposable) {   
        flushNext(NO);
        if (!shouldThrottle) {
            [subscriber sendNext:x];
            return;
        }
        nextValue = x;
        hasNextValue = YES;
        nextDisposable.disposable = [delayScheduler afterDelay:interval schedule:^{
            flushNext(YES);
        }];
    }
}


```

1. 首先先创建一个delayScheduler。先判断当前的currentScheduler是否存在，不存在就取之前创建的[RACScheduler scheduler]。这里虽然两处都是RACTargetQueueScheduler类型的，但是currentScheduler是com.ReactiveCocoa.RACScheduler.mainThreadScheduler，而[RACScheduler scheduler]创建的是com.ReactiveCocoa.RACScheduler.backgroundScheduler。

2. 调用predicate( )闭包，传入原信号发来的信号值x，经过predicate判断以后，得到是否打开节流开关的BOOL变量shouldThrottle。

3. 之所以把RACCompoundDisposable作为线程间互斥信号量，因为RACCompoundDisposable里面会加入所有的RACDisposable信号。接着下面的操作用@synchronized给线程间加锁。

4. flushNext( )这个闭包是为了hook住原信号的发送。  

```objectivec

void (^flushNext)(BOOL send) = ^(BOOL send) {
    @synchronized (compoundDisposable) {
        [nextDisposable.disposable dispose];
        
        if (!hasNextValue) return;
        if (send) [subscriber sendNext:nextValue];
        
        nextValue = nil;
        hasNextValue = NO;
    }
};

```  
这个闭包中如果传入的是NO，那么原信号就无法立即sendNext。如果传入的是YES，并且hasNextValue = YES，原信号待发送的还有值，那么就发送原信号。

shouldThrottle是一个阀门，随时控制原信号是否可以被发送。

小结一下，每个原信号发送过来，通过在throttle:valuesPassingTest:里面的did subscriber闭包中进行订阅。这个闭包中主要干了4件事情：

1. 调用flushNext(NO)闭包判断能否发送原信号的值。入参为NO，不发送原信号的值。
2. 判断阀门条件predicate(x)能否发送原信号的值。
3. 如果以上两个条件都满足，nextValue中进行赋值为原信号发来的值，hasNextValue = YES代表当前有要发送的值。
4. 开启一个delayScheduler，延迟interval的时间，发送原信号的这个值，即调用flushNext(YES)。

现在再来分析一下整个throttle:valuesPassingTest:的全过程

原信号发出第一个值，如果在interval的时间间隔内，没有新的信号发送，那么delayScheduler延迟interval的时间，执行flushNext(YES)，发送原信号的这个第一个值。

```objectivec

- (RACDisposable *)afterDelay:(NSTimeInterval)delay schedule:(void (^)(void))block {
    return [self after:[NSDate dateWithTimeIntervalSinceNow:delay] schedule:block];
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(block != NULL);
    
    RACDisposable *disposable = [[RACDisposable alloc] init];
    
    dispatch_after([self.class wallTimeWithDate:date], self.queue, ^{
        if (disposable.disposed) return;
        [self performAsCurrentScheduler:block];
    });
    
    return disposable;
}


```

注意，在dispatch\_after闭包里面之前[self performAsCurrentScheduler:block]之前，有一个关键的判断：

```objectivec

if (disposable.disposed) return;

```

这个判断就是用来判断从第一个信号发出，在间隔interval的时间之内，还有没有其他信号存在。如果有，第一个信号肯定会disposed，这里会执行return，所以也就不会把第一个信号发送出来了。


这样也就达到了节流的目的：原来每个信号都会创建一个delayScheduler，都会延迟interval的时间，在这个时间内，如果原信号再没有发送新值，即原信号没有disposed，就把原信号的值发出来；如果在这个时间内，原信号还发送了一个新值，那么第一个值就被丢弃。在发送过程中，每个信号都要判断一次predicate( )，这个是阀门的开关，如果随时都不节流了，原信号发的值就需要立即被发送出来。


还有二点需要注意的是，第一点，正好在interval那一时刻，有新信号发送出来，原信号也会被丢弃，即只有在>=interval的时间之内，原信号没有发送新值，原来的这个值才能发送出来。第二点，原信号发送completed时，会立即执行flushNext(YES)，把原信号的最后一个值发送出来。


#### 2. throttle:

```objectivec

- (RACSignal *)throttle:(NSTimeInterval)interval {
    return [[self throttle:interval valuesPassingTest:^(id _) {
        return YES;
    }] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
}

```

这个操作其实就是调用了throttle:valuesPassingTest:方法，传入时间间隔interval，predicate( )闭包则永远返回YES，原信号的每个信号都执行节流操作。


#### 3. bufferWithTime:onScheduler:

这个操作的实现是类似于throttle:valuesPassingTest:的实现。

```objectivec


- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACSerialDisposable *timerDisposable = [[RACSerialDisposable alloc] init];
        NSMutableArray *values = [NSMutableArray array];
        
        void (^flushValues)() = ^{
            // 暂时省略
        };
        
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
            // 暂时省略
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            flushValues();
            [subscriber sendCompleted];
        }];
        
        return [RACDisposable disposableWithBlock:^{
            [selfDisposable dispose];
            [timerDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -bufferWithTime: %f onScheduler: %@", self.name, (double)interval, scheduler];
}


```


bufferWithTime:onScheduler:的实现和throttle:valuesPassingTest:的实现给出类似。开始有2个断言，2个都是判断scheduler的，第一个断言是判断scheduler是否为nil。第二个断言是判断scheduler的类型的，scheduler类型不能是immediateScheduler类型的，因为这个方法是要缓存一些信号的，所以不能是immediateScheduler类型的。


```objectivec

RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
    @synchronized (values) {
        if (values.count == 0) {
            timerDisposable.disposable = [scheduler afterDelay:interval schedule:flushValues];
        }
        [values addObject:x ?: RACTupleNil.tupleNil];
    }
}

```

在subscribeNext中，当数组里面是没有存任何原信号的值，就会开启一个scheduler，延迟interval时间，执行flushValues闭包。如果里面有值了，就继续加到values的数组中。关键的也是闭包里面的内容，代码如下：



```objectivec

void (^flushValues)() = ^{
    @synchronized (values) {
        [timerDisposable.disposable dispose];
        
        if (values.count == 0) return;
        
        RACTuple *tuple = [RACTuple tupleWithObjectsFromArray:values];
        [values removeAllObjects];
        [subscriber sendNext:tuple];
    }
};

```

flushValues( )闭包里面主要是把数组包装成一个元组，并且全部发送出来，原数组里面就全部清空了。这也是bufferWithTime:onScheduler:的作用，在interval时间内，把这个时间间隔内的原信号都缓存起来，并且在interval的那一刻，把这些缓存的信号打包成一个元组，发送出来。

和throttle:valuesPassingTest:方法一样，在原信号completed的时候，立即执行flushValues( )闭包，把里面存的值都发送出来。



#### 4. delay:

delay:函数的操作和上面几个套路都是一样的，实现方式也都是模板式的，唯一的不同都在subscribeNext中，和一个判断是否发送的闭包中。

```objectivec

- (RACSignal *)delay:(NSTimeInterval)interval {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        // We may never use this scheduler, but we need to set it up ahead of
        // time so that our scheduled blocks are run serially if we do.
        RACScheduler *scheduler = [RACScheduler scheduler];
        
        void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
            // 暂时省略
        };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // 暂时省略
        } error:^(NSError *error) {
            [subscriber sendError:error];
        } completed:^{
            schedule(^{
                [subscriber sendCompleted];
            });
        }];
        
        [disposable addDisposable:subscriptionDisposable];
        return disposable;
    }] setNameWithFormat:@"[%@] -delay: %f", self.name, (double)interval];
}

```

在delay:的subscribeNext中，就单纯的执行了schedule的闭包。

```objectivec

        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            schedule(^{
                [subscriber sendNext:x];
            });
        }

```

```objectivec

  void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
          RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
          RACDisposable *schedulerDisposable = [delayScheduler afterDelay:interval schedule:block];
          [disposable addDisposable:schedulerDisposable];
      };

```

在schedule闭包中做的时间就是延迟interval的时间发送原信号的值。


#### 5. interval:onScheduler:withLeeway:


```objectivec

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        return [scheduler after:[NSDate dateWithTimeIntervalSinceNow:interval] repeatingEvery:interval withLeeway:leeway schedule:^{
            [subscriber sendNext:[NSDate date]];
        }];
    }] setNameWithFormat:@"+interval: %f onScheduler: %@ withLeeway: %f", (double)interval, scheduler, (double)leeway];
}

```

在这个操作中，实现代码不难。先来看看2个断言，都是保护入参类型的，scheduler不能为空，且不能是immediateScheduler的类型，原因和上面是一样的，这里是延迟操作。


主要的实现就在after:repeatingEvery:withLeeway:schedule:上了。

```objectivec

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
    NSCParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);
    NSCParameterAssert(block != NULL);
    
    uint64_t intervalInNanoSecs = (uint64_t)(interval * NSEC_PER_SEC);
    uint64_t leewayInNanoSecs = (uint64_t)(leeway * NSEC_PER_SEC);
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(timer, [self.class wallTimeWithDate:date], intervalInNanoSecs, leewayInNanoSecs);
    dispatch_source_set_event_handler(timer, block);
    dispatch_resume(timer);
    
    return [RACDisposable disposableWithBlock:^{
        dispatch_source_cancel(timer);
    }];
}


```

这里的实现就是用GCD在self.queue上创建了一个Timer，时间间隔是interval，修正时间是leeway。

leeway这个参数是为dispatch source指定一个期望的定时器事件精度，让系统能够灵活地管理并唤醒内核。例如系统可以使用leeway值来提前或延迟触发定时器，使其更好地与其它系统事件结合。创建自己的定时器时，应该尽量指定一个leeway值。不过就算指定leeway值为0，也不能完完全全期望定时器能够按照精确的纳秒来触发事件。

这个定时器在interval执行sendNext操作，也就是发送原信号的值。


#### 6. interval:onScheduler:


```objectivec


+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    return [[RACSignal interval:interval onScheduler:scheduler withLeeway:0.0] setNameWithFormat:@"+interval: %f onScheduler: %@", (double)interval, scheduler];
}

```

这个操作就是调用上一个方法interval:onScheduler:withLeeway:，只不过leeway = 0.0。具体实现上面已经分析过了，这里不再赘述。


### 最后

本来想穷尽分析每一个RACSignal的操作的实现，但是发现所有操作加起来实在太多，用一篇文章全部写完篇幅太长了，还是拆成几篇，RACSignal还剩过滤操作，多信号组合操作，冷热信号转换操作，高阶信号操作，下篇接着继续分析。最后请大家多多指教。

