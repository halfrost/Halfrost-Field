# Analysis of the Underlying Implementation of the Collection Classes RACSequence and RACTuple in ReactiveCocoa

![](https://img.halfrost.com/Blog/ArticleTitleImage/36_0_.png)


### Preface

In the world of OOP, when programming with FRP ideas, having only functions as first-class citizens is still not enough to satisfy some of our requirements. Therefore, we still need to reference variables to complete all kinds of class operation behaviors.

In previous articles, we analyzed the underlying implementation of RACSignal in RACStream in detail. RACStream also has another subclass, RACSequence, which is designed by RAC specifically for collections. This article focuses on analyzing the underlying implementation of RACSequence.


### Table of Contents

- 1. Analysis of the Underlying Implementation of RACTuple
- 2. Analysis of the Underlying Implementation of RACSequence
- 3. Analysis of the Implementation of RACSequence Operations
- 4. Some Extensions of RACSequence


### 1. Analysis of the Underlying Implementation of RACTuple

Before analyzing RACSequence, let’s first look at the implementation of RACTuple. RACTuple is ReactiveCocoa’s tuple class.

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

@property (nonatomic, copy, readonly) RACSequence *rac_sequence; // This is an extension specifically provided for sequence

@end

```
The definition of RACTuple looks very simple; underneath, it is essentially just an NSArray, with a few methods wrapped around it. RACTuple conforms to the NSCoding, NSCopying, and NSFastEnumeration protocols.
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
This is the NSCoding protocol. Both call decodeObjectForKey: and encodeObject: on the internal backingArray.
```objectivec

- (instancetype)copyWithZone:(NSZone *)zone {
   // we're immutable, bitches!    <---this is the original author's comment
   return self;
}

```
The above is the `NSCopying` protocol. Since it is internally based on `NSArray`, it is immutable.
```objectivec

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    return [self.backingArray countByEnumeratingWithState:state objects:buffer count:len];
}

```
The above is the NSFastEnumeration protocol; fast enumeration is also performed on NSArray.
```objectivec

// Three class methods
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array;
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert;
+ (instancetype)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;


- (id)objectAtIndex:(NSUInteger)index;
- (NSArray *)allObjects;
- (instancetype)tupleByAddingObject:(id)obj;

```
RACTuple doesn't have many methods either—six in total: three class methods and three instance methods.

Let's look at the class methods first:
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
First, look at these two class methods. The difference between them is whether NSNull is converted into the RACTupleNil type. They initialize the internal NSArray of RACTuple based on the input array.

![](https://img.halfrost.com/Blog/ArticleImage/36_2.png)


The implementations of the two macros RACTuplePack( ) and RACTuplePack\_( ) also call the tupleWithObjectsFromArray: method.
```objectivec

#define RACTuplePack(...) \
    RACTuplePack_(__VA_ARGS__)

#define RACTuplePack_(...) \
    ([RACTuple tupleWithObjectsFromArray:@[ metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) ]])


```
What needs to be noted here is RACTupleNil.
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
`RACTupleNil` is a singleton.

The key point to explain is another class method:
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
The parameters of this class method are variadic. Because a variadic parameter type is used, `va_list`, `va_start`, `va_arg`, and `va_end` are involved.
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
1. va\_list is used to declare a variable. We know that a function’s variadic argument list is essentially a string, which is why va\_list is declared as a character pointer. This type is used to declare a character pointer variable that points to the argument list, for example: va\_list ap;//ap:argument pointer
2. va\_start(ap,v): its first parameter is the variable pointing to the variadic argument string, and its second parameter is the first parameter of the variadic function. It is usually used to specify the number of arguments in the variadic argument list.
3. va\_arg(ap,t): its first parameter is the variable pointing to the variadic argument string, and its second parameter is the type of the variadic argument.
4. va\_end(ap) is used to clear the variable that stores the variadic argument string by assigning it to NULL.

The remaining three instance methods are all array operations and are straightforward.

In general, two macros are used: RACTupleUnpack( ) for unpacking, and RACTuplePack( ) for packing.
```objectivec

   RACTupleUnpack(NSString *string, NSNumber *num) = [RACTuple tupleWithObjects:@"foo", @5, nil];

 
   RACTupleUnpack(NSString *string, NSNumber *num) = RACTuplePack(@"foo",@(5));

   NSLog(@"string: %@", string);
   NSLog(@"num: %@", num);

   /* The above approach is equivalent to the following */
   RACTuple *t = [RACTuple tupleWithObjects:@"foo", @5, nil];
   NSString *string = t[0];
   NSNumber *num = t[1];
   NSLog(@"string: %@", string);
   NSLog(@"num: %@", num);


