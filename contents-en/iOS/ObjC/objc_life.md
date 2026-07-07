# The Life and Times of Objc Objects

![](https://img.halfrost.com/Blog/ArticleTitleImage/30_0_.png)


#### Preface

In object-oriented programming, we create objects every day and use them to describe the entire world. But how does an object go from being created to being destroyed?


#### Table of Contents
- 1. Conceiving an Object
- 2. The Birth of an Object
- 3. The Growth of an Object
- 4. The Destruction of an Object
- 5. Summary


##### 1. Conceiving an Object


![](https://img.halfrost.com/Blog/ArticleImage/30_1.png)


In day-to-day development, we `alloc` objects all the time. So what exactly does the `alloc` method do?
```objectivec

+ (id)alloc {
    return _objc_rootAlloc(self);
}

```
All object alloc operations call this root method.
```objectivec

id _objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}

```
This method will then call the `callAlloc` method.
```objectivec

static ALWAYS_INLINE id callAlloc(Class cls, bool checkNil, bool allocWithZone=false)
{
    if (checkNil && !cls) return nil;

#if __OBJC2__
    if (! cls->ISA()->hasCustomAWZ()) {
        // No alloc/allocWithZone implementation. Go straight to the allocator.
        // fixme store hasCustomAWZ in the non-meta class and 
        // add it to canAllocFast's summary
        if (cls->canAllocFast()) {
            // No ctors, raw isa, etc. Go straight to the metal.
            bool dtor = cls->hasCxxDtor();
            id obj = (id)calloc(1, cls->bits.fastInstanceSize());
            if (!obj) return callBadAllocHandler(cls);
            obj->initInstanceIsa(cls, dtor);
            return obj;
        }
        else {
            // Has ctor or raw isa or something. Use the slower path.
            id obj = class_createInstance(cls, 0);
            if (!obj) return callBadAllocHandler(cls);
            return obj;
        }
    }

#endif

    // No shortcuts available.
    if (allocWithZone) return [cls allocWithZone:nil];
    return [cls alloc];
}

```
Since the input parameter checkNil = false, nil will not be returned.
```objectivec

    bool hasCustomAWZ() {
        return ! bits.hasDefaultAWZ();
    }

```
![](https://img.halfrost.com/Blog/ArticleImage/30_2.png)


In [this figure](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/images/objc-method-after-realize-class.png), we can see that in the object's data segment, data, class\_rw\_t contains a flags field.
```objectivec

    bool hasDefaultAWZ( ) {
        return data()->flags & RW_HAS_DEFAULT_AWZ;
    }

#define RW_HAS_DEFAULT_AWZ    (1<<16)

```
RW\_HAS\_DEFAULT\_AWZ is used to indicate whether the current class or superclass has the default alloc/allocWithZone:. It is worth noting that this value is stored in the metaclass.


The hasDefaultAWZ( ) method is used to determine whether the current class has the default allocWithZone.


If cls\->ISA()\->hasCustomAWZ() returns YES, it means there is a default allocWithZone method, so allocWithZone is invoked directly on the class to allocate memory.
```objectivec

    if (allocWithZone) return [cls allocWithZone:nil];

```
allocWithZone will call rootAllocWithZone
```objectivec

+ (id)allocWithZone:(struct _NSZone *)zone {
    return _objc_rootAllocWithZone(self, (malloc_zone_t *)zone);
}

```
Next, let's take a closer look at the specific implementation of \_objc\_rootAllocWithZone.
```objectivec

id _objc_rootAllocWithZone(Class cls, malloc_zone_t *zone)
{
    id obj;

#if __OBJC2__
    // allocWithZone under __OBJC2__ ignores the zone parameter
    (void)zone;
    obj = class_createInstance(cls, 0);

#else
    if (!zone || UseGC) {
        obj = class_createInstance(cls, 0);
    }
    else {
        obj = class_createInstanceFromZone(cls, 0, zone);
    }

#endif

    if (!obj) obj = callBadAllocHandler(cls);
    return obj;
}


```
In \_\_OBJC2\_\_, directly call the class\_createInstance(cls, 0); method to create an object.
```objectivec

id  class_createInstance(Class cls, size_t extraBytes)
{
    return _class_createInstanceFromZone(cls, extraBytes, nil);
}

```
We won’t analyze the \_class\_createInstanceFromZone method in detail here; we’ll do that later. For now, let’s first clarify the program flow.

In older versions of objc, it first checks whether the zone has space and whether garbage collection is being used. If there is no space, or if garbage collection is enabled, it calls class\_createInstance(cls, 0) to obtain the object; otherwise, it calls class\_createInstanceFromZone(cls, 0, zone); to obtain the object.
```objectivec

id class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone)
{
    return _class_createInstanceFromZone(cls, extraBytes, zone);
}

```
As you can see, the function ultimately called to create an object is always \_class\_createInstanceFromZone, regardless of whether the objc version is new or old.

If creation succeeds, objc is returned; if creation fails, the callBadAllocHandler method is invoked.
```objectivec

static id callBadAllocHandler(Class cls)
{
    // fixme add re-entrancy protection in case allocation fails inside handler
    return (*badAllocHandler)(cls);
}

static id(*badAllocHandler)(Class) = &defaultBadAllocHandler;

static id defaultBadAllocHandler(Class cls)
{
    _objc_fatal("attempt to allocate object of class '%s' failed", 
                cls->nameForLogging());
}

```
After object creation fails, it will ultimately call \_objc\_fatal and output "attempt to allocate object of class failed", indicating that object creation failed.

At this point, we’ve covered the case where hasCustomAWZ( ) returns YES in callAlloc. So what happens when hasCustomAWZ( ) returns NO?
```objectivec

    if (! cls->ISA()->hasCustomAWZ()) {
        // No alloc/allocWithZone implementation. Go straight to the allocator.
        // fixme store hasCustomAWZ in the non-meta class and 
        // add it to canAllocFast's summary
        if (cls->canAllocFast()) {
            // No ctors, raw isa, etc. Go straight to the metal.
            bool dtor = cls->hasCxxDtor();
            id obj = (id)calloc(1, cls->bits.fastInstanceSize());
            if (!obj) return callBadAllocHandler(cls);
            obj->initInstanceIsa(cls, dtor);
            return obj;
        }
        else {
            // Has ctor or raw isa or something. Use the slower path.
            id obj = class_createInstance(cls, 0);
            if (!obj) return callBadAllocHandler(cls);
            return obj;
        }
    }

```
This section covers the case where `hasCustomAWZ()` returns `NO`, which corresponds to the current `class` not having a default `allocWithZone`.

When there is no default `allocWithZone`, it still needs to check again whether the current `class` supports fast `alloc`. If it does, it directly calls `calloc` to allocate a block of memory of size `bits.fastInstanceSize()`. If allocation fails, it will also call `callBadAllocHandler`.

If allocation succeeds, it initializes the `isa` pointer and `dtor`.
```objectivec

    bool hasCxxDtor() {
        return data()->flags & RW_HAS_CXX_DTOR;
    }

// class or superclass has .cxx_destruct implementation

#define RW_HAS_CXX_DTOR       (1<<17)

```
`dtor` is used to determine whether the current class or its superclass implements the `.cxx\_destruct` function.

If the current class does not support fast allocation, it simply calls `class\_createInstance(cls, 0);` to create a new object.


To summarize:


![](https://img.halfrost.com/Blog/ArticleImage/30_3.png)


After the series of checks above, the process of “creating an object” ultimately falls to the `\_class\_createInstanceFromZone` function.
```objectivec

static __attribute__((always_inline))  id _class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone, 
                              bool cxxConstruct = true, 
                              size_t *outAllocatedSize = nil)
{
    if (!cls) return nil;

    assert(cls->isRealized());

    // Read class's info bits all at once for performance
    bool hasCxxCtor = cls->hasCxxCtor();
    bool hasCxxDtor = cls->hasCxxDtor();
    bool fast = cls->canAllocIndexed();

    size_t size = cls->instanceSize(extraBytes);
    if (outAllocatedSize) *outAllocatedSize = size;

    id obj;
    if (!UseGC  &&  !zone  &&  fast) {
        obj = (id)calloc(1, size);
        if (!obj) return nil;
        obj->initInstanceIsa(cls, hasCxxDtor);
    } 
    else {

#if SUPPORT_GC
        if (UseGC) {
            obj = (id)auto_zone_allocate_object(gc_zone, size,
                                                AUTO_OBJECT_SCANNED, 0, 1);
        } else 

#endif
        if (zone) {
            obj = (id)malloc_zone_calloc ((malloc_zone_t *)zone, 1, size);
        } else {
            obj = (id)calloc(1, size);
        }
        if (!obj) return nil;

        // Use non-indexed isa on the assumption that they might be 
        // doing something weird with the zone or RR.
        obj->initIsa(cls);
    }

    if (cxxConstruct && hasCxxCtor) {
        obj = _objc_constructOrFree(obj, cls);
    }

    return obj;
}

```
What do ctor and dtor refer to, respectively?
```objectivec

    bool hasCxxCtor() {
        // addSubclass() propagates this flag from the superclass.
        assert(isRealized());
        return bits.hasCxxCtor();
    }

    bool hasCxxCtor() {
        return data()->flags & RW_HAS_CXX_CTOR;
    }

#define RW_HAS_CXX_CTOR       (1<<18)

```
ctor determines whether the current class or its superclass has an implementation of the .cxx\_construct constructor method.
```objectivec

    bool hasCxxDtor() {
        // addSubclass() propagates this flag from the superclass.
        assert(isRealized());
        return bits.hasCxxDtor();
    }

    bool hasCxxDtor() {
        return data()->flags & RW_HAS_CXX_DTOR;
    }

#define RW_HAS_CXX_DTOR       (1<<17)

```
dtor determines whether the current class or superclass has an implementation of the .cxx\_destruct destructor method.
```objectivec

    size_t instanceSize(size_t extraBytes) {
        size_t size = alignedInstanceSize() + extraBytes;
        // CF requires all objects be at least 16 bytes.
        if (size < 16) size = 16;
        return size;
    }

    uint32_t alignedInstanceSize() {
        return word_align(unalignedInstanceSize());
    }

    uint32_t unalignedInstanceSize() {
        assert(isRealized());
        return data()->ro->instanceSize;
    }

```
The instance size `instanceSize` is stored in the `class_ro_t` structure, then aligned and finally returned.

Note: Core Foundation requires the size of every object to be greater than or equal to 16 bytes.

After obtaining the object size, you can directly call the `calloc` function to allocate memory for the object.


About the `calloc` function

>The calloc( ) function contiguously allocates enough space for count objects that are size bytes of memory each and returns a pointer to the allocated memory. The allocated memory is filled with bytes of value zero.

This function is also why the objects we allocate have initial values of 0 or nil. The `calloc( )` function initializes the allocated memory to 0 or nil by default.

After allocating the memory, the `isa` pointer still needs to be initialized.
```objectivec

obj->initInstanceIsa(cls, hasCxxDtor);

obj->initIsa(cls);

```
The two functions above are used to initialize the Isa pointer.
```objectivec

inline void  objc_object::initInstanceIsa(Class cls, bool hasCxxDtor)
{
    assert(!UseGC);
    assert(!cls->requiresRawIsa());
    assert(hasCxxDtor == cls->hasCxxDtor());

    initIsa(cls, true, hasCxxDtor);
}


inline void  objc_object::initIsa(Class cls)
{
    initIsa(cls, false, false);
}

```
From the source code above, we can also see that in the end they all call the `initIsa` function, with only the arguments differing.
```objectivec

inline void  objc_object::initIsa(Class cls, bool indexed, bool hasCxxDtor) 
{ 
    assert(!isTaggedPointer()); 
    
    if (!indexed) {
        isa.cls = cls;
    } else {
        assert(!DisableIndexedIsa);
        isa.bits = ISA_MAGIC_VALUE;
        // isa.magic is part of ISA_MAGIC_VALUE
        // isa.indexed is part of ISA_MAGIC_VALUE
        isa.has_cxx_dtor = hasCxxDtor;
        isa.shiftcls = (uintptr_t)cls >> 3;
    }
}

```
The initialization process is essentially the process of initializing the isa_t struct.
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

```
For the specific initialization process, see this article: [Psychiatric Hospital Objective-C Runtime, Day 1 of Admission — isa and Class](http://www.jianshu.com/p/9d649ce6d0b8)


>**The main reason for shifting the current address three bits to the right is to clear the unused last three bits in the Class pointer and reduce memory consumption, because class pointers must be byte-aligned (8 bits), so the last three bits of the pointer are meaningless 0s**.
Most machine architectures are [byte-addressable](https://en.wikipedia.org/wiki/Byte_addressing), but an object’s memory address must be aligned to a multiple of bytes. This can improve code execution performance. On the iPhone 5s, virtual addresses are 33 bits, so the last three bits used for alignment are `000`; we use only 30 of those bits to represent the object’s address.


At this point, the process of creating the object is complete.


#### II. Object Birth

![](https://img.halfrost.com/Blog/ArticleImage/30_4.png)


Once we call the init method, the object is “born.”
```objectivec

- (id)init {
    return _objc_rootInit(self);
}

```
init calls the \_objc\_rootInit method.
```objectivec

id _objc_rootInit(id obj)
{
    // In practice, it will be hard to rely on this function.
    // Many classes do not properly chain -init calls.
    return obj;
}

```
The role of the \_objc\_rootInit method is merely to return the current object.


#### III. Object Growth

![](https://img.halfrost.com/Blog/ArticleImage/30_5.png)


When talking about object growth, what we really want to discuss is what an object’s properties and methods look like in memory when they are accessed after the object has been initialized.
```objectivec

#import <Foundation/Foundation.h>

@interface Student : NSObject
@property (strong , nonatomic) NSString *name;
+(void)study;
-(void)run;
@end


#import "Student.h"
@implementation Student

+(void)study
{
    NSLog(@"Study"); 
}

-(void)run
{
    NSLog(@"Run");
}
@end

```
Here we create a `Student` class as an example. This class is very simple: it has only a `name` attribute, along with one class method and one instance method.
```objectivec

        Student  *stu = [[Student alloc]init];
        
        NSLog(@"Student's class is %@", [stu class]);
        NSLog(@"Student's meta class is %@", object_getClass([stu class]));
        NSLog(@"Student's meta class's superclass is %@", object_getClass(object_getClass([stu class])));
        
        Class currentClass = [Student class];
        for (int i = 1; i < 5; i++)
        {
            NSLog(@"Following the isa pointer %d times gives %p %@", i, currentClass,currentClass);
            currentClass = object_getClass(currentClass);
        }
        
        NSLog(@"NSObject's class is %p", [NSObject class]);
        NSLog(@"NSObject's meta class is %p", object_getClass([NSObject class]));

```
Write the code above and analyze its structure.

The output is as follows:
```objectivec


Student's class is Student
Student's meta class is Student
Student's meta class's superclass is NSObject
Following the isa pointer 1 times gives 0x100004d90 Student
Following the isa pointer 2 times gives 0x100004d68 Student
Following the isa pointer 3 times gives 0x7fffba0b20f0 NSObject
Following the isa pointer 4 times gives 0x7fffba0b20f0 NSObject
NSObject's class is 0x7fffba0b2140
NSObject's meta class is 0x7fffba0b20f0

```
From the printed results above, we can see that the `isa` of an instance of a class points to its class, as shown below:

![](https://img.halfrost.com/Blog/ArticleImage/30_6.png)


For an instance of a class, the dashed line points to the gray area. The gray area is a Class pair, which contains two things: one is the class, and the other is the meta-class. The class’s `isa` points to the meta-class. Since `student` inherits from `NSObject`, the `superclass` of `Student`’s class’s meta-class is `NSObject`.

To figure out what is stored in each of these three things, let’s print some additional information.
```objectivec


+ (NSArray *)instanceVariables {
    unsigned int outCount;
    Ivar *ivars = class_copyIvarList([self class], &outCount);
    NSMutableArray *result = [NSMutableArray array];
    for (unsigned int i = 0; i < outCount; i++) {
        NSString *type = [NSString decodeType:ivar_getTypeEncoding(ivars[i])];
        NSString *name = [NSString stringWithCString:ivar_getName(ivars[i]) encoding:NSUTF8StringEncoding];
        NSString *ivarDescription = [NSString stringWithFormat:@"%@ %@", type, name];
        [result addObject:ivarDescription];
    }
    free(ivars);
    return result.count ? [result copy] : nil;
}

```
From the previous printed output, we know that `0x100004d90` is the address of the class. `0x100004d68` is the address of the meta-class.
```vim

po [0x100004d90 instanceVariables]
po [0x100004d68 instanceVariables]

```
Print it out:
```objectivec


<__NSSingleObjectArrayI 0x100302460>(
  NSString* _name
)

nil
```
From this, we can see that properties are stored in the class.

Next is an understanding of class methods and instance methods, and of `+` methods and `-` methods.

In memory, there is actually no concept of `+` methods or `-` methods. Let’s do an experiment:
```objectivec

+ (NSArray *)ClassMethodNames
{
    NSMutableArray * array = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method * methodList = class_copyMethodList([self class], &methodCount);
    unsigned int i;
    for(i = 0; i < methodCount; i++) {
        [array addObject: NSStringFromSelector(method_getName(methodList[i]))];
    }
    
    free(methodList);
    return array;
}


```

```objectivec

po [0x100004d90 ClassMethodNames]
po [0x100004d68 ClassMethodNames]

```
Print it out:
```vim

<__NSArrayM 0x100303310>(
.cxx_destruct,
name,
setName:,
run
)

<__NSArrayM 0x100303800>(
study
)

```
0x100004d90 is the class object, which stores the `-` methods, along with three other methods: the getter, the setter, and the `.cxx_destruct` method.

0x100004d68 is the meta-class, which stores the `+` methods.

Of course, there is one special case for meta-classes in the runtime: the meta-class of `NSObject`. Its `superclass` is itself. To prevent potential crashes when calling `-` methods from the `NSObject` protocol, such as the `copy` instance method, all of `NSObject`’s `+` methods are reimplemented in `NSObject`’s meta-class. This is done so that when message dispatch reaches this point, it can be intercepted. Therefore, in general, methods in the `NSObject` protocol usually have both `+` and `-` versions for the same method.

It is worth noting that both class and meta-class objects are singletons.

As for objects, every object has an `isa` in memory. `isa` is like a small “radar”; with it, you can send messages to an object under the runtime.

So the essence of an object is: an object in ObjC is a variable pointing to the address of a `ClassObject`, that is, `id obj = &ClassObject`.

The essence of an object property is: `void *ivar = &obj + offset(N)`
```objectivec

    NSString *myName = @"halfrost";
    NSLog(@"myName address = %p , size = %lu  ",&myName ,sizeof(myName));
    
    id cls = [Student class];
    NSLog(@"Student class = %@ address = %p , size = %lu", cls, &cls,sizeof(cls));
    
    void *obj = &cls;
    NSLog(@"Void *obj = %@ address = %p , size = %lu", obj,&obj, sizeof(obj));
    
    NSLog(@"%@  %p",((__bridge Student *)obj).name,((__bridge Student *)obj).name);

```
Output
```vim


myName address = 0x7fff562eeaa8 , size = 8  
Student class = Student address = 0x7fff562eeaa0 , size = 8
Void *obj = <Student: 0x7fff562eeaa0> address = 0x7fff562eea98 , size = 8
halfrost  0x10a25c068

```
This example shows that, in essence, an object is an address variable that points to a class object. From obj in the example above, you can see that id obj = &ClassObject. cls is the class object of Student, so obj is an instance of Student.

Class objects are loaded into memory before the main function executes. All symbols in the executable file and dynamic libraries (Class, Protocol, Selector, IMP, ...) have already been successfully loaded into memory in the required format and are managed by the runtime. Only after that can runtime methods such as dynamically adding a Class, swizzling, and so on take effect.

For details, see this article: [What Happens Before the main Function of an iOS Program](http://blog.sunnyxx.com/2014/08/30/objc-pre-main/)


Returning to the example, an object's properties can be accessed by adding an offset to the address of obj. In the example above, the address of obj is 0x7fff562eea98. Moving down by 8 bytes reaches the address of class, 0x7fff562eeaa0. Moving down another 8 bytes reaches the address of the name property, 0x7fff562eeaa8. What is stored in name is the starting address of the string. As the printed output also shows, what is stored there is a pointer, pointing to the address 0x10a25c068.

If we print this address:

![](https://img.halfrost.com/Blog/ArticleImage/30_9.png)

we will find that what it stores is exactly our string.


![](https://img.halfrost.com/Blog/ArticleImage/30_10.png)


To summarize, this is what the diagram above shows: the isa of each object stores the memory address of its Class. The Class is loaded into memory before the main function executes and is managed by the Runtime. Therefore, as long as you construct a pointer to the Class—that is, isa—it can become an object.

An object's properties are accessed by applying offsets from the object's starting address. As shown above, once we know the object's starting address is 0x7fff562eea98, an offset of 8 bytes reaches isa, and another offset of 8 bytes reaches the name property. Accessing an object's properties is essentially the process of offset-based addressing and value retrieval in memory.


#### IV. Object Destruction


![](https://img.halfrost.com/Blog/ArticleImage/30_7.png)


Destroying an object means calling the dealloc method.
```objectivec


- (void)dealloc {
    _objc_rootDealloc(self);
}

```
The dealloc method calls the \_objc\_rootDealloc method.
```objectivec

void _objc_rootDealloc(id obj)
{
    assert(obj);

    obj->rootDealloc();
}


inline void objc_object::rootDealloc()
{
    assert(!UseGC);
    if (isTaggedPointer()) return;

    if (isa.indexed  &&  
        !isa.weakly_referenced  &&  
        !isa.has_assoc  &&  
        !isa.has_cxx_dtor  &&  
        !isa.has_sidetable_rc)
    {
        assert(!sidetable_present());
        free(this);
    } 
    else {
        object_dispose((id)this);
    }
}

```
If it is a TaggedPointer, return directly.

`indexed` indicates whether isa pointer optimization is enabled. `weakly_referenced` indicates that the object is, or was, referenced by an ARC weak variable. `has_assoc` indicates that the object has, or has had, associated references. `has_cxx_dtor`, as mentioned earlier, is the destructor. `has_sidetable_rc` determines whether the object’s reference count is too large.
```objectivec


id  object_dispose(id obj)
{
    if (!obj) return nil;

    objc_destructInstance(obj);
    
#if SUPPORT_GC
    if (UseGC) {
        auto_zone_retain(gc_zone, obj); // gc free expects rc==1
    }

#endif

    free(obj);

    return nil;
}

```
object\_dispose calls objc\_destructInstance.
```objectivec


/***********************************************************************
* objc_destructInstance
* Destroys an instance without freeing memory. 
* Calls C++ destructors.
* Calls ARR ivar cleanup.
* Removes associative references.
* Returns `obj`. Does nothing if `obj` is nil.
* Be warned that GC DOES NOT CALL THIS. If you edit this, also edit finalize.
* CoreFoundation and other clients do call this under GC.
**********************************************************************/
void *objc_destructInstance(id obj) 
{
    if (obj) {
        // Read all of the flags at once for performance.
        bool cxx = obj->hasCxxDtor();
        bool assoc = !UseGC && obj->hasAssociatedObjects();
        bool dealloc = !UseGC;

        // This order is important.
        if (cxx) object_cxxDestruct(obj);
        if (assoc) _object_remove_assocations(obj);
        if (dealloc) obj->clearDeallocating();
    }

    return obj;
}

```
Destroying an object is handled by the underlying C++ destructor. The associative references also need to be removed.

Next, let’s take a detailed look at the three methods for destroying an object in order.

##### 1.object\_cxxDestruct
```objectivec


void object_cxxDestruct(id obj)
{
    if (!obj) return;
    if (obj->isTaggedPointer()) return;
    object_cxxDestructFromClass(obj, obj->ISA());
}

static void object_cxxDestructFromClass(id obj, Class cls)
{
    void (*dtor)(id);

    // Call cls's dtor first, then superclasses's dtors.

    for ( ; cls; cls = cls->superclass) {
        if (!cls->hasCxxDtor()) return; 
        dtor = (void(*)(id))
            lookupMethodInClassAndLoadCache(cls, SEL_cxx_destruct);
        if (dtor != (void(*)(id))_objc_msgForward_impcache) {
            if (PrintCxxCtors) {
                _objc_inform("CXX: calling C++ destructors for class %s", 
                             cls->nameForLogging());
            }
            (*dtor)(obj);
        }
    }
}


```
Starting from the subclass, walk up the inheritance chain all the way to the superclass, searching upward for the `SEL_cxx_destruct` selector. Once found, locate the function implementation `(void (*)(id)` (a function pointer) and execute it.

The following quotes are from [Exploring the dealloc Process Under ARC and .cxx_destruct](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/):

From [this article](http://my.safaribooksonline.com/book/programming/objective-c/9780132908641/3dot-memory-management/ch03):
>ARC actually creates a -.cxx_destruct method to handle freeing instance variables. This method was originally created for calling C++ destructors automatically when an object was destroyed.

And as mentioned in *Effective Objective-C 2.0*:
>When the compiler saw that an object contained C++ objects, it would generate a method called .cxx_destruct. ARC piggybacks on this method and emits the required cleanup code within it.

From this we can see that the `.cxx_destruct` method was originally intended for destructing C++ objects, and ARC reuses this method to insert code that performs automatic memory cleanup.

Under ARC, the `dealloc` method is called after the final `release`, but at that point the instance variables (ivars) have not yet been released. **The superclass’s `dealloc` method is automatically called after the subclass’s `dealloc` method returns**. Under ARC, an object’s instance variables are released in the root class’s `[NSObject dealloc]` (typically the root class is `NSObject`). The release order of variables is unspecified in various ways (it is unspecified within a class, and also unspecified between subclasses and superclasses; in other words, there is no need to care about the release order).


Based on the investigation in @sunnyxx’s article:
1. Under ARC, an object’s member variables are automatically released by the compiler-inserted `.cxx_desctruct` method.
2. Under ARC, the `[super dealloc]` call is also automatically inserted by the compiler.


As for the implementation of the `.cxx_destruct` method, please refer to the detailed analysis in @sunnyxx’s article.


##### 2.\_object\_remove\_assocations
```objectivec

void _object_remove_assocations(id object) {
    vector< ObjcAssociation,ObjcAllocator<ObjcAssociation> > elements;
    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.associations());
        if (associations.size() == 0) return;
        disguised_ptr_t disguised_object = DISGUISE(object);
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        if (i != associations.end()) {
            // copy all of the associations that need to be removed.
            ObjectAssociationMap *refs = i->second;
            for (ObjectAssociationMap::iterator j = refs->begin(), end = refs->end(); j != end; ++j) {
                elements.push_back(j->second);
            }
            // remove the secondary table.
            delete refs;
            associations.erase(i);
        }
    }
    // the calls to releaseValue() happen outside of the lock.
    for_each(elements.begin(), elements.end(), ReleaseValue());
}


```
When removing the associated object, the runtime first checks the value of the second bit, has\_assoc, in the object’s isa\_t. Only when object exists and object\->hasAssociatedObjects( ) returns 1 will it call the \_object\_remove\_assocations method.

The purpose of \_object\_remove\_assocations is to delete the second ObjcAssociationMap table, that is, to delete all associated objects. To delete the second table, it needs to traverse and look it up in the first AssociationsHashMap table. Here, all ObjcAssociation objects in the second ObjcAssociationMap table are stored in an array named elements, and then associations.erase( ) is called to delete the second table. Finally, the elements array is traversed, and the ObjcAssociation objects are released one by one.

The removal approach here is exactly the same as the remove method for Associated Object associated objects.


##### 3.clearDeallocating( )
```objectivec


inline void objc_object::clearDeallocating()
{
    if (!isa.indexed) {
        // Slow path for raw pointer isa.
        sidetable_clearDeallocating();
    }
    else if (isa.weakly_referenced  ||  isa.has_sidetable_rc) {
        // Slow path for non-pointer isa with weak refs and/or side table data.
        clearDeallocating_slow();
    }

    assert(!sidetable_present());
}

```
This involves two `clear` functions. Let’s look at them one by one.
```objectivec


void objc_object::sidetable_clearDeallocating()
{
    SideTable& table = SideTables()[this];

    // clear any weak table items
    // clear extra retain count and deallocating bit
    // (fixme warn or abort if extra retain count == 0 ?)
    table.lock();
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it != table.refcnts.end()) {
        if (it->second & SIDE_TABLE_WEAKLY_REFERENCED) {
            weak_clear_no_lock(&table.weak_table, (id)this);
        }
        table.refcnts.erase(it);
    }
    table.unlock();
}

```
Traverse `SideTable` and call the `weak_clear_no_lock` function in a loop.

`weakly_referenced` indicates that the object is, or once was, referenced by an ARC weak variable. `has_sidetable_rc` determines whether the object’s reference count is too large. If either of them is `YES`, the `clearDeallocating_slow()` method is called.
```objectivec


// Slow path of clearDeallocating() 
// for objects with indexed isa
// that were ever weakly referenced 
// or whose retain count ever overflowed to the side table.
NEVER_INLINE void objc_object::clearDeallocating_slow()
{
    assert(isa.indexed  &&  (isa.weakly_referenced || isa.has_sidetable_rc));

    SideTable& table = SideTables()[this];
    table.lock();
    if (isa.weakly_referenced) {
        weak_clear_no_lock(&table.weak_table, (id)this);
    }
    if (isa.has_sidetable_rc) {
        table.refcnts.erase(this);
    }
    table.unlock();
}


```
`clearDeallocating_slow` also eventually calls the `weak_clear_no_lock` method.
```objectivec


/** 
 * Called by dealloc; nils out all weak pointers that point to the 
 * provided object so that they can no longer be used.
 * 
 * @param weak_table 
 * @param referent The object being deallocated. 
 */
void  weak_clear_no_lock(weak_table_t *weak_table, id referent_id) 
{
    objc_object *referent = (objc_object *)referent_id;

    weak_entry_t *entry = weak_entry_for_referent(weak_table, referent);
    if (entry == nil) {
        /// XXX shouldn't happen, but does with mismatched CF/objc
        //printf("XXX no entry for clear deallocating %p\n", referent);
        return;
    }

    // zero out references
    weak_referrer_t *referrers;
    size_t count;
    
    if (entry->out_of_line) {
        referrers = entry->referrers;
        count = TABLE_SIZE(entry);
    } 
    else {
        referrers = entry->inline_referrers;
        count = WEAK_INLINE_COUNT;
    }
    
    for (size_t i = 0; i < count; ++i) {
        objc_object **referrer = referrers[i];
        if (referrer) {
            if (*referrer == referent) {
                *referrer = nil;
            }
            else if (*referrer) {
                _objc_inform("__weak variable at %p holds %p instead of %p. "
                             "This is probably incorrect use of "
                             "objc_storeWeak() and objc_loadWeak(). "
                             "Break on objc_weak_error to debug.\n", 
                             referrer, (void*)*referrer, (void*)referent);
                objc_weak_error();
            }
        }
    }
    
    weak_entry_remove(weak_table, entry);
}


```
This function clears the reference count table and the weak reference table in the weak\_table, setting all weak references to nil.


#### Summary

![](https://img.halfrost.com/Blog/ArticleImage/30_8.png)


This article provides a detailed analysis of an objc object, from birth to final destruction—its entire lifecycle is covered here. Feedback and corrections are very welcome.