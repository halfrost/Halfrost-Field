![](http://upload-images.jianshu.io/upload_images/1194012-2f6a7c6ad0b9531a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





### 前言

随着用户的需求越来越多，对App的用户体验也变的要求越来越高。为了更好的应对各种需求，开发人员从软件工程的角度，将App架构由原来简单的MVC变成MVVM，VIPER等复杂架构。更换适合业务的架构，是为了后期能更好的维护项目。

但是用户依旧不满意，继续对开发人员提出了更多更高的要求，不仅需要高质量的用户体验，还要求快速迭代，最好一天出一个新功能，而且用户还要求不更新就能体验到新功能。为了满足用户需求，于是开发人员就用H5，ReactNative，Weex等技术对已有的项目进行改造。项目架构也变得更加的复杂，纵向的会进行分层，网络层，UI层，数据持久层。每一层横向的也会根据业务进行组件化。尽管这样做了以后会让开发更加有效率，更加好维护，但是如何解耦各层，解耦各个界面和各个组件，降低各个组件之间的耦合度，如何能让整个系统不管多么复杂的情况下都能保持“高内聚，低耦合”的特点？这一系列的问题都摆在开发人员面前，亟待解决。今天就来谈谈解决这个问题的一些思路。


### 目录

- 1.引子
- 2.App路由能解决哪些问题
- 3.App之间跳转实现
- 4.App内组件间路由设计
- 5.各个方案优缺点
- 6.最好的方案


### 一. 引子

大前端发展这么多年了，相信也一定会遇到相似的问题。近两年SPA发展极其迅猛，React 和 Vue一直处于风口浪尖，那我们就看看他们是如何处理好这一问题的。


![](http://upload-images.jianshu.io/upload_images/1194012-4fa5a120089e0580.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





在SPA单页面应用，路由起到了很关键的作用。路由的作用主要是保证视图和 URL 的同步。在前端的眼里看来，视图是被看成是资源的一种表现。当用户在页面中进行操作时，应用会在若干个交互状态中切换，路由则可以记录下某些重要的状态，比如用户查看一个网站，用户是否登录、在访问网站的哪一个页面。而这些变化同样会被记录在浏览器的历史中，用户可以通过浏览器的前进、后退按钮切换状态。总的来说，用户可以通过手动输入或者与页面进行交互来改变 URL，然后通过同步或者异步的方式向服务端发送请求获取资源，成功后重新绘制 UI，原理如下图所示：



![](http://upload-images.jianshu.io/upload_images/1194012-012b64699f6d1222.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



 react-router通过传入的location到最终渲染新的UI，流程如下：



![](http://upload-images.jianshu.io/upload_images/1194012-7868710ba2a1d637.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


location的来源有2种，一种是浏览器的回退和前进，另外一种是直接点了一个链接。新的 location 对象后，路由内部的 matchRoutes 方法会匹配出 Route 组件树中与当前 location 对象匹配的一个子集，并且得到了 nextState，在this.setState(nextState) 时就可以实现重新渲染 Router 组件。



大前端的做法大概是这样的，我们可以把这些思想借鉴到iOS这边来。上图中的Back / Forward 在iOS这边很多情况下都可以被UINavgation所管理。所以iOS的Router主要处理绿色的那一块。





### 二. App路由能解决哪些问题



![](http://upload-images.jianshu.io/upload_images/1194012-3626c70bc97e0547.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)







既然前端能在SPA上解决URL和UI的同步问题，那这种思想可以在App上解决哪些问题呢？

思考如下的问题，平时我们开发中是如何优雅的解决的：

1.3D-Touch功能或者点击推送消息，要求外部跳转到App内部一个很深层次的一个界面。

比如微信的3D-Touch可以直接跳转到“我的二维码”。“我的二维码”界面在我的里面的第三级界面。或者再极端一点，产品需求给了更加变态的需求，要求跳转到App内部第十层的界面，怎么处理？

2.自家的一系列App之间如何相互跳转？

如果自己App有几个，相互之间还想相互跳转，怎么处理？

3.如何解除App组件之间和App页面之间的耦合性？

随着项目越来越复杂，各个组件，各个页面之间的跳转逻辑关联性越来越多，如何能优雅的解除各个组件和页面之间的耦合性？

4.如何能统一iOS和Android两端的页面跳转逻辑？甚至如何能统一三端的请求资源的方式？

项目里面某些模块会混合ReactNative，Weex，H5界面，这些界面还会调用Native的界面，以及Native的组件。那么，如何能统一Web端和Native端请求资源的方式？

5.如果使用了动态下发配置文件来配置App的跳转逻辑，那么如果做到iOS和Android两边只要共用一套配置文件？

6.如果App出现bug了，如何不用JSPatch，就能做到简单的热修复功能？

比如App上线突然遇到了紧急bug，能否把页面动态降级成H5，ReactNative，Weex？或者是直接换成一个本地的错误界面？

7.如何在每个组件间调用和页面跳转时都进行埋点统计？每个跳转的地方都手写代码埋点？利用Runtime AOP ？

8.如何在每个组件间调用的过程中，加入调用的逻辑检查，令牌机制，配合灰度进行风控逻辑？


9.如何在App任何界面都可以调用同一个界面或者同一个组件？只能在AppDelegate里面注册单例来实现？

比如App出现问题了，用户可能在任何界面，如何随时随地的让用户强制登出？或者强制都跳转到同一个本地的error界面？或者跳转到相应的H5，ReactNative，Weex界面？如何让用户在任何界面，随时随地的弹出一个View ？



以上这些问题其实都可以通过在App端设计一个路由来解决。那么我们怎么设计一个路由呢？




### 三. App之间跳转实现

在谈App内部的路由之前，先来谈谈在iOS系统间，不同App之间是怎么实现跳转的。


#### 1. URL Scheme方式

iOS系统是默认支持URL Scheme的，具体见[官方文档](https://developer.apple.com/library/content/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899)。

比如说，在iPhone的Safari浏览器上面输入如下的命令，会自动打开一些App：

```c

// 打开邮箱
mailto://

// 给110拨打电话
tel://110

```

在iOS 9 之前只要在App的info.plist里面添加URL types - URL Schemes，如下图：


![](http://upload-images.jianshu.io/upload_images/1194012-f76be42afc25b764.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这里就添加了一个com.ios.Qhomer的Scheme。这样就可以在iPhone的Safari浏览器上面输入：

```c

com.ios.Qhomer://

```

就可以直接打开这个App了。

关于其他一些常见的App，可以从iTunes里面下载到它的ipa文件，解压，显示包内容里面可以找到info.plist文件，打开它，在里面就可以相应的URL Scheme。

```c

// 手机QQ
mqq://

// 微信
weixin://

// 新浪微博
sinaweibo://

// 饿了么
eleme://

```



![](http://upload-images.jianshu.io/upload_images/1194012-7bf9d12f40e43505.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



当然了，某些App对于调用URL Scheme比较敏感，它们不希望其他的App随意的就调用自己。

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
        // 允许打开
        return YES;
    }else{
        return NO;
    }
}

```



如果待调用的App已经运行了，那么它的生命周期如下：


![](http://upload-images.jianshu.io/upload_images/1194012-a36c3d174d449288.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果待调用的App在后台，那么它的生命周期如下：


![](http://upload-images.jianshu.io/upload_images/1194012-389be7fe4279db76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

明白了上面的生命周期之后，我们就可以通过调用[application:openURL:sourceApplication:annotation:](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623073-application)这个方法，来阻止一些App的随意调用。

![](http://upload-images.jianshu.io/upload_images/1194012-92cfad91592aa7b4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-e71403244460b5de.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


如上图，饿了么App允许通过URL Scheme调用，那么我们可以在Safari里面调用到饿了么App。手机QQ不允许调用，我们在Safari里面也就没法跳转过去。


关于App间的跳转问题，感兴趣的可以查看官方文档[Inter-App Communication](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW2)。

App也是可以直接跳转到系统设置的。比如有些需求要求检测用户有没有开启某些系统权限，如果没有开启就弹框提示，点击弹框的按钮直接跳转到系统设置里面对应的设置界面。

[iOS 10 支持通过 URL Scheme 跳转到系统设置](https://www.zhihu.com/question/50635906/answer/125195317)
[iOS10跳转系统设置的正确姿势](http://www.jianshu.com/p/bb3f42fdbc31)
[关于 iOS 系统功能的 URL 汇总列表](http://www.jianshu.com/p/32ca4bcda3d1)


#### 2. Universal Links方式

虽然在微信内部开网页会禁止所有的Scheme，但是iOS 9.0新增加了一项功能是Universal Links，使用这个功能可以使我们的App通过HTTP链接来启动App。
1.如果安装过App，不管在微信里面http链接还是在Safari浏览器，还是其他第三方浏览器，都可以打开App。
2.如果没有安装过App，就会打开网页。


具体设置需要3步：

1.App需要开启Associated Domains服务，并设置Domains，注意必须要applinks：开头。


![](http://upload-images.jianshu.io/upload_images/1194012-9d373eb510316c0a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2.域名必须要支持HTTPS。

3.上传内容是Json格式的文件，文件名为apple-app-site-association到自己域名的根目录下，或者.well-known目录下。iOS自动会去读取这个文件。具体的文件内容请查看[官方文档](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html)。






![](http://upload-images.jianshu.io/upload_images/1194012-2d1b91f5fcb619cd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





如果App支持了Universal Links方式，那么可以在其他App里面直接跳转到我们自己的App里面。如下图，点击链接，由于该链接会Matcher到我们设置的链接，所以菜单里面会显示用我们的App打开。

![](http://upload-images.jianshu.io/upload_images/1194012-9e8a7004389c7a53.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在浏览器里面也是一样的效果，如果是支持了Universal Links方式，访问相应的URL，会有不同的效果。如下图：


![](http://upload-images.jianshu.io/upload_images/1194012-69233d229be05d24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

以上就是iOS系统中App间跳转的二种方式。


从iOS 系统里面支持的URL Scheme方式，我们可以看出，对于一个资源的访问，苹果也是用URI的方式来访问的。

>**统一资源标识符**（英语：Uniform Resource Identifier，或**URI**)是一个用于[标识](https://zh.wikipedia.org/wiki/%E6%A0%87%E8%AF%86)某一[互联网](https://zh.wikipedia.org/wiki/%E4%BA%92%E8%81%94%E7%BD%91)[资源](https://zh.wikipedia.org/wiki/%E8%B5%84%E6%BA%90)名称的[字符串](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6%E4%B8%B2)。 该种标识允许用户对网络中（一般指[万维网](https://zh.wikipedia.org/wiki/%E4%B8%87%E7%BB%B4%E7%BD%91)）的资源通过特定的[协议](https://zh.wikipedia.org/wiki/%E5%8D%8F%E8%AE%AE)进行交互操作。URI的最常见的形式是[统一资源定位符](https://zh.wikipedia.org/wiki/%E7%BB%9F%E4%B8%80%E8%B5%84%E6%BA%90%E5%AE%9A%E4%BD%8D%E7%AC%A6)（URL）。


举个例子：

![](http://upload-images.jianshu.io/upload_images/1194012-59139927a45ec117.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这是一段URI，每一段都代表了对应的含义。对方接收到了这样一串字符串，按照规则解析出来，就能获取到所有的有用信息。


这个能给我们设计App组件间的路由带来一些思路么？如果我们想要定义一个三端（iOS，Android，H5）的统一访问资源的方式，能用URI的这种方式实现么？


### 四. App内组件间路由设计

上一章节中我们介绍了iOS系统中，系统是如何帮我们处理App间跳转逻辑的。这一章节我们着重讨论一下，App内部，各个组件之间的路由应该怎么设计。关于App内部的路由设计，主要需要解决2个问题：

1.各个页面和组件之间的跳转问题。
2.各个组件之间相互调用。


先来分析一下这两个问题。

#### 1. 关于页面跳转



![](http://upload-images.jianshu.io/upload_images/1194012-1f01e4fc2f9a6e23.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在iOS开发的过程中，经常会遇到以下的场景，点击按钮跳转Push到另外一个界面，或者点击一个cell Present一个新的ViewController。在MVC模式中，一般都是新建一个VC，然后Push / Present到下一个VC。但是在MVVM中，会有一些不合适的情况。



![](http://upload-images.jianshu.io/upload_images/1194012-35db9020069ee57b.gif?imageMogr2/auto-orient/strip)


众所周知，MVVM把MVC拆成了上图演示的样子，原来View对应的与数据相关的代码都移到ViewModel中，相应的C也变瘦了，演变成了M-VM-C-V的结构。这里的C里面的代码可以只剩下页面跳转相关的逻辑。如果用代码表示就是下面这样子：


假设一个按钮的执行逻辑都封装成了command。

```
    @weakify(self);
    [[[_viewModel.someCommand executionSignals] flatten] subscribeNext:^(id x) {
        @strongify(self);
        // 跳转逻辑
        [self.navigationController pushViewController:targetViewController animated:YES];
  }];


```

上述的代码本身没啥问题，但是可能会弱化MVVM框架的一个重要作用。


MVVM框架的目的除去解耦以外，还有2个很重要的目的：

1. 代码高复用率
2. 方便进行单元测试

如果需要测试一个业务是否正确，我们只要对ViewModel进行单元测试即可。前提是假定我们使用ReactiveCocoa进行UI绑定的过程是准确无误的。目前绑定是正确的。所以我们只需要单元测试到ViewModel即可完成业务逻辑的测试。

页面跳转也属于业务逻辑，所以应该放在ViewModel中一起单元测试，保证业务逻辑测试的覆盖率。

把页面跳转放到ViewModel中，有2种做法，第一种就是用路由来实现，第二种由于和路由没有关系，所以这里就不多阐述，有兴趣的可以看[lpd-mvvm-kit](https://github.com/LPD-iOS/lpd-mvvm-kit)这个库关于页面跳转的具体实现。


页面跳转相互的耦合性也就体现出来了：

1.由于pushViewController或者presentViewController，后面都需要带一个待操作的ViewController，那么就必须要引入该类，import头文件也就引入了耦合性。
2.由于跳转这里写死了跳转操作，如果线上一旦出现了bug，这里是不受我们控制的。
3.推送消息或者是3D-Touch需求，要求直接跳转到内部第10级界面，那么就需要写一个入口跳转到指定界面。



#### 2. 关于组件间调用





![](http://upload-images.jianshu.io/upload_images/1194012-03b4d15460bb7449.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

关于组件间的调用，也需要解耦。随着业务越来越复杂，我们封装的组件越来越多，要是封装的粒度拿捏不准，就会出现大量组件之间耦合度高的问题。组件的粒度可以随着业务的调整，不断的调整组件职责的划分。但是组件之间的调用依旧不可避免，相互调用对方组件暴露的接口。如何减少各个组件之间的耦合度，是一个设计优秀的路由的职责所在。




#### 3. 如何设计一个路由


如何设计一个能完美解决上述2个问题的路由，让我们先来看看GitHub上优秀开源库的设计思路。以下是我从Github上面找的一些路由方案，按照Star从高到低排列。依次来分析一下它们各自的设计思路。


#### （1）**[JLRoutes](https://github.com/joeldev/JLRoutes)** Star 3189

JLRoutes在整个Github上面Star最多，那就来从它来分析分析它的具体设计思路。

首先JLRoutes是受URL Scheme思路的影响。它把所有对资源的请求看成是一个URI。

首先来熟悉一下NSURLComponent的各个字段：

![](http://upload-images.jianshu.io/upload_images/1194012-c1e6a1e29dc04850.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


>Note
The URLs employed by the NSURL
 class are described in [RFC 1808](https://tools.ietf.org/html/rfc1808), [RFC 1738](https://tools.ietf.org/html/rfc1738), and [RFC 2732](https://tools.ietf.org/html/rfc2732).

JLRoutes会传入每个字符串，都按照上面的样子进行切分处理，分别根据RFC的标准定义，取到各个NSURLComponent。




![](http://upload-images.jianshu.io/upload_images/1194012-37f83ac95de14c1a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


JLRoutes全局会保存一个Map，这个Map会以scheme为Key，JLRoutes为Value。所以在routeControllerMap里面每个scheme都是唯一的。

至于为何有这么多条路由，笔者认为，如果路由按照业务线进行划分的话，每个业务线可能会有不相同的逻辑，即使每个业务里面的组件名字可能相同，但是由于业务线不同，会有不同的路由规则。

举个例子：如果滴滴按照每个城市的打车业务进行组件化拆分，那么每个城市就对应着这里的每个scheme。每个城市的打车业务都有叫车，付款……等业务，但是由于每个城市的地方法规不相同，所以这些组件即使名字相同，但是里面的功能也许千差万别。所以这里划分出了多个route，也可以理解为不同的命名空间。


在每个JLRoutes里面都保存了一个数组，这个数组里面保存了每个路由规则JLRRouteDefinition里面会保存外部传进来的block闭包，pattern，和拆分之后的pattern。


在每个JLRoutes的数组里面，会按照路由的优先级进行排列，优先级高的排列在前面。

```objectivec


- (void)_registerRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
    JLRRouteDefinition *route = [[JLRRouteDefinition alloc] initWithScheme:self.scheme pattern:routePattern priority:priority handlerBlock:handlerBlock];
    
    if (priority == 0 || self.routes.count == 0) {
        [self.routes addObject:route];
    } else {
        NSUInteger index = 0;
        BOOL addedRoute = NO;
        
        // 找到当前已经存在的一条优先级比当前待插入的路由低的路由
        for (JLRRouteDefinition *existingRoute in [self.routes copy]) {
            if (existingRoute.priority < priority) {
                // 如果找到，就插入数组
                [self.routes insertObject:route atIndex:index];
                addedRoute = YES;
                break;
            }
            index++;
        }
        
        // 如果没有找到任何一条路由比当前待插入的路由低的路由，或者最后一条路由优先级和当前路由一样，那么就只能插入到最后。
        if (!addedRoute) {
            [self.routes addObject:route];
        }
    }
}


```


由于这个数组里面的路由是一个单调队列，所以查找优先级的时候只用从高往低遍历即可。

具体查找路由的过程如下：


![](http://upload-images.jianshu.io/upload_images/1194012-5b4e7c887c48cce5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



首先根据外部传进来的URL初始化一个JLRRouteRequest，然后用这个JLRRouteRequest在当前的路由数组里面依次request，每个规则都会生成一个response，但是只有符合条件的response才会match，最后取出匹配的JLRRouteResponse拿出其字典parameters里面对应的参数就可以了。查找和匹配过程中重要的代码如下：

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
        // 检查每一个route，生成对应的response
        JLRRouteResponse *response = [route routeResponseForRequest:request decodePlusSymbols:shouldDecodePlusSymbols];
        if (!response.isMatch) {
            continue;
        }
        
        [self _verboseLog:@"Successfully matched %@", route];
        
        if (!executeRouteBlock) {
            // 如果我们被要求不允许执行，但是又找了匹配的路由response。
            return YES;
        }
        
        // 装配最后的参数
        NSMutableDictionary *finalParameters = [NSMutableDictionary dictionary];
        [finalParameters addEntriesFromDictionary:response.parameters];
        [finalParameters addEntriesFromDictionary:parameters];
        [self _verboseLog:@"Final parameters are %@", finalParameters];
        
        didRoute = [route callHandlerBlockWithParameters:finalParameters];
        
        if (didRoute) {
            // 调用Handler成功
            break;
        }
    }
    
    if (!didRoute) {
        [self _verboseLog:@"Could not find a matching route"];
    }
    
    // 如果在当前路由规则里面没有找到匹配的路由，当前路由不是global 的，并且允许降级到global里面去查找，那么我们继续在global的路由规则里面去查找。
    if (!didRoute && self.shouldFallbackToGlobalRoutes && ![self _isGlobalRoutesController]) {
        [self _verboseLog:@"Falling back to global routes..."];
        didRoute = [[JLRoutes globalRoutes] _routeURL:URL withParameters:parameters executeRouteBlock:executeRouteBlock];
    }
    
    // 最后，依旧没有找到任何能匹配的，如果有unmatched URL handler，调用这个闭包进行最后的处理。

if, after everything, we did not route anything and we have an unmatched URL handler, then call it
    if (!didRoute && executeRouteBlock && self.unmatchedURLHandler) {
        [self _verboseLog:@"Falling back to the unmatched URL handler"];
        self.unmatchedURLHandler(self, URL, parameters);
    }
    
    return didRoute;
}


```


举个例子：

我们先注册一个Router，规则如下：

```objectivec



[[JLRoutes globalRoutes] addRoute:@"/:object/:action" handler:^BOOL(NSDictionary *parameters) {
  NSString *object = parameters[@"object"];
  NSString *action = parameters[@"action"];
  // stuff
  return YES;
}];


```


我们传入一个URL，让Router进行处理。

```objectivec

NSURL *editPost = [NSURL URLWithString:@"ele://post/halfrost?debug=true&foo=bar"];
[[UIApplication sharedApplication] openURL:editPost];

```


匹配成功之后，我们会得到下面这样一个字典：

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

把上述过程图解出来，见下图：

![](http://upload-images.jianshu.io/upload_images/1194012-499ad0d66da3a745.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


JLRoutes还可以支持Optional的路由规则，假如定义一条路由规则：

```c

/the(/foo/:a)(/bar/:b)

```

JLRoutes 会帮我们默认注册如下4条路由规则：

```c

/the/foo/:a/bar/:b
/the/foo/:a
/the/bar/:b
/the

```


#### （2）**[routable-ios](https://github.com/clayallsopp/routable-ios)** Star 1415

Routable路由是用在in-app native端的 URL router, 它可以用在iOS上也可以用在[Android](https://github.com/usepropeller/routable-android)上。




![](http://upload-images.jianshu.io/upload_images/1194012-0543112d4d3bda48.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


UPRouter里面保存了2个字典。routes字典里面存储的Key是路由规则，Value存储的是UPRouterOptions。cachedRoutes里面存储的Key是最终的URL，带传参的，Value存储的是RouterParams。RouterParams里面会包含在routes匹配的到的UPRouterOptions，还有额外的打开参数openParams和一些额外参数extraParams。


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
    
   // 比对url通过/分割之后的参数个数和pathComponents的个数是否一样
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

这一段代码里面重点在干一件事情，遍历routes字典，然后找到参数匹配的字符串，封装成RouterParams返回。


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


上面这段函数，第一个参数是外部传进来URL带有各个入参的分割数组。第二个参数是路由规则分割开的数组。routerComponent由于规定：号后面才是参数，所以routerComponent的第1个位置就是对应的参数名。params字典里面以参数名为Key，参数为Value。



```objectivec


 NSDictionary *givenParams = [self paramsForUrlComponents:givenParts routerUrlComponents:routerParts];
if (givenParams) {
       openParams = [[RouterParams alloc] initWithRouterOptions:routerOptions openParams:givenParams extraParams: extraParams];
       *stop = YES;
}


```

最后通过RouterParams的初始化方法，把路由规则对应的UPRouterOptions，上一步封装好的参数字典givenParams，还有
routerParamsForUrl: extraParams: 方法的第二个入参，这3个参数作为初始化参数，生成了一个RouterParams。

```objectivec

[self.cachedRoutes setObject:openParams forKey:url];

```

最后一步self.cachedRoutes的字典里面Key为带参数的URL，Value是RouterParams。




![](http://upload-images.jianshu.io/upload_images/1194012-1a44ce14af0e084a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


最后将匹配封装出来的RouterParams转换成对应的Controller。

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

如果Controller是一个类，那么就调用allocWithRouterParams:方法去初始化。如果Controller已经是一个实例了，那么就调用initWithRouterParams:方法去初始化。

将Routable的大致流程图解如下：


![](http://upload-images.jianshu.io/upload_images/1194012-f1b04aee828d5ea0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)











#### （3）**[HHRouter](https://github.com/lightory/HHRouter)**  Star 1277

这是布丁动画的一个Router，灵感来自于 [ABRouter](https://github.com/aaronbrethorst/ABRouter) 和 [Routable iOS](https://github.com/usepropeller/routable-ios)。


先来看看HHRouter的Api。它提供的方法非常清晰。

ViewController提供了2个方法。map是用来设置路由规则，matchController是用来匹配路由规则的，匹配争取之后返回对应的UIViewController。

```objectivec


- (void)map:(NSString *)route toControllerClass:(Class)controllerClass;
- (UIViewController *)matchController:(NSString *)route;



```

block闭包提供了三个方法，map也是设置路由规则，matchBlock：是用来匹配路由，找到指定的block，但是不会调用该block。callBlock:是找到指定的block，找到以后就立即调用。

```objectivec


- (void)map:(NSString *)route toBlock:(HHRouterBlock)block;

- (HHRouterBlock)matchBlock:(NSString *)route;
- (id)callBlock:(NSString *)route;

```

matchBlock:和callBlock:的区别就在于前者不会自动调用闭包。所以matchBlock:方法找到对应的block之后，如果想调用，需要手动调用一次。



除去上面这些方法，HHRouter还为我们提供了一个特殊的方法。

```objectivec

- (HHRouteType)canRoute:(NSString *)route;



```

这个方法就是用来找到执行路由规则对应的RouteType，RouteType总共就3种:

```objectivec


typedef NS_ENUM (NSInteger, HHRouteType) {
    HHRouteTypeNone = 0,
    HHRouteTypeViewController = 1,
    HHRouteTypeBlock = 2
};

```


再来看看HHRouter是如何管理路由规则的。整个HHRouter就是由一个NSMutableDictionary *routes控制的。

```objectivec


@interface HHRouter ()
@property (strong, nonatomic) NSMutableDictionary *routes;
@end


```




![](http://upload-images.jianshu.io/upload_images/1194012-43d6dc07d7fc2326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



别看只有这一个看似“简单”的字典数据结构，但是HHRouter路由设计的还是很精妙的。








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

上面两个方法分别是block闭包和ViewController设置路由规则调用的方法实体。不管是ViewController还是block闭包，设置规则的时候都会调用subRoutesToRoute:方法。

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


上面这段函数就是来构造路由匹配规则的字典。

举个例子：

```objectivec

[[HHRouter shared] map:@"/user/:userId/"
         toControllerClass:[UserViewController class]];
[[HHRouter shared] map:@"/story/:storyId/"
         toControllerClass:[StoryViewController class]];
[[HHRouter shared] map:@"/user/:userId/story/?a=0"
         toControllerClass:[StoryListViewController class]];

```

设置3条规则以后，按照上面构造路由匹配规则的字典的方法，该路由规则字典就会变成这个样子：


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


路由规则字典生成之后，等到匹配的时候就会遍历这个字典。



假设这时候有一条路由过来：

```objectivec

  [[[HHRouter shared] matchController:@"hhrouter20://user/1/"] class],


```

HHRouter对这条路由的处理方式是先匹配前面的scheme，如果连scheme都不正确的话，会直接导致后面匹配失败。

然后再进行路由匹配，最后生成的参数字典如下：

```objectivec


{
    "controller_class" = UserViewController;
    route = "/user/1/";
    userId = 1;
}

```

具体的路由参数匹配的函数在

```objectivec

- (NSDictionary *)paramsInRoute:(NSString *)route


```

这个方法里面实现的。这个方法就是按照路由匹配规则，把传进来的URL的参数都一一解析出来，带？号的也都会解析成字典。这个方法没什么难度，就不在赘述了。

ViewController 的字典里面默认还会加上2项：


```objectivec

"controller_class" = 
route = 

```

route里面都会保存传过来的完整的URL。


如果传进来的路由后面带访问字符串呢？那我们再来看看：

```objectivec

[[HHRouter shared] matchController:@"/user/1/?a=b&c=d"]


```


那么解析出所有的参数字典会是下面的样子：

```objectivec

{
    a = b;
    c = d;
    "controller_class" = UserViewController;
    route = "/user/1/?a=b&c=d";
    userId = 1;
}

```


同理，如果是一个block闭包的情况呢？

还是先添加一条block闭包的路由规则：


```objectivec


[[HHRouter shared] map:@"/user/add/"
                   toBlock:^id(NSDictionary* params) {
                   }];


```

这条规则对应的会生成一个路由规则的字典。

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

注意”\_”后面跟着是一个block。


匹配block闭包的方式有两种。

```objectivec

// 1.第一种方式匹配到对应的block之后，还需要手动调用一次闭包。
    HHRouterBlock block = [[HHRouter shared] matchBlock:@"/user/add/?a=1&b=2"];
    block(nil);


// 2.第二种方式匹配block之后自动会调用改闭包。
    [[HHRouter shared] callBlock:@"/user/add/?a=1&b=2"];


```


匹配出来的参数字典是如下：

```objectivec

{
    a = 1;
    b = 2;
    block = "<__NSMallocBlock__: 0x600000056b90>";
    route = "/user/add/?a=1&b=2";
}


```



block的字典里面会默认加上下面这2项：

```objectivec

block = 
route = 

```

route里面都会保存传过来的完整的URL。



生成的参数字典最终会被绑定到ViewController的Associated Object关联对象上。


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


这个绑定的过程是在match匹配完成的时候进行的。

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


最终得到的ViewController也是我们想要的。相应的参数都在它绑定的params属性的字典里面。



将上述过程图解出来，如下：


![](http://upload-images.jianshu.io/upload_images/1194012-1b1a038ed9120a5b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




#### （4）**[MGJRouter](https://github.com/mogujie/MGJRouter)** Star 633


这是蘑菇街的一个路由的方法。

这个库的由来：

JLRoutes 的问题主要在于查找 URL 的实现不够高效，通过遍历而不是匹配。还有就是功能偏多。

HHRouter 的 URL 查找是基于匹配，所以会更高效，MGJRouter 也是采用的这种方法，但它跟 ViewController 绑定地过于紧密，一定程度上降低了灵活性。

于是就有了 MGJRouter。


从数据结构来看，MGJRouter还是和HHRouter一模一样的。

```objectivec

@interface MGJRouter ()
@property (nonatomic) NSMutableDictionary *routes;
@end

```



![](http://upload-images.jianshu.io/upload_images/1194012-379b3ab298775280.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



那么我们就来看看它对HHRouter做了哪些优化改进。


##### 1.MGJRouter支持openURL时，可以传一些 userinfo 过去

```objectivec

[MGJRouter openURL:@"mgj://category/travel" withUserInfo:@{@"user_id": @1900} completion:nil];


```


这个对比HHRouter，仅仅只是写法上的一个语法糖，在HHRouter中虽然不支持带字典的参数，但是在URL后面可以用URL Query Parameter来弥补。



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

MGJRouter对userInfo的处理是直接把它封装到Key = MGJRouterParameterUserInfo对应的Value里面。


##### 2.支持中文的URL。


```objectivec

    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, NSString *obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            parameters[key] = [obj stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }];


```


这里就是需要注意一下编码。


##### 3.定义一个全局的 URL Pattern 作为 Fallback。

这一点是模仿的JLRoutes的匹配不到会自动降级到global的思想。

```objectivec

    if (parameters) {
        MGJRouterHandler handler = parameters[@"block"];
        if (handler) {
            [parameters removeObjectForKey:@"block"];
            handler(parameters);
        }
    }


```

parameters字典里面会先存储下一个路由规则，存在block闭包中，在匹配的时候会取出这个handler，降级匹配到这个闭包中，进行最终的处理。

##### 4.当 OpenURL 结束时，可以执行 Completion Block。


在MGJRouter里面，作者对原来的HHRouter字典里面存储的路由规则的结构进行了改造。

```objectivec

NSString *const MGJRouterParameterURL = @"MGJRouterParameterURL";
NSString *const MGJRouterParameterCompletion = @"MGJRouterParameterCompletion";
NSString *const MGJRouterParameterUserInfo = @"MGJRouterParameterUserInfo";

```

这3个key会分别保存一些信息：

MGJRouterParameterURL保存的传进来的完整的URL信息。
MGJRouterParameterCompletion保存的是completion闭包。
MGJRouterParameterUserInfo保存的是UserInfo字典。




举个例子：

```objectivec


    [MGJRouter registerURLPattern:@"ele://name/:name" toHandler:^(NSDictionary *routerParameters) {
        void (^completion)(NSString *) = routerParameters[MGJRouterParameterCompletion];
        if (completion) {
            completion(@"完成了");
        }
    }];
    
    [MGJRouter openURL:@"ele://name/halfrost/?age=20" withUserInfo:@{@"user_id": @1900} completion:^(id result) {
        NSLog(@"result = %@",result);
    }];


```


上面的URL会匹配成功，那么生成的参数字典结构如下：

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


##### 5.可以统一管理URL

这个功能非常有用。

URL 的处理一不小心，就容易散落在项目的各个角落，不容易管理。比如注册时的 pattern 是 mgj://beauty/:id，然后 open 时就是 mgj://beauty/123，这样到时候 url 有改动，处理起来就会很麻烦，不好统一管理。

所以 MGJRouter 提供了一个类方法来处理这个问题。


```objectivec

#define TEMPLATE_URL @"qq://name/:name"

[MGJRouter registerURLPattern:TEMPLATE_URL  toHandler:^(NSDictionary *routerParameters) {
    NSLog(@"routerParameters[name]:%@", routerParameters[@"name"]); // halfrost
}];

[MGJRouter openURL:[MGJRouter generateURLWithPattern:TEMPLATE_URL parameters:@[@"halfrost"]]];
}


```

generateURLWithPattern:函数会对我们定义的宏里面的所有的:进行替换，替换成后面的字符串数组，依次赋值。



将上述过程图解出来，如下：

![](http://upload-images.jianshu.io/upload_images/1194012-6d9f7fc2a69bd160.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



蘑菇街为了区分开页面间调用和组件间调用，于是想出了一种新的方法。用Protocol的方法来进行组件间的调用。

每个组件之间都有一个 Entry，这个 Entry，主要做了三件事：

1. 注册这个组件关心的 URL
2. 注册这个组件能够被调用的方法/属性
3. 在 App 生命周期的不同阶段做不同的响应

页面间的openURL调用就是如下的样子：

![](http://upload-images.jianshu.io/upload_images/1194012-202a46e5fe0b00cb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


每个组件间都会向MGJRouter注册，组件间相互调用或者是其他的App都可以通过openURL:方法打开一个界面或者调用一个组件。


在组件间的调用，蘑菇街采用了Protocol的方式。


![](http://upload-images.jianshu.io/upload_images/1194012-ebb6183e75b7341f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



[ModuleManager registerClass:ClassA forProtocol:ProtocolA] 的结果就是在 MM 内部维护的 dict 里新加了一个映射关系。

[ModuleManager classForProtocol:ProtocolA] 的返回结果就是之前在 MM 内部 dict 里 protocol 对应的 class，使用方不需要关心这个 class 是个什么东东，反正实现了 ProtocolA 协议，拿来用就行。

这里需要有一个公共的地方来容纳这些 public protocl，也就是图中的 PublicProtocl.h。


我猜测，大概实现可能是下面的样子：

```objectivec


@interface ModuleProtocolManager : NSObject

+ (void)registServiceProvide:(id)provide forProtocol:(Protocol*)protocol;
+ (id)serviceProvideForProtocol:(Protocol *)protocol;

@end

```


然后这个是一个单例，在里面注册各个协议：

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


在ModuleProtocolManager中用一个字典保存每个注册的protocol。现在再来猜猜ModuleEntry的实现。


```objectivec


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol DetailModuleEntryProtocol <NSObject>

@required;
- (UIViewController *)detailViewControllerWithId:(NSString*)Id Name:(NSString *)name;
@end


```


然后每个模块内都有一个和暴露到外面的协议相连接的“接头”。

```objectivec


#import <Foundation/Foundation.h>

@interface DetailModuleEntry : NSObject
@end


```

在它的实现中，需要引入3个外部文件，一个是ModuleProtocolManager，一个是DetailModuleEntryProtocol，最后一个是所在模块需要跳转或者调用的组件或者页面。

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


至此基于Protocol的方案就完成了。如果需要调用某个组件或者跳转某个页面，只要先从ModuleProtocolManager的字典里面根据对应的ModuleEntryProtocol找到对应的DetailModuleEntry，找到了DetailModuleEntry就是找到了组件或者页面的“入口”了。再把参数传进去即可。

```objectivec



- (void)didClickDetailButton:(UIButton *)button
{
    id< DetailModuleEntryProtocol > DetailModuleEntry = [ModuleProtocolManager serviceProvideForProtocol:@protocol(DetailModuleEntryProtocol)];
    UIViewController *detailVC = [DetailModuleEntry detailViewControllerWithId:@“详情界面” Name:@“我的购物车”];
    [self.navigationController pushViewController:detailVC animated:YES];
    
}


```


这样就可以调用到组件或者界面了。

如果组件之间有相同的接口，那么还可以进一步的把这些接口都抽离出来。这些抽离出来的接口变成“元接口”，它们是可以足够支撑起整个组件一层的。




![](http://upload-images.jianshu.io/upload_images/1194012-122920349fc0ac08.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



#### （5）**[CTMediator](https://github.com/casatwy/CTMediator)**  Star 803



再来说说@casatwy的方案，这方案是基于Mediator的。

传统的中间人Mediator的模式是这样的：



![](http://upload-images.jianshu.io/upload_images/1194012-eae91f827634d37c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





这种模式每个页面或者组件都会依赖中间者，各个组件之间互相不再依赖，组件间调用只依赖中间者Mediator，Mediator还是会依赖其他组件。那么这是最终方案了么？


看看@casatwy是怎么继续优化的。

主要思想是利用了Target-Action简单粗暴的思想，利用Runtime解决解耦的问题。


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
        // 这里是处理无响应请求的地方之一，这个demo做得比较简单，如果没有可以响应的target，就直接return了。实际开发过程中是可以事先给一个固定的target专门用于在这个时候顶上，然后处理这种请求的
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
        // 有可能target是Swift对象
        actionString = [NSString stringWithFormat:@"Action_%@WithParams:", actionName];
        action = NSSelectorFromString(actionString);
        if ([target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [target performSelector:action withObject:params];
#pragma clang diagnostic pop
        } else {
            // 这里是处理无响应请求的地方，如果无响应，则尝试调用对应target的notFound方法统一处理
            SEL action = NSSelectorFromString(@"notFound:");
            if ([target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                return [target performSelector:action withObject:params];
#pragma clang diagnostic pop
            } else {
                // 这里也是处理无响应请求的地方，在notFound都没有的时候，这个demo是直接return了。实际开发过程中，可以用前面提到的固定的target顶上的。
                [self.cachedTarget removeObjectForKey:targetClassString];
                return nil;
            }
        }
    }
}



```


targetName就是调用接口的Object，actionName就是调用方法的SEL，params是参数，shouldCacheTarget代表是否需要缓存，如果需要缓存就把target存起来，Key是targetClassString，Value是target。


通过这种方式进行改造的，外面调用的方法都很统一，都是调用performTarget: action: params: shouldCacheTarget:。第三个参数是一个字典，这个字典里面可以传很多参数，只要Key-Value写好就可以了。处理错误的方式也统一在一个地方了，target没有，或者是target无法响应相应的方法，都可以在Mediator这里进行统一出错处理。

但是在实际开发过程中，不管是界面调用，组件间调用，在Mediator中需要定义很多方法。于是作者又想出了建议我们用Category的方法，对Mediator的所有方法进行拆分，这样就就可以不会导致Mediator这个类过于庞大了。


```objectivec

- (UIViewController *)CTMediator_viewControllerForDetail
{
    UIViewController *viewController = [self performTarget:kCTMediatorTargetA
                                                    action:kCTMediatorActionNativFetchDetailViewController
                                                    params:@{@"key":@"value"}
                                         shouldCacheTarget:NO
                                        ];
    if ([viewController isKindOfClass:[UIViewController class]]) {
        // view controller 交付出去之后，可以由外界选择是push还是present
        return viewController;
    } else {
        // 这里处理异常场景，具体如何处理取决于产品
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
        // 这里处理image为nil的场景，如何处理取决于产品
        [self performTarget:kCTMediatorTargetA
                     action:kCTMediatorActionNativeNoImage
                     params:@{@"image":[UIImage imageNamed:@"noImage"]}
          shouldCacheTarget:NO];
    }
}

```

把这些具体的方法一个个的都写在Category里面就好了，调用的方式都非常的一致，都是调用performTarget: action: params: shouldCacheTarget:方法。


最终去掉了中间者Mediator对组件的依赖，各个组件之间互相不再依赖，组件间调用只依赖中间者Mediator，Mediator不依赖其他任何组件。

![](http://upload-images.jianshu.io/upload_images/1194012-33914ebfa0566e2b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



#### （6）一些并没有开源的方案

除了上面开源的路由方案，还有一些并没有开源的设计精美的方案。这里可以和大家一起分析交流一下。



![](http://upload-images.jianshu.io/upload_images/1194012-5e8372009b87f2ef.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



这个方案是Uber 骑手App的一个方案。

Uber在发现MVC的一些弊端之后：比如动辄上万行巨胖无比的VC，无法进行单元测试等缺点后，于是考虑把架构换成VIPER。但是VIPER也有一定的弊端。因为它的iOS特定的结构，意味着iOS必须为Android做出一些妥协的权衡。以视图为驱动的应用程序逻辑，代表应用程序状态由视图驱动，整个应用程序都锁定在视图树上。由操作应用程序状态所关联的业务逻辑的改变，就必须经过Presenter。因此会暴露业务逻辑。最终导致了视图树和业务树进行了紧紧的耦合。这样想实现一个紧紧只有业务逻辑的Node节点或者紧紧只有视图逻辑的Node节点就非常的困难了。

通过改进VIPER架构，吸收其优秀的特点，改进其缺点，就形成了Uber 骑手App的全新架构——Riblets(肋骨)。





![](http://upload-images.jianshu.io/upload_images/1194012-677b5dd3b54ca42c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在这个新的架构中，即使是相似的逻辑也会被区分成很小很小，相互独立，可以单独进行测试的组件。每个组件都有非常明确的用途。使用这些一小块一小块的Riblets(肋骨)，最终把整个App拼接成一颗Riblets(肋骨)树。


通过抽象，一个Riblets(肋骨)被定义成一下6个更小的组件，这些组件各自有各自的职责。通过一个Riblets(肋骨)进一步的抽象业务逻辑和视图逻辑。



![](http://upload-images.jianshu.io/upload_images/1194012-fe7d2482d631de4c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



一个Riblets(肋骨)被设计成这样，那和之前的VIPER和MVC有什么区别呢？最大的区别在路由上面。


Riblets(肋骨)内的Router不再是视图逻辑驱动的，现在变成了业务逻辑驱动。这一重大改变就导致了整个App不再是由表现形式驱动，现在变成了由数据流驱动。


每一个Riblet都是由一个路由Router，一个关联器Interactor，一个构造器Builder和它们相关的组件构成的。所以它的命名（Router - Interactor - Builder，Rib）也由此得来。当然还可以有可选的展示器Presenter和视图View。路由Router和关联器Interactor处理业务逻辑，展示器Presenter和视图View处理视图逻辑。


重点分析一下Riblet里面路由的职责。

##### 1.路由的职责

在整个App的结构树中，路由的职责是用来关联和取消关联其他子Riblet的。至于决定是由关联器Interactor传递过来的。在状态转换过程中，关联和取消关联子Riblet的时候，路由也会影响到关联器Interactor的生命周期。路由只包含2个业务逻辑：

1.提供关联和取消关联其他路由的方法。
2.在多个孩子之间决定最终状态的状态转换逻辑。

##### 2.拼装

每一个Riblets只有一对Router路由和Interactor关联器。但是它们可以有多对视图。Riblets只处理业务逻辑，不处理视图相关的部分。Riblets可以拥有单一的视图（一个Presenter展示器和一个View视图），也可以拥有多个视图（一个Presenter展示器和多个View视图，或者多个Presenter展示器和多个View视图），甚至也可以能没有视图（没有Presenter展示器也没有View视图）。这种设计可以有助于业务逻辑树的构建，也可以和视图树做到很好的分离。

举个例子，骑手的Riblet是一个没有视图的Riblet，它用来检查当前用户是否有一个激活的路线。如果骑手确定了路线，那么这个Riblet就会关联到路线的Riblet上面。路线的Riblet会在地图上显示出路线图。如果没有确定路线，骑手的Riblet就会被关联到请求的Riblet上。请求的Riblet会在屏幕上显示等待被呼叫。像骑手的Riblet这样没有任何视图逻辑的Riblet，它分开了业务逻辑，在驱动App和支撑模块化架构起了重大作用。



##### 3.Riblets是如何工作的


Riblet中的数据流


![](http://upload-images.jianshu.io/upload_images/1194012-9f854b96f2fd41d5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在这个新的架构中，数据流动是单向的。Data数据流从service服务流到Model Stream生成Model流。Model流再从Model Stream流动到Interactor关联器。Interactor关联器，scheduler调度器，远程推送都可以想Service触发变化来引起Model Stream的改动。Model Stream生成不可改动的models。这个强制的要求就导致关联器只能通过Service层改变App的状态。

举两个例子：

1. 数据从后台到视图View上  
一个状态的改变，引起服务器后台触发推送到App。数据就被Push到App，然后生成不可变的数据流。关联器收到model之后，把它传递给展示器Presenter。展示器Presenter把model转换成view model传递给视图View。

2. 数据从视图到服务器后台  
当用户点击了一个按钮，比如登录按钮。视图View就会触发UI事件传递给展示器Presenter。展示器Presenter调用关联器Interactor登录方法。关联器Interactor又会调用Service call的实际登录方法。请求网络之后会把数据pull到后台服务器。



Riblet间的数据流


![](http://upload-images.jianshu.io/upload_images/1194012-003acf4aae15a5ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



当一个关联器Interactor在处理业务逻辑的工程中，需要调用其他Riblet的事件的时候，关联器Interactor需要和子关联器Interactor进行关联。见上图5个步骤。

如果调用方法是从子调用父类，父类的Interactor的接口通常被定义成监听者listener。如果调用方法是从父类调用到子类，那么子类的接口通常是一个delegate，实现父类的一些Protocol。

在Riblet的方案中，路由Router仅仅只是用来维护一个树型关系，而关联器Interactor才担当的是用来决定触发组件间的逻辑跳转的角色。




### 五. 各个方案优缺点






![](http://upload-images.jianshu.io/upload_images/1194012-8c99a2bb4fae9914.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




经过上面的分析，可以发现，路由的设计思路是从URLRoute ->Protocol-class ->Target-Action一步步的深入的过程。这也是逐渐深入本质的过程。

#### 1. URLRoute注册方案的优缺点

首先URLRoute也许是借鉴前端Router和系统App内跳转的方式想出来的方法。它通过URL来请求资源。不管是H5，RN，Weex，iOS界面或者组件请求资源的方式就都统一了。URL里面也会带上参数，这样调用什么界面或者组件都可以。所以这种方式是最容易，也是最先可以想到的。

URLRoute的优点很多，最大的优点就是服务器可以动态的控制页面跳转，可以统一处理页面出问题之后的错误处理，可以统一三端，iOS，Android，H5 / RN / Weex 的请求方式。

但是这种方式也需要看不同公司的需求。如果公司里面已经完成了服务器端动态下发的脚手架工具，前端也完成了Native端如果出现错误了，可以随时替换相同业务界面的需求，那么这个时候可能选择URLRoute的几率会更大。

但是如果公司里面H5没有做相关出现问题后能替换的界面，H5开发人员觉得这是给他们增添负担。如果公司也没有完成服务器动态下发路由规则的那套系统，那么公司可能就不会采用URLRoute的方式。因为URLRoute带来的少量动态性，公司是可以用JSPatch来做到。线上出现bug了，可以立即用JSPatch修掉，而不采用URLRoute去做。

所以选择URLRoute这种方案，也要看公司的发展情况和人员分配，技术选型方面。


URLRoute方案也是存在一些缺点的，首先URL的map规则是需要注册的，它们会在load方法里面写。写在load方法里面是会影响App启动速度的。

其次是大量的硬编码。URL链接里面关于组件和页面的名字都是硬编码，参数也都是硬编码。而且每个URL参数字段都必须要一个文档进行维护，这个对于业务开发人员也是一个负担。而且URL短连接散落在整个App四处，维护起来实在有点麻烦，虽然蘑菇街想到了用宏统一管理这些链接，但是还是解决不了硬编码的问题。


真正一个好的路由是在无形当中服务整个App的，是一个无感知的过程，从这一点来说，略有点缺失。


最后一个缺点是，对于传递NSObject的参数，URL是不够友好的，它最多是传递一个字典。

#### 2. Protocol-Class注册方案的优缺点


Protocol-Class方案的优点，这个方案没有硬编码。


Protocol-Class方案也是存在一些缺点的，每个Protocol都要向ModuleManager进行注册。

这种方案ModuleEntry是同时需要依赖ModuleManager和组件里面的页面或者组件两者的。当然ModuleEntry也是会依赖ModuleEntryProtocol的，但是这个依赖是可以去掉的，比如用Runtime的方法NSProtocolFromString，加上硬编码是可以去掉对Protocol的依赖的。但是考虑到硬编码的方式对出现bug，后期维护都是不友好的，所以对Protocol的依赖还是不要去除。

最后一个缺点是组件方法的调用是分散在各处的，没有统一的入口，也就没法做组件不存在时或者出现错误时的统一处理。


#### 3. Target-Action方案的优缺点


Target-Action方案的优点，充分的利用Runtime的特性，无需注册这一步。Target-Action方案只有存在组件依赖Mediator这一层依赖关系。在Mediator中维护针对Mediator的Category，每个category对应一个Target，Categroy中的方法对应Action场景。Target-Action方案也统一了所有组件间调用入口。

Target-Action方案也能有一定的安全保证，它对url中进行Native前缀进行验证。



Target-Action方案的缺点，Target_Action在Category中将常规参数打包成字典，在Target处再把字典拆包成常规参数，这就造成了一部分的硬编码。



#### 4. 组件如何拆分？

这个问题其实应该是在打算实施组件化之前就应该考虑的问题。为何还要放在这里说呢？因为组件的拆分每个公司都有属于自己的拆分方案，按照业务线拆？按照最细小的业务功能模块拆？还是按照一个完成的功能进行拆分？这个就牵扯到了拆分粗细度的问题了。组件拆分的粗细度就会直接关系到未来路由需要解耦的程度。

假设，把登录的所有流程封装成一个组件，由于登录里面会涉及到多个页面，那么这些页面都会打包在一个组件里面。那么其他模块需要调用登录状态的时候，这时候就需要用到登录组件暴露在外面可以获取登录状态的接口。那么这个时候就可以考虑把这些接口写到Protocol里面，暴露给外面使用。或者用Target-Action的方法。这种把一个功能全部都划分成登录组件的话，划分粒度就稍微粗一点。


如果仅仅把登录状态的细小功能划分成一个元组件，那么外面想获取登录状态就直接调用这个组件就好。这种划分的粒度就非常细了。这样就会导致组件个数巨多。


所以在进行拆分组件的时候，也许当时业务并不复杂的时候，拆分成组件，相互耦合也不大。但是随着业务不管变化，之前划分的组件间耦合性越来越大，于是就会考虑继续把之前的组件再进行拆分。也许有些业务砍掉了，之前一些小的组件也许还会被组合到一起。总之，在业务没有完全固定下来之前，组件的划分可能一直进行时。

### 六. 最好的方案





![](http://upload-images.jianshu.io/upload_images/1194012-80d7e39d04c3a0b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



关于架构，我觉得抛开业务谈架构是没有意义的。因为架构是为了业务服务的，空谈架构只是一种理想的状态。所以没有最好的方案，只有最适合的方案。

最适合自己公司业务的方案才是最好的方案。分而治之，针对不同业务选择不同的方案才是最优的解决方案。如果非要笼统的采用一种方案，不同业务之间需要同一种方案，需要妥协牺牲的东西太多就不好了。

希望本文能抛砖引玉，帮助大家选择出最适合自家业务的路由方案。当然肯定会有更加优秀的方案，希望大家能多多指点我。



References:

[在现有工程中实施基于CTMediator的组件化方案](http://casatwy.com/modulization_in_action.html)  
[iOS应用架构谈 组件化方案](http://casatwy.com/iOS-Modulization.html)  
[蘑菇街 App 的组件化之路](http://limboy.me/tech/2016/03/10/mgj-components.html)  
[蘑菇街 App 的组件化之路·续](http://limboy.me/tech/2016/03/14/mgj-components-continued.html)  
[ENGINEERING THE ARCHITECTURE BEHIND UBER’S NEW RIDER APP](https://eng.uber.com/new-rider-app/)  


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_router/](https://halfrost.com/ios_router/)

