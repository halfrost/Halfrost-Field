+++
author = "一缕殇流化隐半边冰霜"
categories = ["系统简介"]
date = 2015-07-29T16:43:00Z
description = ""
draft = false
slug = "welcome-to-ghost"
tags = ["系统简介"]
title = "欢迎使用 Ghost 博客系统"

+++


Yeah，博客上线了！这篇文章的目的是向你介绍 Ghost 编辑器并帮你快速上手。通过 `<your blog URL>/ghost/` 链接就可以登录系统后台管理你的博客内容了。当你进入后台，你就能看到左侧文章列表处列出的这篇文章，右侧就是这篇文章的预览效果。点击预览栏右上角的铅笔图标就能进入内容编辑页面。 

## 快速入门

Ghost 使用 Markdown 语法书写内容。简单来说，Markdown 就是一种简化的书写格式！

用 Markdown 语法写作是很容易的。在编辑界面的左侧就是你写作的地方。在你认为需要的时候，可以使用以下这些语法来格式化你的内容。例如下面这个无序列表：

* Item number one
* Item number two
    * A nested item
* A final item


还可以是有序列表：

1. Remember to buy some milk
2. Drink the milk
3. Tweet that I remembered to buy the milk, and drank it

### 链接

如果要链接其它页面，可以直接把页面的 URL 粘贴过来，例如 http://www.ghostchina.com - 会被自动识别为链接。但是，如果你想自定义链接文本，可以像这样： [Ghost 中文网](http://www.ghostchina.com)。很简单吧！

### 图片

插入图片也没问题！前提是你事先知道图片的 URL，然后像下面这样：

![The Ghost Logo](http://static.ghostchina.com/image/3/fe/34a9831916be9db1381ecb320491e.png)

如果图片在本地的硬盘里怎么办？也很简单！像下面这样书写就能为图片预留一个位置，然后你可以继续写作，回头再通过拖拽的方式把图片上传到服务器上。

![一张图片]


### 引用

有些时候我们需要引用别人说的话，可以这样：

> Wisdomous - it's definitely a word.

### 代码

或许你是个码农，需要贴一些代码到文章里，可以通过两个引号（Tab 键上面的那个键）加入行内代码 `<code>`。如果需要加入大段的代码，可以在代码前加 4 个空格缩进，这就是 Markdown 的语法。

    .awesome-thing {
        display: block;
        width: 100%;
    }

### 分割线

在任一新行输入 3 个或更多的短横线（减号）就是一条分隔线了。

---

### 高级用法

Markdown 还有一个特别用法，就是在你需要的时候可以直接书写 HTML 代码。

<input type="text" placeholder="这是个输入框！" />

只要掌握了上面的这些介绍，你就已经入门了！继续写作吧！

