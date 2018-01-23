# iOS 开发者的 Weex 伪最佳实践指北


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-5763204636dd1f25.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>




### 引子

这篇文章是笔者近期关于Weex在iOS端的一些研究和实践心得，和大家一起分享分享，也算是对学习成果的总结。文章里面提到的做法也许不是最佳实践，也许里面的方法称不算是一份标准的指南手册，所以标题就只好叫“伪最佳实践指北”了。有更好的方法欢迎大家一起留言讨论，一起学习。

由于笔者不太了解Android，所以以下的文章不会涉及到Android。

### 一. React Native 和 Weex

自从Weex出生的那一天起，就无法摆脱和React Native相互比较的命运。React Native宣称“Learn once, write anywhere”，而Weex宣称“Write Once, Run Everywhere”。Weex从出生那天起，就被给予了一统三端的厚望。React Native可以支持iOS、Android，而Weex可以支持iOS、Android、HTML5。

在Native端，两者的最大的区别可能就是在对JSBundle是否分包。React Native官方只允许将React Native基础JS库和业务JS一起打成一个JS bundle，没有提供分包的功能，所以如果想节约流量就必须制作分包打包工具。而Weex默认打的JS bundle只包含业务JS代码，体积小很多，基础JS库包含在Weex SDK中，这一点Weex与Facebook的React Native和微软的Cordova相比，Weex更加轻量，体积小巧。

在JS端，Weex又被人称为Vue Native，所以 React Native 和 Weex 的区别就在 React 和 Vue 两者上了。



