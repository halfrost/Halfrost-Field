+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
date = 2016-11-26T00:42:12Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/32_0_.png"
slug = "reactivecocoa_racsignal_operations1"
tags = ["iOS", "RAC", "ReactiveCocoa", "RACSignal"]
title = "Analysis of the Underlying Implementation of All RACSignal Transformation Operations in ReactiveCocoa (Part 1)"

+++


### Preface

In the [previous article](https://halfrost.com/reactivecocoa_racsignal/), we analyzed in detail the process by which `RACSignal` is created and subscribed to. After examining the underlying source implementation, we can see that ReactiveCocoa, as an FRP library, implements reactive programming (RP) using Block closures rather than KVC / KVO.


Across the entire ReactiveCocoa library, `RACSignal` plays a very important role, and transformation operations on `RACSignal` are one of the cores of the overall `RACStream` stream operations. The previous article also analyzed the implementation of the `bind` operation in detail. Many transformation operations on `RACsignal` are implemented based on `bind`. Before starting the analysis of the underlying implementation in this article, let’s briefly review the `bind` function analyzed in the previous article, since it is the foundation for this article’s analysis.


The `bind` function can be simplified as follows.
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
When the signal transformed by `bind` is subscribed to, execution begins in the `block` closure returned by the `bind` function.

1. In the `bind` closure, first subscribe to the original signal A.
2. In the `didSubscribe` closure for the original signal A, perform the signal transformation. The `block` closure used in the transformation is the one passed in from the outside, that is, the input parameter of the `bind` function. After the transformation completes, a new signal B is obtained.
3. Subscribe to the new signal B, obtain the subscriber of the signal produced by the `bind` transformation, and send the new signal value to it.


![](https://img.halfrost.com/Blog/ArticleImage/32_1.png)


The brief process is shown in the diagram above. The `bind` function performs two subscription operations: the first subscription is to obtain the value of `signalA`, and the second subscription is to send the new value of `signalB` to the subscriber of the `signalB` obtained after the `bind` transformation.


After reviewing the underlying implementation of `bind`, we can continue with the analysis in this article.

### Table of Contents

- 1. Transformation Operations
- 2. Time Operations

### I. Transformation Operations


![](https://img.halfrost.com/Blog/ArticleImage/32_2.png)


We all know that `RACSignal` inherits from `RACStream`, and some fundamental signal transformation operations are also defined on the underlying `RACStream`, so these operations are equally applicable to `RACSignal`. If `RACSignal` does not override these methods, then invoking these operations actually calls the operations of the parent class, `RACStream`. In the analysis below, all places where the parent-class `RACStream` operations are actually called will be explicitly noted.

#### 1. Map: (defined in the parent class `RACStream`)

The `map` operation is generally used for signal transformation.
```objectivec

    RACSignal *signalB = [signalA map:^id(NSNumber *value) {
        return @([value intValue] * 10);
    }];

```
![](https://img.halfrost.com/Blog/ArticleImage/32_3.png)


Let's take a look at how it is implemented under the hood.
```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```
The implementation here is fairly rigorous: it first checks the type of `self`. Because some subclasses of `RACStream` override these methods, it needs to determine the type of `self` so that the callback can invoke the method on the original type.

Since this article analyzes `RACSignal` operations throughout, `self.class` here is of type `RACDynamicSignal`. Correspondingly, the `class` is also returned in the return value—that is, a signal of type `RACDynamicSignal`.

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
`flattenMap` can be considered a wrapper around the `bind` function. The input parameter of `bind` is a closure of type `RACStreamBindBlock`, whereas the input parameter of `flattenMap` is a closure that takes a `value` and returns a `RACStream`.

In `flattenMap`, the signal returned by `block(value)` is used. If that signal is `nil`, `[class empty]` is returned.

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
What kind of signal is the `RACEmptySignal` type?
```objectivec


- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    return [RACScheduler.subscriptionScheduler schedule:^{
        [subscriber sendCompleted];
    }];
}

```
RACEmptySignal is a subclass of RACSignal. Once subscribed to, it synchronously sends a completed signal to the subscriber.

So flattenMap returns a signal; if the signal does not exist, it returns a completed signal to the subscriber.

Now let’s look at how the signal returned by flattenMap is transformed.

block(value) passes the value sent by the original signal to the input parameter of flattenMap. The input parameter of flattenMap is a closure, and the closure’s parameter is also value:
```objectivec

^(id value) { return [class return:block(value)]; }

```
This closure returns a signal whose type is the same as the original signal, namely `RACDynamicSignal`, with the value `block(value)`. The closure here is passed in from the outer `map`:
```objectivec

^id(NSNumber *value) { return @([value intValue] * 10); }

```
Pass the original signal’s `value` into this closure for transformation. After the transformation is complete, wrap it into a signal of the same type as the original signal and return it. The returned signal is used as the return value of the closure passed to the `bind` function. This way, after subscribing to the new signal produced by `map`, you will receive the transformed value.

#### 2.MapReplace: (Defined in the superclass RACStream)

A typical usage is as follows:
```objectivec

RACSignal *signalB = [signalA mapReplace:@"A"];

```
![](https://img.halfrost.com/Blog/ArticleImage/32_4.png)


The effect is that no matter what value signal A sends, it is replaced with @“A”.
```objectivec

- (instancetype)mapReplace:(id)object {
    return [[self map:^(id _) {
        return object;
    }] setNameWithFormat:@"[%@] -mapReplace: %@", self.name, [object rac_description]];
}

```
Looking at the underlying source code makes it clear that it does not care what value the original signal sends. No matter what value the original signal sends, it returns the value of the input parameter `object`.


#### 3.reduceEach:   (defined in the superclass RACStream)


`reduce` means reducing, or aggregating things together. `reduceEach` means aggregating the contents within each signal together.
```objectivec

    RACSignal *signalB = [signalA reduceEach:^id(NSNumber *num1 , NSNumber *num2){
        return @([num1 intValue] + [num2 intValue]);
    }];


```
![](https://img.halfrost.com/Blog/ArticleImage/32_5.png)

reduceEach must be passed a tuple of type RACTuple; otherwise, an error will occur.
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
There are two assertions here: one checks whether the passed-in `reduceBlock` closure is nil, and the other checks whether the closure’s argument is of type `RACTuple`.
```objectivec

@interface RACBlockTrampoline : NSObject
@property (nonatomic, readonly, copy) id block;
+ (id)invokeBlock:(id)block withArguments:(RACTuple *)arguments;
@end

```
RACBlockTrampoline is an object that stores a block closure. Based on the arguments passed in, it dynamically constructs an NSInvocation and invokes it.

reduceEach passes the input parameter reduceBlock to RACBlockTrampoline as the invokeBlock parameter, and also passes each RACTuple into RACBlockTrampoline.
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
The first step is to calculate the number of elements in the input tuple `RACTuple`.
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
You can see that the maximum number of elements supported in a tuple is 15.

Here, we’ll use a tuple with 2 elements as an example.
```objectivec

- (id)performWith:(id)obj1 :(id)obj2 {
    id (^block)(id, id) = self.block;
    return block(obj1, obj2);
}

```
The corresponding [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html) is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/32_6.png)

`argument0` and `argument1` correspond to the hidden parameters `self` and `_cmd`, respectively, so their corresponding types are `@` and `:`. Starting from `argument2`, the parameters correspond to the Type Encodings of the input arguments.

Therefore, when constructing the arguments for the invocation, `argIndex` needs to be offset by 2 positions. That is, arguments should be set starting from `(i + 2)`.

After dynamically constructing an invocation method, `[invocation invoke]` calls this dynamic method, which means it executes the external `reduceBlock` closure. The closure contains the rules we want for transforming the signal.

After the closure finishes executing, it produces the return value `returnVal`. This return value is the return value of the entire `RACBlockTrampoline`. It also serves as the return value inside the `map` closure.

The subsequent operations are then completely transformed into `map` operations. We already analyzed the `map` operation above, so we won’t repeat it here.

#### 4. reduceApply

For example:
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
The condition for using `reduceApply` is also that the values in the signal must be `RACTuple`s. However, unlike `reduceEach`, each original `RACTuple` in the signal must have a closure at index 0, and the following `n` elements must be the arguments to that closure. The number of parameters in the closure at index 0 determines how many arguments must follow it.

In the example above, the closure at index 0 of the first tuple has three parameters, so the first tuple must be followed by three arguments. The closure at index 0 of the second tuple has only one parameter, so only one argument needs to follow it.

Of course, more arguments can follow. For example, in the second tuple, three arguments follow the closure, but only the first argument is a valid value; the remaining two arguments are invalid and have no effect. The only thing to note is that the number of following arguments must not be less than the number of input parameters of the closure at index 0; otherwise, an error will be reported.

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
There are also two assertions here. The first ensures that the passed-in argument is of type `RACTuple`; the second ensures that the tuple `RACTuple` contains at least two elements. This is because the parameters below are retrieved directly starting from index 1.

What `reduceApply` does is essentially equivalent to `reduceEach`; the only difference is that the transformation-rule `block` closure is passed in externally in one case, while in the other it is packaged directly at index 0 of each signal tuple `RACTuple`.


#### 5. materialize

This method wraps the signal as a `RACEvent` type.
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
`sendNext` is wrapped as `[RACEvent eventWithValue:x]`, `error` is wrapped as `[RACEvent eventWithError:error]`, and `completed` is wrapped as `RACEvent.completedEvent`. Note that when the original signal sends `error` or `completed`, the new signal will send `sendCompleted`.


#### 6. dematerialize

This operation is the inverse of `materialize`. It restores signals wrapped as `RACEvent` back into normal value signals.
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
The implementation here also uses the bind function, which applies a transformation to the original signal. The new signal is transformed based on event.eventType. RACEventTypeCompleted is transformed into [RACSignal empty], RACEventTypeError is transformed into [RACSignal error:event.error], and RACEventTypeNext is transformed into [RACSignal return:event.value].

#### 7. not
```objectivec

- (RACSignal *)not {
    return [[self map:^(NSNumber *value) {
        NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);
        
        return @(!value.boolValue);
    }] setNameWithFormat:@"[%@] -not", self.name];
}


```
The not operation requires all values passed in to be of type NSNumber. If a value is not an NSNumber, an error will be reported. The not operation negates each NSNumber according to BOOL rules and uses the result as the value of the new signal.


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
The `and` operation requires every signal from the original signal to be of the RACTuple type, because only then can the values of each element inside the RACTuple be used in the `&` operation.

There are three assertions inside the `and` operation. The first checks whether the input parameter is of the RACTuple type. The second checks whether the RACTuple contains at least one NSNumber. The third checks whether all elements inside the RACTuple are of the NSNumber type; if any one of them does not match, an error will be reported.
```objectivec

- (RACSequence *)rac_sequence {
    return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

```
The RACTuple type is first converted into RACTupleSequence.
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
`backingArray` is an `NSArry` array. `RACTupleSequence` and `RACTuple` will be analyzed in detail in future articles; this article focuses on analyzing `RACSignal`.


The `RACTuple` type is first converted into a `RACTupleSequence`, which means it is stored as an array.
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
`for` iterates over every value stored in the `RACSequence`, invoking the `reduce( )` closure for each one. The initial value of `start` is `YES`. The `reduce( )` closure is:
```objectivec

^(NSNumber *accumulator, id value) { return @(accumulator.boolValue && block(value)); }

```
Here it will again call the block( ) closure:
```objectivec

^(NSNumber *number) { return number.boolValue; }

```
`number` is the first value of the original signal’s `RACTuple`. In the first loop, the `reduce( )` closure performs an `&` operation on `YES` and the first value of the original signal’s `RACTuple`. In the second loop, the `reduce( )` closure performs an `&` operation on the first and second values of the original signal’s `RACTuple`; the result then participates in the next loop, where it is `&`-ed with the third value, and so on. This is also what the fold function means: `foldLeft` starts folding from the left. The `fold` function proceeds from left to right, performing an `&` operation on each value in the array converted from the `RACTuple`, one after another.

Each `RACTuple` is mapped to a `BOOL` value like this. The signal is then mapped into a new signal.

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
The implementation of the `or` operation is largely similar to that of the `and` operation. The three assertions serve exactly the same purpose as in the `and` operation, so they will not be repeated here. The key part of the `or` operation lies in the implementation of the `any` function. The input parameter of the `or` operation must also be of type `RACTuple`.
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
`any` checks the values in the `RACTupleSequence` array in order, applying `filter` to each one sequentially. If the `BOOL` value corresponding to `value` is `YES`, it is converted into a `RACTupleSequence` signal. If the corresponding value is `NO`, it is converted into an `empty` signal.

As long as the `RACTuple` is `NO`, it keeps returning an `empty` signal. Once the `BOOL` value is `YES`, it returns `1`. After the signal is transformed by `map`, it becomes `1`. After finding a value whose result is `YES`, it will not continue checking. If no `YES` is found and all intermediate values are `NO`, it will keep iterating until the last element in the array, and the signal can only return `0`.

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
The original signal is first wrapped into `RACEvent` events via the `materialize` transformation. It then evaluates the BOOL value of `predicateBlock(event.value)` in order. If it returns YES, the value is wrapped into a new `RACSignal`, YES is sent out, and subsequent signals are stopped. If it returns NO, `[RACSignal empty]`, an empty signal, is returned. Once `event.finished` is reached, `[RACSignal return:@NO]` is returned.

So the purpose of the `any:` operation is to find the first value that satisfies the `predicateBlock` condition. If such a value is found, it returns a `RACSignal` that sends YES; if none is found, it returns a `RACSignal` that sends NO.

#### 11. any
```objectivec

- (RACSignal *)any {
    return [[self any:^(id x) {
        return YES;
    }] setNameWithFormat:@"[%@] -any", self.name];
}

```
The `any` operation is a special case of the `any:` operation. That is, the `predicateBlock` closure always returns `YES`, so after the `any` operation, you will only ever get a new signal that sends a single `YES`.

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
all: is somewhat similar to any:. The original signal is first wrapped into `RACEvent` events via `materialize`. For each signal sent by the original signal, it checks in sequence whether `predicateBlock(event.value)` is `NO` or whether `event.eventType == RACEventTypeError`. If `predicateBlock(event.value)` returns `NO` or an error occurs, the new signal returns `NO`. If no issues occur throughout the process, it sends `YES` when `RACEventTypeCompleted` is reached.

all: can be used to determine whether the original signal emits an error event `RACEventTypeError` during its entire sending process, or whether there is any case where `predicateBlock` is `NO`. You can set `predicateBlock` to a valid condition. If the original signal emits an error event, or if it does not satisfy the configured condition, the new signal will send `NO`. If no error occurs during the entire process, or all values satisfy the condition configured by `predicateBlock`, then when `RACEventTypeCompleted` is reached, the new signal sends `YES`.


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
`subscribeForever` has four parameters: the first is the original signal, the second is the `next` closure, the third is the `error` closure, and the last is the `completed` closure.

As soon as `subscribeForever` enters this function, it invokes the `recursiveBlock()` closure. Inside that closure, there is a `recurse()` parameter. Within the `recursiveBlock()` closure, it subscribes to the original `RACSignal`. `next`, `error`, and `completed` each first invoke the closures passed in. Then, after `error` and `completed` finish executing the `error()` and `completed()` closures, they continue to execute `recurse()`. `recurse()` is the parameter passed to `recursiveBlock`.
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
It first retrieves the current `currentScheduler`, namely `recursiveScheduler`, and executes `scheduleRecursiveBlock`; within that function, `schedule` is invoked. Here, `recursiveScheduler` is of type `RACQueueScheduler`.
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
If the original signal has not been disposed, dispatch\_async will continue executing the block, and within that block the original signal will continue sending events. Therefore, as long as the original signal does not send an error event, disposable.disposed will not return YES, and the block will keep being invoked. That is why the recurse( ) closure is called at the end of both the error and completed handlers in subscribeForever. Calling the recurse( ) closure from error is intended to stop invoking the block and terminate all signals. Calling the recurse( ) closure from completed is intended to continue invoking the block( ) closure, which is the essence of repeat. The original signal will continue sending events, looping infinitely in this way.


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

So the purpose of the `retry:` operator is: when the original signal produces an `error`, retry up to `retryCount` times. If it still results in an `error`, retrying stops.

If the original signal does not produce an error, then once the original signal completes, `subscribeForever` also ends. For a signal with no `error` at all, the `retry:` operator is effectively a no-op.


#### 15. retry
```objectivec

- (RACSignal *)retry {
    return [[self retry:0] setNameWithFormat:@"[%@] -retry", self.name];
}

```
The `retry` operation here is an infinite retry operation. Because after `retryCount` is set to 0, inside the `error` closure, `retryCount` is always equal to 0, and the original signal is never disposed. As a result, `subscribeForever` keeps retrying indefinitely.

Similarly, if you call the `retry` operation on a signal that never errors, it has no effect.


#### 16. scanWithStart: reduceWithIndex: (defined in the superclass RACStream)


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
The scanWithStart transformation consists of an initial value, the transformation function reduceBlock( ), and an index variable that advances step by step. Each value from the original signal is transformed by the transformation function reduceBlock( ). index is incremented each time. The initial value for the transformation is passed in via the startingValue parameter.


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


scanWithStart: reduce: is simply a shorthand version of scanWithStart: reduceWithIndex:. The transformation function is also passed in from the external closure reduceBlock( ). The only difference is that the auto-incrementing `index` variable is not used during the transformation process.


**By using this family of `scan` operations, you can effectively eliminate side-effect operations!**

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


`aggregate` means to compute an aggregate. Therefore, the transformed signal ultimately contains only the final value.

The `aggregateWithStart: reduceWithIndex:` operation calls `scanWithStart: reduceWithIndex:`, and its underlying principle is exactly the same. The difference is that it adds two extra operations: `startWith:` and `takeLast:1`. `startWith:` prepends the `start` signal before the signal transformed by `scanWithStart: reduceWithIndex:`. `takeLast:1` takes the last signal. Detailed analyses of `takeLast:` and `startWith:` will be covered later in this article.

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


`aggregateWithStart: reduce:` calls `aggregateWithStart: reduceWithIndex:`, except that it does not use the index value. Likewise, if the original signal does not send a `complete` event, it will not emit any values.


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
aggregateWithStartFactory: reduce: is implemented internally by calling aggregateWithStart: reduce:, except that its input parameters include an additional startFactory( ) closure that produces start.

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

The `collect` function calls the `aggregateWithStartFactory: reduce:` method. It collects the values from all source signals and stores them in an `NSMutableArray`.


### II. Time Operations


![](https://img.halfrost.com/Blog/ArticleImage/32_12.png)


#### 1. throttle:valuesPassingTest:

This operation takes a time interval `NSTimeInterval` and a predicate closure `predicate`. For signals sent by the source signal within a time interval `NSTimeInterval`, if they still satisfy `predicate`, those source-signal values are “swallowed”. When the time interval `NSTimeInterval` ends, `predicate` is evaluated again; if it no longer matches, the source-signal value is sent downstream.


![](https://img.halfrost.com/Blog/ArticleImage/32_13.png)


As shown above, after the source signal sends `1`, no signal is emitted during the `NSTimeInterval`, and `predicate` is also `YES`, so `1` is transformed into a new signal and sent out. Next, because the source signal sends `2`, `3`, and `4` all within the `NSTimeInterval`, they are all “swallowed”. Only after the source signal sends `5`, and no new signal is emitted during the following `NSTimeInterval`, is the source value `5` sent out. The same applies to `6` from the source signal.


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
        
        void (^flushNext)(BOOL send) = ^(BOOL send) { // Omitted for now };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // Omitted for now
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
Looking at this implementation, there are two assertions. It first checks whether the `interval` passed in is greater than 0; of course, values less than 0 are not allowed. The other assertion is that the `predicate` closure passed in must not be nil, since it is used later to control the flow.

The rest of the implementation follows the usual pattern: the return value is a signal, and the closure of the new signal subscribes to the original signal and transforms it.

So the key parts of the entire transformation are the `flushNext` closure and the `subscribeNext` closure used when subscribing to the original signal.

Once the new signal is subscribed to and the closure executes to this point, it subscribes to the original signal.
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
1. First, create a delayScheduler. Check whether the current currentScheduler exists; if it does not, use the previously created [RACScheduler scheduler]. Although both are of type RACTargetQueueScheduler, currentScheduler is com.ReactiveCocoa.RACScheduler.mainThreadScheduler, whereas [RACScheduler scheduler] creates com.ReactiveCocoa.RACScheduler.backgroundScheduler.

2. Call the predicate( ) closure, passing in the signal value x sent by the original signal. After predicate evaluates it, you get the BOOL variable shouldThrottle, which indicates whether the throttling switch should be enabled.

3. RACCompoundDisposable is used as a cross-thread mutual-exclusion semaphore because all RACDisposable signals are added to the RACCompoundDisposable. The following operations are then locked across threads using @synchronized.

4. The flushNext( ) closure is used to hook the send operation of the original signal.
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
If `NO` is passed into this closure, the original signal cannot immediately `sendNext`. If `YES` is passed in, and `hasNextValue = YES`, meaning the original signal still has a value pending to be sent, then the original signal is sent.

`shouldThrottle` is a gate that controls at any time whether the original signal can be sent.

To summarize: each value sent by the original signal is subscribed to in the `did subscribe` closure inside `throttle:valuesPassingTest:`. This closure mainly does four things:

1. Calls the `flushNext(NO)` closure to determine whether the original signal’s value can be sent. The input parameter is `NO`, so the original signal’s value is not sent.
2. Checks whether the gate condition `predicate(x)` allows the original signal’s value to be sent.
3. If both conditions above are satisfied, assigns the value sent by the original signal to `nextValue`, and `hasNextValue = YES` indicates that there is currently a value to be sent.
4. Starts a `delayScheduler`, delays by `interval`, and sends this value from the original signal, i.e. calls `flushNext(YES)`.

Now let’s analyze the entire process of `throttle:valuesPassingTest:`.

When the original signal emits the first value, if no new signal is sent within the `interval` time window, `delayScheduler` delays by `interval`, executes `flushNext(YES)`, and sends this first value from the original signal.
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
Note that inside the dispatch\_after closure, before [self performAsCurrentScheduler:block], there is a crucial check:
```objectivec

if (disposable.disposed) return;

```
This check is used to determine whether, after the first signal is sent, any other signal exists within the `interval` time window. If there is, the first signal will definitely be disposed. Execution returns here, so the first signal will not be sent out.

This achieves the purpose of throttling: originally, each signal would create a `delayScheduler` and be delayed by `interval`. During that time, if the original signal does not send a new value—that is, if the original signal has not been disposed—then the original signal’s value is sent out. If, during that time, the original signal sends another new value, then the first value is discarded. During the sending process, each signal must evaluate `predicate()`. This acts as the gate switch: if throttling is disabled at any time, the value sent by the original signal must be emitted immediately.

There are two additional points to note. First, if a new signal is sent exactly at the `interval` moment, the original signal will also be discarded. In other words, only if the original signal does not send a new value within a time period of `>= interval` can the original value be sent out. Second, when the original signal sends `completed`, `flushNext(YES)` is executed immediately, sending out the last value of the original signal.

#### 2. throttle:
```objectivec

- (RACSignal *)throttle:(NSTimeInterval)interval {
    return [[self throttle:interval valuesPassingTest:^(id _) {
        return YES;
    }] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
}

```
This operation actually calls the `throttle:valuesPassingTest:` method, passing in the time interval `interval`, while the `predicate()` closure always returns `YES`. Every event from the original signal is throttled.


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
The implementation of `bufferWithTime:onScheduler:` is similar to that of `throttle:valuesPassingTest:`. It starts with two assertions, both checking the scheduler. The first assertion checks whether the scheduler is `nil`. The second assertion checks the scheduler’s type: the scheduler must not be of type `immediateScheduler`, because this method needs to buffer some signals, so it cannot use an `immediateScheduler`.
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
In subscribeNext, when the array does not contain any values from the original signal, it starts a scheduler, waits for interval, and then executes the flushValues closure. If the array already has values, it continues appending them to the values array. The key part is the content inside the closure, shown below:
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
The `flushValues( )` closure mainly wraps the array into a tuple and sends it out, then clears the original array completely. This is also what `bufferWithTime:onScheduler:` does: within the `interval`, it buffers all values from the original signal during that time span, and at the moment the `interval` elapses, it packages those buffered values into a tuple and sends it out.

As with the `throttle:valuesPassingTest:` method, when the original signal completes, the `flushValues( )` closure is executed immediately, sending out all stored values.


#### 4. delay:

The behavior of the `delay:` function follows the same pattern as the previous ones, and its implementation is also template-based. The only differences are in `subscribeNext` and in the closure that determines whether to send.
```objectivec

- (RACSignal *)delay:(NSTimeInterval)interval {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        // We may never use this scheduler, but we need to set it up ahead of
        // time so that our scheduled blocks are run serially if we do.
        RACScheduler *scheduler = [RACScheduler scheduler];
        
        void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
            // Temporarily omitted
        };
        
        RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
            // Temporarily omitted
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
Inside subscribeNext of delay:, it simply executes the schedule closure.
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
The work done in the `schedule` closure is to send the original signal’s value after a delay of `interval`.


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
In this operation, the implementation is not difficult. First, let’s look at the two assertions: both protect the input parameter type. `scheduler` must not be nil, and it must not be of type `immediateScheduler`. The reason is the same as above: this is a delayed operation.

The main implementation is in `after:repeatingEvery:withLeeway:schedule:`.
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
The implementation here uses GCD to create a Timer on `self.queue`, with `interval` as the time interval and `leeway` as the tolerance.

The `leeway` parameter specifies the desired precision for timer events on the dispatch source, allowing the system to manage and wake the kernel more flexibly. For example, the system can use the `leeway` value to trigger the timer earlier or later, so that it can be better coalesced with other system events. When creating your own timer, you should specify a `leeway` value whenever possible. However, even if you set `leeway` to 0, you still cannot fully expect the timer to fire events with exact nanosecond precision.

This timer performs `sendNext` at each `interval`, which means it sends the value from the original signal.


#### 6. interval:onScheduler:
```objectivec


+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    return [[RACSignal interval:interval onScheduler:scheduler withLeeway:0.0] setNameWithFormat:@"+interval: %f onScheduler: %@", (double)interval, scheduler];
}

```
This operation simply calls the previous method, `interval:onScheduler:withLeeway:`, with `leeway = 0.0`. The implementation has already been analyzed above, so I won’t repeat it here.


### Finally

I originally wanted to exhaustively analyze the implementation of every `RACSignal` operation, but there are simply too many operations in total. Covering all of them in a single article would make it far too long, so I’ll split the analysis into several parts. For `RACSignal`, the remaining topics include filtering operations, multi-signal composition operations, hot/cold signal conversion operations, and higher-order signal operations. I’ll continue the analysis in the next article. As always, feedback and corrections are very welcome.