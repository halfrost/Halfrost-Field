# Analysis of the Underlying Implementation of All Transformation Operations in ReactiveCocoa's RACSignal (Part 2)

![](https://img.halfrost.com/Blog/ArticleTitleImage/35_0_.png)


### Preface


Continuing from the source-code implementation analysis in the [previous article](https://halfrost.com/reactivecocoa_racsignal_operations2/), this article continues analyzing the underlying implementation of RACSignal’s transformation operations.


### Table of Contents

- 1. Higher-order signal operations
- 2. Synchronization operations
- 3. Side-effect operations
- 4. Multithreading operations
- 5. Other operations


### 1. Higher-Order Signal Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_1.png)


Most higher-order operations are designed for higher-order signals. In other words, the values sent by a signal are themselves signals, or even higher-order signals. By analogy with arrays, this is like a multidimensional array: arrays nested inside arrays.


#### 1. flattenMap: (defined in the superclass RACStream)

flattenMap: plays a very important role throughout RAC. Many signal transformations can be implemented with flattenMap:.

The four operations map:, flatten, filter, and sequenceMany: are all implemented using flattenMap:. Meanwhile, many other transformation operations internally use map:, flatten, and filter as well.


Let’s review the implementation of map:
```objectivec

- (instancetype)map:(id (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^(id value) {
        return [class return:block(value)];
    }] setNameWithFormat:@"[%@] -map:", self.name];
}

```
The map: operation is actually just a flattenMap: operation performed directly on the original signal; the value of the transformed new signal is block(value).


The implementation of flatten will be analyzed in detail next; for now, we’ll skip it.

Implementation of filter:
```objectivec

- (instancetype)filter:(BOOL (^)(id value))block {
    NSCParameterAssert(block != nil);
    
    Class class = self.class;
    return [[self flattenMap:^ id (id value) {
        block(value) ? return [class return:value] :  return class.empty;
    }] setNameWithFormat:@"[%@] -filter:", self.name];
}

```
The implementation of filter is somewhat similar to map:: it also performs a flattenMap: operation on the original signal. The difference is that block(value) is not used as the return value, but as the predicate. If the condition in this closure is satisfied, the return value of the transformed new signal is value; otherwise, it returns an empty signal.


Among the higher-order operations analyzed next, the implementations of switchToLatest, try:, and tryMap: will also use flattenMap:.

Source implementation of flattenMap::
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
The implementation of `flattenMap:` calls the `bind` function, transforms the original signal, and returns the new signal from `block(value)`. The specific flow of the `bind` operation has already been analyzed in [this article](https://halfrost.com/reactivecocoa_racsignal/), so it won’t be repeated here.

From the source code of `flattenMap:`, we can see that it can support Promise-like serial asynchronous operations, and `flattenMap:` satisfies the `bind` part of the Monad definition. `flattenMap:` cannot be used to implement operations such as `takeUntil:` and `take:`.

However, the `bind` operation can implement `take:`; `bind` fully satisfies the `bind` part of the Monad definition.

#### 2. flatten (defined in the superclass RACStream)

Source implementation of `flatten`:
```objectivec

- (instancetype)flatten {
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self flattenMap:^(id value) {
        return value;
    }] setNameWithFormat:@"[%@] -flatten", self.name];
}


```
The `flatten` operation must be performed on a higher-order signal. If the value inside the signal is not itself a signal—that is, if it is not a higher-order signal—it will crash. The crash message is as follows:
```objectivec

*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Value returned from -flattenMap: is not a stream

```
So `flatten` is a lowering operation applied to higher-order signals. Each time a higher-order signal sends a signal, after the `flatten` transformation—because of the `flattenMap:` operation—each value of the newly returned signal is the value of each signal in the original signal.

![](https://img.halfrost.com/Blog/ArticleImage/35_2.png)


If you perform a `merge:` operation on signal A, signal B, and signal C, you can achieve the same effect as `flatten`.
```objectivec

    [RACSignal merge:@[signalA,signalB,signalC]];

```
The `merge:` operation was analyzed in the [previous article](https://halfrost.com/reactivecocoa_racsignal_operations2/). Let’s review it again:
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
Now, looking back at this code, although copiedSignals is an NSMutableArray, it effectively approximates the higher-order signal shown in the figure above. Then, whenever any of these signals emits a signal, it is sent to the subscriber. The entire operation is exactly what flatten literally means: flattening.


![](https://img.halfrost.com/Blog/ArticleImage/35_3.png)


Additionally, in ReactiveCocoa v2.5, flatten defaults to the flattenMap: operation.
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
In ReactiveCocoa v3.x, v4.x, and v5.x, the `flatten` operation can choose from three behaviors: `merge`, `concat`, and `switchToLatest`.

#### 3. flatten:

The `flatten:` operation must also be performed on a higher-order signal. If the values inside the signal are not themselves signals—that is, if it is not a higher-order signal—then it will crash.

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
        recur = subscribeToSignal = ^(RACSignal *signal) { // Omitted for now};

        void (^completeIfAllowed)(void) = ^{ // Omitted for now};
        
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
First, let’s explain the roles of a few variables and arrays.

`activeDisposables` holds the `disposables` signals for the subscribers that are currently subscribed.

`queuedSignals` holds signals that are temporarily cached and waiting to be subscribed to.

`selfCompleted` indicates whether the higher-order signal has completed.

The `subscribeToSignal` closure is responsible for subscribing to the given signal. The input parameter of this closure is a signal; inside the closure, it subscribes to that signal and performs some operations.

`recur` is a weak reference to the `subscribeToSignal` closure, preventing a strong-weak reference cycle. We will analyze the `subscribeToSignal` closure below, and then it will become clear why `recur` needs to be marked as `weak`.

`completeIfAllowed` is used to notify subscribers and send them `completed` when all signals have finished sending.

The input parameter `maxConcurrent` means the maximum number of signals that can be subscribed to concurrently.

Now let’s analyze the specific subscription process in detail.

Inside `flatten:`, it subscribes to the signals emitted by the higher-order signal. This part of the code is relatively straightforward:
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
1. If the current maximum number of signals that can be accommodated is > 0, and the `activeDisposables` array is already filled to that maximum, no new signals can be added. In that case, cache the current signal in the `queuedSignals` array.

2. When there is an empty slot in the `activeDisposables` array for adding a new signal, call the `subscribeToSignal( )` closure to start subscribing to the new signal.

3. When everything is complete, set the `selfCompleted` flag to `YES`, and call the `completeIfAllowed( )` closure.
```objectivec

void (^completeIfAllowed)(void) = ^{
    if (selfCompleted && activeDisposables.count == 0) {
        [subscriber sendCompleted];
        subscribeToSignal = nil;
    }
};


```
When `selfCompleted = YES` and all signals in the `activeDisposables` array have finished sending—meaning there are no more signals that can be sent, i.e. `activeDisposables.count = 0`—`sendCompleted` is sent to the subscriber. One thing worth mentioning here is that `subscribeToSignal` also needs to be manually set to `nil`. This is because the `subscribeToSignal` closure strongly references the `completeIfAllowed` closure, preventing `completeIfAllowed` from being deallocated too early. Therefore, after the `completeIfAllowed` closure finishes executing, the `subscribeToSignal` closure needs to be set to `nil` as well.

Next, the key point to examine is the `subscribeToSignal( )` closure.
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
2. Here, `recur` is made `__strong`, because the `subscribeToSignal()` closure will be used in step 6 below. This is also to avoid a retain cycle.
3. Subscribe to the input signal and send the signal to the subscriber. After it finishes sending, remove its corresponding `Disposable` from `activeDisposables`.
4. If the currently cached `queuedSignals` array has no cached signals, call the `completeIfAllowed()` closure.
5. If the currently cached `queuedSignals` array contains cached signals, take out the signal at index 0 and remove it from the `queuedSignals` array.
6. Continue subscribing to the signal retrieved in step 4, and continue calling the `subscribeToSignal()` closure.


To summarize: every time the higher-order signal sends a signal value, it checks whether the number of items in the `activeDisposables` array has already exceeded `maxConcurrent`. If it cannot accommodate more, the signal is cached in the `queuedSignals` array. If it can still accommodate it, the `subscribeToSignal()` closure is called to subscribe to the current signal.

Each time a signal finishes sending, it checks the number of items in the cached array `queuedSignals`. If there are no signals left in the cached array, it completes the sending of the original higher-order signal. If there are still signals in the cached array, it continues subscribing. This repeats until all signals from the original higher-order signal have been sent.


The entire execution flow of `flatten:` has now been analyzed clearly. Finally, let’s take a closer look at the input parameter `maxConcurrent`.

Looking back at the implementation of `flatten:` above, there is this line:
```objectivec

if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) 

```
So the range of values for maxConcurrent ultimately determines how flatten: behaves.

What happens if maxConcurrent < 0? The program crashes, because the source code contains an initialization line like this:
```objectivec

NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];

```
`activeDisposables` initializes an `NSMutableArray` with a size of `maxConcurrent` during initialization. If `maxConcurrent < 0`, initialization will crash here.

If `maxConcurrent = 0`, what happens? In that case, `flatten:` degenerates into `flatten`.

![](https://img.halfrost.com/Blog/ArticleImage/35_4.png)


If `maxConcurrent = 1`, what happens? In that case, `flatten:` degenerates into `concat`.

![](https://img.halfrost.com/Blog/ArticleImage/35_5.png)


If `maxConcurrent > 1`, what happens? Since I haven’t yet encountered a real requirement that uses `maxConcurrent > 1`, I won’t include a diagram here for now. When `maxConcurrent > 1`, the behavior of `flatten` also depends on the relationship between the number of higher-order signals and `maxConcurrent`. If the number of higher-order signals is `<= maxConcurrent`, then `flatten:` degenerates into `flatten` again. If the number of higher-order signals is `> maxConcurrent`, the excess signals enter the `queuedSignals` cache array.


#### 4. concat


The implementation of `concat` here is defined in `RACSignal`.
```objectivec

- (RACSignal *)concat {
    return [[self flatten:1] setNameWithFormat:@"[%@] -concat", self.name];
}

```
A look at the source code makes it clear: `concat` is actually `flatten:1`.


Of course, `RACSignal` defines the `concat:` method. This method was already analyzed in a previous [article](https://halfrost.com/reactivecocoa_racsignal/), so here we’ll review and compare it:
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


By comparison, we can see that although the final transformed results are similar, the target signal objects are different. `concat` performs a dimensionality-reduction operation on higher-order signals. `concat:` is an operation that connects two signals. If, along the time axis of a higher-order signal, you connect each signal from left to right using `concat:`, the result is `concat`.


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
The `switchToLatest` operation can only be used on higher-order signals. If the original signal contains values that are not signals, it will crash with the following error:
```vim

***** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: '-switchToLatest requires that the source signal (<RACDynamicSignal: 0x608000038ec0> name: ) send signals.

```
In the `switchToLatest` operation, the original signal is first converted into a hot signal, and `connection.signal` is of type `RACSubject`. Then a `flattenMap:` transformation is applied to the `RACSubject`. Inside the `flattenMap:` transformation, `connection.signal` first `concat:`s a `never` signal. The reason for `concat:`ing a `never` signal here is to prevent the inner signal from ending too early and causing the subscriber to receive a `complete` signal.

In the `flattenMap:` transformation, `x` is also a signal. Applying `takeUntil:` to `x` has the following effect: before the next signal arrives, `x` keeps sending signals; once the next signal arrives, `x` is unsubscribed from, and subscription to the new signal begins.


![](https://img.halfrost.com/Blog/ArticleImage/35_7.png)


After a higher-order signal is flattened via the `switchToLatest` operation, the signal shown in the diagram above is obtained.


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
There are three assertions in the implementation, all of which are requirements on the input parameters. The input `signal` and the `cases` dictionary must not be `nil`. In addition, every value corresponding to every key in the `cases` dictionary must be of type `RACSignal`. Note that `defaultSignal` is allowed to be `nil`.

The rest of the implementation is relatively straightforward: it performs a `map` transformation on the input `signal`. This transformation is a higher-order transformation.

For each value emitted by `signal`, that value is used as a key to look up the corresponding value in the `cases` dictionary. That value, of course, is a signal. If the signal corresponding to the value is not empty, the value emitted by `signal` is mapped to the corresponding signal in the dictionary. If the corresponding value is empty, the value emitted by the original `signal` is mapped to `defaultSignal`.

If the signal obtained after the transformation is `nil`, an error signal is returned. If the resulting signal is not `nil`, then after the original signal has been fully transformed, it becomes a higher-order signal, whose values are all signals. Finally, `switchToLatest` is applied to this higher-order signal.


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
The three input signals, boolSignal, trueSignal, and falseSignal, must not be nil.

The values contained in boolSignal must all be of type NSNumber.

Perform a map lifting operation on boolSignal. If the value inside the boolSignal signal is YES, convert it to the trueSignal signal; if it is NO, convert it to falseSignal. After the lifting conversion is complete, boolSignal becomes a higher-order signal, and then a switchToLatest operation is performed.


#### 8. catch:

The implementation of catch: is as follows:
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
When subscribing to the original signal, if an error occurs, the `catchBlock( )` closure is executed, with the newly produced `error` passed in as its argument. The `catchBlock( )` closure produces a new `RACSignal`, and the subscriber then subscribes to that signal again.

The reason this is considered a higher-order operation is that after the original signal errors, the error is promoted into a signal.

#### 9. catchTo:

The implementation of `catchTo:` is as follows:
```objectivec

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
}

```
The implementation of catchTo: simply calls the catch: method. The only difference is that the catchBlock( ) closure inside the original catch: method always returns the input argument to catchTo:, the signal.


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
try: can be used to perform a signal promotion operation. It applies a flattenMap transformation to the original signal, invoking the `tryBlock( )` closure once for each value emitted by the signal. If the closure returns YES, it returns `[RACSignal return:value]`; if the closure returns NO, it returns an error. If the original signal contains only values, then after the `try:` operation, each value becomes an RACSignal, so the original signal becomes a higher-order signal.

Of course, if the block implementation returns a signal, then no promotion occurs. The returned signal does not have to emit another signal; it can emit values directly.


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
The implementation of tryMap: is basically the same as that of try:. The only difference is the return value of the input closure. In tryMap:, the mapBlock( ) closure is invoked and returns an object. If that object is not nil, [RACSignal return:mappedValue] is returned. If the returned object is nil, it is transformed into an error signal.

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
timeout:onScheduler: is implemented very simply. Compared with a normal signal subscription, it adds a `timeoutDisposable` operation. Inside the signal subscription, it starts a scheduler. After `interval` has elapsed, it stops subscribing to the original signal and sends `sendError` to the subscriber.

The semantics of this operation are exactly the same as its method name: after `interval` has elapsed, it is considered a timeout, so the subscription to the original signal is stopped and `sendError` is sent.


To summarize the lifting / lowering operations for higher-order signals in ReactiveCocoa v2.5:


![](https://img.halfrost.com/Blog/ArticleImage/35_8.png)


**Lifting operations**:

1. map( maps a value into a signal)
2. [RACSignal return:signal]


![](https://img.halfrost.com/Blog/ArticleImage/35_9.png)

**Lowering operations**:

1. flatten(equivalent to flatten:0, +merge:)
2. concat(equivalent to flatten:1)
3. flatten:1
4. switchToLatest
5. flattenMap:

These 5 operations can turn a higher-order signal into a lower-order signal, but after lowering, there are ultimately only 3 possible behaviors: switchToLatest, flatten, and concat. See the analysis above for the specific diagrams.


### II. Synchronous Operations

ReactiveCocoa also includes some synchronous operations. We generally use these operations rarely. Unless you are truly certain that doing so will not cause any issues, using them carelessly may lead to serious problems such as thread deadlocks.

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
From the source code, synchronous methods like `firstOrDefault: success: error:` can easily lead to thread deadlocks. Inside the closures for `subscribeNext`, `error`, and `completed`, it calls `lock` on the `condition` lock and then `unlock`. If a signal sends a value but none of the three operations—`subscribeNext`, `error`, or `completed`—is executed, then `[condition wait]` will be executed and the thread will wait.

Because `take:1` is applied to the original signal, only the first value is processed. After any one of the three operations—`subscribeNext`, `error`, or `completed`—has executed, the lock is acquired again, and the input parameters `success` and `error` passed in from outside are assigned values, so the caller can obtain the internal state. The final returned value is the value from the first `next` in the original signal. If the original signal has no first value—for example, it directly sends `error` or `completed`—then `defaultValue` is returned.

When `done` is `YES`, it means that one of the three operations—`subscribeNext`, `error`, or `completed`—has been successfully executed. Otherwise, it is `NO`.

When `localSuccess` is `YES`, it means a value was successfully sent, or all values from the original signal were successfully sent, with no error occurring during the process.

The `broadcast` operation on `condition` wakes up other threads, equivalent to the `signal` operation of a mutex semaphore in an operating system.

The input parameter `defaultValue` provides an initial value for the internal variable `value`. After the original signal sends a value, the value of `value` always stays consistent with the value from the original signal.

`success` and `error` are addresses of external variables, allowing the external caller to observe the internal state. They are assigned inside the function, and their values are obtained outside the function.


#### 2. firstOrDefault:
```objectivec

- (id)firstOrDefault:(id)defaultValue {
    return [self firstOrDefault:defaultValue success:NULL error:NULL];
}


```
firstOrDefault: is implemented by calling the firstOrDefault: success: error: method. It just does not need success and error to be passed in, and does not care about the internal state. The final returned value is the value from the first next in the original signal. If the original signal has no first value—for example, it errors or completes directly—then defaultValue is returned.


#### 3. first
```objectivec

- (id)first {
	return [self firstOrDefault:nil];
}

```
The first method is even more concise; it doesn’t even pass defaultValue. The final return value is the value from the first next in the original signal. If the original signal has no first value—for example, it errors or completes immediately—then nil is returned.

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
`waitUntilCompleted:` still calls the `firstOrDefault: success: error:` method internally. The return value is `success`. As long as the original signal finishes sending normally, `success` should be `YES`; however, if an `error` occurs during sending, `success` will be `NO`. Since `success` is used as the return value, external callers can observe whether the sending succeeded.

Although this method can observe the state when sending completes, you should still avoid using it as much as possible. Its implementation calls the `firstOrDefault: success: error:` method, which performs a large number of lock operations; if you are not careful, it can lead to deadlocks.

#### 5. toArray
```objectivec

- (NSArray *)toArray {
	return [[[self collect] first] copy];
}


```
After `collect`, all values from the original signal are added into an array. Retrieving the first value of the signal yields an array. Therefore, after executing `first`, the first value is the array containing all values from the original signal.


### III. Side-effect Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_10.png)


ReactiveCocoa v2.5 also provides several functions for performing side-effect operations.

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
doNext: Allows us to execute a block closure before the original signal’s sendNext; within this closure, we can perform any side-effect operations we want.


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
doError: allows us to execute a block closure before the original signal’s sendError. Within this closure, we can perform any side-effect operations we want.

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
doCompleted: Allows us to execute a block closure before the original signal `sendCompleted`; inside this closure, we can perform any side-effect operations we want.


**The three operations `doNext:`, `doError:`, and `doCompleted:` are quite useful. Any operations that produce side effects should preferably be declared here, so that anyone reading the code can immediately and clearly see that they are side-effect operations.**


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
initially: Allows us to call the `defer` operation before the original signal is sent. Before returning `self`, a closure is executed, and within that closure we can perform the side-effect operations we want to execute.

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
finally: calls the doError: and doCompleted: operations, inserting a block( ) closure before sendError and before sendCompleted, respectively. This allows a side-effect operation we want to run when the signal is about to terminate due to an error and cancel the subscription, or before it finishes sending.


### IV. Multithreading Operations

RACSignal has three operations related to multithreading.

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
The input parameter of `deliverOn:` is a scheduler. When the original signal calls `subscribeNext`, `sendError`, or `sendCompleted`, it invokes the scheduler’s `schedule` method.
```objectivec


- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];

	block();
	return nil;
}

```
In the `schedule` method, it checks whether the current `currentScheduler` is `nil`. If it is `nil`, it calls `backgroundScheduler` to execute the `block( )` closure; otherwise, the current `currentScheduler` executes the `block( )` closure directly.
```objectivec


+ (instancetype)currentScheduler {
	RACScheduler *scheduler = NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey];
	if (scheduler != nil) return scheduler;
	if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

	return nil;
}

```
To determine whether currentScheduler exists, check two conditions. First, check whether the current thread’s dictionary contains RACSchedulerCurrentSchedulerKey( @"RACSchedulerCurrentSchedulerKey" ). If a corresponding value exists, return scheduler. Second, check whether the current class is on the main thread; if it is, return mainThreadScheduler. If neither condition is met, then currentScheduler does not exist, and nil is returned.


A characteristic of the deliverOn: operation is that the thread on which the original signal sends sendNext, sendError, and sendCompleted is deterministic.


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
`subscribeOn:` subscribes to the original signal inside the closure of the passed-in `scheduler`. It differs from `deliverOn:`:

`subscribeOn:` can guarantee that the `didSubscribe block( )` closure is executed on the input `scheduler`, but it cannot guarantee on which `scheduler` the original signal’s `subscribeNext`, `sendError`, and `sendCompleted` are executed.

`deliverOn:` is exactly the opposite of `subscribeOn:`. It can guarantee on which `scheduler` the original signal’s `subscribeNext`, `sendError`, and `sendCompleted` are executed, but it cannot guarantee on which `scheduler` the `didSubscribe block( )` closure is executed.

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
Comparing it with the source implementation of `deliverOn:`, the two are fairly similar. The only difference is that `deliverOnMainThread` wraps `sendNext`, `sendError`, and `sendCompleted` in a `performOnMainThread` closure for execution.
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
Inside the `performOnMainThread` closure, it guarantees that the input `block()` closure is executed on the main thread.

`OSAtomicIncrement32` and `OSAtomicDecrement32` are atomic operations, representing `+1` and `-1` respectively. In the following `if-else` checks, regardless of which condition is satisfied, the `block()` closure is ultimately executed on the main thread.

`deliverOnMainThread` can guarantee that the original signal’s `subscribeNext`, `sendError`, and `sendCompleted` are all executed on the main thread, `MainThread`.

### V. Other Operations


![](https://img.halfrost.com/Blog/ArticleImage/35_12.png)


#### 1. setKeyPath: onObject: nilValue:

The source implementation of `setKeyPath: onObject: nilValue:` is as follows:
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
Although the code is a bit long, it is not hard to follow line by line. There are four points that need attention, and they have already been marked in the code above. Next, let’s analyze them one by one.

##### 1. The objc\_precise\_lifetime issue.

The author wrote a comment here:

 > Possibly spec, possibly compiler bug, but this \_\_bridge cast does not result in a retain here, effectively an invisible \_\_unsafe\_unretained qualifier. Using objc\_precise\_lifetime gives the \_\_strong reference desired. The explicit use of \_\_strong is strictly defensive.

The author suspects this is a compiler bug: even if \_\_strong is explicitly used, there is still no guarantee that the object is strongly referenced, so objc\_precise\_lifetime is also needed to ensure a strong reference.

Regarding this issue, I looked up the LLVM documentation, where it is mentioned in the section [6.3 precise lifetime semantics](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id42).

In general, variables declared as \_\_strong have a well-defined lifetime. ARC keeps these \_\_strong variables retained throughout their lifetime.

However, automatic local variables do not have a precise lifetime. These variables merely hold a strong reference, strongly referencing a pointer-typed value to a retained object. These values are entirely subject to how the local optimizer chooses to optimize them. Therefore, it is impossible to change the lifetime of such local variables. Since there are so many optimizations, in theory they can all reduce the lifetime of local variables, but these optimizations are very useful.

However, LLVM provides us with the objc\_precise\_lifetime keyword, which can make the lifetime of a local variable precise. This keyword can be quite useful in some cases. In even more extreme cases, even if the local variable is not used at all, it can still maintain a deterministic lifetime.

Returning to the source code, the code then calls setValue: forKeyPath: on the input parameter object.
```objectivec

[object setValue:x ?: nilValue forKeyPath:keyPath];

```
If `x` is `nil`, return the value passed in via `nilValue`.


##### 2.  AssociatedObject Associated Objects

If the `bindings` dictionary does not exist, call objc\_setAssociatedObject to associate an object with `object`. The option is OBJC\_ASSOCIATION\_RETAIN\_NONATOMIC. If the `bindings` dictionary exists, use objc\_getAssociatedObject to retrieve the dictionary.

Update the bound key-value pair in the dictionary again: the key is the input parameter `keyPath`, and the value is the original signal.


##### 3.  When unsubscribing from the original signal
```objectivec

[bindings removeObjectForKey:keyPath];

```
When a signal is unsubscribed from, remove all associated values.

##### 3.  OSAtomicCompareAndSwapPtrBarrier

This function is part of the OSAtomic atomic operations API. Its prototype is as follows:
```objectivec

OSAtomicCompareAndSwapPtrBarrier(type __oldValue, type __newValue, volatile type *__theValue)

```
>Compares a variable against the specified old value. If the two values are equal, this function assigns the specified new value to the variable; otherwise, it does nothing. The comparison and assignment are done as one atomic operation and the function returns a Boolean value indicating whether the swap actually occurred.

This function compares whether \_\_oldValue matches the value at the memory location pointed to by \_\_theValue. If it matches, it stores the value of \_\_newValue into the memory location pointed to by \_\_theValue. The function returns a BOOL value indicating whether the swap succeeded.
```objectivec
	while (YES) {
	void *ptr = objectPtr;
	if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr))   {
		  break;
	}
  }

```
In this infinite while loop, the entire loop can exit only when OSAtomicCompareAndSwapPtrBarrier returns YES. A return value of YES means that &objectPtr has been set to NULL, which ensures thread safety and eliminates the possibility of a dangling pointer.


#### 2. setKeyPath: onObject:
```objectivec

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
    return [self setKeyPath:keyPath onObject:object nilValue:nil];
}

```
setKeyPath: onObject: simply calls setKeyPath: onObject: nilValue:, except that nilValue is passed as nil.


### Finally

The low-level implementation analysis of all RACSignal operations is now complete. Feedback and suggestions are welcome.