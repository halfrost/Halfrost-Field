# How to Quickly Build Yourself a Cozy "Home" — Setting Up a Static Blog with Jekyll

<p align="center"> 
<img src="https://img.halfrost.com/Blog/ArticleTitleImage/12_0_.jpg">
</p> 


## Preface
I believe every programmer has the same wish: to have a "home" of their own — their own blog, their own dedicated website. In your own “home,” you can share and discuss any technology with like-minded peers, or simply chat about anything. More importantly, it can serve as a record of your technical growth and help you improve your skills. Next, I’ll walk through the process of setting up my blog.

## Table of Contents:
1. Set up Jekyll locally
2. Develop or choose a Jekyll theme
3. Use the GitHub Pages service
4. Apply for a personal domain name
5. Add visitor comments to the blog
6. Apply for the "little green lock" — HTTPS
7. Ongoing maintenance

## 1. Set up Kekyll locally
What is Jekyll? It is a simple static blog generation tool, as opposed to a dynamic blog.  
1. Simple. Because it does not require a database. You write static files in Markdown and generate HTML pages. Its advantages are improved page response speed and allowing bloggers to focus only on writing articles, without having to think about layout and formatting.  
2. Static. Markdown (or Textile), Liquid, and HTML & CSS are used to build publishable static websites.  
3. Blog support. It supports custom URLs, blog categories, pages, posts, and custom layout design.
```
//Install Jekyll with gem
gem install jekyll


//Create your blog site with Jekyll
jekyll new blog  #Create your site


//Start the Jekyll service
//Enter the blog directory, be sure to enter the created directory, otherwise the service cannot start
cd blog    	 
jekyll serve 	 #Start your HTTP service 
```
After the local service starts, the default port for the Jekyll service is 4000, so I can open a browser and enter: http://localhost:4000 to access it.

At this point, a simple blog page will be displayed.

The usage of some other Jekyll commands is as follows:
```
$ jekyll build

# => The contents of the current folder will be generated into the ./_site folder.

$ jekyll build --destination <destination>

# => The contents of the current folder will be generated into the target folder <destination>.

$ jekyll build --source <source> --destination <destination>

# => The contents of the specified source folder <source> will be generated into the target folder <destination>.

$ jekyll build --watch

# => The contents of the current folder will be generated into the ./_site folder,

#    watch for changes, and automatically regenerate.

$ jekyll serve

# => A development server will run at http://localhost:4000/

# Auto-regeneration (automatically regenerate files): enabled. Use `--no-watch` to disable.

$ jekyll serve --detach

# => Same as the `jekyll serve` command, but detaches from the terminal and runs in the background.

#    To stop the server, use the `kill -9 1234` command, where "1234" is the process ID (PID).

#    If you can't find the process ID, use `ps aux | grep jekyll` to check, then stop the server. [More](http://unixhelp.ed.ac.uk/shell/jobz5.html).

```
At its core, Jekyll is essentially a text transformation engine. The concept is straightforward: you write posts in your favorite markup language—Markdown, Textile, or just plain HTML—and Jekyll helps you apply one or more layouts to them. Throughout the process, you can configure URL paths, how your text is displayed within layouts, and more. All of this can be done by editing plain text, and the static pages generated at the end are the final product.  

Next, let’s talk about Jekyll’s directory structure:    
```
├── _config.yml  			(configuration file)
├── _drafts  				(drafts are unpublished posts)
|   ├── begin-with-the-crazy-ideas.textile
|   └── on-simplicity-in-technology.markdown
├── _includes 			(load these includes into your layouts)
|   ├── footer.html
|   └── header.html
├── _layouts 			    (templates that wrap posts)
|   ├── default.html
|   └── post.html
├── _posts 				  (posts are stored here)
|   ├── 2007-10-29-why-every-programmer-should-play-nethack.textile
|   └── 2009-04-26-barcamp-boston-4-roundup.textile
├── _site 				(generated pages are created in this directory)
├── .jekyll-metadata	  (This file helps Jekyll track which files have not been modified since the last site build and which files need to be regenerated during the next site build. This file will not be included in the generated site.)
└── index.html 		   (site index)
```

## II. Develop or Choose a Jekyll Theme

