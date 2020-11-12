+++
author = "一缕殇流化隐半边冰霜"
categories = ["Vue.js", "Electron"]
date = 2017-06-17T09:50:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/49_0_.png"
slug = "vue_electron"
tags = ["Vue.js", "Electron"]
title = "Vue 全家桶 + Electron 开发的一个跨三端的应用"

+++


利用 Vue.js 实现 [objc中国](https://objccn.io/) 的跨平台全栈应用

- ✅ 桌面应用，支持 Mac、Linux、Windows 三个平台
- ✅ Web 应用，支持 桌面浏览器 和 手机浏览器
- ✅ 手机 App，目前只支持了 Cordova 框架，支持 iOS、Android、Windows Phone、BlackBerry 四个平台
- ❌ 手机原生 App，打算用 Weex 框架，同样一起支持 iOS 和 Android 两个平台


![](https://img.halfrost.com/Blog/ArticleImage/49_1__.png)


> 注：此项目纯属个人瞎搞，请大家支持 喵神(@onevcat)，支持 [Objc中国](https://objccn.io/)。

## 前言

### 一.关于我

我是一名全职的 iOS 开发者，非前端开发者。由于接触了 Weex 开发，从而接触到了 Vue.js。

### 二.为什么会写这个项目？

1. 最开始有这个想法的时候是来自一个网友，他在我的博客上问我，网上有没有写的比较好的 Weex demo ？我说尤大写的那个 Hacker News 是最好的。后来网友就说，楼主能写一个么？我当时回答暂时不行。其实这事我一直记在心里。

2. 今年5月19号，GitHub 使用 Electron 重写了 macOS 和 Windows 的客户端，加上近些年跨端开发越来越火，对于一些公司来说，Web 和 app 应该都是需要的，app 还需要 iOS 和 Android 两个平台，再有甚者还要开发小程序，桌面级的应用虽然少，但是用 Electron 一样可以一起开发了。自己也萌生了想要跃跃欲试的念头。

3. 由于接触到了 Vue.js，当然不想停留在初级，想进阶，尤大给出了建议，就是多实践，多练。为了加快进阶的步伐，自己私下就找项目练。

4. 至于为何选择 Objc 中国，理由其实很简单，因为我是 iOS 开发者。在 iOS 开发者中，Objc 基本上人尽皆知（有不知道的？），喵神也基本上人尽皆知，我个人很崇拜喵神，所以就选了 Objc 中国来写。

5. 因为爱 ... ...

### 三.这次为何跨端开发没有weex？

这次在我写完项目以后，发现 Vue 的代码直接转换成 Weex 的项目，是无法实现的，好多报错。而且不是一下子能都修复好。我相信是我使用姿势的问题，不是 Weex 的问题。对了，Weex 又发布新版本了，接下来有时间的话就把 Weex 版的也做一遍开源。

好了，进入正题，说项目：

------



## 技术栈和主要框架

- Vue 全家桶：vue2 + vuex + vue-router + webpack  
- ES6     
- 网络请求：axios  
- 页面相应式框架：bootstrap，element-ui  
- 后台：express  
- 代码高亮：highlight.js  
- 数据库：lowdb  
- markdown解析器：vue-markdown  
- 表单验证：vee-validate  
- 跨平台框架：Electron  

## 项目构建

由于喵神的 Objc 网站是直接返回 html，所以想进行模拟网络请求返回数据，就只能自己搭建一个后台，写 api 返回数据了。

我利用 Express 把后台搭建在 8081端口上，并写好路由，请求会转到8080，开启服务器的时候也会自动开启后台。

``` npm

# install dependencies 安装依赖
npm install

# serve with hot reload at localhost:8080
npm run dev

# serve with hot reload at localhost:8080
npm run start

# build for production with minification 打包
npm run build

# build for production and view the bundle analyzer report
npm run build --report

# run unit tests
npm run unit

# run e2e tests
npm run e2e

# run all tests
npm test

# 打包 Mac 应用
npm run build:mac

# 打包 Linux 应用
npm run build:linux

# 打包 Win 应用
npm run build:win

# 打包 Cordova 应用
npm run build:app

```

这里要单独说一下 Cordova 的打包方式，它比桌面端的稍微特殊一点。

首先把 src/main.js 文件中关于 Coredova 的三行注释打开，Coredova 库的初始化需要包在生成 Vue 实例 的外面。打开注释以后，再执行接下来的步骤。

我在项目中放了一个 Makefile，可以根据这个来做。

1. 首先全局安装 cordova 命令
> npm install -g cordova 

2. 再输入下面的命令，生成 app 项目目录
> cordova create app com.vueobjccn vueobjccn

3. 进入到 app 文件夹中
> cd app

4. 添加对应的平台
> cordova platform add ios  
> cordova platform add android

5. 运行项目
> cordova run ios  
> cordova run android

Cordova 只生成了一个壳的 app，里面具体的内容还是读取的网页，在生成的对应的应用里面有一个 www 的文件夹，这个文件夹里面就是要加载页面。JavaScript 打包之后是会生成 www 的文件夹，只要去替换 Cordova 对应平台里面的 www 文件夹里面的内容即可。

额外说几句，在 app 发展到现在这么成熟的时代，如果构建一个大的 app，用 Cordova 框架去做，不用原生，不做任何优化，用户体验确实不如原生的快。我这次就专门打包体验了 Cordova app，没有做任何优化，打包出来就用，如果是挑剔的用户，放在当今各大 app 接近完美的体验度相比来说，确实会感到满足感略低。如果真的要前端开发 app ，给2个建议，如果是用 Cordova 框架，一定要尽量优化优化，不然性能不如原生。如果想有接近原生的体验，那么可以考虑用 React Native 或者 Weex。


## 跨平台开发


JavaScript 跨平台开发打包成桌面级应用，主要用 Electron 框架。这里需要在 devDependencies 里面安装好 "electron"、"electron-builder"、"electron-packager" 这三个。其他的路径配置在 webpack 里面配置好即可。

关于 Cordova 的安装，确实可以吐槽一点网络的问题。如果你在一个翻墙环境很差的地方，真的很痛苦。比如之前在一个翻墙环境很差的情况下全局安装 Cordova ，各种报错，就算是换了 cnpm 完全安装了以后，添加 iOS 平台以后以后会报一个 co 文件找不到的问题，感觉是 cnpm 没有把命令安装完整。后来我回到家里，翻墙网络很好，npm install 一下子就安装好了。不过有个小插曲：Cordova iOS 4.4.0 template 如果报错，就多安装几次，原因还是翻墙的原因，没有 catch 到。

还有可能会遇到下面这个错误：

> "Error: Cannot find module 'config-chain'" when running 'ionic start'

这个错误就用 sudo 命令重新尝试一遍原命令就好了。

最终打包完成会在 dist 的文件夹中。


接下来展示一下这个跨三端的应用在各个平台下的表现：

先展示一下 Web 端

![](https://img.halfrost.com/Blog/ArticleImage/49_1.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_3.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_4.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_5.png)

再展示一下在手机浏览器上的效果：

Android平台

Nexus 5x 的 Web


![](https://img.halfrost.com/Blog/ArticleImage/49_6.png)


Nexus 6P 的 Web

![](https://img.halfrost.com/Blog/ArticleImage/49_7.png)

iOS 平台

iPhone 5 的 Web


![](https://img.halfrost.com/Blog/ArticleImage/49_8.png)


iPhone 7 的 Web

![](https://img.halfrost.com/Blog/ArticleImage/49_9.png)


iPhone 7 Plus 的 Web

![](https://img.halfrost.com/Blog/ArticleImage/49_10.png)


iPad 的 Web

![](https://img.halfrost.com/Blog/ArticleImage/49_11.png)




接着再看看 Mac 端上的表现：


![](https://img.halfrost.com/Blog/ArticleImage/49_12.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_13.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_14.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_15.png)


最后看看 Cordova 的效果：

![](https://img.halfrost.com/Blog/ArticleImage/49_16.png)


![](https://img.halfrost.com/Blog/ArticleImage/49_17.png)


![](https://img.halfrost.com/Blog/ArticleImage/49_18.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_19.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_20.png)

![](https://img.halfrost.com/Blog/ArticleImage/49_21.png)



## 功能展示

用 Vue.js 搭建一个 Web 页面很快。

![](https://img.halfrost.com/Blog/ArticleImage/49_22.gif)


看看 Vuex 管理状态的方便。登录状态保存在 state 里面，全局都会获取到。



![](https://img.halfrost.com/Blog/ArticleImage/49_23.gif)



一旦用户没有登录，点击购买电子书的时候，判断没有用户登录都会跳转到登录页面。

还有一点值得说的是，由于这是一个 SPA ，所以里面的路由都用 Router-link 实现的，而没有选用 `<a>` 标签的跳转，效果就是跳转并不用去请求数据，秒跳。这个用户体验真的很爽。

`<router-link>` 比起写死的 `<a href="...">` 会好一些，理由如下：

无论是 HTML5 history 模式还是 hash 模式，它的表现行为一致，所以，当你要切换路由模式，或者在 IE9 降级使用 hash 模式，无须作任何变动。

在 HTML5 history 模式下，router-link 会拦截点击事件，让浏览器不再重新加载页面。

当你在 HTML5 history 模式下使用 base 选项之后，所有的 to 属性都不需要写（基路径）了。


![](https://img.halfrost.com/Blog/ArticleImage/49_24.gif)



登出页面同理，一旦用户登出，所有显示用户名的地方都会变成登录，navigationBar 上的购物车也一并消失。用 Vuex 管理状态，挺好的。


![](https://img.halfrost.com/Blog/ArticleImage/49_25.gif)



这就是 email 的表单验证了，没有太多的技术含量。


![](https://img.halfrost.com/Blog/ArticleImage/49_26.gif)



这里是购物车页面，这里用到了 MVVM 页面的绑定的思想，页面上4个按钮，点任意一个按钮都会立即改变下面的总价。关于 Vue.js 的 MVVM 实现思想值得 iOSer 们学习。

接下来这个是 iPhone 的 Safari 上的表现，速度还可以。


![](https://img.halfrost.com/Blog/ArticleImage/49_27.gif)



在跨平台的这几个应用中，体验最好的，我觉得还是 Mac 的应用。使用起来满意度非常高。


![](https://img.halfrost.com/Blog/ArticleImage/49_28.gif)


最后就是 Cordova 框架搭建的 手机 app，体验度不高，具体如何，看图吧，总之不优化的 Cordova ，对于挑剔的我来说，我是不满意的。

iPhone 上的应用

![](https://img.halfrost.com/Blog/ArticleImage/49_29.gif)


iPad 上的应用

![](https://img.halfrost.com/Blog/ArticleImage/49_30.gif)



## 项目完成之后的感想

先安利一下 element-ui 这个项目，用它来搭建项目，真的很快，页面很快就可以搭建完成，开发 Vue.js 的同学一定有听过这个库。节约出来的大把时间可以把更多的精力放在业务开发上面。

大家都在说现在是大前端时代，移动开发和前端融合是必然。但是两个平台的开发其实还是有很多的不同，我在经历过前端的开发和 iOS 开发以后，感想还是很多的，前端和 iOS 是有很多可以相互学习的地方，两者也各有优缺点。接下来我打算写写这些方面的系列文章。前端的工程化，组件化，路由，MVVM，分别和 iOS 这边各有哪些优缺点，相互可以学习些什么。（感觉给自己挖了一个大坑）


## Feature


有时间就支持 Weex ，把这个 Vue.js 的改成一个完整的 Weex 的应用，变成原生以后，性能一定不会差。这样跨平台开发就应该全了。



## 勘误


如果在项目中发现了有什么不解或者发现了 bug，欢迎提交 PR 或者 issue，欢迎大神们多多指点小弟



## 感谢


如果喜欢这个项目，欢迎Star！



------

## LICENSE

GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.

