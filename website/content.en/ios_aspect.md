+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Runtime", "Aspect", "AOP"]
date = 2016-10-15T09:54:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/27_0_.jpg"
slug = "ios_aspect"
tags = ["iOS", "Runtime", "Aspect", "AOP"]
title = "How to Implement Aspect-Oriented Programming in iOS"

+++


#### Preface

During the last two days of my stay at the “Runtime Hospital,” I analyzed how AOP is implemented. After being “discharged,” I realized that the Aspects library had not yet been analyzed in detail, so this article came about. Today, let’s talk about how iOS implements Aspect Oriented Programming.


#### Table of Contents
- 1.Introduction to Aspect Oriented Programming
- 2.What Is Aspects
- 3.Analysis of the Four Basic Classes in Aspects
- 4.Preparation Before Hooking with Aspects
- 5.Detailed Explanation of the Aspects Hooking Process
- 6.Some “Pitfalls” in Aspects

#### 1. Introduction to Aspect Oriented Programming

**Aspect-oriented programming** (AOP, also translated as **aspect-based programming**, **perspective-oriented programming**, or **profile-oriented programming**) is a term in [computer science](https://zh.wikipedia.org/wiki/%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6) that refers to a [programming paradigm](https://zh.wikipedia.org/wiki/%E7%A8%8B%E5%BA%8F%E8%AE%BE%E8%AE%A1%E8%8C%83%E5%9E%8B). This paradigm is based on a language construct called an **aspect**. An **aspect** is a new modularization mechanism used to describe **crosscutting concerns** that are scattered across [objects](https://zh.wikipedia.org/wiki/%E5%AF%B9%E8%B1%A1_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6)), [classes](https://zh.wikipedia.org/wiki/%E7%B1%BB_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E5%AD%A6)), or [functions](https://zh.wikipedia.org/wiki/%E5%87%BD%E6%95%B0_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E5%AD%A6)).

The concept of aspects originated as an improvement to [object-oriented programming](https://zh.wikipedia.org/wiki/%E9%9D%A2%E5%90%91%E5%AF%B9%E8%B1%A1%E7%9A%84%E7%A8%8B%E5%BA%8F%E8%AE%BE%E8%AE%A1), but it is not limited to that; it can also be used to improve traditional functions. Programming concepts related to aspects also include the [metaobject protocol](https://zh.wikipedia.org/w/index.php?title=%E5%85%83%E5%AF%B9%E8%B1%A1%E5%8D%8F%E8%AE%AE&action=edit&redlink=1), subjects, [mixins](https://zh.wikipedia.org/w/index.php?title=%E6%B7%B7%E5%85%A5&action=edit&redlink=1), and delegation.

AOP is a technique for uniformly maintaining program functionality through precompilation and runtime **dynamic proxies**.

OOP (object-oriented programming) **abstracts and encapsulates** the **entities** in a business process, along with their **attributes** and **behaviors**, in order to obtain clearer and more efficient logical unit partitioning.

AOP, by contrast, extracts **aspects** from a business process. It focuses on a particular **step** or **phase** in the process, in order to achieve **isolation** with low coupling between different parts of the logical flow.


OOP and AOP are two different “ways of thinking.” OOP focuses on encapsulating an object’s attributes and behavior, while AOP focuses on a particular step or phase and extracts aspects from it.

For example, suppose there is a requirement to check permissions. The OOP approach would certainly be to add a permission check before every operation. What about logging? You would add logging at the start and end of every method. AOP extracts these repeated logic and operations, and uses dynamic proxies to decouple these modules. OOP and AOP are not mutually exclusive; they complement each other.

Using AOP for programming in iOS enables non-intrusive changes. You can add new functionality without modifying the previous code logic. It is mainly used to handle system-level services with crosscutting characteristics, such as logging, permission management, caching, and object pool management.


#### 2. What Is Aspects
 
![](https://img.halfrost.com/Blog/ArticleImage/27_1.png)


[Aspects](https://github.com/steipete/Aspects) is a lightweight aspect-oriented programming library. It allows you to add arbitrary code to methods that exist in any class and any instance. You can insert code at the following join points: before (executed before the original method) / instead (replaces execution of the original method) / after (executed after the original method, the default). It implements hooks through Runtime message forwarding. Aspects automatically calls the super method, making it more convenient than using method swizzling.

This library is very stable and is currently used in hundreds of apps. It is also part of PSPDFKit. [PSPDFKit](http://pspdfkit.com/) is an iOS framework library for viewing PDFs. The author eventually decided to open source it.


#### 3. Analysis of the Four Basic Classes in Aspects

Let’s start with the header file.

##### 1.Aspects.h
```objectivec

typedef NS_OPTIONS(NSUInteger, AspectOptions) {
    AspectPositionAfter   = 0,            /// Called after the original implementation (default)
    AspectPositionInstead = 1,            /// Will replace the original implementation.
    AspectPositionBefore  = 2,            /// Called before the original implementation.
    
    AspectOptionAutomaticRemoval = 1 << 3 /// Will remove the hook after the first execution.
};

```
An enum is defined in the header file. This enum specifies when the aspect method is invoked. The default is `AspectPositionAfter`, which invokes it after the original method has finished executing. `AspectPositionInstead` replaces the original method. `AspectPositionBefore` invokes the aspect method before the original method. `AspectOptionAutomaticRemoval` automatically removes the hook after it has executed.
```objectivec

@protocol AspectToken <NSObject>

- (BOOL)remove;

@end

```
An AspectToken protocol is defined. The Aspect Token here is implicit, allowing us to call remove to undo a hook. The remove method returns YES to indicate that the undo operation succeeded, and NO to indicate that it failed.
```objectivec

@protocol AspectInfo <NSObject>

- (id)instance;
- (NSInvocation *)originalInvocation;
- (NSArray *)arguments;

@end

```
An `AspectInfo` protocol is also defined. The `AspectInfo` protocol is the first parameter in our block syntax.

The `instance` method returns the current hooked instance. The `originalInvocation` method returns the original invocation of the hooked method. The `arguments` method returns all method arguments. Its implementation is lazy-loaded.

The header file also deliberately includes a comment explaining how to use Aspects and the caveats to be aware of, which is worth our attention.
```c

/**
 Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called a 1000 times per second.

 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */

```
Aspects uses Objective-C’s message forwarding mechanism to hook messages. This introduces some performance overhead. Do not add Aspects to methods that are used frequently. Aspects is designed for use with view/controller code, not for hooking methods that are called 1,000 times per second.

After adding an Aspect, an implicit token is returned, which can be used to unregister the hooked method. All calls are thread-safe.

Thread safety will be analyzed in detail below. For now, we at least know that Aspects should not be used in methods such as those inside `for` loops, as it can cause significant performance overhead.
```objectivec

@interface NSObject (Aspects)

/// Adds a block of code before/instead/after the current `selector` for a specific class.
///
/// @param block Aspects replicates the type signature of the method being hooked.
/// The first parameter will be `id<AspectInfo>`, followed by all parameters of the method.
/// These parameters are optional and will be filled to match the block signature.
/// You can even use an empty block, or one that simple gets `id<AspectInfo>`.
///
/// @note Hooking static methods is not supported.
/// @return A token which allows to later deregister the aspect.
+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

/// Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

@end


```
There are only these two methods in the entire Aspects library. As you can see, Aspects is an extension on NSObject; as long as something is an NSObject, it can use these two methods. The two methods have the same name, the same parameters, and the same return value. The only difference is that one is a plus method and the other is a minus method. One is used to hook class methods, and the other is used to hook instance methods.

The method has 4 parameters. The first, selector, is the original method to which you want to add the aspect. The second parameter is of type AspectOptions, which indicates whether this aspect is added before / instead / after the original method. The 4th parameter is the returned error.

The key point is the third parameter, block. This block copies the signature type of the method being hooked. The block conforms to the AspectInfo protocol. We can even use an empty block. The parameters in the AspectInfo protocol are optional and are mainly used to match the block signature.

The return value is a token that can be used to unregister this Aspects hook.

**Note: Aspects does not support hooking static methods**
```objectivec

typedef NS_ENUM(NSUInteger, AspectErrorCode) {
    AspectErrorSelectorBlacklisted,                   /// Selectors like release, retain, autorelease are blacklisted.
    AspectErrorDoesNotRespondToSelector,              /// Selector could not be found.
    AspectErrorSelectorDeallocPosition,               /// When hooking dealloc, only AspectPositionBefore is allowed.
    AspectErrorSelectorAlreadyHookedInClassHierarchy, /// Statically hooking the same method in subclasses is not allowed.
    AspectErrorFailedToAllocateClassPair,             /// The runtime failed creating a class pair.
    AspectErrorMissingBlockSignature,                 /// The block misses compile time signature info and can't be called.
    AspectErrorIncompatibleBlockSignature,            /// The block signature does not match the method or is too large.

    AspectErrorRemoveObjectAlreadyDeallocated = 100   /// (for removing) The object hooked is already deallocated.
};

extern NSString *const AspectErrorDomain;


```
The error code type is defined here. This makes it easier for us to debug when errors occur.


##### 2.Aspects.m
```objectivec

#import "Aspects.h"

#import <libkern/OSAtomic.h>

#import <objc/runtime.h>

#import <objc/message.h>

```
\#import <libkern/OSAtomic.h> is imported for the spin lock used below. \#import <objc/runtime.h> and \#import <objc/message.h> are required headers for using the Runtime.
```objectivec

typedef NS_OPTIONS(int, AspectBlockFlags) {
      AspectBlockFlagsHasCopyDisposeHelpers = (1 << 25),
      AspectBlockFlagsHasSignature          = (1 << 30)
};

```
AspectBlockFlags is defined as a flag used to indicate two conditions: whether Copy and Dispose Helpers are required, and whether a method signature, Signature, is required.


The four classes defined in Aspects are AspectInfo, AspectIdentifier, AspectsContainer, and AspectTracker. Next, let’s look at how these four classes are defined.

##### 3. AspectInfo
```objectivec

@interface AspectInfo : NSObject <AspectInfo>
- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation;
@property (nonatomic, unsafe_unretained, readonly) id instance;
@property (nonatomic, strong, readonly) NSArray *arguments;
@property (nonatomic, strong, readonly) NSInvocation *originalInvocation;
@end

```
Implementation for AspectInfo
```objectivec


#pragma mark - AspectInfo

@implementation AspectInfo

@synthesize arguments = _arguments;

- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation {
    NSCParameterAssert(instance);
    NSCParameterAssert(invocation);
    if (self = [super init]) {
        _instance = instance;
        _originalInvocation = invocation;
    }
    return self;
}

- (NSArray *)arguments {
    // Lazily evaluate arguments, boxing is expensive.
    if (!_arguments) {
        _arguments = self.originalInvocation.aspects_arguments;
    }
    return _arguments;
}

```
AspectInfo inherits from NSObject and conforms to the AspectInfo protocol. In its \- (id)initWithInstance: invocation: method, it stores the externally passed-in instance, `instance`, and the original `invocation` into the corresponding member variables of the AspectInfo class. The - (NSArray *)arguments method is lazily loaded and returns the `aspects` argument array from the original `invocation`.


So how is the `aspects_arguments` getter implemented? The author does this by adding a category to NSInvocation.
```objectivec


@interface NSInvocation (Aspects)
- (NSArray *)aspects_arguments;
@end

```
Add an `Aspects` category to the original `NSInvocation` class. This category adds only one method, `aspects\_arguments`, whose return value is an array containing all arguments of the current invocation.

The corresponding implementation
```objectivec

#pragma mark - NSInvocation (Aspects)

@implementation NSInvocation (Aspects)

- (NSArray *)aspects_arguments {
 NSMutableArray *argumentsArray = [NSMutableArray array];
 for (NSUInteger idx = 2; idx < self.methodSignature.numberOfArguments; idx++) {
  [argumentsArray addObject:[self aspect_argumentAtIndex:idx] ?: NSNull.null];
 }
 return [argumentsArray copy];
}

@end

```
\- (NSArray *)aspects\_arguments is very straightforward: it is just a `for` loop that adds all the arguments in the `methodSignature` method signature to an array, and finally returns that array.

There are two points about the implementation of this `\- (NSArray *)aspects\_arguments` method for retrieving all method arguments that need to be explained in detail. First, why the loop starts from 2; second, how `[self aspect\_argumentAtIndex:idx]` is implemented internally.


![](https://img.halfrost.com/Blog/ArticleImage/27_2.png)

Let’s first talk about why the loop starts from 2.


As a supplement to the Runtime, Type Encodings encode the return value and parameter types of each method into a string at compile time, and associate that string with the method’s selector. This encoding scheme is also very useful in other situations, so we can use the `@encode` compiler directive to obtain it. Given a type, `@encode` returns the string encoding of that type. These types can be basic types such as `int` and pointers, or types such as structs and classes. In fact, any type that can be used as an operand to `sizeof()` can be used with `@encode()`.

In the [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html) section of the Objective\-C Runtime Programming Guide, all type encodings in Objective\-C are listed. Note that many of these types are the same as the encoding types we use for archiving and distribution. However, some of them cannot be used for archiving.

Note: Objective\-C does not support the `long double` type. `@encode(long double)` returns `d`, which is the same as `double`.

![](https://img.halfrost.com/Blog/ArticleImage/27_3.png)


To support message forwarding and dynamic invocation in OC, the Type information of an Objective\-C Method is **combined and encoded** in the form of “return value Type + argument Types”. The two implicit arguments, `self` and `\_cmd`, also need to be taken into account:
```c

- (void)tap; => "v@:"
- (int)tapWithView:(double)pointx; => "i@:d"

```
According to the table above, we can see that in the encoded string, the first three positions are the return value Type, the implicit `self` parameter Type `@`, and the implicit `\_cmd` parameter Type `:`.

Therefore, starting from position 3, the remaining entries are the input parameters.

Suppose we take \- (void)tapView:(UIView *)view atIndex:(NSInteger)index as an example and print the methodSignature.
```c

(lldb) po self.methodSignature
<NSMethodSignature: 0x60800007df00>
number of arguments = 4
frame size = 224
is special struct return? NO
return value: -------- -------- -------- --------
type encoding (v) 'v'
flags {}
modifiers {}
frame {offset = 0, offset adjust = 0, size = 0, size adjust = 0}
memory {offset = 0, size = 0}
argument 0: -------- -------- -------- --------
type encoding (@) '@'
flags {isObject}
modifiers {}
frame {offset = 0, offset adjust = 0, size = 8, size adjust = 0}
memory {offset = 0, size = 8}
argument 1: -------- -------- -------- --------
type encoding (:) ':'
flags {}
modifiers {}
frame {offset = 8, offset adjust = 0, size = 8, size adjust = 0}
memory {offset = 0, size = 8}
argument 2: -------- -------- -------- --------
type encoding (@) '@'
flags {isObject}
modifiers {}
frame {offset = 16, offset adjust = 0, size = 8, size adjust = 0}
memory {offset = 0, size = 8}
argument 3: -------- -------- -------- --------
type encoding (q) 'q'
flags {isSigned}
modifiers {}
frame {offset = 24, offset adjust = 0, size = 8, size adjust = 0}
memory {offset = 0, size = 8}


```
number of arguments = 4, because there are two implicit parameters, self and \_cmd, plus the input parameters view and index.

![](https://img.halfrost.com/Blog/ArticleImage/27_4.png)


The frame of the first argument is {offset = 0, offset adjust = 0, size = 0, size adjust = 0}, and the memory is {offset = 0, size = 0}; the return value does not occupy any size here. The second argument is self, with frame {offset = 0, offset adjust = 0, size = 8, size adjust = 0} and memory {offset = 0, size = 8}. Since size = 8, the offset of the next frame is 8, then 16, and so on.


As for why 2 needs to be passed here, it is also related to the specific implementation of aspect\_argumentAtIndex.

Now let’s look at the implementation of aspect\_argumentAtIndex. Credit for this method also goes to the ReactiveCocoa team, which provided an elegant way to obtain the parameters from a method signature.
```objectivec

// Thanks to the ReactiveCocoa team for providing a generic solution for this.
- (id)aspect_argumentAtIndex:(NSUInteger)index {
 const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
 // Skip const type qualifier.
 if (argType[0] == _C_CONST) argType++;

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)

 if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
    __autoreleasing id returnObj;
    [self getArgument:&returnObj atIndex:(NSInteger)index];
    return returnObj;
 } else if (strcmp(argType, @encode(SEL)) == 0) {
    SEL selector = 0;
    [self getArgument:&selector atIndex:(NSInteger)index];
    return NSStringFromSelector(selector);
} else if (strcmp(argType, @encode(Class)) == 0) {
    __autoreleasing Class theClass = Nil;
    [self getArgument:&theClass atIndex:(NSInteger)index];
    return theClass;
    // Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
 } else if (strcmp(argType, @encode(char)) == 0) {
    WRAP_AND_RETURN(char);
 } else if (strcmp(argType, @encode(int)) == 0) {
    WRAP_AND_RETURN(int);
 } else if (strcmp(argType, @encode(short)) == 0) {
    WRAP_AND_RETURN(short);
 } else if (strcmp(argType, @encode(long)) == 0) {
    WRAP_AND_RETURN(long);
 } else if (strcmp(argType, @encode(long long)) == 0) {
    WRAP_AND_RETURN(long long);
 } else if (strcmp(argType, @encode(unsigned char)) == 0) {
    WRAP_AND_RETURN(unsigned char);
 } else if (strcmp(argType, @encode(unsigned int)) == 0) {
    WRAP_AND_RETURN(unsigned int);
 } else if (strcmp(argType, @encode(unsigned short)) == 0) {
    WRAP_AND_RETURN(unsigned short);
 } else if (strcmp(argType, @encode(unsigned long)) == 0) {
    WRAP_AND_RETURN(unsigned long);
 } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
    WRAP_AND_RETURN(unsigned long long);
 } else if (strcmp(argType, @encode(float)) == 0) {
    WRAP_AND_RETURN(float);
 } else if (strcmp(argType, @encode(double)) == 0) {
    WRAP_AND_RETURN(double);
 } else if (strcmp(argType, @encode(BOOL)) == 0) {
    WRAP_AND_RETURN(BOOL);
 } else if (strcmp(argType, @encode(bool)) == 0) {
    WRAP_AND_RETURN(BOOL);
 } else if (strcmp(argType, @encode(char *)) == 0) {
    WRAP_AND_RETURN(const char *);
 } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
    __unsafe_unretained id block = nil;
    [self getArgument:&block atIndex:(NSInteger)index];
    return [block copy];
 } else {
    NSUInteger valueSize = 0;
    NSGetSizeAndAlignment(argType, &valueSize, NULL);

    unsigned char valueBytes[valueSize];
    [self getArgument:valueBytes atIndex:(NSInteger)index];

    return [NSValue valueWithBytes:valueBytes objCType:argType];
 }
 return nil;

#undef WRAP_AND_RETURN
}

```
`getArgumentTypeAtIndex:` is used to obtain the type encoding string at the specified `index` in a `methodSignature`. The string returned by this method corresponds directly to the `index` value we pass in. For example, if we pass in `2`, the returned string is actually the third position in the string corresponding to the `methodSignature`.

Because position 0 is the type encoding for the function’s return value, passing in `2` corresponds to `argument2`. So when we pass in `index = 2`, we are filtering out the first three type encoding strings and starting the comparison from `argument2`. This is why the loop starts at 2.


![](https://img.halfrost.com/Blog/ArticleImage/27_5.png)


`_C_CONST` is a constant used to determine whether the encoding string represents a `CONST` constant.
```c

#define _C_ID       '@'

#define _C_CLASS    '#'

#define _C_SEL      ':'

#define _C_CHR      'c'

#define _C_UCHR     'C'

#define _C_SHT      's'

#define _C_USHT     'S'

#define _C_INT      'i'

#define _C_UINT     'I'

#define _C_LNG      'l'

#define _C_ULNG     'L'

#define _C_LNG_LNG  'q'

#define _C_ULNG_LNG 'Q'

#define _C_FLT      'f'

#define _C_DBL      'd'

#define _C_BFLD     'b'

#define _C_BOOL     'B'

#define _C_VOID     'v'

#define _C_UNDEF    '?'

#define _C_PTR      '^'

#define _C_CHARPTR  '*'

#define _C_ATOM     '%'

#define _C_ARY_B    '['

#define _C_ARY_E    ']'

#define _C_UNION_B  '('

#define _C_UNION_E  ')'

#define _C_STRUCT_B '{'

#define _C_STRUCT_E '}'

#define _C_VECTOR   '!'

#define _C_CONST    'r'

```
The `Type` here is exactly the same as the `Type` in OC, except that here it is a C `char` type.
```c

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)

```
WRAP\_AND\_RETURN is a macro definition. The `getArgument:atIndex:` method invoked inside this macro is used to retrieve the corresponding argument from an `NSInvocation` by `index`. Finally, when returning, it wraps `val` into an object and returns it.

In the large `if - else` block below, there are many string comparison calls using `strcmp`.

For example, `strcmp(argType, @encode(id)) == 0`: `argType` is a `char`, whose content is the corresponding type encoding obtained from `methodSignature`, and it is the same type encoding as `@encode(id)`. After comparing them with `strcmp`, if the result is `0`, it means the types are the same.

The large block of checks below is the process of returning all input arguments. It checks `id`, `class`, and `SEL` in sequence, followed by a large set of basic types: `char`, `int`, `short`, `long`, `long long`, `unsigned char`, `unsigned int`, `unsigned short`, `unsigned long`, `unsigned long long`, `float`, `double`, `BOOL`, `bool`, and `char *`. These basic types are all wrapped into objects and returned using `WRAP\_AND\_RETURN`. Finally, it checks blocks and `struct` structures, and returns the corresponding objects as well.

In this way, all input arguments are returned and received in the array. Suppose we still use the example above, `- (void)tapView:(UIView *)view atIndex:(NSInteger)index`. After `aspects\_arguments` finishes executing, the array contains:
```c

(
  <UIView: 0x7fa2e2504190; frame = (0 80; 414 40); layer = <CALayer: 0x6080000347c0>>",
  1
)

```
In summary, `AspectInfo` primarily contains `NSInvocation` information. It wraps `NSInvocation` with an additional layer, such as argument information.

##### 4. AspectIdentifier


![](https://img.halfrost.com/Blog/ArticleImage/27_5_.png)
```objectivec

// Tracks a single aspect.
@interface AspectIdentifier : NSObject
+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error;
- (BOOL)invokeWithInfo:(id<AspectInfo>)info;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, strong) NSMethodSignature *blockSignature;
@property (nonatomic, weak) id object;
@property (nonatomic, assign) AspectOptions options;
@end

```
Corresponding implementation
```objectivec

#pragma mark - AspectIdentifier

@implementation AspectIdentifier

+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error {
    NSCParameterAssert(block);
    NSCParameterAssert(selector);
    NSMethodSignature *blockSignature = aspect_blockMethodSignature(block, error); // TODO: check signature compatibility, etc.
    if (!aspect_isCompatibleBlockSignature(blockSignature, object, selector, error)) {
        return nil;
    }

    AspectIdentifier *identifier = nil;
    if (blockSignature) {
        identifier = [AspectIdentifier new];
        identifier.selector = selector;
        identifier.block = block;
        identifier.blockSignature = blockSignature;
        identifier.options = options;
        identifier.object = object; // weak
    }
    return identifier;
}

- (BOOL)invokeWithInfo:(id<AspectInfo>)info {
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.blockSignature];
    NSInvocation *originalInvocation = info.originalInvocation;
    NSUInteger numberOfArguments = self.blockSignature.numberOfArguments;

    // Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        AspectLogError(@"Block has too many arguments. Not calling %@", info);
        return NO;
    }

    // The `self` of the block will be the AspectInfo. Optional.
    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&info atIndex:1];
    }
    
 void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
  NSUInteger argSize;
  NSGetSizeAndAlignment(type, &argSize, NULL);
        
  if (!(argBuf = reallocf(argBuf, argSize))) {
            AspectLogError(@"Failed to allocate memory for block invocation.");
   return NO;
  }
        
  [originalInvocation getArgument:argBuf atIndex:idx];
  [blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:self.block];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, SEL:%@ object:%@ options:%tu block:%@ (#%tu args)>", self.class, self, NSStringFromSelector(self.selector), self.object, self.options, self.block, self.blockSignature.numberOfArguments];
}

- (BOOL)remove {
    return aspect_remove(self, NULL);
}

@end


```
The aspect\_blockMethodSignature method is called in the instancetype method.
```objectivec


static NSMethodSignature *aspect_blockMethodSignature(id block, NSError **error) {
    AspectBlockRef layout = (__bridge void *)block;
 if (!(layout->flags & AspectBlockFlagsHasSignature)) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't contain a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }
 void *desc = layout->descriptor;
 desc += 2 * sizeof(unsigned long int);
 if (layout->flags & AspectBlockFlagsHasCopyDisposeHelpers) {
  desc += 2 * sizeof(void *);
    }
 if (!desc) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't has a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }
 const char *signature = (*(const char **)desc);
 return [NSMethodSignature signatureWithObjCTypes:signature];
}

```
The purpose of `aspect\_blockMethodSignature` is to convert the incoming `AspectBlock` into an `NSMethodSignature` method signature.

The structure of `AspectBlock` is as follows:
```objectivec

typedef struct _AspectBlock {
 __unused Class isa;
 AspectBlockFlags flags;
 __unused int reserved;
 void (__unused *invoke)(struct _AspectBlock *block, ...);
 struct {
  unsigned long int reserved;
  unsigned long int size;
  // requires AspectBlockFlagsHasCopyDisposeHelpers
  void (*copy)(void *dst, const void *src);
  void (*dispose)(const void *);
  // requires AspectBlockFlagsHasSignature
  const char *signature;
  const char *layout;
 } *descriptor;
 // imported variables
} *AspectBlockRef;

```
Here, a `block` type used internally by Aspects is defined. Anyone familiar with the system’s `Block` will immediately notice that the two look very similar. If you are not familiar with it, you can read my earlier article analyzing `Block`. In that article, `Block` is converted into a struct using Clang, and the resulting structure is very similar to the `block` defined here.

![](https://img.halfrost.com/Blog/ArticleImage/27_6.png)


After understanding the structure of `AspectBlock`, the `aspect\_blockMethodSignature` function becomes much clearer.
```objectivec

    AspectBlockRef layout = (__bridge void *)block;
 if (!(layout->flags & AspectBlockFlagsHasSignature)) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't contain a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }

```
AspectBlockRef layout = (\_\_bridge void *)block. Since the two block implementations are similar, the input parameter block is first forcibly cast to the AspectBlockRef type here, and then it checks whether the AspectBlockFlagsHasSignature flag is present. If not, it reports an error indicating that no method signature is included.

Note that the block passed in is of the global type.
```objectivec

  (__NSGlobalBlock) __NSGlobalBlock = {
    NSBlock = {
      NSObject = {
        isa = __NSGlobalBlock__
      }
    }
  }


```

```objectivec

 void *desc = layout->descriptor;
 desc += 2 * sizeof(unsigned long int);
 if (layout->flags & AspectBlockFlagsHasCopyDisposeHelpers) {
  desc += 2 * sizeof(void *);
    }
 if (!desc) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't has a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }


```
`desc` is the descriptor pointer corresponding to the original block. Moving the descriptor pointer forward by two `unsigned long int` positions points to the address of the copy function. If it includes the Copy and Dispose functions, then move it forward by another two `(void *)` sizes. At this point, the pointer has definitely advanced to the `const char *signature` position. If `desc` does not exist, an error will also be reported: the block does not contain a method signature.
```objectivec

 const char *signature = (*(const char **)desc);
 return [NSMethodSignature signatureWithObjCTypes:signature];


```
At this point, it is guaranteed that the method signature exists and has a valid signature. Finally, it calls `NSMethodSignature`’s `signatureWithObjCTypes` method to return the method signature.

Here is an example of what the method signature ultimately generated by `aspect_blockMethodSignature` looks like.
```objectivec

    [UIView aspect_hookSelector:@selector(UIView:atIndex:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspects, UIView *view, NSInteger index)
     {
         
         NSLog(@"Button clicked %ld",index);
         
     } error:nil];

```
The string ultimately obtained by const char *signature looks like this
```objectivec

(const char *) signature = 0x0000000102f72676 "v32@?0@\"<AspectInfo>\"8@\"UIView\"16q24"

```
v32@?0@"<AspectInfo>"8@"UIView"16q24 is a Block
```objectivec

^(id<AspectInfo> aspects, UIView *view, NSInteger index){

}

```
The corresponding Type. The Type for a void return value is v, 32 is the offset, @？ is the Type corresponding to the block, @“<AspectInfo>” is the first parameter, @"UIView" is the second parameter, and the Type corresponding to NSInteger is q.

The number following each Type is its corresponding offset. Print out the final converted NSMethodSignature.
```objectivec


 <NSMethodSignature: 0x600000263dc0>
      number of arguments = 4
      frame size = 224
      is special struct return? NO
      return value: -------- -------- -------- --------
          type encoding (v) 'v'
          flags {}
          modifiers {}
          frame {offset = 0, offset adjust = 0, size = 0, size adjust = 0}
          memory {offset = 0, size = 0}
      argument 0: -------- -------- -------- --------
          type encoding (@) '@?'
          flags {isObject, isBlock}
          modifiers {}
          frame {offset = 0, offset adjust = 0, size = 8, size adjust = 0}
          memory {offset = 0, size = 8}
      argument 1: -------- -------- -------- --------
          type encoding (@) '@"<AspectInfo>"'
          flags {isObject}
          modifiers {}
          frame {offset = 8, offset adjust = 0, size = 8, size adjust = 0}
          memory {offset = 0, size = 8}
              conforms to protocol 'AspectInfo'
      argument 2: -------- -------- -------- --------
          type encoding (@) '@"UIView"'
          flags {isObject}
          modifiers {}
          frame {offset = 16, offset adjust = 0, size = 8, size adjust = 0}
          memory {offset = 0, size = 8}
              class 'DLMenuView'
      argument 3: -------- -------- -------- --------
          type encoding (q) 'q'
          flags {isSigned}
          modifiers {}
          frame {offset = 24, offset adjust = 0, size = 8, size adjust = 0}
          memory {offset = 0, size = 8}

```
Returning to AspectIdentifier, continue looking at the instancetype method. After obtaining the method signature of the passed-in block, it then calls the aspect\_isCompatibleBlockSignature method.
```objectivec


static BOOL aspect_isCompatibleBlockSignature(NSMethodSignature *blockSignature, id object, SEL selector, NSError **error) {
    NSCParameterAssert(blockSignature);
    NSCParameterAssert(object);
    NSCParameterAssert(selector);

    BOOL signaturesMatch = YES;
    NSMethodSignature *methodSignature = [[object class] instanceMethodSignatureForSelector:selector];
    if (blockSignature.numberOfArguments > methodSignature.numberOfArguments) {
        signaturesMatch = NO;
    }else {
        if (blockSignature.numberOfArguments > 1) {
            const char *blockType = [blockSignature getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }
        // Argument 0 is self/block, argument 1 is SEL or id<AspectInfo>. We start comparing at argument 2.
        // The block can have less arguments than the method, that's ok.
        if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < blockSignature.numberOfArguments; idx++) {
                const char *methodType = [methodSignature getArgumentTypeAtIndex:idx];
                const char *blockType = [blockSignature getArgumentTypeAtIndex:idx];
                // Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }
    }

    if (!signaturesMatch) {
        NSString *description = [NSString stringWithFormat:@"Block signature %@ doesn't match %@.", blockSignature, methodSignature];
        AspectError(AspectErrorIncompatibleBlockSignature, description);
        return NO;
    }
    return YES;
}


```
This function compares the method block we want to use as the replacement with the original method to be replaced. How does it compare them? By comparing their method signatures.

The input parameter selector is the original method.
```objectivec

if (blockSignature.numberOfArguments > methodSignature.numberOfArguments) {
        signaturesMatch = NO;
    }else {
        if (blockSignature.numberOfArguments > 1) {
            const char *blockType = [blockSignature getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }

```
First compare whether the method signatures have the same number of parameters. If they do not, they definitely do not match, so signaturesMatch = NO. If the parameter counts are equal, then compare whether the first parameter in the method we want to replace is \_cmd, whose corresponding Type is @. If it is not, that is also a mismatch, so signaturesMatch = NO. If both of the above conditions are satisfied, signaturesMatch = YES, and then we proceed to the stricter comparison below.
```objectivec

     if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < blockSignature.numberOfArguments; idx++) {
                const char *methodType = [methodSignature getArgumentTypeAtIndex:idx];
                const char *blockType = [blockSignature getArgumentTypeAtIndex:idx];
                // Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }


```
Here, the loop also starts from 2. Let’s use an example to explain why the comparison starts from the second position. We’ll use the previous example again.
```objectivec

[UIView aspect_hookSelector:@selector(UIView:atIndex:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspects, UIView *view, NSInteger index)
 {
     
     NSLog(@"Button tapped %ld",index);
     
 } error:nil];

```
The original method I want to replace here is UIView:atIndex:, so the corresponding Type is v@:@q. Based on the analysis above, the blockSignature here is the Type produced by the previous conversion call, which should be v@?@"<AspectInfo>"@"UIView"q.

![](https://img.halfrost.com/Blog/ArticleImage/27_7.png)


Both the return value of methodSignature and blockSignature are void, so both correspond to v. argument 0 of methodSignature is the implicit parameter self, so it corresponds to @. argument 0 of blockSignature is the block, so it corresponds to @?. argument 1 of methodSignature is the implicit parameter _cmd, so it corresponds to :. argument 1 of blockSignature is <AspectInfo>, so it corresponds to @"<AspectInfo>". Starting from argument 2, the parameter lists corresponding to the method signature may differ and need to be compared.

Finally
```objectivec

    if (!signaturesMatch) {
        NSString *description = [NSString stringWithFormat:@"Block signature %@ doesn't match %@.", blockSignature, methodSignature];
        AspectError(AspectErrorIncompatibleBlockSignature, description);
        return NO;
    }


```
If `signaturesMatch` is `NO` after the comparisons above, an error is thrown: the Block cannot match the method signature.
```objectivec

    AspectIdentifier *identifier = nil;
    if (blockSignature) {
        identifier = [AspectIdentifier new];
        identifier.selector = selector;
        identifier.block = block;
        identifier.blockSignature = blockSignature;
        identifier.options = options;
        identifier.object = object; // weak
    }
    return identifier;


```
If the match succeeds here, the entire blockSignature will be assigned to AspectIdentifier. This is why AspectIdentifier has a separate NSMethodSignature property.

AspectIdentifier also has another method, invokeWithInfo.
```objectivec

    // Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        AspectLogError(@"Block has too many arguments. Not calling %@", info);
        return NO;
    }


```
The comment makes this clear as well: this check was written by someone being overly compulsive. By the time execution reaches this point, the number of parameters in the block cannot be greater than the number of parameters in the original method signature.
```objectivec


    // The `self` of the block will be the AspectInfo. Optional.
    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&info atIndex:1];
    }


```
Store `AspectInfo` in `blockInvocation`.
```objectivec

 void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
         NSUInteger argSize;
         NSGetSizeAndAlignment(type, &argSize, NULL);
        
          if (!(argBuf = reallocf(argBuf, argSize))) {
            AspectLogError(@"Failed to allocate memory for block invocation.");
            return NO;
          }
        
        [originalInvocation getArgument:argBuf atIndex:idx];
        [blockInvocation setArgument:argBuf atIndex:idx];
   }
    
    [blockInvocation invokeWithTarget:self.block];

```
This section loops through the arguments extracted from `originalInvocation`, assigns them into `argBuf`, and then assigns them into `blockInvocation`. The reason the loop starts from 2 has already been explained above, so it will not be repeated here. Finally, it assigns `self.block` to the `Target` of `blockInvocation`.


![](https://img.halfrost.com/Blog/ArticleImage/27_8.png)


In summary, `AspectIdentifier` is the concrete content of an Aspect slice. It contains the specific information for a single Aspect, including when it should be executed and the concrete information required to execute the block, such as the method signature, arguments, and so on. The process of initializing `AspectIdentifier` is essentially the process of packaging the block we pass in into an `AspectIdentifier`.


##### 5. AspectsContainer


![](https://img.halfrost.com/Blog/ArticleImage/27_9.png)
```objectivec


// Tracks all aspects for an object/class.
@interface AspectsContainer : NSObject
- (void)addAspect:(AspectIdentifier *)aspect withOptions:(AspectOptions)injectPosition;
- (BOOL)removeAspect:(id)aspect;
- (BOOL)hasAspects;
@property (atomic, copy) NSArray *beforeAspects;
@property (atomic, copy) NSArray *insteadAspects;
@property (atomic, copy) NSArray *afterAspects;
@end

```
Corresponding implementation
```objectivec

#pragma mark - AspectsContainer

@implementation AspectsContainer

- (BOOL)hasAspects {
    return self.beforeAspects.count > 0 || self.insteadAspects.count > 0 || self.afterAspects.count > 0;
}

- (void)addAspect:(AspectIdentifier *)aspect withOptions:(AspectOptions)options {
    NSParameterAssert(aspect);
    NSUInteger position = options&AspectPositionFilter;
    switch (position) {
        case AspectPositionBefore:  self.beforeAspects  = [(self.beforeAspects ?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionInstead: self.insteadAspects = [(self.insteadAspects?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionAfter:   self.afterAspects   = [(self.afterAspects  ?:@[]) arrayByAddingObject:aspect]; break;
    }
}

- (BOOL)removeAspect:(id)aspect {
    for (NSString *aspectArrayName in @[NSStringFromSelector(@selector(beforeAspects)),
                                        NSStringFromSelector(@selector(insteadAspects)),
                                        NSStringFromSelector(@selector(afterAspects))]) {
        NSArray *array = [self valueForKey:aspectArrayName];
        NSUInteger index = [array indexOfObjectIdenticalTo:aspect];
        if (array && index != NSNotFound) {
            NSMutableArray *newArray = [NSMutableArray arrayWithArray:array];
            [newArray removeObjectAtIndex:index];
            [self setValue:newArray forKey:aspectArrayName];
            return YES;
        }
    }
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, before:%@, instead:%@, after:%@>", self.class, self, self.beforeAspects, self.insteadAspects, self.afterAspects];
}

@end

```
AspectsContainer is relatively easy to understand. `addAspect` places the Aspects into the corresponding arrays based on the aspect timing. `removeAspects` iterates through and removes all Aspects. `hasAspects` determines whether any Aspects exist.


AspectsContainer is a container for all Aspects of an object or class. Therefore, there are two types of containers.

It is worth noting that the arrays here are modified with `Atomic`. Regarding `Atomic`, note that by default, compiler-synthesized methods ensure atomicity through a locking mechanism. If a property has the `nonatomic` attribute, no synchronization lock is required.


##### 6. AspectTracker


![](https://img.halfrost.com/Blog/ArticleImage/27_10.png)
```objectivec


@interface AspectTracker : NSObject
- (id)initWithTrackedClass:(Class)trackedClass;
@property (nonatomic, strong) Class trackedClass;
@property (nonatomic, readonly) NSString *trackedClassName;
@property (nonatomic, strong) NSMutableSet *selectorNames;
@property (nonatomic, strong) NSMutableDictionary *selectorNamesToSubclassTrackers;
- (void)addSubclassTracker:(AspectTracker *)subclassTracker hookingSelectorName:(NSString *)selectorName;
- (void)removeSubclassTracker:(AspectTracker *)subclassTracker hookingSelectorName:(NSString *)selectorName;
- (BOOL)subclassHasHookedSelectorName:(NSString *)selectorName;
- (NSSet *)subclassTrackersHookingSelectorName:(NSString *)selectorName;
@end


```
Corresponding implementation
```objectivec

@implementation AspectTracker

- (id)initWithTrackedClass:(Class)trackedClass {
    if (self = [super init]) {
        _trackedClass = trackedClass;
        _selectorNames = [NSMutableSet new];
        _selectorNamesToSubclassTrackers = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)subclassHasHookedSelectorName:(NSString *)selectorName {
    return self.selectorNamesToSubclassTrackers[selectorName] != nil;
}

- (void)addSubclassTracker:(AspectTracker *)subclassTracker hookingSelectorName:(NSString *)selectorName {
    NSMutableSet *trackerSet = self.selectorNamesToSubclassTrackers[selectorName];
    if (!trackerSet) {
        trackerSet = [NSMutableSet new];
        self.selectorNamesToSubclassTrackers[selectorName] = trackerSet;
    }
    [trackerSet addObject:subclassTracker];
}
- (void)removeSubclassTracker:(AspectTracker *)subclassTracker hookingSelectorName:(NSString *)selectorName {
    NSMutableSet *trackerSet = self.selectorNamesToSubclassTrackers[selectorName];
    [trackerSet removeObject:subclassTracker];
    if (trackerSet.count == 0) {
        [self.selectorNamesToSubclassTrackers removeObjectForKey:selectorName];
    }
}
- (NSSet *)subclassTrackersHookingSelectorName:(NSString *)selectorName {
    NSMutableSet *hookingSubclassTrackers = [NSMutableSet new];
    for (AspectTracker *tracker in self.selectorNamesToSubclassTrackers[selectorName]) {
        if ([tracker.selectorNames containsObject:selectorName]) {
            [hookingSubclassTrackers addObject:tracker];
        }
        [hookingSubclassTrackers unionSet:[tracker subclassTrackersHookingSelectorName:selectorName]];
    }
    return hookingSubclassTrackers;
}
- (NSString *)trackedClassName {
    return NSStringFromClass(self.trackedClass);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@, trackedClass: %@, selectorNames:%@, subclass selector names: %@>", self.class, self, NSStringFromClass(self.trackedClass), self.selectorNames, self.selectorNamesToSubclassTrackers.allKeys];
}

@end

```
The `AspectTracker` class is used to track classes that are to be hooked. `trackedClass` is the class being tracked. `trackedClassName` is the name of the tracked class. `selectorNames` is an `NSMutableSet` that records the method names to be replaced via hooking; `NSMutableSet` is used to prevent replacing the same method multiple times. `selectorNamesToSubclassTrackers` is a dictionary where the key is `hookingSelectorName`, and the value is an `NSMutableSet` filled with `AspectTracker` instances.

The `addSubclassTracker` method adds an `AspectTracker` to the collection corresponding to a given `selectorName`. The `removeSubclassTracker` method removes an `AspectTracker` from the collection corresponding to a given `selectorName`. The `subclassTrackersHookingSelectorName` method is a union-find operation: given a `selectorName`, it recursively searches for all sets containing that `selectorName`, and finally merges these sets together as the return value.


#### IV. Preparation Before Aspects Hooking


![](https://img.halfrost.com/Blog/ArticleImage/27_11.png)


There are only two functions in the Aspects library: one for classes and one for instances.
```objectivec

+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error {
    return aspect_add((id)self, selector, options, block, error);
}

- (id<AspectToken>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error {
    return aspect_add(self, selector, options, block, error);
}

```
Both methods are implemented by calling the same method, aspect\_add; they merely pass different arguments. So we only need to start by examining aspect\_add.
```c

- aspect_hookSelector:(SEL)selector withOptions:(AspectOptions)options usingBlock:(id)block error:(NSError **)error
└── aspect_add(self, selector, options, block, error);
    └── aspect_performLocked
        ├── aspect_isSelectorAllowedAndTrack
        └── aspect_prepareClassAndHookSelector

```
This is the function call stack. Start analyzing from aspect\_add.
```objectivec

static id aspect_add(id self, SEL selector, AspectOptions options, id block, NSError **error) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(block);

    __block AspectIdentifier *identifier = nil;
    aspect_performLocked(^{
        if (aspect_isSelectorAllowedAndTrack(self, selector, options, error)) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, selector);
            identifier = [AspectIdentifier identifierWithSelector:selector object:self options:options block:block error:error];
            if (identifier) {
                [aspectContainer addAspect:identifier withOptions:options];

                // Modify the class to allow message interception.
                aspect_prepareClassAndHookSelector(self, selector, error);
            }
        }
    });
    return identifier;
}

```
The aspect\_add function has five parameters in total. The first parameter is self; selector is the SEL passed in from the outside that needs to be hooked; options specifies the timing of the aspect; block is the execution method for the aspect; and the final error parameter is for errors.

aspect\_performLocked is a spin lock. A spin lock is a relatively efficient type of lock, much more efficient than @synchronized.
```objectivec

static void aspect_performLocked(dispatch_block_t block) {
    static OSSpinLock aspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&aspect_lock);
    block();
    OSSpinLockUnlock(&aspect_lock);
}

```
If you’re not familiar with the eight major locks in iOS, you can read the following two articles:

[Common iOS Knowledge Points (Part 3): Lock](http://www.jianshu.com/p/ddbe44064ca4)    
[An In-depth Look at Locks in iOS Development](http://www.jianshu.com/p/8781ff49e05b)


![](https://img.halfrost.com/Blog/ArticleImage/27_12.png)


However, spin locks can also run into problems:

If a low-priority thread acquires the lock and accesses a shared resource, and then a high-priority thread also attempts to acquire the lock, the high-priority thread will enter the busy-wait state of the spin lock and consume a large amount of CPU. At this point, the low-priority thread cannot compete with the high-priority thread for CPU time, which causes the task to remain unfinished for a long time and prevents the `lock` from being released. [OSSpinLock Is No Longer Safe](http://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/)

The problem with OSSpinLock is that if the threads accessing the lock do not have the same priority, there is a potential risk of deadlock.

Here, we temporarily assume the threads have the same priority, so OSSpinLock guarantees thread safety. In other words, `aspect_performLocked` protects the thread safety of the block.

Now only the `aspect_isSelectorAllowedAndTrack` function and the `aspect_prepareClassAndHookSelector` function remain.

Next, let’s first look at the implementation of the `aspect_isSelectorAllowedAndTrack` function.
```objectivec

    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"forwardInvocation:", nil];
    });

```
An NSSet is first defined as a “blacklist” containing function names that are not allowed to be hooked. retain, release, autorelease, and forwardInvocation: are not allowed to be hooked.
```objectivec

    NSString *selectorName = NSStringFromSelector(selector);
    if ([disallowedSelectorList containsObject:selectorName]) {
        NSString *errorDescription = [NSString stringWithFormat:@"Selector %@ is blacklisted.", selectorName];
        AspectError(AspectErrorSelectorBlacklisted, errorDescription);
        return NO;
    }


```
Immediately report an error when the selector’s function name is detected to be in the blacklist.
```objectivec

    AspectOptions position = options&AspectPositionFilter;
    if ([selectorName isEqualToString:@"dealloc"] && position != AspectPositionBefore) {
        NSString *errorDesc = @"AspectPositionBefore is the only valid position when hooking dealloc.";
        AspectError(AspectErrorSelectorDeallocPosition, errorDesc);
        return NO;
    }

```
Check again: if `dealloc` is to be aspected, the aspect position can only be before `dealloc`; if it is not `AspectPositionBefore`, an error should also be reported.
```objectivec

    if (![self respondsToSelector:selector] && ![self.class instancesRespondToSelector:selector]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Unable to find selector -[%@ %@].", NSStringFromClass(self.class), selectorName];
        AspectError(AspectErrorDoesNotRespondToSelector, errorDesc);
        return NO;
    }

```
When the selector is no longer on the blacklist, if the slice is `dealloc` and the selector is registered before it, you should check whether the method exists. If the selector cannot be found on either `self` or `self.class`, an error will be reported indicating that the method cannot be found.
```objectivec

    if (class_isMetaClass(object_getClass(self))) {
        Class klass = [self class];
        NSMutableDictionary *swizzledClassesDict = aspect_getSwizzledClassesDict();
        Class currentClass = [self class];

        AspectTracker *tracker = swizzledClassesDict[currentClass];
        if ([tracker subclassHasHookedSelectorName:selectorName]) {
            NSSet *subclassTracker = [tracker subclassTrackersHookingSelectorName:selectorName];
            NSSet *subclassNames = [subclassTracker valueForKey:@"trackedClassName"];
            NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already hooked subclasses: %@. A method can only be hooked once per class hierarchy.", selectorName, subclassNames];
            AspectError(AspectErrorSelectorAlreadyHookedInClassHierarchy, errorDescription);
            return NO;
        }

```
class\_isMetaClass first checks whether it is a metaclass. The subsequent checks determine whether methods in the metaclass are allowed to be replaced.

subclassHasHookedSelectorName checks whether the current tracker’s subclass contains selectorName. This is because a method can only be hooked once within a class hierarchy. If the tracker already contains it once, an error will be reported.
```objectivec

        do {
            tracker = swizzledClassesDict[currentClass];
            if ([tracker.selectorNames containsObject:selectorName]) {
                if (klass == currentClass) {
                    // Already modified and topmost!
                    return YES;
                }
                NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already hooked in %@. A method can only be hooked once per class hierarchy.", selectorName, NSStringFromClass(currentClass)];
                AspectError(AspectErrorSelectorAlreadyHookedInClassHierarchy, errorDescription);
                return NO;
            }
        } while ((currentClass = class_getSuperclass(currentClass)));


```
In this do-while loop, the check currentClass = class\_getSuperclass(currentClass) starts from currentClass's superclass and keeps walking up the hierarchy until it reaches the root class, NSObject.
```objectivec

        currentClass = klass;
        AspectTracker *subclassTracker = nil;
        do {
            tracker = swizzledClassesDict[currentClass];
            if (!tracker) {
                tracker = [[AspectTracker alloc] initWithTrackedClass:currentClass];
                swizzledClassesDict[(id<NSCopying>)currentClass] = tracker;
            }
            if (subclassTracker) {
                [tracker addSubclassTracker:subclassTracker hookingSelectorName:selectorName];
            } else {
                [tracker.selectorNames addObject:selectorName];
            }

            // All superclasses get marked as having a subclass that is modified.
            subclassTracker = tracker;
        }while ((currentClass = class_getSuperclass(currentClass)));

```
After the legality hook check above and the check that class methods cannot be replaced repeatedly, at this point, the information to be hooked can be recorded and marked using `AspectTracker`. During the marking process, once a subclass is changed, its superclass also needs to be marked accordingly. The termination condition of the do-while loop is still `currentClass = class\_getSuperclass(currentClass)`.

The above is the code for validating the legality of hooking class methods on a metaclass.


If it is not a metaclass, as long as the method being hooked is not one of `"retain"`, `"release"`, `"autorelease"`, or `"forwardInvocation:"`, and the timing for hooking the `"dealloc"` method must be `before`, and the selector can be found, then the method can be hooked.


After passing the legality check for whether the selector can be hooked, the next step is to obtain or create the `AspectsContainer` container.
```objectivec

// Loads or creates the aspect container.
static AspectsContainer *aspect_getContainerForObject(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(selector);
    AspectsContainer *aspectContainer = objc_getAssociatedObject(self, aliasSelector);
    if (!aspectContainer) {
        aspectContainer = [AspectsContainer new];
        objc_setAssociatedObject(self, aliasSelector, aspectContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectContainer;
}

```
Before reading or creating an AspectsContainer, the first step is to mark the selector.
```objectivec

static SEL aspect_aliasForSelector(SEL selector) {
    NSCParameterAssert(selector);
 return NSSelectorFromString([AspectsMessagePrefix stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
}

```
A constant string is defined in the global scope.
```objectivec


static NSString *const AspectsMessagePrefix = @"aspects_";

```
Use this string to mark all selectors by adding the prefix `"aspects_"`. Then retrieve the corresponding AssociatedObject. If it cannot be retrieved, create a new associated object. In the end, you get a selector with the `"aspects_"` prefix and its corresponding `aspectContainer`.

After obtaining the `aspectContainer`, you can start preparing the information for the method we want to hook. All of this information is stored in `AspectIdentifier`, so we need to create a new `AspectIdentifier`.

Call the `instancetype` method of `AspectIdentifier` to create a new `AspectIdentifier`.
```objectivec

+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error

```
This `instancetype` method can fail to create an instance in only one case: when `aspect\_isCompatibleBlockSignature` returns `NO`. Returning `NO` means that the method signatures of the replacement `block` and the original method being replaced do not match. (This function was explained in detail above, so it will not be repeated here.) Once the method signatures match successfully, an `AspectIdentifier` is created.
```objectivec

[aspectContainer addAspect:identifier withOptions:options];

```
The `aspectContainer` container adds it to the container. After the container and `AspectIdentifier` have been initialized, it can start preparing to perform the hook. Based on the `options` setting, it is added to the three arrays in the container: `beforeAspects`, `insteadAspects`, and `afterAspects`.
```objectivec

// Modify the class to allow message interception.
       aspect_prepareClassAndHookSelector(self, selector, error);

```
To summarize, here is what preparation work `aspect_add` performs:

1. It first calls `aspect_performLocked`, using a spin lock to ensure the entire operation is thread-safe.
2. It then calls `aspect_isSelectorAllowedAndTrack` to strictly validate the passed-in parameters and ensure they are legal.  
3. Next, it creates an `AspectsContainer` container, which is dynamically added to the `NSObject` category as a property using an Associated Object.
4. Then, based on the input parameters `selector` and `option`, it creates an `AspectIdentifier` instance. `AspectIdentifier` mainly contains the concrete information for a single Aspect, including the execution timing and the specific information needed to execute the block.
5. It then adds the concrete information of the individual `AspectIdentifier` to the `AspectsContainer` property container. Depending on the `options`, it is added to one of the three arrays in the container: `beforeAspects`, `insteadAspects`, or `afterAspects`.
6. Finally, it calls `prepareClassAndHookSelector` to prepare for the hook.

![](https://img.halfrost.com/Blog/ArticleImage/27_13.png)


#### 5. Detailed Explanation of the Aspects Hooking Process


First, let’s look at the function call stack.
```c

- aspect_prepareClassAndHookSelector(self, selector, error);
  ├── aspect_hookClass(self, error)
  │    ├──aspect_swizzleClassInPlace
  │    ├──aspect_swizzleForwardInvocation
  │    │  └──__ASPECTS_ARE_BEING_CALLED__
  │    │       ├──aspect_aliasForSelector
  │    │       ├──aspect_getContainerForClass
  │    │       ├──aspect_invoke
  │    │       └──aspect_remove
  │    └── aspect_hookedGetClass
  ├── aspect_isMsgForwardIMP
  ├──aspect_aliasForSelector(selector)
  └── aspect_getMsgForwardIMP

```
From the call stack, you can see that the Aspects hook process mainly consists of four stages: hookClass, ASPECTS\_ARE\_BEING\_CALLED, prepareClassAndHookSelector, and remove.


![](https://img.halfrost.com/Blog/ArticleImage/28_1.jpg)


##### 1. hookClass
```objectivec


 NSCParameterAssert(self);
 Class statedClass = self.class;
 Class baseClass = object_getClass(self);
 NSString *className = NSStringFromClass(baseClass);

```
`statedClass` and `baseClass` are different.
```objectivec

Class object_getClass(id obj)
{
    if (obj) return obj->getIsa();
    else return Nil;
}

+ (Class)class {
    return self;
}


```
`statedClass` gets the class object, while `baseClass` gets the class’s `isa`.
```objectivec

    // Already subclassed
 if ([className hasSuffix:AspectsSubclassSuffix]) {
  return baseClass;

        // We swizzle a class object, not a single object.
 }else if (class_isMetaClass(baseClass)) {
        return aspect_swizzleClassInPlace((Class)self);
        // Probably a KVO'ed class. Swizzle in place. Also swizzle meta classes in place.
    }else if (statedClass != baseClass) {
        return aspect_swizzleClassInPlace(baseClass);
    }

```
First determine whether `className` has the suffix `AspectsSubclassSuffix` using `hasSuffix:`.
```objectivec


static NSString *const AspectsSubclassSuffix = @"_Aspects_";


```
If it includes the @"\_Aspects\_" suffix, it means the class has already been hooked, so return directly.
If it does not include the @"\_Aspects\_" suffix, then check whether baseClass is a metaclass. If it is a metaclass, call aspect\_swizzleClassInPlace. If it is not a metaclass either, then check whether statedClass and baseClass are equal. If they are not equal, it means this is a KVO object, because the isa pointer of a KVO object points to an intermediate class. Call aspect\_swizzleClassInPlace on the KVO intermediate class.
```objectivec

static Class aspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_swizzleForwardInvocation(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}


```
\_aspect\_modifySwizzledClasses passes in a block whose parameter is (NSMutableSet \*swizzledClasses). Inside the block, it checks whether the Set contains the current ClassName. If it does not, it calls the aspect\_swizzleForwardInvocation() method and adds the className to the Set.
```objectivec

static void _aspect_modifySwizzledClasses(void (^block)(NSMutableSet *swizzledClasses)) {
    static NSMutableSet *swizzledClasses;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClasses = [NSMutableSet new];
    });
    @synchronized(swizzledClasses) {
        block(swizzledClasses);
    }
}

```
The \_aspect\_modifySwizzledClasses method ensures that the `swizzledClasses` Set is globally unique, and adds a thread lock `@synchronized( )` around the passed-in block, ensuring that the block invocation is thread-safe.

As for calling aspect\_swizzleForwardInvocation to point the original IMP to `forwardInvocation`, that belongs to the next stage. Let’s finish looking at `hookClass` first.
```objectivec

// Default case. Create dynamic subclass.
 const char *subclassName = [className stringByAppendingString:AspectsSubclassSuffix].UTF8String;
 Class subclass = objc_getClass(subclassName);

 if (subclass == nil) {
  subclass = objc_allocateClassPair(baseClass, subclassName, 0);
  if (subclass == nil) {
            NSString *errrorDesc = [NSString stringWithFormat:@"objc_allocateClassPair failed to allocate class %s.", subclassName];
            AspectError(AspectErrorFailedToAllocateClassPair, errrorDesc);
            return nil;
        }

  aspect_swizzleForwardInvocation(subclass);
  aspect_hookedGetClass(subclass, statedClass);
  aspect_hookedGetClass(object_getClass(subclass), statedClass);
  objc_registerClassPair(subclass);
 }

 object_setClass(self, subclass);

```
When `className` does not include the `@"_Aspects_"` suffix, and it is neither a metaclass nor a KVO intermediate class—that is, when `statedClass == baseClass`—a new subclass `subclass` is created by default.

At this point, we can understand the design philosophy of Aspects: **hooking is implemented on the basis of dynamically creating subclasses at runtime**. All swizzling operations occur on the subclass. The benefit of this approach is that you do not need to change the class of the object itself. In other words, when you remove aspects, if you find that all aspects on the current object have been removed, you can point the `isa` pointer back to the object’s original class, thereby eliminating the swizzling for that object, while also avoiding any impact on other instances of the same class. This has no effect on the originally replaced class or object, and aspects can be added or removed based on the subclass.

The newly created class name is first appended with the `AspectsSubclassSuffix` suffix—that is, `@"_Aspects_"` is appended to `className`—to mark it as a subclass. Then the `objc_getClass` method is called to create this subclass.
```objectivec

/***********************************************************************
* objc_getClass.  Return the id of the named class.  If the class does
* not exist, call _objc_classLoader and then objc_classHandler, either of 
* which may create a new class.
* Warning: doesn't work if aClassName is the name of a posed-for class's isa!
**********************************************************************/
Class objc_getClass(const char *aClassName)
{
    if (!aClassName) return Nil;

    // NO unconnected, YES class handler
    return look_up_class(aClassName, NO, YES);
}

```
objc\_getClass calls the look\_up\_class method.
```objectivec

/***********************************************************************
* look_up_class
* Look up a class by name, and realize it.
* Locking: acquires runtimeLock
**********************************************************************/
Class look_up_class(const char *name, 
              bool includeUnconnected __attribute__((unused)), 
              bool includeClassHandler __attribute__((unused)))
{
    if (!name) return nil;

    Class result;
    bool unrealized;
    {
        rwlock_reader_t lock(runtimeLock);
        result = getClass(name);
        unrealized = result  &&  !result->isRealized();
    }
    if (unrealized) {
        rwlock_writer_t lock(runtimeLock);
        realizeClass(result);
    }
    return result;
}


```
This method checks whether a class named `name` has been implemented. During the lookup, it uses `rwlock_reader_t lock(runtimeLock)`, a read-write lock implemented underneath with `pthread_rwlock_t`.

Since this is the name of a subclass we just created, `objc_getClass()` is very likely to return `nil`. In that case, we need to create this subclass by calling `objc_allocateClassPair()`.
```objectivec

/***********************************************************************
* objc_allocateClassPair
* fixme
* Locking: acquires runtimeLock
**********************************************************************/
Class objc_allocateClassPair(Class superclass, const char *name, 
                             size_t extraBytes)
{
    Class cls, meta;

    rwlock_writer_t lock(runtimeLock);

    // Fail if the class name is in use.
    // Fail if the superclass isn't kosher.
    if (getClass(name)  ||  !verifySuperclass(superclass, true/*rootOK*/)) {
        return nil;
    }

    // Allocate new classes.
    cls  = alloc_class_for_subclass(superclass, extraBytes);
    meta = alloc_class_for_subclass(superclass, extraBytes);

    // fixme mangle the name if it looks swift-y?
    objc_initializeClassPair_internal(superclass, name, cls, meta);

    return cls;
}

```
Calling objc\_allocateClassPair creates a new subclass whose superclass is the input parameter superclass.

If the newly created subclass subclass = = nil, an error is reported: objc\_allocateClassPair failed to allocate class.

aspect\_swizzleForwardInvocation(subclass) belongs to the next stage. Its main purpose is to replace the implementation of the current class’s forwardInvocation method with \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_, so we will skip it for now.

Next, aspect\_hookedGetClass( ) is called.
```objectivec


static void aspect_hookedGetClass(Class class, Class statedClass) {
    NSCParameterAssert(class);
    NSCParameterAssert(statedClass);
 Method method = class_getInstanceMethod(class, @selector(class));
 IMP newIMP = imp_implementationWithBlock(^(id self) {
  return statedClass;
 });
 class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

```
aspect\_hookedGetClass replaces the instance method class with an implementation that returns statedClass; in other words, when class is called, it makes isa point to statedClass.
```objectivec

  aspect_hookedGetClass(subclass, statedClass);
  aspect_hookedGetClass(object_getClass(subclass), statedClass);

```
Now we understand the intent of these two lines.

The first line points the `isa` of `subclass` to `statedClass`; the second line points the `isa` of `subclass`’s metaclass to `statedClass` as well.

Finally, it calls objc\_registerClassPair( ) to register the newly created subclass `subclass`, and then calls object\_setClass(self, subclass); to point the current `self`’s `isa` to the subclass `subclass`.

At this point, the `hookClass` phase is complete: `self` has been successfully hooked into its subclass xxx\_Aspects\_.

![](https://img.halfrost.com/Blog/ArticleImage/28_2.png)


##### 2. ASPECTS\_ARE\_BEING\_CALLED


In the previous `hookClass` phase, the aspect\_swizzleForwardInvocation method was called in several places.
```objectivec

static NSString *const AspectsForwardInvocationSelectorName = @"__aspects_forwardInvocation:";

static void aspect_swizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    // If there is no method, replace will act like class_addMethod.
    IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
    }
    AspectLog(@"Aspects: %@ is now aspect aware.", NSStringFromClass(klass));
}

```
aspect\_swizzleForwardInvocation is the entry point for the entire Aspects hook mechanism.
```objectivec

/***********************************************************************
* class_replaceMethod
**********************************************************************/
IMP class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
{
    if (!cls) return nil;

    return _class_addMethod(cls, name, imp, types, YES);
}

```
Calling the class\_replaceMethod method; the underlying implementation actually calls the \_class\_addMethod method.
```objectivec

static IMP _class_addMethod(Class cls, SEL name, IMP imp, 
                            const char *types, bool replace)
{
    old_method *m;
    IMP result = nil;

    if (!types) types = "";

    mutex_locker_t lock(methodListLock);

    if ((m = _findMethodInClass(cls, name))) {
        // already exists
        // fixme atomic
        result = method_getImplementation((Method)m);
        if (replace) {
            method_setImplementation((Method)m, imp);
        }
    } else {
        // fixme could be faster
        old_method_list *mlist = 
            (old_method_list *)calloc(sizeof(old_method_list), 1);
        mlist->obsolete = fixed_up_method_list;
        mlist->method_count = 1;
        mlist->method_list[0].method_name = name;
        mlist->method_list[0].method_types = strdup(types);
        if (!ignoreSelector(name)) {
            mlist->method_list[0].method_imp = imp;
        } else {
            mlist->method_list[0].method_imp = (IMP)&_objc_ignored_method;
        }
        
        _objc_insertMethods(cls, mlist, nil);
        if (!(cls->info & CLS_CONSTRUCTING)) {
            flush_caches(cls, NO);
        } else {
            // in-construction class has no subclasses
            flush_cache(cls);
        }
        result = nil;
    }

    return result;
}

```
From the source code above, we can see that it first calls \_findMethodInClass(cls, name) to look for a method named name in cls. If it exists and the corresponding IMP can be found, it replaces it via method\_setImplementation((Method)m, imp), replacing the IMP of the name method with imp. In this case, \_class\_addMethod returns the IMP corresponding to the name method, which is actually the imp we just replaced it with.

If the name method is not found in cls, then the method is added by inserting a new name method at mlist \-\> method\_list[0], with the corresponding IMP being the passed-in imp. In this case, \_class\_addMethod returns nil.


Returning to aspect\_swizzleForwardInvocation,
```objectivec

IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
if (originalImplementation) {
   class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
}

```
Replace the IMP of `forwardInvocation:` with \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_. If the `forwardInvocation:` method cannot be found in `klass`, this method will be added.

~~Because the subclass itself does not implement `forwardInvocation`, the returned `originalImplementation` will be nil, so `NSSelectorFromString(AspectsForwardInvocationSelectorName)` will not be generated either. Therefore, \_class\_addMethod is also needed to add the implementation of the `forwardInvocation:` method for us.~~

Thanks to the Jianshu expert @zhao0 for pointing this out. This pitfall has already been fixed in Aspects 1.4.1.

In `aspect\_swizzleForwardInvocation`, `class\_replaceMethod` returns the IMP of the original method. If `originalImplementation` is not nil, it means the original method has an implementation. A new method \_\_aspects\_forwardInvocation: is added and points to the original `originalImplementation`. In \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_, if it cannot handle the invocation, it checks whether \_\_aspects_forwardInvocation is implemented; if so, it forwards to it. This solves the compatibility issue.


If the returned `originalImplementation` is not nil, it means the replacement has succeeded. After replacing the method, we add another method named “\_\_aspects\_forwardInvocation:” to `klass`, whose corresponding implementation is also (IMP)\_\_ASPECTS\_ARE_BEING\_CALLED\_\_.


Next comes the core implementation of Aspects: \_\_ASPECTS\_ARE_BEING\_CALLED\_\_
```objectivec

static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    SEL originalSelector = invocation.selector;
    SEL aliasSelector = aspect_aliasForSelector(invocation.selector);
    invocation.selector = aliasSelector;
    AspectsContainer *objectContainer = objc_getAssociatedObject(self, aliasSelector);
    AspectsContainer *classContainer = aspect_getContainerForClass(object_getClass(self), aliasSelector);
    AspectInfo *info = [[AspectInfo alloc] initWithInstance:self invocation:invocation];
    NSLog(@"%@",info.arguments);
    NSArray *aspectsToRemove = nil;

    …… ……
}
```
This section covers the preparation before the hook:

1. Get the original selector
2. Get the method with the `aspects_xxxx` prefix
3. Replace the selector
4. Get the instance object container `objectContainer`; this is the object previously associated via `aspect_add`.
5. Get the class object container `classContainer`
6. Initialize `AspectInfo`, passing in the `self` and `invocation` parameters.
```objectivec

    // Before hooks.
    aspect_invoke(classContainer.beforeAspects, info);
    aspect_invoke(objectContainer.beforeAspects, info);

```
Invoke Macro Definitions to Execute Aspects Slicing Functionality
```objectivec

#define aspect_invoke(aspects, info) \
for (AspectIdentifier *aspect in aspects) {\
    [aspect invokeWithInfo:info];\
    if (aspect.options & AspectOptionAutomaticRemoval) { \
        aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; \
    } \
}

```
The reason a macro is used here to implement this functionality is to obtain clearer stack information.

The macro does two things: it calls the `[aspect invokeWithInfo:info]` method, and it adds the Aspects that need to be removed to the array waiting for removal.

The implementation of `[aspect invokeWithInfo:info]` was analyzed in detail in the previous article. The main purpose of this function is to initialize `blockSignature` and obtain an `invocation` from it. It then processes the parameters: if the number of parameters in the block is greater than 1, it puts the incoming `AspectInfo` into `blockInvocation`. Then it takes the parameters from `originalInvocation` and assigns them to `blockInvocation`. Finally, it calls `[blockInvocation invokeWithTarget:self.block];`, where the target is set to `self.block`. This executes the block for the method we hooked.

So as long as `aspect_invoke(classContainer.Aspects, info);`, the core replacement method, is called, we can hook the original `SEL`. Correspondingly, by passing `classContainer.beforeAspects`, `classContainer.insteadAspects`, and `classContainer.afterAspects` as the first argument to the function, we can implement hooks for the Aspects slices at the corresponding `before`, `instead`, and `after` points in time.
```objectivec

    // Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadAspects.count || classContainer.insteadAspects.count) {
        aspect_invoke(classContainer.insteadAspects, info);
        aspect_invoke(objectContainer.insteadAspects, info);
    }else {
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }


```
This code implements Instead hooks. It first checks whether the current insteadAspects contains any data. If it does not, it then checks whether the current inheritance chain can respond to the aspects\_xxx method. If it can, aliasSelector is called directly. **Note: here, aliasSelector is the original method**
```objectivec

    // After hooks.
    aspect_invoke(classContainer.afterAspects, info);
    aspect_invoke(objectContainer.afterAspects, info);


```
These two lines execute the corresponding After hooks. The principle is as described above.

At this point, all executable hooks in the Aspects slices for the before, instead, and after timings have finished executing.

If the hook was not executed normally, then the original method should be executed.
```objectivec

    // If no hooks are installed, call original implementation (usually to throw an exception)
    if (!respondsToAlias) {
        invocation.selector = originalSelector;
        SEL originalForwardInvocationSEL = NSSelectorFromString(AspectsForwardInvocationSelectorName);
        if ([self respondsToSelector:originalForwardInvocationSEL]) {
            ((void( *)(id, SEL, NSInvocation *))objc_msgSend)(self, originalForwardInvocationSEL, invocation);
        }else {
            [self doesNotRecognizeSelector:invocation.selector];
        }
    }

```
First switch invocation.selector back to the original originalSelector. If the hook did not succeed, AspectsForwardInvocationSelectorName can still retrieve the SEL corresponding to the original IMP. If it can respond to it, call the original SEL; otherwise, raise a doesNotRecognizeSelector error.
```objectivec

[aspectsToRemove makeObjectsPerformSelector:@selector(remove)];

```
Finally, call the removal method to remove the hook.

![](https://img.halfrost.com/Blog/ArticleImage/28_3.png)


##### 3. prepareClassAndHookSelector

Now we need to return to the aspect\_prepareClassAndHookSelector method mentioned in the previous article.
```objectivec

static void aspect_prepareClassAndHookSelector(NSObject *self, SEL selector, NSError **error) {
    NSCParameterAssert(selector);
    Class klass = aspect_hookClass(self, error);
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!aspect_isMsgForwardIMP(targetMethodIMP)) {
        // Make a method alias for the existing method implementation, it not already copied.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        if (![klass instancesRespondToSelector:aliasSelector]) {
            __unused BOOL addedAlias = class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        }

        // We use forwardInvocation to hook in.
        class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);
        AspectLog(@"Aspects: Installed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }
}

```
`klass` is the subclass we obtain after hooking the original class. Its name has the `_Aspects_` suffix. Because it is a subclass of the current class, we can also retrieve the original selector’s `IMP` from it.
```objectivec

static BOOL aspect_isMsgForwardIMP(IMP impl) {
    return impl == _objc_msgForward

#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret

#endif
    ;
}


```
This checks whether the current IMP is `\_objc\_msgForward` or `\_objc\_msgForward\_stret`, i.e. whether the current IMP is message forwarding.

If it is not message forwarding, first obtain the method encoding typeEncoding of the IMP corresponding to the original selector.

If the subclass cannot respond to aspects\_xxxx, add the aspects\_xxxx method to klass, with the implementation set to the native method’s implementation.

The entry point for Aspects’ entire hook mechanism is this line:
```objectivec

class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);

```
Since we point the selector to \_objc\_msgForward and \_objc\_msgForward\_stret, it follows that when the selector is executed, message forwarding will also be triggered and execution will enter forwardInvocation. Since we have also swizzled forwardInvacation, control ultimately transitions into our own handling logic.


![](https://img.halfrost.com/Blog/ArticleImage/28_4.png)
 


##### 4. aspect\_remove

Function call stack for the entire aspect\_remove teardown process.
```c

- aspect_remove(AspectIdentifier *aspect, NSError **error)
  └── aspect_cleanupHookedClassAndSelector
      ├──aspect_deregisterTrackedSelector
      │   └── aspect_getSwizzledClassesDict
      ├──aspect_destroyContainerForObject
      └── aspect_undoSwizzleClassInPlace
          └── _aspect_modifySwizzledClasses
                └──aspect_undoSwizzleForwardInvocation

```


```objectivec

static BOOL aspect_remove(AspectIdentifier *aspect, NSError **error) {
    NSCAssert([aspect isKindOfClass:AspectIdentifier.class], @"Must have correct type.");
    
    __block BOOL success = NO;
    aspect_performLocked(^{
        id self = aspect.object; // strongify
        if (self) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, aspect.selector);
            success = [aspectContainer removeAspect:aspect];
            
            aspect_cleanupHookedClassAndSelector(self, aspect.selector);
            // destroy token
            aspect.object = nil;
            aspect.block = nil;
            aspect.selector = NULL;
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", aspect];
            AspectError(AspectErrorRemoveObjectAlreadyDeallocated, errrorDesc);
        }
    });
    return success;
}


```
aspect\_remove is the inverse of the entire aspect\_add process.
aspect\_performLocked ensures thread safety. It sets all AspectsContainer instances to nil; the most critical step in remove is aspect\_cleanupHookedClassAndSelector(self, aspect.selector);, which removes the class and selector that were hooked earlier.
```objectivec


static void aspect_cleanupHookedClassAndSelector(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    
    Class klass = object_getClass(self);
    BOOL isMetaClass = class_isMetaClass(klass);
    if (isMetaClass) {
        klass = (Class)self;
    }

    ……  ……
}

```
`klass` is the current class; if it is a metaclass, convert it to the metaclass.
```objectivec

    // Check if the method is marked as forwarded and undo that.
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (aspect_isMsgForwardIMP(targetMethodIMP)) {
        // Restore the original method implementation.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        Method originalMethod = class_getInstanceMethod(klass, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        
        class_replaceMethod(klass, selector, originalIMP, typeEncoding);
        AspectLog(@"Aspects: Removed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }


```
First, respond to the `MsgForward` message-forwarding function to obtain the method signature, then replace the original forwarding method with the method we hooked.

There is one issue to be aware of here.

If the current `Student` has two instances, `stu1` and `stu2`, and both of them hook the same method `study()`, after `stu2` executes `aspect_remove` and restores `stu2`’s `study()` method, this will also restore `stu1`’s `study()` method. This is because the `remove` operation applies to all instances of the entire class.

To allow each instance to restore its own method without affecting other instances, simply delete the code above. When the `remove` operation is executed, the data structures related to that object have actually already been cleared. Even if `stu2`’s `study()` implementation is not restored, when execution enters `__ASPECTS_ARE_BEING_CALLED__`, since there are no aspects responding to it, it will directly fall through to the original handling logic and will not have any additional side effects.
```objectivec

static void aspect_deregisterTrackedSelector(id self, SEL selector) {
    if (!class_isMetaClass(object_getClass(self))) return;
    
    NSMutableDictionary *swizzledClassesDict = aspect_getSwizzledClassesDict();
    NSString *selectorName = NSStringFromSelector(selector);
    Class currentClass = [self class];
    AspectTracker *subclassTracker = nil;
    do {
        AspectTracker *tracker = swizzledClassesDict[currentClass];
        if (subclassTracker) {
            [tracker removeSubclassTracker:subclassTracker hookingSelectorName:selectorName];
        } else {
            [tracker.selectorNames removeObject:selectorName];
        }
        if (tracker.selectorNames.count == 0 && tracker.selectorNamesToSubclassTrackers) {
            [swizzledClassesDict removeObjectForKey:currentClass];
        }
        subclassTracker = tracker;
    }while ((currentClass = class_getSuperclass(currentClass)));
}


```
Also remove all marked `swizzledClassesDict` entries in `AspectTracker`. Destroy all recorded selectors.
```objectivec

   AspectsContainer *container = aspect_getContainerForObject(self, selector);
    if (!container.hasAspects) {
        // Destroy the container
        aspect_destroyContainerForObject(self, selector);
        
        // Figure out how the class was modified to undo the changes.
        NSString *className = NSStringFromClass(klass);
        if ([className hasSuffix:AspectsSubclassSuffix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:AspectsSubclassSuffix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            object_setClass(self, originalClass);
            AspectLog(@"Aspects: %@ has been restored.", NSStringFromClass(originalClass));
            
            // We can only dispose the class pair if we can ensure that no instances exist using our subclass.
            // Since we don't globally track this, we can't ensure this - but there's also not much overhead in keeping it around.
            //objc_disposeClassPair(object.class);
        }else {
            // Class is most likely swizzled in place. Undo that.
            if (isMetaClass) {
                aspect_undoSwizzleClassInPlace((Class)self);
            }else if (self.class != klass) {
                aspect_undoSwizzleClassInPlace(klass);
            }
        }
    }


```
Finally, we also need to reconstruct the class’s `AssociatedObject` associated objects, as well as the `AspectsContainer` container it uses.
```objectivec

static void aspect_destroyContainerForObject(id<NSObject> self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(selector);
    objc_setAssociatedObject(self, aliasSelector, nil, OBJC_ASSOCIATION_RETAIN);
}

```
This method destroys the `AspectsContainer` container and also sets the associated object to `nil`.
```objectivec


static void aspect_undoSwizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);
    
    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            aspect_undoSwizzleForwardInvocation(klass);
            [swizzledClasses removeObject:className];
        }
    });
}


```
aspect\_undoSwizzleClassInPlace then calls the aspect\_undoSwizzleForwardInvocation method.
```objectivec

static void aspect_undoSwizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    Method originalMethod = class_getInstanceMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName));
    Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
    // There is no class_removeMethod, so the best we can do is to retore the original implementation, or use a dummy.
    IMP originalImplementation = method_getImplementation(originalMethod ?: objectMethod);
    class_replaceMethod(klass, @selector(forwardInvocation:), originalImplementation, "v@:@");
    
    AspectLog(@"Aspects: %@ has been restored.", NSStringFromClass(klass));
}

```
Finally, restore the Swizzling of ForwardInvocation by swapping the original ForwardInvocation back.


#### VI. Some “Pitfalls” in Aspects


![](https://img.halfrost.com/Blog/ArticleImage/28_5.png)


In the Aspects library, Method Swizzling is used in several places. If these places are not handled properly, you can easily fall into “pitfalls.”


##### 1. Pitfalls You May Encounter in aspect\_prepareClassAndHookSelector

In the aspect\_prepareClassAndHookSelector method, the original selector is hooked to \_objc\_msgForward. But what happens if the selector here is already \_objc\_msgForward?

In fact, this pitfall is already hinted at in a hidden way in the author’s code comments.


In the \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_ method, there is the following comment in the final piece of code that forwards the message:
```c

// If no hooks are installed, call original implementation (usually to throw an exception)

```
After seeing this comment, you’ll probably wonder: why does it throw an exception at this point? The reason is that the IMP corresponding to NSSelectorFromString(AspectsForwardInvocationSelectorName) cannot be found.

If you look further up, you can find the cause. In the implementation of aspect\_prepareClassAndHookSelector, it checks whether the current selector is \_objc\_msgForward. If it is not msgForward, nothing else is done afterward. As a result, aliasSelector has no corresponding implementation.


Because forwardInvocation has been hooked by aspects, execution eventually enters Aspects’ handling logic \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_. At this point, if the IMP implementation for aliasSelector cannot be found, message forwarding will occur here. Moreover, the subclass does not implement NSSelectorFromString(AspectsForwardInvocationSelectorName), so the forwarding will throw an exception.

The “gotcha” here is that if the hooked selector becomes \_objc\_msgForward, an exception will occur. But in general, we do not hook the \_objc\_msgForward method directly. The reason this problem appears is that some other Swizzling logic hooks this method.


For example, JSPatch first hooks the incoming selector. In that case, we will not process it here, and aliasSelector will not be generated. This leads to a crash exception.
```objectivec

static Class aspect_hookClass(NSObject *self, NSError **error) {
    ...
    subclass = objc_allocateClassPair(baseClass, subclassName, 0);
    ...
    IMP originalImplementation = class_replaceMethod(subclass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(subclass, NSSelectorFromString(AspectsForwardInvocationSelectorName),   originalImplementation, "v@:@");
    } else {
        Method baseTargetMethod = class_getInstanceMethod(baseClass, @selector(forwardInvocation:));
        IMP baseTargetMethodIMP = method_getImplementation(baseTargetMethod);
        if (baseTargetMethodIMP) {
            class_addMethod(subclass, NSSelectorFromString(AspectsForwardInvocationSelectorName), baseTargetMethodIMP, "v@:@");
        }
    }
    ...
}


```
Here is a solution provided in this [article](http://wereadteam.github.io/2016/06/30/Aspects/):

Instead of simply replacing the subclass's forwardInvocation method, swap it. The implementation logic is as follows: forcibly generate an NSSelectorFromString(AspectsForwardInvocationSelectorName) that points to the original object's forwardInvocation implementation.


Note that if originalImplementation is empty, the generated NSSelectorFromString(AspectsForwardInvocationSelectorName)
will point to baseClass, that is, the actual object's forwradInvocation. This is in fact the method hooked by JSPatch. At the same time, to guarantee the execution order of the blocks (that is, the before hooks / instead hooks / after hooks described earlier), this code needs to be moved ahead of the after hooks execution. This resolves the conflict that occurs after forwardInvocation has already been hooked externally.


Thanks to the JianShu expert @zhao0 for the guidance. This article provides a detailed analysis of [various compatibility issues between Aspect and JSPatch](http://www.jianshu.com/p/dc1deaa1b28e). After a detailed analysis, there are ultimately only four incompatible cases.


##### 2. Potential “pitfalls” in aspect\_hookSelector

In Aspects, the main operation is hooking selectors. At this point, if multiple places hook the same method as Aspects, a doesNotRecognizeSelector issue may also occur.

For example, suppose Aspects is used in NSArray to hook the objectAtIndex method, and then the objectAtIndex method is swizzled in NSMutableArray. In
NSMutableArray, calling objectAtIndex may cause an error.


The reason is still that after Aspects hooks a selector, it changes the original selector to \_objc\_msgForward. When NSMutableArray later hooks this method, the recorded IMP is already \_objc\_msgForward. If objc\_msgSend executes the original implementation at this point, an error will occur. Because the original implementation has already been replaced by \_objc\_msgForward, and the real IMP was swizzled away by Aspects first, it can no longer be found.


The solution is still similar to JSPatch's approach:

Also swizzle -forwardInvocation:. In your own -forwardInvocation: method, perform the same operation: inspect the Selector of the incoming NSInvocation and check whether the swizzled method points to \_objc\_msgForward (or \_objc\_msgForward\_stret). If it is a Selector that you can recognize, change the Selector back to the original Selector before execution; if it cannot be recognized, forward it directly.


#### Finally

Finally, use one diagram to summarize the overall Aspects flow:


![](https://img.halfrost.com/Blog/ArticleImage/28_6.png)


Feedback and suggestions are welcome.