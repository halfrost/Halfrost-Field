# In-Depth Study of How Blocks Capture External Variables and How __block Is Implemented

![](https://img.halfrost.com/Blog/ArticleTitleImage/21_0_.png)


#### Preface

Blocks are an extension to the C language, and Apple introduced this new feature, “Blocks,” in OS X Snow Leopard and iOS 4. Since then, Blocks have appeared throughout the APIs of iOS and Mac systems and have been widely used. In one sentence, Blocks are anonymous functions that carry automatic variables (local variables).

The implementation of Blocks in OC is as follows:
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

The structure diagram makes it easy to see `isa`, so OC handles Blocks as objects. In iOS, the common `isa` values are `_NSConcreteStackBlock`, `_NSConcreteMallocBlock`, and `_NSConcreteGlobalBlock` (there are also three types used only in GC environments: `_NSConcreteFinalizingBlock`, `_NSConcreteAutoBlock`, and `_NSConcreteWeakBlockVariable`. This article will not discuss these three; if you are interested, see the official documentation).

The above is a brief introduction to the implementation of Block. Next, let’s take a closer look at how Block captures external variables and how `__block` is implemented.

**Research tool: clang**
To study the compiler’s implementation principles, we need to use the `clang` command. The `clang` command can rewrite Objective-C source code into C / C++, which lets us examine how each Block feature is implemented at the source level. The command is
```vim
clang -rewrite-objc block.c

```

#### Table of Contents
- 1. The Essence of How Blocks Capture External Variables
- 2. Block copy and release
- 3. Implementation Principles of `__block` in Blocks

#### 1. The Essence of How Blocks Capture External Variables


![](https://img.halfrost.com/Blog/ArticleImage/21_2.png)


Let’s pick up our Block and capture some external variables.

Speaking of external variables, we first need to talk about the kinds of variables in C. In general, they can be divided into the following five categories:

- automatic variables
- function parameters 
- static variables
- static global variables
- global variables

To study how Blocks capture external variables, we need to exclude function parameters. Below, we will analyze the capture behavior for each of the remaining four variable types.

Based on these four types:
- automatic variables 
- static variables
- static global variables
- global variables

we write Block test code.

![](https://img.halfrost.com/Blog/ArticleImage/21_3.png)


An error appears almost immediately here, indicating that the automatic variable is not marked with `__block`. Since `__block` is somewhat complex, let’s first experiment with the three categories of static variables, static global variables, and global variables. The test code is as follows:
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
        NSLog(@"Inside Block global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    };
    
    global_i ++;
    static_global_j ++;
    static_k ++;
    val ++;
    NSLog(@"Outside Block global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    
    myBlock();
    
    return 0;
}

```
Execution Result
```vim
Block outside  global_i = 2,static_global_j = 3,static_k = 4,val = 5
Block inside  global_i = 3,static_global_j = 4,static_k = 5,val = 4
```
There are two things we need to clarify here:  
1. Why is it not allowed to modify a variable inside a Block unless `__block` is added?
2. Why does the value of the automatic variable not increase, while the values of the other variables do? In what state is an automatic variable captured by a block?

To clarify these two points, let’s use clang to convert the source code and analyze the result.

(`main.m` has 37 lines of code and a file size of 832 bytes. After being converted by clang into `main.cpp`, the code balloons to 104,810 lines, and the file size becomes 3.1 MB.)

The source code is as follows:
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
First, it is easy to understand why the values of the global variable global\_i and the static global variable static\_global\_j increase, and why they are captured by the Block. Since they are global and have a very broad scope, after the Block captures them and performs the ++ operation inside the Block, their values can still be preserved after the Block ends.


Next, let’s take a closer look at automatic variables and static variables.  
In \_\_main\_block\_impl\_0, you can see that the static variable static\_k and the automatic variable val are captured by the Block from the outside and become member variables of the \_\_main\_block\_impl\_0 struct.

Next, look at the constructor,
```objectivec

__main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_k, int _val, int flags=0) : static_k(_static_k), val(_val)

```
In this constructor, automatic variables and static variables are captured as member variables and added to the constructor.

The \_\_main\_block\_impl\_0 struct in the myBlock closure inside main is initialized as follows.
```objectivec
void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &static_k, val));


impl.isa = &_NSConcreteStackBlock;
impl.Flags = 0;
impl.FuncPtr = __main_block_impl_0; 
Desc = &__main_block_desc_0_DATA;
*_static_k = 4；
val = 4; 
```
At this point, this is how the \_\_main\_block\_impl\_0 struct captures automatic variables. In other words, when executing Block syntax, the values of the automatic variables used by the Block expression are saved into the Block’s struct instance—that is, into the Block itself.

One point worth noting here is that if there are many automatic variables, static variables, and so on outside the Block, but those variables are not used inside the Block, then they will not be captured by the Block. In other words, their values will not be passed into the constructor.

When a Block captures external variables, it only captures the values that are actually used inside the Block closure. Values that are not used will not be captured.

Looking further into the source code, we notice the implementation of the \_\_main\_block\_func\_0 function.
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
We can see that the system automatically adds the comment `bound by copy` for us. Although the automatic variable `val` is captured, it is accessed via `__cself->val`. The Block only captures the value of `val`; it does not capture the memory address of `val`. Therefore, even if we rewrite the value of the automatic variable `val` inside the `__main_block_func_0` function, we still cannot change the value of the automatic variable `val` outside the Block.

OC may be based on this point: at the compilation level, it prevents mistakes developers might make. Since an automatic variable cannot change the value of an external variable inside a Block, the compiler reports a compilation error during compilation. That error is the one shown in the screenshot at the beginning.
```vim
Variable is not assignable(missing __block type specifier)

```
A quick summary:  
At this point, the second question raised above has been answered. Automatic variables are passed by value into the Block’s constructor. A Block captures only the variables that are used inside the Block. Because it captures only the value of an automatic variable, not its memory address, the value of an automatic variable cannot be changed inside the Block. The external variables captured by a Block whose values can be changed are static variables, static global variables, and global variables. The examples above have already demonstrated this.


The remaining first question has not been resolved yet.

Returning to the example above, among the four types of variables, only static variables, static global variables, and global variables can have their values changed inside a Block. By carefully examining the source code, we can see why these three variables can be modified.

1. Static global variables and global variables can be changed directly inside a Block because of their scope. They are also stored in the global area.  ![](https://img.halfrost.com/Blog/ArticleImage/21_4.png)


2. Static variables are passed to a Block as memory address values, so their values can be changed directly inside the Block.


According to the [official documentation](developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1), Apple requires us to add the **\_\_block** keyword before an automatic variable (\_\_block storage-class-specifier, storage-class specifier) so that the value of an external automatic variable can be changed inside a Block.

To summarize, there are two ways to change a variable’s value inside a Block: one is to pass a memory address pointer into the Block, and the other is to change the storage class (\_\_block).

First, let’s experiment with the first approach: passing a memory address into a Block and changing the variable’s value.
```objectivec

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    
  NSMutableString * str = [[NSMutableString alloc]initWithString:@"Hello,"];
    
        void (^myBlock)(void) = ^{
            [str appendString:@"World!"];
            NSLog(@"Inside block str = %@",str);
        };
    
    NSLog(@"Outside block str = %@",str);
    
    myBlock();
    
    return 0;
}

