+++
author = "一缕殇流化隐半边冰霜"
categories = ["Ghost"]
date = 2018-06-30T08:55:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/93_0.png"
slug = "ghost_feature"
tags = ["Ghost"]
title = "A 'New' Way to Show Off Your Ghost Blog"

+++


Since Ghost has been upgraded to the latest version, a lot of new things are now possible. This post lists those “new” capabilities and also explains the new features on my blog.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_24.png'>
</p>

If you also want to modify your own theme, read the official documentation first:

[ghost themes](https://themes.ghost.org/docs)  
[ghost api](https://api.ghost.org/)


## Adding a Navigation Page to Ghost

Older versions of the blog did not have navigation, and some readers had asked about this before. Since the upgrade is done, this was the first requirement I implemented.

In the new version of the blog, navigation is placed in the footer. Some may ask why it is not placed in the header. I tried several positions, but none of them felt quite right, so I ultimately put it in the footer.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_1.png'>
</p>

The footer is mainly divided into three columns: TAGS, ABOUT, and NEWSLETTER.

Most blogs have tags, archives, blogrolls, about pages, and subscriptions. This time I added all of them in one go.

## Adding a Cover Image to Each Post

Influenced by the CSS of Zhihu Columns, and because Ghost itself supports the cover feature, I reworked the original theme during this upgrade and added cover images back in.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_2.png'>
</p>

Anyone who has used Zhihu Columns knows that when you open a post, the first thing you see is a full-screen cover image. I think this design is pretty good, so I “borrowed” it.

A few notes on the rest of the design: above the title is the tag corresponding to the post. Below the post is the estimated reading time, calculated based on the average human reading speed of 100 Chinese characters per minute. In the lower-right corner are the author’s name and avatar, as well as the publication time.


Three `iconfont` buttons have been added to the top row. The back button was added specifically for the PWA; otherwise, there would be no way to return to the home page. Search and the sidebar are also new features added this time, which I will describe in detail below.

## Adding a Table of Contents to Posts

This feature was also requested by readers. Some posts are quite long, and it is easy to get to the end and forget what came before. With a table of contents, readers can read by section, quickly scan the structure, and grasp the flow of the article. I added this feature as part of this upgrade as well.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_3.png'>
</p>


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_4.png'>
</p>

Implementing the table of contents is not difficult; you just need to traverse the Markdown headings once. You can find an off-the-shelf jQuery implementation on GitHub: `jquery.toc.js`. Include it, then add your own configuration during initialization:
```javascript
//Initialize the toc plugin
    $('#toc').initTOC({
        selector: "h1, h2, h3, h4, h5, h6",
        scope: "article",
        overwrite: false,
        prefix: "toc"
    });
```
`selector` represents the heading depth to search in Markdown articles; here it ranges from h1 to h6. `scope` indicates the search scope for the TOC. Since articles in Ghost are inside the `<article>` tag, the `scope` here is `article`.

Of course, the TOC should not be constrained across all screen sizes. I limited it to display only when the viewport width is above 1440px, so it definitely will not appear on mobile screens.

## Add Search Functionality to Articles

I added this requirement for myself because I saw it on other people’s blogs and wanted to implement it as well. The final result is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_5.png'>
</p>

To add search functionality in Ghost, you first need to enable the public API in the admin panel, because it uses some of Ghost’s experimental APIs.

Find the open-source project [ghostHunter](https://github.com/jamalneufeld/ghostHunter) on GitHub. This is a Ghost search engine written by an expert, and we will implement the search functionality using this repo. Include the `jquery.ghosthunter.js` file.
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
Add the script code above when Ghost starts, and the initialization triggered by GhostHunter search will be complete. The remaining work is just writing the CSS.

## Add a Sidebar

The original intention of adding a sidebar was to include some Easter eggs in each post and give readers a few surprises.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_6.png'>
</p>

Sidebars are generally implemented with the `<aside>` tag.

## Implement Post Archives for Ghost

This is a feature many blogs have, but Ghost does not include it by default. There is no way around it; we have to implement it ourselves.

In the old version of the blog, my blog did not have this feature, and I had always used GitHub as the blog’s table of contents 🤪. Now that this feature exists, though, perhaps not many people know about it. 🤓

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_7.png'>
</p>

In Ghost, users are allowed to apply special CSS to individual pages. The default template is page.hbs. If a user wants to add a new style for a standalone page, they need to create a new file, page-XXX.hbs. Then, when publishing the post, select it as a page and route the URL to XXX. After this configuration, the standalone page will be available.

Here we need the archives to be a standalone page, so we need to create page-archives.hbs, with the corresponding URL being [https://halfrost.com/archives/](https://halfrost.com/archives/). You can write your own styles in the page-archives.hbs file. In this file, we insert a script that fetches the post archive list:
```javascript
<script type = "text/javascript">
      /**
       * Call the ghost API to implement post archives
       * Required components: jQuery, moment.js
       * @ldsun.com
       */
      jQuery(document).ready(function() {
        //Get all post data, ordered by publication time
        $.get(ghost.url.api('posts', {
          limit: 'all',
          order: "published_at desc"
        })).done(function(data) {
          var posts = data.posts;
          var count = posts.length;
          for (var i = 0; i < count; i++) {
            //Use comentjs to manipulate timestamps
            //Since ghost defaults to the CST time zone, dates may differ; offset the time zone here
            var time = moment(posts[i].published_at).utcOffset("-08:00");
            var year = time.get('y');
            var month = time.get('M')+1;
            var date = time.get('D');
            if( date<10 ) date = "0"+date;
            var title = posts[i].title;
            var url = "{{@blog.url}}"+posts[i].url;
            //Handle the first post separately from the rest
            if (i > 0) {
              var pre_month = moment(posts[i - 1].published_at).utcOffset("-08:00").get('month')+1;
              //If the current post's publication month matches the previous post's, insert it under that month's ul
              if (month == pre_month) {
                var html = "<li><time>"+date+" day</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li>";
                $(html).appendTo(".archives .list-"+year+"-"+month);
              }
              //When the month differs, insert a new month
              else{
                var html = "<div class='item'><h3><i class='fa fa-calendar fa-fw' aria-hidden='true'></i> "+year+"-"+month+"</h3><ul class='archives-list list-"+year+"-"+month+"'><li><time>"+date+" day</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li></ul></div>";
                $(html).appendTo('.archives');
              }
            }else{
              var html = "<div class='item'><h3><i class='fa fa-calendar fa-fw' aria-hidden='true'></i> "+year+"-"+month+"</h3><ul class='archives-list list-"+year+"-"+month+"'><li><time>"+date+" day</time><a href='"+url+"' style='color: #4fc3f7'>"+title+"</a></li></ul></div>";
              $(html).appendTo('.archives');
            }
          }
        }).fail(function(err) {
          console.log(err);
        });
      });
      </script>
```
With the code above, the archive feature on Ghost is complete.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_22.png'>
</p>

Some of you may wonder what the cover image means. I’ll keep you in suspense for now; it will be explained below.

## Add Tags

This is a feature many blogs have, but Ghost does not include it by default. There was no choice but to implement it myself. 😭

I listed the top five most-read article series from recent posts, grouped them by tag, and placed them under POPULAR TAGS in the footer. It also serves as a kind of “navigation” for recommended reading.

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

The specific approach is to go to tag management in the Ghost admin panel, find the corresponding tag, and add a cover image to each tag. The page routing is simple: using a URL like `/tag/XXX/` will take you to the corresponding tag page.

## Blogroll

This feature used to be fairly rough. In the new version, I added a dedicated page to display it. The steps for adding this new standalone page are the same as adding the article archive, so I won’t repeat them here.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_14.png'>
</p>

Create page-links.hbs, write all the blogroll information into the standalone page, and adjust the CSS accordingly.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_23.png'>
</p>

Sharp-eyed readers may have noticed that the cover image for the blogroll is related to the cover image for the article archive.

When I found this pair of images, I immediately had their meaning in mind and used them right away, though I still don’t know which game they come from.

The cover image for the article archive shows one person moving forward, while the blogroll image shows three people moving forward. The meaning is obvious: the article archive represents the footprints of one person moving forward, while the blogroll is a place where friends share with one another.

## Collapsible Disqus Comments

This feature is actually a performance optimization. Some readers do not have a VPN/proxy and cannot access blocked sites, so they cannot comment. However, the Disqus script keeps loading until it times out. This creates a very poor experience for readers without a VPN/proxy. So I added this collapsible feature. See the images below.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_15.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_16.png'>
</p>

The Disqus comment box only starts loading when the reader clicks the COMMENTS button. This also speeds up rendering for the entire article page, because the Disqus comment framework no longer needs to be loaded first when loading JavaScript.

One thing to note here is that the official documentation includes the following statements:
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
We recommend setting the two properties `page.url` and `page.identifier` in the `disqus_config` variable. I previously left these unset and comments still displayed normally. However, this article, [“The Importance of Disqus Configuration Variables”](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments), mentions that not setting these two variables can cause performance issues.


## Email Subscriptions for a Ghost Blog

The last major feature was adding blog subscriptions. Ghost also provides native blog subscription support, but at the moment it can only collect users’ email addresses and cannot send blog update emails to them.

There are quite a few products that can be used for this feature, such as Mailgun and Mailchimp. I chose Mailchimp here.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_17.png'>
</p>

When readers click the subscribe button in the footer, they are redirected to this page. This page is generated on Mailchimp. After entering an email address, they will receive email notifications when this blog is updated.


How is this implemented exactly? You can refer to this article, [“Share Your Blog Posts with MailChimp”](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/). I’ll briefly describe my workflow here.

First, register an account on Mailchimp and create Lists, which are the email groups used for sending to users. After creating Lists, create Campaigns. Campaigns are bound to Lists. When creating a new Campaign, remember to choose RSS Update.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_18.png'>
</p>

The image above shows the basic settings page for Campaigns. On this page, it’s best to check the To Field option, which is intended to help avoid spam filtering and prevent update emails from being identified as spam.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_19.png'>
</p>

This step is for designing the email template to be sent. My design is relatively simple. There are many options available here. For details, see this document, [“RSS Merge Tags”](https://mailchimp.com/help/rss-merge-tags/), which lists all available tags.
```javascript
Halfrost's Field | Frostland updated with a new article
------------------------
I published a new article on my blog; I hope you enjoy it:
《*|RSSITEM:TITLE|*》
View it on the web:

*|RSSITEM:URL|*

*|RSSITEM:DATE|* by *|RSSITEM:AUTHOR|*

------------------------
*|RSSFEED:DESCRIPTION|*

```
The actual displayed content is as follows:
```html
Halfrost's Field | Land of Frost has a new article
------------------------
I published a new article on my blog, hope you like it:
An Accessible Guide to FlatBuffers: FlexBuffers
View on the web:
http://halfrost.com/flatbuffers_flexbuffers/

Jun 16, 2018 01:24 pm by A Wisp of Sorrow, Half-Hidden in Frost
------------------------
Explore in every moment of the cudgel thinking
```
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_20.png'>
</p>

After clicking Next all the way through, don’t rush to click Start RSS on the final page. In the upper-right corner, you can choose to send a test email and check whether the final result is what you want.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_21.png'>
</p>

After you finish the configuration, you’ll see this star gesture, which means it succeeded.


## Finally

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_25.png'>
</p>

That’s all for the new features added in this blog upgrade. As for performance optimization, I’ll cover that in detail in the next article.

------------------------------------------------------

References:  

[The Importance of Configuring Configuration Variables in Disqus](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments)  
[How to Configure Disqus in Ghost](https://help.ghost.org/article/15-disqus)  
[Implementing Post Archives in Ghost](https://xiao.lu/ghost-post-archives-page/)  
[Implementing Post Archives in Ghost](https://www.ldsun.com/2016/07/23/ghost-archives/)  
[Archive Implementation Code](https://github.com/flute/ghost-archives/blob/master/page-archives.hbs)
[Share Your Blog Posts with MailChimp](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/)  
[Tutorial: Using MailChimp to Configure Email Subscriptions for a Ghost Blog](http://402v.com/ghostbo-ke-shi-yong-mailchimppei-zhi-you-jian-ding-yue/)    
[RSS Merge Tags](https://mailchimp.com/help/rss-merge-tags/)
[Preview and Test Your Email Campaign](https://mailchimp.com/help/preview-and-test-your-email-campaign/)  

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_feature/](https://halfrost.com/ghost_feature/)