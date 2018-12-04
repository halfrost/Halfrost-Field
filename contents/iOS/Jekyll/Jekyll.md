# 如何快速给自己构建一个温馨的"家"——用Jekyll搭建静态博客

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleTitleImage/12_0_.jpg">
</p> 


## 前言
我相信，每个程序员都有一个愿望，都想有一个属于自己的"家"——属于自己的博客，专属的网站。在自己的“家”中，可以和志同道合的兄弟一起分享和讨论任何技术，谈天说地。更重要的是可以当做自己的技术积累，提升自己实力。那么接下来就来说说我博客搭建过程。

## 目录：
1. 本地搭建Jekyll
2. 开发或者选择Jekyll主题
3. 使用Github Pages服务
4. 申请个人域名
5. 给博客增加访客评论功能
6. 申请"小绿锁"HTTPS
7. 日后维护

## 一.本地搭建Kekyll
Jekyll是什么？它是一个简单静态博客生成工具，相对于动态博客。  
1. 简单。因为它是不需要数据库的，通过markdown编写静态文件，生成Html页面，它的优点是提升了页面的响应速度，并且让博主可以只专注于写文章，不用再去考虑如何排版。  
2. 静态。Markdown（或 Textile）、Liquid 和 HTML & CSS 构建可发布的静态网站。  
3. 博客支持。支持自定义地址、博客分类、页面、文章以及自定义的布局设计。  

```
//使用gem安装Jekyll
gem install jekyll


//使用Jekyll创建你的博客站点
jekyll new blog  #创建你的站点


//开启Jekyll服务
//进入blog目录,记得一定要进入创建的目录，否则服务无法开启
cd blog    	 
jekyll serve 	 #启动你的http服务 
```
本地服务开启后，Jekyll服务默认端口是4000，所以我打开浏览器，输入：http://localhost:4000 即可访问

到这里一个简单的博客页面就会显示出来了。

关于jekyll其他一些命令的用法如下:

```
$ jekyll build
# => 当前文件夹中的内容将会生成到 ./_site 文件夹中。

$ jekyll build --destination <destination>
# => 当前文件夹中的内容将会生成到目标文件夹<destination>中。

$ jekyll build --source <source> --destination <destination>
# => 指定源文件夹<source>中的内容将会生成到目标文件夹<destination>中。

$ jekyll build --watch
# => 当前文件夹中的内容将会生成到 ./_site 文件夹中，
#    查看改变，并且自动再生成。

$ jekyll serve
# => 一个开发服务器将会运行在 http://localhost:4000/
# Auto-regeneration（自动再生成文件）: 开启。使用 `--no-watch` 来关闭。

$ jekyll serve --detach
# => 功能和`jekyll serve`命令相同，但是会脱离终端在后台运行。
#    如果你想关闭服务器，可以使用`kill -9 1234`命令，"1234" 是进程号（PID）。
#    如果你找不到进程号，那么就用`ps aux | grep jekyll`命令来查看，然后关闭服务器。[更多](http://unixhelp.ed.ac.uk/shell/jobz5.html).

```  

Jekyll 的核心其实是一个文本转换引擎。它的概念其实就是：你用你最喜欢的标记语言来写文章，可以是 Markdown, 也可以是 Textile, 或者就是简单的 HTML, 然后 Jekyll 就会帮你套入一个或一系列的布局中。在整个过程中你可以设置 URL 路径，你的文本在布局中的显示样式等等。这些都可以通过纯文本编辑来实现，最终生成的静态页面就是你的成品了。  

接下来再说说jeykll的目录结构：    

```
├── _config.yml  			(配置文件)
├── _drafts  				(drafts（草稿）是未发布的文章)
|   ├── begin-with-the-crazy-ideas.textile
|   └── on-simplicity-in-technology.markdown
├── _includes 			(加载这些包含部分到你的布局)
|   ├── footer.html
|   └── header.html
├── _layouts 			    (包裹在文章外部的模板)
|   ├── default.html
|   └── post.html
├── _posts 				  (这里都是存放文章)
|   ├── 2007-10-29-why-every-programmer-should-play-nethack.textile
|   └── 2009-04-26-barcamp-boston-4-roundup.textile
├── _site 				(生成的页面都会生成在这个目录下)
├── .jekyll-metadata	  (该文件帮助 Jekyll 跟踪哪些文件从上次建立站点开始到现在没有被修改，哪些文件需要在下一次站点建立时重新生成。该文件不会被包含在生成的站点中。)
└── index.html 		   (网站的index)
```

## 二.开发或者选择Jekyll主题

