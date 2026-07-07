# How iOS Can Elegantly Handle “Callback Hell” (Part 2) — Using Swift


![](http://upload-images.jianshu.io/upload_images/1194012-a590ae3efef185d3.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####Preface
In the previous article, I discussed how promises can be used to solve the problem of callback hell. In this article, we’ll use a different approach to solve the same problem.

First, let’s analyze why promises can solve the problem of deeply nested callbacks. Based on the analysis in the previous article, I’ve summarized the following points:

1.A promise encapsulates all asynchronous operations, wrapping them in a “box”.
2.A promise provides a Monad; `then` is equivalent to `flatMap`.
3.A promise function returns the object itself, enabling chained calls.

All right, since these capabilities can elegantly solve callback hell, as long as we can achieve the same things, we can accomplish the task as well. At this point, you may already have realized it: Swift is the best language for this job! Swift supports functional programming, so implementing the basic capabilities of promises can be done in no time.

####I.Using Swift Features to Handle Callback Hell  


We’ll still use the example from the previous article. First, let’s describe the scenario:
Suppose there is a submit button. When you tap it, a task is submitted. The moment you tap the button, you first need to determine whether the user has permission to submit. If not, an error is displayed. After confirming that the user has permission, you also need to make a request to determine whether the current task already exists. If it does, an error is displayed. If it does not, the task can then be submitted safely.

The code is as follows:
```
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
Next, let's elegantly solve the seemingly hard-to-maintain Callback hell described above.

1. First, we need to encapsulate the asynchronous operation in Async, and also wrap the return value as Result.
```

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
2. Wrap it as a Monad, providing Map and flatMap operations. Also return Async as the return value so subsequent chained calls remain convenient.
```
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
Here we encapsulate the asynchronous process into a box. Inside the box, there are `Map` and `flatMap` operations, and `flatMap` essentially corresponds to `then` in a promise.

3. We can directly rename `flatMap` to `then`, so the previous 30-plus lines of code can be simplified to the following:
```

func requestAsyncOperation(request : String ) -> Async <String>
{
    return fetchDataAPI(request)
           .then(fetchOtherDataAPI)
           .map(transformResult)
           .then(fetchOtherDataAPI)
           .map(transformTaskResult)
}
```
Basically, this achieves the same effect as using a promise. This way, there is no need for the PromiseKit library; by leveraging the essence of the promise concept, callback hell is handled elegantly and perfectly. This is also thanks to the strengths of the Swift language.


At this point, although the problem has already been solved, we are not done yet. We can continue to discuss a few things further.


####II. Further Discussion
1. The `@noescape`, `throws`, and `rethrows` keywords
`flatMap` can also be written like this:
```
func flatMap<U> (@noescape f: T throws -> Async<U>)rethrows -> Async<U> 
```
Judging by the literal meaning of `@noescape`, it means “will not escape.” This keyword is specifically used to modify parameters of the closure function type. When this parameter appears, it indicates that the closure will not outlive the lifetime of the function call: once the function call completes, the closure’s lifetime also ends.

Apple’s official documentation describes it as follows:

>A new @noescape attribute may be used on closure parameters to functions. This indicates that the parameter is only ever called (or passed as an @noescape parameter in a call), which means that it cannot outlive the lifetime of the call. This enables some minor performance optimizations, but more importantly disables the self. requirement in closure arguments.

So when would a closure parameter outlive the lifetime of a function?

Quoting Tang Qiao’s explanation:

>Within the function implementation, wrap a closure inside `dispatch_async`. In this way, the closure will exist on another thread, thereby escaping the lifetime of the current function. The main purpose of doing this is to help the compiler perform performance optimizations.

The `throws` keyword indicates that the closure may throw an exception.

The `rethrows` keyword indicates that if this closure throws an exception, it can only be due to an exception thrown by a closure passed to it.

2. Continuing with the `Result` in the example above: as with `Async`, we can also further wrap `Result` and add `map` and `flatMap` methods to it.
```

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
3. Above, we already wrapped `Async` and `Result` with a `map` method, so they can also be called **functors (Functor)**. Next, we can continue wrapping them into **applicative functors (Applicative Functor)** and **monads (Monad)**.

By definition, an **applicative functor (Applicative Functor)** is:
For any functor F, if it can support the following operations, then that functor is an applicative functor:
```
func pure<A>(value:A) ->F<A>

func <*><A,B>(f:F<A - > B>, x:F<A>) ->F<B>
```
Using `Async` as an example, we add these two methods to it.
```

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
unit and apply are the two methods in the definition above. Next, let’s look at the definition of Monad.

By definition, a **Monad** is:
For any type constructor F, if the following two functions are defined for it, then it is a Monad:
```
func pure<A>(value:A) ->F<A>

func flatMap<A,B>(x:F<A>)->(A->F<B>)->F<B>
```
Still using Async as an example: at this point, Async already has `unit` and `flatMap`, satisfying the definition. So we can say that Async is already a Monad.

At this point, we have made both Async and Result into **Applicative Functors** and **Monads**.

4.Now let’s talk about operators.
The `flatMap` function is sometimes defined as an operator, `>>=`. Because it binds the computation result of the first argument to the input of the second argument, this operator is also called the “bind” operation.

For convenience, let’s define all four operations above as operators.
```
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
In order, the second corresponds to the original map function, and the third corresponds to the original flatMap function.


5.Speaking of operators, we can now go back to the beginning of the article and discuss that callback hell code. Above, we successfully unfolded Callback hell using map and flatMap. In fact, there is another way to solve the problem here: using custom operators. We do not need the applicative functor's <*> here, though some problems may require it. Returning to the problem above, we will use the operators in Monad to solve callback hell.
```

func requestAsyncOperation(request : String ) -> Async <String>
{
    return fetchDataAPI(request) >>= (fetchOtherDataAPI) <^>(transformResult) >>= (fetchOtherDataAPI) <^> (transformTaskResult)
}
```
With operators, the original 40-plus lines of code ultimately became just the final line! Of course, we encapsulated some operations along the way.

####III. Summary
After the discussion in the previous article and this one, there are several ways to elegantly handle "Callback hell":
1.Use PromiseKit
2.Use Swift’s map and flatMap to encapsulate asynchronous operations (the idea is quite similar to promises)
3.Use Swift custom operators to unfold nested callbacks

So far, I can think of two more approaches:
4.Use Reactive Cocoa
5.Use RxSwift

The next article, or the one after that, will probably discuss how RAC and RxSwift can elegantly handle callback hell. If anyone has other approaches that can elegantly solve this problem, feel free to bring them up so we can discuss and learn from each other!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_callback\_hell\_swift/](https://halfrost.com/ios_callback_hell_swift/)