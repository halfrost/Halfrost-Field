<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-fdee34cd97308fac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface 

Since I’ve been using Realm in a recent project, I’d like to summarize and share some of the insights I’ve gained from hands-on practice.

Realm is an open-source cross-platform mobile database for iOS (also applicable to Swift & Objective-C) and Android, created by a startup team incubated by Y Combinator. The latest version is currently Realm 2.0.2, and the supported platforms include Java, Objective-C, Swift, React Native, and Xamarin.

Realm’s official website lists many advantages, but in my opinion the three most compelling reasons to choose Realm are:

1. **Cross-platform**: Many applications now need to be developed for both iOS and Android at the same time. If both platforms can use the same database, you no longer need to worry about differences in the internal data architecture. With the APIs provided by Realm, the data persistence layer can be transferred between the two platforms without any platform-specific differences.

2. **Simple and easy to use**: The redundant and complicated knowledge and code required by Core Data and SQLite are enough to scare off most beginners. Switching to Realm can greatly reduce the learning curve and let you immediately grasp local storage. Without exaggeration, after reading through the latest official documentation once, you’ll be fully ready to start development.

3. **Visualization**: Realm also provides a lightweight database inspection tool. You can download “Realm Browser” from the Mac App Store. Developers can inspect the contents of the database and perform simple insert and delete operations. After all, in many cases, the reason developers use a database is to provide some kind of so-called “knowledge base.”