再来说说博客的外观，这可能是很多人很看重的，一个高逼格的博客里面看文章也是一种享受。这里就需要自定义主题了。你可以选择自己开发一套，也可以直接选择已有的，然后自己再更改css布局形成自己的。[jekyll主题](http://jekyllthemes.org/)在这里，你可以选择到你自己喜欢的主题。下载下来，改改css，或者借用一下，就会有很漂亮的blog就出炉了。

## 三.使用Github Pages服务

### 1.创建我们自己的仓库

以下用usename代替自己的用户名
![](http://upload-images.jianshu.io/upload_images/1194012-1609f73ca0242750.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 2.配置我们的仓库


![](http://upload-images.jianshu.io/upload_images/1194012-35e073b16f96a9aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在Settings里面找到Github Pages


![](http://upload-images.jianshu.io/upload_images/1194012-a97613e15a848289.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

选择**Launch automatic page generator**

接下来的界面就直接选择**Continue to layouts**


![](http://upload-images.jianshu.io/upload_images/1194012-a935d6e86644bf94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

到了这个界面就随便选择一个模板，点击**Publish Page**即可


![](http://upload-images.jianshu.io/upload_images/1194012-8984c24b9588e13b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
这里就生成了一个静态网页了，直接访问刚刚的设置的[地址https://halfrost.com/username.github.io/](https://halfrost.com/username.github.io/)，这个地址，就可以访问到了。


接下来我们要做的就是把我们的Jekyll生成的blog部署到Github Pages上去即可

### 3.部署blog

我们先把刚刚新建的仓库git clone到本地，然后cd 到仓库的目录下，执行jekyll serve -B   

```
cd username.github.com
jekyll serve -B
```
注意，启动前确保其他目录下没有jekyll服务，可以ps aux|grep jekyll
查看进程,有的话,用kill -9 进程号 杀掉其他进程。  

现在我们打开[http://localhost:4000](localhost:4000),即可看见我们在Github上创建的主页，理论上和https://username.com/username.github.io/ 访问的应该是一模一样的。

接着我们把我们自己做好的blog目录整个都拷贝到这个仓库文件夹中，当然，这个仓库之前的文件可以删除了，只留下README即可。把整个文件都push到github上去
```
git add --all                          #添加到暂存区 
git commit -m "提交jekyll默认页面"       #提交到本地仓库
git push origin master                 #线上的站点是部署在master下面的
```

注意，在提交前，请确保_config.yml文件里面下面是这样配置的，因为这个是Github Pages的规定，如果选择了其他的模式，会立即收到编译警告的邮件提醒的。  

```
highlighter: rouge
markdown: kramdown

```
等待大概1-2分钟之后，再次刷新username.github.io，就能看到我们的blog了。  


## 四.申请个人域名

现在很多地方都支持个性化域名，比如新浪微博，就可以自己申请一个个性域名，那么以后只要访问weibo.com/你的名字，这个网址就可以直达你的主页。同理，我们也希望有一个名字直达我们的博客首页，那么我们就需要先买一个域名。一般国内用的比较多的应该就是**万网**，国外的就是**Go Daddy**。选择一个你喜欢的用户名，如果没有人先买下那个域名，那就可以恭喜你了，可以去买下来了。

买好域名以后，就是配置的问题了。
1. 我们要绑定的话需要在username.github.com目录下增加一个CNAME文件。 在里面添加你的域名，假设为example.com，然后推送CNAME文件到远程仓库:  
```
git add CNAME
git push origin master
```
2. 到域名服务商增加你的CNAME记录。 添加两条记录，@和www的主机记录，记录类型为CNAME类型，CNAME表示别名记录，该记录可以将多个名字映射到同一台计算机。 记录值请写**username.github.io.**,值得注意的是io
后面还有一个圆点，切记。
   
![](http://upload-images.jianshu.io/upload_images/1194012-888c87d7134d7ff8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
注意，当添加@的记录的时候，很可能会提示冲突了，和MX那条冲突了，这里我就直接删除了MX的@规则。想知道原因，其实可以看这个链接，http://cn.v2ex.com/t/204489 。结论还是自己删除MX的@吧。

如果是国内的域名，解析会很快，一般10分钟之内就能解析完成。我们就可以直接通过访问我们买的个性域名访问到我们的博客了。  

## 五.给博客增加访客评论功能

一般静态博客添加访客评论功能都是用[disqus](https://disqus.com/)来集成的。一般都是放在博客的一篇文章的最后，当然这个排版就看你自己怎么设计的了。我这里就贴一下我集成disqus的代码。大家估计都类似。  

```
<section class="post-comments">
  {% if site.comment.disqus %}
    <div id="disqus_thread"></div>
    <script>
    
    var disqus_config = function () {
        this.page.url = "{{ page.url | prepend: site.baseurl | prepend: site.url }}";
        this.page.identifier = "{{ page.url }}";
    };

    var disqus_shortname = '{{ site.comment.disqus }}';
    
    (function() { // DON'T EDIT BELOW THIS LINE
        var d = document, s = d.createElement('script');
        s.src = '//' + disqus_shortname + '.disqus.com/embed.js';
        s.setAttribute('data-timestamp', +new Date());
            (d.head || d.body).appendChild(s);
        })();
    </script>
    <noscript>要查看<a href="http://disqus.com/?ref_noscript"> Disqus </a>评论，请启用 JavaScript</noscript>
    
  {% elsif site.comment.duoshuo %}
    <div class="ds-thread" data-thread-key="{{ page.url }}" data-title="{{ page.title }}" data-url="{{ page.url | prepend: site.baseurl | prepend: site.url }}"></div>
    <script type="text/javascript">
        var duoshuoQuery = {short_name:"{{ site.comment.duoshuo }}"};
        (function() {
            var ds = document.createElement('script');
            ds.type = 'text/javascript';ds.async = true;
            ds.src = (document.location.protocol == 'https:' ? 'https:' : 'http:') + '//static.duoshuo.com/embed.js';
            ds.charset = 'UTF-8';
            (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(ds);
        })();
    </script>
  {% endif %}
  
  
  
</section>

```
## 六.申请"小绿锁"HTTPS  

![](http://upload-images.jianshu.io/upload_images/1194012-fcbd290c62a45816.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
要想使用HTTPS开头，目前就2种做法，一是申请HTTPS证书，免费的就用Let’s Encrypt 提供的免费 SSL 证书，二是使用kloudsec提供的服务。申请SSL证书的做法我就不说了，我来说说第二种使用kloudsec提供的服务的做法。

实现原理
看 Kloudsec 的文档里描述的 [HOW DOES IT WORK?](https://docs.kloudsec.com/#section-how-does-it-work-)，它提供的服务处于我们的网站服务器和我们的网站访问者之间，其原理是缓存了我们服务器上的页面，所以实际用户建立的 HTTPS 连接是用户的浏览器与 Kloudsec 之间的。

首先注册Kloudsec的账户，填写邮箱和密码，接下来会让你填写仓库的地址和域名，它会检测仓库是否存在。然后最后是激活 Kloudsec 账号并登录。

然后最关键的一步来了，就是要设置域名解析规则。

![](http://upload-images.jianshu.io/upload_images/1194012-63d0ee7385034236.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

按照上面给的，要设置3个A的解析规则。设置完成之后点击**Verify DNS records**，如果通过，那么就可以接下来的设置了。


![](http://upload-images.jianshu.io/upload_images/1194012-e6615fa4f840932f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里会有一些免费和付费的服务，大家看自己需要选取。

![](http://upload-images.jianshu.io/upload_images/1194012-962aa0ffcb15e729.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里的SSL Encryption要选上，打开会有如下的设置。
![](http://upload-images.jianshu.io/upload_images/1194012-ee6c9cc414be8e87.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里如果不上传自己的SSL，就会用它帮你生成免费的SSL证书。如果要用自己的，点击ADD CUSTOM CERT按钮上传SSL证书。


![](http://upload-images.jianshu.io/upload_images/1194012-436818e0d0989824.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
这里是一些插件。看自己需不需要。


![](http://upload-images.jianshu.io/upload_images/1194012-1ac0bce6a395d638.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后，SETTING里面加上这个IP地址。这个IP是GitHub Pages 的可用 IP地址。

使用 Kloudsec 的好处  

1. 摆脱了证书不可信存在安全风险的不友好提示。
2. 配置方便，一劳永逸。
3. 访问速度并未受影响
4. 小绿锁看着舒心

后来又发现了第三种方法能用HTTPS访问博客的方法：
使用 GitLab 提供的 Pages 服务，那它直接支持添加自定义域名的 SSL 证书，可以配合免费申请的 SSL 证书一起使用。详情可见 [零成本打造安全博客的简单办法](https://www.figotan.org/2016/04/26/using-free-wosign-to-certificate-your-blog-on-gitlab/)。


## 七.日后维护

至此，个人博客也绑定好域名成功上线了。以后的维护工作其实并没有多少。

### 1. 本地编辑文章：
用markdown工具，先写好博文，注意，每篇博文前面题头都要带下面这些格式。

```
---
layout: post
title: 如何快速给自己搭建一个温馨的"家"——用Jekyll生成静态博客
author: 一缕殇流化隐半边冰霜
date: 2016.06.21 01:57:32 +0800
categories: Blog
tag: Blog
---
```
文章写完之后，通过jekyll build生成页面，jekyll serve -B 通过本地localhost:4000查看文章。

### 2. 发布线上博客
本地确认文章无误，可以通过git add,git commit,git push
等git命令推送文章到Github Pages服务器就可以啦。过1，2分钟，访问自己的域名就可以看到新的博文啦！


## 结尾
关于静态博客的搭建就到这里了，如果大家还有什么不清楚了，请直接给我留言就好。静态博客还有一个hexo，也是很优秀的静态博客，如果大家有兴趣，想折腾的，也可以去试试它。唐巧就是用这个搭建博客的。当然也有动态博客，ghost搭建的，搭建动态博客就需要自己买一个服务器，然后去安装node.js环境，日后的维护也都需要自己一个人去完成。有兴趣的同学一样可以去试试！





> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jekyll/](https://halfrost.com/jekyll/)