```
There are two other classes related to RACTuple: RACTupleUnpackingTrampoline and RACTupleSequence.

#### 2. RACTupleUnpackingTrampoline
```objectivec


@interface RACTupleUnpackingTrampoline : NSObject
+ (instancetype)trampoline;
- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables;
@end

```
First, this class is a singleton.
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
The RACTupleUnpackingTrampoline class has only one purpose: the instance method it corresponds to.
```objectivec

- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables {
    NSCParameterAssert(variables != nil);
    
    [variables enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger index, BOOL *stop) {
        __strong id *ptr = (__strong id *)value.pointerValue;
        *ptr = tuple[index];
    }];
}

```
This method iterates over the input `NSArray`, then retrieves the pointer to each value in the array in order, and assigns that pointer to `tuple[index]`.

To clearly explain what this method does, here is some test code:
```objectivec

    RACTupleUnpackingTrampoline *tramp = [RACTupleUnpackingTrampoline trampoline];
    
    NSString *string;
    NSString *string1;
    NSString *string2;
    
    NSArray *array = [NSArray arrayWithObjects:[NSValue valueWithPointer:&string],[NSValue valueWithPointer:&string1],[NSValue valueWithPointer:&string2], nil];
    
    NSLog(@"Before calling method string = %@,string1 = %@,string2 = %@",string,string1,string2);
    
    [tramp setObject:[RACTuple tupleWithObjectsFromArray:@[(@"foo"),(@(10)),@"32323"]] forKeyedSubscript:array];
    
    NSLog(@"After calling method string = %@,string1 = %@,string2 = %@",string,string1,string2);


```
Output as follows:
```vim

Before calling the method string = (null),string1 = (null),string2 = (null)
After calling the method string = foo,string1 = 10,string2 = 32323


```
The purpose of this function is now pretty clear. However, in day-to-day development we rarely use a form like [NSValue valueWithPointer:&string]. So where exactly is this function used? A global search turns up the places where it is used.


There are two very useful macros in RACTuple: RACTupleUnpack( ) for unpacking, and RACTuplePack( ) for packing. The implementation of RACTuplePack( ) was analyzed above; it actually calls the tupleWithObjectsFromArray: method. So how is the RACTupleUnpack( ) macro implemented? This is where RACTupleUnpackingTrampoline comes into play.


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
That’s the actual macro for RACTupleUnpack( ). It looks quite complicated. Let’s write some test code and analyze it.
```objectivec

    RACTupleUnpack(NSString *string, NSNumber *num) = RACTuplePack(@"foo",@(10));


```
Paste the compiled output of the code above:
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
This makes it much easier to understand. `RACTupleUnpack_after284:` is a label. The initial value of `RACTupleUnpack_state284` is 0. In the `while` below, there is a `for` loop, and unpacking is performed inside this loop; in other words, the `setObject:forKeyedSubscript:` function is called.

Inside the loop,
```objectivec

[RACTupleUnpackingTrampoline trampoline][ @[ [NSValue valueWithPointer:&RACTupleUnpack284_var0], [NSValue valueWithPointer:&RACTupleUnpack284_var1], ] ]


```
This is the usage of calling [NSValue valueWithPointer:&string].


At this point, the role of the RACTupleUnpackingTrampoline class is also clear: it was designed specifically to implement the magical RACTupleUnpack( ) macro.

Of course, the setObject:forKeyedSubscript: function of the RACTupleUnpackingTrampoline class can also be used directly. However, you need to pay attention to how it is written, especially the pointer type. What is wrapped inside NSValue is valueWithPointer, whose type is (nullable const void *)pointer.


#### 3. RACTupleSequence

This class merely has Tuple in its name; it actually inherits from RACSequence.


The reason this class needs to be analyzed is that RACTuple has an extension property named rac\_sequence.
```objectivec

