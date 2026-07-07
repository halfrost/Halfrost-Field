![](http://upload-images.jianshu.io/upload_images/1194012-2f6a7c6ad0b9531a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


### Preface

As user demands continue to grow, expectations for an app’s user experience are also becoming increasingly high. To better handle various requirements, developers, from a software engineering perspective, have evolved app architectures from the original simple MVC to more complex architectures such as MVVM and VIPER. Choosing an architecture that fits the business is intended to make the project easier to maintain later on.

But users are still not satisfied. They continue to place more and higher demands on developers: not only a high-quality user experience, but also rapid iteration—ideally a new feature every day—and they also want to experience new features without updating the app. To meet user requirements, developers use technologies such as H5, ReactNative, and Weex to refactor existing projects. The project architecture also becomes more complex: vertically, it is layered into a networking layer, UI layer, and data persistence layer; horizontally, each layer is componentized according to business needs. Although doing this makes development more efficient and easier to maintain, how do we decouple the layers, decouple individual screens and components, and reduce coupling between components? How can the entire system maintain the characteristics of “high cohesion and low coupling” no matter how complex it becomes? This series of problems stands before developers and urgently needs to be solved. Today, let’s talk about some ideas for solving this problem.


### Table of Contents

- 1.Introduction
- 2.What problems can App routing solve
- 3.Implementing navigation between Apps
- 4.Routing design between components inside an App
- 5.Pros and cons of each approach
- 6.The best approach


### I. Introduction

The “big frontend” has been developing for many years, and I believe it must have encountered similar problems. Over the past two years, SPA development has been extremely rapid, with React and Vue always at the center of attention. So let’s see how they handle this problem well.


![](http://upload-images.jianshu.io/upload_images/1194012-4fa5a120089e0580.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In SPA single-page applications, routing plays a critical role. The main role of routing is to keep the view and the URL in sync. From a frontend perspective, a view is regarded as a representation of a resource. When users operate on a page, the application switches among several interaction states. Routing can record certain important states, such as when a user browses a website: whether the user is logged in and which page of the site they are visiting. These changes are also recorded in the browser history, allowing users to switch states via the browser’s Back and Forward buttons. In general, users can change the URL by manually entering it or interacting with the page, then send a request to the server synchronously or asynchronously to fetch resources, and redraw the UI after success. The principle is shown below:


![](http://upload-images.jianshu.io/upload_images/1194012-012b64699f6d1222.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


 react-router goes from the incoming location to finally rendering a new UI. The flow is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-7868710ba2a1d637.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There are two sources of location: one is the browser’s Back and Forward navigation, and the other is directly clicking a link. After obtaining a new location object, the internal matchRoutes method of the router matches a subset of the Route component tree against the current location object and obtains nextState. When this.setState(nextState) is called, the Router component can be re-rendered.


This is roughly how the big frontend does it, and we can borrow these ideas on the iOS side. In the diagram above, Back / Forward can in many cases be managed by UINavgation on iOS. So the iOS Router mainly handles the green part.


### II. What Problems Can App Routing Solve


![](http://upload-images.jianshu.io/upload_images/1194012-3626c70bc97e0547.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Since the frontend can solve the synchronization problem between URL and UI in SPAs, what problems can this idea solve in an App?

Consider the following questions: how do we usually solve them elegantly during development?

1.3D Touch functionality or tapping a push notification requires navigating from outside the App to a deeply nested screen inside the App.

For example, WeChat’s 3D Touch can jump directly to “My QR Code”. The “My QR Code” screen is a third-level screen under Me. Or, to take a more extreme case, if the product requirements are even more demanding and require jumping to a tenth-level screen inside the App, how should this be handled?

2.How should a family of in-house Apps navigate to one another?

If you have several Apps of your own and want them to navigate to one another, how should that be handled?

3.How can we eliminate coupling between App components and between App pages?

As the project becomes increasingly complex, the navigation logic among various components and pages becomes more and more interconnected. How can we elegantly eliminate the coupling between components and pages?

4.How can we unify page navigation logic across iOS and Android? Or even unify the way resources are requested across three platforms?

Some modules in the project may mix ReactNative, Weex, and H5 screens. These screens may also invoke Native screens and Native components. So how can we unify the way Web and Native request resources?

5.If dynamically delivered configuration files are used to configure App navigation logic, how can iOS and Android share a single configuration file?

6.If the App has a bug, how can we implement simple hotfix capabilities without using JSPatch?

For example, if an urgent bug suddenly appears after the App goes online, can we dynamically downgrade the page to H5, ReactNative, or Weex? Or directly replace it with a local error screen?

7.How can we perform tracking and analytics for every inter-component call and page navigation? Should we manually write tracking code at every navigation point? Use Runtime AOP?

8.How can we add logical checks, a token mechanism, and risk-control logic in conjunction with grayscale release during each inter-component call?


9.How can the same screen or the same component be invoked from any screen in the App? Can this only be implemented by registering a singleton in AppDelegate?

For example, if something goes wrong in the App, the user may be on any screen. How can we force the user to log out anytime and anywhere? Or force navigation to the same local error screen? Or navigate to the corresponding H5, ReactNative, or Weex screen? How can we present a View to the user anytime, anywhere, from any screen?


All of the above problems can actually be solved by designing a router on the App side. So how do we design a router?


### III. Implementing Navigation Between Apps

Before discussing routing inside an App, let’s first talk about how navigation between different Apps is implemented in the iOS system.


#### 1. URL Scheme Approach

The iOS system supports URL Scheme by default. For details, see the [official documentation](https://developer.apple.com/library/content/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899).

For example, entering the following commands in Safari on an iPhone will automatically open some Apps:
```c

// Open email
mailto://

// Call 110
tel://110

```
Before iOS 9, you only needed to add URL types - URL Schemes to the app’s info.plist, as shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-f76be42afc25b764.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here, a Scheme named com.ios.Qhomer has been added. You could then enter the following in Safari on the iPhone:
```c

com.ios.Qhomer://

```
Then you can open the app directly.

For other common apps, you can download their IPA files from iTunes, unzip them, and use “Show Package Contents” to find the `info.plist` file. Open it, and you’ll find the corresponding URL Scheme inside.
```c

// Mobile QQ
mqq://

// WeChat
weixin://

// Sina Weibo
sinaweibo://

// Ele.me
eleme://

```
![](http://upload-images.jianshu.io/upload_images/1194012-7bf9d12f40e43505.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Of course, some apps are fairly sensitive about URL Scheme invocation; they do not want other apps to be able to invoke them arbitrarily.
```objectivec


- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    NSLog(@"sourceApplication: %@", sourceApplication);
    NSLog(@"URL scheme:%@", [url scheme]);
    NSLog(@"URL query: %@", [url query]);
    
    if ([sourceApplication isEqualToString:@"com.tencent.weixin"]){
        // Allow opening
        return YES;
    }else{
        return NO;
    }
}

```
If the app to be invoked is already running, its lifecycle is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-a36c3d174d449288.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If the app to be invoked is in the background, its lifecycle is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-389be7fe4279db76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Once we understand the lifecycle above, we can prevent arbitrary invocations by some apps by calling [application:openURL:sourceApplication:annotation:](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623073-application).

![](http://upload-images.jianshu.io/upload_images/1194012-92cfad91592aa7b4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-e71403244460b5de.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown above, the Ele.me app allows invocation via URL Scheme, so we can invoke the Ele.me app from Safari. Mobile QQ does not allow invocation, so we cannot jump to it from Safari.


For inter-app navigation, if you are interested, you can refer to the official documentation [Inter-App Communication](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW2).

Apps can also jump directly to system Settings. For example, some requirements involve checking whether the user has enabled certain system permissions; if not, an alert is shown, and tapping the button in the alert jumps directly to the corresponding Settings screen.

[iOS 10 supports jumping to system Settings via URL Scheme](https://www.zhihu.com/question/50635906/answer/125195317)
[The correct way to jump to system Settings in iOS 10](http://www.jianshu.com/p/bb3f42fdbc31)
[A summary list of URLs for iOS system features](http://www.jianshu.com/p/32ca4bcda3d1)


#### 2. Universal Links

Although opening web pages inside WeChat blocks all Schemes, iOS 9.0 introduced a new feature called Universal Links. With this feature, our app can be launched through HTTP links.
1. If the app is installed, the app can be opened whether the http link is inside WeChat, in Safari, or in other third-party browsers.
2. If the app is not installed, the web page will be opened.


The specific setup requires three steps:

1. The app must enable the Associated Domains service and configure Domains. Note that it must start with applinks:.


![](http://upload-images.jianshu.io/upload_images/1194012-9d373eb510316c0a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2. The domain name must support HTTPS.

3. Upload a file in JSON format named apple-app-site-association to the root directory of your domain, or to the .well-known directory. iOS will automatically read this file. For the exact file contents, see the [official documentation](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html).


![](http://upload-images.jianshu.io/upload_images/1194012-2d1b91f5fcb619cd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


If the app supports Universal Links, then other apps can jump directly into our own app. As shown below, when the link is tapped, because the link matches the links we configured, the menu will show an option to open it with our app.

![](http://upload-images.jianshu.io/upload_images/1194012-9e8a7004389c7a53.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The effect is the same in the browser. If Universal Links are supported, accessing the corresponding URL will produce a different result. As shown below:


![](http://upload-images.jianshu.io/upload_images/1194012-69233d229be05d24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The above are the two ways to navigate between apps in iOS.


From the URL Scheme mechanism supported by iOS, we can see that Apple also uses URIs to access resources.

>**Uniform Resource Identifier** (or **URI**) is a [string](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6%E4%B8%B2) used to [identify](https://zh.wikipedia.org/wiki/%E6%A0%87%E8%AF%86) the name of an [Internet](https://zh.wikipedia.org/wiki/%E4%BA%92%E8%81%94%E7%BD%91) [resource](https://zh.wikipedia.org/wiki/%E8%B5%84%E6%BA%90). This type of identifier allows users to interact with resources on a network (generally the [World Wide Web](https://zh.wikipedia.org/wiki/%E4%B8%87%E7%BB%B4%E7%BD%91)) through a specific [protocol](https://zh.wikipedia.org/wiki/%E5%8D%8F%E8%AE%AE). The most common form of URI is the [Uniform Resource Locator](https://zh.wikipedia.org/wiki/%E7%BB%9F%E4%B8%80%E8%B5%84%E6%BA%90%E5%AE%9A%E4%BD%8D%E7%AC%A6) (URL).


For example:

![](http://upload-images.jianshu.io/upload_images/1194012-59139927a45ec117.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This is a URI, and each segment represents its corresponding meaning. Once the other party receives this string, it can parse it according to the rules and obtain all the useful information.


Can this give us some ideas for designing routing between app components? If we want to define a unified way to access resources across three platforms (iOS, Android, and H5), can we implement it using the URI approach?


### IV. Routing Design Between Components Within an App

In the previous section, we introduced how iOS helps us handle inter-app navigation logic. In this section, we focus on how routing between components inside an app should be designed. For internal app routing design, there are mainly two problems to solve:

1. Navigation between different pages and components.
2. Mutual invocation between different components.


Let’s analyze these two problems first.

#### 1. About Page Navigation


![](http://upload-images.jianshu.io/upload_images/1194012-1f01e4fc2f9a6e23.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


During iOS development, you often encounter scenarios such as tapping a button to Push to another screen, or tapping a cell to Present a new ViewController. In the MVC pattern, you usually create a new VC and then Push / Present to the next VC. But in MVVM, some situations become less appropriate.


![](http://upload-images.jianshu.io/upload_images/1194012-35db9020069ee57b.gif?imageMogr2/auto-orient/strip)


As everyone knows, MVVM splits MVC into the form shown above. The data-related code that originally belonged to the View is moved into the ViewModel, and the corresponding C becomes thinner, evolving into an M-VM-C-V structure. The code inside C can be reduced to only the page-navigation-related logic. Expressed in code, it would look like this:


Assume that the execution logic of a button has been encapsulated as a command.
```
    @weakify(self);
    [[[_viewModel.someCommand executionSignals] flatten] subscribeNext:^(id x) {
        @strongify(self);
        // Navigation logic
        [self.navigationController pushViewController:targetViewController animated:YES];
  }];


```
The code above is not problematic in itself, but it may weaken one important role of an MVVM framework.


In addition to decoupling, an MVVM framework has two other very important goals:

1. High code reuse
2. Easier unit testing

If we need to verify whether a business flow is correct, we only need to unit test the ViewModel. The prerequisite is that we assume the UI binding process implemented with ReactiveCocoa is correct. The current binding is correct. Therefore, unit testing up to the ViewModel is enough to complete testing of the business logic.

Page navigation is also part of business logic, so it should be placed in the ViewModel and unit tested together, ensuring coverage of business-logic tests.

There are two ways to put page navigation into the ViewModel. The first is to implement it with routing. The second is unrelated to routing, so I won’t elaborate on it here. If you’re interested, you can look at the concrete implementation of page navigation in the [lpd-mvvm-kit](https://github.com/LPD-iOS/lpd-mvvm-kit) library.


The coupling involved in page navigation becomes apparent:

1. Because `pushViewController` or `presentViewController` both require a ViewController to operate on, that class must be introduced; importing its header file introduces coupling.
2. Because the navigation operation is hard-coded here, if a bug occurs in production, it is not under our control.
3. For push notifications or 3D Touch requirements, if we need to jump directly to an internal level-10 screen, we then need to write an entry point that navigates to the specified screen.


#### 2. About Inter-Component Calls


![](http://upload-images.jianshu.io/upload_images/1194012-03b4d15460bb7449.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Inter-component calls also need to be decoupled. As the business becomes increasingly complex, we encapsulate more and more components. If the granularity of encapsulation is not chosen carefully, a large number of components will end up being highly coupled. Component granularity can be continuously adjusted along with changes in the business, refining the division of component responsibilities. However, calls between components remain unavoidable: components call the interfaces exposed by other components. Reducing the coupling between components is exactly the responsibility of a well-designed router.


#### 3. How to Design a Router


How can we design a router that perfectly solves the two problems above? Let’s first look at the design ideas behind some excellent open-source libraries on GitHub. Below are several routing solutions I found on GitHub, sorted by Star count from high to low. We’ll analyze their respective design approaches one by one.


#### (1) **[JLRoutes](https://github.com/joeldev/JLRoutes)** Star 3189

JLRoutes has the most Stars on GitHub overall, so let’s start by analyzing its concrete design approach.

First of all, JLRoutes is influenced by the idea of URL Scheme. It treats every request for a resource as a URI.

First, let’s get familiar with the various fields of NSURLComponent:

![](http://upload-images.jianshu.io/upload_images/1194012-c1e6a1e29dc04850.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


>Note
The URLs employed by the NSURL
 class are described in [RFC 1808](https://tools.ietf.org/html/rfc1808), [RFC 1738](https://tools.ietf.org/html/rfc1738), and [RFC 2732](https://tools.ietf.org/html/rfc2732).

For every string passed in, JLRoutes splits and processes it in the manner shown above. According to the standards defined by the RFCs, it extracts the various NSURLComponent values.


![](http://upload-images.jianshu.io/upload_images/1194012-37f83ac95de14c1a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


JLRoutes globally stores a Map, where the scheme is the Key and JLRoutes is the Value. Therefore, every scheme in routeControllerMap is unique.

As for why there are so many routes, in my view, if routes are divided by business line, each business line may have different logic. Even if components within each business have the same names, different business lines may have different routing rules.

For example, if Didi were to split its ride-hailing business into components by city, then each city would correspond to one scheme here. The ride-hailing business in every city has features such as requesting a ride, payment, and so on. However, because local regulations differ from city to city, even if these components have the same names, their internal functionality may vary dramatically. Therefore, multiple routes are separated here, which can also be understood as different namespaces.


Each JLRoutes instance stores an array. This array stores each routing rule, JLRRouteDefinition, which contains the block closure passed in from the outside, the pattern, and the pattern after splitting.


Within the array of each JLRoutes instance, routes are ordered by priority, with higher-priority routes placed earlier.
```objectivec


- (void)_registerRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
    JLRRouteDefinition *route = [[JLRRouteDefinition alloc] initWithScheme:self.scheme pattern:routePattern priority:priority handlerBlock:handlerBlock];
    
    if (priority == 0 || self.routes.count == 0) {
        [self.routes addObject:route];
    } else {
        NSUInteger index = 0;
        BOOL addedRoute = NO;
        
        // Find an existing route with lower priority than the route to be inserted
        for (JLRRouteDefinition *existingRoute in [self.routes copy]) {
            if (existingRoute.priority < priority) {
                // If found, insert it into the array
                [self.routes insertObject:route atIndex:index];
                addedRoute = YES;
                break;
            }
            index++;
        }
        
        // If no route with lower priority than the route to be inserted is found, or the last route has the same priority as the current route, insert it at the end.
        if (!addedRoute) {
            [self.routes addObject:route];
        }
    }
}


```
Because the routes in this array form a monotonic queue, when looking up priority, you only need to traverse from high to low.

The route lookup process is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-5b4e7c887c48cce5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


First, initialize a `JLRRouteRequest` from the externally provided URL. Then use this `JLRRouteRequest` to request each route in the current route array in sequence. Each rule generates a response, but only responses that satisfy the conditions will match. Finally, take the matching `JLRRouteResponse` and retrieve the corresponding parameters from its `parameters` dictionary. The key code for lookup and matching is as follows:
```objectivec


- (BOOL)_routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters executeRouteBlock:(BOOL)executeRouteBlock
{
    if (!URL) {
        return NO;
    }
    
    [self _verboseLog:@"Trying to route URL %@", URL];
    
    BOOL didRoute = NO;
    JLRRouteRequest *request = [[JLRRouteRequest alloc] initWithURL:URL];
    
    for (JLRRouteDefinition *route in [self.routes copy]) {
        // Check each route and generate the corresponding response
        JLRRouteResponse *response = [route routeResponseForRequest:request decodePlusSymbols:shouldDecodePlusSymbols];
        if (!response.isMatch) {
            continue;
        }
        
        [self _verboseLog:@"Successfully matched %@", route];
        
        if (!executeRouteBlock) {
            // If execution is not allowed but a matching route response is found.
            return YES;
        }
        
        // Assemble the final parameters
        NSMutableDictionary *finalParameters = [NSMutableDictionary dictionary];
        [finalParameters addEntriesFromDictionary:response.parameters];
        [finalParameters addEntriesFromDictionary:parameters];
        [self _verboseLog:@"Final parameters are %@", finalParameters];
        
        didRoute = [route callHandlerBlockWithParameters:finalParameters];
        
        if (didRoute) {
            // Handler called successfully
            break;
        }
    }
    
    if (!didRoute) {
        [self _verboseLog:@"Could not find a matching route"];
    }
    
    // If no matching route is found in the current route rules, the current route is not global, and fallback to global lookup is allowed, then continue searching the global route rules.
    if (!didRoute && self.shouldFallbackToGlobalRoutes && ![self _isGlobalRoutesController]) {
        [self _verboseLog:@"Falling back to global routes..."];
        didRoute = [[JLRoutes globalRoutes] _routeURL:URL withParameters:parameters executeRouteBlock:executeRouteBlock];
    }
    
    // Finally, if nothing matched and there is an unmatched URL handler, call this block for final handling.

if, after everything, we did not route anything and we have an unmatched URL handler, then call it
    if (!didRoute && executeRouteBlock && self.unmatchedURLHandler) {
        [self _verboseLog:@"Falling back to the unmatched URL handler"];
        self.unmatchedURLHandler(self, URL, parameters);
    }
    
    return didRoute;
}


```
For example:

First, we register a Router with the following rules:
```objectivec


[[JLRoutes globalRoutes] addRoute:@"/:object/:action" handler:^BOOL(NSDictionary *parameters) {
  NSString *object = parameters[@"object"];
  NSString *action = parameters[@"action"];
  // stuff
  return YES;
}];


```
We pass in a URL and let the Router handle it.
```objectivec

NSURL *editPost = [NSURL URLWithString:@"ele://post/halfrost?debug=true&foo=bar"];
[[UIApplication sharedApplication] openURL:editPost];

```
After a successful match, we get a dictionary like this:
```objectivec

{
  "object": "post",
  "action": "halfrost",
  "debug": "true",
  "foo": "bar",
  "JLRouteURL": "ele://post/halfrost?debug=true&foo=bar",
  "JLRoutePattern": "/:object/:action",
  "JLRouteScheme": "JLRoutesGlobalRoutesScheme"
}

```
The process described above is illustrated in the following figure:

![](http://upload-images.jianshu.io/upload_images/1194012-499ad0d66da3a745.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


JLRoutes also supports optional route patterns. Suppose we define the following route pattern:
```c

/the(/foo/:a)(/bar/:b)

```
JLRoutes registers the following four routing rules for us by default:
```c

/the/foo/:a/bar/:b
/the/foo/:a
/the/bar/:b
/the

```

#### (2) **[routable-ios](https://github.com/clayallsopp/routable-ios)** Stars 1415

Routable routing is a URL router used on the in-app native side. It can be used on iOS as well as on [Android](https://github.com/usepropeller/routable-android).


![](http://upload-images.jianshu.io/upload_images/1194012-0543112d4d3bda48.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


UPRouter stores two dictionaries. In the routes dictionary, the keys are routing rules, and the values are UPRouterOptions. In cachedRoutes, the keys are the final URLs, including passed parameters, and the values are RouterParams. RouterParams contains the UPRouterOptions matched in routes, as well as additional opening parameters openParams and other extra parameters extraParams.
```objectivec


- (RouterParams *)routerParamsForUrl:(NSString *)url extraParams: (NSDictionary *)extraParams {
    if (!url) {
        //if we wait, caching this as key would throw an exception
        if (_ignoresExceptions) {
            return nil;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    
    if ([self.cachedRoutes objectForKey:url] && !extraParams) {
        return [self.cachedRoutes objectForKey:url];
    }
    
   // Compare whether the number of params after splitting the url by / matches the number of pathComponents
    NSArray *givenParts = url.pathComponents;
    NSArray *legacyParts = [url componentsSeparatedByString:@"/"];
    if ([legacyParts count] != [givenParts count]) {
        NSLog(@"Routable Warning - your URL %@ has empty path components - this will throw an error in an upcoming release", url);
        givenParts = legacyParts;
    }
    
    __block RouterParams *openParams = nil;
    [self.routes enumerateKeysAndObjectsUsingBlock:
     ^(NSString *routerUrl, UPRouterOptions *routerOptions, BOOL *stop) {
         
         NSArray *routerParts = [routerUrl pathComponents];
         if ([routerParts count] == [givenParts count]) {
             
             NSDictionary *givenParams = [self paramsForUrlComponents:givenParts routerUrlComponents:routerParts];
             if (givenParams) {
                 openParams = [[RouterParams alloc] initWithRouterOptions:routerOptions openParams:givenParams extraParams: extraParams];
                 *stop = YES;
             }
         }
     }];
    
    if (!openParams) {
        if (_ignoresExceptions) {
            return nil;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    [self.cachedRoutes setObject:openParams forKey:url];
    return openParams;
}


```
The main purpose of this code is to iterate over the `routes` dictionary, find the string whose parameters match, wrap it as `RouterParams`, and return it.
```objectivec


- (NSDictionary *)paramsForUrlComponents:(NSArray *)givenUrlComponents routerUrlComponents:(NSArray *)routerUrlComponents {
    
    __block NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [routerUrlComponents enumerateObjectsUsingBlock:
     ^(NSString *routerComponent, NSUInteger idx, BOOL *stop) {
         
         NSString *givenComponent = givenUrlComponents[idx];
         if ([routerComponent hasPrefix:@":"]) {
             NSString *key = [routerComponent substringFromIndex:1];
             [params setObject:givenComponent forKey:key];
         }
         else if (![routerComponent isEqualToString:givenComponent]) {
             params = nil;
             *stop = YES;
         }
     }];
    return params;
}


```
In the function above, the first parameter is a split array of the URL passed in from outside, including all input parameters. The second parameter is an array obtained by splitting the routing rule. Since `routerComponent` specifies that only the part after `:` is a parameter, the first position of `routerComponent` corresponds to the parameter name. In the `params` dictionary, the parameter name is used as the key, and the parameter value as the value.
```objectivec


 NSDictionary *givenParams = [self paramsForUrlComponents:givenParts routerUrlComponents:routerParts];
if (givenParams) {
       openParams = [[RouterParams alloc] initWithRouterOptions:routerOptions openParams:givenParams extraParams: extraParams];
       *stop = YES;
}


```
Finally, through the RouterParams initializer, it uses the UPRouterOptions corresponding to the routing rule, the givenParams parameter dictionary encapsulated in the previous step, and
the second argument of the routerParamsForUrl: extraParams: method as the three initialization arguments to create a RouterParams.
```objectivec

[self.cachedRoutes setObject:openParams forKey:url];

```
In the final step, in the self.cachedRoutes dictionary, the key is the parameterized URL, and the value is RouterParams.


![](http://upload-images.jianshu.io/upload_images/1194012-1a44ce14af0e084a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Finally, convert the matched and encapsulated RouterParams into the corresponding Controller.
```objectivec


- (UIViewController *)controllerForRouterParams:(RouterParams *)params {
    SEL CONTROLLER_CLASS_SELECTOR = sel_registerName("allocWithRouterParams:");
    SEL CONTROLLER_SELECTOR = sel_registerName("initWithRouterParams:");
    UIViewController *controller = nil;
    Class controllerClass = params.routerOptions.openClass;

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([controllerClass respondsToSelector:CONTROLLER_CLASS_SELECTOR]) {
        controller = [controllerClass performSelector:CONTROLLER_CLASS_SELECTOR withObject:[params controllerParams]];
    }
    else if ([params.routerOptions.openClass instancesRespondToSelector:CONTROLLER_SELECTOR]) {
        controller = [[params.routerOptions.openClass alloc] performSelector:CONTROLLER_SELECTOR withObject:[params controllerParams]];
    }

#pragma clang diagnostic pop
    if (!controller) {
        if (_ignoresExceptions) {
            return controller;
        }
        @throw [NSException exceptionWithName:@"RoutableInitializerNotFound"
                                       reason:[NSString stringWithFormat:INVALID_CONTROLLER_FORMAT, NSStringFromClass(controllerClass), NSStringFromSelector(CONTROLLER_CLASS_SELECTOR),  NSStringFromSelector(CONTROLLER_SELECTOR)]
                                     userInfo:nil];
    }
    
    controller.modalTransitionStyle = params.routerOptions.transitionStyle;
    controller.modalPresentationStyle = params.routerOptions.presentationStyle;
    return controller;
}


```
If `Controller` is a class, call `allocWithRouterParams:` to initialize it. If `Controller` is already an instance, call `initWithRouterParams:` to initialize it.

The rough flow of Routable is illustrated below:


![](http://upload-images.jianshu.io/upload_images/1194012-f1b04aee828d5ea0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### （3）**[HHRouter](https://github.com/lightory/HHRouter)**  Star 1277

This is a Router from Bilibili Animation, inspired by [ABRouter](https://github.com/aaronbrethorst/ABRouter) and [Routable iOS](https://github.com/usepropeller/routable-ios).


First, let’s look at HHRouter’s API. The methods it provides are very clear.

ViewController provides two methods. `map` is used to define routing rules, and `matchController` is used to match routing rules. After a successful match, it returns the corresponding `UIViewController`.
```objectivec


- (void)map:(NSString *)route toControllerClass:(Class)controllerClass;
- (UIViewController *)matchController:(NSString *)route;


```
The block closure provides three methods. `map` is also used to define routing rules. `matchBlock` is used to match a route and find the specified block, but it does not invoke that block. `callBlock` finds the specified block and invokes it immediately once found.
```objectivec


- (void)map:(NSString *)route toBlock:(HHRouterBlock)block;

- (HHRouterBlock)matchBlock:(NSString *)route;
- (id)callBlock:(NSString *)route;

```
The difference between matchBlock: and callBlock: is that the former does not automatically invoke the closure. Therefore, after the matchBlock: method finds the corresponding block, you need to invoke it manually if you want to execute it.

In addition to the methods above, HHRouter also provides us with a special method.
```objectivec

- (HHRouteType)canRoute:(NSString *)route;


```
This method is used to find the `RouteType` corresponding to the route rule being executed. There are only three `RouteType` values in total:
```objectivec


typedef NS_ENUM (NSInteger, HHRouteType) {
    HHRouteTypeNone = 0,
    HHRouteTypeViewController = 1,
    HHRouteTypeBlock = 2
};

```
Next, let’s look at how HHRouter manages routing rules. The entire HHRouter is controlled by an NSMutableDictionary *routes.
```objectivec


@interface HHRouter ()
@property (strong, nonatomic) NSMutableDictionary *routes;
@end


```
![](http://upload-images.jianshu.io/upload_images/1194012-43d6dc07d7fc2326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Despite having only this seemingly “simple” dictionary data structure, HHRouter’s routing design is actually quite elegant.
```objectivec


- (void)map:(NSString *)route toBlock:(HHRouterBlock)block
{
    NSMutableDictionary *subRoutes = [self subRoutesToRoute:route];
    subRoutes[@"_"] = [block copy];
}

- (void)map:(NSString *)route toControllerClass:(Class)controllerClass
{
    NSMutableDictionary *subRoutes = [self subRoutesToRoute:route];
    subRoutes[@"_"] = controllerClass;
}


```
The two methods above are the method bodies invoked by the block closure and the ViewController, respectively, to configure routing rules. Whether it is a ViewController or a block closure, when setting rules, they both call the `subRoutesToRoute:` method.
```objectivec


- (NSMutableDictionary *)subRoutesToRoute:(NSString *)route
{
    NSArray *pathComponents = [self pathComponentsFromRoute:route];

    NSInteger index = 0;
    NSMutableDictionary *subRoutes = self.routes;

    while (index < pathComponents.count) {
        NSString *pathComponent = pathComponents[index];
        if (![subRoutes objectForKey:pathComponent]) {
            subRoutes[pathComponent] = [[NSMutableDictionary alloc] init];
        }
        subRoutes = subRoutes[pathComponent];
        index++;
    }
    
    return subRoutes;
}


```
The function above is used to construct the dictionary of route-matching rules.

For example:
```objectivec

[[HHRouter shared] map:@"/user/:userId/"
         toControllerClass:[UserViewController class]];
[[HHRouter shared] map:@"/story/:storyId/"
         toControllerClass:[StoryViewController class]];
[[HHRouter shared] map:@"/user/:userId/story/?a=0"
         toControllerClass:[StoryListViewController class]];

```
After setting three rules, using the method described above to construct the route-matching rule dictionary, the route rule dictionary will look like this:
```vim


{
    story =     {
        ":storyId" =         {
            "_" = StoryViewController;
        };
    };
    user =     {
        ":userId" =         {
            "_" = UserViewController;
            story =             {
                "_" = StoryListViewController;
            };
        };
    };
}

```
After the routing-rule dictionary is generated, it will be traversed when matching is performed.

Suppose a route comes in at this point:
```objectivec

  [[[HHRouter shared] matchController:@"hhrouter20://user/1/"] class],


```
HHRouter handles this route by first matching the leading scheme. If the scheme itself is incorrect, the subsequent matching will fail immediately.

It then performs route matching, and the resulting parameter dictionary is as follows:
```objectivec


{
    "controller_class" = UserViewController;
    route = "/user/1/";
    userId = 1;
}

```
The specific function for matching route parameters is in
```objectivec

- (NSDictionary *)paramsInRoute:(NSString *)route


```
This is implemented in this method. Following the route-matching rules, this method parses all parameters from the incoming URL one by one; anything after the `?` is also parsed into a dictionary. The method is straightforward, so I won’t go into further detail here.

The `ViewController` dictionary also includes two default entries:
```objectivec

"controller_class" = 
route = 

```
The route stores the complete URL that was passed in.

What if the incoming route has a query string appended? Let’s take another look:
```objectivec

[[HHRouter shared] matchController:@"/user/1/?a=b&c=d"]


```
After parsing, the dictionary of all parameters will look like this:
```objectivec

{
    a = b;
    c = d;
    "controller_class" = UserViewController;
    route = "/user/1/?a=b&c=d";
    userId = 1;
}

```
Similarly, what if it’s a block closure?

Again, first add a routing rule for the block closure:
```objectivec


[[HHRouter shared] map:@"/user/add/"
                   toBlock:^id(NSDictionary* params) {
                   }];


```
This rule will generate a dictionary of routing rules.
```objectivec

{
    story =     {
        ":storyId" =         {
            "_" = StoryViewController;
        };
    };
    user =     {
        ":userId" =         {
            "_" = UserViewController;
            story =             {
                "_" = StoryListViewController;
            };
        };
        add =         {
            "_" = "<__NSMallocBlock__: 0x600000240480>";
        };
    };
}


```
Note that “\_” is followed by a block.


There are two ways to match a block closure.
```objectivec

// 1.In the first method, after matching the corresponding block, you still need to manually call the closure once.
    HHRouterBlock block = [[HHRouter shared] matchBlock:@"/user/add/?a=1&b=2"];
    block(nil);


// 2.The second method automatically calls the closure after matching the block.
    [[HHRouter shared] callBlock:@"/user/add/?a=1&b=2"];


```
The matched parameter dictionary is as follows:
```objectivec

{
    a = 1;
    b = 2;
    block = "<__NSMallocBlock__: 0x600000056b90>";
    route = "/user/add/?a=1&b=2";
}


```
The following two entries are added to the `block` dictionary by default:
```objectivec

block = 
route = 

```
The route stores the full URL that was passed in.

The generated parameter dictionary is ultimately bound to the `ViewController` as an Associated Object.
```objectivec


- (void)setParams:(NSDictionary *)paramsDictionary
{
    objc_setAssociatedObject(self, &kAssociatedParamsObjectKey, paramsDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)params
{
    return objc_getAssociatedObject(self, &kAssociatedParamsObjectKey);
}


```
This binding process takes place once the match is complete.
```objectivec


- (UIViewController *)matchController:(NSString *)route
{
    NSDictionary *params = [self paramsInRoute:route];
    Class controllerClass = params[@"controller_class"];

    UIViewController *viewController = [[controllerClass alloc] init];

    if ([viewController respondsToSelector:@selector(setParams:)]) {
        [viewController performSelector:@selector(setParams:)
                             withObject:[params copy]];
    }
    return viewController;
}


```
The final ViewController obtained is also the one we want. The corresponding parameters are all in the dictionary of its bound `params` property.


The process above is illustrated as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-1b1a038ed9120a5b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (4) **[MGJRouter](https://github.com/mogujie/MGJRouter)** Star 633


This is a routing approach from Mogujie.

The origin of this library:

The main issue with JLRoutes is that its URL lookup implementation is not efficient enough: it traverses rather than matches. It also has too many features.

HHRouter’s URL lookup is match-based, so it is more efficient. MGJRouter uses the same approach, but HHRouter is too tightly coupled to ViewController, which reduces flexibility to some extent.

That is how MGJRouter came about.


From the perspective of data structures, MGJRouter is still exactly the same as HHRouter.
```objectivec

@interface MGJRouter ()
@property (nonatomic) NSMutableDictionary *routes;
@end

```
![](http://upload-images.jianshu.io/upload_images/1194012-379b3ab298775280.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


So let’s take a look at what optimizations and improvements it made to HHRouter.


##### 1. MGJRouter supports passing some userinfo when calling openURL
```objectivec

[MGJRouter openURL:@"mgj://category/travel" withUserInfo:@{@"user_id": @1900} completion:nil];


```
Compared with HHRouter, this is merely syntactic sugar in terms of notation. Although HHRouter does not support dictionary parameters, this can be compensated for by using URL query parameters after the URL.
```objectivec


    if (parameters) {
        MGJRouterHandler handler = parameters[@"block"];
        if (completion) {
            parameters[MGJRouterParameterCompletion] = completion;
        }
        if (userInfo) {
            parameters[MGJRouterParameterUserInfo] = userInfo;
        }
        if (handler) {
            [parameters removeObjectForKey:@"block"];
            handler(parameters);
        }
    }


```
MGJRouter handles userInfo by directly wrapping it in the Value corresponding to Key = MGJRouterParameterUserInfo.


##### 2. URLs with Chinese characters are supported.
```objectivec

    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, NSString *obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            parameters[key] = [obj stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }];


```
The only thing to watch out for here is the encoding.


##### 3. Define a global URL Pattern as a Fallback.

This mimics JLRoutes’ idea of automatically falling back to global when no match is found.
```objectivec

    if (parameters) {
        MGJRouterHandler handler = parameters[@"block"];
        if (handler) {
            [parameters removeObjectForKey:@"block"];
            handler(parameters);
        }
    }


```
The `parameters` dictionary first stores the next routing rule, which is held in a block closure. During matching, this handler is retrieved, and matching falls back to this closure to perform the final processing.

##### 4. When OpenURL finishes, a Completion Block can be executed.


In MGJRouter, the author reworked the structure used by the original HHRouter dictionary to store routing rules.
```objectivec

NSString *const MGJRouterParameterURL = @"MGJRouterParameterURL";
NSString *const MGJRouterParameterCompletion = @"MGJRouterParameterCompletion";
NSString *const MGJRouterParameterUserInfo = @"MGJRouterParameterUserInfo";

```
These three keys store the following information respectively:

`MGJRouterParameterURL` stores the full URL that was passed in.  
`MGJRouterParameterCompletion` stores the `completion` closure.  
`MGJRouterParameterUserInfo` stores the `UserInfo` dictionary.

For example:
```objectivec


    [MGJRouter registerURLPattern:@"ele://name/:name" toHandler:^(NSDictionary *routerParameters) {
        void (^completion)(NSString *) = routerParameters[MGJRouterParameterCompletion];
        if (completion) {
            completion(@"Done");
        }
    }];
    
    [MGJRouter openURL:@"ele://name/halfrost/?age=20" withUserInfo:@{@"user_id": @1900} completion:^(id result) {
        NSLog(@"result = %@",result);
    }];


```
The URL above will match successfully, and the generated parameter dictionary structure is as follows:
```objectivec

{
    MGJRouterParameterCompletion = "<__NSGlobalBlock__: 0x107ffe680>";
    MGJRouterParameterURL = "ele://name/halfrost/?age=20";
    MGJRouterParameterUserInfo =     {
        "user_id" = 1900;
    };
    age = 20;
    block = "<__NSMallocBlock__: 0x608000252120>";
    name = halfrost;
}


```

##### 5. URLs Can Be Managed Centrally

This feature is very useful.

If you are not careful with URL handling, URLs can easily end up scattered throughout the project, making them hard to manage. For example, the pattern registered is mgj://beauty/:id, while the URL opened is mgj://beauty/123. If the URL needs to change later, it becomes troublesome to handle and difficult to manage centrally.

Therefore, MGJRouter provides a class method to address this issue.
```objectivec

#define TEMPLATE_URL @"qq://name/:name"

[MGJRouter registerURLPattern:TEMPLATE_URL  toHandler:^(NSDictionary *routerParameters) {
    NSLog(@"routerParameters[name]:%@", routerParameters[@"name"]); // halfrost
}];

[MGJRouter openURL:[MGJRouter generateURLWithPattern:TEMPLATE_URL parameters:@[@"halfrost"]]];
}


```
`generateURLWithPattern:` replaces all `:` occurrences in the macros we define with the subsequent string array values, assigning them in order.


The process illustrated above is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-6d9f7fc2a69bd160.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


To distinguish calls between pages from calls between components, Mogujie came up with a new approach: using a Protocol-based method for inter-component calls.

Each component has an Entry. This Entry mainly does three things:

1. Registers the URLs this component cares about
2. Registers the methods/properties this component can expose for invocation
3. Responds differently at different stages of the App lifecycle

An `openURL` call between pages looks like this:

![](http://upload-images.jianshu.io/upload_images/1194012-202a46e5fe0b00cb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Each component registers with `MGJRouter`. Inter-component calls, or calls from other Apps, can open a screen or invoke a component through the `openURL:` method.


For inter-component calls, Mogujie uses a Protocol-based approach.


![](http://upload-images.jianshu.io/upload_images/1194012-ebb6183e75b7341f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The result of `[ModuleManager registerClass:ClassA forProtocol:ProtocolA]` is that a new mapping is added to the dict maintained inside MM.

The return value of `[ModuleManager classForProtocol:ProtocolA]` is the class corresponding to the protocol in MM’s internal dict. The caller does not need to care what this class actually is; as long as it implements the `ProtocolA` protocol, it can be used directly.

A shared place is needed here to hold these public protocols, namely `PublicProtocl.h` in the diagram.


My guess is that the implementation might look roughly like this:
```objectivec


@interface ModuleProtocolManager : NSObject

+ (void)registServiceProvide:(id)provide forProtocol:(Protocol*)protocol;
+ (id)serviceProvideForProtocol:(Protocol *)protocol;

@end

```
Then this is a singleton, where the various protocols are registered:
```objectivec

@interface ModuleProtocolManager ()

@property (nonatomic, strong) NSMutableDictionary *serviceProvideSource;
@end

@implementation ModuleProtocolManager

+ (ModuleProtocolManager *)sharedInstance
{
    static ModuleProtocolManager * instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _serviceProvideSource = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (void)registServiceProvide:(id)provide forProtocol:(Protocol*)protocol
{
    if (provide == nil || protocol == nil)
        return;
    [[self sharedInstance].serviceProvideSource setObject:provide forKey:NSStringFromProtocol(protocol)];
}

+ (id)serviceProvideForProtocol:(Protocol *)protocol
{
    return [[self sharedInstance].serviceProvideSource objectForKey:NSStringFromProtocol(protocol)];
}


```
`ModuleProtocolManager` uses a dictionary to store each registered protocol. Now let’s take another guess at the implementation of `ModuleEntry`.
```objectivec


#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

@protocol DetailModuleEntryProtocol <NSObject>

@required;
- (UIViewController *)detailViewControllerWithId:(NSString*)Id Name:(NSString *)name;
@end


```
Then each module contains a “connector” that connects to the externally exposed protocol.
```objectivec


#import <Foundation/Foundation.h>

@interface DetailModuleEntry : NSObject
@end


```
In its implementation, you need to import three external files: `ModuleProtocolManager`, `DetailModuleEntryProtocol`, and finally the component or page in the module that needs to be navigated to or invoked.
```objectivec


#import "DetailModuleEntry.h"

#import <DetailModuleEntryProtocol/DetailModuleEntryProtocol.h>

#import <ModuleProtocolManager/ModuleProtocolManager.h>

#import "DetailViewController.h"

@interface DetailModuleEntry()<DetailModuleEntryProtocol>

@end

@implementation DetailModuleEntry

+ (void)load
{
    [ModuleProtocolManager registServiceProvide:[[self alloc] init] forProtocol:@protocol(DetailModuleEntryProtocol)];
}

- (UIViewController *)detailViewControllerWithId:(NSString*)Id Name:(NSString *)name
{
    DetailViewController *detailVC = [[DetailViewController alloc] initWithId:id Name:name];
    return detailVC;
}

@end


```
At this point, the Protocol-based solution is complete. If you need to invoke a component or navigate to a page, simply use the corresponding `ModuleEntryProtocol` to look up the matching `DetailModuleEntry` in the `ModuleProtocolManager` dictionary. Once you have found the `DetailModuleEntry`, you have effectively found the “entry point” for that component or page. Then just pass in the parameters.
```objectivec


- (void)didClickDetailButton:(UIButton *)button
{
    id< DetailModuleEntryProtocol > DetailModuleEntry = [ModuleProtocolManager serviceProvideForProtocol:@protocol(DetailModuleEntryProtocol)];
    UIViewController *detailVC = [DetailModuleEntry detailViewControllerWithId:@“Detail Screen” Name:@“My Cart”];
    [self.navigationController pushViewController:detailVC animated:YES];
    
}


```
This makes it possible to invoke the component or screen.

If components share the same interfaces, these interfaces can be further extracted. The extracted interfaces become “meta-interfaces,” which are sufficient to support an entire component layer.


![](http://upload-images.jianshu.io/upload_images/1194012-122920349fc0ac08.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### （5）**[CTMediator](https://github.com/casatwy/CTMediator)**  Star 803


Next, let’s talk about @casatwy’s approach, which is based on the Mediator pattern.

The traditional Mediator pattern looks like this:


![](http://upload-images.jianshu.io/upload_images/1194012-eae91f827634d37c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In this pattern, every page or component depends on the mediator. The components no longer depend on one another; inter-component calls depend only on the Mediator, while the Mediator still depends on the other components. So is this the final solution?


Let’s see how @casatwy further optimizes it.

The main idea is to use the simple, straightforward Target-Action approach, and to leverage Runtime to solve the decoupling problem.
```objectivec

- (id)performTarget:(NSString *)targetName action:(NSString *)actionName params:(NSDictionary *)params shouldCacheTarget:(BOOL)shouldCacheTarget
{
    
    NSString *targetClassString = [NSString stringWithFormat:@"Target_%@", targetName];
    NSString *actionString = [NSString stringWithFormat:@"Action_%@:", actionName];
    Class targetClass;
    
    NSObject *target = self.cachedTarget[targetClassString];
    if (target == nil) {
        targetClass = NSClassFromString(targetClassString);
        target = [[targetClass alloc] init];
    }
    
    SEL action = NSSelectorFromString(actionString);
    
    if (target == nil) {
        // This is one place to handle unresponsive requests. This demo keeps it simple: if no target can respond, it returns directly. In real development, you can provide a fixed target in advance to step in here and handle such requests.
        return nil;
    }
    
    if (shouldCacheTarget) {
        self.cachedTarget[targetClassString] = target;
    }

    if ([target respondsToSelector:action]) {

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [target performSelector:action withObject:params];

#pragma clang diagnostic pop
    } else {
        // The target may be a Swift object.
        actionString = [NSString stringWithFormat:@"Action_%@WithParams:", actionName];
        action = NSSelectorFromString(actionString);
        if ([target respondsToSelector:action]) {

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [target performSelector:action withObject:params];

#pragma clang diagnostic pop
        } else {
            // This is where unresponsive requests are handled. If there is no response, try calling the corresponding target's notFound method for unified handling.
            SEL action = NSSelectorFromString(@"notFound:");
            if ([target respondsToSelector:action]) {

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                return [target performSelector:action withObject:params];

#pragma clang diagnostic pop
            } else {
                // This is also where unresponsive requests are handled. If notFound is also unavailable, this demo returns directly. In real development, you can use the fixed target mentioned earlier to step in.
                [self.cachedTarget removeObjectForKey:targetClassString];
                return nil;
            }
        }
    }
}


```
`targetName` is the `Object` whose interface is being invoked, `actionName` is the method `SEL` being invoked, `params` contains the parameters, and `shouldCacheTarget` indicates whether caching is needed. If caching is needed, the `target` is stored with `targetClassString` as the key and `target` as the value.

With this refactoring approach, the methods called from the outside are very consistent: they all call `performTarget: action: params: shouldCacheTarget:`. The third parameter is a dictionary, which can carry many parameters as long as the key-value pairs are defined properly. Error handling is also centralized in one place. If the `target` does not exist, or if the `target` cannot respond to the corresponding method, the `Mediator` can handle those errors uniformly.

However, in real-world development, whether for UI calls or inter-component calls, many methods need to be defined in the `Mediator`. Therefore, the author also suggested using `Category` to split up all the methods in the `Mediator`, so that the `Mediator` class does not become overly large.
```objectivec

- (UIViewController *)CTMediator_viewControllerForDetail
{
    UIViewController *viewController = [self performTarget:kCTMediatorTargetA
                                                    action:kCTMediatorActionNativFetchDetailViewController
                                                    params:@{@"key":@"value"}
                                         shouldCacheTarget:NO
                                        ];
    if ([viewController isKindOfClass:[UIViewController class]]) {
        // After the view controller is handed off, the caller can choose to push or present it
        return viewController;
    } else {
        // Handle the exceptional case here; the specific handling depends on the product
        return [[UIViewController alloc] init];
    }
}


- (void)CTMediator_presentImage:(UIImage *)image
{
    if (image) {
        [self performTarget:kCTMediatorTargetA
                     action:kCTMediatorActionNativePresentImage
                     params:@{@"image":image}
          shouldCacheTarget:NO];
    } else {
        // Handle the case where image is nil here; the handling depends on the product
        [self performTarget:kCTMediatorTargetA
                     action:kCTMediatorActionNativeNoImage
                     params:@{@"image":[UIImage imageNamed:@"noImage"]}
          shouldCacheTarget:NO];
    }
}

```
Just put each of these concrete methods in the Category. The invocation pattern is very consistent: they all call the performTarget: action: params: shouldCacheTarget: method.


In the end, the Mediator’s dependency on components is removed. Components no longer depend on one another; inter-component calls depend only on the Mediator, and the Mediator does not depend on any other component.

![](http://upload-images.jianshu.io/upload_images/1194012-33914ebfa0566e2b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (6) Some solutions that are not open source

In addition to the open-source routing solutions above, there are also some well-designed solutions that have not been open sourced. We can analyze and discuss them here.


![](http://upload-images.jianshu.io/upload_images/1194012-5e8372009b87f2ef.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This is the architecture used by Uber’s Rider App.

After Uber discovered some drawbacks of MVC—for example, extremely bloated VCs with tens of thousands of lines, and the inability to perform unit testing—it considered switching the architecture to VIPER. However, VIPER also has certain disadvantages. Because of its iOS-specific structure, iOS has to make certain trade-offs for Android. View-driven application logic means that application state is driven by views, and the entire application is locked onto the view tree. Any change to business logic associated with manipulating application state must go through the Presenter. This exposes business logic, and ultimately causes the view tree and the business tree to be tightly coupled. As a result, it becomes very difficult to implement a Node that contains only business logic, or a Node that contains only view logic.

By improving the VIPER architecture—absorbing its strengths and addressing its weaknesses—Uber formed the new architecture for its Rider App: Riblets (ribs).


![](http://upload-images.jianshu.io/upload_images/1194012-677b5dd3b54ca42c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In this new architecture, even similar logic is split into very small, independent, individually testable components. Each component has a very clear purpose. Using these small pieces of Riblets (ribs), the entire App is eventually assembled into a Riblets (ribs) tree.


Through abstraction, a Riblet (rib) is defined as the following 6 smaller components, each with its own responsibility. A Riblet (rib) further abstracts business logic and view logic.


![](http://upload-images.jianshu.io/upload_images/1194012-fe7d2482d631de4c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


If a Riblet (rib) is designed like this, how is it different from the previous VIPER and MVC architectures? The biggest difference lies in routing.


The Router inside a Riblet (rib) is no longer driven by view logic; it is now driven by business logic. This major change means the entire App is no longer driven by presentation, but by data flow.


Each Riblet consists of a Router, an Interactor, a Builder, and their related components. This is where its name (Router - Interactor - Builder, Rib) comes from. Of course, it can also have optional Presenters and Views. The Router and Interactor handle business logic, while the Presenter and View handle view logic.


Let’s focus on analyzing the responsibilities of routing inside a Riblet.

##### 1. Responsibilities of routing

In the overall App structure tree, routing is responsible for attaching and detaching other child Riblets. The decision itself is passed from the Interactor. During state transitions, when child Riblets are attached or detached, routing also affects the lifecycle of the Interactor. Routing contains only 2 pieces of business logic:

1. Provide methods for attaching and detaching other routes.
2. State transition logic that determines the final state among multiple children.

##### 2. Assembly

Each Riblet has only one pair of Router and Interactor. However, they can have multiple pairs of views. Riblets handle only business logic, not view-related parts. A Riblet can have a single view (one Presenter and one View), multiple views (one Presenter and multiple Views, or multiple Presenters and multiple Views), or even no view at all (no Presenter and no View). This design helps build the business logic tree and also enables good separation from the view tree.

For example, the rider Riblet is a Riblet without a view. It is used to check whether the current user has an active route. If the rider has confirmed a route, this Riblet attaches to the route Riblet. The route Riblet displays the route on the map. If no route has been confirmed, the rider Riblet attaches to the request Riblet. The request Riblet displays a waiting-to-be-called state on the screen. A Riblet like the rider Riblet, which has no view logic at all, separates business logic and plays an important role in driving the App and supporting the modular architecture.


##### 3. How Riblets work


Data flow within a Riblet


![](http://upload-images.jianshu.io/upload_images/1194012-9f854b96f2fd41d5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In this new architecture, data flows in one direction. Data flows from services into a Model Stream, which generates a Model stream. The Model stream then flows from the Model Stream to the Interactor. The Interactor, scheduler, and remote push can all trigger changes in the Service, causing the Model Stream to change. The Model Stream generates immutable models. This enforced requirement means the Interactor can change App state only through the Service layer.

Two examples:

1. Data flows from the backend to the View  
A state change causes the backend server to trigger a push to the App. The data is pushed to the App and then generates an immutable data stream. After the Interactor receives the model, it passes it to the Presenter. The Presenter converts the model into a view model and passes it to the View.

2. Data flows from the View to the backend server  
When the user taps a button, such as the login button, the View triggers a UI event and passes it to the Presenter. The Presenter calls the Interactor’s login method. The Interactor then calls the actual login method of the Service call. After the network request, data is pulled to the backend server.


Data flow between Riblets


![](http://upload-images.jianshu.io/upload_images/1194012-003acf4aae15a5ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


When an Interactor needs to call events from another Riblet while processing business logic, the Interactor needs to connect with the child Interactor. See the 5 steps in the diagram above.

If the call goes from child to parent, the parent Interactor’s interface is usually defined as a listener. If the call goes from parent to child, the child’s interface is usually a delegate, implementing some Protocols from the parent.

In the Riblet solution, the Router is used only to maintain a tree relationship, while the Interactor is the one responsible for deciding and triggering logical transitions between components.


### V. Pros and cons of each solution


![](http://upload-images.jianshu.io/upload_images/1194012-8c99a2bb4fae9914.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From the analysis above, we can see that the design thinking behind routing goes progressively deeper from URLRoute -> Protocol-class -> Target-Action. This is also a process of gradually getting closer to the essence.

#### 1. Pros and cons of the URLRoute registration solution

First, URLRoute may have been inspired by frontend Routers and the way system Apps navigate internally. It requests resources through URLs. Whether the resource is an H5 page, RN, Weex, an iOS screen, or a component, the way resources are requested becomes unified. Parameters can also be carried in the URL, so any screen or component can be invoked. Therefore, this is the easiest approach and also the first one people tend to think of.

URLRoute has many advantages. Its biggest advantage is that the server can dynamically control page navigation, handle error processing uniformly after a page has a problem, and unify the request approach across the three ends: iOS, Android, and H5 / RN / Weex.

However, whether this approach is suitable depends on the needs of different companies. If the company has already completed the scaffolding tools for dynamic server-side delivery, and the frontend has also fulfilled the requirement that Native screens can be replaced at any time with H5 screens for the same business when errors occur, then URLRoute may be more likely to be chosen.

But if the company does not have corresponding H5 replacement screens for failure scenarios, and H5 developers feel this adds to their burden; and if the company has not completed a system for dynamically delivering routing rules from the server, then the company may not adopt URLRoute. This is because the small amount of dynamism URLRoute provides can be achieved with JSPatch. If an online bug occurs, it can be fixed immediately with JSPatch, without using URLRoute.

Therefore, whether to choose URLRoute also depends on the company’s stage of development, staffing, and technology selection.


The URLRoute solution also has some disadvantages. First, URL mapping rules need to be registered, and they are written inside the load method. Writing them in the load method affects App startup performance.

Second, there is a lot of hard coding. The component and page names in URL links are hard coded, and the parameters are also hard coded. In addition, every URL parameter field must be maintained in documentation, which is also a burden for business developers. URL short links are scattered throughout the App, making maintenance quite troublesome. Although Mogujie thought of using macros to manage these links uniformly, that still does not solve the hard-coding problem.


A truly good routing system serves the entire App invisibly. It should be a process that is not perceived by developers. From this perspective, this approach is somewhat lacking.


The final disadvantage is that URLs are not very friendly for passing NSObject parameters. At most, they can pass a dictionary.

#### 2. Pros and cons of the Protocol-Class registration solution


The advantage of the Protocol-Class solution is that it has no hard coding.


The Protocol-Class solution also has some disadvantages: every Protocol must be registered with ModuleManager.

In this solution, ModuleEntry needs to depend on both ModuleManager and the pages or components inside the component. Of course, ModuleEntry also depends on ModuleEntryProtocol, but this dependency can be removed. For example, using the Runtime method NSProtocolFromString plus hard coding can remove the dependency on the Protocol. However, considering that hard coding is not friendly to bugs or later maintenance, the dependency on the Protocol should not be removed.

The final disadvantage is that calls to component methods are scattered everywhere. There is no unified entry point, so it is impossible to handle missing components or errors uniformly.


#### 3. Pros and cons of the Target-Action solution


The advantage of the Target-Action solution is that it fully leverages Runtime features and does not require registration. In the Target-Action solution, there is only one dependency relationship: components depend on the Mediator layer. Categories for the Mediator are maintained in the Mediator; each Category corresponds to a Target, and methods in the Category correspond to Action scenarios. The Target-Action solution also unifies the entry point for all inter-component calls.

The Target-Action solution can also provide a certain degree of safety by validating the Native prefix in the URL.


The disadvantage of the Target-Action solution is that Target_Action packages regular parameters into a dictionary in the Category, and then unpacks the dictionary back into regular parameters at the Target. This introduces some hard coding.


#### 4. How should components be split?

This question should actually be considered before deciding to implement componentization. So why bring it up here? Because every company has its own way of splitting components: split by business line? Split by the smallest business function module? Or split by a complete feature? This involves the granularity of splitting. The granularity of component splitting is directly related to the degree of decoupling future routing will need.

Suppose all login flows are encapsulated into one component. Since login involves multiple pages, all of these pages will be packaged into the same component. When other modules need to access the login state, they need to use the external interface exposed by the login component for obtaining login state. At this point, these interfaces can be written into a Protocol and exposed externally. Alternatively, the Target-Action approach can be used. If an entire feature is divided into a login component like this, the granularity is slightly coarse.


If only the small function of login state is split into an atomic component, then external modules that want to obtain login state can simply call this component directly. This granularity is very fine. It will also result in a huge number of components.


Therefore, when splitting components, perhaps the business is not complex at the time, and splitting it into components does not create much coupling. But as the business keeps changing, coupling between previously split components may become increasingly strong, so you may consider further splitting the previous components. Or perhaps some businesses are cut, and some previously small components may be combined together again. In short, before the business is completely stabilized, component splitting may always be ongoing.

### VI. The best solution


![](http://upload-images.jianshu.io/upload_images/1194012-80d7e39d04c3a0b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Regarding architecture, I think it is meaningless to discuss architecture without considering the business. Architecture serves the business; talking about architecture in isolation is only an idealized state. So there is no best solution, only the most suitable one.

The solution that best fits your company’s business is the best solution. Divide and conquer: choosing different solutions for different businesses is the optimal approach. If you insist on broadly adopting one solution, and different businesses all have to use the same solution, then too many compromises and sacrifices will be required, which is not good.

I hope this article can serve as a starting point and help everyone choose the routing solution most suitable for their own business. Of course, there must be even better solutions out there, and I hope you can offer me more advice.


References:

[Implementing a CTMediator-based componentization solution in an existing project](http://casatwy.com/modulization_in_action.html)  
[Discussion of iOS application architecture: componentization solution](http://casatwy.com/iOS-Modulization.html)  
[Mogujie App’s road to componentization](http://limboy.me/tech/2016/03/10/mgj-components.html)  
[Mogujie App’s road to componentization · continued](http://limboy.me/tech/2016/03/14/mgj-components-continued.html)  
[ENGINEERING THE ARCHITECTURE BEHIND UBER’S NEW RIDER APP](https://eng.uber.com/new-rider-app/)  


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_router/](https://halfrost.com/ios_router/)