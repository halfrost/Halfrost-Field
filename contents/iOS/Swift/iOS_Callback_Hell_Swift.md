# iOS如何优雅的处理“回调地狱Callback hell”(二)——使用Swift

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleTitleImage/13_0_.png">
</p> 





## 前言
在上篇中，我谈到了可以用promise来解决Callback hell的问题，这篇我们换一种方式一样可以解决这个问题。

我们先分析一下为何promise能解决多层回调嵌套的问题，经过上篇的分析，我总结也一下几点：

1.promise封装了所有异步操作，把异步操作封装成了一个“盒子”。
2.promise提供了Monad，then相当于flatMap。
3.promise的函数返回对象本身，于是就可形成链式调用

好了，既然这些能优雅的解决callback hell，那么我们只要能做到这些，也一样可以完成任务。到这里大家可能就已经恍然大悟了，Swift就是完成这个任务的最佳语言！Swift支持函数式编程，分分钟就可以完成promise的基本功能。

## 一.利用Swift特性处理回调Callback hell  


我们还是以上篇的例子来举例，先来描述一下场景：
假设有这样一个提交按钮，当你点击之后，就会提交一次任务。当你点下按钮的那一刻，首先要先判断是否有权限提交，没有权限就弹出错误。有权限提交之后，还要请求一次，判断当前任务是否已经存在，如果存在，弹出错误。如果不存在，这个时候就可以安心提交任务了。

那么代码如下：
```swift  
func requestAsyncOperation(request : String , success : String -> Void , failure : NSError -> Void)
{
    WebRequestAPI.fetchDataAPI(request, success : { result in
        WebOtherRequestAPI.fetchOtherDataAPI ( result ,  success : {OtherResult in
            [self fulfillData:OtherResult];
            
            let finallyTheParams = self.transformResult(OtherResult)
            TaskAPI.fetchOtherDataAPI ( finallyTheParams , success : { TaskResult in
                
                let finallyTaskResult = self.transformTaskResult(TaskResult)
                
                success(finallyTaskResult)
                },
                failure:{ TaskError in
                    failure(TaskError)
                }
                
            )
            },failure : { ExistError in
                failure(ExistError)
            }
        )
        } , failure : { AuthorityError in
            failure(AuthorityError)
        }
    )
}
```

接下来我们就来优雅的解决上述看上去不好维护的Callback hell。

1.首先我们要封装异步操作，把异步操作封装到Async中，顺带把返回值也一起封装成Result。
```swift  

enum Result <T> {
    case Success(T)
    case Failure(ErrorType)
}

struct Async<T> {
    let trunk:(Result<T>->Void)->Void
    init(function:(Result<T>->Void)->Void) {
        trunk = function
    }
    func execute(callBack:Result<T>->Void) {
        trunk(callBack)
    }
}

```

2.封装Monad，提供Map和flatMap操作。顺带返回值也返回Async，以方便后面可以继续链式调用。
```swift  
// Monad
extension Async{


    func map<U>(f: T throws-> U) -> Async<U> {
        return flatMap{ .unit(try f($0)) }
    }

    func flatMap<U>(f:T throws-> Async<U>) -> Async<U> {
        return Async<U>{ cont in
            self.execute{
                switch $0.map(f){
                case .Success(let async):
                    async.execute(cont)
                case .Failure(let error):
                    cont(.Failure(error))
                }
            }
        }
    }
}
```
这是我们把异步的过程就封装成一个盒子了，盒子里面有Map，flatMap操作，flatMap对应的其实就是promise的then

3.我们可以把flatMap名字直接换成then，那么之前那30多行的代码就会简化成下面这样：
```swift  

func requestAsyncOperation(request : String ) -> Async <String>
{
    return fetchDataAPI(request)
           .then(fetchOtherDataAPI)
           .map(transformResult)
           .then(fetchOtherDataAPI)
           .map(transformTaskResult)
}
```
基本上和用promise一样的效果。这样就不用PromiseKit库，利用promise思想的精髓，优雅的完美的处理了回调地狱。这也得益于Swift语言的优点。


文章至此，虽然已经解决了问题了，不过还没有结束，我们还可以继续再进一步讨论一些东西。



## 二.进一步的讨论
1.@noescape，throws，rethrows关键字
flatMap还有这种写法：

```swift  
func flatMap<U> (@noescape f: T throws -> Async<U>)rethrows -> Async<U> 
```

@noescape 从字面上看，就知道是“不会逃走”的意思，这个关键字专门用于修饰函数闭包这种参数类型的，当出现这个参数时，它表示该闭包不会跳出这个函数调用的生命期：即函数调用完之后，这个闭包的生命期也结束了。
在苹果官方文档上是这样写的：
>A new @noescape attribute may be used on closure parameters to functions. This indicates that the parameter is only ever called (or passed as an @noescape parameter in a call), which means that it cannot outlive the lifetime of the call. This enables some minor performance optimizations, but more importantly disables the self. requirement in closure arguments.

那什么时候一个闭包参数会跳出函数的生命期呢？

引用唐巧大神的解释：
>在函数实现内，将一个闭包用 dispatch_async
嵌套，这样这个闭包就会在另外一个线程中存在，从而跳出了当前函数的生命期。这样做主要是可以帮助编译器做性能的优化。