```
Console output:
```vim
Block outside  str = Hello,
Block inside  str = Hello,World!

```
The result shows that the variable’s value was successfully changed. Let’s convert the source code.
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
In \_\_main\_block\_func\_0, you can see that what is passed is a pointer. Therefore, the variable’s value is successfully changed.

As for `copy` and `dispose` in the source code, they will be covered in the next section.

The second way to change the value of an external variable is to add \_\_block. This will be discussed in Chapter 3. Next, let’s first discuss the issue of copying Blocks, because this is related to the storage domain of \_\_block.


#### II. Block copy and dispose


![](https://img.halfrost.com/Blog/ArticleImage/21_5.jpg)


In OC, Blocks are generally divided into the following three types: \_NSConcreteStackBlock, \_NSConcreteMallocBlock, and \_NSConcreteGlobalBlock. Let’s first explain the differences among them.

##### 1. From the perspective of capturing external variables

- _NSConcreteStackBlock：
Blocks that only use external local variables or member property variables, and do not have strong pointer references, are all StackBlocks.
The lifecycle of a StackBlock is controlled by the system. Once it returns, it is destroyed by the system.

- _NSConcreteMallocBlock：
A Block that has a strong pointer reference, or is referenced by a member property modified with `copy`, will be copied to the heap and become a MallocBlock. If there is no strong pointer reference, it will be destroyed. Its lifecycle is controlled by the programmer.

- _NSConcreteGlobalBlock：
A Block that does not use any external variables, or only uses global variables or static variables, is a \_NSConcreteGlobalBlock. Its lifecycle lasts from creation until the application exits.

A Block that does not use external variables is definitely a \_NSConcreteGlobalBlock, which is easy to understand. However, a Block that only uses global variables or static variables is also a \_NSConcreteGlobalBlock. For example:
```objectivec

