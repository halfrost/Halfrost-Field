# Remote debugging on iOS with Safari Web Inspector

![](https://img.halfrost.com/Blog/ArticleTitleImage/5_0_.png)


Debugging Hybrid apps at work used to be a real pain. We had to open the zip package locally, run the JavaScript, and then debug it. Every time, we had to find the zip file, which was pretty cumbersome. Later, I discovered this remote debugging method: just plug in the phone and you can debug directly—much simpler, and you can see the live results on the phone.

I later found that some JavaScript frontend developers still don’t know about this method, so I’m sharing it today. Take a look, and please feel free to point out any issues.

1. First, connect the iPhone to the Mac, tap Trust, make sure iTunes connects successfully, then open “Settings” - “Safari” - “Advanced” on the iPhone, and enable “JavaScript” and “Web Inspector”


![](https://img.halfrost.com/Blog/ArticleImage/5_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/5_3.png)

2. Open Safari on the Mac, choose “Preferences” - “Advanced” - “Show Develop menu in menu bar”


![](https://img.halfrost.com/Blog/ArticleImage/5_4.png)

3. Open Safari on the iPhone, or run the PhoneGap app, navigate to a screen, then go back to Safari on the Mac, choose “Develop”, and then select your iPhone. You’ll be able to see that web page there.

![](https://img.halfrost.com/Blog/ArticleImage/5_5.png)