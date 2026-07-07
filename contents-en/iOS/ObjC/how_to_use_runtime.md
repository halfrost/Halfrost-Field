# Asylum Objective-C Runtime: Day 3 of Discharge—How to Use the Runtime Correctly

![](https://img.halfrost.com/Blog/ArticleTitleImage/25_0_.jpg)


#### Preface

Today we can finally be "discharged." It is time to summarize what we have learned over the past few days in the hospital and talk about what benefits the Runtime can actually bring to our development work. Of course, it is also a double-edged sword: if used improperly, it can become a major pitfall on the road to development.

####Table of Contents

- 1.Advantages of Runtime
    - (1)    Implementing Multiple Inheritance
    - (2)    Method Swizzling
    - (3)    Aspect Oriented Programming
    - (4)    Isa Swizzling
    - (5)    Associated Object
    - (6)    Dynamically Adding Methods
    - (7)    Automatic Archiving and Unarchiving with NSCoding
    - (8)    Converting Between Dictionaries and Models
- 2.Disadvantages of Runtime

#### I. Implementing Multiple Inheritance  

From the forwardingTargetForSelector: method discussed in the previous article, we can see that a class can achieve the effect of inheriting from multiple classes. At this step, you only need to forward the message to the correct class object to simulate multiple inheritance.

The [official documentation](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtForwarding.html#//apple_ref/doc/uid/TP40008048-CH105-SW11) includes the following example.

![](https://img.halfrost.com/Blog/ArticleImage/25_1.png)


In an Objective-C program, you can leverage the message forwarding mechanism to implement a form of multiple inheritance. In the diagram above, one object responds to a message in a way that is similar to borrowing or "inheriting" a method from another object. In the diagram, the warrior instance forwards a negotiate message to the Diplomat instance, which executes the negotiate method in Diplomat. The result looks as if the warrior instance executed a negotiate method identical to the one in the Diplomat instance, but the actual executor is still the Diplomat instance.

This allows two classes from different branches of the inheritance hierarchy to "inherit" each other's methods. In this way, a class can respond to methods from its own inheritance branch while also responding to messages sent by otherwise unrelated classes. In the diagram above, Warrior and Diplomat have no inheritance relationship, but after Warrior forwards the negotiate message to Diplomat, it is as if Diplomat were a superclass of Warrior.

Message forwarding provides many characteristics similar to multiple inheritance, but there is one major difference between them: 

Multiple inheritance: combines different behavioral characteristics into a single object, resulting in a heavyweight, multifaceted object.   

Message forwarding: distributes separate capabilities across different objects, resulting in lightweight objects that are connected through message forwarding.


One point worth noting here is that even if we use message forwarding to implement "fake" inheritance, the NSObject class still distinguishes between the two. Methods such as respondsToSelector: and isKindOfClass: only consider the inheritance hierarchy; they do not consider the forwarding chain. For example, in the diagram above, if a Warrior object is asked whether it can respond to the negotiate message:
```objectivec

if ( [aWarrior respondsToSelector:@selector(negotiate)] )

```
The answer is NO. Although it can respond to the `negotiate` message without reporting an error, it does so by forwarding the message to the `Diplomat` class.

If you really want to create the illusion of this “fake” inheritance relationship, you need to reimplement `respondsToSelector:` and `isKindOfClass:` to incorporate your forwarding algorithm:
```objectivec

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ( [super respondsToSelector:aSelector] )
        return YES;
    else {
        /* Here, test whether the aSelector message can     *
         * be forwarded to another object and whether that  *
         * object can respond to it. Return YES if it can.  */
    }
    return NO;
}

```
In addition to respondsToSelector: and isKindOfClass:, instancesRespondToSelector: should also include a forwarding algorithm. If protocols are used, conformsToProtocol: likewise needs to be overridden. Similarly, if an object forwards any remote message it receives, it must provide a methodSignatureForSelector: that returns an accurate method description for the method that will ultimately respond to the forwarded message. For example, if an object can forward messages to its surrogate object, it needs to implement methodSignatureForSelector: as follows:
```objectivec


- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature* signature = [super methodSignatureForSelector:selector];
    if (!signature) {
        signature = [surrogate methodSignatureForSelector:selector];
    }
    return signature;
}

```
>**Note:**  This is an advanced technique, suitable only for situations where no other solution is possible. It is not intended as a replacement for inheritance. If you must make use of this technique, make sure you fully understand the behavior of the class doing the forwarding and the class you’re forwarding to.

One point worth noting is that implementing `methodSignatureForSelector` is an advanced technique suitable only for situations where no other solution is possible. It is not intended as a replacement for inheritance. If you must use this technique, make sure you fully understand the behavior of both the class performing the forwarding and the class you are forwarding to. Do not abuse it!

#### II. Method Swizzling

![](https://img.halfrost.com/Blog/ArticleImage/25_2.png)


When Objective-C Runtime is mentioned, the first thing most people probably think of is the “black magic” known as Method Swizzling. After all, it is a very powerful part of Runtime: by using Runtime APIs, it can change arbitrary methods. In theory, at runtime, you can hook into any OC method by class name/method name, replace the implementation of any class, and add arbitrary classes.

The most commonly cited example is probably collecting user analytics.

Suppose we need to collect user information in different places across pages. There are two common approaches:  
1. The brute-force approach: add the tracking code to every page that needs analytics. This is simple, but it introduces a lot of duplicated code.
2. Put the tracking code in a base class, such as `BaseViewController`. Although the code only needs to be written once, `UITableViewController` and `UICollectionViewcontroller` still need their own implementations, so there is still quite a bit of duplicated code.

Given these two points, using Method Swizzling here is the most elegant solution.

##### 1. How Method Swizzling Works

Method Swizzling happens at runtime and is mainly used to exchange two `Method`s at runtime. We can write Method Swizzling code anywhere, but the exchange only takes effect after that Method Swizzling code has finished executing. Method Swizzling is also one way to implement AOP (aspect-oriented programming) in iOS; we can leverage this Apple-provided capability to implement AOP-style programming.

In essence, Method Swizzling is an exchange of `IMP` and `SEL`.


##### 2. Using Method Swizzling

In general, we create a category and perform the Method Swizzling exchange inside that category. The code template for the exchange is as follows:
```objectivec

#import <objc/runtime.h>
@implementation UIViewController (Swizzling)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        // When swizzling a class method, use the following:
        // Class class = object_getClass((id)self);
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(xxx_viewWillAppear:);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

#pragma mark - Method Swizzling
- (void)xxx_viewWillAppear:(BOOL)animated {
    [self xxx_viewWillAppear:animated];
    NSLog(@"viewWillAppear: %@", self);
}
@end

```
Method Swizzling can dynamically modify methods at runtime by changing the function corresponding to a selector in a class’s method list, or by swapping method implementations. It lets you override a method without subclassing, while still being able to call the original implementation. Therefore, it is commonly used to add behavior in a category.

##### 3.Method Swizzling Caveats

![](https://img.halfrost.com/Blog/ArticleImage/25_3.png)


1.Swizzling should always be performed in +load

At runtime, Objective-C automatically calls two class methods: +load and +initialize. +load is called when the class is initially loaded. +initialize is called lazily: if the program never sends a message to a class or any of its subclasses, that class’s +initialize method will never be called. Therefore, if Swizzling is written in +initialize, it may never be executed.

Compared with +initialize, +load guarantees that the code is loaded during class initialization.

For a comparison of +load and +initialize, see this article: [Objective-C +load vs +initialize](http://blog.leichunfeng.com/blog/2015/05/02/objective-c-plus-load-vs-plus-initialize/)


2.Swizzling should always be performed inside dispatch\_once

Swizzling changes global state, so you should take precautions at runtime. Using dispatch\_once ensures that the code is executed exactly once, no matter how many threads are involved. This should be considered a best practice for Method Swizzling.


There is a very common mistake: using Swizzling in an inheritance hierarchy. If you do not use dispatch\_once, Swizzling may become ineffective!

For example, suppose you Swizzle the objectAtIndex: method in both NSArray and NSMutableArray. This may cause the Swizzling in NSArray to become ineffective.

But why does this happen?
The reason is that we did not use dispatch\_once to ensure that Swizzling runs only once. If this Swizzling code is executed multiple times, after the IMPs and SELs are exchanged repeatedly, the final result may be the same as the original, unswizzled state.

For example, suppose method B in superclass A is exchanged with method D in subclass C. After one exchange, superclass A holds the IMP of method D, and subclass C holds the IMP of method B. But if they are exchanged again, everything is restored: superclass A still holds the IMP of method B, and subclass C still holds the IMP of method D. This is equivalent to not having swapped them at all. As you can see, if dispatch\_once is not used, then after an even number of swaps, it is equivalent to no swap having occurred, and Swizzling becomes ineffective!

3.When Swizzling is performed in +load, do not call [super load]

The reason is the same as caveat two: if there is an inheritance hierarchy and the same method is Swizzled in multiple classes, calling [super load] will make the superclass’s Swizzling ineffective.


4.There is no error in the template above

Some people suspect that the template I provided above may be incorrect. This needs some explanation.

When performing Swizzling, we need to first use class\_addMethod to determine whether the original class has an implementation of the method to be replaced.

If class\_addMethod returns NO, it means the current class has an implementation of the method to be replaced, so we can swap directly by calling method\_exchangeImplementations to implement Swizzling.

If class\_addMethod returns YES, it means the current class does not have an implementation of the method to be replaced, and we need to look for it in the superclass. At this point, we need to use method\_getImplementation to obtain the method implementation from class\_getInstanceMethod, and then use class\_replaceMethod to implement Swizzling.

This is one point that must be checked when doing Swizzling.

Another point to note is that, in our replacement method - (void)xxx\_viewWillAppear:(BOOL)animated, we call [self xxx\_viewWillAppear:animated];. Isn’t that an infinite loop?

In fact, this does not cause an infinite loop.
Because we performed Swizzling, the original - (void)viewWillAppear:(BOOL)animated method actually calls the implementation of - (void)xxx\_viewWillAppear:(BOOL)animated. Therefore, it does not cause an infinite loop. Conversely, if [self xxx\_viewWillAppear:animated]; were changed to [self viewWillAppear:animated];, it would cause an infinite loop. When the caller invokes [self viewWillAppear:animated];, the swapped method dispatch will enter the implementation of [self xxx\_viewWillAppear:animated];, and then this implementation calls [self viewWillAppear:animated] again, creating an infinite loop.

So if you follow the Swizzling template above, you will not run into these four issues.


##### 4.Method Swizzling Use Cases

There are actually many, many use cases for Method Swizzling. In certain special development scenarios, using this bit of “black magic” at the right time can produce remarkably elegant results. Here are three common scenarios.

1.Implementing AOP

An AOP example was given in the previous article, and the next chapter will also analyze its implementation principles in detail, so I will only mention it briefly here.

2.Implementing analytics tracking

If an app requires event tracking and you need to implement your own tracking logic, using Swizzling is a very suitable choice. The advantages were already analyzed at the beginning, so I will not repeat them here. I found an excellent article analyzing tracking implementation and recommend that everyone read it.
[iOS Runtime Dynamism (Part 2): A Reusable and Highly Decoupled User Analytics Tracking Implementation](http://www.jianshu.com/p/0497afdad36d)

3.Implementing exception protection

In day-to-day development, we often encounter out-of-bounds access with NSArray. Apple’s APIs do not provide exception protection for this either, so developers need to pay close attention during development. There are many Index-related methods, such as objectAtIndex, removeObjectAtIndex, replaceObjectAtIndex, exchangeObjectAtIndex, and so on. Anything involving Index needs to check whether it is out of bounds.

A common approach is to add categories to NSArray and NSMutableArray and add methods that provide this exception protection. However, if the existing project already contains a large number of AtIndex-series method calls, replacing them all with the new category methods would be inefficient. In this case, you can consider using Swizzling.
```objectivec


#import "NSArray+ Swizzling.h"

#import "objc/runtime.h"
@implementation NSArray (Swizzling)
+ (void)load {
    Method fromMethod = class_getInstanceMethod(objc_getClass("__NSArrayI"), @selector(objectAtIndex:));
    Method toMethod = class_getInstanceMethod(objc_getClass("__NSArrayI"), @selector(swizzling_objectAtIndex:));
    method_exchangeImplementations(fromMethod, toMethod);
}

- (id)swizzling_objectAtIndex:(NSUInteger)index {
    if (self.count-1 < index) {
        // Exception handling
        @try {
            return [self swizzling_objectAtIndex:index];
        }
        @catch (NSException *exception) {
            // Print crash information
            NSLog(@"---------- %s Crash Because Method %s  ----------\n", class_getName(self.class), __func__);
            NSLog(@"%@", [exception callStackSymbols]);
            return nil;
        }
        @finally {}
    } else {
        return [self swizzling_objectAtIndex:index];
    }
}
@end

```
Note that when calling the objc\_getClass method, you must first know the actual class name corresponding to the class. `NSArray` actually corresponds to `__NSArrayI` in the Runtime, `NSMutableArray` corresponds to `__NSArrayM`, `NSDictionary` corresponds to `__NSDictionaryI`, and `NSMutableDictionary` corresponds to `__NSDictionaryM`.


#### III. Aspect Oriented Programming


![](https://img.halfrost.com/Blog/ArticleImage/25_4.png)


Wikipedia describes AOP as follows:

>An aspect can alter the behavior of the base code by applying advice (additional behavior) at various join points (points in a program) specified in a quantification or query called a pointcut (that detects whether a given join point matches).


Concerns such as logging, authentication, and caching are tedious, unrelated to business logic, appear in many places, and are difficult to abstract into a single module. The industry has given this kind of programming problem a name: Cross-cutting concern. The role of [AOP](https://en.wikipedia.org/wiki/Aspect-oriented_programming) is to separate cross-cutting concerns to improve module reuse. It can add extra behavior (logging, authentication, caching) to existing code without modifying that code.

Next, let’s analyze how AOP works.

As we analyzed in the previous article, during the process where the `objc_msgSend` function looks up the IMP, if the corresponding IMP cannot be found even in the superclass, it starts executing the \_class\_resolveMethod method. If it is not a metaclass, it executes \_class\_resolveInstanceMethod; if it is a metaclass, it executes \_class\_resolveClassMethod. In this method, developers are allowed to dynamically add method implementations. This stage is generally used to provide dynamic methods for `@dynamic` property variables.


If \_class\_resolveMethod cannot handle it, the runtime starts choosing a fallback receiver to accept the message; at this point, it reaches the `forwardingTargetForSelector` method. If this method returns a non-nil object, that object is used as the new message receiver.
```objectivec


- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(aSelector == @selector(Method:)){
        return otherObject;
    }
    return [super forwardingTargetForSelector:aSelector];
}

```
Class methods can also be replaced in the same way.
```objectivec

+ (id)forwardingTargetForSelector:(SEL)aSelector {
    if(aSelector == @selector(xxx)) {
        return NSClassFromString(@"Class name");
    }
    return [super forwardingTargetForSelector:aSelector];
}

```
The return value of a replacement class method is a class object.

The forwardingTargetForSelector approach is simple forwarding and cannot process the message’s arguments or return value.

Finally, execution reaches the full forwarding stage.

The runtime system sends a methodSignatureForSelector: message to the object and uses the returned method signature to create an NSInvocation object. It creates an NSMethodSignature object for the subsequent full message forwarding. The NSMethodSignature object is wrapped into an NSInvocation object, and forwardInvocation: can then process the NSInvocation.
```objectivec

// Returns an NSMethodSignature instance for the method invoked on the target object

#warning The runtime system requires this method to be implemented when performing standard forwarding
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    return [self.proxyTarget methodSignatureForSelector:sel];
}

```
The object needs to create an `NSInvocation` object that encapsulates all the details of the message invocation, including parameters such as the selector, target, and arguments, and it can also handle the return value.

Most AOP operations are completed in `forwardInvocation`. Generally, this is divided into two phases: the Interceptor registration phase and the Interceptor execution phase.


##### 1. Interceptor Registration

![](https://img.halfrost.com/Blog/ArticleImage/25_5.png)

First, the `IMP` of a method in the class that needs to be advised is added to the Aspect. If the class method has an `IMP` for `forwardingTargetForSelector:`, that also needs to be added to the Aspect.

![](https://img.halfrost.com/Blog/ArticleImage/25_6.png)


Then the `IMP`s of the advised method and `forwardingTargetForSelector:` are replaced. Their `IMP`s are respectively replaced with the `objc\_msgForward()` method and the hooked `forwardingTargetForSelector:`. At this point, the main Interceptor registration is complete.


##### 2. Interceptor Execution

![](https://img.halfrost.com/Blog/ArticleImage/25_7.png)


When the `func()` method is executed, its `IMP` is looked up. Since its `IMP` has already been replaced by us with the `objc\_msgForward()` method, the runtime starts looking for a fallback forwarding target.

Finding a fallback receiver calls the `forwardingTargetForSelector:` method. Since this has been hooked here, its `IMP` points to the hooked `forwardingTargetForSelector:` method. Here, we return the Aspect's target—that is, we choose the Aspect as the fallback receiver.

Once there is a fallback receiver, `objc\_msgSend` is performed again, restarting from the message-sending phase.


`objc\_msgSend` cannot find the specified `IMP`, then proceeds to `_class\_resolveMethod`; nothing is found there either. `forwardingTargetForSelector:` does not handle it here, so execution continues to `methodSignatureForSelector`. In the `methodSignatureForSelector` method, an `NSInvocation` object is created and passed to the final `forwardInvocation` method.


The `forwardInvocation` method inside the Aspect does all the aspect-related work. At this point, the forwarding logic is entirely customized by us. During Interceptor registration, we also added the `IMP`s of the original method's `method()` and `forwardingTargetForSelector:` methods. Here, we can execute these `IMP`s inside `forwardInvocation`. Before and after executing these `IMP`s, we can insert any `IMP` we want to achieve the purpose of aspect-oriented programming.

The above is the principle behind AOP.


#### IV. Isa Swizzling

The second point above discussed the dark magic of Method Swizzling, which is essentially the exchange of `IMP` and `SEL`. The Isa Swizzling we are about to discuss is similar in nature: it is also an exchange, except what is exchanged is `isa`.

There is a very famous technique in Apple's official libraries that uses Isa Swizzling: KVO—Key-Value Observing.

The [official documentation](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOImplementation.html) defines KVO as follows:

>Automatic key-value observing is implemented using a technique called *isa-swizzling*.
The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
You should never rely on the isa pointer to determine class membership. Instead, you should use the [class](https://developer.apple.com/reference/objectivec/1418956-nsobject/1571949-class) method to determine the class of an object instance.


That is all the official documentation provides; it does not explain the concrete implementation very clearly. So we can only experiment ourselves.

KVO is used to observe whether the value of a certain property of an object changes. When the property value changes, its setter method will definitely be called. Therefore, the essence of KVO is to observe whether the object calls the setter method corresponding to the observed property. The concrete implementation should simply be to override that setter method.

How does Apple elegantly implement overriding the setter method of the observed class? The experimental code is as follows:
```objectivec

    Student *stu = [[Student alloc]init];
    
    [stu addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];

```
We can print it to observe where the `isa` pointer points.
```vim

Printing description of stu->isa:
Student
Printing description of stu->isa:
NSKVONotifying_Student

```
From the printed output, we can clearly see that the observed object’s isa has changed; it has become the NSKVONotifying_Student class.

In the @interface NSObject(NSKeyValueObserverRegistration) category, Apple defines the KVO methods.
```objectivec

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context NS_AVAILABLE(10_7, 5_0);

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

```
After KVO calls the `addObserver` method, Apple’s approach is to point `isa` to another class after executing the `addObserver:forKeyPath:options:context:` method.

In this new class, four methods of the observed object are overridden: `class`, the setter, `dealloc`, and `_isKVOA`.

##### 1. Override the class method
The `class` method is overridden so that when we call it, it returns the same value as it did before the subclass was created.
```objectivec

static NSArray * ClassMethodNames(Class c)
{
    NSMutableArray * array = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method * methodList = class_copyMethodList(c, &methodCount);
    unsigned int i;
    for(i = 0; i < methodCount; i++) {
        [array addObject: NSStringFromSelector(method_getName(methodList[i]))];
    }
    
    free(methodList);
    return array;
}

int main(int argc, char * argv[]) {
    
    Student *stu = [[Student alloc]init];
    
    NSLog(@"self->isa:%@",object_getClass(stu));
    NSLog(@"self class:%@",[stu class]);
    NSLog(@"ClassMethodNames = %@",ClassMethodNames(object_getClass(stu)));
    [stu addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
    
    NSLog(@"self->isa:%@",object_getClass(stu));
    NSLog(@"self class:%@",[stu class]);
    NSLog(@"ClassMethodNames = %@",ClassMethodNames(object_getClass(stu)));
}

```
Print result
```vim

self->isa:Student
self class:Student
ClassMethodNames = (
".cxx_destruct",
name,
"setName:"
)

self->isa:NSKVONotifying_Student
self class:Student
ClassMethodNames = (
"setName:",
class,
dealloc,
"_isKVOA"
)

```
This also shows the difference between the `object_getClass` method and the `class` method.

One point worth calling out here is why printing the results of the `object_getClass` method and the `class` method produces different output.
```objectivec

- (Class)class {
    return object_getClass(self);
}

Class object_getClass(id obj)  
{
    if (obj) return obj->getIsa();
    else return Nil;
}

```
From an implementation perspective, the two methods are implemented the same way. In theory, the printed results should be identical. So why do the printed results differ after KVO is added?

**Root cause: For KVO, the underlying implementation swizzles the `class` method of NSKVONotifying\_Student so that it returns Student.**

When printing this expression, object\_getClass(stu), the isa is of course NSKVONotifying\_Student.
```objectivec

+ (BOOL)respondsToSelector:(SEL)sel {
    if (!sel) return NO;
    return class_respondsToSelector_inst(object_getClass(self), sel, self);
}


```
When we execute NSLog, the method above is invoked. The sel for this method is `encodeWithOSLogCoder:options:maxLength:`. At this point, self is NSKVONotifying\_Student, and the result returned by `object_getClass(self)` inside the respondsToSelector method above is still NSKVONotifying\_Student.

When printing [stu class], the isa is of course still NSKVONotifying\_Student. When execution reaches NSLog, `+ (BOOL)respondsToSelector:(SEL)sel` is invoked again. This time, self becomes Student, so the output of object\_getClass(self) inside the respondsToSelector method is naturally Student.


##### 2. Override the setter method

In the new class, the corresponding set method is overridden in order to add calls to two other methods inside the set method:
```objectivec

- (void)willChangeValueForKey:(NSString *)key
- (void)didChangeValueForKey:(NSString *)key

```
Call it again in the `didChangeValueForKey:` method.
```objectivec

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context

```
There are several cases to clarify:

1) If KVC is used

If accessor methods exist, the runtime calls the `will/didChangeValueForKey:` methods inside the setter method.

If accessor methods are not used, the runtime calls the `will/didChangeValueForKey:` methods inside the `setValue:forKey` method.

So in this case, KVO works.

2) If accessor methods exist

The runtime rewrites the accessor methods to call the `will/didChangeValueForKey:` methods.  
Therefore, when you change a property value by directly calling an accessor method, KVO can also observe it.

3) Directly call the `will/didChangeValueForKey:` methods.

In summary, as long as the setter overrides the `will/didChangeValueForKey:` methods, KVO can be used.

##### 3. Override the dealloc method

Destroy the newly generated NSKVONotifying_ class.

##### 4. Override the _isKVOA method

This private method is probably used to mark that the class is one claimed by the KVO mechanism.

What helper functions for KVO does Foundation provide us with? Open Terminal and use the `nm -a` command to inspect the information in Foundation:
```vim

nm -a /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation

```
It includes the following functions that may be used in KVO:
```vim

00000000000233e7 t __NSSetDoubleValueAndNotify
00000000000f32ba t __NSSetFloatValueAndNotify
0000000000025025 t __NSSetIntValueAndNotify
000000000007fbb5 t __NSSetLongLongValueAndNotify
00000000000f33e8 t __NSSetLongValueAndNotify
000000000002d36c t __NSSetObjectValueAndNotify
0000000000024dc5 t __NSSetPointValueAndNotify
00000000000f39ba t __NSSetRangeValueAndNotify
00000000000f3aeb t __NSSetRectValueAndNotify
00000000000f3512 t __NSSetShortValueAndNotify
00000000000f3c2f t __NSSetSizeValueAndNotify
00000000000f363b t __NSSetUnsignedCharValueAndNotify
000000000006e91f t __NSSetUnsignedIntValueAndNotify
0000000000034b5b t __NSSetUnsignedLongLongValueAndNotify
00000000000f3766 t __NSSetUnsignedLongValueAndNotify
00000000000f3890 t __NSSetUnsignedShortValueAndNotify
00000000000f3060 t __NSSetValueAndNotifyForKeyInIvar
00000000000f30d7 t __NSSetValueAndNotifyForUndefinedKey

```
Foundation provides helper functions for most fundamental data types (in Objective-C, `Boolean` is merely a `typedef` of `unsigned char`, so it is included, but not C++ `bool`). It also includes some common structs such as Point, Range, Rect, and Size. This indicates that these structs can also be used with automatic key-value observing, but note that structs beyond these cannot be used with automatic key-value observing. For all Objective-C objects, the corresponding method is `__NSSetObjectValueAndNotify`.


KVO, even Apple’s official implementation, has its flaws. This article provides a detailed analysis of [the flaws in KVO](http://www.mikeash.com/pyblog/key-value-observing-done-right.html). The main issue lies in KVO’s callback mechanism: you cannot pass a selector or block as the callback, and instead must override the `-addObserver:forKeyPath:options:context:` method, which leads to a series of problems. It is still manageable when observing only one or two property values, but if you observe many properties, or properties on multiple objects, it becomes somewhat cumbersome, requiring a lot of `if-else` checks inside the method.


Finally, at the end of the official documentation’s description of KVO’s implementation, it points out something we need to keep in mind: **never use `isa` to determine a class’s inheritance relationship; instead, use the `class` method to determine an instance’s class.**


#### Five. Associated Object

![](https://img.halfrost.com/Blog/ArticleImage/25_8.png)


Associated Objects are one of the Runtime features introduced in Objective-C 2.0. As we all know, in a Category, we cannot add `@property`, because adding `@property` does not automatically generate instance variables or accessor methods for us. Now, however, we can use associated objects to implement the ability to add properties in a Category.

##### 1. Usage

Let’s borrow the example from this classic article, [Associated Objects](http://nshipster.com/associated-objects/), to explain the usage.
```objectivec

// NSObject+AssociatedObject.h
@interface NSObject (AssociatedObject)
@property (nonatomic, strong) id associatedObject;
@end

// NSObject+AssociatedObject.m
@implementation NSObject (AssociatedObject)
@dynamic associatedObject;

- (void)setAssociatedObject:(id)object {
    objc_setAssociatedObject(self, @selector(associatedObject), object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)associatedObject {
    return objc_getAssociatedObject(self, @selector(associatedObject));
}

```
This involves three functions:
```objectivec

OBJC_EXPORT void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

OBJC_EXPORT id objc_getAssociatedObject(id object, const void *key)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

OBJC_EXPORT void objc_removeAssociatedObjects(id object)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

```
Here is what these parameters mean:

1.id object Sets the instance object for the associated object

2.const void *key The key used to distinguish different associated objects. There are three ways to write this.


Use &AssociatedObjectKey as the key value
```objectivec

static char AssociatedObjectKey = "AssociatedKey";

```
Use `AssociatedKey` as the key value
```objectivec

static const void *AssociatedKey = "AssociatedKey";

```
Using @selector
```objectivec

@selector(associatedKey)

```
All three methods work, but the more concise third approach is recommended.


3. The object associated with the id value

4. `objc_AssociationPolicy policy` The storage policy for the associated object. It is an enum that corresponds to the attributes of a `property`.

![](https://img.halfrost.com/Blog/ArticleImage/25_13.png)

One thing to note here is that an associated object marked as `OBJC_ASSOCIATION_ASSIGN` is not the same as `@property (weak)`. In the table above, the equivalent definition is `@property (unsafe_unretained)`: when the object is destroyed, the property value still remains. If you use that object again afterward, the program will crash. Therefore, you need to be especially careful when using `OBJC_ASSOCIATION_ASSIGN`.

>According to the Deallocation Timeline described in [WWDC 2011, Session 322](https://developer.apple.com/videos/wwdc/2011/#322-video)(~36:00), associated objects are erased surprisingly late in the object lifecycle, inobject_dispose(), which is invoked by NSObject -dealloc.


One more point to clarify about associated objects is `objc_removeAssociatedObjects`. This method removes all associated objects from the source object, not just one of them. Therefore, its parameters do not include a specific key. To delete a specific associated object, use `objc_setAssociatedObject` to set the corresponding key to `nil`.
```objectivec

objc_setAssociatedObject(self, associatedKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);

```
Three Use Cases for Associated Objects

1. Add private variables to an existing class
2. Add public properties to an existing class
3. Create an associated observer for KVO.


##### 2. Source Code Analysis

###### (1) objc\_setAssociatedObject Method
```objectivec

void _object_set_associative_reference(id object, void *key, id value, uintptr_t policy) {
    // retain the new value (if any) outside the lock.
    ObjcAssociation old_association(0, nil);
    id new_value = value ? acquireValue(value, policy) : nil;
    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.associations());
        disguised_ptr_t disguised_object = DISGUISE(object);
        if (new_value) {
            // break any existing association.
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i != associations.end()) {
                // secondary table exists
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    j->second = ObjcAssociation(policy, new_value);
                } else {
                    (*refs)[key] = ObjcAssociation(policy, new_value);
                }
            } else {
                // create the new association (first time).
                ObjectAssociationMap *refs = new ObjectAssociationMap;
                associations[disguised_object] = refs;
                (*refs)[key] = ObjcAssociation(policy, new_value);
                object->setHasAssociatedObjects();
            }
        } else {
            // setting the association to nil breaks the association.
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i !=  associations.end()) {
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    refs->erase(j);
                }
            }
        }
    }
    // release the old value (outside of the lock).
    if (old_association.hasValue()) ReleaseValue()(old_association);
}

```
This function is mainly divided into two parts: one where the corresponding `new_value` in the `if` branch is not `nil`, and the other where the corresponding `new_value` in the `else` branch is `nil`.

When `new_value` is not `nil`, the lookup flow is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/25_9.png)

First, the structure of `AssociationsManager` is as follows:
```objectivec

class AssociationsManager {
    static spinlock_t _lock;
    static AssociationsHashMap *_map;
public:
    AssociationsManager()   { _lock.lock(); }
    ~AssociationsManager()  { _lock.unlock(); }
    
    AssociationsHashMap &associations() {
        if (_map == NULL)
            _map = new AssociationsHashMap();
        return *_map;
    }
};
```
In AssociationsManager, there is a spinlock-type [spinlock](https://en.wikipedia.org/wiki/Spinlock) named lock. It ensures that only one thread operates on AssociationsManager at a time, guaranteeing thread safety. AssociationsHashMap corresponds to a hash table.


In the AssociationsHashMap hash table, the key is disguised\_ptr\_t.
```objectivec

disguised_ptr_t disguised_object = DISGUISE(object);

```
Obtain a pointer to the `object` address by calling the `DISGUISE()` method. After getting `disguised_object`, use this key to find the corresponding value in the `AssociationsHashMap` hash table. That value is the starting address of the `ObjcAssociationMap` table.

In the `ObjcAssociationMap` table, the key is the parameter `const void *key` passed into the set method, and the value is an `ObjcAssociation` object.

The `ObjcAssociation` object stores the last two parameters of the set method: `policy` and `value`.

So the four parameters passed to the `objc_setAssociatedObject` method are already marked in the diagram above.

Now that the structure is clear, the source code becomes much easier to understand. The purpose of the `objc_setAssociatedObject` method is to store the corresponding key-value pairs in these two hash tables.

First, initialize an `AssociationsManager` and obtain the unique `AssociationsHashMap` hash table used to store associated objects. Then look up the pointer to the `object` address in `AssociationsHashMap`.

If it is found, the second table, `ObjectAssociationMap`, has been found. Continue looking up the object’s key in this table.
```objectivec

if (i != associations.end()) {
    // secondary table exists
    ObjectAssociationMap *refs = i->second;
    ObjectAssociationMap::iterator j = refs->find(key);
    if (j != refs->end()) {
        old_association = j->second;
        j->second = ObjcAssociation(policy, new_value);
    } else {
        (*refs)[key] = ObjcAssociation(policy, new_value);
    }
}

```
If the corresponding `ObjcAssociation` object is found in the second table, `ObjectAssociationMap`, its value is updated. If it is not found, a new `ObjcAssociation` object is created and inserted into the second table, `ObjectAssociationMap`.

Returning to the first table, `AssociationsHashMap`, if the corresponding key-value pair is not found
```objectivec

ObjectAssociationMap *refs = new ObjectAssociationMap;
associations[disguised_object] = refs;
(*refs)[key] = ObjcAssociation(policy, new_value);
object->setHasAssociatedObjects();

```
At this point, the second table, `ObjectAssociationMap`, does not yet exist, so a second `ObjectAssociationMap` table needs to be created to maintain all newly added properties for the object. After creating the second `ObjectAssociationMap` table, an `ObjcAssociation` object must also be instantiated and added to the Map. Then `setHasAssociatedObjects` is called to indicate that the current object has associated objects. The `setHasAssociatedObjects` method changes the value of the second flag bit, `has_assoc`, in the `isa_t` struct. (For details about the structure of the `isa_t` struct, see the analysis from Day 1.)
```objectivec

// release the old value (outside of the lock).
 if (old_association.hasValue()) ReleaseValue()(old_association);

```
Finally, if the old association object has a value, it will also be released at this point.

The above covers the case where `new_value` is not `nil`. In fact, as long as you remember the structure of the two tables above, the `objc_setAssociatedObject` process is simply the process of updating / creating key-value pairs in the table.

Now let’s look at the case where `new_value` is `nil`.
```objectivec

// setting the association to nil breaks the association.
AssociationsHashMap::iterator i = associations.find(disguised_object);
if (i !=  associations.end()) {
    ObjectAssociationMap *refs = i->second;
    ObjectAssociationMap::iterator j = refs->find(key);
    if (j != refs->end()) {
        old_association = j->second;
        refs->erase(j);
    }
}

```
When new\_value is nil, it means we need to remove the associated object. At this point, we find the corresponding key-value pair in the two tables and call the erase( ) method to delete the corresponding associated object.


###### (2) objc\_getAssociatedObject Method
```objectivec

id _object_get_associative_reference(id object, void *key) {
    id value = nil;
    uintptr_t policy = OBJC_ASSOCIATION_ASSIGN;
    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.associations());
        disguised_ptr_t disguised_object = DISGUISE(object);
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        if (i != associations.end()) {
            ObjectAssociationMap *refs = i->second;
            ObjectAssociationMap::iterator j = refs->find(key);
            if (j != refs->end()) {
                ObjcAssociation &entry = j->second;
                value = entry.value();
                policy = entry.policy();
                if (policy & OBJC_ASSOCIATION_GETTER_RETAIN) ((id(*)(id, SEL))objc_msgSend)(value, SEL_retain);
            }
        }
    }
    if (value && (policy & OBJC_ASSOCIATION_GETTER_AUTORELEASE)) {
        ((id(*)(id, SEL))objc_msgSend)(value, SEL_autorelease);
    }
    return value;
}


```
The objc\_getAssociatedObject method is very simple. It finds the corresponding ObjcAssociation object by iterating over all key-value pairs in the AssociationsHashMap hash table and the ObjcAssociationMap table. If it finds one, it returns the ObjcAssociation object; if not, it returns nil.


###### (3) The objc\_removeAssociatedObjects method
```objectivec

void objc_removeAssociatedObjects(id object) {
    if (object && object->hasAssociatedObjects()) {
        _object_remove_assocations(object);
    }
}

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
When removing the associated object for `object`, it first checks the value of the second bit `has_assoc` in `object`’s `isa\_t`. Only when `object` exists and `object->hasAssociatedObjects( )` returns 1 will it call the \_object\_remove\_assocations method.

The purpose of the \_object\_remove\_assocations method is to delete the second `ObjcAssociationMap` table, that is, to delete all associated objects. To delete the second table, it needs to traverse and search in the first `AssociationsHashMap` table. Here, all `ObjcAssociation` objects in the second `ObjcAssociationMap` table are stored in an array named `elements`, and then `associations.erase( )` is called to delete the second table. Finally, it traverses the `elements` array and releases the `ObjcAssociation` objects one by one.


The above is the source-code analysis of the three functions for Associated Object.


#### VI. Dynamically Adding Methods

During message sending, if the corresponding IMP still cannot be found in the superclass, the `resolveInstanceMethod` method will be executed. In this method, we can dynamically add methods to a class object or an instance object.
```objectivec

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    
    NSString *selectorString = NSStringFromSelector(sel);
    if ([selectorString isEqualToString:@"method1"]) {
        class_addMethod(self.class, @selector(method1), (IMP)functionForMethod1, "@:");
    }
    
    return [super resolveInstanceMethod:sel];
}

```
Other functions related to method operations include the following:
```objectivec

// Invoke the implementation of the specified method
id method_invoke ( id receiver, Method m, ... );
// Invoke the implementation of a method that returns a data structure
void method_invoke_stret ( id receiver, Method m, ... );
// Get the method name
SEL method_getName ( Method m );
// Return the method implementation
IMP method_getImplementation ( Method m );
// Get the string describing the method parameter and return value types
const char * method_getTypeEncoding ( Method m );
// Get the string for the method return type
char * method_copyReturnType ( Method m );
// Get the type string for the argument at the specified position
char * method_copyArgumentType ( Method m, unsigned int index );
// Return the method return type string by reference
void method_getReturnType ( Method m, char *dst, size_t dst_len );
// Return the number of method arguments
unsigned int method_getNumberOfArguments ( Method m );
// Return the type string for the argument at the specified position by reference
void method_getArgumentType ( Method m, unsigned int index, char *dst, size_t dst_len );
// Return the method description structure for the specified method
struct objc_method_description * method_getDescription ( Method m );
// Set the method implementation
IMP method_setImplementation ( Method m, IMP imp );
// Exchange the implementations of two methods
void method_exchangeImplementations ( Method m1, Method m2 );

```
You don’t really need to memorize these methods in day-to-day work. When you need to use them, just start by typing `method`; the completion suggestions will appear. Find the appropriate method and pass in the corresponding method.

#### VII. Automatic Archiving and Unarchiving with NSCoding

![](https://img.halfrost.com/Blog/ArticleImage/25_10.png)


Although handwritten archiving and unarchiving are less common now, the automatic approach is still implemented using Runtime.
```objectivec

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:self.name forKey:@"name"];
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    if (self = [super init]) {
        self.name = [aDecoder decodeObjectForKey:@"name"];
    }
    return self;
}

```
The manual approach has one drawback: when there are many properties, you have to write many lines of similar code. Although the functionality can be implemented perfectly, it doesn’t look very elegant.

The idea of using runtime is relatively simple: we loop through and find the name of each member variable, then use KVC to read and assign values, which lets us implement `encodeWithCoder` and `initWithCoder`.
```objectivec

#import "Student.h"

#import <objc/runtime.h>

#import <objc/message.h>

@implementation Student

- (void)encodeWithCoder:(NSCoder *)aCoder{
    unsigned int outCount = 0;
    Ivar *vars = class_copyIvarList([self class], &outCount);
    for (int i = 0; i < outCount; i ++) {
        Ivar var = vars[i];
        const char *name = ivar_getName(var);
        NSString *key = [NSString stringWithUTF8String:name];

        id value = [self valueForKey:key];
        [aCoder encodeObject:value forKey:key];
    }
}

- (nullable __kindof)initWithCoder:(NSCoder *)aDecoder{
    if (self = [super init]) {
        unsigned int outCount = 0;
        Ivar *vars = class_copyIvarList([self class], &outCount);
        for (int i = 0; i < outCount; i ++) {
            Ivar var = vars[i];
            const char *name = ivar_getName(var);
            NSString *key = [NSString stringWithUTF8String:name];
            id value = [aDecoder decodeObjectForKey:key];
            [self setValue:value forKey:key];
        }
    }
    return self;
}
@end

```
class\_copyIvarList is used to get all member variables of the current Model, and ivar\_getName is used to get the name of each member variable.


#### VIII. Dictionary and Model Conversion

     

##### 1. Dictionary to Model

1. Call the class\_getProperty method to get all properties of the current Model.
2. Call property\_copyAttributeList to get the attribute list.
3. Generate the setter method based on the property name.
4. Use objc\_msgSend to call the setter method to assign values to the Model’s properties (or use KVC).
```objectivec

+(id)objectWithKeyValues:(NSDictionary *)aDictionary{
    id objc = [[self alloc] init];
    for (NSString *key in aDictionary.allKeys) {
        id value = aDictionary[key];
        
        /*Determine whether the current property is a Model*/
        objc_property_t property = class_getProperty(self, key.UTF8String);
        unsigned int outCount = 0;
        objc_property_attribute_t *attributeList = property_copyAttributeList(property, &outCount);
        objc_property_attribute_t attribute = attributeList[0];
        NSString *typeString = [NSString stringWithUTF8String:attribute.value];

        if ([typeString isEqualToString:@"@\"Student\""]) {
            value = [self objectWithKeyValues:value];
        }
        
        //Generate the setter method and call it with objc_msgSend
        NSString *methodName = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString,[key substringFromIndex:1]];
        SEL setter = sel_registerName(methodName.UTF8String);
        if ([objc respondsToSelector:setter]) {
            ((void (*) (id,SEL,id)) objc_msgSend) (objc,setter,value);
        }
        free(attributeList);
    }
    return objc;
}

```
There is a check for `typeString` in this code. This check is used to prevent nested models. For example, if `Student` contains another `Student`, it needs to be converted again here. Of course, however many levels there are, that many conversions are required.

Several well-known open-source libraries, such as JSONModel and MJExtension, are implemented this way: they use the runtime function `class_copyIvarList` to obtain the property array, iterate over all member properties of the model object, find the corresponding key in the dictionary based on the property name, and assign the value. Of course, this approach only handles types such as `NSString` and `NSNumber`. If the model contains an `NSArray` or `NSDictionary`, a second conversion step is required. If it is an array of dictionaries, you need to iterate over the dictionaries in the array, use `objectWithDict` to convert each dictionary into a model, then put the models into an array, and finally assign this model array to the original dictionary array.

##### 2. Model to Dictionary

This is the reverse of the dictionary-to-model process in the previous section:

1. Call the `class_copyPropertyList` method to get all properties of the current Model.
2. Call `property_getName` to get the property name.
3. Generate the getter method based on the property name.
4. Use `objc_msgSend` to call the getter method to obtain the property value (or use KVC).
```objectivec

//Convert model to dictionary
-(NSDictionary *)keyValuesWithObject{
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &outCount);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        //Generate the getter method and call it with objc_msgSend
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        if ([self respondsToSelector:getter]) {
            id value = ((id (*) (id,SEL)) objc_msgSend) (self,getter);
            
            /*Check whether the current property is a Model*/
            if ([value isKindOfClass:[self class]] && value) {
                value = [value keyValuesWithObject];
            }

            if (value) {
                NSString *key = [NSString stringWithUTF8String:propertyName];
                [dict setObject:value forKey:key];
            }
        }
        
    }
    free(propertyList);
    return dict;
}

```
The check in the middle comment is also meant to prevent nested models. If there is another layer of model inside a model, then when converting the model to a dictionary, it needs to be converted again as well. Likewise, however many layers there are, that many conversions are required.

However, the approach above assumes that the dictionary no longer contains nested dictionaries. If it also contains arrays, and those arrays contain dictionaries, then multi-level conversion is still required. Here is a [demo](https://github.com/XHTeng/XHRuntimeDemo) about dictionaries that contain arrays.

#### IX. Disadvantages of Runtime

![](https://img.halfrost.com/Blog/ArticleImage/25_11.png)


After reading the eight points above, do you feel that Runtime is magical and can quickly solve many problems? However, Runtime is like a Swiss Army knife: if used properly, it can solve problems effectively. But if used improperly, it can bring a lot of trouble. Someone on Stack Overflow has already raised this question: [What are the Dangers of Method Swizzling in Objective C?](http://stackoverflow.com/questions/5339276/what-are-the-dangers-of-method-swizzling-in-objective-c). Its risks are mainly reflected in the following aspects:

- Method swizzling is not atomic

Method swizzling is not an atomic operation. If you write it in the `+load` method, there is no problem, but if you write it in the `+initialize` method, some strange issues may occur.

- Changes behavior of un-owned code

If you override a method in a class and do not call the `super` method, you may cause problems. In most cases, the `super` method is expected to be called (unless otherwise specified). If you apply the same thinking to Swizzling, it may cause many problems. If you do not call the original method implementation, then your Swizzling changes too much, making the entire program unsafe.


- Possible naming conflicts

Naming conflicts are a common issue in software development. We often prefix class names and method names in categories. Unfortunately, naming conflicts are like a plague in our programs. In general, we write Method Swizzling like this:
```objectivec

@interface NSView : NSObject
- (void)setFrame:(NSRect)frame;
@end

@implementation NSView (MyViewAdditions)

- (void)my_setFrame:(NSRect)frame {
    // do custom work
    [self my_setFrame:frame];
}

+ (void)load {
    [self swizzle:@selector(setFrame:) with:@selector(my_setFrame:)];
}

@end

```
This looks fine as written. But what if, somewhere else in the large program, another `my_setFrame:` method is defined? That would again cause a naming conflict. We should change the Swizzling above to the following form:
```objectivec

@implementation NSView (MyViewAdditions)

static void MySetFrame(id self, SEL _cmd, NSRect frame);
static void (*SetFrameIMP)(id self, SEL _cmd, NSRect frame);

static void MySetFrame(id self, SEL _cmd, NSRect frame) {
    // do custom work
    SetFrameIMP(self, _cmd, frame);
}

+ (void)load {
    [self swizzle:@selector(setFrame:) with:(IMP)MySetFrame store:(IMP *)&SetFrameIMP];
}

@end

```
Although the code above does not look like OC (because it uses function pointers), this approach does effectively prevent naming conflicts. In principle, the approach above is actually more consistent with standardized Swizzling. It may differ from how people commonly use it, but it is a better approach. The standard definition of Swizzling Method should look like this:
```objectivec

typedef IMP *IMPPointer;

BOOL class_swizzleMethodAndStore(Class class, SEL original, IMP replacement, IMPPointer store) {
    IMP imp = NULL;
    Method method = class_getInstanceMethod(class, original);
    if (method) {
        const char *type = method_getTypeEncoding(method);
        imp = class_replaceMethod(class, original, replacement, type);
        if (!imp) {
            imp = method_getImplementation(method);
        }
    }
    if (imp && store) { *store = imp; }
    return (imp != NULL);
}

@implementation NSObject (FRRuntimeAdditions)
+ (BOOL)swizzle:(SEL)original with:(IMP)replacement store:(IMPPointer)store {
    return class_swizzleMethodAndStore(self, original, replacement, store);
}
@end

```
- Swizzling changes the method's arguments

This is the biggest of these issues. Standard Method Swizzling does not change a method's arguments. When using Swizzling, the arguments passed to the original function implementation may be changed, for example:
```objectivec 

[self my_setFrame:frame];

```
will be converted into
```objectivec

objc_msgSend(self, @selector(my_setFrame:), frame);

```
`objc_msgSend` looks up the IMP corresponding to `my_setFrame`. Once the IMP is found, it passes in the same arguments. In this case, it will find the original `setFrame:` method and invoke it. However, the `_cmd` argument here is not `setFrame:`; it is now `my_setFrame:`. The original method is therefore called with an argument it does not expect. That is not good.

There is a simple solution here: as mentioned in the previous section, implement this using a function pointer. The arguments will then remain unchanged.


- The order of swizzles matters

Call order is very important for swizzling. Suppose the `setFrame:` method is defined only on the `NSView` class.
```objectivec

[NSButton swizzle:@selector(setFrame:) with:@selector(my_buttonSetFrame:)];
[NSControl swizzle:@selector(setFrame:) with:@selector(my_controlSetFrame:)];
[NSView swizzle:@selector(setFrame:) with:@selector(my_viewSetFrame:)];

```
What happens after `NSButton` is swizzled? Most swizzling should ensure that the `setFrame:` method is not replaced. Once this method is changed, it affects all the views below it. So it retrieves the instance method. `NSButton` uses an existing method to redefine the `setFrame:` method, so changing the `IMP` implementation does not affect all views. The same thing also happens when swizzling `NSControl`: likewise, the `IMP` is defined in the `NSView` class. If you swap the swizzling order of the two lines for `NSControl` and `NSButton`, the result is the same.

When `NSButton`’s `setFrame:` method is called, it calls the swizzled method, and then jumps into the `setFrame:` method defined in the `NSView` class. The swizzled methods corresponding to `NSControl` and `NSView` will not be called.

`NSButton` and `NSControl` each call their own swizzling methods and do not affect each other.

But let’s change the invocation order and call `NSView` first.
```objectivec

[NSView swizzle:@selector(setFrame:) with:@selector(my_viewSetFrame:)];
[NSControl swizzle:@selector(setFrame:) with:@selector(my_controlSetFrame:)];
[NSButton swizzle:@selector(setFrame:) with:@selector(my_buttonSetFrame:)];

```
Once the `NSView` here has been swizzled first, the situation becomes very different from the one above. The `NSControl` swizzling will retrieve the replacement method from `NSView`. Correspondingly, since `NSControl` comes before `NSButton`, `NSButton` will also retrieve the replacement method from `NSControl`. This makes things extremely confusing. But that is the order in which they are arranged. In development, how can we ensure that this kind of confusion does not occur?

Furthermore, perform the swizzling in the `load` method. If you only swizzle classes that have already finished loading, then this approach is safe. The `load` method guarantees that a superclass loads its corresponding methods before any of its subclasses load theirs. This ensures that our call order is correct.


- Difficult to understand (looks recursive)

Looking at the traditionally defined swizzled method, I think it is difficult to predict what will happen. But compared with the standard swizzling above, it is still easy to understand. This point has already been addressed.


- Difficult to debug

During debugging, you may see strange stack trace information, especially when the swizzled naming is very confusing and all method calls become muddled. Compared with the standard swizzling approach, you will see clearly named methods in the stack. Another aspect of swizzling that is relatively difficult to debug is that it is hard to remember exactly which method has currently been swizzled.

Write proper documentation comments in the code, even if you think you are the only person who will ever read it. Follow this practice, and your code will be fine. Debugging it is not as difficult as debugging multithreaded code.


#### Finally

After three days of training in the “asylum,” I have gained a deeper understanding of the Objective-C Runtime.

As for the black magic of method swizzling, I personally think it is still very safe if used properly. One simple and safe measure is to swizzle only in the `load` method. As with many things in programming, it can be dangerous and frightening when you do not understand it, but once you understand how it works, using it becomes very appropriate and efficient.

For multi-person development, especially in areas where the Runtime has been modified, the documentation must be complete. If someone does not know that a method has been swizzled, debugging problems that arise can be extremely painful.

If you are developing an SDK, and some swizzling changes global methods, you must clearly note this in the documentation. Otherwise, SDK users will not know about it, strange problems will appear, and they will be stuck for a long time.

When used reasonably and with complete documentation, using the Runtime to solve specific problems is still very concise and safe.

The Runtime functions you may use most often in day-to-day work are probably the following.
```objectivec

//Get all member ivar structs of the cls class object
Ivar *class_copyIvarList(Class cls, unsigned int *outCount)
//Get the instance method struct corresponding to name in the cls class object
Method class_getInstanceMethod(Class cls, SEL name)
//Get the class method struct corresponding to name in the cls class object
Method class_getClassMethod(Class cls, SEL name)
//Get the IMP implementation for the method corresponding to name in the cls class object
IMP class_getMethodImplementation(Class cls, SEL name)
//Test whether instances of cls respond to the method corresponding to sel
BOOL class_respondsToSelector(Class cls, SEL sel)
//Get the method list corresponding to cls
Method *class_copyMethodList(Class cls, unsigned int *outCount)
//Test whether cls conforms to the protocol
BOOL class_conformsToProtocol(Class cls, Protocol *protocol)
//Add a new method to the cls class object
BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)
//Replace the implementation of the method corresponding to name in the cls class object
IMP class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
//Add a new member to cls
BOOL class_addIvar(Class cls, const char *name, size_t size, uint8_t alignment, const char *types)
//Add a new property to cls
BOOL class_addProperty(Class cls, const char *name, const objc_property_attribute_t *attributes, unsigned int attributeCount)
//Get the selector corresponding to m
SEL method_getName(Method m)
//Get the IMP pointer for the method implementation corresponding to m
IMP method_getImplementation(Method m)
//Get the encoding corresponding to method m
const char *method_getTypeEncoding(Method m)
//Get the number of arguments of method m
unsigned int method_getNumberOfArguments(Method m)
//Copy the method return type
char *method_copyReturnType(Method m)
//Get the type of the argument at index in method m
char *method_copyArgumentType(Method m, unsigned int index)
//Get the return type of method m
void method_getReturnType(Method m, char *dst, size_t dst_len)
//Get the method argument type
void method_getArgumentType(Method m, unsigned int index, char *dst, size_t dst_len)
//Set the implementation pointer of method m
IMP method_setImplementation(Method m, IMP imp)
//Exchange the function pointers for the implementations of methods m1 and m2
void method_exchangeImplementations(Method m1, Method m2)
//Get the name of v
const char *ivar_getName(Ivar v)
//Get the type encoding of v
const char *ivar_getTypeEncoding(Ivar v)
//Set the object associated with object
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
//Get the object associated with object
id objc_getAssociatedObject(id object, const void *key)
//Remove objects associated with object
void objc_removeAssociatedObjects(id object)

```
These APIs may look hard to memorize, but they are not difficult to use in practice. For method-related operations, the names generally start with `method`; for class-related ones, they generally start with `class`; most of the others start with `objc`. For the rest, you can rely on code completion hints—just looking at the method names is usually enough to find what you need. Of course, once you are very familiar with them, you can type the specific method directly without depending on code completion.

There are also some protocol-related APIs and other less commonly used APIs that you may still need from time to time. For those, refer to the [official Objective-C Runtime API documentation](https://developer.apple.com/reference/objectivec/1657527-objective_c_runtime?language=objc). The official documentation explains them in detail, so when something is unclear, make sure to read the docs.

Finally, I’d appreciate any feedback or advice.


P.S. This post is packed with content. JianShu warned me that the article was approaching the word limit, but fortunately I managed to finish it. I was discharged from the hospital successfully!

![](https://img.halfrost.com/Blog/ArticleImage/25_12.png)