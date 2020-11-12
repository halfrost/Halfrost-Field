+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "ReactiveCocoa", "RAC", "Macro"]
date = 2017-02-12T05:46:54Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/39_0_.png"
slug = "reactivecocoa_macro"
tags = ["iOS", "ReactiveCocoa", "RAC", "Macro"]
title = "ReactiveCocoa 中 奇妙无比的“宏”魔法"

+++


### 前言

在ReactiveCocoa 中，开源库作者为我们提供了很多种魔法，“黑”魔法，“红”魔法……今天就让先来看看“红”魔法。


![](https://img.halfrost.com/Blog/ArticleImage/39_1.png)






在ReactiveCocoa 中，封装了很多非常实用的“宏”，使用这些“宏”为我们开发带来了很多的便利。

今天就来盘点一下RAC中的宏是如何实现的。

### 目录

- 1.关于宏
- 2.ReactiveCocoa 中的元宏
- 3.ReactiveCocoa 中常用的宏

### 一. 关于宏

> **宏**（Macro），是一种[批量处理](https://zh.wikipedia.org/wiki/%E6%89%B9%E5%A4%84%E7%90%86)的称谓。

在编程领域里的宏是一种[抽象](https://zh.wikipedia.org/wiki/%E6%8A%BD%E8%B1%A1)（Abstraction），它根据一系列预定义的规则替换一定的文本模式。[解释器](https://zh.wikipedia.org/wiki/%E8%A7%A3%E9%87%8A%E5%99%A8)或[编译器](https://zh.wikipedia.org/wiki/%E7%BC%96%E8%AF%91%E5%99%A8)在遇到宏时会自动进行这一模式替换。绝大多数情况下，“宏”这个词的使用暗示着将小命令或动作转化为一系列指令。

宏的用途在于自动化频繁使用的序列或者是获得一种更强大的抽象能力。
计算机语言如[C语言](https://zh.wikipedia.org/wiki/C%E8%AF%AD%E8%A8%80)或[汇编语言](https://zh.wikipedia.org/wiki/%E6%B1%87%E7%BC%96%E8%AF%AD%E8%A8%80)有简单的宏系统，由[编译器](https://zh.wikipedia.org/wiki/%E7%BC%96%E8%AF%91%E5%99%A8)或[汇编器](https://zh.wikipedia.org/wiki/%E6%B1%87%E7%BC%96%E5%99%A8)的预处理器实现。[C语言](https://zh.wikipedia.org/wiki/C%E8%AF%AD%E8%A8%80)的宏预处理器的工作只是简单的文本搜索和替换，使用附加的文本处理语言如[M4](https://zh.wikipedia.org/wiki/M4)，C程序员可以获得更精巧的宏。

[Lisp](https://zh.wikipedia.org/wiki/Lisp)类语言如[Common Lisp](https://zh.wikipedia.org/wiki/Common_Lisp)和[Scheme](https://zh.wikipedia.org/wiki/Scheme)有更精巧的宏系统：宏的行为如同是函数对自身程序文本的变形，并且可以应用全部语言来表达这种变形。一个C宏可以定义一段语法的替换，然而一个Lisp的宏却可以控制一节代码的计算。



对于编译语言来说，所有的宏都是在预编译的时候被展开的，所以在lex进行词法扫描生成Token，词法分析过程之前，所有的宏都已经被展开完成了。

对于Xcode，预处理或者预编译阶段是可以直接查看的。


![](https://img.halfrost.com/Blog/ArticleImage/39_2.png)


随便写一个宏，然后打开Xcode右上方的Assistant，选择“Preprocess”就可以看到该文件预处理之后的样子了。可以看到左边的@weakify(self) 被转换成了右边的两行代码了。

关于这个Xcode的这个功能还有2点补充说明：

1.不同阶段的Preprocessed可能不同，要根据你的目标去选择预处理的条件。


![](https://img.halfrost.com/Blog/ArticleImage/39_3.png)


比如这里就有5种预编译的种类可以选择。

2.宏经过预编译之后出来的代码，是可以用来检测宏写的是否正确的，但是无法看到宏被展开的具体过程。这意味着我们可以通过Xcode这个功能来查看宏的作用，但是无法知道宏的具体实现。具体实现还是需要通过查看源码来分析。


ReactiveCocoa中的宏，如果不查看源码分析，会觉得那些宏都像魔法一样奇妙无比，接下来就来解开“宏”魔法的神秘面纱。


### 二. ReactiveCocoa 中的元宏

![](https://img.halfrost.com/Blog/ArticleImage/39_4.jpg)


在ReactiveCocoa的宏中，作者定义了这么一些基础的宏，作为“元宏”，它们是构成之后复杂宏的基础。在分析常用宏之前，必须要先分析清楚这些元宏的具体实现。

#### 1. metamacro\_stringify(VALUE)

```objectivec

#define metamacro_stringify(VALUE) \
        metamacro_stringify_(VALUE)

#define metamacro_stringify_(VALUE) # VALUE

```

metamacro\_stringify( )这个宏用到了#的用法。#在宏中代表把宏的参数变为一个字符串。这个宏的目的和它的名字一样明显，把入参VALUE转换成一个字符串返回。

这里可能就有人有疑问，为啥要包装一层，不能直接写成下面这样：

```objectivec

#define metamacro_stringify(VALUE)  # VALUE


```

语意确实也没有变，但是有种特殊情况下就会出现问题。


举个例子：

```objectivec

#define NUMBER   10
#define ADD(a,b) (a+b)
NSLog(@"%d+%d=%d",NUMBER, NUMBER, ADD(NUMBER,NUMBER));

```

输出如下：

```vim

10+10=20

```

这样子确实是没有问题，但是稍作修改就会有问题。

```objectivec

#define STRINGIFY(S) #S
#define CALCULATE(A,B)  (A##10##B)

NSLog(@"int max: %s",STRINGIFY(INT_MAX));
NSLog(@"%d", CALCULATE(NUMBER,NUMBER));

```

如果是这种情况下，第二个NSLog打印是会编译错误的。上面两句经过预编译之后，宏会被展开成下面这个样子：

```vim

NSLog(@"int max: %s","INT_MAX");
NSLog(@"%d", (NUMBER10NUMBER));

```

可以发现，宏并没有再次被展开。解决办法也很简单，就是把宏包装一层，写一个转接宏出来。

```objectivec

#define CALCULATE(A,B)   _CALCULATE(A,B)   // 转换宏
#define _CALCULATE(A,B)  A##10##B

```

再次测试一下，这里我们使用官方的metamacro\_stringify

```objectivec

NSLog(@"int max: %s",metamacro_stringify(INT_MAX));
NSLog(@"%d", CALCULATE(NUMBER,NUMBER));

```

这样最终打印出来的结果和我们想要的一致，没有问题。

```vim

2147483647
101010

```

CALCULATE(NUMBER,NUMBER) 第一层转换成 \_CALCULATE(10,10)，接着第二次转换成10##10##10，也就是101010。

当然这里是2层转换，如果有多层转换就需要更多个转换宏了。

```objectivec

NSLog(@"%d", CALCULATE(STRINGIFY(NUMBER),STRINGIFY(NUMBER)));


```


上面这个例子就是3层了，按照之前我们的写法还是编译报错。如果是超过2，3层的多层的情况，就该考虑考虑宏设计的语意的问题，尽量不让使用者产生错误的用法。



#### 2. metamacro\_concat(A, B)


```objectivec

#define metamacro_concat(A, B) \
        metamacro_concat_(A, B)
#define metamacro_concat_(A, B) A ## B

```

这个宏就是用来合并入参A，B到一起。在RAC里面主要用这个方法来合成另外一个宏的名字。


#### 3. metamacro\_argcount(...) 和 metamacro\_at(N, ...)

metamacro\_argcount(...)这个宏设计的也非常巧妙，它是用来获取参数个数的。由于宏展开是在预编译时期的，所以它在预编译时期获取参数个数的，其他非宏的方法都是在运行时获取参数个数的。

```objectivec

#define metamacro_argcount(...) \
        metamacro_at(20, __VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


```

这里会调用metamacro\_at(N, ...)宏。


```objectivec

#define metamacro_at(N, ...) \
        metamacro_concat(metamacro_at, N)(__VA_ARGS__)

```

把这个宏展开，于是得到：

```objectivec

#define metamacro_at(N, ...) \
        metamacro_atN(__VA_ARGS__)

```

于是通过metamacro\_concat合成命令，就得到了一连串的metamacro\_atN宏命令：


```objectivec

#define metamacro_at0(...) metamacro_head(__VA_ARGS__)
#define metamacro_at1(_0, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at2(_0, _1, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at3(_0, _1, _2, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at4(_0, _1, _2, _3, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at5(_0, _1, _2, _3, _4, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at6(_0, _1, _2, _3, _4, _5, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at7(_0, _1, _2, _3, _4, _5, _6, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at8(_0, _1, _2, _3, _4, _5, _6, _7, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at9(_0, _1, _2, _3, _4, _5, _6, _7, _8, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at10(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at11(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at12(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at13(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at14(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at15(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at16(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at17(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at18(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at19(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, ...) metamacro_head(__VA_ARGS__)
#define metamacro_at20(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ...) metamacro_head(__VA_ARGS__)



```

可见N的取值只能从0到20。

```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)
#define metamacro_head_(FIRST, ...) FIRST

```

metamacro\_head展开之后变成：

```objectivec

#define metamacro_head(FIRST,..., 0)  FIRST

```

metamacro\_head的意图就很明显，是用来获取后面可变入参的第一个参数。

回到metamacro\_atN宏上面来，那么把它展开就是下面这样：

```objectivec

#define metamacro_atN(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ... , _N, ...) metamacro_head(__VA_ARGS__)


```

当然，N的取值还是从0到20，那么metamacro\_atN宏获取到的值就是可变参数列表里面的第N个参数值。参数从0开始。


再回到最初的metamacro\_argcount(...)宏，目前展开到这一步：

```objectivec


#define metamacro_argcount(...) \
        metamacro_at20(__VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


```

由于\_\_VA\_ARGS\_\_个数不能超过20个，所以必定是在0-19之间。

```objectivec

metamacro_at20(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ..., 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1) metamacro_head(__VA_ARGS__)


```

假设入参是有5个：

```objectivec

metamacro_argcount(@"1",@"2",@"3",@"4",@"5");

```

先把5个参数放入metamacro\_at20的前五个位置。然后从第6个位置开始倒序插入20-1的数字。如下图：

![](https://img.halfrost.com/Blog/ArticleImage/39_5.png)



我们可以把倒序的数字想象成一把尺子，是用来衡量或者指示当前有多少个参数的。尺子的最左边对齐上面20个空位的第一位，尺子后面多出来的部分，取出来，然后进行metamacro\_head操作，取出第一位参数，这个数字就是整个参数的个数了。这把虚拟的“尺子”是会左右对齐的，具体的位置就要根据填入参数的个数来决定的。

这个宏的原理也很简单，20 - （ 20 - n ）= n。metamacro\_argcount(...) 宏就是这样在预编译时期获取到参数个数的。


作者也标明了，这个宏的设计灵感来自于[P99](http://p99.gforge.inria.fr)神库，有兴趣的同学可以去看看这个库。


#### 4. metamacro\_foreach(MACRO, SEP, ...) 和 metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)


先来分析分析metamacro\_foreach(MACRO, SEP, ...) 宏：

```objectivec

#define metamacro_foreach(MACRO, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

```

看到定义就知道metamacro\_foreach(MACRO, SEP, ...) 和 metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...) 是一样的作用。前者只不过比后者少了一个foreach的迭代子。

##### 1. metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏

再来看看metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏的定义。

```objectivec


#define metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)


```

那么之前的metamacro\_foreach(MACRO, SEP, ...)宏就可以等价于

```objectivec

metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

```

回到metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏的展开表达式上面来，假设\_\_VA\_ARGS\_\_的参数个数为N。

metamacro\_concat 宏 和 metamacro\_argcount 宏上面介绍过了，那么可以继续把宏展开成下面的样子：

```objectivec

metamacro_foreach_cxtN(MACRO, SEP, CONTEXT, __VA_ARGS__)

```

这里又是利用metamacro\_concat 宏动态的合并成了另一个宏的例子。

```objectivec

#define metamacro_foreach_cxt0(MACRO, SEP, CONTEXT)
#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)

#define metamacro_foreach_cxt2(MACRO, SEP, CONTEXT, _0, _1) \
    metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1)

#define metamacro_foreach_cxt3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    metamacro_foreach_cxt2(MACRO, SEP, CONTEXT, _0, _1) \
    SEP \
    MACRO(2, CONTEXT, _2)

#define metamacro_foreach_cxt4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    metamacro_foreach_cxt3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    SEP \
    MACRO(3, CONTEXT, _3)

#define metamacro_foreach_cxt5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    metamacro_foreach_cxt4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    SEP \
    MACRO(4, CONTEXT, _4)

#define metamacro_foreach_cxt6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    metamacro_foreach_cxt5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    SEP \
    MACRO(5, CONTEXT, _5)

#define metamacro_foreach_cxt7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    metamacro_foreach_cxt6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    SEP \
    MACRO(6, CONTEXT, _6)

#define metamacro_foreach_cxt8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    metamacro_foreach_cxt7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    SEP \
    MACRO(7, CONTEXT, _7)

#define metamacro_foreach_cxt9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    metamacro_foreach_cxt8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    SEP \
    MACRO(8, CONTEXT, _8)

#define metamacro_foreach_cxt10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    metamacro_foreach_cxt9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    SEP \
    MACRO(9, CONTEXT, _9)

#define metamacro_foreach_cxt11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    metamacro_foreach_cxt10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    SEP \
    MACRO(10, CONTEXT, _10)

#define metamacro_foreach_cxt12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    metamacro_foreach_cxt11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    SEP \
    MACRO(11, CONTEXT, _11)

#define metamacro_foreach_cxt13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    metamacro_foreach_cxt12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    SEP \
    MACRO(12, CONTEXT, _12)

#define metamacro_foreach_cxt14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    metamacro_foreach_cxt13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    SEP \
    MACRO(13, CONTEXT, _13)

#define metamacro_foreach_cxt15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    metamacro_foreach_cxt14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    SEP \
    MACRO(14, CONTEXT, _14)

#define metamacro_foreach_cxt16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    metamacro_foreach_cxt15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    SEP \
    MACRO(15, CONTEXT, _15)

#define metamacro_foreach_cxt17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    metamacro_foreach_cxt16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    SEP \
    MACRO(16, CONTEXT, _16)

#define metamacro_foreach_cxt18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    metamacro_foreach_cxt17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    SEP \
    MACRO(17, CONTEXT, _17)

#define metamacro_foreach_cxt19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    metamacro_foreach_cxt18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    SEP \
    MACRO(18, CONTEXT, _18)

#define metamacro_foreach_cxt20(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19) \
    metamacro_foreach_cxt19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    SEP \
    MACRO(19, CONTEXT, _19)



```


把上述的metamacro\_foreach\_cxtN的定义抽象一下：

```objectivec

#define metamacro_foreach_cxtN(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, … ,_N - 1) \
    metamacro_foreach_cxtN - 1(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, … ,_N - 2) \
    SEP \
    MACRO(N - 1, CONTEXT, _N - 1)


```

当然，在RAC中N的取值范围是[0,20]。我们还是假设N的定义域是全体非负整数组成的集合N(数学中的非负整数集合的标志) 。那么我们把metamacro\_foreach\_cxtN完全展开到不能展开为止：

```objectivec

    MACRO(0, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1) \
    SEP \
    MACRO(2, CONTEXT, _2) \
    SEP \
    MACRO(3, CONTEXT, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, CONTEXT, _N - 4) \
     SEP \
    MACRO(N - 3, CONTEXT, _N - 3) \
     SEP \
    MACRO(N - 2, CONTEXT, _N - 2) \
     SEP \
    MACRO(N - 1, CONTEXT, _N - 1)


```



metamacro\_foreach\_cxtN(MACRO, SEP, CONTEXT, ...)，这个宏的意图也就很明显了，从可变参数列表里面读取出个数，然后把每个参数都进行一次MACRO(N - 1, CONTEXT, _N - 1)操作，每个操作直接用SEP作为分隔符进行分隔。

metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)这个宏的设计灵感也来自于P99库。


![](https://img.halfrost.com/Blog/ArticleImage/39_6.png)



用到这个宏最著名的的宏就是weakify(...)了，下面来简要的看看是如何利用metamacro\_foreach\_cxtN(MACRO, SEP, CONTEXT, ...)巧妙的实现weakify(...)的。


```objectivec

#define weakify(...) \
    rac_keywordify \
    metamacro_foreach_cxt(rac_weakify_,, __weak, __VA_ARGS__)


```


使用weakify和平时我们自己写的weakSelf最大的区别就是，weakify后面是可以跟多个参数的，最多多达20个。weakify可以一口气把参数列表里面所有的参数都进行weak操作。


weakify(...)的重点之一就在metamacro\_foreach\_cxt操作上。假设传入2个参数，self和str，进行展开之后得到：

```objectivec


    MACRO(0, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1)

```

MACRO = rac\_weakify\_，CONTEXT =  \_\_weak，SEP 为 空格 ，代入参数：

```objectivec

 rac_weakify_(0,__weak,self) \
 rac_weakify_(1,__weak,str) 

```

注意，替换完成之后，两个宏是连在一起的，中间没有分号！分隔符SEP目前是空格。最后一步就是替换掉rac\_weakify\_：

```objectivec

#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

```

注意这里的INDEX是废参数，并没有被用到。

展开上面的宏：

```objectivec

__weak __typeof__(self) self_weak_ = (self)；__weak __typeof__(str) str_weak_ = (str)；


```

注意，rac\_weakify\_是自带分号的，如果此处没有分号，这里会出现编译错误。

最终@weakify(self，str) 就会在预编译期间被替换成

```objectivec


@autoreleasepool {} __weak __typeof__(self) self_weak_ = (self)；__weak __typeof__(str) str_weak_ = (str)；

```

注意中间是没有换行的，此处宏展开之后就是一行。



metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)分析完毕之后再回过来看看metamacro\_foreach(MACRO, SEP, ...)

##### 2. metamacro\_foreach(MACRO, SEP, ...)

```objectivec

metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)


```

此时同样可以假设参数个数为N，那么上述宏展开可以变成下面的样子：

```objectivec


metamacro_foreach_cxtN(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)


```

这里的MACRO = metamacro\_foreach\_iter，SEP = SEP ， CONTEXT = MACRO。

```objectivec

    metamacro_foreach_iter(0, MACRO, _0) \
    SEP \
    metamacro_foreach_iter(1, MACRO, _1) \
    SEP \
    metamacro_foreach_iter(2, MACRO, _2) \
    SEP \
    metamacro_foreach_iter(3, MACRO, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    metamacro_foreach_iter(N - 4, MACRO, _N - 4) \
     SEP \
    metamacro_foreach_iter(N - 3, MACRO, _N - 3) \
     SEP \
    metamacro_foreach_iter(N - 2, MACRO, _N - 2) \
     SEP \
    metamacro_foreach_iter(N - 1, MACRO, _N - 1)


```

metamacro\_foreach\_iter 定义如下：

```objectivec


#define metamacro_foreach_iter(INDEX, MACRO, ARG) MACRO(INDEX, ARG)


```

继续展开得到下面的式子：

```objectivec

    MACRO(0, _0) \
    SEP \
    MACRO(1, _1) \
    SEP \
    MACRO(2, _2) \
    SEP \
    MACRO(3, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, _N - 4) \
     SEP \
    MACRO(N - 3, _N - 3) \
     SEP \
    MACRO(N - 2, _N - 2) \
     SEP \
    MACRO(N - 1, _N - 1)


```

![](https://img.halfrost.com/Blog/ArticleImage/39_7.png)



从最终的展开式子上来看，metamacro\_foreach(MACRO, SEP, ...) 就比 metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...) 少了一个CONTEXT。

metamacro\_foreach(MACRO, SEP, ...)这个宏的典型例子就是熟知的strongify(...)的实现。


```objectivec


#define strongify(...) \
    rac_keywordify \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    metamacro_foreach(rac_strongify_,, __VA_ARGS__) \
    _Pragma("clang diagnostic pop")


```

通过上面的分析，我们直接替换结果，MACRO = rac\_strongify\_ ，SEP = 空格。

```objectivec

    rac_strongify_(0, _0) \
    rac_strongify_(1, _1) \
    rac_strongify_(2, _2) \
    rac_strongify_(3, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

    rac_strongify_(N - 4, _N - 4) \
    rac_strongify_(N - 3, _N - 3) \
    rac_strongify_(N - 2, _N - 2) \
    rac_strongify_(N - 1, _N - 1)


```

接下来替换掉rac\_strongify\_

```objectivec

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);


```

同样的，这里的INDEX也是一个废参数，也没有用到。rac\_strongify\_同样的自带分号，如果此处没有分号，SEP此时也是空格，编译就直接报错。

最终就转换成如下的样子：

```objectivec

__strong __typeof__(self) self = self_weak_;


```


#### 5. metamacro\_foreach\_cxt\_recursive(MACRO, SEP, CONTEXT, ...)

先来看看定义：

```objectivec

#define metamacro_foreach_cxt_recursive(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt_recursive, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)



```

假设可变参数个数为N，将上面式子展开：

```objectivec


#define metamacro_foreach_cxt_recursive(MACRO, SEP, CONTEXT, ...) \
        metamacro_foreach_cxt_recursiveN(MACRO, SEP, CONTEXT, __VA_ARGS__)

```

于是就转换成了metamacro\_foreach\_cxt\_recursiveN 宏：

```objectivec


#define metamacro_foreach_cxt_recursive0(MACRO, SEP, CONTEXT)
#define metamacro_foreach_cxt_recursive1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)

#define metamacro_foreach_cxt_recursive2(MACRO, SEP, CONTEXT, _0, _1) \
    metamacro_foreach_cxt_recursive1(MACRO, SEP, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1)

#define metamacro_foreach_cxt_recursive3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    metamacro_foreach_cxt_recursive2(MACRO, SEP, CONTEXT, _0, _1) \
    SEP \
    MACRO(2, CONTEXT, _2)

#define metamacro_foreach_cxt_recursive4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    metamacro_foreach_cxt_recursive3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    SEP \
    MACRO(3, CONTEXT, _3)

#define metamacro_foreach_cxt_recursive5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    metamacro_foreach_cxt_recursive4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    SEP \
    MACRO(4, CONTEXT, _4)

#define metamacro_foreach_cxt_recursive6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    metamacro_foreach_cxt_recursive5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    SEP \
    MACRO(5, CONTEXT, _5)

#define metamacro_foreach_cxt_recursive7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    metamacro_foreach_cxt_recursive6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    SEP \
    MACRO(6, CONTEXT, _6)

#define metamacro_foreach_cxt_recursive8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    metamacro_foreach_cxt_recursive7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    SEP \
    MACRO(7, CONTEXT, _7)

#define metamacro_foreach_cxt_recursive9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    metamacro_foreach_cxt_recursive8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    SEP \
    MACRO(8, CONTEXT, _8)

#define metamacro_foreach_cxt_recursive10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    metamacro_foreach_cxt_recursive9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    SEP \
    MACRO(9, CONTEXT, _9)

#define metamacro_foreach_cxt_recursive11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    metamacro_foreach_cxt_recursive10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    SEP \
    MACRO(10, CONTEXT, _10)

#define metamacro_foreach_cxt_recursive12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    metamacro_foreach_cxt_recursive11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    SEP \
    MACRO(11, CONTEXT, _11)

#define metamacro_foreach_cxt_recursive13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    metamacro_foreach_cxt_recursive12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    SEP \
    MACRO(12, CONTEXT, _12)

#define metamacro_foreach_cxt_recursive14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    metamacro_foreach_cxt_recursive13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    SEP \
    MACRO(13, CONTEXT, _13)

#define metamacro_foreach_cxt_recursive15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    metamacro_foreach_cxt_recursive14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    SEP \
    MACRO(14, CONTEXT, _14)

#define metamacro_foreach_cxt_recursive16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    metamacro_foreach_cxt_recursive15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    SEP \
    MACRO(15, CONTEXT, _15)

#define metamacro_foreach_cxt_recursive17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    metamacro_foreach_cxt_recursive16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    SEP \
    MACRO(16, CONTEXT, _16)

#define metamacro_foreach_cxt_recursive18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    metamacro_foreach_cxt_recursive17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    SEP \
    MACRO(17, CONTEXT, _17)

#define metamacro_foreach_cxt_recursive19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    metamacro_foreach_cxt_recursive18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    SEP \
    MACRO(18, CONTEXT, _18)

#define metamacro_foreach_cxt_recursive20(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19) \
    metamacro_foreach_cxt_recursive19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    SEP \
    MACRO(19, CONTEXT, _19)


```

提取一下metamacro_foreach_cxt_recursiveN的定义：

```objectivec

#define metamacro_foreach_cxt_recursiveN(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, … ，_( N - 1)) \
        metamacro_foreach_cxt_recursive(N - 1)(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _( N - 2)) \
        SEP \
        MACRO(N -1, CONTEXT, _N -1)

```

还是按照之前分析的，同理完全展开：

```objectivec

    MACRO(0, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1) \
    SEP \
    MACRO(2, CONTEXT, _2) \
    SEP \
    MACRO(3, CONTEXT, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, CONTEXT, _N - 4) \
     SEP \
    MACRO(N - 3, CONTEXT, _N - 3) \
     SEP \
    MACRO(N - 2, CONTEXT, _N - 2) \
     SEP \
    MACRO(N - 1, CONTEXT, _N - 1)



```

至此，展开式与metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏完全相同。

这个递归的宏从来没有在RAC的其他宏中使用，作者在这里标注说明了这个宏的用处。

> This can be used when the former would fail due to recursive macro expansion

由于宏在递归展开中可能会导致递归前置条件失败，在这种情况下，应该使用这个递归宏。当然，它的效果和metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏是完全一样的。

#### 6. metamacro\_foreach\_concat(BASE, SEP, ...)

这个宏定义是套用了metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏的实现，只是多传入了一些参数。由此可见，metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏在RAC中的重要性。

```objectivec

#define metamacro_foreach_concat(BASE, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_concat_iter, SEP, BASE, __VA_ARGS__)


```

由于在上面详细分析过了metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...)宏的实现，那么这里就直接完全展开到最后一步。MACRO = metamacro\_foreach\_concat\_iter，SEP = SEP，CONTEXT = BASE。

```objectivec

    metamacro_foreach_concat_iter(0, BASE, _0) \
    SEP \
    metamacro_foreach_concat_iter(1, BASE, _1) \
    SEP \
    metamacro_foreach_concat_iter(2, BASE, _2) \
    SEP \
    metamacro_foreach_concat_iter(3, BASE, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    metamacro_foreach_concat_iter(N - 4, BASE, _N - 4) \
     SEP \
    metamacro_foreach_concat_iter(N - 3, BASE, _N - 3) \
     SEP \
    metamacro_foreach_concat_iter(N - 2, BASE, _N - 2) \
     SEP \
    metamacro_foreach_concat_iter(N - 1, BASE, _N - 1)



```

到了这一步，就需要继续展开metamacro\_foreach\_concat\_iter

```objectivec

#define metamacro_foreach_concat_iter(INDEX, BASE, ARG) metamacro_foreach_concat_iter_(BASE, ARG)

#define metamacro_foreach_concat_iter_(BASE, ARG) BASE ## ARG


```

这里的2个宏，就用到了之前说道的转接宏的概念，因为需要把第一个参数剔除，所以需要写一个转接宏，转换一次踢掉第一个参数。

最终完全展开就是下面的样子：

```objectivec

    BASE_0 \
    SEP \
    BASE_1 \
    SEP \
    BASE_2 \
    SEP \
    BASE_3 \
     ……
     ……
     ……
     ……
     ……
     ……

    SEP \
    BASE_N - 4 \
    SEP \
    BASE_N - 3 \
    SEP \
    BASE_N - 2 \
    SEP \
    BASE_N - 1



```

metamacro\_foreach\_concat(BASE, SEP, ...)宏如同它的名字一样，把可变参数里面每个参数都拼接到BASE后面，每个参数拼接完成之间都用SEP分隔。

试想一种场景：

如果有一连串的方法，方法名都有一个相同的前缀，后面是不同的。这种场景下，利用metamacro\_foreach\_concat(BASE, SEP, ...)宏是非常爽的，它会一口气组合出相关的一列表的不同的宏。


#### 7. metamacro\_for\_cxt(COUNT, MACRO, SEP, CONTEXT)


定义如下：


```objectivec

#define metamacro_for_cxt(COUNT, MACRO, SEP, CONTEXT) \
        metamacro_concat(metamacro_for_cxt, COUNT)(MACRO, SEP, CONTEXT)


```

metamacro\_concat 之前分析过，展开这一层：

```objectivec


metamacro_for_cxtN(MACRO, SEP, CONTEXT)


```

metamacro\_for\_cxtN的定义如下：


```objectivec

#define metamacro_for_cxt0(MACRO, SEP, CONTEXT)
#define metamacro_for_cxt1(MACRO, SEP, CONTEXT) MACRO(0, CONTEXT)

#define metamacro_for_cxt2(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt1(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(1, CONTEXT)

#define metamacro_for_cxt3(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt2(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(2, CONTEXT)

#define metamacro_for_cxt4(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt3(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(3, CONTEXT)

#define metamacro_for_cxt5(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt4(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(4, CONTEXT)

#define metamacro_for_cxt6(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt5(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(5, CONTEXT)

#define metamacro_for_cxt7(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt6(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(6, CONTEXT)

#define metamacro_for_cxt8(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt7(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(7, CONTEXT)

#define metamacro_for_cxt9(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt8(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(8, CONTEXT)

#define metamacro_for_cxt10(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt9(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(9, CONTEXT)

#define metamacro_for_cxt11(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt10(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(10, CONTEXT)

#define metamacro_for_cxt12(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt11(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(11, CONTEXT)

#define metamacro_for_cxt13(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt12(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(12, CONTEXT)

#define metamacro_for_cxt14(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt13(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(13, CONTEXT)

#define metamacro_for_cxt15(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt14(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(14, CONTEXT)

#define metamacro_for_cxt16(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt15(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(15, CONTEXT)

#define metamacro_for_cxt17(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt16(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(16, CONTEXT)

#define metamacro_for_cxt18(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt17(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(17, CONTEXT)

#define metamacro_for_cxt19(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt18(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(18, CONTEXT)

#define metamacro_for_cxt20(MACRO, SEP, CONTEXT) \
    metamacro_for_cxt19(MACRO, SEP, CONTEXT) \
    SEP \
    MACRO(19, CONTEXT)



```

提取一下metamacro\_for\_cxtN的定义：

```objectivec


#define metamacro_for_cxtN(MACRO, SEP, CONTEXT) \
        metamacro_for_cxtN - 1(MACRO, SEP, CONTEXT) \
        SEP \
        MACRO(N - 1, CONTEXT)

```

把metamacro\_for\_cxtN完全展开如下：


```objectivec


    MACRO(0, CONTEXT) \
    SEP \
    MACRO(1, CONTEXT) \
    SEP \
    MACRO(2, CONTEXT) \
    SEP \
    MACRO(3, CONTEXT) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, CONTEXT) \
     SEP \
    MACRO(N - 3, CONTEXT) \
     SEP \
    MACRO(N - 2, CONTEXT) \
     SEP \
    MACRO(N - 1, CONTEXT)


```


这个宏的用途是执行COUNT次MACRO宏命令，每次MACRO宏命令的第一个参数都会从COUNT开始递减到0。

#### 8. metamacro\_head(...)

这个宏要求它的可变参数至少为1个。

```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)


```

把宏展开，如下：

```objectivec

#define metamacro_head_(FIRST, ...) FIRST


```

metamacro\_head(...) 的作用就是取出可变参数列表的第一个参数。


#### 9. metamacro\_tail(...)

这个宏要求它的可变参数至少为2个。

```objectivec

#define metamacro_tail(...) \
        metamacro_tail_(__VA_ARGS__)


```

把宏展开，如下：

```objectivec

#define metamacro_tail_(FIRST, ...) __VA_ARGS__


```

metamacro\_tail(...) 的作用就是取出可变参数列表除去第一个参数以外的所有参数。

#### 10. metamacro\_take(N, ...)


这个宏要求它的可变参数至少有N个。

```objectivec


#define metamacro_take(N, ...) \
        metamacro_concat(metamacro_take, N)(__VA_ARGS__)

```

展开成如下的样子：

```objectivec


metamacro_takeN(__VA_ARGS__)

```

继续展开metamacro\_takeN：

```objectivec

#define metamacro_take0(...)
#define metamacro_take1(...) metamacro_head(__VA_ARGS__)
#define metamacro_take2(...) metamacro_head(__VA_ARGS__), metamacro_take1(metamacro_tail(__VA_ARGS__))
#define metamacro_take3(...) metamacro_head(__VA_ARGS__), metamacro_take2(metamacro_tail(__VA_ARGS__))
#define metamacro_take4(...) metamacro_head(__VA_ARGS__), metamacro_take3(metamacro_tail(__VA_ARGS__))
#define metamacro_take5(...) metamacro_head(__VA_ARGS__), metamacro_take4(metamacro_tail(__VA_ARGS__))
#define metamacro_take6(...) metamacro_head(__VA_ARGS__), metamacro_take5(metamacro_tail(__VA_ARGS__))
#define metamacro_take7(...) metamacro_head(__VA_ARGS__), metamacro_take6(metamacro_tail(__VA_ARGS__))
#define metamacro_take8(...) metamacro_head(__VA_ARGS__), metamacro_take7(metamacro_tail(__VA_ARGS__))
#define metamacro_take9(...) metamacro_head(__VA_ARGS__), metamacro_take8(metamacro_tail(__VA_ARGS__))
#define metamacro_take10(...) metamacro_head(__VA_ARGS__), metamacro_take9(metamacro_tail(__VA_ARGS__))
#define metamacro_take11(...) metamacro_head(__VA_ARGS__), metamacro_take10(metamacro_tail(__VA_ARGS__))
#define metamacro_take12(...) metamacro_head(__VA_ARGS__), metamacro_take11(metamacro_tail(__VA_ARGS__))
#define metamacro_take13(...) metamacro_head(__VA_ARGS__), metamacro_take12(metamacro_tail(__VA_ARGS__))
#define metamacro_take14(...) metamacro_head(__VA_ARGS__), metamacro_take13(metamacro_tail(__VA_ARGS__))
#define metamacro_take15(...) metamacro_head(__VA_ARGS__), metamacro_take14(metamacro_tail(__VA_ARGS__))
#define metamacro_take16(...) metamacro_head(__VA_ARGS__), metamacro_take15(metamacro_tail(__VA_ARGS__))
#define metamacro_take17(...) metamacro_head(__VA_ARGS__), metamacro_take16(metamacro_tail(__VA_ARGS__))
#define metamacro_take18(...) metamacro_head(__VA_ARGS__), metamacro_take17(metamacro_tail(__VA_ARGS__))
#define metamacro_take19(...) metamacro_head(__VA_ARGS__), metamacro_take18(metamacro_tail(__VA_ARGS__))
#define metamacro_take20(...) metamacro_head(__VA_ARGS__), metamacro_take19(metamacro_tail(__VA_ARGS__))


```


![](https://img.halfrost.com/Blog/ArticleImage/39_8.png)






这里也用到了递归的思想，每次取完头以后，剩下的队列针对于此次是tail，对于下次是head。所以每次都取head，之后再递归的取剩下部分的head，直到取出前N个数为止。

metamacro\_take(N, ...)的作用就是取出可变参数的前N个数，并把它们组合成新的参数列表。

#### 11. metamacro\_drop(N, ...)


这个宏要求它的可变参数至少为N个。

```objectivec

#define metamacro_drop(N, ...) \
        metamacro_concat(metamacro_drop, N)(__VA_ARGS__)

```

展开成如下的样子：

```objectivec


metamacro_dropN(__VA_ARGS__)

```

继续展开metamacro\_dropN：

```objectivec


#define metamacro_drop0(...) __VA_ARGS__
#define metamacro_drop1(...) metamacro_tail(__VA_ARGS__)
#define metamacro_drop2(...) metamacro_drop1(metamacro_tail(__VA_ARGS__))
#define metamacro_drop3(...) metamacro_drop2(metamacro_tail(__VA_ARGS__))
#define metamacro_drop4(...) metamacro_drop3(metamacro_tail(__VA_ARGS__))
#define metamacro_drop5(...) metamacro_drop4(metamacro_tail(__VA_ARGS__))
#define metamacro_drop6(...) metamacro_drop5(metamacro_tail(__VA_ARGS__))
#define metamacro_drop7(...) metamacro_drop6(metamacro_tail(__VA_ARGS__))
#define metamacro_drop8(...) metamacro_drop7(metamacro_tail(__VA_ARGS__))
#define metamacro_drop9(...) metamacro_drop8(metamacro_tail(__VA_ARGS__))
#define metamacro_drop10(...) metamacro_drop9(metamacro_tail(__VA_ARGS__))
#define metamacro_drop11(...) metamacro_drop10(metamacro_tail(__VA_ARGS__))
#define metamacro_drop12(...) metamacro_drop11(metamacro_tail(__VA_ARGS__))
#define metamacro_drop13(...) metamacro_drop12(metamacro_tail(__VA_ARGS__))
#define metamacro_drop14(...) metamacro_drop13(metamacro_tail(__VA_ARGS__))
#define metamacro_drop15(...) metamacro_drop14(metamacro_tail(__VA_ARGS__))
#define metamacro_drop16(...) metamacro_drop15(metamacro_tail(__VA_ARGS__))
#define metamacro_drop17(...) metamacro_drop16(metamacro_tail(__VA_ARGS__))
#define metamacro_drop18(...) metamacro_drop17(metamacro_tail(__VA_ARGS__))
#define metamacro_drop19(...) metamacro_drop18(metamacro_tail(__VA_ARGS__))
#define metamacro_drop20(...) metamacro_drop19(metamacro_tail(__VA_ARGS__))


```


![](https://img.halfrost.com/Blog/ArticleImage/39_9.png)


这里也用到了递归的思想，每次都取当前队列的tail，每次都丢掉当前队列的head。这样递归N次就丢掉了前N位参数。


metamacro\_drop(N, ...)的作用是丢掉当前参数列表里面的前N位参数。




#### 12. metamacro\_dec(VAL) 和 metamacro\_inc(VAL)

这两个宏是一对。它们在元编程中，处理计数和index方面及其有用。VAL的值域都是[0,20]。

```objectivec

#define metamacro_dec(VAL) \
        metamacro_at(VAL, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19)



```

metamacro\_dec(VAL) 提供了一个被左移一位的[0,20]的序列。那么通过metamacro\_at计算出来的结果就比原来的结果小1。从而达到了减一的目的。


```objectivec

#define metamacro_inc(VAL) \
        metamacro_at(VAL, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21)


```

metamacro\_inc(VAL) 提供了一个被右移一位的[0,20]的序列。那么通过metamacro\_at计算出来的结果就比原来的结果大1。从而达到了加一的目的。


#### 13. metamacro\_if\_eq(A, B)

首先A 和 B的值域都为[0,20]，并且B要大于等于A，即0<=A<=B<=20。

```objectivec

#define metamacro_if_eq(A, B) \
        metamacro_concat(metamacro_if_eq, A)(B)


```

如果当A不等于0的时候，将上面的式子展开：


```objectivec


#define metamacro_if_eq(A, B) \
        metamacro_if_eqA(B)


```

再继续把metamacro\_if\_eqA展开：


```objectivec


#define metamacro_if_eq1(VALUE) metamacro_if_eq0(metamacro_dec(VALUE))
#define metamacro_if_eq2(VALUE) metamacro_if_eq1(metamacro_dec(VALUE))
#define metamacro_if_eq3(VALUE) metamacro_if_eq2(metamacro_dec(VALUE))
#define metamacro_if_eq4(VALUE) metamacro_if_eq3(metamacro_dec(VALUE))
#define metamacro_if_eq5(VALUE) metamacro_if_eq4(metamacro_dec(VALUE))
#define metamacro_if_eq6(VALUE) metamacro_if_eq5(metamacro_dec(VALUE))
#define metamacro_if_eq7(VALUE) metamacro_if_eq6(metamacro_dec(VALUE))
#define metamacro_if_eq8(VALUE) metamacro_if_eq7(metamacro_dec(VALUE))
#define metamacro_if_eq9(VALUE) metamacro_if_eq8(metamacro_dec(VALUE))
#define metamacro_if_eq10(VALUE) metamacro_if_eq9(metamacro_dec(VALUE))
#define metamacro_if_eq11(VALUE) metamacro_if_eq10(metamacro_dec(VALUE))
#define metamacro_if_eq12(VALUE) metamacro_if_eq11(metamacro_dec(VALUE))
#define metamacro_if_eq13(VALUE) metamacro_if_eq12(metamacro_dec(VALUE))
#define metamacro_if_eq14(VALUE) metamacro_if_eq13(metamacro_dec(VALUE))
#define metamacro_if_eq15(VALUE) metamacro_if_eq14(metamacro_dec(VALUE))
#define metamacro_if_eq16(VALUE) metamacro_if_eq15(metamacro_dec(VALUE))
#define metamacro_if_eq17(VALUE) metamacro_if_eq16(metamacro_dec(VALUE))
#define metamacro_if_eq18(VALUE) metamacro_if_eq17(metamacro_dec(VALUE))
#define metamacro_if_eq19(VALUE) metamacro_if_eq18(metamacro_dec(VALUE))
#define metamacro_if_eq20(VALUE) metamacro_if_eq19(metamacro_dec(VALUE))


```

上面是一个递推的式子，最终肯定会得到metamacro\_if\_eq0，最终的结果就是：

```objectivec


metamacro_if_eq0(B - A)


```

再把metamacro\_if\_eq0展开：

```objectivec

#define metamacro_if_eq0(VALUE) \
        metamacro_concat(metamacro_if_eq0_, VALUE)


```

得到最终的展开式子：

```objectivec


metamacro_if_eq0_(B - A)

```


再查表得到最终结果：

```objectivec


#define metamacro_if_eq0_0(...) __VA_ARGS__ metamacro_consume_
#define metamacro_if_eq0_1(...) metamacro_expand_
#define metamacro_if_eq0_2(...) metamacro_expand_
#define metamacro_if_eq0_3(...) metamacro_expand_
#define metamacro_if_eq0_4(...) metamacro_expand_
#define metamacro_if_eq0_5(...) metamacro_expand_
#define metamacro_if_eq0_6(...) metamacro_expand_
#define metamacro_if_eq0_7(...) metamacro_expand_
#define metamacro_if_eq0_8(...) metamacro_expand_
#define metamacro_if_eq0_9(...) metamacro_expand_
#define metamacro_if_eq0_10(...) metamacro_expand_
#define metamacro_if_eq0_11(...) metamacro_expand_
#define metamacro_if_eq0_12(...) metamacro_expand_
#define metamacro_if_eq0_13(...) metamacro_expand_
#define metamacro_if_eq0_14(...) metamacro_expand_
#define metamacro_if_eq0_15(...) metamacro_expand_
#define metamacro_if_eq0_16(...) metamacro_expand_
#define metamacro_if_eq0_17(...) metamacro_expand_
#define metamacro_if_eq0_18(...) metamacro_expand_
#define metamacro_if_eq0_19(...) metamacro_expand_
#define metamacro_if_eq0_20(...) metamacro_expand_

```


上面这张表有两点注意点：

1. 除了0\_0，其他的都是metamacro\_expand\_。

```objectivec

#define metamacro_consume_(...)
#define metamacro_expand_(...) __VA_ARGS__


```
除了0\_0以外，其他所有操作都是直接透传参数，什么也不处理。metamacro\_consume\_(...)就是直接吞掉后续的参数。expand就是指的是可以继续展开宏，consume就是指的是终止展开宏，并吃掉后面的参数。

举2个例子：

```objectivec

// 第一个例子
metamacro_if_eq(0, 0)(true)(false)

// 第二个例子
metamacro_if_eq(0, 1)(true)(false)



```

直接套用最终展开式：

```objectivec

// 第一个例子
metamacro_if_eq0_0(true)(false)

// 第二个例子
metamacro_if_eq0_1(true)(false)


```

继续展开：


```objectivec

// 第一个例子
true metamacro_consume_(false) => true

// 第二个例子
metamacro_expand_(false) => false


```


这个如果 B < A，那么(B - A) < 0，那么最终展开的式子就变成下面的样子：

```objectivec


metamacro_if_eq0_(负数)


```

这个宏展开到这个程度就没法继续下去了，就会出现编译错误。


#### 14. metamacro\_if\_eq\_recursive(A, B)

A 和 B的值域都为[0,20]，并且B要大于等于A，即0<=A<=B<=20。


定义如下：

```objectivec


#define metamacro_if_eq_recursive(A, B) \
        metamacro_concat(metamacro_if_eq_recursive, A)(B)


```

展开之后：


```objectivec

metamacro_if_eq_recursiveA(B)

```

继续展开：


```objectivec

#define metamacro_if_eq_recursive1(VALUE) metamacro_if_eq_recursive0(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive2(VALUE) metamacro_if_eq_recursive1(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive3(VALUE) metamacro_if_eq_recursive2(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive4(VALUE) metamacro_if_eq_recursive3(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive5(VALUE) metamacro_if_eq_recursive4(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive6(VALUE) metamacro_if_eq_recursive5(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive7(VALUE) metamacro_if_eq_recursive6(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive8(VALUE) metamacro_if_eq_recursive7(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive9(VALUE) metamacro_if_eq_recursive8(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive10(VALUE) metamacro_if_eq_recursive9(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive11(VALUE) metamacro_if_eq_recursive10(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive12(VALUE) metamacro_if_eq_recursive11(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive13(VALUE) metamacro_if_eq_recursive12(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive14(VALUE) metamacro_if_eq_recursive13(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive15(VALUE) metamacro_if_eq_recursive14(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive16(VALUE) metamacro_if_eq_recursive15(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive17(VALUE) metamacro_if_eq_recursive16(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive18(VALUE) metamacro_if_eq_recursive17(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive19(VALUE) metamacro_if_eq_recursive18(metamacro_dec(VALUE))
#define metamacro_if_eq_recursive20(VALUE) metamacro_if_eq_recursive19(metamacro_dec(VALUE))



```


最终肯定会得到metamacro\_if\_eq\_recursive0\_，最终的结果就是：

```objectivec


metamacro_if_eq_recursive0_(B - A)


```

再把metamacro\_if\_eq\_recursive0\_展开：


```objectivec


#define metamacro_if_eq_recursive0(VALUE) \
    metamacro_concat(metamacro_if_eq_recursive0_, VALUE)


```

得到最终的式子：


```objectivec


metamacro_if_eq_recursive0_(B - A)


```


最终再比对下表：


```objectivec


#define metamacro_if_eq_recursive0_0(...) __VA_ARGS__ metamacro_consume_
#define metamacro_if_eq_recursive0_1(...) metamacro_expand_
#define metamacro_if_eq_recursive0_2(...) metamacro_expand_
#define metamacro_if_eq_recursive0_3(...) metamacro_expand_
#define metamacro_if_eq_recursive0_4(...) metamacro_expand_
#define metamacro_if_eq_recursive0_5(...) metamacro_expand_
#define metamacro_if_eq_recursive0_6(...) metamacro_expand_
#define metamacro_if_eq_recursive0_7(...) metamacro_expand_
#define metamacro_if_eq_recursive0_8(...) metamacro_expand_
#define metamacro_if_eq_recursive0_9(...) metamacro_expand_
#define metamacro_if_eq_recursive0_10(...) metamacro_expand_
#define metamacro_if_eq_recursive0_11(...) metamacro_expand_
#define metamacro_if_eq_recursive0_12(...) metamacro_expand_
#define metamacro_if_eq_recursive0_13(...) metamacro_expand_
#define metamacro_if_eq_recursive0_14(...) metamacro_expand_
#define metamacro_if_eq_recursive0_15(...) metamacro_expand_
#define metamacro_if_eq_recursive0_16(...) metamacro_expand_
#define metamacro_if_eq_recursive0_17(...) metamacro_expand_
#define metamacro_if_eq_recursive0_18(...) metamacro_expand_
#define metamacro_if_eq_recursive0_19(...) metamacro_expand_
#define metamacro_if_eq_recursive0_20(...) metamacro_expand_


```

接下来就和metamacro\_if\_eq(A, B)宏完全一样了。



这个递归的宏也从来没有在RAC的其他宏中使用，作者在这里标注说明了这个宏的用处。

> This can be used when the former would fail due to recursive macro expansion

由于宏在递归展开中可能会导致递归前置条件失败，在这种情况下，应该使用这个递归宏。当然，它的效果和metamacro\_if\_eq(A, B)宏是完全一样的。


#### 15. metamacro\_is\_even(N)


定义如下：

N的值域在[0,20]之间。


```objectivec

#define metamacro_is_even(N) \
        metamacro_at(N, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1)



```

这个宏比较简单，就是判断N是不是偶数，下面metamacro\_at把所有从0-20的自然数是偶数的都标志成了1，是奇数的都标志成了0。0在这里默认是偶数。


#### 16. metamacro\_not(B)

这里B的取值只能是0或者1。

```objectivec


#define metamacro_not(B) \
        metamacro_at(B, 1, 0)


```

这个宏很简单，就是对参数逻辑取非运算。



### 三. ReactiveCocoa 中常用的宏


![](https://img.halfrost.com/Blog/ArticleImage/39_10.png)



上一章节我们分析完了ReactiveCocoa中所有的元宏，这一章节将会把元宏以外的宏的实现都分析一遍。包括我们日常使用的常见的所有宏，它们看似神秘，但是他们都是由这些元宏来组成的。

#### 1. weakify(...)、unsafeify(...)、strongify(...)

这三个在ReactiveCocoa一定是使用最多的，那么就先来分析这三个。这三个宏的定义在RACEXTScope.h中。

关于weakify(...)和strongify(...)，这两个宏的实现分析在之前的文章里面详细分析过了，详情可以看这篇文章[《深入研究Block用weakSelf、strongSelf、@weakify、@strongify解决循环引用》](http://www.jianshu.com/p/701da54bd78c)。


这里需要再次强调的一点是，在使用weakify(...)、unsafeify(...)、strongify(...)这三个宏的前面需要额外添加@符号。原因是在这三个宏的实现里面都有rac\_keywordify，它的实现如下：


```objectivec

#if DEBUG
#define rac_keywordify autoreleasepool {}
#else
#define rac_keywordify try {} @catch (...) {}
#endif


```

不管是在什么环境下，autoreleasepool  {} 和 try {} @catch (...) {} 前面都要添加@符号，变成@autoreleasepool  {} 和 @try {} @catch (...) {} 才可以继续使用。


既然@weakify(...)，@strongify(...)都分析过了，那么这里就分析一下@unsafeify(...)的实现。

```objectivec

#define unsafeify(...) \
        rac_keywordify \
        metamacro_foreach_cxt(rac_weakify_,, __unsafe_unretained, __VA_ARGS__)



```

rac\_keywordify上面说过了，这里就直接展开metamacro\_foreach\_cxt宏。这里就套用之前元宏的分析，直接拿到最终展开表达式：

```objectivec

    MACRO(0, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1) \
    SEP \
    MACRO(2, CONTEXT, _2) \
    SEP \
    MACRO(3, CONTEXT, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, CONTEXT, _N - 4) \
     SEP \
    MACRO(N - 3, CONTEXT, _N - 3) \
     SEP \
    MACRO(N - 2, CONTEXT, _N - 2) \
     SEP \
    MACRO(N - 1, CONTEXT, _N - 1)

```

MACRO = rac\_weakify\_，SEP = 空格，CONTEXT = \_\_unsafe\_unretained。代入得到最终的展开式：

```objectivec


    rac_weakify_(0,  __unsafe_unretained, _0) \
    rac_weakify_(1,  __unsafe_unretained, _1) \
    rac_weakify_(2,  __unsafe_unretained, _2) \
    rac_weakify_(3,  __unsafe_unretained, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

    rac_weakify_(N - 4,  __unsafe_unretained, _N - 4) \
    rac_weakify_(N - 3,  __unsafe_unretained, _N - 3) \
    rac_weakify_(N - 2,  __unsafe_unretained, _N - 2) \
    rac_weakify_(N - 1,  __unsafe_unretained, _N - 1)

```

把rac\_weakify\_再替换掉：

```objectivec

#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);


```

得到最终的展开表达式：

```objectivec


__unsafe_unretained  __typeof__(_0) _0_weak_ = _0；
__unsafe_unretained  __typeof__(_1) _1_weak_ = _1；
__unsafe_unretained  __typeof__(_2) _2_weak_ = _2；
     ……
     ……
     ……
     ……
     ……
     ……
__unsafe_unretained  __typeof__(_N - 3) _N - 3_weak_ = _N - 3；
__unsafe_unretained  __typeof__(_N - 2) _N - 2_weak_ = _N - 2；
__unsafe_unretained  __typeof__(_N - 1) _N - 1_weak_ = _N - 1；



```


其中 _0， _1， _2 …… _N - 3， _N - 2， _N - 1是 \_\_VA\_ARGS\_\_里面对应的是0 - N的参数值。


#### 2. RACTuplePack(...) 和 RACTupleUnpack(...)

这两个在ReactiveCocoa中也是非常常见的宏，专门用在RACTuple中。

先看RACTuplePack(...)

```objectivec

#define RACTuplePack(...) \
        RACTuplePack_(__VA_ARGS__)

```


再展开一步：


```objectivec

#define RACTuplePack_(...) \
        ([RACTuple tupleWithObjectsFromArray:@[ metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) ]])


```

这里调用了RACTuple的tupleWithObjectsFromArray:方法。主要需要展开的是：

```objectivec

metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) 


```

直接调用上一章节中metamacro\_foreach的最终表达式：

```objectivec


    MACRO(0, _0) \
    SEP \
    MACRO(1, _1) \
    SEP \
    MACRO(2, _2) \
    SEP \
    MACRO(3, _3) \
     ……
     ……
     ……
     ……
     ……
     ……

     SEP \
    MACRO(N - 4, _N - 4) \
     SEP \
    MACRO(N - 3, _N - 3) \
     SEP \
    MACRO(N - 2, _N - 2) \
     SEP \
    MACRO(N - 1, _N - 1)



```

MACRO = RACTuplePack\_object\_or\_ractuplenil ， SEP = 空格，替换之后如下：

```objectivec

RACTuplePack_object_or_ractuplenil(0, _0) \
RACTuplePack_object_or_ractuplenil(1, _1) \
RACTuplePack_object_or_ractuplenil(2, _2) \
     ……
     ……
     ……
     ……
     ……
     ……
RACTuplePack_object_or_ractuplenil( N - 3, _N - 3) \
RACTuplePack_object_or_ractuplenil( N - 2, _N - 2) \
RACTuplePack_object_or_ractuplenil( N - 1, _N - 1) 

```

最后一步就是替换掉RACTuplePack\_object\_or\_ractuplenil：

```objectivec

#define RACTuplePack_object_or_ractuplenil(INDEX, ARG) \
    (ARG) ?: RACTupleNil.tupleNil,

```

注意这里宏结尾是“，”逗号，而不是“；”分号，原因是因为tupleWithObjectsFromArray:方法里面是各个元素，所以这里用“；”分号就会出错，反而应该用“，”逗号，可见设计宏的时候需要考虑清楚使用场景，不能乱写。

展开上面最后一层宏之后，原可变参数列表里面的所有非nil的值就都排列到了tupleWithObjectsFromArray:方法里面了，如果是nil的，就会变成RACTupleNil.tupleNil放进Array里面。



再来看看RACTupleUnpack(...)


```objectivec

#define RACTupleUnpack(...) \
        RACTupleUnpack_(__VA_ARGS__)


```

再展开一步：

```objectivec

#define RACTupleUnpack_(...) \
    metamacro_foreach(RACTupleUnpack_decl,, __VA_ARGS__) \
    \
    int RACTupleUnpack_state = 0; \
    \
    RACTupleUnpack_after: \
        ; \
        metamacro_foreach(RACTupleUnpack_assign,, __VA_ARGS__) \
        if (RACTupleUnpack_state != 0) RACTupleUnpack_state = 2; \
        \
        while (RACTupleUnpack_state != 2) \
            if (RACTupleUnpack_state == 1) { \
                goto RACTupleUnpack_after; \
            } else \
                for (; RACTupleUnpack_state != 1; RACTupleUnpack_state = 1) \
                    [RACTupleUnpackingTrampoline trampoline][ @[ metamacro_foreach(RACTupleUnpack_value,, __VA_ARGS__) ] ]



```


乍一看这个宏像一段程序，仔细分析一下也不难。RACTupleUnpack\_state 就是一个局部变量，代表状态的。RACTupleUnpack\_after: 这是一个标号，用来给goto跳转使用的。

```objectivec

// 1
metamacro_foreach(RACTupleUnpack_decl,, __VA_ARGS__) 
// 2
metamacro_foreach(RACTupleUnpack_assign,, __VA_ARGS__)
// 3
metamacro_foreach(RACTupleUnpack_value,, __VA_ARGS__)

```

这里面需要展开的就是这3个宏了。

套用上一章节中metamacro\_foreach的最终表达式，直接把MACRO分别为  RACTupleUnpack\_decl，RACTupleUnpack\_assign，RACTupleUnpack\_value 代入表达式。

```objectivec

// 1
RACTupleUnpack_decl(0, _0) \
     ……
     ……
     ……
RACTupleUnpack_decl( N - 1, _N - 1)
// 2
RACTupleUnpack_assign(0, _0) \
     ……
     ……
     ……
RACTupleUnpack_assign( N - 1, _N - 1)
// 3
RACTupleUnpack_value(0, _0) \
     ……
     ……
     ……
RACTupleUnpack_value( N - 1, _N - 1)


```


分别替换掉这3个宏：

```objectivec

#define RACTupleUnpack_decl(INDEX, ARG) \
    __strong id RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_assign(INDEX, ARG) \
    __strong ARG = RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_value(INDEX, ARG) \
    [NSValue valueWithPointer:&RACTupleUnpack_decl_name(INDEX)],



```

发现这3个宏都是用RACTupleUnpack\_decl\_name实现的。

```objectivec

#define RACTupleUnpack_decl_name(INDEX) \
        metamacro_concat(metamacro_concat(RACTupleUnpack, __LINE__), metamacro_concat(_var, INDEX))



```


这个展开就是一个名字：

```objectivec

RACTupleUnpack __LINE__ _varINDEX

```


之后的实现，请看[《ReactiveCocoa 中 集合类RACSequence 和 RACTuple底层实现分析》](http://www.jianshu.com/p/5c2119b3f2eb)这篇文章的详细分析。


#### 3. RACObserve(TARGET, KEYPATH)

定义如下：

```objectivec

#define RACObserve(TARGET, KEYPATH) \
	({ \
		_Pragma("clang diagnostic push") \
		_Pragma("clang diagnostic ignored \"-Wreceiver-is-weak\"") \
		__weak id target_ = (TARGET); \
		[target_ rac_valuesForKeyPath:@keypath(TARGET, KEYPATH) observer:self]; \
		_Pragma("clang diagnostic pop") \
	})


```

看完定义，RACObserve(TARGET, KEYPATH) 实质其实就是调用了rac_valuesForKeyPath:方法。这个方法是NSObject的一个category，所以只要是NSObject就可以调用这个方法。所以这里的关键就是要分析清楚@keypath(TARGET, KEYPATH) 这个宏的实现。


以下重点分析一下keypath(...)的实现

```objectivec

#define keypath(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(keypath1(__VA_ARGS__))(keypath2(__VA_ARGS__))

#define keypath1(PATH) \
    (((void)(NO && ((void)PATH, NO)), strchr(# PATH, '.') + 1))

#define keypath2(OBJ, PATH) \
    (((void)(NO && ((void)OBJ.PATH, NO)), # PATH))



```

metamacro\_argcount这个宏在元宏里面分析过，是取出可变参数个数的。metamacro\_if\_eq也详细分析过，是判断里面2个参数是否相当的。所以keypath(...)总体展开的意思是说，可变参数的个数是否等于1，如果等于1，就执行(keypath1(\_\_VA\_ARGS\_\_))，如果不等于1，就执行(keypath2(\_\_VA\_ARGS\_\_))。

这里有几点需要说明的：

1.加void是为了防止逗号表达式的warning。例如：  

```c

int a=0; int b = 1;
int c = (a,b);


```
由于a没有被用到，所以会有警告。但是写成如下的样子就不会出现警告了：  

```c

int c = ((void)a,b);


```
所以上面keypath1和keypath2加了几个void就是为了防止出现warning。


2.加NO是C语言判断条件短路表达式。增加NO && 以后，预编译的时候看见了NO，就会很快的跳过判断条件。

3.strchr函数原型如下：

```c

extern char *strchr(const char *s,char c);

```

查找字符串s中首次出现字符c的位置。返回首次出现字符c的位置的指针，返回的地址是被查找字符串指针开始的第一个与字符c相同字符的指针，如果字符串中不存在字符c则返回NULL。

4.当输入self.的时候，会出现编译器的语法提示，原因是OBJ.PATH，因为这里的点，所以输入第二个参数时编辑器会给出正确的代码提示。

5.使用keypath(...)的时候前面会加上@符号，原因是经过keypath1(PATH)和keypath2(OBJ, PATH)之后出现的结果是一个C的字符串，前面加上@以后，就变成了OC的字符串了。

举3个例子

```objectivec



// 例子1，一个参数的情况，会调用keypath1(PATH)
NSString *UTF8StringPath = @keypath(str.lowercaseString.UTF8String);
// 输出=> @"lowercaseString.UTF8String"


// 例子2，2个参数的情况，支持自省
NSString *versionPath = @keypath(NSObject, version);
//  输出=> @"version"

// 例子3，2个参数的情况
NSString *lowercaseStringPath = @keypath(NSString.new, lowercaseString);
// 输出=> @"lowercaseString"


```

相应的也有集合类的keypath

```objectivec

#define collectionKeypath(...) \
    metamacro_if_eq(3, metamacro_argcount(__VA_ARGS__))(collectionKeypath3(__VA_ARGS__))(collectionKeypath4(__VA_ARGS__))

#define collectionKeypath3(PATH, COLLECTION_OBJECT, COLLECTION_PATH) ([[NSString stringWithFormat:@"%s.%s",keypath(PATH), keypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String])

#define collectionKeypath4(OBJ, PATH, COLLECTION_OBJECT, COLLECTION_PATH) ([[NSString stringWithFormat:@"%s.%s",keypath(OBJ, PATH), keypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String])


```

原理也是调用了keypath(PATH)，原理这里就不再赘述了。


#### 4. RAC(TARGET, ...) 

宏定义如下：

```objectivec

#define RAC(TARGET, ...) \
        metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RAC_(TARGET, __VA_ARGS__, nil)) \
        (RAC_(TARGET, __VA_ARGS__))


```

RAC(TARGET, ...) 和上一个RACObserve(TARGET, KEYPATH)原理类似。如果只有一个参数就调用(RAC\_(TARGET, \_\_VA\_ARGS\_\_, nil))，如果是多个参数就调用(RAC\_(TARGET, \_\_VA\_ARGS\_\_))。

```objectivec


#define RAC_(TARGET, KEYPATH, NILVALUE) \
        [[RACSubscriptingAssignmentTrampoline alloc] initWithTarget:(TARGET) nilValue:(NILVALUE)][@keypath(TARGET, KEYPATH)]


```

到这里就很明了了，其实内部就是调用RACSubscriptingAssignmentTrampoline类的initWithTarget: nilValue:方法。


我们都知道RAC(TARGET, ...)宏是用来把一个信号绑定给一个对象的属性，绑定之后，每次信号发送出一个新的值，就会自动设定到执行的keypath中。当信号完成之后，这次绑定也会自动的解除。

RAC\_(TARGET, KEYPATH, NILVALUE) 会把信号绑定到TARGET指定的KEYPATH上。如果信号发送了nil的值，那么会替换成NILVALUE赋值给对应的属性值上。

RAC\_(TARGET, \_\_VA\_ARGS\_\_)只不过是RAC\_(TARGET, KEYPATH, NILVALUE)第三个参数为nil。



#### 5. RACChannelTo(TARGET, ...)

RACChannelTo(TARGET, ...)这个宏完全可以类比RAC(TARGET, ...)，两个几乎完全一样。

```objectivec


#define RACChannelTo(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACChannelTo_(TARGET, __VA_ARGS__, nil)) \
        (RACChannelTo_(TARGET, __VA_ARGS__))


```

如果只有一个参数就调用(RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_, nil)) ，如果是多个参数就调用(RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_))。(RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_))相当于是(RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_, nil)) 第三个参数传了nil。

```objectivec


#define RACChannelTo_(TARGET, KEYPATH, NILVALUE) \
    [[RACKVOChannel alloc] initWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][@keypath(RACKVOChannel.new, followingTerminal)]

```


最终内部是调用了RACKVOChannel的initWithTarget: keyPath: nilValue:方法。具体原理可以完全类比RAC(TARGET, ...)宏展开，这里不再赘述。

平时我们都是这样用：

```objectivec

   RACChannelTo(view, objectProperty) = RACChannelTo(model, objectProperty);
   RACChannelTo(view, integerProperty, @2) = RACChannelTo(model, integerProperty, @10);


```


#### 6. onExit


宏定义如下：


```objectivec

#define onExit \
    rac_keywordify \
    __strong rac_cleanupBlock_t metamacro_concat(rac_exitBlock_, __LINE__) __attribute__((cleanup(rac_executeCleanupBlock), unused)) = ^



```

由于rac\_keywordify的存在，所以在使用onExit的时候，前面也要加上@符号。

这个宏比较特殊，最后是跟着一个闭包，比如这样：

```objectivec

        @onExit {
		      free(attributes);
	    };

        @onExit {
				[objectLock unlock];
			};


```


@onExit定义当前代码段退出时要执行的一些代码。代码必须用大括号括起来并以分号结尾，无论是何种情况（包括出现异常，goto语句，return语句，break语句，continue语句）下跳出代码段，都会执行onExit后面的代码。


@onExit提供的代码被放进一个block块中，之后才会执行。因为在闭包中，所以它也必须遵循内存管理方面的规则。@onExit是以一种合理的方式提前退出清理块。

在相同代码段中如果有多个@onExit语句，那么他们是按照反字典序的顺序执行的。

@onExit语句不能在没有大括号的范围内使用。在实际使用过程中，这不是一个问题，因为@onExit后面如果没有大括号，那么它是一个无用的结构，不会有任何事情发生。


### 最后

![](https://img.halfrost.com/Blog/ArticleImage/39_11.jpg)

关于ReactiveCocoa里面所有宏的实现分析都已经分析完成。我觉得宏是对一段逻辑的高度抽象，当一个宏被思维完备的开发人员设计出来以后，就是一个充满神奇色彩的魔法！如果能把一些简单实用的功能或者逻辑抽象成宏，把这些时间都节约到预编译中，节约运行时的时间，单从编码的程度来说，都是极有乐趣的一件事情！如果以后有机会，希望还能和大家交流交流Lisp里面的相关宏魔法的知识。

