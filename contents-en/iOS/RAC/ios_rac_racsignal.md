# Functional Reactive Programming (FRP) from Getting Started to "Giving Up" — Illustrated RACSignal Edition


![](https://img.halfrost.com//Blog/ArticleTitleImage/c/ac/7edb67708d620d3fa721e92b330bd.jpg)


#### Table of Contents
- 1. Creating RACSignal
- 2. Subscribing to RACSignal
- 3. Various RACSignal Operations


####I. Creating RACSignal  

1. Creating a unit signal
```

    NSError *errorObject = [NSError errorWithDomain:@"Something wrong" code:500 userInfo:nil];  

    //Basic four creation methods
    RACSignal *signal1 = [RACSignal return:@"Some Value"];
    RACSignal *signal2 = [RACSignal error:errorObject];
    RACSignal *signal3 = [RACSignal empty];
    RACSignal *signal4 = [RACSignal never];
```
2.Create dynamic signals
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
3.Obtain a signal via Cocoa bridging
```

    RACSignal *signal6 = [view rac_signalForSelector:@selector(setFrame:)];
    RACSignal *signal7 = [view rac_signalForControlEvents:UIControlEventTouchUpInside];
    RACSignal *signal8 = [view rac_willDeallocSignal];

    //Implementation of KVO principles
    RACSignal *signal9 = RACObserve(view, backgroundColor);
```  
4. Obtained through signal transformation
```
RACSignal *signal10 = [signal1 map:^id(NSString *value) {
        return [value substringFromIndex:1];
    }];
```
5. Obtained through sequence conversion
```

RACSequence *sequence = @[@"A", @"B", @"C"].rac_sequence;

//The signal11 obtained after this conversion emits values very quickly
RACSignal *signal11 = sequence.signal;
```

#### II. Subscribing to RACSignal  

1. Subscription method
```

    [signal11 subscribeNext:^(id x) {
        NSLog(@"next value is %@", x);
    } error:^(NSError *error) {
        NSLog(@"Ops! Get some error: %@", error);
    } completed:^{
        NSLog(@"It finished success");
    }];
```
2. Binding Methods
```
//This is equivalent to KVO; each time signal produces a color, it assigns it to backgroundColor
RAC(view, backgroundColor) = signal10;

```
3. Cocoa Bridging
```

[view rac_liftSelector:@selector(convertPoint:toView:)
               withSignals:signal1, signal2, nil];

[view rac_liftSelector:@selector(convertRect:toView:)
      withSignalsFromArray:@[signal3, signal4]];

[view rac_liftSelector:@selector(convertRect:toLayer:)
     withSignalOfArguments:signal5];
```
It is worth noting that if `selector` has a return value, calling `rac_liftSelector` will produce a new signal. The new signal is the return value after calling `selector`.

4. Execution flow of the subscription process
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
If a `signal` is subscribed to, execution first enters the block where the signal is created. When execution reaches `sendNext`, `sendCompleted`, or `sendError`, it then moves to the corresponding subscriber blocks: `subscribeNext`, `completed`, or `error`. The main execution flow still runs inside the signal creation block; only when it reaches a specific `sendNext`, `sendCompleted`, or `sendError` does it jump to the corresponding subscriber block for execution. After the subscriber’s corresponding block finishes executing, control returns to the signal’s block and continues downward. Finally, after the signal finishes executing, the `disposable` is executed. When the signal discovers a `disposable`, it immediately invokes the block of the `RACDisposable` inside the signal creation block.

Execution order: 1-6-2-6-3-8-4-5-9


The difference between `RACStream` and `RACSignal` is whether they return data or events.

There are three types of events in total: value, error, and completion.

A value may be an Objective-C object, an `RACTuple`, or even an `RACSignal`.

First, let’s talk about `RACTuple`. `RACTuple` is also a data type defined by RAC; it can be considered a simplified version of `NSArray`.
```

    RACTuple *tuple = RACTuplePack(@1, @"haha");
    
    id first = tuple.first;
    id second = tuple.second;
    id last = tuple.last;
    id index1 = tuple[1];
    
    RACTupleUnpack(NSNumber *num, NSString *str) = tuple;
```
There are two macros here. `RACTuplePack` can pack the following two objects into an `RACTuple`. `RACTuple` also supports subscript access. During usage, the type is not `id`, so you need to cast it explicitly. A typical usage looks like this: `RACTupleUnpack(NSNumber *num, NSString *str)`.

####III. Various Operations on `RACSignal`

First, let’s agree on the legend:

![](http://upload-images.jianshu.io/upload_images/1194012-31823227ffed454f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####1. Transformations on a Single Signal  
- 1. Operations on values
- 2. Operations on count
- 3. Operations on dimensions
- 4. Operations on time intervals


![](http://upload-images.jianshu.io/upload_images/1194012-493f98c66bfdf7cb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1. Operations on values  

- Map operation
- MapReplace operation
- ReduceEach operation
- not operation
- and operation
- or operation
- reduceApply operation
- materialize operation
- dematerialize operation

(1) Map operation  

![](http://upload-images.jianshu.io/upload_images/1194012-9558edfc6d89d701.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *SignalB = [signalA map:^id(NSNumber *value) {
        return @(value.integerValue * 2);
    }];
```
If an Error is encountered during Map, the Error is not mapped; it is returned directly.

![](http://upload-images.jianshu.io/upload_images/1194012-75fd1b2e7ca6bae4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


(2) MapReplace operation


![](http://upload-images.jianshu.io/upload_images/1194012-adcd0aab1318ee97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *signalB = [signalA map:^id(id value) {
        return @8;
    }]; // signalB is --8--8--8--8--|
    
RACSignal *signalC = [signalA mapReplace:@8];
    // signalC is --8--8--8--8--| too.
```
(3) ReduceEach Operation

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
`reduceEach` can be followed by parameters of specific types.

(4) `not` operation


![](http://upload-images.jianshu.io/upload_images/1194012-7628d11ce0b4f366.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

 RACSignal *signalA = @[@0, @1, @1, @0].rac_sequence.signal;
    
 RACSignal *signalB = [signalA not];
```  
(5) AND Operation


![](http://upload-images.jianshu.io/upload_images/1194012-7ce7facd5d03c956.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACTuple *a = RACTuplePack(@0, @1);
    RACTuple *b = RACTuplePack(@0, @0);
    RACTuple *c = RACTuplePack(@1, @1);
    RACTuple *d = RACTuplePack(@1, @0);
    
    RACSignal *signalA = @[a, b, c, d].rac_sequence.signal;
    
    RACSignal *signalB = [signalA and];
```  
(6) OR Operation  

![](http://upload-images.jianshu.io/upload_images/1194012-b69324ddb36bbc0f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```


    RACTuple *a = RACTuplePack(@0, @1);
    RACTuple *b = RACTuplePack(@0, @0);
    RACTuple *c = RACTuplePack(@1, @1);
    RACTuple *d = RACTuplePack(@1, @0);

    RACSignal *signalA = @[a, b, c, d].rac_sequence.signal;
    
    RACSignal *signalB = [signalA or];
```
(7) reduceApply Operation
Here, a block is treated as the `first` of an RACTuple, while `second` and `third` are the other parameters. When the reduceApply operation is executed, it takes the block from the first parameter, then passes the second and third parameters into that block.


(8) materialize Operation
This operation converts ordinary Complete, Error, and Next events into ordinary value events and passes them through.

(9) dematerialize Operation  
RACEvent has some values
```
RACEventTypeCompleted,
RACEventTypeError,
RACEventTypeNext
```
After applying the dematerialize operator, you can convert the values above back into their corresponding events.  

(10) Scan Operator


![](http://upload-images.jianshu.io/upload_images/1194012-adb11010c6fb63a3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
    RACSignal *signalB = [signalA scanWithStart:@0
                                         reduce:^id(NSNumber *running,
                                                    NSNumber *next) {
        return @(running.integerValue + next.integerValue);
    }];
```
Compared with the Aggregate operation in the quantitative operations below, the advantage here is obvious: you can get a value on every “scan.”
```
- (RACSignal *)scanWithStart:(id)startingValue   
             reduceWithIndex:(id (^)(id running, id next, NSUInteger index))reduceBlock;
```
The above is a variant of `scan`.


2. Operations on the Number of Items

- Filter operation
- Ignore / IgnoreValues operation
- DistinctUntilChanged operation
- Take operation
- Skip operation
- StartWith operation
- Repeat operation
- Retry operation
- Collect operation
- Aggregate operation


(1) Filter operation

![](http://upload-images.jianshu.io/upload_images/1194012-f3fb1cb8c3aca987.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@"ab", @"hello", @"ppp", @"0"].rac_sequence.signal;
    
    RACSignal *signalB = [signalA filter:^BOOL(NSString *value) {
        return value.length > 2;
    }];
```
(2) Ignore / IgnoreValues Operations

Ignore Operation

![](http://upload-images.jianshu.io/upload_images/1194012-4646fa07e4ea4c97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @1, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA filter:^BOOL(id value) {
        return ![@1 isEqual:value];
    }];
    
    RACSignal *signalC = [signalA ignore:@1];
```  
IgnoreValues Operation

After this operation, the new signal has no values; only Error and Complete events remain.

![](http://upload-images.jianshu.io/upload_images/1194012-a951993bccbc6a0d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  
```

    RACSignal *signalA = @[@1, @2, @1, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA ignoreValues];
```
(3) DistinctUntilChanged Operation
This operation is essentially deduplication.

![](http://upload-images.jianshu.io/upload_images/1194012-dfacd25c58482b05.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1,@1,@2,@2,@3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA distinctUntilChanged];
```  
(4) Take Operation


![](http://upload-images.jianshu.io/upload_images/1194012-4c1a699dfe83bde4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA take:2];
```
(5) Skip Operation


![](http://upload-images.jianshu.io/upload_images/1194012-d1779d3ae60f7baa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    
    RACSignal *signalB = [signalA skip:2];
```
Variants of the take and Skip methods
```

- (RACSignal *)takeLast:(NSUInteger)count;
- (RACSignal *)takeUntilBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)takeWhileBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)skipUntilBlock:(BOOL (^)(id x))predicate;
- (RACSignal *)skipWhileBlock:(BOOL (^)(id x))predicate;
``` 
A predicate is a rule passed in to determine whether to include something or skip it.

(6) StartWith Operation


![](http://upload-images.jianshu.io/upload_images/1194012-5eb4c8a859ad7de9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalA = @[@"ab", @"hello", @"app", @"1"].rac_sequence.signal;
    
RACSignal *signalB = [signalA startWith:@"Start"];
```
(7) Repeat Operation


![](http://upload-images.jianshu.io/upload_images/1194012-3187c446c645f073.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalA = @[@"ab", @"hello"].rac_sequence.signal;
RACSignal *signalB = [signalA repeat];
```
(8) Retry Operation

In some network requests, if we encapsulate the network fetch as a signal, an error will be thrown when the network request fails, indicating that the network cannot be connected. At this point, the client may need to reconnect.


![](http://upload-images.jianshu.io/upload_images/1194012-5cf8576101a3875c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```
RACSignal *signalA = @[@"ab"].rac_sequence.signal;
RACSignal *signalB = [signalA retry:2];
```
The number after Retry is the number of retry attempts.

This can introduce side-effecting operations.
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
Side-effect operations refer to extra operations that do not affect the value, such as playing animations, printing some text on the screen, showing pop-ups, and so on.

The following convenience methods are available:
```
- (RACSignal *)doError:(void (^)(NSError *error))block;
- (RACSignal *)doCompleted:(void (^)(void))block;
- (RACSignal *)initially:(void (^)(void))block;
- (RACSignal *)finally:(void (^)(void))block;
```  
(9) Collect Operation


![](http://upload-images.jianshu.io/upload_images/1194012-f1b01ecbc516c887.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```
RACSignal *signalA = @[@"ab", @"hello", @"ppp", @"0"].rac_sequence.signal;
    
RACSignal *signalB = [signalA collect];
```
(10) Aggregate Operation
This function is actually a “fold function”

![](http://upload-images.jianshu.io/upload_images/1194012-995c1563638f089b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```
RACSignal *signalA = @[@1, @2, @3, @4].rac_sequence.signal;
    
RACSignal *signalB = [signalA aggregateWithStart:@0
                                              reduce:^id(NSNumber *running,
                                                         NSNumber *next) {
        return @(running.integerValue + next.integerValue);
    }];
``` 
It is worth noting that this function only returns when it terminates; if it does not terminate, it never returns. If it encounters a `Repeat` signal, it will never return at all. `aggregateWithStart` has an initial value. Its drawback is that you cannot obtain intermediate values during the changes; you only get a value at the end. Compared with the `Scan` operation in value operations, `Scan` is still the better choice.
```
 - (RACSignal *)aggregateWithStart:(id)start 
                   reduceWithIndex:(id (^)(id running, id next, NSUInteger index))reduceBlock;
 - (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory 
                                   reduce:(id (^)(id running, id next))reduceBlock;
``` 
This is a variant of the aggregate function.  


3.Operations on time intervals
- Unit interval time signal
- Delay operation
- Throttle operation


(1)Unit interval time signal
```

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;
+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway;
```
The two methods above return a time signal at intervals of `interval`. A signal is emitted every `interval`.

(2) Delay operation

Delays the source signal by 1 second before sending it.
![](http://upload-images.jianshu.io/upload_images/1194012-736b439f164785be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalB = [signalA delay:1];
```
(3) Throttle Operation


![](http://upload-images.jianshu.io/upload_images/1194012-122ce82b819396ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalB = [signalA throttle:2];
```
The value after `throttle` indicates the interval in seconds. If no value arrives after that interval, it emits the previously observed value. For example, in the case above, after `1` is emitted, there is a 2-second interval. Within those 2 seconds, `2` arrives, so it continues listening for another 2 seconds. Within those 2 seconds, `3` arrives, so it continues listening for another 2 seconds. If no other value arrives during those 2 seconds, it emits `3`. By the same logic, it will emit `5` and `6`.

A scenario where we use this function in development is search.
When a user keeps typing in the search box, making a network request on every input would waste bandwidth and is unnecessary. In this case, `throttle` can be used. If the user stops typing for 1 second, then we can send the network request.
```

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate;
- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;
```
These are variants of the Throttle function.


####2. Combining multiple signals
- 1. Concat combination operation
- 2. Merge combination operation
- 3. Zip combination operation
- 4. CombineLatest combination operation
- 5. Sample combination operation
- 6. TakeUntil / TakeUntilReplacement combination operation

1. Concat combination operation


![](http://upload-images.jianshu.io/upload_images/1194012-21fdb249e315d32d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3, @4, @5].rac_sequence.signal;
    RACSignal *signalB = @[@6, @7].rac_sequence.signal;
    
    RACSignal *signalC = [signalA concat:signalB];
```  
How Concat works: it subscribes to A first, and only after A has completed does it continue to subscribe to B. At this point, you can see that B has already completed long before. This also demonstrates that defining a signal and subscribing to a signal are separate concerns.

If A encounters an error, then B will never get involved.

![](http://upload-images.jianshu.io/upload_images/1194012-3930552684a844ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If B encounters an error, then C will propagate that error.

![](http://upload-images.jianshu.io/upload_images/1194012-ed1fc826ac7dab4a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


2. Merge Combination Operator


![](http://upload-images.jianshu.io/upload_images/1194012-33c271814737d904.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3, @4, @5].rac_sequence.signal;
    RACSignal *signalB = @[@6, @7].rac_sequence.signal;
    
    RACSignal *signalC = [signalA merge:signalB];
    RACSignal *signalC = [RACSignal merge:@[signalA, signalB]];
    RACSignal *signalC = [RACSignal merge:RACTuplePack(signalA, signalB)];
 
```
If SignalA and SignalB are two threads, then SignalC will shuttle between the two threads to send events. In the example shown above, 1, 2, 3, and 5 are sent on thread A, while 4, 6, and 7 are sent on thread B.

In real-world development, Merge may be used in scenarios like the following:
```

RACSignal *appearSignal = [[self rac_signalForSelector:@selector(viewDidAppear:)]
                               mapReplace:@YES];
RACSignal *disappearSignal = [[self rac_signalForSelector:@selector(viewWillDisappear:)]
                                  mapReplace:@NO];
RACSignal *activeSignal = [RACSignal merge:@[appearSignal, disappearSignal]];
```
The signal obtained from `activeSignal` indicates whether the app is in the foreground.

3. Zip Combination Operation

![](http://upload-images.jianshu.io/upload_images/1194012-a04d8e0c02c57c7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```
RACSignal *signalA = @[@1, @2, @3, @5].rac_sequence.signal;
RACSignal *signalB = @[@4, @6, @7].rac_sequence.signal;

RACSignal *signalC = [signalA zipWith:signalB];
RACSignal *signalC = [RACSignal zip:@[signalA, signalB]];
RACSignal *signalC = [RACSignal zip:RACTuplePack(signalA, signalB)];
```
Pay attention to the color of the RACTuple in the figure. Termination is controlled by whichever signal is shorter. The sending time is determined by whichever value arrives later; send that pair then. For (1, 4), 4 arrives later, so send the RACTuple when 4 arrives. For (2, 6), 6 arrives later, so send the RACTuple when 6 arrives. For (3, 7), 3 arrives later, so send the RACTuple when 3 arrives.


4. CombineLatest combination operation


![](http://upload-images.jianshu.io/upload_images/1194012-723e854a562298a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

    RACSignal *signalA = @[@1, @2, @3].rac_sequence.signal;
    RACSignal *signalB = @[@4, @6, @7].rac_sequence.signal;
    
     RACSignal *signalC = [signalA combineLatestWith:signalB];
     RACSignal *signalC = [RACSignal combineLatest:@[signalA, signalB]];
     RACSignal *signalC = [RACSignal combineLatest:RACTuplePack(signalA, signalB)];
```  
Always combines the latest values and returns them as a new value. Termination is controlled by whoever is responsible for it.
```
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock;
+ (RACSignal *)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock;
```
These are convenient syntactic-sugar-like operations corresponding to `combineLatest` and `Zip`, respectively. They simply add a `Reduce` at the end.

5. Sample Combination Operation

![](http://upload-images.jianshu.io/upload_images/1194012-107e725a6813f7c3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```
RACSignal *signalC = [signalA sample:signalB];
```
Whichever one completes first, the resulting signal completes along with it.

![](http://upload-images.jianshu.io/upload_images/1194012-13e69a0e9ac4f21b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If an error occurs, this function acts like a shutter. It will also capture the Error and return it.


6.TakeUntil / TakeUntilReplacement composition operations


![](http://upload-images.jianshu.io/upload_images/1194012-e6868359cb0ae356.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalC = [signalA takeUntil:signalB];
```
Terminate A when B occurs.

![](http://upload-images.jianshu.io/upload_images/1194012-3126818c4567512b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```

RACSignal *signalC = [signalA takeUntilReplacement:signalB];
```  
When B occurs, terminate A, and then proceed immediately with B.