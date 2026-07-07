+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "ReactiveCocoa", "RAC", "RACSignal"]
date = 2016-12-10T09:12:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/35_0_.png"
slug = "reactivecocoa_racsignal_operations3"
tags = ["iOS", "ReactiveCocoa", "RAC", "RACSignal"]
title = "Analysis of the Underlying Implementation of All RACSignal Transformation Operations in ReactiveCocoa (Part 2)"

+++


### Preface


Continuing from the source-code implementation analysis in the [previous article](https://halfrost.com/reactivecocoa_racsignal_operations2/), this article continues analyzing the underlying implementation of RACSignal transformation operations.


### Table of Contents

- 1. Higher-Order Signal Operations
- 2. Synchronization Operations
- 3. Side-Effect Operations
- 4. Multithreading Operations
- 5. Other Operations


### 1. Higher-Order Signal Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_1.png)


Most higher-order operations operate on higher-order signals. In other words, the values sent by a signal are themselves signals, or even higher-order signals. By analogy with arrays, this is like a multidimensional array, where the elements inside the array are still arrays.


#### 1. flattenMap: (defined in the parent class RACStream)

flattenMap: plays a very important role throughout RAC. Many signal transformations can be implemented with flattenMap:.

The four operations map:, flatten, filter, and sequenceMany: are all implemented using flattenMap:. Moreover, many other transformation implementations also make use of map:, flatten, and filter.


Let’s review the implementation of map::
```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```
The operation of `map:` is actually just applying `flattenMap:` directly to the original signal. The value of the new signal produced by the transformation is `block(value)`.

The implementation of `flatten` will be analyzed in detail next, so we’ll skip it for now.

Implementation of `filter`:
```objectivec

- (instancetype)filter:(BOOL (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^ id (id value) {
        block(value) ? return [class return:value] :  return class.empty;
    }] setNameWithFormat:@"[%@] -filter:", self.name];
}

```
The implementation of `filter` is somewhat similar to `map:`. It also applies `flattenMap:` to the original signal, except that `block(value)` is not used as the return value, but as the predicate. If the condition in this closure is satisfied, the return value of the newly transformed signal is `value`; otherwise, it returns an empty signal.

Among the higher-order operators to be analyzed next, the implementations of `switchToLatest`, `try:`, and `tryMap:` will also use `flattenMap:`.

Source implementation of `flattenMap:`:
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
`flattenMap:` is implemented by calling the `bind` function, transforming the original signal and returning the new signal from `block(value)`. The concrete flow of the `bind` operation has already been analyzed in [this article](https://halfrost.com/reactivecocoa_racsignal/), so it will not be repeated here.

From the source code of `flattenMap:`, you can see that it supports Promise-like serial asynchronous operations, and `flattenMap:` satisfies the `bind` part of the Monad definition. `flattenMap:` cannot implement the operations of `takeUntil:` and `take:`.

However, the `bind` operation can implement `take:`, and `bind` fully satisfies the `bind` part of the Monad definition.

#### 2. flatten (defined in the superclass RACStream)

Implementation of `flatten`:
```objectivec

- (instancetype)flatten {
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self flattenMap:^(id value) {
        return value;
    }] setNameWithFormat:@"[%@] -flatten", self.name];
}


```
The `flatten` operation must be applied to higher-order signals. If the value inside the signal is not itself a signal—that is, if it is not a higher-order signal—then it will crash. The crash message is as follows:
```objectivec

*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Value returned from -flattenMap: is not a stream

```
Therefore, `flatten` is a rank-reducing operation performed on higher-order signals. Each time a higher-order signal sends a signal, after the `flatten` transformation, because of the `flattenMap:` operation, each value of the newly returned signal is the value of each signal in the original signal.

![](https://img.halfrost.com/Blog/ArticleImage/35_2.png)


If you perform a `merge:` operation on signal A, signal B, and signal C, you can achieve the same effect as `flatten`.
```objectivec

    [RACSignal merge:@[signalA,signalB,signalC]];

```
The merge: operation was analyzed in [the previous article](https://halfrost.com/reactivecocoa_racsignal_operations2/); let’s review it again:
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
Now let’s look back at this code. Although `copiedSignals` is an `NSMutableArray`, it effectively composes a higher-order signal like the one shown above. Then, whenever any of these signals emits a signal, it is sent to the subscriber. The entire operation is exactly what the literal meaning of `flatten` suggests: flattening.


![](https://img.halfrost.com/Blog/ArticleImage/35_3.png)


Also, in ReactiveCocoa v2.5, `flatten` defaults to the `flattenMap:` operation.
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
In ReactiveCocoa v3.x, v4.x, and v5.x, the `flatten` operation lets you choose among three operation modes: `merge`, `concat`, and `switchToLatest`.

#### 3. flatten:

The `flatten:` operation must also operate on a higher-order signal. If the values inside the signal are not signals—that is, if it is not a higher-order signal—it will crash.

The implementation of `flatten:` is relatively complex, so let’s analyze it step by step:
```objectivec

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *compoundDisposable = [[RACCompoundDisposable alloc] init];
        NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];
        NSMutableArray *queuedSignals = [NSMutableArray array];

        __block BOOL selfCompleted = NO;
        __block void (^subscribeToSignal)(RACSignal *);
        __weak __block void (^recur)(RACSignal *);
        recur = subscribeToSignal = ^(RACSignal *signal) { // omitted for now};

        void (^completeIfAllowed)(void) = ^{ // omitted for now};
        
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
First, let’s explain the purpose of a few variables and arrays.

`activeDisposables` contains the `disposables` signals for the subscribers that are currently subscribed.

`queuedSignals` contains signals that have been temporarily cached and are waiting to be subscribed to.

`selfCompleted` indicates whether the higher-order signal has completed.

The `subscribeToSignal` closure is used to subscribe to a given signal. The input parameter of this closure is a signal; inside the closure, it subscribes to that signal and performs some operations.

`recur` is a weak reference to the `subscribeToSignal` closure, used to prevent a strong-weak retain cycle. We’ll analyze the `subscribeToSignal` closure below, and then it will be clear why `recur` needs to be marked as `weak`.

`completeIfAllowed` is used to notify the subscriber and send `completed` when all signals have finished sending.

The input parameter `maxConcurrent` means the maximum number of signals that can be subscribed to at the same time.

Now let’s analyze the actual subscription process in detail.

Inside `flatten:`, the higher-order signal is subscribed to, and the signals it emits are handled. This part of the code is relatively simple:
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
1. If the current maximum number of signals that can be accommodated is > 0, and the `activeDisposables` array has already reached that maximum, no new signals can be added. In that case, cache the current signal in the `queuedSignals` array.

2. Once there is an available slot in the `activeDisposables` array for a new signal, call the `subscribeToSignal( )` closure to start subscribing to the new signal.

3. When everything is complete, mark the variable `selfCompleted` as `YES`, and call the `completeIfAllowed( )` closure.
```objectivec

void (^completeIfAllowed)(void) = ^{
    if (selfCompleted && activeDisposables.count == 0) {
        [subscriber sendCompleted];
        subscribeToSignal = nil;
    }
};


```
When `selfCompleted = YES` and all signals in the `activeDisposables` array have finished sending—meaning there are no more signals that can be sent, i.e. `activeDisposables.count = 0`—then `sendCompleted` is sent to the subscriber. One point worth noting here is that `subscribeToSignal` also needs to be manually set to `nil`. This is because the `subscribeToSignal` closure strongly references the `completeIfAllowed` closure, preventing the `completeIfAllowed` closure from being destroyed prematurely. Therefore, after the `completeIfAllowed` closure finishes executing, the `subscribeToSignal` closure needs to be set to `nil` as well.

Next, the key focus is the `subscribeToSignal( )` closure.
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
1. `activeDisposables` first adds the `Disposable` for the signal emitted by the current higher-order signal (that is, the `Disposable` for the input signal).
2. Here, `recur` is made `__strong`, because the `subscribeToSignal( )` closure will be used in step 6 below. This is also to prevent retain cycles.
3. Subscribe to the input signal and send the signal to the subscriber. After sending is complete, remove its corresponding `Disposable` from `activeDisposables`.
4. If the currently cached `queuedSignals` array contains no cached signals, call the `completeIfAllowed( )` closure.
5. If the currently cached `queuedSignals` array contains cached signals, take out the signal at index 0 and remove it from the `queuedSignals` array.
6. Continue subscribing to the signal taken out in step 4, and continue calling the `subscribeToSignal( )` closure.


In summary: each time the higher-order signal sends a signal value, determine whether the number of items in the `activeDisposables` array has already exceeded `maxConcurrent`. If there is no capacity, cache it in the `queuedSignals` array. If there is still capacity, start calling the `subscribeToSignal( )` closure and subscribe to the current signal.

Each time a signal finishes sending, check the number of items in the cached array `queuedSignals`. If there are no signals left in the cached array, terminate sending from the original higher-order signal. If there are still signals in the cached array, continue subscribing. This loops until all signals from the original higher-order signal have finished sending.


The entire execution flow of `flatten:` has now been analyzed. Finally, let’s take a closer look at the input parameter `maxConcurrent`.

Looking back at the implementation of `flatten:` above, there is this line:
```objectivec

if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) 

```
So the value range of maxConcurrent ultimately determines how flatten behaves.

What happens if maxConcurrent < 0? The program crashes, because the source code contains the following initialization line:
```objectivec

NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];

```
When `activeDisposables` is initialized, it initializes an `NSMutableArray` with a size of `maxConcurrent`. If `maxConcurrent < 0`, initialization will crash here.

What happens if `maxConcurrent = 0`? In that case, `flatten:` degenerates into `flatten`.

![](https://img.halfrost.com/Blog/ArticleImage/35_4.png)


What happens if `maxConcurrent = 1`? In that case, `flatten:` degenerates into `concat`.

![](https://img.halfrost.com/Blog/ArticleImage/35_5.png)


What happens if `maxConcurrent > 1`? Since I haven’t yet encountered a use case that requires `maxConcurrent > 1`, I won’t include a diagram here for now. When `maxConcurrent > 1`, the behavior of `flatten` also depends on the relationship between the number of higher-order signals and `maxConcurrent`. If the number of higher-order signals is <= the value of `maxConcurrent`, then `flatten:` again degenerates into `flatten`. If the number of higher-order signals is > the value of `maxConcurrent`, the extra signals will enter the `queuedSignals` cache array.


#### 4. concat


The implementation of `concat` here is defined in `RACSignal`.
```objectivec

- (RACSignal *)concat {
    return [[self flatten:1] setNameWithFormat:@"[%@] -concat", self.name];
}

```
A quick look at the source code tells you that concat is actually flatten:1.


Of course, RACSignal defines the concat: method. This method was already analyzed in a previous [article](https://halfrost.com/reactivecocoa_racsignal/), so here we’ll review and compare it:
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


By comparison, we can see that although the final transformed results are similar, the signals they operate on are different. `concat` performs a dimensionality-reduction operation on higher-order signals. `concat:` is an operation that connects two signals. If you take a higher-order signal along the time axis and, from left to right, connect each signal one by one using `concat:`, the result is `concat`.


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
The `switchToLatest` operation can only be used on higher-order signals. If the original signal contains a value that is not a signal, it will crash with the following error:
```vim

***** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: '-switchToLatest requires that the source signal (<RACDynamicSignal: 0x608000038ec0> name: ) send signals.

```
In the `switchToLatest` operation, the original signal is first converted into a hot signal, and `connection.signal` is of type `RACSubject`. Then `flattenMap:` is applied to the `RACSubject`. During the `flattenMap:` transformation, `connection.signal` first `concat:`s a `never` signal. The reason for `concat:`ing a `never` signal here is to prevent the inner signal from completing too early and causing the subscriber to receive a `complete` signal.

In the `flattenMap:` transformation, `x` is also a signal. Applying `takeUntil:` to `x` means that before the next signal arrives, `x` will keep sending values. Once the next signal arrives, `x` will be unsubscribed from, and the new signal will start being subscribed to.


![](https://img.halfrost.com/Blog/ArticleImage/35_7.png)


After a higher-order signal goes through the `switchToLatest` flattening operation, you get the signal shown in the figure above.


#### 6. switch: cases: default:


The source implementation of `switch: cases: default:` is as follows:
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
There are three assertions in the implementation, all of which are requirements on the input parameters. The input `signal` and the `cases` dictionary must not be `nil`. In addition, the value corresponding to every key in the `cases` dictionary must be of type `RACSignal`. Note that `defaultSignal` is allowed to be `nil`.

The rest of the implementation is relatively straightforward: it performs a `map` transformation on the input `signal`. This transformation is a higher-order transformation.

For each value emitted by `signal`, that value is used as a key to look up the corresponding value in the `cases` dictionary. Of course, the corresponding value is a signal. If the value’s corresponding signal is not empty, the value emitted by `signal` is mapped to the corresponding signal in the dictionary. If the corresponding value is empty, the value emitted by the original `signal` is mapped to the `defaultSignal`.

If the signal obtained after the transformation is `nil`, an error signal is returned. If the obtained signal is not `nil`, then after the original signal has been fully transformed, it becomes a higher-order signal, and every value inside that higher-order signal is itself a signal. Finally, `switchToLatest` is applied to this higher-order signal.


#### 7. if: then: else:

The source implementation of `if: then: else:` is as follows:
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
The input signals `boolSignal`, `trueSignal`, and `falseSignal` must not be `nil`.

The values contained in `boolSignal` must all be of type `NSNumber`.

Perform a `map` lifting operation on `boolSignal`: if the value in `boolSignal` is `YES`, convert it to the `trueSignal`; if it is `NO`, convert it to the `falseSignal`. After the lifting conversion is complete, `boolSignal` becomes a higher-order signal, and then `switchToLatest` is applied.


#### 8. catch:

The implementation of `catch:` is as follows:
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
When subscribing to the original signal, if an error occurs, the `catchBlock( )` closure is executed, with the newly generated `error` passed in as its argument. The `catchBlock( )` closure produces a new `RACSignal`, and the subscriber then subscribes to that signal again.

The reason this is considered a higher-order operation is that after the original signal errors, the error is lifted into a signal.

#### 9. catchTo:

The implementation of `catchTo:` is as follows:
```objectivec

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
}

```
The implementation of catchTo: simply calls the catch: method; the only difference is that the catchBlock( ) closure inside the original catch: method always returns catchTo:'s input parameter—the signal.


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
try: can be used to perform a signal promotion operation. It applies a flattenMap transformation to the original signal, invoking the tryBlock( ) closure once for each value emitted by the signal. If the closure returns YES, then [RACSignal return:value] is returned; if the closure returns NO, then an error is returned. If the original signal contains only values, then after the try: operation, each value is converted into an RACSignal, so the original signal becomes a higher-order signal.

Of course, if the block implementation returns a signal, no promotion will occur at this point. The returned signal does not have to return another signal; it can return values directly.


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
The implementation of tryMap: is basically the same as that of try:. The only difference is the return value of the input closure. In tryMap:, the mapBlock( ) closure is called, returning an object. If this object is not nil, [RACSignal return:mappedValue] is returned. If the returned object is nil, it is transformed into an error signal.

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
timeout: onScheduler: is implemented very simply. Compared with a normal signal subscription, it adds a `timeoutDisposable` operation. Inside the signal subscription, it starts a scheduler; after `interval` has elapsed, it stops subscribing to the original signal and sends `sendError` to the subscriber.

The semantics of this operation are exactly consistent with its method name: after `interval` has elapsed, it is considered a timeout, so the subscription to the original signal is stopped and `sendError` is sent.


To summarize the lifting / lowering operations for higher-order signals in ReactiveCocoa v2.5:


![](https://img.halfrost.com/Blog/ArticleImage/35_8.png)


**Lifting operations**:

1. map( map a value into a signal)
2. [RACSignal return:signal]


![](https://img.halfrost.com/Blog/ArticleImage/35_9.png)

**Lowering operations**:

1. flatten(equivalent to flatten:0, +merge:)
2. concat(equivalent to flatten:1)
3. flatten:1
4. switchToLatest
5. flattenMap:

These five operations can turn a higher-order signal into a lower-order signal, but after lowering, there are ultimately only three resulting behaviors: switchToLatest, flatten, and concat. For the specific diagrams, see the analysis above.


### II. Synchronous Operations

ReactiveCocoa also includes some synchronous operations. In general, we rarely use these operations. Unless you are truly certain that doing so will not cause problems, using them carelessly can lead to serious issues such as thread deadlocks.

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
        // Lock
        [condition lock];
        
        value = x;
        localSuccess = YES;
        
        done = YES;
        [condition broadcast];
        // Unlock
        [condition unlock];
    } error:^(NSError *e) {
        // Lock
        [condition lock];
        
        if (!done) {
            localSuccess = NO;
            localError = e;
            
            done = YES;
            [condition broadcast];
        }
        // Unlock
        [condition unlock];
    } completed:^{
        // Lock
        [condition lock];
        
        localSuccess = YES;
        
        done = YES;
        [condition broadcast];
        // Unlock
        [condition unlock];
    }];
    // Lock
    [condition lock];
    while (!done) {
        [condition wait];
    }
    
    if (success != NULL) *success = localSuccess;
    if (error != NULL) *error = localError;
    // Unlock
    [condition unlock];
    return value;
}


```
From the source code, a synchronous method like `firstOrDefault: success: error:` can easily lead to thread deadlocks. Inside the closures for `subscribeNext`, `error`, and `completed`, it calls the condition lock: first `lock`, then `unlock`. If a signal sends a value but none of the three operations—`subscribeNext`, `error`, or `completed`—is executed, then `[condition wait]` will run and wait.

Because `take:1` is applied to the original signal, only the first value is processed. After any one of the three operations—`subscribeNext`, `error`, or `completed`—finishes executing, the lock is acquired again, and the externally passed-in parameters `success` and `error` are assigned values so that the caller can obtain the internal state. The final returned signal is the value from the first `next` of the original signal. If the original signal has no first value—for example, it directly sends `error` or `completed`—then `defaultValue` is returned.

When `done` is `YES`, it means one of the three operations—`subscribeNext`, `error`, or `completed`—has been successfully executed. Otherwise, it is `NO`.

When `localSuccess` is `YES`, it means a value was sent successfully, or all values from the original signal were sent successfully, with no errors occurring during the process.

The `broadcast` operation on `condition` wakes up other threads. It is equivalent to the `signal` operation of a mutex semaphore in the operating system.

The input parameter `defaultValue` provides an initial value for the internal variable `value`. Once the original signal sends a value, the value of `value` will always stay in sync with the value from the original signal.

`success` and `error` are addresses of external variables, allowing the external caller to observe the internal state. They are assigned inside the function, and their values are retrieved outside the function.


#### 2. firstOrDefault:
```objectivec

- (id)firstOrDefault:(id)defaultValue {
    return [self firstOrDefault:defaultValue success:NULL error:NULL];
}


```
The implementation of firstOrDefault: simply calls the firstOrDefault: success: error: method. It just does not need to pass success and error, because it does not care about the internal state. The signal ultimately returns the value from the first next in the original signal. If the original signal has no first value—for example, it directly errors or completes—then defaultValue is returned.


#### 3. first
```objectivec

- (id)first {
	return [self firstOrDefault:nil];
}

```
The first method is even more abbreviated; it does not even pass defaultValue. The final returned value is the value inside the first next from the original signal. If the original signal has no first value—for example, it errors directly or completes—then nil is returned.

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
waitUntilCompleted: still calls the firstOrDefault: success: error: method internally. The return value is success. As long as the original signal finishes sending normally, success should be YES; however, if an error occurs during sending, success will be NO. Since success is used as the return value, callers can observe whether the sending succeeded.

Although this method can observe the state when sending completes, you should still avoid using it where possible, because its implementation calls the firstOrDefault: success: error: method, which performs a large number of locking operations. A slight mistake can easily lead to a deadlock.

#### 5. toArray
```objectivec

- (NSArray *)toArray {
	return [[[self collect] first] copy];
}


```
After collect, all values from the original signal are added to an array, and the first value emitted by the resulting signal is that array. Therefore, after first is executed, the first value is the array containing all values from the original signal.


### III. Side-Effect Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_10.png)


ReactiveCocoa v2.5 also provides several functions for performing side effects.

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
doNext: allows us to execute a `block` closure before the original signal’s `sendNext`; within this closure, we can perform any side-effect operations we want to execute.


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
doError: allows us to execute a block closure before the original signal sends `sendError`; within this closure, we can perform any side-effect operations we want.

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
doCompleted: allows us to execute a block closure before the original signal sends `sendCompleted`. Inside this closure, we can perform any side-effect operations we want to execute.


**The three operations doNext:, doError:, and doCompleted: are quite useful. Any side-effect operations should preferably be declared inside them, so that readers can immediately and clearly see that these are side-effect operations.**


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
initially: allows us to call the defer: operation before the original signal is sent, executing a closure before return self. In this closure, we can perform any side-effect operations we want to execute.


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
finally: calls the `doError:` and `doCompleted:` operations, inserting a `block( )` closure before `sendError` and before `sendCompleted`, respectively. This allows a side-effect operation that we want to run when the signal is about to terminate due to an error and unsubscribe, or before it sends completion.


### IV. Multithreading Operations

There are three multithreading-related operations in `RACSignal`.

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
The argument to deliverOn: is a scheduler. When the original signal invokes subscribeNext, sendError, or sendCompleted, it calls the scheduler’s schedule method.
```objectivec


- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];

	block();
	return nil;
}

```
In the `schedule` method, it checks whether the current `currentScheduler` is `nil`. If it is `nil`, it calls `backgroundScheduler` to execute the `block()` closure; otherwise, the current `currentScheduler` directly executes the `block()` closure.
```objectivec


+ (instancetype)currentScheduler {
	RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
	if (scheduler != nil) return scheduler;
	if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

	return nil;
}

```
To determine whether `currentScheduler` exists, check two things: first, whether the current thread’s dictionary contains `RACSchedulerCurrentSchedulerKey` (`@"RACSchedulerCurrentSchedulerKey"`). If a corresponding value exists, return the scheduler. Second, check whether the current class is on the main thread; if it is, return `mainThreadScheduler`. If neither condition is met, then the current `currentScheduler` does not exist, and `nil` is returned.


The characteristic of the `deliverOn:` operation is that the threads on which the original signal sends `sendNext`, `sendError`, and `sendCompleted` are deterministic.


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
subscribeOn: subscribes to the original signal inside the closure of the scheduler passed in. It differs from deliverOn::

subscribeOn: can ensure that the didSubscribe block( ) closure runs on the input scheduler, but it cannot guarantee which scheduler the original signal’s subscribeNext, sendError, and sendCompleted run on.

deliverOn: is the opposite of subscribeOn:: it can ensure which scheduler the original signal’s subscribeNext, sendError, and sendCompleted run on, but it cannot guarantee which scheduler the didSubscribe block( ) closure runs on.

#### 3. deliverOnMainThread
```objectivec


- (RACSignal *)deliverOnMainThread {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block volatile int32_t queueLength = 0;
        
        void (^performOnMainThread)(dispatch_block_t) = ^(dispatch_block_t block) { // omitted for now};
        
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
Comparing this with the source implementation of `deliverOn:`, we can see that the two are quite similar. The only difference is that `deliverOnMainThread` wraps `sendNext`, `sendError`, and `sendCompleted` in a `performOnMainThread` closure for execution.
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
The closure inside performOnMainThread ensures that the input block( ) closure is always executed on the main thread.

OSAtomicIncrement32 and OSAtomicDecrement32 are atomic operations, representing +1 and -1 respectively. In the if-else check below, regardless of which branch is satisfied, the block( ) closure is ultimately still executed on the main thread.

deliverOnMainThread can guarantee that the original signal’s subscribeNext, sendError, and sendCompleted are all executed on the main thread, MainThread.

### V. Other Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_12.png)


#### 1. setKeyPath: onObject: nilValue:

The source implementation of setKeyPath: onObject: nilValue: is as follows:
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
Although the code is a bit long, it is not hard to follow line by line. There are four places worth paying attention to, and they have already been marked in the code above. Next, let’s analyze them one by one.

##### 1. The objc\_precise\_lifetime issue.

The author wrote the following comment here:

 > Possibly spec, possibly compiler bug, but this \_\_bridge cast does not result in a retain here, effectively an invisible \_\_unsafe\_unretained qualifier. Using objc\_precise\_lifetime gives the \_\_strong reference desired. The explicit use of \_\_strong is strictly defensive.

The author suspects this is a compiler bug: even if \_\_strong is explicitly used, it still cannot guarantee that the object is strongly referenced, so objc\_precise\_lifetime is also needed to ensure a strong reference.

Regarding this issue, I looked up the LLVM documentation, and it is mentioned in [6.3 precise lifetime semantics](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id42).

In general, any variable declared as \_\_strong has a well-defined lifetime. ARC keeps these \_\_strong variables retained throughout their lifetime.

However, automatic local variables do not have a precise lifetime. These variables merely hold a strong reference—specifically, a pointer-typed value that strongly references a retained object. These values are entirely subject to how the local optimizer chooses to optimize them. Therefore, trying to change the lifetime of such local variables is not possible. Many optimizations can, in theory, shorten the lifetime of local variables, but those optimizations are very useful.

However, LLVM provides us with the objc\_precise\_lifetime keyword, which can make the lifetime of a local variable precise. This keyword can be very useful in some cases. In even more extreme cases, even if the local variable is not used at all, it can still maintain a deterministic lifetime.

Returning to the source code, the next step is to call setValue: forKeyPath: on the input parameter object.
```objectivec

[object setValue:x ?: nilValue forKeyPath:keyPath];

```
If x is nil, return the value passed in as nilValue.


##### 2.  AssociatedObject Associated Objects

If the bindings dictionary does not exist, call objc\_setAssociatedObject to associate an object with object. The parameter is OBJC\_ASSOCIATION\_RETAIN\_NONATOMIC. If the bindings dictionary exists, use objc\_getAssociatedObject to retrieve the dictionary.

Update the bound key-value pair in the dictionary. The key is the input parameter keyPath, and the value is the original signal.


##### 3.  When unsubscribing from the original signal
```objectivec

[bindings removeObjectForKey:keyPath];

```
When the signal is unsubscribed, remove all associated values.

##### 3.  OSAtomicCompareAndSwapPtrBarrier

This function is part of the OSAtomic atomic operations. Its prototype is as follows:
```objectivec

OSAtomicCompareAndSwapPtrBarrier(type __oldValue, type __newValue, volatile type *__theValue)

```
>Compares a variable against the specified old value. If the two values are equal, this function assigns the specified new value to the variable; otherwise, it does nothing. The comparison and assignment are done as one atomic operation and the function returns a Boolean value indicating whether the swap actually occurred.

This function compares whether \_\_oldValue matches the value at the memory location pointed to by \_\_theValue. If it matches, it stores the value of \_\_newValue into the memory location pointed to by \_\_theValue. The return value of the function is a BOOL indicating whether the swap succeeded.
```objectivec
	while (YES) {
	void *ptr = objectPtr;
	if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr))   {
		  break;
	}
  }

```
In this infinite `while` loop, the loop can exit only when `OSAtomicCompareAndSwapPtrBarrier` returns `YES`. A return value of `YES` means that `&objectPtr` has been set to `NULL`, which ensures thread safety while avoiding dangling pointer issues.


#### 2. setKeyPath: onObject:
```objectivec

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
    return [self setKeyPath:keyPath onObject:object nilValue:nil];
}

```
setKeyPath: onObject: simply calls setKeyPath: onObject: nilValue:, except that nil is passed for nilValue.


### Finally

This completes the low-level implementation analysis of all RACSignal operations. Feedback and suggestions are welcome.