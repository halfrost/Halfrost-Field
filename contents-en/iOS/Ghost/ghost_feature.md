# Ghost Blog: Flashy “New” Tricks

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleTitleImage/93_0.png'>
</p>

Since Ghost has been upgraded to the latest version, it now supports many new things you can do with it. This post lists those “new” tricks and also explains the new features on my blog.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_24.png'>
</p>

If you also want to modify your own theme, please read the official documentation first:

[ghost themes](https://themes.ghost.org/docs)  
[ghost api](https://api.ghost.org/)


## Adding Navigation Pages to Ghost

The older version of the blog did not have navigation, and some readers had asked about it before. Since I was upgrading this time, I decided to address that requirement first.

In the new version, the blog’s navigation is placed in the footer. Some people may ask why it is not in the header. I tried several different positions and none of them felt quite right, so I ended up putting it in the footer.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_1.png'>
</p>

The footer is mainly divided into three columns: TAGS, ABOUT, and NEWSLETTER.

Most blogs have tags, archives, blogroll links, an about page, and subscriptions. This time, I added all of them in one go.

## Adding a Cover to Each Post

Influenced by the CSS design of Zhihu Columns, and because Ghost itself supports the cover feature, I reworked the original theme during this upgrade and added cover images back in.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_2.png'>
</p>

Anyone who has used Zhihu Columns knows that when you open a post, the first thing you see is a full-screen cover image. I think this design is pretty nice, so I “borrowed” it.

A few other design details are worth mentioning as well. Above the post title is the tag associated with the post. Below the post is the estimated reading time, calculated based on the average human reading speed of 100 Chinese characters per minute. In the lower-right corner are the author’s name and avatar, along with the publication time.

Three iconfont buttons have been added to the top row. The back button was added specifically for PWA support; otherwise, there would be no way to return to the homepage. Search and the sidebar are also new features added in this upgrade, and I’ll explain them in more detail below.

## Adding a Table of Contents to Posts

This feature was also requested by readers. Some posts are relatively long, and it is easy to forget the earlier parts by the time you get to the end. With a table of contents, readers can go through a post section by section, or quickly scan the outline to understand the structure of the article. I added this feature as part of this upgrade as well.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_3.png'>
</p>


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_4.png'>
</p>

The table of contents feature is not difficult to implement: you just need to traverse the headings in the markdown once. You can find ready-made jquery versions on github, such as `jquery.toc.js`. Include it, then add your own configuration during initialization:
```javascript
//Initialize the toc plugin
    $('#toc').initTOC({
        selector: "h1, h2, h3, h4, h5, h6",
        scope: "article",
        overwrite: false,
        prefix: "toc"
    });
```
`selector` indicates the heading depth to search in the Markdown article, here from h1 to h6. `scope` indicates the search scope for the TOC. Since articles in Ghost are inside the `<article>` tag, the scope here is `article`.

Of course, the TOC should not be constrained across all screen sizes. I only show it when the width is above a 1440 resolution, so it definitely will not be displayed on mobile screens.

## Add Search Functionality to Articles

I added this requirement for myself because I saw it on other people’s blogs and wanted to implement it too. The final result is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_5.png'>
</p>

To add search functionality in Ghost, you first need to enable the public API in the admin panel, because it uses some of Ghost’s experimental APIs.

Find the open-source project [ghostHunter](https://github.com/jamalneufeld/ghostHunter) on GitHub. This is a Ghost search engine written by an expert, and we will use this repo to implement the search feature. Include the `jquery.ghosthunter.js` file.
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
Add the script code above when Ghost starts, and the initialization triggered by ghosthunter search is complete. The remaining work is writing CSS.

## Adding a Sidebar

The original intent behind adding a sidebar was to add some Easter eggs to each post and give readers a few surprises.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_6.png'>
</p>

A sidebar is usually implemented with the `<aside>` tag.

## Implementing Post Archives for Ghost

This is a common feature in many blogs, but Ghost does not include it by default. There is no way around it—you have to implement it yourself.

In the old version of the blog, my blog did not have this feature and I had been using GitHub as the blog’s table of contents 🤪. Now that this feature exists, though, perhaps not many people know about it. 🤓

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_7.png'>
</p>

In Ghost, users can apply custom CSS to individual pages. The default template is page.hbs. If you want to add a new template for a standalone page, you need to create a file named page-XXX.hbs yourself. Then, when publishing a post, choose a page, and route the URL to XXX. After this setup, you will have a standalone page.

Here we need the archives to be a separate page, so we need to create page-archives.hbs, with the corresponding URL being [https://halfrost.com/archives/](https://halfrost.com/archives/). You can write your own styles in the page-archives.hbs file. In this file, we insert a script that fetches the archived post list:
```javascript
<script type = "text/javascript">
      /**
       * Call the Ghost API to implement the post archive feature
       * Required components: jQuery, moment.js
       * @ldsun.com
       */
      jQuery(document).ready(function() {
        //Get all post data, sorted by publication time
        $.get(ghost.url.api('posts', {
          limit: 'all',
          order: "published_at desc"
        })).done(function(data) {
          var posts = data.posts;
          var count = posts.length;
          for (var i = 0; i < count; i++) {
            //Use comentjs to process timestamps
            //Since Ghost defaults to the CST time zone, dates may differ; adjust for the time-zone offset here
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
              //If the current post was published in the same month as the previous post, insert it under that month's ul
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
Using the code above, you can implement the archive feature on Ghost.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_22.png'>
</p>

Some people may wonder: what is the meaning behind this cover image? I’ll keep you in suspense for now; it will be explained later.

## Adding Tags

This is a feature many blogs have, but Ghost does not provide it by default. So there was no choice but to implement it myself. 😭

I listed the top five most-read article series recently, grouped them by tag, and placed them under POPULAR TAGS in the footer. This also serves as a kind of “navigation” for recommending content to readers.

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

The implementation is to go to tag management in the Ghost admin panel, find the corresponding tag, and add a cover image to each tag. The page routing is very simple: just use the `/tag/XXX/` format to navigate to the corresponding tag page.

## Friend Links

This feature used to be rather rough. In the new version, I added a dedicated page to display it. The steps for adding a new standalone page are the same as those for adding the article archive, so I won’t repeat them here.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_14.png'>
</p>

Create page-links.hbs, then write all the friend-link information into the standalone page content and adjust the CSS accordingly.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_23.png'>
</p>

Readers with sharp eyes should have noticed that the cover image for the friend links is somewhat related to the cover image for the article archive.

When I found this pair of images, I immediately had their meaning in mind and used them right away—though I still don’t know which game they are from.

The cover image for the article archive shows one person moving forward, while the friend links image shows three people moving forward. The meaning is obvious: the article archive represents the footprints of one person’s journey, while friend links are a place where friends share with one another.

## Collapsible Disqus Comments

This feature is actually a performance optimization. Some readers do not have a proxy/VPN and cannot access blocked sites, so they cannot comment. However, the Disqus script will keep loading until it times out. This creates a very poor experience for readers without a proxy/VPN. So I added this collapsible behavior. See the images below.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_15.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_16.png'>
</p>

Only when a reader clicks the COMMENTS button will the Disqus comment box start loading. This also speeds up rendering of the entire article page, because the Disqus comment framework no longer needs to be loaded first when loading JS.

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
We recommend setting the two properties `page.url` and `page.identifier` in the `disqus_config` variable. I hadn’t set them before, and comments still displayed correctly. However, this article, [“The Importance of Disqus Configuration Variables”](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments), mentions that failing to set these two variables can cause performance issues.


## Ghost Blog Email Subscriptions

The last major feature is adding blog subscription support. Ghost also provides native blog subscriptions, but currently it can only collect users’ email addresses and cannot send blog update emails to them.

There are quite a few products that can be used for this feature, such as mailgun and mailchimp. I chose mailchimp here.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_17.png'>
</p>

When readers click the subscribe button in the footer, they are redirected to this page. This page is generated on mailchimp. After entering an email address, readers can receive email notifications whenever this blog is updated.


How exactly is this implemented? You can refer to this article, [“Share Your Blog Posts with MailChimp”](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/). I’ll describe my workflow here.

First, register an account on mailchimp and create Lists, which are the email groups to send to users. After creating Lists, create Campaigns. Campaigns are bound to Lists. When creating Campaigns, remember to select RSS Update.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_18.png'>
</p>

The image above shows the basic settings page for Campaigns. On this page, it’s best to check the To Field option; this is to help prevent spam filtering and avoid update emails being identified as spam.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_19.png'>
</p>

This step is for designing the email template. My design is fairly simple. There are many options here. For details, see this document, [“RSS Merge Tags”](https://mailchimp.com/help/rss-merge-tags/), which lists all available tags.
```javascript
Halfrost's Field | Frostland has a new article
------------------------
I've published a new article on my blog; I hope you enjoy it:
《*|RSSITEM:TITLE|*》
View it on the web:

*|RSSITEM:URL|*

*|RSSITEM:DATE|* by *|RSSITEM:AUTHOR|*

------------------------
*|RSSFEED:DESCRIPTION|*

```
The content actually displayed is as follows:
```html
Halfrost's Field | Frostland has a new article
------------------------
I published a new article on my blog. Hope you like it:
《A Simple Guide to FlatBuffers: FlexBuffers》
View it on the web:
http://halfrost.com/flatbuffers_flexbuffers/

Jun 16, 2018 01:24 pm by A Wisp of Sorrow, Half-Hidden in Frost
------------------------
Explore in every moment of the cudgel thinking
```
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_20.png'>
</p>

After clicking Next all the way through, don’t rush to click Start RSS on the final page. You can choose to send a test email in the upper-right corner to see whether the final result is what you want.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_21.png'>
</p>

Once the configuration is complete, you’ll see this star hand gesture, which means it succeeded.


## Finally

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/93_25.png'>
</p>

That’s it for the new features added after this blog upgrade. As for performance optimization, I’ll cover that in detail in the next article.

------------------------------------------------------

References:  

[The importance of configuring Disqus Configuration Variables](https://help.disqus.com/troubleshooting/use-configuration-variables-to-avoid-split-threads-and-missing-comments)    
[How to configure Disqus for Ghost](https://help.ghost.org/article/15-disqus)    
[Implementing post archives in Ghost](https://xiao.lu/ghost-post-archives-page/)  
[Implementing post archives in Ghost](https://www.ldsun.com/2016/07/23/ghost-archives/)  
[Specific archive code](https://github.com/flute/ghost-archives/blob/master/page-archives.hbs)  
[Share Your Blog Posts with MailChimp](https://mailchimp.com/help/share-your-blog-posts-with-mailchimp/)    
[Tutorial: using MailChimp to configure email subscriptions for a Ghost blog](http://402v.com/ghostbo-ke-shi-yong-mailchimppei-zhi-you-jian-ding-yue/)      
[RSS Merge Tags](https://mailchimp.com/help/rss-merge-tags/)  
[Preview and Test Your Email Campaign](https://mailchimp.com/help/preview-and-test-your-email-campaign/)    

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_feature/](https://halfrost.com/ghost_feature/)