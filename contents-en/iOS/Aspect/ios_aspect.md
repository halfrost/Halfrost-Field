# How iOS Implements Aspect Oriented Programming

![](https://img.halfrost.com/Blog/ArticleTitleImage/27_0_.jpg)


#### Preface

During the last two days of my stay in the “Runtime Hospital,” I analyzed the implementation principles of AOP. After I was “discharged,” I realized that the Aspects library had not yet been analyzed in detail, which led to this article. Today, let’s talk about how iOS implements Aspect Oriented Programming.


#### Table of Contents
- 1.Introduction to Aspect Oriented Programming
- 2.What Is Aspects
- 3.Analysis of the 4 Core Classes in Aspects
- 4.Preparation Before Hooking with Aspects
- 5.Detailed Explanation of the Aspects Hooking Process
- 6.Some “Pitfalls” in Aspects

#### I. Introduction to Aspect Oriented Programming

**Aspect-oriented programming** (AOP, also translated as **aspect-based programming**, **viewpoint-oriented programming**, or **profile-oriented programming**) is a term in [computer science](https://zh.wikipedia.org/wiki/%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6) that refers to a [programming paradigm](https://zh.wikipedia.org/wiki/%E7%A8%8B%E5%BA%8F%E8%AE%BE%E8%AE%A1%E8%8C%83%E5%9E%8B). This paradigm is based on a language construct called an **aspect**, a new modularization mechanism used to describe **crosscutting concerns** scattered across [objects](https://zh.wikipedia.org/wiki/%E5%AF%B9%E8%B1%A1_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6)), [classes](https://zh.wikipedia.org/wiki/%E7%B1%BB_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6)), or [functions](https://zh.wikipedia.org/wiki/%E5%87%BD%E6%95%B0_(%E8%AE%A1%E7%AE%97%E6%9C%BA%E7%A7%91%E5%AD%A6)).

The concept of aspects originated as an improvement to [object-oriented programming](https://zh.wikipedia.org/wiki/%E9%9D%A2%E5%90%91%E5%AF%B9%E8%B1%A1%E7%9A%84%E7%A8%8B%E5%BA%8F%E8%AE%BE%E8%AE%A1), but it is not limited to that; it can also be used to improve traditional functions. Programming concepts related to aspects also include [metaobject protocol](https://zh.wikipedia.org/w/index.php?title=%E5%85%83%E5%AF%B9%E8%B1%A1%E5%8D%8F%E8%AE%AE&action=edit&redlink=1), subject, [mixin](https://zh.wikipedia.org/w/index.php?title=%E6%B7%B7%E5%85%A5&action=edit&redlink=1), and delegation.

AOP is a technique for uniformly maintaining program functionality through precompilation and runtime **dynamic proxying**.

OOP (object-oriented programming) **abstracts and encapsulates** the **entities**, their **attributes**, and their **behaviors** in a business process to achieve a clearer and more efficient division of logical units.

AOP, on the other hand, extracts **aspects** from a business process. It focuses on a particular **step** or **stage** in the process, in order to achieve a low-coupling **isolation effect** among the different parts of the logical flow.


OOP and AOP represent two different “ways of thinking.” OOP focuses on encapsulating the attributes and behaviors of objects, while AOP focuses on a certain step or stage of processing and extracts aspects from it.

For example, suppose there is a requirement to check permissions. The OOP approach would certainly be to add a permission check before every operation. What about logging? You would add logging at the beginning and end of every method. AOP extracts these repeated pieces of logic and operations, and uses dynamic proxying to decouple these modules. OOP and AOP are not mutually exclusive; they complement each other.

Using AOP for programming in iOS makes non-intrusive changes possible. You can add new functionality without modifying the existing code logic. It is mainly used to handle crosscutting system-level services, such as logging, permission management, caching, object pool management, and so on.


#### II. What Is Aspects
 
![](https://img.halfrost.com/Blog/ArticleImage/27_1.png)


[Aspects](https://github.com/steipete/Aspects) is a lightweight aspect-oriented programming library. It allows you to inject arbitrary code into methods that exist on any class or any instance. You can insert code at the following join points: before (execute before the original method) / instead (replace execution of the original method) / after (execute after the original method, the default). Hooking is implemented through Runtime message forwarding. Aspects automatically calls the super method, making it more convenient to use than method swizzling.

This library is quite stable and is currently used in hundreds of apps. It is also part of PSPDFKit; [PSPDFKit](http://pspdfkit.com/) is an iOS framework library for viewing PDFs. The author eventually decided to open-source it.


#### III. Analysis of the 4 Core Classes in Aspects

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
An enum is defined in the header file. The enum specifies when the aspect method is invoked. The default is `AspectPositionAfter`, which invokes it after the original method has finished executing. `AspectPositionInstead` replaces the original method. `AspectPositionBefore` invokes the aspect method before the original method. `AspectOptionAutomaticRemoval` automatically removes the hook after it has executed.
```objectivec

@protocol AspectToken <NSObject>

- (BOOL)remove;

@end

```
Defines an `AspectToken` protocol. The Aspect Token here is implicit and allows us to call `remove` to revoke a hook. The `remove` method returns `YES` if the revocation succeeds, and `NO` if it fails.
```objectivec

@protocol AspectInfo <NSObject>

- (id)instance;
- (NSInvocation *)originalInvocation;
- (NSArray *)arguments;

@end

```
Another protocol, `AspectInfo`, is also defined. The `AspectInfo` protocol is the first parameter in our block syntax.

The `instance` method returns the instance currently being hooked. The `originalInvocation` method returns the original invocation of the hooked method. The `arguments` method returns all of the method’s arguments. Its implementation is lazy-loaded.

The header file also includes a comment specifically explaining how to use Aspects and what to watch out for, which is worth our attention.
```c

/**
 Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called a 1000 times per second.

 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */

```
Aspects leverages Objective-C’s message forwarding mechanism to hook messages. This introduces some performance overhead, so don’t add Aspects to methods that are used frequently. Aspects is designed for use in view/controller code, not for hooking methods that are called 1,000 times per second.

After adding an aspect, an implicit token is returned, and that token is used to unregister the hooked method. All calls are thread-safe.

Thread safety will be analyzed in detail below. For now, we at least know that Aspects should not be used in methods such as those inside `for` loops, as it can cause significant performance degradation.
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
There are only these two methods in the entire Aspects library. As you can see here, Aspects is an extension on `NSObject`; as long as something is an `NSObject`, it can use these two methods. The two methods have the same name, the same parameters, and the same return value. The only difference is that one is a class method and the other is an instance method. One is used to hook class methods, and the other is used to hook instance methods.

The method has four parameters. The first, `selector`, is the original method to which you want to add an aspect. The second parameter is of type `AspectOptions`, indicating whether the aspect is added `before`, `instead`, or `after` the original method. The fourth parameter is the returned error.

The key point is the third parameter, `block`. This `block` copies the signature type of the method being hooked. The `block` conforms to the `AspectInfo` protocol. You can even use an empty `block`. The parameters in the `AspectInfo` protocol are optional and are mainly used to match the `block` signature.

The return value is a token that can be used to unregister this aspect.

**Note: Aspects does not support hooking static methods.**
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
This defines the error code types, which makes debugging easier when errors occur.


##### 2.Aspects.m
```objectivec

#import "Aspects.h"

#import <libkern/OSAtomic.h>

#import <objc/runtime.h>

#import <objc/message.h>

```
\#import <libkern/OSAtomic.h> imports this header file for the spin lock used below. \#import <objc/runtime.h> and \#import <objc/message.h> are the required header files for using the Runtime.
```objectivec

typedef NS_OPTIONS(int, AspectBlockFlags) {
      AspectBlockFlagsHasCopyDisposeHelpers = (1 << 25),
      AspectBlockFlagsHasSignature          = (1 << 30)
};

```
AspectBlockFlags is defined as a flag used to indicate two conditions: whether Copy and Dispose helpers are needed, and whether the method signature Signature is needed.


Four classes are defined in Aspects: AspectInfo, AspectIdentifier, AspectsContainer, and AspectTracker. Next, let’s look at how these four classes are defined.

##### 3. AspectInfo
```objectivec

@interface AspectInfo : NSObject <AspectInfo>
- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation;
@property (nonatomic, unsafe_unretained, readonly) id instance;
@property (nonatomic, strong, readonly) NSArray *arguments;
@property (nonatomic, strong, readonly) NSInvocation *originalInvocation;
@end

```
Implementation corresponding to AspectInfo
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
AspectInfo inherits from NSObject and conforms to the AspectInfo protocol. In its \- (id)initWithInstance: invocation: method, it stores the externally passed-in instance `instance` and the original `invocation` in the corresponding member variables of the AspectInfo class. The - (NSArray *)arguments method is lazily loaded and returns the aspects argument array from the original `invocation`.


How is the aspects\_arguments getter implemented? The author implements it by adding a category to NSInvocation.
```objectivec


@interface NSInvocation (Aspects)
- (NSArray *)aspects_arguments;
@end

```
Add an Aspects category to the original NSInvocation class. This category adds only one method, aspects\_arguments, whose return value is an array containing all arguments of the current invocation.

Corresponding implementation
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
\- (NSArray *)aspects\_arguments has a very simple implementation: it is just a `for` loop that adds all the arguments from the `methodSignature` method signature into an array, and finally returns that array.

There are two points worth explaining in detail about the implementation of this `\- (NSArray *)aspects\_arguments` method, which retrieves all method arguments. First, why the loop starts from 2; second, how `[self aspect\_argumentAtIndex:idx]` is implemented internally.


![](https://img.halfrost.com/Blog/ArticleImage/27_2.png)

Let’s first talk about why the loop starts from 2.


As a supplement to the Runtime, Type Encodings are how the compiler encodes the return value and parameter types of each method into a string and associates that string with the method’s selector. This encoding scheme is also very useful in other situations, so we can use the `@encode` compiler directive to obtain it. Given a type, `@encode` returns the string encoding for that type. These types can be primitive types such as `int` and pointers, or types such as structs and classes. In fact, any type that can be used as an operand to `sizeof()` can be used with `@encode()`.

The [Type Encoding](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html) section in the Objective\-C Runtime Programming Guide lists all type encodings in Objective\-C. Note that many of these types are the same as the encoding types we use for archiving and distribution. However, some of them cannot be used for archiving.

Note: Objective\-C does not support the `long double` type. `@encode(long double)` returns `d`, which is the same as `double`.

![](https://img.halfrost.com/Blog/ArticleImage/27_3.png)


To support message forwarding and dynamic invocation, Objective\-C Method type information is **encoded in combination** as “return value Type + parameter Types”. It also needs to take into account the two implicit parameters, self and \_cmd:
```c

- (void)tap; => "v@:"
- (int)tapWithView:(double)pointx; => "i@:d"

```
According to the table above, we can see that in the encoded string, the first three positions are the return value Type, the implicit `self` parameter Type `@`, and the implicit `_cmd` parameter Type `:`.

So starting from position 3, the entries are the input parameters.

Suppose we take \- (void)tapView:(UIView *)view atIndex:(NSInteger)index as an example and print `methodSignature`.
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


The first argument has frame {offset = 0, offset adjust = 0, size = 0, size adjust = 0}memory {offset = 0, size = 0}; the return value does not occupy any size here. The second argument is self, with frame {offset = 0, offset adjust = 0, size = 8, size adjust = 0}memory {offset = 0, size = 8}. Since size = 8, the next frame’s offset is 8, then 16, and so on.


As for why 2 needs to be passed here, that is also related to the specific implementation of aspect\_argumentAtIndex.

Now let’s look at the specific implementation of aspect\_argumentAtIndex. Thanks to the ReactiveCocoa team, this method provides an elegant way to obtain the arguments from a method signature.
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
getArgumentTypeAtIndex: This method is used to obtain the type encoding string at the specified index in the method signature represented by methodSignature. The string returned by this method directly corresponds to the index value we pass in. For example, if we pass in 2, the string returned is actually the 3rd position in the string corresponding to methodSignature.

Because position 0 is the type encoding corresponding to the function return value, passing in 2 corresponds to argument2. So here, when we pass in index = 2, we are skipping the first three type encoding strings and starting the comparison from argument2. This is why the loop starts from 2.


![](https://img.halfrost.com/Blog/ArticleImage/27_5.png)


\_C\_CONST is a constant used to determine whether the encoding string is a CONST constant.
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
The `Type` here is exactly the same as the `Type` in OC; it’s just a C `char` type here.
```c

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)

```
WRAP\_AND\_RETURN is a macro definition. The `getArgument:atIndex:` method called inside this macro is used to retrieve the corresponding argument from an `NSInvocation` by `index`. Finally, when returning, it wraps `val` into an object and returns it.

In the large `if` \- `else` chain below, there are many string comparison calls using `strcmp`.

For example, `strcmp(argType, @encode(id)) == 0`: `argType` is a `char`, whose content is the corresponding type encoding extracted from `methodSignature`, and it is the same type encoding as `@encode(id)`. After comparing them with `strcmp`, if the result is `0`, it means the types are the same.

The large block of checks below is the process of returning all input arguments. It checks `id`, `class`, and `SEL` in order, followed by a large set of primitive types: `char`, `int`, `short`, `long`, `long long`, `unsigned char`, `unsigned int`, `unsigned short`, `unsigned long`, `unsigned long long`, `float`, `double`, `BOOL`, `bool`, and `char *`. These primitive types are all wrapped into objects using WRAP\_AND\_RETURN and returned. Finally, it checks `block` and `struct`, and returns the corresponding objects as well.

In this way, all input arguments are returned and collected into the array. Suppose we still use the example above, `- (void)tapView:(UIView *)view atIndex:(NSInteger)index`. After `aspects_arguments` is executed, the array contains:
```c

(
  <UIView: 0x7fa2e2504190; frame = (0 80; 414 40); layer = <CALayer: 0x6080000347c0>>",
  1
)

```
In summary, `AspectInfo` mainly contains `NSInvocation` information. It wraps `NSInvocation` in an additional layer, including details such as argument information.

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
The purpose of this `aspect_blockMethodSignature` is to convert the incoming `AspectBlock` into an `NSMethodSignature` method signature.

The structure of `AspectBlock` is as follows
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
Here we define a `block` type used internally by Aspects. Anyone familiar with the system `Block` will immediately notice that the two look very similar. If you are not familiar with it, you can read my previous article analyzing `Block`. In that article, Clang is used to transform a `Block` into a struct, and its structure is very similar to the `block` defined here.

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
AspectBlockRef layout = (\_\_bridge void *)block. Since the two block implementations are similar, here the input block is first forcibly cast to the AspectBlockRef type, and then it checks whether the AspectBlockFlagsHasSignature flag bit is present. If not, it reports an error indicating that the method signature is not included.

Note that the passed-in block is of a global type.
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
`desc` is the corresponding `descriptor` pointer in the original block. If the `descriptor` pointer is advanced by two `unsigned long int` positions, it points to the address of the copy function. If the block includes `Copy` and `Dispose` functions, continue advancing it by the size of two `(void *)` values. At this point, the pointer must have reached the `const char *signature` location. If `desc` does not exist, an error will also be reported: the block does not contain a method signature.
```objectivec

 const char *signature = (*(const char **)desc);
 return [NSMethodSignature signatureWithObjCTypes:signature];


```
At this point, it is guaranteed that the method signature is present and valid. Finally, it calls `NSMethodSignature`’s `signatureWithObjCTypes` method and returns the method signature.

For example, let’s illustrate what the method signature ultimately generated by `aspect_blockMethodSignature` looks like.
```objectivec

    [UIView aspect_hookSelector:@selector(UIView:atIndex:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspects, UIView *view, NSInteger index)
     {
         
         NSLog(@"Button clicked %ld",index);
         
     } error:nil];

```
The string ultimately obtained by const char *signature is as follows
```objectivec

(const char *) signature = 0x0000000102f72676 "v32@?0@\"<AspectInfo>\"8@\"UIView\"16q24"

```
v32@?0@"<AspectInfo>"8@"UIView"16q24 is a Block
```objectivec

^(id<AspectInfo> aspects, UIView *view, NSInteger index){

}

```
The corresponding Type. The Type for a `void` return value is `v`, `32` is the offset, `@?` is the Type corresponding to the block, `@"<AspectInfo>"` is the first parameter, `@"UIView"` is the second parameter, and the Type corresponding to `NSInteger` is `q`.

The number following each Type is its respective offset. Print the final converted `NSMethodSignature`.
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
Returning to `AspectIdentifier`, let’s continue looking at the `instancetype` method. After obtaining the method signature of the passed-in block, it then calls the `aspect\_isCompatibleBlockSignature` method.
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
The purpose of this function is to compare the method block we want to substitute with the original method being replaced. How does it compare them? By comparing the method signatures of the two.

The input parameter `selector` is the original method.
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
First compare whether the method signatures have the same number of parameters. If they differ, they definitely do not match, so `signaturesMatch = NO`. If the parameter counts are the same, then compare whether the first parameter of the method we want to replace is \_cmd, whose corresponding Type is @. If not, it also does not match, so `signaturesMatch = NO`. If both of the above conditions are satisfied, `signaturesMatch = YES`, and the more stringent comparison below is performed.
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
The loop here also starts at 2. Here’s an example to explain why the comparison starts from the second position. We’ll use the same example as before.
```objectivec

[UIView aspect_hookSelector:@selector(UIView:atIndex:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspects, UIView *view, NSInteger index)
 {
     
     NSLog(@"Button clicked %ld",index);
     
 } error:nil];

```
Here, the original method I want to replace is UIView:atIndex:, so the corresponding Type is v@:@q. Based on the analysis above, the blockSignature here is the Type produced by the earlier conversion, which should be v@?@"<AspectInfo>"@"UIView"q.

![](https://img.halfrost.com/Blog/ArticleImage/27_7.png)


The return value of both methodSignature and blockSignature is void, so both correspond to v. argument 0 of methodSignature is the implicit parameter self, so it corresponds to @. argument 0 of blockSignature is the block, so it corresponds to @?. argument 1 of methodSignature is the implicit parameter _cmd, so it corresponds to :. argument 1 of blockSignature is <AspectInfo>, so it corresponds to @"<AspectInfo>". Starting from argument 2 is where differences may appear in the parameter list corresponding to the method signature, and those are the parameters that need to be compared.

Finally
```objectivec

    if (!signaturesMatch) {
        NSString *description = [NSString stringWithFormat:@"Block signature %@ doesn't match %@.", blockSignature, methodSignature];
        AspectError(AspectErrorIncompatibleBlockSignature, description);
        return NO;
    }


```
If `signaturesMatch` is still `NO` after the comparisons above, an error is thrown: the Block cannot match the method signature.
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
If the match succeeds here, the entire `blockSignature` will be assigned to `AspectIdentifier`. This is why `AspectIdentifier` has a separate `NSMethodSignature` property.

`AspectIdentifier` also has another method, `invokeWithInfo`.
```objectivec

    // Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        AspectLogError(@"Block has too many arguments. Not calling %@", info);
        return NO;
    }


```
The comment makes this clear as well: this check was written by someone with OCD. At this point, the number of parameters in the block cannot be greater than the number of parameters in the original method signature.
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
This section loops over the arguments extracted from originalInvocation, assigns them into argBuf, and then assigns them into blockInvocation. The reason the loop starts at 2 has already been explained above, so it will not be repeated here. Finally, self.block is assigned to the Target of blockInvocation.


![](https://img.halfrost.com/Blog/ArticleImage/27_8.png)


In summary, AspectIdentifier is the concrete content of an Aspect slice. It contains the specific information for a single Aspect, including when it should be executed and the concrete information required to execute the block, such as the method signature, arguments, and so on. The process of initializing AspectIdentifier is essentially packaging the block we pass in into an AspectIdentifier.


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
AspectsContainer is fairly easy to understand. `addAspect` places the Aspects into the corresponding arrays based on the aspect’s timing. `removeAspects` iterates and removes all Aspects. `hasAspects` determines whether any Aspects exist.


AspectsContainer is a container for all Aspects of an object or class. Therefore, there are two kinds of containers.

One thing worth noting is that the arrays here are marked as Atomic. Regarding Atomic, note that by default, compiler-synthesized methods ensure atomicity through a locking mechanism. If a property has the nonatomic attribute, no synchronization lock is required.


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
AspectTracker is used to track the class that will be hooked. `trackedClass` is the class being tracked. `trackedClassName` is the class name of the tracked class. `selectorNames` is an `NSMutableSet`; it records the method names that will be hooked and replaced. An `NSMutableSet` is used to prevent the same method from being replaced repeatedly. `selectorNamesToSubclassTrackers` is a dictionary whose key is `hookingSelectorName` and whose value is an `NSMutableSet` filled with `AspectTracker` instances.

The `addSubclassTracker` method adds an `AspectTracker` to the collection corresponding to the given `selectorName`. The `removeSubclassTracker` method removes an `AspectTracker` from the collection corresponding to the given `selectorName`. The `subclassTrackersHookingSelectorName` method works like a union-find: given a `selectorName`, it recursively searches for all sets that contain this `selectorName`, then merges those sets together and returns the merged result.


#### IV. Preparation Before Hooking with Aspects


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
Both methods are implemented by calling the same method, aspect\_add; they just pass different arguments. Therefore, we only need to start our investigation from aspect\_add.
```c

- aspect_hookSelector:(SEL)selector withOptions:(AspectOptions)options usingBlock:(id)block error:(NSError **)error
└── aspect_add(self, selector, options, block, error);
    └── aspect_performLocked
        ├── aspect_isSelectorAllowedAndTrack
        └── aspect_prepareClassAndHookSelector

```
This is the function call stack. Start investigating from aspect\_add.
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
The `aspect\_add` function has five parameters in total. The first parameter is `self`; `selector` is the `SEL` passed in from outside that needs to be hooked; `options` specifies the timing of the aspect; `block` is the execution method for the aspect; and the final `error` parameter is for errors.

`aspect\_performLocked` is a spin lock. A spin lock is a relatively efficient type of lock, much more efficient than `@synchronized`.
```objectivec

static void aspect_performLocked(dispatch_block_t block) {
    static OSSpinLock aspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&aspect_lock);
    block();
    OSSpinLockUnlock(&aspect_lock);
}

```
If you are not familiar with the eight major locks in iOS, you can read the following two articles:

[Common iOS Knowledge Points (3): Lock](http://www.jianshu.com/p/ddbe44064ca4)    
[An In-Depth Understanding of Locks in iOS Development](http://www.jianshu.com/p/8781ff49e05b)


![](https://img.halfrost.com/Blog/ArticleImage/27_12.png)


However, spin locks can also run into problems:
If a low-priority thread acquires the lock and accesses a shared resource, and then a high-priority thread also tries to acquire the same lock, it will enter the busy-wait state of the spin lock and consume a large amount of CPU. At this point, the low-priority thread cannot compete with the high-priority thread for CPU time, which causes the task to remain unfinished and prevents the lock from being released. [The No-Longer-Safe OSSpinLock](http://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/)

The problem with OSSpinLock is that if the threads accessing this lock do not have the same priority, there is a potential risk of deadlock.

Here, for the time being, we assume the threads have the same priority, so OSSpinLock guarantees thread safety. In other words, aspect\_performLocked protects the thread safety of the block.

Now only the aspect\_isSelectorAllowedAndTrack function and the aspect\_prepareClassAndHookSelector function remain.

Next, let’s first look at the implementation process of the aspect\_isSelectorAllowedAndTrack function.
```objectivec

    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"forwardInvocation:", nil];
    });

```
First, an `NSSet` is defined. It contains a “blacklist” of function names that are not allowed to be hooked. `retain`, `release`, `autorelease`, and `forwardInvocation:` are not allowed to be hooked.
```objectivec

    NSString *selectorName = NSStringFromSelector(selector);
    if ([disallowedSelectorList containsObject:selectorName]) {
        NSString *errorDescription = [NSString stringWithFormat:@"Selector %@ is blacklisted.", selectorName];
        AspectError(AspectErrorSelectorBlacklisted, errorDescription);
        return NO;
    }


```
If the selector’s function name is found in the blacklist, report an error immediately.
```objectivec

    AspectOptions position = options&AspectPositionFilter;
    if ([selectorName isEqualToString:@"dealloc"] && position != AspectPositionBefore) {
        NSString *errorDesc = @"AspectPositionBefore is the only valid position when hooking dealloc.";
        AspectError(AspectErrorSelectorDeallocPosition, errorDesc);
        return NO;
    }

```
Also check that if `dealloc` is being hooked, the aspect position can only be before `dealloc`; if it is not `AspectPositionBefore`, an error should also be reported.
```objectivec

    if (![self respondsToSelector:selector] && ![self.class instancesRespondToSelector:selector]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Unable to find selector -[%@ %@].", NSStringFromClass(self.class), selectorName];
        AspectError(AspectErrorDoesNotRespondToSelector, errorDesc);
        return NO;
    }

```
When the selector is no longer in the blacklist, if the slice is `dealloc` and the selector comes before it, you should check whether the method exists. If the selector cannot be found in either `self` or `self.class`, an error will be reported indicating that the method cannot be found.
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
`class_isMetaClass` first checks whether it is a metaclass. The subsequent checks determine whether methods in the metaclass are allowed to be replaced.

`subclassHasHookedSelectorName` checks whether the current `tracker`’s subclass contains `selectorName`. This is because a method can only be hooked once within a class hierarchy. If the `tracker` already contains it once, an error will be reported.
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
In this do-while loop, the condition currentClass = class\_getSuperclass(currentClass) starts from currentClass's superclass and keeps walking up until the class is the root class, NSObject.
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
After the legality hook check above and the check that class methods are not allowed to be replaced repeatedly, at this point the information to be hooked can be recorded and marked with AspectTracker. During the marking process, once a subclass is changed, its superclass also needs to be marked accordingly. The termination condition of the do-while loop is still currentClass = class\_getSuperclass(currentClass).

The above is the code for validating whether hooking a metaclass’s class method is legal.


If it is not a metaclass, then as long as the method being hooked is not one of "retain", "release", "autorelease", or "forwardInvocation:", the timing for hooking the “dealloc” method must be before, and the selector can be found, the method can be hooked.


After passing the legality check for whether the selector can be hooked, the next step is to obtain or create the AspectsContainer container.
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
Before reading or creating `AspectsContainer`, the first step is to mark the selector.
```objectivec

static SEL aspect_aliasForSelector(SEL selector) {
    NSCParameterAssert(selector);
 return NSSelectorFromString([AspectsMessagePrefix stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
}

```
A constant string is defined in the global code.
```objectivec


static NSString *const AspectsMessagePrefix = @"aspects_";

```
Use this string to mark all selectors by adding the prefix "aspects\_" to each of them. Then obtain the corresponding AssociatedObject. If it cannot be retrieved, create a new associated object. The final result is an aspectContainer corresponding to a selector with the "aspects\_" prefix.

After obtaining the aspectContainer, we can start preparing the information needed to hook the method. All of this information is stored in AspectIdentifier, so we need to create a new AspectIdentifier.

Call the instancetype method of AspectIdentifier to create a new AspectIdentifier.
```objectivec

+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error

```
This instancetype method can fail to create an instance in only one case: when the aspect\_isCompatibleBlockSignature method returns NO. Returning NO means that the method signatures of the replacement block and the original method to be replaced do not match. (This function was explained in detail above, so it will not be repeated here.) Once the method signatures match successfully, an AspectIdentifier is created.
```objectivec

[aspectContainer addAspect:identifier withOptions:options];

```
The aspectContainer container adds it to the container. After the container and AspectIdentifier have been initialized, it can start preparing to perform the hook. Based on the options, it is added to the three arrays in the container: beforeAspects, insteadAspects, and afterAspects.
```objectivec

// Modify the class to allow message interception.
       aspect_prepareClassAndHookSelector(self, selector, error);

```
To summarize, here is what preparation work `aspect_add` does:

1. First, it calls `aspect_performLocked`, using a spin lock to ensure the thread safety of the entire operation.
2. Next, it calls `aspect_isSelectorAllowedAndTrack` to strictly validate the passed-in parameters and ensure their legality.  
3. It then creates an `AspectsContainer` container, which is dynamically added to the `NSObject` category as a property using an `AssociatedObject`.
4. Next, it creates an `AspectIdentifier` instance from the input parameters `selector` and `option`. `AspectIdentifier` mainly contains the specific information for a single Aspect, including the execution timing and the concrete information required by the block to be executed.
5. It then adds the specific information of the single `AspectIdentifier` to the `AspectsContainer` property. Based on the `options` value, it is added to the three arrays in the container: `beforeAspects`, `insteadAspects`, and `afterAspects`.
6. Finally, it calls `prepareClassAndHookSelector` to prepare for hooking.

![](https://img.halfrost.com/Blog/ArticleImage/27_13.png)


#### V. Detailed Explanation of the Aspects Hooking Process


First, take a look at the function call stack.
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
From the call stack, the Aspects hook process mainly consists of four stages: hookClass, ASPECTS\_ARE\_BEING\_CALLED, prepareClassAndHookSelector, and remove.


![](https://img.halfrost.com/Blog/ArticleImage/28_1.jpg)


##### 1. hookClass
```objectivec


 NSCParameterAssert(self);
 Class statedClass = self.class;
 Class baseClass = object_getClass(self);
 NSString *className = NSStringFromClass(baseClass);

```
statedClass and baseClass are different.
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
`statedClass` retrieves the class object, while `baseClass` retrieves the class’s `isa`.
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
First, check whether className has the suffix AspectsSubclassSuffix.
```objectivec


static NSString *const AspectsSubclassSuffix = @"_Aspects_";


```
If it contains the @"\_Aspects\_" suffix, it means this class has already been hooked, so return directly.
If it does not contain the @"\_Aspects\_" suffix, then check whether baseClass is a metaclass. If it is a metaclass, call aspect\_swizzleClassInPlace. If it is not a metaclass either, then check whether statedClass and baseClass are equal. If they are not equal, it indicates a KVO-observed object, because the isa pointer of a KVO-observed object points to an intermediate class. Call aspect\_swizzleClassInPlace on the KVO intermediate class.
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
\_aspect\_modifySwizzledClasses passes in a block whose parameter is (NSMutableSet \*swizzledClasses). Inside the block, it checks whether the Set contains the current ClassName. If it does not, it calls the aspect\_swizzleForwardInvocation() method and adds className to the Set.
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
The `_aspect_modifySwizzledClasses` method ensures that the `swizzledClasses` `Set` collection is globally unique, and adds a thread lock `@synchronized( )` to the passed-in block, ensuring thread safety during the block invocation.

As for calling `aspect_swizzleForwardInvocation` and making the original `IMP` point to `forwardInvocation`, that belongs to the next stage. Let’s finish looking at `hookClass` first.
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
When `className` does not contain the `@"_Aspects_"` suffix, is not a metaclass, and is not a KVO intermediate class—that is, when `statedClass == baseClass`—a new subclass `subclass` is created by default.

At this point, we can understand the design philosophy behind Aspects: **hooking is implemented on top of subclasses dynamically created at runtime**. All swizzling operations take place on the subclass. The benefit of this approach is that you do not need to change the object's original class. In other words, when you remove aspects, if all aspects on the current object have been removed, you can point the `isa` pointer back to the object's original class, thereby eliminating the swizzling for that object without affecting other instances of the same class. This has no impact on the originally replaced class or object, and aspects can be added or removed on top of the subclass.

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
This method checks whether a class named name has been implemented. During the lookup, it uses `rwlock_reader_t lock(runtimeLock)`, a read-write lock implemented under the hood with `pthread_rwlock_t`.

Since this is the name of a subclass we just created, it is very likely that `objc_getClass()` returns `nil`. In that case, we need to create this subclass by calling `objc_allocateClassPair()`.
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

If the newly created subclass, subclass = = nil, an error is reported: objc\_allocateClassPair failed to allocate class.

aspect\_swizzleForwardInvocation(subclass) belongs to the next stage. Its main purpose is to replace the implementation of the current class’s forwardInvocation method with \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_. We’ll skip it for now.

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
The aspect\_hookedGetClass method replaces class’s instance method with one that returns statedClass; in other words, when class is called, its isa points to statedClass.
```objectivec

  aspect_hookedGetClass(subclass, statedClass);
  aspect_hookedGetClass(object_getClass(subclass), statedClass);

```
Now we understand the intent of these two lines as well.

The first line points the `isa` of `subclass` to `statedClass`; the second line points the `isa` of `subclass`’s metaclass to `statedClass` as well.


Finally, it calls `objc_registerClassPair( )` to register the newly created subclass `subclass`, and then calls `object_setClass(self, subclass);` to point the current `self`’s `isa` to the subclass `subclass`.


At this point, the `hookClass` phase is complete: `self` has been successfully hooked into its subclass `xxx_Aspects_`.

![](https://img.halfrost.com/Blog/ArticleImage/28_2.png)


##### 2. ASPECTS_ARE_BEING_CALLED


In the previous `hookClass` phase, `aspect_swizzleForwardInvocation` was called in several places.
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
aspect\_swizzleForwardInvocation is where the entire Aspects hook mechanism begins.
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
Calling the class\_replaceMethod method actually invokes the \_class\_addMethod method under the hood.
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
From the source code above, we can see that it first calls \_findMethodInClass(cls, name) to look for a method named name in cls. If it exists and the corresponding IMP can be found, it replaces it with method\_setImplementation((Method)m, imp), replacing the IMP of the name method with imp. In this case, \_class\_addMethod returns the IMP corresponding to the name method, which is actually the imp we just replaced it with.

If the name method is not found in cls, then the method is added: a new name method is inserted at mlist \-\> method\_list[0], and its corresponding IMP is the passed-in imp. In this case, \_class\_addMethod returns nil.


Back to aspect\_swizzleForwardInvocation,
```objectivec

IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
if (originalImplementation) {
   class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
}

```
Replace the IMP of forwardInvocation: with \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_. If the forwardInvocation: method cannot be found in klass, this method will be added.


~~Because the subclass itself does not implement forwardInvocation, the hidden returned originalImplementation will be nil, so NSSelectorFromString(AspectsForwardInvocationSelectorName) will not be generated either. Therefore, \_class\_addMethod is also needed to add the implementation of the forwardInvocation: method for us.~~

Thanks to the Jianshu expert @zhao0 for pointing this out. This issue has already been fixed in Aspects 1.4.1.

In aspect\_swizzleForwardInvocation, class\_replaceMethod returns the IMP of the original method. If originalImplementation is not nil, it means the original method has an implementation. A new method, \_\_aspects\_forwardInvocation:, is added and points to the original originalImplementation. In \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_, if it cannot be handled, it checks whether \_\_aspects_forwardInvocation is implemented; if so, it forwards to it. This solves the compatibility issue.


If originalImplementation returns a value other than nil, it means the replacement succeeded. After replacing the method, we then add another method named “\_\_aspects\_forwardInvocation:” to klass, whose corresponding implementation is also (IMP)\_\_ASPECTS\_ARE_BEING\_CALLED\_\_.


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
4. Get the instance object's container, `objectContainer`; this is the object previously associated via `aspect_add`.
5. Get the class object's container, `classContainer`
6. Initialize `AspectInfo`, passing in the `self` and `invocation` parameters
```objectivec

    // Before hooks.
    aspect_invoke(classContainer.beforeAspects, info);
    aspect_invoke(objectContainer.beforeAspects, info);

```
Invoke macro definitions to perform Aspects slicing functionality
```objectivec

#define aspect_invoke(aspects, info) \
for (AspectIdentifier *aspect in aspects) {\
    [aspect invokeWithInfo:info];\
    if (aspect.options & AspectOptionAutomaticRemoval) { \
        aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; \
    } \
}

```
The reason a macro definition is used here to implement the functionality is to obtain clearer stack information.

The macro does two things: it executes the `[aspect invokeWithInfo:info]` method, and it adds the Aspects that need to be removed to an array waiting for removal.

The implementation of `[aspect invokeWithInfo:info]` was analyzed in detail in the previous article. The main purpose of this function is to initialize `blockSignature` and obtain an `invocation`. It then handles the parameters: if the parameter count in the block is greater than 1, it puts the passed-in `AspectInfo` into `blockInvocation`. It then retrieves parameters from `originalInvocation` and assigns them to `blockInvocation`. Finally, it calls `[blockInvocation invokeWithTarget:self.block];`, where the Target is set to `self.block`. In other words, this executes the block for the method we hooked.

So as long as we call `aspect_invoke(classContainer.Aspects, info);`, the core replacement method, we can hook the original SEL. Correspondingly, passing `classContainer.beforeAspects`, `classContainer.insteadAspects`, and `classContainer.afterAspects` as the first argument to the function enables hooking the Aspects slices for the corresponding before, instead, and after execution points.
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
This section of code implements Instead hooks. It first checks whether the current insteadAspects contains any data. If it does not, it then checks whether the current inheritance chain can respond to the aspects\_xxx method. If it can, aliasSelector is called directly. **Note: the aliasSelector here is the original method**
```objectivec

    // After hooks.
    aspect_invoke(classContainer.afterAspects, info);
    aspect_invoke(objectContainer.afterAspects, info);


```
These two lines are for executing the corresponding After hooks. The principle is as described above.

At this point, all executable hooks in the Aspects slices corresponding to the before, instead, and after phases have finished executing.

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
First, set `invocation.selector` back to the original `originalSelector`. If the hook did not succeed, `AspectsForwardInvocationSelectorName` can still obtain the `SEL` corresponding to the original `IMP`. If it responds to it, invoke the original `SEL`; otherwise, raise a `doesNotRecognizeSelector` error.
```objectivec

[aspectsToRemove makeObjectsPerformSelector:@selector(remove)];

```
Finally, call the removal method to remove the hook.

![](https://img.halfrost.com/Blog/ArticleImage/28_3.png)


##### 3. prepareClassAndHookSelector

Now let's return to the aspect\_prepareClassAndHookSelector method mentioned in the previous article.
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
klass is the subclass we obtain after hooking the original class; its name has the \_Aspects\_ suffix. Because it is a subclass of the current class, we can also retrieve the IMP of the original selector from it.
```objectivec

static BOOL aspect_isMsgForwardIMP(IMP impl) {
    return impl == _objc_msgForward

#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret

#endif
    ;
}


```
This checks whether the current IMP is `_objc_msgForward` or `_objc_msgForward_stret`; in other words, whether the current IMP is message forwarding.

If it is not message forwarding, first obtain the method encoding `typeEncoding` of the IMP corresponding to the current original selector.

If the subclass cannot respond to `aspects_xxxx`, add the `aspects_xxxx` method to `klass`, with its implementation being the original method implementation.

The entry point for the entire Aspects hook is this line:
```objectivec

class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);

```
Since we point the selector to \_objc\_msgForward and \_objc\_msgForward\_stret, as you can imagine, when the selector is executed, it will also trigger message forwarding and enter `forwardInvocation`. Since we have swizzled `forwardInvacation`, execution ultimately transfers into our own handling logic.


![](https://img.halfrost.com/Blog/ArticleImage/28_4.png)
 


##### 4. aspect\_remove

The function call stack for the entire `aspect_remove` teardown process.
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
aspect\_performLocked ensures thread safety. It sets all AspectsContainer instances to nil. The most critical step in remove is aspect\_cleanupHookedClassAndSelector(self, aspect.selector);, which removes the previously hooked class and selector.
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
klass is the current class; if it is a metaclass, convert it into a metaclass.
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
First, respond to the MsgForward message-forwarding function to obtain the method signature, and then replace the original forwarding method with the method we hooked.


There is one issue to be aware of here.


If the current Student has 2 instances, stu1 and stu2, and they have both hooked the same method study( ), after stu2 finishes executing aspect\_remove and restores stu2's study( ) method, stu1's study( ) method will also be restored. This is because the remove operation takes effect for all instances of the entire class.

To allow each instance to restore its own method without affecting other instances, the code above can simply be deleted. When the remove operation is executed, the data structures related to this object have actually already been cleared. Even if stu2's study( ) execution is not restored, when entering \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_, because there are no responsive aspects, it will directly fall through to the original handling logic and will not have any other side effects.
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
Finally, we also need to reconstruct the class’s `AssociatedObject` associated object, as well as the `AspectsContainer` container it uses.
```objectivec

static void aspect_destroyContainerForObject(id<NSObject> self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(selector);
    objc_setAssociatedObject(self, aliasSelector, nil, OBJC_ASSOCIATION_RETAIN);
}

```
This method destroys the AspectsContainer container and also sets the associated object to nil.
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
Finally, restore the Swizzling for ForwardInvocation by swapping the original ForwardInvocation back.


#### 6. Some “Pitfalls” in Aspects


![](https://img.halfrost.com/Blog/ArticleImage/28_5.png)


The Aspects library uses Method Swizzling in several places. If these spots are not handled properly, you can easily fall into a “pitfall”.


##### 1. Potential “pitfalls” in aspect\_prepareClassAndHookSelector

In the aspect\_prepareClassAndHookSelector method, the original selector is hooked to \_objc\_msgForward. But what happens if the selector here is itself \_objc\_msgForward?

In fact, the author has already hinted at this pitfall in the code comments.


In the \_\_ASPECTS\_ARE\_BEING\_CALLED\_\_ method, there is the following comment in the section of code that finally forwards the message:
```c

// If no hooks are installed, call original implementation (usually to throw an exception)

```
After reading this comment, you will probably wonder why an exception is thrown at this point. The reason is that the IMP corresponding to `NSSelectorFromString(AspectsForwardInvocationSelectorName)` cannot be found.

If you trace further up, you can find the cause. In the implementation of `aspect_prepareClassAndHookSelector`, it checks whether the current selector is `_objc_msgForward`. If it is not `msgForward`, nothing further will be done. As a result, `aliasSelector` has no corresponding implementation.

Because `forwardInvocation` is hooked by Aspects, execution eventually enters Aspects’ handling logic, `__ASPECTS_ARE_BEING_CALLED__`. At this point, if the IMP implementation for `aliasSelector` cannot be found, message forwarding will occur here. In addition, the subclass does not implement `NSSelectorFromString(AspectsForwardInvocationSelectorName)`, so forwarding will throw an exception.

The “trap” here is that if the hooked selector becomes `_objc_msgForward`, an exception will occur. However, we generally do not hook the `_objc_msgForward` method directly. The reason this issue occurs is that some other swizzling mechanism hooks this method.

For example, if the passed-in selector has already been hooked by JSPatch, then we will no longer process it here, and `aliasSelector` will not be generated. This results in a crash exception.
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
This [article](http://wereadteam.github.io/2016/06/30/Aspects/) provides a solution:

Swizzle the subclass’s forwardInvocation method rather than merely replacing it. The implementation works as follows: force-create an NSSelectorFromString(AspectsForwardInvocationSelectorName) that points to the original object’s forwardInvocation implementation.


Note that if originalImplementation is empty, the generated NSSelectorFromString(AspectsForwardInvocationSelectorName)
will point to baseClass, which is this object’s actual forwradInvocation. This is in fact also the method hooked by JSPatch. At the same time, to preserve the execution order of the blocks (that is, the before hooks / instead hooks / after hooks introduced earlier), this code needs to be moved earlier so it runs before the after hooks. This resolves the conflict that occurs when forwardInvocation has already been hooked externally.


Thanks to the Jianshu expert @zhao0 for the guidance. This article provides a detailed analysis of [various compatibility issues between Aspect and JSPatch](http://www.jianshu.com/p/dc1deaa1b28e). After a detailed analysis, only four incompatible cases remain.


##### 2. Potential “pitfalls” in aspect\_hookSelector

Aspects mainly hooks selectors. If multiple places use Aspects to hook the same method, doesNotRecognizeSelector issues may also occur.

For example, suppose Aspects is used on NSArray to hook the objectAtIndex method, and then objectAtIndex is swizzled in NSMutableArray. In
NSMutableArray, calling objectAtIndex may then fail.


The reason is still that after Aspects hooks a selector, it changes the original selector to \_objc\_msgForward. When NSMutableArray later hooks this method, the recorded IMP is already \_objc\_msgForward. If objc\_msgSend executes the original implementation at this point, an error will occur. The original implementation has already been replaced with \_objc\_msgForward, and the real IMP cannot be found because it was swizzled away by Aspects first.


The solution is still similar to the JSPatch solution:

Swizzle -forwardInvocation: as well. In your own -forwardInvocation: method, perform the same operation: inspect the Selector of the incoming NSInvocation. If the swizzled method points to \_objc\_msgForward (or \_objc\_msgForward\_stret) and the Selector is one that you can recognize, change the Selector back to the original Selector before executing it. If it is not recognized, forward it directly.


#### Finally

Finally, here is a diagram summarizing the overall Aspects flow:


![](https://img.halfrost.com/Blog/ArticleImage/28_6.png)


Feedback and corrections are welcome.