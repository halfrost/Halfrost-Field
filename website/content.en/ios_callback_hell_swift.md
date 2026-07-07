+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Callback hell", "回调地狱", "Swift"]
date = 2016-06-22T06:45:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/13_0_.png"
slug = "ios_callback_hell_swift"
tags = ["iOS", "Callback hell", "回调地狱", "Swift"]
title = "How to Elegantly Handle “Callback Hell” in iOS (Part 2) — Using Swift"

+++


#### Preface
In the previous article, I talked about how `promise` can be used to solve the problem of Callback hell. In this article, we’ll use another approach to solve the same problem.

Let’s first analyze why `promise` can solve the problem of deeply nested callbacks. Based on the analysis in the previous article, I’ve summarized the following points:

1. `promise` encapsulates all asynchronous operations, packaging them into a “box”.
2. `promise` provides a Monad; `then` is equivalent to `flatMap`.
3. `promise` functions return the object itself, which enables chained calls.

Alright, since these capabilities can elegantly solve callback hell, as long as we can achieve the same things, we can complete the task as well. At this point, you may have already realized it: Swift is the best language for this task! Swift supports functional programming, so implementing the basic functionality of `promise` can be done in no time.

#### 1. Using Swift Features to Handle Callback Hell

Let’s still use the example from the previous article. First, let’s describe the scenario:

Suppose there is a submit button. When you click it, a task is submitted. At the moment you press the button, you first need to determine whether the user has permission to submit. If not, an error is displayed. After permission is confirmed, another request is made to determine whether the current task already exists. If it does, an error is displayed. If it does not, the task can then be submitted with confidence.

The code is as follows:
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
Next, let's elegantly solve the callback hell described above, which looks hard to maintain.

1. First, we need to encapsulate asynchronous operations: wrap the asynchronous operation in Async, and, while we’re at it, wrap the return value as Result.
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
2. Wrap it as a Monad, providing Map and flatMap operations. Have the return value be Async as well, so subsequent calls can be chained conveniently.
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
This encapsulates the asynchronous process into a box. Inside the box, there are Map and flatMap operations; flatMap is essentially equivalent to a Promise’s then.

3. We can rename flatMap directly to then, and the 30+ lines of code from earlier can be simplified to the following:
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
The effect is basically the same as using promises. This way, you don’t need the PromiseKit library; by leveraging the essence of the promise concept, you can handle callback hell elegantly and perfectly. This is also thanks to the advantages of the Swift language.

At this point in the article, although the problem has already been solved, we’re not done yet. We can continue to discuss a few things in more depth.


####II. Further Discussion
1. The @noescape, throws, and rethrows keywords
flatMap can also be written like this:
```swift  
func flatMap<U> (@noescape f: T throws -> Async<U>)rethrows -> Async<U> 
```
`@noescape` literally means “will not escape.” This keyword is specifically used to annotate closure parameter types. When this parameter appears, it indicates that the closure will not escape the lifetime of the function call: once the function call completes, the closure’s lifetime also ends.

Apple’s official documentation describes it as follows:

>A new @noescape attribute may be used on closure parameters to functions. This indicates that the parameter is only ever called (or passed as an @noescape parameter in a call), which means that it cannot outlive the lifetime of the call. This enables some minor performance optimizations, but more importantly disables the self. requirement in closure arguments.

So when would a closure parameter escape the lifetime of a function?

Quoting Tang Qiao’s explanation:

>Within the function implementation, wrap a closure in `dispatch_async`. This way, the closure will exist on another thread, thereby escaping the lifetime of the current function. The main purpose of doing this is to help the compiler perform performance optimizations.

The `throws` keyword means that the closure may throw an exception.

The `rethrows` keyword means that if this closure throws an exception, it can only be because calling a closure passed to it caused the exception.

2. Continuing with `Result` in the example above: as with `Async`, we can also further wrap `Result` and add `map` and `flatMap` methods.
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
3. Above, we have already encapsulated the map method for Async and Result, so they can also be called **Functors**. Next, we can continue encapsulating them as **Applicative Functors** and **Monads**.

By definition, an **Applicative Functor** is:  
For any functor F, if it supports the following operations, then that functor is an applicative functor:
```swift  
func pure<A>(value:A) ->F<A>

func <*><A,B>(f:F<A - > B>, x:F<A>) ->F<B>
```
Using `Async` as an example, we add these two methods to it.
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
unit and apply are the two methods in the definition above. Next, let’s look at the definition of Monad.

**Monad** by definition:  
For any type constructor F, if the following two functions are defined, then it is a Monad:
```swift  
func pure<A>(value:A) ->F<A>

func flatMap<A,B>(x:F<A>)->(A->F<B>)->F<B>
```
Still using `Async` as an example: at this point, `Async` already has `unit` and `flatMap` and therefore satisfies the definition. We can now say that `Async` is a `Monad`.

At this point, we have turned both `Async` and `Result` into **Applicative Functors** and **Monads**.

4. Now let’s talk about operators.

The `flatMap` function is sometimes defined as an operator, `>>=`. Because it binds the result of the first argument’s computation to the input of the second argument, this operator is also called the “bind” operation.

For convenience, let’s define all four operations above as operators.
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
In order, the second one corresponds to the original map function, and the third one corresponds to the original flatMap function.


5. Speaking of operators, we can also return to the callback-hell code from the beginning of the article. Above, we successfully flattened Callback hell using map and flatMap, but there is actually another way to solve the problem: using a custom operator. We do not need the Applicative functor’s <*> here, though some problems may require it. Returning to the problem above, we will use the operators in Monad to solve callback hell.
```swift  

func requestAsyncOperation(request : String ) -> Async <String>
{
    return fetchDataAPI(request) >>= (fetchOtherDataAPI) <^>(transformResult) >>= (fetchOtherDataAPI) <^> (transformTaskResult)
}
```
Through operators, the original 40-plus lines of code were ultimately reduced to a single final line! Of course, we encapsulated some operations along the way.

####III. Summary
After the discussion in the previous article and this one, there are several elegant ways to handle "Callback hell":  
1.Use PromiseKit
2.Use Swift’s map and flatMap to encapsulate asynchronous operations (the idea is similar to promises)
3.Use custom Swift operators to flatten nested callbacks

So far, I can think of two other approaches:  
4.Use Reactive Cocoa
5.Use RxSwift

The next article, or the one after that, will probably discuss how RAC and RxSwift can elegantly handle callback hell. If anyone has other ways to solve this problem elegantly, feel free to bring them up so we can discuss and learn from each other!