- (RACSequence *)rac_sequence {
   return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

```
Let's first take a look at the definition of RACTupleSequence.
```objectivec

@interface RACTupleSequence : RACSequence
@property (nonatomic, strong, readonly) NSArray *tupleBackingArray;
@property (nonatomic, assign, readonly) NSUInteger offset;
+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset;
@end

```
This class inherits from `RACSequence` and has only this one class method.

`tupleBackingArray` comes from the `backingArray` in `RACTuple`.
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
RACTupleSequence is designed to convert a Tuple into a Sequence. The array inside the Sequence is the Tuple’s internal backingArray. offset starts from 0.


### II. Analysis of RACSequence’s Underlying Implementation


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
RACSequence is a subclass of RACStream and is primarily the collection type in ReactiveCocoa.

First, let’s go over a few concepts related to RACSequence.

RACSequence has two very important properties: head and tail. head is an id, while tail is another RACSequence. This definition is somewhat recursive in nature.
```objectivec

    RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^id{
        return @(1);
    } tailBlock:^RACSequence *{
        return @[@2,@3,@4].rac_sequence;
    }];
    
    NSLog(@"sequence.head = %@ , sequence.tail =  %@",sequence.head ,sequence.tail);


```
Output:
```vim

sequence.head = 1 , sequence.tail =  <RACArraySequence: 0x608000223920>{ name = , array = (
    2,
    3,
    4
) }


```
This test code reveals the definitions of head and tail. See the figure below for a more detailed description:


![](https://img.halfrost.com/Blog/ArticleImage/36_5.png)


The code above uses the RACSequence initialization method; a detailed analysis is provided later.

objectEnumerator is a fast enumerator.
```objectivec


@interface RACSequenceEnumerator : NSEnumerator
@property (nonatomic, strong) RACSequence *sequence;
@end

```
This needs to be implemented to make iterating over RACSequence more convenient.
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
With this `NSEnumerator`, you can traverse from the `head` of `RACSequence` all the way to the `tail`.
```objectivec

- (NSEnumerator *)objectEnumerator {
    RACSequenceEnumerator *enumerator = [[RACSequenceEnumerator alloc] init];
    enumerator.sequence = self;
    return enumerator;
}

```
Back in the objectEnumerator in the definition of RACSequence, this simply retrieves the internal RACSequenceEnumerator.
```objectivec

- (NSArray *)array {
    NSMutableArray *array = [NSMutableArray array];
    for (id obj in self) {
        [array addObject:obj];
    }   
    return [array copy];
}

```
There is also an array in the definition of RACSequence; this array returns an NSArray containing all the objects in the RACSequence. The reason for-in can be used here is that the NSFastEnumeration protocol is implemented. As for the efficiency of for-in, it depends entirely on the execution efficiency of the overridden countByEnumeratingWithState: objects:  count: method in the NSFastEnumeration protocol.

Before analyzing the for-in execution efficiency of RACSequence, let’s first review the definition of NSFastEnumerationState. The fields here will be used extensively in the implementation that follows.
```objectivec

typedef struct {
    unsigned long state; //can be customized as any meaningful variable
    id __unsafe_unretained _Nullable * _Nullable itemsPtr;  //returns the starting address of the object array
    unsigned long * _Nullable mutationsPtr;  //points to a value that changes as the collection changes
    unsigned long extra[5]; //can be customized as any meaningful array
} NSFastEnumerationState;

