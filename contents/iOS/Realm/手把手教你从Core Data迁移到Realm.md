<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-86f3f1bc02294ac7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## 前言
看了这篇文章的标题，也许有些人还不知道Realm是什么，那么我先简单介绍一下这个新生的数据库。号称是用来替代SQLite 和 Core Data的。Realm有以下优点：

1. 使用方便
Realm并不是基于SQLite的对象关系映射数据库。它是使用自己的持久化引擎，为简单和速度而生。[用户](https://realm.io/users)们说，他们在数分钟之内就上手了Realm，构建一个app只需要数小时，每个app开发时间至少节约数周的时间。

2. 快
Realm比其他的对象关系映射型数据库(Object Relational Mapping)，甚至比原生的SQLite更加快，这都得益于它零拷贝的设计。看看[iOS](https://realm.io/news/introducing-realm/#fast)用户和[Android](https://realm.io/news/realm-for-android/#realm-for-android)用户都是怎么评价它的快的[Twitter](https://twitter.com/realm/favorites)

3. 跨平台
Realm 支持 iOS 和 OS X ([Objective‑C](https://static.realm.io/downloads/objc/realm-objc-1.0.0.zip) & [Swift](https://static.realm.io/downloads/swift/realm-swift-1.0.0.zip)) 和[Android](https://static.realm.io/downloads/java/realm-java-1.0.0.zip)。你可以通过使用相同的model，共享Realm文件到各个平台，Java，Swift，Objective-C。并且在全平台可以使用相同的业务逻辑
 
4. 优秀的特性
Realm支持先进的特性，如[加密](https://realm.io/docs/java/latest/#encryption)，[图形查询](https://realm.io/docs/objc/latest/#queries)，[轻松的迁移](https://realm.io/docs/swift/latest/#migrations)。Realm的API是一个非常适合打造高响应的应用程​​序，并且Realm为我们提供方便的组件，以轻松构建复杂的用户界面

5. 值得信任
Realm已经获得了银行，医疗保健提供商，复杂的企业app，星巴克这些产品的青睐。

6. 社区驱动
Realm是Github上星标最多的数据库里面排名第四，仅次于Java 和 Cocoa 的repos。除了核心工程之外，Realm的社区已经编译了[上百个app插件和组件](https://realm.io/addons)
7. 支持
可以从Realm公司快速获得官方的答案，去编译和支持你的数据库。Realm的团队会在[Github](https://github.com/realm), [StackOverflow](https://stackoverflow.com/questions/tagged/realm?sort=newest), & [Twitter](https://twitter.com/realm)回答大家的各种问题

下面再发3张令人惊喜的性能对比图

![](http://upload-images.jianshu.io/upload_images/1194012-c5a9a2eba990151e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是每秒能在20万条数据中进行查询后count的次数。realm每秒可以进行30.9次查询后count。SQLite仅仅只有每秒13.6次查询后的count，相对于Core Data只有可怜的1。


![](http://upload-images.jianshu.io/upload_images/1194012-f44984d9ac96595c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在20万条中进行一次遍历查询，数据和前面的count相似：Realm一秒可以遍历20万条数据31次，而RCore Data只能进行两次查询。 SQLite也只有14次而已。




![](http://upload-images.jianshu.io/upload_images/1194012-c808e85259fbccf5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
这是在一次事务每秒插入数据的对比，Realm每秒可以插入9.4万条记录，在这个比较里纯SQLite的性能最好，每秒可以插入17.8万条记录。然而封装了SQLite的FMDB的成绩大概是Realm的一半，4.7万，Core Data就更低了，只有可怜的1.8万。

从以上3张图可以看出Realm优秀的特性。那么我们开始使用Realm吧。第一步就是把本地的数据库换成Realm。

下面是我翻译的一篇手把手教程，那么让我们赶紧通过教程，来把Core Data迁移到Realm吧。

## [原文](https://realm.io/news/migrating-from-core-data-to-realm/)

## 译文
把一个使用core data框架作为数据库存储方式的app，迁移到Realm的确是一件很容易的事情。如果你现在有一个已经用了Core Data的app，并且考虑换成Realm，这个手把手教程正适合你！

很多开发者在用户界面，高度集成了Core Data(有时可能有上千行代码),这时很多人会告诉你转换Core Data到Realm可能会花数小时。Core Data和Realm两者都是把你的数据当成Object看待，所以迁移通常是很直接的过程:把你已经存在的Core Data的代码重构成使用Realm API的过程是很简单的。

迁移后，你会为Realm为你app带来的易用性，速度快，和稳定性而感到兴奋。

### 1.移除Core Data Framework
首先，如果你的app当前正在使用Core Data，你需要找出哪些代码是包含了Core Data的代码。这些代码是需要重构的。幸运的是，这里有一个手动的方式去做这件事:你可以手动的在整个代码里面搜索相关的代码，然后删除每个导入了Core Data头文件声明的语句

```
#import <CoreData/CoreData.h>
//or
@import CoreData;
```

一旦这样删除以后，每一行使用了Core Data的将会报一个编译错误，接下来，解决这些编译错误只是时间问题。


### 2.移除Core Data的设置代码
在Core Data中，对model objects的更改是要通过managed object context object来实现的。而managed object context objects又是被persistent store coordinator object创建的，它们两者又是被managed object model object创建的。

可以这么说，在你开始思考用Core Data读取，或者写入数据的时候，你通常需要在你的app中的某处去设置依赖的对象，暴露一些Core Data的方法给你的app逻辑使用。无论在你的application delegate中，全局的单例中，或者就是在inline实现中，这些地方都会存在大量的潜在的Core Data 设置代码。

当你准备转换到Realm时，所有的这些代码都可以删掉。

在Realm中，所有设置都在你第一次创建一个Realm object的时候就已经都完成了。当然也是可以手动去配置它，就像你指定Realm数据文件存储在你的硬盘的哪个路径下，这些完全都可以在runtime的时候去选择的。


```
RLMRealm *defaultRealm = [RLMRealm defaultRealm];
//or
let realm = Realm()
```
感觉很好吧？


### 3.迁移model文件

在Core Data中，实用的那些类都是被定义成NSManagedObject的子类。这些object的接口都是很标准的，原始的类型(比如NSInteger 和 CGFloat)是不能被使用的，它们必须抽象成一个NSNumber对象。

```
@interface Dog : NSManagedObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSNumber *age;
@property (nonatomic, strong) NSDate *birthdate;

@end

@implementation Dog

@dynamic name;
@dynamic age;
@dynamic birthdate;

@end
```

把这些managed object subclasses转换成Realm是非常简单的:

```
@interface Dog : RLMObject

@property NSString *uuid;
@property NSString *name;
@property NSInteger age;
@property NSDate *birthdate;

@end

@implementation Dog

+ (NSString *)primaryKey
{
    return @"uuid";
}

+ (NSDictionary *)defaultPropertyValues
{
    return @{ @"uuid" : [[NSUUID UUID] UUIDString],
              @"name" : @"",
              @"birthdate" : [NSDate date]};
}

@end
```

或者

```

class Dog: Object {
    dynamic var uuid = NSUUID().UUIDString
    dynamic var name = ""
    dynamic var age = 0
    dynamic var birthdate = NSDate().date
    
    override static func primaryKey() -> String? {
        return "uuid"
    }
}
```

完成！这是多么的简单？

看这些实现，还是有一些Realm的细节需要注意的。

对于初次使用Realm的人来说，没有必要去指定属性关键字，Realm在内部已经管理了。所以这些类的头文件看上去都很精简。此外，Realm支持简单的数据类型，比如NSInteger 和 CGFloat，所有所有的NSNumber都可以安全的删除。

另一方面，这有一些关于Realm model的声明额外的说明。

1. Core Data objects通过内部的NSManagedObjectID属性去唯一标识一个objects，Realm把这个留给开发者去完成。在上面的例子中，我们额外添加了一个名为uuid的属性，然后通过调用 [RLMObject primaryKey]方法去作为这个class的唯一标识。当然，如果你的objects完全不需要唯一标识，这些都可以跳过。

2. 在写数据的过程中(这个过程不会太长！),Realm不能处理nil的object的属性。原因是，在[RLMObject defaultPropertyValues]这个类方法中给每个object在最初创建的时候，每个object属性都定义了一系列default值。当然这只是暂时的，我们很高兴的告诉你，在接下来的更新中，我们将会支持Realm object的属性可以为nil。


### 4.迁移写操作

如果你不能保存你的数据，这肯定不是一个持久的方案！创建一个新的Core Data对象然后再简单的修改一下它，需要下面这些代码：

```

//Create a new Dog
Dog *newDog = [NSEntityDescription insertNewObjectForEntityForName:@"Dog" inManagedObjectContext:myContext];
newDog.name = @"McGruff";

//Save the new Dog object to disk
NSError *saveError = nil;
[newDog.managedObjectContext save:&saveError];

//Rename the Dog
newDog.name = @"Pluto";
[newDog.managedObjectContext save:&saveError];
```

相比之下，Realm保存的操作是略有不同的，但在相同的范围内修改上面的代码，仍然有相似的地方。

```
//Create the dog object
Dog *newDog = [[Dog alloc] init];
newDog.name = @"McGruff";

//Save the new Dog object to disk (Using a block for the transaction)
RLMRealm *defaultRealm = [RLMRealm defaultRealm];
[defaultRealm transactionWithBlock:^{
    [defaultRealm addObject:newDog];
}];

//Rename the dog (Using open/close methods for the transaction)
[defaultRealm beginWriteTransaction];
newDog.name = @"Pluto";
[defaultRealm commitWriteTransaction];
```

或者

```
//Create the dog object
let mydog = Dog()
myDog.name = "McGruff"

//Save the new Dog object to disk (Using a block for the transaction)
Realm().write {
    realm.add(myDog)
}

//Rename the dog (Using open/close methods for the transaction)
Realm().beginWrite()
myDog.name = "Pluto"
Realm().commitWrite()
```

完成！我们的数据被保存了！

明显的不同是，在Realm中，一旦一个objects被添加到一个Realm object中，它就是不可被修改的。为了在修改属性操作的后面执行，Realm object会被保存在一个写的事务中。这种不能被修改的model，保证了在不同线程中读/写 object数据的情况下，数据的一致性。

Core Data的实现确实可以改变属性，然后调用save方法，对比Realm的实现，只是一些小小的不同罢了。


### 5.迁移查询


另一方面，如果你不能检索查询你的数据，这肯定不是一个持久的方案！

在Core Data的基础实现中，它运用了fetch requests的概念去从硬盘检索数据。一个fetch request object是被当成一个单独的实例化对象去创建的，包含了一些额外的过滤参数，排序条件。

```

NSManagedObjectContext *context = self.managedObjectContext;

//A fetch request to get all dogs younger than 5 years old, in alphabetical order
NSEntityDescription *entity = [NSEntityDescription
                               entityForName:@"Dog" inManagedObjectContext:context];

NSPredicate *predicate = [NSPredicate predicateWithFormat:@"age < 5"];

NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];

NSFetchRequest *request = [[NSFetchRequest alloc] init];
request.entity = entity;
request.predicate = predicate;
request.sortDescriptors = @[sortDescriptor];

NSError *error;
NSArray *dogs = [moc executeFetchRequest:request error:&error];
```
虽然这确实挺好，但是需要编写大量的代码！一些聪明的开发者就开发了一些library使这些代码编写的更加容易。比如MagicalRecord。

对比这些，使用了Realm之后，这些查询的等效代码如下:

```
RLMResults *dogs = [[Dog objectsWhere:@"age < 5"] sortedResultsUsingProperty:@"name" ascending:YES];
```
或者

```
var dogs = Realm().objects(Dog).filter("age < 5").sorted("name")
```

在一行调用了2个方法。对比Core Data将近10行代码。

当然，相同操作得到的结果是相同的(RLMResults 和 NSArray 基本类似),转换到Realm，由于这些查询都是很独立的，所以查询周围的逻辑只需要重构很少的一部分代码就可以了。


### 6.迁移用户数据

一旦你所有代码都迁移到Realm，这里还有一个突出的问题，你如何迁移所有用户已经存在在他们设备上的数据，从Core Data迁移到Realm中？

显然，这是非常复杂的问题，它决定于你的app的功能，还有用户的环境。你处理这种情况可能解决办法每次都不一样。

目前，我们看到了2种情况:

1. 一旦你迁移到Realm，你可以重新导入Core Data framework到你的app，用原生的NSManagedObject objects去fetch你的用户的Core Data数据，然后手动的把数据传给Realm。你可以把这段迁移的代码永久的留在app中，或者也可以经过非常充足的时间之后，再删除掉。

2. 如果用户数据不是不可替代的——举个例子，如果是一些简单的缓存信息，可以通过硬盘上的用户数据重新生成的话，那么可以很简单的就把Core Data数据直接清除掉，当用户下次打开app的时候，一切从0开始。当然这需要经过非常谨慎的考虑，不然的话，会给很多人留下非常坏的用户体验。

最终，决定应该偏向于用户。理想的情况是不要留下Core Data还连接着你的app，但是结果还是要取决于你的情况。好运！


## 进一步的讨论

虽然在移植一个应用程序到Realm过程中，没有真正重要的步骤，但是有一些额外的情况下，你应该知道：

### 并发


如果你在后台线程做了一些比较重的操作，你可能会发现你需要在线程之间传递Realm object。在Core Data中允许你在线程之间传递managed objects(虽然这样做不是最佳实践)，但是在Realm中，在线程中传递objects是严格禁止的，并且任何企图这样做的，都会抛出一个严重的异常。

如此来说，对于下面这些情况，是件很容易的事情:

```

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    //Rename the dog in a background queue
    [[RLMRealm defaultRealm] transactionWithBlock:^{
        dog.name = @"Peanut Wigglebutt";
    }];
    
    //Print the dog's name on the main queue
    NSString *uuid = dog.uuid;
    dispatch_async(dispatch_get_main_queue(), ^{
        Dog *localDog = [Dog objectForPrimaryKey:uuid];
        NSLog(@"Dog's name is %@", localDog.name);
    });
});
```

或者

```

dispatch_async(queue) {
    //Rename the dog in a background queue
    Realm().write {
        dog.name = "Peanut Wigglebutt"
    }
    
    //Print the dog's name on the main queue
    let uuid = dog.uuid
    dispatch_async(dispatch_get_main_queue()) {
        let localDog = Realm().objectForPrimaryKey(Dog, uuid)
        println("Dog's name is \\(localDog.name)")
    }
}
```

虽然Realm objects不能在线程间被传递，但是Realm properties的副本可以在线程中被传递。考虑到Realm从磁盘中检索objects是非常快速的，如果只是简单的通过新线程在存储区中重新refetch相同的object，这只会造成很小的性能损失。在这个例子中，我们取了对象的主键的copy，然后把它从后台队列传递给主队列，然后再通过它在主线程的上下文中重新获取该对象。


### NSFetchedResultsController 的等效做法

相比Core Data的所有缺点，可能使用Core Data最充足的理由就是NSFetchedResultsController——这是一个类，它可以检测到数据存储的变化，并且能自动的把这一变化展示到UI上。

在写这篇文章的时候，Realm还没有相似的机制。虽然它可以注册一个block，这个block会在数据源发生变化的时候被执行，但是这种"蛮力"的做法对大多数的UI来说都是不友好的。目前，如果你的UI代码很依赖Realm，那么这种做法对你来说就像处理一个breaker一样。

Realm的cocoa工程师现在正在开发一套通知系统，当一些object的属性被更改的时候，允许我们去注册一个通知，来接收到这些改变。这些特性都会在Realm的Swift and  Objective‑C 的未来的更新版本中。

在此期间，如果现有的通知block API还是没有满足你的需要，但是你还是需要当特定的property被更改了收到一个通知，这里推荐使用神奇的第三方库，名字叫[RBQFetchedResultsController](https://github.com/Roobiq/RBQFetchedResultsController)，它能模仿上述功能。除此之外，你还可以通过在objects里面加入setter方法，当setter方法被调用的时候，发送一个广播通知，这样做也能实现相同的功能。



## 结尾

Core Data和Realm的在展示数据的时候都是通过model objects，由于这一相似性，得以让我们从Core Data迁移到Realm时非常迅速，简单(并且非常令人满意！)。尽管开始看上去令人怯步，但是实际做起来，就是需要把每个Core Data的方法调用转换成等价的Realm的方法，然后写一个辅助类去帮你迁移用户的数据。这些也都非常简单。

如果你在你的app中使用Core Data遇到了些困难，需要些更加简单的解决办法，我们强烈推荐你尝试一下Realm，看看它是否适用于你。如果适用，请你告诉我们！

感谢阅读这篇文章。快去用Realm构建一个令人惊喜的app吧！在这些地方可以联系到我们[StackOverflow](https://stackoverflow.com/questions/tagged/realm?sort=newest), [GitHub](https://github.com/realm/realm-cocoa), or [Twitter](https://twitter.com/realm).