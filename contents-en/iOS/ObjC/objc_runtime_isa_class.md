# Psych Ward Objective-C Runtime: Day One of Admission — isa and Class

![](https://img.halfrost.com/Blog/ArticleTitleImage/23_0__.png)


#### Preface
I first started taking the Objective-C Runtime seriously because of a Weibo post by @唐巧 on November 1, 2014.


![](https://img.halfrost.com/Blog/ArticleImage/23_1_.png)


This was from an offline sharing session by sunnyxx. Four questions were also given at the session.


![](https://img.halfrost.com/Blog/ArticleImage/23_2.png)


Given what I knew at the time, I was unsure about many of these four questions and could not answer them with confidence. Starting with this admission exam, I was successfully admitted to the ward. Over the past two years, my understanding of Runtime has gradually improved, so today I plan to summarize the notes that have long been lying in my Evernote. Some people may wonder what the point of learning Runtime is, since it does not seem to be used much in day-to-day development. I hope that after reading this summary, some of those doubts will be cleared up.


####Table of Contents
- 1.Introduction to Runtime
- 2.The Origin of NSObject
    - (1)    The concrete implementation of the isa\_t struct
    - (2)    The concrete implementation of cache\_t
    - (3)    The concrete implementation of class\_data\_bits\_t
- 3.Admission Exam


#### I. Introduction to Runtime

Runtime, also known as the run-time system, is a set of low-level C APIs and one of the core components of iOS. During development, a developer can send a message to any object. At compile time, the compiler merely determines that this message should be sent to the receiver; how the receiver responds to and handles the message is decided at runtime.

In C, which function is called is determined at compile time.
Objective-C method calls, however, are dynamic dispatch. The actual function to invoke cannot be determined at compile time; only when the program is actually running will the corresponding function be found and called based on the method name.

Objective-C is a dynamic language, which means it needs not only a compiler, but also a runtime system to dynamically create classes and objects, perform message dispatch, and handle message forwarding.


Objc interacts with the Runtime system at three levels:


![](https://img.halfrost.com/Blog/ArticleImage/23_3.png)

##### 1. Through Objective-C source code

In general, developers only need to write OC code. The Runtime system automatically works behind the scenes, converting the source code we write into runtime code during compilation, and determining the corresponding data structures and the specific method to call at runtime.

##### 2. Through methods defined by the NSObject class in the Foundation framework

In the world of OC, except for the NSProxy class, all classes are subclasses of NSObject. In the Foundation framework, the two base classes NSObject and NSProxy define the common interface and behavior for all classes beneath them in the class hierarchy. NSProxy is a class specifically used to implement proxy objects, and this article will not cover it for now. Both of these classes conform to the NSObject protocol. The NSObject protocol declares the common methods shared by all OC objects.

In the NSObject protocol, the following five methods can obtain information from the Runtime and allow an object to introspect itself.
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

A method is also defined in the NSObject class.
```objectivec

- (IMP)methodForSelector:(SEL)aSelector;

```
This method returns the IMP address of the specified method implementation.

The specific implementations of all the methods above will be analyzed in detail in this article.

##### 3. Through Direct Calls to Runtime Library Functions
For library functions, you can refer to the detailed Runtime function documentation in the [Objective-C Runtime Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/index.html).

There is actually a small side note here. After we import the two header files objc/Runtime.h and objc/message.h, find the Runtime functions, and finish writing the code, we may notice that code completion is gone: the parameters and descriptions for those functions are no longer shown. For developers familiar with Runtime, this is not difficult, because the parameters are already committed to memory. But for beginners, this is quite unfriendly. Also, if you started developing around iOS 6, you may vaguely feel that the official documentation about the concrete implementation of Runtime has become increasingly sparse. You might even wonder whether it is just an illusion. In fact, starting with Xcode 5, Apple has not recommended that we manually call Runtime APIs, and likewise does not want us to know the concrete low-level implementation. So the IDE has a default setting that disables Runtime code completion, and some explanations have also been removed from the source code and documentation.

The specific setting is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/23_4.png)


If you find that there is still no code completion after importing the two library files, change the setting here to NO.


#### II. The Origin of NSObject

From the previous section, we know that there are three ways to interact with Runtime. The first two are both related to NSObject, so let’s start with the NSObject base class.

![](https://img.halfrost.com/Blog/ArticleImage/23_5.png)


All source code analysis below comes from [objc4-680](http://opensource.apple.com//source/objc4/ )

NSObject is defined as follows
```objectivec

typedef struct objc_class *Class;

@interface NSObject <NSObject> {
    Class isa  OBJC_ISA_AVAILABILITY;
}

```
Before Objc 2.0, the source code of objc\_class was as follows:
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
`ivars` is a pointer to the `objc\_ivar\_list` member-variable list; `methodLists` is a pointer to a pointer to `objc\_method\_list`. `\*methodLists` is a pointer to the method list. If you dynamically modify the value of `\*methodLists` here to add instance methods, that is also the principle behind how Category is implemented, and it likewise explains why Category cannot add properties.

For Category, I recommend carefully reading the following two articles.  
[Understanding Objective-C in Depth: Category](http://tech.meituan.com/DiveIntoCategory.html)  
[Analyzing the Runtime in OC 2.0 Based on How Category Works
](https://bestswifter.com/jie-he-category-gong-zuo-yuan-li-fen-xi-oc2-0-zhong-de-runtime/)

Then, after Apple released ObjC 2.0 in 2006, the definition of `objc\_class` became the following.
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


Converting the source-code definitions into a class diagram gives the diagram shown above.


From the source code above, we can see that **Objective-C objects are implemented as C structs**. In objc2.0, every object contains a struct of type isa\_t.

objc\_object is typedef’d as the id type in the source code, which is the id type we commonly encounter. This struct contains only one struct of type isa\_t. We will analyze this struct in detail below.

objc\_class inherits from objc\_object. Therefore, objc\_class also contains a struct named isa of type isa\_t. At this point, we can conclude that **classes in Objective-C are also objects**. In objc\_class, besides isa, there are three member variables: a pointer to the superclass, a method cache, and finally the linked list of instance methods for this class.

The object class and the NSObject class each contain an isa of type objc_class.

That covers the class relationships on the left side of the diagram. Next, let’s start with isa.

When an instance method of an object is called, the corresponding class is found through isa, and then the method is looked up in that class’s class\_data\_bits\_t. class\_data\_bits\_t points to the data region of the class object. The corresponding implementation of the method is looked up in that data region.

But when we call a class method, what is inside the isa of the class object? To make the method lookup mechanism consistent with that of objects, the concept of a meta-class was introduced.

For more details about meta-classes, you can read this article: [What is a meta-class in Objective-C?](http://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html)

After introducing meta-classes, the method lookup mechanisms for class objects and ordinary objects become completely unified.

When an object’s instance method is called, the method implementation is obtained from the class through the object’s isa.
When a class object’s class method is called, the method implementation is obtained from the meta-class through the class’s isa.

The reason meta-class is important is that it stores all class methods of a class. Each class has its own distinct meta-class, because the class methods of different classes are almost never exactly the same.

The corresponding relationship is shown in the diagram below, which clearly illustrates the relationships among objects, classes, and meta-classes:

![](https://img.halfrost.com/Blog/ArticleImage/23_7.png)


In the diagram, solid lines are super\_class pointers, and dashed lines are isa pointers.

1. Root class (class) is essentially NSObject. NSObject has no superclass, so the superclass of Root class(class) points to nil.
2. Every Class has an isa pointer pointing to its unique Meta class.
3. The superclass of Root class(meta) points to Root class(class), namely NSObject, forming a loop.
4. The isa pointer of every Meta class points to Root class (meta).


What we should understand is that class objects and meta-class objects are unique, whereas objects can be created in unlimited numbers at runtime. Before the main function executes, during the period from dyld to runtime, class objects and meta-class objects are created. For details, see sunnyxx’s article [What Happens Before the main Function of an iOS Program](http://blog.sunnyxx.com/2014/08/30/objc-pre-main/)


##### (1) Specific implementation of the isa\_t struct
Next, it is time to take a closer look at the concrete implementation of isa. The isa inside objc\_object is of type isa\_t. By looking at the source code, we can see that isa\_t is a union.
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
Since `true` is passed as the second argument to `initIsa`, `initIsa` will execute the statements in the `else` branch.
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


Parameter descriptions:

The first bit, index, indicates whether isa pointer optimization is enabled. index = 1 means isa pointer optimization is enabled.

In September 2013, Apple released the [iPhone5s](http://en.wikipedia.org/wiki/IPhone_5S). At the same time, the iPhone5s was equipped with the first [A7 dual-core processor](http://en.wikipedia.org/wiki/Apple_A7) to use a 64-bit architecture. To save memory and improve execution efficiency, Apple introduced the concept of Tagged Pointer. For 64-bit programs, after introducing Tagged Pointer, the relevant logic can reduce memory usage by half, improve access speed by 3x, and improve creation and destruction speed by 100x.

In the WWDC 2013 video “Session 404 Advanced in Objective-C”, Apple introduced Tagged Pointer. Tagged Pointer exists primarily to save memory. As we know, the size of an object pointer is generally related to the machine word size. On a 32-bit system, a pointer is 32 bits (4 bytes), while on a 64-bit system, a pointer is 64 bits (8 bytes).

Suppose we want to store an NSNumber object whose value is an integer. Normally, if this integer were just an ordinary NSInteger variable, the memory it occupies would depend on the CPU bit width: 4 bytes on a 32-bit CPU and 8 bytes on a 64-bit CPU. The size of a pointer type is usually also related to the CPU bit width: a pointer occupies 4 bytes on a 32-bit CPU and 8 bytes on a 64-bit CPU. Without Tagged Pointer objects, after migrating from a 32-bit machine to a 64-bit machine, even though the logic does not change at all, the memory occupied by objects such as NSNumber and NSDate would double. As shown below:


![](https://img.halfrost.com/Blog/ArticleImage/23_10.png)


Apple introduced Tagged Pointer objects. Since the values of variables such as NSNumber and NSDate often do not themselves require 8 bytes of memory, take integers for example: the signed integers representable in 4 bytes can already reach more than 2 billion (note: 2^31=2147483648, with the remaining 1 bit used as the sign bit), which is sufficient for the vast majority of cases. Therefore, after introducing Tagged Pointer objects, the memory layout of NSNumber on a 64-bit CPU becomes the following:


![](https://img.halfrost.com/Blog/ArticleImage/23_11.png)


For details on [Tagged Pointer technology](http://www.infoq.com/cn/articles/deep-understanding-of-tagged-pointer/), you can read the article linked above.


has\_assoc
The object has, or once had, associated references. Objects without associated references can be deallocated faster.

has\_cxx\_dtor
Indicates whether the object has a C++ or Objc destructor.

shiftcls
The class pointer. In the arm64 architecture, 33 bits are available to store the class pointer.

In the source code, isa.shiftcls = (uintptr_t)cls >> 3;
The main reason for shifting the current address right by three bits is to clear the unused last three bits of the Class pointer and reduce memory consumption, because class pointers must be byte-aligned (8 bits) in memory, and the last three bits of the pointer are meaningless 0s. For details, see the shiftcls analysis in [Understanding isa from NSObject initialization](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E4%BB%8E%20NSObject%20%E7%9A%84%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BA%86%E8%A7%A3%20isa.md#shiftcls).

- magic
Determines whether object initialization has completed. On arm64, 0x16 is used by the debugger to determine whether the current object is a real object or uninitialized memory.

- weakly\_referenced
The object is, or once was, referenced by an ARC weak variable. Objects without weak references can be released faster.

- deallocating
Whether the object is currently being deallocated.

- has\_sidetable\_rc
Determines whether the object’s reference count is too large. If it is too large, another hash table is needed for storage.

- extra\_rc
Stores the result of the object’s reference count minus one. If the object’s reference count is greater than 1, it will be stored here. If the reference count is 10, the value of extra\_rc is 9.

ISA\_MAGIC\_MASK and ISA\_MASK obtain the MAGIC value and the isa class pointer, respectively, by means of masks.
```objectivec

inline Class 
objc_object::ISA() 
{
    assert(!isTaggedPointer()); 
    return (Class)(isa.bits & ISA_MASK);
}

```
For the x86_64 architecture, see the detailed analysis in the article [Understanding `isa` from `NSObject` Initialization](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E4%BB%8E%20NSObject%20%E7%9A%84%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BA%86%E8%A7%A3%20isa.md).


##### (2) Concrete implementation of cache\_t
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


Based on the source code, we can see that `cache_t` stores a `bucket_t` struct and two `unsigned int` variables.

`mask`: the total number of buckets allocated for caching.  
`occupied`: the number of cache buckets that are actually occupied at the moment.

The `bucket_t` struct stores an `unsigned long` and an `IMP`. `IMP` is a function pointer that points to the concrete implementation of a method.

The `bucket_t *_buckets` in `cache_t` is essentially a hash table used to store the linked list of `Method`s.

The purpose of `Cache` is mainly to optimize the performance of method calls. When an object `receiver` calls a method `message`, the runtime first uses the object `receiver`’s `isa` pointer to find its corresponding class, and then searches for the method in the class’s `methodLists`. If it is not found, it uses the `super_class` pointer to look in the parent class’s `methodLists`; once found, it invokes the method. If it is still not found, the message may be forwarded, or it may be ignored. But this lookup approach is too inefficient, because typically only about 20% of a class’s methods are called frequently, accounting for 80% of total calls. Therefore, `Cache` is used to cache frequently invoked methods. When a method is called, the runtime first looks it up in `Cache`; if it is not found there, it then searches `methodLists`.

##### (3) Concrete implementation of `class_data_bits_t`

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
It provides us with a convenient method for returning the class\_rw\_t * pointer it contains:
```objectivec

class_rw_t *data() {
    return bits.data();
}

```
In ObjC, a class’s properties, methods, and adopted protocols have all been placed in class\_rw\_t since ObjC 2.0. class\_ro\_t is a pointer to constants, storing the properties, methods, and adopted protocols determined by the compiler. rw means read-write, and ro means read-only.


At compile time, the class\_data\_bits\_t \*data in the class structure points to a class\_ro\_t \* pointer:

![](https://img.halfrost.com/Blog/ArticleImage/23_14.png)


At runtime, calling the realizeClass method does the following three things:  
1. Calls the data method on class\_data\_bits\_t, and forcibly casts the result from class\_rw\_t to a class\_ro\_t pointer
2. Initializes a class\_rw\_t struct
3. Sets the values of the struct’s ro and flag

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
The definition of the method `method` is shown above. It contains three member variables. `SEL` is the method’s name. `types` is the Type Encoding; for the available types, see [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html), so I won’t go into detail here.

`IMP` is a function pointer that points to the concrete implementation of the function. In the runtime, the purpose of message passing and forwarding is to find the `IMP` and execute the function.

The entire runtime process can be described as follows:


![](https://img.halfrost.com/Blog/ArticleImage/23_15.png)


For a more detailed analysis, see this article by [@Draveness](https://github.com/Draveness), [A Deep Dive into the Structure of Methods in ObjC](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/objc/%E6%B7%B1%E5%85%A5%E8%A7%A3%E6%9E%90%20ObjC%20%E4%B8%AD%E6%96%B9%E6%B3%95%E7%9A%84%E7%BB%93%E6%9E%84.md#深入解析-objc-中方法的结构)

At this point, let’s summarize the differences between objc\_class 1.0 and 2.0.


![](https://img.halfrost.com/Blog/ArticleImage/23_16.png)


![](https://img.halfrost.com/Blog/ArticleImage/23_17.png)


#### 3. Entrance Exam

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
The difference between self and super:

self is a hidden parameter of a class; the first parameter of every method implementation is self.

super is not a hidden parameter. It is actually just a “compiler marker” that tells the compiler to call the superclass’s method, rather than the method in the current class, when invoking a method.

When calling [super class], the runtime calls objc\_msgSendSuper instead of objc\_msgSend.
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
In the `objc_msgSendSuper` method, the first parameter is an `objc_super` struct. This struct contains two variables: the `receiver` that receives the message, and the `super_class`, which is the superclass of the current class.

This is exactly why the first question in the entrance exam was answered incorrectly: it mistakenly assumed that `[super class]` calls `[super_class class]`.

The way `objc_msgSendSuper` works should be as follows:

It starts looking for the selector in the method list of the superclass pointed to by the `superClass` field in the `objc_super` struct. Once found, it invokes that selector on `objc->receiver`. Note that the final caller is `objc->receiver`, not `super_class`!

So `objc_msgSendSuper` ultimately becomes
```objectivec

// Note that msgSend starts from the superclass here, not from this class; thanks to @Josscii and his colleague for pointing out the inaccuracy in this description.
objc_msgSend(objc_super->receiver, @selector(class))

/// Specifies an instance of a class.  This is an instance of the class
    __unsafe_unretained id receiver;   


// Since it's called on an instance, this is a '-' method
- (Class)class {
    return object_getClass(self);
}

```
Because the IMP of the `class` method in the superclass `NSObject` is found, and because the passed-in argument is `objc_super->receiver = self`. `self` is `son`; when `class` is called, after the superclass method `class` executes the IMP, the output is still `son`. Therefore, the final two outputs are the same: both output `son`.


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
Let's start by analyzing the object implementations of these two functions in the source code.
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
First, in the question, both NSObject and Sark call the class method.

Inside the \+ (BOOL)isKindOfClass:(Class)cls method, it first obtains the class from object\_getClass. The source implementation of object\_getClass calls obj->getIsa() on the current class, and finally obtains the pointer to the meta class in the ISA() method.

Then, in isKindOfClass, there is a loop. It first checks whether class is equal to the meta class. If not, it continues looping to check whether it is equal to the super class. If still not, it continues to get the super class, and the loop proceeds this way.

After [NSObject class] executes, it calls isKindOfClass. The first check compares NSObject with NSObject’s meta class. When we discussed meta class earlier, we included a very detailed diagram, and from that diagram we can also see that NSObject’s meta class is not equal to NSObject itself. Then, in the second loop, it checks whether NSObject is equal to the superclass of the meta class. Again, from that diagram we can see that the superclass of Root class(meta) is Root class(class), which is NSObject itself. Therefore, the second loop matches, so the output of res1 on the first line should be YES.


Similarly, after [Sark class] executes, it calls isKindOfClass. In the first for loop, Sark’s Meta Class is not equal to [Sark class]. In the second for loop, the super class of Sark Meta Class points to NSObject Meta Class, which is not equal to Sark Class. In the third for loop, the super class of NSObject Meta Class points to NSObject Class, which is not equal to Sark Class. In the fourth loop, the super class of NSObject Class points to nil, which is not equal to Sark Class. After the fourth loop, the loop exits, so res3 on the third line outputs NO.

If Sark here is replaced with its instance object, [sark isKindOfClass:[Sark class], then the output should be YES. This is because in the isKindOfClass function, it checks whether sark’s isa points to its own class Sark, so the first for loop can output YES.

The source implementation of isMemberOfClass gets its own isa pointer and compares it with itself to see whether they are equal.
On the second line, isa points to NSObject’s Meta Class, so it is not equal to NSObject Class. On the fourth line, isa points to Sark’s Meta Class, which is also not equal to Sark Class, so both res2 on the second line and res4 on the fourth line output NO.


#### (3) Class and Memory Addresses

>The following code will do what? Compile Error / Runtime Crash / NSLog…?
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
When `[receiver message]` invokes a method, the system secretly and dynamically passes in two hidden parameters at runtime: `self` and \_cmd. They are called hidden parameters because these two parameters are not declared or defined in the source code. `self` has already been explained above, so next let’s talk about \_cmd. \_cmd represents the currently invoked method; in fact, it is a method selector `SEL`.

Tricky point one: can the `speak` method be called?
```objectivec

id cls = [Sark class]; 
void *obj = &cls;

```
The answer is yes. `obj` is converted into a pointer to the `Sark` class, and then cast to the `objc_object` type using `id`. `obj` is now already an instance object of type `Sark`. Of course, the `speak` method can then be called.

The second tricky point: if `speak` can be called, what will it output?

Many people might think it will output information related to `sark`. That answer would be wrong.

The correct answer will output
```vim

my name is <ViewController: 0x7ff6d9f31c50>

```
The memory address is different on each run, but it is always preceded by `ViewController`. Why?

Let's change the code a bit and print more information.
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
We print out the pointer addresses of the objects. Output:
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
So, when `viewDidLoad` is executed, the order in which the variables are pushed onto the stack, from high addresses to low addresses, is `self`, `_cmd`, `super_class` (equivalent to `self.class`), `receiver` (equivalent to `self`), and `obj`.

![](https://img.halfrost.com/Blog/ArticleImage/23_20.png)


The first `self` and the second `_cmd` are hidden parameters. The third `self.class` and the fourth `self` are the parameters used when the `[super viewDidLoad]` method is executed.

When calling `self.name`, what essentially happens is that the `self` pointer is offset in memory by one pointer toward a higher address.

![](https://img.halfrost.com/Blog/ArticleImage/23_21.png)

From the printed result, we can see that `obj` is exactly the address of `cls`. Offsetting `obj` upward by one pointer takes us to `0x7fff543f5a90`, which is exactly the address of `ViewController`.

So the output is `my name is &lt;ViewController: 0x7fb570e2ad00&gt;`.

At this point, what exactly is an object in Objc?

Essence: **An object in Objc is a variable that points to the address of a ClassObject, namely id obj = &ClassObject, while an object's instance variable is void \*ivar = &obj + offset(N)**

To deepen the understanding of the statement above, what will the following code output?
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
Because a string was added, the output changed completely. `[(\_\_bridge id)obj speak];` now outputs “my name is halfrost”.

The reason is similar to the one above. When `viewDidLoad` is executed, the variables are pushed onto the stack in the following order from high to low: `self`, `_cmd`, `self.class` (`super_class`), `self` (`receiver`), `myName`, and `obj`. If `obj` is offset upward by one pointer, it points to the `myName` string, so the output becomes `myName`.

![](https://img.halfrost.com/Blog/ArticleImage/23_22.png)


One additional point worth mentioning here is that there are two `self`s on the stack. Some people may think the pointer was offset to the first `self`, and therefore printed `ViewController`:
```objectivec


my name is <ViewController: 0x7fb570e2ad00>

```
![](https://img.halfrost.com/Blog/ArticleImage/23_23.png)

In fact, this line of thinking is incorrect. The reason walking upward from obj finds the name property is entirely that the pointer has been offset by one slot; in other words, the pointer has only shifted downward by one. So how can we prove that the pointer has only shifted by one slot, rather than by four slots all the way down to the bottom self?

![](https://img.halfrost.com/Blog/ArticleImage/23_24.png)

The address of obj is 0x7fff5c7b9a08, and the address of self is 0x7fff5c7b9a28. Each pointer occupies 8 bytes, so there are indeed four pointer-sized intervals between obj and self. If we offset obj by one pointer, we arrive at 0x7fff5c7b9a10. We need to print the contents at this memory address.

> In LLDB debugging, you can use the examine command (abbreviated as x) to inspect the value at a memory address. The syntax of the x command is shown below:
x/

>n, f, and u are optional parameters.
n is a positive integer indicating the length of memory to display; that is, how many addresses’ contents to display starting from the current address.

>f indicates the display format, as described above. If the address points to a string, the format can be s; if the address is an instruction address, the format can be i.

>u indicates the number of bytes requested starting from the current address. If not specified, GDB defaults to 4 bytes. The u parameter can be replaced by the following characters: b for one byte, h for two bytes, w for four bytes, and g for eight bytes. After we specify the byte length, GDB starts from the specified memory address, reads the specified number of bytes, and treats them as a single value.

![](https://img.halfrost.com/Blog/ArticleImage/23_25.png)

We use the x command to print the contents at memory addresses 0x7fff5c7b9a10 and 0x7fff5c7b9a28 respectively. We can see that the two printed values are the same: both are 0x7fbf0d606aa0.

The addresses of these two self variables are different, but the contents stored inside them are the same.

Therefore, obj has been offset by one pointer, not offset all the way down to the bottom self.


#### Finally

Since there was still one question in the admission exam that I failed to answer, the hospital decided to keep me for one day of observation.

To be continued. Feedback is welcome.


Recommended reading:  
[Digging into Objective-C Runtime (1) - Self & Super](http://chun.tips/2014/11/05/objc-runtime-1/)