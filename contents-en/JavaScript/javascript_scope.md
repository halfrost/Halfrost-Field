# Starting from JavaScript Scope

![](https://img.halfrost.com/Blog/ArticleTitleImage/48_0_.png)


### Table of Contents

- 1.Static Scope and Dynamic Scope
- 2.Variable Scope
- 3.Variable Scope in JavaScript
- 4.Cheating Scope in JavaScript
- 5.JavaScript Execution Context
- 6.The Scope Chain in JavaScript
- 7.Closures in JavaScript
- 8.Modules in JavaScript


### 1. Static Scope and Dynamic Scope

In computer programming, **scope** is the portion of a computer program in which the binding between a name and an entity remains valid. Different programming languages may have different scoping and name-resolution rules. Even within the same language, multiple kinds of scope may exist, varying with the type of entity. The **kind of scope** affects how variables are bound; depending on whether a language uses **static scope** or **dynamic scope**, evaluating a variable may produce different results.

- Contains declarations or definitions of identifiers;  
- Contains statements and/or expressions that define, or partially define, an executable algorithm;
- Nests or is nested.

A [namespace](https://zh.wikipedia.org/wiki/%E5%91%BD%E5%90%8D%E7%A9%BA%E9%97%B4) is a kind of scope: it uses the encapsulation property of scope to logically group related identifiers under a single identifier. Therefore, **scope** can affect the [name resolution](https://zh.wikipedia.org/w/index.php?title=%E5%90%8D%E5%AD%97%E8%A7%A3%E6%9E%90&action=edit&redlink=1) of these elements.
Programmers often [indent](https://zh.wikipedia.org/w/index.php?title=%E7%B8%AE%E6%8E%92&action=edit&redlink=1) the **scopes** in their [source code](https://zh.wikipedia.org/wiki/%E5%8E%9F%E5%A7%8B%E7%A2%BC) to improve readability.

Scope is further divided into two types: static scope and dynamic scope.

**Static scope** is also called lexical scope, and variables that use lexical scope are called **lexical variables**. A lexical variable has a scope that is determined statically at compile time. The scope of a lexical variable can be a function or a block of code; the variable is visible within that region of code, and invisible (or inaccessible) outside it. Under lexical scope, when retrieving a variable’s value, the textual environment where the function was defined is examined, capturing the binding of that variable at the time the function was defined.
```javascript


function f() {
    function g() {
  }
}


```
Static (lexical) scoping means that you can determine how a program works purely from the program’s source code, without executing it. From the example above, it is clear that function `g` is enclosed within function `f`.

Most modern programming languages use static scoping rules, such as C/C++, C#, Python, Java, JavaScript, and so on.

By contrast, variables that use **dynamic scoping** are called **dynamic variables**. As long as the program is executing the code block in which a dynamic variable is defined, that variable continues to exist; once the code block finishes executing, the variable disappears. This means that if there is a function `f` that calls a function `g`, then while `g` is executing, all local variables in `f` can be accessed by `g`. Under static scoping, however, `g` cannot access variables in `f`. With dynamic scoping, when retrieving the value of a variable, the function call chain is checked layer by layer from the inside out, and the value of the first binding encountered is used. Clearly, the outermost binding is the value in the global state.
```javascript

function g() {
}

function f() {
   g()；
}


```
When we call f(), it calls g(). During execution, g being called by f represents a dynamic relationship.

Languages that use dynamic scoping include Pascal, Emacs Lisp, Common Lisp (which also has static scoping), and Perl (which also has static scoping). C/C++ are statically scoped languages, but names used in macros are also dynamically scoped.


### II. Variable Scope

#### 1. Variable Scope

A variable’s scope refers to where the variable can be accessed. For example:
```javascript

function foo（）{
    var bar;
}

```
Here, the direct scope of `bar` is the function scope `foo()`;


#### 2. Lexical Scope

Variables in JavaScript all have static (lexical) scope. Therefore, the static structure of a program determines a variable’s scope, and that scope does not change when the function’s position changes.


#### 3. Nested Scopes

If multiple scopes are nested within a variable’s direct scope, then the variable can be accessed in all of those scopes:
```javascript

function foo (arg) {
    function bar() {
        console.log( 'arg:' + arg );
    }
    bar();
}

console.log(foo('hello'));   // arg:hello

```
The immediate scope of `arg` is `foo()`, but it can also be accessed from the nested scope `bar()`. `foo()` is the outer scope, and `bar()` is the inner scope.


#### 4. Shadowed Scopes

If a variable is declared in a scope with the same name as a variable in an outer scope, then within that inner scope and all scopes nested inside it, the outer variable will no longer be accessible. Changes to the inner variable will not affect the outer variable. Once execution leaves the inner scope, the outer variable becomes accessible again.
```javascript

var x = "global"；

function f() {
   var x = "local"；
   console.log(x);   // local
}

f();
console.log(x);  // global


```
This is the scope covered.

### III. Variable Scope in JavaScript

Most mainstream languages have block-level scope: a variable lives in the nearest code block. Objective-C and Swift both use block-level scope. In JavaScript, however, variables are function-scoped. That said, with the introduction of the `let` and `const` keywords in ES6, JavaScript effectively gained support for block-level scope. After ES6, the following constructs support block-level scope:

1. **`with` statement**
The scope created from an object using `with` is only valid within the `with` statement, not in the outer scope.
2. **`try/catch` statement**
The ES3 specification for JavaScript states that the `catch` clause of `try/catch` creates a block scope, where variables declared inside it are only valid within the `catch` block.
3. **`let` keyword**
The `let` keyword can bind a variable to any scope it appears in (usually inside `{ .. }`). In other words, `let` implicitly scopes the variable it declares to the enclosing block scope.
4. **`const` keyword**
In addition to `let`, ES6 also introduced `const`, which can likewise be used to create block-scoped variables, but with a fixed value (a constant). Any subsequent attempt to modify that value will result in an error.

At this point, you need to pay attention to variable and function hoisting. This was covered in detail in the previous article, so it will not be repeated here.

There is another pitfall here: assigning a value to an undefined variable creates a global variable.

In non-strict mode, assigning directly to a variable without using the `var` keyword creates a global variable.
```javascript

function func() { x = 123; }
func();
x
<123


```
However, in strict mode, this will throw an error directly.
```javascript

function func() { 'use strict'; x = 123; }
func();
<ReferenceError: x is not defined


```
In ES5, a new scope is often introduced to limit the lifetime of variables. This is done via an IIFE (Immediately-invoked Function Expression).

With an IIFE, we can:

1. Avoid global variables and hide variables from the global scope.
2. Create a new environment to avoid sharing.
3. Keep global data relatively independent from constructor data.
4. Attach global data to a singleton object.
5. Attach global data to methods.


### IV. JavaScript Scope Deception

#### (1). The `with` Statement

The `with` statement is widely regarded as one of the bad parts of JavaScript. Its original purpose was well-intentioned, but it causes more problems than it solves.

`with` was originally designed to avoid redundant object access.

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
However, this feature has introduced many problems:
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
You can see that the output has gone wrong. Because of the `with` statement, the first argument is overwritten. By reading the code, you sometimes cannot identify these issues; they can also change as the program runs. This kind of uncertainty about future behavior can easily lead to bugs.

`with` causes three problems:

1. Performance issues  
Variable lookup becomes slower because the object is temporarily inserted into the scope chain.

2. Code uncertainty  
@Brendan Eich explained that the fundamental reason `with` was deprecated was not performance. The reason was that “`with` may violate the current code context, making program analysis (such as security analysis) difficult and cumbersome.”

3. Code minification tools will not minify variable names inside `with` statements

Therefore, in strict mode, the use of the `with` statement is strictly prohibited.
```javascript

Uncaught SyntaxError: Strict mode code may not include a with statement

```
If you still want to avoid using the `with` statement, there are two approaches:

1. Use a temporary variable to replace the object passed into the `with` statement.
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

The `Function()` constructor is slightly better than the `eval()` function in that it makes the input parameters clearer.
```javascript

new Function( param1, ...... , paramN, funcBody )


var f = new Function( 'x', 'y' , 'return x + y' )；
f(3,4)
<7

```
Using `Function()` at least avoids an indirect `eval()` call, ensuring that the executed code can access only its own scope and global variables.

There is still `eval()` code in Weex, but the Weex team promises in the comments that they will change it. In general, it is best to avoid dynamic code execution methods such as `eval()` and `new Function()`. Dynamically executing code is relatively slow and also introduces security risks.

Now let’s talk about two other relatives: `setTimeout` and `setInterval`. They can also accept either a string argument or a function argument. When a string argument is passed, `setTimeout` and `setInterval` process it in a way similar to `eval`. Likewise, you should avoid passing strings to these two functions.

The problems introduced by the `eval` function can be summarized as follows:

1. Functions become strings, which hurts readability and introduces security risks.
2. The function has to run the compiler, even if it is only executing a trivial assignment statement. This makes execution slower.
3. It breaks JSLint, greatly reducing its ability to detect problems.

### V. JavaScript Execution Context


![](https://img.halfrost.com/Blog/ArticleImage/48_1.png)


This topic starts with how JavaScript source code is run.

We all know that JavaScript is a scripting language. It only has runtime, not the buildTime of compiled languages. So how is it run by major browsers?

JavaScript code is compiled and executed by the various browser engines. **The goal of a JavaScript engine’s code parsing and execution process is to compile the most optimized code in the shortest possible time.** A JavaScript engine is also responsible for memory management, garbage collection, interaction with the host language, and more. Popular engines include the following:  
Apple’s JavaScriptCore (JSC) engine, Mozilla’s SpiderMonkey, Microsoft Internet Explorer’s Chakra (JScript engine), Microsoft Edge’s Chakra (JavaScript engine), and Google Chrome’s V8.


![](https://img.halfrost.com/Blog/ArticleImage/48_17.png)


Among them, V8 is the best-known open-source engine. Its biggest difference from the engines mentioned above is that mainstream engines were all bytecode-based implementations, whereas V8 took an extremely aggressive approach: it skipped the bytecode layer entirely and compiled JS directly to machine code. So V8 had no interpreter. (But that is history; the latest versions of V8 now do have an interpreter.)

![](https://img.halfrost.com/Blog/ArticleImage/48_2.png)


> After May 1, 2017, Chrome’s V8 engine released v8 5.9, in which the Ignition bytecode interpreter was enabled by default: V8 Release 5.9. From then on, v8 returned to the embrace of bytecode.

After V8 introduced bytecode, it removed the old Crankshaft compiler and allowed the new Turbofan to optimize code directly from bytecode. When deoptimization is needed, it can deoptimize directly back to bytecode without needing to consider the JS source code again. After removing Crankshaft, the architecture became the combination of Turbofan + Ignition.


![](https://img.halfrost.com/Blog/ArticleImage/48_3.png)


The combination of Ignition + TurboFan is the golden pairing of a bytecode interpreter and a JIT compiler. This golden pairing is used in many JS engines. For example, Microsoft’s Chakra first interprets and executes bytecode, then observes execution. If it finds hot code, the background JIT compiles the bytecode into optimized code, after which only the optimized code is executed and the bytecode is no longer interpreted. Apple’s SquirrelFish Extreme also introduced JIT. SpiderMonkey is the same: all JS code is initially interpreted by the interpreter, which simultaneously collects execution information. When it finds that code has become hot, JITs such as JaegerMonkey and IonMonkey come into play and compile it into efficient machine code.

To summarize:

JavaScript code is first compiled by the engine and converted into bytecode that the interpreter can recognize.

![](https://img.halfrost.com/Blog/ArticleImage/48_4.png)


The source code is lexically analyzed and syntactically analyzed, producing an AST, or abstract syntax tree.


![](https://img.halfrost.com/Blog/ArticleImage/48_5.png)


The AST is then optimized multiple times by the bytecode generator, eventually producing intermediate bytecode. At this point, the bytecode can be executed by the interpreter.


In this way, JavaScript code can be run by the engine.

There are three types of scopes involved while JavaScript is running:
1. Global Scope: the default environment where JavaScript code starts running
2. Local Scope: when code enters a JavaScript function
3. Eval Scope: code executed using `eval()`


When JavaScript code executes, the engine creates different execution contexts. These execution contexts form an execution context stack (ECS).

The global execution context is always at the bottom of the stack, and the currently executing function is at the top.


![](https://img.halfrost.com/Blog/ArticleImage/48_6.png)


When the JavaScript engine encounters a function execution, it creates an execution context and pushes it onto the execution context stack. When the function finishes executing, it pops the function’s execution context from the stack.


Each execution context has three important properties: the Variable Object (VO), the Scope Chain, and `this`. These three properties are closely related to the behavior of the running code.


The Variable Object, or VO, is the data scope associated with an execution context. It is a special context-related object that stores the variables and function declarations defined in that context. In other words, a typical VO contains the following information:

1. Creation of the arguments object
2. Lookup of function declarations
3. Lookup of variable declarations


![](https://img.halfrost.com/Blog/ArticleImage/48_7.png)


The diagram above also explains why function hoisting has higher priority than variable hoisting.

This also involves the Activation Object:
Only the variable object of the global context can be accessed indirectly through VO property names. In a function execution context, the VO cannot be accessed directly. Instead, the Activation Object (AO) plays the role of the VO. The activation object is created when entering the function context, and it is initialized through the function’s `arguments` property.


![](https://img.halfrost.com/Blog/ArticleImage/48_8.png)


Arguments Objects are internal objects inside the activation object AO in a function context. They include the following properties:  
1. `callee`: a reference to the current function
2. `length`: the actual number of arguments passed
3. `properties-indexes`: the values of the function’s parameters (ordered from left to right according to the parameter list)


When the JavaScript interpreter creates an execution context, it goes through two phases:

1. Creation phase (after the function is called, but before the function body starts executing)
Create the Scope Chain, create the VO/AO (variables, functions and arguments), and set the value of `this`.
2. Activation / code execution phase
Set variable values and function references, then interpret/execute the code.

The difference between VO and AO lies in these two lifecycle phases of an execution context.


![](https://img.halfrost.com/Blog/ArticleImage/48_9.png)


The relationship between VO and AO can be understood as follows: VO has different manifestations in different Execution Contexts. In the Global Execution Context, VO is used directly; however, in a function Execution Context, AO is created.


### VI. Scope Chains in JavaScript

There are two ways to pass variables in JavaScript.

#### 1. Passing variables through the execution context stack by calling functions.  
 
Each time a function is called, new storage space must be prepared for its parameters and variables, and a new environment is created to map identifiers (for variables and parameters) to variables. In recursive cases, the execution context—that is, references through environments—is managed on the stack. The stack here corresponds to the call stack.

The JavaScript engine processes them in a stack-based manner. This stack is called the function call stack. The bottom of the stack is always the global context, while the top of the stack is the currently executing context.


Here is an example: calculating the factorial of n recursively.

#### 2. Scope chain

In JavaScript, there is an internal property [[ Scope ]] that records a function’s scope. When a function is called, JavaScript creates an environment for the new scope in which the function resides. This environment has an outer scope, which is created through [[ Scope ]] and points to the environment of the outer scope. Therefore, JavaScript has a scope chain that starts from the current scope and connects to outer scopes; every scope chain ultimately terminates in the global environment. The outer scope of the global scope points to null.

**A scope chain consists of a series of variable objects from the current environment and its parent environments. It ensures ordered access from the current execution environment to variables and functions that are within the permitted access scope.**


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

When the program reaches marker 2, JavaScript creates a new scope to manage parameters and local variables.


![](https://img.halfrost.com/Blog/ArticleImage/48_11.png)


Because of the outer scope chain, myFunc can access the outer myFloat.

This is the "scope chain" structure unique to JavaScript: child objects look upward level by level for variables in all parent objects. Therefore, all variables of a parent object are visible to its child objects, but not vice versa.


> The scope chain ensures ordered access to all variables and functions that an execution context has permission to access. The front of the scope chain is always the variable object of the environment where the currently executing code resides. We have already discussed the creation process of variable objects. The next variable object in the scope chain comes from the containing environment, i.e., the outer environment, and this continues all the way to the global execution environment; the variable object of the global execution environment is always the last object in the scope chain.

### VII. Closures in JavaScript

A closure is created when a function can remember and access its lexical scope, even when that function is executed outside the current lexical scope.

Next, let’s look at how closures are defined by different sources:

MDN’s definition of a closure:

> A closure refers to functions that can access independent (free) variables (variables that are used locally but defined in an enclosing scope). In other words, these functions can “remember” the environment in which they were created.

The definition of a closure in *JavaScript: The Definitive Guide (6th Edition)*:

> Function objects can be associated with one another through the scope chain, and variables inside a function body can be preserved within the function scope. This characteristic is called a closure in computer science literature.

The definition of a closure in *Professional JavaScript for Web Developers (3rd Edition)*:

> A closure is a function that has access to variables in another function’s scope.

Finally, here is Ruan Yifeng’s explanation of closures:

> In JavaScript, since only subfunctions inside a function can read local variables, a closure can be simply understood as a function defined inside another function. It has two main uses: one is, as mentioned earlier, to read variables inside a function; the other is to keep the values of those variables in memory at all times.


Now let’s compare the differences in closure syntax among the four languages OC, Swift, JS, and Python:
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
// Output 11

```
As you can see, OC’s default behavior differs from the other three languages. iOS developers should already be very familiar with how closures work in OC, so I won’t go into detail here. Of course, if you want the first OC example to output 11, it’s easy to modify: just add the \_\_block keyword before the external variable that needs to be captured.

Finally, let’s look at an example that combines the scope chain and closures:
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
Once the code enters the Global Execution Context, a Global Variable Object is created. The global execution context is pushed onto the execution context stack.

![](https://img.halfrost.com/Blog/ArticleImage/48_12.png)


Initializing the Global Variable Object creates createInc and points it to a function object; it also initializes inc, which is still undefined at this point.


Next, execution reaches createInc(5). A Function Execution Context is created and pushed onto the execution context stack. A createInc Activation Object is created.


![](https://img.halfrost.com/Blog/ArticleImage/48_13.png)


Because this function has not yet executed, the value of startValue is still undefined. Next, the createInc function will be executed.


![](https://img.halfrost.com/Blog/ArticleImage/48_14.png)


When the createInc function finishes execution and exits, inc in the Global VO is set. One thing to note here is that although the createInc Execution Context has exited the execution context stack, the members inside inc still reference createInc AO (because createInc AO is the parent scope of the function(step) function), so createInc AO still remains in Scope.

Next, execution starts for inc(3).

![](https://img.halfrost.com/Blog/ArticleImage/48_15.png)


When executing the inc(3) code, the code enters the inc Execution Context, and creates the VO/AO and scope chain for that execution context, and sets this. At this point, inc AO points to createInc AO.


![](https://img.halfrost.com/Blog/ArticleImage/48_16.png)


Finally, the inc Execution Context exits the execution context stack, but createInc AO is not destroyed and can still be accessed.


### 8. Modules in JavaScript

The concept of modules can also be derived from scope.

Modules are used extensively in ES6. When loaded through the module system, ES6 treats each file as an independent module. Each module can import other modules or specific API members, and likewise can export its own API members.


Modules have two main characteristics:  
1. A wrapper function is invoked to create an internal scope;
2. The return value of the wrapper function must include at least one reference to an internal function, thereby creating a closure that covers the entire internal scope of the wrapper function.

The two primary JavaScript module systems are CommonJS and AMD; the former is used on servers, and the latter in browsers. Modules in ES6 make it possible to determine a module’s dependencies, as well as its input and output variables, at compile time. CommonJS and AMD modules can only determine these things at runtime.

CommonJS modules are objects, and importing requires looking up object properties. This is runtime loading. What CommonJS imports is a copy of the exported value, not a reference.

ES6 Modules complete module compilation at compile time, so they are compile-time loaded and are more efficient than the CommonJS module loading approach. The runtime mechanism of ES6 modules differs from CommonJS: when it encounters the module loading command import, it does not execute the module; it only creates a dynamic read-only reference. When the value is actually needed, it is then retrieved from the module. Variables loaded by ES6 modules are dynamic references: if the original value changes, the imported value changes as well, and the value is not cached. Variables inside a module are bound to the module in which they reside.


References:     
[Learning JavaScript Closures](http://www.ruanyifeng.com/blog/2009/08/learning_javascript_closures.html)     
[JavaScript Execution Contexts](http://www.cnblogs.com/wilber2013/p/4909430.html)    
[V8](https://github.com/v8/v8/wiki/Introduction)   
[V8 JavaScript Engine](https://v8project.blogspot.sg/2016/)   
[V8 Ignition: The Inextricable Link Between JS Engines and Bytecode](https://zhuanlan.zhihu.com/p/26669846)   
[Ignition: An Interpreter for V8 [BlinkOn]](https://docs.google.com/presentation/d/1OqjVqRhtwlKeKfvMdX6HaCIu9wpZsrzqpIVIwQSuiXQ/edit#slide=id.g1453eb7f19_0_391)