#import <Foundation/Foundation.h>

int global_i = 1;
static int static_global_j = 2;

int main(int argc, const char * argv[]) {
   
    static int static_k = 3;

    void (^myBlock)(void) = ^{
            NSLog(@"Variables in Block = %d %d %d",static_global_j ,static_k, global_i);
        };
    
    NSLog(@"%@",myBlock);
    
    myBlock();
    
    return 0;
}

```
Output:
```vim
<__NSGlobalBlock__: 0x100001050>
Block variable = 2 3 1
```
As you can see, a block that uses only global variables or static variables can also be an _NSConcreteGlobalBlock.

Therefore, in an ARC environment, all three types can capture external variables.

##### 2. From the perspective of object ownership:

- _NSConcreteStackBlock does not retain objects.
```objectivec

//The following is executed under MRC
    NSObject * obj = [[NSObject alloc]init];
    NSLog(@"1.Outside Block obj = %lu",(unsigned long)obj.retainCount);
    
    void (^myBlock)(void) = ^{
        NSLog(@"Inside Block obj = %lu",(unsigned long)obj.retainCount);
    };
    
    NSLog(@"2.Outside Block obj = %lu",(unsigned long)obj.retainCount);
    
    myBlock();
```
Output:
```vim
1.Block outside obj = 1
2.Block outside obj = 1
Block inside obj = 1
```
- _NSConcreteMallocBlock retains objects.
```objectivec
//The following is executed under MRC
    NSObject * obj = [[NSObject alloc]init];
    NSLog(@"1.Outside Block obj = %lu",(unsigned long)obj.retainCount);
    
    void (^myBlock)(void) = [^{
        NSLog(@"Inside Block obj = %lu",(unsigned long)obj.retainCount);
    }copy];
    
    NSLog(@"2.Outside Block obj = %lu",(unsigned long)obj.retainCount);
    
    myBlock();
    
    [myBlock release];
    
    NSLog(@"3.Outside Block obj = %lu",(unsigned long)obj.retainCount);
```
Output:
```vim
1.Outside Block obj = 1
2.Outside Block obj = 2
Inside Block obj = 2
3.Outside Block obj = 1
```
- _NSConcreteGlobalBlock also does not retain objects
```objectivec
//The following is executed under MRC
    void (^myBlock)(void) = ^{
        
        NSObject * obj = [[NSObject alloc]init];
        NSLog(@"obj in Block = %lu",(unsigned long)obj.retainCount);
    };
    
    myBlock();

```
Output:
```vim