```
For the function we are about to analyze, the input parameter `stackbuf` is the object array provided for `for-in`, and `len` is the length of that array.
```objectivec

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
    // Define the completed state as state = ULONG_MAX
    if (state->state == ULONG_MAX) {
        return 0;
    }
    
    // Since we need to traverse sequence multiple times, define the state field here to record sequence's starting address
    RACSequence *(^getSequence)(void) = ^{
        return (__bridge RACSequence *)(void *)state->state;
    };
    
    void (^setSequence)(RACSequence *) = ^(RACSequence *sequence) {
        // Release the old sequence
        CFBridgingRelease((void *)state->state);
        // Retain the new sequence and store sequence's starting address in state
        state->state = (unsigned long)CFBridgingRetain(sequence);
    };
    
    void (^complete)(void) = ^{
        // Release sequence and set state to the completed state
        setSequence(nil);
        state->state = ULONG_MAX;
    };
    
    // state == 0 is the initial value on the first call
    if (state->state == 0) {
        // During enumeration, if Sequence no longer changes, make mutationsPtr point to a constant value, the starting address of the extra array
        state->mutationsPtr = state->extra;
        // Refresh state again
        setSequence(self);
    }
    
    // Returned objects will be placed in stackbuf, so point itemsPtr to it
    state->itemsPtr = stackbuf;
    
    NSUInteger enumeratedCount = 0;
    while (enumeratedCount < len) {
        RACSequence *seq = getSequence();
        // Since sequence may be lazily generated, prevent it from being released when the enumerator reaches it

        __autoreleasing id obj = seq.head;

        // If there is no head, end enumeration
        if (obj == nil) {
            complete();
            break;
        }
        // Traverse sequence, putting each head into the stackbuf array.
        stackbuf[enumeratedCount++] = obj;
        
        // If there is no tail, enumeration is complete
        if (seq.tail == nil) {
            complete();
            break;
        }
        
        // After taking tail, the tail at the end of this iteration is the head for the next iteration; set seq.tail as Sequence's head to prepare for the next loop
        setSequence(seq.tail);
    }
    
    return enumeratedCount;
}


```
The entire traversal process is similar to recursion, traversing sequentially from start to finish.

Next, let’s take a closer look at the initialization of RACSequence:
```objectivec

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
   return [[RACDynamicSequence sequenceWithHeadBlock:headBlock tailBlock:tailBlock] setNameWithFormat:@"+sequenceWithHeadBlock:tailBlock:"];
}

```
Initializing `RACSequence` will call `RACDynamicSequence`. This is somewhat analogous to `RACSignal`’s `RACDynamicSignal`.


Now let’s look at the definition of `RACDynamicSequence`.
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
What needs to be noted here is that the modifiers for headBlock, tailBlock, and dependencyBlock are all strong rather than copy. This is due to a very strange bug. The bug where using the copy keyword causes a memory leak is documented in detail in [https://github.com/ReactiveCocoa/ReactiveCocoa/issues/505](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/505). The specific code is as follows:
```objectivec

[[[@[@1,@2,@3,@4,@5] rac_sequence] filter:^BOOL(id value) {
    return [value intValue] > 1;
}] array];

