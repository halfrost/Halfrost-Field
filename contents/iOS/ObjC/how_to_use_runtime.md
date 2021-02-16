# 神经病院 Objective-C Runtime 出院第三天——如何正确使用 Runtime

![](https://img.halfrost.com/Blog/ArticleTitleImage/25_0_.jpg)



#### 前言

到了今天终于要"出院"了，要总结一下住院几天的收获，谈谈Runtime到底能为我们开发带来些什么好处。当然它也是把双刃剑，使用不当的话，也会成为开发路上的一个大坑。

####目录

- 1.Runtime的优点
    - (1)    实现多继承Multiple Inheritance
    - (2)    Method Swizzling
    - (3)    Aspect Oriented Programming
    - (4)    Isa Swizzling
    - (5)    Associated Object关联对象
    - (6)    动态的增加方法
    - (7)    NSCoding的自动归档和自动解档
    - (8)    字典和模型互相转换
- 2.Runtime的缺点

#### 一. 实现多继承Multiple Inheritance  

在上一篇文章里面讲到的forwardingTargetForSelector:方法就能知道，一个类可以做到继承多个类的效果，只需要在这一步将消息转发给正确的类对象就可以模拟多继承的效果。

在[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtForwarding.html#//apple_ref/doc/uid/TP40008048-CH105-SW11)上记录了这样一段例子。

![](https://img.halfrost.com/Blog/ArticleImage/25_1.png)


在OC程序中可以借用消息转发机制来实现多继承的功能。 在上图中，一个对象对一个消息做出回应，类似于另一个对象中的方法借过来或是“继承”过来一样。 在图中，warrior实例转发了一个negotiate消息到Diplomat实例中，执行Diplomat中的negotiate方法，结果看起来像是warrior实例执行了一个和Diplomat实例一样的negotiate方法，其实执行者还是Diplomat实例。

这使得不同继承体系分支下的两个类可以“继承”对方的方法，这样一个类可以响应自己继承分支里面的方法，同时也能响应其他不相干类发过来的消息。在上图中Warrior和Diplomat没有继承关系，但是Warrior将negotiate消息转发给了Diplomat后，就好似Diplomat是Warrior的超类一样。

消息转发提供了许多类似于多继承的特性，但是他们之间有一个很大的不同： 

多继承：合并了不同的行为特征在一个单独的对象中，会得到一个重量级多层面的对象。   

消息转发：将各个功能分散到不同的对象中，得到的一些轻量级的对象，这些对象通过消息通过消息转发联合起来。


这里值得说明的一点是，即使我们利用转发消息来实现了“假”继承，但是NSObject类还是会将两者区分开。像respondsToSelector:和 isKindOfClass:这类方法只会考虑继承体系，不会考虑转发链。比如上图中一个Warrior对象如果被问到是否能响应negotiate消息：

```objectivec

if ( [aWarrior respondsToSelector:@selector(negotiate)] )

```
结果是NO，虽然它能够响应negotiate消息而不报错，但是它是靠转发消息给Diplomat类来响应消息的。

如果非要制造假象，反应出这种“假”的继承关系，那么需要重新实现 respondsToSelector:和 isKindOfClass:来加入你的转发算法：


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

除了respondsToSelector:和 isKindOfClass:之外，instancesRespondToSelector:中也应该写一份转发算法。如果使用了协议，conformsToProtocol:也一样需要重写。类似地，如果一个对象转发它接受的任何远程消息，它得给出一个methodSignatureForSelector:来返回准确的方法描述，这个方法会最终响应被转发的消息。比如一个对象能给它的替代者对象转发消息，它需要像下面这样实现methodSignatureForSelector:


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

需要引起注意的一点，实现methodSignatureForSelector方法是一种先进的技术，只适用于没有其他解决方案的情况下。它不会作为继承的替代。如果您必须使用这种技术，请确保您完全理解类做的转发和您转发的类的行为。请勿滥用！

#### 二.Method Swizzling

![](https://img.halfrost.com/Blog/ArticleImage/25_2.png)




提到Objective-C 中的 Runtime，大多数人第一个想到的可能就是黑魔法Method Swizzling。毕竟这是Runtime里面很强大的一部分，它可以通过Runtime的API实现更改任意的方法，理论上可以在运行时通过类名/方法名hook到任何 OC 方法，替换任何类的实现以及新增任意类。

举的最多的例子应该就是埋点统计用户信息的例子。

假设我们需要在页面上不同的地方统计用户信息，常见做法有两种：  
1. 傻瓜式的在所有需要统计的页面都加上代码。这样做简单，但是重复的代码太多。
2. 把统计的代码写入基类中，比如说BaseViewController。这样虽然代码只需要写一次，但是UITableViewController，UICollectionViewcontroller都需要写一遍，这样重复的代码依旧不少。

基于这两点，我们这时候选用Method Swizzling来解决这个事情最优雅。

##### 1. Method Swizzling原理

Method Swizzing是发生在运行时的，主要用于在运行时将两个Method进行交换，我们可以将Method Swizzling代码写到任何地方，但是只有在这段Method Swilzzling代码执行完毕之后互换才起作用。而且Method Swizzling也是iOS中AOP(面相切面编程)的一种实现方式，我们可以利用苹果这一特性来实现AOP编程。

Method Swizzling本质上就是对IMP和SEL进行交换。


##### 2.Method Swizzling使用

一般我们使用都是新建一个分类，在分类中进行Method Swizzling方法的交换。交换的代码模板如下：

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

Method Swizzling可以在运行时通过修改类的方法列表中selector对应的函数或者设置交换方法实现，来动态修改方法。可以重写某个方法而不用继承，同时还可以调用原先的实现。所以通常应用于在category中添加一个方法。

##### 3.Method Swizzling注意点

![](https://img.halfrost.com/Blog/ArticleImage/25_3.png)



1.Swizzling应该总在+load中执行

Objective-C在运行时会自动调用类的两个方法+load和+initialize。+load会在类初始加载时调用， +initialize方法是以懒加载的方式被调用的，如果程序一直没有给某个类或它的子类发送消息，那么这个类的 +initialize方法是永远不会被调用的。所以Swizzling要是写在+initialize方法中，是有可能永远都不被执行。

和+initialize比较+load能保证在类的初始化过程中被加载。

关于+load和+initialize的比较可以参看这篇文章[《Objective-C +load vs +initialize》](http://blog.leichunfeng.com/blog/2015/05/02/objective-c-plus-load-vs-plus-initialize/)


2.Swizzling应该总是在dispatch\_once中执行

Swizzling会改变全局状态，所以在运行时采取一些预防措施，使用dispatch\_once就能够确保代码不管有多少线程都只被执行一次。这将成为Method Swizzling的最佳实践。


这里有一个很容易犯的错误，那就是继承中用了Swizzling。如果不写dispatch\_once就会导致Swizzling失效！

举个例子，比如同时对NSArray和NSMutableArray中的objectAtIndex:方法都进行了Swizzling，这样可能会导致NSArray中的Swizzling失效的。

可是为什么会这样呢？
原因是，我们没有用dispatch\_once控制Swizzling只执行一次。如果这段Swizzling被执行多次，经过多次的交换IMP和SEL之后，结果可能就是未交换之前的状态。

比如说父类A的B方法和子类C的D方法进行交换，交换一次后，父类A持有D方法的IMP，子类C持有B方法的IMP，但是再次交换一次，就又还原了。父类A还是持有B方法的IMP，子类C还是持有D方法的IMP，这样就相当于咩有交换。可以看出，如果不写dispatch\_once，偶数次交换以后，相当于没有交换，Swizzling失效！

3.Swizzling在+load中执行时，不要调用[super load]

原因同注意点二，如果是多继承，并且对同一个方法都进行了Swizzling，那么调用[super load]以后，父类的Swizzling就失效了。


4.上述模板中没有错误

有些人怀疑我上述给的模板可能有错误。在这里需要讲解一下。

在进行Swizzling的时候，我们需要用class\_addMethod先进行判断一下原有类中是否有要替换的方法的实现。

如果class\_addMethod返回NO，说明当前类中有要替换方法的实现，所以可以直接进行替换，调用method\_exchangeImplementations即可实现Swizzling。

如果class\_addMethod返回YES，说明当前类中没有要替换方法的实现，我们需要在父类中去寻找。这个时候就需要用到method\_getImplementation去获取class\_getInstanceMethod里面的方法实现。然后再进行class\_replaceMethod来实现Swizzling。

这是Swizzling需要判断的一点。

还有一点需要注意的是，在我们替换的方法- (void)xxx\_viewWillAppear:(BOOL)animated中，调用了[self xxx\_viewWillAppear:animated];这不是死循环了么？

其实这里并不会死循环。
由于我们进行了Swizzling，所以其实在原来的- (void)viewWillAppear:(BOOL)animated方法中，调用的是- (void)xxx\_viewWillAppear:(BOOL)animated方法的实现。所以不会造成死循环。相反的，如果这里把[self xxx\_viewWillAppear:animated];改成[self viewWillAppear:animated];就会造成死循环。因为外面调用[self viewWillAppear:animated];的时候，会交换方法走到[self xxx\_viewWillAppear:animated];这个方法实现中来，然后这里又去调用[self viewWillAppear:animated]，就会造成死循环了。

所以按照上述Swizzling的模板来写，就不会遇到这4点需要注意的问题啦。




##### 4.Method Swizzling使用场景

Method Swizzling使用场景其实有很多很多，在一些特殊的开发需求中适时的使用黑魔法，可以做法神来之笔的效果。这里就举3种常见的场景。

1.实现AOP

AOP的例子在上一篇文章中举了一个例子，在下一章中也打算详细分析一下其实现原理，这里就一笔带过。

2.实现埋点统计

如果app有埋点需求，并且要自己实现一套埋点逻辑，那么这里用到Swizzling是很合适的选择。优点在开头已经分析了，这里不再赘述。看到一篇分析的挺精彩的埋点的文章，推荐大家阅读。
[iOS动态性(二)可复用而且高度解耦的用户统计埋点实现](http://www.jianshu.com/p/0497afdad36d)

3.实现异常保护

日常开发我们经常会遇到NSArray数组越界的情况，苹果的API也没有对异常保护，所以需要我们开发者开发时候多多留意。关于Index有好多方法，objectAtIndex，removeObjectAtIndex，replaceObjectAtIndex，exchangeObjectAtIndex等等，这些设计到Index都需要判断是否越界。

常见做法是给NSArray，NSMutableArray增加分类，增加这些异常保护的方法，不过如果原有工程里面已经写了大量的AtIndex系列的方法，去替换成新的分类的方法，效率会比较低。这里可以考虑用Swizzling做。


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
        // 异常处理
        @try {
            return [self swizzling_objectAtIndex:index];
        }
        @catch (NSException *exception) {
            // 打印崩溃信息
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

注意，调用这个objc\_getClass方法的时候，要先知道类对应的真实的类名才行，NSArray其实在Runtime中对应着\_\_NSArrayI，NSMutableArray对应着\_\_NSArrayM，NSDictionary对应着\_\_NSDictionaryI，NSMutableDictionary对应着\_\_NSDictionaryM。





#### 三. Aspect Oriented Programming


![](https://img.halfrost.com/Blog/ArticleImage/25_4.png)


Wikipedia 里对 AOP 是这么介绍的:

>An aspect can alter the behavior of the base code by applying advice (additional behavior) at various join points (points in a program) specified in a quantification or query called a pointcut (that detects whether a given join point matches).


类似记录日志、身份验证、缓存等事务非常琐碎，与业务逻辑无关，很多地方都有，又很难抽象出一个模块，这种程序设计问题，业界给它们起了一个名字叫横向关注点(Cross-cutting concern)，[AOP](https://en.wikipedia.org/wiki/Aspect-oriented_programming)作用就是分离横向关注点(Cross-cutting concern)来提高模块复用性，它可以在既有的代码添加一些额外的行为(记录日志、身份验证、缓存)而无需修改代码。

接下来分析分析AOP的工作原理。

在上一篇中我们分析过了，在objc_msgSend函数查找IMP的过程中，如果在父类也没有找到相应的IMP，那么就会开始执行\_class\_resolveMethod方法，如果不是元类，就执行\_class\_resolveInstanceMethod，如果是元类，执行\_class\_resolveClassMethod。在这个方法中，允许开发者动态增加方法实现。这个阶段一般是给@dynamic属性变量提供动态方法的。


如果\_class\_resolveMethod无法处理，会开始选择备援接受者接受消息，这个时候就到了forwardingTargetForSelector方法。如果该方法返回非nil的对象，则使用该对象作为新的消息接收者。

```objectivec


- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(aSelector == @selector(Method:)){
        return otherObject;
    }
    return [super forwardingTargetForSelector:aSelector];
}

```

同样也可以替换类方法

```objectivec

+ (id)forwardingTargetForSelector:(SEL)aSelector {
    if(aSelector == @selector(xxx)) {
        return NSClassFromString(@"Class name");
    }
    return [super forwardingTargetForSelector:aSelector];
}

```

替换类方法返回值就是一个类对象。


forwardingTargetForSelector这种方法属于单纯的转发，无法对消息的参数和返回值进行处理。

最后到了完整转发阶段。

Runtime系统会向对象发送methodSignatureForSelector:消息，并取到返回的方法签名用于生成NSInvocation对象。为接下来的完整的消息转发生成一个 NSMethodSignature对象。NSMethodSignature 对象会被包装成 NSInvocation 对象，forwardInvocation: 方法里就可以对 NSInvocation 进行处理了。


```objectivec

// 为目标对象中被调用的方法返回一个NSMethodSignature实例
#warning 运行时系统要求在执行标准转发时实现这个方法
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    return [self.proxyTarget methodSignatureForSelector:sel];
}

```

对象需要创建一个NSInvocation对象，把消息调用的全部细节封装进去，包括selector, target, arguments 等参数，还能够对返回结果进行处理。

AOP的多数操作就是在forwardInvocation中完成的。一般会分为2个阶段，一个是Intercepter注册阶段，一个是Intercepter执行阶段。


##### 1. Intercepter注册

![](https://img.halfrost.com/Blog/ArticleImage/25_5.png)

首先会把类里面的某个要切片的方法的IMP加入到Aspect中，类方法里面如果有forwardingTargetForSelector:的IMP，也要加入到Aspect中。

![](https://img.halfrost.com/Blog/ArticleImage/25_6.png)


然后对类的切片方法和forwardingTargetForSelector:的IMP进行替换。两者的IMP相应的替换为objc\_msgForward()方法和hook过的forwardingTargetForSelector:。这样主要的Intercepter注册就完成了。


##### 2. Intercepter执行

![](https://img.halfrost.com/Blog/ArticleImage/25_7.png)


当执行func()方法的时候，会去查找它的IMP，现在它的IMP已经被我们替换为了objc\_msgForward()方法，于是开始查找备援转发对象。

查找备援接受者调用forwardingTargetForSelector:这个方法，由于这里是被我们hook过的，所以IMP指向的是hook过的forwardingTargetForSelector:方法。这里我们会返回Aspect的target，即选取Aspect作为备援接受者。

有了备援接受者之后，就会重新objc\_msgSend，从消息发送阶段重头开始。


objc\_msgSend找不到指定的IMP，再进行\_class\_resolveMethod，这里也没有找到，forwardingTargetForSelector:这里也不做处理，接着就会methodSignatureForSelector。在methodSignatureForSelector方法中创建一个NSInvocation对象，传递给最终的forwardInvocation方法。


Aspect里面的forwardInvocation方法会干所有切面的事情。这里转发逻辑就完全由我们自定义了。Intercepter注册的时候我们也加入了原来方法中的method()和forwardingTargetForSelector:方法的IMP，这里我们可以在forwardInvocation方法中去执行这些IMP。在执行这些IMP的前后都可以任意的插入任何IMP以达到切面的目的。

以上就是AOP的原理。


#### 四. Isa Swizzling

前面第二点谈到了黑魔法Method Swizzling，本质上就是对IMP和SEL进行交换。其实接下来要说的Isa Swizzling，和它类似，本质上也是交换，不过交换的是Isa。

在苹果的官方库里面有一个很有名的技术就用到了这个Isa Swizzling，那就是KVO——Key-Value Observing。

[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOImplementation.html)上对于KVO的定义是这样的:

>Automatic key-value observing is implemented using a technique called *isa-swizzling*.
The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
You should never rely on the isa pointer to determine class membership. Instead, you should use the [class](https://developer.apple.com/reference/objectivec/1418956-nsobject/1571949-class) method to determine the class of an object instance.


官方给的就这么多，具体实现也没有说的很清楚。那只能我们自己来实验一下。

KVO是为了监听一个对象的某个属性值是否发生变化。在属性值发生变化的时候，肯定会调用其setter方法。所以KVO的本质就是监听对象有没有调用被监听属性对应的setter方法。具体实现应该是重写其setter方法即可。

官方是如何优雅的实现重写监听类的setter方法的呢？实验代码如下：


```objectivec

    Student *stu = [[Student alloc]init];
    
    [stu addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];

```

我们可以打印观察isa指针的指向

```vim

Printing description of stu->isa:
Student
Printing description of stu->isa:
NSKVONotifying_Student

```

通过打印，我们可以很明显的看到，被观察的对象的isa变了，变成了NSKVONotifying_Student这个类了。


在@interface NSObject(NSKeyValueObserverRegistration) 这个分类里面，苹果定义了KVO的方法。

```objectivec

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context NS_AVAILABLE(10_7, 5_0);

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

```

KVO在调用addObserver方法之后，苹果的做法是在执行完addObserver: forKeyPath: options: context: 方法之后，把isa指向到另外一个类去。

在这个新类里面重写被观察的对象四个方法。class，setter，dealloc，_isKVOA。

##### 1. 重写class方法
重写class方法是为了我们调用它的时候返回跟重写继承类之前同样的内容。

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

打印结果

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

这里也可以看出，这是object\_getClass方法和class方法的区别。

这里要特别说明一下，为何打印object\_getClass方法和class方法打印出来结果不同。



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

从实现上看，两个方法的实现都一样的，按道理来说，打印结果应该相同，可是为何在加了 KVO 以后会出现打印结果不同呢？

**根本原因：对于KVO，底层交换了 NSKVONotifying\_Student 的 class 方法，让其返回 Student。**

打印这句话 object\_getClass(stu) 的时候，isa 当然是 NSKVONotifying\_Student。

```objectivec

+ (BOOL)respondsToSelector:(SEL)sel {
    if (!sel) return NO;
    return class_respondsToSelector_inst(object_getClass(self), sel, self);
}


```

当我们执行 NSLog 的时候，会执行上面这个方法，这个方法的 sel 是`encodeWithOSLogCoder:options:maxLength:`，这个时候，self 是 NSKVONotifying\_Student，上面那个respondsToSelector 方法里面 return 的`object_getClass(self)`结果还是NSKVONotifying\_Student。

打印 [stu class] 的时候，isa 当然还是NSKVONotifying\_Student。当执行到 NSLog 的时候，`+ (BOOL)respondsToSelector:(SEL)sel`，又会执行到这个方法，这个时候的 self 变成了 Student，这个时候 respondsToSelector 方法里面的
 object\_getClass(self) 输出当然就是 Student 了。


##### 2. 重写setter方法

在新的类中会重写对应的set方法，是为了在set方法中增加另外两个方法的调用：

```objectivec

- (void)willChangeValueForKey:(NSString *)key
- (void)didChangeValueForKey:(NSString *)key

```

在didChangeValueForKey:方法再调用

```objectivec

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context

```


这里有几种情况需要说明一下：

1)如果使用了KVC
如果有访问器方法，则运行时会在setter方法中调用will/didChangeValueForKey:方法；

如果没用访问器方法，运行时会在setValue:forKey方法中调用will/didChangeValueForKey:方法。

所以这种情况下，KVO是奏效的。


2)有访问器方法
运行时会重写访问器方法调用will/didChangeValueForKey:方法。
因此，直接调用访问器方法改变属性值时，KVO也能监听到。


3)直接调用will/didChangeValueForKey:方法。

综上所述，只要setter中重写will/didChangeValueForKey:方法就可以使用KVO了。



##### 3. 重写dealloc方法

销毁新生成的NSKVONotifying_类。

##### 4. 重写_isKVOA方法

这个私有方法估计可能是用来标示该类是一个 KVO 机制声称的类。


Foundation 到底为我们提供了哪些用于 KVO 的辅助函数。打开 terminal，使用 nm -a 命令查看 Foundation 中的信息：

```vim

nm -a /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation

```

里面包含了以下这些KVO中可能用到的函数：

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

Foundation 提供了大部分基础数据类型的辅助函数（Objective C中的 Boolean 只是 unsigned char 的 typedef，所以包括了，但没有 C++中的 bool），此外还包括一些常见的结构体如 Point, Range, Rect, Size，这表明这些结构体也可以用于自动键值观察，但要注意除此之外的结构体就不能用于自动键值观察了。对于所有 Objective C 对象对应的是 __NSSetObjectValueAndNotify 方法。


KVO即使是苹果官方的实现，也是有缺陷的，这里有一篇文章详细了分析了[KVO中的缺陷](http://www.mikeash.com/pyblog/key-value-observing-done-right.html)，主要问题在KVO的回调机制，不能传一个selector或者block作为回调，而必须重写-addObserver:forKeyPath:options:context:方法所引发的一系列问题。而且只监听一两个属性值还好，如果监听的属性多了, 或者监听了多个对象的属性, 那有点麻烦，需要在方法里面写很多的if-else的判断。



最后，官方文档上对于KVO的实现的最后，给出了需要我们注意的一点是，**永远不要用用isa来判断一个类的继承关系，而是应该用class方法来判断类的实例。**


#### 五. Associated Object 关联对象

![](https://img.halfrost.com/Blog/ArticleImage/25_8.png)



Associated Objects是Objective-C 2.0中Runtime的特性之一。众所周知，在 Category 中，我们无法添加@property，因为添加了@property之后并不会自动帮我们生成实例变量以及存取方法。那么，我们现在就可以通过关联对象来实现在 Category 中添加属性的功能了。

##### 1. 用法

借用这篇经典文章[Associated Objects](http://nshipster.com/associated-objects/)里面的例子来说明一下用法。


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

这里涉及到了3个函数：

```objectivec

OBJC_EXPORT void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

OBJC_EXPORT id objc_getAssociatedObject(id object, const void *key)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

OBJC_EXPORT void objc_removeAssociatedObjects(id object)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_1);

```

来说明一下这些参数的意义：

1.id object 设置关联对象的实例对象

2.const void *key 区分不同的关联对象的 key。这里会有3种写法。



使用 &AssociatedObjectKey 作为key值
```objectivec

static char AssociatedObjectKey = "AssociatedKey";

```

使用AssociatedKey 作为key值
```objectivec

static const void *AssociatedKey = "AssociatedKey";

```

使用@selector

```objectivec

@selector(associatedKey)

```
3种方法都可以，不过推荐使用更加简洁的第三种方式。


3.id value 关联的对象

4.objc\_AssociationPolicy policy 关联对象的存储策略，它是一个枚举，与property的attribute 相对应。

![](https://img.halfrost.com/Blog/ArticleImage/25_13.png)

这里需要注意的是标记成OBJC\_ASSOCIATION\_ASSIGN的关联对象和
@property (weak) 是不一样的，上面表格中等价定义写的是 @property (unsafe_unretained)，对象被销毁时，属性值仍然还在。如果之后再次使用该对象就会导致程序闪退。所以我们在使用OBJC\_ASSOCIATION\_ASSIGN时，要格外注意。

>According to the Deallocation Timeline described in [WWDC 2011, Session 322](https://developer.apple.com/videos/wwdc/2011/#322-video)(~36:00), associated objects are erased surprisingly late in the object lifecycle, inobject_dispose(), which is invoked by NSObject -dealloc.


关于关联对象还有一点需要说明的是objc\_removeAssociatedObjects。这个方法是移除源对象中所有的关联对象，并不是其中之一。所以其方法参数中也没有传入指定的key。要删除指定的关联对象，使用 objc\_setAssociatedObject 方法将对应的 key 设置成 nil 即可。

```objectivec

objc_setAssociatedObject(self, associatedKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);

```

关联对象3种使用场景

1.为现有的类添加私有变量
2.为现有的类添加公有属性
3.为KVO创建一个关联的观察者。


##### 2.源码分析

###### (一) objc\_setAssociatedObject方法

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

这个函数里面主要分为2部分，一部分是if里面对应的new\_value不为nil的时候，另一部分是else里面对应的new\_value为nil的情况。

当new\_value不为nil的时候，查找时候，流程如下：


![](https://img.halfrost.com/Blog/ArticleImage/25_9.png)


首先在AssociationsManager的结构如下

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

在AssociationsManager中有一个spinlock类型的[自旋锁](https://en.wikipedia.org/wiki/Spinlock)lock。保证每次只有一个线程对AssociationsManager进行操作，保证线程安全。AssociationsHashMap对应的是一张哈希表。


AssociationsHashMap哈希表里面key是disguised\_ptr\_t。

```objectivec

disguised_ptr_t disguised_object = DISGUISE(object);

```
通过调用DISGUISE( )方法获取object地址的指针。拿到disguised_object后，通过这个key值，在AssociationsHashMap哈希表里面找到对应的value值。而这个value值ObjcAssociationMap表的首地址。

在ObjcAssociationMap表中，key值是set方法里面传过来的形参const void *key，value值是ObjcAssociation对象。

ObjcAssociation对象中存储了set方法最后两个参数，policy和value。

所以objc_setAssociatedObject方法中传的4个形参在上图中已经标出。

现在弄清楚结构之后再来看源码，就很容易了。objc_setAssociatedObject方法的目的就是在这2张哈希表中存储对应的键值对。

先初始化一个 AssociationsManager，获取唯一的保存关联对象的哈希表 AssociationsHashMap，然后在AssociationsHashMap里面去查找object地址的指针。

如果找到，就找到了第二张表ObjectAssociationMap。在这张表里继续查找object的key。

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

如果在第二张表ObjectAssociationMap找到对应的ObjcAssociation对象，那就更新它的值。如果没有找到，就新建一个ObjcAssociation对象，放入第二张表ObjectAssociationMap中。

再回到第一张表AssociationsHashMap中，如果没有找到对应的键值

```objectivec

ObjectAssociationMap *refs = new ObjectAssociationMap;
associations[disguised_object] = refs;
(*refs)[key] = ObjcAssociation(policy, new_value);
object->setHasAssociatedObjects();

```

此时就不存在第二张表ObjectAssociationMap了，这时就需要新建第二张ObjectAssociationMap表，来维护对象的所有新增属性。新建完第二张ObjectAssociationMap表之后，还需要再实例化 ObjcAssociation对象添加到 Map 中，调用setHasAssociatedObjects方法，表明当前对象含有关联对象。这里的setHasAssociatedObjects方法，改变的是isa\_t结构体中的第二个标志位has_assoc的值。(关于isa\_t结构体的结构，详情请看第一天的解析)



```objectivec

// release the old value (outside of the lock).
 if (old_association.hasValue()) ReleaseValue()(old_association);

```
最后如果老的association对象有值，此时还会释放它。

以上是new\_value不为nil的情况。其实只要记住上面那2张表的结构，这个objc_setAssociatedObject的过程就是更新 / 新建 表中键值对的过程。


再来看看new\_value为nil的情况

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

当new\_value为nil的时候，就是我们要移除关联对象的时候。这个时候就是在两张表中找到对应的键值，并调用erase( )方法，即可删除对应的关联对象。


###### (二) objc\_getAssociatedObject方法
  
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

objc\_getAssociatedObject方法 很简单。就是通过遍历AssociationsHashMap哈希表 和 ObjcAssociationMap表的所有键值找到对应的ObjcAssociation对象，找到了就返回ObjcAssociation对象，没有找到就返回nil。


###### (三) objc\_removeAssociatedObjects方法
   
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

在移除关联对象object的时候，会先去判断object的isa\_t中的第二位has\_assoc的值，当object 存在并且object->hasAssociatedObjects( )值为1的时候，才会去调用\_object\_remove\_assocations方法。

\_object\_remove\_assocations方法的目的是删除第二张ObjcAssociationMap表，即删除所有的关联对象。删除第二张表，就需要在第一张AssociationsHashMap表中遍历查找。这里会把第二张ObjcAssociationMap表中所有的ObjcAssociation对象都存到一个数组elements里面，然后调用associations.erase( )删除第二张表。最后再遍历elements数组，把ObjcAssociation对象依次释放。


以上就是Associated Object关联对象3个函数的源码分析。


#### 六.动态的增加方法

在消息发送阶段，如果在父类中也没有找到相应的IMP，就会执行resolveInstanceMethod方法。在这个方法里面，我们可以动态的给类对象或者实例对象动态的增加方法。


```objectivec

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    
    NSString *selectorString = NSStringFromSelector(sel);
    if ([selectorString isEqualToString:@"method1"]) {
        class_addMethod(self.class, @selector(method1), (IMP)functionForMethod1, "@:");
    }
    
    return [super resolveInstanceMethod:sel];
}

```

关于方法操作方面的函数还有以下这些



```objectivec

// 调用指定方法的实现
id method_invoke ( id receiver, Method m, ... );
// 调用返回一个数据结构的方法的实现
void method_invoke_stret ( id receiver, Method m, ... );
// 获取方法名
SEL method_getName ( Method m );
// 返回方法的实现
IMP method_getImplementation ( Method m );
// 获取描述方法参数和返回值类型的字符串
const char * method_getTypeEncoding ( Method m );
// 获取方法的返回值类型的字符串
char * method_copyReturnType ( Method m );
// 获取方法的指定位置参数的类型字符串
char * method_copyArgumentType ( Method m, unsigned int index );
// 通过引用返回方法的返回值类型字符串
void method_getReturnType ( Method m, char *dst, size_t dst_len );
// 返回方法的参数的个数
unsigned int method_getNumberOfArguments ( Method m );
// 通过引用返回方法指定位置参数的类型字符串
void method_getArgumentType ( Method m, unsigned int index, char *dst, size_t dst_len );
// 返回指定方法的方法描述结构体
struct objc_method_description * method_getDescription ( Method m );
// 设置方法的实现
IMP method_setImplementation ( Method m, IMP imp );
// 交换两个方法的实现
void method_exchangeImplementations ( Method m1, Method m2 );

```

这些方法其实平时不需要死记硬背，使用的时候只要先打出method开头，后面就会有补全信息，找到相应的方法，传入对应的方法即可。

#### 七.NSCoding的自动归档和自动解档

![](https://img.halfrost.com/Blog/ArticleImage/25_10.png)




现在虽然手写归档和解档的时候不多了，但是自动操作还是用Runtime来实现的。


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

手动的有一个缺陷，如果属性多起来，要写好多行相似的代码，虽然功能是可以完美实现，但是看上去不是很优雅。

用runtime实现的思路就比较简单，我们循环依次找到每个成员变量的名称，然后利用KVC读取和赋值就可以完成encodeWithCoder和initWithCoder了。

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

class\_copyIvarList方法用来获取当前 Model 的所有成员变量，ivar\_getName方法用来获取每个成员变量的名称。



#### 八.字典和模型互相转换

     

##### 1.字典转模型

1.调用 class\_getProperty 方法获取当前 Model 的所有属性。
2.调用 property\_copyAttributeList 获取属性列表。
3.根据属性名称生成 setter 方法。
4.使用 objc\_msgSend 调用 setter 方法为 Model 的属性赋值（或者 KVC）


```objectivec

+(id)objectWithKeyValues:(NSDictionary *)aDictionary{
    id objc = [[self alloc] init];
    for (NSString *key in aDictionary.allKeys) {
        id value = aDictionary[key];
        
        /*判断当前属性是不是Model*/
        objc_property_t property = class_getProperty(self, key.UTF8String);
        unsigned int outCount = 0;
        objc_property_attribute_t *attributeList = property_copyAttributeList(property, &outCount);
        objc_property_attribute_t attribute = attributeList[0];
        NSString *typeString = [NSString stringWithUTF8String:attribute.value];

        if ([typeString isEqualToString:@"@\"Student\""]) {
            value = [self objectWithKeyValues:value];
        }
        
        //生成setter方法，并用objc_msgSend调用
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

这段代码里面有一处判断typeString的，这里判断是防止model嵌套，比如说Student里面还有一层Student，那么这里就需要再次转换一次，当然这里有几层就需要转换几次。

几个出名的开源库JSONModel、MJExtension等都是通过这种方式实现的(利用runtime的class\_copyIvarList获取属性数组，遍历模型对象的所有成员属性，根据属性名找到字典中key值进行赋值，当然这种方法只能解决NSString、NSNumber等，如果含有NSArray或NSDictionary，还要进行第二步转换，如果是字典数组，需要遍历数组中的字典，利用objectWithDict方法将字典转化为模型，在将模型放到数组中，最后把这个模型数组赋值给之前的字典数组)

##### 2.模型转字典

这里是上一部分字典转模型的逆步骤：

1.调用 class\_copyPropertyList 方法获取当前 Model 的所有属性。
2.调用 property\_getName 获取属性名称。
3.根据属性名称生成 getter 方法。
4.使用 objc\_msgSend 调用 getter 方法获取属性值（或者 KVC）

```objectivec

//模型转字典
-(NSDictionary *)keyValuesWithObject{
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &outCount);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        //生成getter方法，并用objc_msgSend调用
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        if ([self respondsToSelector:getter]) {
            id value = ((id (*) (id,SEL)) objc_msgSend) (self,getter);
            
            /*判断当前属性是不是Model*/
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

中间注释那里的判断也是防止model嵌套，如果model里面还有一层model，那么model转字典的时候还需要再次转换，同样，有几层就需要转换几次。

不过上述的做法是假设字典里面不再包含二级字典，如果还包含数组，数组里面再包含字典，那还需要多级转换。这里有一个关于字典里面包含数组的[demo](https://github.com/XHTeng/XHRuntimeDemo).

#### 九.Runtime缺点

![](https://img.halfrost.com/Blog/ArticleImage/25_11.png)



看了上面八大点之后，是不是感觉Runtime很神奇，可以迅速解决很多问题，然而，Runtime就像一把瑞士小刀，如果使用得当，它会有效地解决问题。但使用不当，将带来很多麻烦。在stackoverflow上有人已经提出这样一个问题：[What are the Dangers of Method Swizzling in Objective C?](http://stackoverflow.com/questions/5339276/what-are-the-dangers-of-method-swizzling-in-objective-c)，它的危险性主要体现以下几个方面：

- Method swizzling is not atomic

Method swizzling不是原子性操作。如果在+load方法里面写，是没有问题的，但是如果写在+initialize方法中就会出现一些奇怪的问题。

- Changes behavior of un-owned code

如果你在一个类中重写一个方法，并且不调用super方法，你可能会导致一些问题出现。在大多数情况下，super方法是期望被调用的（除非有特殊说明）。如果你使用同样的思想来进行Swizzling，可能就会引起很多问题。如果你不调用原始的方法实现，那么你Swizzling改变的太多了，而导致整个程序变得不安全。


- Possible naming conflicts

命名冲突是程序开发中经常遇到的一个问题。我们经常在类别中的前缀类名称和方法名称。不幸的是，命名冲突是在我们程序中的像一种瘟疫。一般我们会这样写Method Swizzling

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

这样写看上去是没有问题的。但是如果在整个大型程序中还有另外一处定义了my_setFrame:方法呢？那又会造成命名冲突的问题。我们应该把上面的Swizzling改成以下这种样子：

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

虽然上面的代码看上去不是OC(因为使用了函数指针)，但是这种做法确实有效的防止了命名冲突的问题。原则上来说，其实上述做法更加符合标准化的Swizzling。这种做法可能和人们使用方法不同，但是这种做法更好。Swizzling Method 标准定义应该是如下的样子：


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

这一点是这些问题中最大的一个。标准的Method Swizzling是不会改变方法参数的。使用Swizzling中，会改变传递给原来的一个函数实现的参数，例如：

```objectivec 

[self my_setFrame:frame];

```

会变转换成

```objectivec

objc_msgSend(self, @selector(my_setFrame:), frame);

```

objc_msgSend会去查找my_setFrame对应的IMP。一旦IMP找到，会把相同的参数传递进去。这里会找到最原始的setFrame:方法，调用执行它。但是这里的_cmd参数并不是setFrame:，现在是my_setFrame:。原始的方法就被一个它不期待的接收参数调用了。这样并不好。

这里有一个简单的解决办法，上一条里面所说的，用函数指针去实现。参数就不会变了。


- The order of swizzles matters

调用顺序对于Swizzling来说，很重要。假设setFrame:方法仅仅被定义在NSView类里面。

```objectivec

[NSButton swizzle:@selector(setFrame:) with:@selector(my_buttonSetFrame:)];
[NSControl swizzle:@selector(setFrame:) with:@selector(my_controlSetFrame:)];
[NSView swizzle:@selector(setFrame:) with:@selector(my_viewSetFrame:)];

```

当NSButton被swizzled之后会发生什么呢？大多数的swizzling应该保证不会替换setFrame:方法。因为一旦改了这个方法，会影响下面所有的View。所以它会去拉取实例方法。NSButton会使用已经存在的方法去重新定义setFrame:方法。以至于改变了IMP实现不会影响所有的View。相同的事情也会发生在对NSControl进行swizzling的时候，同样，IMP也是定义在NSView类里面，把NSControl 和 NSButton这上下两行swizzle顺序替换，结果也是相同的。

当调用NSButton的setFrame:方法，会去调用swizzled method，然后会跳入NSView类里面定义的setFrame:方法。NSControl 和 NSView对应的swizzled method不会被调用。

NSButton 和  NSControl各自调用各自的 swizzling方法，相互不会影响。

但是我们改变一下调用顺序，把NSView放在第一位调用。

```objectivec

[NSView swizzle:@selector(setFrame:) with:@selector(my_viewSetFrame:)];
[NSControl swizzle:@selector(setFrame:) with:@selector(my_controlSetFrame:)];
[NSButton swizzle:@selector(setFrame:) with:@selector(my_buttonSetFrame:)];

```
一旦这里的NSView先进行了swizzling了以后，情况就和上面大不相同了。NSControl的swizzling会去拉取NSView替换后的方法。相应的，NSControl在NSButton前面，NSButton也会去拉取到NSControl替换后的方法。这样就十分混乱了。但是顺序就是这样排列的。我们开发中如何能保证不出现这种混乱呢？

再者，在load方法中加载swizzle。如果仅仅是在已经加载完成的class中做了swizzle，那么这样做是安全的。load方法能保证父类会在其任何子类加载方法之前，加载相应的方法。这就保证了我们调用顺序的正确性。


- Difficult to understand (looks recursive)

看着传统定义的swizzled method，我认为很难去预测会发生什么。但是对比上面标准的swizzling，还是很容易明白。这一点已经被解决了。


- Difficult to debug

在调试中，会出现奇怪的堆栈调用信息，尤其是swizzled的命名很混乱，一切方法调用都是混乱的。对比标准的swizzled方式，你会在堆栈中看到清晰的命名方法。swizzling还有一个比较难调试的一点， 在于你很难记住当前确切的哪个方法已经被swizzling了。

在代码里面写好文档注释，即使你认为这段代码只有你一个人会看。遵循这个方式去实践，你的代码都会没问题。它的调试也没有多线程的调试困难。



#### 最后

经过在“神经病院”3天的修炼之后，对OC 的Runtime理解更深了。

关于黑魔法Method swizzling，我个人觉得如果使用得当，还是很安全的。一个简单而安全的措施是你仅仅只在load方法中去swizzle。和编程中很多事情一样，不了解它的时候会很危险可怕，但是一旦明白了它的原理之后，使用它又会变得非常正确高效。

对于多人开发，尤其是改动过Runtime的地方，文档记录一定要完整。如果某人不知道某个方法被Swizzling了，出现问题调试起来，十分蛋疼。

如果是SDK开发，某些Swizzling会改变全局的一些方法的时候，一定要在文档里面标注清楚，否则使用SDK的人不知道，出现各种奇怪的问题，又要被坑好久。

在合理使用 + 文档完整齐全 的情况下，解决特定问题，使用Runtime还是非常简洁安全的。

日常可能用的比较多的Runtime函数可能就是下面这些

```objectivec

//获取cls类对象所有成员ivar结构体
Ivar *class_copyIvarList(Class cls, unsigned int *outCount)
//获取cls类对象name对应的实例方法结构体
Method class_getInstanceMethod(Class cls, SEL name)
//获取cls类对象name对应类方法结构体
Method class_getClassMethod(Class cls, SEL name)
//获取cls类对象name对应方法imp实现
IMP class_getMethodImplementation(Class cls, SEL name)
//测试cls对应的实例是否响应sel对应的方法
BOOL class_respondsToSelector(Class cls, SEL sel)
//获取cls对应方法列表
Method *class_copyMethodList(Class cls, unsigned int *outCount)
//测试cls是否遵守protocol协议
BOOL class_conformsToProtocol(Class cls, Protocol *protocol)
//为cls类对象添加新方法
BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)
//替换cls类对象中name对应方法的实现
IMP class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
//为cls添加新成员
BOOL class_addIvar(Class cls, const char *name, size_t size, uint8_t alignment, const char *types)
//为cls添加新属性
BOOL class_addProperty(Class cls, const char *name, const objc_property_attribute_t *attributes, unsigned int attributeCount)
//获取m对应的选择器
SEL method_getName(Method m)
//获取m对应的方法实现的imp指针
IMP method_getImplementation(Method m)
//获取m方法的对应编码
const char *method_getTypeEncoding(Method m)
//获取m方法参数的个数
unsigned int method_getNumberOfArguments(Method m)
//copy方法返回值类型
char *method_copyReturnType(Method m)
//获取m方法index索引参数的类型
char *method_copyArgumentType(Method m, unsigned int index)
//获取m方法返回值类型
void method_getReturnType(Method m, char *dst, size_t dst_len)
//获取方法的参数类型
void method_getArgumentType(Method m, unsigned int index, char *dst, size_t dst_len)
//设置m方法的具体实现指针
IMP method_setImplementation(Method m, IMP imp)
//交换m1，m2方法对应具体实现的函数指针
void method_exchangeImplementations(Method m1, Method m2)
//获取v的名称
const char *ivar_getName(Ivar v)
//获取v的类型编码
const char *ivar_getTypeEncoding(Ivar v)
//设置object对象关联的对象
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
//获取object关联的对象
id objc_getAssociatedObject(id object, const void *key)
//移除object关联的对象
void objc_removeAssociatedObjects(id object)

```

这些API看上去不好记，其实使用的时候不难，关于方法操作的，一般都是method开头，关于类的，一般都是class开头的，其他的基本都是objc开头的，剩下的就看代码补全的提示，看方法名基本就能找到想要的方法了。当然很熟悉的话，可以直接打出指定方法，也不会依赖代码补全。

还有一些关于协议相关的API以及其他一些不常用，但是也可能用到的，就需要查看[Objective-C Runtime官方API文档](https://developer.apple.com/reference/objectivec/1657527-objective_c_runtime?language=objc)，这个官方文档里面详细说明，平时不懂的多看看文档。

最后请大家多多指教。


Ps.这篇干货有点多，简书提示文章字数快到上限了，还好都写完了。顺利出院了！

![](https://img.halfrost.com/Blog/ArticleImage/25_12.png)