Block in obj = 1
```
Because the variable scope to which `_NSConcreteStackBlock` belongs ends, the Block is destroyed. In an ARC environment, the compiler automatically determines whether to copy the Block from the stack to the heap. For example, when a Block is used as a function return value, it will definitely be copied to the heap.

1. Manually calling `copy`
2. The Block is the return value of a function
3. The Block is strongly referenced; the Block is assigned to a `__strong` or `id` type
4. Calling a system API method whose parameters include `usingBlcok`

In the four cases above, the system will call the `copy` method by default to copy the Block.

However, when a Block is used as a function parameter, we need to manually copy it to the heap. This excludes system APIs, which we do not need to worry about—for example, methods such as GCD APIs that themselves include `usingBlock`. For other custom methods where we pass a Block as a parameter, we need to manually copy it to the heap.

The `copy` function copies a Block from the stack to the heap, and the `dispose` function destroys the function on the heap when it is discarded.
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
Above are two commonly used macro definitions and four commonly used methods in the source code. We’ll see these four methods shortly.
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
The section above is an implementation of `Block_copy`, which implements the process of copying from `_NSConcreteStackBlock` to `_NSConcreteMallocBlock`. It consists of 9 steps.
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
The paragraph above is one implementation of `Block_release`, showing how a Block is released. It consists of six steps.

For a detailed analysis of the two methods above, see this [article](http://www.galloway.me.uk/2013/05/a-look-inside-blocks-episode-3-block-copy/).

Returning to the final example from the previous section—the string example—after converting the source code, we will find that two additional methods, `copy` and `dispose`, have been added.

Because in C structs the compiler cannot perform initialization and destruction very well, this is quite inconvenient for memory management. Therefore, the member variables `void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*)` and `void (*dispose)(struct __main_block_impl_0*)` are added to the `__main_block_desc_0` struct, using the Objective-C Runtime for memory management.

Accordingly, two methods are added.
```objectivec
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->str, (void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->str, 3/*BLOCK_FIELD_IS_OBJECT*/);}

```
Here, \_Block\_object\_assign and \_Block\_object\_dispose correspond to the retain and release methods.

BLOCK\_FIELD\_IS\_OBJECT is a special flag used when a Block captures an object. If it captures a \_\_block variable, then the flag is BLOCK\_FIELD\_IS\_BYREF.

#### III. How \_\_block Is Implemented in Blocks

Let’s continue by examining how \_\_block is implemented.

##### 1. Ordinary Non-Object Variables


First, let’s look at the case of ordinary variables.
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
Convert the above code into source code using clang.
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
From the source code, we can see that a variable annotated with \_\_block is also transformed into a struct named \_\_Block\_byref\_i\_0. This struct has five member variables. The first is an isa pointer, the second is a \_\_forwarding pointer that points to its own type, the third is a flag, the fourth is its size, and the fifth is the variable’s value, whose name is the same as the original variable name.
```objectivec
__attribute__((__blocks__(byref))) __Block_byref_i_0 i = {(void*)0,(__Block_byref_i_0 *)&i, 0, sizeof(__Block_byref_i_0), 0};

```
In the source code, it is initialized like this. The \_\_forwarding pointer is initialized by passing its own address. But does the \_\_forwarding pointer here really always point to itself? Let’s run an experiment.
```objectivec

//The following code runs in MRC
    __block int i = 0;
    NSLog(@"%p",&i);
    
    void (^myBlock)(void) = [^{
        i ++;
        NSLog(@"This is inside the Block %p",&i);
    }copy];

