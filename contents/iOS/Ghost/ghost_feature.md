# Ghost 博客炫技"新"玩法

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleTitleImage/93_0.png'>
</p>

由于 Ghost 升级到了最新版本，新增加了很多玩法。这里罗列一下“新”玩法，也是对笔者博客新功能的说明。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_24.png'>
</p>

如果读者也想修改自己的主题，那么请先阅读官方的文档：

[ghost themes](https://themes.ghost.org/docs)  
[ghost api](https://api.ghost.org/)


## Ghost 添加导航页面

之前老版本的博客没有导航功能，也有读者问过这个事情，这次既然升级了，首先完成这个需求。

新版本的博客导航功能放到了 footer 上了。可能有人问为何不放在 header 上。我尝试了好几种位置，都觉得不太合适，还是放在 footer 上了。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_1.png'>
</p>

footer 上主要分了 3 列，TAGS、ABOUT、NEWSLETTER。

一般博客都会有标签，归档，友链，关于，订阅。这次一口气都加全了。

## 给每篇文章添加封面

由于受到了知乎专栏的 CSS 影响，加上 Ghost 本身也支持 cover 功能，所以笔者在这次升级的时候，把原来的主题重新修改了，把 cover 封面重新添加回来了。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_2.png'>
</p>

用过知乎专栏的朋友会知道，每篇文章一进去，就是一个占满全屏的封面题图，这种设计笔者觉得挺好的，所以也“抄”过来了。

其他的设计也说一下，题目标题上面是文章对应的 tag。文章下面有预估阅读时间，这个是根据人类平均阅读时间每分钟 100 个字算出来的。右下角是文章作者的名字和头像，以及文章发布时间。


最上一排增加了 3 个 iconfont 的按钮，返回按钮是为了 PWA 特意增加的，不然不能返回到主页了。搜索和侧边栏也都是这次增加的新功能，下面会细说。

## 文章添加目录

这个功能也是读者提过的需求。因为有些文章比较长，常常容易看到后面忘记了前面，如果有一个目录，可以分章节阅读文章，也可以迅速浏览目录，抓住文章脉络。这次升级笔者也加上了这个功能。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_3.png'>
</p>


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_4.png'>
</p>

文章目录这个功能的不难，只要遍历一遍 markdown 的标题就可以了。github 上可以找到现成的 jquery 版本的代码 `jquery.toc.js`。引用它，然后初始化的时候加上自己的配置：

```javascript
//初始化 toc 插件
    $('#toc').initTOC({
        selector: "h1, h2, h3, h4, h5, h6",
        scope: "article",
        overwrite: false,
        prefix: "toc"
    });
```

selector 代表会搜索 markdown 文章标题的层级深度，这里是从 h1 - h6 。scope 表示的是 toc 搜索范围，由于在 ghost 中文章是在 `<article>` 标签里面的，所以这里 scope 为 article。

当然 toc 也不能所有屏幕尺寸大小都会限制，笔者限制在 1440 分辨率以上宽度才会显示出来，手机屏幕肯定是不会显示的。

## 给文章添加搜索功能

这个需求是自己给自己加的，因为看见别人博客有，自己也想做一下。最终成品如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_5.png'>
</p>

在 Ghost 里面想加入搜索功能，需要现在后台开启 public API ，因为它会用到 Ghost 一下实验的接口。


在 github 上找一个开源项目 [ghostHunter](https://github.com/jamalneufeld/ghostHunter)，这个是一个大神写的 Ghost 的搜索引擎，我们搜索功能就用这个 repo 来实现。引用 `jquery.ghosthunter.js` 文件。

```javascript
    // Site search
    var searchField = $('#search-field').ghostHunter({
      results : "#search-results",
      onKeyUp : true,
      onPageLoad : true,
      includepages : true,
      info_template : '<div class="results-info">Posts found: {{amount}}</div>',
      result_template : '<div class="result-item"><a href="{{link}}"><div class="result-title">{{title}}</div><div class="result-date">{{pubDate}}</div></a></div>'
    });
```

在 ghost 启动的时候加入上述脚本代码，即可完成 ghosthunter 搜索引起的初始化，其他的工作就是写 CSS 了。

## 添加侧边栏

加入侧边栏本意是想在每篇文章增加一些彩蛋环节，给读者一些惊喜。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_6.png'>
</p>

侧边栏一般都是用 `<aside>` 标签完成的。

## 给 Ghost 实现文章归档

这个功能是很多博客都有的功能，但是 Ghost 默认是不带这个功能的。没办法，只能自己来实现了。

在老版本的博客中，笔者博客是没有这个功能，一直用 github 作为博客的目录🤪，不过现在有了这个功能，说不定知道的人也不多。🤓

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_7.png'>
</p>

在 Ghost 中，允许用户针对单页做特殊的 CSS。默认样式是 page.hbs。如果用户想新增单页的样式，就需要自己新建一个文件，page-XXX.hbs，然后在发布文章的时候，选择单页，并且网址要路由到 XXX ，这样设置以后，就有单页了。

这里我们需要归档为一个单独页面，那么就需要新建 page-archives.hbs，对应的 URL 为[https://halfrost.com/archives/](https://halfrost.com/archives/)。在 page-archives.hbs 文件中可以写上自己的样式。在这个文件中，我们插入一段拉取文章归档列表的脚本：

```javascript
<script type = "text/javascript">
      /**
       * 调用ghost API，完成文章归档功能
       * 所需组件：jQuery、moment.js
       * @ldsun.com
       */
      jQuery(document).ready(function() {
        //获取所有文章数据，按照发表时间排列
        $.get(ghost.url.api('posts', {
          limit: 'all',
          order: "published_at desc"
        })).done(function(data) {
          var posts = data.posts;
          var count = posts.length;
          for (var i = 0; i < count; i++) {
            //调用comentjs对时间戳进行操作
            //由于ghost默认是CST时区，所以日期会有出入，这里消除时区差
            var time = moment(posts[i].published_at).utcOffset("-08:00");
            var year = time.get('y');
            var month = time.get('M')+1;
            var date = time.get('D');
            if( date<10 ) date = "0"+date;
            var title = posts[i].title;
            var url = "{{@blog.url}}"+posts[i].url;
            //首篇文章与其余文章分步操作
            if (i > 0) {
              var pre_month = moment(posts[i - 1].published_at).utcOffset("-08:00").get('month')+1;
              //如果当前文章的发表月份与前篇文章发表月份相同，则在该月份ul下插入该文章
              if (month == pre_month) {
                var html = "<li><time>"+date+"日</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li>";
                $(html).appendTo(".archives .list-"+year+"-"+month);
              }
              //当月份不同时，插入新的月份
              else{
                var html = "<div class='item'><h3><i class='fa fa-calendar fa-fw' aria-hidden='true'></i> "+year+"-"+month+"</h3><ul class='archives-list list-"+year+"-"+month+"'><li><time>"+date+"日</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li></ul></div>";
                $(html).appendTo('.archives');
              }
            }else{
              var html = "<div class='item'><h3><i class='fa fa-calendar fa-fw' aria-hidden='true'></i> "+year+"-"+month+"</h3><ul class='archives-list list-"+year+"-"+month+"'><li><time>"+date+"日</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li></ul></div>";
              $(html).appendTo('.archives');
            }
          }
        }).fail(function(err) {
          console.log(err);
        });
      });
      </script>
```

利用上述代码，就可以完成 Ghost 上的归档功能了。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_22.png'>
</p>

可能有人会问，这个题图是什么寓意呢？先卖个关子，下文会说明。

## 添加标签

这个功能是很多博客都有的功能，但是 Ghost 默认是不带这个功能的。没办法，也只能自己来实现了。😭

笔者把近期阅读量最高的系列文章，排名前五的都罗列了出来，分 tag 放在了 footer 的 POPULAR TAGS 里，也算是给读者阅读推荐的一个“导航”。



<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_8.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_9.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_10.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_11.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_12.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_13.png'>
</p>

具体做法是在 Ghost 后台 tag 管理中，找到对应的 tag，给每个 tag 都加上题图。网页路由很简单，只要按照 `/tag/XXX/` 这种方式就可以跳转到对应的 tag 页面中了。


## 友链

这个功能之前做的比较简陋，现在在新版里面单独加一个页面来展示。具体新加单页的步骤和添加文章归档是一样的，这里就不再赘述了。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_14.png'>
</p>

新建 page-links.hbs ，然后把这些友链信息都写到单页文章中，调整一下 CSS 即可。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_23.png'>
</p>

眼力尖的同学应该发现了，友链的题图和文章归档的题图有些联系。

笔者在发现这一对图片的时候，当时就想好了他们的寓意，立即拿过来了。虽然不知道出自哪个游戏。

文章归档的那个题图是一个人在前行，而友链的这张图是 3 个人在前行。寓意很明显，文章归档是一个人前行的足迹，友链是朋友们相互分享的地方。


## Disqus 评论伸缩

这个功能其实算性能优化。有些读者没有梯子，不能翻墙也就不能评论。但是由于 Disqus 脚本会一直加载，直到超时才会停止。这样对于没有梯子的读者体验非常不好。所以加入这个伸缩的功能。具体见下图。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_15.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_16.png'>
</p>

只有当读者点击了 COMMENTS 按钮的时候，才会开始去加载 Disqus 评论框。这样对整个文章页面的渲染也提速了。因为在加载 JS 的时候，不需要先加载 Disqus 评论框架了。

这里有一点需要注意的是，在官方文档中有这样几段说明：

```html

<div id="disqus_thread" style="margin-left:15px;margin-right:15px;"></div>
<script>

/**
*  RECOMMENDED CONFIGURATION VARIABLES: EDIT AND UNCOMMENT THE SECTION BELOW TO INSERT DYNAMIC VALUES FROM YOUR PLATFORM OR CMS.
*  LEARN WHY DEFINING THESE VARIABLES IS IMPORTANT: https://disqus.com/admin/universalcode/#configuration-variables*/
/*
var disqus_config = function () {
this.page.url = PAGE_URL;  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = PAGE_IDENTIFIER; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};
*/
(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = 'https://halfrost.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
```

建议我们设置 `disqus_config` 变量里面的两个属性 `page.url`  和 `page.identifier`。笔者之前没有设置这个也一样可以显示。不过这篇文章[《disqus 配置 Configuration Variables 的重要性》](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments)里面提到，如果不设置这两个变量，会导致性能问题。


## Ghost博客邮件订阅

最后一个大的功能就是加入了博客订阅的功能。Ghost 原生也自带了博客订阅，但是目前只能收集用户的邮箱，无法给用户发博客更新邮件。

关于这个功能可以用的产品挺多的，比如 mailgun 和 mailchimp。笔者这里选用了 mailchimp。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_17.png'>
</p>

当读者点击了 footer 上的 subscribe 按钮，就会跳转到这个页面了。这个页面是在 mailchimp 上生成的。填上邮箱就能在本博客更新的时候收到更新邮件提醒了。


具体是怎么做到的呢？可以参考这篇文章[《Share Your Blog Posts with MailChimp》](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/)，笔者在这里写一下我的操作流程。

先在 mailchimp 上注册好账号，建立好 Lists，这个就是要发送用户的邮件组。有了 Lists 以后就要新建 Campaigns。Campaigns 是会绑定 Lists 的。新建 Campaigns 记得要选择 RSS Update。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_18.png'>
</p>

上图是 Campaigns 的基本设置页面。在这个页面最好勾选 To Field 那一项，这一样是为了防止垃圾邮件扫描的。防止更新邮件被识别成垃圾邮件了。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_19.png'>
</p>

这一步就是设计发送邮件的模板了。笔者设计的比较简单。这里有很多可选项。具体可以看这个文档[《RSS Merge Tags》](https://mailchimp.com/help/rss-merge-tags/)，文档里面写了所有可用的 tags。

```javascript
Halfrost's Field | 冰霜之地 更新了新文章
------------------------
我在博客上发布了新文章，希望您能喜欢：
《*|RSSITEM:TITLE|*》
在网页中查看：

*|RSSITEM:URL|*

*|RSSITEM:DATE|* by *|RSSITEM:AUTHOR|*

------------------------
*|RSSFEED:DESCRIPTION|*

```

实际展示出现的内容如下：

```html
Halfrost's Field | 冰霜之地 更新了新文章
------------------------
我在博客上发布了新文章，希望您能喜欢：
《深入浅出 FlatBuffers 之 FlexBuffers》
在网页中查看：
http://halfrost.com/flatbuffers_flexbuffers/

Jun 16, 2018 01:24 pm by 一缕殇流化隐半边冰霜
------------------------
Explore in every moment of the cudgel thinking
```

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_20.png'>
</p>

一路 next 点下来以后，到最后一个页面别慌着点 start rss，在右上角可以选择测试 send 发送邮件，看看最终效果是否是你想要的。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_21.png'>
</p>

最后完成配置以后，就会看见这个星星的手势了，就代表成功了。


## 最后

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_25.png'>
</p>

以上就是本次博客升级以后新增的一些功能，至于性能优化放在下篇文章再细说吧。

------------------------------------------------------

Reference：  

[disqus 配置 Configuration Variables 的重要性](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments)    
[ghost 配置 disqus 方法](https://help.ghost.org/article/15-disqus)    
[给 Ghost 实现文章归档](https://xiao.lu/ghost-post-archives-page/)  
[Ghost 实现文章归档](https://www.ldsun.com/2016/07/23/ghost-archives/)  
[归档的具体代码](https://github.com/flute/ghost-archives/blob/master/page-archives.hbs)  
[Share Your Blog Posts with MailChimp](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/)    
[使用MailChimp配置Ghost博客邮件订阅教程](http://402v.com/ghostbo-ke-shi-yong-mailchimppei-zhi-you-jian-ding-yue/)      
[RSS Merge Tags](https://mailchimp.com/help/rss-merge-tags/)  
[Preview and Test Your Email Campaign](https://mailchimp.com/help/preview-and-test-your-email-campaign/)    

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_feature/](https://halfrost.com/ghost_feature/)