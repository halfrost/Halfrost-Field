# iOS 如何优雅的处理“回调地狱 Callback hell ”(一) —— 使用 PromiseKit

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleTitleImage/5/67/ccdf7c53c68a53261257b281cdd72.png">
</p> 



## 前言

最近看了一些Swift关于封装异步操作过程的文章，比如RxSwift，RAC等等，因为回调地狱我自己也写过，很有感触，于是就翻出了Promise来研究学习一下。现将自己的一些收获分享一下，有错误欢迎大家多多指教。

## 目录

- 1.PromiseKit简介
- 2.PromiseKit安装和使用
- 3.PromiseKit主要函数的使用方法
- 4.PromiseKit的源码解析
- 5.使用PromiseKit优雅的处理回调地狱

## 一.PromiseKit简介

PromiseKit是iOS/OS X 中一个用来出来异步编程框架。这个框架是由Max Howell(Mac下Homebrew的作者，传说中因为"不会"写反转二叉树而没有拿到Google offer)大神级人物开发出来的。

在PromiseKit中，最重要的一个概念就是Promise的概念，Promise是异步操作后的future的一个值。

>A [promise](http://wikipedia.org/wiki/Promise_%28programming%29) represents the future value of an asynchronous task.
A promise is an object that wraps an asynchronous task

Promise也是一个包装着异步操作的一个对象。使用PromiseKit，能够编写出整洁，有序的代码，逻辑简单的，将Promise作为参数，模块化的从一个异步任务到下一个异步任务中去。用PromiseKit写出的代码就是这样：

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

PromiseKit就是用来干净简洁的代码，来解决异步操作，和奇怪的错误处理回调的。它将异步操作变成了链式的调用，简单的错误处理方式。

PromiseKit里面目前有2个类，一个是Promise<T>(Swift)，一个是AnyPromise(Objective-C)，2者的区别就在2种语言的特性上，Promise<T>是定义精确严格的，AnyPromise是定义宽松，灵活，动态的。

在异步编程中，有一个最最典型的例子就是回调地狱CallBack hell，要是处理的不优雅，就会出现下图这样:

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_2.jpg">
</p>


上图的代码是真实存在的，也是朋友告诉我的，来自[快的的代码](http://www.kuaidadi.com/assets/js/animate.js)，当然现在人家肯定改掉了。虽然这种代码看着像这样：

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_3.png">
</p>

代码虽然看上去不优雅，功能都是正确的，但是这种代码基本大家都自己写过，我自己也写过很多。今天就让我们动起手来，用PromiseKit来优雅的处理掉Callback hell吧。


## 二.PromiseKit安装和使用
1.下载安装CocoaPods  

在墙外的安装步骤:  
在Terminal里面输入

```vim  
sudo gem install cocoapods && pod setup
```

大多数在墙内的同学应该看如下步骤了:   

```vim  
//移除原有的墙外Ruby 默认源
$ gem sources --remove https://rubygems.org/
//添加现有的墙内的淘宝源
$ gem sources -a https://ruby.taobao.org/
//验证新源是否替换成功
$ gem sources -l
//下载安装cocoapods
// OS 10.11之前
$ sudo gem install cocoapods
//mark：OS 升级 OS X EL Capitan 后命令应该为:
$ sudo gem install -n /usr/local/bin cocoapods
//设置cocoapods
$ pod setup
```

2.找到项目的路径，进入项目文件夹下面，执行：

```vim  
$ touch Podfile && open -e Podfile
```

此时会打开TextEdit，然后输入一下命令:

```vim  
platform:ios, ‘7.0’

target 'PromisekitDemo' do  //由于最新版cocoapods的要求，所以必须加入这句话
    pod 'PromiseKit'
end
```

>Tips：感谢qinfensky大神提醒，其实这里也可以用init命令
Podfile是CocoaPods的特殊文件，在其中可以列入在项目中想要使用的开源库，若想创建Podfile，有2种方法：
1.在项目目录中创建空文本文件，命名为Podfile
2.或者可以再项目目录中运行“$ pod init “，来创建功能性文件（终端中输入cd 文件夹地址，然后再输入 pod init）
两种方法都可以创建Podfile，使用你最喜欢使用的方法

3.安装PromiseKit

```vim  
$ pod install
```

安装完成之后，退出终端，打开新生成的.xcworkspace文件即可


## 三.PromiseKit主要函数的使用方法
1. then
经常我们会写出这样的代码:

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

上面的写法也不是错误的，就是它在调用函数中保存了一个属性，在调用alertView会使用到这个属性。其实这个中间属性是不需要存储的。接下来我们就用then来去掉这个中间变量。

```objectivec  

- (void)showUndoRedoAlert:(UndoRedoState *)state
 {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:……];
    [alert promise].then(^(NSNumber *dismissedButtonIndex){
        [state do];
    });
}
```

这时就有人问了，为啥能调用[alert promise]这个方法？后面点语法跟着then是什么？我来解释一下，原因其实只要打开Promise源码就一清二楚了。在pormise源码中

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
对应的实现是这样的
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

调用[alert promise]返回还是一个promise对象，在promise的方法中有then的方法，所以上面可以那样链式的调用。上面代码里面的fulfiller放在源码分析里面去讲讲。

在PromiseKit里面，其实就默认给你创建了几个类的延展，如下图

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_4.png">
</p>

这些扩展类里面就封装了一些常用的生成promise方法，调用这些方法就可以愉快的一路.then执行下去了！

2.dispatch_promise
项目中我们经常会异步的下载图片

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

使用dispatch_promise，我们可以将它改变成下面这样:

```objectivec  
    dispatch_promise(^{
        return [NSData dataWithContentsOfURL:url];     
    }).then(^(NSData * imageData){ 
        self.imageView.image = [UIImage imageWithData:imageData];  
    }).then(^{
        // add code to happen next here
    });
```

我们看看源码，看看调用的异步过程对不对

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

看了源码就知道上述是正确的。

3.catch
在异步操作中，处理错误也是一件很头疼的事情，如下面这段代码，每次异步请求回来都必须要处理错误。

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

我们可以用promise的catch来解决上面的错误处理的问题

```objectivec  
//oc版
[NSURLSession GET:url].then(^(NSDictionary *json){
    return [NSURLConnection GET:json[@"avatar_url"]];
}).then(^(UIImage *image){
    self.imageView.image = image;
}).catch(^(NSError *error){
    [[UIAlertView …] show];
})
```
```swift  
//swift版
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

用了catch以后，在传递promise的链中，一旦中间任何一环产生了错误，都会传递到catch去执行Error Handler。

4.when
通常我们有这种需求:
在执行一个A任务之前还有1，2个异步的任务，在全部异步操作完成之前，需要阻塞A任务。代码可能会写的像下面这样子：

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

这里就可以使用when来优雅的处理这种情况:

```objectivec  

id search1 = [[[MKLocalSearch alloc] initWithRequest:rq1] promise];
id search2 = [[[MKLocalSearch alloc] initWithRequest:rq2] promise];

PMKWhen(@[search1, search2]).then(^(NSArray *results){
    //…
}).catch(^{
    // called if either search fails
});
```

在when后面传入一个数组，里面是2个promise，只有当这2个promise都执行完，才会去执行后面的then的操作。这样就达到了之前所说的需求。

这里when还有2点要说的，when的参数还可以是字典。

```objectivec  

id coffeeSearch = [[MKLocalSearch alloc] initWithRequest:rq1];
id beerSearch = [[MKLocalSearch alloc] initWithRequest:rq2];
id input = @{@"coffee": coffeeSearch, @"beer": beerSearch};

PMKWhen(input).then(^(NSDictionary *results){
    id coffeeResults = results[@"coffee"];
});
```
这个例子里面when传入了一个input字典，处理完成之后依旧可以生成新的promise传递到下一个then中，在then中可以去到results的字典，获得结果。传入字典的工作原理放在第四章会解释。

when传入的参数还可以是一个可变的属性：

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
dataSource如果为空就新建一个promise，传入到when中，执行完之后，在then中拿到result，并把result赋值给dataSource，这样dataSource就有数据了。由此看来，when的使用非常灵活！

5.always & finally

```objectivec  
//oc版
[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
[self myPromise].then(^{
    //…
}).finally(^{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
})
```

```swift
//swift版
UIApplication.sharedApplication().networkActivityIndicatorVisible = true
myPromise().then {
    //…
}.always {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
}
```
在我们执行完then，处理完error之后，还有一些操作，那么就可以放到finally和always里面去执行。

## 四.PromiseKit的源码解析

经过上面对promise的方法的学习，我们已经可以了解到，在异步操作我们可以通过不断的返回promise，传递给后面的then来形成链式调用，所以重点就在then的实现了。在讨论then之前，我先说一下promise的状态和传递机制。


一个promise可能有三种状态：等待（pending）、已完成（fulfilled）、已拒绝（rejected）。  
一个promise的状态只可能从“等待”转到“完成”态或者“拒绝”态，不能逆向转换，同时“完成”态和“拒绝”态不能相互转换。  
promise必须实现then方法（可以说，then就是promise的核心），而且then必须返回一个promise，同一个promise的then可以调用多次，并且回调的执行顺序跟它们被定义时的顺序一致
then方法接受两个参数，第一个参数是成功时的回调，在promise由“等待”态转换到“完成”态时调用，另一个是失败时的回调，在promise由“等待”态转换到“拒绝”态时调用。同时，then可以接受另一个promise传入，也接受一个“类then”的对象或方法，即thenable对象

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleImage/11_5.png">
</p>


总结起来就是上图，pending状态的promise对象既可转换为带着一个成功值的 fulfilled 状态，也可变为带着一个 error 信息的 rejected 状态。当状态发生转换时， promise.then 绑定的方法就会被调用。(当绑定方法时，如果 promise 对象已经处于 fulfilled 或 rejected 状态，那么相应的方法将会被立刻调用， 所以在异步操作的完成情况和它的绑定方法之间不存在竞争关系。)从Pending转换为fulfilled或Rejected之后， 这个promise对象的状态就不会再发生任何变化。因此 then是只被调用一次的函数，从而也能说明，then生成的是一个新的promise，而不是原来的那个。


了解完流程之后，就可以开始继续研究源码了。在PromiseKit当中，最常用的当属then，thenInBackground，catch，finally

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

这四个方法底层调用了各自的thenon，catchon，finallyon方法，这些on的方法实现基本都差不多，那我就以最重要的thenon来分析一下。

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

这个thenon就是返回一个方法，所以继续往下看

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

这个方法看上去很复杂，仔细看看，函数的形参其实就是2个block，一个是resolved的block，还有一个是pending的block。当一个promise经历过resolved之后，可能是fulfill，也可能是reject，之后生成next新的promise，传入到下一个then中，并且状态会变成pending。上面代码中第一个return，如果next为nil，那么意味着promise没有生成，这是会再调用一次mkresolvedCallback，并传入参数result，生成的PMKResolveOnQueueBlock，再次传入(q, block)，直到next的promise生成，并把pendingCallback存入到handler当中。这个handler存了所有待执行的block，如果把这个数组里面的block都执行，那么就相当于依次完成了上面的所有异步操作。第二个return是在callblock为nil的时候，还会再调一次mkresolvedCallback(result)，保证一定要生成next的promise。

这个函数里面的这里dispatch_barrier_sync这个方法，就是promise后面可以链式调用then的原因，因为GCD的这个方法，让后面then变得像一行行的then顺序执行了。

可能会有人问了，并没有看到各个block执行，仅仅只是加到handler数组里了，这个问题的答案，就是promise的核心了。promise执行block的操作是放在resove里面的。先来看看源码

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

这是一个递归函数，能形成递归的条件就是那句PMKResolve(this, o);当nextResult = nil的时候，就代表了这个promise还是pending状态，还没有被执行，这个时候就要递归调用，直到nextResult不为nil。不为nil，就会调用set方法，set方法是一个匿名函数，里面的for循环会依次循环，执行handler数组里面的每一个block。里面的那个if语句，是先判断result是否是一个promise，如果不是promise，就去执行set方法，依次调用各个block。

至此，一个then的执行原理就到此结束了。接下来我们再看看when的原理。

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

这里只截取了return的部分，理解了then，这里再看when就好理解了。when就是在传入的promises的数组里面，依次执行各个promise，结果最后传给新生成的一个promise，作为返回值返回。

这里要额外提一点的就是如果给when传入一个字典，它会如何处理的

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

方式和when的数组方式基本一样，只不过多了一步，就是从字典里面先取出promise[key]，然后再继续对这个promise执行操作而已。所以when可以传入以promise为value的字典。

## 五.使用PromiseKit优雅的处理回调地狱
这里我就举个例子，大家一起来感受感受用promise的简洁。
先描述一下环境，假设有这样一个提交按钮，当你点击之后，就会提交一次任务。首先要先判断是否有权限提交，没有权限就弹出错误。有权限提交之后，还要请求一次，判断当前任务是否已经存在，如果存在，弹出错误。如果不存在，这个时候就可以安心提交任务了。

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

上面的代码里面有3层回调，看上去就很晕，接下来我们用promise来整理一下。

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

之前将近40行代码就一下子变成15行左右，看上去比原来清爽多了，可读性更高。




## 最后
    
看完上面关于PromiseKit的使用方法之后，其实对于PromiseKit，我个人的理解它就是一个Monad（这是最近很火的一个概念，4月底在上海SwiftCon 2016中，唐巧大神分享的主题就是关于Monad，还不是很了解这个概念的可以去他博客看看，或者找视频学习学习。）Promise就是一个盒子里面封装了一堆操作，then对应的就是一组flatmap或map操作。不过缺点也还是有，如果网络用的AFNetWorking，网络请求很有可能会回调多次，这时用PromiseKit，就需要自己封装一个属于自己的promise了。PromiseKit原生的是用的OMGHTTPURLRQ这个网络框架。PromiseKit里面自带的封装的网络请求也还是基于NSURLConnection的。所以用了AFNetWorking的同学，要想再优雅的处理掉网络请求引起的回调地狱的时候，自己还是需要先封装一个自己的Promise，然后优雅的then一下。很多人可能看到这里，觉得我引入一个框架，本来是来解决问题的，但是现在还需要我再次封装才能解决问题，有点不值得。

我自己的看法是，PromiseKit是个解决异步问题很优秀的一个开源库，尤其是解决回调嵌套，回调地狱的问题，效果非常明显。虽然需要自己封装AFNetWorking的promise，但是它的思想非常值得我们学习的！这也是接下来第二篇想和大家一起分享的内容，利用promise的思想，自己来优雅的处理回调地狱！这一篇PromiseKit先分享到这里。

如有错误，还请大家请多多指教。


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_callback\_hell\_promisekit/](https://halfrost.com/ios_callback_hell_promisekit/)