```
In the end, the person who identified the issue changed `copy` to `strong`, and the bug was magically fixed. Ultimately, in the entire ReactiveCocoa library, this was the only place where the block attribute was changed from `copy` to `strong`; it was not changed to `strong` everywhere.

The original author, [Justin Spahr-Summers](https://github.com/jspahrsummers), gave the [final explanation](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/506) for this issue:

>Maybe there's just something weird with how we override dealloc, set the blocks from a class method, cast them, or something else.

So in everyday code, when we write blocks, unless there is a special case, we should still continue to use `copy` as the attribute.
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
The `hasDependency` variable indicates whether there is a `dependencyBlock`. This function only saves `headBlock` and `tailBlock`.
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
The other class method, sequenceWithLazyDependency: headBlock: tailBlock:, includes a dependencyBlock. This method stores the three blocks: headBlock, tailBlock, and dependencyBlock.

These two sole initialization methods of RACSequence lead us to one of RACSequence’s two core issues: eager evaluation and lazy evaluation.


#### 1. Eager Evaluation and Lazy Evaluation


In the definition of RACSequence, there are also two RACSequences — eagerSequence and lazySequence. These two RACSequences correspond to the eager-evaluation RACSequence and the lazy-evaluation RACSequence, respectively.

The most vivid analogy for these two concepts is still the joke from Teacher Zang’s blog post, [Let’s Talk About Lazy Computation in iOS Development](http://williamzang.com/blog/2016/11/07/liao-yi-liao-ioskai-fa-zhong-de-duo-xing-ji-suan/). Quoted below:

>A little white rabbit ran into a vegetable shop and asked the owner, “Boss, do you have 100 carrots?” The owner said, “Not that many.” The little rabbit said disappointedly, “Sigh, you don’t even have 100 carrots...” The next day, the little rabbit came to the vegetable shop again and asked the owner, “Do you have 100 carrots today?” The owner said awkwardly, “We’re still a bit short today; they’ll be ready tomorrow.” The little rabbit left disappointed again. On the third day, as soon as the little rabbit pushed the door open, the owner happily said, “They’re here, they’re here! The 100 carrots I ordered the day before yesterday have arrived.” The little rabbit said, “Great, I’d like to buy 2!” ...

If we run into this kind of problem in daily development, it wastes a lot of memory. For example, suppose we allocate an array of size 1 million in memory, but in practice only use 100 values. This is where lazy evaluation is needed.

RACSequence supports both of these approaches. Let’s take a look at how the underlying source code implements them.


First, let’s look at the case we are usually very familiar with — eager evaluation.

![](https://img.halfrost.com/Blog/ArticleImage/36_6.png)


In RACSequence, the representative of eager evaluation is RACEagerSequence, a subclass of RACArraySequence, which is itself a subclass of RACSequence. Its eager evaluation is reflected in its bind function.
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
From the code above, you can see that it mainly performs two levels of loops. The outermost loop iterates over the values in its own RACSequence, then passes each value into the closure bindBlock( ), which returns a RACSequence. Finally, an NSMutableArray is used to collect the values from each RACSequence in sequence.

The second for-in loop iterates over the RACSequence. The reason it can be iterated using for-in is that it implements the NSFastEnumeration protocol, specifically the countByEnumeratingWithState: objects: count: method. This method was analyzed in detail above, so it will not be repeated here.

This is an example of eager evaluation: in each iteration, the value of the block( ) closure is computed. It is worth noting that the type of the RACSequence returned at the end is self.class, meaning it is still of type RACEagerSequence.

Now let’s look at how lazy evaluation is implemented in RACSequence.

In RACSequence, the bind function looks like this:
```objectivec

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
    RACStreamBindBlock bindBlock = block();
    return [[self bind:bindBlock passingThroughValuesFromSequence:nil] setNameWithFormat:@"[%@] -bind:", self.name];
}

```
It actually calls the `bind:passingThroughValuesFromSequence:` method, passing `nil` as the second argument.
```objectivec

