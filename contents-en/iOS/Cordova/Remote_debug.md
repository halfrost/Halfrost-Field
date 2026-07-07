<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-421c26dcd9c36f3b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


Debugging Hybrid apps at the company used to be a real pain... We had to open the zip package locally, run the JS, and then debug it. Every time we had to find the zip file, which was pretty troublesome. Later, I discovered this remote debugging method: just plug in the phone and you can debug directly, without all that hassle. You can also see the live results directly on the phone.

Later I found that some JS frontend developers still don’t know about this method, so I’m sharing it today. Please take a look, and feel free to point out any issues.

1.First, connect the iPhone to the Mac, tap Trust, and make sure iTunes connects successfully. Then open “Settings” - “Safari” - “Advanced” on the iPhone, and enable “JavaScript” and “Web Inspector”.


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-9ec6c25df1dedaa5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-a1f93269e8cc2fa7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


2.Open Safari on the Mac, choose “Preferences” - “Advanced” - “Show Develop menu in menu bar”.


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-cab218d03bdafb3d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


3.Open Safari on the iPhone or run the PhoneGap app and navigate to a screen. Then go back to Safari on the Mac, choose “Develop”, and select your iPhone. You should then be able to see that Web view.


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-92c19e242295d732.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p>