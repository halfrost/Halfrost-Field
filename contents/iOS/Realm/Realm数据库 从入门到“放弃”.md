<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-fdee34cd97308fac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 




## 前言 

由于最近项目中在用Realm，所以把自己实践过程中的一些心得总结分享一下。

Realm是由Y Combinator孵化的创业团队开源出来的一款可以用于iOS(同样适用于Swift&Objective-C)和Android的跨平台移动数据库。目前最新版是Realm 2.0.2，支持的平台包括Java，Objective-C，Swift，React Native，Xamarin。

Realm官网上说了好多优点，我觉得选用Realm的最吸引人的优点就三点：

1. **跨平台**：现在很多应用都是要兼顾iOS和Android两个平台同时开发。如果两个平台都能使用相同的数据库，那就不用考虑内部数据的架构不同，使用Realm提供的API，可以使数据持久化层在两个平台上无差异化的转换。

2. **简单易用**：Core Data 和 SQLite 冗余、繁杂的知识和代码足以吓退绝大多数刚入门的开发者，而换用 Realm，则可以极大地减少学习成本，立即学会本地化存储的方法。毫不吹嘘的说，把官方最新文档完整看一遍，就完全可以上手开发了。

3. **可视化**：Realm 还提供了一个轻量级的数据库查看工具，在Mac Appstore 可以下载“Realm Browser”这个工具，开发者可以查看数据库当中的内容，执行简单的插入和删除数据的操作。毕竟，很多时候，开发者使用数据库的理由是因为要提供一些所谓的“知识库”。

