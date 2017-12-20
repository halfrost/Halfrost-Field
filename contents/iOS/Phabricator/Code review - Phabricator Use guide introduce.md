<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-dc92dffb821d6ce9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## 前言    
   今天给大家分享一下我之前在公司搭建的一个Code Review服务器的一些心得吧。由于现在移动互联网更新迭代速度很快，分布版本的速度基本上决定了创业公司的生命，所以代码质量在决定产品质量上也体现出尤其重要的地位。

    目录
    1.Phabricator Summary
    2.pre-push code review tool —— Differential
    3.code repository browse tool — Diffusion
    4.post-push code review tool —— Audit
    5.Other Feature Summary
    6.Final

#### 一. Phabricator Summary
今天我要向大家分享的是一款非常棒的代码检视工具Phabricator。Phabricator是Facebook保驾护航的11大IT技术之一。在Phabricator的网站中，开发者给出了这样的描述：“Facebook的工程师们毫不掩饰自己对于Phabricator的喜爱之情，他们甚至将它视为’顺利’与’严谨’的代名词”。下面我就将演示使用Phabricator进行代码检视的流程以及它的亮点。

> Facebook 保价护航的11大IT技术
1.HTML5
2.Facebook平台
3.Facebook虚拟币
4.Facebook应用
5.开放计算项目
6.Hadoop
7.LAMP堆栈
8.Scuba
9.HipHop For PHP
10.Scribe 与 Thift
11.Phabricator

这就是搭建好的服务器的界面

