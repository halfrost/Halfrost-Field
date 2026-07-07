# The Incredibly Magical “Macro” Magic in ReactiveCocoa


![](https://img.halfrost.com/Blog/ArticleTitleImage/39_0_.png)


### Preface

In ReactiveCocoa, the authors of the open-source library provide us with many kinds of magic: “black” magic, “red” magic… Today, let’s first take a look at the “red” magic.


![](https://img.halfrost.com/Blog/ArticleImage/39_1.png)


ReactiveCocoa encapsulates many highly practical “macros.” Using these “macros” brings a great deal of convenience to our development work.

Today, let’s take inventory of how macros in RAC are implemented.

### Table of Contents

- 1. About Macros
- 2. Metamacros in ReactiveCocoa
- 3. Commonly Used Macros in ReactiveCocoa

### 1. About Macros

> A **macro** is a term for a kind of [batch processing](https://zh.wikipedia.org/wiki/%E6%89%B9%E5%A4%84%E7%90%86).

In programming, a macro is a form of [abstraction](https://zh.wikipedia.org/wiki/%E6%8A%BD%E8%B1%A1). It replaces certain textual patterns according to a series of predefined rules. When an [interpreter](https://zh.wikipedia.org/wiki/%E8%A7%A3%E9%87%8A%E5%99%A8) or [compiler](https://zh.wikipedia.org/wiki/%E7%BC%96%E8%AF%91%E5%99%A8) encounters a macro, it automatically performs this pattern substitution. In most cases, the use of the word “macro” implies transforming small commands or actions into a sequence of instructions.

Macros are used to automate frequently used sequences or to obtain a more powerful abstraction capability.
Programming languages such as [C](https://zh.wikipedia.org/wiki/C%E8%AF%AD%E8%A8%80) or [assembly language](https://zh.wikipedia.org/wiki/%E6%B1%87%E7%BC%96%E8%AF%AD%E8%A8%80) have simple macro systems implemented by the preprocessor of a [compiler](https://zh.wikipedia.org/wiki/%E7%BC%96%E8%AF%91%E5%99%A8) or [assembler](https://zh.wikipedia.org/wiki/%E6%B1%87%E7%BC%96%E5%99%A8). The C macro preprocessor only performs simple textual search and replacement. By using additional text-processing languages such as [M4](https://zh.wikipedia.org/wiki/M4), C programmers can get more sophisticated macros.

[Lisp](https://zh.wikipedia.org/wiki/Lisp)-like languages such as [Common Lisp](https://zh.wikipedia.org/wiki/Common_Lisp) and [Scheme](https://zh.wikipedia.org/wiki/Scheme) have more sophisticated macro systems: macros behave like functions that transform their own program text, and the full language can be used to express such transformations. A C macro can define a replacement for a piece of syntax, whereas a Lisp macro can control the evaluation of a section of code.


For compiled languages, all macros are expanded during preprocessing, so before lexical scanning by lex generates tokens and before lexical analysis, all macros have already been fully expanded.

In Xcode, the preprocessing or precompilation stage can be viewed directly.


![](https://img.halfrost.com/Blog/ArticleImage/39_2.png)


Write any macro, then open the Assistant in the upper-right corner of Xcode and select “Preprocess”; you can then see what the file looks like after preprocessing. You can see that `@weakify(self)` on the left has been converted into the two lines of code on the right.

There are two additional notes about this Xcode feature:

1. The preprocessed output may differ at different stages, so you need to choose the preprocessing conditions according to your target.


![](https://img.halfrost.com/Blog/ArticleImage/39_3.png)


For example, there are five kinds of precompilation options to choose from here.

2. The code produced after macro preprocessing can be used to check whether a macro is written correctly, but it cannot show the specific process by which the macro is expanded. This means we can use this Xcode feature to see what a macro does, but we cannot know how the macro is implemented in detail. To analyze the specific implementation, we still need to read the source code.


If you do not read and analyze the source code of the macros in ReactiveCocoa, those macros will seem as wonderfully magical as magic. Next, let’s lift the veil on this “macro” magic.


### 2. Metamacros in ReactiveCocoa

![](https://img.halfrost.com/Blog/ArticleImage/39_4.jpg)


Among ReactiveCocoa’s macros, the author defines a set of fundamental macros as “metamacros.” They form the foundation for the more complex macros that follow. Before analyzing the commonly used macros, we must first clearly analyze the concrete implementations of these metamacros.

#### 1. metamacro\_stringify(VALUE)
```objectivec

#define metamacro_stringify(VALUE) \
        metamacro_stringify_(VALUE)

#define metamacro_stringify_(VALUE) # VALUE

```
The `metamacro_stringify()` macro uses `#`. In a macro, `#` means converting the macro’s argument into a string. As its name clearly suggests, this macro’s purpose is to convert the input parameter `VALUE` into a string and return it.

At this point, some people may wonder: why wrap it in an extra layer? Why not write it directly as follows:
```objectivec

#define metamacro_stringify(VALUE)  # VALUE


```
The semantics indeed remain unchanged, but a problem can occur in a special case.

For example:
```objectivec

#define NUMBER   10

#define ADD(a,b) (a+b)
NSLog(@"%d+%d=%d",NUMBER, NUMBER, ADD(NUMBER,NUMBER));

```
Output as follows:
```vim

10+10=20

```
This is indeed fine as is, but even a slight modification will cause problems.
```objectivec

#define STRINGIFY(S) #S

#define CALCULATE(A,B)  (A##10##B)

NSLog(@"int max: %s",STRINGIFY(INT_MAX));
NSLog(@"%d", CALCULATE(NUMBER,NUMBER));

```
In this case, the second `NSLog` statement will produce a compilation error. After preprocessing, the two lines above have their macros expanded as follows:
```vim

NSLog(@"int max: %s","INT_MAX");
NSLog(@"%d", (NUMBER10NUMBER));

```
As you can see, the macro is not expanded again. The solution is also straightforward: wrap the macro in another layer by defining a forwarding macro.
```objectivec

#define CALCULATE(A,B)   _CALCULATE(A,B)   // Conversion macro

#define _CALCULATE(A,B)  A##10##B

```
Test again; here we use the official metamacro\_stringify.
```objectivec

NSLog(@"int max: %s",metamacro_stringify(INT_MAX));
NSLog(@"%d", CALCULATE(NUMBER,NUMBER));

```
This way, the final printed result is consistent with what we want, so there is no issue.
```vim

2147483647
101010

```
CALCULATE(NUMBER,NUMBER) is first transformed into \_CALCULATE(10,10), and then the second transformation turns it into 10##10##10, which is 101010.

Of course, this is a two-level transformation; if there are more levels, more transformation macros are needed.
```objectivec

NSLog(@"%d", CALCULATE(STRINGIFY(NUMBER),STRINGIFY(NUMBER)));


```
The example above already has three levels; with our previous approach, it would still fail to compile. If you have multiple levels beyond two or three, you should consider the semantics of the macro design and try to prevent users from using it incorrectly.


#### 2. metamacro\_concat(A, B)
```objectivec

#define metamacro_concat(A, B) \
        metamacro_concat_(A, B)

#define metamacro_concat_(A, B) A ## B

```
This macro is used to concatenate input arguments A and B. In RAC, this method is mainly used to compose the name of another macro.


#### 3. metamacro\_argcount(...) and metamacro\_at(N, ...)

The design of the `metamacro_argcount(...)` macro is also very clever. It is used to get the number of arguments. Because macro expansion happens during preprocessing, it obtains the argument count at preprocessing time, whereas other non-macro approaches obtain the argument count at runtime.
```objectivec

#define metamacro_argcount(...) \
        metamacro_at(20, __VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


```
This will call the metamacro\_at(N, ...) macro.
```objectivec

#define metamacro_at(N, ...) \
        metamacro_concat(metamacro_at, N)(__VA_ARGS__)

```
Expanding this macro gives:
```objectivec

#define metamacro_at(N, ...) \
        metamacro_atN(__VA_ARGS__)

```
Thus, by using the `metamacro_concat` concatenation command, we get a series of `metamacro_atN` macro commands:
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
It can be seen that the value of N can only range from 0 to 20.
```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)

#define metamacro_head_(FIRST, ...) FIRST

```
After `metamacro_head` expands, it becomes:
```objectivec

#define metamacro_head(FIRST,..., 0)  FIRST

```
The intent of metamacro\_head is quite clear: it is used to obtain the first argument from the subsequent variadic parameters.

Returning to the metamacro\_atN macro, expanding it gives the following:
```objectivec

#define metamacro_atN(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ... , _N, ...) metamacro_head(__VA_ARGS__)


```
Of course, N still ranges from 0 to 20, so the value obtained by the metamacro\_atN macro is the Nth argument value in the variadic argument list. Arguments are indexed starting from 0.


Now back to the original metamacro\_argcount(...) macro. At this point, it has expanded to:
```objectivec


#define metamacro_argcount(...) \
        metamacro_at20(__VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


```
Because the number of \_\_VA\_ARGS\_\_ cannot exceed 20, it must be between 0 and 19.
```objectivec

metamacro_at20(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ..., 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1) metamacro_head(__VA_ARGS__)


```
Assume there are 5 input parameters:
```objectivec

metamacro_argcount(@"1",@"2",@"3",@"4",@"5");

```
First, place the 5 parameters into the first five positions of `metamacro_at20`. Then, starting from the 6th position, insert the numbers `20-1` in reverse order. As shown below:

![](https://img.halfrost.com/Blog/ArticleImage/39_5.png)


We can think of the reversed numbers as a ruler, used to measure or indicate how many parameters there currently are. Align the leftmost end of the ruler with the first of the 20 empty slots above; take the extra part that extends beyond the ruler, then perform the `metamacro_head` operation to extract the first parameter. That number is the total number of parameters. This virtual “ruler” aligns left or right depending on the number of parameters that have been filled in.

The principle behind this macro is also simple: `20 - (20 - n) = n`. This is how the `metamacro_argcount(...)` macro obtains the number of parameters during preprocessing.


The author also notes that the design of this macro was inspired by the excellent [P99](http://p99.gforge.inria.fr) library. If you’re interested, you can take a look at that library.


#### 4. `metamacro_foreach(MACRO, SEP, ...)` and `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)`


Let’s first analyze the `metamacro_foreach(MACRO, SEP, ...)` macro:
```objectivec

#define metamacro_foreach(MACRO, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

```
From the definitions, it is clear that `metamacro_foreach(MACRO, SEP, ...)` and `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` serve the same purpose. The former simply has one fewer `foreach` iterator parameter than the latter.

##### 1. The `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` Macro

Now let’s look at the definition of the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro.
```objectivec


#define metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)


```
Then the previous metamacro\_foreach(MACRO, SEP, ...) macro can be equivalently expressed as
```objectivec

metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

```
Returning to the expansion expression of the metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...) macro, assume the number of arguments in \_\_VA\_ARGS\_\_ is N.

The metamacro\_concat macro and metamacro\_argcount macro were introduced above, so the macro can be further expanded as follows:
```objectivec

metamacro_foreach_cxtN(MACRO, SEP, CONTEXT, __VA_ARGS__)

```
Here again is an example of using the metamacro\_concat macro to dynamically compose another macro.
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
Abstract the definition of the above metamacro\_foreach\_cxtN:
```objectivec

#define metamacro_foreach_cxtN(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, … ,_N - 1) \
    metamacro_foreach_cxtN - 1(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, … ,_N - 2) \
    SEP \
    MACRO(N - 1, CONTEXT, _N - 1)


```
Of course, in RAC, the value range of N is [0,20]. Let’s still assume that the domain of N is the set N consisting of all non-negative integers (the mathematical notation for the set of non-negative integers). Then we fully expand metamacro\_foreach\_cxtN until it can no longer be expanded:
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
metamacro\_foreach\_cxtN(MACRO, SEP, CONTEXT, ...): the intent of this macro is fairly obvious. It reads the count from the variadic argument list, then applies `MACRO(N - 1, CONTEXT, _N - 1)` to each argument, using `SEP` directly as the separator between each operation.

The design of the metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...) macro was also inspired by the P99 library.


![](https://img.halfrost.com/Blog/ArticleImage/39_6.png)


The most well-known macro that uses this is `weakify(...)`. Next, let’s briefly look at how metamacro\_foreach\_cxtN(MACRO, SEP, CONTEXT, ...) is cleverly used to implement `weakify(...)`.
```objectivec

#define weakify(...) \
    rac_keywordify \
    metamacro_foreach_cxt(rac_weakify_,, __weak, __VA_ARGS__)


```
The biggest difference between using weakify and the weakSelf we usually write ourselves is that weakify can take multiple parameters—up to 20. weakify can weakify all parameters in the parameter list in one go.


One of the key points of weakify(...) is the metamacro\_foreach\_cxt operation. Suppose two parameters are passed in, self and str. After expansion, we get:
```objectivec


    MACRO(0, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1)

```
MACRO = rac\_weakify\_, CONTEXT =  \_\_weak, SEP is a space, substituting the arguments:
```objectivec

 rac_weakify_(0,__weak,self) \
 rac_weakify_(1,__weak,str) 

```
Note that after the replacement is complete, the two macros are joined together, with no semicolon in between! The separator SEP is currently a space. The final step is to replace rac\_weakify\_:
```objectivec

#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

```
Note that `INDEX` here is a dummy parameter and is not used.

Expanding the macro above:
```objectivec

__weak __typeof__(self) self_weak_ = (self)；__weak __typeof__(str) str_weak_ = (str)；


```
Note that rac\_weakify\_ includes its own semicolon. If there were no semicolon here, a compilation error would occur.

Ultimately, @weakify(self，str) will be replaced during preprocessing with
```objectivec


@autoreleasepool {} __weak __typeof__(self) self_weak_ = (self)；__weak __typeof__(str) str_weak_ = (str)；

```
Note that there is no line break in the middle; after macro expansion, this is a single line.


After finishing the analysis of metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...), let’s come back and look at metamacro\_foreach(MACRO, SEP, ...)

##### 2. metamacro\_foreach(MACRO, SEP, ...)
```objectivec

metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)


```
At this point, we can similarly assume that the number of parameters is N, so the macro expansion above can become the following:
```objectivec


metamacro_foreach_cxtN(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)


```
Here, MACRO = metamacro\_foreach\_iter, SEP = SEP, and CONTEXT = MACRO.
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
metamacro\_foreach\_iter is defined as follows:
```objectivec


#define metamacro_foreach_iter(INDEX, MACRO, ARG) MACRO(INDEX, ARG)


```
Continuing to expand, we get the following expression:
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


Looking at the final expanded expression, metamacro\_foreach(MACRO, SEP, ...) has one fewer CONTEXT than metamacro\_foreach\_cxt(MACRO, SEP, CONTEXT, ...).

A typical example of the metamacro\_foreach(MACRO, SEP, ...) macro is the well-known implementation of strongify(...).
```objectivec


#define strongify(...) \
    rac_keywordify \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    metamacro_foreach(rac_strongify_,, __VA_ARGS__) \
    _Pragma("clang diagnostic pop")


```
Based on the analysis above, we directly substitute the results: MACRO = rac\_strongify\_ , SEP = space.
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
Next, replace rac\_strongify\_
```objectivec

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);


```
Similarly, `INDEX` here is also a dummy parameter and is not used. `rac\_strongify\_` likewise includes its own semicolon; if there were no semicolon here, `SEP` would be a space at this point, and compilation would fail immediately.

In the end, it is transformed into the following:
```objectivec

__strong __typeof__(self) self = self_weak_;


```

#### 5. metamacro\_foreach\_cxt\_recursive(MACRO, SEP, CONTEXT, ...)

First, let’s look at the definition:
```objectivec

#define metamacro_foreach_cxt_recursive(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt_recursive, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)


```
Assuming the number of variadic arguments is N, expand the above expression:
```objectivec


#define metamacro_foreach_cxt_recursive(MACRO, SEP, CONTEXT, ...) \
        metamacro_foreach_cxt_recursiveN(MACRO, SEP, CONTEXT, __VA_ARGS__)

```
It is then transformed into the `metamacro_foreach_cxt_recursiveN` macro:
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
Extract the definition of `metamacro_foreach_cxt_recursiveN`:
```objectivec

#define metamacro_foreach_cxt_recursiveN(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, … ，_( N - 1)) \
        metamacro_foreach_cxt_recursive(N - 1)(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _( N - 2)) \
        SEP \
        MACRO(N -1, CONTEXT, _N -1)

```
As with the previous analysis, expand it fully in the same way:
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
At this point, the expansion is exactly the same as the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro.

This recursive macro is never used by any other macro in RAC; the author added a note here to explain what this macro is for.

> This can be used when the former would fail due to recursive macro expansion

Because recursive macro expansion may cause the recursive preconditions to fail, this recursive macro should be used in such cases. Of course, its effect is exactly the same as the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro.

#### 6. metamacro_foreach_concat(BASE, SEP, ...)

This macro definition reuses the implementation of the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro, only passing in a few additional parameters. This shows how important the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro is in RAC.
```objectivec

#define metamacro_foreach_concat(BASE, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_concat_iter, SEP, BASE, __VA_ARGS__)


```
Since the implementation of the `metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...)` macro was analyzed in detail above, here we will directly expand it fully to the final step. `MACRO = metamacro_foreach_concat_iter`, `SEP = SEP`, `CONTEXT = BASE`.
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
At this point, you need to continue expanding metamacro\_foreach\_concat\_iter
```objectivec

#define metamacro_foreach_concat_iter(INDEX, BASE, ARG) metamacro_foreach_concat_iter_(BASE, ARG)

#define metamacro_foreach_concat_iter_(BASE, ARG) BASE ## ARG


```
The two macros here use the concept of the adapter macro mentioned earlier. Since the first argument needs to be removed, an adapter macro has to be written to perform one level of transformation and drop the first argument.

After full expansion, it ultimately looks like this:
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
The `metamacro_foreach_concat(BASE, SEP, ...)` macro, as its name suggests, concatenates each variadic argument to `BASE`, separating each completed concatenation with `SEP`.

Consider a scenario:

If you have a series of methods whose names all share the same prefix but differ in the suffix, `metamacro_foreach_concat(BASE, SEP, ...)` is extremely handy. It can generate an entire related list of different macros in one shot.

#### 7. metamacro_for_cxt(COUNT, MACRO, SEP, CONTEXT)

Defined as follows:
```objectivec

#define metamacro_for_cxt(COUNT, MACRO, SEP, CONTEXT) \
        metamacro_concat(metamacro_for_cxt, COUNT)(MACRO, SEP, CONTEXT)


```
We analyzed metamacro\_concat earlier; expand this layer:
```objectivec


metamacro_for_cxtN(MACRO, SEP, CONTEXT)


```
The definition of metamacro\_for\_cxtN is as follows:
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
Extract the definition of metamacro\_for\_cxtN:
```objectivec


#define metamacro_for_cxtN(MACRO, SEP, CONTEXT) \
        metamacro_for_cxtN - 1(MACRO, SEP, CONTEXT) \
        SEP \
        MACRO(N - 1, CONTEXT)

```
Fully expand metamacro\_for\_cxtN as follows:
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
This macro is used to execute the `MACRO` macro command `COUNT` times. On each invocation of `MACRO`, its first argument is decremented from `COUNT` down to 0.

#### 8. metamacro\_head(...)

This macro requires at least one variadic argument.
```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)


```
Expand the macro as follows:
```objectivec

#define metamacro_head_(FIRST, ...) FIRST


```
The purpose of metamacro\_head(...) is to extract the first argument from a variadic argument list.


#### 9. metamacro\_tail(...)

This macro requires its variadic arguments to contain at least 2 arguments.
```objectivec

#define metamacro_tail(...) \
        metamacro_tail_(__VA_ARGS__)


```
Expand the macro as follows:
```objectivec

#define metamacro_tail_(FIRST, ...) __VA_ARGS__


```
The purpose of metamacro\_tail(...) is to retrieve all arguments in a variadic argument list except the first one.

#### 10. metamacro\_take(N, ...)


This macro requires that its variadic arguments contain at least N arguments.
```objectivec


#define metamacro_take(N, ...) \
        metamacro_concat(metamacro_take, N)(__VA_ARGS__)

```
Expand it as follows:
```objectivec


metamacro_takeN(__VA_ARGS__)

```
Continue expanding metamacro\_takeN:
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


This also uses the idea of recursion. After taking the head each time, the remaining queue is the tail for the current step and the head for the next step. So each time it takes the head, then recursively takes the head of the remaining part, until the first N values have been taken.

The purpose of metamacro\_take(N, ...) is to take the first N values from the variadic arguments and combine them into a new argument list.

#### 11. metamacro\_drop(N, ...)


This macro requires its variadic arguments to contain at least N values.
```objectivec

#define metamacro_drop(N, ...) \
        metamacro_concat(metamacro_drop, N)(__VA_ARGS__)

```
Expand it as follows:
```objectivec


metamacro_dropN(__VA_ARGS__)

```
Continue expanding metamacro\_dropN:
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


This also uses the idea of recursion: each time, it takes the current queue’s tail and discards the current queue’s head. After recursing N times, the first N arguments are discarded.


The purpose of metamacro\_drop(N, ...) is to drop the first N arguments from the current argument list.


#### 12. metamacro\_dec(VAL) and metamacro\_inc(VAL)

These two macros are a pair. In metaprogramming, they are extremely useful for handling counters and indexes. The value range of VAL is [0,20].
```objectivec

#define metamacro_dec(VAL) \
        metamacro_at(VAL, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19)


```
metamacro\_dec(VAL) provides a [0,20] sequence shifted left by one position. Therefore, the result computed by metamacro\_at is 1 less than the original result, thereby achieving a decrement by one.
```objectivec

#define metamacro_inc(VAL) \
        metamacro_at(VAL, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21)


```
metamacro\_inc(VAL) provides a [0,20] sequence shifted right by one position. Therefore, the result computed via metamacro\_at is 1 greater than the original result, thereby achieving the purpose of incrementing by one.


#### 13. metamacro\_if\_eq(A, B)

First, the value ranges of both A and B are [0,20], and B must be greater than or equal to A; that is, 0<=A<=B<=20.
```objectivec

#define metamacro_if_eq(A, B) \
        metamacro_concat(metamacro_if_eq, A)(B)


```
If A is nonzero, expanding the expression above gives:
```objectivec


#define metamacro_if_eq(A, B) \
        metamacro_if_eqA(B)


```
Continue expanding metamacro\_if\_eqA:
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
The expression above is recursive; it will eventually reach metamacro\_if\_eq0, and the final result is:
```objectivec


metamacro_if_eq0(B - A)


```
Next, expand metamacro\_if\_eq0:
```objectivec

#define metamacro_if_eq0(VALUE) \
        metamacro_concat(metamacro_if_eq0_, VALUE)


```
Obtain the final expanded expression:
```objectivec


metamacro_if_eq0_(B - A)

```
Looking it up in the table again yields the final result:
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
There are two points to note about the table above:

1. Except for 0\_0, all the others are metamacro\_expand\_.
```objectivec

#define metamacro_consume_(...)

#define metamacro_expand_(...) __VA_ARGS__


```
Except for 0\_0, all other operations directly pass through the arguments without doing any processing. metamacro\_consume\_(...) simply consumes the subsequent arguments. expand means the macro can continue to be expanded, while consume means macro expansion is terminated and the following arguments are consumed.

Here are 2 examples:
```objectivec

// First example
metamacro_if_eq(0, 0)(true)(false)

// Second example
metamacro_if_eq(0, 1)(true)(false)


```
Directly apply the final expanded form:
```objectivec

// First example
metamacro_if_eq0_0(true)(false)

// Second example
metamacro_if_eq0_1(true)(false)


```
Continue expanding:
```objectivec

// First example
true metamacro_consume_(false) => true

// Second example
metamacro_expand_(false) => false


```
If B < A, then (B - A) < 0, so the fully expanded expression becomes:
```objectivec


metamacro_if_eq0_(negativeNumber)


```
At this point, the macro expansion can no longer proceed, and a compilation error will occur.


#### 14. metamacro\_if\_eq\_recursive(A, B)

The value ranges of both A and B are [0,20], and B must be greater than or equal to A, i.e., 0<=A<=B<=20.


Defined as follows:
```objectivec


#define metamacro_if_eq_recursive(A, B) \
        metamacro_concat(metamacro_if_eq_recursive, A)(B)


```
After expanding:
```objectivec

metamacro_if_eq_recursiveA(B)

```
Continue expanding:
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
Eventually, you will end up with metamacro\_if\_eq\_recursive0\_; the final result is:
```objectivec


metamacro_if_eq_recursive0_(B - A)


```
Next, expand metamacro\_if\_eq\_recursive0\_:
```objectivec


#define metamacro_if_eq_recursive0(VALUE) \
    metamacro_concat(metamacro_if_eq_recursive0_, VALUE)


```
Obtain the final expression:
```objectivec


metamacro_if_eq_recursive0_(B - A)


```
Finally, compare against the table below:
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
From here on, it is exactly the same as the metamacro\_if\_eq(A, B) macro.


This recursive macro is also never used by any other macro in RAC; the author added a note here explaining its purpose.

> This can be used when the former would fail due to recursive macro expansion

Because macro recursive expansion may cause the recursion precondition to fail, this recursive macro should be used in that case. Of course, its effect is exactly the same as the metamacro\_if\_eq(A, B) macro.


#### 15. metamacro\_is\_even(N)


Defined as follows:

The value range of N is [0,20].
```objectivec

#define metamacro_is_even(N) \
        metamacro_at(N, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1)


```
This macro is relatively simple: it just determines whether `N` is even. The `metamacro_at` below marks all natural numbers from 0 to 20 that are even as 1, and all odd numbers as 0. Here, 0 is considered even by default.


#### 16. metamacro_not(B)

Here, the value of `B` can only be 0 or 1.
```objectivec


#define metamacro_not(B) \
        metamacro_at(B, 1, 0)


```
This macro is very simple: it just performs a logical negation on the argument.


### III. Commonly Used Macros in ReactiveCocoa


![](https://img.halfrost.com/Blog/ArticleImage/39_10.png)


In the previous section, we finished analyzing all the metamacros in ReactiveCocoa. In this section, we will analyze the implementations of all macros other than the metamacros, including all the common macros we use day to day. They may look mysterious, but they are all composed from those metamacros.

#### 1. weakify(...)、unsafeify(...)、strongify(...)

These three are certainly among the most frequently used in ReactiveCocoa, so let’s analyze them first. Their definitions are in RACEXTScope.h.

As for weakify(...) and strongify(...), the implementation analysis of these two macros was covered in detail in a previous article. For details, see [“In-depth Study of Using weakSelf, strongSelf, @weakify, and @strongify in Blocks to Resolve Retain Cycles”](http://www.jianshu.com/p/701da54bd78c).


One point that needs to be emphasized again is that when using the three macros weakify(...), unsafeify(...), and strongify(...), you need to add an extra @ symbol before them. The reason is that the implementations of these three macros all contain rac\_keywordify, whose implementation is as follows:
```objectivec

#if DEBUG

#define rac_keywordify autoreleasepool {}

#else

#define rac_keywordify try {} @catch (...) {}

#endif


```
Regardless of the environment, you must add the @ symbol before autoreleasepool  {} and try {} @catch (...) {}, changing them to @autoreleasepool  {} and @try {} @catch (...) {} before they can continue to be used.


Since @weakify(...) and @strongify(...) have already been analyzed, this section analyzes the implementation of @unsafeify(...).
```objectivec

#define unsafeify(...) \
        rac_keywordify \
        metamacro_foreach_cxt(rac_weakify_,, __unsafe_unretained, __VA_ARGS__)


```
As mentioned above for rac\_keywordify, here we will directly expand the metamacro\_foreach\_cxt macro. Applying the earlier analysis of the meta-macros, we can directly obtain the final expanded expression:
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
MACRO = rac\_weakify\_, SEP = space, CONTEXT = \_\_unsafe\_unretained. Substituting these gives the final expansion:
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
Replace rac\_weakify\_ as well:
```objectivec

#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);


```
Obtain the final expanded expression:
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
Here, _0, _1, _2, …… _N - 3, _N - 2, and _N - 1 are the corresponding argument values 0 through N in \_\_VA\_ARGS\_\_.


#### 2. RACTuplePack(...) and RACTupleUnpack(...)

These two are also very common macros in ReactiveCocoa, used specifically with RACTuple.

First, look at RACTuplePack(...)
```objectivec

#define RACTuplePack(...) \
        RACTuplePack_(__VA_ARGS__)

```
Taking it one step further:
```objectivec

#define RACTuplePack_(...) \
        ([RACTuple tupleWithObjectsFromArray:@[ metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) ]])


```
Here, RACTuple’s tupleWithObjectsFromArray: method is called. The main part that needs to be expanded is:
```objectivec

metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) 


```
Directly invoke the final expression of metamacro\_foreach from the previous section:
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
MACRO = RACTuplePack\_object\_or\_ractuplenil, SEP = space, after replacement:
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
The final step is to replace RACTuplePack\_object\_or\_ractuplenil:
```objectivec

#define RACTuplePack_object_or_ractuplenil(INDEX, ARG) \
    (ARG) ?: RACTupleNil.tupleNil,

```
Note that the macro ends with a comma “,” rather than a semicolon “;”. This is because `tupleWithObjectsFromArray:` takes individual elements, so using a semicolon “;” here would cause an error; instead, a comma “,” should be used. This shows that when designing macros, you need to think carefully about the usage scenario and not write them arbitrarily.

After expanding the final layer of macros above, all non-`nil` values from the original variadic argument list are arranged inside the `tupleWithObjectsFromArray:` method. If a value is `nil`, it is converted into `RACTupleNil.tupleNil` and placed into the `Array`.

Now let’s look at `RACTupleUnpack(...)`.
```objectivec

#define RACTupleUnpack(...) \
        RACTupleUnpack_(__VA_ARGS__)


```
Expand one step further:
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
At first glance, this macro looks like a piece of code, but it is not hard to analyze carefully. RACTupleUnpack\_state is just a local variable representing the state. RACTupleUnpack\_after: is a label used as the target of a `goto` jump.
```objectivec

// 1
metamacro_foreach(RACTupleUnpack_decl,, __VA_ARGS__) 
// 2
metamacro_foreach(RACTupleUnpack_assign,, __VA_ARGS__)
// 3
metamacro_foreach(RACTupleUnpack_value,, __VA_ARGS__)

```
What needs to be expanded here are these three macros.

Using the final expression for metamacro\_foreach from the previous section, directly substitute MACRO with RACTupleUnpack\_decl, RACTupleUnpack\_assign, and RACTupleUnpack\_value respectively.
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
Replace these three macros respectively:
```objectivec

#define RACTupleUnpack_decl(INDEX, ARG) \
    __strong id RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_assign(INDEX, ARG) \
    __strong ARG = RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_value(INDEX, ARG) \
    [NSValue valueWithPointer:&RACTupleUnpack_decl_name(INDEX)],


```
It turns out that all three macros are implemented using RACTupleUnpack\_decl\_name.
```objectivec

#define RACTupleUnpack_decl_name(INDEX) \
        metamacro_concat(metamacro_concat(RACTupleUnpack, __LINE__), metamacro_concat(_var, INDEX))


```
This expansion is just a name:
```objectivec

RACTupleUnpack __LINE__ _varINDEX

```
For the subsequent implementation, see the detailed analysis in [“Analysis of the Underlying Implementation of the Collection Classes RACSequence and RACTuple in ReactiveCocoa”](http://www.jianshu.com/p/5c2119b3f2eb).

#### 3. RACObserve(TARGET, KEYPATH)

Defined as follows:
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
After reading the definition, RACObserve(TARGET, KEYPATH) is essentially just a call to the rac_valuesForKeyPath: method. This method is a category on NSObject, so any NSObject can call it. Therefore, the key point here is to clearly analyze the implementation of the @keypath(TARGET, KEYPATH) macro.

The following focuses on analyzing the implementation of keypath(...).
```objectivec

#define keypath(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(keypath1(__VA_ARGS__))(keypath2(__VA_ARGS__))

#define keypath1(PATH) \
    (((void)(NO && ((void)PATH, NO)), strchr(# PATH, '.') + 1))

#define keypath2(OBJ, PATH) \
    (((void)(NO && ((void)OBJ.PATH, NO)), # PATH))


```
The metamacro\_argcount macro was analyzed in the metamacro section; it retrieves the number of variadic arguments. metamacro\_if\_eq was also analyzed in detail; it determines whether the two arguments it receives are equal. So the overall expansion of keypath(...) means: check whether the number of variadic arguments is equal to 1. If it is equal to 1, execute (keypath1(\_\_VA\_ARGS\_\_)); otherwise, execute (keypath2(\_\_VA\_ARGS\_\_)).

A few points need to be clarified here:

1. Adding void is to prevent warnings from comma expressions. For example: 
```c

int a=0; int b = 1;
int c = (a,b);


```
Because a is not used, there will be a warning. However, if you write it as follows, the warning will not appear:  
```c

int c = ((void)a,b);


```
So the reason several `void` casts were added to `keypath1` and `keypath2` above is to prevent warnings.


2. Adding `NO` uses C's short-circuit evaluation for conditional expressions. After adding `NO &&`, once the compiler sees `NO`, it can quickly skip evaluating the condition.

3. The prototype of the `strchr` function is as follows:
```c

extern char *strchr(const char *s,char c);

```
Find the position of the first occurrence of character `c` in string `s`. Return a pointer to the position of the first occurrence of character `c`; the returned address is the pointer to the first character, starting from the string pointer being searched, that matches character `c`. If character `c` does not exist in the string, return `NULL`.

4. When you type `self.`, the compiler’s syntax suggestions appear because of `OBJ.PATH`. Because of the dot here, when you enter the second parameter, the editor can provide the correct code completion suggestions.

5. When using `keypath(...)`, an `@` symbol is added in front. The reason is that after `keypath1(PATH)` and `keypath2(OBJ, PATH)`, the result is a C string. After adding `@` in front, it becomes an Objective-C string.

Give 3 examples.
```objectivec


// Example 1, one-parameter case, calls keypath1(PATH)
NSString *UTF8StringPath = @keypath(str.lowercaseString.UTF8String);
// Output=> @"lowercaseString.UTF8String"


// Example 2, two-parameter case, supports introspection
NSString *versionPath = @keypath(NSObject, version);
//  Output=> @"version"

// Example 3, two-parameter case
NSString *lowercaseStringPath = @keypath(NSString.new, lowercaseString);
// Output=> @"lowercaseString"


```
Correspondingly, there are also key paths for collection types.
```objectivec

#define collectionKeypath(...) \
    metamacro_if_eq(3, metamacro_argcount(__VA_ARGS__))(collectionKeypath3(__VA_ARGS__))(collectionKeypath4(__VA_ARGS__))

#define collectionKeypath3(PATH, COLLECTION_OBJECT, COLLECTION_PATH) ([[NSString stringWithFormat:@"%s.%s",keypath(PATH), keypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String])

#define collectionKeypath4(OBJ, PATH, COLLECTION_OBJECT, COLLECTION_PATH) ([[NSString stringWithFormat:@"%s.%s",keypath(OBJ, PATH), keypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String])


```
The underlying mechanism also calls `keypath(PATH)`, so I won’t go into the details again here.


#### 4. RAC(TARGET, ...)

The macro is defined as follows:
```objectivec

#define RAC(TARGET, ...) \
        metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RAC_(TARGET, __VA_ARGS__, nil)) \
        (RAC_(TARGET, __VA_ARGS__))


```
`RAC(TARGET, ...)` works similarly to the previous `RACObserve(TARGET, KEYPATH)`. If there is only one argument, it calls `(RAC_(TARGET, __VA_ARGS__, nil))`; if there are multiple arguments, it calls `(RAC_(TARGET, __VA_ARGS__))`.
```objectivec


#define RAC_(TARGET, KEYPATH, NILVALUE) \
        [[RACSubscriptingAssignmentTrampoline alloc] initWithTarget:(TARGET) nilValue:(NILVALUE)][@keypath(TARGET, KEYPATH)]


```
At this point it’s quite clear: internally, it actually calls the `initWithTarget: nilValue:` method of the `RACSubscriptingAssignmentTrampoline` class.


As we all know, the `RAC(TARGET, ...)` macro is used to bind a signal to a property of an object. After the binding is established, every time the signal sends a new value, that value is automatically set on the specified keypath. When the signal completes, this binding is also automatically disposed of.

RAC\_(TARGET, KEYPATH, NILVALUE) binds the signal to the KEYPATH specified by TARGET. If the signal sends a nil value, it will be replaced with NILVALUE and assigned to the corresponding property.

RAC\_(TARGET, \_\_VA\_ARGS\_\_) is simply RAC\_(TARGET, KEYPATH, NILVALUE) with the third parameter set to nil.


#### 5. RACChannelTo(TARGET, ...)

The RACChannelTo(TARGET, ...) macro is directly comparable to RAC(TARGET, ...); the two are almost exactly the same.
```objectivec


#define RACChannelTo(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACChannelTo_(TARGET, __VA_ARGS__, nil)) \
        (RACChannelTo_(TARGET, __VA_ARGS__))


```
If there is only one argument, call (RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_, nil)); if there are multiple arguments, call (RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_)). (RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_)) is effectively equivalent to (RACChannelTo\_(TARGET, \_\_VA\_ARGS\_\_, nil)), with `nil` passed as the third argument.
```objectivec


#define RACChannelTo_(TARGET, KEYPATH, NILVALUE) \
    [[RACKVOChannel alloc] initWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][@keypath(RACKVOChannel.new, followingTerminal)]

```
Ultimately, it internally calls `RACKVOChannel`’s `initWithTarget: keyPath: nilValue:` method. The underlying mechanism is directly analogous to the expansion of the `RAC(TARGET, ...)` macro, so I won’t repeat it here.

In day-to-day use, we usually write it like this:
```objectivec

   RACChannelTo(view, objectProperty) = RACChannelTo(model, objectProperty);
   RACChannelTo(view, integerProperty, @2) = RACChannelTo(model, integerProperty, @10);


```

#### 6. onExit


The macro is defined as follows:
```objectivec

#define onExit \
    rac_keywordify \
    __strong rac_cleanupBlock_t metamacro_concat(rac_exitBlock_, __LINE__) __attribute__((cleanup(rac_executeCleanupBlock), unused)) = ^


```
Because of `rac_keywordify`, when using `onExit`, you also need to prefix it with the `@` symbol.

This macro is a bit special: it is followed by a closure, like this:
```objectivec

        @onExit {
		      free(attributes);
	    };

        @onExit {
				[objectLock unlock];
			};


```
`@onExit` defines code to be executed when the current code block exits. The code must be enclosed in braces and end with a semicolon. Regardless of how the code block is exited—including exceptions, `goto` statements, `return` statements, `break` statements, or `continue` statements—the code following `onExit` will be executed.

The code provided to `@onExit` is placed into a `block` and then executed later. Because it is inside a closure, it must also follow the relevant memory-management rules. `@onExit` is a reasonable way to exit a cleanup block early.

If there are multiple `@onExit` statements in the same code block, they are executed in reverse lexicographical order.

An `@onExit` statement cannot be used in a scope without braces. In practice, this is not an issue, because if there are no braces after `@onExit`, it is a useless construct and nothing will happen.


### Finally

![](https://img.halfrost.com/Blog/ArticleImage/39_11.jpg)

The implementation analysis of all macros in ReactiveCocoa is now complete. I think macros are a high-level abstraction over a piece of logic. Once a macro is designed by a developer with rigorous thinking, it becomes a kind of truly magical construct! If some simple and practical functionality or logic can be abstracted into macros, moving that work into preprocessing and saving runtime cost, then purely from a coding perspective, it is an extremely enjoyable thing to do. If there is an opportunity in the future, I hope to discuss more macro magic from Lisp with everyone.