# WWDC2016 Session 笔记 - iOS 10 推送 Notification 新特性

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-520084e0dda3ed1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## 前言
在今年6月14号苹果WWDC开发者大会上，苹果带来了新的iOS系统——iOS 10。苹果为iOS 10带来了十大项更新。苹果高级副总裁Craig Federighi称此次对iOS的更新是“苹果史上最大的iOS更新”。


![](http://upload-images.jianshu.io/upload_images/1194012-4416fe3f0633a60e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1. 新的屏幕通知查看方式：苹果为iOS 10带来了全新的通知查看功能，即抬起iPhone的屏幕，用户就能看到目前的通知和更新情况。
2. 苹果将Siri开放给第三方开发者: 现在用户可以让Siri实现更多的功能，例如让Siri向自己的联系人发送微信信息等。目前Siri可以直接支持的应用有微信、WhatsApp以及Uber、滴滴、Skype等。
3. Siri将会更加智能：Siri将拥有更多对语境的意识。基于用户的地点、日历、联系人、联系地址等，Siri会做出智能建议。Siri将越来越成为一个人工智能机器人，具备深度学习功能。
4. 照片应用更新：基于深度学习技术，iOS 10对照片应用有比较大的更新。iOS 10对照片的搜索能力进一步增强，可以检测到新的人物和景色。未来的iPhone能够将相关的照片组织在一起，比如某次旅行的照片、某个周末的照片，并且能够进行自动编辑。iOS 10照片还新增了一个“记忆”标签。
5. 苹果地图：有点类似Siri和照片的更新，苹果地图也增加了很多预测功能，例如苹果地图能够将提供附近的餐厅建议。苹果地图的界面也得到了重新设计，更加的简洁，并增加了交通实时信息。新的苹果地图还将整合在苹果CarPlay中，将为用户提供turn-by-turn导航功能。和Siri一样，地图也将开放给开发者。
6. 苹果音乐：苹果音乐的界面得到了更新，界面会更加简洁、支持多任务，增加最近播放列表。苹果音乐现在已经有1500万付费用户。
7. HomeKit：iOS 10新增智能家庭应用，支持一键场景模式，HomeKit可以与Siri相连接。
![](http://upload-images.jianshu.io/upload_images/1194012-dd5070c430b37cc7.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
8. 苹果电话：苹果更新了电话功能，来电时可以区别出骚扰电话。
![](http://upload-images.jianshu.io/upload_images/1194012-20115aefabb1c770.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
9. iMesseage：在iMessage方面，用户可以直接在文本框内发送视频、链接，分享实时照片。另外，苹果还增添了表情预测功能，打出的文字若和表情相符，将会直接推荐相关表情。

以下是我关于关于iOS 10中变化比较大的推送通知的学习笔记。

##目录
- 1.Notification User Interface
- 2.Media Attachments
- 3.Customize user interface
- 4.Customize Actions

## 一. Notification User Interface
让我们先来看看用户推送在iOS X中的样子，如下图


![](http://upload-images.jianshu.io/upload_images/1194012-3439e7712872c625.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图这是在锁屏界面下的推送。支持抬起手机唤醒功能。

![](http://upload-images.jianshu.io/upload_images/1194012-a74bf10dc32c739b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
上图是Banner，可以看到这个推送更加的易读，并且包含更多的内容。


![](http://upload-images.jianshu.io/upload_images/1194012-d9dbd2a57d18d8ac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是通知中心。从上面三种图可以看到，它们都长一个样。



![](http://upload-images.jianshu.io/upload_images/1194012-55e35bda6f792759.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在iOS 8 中，我们可以给推送增加用户操作，这样使推送更加具有交互性，并且允许用户去处理用户推送更加的迅速。到了iOS 9 中，苹果又再次增加了快速回复功能，进一步的提高了通知的响应性。开发者可以允许用户通过点击推送，并用文字进行回复。再就到了iOS 10 中，推送变得更加给力。因为在iOS X中，推送对iOS系统来说，是很重要的一部分。在日常使用中，我们会经常和推送打交道。推送是我们和设备进行互动非常重要的方式。

在iOS X 中，你可以按压推送，推送就会被展开，展示出更加详细的用户界面。展示出来的详细界面对用户来说，提供了更加有用的信息。用户可以通过点击下面的按钮，来处理一些事件，并且推送的详细界面也会跟着用户的操作进行更新UI界面。

![](http://upload-images.jianshu.io/upload_images/1194012-28f89dc9b23bb018.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

iOS 8 中iMessage支持了快速回复功能，但是你只能看见一条信息，并且你也只能回复一条信息。但是在iOS X中，你可以展开推送，这个时候你就可以看到整个对话的内容了。你可以等待你的朋友回复，你再回复他，并且可以回复很多条。


以上就是iOS X的强大功能。以上的所有功能都能通过iOS X的新API来实现。所有的新特性都能在我们开发者开发的app里面有所体现。


## 二. Media Attachments



![](http://upload-images.jianshu.io/upload_images/1194012-51beb1aaef4af5ed.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果经常使用iMessage的朋友们，就会经常收到一些信息，附带了一些照片或者视频，所以推送中能附带这些多媒体是非常重要的。如果推送中包含了这些多媒体信息，可以使用户不用打开app，不用下载就可以快速浏览到内容。众所周知，推送通知中带了push payload，及时去年苹果已经把payload的size提升到了4k bites，但是这么小的容量也无法使用户能发送一张高清的图片，甚至把这张图的缩略图包含在推送通知里面，也不一定放的下去。在iOS X中，我们可以使用新特性来解决这个问题。我们可以通过新的service extensions来解决这个问题。

为了能去下载service extension 里面的attachment，我们必须去按照如下的要求去设置你的推送通知，使你的推送通知是动态可变的。

```

{
    aps: {
        alert : {……}
        mutable-content : 1
    }
    my-attachment : https://example.com/phtos.jpg"
}
```
在上面代码中，可以看到加载了一个mutable-content 的flag，然后我们就可以引用一个链接，把你想加入到推送里面的attachments加入到里面来。在上面的例子里面，我们就加入了一个URL。更复杂的，你甚至可以去加入一个identifier来标示你想加入到推送里面的内容，这个identifier是你app知道的，app能通过拿到identifier，然后知道去你自己的服务器哪里去下载内容。



![](http://upload-images.jianshu.io/upload_images/1194012-ba7069e754c5bcf8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

通过设置完上述的部分，推送就被推送到了每个设备的Service Extension那里了。在每个设备里面的Service Extension里面，就可以下载任意想要的attachment了。然后推送就会带着下载好的attachment推送到手机并显示出来了。


如果来设置Service Extension呢？来看看如下的代码：  

```

// Adding an attachment to a user notification

public class NotificationService: UNNotificationServiceExtension {
    override public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: (UNNotificationContent) -> Void)
    {
        let fileURL = // ...
        let attachment = UNNotificationAttachment(identifier: "image",
                                                  url: fileURL,
                                                  options: nil)
        let content = request.content.mutableCopy as! UNMutableNotificationContent 
        content.attachments = [ attachment ]
        contentHandler(content)
    }
}
```
首先定义了一个didReceive的方法，用来接收request，后面跟着withContentHandler的回调函数。
这个NotificationServiceExtension会在收到推送之后，被调用，然后在这个方法里面去下载自己的attachment。下载可以通过URL，或者任何你喜欢的方式。当下载完成之后，就可以创建attachment对象了。创建完UNMutableNotificationContent，我们就可以把这个加入到推送的content中了。最后，通过contentHandler回调，把它传递给iOS系统，iOS 系统就会展示给用户。


![](http://upload-images.jianshu.io/upload_images/1194012-a02ca43edd228bc1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


通过以上的设置，我们就能在推送中看到丰富的媒体信息了。用户并不需要去打开app，也不用去点击下载。

简单的概述一下Media Attachments：
1. 新特性使推送支持附带Media Attachments。本地推送和远程推送同时都可支持。
2. attachment支持图片，音频，视频，系统会自动提供一套可自定义化的UI，专门针对这3种内容。
3. 在service extension里面去下载attachment，但是需要注意，service extension会限制下载的时间，并且下载的文件大小也会同样被限制。这里毕竟是一个推送，而不是把所有的内容都推送给用户。所以你应该去推送一些缩小比例之后的版本。比如图片，推送里面附带缩略图，当用户打开app之后，再去下载完整的高清图。视频就附带视频的关键帧或者开头的几秒，当用户打开app之后再去下载完整视频。
4. 把下载完成的attachment加入到notification中。  
5. 推送里面包含的attachment这些文件，是由系统帮你管理的，系统会把这些文件放在单独的一个地方，然后统一管理。
6. 额外说明一点，推送的attachment的图片还可以包含GIF图。


通过以上可以看出，Media Attachments非常的酷，它为我们提供了更加丰富的推送内容。

接下来我们再来看看如何自定义推送的用户界面

##三. Customize user interface  

要想创建一个自定义的用户界面，需要用到Notification content extension。

先来说说下面这个例子的应用场景：  

比如有个朋友在日历中给我了一个聚会的邀请，这个时候就来了推送，推送里面的内容就是包含了聚会的时间地点信息，推送下面有三个按钮，接受，谢绝。下面的例子都以此为例。

Notification content extension允许开发者加入自定义的界面，在这个界面里面，你可以绘制任何你想要的东西。但是有一个最重要的限制就是，这个自定义的界面没有交互。它们不能接受点击事件，用户并不能点击它们。但是推送通知还是可以继续与用户进行交互，因为用户可以使用notificaiton的actions。extension可以处理这些actions。

接下来我们就来说说如何自定义界面

### 1.   推送的四部分

先来看一个日历的推送例子：


![](http://upload-images.jianshu.io/upload_images/1194012-15b9cc813f3c40cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图，整个推送分4段。用户可以通过点击Header里面的icon来打开app，点击取消来取消显示推送。Header的UI是系统提供的一套标准的UI。这套UI会提供给所有的推送通知。  

Header下面是自定义内容，这里就是显示的Notification content extension。在这里，就可以显示任何你想绘制的内容了。你可以展示任何额外的有用的信息给用户。

content extension下面就是default content。这里是系统的界面。这里的系统界面就是上面推送里面payload里面附带的内容。这也就是iOS 9 之前的推送的样子。

最下面一段就是notification action了。在这一段，用户可以触发一些操作。并且这些操作还会相应的反映到上面的自定义的推送界面content extension中。

### 2.创建 Notification content extension  

接下来我们就来看看如何创建一个Notification content extension


![](http://upload-images.jianshu.io/upload_images/1194012-b8b69cdab7aee38e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


第一件事就是去创建一个新的target。创建好了之后，Xcode会自动帮我们生成一个template。template会在新的target里面生成3个文件，一个新的ViewController，main Interface storyboard，info.plist。info.plist中就是可以定义化一些target的配置。


![](http://upload-images.jianshu.io/upload_images/1194012-bffc21df9faf33e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


打开Notification content extension的ViewController
```

// Minimal Content Extension
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var label: UILabel?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }
    func didReceive(_ notification: UNNotification) {
        label?.text = notification.request.content.body
    }
}
```
我们会发现，这个ViewController是UIViewController的子类，其实就是一个很普通的ViewController，和我们平时使用的没有啥两样。后面是UNNotificationContentExtension的protocol，这里是系统要求你必须实现的协议。

UNNotificationContentExtension只有一个required的方法，就是didReceive方法。当推送到达你的设备之后，这个didReceive方法会随着ViewController的生命周期的方法 ，一起被调用。当开发者给推送加上expands的时候，一旦推送送达以后，这时会接到所有的ViewController生命周期的方法，和didReceive方法。这样，我们就可以接收notification object ，接着更新UI。


### 3. 配置target
接下来，我们需要做的是，告诉iOS系统，推送送达之后，iOS系统如何找到你自定义的Notification content extension。


![](http://upload-images.jianshu.io/upload_images/1194012-9cafc7af30c557d8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Notification content extension和我们注册notification actions一样，注册的相同的category。这个例子中，我们使用event-invite。值得提到的一点是，这里的extension是可以为一个数组的，里面可以为多个category，这样做的目的是多个category共用同一套UI。


![](http://upload-images.jianshu.io/upload_images/1194012-33d02a0c6572c81b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图中，event-invite 和 event-update就共用了一套UI。这样我们就可以把他们打包到一个extension里面来。但是不同的category是独立的，他们可以相应不同的actions。

通过以上设置，iOS系统就知道了我们的target了。


### 4. 自定义用户UI界面  

接下来我们来自定义UI界面。
```

// Notification Content Extension
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var eventTitle: UILabel!
    @IBOutlet var eventDate: UILabel!
    @IBOutlet var eventLocation: UILabel!
    @IBOutlet var eventMessage: UILabel!
    
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        
        eventTitle.text = content.title
        eventDate.text = content.subtitle
        eventMessage.text = content.body
        
        if let location = content.userInfo["location"] as? String {
            eventLocation.text = location
        }
    }
}
```

上述代码中，我们在stroyboard 里面加入了一些labels 。当接收到推送的时候，我们提取出内容，得到我们想要的内容，然后把这些内容设置到label上面去，并展示出来。在content的userinfo里面我们还能加入一些额外的信息，这些信息是标准的payload无法展示的，比如说位置信息等等。



![](http://upload-images.jianshu.io/upload_images/1194012-c1962c798ad01273.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


代码完成之后就是如上的样子，中间就是我们自定义的UIView了。但是这样子会有2个问题。第一个问题就是这个自定义的View实在太大了。大量的空白不需要显示出来。第二个问题就是我们自定义的内容和下面默认的推送内容重复了。我们需要去掉一份。


### 5.改进

我们先来改进上面说的第二个问题。
这个问题很简单，其实就是一个plist的设置。我们可以在plist里面把默认的content隐藏。设置如下图。



![](http://upload-images.jianshu.io/upload_images/1194012-b4dc0be29fdce509.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


再来说说第一个问题，界面大小的问题。
我们可以通过平时我们Resize其他ViewController一样，来Resize这个ViewController。来看看如下的代码。

```

// Notification Content Extension
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    override func viewDidLoad() {
        
        super.viewDidLoad()
        let size = view.bounds.size
        
        preferredContentSize = CGSize(width: size.width, height: size.width / 2)
    }
    
    func didReceive(_ notification: UNNotification) {
        // ...
    }
}
```
这里我们也可以加入constraints来做autolayout。



![](http://upload-images.jianshu.io/upload_images/1194012-7f7cc4a4fc88a599.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

解决完上面2个问题，界面就会变成这个样子。看上去比之前好很多了。正常的尺寸，没有多余的空白。没有重复信息。但是这又出现了另外一个问题。当通知展示出来之后，它的大小并不是正常的我们想要的尺寸。iOS系统会去做一个动画来Resize它的大小。如下图，系统会先展现出第一张图，然后紧接着展示第二张图，这个用户体验很差。



![](http://upload-images.jianshu.io/upload_images/1194012-7d887c3b6ec3fe57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-20779263e0de3c19.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


会出现上面这张图的原因是，在推送送达的那一刻，iOS系统需要知道我们推送界面的最终大小。但是我们自定义的extension在系统打算展示推送通知的那一刻，并还没有启动。所以这个时候，在我们代码都还没有跑起来之前，我们需要告诉iOS系统，我们的View最终要展示的大小。

现在问题又来了。这些通知会跑在不同的设备上，不同的设备的屏幕尺寸不同。为了解决这个问题，我们需要设置一个content size ratio。


![](http://upload-images.jianshu.io/upload_images/1194012-e7cd9adac20e2730.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这个属性定义了宽和高的比例。当然设置了这个比例以后，也并不是万能的。因为你并不知道你会接受到多长的content。当你仅仅只设置比例，还是不能完整的展示所有的内容。有些时候如果我们可以知道最终的尺寸，那么我们固定尺寸会更好。


###6. 进一步美化 

我们可以给这个extension加上Media Attachments。一旦我们加入Media Attachments，我们可以在content extension里面使用这些内容。

```

// Notification Content Extension Attachments
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var eventImage: UIImageView!
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        if let attachment = content.attachments.first {
            if attachment.url.startAccessingSecurityScopedResource() {
                eventImage.image = UIImage(contentsOfFile: attachment.url.path!)
                attachment.url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
```
我们可以提取content的attachments。前文提到过，attachment是由系统管理的，系统会把它们单独的管理，这意味着它们存储在我们sandbox之外。所以这里我们要使用attachment之前，我们需要告诉iOS系统，我们需要使用它，并且在使用完毕之后告诉系统我们使用完毕了。对应上述代码就是startAccessingSecurityScopedResource()和stopAccessingSecurityScopedResource()的操作。当我们获取到了attachment的使用权之后，我们就可以使用那个文件获取我们想要的信息了。

上述例子中，我们从attachment中获取到图片，并展示到UIImageView中。于是notification就变成下面这个样子了。


![](http://upload-images.jianshu.io/upload_images/1194012-4640a3c616c41b8e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## 四.Customize Actions  

说道这里，我们不得不说一下iOS8开始引入的action的工作原理：
默认系统的Action的处理是，当用户点击的按钮，就把action传递给app，与此同时，推送通知会立即消失。这种做法很方便。

但是还有一种情况，当用户点击了按钮，希望接受一些日历上的邀请，我们需要把这个操作即时的展示在我们自定义的UI上，这是我们就只能用Notification content extension来处理这些用户点击事件了。这个时候，用户点击完按钮，我们把这个action直接传递给extension，而不是传递给app。当actions传递给extension时，它可以延迟推送通知的消失时间。在这段延迟的时间之内，我们就可以处理用户点击按钮的事件了，并且更新UI，一切都处理完成之后，我们再去让推送通知消失掉。

这里我们可以运用UNNotificationContentExtension协议的第二个方法，这方法是Optional

```

// Intercepting notification action response
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    func didReceive(_ response: UNNotificationResponse, completionHandler done: (UNNotificationContentExtensionResponseOption) -> Void) {
        server.postEventResponse(response.actionIdentifier) {
            if response.actionIdentifier == "accept" {
                eventResponse.text = "Going!"
                eventResponse.textColor = UIColor.green()
            } else if response.actionIdentifier == "decline" {
                eventResponse.text = "Not going :("
                eventResponse.textColor = UIColor.red()
            }
            done(.dismiss)
        }
    }
}
```
不用这个方法的时候就可以不声明出来。但是一旦声明了，那么你就需要在这个方法里面处理推送通知里面所有的actions。这就意味着你不能只处理一个action，而不管其他的action。

在上述代码中，当用户点击了按钮，这个时候我们同步一下服务器信息，当接收到了服务器应答之后，然后我们更新UI。用户点击了“accept”之后，表示接受了这次聚会邀请，于是我们把text的颜色变成绿色。当用户点击了“decline”，表示谢绝，于是我们把text的颜色变成红色。当用户点击之后，更新完界面，我们就让推送通知消失掉。


这里值得一提的是，如果你还想把这个action传递给app，那么最后的参数应该是这样。

```
done(.dismissAndForwardAction)
```
参数设置成这样之后，用户的action就会再传递给app。


如果此时用户还想输入写文字来评论这条推送，我们该如何做？

这个输入文字的需求是来自于iOS 9 。这个的使用方法和9是相同的。

```

// Text Input Action
private func makeEventExtensionCategory() -> UNNotificationCategory {
    let commentAction = UNTextInputNotificationAction(
        identifier: "comment",
        title: "Comment",
        options: [],
        textInputButtonTitle: "Send",
        textInputPlaceholder: "Type here...")
    return UNNotificationCategory(identifier: "event-invite", actions: [ acceptAction, declineAction, commentAction ],
}
```
我们可以创建一个UNTextInputNotificationAction，并把它设置到plist里面的Category中。当推送通知到来之后，用户点击了按钮，textfield就会显示出来。同样的处理action代码如下：

```

// Text input action response
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    func didReceive(_ response: UNNotificationResponse,
                      completionHandler done: (UNNotificationContentExtensionResponseOption) -> Void) {
        if let textResponse = response as? UNTextInputNotificationResponse {
            server.send(textResponse.userText) {
            }
        }
    }
}
```

这个时候当用户点击了评论按钮，就会弹出textfield。


这里还有一个问题，就是用户点完评论按钮之后，之前的接受和谢绝的按钮就消失了。这个时候用户可能有这个需求，想又评论，又接受或者谢绝。那么我们就需要在下面键盘上加入这两个按钮。如下图这样子。



![](http://upload-images.jianshu.io/upload_images/1194012-68965591c8c9c0c6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这里并没有新的API，还是用原来的API。我们可以使用已经存在的UIKit的API去定制输入的input accessory view。它可以让我们开发者加入自定义的按钮。

```

// Custom input accessory view
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    override var inputAccessoryView: UIView { get {
        return inputView
        }
    }
    func didReceive(_ response: UNNotificationResponse,
                      completionHandler done: (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "comment" {
            becomeFirstResponder()
            textField.becomeFirstResponder()
        }
    }
}
```  

解析一下上述的代码。首先我们需要让ViewController BecomeFirstResponder。这里做了2件事情，一是告诉responder chain，我成为了第一响应者，二是告诉iOS系统，我不想使用系统标准的text field。接着就可以创建自定义化的inputAccessoryView。如上图中显示的，带自定义的两个按钮。然后，当extension接受到了用户点击按钮后产生的action，这时自定义的textfield就会变成第一响应者，并且伴随着键盘的弹起。

注意，这里需要2个becomeFirstResponder，第一个becomeFirstResponder是使viewController变成第一响应者，这样textfield就会出现。第二个becomeFirstResponder是使我们自定义的textfield变成第一响应者，这样键盘才会弹起。



## 总结  
以上就是iOS X中notification的所有新特性，通过上文，我们学到的以下的知识，总结一下：
1. 什么是attachment
2. 如何在service extension中使用attachment
3. 如何定义content extension的用户UI界面
4. 如何响应用户操作action

最后，请大家多多指教。



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/wwdc2016\_ios10\_notification\_new\_features/](https://halfrost.com/wwdc2016_ios10_notification_new_features/)

