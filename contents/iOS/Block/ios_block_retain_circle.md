# 深入研究 Block 用 weakSelf、strongSelf、@weakify、@strongify 解决循环引用


![](https://img.halfrost.com/Blog/ArticleTitleImage/22_0_.png)



#### 前言
在上篇中，仔细分析了一下Block的实现原理以及__block捕获外部变量的原理。然而实际使用Block过程中，还是会遇到一些问题，比如Retain Circle的问题。


####目录
- 1.Retain Circle的由来
- 2.\_\_weak、\_\_strong的实现原理
- 3.weakSelf、strongSelf的用途
- 4.@weakify、@strongify实现原理

#### 一. Retain Circle的由来

![](https://img.halfrost.com/Blog/ArticleImage/22_1.jpg)



循环引用的问题相信大家都很理解了，这里还是简单的提一下。

当A对象里面强引用了B对象，B对象又强引用了A对象，这样两者的retainCount值一直都无法为0，于是内存始终无法释放，导致内存泄露。所谓的内存泄露就是本应该释放的对象，在其生命周期结束之后依旧存在。


![](https://img.halfrost.com/Blog/ArticleImage/22_2.png)

这是2个对象之间的，相应的，这种循环还能存在于3，4……个对象之间，只要相互形成环，就会导致Retain Cicle的问题。



当然也存在自身引用自身的，当一个对象内部的一个obj，强引用的自身，也会导致循环引用的问题出现。常见的就是block里面引用的问题。

![](https://img.halfrost.com/Blog/ArticleImage/22_3.png)



#### 二.\_\_weak、\_\_strong的实现原理

在ARC环境下，id类型和对象类型和C语言其他类型不同，类型前必须加上所有权的修饰符。

所有权修饰符总共有4种：

1.\_\_strong修饰符
2.\_\_weak修饰符
3.\_\_unsafe\_unretained修饰符
4.\_\_autoreleasing修饰符

一般我们如果不写，默认的修饰符是\_\_strong。

要想弄清楚\_\_strong，\_\_weak的实现原理，我们就需要研究研究clang(LLVM编译器)和objc4 Objective-C runtime库了。

关于clang有一份[关于ARC详细的文档](http://clang.llvm.org/docs/AutomaticReferenceCounting.html)，有兴趣的可以仔细研究一下文档里面的说明和例子，很有帮助。

以下的讲解，也会来自于上述文档中的函数说明。

![](https://img.halfrost.com/Blog/ArticleImage/22_4.jpg)


##### 1.\_\_strong的实现原理

###### (1)对象持有自己

首先我们先来看看生成的对象持有自己的情况，利用alloc/new/copy/mutableCopy生成对象。

当我们声明了一个\_\_strong对象

```objectivec
{
    id __strong obj = [[NSObject alloc] init];
}
```

LLVM编译器会把上述代码转换成下面的样子

```objectivec

id __attribute__((objc_ownership(strong))) obj = ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"));
```
相应的会调用

```objectivec
id obj = objc_msgSend(NSObject, @selector(alloc));
objc_msgSend(obj,selector(init));
objc_release(obj);
```

上述这些方法都好理解。在ARC有效的时候就会自动插入release代码，在作用域结束的时候自动释放。


###### (2)对象不持有自己

生成对象的时候不用alloc/new/copy/mutableCopy等方法。

```objectivec
{
    id __strong obj = [NSMutableArray array];
}
```

LLVM编译器会把上述代码转换成下面的样子

```objectivec

id __attribute__((objc_ownership(strong))) array = ((NSMutableArray *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSMutableArray"), sel_registerName("array"));

```

查看LLVM文档，其实是下述的过程

相应的会调用

```objectivec
id obj = objc_msgSend(NSMutableArray, @selector(array));
objc_retainAutoreleasedReturnValue(obj);
objc_release(obj);
```
与之前对象会持有自己的情况不同，这里多了一个objc_retainAutoreleasedReturnValue函数。

这里有3个函数需要说明：
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

这3个函数其实都是在描述一件事情。 it makes a best effort to hand off ownership of a retain count on the object to a call to objc_retainAutoreleasedReturnValue for the same object in an enclosing call frame。

这属于LLVM编译器的一个优化。objc_retainAutoreleasedReturnValue函数是用于自己持有(retain)对象的函数，它持有的对象应为返回注册在autoreleasepool中对象的方法或者是函数的返回值。

在ARC中原本对象生成之后是要注册到autoreleasepool中，但是调用了objc_autoreleasedReturnValue 之后，紧接着调用了 objc_retainAutoreleasedReturnValue，objc_autoreleasedReturnValue函数会去检查该函数方法或者函数调用方的执行命令列表，如果里面有objc_retainAutoreleasedReturnValue()方法，那么该对象就直接返回给方法或者函数的调用方。达到了即使对象不注册到autoreleasepool中，也可以返回拿到相应的对象。


##### 2.\_\_weak的实现原理

声明一个\_\_weak对象

```objectivec
{
    id __weak obj = strongObj;
}
```

假设这里的strongObj是一个已经声明好了的对象。

LLVM转换成对应的代码

```objectivec

id __attribute__((objc_ownership(none))) obj1 = strongObj;

```
相应的会调用

```objectivec
id obj ;
objc_initWeak(&obj,strongObj);
objc_destoryWeak(&obj);

```

看看文档描述

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

objc_initWeak的实现其实是这样的
```objectivec

id objc_initWeak(id *object, id value) {   
    *object = nil; 
    return objc_storeWeak(object, value);
}
```
会把传入的object变成0或者nil，然后执行objc_storeWeak函数。


那么objc_destoryWeak函数是干什么的呢？

>[void objc_destroyWeak(id *object);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id61)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#void-objc-destroyweak-id-object)  
*Precondition:* object  is a valid pointer which either contains a null pointer or has been registered as a \_\_weak object.

>object  is unregistered as a weak object, if it ever was. The current value of object is left unspecified; otherwise, equivalent to the following code:

>void objc_destroyWeak(id *object) { 
objc_storeWeak(object, nil);
}

>Does not need to be atomic with respect to calls to objc_storeWeak on object


objc_destoryWeak函数的实现

```objectivec
void objc_destroyWeak(id *object) { 
    objc_storeWeak(object, nil);
}
```
也是会去调用objc_storeWeak函数。objc_initWeak和objc_destroyWeak函数都会去调用objc_storeWeak函数，唯一不同的是调用的入参不同，一个是value，一个是nil。


那么重点就都落在objc_storeWeak函数上了。
>[id objc_storeWeak(id *object, id value);
](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#id73)[](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#arc-runtime-objc-storeweak)  
*Precondition:* object is a valid pointer which either contains a null pointer or has been registered as a __weak object. value
 is null or a pointer to a valid object.

>If value is a null pointer or the object to which it points has begun deallocation, object  is assigned null and unregistered as a \_\_weak object. Otherwise, object is registered as a \_\_weak object or has its registration updated to point to value

>Returns the value of object after the call.

objc\_storeWeak函数的用途就很明显了。由于weak表也是用Hash table实现的，所以objc\_storeWeak函数就把第一个入参的变量地址注册到weak表中，然后根据第二个入参来决定是否移除。如果第二个参数为0，那么就把\_\_weak变量从weak表中删除记录，并从引用计数表中删除对应的键值记录。

所以如果\_\_weak引用的原对象如果被释放了，那么对应的\_\_weak对象就会被指为nil。原来就是通过objc_storeWeak函数这些函数来实现的。

以上就是ARC中\_\_strong和\_\_weak的简单的实现原理，更加详细的还请大家去看看这一章开头提到的那个LLVM文档，里面说明的很详细。



![](https://img.halfrost.com/Blog/ArticleImage/22_5.png)





#### 三.weakSelf、strongSelf的用途

在提weakSelf、strongSelf之前，我们先引入一个 Retain Cycle 的例子。

假设自定义的一个student类


例子1：
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
到这里，大家应该看出来了，这里肯定出现了循环引用了。student的study的Block里面强引用了student自身。根据[上篇文章](https://www.halfrost.com/ios_block/)的分析，可以知道，_NSConcreteMallocBlock捕获了外部的对象，会在内部持有它。retainCount值会加一。

我们用Instruments来观察一下。添加Leak观察器。

当程序运行起来之后，在**Leak Checks**观察器里面应该可以看到红色的❌，点击它就会看到内存leak了。有2个泄露的对象。Block和Student相互循环引用了。

![](https://img.halfrost.com/Blog/ArticleImage/22_6.png)


打开Cycles & Roots 观察一下循环的环。


![](https://img.halfrost.com/Blog/ArticleImage/22_7.png)


这里形成环的原因block里面持有student本身，student本身又持有block。

那再看一个例子2：

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

我把block新传入一个参数，传入的是student.name。这个时候会引起循环引用么？

答案肯定是不会。

![](https://img.halfrost.com/Blog/ArticleImage/22_8.png)


如上图，并不会出现内存泄露。原因是因为，student是作为形参传递进block的，block并不会捕获形参到block内部进行持有。所以肯定不会造成循环引用。

再改一下。看例子3：

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

这样会形成循环引用么？

![](https://img.halfrost.com/Blog/ArticleImage/22_9.png)



答案也是否定的。

ViewController虽然强引用着student，但是student里面的blcok强引用的是viewController的name属性，并没有形成环。如果把上述的self.name改成self，也依旧不会产生循环引用。因为他们都没有强引用这个block。


那遇到循环引用我们改如何处理呢？？类比平时我们经常写的delegate，可以知道，只要有一边是__weak就可以打破循环。

先说一种做法，利用__block解决循环的做法。例子4：


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

这样写会循环么？看上去应该不会。但是实际上却是会的。


![](https://img.halfrost.com/Blog/ArticleImage/22_10.png)


![](https://img.halfrost.com/Blog/ArticleImage/22_11.png)


由于没有执行study这个block，现在student持有该block，block持有\_\_block变量，\_\_block变量又持有student对象。3者形成了环，导致了循环引用了。
想打破环就需要破坏掉其中一个引用。__block不持有student即可。

只需要执行一下block即可。例子5：

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

这样就不会循环引用了。

![](https://img.halfrost.com/Blog/ArticleImage/22_12.png)

使用\_\_block解决循环引用虽然可以控制对象持有时间，在block中还能动态的控制是\_\_block变量的值，可以赋值nil，也可以赋值其他的值，但是有一个唯一的缺点就是需要执行一次block才行。否则还是会造成循环引用。


** 值得注意的是，在ARC下\_\_block会导致对象被retain，有可能导致循环引用。而在MRC下，则不会retain这个对象，也不会导致循环引用。** [这里可以详细看看来自kuailejim的实验](http://www.jianshu.com/p/e03292674e60)
>在MRC环境下，__block根本不会对指针所指向的对象执行copy操作，而只是把指针进行的复制。而这一点往往是很多新手&老手所不知道的！

>而在ARC环境下，对于声明为__block的外部对象，在block内部会进行retain，以至于在block环境内能安全的引用外部对象，所以要谨防循环引用的问题！


接下来可以正式开始讲讲weakSelf 和 strongSelf的用法了。

##### 1.weakSelf

说道weakSelf，需要先来区分几种写法。
\_\_weak \_\_typeof(self)weakSelf = self;  这是AFN里面的写法。。

\#define WEAKSELF typeof(self) __weak weakSelf = self; 这是我们平时的写法。。

先区分\_\_typeof() 和 typeof()
由于笔者一直很崇拜AFNetWorking的作者，这个库里面的代码都很整洁，里面各方面的代码都可以当做代码范本来阅读。遇到不懂疑惑的，都要深究，肯定会有收获。这里就是一处，平时我们的写法是不带\_\_的，AFN里面用这种写法有什么特殊的用途么？



在SOF上能找到相关的[答案](http://stackoverflow.com/questions/14877415/difference-between-typeof-typeof-and-typeof-objective-c)：

>\_\_typeof\_\_() and \_\_typeof() are compiler-specific extensions to the C language, because standard C does not include such an operator. Standard C requires compilers to prefix language extensions with a double\-underscore (which is also why you should never do so for your own functions, variables, etc.)
typeof() is exactly the same, but throws the underscores out the window with the understanding that every modern compiler supports it. (Actually, now that I think about it, Visual C++ might not. It does support decltype() though, which generally provides the same behaviour as typeof().)
All three mean the same thing, but none are standard C so a conforming compiler may choose to make any mean something different.

其实两者都是一样的东西，只不过是C里面不同的标准，兼容性不同罢了。

更加详细的[官方说明](http://gcc.gnu.org/onlinedocs/gcc/Alternate-Keywords.html#Alternate-Keywords)



那么抽象出来就是这2种写法。  
\#define WEAKSELF  \_\_weak typeof(self)weakSelf = self;  
\#define WEAKSELF typeof(self) \_\_weak weakSelf = self;

这样子看就清楚了，两种写法就是完全一样的。

我们可以用WEAKSELF来解决循环引用的问题。例子6：

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

这样就解决了循环引用的问题了。

解决循环应用的问题一定要分析清楚哪里出现了循环引用，只需要把其中一环加上weakSelf这类似的宏，就可以解决循环引用。如果分析不清楚，就只能无脑添加weakSelf、strongSelf，这样的做法不可取。

在上面的例子3中，就完全不存在循环引用，要是无脑加weakSelf、strongSelf是不对的。在例子6中，也只需要加一个weakSelf就可以了，也不需要加strongSelf。


曾经在segmentfault也看到过这样一个问题，问：[为什么iOS的Masonry中的self不会循环引用?](https://segmentfault.com/q/1010000004343510)

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
>如果我用blocksKit的bk_addEventHandler
方法, 其中使用strong self, 该viewController就无法dealloc, 我理解是因为,self retain self.view, retain testButton, retain self. 但是如果只用Mansonry的mas_makeConstraints
方法, 同样使用strong self, 该viewController却能正常dealloc, 请问这是为什么, 为什么Masonry没有导致循环引用？


看到这里，读者应该就应该能回答这个问题了。

```objectivec

- (NSArray *)mas_makeConstraints:(void(^)(MASConstraintMaker *))block {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    MASConstraintMaker *constraintMaker = [[MASConstraintMaker alloc] initWithView:self];
    block(constraintMaker);
    return [constraintMaker install];
}
```

~~在Masonry这个block中，block仅仅捕获了self的translatesAutoresizingMaskIntoConstraints变量，但是并没有持有self。~~

上述描述有误，感谢@酷酷的哀殿 耐心指点

更正如下：

关于 Masonry ，它内部根本没有捕获变量 self，进入block的是testButton，所以执行完毕后，block会被销毁，没有形成环。所以，没有引起循环依赖。



##### 2.strongSelf

上面介绍完了weakSelf，既然weakSelf能完美解决Retain Circle的问题了，那为何还需要strongSelf呢？

还是先从AFN经典说起，以下是AFN其中的一段代码：

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

如果block里面不加\_\_strong \_\_typeof(weakSelf)strongSelf = weakSelf会如何呢？

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

输出：

```vim
my name is = (null)
```

为什么输出是这样的呢？

重点就在dispatch\_after这个函数里面。在study()的block结束之后，student被自动释放了。又由于dispatch\_after里面捕获的\_\_weak的student，根据第二章讲过的\_\_weak的实现原理，在原对象释放之后，\_\_weak对象就会变成null，防止野指针。所以就输出了null了。

那么我们怎么才能在weakSelf之后，block里面还能继续使用weakSelf之后的对象呢？

究其根本原因就是weakSelf之后，无法控制什么时候会被释放，为了保证在block内不会被释放，需要添加\_\_strong。

在block里面使用的\_\_strong修饰的weakSelf是为了在函数生命周期中防止self提前释放。strongSelf是一个自动变量当block执行完毕就会释放自动变量strongSelf不会对self进行一直进行强引用。

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


输出
```vim
my name is = Hello World

```

至此，我们就明白了weakSelf、strongSelf的用途了。

weakSelf 是为了block不持有self，避免Retain Circle循环引用。在 Block 内如果需要访问 self 的方法、变量，建议使用 weakSelf。


strongSelf的目的是因为一旦进入block执行，假设不允许self在这个执行过程中释放，就需要加入strongSelf。block执行完后这个strongSelf 会自动释放，没有不会存在循环引用问题。如果在 Block 内需要多次 访问 self，则需要使用 strongSelf。


关于Retain Circle最后总结一下，有3种方式可以解决循环引用。

结合《Effective Objective-C 2.0》(编写高质量iOS与OS X代码的52个有效方法)这本书的例子，来总结一下。

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
    //开始网络请求
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        _downloadData = [[NSData alloc] initWithContentsOfURL:_url];
        dispatch_async(dispatch_get_main_queue(), ^{
             //网络请求完成
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

在这个例子中，存在3者之间形成环

1、completion handler的block因为要设置_fetchedData实例变量的值，所以它必须捕获self变量，也就是说handler块保留了EOCClass实例；

2、EOCClass实例通过strong实例变量保留了EOCNetworkFetcher，最后EOCNetworkFetcher实例对象也会保留了handler的block。

书上说的3种方法来打破循环。

方法一：手动释放EOCNetworkFetcher使用之后持有的_networkFetcher，这样可以打破循环引用

```objectivec
- (void)downloadData {
    NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
    _networkFetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
    [_networkFetcher startWithCompletionHandler:^(NSData *data) {
        _fetchedData = data;
        _networkFetcher = nil;//加上此行，打破循环引用
    }];
}
```


方法二：直接释放block。因为在使用完对象之后需要人为手动释放，如果忘记释放就会造成循环引用了。如果使用完completion handler之后直接释放block即可。打破循环引用

```objectivec

- (void)p_requestCompleted {
    if(_completionHandler) {
        _completionHandler(_downloadData);
    }
    self.completionHandler = nil;//加上此行，打破循环引用
}
```

方法三：使用weakSelf、strongSelf

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




#### 四.@weakify、@strongify实现原理

上面讲完了weakSelf、strongSelf之后，接下来再讲讲@weakify、@strongify，这两个关键字是RAC中避免Block循环引用而开发的2个宏，这2个宏的实现过程很牛，值得我们学习。

@weakify、@strongify的作用和weakSelf、strongSelf对应的一样。这里我们具体看看大神是怎么实现这2个宏的。

直接从源码看起来。

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

看到这种宏定义，咋一看什么都不知道。那就只能一层层的往下看。

##### 1. weakify
先从weakify(...)开始。

```objectivec

#if DEBUG
#define rac_keywordify autoreleasepool {}
#else
#define rac_keywordify try {} @catch (...) {}
#endif
```
这里在debug模式下使用@autoreleasepool是为了维持编译器的分析能力，而使用@try/@catch 是为了防止插入一些不必要的autoreleasepool。rac_keywordify 实际上就是autoreleasepool {}
的宏替换。因为有了autoreleasepool {}的宏替换，所以weakify要加上@，形成@autoreleasepool {}。


```objectivec

#define metamacro_foreach_cxt(MACRO, SEP, CONTEXT, ...) \
        metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(__VA_ARGS__))(MACRO, SEP, CONTEXT, __VA_ARGS__)

```

\_\_VA\_ARGS\_\_：总体来说就是将左边宏中 ... 的内容原样抄写在右边 \_\_VA\_ARGS\_\_ 所在的位置。它是一个可变参数的宏，是新的C99规范中新增的，目前似乎只有gcc支持（VC从VC2005开始支持）。

那么我们使用@weakify(self)传入进去。\_\_VA\_ARGS\_\_相当于self。此时我们可以把最新开始的weakify套下来。于是就变成了这样：

rac\_weakify\_,, \_\_weak, \_\_VA\_ARGS\_\_整体替换MACRO, SEP, CONTEXT, ...

这里需要注意的是，源码中就是给的两个","逗号是连着的，所以我们也要等效替换参数，相当于SEP是空值。

替换完成之后就是下面这个样子：

```objectivec
autoreleasepool {}
metamacro_concat(metamacro_foreach_cxt, metamacro_argcount(self))(rac_weakify_, , __weak, self)
```

现在我们需要弄懂的就是metamacro\_concat 和 metamacro\_argcount是干什么用的。

继续看看metamacro\_concat  的实现

```objectivec


#define metamacro_concat(A, B) \
        metamacro_concat_(A, B)


#define metamacro_concat_(A, B) A ## B

```

\#\# 是宏连接符。举个例子：

假设宏定义为#define XNAME(n) x##n，代码为：XNAME(4)，则在预编译时，宏发现XNAME(4)与XNAME(n)匹配，则令 n 为 4，然后将右边的n的内容也变为4，然后将整个XNAME(4)替换为 x##n，亦即 x4，故 最终结果为 XNAME(4) 变为 x4。所以A##B就是AB。


metamacro\_argcount 的实现

```objectivec
#define metamacro_argcount(...) \
        metamacro_at(20, __VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)


#define metamacro_at(N, ...) \
        metamacro_concat(metamacro_at, N)(__VA_ARGS__)

```
metamacro\_concat是上面讲过的连接符，那么metamacro\_at, N = metamacro\_atN，由于N = 20，于是metamacro\_atN = metamacro\_at20。


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

metamacro\_at20的作用就是截取前20个参数，剩下的参数传入metamacro\_head。


```objectivec

#define metamacro_head(...) \
        metamacro_head_(__VA_ARGS__, 0)


#define metamacro_head_(FIRST, ...) FIRST

```
metamacro\_head的作用返回第一个参数。返回到上一级metamacro\_at20，如果我们从最源头的@weakify(self)，传递进来，那么metamacro\_at20(self,20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)，截取前20个参数，最后一个留给metamacro\_head\_(1)，那么就应该返回1。


metamacro\_concat(metamacro\_foreach\_cxt, metamacro\_argcount(self)) = metamacro\_concat(metamacro\_foreach\_cxt, 1) 最终可以替换成metamacro\_foreach\_cxt1。

在源码中继续搜寻。

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


metamacro\_foreach\_cxt这个宏定义有点像递归，这里可以看到N 最大就是20，于是metamacro\_foreach\_cxt19就是最大，metamacro\_foreach\_cxt19会生成rac\_weakify\_(0,\_\_weak,\_18)，然后再把前18个数传入metamacro\_foreach\_cxt18，并生成rac\_weakify\_(0,\_\_weak,\_17)，依次类推，一直递推到metamacro\_foreach\_cxt0。

```objectivec

#define metamacro_foreach_cxt0(MACRO, SEP, CONTEXT)

```
metamacro\_foreach\_cxt0就是终止条件，不做任何操作了。


于是最初的@weakify就被替换成

```objectivec
autoreleasepool {}
metamacro_foreach_cxt1(rac_weakify_, , __weak, self)
```

```objectivec

#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)

```

代入参数

```objectivec
autoreleasepool {}
rac_weakify_（0,__weak,self）

```

最终需要解析的就是rac\_weakify\_

```objectivec


#define rac_weakify_(INDEX, CONTEXT, VAR) \
    CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

```

把（0,\_\_weak,self）的参数替换进来(INDEX, CONTEXT, VAR)。
INDEX = 0， CONTEXT = \_\_weak，VAR = self，

于是

```objectivec

CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);


等效替换为


__weak __typeof__(self) self_weak_ = self;
```

最终@weakify(self) = \_\_weak \_\_typeof\_\_(self) self\_weak\_ = self;

这里的self\_weak\_ 就完全等价于我们之前写的weakSelf。

##### 2. strongify

再继续分析strongify(...)

rac_keywordify还是和weakify一样，是autoreleasepool {}，只为了前面能加上@

```objectivec

_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
_Pragma("clang diagnostic pop")

```
strongify比weakify多了这些\_Pragma语句。

关键字\_Pragma是C99里面引入的。\_Pragma比#pragma（在设计上）更加合理，因而功能也有所增强。

上面的等效替换

```objectivec

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic pop

```

这里的clang语句的作用:忽略当一个局部变量或类型声明遮盖另一个变量的警告。


最初的

```objectivec
#define strongify(...) \
    rac_keywordify \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    metamacro_foreach(rac_strongify_,, __VA_ARGS__) \
    _Pragma("clang diagnostic pop")
```

strongify里面需要弄清楚的就是metamacro\_foreach 和 rac\_strongify\_。

```objectivec
#define metamacro_foreach(MACRO, SEP, ...) \
        metamacro_foreach_cxt(metamacro_foreach_iter, SEP, MACRO, __VA_ARGS__)

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

```

我们先替换一次，SEP = 空 ， MACRO = rac\_strongify\_ ， \_\_VA\_ARGS\_\_ , 于是替换成这样。


```objectivec

metamacro_foreach_cxt(metamacro_foreach_iter,,rac_strongify_,self)

```


根据之前分析，metamacro\_foreach\_cxt再次等效替换，metamacro\_foreach\_cxt##1(metamacro\_foreach\_iter,,rac\_strongify\_,self)

根据

```objectivec

#define metamacro_foreach_cxt1(MACRO, SEP, CONTEXT, _0) MACRO(0, CONTEXT, _0)
```
再次替换成metamacro\_foreach\_iter(0, rac\_strongify\_, self)


继续看看metamacro\_foreach\_iter的实现

```objectivec


#define metamacro_foreach_iter(INDEX, MACRO, ARG) MACRO(INDEX, ARG)

```

最终替换成rac\_strongify\_(0,self)

```objectivec

#define rac_strongify_(INDEX, VAR) \
    __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);
```

INDEX = 0, VAR = self,于是@strongify(self)就等价于

```objectivec

 __strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

等价于

__strong __typeof__(self) self = self_weak_;

```

注意@strongify(self)只能使用在block中，如果用在block外面，会报错，因为这里会提示你Redefinition of 'self'。

总结一下

@weakify(self) = @autoreleasepool{} \_\_weak \_\_typeof\_\_ (self) self\_weak\_ = self;

@strongify(self) = @autoreleasepool{} \_\_strong \_\_typeof\_\_(self) self = self\_weak\_;

经过分析以后，其实@weakify(self) 和 @strongify(self) 就是比我们日常写的weakSelf、strongSelf多了一个@autoreleasepool{}而已，至于为何要用这些复杂的宏定义来做，目前我还没有理解。如果有大神指导其中的原因，还请多多指点。




**更新**

针对文章中给的例子3，大家都提出了疑问，为何没有检测出循环引用？其实这个例子有点不好。因为这个ViewController的引用计数一出来就是6，因为它被其他很多对象引用着。当然它是强引用了student，因为student的retainCount值是2。ViewController释放的时候才会把student的值减一。针对这个例子3，我重新抽取出中间的模型，重新举一个例子。


既然ViewController特殊，那我们就新建一个类。

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



如图所示，还是出现了循环引用，student的block强引用了teacher，teacher又强引用了student，导致两者都无法释放。

