+++
author = "一缕殇流化隐半边冰霜"
categories = ["JavaScript"]
date = 2017-07-15T09:25:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/53_0_.png"
slug = "jsconf_china_2017_final"
tags = ["JavaScript"]
title = "JSConf China 2017 Day Two — End And Beginning"

+++


第二天的分享更加偏向 Web 后端。

## 第一场：Node.js Microservices on Autopilot

![](https://img.halfrost.com/Blog/ArticleImage/53_1.png)




开场简单介绍了一下什么是微服务。


![](https://img.halfrost.com/Blog/ArticleImage/53_2.png)


### 微服务有什么帮助

![](https://img.halfrost.com/Blog/ArticleImage/53_3.png)



- 假想步骤：
    - 把 corn 服务分解成许多较小服务
    - 每个微服务都可以独立部署
    - 新的微服务都可以负载均衡

- 当微服务架构与他们所替代的服务相同时，它们也会面对相同的挑战。


### 微服务的优势

![](https://img.halfrost.com/Blog/ArticleImage/53_4.png)






- 容忍失败，尽管外部失败后仍可工作。

- 快速迭代，一次性服务，可独立部署服务。

### 微服务的反模式


![](https://img.halfrost.com/Blog/ArticleImage/53_5.png)


- 微服务器之间需要负载平衡器

- 启动顺序很重要

- 负载平衡无处不在。

![](https://img.halfrost.com/Blog/ArticleImage/53_6.png)





### Autopilot 模式

![](https://img.halfrost.com/Blog/ArticleImage/53_7.png)





- 可以通过单击来部署和扩展的应用程序。

- 应用和工作流在我们的笔记本电脑和在云（公有或者私有云）上同样工作

- 应用和工作流不用强绑在任何特定的架构或者调度上。

### Autopilot 应用

![](https://img.halfrost.com/Blog/ArticleImage/53_8.png)





- Autopilot 模式的解决方案
- 可以通过 Container 获取服务

###  Autopilot 实践

![](https://img.halfrost.com/Blog/ArticleImage/53_9.png)




- 应用程序由编写的 docker 容易组成
- 服务探索可以用过 consul 或者其他 catalog
- Container 本地健康和服务相应于服务依赖的变化


![](https://img.halfrost.com/Blog/ArticleImage/53_10.png)




### ContainerPilot

![](https://img.halfrost.com/Blog/ArticleImage/53_11.png)





- 自动化一个 Container 的服务探索，生命周期管理和遥测报告
- 功能
	- Container-local 健康检查
	- PID 1初始化进程
	- 服务探索和注册和观察
	- 遥测报告给 Prometheus
	- 免费以及开源[https://github.com/joyent/containerpilot](https://github.com/joyent/containerpilot)

![](https://img.halfrost.com/Blog/ArticleImage/53_12.png)




### 一些 tips ：

- 防止那些会发生并会导致服务负担过重的请求。
- 一旦达到相应超时的阈值，阻止以后的服务直到服务能够跟上处理或者恢复
- 是否可以使用负载均衡器实现？

![](https://img.halfrost.com/Blog/ArticleImage/53_13.png)






### load Balancers at Edge

![](https://img.halfrost.com/Blog/ArticleImage/53_14.png)




- 不要将微服务直接暴露在你的组织以外。
- 设置一个能够使用 Consul 的负载均衡器。
- 当通过微服务创造商业价值时 API 网关也比较重要。




## 第二场：	无服务器架构与API

![](https://img.halfrost.com/Blog/ArticleImage/53_15.png)





### 函数即服务

![](https://img.halfrost.com/Blog/ArticleImage/53_16.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_17.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_18.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_19.png)









### 软件开发需要考虑以下几点：

- 可运维性

- 可拓展性

- 安全性

- 稳定性

- 可靠性

- 高可用性



### Xaas 比较

![](https://img.halfrost.com/Blog/ArticleImage/53_20.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_21.png)





### 函数计算的应用架构及执行方式

![](https://img.halfrost.com/Blog/ArticleImage/53_22.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_23.png)








### API Gateway & Function Computing

![](https://img.halfrost.com/Blog/ArticleImage/53_24.png)




API Gateway 的特点：

- 防攻击，防重放，请求加密、身份认证、权限管理、流量控制

- API 定义、测试、发布、下线生命周期管理

- 监控、报警、分析、API 市场

![](https://img.halfrost.com/Blog/ArticleImage/53_25.png)



Faas 的缺陷

![](https://img.halfrost.com/Blog/ArticleImage/53_26.png)




- 运行环境的不确定性：IP变化

- 运行环境的数量，对依赖资源的压力：比如数据库的连接数的限制。




## 第三场：从 REST 到 GraphQL 


![](https://img.halfrost.com/Blog/ArticleImage/53_27.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_28.png)










GraphQL 一个用于 API 的查询语言。

![](https://img.halfrost.com/Blog/ArticleImage/53_29.png)



一个简单的 GraphQL query

页面加载时间 = 加载代码 + 加载数据



本次演讲主要分为三大部分：

![](https://img.halfrost.com/Blog/ArticleImage/53_30.png)






### Web 开发的变迁

早期的 Web 开发：

![](https://img.halfrost.com/Blog/ArticleImage/53_31.png)




一个 Web 服务器返回静态的 html 返回给浏览器。

2017年的 Web 开发

![](https://img.halfrost.com/Blog/ArticleImage/53_32.png)




Web 服务器返回代码，用户服务、Posts服务、外部 API 返回数据给浏览器。页面会有很多请求，请求各种数据。现在又多了多个终端，浏览器，iOS，Android。

### 纯 REST - 一个endpoint对应一个资源

![](https://img.halfrost.com/Blog/ArticleImage/53_33.png)





优点：

- 灵活  
- 解耦  


缺点

- 需要很多次请求  
- 会获取到不需要的数据  
- 复杂的客户端  


### 类 REST - 一个endpoint对应一个视图


![](https://img.halfrost.com/Blog/ArticleImage/53_34.png)




优点：

- 一次请求  
- 所得即所需

缺点：

- 不够灵活
- 高度耦合
- 很高的维护代价
- 迭代缓慢




我们需要：

- 只需要一次请求
- 所得即所需
- 灵活
- 解耦合

而 GraphQL 能带给我们：

![](https://img.halfrost.com/Blog/ArticleImage/53_35.png)



- 只需要一次请求
- 所得即所需
- 解耦合



GraphQL 有以下3点重要的特性：

- 一个用来描述数据类型和关系的 API 定义语言
- 一个可以描述具体需要获取哪些数据的查询语言
- 一个可以 resolve 到数据单个属性的可执行模型

GraphQL resolvers 约等于 REST endpoints


![](https://img.halfrost.com/Blog/ArticleImage/53_36.png)



![](https://img.halfrost.com/Blog/ArticleImage/53_37.png)





GraphQL 是一个规范，不是一个实现，它在 servers、clients、tools 这些地方都有相应的规范。


有以下的这些大公司正在生产环境使用 GraphQL。


![](https://img.halfrost.com/Blog/ArticleImage/53_38.png)





![](https://img.halfrost.com/Blog/ArticleImage/53_39.png)



第二部分讲师演示了一个实际的例子：


具体的例子就需要看回放视频了。


![](https://img.halfrost.com/Blog/ArticleImage/53_40.png)



第三部分展望了一下 GraphQL 的未来。


![](https://img.halfrost.com/Blog/ArticleImage/53_41.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_42.png)







## 第四场：通过React Storybook实现visual testing驱动开发

![](https://img.halfrost.com/Blog/ArticleImage/53_43.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_44.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_45.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_46.png)



![](https://img.halfrost.com/Blog/ArticleImage/53_47.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_48.png)





这一场讲师分享了很多项目中实战踩坑经验，讲师全程用的流利英文，感兴趣的话，建议大家直接看看回看视频。

## 第五场：Graduating your node.js API to production environment

![](https://img.halfrost.com/Blog/ArticleImage/53_49.png)






我们期待的架构类型

![](https://img.halfrost.com/Blog/ArticleImage/53_50.png)







### 什么是生产系统？

有真实用户和数据的系统，日用户至少上千的公开服务。

### 达到生产级别的水准是？

- 开发者：代码可以跑，功能测试都可以通过

- 商业经理：系统能运行，并能给用户带来价值和利润。

- 库开发者：自己的库被广泛应用。有很好的文档。

- 运维：运行时环境稳定，可debug，可维护

- 安全专家：系统通过安全监测。

### 避免责任缺失

编写产品级代码的必要条件

- 稳定
- 有效
- 可调试

### 如何跨组件跟踪日志


![](https://img.halfrost.com/Blog/ArticleImage/53_51.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_52.png)




### 只是debug是不够的

![](https://img.halfrost.com/Blog/ArticleImage/53_53.png)






### 如何在上游服务故障中存活


![](https://img.halfrost.com/Blog/ArticleImage/53_54.png)







### Add error handling 

![](https://img.halfrost.com/Blog/ArticleImage/53_55.png)



### 如何运行 性能/稳定性 测试

![](https://img.halfrost.com/Blog/ArticleImage/53_56.png)




![](https://img.halfrost.com/Blog/ArticleImage/53_57.png)





### 安全性

![](https://img.halfrost.com/Blog/ArticleImage/53_58.png)





### 总结

Thinking：

- 考虑产品上线的各个方面
- 避免责任缺失

Code：

- 适当的日志
- 处理服务故障
- 记录错误内容
- 管理连接


系统：

- 做性能和稳定性测试
- 不要独自去实现所有安全相关的逻辑



## 第六场：基于 Node.js 开发物联网应用

![](https://img.halfrost.com/Blog/ArticleImage/53_59.png)





## 物联网开发  

数据产生 -> 传感器    
数据收集 -> 网络传输    
数据分析 -> 云服务器    
执行分析结果 -> 执行机构/推送    

![](https://img.halfrost.com/Blog/ArticleImage/53_60.png)





## 为什么选用 Node.js ？

- 生态
- 高并发
- 易扩展
- 学习曲线
- 开发效率
- 前后端沟通

最后讲师现场演示了一个小车的例子，通过网页上发送前进、后退、左转、右转控制小车的行为。

## 第七场：Upgrading to Progressive Web Apps

![](https://img.halfrost.com/Blog/ArticleImage/53_61.png)




黄玄老师本次分享的内容很多，满满的都是干货，也是我这次大会收获最大的一场之一。[黄玄老师的演讲稿分享地址](https://huangxuan.me/jsconfcn2017/#/)


从演讲的题目上看，就能看出这次分享讲的是 PWA 的进化史。一共讲了10个阶段。

### 1. A Web App

![](https://img.halfrost.com/Blog/ArticleImage/53_62.png)





这里向我们展示了一个简单的例子，Githuber.js 的一个单页面应用，可以查询 Github 用户的用户名。

作为一个典型的 web 应用，它有两个很明显的硬依赖：
1. 我们依赖浏览器作为运行时和应用的入口
2. 我们依赖网络来下载应用的客户端代码


这两个 web 平台固有的特性，在桌面时代，一度是 Web 的优势,但在移动设备上，由于较小的屏幕，新的交互方式，脆弱的网络条件。Web 应用却在和原生应用的较量中处于了非常明显的劣势

虽然这个 Web app 功能都比较完善，但是到了移动互联网的时代，原生的 app 的装机量更大。

这个时候我们考虑往 Web app 里面加入一些原生的特性。于是就到了第二阶段。


### 2. A Standalone Web App

我们希望让这个 Web 应用能够独立出来，和原生应用一样能够成为操作系统的第一公民。

![](https://img.halfrost.com/Blog/ArticleImage/53_63.png)


其实早在 2008 年， iOS 1.1.3 与 iOS 2.1.0 时就分别支持了 web 应用增加了自定义 icon 、添加到主屏幕和全屏打开的功能。



为了实现上述功能，网页里面就需要加入类似下面这段代码。

```javascript

<!-- Add to homescreen for Chrome on Android -->
<meta name="mobile-web-app-capable" content="yes">
<mate name="theme-color" content="#000000">

<!-- Add to homescreen for Safari on iOS -->
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black">
<meta name="apple-mobile-web-app-title" content="Lighten">

<!-- Tile icon for Win8 (144x144 + tile color) -->
<meta name="msapplication-TileImage" content="images/touch/ms-touch-icon-144x144-precomposed.png">
<meta name="msapplication-TileColor" content="#3372DF">

<!-- Icons for iOS and Android Chrome M31~M38 -->
<link rel="apple-touch-icon-precomposed" sizes="144x144" href="images/touch/apple-touch-icon-144x144-precomposed.png">
<link rel="apple-touch-icon-precomposed" sizes="114x114" href="images/touch/apple-touch-icon-114x114-precomposed.png">
<link rel="apple-touch-icon-precomposed" sizes="72x72" href="images/touch/apple-touch-icon-72x72-precomposed.png">
<link rel="apple-touch-icon-precomposed" href="images/touch/apple-touch-icon-57x57-precomposed.png">

<!-- Generic Icon -->
<link rel="shortcut icon" href="images/touch/touch-icon-57x57.png">

```



经历了一定的探索后，2013 年，W3C WebApps 工作组开始对基于 JSON 的 Manifest 进行标准化，于同年年底发布第一份公开 Working Draft，并逐渐演化成为今天的 W3C Web App Manifest。

这里需要配置一个 Manifest：

```javascript


<!-- Chrome Add to Homescreen -->
<link rel="shortcut icon" sizes="196x196" href="images/touch/touch-icon-196x196.png">
{
  "name": "Githuber.JS",
  "short_name": "Githuber.JS",
  "icons": [{
      "src": "logo-512x512.png",
      "type": "image/png",
      "sizes": "512x512"
    }],
  "start_url": "./",
  "display": "standalone",
  "orientation": "portrait",
  "theme_color": "#f36a84",
  "background_color": "#ffffff"
}
Web App Manifest
<link rel="manifest" href="/manifest.json">




```

比如我们在这里可以看到，web 应用的名字、icon、并且我们可以指定，每次这个 web 应用都从这个 url 启动，以独立的方式显示，并且锁定屏幕在竖屏幕。

那么，当这个 web 应用被添加到主屏的时候，浏览器就可以通过这个清单文件，将应用的这些配置用于跟操作系统集成。比如说这里的 icon ，全屏打开，主题色，都非常明显。


这样一个网页就能像 Native app 存在于桌面上了。不过问题又来了，如果手机当前没有网络，那么打开这个书签，app 就完全不能用了。


### 3. An Installable Web App

第三阶段就进行成了一个可以安装的 Web app。如果我们的 web 应用可以被安装，那么网络不就变成一种渐进增强了吗？


这里最早可以追溯到2007年的 Google Gears。Gears 在 2008 年开始被 W3C 进行标准化，其中的 LocalServer，就是后来 HTML5 中大家熟知的 App Cache 的前身。

```javascript

// Somewhere in your javascript
var localServer = google.gears.factory.create("localserver");
var store = localServer.createManagedStore(STORE_NAME);
store.manifestUrl = "manifest.json"

{
　　"betaManifestVersion":　1,
　　"version": 　"1.0",
　　"entries":　[　
　　　　{　"url": 　"index.html"},
　　　　{　"url": 　"main.js"}
　　]
}


```


接着到了2011年，发展到了 App Cache。

```javascript

<html manifest="cache.appcache">

CACHE MANIFEST

CACHE:
style/default.css
images/sound-icon.png
images/background.png

NETWORK:
comm.cgi


```

这个其实是 [**HTML5 Offline Web Applications**](https://www.w3.org/TR/2011/WD-html5-20110525/offline.html)

App Cache 的设计实在太烂了……不可编程，缓存不可清理，如果你不小心把 appcache 这个文件设上了一年的
 HTTP 缓存，你的用户这辈子都会停留在同一个版本而你没有任何办法 kill switch。


![](https://img.halfrost.com/Blog/ArticleImage/53_64.png)


不过由于缓存问题，在 2016年5月19号，Application Cache 被移除了。

最后就发展到了 Service Workers 的时代了。于 2016年10月11号，W3C 提的新的草案提出了 Service Workers 的概念。

```vim

Service Workers 1
W3C Working Draft, 11 October 2016

```

平常，我们 web 应用的所有代码资源都是通过 HTTP 来获取的，还记得 Cache Storage 吗？而 Service Worker 呢，它就像一个使用
 JavaScript 编写的，位于浏览器与网络之间的客户端代理，可以拦截、处理、响应所有流经的 HTTP 请求。

你还可以将通过网络请求来的 Response 缓存到随着 SW 一起引入的 Cache Storage 里。这就使得 Service Worker 即使在离线的环境下也可以从缓存中向 web 应用提供应答。

![](https://img.halfrost.com/Blog/ArticleImage/53_65.png)


需要注意的是：Service Workers 在生产环境必须强制要求 HTTPS ，防止中间人劫持。 

![](https://img.halfrost.com/Blog/ArticleImage/53_66.png)


上图是 Service Workers 的生命周期 LifeCycle。其中，这两个蓝色的，Install 和 Activate，安装与激活，是两个生命周期事件。完成了这两个事件，SW 就预备就位了。

什么叫完成了这两个事件呢？SW 的规范里定义了一个新的 ExtendableEvent 接口，可延展事件。它只有一个方法，waitUntil，接受一个 promise，只有这个 promise fulfill 了，这个事件才算结束。

比如说，如下代码，只有 promiseA fullfill 后，install 事件才算结束，activate 事件才会触发，然后直到 Promise B fullfill 后，SW 才算真正就位。


Service Workers 也有一些拓展的事件：


```javascript

// IDL
interface ExtendableEvent : Event {
  void waitUntil(Promise<any> f);
};
// sw.js
self.oninstall = (e) => {
  e.waitUntil(promiseA)
}
self.onactivate = (e) => {
  e.waitUntil(promiseB)
}

```

![](https://img.halfrost.com/Blog/ArticleImage/53_67.png)




SW 就位之后， 就开始接收功能性事件了，包括网络请求 Fetch，消息推送 Push，后台同步 Sync 等，这些事件会把 SW 从闲置状态唤醒 ，来执行你的事件回调。同时，SW 还有一个从抽象 Web Worker 那继承来的 message 事件，用于进行 Worker 与文档主线程间的通信。那么，我们就可以来做一些有意思的事情了。我们可以在 SW 安装生命周期里，利用 CacheStorage，来做资源的预存。


```javascript

const CACHE_NAMESPACE = 'githuber.js.dev-'
const PRECACHE = CACHE_NAMESPACE + 'precache'
const PRECACHE_LIST = [
  './',
  './static/js/bundle.js',
]
self.oninstall = (e) => {
  e.waitUntil(
    caches.open(PRECACHE)
    .then(cache => cache.addAll(PRECACHE_LIST))
  )
}

```

怎么做呢，如代码所示，PRECACHE 是一个缓存的名字，PRECACHE LIST 是我们要缓存的静态资源列表。

在 waitUntil 里，我们用 caches.open 打开一个名为 PRECACHE 的新缓存。并且用 cache.addAll 添加 PRECACHE LIST 到这个缓存里。

相信你也发现了，SW 与 Node 都在在于网络 IO 与磁盘 IO 这些东西打交道。所以所有相关的 API 都是异步操作，并且都设计为了更现代的 Promise 风格。

那么，cache.addAll 其实意味着 SW 会独立去发两个请求，然后拿回来放到缓存里。只有这两个请求都成功了，这次安装才会成功。


在 Chrome 的 Application - cache 里，我们就可以看到，这些请求的 Response 已经被缓存下来了。  

这意味着，一种真正的，类似原生应用的“安装”能力。



这里需要注意的一个大坑是：CacheStorage 和 localStorage 一样是 Origin Storage。所以要注意命名冲突，不同的 Web app 之间千万别把别人的缓存覆盖或者清理掉了。


我们可以在没有网络的环境下，自定义一个离线的页面。当没有网络的时候，用户进入 app ，依旧可以看到一个页面。


```javascript

self.onfetch = (e) => {
  const fetched = fetch(e.request)
  // match offline.html in all cache opened in caches
  const sorry = caches.match("offline.html")

  // if the fetched reject, we return the sorry Response.
  e.respondWith(
    fetched.catch(_ => sorry)
  )
}

```

经过上述的改造以后，Web app 就变成如下逻辑：

![](https://img.halfrost.com/Blog/ArticleImage/53_68.png)


加载一个页面会先通过 Service Workers 去请求网络，如果没有网络，就去加载缓存里面的内容，最后把数据渲染到页面上。



当然我们还可以把上述逻辑改成缓存优先：

```javascript

self.onfetch = (e) => {
  // Cuz we are a SPA using History API, 
  // we need "rewrite" navigation requests to root route.
  let url = rewriteUrl(e);
  // match url in all cache opened in caches
  const cached = caches.match(url) 

  e.respondWith(
    cached
      .then(resp => resp || fetch(url))
      .catch(_ => {/* eat any errors */})
  )
}


```

逻辑就变成下图所示：

![](https://img.halfrost.com/Blog/ArticleImage/53_69.png)



加载一个页面还是先通过 Service Workers ，不过优先去缓存里面找数据，如果缓存里面没有，再去请求网络，网络返回的数据渲染到页面上。


这样一来，其实就实现了Google 推崇的一种 PWA 架构方式，App shell 架构，动态的数据来自于网络请求。

![](https://img.halfrost.com/Blog/ArticleImage/53_70.png)



上述过程我们都会依赖 Service Workers ，但是万一 Service Workers “死”了呢？如果 SW 就是个死的，好像也不行啊，那我们还怎么发版？缓存也不会自己更新啊。


### 4. An Evergreen Web App


我们的 web 应用已经具备了原生应用一般的安装能力，但是我们还是可以做到，无缝发版，保证 App 一直是常青的。

![](https://img.halfrost.com/Blog/ArticleImage/53_71.png)

让我们先来回顾一下，第一个 SW 是怎么被注册上去的。SW 进行安装，激活。直到页面被刷新，这个页面的所有请求才会通过 SW。所以说，默认情况下，第一个 SW 只会在第二次加载时才生效。


这里又有三个坑。

第一个坑是：Service Workers 是第二次被加载的。默认页面进行 fetches 的时候是不会通过 Service Workers 的。


你可能会想，SW 安装好之后，页面发出的请求，会不会被劫持？

答案是不会的。如果这个页面本身没有经过 SW，这个页面的所有请求也都不会经过 SW，这是为了避免可能存在竞态。

当然，这个行为也是可以覆写的。我们可以在 onactivate 里对所有 clients，即客户端（典型的 C/S 模型）做一个声称，表示我现在要立即接管你的请求。


这里可以考虑重写 clients.claim() 方法

```javascript

self.onactivate = (e) => {
  // Clients.claim() let SW control the page in the first load
  clients.claim()
}

```


那么在已经有了一个 SW 之后，每次页面刷新，其实 SW 都会被重新请求。
如果浏览器发现哪怕有一个字节的不同，都会认为是有 SW 的更新了。
比如，我们可以设一个版本号，每次要发版，就加一位，就会重新跑一遍 SW，就会重新把那些静态资源拿一遍。

当然在生产环境，我们会用构建工具来帮助我们。


第二个坑是：新的 Service Workers 不会立即把老的替换掉，直到老的 Service Workers 被关掉。 

不过，新的 SW 并不会立刻就把旧的替换掉。

为什么呢。你想啊，在没有 SW 的时候，如果我们对每个资源打 hash，使用 HTTP 的长期缓存。我们整个 web 应用的依赖关系的入口是在 html 所引用的那个入口模块块（比如 webpack 的 entry chunk），但是，有了 SW 之后，你会发现，SW 的入口作用比这个 entry chunk 还要提前，因为你的 entry chunk
 的版本其实是跟着 SW 的 cache 走的。 

所以，SW 其实成为了整个 web 应用的资源版本的入口。如果你的 SW 有 breaking change，那么这个应用就会出现资源版本问题了。

试想一下 Chrome 的更新机制，当有新的版本时，重启 Chrome 之后才会生效。

![](https://img.halfrost.com/Blog/ArticleImage/53_72.png)




上图就是图例，新的 Service Workers 会一直处于 Waiting 的状态，直到当前页面关掉了，这个 Waiting状态的 Service Workers 才能变为 Active。

有趣的是，一次刷新是不足以替换 SW的，因为浏览器在刷新时，只有在新的 navigation 结束后才会移除旧的 browsing context，所以这段时间里 clients 是重叠的，并不会引起旧的 SW 被抛弃。



```javascript

self.oninstall = (e) => {
  e.waitUntil(
    caches.open(PRECACHE)
    .then(cache => cache.addAll(PRECACHE_LIST))
    .then(self.skipWaiting())
    .catch(err => console.log(err))
  )
}


```

同样，这个行为可以使用 SkipWaiting 覆写。（这意味着你的 web 应用可能来自两个版本的缓存，可能会潜在的 break things。）所以，SkipWaiting 其实意味着，新的 SW 在控制一个老的版本的页面。不带着刷新是潜在不安全的，除非你能保证，你的每次 SW 都是向后兼容的"。不过，SkipWaiting 非常有用，我们说了，一种让应用更新的方式是，所有 tab 都被关闭，然后重新打开时就更新了。这是一种静默的更新，但是可能会滞后于我们的发版。

但是，有的时候我们希望用户立刻用到新版本，不要晚一拍。这个时候，让新的 SW SkipWaiting，再刷新一次，就可以保证所有的资源都是来自新的 SW 的缓存与其对应的逻辑。

所以，我们可以在 skipWaiting 之后，提示用户去刷新一下。

但是，如果用户那时候正在干什么事情，然后就没去刷新呢？

Quick Update = skipWaiting() + Refresh ，但是失效了怎么办？有2种解决办法。

#### 方法一：在 skipWaiting() 之后强制刷新

每次发版都强制刷新。对于游戏等卡大版本的场景是很适用的。

```javascript

// broadcasting clients to do window.location.reload() 
self.clients.matchAll().then(clients => {
  clients.forEach(client => {
    client.postMessage(REFRESH_MSG)
  })
})

// new API: client.navigate
self.clients.matchAll().then(clients => {
  clients.forEach(client => {
    client.navigate(REFRESH_URL)
  })
})


```

#### 方法二：利用 PostMessage() 刷新

在用户交互后再去 skipwaiting 同时刷新。


```javascript

// registration.waiting.postMessage()
self.onmessage = (e) => {
  switch (e.data.command) {
    case "SKIP_WAITING_AND_RELOAD_ALL_CLIENTS_TO_ROOT":
      self.skipWaiting()
        .then(_ => reloadAllClients("/"))
        .catch(err => console.log(err))
      break;
  }
}


```


每次 SW 更新必然会重新请求我们 PRECACHE 列表里的 URL，这就不得不谈到 SW 的一个大坑，就是与 HTTP Cache 的合作。

第三个坑是 Service Workers 与 HTTP Cache 的坑，有缓存存在。

Cache Storage 只是 HTTP Cache 外的另一个 Cache。所以所有从 SW 发出的请求仍然要走 HTTP Cache。

设想我们的 bundle.js 设置了这样的 cache-control。那么无论我们如何更新 SW 与 bundle.js，每次更新回来的都还会是 HTTP缓存里的版本，变成了一个无限循环。

由于每次都是请求新文件，而 Cache Storage 又不像 HTTP Cache，它属于浏览器尽可能给你分配的永远存储。所以缓存一直无限增多怎么办？


那么这里有一个简单的解决方法，就是，我们给缓存加上版本，然后呢，在每次 onactivate 的时候，我们就清理掉不属于当前版本的缓存。

你可能会想，那要是两个版本里有相同的资源怎么办，是不是浪费了。好在，这个时候，HTTP Cache 又可以帮你兜底。

但是，HTTP Cache 更容易因为一些原因无法持久存在。所以如果我们的清理能精确到请求粒度而不是 cache 粒度肯定会更好一些。


这里推荐一个 Service Workers 好用的库 SW-Precache。

```javascript

// sw-precache-config.js

module.exports = { 
      staticFileGlobs: [ 
            'app/css/**.css', 
            'app/**.html', 
            'app/images/**.*', 
            'app/js/**.js' 
    ]
};

$ sw-precache --config=path/to/sw-precache-config.js

```

它是一个 node module，指定静态文件的 Glob 匹配，就可以帮你生成非常可靠的 SW。在 build time 收集资源版本，在安装和迁移时以文件（request）粒度进行增量更新。

同时，它提供了 webpack 插件。**[sw-precache-webpack-plugin](https://github.com/GoogleChrome/sw-precache)**

可以直接把 webpack build 出来的清单塞给这个 sw-precache 库。

1. 不需要 cachebust
2. navigateFallback

那么，可以非常好的解决我们之前遇到的问题。

```javascript

// webpack.config.js
const SWPrecacheWebpackPlugin = require('sw-precache-webpack-plugin');
module.exports = {
  plugins: [
    new SWPrecacheWebpackPlugin({
      // assets already hashed by webpack aren't concerned to be stale
      dontCacheBustUrlsMatching: /\.\w{8}\./,  
      filename: 'service-worker.js',
      minify: true,
      navigateFallback: PUBLIC_PATH + 'index.html',
      staticFileGlobsIgnorePatterns: [/\.map$/, /asset-manifest\.json$/],
    }),
  ],
};

```



### 5. An Offline-1st Web App

离线优先，离线，并不应该是一种错误的状态。


这里黄玄老师把 Ajax、RWD、PWA 三者做了一个对比。


![](https://img.halfrost.com/Blog/ArticleImage/53_73.png)



我们可以监听一些事件

```javascript

// here, we hard-code the online/offline logics
// In production, we can expose callbacks to subscribers
function updateOnlineStatus(event) {
  if(navigator.onLine){
    document.body.classList.remove('app-offline')
  }else{
    document.body.classList.add('app-offline');
    createSnackbar({ message: "you are offline." })
  }
}

window.addEventListener('online',  updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);


```

通过监听离线的事件，我们可以把离线的状态反应到 UI 上。


于是我们可以把缓存逻辑改成如下：

```javascript

// sw.js
self.onfetch = (e) => {
  // ...
  if(url.includes('api.github.com')){
    e.respondWith(networkFirst(url));
    return;
  } 
  if(url.includes('githubusercontent.com')){
    e.respondWith(staleWhileRevalidate(url));
    return;
  }
  if(PRECACHE_ABS_LIST.includes(url)){
    e.respondWith(cacheOnly(url));
    return;
  }
  // default: Network Only
}


```

于是逻辑又会变成下图的样子：


![](https://img.halfrost.com/Blog/ArticleImage/53_74.png)




为了让离线时，我们的 web 应用能更加有用，我们还可以做运行时缓存。

比如，对于在 PRECACHE 列表里的，我们其实可以大胆放心用 cacheOnly 的策略来回应。对于 api，我们可以用网络优先。


对于静态的资源，尤其是图片，我们可以用一种叫做 stale-while-revalidate 的办法。

一个页面请求数据还是通过 Service Worker，只不过先去缓存里面去查，查到了就返回给页面渲染。同时 Service Worker 还会再去请求网络数据，返回的数据又会更新缓存。

stale while revalidate 本身是 HTTP 的一个提案，但是我们可以用 SW 来 polyfill。


![](https://img.halfrost.com/Blog/ArticleImage/53_75.png)



当然这里还有一个策略是 fastest。既然 都发了请求，为什么不放回 cache 里呢。

当然也可以同时请求缓存和网络。但是这里有一个问题，如果两者同时返回数据，究竟用谁的呢？

这里就会遇到一个坑：

运行时的 Cache 也需要一个替换机制，不能无限增长下去。这是一个缓存替换的问题。

这里有一个解决方案，FIFO

```javascript


// sw.js
function replaceRuntimeCache(MAX_ENTRIES){
  caches.open(RUNTIME)
    .then(cache => {
      cache.keys()
        .then(entries => {
          // FIFO queue
          if(entries.length > MAX_ENTRIES) {
            cache.delete(entries[0])
          } 
        })
    })
}

```

这里黄玄老师又推荐了一个 Service Worker Libraries，SW-Toolbox。

它是一个在 SW 里用的，可以用 worker 都有的 importScript 引入。swtoolbox 还提供了 express 风格的路由。并且，它通过 indexedDB 实现了 LRU 清理策略，我们只需要提供一个 maxEntries 数就可以了。它会自动帮我们统计使用情况。同时，配合上最长过期时间，实际上实现了完整的 TLRU。


它有5种缓存策略：

- CacheOnly
- CacheFirst
- Fastest (Stale-while-Revalidate)
- NetworkOnly
- NetworkFirst

sw-precache 可以配合 sw-toolbox 一起使用：

```javascript

// sw-precache-config.js
module.exports = {
  // ...
  runtimeCaching: [{
    urlPattern: /this\\.is\\.a\\.regex/,
    handler: 'networkFirst'
  }]
};

// sw.js with sw-toolbox imported
toolbox.precache([
  "./index.a35bc762.js",
  "./style.5217a6fb.css"
])


```

这是又有一个库，Workbox，完成了sw-precache 和 sw-toolbox两个库的功能。也许是未来 Service Worker 比较好的完整的解决方案。

![](https://img.halfrost.com/Blog/ArticleImage/53_76.png)





### 6. A Streaming Web App

与原生应用上来就需要先安一个大包不同，web 应用是不是像是流式的流进里的手机里的。配合上 SW 的安装能力，就好像流式安装一样。


![](https://img.halfrost.com/Blog/ArticleImage/53_77.png)



加载一个页面依旧比较慢，需要经历上述这些步骤。


![](https://img.halfrost.com/Blog/ArticleImage/53_78.png)


web 性能常见的几个问题：

1. HTTP 的开销
2. 太深的依赖关系会造成无法并行
3. JS 的启动开销
4. 打一个大包


这里我们可以采用 PRPL 模式来解决问题。


![](https://img.halfrost.com/Blog/ArticleImage/53_79.png)



PRPL 是一种用于结构化和提供 Progressive Web App (PWA) 的模式，该模式强调应用交付和启动的性能。 它代表：


![](https://img.halfrost.com/Blog/ArticleImage/53_80.png)




- 推送 - 为初始网址路由推送关键资源。
- 渲染 - 渲染初始路由。
- 预缓存 - 预缓存剩余路由。
- 延迟加载 - 延迟加载并按需创建剩余路由。


除了针对 PWA 的基本目标和标准外，PRPL 还竭力在以下方面进行优化：

- 尽可能减少交互时间，特别是第一次使用（无论入口点在何处），特别是在真实的移动设备上
- 尽可能提高缓存效率，特别是在发布更新时
- 开发和部署的简易性

对如何组织与设计高性能的 PWA 系统提供了一种高层次的抽象。


![](https://img.halfrost.com/Blog/ArticleImage/53_81.png)




上图是采用了 PRPL 模式 加上通过路由进行的代码分割。

通过优化以后，再看看加载时间。

![](https://img.halfrost.com/Blog/ArticleImage/53_82.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_83.png)



时间缩短了不少。


### 7. A Progressive Web App

PWA 希望汲取 Web 和 Native 的优点。

三个吸引人的特性。 


![](https://img.halfrost.com/Blog/ArticleImage/53_84.png)



- Reliable 

![](https://img.halfrost.com/Blog/ArticleImage/53_85.png)


- Fast 

![](https://img.halfrost.com/Blog/ArticleImage/53_86.png)



- Engaging

![](https://img.halfrost.com/Blog/ArticleImage/53_87.png)



PWA 同样可以运行在桌面端。三星 Samsung Internet DeX 和 Chromebook、win10 相继都开始支持桌面级的 PWA。

### 8. A JavaScript Web App



到了第八个阶段了。这个阶段的 Web App 都是集成了 JS frameworks 的。

举最典型的3个框架，里面都都支持了 PWA。

![](https://img.halfrost.com/Blog/ArticleImage/53_88.png)



create-react-app、Preact CLI、vue init pwa。


![](https://img.halfrost.com/Blog/ArticleImage/53_89.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_90.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_91.png)



### 9. Any Web App/Site

很多人会问，那 PWA 只能是 SPA 吗？为什么要叫 PWA 而不是 PWS？

![](https://img.halfrost.com/Blog/ArticleImage/53_92.png)




PWA 就是 web，它的出现是为了告诉开发者，告诉用户，告诉我们的老板。嘿，Web 平台的很多很多新技术，他们组合可以起来可以干很多你想象不到的事情。

而我们还有 AR/VR, WebGL/ WebGPU, Web ASM  等等等等，它们都是 PWA 吗，不是？他们是 web，他们都是 PWA 吗？也是啊，也是 PWA 就是 web。


### 10. The Web

最后一站，The Web，是终点，也是起点。

> Anyone, at any time, can publish anything from anywhere
> 任何人在任何时间，都可以在任何地方发布任何东西。

Web 是自由的。所谓 Web 的开放精神，还在于『任何人，在任何时间任何地点，都可以在万维网上发布任何信息，并被世界上的任何一个人所访问到。』而这才是 web 的最为革命之处，堪称我们人类，作为一个物种的一次进化。」

是的，这是 phonegap 的作者说的话

>PWA 的主导者 Alex Russell 说
>"Progressive Web Apps: Escaping Tabs Without Losing Our Soul"
>@slightlylate


请让我们，在不丢失我们开放灵魂的前提下，不需要依靠 Hybrid 把应用放在 App Store 的前提下，跳脱出浏览器的标签，变成用户眼中，跟强大，更好用的软件应用，这就是 PWA。


![](https://img.halfrost.com/Blog/ArticleImage/53_93.png)



这就是 Web。

这就是让那群天天撕逼的浏览器厂商重新站在一起，想要去做的那件事" 。



黄玄老师最后将主题升华了！


## 第八场：讲师圆桌讨论


![](https://img.halfrost.com/Blog/ArticleImage/53_94.png)





尤大由于忙，第二天没有来，其实挺想听听尤大的观点。


## 感想

通过参加这次大会，令我频繁听到的两个词就是 GraphQL 和 Go，在群里讨论最多的也是这两个技术。Go 语言刚刚在7月份登上了语言排行榜的前十名，正好第十名。而且 Google 官方也宣布准备发布2.0的版本了。确实 Go 最近的风头正火。至于 GraphQL 这个技术在美国大公司都用了一段时间了，并且越来越流行。反观中国，在生产环境用到这个技术的公司挺少的，至少现场举手的同学很少很少。也许过几年就会在中国流行开来吧。


这次比较失望的还是没有遇到 Weex 官方的开发者来分享。一直很想和 Weex 官方开发者当面交流交流技术的，一直没有机会。Weex 的团队也一直非常低调，这次大会也依旧传出了 Weex 团队可能快要解散的“流言蜚语”。我相信这只是谣言吧。

最后讲师答疑环节，是 Angular 和 React 的天下了，由于尤大比较忙，就没来最后的答疑环节。不出意料，网友就是喜欢搞事情，问的问题都是搞事情！问：如何选择 Vue、Angular、React 的？问：前端框架发展日新月异，如何看待前端框架这种层出不穷，快速更新的现状？问：前端的未来到底在哪里？这些问题问出来，其实讲师只能给出参考答案。最终怎么实践，每个人都应该有自己的答案的。关于前端这三大框架怎么选择的问题，这就要看自家公司的业务场景了。前端框架快速更新的现状，讲师给的答案就是“let it go”，随着他吧。最后关于前端的未来，讲师也谈到了很多，谈到了 TypeScript 和 Flow 是否可能替代 JavaScript，谈到了 WebAssembly 、 PWA 等等。总之前端的未来现在谁也说不好，还需要继续顺应时代的发展。

这次参会，小弟也是开了开眼界，有很多收获，能和大家分享的也就这么多了。收获最大的就是尤大和黄玄老师的分享，其他人的分享由于我的前端资历过浅，都没有领悟到“精髓”。

![](https://img.halfrost.com/Blog/ArticleImage/53_95.png)


<div style="position: relative; padding-bottom: 56.25%;padding-top: 25px;height: 0;">
<iframe width="1920" height="1080" src="http://player.youku.com/player.php/sid/XMjkwNzI1Mzg2MA==/v.swf" frameborder="0" allowfullscreen style="position: absolute;top: 0;left: 0;width: 100%;height: 100%;"></iframe>
</div>

(上面这里是优酷视频，如果显示空白，请查看是不是浏览器禁止了某些插件)

<div style="position: relative; padding-bottom: 56.25%;padding-top: 25px;height: 0;">
<iframe width="1920" height="1080" src="https://www.youtube.com/embed/E6rVjWZy13s?ecver=1" frameborder="0" allowfullscreen style="position: absolute;top: 0;left: 0;width: 100%;height: 100%;"></iframe>
</div>

(上面这里是YouTube视频，如果显示空白，请查看是否科学上网了)

[官方花絮视频 JSConf China 2017](http://v.youku.com/v_show/id_XMjkwNzI1Mzg2MA==.html?spm=a2h0k.8191407.0.0&from=s1.8-1-1.2)(JSConf China 2017 官方高清视频，第一天签到的时候就看见无人机了，结果真的把小弟我剪辑到影片中了，39秒，40秒，是我的特写。50秒第七排中间粉色T恤，腿上的Mac屏幕亮着的也是笔者我)


最后献上[JSConf China 官网](http://2017.jsconf.cn/)上面有部分版权可以公开的 PPT 演讲稿，可以下载下来学习学习。


JSConf China 2017 完美落幕！




> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jsconf\_china\_2017\_final/](https://halfrost.com/jsconf_china_2017_final/)