![](http://upload-images.jianshu.io/upload_images/1194012-96eb173768167645.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  
“Realm Browser”这个工具调试起Realm数据库实在太好用了，强烈推荐。

如果使用模拟器进行调试,可以通过

```objectivec

[RLMRealmConfiguration defaultConfiguration].fileURL

```

打印出Realm 数据库地址,然后在Finder中⌘⇧G跳转到对应路径下,用Realm Browser打开对应的.realm文件就可以看到数据啦.

如果是使用真机调试的话“Xcode->Window->Devices(⌘⇧2)”,然后找到对应的设备与项目,点击Download Container，导出xcappdata文件后,显示包内容,进到AppData->Documents,使用Realm Browser打开.realm文件即可.




自2012年起， Realm 就已经开始被用于正式的商业产品中了。经过4年的使用，逐步趋于稳定。


## 目录
- 1.Realm 安装
- 2.Realm 中的相关术语
- 3.Realm 入门——如何使用
- 4.Realm 使用中可能需要注意的一些问题
- 5.Realm “放弃”——优点和缺点
- 6.Realm 到底是什么？
- 7.总结


## 一. Realm 安装

使用 Realm 构建应用的基本要求：
1. iOS 7 及其以上版本, macOS 10.9 及其以上版本，此外 Realm 支持 tvOS 和 watchOS 的所有版本。
2. 需要使用 Xcode 7.3 或者以后的版本。

**注意** 这里如果是纯的OC项目，就安装OC的Realm，如果是纯的Swift项目，就安装Swift的Realm。如果是混编项目，就需要安装OC的Realm，然后要把 [Swift/RLMSupport.swift
](https://github.com/realm/realm-cocoa/blob/master/Realm/Swift/RLMSupport.swift) 文件一同编译进去。

RLMSupport.swift这个文件为 Objective-C 版本的 Realm 集合类型中引入了 Sequence 一致性，并且重新暴露了一些不能够从 Swift 中进行原生访问的 Objective-C 方法，例如可变参数 (variadic arguments)。更加详细的说明见[官方文档](https://realm.io/docs/objc/latest/#getting-started)。


安装方法就4种：

### 一. Dynamic Framework
**注意：动态框架与 iOS 7 不兼容，要支持 iOS 7 的话请查看“静态框架”。**
1. 下载[最新的Realm发行版本](https://static.realm.io/downloads/objc/realm-objc-2.0.2.zip)，并解压；
2. 前往Xcode 工程的”General”设置项中，从ios/dynamic/、osx/、tvos/
或者watchos/中将’Realm.framework’拖曳到”Embedded Binaries”选项中。确认**Copy items if needed**被选中后，点击**Finish**按钮；
3. 在单元测试 Target 的”Build Settings”中，在”Framework Search Paths”中添加Realm.framework的上级目录；
4. 如果希望使用 Swift 加载 Realm，请拖动Swift/RLMSupport.swift
文件到 Xcode 工程的文件导航栏中并选中**Copy items if needed**；
5. 如果在 iOS、watchOS 或者 tvOS 项目中使用 Realm，请在您应用目标的”Build Phases”中，创建一个新的”Run Script Phase”，并将

```vim

bash "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Realm.framework/strip-frameworks.sh"

```
这条脚本复制到文本框中。 因为要绕过[APP商店提交的bug](http://www.openradar.me/radar?id=6409498411401216)，这一步在打包通用设备的二进制发布版本时是必须的。

### 二.CocoaPods

![](http://upload-images.jianshu.io/upload_images/1194012-da6cec98554a0fbf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在项目的Podfile中，添加pod 'Realm'，在终端运行pod install。

### 三.Carthage
1.在Carthage 中添加github "realm/realm-cocoa"，运行carthage update。为了修改用以构建项目的 Swift toolchain，通过--toolchain参数来指定合适的 toolchain。--no-use-binaries参数也是必需的，这可以避免 Carthage 将预构建的 Swift 3.0 二进制包下载下来。 例如：  

```vim

carthage update --toolchain com.apple.dt.toolchain.Swift_2_3 --no-use-binaries

```

2.从 Carthage/Build/目录下对应平台文件夹中，将 Realm.framework
 拖曳到您 Xcode 工程”General”设置项的”Linked Frameworks and Libraries”选项卡中；

3.**iOS/tvOS/watchOS:** 在您应用目标的“Build Phases”设置选项卡中，点击“+”按钮并选择“New Run Script Phase”。在新建的Run Script中，填写:

```vim

/usr/local/bin/carthage copy-frameworks

```

在“Input Files”内添加您想要使用的框架路径，例如:

```vim

$(SRCROOT)/Carthage/Build/iOS/Realm.framework

```

因为要绕过[APP商店提交的bug](http://www.openradar.me/radar?id=6409498411401216)，这一步在打包通用设备的二进制发布版本时是必须的。

### 四.Static Framework (iOS only)

1. 下载 [Realm 的最新版本](https://static.realm.io/downloads/objc/realm-objc-2.0.2.zip)并解压，将 Realm.framework 从 ios/static/文件夹拖曳到您 Xcode 项目中的文件导航器当中。确保 **Copy items if needed** 选中然后单击 **Finish**；
2. 在 Xcode 文件导航器中选择您的项目，然后选择您的应用目标，进入到** Build Phases** 选项卡中。在 **Link Binary with Libraries** 中单击 + 号然后添加**libc++.dylib**；

## 二. Realm 中的相关术语

为了能更好的理解Realm的使用，先介绍一下涉及到的相关术语。

**RLMRealm**：Realm是框架的核心所在，是我们构建数据库的访问点，就如同Core Data的管理对象上下文（managed object context）一样。出于简单起见，realm提供了一个默认的defaultRealm( )的便利构造器方法。

**RLMObject**：这是我们自定义的Realm数据模型。创建数据模型的行为对应的就是数据库的结构。要创建一个数据模型，我们只需要继承RLMObject，然后设计我们想要存储的属性即可。

**关系(Relationships)**：通过简单地在数据模型中声明一个RLMObject类型的属性，我们就可以创建一个“一对多”的对象关系。同样地，我们还可以创建“多对一”和“多对多”的关系。

**写操作事务(Write Transactions)**：数据库中的所有操作，比如创建、编辑，或者删除对象，都必须在**事务**中完成。“事务”是指位于write闭包内的代码段。

**查询(Queries)**：要在数据库中检索信息，我们需要用到“检索”操作。检索最简单的形式是对Realm( )数据库发送查询消息。如果需要检索更复杂的数据，那么还可以使用断言（predicates）、复合查询以及结果排序等等操作。

**RLMResults**：这个类是执行任何查询请求后所返回的类，其中包含了一系列的**RLMObject**对象。RLMResults和NSArray类似，我们可以用下标语法来对其进行访问，并且还可以决定它们之间的关系。不仅如此，它还拥有许多更强大的功能，包括排序、查找等等操作。



## 三.Realm 入门——如何使用

由于Realm的API极为友好，一看就懂，所以这里就按照平时开发的顺序，把需要用到的都梳理一遍。

### 1. 创建数据库

```objectivec

- (void)creatDataBaseWithName:(NSString *)databaseName
{
    NSArray *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [docPath objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:databaseName];
    NSLog(@"数据库目录 = %@",filePath);

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.fileURL = [NSURL URLWithString:filePath];
    config.objectClasses = @[MyClass.class, MyOtherClass.class];
    config.readOnly = NO;
    int currentVersion = 1.0;
    config.schemaVersion = currentVersion;
    
    config.migrationBlock = ^(RLMMigration *migration , uint64_t oldSchemaVersion) {
       // 这里是设置数据迁移的block
        if (oldSchemaVersion < currentVersion) {
        }
    };
    
    [RLMRealmConfiguration setDefaultConfiguration:config];

}

```

创建数据库主要设置RLMRealmConfiguration，设置数据库名字和存储地方。把路径以及数据库名字拼接好字符串，赋值给fileURL即可。

objectClasses这个属性是用来控制对哪个类能够存储在指定 Realm 数据库中做出限制。例如，如果有两个团队分别负责开发您应用中的不同部分，并且同时在应用内部使用了 Realm 数据库，那么您肯定不希望为它们协调进行数据迁移您可以通过设置RLMRealmConfiguration的 objectClasses属性来对类做出限制。objectClasses一般可以不用设置。

readOnly是控制是否只读属性。


还有一个很特殊的数据库，内存数据库。

通常情况下，Realm 数据库是存储在硬盘中的，但是您能够通过设置inMemoryIdentifier而不是设置RLMRealmConfiguration中的 fileURL属性，以创建一个完全在内存中运行的数据库。

```objectivec

RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];config.inMemoryIdentifier = @"MyInMemoryRealm";RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];

```

内存数据库在每次程序运行期间都不会保存数据。但是，这不会妨碍到 Realm 的其他功能，包括查询、关系以及线程安全。

如果需要一种灵活的数据读写但又不想储存数据的方式的话，那么可以选择用内存数据库。(关于内存数据库的性能 和 类属性的 性能，还没有测试过，感觉性能不会有太大的差异，所以内存数据库使用场景感觉不多)

使用内存数据库需要注意的是：

1. 内存数据库会在临时文件夹中创建多个文件，用来协调处理诸如跨进程通知之类的事务。 实际上没有任何的数据会被写入到这些文件当中，除非操作系统由于内存过满， ~~需要清除磁盘上的多余空间。~~ 才会去把内存里面的数据存入到文件中。（感谢 @酷酷的哀殿 指出）



2. 如果某个内存 Realm 数据库实例没有被引用，那么所有的数据就会被释放。所以必须要在应用的生命周期内保持对Realm内存数据库的强引用，以避免数据丢失。

### 2. 建表

Realm数据模型是基于标准 Objective‑C 类来进行定义的，使用属性来完成模型的具体定义。

我们只需要继承 RLMObject或者一个已经存在的模型类，您就可以创建一个新的 Realm 数据模型对象。对应在数据库里面就是一张表。

```objectivec

#import <Realm/Realm.h>

@interface RLMUser : RLMObject

@property NSString       *accid;
//用户注册id
@property NSInteger      custId;
//姓名
@property NSString       *custName;
//头像大图url
@property NSString       *avatarBig;
@property RLMArray<Car> *cars;

RLM_ARRAY_TYPE(RLMUser) // 定义RLMArray<RLMUser>


@interface Car : RLMObject
@property NSString *carName;
@property RLMUser *owner;
@end

RLM_ARRAY_TYPE(Car) // 定义RLMArray<Car>

@end

```

**注意**，RLMObject 官方建议不要加上 Objective-C的property attributes(如nonatomic, atomic, strong, copy, weak 等等）假如设置了，这些attributes会一直生效直到RLMObject被写入realm数据库。


RLM_ARRAY_TYPE宏创建了一个协议，从而允许 RLMArray<Car>语法的使用。如果该宏没有放置在模型接口的底部的话，您或许需要提前声明该模型类。

关于RLMObject的的关系

1.对一(To-One)关系

对于多对一(many-to-one)或者一对一(one-to-one)关系来说，只需要声明一个RLMObject子类类型的属性即可，如上面代码例子，@property RLMUser *owner;

2.对多(To-Many)关系
通过 RLMArray类型的属性您可以定义一个对多关系。如上面代码例子，@property RLMArray<Car> *cars;

3.反向关系(Inverse Relationship)

链接是单向性的。因此，如果对多关系属性 RLMUser.cars链接了一个 Car实例，而这个实例的对一关系属性 Car.owner又链接到了对应的这个 RLMUser实例，那么实际上这些链接仍然是互相独立的。

```objectivec


@interface Car : RLMObject
@property NSString *carName;
@property (readonly) RLMLinkingObjects *owners;
@end

@implementation Car
+ (NSDictionary *)linkingObjectsProperties {
    return @{
             @"owners": [RLMPropertyDescriptor descriptorWithClass:RLMUser.class propertyName:@"cars"],
             };
}
@end

```

这里可以类比Core Data里面xcdatamodel文件里面那些“箭头”



![](http://upload-images.jianshu.io/upload_images/1194012-c170321185c77092.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





```objectivec

@implementation Book

// 主键
+ (NSString *)primaryKey {
    return @"ID";
}

//设置属性默认值
+ (NSDictionary *)defaultPropertyValues{
    return @{@"carName":@"测试" };
}

//设置忽略属性,即不存到realm数据库中
+ (NSArray<NSString *> *)ignoredProperties {
    return @[@"ID"];
}

//一般来说,属性为nil的话realm会抛出异常,但是如果实现了这个方法的话,就只有name为nil会抛出异常,也就是说现在cover属性可以为空了
+ (NSArray *)requiredProperties {
    return @[@"name"];
}

//设置索引,可以加快检索的速度
+ (NSArray *)indexedProperties {
    return @[@"ID"];
}
@end

```

还可以给RLMObject设置主键primaryKey，默认值defaultPropertyValues，忽略的属性ignoredProperties，必要属性requiredProperties，索引indexedProperties。比较有用的是主键和索引。

### 3.存储数据


新建对象

```objectivec

// (1) 创建一个Car对象，然后设置其属性
Car *car = [[Car alloc] init];
car.carName = @"Lamborghini";

// (2) 通过字典创建Car对象
Car *myOtherCar = [[Car alloc] initWithValue:@{@"name" : @"Rolls-Royce"}];

// (3) 通过数组创建狗狗对象
Car *myThirdcar = [[Car alloc] initWithValue:@[@"BMW"]];

```

**注意，所有的必需属性都必须在对象添加到 Realm 前被赋值**


## 4.增


![](http://upload-images.jianshu.io/upload_images/1194012-ca53417c1d55ab5d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




```objectivec


[realm beginWriteTransaction];
[realm addObject:Car];
[realm commitWriteTransaction];

```

**请注意，如果在进程中存在多个写入操作的话，那么单个写入操作将会阻塞其余的写入操作，并且还会锁定该操作所在的当前线程。**

Realm这个特性与其他持久化解决方案类似，我们建议您使用该方案常规的最佳做法：将写入操作转移到一个独立的线程中执行。

官方给出了一个建议：

由于 Realm 采用了 MVCC 设计架构，**读取操作并不会因为写入事务正在进行而受到影响**。除非您需要立即使用多个线程来同时执行写入操作，不然您应当采用批量化的写入事务，而不是采用多次少量的写入事务。


```objectivec

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm addObject: Car];
        }];
    });

```

上面的代码就是把写事务放到子线程中去处理。


### 5.删


![](http://upload-images.jianshu.io/upload_images/1194012-c41304bc132249ca.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```objectivec

[realm beginWriteTransaction];
// 删除单条记录
[realm deleteObject:Car];
// 删除多条记录
[realm deleteObjects:CarResult];
// 删除所有记录
[realm deleteAllObjects];

[realm commitWriteTransaction];
```

### 6.改



![](http://upload-images.jianshu.io/upload_images/1194012-ac4a130ece033e65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


当没有主键的情况下，需要先查询，再修改数据。
当有主键的情况下，有以下几个非常好用的API

```objectivec

[realm addOrUpdateObject:Car];

[Car createOrUpdateInRealm:realm withValue:@{@"id": @1, @"price": @9000.0f}];

```

addOrUpdateObject会去先查找有没有传入的Car相同的主键，如果有，就更新该条数据。这里需要注意，**addOrUpdateObject这个方法不是增量更新**，所有的值都必须有，如果有哪几个值是null，那么就会覆盖原来已经有的值，这样就会出现数据丢失的问题。

createOrUpdateInRealm：withValue：这个方法是增量更新的，后面传一个字典，使用这个方法的前提是有主键。方法会先去主键里面找有没有字典里面传入的主键的记录，如果有，就只更新字典里面的子集。如果没有，就新建一条记录。


### 7.查



![](http://upload-images.jianshu.io/upload_images/1194012-78425d8b2748e9e8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在Realm中所有的查询（包括查询和属性访问）在 Realm 中都是延迟加载的，只有当属性被访问时，才能够读取相应的数据。

查询结果并不是数据的拷贝：修改查询结果（在写入事务中）会直接修改硬盘上的数据。同样地，您可以直接通过包含在RLMResults中的RLMObject对象完成遍历关系图的操作。除非查询结果被使用，否则检索的执行将会被推迟。这意味着链接几个不同的临时 {RLMResults} 来进行排序和匹配数据，不会执行额外的工作，例如处理中间状态。
一旦检索执行之后，或者通知模块被添加之后， RLMResults将随时保持更新，接收 Realm 中，在后台线程上执行的检索操作中可能所做的更改。


```objectivec

//从默认数据库查询所有的车
RLMResults<Car *> *cars = [Car allObjects];

// 使用断言字符串查询
RLMResults<Dog *> *tanDogs = [Dog objectsWhere:@"color = '棕黄色' AND name BEGINSWITH '大'"];

// 使用 NSPredicate 查询
NSPredicate *pred = [NSPredicate predicateWithFormat:@"color = %@ AND name BEGINSWITH %@",
                     @"棕黄色", @"大"];
RLMResults *results = [Dog objectsWithPredicate:pred];

// 排序名字以“大”开头的棕黄色狗狗
RLMResults<Dog *> *sortedDogs = [[Dog objectsWhere:@"color = '棕黄色' AND name BEGINSWITH '大'"] sortedResultsUsingProperty:@"name" ascending:YES];


```

Realm还能支持链式查询

Realm 查询引擎一个特性就是它能够通过非常小的事务开销来执行链式查询(chain queries)，而不需要像传统数据库那样为每个成功的查询创建一个不同的数据库服务器访问。

```objectivec

RLMResults<Car *> *Cars = [Car objectsWhere:@"color = blue"];
RLMResults<Car *> *CarsWithBNames = [Cars objectsWhere:@"name BEGINSWITH 'B'"];

```

### 8.其他相关特性

1.支持KVC和KVO

RLMObject、RLMResult以及 RLMArray
都遵守键值编码(Key-Value Coding)（KVC）机制。当您在运行时才能决定哪个属性需要更新的时候，这个方法是最有用的。
将 KVC 应用在集合当中是大量更新对象的极佳方式，这样就可以不用经常遍历集合，为每个项目创建一个访问器了。

```objectivec

RLMResults<Person *> *persons = [Person allObjects];
[[RLMRealm defaultRealm] transactionWithBlock:^{ 
    [[persons firstObject] setValue:@YES forKeyPath:@"isFirst"]; // 将每个人的 planet 属性设置为“地球” 
    [persons setValue:@"地球" forKeyPath:@"planet"];
}];

```

Realm 对象的大多数属性都遵从 KVO 机制。所有 RLMObject子类的持久化(persisted)存储（未被忽略）的属性都是遵循 KVO 机制的，并且 RLMObject以及 RLMArray中 无效的(invalidated)属性也同样遵循（然而 RLMLinkingObjects属性并不能使用 KVO 进行观察）。


2.支持数据库加密

```objectivec

// 产生随机密钥
NSMutableData *key = [NSMutableData dataWithLength:64];
SecRandomCopyBytes(kSecRandomDefault, key.length, (uint8_t *)key.mutableBytes);

// 打开加密文件
RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
config.encryptionKey = key;
NSError *error = nil;
RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:&error];
if (!realm) {
    // 如果密钥错误，`error` 会提示数据库不可访问
    NSLog(@"Error opening realm: %@", error);
}
```

Realm 支持在创建 Realm 数据库时采用64位的密钥对数据库文件进行 AES-256+SHA2 加密。这样硬盘上的数据都能都采用AES-256来进行加密和解密，并用 SHA-2 HMAC 来进行验证。每次您要获取一个 Realm 实例时，您都需要提供一次相同的密钥。

不过，加密过的 Realm 只会带来很少的额外资源占用（通常最多只会比平常慢10%）。


3.通知

```objectivec

// 获取 Realm 通知
token = [realm addNotificationBlock:^(NSString *notification, RLMRealm * realm) {
     [myViewController updateUI];
}];

[token stop];

// 移除通知
[realm removeNotification:self.token];

```

Realm 实例将会在每次写入事务提交后，给其他线程上的 Realm 实例发送通知。一般控制器如果想一直持有这个通知，就需要申请一个属性，strong持有这个通知。

```objectivec

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 观察 RLMResults 通知
    __weak typeof(self) weakSelf = self;
    self.notificationToken = [[Person objectsWhere:@"age > 5"] addNotificationBlock:^(RLMResults<Person *> *results, RLMCollectionChange *change, NSError *error) {
        if (error) {
            NSLog(@"Failed to open Realm on background worker: %@", error);
            return;
        }
        
        UITableView *tableView = weakSelf.tableView;
        // 对于变化信息来说，检索的初次运行将会传递 nil
        if (!changes) {
            [tableView reloadData];
            return;
        }
        
        // 检索结果被改变，因此将它们应用到 UITableView 当中
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:[changes deletionsInSection:0]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView insertRowsAtIndexPaths:[changes insertionsInSection:0]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView reloadRowsAtIndexPaths:[changes modificationsInSection:0]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView endUpdates];
    }];
}


```

我们还能进行更加细粒度的通知，用集合通知就可以做到。

集合通知是异步触发的，首先它会在初始结果出现的时候触发，随后当某个写入事务改变了集合中的所有或者某个对象的时候，通知都会再次触发。这些变化可以通过传递到通知闭包当的 RLMCollectionChange参数访问到。这个对象当中包含了受 deletions、insertions和 modifications 状态所影响的索引信息。

集合通知对于 RLMResults、RLMArray、RLMLinkingObjects 以及 RLMResults 这些衍生出来的集合来说，当关系中的对象被添加或者删除的时候，一样也会触发这个状态变化。

4.数据库迁移

这是Realm的优点之一，方便迁移。

对比Core Data的数据迁移，实在是方便太多了。关于iOS Core Data 数据迁移 指南请看这篇[文章](http://www.jianshu.com/p/b3b764fc5191)。

数据库存储方面的增删改查应该都没有什么大问题，比较蛋疼的应该就是数据迁移了。在版本迭代过程中，很可能会发生表的新增，删除，或者表结构的变化，如果新版本中不做数据迁移，用户升级到新版，很可能就直接crash了。对比Core Data的数据迁移比较复杂，Realm的迁移实在太简单了。

1.新增删除表，Realm不需要做迁移
2.新增删除字段，Realm不需要做迁移。Realm 会自行检测新增和需要移除的属性，然后自动更新硬盘上的数据库架构。

举个官方给的数据迁移的例子：

```objectivec

RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
config.schemaVersion = 2;
config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion)
{
    // enumerateObjects:block: 遍历了存储在 Realm 文件中的每一个“Person”对象
    [migration enumerateObjects:Person.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        // 只有当 Realm 数据库的架构版本为 0 的时候，才添加 “fullName” 属性
        if (oldSchemaVersion < 1) {
            newObject[@"fullName"] = [NSString stringWithFormat:@"%@ %@", oldObject[@"firstName"], oldObject[@"lastName"]];
        }
        // 只有当 Realm 数据库的架构版本为 0 或者 1 的时候，才添加“email”属性
        if (oldSchemaVersion < 2) {
            newObject[@"email"] = @"";
        }
       // 替换属性名
       if (oldSchemaVersion < 3) { // 重命名操作应该在调用 `enumerateObjects:` 之外完成 
            [migration renamePropertyForClass:Person.className oldName:@"yearsSinceBirth" newName:@"age"]; }
    }];
};
[RLMRealmConfiguration setDefaultConfiguration:config];
// 现在我们已经成功更新了架构版本并且提供了迁移闭包，打开旧有的 Realm 数据库会自动执行此数据迁移，然后成功进行访问
[RLMRealm defaultRealm];


```

在block里面分别有3种迁移方式，第一种是合并字段的例子，第二种是增加新字段的例子，第三种是原字段重命名的例子。


## 四. Realm 使用中可能需要注意的一些问题



![](http://upload-images.jianshu.io/upload_images/1194012-efc4101042d99c8f.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




在我从0开始接触Realm到熟练上手，基本就遇到了多线程这一个坑。可见Realm的API文档是多么的友好。虽然坑不多，但是还有有些需要注意的地方。

### 1.跨线程访问数据库，Realm对象一定需要新建一个


```vim

*** Terminating app due to uncaught exception 'RLMException', reason: 'Realm accessed from incorrect thread.'**
***** First throw call stack:**
**(**
** 0   CoreFoundation                      0x000000011479f34b __exceptionPreprocess + 171**
** 1   libobjc.A.dylib                     0x00000001164a321e objc_exception_throw + 48**
** 2   BHFangChuang                        0x000000010dd4c2b5 -[RLMRealm beginWriteTransaction] + 77**
** 3   BHFangChuang                        0x000000010dd4c377 -[RLMRealm transactionWithBlock:error:] + 45**
** 4   BHFangChuang                        0x000000010dd4c348 -[RLMRealm transactionWithBlock:] + 19**
** 5   BHFangChuang                        0x000000010d51d7ae __71-[RealmDataBaseHelper updateUserWithLoginDate:andLogoutDate:according:]_block_invoke + 190**
** 6   libdispatch.dylib                   0x00000001180ef980 _dispatch_call_block_and_release + 12**
** 7   libdispatch.dylib                   0x00000001181190cd _dispatch_client_callout + 8**
** 8   libdispatch.dylib                   0x00000001180f8366 _dispatch_queue_override_invoke + 1426**
** 9   libdispatch.dylib                   0x00000001180fa3b7 _dispatch_root_queue_drain + 720**
** 10  libdispatch.dylib                   0x00000001180fa08b _dispatch_worker_thread3 + 123**
** 11  libsystem_pthread.dylib             0x00000001184c8746 _pthread_wqthread + 1299**
** 12  libsystem_pthread.dylib             0x00000001184c8221 start_wqthread + 13**
**)**
**libc++abi.dylib: terminating with uncaught exception of type NSException**

```

如果程序崩溃了，出现以上错误，那就是因为你访问Realm数据的时候，使用的Realm对象所在的线程和当前线程不一致。

解决办法就是在当前线程重新获取最新的Realm，即可。


### 2. 自己封装一个Realm全局实例单例是没啥作用的

这个也是我之前对Realm多线程理解不清，导致的一个误解。

很多开发者应该都会对Core Data和Sqlite3或者FMDB，自己封装一个类似Helper的单例。于是我也在这里封装了一个单例，在新建完Realm数据库的时候strong持有一个Realm的对象。然后之后的访问中只需要读取这个单例持有的Realm对象就可以拿到数据库了。

想法是好的，但是同一个Realm对象是不支持跨线程操作realm数据库的。

Realm 通过确保每个线程始终拥有 Realm 的一个快照，以便让并发运行变得十分轻松。你可以同时有任意数目的线程访问同一个 Realm 文件，并且由于每个线程都有对应的快照，因此线程之间绝不会产生影响。需要注意的一件事情就是不能让多个线程都持有同一个 Realm 对象的 实例 。如果多个线程需要访问同一个对象，那么它们分别会获取自己所需要的实例（否则在一个线程上发生的更改就会造成其他线程得到不完整或者不一致的数据）。

其实RLMRealm \*realm = [RLMRealm defaultRealm]; 这句话就是获取了当前realm对象的一个实例，其实实现就是拿到单例。所以我们每次在子线程里面不要再去读取我们自己封装持有的realm实例了，直接调用系统的这个方法即可，能保证访问不出错。

### 3.transactionWithBlock 已经处于一个写的事务中，事务之间不能嵌套

```objectivec

[realm transactionWithBlock:^{
                [self.realm beginWriteTransaction];
                [self convertToRLMUserWith:bhUser To:[self convertToRLMUserWith:bhUser To:nil]];
                [self.realm commitWriteTransaction];
            }];

```

transactionWithBlock 已经处于一个写的事务中，如果还在block里面再写一个commitWriteTransaction，就会出错，写事务是不能嵌套的。

出错信息如下：

```vim


*** Terminating app due to uncaught exception 'RLMException', reason: 'The Realm is already in a write transaction'**
***** First throw call stack:**
**(**
** 0   CoreFoundation                      0x0000000112e2d34b __exceptionPreprocess + 171**
** 1   libobjc.A.dylib                     0x0000000114b3121e objc_exception_throw + 48**
** 2   BHFangChuang                        0x000000010c4702b5 -[RLMRealm beginWriteTransaction] + 77**
** 3   BHFangChuang                        0x000000010bc4175a __71-[RealmDataBaseHelper updateUserWithLoginDate:andLogoutDate:according:]_block_invoke_2 + 42**
** 4   BHFangChuang                        0x000000010c470380 -[RLMRealm transactionWithBlock:error:] + 54**
** 5   BHFangChuang                        0x000000010c470348 -[RLMRealm transactionWithBlock:] + 19**
** 6   BHFangChuang                        0x000000010bc416d7 __71-[RealmDataBaseHelper updateUserWithLoginDate:andLogoutDate:according:]_block_invoke + 231**
** 7   libdispatch.dylib                   0x0000000116819980 _dispatch_call_block_and_release + 12**
** 8   libdispatch.dylib                   0x00000001168430cd _dispatch_client_callout + 8**
** 9   libdispatch.dylib                   0x0000000116822366 _dispatch_queue_override_invoke + 1426**
** 10  libdispatch.dylib                   0x00000001168243b7 _dispatch_root_queue_drain + 720**
** 11  libdispatch.dylib                   0x000000011682408b _dispatch_worker_thread3 + 123**
** 12  libsystem_pthread.dylib             0x0000000116bed746 _pthread_wqthread + 1299**
** 13  libsystem_pthread.dylib             0x0000000116bed221 start_wqthread + 13**
**)**
**libc++abi.dylib: terminating with uncaught exception of type NSException**


```

### 4.建议每个model都需要设置主键，这样可以方便add和update

如果能设置主键，请尽量设置主键，因为这样方便我们更新数据，我们可以很方便的调用addOrUpdateObject: 或者 createOrUpdateInRealm：withValue：方法进行更新。这样就不需要先根据主键，查询出数据，然后再去更新。有了主键以后，这两步操作可以一步完成。


### 5.查询也不能跨线程查询 

```objectivec


RLMResults * results = [self selectUserWithAccid:bhUser.accid];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm addOrUpdateObject:results[0]];
        }];
    });

```

由于查询是在子线程外查询的，所以跨线程也会出错，出错信息如下：


```vim


***** Terminating app due to uncaught exception 'RLMException', reason: 'Realm accessed from incorrect thread'**
***** First throw call stack:**
**(**
** 0   CoreFoundation                      0x000000011517a34b __exceptionPreprocess + 171**
** 1   libobjc.A.dylib                     0x0000000116e7e21e objc_exception_throw + 48**
** 2   BHFangChuang                        0x000000010e7c34ab _ZL10throwErrorP8NSString + 129**
** 3   BHFangChuang                        0x000000010e7c177f -[RLMResults count] + 40**
** 4   BHFangChuang                        0x000000010df8f3bf -[RealmDataBaseHelper convertToRLMUserWith:LoginDate:LogoutDate:To:] + 159**
** 5   BHFangChuang                        0x000000010df8efc1 __71-[RealmDataBaseHelper updateUserWithLoginDate:andLogoutDate:according:]_block_invoke_2 + 81**
** 6   BHFangChuang                        0x000000010e7bd320 -[RLMRealm transactionWithBlock:error:] + 54**
** 7   BHFangChuang                        0x000000010e7bd2e8 -[RLMRealm transactionWithBlock:] + 19**
** 8   BHFangChuang                        0x000000010df8eecf __71-[RealmDataBaseHelper updateUserWithLoginDate:andLogoutDate:according:]_block_invoke + 351**
** 9   libdispatch.dylib                   0x0000000118b63980 _dispatch_call_block_and_release + 12**
** 10  libdispatch.dylib                   0x0000000118b8d0cd _dispatch_client_callout + 8**
** 11  libdispatch.dylib                   0x0000000118b6c366 _dispatch_queue_override_invoke + 1426**
** 12  libdispatch.dylib                   0x0000000118b6e3b7 _dispatch_root_queue_drain + 720**
** 13  libdispatch.dylib                   0x0000000118b6e08b _dispatch_worker_thread3 + 123**
** 14  libsystem_pthread.dylib             0x0000000118f3c746 _pthread_wqthread + 1299**
** 15  libsystem_pthread.dylib             0x0000000118f3c221 start_wqthread + 13**
**)**
**libc++abi.dylib: terminating with uncaught exception of type **

```


## 五. Realm “放弃”——优点和缺点


关于Realm的优点，在官网上也说了很多了，我感触最深的3个优点也在文章开头提到了。

CoreData VS Realm 的对比，可以看看[这篇文章](http://www.iiiyu.com/2016/01/19/CoreData-VS-Realm/)





![](http://upload-images.jianshu.io/upload_images/1194012-dc7c9fa8a40a9e38.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

说到使用 Realm最后的二道门槛，一是如何从其他数据库迁移到Realm，二是Realm数据库的一些限制。

接下来请还在考虑是否使用Realm的同学仔细看清楚，下面是你需要权衡是否要换到Realm数据库的重要标准。（以下描述基于Realm最新版 2.0.2）

### 1.从其他数据库迁移到Realm


![](http://upload-images.jianshu.io/upload_images/1194012-6c9a4cdd9c0b0bcc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



如果从其他数据库迁移到Realm，请看我之前写过的一篇[文章](http://www.jianshu.com/p/d79b2b1bfa72)，简单的提一下蛋疼的问题，由于切换了数据库，需要在未来几个版本都必须维护2套数据库，因为老用户的数据需要慢慢从老数据库迁移到Realm，这个有点蛋疼。迁移数据的那段代码需要“恶心”的存在工程里。但是一旦都迁移完成，之后的路就比较平坦了。

关于Core Data迁移过来没有fetchedResultController的问题，这里提一下。由于使用Realm的话就无法使用Core Data的fetchedResultController，那么如果数据库更新了数据，是不是只能通过reloadData来更新tableview了？目前基本上是的，Realm提供了我们通知机制，目前的Realm支持给realm数据库对象添加通知，这样就可以在数据库写入事务提交后获取到，从而更新UI；详情可以参考[https://realm.io/cn/docs/swift/latest/#notification](https://realm.io/cn/docs/swift/latest/#notification)当然如果仍希望使用NSFetchedResultsController的话，那么推荐使用RBQFetchedResultsController，这是一个替代品，地址是：[https://github.com/Roobiq/RBQFetchedResultsController](https://github.com/Roobiq/RBQFetchedResultsController)目前Realm计划在未来实现类似的效果，具体您可以参见这个PR：[http://github.com/realm/realm-cocoa/issues/687](http://github.com/realm/realm-cocoa/issues/687)。

当然，如果是新的App，还在开发中，可以考虑直接使用Realm，会更爽。

以上是第一道门槛，如果觉得迁移带来的代价还能承受，那么恭喜你，已经踏入Realm一半了。那么还请看第二道“门槛”。

### 2. Realm数据库当前版本的限制

把用户一部分拦在Realm门口的还在这第二道坎，因为这些限制，这些“缺点”，导致App的业务无法使用Realm得到满足，所以最终放弃了Realm。当然，这些问题，有些是可以灵活通过改变表结构解决的，毕竟人是活的（如果真的想用Realm，想些办法，谁也拦不住）





![](http://upload-images.jianshu.io/upload_images/1194012-bf23d93b491a27ce.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


1.类名称的长度最大只能存储 57 个 UTF8 字符。

2.属性名称的长度最大只能支持 63 个 UTF8 字符。

3.NSData以及 NSString属性不能保存超过 16 MB 大小的数据。如果要存储大量的数据，可通过将其分解为16MB 大小的块，或者直接存储在文件系统中，然后将文件路径存储在 Realm 中。如果您的应用试图存储一个大于 16MB 的单一属性，系统将在运行时抛出异常。

4.对字符串进行排序以及不区分大小写查询只支持“基础拉丁字符集”、“拉丁字符补充集”、“拉丁文扩展字符集 A” 以及”拉丁文扩展字符集 B“（UTF-8 的范围在 0~591 之间）。

5.尽管 Realm 文件可以被多个线程同时访问，但是您不能跨线程处理 Realms、Realm 对象、查询和查询结果。（这个其实也不算是个问题，我们在多线程中新建新的Realm对象就可以解决）

6.Realm对象的 Setters & Getters 不能被重载

因为 Realm 在底层数据库中重写了 setters 和 getters 方法，所以您不可以在您的对象上再对其进行重写。一个简单的替代方法就是：创建一个新的 Realm 忽略属性，该属性的访问起可以被重写， 并且可以调用其他的 getter 和 setter 方法。

7.文件大小 & 版本跟踪

一般来说 Realm 数据库比 SQLite 数据库在硬盘上占用的空间更少。如果您的 Realm 文件大小超出了您的想象，这可能是因为您数据库中的 RLMRealm中包含了旧版本数据。
为了使您的数据有相同的显示方式，Realm 只在循环迭代开始的时候才更新数据版本。这意味着，如果您从 Realm 读取了一些数据并进行了在一个锁定的线程中进行长时间的运行，然后在其他线程进行读写 Realm 数据库的话，那么版本将不会被更新，Realm 将保存中间版本的数据，但是这些数据已经没有用了，这导致了文件大小的增长。这部分空间会在下次写入操作时被重复利用。这些操作可以通过调用writeCopyToPath:error:来实现。

解决办法：
通过调用invalidate，来告诉 Realm 您不再需要那些拷贝到 Realm 的数据了。这可以使我们不必跟踪这些对象的中间版本。在下次出现新版本时，再进行版本更新。
您可能在 Realm 使用Grand Central Dispatch时也发现了这个问题。在 dispatch 结束后自动释放调度队列（dispatch queue）时，调度队列（dispatch queue）没有随着程序释放。这造成了直到 
RLMRealm 对象被释放后，Realm 中间版本的数据空间才会被再利用。为了避免这个问题，您应该在 dispatch 队列中，使用一个显式的自动调度队列（dispatch queue）。


8.Realm 没有自动增长属性

Realm 没有线程/进程安全的自动增长属性机制，这在其他数据库中常常用来产生主键。然而，在绝大多数情况下，对于主键来说，我们需要的是一个唯一的、自动生成的值，因此没有必要使用顺序的、连续的、整数的 ID 作为主键。

解决办法：

在这种情况下，一个独一无二的字符串主键通常就能满足需求了。一个常见的模式是将默认的属性值设置为 [[NSUUID UUID] UUIDString]
以产生一个唯一的字符串 ID。
自动增长属性另一种常见的动机是为了维持插入之后的顺序。在某些情况下，这可以通过向某个 RLMArray中添加对象，或者使用 [NSDate date]默认值的createdAt属性。

9.所有的数据模型必须直接继承自RealmObject。这阻碍我们利用数据模型中的任意类型的继承。

这一点也不算问题，我们只要自己在建立一个model就可以解决这个问题。自己建立的model可以自己随意去继承，这个model专门用来接收网络数据，然后把自己的这个model转换成要存储到表里面的model，即RLMObject对象。这样这个问题也可以解决了。


Realm 允许模型能够生成更多的子类，也允许跨模型进行代码复用，但是由于某些 Cocoa 特性使得运行时中丰富的类多态无法使用。以下是可以完成的操作：
- 父类中的类方法，实例方法和属性可以被它的子类所继承
- 子类中可以在方法以及函数中使用父类作为参数

以下是不能完成的：
- 多态类之间的转换（例如子类转换成子类，子类转换成父类，父类转换成子类等）
- 同时对多个类进行检索
- 多类容器 (RLMArray以及 RLMResults)

10.Realm不支持集合类型

这一点也是比较蛋疼。

Realm支持以下的属性类型：BOOL、bool、int、NSInteger、long、long long、float、double、NSString、NSDate、NSData以及 [被特殊类型标记的](https://realm.io/cn/docs/objc/latest/#optional-properties)NSNumber。CGFloat属性的支持被取消了，因为它不具备平台独立性。

这里就是不支持集合，比如说NSArray，NSMutableArray，NSDictionary，NSMutableDictionary，NSSet，NSMutableSet。如果服务器传来的一个字典，key是一个字符串，对应的value就是一个数组，这时候就想存储这个数组就比较困难了。当然Realm里面是有集合的，就是RLMArray，这里面装的都是RLMObject。

所以我们想解决这个问题，就需要把数据里面的东西都取出来，如果是model，就先自己接收一下，然后转换成RLMObject的model，再存储到RLMArray里面去，这样转换一遍，还是可以的做到的。



这里列出了暂时Realm当前办法存在的“缺点”，如果这10点，在自己的App上都能满足业务需求，那么这一道坎也不是问题了。


以上两道砍请仔细衡量清楚，这里还有一篇文章是关于更换数据库的心得体会的，[高速公路换轮胎——为遗留系统替换数据库](http://www.jianshu.com/p/d684693f1d77)考虑更换的同学也可以看看。这两道坎如果真的不适合，过不去，那么请放弃Realm吧！



## 六. Realm 到底是什么？



![](http://upload-images.jianshu.io/upload_images/1194012-b0282fce2c36425b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



大家都知道Sqlite3 是一个移动端上面使用的小型数据库，FMDB是基于Sqlite3进行的一个封装。

那Core Data是数据库么？
Core Data本身并不是数据库，它是一个拥有多种功能的框架，其中一个重要的功能就是把应用程序同数据库之间的交互过程自动化了。有了Core Data框架以后，我们无须编写Objective-C代码，又可以是使用关系型数据库。因为Core Data会在底层自动给我们生成应该最佳优化过的SQL语句。

那么Realm是数据库么？



![](http://upload-images.jianshu.io/upload_images/1194012-c91fecaccbecf0a4.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Realm 不是 ORM，也不基于 SQLite 创建，而是为移动开发者定制的全功能数据库。它可以将原生对象直接映射到Realm的数据库引擎（远不仅是一个键值对存储）中。

Realm 是一个 [MVCC 数据库](https://en.wikipedia.org/wiki/Multiversion_concurrency_control) ，底层是用 C++ 编写的。MVCC 指的是多版本并发控制。

Realm是满足ACID的。原子性（Atomicity）、一致性（Consistency）、隔离性（Isolation）、持久性（Durability）。一个支持事务（Transaction）的数据库，必需要具有这四种特性。Realm都已经满足。


### 1.Realm 采用MVCC的设计思想

MVCC 解决了一个重要的并发问题：在所有的数据库中都有这样的时候，当有人正在写数据库的时候有人又想读取数据库了（例如，不同的线程可以同时读取或者写入同一个数据库）。这会导致数据的不一致性 - 可能当你读取记录的时候一个写操作才部分结束。

有很多的办法可以解决读、写并发的问题，最常见的就是给数据库加锁。在之前的情况下，我们在写数据的时候就会加上一个锁。在写操作完成之前，所有的读操作都会被阻塞。这就是众所周知的读-写锁。这常常都会很慢。Realm采用的是MVCC数据库的优点就展现出来了，速度非常快。

MVCC 在设计上采用了和 Git 一样的源文件管理算法。你可以把 Realm 的内部想象成一个 Git，它也有分支和原子化的提交操作。这意味着你可能工作在许多分支上（数据库的版本），但是你却没有一个完整的数据拷贝。Realm 和真正的 MVCC 数据库还是有些不同的。一个像 Git 的真正的 MVCC 数据库，你可以有成为版本树上 HEAD 的多个候选者。而 Realm 在某个时刻只有一个写操作，而且总是操作最新的版本 - 它不可以在老的版本上工作。


![](http://upload-images.jianshu.io/upload_images/1194012-77d8f83cd4f870a6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



Realm底层是B+树实现的，在Realm团队开源的[realm-core](https://github.com/realm/realm-core)里面可以看到源码，里面有用bpTree，这是一个B+树的实现。B+ 树是一种树数据结构，是一个n叉树，每个节点通常有多个孩子，一棵B+树包含根节点、内部节点和叶子节点。根节点可能是一个叶子节点，也可能是一个包含两个或两个以上孩子节点的节点。


B+ 树通常用于数据库和操作系统的[文件系统](http://baike.baidu.com/view/266589.htm)中。NTFS, ReiserFS, NSS, XFS, JFS, ReFS 和BFS等文件系统都在使用B+树作为元数据索引。B+ 树的特点是能够保持数据稳定有序，其插入与修改拥有较稳定的对数时间复杂度。B+ 树元素自底向上插入。



![](http://upload-images.jianshu.io/upload_images/1194012-b576120711ec7f4b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



Realm会让每一个连接的线程都会有数据在一个特定时刻的快照。这也是为什么能够在上百个线程中做大量的操作并同时访问数据库，却不会发生崩溃的原因。

![](http://upload-images.jianshu.io/upload_images/1194012-9fb904dc362ba9ba.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图很好的展现了Realm的一次写操作流程。这里分3个阶段，阶段一中，V1指向根节点R。在阶段二中，准备写入操作，这个时候会有一个V2节点，指向新的R'，并且新建一个分支出来，A'和C'。相应的右孩子指向原来V1指向的R的右孩子。如果写入操作失败，就丢弃左边这个分支。这样的设计可以保证即使失败，也仅仅只丢失最新数据，而不会破坏整个数据库。如果写入成功，那么把原来的R，A，C节点放入Garbage中，于是就到了第三阶段，写入成功，变成了V2指向根节点。

在这个写入的过程中，第二阶段是最关键的，写入操作并不会改变原有数据，而是新建了一个新的分支。这样就不用加锁，也可以解决数据库的并发问题。

**正是B+树的底层数据结构 + MVCC的设计，保证了Realm的高性能。**

### 2.Realm 采用了 zero-copy 架构

因为 Realm 采用了 zero-copy 架构，这样几乎就没有内存开销。这是因为每一个 Realm 对象直接通过一个本地 long 指针和底层数据库对应，这个指针是数据库中数据的钩子。


通常的传统的数据库操作是这样的，数据存储在磁盘的数据库文件中，我们的查询请求会转换为一系列的SQL语句，创建一个数据库连接。数据库服务器收到请求，通过解析器对SQL语句进行词法和语法语义分析，然后通过查询优化器对SQL语句进行优化，优化完成执行对应的查询，读取磁盘的数据库文件(有索引则先读索引)，读取命中查询的每一行的数据，然后存到内存里（这里有内存消耗）。之后你需要把数据序列化成可在内存里面存储的格式，这意味着比特对齐，这样 CPU 才能处理它们。最后，数据需要转换成语言层面的类型，然后它会以对象的形式返回，比如Objective-C的对象等。

这里就是Realm另外一个很快的原因，Realm的数据库文件是通过memory-mapped，也就是说数据库文件本身是映射到内存(实际上是虚拟内存)中的，Realm访问文件偏移就好比文件已经在内存中一样(这里的内存是指虚拟内存)，它允许文件在没有做反序列化的情况下直接从内存读取，提高了读取效率。Realm 只需要简单地计算偏移来找到文件中的数据，然后从原始访问点返回数据结构的值 。

**正是Realm采用了 zero-copy 架构，几乎没有内存开销，Realm核心文件格式基于memory-mapped，节约了大量的序列化和反序列化的开销，导致了Realm获取对象的速度特别高效。**


### 3. Realm 对象在不同的线程间不能共享

Realm 对象不能在线程间传递的原因就是为了保证隔离性和数据一致性。这样做的目的只有一个，为了速度。

由于Realm是基于零拷贝的，所有对象都在内存里，所以会自动更新。如果允许Realm对象在线程间共享，Realm 会无法确保数据的一致性，因为不同的线程会在不确定的什么时间点同时改变对象的数据。

要想保证多线程能共享对象就是加锁，但是加锁又会导致一个长时间的后台写事务会阻塞 UI 的读事务。不加锁就不能保证数据的一致性，但是可以满足速度的要求。Realm在衡量之后，还是为了速度，做出了不允许线程间共享的妥协。

**正是因为不允许对象在不同的线程间共享，保证了数据的一致性，不加线程锁，保证了Realm的在速度上遥遥领先。**


### 4. 真正的懒加载

大多数数据库趋向于在水平层级存储数据，这也就是为什么你从 SQLite 读取一个属性的时候，你就必须要加载整行的数据。它在文件中是连续存储的。

不同的是，Realm尽可能让 Realm 在垂直层级连续存储属性，你也可以看作是按列存储。

在查询到一组数据后，只有当你真正访问对象的时候才真正加载进来。



### 5. Realm 中的文件


![](http://upload-images.jianshu.io/upload_images/1194012-9543fbc332191bc0.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

先来说说中间的Database File

.realm 文件是memory mapped的，所有的对象都是文件首地址偏移量的一个引用。对象的存储不一定是连续的，但是Array可以保证是连续存储。


.realm执行写操作的时候，有3个指针，一个是\*current top pointer ，一个是 other top pointer ，最后一个是 switch bit\*。

switch bit\* 标示着top pointer是否已经被使用过。如果被使用过了，代表着数据库已经是可读的。

the top pointer优先更新，紧接着是the switch bit更新。因为即使写入失败了，虽然丢失了所有数据，但是这样能保证数据库依旧是可读的。

再来说说 .lock file。

.lock文件中会包含 the shared group 的metadata。这个文件承担着允许多线程访问相同的Realm对象的职责。

最后说说Commit logs history

这个文件会用来更新索引indexes，会用来同步。里面主要维护了3个小文件，2个是数据相关的，1个是操作management的。


## 总结

经过上面的分析之后，深深的感受到Realm就是为速度而生的！在保证了ACID的要求下，很多设计都是以速度为主。当然，Realm 最核心的理念就是对象驱动，这是 Realm 的核心原则。Realm 本质上是一个嵌入式数据库，但是它也是看待数据的另一种方式。它用另一种角度来重新看待移动应用中的模型和业务逻辑。

Realm还是跨平台的，多个平台都使用相同的数据库，是多么好的一件事情呀。相信使用Realm作为App数据库的开发者会越来越多。


参考链接  

[Realm官网](https://realm.io/)  
[Realm官方文档](https://realm.io/docs/objc/latest/api/index.html)  
[Realm GitHub](https://github.com/realm)  