Next, let’s talk about the appearance of the blog. This may be something many people care a lot about—reading articles on a polished, high-quality blog is enjoyable in itself. This is where a custom theme comes in. You can either develop one yourself or choose an existing theme and then modify the CSS layout to make it your own. [Jekyll themes](http://jekyllthemes.org/) are available here, where you can choose a theme you like. Download it, tweak the CSS, or borrow parts of it, and you’ll have a beautiful blog ready to go.

## III. Use the GitHub Pages Service

### 1. Create Our Own Repository

The following uses usename as a placeholder for your own username
![](http://upload-images.jianshu.io/upload_images/1194012-1609f73ca0242750.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 2. Configure Our Repository


![](http://upload-images.jianshu.io/upload_images/1194012-35e073b16f96a9aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Find GitHub Pages in Settings


![](http://upload-images.jianshu.io/upload_images/1194012-a97613e15a848289.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Select **Launch automatic page generator**

On the next screen, simply select **Continue to layouts**


![](http://upload-images.jianshu.io/upload_images/1194012-a935d6e86644bf94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Once you reach this screen, choose any template and click **Publish Page**


![](http://upload-images.jianshu.io/upload_images/1194012-8984c24b9588e13b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
At this point, a static web page has been generated. Visit the [URL https://halfrost.com/username.github.io/](https://halfrost.com/username.github.io/) you just configured, and you’ll be able to access it.


Next, all we need to do is deploy the blog generated by Jekyll to GitHub Pages.

### 3. Deploy the Blog

First, git clone the newly created repository to your local machine, then cd into the repository directory and run jekyll serve -B  
```
cd username.github.com
jekyll serve -B
```
Before starting, make sure there are no Jekyll services running in other directories. You can use ps aux|grep jekyll
to check the processes. If there are any, use kill -9 process_id to terminate the other processes.  

Now open [http://localhost:4000](localhost:4000), and you should see the homepage we created on GitHub. In theory, it should be exactly the same as what you see when visiting https://username.com/username.github.io/.

Next, copy the entire blog directory you created into this repository folder. Of course, you can delete the previous files in this repository and keep only README. Then push all the files to GitHub.
```
git add --all                          #Add to staging area 
git commit -m "Commit the default Jekyll page"       #Commit to local repository
git push origin master                 #The live site is deployed under master
```
Before submitting, make sure the configuration below is set this way in the _config.yml file, because this is a GitHub Pages requirement. If you choose any other mode, you will immediately receive an email notification with a build warning.  
```
highlighter: rouge
markdown: kramdown

```
After waiting about 1–2 minutes, refresh username.github.io again, and you should be able to see our blog.


## IV. Apply for a Custom Domain

Many services now support custom domains. For example, on Sina Weibo, you can apply for a custom domain yourself, so in the future, visiting weibo.com/your-name will take you directly to your profile page. Similarly, we also want a name that takes users directly to our blog homepage, so we need to buy a domain first. In China, the most commonly used provider is probably **Wanwang**; internationally, it is **Go Daddy**. Choose a username you like. If no one has already purchased that domain, congratulations—you can go ahead and buy it.

After purchasing the domain, the next step is configuration.
1. To bind it, we need to add a CNAME file under the username.github.com directory. Add your domain to it, assuming it is example.com, and then push the CNAME file to the remote repository:
```
git add CNAME
git push origin master
```
2. Add your CNAME records with your domain registrar. Add two records, with host records `@` and `www`; set the record type to CNAME. CNAME stands for canonical name record, and it can map multiple names to the same computer. For the record value, enter **username.github.io.**. Note that there is a trailing dot after `io`; do not forget it.
   
![](http://upload-images.jianshu.io/upload_images/1194012-888c87d7134d7ff8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
Note that when adding the `@` record, you may very likely be prompted that there is a conflict with the MX record. In my case, I simply deleted the MX `@` rule. If you want to know why, you can read this link: http://cn.v2ex.com/t/204489. The bottom line is: just delete the MX `@` record yourself.

If it is a domestic domain, DNS resolution will be very fast, usually completing within 10 minutes. Then we can access our blog directly through the custom domain name we purchased.  

## V. Add Visitor Comments to the Blog

Static blogs generally integrate visitor comments using [Disqus](https://disqus.com/). It is usually placed at the end of a blog post, though the exact layout depends on how you want to design it. Here I’ll just paste the code I used to integrate Disqus. Yours will probably be similar.  
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
    <noscript>To view<a href="http://disqus.com/?ref_noscript"> Disqus </a>comments, please enable JavaScript</noscript>
    
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

## VI. Apply for the "Green Padlock" HTTPS  

![](http://upload-images.jianshu.io/upload_images/1194012-fcbd290c62a45816.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
To use an HTTPS URL, there are currently two approaches: apply for an HTTPS certificate—for a free option, use the free SSL certificate provided by Let’s Encrypt—or use the service provided by Kloudsec. I won’t cover the SSL certificate application process here; instead, I’ll talk about the second approach: using Kloudsec’s service.

How it works
According to Kloudsec’s documentation, [HOW DOES IT WORK?](https://docs.kloudsec.com/#section-how-does-it-work-), its service sits between our website server and our visitors. The idea is that it caches pages from our server, so the HTTPS connection actually established by the user is between the user’s browser and Kloudsec.

First, register for a Kloudsec account by entering your email address and password. Next, it will ask you to enter the repository URL and domain name, and it will check whether the repository exists. Finally, activate the Kloudsec account and log in.

Then comes the most important step: configuring the domain DNS records.

![](http://upload-images.jianshu.io/upload_images/1194012-63d0ee7385034236.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As shown above, you need to configure three A records. After completing the setup, click **Verify DNS records**. If verification passes, you can proceed with the next settings.


![](http://upload-images.jianshu.io/upload_images/1194012-e6615fa4f840932f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here you’ll find both free and paid services. Choose whatever fits your needs.

![](http://upload-images.jianshu.io/upload_images/1194012-962aa0ffcb15e729.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Make sure to enable SSL Encryption here. After enabling it, you’ll see the following settings.
![](http://upload-images.jianshu.io/upload_images/1194012-ee6c9cc414be8e87.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If you don’t upload your own SSL certificate here, it will generate a free SSL certificate for you. If you want to use your own, click the ADD CUSTOM CERT button to upload the SSL certificate.


![](http://upload-images.jianshu.io/upload_images/1194012-436818e0d0989824.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
These are some plugins. Enable them based on your needs.


![](http://upload-images.jianshu.io/upload_images/1194012-1ac0bce6a395d638.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Finally, add this IP address under SETTING. This IP is an available IP address for GitHub Pages.

Benefits of using Kloudsec  

1. Eliminates the unfriendly warning about an untrusted certificate posing a security risk.
2. Easy to configure; set it up once and you’re done.
3. Access speed is not affected.
4. The green padlock is reassuring to see.

Later, I discovered a third way to access the blog over HTTPS:
Use the Pages service provided by GitLab. It directly supports adding SSL certificates for custom domains and can be used together with a free SSL certificate. For details, see [A Simple Way to Build a Secure Blog at Zero Cost](https://www.figotan.org/2016/04/26/using-free-wosign-to-certificate-your-blog-on-gitlab/).


## VII. Future Maintenance

At this point, the personal blog has been successfully bound to the domain and launched. There really isn’t much maintenance work going forward.

### 1. Edit posts locally:
Use a Markdown tool to draft the post first. Note that the front matter of each post must include the following format.
```
---
layout: post
title: How to quickly build yourself a cozy "home"——Generate a static blog with Jekyll
author: A wisp of sorrow flowing into half-hidden frost
date: 2016.06.21 01:57:32 +0800
categories: Blog
tag: Blog
---
```
After finishing the article, run `jekyll build` to generate the pages, then use `jekyll serve -B` and view the article locally at `localhost:4000`.

### 2. Publish the Blog Online
Once you have confirmed locally that the article is correct, you can push it to the GitHub Pages server using Git commands such as `git add`, `git commit`, and `git push`. After a minute or two, visit your own domain and you should be able to see the new blog post!


## Conclusion
That’s it for setting up a static blog. If anything is still unclear, feel free to leave me a comment. Another excellent static blog generator is hexo; if you’re interested and feel like tinkering, you can give it a try as well. Tang Qiao uses it to build his blog. Of course, there are also dynamic blogs built with ghost. To set up a dynamic blog, you need to buy your own server, install the node.js environment, and handle all future maintenance yourself. If you’re interested, feel free to try that too!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jekyll/](https://halfrost.com/jekyll/)