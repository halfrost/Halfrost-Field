# A Pseudo Best-Practices Guide for iOS Weex Developers


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-5763204636dd1f25.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


### Introduction

This article summarizes some of my recent research and hands-on experience with Weex on iOS, and shares it with everyone as a recap of what I’ve learned. The approaches mentioned here may not be best practices, and the methods described may not qualify as a standard guide or handbook, so I can only call the title a “Pseudo Best-Practices Guide.” If you have better approaches, feel free to leave comments so we can discuss and learn together.

Since I don’t know much about Android, the following article will not cover Android.

### 1. React Native and Weex

From the day Weex was born, it could not escape being compared with React Native. React Native claims “Learn once, write anywhere,” while Weex claims “Write Once, Run Everywhere.” Since its birth, Weex has carried the high expectation of unifying all three platforms. React Native supports iOS and Android, while Weex supports iOS, Android, and HTML5.

On the Native side, the biggest difference between the two may be whether the JSBundle is split into packages. Officially, React Native only allows the core React Native JS library and business JS to be bundled together into a single JS bundle, and does not provide package-splitting support. So if you want to save traffic, you must build your own split-bundling tool. By default, the JS bundle produced by Weex contains only business JS code and is much smaller. The core JS library is included in the Weex SDK. In this regard, compared with Facebook’s React Native and Microsoft’s Cordova, Weex is more lightweight and compact.

On the JS side, Weex is also sometimes called Vue Native, so the difference between React Native and Weex comes down to the difference between React and Vue.