```
We copied the Block onto the heap, and at this point the addresses of the two `i` variables printed are different.
```vim
0x7fff5fbff818
<__NSMallocBlock__: 0x100203cc0>
This is inside Block 0x1002038a8
```
The different addresses clearly show that the `__forwarding` pointer no longer points to its original self. So where does the `__forwarding` pointer point now?

The address of the `__block` inside the Block differs from the address of the Block by only 1052. We can make a fairly bold guess that `__block` is now on the heap as well.

The reason for this difference is that the Block has been copied to the heap here.

As analyzed in detail in Chapter 2, a Block on the heap retains objects. When we copy the Block to the heap via `copy`, a new copy of the Block is also created on the heap, and that Block continues to retain the `__block`. When the Block is released, the `__block` is no longer referenced by any object, so it is also released and destroyed.

The role of the `__forwarding` pointer here is that, for a heap Block, it changes the original `__forwarding` pointer from pointing to itself to pointing to the copied `__block` itself on `_NSConcreteMallocBlock`. Then the heap variable’s `__forwarding` points to itself. This way, regardless of whether the `__block` is copied to the heap or remains on the stack, the variable value can be accessed via `(i->__forwarding->i)`.

![](https://img.halfrost.com/Blog/ArticleImage/21_6.jpg)

So inside the `__main_block_func_0` function, it is written as `(i->__forwarding->i)`.

There is one more point to note here. Let’s still start with an example:
```objectivec
//The following code runs under MRC
    __block int i = 0;
    NSLog(@"%p",&i);
    
    void (^myBlock)(void) = ^{
        i ++;
        NSLog(@"%p inside Block",&i);
    };
    
    
    NSLog(@"%@",myBlock);
    
    myBlock();

```
The result is completely different from the example copied earlier.
```vim

 0x7fff5fbff818
<__NSStackBlock__: 0x7fff5fbff7c0>**
 0x7fff5fbff818

```
After a Block captures a `__block` variable, it is not copied to the heap, so its address remains on the stack. This differs from behavior under ARC.

~~Under ARC, regardless of whether `copy` is performed, `__block` will be copied to the heap, and the Block is also an `__NSMallocBlock`.~~

Thanks to @酷酷的哀殿 for pointing out the mistake, and thanks to @bestswifter for the guidance. The statement above is somewhat inaccurate; see the update at the end of the article for details.

Under ARC, once a Block is assigned, `copy` is triggered, the `__block` variable is copied to the heap, and the Block is also an `__NSMallocBlock`. There are also cases under ARC where the Block is an `__NSStackBlock`; in that situation, `__block` remains on the stack.

Under MRC, only `copy` causes `__block` to be copied to the heap. Otherwise, `__block` always stays on the stack, and the block is only an `__NSStackBlock`. In this case, the `__forwarding` pointer points only to itself.


![](https://img.halfrost.com/Blog/ArticleImage/21_7.jpg)


At this point, the first question raised at the beginning of the article has also been answered. The implementation principle of `__block` is now clear as well.


##### 2. Object Variables

Let’s start with an example:
```objectivec

