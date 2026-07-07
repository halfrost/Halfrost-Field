+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Functional Reactive Programming", "FRP", "RAC", "ReactiveCocoa"]
date = 2016-07-11T01:24:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/rac_1_.png"
slug = "functional_reactive_programming_concept"
tags = ["iOS", "Functional Reactive Programming", "FRP", "RAC", "ReactiveCocoa"]
title = "Functional Reactive Programming (FRP): From Getting Started to 'Giving Up'—Basic Concepts"

+++


#### Preface  
I’ve been studying ReactiveCocoa for a while, so it’s time to summarize some of what I’ve learned.

#### I. Functional Reactive Programming  
When talking about functional reactive programming, we inevitably have to talk about functional programming. What exactly is the relationship between the two? Today we’ll analyze that relationship in detail.  
 
There are currently four concepts we need to clarify and understand how they relate to one another:  
Object Oriented Programming  
Reactive Programming  
Functional Programming  
Functional Reactive Programming

Let’s first talk about what Functional Programming is. First, let’s look at the relevant definition on [wikipedia](https://en.wikipedia.org/wiki/Functional_programming):

 >Functional Programming is a programming paradigm   
1. treats computation as the evaluation of  mathematical functions.
2. avoids changing-state and mutable data

To summarize, functional programming has the following characteristics:  
1. Functions are "first-class citizens"  
2. Closures and higher-order functions
3. No state mutation (which leads to the concept of “referential transparency”) 
4. Recursion
5. Use only "expressions", not "statements"; no side effects 

Next, let’s explain these characteristics one by one.

##### 1.  Functions Are "First-Class Citizens"   
The so-called "first class" status means that functions are on equal footing with other data types: they can be assigned to variables, passed as arguments into another function, or returned as the return value of another function.

The idea of first-class functions can be traced back to Church’s lambda calculus (Church 1941; Barendregt 1984). Since then, many (functional) programming languages, including Haskell, OCaml, Standard ML, Scala, and F#, have adopted this concept to varying degrees.

PS: The purest functional programming language in the world is undoubtedly Haskell.

##### 2. Closures and Higher-Order Functions  
A closure is an object that acts like a function and can be manipulated like an object. Similarly, functional programming languages support higher-order functions. A higher-order function can take another function (indirectly, an expression) as its input parameter, and in most cases, it can even return a function as its output. Together, these two constructs make it possible to write modular programs in an elegant way, which is one of the biggest benefits of functional programming.

##### 3. No State Mutation (Which Leads to the Concept of “Referential Transparency”)   

No state mutation:  
Functional programming only returns new values; it does not modify system variables. Therefore, not modifying variables is also one of its important characteristics. In other kinds of languages, variables are often used to store "state". Not modifying variables means state cannot be stored in variables. Functional programming uses parameters to store state; the best example is recursion. 

Avoiding program state and mutable objects is one of the effective ways to reduce program complexity, and this is also the essence of functional programming. Functional programming emphasizes the result of execution rather than the execution process. We first build a series of small, simple functions that each have some capability, and then compose these functions to implement complete logic and complex computations. This is the basic idea of functional programming.  


Referential transparency:  
Given the same input, a function always returns the same result. That is, the value of an expression does not depend on global state whose value can change. This allows you to reason formally about program behavior, because the meaning of an expression depends only on its subexpressions, not on evaluation order or the side effects of other expressions.  

This raises another question: 

Interview question: **Does a purely functional closure satisfy the functional programming property of not changing function state?**

According to the definition of a [pure function](http://en.wikipedia.org/wiki/Pure_function):
> In computer programming, a function may be described as a pure function if it satisfies the constraints of the following two statements:

> 1. Given the same argument values, the function always evaluates to the same result. The function’s result value does not depend on any hidden information or state that may change during program execution, or between two different executions of the program, nor can it depend on any external input from I/O devices (usually this is the case--see the description below).
2. Evaluation of the result does not cause any semantically observable side effects or output, such as mutation of mutable objects or output to I/O devices.

A function’s return value does not need to depend on all (or any) argument values, but it must not depend on anything other than the argument values. A function may return multiple result values, and for a function to be considered pure, these conditions must apply to all return values. If an argument is passed by reference, any internal change to that argument will change the value of the input argument outside the function, which makes the function impure.  


Returning to the question we are discussing:  

Although a closure can capture variables from outside the closure into the closure, the closure still satisfies the property of not changing state. Suppose the return value of f(x) is g(x), and g(x) returns a value based on the parameters of f(x); g(x) is equivalent to owning f(x)’s closure. At this point, it can create a mistaken impression that g(x) has captured the variables passed into f(x), thereby producing different closures. From that, one might conclude that g(x) is not purely functional because it has changed state. If we look at this issue from a higher level, functions are first-class values in functional programming and are no different from structs, integers, or booleans. Returning to the issue above, although we passed in different parameters, the overall algorithm inside the closure has not changed. For a more detailed example, f(x) returns a function g(x) that computes the square of x. Although g(x) changes each time based on the value of x passed into f(x), the overall algorithm of g(x) is to compute the square of x. This computation method does not change; it does not change based on external state. Therefore, this block g(x) satisfies the functional programming property of not changing function state. So it is also referentially transparent.

One additional point needs to be explained: the __block keyword actually breaks functional programming.

Interview question: **How should we understand referential transparency?**  

If a function is affected only by changes to its input parameters, then every invocation of that function will be the same.  
Suppose a function f(x) calls g(x), g(x) calls h(x), and h(x) ultimately computes the result, which is returned as the return value of f(x). If none of the state has changed, then the next time f(x) is called with the same parameters, it should get exactly the same result. In that case, there is actually no need to call g(x) and h(x) again; we can still obtain exactly the same result. When a function does not depend on “external” variables or state, and its final return value is affected only by changes in its input parameters—in other words, if the input parameters are the same, the returned result must be the same—then if a function has this property, we can say that the function is referentially transparent.
```objectivec    
typedef int(^intFx)(int a);

intFx transparent(intFx origin) {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    return ^int(int p) {
        if (results[@(p)]) {
            return [results[@(p)] intValue];
        }
        results[@(p)] = @(origin(p));
        return [results[@(p)] intValue];
    };
}
```   
As you can see in the example above, if `result` already contains the value we need, we will no longer invoke the callback closure. This way, when the `transparent` function is passed the same value each time, it is guaranteed to return the same result.

During the execution of a pure function, it depends only on its input parameters. The function body does not reference external global variables, or, in the case of a class method, other member variables. In addition, apart from its return value, a pure function does not modify the values of external variables. A pure function that satisfies these two conditions can be said to be referentially transparent. Some also refer to this property as **idempotence**.


##### IV. Recursion
Functional programming uses recursion as its control-flow mechanism.


##### V. Use Only "Expressions", Not "Statements"; No Side Effects

An "expression" is a pure computation process and always has a return value; a "statement" performs some operation and has no return value. Functional programming requires using only expressions and not statements. In other words, every step is a pure computation and has a return value.

The reason is that functional programming was originally motivated by handling computation, without considering system reads and writes (I/O). "Statements" are read/write operations, so they are excluded.

Functional programming emphasizes having no "side effects", meaning functions should remain independent: their entire purpose is to return a new value, with no other behavior—especially not modifying the values of external variables.


Here is an example to illustrate the difference between functional programming and imperative programming:
```objectivec    

// Imperative programming
int factorial1(int x) {
    int result = 1;
    for (int i = 1; i <= x; i ++) {
        result *= i;
    }
    return result;
}

// Functional programming
int factorial2(int x) {
    if (x == 1) return 1;
    return x * factorial2(x - 1);
}

```
The example above computes a factorial. Let’s first look at imperative programming. Imperative programming thinks about problems as if issuing commands to a machine one by one. The imperative mindset is similar to assembly: each instruction tells the computer how to handle the problem. So in imperative programming, there are many **state variables** and **statements**. In functional programming, however, the idea is to think about problems using mathematical methods. In its mathematical definition, factorial is f(n) = n _*_ f(n - 1) (n > 1), f(n) = 1 (n = 1). In functional programming, there are basically no **state variables**—only **expressions**—and there are no assignment statements. The problem is solved using recursion.

Now let’s look at the difference between imperative programming and reactive programming.
```objectivec    

void test() {
    int a = 5;
    int b = 8;
    int c = a + b;
    a = 10;
    NSLog(@"%d",c);
}
```  
In imperative programming, computation is an instantaneous operation. In reactive programming, computations react to one another: relationships exist among them, and when something changes, those relationships cause the corresponding values to change as well. Reactive programming has 2 typical examples: Excel, where when a cell changes, related cells change immediately as well. Auto Layout, where when a parent View changes, the child View’s frame also changes according to the Constraint relationships among them.

Reactive programming can also be implemented in object-oriented languages. The concrete approach should be to abstract relationships, then abstract changes, and use the relationships to propagate change events. RAC’s implementation under the Cocoa framework works this way.

Finally, let’s talk about functional reactive programming.
First, functional reactive programming definitely satisfies the characteristics of functional programming described above. Functional reactive programming is oriented around discrete event streams: discrete events are produced along a timeline, and these events are propagated downstream in order.

RAC is an implementation of functional reactive programming under the Cocoa framework. It provides composition and transformation of time-varying data streams.


Next, let’s revisit the 4 programming paradigms mentioned earlier. To summarize, if we view them as something like an inheritance hierarchy, it should look like the diagram below:  

![](https://img.halfrost.com/Blog/ArticleImage/RAC_3.png)

First, declarative programming has 2 major families: functional programming and dataflow programming. Under dataflow programming is reactive programming, while functional reactive programming “inherits” from both functional programming and reactive programming.


![](https://img.halfrost.com/Blog/ArticleImage/RAC_2.png)

Object-oriented programming belongs to the category of imperative programming. From the 2 diagrams above, we can clearly see how these 4 relate to one another.  

Interview question: **Functional programming is an upgraded version of object-oriented programming**  
Based on the explanation above, this statement is definitely wrong. The relationship is already obvious from the 2 diagrams above.
  


Interview question: **Why do functional languages advocate immutability?**    
1. Functions remain independent: all they do is return a new value, with no other behavior, especially not modifying the values of external variables. Because of this principle, we do not need to consider thread “deadlock” issues. Threads are necessarily safe with respect to one another, because they do not modify variables, so there is no issue of “locking” threads at all.  
2. Going further, functional languages tend more toward the derivation of mathematical formulas. In mathematical formulas, the concept of variables essentially does not exist. If variables also do not exist here, then the execution order of the entire program is no longer necessary. This makes it easier for us to write concurrent programs and to more efficiently leverage the computing power of multi-core CPUs.

#### II. Chained Calls  
Definition: f(x) represents a morphism, from the domain of x to the codomain of f(x). If the domain and codomain are exactly the same, this mapping is also called an identity morphism. A function that satisfies the identity morphism property can be used for chained calls.  

Taking RAC as an example, RACSignal is passed down the chain. subscribeNext returns an RACSignal, and both the domain and codomain are RACSignal. This satisfies the requirement of an identity morphism, so chained calls can continue.  

Interview question: **The necessary condition for forming chained calls is that the method returns the object itself**  

This statement is wrong. For example, every time RAC performs a signal transformation, it produces a new signal, so returning itself is not a necessary condition. In fact, as long as it returns the same type as itself, or a type similar to itself, and that type also contains methods that can continue the chain, chained calls can be formed.


#### III. Some Other Concepts About RAC
Interview question: **ReactiveCocoa is an FRP open-source library from Facebook**

Wrong. It was a byproduct of writing the GitHub client, an open-source framework developed along the way.  

Interview question: **ReactiveCocoa is an open-source library based on KVO** 

Wrong. KVO is a very minor part of RAC. You could even say that RAC could still exist without KVO. 

Interview question: **ReactiveCocoa is a purely functional programming library** 

Wrong. Because the Cocoa framework is not functional, and RAC is built under the Cocoa framework, it is not purely functional. To implement purely functional programming within the category of imperative programming languages, compromises are needed. We can encapsulate imperative programming so that it appears purely functional to upper layers, but the lower layers are definitely still implemented using imperative programming.

Finally, let’s distinguish one more concept:

Interview question: **What is the difference between Pull-driver and Push-driver in RAC?**  

Pull-driver means that at any moment, if we need data, we can take it from the pull-driver, because the data has already been stored. The timing of data retrieval is entirely controlled by the caller. A typical example is a for-in loop, which is a pull-driver operation. No matter how many times you loop or what you do in each iteration, the data in the array or dictionary always exists there, “lying” there.
Push-driver is the opposite. At any moment, when data or an event is produced, it will be pushed to you. If you do not handle it at that moment, the event or data is lost. The timing of data retrieval is not controlled by the caller.

Pull-driver can be compared to reading a book: whether or not you read it, the knowledge and text are always in the book.
Push-driver can be compared to watching TV: whether or not you watch it, the program keeps playing; if you miss it, you miss it.

In RAC, Sequence is a pull-driver, and Signal is a push-driver.  


#### To be continued……

I will periodically organize more RAC-related concepts that are difficult to understand or easy to confuse…… Feedback is welcome.