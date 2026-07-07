<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-86f3f1bc02294ac7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface
After reading the title of this article, some of you may still not know what Realm is, so let me briefly introduce this new database. It claims to be a replacement for SQLite and Core Data. Realm has the following advantages:

1. Easy to use
Realm is not an object-relational mapping database built on SQLite. It uses its own persistence engine and was built for simplicity and speed. [Users](https://realm.io/users) say they can get started with Realm in minutes, build an app in just a few hours, and save at least several weeks of development time on each app.

2. Fast
Realm is faster than other object-relational mapping databases (Object Relational Mapping), and even faster than native SQLite, thanks to its zero-copy design. Take a look at what [iOS](https://realm.io/news/introducing-realm/#fast) users and [Android](https://realm.io/news/realm-for-android/#realm-for-android) users have said about how fast it is on [Twitter](https://twitter.com/realm/favorites).

3. Cross-platform
Realm supports iOS and OS X ([Objective‑C](https://static.realm.io/downloads/objc/realm-objc-1.0.0.zip) & [Swift](https://static.realm.io/downloads/swift/realm-swift-1.0.0.zip)) and [Android](https://static.realm.io/downloads/java/realm-java-1.0.0.zip). By using the same model, you can share Realm files across platforms: Java, Swift, and Objective-C. You can also use the same business logic across all platforms.
 
4. Excellent features
Realm supports advanced features such as [encryption](https://realm.io/docs/java/latest/#encryption), [graph queries](https://realm.io/docs/objc/latest/#queries), and [easy migrations](https://realm.io/docs/swift/latest/#migrations). Realm's API is very well suited to building highly responsive applications, and Realm provides convenient components that make it easy to build complex user interfaces.

5. Trusted
Realm has already been adopted by banks, healthcare providers, complex enterprise apps, and products like Starbucks.

6. Community-driven
Realm is the fourth most-starred database on GitHub, second only to the Java and Cocoa repos. Beyond the core project, the Realm community has already built [hundreds of app plugins and components](https://realm.io/addons).
7. Support
You can get official answers quickly from the Realm company to help build and support your database. The Realm team answers all kinds of questions on [Github](https://github.com/realm), [StackOverflow](https://stackoverflow.com/questions/tagged/realm?sort=newest), & [Twitter](https://twitter.com/realm).

Below are three more exciting performance comparison charts.

![](http://upload-images.jianshu.io/upload_images/1194012-c5a9a2eba990151e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The chart above shows how many query-then-count operations can be performed per second over 200,000 records. Realm can perform 30.9 query-then-count operations per second. SQLite can only perform 13.6 query-then-count operations per second, while Core Data manages a pitiful 1.


![](http://upload-images.jianshu.io/upload_images/1194012-f44984d9ac96595c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This is a traversal query over 200,000 records. The numbers are similar to the previous count benchmark: Realm can traverse 200,000 records 31 times per second, while Core Data can only perform two queries. SQLite manages only 14.


![](http://upload-images.jianshu.io/upload_images/1194012-c808e85259fbccf5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
This compares inserting data per second in a single transaction. Realm can insert 94,000 records per second. In this comparison, pure SQLite performs the best, inserting 178,000 records per second. However, FMDB, which wraps SQLite, achieves roughly half of Realm's result—47,000—while Core Data is even lower, at a pitiful 18,000.

From the three charts above, you can see Realm's excellent characteristics. Now let's start using Realm. The first step is to replace the local database with Realm.

Below is a step-by-step tutorial I translated. Let's walk through it and migrate from Core Data to Realm.

## [Original](https://realm.io/news/migrating-from-core-data-to-realm/)

## Translation
Migrating an app that uses the Core Data framework for database storage to Realm is indeed very easy. If you currently have an app that already uses Core Data and are considering switching to Realm, this step-by-step tutorial is for you!

Many developers have Core Data deeply integrated into their user interface (sometimes with thousands of lines of code). At that point, many people will tell you that converting from Core Data to Realm could take hours. Both Core Data and Realm treat your data as objects, so migration is usually a very straightforward process: refactoring your existing Core Data code to use the Realm API is simple.

After the migration, you'll be excited by the ease of use, speed, and stability that Realm brings to your app.

### 1. Remove the Core Data Framework
First, if your app is currently using Core Data, you need to identify which parts of the code contain Core Data-related code. That code will need to be refactored. Fortunately, there is a manual way to do this: you can manually search through the entire codebase for the relevant code, then delete every statement that imports the Core Data header.
```

#import <CoreData/CoreData.h>
//or
@import CoreData;
```
Once you delete it this way, every line that uses Core Data will report a compile error. From there, resolving those compile errors is just a matter of time.


### 2. Remove the Core Data setup code
In Core Data, changes to model objects are made through a managed object context object. Managed object context objects are created by a persistent store coordinator object, and both of those are created by a managed object model object.

Put another way, before you even start thinking about using Core Data to read or write data, you typically need to set up the dependent objects somewhere in your app and expose some Core Data methods for your app logic to use. Whether in your application delegate, in a global singleton, or directly inline, these places can contain a large amount of potential Core Data setup code.

When you are ready to migrate to Realm, all of this code can be deleted.

In Realm, all setup is already complete the first time you create a Realm object. Of course, you can also configure it manually—for example, specifying which path on disk the Realm data file should be stored at. All of this can be chosen at runtime.
```
RLMRealm *defaultRealm = [RLMRealm defaultRealm];
//or
let realm = Realm()
```
Feels pretty good, right?

### 3. Migrate model files

In Core Data, the practical classes are all defined as subclasses of `NSManagedObject`. The interfaces of these objects are very standardized. Primitive types (such as `NSInteger` and `CGFloat`) cannot be used directly; they must be abstracted into an `NSNumber` object.
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
Converting these managed object subclasses to Realm is very straightforward:
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
or
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
Done! How easy was that?

Looking at these implementations, there are still a few Realm details worth noting.

For people using Realm for the first time, there is no need to specify property attributes; Realm manages them internally. That is why the header files for these classes all look very concise. In addition, Realm supports simple data types such as NSInteger and CGFloat, so all NSNumber usage can be safely removed.

On the other hand, here are a few additional notes about declaring Realm models.

1. Core Data objects are uniquely identified by their internal NSManagedObjectID property, while Realm leaves this to the developer. In the example above, we added an extra property named uuid, and then used the [RLMObject primaryKey] method to make it the unique identifier for this class. Of course, if your objects do not need unique identifiers at all, you can skip all of this.

2. During write operations (which do not take very long!), Realm cannot handle nil object properties. The reason is that, in the [RLMObject defaultPropertyValues] class method, a set of default values is defined for each object property when each object is initially created. Of course, this is only temporary. We are happy to tell you that in upcoming updates, we will support Realm object properties being nil.


### 4. Migrating Write Operations

If you cannot save your data, it is certainly not a persistent solution! Creating a new Core Data object and then simply modifying it requires the following code:
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
By contrast, Realm’s save operation is slightly different, but if you modify the code above within the same scope, there are still similarities.
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
or
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
Done! Our data has been saved!

The obvious difference is that in Realm, once an object is added to a Realm, it cannot be modified directly. To perform operations that modify properties afterward, the Realm object must be updated within a write transaction. This immutable model ensures data consistency when object data is read and written across different threads.

Core Data’s implementation can indeed change properties and then call the save method. Compared with Realm’s implementation, the differences are only minor.


### 5. Migrating Queries


On the other hand, if you cannot retrieve and query your data, it certainly is not a persistent solution!

In Core Data’s basic implementation, it uses the concept of fetch requests to retrieve data from disk. A fetch request object is created as a separate instantiated object and includes additional filtering parameters and sorting criteria.
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
While this is indeed quite good, it requires writing a lot of code! Some clever developers created libraries to make writing this code easier, such as MagicalRecord.

By comparison, after using Realm, the equivalent code for these queries is as follows:
```
RLMResults *dogs = [[Dog objectsWhere:@"age < 5"] sortedResultsUsingProperty:@"name" ascending:YES];
```
or
```
var dogs = Realm().objects(Dog).filter("age < 5").sorted("name")
```
Called two methods on a single line, compared with nearly 10 lines of code in Core Data.

Of course, the same operation produces the same result (`RLMResults` and `NSArray` are broadly similar). When migrating to Realm, because these queries are quite independent, the logic around them only needs a small amount of refactoring.


### 6. Migrating User Data

Once all your code has been migrated to Realm, there is still one prominent issue: how do you migrate all the data that already exists on users’ devices from Core Data to Realm?

Obviously, this is a very complex problem, and it depends on your app’s functionality as well as the user’s environment. The solution you use to handle this situation may be different every time.

So far, we have seen two scenarios:

1. Once you migrate to Realm, you can re-import the Core Data framework into your app, use native `NSManagedObject` objects to fetch your users’ Core Data, and then manually pass that data to Realm. You can leave this migration code in the app permanently, or you can remove it after a sufficiently long period of time.

2. If the user data is not irreplaceable—for example, if it is simple cached information that can be regenerated from user data on disk—then you can simply clear the Core Data data and start from scratch the next time the user opens the app. Of course, this requires very careful consideration; otherwise, it could leave many people with a very poor user experience.

Ultimately, the decision should be user-oriented. Ideally, you should not leave Core Data still linked into your app, but the outcome depends on your situation. Good luck!


## Further Discussion

Although there are no truly critical steps in porting an application to Realm, there are some additional situations you should be aware of:

### Concurrency


If you perform some relatively heavy operations on a background thread, you may find that you need to pass Realm objects between threads. Core Data allows you to pass managed objects between threads (although doing so is not a best practice), but in Realm, passing objects between threads is strictly prohibited, and any attempt to do so will throw a serious exception.

That said, for the following cases, this is straightforward:
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
or
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
Although Realm objects cannot be passed across threads, copies of Realm properties can be passed between threads. Given that Realm is extremely fast at retrieving objects from disk, simply re-fetching the same object from the store on a new thread incurs only a very small performance cost. In this example, we take a copy of the object’s primary key, pass it from a background queue to the main queue, and then use it to re-fetch the object in the context of the main thread.


### The Equivalent of NSFetchedResultsController

Despite all of Core Data’s shortcomings, perhaps the strongest reason to use Core Data is NSFetchedResultsController—a class that can detect changes in the data store and automatically reflect those changes in the UI.

At the time of writing, Realm does not yet have a similar mechanism. Although it can register a block that is executed when the data source changes, this “brute force” approach is not very UI-friendly for most interfaces. For now, if your UI code depends heavily on Realm, this can feel like a deal breaker.

Realm’s Cocoa engineers are currently developing a notification system that will allow us to register for notifications when properties on certain objects are changed, so we can receive those changes. These features will arrive in future updates to Realm for Swift and Objective‑C.

In the meantime, if the existing notification block API still does not meet your needs, but you still need to receive a notification when a specific property changes, we recommend using the excellent third-party library [RBQFetchedResultsController](https://github.com/Roobiq/RBQFetchedResultsController), which can emulate the functionality described above. In addition, you can achieve the same effect by adding setter methods to your objects and broadcasting a notification when those setters are called.


## Conclusion

Both Core Data and Realm present data through model objects. Because of this similarity, migrating from Core Data to Realm can be very quick, simple, and very satisfying. Although it may look daunting at first, in practice it mainly involves converting each Core Data method call into the equivalent Realm method call, and then writing a helper class to migrate your users’ data. These tasks are all quite straightforward.

If you are running into difficulties using Core Data in your app and need a simpler solution, we strongly recommend trying Realm to see whether it works for you. If it does, please let us know!

Thanks for reading. Now go build something amazing with Realm! You can reach us on [StackOverflow](https://stackoverflow.com/questions/tagged/realm?sort=newest), [GitHub](https://github.com/realm/realm-cocoa), or [Twitter](https://twitter.com/realm).