//The following code is executed under ARC

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
     
    __block id block_obj = [[NSObject alloc]init];
    id obj = [[NSObject alloc]init];

    NSLog(@"block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    
    void (^myBlock)(void) = ^{
        NSLog(@"***Inside Block****block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    };
    
    myBlock();
   
    return 0;
}

```
Output
```vim

block_obj = [<NSObject: 0x100b027d0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b03b50> , 0x7fff5fbff7b8]
Block****inside********block_obj = [<NSObject: 0x100b027d0> , 0x100f000a8] , obj = [<NSObject: 0x100b03b50> , 0x100f00070]

```
Let's convert the code above into source code and take a look:
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
First, it should be noted that in OC, object declarations include the \_\_strong ownership qualifier by default, so the one we declared at the beginning of `main`
```objectivec

__block id block_obj = [[NSObject alloc]init];
id obj = [[NSObject alloc]init];

```
Equivalent to
```objectivec

__block id __strong block_obj = [[NSObject alloc]init];
id __strong obj = [[NSObject alloc]init];
```
In the generated source code, we can also see that the Block captures `__block` and holds a strong reference to it. This is because in the `__Block_byref_block_obj_0` struct, there is a variable `id block_obj`, which by default also has the `__strong` ownership qualifier.

Based on the printed results, in an ARC environment, when a Block captures an external object variable, it always makes a copy, and the addresses are all different. The only difference is that variables marked with `__block` are captured inside the Block and retained by it.

Now let’s look at the situation in an MRC environment. Again, run the example code above under MRC.

Output:
```objectivec

block_obj = [<NSObject: 0x100b001b0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b001c0> , 0x7fff5fbff7b8]
Block****in********block_obj = [<NSObject: 0x100b001b0> , 0x7fff5fbff7e8] , obj = [<NSObject: 0x100b001c0> , 0x7fff5fbff790]

```
At this point, the block is on the stack, \_\_NSStackBlock\_\_, and you can print out its retainCount value—it is 1. When you copy this block, it becomes \_\_NSMallocBlock\_\_, and the object's retainCount value becomes 2.

Summary:  

In an MRC environment, \_\_block does not perform a copy operation on the object the pointer points to at all; it only copies the pointer itself.
In an ARC environment, for an external object declared as \_\_block, the block will retain it internally, so the external object can be safely referenced within the block's environment. This is why retain cycles can occur!

In an ARC environment, external objects not declared as \_\_block will also be retained.

(Thanks to @南栀倾寒 for the correction. The previous conclusion only discussed external objects declared as \_\_block in an ARC environment, without explaining the case of external objects that are not \_\_block, which could cause ambiguity. So here is a clarification: in an ARC environment, not only external objects declared as \_\_block, but also objects without \_\_block will be retained inside the block. This is because adding \_\_block only affects an automatic variable. These variables are pointers; it is equivalent to extending the lifetime of the pointer variable. As long as the object is accessed, it will still be retained.)

#### Finally

Block capture of external variables has many uses and is widely applicable. Only after clarifying the concepts of captured variables and retained variables can we clearly solve Block retain-cycle issues.

Returning again to the beginning of the article: among the five kinds of variables—automatic variables, function parameters, static variables, static global variables, and global variables—strictly speaking, if capture requires that the Block struct \_\_main\_block\_impl\_0 contain member variables, then the only variables a Block can capture are automatic variables and static variables. Objects captured into a Block will be retained by the Block.

For non-object variables,

the value of an automatic variable is copied into the Block. An automatic variable without \_\_block can only be accessed inside the Block; its value cannot be changed.

![](https://img.halfrost.com/Blog/ArticleImage/21_8.jpg)


Automatic variables with \_\_block and static variables are accessed directly by address. Therefore, their values can be changed directly inside the Block.

![](https://img.halfrost.com/Blog/ArticleImage/21_9.jpg)


The remaining static global variables, global variables, and function parameters can also have their values changed directly inside the Block, but they do not become member variables of the Block struct \_\_main\_block\_impl\_0. Because their scope is large enough, their values can be modified directly.


It is worth noting that static global variables, global variables, and function parameters are not retained by the Block; that is, their retainCount values do not increase.


For objects,

in an MRC environment, \_\_block does not perform a copy operation on the object the pointer points to at all; it only copies the pointer itself.
In an ARC environment, for an external object declared as \_\_block, the block will retain it internally, so the external object can be safely referenced within the block environment. External objects not declared as \_\_block will also be retained in the block.


Feedback and corrections are very welcome.


**Update**


In an ARC environment, a Block can also be a \_\_NSStackBlock\_\_. The reason we usually see \_NSConcreteMallocBlock most often is that we typically assign Blocks. Under ARC, when a block type is passed via =, it triggers the objc\_retainBlock->\_Block\_copy->\_Block\_copy\_internal method chain. This causes a block of type \_\_NSStackBlock\_\_ to be converted into type \_\_NSMallocBlock\_\_.

Example:
```objectivec

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    
    __block int temp = 10;
    
    NSLog(@"%@",^{NSLog(@"*******%d %p",temp ++,&temp);});
   
    return 0;
}
```
Output
```vim
<__NSStackBlock__: 0x7fff5fbff768>
```
In this case, in an ARC environment, the Block is of type \_\_NSStackBlock.