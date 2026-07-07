+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Runtime", "isa", "Class"]
date = 2016-09-10T01:25:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/23_0__.png"
slug = "objc_runtime_isa_class"
tags = ["iOS", "Runtime", "isa", "Class"]
title = "Objective-C Runtime in the Mental Hospital: Day 1 — isa and Class"

+++


#### Preface
I first started taking the Objective-C Runtime seriously on November 1, 2014, after seeing a Weibo post by @Tang Qiao.


![](https://img.halfrost.com/Blog/ArticleImage/23_1_.png)


This was from an offline sharing session by sunnyxx. Four questions were also given at the session.


![](https://img.halfrost.com/Blog/ArticleImage/23_2.png)


Given my knowledge at the time, I was uncertain about many of these four questions and could not answer them confidently. Starting with this “entrance exam,” I was successfully “admitted.” Over the past two years, my understanding of Runtime has gradually deepened, so today I plan to summarize the notes that have long been sitting in my Evernote. Some people may wonder what the point of learning Runtime is, since it does not seem to be used much in day-to-day work. I hope that after reading this summary, some of those doubts will be cleared up.


####Table of Contents
- 1.Introduction to Runtime
- 2.The Origin of NSObject
    - (1)    The concrete implementation of the isa\_t struct
    - (2)    The concrete implementation of cache\_t
    - (3)    The concrete implementation of class\_data\_bits\_t
- 3.Entrance Exam


#### I. Introduction to Runtime

Runtime, also known as the runtime system, is a set of low-level C APIs and one of the cores of the iOS system. During development, a developer can send a message to any object. At compile time, the compiler only determines that this message should be sent to the receiver; how the receiver responds to and handles the message is decided by the runtime.

In C, during compilation, a function call already determines which function will be invoked.
In Objective-C, however, function calls are part of a dynamic dispatch process. The actual function to be called cannot be determined at compile time; only at runtime will the corresponding function be found and invoked based on the function name.

Objective-C is a dynamic language, which means it requires not only a compiler, but also a runtime system to dynamically create classes and objects, and to perform message passing and forwarding.


Objc interacts with the Runtime system at three levels:


![](https://img.halfrost.com/Blog/ArticleImage/23_3.png)

##### 1. Through Objective-C source code

In most cases, developers only need to write OC code. The Runtime system automatically converts the source code we write into runtime code behind the scenes during compilation, and at runtime determines the corresponding data structures and which specific method to call.

##### 2. Through methods defined by the NSObject class in the Foundation framework

In the world of OC, except for the NSProxy class, all classes are subclasses of NSObject. In the Foundation framework, the two base classes, NSObject and NSProxy, define the common interfaces and behavior for all classes below them in the class hierarchy. NSProxy is a class specifically used to implement proxy objects; this article will not discuss it for now. Both of these classes conform to the NSObject protocol. The NSObject protocol declares the common methods of all OC objects.

In the NSObject protocol, the following five methods can obtain information from Runtime and allow objects to inspect themselves.
```objectivec
- (Class)class OBJC_SWIFT_UNAVAILABLE("use 'anObject.dynamicType' instead");
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (BOOL)respondsToSelector:(SEL)aSelector;
```
-class returns the object's class;
-isKindOfClass: and -isMemberOfClass: check whether the object exists within the inheritance hierarchy of the specified class;
-respondsToSelector: checks whether the object can respond to the specified message;
-conformsToProtocol: checks whether the object implements the methods of the specified protocol;

The NSObject class also defines a method
```objectivec

- (IMP)methodForSelector:(SEL)aSelector;

```
This method returns the IMP address of the specified method implementation.

The concrete implementations of all the methods above will be analyzed in detail in this article.

##### 3. Directly calling Runtime library functions
For library functions, you can refer to the detailed Runtime function documentation in the [Objective-C Runtime Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/index.html).

There is actually a small story behind this. After importing the `objc/Runtime.h` and `objc/message.h` header files, once we found the Runtime functions and finished writing the code, we discovered that code completion was gone—the parameters and descriptions for those functions were no longer available. For developers familiar with Runtime, this is not a big problem, because the parameters are already committed to memory. But for beginners, this is quite unfriendly. Also, if you started developing around iOS 6, you may vaguely feel that the official documentation for the concrete implementation details of Runtime has been getting scarcer and scarcer. You might even wonder whether it is just your imagination. In fact, starting with Xcode 5, Apple has discouraged us from manually calling Runtime APIs, and likewise does not want us to know the specific underlying implementation. Therefore, the IDE sets an option by default that disables Runtime code completion, and some explanations have also been removed from the source code and documentation.

The specific setting is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/23_4.png)


If you find that code completion is still unavailable after importing the two library files, you need to change this setting to NO.


#### II. The Origins of NSObject

From the previous section, we know that there are three ways to interact with Runtime, and the first two are both related to NSObject. So let’s start with the NSObject base class.

![](https://img.halfrost.com/Blog/ArticleImage/23_5.png)


All of the following source-code analysis is based on [objc4-680](http://opensource.apple.com//source/objc4/ )

NSObject is defined as follows
```objectivec

typedef struct objc_class *Class;

@interface NSObject <NSObject> {
    Class isa  OBJC_ISA_AVAILABILITY;
}

```
Before ObjC 2.0, the `objc_class` source code was as follows:
```objectivec

struct objc_class {
    Class isa  OBJC_ISA_AVAILABILITY;
    
#if !__OBJC2__
    Class super_class                                        OBJC2_UNAVAILABLE;
    const char *name                                         OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list *ivars                             OBJC2_UNAVAILABLE;
    struct objc_method_list **methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache *cache                                 OBJC2_UNAVAILABLE;
    struct objc_protocol_list *protocols                     OBJC2_UNAVAILABLE;

#endif
    
} OBJC2_UNAVAILABLE;

```
Here you can see that a class contains a pointer to its superclass, the class name, and version information.
`ivars` is a pointer to the `objc_ivar_list` member variable list; `methodLists` is a pointer to a pointer to `objc_method_list`. `*methodLists` is a pointer to the method list. If you dynamically modify the value of `*methodLists` here to add member methods, this is also the principle behind the implementation of Category, and it likewise explains why Category cannot add properties.

Regarding Category, I recommend carefully reading these two articles:  
[Deep Dive into Objective-C: Category](http://tech.meituan.com/DiveIntoCategory.html)  
[Analyzing the Runtime in OC2.0 Based on How Category Works
](https://bestswifter.com/jie-he-category-gong-zuo-yuan-li-fen-xi-oc2-0-zhong-de-runtime/)

Then, after Apple released ObjC 2.0 in 2006, the definition of `objc_class` became the following.
```objectivec

typedef struct objc_class *Class;
typedef struct objc_object *id;

@interface Object { 
    Class isa; 
}

@interface NSObject <NSObject> {
    Class isa  OBJC_ISA_AVAILABILITY;
}

struct objc_object {
private:
    isa_t isa;
}

struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
}

union isa_t 
{
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }
    Class cls;
    uintptr_t bits;
}

```
![](https://img.halfrost.com/Blog/ArticleImage/23_6.png)


Converting the source-code definitions into a class diagram gives you the diagram above.


From the source code above, we can see that **Objective-C objects are all implemented as C structs**. In objc2.0, every object contains a struct of type isa\_t.

objc\_object is typedef’d in the source code as the id type, which is the id type we commonly encounter. This struct contains only one struct of type isa\_t. We will analyze this struct in detail below.

objc\_class inherits from objc\_object. Therefore, objc\_class also contains an isa struct of type isa\_t. At this point, we can conclude that **classes in Objective-C are also objects**. In objc\_class, in addition to isa, there are three member variables: a pointer to the superclass, a method cache, and finally the instance-method list for this class.

The object class and the NSObject class each contain an isa of type objc_class.

That covers the class relationships on the left side of the diagram. Next, let’s start with isa.

When an instance method of an object is called, the corresponding class is found through isa, and then the method is looked up in the class\_data\_bits\_t of that class. class\_data\_bits\_t points to the data area of the class object. The implementation corresponding to the method is looked up in that data area.

But when we call a class method, what is inside the class object’s isa? To keep the method lookup mechanism consistent with object method lookup, the concept of a meta-class was introduced.

For more details about meta-classes, you can study this article: [What is a meta-class in Objective-C?](http://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html)

After introducing meta-classes, the method lookup mechanisms for class objects and objects become completely unified.

When an object’s instance method is called, the method implementation is obtained from the class through the object’s isa.
When a class object’s class method is called, the method implementation is obtained from the meta-class through the class’s isa.

The reason meta-class is important is that it stores all class methods of a class. Each class has its own separate meta-class, because the class methods of different classes are almost never exactly the same.

The correspondence is shown in the diagram below, which clearly describes the relationship among objects, classes, and meta-classes:

![](https://img.halfrost.com/Blog/ArticleImage/23_7.png)


In the diagram, solid lines are super\_class pointers, and dashed lines are isa pointers.

1. Root class (class) is actually NSObject. NSObject has no superclass, so the superclass of Root class(class) points to nil.
2. Every Class has an isa pointer that points to a unique Meta class.
3. The superclass of Root class(meta) points to Root class(class), that is, NSObject, forming a loop.
4. The isa pointer of every Meta class points to Root class (meta).


We should understand that class objects and meta-class objects are unique, while any number of objects can be created at runtime. Before the main method executes, during the period from dyld to runtime, class objects and meta-class objects are created. For details, see sunnyxx’s article [What Happens Before the main Function of an iOS Program](http://blog.sunnyxx.com/2014/08/30/objc-pre-main/).


##### (1) The concrete implementation of the isa\_t struct
Next, we should examine the concrete implementation of isa. The isa inside objc\_object is of type isa\_t. By inspecting the source code, we can see that isa\_t is a union.
```objectivec

struct objc_object {
private:
    isa_t isa;
public:
    // initIsa() should be used to init the isa of new objects only.
    // If this object already has an isa, use changeIsa() for correctness.
    // initInstanceIsa(): objects with no custom RR/AWZ
    void initIsa(Class cls /*indexed=false*/);
    void initInstanceIsa(Class cls, bool hasCxxDtor);
private:
    void initIsa(Class newCls, bool indexed, bool hasCxxDtor);
｝

```
Let's start by examining the initIsa method. The following uses arm64 as an example.
```objectivec

inline void
objc_object::initInstanceIsa(Class cls, bool hasCxxDtor)
{
    initIsa(cls, true, hasCxxDtor);
}

inline void
objc_object::initIsa(Class cls, bool indexed, bool hasCxxDtor)
{
    if (!indexed) {
        isa.cls = cls;
    } else {
        isa.bits = ISA_MAGIC_VALUE;
        isa.has_cxx_dtor = hasCxxDtor;
        isa.shiftcls = (uintptr_t)cls >> 3;
    }
}

```
Since true is passed as the second argument to initIsa, initIsa will execute the statements in the else branch.
```objectivec


# if __arm64__

#   define ISA_MASK        0x0000000ffffffff8ULL

#   define ISA_MAGIC_MASK  0x000003f000000001ULL

#   define ISA_MAGIC_VALUE 0x000001a000000001ULL
    struct {
        uintptr_t indexed           : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 33; // MACH_VM_MAX_ADDRESS 0x1000000000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 19;

#       define RC_ONE   (1ULL<<45)

#       define RC_HALF  (1ULL<<18)
    };

# elif __x86_64__

#   define ISA_MASK        0x00007ffffffffff8ULL

#   define ISA_MAGIC_MASK  0x001f800000000001ULL

#   define ISA_MAGIC_VALUE 0x001d800000000001ULL
    struct {
        uintptr_t indexed           : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 44; // MACH_VM_MAX_ADDRESS 0x7fffffe00000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 8;

#       define RC_ONE   (1ULL<<56)

#       define RC_HALF  (1ULL<<7)
    };


```
![](https://img.halfrost.com/Blog/ArticleImage/23_8.png)


ISA\_MAGIC\_VALUE = 0x000001a000000001ULL converted to binary is 11010000000000000000000000000000000000001. Its structure is shown below:

![](https://img.halfrost.com/Blog/ArticleImage/23_9.png)


Description of the fields:

The first bit, index, indicates whether isa pointer optimization is enabled. index = 1 means isa pointer optimization is enabled.

In September 2013, Apple released the [iPhone5s](http://en.wikipedia.org/wiki/IPhone_5S). At the same time, the iPhone5s was equipped with the first [A7 dual-core processor](http://en.wikipedia.org/wiki/Apple_A7) based on a 64-bit architecture. To save memory and improve execution efficiency, Apple introduced the concept of Tagged Pointer. For 64-bit programs, after introducing Tagged Pointer, the related logic can reduce memory usage by half, improve access speed by 3x, and improve creation and destruction speed by 100x.

In the WWDC 2013 video “Session 404 Advanced in Objective-C”, Apple introduced Tagged Pointer. Tagged Pointer mainly exists to save memory. As we know, the size of an object pointer is generally related to the machine word size. On a 32-bit system, a pointer is 32 bits (4 bytes), while on a 64-bit system, a pointer is 64 bits (8 bytes).

Suppose we want to store an NSNumber object whose value is an integer. Under normal circumstances, if this integer were just an ordinary NSInteger variable, the memory it occupies would depend on the CPU bit width: 4 bytes on a 32-bit CPU and 8 bytes on a 64-bit CPU. The size of a pointer type is usually also related to the CPU bit width: a pointer occupies 4 bytes on a 32-bit CPU and 8 bytes on a 64-bit CPU. Without Tagged Pointer objects, after migrating from a 32-bit machine to a 64-bit machine, although the logic does not change at all, objects such as NSNumber and NSDate would double their memory usage. As shown below:


![](https://img.halfrost.com/Blog/ArticleImage/23_10.png)


Apple introduced Tagged Pointer objects. Because the values of variables such as NSNumber and NSDate often do not need 8 bytes of memory, taking integers as an example, the signed integer range representable by 4 bytes can already exceed 2 billion (note: 2^31=2147483648, with one additional bit used as the sign bit), which is sufficient for the vast majority of cases. Therefore, after introducing Tagged Pointer objects, the memory layout of NSNumber on a 64-bit CPU becomes the following:


![](https://img.halfrost.com/Blog/ArticleImage/23_11.png)


For details about [Tagged Pointer technology](http://www.infoq.com/cn/articles/deep-understanding-of-tagged-pointer/), see the article linked above.


has\_assoc
The object has, or once had, associated references. Objects without associated references can be deallocated faster.

has\_cxx\_dtor
Indicates whether the object has a C++ or ObjC destructor.

shiftcls
The class pointer. On the arm64 architecture, 33 bits are available to store the class pointer.

In the source code, isa.shiftcls = (uintptr_t)cls >> 3;
The main reason for shifting the current address right by three bits is to clear the useless last three bits in the Class pointer and reduce memory consumption. Since class pointers are aligned in memory by bytes (8 bits), the last three bits of the pointer are meaningless 0s. For details, see the shiftcls analysis in [Understanding isa from NSObject Initialization](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E4%BB%8E%20NSObject%20%E7%9A%84%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BA%86%E8%A7%A3%20isa.md#shiftcls).

- magic
Determines whether object initialization is complete. On arm64, 0x16 is used by the debugger to determine whether the current object is a real object or uninitialized memory.

- weakly\_referenced
The object is, or once was, referenced by an ARC weak variable. Objects without weak references can be deallocated faster.

- deallocating
Whether the object is currently being deallocated.

- has\_sidetable\_rc
Determines whether the object's reference count is too large. If it is too large, another hash table is needed for storage.

- extra\_rc
Stores the result of the object's reference count minus one. If the object's reference count exceeds 1, it is stored here. If the reference count is 10, the value of extra\_rc is 9.

ISA\_MAGIC\_MASK and ISA\_MASK obtain the MAGIC value and the isa class pointer, respectively, by applying masks.
```objectivec

inline Class 
objc_object::ISA() 
{
    assert(!isTaggedPointer()); 
    return (Class)(isa.bits & ISA_MASK);
}

```
For details on the x86_64 architecture, see the in-depth analysis in [Understanding isa from NSObject Initialization](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E4%BB%8E%20NSObject%20%E7%9A%84%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BA%86%E8%A7%A3%20isa.md).


##### (2) The concrete implementation of cache\_t
Let’s continue looking at the source code.
```objectivec
struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
}

typedef unsigned int uint32_t;
typedef uint32_t mask_t;  // x86_64 & arm64 asm are less efficient with 16-bits

typedef unsigned long  uintptr_t;
typedef uintptr_t cache_key_t;

struct bucket_t {
private:
    cache_key_t _key;
    IMP _imp;
}
```
![](https://img.halfrost.com/Blog/ArticleImage/23_12.png)


From the source code, we can see that `cache_t` stores a `bucket_t` struct and two `unsigned int` variables.

`mask`: the total number of buckets allocated for the cache.  
`occupied`: indicates the number of cache buckets currently actually occupied.

The `bucket_t` struct stores an `unsigned long` and an `IMP`. `IMP` is a function pointer that points to the concrete implementation of a method.

`bucket_t *_buckets` in `cache_t` is essentially a hash table used to store the linked list of `Method`s.

The primary purpose of `Cache` is to optimize method invocation performance. When an object `receiver` invokes a method `message`, the corresponding class is first found via the object `receiver`’s `isa` pointer. Then the method is searched for in the class’s `methodLists`. If it is not found, the `super_class` pointer is used to search in the parent class’s `methodLists`. Once found, the method is invoked. If it is not found, the message may be forwarded, or it may be ignored. However, this lookup approach is too inefficient, because typically only about 20% of a class’s methods are called frequently, accounting for 80% of total invocations. Therefore, `Cache` is used to cache frequently called methods. When a method is invoked, the lookup first checks `Cache`; if it is not found there, it then searches `methodLists`.

##### (3) Concrete Implementation of `class_data_bits_t`

The source implementation is as follows:
```objectivec


struct class_data_bits_t {

    // Values are the FAST_ flags above.
    uintptr_t bits;
}

struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;
}

struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;

#ifdef __LP64__
    uint32_t reserved;

#endif

    const uint8_t * ivarLayout;
    
    const char * name;
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;

    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};

```
![](https://img.halfrost.com/Blog/ArticleImage/23_13.png)


The comment in the objc\_class struct says that class\_data\_bits\_t is equivalent to a class\_rw\_t pointer plus the rr/alloc flags.
```objectivec

class_data_bits_t bits; // class_rw_t * plus custom rr/alloc flags

```
It provides a convenient method for returning the `class_rw_t *` pointer within it:
```objectivec

class_rw_t *data() {
    return bits.data();
}

```
Since Objective-C 2.0, a class’s properties, methods, and adopted protocols are all stored in class\_rw\_t. class\_ro\_t is a pointer to constant data, storing the properties, methods, and adopted protocols determined by the compiler. rw means readwrite, and ro means readonly.


At compile time, class\_data\_bits\_t \*data in the class structure points to a class\_ro\_t \* pointer:

![](https://img.halfrost.com/Blog/ArticleImage/23_14.png)


At runtime, calling the realizeClass method does the following three things:  
1. Calls the data method from class\_data\_bits\_t, and forcibly casts the result from class\_rw\_t to a class\_ro\_t pointer
2. Initializes a class\_rw\_t struct
3. Sets the struct’s ro value and flag

Finally, it calls the methodizeClass method to load the class’s properties, protocols, and methods.
```objectivec

struct method_t {
    SEL name;
    const char *types;
    IMP imp;

    struct SortBySELAddress :
        public std::binary_function<const method_t&,
                                    const method_t&, bool>
    {
        bool operator() (const method_t& lhs,
                         const method_t& rhs)
        { return lhs.name < rhs.name; }
    };
};
```
The definition of `method` is shown above. It contains three member variables. `SEL` is the method’s name. `types` is the Type Encoding; for the available types, refer to [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html), which will not be covered in detail here.

`IMP` is a function pointer that points to the concrete implementation of the function. In the runtime, the purpose of message dispatch and forwarding is to locate the `IMP` and execute the function.

The entire runtime process can be described as follows:


![](https://img.halfrost.com/Blog/ArticleImage/23_15.png)


For a more detailed analysis, see this article by [@Draveness](https://github.com/Draveness): [In-Depth Analysis of the Structure of Methods in ObjC](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E6%B7%B1%E5%85%A5%E8%A7%A3%E6%9E%90%20ObjC%20%E4%B8%AD%E6%96%B9%E6%B3%95%E7%9A%84%E7%BB%93%E6%9E%84.md#深入解析-objc-中方法的结构)

At this point, let’s summarize the differences between objc\_class 1.0 and 2.0.


![](https://img.halfrost.com/Blog/ArticleImage/23_16.png)


![](https://img.halfrost.com/Blog/ArticleImage/23_17.png)


#### III. Entrance Exam

![](https://img.halfrost.com/Blog/ArticleImage/23_18.png)


#### (1) [self class] and [super class]

>What does the following code output?
```objectivec
    @implementation Son : Father
    - (id)init
    {
        self = [super init];
        if (self)
        {
            NSLog(@"%@", NSStringFromClass([self class]));
            NSLog(@"%@", NSStringFromClass([super class]));
        }
    return self;
    }
    @end
```
Difference between self and super:

self is a hidden parameter of a class; the first parameter of every method implementation is self.

super is not a hidden parameter. It is actually just a “compiler marker” that tells the compiler, when invoking a method, to call the method of the superclass rather than the method in the current class.

When calling [super class], the runtime calls the objc\_msgSendSuper method rather than objc\_msgSend.
```objectivec

OBJC_EXPORT void objc_msgSendSuper(void /* struct objc_super *super, SEL op, ... */ )


/// Specifies the superclass of an instance. 
struct objc_super {
    /// Specifies an instance of a class.
    __unsafe_unretained id receiver;

    /// Specifies the particular superclass of the instance to message. 

#if !defined(__cplusplus)  &&  !__OBJC2__
    /* For compatibility with old objc-runtime.h header */
    __unsafe_unretained Class class;

#else
    __unsafe_unretained Class super_class;

#endif
    /* super_class is the first class to search */
};

```
In the `objc\_msgSendSuper` method, the first parameter is an `objc\_super` struct. This struct contains two variables: `receiver`, which receives the message, and `super\_class`, the superclass of the current class.

This is exactly why the first entrance exam question was answered incorrectly: it mistakenly assumed that `[super class]` calls `[super\_class class]`.

The working principle of `objc\_msgSendSuper` should be as follows:
Starting from the method list of the superclass `superClass` pointed to by the `objc\_super` struct, it searches for the selector. After finding it, it calls that selector of the superclass with `objc->receiver`. Note that the final caller is `objc->receiver`, not `super\_class`!

So in the end, `objc\_msgSendSuper` is transformed into
```objectivec

// Note that msgSend starts from the superclass here, not this class. Thanks to @Josscii and his colleague for pointing out the inaccuracy in this description.
objc_msgSend(objc_super->receiver, @selector(class))

/// Specifies an instance of a class.  This is an instance of a class
    __unsafe_unretained id receiver;   


// Since this is called on an instance, this is an instance method
- (Class)class {
    return object_getClass(self);
}

```
Because the `IMP` of the `class` method in the superclass `NSObject` was found, and because the passed-in argument `objc\_super->receiver = self`, where `self` is `son`, calling `class` means that after the superclass method `class` executes its `IMP`, the output is still `son`. Therefore, the final two outputs are the same: both output `son`.


#### (2) isKindOfClass and isMemberOfClass

> What does the following code output?
```objectivec

     @interface Sark : NSObject
     @end

     @implementation Sark
     @end

  int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];
        BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];
        BOOL res3 = [(id)[Sark class] isKindOfClass:[Sark class]];
        BOOL res4 = [(id)[Sark class] isMemberOfClass:[Sark class]];

        NSLog(@"%d %d %d %d", res1, res2, res3, res4);
    }
    return 0;
  }
```
Let's first analyze the object implementations of these two functions in the source code.
```objectivec


+ (Class)class {
    return self;
}

- (Class)class {
    return object_getClass(self);
}

Class object_getClass(id obj)
{
    if (obj) return obj->getIsa();
    else return Nil;
}

inline Class 
objc_object::getIsa() 
{
    if (isTaggedPointer()) {
        uintptr_t slot = ((uintptr_t)this >> TAG_SLOT_SHIFT) & TAG_SLOT_MASK;
        return objc_tag_classes[slot];
    }
    return ISA();
}

inline Class 
objc_object::ISA() 
{
    assert(!isTaggedPointer()); 
    return (Class)(isa.bits & ISA_MASK);
}

+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [self class] == cls;
}

```
First, in the question, `NSObject` and `Sark` both call the `class` method.

Inside the \+ (BOOL)isKindOfClass:(Class)cls method, it first obtains the class returned by object\_getClass. The source implementation of object\_getClass calls `obj->getIsa()` on the current class, and finally obtains the pointer to the meta class in the ISA() method.

Then, inside isKindOfClass, there is a loop. It first checks whether class is equal to the meta class. If not, it continues the loop and checks whether it is equal to the super class. If still not, it continues to fetch the super class, and so on.

After [NSObject class] finishes executing, it calls isKindOfClass. In the first check, it compares NSObject with NSObject’s meta class. When discussing meta classes earlier, we showed a very detailed diagram, and from that diagram we can also see that NSObject’s meta class is not equal to NSObject itself. Then, in the second loop, it checks whether NSObject is equal to the superclass of the meta class. Again, from that diagram we can see that the superclass of Root class(meta) is Root class(class), which is NSObject itself. Therefore, the second loop matches, so the output of res1 on the first line should be YES.


Similarly, after [Sark class] finishes executing, it calls isKindOfClass. In the first for loop, Sark’s Meta Class is not equal to [Sark class]. In the second for loop, the super class of Sark Meta Class points to NSObject Meta Class, which is not equal to Sark Class. In the third for loop, the super class of NSObject Meta Class points to NSObject Class, which is not equal to Sark Class. In the fourth loop, the super class of NSObject Class points to nil, which is not equal to Sark Class. After the fourth loop, the loop exits, so the output of res3 on the third line is NO.

If the Sark here is changed to one of its instance objects, [sark isKindOfClass:[Sark class], then it should output YES at this point. Because in the isKindOfClass function, it checks whether sark’s isa points to its own class Sark, so the first for loop can output YES.

The source implementation of isMemberOfClass obtains its own isa pointer and compares it with itself to see whether they are equal.
On the second line, isa points to NSObject’s Meta Class, so it is not equal to NSObject Class. On the fourth line, isa points to Sark’s Meta Class, which is also not equal to Sark Class. Therefore, both res2 on the second line and res4 on the fourth line output NO.


#### (3) Class and Memory Addresses

>What will the following code do? Compile Error / Runtime Crash / NSLog…?
```objectivec

    @interface Sark : NSObject
    @property (nonatomic, copy) NSString *name;
    - (void)speak;
    @end
    @implementation Sark
    - (void)speak {                            
       NSLog(@"my name's %@", self.name);
    }
    @end
    @implementation ViewController
    - (void)viewDidLoad {  
       [super viewDidLoad];
       id cls = [Sark class];
       void *obj = &cls;
       [(__bridge id)obj speak];
    }
    @end
```
This question has two tricky points. First: when `obj` calls the `speak` method, will it crash? Second: if the `speak` method does not crash, what should it output?

First, we need to talk about the hidden parameters `self` and \_cmd.
When `[receiver message]` invokes a method, the system secretly and dynamically passes in two hidden parameters at runtime: `self` and \_cmd. They are called hidden parameters because these two parameters are not declared or defined in the source code. `self` has already been explained clearly above, so next let’s talk about \_cmd. \_cmd represents the method currently being invoked; in fact, it is a method selector, `SEL`.

Tricky point one: can the `speak` method be called?
```objectivec

id cls = [Sark class]; 
void *obj = &cls;

```
The answer is yes. `obj` is converted into a pointer to the `Sark` Class, and then cast to the `objc\_object` type using `id`. `obj` is now an instance object of type `Sark`. Of course, you can then call the `speak` method.

The second tricky point: if `speak` can be called, what will it output?

Many people may think it will output information related to `sark`. That answer is incorrect.

The correct answer outputs
```vim

my name is <ViewController: 0x7ff6d9f31c50>

```
The memory address is different on each run, but the part before it is always `ViewController`. Why?

Let’s change the code a bit and print more information.
```objectivec

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"ViewController = %@ , address = %p", self, &self);
    
    id cls = [Sark class];
    NSLog(@"Sark class = %@ address = %p", cls, &cls);
    
    void *obj = &cls;
    NSLog(@"Void *obj = %@ address = %p", obj,&obj);
    
    [(__bridge id)obj speak];
    
    Sark *sark = [[Sark alloc]init];
    NSLog(@"Sark instance = %@ address = %p",sark,&sark);
    
    [sark speak];
    
}

```
Let's print out the pointer addresses of the objects. Output:
```vim

ViewController = <ViewController: 0x7fb570e2ad00> , address = 0x7fff543f5aa8
Sark class = Sark address = 0x7fff543f5a88
Void *obj = <Sark: 0x7fff543f5a88> address = 0x7fff543f5a80

my name is <ViewController: 0x7fb570e2ad00>

Sark instance = <Sark: 0x7fb570d20b10> address = 0x7fff543f5a78
my name is (null)

```


![](https://img.halfrost.com/Blog/ArticleImage/23_19_.png)

```objectivec

// objc_msgSendSuper2() takes the current search class, not its superclass.
OBJC_EXPORT id objc_msgSendSuper2(struct objc_super *super, SEL op, ...)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);


```
The objc\_msgSendSuper2 method takes an objc\_super *super parameter.
```objectivec

/// Specifies the superclass of an instance. 
struct objc_super {
    /// Specifies an instance of a class.
    __unsafe_unretained id receiver;

    /// Specifies the particular superclass of the instance to message. 

#if !defined(__cplusplus)  &&  !__OBJC2__
    /* For compatibility with old objc-runtime.h header */
    __unsafe_unretained Class class;

#else
    __unsafe_unretained Class super_class;

#endif
    /* super_class is the first class to search */
};

#endif


```
So when viewDidLoad executes, the order in which the variables are pushed onto the stack, from high to low, is self, \_cmd, super\_class (equivalent to self.class), receiver (equivalent to self), obj.

![](https://img.halfrost.com/Blog/ArticleImage/23_20.png)


The first self and the second \_cmd are hidden parameters. The third self.class and the fourth self are the parameters used when the [super viewDidLoad] method executes.

When calling self.name, it is essentially the self pointer being offset in memory toward higher addresses by one pointer.

![](https://img.halfrost.com/Blog/ArticleImage/23_21.png)

From the printed result, we can see that obj is exactly the address of cls. Offsetting obj upward by one pointer brings us to 0x7fff543f5a90, which happens to be the address of ViewController.

So the output is my name is &lt;ViewController: 0x7fb570e2ad00&gt;.

At this point, what exactly is an object in Objc?

In essence: **An object in Objc is a variable that points to the address of a ClassObject, i.e. id obj = &ClassObject, and an object's instance variable is void \*ivar = &obj + offset(N)**

To deepen your understanding of the statement above, what will the following code output?
```objectivec

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"ViewController = %@ , address = %p", self, &self);
    
    NSString *myName = @"halfrost";
    
    id cls = [Sark class];
    NSLog(@"Sark class = %@ address = %p", cls, &cls);
    
    void *obj = &cls;
    NSLog(@"Void *obj = %@ address = %p", obj,&obj);
    
    [(__bridge id)obj speak];
    
    Sark *sark = [[Sark alloc]init];
    NSLog(@"Sark instance = %@ address = %p",sark,&sark);
    
    [sark speak];
    
}

```
```vim

ViewController = <ViewController: 0x7fff44404ab0> ,  address  = 0x7fff56a48a78
Sark class = Sark  address  = 0x7fff56a48a50
Void *obj = <Sark: 0x7fff56a48a50>  address = 0x7fff56a48a48

my name is halfrost

Sark instance = <Sark: 0x6080000233e0>  address = 0x7fff56a48a40
my name is (null)

```
Because a string was added, the output changes completely. `[(\_\_bridge id)obj speak];` will output “my name is halfrost”.

The reason is similar to the one above. When `viewDidLoad` executes, the order in which the variables are pushed onto the stack, from high addresses to low addresses, is `self`, `\_cmd`, `self.class( super\_class )`, `self ( receiver )`, `myName`, and `obj`. Moving `obj` upward by one pointer lands on the `myName` string, so the output becomes `myName`.

![](https://img.halfrost.com/Blog/ArticleImage/23_22.png)


One additional point to clarify here is that there are two `self` values on the stack. Some people may think the pointer offset reaches the first `self`, thus printing `ViewController`:
```objectivec


my name is <ViewController: 0x7fb570e2ad00>

```
![](https://img.halfrost.com/Blog/ArticleImage/23_23.png)

In fact, this way of thinking is incorrect. Looking upward from `obj` for the `name` property is entirely caused by the pointer being offset by one `offset`; in other words, the pointer only moves downward by one position. So how can we prove that the pointer is only offset by one position, rather than by four positions all the way down to the bottom `self`?

![](https://img.halfrost.com/Blog/ArticleImage/23_24.png)

The address of `obj` is `0x7fff5c7b9a08`, and the address of `self` is `0x7fff5c7b9a28`. Each pointer occupies 8 bytes, so there are indeed four pointer-sized intervals between `obj` and `self`. If we offset `obj` by one pointer, we arrive at `0x7fff5c7b9a10`. We need to print the contents at this memory address.

> In LLDB debugging, you can use the `examine` command (abbreviated as `x`) to inspect the value at a memory address. The syntax of the `x` command is as follows:
x/

>`n`, `f`, and `u` are optional parameters.
`n` is a positive integer indicating the length of memory to display; that is, how many addresses’ contents to display starting from the current address.

>`f` indicates the display format, as mentioned above. If the address points to a string, the format can be `s`; if the address is an instruction address, the format can be `i`.

>`u` indicates the number of bytes requested starting from the current address. If not specified, GDB defaults to 4 bytes. The `u` parameter can be replaced by the following characters: `b` for a single byte, `h` for two bytes, `w` for four bytes, and `g` for eight bytes. After we specify the byte length, GDB starts from the specified memory address, reads the specified number of bytes, and treats them as a single value.

![](https://img.halfrost.com/Blog/ArticleImage/23_25.png)

We use the `x` command to print the contents at the memory addresses `0x7fff5c7b9a10` and `0x7fff5c7b9a28`, respectively. We can see that the two printed values are the same: both are `0x7fbf0d606aa0`.

The addresses of these two `self` values are different, but the contents stored inside them are the same.

Therefore, `obj` is offset by one pointer, rather than being offset all the way down to the bottom `self`.


#### Finally

Because there was still one question on the admission exam that I couldn’t answer, the hospital decided to keep me for one day of observation.

To be continued. I welcome your comments and corrections.


Recommended reading:  
[Getting to the Bottom of Objective-C Runtime (1) — Self & Super](http://chun.tips/2014/11/05/objc-runtime-1/)