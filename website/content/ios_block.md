+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Block", "__block"]
date = 2016-08-27T06:54:28Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/21_0_.png"
slug = "ios_block"
tags = ["iOS", "Block", "__block"]
title = "深入研究 Block 捕获外部变量和 __block 实现原理"

+++


#### 前言

Blocks是C语言的扩充功能，而Apple 在OS X Snow Leopard 和 iOS 4中引入了这个新功能“Blocks”。从那开始，Block就出现在iOS和Mac系统各个API中，并被大家广泛使用。一句话来形容Blocks，带有自动变量（局部变量）的匿名函数。

Block在OC中的实现如下：

```objectivec

struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor *descriptor;
    /* Imported variables. */
};

struct Block_descriptor {
    unsigned long int reserved;
    unsigned long int size;
    void (*copy)(void *dst, void *src);
    void (*dispose)(void *);
};
```

![](https://img.halfrost.com/Blog/ArticleImage/21_1.png)

从结构图中很容易看到isa，所以OC处理Block是按照对象来处理的。在iOS中，isa常见的就是\_NSConcreteStackBlock，\_NSConcreteMallocBlock，\_NSConcreteGlobalBlock这3种(另外只在GC环境下还有3种使用的\_NSConcreteFinalizingBlock，\_NSConcreteAutoBlock，\_NSConcreteWeakBlockVariable，本文暂不谈论这3种，有兴趣的看看官方文档)

以上介绍是Block的简要实现，接下来我们来仔细研究一下Block的捕获外部变量的特性以及\_\_block的实现原理。

**研究工具：clang**
为了研究编译器的实现原理，我们需要使用 clang 命令。clang 命令可以将 Objetive-C 的源码改写成 C / C++ 语言的，借此可以研究 block 中各个特性的源码实现方式。该命令是

```vim
clang -rewrite-objc block.c

```



####目录
- 1.Block捕获外部变量实质
- 2.Block的copy和release
- 3.Block中__block实现原理

#### 一.Block捕获外部变量实质


![](https://img.halfrost.com/Blog/ArticleImage/21_2.png)


拿起我们的Block一起来捕捉外部变量吧。

说到外部变量，我们要先说一下C语言中变量有哪几种。一般可以分为一下5种：

- 自动变量
- 函数参数 
- 静态变量
- 静态全局变量
- 全局变量

研究Block的捕获外部变量就要除去函数参数这一项，下面一一根据这4种变量类型的捕获情况进行分析。

我们先根据这4种类型
- 自动变量 
- 静态变量
- 静态全局变量
- 全局变量

写出Block测试代码。

![](https://img.halfrost.com/Blog/ArticleImage/21_3.png)


这里很快就出现了一个错误，提示说自动变量没有加\_\_block，由于\_\_block有点复杂，我们先实验静态变量，静态全局变量，全局变量这3类。测试代码如下：

```objectivec

#import <Foundation/Foundation.h>

int global_i = 1;

static int static_global_j = 2;

int main(int argc, const char * argv[]) {
   
    static int static_k = 3;
    int val = 4;
    
    void (^myBlock)(void) = ^{
        global_i ++;
        static_global_j ++;
        static_k ++;
        NSLog(@"Block中 global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    };
    
    global_i ++;
    static_global_j ++;
    static_k ++;
    val ++;
    NSLog(@"Block外 global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    
    myBlock();
    
    return 0;
}

```

运行结果
```vim
Block 外  global_i = 2,static_global_j = 3,static_k = 4,val = 5
Block 中  global_i = 3,static_global_j = 4,static_k = 5,val = 4
```

这里就有2点需要弄清楚了  
1.为什么在Block里面不加__bolck不允许更改变量？
2.为什么自动变量的值没有增加，而其他几个变量的值是增加的？自动变量是什么状态下被block捕获进去的？

为了弄清楚这2点，我们用clang转换一下源码出来分析分析。

（main.m代码行37行，文件大小832bype， 经过clang转换成main.cpp以后，代码行数飙升至104810行，文件大小也变成了3.1MB）

源码如下

```objectivec

int global_i = 1;

static int static_global_j = 2;

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  int *static_k;
  int val;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_k, int _val, int flags=0) : static_k(_static_k), val(_val) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  int *static_k = __cself->static_k; // bound by copy
  int val = __cself->val; // bound by copy

        global_i ++;
        static_global_j ++;
        (*static_k) ++;
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_6fe658_mi_0,global_i,static_global_j,(*static_k),val);
    }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};


int main(int argc, const char * argv[]) {

    static int static_k = 3;
    int val = 4;

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &static_k, val));

    global_i ++;
    static_global_j ++;
    static_k ++;
    val ++;
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_6fe658_mi_1,global_i,static_global_j,static_k,val);

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}
```

首先全局变量global\_i和静态全局变量static\_global\_j的值增加，以及它们被Block捕获进去，这一点很好理解，因为是全局的，作用域很广，所以Block捕获了它们进去之后，在Block里面进行++操作，Block结束之后，它们的值依旧可以得以保存下来。


接下来仔细看看自动变量和静态变量的问题。  
在\_\_main\_block\_impl\_0中，可以看到静态变量static\_k和自动变量val，被Block从外面捕获进来，成为\_\_main\_block\_impl\_0这个结构体的成员变量了。

接着看构造函数，

```objectivec

__main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_k, int _val, int flags=0) : static_k(_static_k), val(_val)

```
这个构造函数中，自动变量和静态变量被捕获为成员变量追加到了构造函数中。

main里面的myBlock闭包中的\_\_main\_block\_impl\_0结构体，初始化如下

```objectivec
void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &static_k, val));


impl.isa = &_NSConcreteStackBlock;
impl.Flags = 0;
impl.FuncPtr = __main_block_impl_0; 
Desc = &__main_block_desc_0_DATA;
*_static_k = 4；
val = 4; 
```
到此，\_\_main\_block\_impl\_0结构体就是这样把自动变量捕获进来的。也就是说，在执行Block语法的时候，Block语法表达式所使用的自动变量的值是被保存进了Block的结构体实例中，也就是Block自身中。


这里值得说明的一点是，如果Block外面还有很多自动变量，静态变量，等等，这些变量在Block里面并不会被使用到。那么这些变量并不会被Block捕获进来，也就是说并不会在构造函数里面传入它们的值。

Block捕获外部变量仅仅只捕获Block闭包里面会用到的值，其他用不到的值，它并不会去捕获。

再研究一下源码，我们注意到\_\_main\_block\_func\_0这个函数的实现

```objectivec

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  int *static_k = __cself->static_k; // bound by copy
  int val = __cself->val; // bound by copy

        global_i ++;
        static_global_j ++;
        (*static_k) ++;
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_6fe658_mi_0,global_i,static_global_j,(*static_k),val);
    }
```

我们可以发现，系统自动给我们加上的注释，bound by copy，自动变量val虽然被捕获进来了，但是是用 \_\_cself->val来访问的。Block仅仅捕获了val的值，并没有捕获val的内存地址。所以在\_\_main\_block\_func\_0这个函数中即使我们重写这个自动变量val的值，依旧没法去改变Block外面自动变量val的值。


OC可能是基于这一点，在编译的层面就防止开发者可能犯的错误，因为自动变量没法在Block中改变外部变量的值，所以编译过程中就报编译错误。错误就是最开始的那张截图。

```vim
Variable is not assignable(missing __block type specifier)

```

小结一下：  
到此为止，上面提出的第二个问题就解开答案了。自动变量是以值传递方式传递到Block的构造函数里面去的。Block只捕获Block中会用到的变量。由于只捕获了自动变量的值，并非内存地址，所以Block内部不能改变自动变量的值。Block捕获的外表变量可以改变值的是静态变量，静态全局变量，全局变量。上面例子也都证明过了。


剩下问题一我们还没有解决。

回到上面的例子上面来，4种变量里面只有静态变量，静态全局变量，全局变量这3种是可以在Block里面被改变值的。仔细观看源码，我们能看出这3个变量可以改变值的原因。

1. 静态全局变量，全局变量由于作用域的原因，于是可以直接在Block里面被改变。他们也都存储在全局区。  ![](https://img.halfrost.com/Blog/ArticleImage/21_4.png)


2. 静态变量传递给Block是内存地址值，所以能在Block里面直接改变值。


根据[官方文档](developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1)我们可以了解到，苹果要求我们在自动变量前加入 **\_\_block**关键字(\_\_block storage-class-specifier存储域类说明符)，就可以在Block里面改变外部自动变量的值了。

总结一下在Block中改变变量值有2种方式，一是传递内存地址指针到Block中，二是改变存储区方式(\_\_block)。

先来实验一下第一种方式，传递内存地址到Block中，改变变量的值。

```objectivec

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    
  NSMutableString * str = [[NSMutableString alloc]initWithString:@"Hello,"];
    
        void (^myBlock)(void) = ^{
            [str appendString:@"World!"];
            NSLog(@"Block中 str = %@",str);
        };
    
    NSLog(@"Block外 str = %@",str);
    
    myBlock();
    
    return 0;
}

```
控制台输出：

```vim
Block 外  str = Hello,
Block 中  str = Hello,World!

```
看结果是成功改变了变量的值了，转换一下源码。

```objectivec

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  NSMutableString *str;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, NSMutableString *_str, int flags=0) : str(_str) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  NSMutableString *str = __cself->str; // bound by copy

            ((void (*)(id, SEL, NSString *))(void *)objc_msgSend)((id)str, sel_registerName("appendString:"), (NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_33ff12_mi_1);
            NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_33ff12_mi_2,str);
        }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->str, (void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

int main(int argc, const char * argv[]) {
    NSMutableString * str = ((NSMutableString *(*)(id, SEL, NSString *))(void *)objc_msgSend)((id)((NSMutableString *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSMutableString"), sel_registerName("alloc")), sel_registerName("initWithString:"), (NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_33ff12_mi_0);

        void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, str, 570425344));

    NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_33ff12_mi_3,str);

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}
```
在\_\_main\_block\_func\_0里面可以看到传递的是指针。所以成功改变了变量的值。

至于源码里面的copy和dispose下一节会讲到。

改变外部变量值的第二种方式是加 \_\_block这个放在第三章里面讨论，接下来我们先讨论一下Block的copy的问题，因为这个问题会关系到 \_\_block存储域的问题。


#### 二.Block的copy和dispose


![](https://img.halfrost.com/Blog/ArticleImage/21_5.jpg)



OC中，一般Block就分为以下3种，\_NSConcreteStackBlock，\_NSConcreteMallocBlock，\_NSConcreteGlobalBlock。先来说明一下3者的区别。

##### 1.从捕获外部变量的角度上来看

- _NSConcreteStackBlock：
只用到外部局部变量、成员属性变量，且没有强指针引用的block都是StackBlock。
StackBlock的生命周期由系统控制的，一旦返回之后，就被系统销毁了。

- _NSConcreteMallocBlock：
有强指针引用或copy修饰的成员属性引用的block会被复制一份到堆中成为MallocBlock，没有强指针引用即销毁，生命周期由程序员控制

- _NSConcreteGlobalBlock：
没有用到外界变量或只用到全局变量、静态变量的block为\_NSConcreteGlobalBlock，生命周期从创建到应用程序结束。

没有用到外部变量肯定是\_NSConcreteGlobalBlock，这点很好理解。不过只用到全局变量、静态变量的block也是\_NSConcreteGlobalBlock。举例如下：

```objectivec

#import <Foundation/Foundation.h>

int global_i = 1;
static int static_global_j = 2;

int main(int argc, const char * argv[]) {
   
    static int static_k = 3;

    void (^myBlock)(void) = ^{
            NSLog(@"Block中 变量 = %d %d %d",static_global_j ,static_k, global_i);
        };
    
    NSLog(@"%@",myBlock);
    
    myBlock();
    
    return 0;
}

```
输出：

```vim
<__NSGlobalBlock__: 0x100001050>
Block中 变量 = 2 3 1
```

可见，只用到全局变量、静态变量的block也可以是_NSConcreteGlobalBlock。


所以在ARC环境下，3种类型都可以捕获外部变量。

##### 2.从持有对象的角度上来看：

- _NSConcreteStackBlock是不持有对象的。

```objectivec

//以下是在MRC下执行的
    NSObject * obj = [[NSObject alloc]init];
    NSLog(@"1.Block外 obj = %lu",(unsigned long)obj.retainCount);
    
    void (^myBlock)(void) = ^{
        NSLog(@"Block中 obj = %lu",(unsigned long)obj.retainCount);
    };
    
    NSLog(@"2.Block外 obj = %lu",(unsigned long)obj.retainCount);
    
    myBlock();
```

输出：

```vim
1.Block外 obj = 1
2.Block外 obj = 1
Block中 obj = 1
```

- _NSConcreteMallocBlock是持有对象的。

```objectivec
//以下是在MRC下执行的
    NSObject * obj = [[NSObject alloc]init];
    NSLog(@"1.Block外 obj = %lu",(unsigned long)obj.retainCount);
    
    void (^myBlock)(void) = [^{
        NSLog(@"Block中 obj = %lu",(unsigned long)obj.retainCount);
    }copy];
    
    NSLog(@"2.Block外 obj = %lu",(unsigned long)obj.retainCount);
    
    myBlock();
    
    [myBlock release];
    
    NSLog(@"3.Block外 obj = %lu",(unsigned long)obj.retainCount);
```

输出：

```vim
1.Block外 obj = 1
2.Block外 obj = 2
Block中 obj = 2
3.Block外 obj = 1
```

- _NSConcreteGlobalBlock也不持有对象

```objectivec
//以下是在MRC下执行的
    void (^myBlock)(void) = ^{
        
        NSObject * obj = [[NSObject alloc]init];
        NSLog(@"Block中 obj = %lu",(unsigned long)obj.retainCount);
    };
    
    myBlock();

```

输出：

```vim

Block 中 obj = 1
```

由于_NSConcreteStackBlock所属的变量域一旦结束，那么该Block就会被销毁。在ARC环境下，编译器会自动的判断，把Block自动的从栈copy到堆。比如当Block作为函数返回值的时候，肯定会copy到堆上。

1.手动调用copy
2.Block是函数的返回值
3.Block被强引用，Block被赋值给__strong或者id类型
4.调用系统API入参中含有usingBlcok的方法

以上4种情况，系统都会默认调用copy方法把Block赋复制

但是当Block为函数参数的时候，就需要我们手动的copy一份到堆上了。这里除去系统的API我们不需要管，比如GCD等方法中本身带usingBlock的方法，其他我们自定义的方法传递Block为参数的时候都需要手动copy一份到堆上。

copy函数把Block从栈上拷贝到堆上，dispose函数是把堆上的函数在废弃的时候销毁掉。

```objectivec

#define Block_copy(...) ((__typeof(__VA_ARGS__))_Block_copy((const void *)(__VA_ARGS__)))
#define Block_release(...) _Block_release((const void *)(__VA_ARGS__))

// Create a heap based copy of a Block or simply add a reference to an existing one.
// This must be paired with Block_release to recover memory, even when running
// under Objective-C Garbage Collection.
BLOCK_EXPORT void *_Block_copy(const void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);

// Lose the reference, and if heap based and last reference, recover the memory
BLOCK_EXPORT void _Block_release(const void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);

// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_assign(void *, const void *, const int)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);

// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_dispose(const void *, const int)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
```

上面是源码中2个常用的宏定义和4个常用的方法，一会我们就会看到这4个方法。


```objectivec

static void *_Block_copy_internal(const void *arg, const int flags) {
    struct Block_layout *aBlock;
    const bool wantsOne = (WANTS_ONE & flags) == WANTS_ONE;
    
    // 1
    if (!arg) return NULL;
    
    // 2
    aBlock = (struct Block_layout *)arg;
    
    // 3
    if (aBlock->flags & BLOCK_NEEDS_FREE) {
        // latches on high
        latching_incr_int(&aBlock->flags);
        return aBlock;
    }
    
    // 4
    else if (aBlock->flags & BLOCK_IS_GLOBAL) {
        return aBlock;
    }
    
    // 5
    struct Block_layout *result = malloc(aBlock->descriptor->size);
    if (!result) return (void *)0;
    
    // 6
    memmove(result, aBlock, aBlock->descriptor->size); // bitcopy first
    
    // 7
    result->flags &= ~(BLOCK_REFCOUNT_MASK);    // XXX not needed
    result->flags |= BLOCK_NEEDS_FREE | 1;
    
    // 8
    result->isa = _NSConcreteMallocBlock;
    
    // 9
    if (result->flags & BLOCK_HAS_COPY_DISPOSE) {
        (*aBlock->descriptor->copy)(result, aBlock); // do fixup
    }
    
    return result;
}
```

上面这一段是Block\_copy的一个实现，实现了从\_NSConcreteStackBlock复制到\_NSConcreteMallocBlock的过程。对应有9个步骤。


```objectivec

void _Block_release(void *arg) {
    // 1
    struct Block_layout *aBlock = (struct Block_layout *)arg;
    if (!aBlock) return;
    
    // 2
    int32_t newCount;
    newCount = latching_decr_int(&aBlock->flags) & BLOCK_REFCOUNT_MASK;
    
    // 3
    if (newCount > 0) return;
    
    // 4
    if (aBlock->flags & BLOCK_NEEDS_FREE) {
        if (aBlock->flags & BLOCK_HAS_COPY_DISPOSE)(*aBlock->descriptor->dispose)(aBlock);
        _Block_deallocator(aBlock);
    }
    
    // 5
    else if (aBlock->flags & BLOCK_IS_GLOBAL) {
        ;
    }
    
    // 6
    else {
        printf("Block_release called upon a stack Block: %p, ignored\n", (void *)aBlock);
    }
}
```

上面这一段是Block\_release的一个实现，实现了怎么释放一个Block。对应有6个步骤。

上述2个方法的详细解析可以看这篇[文章](http://www.galloway.me.uk/2013/05/a-look-inside-blocks-episode-3-block-copy/)


回到上一章节中最后的例子，字符串的例子中来，转换源码之后，我们会发现多了一个copy和dispose方法。

因为在C语言的结构体中，编译器没法很好的进行初始化和销毁操作。这样对内存管理来说是很不方便的。所以就在 \_\_main\_block\_desc\_0结构体中间增加成员变量 void (\*copy)(struct  \_\_main\_block\_impl\_0\*, struct \_\_main\_block\_impl\_0\*)和void (\*dispose)(struct \_\_main\_block\_impl\_0\*)，利用OC的Runtime进行内存管理。

相应的增加了2个方法。

```objectivec
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->str, (void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

```
这里的\_Block\_object\_assign和\_Block\_object\_dispose就对应着retain和release方法。

BLOCK\_FIELD\_IS\_OBJECT 是Block截获对象时候的特殊标示，如果是截获的\_\_block，那么是BLOCK\_FIELD\_IS\_BYREF。

#### 三.Block中\_\_block实现原理

我们继续研究一下\_\_block实现原理。

##### 1.普通非对象的变量


先来看看普通变量的情况。

```objectivec

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    
    __block int i = 0;
    
    void (^myBlock)(void) = ^{
        i ++;
        NSLog(@"%d",i);
    };
    
    myBlock();
    
    return 0;
}
```
把上述代码用clang转换成源码。

```objectivec

struct __Block_byref_i_0 {
  void *__isa;
__Block_byref_i_0 *__forwarding;
 int __flags;
 int __size;
 int i;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __Block_byref_i_0 *i; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_i_0 *_i, int flags=0) : i(_i->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_i_0 *i = __cself->i; // bound by ref

        (i->__forwarding->i) ++;
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_3b0837_mi_0,(i->__forwarding->i));
    }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->i, (void*)src->i, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->i, 8/*BLOCK_FIELD_IS_BYREF*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};
int main(int argc, const char * argv[]) {
    __attribute__((__blocks__(byref))) __Block_byref_i_0 i = {(void*)0,(__Block_byref_i_0 *)&i, 0, sizeof(__Block_byref_i_0), 0};

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_i_0 *)&i, 570425344));

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}
```
从源码我们能发现，带有 \_\_block的变量也被转化成了一个结构体\_\_Block\_byref\_i\_0,这个结构体有5个成员变量。第一个是isa指针，第二个是指向自身类型的\_\_forwarding指针，第三个是一个标记flag，第四个是它的大小，第五个是变量值，名字和变量名同名。

```objectivec
__attribute__((__blocks__(byref))) __Block_byref_i_0 i = {(void*)0,(__Block_byref_i_0 *)&i, 0, sizeof(__Block_byref_i_0), 0};

```
源码中是这样初始化的。\_\_forwarding指针初始化传递的是自己的地址。然而这里\_\_forwarding指针真的永远指向自己么？我们来做一个实验。


```objectivec

//以下代码在MRC中运行
    __block int i = 0;
    NSLog(@"%p",&i);
    
    void (^myBlock)(void) = [^{
        i ++;
        NSLog(@"这是Block 里面%p",&i);
    }copy];

```
我们把Block拷贝到了堆上，这个时候打印出来的2个i变量的地址就不同了。

```vim
0x7fff5fbff818
<__NSMallocBlock__: 0x100203cc0>
这是Block 里面 0x1002038a8
```

地址不同就可以很明显的说明\_\_forwarding指针并没有指向之前的自己了。那\_\_forwarding指针现在指向到哪里了呢？

Block里面的\_\_block的地址和Block的地址就相差1052。我们可以很大胆的猜想，\_\_block现在也在堆上了。

出现这个不同的原因在于这里把Block拷贝到了堆上。

由第二章里面详细分析的，堆上的Block会持有对象。我们把Block通过copy到了堆上，堆上也会重新复制一份Block，并且该Block也会继续持有该\_\_block。当Block释放的时候，\_\_block没有被任何对象引用，也会被释放销毁。


\_\_forwarding指针这里的作用就是针对堆的Block，把原来\_\_forwarding指针指向自己，换成指向\_NSConcreteMallocBlock上复制之后的\_\_block自己。然后堆上的变量的\_\_forwarding再指向自己。这样不管\_\_block怎么复制到堆上，还是在栈上，都可以通过(i->\_\_forwarding->i)来访问到变量值。

![](https://img.halfrost.com/Blog/ArticleImage/21_6.jpg)

所以在\_\_main\_block\_func\_0函数里面就是写的(i->\_\_forwarding->i)。

这里还有一个需要注意的地方。还是从例子说起：

```objectivec
//以下代码在MRC中运行
    __block int i = 0;
    NSLog(@"%p",&i);
    
    void (^myBlock)(void) = ^{
        i ++;
        NSLog(@"Block 里面的%p",&i);
    };
    
    
    NSLog(@"%@",myBlock);
    
    myBlock();

```

结果和之前copy的例子完全不同。

```vim

 0x7fff5fbff818
<__NSStackBlock__: 0x7fff5fbff7c0>**
 0x7fff5fbff818

```

Block在捕获住\_\_block变量之后，并不会复制到堆上，所以地址也一直都在栈上。这与ARC环境下的不一样。

~~ARC环境下，不管有没有copy，\_\_block都会变copy到堆上，Block也是\_\_NSMallocBlock。~~

感谢@酷酷的哀殿 指出错误，感谢@bestswifter 指点。上述说法有点不妥，详细见文章末尾更新。

ARC环境下，一旦Block赋值就会触发copy，\_\_block就会copy到堆上，Block也是\_\_NSMallocBlock。ARC环境下也是存在\_\_NSStackBlock的时候，这种情况下，__block就在栈上。

MRC环境下，只有copy，\_\_block才会被复制到堆上，否则，\_\_block一直都在栈上，block也只是\_\_NSStackBlock，这个时候\_\_forwarding指针就只指向自己了。


![](https://img.halfrost.com/Blog/ArticleImage/21_7.jpg)


至此，文章开头提出的问题一，也解答了。\_\_block的实现原理也已经明了。



##### 2.对象的变量

还是先举一个例子：


```objectivec

//以下代码是在ARC下执行的
#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
     
    __block id block_obj = [[NSObject alloc]init];
    id obj = [[NSObject alloc]init];

    NSLog(@"block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    
    void (^myBlock)(void) = ^{
        NSLog(@"***Block中****block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    };
    
    myBlock();
   
    return 0;
}

```

输出

```vim

block_obj = [<NSObject: 0x100b027d0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b03b50> , 0x7fff5fbff7b8]
Block****中********block_obj = [<NSObject: 0x100b027d0> , 0x100f000a8] , obj = [<NSObject: 0x100b03b50> , 0x100f00070]

```

我们把上面的代码转换成源码研究一下：

```objectivec

struct __Block_byref_block_obj_0 {
  void *__isa;
__Block_byref_block_obj_0 *__forwarding;
 int __flags;
 int __size;
 void (*__Block_byref_id_object_copy)(void*, void*);
 void (*__Block_byref_id_object_dispose)(void*);
 id block_obj;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  id obj;
  __Block_byref_block_obj_0 *block_obj; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, id _obj, __Block_byref_block_obj_0 *_block_obj, int flags=0) : obj(_obj), block_obj(_block_obj->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_block_obj_0 *block_obj = __cself->block_obj; // bound by ref
  id obj = __cself->obj; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_e64910_mi_1,(block_obj->__forwarding->block_obj) , &(block_obj->__forwarding->block_obj) , obj , &obj);
    }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->block_obj, (void*)src->block_obj, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_assign((void*)&dst->obj, (void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->block_obj, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_dispose((void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};


int main(int argc, const char * argv[]) {

    __attribute__((__blocks__(byref))) __Block_byref_block_obj_0 block_obj = {(void*)0,(__Block_byref_block_obj_0 *)&block_obj, 33554432, sizeof(__Block_byref_block_obj_0), __Block_byref_id_object_copy_131, __Block_byref_id_object_dispose_131, ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"))};

    id obj = ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"));
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_e64910_mi_0,(block_obj.__forwarding->block_obj) , &(block_obj.__forwarding->block_obj) , obj , &obj);

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, obj, (__Block_byref_block_obj_0 *)&block_obj, 570425344));

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}
```

首先需要说明的一点是对象在OC中，默认声明自带\_\_strong所有权修饰符的，所以main开头我们声明的

```objectivec

__block id block_obj = [[NSObject alloc]init];
id obj = [[NSObject alloc]init];

```
等价于 

```objectivec

__block id __strong block_obj = [[NSObject alloc]init];
id __strong obj = [[NSObject alloc]init];
```

在转换出来的源码中，我们也可以看到，Block捕获了\_\_block，并且强引用了，因为在\_\_Block\_byref\_block\_obj\_0结构体中，有一个变量是id block\_obj，这个默认也是带\_\_strong所有权修饰符的。

根据打印出来的结果来看，ARC环境下，Block捕获外部对象变量，是都会copy一份的，地址都不同。只不过带有\_\_block修饰符的变量会被捕获到Block内部持有。

我们再来看看MRC环境下的情况，还是将上述代码的例子运行在MRC中。

输出：

```objectivec

block_obj = [<NSObject: 0x100b001b0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b001c0> , 0x7fff5fbff7b8]
Block****中********block_obj = [<NSObject: 0x100b001b0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b001c0> , 0x7fff5fbff790]

```

这个时候block在栈上，\_\_NSStackBlock\_\_，可以打印出来retainCount值都是1。当把这个block copy一下，就变成\_\_NSMallocBlock\_\_，对象的retainCount值就会变成2了。

总结：  

在MRC环境下，\_\_block根本不会对指针所指向的对象执行copy操作，而只是把指针进行的复制。
而在ARC环境下，对于声明为\_\_block的外部对象，在block内部会进行retain，以至于在block环境内能安全的引用外部对象，所以才会产生循环引用的问题！

在ARC环境下，对于没有声明为\_\_block的外部对象，也会被retain。

(感谢@南栀倾寒 指点。由于之前结论只说了ARC环境下\_\_block的外部对象的情况，没有说明非\_\_block的外部对象的情况，所以可能会引起歧义，特此说明一下。在ARC环境下，不仅仅是声明了\_\_block的外部对象，没有加\_\_block的对象，在block内部也会被retain。因为加了\_\_block，只是对一个自动变量有影响，它们是指针，   相当于延长了指针变量的声明周期，只要访问对象的话还是会retain。)

#### 最后

关于Block捕获外部变量有很多用途，用途也很广，只有弄清了捕获变量和持有的变量的概念以后，之后才能清楚的解决Block循环引用的问题。

再次回到文章开头，5种变量，自动变量，函数参数 ，静态变量，静态全局变量，全局变量，如果严格的来说，捕获是必须在Block结构体\_\_main\_block\_impl\_0里面有成员变量的话，Block能捕获的变量就只有带有自动变量和静态变量了。捕获进Block的对象会被Block持有。

对于非对象的变量来说，

自动变量的值，被copy进了Block，不带\_\_block的自动变量只能在里面被访问，并不能改变值。

![](https://img.halfrost.com/Blog/ArticleImage/21_8.jpg)


带\_\_block的自动变量 和 静态变量 就是直接地址访问。所以在Block里面可以直接改变变量的值。

![](https://img.halfrost.com/Blog/ArticleImage/21_9.jpg)


而剩下的静态全局变量，全局变量，函数参数，也是可以在直接在Block中改变变量值的，但是他们并没有变成Block结构体\_\_main\_block\_impl\_0的成员变量，因为他们的作用域大，所以可以直接更改他们的值。




值得注意的是，静态全局变量，全局变量，函数参数他们并不会被Block持有，也就是说不会增加retainCount值。


对于对象来说，

在MRC环境下，\_\_block根本不会对指针所指向的对象执行copy操作，而只是把指针进行的复制。
而在ARC环境下，对于声明为\_\_block的外部对象，在block内部会进行retain，以至于在block环境内能安全的引用外部对象。对于没有声明\_\_block的外部对象，在block中也会被retain。


请大家多多指点。


**更新**



在ARC环境下，Block也是存在\_\_NSStackBlock的时候的，平时见到最多的是\_NSConcreteMallocBlock，是因为我们会对Block有赋值操作，所以ARC下，block 类型通过=进行传递时，会导致调用objc\_retainBlock->\_Block\_copy->\_Block\_copy\_internal方法链。并导致 \_\_NSStackBlock\_\_ 类型的 block 转换为 \_\_NSMallocBlock\_\_ 类型。

举例如下：

```objectivec

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    
    __block int temp = 10;
    
    NSLog(@"%@",^{NSLog(@"*******%d %p",temp ++,&temp);});
   
    return 0;
}
```

输出

```vim
<__NSStackBlock__: 0x7fff5fbff768>
```

这种情况就是ARC环境下Block是\_\_NSStackBlock的类型。