![](http://upload-images.jianshu.io/upload_images/1194012-2aac90194fcb247f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 二. Differential
Differential是Phabricator核心功能之一，它是开发者相互检视代码，互相讨论代码的主要平台。

谈到如何生成Diff，此处需要用到Arcanist Tool工具了。

1.DownLoad Tool 下载Arcanist Tool

![](http://upload-images.jianshu.io/upload_images/1194012-0cb7d73b33d2b5eb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2.Edit Path 配置path路径
![](http://upload-images.jianshu.io/upload_images/1194012-b2939dd587f84f1b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.install certificate 安装证书
![](http://upload-images.jianshu.io/upload_images/1194012-9016eb3624214f9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

4.install certificate 验证证书token
![](http://upload-images.jianshu.io/upload_images/1194012-74c12121defa9fb1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5.creat diff 生成diff

![](http://upload-images.jianshu.io/upload_images/1194012-bfc62b4ab782de65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

6.edit diff info 编辑diff的信息

![](http://upload-images.jianshu.io/upload_images/1194012-4cb2db4f59eb3b03.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

到此就生成了一个diff了。相应的，在搭建的服务器网页上也应该对应的有一条diff记录
![](http://upload-images.jianshu.io/upload_images/1194012-7bf98ce3a90abce7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

现在应该到了pre-push code review，提交之前等待审核代码的人审核了。

![](http://upload-images.jianshu.io/upload_images/1194012-9e61121c03b3f55a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-dc5fdb22cd13ba04.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-ad02ed72daf6e7f2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-56fc42fcf5704311.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

审核代码的人界面上面就会出现这样的界面

![](http://upload-images.jianshu.io/upload_images/1194012-d34acabd1eff76d0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当审核人同意通过后，申请审核的人的界面会收到通过的通知

![](http://upload-images.jianshu.io/upload_images/1194012-da6258378190cd76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-b8b22e89915cb850.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 三. Diffusion
Phabricator提供一个类似于gitlab之类的远程仓库浏览工具diffusion，开发人员可以快速查看以下信息
1.VCS Repertory information 线上版本控制系统 仓库信息

![](http://upload-images.jianshu.io/upload_images/1194012-40b2facdc859325e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-55d65be193b68502.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2.VCS commit history 提交历史

![](http://upload-images.jianshu.io/upload_images/1194012-1bbe2e7ca4d1fc9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.Repertory directory structure 仓库目录树


![](http://upload-images.jianshu.io/upload_images/1194012-096e9c4661858248.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

4.Directory structure & commit information 提交信息

![](http://upload-images.jianshu.io/upload_images/1194012-d7b0afe985b0ae5d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5.Branches information 分支信息

![](http://upload-images.jianshu.io/upload_images/1194012-9ac2dd3a89ea716e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 四. Audit 审计

1.区别
很多人会有疑惑了，我们有了Differential，那么现在为何还需要一个Audit ？

下面我来解释解释Review vs Audit的区别

> 1.Phabricator supports two similar but separate code review workflows:

> 2.Differential is used for pre-push code review, called "reviews" elsewhere in the documentation. You can learn more in Differential User Guide.

> 3.Audit is used for post-push code reviews, called "audits" elsewhere in the documentation. You can learn more in Audit User Guide.
(By "pre-push", this document means review which blocks deployment of changes, while "post-push" means review which happens after changes are deployed or en route to deployment.)

> 4.Both are lightweight, asynchronous web-based workflows where reviewers/auditors inspect code independently, from their own machines -- not synchronous review sessions where authors and reviewers meet in person to discuss changes.

以上是FB官方的解释，简单的来说，Differential是代码提交VCS仓库前的代码检视工具，但是有些情况下我们的代码由于某些情况来不及做非常细致的pre-commit review，需要提前部署。那么有什么办法在在代码提交VCS之后来进行代码检视，保证我们的代码质量呢？答案是Audit。这就是Audit的职责。

2.工作原理
这里还会有人问了，Audit是怎么工作的呢？工作原理是什么呢？
Audit主要是由一些Audit请求触发器实现的。

Audit工具主要跟踪两件事：
- 代码提交（Commits），以及它们的审核状态（譬如“未经审核（Not Audited）”、“认可（Approved）”、“引发担忧（Concern Raised）”）。

- 审核请求（Audit Requests）。审核请求提醒用户去审核一次提交。它有多种触发方式。

现在说完了它的工作原理，我们来看看它的界面

![](http://upload-images.jianshu.io/upload_images/1194012-50a25fd88098eec2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.Audit类型  

Audit又可以分为2种：
- 必要的审核（Required Audits）。当你是某个项目的成员，或者是一个包的拥有者，Required Audits提示你去审核一次提交。当你认可这次提交时，审核请求会被关闭。

- 问题提交（Problem Commits）。是指有人在审核过程中对你提交的代码表示担忧。当你消除了他们的疑虑并且所有审核人均对代码表示认可时，问题提交将会消失。

4.Audit流程
举个例子来详细说明一下Audit的流程：

A进行了一次代码提交
B接收到审核请求
过了一阵儿，B登录Phabricator并在首页看到审核请求
B检查A提交的代码。他发现代码中的一些问题，之后他选择了“引发担忧”选项，并且在评论中描述了这些问题
A收到一封关于B对她的提交表示忧虑的email。她决定过一会儿再处理这个问题
不久后，A登录Phabricator并在首页“问题提交”下看到提示
A通过某些方式解决了那些问题（如“找B讨论”、“修复问题并提交”）
B表示满意，并认可了最初那次提交
审核请求将从B的待办事项中消失。问题提交也会从A的待办事项里消失

以上就是Audit的标准的流程了。

5.Audit Triggers 触发器
审核请求可由以下4种方式触发：
- 将“Auditors: username1, username2”写入提交注释中，会触发上述用户接到审核请求。
- 可以在Herald工具中，根据提交的属性创建一系列的触发规则。如有文件被创建、文本被修改，提交人等。
- 可以在任何提交中，通过提交注释为自己创建审核请求。
- 你可以创建一个包，并且选择“开启审核”，这个功能是更强的特性，而且可能对于非常大的团队比较有用

6.关于Audit的小建议
- 审核人的责任感。在审阅一次代码提交时，你所负责的审核是被突出显示的。你要为自己的任何审核行为负责。
- 在diff对比区域，点击行号将可添加内嵌评论。
- 在diff对比区域，在行号上拖动可添加跨越多行的内嵌评论。
- 内嵌评论最初只保存为草稿，直到你在页面底部提交评论。
- 按“?”键查看快捷键。

Raise Concern

![](http://upload-images.jianshu.io/upload_images/1194012-2d78952c638a8c92.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Add Comment


![](http://upload-images.jianshu.io/upload_images/1194012-2b0ca4ef38e934b6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 五. Other Feature Summary 其他的一些常用功能
- Maniphest：任务管理和缺陷追踪(类似于Github的Issue)
- CountDown：定时提醒工具
- Repository：远程VCS仓库管理
- Herald Rule：创建自定义规则，当某些事件触发了规则时提醒我们(类似于IFTTT)

#### 六. Final
最后来谈谈phabricator的优点吧。

- phabricator 中也是通过提交request来展示diff做reivew.但是他的diff不是文件的全部内容，只是diff的部分，所以不需要事先在工具里添加库，可以直接提交diff，也可以粘贴diff的内容来提交。
- 不光只有代码review工具，还有bug跟踪，wiki等功能。可以直接做单元测试,bug与代码review的关联。
- 按request状态分类清晰，搜索功能好用。
- 支持svn 和 git。
- 所有检视工作只需要一个浏览器，不需要安装额外的插/软件。
- 操作界面和易用性非常棒。可自定义界面布局和主题，更加时尚和有活力

>“The function of good software is to make the complex appear to be simple”        
         
> –Grady Booch,One of the UML founders


“好的软件的作用是让复杂的东西看起来简单。” 
(Grady Booch，UML创始人之一)

大家都来一起体验code review的强大吧！！


这篇是分享给大家使用Phabricator的方法，公司里面有这个服务器的，或者买了Phabricator服务的，又不会使用的，看了我这篇文章应该能上手用起来啦！！有时间再给大家分享一下我当时自己搭建这个服务器遇到的一些坑吧。这篇分享就到这里了，欢迎大家一起讨论！

这里是我当时在公司给大家分享时用的Keynote，做的一般，也一起分享出来给大家看看吧：http://pan.baidu.com/s/1dFiAaM9


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/code\_review\_phabricator\_use\_guide\_introduce/](https://halfrost.com/code_review_phabricator_use_guide_introduce/)