# Objc 对象的今生今世

![](https://img.halfrost.com/Blog/ArticleTitleImage/30_0_.png)



#### 前言

在面向对象编程中，我们每天都在创建对象，用对象描述着整个世界，然而对象是如何从孕育到销毁的呢？





#### 目录
- 1.孕育对象
- 2.对象的出生
- 3.对象的成长
- 4.对象的销毁
- 5.总结


##### 一.孕育对象


![](https://img.halfrost.com/Blog/ArticleImage/30_1.png)




每天开发我们都在alloc对象，而alloc方法做了些什么呢？


```objectivec

+ (id)alloc {
    return _objc_rootAlloc(self);
}

```

所有对象alloc都会调用这个root的方法

```objectivec

id _objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}

```

这个方法又会去调用callAlloc方法

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

由于入参 checkNil = false，所以不会返回nil。

```objectivec

    bool hasCustomAWZ() {
        return ! bits.hasDefaultAWZ();
    }

```

![](https://img.halfrost.com/Blog/ArticleImage/30_2.png)


在[这张图](https://github.com/Draveness/iOS-Source-Code-Analyze/blob/master/contents/images/objc-method-after-realize-class.png)，我们可以看到在对象的数据段data中，class\_rw\_t中有一个flags。

```objectivec

    bool hasDefaultAWZ( ) {
        return data()->flags & RW_HAS_DEFAULT_AWZ;
    }

#define RW_HAS_DEFAULT_AWZ    (1<<16)

```

RW\_HAS\_DEFAULT\_AWZ 这个是用来标示当前的class或者是superclass是否有默认的alloc/allocWithZone:。值得注意的是，这个值会存储在metaclass 中。


hasDefaultAWZ( )方法是用来判断当前class是否有默认的allocWithZone。


如果cls\->ISA()\->hasCustomAWZ()返回YES，意味着有默认的allocWithZone方法，那么就直接对class进行allocWithZone，申请内存空间。

```objectivec

    if (allocWithZone) return [cls allocWithZone:nil];

```

allocWithZone会去调用rootAllocWithZone

```objectivec

+ (id)allocWithZone:(struct _NSZone *)zone {
    return _objc_rootAllocWithZone(self, (malloc_zone_t *)zone);
}

```

接下来就仔细看看\_objc\_rootAllocWithZone的具体实现

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

在\_\_OBJC2\_\_中，直接调用class\_createInstance(cls, 0);方法去创建对象。

```objectivec

id  class_createInstance(Class cls, size_t extraBytes)
{
    return _class_createInstanceFromZone(cls, extraBytes, nil);
}

```

关于\_class\_createInstanceFromZone方法这里先不详细分析，下面再详细分析，先理清程序脉络。

在objc的老版本中要先去看看zone是否有空间，是否用了垃圾回收，如果没有空间，或者用了垃圾回收，就会调用class\_createInstance(cls, 0)方法获取对象，否则调用class\_createInstanceFromZone(cls, 0, zone);获取对象。

```objectivec

id class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone)
{
    return _class_createInstanceFromZone(cls, extraBytes, zone);
}

```

可以看到，创建对象最终调用的函数都是\_class\_createInstanceFromZone，不管objc的版本是新版还是旧版。

如果创建成功就返回objc，如果创建失败，就会调用callBadAllocHandler方法。


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

创建对象失败后，最终会调用\_objc\_fatal输出"attempt to allocate object of class failed"创建对象失败。

到此就完成了callAlloc中hasCustomAWZ( )返回YES的情况。那么hasCustomAWZ( )函数返回NO，情况是怎么样的呢？

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

这一段是hasCustomAWZ( )返回NO的情况，对应的是当前class没有默认的allocWithZone的情况。

在没有默认的allocWithZone的情况下，还需要再次判断当前的class是否支持快速alloc。如果可以，直接调用calloc函数，申请1块bits.fastInstanceSize()大小的内存空间，如果创建失败，也会调用callBadAllocHandler函数。

如果创建成功，就去初始化Isa指针和dtor。

```objectivec

    bool hasCxxDtor() {
        return data()->flags & RW_HAS_CXX_DTOR;
    }

// class or superclass has .cxx_destruct implementation
#define RW_HAS_CXX_DTOR       (1<<17)

```

dtor是用来判断当前class或者superclass是否有.cxx\_destruct函数的实现。

如果当前的class不支持快速alloc，那么就乖乖的去调用class\_createInstance(cls, 0);方法去创建一个新的对象。


小结一下：


![](https://img.halfrost.com/Blog/ArticleImage/30_3.png)



经过上面的一系列判断，“孕育对象”的过程最终落在了\_class\_createInstanceFromZone函数上了。


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


ctor 和 dtor 分别是什么呢？

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

ctor是判断当前class或者superclass 是否有.cxx\_construct构造方法的实现。


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

dtor是判断判断当前class或者superclass 是否有.cxx\_destruct析构方法的实现。

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

实例大小 instanceSize 会存储在 class\_ro\_t 结构体中，然后经过对齐最后返回。

注意：Core Foundation 需要所有的对象的大小都必须大于或等于 16 字节。

在获取对象大小之后，直接调用calloc函数就可以为对象分配内存空间了。


关于calloc函数

>The calloc( ) function contiguously allocates enough space for count objects that are size bytes of memory each and returns a pointer to the allocated memory. The allocated memory is filled with bytes of value zero.

这个函数也是为什么我们申请出来的对象，初始值是0或者nil的原因。因为这个calloc( )函数会默认的把申请出来的空间初始化为0或者nil。

申请完内存空间之后，还需要再初始化Isa指针。

```objectivec

obj->initInstanceIsa(cls, hasCxxDtor);

obj->initIsa(cls);

```

初始化Isa指针有这上面两个函数。


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

从上述源码中，我们也能看出，最终都是调用了initIsa函数，只不过入参不同。

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

初始化的过程就是对isa_t结构体初始化的过程。

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


具体初始化的过程请参见这篇[神经病院Objective-C Runtime入院第一天——isa和Class](http://www.jianshu.com/p/9d649ce6d0b8)





>**将当前地址右移三位的主要原因是用于将 Class 指针中无用的后三位清除减小内存的消耗，因为类的指针要按照字节（8 bits）对齐内存，其指针后三位都是没有意义的 0**。
绝大多数机器的架构都是 [byte-addressable](https://en.wikipedia.org/wiki/Byte_addressing) 的，但是对象的内存地址必须对齐到字节的倍数，这样可以提高代码运行的性能，在 iPhone5s 中虚拟地址为 33 位，所以用于对齐的最后三位比特为 000，我们只会用其中的 30 位来表示对象的地址。



至此，孕育对象的过程就完成了。


#### 二.对象的出生

![](https://img.halfrost.com/Blog/ArticleImage/30_4.png)





一旦当我们调用init方法的时候，对象就会“出生”了。

```objectivec

- (id)init {
    return _objc_rootInit(self);
}

```

init会调用\_objc\_rootInit方法。


```objectivec

id _objc_rootInit(id obj)
{
    // In practice, it will be hard to rely on this function.
    // Many classes do not properly chain -init calls.
    return obj;
}

```

而\_objc\_rootInit方法的作用也仅仅就是返回了当前对象而已。


#### 三.对象的生长

![](https://img.halfrost.com/Blog/ArticleImage/30_5.png)


关于对象的生长，其实是想谈谈对象初始化之后，访问它的属性和方法，它们在内存中的样子。

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

这里我们新建一个Student类，来举例说明。这个类很简单，只有一个name的属性，加上一个类方法，和一个实例方法。


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

写出上述的代码，分析一下结构。

输出如下:

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

经过上面的打印结果，我们可以知道，一个类的实例的isa是指向它的class，如下图：

![](https://img.halfrost.com/Blog/ArticleImage/30_6.png)



一个类的实例，虚线指向灰色的区域，灰色的区域是一个Class pair，里面包含两个东西，一个是类，另一个是meta-class。类的isa指向meta-class。由于student是继承NSObject，所以Student的class的meta-class的superclass是NSObject。

为了弄清楚这3个东西里面分别存了些什么，我们进一步的打印一些信息。


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

从之前的打印信息我们能知道，0x100004d90是类的地址。0x100004d68是meta-class类的地址。

```vim

po [0x100004d90 instanceVariables]
po [0x100004d68 instanceVariables]

```

打印出来：

```objectivec


<__NSSingleObjectArrayI 0x100302460>(
  NSString* _name
)

nil
```

从这里就知道了，属性这些是存储在类中。


接下来就是关于类方法和实例方法的认识，+号方法和-号方法的认识。

在内存中其实没有+号和-号方法的概念。做个试验：

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


打印出来：

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


0x100004d90是类对象，里面存储的是-号方法，还有另外3个方法，getter，setter，还有.cxx\_destruct方法

0x100004d68是meta-class，里面存储的是+号方法。

当然在runtime的meta-class有一处很特殊，那就是NSObject的meta-class，它的superclass是它自己本身。为了防止调用NSObject协议里面的减号方法可能会出现崩溃，比如copy的-号方法，于是在NSObject的meta-class里面把所有的NSObject的+号方法都重新实现了一遍，就是为了消息传递到这里，拦截了一遍。所以一般NSObject协议方法同一个方法都有+号和-号方法。

值得说明的是，class和meta-class都是单例。

关于对象，所有的对象在内存里面都有一个isa，isa就是一个小“雷达”，有了它，就可以在runtime下给一个对象发送消息了。

所以对象的实质：Objc中的对象是一个指向ClassObject地址的变量，即 id obj = &ClassObject 。

关于对象的属性实质是，void *ivar = &obj + offset(N)

```objectivec

    NSString *myName = @"halfrost";
    NSLog(@"myName 地址 = %p , 大小 = %lu  ",&myName ,sizeof(myName));
    
    id cls = [Student class];
    NSLog(@"Student class = %@ 地址 = %p , 大小 = %lu", cls, &cls,sizeof(cls));
    
    void *obj = &cls;
    NSLog(@"Void *obj = %@ 地址 = %p , 大小 = %lu", obj,&obj, sizeof(obj));
    
    NSLog(@"%@  %p",((__bridge Student *)obj).name,((__bridge Student *)obj).name);

```

输出

```vim


myName 地址 = 0x7fff562eeaa8 , 大小 = 8  
Student class = Student 地址 = 0x7fff562eeaa0 , 大小 = 8
Void *obj = <Student: 0x7fff562eeaa0> 地址 = 0x7fff562eea98 , 大小 = 8
halfrost  0x10a25c068

```

从这个例子就可以说明，对象的实质就是指向类对象的地址变量，从上面例子里面obj就可以看出， id obj = &ClassObject ，cls是Student的类对象，所以obj是Student的对象。

类对象是在main函数执行之前就加载进内存的，可执行文件中和动态库所有的符号（Class，Protocol，Selector，IMP，…）都已经按格式成功加载到内存中，被 runtime 所管理，再这之后，runtime 的那些方法（动态添加 Class、swizzle 等等才能生效）

具体可以看这篇文章[iOS 程序 main 函数之前发生了什么](http://blog.sunnyxx.com/2014/08/30/objc-pre-main/)


还是回到例子中来，关于对象的属性，就是obj的地址加上偏移量，就可以访问到，上述的例子中，obj地址是0x7fff562eea98，往下偏移8，到了class的地址，0x7fff562eeaa0，再往下偏移8，就到了name属性的地址，0x7fff562eeaa8。在name中存储的是字符串的首地址，根据打印信息也看到了，存储的是一个指针，指向的0x10a25c068的地址。

如果我们打印一下这个地址：

![](https://img.halfrost.com/Blog/ArticleImage/30_9.png)

就会发现里面存的就是我们的字符串。


![](https://img.halfrost.com/Blog/ArticleImage/30_10.png)


总结一下就是上面这张图，每个对象的isa都存的是Class的内存地址，Class是在main函数执行之前就加载进内存的，并且由Runtime所管理。所以只需要构造一个指向Class的指针，即isa，就可以成为一个对象。

而对象的属性，就是在对象的首地址上进行的偏移。如上图，当知道对象的首地址是0x7fff562eea98，那么偏移8个字节就到了isa，再偏移8个字节就到了name属性了。对象的属性就是在内存中偏移寻址取值的过程。


#### 四.对象的销毁


![](https://img.halfrost.com/Blog/ArticleImage/30_7.png)



对象的销毁就是调用dealloc方法。

```objectivec


- (void)dealloc {
    _objc_rootDealloc(self);
}

```

dealloc方法会调用\_objc\_rootDealloc方法

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

如果是TaggedPointer，直接return。

indexed是代表是否开启isa指针优化。weakly\_referenced代表对象被指向或者曾经指向一个 ARC 的弱变量。has\_assoc代表对象含有或者曾经含有关联引用。has\_cxx\_dtor之前提到过了，是析构器。has\_sidetable\_rc判断该对象的引用计数是否过大。


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

object\_dispose会调用objc\_destructInstance。


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

销毁一个对象，靠的是底层的C++析构函数完成的。还需要移除associative的引用。

接下来就依次详细看看销毁对象的3个方法。

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

从子类开始沿着继承链一直找到父类，向上搜寻SEL\_cxx\_destruct
这个selector，找到函数实现(void (*)(id)(函数指针)并执行。

以下引用[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)的内容：

从[这篇文章](http://my.safaribooksonline.com/book/programming/objective-c/9780132908641/3dot-memory-management/ch03)中：
>ARC actually creates a -.cxx_destruct method to handle freeing instance variables. This method was originally created for calling C++ destructors automatically when an object was destroyed.

和《Effective Objective\-C 2.0》中提到的：
>When the compiler saw that an object contained C++ objects, it would generate a method called .cxx_destruct. ARC piggybacks on this method and emits the required cleanup code within it.

可以了解到，\.cxx\_destruct方法原本是为了C++对象析构的，ARC借用了这个方法插入代码实现了自动内存释放的工作。

在ARC中dealloc方法在最后一次release后被调用，但此时实例变量（Ivars）并未释放，**父类的dealloc的方法将在子类dealloc方法返回后自动调用**。ARC下对象的实例变量在根类[NSObject dealloc]中释放（通常root class都是NSObject），变量释放顺序各种不确定（一个类内的不确定，子类和父类间也不确定，也就是说不用care释放顺序）


经过@sunnyxx文中的研究：
1.ARC下对象的成员变量于编译器插入的\.cxx\_desctruct方法自动释放。
2.ARC下[super dealloc]方法也由编译器自动插入。


至于\.cxx\_destruct方法的实现，还请看@sunnyxx 那篇文章里面详细的分析。


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

在移除关联对象object的时候，会先去判断object的isa\_t中的第二位has\_assoc的值，当object 存在并且object\->hasAssociatedObjects( )值为1的时候，才会去调用_object\_remove\_assocations方法。

\_object\_remove\_assocations方法的目的是删除第二张ObjcAssociationMap表，即删除所有的关联对象。删除第二张表，就需要在第一张AssociationsHashMap表中遍历查找。这里会把第二张ObjcAssociationMap表中所有的ObjcAssociation对象都存到一个数组elements里面，然后调用associations.erase( )删除第二张表。最后再遍历elements数组，把ObjcAssociation对象依次释放。

这里移除的方式和Associated Object关联对象里面的remove方法是完全一样的。


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


这里涉及到了2个clear函数，接下来一个个的看。

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

遍历SideTable，循环调用weak\_clear\_no\_lock函数。


weakly_referenced代表对象被指向或者曾经指向一个 ARC 的弱变量。has_sidetable_rc判断该对象的引用计数是否过大。如果其中有一个为YES，则调用clearDeallocating\_slow()方法。

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

clearDeallocating\_slow也会最终调用weak\_clear\_no\_lock方法。




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

这个函数会在weak\_table中，清空引用计数表并清除弱引用表，将所有weak引用指nil。


#### 总结

![](https://img.halfrost.com/Blog/ArticleImage/30_8.png)




这篇文章详细的分析了objc对象 从 出生 到 最终销毁，它的今生今世全部在此。还请大家多多指点。

