# Analysis of the Underlying Implementation of All RACSignal Transformation Operations in ReactiveCocoa (Part 1)


![](https://img.halfrost.com/Blog/ArticleTitleImage/32_0_.png)


### Preface

In the [previous article](https://halfrost.com/reactivecocoa_racsignal/), we analyzed in detail the process by which `RACSignal` is created and subscribed to. After examining the underlying source implementation, we can see that ReactiveCocoa, as an FRP library, implements reactive programming (RP) using block closures rather than KVC / KVO.


In the entire ReactiveCocoa library, `RACSignal` occupies a very important position, and `RACSignal`’s transformation operations are among the core stream operations of `RACStream`. In the previous article, we also analyzed the implementation of the `bind` operation in detail. Many transformation operations on `RACSignal` are implemented based on `bind`. Before starting this analysis of the underlying implementation, let’s briefly review the `bind` function analyzed in the previous article, since it forms the foundation for this article.


The `bind` function can be abbreviated simply as follows.
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
When the signal produced by the `bind` transformation is subscribed to, execution begins for the block closure returned by the `bind` function.

1. Inside the `bind` closure, first subscribe to the original signal A.
2. In the `didSubscribe` closure for the subscription to the original signal A, perform the signal transformation. The block closure used in the transformation is the one passed in from the outside, i.e. the input parameter of the `bind` function. After the transformation completes, a new signal B is obtained.
3. Subscribe to the new signal B, obtain the subscriber of the signal produced by the `bind` transformation, and send the new signal value to it.


![](https://img.halfrost.com/Blog/ArticleImage/32_1.png)


The high-level process is shown above. The `bind` function performs two subscriptions: the first subscription is to obtain the value of signal A, and the second subscription is to send the new value of signal B to the subscriber of the signal B produced by the `bind` transformation.


After reviewing the underlying implementation of `bind`, we can continue with the analysis in this article.

### Table of Contents

- 1. Transformation Operations
- 2. Time Operations

### 1. Transformation Operations


![](https://img.halfrost.com/Blog/ArticleImage/32_2.png)


We all know that RACSignal inherits from RACStream, and some basic signal transformation operations are also defined on the underlying RACStream. Therefore, these operations are equally applicable to RACSignal. If these methods are not overridden in RACSignal, then invoking these operations actually calls the operations on the parent class RACStream. In the analysis below, any place where the parent class RACStream operation is actually invoked will be explicitly marked.

#### 1. Map: (Defined in the parent class RACStream)

The `map` operation is generally used for signal transformation.
```objectivec

    RACSignal *signalB = [signalA map:^id(NSNumber *value) {
        return @([value intValue] * 10);
    }];

```
![](https://img.halfrost.com/Blog/ArticleImage/32_3.png)


Let’s take a look at how this is implemented under the hood.
```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```
The implementation here is fairly rigorous: it first checks the type of `self`. Some subclasses of `RACStream` override these methods, so the type of `self` needs to be checked to ensure callbacks can dispatch to methods on the original type.

Since this article analyzes operations on `RACSignal`, `self.class` here is `RACDynamicSignal`. Correspondingly, the `return` value also returns that `class`, meaning a signal of type `RACDynamicSignal`.

Looking at the implementation of `map`, it is implemented using the `flattenMap` function. The closure passed into `map` is placed inside the return value of `flattenMap`.

Now let’s look at the implementation of `flattenMap`:
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
`flattenMap` can be considered a wrapper around the `bind` function. The input to `bind` is a closure of type `RACStreamBindBlock`, whereas the input to `flattenMap` is a closure that takes a `value` and returns a `RACStream`.

In `flattenMap`, the signal returned by `block(value)` is returned; if that signal is `nil`, `[class empty]` is returned.

First, let’s look at the empty case. When `block(value)` is empty, `[RACEmptySignal empty]` is returned. `empty` creates a signal of type `RACEmptySignal`:
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
What, then, is a signal of type RACEmptySignal?
```objectivec


- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```
RACEmptySignal is a subclass of RACSignal. Once subscribed to, it synchronously sends a `completed` completion signal to the subscriber.

Therefore, `flattenMap` returns a signal; if the signal does not exist, it returns a `completed` completion signal to the subscriber.

Now let’s look at how the signal returned by `flattenMap` is transformed.

`block(value)` passes the `value` sent by the original signal to the argument of `flattenMap`. The argument of `flattenMap` is a closure, and the closure’s parameter is also `value`:
```objectivec

^(id value) { return [class return:block(value)]; }

```
This closure returns a signal whose type is the same as the original signal, namely `RACDynamicSignal`, and whose value is `block(value)`. The closure here is the one passed in from the outer `map`:
```objectivec

^id(NSNumber *value) { return @([value intValue] * 10); }

```
In this closure, the original signal’s value is passed in for transformation. After the transformation is complete, it is wrapped into a signal of the same type as the original signal and returned. The returned signal serves as the return value of the closure passed to the `bind` function. This way, when subscribing to the new signal after `map`, you receive the transformed value.

#### 2.MapReplace: (defined in the parent class RACStream)

The typical usage is as follows:
```objectivec

RACSignal *signalB = [signalA mapReplace:@"A"];

```
![](https://img.halfrost.com/Blog/ArticleImage/32_4.png)


The effect is that no matter what value signal A sends, it is replaced with @"A".
```objectivec

- (instancetype)mapReplace:(id)object {
    return [[self map:^(id _) {
        return object;
    }] setNameWithFormat:@"[%@] -mapReplace: %@", self.name, [object rac_description]];
}

```
Looking at the underlying source code, you can see that it does not care what value the original signal sends. No matter what value the original signal sends, it returns the value of the input parameter `object`.


#### 3.reduceEach:   (defined in the superclass RACStream)


`reduce` means to reduce or aggregate things together; `reduceEach` means aggregating the values within each signal together.
```objectivec

    RACSignal *signalB = [signalA reduceEach:^id(NSNumber *num1 , NSNumber *num2){
        return @([num1 intValue] + [num2 intValue]);
    }];


```
![](https://img.halfrost.com/Blog/ArticleImage/32_5.png)

reduceEach must be followed by a tuple of type RACTuple; otherwise, an error will be thrown.
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
There are two assertions here: one checks whether the passed-in `reduceBlock` closure is nil, and the other checks whether the closure’s input parameter is of type `RACTuple`.
```objectivec

@interface RACBlockTrampoline : NSObject
@property (nonatomic, readonly, copy) id block;
+ (id)invokeBlock:(id)block withArguments:(RACTuple *)arguments;
@end

```
RACBlockTrampoline is an object that stores a block closure. Based on the arguments passed in, it dynamically constructs an `NSInvocation` and executes it.

`reduceEach` passes the input `reduceBlock` as the `invokeBlock` argument to `RACBlockTrampoline`, and also passes each `RACTuple` into `RACBlockTrampoline`.
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
The first step is to calculate the number of elements in the input `RACTuple`.
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
As you can see, the maximum number of elements supported in a tuple is 15.

Here, let’s assume a tuple with 2 elements as an example.
```objectivec

- (id)performWith:(id)obj1 :(id)obj2 {
    id (^block)(id, id) = self.block;
    return block(obj1, obj2);
}

```
The corresponding [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html) is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/32_6.png)

`argument0` and `argument1` correspond to the hidden parameters `self` and `_cmd`, respectively, so their corresponding types are `@` and `:`. Starting from `argument2`, the entries are the Type Encodings of the input parameters.

Therefore, when constructing the arguments for the invocation, `argIndex` needs to be offset by 2 positions. That is, parameters are set starting from `(i + 2)`.

After dynamically constructing an invocation method, calling `[invocation invoke]` invokes this dynamic method—that is, it executes the external `reduceBlock` closure, whose body contains the signal transformation rules we want.

When the closure finishes executing, it produces the return value `returnVal`. This return value is the return value of the entire `RACBlockTrampoline`. It is also used as the return value inside the `map` closure.

The subsequent operations are completely transformed into `map` operations. The `map` operation has already been analyzed above, so it will not be repeated here.

#### 4. reduceApply

Here is an example:
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
The condition for using `reduceApply` is also that the values in the signal must be tuples, i.e. `RACTuple`. However, unlike `reduceEach`, the 0th element of each original `RACTuple` in the signal must be a closure, and the following `n` elements are the arguments to that closure. If the closure at index 0 takes a certain number of parameters, the tuple must provide that many arguments after it.

In the example above, the closure at index 0 of the first tuple takes 3 parameters, so the first tuple must include 3 arguments after it. The closure at index 0 of the second tuple takes only one parameter, so only one argument is required after it.

Of course, more arguments can be provided afterward. For example, in the second tuple, there are 3 arguments after the closure, but only the first argument is a valid value; the remaining 2 arguments are invalid and have no effect. The only thing to note is that the number of arguments following the closure must not be less than the number of input parameters required by the closure at index 0; otherwise, an error will be reported.

The output of the example above is:
```vim

26  // 26 = 2 + 3 * 8；
90  // 90 = 9 * 10；

```
Let's look at the underlying implementation:
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
There are also two assertions here. The first ensures that the passed-in argument is of type `RACTuple`; the second ensures that the tuple `RACTuple` contains at least two elements. This is because the arguments below are accessed directly starting from index 1.

`reduceApply` does essentially the same thing as `reduceEach`; the only difference is that the transformation-rule `block` closure is passed in externally for one, while for the other it is packaged directly at index 0 of each signal tuple `RACTuple`.

#### 5. materialize

This method wraps the signal as an `RACEvent` type.
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
sendNext will be wrapped as [RACEvent eventWithValue:x], error will be wrapped as [RACEvent eventWithError:error], and completed will be wrapped as RACEvent.completedEvent. Note that when the original signal sends error or completed, the new signal will send sendCompleted.


#### 6. dematerialize

This operation is the inverse of materialize. It restores signals wrapped as RACEvent back into normal value signals.
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
The implementation here also uses the bind function, which transforms the original signal. The new signal is transformed based on event.eventType. RACEventTypeCompleted is transformed into [RACSignal empty], RACEventTypeError is transformed into [RACSignal error:event.error], and RACEventTypeNext is transformed into [RACSignal return:event.value].

#### 7. not
```objectivec

- (RACSignal *)not {
    return [[self map:^(NSNumber *value) {
        NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);
        
        return @(!value.boolValue);
    }] setNameWithFormat:@"[%@] -not", self.name];
}


```
The values passed to the not operation must all be of type NSNumber. If a value is not of type NSNumber, an error will occur. The not operation negates each NSNumber according to BOOL rules and uses the result as the value of the new signal.


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
The and operation requires every signal emitted by the original signal to be of type RACTuple, because only then can each element in the RACTuple be used in an & operation.

There are three assertions in the and operation. The first checks whether the input parameter is of type RACTuple. The second checks whether the RACTuple contains at least one NSNumber. The third checks whether all elements in the RACTuple are of type NSNumber; if any element does not match, an error is raised.
```objectivec

- (RACSequence *)rac_sequence {
    return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

```
The RACTuple type is first converted to RACTupleSequence.
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
`backingArray` is an array, `NSArry`. `RACTupleSequence` and `RACTuple` will be analyzed in detail in future articles; this article focuses on analyzing `RACSignal`.

The `RACTuple` type is first converted into a `RACTupleSequence`, meaning it is stored as an array.
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
`for` iterates over each value stored in the `RACSequence` and calls the `reduce( )` closure for each one. The initial value of `start` is `YES`. The `reduce( )` closure is:
```objectivec

^(NSNumber *accumulator, id value) { return @(accumulator.boolValue && block(value)); }

```
Here it will again call the block( ) closure:
```objectivec

^(NSNumber *number) { return number.boolValue; }

```
`number` is the first value in the original signal’s `RACTuple`. In the first iteration, the `reduce( )` closure performs an `&` operation between `YES` and the first value of the original signal’s `RACTuple`. In the second iteration, the `reduce( )` closure performs an `&` operation between the first and second values of the original signal’s `RACTuple`; the resulting value participates in the next iteration and is `&`-ed with the third value, and so on. This is also what a fold function means: `foldLeft` starts folding from the left. The `fold` function proceeds from left to right, performing `&` operations on each value in the array converted from the `RACTuple`, one after another.

Each `RACTuple` is `map`ped into a `BOOL` value like this. The signal is then `map`ped into a new signal.

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
The implementation of the `or` operation is largely similar to that of the `and` operation. The three assertions serve exactly the same purpose as in the `and` operation, so they will not be repeated here. The key point of the `or` operation lies in the implementation of the `any` function. The input argument to the `or` operation must also be of type `RACTuple`.
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
`any` checks the values in the `RACTupleSequence` array in order, applying `filter` to each one sequentially. If the `BOOL` value corresponding to `value` is `YES`, it is converted into a `RACTupleSequence` signal. If it is `NO`, it is converted into an `empty` signal.

As long as the `RACTuple` is `NO`, it keeps returning an `empty` signal. Once the `BOOL` value is `YES`, it returns `1`. After the signal is transformed by `map`, it becomes `1`. Once the value corresponding to `YES` is found, subsequent values will no longer be checked. If no `YES` is found and all intermediate values are `NO`, it keeps iterating until the last element of the array, and the signal can only return `0`.

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
The original signal is first transformed by materialize and wrapped as RACEvent events. It then evaluates the BOOL value of predicateBlock(event.value) in order. If it returns YES, it is wrapped into a new RACSignal, sends YES, and stops processing subsequent signals. If it returns NO, it returns [RACSignal empty], an empty signal. Once event.finished is reached, it returns [RACSignal return:@NO].

Therefore, the purpose of the any: operation is to find the first value that satisfies the predicateBlock condition. If found, it returns a RACSignal that sends YES; if not found, it returns a RACSignal that sends NO.

#### 11. any
```objectivec

- (RACSignal *)any {
    return [[self any:^(id x) {
        return YES;
    }] setNameWithFormat:@"[%@] -any", self.name];
}

```
The `any` operation is a special case of `any:`. That is, the `predicateBlock` closure always returns `YES`, so after the `any` operation, you will always get a new signal that sends only a single `YES`.

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
`all:` is somewhat similar to `any:`. The original signal is first wrapped into `RACEvent` events via `materialize`. For each event sent by the original signal, it sequentially checks whether `predicateBlock(event.value)` is `NO` or whether `event.eventType == RACEventTypeError`. If `predicateBlock(event.value)` returns `NO` or an error occurs, the new signal returns `NO`. If no issue occurs throughout the process, it sends `YES` when `RACEventTypeCompleted` is reached.

`all:` can be used to determine whether an error event `RACEventTypeError` occurs during the entire sending process of the original signal, or whether there is any case where `predicateBlock` evaluates to `NO`. You can set `predicateBlock` to represent a valid condition. If the original signal emits an error event, or does not satisfy the configured condition, the new signal will send `NO`. If no error occurs throughout the entire process, or all values satisfy the condition configured by `predicateBlock`, then when `RACEventTypeCompleted` is reached, a new signal sending `YES` is emitted.


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
The repeat operation returns a subscribeForever closure, which takes four parameters.
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
`subscribeForever` takes four parameters: the first is the original signal, the second is the `next` closure, the third is the `error` closure, and the last is the `completed` closure.

As soon as `subscribeForever` is entered, it calls the `recursiveBlock()` closure. Inside that closure, there is a parameter named `recurse()`. Within the `recursiveBlock()` closure, it subscribes to the original `RACSignal`. `next`, `error`, and `completed` each first invoke the closures passed in from the outside. Then, after `error` and `completed` finish executing the `error()` and `completed()` closures, they continue by invoking `recurse()`, which is the parameter passed into `recursiveBlock`.
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
        
        RACDisposable *schedulingDisposable = [self schedule:^{ // omitted here }];
        
        [selfDisposable addDisposable:schedulingDisposable];
    }
}
```
First, obtain the current `currentScheduler`, namely `recursiveScheduler`, and execute `scheduleRecursiveBlock`. This function calls the `schedule` function. Here, `recursiveScheduler` is of type `RACQueueScheduler`.
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
If the original signal has not been disposed, `dispatch_async` will continue executing the block, and that block will continue sending the original signal. Therefore, as long as the original signal does not emit an error signal, `disposable.disposed` will not return `YES`, and the block will keep being invoked. For this reason, the `recurse( )` closure is called at the end of both the `error` and `completed` handlers in `subscribeForever`. Calling the `recurse( )` closure in `error` is to stop invoking the block and terminate all signals. Calling the `recurse( )` closure in `completed` is to continue invoking the `block( )` closure, which is the essence of `repeat`. The original signal will continue sending signals, looping infinitely like this.

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
In the implementation of `retry:`, the difference from the implementation of `repeat` is that a `currentRetryCount` value is added in between. If `currentRetryCount > retryCount`, `[disposable dispose]` is called in `error`, so `subscribeForever` will no longer continue looping indefinitely.

Therefore, the purpose of the `retry:` operation is to retry the original signal `retryCount` times when it encounters an `error`. If it still errors after that, retrying stops.

If the original signal does not encounter an error, then once the original signal completes, `subscribeForever` also ends. For a signal without any `error`, the `retry:` operation is effectively a no-op.


#### 15. retry
```objectivec

- (RACSignal *)retry {
    return [[self retry:0] setNameWithFormat:@"[%@] -retry", self.name];
}

```
The `retry` operation here is an infinite retry operation. Because after `retryCount` is set to 0, inside the `error` closure, `retryCount` is always equal to 0, and the original signal will never be disposed, so `subscribeForever` will keep retrying indefinitely.

Similarly, calling the `retry` operation on a signal that has no `error` has no effect at all.


#### 16. scanWithStart: reduceWithIndex: (defined in the parent class `RACStream`)


First, write the test code:
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
The `scanWithStart` transformation consists of an initial value, the transformation function reduceBlock( ), and an `index` variable that advances step by step. Each signal from the original signal is transformed by the transformation function reduceBlock( ). `index` increments each time. The initial value for the transformation is passed in via the input parameter `startingValue`.


#### 17. scanWithStart: reduce: (defined in the parent class RACStream)
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


scanWithStart: reduce: is simply the shorthand version of scanWithStart: reduceWithIndex:. The transformation function is also passed in from the external closure reduceBlock(). The only difference is that the auto-incrementing `index` variable is not used during the transformation process.


**By using this family of scan operations, you can effectively eliminate operations with side effects!**

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


`aggregate` means to aggregate, so the transformed signal ultimately contains only the final value.
The `aggregateWithStart: reduceWithIndex:` operation calls `scanWithStart: reduceWithIndex:`, and its principle is exactly the same. The difference is that it performs two additional operations: `startWith:` and `takeLast:1`. `startWith:` prepends the `start` signal before the signal transformed by `scanWithStart: reduceWithIndex:`. `takeLast:1` takes the last signal. A detailed analysis of `takeLast:` and `startWith:` will be covered below.

One thing worth noting is that if the original signal does not send a `complete` signal, this function will not output a new signal value, because it keeps waiting for completion.

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


`aggregateWithStart: reduce:` calls the `aggregateWithStart: reduceWithIndex:` function, except that it does not use the `index` value. Likewise, if the original signal does not send a `complete` signal, no signal will be emitted.


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
aggregateWithStartFactory: reduce: is implemented internally by calling aggregateWithStart: reduce:, except that its parameters include an additional startFactory( ) closure that produces start.

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

The `collect` function calls the `aggregateWithStartFactory: reduce:` method. It collects all values from the original signal and stores them in an `NSMutableArray`.


### II. Time Operations


![](https://img.halfrost.com/Blog/ArticleImage/32_12.png)


#### 1. throttle:valuesPassingTest:

This operation takes a time interval `NSTimeInterval` and a predicate closure `predicate`. For signals sent by the original signal within a time interval `NSTimeInterval`, if they still satisfy `predicate`, they are all “swallowed” until the time interval `NSTimeInterval` ends. Then `predicate` is evaluated again; if it is no longer satisfied, the original signal will be sent out.


![](https://img.halfrost.com/Blog/ArticleImage/32_13.png)


As shown above, after the original signal sends `1`, no signal is emitted during the `NSTimeInterval`, and `predicate` is also `YES`, so `1` is transformed into a new signal and sent out. Next, because the original signal sends `2`, `3`, and `4` all within the `NSTimeInterval`, they are all “swallowed.” Only after the original signal sends `5`, if no new signal is emitted during the `NSTimeInterval`, the original signal’s `5` is sent out. The same applies to `6`.


Now let’s look at the concrete implementation:
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
        
        void (^flushNext)(BOOL send) = ^(BOOL send) { // omitted for now };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // omitted for now
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
Looking at this implementation, there are two assertions. It first checks whether the passed-in `interval` is greater than 0; naturally, a value less than 0 is not allowed. The other assertion is that the passed-in `predicate` closure must not be nil, since it is used next to control the flow.

The rest of the implementation follows the usual pattern: the return value is a signal, and inside the new signal’s closure, it subscribes to the original signal and performs the transformation.

So the focus of the entire transformation falls on the `flushNext` closure and the `subscribeNext` closure that subscribes to the original signal.

Once the new signal is subscribed to and execution reaches this point in the closure, it subscribes to the original signal.
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
1. First, create a delayScheduler. Check whether the current currentScheduler exists; if it does not, use the previously created [RACScheduler scheduler]. Although both are of type RACTargetQueueScheduler here, currentScheduler is com.ReactiveCocoa.RACScheduler.mainThreadScheduler, while [RACScheduler scheduler] creates com.ReactiveCocoa.RACScheduler.backgroundScheduler.

2. Call the predicate( ) closure and pass in the signal value x sent by the original signal. After predicate evaluates it, you get the BOOL variable shouldThrottle, which indicates whether to enable throttling.

3. RACCompoundDisposable is used as a cross-thread mutual-exclusion semaphore because all RACDisposable signals are added to the RACCompoundDisposable. The following operations are then protected with @synchronized to add inter-thread locking.

4. The flushNext( ) closure is used to hook into the emissions from the original signal.
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
If `NO` is passed into this closure, the original signal cannot immediately `sendNext`. If `YES` is passed in and `hasNextValue = YES`, meaning the original signal still has a value waiting to be sent, then the original signal is sent.

`shouldThrottle` is a gate that controls at any time whether the original signal is allowed to be sent.

To summarize, each value sent by the original signal is subscribed to through the `did subscriber` closure inside `throttle:valuesPassingTest:`. This closure mainly does four things:

1. Calls the `flushNext(NO)` closure to determine whether the original signal’s value can be sent. The argument is `NO`, so the original signal’s value is not sent.
2. Checks whether the gate condition `predicate(x)` allows the original signal’s value to be sent.
3. If both of the above conditions are satisfied, assigns the value sent by the original signal to `nextValue`, and `hasNextValue = YES` indicates that there is currently a value to be sent.
4. Starts a `delayScheduler`, delays by `interval`, and then sends this value from the original signal, i.e. calls `flushNext(YES)`.

Now let’s analyze the entire process of `throttle:valuesPassingTest:`.

When the original signal emits the first value, if no new signal is sent within the `interval` time window, `delayScheduler` waits for `interval`, executes `flushNext(YES)`, and sends this first value from the original signal.
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
Note that inside the dispatch\_after closure, before [self performAsCurrentScheduler:block], there is a key check:
```objectivec

if (disposable.disposed) return;

```
This check is used to determine whether, after the first signal is sent, any other signal exists within the `interval` window. If there is, the first signal will definitely be disposed. Execution returns here, so the first signal will not be sent out.

This achieves throttling: originally, each signal would create a `delayScheduler` and be delayed by `interval`. During that period, if the original signal does not send a new value—that is, if the original signal has not been disposed—then the original signal’s value is emitted. If, during that period, the original signal sends another new value, then the first value is discarded. During emission, each signal must evaluate `predicate()`. This acts as the gate switch: if throttling is disabled at any point, values emitted by the original signal need to be sent out immediately.

There are two more points to note. First, if a new signal is sent exactly at the `interval` moment, the original signal will also be discarded. In other words, only if the original signal does not send a new value within a time span of `>= interval` can the original value be emitted. Second, when the original signal sends `completed`, `flushNext(YES)` is executed immediately, emitting the final value of the original signal.

#### 2. throttle:
```objectivec

- (RACSignal *)throttle:(NSTimeInterval)interval {
    return [[self throttle:interval valuesPassingTest:^(id _) {
        return YES;
    }] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
}

```
This operation actually calls the `throttle:valuesPassingTest:` method, passing in the time interval `interval`; the `predicate( )` closure always returns `YES`, so every value from the original signal is throttled.


#### 3. bufferWithTime:onScheduler:

The implementation of this operation is similar to that of `throttle:valuesPassingTest:`.
```objectivec


- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    NSCParameterAssert(scheduler != nil);
    NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACSerialDisposable *timerDisposable = [[RACSerialDisposable alloc] init];
        NSMutableArray *values = [NSMutableArray array];
        
        void (^flushValues)() = ^{
            // Omitted for now
        };
        
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
            // Omitted for now
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
The implementation of `bufferWithTime:onScheduler:` is similar to that of `throttle:valuesPassingTest:`. It starts with two assertions, both of which validate the scheduler. The first assertion checks whether the scheduler is `nil`. The second assertion checks the scheduler’s type: the scheduler must not be an `immediateScheduler`, because this method needs to buffer some signals, so it cannot use an `immediateScheduler`.
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
In `subscribeNext`, when the array does not contain any values from the original signal, a `scheduler` is started, delaying for the `interval` duration before executing the `flushValues` closure. If there are already values in it, the new value is appended to the `values` array. The key part is also the logic inside the closure, shown below:
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
Inside the flushValues( ) closure, the main operation is to wrap the array into a tuple and send it out, after which the original array is completely cleared. This is also what bufferWithTime:onScheduler: does: within the interval duration, it buffers all original signals that arrive during that time window, and at the moment the interval elapses, it packages those buffered signals into a tuple and sends it out.

As with the throttle:valuesPassingTest: method, when the original signal completes, the flushValues( ) closure is executed immediately, sending out all values stored inside it.


#### 4. delay:

The behavior of the delay: function follows the same pattern as the previous ones, and its implementation is also template-like. The only differences are in subscribeNext and in the closure that determines whether to send.
```objectivec

- (RACSignal *)delay:(NSTimeInterval)interval {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        // We may never use this scheduler, but we need to set it up ahead of
        // time so that our scheduled blocks are run serially if we do.
        RACScheduler *scheduler = [RACScheduler scheduler];
        
        void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
            // Omitted for now
        };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // Omitted for now
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
In delay:'s subscribeNext, it simply executes the schedule closure.
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
In the schedule closure, it sends the original signal’s value after delaying for interval.


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
In this operation, the implementation isn’t difficult. Let’s first look at the two assertions: both protect the input parameter types. `scheduler` must not be nil, and it must not be of type `immediateScheduler`, for the same reason as above: this is a delayed operation.

The main implementation is in after:repeatingEvery:withLeeway:schedule:.
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
The implementation here uses GCD to create a Timer on self.queue, with interval as the time interval and leeway as the tolerance.

The leeway parameter specifies the desired precision for timer events on the dispatch source, allowing the system to manage and wake the kernel more flexibly. For example, the system can use the leeway value to fire the timer earlier or later so that it can be better coalesced with other system events. When creating your own timer, you should specify a leeway value whenever possible. However, even if you specify a leeway value of 0, you still cannot fully expect the timer to fire events with exact nanosecond precision.

This timer performs the sendNext operation at each interval, which means it sends the value of the original signal.


#### 6. interval:onScheduler:
```objectivec


+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    return [[RACSignal interval:interval onScheduler:scheduler withLeeway:0.0] setNameWithFormat:@"+interval: %f onScheduler: %@", (double)interval, scheduler];
}

```
This operation simply calls the previous method, interval:onScheduler:withLeeway:, except with leeway = 0.0. The concrete implementation has already been analyzed above, so I won’t repeat it here.


### Finally

I originally wanted to exhaustively analyze the implementation of every RACSignal operation, but there are simply too many operations in total. Covering all of them in a single article would make it far too long, so I’ll split the discussion into several parts. For RACSignal, filtering operations, multi-signal composition operations, cold/hot signal conversion operations, and higher-order signal operations are still left. I’ll continue the analysis in the next article. As always, feedback and corrections are welcome.