# ReactiveCocoa 中 集合类 RACSequence 和 RACTuple 底层实现分析

![](https://img.halfrost.com/Blog/ArticleTitleImage/36_0_.png)



### 前言

在OOP的世界里使用FRP的思想来编程，光有函数这种一等公民，还是无法满足我们一些需求的。因此还是需要引用变量来完成各式各样的类的操作行为。

在前几篇文章中详细的分析了RACStream中RACSignal的底层实现。RACStream还有另外一个子类，RACSequence，这个类是RAC专门为集合而设计的。这篇文章就专门分析一下RACSequence的底层实现。



### 目录

- 1.RACTuple底层实现分析
- 2.RACSequence底层实现分析
- 3.RACSequence操作实现分析
- 4.RACSequence的一些扩展



### 一. RACTuple底层实现分析

在分析RACSequence之前，先来看看RACTuple的实现。RACTuple是ReactiveCocoa的元组类。

![](https://img.halfrost.com/Blog/ArticleImage/36_1.png)







#### 1. RACTuple

```objectivec


@interface RACTuple : NSObject <NSCoding, NSCopying, NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;

@property (nonatomic, readonly) id first;
@property (nonatomic, readonly) id second;
@property (nonatomic, readonly) id third;
@property (nonatomic, readonly) id fourth;
@property (nonatomic, readonly) id fifth;
@property (nonatomic, readonly) id last;
@property (nonatomic, strong) NSArray *backingArray;

@property (nonatomic, copy, readonly) RACSequence *rac_sequence; // 这个是专门为sequence提供的一个扩展

@end

```


RACTuple的定义看上去很简单，底层实质就是一个NSArray，只不过封装了一些方法。RACTuple继承了NSCoding, NSCopying, NSFastEnumeration这三个协议。


```objectivec

- (id)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self == nil) return nil;
    
    self.backingArray = [coder decodeObjectForKey:@keypath(self.backingArray)];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.backingArray != nil) [coder encodeObject:self.backingArray forKey:@keypath(self.backingArray)];
}

```

这里是NSCoding协议。都是对内部的backingArray进行decodeObjectForKey:和encodeObject: 。


```objectivec

- (instancetype)copyWithZone:(NSZone *)zone {
   // we're immutable, bitches!    <---这里是原作者的注释
   return self;
}

```

上面这是NSCopying协议。由于内部是基于NSArray的，所以是immutable不可变的。


```objectivec

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    return [self.backingArray countByEnumeratingWithState:state objects:buffer count:len];
}

```

上面是NSFastEnumeration协议，快速枚举也都是针对NSArray进行的操作。



```objectivec

// 三个类方法
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array;
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert;
+ (instancetype)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;


- (id)objectAtIndex:(NSUInteger)index;
- (NSArray *)allObjects;
- (instancetype)tupleByAddingObject:(id)obj;

```

RACTuple的方法也不多，总共就6个方法，3个类方法，3个实例方法。

先看类方法：

```objectivec


+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array {
    return [self tupleWithObjectsFromArray:array convertNullsToNils:NO];
}

+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert {
    RACTuple *tuple = [[self alloc] init];
    
    if (convert) {
        NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
        for (id object in array) {
            [newArray addObject:(object == NSNull.null ? RACTupleNil.tupleNil : object)];
        }       
        tuple.backingArray = newArray;
    } else {
        tuple.backingArray = [array copy];
    }
    
    return tuple;
}

```

先看这两个类方法，这两个类方法的区别在于是否把NSNull转换成RACTupleNil类型。根据入参array初始化RACTuple内部的NSArray。

![](https://img.halfrost.com/Blog/ArticleImage/36_2.png)




RACTuplePack( ) 和 RACTuplePack\_( )这两个宏的实现也是调用了tupleWithObjectsFromArray:方法

```objectivec

#define RACTuplePack(...) \
    RACTuplePack_(__VA_ARGS__)

#define RACTuplePack_(...) \
    ([RACTuple tupleWithObjectsFromArray:@[ metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) ]])


```


这里需要注意的是RACTupleNil

```objectivec

+ (RACTupleNil *)tupleNil {
    static dispatch_once_t onceToken;
    static RACTupleNil *tupleNil = nil;
    dispatch_once(&onceToken, ^{
        tupleNil = [[self alloc] init];
    });
    
    return tupleNil;
}

```

RACTupleNil是一个单例。


重点需要解释的是另外一种类方法：

```objecitvec


+ (instancetype)tupleWithObjects:(id)object, ... {
    RACTuple *tuple = [[self alloc] init];
    
    va_list args;
    va_start(args, object);
    
    NSUInteger count = 0;
    for (id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
        ++count;
    }
    
    va_end(args);
    
    if (count == 0) {
        tuple.backingArray = @[];
        return tuple;
    }
    
    NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:count];
    
    va_start(args, object);
    for (id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
        [objects addObject:currentObject];
    }
    
    va_end(args);
    
    tuple.backingArray = objects;
    return tuple;
}
```


这个类方法的参数是可变参数类型。由于用到了可变参数类型，所以就会用到va\_list，va\_start，va\_arg，va\_end。


```objectivec

#ifndef _VA_LIST_T
#define _VA_LIST_T
typedef __darwin_va_list va_list;
#endif /* _VA_LIST_T */

#ifndef _VA_LIST
typedef __builtin_va_list va_list;
#define _VA_LIST
#endif
#define va_start(ap, param) __builtin_va_start(ap, param)
#define va_end(ap)          __builtin_va_end(ap)
#define va_arg(ap, type)    __builtin_va_arg(ap, type)

```

1. va\_list用于声明一个变量，我们知道函数的可变参数列表其实就是一个字符串，所以va\_list才被声明为字符型指针，这个类型用于声明一个指向参数列表的字符型指针变量，例如：va\_list ap;//ap:arguement pointer
2. va\_start(ap,v),它的第一个参数是指向可变参数字符串的变量，第二个参数是可变参数函数的第一个参数，通常用于指定可变参数列表中参数的个数。
3. va\_arg(ap,t),它的第一个参数指向可变参数字符串的变量，第二个参数是可变参数的类型。
4. va\_end(ap) 用于将存放可变参数字符串的变量清空（赋值为NULL)。


剩下的3个实例方法都是对数组的操作，没有什么难度。

一般使用用两个宏，RACTupleUnpack( ) 用来解包，RACTuplePack( ) 用来装包。

```objectivec

   RACTupleUnpack(NSString *string, NSNumber *num) = [RACTuple tupleWithObjects:@"foo", @5, nil];

 
   RACTupleUnpack(NSString *string, NSNumber *num) = RACTuplePack(@"foo",@(5));

   NSLog(@"string: %@", string);
   NSLog(@"num: %@", num);

   /* 上面的做法等价于下面的 */
   RACTuple *t = [RACTuple tupleWithObjects:@"foo", @5, nil];
   NSString *string = t[0];
   NSNumber *num = t[1];
   NSLog(@"string: %@", string);
   NSLog(@"num: %@", num);


```



关于RACTuple还有2个相关的类，RACTupleUnpackingTrampoline，RACTupleSequence。

#### 2. RACTupleUnpackingTrampoline

```objectivec


@interface RACTupleUnpackingTrampoline : NSObject
+ (instancetype)trampoline;
- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables;
@end

```

首先这个类是一个单例。

```objectivec

+ (instancetype)trampoline {
    static dispatch_once_t onceToken;
    static id trampoline = nil;
    dispatch_once(&onceToken, ^{
        trampoline = [[self alloc] init];
    });    
    return trampoline;
}


```

RACTupleUnpackingTrampoline这个类也就只有一个作用，就是它对应的实例方法。


```objectivec

- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables {
    NSCParameterAssert(variables != nil);
    
    [variables enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger index, BOOL *stop) {
        __strong id *ptr = (__strong id *)value.pointerValue;
        *ptr = tuple[index];
    }];
}

```

这个方法里面会遍历入参数组NSArray，然后依次取出数组里面每个value 的指针，用这个指针又赋值给了tuple[index]。

为了解释清楚这个方法的作用，写出测试代码：

```objectivec

    RACTupleUnpackingTrampoline *tramp = [RACTupleUnpackingTrampoline trampoline];
    
    NSString *string;
    NSString *string1;
    NSString *string2;
    
    NSArray *array = [NSArray arrayWithObjects:[NSValue valueWithPointer:&string],[NSValue valueWithPointer:&string1],[NSValue valueWithPointer:&string2], nil];
    
    NSLog(@"调用方法之前 string = %@,string1 = %@,string2 = %@",string,string1,string2);
    
    [tramp setObject:[RACTuple tupleWithObjectsFromArray:@[(@"foo"),(@(10)),@"32323"]] forKeyedSubscript:array];
    
    NSLog(@"调用方法之后 string = %@,string1 = %@,string2 = %@",string,string1,string2);


```

输出如下：

```vim

调用方法之前 string = (null),string1 = (null),string2 = (null)
调用方法之后 string = foo,string1 = 10,string2 = 32323


```

这个函数的作用也就一清二楚了。但是平时我们是很少用到[NSValue valueWithPointer:&string]这种写法的。究竟是什么地方会用到这个函数呢？全局搜索一下，找到了用到这个的地方。


在RACTuple 中两个非常有用的宏：RACTupleUnpack( ) 用来解包，RACTuplePack( ) 用来装包。RACTuplePack( )的实现在上面分析过了，实际是调用tupleWithObjectsFromArray:方法。那么RACTupleUnpack( ) 的宏是怎么实现的呢？这里就用到了RACTupleUnpackingTrampoline。


![](https://img.halfrost.com/Blog/ArticleImage/36_3.png)





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


以上就是RACTupleUnpack( ) 具体的宏。看上去很复杂。还是写出测试代码分析分析。

```objectivec

    RACTupleUnpack(NSString *string, NSNumber *num) = RACTuplePack(@"foo",@(10));


```

把上述的代码编译之后的代码贴出来：


```objectivec

    __attribute__((objc_ownership(strong))) id RACTupleUnpack284_var0;
    __attribute__((objc_ownership(strong))) id RACTupleUnpack284_var1;
    
    int RACTupleUnpack_state284 = 0;
    RACTupleUnpack_after284: ;
    __attribute__((objc_ownership(strong))) NSString *string = RACTupleUnpack284_var0;
    __attribute__((objc_ownership(strong))) NSNumber *num = RACTupleUnpack284_var1;
    
    if (RACTupleUnpack_state284 != 0)
        RACTupleUnpack_state284 = 2;
    
    while (RACTupleUnpack_state284 != 2)
        if (RACTupleUnpack_state284 == 1) {
            goto RACTupleUnpack_after284;
        } else for (; RACTupleUnpack_state284 != 1; RACTupleUnpack_state284 = 1)
            [RACTupleUnpackingTrampoline trampoline][ @[ [NSValue valueWithPointer:&RACTupleUnpack284_var0], [NSValue valueWithPointer:&RACTupleUnpack284_var1], ] ] = ([RACTuple tupleWithObjectsFromArray:@[ (@"foo") ?: RACTupleNil.tupleNil, (@(10)) ?: RACTupleNil.tupleNil, ]]);

```


转换成这样就比较好理解了。RACTupleUnpack\_after284: 是一个标号。RACTupleUnpack\_state284初始值为0，在下面while里面有一个for循环，在这个循环里面会进行解包操作，也就是会调用setObject:forKeyedSubscript:函数。

在循环里面，

```objectivec

[RACTupleUnpackingTrampoline trampoline][ @[ [NSValue valueWithPointer:&RACTupleUnpack284_var0], [NSValue valueWithPointer:&RACTupleUnpack284_var1], ] ]


```

这里就是调用了[NSValue valueWithPointer:&string]的写法。


至此，RACTupleUnpackingTrampoline这个类的作用也已明了，它是被作用设计出来用来实现神奇的RACTupleUnpack( ) 这个宏。

当然RACTupleUnpackingTrampoline这个类的setObject:forKeyedSubscript:函数也可以使用，只不过要注意写法，注意指针的类型，在NSValue里面包裹的是valueWithPointer，(nullable const void *)pointer类型的。


#### 3. RACTupleSequence

这个类仅仅只是名字里面带有Tuple而已，它其实是继承自RACSequence。


需要分析这个类的原因是因为RACTuple里面有一个拓展的属性rac\_sequence。

```objectivec

- (RACSequence *)rac_sequence {
   return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

```


还是先看看RACTupleSequence的定义。

```objectivec

@interface RACTupleSequence : RACSequence
@property (nonatomic, strong, readonly) NSArray *tupleBackingArray;
@property (nonatomic, assign, readonly) NSUInteger offset;
+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset;
@end

```


这个类是继承自RACSequence，而且只有这一个类方法。

tupleBackingArray是来自于RACTuple里面的backingArray。



```objectivec

+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset {
    NSCParameterAssert(offset <= backingArray.count);
    
    if (offset == backingArray.count) return self.empty;
    
    RACTupleSequence *seq = [[self alloc] init];
    seq->_tupleBackingArray = backingArray;
    seq->_offset = offset;
    return seq;
}


```

RACTupleSequence这个类的目的就是把Tuple转换成Sequence。Sequence里面的数组就是Tuple内部的backingArray。offset从0开始。


### 二. RACSequence底层实现分析


![](https://img.halfrost.com/Blog/ArticleImage/36_4.png)




```objectivec

@interface RACSequence : RACStream <NSCoding, NSCopying, NSFastEnumeration>

@property (nonatomic, strong, readonly) id head;
@property (nonatomic, strong, readonly) RACSequence *tail;
@property (nonatomic, copy, readonly) NSArray *array;
@property (nonatomic, copy, readonly) NSEnumerator *objectEnumerator;
@property (nonatomic, copy, readonly) RACSequence *eagerSequence;
@property (nonatomic, copy, readonly) RACSequence *lazySequence;
@end

```

RACSequence是RACStream的子类，主要是ReactiveCocoa里面的集合类。

先来说说关于RACSequence的一些概念。


RACSequence有两个很重要的属性就是head和tail。head是一个id，而tail又是一个RACSequence，这个定义有点递归的意味。





```objectivec

    RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^id{
        return @(1);
    } tailBlock:^RACSequence *{
        return @[@2,@3,@4].rac_sequence;
    }];
    
    NSLog(@"sequence.head = %@ , sequence.tail =  %@",sequence.head ,sequence.tail);


```

输出：

```vim

sequence.head = 1 , sequence.tail =  <RACArraySequence: 0x608000223920>{ name = , array = (
    2,
    3,
    4
) }


```

这段测试代码就道出了head和tail的定义。更加详细的描述见下图：


![](https://img.halfrost.com/Blog/ArticleImage/36_5.png)


上述代码里面用到了RACSequence初始化的方法，具体的分析见后面。

objectEnumerator是一个快速枚举器。

```objectivec


@interface RACSequenceEnumerator : NSEnumerator
@property (nonatomic, strong) RACSequence *sequence;
@end

```

之所以需要实现这个，是为了更加方便的RACSequence进行遍历。

```objectivec

- (id)nextObject {
    id object = nil;
    
    @synchronized (self) {
        object = self.sequence.head;
        self.sequence = self.sequence.tail;
    }
    
    return object;
}

```

有了这个NSEnumerator，就可以从RACSequence的head一直遍历到tail。


```objectivec

- (NSEnumerator *)objectEnumerator {
    RACSequenceEnumerator *enumerator = [[RACSequenceEnumerator alloc] init];
    enumerator.sequence = self;
    return enumerator;
}

```

回到RACSequence的定义里面的objectEnumerator，这里就是取出内部的RACSequenceEnumerator。


```objectivec

- (NSArray *)array {
    NSMutableArray *array = [NSMutableArray array];
    for (id obj in self) {
        [array addObject:obj];
    }   
    return [array copy];
}

```

RACSequence的定义里面还有一个array，这个数组就是返回一个NSArray，这个数组里面装满了RACSequence里面所有的对象。这里之所以能用for-in，是因为实现了NSFastEnumeration协议。至于for-in的效率，完全就看重写NSFastEnumeration协议里面countByEnumeratingWithState: objects:  count: 方法里面的执行效率了。

在分析RACSequence的for-in执行效率之前，先回顾一下NSFastEnumerationState的定义，这里的属性在接下来的实现中会被大量使用。

```objectivec

typedef struct {
    unsigned long state; //可以被自定义成任何有意义的变量
    id __unsafe_unretained _Nullable * _Nullable itemsPtr;  //返回对象数组的首地址
    unsigned long * _Nullable mutationsPtr;  //指向会随着集合变动而变化的一个值
    unsigned long extra[5]; //可以被自定义成任何有意义的数组
} NSFastEnumerationState;

```

接下来要分析的这个函数的入参，stackbuf是为for-in提供的对象数组，len是该数组的长度。

```objectivec

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
    // 定义完成时候的状态为state = ULONG_MAX
    if (state->state == ULONG_MAX) {
        return 0;
    }
    
    // 由于我们需要遍历sequence多次，所以这里定义state字段来记录sequence的首地址
    RACSequence *(^getSequence)(void) = ^{
        return (__bridge RACSequence *)(void *)state->state;
    };
    
    void (^setSequence)(RACSequence *) = ^(RACSequence *sequence) {
        // 释放老的sequence
        CFBridgingRelease((void *)state->state);
        // 保留新的sequence，把sequence的首地址存放入state中
        state->state = (unsigned long)CFBridgingRetain(sequence);
    };
    
    void (^complete)(void) = ^{
        // 释放sequence，并把state置为完成态
        setSequence(nil);
        state->state = ULONG_MAX;
    };
    
    // state == 0是第一次调用时候的初始值
    if (state->state == 0) {
        // 在遍历过程中，如果Sequence不再发生变化，那么就让mutationsPtr指向一个定值，指向extra数组的首地址
        state->mutationsPtr = state->extra;
        // 再次刷新state的值
        setSequence(self);
    }
    
    // 将会把返回的对象放进stackbuf中，因此用itemsPtr指向它
    state->itemsPtr = stackbuf;
    
    NSUInteger enumeratedCount = 0;
    while (enumeratedCount < len) {
        RACSequence *seq = getSequence();
        // 由于sequence可能是懒加载生成的，所以需要防止在遍历器enumerator遍历到它们的时候被释放了

        __autoreleasing id obj = seq.head;

        // 没有头就结束遍历
        if (obj == nil) {
            complete();
            break;
        }
        // 遍历sequence，每次取出来的head都放入stackbuf数组中。
        stackbuf[enumeratedCount++] = obj;
        
        // 没有尾就是完成遍历
        if (seq.tail == nil) {
            complete();
            break;
        }
        
        // 取出tail以后，这次遍历结束的tail，即为下次遍历的head，设置seq.tail为Sequence的head，为下次循环做准备
        setSequence(seq.tail);
    }
    
    return enumeratedCount;
}


```

整个遍历的过程类似递归的过程，从头到尾依次遍历一遍。


再来研究研究RACSequence的初始化：

```objectivec

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
   return [[RACDynamicSequence sequenceWithHeadBlock:headBlock tailBlock:tailBlock] setNameWithFormat:@"+sequenceWithHeadBlock:tailBlock:"];
}

```

初始化RACSequence，会调用RACDynamicSequence。这里有点类比RACSignal的RACDynamicSignal。



再来看看RACDynamicSequence的定义。

```objectivec

@interface RACDynamicSequence () {
    id _head;
    RACSequence *_tail;
    id _dependency;
}
@property (nonatomic, strong) id headBlock;
@property (nonatomic, strong) id tailBlock;
@property (nonatomic, assign) BOOL hasDependency;
@property (nonatomic, strong) id (^dependencyBlock)(void);

@end


```


这里需要说明的是此处的headBlock，tailBlock，dependencyBlock的修饰符都是用了strong，而不是copy。这里是一个很奇怪的bug导致的。在[https://github.com/ReactiveCocoa/ReactiveCocoa/issues/505](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/505)中详细记录了用copy关键字会导致内存泄露的bug。具体代码如下：

```objectivec

[[[@[@1,@2,@3,@4,@5] rac_sequence] filter:^BOOL(id value) {
    return [value intValue] > 1;
}] array];

```

最终发现这个问题的人把copy改成strong就神奇的修复了这个bug。最终整个ReactiveCocoa库里面就只有这里把block的关键字从copy改成了strong，而不是所有的地方都改成strong。

原作者[Justin Spahr-Summers](https://github.com/jspahrsummers)大神对这个问题的[最终解释](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/506)是：

>Maybe there's just something weird with how we override dealloc, set the blocks from a class method, cast them, or something else.

所以日常我们写block的时候，没有特殊情况，依旧需要继续用copy进行修饰。


```objectivec

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
   NSCParameterAssert(headBlock != nil);

   RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
   seq.headBlock = [headBlock copy];
   seq.tailBlock = [tailBlock copy];
   seq.hasDependency = NO;
   return seq;
}

```


hasDependency这个变量是代表是否有dependencyBlock。这个函数里面就只把headBlock和tailBlock保存起来了。

```objectivec

+ (RACSequence *)sequenceWithLazyDependency:(id (^)(void))dependencyBlock headBlock:(id (^)(id dependency))headBlock tailBlock:(RACSequence *(^)(id dependency))tailBlock {
    NSCParameterAssert(dependencyBlock != nil);
    NSCParameterAssert(headBlock != nil);
    
    RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
    seq.headBlock = [headBlock copy];
    seq.tailBlock = [tailBlock copy];
    seq.dependencyBlock = [dependencyBlock copy];
    seq.hasDependency = YES;
    return seq;
}

```

另外一个类方法sequenceWithLazyDependency: headBlock: tailBlock:是带有dependencyBlock的，这个方法里面会保存headBlock，tailBlock，dependencyBlock这3个block。

从RACSequence这两个唯一的初始化方法之间就引出了RACSequence两大核心问题之一，积极运算 和 惰性求值。


#### 1. 积极运算 和 惰性求值


在RACSequence的定义中还有两个RACSequence —— eagerSequence 和 lazySequence。这两个RACSequence就是分别对应着积极运算的RACSequence和惰性求值的RACSequence。

关于这两个概念最最新形象的比喻还是臧老师博客里面的这篇文章[聊一聊iOS开发中的惰性计算](http://williamzang.com/blog/2016/11/07/liao-yi-liao-ioskai-fa-zhong-de-duo-xing-ji-suan/)里面写的一段笑话。引入如下：

>有一只小白兔，跑到蔬菜店里问老板：“老板，有100个胡萝卜吗？”。老板说：“没有那么多啊。”，小白兔失望的说道：“哎，连100个胡萝卜都没有。。。”。第二天小白兔又来到蔬菜店问老板：“今天有100个胡萝卜了吧？”，老板尴尬的说：“今天还是缺点，明天就能好了。”，小白兔又很失望的走了。第三天小白兔刚一推门，老板就高兴的说道：“有了有了，从前天就进货的100个胡萝卜到货了。”，小白兔说：“太好了，我要买2根！”。。。

如果日常我们遇到了这种问题，就很浪费内存空间了。比如在内存里面开了一个100W大小的数组，结果实际只使用到100个数值。这个时候就需要用到惰性运算了。

在RACSequence里面这两种方式都支持，我们来看看底层源码是如何实现的。


先来看看平时我们很熟悉的情况——积极运算。

![](https://img.halfrost.com/Blog/ArticleImage/36_6.png)




在RACSequence中积极运算的代表是RACSequence的一个子类RACArraySequence的子类——RACEagerSequence。它的积极运算表现在其bind函数上。

```objectivec

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
    NSCParameterAssert(block != nil);
    RACStreamBindBlock bindBlock = block();
    NSArray *currentArray = self.array;
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:currentArray.count];
    
    for (id value in currentArray) {
        BOOL stop = NO;
        RACSequence *boundValue = (id)bindBlock(value, &stop);
        if (boundValue == nil) break;
        
        for (id x in boundValue) {
            [resultArray addObject:x];
        }
        
        if (stop) break;
    }
    
    return [[self.class sequenceWithArray:resultArray offset:0] setNameWithFormat:@"[%@] -bind:", self.name];
}




```


从上述代码中能看到主要是进行了2层循环，最外层循环遍历的自己RACSequence中的值，然后拿到这个值传入闭包bindBlock( )中，返回一个RACSequence，最后用一个NSMutableArray依次把每个RACSequence里面的值都装起来。

第二个for-in循环是在遍历RACSequence，之所以可以用for-in的方式遍历就是因为实现了NSFastEnumeration协议，实现了countByEnumeratingWithState: objects: count: 方法，这个方法在上面详细分析过了，这里不再赘述。

这里就是一个积极运算的例子，在每次循环中都会把闭包block( )的值计算出来。值得说明的是，最后返回的RACSequence的类型是self.class类型的，即还是RACEagerSequence类型的。


再来看看RACSequence中的惰性求值是怎么实现的。

在RACSequence中，bind函数是下面这个样子：

```objectivec

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
    RACStreamBindBlock bindBlock = block();
    return [[self bind:bindBlock passingThroughValuesFromSequence:nil] setNameWithFormat:@"[%@] -bind:", self.name];
}

```

实际上调用了bind: passingThroughValuesFromSequence:方法，第二个入参传入nil。

```objectivec

- (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {

    __block RACSequence *valuesSeq = self;
    __block RACSequence *current = passthroughSequence;
    __block BOOL stop = NO;
    
    RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
        // 暂时省略
    } headBlock:^(id _) {
        return current.head;
    } tailBlock:^ id (id _) {
        if (stop) return nil;
        return [valuesSeq bind:bindBlock passingThroughValuesFromSequence:current.tail];
    }];
    
    sequence.name = self.name;
    return sequence;
}


```


在bind: passingThroughValuesFromSequence:方法的实现中，就是用sequenceWithLazyDependency: headBlock: tailBlock:方法生成了一个RACSequence，并返回。在sequenceWithLazyDependency: headBlock: tailBlock:上面分析过源码，主要目的是为了保存3个闭包，headBlock，tailBlock，dependencyBlock。

通过调用RACSequence里面的bind操作，并没有执行3个闭包里面的值，只是保存起来了。这里就是惰性求值的表现——等到要用的时候才会计算。

通过上述源码的分析，可以写出如下的测试代码加深理解。


```objectivec


    NSArray *array = @[@1,@2,@3,@4,@5];
    
    RACSequence *lazySequence = [array.rac_sequence map:^id(id value) {
        NSLog(@"lazySequence");
        return @(101);
    }];
    
    RACSequence *eagerSequence = [array.rac_sequence.eagerSequence map:^id(id value) {
        NSLog(@"eagerSequence");
        return @(100);
    }];


```

上述代码运行之后，会输出如下信息：

```vim

eagerSequence
eagerSequence
eagerSequence
eagerSequence
eagerSequence

```

只输出了5遍eagerSequence，lazySequence并没有输出。原因是因为bind闭包只在eagerSequence中真正被调用执行了，而在lazySequence中bind闭包仅仅只是被copy了。

那如何让lazySequence执行bind闭包呢？


```objectivec

    [lazySequence array];

```

通过执行上述代码，就可以输出5遍“lazySequence”了。因为bind闭包再次会被调用执行。


积极运算 和 惰性求值在这里就区分出来了。在RACSequence中，除去RACEagerSequence只积极运算，其他的Sequence都是惰性求值的。

接下来再继续分析RACSequence是如何实现惰性求值的。


![](https://img.halfrost.com/Blog/ArticleImage/36_7.png)





```objectivec

RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
    while (current.head == nil) {
        if (stop) return nil;
        
        // 遍历当前sequence，取出下一个值
        id value = valuesSeq.head;
        
        if (value == nil) {
            // 遍历完sequence所有的值
            stop = YES;
            return nil;
        }
        
        current = (id)bindBlock(value, &stop);
        if (current == nil) {
            stop = YES;
            return nil;
        }
        
        valuesSeq = valuesSeq.tail;
    }
    
    NSCAssert([current isKindOfClass:RACSequence.class], @"-bind: block returned an object that is not a sequence: %@", current);
    return nil;
} headBlock:^(id _) {
    return current.head;
} tailBlock:^ id (id _) {
    if (stop) return nil;
    
    return [valuesSeq bind:bindBlock passingThroughValuesFromSequence:current.tail];
}];

```

在bind操作中创建了这样一个lazySequence，3个block闭包保存了如何创建一个lazySequence的做法。

headBlock是入参为id，返回值也是一个id。在创建lazySequence的head的时候，并不关心入参，直接返回passthroughSequence的head。

tailBlock是入参为id，返回值为RACSequence。由于RACSequence的定义类似递归定义的，所以tailBlock会再次递归调用bind:passingThroughValuesFromSequence:产生一个RACSequence作为新的sequence的tail。

dependencyBlock的返回值是作为headBlock和tailBlock的入参。不过现在headBlock和tailBlock都不关心这个入参。那么dependencyBlock就是成为了headBlock和tailBlock闭包执行之前要执行的闭包。


dependencyBlock的目的是为了把原来的sequence里面的值，都进行一次变换。current是入参passthroughSequence，valuesSeq就是原sequence的引用。每次循环一次就取出原sequence的头，直到取不到为止，就是遍历完成。

取出valuesSeq的head，传入bindBlock( )闭包进行变换，返回值是一个current 的sequence。在每次headBlock和tailBlock之前都会调用这个dependencyBlock，变换后新的sequence的head就是current的head，新的sequence的tail就是递归调用传入的current.tail。


RACDynamicSequence创建的lazyDependency的过程就是保存了3个block的过程。那这些闭包什么时候会被调用呢？

```objectivec

- (id)head {
    @synchronized (self) {
        id untypedHeadBlock = self.headBlock;
        if (untypedHeadBlock == nil) return _head;
        
        if (self.hasDependency) {
            if (self.dependencyBlock != nil) {
                _dependency = self.dependencyBlock();
                self.dependencyBlock = nil;
            }
            
            id (^headBlock)(id) = untypedHeadBlock;
            _head = headBlock(_dependency);
        } else {
            id (^headBlock)(void) = untypedHeadBlock;
            _head = headBlock();
        }
        
        self.headBlock = nil;
        return _head;
    }
}


```

上面的源码就是获取RACDynamicSequence中head的实现。当要取出sequence的head的时候，就会调用headBlock( )。如果保存了dependencyBlock闭包，在执行headBlock( )之前会先执行dependencyBlock( )进行一次变换。


```objectivec

- (RACSequence *)tail {
    @synchronized (self) {
        id untypedTailBlock = self.tailBlock;
        if (untypedTailBlock == nil) return _tail;
        
        if (self.hasDependency) {
            if (self.dependencyBlock != nil) {
                _dependency = self.dependencyBlock();
                self.dependencyBlock = nil;
            }
            
            RACSequence * (^tailBlock)(id) = untypedTailBlock;
            _tail = tailBlock(_dependency);
        } else {
            RACSequence * (^tailBlock)(void) = untypedTailBlock;
            _tail = tailBlock();
        }
        
        if (_tail.name == nil) _tail.name = self.name;
        
        self.tailBlock = nil;
        return _tail;
    }
}


```


获取RACDynamicSequence中tail的时候，和获取head是一样的，当需要取出tail的时候才会调用tailBlock( )。当有dependencyBlock闭包，会先执行dependencyBlock闭包，再调用tailBlock( )。


**总结一下：**  

1. RACSequence的惰性求值，除去RACEagerSequence的bind函数以外，其他所有的Sequence都是基于惰性求值的。只有到取出来运算之前才会去把相应的闭包执行一遍。  
2. 在RACSequence所有函数中，只有bind函数会传入dependencyBlock( )闭包，（RACEagerSequence会重写这个bind函数），所以看到dependencyBlock( )闭包一定可以推断出是RACSequence做了变换操作了。



#### 2. Pull-driver 和 Push-driver

![](https://img.halfrost.com/Blog/ArticleImage/36_8.png)




在RACSequence中有一个方法可以让RACSequence和RACSignal进行关联上。





```objectivec


- (RACSignal *)signal {
    return [[self signalWithScheduler:[RACScheduler scheduler]] setNameWithFormat:@"[%@] -signal", self.name];
}

- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler {
    return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        __block RACSequence *sequence = self;
        
        return [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
            if (sequence.head == nil) {
                [subscriber sendCompleted];
                return;
            }            
            [subscriber sendNext:sequence.head];           
            sequence = sequence.tail;
            reschedule();
        }];
    }] setNameWithFormat:@"[%@] -signalWithScheduler: %@", self.name, scheduler];
}

```

RACSequence中的signal方法会调用signalWithScheduler:方法。在signalWithScheduler:方法中会创建一个新的信号。这个新的信号的RACDisposable信号由scheduleRecursiveBlock:产生。

```objectivec


- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable {
    @autoreleasepool {
        RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
        [disposable addDisposable:selfDisposable];
        
        __weak RACDisposable *weakSelfDisposable = selfDisposable;
        
        RACDisposable *schedulingDisposable = [self schedule:^{
     
            if (disposable.disposed) return;
            
            void (^reallyReschedule)(void) = ^{
                if (disposable.disposed) return;          
                // 这里是递归
                [self scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable];
            };
            
            // 这里实际上不需要__block关键字，但是由于Clang编译器的特性，为了保护下面的变量，所以加上了__block关键字
            __block NSLock *lock = [[NSLock alloc] init];
            lock.name = [NSString stringWithFormat:@"%@ %s", self, sel_getName(_cmd)];
            
            __block NSUInteger rescheduleCount = 0;
            
            // 一旦同步操作执行完成，rescheduleImmediately就应该被设为YES
            __block BOOL rescheduleImmediately = NO;
            
            @autoreleasepool {
                recursiveBlock(^{
                    [lock lock];
                    BOOL immediate = rescheduleImmediately;
                    if (!immediate) ++rescheduleCount;
                    [lock unlock];
                    
                    if (immediate) reallyReschedule();
                });
            }
            
            [lock lock];
            NSUInteger synchronousCount = rescheduleCount;
            rescheduleImmediately = YES;
            [lock unlock];
            
            for (NSUInteger i = 0; i < synchronousCount; i++) {
                reallyReschedule();
            }
        }];
        
        [selfDisposable addDisposable:schedulingDisposable];
    }
}

```


这段代码虽然长，但是拆分分析一下：

```objectivec

__block NSUInteger rescheduleCount = 0; 

// 一旦同步操作执行完成，rescheduleImmediately就应该被设为YES 
__block BOOL rescheduleImmediately = NO;

```

rescheduleCount 是递归次数计数。rescheduleImmediately这个BOOL是决定是否立即执行reallyReschedule( )闭包。


recursiveBlock是入参，它实际是下面这段闭包代码：

```objectivec

{
   if (sequence.head == nil) {
    [subscriber sendCompleted];
    return;
   }

   [subscriber sendNext:sequence.head];

   sequence = sequence.tail;
   reschedule();
  }

```

recursiveBlock的入参是reschedule( )。执行完上面的代码之后开始执行入参reschedule( )的代码，入参reschedule( 闭包的代码是如下：

```objectivec

    ^{
            [lock lock];
            BOOL immediate = rescheduleImmediately;
            if (!immediate) ++rescheduleCount;
            [lock unlock];
                    
            if (immediate) reallyReschedule();
    }

```

在这段block中会统计rescheduleCount，如果rescheduleImmediately为YES还会继续开始执行递归操作reallyReschedule( )。


```objectivec

   for (NSUInteger i = 0; i < synchronousCount; i++) {
    reallyReschedule();
   }

```

最终会在这个循环里面递归调用reallyReschedule( )闭包。reallyReschedule( )闭包执行的操作就是再次执行scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable方法。

每次执行一次递归就会取出sequence的head值发送出来，直到sequence.head = = nil发送完成信号。


既然RACSequence也可以转换成RACSignal，那么就需要总结一下两者的异同点。

**总结一下：**

RACSequence 和 RACSignal 异同点对比：

![](https://img.halfrost.com/Blog/ArticleImage/36_9.png)




1. RACSequence除去RACEagerSequence，其他所有的都是基于惰性计算的，这和RACSignal是一样的。
2. RACSequence是在时间上是连续的，一旦把RACSequence变成signal，再订阅，会立即把所有的值一口气都发送出来。RACSignal是在时间上是离散的，当有事件到来的时候，才会发送出数据流。
3.  RACSequence是Pull-driver，由订阅者来决定是否发送值，只要订阅者订阅了，就会发送数据流。RACSignal是Push-driver，它发送数据流是不由订阅者决定的，不管有没有订阅者，它有离散事件产生了，就会发送数据流。
4. RACSequence发送的全是数据，RACSignal发送的全是事件。事件不仅仅包括数据，还包括事件的状态，比如说事件是否出错，事件是否完成。


### 三. RACSequence操作实现分析


![](https://img.halfrost.com/Blog/ArticleImage/36_10.png)




RACSequence还有以下几个操作。

```objectivec

- (id)foldLeftWithStart:(id)start reduce:(id (^)(id accumulator, id value))reduce;
- (id)foldRightWithStart:(id)start reduce:(id (^)(id first, RACSequence *rest))reduce;
- (BOOL)any:(BOOL (^)(id value))block;
- (BOOL)all:(BOOL (^)(id value))block;
- (id)objectPassingTest:(BOOL (^)(id value))block;

```

#### 1. foldLeftWithStart: reduce:

```objectivec


- (id)foldLeftWithStart:(id)start reduce:(id (^)(id, id))reduce {
    NSCParameterAssert(reduce != NULL);
    
    if (self.head == nil) return start;
    
    for (id value in self) {
        start = reduce(start, value);
    }
    
    return start;
}


```


这个函数传入了一个初始值start，然后依次循环执行reduce( )，循环之后，最终的值作为返回值返回。这个函数就是折叠函数，从左边折叠到右边。


#### 2. foldRightWithStart: reduce:

```objectivec


- (id)foldRightWithStart:(id)start reduce:(id (^)(id, RACSequence *))reduce {
    NSCParameterAssert(reduce != NULL);
    
    if (self.head == nil) return start;
    
    RACSequence *rest = [RACSequence sequenceWithHeadBlock:^{
        return [self.tail foldRightWithStart:start reduce:reduce];
    } tailBlock:nil];
    
    return reduce(self.head, rest);
}


```

这个函数和上一个foldLeftWithStart: reduce:是一样的，只不过方向是从右往左。


#### 3. objectPassingTest:

```objectivec

- (id)objectPassingTest:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);

    return [self filter:block].head;
}

```

objectPassingTest:里面会调用RACStream中的filter:函数，这个函数在前几篇文章分析过了。如果block(value)为YES，就代表通过了Test，那么就会返回value的sequence。取出head返回。


#### 4. any:

```objectivec

- (BOOL)any:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    return [self objectPassingTest:block] != nil;
}

```

any:会调用objectPassingTest:函数，如果不为nil就代表有value值通过了Test，有通过了value的就返回YES，反之返回NO。

#### 5. all:

```objectivec

- (BOOL)all:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    NSNumber *result = [self foldLeftWithStart:@YES reduce:^(NSNumber *accumulator, id value) {
        return @(accumulator.boolValue && block(value));
    }];
    
    return result.boolValue;
}

```

all:会从左往右依次对每个值进行block( ) Test，然后每个值依次进行&&操作。


#### 6. concat:


```objectivec

- (instancetype)concat:(RACStream *)stream {
    NSCParameterAssert(stream != nil);
    
    return [[[RACArraySequence sequenceWithArray:@[ self, stream ] offset:0]
             flatten]
            setNameWithFormat:@"[%@] -concat: %@", self.name, stream];
}


```

concat:的操作和RACSignal的作用是一样的。它会把原sequence和入参stream连接到一起，组合成一个高阶sequence，最后调用flatten“拍扁”。关于flatten的实现见前几篇RACStream里面的flatten实现分析。


#### 7. zipWith:

```objectivec

- (instancetype)zipWith:(RACSequence *)sequence {
    NSCParameterAssert(sequence != nil);
    
    return [[RACSequence
             sequenceWithHeadBlock:^ id {
                 if (self.head == nil || sequence.head == nil) return nil;
                 return RACTuplePack(self.head, sequence.head);
             } tailBlock:^ id {
                 if (self.tail == nil || [[RACSequence empty] isEqual:self.tail]) return nil;
                 if (sequence.tail == nil || [[RACSequence empty] isEqual:sequence.tail]) return nil;
                 
                 return [self.tail zipWith:sequence.tail];
             }]
            setNameWithFormat:@"[%@] -zipWith: %@", self.name, sequence];
}

```


由于sequence的定义是递归形式的，所以zipWith:也是递归来进行的。zipWith:新的sequence的head是原来2个sequence的head组合成RACTuplePack。新的sequence的tail是原来2个sequence的tail递归调用zipWith:。










### 四. RACSequence的一些扩展


![](https://img.halfrost.com/Blog/ArticleImage/36_11.png)

关于RACSequence有以下9个子类，其中RACEagerSequence是继承自RACArraySequence。这些子类看名字就知道sequence里面装的是什么类型的数据。RACUnarySequence里面装的是单元sequence。它只有head值，没有tail值。


![](https://img.halfrost.com/Blog/ArticleImage/36_12.png)


RACSequenceAdditions 总共有7个Category。这7个Category分别对iOS 里面的集合类进行了RACSequence的扩展，使我们能更加方便的使用RACSequence。

#### 1. NSArray+RACSequenceAdditions


```objectivec

@interface NSArray (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```

这个Category能把任意一个NSArray数组转换成RACSequence。

```objectivec

- (RACSequence *)rac_sequence {
 return [RACArraySequence sequenceWithArray:self offset:0];
}

```

根据NSArray创建一个RACArraySequence并返回。


#### 2. NSDictionary+RACSequenceAdditions

```objectivec

@interface NSDictionary (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@property (nonatomic, copy, readonly) RACSequence *rac_keySequence;
@property (nonatomic, copy, readonly) RACSequence *rac_valueSequence;
@end

```

这个Category能把任意一个NSDictionary字典转换成RACSequence。

```objectivec


- (RACSequence *)rac_sequence {
   NSDictionary *immutableDict = [self copy];
     return [immutableDict.allKeys.rac_sequence map:^(id key) {
      id value = immutableDict[key];
      return RACTuplePack(key, value);
   }];
}

- (RACSequence *)rac_keySequence {
   return self.allKeys.rac_sequence;
}

- (RACSequence *)rac_valueSequence {
   return self.allValues.rac_sequence;
}

```

rac\_sequence会把字典都转化为一个装满RACTuplePack的RACSequence，在这个RACSequence中，第一个位置是key，第二个位置是value。

rac\_keySequence是装满所有key的RACSequence。

rac\_valueSequence是装满所有value的RACSequence。


#### 3. NSEnumerator+RACSequenceAdditions

```objectivec

@interface NSEnumerator (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end


```

这个Category能把任意一个NSEnumerator转换成RACSequence。

```objectivec


- (RACSequence *)rac_sequence {
    return [RACSequence sequenceWithHeadBlock:^{
        return [self nextObject];
    } tailBlock:^{
        return self.rac_sequence;
    }];
}

```

返回的RACSequence的head是当前的sequence的head，tail就是当前的sequence。


#### 4. NSIndexSet+RACSequenceAdditions

```objectivec

@interface NSIndexSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end


```

这个Category能把任意一个NSIndexSet转换成RACSequence。


```objectivec


- (RACSequence *)rac_sequence {
    return [RACIndexSetSequence sequenceWithIndexSet:self];
}

+ (instancetype)sequenceWithIndexSet:(NSIndexSet *)indexSet {
    NSUInteger count = indexSet.count;
    if (count == 0) return self.empty;
    NSUInteger sizeInBytes = sizeof(NSUInteger) * count;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:sizeInBytes];
    [indexSet getIndexes:data.mutableBytes maxCount:count inIndexRange:NULL];
    
    RACIndexSetSequence *seq = [[self alloc] init];
    seq->_data = data;
    seq->_indexes = data.bytes;
    seq->_count = count;
    return seq;
}


```

返回RACIndexSetSequence，在这个IndexSetSequence中，data里面装的NSData，indexes里面装的NSUInteger，count里面装的是index的总数。


#### 5. NSOrderedSet+RACSequenceAdditions

```objectivec

@interface NSOrderedSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```

这个Category能把任意一个NSOrderedSet转换成RACSequence。



```objectivec

- (RACSequence *)rac_sequence {
    return self.array.rac_sequence;
}

```

返回的NSOrderedSet中的数组转换成sequence。


#### 6. NSSet+RACSequenceAdditions


```objectivec

@interface NSSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```

这个Category能把任意一个NSSet转换成RACSequence。

```objectivec

- (RACSequence *)rac_sequence {
   return self.allObjects.rac_sequence;
}

```

根据NSSet的allObjects数组创建一个RACArraySequence并返回。


#### 7. NSString+RACSequenceAdditions


```objectivec

@interface NSString (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```

这个Category能把任意一个NSString转换成RACSequence。



```objectivec

- (RACSequence *)rac_sequence {
    return [RACStringSequence sequenceWithString:self offset:0];
}


```

返回的是一个装满string字符的数组对应的sequence。



### 最后

关于RACSequence 和 RACTuple底层实现分析都已经分析完成。最后请大家多多指教。

