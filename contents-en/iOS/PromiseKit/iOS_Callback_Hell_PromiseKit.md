# How to Elegantly Handle “Callback Hell” on iOS (Part 1) — Using PromiseKit

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleTitleImage/5/67/ccdf7c53c68a53261257b281cdd72.png">
</p> 


## Preface

Recently I read several articles about encapsulating asynchronous workflows in Swift, such as RxSwift, RAC, and so on. Since I’ve also written my fair share of callback hell, this resonated with me, so I dug up PromiseKit to study it. I’d like to share some of what I’ve learned. If there are any mistakes, I’d be grateful for corrections.

## Table of Contents

- 1.Introduction to PromiseKit
- 2.Installing and Using PromiseKit
- 3.How to Use PromiseKit’s Main Functions
- 4.PromiseKit Source Code Analysis
- 5.Using PromiseKit to Elegantly Handle Callback Hell

## 1.Introduction to PromiseKit

PromiseKit is a framework for handling asynchronous programming on iOS/OS X. It was developed by Max Howell, the author of Homebrew on Mac and a legendary engineer who, as the story goes, did not receive a Google offer because he “couldn’t” invert a binary tree.

In PromiseKit, the most important concept is the Promise itself. A Promise is the future value produced by an asynchronous operation.

>A [promise](http://wikipedia.org/wiki/Promise_%28programming%29) represents the future value of an asynchronous task.
A promise is an object that wraps an asynchronous task

A Promise is also an object that wraps an asynchronous operation. By using PromiseKit, you can write clean, orderly code with straightforward logic, pass Promises as parameters, and modularly move from one asynchronous task to the next. Code written with PromiseKit looks like this:
```objectivec  

[self login].then(^{
                  
     // our login method wrapped an async task in a promise
     return [API fetchData];
                  
}).then(^(NSArray *fetchedData){
                          
     // our API class wraps our API and returns promises
     // fetchedData returned a promise that resolves with an array of data
     self.datasource = fetchedData;
     [self.tableView reloadData];
                          
}).catch(^(NSError *error){
                                   
     // any errors in any of the above promises land here
     [[[UIAlertView alloc] init…] show];
                                   
});
```
PromiseKit is used to solve asynchronous operations and awkward error-handling callbacks with clean, concise code. It turns asynchronous operations into chained calls with a simple approach to error handling.

PromiseKit currently has two classes: `Promise<T>` (Swift) and `AnyPromise` (Objective-C). The difference between them lies in the characteristics of the two languages: `Promise<T>` is precisely and strictly typed, while `AnyPromise` is loosely defined, flexible, and dynamic.

In asynchronous programming, one of the most typical examples is callback hell. If it is not handled elegantly, you end up with something like this:

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_2.jpg">
</p>


The code above really existed. A friend told me about it; it came from [Kuaidi’s code](http://www.kuaidadi.com/assets/js/animate.js). Of course, they must have fixed it by now. Although this kind of code looks like this:

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_3.png">
</p>

Even though the code does not look elegant, the functionality is correct. But this is the kind of code almost everyone has written themselves; I have written plenty of it too. Today, let’s get hands-on and use PromiseKit to handle callback hell elegantly.


## II. Installing and Using PromiseKit
1. Download and install CocoaPods  

Installation steps outside the Great Firewall:  
Enter the following in Terminal
```vim  
sudo gem install cocoapods && pod setup
```
Most of you behind the Great Firewall should follow the steps below:  
```vim  
//Remove the original external Ruby default source
$ gem sources --remove https://rubygems.org/
//Add the existing internal Taobao source
$ gem sources -a https://ruby.taobao.org/
//Verify the new source was switched successfully
$ gem sources -l
//Download and install cocoapods
// Before OS 10.11
$ sudo gem install cocoapods
//mark：After upgrading OS to OS X EL Capitan, the command should be:
$ sudo gem install -n /usr/local/bin cocoapods
//Set up cocoapods
$ pod setup
```
2. Locate the project path, enter the project directory, and run:
```vim  
$ touch Podfile && open -e Podfile
```
At this point, TextEdit will open. Enter the following command:
```vim  
platform:ios, ‘7.0’

target 'PromisekitDemo' do  //Required by the latest version of CocoaPods, so this line must be added
    pod 'PromiseKit'
end
```
>Tips: Thanks to qinfensky for the reminder—actually, you can also use the init command here.
A Podfile is a special CocoaPods file where you can list the open-source libraries you want to use in your project. There are two ways to create a Podfile:
1. Create an empty text file in the project directory and name it Podfile
2. Or run “$ pod init” in the project directory to create the functional file (enter cd folder path in the terminal, then enter pod init)
Both methods can create a Podfile, so use whichever one you prefer

3. Install PromiseKit
```vim  
$ pod install
```
After the installation is complete, exit the terminal and open the newly generated .xcworkspace file.


## 3. How to Use the Main PromiseKit Functions
1. then
We often write code like this:
```objectivec  
- (void)showUndoRedoAlert:(UndoRedoState *)state
{
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:……];
     alert.delegate = self; 
     self.state = state;
     [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        [self.state do];
    }

}

```
The approach above isn’t wrong; it stores a property in the calling function, and that property is used when calling `alertView`. In fact, this intermediate property does not need to be stored. Next, we’ll use `then` to remove this intermediate variable.
```objectivec  

- (void)showUndoRedoAlert:(UndoRedoState *)state
 {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:……];
    [alert promise].then(^(NSNumber *dismissedButtonIndex){
        [state do];
    });
}
```
At this point, someone might ask: why can we call the [alert promise] method? Why is then appended with dot syntax afterward? Let me explain. The reason becomes obvious once you open the Promise source code. In the Promise source code
```objectivec  

@interface UIAlertView (PromiseKit)

/**
 Displays the alert view.

 @return A promise the fulfills with two parameters:
 1) The index of the button that was tapped to dismiss the alert.
 2) This alert view.
*/
- (PMKPromise *)promise;
```
The corresponding implementation looks like this.
```objectivec  
- (PMKPromise *)promise {
    PMKAlertViewDelegater *d = [PMKAlertViewDelegater new];
    PMKRetain(d);
    self.delegate = d;
    [self show];
    return [PMKPromise new:^(id fulfiller, id rejecter){
        d->fulfiller = fulfiller;
    }];
}
```
Calling [alert promise] returns another promise object. The promise method includes a then method, which is why the chained call above works. The fulfiller in the code above will be discussed in the source code analysis section.

In PromiseKit, several class extensions are actually created for you by default, as shown below.

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_4.png">
</p>

These extension classes encapsulate some commonly used methods for creating promises. Once you call these methods, you can happily keep executing .then all the way through!

2.dispatch_promise
In projects, we often download images asynchronously.
```objectivec  
typedefvoid(^onImageReady) (UIImage* image);

+ (void)getImageWithURL:(NSURL *)url onCallback:(onImageReady)callback
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSData * imageData = [NSData dataWithContentsOfURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image = [UIImage imageWithData:imageData];
            callback(image);
        });
    });
}
```
Using `dispatch_promise`, we can change it to the following:
```objectivec  
    dispatch_promise(^{
        return [NSData dataWithContentsOfURL:url];     
    }).then(^(NSData * imageData){ 
        self.imageView.image = [UIImage imageWithData:imageData];  
    }).then(^{
        // add code to happen next here
    });
```
Let's look at the source code and check whether the asynchronous call flow is correct.
```objectivec  
- (PMKPromise *(^)(id))then {
    return ^(id block){
        return self.thenOn(dispatch_get_main_queue(), block);
    };
}

PMKPromise *dispatch_promise(id block) {
    return dispatch_promise_on(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}
```
Reading the source code confirms that the above is correct.

3.catch
In asynchronous operations, error handling is also a major headache. As in the code below, every time an asynchronous request returns, the error must be handled.
```objectivec  

void (^errorHandler)(NSError *) = ^(NSError *error) {
    [[UIAlertView …] show];
};
[NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
    if (connectionError) {
        errorHandler(connectionError);
    } else {
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            errorHandler(jsonError);
        } else {
            id rq = [NSURLRequest requestWithURL:[NSURL URLWithString:json[@"avatar_url"]]];
            [NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                UIImage *image = [UIImage imageWithData:data];
                if (!image) {
                    errorHandler(nil); // NSError TODO!
                } else {
                    self.imageView.image = image;
                }
            }];
        }
    }
}];
```
We can use a Promise’s `catch` to solve the error-handling issue above.
```objectivec  
//OC version
[NSURLSession GET:url].then(^(NSDictionary *json){
    return [NSURLConnection GET:json[@"avatar_url"]];
}).then(^(UIImage *image){
    self.imageView.image = image;
}).catch(^(NSError *error){
    [[UIAlertView …] show];
})
```
```swift  
//Swift version
firstly {
    NSURLSession.GET(url)
}.then { (json: NSDictionary) in
    NSURLConnection.GET(json["avatar_url"])
}.then { (image: UIImage) in
    self.imageView.image = image
}.error { error in
    UIAlertView(…).show()
}
```
After using `catch`, in a chain of passed-along promises, once any intermediate step produces an error, it will be propagated to `catch` to execute the Error Handler.

4.when
Typically, we have this kind of requirement:
Before executing task A, there are one or two asynchronous tasks; before all asynchronous operations are completed, task A needs to be blocked. The code might look like this:
```objectivec  

__block int x = 0;
void (^completionHandler)(id, id) = ^(MKLocalSearchResponse *response, NSError *error){
    if (++x == 2) {
        [self finish];
    }
};
[[[MKLocalSearch alloc] initWithRequest:rq1] startWithCompletionHandler:completionHandler];
[[[MKLocalSearch alloc] initWithRequest:rq2] startWithCompletionHandler:completionHandler];
```
Here, you can use `when` to handle this situation elegantly:
```objectivec  

id search1 = [[[MKLocalSearch alloc] initWithRequest:rq1] promise];
id search2 = [[[MKLocalSearch alloc] initWithRequest:rq2] promise];

PMKWhen(@[search1, search2]).then(^(NSArray *results){
    //…
}).catch(^{
    // called if either search fails
});
```
Pass an array to `when`, containing two promises. Only after both promises have completed will the subsequent `then` operation be executed. This satisfies the requirement described earlier.

There are two more points to mention about `when`: its argument can also be a dictionary.
```objectivec  

id coffeeSearch = [[MKLocalSearch alloc] initWithRequest:rq1];
id beerSearch = [[MKLocalSearch alloc] initWithRequest:rq2];
id input = @{@"coffee": coffeeSearch, @"beer": beerSearch};

PMKWhen(input).then(^(NSDictionary *results){
    id coffeeResults = results[@"coffee"];
});
```
In this example, `when` is passed an `input` dictionary. After processing completes, it can still generate a new promise to pass to the next `then`. Inside `then`, you can access the `results` dictionary to obtain the result. The mechanism by which dictionaries are passed in is explained in Chapter 4.

The parameter passed to `when` can also be a variadic property:
```objectivec  

@property id dataSource;

- (id)dataSource {
    return dataSource ?: [PMKPromise new:…];
}

- (void)viewDidAppear {
    [PMKPromise when:self.dataSource].then(^(id result){
        // cache the result
        self.dataSource = result;
    });
}
```
If dataSource is empty, create a new promise, pass it into when, and after execution completes, get result in then and assign result to dataSource. This way, dataSource will have data. From this, we can see that when is extremely flexible to use!

5.always & finally
```objectivec  
//OC version
[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
[self myPromise].then(^{
    //…
}).finally(^{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
})
```

```swift
//Swift version
UIApplication.sharedApplication().networkActivityIndicatorVisible = true
myPromise().then {
    //…
}.always {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
}
```
After we have executed `then` and handled the error, if there are still additional operations to perform, we can put them in `finally` and `always`.

## 4. Source Code Analysis of PromiseKit

After learning the Promise methods above, we can see that in asynchronous operations we can continuously return promises and pass them to subsequent `then` calls to form a chain. So the key point is the implementation of `then`. Before discussing `then`, I will first talk about the state and propagation mechanism of a promise.


A promise can be in one of three states: pending, fulfilled, or rejected.  
A promise can only transition from “pending” to “fulfilled” or “rejected”; it cannot transition backward, and “fulfilled” and “rejected” cannot transition to each other.  
A promise must implement the `then` method (you could say that `then` is the core of a promise), and `then` must return a promise. The `then` method of the same promise can be called multiple times, and the execution order of the callbacks is consistent with the order in which they were defined.
The `then` method accepts two parameters. The first parameter is the success callback, which is called when the promise transitions from “pending” to “fulfilled”. The other is the failure callback, which is called when the promise transitions from “pending” to “rejected”. At the same time, `then` can accept another promise as input, and it can also accept a “then-like” object or method, that is, a thenable object.

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_5.png">
</p>


In summary, as shown in the figure above, a promise object in the pending state can transition either to the fulfilled state with a success value or to the rejected state with an error message. When the state transition occurs, the methods bound via `promise.then` will be called. (When binding a method, if the promise object is already in the fulfilled or rejected state, the corresponding method will be called immediately, so there is no race condition between the completion of the asynchronous operation and its bound method.) After transitioning from pending to fulfilled or rejected, the state of this promise object will never change again. Therefore, `then` is a function that is called only once, which also explains why `then` produces a new promise rather than the original one.


After understanding the flow, we can continue studying the source code. In PromiseKit, the most commonly used methods are `then`, `thenInBackground`, `catch`, and `finally`.
```objectivec  

- (PMKPromise *(^)(id))then {
    return ^(id block){
        return self.thenOn(dispatch_get_main_queue(), block);
    };
}

- (PMKPromise *(^)(id))thenInBackground {
    return ^(id block){
        return self.thenOn(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
    };
}

- (PMKPromise *(^)(id))catch {
    return ^(id block){
        return self.catchOn(dispatch_get_main_queue(), block);
    };
}

- (PMKPromise *(^)(dispatch_block_t))finally {
    return ^(dispatch_block_t block) {
        return self.finallyOn(dispatch_get_main_queue(), block);
    };
}
```
These four methods all call their respective thenon, catchon, and finallyon methods under the hood. The implementations of these on methods are largely the same, so I’ll analyze the most important one, thenon.
```objectivec  

- (PMKResolveOnQueueBlock)thenOn {
    return [self resolved:^(id result) {
        if (IsPromise(result))
            return ((PMKPromise *)result).thenOn;

        if (IsError(result)) return ^(dispatch_queue_t q, id block) {
            return [PMKPromise promiseWithValue:result];
        };

        return ^(dispatch_queue_t q, id block) {
            block = [block copy];
            return dispatch_promise_on(q, ^{
                return pmk_safely_call_block(block, result);
            });
        };
    }
    pending:^(id result, PMKPromise *next, dispatch_queue_t q, id block, void (^resolve)(id)) {
        if (IsError(result))
            PMKResolve(next, result);
        else dispatch_async(q, ^{
            resolve(pmk_safely_call_block(block, result));
        });
    }];
}
```
This `thenon` returns a method, so let’s keep reading.
```objectivec  
- (id)resolved:(PMKResolveOnQueueBlock(^)(id result))mkresolvedCallback
       pending:(void(^)(id result, PMKPromise *next, dispatch_queue_t q, id block, void (^resolver)(id)))mkpendingCallback
{
    __block PMKResolveOnQueueBlock callBlock;
    __block id result;
    
    dispatch_sync(_promiseQueue, ^{
        if ((result = _result))
            return;

        callBlock = ^(dispatch_queue_t q, id block) {

            block = [block copy];

            __block PMKPromise *next = nil;

            dispatch_barrier_sync(_promiseQueue, ^{
                if ((result = _result))
                    return;

                __block PMKPromiseFulfiller resolver;
                next = [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
                    resolver = ^(id o){
                        if (IsError(o)) reject(o); else fulfill(o);
                    };
                }];
                [_handlers addObject:^(id value){
                    mkpendingCallback(value, next, q, block, resolver);
                }];
            });

            return next ?: mkresolvedCallback(result)(q, block);
        };
    });

    // We could just always return the above block, but then every caller would
    // trigger a barrier_sync on the promise queue. Instead, if we know that the
    // promise is resolved (since that makes it immutable), we can return a simpler
    // block that doesn't use a barrier in those cases.

    return callBlock ?: mkresolvedCallback(result);
}
```
This method looks quite complex, but if you look closely, the function parameters are essentially just two blocks: one resolved block and one pending block. After a promise has been resolved, it may be fulfilled or rejected. Then a new `next` promise is generated and passed into the next `then`, and its state becomes pending. In the first `return` in the code above, if `next` is `nil`, it means the promise has not been generated. In that case, `mkresolvedCallback` is called again with `result` as the argument, and the generated `PMKResolveOnQueueBlock` is passed into `(q, block)` again, until the `next` promise is generated and the `pendingCallback` is stored in the handler. This handler stores all blocks waiting to be executed. If all the blocks in this array are executed, it is equivalent to completing all the asynchronous operations above in sequence. The second `return` occurs when `callblock` is `nil`; `mkresolvedCallback(result)` is called again to ensure that the `next` promise is generated.

The `dispatch_barrier_sync` call in this function is what enables chained `then` calls after a promise. Because of this GCD method, subsequent `then` calls behave as if they were executed sequentially, one line after another.

Some people may ask: we do not see the individual blocks being executed; they are only added to the handler array. The answer to this question is the core of promises. The operation that executes promise blocks is placed inside `resolve`. Let’s first look at the source code.
```objectivec  

static void PMKResolve(PMKPromise *this, id result) {
    void (^set)(id) = ^(id r){
        NSArray *handlers = PMKSetResult(this, r);
        for (void (^handler)(id) in handlers)
            handler(r);
    };

    if (IsPromise(result)) {
        PMKPromise *next = result;
        dispatch_barrier_sync(next->_promiseQueue, ^{
            id nextResult = next->_result;
            
            if (nextResult == nil) {  // ie. pending
                [next->_handlers addObject:^(id o){
                    PMKResolve(this, o);
                }];
            } else
                set(nextResult);
        });
    } else
        set(result);
}
```
This is a recursive function. The condition that enables recursion is the line `PMKResolve(this, o);`. When `nextResult = nil`, it means this promise is still in the pending state and has not been executed yet. At this point, it needs to be called recursively until `nextResult` is no longer `nil`. Once it is not `nil`, the `set` method is called. The `set` method is an anonymous function, and the `for` loop inside it iterates in order, executing each block in the `handler` array. The `if` statement inside first checks whether `result` is a promise. If it is not a promise, it executes the `set` method and invokes each block in sequence.

At this point, the execution principle of `then` is complete. Next, let’s look at how `when` works.
```objectivec  
    return newPromise = [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter){
        NSPointerArray *results = nil;
      #if TARGET_OS_IPHONE
        results = [NSPointerArray strongObjectsPointerArray];
      #else
        if ([[NSPointerArray class] respondsToSelector:@selector(strongObjectsPointerArray)]) {
            results = [NSPointerArray strongObjectsPointerArray];
        } else {
          #pragma clang diagnostic push
          #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            results = [NSPointerArray pointerArrayWithStrongObjects];
          #pragma clang diagnostic pop
        }
      #endif
        results.count = count;

        NSUInteger ii = 0;

        for (__strong PMKPromise *promise in promises) {
            if (![promise isKindOfClass:[PMKPromise class]])
                promise = [PMKPromise promiseWithValue:promise];
            promise.catch(rejecter(@(ii)));
            promise.then(^(id o){
                [results replacePointerAtIndex:ii withPointer:(__bridge void *)(o ?: [NSNull null])];
                if (--count == 0)
                    fulfiller(results.allObjects);
            });
            ii++;
        }
    }];
```
Only the `return` part is excerpted here. Once you understand `then`, `when` is easy to understand as well. `when` executes each promise in the passed-in `promises` array in order, then passes the results to a newly created promise, which is returned as the return value.

One additional point worth mentioning is how `when` handles a dictionary passed to it.
```objectivec  

    if ([promises isKindOfClass:[NSDictionary class]])
        return newPromise = [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter){
            NSMutableDictionary *results = [NSMutableDictionary new];
            for (id key in promises) {
                PMKPromise *promise = promises[key];
                if (![promise isKindOfClass:[PMKPromise class]])
                    promise = [PMKPromise promiseWithValue:promise];
                promise.catch(rejecter(key));
                promise.then(^(id o){
                    if (o)
                        results[key] = o;
                    if (--count == 0)
                        fulfiller(results);
                });
            }
        }];
```
The approach is basically the same as the array-based form of when, except for one extra step: first retrieve promise[key] from the dictionary, and then continue operating on that promise. So when can accept a dictionary whose values are promises.

## V. Using PromiseKit to Elegantly Handle Callback Hell
Here I’ll give an example so everyone can get a feel for how concise promises can be.
First, let’s describe the scenario. Suppose there is a submit button: when you click it, a task will be submitted. First, you need to check whether the user has permission to submit. If not, show an error. If they do have permission, you also need to make another request to determine whether the current task already exists. If it exists, show an error. If it does not exist, you can safely submit the task.
```objectivec  

void (^errorHandler)(NSError *) = ^(NSError *error) {
    [[UIAlertView …] show];
};
[NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
    if (connectionError) {
        errorHandler(connectionError);
    } else {
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            errorHandler(jsonError);
        } else {
            id rq = [NSURLRequest requestWithURL:[NSURL URLWithString:json[@"have_authority"]]];
            [NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                
                NSError *jsonError = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                
                if (jsonError) {
                    errorHandler(jsonError);
                } else {
                    id rq = [NSURLRequest requestWithURL:[NSURL URLWithString:json[@"exist"]]];
                    [NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                        
                        NSError *jsonError = nil;
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                        
                        if (jsonError) {
                            errorHandler(jsonError);
                        } else {
                            if ([json[@"status"] isEqualToString:@"OK"]) {
                                [self submitTask];
                            } else {
                                errorHandler(json[@"status"]);
                            }
                        }
                    }];
                }
            }];
        }
    }
}];
```
The code above has three levels of callbacks, which makes it look quite confusing. Next, let's clean it up using Promise.
```objectivec  

[NSURLSession GET:url].then(^(NSDictionary *json){
    return [NSURLConnection GET:json[@"have_authority"]];
}).then(^(NSDictionary *json){
    return [NSURLConnection GET:json[@"exist"]];
}).then(^(NSDictionary *json){
    if ([json[@"status"] isEqualToString:@"OK"]) {
        return [NSURLConnection GET:submitJson];
    } else
        @throw [NSError errorWithDomain:… code:… userInfo:json[@"status"]];
}).catch(^(NSError *error){
    [[UIAlertView …] show];
})
```
What used to be nearly 40 lines of code suddenly became about 15 lines. It looks much cleaner than before and is more readable.


## Final Thoughts
    
After reading the above usage examples for PromiseKit, my personal understanding is that PromiseKit is essentially a Monad. (This has been a very popular concept recently. At SwiftCon 2016 in Shanghai at the end of April, Tang Qiao gave a talk on Monad. If you are not yet familiar with the concept, you can check out his blog or find some videos to learn more.) A Promise is like a box that encapsulates a set of operations, and `then` corresponds to a series of `flatmap` or `map` operations. That said, it still has some drawbacks. If you are using AFNetWorking for networking, a network request may very likely invoke its callback multiple times. In that case, when using PromiseKit, you need to wrap your own promise. PromiseKit natively uses the OMGHTTPURLRQ networking framework. The network request wrappers built into PromiseKit are also based on NSURLConnection. So for those using AFNetWorking, if you want to elegantly eliminate callback hell caused by network requests, you still need to first wrap your own Promise, and then elegantly chain it with `then`. Many people may read this and feel that introducing a framework was supposed to solve the problem, but now they still need to wrap things again before the problem is solved, which may not seem worthwhile.

My own view is that PromiseKit is an excellent open-source library for solving asynchronous programming problems, especially callback nesting and callback hell, where the effect is very obvious. Although you need to wrap AFNetWorking promises yourself, its underlying idea is very much worth learning! This is also what I want to share with everyone in the second article: using the idea of promises to elegantly handle callback hell ourselves. That is all for this article on PromiseKit.

If there are any mistakes, I would greatly appreciate your guidance.


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_callback\_hell\_promisekit/](https://halfrost.com/ios_callback_hell_promisekit/)