throws关键字是代表该闭包可能会抛出异常。
rethrows关键字是代表这个闭包如果抛出异常，仅可能是因为传递给它的闭包的调用导致了异常。

2.继续说说上面例子里面的Result，和Async一样，我们也可以继续封装Result，也加上map和flatMap方法。

```swift  

func ==<T:Equatable>(lhs:Result<T>, rhs:Result<T>) -> Bool{
    if case (.Success(let l), .Success(let r)) = (lhs, rhs){
        return l == r
    }
    return false
}

extension Result{

    func map<U>(f:T throws-> U) -> Result<U> {
        return flatMap{.unit(try f($0))}
    }

    func flatMap<U>(f:T throws-> Result<U>) -> Result<U> {
        switch self{
        case .Success(let value):
            do{
                return try f(value)
            }catch let e{
                return .Failure(e)
            }
        case .Failure(let e):
            return .Failure(e)
        }
    }
}
```

3.上面我们已经把Async和Result封装了map方法，所以他们也可以叫做**函子(Functor)**。接下来可以继续封装，把他们都封装成**适用函子(Applicative Functor)**和**单子(Monad)**

**适用函子(Applicative Functor)**根据定义：  

对于任意一个函子F，如果能支持以下运算，该函子就是一个适用函子：

```swift  
func pure<A>(value:A) ->F<A>

func <*><A,B>(f:F<A - > B>, x:F<A>) ->F<B>
```

以Async为例，我们为它加上这两个方法

```swift  

extension Async{

    static func unit(x:T) -> Async<T> {
        return Async{ $0(.Success(x)) }
    }

    func map<U>(f: T throws-> U) -> Async<U> {
        return flatMap{ .unit(try f($0)) }
    }

    func flatMap<U>(f:T throws-> Async<U>) -> Async<U> {
        return Async<U>{ cont in
            self.execute{
                switch $0.map(f){
                case .Success(let async):
                    async.execute(cont)
                case .Failure(let error):
                    cont(.Failure(error))
                }
            }
        }
    }

    func apply<U>(af:Async<T throws-> U>) -> Async<U> {
        return af.flatMap(map)
    }
}
```

unit和apply就是上面定义中的两个方法。接下来我们在看看Monad的定义。

**单子(Monad)**根据定义：  
对于任意一个类型构造体F定义了下面两个函数，它就是一个单子Monad：

```swift  
func pure<A>(value:A) ->F<A>

func flatMap<A,B>(x:F<A>)->(A->F<B>)->F<B>
```

还是以Async为例，此时的Async已经有了unit和flatMap满足定义了，这个时候，就可以说Async已经是一个Monad了。

至此，我们就把Async和Result都变成了**适用函子(Applicative Functor)**和**单子(Monad)**了。

4.再说说运算符。
flatMap函数有时候会被定义为一个运算符>>=。由于它会将第一个参数的计算结果绑定到第二个参数的输入上面，这个运算符也会被称为“绑定(bind)”运算.

为了方便，那我们就把上面的4个操作都定义成运算符吧。

```swift  
func unit<T> (x:T) -> Async<T> {
    return Async{$0(.Success(x))}
}

func <^> <T, U> (f: T throws-> U, async: Async<T>) -> Async<U> {
    return async.map(f)
}

func >>= <T, U> (async:Async<T>, f:T throws-> Async<U>) -> Async<U> {
    return async.flatMap(f)
}

func <*> <T, U> (af: Async<T throws-> U>, async:Async<T>) -> Async<U> {
    return async.apply(af)
}
```
按照顺序，第二个对应的就是原来的map函数，第三个对应的就是原来的flatMap函数。


5.说到运算符，我们这里还可以继续回到文章最开始的地方去讨论一下那段回调地狱的代码。上面我们通过map和flatMap成功的展开了Callback hell，其实这里还有另外一个方法可以解决问题，那就是用自定义运算符。这里我们用不到适用函子的<*>，有些问题就可能用到它。还是回到上述问题，这里我们用Monad里面的运算符来解决回调地狱。

```swift  

func requestAsyncOperation(request : String ) -> Async <String>
{
    return fetchDataAPI(request) >>= (fetchOtherDataAPI) <^>(transformResult) >>= (fetchOtherDataAPI) <^> (transformTaskResult)
}
```

通过运算符，最终原来的40多行代码变成了最后一行了！当然，我们中间封装了一些操作。

## 三.总结

经过上篇和本篇的讨论，优雅的处理"回调地狱Callback hell"的方法有以下几种:  
1.使用PromiseKit
2.使用Swift的map和flatMap封装异步操作(思想和promise差不多)
3.使用Swift自定义运算符展开回调嵌套

目前为止，我能想到的处理方法还有2种：  
4.使用Reactive cocoa
5.使用RxSwift

下篇或者下下篇可能应该就是讨论RAC和RxSwift如果优雅的处理回调地狱了。如果大家还有什么其他方法能优雅的解决这个问题，也欢迎大家提出来，一起讨论，相互学习！


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_callback\_hell\_swift/](https://halfrost.com/ios_callback_hell_swift/)