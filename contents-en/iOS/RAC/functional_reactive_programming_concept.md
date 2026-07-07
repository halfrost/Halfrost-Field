# Functional Reactive Programming (FRP) from Getting Started to "Giving Up"—Fundamental Concepts

![](https://img.halfrost.com/Blog/ArticleTitleImage/rac_1_.png)


#### Preface  
I’ve been studying ReactiveCocoa for a while, so it’s time to summarize some of what I’ve learned.

#### I. Functional Reactive Programming  
When talking about functional reactive programming, we have to mention functional programming. What exactly is the relationship between the two? Today we’ll analyze that relationship in detail.  
 
There are four concepts below whose relationships we need to clarify:  
Object Oriented Programming  
Reactive Programming  
Functional Programming  
Functional Reactive Programming

Let’s first talk about what Functional Programming is. First, let’s look at the relevant definition on [Wikipedia](https://en.wikipedia.org/wiki/Functional_programming):

 >Functional Programming is a programming paradigm   
1. treats computation as the evaluation of mathematical functions.
2. avoids changing-state and mutable data

To summarize, functional programming has the following characteristics:  
1. Functions are "first-class citizens"  
2. Closures and higher-order functions
3. No state changes (from which the concept of "referential transparency" is derived) 
4. Recursion
5. Uses only "expressions", not "statements", and has no side effects 

Next, let’s explain these characteristics one by one.

##### I. Functions are "first-class citizens"   
The so-called "first class" means that functions have the same status as other data types: they can be assigned to variables, passed as arguments to another function, or returned as the return value of another function.

The idea of first-class functions can be traced back to Church’s lambda calculus (Church 1941; Barendregt 1984). Since then, many (functional) programming languages, including Haskell, OCaml, Standard ML, Scala, and F#, have adopted this concept to varying degrees.

PS: The purest functional programming language in the world is undoubtedly Haskell.

##### II. Closures and higher-order functions  
A closure is an object that behaves like a function and can be manipulated like an object. Similarly, functional programming languages support higher-order functions. A higher-order function can take another function (indirectly, an expression) as its input parameter, and in most cases it can even return a function as its output. Combining these two constructs enables elegant modular programming, which is one of the greatest benefits of using functional programming.

##### III. No state changes (from which the concept of "referential transparency" is derived)   

No state changes:
Functional programming only returns new values and does not modify system variables. Therefore, not modifying variables is also an important characteristic. In other types of languages, variables are often used to store "state". Not modifying variables means state cannot be stored in variables. Functional programming uses parameters to preserve state, and the best example is recursion. 

Avoiding program state and mutable objects is one effective way to reduce program complexity, and this is precisely the essence of functional programming. Functional programming emphasizes the result of execution rather than the process of execution. We first build a series of small, simple functions with certain capabilities, and then compose these functions to implement complete logic and complex computations. This is the basic idea of functional programming.  


Referential transparency: 
If the same input is provided, the function always returns the same result. In other words, the value of an expression does not depend on any global state that may change. This allows you to reason formally about program behavior, because the meaning of an expression depends only on its subexpressions, not on evaluation order or the side effects of other expressions.  

This raises another question: 

Interview question: **Does a purely functional closure satisfy the functional programming property of not changing function state?**

According to the definition of a [pure function](http://en.wikipedia.org/wiki/Pure_function):
> In computer programming, a function may be described as a pure function if it satisfies the following two constraints:

> 1. Given the same argument values, the function always evaluates to the same result. The result value of the function does not depend on any hidden information or state that may change during program execution or between different executions of the program, nor can it depend on any external input from I/O devices (usually so—see the description below).
2. Evaluation of the result does not cause any semantically observable side effects or output, such as changes to mutable objects or output to I/O devices.

A function’s return value does not have to depend on all (or any) argument values, but it must not depend on anything other than the argument values. A function may return multiple result values, and for a function to be considered pure, these conditions must apply to all return values. If an argument is passed by reference, any internal change to the argument will change the input argument value outside the function, which makes the function impure.  


Returning to the question we are discussing:  

Although a closure can capture variables outside the closure into its body, the closure still satisfies the property of not changing state. Suppose the return value of f(x) is g(x), and g(x) depends on the parameters of f(x) to return its result; g(x) effectively has the closure of f(x). At this point, it is easy to get the mistaken impression that g(x) captures the input variables of f(x), thereby producing different closures, and to conclude that g(x) is not purely functional because it changes state. If we look at this from a higher level, functions are first-class values in functional programming and are no different from structs, integers, or Booleans. Returning to the problem above: although we pass in different parameters, the overall algorithm inside the closure does not change. For a more concrete example, f(x) returns a function g(x) that computes the square of x. Although g(x) changes each time according to the value of x passed into f(x), the overall algorithm of g(x) is to compute the square of x. This computation method does not change and is not affected by external state. Therefore, this block of g(x) satisfies the functional programming property of not changing function state. So it is also referentially transparent.

One additional point to note: __block actually breaks functional programming.

Interview question: **How should we understand referential transparency?**  

If a function is affected only by changes to its input parameters, then every call to that function will be the same.
Suppose there is a function f(x), which calls g(x), and g(x) calls h(x). h(x) eventually computes a result, which is returned as the return value of f(x). If no state has changed, then the next time f(x) is called with the same parameters, it should produce exactly the same result. In that case, there is actually no need to call g(x) and h(x) again; the exact same result can still be obtained. When a function does not depend on "external" variables or state, and its final return value is affected only by changes in its input parameters—that is, given the same input parameters, the returned result must be the same—then the function can be said to be referentially transparent.
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
In the example above, you can see that if result already contains the value we need, we will no longer invoke the callback closure. In this way, when the transparent function is passed the same value each time, it is guaranteed to return the same result.

During execution, a pure function depends only on its input parameters. Its function body does not reference external global variables, or, in the case of a class method, other member variables. In addition, aside from its return value, a pure function does not change the values of external variables. A pure function that satisfies these two conditions can be said to be referentially transparent. Some also call this property **idempotency**.


##### IV. Recursion 
Functional programming uses recursion as its control-flow mechanism.


##### V. Use Only "Expressions", Not "Statements", and Have No Side Effects 

An "expression" is a pure computation process and always has a return value; a "statement" performs some kind of operation and has no return value. Functional programming requires using only expressions, not statements. In other words, every step is a pure computation, and every step has a return value.
The reason is that the original motivation for functional programming was to handle computation, without considering system reads and writes (I/O). "Statements" belong to read/write operations, so they are excluded. 
Functional programming emphasizes having no "side effects", which means functions should remain independent: all they do is return a new value, with no other behavior—especially not modifying the values of external variables.  


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
The example above is a factorial calculation. Let’s first look at imperative programming. Imperative programming approaches problems like a machine executing commands one by one. The imperative mindset is similar to assembly: each instruction tells the computer how to handle the problem. So in imperative programming, there are many **state variables** and **statements**. In functional programming, by contrast, the idea is to think about problems using mathematical methods. In mathematics, factorial is defined as f(n) = n _*_ f(n - 1) (n > 1), f(n) = 1 (n = 1). In functional programming, there are basically no **state variables**—only **expressions**—and no assignment statements. The problem is solved using recursion.

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
In imperative programming, computation is an instantaneous operation. In reactive programming, computations respond to one another and are related to one another: when something changes, those relationships cause the corresponding values to change as well. There are two typical examples of reactive programming: Excel—when a cell changes, related cells change immediately as well. Auto Layout—when the parent View changes, the child View’s frame also changes according to the relationships between them, i.e. Constraints.

Reactive programming can also be implemented in object-oriented languages. The specific approach is to abstract out the relationships, then abstract out the changes, and use those relationships to propagate change events onward. This is exactly how RAC is implemented under the Cocoa framework.

Finally, let’s talk about functional reactive programming.
First, functional reactive programming certainly satisfies the characteristics of functional programming described above. Functional reactive programming is oriented around discrete event streams: on a timeline, discrete events are produced, and these events are passed downstream in sequence.

RAC is an implementation of functional reactive programming under the Cocoa framework. It provides composition and transformation of data streams that change over time.


Next, let’s revisit the four programming paradigms mentioned earlier. To summarize, if we look at them as something like an inheritance diagram, it should look like this:  

![](https://img.halfrost.com/Blog/ArticleImage/RAC_3.png)

First, declarative programming has two major families: functional programming and dataflow programming. Under dataflow programming is reactive programming, while functional reactive programming “inherits” from both functional programming and reactive programming.


![](https://img.halfrost.com/Blog/ArticleImage/RAC_2.png)

Object-oriented programming belongs to the category of imperative programming. From the two diagrams above, we can clearly see how these four relate to one another.  

Interview question: **Functional programming is an upgraded version of object-oriented programming**  
Based on the explanation above, this statement is definitely wrong. The relationship is already clear from the two diagrams above.
  


Interview question: **Why do functional languages advocate immutability?**    
1. Functions remain independent: all they do is return a new value, with no other behavior, especially not modifying the values of external variables. Because of this principle, we do not need to worry about thread “deadlock” issues. Threads are necessarily safe with respect to one another, because they do not modify variables, so the problem of “locking” threads fundamentally does not exist.  
2. Furthermore, functional languages are more inclined toward derivation in the style of mathematical formulas. In mathematical formulas, the concept of variables actually does not exist at all. If variables no longer exist, then the execution order of the entire program is not really necessary either. This makes it easier for us to do concurrent programming and to use the computing power of multi-core CPUs more efficiently.

#### II. Method Chaining  
Definition: f(x) represents a morphism from the domain of x to the codomain of f(x). If the domain and codomain are exactly the same, this mapping is also called an endomorphism. A function that satisfies the endomorphism property can be chained.  

Taking RAC as an example, if RACSignal is passed along in a chain, subscribeNext returns an RACSignal. Both the domain and codomain are RACSignal, so it satisfies the requirement of an endomorphism and can continue to be chained.  

Interview question: **A necessary condition for method chaining is that the method returns the object itself**  

This statement is wrong. For example: every time RAC performs a signal transformation, it creates a new signal, so returning itself is not a necessary condition. In fact, as long as it returns an object of the same type as itself, or a type similar to itself, and that type also contains methods that can continue the chain, method chaining can be formed.


#### III. Other Concepts About RAC
Interview question: **ReactiveCocoa is an FRP open-source library from Facebook**

Wrong. It was a byproduct of building the GitHub client, an open-source framework developed along the way.  

Interview question: **ReactiveCocoa is an open-source library based on KVO** 

Wrong. KVO is a very minor part of RAC. You could even say that RAC would still exist without KVO. 

Interview question: **ReactiveCocoa is a purely functional programming library** 

Wrong. Since the Cocoa framework itself is not functional, and RAC is built under the Cocoa framework, it is not purely functional. To implement purely functional programming within the category of imperative programming languages, a compromise is needed: we can encapsulate imperative programming so that it appears purely functional to the upper layers, but the lower layers are definitely still implemented using imperative programming.

Finally, let’s distinguish one more concept:

Interview question: **What is the difference between Pull-driver and Push-driver in RAC?**  

Pull-driver means that at any moment, if we need data, we can take data from the pull-driver, because the data has already been stored. The timing of data retrieval is entirely controlled by the caller. A typical example is a for-in loop, which is a pull-driver operation. No matter how many times you loop, and no matter what you do in each iteration, the data in the array or dictionary always exists there, “lying” there.
Push-driver is the opposite. At any moment, when data or an event is produced, it will be pushed to you. If you do not handle it at that time, the event or data is lost. The timing of data retrieval is not controlled by the caller.

Pull-driver can be compared to reading a book: whether you read it or not, the knowledge and words are always in the book.
Push-driver can be compared to watching TV: whether you watch it or not, the program keeps playing; if you miss it, you miss it.

In RAC, Sequence is a pull-driver, and Signal is a push-driver.  


#### To Be Continued...

I will periodically organize more hard-to-understand and easily confused RAC-related concepts here... Feedback is welcome.