![](http://upload-images.jianshu.io/upload_images/1194012-96eb173768167645.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  
The “Realm Browser” tool is extremely useful for debugging Realm databases. Highly recommended.

If you are debugging with the simulator, you can use
```objectivec

[RLMRealmConfiguration defaultConfiguration].fileURL

```
Print the Realm database path, then in Finder press ⌘⇧G to jump to that path. Open the corresponding `.realm` file with Realm Browser, and you’ll be able to view the data.

If you are debugging on a physical device, go to “Xcode -> Window -> Devices (⌘⇧2)”, then find the corresponding device and project, click Download Container, export the `xcappdata` file, choose Show Package Contents, go to AppData->Documents, and open the `.realm` file with Realm Browser.


Realm has been used in production commercial products since 2012. After four years of real-world use, it has gradually become stable.


## Table of Contents
- 1.Realm Installation
- 2.Relevant Terminology in Realm
- 3.Getting Started with Realm — How to Use It
- 4.Some Issues to Be Aware of When Using Realm
- 5.“Giving Up” on Realm — Advantages and Disadvantages
- 6.What Exactly Is Realm?
- 7.Summary


## I. Realm Installation

Basic requirements for building apps with Realm:
1. iOS 7 and later, macOS 10.9 and later. In addition, Realm supports all versions of tvOS and watchOS.
2. Xcode 7.3 or later is required.

**Note**: If this is a pure Objective-C project, install the Objective-C version of Realm. If it is a pure Swift project, install the Swift version of Realm. If it is a mixed-language project, install the Objective-C version of Realm, and also compile the [Swift/RLMSupport.swift
](https://github.com/realm/realm-cocoa/blob/master/Realm/Swift/RLMSupport.swift) file into the project.

The RLMSupport.swift file introduces Sequence conformance for the collection types in the Objective-C version of Realm, and re-exposes some Objective-C methods that cannot be accessed natively from Swift, such as variadic arguments. For more details, see the [official documentation](https://realm.io/docs/objc/latest/#getting-started).


There are four installation methods:

### I. Dynamic Framework
**Note: Dynamic frameworks are not compatible with iOS 7. If you need to support iOS 7, see “Static Framework”.**
1. Download the [latest Realm release](https://static.realm.io/downloads/objc/realm-objc-2.0.2.zip) and unzip it;
2. Go to the “General” settings of the Xcode project, and from ios/dynamic/, osx/, tvos/
or watchos/, drag ’Realm.framework’ into the “Embedded Binaries” section. Make sure **Copy items if needed** is selected, then click **Finish**;
3. In the unit test Target’s “Build Settings”, add the parent directory of Realm.framework to “Framework Search Paths”;
4. If you want to use Swift to load Realm, drag the Swift/RLMSupport.swift
file into the Xcode project’s file navigator and select **Copy items if needed**;
5. If you use Realm in an iOS, watchOS, or tvOS project, create a new “Run Script Phase” in your app target’s “Build Phases”, and
```vim

bash "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Realm.framework/strip-frameworks.sh"

```
Copy this script into the text box. Because it works around an [App Store submission bug](http://www.openradar.me/radar?id=6409498411401216), this step is required when packaging a binary release build for generic devices.

### II. CocoaPods

![](http://upload-images.jianshu.io/upload_images/1194012-da6cec98554a0fbf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Add `pod 'Realm'` to the project’s Podfile, then run `pod install` in the terminal.

### III. Carthage
1. Add github "realm/realm-cocoa" to Carthage and run `carthage update`. To change the Swift toolchain used to build the project, specify the appropriate toolchain with the `--toolchain` parameter. The `--no-use-binaries` parameter is also required to prevent Carthage from downloading prebuilt Swift 3.0 binary packages. For example:
```vim

carthage update --toolchain com.apple.dt.toolchain.Swift_2_3 --no-use-binaries

```
2. From the platform-specific folder under the `Carthage/Build/` directory, drag `Realm.framework` into the “Linked Frameworks and Libraries” section of your Xcode project’s “General” settings;

3. **iOS/tvOS/watchOS:** In the “Build Phases” settings tab of your app target, click the “+” button and select “New Run Script Phase”. In the newly created Run Script, enter:
```vim

/usr/local/bin/carthage copy-frameworks

```
Add the framework paths you want to use under “Input Files”, for example:
```vim

$(SRCROOT)/Carthage/Build/iOS/Realm.framework

```
Because you need to work around the [App Store submission bug](http://www.openradar.me/radar?id=6409498411401216), this step is required when packaging a binary release for universal devices.

### IV. Static Framework (iOS only)

1. Download the [latest version of Realm](https://static.realm.io/downloads/objc/realm-objc-2.0.2.zip) and unzip it. Drag Realm.framework from the ios/static/ folder into the file navigator in your Xcode project. Make sure **Copy items if needed** is selected, then click **Finish**;
2. Select your project in Xcode’s file navigator, then select your app target and go to the ** Build Phases** tab. Under **Link Binary with Libraries**, click the + button and add **libc++.dylib**;

## II. Realm Terminology

To better understand how to use Realm, let’s first introduce the relevant terminology.

**RLMRealm**: Realm is the core of the framework and the access point through which we build and use the database, much like Core Data’s managed object context. For simplicity, Realm provides a convenient defaultRealm( ) constructor method.

**RLMObject**: This is the custom Realm data model we define. Creating a data model corresponds to defining the database schema. To create a data model, we simply subclass RLMObject and design the properties we want to store.

**Relationships**: By simply declaring a property of type RLMObject in a data model, we can create a “one-to-many” object relationship. Similarly, we can also create “many-to-one” and “many-to-many” relationships.

**Write Transactions**: All operations in the database, such as creating, editing, or deleting objects, must be performed within a **transaction**. A “transaction” refers to a block of code inside a write closure.

**Queries**: To retrieve information from the database, we use query operations. The simplest form of retrieval is sending a query message to the Realm( ) database. If more complex data retrieval is required, you can also use predicates, compound queries, result sorting, and other operations.

**RLMResults**: This is the class returned after executing any query request, and it contains a collection of **RLMObject** objects. RLMResults is similar to NSArray: we can access it using subscript syntax and determine relationships between its elements. In addition, it provides many more powerful capabilities, including sorting, searching, and more.


## III. Getting Started with Realm — How to Use It

Because Realm’s API is extremely developer-friendly and easy to understand, this section walks through the features you’ll typically need in the order they come up during everyday development.

### 1. Create a Database
```objectivec

- (void)creatDataBaseWithName:(NSString *)databaseName
{
    NSArray *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [docPath objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:databaseName];
    NSLog(@"Database directory = %@",filePath);

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.fileURL = [NSURL URLWithString:filePath];
    config.objectClasses = @[MyClass.class, MyOtherClass.class];
    config.readOnly = NO;
    int currentVersion = 1.0;
    config.schemaVersion = currentVersion;
    
    config.migrationBlock = ^(RLMMigration *migration , uint64_t oldSchemaVersion) {
       // This is the block for data migration
        if (oldSchemaVersion < currentVersion) {
        }
    };
    
    [RLMRealmConfiguration setDefaultConfiguration:config];

}

```
Creating a database mainly involves configuring `RLMRealmConfiguration`, setting the database name and storage location. Concatenate the path and database name into a string, then assign it to `fileURL`.

The `objectClasses` property is used to restrict which classes can be stored in a specified Realm database. For example, if two teams are responsible for developing different parts of your app and both use Realm databases within the app, you probably do not want to coordinate data migrations between them. You can restrict classes by setting the `objectClasses` property of `RLMRealmConfiguration`. In general, `objectClasses` does not need to be set.

`readOnly` controls whether the database is read-only.

There is also a very special type of database: an in-memory database.

Normally, a Realm database is stored on disk, but you can create a database that runs entirely in memory by setting `inMemoryIdentifier` instead of the `fileURL` property in `RLMRealmConfiguration`.
```objectivec

RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];config.inMemoryIdentifier = @"MyInMemoryRealm";RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];

```
In-memory databases do not persist data across program runs. However, this does not interfere with Realm’s other features, including queries, relationships, and thread safety.

If you need a flexible way to read and write data without storing it persistently, you can use an in-memory database. (The performance of in-memory databases vs. class properties has not been tested. I don’t expect a significant difference, so the use cases for in-memory databases may be limited.)

Things to keep in mind when using an in-memory database:

1. An in-memory database creates multiple files in the temporary folder to coordinate tasks such as cross-process notifications. In practice, no data is written to these files unless the operating system, due to memory pressure, ~~needs to clear extra space on disk.~~ writes the data in memory to files. (Thanks to @酷酷的哀殿 for pointing this out.)


2. If an in-memory Realm database instance is no longer referenced, all of its data will be released. Therefore, you must keep a strong reference to the in-memory Realm database throughout the application lifecycle to avoid data loss.

### 2. Creating Tables

Realm data models are defined based on standard Objective‑C classes, with properties used to define the details of the model.

You only need to inherit from RLMObject or an existing model class to create a new Realm data model object. In the database, this corresponds to a table.
```objectivec

#import <Realm/Realm.h>

@interface RLMUser : RLMObject

@property NSString       *accid;
//User registration ID
@property NSInteger      custId;
//Name
@property NSString       *custName;
//Large avatar image URL
@property NSString       *avatarBig;
@property RLMArray<Car> *cars;

RLM_ARRAY_TYPE(RLMUser) // Define RLMArray<RLMUser>


@interface Car : RLMObject
@property NSString *carName;
@property RLMUser *owner;
@end

RLM_ARRAY_TYPE(Car) // Define RLMArray<Car>

@end

```
**Note**: The official RLMObject guidance recommends not adding Objective-C property attributes (such as nonatomic, atomic, strong, copy, weak, and so on). If they are set, these attributes will remain in effect until the RLMObject is written to the Realm database.


The RLM_ARRAY_TYPE macro creates a protocol, allowing the use of the RLMArray<Car> syntax. If this macro is not placed at the bottom of the model interface, you may need to forward-declare the model class.

Relationships in RLMObject

1. To-One Relationship

For many-to-one or one-to-one relationships, you only need to declare a property whose type is an RLMObject subclass, as in the code example above: @property RLMUser *owner;

2. To-Many Relationship
You can define a to-many relationship with a property of type RLMArray. As in the code example above: @property RLMArray<Car> *cars;

3. Inverse Relationship

Links are unidirectional. Therefore, if the to-many relationship property RLMUser.cars links to a Car instance, and that instance’s to-one relationship property Car.owner links back to the corresponding RLMUser instance, these links are still actually independent of each other.
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
This can be compared to the “arrows” in the `xcdatamodel` file in Core Data.


![](http://upload-images.jianshu.io/upload_images/1194012-c170321185c77092.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```objectivec

@implementation Book

// Primary key
+ (NSString *)primaryKey {
    return @"ID";
}

// Set default property values
+ (NSDictionary *)defaultPropertyValues{
    return @{@"carName":@"test" };
}

// Set ignored properties, i.e., not stored in the Realm database
+ (NSArray<NSString *> *)ignoredProperties {
    return @[@"ID"];
}

// Generally, if a property is nil, Realm will throw an exception, but if this method is implemented, only name being nil will throw an exception; that is, the cover property can now be nil
+ (NSArray *)requiredProperties {
    return @[@"name"];
}

// Set indexes to speed up searches
+ (NSArray *)indexedProperties {
    return @[@"ID"];
}
@end

```
You can also configure a primary key (`primaryKey`), default values (`defaultPropertyValues`), ignored properties (`ignoredProperties`), required properties (`requiredProperties`), and indexed properties (`indexedProperties`) for an `RLMObject`. The primary key and indexes are the most useful.

### 3. Storing Data


Create a new object
```objectivec

// (1) Create a Car object, then set its properties
Car *car = [[Car alloc] init];
car.carName = @"Lamborghini";

// (2) Create a Car object from a dictionary
Car *myOtherCar = [[Car alloc] initWithValue:@{@"name" : @"Rolls-Royce"}];

// (3) Create a dog object from an array
Car *myThirdcar = [[Car alloc] initWithValue:@[@"BMW"]];

```
**Note: All required properties must be assigned before the object is added to Realm**


## 4. Add


![](http://upload-images.jianshu.io/upload_images/1194012-ca53417c1d55ab5d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```objectivec


[realm beginWriteTransaction];
[realm addObject:Car];
[realm commitWriteTransaction];

```
**Note that if there are multiple write operations in the process, a single write operation will block the other write operations and will also lock the current thread on which that operation is running.**

This Realm behavior is similar to other persistence solutions. We recommend following the usual best practice for this approach: move write operations to a separate thread for execution.

The official recommendation is:

Because Realm uses an MVCC architecture, **read operations are not affected by an in-progress write transaction**. Unless you need to immediately use multiple threads to perform write operations concurrently, you should use batched write transactions rather than many small write transactions.
```objectivec

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm addObject: Car];
        }];
    });

```
The code above processes write transactions in a child thread.


### 5. Delete


![](http://upload-images.jianshu.io/upload_images/1194012-c41304bc132249ca.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```objectivec

[realm beginWriteTransaction];
// Delete a single record
[realm deleteObject:Car];
// Delete multiple records
[realm deleteObjects:CarResult];
// Delete all records
[realm deleteAllObjects];

[realm commitWriteTransaction];
```

### 6. Modify


![](http://upload-images.jianshu.io/upload_images/1194012-ac4a130ece033e65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


When there is no primary key, you need to query first, then modify the data.
When there is a primary key, the following APIs are very useful.
```objectivec

[realm addOrUpdateObject:Car];

[Car createOrUpdateInRealm:realm withValue:@{@"id": @1, @"price": @9000.0f}];

```
addOrUpdateObject first checks whether there is an existing record with the same primary key as the passed-in Car. If there is, it updates that record. Note that **addOrUpdateObject is not an incremental update**: all values must be provided. If any values are null, they will overwrite the existing values, which can lead to data loss.

createOrUpdateInRealm：withValue：is an incremental update method. You pass in a dictionary afterward; the prerequisite for using this method is that a primary key exists. The method first checks whether there is a record whose primary key matches the primary key passed in via the dictionary. If there is, it updates only the subset of fields included in the dictionary. If not, it creates a new record.


### 7. Query


![](http://upload-images.jianshu.io/upload_images/1194012-78425d8b2748e9e8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In Realm, all queries (including queries and property access) are lazily loaded. The corresponding data is read only when a property is accessed.

Query results are not copies of the data: modifying query results (within a write transaction) directly modifies the data on disk. Similarly, you can traverse the object graph directly through the RLMObject objects contained in RLMResults. Unless the query results are used, execution of the retrieval is deferred. This means that chaining several different temporary {RLMResults} instances to sort and match data does not perform extra work, such as processing intermediate states.
Once the retrieval has executed, or once a notification block has been added, RLMResults will stay up to date at all times, receiving any changes that may have been made in Realm by retrieval operations executed on a background thread.
```objectivec

// Query all cars from the default database
RLMResults<Car *> *cars = [Car allObjects];

// Query using an assertion string
RLMResults<Dog *> *tanDogs = [Dog objectsWhere:@"color = 'tan' AND name BEGINSWITH 'Big'"];

// Query using NSPredicate
NSPredicate *pred = [NSPredicate predicateWithFormat:@"color = %@ AND name BEGINSWITH %@",
                     @"tan", @"Big"];
RLMResults *results = [Dog objectsWithPredicate:pred];

// Sort tan dogs whose names start with “Big”
RLMResults<Dog *> *sortedDogs = [[Dog objectsWhere:@"color = 'tan' AND name BEGINSWITH 'Big'"] sortedResultsUsingProperty:@"name" ascending:YES];


```
Realm also supports chained queries

One feature of the Realm query engine is that it can execute chained queries with very low transaction overhead, without creating a separate database server access for each successful query as traditional databases do.
```objectivec

RLMResults<Car *> *Cars = [Car objectsWhere:@"color = blue"];
RLMResults<Car *> *CarsWithBNames = [Cars objectsWhere:@"name BEGINSWITH 'B'"];

```

### 8. Other Related Features

1. Supports KVC and KVO

RLMObject, RLMResult, and RLMArray
all conform to the Key-Value Coding (KVC) mechanism. This approach is most useful when you can only determine at runtime which property needs to be updated.
Applying KVC to collections is an excellent way to update large numbers of objects, so you do not have to repeatedly iterate over the collection and create an accessor for each item.
```objectivec

RLMResults<Person *> *persons = [Person allObjects];
[[RLMRealm defaultRealm] transactionWithBlock:^{ 
    [[persons firstObject] setValue:@YES forKeyPath:@"isFirst"]; // Set each person's planet property to "Earth" 
    [persons setValue:@"Earth" forKeyPath:@"planet"];
}];

```
Most properties of Realm objects are KVO-compliant. All persisted (non-ignored) properties of `RLMObject` subclasses are KVO-compliant, and the invalidated properties on `RLMObject` and `RLMArray` are KVO-compliant as well (however, `RLMLinkingObjects` properties cannot be observed using KVO).


2.Supports database encryption
```objectivec

// Generate a random key
NSMutableData *key = [NSMutableData dataWithLength:64];
SecRandomCopyBytes(kSecRandomDefault, key.length, (uint8_t *)key.mutableBytes);

// Open the encrypted file
RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
config.encryptionKey = key;
NSError *error = nil;
RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:&error];
if (!realm) {
    // If the key is incorrect, `error` will indicate that the database is inaccessible
    NSLog(@"Error opening realm: %@", error);
}
```
Realm supports encrypting database files with AES-256+SHA2 using a 64-bit key when creating a Realm database. This means all data on disk is encrypted and decrypted with AES-256 and verified with SHA-2 HMAC. Each time you obtain a Realm instance, you must provide the same key.

However, an encrypted Realm incurs only a small amount of additional overhead (typically at most about 10% slower than usual).


3.Notifications
```objectivec

// Get Realm notifications
token = [realm addNotificationBlock:^(NSString *notification, RLMRealm * realm) {
     [myViewController updateUI];
}];

[token stop];

// Remove notification
[realm removeNotification:self.token];

```
After each write transaction is committed, a Realm instance sends notifications to Realm instances on other threads. In general, if a controller wants to keep receiving these notifications, it needs to declare a property and hold the notification strongly.
```objectivec

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Observe RLMResults notifications
    __weak typeof(self) weakSelf = self;
    self.notificationToken = [[Person objectsWhere:@"age > 5"] addNotificationBlock:^(RLMResults<Person *> *results, RLMCollectionChange *change, NSError *error) {
        if (error) {
            NSLog(@"Failed to open Realm on background worker: %@", error);
            return;
        }
        
        UITableView *tableView = weakSelf.tableView;
        // On the initial query run, the change info will be nil
        if (!changes) {
            [tableView reloadData];
            return;
        }
        
        // The query results changed, so apply them to the UITableView
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
We can also perform more fine-grained notifications, which can be achieved with collection notifications.

Collection notifications are triggered asynchronously. They are first triggered when the initial results become available, and then triggered again whenever a write transaction changes all objects in the collection or any individual object in it. These changes can be accessed through the RLMCollectionChange parameter passed to the notification closure. This object contains index information affected by the deletions, insertions, and modifications states.

For RLMResults, RLMArray, RLMLinkingObjects, and collections derived from RLMResults, collection notifications will likewise trigger state changes when objects in the relationship are added or removed.

4.Database Migration

This is one of Realm’s strengths: easy migration.

Compared with Core Data migrations, it is much more convenient. For an iOS Core Data migration guide, see this [article](http://www.jianshu.com/p/b3b764fc5191).

There generally should not be many issues with CRUD operations for database storage. The more painful part is usually data migration. During version iteration, tables may be added or deleted, or table schemas may change. If the new version does not perform data migration, users upgrading to the new version may very likely encounter a crash. Compared with the relatively complex migration process in Core Data, Realm migration is really simple.

1.Adding or deleting tables does not require migration in Realm.
2.Adding or deleting fields does not require migration in Realm. Realm automatically detects newly added properties and properties that need to be removed, then updates the on-disk database schema automatically.

Here is an official example of data migration:
```objectivec

RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
config.schemaVersion = 2;
config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion)
{
    // enumerateObjects:block: Iterates over every “Person” object stored in the Realm file
    [migration enumerateObjects:Person.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        // Add the “fullName” property only when the Realm database schema version is 0
        if (oldSchemaVersion < 1) {
            newObject[@"fullName"] = [NSString stringWithFormat:@"%@ %@", oldObject[@"firstName"], oldObject[@"lastName"]];
        }
        // Add the “email” property only when the Realm database schema version is 0 or 1
        if (oldSchemaVersion < 2) {
            newObject[@"email"] = @"";
        }
       // Rename the property
       if (oldSchemaVersion < 3) { // The rename should be done outside the call to `enumerateObjects:`
            [migration renamePropertyForClass:Person.className oldName:@"yearsSinceBirth" newName:@"age"]; }
    }];
};
[RLMRealmConfiguration setDefaultConfiguration:config];
// Now that we have updated the schema version and provided a migration block, opening an old Realm database will automatically perform this migration and then be accessed successfully
[RLMRealm defaultRealm];


```
There are three types of migration approaches in the block: the first is an example of merging fields, the second is an example of adding a new field, and the third is an example of renaming an existing field.


## IV. Some Issues You May Need to Be Aware of When Using Realm


![](http://upload-images.jianshu.io/upload_images/1194012-efc4101042d99c8f.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From when I first started learning Realm from scratch to becoming proficient with it, the only real pitfall I encountered was multithreading. This shows how developer-friendly Realm’s API documentation is. Although there are not many pitfalls, there are still a few things worth noting.

### 1. When accessing the database across threads, you must create a new Realm object
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
If the program crashes with the error above, it is because when you access Realm data, the thread that owns the Realm object you are using is different from the current thread.

The solution is to obtain the latest Realm again on the current thread.


### 2. Wrapping a global Realm singleton yourself is not particularly useful

This was also a misconception caused by my previous lack of understanding of Realm’s multithreading model.

Many developers probably wrap Core Data, Sqlite3, or FMDB in a Helper-like singleton. So I did the same here: after creating the Realm database, I held a Realm object strongly in a singleton. Then, for subsequent access, I only needed to read the Realm object held by that singleton to get the database.

The idea is fine, but the same Realm object does not support cross-thread operations on the Realm database.

Realm makes concurrent execution very easy by ensuring that each thread always has a snapshot of the Realm. You can have any number of threads accessing the same Realm file at the same time, and because each thread has its corresponding snapshot, the threads will never interfere with each other. One thing to note is that you must not let multiple threads hold the same instance of a Realm object. If multiple threads need to access the same object, they should each obtain the instance they need separately; otherwise, changes made on one thread could cause other threads to see incomplete or inconsistent data.

In fact, `RLMRealm *realm = [RLMRealm defaultRealm];` obtains an instance of the current Realm object; its implementation is essentially retrieving a singleton. So each time we are in a background thread, we should not read the Realm instance held by our own wrapper. Just call this system-provided method directly, which ensures access will not fail.

### 3. `transactionWithBlock` is already inside a write transaction; transactions cannot be nested
```objectivec

[realm transactionWithBlock:^{
                [self.realm beginWriteTransaction];
                [self convertToRLMUserWith:bhUser To:[self convertToRLMUserWith:bhUser To:nil]];
                [self.realm commitWriteTransaction];
            }];

```
`transactionWithBlock` is already within a write transaction. If you call `commitWriteTransaction` again inside the block, an error will occur; write transactions cannot be nested.

The error message is as follows:
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

### 4. It is recommended that every model define a primary key, making add and update operations easier

If a primary key can be defined, define one whenever possible. This makes it easier to update data: we can conveniently call the `addOrUpdateObject:` or `createOrUpdateInRealm:withValue:` methods to perform updates. This eliminates the need to first query the data by primary key and then update it. With a primary key, these two steps can be completed in a single operation.


### 5. Queries also cannot be performed across threads
```objectivec


RLMResults * results = [self selectUserWithAccid:bhUser.accid];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm addOrUpdateObject:results[0]];
        }];
    });

```
Because the query is performed outside the child thread, it will also fail across threads. The error message is as follows:
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

## V. Realm “Abandonment” — Pros and Cons


Realm’s advantages are already covered extensively on the official website, and the three advantages that impressed me most were also mentioned at the beginning of this article.

For a comparison of CoreData vs Realm, you can read [this article](http://www.iiiyu.com/2016/01/19/CoreData-VS-Realm/).


![](http://upload-images.jianshu.io/upload_images/1194012-dc7c9fa8a40a9e38.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

When it comes to the final two barriers to adopting Realm, one is how to migrate from other databases to Realm, and the other is the set of limitations in the Realm database.

If you are still considering whether to use Realm, please read the following carefully. These are important criteria you need to weigh when deciding whether to switch to Realm. (The following is based on the latest Realm version at the time, 2.0.2.)

### 1.Migrating from other databases to Realm


![](http://upload-images.jianshu.io/upload_images/1194012-6c9a4cdd9c0b0bcc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


If you are migrating from another database to Realm, please read an [article](http://www.jianshu.com/p/d79b2b1bfa72) I wrote earlier. To briefly mention the painful part: because the database has been switched, you will need to maintain two sets of databases for the next several versions, since existing users’ data must be gradually migrated from the old database to Realm. This is somewhat painful. The code that migrates the data has to “ugly up” the project for a while. But once the migration is complete, the road ahead becomes much smoother.

Regarding the lack of `fetchedResultController` when migrating from Core Data, I’ll mention it here. If you use Realm, you can no longer use Core Data’s `fetchedResultController`. So if the database updates data, does that mean you can only update the table view via `reloadData`? For now, basically yes. Realm provides a notification mechanism. The current version of Realm supports adding notifications to Realm database objects, so you can receive them after a database write transaction is committed and then update the UI. For details, see [https://realm.io/cn/docs/swift/latest/#notification](https://realm.io/cn/docs/swift/latest/#notification). Of course, if you still want to use `NSFetchedResultsController`, I recommend `RBQFetchedResultsController`, which is a replacement. Its address is: [https://github.com/Roobiq/RBQFetchedResultsController](https://github.com/Roobiq/RBQFetchedResultsController). Realm currently plans to implement similar behavior in the future. For details, see this PR: [http://github.com/realm/realm-cocoa/issues/687](http://github.com/realm/realm-cocoa/issues/687).

Of course, if this is a new app that is still under development, you can consider using Realm directly. It will be much more enjoyable.

That is the first barrier. If you think the cost of migration is acceptable, congratulations—you are already halfway into Realm. Now please look at the second “barrier.”

### 2. Limitations of the current Realm database version

What keeps some users outside Realm’s door is still this second barrier. Because of these limitations—these “drawbacks”—an app’s business requirements may not be satisfiable with Realm, so the team ultimately gives up on Realm. Of course, some of these issues can be solved flexibly by changing the table structure. After all, people are adaptable (if you really want to use Realm, you can always find a way—no one can stop you).


![](http://upload-images.jianshu.io/upload_images/1194012-bf23d93b491a27ce.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


1.Class names can store at most 57 UTF-8 characters.

2.Property names can support at most 63 UTF-8 characters.

3.`NSData` and `NSString` properties cannot store data larger than 16 MB. If you need to store large amounts of data, you can split it into 16 MB chunks, or store it directly in the file system and then store the file path in Realm. If your app tries to store a single property larger than 16 MB, the system will throw an exception at runtime.

4.Sorting strings and case-insensitive queries only support the “Basic Latin,” “Latin-1 Supplement,” “Latin Extended-A,” and “Latin Extended-B” character sets (UTF-8 range 0–591).

5.Although Realm files can be accessed by multiple threads simultaneously, you cannot pass Realms, Realm objects, queries, or query results across threads. (This is not really a problem; creating a new Realm object in each thread solves it.)

6.Setters & Getters of Realm objects cannot be overridden

Because Realm overrides setter and getter methods in the underlying database, you cannot override them again on your objects. A simple alternative is to create a new Realm-ignored property whose accessor can be overridden and can call other getter and setter methods.

7.File size & version tracking

Generally speaking, Realm databases occupy less disk space than SQLite databases. If your Realm file size is larger than expected, it may be because the `RLMRealm` in your database contains data from old versions.
To make your data appear consistent, Realm only updates the data version at the beginning of a run loop iteration. This means that if you read some data from Realm and then perform a long-running operation on a locked thread, while other threads read and write the Realm database, the version will not be updated. Realm will retain intermediate versions of the data, even though that data is no longer useful, causing the file size to grow. This space will be reused on the next write operation. These operations can be implemented by calling `writeCopyToPath:error:`.

Solution:
Call `invalidate` to tell Realm that you no longer need those copies of data in Realm. This allows us to avoid tracking intermediate versions of those objects. The version will be updated again the next time a new version appears.
You may also have encountered this issue when using Realm with Grand Central Dispatch. After dispatch finishes, when the dispatch queue is automatically released, the dispatch queue is not released along with the program. This causes the space occupied by Realm’s intermediate-version data to be reused only after the 
`RLMRealm` object is released. To avoid this problem, you should use an explicit autorelease pool in the dispatch queue.


8.Realm has no auto-increment properties

Realm has no thread-/process-safe auto-increment property mechanism, which is often used in other databases to generate primary keys. However, in most cases, what we need for a primary key is a unique, automatically generated value, so there is no need to use sequential, contiguous integer IDs as primary keys.

Solution:

In this case, a unique string primary key usually satisfies the requirement. A common pattern is to set the default property value to `[[NSUUID UUID] UUIDString]`
to generate a unique string ID.
Another common motivation for auto-increment properties is to maintain insertion order. In some cases, this can be achieved by adding objects to an `RLMArray`, or by using a `createdAt` property with a default value of `[NSDate date]`.

9.All data models must directly inherit from `RealmObject`. This prevents us from leveraging arbitrary inheritance in data models.

This is not really a problem either. We can solve it by creating our own model. The model we create can inherit however we want. This model is used specifically to receive network data, and then we convert our own model into the model that needs to be stored in the table, namely an `RLMObject` object. This also solves the problem.


Realm allows models to generate more subclasses and supports code reuse across models, but certain Cocoa features prevent rich class polymorphism at runtime. The following operations are possible:
- Class methods, instance methods, and properties in a parent class can be inherited by its subclasses
- A subclass can use the parent class as a parameter in methods and functions

The following are not possible:
- Casting between polymorphic classes (for example, subclass to subclass, subclass to parent class, parent class to subclass, and so on)
- Querying multiple classes at the same time
- Multi-class containers (`RLMArray` and `RLMResults`)

10.Realm does not support collection types

This is also relatively painful.

Realm supports the following property types: `BOOL`, `bool`, `int`, `NSInteger`, `long`, `long long`, `float`, `double`, `NSString`, `NSDate`, `NSData`, and `NSNumber` [marked with a special type](https://realm.io/cn/docs/objc/latest/#optional-properties). Support for `CGFloat` properties was removed because it is not platform-independent.

The issue here is that collections are not supported, such as `NSArray`, `NSMutableArray`, `NSDictionary`, `NSMutableDictionary`, `NSSet`, and `NSMutableSet`. If the server sends a dictionary whose key is a string and whose corresponding value is an array, storing that array becomes difficult. Of course, Realm does have collections, namely `RLMArray`, but it contains `RLMObject` instances.

So if we want to solve this problem, we need to extract everything from the data. If it is a model, first receive it with our own model, then convert it into an `RLMObject` model, and finally store it in an `RLMArray`. With this conversion step, it is still achievable.


The temporary “drawbacks” that currently exist in Realm are listed here. If these 10 points can all satisfy the business requirements of your own app, then this barrier is not a problem either.


Please carefully evaluate the two barriers above. Here is another article about lessons learned from replacing a database: [Changing tires on the highway — replacing the database of a legacy system](http://www.jianshu.com/p/d684693f1d77). Those considering a replacement can also take a look. If these two barriers really are not suitable for you and cannot be overcome, then give up on Realm!


## VI. What exactly is Realm?


![](http://upload-images.jianshu.io/upload_images/1194012-b0282fce2c36425b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Everyone knows that Sqlite3 is a small database used on mobile devices, and FMDB is a wrapper built on top of Sqlite3.

So is Core Data a database?
Core Data itself is not a database. It is a framework with multiple capabilities, one important capability being that it automates the interaction between an application and a database. With the Core Data framework, we can use a relational database without writing Objective-C code, because Core Data automatically generates what should be optimally optimized SQL statements for us under the hood.

So is Realm a database?


![](http://upload-images.jianshu.io/upload_images/1194012-c91fecaccbecf0a4.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Realm is not an ORM, nor is it built on SQLite. It is a full-featured database customized for mobile developers. It can directly map native objects into Realm’s database engine (far more than just a key-value store).

Realm is an [MVCC database](https://en.wikipedia.org/wiki/Multiversion_concurrency_control), with its underlying implementation written in C++. MVCC stands for multiversion concurrency control.

Realm satisfies ACID: Atomicity, Consistency, Isolation, and Durability. A database that supports transactions must have these four properties. Realm satisfies all of them.


### 1.Realm adopts the MVCC design philosophy

MVCC solves an important concurrency problem: in every database, there are moments when someone is writing to the database while someone else wants to read from it (for example, different threads may read from or write to the same database at the same time). This can lead to data inconsistency—for example, a write operation may have only partially completed when you read a record.

There are many ways to solve read/write concurrency problems. The most common is to lock the database. In the previous scenario, we would add a lock while writing data. Before the write operation completes, all read operations are blocked. This is the well-known read-write lock, and it is often slow. This is where the advantage of Realm’s MVCC database design becomes apparent: it is very fast.

MVCC uses a source-file management algorithm similar to Git’s design. You can imagine Realm’s internals as a Git-like system, with branches and atomic commit operations. This means you may be working on many branches (versions of the database), but you do not have a complete copy of the data. Realm is still somewhat different from a true MVCC database. In a true MVCC database like Git, you can have multiple candidates to become `HEAD` of the version tree. Realm, however, has only one write operation at any given moment, and it always operates on the latest version—it cannot work on an older version.


![](http://upload-images.jianshu.io/upload_images/1194012-77d8f83cd4f870a6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Realm’s underlying implementation is based on B+ trees. In the Realm team’s open-source [realm-core](https://github.com/realm/realm-core), you can view the source code, where `bpTree` is used; this is an implementation of a B+ tree. A B+ tree is a tree data structure—an n-ary tree—where each node typically has multiple children. A B+ tree contains a root node, internal nodes, and leaf nodes. The root node may be a leaf node, or it may be a node containing two or more child nodes.


B+ trees are commonly used in databases and operating system [file systems](http://baike.baidu.com/view/266589.htm). File systems such as NTFS, ReiserFS, NSS, XFS, JFS, ReFS, and BFS all use B+ trees as metadata indexes. B+ trees are characterized by their ability to keep data stable and ordered, while insertions and modifications have relatively stable logarithmic time complexity. B+ tree elements are inserted from bottom to top.


![](http://upload-images.jianshu.io/upload_images/1194012-b576120711ec7f4b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Realm ensures that every connected thread has a snapshot of the data at a specific point in time. This is also why you can perform large numbers of operations across hundreds of threads while accessing the database concurrently without crashes.

![](http://upload-images.jianshu.io/upload_images/1194012-9fb904dc362ba9ba.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The diagram above clearly illustrates the flow of a Realm write operation. It is divided into three stages. In stage one, V1 points to the root node R. In stage two, the write operation is prepared. At this point, there is a V2 node pointing to the new R', and a new branch is created, A' and C'. The corresponding right child points to the right child of the original R that V1 points to. If the write operation fails, the branch on the left is discarded. This design ensures that even if failure occurs, only the latest data is lost, and the entire database is not corrupted. If the write succeeds, the original R, A, and C nodes are placed into Garbage, and then stage three is reached: the write succeeds, and V2 points to the root node.

In this write process, the second stage is the most critical. The write operation does not modify the original data; instead, it creates a new branch. This avoids locking while still solving the database concurrency problem.

**It is precisely the underlying B+ tree data structure plus the MVCC design that guarantees Realm’s high performance.**

### 2.Realm uses a zero-copy architecture

Because Realm uses a zero-copy architecture, it has almost no memory overhead. This is because every Realm object directly corresponds to the underlying database through a native `long` pointer, which acts as a hook into the data in the database.


A typical traditional database operation works like this: data is stored in a database file on disk, and our query request is converted into a series of SQL statements to create a database connection. The database server receives the request, performs lexical, syntactic, and semantic analysis of the SQL statement through a parser, then optimizes the SQL statement through a query optimizer. After optimization, it executes the corresponding query, reads the database file on disk (if there is an index, it reads the index first), reads each row that matches the query, and then stores the data in memory (which incurs memory overhead). After that, you need to serialize the data into a format that can be stored in memory, which means bit alignment so the CPU can process it. Finally, the data needs to be converted into language-level types, and then it is returned as objects, such as Objective-C objects.

This is another reason Realm is fast. Realm database files are memory-mapped, meaning the database file itself is mapped into memory (actually virtual memory). Accessing file offsets in Realm is as if the file were already in memory (where “memory” refers to virtual memory). This allows the file to be read directly from memory without deserialization, improving read efficiency. Realm only needs to calculate offsets to locate data in the file, then return the value of the data structure from the raw access point.

**It is precisely because Realm uses a zero-copy architecture, has almost no memory overhead, and has a core file format based on memory-mapping—saving a large amount of serialization and deserialization overhead—that Realm is especially efficient at retrieving objects.**


### 3. Realm objects cannot be shared across different threads

The reason Realm objects cannot be passed between threads is to ensure isolation and data consistency. There is only one goal behind this design: speed.

Because Realm is based on zero-copy and all objects are in memory, they update automatically. If Realm objects were allowed to be shared between threads, Realm would be unable to ensure data consistency, because different threads could change an object’s data at unpredictable points in time.

To guarantee that objects can be shared across multiple threads, you need locking. But locking would cause a long-running background write transaction to block UI read transactions. Without locking, data consistency cannot be guaranteed, but speed requirements can be met. After weighing the trade-offs, Realm chose speed and made the compromise of disallowing sharing across threads.

**It is precisely because objects are not allowed to be shared across different threads that data consistency is guaranteed; and by avoiding thread locks, Realm maintains its significant speed advantage.**

### 4. True Lazy Loading

Most databases tend to store data horizontally, which is why when you read a single property from SQLite, you have to load the entire row. It is stored contiguously in the file.

Realm is different: it stores properties contiguously in the vertical dimension as much as possible. You can also think of it as column-oriented storage.

After a query returns a set of data, the data is only actually loaded when you access the objects.


### 5. Files in Realm


![](http://upload-images.jianshu.io/upload_images/1194012-9543fbc332191bc0.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Let’s start with the Database File in the middle.

The .realm file is memory-mapped, and every object is a reference to an offset from the start address of the file. Object storage is not necessarily contiguous, but Array can guarantee contiguous storage.

When a .realm performs a write operation, there are three pointers: one is the \*current top pointer, one is the other top pointer, and the last one is the switch bit\*.

The switch bit\* indicates whether the top pointer has already been used. If it has been used, it means the database is already readable.

The top pointer is updated first, followed by the switch bit. This is because even if the write fails and all newly written data is lost, it still ensures that the database remains readable.

Next, let’s talk about the .lock file.

The .lock file contains metadata for the shared group. This file is responsible for allowing multiple threads to access the same Realm objects.

Finally, let’s talk about Commit logs history.

This file is used to update indexes and for synchronization. It mainly maintains three small files: two are data-related, and one is for operation management.


## Summary

After the analysis above, it is clear that Realm was built for speed. While satisfying ACID requirements, many of its design choices prioritize performance. Of course, Realm’s core philosophy is object-driven, and this is Realm’s fundamental principle. Realm is essentially an embedded database, but it is also a different way of looking at data. It rethinks the models and business logic in mobile applications from another perspective.

Realm is also cross-platform. It is a great thing for multiple platforms to use the same database. I believe more and more developers will use Realm as the database for their apps.


Reference Links  

[Realm Official Website](https://realm.io/)  
[Realm Official Documentation](https://realm.io/docs/objc/latest/api/index.html)  
[Realm GitHub](https://github.com/realm) 