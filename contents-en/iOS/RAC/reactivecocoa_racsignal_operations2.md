# Analysis of the Underlying Implementation of All RACSignal Transformation Operations in ReactiveCocoa (Part 2)

![](https://img.halfrost.com/Blog/ArticleTitleImage/33_0_.png)


### Preface


Continuing from the source-code implementation analysis in the [previous article](https://halfrost.com/reactivecocoa_racsignal_operations1/), this article continues analyzing the underlying implementation of RACSignal transformation operations.


### Table of Contents

- 1.Filtering Operations
- 2.Combination Operations


### 1. Filtering Operations

![](https://img.halfrost.com/Blog/ArticleImage/33_1.png)


Filtering operations are also a kind of transformation. Based on filtering conditions, they filter out values that satisfy the criteria. The new signal produced by the transformation is a subset of the original signal.

#### 1. filter: (defined in the parent class RACStream)

This filter: operation has already been used in the implementation of any:.
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


A closure is passed into `filter:` as the filtering predicate. If the predicate is satisfied, the original signal’s value is returned; otherwise, the original signal’s value is “swallowed” and an empty signal is returned. This transformation is primarily implemented using flattenMap.


#### 2. ignoreValues
```objectivec

- (RACSignal *)ignoreValues {
    return [[self filter:^(id _) {
        return NO;
    }] setNameWithFormat:@"[%@] -ignoreValues", self.name];
}


```
![](https://img.halfrost.com/Blog/ArticleImage/33_3.png)


From the `filter` implementation above, the predicate condition passed in here is always `NO`, so all values from the original signal will be transformed into an empty signal. Therefore, the transformed signal is an empty signal.


#### 3. ignore: (defined in the superclass RACStream)
```objectivec

- (instancetype)ignore:(id)value {
    return [[self filter:^ BOOL (id innerValue) {
        return innerValue != value && ![innerValue isEqual:value];
    }] setNameWithFormat:@"[%@] -ignore: %@", self.name, [value rac_description]];
}

```
![](https://img.halfrost.com/Blog/ArticleImage/33_4.png)


The implementation of `ignore:` is still based on `filter:`. The filtering condition passed in is a value; when the original signal sends that value, it is replaced with an empty signal.

#### 4. distinctUntilChanged (defined in the parent class `RACStream`)
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


distinctUntilChanged is implemented using bind. During each transformation, it records the value previously sent by the original signal and compares it with the current one. If the value is the same, it “swallows” it and returns an empty signal. Only when the value differs from the one previously sent by the original signal does the transformed new signal send this value.


For distinctUntilChanged, the focus is on whether the values between each pair of consecutive signals are different. Sometimes we may need a signal set similar to NSSet, in which case distinctUntilChanged is not sufficient. ReactiveCocoa 2.5 does not provide a distinct transformation function either.


![](https://img.halfrost.com/Blog/ArticleImage/33_6.png)


We can implement a similar transformation ourselves. The idea is straightforward: store every previously sent signal value in an array. For each new signal value, search the array. If it is not found, send the value; if it is found, return an empty signal. The result is shown in the figure above.


#### 5. take: (defined in the parent class RACStream)
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


take: is also very simple to implement; it is implemented with the help of the bind function. The count parameter is the number of values to take from the original signal. In the bind closure, the taken counter starts at 0 and takes values from the original signal; once taken has reached count, it stops taking values.


On top of take:, we can further adapt it into new transformation methods. For example, suppose we want to take the nth value executed by the original signal, similar to an elementAt operation. This operation is also not provided directly in ReactiveCocoa 2.5.


![](https://img.halfrost.com/Blog/ArticleImage/33_8.png)


The implementation is actually very simple: you only need to check whether taken is equal to the position we want to take. When it is equal, send out the value from the original signal and set *stop = YES.
```objectivec

// Method I added myself
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


The implementation of `takeLast:` also follows the usual pattern. First, it creates a new signal, and when returning, subscribes to the original signal. Inside the function, it uses `valuesTaken` to store the values sent by the original signal. It stores as many values as the original signal sends, until the number exceeds the `count` passed in; then it drops the element at index 0 of the array. This ensures that the array always contains the last `count` values from the original signal.

When the original signal sends the `completed` signal, all values stored in the array are sent out via `sendNext`. One thing to note here is also the timing at which this transformation sends signals. If the original signal never completes, then `takeLast:` will never be able to emit any signal.

#### 7. takeUntilBlock: (defined in the superclass `RACStream`)
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
takeUntilBlock: uses the passed-in predicate closure as the filtering condition. Once the predicate() closure’s condition is satisfied, the new signal stops sending new values because it has been set to nil. This matches the meaning of the function name: take values from the original signal until the closure’s condition is satisfied.

#### 8. takeWhileBlock: (defined in the parent class RACStream)
```objectivec

- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    return [[self takeUntilBlock:^ BOOL (id x) {
        return !predicate(x);
    }] setNameWithFormat:@"[%@] -takeWhileBlock:", self.name];
}

```
The signal set of takeWhileBlock: is the complement of the signal set of takeUntilBlock:. The universal set is the original signal. Under the hood, takeWhileBlock: still calls takeUntilBlock:; the only difference is that the condition checks for the set that does not satisfy the predicate( ) closure.

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


The implementation of takeUntil: is also a “classic pattern”: return a new signal, and subscribe to the original signal within the new signal. The input parameter is a signal, signalTrigger, which acts as a Trigger. Once signalTrigger sends its first signal, it triggers the triggerCompletion( ) closure; inside that closure, the triggerCompletion( ) closure is called.
```objectivec

  void (^triggerCompletion)(void) = ^{
   [disposable dispose];
   [subscriber sendCompleted];
  };

```
Once the `triggerCompletion( )` closure is called, it unsubscribes from the original signal and sends `sendCompleted` to the subscribers of the transformed new signal.

If the input parameter `signalTrigger` never sends `sendNext`, the original signal will keep sending `sendNext:`.


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


1. The original signal is `concat:`-ed with a `[RACSignal never]` signal, so the original signal will never be disposed and will keep waiting for the replacement signal to arrive.
2. Whether `selfDisposable` is disposed is controlled by the `replacement` signal passed in as a parameter. Once the `replacement` signal sends `sendNext`, the original signal unsubscribes, and everything that follows is handed over to the `replacement` signal.
3. For the transformed new signal, all `sendNext`, `sendError`, and `sendCompleted` events are sent by the `replacement` signal. Ultimately, the point at which the new signal completes is also the point at which the `replacement` signal completes.


#### 11. skip: (defined in the superclass RACStream)
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


The skip: signal set and the take: signal set are complements of each other; the universal set is the original signal. take: takes the first count signals from the original signal, while skip: starts taking signals from position count + 1 of the original signal.

skipped is a cursor. Each time the original signal sends a value, it compares skipped with the input parameter skipCount. If it is not greater than skipCount, that means more values still need to be skipped, so an empty signal is returned; otherwise, the value from the original signal is sent onward.


By analogy with the take family of methods, we can see that ReactiveCocoa 2.5 also does not provide us with a skipLast: transformation function. This transformation is not difficult to implement; we can implement it by analogy with takeLast:.


The implementation idea is also straightforward: store each value sent by the original signal in an array. skipLast: is intended to remove the last count signals from the original signal.

Let’s analyze this first: suppose the original signal has n signals, from 0 to (n-1). After removing the last count signals, n - count signals remain at the front. Therefore, starting to send when the signal at position count + 1 of the original signal arrives, and continuing until the original signal ends, will result in exactly n - count signals being sent.

Once this is clear, the code is easy:
```objectivec

// Method I added myself
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


Each time the original signal sends a value, it is stored in an array. When the number of elements in the array is greater than `count`, it means we need to send a value. At that point, we simply send the element at index 0 of the array each time. The array maintains a FIFO queue. This achieves the effect of `skipLast:`.

#### 12. skipUntilBlock: (defined in the superclass `RACStream`)
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
skipUntilBlock: can be implemented by analogy with the implementation of takeUntilBlock:.

skipUntilBlock: uses the passed-in predicate closure as its filtering condition. Once the predicate() closure satisfies the condition, skipping = NO. When skipping is NO, every value sent by the original signal afterward is forwarded unchanged. When the predicate() closure does not satisfy the condition, it keeps skipping values from the original signal. This matches the meaning of the function name: skip values from the original signal until the closure satisfies the condition, and then stop skipping.


#### 13. skipWhileBlock: (defined in the parent class RACStream)
```objectivec

- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate {
    NSCParameterAssert(predicate != nil);
    
    return [[self skipUntilBlock:^ BOOL (id x) {
        return !predicate(x);
    }] setNameWithFormat:@"[%@] -skipWhileBlock:", self.name];
}

```
The signal set of skipWhileBlock: is the complement of the signal set of skipUntilBlock:. The universal set is the original signal. Under the hood, skipWhileBlock: still calls skipUntilBlock:; the only difference is that the condition is the set that does not satisfy the predicate( ) closure.


This concludes the skip family of methods. Compared with the take family of methods, there are two fewer methods. In ReactiveCocoa 2.5, takeUntil: and takeUntilReplacement: do not have corresponding skip methods.
```objectivec

// Method I added myself
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


The implementation of `skipUntil` is also very simple: when the input `signalTrigger` starts sending signals, it lets the original signal send out values via `sendNext`; otherwise, it “swallows” the values from the original signal.

`skipUntilReplacement:` is basically meaningless. After transforming the original signal with `skipUntilReplacement:`, the new signal you get is the `Replacement` signal. So this operation has no real significance.


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
Looking at the implementation of `groupBy:transform:`, it still follows the familiar pattern: return a new `RACSignal`, and subscribe to the original signal inside the new signal.

The key part of `groupBy:transform:` is in `subscribeNext`.

1. First, let’s explain the two input parameters. Both are blocks. The return value of `keyBlock` is used as the dictionary key, while the return value of `transformBlock` is the transformation applied to the value `x` emitted by the original signal.
2. First create an `NSMutableDictionary` dictionary named `groups`, and an `NSMutableArray` array named `orderedGroups`.
3. Retrieve the value corresponding to `key` from the dictionary, where `key` corresponds to the return value of `keyBlock`. The value is a `RACGroupedSignal`. If no corresponding `key` value can be found, create a new `RACGroupedSignal` and store it in the dictionary under the corresponding `key`.
4. After the newly transformed signal is subscribed to, `RACGroupedSignal` performs `sendNext`. This is a signal; if `transformBlock` is not nil, it sends the value transformed by `transformBlock`.
5. `sendError` and `sendCompleted` must each be sent to every `RACGroupedSignal` in the `orderedGroups` array. Since the same operation needs to be executed on every signal in the array, `makeObjectsPerformSelector:withObject:` needs to be called.

After being transformed by `groupBy:transform:`, the original signal is grouped according to `keyBlock`.

Write some test code to see how it should typically be used.
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
Assume the original signal sends `1`, `2`, `3`, `4`, and `5`, representing five grade levels. Grades greater than `3` are considered “good”, and grades less than `3` are considered “bad”.

`signalGroup` is a new signal obtained from the original signal `signalA` via `groupBy:transform:`. This signal is a higher-order signal, because it does not directly contain values; what `signalGroup` contains are still signals. There are two groups inside `signalGroup`: the “good” group and the “bad” group.

To extract the values from these two groups, you need to apply a `filter:` operation. After filtering, you get the higher-order signal for the corresponding group. At this point, you still need to perform a `flatten` operation to turn the higher-order signal into a lower-order signal, and then subscribe again to retrieve its values.

Subscribe to the values of the new signal, and the output is as follows:
```vim

subscribeNext: 40
subscribeNext: 50


```
About the implementation of flatten:
```objectivec

- (instancetype)flatten {
    __weak RACStream *stream __attribute__((unused)) = self;
    return [[self flattenMap:^(id value) {
        return value;
    }] setNameWithFormat:@"[%@] -flatten", self.name];
}

```
The flatten operation simply calls flattenMap: it passes the value in.
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
`flatten` is a common operation for transforming higher-order signals into lower-order signals. The concrete implementation of `flattenMap` was analyzed in the previous article, so it will not be repeated here.


#### 15. groupBy:
```objectivec


- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
    return [[self groupBy:keyBlock transform:nil] setNameWithFormat:@"[%@] -groupBy:", self.name];
}

```
The groupBy: operation is simply a reduced version of groupBy:transform:, with nil passed for transform.

There are many things you can do with groupBy:; it supports very advanced grouping operations. Here is an example:
```objectivec

    // Simple algorithm problem: separate identical elements in an array. If the element count is greater than 2, form a new array, resulting in multiple arrays containing identical elements,
    // e.g. [1,2,3,1,2,3] is separated into [1,1],[2,2],[3,3]
    RACSignal *signal = @[@1, @2, @3, @4,@2,@3,@3,@4,@4,@4].rac_sequence.signal;

      NSArray * array = [[[[signal groupBy:^NSString *(NSNumber *object) {
          return [NSString stringWithFormat:@"%@",object];
      }] map:^id(RACGroupedSignal *value) {
          return [value sequence];
      }] sequence] map:^id(RACSignalSequence * value) {
          return value.array;
      }].array;
    
    for (NSNumber * num in array) {
        NSLog(@"final array%@",num);
    }
    
   // Final output: [1,2,3,4,2,3,3,4,4,4] becomes [1],[2,2],[3,3,3],[4,4,4,4]

```

### II. Composition Operations


![](https://img.halfrost.com/Blog/ArticleImage/33_15.png)


#### 1. startWith: (defined in the parent class RACStream)
```objectivec

- (instancetype)startWith:(id)value {
    
    return [[[self.class return:value]
             concat:self]
            setNameWithFormat:@"[%@] -startWith: %@", self.name, [value rac_description]];
}

```
![](https://img.halfrost.com/Blog/ArticleImage/33_16.png)


The implementation of `startWith:` is very simple: first construct a signal that sends only one value, and after that signal finishes sending, concatenate it with the original signal. The resulting new signal is the original signal with a new value prepended.


#### 2. concat: (defined in the superclass RACStream)

The `concat:` discussed here is defined in the superclass `RACStream`.
```objectivec

- (instancetype)concat:(RACStream *)stream {
    return nil;
}

```
The method defined in the parent class simply returns `nil`; the concrete implementation must be overridden by subclasses.

#### 3. concat: (defined in the parent class RACStream)
```objectivec

+ (instancetype)concat:(id<NSFastEnumeration>)streams {
    RACStream *result = self.empty;
    for (RACStream *stream in streams) {
        result = [result concat:stream];
    }
    
    return [result setNameWithFormat:@"+concat: %@", streams];
}


```
This `concat:` is followed by an array, which contains many signals. `concat:` concatenates these signals together in order.


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


`merge:` is followed by an array. First, a new array `copiedSignals` is created, and all the input signals are placed into it. Then the signals in the array are sent one by one. Because the new signal is also a higher-order signal, and `sendNext` sends each signal in sequence, a `flatten` operation is needed to convert this signal into values before sending them out.

From the diagram above, the upper and lower signals look as if they have been flattened into the emission order of the new signal.


#### 5. merge:
```objectivec


- (RACSignal *)merge:(RACSignal *)signal {
    return [[RACSignal
             merge:@[ self, signal ]]
            setNameWithFormat:@"[%@] -merge: %@", self.name, signal];
}

```
merge: can also take a signal as its parameter, in which case merge: merges the two signals. The concrete implementation follows the same principle as merging multiple signals with merge:.


#### 6. zip: (defined in the superclass RACStream)
```objectivec


+ (instancetype)zip:(id<NSFastEnumeration>)streams {
    return [[self join:streams block:^(RACStream *left, RACStream *right) {
        return [left zipWith:right];
    }] setNameWithFormat:@"+zip: %@", streams];
}


```
zip: can take an array containing various signal streams.

It is implemented by calling join: block:.
```objectivec

+ (instancetype)join:(id<NSFastEnumeration>)streams block:(RACStream * (^)(id, id))block {
    RACStream *current = nil;
    // Step 1
    for (RACStream *stream in streams) {

        if (current == nil) {
            current = [stream map:^(id x) {
                return RACTuplePack(x);
            }];
            
            continue;
        }
        
        current = block(current, stream);
    }
    // Step 2
    if (current == nil) return [self empty];
    
    return [current map:^(RACTuple *xs) {

        NSMutableArray *values = [[NSMutableArray alloc] init];
        // Step 3
        while (xs != nil) {
            [values insertObject:xs.last ?: RACTupleNil.tupleNil atIndex:0];
            xs = (xs.count > 1 ? xs.first : nil);
        }
        // Step 4
        return [RACTuple tupleWithObjectsFromArray:values];
    }];
}

```
The implementation of `join:block:` can be broken down into four steps:

1. Package each signal stream in sequence, wrapping every signal stream into an `RACTuple`. First, the first signal stream is wrapped into a tuple containing only that one signal. Then the first tuple and the second signal are passed through the operation in the `block( )` closure. The incoming `block( )` closure performs the `zipWith:` operation, which “zips” two signals together. For a detailed analysis of the implementation, see the discussion in [the first article](https://halfrost.com/reactivecocoa_racsignal/), so it will not be repeated here. This produces the second tuple, which contains the first tuple and the second signal. Each subsequent loop performs a similar operation: zip the second tuple with the third signal using `zipWith:`, and so on, until all signal streams have been iterated over.

2. After the loop in the first step, if the result is still `nil`, it must be an empty signal, so return the `empty` signal.

3. This step restores the result packaged in the first step back into the original signals. After the loop in the first step, `current` will look something like `(((1), 2), 3)`. The purpose of the third step is to unpack this nested tuple structure and place each signal stream into an array in order. Observe the structure of `current`: the outermost tuple consists of a value and another tuple. So starting from the outermost tuple, peel it layer by layer. In each iteration, the `while` loop takes the `last` element of the outermost tuple, namely the standalone value, and inserts it at index `0` of the array; then it takes `first`, which is the next inner tuple. The loop continues in this way. Because each value is inserted at index `0`, similar to head insertion in a linked list, the final order in the array is guaranteed to match the original signal order.

4. The fourth step wraps the array, now restored to the original signal order, into a tuple and returns it to the closure used by the `map` operation.
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
During the conversion process, the input parameter convertNullsToNils indicates whether NSNull values in the array should be converted to RACTupleNil.

Here, NO is passed for the conversion, so it simply makes an exact copy of the array.

Test code:
```objectivec

    RACSignal *signalD = [RACSignal interval:3 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalO = [RACSignal interval:1 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalE = [RACSignal interval:4 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:0];
    RACSignal *signalB = [RACStream zip:@[signalD,signalO,signalE]];
    
    [signalB subscribeNext:^(id x) {
        NSLog(@"Last received value = %@",x);
    }];


```
Output:
```vim

2016-11-29 13:07:57.349 last received value = <RACTuple: 0x608000011440> (
    "2016-11-29 05:07:56 +0000",
    "2016-11-29 05:07:54 +0000",
    "2016-11-29 05:07:57 +0000"
)

2016-11-29 13:08:01.350 last received value = <RACTuple: 0x608000010c60> (
    "2016-11-29 05:07:59 +0000",
    "2016-11-29 05:07:55 +0000",
    "2016-11-29 05:08:01 +0000"
)

2016-11-29 13:08:05.352 last received value = <RACTuple: 0x60000001a350> (
    "2016-11-29 05:08:02 +0000",
    "2016-11-29 05:07:56 +0000",
    "2016-11-29 05:08:05 +0000"
)

```
The final output signal is governed by the one with the longest duration. The last received signal is a tuple that contains, in order, the value of each signal in the `zip:` array during one “zip” cycle.


#### 7. zip: reduce: (defined in the parent class RACStream)
```objectivec

+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    RACStream *result = [self zip:streams];
    if (reduceBlock != nil) result = [result reduceEach:reduceBlock];
    return [result setNameWithFormat:@"+zip: %@ reduce:", streams];
}

```
`zip: reduce:` is a composition method. Its implementation can be split into two parts. The first part executes `zip:` first, combining each signal stream in the array in sequence. The implementation of this process was analyzed in the previous transform implementation. After `zip:` completes, `reduceEach:` is performed immediately.

There is a check here to determine whether `reduceBlock` is `nil`. This check exists for legacy compatibility with older versions. In versions prior to ReactiveCocoa 2.5, passing `nil` to `reduceBlock` was allowed. To prevent crashes, this check for whether `reduceBlock` is `nil` was added.
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
The reduceEach: operation was already analyzed in the [previous article](https://halfrost.com/reactivecocoa_racsignal_operations1/). It dynamically constructs a closure and, for each tuple from the original signal, executes the logic inside the reduceBlock( ) closure. See the previous article for the detailed analysis. A typical usage is as follows:
```objectivec

   [RACStream zip:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
       return [NSString stringWithFormat:@"%@: %@", string, number];
   }];

```

#### 8. zipWith: (defined in the parent class RACStream)
```objectivec

- (instancetype)zipWith:(RACStream *)stream {
    return nil;
}

```
This method is defined in the parent class `RACStream`; the concrete behavior depends on the implementations in each `RACStream` subclass.

It is comparable to the implementation of `concat:` in the parent class, which also simply returns `nil`.
```objectivec

- (instancetype)concat:(RACStream *)stream { return nil;}

```
In [Part 1](https://halfrost.com/reactivecocoa_racsignal/), we analyzed the concrete implementations of concat: and zipWith: in RACSignal subclasses. If you’ve forgotten the implementation details, you can go back and take a look.

#### 9. combineLatestWith:
```objectivec

- (RACSignal *)combineLatestWith:(RACSignal *)signal {
    NSCParameterAssert(signal != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
        
        // Initialize some flag variables for the first signal
        __block id lastSelfValue = nil;
        __block BOOL selfCompleted = NO;
        
        // Initialize some flag variables for the second signal
        __block id lastOtherValue = nil;
        __block BOOL otherCompleted = NO;

        // This is a closure that determines whether to sendNext
        void (^sendNext)(void) = ^{ };
        
        // Subscribe to the first signal
        RACDisposable *selfDisposable = [self subscribeNext:^(id x) { }];
        [disposable addDisposable:selfDisposable];
        
        // Subscribe to the second signal
        RACDisposable *otherDisposable = [signal subscribeNext:^(id x) { }];
        [disposable addDisposable:otherDisposable];
        
        return disposable;
    }] setNameWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
}

```
The overall implementation approach is fairly simple: in the new signal, subscribe to the original signal and the input `signal` respectively.
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
First, let's look at the concrete implementation of the original signal subscription:

In the `subscribeNext` closure, the latest `x` value sent by the original signal is recorded and stored in `lastSelfValue`. From then on, the `lastSelfValue` variable always holds the most recent value sent by the original signal. Then the `sendNext( )` closure is called.

In the `completed` closure, `selfCompleted` records that the original signal has completed sending. It also needs to check whether `otherCompleted` has completed—that is, whether the input signal `signal` has completed sending. Only when both have completed sending can the newly combined signal be considered fully completed.
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
This is the implementation for handling the input `signal`. It is fully consistent with how the original signal is handled. The key now is to look at what the `sendNext()` closure does.
```objectivec

void (^sendNext)(void) = ^{
    @synchronized (disposable) {
        if (lastSelfValue == nil || lastOtherValue == nil) return;
        [subscriber sendNext:RACTuplePack(lastSelfValue, lastOtherValue)];
    }
};

```
Inside the `sendNext( )` closure, if either `lastSelfValue` or `lastOtherValue` is `nil`, it returns, because the two cannot be combined at that point. When both signals have values, the latest values of the two signals are packaged into a tuple and sent out.


![](https://img.halfrost.com/Blog/ArticleImage/33_18.png)


As you can see, whenever either signal sends a new value, it looks for the latest value from the other signal and combines with it.


Here we can compare it with the similar `zip:` operation:


![](https://img.halfrost.com/Blog/ArticleImage/33_19.png)


The `zip:` operation stores the value from the newly arrived signal in an array. Then, when the other signal sends a value, it combines that value with the value at index 0 of the array into a new tuple signal, sends it out, and removes the two values at index 0 from their respective arrays. `zip:` can guarantee that each combined value is unique, and that a value from an original signal will not be combined multiple times into new tuple signals. However, `combineLatestWith:` cannot guarantee this. Before either the original signal or the other signal sends a new signal value, every emitted signal will be combined with the current latest signal, so repeated combinations can occur here.

#### 10. combineLatest:
```objectivec

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
    return [[self join:signals block:^(RACSignal *left, RACSignal *right) {
        return [left combineLatestWith:right];
    }] setNameWithFormat:@"+combineLatest: %@", signals];
}

```
combineLatest: is implemented by calling the join: block: method once for each signal in the input array. The closure passed in combines the two signals using combineLatestWith:. The implementation of combineLatest: is simply a composition of these two operations. The concrete implementation has already been analyzed above, so I won’t repeat it here.


#### 11. combineLatest: reduce:
```objectivec

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock {
    NSCParameterAssert(reduceBlock != nil);
    RACSignal *result = [self combineLatest:signals];
    if (reduceBlock != nil) result = [result reduceEach:reduceBlock]; 
    return [result setNameWithFormat:@"+combineLatest: %@ reduce:", signals];
}


```
The implementation of `combineLatest: reduce:` can be compared to the implementation of `zip: reduce:`.

The concrete implementation can be split into two parts. The first part is to execute `combineLatest:` first, combining each signal stream in the array in sequence. The implementation of this process was analyzed in the previous transformation implementation. After `combineLatest:` completes, `reduceEach:` is performed immediately afterward.

There is a check here to determine whether `reduceBlock` is `nil`. This check exists for legacy reasons from older versions. In versions prior to ReactiveCocoa 2.5, passing `nil` for `reduceBlock` was allowed. To prevent crashes, this check for whether `reduceBlock` is `nil` was added.


#### 12. combinePreviousWithStart: reduce:(defined in the parent class RACStream)

The implementation of this method is also a composition of multiple transformation operations.
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
The implementation of combinePreviousWithStart: reduce: can be directly analogous to that of scanWithStart:reduce:. Here’s an example to illustrate the difference between the two.
```objectivec

      RACSequence *numbers = @[ @1, @2, @3, @4 ].rac_sequence;

      RACSignal *signalA = [numbers combinePreviousWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
          return @(previous.integerValue + next.integerValue);
      }].signal;

    RACSignal *signalB = [numbers scanWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
        return @(previous.integerValue + next.integerValue);
    }].signal;

```
signalA outputs the following:
```vim

1
3
5
7

```
The output of signalB is as follows:
```vim

1
3
6
10

```
By now, the difference should be obvious. `combinePreviousWithStart: reduce:` computes pairwise sums with the previous value, while `scanWithStart:reduce:` computes a cumulative sum.

Why does this happen? Let’s look specifically at the implementation of `combinePreviousWithStart: reduce:`.

Although `combinePreviousWithStart: reduce:` also calls `scanWithStart:reduce:`, its initial value is the `RACTuplePack(start)` tuple, and the aggregation process performed by `reduce` is also different:
```objectivec

id value = reduceBlock(previousTuple[0], next); 
return RACTuplePack(next, value);

```
The `reduceBlock( )` closure is invoked sequentially with `previousTuple[0]` and `next` as arguments. Here, the `reduceBlock( )` closure performs an accumulation operation, so it adds the value at index 0 of the previous tuple to the value of the newly arriving signal. The resulting value is then combined into a new tuple, which consists of `next` and `value`.

If we print the value of each signal during the accumulation process of `combinePreviousWithStart: reduce:` in the example above, it looks like this:
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
Because after splitting it into a tuple this way, the next time an operation is performed, you can still get the value of the previous signal, so it won’t produce an accumulating effect.


#### 13. sample:
```objectivec

- (RACSignal *)sample:(RACSignal *)sampler {
    NSCParameterAssert(sampler != nil);
    
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        NSLock *lock = [[NSLock alloc] init];
        __block id lastValue;
        __block BOOL hasValue = NO;
        
        RACSerialDisposable *samplerDisposable = [[RACSerialDisposable alloc] init];
        RACDisposable *sourceDisposable = [self subscribeNext:^(id x) { // temporarily omitted }];
        
        samplerDisposable.disposable = [sampler subscribeNext:^(id _) { // temporarily omitted }];
        
        return [RACDisposable disposableWithBlock:^{
            [samplerDisposable dispose];
            [sourceDisposable dispose];
        }];
    }] setNameWithFormat:@"[%@] -sample: %@", self.name, sampler];
}

```
sample: The internal implementation also subscribes separately to the original signal and the input signal sampler. The concrete implementation is essentially what happens inside these two signal subscriptions.
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
This is an operation on the original signal. In `subscribeNext`, the operation on the original signal records the values of two variables: `hasValue` records whether the original signal has a value, and `lastValue` records the latest value of the original signal. An `NSLock` is added here for protection.

When an error occurs, it first unsubscribes from the `sampler` signal and then calls `sendError:`. When the original signal completes, it likewise first unsubscribes from the `sampler` signal and then calls `sendCompleted`.
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
This is an operation on the input signal `sampler`. The default value of `shouldSend` is `NO`; this variable controls whether to `sendNext:` a value. Only when the original signal has a value does `hasValue = YES`, so `shouldSend = YES`; only then can the value of the original signal be sent. Here we do not care about the value of the input signal `sampler`, as can be seen from `subscribeNext:^(id \_)`: `\_` indicates that its value is not needed.

When an error occurs, the original signal is unsubscribed from first, and then `sendError:` is called. When the `sampler` signal completes, the original signal is likewise unsubscribed from first, and then `sendCompleted` is called.

![](https://img.halfrost.com/Blog/ArticleImage/33_20_.png)

After the `sample:` transformation, it becomes like this. It simply moves all the values of the original signal to the moments when the `sampler` signal sends signals; the values are still the same as those of the original signal.

### Finally

For transformation operations on `RACSignal`, cold/hot signal conversion operations and higher-order signal operations still remain. We will continue the analysis in the next article. As always, feedback and corrections are welcome.