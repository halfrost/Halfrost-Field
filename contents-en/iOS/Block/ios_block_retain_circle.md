# In-Depth Study of Using weakSelf, strongSelf, @weakify, and @strongify in Blocks to Resolve Retain Cycles


![](https://img.halfrost.com/Blog/ArticleTitleImage/22_0_.png)


#### Preface
In the previous article, we carefully analyzed how Blocks are implemented and how `__block` captures external variables. However, in actual use of Blocks, we still encounter some issues, such as Retain Cycles.


####Table of Contents
- 1.The Origin of Retain Cycles
- 2.How \_\_weak and \_\_strong Are Implemented
- 3.The Purpose of weakSelf and strongSelf
- 4.How @weakify and @strongify Are Implemented

#### I. The Origin of Retain Cycles

![](https://img.halfrost.com/Blog/ArticleImage/22_1.jpg)


I believe everyone is already familiar with retain cycles, but let’s briefly go over them here.

When object A strongly references object B, and object B also strongly references object A, the `retainCount` of both objects can never reach 0. As a result, the memory can never be released, leading to a memory leak. A so-called memory leak means that an object that should have been released still exists after its lifecycle has ended.


![](https://img.halfrost.com/Blog/ArticleImage/22_2.png)

This is the case between two objects. Similarly, this kind of cycle can also exist among 3, 4, ... objects. As long as they form a ring of references, it will lead to a Retain Cycle.


Of course, an object can also reference itself. When an `obj` inside an object strongly references the object itself, it can also cause a retain cycle. A common case is references inside a block.

![](https://img.halfrost.com/Blog/ArticleImage/22_3.png)


#### II. How \_\_weak and \_\_strong Are Implemented

In an ARC environment, `id` types and object types differ from other C language types: ownership qualifiers must be added before the type.

There are four ownership qualifiers in total:

1.\_\_strong qualifier
2.\_\_weak qualifier
3.\_\_unsafe\_unretained qualifier
4.\_\_autoreleasing qualifier

In general, if we do not write one explicitly, the default qualifier is \_\_strong.

To understand how \_\_strong and \_\_weak are implemented, we need to study clang (the LLVM compiler) and the objc4 Objective-C runtime library.

For clang, there is [a detailed document about ARC](http://clang.llvm.org/docs/AutomaticReferenceCounting.html). If you are interested, you can study the explanations and examples in that document carefully; they are very helpful.

The following discussion will also be based on the function descriptions in the document above.

![](https://img.halfrost.com/Blog/ArticleImage/22_4.jpg)


##### 1.How \_\_strong Is Implemented

###### (1)An object retains itself

First, let’s look at the case where a generated object retains itself, using `alloc`/`new`/`copy`/`mutableCopy` to create the object.

When we declare a \_\_strong object
```objectivec
{
    id __strong obj = [[NSObject alloc] init];
}
```
The LLVM compiler will transform the above code into something like this.
```objectivec

id __attribute__((objc_ownership(strong))) obj = ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"));
```
The corresponding one will be called.
```objectivec
id obj = objc_msgSend(NSObject, @selector(alloc));
objc_msgSend(obj,selector(init));
objc_release(obj);
```
The methods above are all easy to understand. When ARC is enabled, release code is inserted automatically, and the object is automatically released when the scope ends.


###### (2) Objects do not own themselves

Do not use methods such as alloc/new/copy/mutableCopy when creating objects.
```objectivec
{
    id __strong obj = [NSMutableArray array];
}
```
The LLVM compiler transforms the above code into something like the following:
```objectivec

id __attribute__((objc_ownership(strong))) array = ((NSMutableArray *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSMutableArray"), sel_registerName("array"));

```
According to the LLVM documentation, the process is actually as follows

The corresponding call will be made
```objectivec
id obj = objc_msgSend(NSMutableArray, @selector(array));
objc_retainAutoreleasedReturnValue(obj);
objc_release(obj);
```
Unlike the previous case where the object would retain itself, there is an additional `objc_retainAutoreleasedReturnValue` function here.

There are three functions to explain here:
1.id objc_retainAutoreleaseReturnValue(id value)
> [id objc_retainAutoreleaseReturnValue(id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id69)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-retainautoreleasereturnvalue)  
*Precondition:* value is null or a pointer to a valid object.

>If value is null, this call has no effect. Otherwise, it performs a retain operation followed by the operation described in [objc_autoreleaseReturnValue](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-autoreleasereturnvalue). 

>Equivalent to the following code:
id objc_retainAutoreleaseReturnValue(id value) {   
       return objc_autoreleaseReturnValue(objc_retain(value));
}

>Always returns value

2.id objc\_retainAutoreleasedReturnValue(id value)

>[id objc_retainAutoreleasedReturnValue(id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id70)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-retainautoreleasedreturnvalue)  
*Precondition:* value is null or a pointer to a valid object.

>If value is null, this call has no effect. Otherwise, it attempts to accept a hand off of a retain count from a call to [objc_autoreleaseReturnValue](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-autoreleasereturnvalue) on value in a recently-called function or something it calls. If that fails, it performs a retain operation exactly like [objc_retain](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-retain).


>Always returns value

3.id objc_autoreleaseReturnValue(id value)

>[id objc_autoreleaseReturnValue(id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id59)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-autoreleasereturnvalue)  
*Precondition:* value  is null or a pointer to a valid object.

>If value  is null, this call has no effect. Otherwise, it makes a best effort to hand off ownership of a retain count on the object to a call to[objc_retainAutoreleasedReturnValue](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-retainautoreleasedreturnvalue) for the same object in an enclosing call frame. If this is not possible, the object is autoreleased as above.

>Always returns value

These three functions are really describing the same thing: it makes a best effort to hand off ownership of a retain count on the object to a call to objc_retainAutoreleasedReturnValue for the same object in an enclosing call frame.

This is an optimization in the LLVM compiler. The `objc_retainAutoreleasedReturnValue` function is used by the caller to take ownership of (retain) an object. The object it retains should be the return value of a method or function that returns an object registered in an `autoreleasepool`.

In ARC, after an object is originally created, it would normally be registered in an `autoreleasepool`. However, after `objc_autoreleasedReturnValue` is called, if `objc_retainAutoreleasedReturnValue` is called immediately afterward, `objc_autoreleasedReturnValue` will inspect the instruction list of the caller of that method or function. If it finds an `objc_retainAutoreleasedReturnValue()` call there, the object is returned directly to the caller of the method or function. This makes it possible to obtain the corresponding object even without registering it in the `autoreleasepool`.


##### 2.\_\_weak Implementation Principle

Declare a \_\_weak object
```objectivec
{
    id __weak obj = strongObj;
}
```
Assume that `strongObj` here is an already declared object.

LLVM converts it into the corresponding code.
```objectivec

id __attribute__((objc_ownership(none))) obj1 = strongObj;

```
The corresponding one will be called.
```objectivec
id obj ;
objc_initWeak(&obj,strongObj);
objc_destoryWeak(&obj);

```
Let's look at the documentation

>[id objc_initWeak(id *object, id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id62)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-initweak)    
*Precondition:* object is a valid pointer which has not been registered as a \_\_weak object. 

>value  is null or a pointer to a valid object.
If value is a null pointer or the object to which it points has begun deallocation, object is zero-initialized. Otherwise, object
 is registered as a \_\_weak object pointing to value

>Equivalent to the following code:
id objc_initWeak(id *object, id value) {   
    *object = nil; 
    return objc_storeWeak(object, value);
}

>Returns the value of object after the call.
Does not need to be atomic with respect to calls to objc_storeWeak on object

The implementation of objc_initWeak is actually as follows
```objectivec

id objc_initWeak(id *object, id value) {   
    *object = nil; 
    return objc_storeWeak(object, value);
}
```
It sets the passed-in `object` to 0 or `nil`, and then executes the `objc_storeWeak` function.


So what does the `objc_destoryWeak` function do?

>[void objc_destroyWeak(id *object);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id61)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#void-objc-destroyweak-id-object)  
*Precondition:* object  is a valid pointer which either contains a null pointer or has been registered as a \_\_weak object.

>object  is unregistered as a weak object, if it ever was. The current value of object is left unspecified; otherwise, equivalent to the following code:

>void objc_destroyWeak(id *object) { 
objc_storeWeak(object, nil);
}

>Does not need to be atomic with respect to calls to objc_storeWeak on object


Implementation of the `objc_destoryWeak` function
```objectivec
void objc_destroyWeak(id *object) { 
    objc_storeWeak(object, nil);
}
```
It will also call the objc_storeWeak function. Both objc_initWeak and objc_destroyWeak call objc_storeWeak; the only difference is the arguments they pass in: one passes value, and the other passes nil.


So the focus now falls entirely on the objc_storeWeak function.
>[id objc_storeWeak(id *object, id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id73)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-storeweak)  
*Precondition:* object is a valid pointer which either contains a null pointer or has been registered as a __weak object. value
 is null or a pointer to a valid object.

>If value is a null pointer or the object to which it points has begun deallocation, object  is assigned null and unregistered as a \_\_weak object. Otherwise, object is registered as a \_\_weak object or has its registration updated to point to value

>Returns the value of object after the call.

The purpose of the objc\_storeWeak function is now quite clear. Since the weak table is also implemented using a hash table, objc\_storeWeak registers the address of the variable passed as the first parameter in the weak table, and then decides whether to remove it based on the second parameter. If the second parameter is 0, it removes the \_\_weak variable’s record from the weak table and deletes the corresponding key-value entry from the reference count table.

Therefore, if the original object referenced by \_\_weak is deallocated, the corresponding \_\_weak object will be set to nil. This is implemented through functions such as objc_storeWeak.

The above is a brief explanation of how \_\_strong and \_\_weak are implemented in ARC. For more details, please read the LLVM document mentioned at the beginning of this chapter; it explains the topic in great detail.


![](https://img.halfrost.com/Blog/ArticleImage/22_5.png)


#### III. Uses of weakSelf and strongSelf

Before discussing weakSelf and strongSelf, let’s first introduce an example of a Retain Cycle.

Suppose we have a custom student class:


Example 1:
```objectivec

#import <Foundation/Foundation.h>
typedef void(^Study)();
@interface Student : NSObject
@property (copy , nonatomic) NSString *name;
@property (copy , nonatomic) Study study;
@end

```

```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    Student *student = [[Student alloc]init];
    student.name = @"Hello World";

    student.study = ^{
        NSLog(@"my name is = %@",student.name);
    };
}

```
By this point, it should be clear that a retain cycle has definitely occurred here. The `Block` in `student`'s `study` strongly references `student` itself. Based on the analysis in the [previous article](https://www.halfrost.com/ios_block/), we know that `_NSConcreteMallocBlock` captures external objects and holds them internally. The `retainCount` value is incremented by one.

Let's observe this with Instruments. Add the Leak instrument.

After the program starts running, you should be able to see a red ❌ in the **Leak Checks** instrument. Click it and you will see the memory leak. There are two leaked objects. `Block` and `Student` are retaining each other in a cycle.

![](https://img.halfrost.com/Blog/ArticleImage/22_6.png)


Open Cycles & Roots to inspect the cycle.


![](https://img.halfrost.com/Blog/ArticleImage/22_7.png)


The reason this cycle is formed is that the block holds `student` itself, and `student` itself also holds the block.

Now let's look at a second example:
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Student *student = [[Student alloc]init];
    student.name = @"Hello World";

    student.study = ^(NSString * name){
        NSLog(@"my name is = %@",name);
    };
    student.study(student.name);
}

```
I pass a new parameter into the block: `student.name`. Will this cause a retain cycle?

The answer is definitely no.

![](https://img.halfrost.com/Blog/ArticleImage/22_8.png)

As shown above, there will be no memory leak. The reason is that `student` is passed into the block as a parameter; the block does not capture the parameter and retain it internally. Therefore, it definitely will not cause a retain cycle.

Let’s modify it again. See Example 3:
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@property (copy,nonatomic) NSString *name;
@property (strong, nonatomic) Student *stu;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Student *student = [[Student alloc]init];
    
    self.name = @"halfrost";
    self.stu = student;
    
    student.study = ^{
        NSLog(@"my name is = %@",self.name);
    };
    
    student.study();
}
```
Will this create a retain cycle?

![](https://img.halfrost.com/Blog/ArticleImage/22_9.png)


The answer is also no.

Although the ViewController strongly references `student`, the block inside `student` strongly references the `name` property of `viewController`; it does not form a cycle. If the `self.name` above were changed to `self`, it still would not create a retain cycle, because neither of them strongly references this block.


So how should we handle retain cycles when we encounter them? By analogy with the delegates we commonly write, we know that as long as one side is `__weak`, the cycle can be broken.

First, let’s discuss one approach: using `__block` to resolve the cycle. Example 4:
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Student *student = [[Student alloc]init];
    
    __block Student *stu = student;
    student.name = @"Hello World";
    student.study = ^{
        NSLog(@"my name is = %@",stu.name);
        stu = nil;
    };
}

```
Will writing it this way create a cycle? At first glance, it shouldn’t. But in reality, it does.


![](https://img.halfrost.com/Blog/ArticleImage/22_10.png)


![](https://img.halfrost.com/Blog/ArticleImage/22_11.png)


Because this block, study, has not been executed, student now holds the block, the block holds the \_\_block variable, and the \_\_block variable in turn holds the student object. The three form a cycle, resulting in a retain cycle.
To break the cycle, you need to break one of the references. It is enough to make __block not hold student.

You only need to execute the block once. Example 5:
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Student *student = [[Student alloc]init];
    student.name = @"Hello World";
    __block Student *stu = student;

    student.study = ^{
        NSLog(@"my name is = %@",stu.name);
        stu = nil;
    };

    student.study();
}

```
This prevents a retain cycle.

![](https://img.halfrost.com/Blog/ArticleImage/22_12.png)

Using \_\_block to solve retain cycles can control how long an object is held, and within the block you can dynamically control the value of the \_\_block variable: you can assign it nil, or assign it some other value. However, it has one drawback: the block must be executed at least once. Otherwise, it will still cause a retain cycle.


** It is worth noting that under ARC, \_\_block causes the object to be retained, which may lead to a retain cycle. Under MRC, however, it does not retain the object and therefore does not cause a retain cycle.** [You can read this experiment by kuailejim for more details](http://www.jianshu.com/p/e03292674e60)
>In an MRC environment, __block does not perform a copy operation on the object pointed to by the pointer at all; it merely copies the pointer. This is something many beginners—and even experienced developers—often do not know!

>In an ARC environment, for external objects declared as __block, the block will retain them internally, so that external objects can be safely referenced within the block environment. Therefore, be careful to avoid retain cycles!


Next, we can formally discuss how to use weakSelf and strongSelf.

##### 1.weakSelf

Speaking of weakSelf, we first need to distinguish between several ways of writing it.
\_\_weak \_\_typeof(self)weakSelf = self;  This is how it is written in AFN.

\#define WEAKSELF typeof(self) __weak weakSelf = self; This is how we usually write it.

First, distinguish between \_\_typeof() and typeof().
The author has always admired the author of AFNetWorking. The code in this library is very clean, and the code in all aspects of it can be read as a model example. Whenever you encounter something you do not understand or find confusing, digging deeper will definitely be rewarding. This is one such case. Usually, the way we write it does not include \_\_. Is there any special purpose behind the way it is written in AFN?


A related [answer](http://stackoverflow.com/questions/14877415/difference-between-typeof-typeof-and-typeof-objective-c) can be found on SOF:

>\_\_typeof\_\_() and \_\_typeof() are compiler-specific extensions to the C language, because standard C does not include such an operator. Standard C requires compilers to prefix language extensions with a double\-underscore (which is also why you should never do so for your own functions, variables, etc.)
typeof() is exactly the same, but throws the underscores out the window with the understanding that every modern compiler supports it. (Actually, now that I think about it, Visual C++ might not. It does support decltype() though, which generally provides the same behaviour as typeof().)
All three mean the same thing, but none are standard C so a conforming compiler may choose to make any mean something different.

In fact, the two are the same thing; they are just different conventions in C with different compatibility implications.

More detailed [official documentation](http://gcc.gnu.org/onlinedocs/gcc/Alternate-Keywords.html#Alternate-Keywords)


Abstracting it out, there are these two forms.  
\#define WEAKSELF  \_\_weak typeof(self)weakSelf = self;  
\#define WEAKSELF typeof(self) \_\_weak weakSelf = self;

Looking at it this way makes it clear: the two forms are exactly the same.

We can use WEAKSELF to solve the retain cycle problem. Example 6:
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Student *student = [[Student alloc]init];
    student.name = @"Hello World";
    __weak typeof(student) weakSelf = student;
    
    student.study = ^{
        NSLog(@"my name is = %@",weakSelf.name);
    };

    student.study();
}
```
This solves the circular reference issue.

To solve circular reference issues, you must clearly analyze where the circular reference occurs. You only need to add a macro such as `weakSelf` to one link in the cycle to break it. If you cannot analyze it clearly, you may end up blindly adding `weakSelf` and `strongSelf` everywhere, which is not a recommended approach.

In Example 3 above, there is no circular reference at all, so blindly adding `weakSelf` and `strongSelf` would be incorrect. In Example 6, adding a single `weakSelf` is enough; there is no need to add `strongSelf`.

I once saw a similar question on SegmentFault: [Why doesn’t `self` in iOS Masonry cause a circular reference?](https://segmentfault.com/q/1010000004343510)
```objectivec


UIButton *testButton = [[UIButton alloc] init];
[self.view addSubview:testButton];
testButton.backgroundColor = [UIColor redColor];
[testButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.width.equalTo(@100);
    make.height.equalTo(@100);
    make.left.equalTo(self.view.mas_left);
    make.top.equalTo(self.view.mas_top);
}];
[testButton bk_addEventHandler:^(id sender) {
    [self dismissViewControllerAnimated:YES completion:nil];
} forControlEvents:UIControlEventTouchUpInside];

```
>If I use blocksKit’s bk_addEventHandler
method and use a strong self inside it, the viewController cannot dealloc. My understanding is that self retains self.view, which retains testButton, which retains self. But if I only use Mansonry’s mas_makeConstraints
method, also using a strong self, the viewController can dealloc normally. Why is that? Why doesn’t Masonry cause a retain cycle?


At this point, readers should be able to answer this question.
```objectivec

- (NSArray *)mas_makeConstraints:(void(^)(MASConstraintMaker *))block {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    MASConstraintMaker *constraintMaker = [[MASConstraintMaker alloc] initWithView:self];
    block(constraintMaker);
    return [constraintMaker install];
}
```
~~In this Masonry block, the block only captures `self`’s `translatesAutoresizingMaskIntoConstraints` variable, but does not retain `self`.~~

The above description is incorrect. Thanks to @酷酷的哀殿 for the patient explanation.

Correction:

Regarding Masonry, it does not capture the variable `self` internally at all. What enters the block is `testButton`, so after execution completes, the block is destroyed and no cycle is formed. Therefore, it does not cause a circular dependency.

##### 2.strongSelf

After introducing `weakSelf` above, since `weakSelf` can perfectly solve the Retain Cycle problem, why do we still need `strongSelf`?

Let’s start with the classic AFN example. The following is a snippet of code from AFN:
```objectivec

#pragma mark - NSOperation

- (void)setCompletionBlock:(void (^)(void))block {
    [self.lock lock];
    if (!block) {
        [super setCompletionBlock:nil];
    } else {
        __weak __typeof(self)weakSelf = self;
        [super setCompletionBlock:^ {
            __strong __typeof(weakSelf)strongSelf = weakSelf;

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Wgnu"
            dispatch_group_t group = strongSelf.completionGroup ?: url_request_operation_completion_group();
            dispatch_queue_t queue = strongSelf.completionQueue ?: dispatch_get_main_queue();

#pragma clang diagnostic pop

            dispatch_group_async(group, queue, ^{
                block();
            });

            dispatch_group_notify(group, url_request_operation_completion_queue(), ^{
                [strongSelf setCompletionBlock:nil];
            });
        }];
    }
    [self.lock unlock];
}

```
What happens if you don’t add __strong __typeof(weakSelf)strongSelf = weakSelf inside the block?
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Student *student = [[Student alloc]init];
    student.name = @"Hello World";
    __weak typeof(student) weakSelf = student;
    
    student.study = ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"my name is = %@",weakSelf.name);
        });
    };

    student.study();
}
```
Output:
```vim
my name is = (null)
```
Why is the output like this?

The key lies in the `dispatch_after` function. After the block in `study()` finishes, `student` is automatically released. Since `dispatch_after` captures the `__weak` `student`, based on the implementation principle of `__weak` discussed in Chapter 2, after the original object is released, the `__weak` object becomes `null` to prevent dangling pointers. Therefore, it outputs `null`.

So how can we continue using the object referenced by `weakSelf` inside the block after using `weakSelf`?

The root cause is that, after using `weakSelf`, you cannot control when it will be released. To ensure it is not released inside the block, you need to add `__strong`.

The `__strong`-qualified `weakSelf` used inside the block is intended to prevent `self` from being released prematurely during the function’s lifetime. `strongSelf` is an automatic variable; when the block finishes executing, the automatic variable `strongSelf` is released and will not keep holding a strong reference to `self` indefinitely.
```objectivec

#import "ViewController.h"

#import "Student.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Student *student = [[Student alloc]init];
    
    student.name = @"Hello World";
    __weak typeof(student) weakSelf = student;
    
    student.study = ^{
        __strong typeof(student) strongSelf = weakSelf;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"my name is = %@",strongSelf.name);
        });
        
    };

    student.study();
}
```
Output
```vim
my name is = Hello World

```
At this point, we understand the purpose of `weakSelf` and `strongSelf`.

`weakSelf` is used so that the block does not retain `self`, thereby avoiding a retain cycle. If you need to access methods or variables of `self` inside a block, it is recommended to use `weakSelf`.

The purpose of `strongSelf` is that once execution enters the block, if `self` must not be deallocated during that execution, you need to introduce `strongSelf`. After the block finishes executing, this `strongSelf` is automatically released, so there is no retain cycle issue. If you need to access `self` multiple times inside a block, you should use `strongSelf`.

To summarize retain cycles, there are three ways to resolve circular references.

Let’s summarize this using an example from *Effective Objective-C 2.0* (*52 Specific Ways to Improve Your iOS and OS X Programs*).

EOCNetworkFetcher.h
```objectivec
typedef void (^EOCNetworkFetcherCompletionHandler)(NSData *data);

@interface EOCNetworkFetcher : NSObject

@property (nonatomic, strong, readonly) NSURL *url;

- (id)initWithURL:(NSURL *)url;

- (void)startWithCompletionHandler:(EOCNetworkFetcherCompletionHandler)completion;

@end
```

EOCNetworkFetcher.m

```objectivec

@interface EOCNetworkFetcher ()

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, copy) EOCNetworkFetcherCompletionHandler completionHandler;
@property (nonatomic, strong) NSData *downloadData;

@end

@implementation EOCNetworkFetcher

- (id)initWithURL:(NSURL *)url {
    if(self = [super init]) {
        _url = url;
    }
    return self;
}

- (void)startWithCompletionHandler:(EOCNetworkFetcherCompletionHandler)completion {
    self.completionHandler = completion;
    //Start network request
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        _downloadData = [[NSData alloc] initWithContentsOfURL:_url];
        dispatch_async(dispatch_get_main_queue(), ^{
             //Network request completed
            [self p_requestCompleted];
        });
    });
}

- (void)p_requestCompleted {
    if(_completionHandler) {
        _completionHandler(_downloadData);
    }
}

@end

```

EOCClass.m

```objectivec

@implementation EOCClass {
    EOCNetworkFetcher *_networkFetcher;
    NSData *_fetchedData;
}

- (void)downloadData {
    NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
    _networkFetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
    [_networkFetcher startWithCompletionHandler:^(NSData *data) {
        _fetchedData = data;
    }];
}
@end

```
In this example, a cycle is formed among three parties:

1、Because the completion handler’s block needs to set the value of the `_fetchedData` instance variable, it must capture the `self` variable; in other words, the handler block retains the `EOCClass` instance.

2、The `EOCClass` instance retains `EOCNetworkFetcher` through a `strong` instance variable, and finally the `EOCNetworkFetcher` instance also retains the handler block.

The book describes three ways to break the cycle.

Method 1: Manually release the `_networkFetcher` held by `EOCNetworkFetcher` after use, which breaks the retain cycle.
```objectivec
- (void)downloadData {
    NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
    _networkFetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
    [_networkFetcher startWithCompletionHandler:^(NSData *data) {
        _fetchedData = data;
        _networkFetcher = nil;//Add this line to break the retain cycle
    }];
}
```
Method 2: Release the block directly. Because the object needs to be manually released after use, forgetting to release it will cause a retain cycle. After the completion handler has been used, simply release the block directly to break the retain cycle.
```objectivec

- (void)p_requestCompleted {
    if(_completionHandler) {
        _completionHandler(_downloadData);
    }
    self.completionHandler = nil;//Add this line to break the retain cycle
}
```
Method 3: Use weakSelf and strongSelf
```objectivec
- (void)downloadData {
   __weak __typeof(self) weakSelf = self;
   NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
   _networkFetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
   [_networkFetcher startWithCompletionHandler:^(NSData *data) {
        __typeof(&*weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.fetchedData = data;
        }
   }];
}
```
![](https://img.halfrost.com/Blog/ArticleImage/22_13.png)


#### IV. Implementation Principles of @weakify and @strongify

After covering weakSelf and strongSelf above, let’s now talk about @weakify and @strongify. These two keywords are macros developed in RAC to avoid retain cycles in Blocks. The implementation of these two macros is quite impressive and worth learning from.

The roles of @weakify and @strongify correspond to those of weakSelf and strongSelf. Here, let’s take a closer look at how the experts implemented these two macros.

Let’s go straight to the source code.
```objectivec

#define weakify(...) \
    rac_keywordify \
    metamacro_foreach_cxt(rac_weakify_,, __weak, __VA_ARGS__)


#define strongify(...) \
    rac_keywordify \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    metamacro_foreach(rac_strongify_,, __VA_ARGS__) \
    _Pragma("clang diagnostic pop")
```
Seeing this kind of macro definition, you have no idea what it does at first glance. So the only option is to drill down layer by layer.

##### 1. weakify
Let’s start with weakify(...).
```objectivec

#if DEBUG

#define rac_keywordify autoreleasepool {}

#else

#define rac_keywordify try {} @catch (...) {}

#endif
```
Here, @autoreleasepool is used in debug mode to preserve the compiler’s analysis capability, while @try/@catch is used to avoid inserting unnecessary autoreleasepool blocks. rac_keywordify is essentially a macro expansion to autoreleasepool {}. Because the macro expands to autoreleasepool {}, weakify needs to be prefixed with @, forming @autoreleasepool {}.
```objectivec

#define metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)

```
\_\_VA\_ARGS\_\_: In general, it copies the contents of `...` in the macro on the left verbatim to the position of \_\_VA\_ARGS\_\_ on the right. It is a variadic macro feature added in the new C99 standard, and currently it seems to be supported only by gcc (VC has supported it since VC2005).

So when we pass in @weakify(self), \_\_VA\_ARGS\_\_ is equivalent to self. At this point, we can expand the initial weakify macro. It then becomes this:

rac\_weakify\_,, \_\_weak, \_\_VA\_ARGS\_\_ as a whole replaces MACRO, SEP, CONTEXT, ...

One thing to note here is that the source code has two consecutive "," commas, so we also need to substitute the parameters equivalently; this means SEP is an empty value.

After the replacement, it looks like this:
```objectivec
autoreleasepool {}
metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(self))(rac_weakify_, , __weak, self)
```
What we need to understand now is what metamacro\_concat and metamacro\_argcount are used for.

Let's continue by looking at the implementation of metamacro\_concat.
```objectivec


#define metamacro_concat(A, B) \
        metamacro_concat_(A, B)


#define metamacro_concat_(A, B) A ## B

```
\#\# is the macro concatenation operator. For example:

Suppose the macro is defined as #define XNAME(n) x##n, and the code is: XNAME(4). During preprocessing, the macro processor finds that XNAME(4) matches XNAME(n), so it sets n to 4, then also changes the content of n on the right-hand side to 4, and finally replaces the entire XNAME(4) with x##n, i.e., x4. Therefore, the final result is that XNAME(4) becomes x4. So A##B is AB.


Implementation of metamacro\_argcount
```objectivec

#define metamacro_argcount(...) \
        metamacro_at(20, __VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


#define metamacro_at(N, ...) \
        metamacro_concat(metamacro_at, N)(__VA_ARGS__)

```
metamacro\_concat is the concatenation operator discussed above, so metamacro\_at, N = metamacro\_atN. Since N = 20, metamacro\_atN = metamacro\_at20.
```objectivec

#define metamacro_at0(...) metamacro_head(__VA_ARGS__)

#define metamacro_at1(_0, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at2(_0, _1, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at3(_0, _1, _2, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at4(_0, _1, _2, _3, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at5(_0, _1, _2, _3, _4, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at6(_0, _1, _2, _3, _4, _5, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at7(_0, _1, _2, _3, _4, _5, _6, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at8(_0, _1, _2, _3, _4, _5, _6, _7, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at9(_0, _1, _2, _3, _4, _5, _6, _7, _8, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at10(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at11(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at12(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at13(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at14(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at15(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at16(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at17(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at18(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at19(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, ...) metamacro_head(__VA_ARGS__)

#define metamacro_at20(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, ...) metamacro_head(__VA_ARGS__)

```
The purpose of metamacro\_at20 is to take the first 20 arguments and pass the remaining arguments to metamacro\_head.
```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)


#define metamacro_head_(FIRST, ...) FIRST

```
The role of metamacro\_head is to return the first argument. Going back up one level to metamacro\_at20, if we start from the original @weakify(self) and pass it in, then metamacro\_at20(self,20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1) takes the first 20 arguments, leaving the last one for metamacro\_head\_(1), so it should return 1.

metamacro\_concat(metamacro\_foreach\_cxt, metamacro\_argcount(self)) = metamacro\_concat(metamacro\_foreach\_cxt, 1) can ultimately be replaced with metamacro\_foreach\_cxt1.

Continue searching in the source code.
```objectivec

// metamacro_foreach_cxt expansions

#define metamacro_foreach_cxt0(MACRO, SEP, CONTEXT)

#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)

#define metamacro_foreach_cxt2(MACRO, SEP, CONTEXT, _0, _1) \
    metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) \
    SEP \
    MACRO(1, CONTEXT, _1)

#define metamacro_foreach_cxt3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    metamacro_foreach_cxt2(MACRO, SEP, CONTEXT, _0, _1) \
    SEP \
    MACRO(2, CONTEXT, _2)

#define metamacro_foreach_cxt4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    metamacro_foreach_cxt3(MACRO, SEP, CONTEXT, _0, _1, _2) \
    SEP \
    MACRO(3, CONTEXT, _3)

#define metamacro_foreach_cxt5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    metamacro_foreach_cxt4(MACRO, SEP, CONTEXT, _0, _1, _2, _3) \
    SEP \
    MACRO(4, CONTEXT, _4)

#define metamacro_foreach_cxt6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    metamacro_foreach_cxt5(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4) \
    SEP \
    MACRO(5, CONTEXT, _5)

#define metamacro_foreach_cxt7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    metamacro_foreach_cxt6(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5) \
    SEP \
    MACRO(6, CONTEXT, _6)

#define metamacro_foreach_cxt8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    metamacro_foreach_cxt7(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6) \
    SEP \
    MACRO(7, CONTEXT, _7)

#define metamacro_foreach_cxt9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    metamacro_foreach_cxt8(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7) \
    SEP \
    MACRO(8, CONTEXT, _8)

#define metamacro_foreach_cxt10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    metamacro_foreach_cxt9(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8) \
    SEP \
    MACRO(9, CONTEXT, _9)

#define metamacro_foreach_cxt11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    metamacro_foreach_cxt10(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9) \
    SEP \
    MACRO(10, CONTEXT, _10)

#define metamacro_foreach_cxt12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    metamacro_foreach_cxt11(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10) \
    SEP \
    MACRO(11, CONTEXT, _11)

#define metamacro_foreach_cxt13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    metamacro_foreach_cxt12(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11) \
    SEP \
    MACRO(12, CONTEXT, _12)

#define metamacro_foreach_cxt14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    metamacro_foreach_cxt13(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12) \
    SEP \
    MACRO(13, CONTEXT, _13)

#define metamacro_foreach_cxt15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    metamacro_foreach_cxt14(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13) \
    SEP \
    MACRO(14, CONTEXT, _14)

#define metamacro_foreach_cxt16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    metamacro_foreach_cxt15(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14) \
    SEP \
    MACRO(15, CONTEXT, _15)

#define metamacro_foreach_cxt17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    metamacro_foreach_cxt16(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15) \
    SEP \
    MACRO(16, CONTEXT, _16)

#define metamacro_foreach_cxt18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    metamacro_foreach_cxt17(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16) \
    SEP \
    MACRO(17, CONTEXT, _17)

#define metamacro_foreach_cxt19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    metamacro_foreach_cxt18(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17) \
    SEP \
    MACRO(18, CONTEXT, _18)

#define metamacro_foreach_cxt20(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19) \
    metamacro_foreach_cxt19(MACRO, SEP, CONTEXT, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18) \
    SEP \
    MACRO(19, CONTEXT, _19)
```
The `metamacro\_foreach\_cxt` macro definition is somewhat recursive. Here you can see that the maximum value of N is 20, so `metamacro\_foreach\_cxt19` is the largest one. `metamacro\_foreach\_cxt19` generates `rac\_weakify\_(0,\_\_weak,\_18)`, then passes the first 18 numbers into `metamacro\_foreach\_cxt18` and generates `rac\_weakify\_(0,\_\_weak,\_17)`, and so on, recursively continuing until `metamacro\_foreach\_cxt0`.
```objectivec

#define metamacro_foreach_cxt0(MACRO, SEP, CONTEXT)

```
`metamacro_foreach_cxt0` is the termination condition; it does not perform any operation.

Thus, the original `@weakify` is replaced with
```objectivec
autoreleasepool {}
metamacro_foreach_cxt1(rac_weakify_, , __weak, self)
```

```objectivec

#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)

```
Substitute parameters
```objectivec
autoreleasepool {}
rac_weakify_（0,__weak,self）

```
What ultimately needs to be parsed is rac\_weakify\_
```objectivec


#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

```
Substitute the arguments (0,\_\_weak,self) into (INDEX, CONTEXT, VAR).
INDEX = 0, CONTEXT = \_\_weak, VAR = self,

Thus
```objectivec

CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);


equivalently replaced with


__weak __typeof__(self) self_weak_ = self;
```
Ultimately, @weakify(self) = \_\_weak \_\_typeof\_\_(self) self\_weak\_ = self;

The self\_weak\_ here is completely equivalent to the weakSelf we wrote earlier.

##### 2. strongify

Next, continue analyzing strongify(...)

rac_keywordify is the same as in weakify: it is autoreleasepool {}, used only so that an @ can be placed before it.
```objectivec

_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
_Pragma("clang diagnostic pop")

```
Compared with weakify, strongify has these additional \_Pragma statements.

The \_Pragma keyword was introduced in C99. \_Pragma is more rationally designed than #pragma, and its functionality is therefore somewhat enhanced.

The equivalent replacement above
```objectivec

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Wshadow"

#pragma clang diagnostic pop

```
The purpose of the clang statement here: ignore warnings when a local variable or type declaration shadows another variable.


The original
```objectivec

#define strongify(...) \
    rac_keywordify \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    metamacro_foreach(rac_strongify_,, __VA_ARGS__) \
    _Pragma("clang diagnostic pop")
```
What you need to understand in strongify is metamacro\_foreach and rac\_strongify\_.
```objectivec

#define metamacro_foreach(MACRO, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

```
First, let's perform one substitution: `SEP =` empty, `MACRO = rac_strongify_`, `__VA_ARGS__`, which gives us the following.
```objectivec

metamacro_foreach_cxt(metamacro_foreach_iter,,rac_strongify_,self)

```
Based on the previous analysis, metamacro\_foreach\_cxt is equivalently substituted again as metamacro\_foreach\_cxt##1(metamacro\_foreach\_iter,,rac\_strongify\_,self)

According to
```objectivec

#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)
```
Replace it again with metamacro\_foreach\_iter(0, rac\_strongify\_, self)


Continue by looking at the implementation of metamacro\_foreach\_iter.
```objectivec


#define metamacro_foreach_iter(INDEX, MACRO, ARG) MACRO(INDEX, ARG)

```
Finally, replace it with rac\_strongify\_(0,self)
```objectivec

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);
```
INDEX = 0, VAR = self, so @strongify(self) is equivalent to
```objectivec

 __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

is equivalent to

__strong __typeof__(self) self = self_weak_;

```
Note that `@strongify(self)` can only be used inside a block. If you use it outside a block, an error will be reported, because it will tell you: `Redefinition of 'self'`.

To summarize:

@weakify(self) = @autoreleasepool{} \_\_weak \_\_typeof\_\_ (self) self\_weak\_ = self;

@strongify(self) = @autoreleasepool{} \_\_strong \_\_typeof\_\_(self) self = self\_weak\_;

After analysis, `@weakify(self)` and `@strongify(self)` are actually just our usual `weakSelf` and `strongSelf` with an extra `@autoreleasepool{}`. As for why such complex macro definitions are used here, I still do not understand it. If any experts know the reason, please feel free to advise.


**Update**

Regarding Example 3 in the article, many people raised questions about why no retain cycle was detected. In fact, this example is not ideal. The reference count of this `ViewController` is already 6 as soon as it is created, because it is referenced by many other objects. Of course, it strongly references `student`, because the `retainCount` value of `student` is 2. Only when the `ViewController` is released will the value for `student` be decremented by one. For this Example 3, I extracted the intermediate model again and will provide another example.


Since `ViewController` is special, let’s create a new class.
```objectivec

#import <Foundation/Foundation.h>

#import "Student.h"

@interface Teacher : NSObject
@property (copy , nonatomic) NSString *name;
@property (strong, nonatomic) Student *stu;
@end

```


```objectivec

#import "ViewController.h"

#import "Student.h"

#import "Teacher.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Student *student = [[Student alloc]init];
    Teacher *teacher = [[Teacher alloc]init];
    
    teacher.name = @"i'm teacher";
    teacher.stu = student;
    
    student.name = @"halfrost";
   
    student.study = ^{
        NSLog(@"my name is = %@",teacher.name);
    };
    
    student.study();
}


```
![](https://img.halfrost.com/Blog/ArticleImage/22_14.png)


![](https://img.halfrost.com/Blog/ArticleImage/22_15.png)


As shown in the figure, a retain cycle still occurs: `student`'s block strongly references `teacher`, and `teacher` strongly references `student`, preventing both from being released.