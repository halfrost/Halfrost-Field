+++
author = "一缕殇流化隐半边冰霜"
categories = ["JavaScript"]
date = 2017-05-25T00:16:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/48_0_.png"
slug = "javascript_scope"
tags = ["JavaScript"]
title = "Starting with JavaScript Scope"

+++


### Table of Contents

- 1. Static Scope and Dynamic Scope
- 2. Variable Scope
- 3. Variable Scope in JavaScript
- 4. JavaScript Scope Cheating
- 5. JavaScript Execution Context
- 6. Scope Chains in JavaScript
- 7. Closures in JavaScript
- 8. Modules in JavaScript


### I. Static Scope and Dynamic Scope

In computer programming, **scope** is the portion of a computer program in which the binding between a name and an entity remains valid. Different programming languages may have different scoping and name-resolution rules. Even within the same language, multiple kinds of scope may exist, varying by the type of entity. The **scope category** affects how variables are bound; depending on whether a language uses **static scope** or **dynamic scope**, evaluating a variable may produce different results.

- Contains declarations or definitions of identifiers;  
- Contains statements and/or expressions that define, or partially define, an executable algorithm;
- Is nested or is nested within another construct.

A [namespace](https://zh.wikipedia.org/wiki/%E5%91%BD%E5%90%8D%E7%A9%BA%E9%97%B4) is a kind of scope that uses the encapsulation property of scope to logically group a set of related identifiers under a single identifier. Therefore, **scope** can affect the [name resolution](https://zh.wikipedia.org/w/index.php?title=%E5%90%8D%E5%AD%97%E8%A7%A3%E6%9E%90&action=edit&redlink=1) of these entities.
Programmers often [indent](https://zh.wikipedia.org/w/index.php?title=%E7%B8%AE%E6%8E%92&action=edit&redlink=1) **scopes** in their [source code](https://zh.wikipedia.org/wiki/%E5%8E%9F%E5%A7%8B%E7%A2%BC) to improve readability.

Scope is further divided into two types: static scope and dynamic scope.

**Static scope** is also called lexical scope, and variables that use lexical scope are called **lexical variables**. A lexical variable has a scope that is determined statically at compile time. The scope of a lexical variable can be a function or a block of code; the variable is visible within that region of code, and is not visible (or cannot be accessed) outside that region. Under lexical scope, when retrieving a variable’s value, the textual environment at the time the function was defined is examined, capturing the binding of that variable at function definition time.
```javascript


function f() {
    function g() {
  }
}


```
Static (lexical) scope means that you can understand how a program works purely from its source code, without executing it. From the example above, it is clear that function g is enclosed inside function f.

Most modern programming languages use static scoping rules, such as C/C++, C#, Python, Java, JavaScript, and so on.

By contrast, variables that use **dynamic scope** are called **dynamic variables**. As long as the program is executing the code segment in which a dynamic variable is defined, that variable continues to exist; once the code segment finishes executing, the variable disappears. This means that if there is a function f that calls function g, then while g is executing, all local variables in f can be accessed by g. Under static scope, however, g cannot access f’s variables. With dynamic scope, when retrieving the value of a variable, the runtime checks the function call chain layer by layer from the inside out, and uses the value of the first binding it encounters. Clearly, the outermost binding is the value in the global state.
```javascript

function g() {
}

function f() {
   g()；
}


```
When we call f(), it calls g(). During execution, the fact that g is called by f represents a dynamic relationship.

Languages that use dynamic scope include Pascal, Emacs Lisp, Common Lisp (which also has static scope), and Perl (which also has static scope). C/C++ are statically scoped languages, but names used in macros are also dynamically scoped.


### II. Variable Scope

#### 1. Variable Scope

A variable’s scope refers to where the variable can be accessed. For example:
```javascript

function foo（）{
    var bar;
}

```
Here, the immediate scope of `bar` is the function scope `foo()`;


#### 2. Lexical Scope

Variables in JavaScript all have static (lexical) scope. Therefore, the static structure of a program determines the scope of a variable, and that scope is not changed by the position of the function.


#### 3. Nested Scope

If multiple scopes are nested within a variable’s immediate scope, then that variable can be accessed from all of those scopes:
```javascript

function foo (arg) {
    function bar() {
        console.log( 'arg:' + arg );
    }
    bar();
}

console.log(foo('hello'));   // arg:hello

```
The immediate scope of `arg` is `foo()`, but it can also be accessed in the nested scope `bar()`. `foo()` is the outer scope, and `bar()` is the inner scope.


#### 4. Shadowed Scope

If a variable is declared in a scope with the same name as a variable in an outer scope, then the outer variable cannot be accessed within this inner scope or any scopes nested inside it. Changes to the inner variable do not affect the outer variable. Once execution leaves the inner scope, the outer variable becomes accessible again.
```javascript

var x = "global"；

function f() {
   var x = "local"；
   console.log(x);   // local
}

f();
console.log(x);  // global


```
This is the scope of shadowing.

### III. Variable Scope in JavaScript

Most mainstream languages have block scope: variables exist within the nearest code block. Objective-C and Swift both use block scope. In JavaScript, however, variables have function scope. That said, with the addition of the `let` and `const` keywords in the latest ES6, JavaScript effectively gained support for block scope. After ES6, the constructs that support block scope include the following:

1. **The `with` statement**
The scope created from an object using `with` is valid only within the `with` statement, not in the outer scope.
2. **The `try/catch` statement**
The JavaScript ES3 specification states that the `catch` clause of `try/catch` creates a block scope, where variables declared inside it are valid only within the `catch` block.
3. **The `let` keyword**
The `let` keyword can bind a variable to any enclosing scope (usually inside `{ .. }`). In other words, `let` implicitly binds the declared variable to the block scope in which it appears.
4. **The `const` keyword**
In addition to `let`, ES6 also introduced `const`, which can likewise be used to create block-scoped variables, but whose value is fixed (a constant). Any subsequent attempt to modify the value will result in an error.

One thing to be aware of here is variable and function hoisting. This issue was covered in detail in the previous article, so it will not be repeated here.

There is another gotcha here: assigning to an undefined variable creates a global variable.

In non-strict mode, assigning directly to a variable without using the `var` keyword creates a global variable.
```javascript

function func() { x = 123; }
func();
x
<123


```
However, in strict mode, this will throw an error immediately.
```javascript

function func() { 'use strict'; x = 123; }
func();
<ReferenceError: x is not defined


```
In ES5, a common way to limit the lifetime of variables is to introduce a new scope, typically via an IIFE (Immediately-invoked function expression).

With an IIFE, we can:

1. Avoid global variables and hide variables from the global scope.
2. Create a new environment to avoid sharing.
3. Keep global data relatively independent from constructor data.
4. Attach global data to a singleton object.
5. Attach global data to methods.


### IV. JavaScript Scope Cheating

#### (1). The `with` Statement

The `with` statement is considered by many to be one of the Bad Parts of JavaScript. It was originally designed with good intentions, but it causes more problems than it solves.

`with` was originally designed to avoid redundant object references.

For example:
```javascript

foo.a.b.c = 888;
foo.a.b.d = 'halfrost';

```
At this point, you can use a with statement to shorten the call:
```javascript

with (foo.a.b) {
      c = 888;
      d = 'halfrost';
}


```
However, this behavior introduces many problems:
```javascript

function myLog( errorMsg , parameters) {
  with (parameters) {
    console.log('errorMsg:' + errorMsg);
  }
}

myLog('error',{});
<errorMsg:error

myLog('error',{ errorMsg:'stackoverflow' }); 
<errorMsg:stackoverflow


```
You can see that the output is already incorrect. Because of the with statement, the first argument is overwritten. By reading the code alone, it is sometimes impossible to identify these issues. They can also change subtly as the program runs, and this uncertainty about future behavior can easily lead to
bugs.

with causes three problems:

1. Performance issues  
Variable lookup becomes slower because the object is temporarily inserted into the scope chain.

2. Code uncertainty  
@Brendan Eich explained that the fundamental reason for deprecating with was not performance. Rather, it was because “with may violate the current code context, making program analysis (such as security analysis) difficult and tedious.”

3. Code minification tools do not minify variable names inside with statements

Therefore, in strict mode, the use of with statements is strictly prohibited.
```javascript

Uncaught SyntaxError: Strict mode code may not include a with statement

```
If you still want to avoid using a `with` statement, there are two approaches:

1. Use a temporary variable instead of the object passed into the `with` statement.
2. If you don’t want to introduce a temporary variable, you can use an IIFE.
```javascript

(function () {
  var a = foo.a.b;
  console.log('Hello' + a.c + a.d);
}());

or

(function (bar) {
  console.log('Hello' + bar.c + bar.d);
}(foo.a.b));


```

#### (2). The eval Function

The eval function passes a string to the JavaScript compiler and executes the result.
```javascript

eval(str)

```
It is one of the most abused features in JavaScript.
```javascript

var a = 12;
eval('a + 5')
<17

```
The `eval` function and its relatives (`Function`, `setTimeout`, `setInterval`) all provide access to the JavaScript compiler.

One advantage of the `Function()` constructor over the `eval()` function is that it makes the inputs clearer.
```javascript

new Function( param1, ...... , paramN, funcBody )


var f = new Function( 'x', 'y' , 'return x + y' )；
f(3,4)
<7

```
Using Function() at least avoids having to use an indirect eval() call to ensure that the executed code can access only global variables in addition to its own scope.

There is still eval() code in Weex, but the Weex team has promised in comments that they will change it. In general, it is best to avoid dynamic code execution methods such as eval() and new Function(). Dynamically executing code is relatively slow and also introduces security risks.

Now let’s talk about two other relatives, the setTimeout and setInterval functions. They can also accept either a string parameter or a function parameter. When a string parameter is passed, setTimeout and setInterval process it just like eval does. Likewise, you should avoid passing strings to these two functions.

The problems introduced by the eval function can be summarized as follows:

1. The function becomes a string, which hurts readability and introduces security risks.
2. The function has to run the compiler, even if only to execute a trivial assignment statement. This slows down execution.
3. It breaks JSLint and greatly reduces its ability to detect problems.

### Five. JavaScript Execution Context


![](https://img.halfrost.com/Blog/ArticleImage/48_1.png)


To explain this, we need to start with how JavaScript source code is run.

We all know that JavaScript is a scripting language. It only has runtime, not the buildTime of compiled languages. So how is it run by major browsers?

JavaScript code is compiled and run by each browser engine. **The goal of a JavaScript engine’s code parsing and execution process is to compile the most optimized code in the shortest possible time.** The JavaScript engine is also responsible for memory management, garbage collection, interaction with the host language, and so on. Popular engines include the following:  
Apple’s JavaScriptCore (JSC) engine, Mozilla’s SpiderMonkey, Microsoft Internet Explorer’s Chakra (JScript engine), Microsoft Edge’s Chakra (JavaScript engine), and Google Chrome’s V8.


![](https://img.halfrost.com/Blog/ArticleImage/48_17.png)


Among them, the V8 engine is the most famous open-source engine. The biggest difference between it and the engines mentioned above is that mainstream engines are implemented based on bytecode, whereas V8 took an extremely aggressive approach: it skipped the bytecode layer entirely and compiled JS directly into machine code. So V8 had no interpreter. (But that is history; the latest versions of V8 now do have an interpreter.)

![](https://img.halfrost.com/Blog/ArticleImage/48_2.png)


> After May 1, 2017, Chrome’s V8 engine released v8 5.9, in which the Ignition bytecode interpreter would be enabled by default: V8 Release 5.9. Since then, v8 returned to the embrace of bytecode.

After V8 gained bytecode, it removed the old Crankshaft compiler and allowed the new Turbofan to optimize code directly from bytecode. When deoptimization is needed, it can deoptimize directly back to bytecode without needing to consider the JS source code anymore. After Crankshaft was removed, the combination became Turbofan + Ignition.


![](https://img.halfrost.com/Blog/ArticleImage/48_3.png)


The Ignition + TurboFan combination is the golden pairing of a bytecode interpreter and a JIT compiler. This golden combination is used in many JS engines. For example, Microsoft’s Chakra first interprets and executes bytecode, then observes execution. If it discovers hot code, the background JIT compiles the bytecode into efficient code, after which only the efficient code is executed and the bytecode is no longer interpreted. Apple’s SquirrelFish Extreme also introduced JIT. SpiderMonkey is the same: all JS code is initially interpreted by the interpreter, which also collects execution information. When it detects that code has become hot, JITs such as JaegerMonkey and IonMonkey step in to compile and generate efficient machine code.

To summarize:

JavaScript code is first compiled by the engine and converted into bytecode that the interpreter can recognize.

![](https://img.halfrost.com/Blog/ArticleImage/48_4.png)


The source code is lexically analyzed and syntactically analyzed to generate an AST, the abstract syntax tree.


![](https://img.halfrost.com/Blog/ArticleImage/48_5.png)


The AST is then optimized multiple times by the bytecode generator, ultimately producing intermediate bytecode. At this point, the bytecode can be executed by the interpreter.


In this way, JavaScript code can be run by the engine.

There are three types of scopes involved when JavaScript runs:
1. Global Scope: the default environment where JavaScript code starts running
2. Local Scope: when code enters a JavaScript function
3. Eval Scope: code executed using eval()


When JavaScript code executes, the engine creates different execution contexts, and these execution contexts form an execution context stack (ECS).

The global execution context is always at the bottom of the stack, while the currently executing function is at the top.


![](https://img.halfrost.com/Blog/ArticleImage/48_6.png)


When the JavaScript engine encounters a function execution, it creates an execution context and pushes it onto the execution context stack. When the function finishes executing, the function’s execution context is popped from the stack.


Each execution context has three important properties: the variable object (VO), the scope chain, and this. These three properties are closely related to how the code runs.


The variable object VO is the data scope associated with an execution context. It is a special context-related object that stores the variables and function declarations defined in that context. In other words, VO generally contains the following information:

1. Create arguments object 
2. Find function declarations (Function declaration)
3. Find variable declarations (Variable declaration)


![](https://img.halfrost.com/Blog/ArticleImage/48_7.png)


The diagram above also explains why function hoisting has higher priority than variable hoisting.

This also involves the activation object:
Only the variable object of the global context allows indirect access through VO property names. In a function execution context, VO cannot be accessed directly; instead, the activation object (Activation Object, abbreviated as AO) plays the role of VO. The activation object is created when entering the function context, and it is initialized through the function’s arguments property.


![](https://img.halfrost.com/Blog/ArticleImage/48_8.png)


Arguments Objects are internal objects in the activation object AO of a function context. They include the following properties:  
1. callee: a reference pointing to the current function
2. length: the number of arguments actually passed
3. properties-indexes: the function’s argument values (ordered from left to right according to the parameter list)


When the JavaScript interpreter creates an execution context, it goes through two phases:

1. Creation phase (after the function is called, but before execution of the function’s internal code begins)
Create the Scope chain, create VO/AO (variables, functions and arguments), and set the value of this.
2. Activation / code execution phase
Set variable values and function references, then interpret/execute the code.

The difference between VO and AO lies in these two lifecycle phases of the execution context.


![](https://img.halfrost.com/Blog/ArticleImage/48_9.png)


The relationship between VO and AO can be understood as follows: VO has different representations in different Execution Contexts. In the Global Execution Context, VO is used directly; however, in a function Execution Context, AO is created.


### Six. Scope Chains in JavaScript

There are two ways to pass variables in JavaScript.

#### 1. Passing variables through the execution context stack by calling functions.  
 
Every time a function is called, new storage space must be prepared for its parameters and variables, and a new environment is created to map identifiers to variables (for variables and parameters). In recursive cases, the execution context—that is, the references to environments—is managed in a stack. The stack here corresponds to the call stack.

The JavaScript engine processes them in a stack-based manner. This stack is what we call the function call stack. The bottom of the stack is always the global context, while the top of the stack is the currently executing context.


Here is an example: computing the factorial of n recursively.

#### 2. Scope chain

In JavaScript, there is an internal property [[ Scope ]] used to record a function’s scope. When a function is called, JavaScript creates an environment for the new scope where the function resides. This environment has an outer scope, which is created through [[ Scope ]] and points to the environment of the external scope. Therefore, JavaScript has a scope chain that starts from the current scope and links to outer scopes; every scope chain ultimately terminates in the global environment. The outer scope of the global scope points to null.

**The scope chain consists of a series of variable objects from the current environment and its upper-level environments. It ensures orderly access from the current execution environment to variables and functions that are allowed by access rules.**


Scope is a set of rules determined when the JavaScript engine compiles the code.
The scope chain is created during the creation phase of the execution context, which is determined during the JavaScript engine’s interpretation and execution phase.
```javascript

function myFunc( myParam ) {
    var myVar = 123;
    return myFloat;
}
var myFloat = 2.0;  // 1
myFunc('ab');       // 2

```
When the program reaches marker 1:


![](https://img.halfrost.com/Blog/ArticleImage/48_10.png)


The function myFunc is connected to its scope—the global scope—through [[ Scope]].

When the program reaches marker 2, JavaScript creates a new scope to manage the parameters and local variables.


![](https://img.halfrost.com/Blog/ArticleImage/48_11.png)


Because of the outer scope chain, myFunC can access myFloat in the outer scope.

This is the "scope chain" structure unique to the JavaScript language: child objects look upward level by level for variables in all parent objects. Therefore, all variables of the parent object are visible to the child object, but not vice versa.


> The scope chain ensures ordered access to all variables and functions that the execution environment is entitled to access. The front of the scope chain is always the variable object of the environment where the currently executing code resides. We have already discussed the process of creating variable objects. The next variable object in the scope chain comes from the containing environment, that is, the outer environment, and this continues all the way to the global execution environment; the variable object of the global execution environment is always the last object in the scope chain.

### VII. Closures in JavaScript

A closure is created when a function can remember and access its lexical scope, even when the function is executed outside that lexical scope.

Next, let's look at how different sources define closures:

MDN defines a closure as follows:

> A closure is a function that can access independent (free) variables (variables that are used locally but defined in an enclosing scope). In other words, these functions can "remember" the environment in which they were created.

*JavaScript: The Definitive Guide (6th Edition)* defines a closure as follows:

> Function objects can be associated with each other through a scope chain, and variables inside a function body can be preserved within the function scope. This feature is called a closure in computer science literature.

*JavaScript: The Advanced Programming (3rd Edition)* defines a closure as follows:

> A closure is a function that has access to variables in another function's scope.

Finally, here is Ruan Yifeng's explanation of closures:

> Because in the JavaScript language, only subfunctions inside a function can read local variables, a closure can be simply understood as a function defined inside another function. It has two main uses: one is, as mentioned earlier, to read variables inside a function; the other is to keep the values of those variables in memory at all times.


Now let's compare the differences in closure syntax across four languages: OC, Swift, JS, and Python:
```objectivec

void test() {
    int value = 10;
    void(^block)() = ^{ NSLog(@"%d", value); };
    value++;
    block();
}

// Outputs 10

```

```Swift

func test() {
    var value = 10
    let closure = { print(value) }
    value += 1
    closure()
}
// Outputs 11

```

```javascript

function test() {
    var value = 10;
    var closure = function () {
        console.log(value);
    }
    value++;
    closure();
}
// Outputs 11

```

```python

def test():
    value = 10
    def closure():
        print(value)
    value = value + 1
    closure()
// Outputs 11

```
As you can see, OC’s default behavior differs from the other three languages. iOS developers should already be very familiar with how closures work in OC, so I won’t go into detail here. Of course, if you want the first OC example to output 11, it’s easy to change: just add the \_\_block keyword before the external variable that needs to be captured.

Finally, let’s look at an example combining the scope chain and closures:
```javascript

function createInc(startValue) {
  return function (step) {
    startValue += step;
    return startValue;
  }
}

var inc = createInc(5);
inc(3);


```
When the code enters the Global Execution Context, the Global Variable Object is created. The global execution context is pushed onto the execution context stack.

![](https://img.halfrost.com/Blog/ArticleImage/48_12.png)


During initialization of the Global Variable Object, createInc is created and made to point to a function object; inc is initialized, but at this point it is still undefined.


Next, execution reaches createInc(5). A Function Execution Context is created and pushed onto the execution context stack. A createInc Activation Object is also created.


![](https://img.halfrost.com/Blog/ArticleImage/48_13.png)


Because this function has not yet executed, the value of startValue is still undefined. Next, the createInc function is executed.


![](https://img.halfrost.com/Blog/ArticleImage/48_14.png)


When the createInc function finishes executing and exits, inc in the Global VO is set. One thing to note here is that although the create Execution Context has exited the execution context stack, members inside inc still reference the createInc AO (because the createInc AO is the parent scope of the function(step) function), so the createInc AO remains in the Scope.

Next, execution begins for inc(3).

![](https://img.halfrost.com/Blog/ArticleImage/48_15.png)


When the inc(3) code runs, execution enters the inc Execution Context, and a VO/AO is created for that execution context, the scope chain is created, and this is set. At this point, the inc AO points to the createInc AO.


![](https://img.halfrost.com/Blog/ArticleImage/48_16.png)


Finally, the inc Execution Context exits the execution context stack, but the createInc AO is not destroyed and can still be accessed.


### 8. Modules in JavaScript

The concept of modules can also be derived from scope.

Modules are used extensively in ES6. When code is loaded through the module system, ES6 treats each file as an independent module. Each module can import other modules or specific API members, and it can also export its own API members.


Modules have two main characteristics:  
1. A wrapper function is invoked to create an internal scope;
2. The return value of the wrapper function must include at least one reference to an internal function, thereby creating a closure that covers the entire internal scope of the wrapper function.

The two main module systems in JavaScript are CommonJS and AMD: the former is used on the server, while the latter is used in the browser. Modules in ES6 make it possible to determine module dependencies, as well as input and output variables, at compile time. CommonJS and AMD modules can only determine these things at runtime.

A CommonJS module is an object, and when importing from it, object properties must be looked up. This is runtime loading. CommonJS imports a copy of the exported value, not a reference.

ES6 Modules complete module compilation at compile time, so they use compile-time loading, which is more efficient than the CommonJS module loading approach. The runtime mechanism of ES6 modules differs from CommonJS. When it encounters an import command for loading a module, it does not execute the module; it only generates a dynamic read-only reference. When the value is actually needed, it is then retrieved from the module. Variables loaded by ES6 modules are dynamic references: if the original value changes, the imported value changes along with it, and the value is not cached. Variables inside a module are bound to the module they belong to.


Reference:     
[Learning JavaScript Closures](http://www.ruanyifeng.com/blog/2009/08/learning_javascript_closures.html)     
[JavaScript Execution Contexts](http://www.cnblogs.com/wilber2013/p/4909430.html)    
[V8](https://github.com/v8/v8/wiki/Introduction)   
[V8 JavaScript Engine](https://v8project.blogspot.sg/2016/)   
[V8 Ignition: The Inseparable Relationship Between the JS Engine and Bytecode](https://zhuanlan.zhihu.com/p/26669846)   
[Ignition: An Interpreter for V8 [BlinkOn]](https://docs.google.com/presentation/d/1OqjVqRhtwlKeKfvMdX6HaCIu9wpZsrzqpIVIwQSuiXQ/edit#slide=id.g1453eb7f19_0_391)