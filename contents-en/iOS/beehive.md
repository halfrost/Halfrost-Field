# BeeHive — An Elegant Decoupling Framework That Is Still Being Refined

![](https://img.halfrost.com/Blog/ArticleTitleImage/41_0_.png)


### Preface

BeeHive is an open-source iOS framework from Alibaba. It is one implementation of an app modularization framework, borrowing the Service concept from the Spring framework to decouple APIs between modules.

The name BeeHive was inspired by honeycombs. A honeycomb is a highly modular engineering structure in nature, and its hexagonal design enables the possibility of infinite expansion. That is why this name was chosen for the open-source project.


![](https://img.halfrost.com/Blog/ArticleImage/41_1.png)


In the previous article, [iOS Componentization — Analysis of Routing Design Ideas](http://www.jianshu.com/p/76da56b3bd55), we analyzed how app components can be decoupled through routing. In this article, we will look at how decoupling can be achieved using the idea of modularization.

(At this point, many people will probably have questions. In that case, take a look at this article: [The Difference Between Components and Modules](http://blog.csdn.net/horkychen/article/details/45083467))


Note: This article is based on BeeHive v1.2.0.

### Table of Contents

- 1.Overview of BeeHive
- 2.BeeHive Module Registration
- 3.BeeHive Module Events
- 4.BeeHive Module Invocation
- 5.Some Other Helper Classes
- 6.Features That May Still Be Under Development


### 1. Overview of BeeHive


Because BeeHive is based on Spring’s Service concept, although it can decouple the concrete implementations of modules from their interfaces, it cannot avoid dependencies on interface classes between modules.


For the time being, BeeHive does not use `invoke` or `performSelector:action withObject: params`. The main reasons are concerns about the learning curve, as well as the fact that dynamic invocation implementations cannot detect interface parameter changes during compile-time checks.

Currently, BeeHive v1.2.0 uses Protocols throughout to achieve decoupling between modules:

1.Each module exists as a plugin. Each can be independent and decoupled from the others.
2.The concrete implementation of each module is separated from interface invocation.
3.Each module also has a lifecycle and can be managed.


The official documentation also provides an architecture diagram:


![](https://img.halfrost.com/Blog/ArticleImage/41_2.png)


Next, we will analyze in order how module registration, module events, and module invocation implement decoupling.


### 2. BeeHive Module Registration


Let’s start with module registration and see how BeeHive registers each module.


In BeeHive, `BHModuleManager` is used to manage all modules. `BHModuleManager` only manages modules that have already been registered.


There are three ways to register a Module:

#### 1. Register via Annotation  

Use the `BeeHiveMod` macro to mark an Annotation.
```objectivec

BeeHiveMod(ShopModule)

```
The `BeeHiveMod` macro is defined as follows:
```objectivec


#define BeeHiveMod(name) \
char * k##name##_mod BeeHiveDATA(BeehiveMods) = ""#name"";


```
BeeHiveDATA is also a macro:
```objectivec

#define BeeHiveDATA(sectname) __attribute((used, section("__DATA,"#sectname" ")))


```
Ultimately, by the end of preprocessing, the `BeeHiveMod` macro will be fully expanded into the following:
```objectivec


char * kShopModule_mod __attribute((used, section("__DATA,""BeehiveMods"" "))) = """ShopModule""";


```
Pay attention to the total number of pairs of double quotes.


At this point, for \_\_attribute((used,section("segmentname,sectionname"))), we need to explain two things first.


The first parameter of \_\_attribute, `used`, is very useful. This keyword is used to annotate functions. Once annotated with `used`, it means that even if the function is not referenced, it will not be optimized away in Release builds. Without this annotation, the linker in a Release environment will remove unreferenced sections. For details, see the [official GNU documentation](https://gcc.gnu.org/onlinedocs/gcc-3.2/gcc/Function-Attributes.html#Function%20Attributes).


Static variables are placed into a separate section in the order in which they are declared. We use \_\_attribute\_\_((section("name"))) to specify which section. Data is marked with \_\_attribute\_\_((used)) to prevent the linker from optimizing away and deleting unused sections.


Now let’s talk specifically about what `section` does.

The file generated after the compiler compiles the source code is called an object file. In terms of file structure, it is already in an executable file format after compilation; it just has not gone through the linking process yet. Executable files are mainly PE (Portable Executable) on Windows and ELF (Executable Linkable Format) on Linux, both of which are variants of the COFF (Common file format) format. After the program source code is compiled, it is mainly divided into two sections: program instructions and program data. The code section belongs to program instructions, while the data section and `.bss` section belong to program data.

![](https://img.halfrost.com/Blog/ArticleImage/41_3.png)


A concrete example is shown in the figure above. As you can see, the `.data` data section stores initialized global static variables and local static variables. The `.rodata` section stores read-only data, generally variables annotated with `const` and string literals. The `.bss` section stores uninitialized global variables and local static variables. The code section is in the `.text` section.

Sometimes we need to specify a special section to store the data we want. Here, we store the data in the `"BeehiveMods"` section inside the `data` data section.

Of course, there are other attribute keywords as well. For details, see the [official documentation](https://gcc.gnu.org/onlinedocs/gcc-3.2/gcc/Variable-Attributes.html)


Back to the code:
```objectivec

char * kShopModule_mod __attribute((used, section("__DATA,""BeehiveMods"" "))) = """ShopModule""";

```
This is equivalent to:
```objectivec


char * kShopModule_mod = """ShopModule""";

```
It simply places the `kShopModule\_mod` string into a special section.


Since the Module is stored in a special section like this, how is it retrieved?
```objectivec


static NSArray<NSString *>* BHReadConfiguration(char *section)
{
    NSMutableArray *configs = [NSMutableArray array];
    
    Dl_info info;
    dladdr(BHReadConfiguration, &info);
    
#ifndef __LP64__
    // const struct mach_header *mhp = _dyld_get_image_header(0); // both works as below line
    const struct mach_header *mhp = (struct mach_header*)info.dli_fbase;
    unsigned long size = 0;
    // Find the memory region of the previously stored data section (Module looks for the BeehiveMods section and Service looks for the BeehiveServices section)
    uint32_t *memory = (uint32_t*)getsectiondata(mhp, "__DATA", section, & size);

#else /* defined(__LP64__) */
    const struct mach_header_64 *mhp = (struct mach_header_64*)info.dli_fbase;
    unsigned long size = 0;
    uint64_t *memory = (uint64_t*)getsectiondata(mhp, "__DATA", section, & size);

#endif /* defined(__LP64__) */
    
    // Convert all data in the special section to strings and store them in the array
    for(int idx = 0; idx < size/sizeof(void*); ++idx){
        char *string = (char*)memory[idx];
        
        NSString *str = [NSString stringWithUTF8String:string];
        if(!str)continue;
        
        BHLog(@"config = %@", str);
        if(str) [configs addObject:str];
    }
    
    return configs;
}


```
Dl\_info is a data structure in Mach-O.
```objectivec

typedef struct dl_info {
        const char      *dli_fname;     /* Pathname of shared object */
        void            *dli_fbase;     /* Base address of shared object */
        const char      *dli_sname;     /* Name of nearest symbol */
        void            *dli_saddr;     /* Address of nearest symbol */
} Dl_info;

```
The data in this data structure is by default passed through
```objectivec

extern int dladdr(const void *, Dl_info *);


```
Use the `dladdr` function to obtain the data in `Dl_info`.

`dli_fname`: path name, for example
```vim

/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation

```
dli\_fbase: the base address of the shared object (Base address of shared object, such as CoreFoundation above)

dli\_saddr: the address of the symbol  
dli\_sname: the name of the symbol, i.e., the function information in the fourth column below
```vim

Thread 0:
0     libsystem_kernel.dylib          0x11135810a __semwait_signal + 94474
1     libsystem_c.dylib               0x1110dab0b sleep + 518923
2     QYPerformanceMonitor            0x10dda4f1b -[ViewController tableView:cellForRowAtIndexPath:] + 7963
3     UIKit                           0x10ed4d4f4 -[UITableView _createPreparedCellForGlobalRow:withIndexPath:willDisplay:] + 1586420

```
By calling this static function, `BHReadConfiguration`, we can obtain the class names of the various Modules previously registered in the special `BeehiveMods` section, all stored in the data as strings.
```objectivec


+ (NSArray<NSString *> *)AnnotationModules
{
    static NSArray<NSString *> *mods = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mods = BHReadConfiguration(BeehiveModSectName);
    });
    return mods;
}


```
This is a singleton array containing string arrays that correspond to the Module names previously placed in the special section.

Once you have this array, you can register all the Modules.
```objectivec


- (void)registedAnnotationModules
{
    
    NSArray<NSString *>*mods = [BHAnnotation AnnotationModules];
    for (NSString *modName in mods) {
        Class cls;
        if (modName) {
            cls = NSClassFromString(modName);
            
            if (cls) {
                [self registerDynamicModule:cls];
            }
        }
    }
}


- (void)registerDynamicModule:(Class)moduleClass
{
    [self addModuleFromObject:moduleClass];
 
}


```
Finally, you also need to add all registered `Module`s to `BHModuleManager`.
```objectivec

- (void)addModuleFromObject:(id)object
{
    Class class;
    NSString *moduleName = nil;
    
    if (object) {
        class = object;
        moduleName = NSStringFromClass(class);
    } else {
        return ;
    }
    
    if ([class conformsToProtocol:@protocol(BHModuleProtocol)]) {
        NSMutableDictionary *moduleInfo = [NSMutableDictionary dictionary];
        
        // If basicModuleLevel is not implemented by default, Level defaults to Normal
        BOOL responseBasicLevel = [class instancesRespondToSelector:@selector(basicModuleLevel)];

        // Level is BHModuleNormal, which is 1
        int levelInt = 1;
        
        // If basicModuleLevel is implemented, then Level is BHModuleBasic
        if (responseBasicLevel) {
            // Level is Basic, BHModuleBasic is 0
            levelInt = 0;
        }
        
        // @"moduleLevel" is the Key, Level is the Value
        [moduleInfo setObject:@(levelInt) forKey:kModuleInfoLevelKey];
        if (moduleName) {
            // @"moduleClass" is the Key, moduleName is the Value
            [moduleInfo setObject:moduleName forKey:kModuleInfoNameKey];
        }

        [self.BHModules addObject:moduleInfo];
    }
}

```
Some necessary explanations have already been added as comments in the code above. `BHModules` is an `NSMutableArray` that stores individual dictionaries. Each dictionary contains two keys: `@"moduleLevel"` and `@"moduleClass"`. When storing registered `Module`s, you need to check the `Level`. Another point to note is that every `Module` that needs to be registered must conform to the `BHModuleProtocol` protocol; otherwise, it cannot be stored.


#### 2. Read a Local Plist File


Before reading a local Plist file, you need to set up the path first.
```objectivec

    [BHContext shareInstance].moduleConfigName = @"BeeHive.bundle/BeeHive";//Optional, defaults to BeeHive.bundle/BeeHive.plist

```
All BeeHive configuration can be written into `BHContext` and passed along.

![](https://img.halfrost.com/Blog/ArticleImage/41_4.png)


The Plist file format should also be an array containing dictionaries. Each dictionary has two keys: `@"moduleLevel"` and `@"moduleClass"`. Note that the root array is named `@"moduleClasses"`.
```objectivec


- (void)loadLocalModules
{
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:[BHContext shareInstance].moduleConfigName ofType:@"plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
        return;
    }

    NSDictionary *moduleList = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    
    NSArray *modulesArray = [moduleList objectForKey:kModuleArrayKey];
    
    [self.BHModules addObjectsFromArray:modulesArray];
    
}


```
Extract the array from the Plist, then append the array to the `BHModules` array.


#### 3. Registration in the Load Method

The final way to register a Module is to register the Module class in the Load method.
```objectivec

+ (void)load
{
    [BeeHive registerDynamicModule:[self class]];
}


```
Call registerDynamicModule: in BeeHive to complete Module registration.
```objectivec


+ (void)registerDynamicModule:(Class)moduleClass
{
    [[BHModuleManager sharedManager] registerDynamicModule:moduleClass];
}


```
The implementation of registerDynamicModule: in BeeHive still calls BHModuleManager’s registration method registerDynamicModule:
```objectivec


- (void)registerDynamicModule:(Class)moduleClass
{
    [self addModuleFromObject:moduleClass];
 
}


```
In the end, it still calls the addModuleFromObject: method in BHModuleManager. This method was analyzed above, so I won’t go into it again.


The Load method can also be implemented using the BH\_EXPORT\_MODULE macro.
```objectivec


#define BH_EXPORT_MODULE(isAsync) \
+ (void)load { [BeeHive registerDynamicModule:[self class]]; } \
-(BOOL)async { return [[NSString stringWithUTF8String:#isAsync] boolValue];}


```
The BH\_EXPORT\_MODULE macro can take one parameter, indicating whether the Module should be loaded asynchronously. If it is YES, the Module is loaded asynchronously; if it is NO, it is loaded synchronously.

That completes the three registration methods. Finally, BeeHive also performs some operations on the Classes of these Modules.

First, when BeeHive initializes setContext:, it loads Modules and Services separately. Here we will first discuss Modules.
```objectivec

-(void)setContext:(BHContext *)context
{
    _context = context;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadStaticServices];
        [self loadStaticModules];
    });
}


```
Let's take a look at what the loadStaticModules method does.
```objectivec


- (void)loadStaticModules
{
    // Read Modules from the local plist file and register them in BHModuleManager's BHModules array
    [[BHModuleManager sharedManager] loadLocalModules];
    
    // Read marker data from the special section and register it in BHModuleManager's BHModules array
    [[BHModuleManager sharedManager] registedAnnotationModules];

    [[BHModuleManager sharedManager] registedAllModules];
    
}


```
Although we only see two approaches here, the `BHModules` array can also include `Module`s registered via the `Load` method. In practice, the `BHModules` array contains `Module`s added through three different registration mechanisms.

The final step, `registedAllModules`, is relatively important.
```objectivec

- (void)registedAllModules
{

    // Sort by priority from high to low
    [self.BHModules sortUsingComparator:^NSComparisonResult(NSDictionary *module1, NSDictionary *module2) {
      NSNumber *module1Level = (NSNumber *)[module1 objectForKey:kModuleInfoLevelKey];
      NSNumber *module2Level =  (NSNumber *)[module2 objectForKey:kModuleInfoLevelKey];
        
        return [module1Level intValue] > [module2Level intValue];
    }];
    
    NSMutableArray *tmpArray = [NSMutableArray array];
    
    //module init
    [self.BHModules enumerateObjectsUsingBlock:^(NSDictionary *module, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSString *classStr = [module objectForKey:kModuleInfoNameKey];
        
        Class moduleClass = NSClassFromString(classStr);
        
        if (NSStringFromClass(moduleClass)) {
            
            // Initialize all Modules
            id<BHModuleProtocol> moduleInstance = [[moduleClass alloc] init];
            [tmpArray addObject:moduleInstance];
        }
        
    }];
    
    [self.BHModules removeAllObjects];

    [self.BHModules addObjectsFromArray:tmpArray];
    
}


```
Before the `registedAllModules` method is executed, the `BHModules` array contains individual dictionaries. After `registedAllModules` has finished executing, it contains instances of individual Modules.

The `registedAllModules` method first sorts the Modules by `Level` in descending priority order, then initializes all Module instances one by one in that order and stores them in the array. Ultimately, the `BHModules` array contains all Module instance objects.


Note that there are two additional points to call out here:

1. All Module objects are restricted to conform to the `BHModuleProtocol` protocol. The reason for conforming to `BHModuleProtocol` will be explained in detail in the next section.
2. A Module must not be created with `alloc` anywhere else. Even if a new Module instance is created, it is not managed by `BHModuleManager` and cannot receive system events dispatched by `BHModuleManager`, so creating it is meaningless.

![](https://img.halfrost.com/Blog/ArticleImage/41_5.png)


### III. BeeHive Module Events


BeeHive provides lifecycle events for each module, enabling the necessary exchange of information with the BeeHive host environment and allowing modules to observe changes in their lifecycle.


Each BeeHive module receives certain events. In `BHModuleManager`, all events are defined as the `BHModuleEventType` enum.
```objectivec


typedef NS_ENUM(NSInteger, BHModuleEventType)
{
    BHMSetupEvent = 0,
    BHMInitEvent,
    BHMTearDownEvent,
    BHMSplashEvent,
    BHMQuickActionEvent,
    BHMWillResignActiveEvent,
    BHMDidEnterBackgroundEvent,
    BHMWillEnterForegroundEvent,
    BHMDidBecomeActiveEvent,
    BHMWillTerminateEvent,
    BHMUnmountEvent,
    BHMOpenURLEvent,
    BHMDidReceiveMemoryWarningEvent,
    BHMDidFailToRegisterForRemoteNotificationsEvent,
    BHMDidRegisterForRemoteNotificationsEvent,
    BHMDidReceiveRemoteNotificationEvent,
    BHMDidReceiveLocalNotificationEvent,
    BHMWillContinueUserActivityEvent,
    BHMContinueUserActivityEvent,
    BHMDidFailToContinueUserActivityEvent,
    BHMDidUpdateUserActivityEvent,
    BHMDidCustomEvent = 1000
    
};


```
The `BHModuleEventType` enum above is mainly divided into three categories: system events, application events, and business-specific custom events.


#### 1. System events.


![](https://img.halfrost.com/Blog/ArticleImage/41_6.png)


The figure above shows the basic workflow for system events provided by the official documentation.

System events are typically `Application` lifecycle events, such as `DidBecomeActive`, `WillEnterBackground`, and so on.

The usual approach is to have `BHAppDelegate` take over the original `AppDelegate`.
```objectivec


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    [[BHModuleManager sharedManager] triggerEvent:BHMSetupEvent];
    [[BHModuleManager sharedManager] triggerEvent:BHMInitEvent];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[BHModuleManager sharedManager] triggerEvent:BHMSplashEvent];
    });
    
    return YES;
}


#if __IPHONE_OS_VERSION_MAX_ALLOWED > 80400 

-(void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    [[BHModuleManager sharedManager] triggerEvent:BHMQuickActionEvent];
}

#endif

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMWillResignActiveEvent];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidEnterBackgroundEvent];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMWillEnterForegroundEvent];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidBecomeActiveEvent];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMWillTerminateEvent];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    [[BHModuleManager sharedManager] triggerEvent:BHMOpenURLEvent];
    return YES;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > 80400
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    [[BHModuleManager sharedManager] triggerEvent:BHMOpenURLEvent];
    return YES;
}

#endif


- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidReceiveMemoryWarningEvent];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidFailToRegisterForRemoteNotificationsEvent];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidRegisterForRemoteNotificationsEvent];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidReceiveRemoteNotificationEvent];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidReceiveRemoteNotificationEvent];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    [[BHModuleManager sharedManager] triggerEvent:BHMDidReceiveLocalNotificationEvent];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > 80000
- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity
{
    if([UIDevice currentDevice].systemVersion.floatValue > 8.0f){
        [[BHModuleManager sharedManager] triggerEvent:BHMDidUpdateUserActivityEvent];
    }
}

- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error
{
    if([UIDevice currentDevice].systemVersion.floatValue > 8.0f){
        [[BHModuleManager sharedManager] triggerEvent:BHMDidFailToContinueUserActivityEvent];
    }
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler
{
    if([UIDevice currentDevice].systemVersion.floatValue > 8.0f){
        [[BHModuleManager sharedManager] triggerEvent:BHMContinueUserActivityEvent];
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType
{
    if([UIDevice currentDevice].systemVersion.floatValue > 8.0f){
        [[BHModuleManager sharedManager] triggerEvent:BHMWillContinueUserActivityEvent];
    }
    return YES;
}


```
This way, all system events can be handled by calling `triggerEvent:` on `BHModuleManager`.

There are two special events in `BHModuleManager`: `BHMInitEvent` and `BHMTearDownEvent`.

Let’s start with the `BHMInitEvent` event.
```objectivec


- (void)handleModulesInitEvent
{
    
    [self.BHModules enumerateObjectsUsingBlock:^(id<BHModuleProtocol> moduleInstance, NSUInteger idx, BOOL * _Nonnull stop) {
        __weak typeof(&*self) wself = self;
        void ( ^ bk )();
        bk = ^(){
            __strong typeof(&*self) sself = wself;
            if (sself) {
                if ([moduleInstance respondsToSelector:@selector(modInit:)]) {
                    [moduleInstance modInit:[BHContext shareInstance]];
                }
            }
        };

        [[BHTimeProfiler sharedTimeProfiler] recordEventTime:[NSString stringWithFormat:@"%@ --- modInit:", [moduleInstance class]]];
        
        if ([moduleInstance respondsToSelector:@selector(async)]) {
            BOOL async = [moduleInstance async];
            
            if (async) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    bk();
                });
                
            } else {
                bk();
            }
        } else {
            bk();
        }
    }];
}


```
The Init event is the event that initializes Module modules. It iterates over the `BHModules` array and calls the `modInit:` method on each Module instance in order. There can be an asynchronous loading issue here. If `moduleInstance` overrides the `async` method, whether to load asynchronously is determined based on the value returned by that method.

The `modInit:` method does a lot of things. For example, it may check the environment and initialize different methods depending on the environment.
```objectivec


-(void)modInit:(BHContext *)context
{
    switch (context.env) {
        case BHEnvironmentDev:
            //....Initialize the development environment
            break;
        case BHEnvironmentProd:
            //....Initialize the production environment
        default:
            break;
    }
}


```
For example, registering some protocols during initialization:
```objectivec


-(void)modInit:(BHContext *)context
{
  [[BeeHive shareInstance] registerService:@protocol(UserTrackServiceProtocol) service:[BHUserTrackViewController class]];
}

```
In short, you can perform any required initialization tasks here.

Now let’s talk about the `BHMTearDownEvent` event. This event tears down the Module.
```objectivec


- (void)handleModulesTearDownEvent
{
    //Reverse Order to unload
    for (int i = (int)self.BHModules.count - 1; i >= 0; i--) {
        id<BHModuleProtocol> moduleInstance = [self.BHModules objectAtIndex:i];
        if (moduleInstance && [moduleInstance respondsToSelector:@selector(modTearDown:)]) {
            [moduleInstance modTearDown:[BHContext shareInstance]];
        }
    }
}


```
Because Module has a priority Level, teardown must start from the lower-priority modules; that is, iterate through the array in reverse order. Simply send the modTearDown: event to each Module instance.


#### 2. Application Events


![](https://img.halfrost.com/Blog/ArticleImage/41_7.png)


The official application event workflow is shown above:

On top of system events, it extends common application events, such as modSetup and modInit, which can be used in code to implement setup and initialization for each plugin module.


All events can be handled by calling BHModuleManager’s triggerEvent:.
```objectivec

- (void)triggerEvent:(BHModuleEventType)eventType
{
    switch (eventType) {
        case BHMSetupEvent:
            [self handleModuleEvent:kSetupSelector];
            break;
        case BHMInitEvent:
            //special
            [self handleModulesInitEvent];
            break;
        case BHMTearDownEvent:
            //special
            [self handleModulesTearDownEvent];
            break;
        case BHMSplashEvent:
            [self handleModuleEvent:kSplashSeletor];
            break;
        case BHMWillResignActiveEvent:
            [self handleModuleEvent:kWillResignActiveSelector];
            break;
        case BHMDidEnterBackgroundEvent:
            [self handleModuleEvent:kDidEnterBackgroundSelector];
            break;
        case BHMWillEnterForegroundEvent:
            [self handleModuleEvent:kWillEnterForegroundSelector];
            break;
        case BHMDidBecomeActiveEvent:
            [self handleModuleEvent:kDidBecomeActiveSelector];
            break;
        case BHMWillTerminateEvent:
            [self handleModuleEvent:kWillTerminateSelector];
            break;
        case BHMUnmountEvent:
            [self handleModuleEvent:kUnmountEventSelector];
            break;
        case BHMOpenURLEvent:
            [self handleModuleEvent:kOpenURLSelector];
            break;
        case BHMDidReceiveMemoryWarningEvent:
            [self handleModuleEvent:kDidReceiveMemoryWarningSelector];
            break;
            
        case BHMDidReceiveRemoteNotificationEvent:
            [self handleModuleEvent:kDidReceiveRemoteNotificationsSelector];
            break;

        case BHMDidFailToRegisterForRemoteNotificationsEvent:
            [self handleModuleEvent:kFailToRegisterForRemoteNotificationsSelector];
            break;
        case BHMDidRegisterForRemoteNotificationsEvent:
            [self handleModuleEvent:kDidRegisterForRemoteNotificationsSelector];
            break;
            
        case BHMDidReceiveLocalNotificationEvent:
            [self handleModuleEvent:kDidReceiveLocalNotificationsSelector];
            break;
            
        case BHMWillContinueUserActivityEvent:
            [self handleModuleEvent:kWillContinueUserActivitySelector];
            break;
            
        case BHMContinueUserActivityEvent:
            [self handleModuleEvent:kContinueUserActivitySelector];
            break;
            
        case BHMDidFailToContinueUserActivityEvent:
            [self handleModuleEvent:kFailToContinueUserActivitySelector];
            break;
            
        case BHMDidUpdateUserActivityEvent:
            [self handleModuleEvent:kDidUpdateContinueUserActivitySelector];
            break;
            
        case BHMQuickActionEvent:
            [self handleModuleEvent:kQuickActionSelector];
            break;
            
        default:
            [BHContext shareInstance].customEvent = eventType;
            [self handleModuleEvent:kAppCustomSelector];
            break;
    }
}


```
As the code above shows, except for the two special events, `BHMInitEvent` (the initialization event) and `BHMTearDownEvent` (the Module teardown event), all events invoke the `handleModuleEvent:` method. In the `switch-case` above, aside from system events and the `customEvent` in the `default` branch, the remaining events are all application events.
```objectivec

- (void)handleModuleEvent:(NSString *)selectorStr
{
    SEL seletor = NSSelectorFromString(selectorStr);
    [self.BHModules enumerateObjectsUsingBlock:^(id<BHModuleProtocol> moduleInstance, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([moduleInstance respondsToSelector:seletor]) {

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [moduleInstance performSelector:seletor withObject:[BHContext shareInstance]];

#pragma clang diagnostic pop

        [[BHTimeProfiler sharedTimeProfiler] recordEventTime:[NSString stringWithFormat:@"%@ --- %@", [moduleInstance class], NSStringFromSelector(seletor)]];

        }
    }];
}


```
The implementation of `handleModuleEvent:` iterates over the `BHModules` array and calls `performSelector:withObject:` to invoke the corresponding method.

Note that all Modules here must conform to `BHModuleProtocol`; otherwise, they will not be able to receive messages for these events.


#### 3. Business Custom Events


If you feel that system events and general events are not sufficient for your needs, we have also simplified event encapsulation into `BHAppdelgate`. You can extend your own events by inheriting from `BHAppdelegate`.

The `type` of a custom event is `BHMDidCustomEvent = 1000`.

In BeeHive, there is a `tiggerCustomEvent:` method used to handle these events, especially custom events.
```objectivec

- (void)tiggerCustomEvent:(NSInteger)eventType
{
    if(eventType < 1000) {
        return;
    }
    
    [[BHModuleManager sharedManager] triggerEvent:eventType];
}

```
This method only forwards custom events to `BHModuleManager` for processing; it does not respond to any other events.

![](https://img.halfrost.com/Blog/ArticleImage/41_8.png)


### IV. BeeHive Module Calls


In BeeHive, `BHServiceManager` is used to manage the various Protocols. `BHServiceManager` only manages Protocols that have already been registered.

There are three ways to register a Protocol, which correspond one-to-one with the ways to register a Module:


#### 1. Annotation-Based Registration

Use the `BeeHiveService` macro to mark it with an Annotation.
```objectivec

BeeHiveService(HomeServiceProtocol,BHViewController)

```
The `BeeHiveService` macro is defined as follows:
```objectivec


#define BeeHiveService(servicename,impl) \
char * k##servicename##_service BeeHiveDATA(BeehiveServices) = "{ \""#servicename"\" : \""#impl"\"}";


```
`BeeHiveDATA` is also a macro:
```objectivec

#define BeeHiveDATA(sectname) __attribute((used, section("__DATA,"#sectname" ")))


```
Ultimately, after preprocessing, the `BeeHiveService` macro will be fully expanded into the following form:
```objectivec

char * kHomeServiceProtocol_service __attribute((used, section("__DATA,""BeehiveServices"" "))) = "{ \"""HomeServiceProtocol""\" : \"""BHViewController""\"}";

```
This is analogous to registering a Module: the data is also stored in a special section. The underlying mechanism has already been analyzed above, so we won’t repeat it here.

Similarly, by calling the static function BHReadConfiguration, we can obtain the strings for the dictionaries previously registered in the BeehiveServices special section, where each Protocol maps to its corresponding Class.
```objectivec

    "{ \"HomeServiceProtocol\" : \"BHViewController\"}"


```
The array contains JSON strings like these.
```objectivec

+ (NSArray<NSString *> *)AnnotationServices
{
    static NSArray<NSString *> *services = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        services = BHReadConfiguration(BeehiveServiceSectName);
    });
    return services;
}


```
This is a singleton array containing an array of strings for the `Class` dictionary corresponding to the `Protocol` protocols previously placed in the special section; in other words, it is an array of JSON strings.

After obtaining this array, you can register all the `Protocol` protocols.
```objectivec


- (void)registerAnnotationServices
{
    NSArray<NSString *>*services = [BHAnnotation AnnotationServices];
    
    for (NSString *map in services) {
        NSData *jsonData =  [map dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (!error) {
            if ([json isKindOfClass:[NSDictionary class]] && [json allKeys].count) {
                
                NSString *protocol = [json allKeys][0];
                NSString *clsName  = [json allValues][0];
                
                if (protocol && clsName) {
                    [self registerService:NSProtocolFromString(protocol) implClass:NSClassFromString(clsName)];
                }
                
            }
        }
    }

}

```
Because the `services` array stores JSON strings, first convert them into dictionaries, then extract `protocol` and `className` one by one. Finally, call `registerService:implClass:`.
```objectivec


- (void)registerService:(Protocol *)service implClass:(Class)implClass
{
    NSParameterAssert(service != nil);
    NSParameterAssert(implClass != nil);
    
    // Whether impClass conforms to the Protocol protocol
    if (![implClass conformsToProtocol:service] && self.enableException) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ module does not comply with %@ protocol", NSStringFromClass(implClass), NSStringFromProtocol(service)] userInfo:nil];
    }
    
    // Whether the Protocol protocol has already been registered
    if ([self checkValidService:service] && self.enableException) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ protocol has been registed", NSStringFromProtocol(service)] userInfo:nil];
    }
    
    NSMutableDictionary *serviceInfo = [NSMutableDictionary dictionary];
    [serviceInfo setObject:NSStringFromProtocol(service) forKey:kService];
    [serviceInfo setObject:NSStringFromClass(implClass) forKey:kImpl];
    
    [self.lock lock];
    [self.allServices addObject:serviceInfo];
    [self.lock unlock];
}

```
Before registerService:implClass: is registered, two checks are performed: first, whether impClass conforms to the Protocol; second, whether the Protocol has already been registered. If either check fails, an exception is thrown.


If both checks pass, two key-value pairs are added: one with the key @"service" and the Protocol name as the value, and another with the key @“impl” and the Class name as the value. Finally, this dictionary is stored in the allServices array.

When storing the allServices array, a lock must be acquired. The lock used here is NSRecursiveLock, which prevents thread-safety issues caused by recursion.


#### 2. Reading the Local Plist File


Before reading the local Plist file, you need to set up the path first.
```objectivec

[BHContext shareInstance].serviceConfigName = @"BeeHive.bundle/BHService";

```
All BeeHive configuration can be written into `BHContext` and passed along.

![](https://img.halfrost.com/Blog/ArticleImage/41_9.png)


The Plist file must also be formatted as an array containing dictionaries. Each dictionary has two keys: `@"service"` and `@"impl"`.
```objectivec


- (void)registerLocalServices
{
    NSString *serviceConfigName = [BHContext shareInstance].serviceConfigName;
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:serviceConfigName ofType:@"plist"];
    if (!plistPath) {
        return;
    }
    
    NSArray *serviceList = [[NSArray alloc] initWithContentsOfFile:plistPath];
    
    [self.lock lock];
    [self.allServices addObjectsFromArray:serviceList];
    [self.lock unlock];
}


```
Extract the array from the Plist, then add the array to the `allServices` array.

#### 3. Registration in the Load Method

The last way to register a Protocol is to register the Protocol in the Load method.
```objectivec


+ (void)load
{
   [[BeeHive shareInstance] registerService:@protocol(UserTrackServiceProtocol) service:[BHUserTrackViewController class]];
}

```
Call `registerService:service:` in BeeHive to complete the Module registration.
```objectivec


- (void)registerService:(Protocol *)proto service:(Class) serviceClass
{
    [[BHServiceManager sharedManager] registerService:proto implClass:serviceClass];
}

```
The implementation of `registerService:service:` in BeeHive still calls the `BHServiceManager` registration method `registerService:implClass:`. This method was analyzed above, so we won’t repeat it here.

At this point, the three ways to register a Protocol are complete.

When we previously analyzed Module registration, we learned that BeeHive calls the `loadStaticServices` method in `setContext:`.
```objectivec


-(void)loadStaticServices
{
    // Whether exception detection is enabled
    [BHServiceManager sharedManager].enableException = self.enableException;
    
    // Read the Protocols in the local plist file and register them in BHServiceManager's allServices array
    [[BHServiceManager sharedManager] registerLocalServices];
    
    // Read marker data in special sections and register it in BHServiceManager's allServices array
    [[BHServiceManager sharedManager] registerAnnotationServices];
    
}

```
Although we only saw two approaches here, the `allServices` array actually also includes `Protocol`s registered via the `Load` method. So the `allServices` array in fact contains `Protocol`s added through three different registration mechanisms.

Here, there is no final step of initializing the instance as there is when registering a `Module`.

However, `Protocol` has one more method than `Module`: a method that returns the corresponding `Protocol` instance object.

In BeeHive, there is such a method; calling it returns an instance object corresponding to a `Protocol`.
```objectivec

- (id)createService:(Protocol *)proto;

- (id)createService:(Protocol *)proto;
{
    return [[BHServiceManager sharedManager] createService:proto];
}


```
In essence, it calls `BHServiceManager`’s `createService:` method. The implementation of `createService:` is as follows:
```objectivec

- (id)createService:(Protocol *)service
{
    id implInstance = nil;
    
    // Whether the Protocol has already been registered
    if (![self checkValidService:service] && self.enableException) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ protocol does not been registed", NSStringFromProtocol(service)] userInfo:nil];
    }
    
    Class implClass = [self serviceImplClass:service];
    
    if ([[implClass class] respondsToSelector:@selector(shareInstance)])
        implInstance = [[implClass class] shareInstance];
    else
        implInstance = [[implClass alloc] init];
    
    if (![implInstance respondsToSelector:@selector(singleton)]) {
        return implInstance;
    }
    
    NSString *serviceStr = NSStringFromProtocol(service);
    
    // Whether caching is needed
    if ([implInstance singleton]) {
        id protocol = [[BHContext shareInstance] getServiceInstanceFromServiceName:serviceStr];
        
        if (protocol) {
            return protocol;
        } else {
            [[BHContext shareInstance] addServiceWithImplInstance:implInstance serviceName:serviceStr];
        }
        
    } else {
        [[BHContext shareInstance] addServiceWithImplInstance:implInstance serviceName:serviceStr];
    }
    
    return implInstance;
}

```
This method also first checks whether the Protocol has been registered. It then retrieves the corresponding Class from the dictionary. If the Class implements shareInstance, it creates a singleton instance; otherwise, it simply creates a regular object. If it also implements singleton, it can further add the implInstance and serviceStr mapping to BHContext’s servicesByName dictionary for caching. This allows it to be passed along with the context.
```objectivec

id<UserTrackServiceProtocol> v4 = [[BeeHive shareInstance] createService:@protocol(UserTrackServiceProtocol)];
if ([v4 isKindOfClass:[UIViewController class]]) {
    [self registerViewController:(UIViewController *)v4 title:@"Tracking 3" iconName:nil];
}


```
The above is the official example. Calls between Modules can be made this way, which gives you good decoupling.


### V. Some Other Helper Classes

There are also some helper classes not mentioned above, so here is a summary and analysis of them.

BHConfig is also a singleton. It stores a `config` `NSMutableDictionary`. The dictionary maintains some dynamic environment variables and serves as a supplement to `BHContext`.

BHContext is also a singleton. It contains two `NSMutableDictionary` dictionaries: one is `modulesByName`, and the other is `servicesByName`. `BHContext` is mainly used to store various context environments.
```objectivec

@interface BHContext : NSObject

//global env
@property(nonatomic, assign) BHEnvironmentType env;

//global config
@property(nonatomic, strong) BHConfig *config;

//application appkey
@property(nonatomic, strong) NSString *appkey;
//customEvent>=1000
@property(nonatomic, assign) NSInteger customEvent;

@property(nonatomic, strong) UIApplication *application;

@property(nonatomic, strong) NSDictionary *launchOptions;

@property(nonatomic, strong) NSString *moduleConfigName;

@property(nonatomic, strong) NSString *serviceConfigName;

//3D-Touch model

#if __IPHONE_OS_VERSION_MAX_ALLOWED > 80400
@property (nonatomic, strong) BHShortcutItem *touchShortcutItem;

#endif

//OpenURL model
@property (nonatomic, strong) BHOpenURLItem *openURLItem;

//Notifications Remote or Local
@property (nonatomic, strong) BHNotificationsItem *notificationsItem;

//user Activity Model
@property (nonatomic, strong) BHUserActivityItem *userActivityItem;

@end


```
During `application:didFinishLaunchingWithOptions:`, you can initialize a large amount of context information.
```objectivec

    [BHContext shareInstance].application = application;
    [BHContext shareInstance].launchOptions = launchOptions;
    [BHContext shareInstance].moduleConfigName = @"BeeHive.bundle/BeeHive";//Optional, defaults to BeeHive.bundle/BeeHive.plist
    [BHContext shareInstance].serviceConfigName = @"BeeHive.bundle/BHService";

```
BHTimeProfiler is a profiler used for measuring computational time performance.

BHWatchDog can start a thread, configure a handler, and execute that handler at regular intervals.

![](https://img.halfrost.com/Blog/ArticleImage/41_10.png)


### VI. Features That May Still Be Under Improvement

BeeHive enables plugin-oriented programming by handling Events to implement each business module. There are no dependencies between business modules; core and module interact through events, achieving plugin isolation. However, sometimes modules still need to call certain functionality in one another to collaborate and complete a feature.

#### 1. Functionality still needs improvement

There are usually three forms of interface access:

1. Interface-based Service access (as implemented by the Java Spring framework)
2. Export Method based on function calling conventions (PHP extensions, ReactNative’s extension mechanism)
3. URL Route mode based on cross-application interaction (mutual access between iPhone Apps)

BeeHive currently implements only the first approach; the latter two still need further improvement.


#### 2. Decoupling is not yet thorough enough

The advantage of interface-based Service access is that interface changes can be detected at compile time, allowing interface issues to be fixed promptly. The disadvantage is that it depends on the header files defining the interfaces. As the number of modules grows, maintaining interface definitions also involves a certain amount of work.


#### 3. The design can still be improved and optimized

BHServiceManager internally maintains an array, where each element is a dictionary containing two key-value pairs: the Key @"service" with the Value being the Protocol name, and the Key @“impl” with the Value being the Class name. Rather than designing it this way, why not directly use NSMutableDictionary, with Protocol as the Key and Class as the Value? This would reduce the manual loop during lookup.


![](https://img.halfrost.com/Blog/ArticleImage/41_11.gif)


### Conclusion


As an open-source inter-module decoupling solution from Alibaba, BeeHive’s design ideas are well worth learning from. The current version is v1.2.0. I believe that in subsequent version iterations, the functionality will become more complete and the implementation will become more elegant. It is definitely worth looking forward to!


### Update:

Some readers asked why macro expansion produces so many double quotation marks:
```objectivec

#define BeeHiveMod(name) \
class BeeHive; char * k##name##_mod BeeHiveDATA(BeehiveMods) = ""#name"";

#define BeeHiveService(servicename,impl) \
class BeeHive; char * k##servicename##_service BeeHiveDATA(BeehiveServices) = "{ \""#servicename"\" : \""#impl"\"}";

```
First, `#` in a macro means converting what follows into a string. For example, `#servicename` converts the replacement for `servicename` into a string. The extra pair of double quotes around it acts somewhat like a placeholder, separating it from the preceding double quote. If you write `\"#servicename\"` directly, you’ll find that during macro preprocessing, `#servicename` is not treated as a replacement target as a whole. Instead, the entire double-quoted portion is treated as a single string. That prevents us from achieving the intended substitution. So we need to add another layer of double quotes: `"#servicename"`. Finally, in standard JSON, every key and value is enclosed in double quotes, so we add one more outer layer of double quotes escaped with escape characters. This gives us the final form: `\""#servicename"\"`.

After preprocessing substitution, this produces the following result: a lot of double quotes.
```objectivec


char * kShopModule_mod __attribute((used, section("__DATA,""BeehiveMods"" "))) = """ShopModule""";


```


```objectivec

char * kHomeServiceProtocol_service __attribute((used, section("__DATA,""BeehiveServices"" "))) = "{ \"""HomeServiceProtocol""\" : \"""BHViewController""\"}";

```