![](http://upload-images.jianshu.io/upload_images/1194012-46105d34246ef565.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


I have not written React Native myself, so I cannot objectively compare the two. However, there is a very good comparison article about Weex and React Native on Zhihu, [“A Comparison of Weex and React Native”](https://zhuanlan.zhihu.com/p/21677103), which I recommend reading.


A couple of days ago, [@Allen Xu Shuai](http://www.weibo.com/122678100) also published an article on the [Glow Tech Team Blog](http://tech.glowing.com/cn/), [“React Native in Practice at Glow”](http://tech.glowing.com/cn/react-native-at-glow/). That article also discusses many practical points related to React Native, and I strongly recommend reading it as well.


### 2. Getting Started Basics


![](http://upload-images.jianshu.io/upload_images/1194012-953ccb5573e125cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


For beginners who want to get started with Weex, the most fundamental thing is of course to read through the documentation. The documentation is the best official learning material. There are two official basic documents:

[Tutorial Documentation](http://weex-project.io/cn/guide/)  
[Reference Documentation](http://weex-project.io/cn/references/)  

The reference documentation contains all currently available Weex components and modules, as well as the usage and properties of each component and module. When you encounter a problem, you can first come here and look it up. It is quite possible that some components and modules simply do not have the properties you are looking for.

### 1. The Weex Toolchain and Scaffolding

After reading the official documentation, you can start building a project.

Our company has written four articles on Zhihu about the [“Weex Getting-Started Guide”](https://zhuanlan.zhihu.com/ElemeFE?topic=Weex). These four articles are well worth reading.

Like frontend projects, Weex has its own complete scaffolding toolchain: weex-toolkit + weexpack + playground + code snippets + weex-devtool.

weex-toolkit is used to initialize projects, compile, run, and debug with all the tools.


![](http://upload-images.jianshu.io/upload_images/1194012-03ec89a3507400c2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

weexpack is used to package JSBundle; in practice, it is also a wrapper around Webpack.

![](http://upload-images.jianshu.io/upload_images/1194012-eada7a409d2a64e1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


playground is a published App that can be used to display the actual page on a phone in real time by scanning a QR code.

![](http://upload-images.jianshu.io/upload_images/1194012-10984a942457d712.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

code snippets is an online playground.

![](http://upload-images.jianshu.io/upload_images/1194012-0d80d249e1f3fa45.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


I believe everyone should already have a Native App. If you truly do not even have an App, then use the weexpack command to initialize a new project. If you already have an App project, then the weex command is only used for running and debugging.

For those who already have an iOS project, you can install the Weex SDK directly via CocoaPods. After initializing the SDK, Native can use Weex. Change the JS loading address to your company server’s IP.
```objectivec

#define CURRENT_IP @"your computer device ip"
// ...

// Change the port number to yours

#define DEMO_URL(path) [NSString stringWithFormat:@"http://%@:8080/%s", DEMO_HOST, #path]

// Change the JS file path

#define HOME_URL [NSString stringWithFormat:@"http://%@:8080/app.weex.js", DEMO_HOST]


```
With this, the entire project can run.

One more thing to note: although the project is now running, every run requires starting npm to bring up the Weex frontend environment. There are two ways to handle this.

The first approach is to hook directly into Xcode’s run command and add a script in the Xcode configuration to start npm. For example:


![](http://upload-images.jianshu.io/upload_images/1194012-d9d1e69465d6cf71.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The second approach is to manually run npm run dev before each run. Personally, I prefer this approach, because before Xcode finishes launching, there is definitely enough time to type these commands in the command line.


Next, let’s talk about debugging. This part uses weex-devtool.


![](http://upload-images.jianshu.io/upload_images/1194012-8a706511d2d5a5a0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The experience of using this tool is basically the same as debugging frontend code in Chrome.

![](http://upload-images.jianshu.io/upload_images/1194012-afc73328b962d3cd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

For the detailed usage, just refer to the following two articles, so I won’t go into it again here:

[“Weex Getting Started Guide: Debugging Is a Craft”](https://zhuanlan.zhihu.com/p/25331465)   
[“The Weex Debugging Power Tool — Weex Devtools User Manual”](https://github.com/weexteam/article/issues/50)   

### 2. Weex Market Plugins


In day-to-day development, we can certainly develop all Weex pages ourselves from scratch, but we can also use some existing high-quality wheels. All of the excellent Weex wheels are available in Weex Market.

![](http://upload-images.jianshu.io/upload_images/1194012-561d88f5b37957c5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

There are many ready-made wheels in this Market that can be used directly, saving a lot of time.

For example, the very popular weex-chart here. The weex-chart chart plugin is implemented through g2-mobile, which depends on the [gcanvas plugin](https://market.dotwe.org/weex-plugin-gcanvas).

If you want to use Plugin plugins from [Weex Market](https://market.dotwe.org/), you can use the weex plugin command:
```vim

$ weex plugin add plugin_name

```
You only need to enter the plugin name to add a plugin from a remote source to your local project. For example, to add weex-chart, you can run:
```vim

$ weex plugin add weex-chart

```
We can use plugin remove to remove a plugin, for example, removing the installed weex-cahrt:
```vim

$ weex plugin remove weex-chart


```
I’ve used weex-router from this plugin library. It’s pretty good for managing routing in Weex. Recommended.


### 3. iOS Packaging and Release

The official Weex team provides the weexpack command. I think this command is intended for frontend developers who don’t understand iOS. If the packaging is handled by Native, you still use Xcode’s Archive workflow.

Frontend developers who know nothing about iOS can use weexpack build ios to package the app. During the process, it will ask for information such as certificates and developer account credentials. Once everything is entered correctly, it can generate an ipa file. The whole process is foolproof. If you are not sure how to do it, refer to the official manual:  
weexpack official manual [《 How to Create a Weex Project with weexpack and Build an App 》](https://github.com/weexteam/weex-pack/wiki/%E5%A6%82%E4%BD%95%E7%94%A8weexpack%E5%88%9B%E5%BB%BAweex%E9%A1%B9%E7%9B%AE%E5%B9%B6%E6%9E%84%E5%BB%BAapp)  


If you are an iOS developer, you package it the same way you always did. The only difference is that the JS part needs to be packaged separately. My recommendation is to manage the Weex part in a separate git branch, and run weexpack or Webpack packaging specifically for that branch. The detailed webpack configuration should be handled by each company based on its own needs.

One extra point here, which was also told to me by a frontend expert: after webpack finishes packaging, you can use the webpack official website to inspect exactly which files and dependencies were included in the bundle. Although I usually just package everything all at once, experienced frontend developers may still check whether any unnecessary files were bundled. They will optimize the package size to the extreme, not even allowing an extra 1KB file to slip in.


Now let’s talk about release. With Weex, every release will include all hotPatch fixes accumulated since the previous version, and the new version will directly bundle the latest JSBundle file. The purpose of bundling JS locally is also to make the first screen load instantly.


### 4. Hot Update

Everyone understands the purpose of hot updates; otherwise, using Weex would lose much of its value. But one more thing needs to be clarified here—the hot update strategy.

During daily development, when we debug on a phone connected through the browser, it is not actually refreshed in real time. (However, by scanning a QR code on the phone, and keeping the phone and computer on the same LAN, real-time updates can be achieved.)

So in an actual production environment, the hot update strategy should be this: when there is a new HotPatch, deliver it to the client. Then, the next time the client starts, it first compares version information. If it is a new version, it loads the latest HotPatch and renders it on screen.

I once imagined real-time online updates: once something is released online, all users who are connected to the network receive the HotPatch, and after the download completes it is loaded directly, allowing online users to get hot updates within seconds. This can be done, but it is not very meaningful. The approach would be to maintain a dedicated Websocket connection directly to the server. After delivery completes, Native notifications can be invoked, and the Native client can refresh the page itself. (There probably are not many companies doing this right now, are there?)


### 5. JSBundle Version Management and Deployment

JSBundle version management should be handed over to the frontend team. The frontend team may use version numbers to manage the versions of individual packages. Deployment will also involve each company’s frontend deployment process, which they understand better. Deployment is usually placed on a CDN for acceleration.


### 6. Pitfalls and How to Avoid Them

It would be impossible to say that Weex has no pitfalls at all.

For example, when continuously pushing certain pages, some lines may sweep across the edge of the screen. Also, when capturing JS errors or exceptions, Weex cannot reliably catch exceptions. This needs to be handled by Native. After Native catches the exception, it can pass an event to the JS Runtime for handling.

Calculating page width and height is the most important thing to pay attention to. Weex uses 750 as the standard for UI adaptation, so values need to be converted based on 750. Another point is that Weex performs rounding operations internally, which can cause a slight loss of precision. For details, see the source code analysis in this article: [《Things About Weex Event Passing》](http://www.jianshu.com/p/419b96aecc39).

The Weex JS engine also does not support HTML DOM APIs or HTML5 JS APIs, including document, setTimeout, and so on.

Weex’s implementation of Web standards has not yet reached 100%, so if you use Vue to write Weex, some features are not supported.

For example, some CSS styles are unsupported. The most surprising thing is that `<br>` is not supported, and neither are `<form>`, `<table>`, `<tr>`, `<td>`. CSS percentage units are not supported, and neither are other standard CSS length units such as em, rem, and pt. hsl(), hsla(), currentColor, and 8-character hexadecimal colors are also unsupported.

Weex also does not fully support the W3C FlexBox specification. inline is not currently supported, and changes along the Z-axis are not supported either, though on mobile there is really little demand for Z-axis behavior. Weex’s Layout uses an older version of Yoga. The solution is also fairly straightforward: after upgrading to the latest version of Yoga later, it will be able to support more Flex standards.

For other unsupported items, you need to read the documentation more, such as [《Which Web Standards Are Currently Unsupported by Weex》](http://weex-project.io/cn/references/web-standards.html). It is best to read these first and have a general idea, so that you do not run into mysterious bugs during development only to discover that they are ultimately caused by unsupported features.


There are also some components that temporarily do not support synchronous methods. This is because Vue 2.0 does not support them yet; the official plan is to support them in version 0.12.

One additional reminder: because Apple cracked down on JSPatch some time ago, the official Weex team issued a warning regarding custom modules:

> All built-in module or component APIs exposed by Weex to JS are safe and controllable. They do not access private system APIs, do not perform any runtime hacks, and do not change the original functional positioning of the application.

>If you need to extend custom modules or components, be careful not to expose the OC runtime to JS. Do not expose dynamic and uncontrollable methods such as dlopen(), dlsym(), respondsToSelector:, performSelector:, and method_exchangeImplementations() to JS, and do not expose private system APIs to JS either.


The warning above specifically emphasizes not using the functions dlopen(), dlsym(), respondsToSelector:, performSelector:, and method\_exchangeImplementations(). This is also why, even though they are all using Weex, some people fail App Review while others pass.

I heard there are some bugs related to Refresh Control on Android. I have not looked much into Weex’s behavior on Android, but if this appeared on iOS, I think this part could simply be replaced with Native directly. Wherever there are bugs, use native implementation instead.


In short, Weex still has some issues to varying degrees, but based on current usage, they do not affect practical use. As long as you know how to work around things flexibly, when you encounter a blocker that really cannot be overcome, or a bug that you really cannot handle for the time being, consider replacing that part with native implementation.

### Three. More Advanced Usage

Next, let’s talk about slightly more advanced usage. Even if you do not implement the following items, they will not affect a normal Weex launch.

### 1. Page Degradation

Weex supports page degradation by default. For example, if an error occurs, it can degrade to H5. Here I recommend creating an online switch. In my company, we use two levels of switches for page degradation:

1. App-level switch. This switch manages whether the user’s App uses the Weex SDK, and it can be configured online.
2. Page-level switch. This switch manages whether a specific page enables Weex. If it is not enabled, it degrades to an H5 page.

In addition to degradation, we also apply a gray release strategy, ensuring that online bugs are minimized.

For example, enable the switch for gray release during low-traffic periods. Another level of gray release is controlled through an online real-time error monitoring platform. If a sudden incident causes the Crash rate to spike, immediately turn off the Weex switch and perform degradation right away.


### 2. Performance Monitoring and Instrumentation


In the official Demo provided by Weex, there is a small floating circle labeled M. When you tap it, you will see the following screen:


![](http://upload-images.jianshu.io/upload_images/1194012-dea1c20cfa2fc3db.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here we tap the performance button:

![](http://upload-images.jianshu.io/upload_images/1194012-7534caab12e5681f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Here we can see that it monitors data such as CPU, frame rate, memory, battery, and traffic. These are also common metrics we monitor in Native APM. Of course, this M dot is not open source. So each company needs to build its own monitoring system for this part. The frontend team in each company may already have this ready, so Weex needs to integrate with the frontend performance monitoring system.


If we then open the tools screen, we will see the following options:

![](http://upload-images.jianshu.io/upload_images/1194012-1429b2bd10bef09c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here there is instrumentation monitoring. In the early stage, Weex instrumentation may still be handled by Native, because each company already has its own complete Native instrumentation system. Later, instrumentation can also be handed over to the frontend team and done on the frontend side.


### 3. Incremental Updates and Full Updates

For now, I have not practiced incremental updates with Weex, so I will not discuss incremental updates here. Full updates are relatively simple: deliver the entire JSBundle, and the App loads it the next time it starts. Weex packages are much smaller than RN packages, usually around 100–200K. In one of Alibaba’s Weex sharing sessions, they mentioned that after gzip compression, they can reach 60–80K.

### 4. Extreme Optimization of First-Screen Load Time


![](http://upload-images.jianshu.io/upload_images/1194012-bd958ca4162d863e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows a challenge proposed by Alibaba at Weex Conf: the combined time of network request plus first-screen rendering should be less than 1 second.

![](http://upload-images.jianshu.io/upload_images/1194012-157fc128529fe9e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This involves three factors: network download time, JS-to-Native communication time, and rendering time.


Network download time can be optimized by supporting HTTP / 2, configuring the Spdy protocol, consolidating domains, supporting http-cache, compressing JSBundle size as much as possible, and preloading JSBundle.

When preloading JSBundle, JS can be downloaded in advance when the App starts. When the remote server pushes packages, it can use a long-lived connection channel for Push. This can combine full / incremental updates with passive / forced updates.

Alibaba’s optimizations for JS-to-Native communication time and rendering time are shown in the image above. I have not had related hands-on practice with these two areas either.

### 5. Vue Ecosystem


![](http://upload-images.jianshu.io/upload_images/1194012-1d71013538b2919e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Although Weex has its own ecosystem, after supporting Vue 2.0, its ecosystem can be fully replaced by the Vue ecosystem. Vue, Vue-Router, Vuex; originally there was also Vue-resource, but Evan You later removed Vue-resource and recommends axios instead. So the ecosystem consists of Vue, Vue-Router, Vuex, and axios.

If everything is replaced with Vue, then first-screen rendering speed on the frontend needs to be solved by Vue. To improve first-screen rendering speed, wns cache + direct output is essential. In the Vue 1.x era, there was no server-side-render solution, so direct output required writing a separate first-screen template that did not use Vue syntax. The release of Vue 2.0 server-side-render (Vue SSR for short) successfully made frontend and backend rendering template code isomorphic.

If only Vue-Router is used, when packaging and building the application, the JSBundle package can become very large, affecting page loading. If we can split components corresponding to different routes into separate code chunks, and load the corresponding component only when the route is visited, it becomes much more efficient.
By combining Vue’s [async components](http://vuejs.org/guide/components.html#Async-Components) with Webpack’s [code splitting feature](https://webpack.js.org/guides/code-splitting-require/), route component lazy loading can be implemented easily, reducing the size of the JSBundle.


Another point to note is that Vue-Router provides three operating modes:  
hash : Uses the URL hash value for routing. Default mode.  
history : Depends on the HTML5 History API and server configuration.  
abstract: Supports all JavaScript runtime environments, such as Node.js server-side.  

However, in the Weex environment, only abstract mode is supported!


Just 7 days ago, Vue released version v2.3.0, officially supporting SSR. So after SSR support, SEO can be greatly improved, and first-screen instant loading can also be achieved. Therefore, for performance, SSR is a must!


### Four. Top-Tier Usage

Finally, there are also some “forward-looking” approaches.

### 1. Powerful JSService


JS service and Weex instances run in parallel in the JS runtime. The lifecycle of a Weex instance can invoke the JS Service lifecycle. Currently, create, refresh, and destroy lifecycles are provided.

I did not find related examples in the official Demo either. There are related examples in the official documentation. The official manual contains this sentence:

> Important reminder: JS Service is very powerful but also very dangerous. Use it with caution!

Clearly, this part is very powerful and may be able to do many “magical” things.


### 2. Weex May Have Greater “Ambitions”


In the official manual’s [《Extending the JS framework》](http://weex-project.io/cn/references/advanced/extend-jsfm.html) chapter, it mentions that the JS framework can be extended horizontally. This feature is probably not something most companies will extend.

Weex hopes to respect the usage habits of as many developers as possible. Therefore, in addition to Vue 2.0 officially supported by Weex, developers can also customize and horizontally extend their own JS Framework, or one they prefer.

After customizing your own JS Framework, code like the following may appear:
```objectivec

import * as Vue from '...'  
import * as React from '...'  
import * as Angular from '...'  
export default { Vue, React, Angular };


```
This can also be extended horizontally to support Vue, React, and Angular.

If the JS Bundle has a comment in the following format at the beginning of the file:
```JavaScript

// { "framework": "Vue" }
...

```
This way, the Weex JS engine will recognize that this JS bundle needs to be parsed using the Vue framework, and dispatch it to Vue for processing.


![](http://upload-images.jianshu.io/upload_images/1194012-6b8f63a4caab42f3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


So, **Weex supports multiple frameworks coexisting within a single mobile application, each parsing JS bundles based on different frameworks.**

The ability to support multiple frameworks coexisting is extremely powerful. Of course, that’s not all—one more thing……

If you just use the APIs normally, read the official documentation, and don’t look at the source code, you won’t find any trace of Rax. The official documentation does not mention it at all.

What is Rax?


![](http://upload-images.jianshu.io/upload_images/1194012-6fd4d23ed67306c9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The article [“Rax in Taobao’s Double Promotions”](http://taobaofed.org/blog/2017/01/13/rax-in-act/) introduces Rax as follows:

Rax is a cross-container JS framework based on the React paradigm.

![](https://gw.alicdn.com/tps/TB1GloTOVXXXXa1XVXXXXXXXXXX-1455-368.jpg_500x500.jpg)

After gzip compression, Rax is only 8 KB, making it much lighter than Angular, React, and Vue. Compared with React’s 43.7 KB, it is far smaller.


Rax abstracts the concept of a Driver in its design to support rendering in different containers. For example, the currently supported Web, Weex, and Node.js are all based on the Driver concept. Even if more containers emerge in the future, such as VR and AR, Rax can handle them with ease. Rax is designed to smooth over differences across platforms as much as possible, which also means developers no longer need to spend too much effort on platform differences and compatibility.

If technologies like RN and Weex are used for cross-platform development, then Rax is used for cross-container development: Browser, Weex, Node.js, and so on.

So what can adding Rax to Weex enable? Worth looking forward to!

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/weex\_best\_practice\_guidelines/](https://halfrost.com/weex_best_practice_guidelines/)

------------------------------------------------------

Weex source code analysis series:

[How Weex Runs on the iOS Client](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_how_to_work_in_iOS.md)  
[The Weex Layout Engine Powerfully Driven by the FlexBox Algorithm](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_layout_engine_powered_by_Flexbox's_algorithm.md)  
[Things You Should Know About Weex Event Propagation](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_events.md)     
[The Ingenious JS Framework in Weex](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_ingenuity_JS_framework.md)  
[A Pseudo Best-Practices Guide to Weex for iOS Developers](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOS/Weex/Weex_pseudo-best_practices_for_iOS_developers.md)  

------------------------------------------------------