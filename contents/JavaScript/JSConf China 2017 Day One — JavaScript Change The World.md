

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-95173eecbedc3a16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


今天有幸参加了 JSConf China 2017 ，作为大会第一天，我来谈谈个人对大会的一些感想。至于大会讲的更加详细的内容可以直接翻到本文末尾，我和另外一个位前端小伙伴一起写的非常详细的笔记，版权在掘金，感兴趣的可以点链接去看看。



![](http://upload-images.jianshu.io/upload_images/1194012-cdb59b045ad66da8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




## 第一场 Programming the Universal Future with next.js



![](http://upload-images.jianshu.io/upload_images/1194012-0168f7d29121b285.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-a8a8b0a1802cc6a1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



第一场是来自 ZEIT 的大神，讲的是 next.js。


现场演示了 React 是如何利用 next.js 进行服务器端渲染的。

next.js 支持 static projects、package.json(node 项目)、Dockerfile 项目配置一键部署。

开发中常见的需求：自定义 URL，服务端渲染、实时日志，这些也都只需要一个 next 命令就可以搞定！

现场演示了经过 next.js 改造之后的服务器端渲染的性能，页面首屏直接秒开，再也没有了 loading 半天的情况了。用户体验极佳。除了这个以后还演示了懒加载 React 组件。React 组件可以按需加载，再也不用一开始加载所有组件了，这样提高了很多性能。演示中还展示了 next.js 的热加载的功能，hot-reload ，极大的提高了开发效率。


## 第二场 理解现代 Web 开发



![](http://upload-images.jianshu.io/upload_images/1194012-1723c635f861885a.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-0b653a0018884074.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



这个演讲提到了太多的话题了。而且演讲过程中语速非常快，keynote 一页一页的。涉及的点实在是广，据说前端没有五到十年经验是无法领悟到其中的精髓的。



这一讲讲师放出了PPT，很值得大家去学习，链接在这里[《理解现代 Web 开发》](https://speakerdeck.com/dexteryy/understanding-modern-web-development-at-jsconf-china-2017-zhong-wen)

关于讲师的 GitHub 上还有一个[《现代 Web 开发者的魔法书 Spellbook of Modern Web Dev》](https://github.com/dexteryy/spellbook-of-modern-webdev) 同样非常推荐阅读。


### 1. 如何看待开发的变化

未来的开发形式走向(移动化 ----> AI 时代 ----> XXX时代的前夜) 这些问题都比较值得我们深思。

### 2. JavaScript Fatigue

根源在于：

1. 多样性  
开发者基数大，每年增加100%，明年超过 Java，任何时候都有 50% 社区成员今年才开始写 JS。
2. 需求多
3. 成本低  
JS 是抽象层最高的语言之一，使用的API是抽象层对高的 API 。

JavaScript Fatigue 的解决办法是：普及维护低成本，填补缺失的中间层。

### 3. Awesome List

现在批评了 awesome list 这种 repo，列表膨胀，无效过时的curation太多。缺少和结构。然后安利了 spellbook，spellbook 就是对 awesome list 的缺点进行的改良，还提供最细粒度的类别。

### 4. CSS 的未来

CSS最大的趋势，从面向文档转变成面向组件。

### 5. Web开源生态
  
1. Web开源生态 = npm 生态  
2. 五大流派  
3. universal JS


## 第三场 后 ES6 时代的 JavaScript 语言



![](http://upload-images.jianshu.io/upload_images/1194012-8a16f95517d86c8f.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



这一场是由百姓网的 贺老 Hax 带来的分享。前半段主要谈 ES6 的新特性是如何被各大浏览器厂商完美支持的。中间遇到了不少困难。还有各个提案是如何一步步的从 S0 到 S4 落地的。

中间主要谈 ES7 的新特性，这里谈到了 JS 的单线程的问题，这个问题我听的比较认真，毕竟客户端开发的同学平时都是接触到多线程的概念。

JS 是单线程？

Worker 其实就是类似线程。Worker 的通信是消息传递的，message 事件传递的。一般多线程编程里面是共享内存。

RTC ，run to completion，JS 函数从头运行到底，一般都不会被打断的。JS 是使用 run to completion 语意的语言。在增加 Async/Await 打破了run to completion 语意，但是还是可控的，只在标识了 Async/Await 的地方可能会有变量的改变，其他没有标识的地方还都是 run to completion 可控的。SharedArrayBuffer 也同理。

node.js 没有 worker，不过node.js开发组已经考虑会加入相关的 API。

最后，贺老提到了更多的新特性，import() 动态加载、数组和对象的展开运算符、正则表达式的一些特性、global 变量、Class 特性扩展支持私有属性、上周新提出的提案 Pattern Match、WebAssembly等等。还有更多细小的点，看下图吧：


![](http://upload-images.jianshu.io/upload_images/1194012-ee82cc21476ce79d.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-3f44e82ab0445028.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




## 第四场 前端工程中的编译时优化



![](http://upload-images.jianshu.io/upload_images/1194012-5bc42f94a8c1cfd9.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-27a89ac2eabf3c8e.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



这一场就是尤大的演讲啦！[尤大的演讲稿分享地址](https://docs.google.com/presentation/d/1ot0JYflhGmPq5Y_PAIEEyYH4APWBK17Zf7-d1dM4v7g/edit#slide=id.p)



![](http://upload-images.jianshu.io/upload_images/1194012-e806bd0f5143235b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

前端 JavaScript 虽然是脚本语言，没有 buildtime，但是现在前端工程里面一样需要有编译的过程。在编译的时候可以进行分析和优化。V8 的实现中就有相关的编译工程，会把 JavaScript 的源码最终编译成机器码。



![](http://upload-images.jianshu.io/upload_images/1194012-7d33677f33e7e73a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


平时我们经常会用到 JS 的 modules ，但是模块化了以后，打包以后会难以压缩代码。为了解决这个问题，就诞生了 Rollup。


![](http://upload-images.jianshu.io/upload_images/1194012-ca035c084825f981.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

webpack 3.0 以后的版本通过 ModuleConcatenationPlugin 插件支持了 Treeshaking 的特性。

### 前端编译的优化方案

前端工程化发展到今天，慢慢的开始思考编译器能做哪些优化，原则是：


![](http://upload-images.jianshu.io/upload_images/1194012-f45276d03dc753fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Do more at build time，Do less at runtime。

于是在 build time 的时候，大家想出了很多优化的点：



![](http://upload-images.jianshu.io/upload_images/1194012-9b577f4146fcc65e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Svelte 是一个完全依赖于编译的框架。可以不依赖任何 runtime 的 lib 就可以编译 JS 代码。


![](http://upload-images.jianshu.io/upload_images/1194012-dda705e3c56c0909.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Relay Modern 通过静态的预编译摆脱昂贵的 runtime query construction。


![](http://upload-images.jianshu.io/upload_images/1194012-619ca41b62be174d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Prepack 的思路比较清奇，它会在编译器把能计算的东西都计算好，然后用计算好的结果直接替换源代码。比如一个函数返回值如果是固定的。那么 Prepack 在编译器就会直接把这个函数的返回值计算完，然后删除掉这个函数，只留下这个返回值。


![](http://upload-images.jianshu.io/upload_images/1194012-217112a91ae4c102.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Rakt 在应用层面进行编译时优化。

最后讲了 Vue 在 编译器的8点优化：

1. Hoisting Static Trees
2. Skipping Static Bindings
3. Skipping Children Array Normalization
4. SSR Optimizing Virtual DOM render functions into string concat
5. SSR inferring async chunks
6. SSR inlining Critical CSS
7. IDEA compile away parts of vue that's not used in your app
8. IDEA styletron-style atomic CSS generation at build time

我主要关注了 SSR 的3点优化：


![](http://upload-images.jianshu.io/upload_images/1194012-1f42b6626852a18a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-5cec91553c4b6e14.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-5b27eb8f8d7555ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




## 第五场 学习 React Native 你需要知道的一切




![](http://upload-images.jianshu.io/upload_images/1194012-ef3ef23ec052c1d5.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



React Native 对很多客户端开发的同学算比较熟悉了。

开始分析了一下 RN 为什么会这么流行：

1. 热更新
2. 使用现代 web 技术开发移动端
3. 跨平台

RN 对应的缺点：

1. Breaking changes 太多
2. 文档不易理解，导致学习成本高
3. Navigation：导航组件问题校对


这里重点谈了 Navigation 的问题，给了以下这些可选的方案：



![](http://upload-images.jianshu.io/upload_images/1194012-b06f79884c746021.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



最后谈到了 State 状态管理，分享者也谈到了 Redux 比较重，推荐了另外3个库：Mobx、Mobx State Tree、Dva。

所以 RN 的 状态管理可以用以下这些方式了：



![](http://upload-images.jianshu.io/upload_images/1194012-3eec96a6fd5b3209.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



1. Built-in state
2. Redux
3. Mobx
4. Mobx State Tree
5. Dva



## 第六场 TypeScript, Angular 和移动端的跨平台开发



![](http://upload-images.jianshu.io/upload_images/1194012-caa18c05112ce356.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




这一场是一个来自 Google 的工程讲 Angular。

开场就安利了一波 TypeScript。




![](http://upload-images.jianshu.io/upload_images/1194012-21f65fc2d43ff43a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



然后接着讲 Angular。



![](http://upload-images.jianshu.io/upload_images/1194012-a00d6cc3d09b1285.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-13a02596e43c36c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-b2a7cf0e4a97dce1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





Angular 笔者实在没有用过，这里不多介绍它了。

讲完 Angular 又讲了 Ionic Framework。



![](http://upload-images.jianshu.io/upload_images/1194012-f6bfe0c9ba0af607.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-71674837b0c272ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



最后又讲了 Native Script。这个是 Angular 的跨平台原生框架，对手就是 Vue 的 Weex，React 的 React Native。

下面三种图分别是 Native Script 的介绍和跨平台原理。




![](http://upload-images.jianshu.io/upload_images/1194012-0ada56ab65594d97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-96c2474aca1dc617.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-e8f7a35f0fbb72e8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


目前用到最多的就是 React Native，Weex 用的人都不是很多(还在用 Weex 的可以在文章下面留言)，笔者周围在用 Native Script 开发的，十个手指头都数的过来(用 Native Script 开发的可以在文章下面留言)。

鉴于 Native Script 使用度不是很高，这里也不多说了。 


## 第七场 Ruff loT 应用开发



![](http://upload-images.jianshu.io/upload_images/1194012-21887867f8cd48d6.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-8d2473197ea7f6da.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-0a6332289d5442fa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-c9e3dd6f61c3fa66.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



这一场讲的是如何用 JS 去开发硬件。软件工程师也可以用高级抽象语言 JavaScript 去开发物联网了。Ruff 把底层的硬件代码都封装起来了。
传统的硬件代码大概像下面这样：

```

GPIO.output(11, GPIO.HIGH)

```
这段代码大多数的软件工程师可能都看不是很懂。

General Purpose Input Output （通用输入/输出）简称为GPIO，或总线扩展器，人们利用工业标准I2C、SMBus或SPI接口简化了I/O口的扩展。当微控制器或芯片组没有足够的I/O端口，或当系统需要采用远端[串行通信](http://baike.baidu.com/item/%E4%B8%B2%E8%A1%8C%E9%80%9A%E4%BF%A1)或控制时，GPIO产品能够提供额外的控制和监视功能。

第一个入参11，一般人也不知道这个是干嘛的。在硬件里面有00，01，10，11这几个值。

HIGH是高电平。在硬件编程里面会有高电平，低电平。

如果能把这些令软件工程师费解的硬件代码封装成上层软件可读性比较强的代码，就会对软件工程师非常的友好。

如果封装成下面这样：

```

led.turnon()

```

软件工程师一眼就知道这在干什么了，可读性非常强。这句话就是在打开一个 LED 灯。


Ruff 平台就做了这些事情，把复杂的硬件代码都封装了成简单易用的 JS API 了。

JavaScript 工程师可以用  jQuery 给孩子写玩具了！


最后如果想看更加详细的笔记，请看掘金这个[链接](https://juejin.im/post/5969821851882534a31cab5b)，是我和另外一个小伙伴一起记录的。

## 感想

第一天讲了这么多主题，其实感受的到，当今的 JavaScript 语言能做的事情越来越多了，所以文章的标题取名为 JavaScript Change The World。

全场听下来，收获最多的可能就是尤大讲的吧。这次大会其他讲师有些分享可能平时开发中也不会用到，不过听听各家对前端技术发展的不同看法也是挺不错的。



前端虽然近几年发展突飞猛进，“魔爪”向前伸向了客户端，向后伸向的后端，向下伸向了硬件，看似无所不能。但是前端依旧还有很多可以改进的地方，比如 JS 的 Class，多线程。这些都可以像面向对象的语言学习。前端工程化也可以慢慢考虑编译期优化了，这块对于客户端开发语言，天生就是编译语言来说，Clang + LLVM 里面的黑魔法般的优化也许值得前端学习的点也挺多的。


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jsconf\_china\_2017/](https://halfrost.com/jsconf_china_2017/)