![](http://upload-images.jianshu.io/upload_images/1194012-46105d34246ef565.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



笔者没有写过React Native，所以也没法客观的去比较两者。不过知乎上有一个关于Weex 和 React Native很好的对比文章[《weex&React Native对比》](https://zhuanlan.zhihu.com/p/21677103)，推荐大家阅读。


前两天[@Allen 许帅](http://www.weibo.com/122678100)也在[Glow 技术团队博客](http://tech.glowing.com/cn/)上面发布了一篇[《React Native 在 Glow 的实践》](http://tech.glowing.com/cn/react-native-at-glow/)这篇文章里面也谈了很多关于React Native实践相关的点，也强烈推荐大家去阅读。


### 二. 入门基础


![](http://upload-images.jianshu.io/upload_images/1194012-953ccb5573e125cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




关于小白想入门Weex，当然最基础的还是要通读文档，文档是官方最好的学习资料。官方的基础文档有两份：

[教程文档](http://weex-project.io/cn/guide/)  
[手册文档](http://weex-project.io/cn/references/)  

在文档手册里面包含了Weex所有目前有的组件，模块，每个组件和模块的用法和属性。遇到问题可以先过来翻翻。很有可能有些组件和模块没有那些属性。

### 1. Weex全家桶和脚手架

看完官方文档以后，就可以开始上手构建工程项目了。

我司在知乎上面写了4篇关于[《Weex入坑指南的》](https://zhuanlan.zhihu.com/ElemeFE?topic=Weex)。这四篇文章还是很值得看的。

Weex也和前端项目一样，拥有它自己的脚手架全家桶。weex-toolkit + weexpack + playground + code snippets + weex-devtool。

weex-toolkit是用来初始化项目，编译，运行，debug所有工具。



![](http://upload-images.jianshu.io/upload_images/1194012-03ec89a3507400c2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

weexpack是用来打包JSBundle的，实际也是对Webpack的封装。

![](http://upload-images.jianshu.io/upload_images/1194012-eada7a409d2a64e1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


playground是一个上架的App，这个可以用来通过扫码实时在手机上显示出实际的页面。

![](http://upload-images.jianshu.io/upload_images/1194012-10984a942457d712.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

code snippets这个是一个在线的playground。

![](http://upload-images.jianshu.io/upload_images/1194012-0d80d249e1f3fa45.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


我相信大家应该都有Native的App，如果真的App都没有，那就用weexpack命令初始化一个新的项目。如果已经有App项目了，那么weex命令就只是用来运行和调试的。

已经有iOS项目的，可以通过cocospod直接安装Weex的SDK，初始化SDK以后，Native就可以使用Weex了。加载的JS的地址改成自己公司服务器的IP。

```objectivec

#define CURRENT_IP @"your computer device ip"
// ...

// 修改端口号到你的端口号
#define DEMO_URL(path) [NSString stringWithFormat:@"http://%@:8080/%s", DEMO_HOST, #path]

// 修改 JS 文件路径
#define HOME_URL [NSString stringWithFormat:@"http://%@:8080/app.weex.js", DEMO_HOST]


```

这样整个项目就可以跑起来了。


这里还有一点需要说明的是，项目虽然跑起来了，但是每次运行都需要启动npm，打开Weex的前端环境。这里有两个做法。

第一种做法是直接Hook Xcode的run命令，在Xcode配置里面加入启动npm的脚本。比如下面这样：




![](http://upload-images.jianshu.io/upload_images/1194012-d9d1e69465d6cf71.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



第二种做法就是每次运行之前，自己手动npm run dev。我个人还是喜欢这种方式，因为在Xcode运行完成之前，一定可以在命令行上面打完这些命令。



再说说如何Debug，这块使用的是weex-devtool。



![](http://upload-images.jianshu.io/upload_images/1194012-8a706511d2d5a5a0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这个工具和前端在Chrome里面调试的体验基本相同。

![](http://upload-images.jianshu.io/upload_images/1194012-afc73328b962d3cd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

具体使用方法看这两篇文章即可，这里不再赘述：

[《Weex 入坑指南：Debug 调试是一门手艺活》](https://zhuanlan.zhihu.com/p/25331465)   
[《Weex调试神器——Weex Devtools使用手册》](https://github.com/weexteam/article/issues/50)   

### 2. Weex Market插件


在日常开发中，我们可以全部自己开发完所有的Weex界面，当然还可以用一些已有的优秀的轮子。Weex的所有优秀的轮子都在Weex Market里面。

![](http://upload-images.jianshu.io/upload_images/1194012-561d88f5b37957c5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在这个Market里面有很多已经写好的轮子，直接拿来用，可以节约很多时间。

比如这里很火的weex-chart。weex-chart图表插件是通过g2-mobile依赖[gcanvas插件](https://market.dotwe.org/weex-plugin-gcanvas)实现的

如果你想使用[Weex Market](https://market.dotwe.org/)的Plugin插件，你可以使用weex plugin 命令：

```vim

$ weex plugin add plugin_name

```

你只需要输入插件的名称就可以从远程添加插件到你本地的项目，比如添加 weex-chart，我们可以输入命令：

```vim

$ weex plugin add weex-chart

```

我们可以使用plugin remove移除插件，比如移除安装好的 weex-cahrt：

```vim

$ weex plugin remove weex-chart


```

这个插件库里面我用过weex-router，还不错，用它来做weex的路由管理。推荐使用。


### 3. iOS打包和发布

 weex官方提供了weexpack命令。我觉得这个命令是提供给不懂iOS的前端的人用的。如果是Native来打包，依旧使用的Xcode的Archive打包。

完全不懂iOS的前端开发者可以使用weexpack build ios 打包，中间会要求输入证书，开发者账号等信息。都输入正确以后就可以打出ipa文件了。全程傻瓜操作。如果不清楚的可以查看官方手册：  
weexpack 官方手册 [《 如何用weexpack创建weex项目并构建app 》](https://github.com/weexteam/weex-pack/wiki/%E5%A6%82%E4%BD%95%E7%94%A8weexpack%E5%88%9B%E5%BB%BAweex%E9%A1%B9%E7%9B%AE%E5%B9%B6%E6%9E%84%E5%BB%BAapp)  


如果是iOS开发者，原来怎么打包现在还是怎么打包。只不多JS这块要单独进行打包。建议是把Weex这块单独用一个git分支进行管理，专门针对这个分支进行weexpack或者Webpack进行打包。webpack的具体配置由每个公司自己配置。

这里额外说一点，这一点也是前端大神告诉我的。webpack打完包以后是可以通过webpack官方网站查看这个包里面究竟打入了哪些文件和依赖。虽然我打包都是一股脑的都打完，但是资深前端开发也许还会再去检查一下是否有多的文件被打进去了。极限压缩包的体积，1KB的文件也不多放进去。


再谈谈发布的问题。由于有了Weex以后，每次发布都会把上个版本累计到这个版本的hotPatch都累计修复掉，并在新版里面直接内置最新的JSBundle文件。内置JS的目的也是为了首屏加载秒开。


### 4. 热更新

关于热更新的作用大家都明白，不然用Weex的意义就少了好多。不过这里还有一点需要说明的是——热更新的策略。

在日常开发过程中，我们在浏览器上面连着手机调试，也并不是实时刷新的。(不过通过在手机上扫描二维码，并且手机和电脑在同一个局域网之内，可以做到实时更新)

所以在实际生产环境中，热更新的策略应该是这样：有新的HotPatch就下发到客户端，然后客户端在下次启动的时候，先比对版本信息，如果是新版本，就去加载这个最新的HotPatch，然后渲染在屏幕上。

曾经我幻想着能实时在线更新，就是线上一发布，所有用户在联网的情况下，下发HotPatch完毕以后直接加载，联网的用户可以实现秒级别的热更新。这种虽然可以做到，但是意义不大。做法是专门维护一套Websocket，直连服务器，下发完毕以后可以通过调用Native的通知，Native客户端自己刷新页面即可。（目前应该没有多少公司是这样做的吧？）


### 5. JSBundle版本管理与部署

关于JSBundle的版本管理这块是应该交给前端来管理。前端可能会用版本号来管理各个包的版本。部署也会牵扯到每个公司前端部署的流程。他们会更加了解。部署一般也会放到CDN上加速。


### 6. 踩坑和避坑

如果说Weex一点坑都没有，那是不可能的。

比如说在某些界面连续Push的时候，页面边缘会有一些线条从屏幕上扫过。还有捕捉JS错误或者异常的时候，Weex并不能可靠的捕捉到异常，这点需要靠Native来做，Native捕捉到异常以后再传递事件给JS Runtime去处理。

计算页面宽高尺寸这点是最需要注意的。Weex进行界面适配的时候是用750为标准的，所以需要根据750去换算。还有一点是Weex里面有四舍五入的操作，是会丢失一点精度的。具体这块请看[《Weex 事件传递的那些事儿》](http://www.jianshu.com/p/419b96aecc39)这篇文章里面的源码分析。

Weex JS 引擎也不支持 HTML DOM APIs 和 HTML5 JS APIs，这包括 document, setTimeout 等。

Weex关于Web标准的实现现在还没有达到100%，所以用Vue来写Weex的话，有些是不支持的。

比如说一些CSS样式，最令人想不到的就是不支持`<br>`，还不支持`<form>`，`<table>`，`<tr>`，`<td>`，不支持CSS percentage 单位，不支持类似 em，rem，pt 这样的 CSS 标准中的其他长度单位。不支持 hsl(), hsla(), currentColor, 8个字符的十六进制颜色。

Weex对W3C上的FlexBox的规范也没有支持完全，暂不支持inline，也不支持Z轴上面的变化，不过移动端在Z轴上的需求真的没有。Weex的Layout是用的Yoga之前的某个版本，解决问题的方式也比较直接，后期升级到最新版的Yoga，便可以支持更多的Flex的标准了。

具体还有不支持的就要多翻翻文档，比如这里的[《Weex 目前不支持的Web 标准有哪些》](http://weex-project.io/cn/references/web-standards.html)。这些最好先看看，心里有个数，以免开发时候遇到一些莫名的bug，殊不知最终是因为不支持导致的。


然后还有一些是组件暂时还不支持同步方法。这里是Vue 2.0还不支持，官方预计是在 0.12 版本支持。

额外提醒一点，由于苹果前段时间对JSPatch的封杀，所以导致Weex官方对自定义模块给出了一个警告：

> Weex 所有暴露给 JS 的内置 module 或 component API 都是安全和可控的， 它们不会去访问系统的私有 API ，也不会去做任何 runtime 上的 hack 更不会去改变应用原有的功能定位。

>如果需要扩展自定义的 module 或者 component ，一定注意不要将 OC 的 runtime 暴露给 JS ， 不要将一些诸如 dlopen()， dlsym()， respondsToSelector:，performSelector:，method_exchangeImplementations() 的动态和不可控的方法暴露给JS， 也不要将系统的私有API暴露给JS


上述警告特别强调了不要用dlopen()， dlsym()， respondsToSelector:，performSelector:，method\_exchangeImplementations()这几个函数。这也是为什么同样是用Weex有些人没有通过审核，有些人却能通过审核的原因。

听说安卓上有Refresh Control的一些bug，安卓在Weex上的表现我没有怎么了解过，不过这块如果出现在iOS上，我觉得可以直接用Native来替换掉这块，有bug的地方都用原生来做。


总之Weex还是多多少少有一些问题，但是目前使用来看，不影响使用，只要懂得灵活变通，遇到实在过不去的坎，或者是真的一时hold不住的bug，那么多考虑用原生来替代。

### 三. 更多高级的玩法

接下来说一下稍微高级的玩法。以下这些即使没有做，也不影响Weex正常上线。

### 1.页面降级

Weex默认是支持页面降级的。比如出现了错误，就会降级到H5。这里建议最好做一个线上的开关。我司在处理页面降级的问题上采取了两种级别的开关：

1. App级的开关。这个开关是管理用户App是否使用Weex SDK的，这块是可以在线配置的。
2. 页面级的开关。这个开关是管理某个页面是否开启Weex的。如果不开启就降级成H5页面。

除了降级以后，还对应采取了灰度的策略，这样保证线上bug降低到最低。

比如在用户量低峰期的时候开启开关进行灰度。还有一级灰度就通过线上实时错误监控平台来控制，如果因为突发事件导致Crash率陡升，那么就立即关闭Weex的开关，立即进行降级处理。


### 2. 性能监控和埋点


在Weex给的官方Demo里面有一个M的小圆点浮框，点开会看到如下的界面：


![](http://upload-images.jianshu.io/upload_images/1194012-dea1c20cfa2fc3db.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在这里我们点开性能的按钮：

![](http://upload-images.jianshu.io/upload_images/1194012-7534caab12e5681f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在这里我们可以看到监控了CPU，帧率，内存，电量，流量等数据，这些数据也是我们在Native APM中监控的常见数据。当然，这个M圆点并不没有开源。所以这块需要各个公司自己做一套自己的监控系统。这块可能每个公司的前端已经做好了，所以Weex需要接入到前端的性能监控里。



如果我们再点开工具的界面，就会看到如下的选项：

![](http://upload-images.jianshu.io/upload_images/1194012-1429b2bd10bef09c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里就有埋点监控。在初期可能Weex埋点还是由Native进行埋点，因为各家都有自家的Native完整的埋点系统了。后期埋点这块也可以交给前端在前端埋点。


### 3. 增量更新和全量更新

暂时笔者还没有实践过Weex的增量更新，所以这里就不提增量更新了。全量更新就比较简单，下发整个JSBundle，App在下次启动的时候再加载即可。Weex的包比RN的包小很多，一般就100-200K左右。阿里的一次Weex分享里面提到他们gzip压缩以后能达到60-80K。

### 4. 首屏加载时间极致优化


![](http://upload-images.jianshu.io/upload_images/1194012-bd958ca4162d863e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是阿里在Weex Conf大会上提出的一个挑战，网络请求加上首屏渲染的时间加起来小于1秒。

![](http://upload-images.jianshu.io/upload_images/1194012-157fc128529fe9e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里面涉及到3方面的因素，网络下载耗时，JS和Native通信耗时，还有渲染耗时。


网络下载耗时可以通过支持HTTP / 2，配置Spdy协议，域名收敛，支持http-cache，极致压缩JSBundle的大小，JSBundle预加载。

JSBundle预加载的时候可以在App启动时候预先下载JS。远程服务器推包的时候通过长连通道Push，这里可以是全量 / 增量，被动 / 强制更新相互结合。

阿里关于JS和Native通信耗时，渲染耗时的相关优化见上图。这两方面笔者也没有相关的实践。

### 5. Vue全家桶




![](http://upload-images.jianshu.io/upload_images/1194012-1d71013538b2919e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



虽然Weex有属于它自己的全家桶，但是在支持了Vue 2.0以后，它的全家桶完全可以换成Vue的全家桶。Vue，Vue-Router，Vuex，原来还有Vue-resource，不过尤大后来去掉了这个Vue-resource，更加推荐axios了。所以全家桶里面就是Vue，Vue-Router，Vuex，axios。

如果全部都换成了Vue以后，那么前端首屏渲染的速度就需要Vue来解决了。为了提高首屏渲染速度，wns缓存+直出 是必不可少的。在Vue 1. x 时代，没有 server-side-render 方案，直出需要专门给写一份首屏非Vue语法的模板。Vue2.0 server-side-render（简称Vue SSR）的推出，成功地让前后端渲染模板代码同构。

如果只用了Vue-Router以后，当打包构建应用时，JSBundle 包会变得非常大，影响页面加载。如果我们能把不同路由对应的组件分割成不同的代码块，然后当路由被访问的时候才加载对应组件，这样就更加高效了。
结合 Vue 的 [异步组件](http://vuejs.org/guide/components.html#Async-Components) 和 Webpack 的 [code splitting feature](https://webpack.js.org/guides/code-splitting-require/), 轻松实现路由组件的懒加载。减少JSBundle的体积。


还有一点需要注意的是，Vue-Router 提供了三种运行模式：  
hash : 使用 URL hash 值来作路由。默认模式。  
history : 依赖 HTML5 History API 和服务器配置。  
abstract: 支持所有 JavaScript 运行环境，如 Node.js 服务器端。  

不过Weex 环境中只支持使用 abstract 模式！


就在7天前，Vue 发布了v2.3.0版本，官方支持了SSR。所以在支持了SSR以后，可以大幅提升SEO，也可以做到首屏秒开。所以为了性能，SSR必做！


### 四. 顶级玩法

最后的最后，还有一些“前瞻性”的玩法。

### 1. 强大的JSService


JS service 和 Weex 实例在 JS runtime 中并行运行。Weex 实例的生命周期可调用 JS Service 生命周期。目前提供创建、刷新、销毁生命周期。

这块我在官方的Demo里面也没有找到相关的例子。在官方的文档里面有相关的例子。在官方手册里面有这样一句话：

> 重要提醒: JS Service 非常强大但也很危险，请小心使用！

可见，这块非常强大，也许可以做很多“神奇的”事情。


### 2. Weex可能有更大的“野心”



在官方手册[《拓展JS framework》](http://weex-project.io/cn/references/advanced/extend-jsfm.html)这一章节里面，提到了可以横向拓展JS framework。这个功能可能一般公司都不会去扩展。

Weex 希望能够尊重尽可能多的开发者的使用习惯，所以除了 Weex 官方支持的 Vue 2.0 之外，开发者还可以定制并横向扩展自己的或自己喜欢的 JS Framework。

定制完自己的JS Framework以后，就可能出现下面的代码：

```objectivec

import * as Vue from '...'  
import * as React from '...'  
import * as Angular from '...'  
export default { Vue, React, Angular };


```

这样还可以横向扩展支持Vue，React，Angular。


如果在 JS Bundle 在文件开头带有如下格式的注释：

```JavaScript

// { "framework": "Vue" }
...

```

这样 Weex JS 引擎就会识别出这个 JS bundle 需要用 Vue 框架来解析。并分发给 Vue 框架处理。



![](http://upload-images.jianshu.io/upload_images/1194012-6b8f63a4caab42f3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




所以，**Weex 支持同时多种框架在一个移动应用中共存并各自解析基于不同框架的 JS bundle。**

可以支持多种框架并存这点非常强大，当然还没有完，one more thing……

如果正常使用API，看官方文档，不开源码，是不会发现Rax的身影的。官方文档丝毫没有提及到它。

Rax是什么呢？



![](http://upload-images.jianshu.io/upload_images/1194012-6fd4d23ed67306c9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在[《淘宝双促中的 Rax》](http://taobaofed.org/blog/2017/01/13/rax-in-act/)这篇文章里面介绍了Rax：

Rax 是一个基于 React 方式的跨容器的 JS 框架。

![](https://gw.alicdn.com/tps/TB1GloTOVXXXXa1XVXXXXXXXXXX-1455-368.jpg_500x500.jpg)

Rax 经过 gzip 以后的大小 8k，与 Angular、React、Vue 相比更加轻量。相比React的43.7kb，小了太多。


Rax 在设计上抽象出 Driver 的概念，用来支持在不同容器中渲染，比如目前所支持的：Web, Weex, Node.js 都是基于 Driver 的概念，未来即使出现更多的容器（如 VR ，AR等），Rax 也可以从容应对。Rax 在设计上尽量抹平各个端的差异性，这也使得开发者在差异性和兼容性方面再也不需要投入太多精力了。

如果说RN和Weex这些技术是用来跨端的技术，那Rax是用来跨容器的：Browser、Weex、Node.js等。

那么Weex里面加了Rax能干些什么事情呢？值得期待！

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/weex\_best\_practice\_guidelines/](https://halfrost.com/weex_best_practice_guidelines/)

------------------------------------------------------

Weex 源码解析系列文章：

[Weex 是如何在 iOS 客户端上跑起来的](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_how_to_work_in_iOS.md)  
[由 FlexBox 算法强力驱动的 Weex 布局引擎](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_layout_engine_powered_by_Flexbox's_algorithm.md)  
[Weex 事件传递的那些事儿](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_events.md)     
[Weex 中别具匠心的 JS Framework](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_ingenuity_JS_framework.md)  
[iOS 开发者的 Weex 伪最佳实践指北](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_pseudo-best_practices_for_iOS_developers.md)  

------------------------------------------------------