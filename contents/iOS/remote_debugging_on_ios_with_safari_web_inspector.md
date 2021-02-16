# Remote debugging on iOS with Safari Web Inspector

![](https://img.halfrost.com/Blog/ArticleTitleImage/5_0_.png)


之前在公司调试Hybrid其实很蛋疼。。都是本地打开zip包，运行js，然后调试，每次都要找到zip，比较麻烦，后来发现了这个远程调试的方法，直接插上手机就可以调试了，不用那么麻烦了，而且可以直接在手机上看到实时的效果。

后来发现有一些Js前端开发还不会这个方法，今天就分享出来，大家都看看，有啥问题请多指点。

1.首先iPhone连接上Mac，点击信任，确保itunes连接成功，然后打开iPhone的“设置” - “Safari” - "高级" -  打开“JavaScript” 和 “Web检查器”


![](https://img.halfrost.com/Blog/ArticleImage/5_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/5_3.png)

2.打开Mac上的Safari，选择“偏好设置” - “高级” - "在菜单栏中显示“开发”菜单"


![](https://img.halfrost.com/Blog/ArticleImage/5_4.png)

3.打开iPhone上的Safari或者运行PhoneGap程序，到某一个界面，回到Mac上的Safari上，选择“开发”，然后选择你的iPhone，就可以查看到那个一个Web界面了

![](https://img.halfrost.com/Blog/ArticleImage/5_5.png)

