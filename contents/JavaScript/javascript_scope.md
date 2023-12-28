# 从 JavaScript 作用域说开去

![](https://img.halfrost.com/Blog/ArticleTitleImage/48_0_.png)


### 目录

- 1.静态作用域与动态作用域
- 2.变量的作用域
- 3.JavaScript 中变量的作用域
- 4.JavaScript 欺骗作用域
- 5.JavaScript 执行上下文
- 6.JavaScript 中的作用域链
- 7.JavaScript 中的闭包
- 8.JavaScript 中的模块


### 一. 静态作用域与动态作用域

在电脑程序设计中，**作用域**（scope，或译作有效范围）是名字（name）与实体（entity）的绑定（binding）保持有效的那部分计算机程序。不同的编程语言可能有不同的作用域和名字解析。而同一语言内也可能存在多种作用域，随实体的类型变化而不同。**作用域类别**影响变量的绑定方式，根据语言使用**静态作用域**还是**动态作用域**变量的取值可能会有不同的结果。

- 包含标识符的宣告或定义；  
- 包含语句和/或表达式，定义或部分关于可运行的算法；
- 嵌套嵌套或被嵌套嵌套。

[名字空间](https://zh.wikipedia.org/wiki/%E5%91%BD%E5%90%8D%E7%A9%BA%E9%97%B4)是一种作用域，使用作用域的封装性质去逻辑上组群起关相的众识别子于单一识别子之下。因此，**作用域**可以影响这些内容的[名字解析](https://zh.wikipedia.org/w/index.php?title=%E5%90%8D%E5%AD%97%E8%A7%A3%E6%9E%90&action=edit&redlink=1)。
程序员常会[缩进](https://zh.wikipedia.org/w/index.php?title=%E7%B8%AE%E6%8E%92&action=edit&redlink=1)他们的[源代码](https://zh.wikipedia.org/wiki/%E5%8E%9F%E5%A7%8B%E7%A2%BC)中的**作用域**，改善可读性。

作用域又分为两种，静态作用域和动态作用域。

**静态作用域**又叫做词法作用域，采用词法作用域的变量叫**词法变量**。词法变量有一个在编译时静态确定的作用域。词法变量的作用域可以是一个函数或一段代码，该变量在这段代码区域内可见（visibility）；在这段区域以外该变量不可见（或无法访问）。词法作用域里，取变量的值时，会检查函数定义时的文本环境，捕捉函数定义时对该变量的绑定。



```javascript


function f() {
    function g() {
  }
}



```

静态(词法)作用域，就是可以无须执行程序而只从程序源码的角度，就可以看出程序是如何工作的。从上面的例子中可以肯定，函数 g 是被函数 f 包围在内部。


大多数现在程序设计语言都是采用静态作用域规则，如C/C++、C#、Python、Java、JavaScript……

相反，采用**动态作用域**的变量叫做**动态变量**。只要程序正在执行定义了动态变量的代码段，那么在这段时间内，该变量一直存在；代码段执行结束，该变量便消失。这意味着如果有个函数f，里面调用了函数g，那么在执行g的时候，f里的所有局部变量都会被g访问到。而在静态作用域的情况下，g不能访问f的变量。动态作用域里，取变量的值时，会由内向外逐层检查函数的调用链，并打印第一次遇到的那个绑定的值。显然，最外层的绑定即是全局状态下的那个值。


```javascript

function g() {
}

function f() {
   g()；
}



```

当我们调用f()，它会调用g()。在执行期间，g被f调用代表了一种动态的关系。

采用动态作用域的语言有Pascal、Emacs Lisp、Common Lisp（兼有静态作用域）、Perl（兼有静态作用域）。C/C++是静态作用域语言，但在宏中用到的名字，也是动态作用域。


### 二. 变量的作用域

#### 1. 变量的作用域

变量的作用域是指变量在何处可以被访问到。比如：

```javascript

function foo（）{
    var bar;
}

```

这里的 bar 的直接作用域是函数作用域foo()；


#### 2. 词法作用域

JavaScript 中的变量都是有静态(词法)作用域的，因此一个程序的静态结构就决定了一个变量的作用域，这个作用域不会被函数的位置改变而改变。


#### 3. 嵌套作用域

如果一个变量的直接作用域中嵌套了多个作用域，那么这个变量在所有的这些作用域中都可以被访问：

```javascript

function foo (arg) {
    function bar() {
        console.log( 'arg:' + arg );
    }
    bar();
}

console.log(foo('hello'));   // arg:hello

```

arg的直接作用域是foo()，但是它同样可以在嵌套的作用域bar()中被访问，foo()是外部的作用域，bar()是内部作用域。


#### 4. 覆盖的作用域

如果在一个作用域中声明了一个与外层作用域同名的变量，那么这个内部作用域以及内部的所有作用域中将会访问不到外面的变量。并且内部的变量的变化也不会影响到外面的变量，当变量离开内部的作用域以后，外部变量又可以被访问了。

```javascript

var x = "global"；

function f() {
   var x = "local"；
   console.log(x);   // local
}

f();
console.log(x);  // global


```

这就是覆盖的作用域。

### 三. JavaScript 中变量的作用域

大多数的主流语言都是有块级作用域的，变量在最近的代码块中，Objective-C 和 Swift 都是块级作用域的。但是在 JavaScript 中的变量是函数级作用域的。不过在最新的 ES6 中加入了 let 和 const 关键字以后，就变相支持了块级作用域。到了 ES6 以后支持块级作用域的有以下几个：

1. **with 语句**
用 with 从对象中创建出的作用域仅在 with 声明中而非外 部作用域中有效。
2. **try/catch 语句**
JavaScript 的 ES3 规范中规定 try/catch 的 catch 分句会创建一个块作用域，其中声明的变量仅在 catch 内部有效。
3. **let 关键字**
let关键字可以将变量绑定到所在的任意作用域中(通常是{ .. }内部)。换句话说，let 为其声明的变量隐式地了所在的块作用域。
4. **const 关键字**
除了 let 以外，ES6 还引入了 const，同样可以用来创建块作用域变量，但其值是固定的 (常量)。之后任何试图修改值的操作都会引起错误。


这里就需要注意变量和函数提升的问题了，这个问题在前一篇文章里面详细的说过了，这里不再赘述了。

不过这里还有一个坑，如果赋值给了一个未定义的变量，会产生一个全局变量。

在非严格模式下，不通过 var 关键字直接给一个变量赋值，会产生一个全局的变量

```javascript

function func() { x = 123; }
func();
x
<123


```

不过在严格模式下，这里会直接报错。

```javascript

function func() { 'use strict'; x = 123; }
func();
<ReferenceError: x is not defined


```

在 ES5 中，经常会通过引入一个新的作用域来限制变量的生命周期，通过 IIFE（Immediately-invoked function expression，立即执行的函数表达式）来引入新的作用域。

通过 IIFE ，我们可以

1. 避免全局变量，隐藏全局作用域的变量。
2. 创建新的环境，避免共享。
3. 保持全局的数据对于构造器的数据相对独立。
4. 将全局的数据附加到单例对象上。
5. 将全局数据附加到方法中。



### 四. JavaScript 欺骗作用域

#### (1). with 语句

with 语句被很多人都认为是 JavaScript 里面的糟粕( Bad Parts )。起初它被设计出来的目的是好的，但是它导致的问题多于它解决的问题。

with 起初设计出来是为了避免冗余的对象调用。

举个例子：

```javascript

foo.a.b.c = 888;
foo.a.b.d = 'halfrost';

```

这时候用 with 语句就可以缩短调用：

```javascript

with (foo.a.b) {
      c = 888;
      d = 'halfrost';
}


```

但是这种特性却带来了很多问题：


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

可以看到输出就出现问题了，由于 with 语句，覆盖掉了第一个入参。通过阅读代码，有时候是不能分辨出这些问题，它也会随着程序的运行，导致发生不多的变化，这种对未来的不确定性就很容易出现
 bug。

with 会导致3个问题：

1. 性能问题  
变量查找会变慢，因为对象是临时性的插入到作用域链中的。

2. 代码不确定性  
@Brendan Eich 解释，废弃 with 的根本原因不是因为性能问题，原因是因为“with 可能会违背当前的代码上下文，使得程序的解析（例如安全性）变得困难而繁琐”。

3. 代码压缩工具不会压缩 with 语句中的变量名

所以在严格模式下，已经严格禁止使用 with 语句。


```javascript

Uncaught SyntaxError: Strict mode code may not include a with statement

```

如果还是想避免使用 with 语句，有两种方法：

1. 用一个临时变量替代传进 with 语句的对象。
2. 如果不想引入临时变量，可以使用 IIFE 。

```javascript

(function () {
  var a = foo.a.b;
  console.log('Hello' + a.c + a.d);
}());

或者

(function (bar) {
  console.log('Hello' + bar.c + bar.d);
}(foo.a.b));


```



#### (2). eval 函数

eval 函数传递一个字符串给 JavaScript 编译器，并且执行其结果。

```javascript

eval(str)

```

它是 JavaScript 中被滥用的最多的特性之一。

```javascript

var a = 12;
eval('a + 5')
<17

```

eval 函数以及它的亲戚（ Function 、setTimeout、setInterval）都提供了访问 JavaScript 编译器的机会。

Function() 构造函数的形式比 eval() 函数好一点的地方在于，它令入参更加清晰。

```javascript

new Function( param1, ...... , paramN, funcBody )


var f = new Function( 'x', 'y' , 'return x + y' )；
f(3,4)
<7

```

用 Function() 的方式至少不用使用间接的 eval() 调用来确保所执行的代码除了其自己的作用域只能访问全局的变量。

在 Weex 的代码中，就还存在着 eval() 的代码，不过 Weex 团队在注释里面承诺会改掉。总的来说，最好应该避免使用 eval() 和 new Function() 这些动态执行代码的方法。动态执行代码相对会比较慢，并且还存在安全隐患。

再说说另外两个亲戚，setTimeout、setInterval 函数，它们也能接受字符串参数或者函数参数。当传递的是字符串参数时，setTimeout、setInterval 会像 eval 那样去处理。同样也需要避免使用这两个函数的时候使用字符串传参数。

eval 函数带来的问题总结如下：

1. 函数变成了字符串，可读性差，存在安全隐患。
2. 函数需要运行编译器，即使只是为了执行一个微不足道的赋值语句。这使得执行速度变慢。
3. 让 JSLint 失效，让它检测问题的能力大打折扣。

### 五. JavaScript 执行上下文


![](https://img.halfrost.com/Blog/ArticleImage/48_1.png)




这个事情要从 JavaScript 源代码如何被运行开始说起。

我们都知道 JavaScript 是脚本语言，它只有 runtime，没有编译型语言的 buildTime，那它是如何被各大浏览器运行起来的呢？

JavaScript 代码是被各个浏览器引擎编译和运行起来的。**JavaScript 引擎的代码解析和执行过程的目标就是在最短时间内编译出最优化的代码。** JavaScript 引擎还需要负责管理内存，负责垃圾回收，与宿主语言的交互等。流行的引擎有以下几种：  
苹果公司的 JavaScriptCore （JSC） 引擎，Mozilla 公司的 SpiderMonkey，微软 Internet Explorer 的 Chakra (JScript引擎)，Microsoft Edge 的 Chakra (JavaScript引擎) ，谷歌 Chrome 的 V8。



![](https://img.halfrost.com/Blog/ArticleImage/48_17.png)



其中 V8 引擎是最著名的开源的引擎，它和前面那几个引擎有一个最大的区别是：主流引擎都是基于字节码的实现，V8 的做法非常极致，直接跳过了字节码这一层，直接把 JS 编译成机器码。所以 V8 是没有解释器的。（但是这都是历史，V8 现在最新版是有解释器的）

![](https://img.halfrost.com/Blog/ArticleImage/48_2.png)



> 在2017年5月1号之后， Chrome 的 V8 引擎的v8 5.9 发布了，其中的 Ignition 字节码解释器将默认启动 ：V8 Release 5.9 。v8 自此回到了字节码的怀抱。

V8 在有了字节码以后，消除 Cranshaft 这个旧的编译器，并让新的 Turbofan 直接从字节码来优化代码，并当需要进行反优化的时候直接反优化到字节码，而不需要再考虑 JS 源代码。去掉 Cranshaft 以后，就成了 Turbofan + Ignition 的组合了。



![](https://img.halfrost.com/Blog/ArticleImage/48_3.png)



Ignition + TurboFan 的组合，就是字节码解释器 + JIT 编译器的黄金组合。这一黄金组合在很多 JS 引擎中都有所使用，例如微软的 Chakra，它首先解释执行字节码，然后观察执行情况，如果发现热点代码，那么后台的 JIT 就把字节码编译成高效代码，之后便只执行高效代码而不再解释执行字节码。苹果公司的 SquirrelFish Extreme 也引入了 JIT。SpiderMonkey 更是如此，所有 JS 代码最初都是被解释器解释执行的，解释器同时收集执行信息，当它发现代码变热了之后，JaegerMonkey、IonMonkey 等 JIT 便登场，来编译生成高效的机器码。

总结一下：

JavaScript 代码会先被引擎编译，转化成能被解释器识别的字节码。

![](https://img.halfrost.com/Blog/ArticleImage/48_4.png)



源码会被词法分析，语法分析，生成 AST 抽象语法树。


![](https://img.halfrost.com/Blog/ArticleImage/48_5.png)



AST 抽象语法树又会被字节码生成器进行多次优化，最终生成了中间态的字节码。这时的字节码就可以被解释器执行了。


这样，JavaScript 代码就可以被引擎跑起来了。

JavaScript 在运行过程中涉及到的作用域有3种：
1. 全局作用域（Global Scope）JavaScript 代码开始运行的默认环境
2. 局部作用域（Local Scpoe）代码进入一个 JavaScript 函数
3. Eval 作用域 使用 eval() 执行代码


当 JavaScript 代码执行的时候，引擎会创建不同的执行上下文，这些执行上下文就构成了一个执行上下文栈（Execution context stack，ECS）。

全局执行上下文永远都在栈底，当前正在执行的函数在栈顶。


![](https://img.halfrost.com/Blog/ArticleImage/48_6.png)


当 JavaScript 引擎遇到一个函数执行的时候，就会创建一个执行上下文，并且压入执行上下文栈，当函数执行完毕的时候，就会将函数的执行上下文从栈中弹出。


对于每个执行上下文都有三个重要的属性，变量对象（Variable object，VO），作用域链（Scope chain）和this。这三个属性跟代码运行的行为有很重要的关系。


变量对象 VO 是与执行上下文相关的数据作用域。它是一个与上下文相关的特殊对象，其中存储了在上下文中定义的变量和函数声明。也就是说，一般 VO 中会包含以下信息：

1. 创建 arguments object 
2. 查找函数声明（Function declaration）
3. 查找变量声明（Variable declaration）


![](https://img.halfrost.com/Blog/ArticleImage/48_7.png)





上图也解释了，为何函数提升优先级会在变量提升前面。

这里还会牵扯到活动对象（Activation object）：
只有全局上下文的变量对象允许通过 VO 的属性名称间接访问。在函数执行上下文中，VO 是不能直接访问的，此时由活动对象(Activation Object, 缩写为AO)扮演 VO 的角色。活动对象是在进入函数上下文时刻被创建的，它通过函数的 arguments 属性初始化。


![](https://img.halfrost.com/Blog/ArticleImage/48_8.png)






Arguments Objects 是函数上下文里的激活对象 AO 中的内部对象，它包括下列属性：  
1. callee：指向当前函数的引用
2. length： 真正传递的参数的个数
3. properties-indexes：就是函数的参数值(按参数列表从左到右排列)


JavaScript 解释器创建执行上下文的时候，会经历两个阶段：

1. 创建阶段（当函数被调用，但是开始执行函数内部代码之前）
创建 Scope chain，创建 VO/AO（variables, functions and arguments），设置 this 的值。
2. 激活 / 代码执行阶段
设置变量的值，函数的引用，然后解释/执行代码。

VO 和 AO 的区别就在执行上下文的这两个生命周期里面。


![](https://img.halfrost.com/Blog/ArticleImage/48_9.png)





VO 和 AO 的关系可以理解为，VO 在不同的 Execution Context 中会有不同的表现：当在 Global Execution Context 中，直接使用的 VO；但是，在函数 Execution Context 中，AO 就会被创建。






### 六. JavaScript 中的作用域链

在 JavaScript 中有两种变量传递的方式

#### 1. 通过调用函数，执行上下文的栈传递变量。  
 
函数每调用一次，就需要给它的参数和变量准备新的存储空间，就会创建一个新的环境将（变量和参数的）标识符合变量做映射。对于递归的情况，执行上下文，即通过环境的引用是在栈中进行管理的。这里的栈对应了调用栈。

JavaScript 引擎会以堆栈的方式来处理它们，这个堆栈，我们称其为函数调用栈(call stack)。栈底永远都是全局上下文，而栈顶就是当前正在执行的上下文。


这里举个例子：比如用递归的方式计算n的阶乘。

#### 2. 作用域链

在 JavaScript 中有一个内部属性 [[ Scope ]] 来记录函数的作用域。在函数调用的时候，JavaScript 会为这个函数所在的新作用域创建一个环境，这个环境有一个外层域，它通过 [[ Scope ]] 创建并指向了外部作用域的环境。因此在 JavaScript 中存在一个作用域链，它以当前作用域为起点，连接了外部的作用域，每个作用域链最终会在全局环境里终结。全局作用域的外部作用域指向了null。

**作用域链，是由当前环境与上层环境的一系列变量对象组成，它保证了当前执行环境对符合访问权限的变量和函数的有序访问。**


作用域是一套规则，是在 JavaScript 引擎编译的时候确定的。
作用域链是在执行上下文的创建阶段创建的，这是在  JavaScript 引擎解释执行阶段确定的。


```javascript

function myFunc( myParam ) {
    var myVar = 123;
    return myFloat;
}
var myFloat = 2.0;  // 1
myFunc('ab');       // 2

```

当程序运行到标志 1 的时候：


![](https://img.halfrost.com/Blog/ArticleImage/48_10.png)





函数 myFunc 通过 [[ Scope]] 连接着它的作用域，全局作用域。

当程序运行到标志 2 的时候，JavaScript 会创建一个新的作用域用来管理参数和本地变量。


![](https://img.halfrost.com/Blog/ArticleImage/48_11.png)





由于外层作用域链，使得 myFunc 可以访问到外层的 myFloat 。

这就是 Javascript 语言特有的"作用域链"结构（chain scope），子对象会一级一级地向上寻找所有父对象的变量。所以，父对象的所有变量，对子对象都是可见的，反之则不成立。


> 作用域链是保证对执行环境有权访问的所有变量和函数的有序访问。作用域链的前端始终是当前执行的代码所在环境的变量对象。而前面我们已经讲了变量对象的创建过程。作用域链的下一个变量对象来自包含环境即外部环境，这样，一直延续到全局执行环境；全局执行环境的变量对象始终都是作用域链中的最后一个对象。

### 七. JavaScript 中的闭包

当函数可以记住并访问所在的词法作用域，即使函数是在当前词法作用域之外执行，这时就产生了闭包。

接下来看看大家对闭包的定义是什么样的：

MDN 对闭包的定义：

> 闭包是指那些能够访问独立（自由）变量的函数（变量在本地使用，但定义在一个封闭的作用域中）。换句话说，这些函数可以「记忆」它被创建时候的环境。

《JavaScript 权威指南(第6版)》对闭包的定义：

> 函数对象可以通过作用域链相互关联起来，函数体内部的变量都可以保存在函数作用域内，这种特性在计算机科学文献中称为闭包。

《JavaScript 高级程序设计(第3版)》对闭包的定义：

> 闭包是指有权访问另一个函数作用域中的变量的函数。

最后是阮一峰老师对闭包的解释：

> 由于在 Javascript 语言中，只有函数内部的子函数才能读取局部变量，因此可以把闭包简单理解成定义在一个函数内部的函数。它的最大用处有两个，一个是前面提到的可以读取函数内部的变量，另一个就是让这些变量的值始终保持在内存中。


再来对比看看 OC，Swift，JS，Python 4种语言的闭包写法有何不同：

```objectivec

void test() {
    int value = 10;
    void(^block)() = ^{ NSLog(@"%d", value); };
    value++;
    block();
}

// 输出10

```

```Swift

func test() {
    var value = 10
    let closure = { print(value) }
    value += 1
    closure()
}
// 输出11

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
// 输出11

```

```python

def test():
    value = 10
    def closure():
        print(value)
    value = value + 1
    closure()
// 输出11

```

可以看出 OC 的写法默认是和其他三种语言不同的。关于 OC 的闭包原理，iOS 开发的同学应该都很清楚了，这里不再赘述。当然，想要第一种 OC 的写法输出11，也很好改，只要把外部需要捕获进去的变量前面加上 \_\_block 关键字就可以了。


最后结合作用域链和闭包举一个例子：

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


当代码进入到 Global Execution Context 之后，会创建 Global Variable Object。全局执行上下文压入执行上下文栈。

![](https://img.halfrost.com/Blog/ArticleImage/48_12.png)



Global Variable Object 初始化会创建 createInc ，并指向一个函数对象，初始化 inc ，此时还是 undefined。


接着代码执行到 createInc(5)，会创建 Function Execution Context，并压入执行上下文栈。会创建 createInc Activation Object。


![](https://img.halfrost.com/Blog/ArticleImage/48_13.png)




由于还没有执行这个函数，所以 startValue 的值还是 undefined。接下来就要执行 createInc 函数了。


![](https://img.halfrost.com/Blog/ArticleImage/48_14.png)




当 createInc 函数执行的最后，并退出的时候，Global VO中的 inc 就会被设置；这里需要注意的是，虽然 create Execution Context 退出了执行上下文栈，但是因为 inc 中的成员仍然引用 createInc AO（因为 createInc AO 是 function(step) 函数的 parent scope ），所以 createInc AO 依然在 Scope 中。

接着再开始执行 inc(3)。

![](https://img.halfrost.com/Blog/ArticleImage/48_15.png)




当执行 inc(3) 代码的时候，代码将进入 inc Execution Context，并为该执行上下文创建 VO/AO，scope chain 和设置 this；这时，inc AO将指向 createInc AO。


![](https://img.halfrost.com/Blog/ArticleImage/48_16.png)



最后，inc Execution Context 退出了执行上下文栈，但是 createInc AO 没有销毁，可以继续访问。



### 八. JavaScript 中的模块

由作用域又可以引申出模块的概念。

在 ES6 中会大量用到模块，通过模块系统进行加载时，ES6 会将文件当作独立的模块来处理。每个模块都可以导入其他模块或特定的 API 成员，同样也可以导出自己的 API 成员。


模块有两个主要特征:  
1. 为创建内部作用域而调用了一个包装函数;
2. 包装函数的返回值必须至少包括一个对内部函数的引用，这样就会创建涵盖整个包装函数内部作用域的闭包。

JavaScript 最主要的有 CommonJS 和 AMD 两种，前者用于服务器，后者用于浏览器。在 ES6 中的 Module 使得编译时就能确定模块的依赖关系，以及输入输出的变量。CommonJS 和 AMD 模块都只能运行时确定这些东西。

CommonJS 模块就是对象，输入时必须查找对象属性。属于运行时加载。CommonJS 输入的是被输出值的拷贝，并不是引用。

ES6 的 Module 在编译时就完成模块编译，属于编译时加载，效率要比 CommonJS 模块的加载方式高。ES6 模块的运行机制与 CommonJS 不一样，它遇到模块加载命令 import 时不会去执行模块，只会生成一个动态的只读引用。等到真正需要的时候，再去模块中取值。ES6 模块加载的变量是动态引用，原始值变了，输入的值也会跟着变，并且不会缓存值，模块里面的变量绑定其所在的模块。





Reference：     
[学习Javascript闭包（Closure）](http://www.ruanyifeng.com/blog/2009/08/learning_javascript_closures.html)     
[JavaScript的执行上下文](http://www.cnblogs.com/wilber2013/p/4909430.html)    
[V8](https://github.com/v8/v8/wiki/Introduction)   
[V8 JavaScript Engine](https://v8project.blogspot.sg/2016/)   
[V8 Ignition：JS 引擎与字节码的不解之缘](https://zhuanlan.zhihu.com/p/26669846)   
[Ignition: An Interpreter for V8 [BlinkOn]](https://docs.google.com/presentation/d/1OqjVqRhtwlKeKfvMdX6HaCIu9wpZsrzqpIVIwQSuiXQ/edit#slide=id.g1453eb7f19_0_391)