- (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {

    __block RACSequence *valuesSeq = self;
    __block RACSequence *current = passthroughSequence;
    __block BOOL stop = NO;
    
    RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
        // Temporarily omitted
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
In the implementation of the `bind: passingThroughValuesFromSequence:` method, a `RACSequence` is created and returned by using the `sequenceWithLazyDependency: headBlock: tailBlock:` method. We analyzed the source code of `sequenceWithLazyDependency: headBlock: tailBlock:` earlier; its main purpose is to store three closures: `headBlock`, `tailBlock`, and `dependencyBlock`.

Calling the `bind` operation inside `RACSequence` does not execute the values inside those three closures; it only stores them. This is an example of lazy evaluation — the computation is deferred until the value is actually needed.

Based on the source code analysis above, we can write the following test code to deepen our understanding.
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
After the above code runs, it outputs the following information:
```vim

eagerSequence
eagerSequence
eagerSequence
eagerSequence
eagerSequence

```
It only printed `eagerSequence` five times; `lazySequence` did not print anything. The reason is that the `bind` closure is actually invoked only in `eagerSequence`; in `lazySequence`, the `bind` closure is merely copied.

So how can we make `lazySequence` execute the `bind` closure?
```objectivec

    [lazySequence array];

```
By executing the code above, “lazySequence” can be printed five times, because the `bind` closure will be invoked and executed again.


Eager evaluation and lazy evaluation are distinguished here. In `RACSequence`, aside from `RACEagerSequence`, which only performs eager evaluation, all other `Sequence` types are lazily evaluated.

Next, let’s continue analyzing how `RACSequence` implements lazy evaluation.


![](https://img.halfrost.com/Blog/ArticleImage/36_7.png)
```objectivec

RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
    while (current.head == nil) {
        if (stop) return nil;
        
        // Iterate over the current sequence and get the next value
        id value = valuesSeq.head;
        
        if (value == nil) {
            // Finished iterating over all values in the sequence
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
During the `bind` operation, a `lazySequence` like this is created. The three block closures capture how to create a `lazySequence`.

`headBlock` takes an `id` as input and also returns an `id`. When creating the `head` of the `lazySequence`, it does not care about the input parameter and directly returns the `head` of `passthroughSequence`.

`tailBlock` takes an `id` as input and returns a `RACSequence`. Since the definition of `RACSequence` is similar to a recursive definition, `tailBlock` recursively calls `bind:passingThroughValuesFromSequence:` again to produce a `RACSequence` as the `tail` of the new sequence.

The return value of `dependencyBlock` is used as the input parameter to `headBlock` and `tailBlock`. However, currently neither `headBlock` nor `tailBlock` cares about this input parameter. Therefore, `dependencyBlock` becomes the closure that must be executed before the `headBlock` and `tailBlock` closures are executed.


The purpose of `dependencyBlock` is to transform all the values in the original sequence once. `current` is the input parameter `passthroughSequence`, and `valuesSeq` is a reference to the original sequence. Each iteration takes the `head` of the original sequence until no more can be obtained, meaning traversal is complete.

The `head` of `valuesSeq` is taken and passed into the `bindBlock( )` closure for transformation. The return value is assigned to the `current` sequence. Before each `headBlock` and `tailBlock`, this `dependencyBlock` is called. The `head` of the transformed new sequence is `current`’s `head`, and the `tail` of the new sequence is obtained by recursively calling with `current.tail`.


The process of creating `lazyDependency` in `RACDynamicSequence` is essentially the process of saving these three blocks. So when are these closures invoked?
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
The source code above is the implementation for retrieving the `head` in `RACDynamicSequence`. When the `head` of the sequence needs to be retrieved, `headBlock()` is called. If the `dependencyBlock` closure has been saved, `dependencyBlock()` is executed first to perform a transformation before `headBlock()` is executed.
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
When retrieving the `tail` of an `RACDynamicSequence`, it behaves the same as retrieving the `head`: `tailBlock()` is only invoked when the `tail` actually needs to be extracted. If a `dependencyBlock` closure exists, the `dependencyBlock` closure is executed first, and then `tailBlock()` is invoked.


**To summarize:**  

1. `RACSequence` uses lazy evaluation. Except for the `bind` function of `RACEagerSequence`, all other Sequences are based on lazy evaluation. The corresponding closure is executed only when the value is about to be taken out for computation.  
2. Among all functions in `RACSequence`, only the `bind` function passes in a `dependencyBlock()` closure (`RACEagerSequence` overrides this `bind` function). Therefore, whenever you see a `dependencyBlock()` closure, you can infer that `RACSequence` has performed a transformation operation.


#### 2. Pull-driven and Push-driven

![](https://img.halfrost.com/Blog/ArticleImage/36_8.png)


In `RACSequence`, there is a method that can associate `RACSequence` with `RACSignal`.
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
The `signal` method in `RACSequence` calls `signalWithScheduler:`. In `signalWithScheduler:`, a new signal is created. The `RACDisposable` for this new signal is produced by `scheduleRecursiveBlock:`.
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
                // This is recursive
                [self scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable];
            };
            
            // The __block keyword isn't actually needed here, but due to Clang compiler behavior, it's added to protect the variables below
            __block NSLock *lock = [[NSLock alloc] init];
            lock.name = [NSString stringWithFormat:@"%@ %s", self, sel_getName(_cmd)];
            
            __block NSUInteger rescheduleCount = 0;
            
            // Once the synchronous operation completes, rescheduleImmediately should be set to YES
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
Although this code is long, let's break it down and analyze it:
```objectivec

__block NSUInteger rescheduleCount = 0; 

// Once the synchronization operation completes, rescheduleImmediately should be set to YES 
__block BOOL rescheduleImmediately = NO;

```
`rescheduleCount` is a counter for the number of recursive calls. The `rescheduleImmediately` `BOOL` determines whether to execute the `reallyReschedule()` closure immediately.

`recursiveBlock` is an input parameter; in practice, it is the closure code shown below:
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
The argument to recursiveBlock is reschedule( ). After the code above finishes executing, the code for the argument reschedule( ) starts executing. The code for the argument reschedule( ) closure is as follows:
```objectivec

    ^{
            [lock lock];
            BOOL immediate = rescheduleImmediately;
            if (!immediate) ++rescheduleCount;
            [lock unlock];
                    
            if (immediate) reallyReschedule();
    }

```
In this block, `rescheduleCount` is incremented. If `rescheduleImmediately` is `YES`, execution continues by recursively invoking `reallyReschedule()`.
```objectivec

   for (NSUInteger i = 0; i < synchronousCount; i++) {
    reallyReschedule();
   }

```
Eventually, the `reallyReschedule()` closure is called recursively inside this loop. What the `reallyReschedule()` closure does is execute the `scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable` method again.

Each recursive execution takes the `head` value of the sequence and sends it out, until `sequence.head == nil`, at which point it sends the completed signal.


Since `RACSequence` can also be converted into a `RACSignal`, we need to summarize the similarities and differences between the two.

**Summary:**

Comparison of similarities and differences between `RACSequence` and `RACSignal`:

![](https://img.halfrost.com/Blog/ArticleImage/36_9.png)


1. Except for `RACEagerSequence`, all `RACSequence` implementations are based on lazy evaluation, just like `RACSignal`.
2. `RACSequence` is continuous in time. Once a `RACSequence` is converted into a signal and subscribed to, it immediately sends out all values in one shot. `RACSignal` is discrete in time; it emits a stream of data only when an event arrives.
3. `RACSequence` is pull-driven: the subscriber determines whether values are sent. As long as a subscriber subscribes, the data stream is emitted. `RACSignal` is push-driven: whether it emits a data stream is not determined by subscribers. Regardless of whether there are subscribers, when a discrete event occurs, it emits the data stream.
4. `RACSequence` sends only data, while `RACSignal` sends events. Events include not only data, but also event state, such as whether the event errored or completed.


### III. Analysis of the Implementation of RACSequence Operations


![](https://img.halfrost.com/Blog/ArticleImage/36_10.png)


`RACSequence` also has the following operations.
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
This function takes an initial value, `start`, then repeatedly executes `reduce( )` in sequence. After the loop, the final value is returned as the result. This function is the fold function, folding from left to right.


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
This function is the same as the previous foldLeftWithStart: reduce:, except that it proceeds from right to left.


#### 3. objectPassingTest:
```objectivec

- (id)objectPassingTest:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);

    return [self filter:block].head;
}

```
objectPassingTest: calls the `filter:` function in `RACStream`, which was analyzed in previous articles. If `block(value)` is `YES`, it means the Test passed, so it returns the sequence for `value`. Then it retrieves `head` and returns it.


#### 4. any:
```objectivec

- (BOOL)any:(BOOL (^)(id))block {
    NSCParameterAssert(block != NULL);
    
    return [self objectPassingTest:block] != nil;
}

```
any: calls the `objectPassingTest:` function. If it is not `nil`, it means a value passed the test. If any value passes, it returns `YES`; otherwise, it returns `NO`.

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
all: performs the block( ) Test on each value from left to right, then applies the `&&` operation to each value in sequence.


#### 6. concat:
```objectivec

- (instancetype)concat:(RACStream *)stream {
    NSCParameterAssert(stream != nil);
    
    return [[[RACArraySequence sequenceWithArray:@[ self, stream ] offset:0]
             flatten]
            setNameWithFormat:@"[%@] -concat: %@", self.name, stream];
}


```
The operation of concat: is the same as it is for RACSignal. It connects the original sequence with the input stream, combines them into a higher-order sequence, and finally calls flatten to “flatten” it. For the implementation of flatten, see the analysis of the flatten implementation in RACStream from the previous articles.


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
Because `sequence` is defined recursively, `zipWith:` is also implemented recursively. The `head` of the new `sequence` produced by `zipWith:` is an `RACTuplePack` composed from the `head` values of the original two `sequence`s. The `tail` of the new `sequence` is produced by recursively calling `zipWith:` on the `tail` values of the original two `sequence`s.


### IV. Some Extensions of RACSequence


![](https://img.halfrost.com/Blog/ArticleImage/36_11.png)

`RACSequence` has the following 9 subclasses, among which `RACEagerSequence` inherits from `RACArraySequence`. From the names of these subclasses, you can tell what type of data each `sequence` contains. `RACUnarySequence` contains a unary `sequence`. It has only a `head` value and no `tail` value.


![](https://img.halfrost.com/Blog/ArticleImage/36_12.png)


`RACSequenceAdditions` contains 7 categories in total. These 7 categories extend the collection classes in iOS with `RACSequence`, making it more convenient for us to use `RACSequence`.

#### 1. NSArray+RACSequenceAdditions
```objectivec

@interface NSArray (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```
This Category can convert any `NSArray` array into a `RACSequence`.
```objectivec

- (RACSequence *)rac_sequence {
 return [RACArraySequence sequenceWithArray:self offset:0];
}

```
Creates and returns a `RACArraySequence` from an `NSArray`.


#### 2. NSDictionary+RACSequenceAdditions
```objectivec

@interface NSDictionary (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@property (nonatomic, copy, readonly) RACSequence *rac_keySequence;
@property (nonatomic, copy, readonly) RACSequence *rac_valueSequence;
@end

```
This Category can convert any `NSDictionary` dictionary into an `RACSequence`.
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
rac\_sequence converts dictionaries into an RACSequence filled with RACTuplePack instances. In this RACSequence, the first element is the key, and the second element is the value.

rac\_keySequence is an RACSequence containing all keys.

rac\_valueSequence is an RACSequence containing all values.


#### 3. NSEnumerator+RACSequenceAdditions
```objectivec

@interface NSEnumerator (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end


```
This category can convert any `NSEnumerator` into an `RACSequence`.
```objectivec


- (RACSequence *)rac_sequence {
    return [RACSequence sequenceWithHeadBlock:^{
        return [self nextObject];
    } tailBlock:^{
        return self.rac_sequence;
    }];
}

```
The returned `RACSequence` has the current sequence’s head as its head, and the current sequence itself as its tail.

#### 4. NSIndexSet+RACSequenceAdditions
```objectivec

@interface NSIndexSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end


```
This Category can convert any `NSIndexSet` into an `RACSequence`.
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
Returns a RACIndexSetSequence. In this IndexSetSequence, data contains NSData, indexes contains NSUInteger, and count contains the total number of indexes.


#### 5. NSOrderedSet+RACSequenceAdditions
```objectivec

@interface NSOrderedSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```
This Category can convert any `NSOrderedSet` into an `RACSequence`.
```objectivec

- (RACSequence *)rac_sequence {
    return self.array.rac_sequence;
}

```
Converts the array in the returned NSOrderedSet into a sequence.

#### 6. NSSet+RACSequenceAdditions
```objectivec

@interface NSSet (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```
This category can convert any `NSSet` into an `RACSequence`.
```objectivec

- (RACSequence *)rac_sequence {
   return self.allObjects.rac_sequence;
}

```
Creates and returns a `RACArraySequence` from the `NSSet`'s `allObjects` array.


#### 7. NSString+RACSequenceAdditions
```objectivec

@interface NSString (RACSequenceAdditions)
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end

```
This Category can convert any `NSString` into an `RACSequence`.
```objectivec

- (RACSequence *)rac_sequence {
    return [RACStringSequence sequenceWithString:self offset:0];
}


```
It returns the sequence corresponding to an array filled with string characters.


### Finally

The analysis of the underlying implementations of RACSequence and RACTuple is now complete. I welcome any feedback or suggestions.