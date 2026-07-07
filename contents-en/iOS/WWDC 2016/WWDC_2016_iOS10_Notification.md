# WWDC 2016 Session Notes - New Notification Features in iOS 10

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-520084e0dda3ed1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface
At Apple’s WWDC developer conference on June 14 this year, Apple introduced its new iOS system—iOS 10. Apple brought ten major updates to iOS 10. Apple Senior Vice President Craig Federighi called this iOS update “the biggest iOS release ever.”


![](http://upload-images.jianshu.io/upload_images/1194012-4416fe3f0633a60e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1. A new way to view notifications on the Lock Screen: Apple introduced an all-new notification viewing experience in iOS 10. When users raise their iPhone screen, they can see current notifications and updates.
2. Apple opened Siri to third-party developers: Users can now ask Siri to do more, such as sending WeChat messages to their contacts. Apps that Siri can directly support currently include WeChat, WhatsApp, Uber, Didi, Skype, and others.
3. Siri will become smarter: Siri will have greater contextual awareness. Based on the user’s location, calendar, contacts, contact addresses, and more, Siri can make intelligent suggestions. Siri will increasingly become an AI assistant with deep learning capabilities.
4. Updates to the Photos app: Based on deep learning technology, iOS 10 brings relatively major updates to Photos. iOS 10 further enhances photo search capabilities and can detect new people and scenes. Future iPhones will be able to organize related photos together, such as photos from a trip or a weekend, and automatically edit them. Photos in iOS 10 also adds a new “Memories” tab.
5. Apple Maps: Somewhat similar to the updates to Siri and Photos, Apple Maps also adds many predictive features. For example, Apple Maps can provide nearby restaurant suggestions. The Apple Maps UI has also been redesigned to be cleaner, and real-time traffic information has been added. The new Apple Maps will also be integrated into Apple CarPlay, providing users with turn-by-turn navigation. Like Siri, Maps will also be opened to developers.
6. Apple Music: The Apple Music UI has been updated. The interface is cleaner, supports multitasking, and adds a Recently Played list. Apple Music now has 15 million paid subscribers.
7. HomeKit: iOS 10 adds a smart home app, supports one-tap scene modes, and HomeKit can connect with Siri.
![](http://upload-images.jianshu.io/upload_images/1194012-dd5070c430b37cc7.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
8. Apple Phone: Apple updated the Phone functionality so that incoming calls can identify spam calls.
![](http://upload-images.jianshu.io/upload_images/1194012-20115aefabb1c770.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
9. iMesseage: In iMessage, users can send videos and links directly in the text field and share Live Photos. Apple also added emoji prediction: if the typed text matches an emoji, the related emoji will be suggested directly.

The following are my study notes on push notifications, which changed significantly in iOS 10.

##Table of Contents
- 1.Notification User Interface
- 2.Media Attachments
- 3.Customize user interface
- 4.Customize Actions

## I. Notification User Interface
First, let’s take a look at what user notifications look like in iOS X, as shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-3439e7712872c625.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows a notification on the Lock Screen. It supports Raise to Wake.

![](http://upload-images.jianshu.io/upload_images/1194012-a74bf10dc32c739b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
The image above shows a banner. You can see that this notification is easier to read and contains more content.


![](http://upload-images.jianshu.io/upload_images/1194012-d9dbd2a57d18d8ac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows Notification Center. From the three images above, you can see that they all look the same.


![](http://upload-images.jianshu.io/upload_images/1194012-55e35bda6f792759.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In iOS 8, we could add user actions to notifications, making notifications more interactive and allowing users to handle them more quickly. In iOS 9, Apple added quick reply, further improving notification responsiveness. Developers could allow users to tap a notification and reply with text. Then in iOS 10, notifications became even more powerful. In iOS X, notifications are a very important part of the iOS system. In day-to-day use, we frequently interact with notifications. Notifications are a very important way for us to interact with our devices.

In iOS X, you can press on a notification and it expands to show a more detailed user interface. The detailed UI that appears provides more useful information to the user. Users can handle certain events by tapping the buttons below, and the notification’s detailed UI will also update in response to the user’s actions.

![](http://upload-images.jianshu.io/upload_images/1194012-28f89dc9b23bb018.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In iOS 8, iMessage supported quick reply, but you could only see one message, and you could only reply with one message. In iOS X, however, you can expand the notification, and at that point you can see the entire conversation. You can wait for your friend to reply, then reply to them, and you can send multiple replies.


That is the power of iOS X. All of the functionality above can be implemented through the new APIs in iOS X. All of these new features can be reflected in the apps we developers build.


## II. Media Attachments


![](http://upload-images.jianshu.io/upload_images/1194012-51beb1aaef4af5ed.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If you often use iMessage, you will frequently receive messages that include photos or videos, so it is very important for notifications to be able to include this type of media. If a notification contains this media information, users can quickly preview the content without opening the app and without downloading it. As we all know, push notifications include a push payload. Even though Apple increased the payload size to 4 KB last year, such a small capacity still cannot allow users to send a high-resolution image; even including a thumbnail of the image in the push notification may not fit. In iOS X, we can use new features to solve this problem. We can solve it through new service extensions.

In order to download the attachment in the service extension, we must configure your push notification according to the following requirements so that the push notification is mutable.
```

{
    aps: {
        alert : {……}
        mutable-content : 1
    }
    my-attachment : https://example.com/phtos.jpg"
}
```
In the code above, you can see that a `mutable-content` flag is set. We can then reference a link and add the attachments you want to include in the push notification. In the example above, we added a URL. For more complex cases, you can even add an identifier to indicate the content you want to include in the push notification. This identifier is known to your app; after obtaining it, the app can determine where to download the content from your own server.


![](http://upload-images.jianshu.io/upload_images/1194012-ba7069e754c5bcf8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After the configuration above is complete, the push notification is delivered to the Service Extension on each device. Inside the Service Extension on each device, you can download any attachment you want. The push notification will then be delivered to the phone with the downloaded attachment and displayed.


So how do you configure the Service Extension? Take a look at the following code: 
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
First, a `didReceive` method is defined to receive the request, followed by the callback function `withContentHandler`.
This `NotificationServiceExtension` is invoked after a push notification is received, and in this method it downloads its own attachment. The download can be done via a URL, or in any way you prefer. Once the download is complete, you can create the attachment object. After creating the `UNMutableNotificationContent`, we can add it to the push notification’s content. Finally, through the `contentHandler` callback, it is passed to the iOS system, which then presents it to the user.


![](http://upload-images.jianshu.io/upload_images/1194012-a02ca43edd228bc1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


With the setup above, we can display rich media information in push notifications. Users do not need to open the app, nor do they need to tap to download it.

A brief overview of Media Attachments:
1. This new feature allows push notifications to include Media Attachments. Both local and remote notifications are supported.
2. Attachments support images, audio, and video. The system automatically provides a customizable UI specifically for these three types of content.
3. Download the attachment inside the service extension, but note that the service extension limits the download time, and the downloaded file size is also limited. After all, this is a push notification, not a way to push all content to the user. So you should push scaled-down versions. For example, for images, include a thumbnail in the push notification, and download the full high-resolution image after the user opens the app. For video, include a key frame or the first few seconds, and download the full video after the user opens the app.
4. Add the downloaded attachment to the notification.  
5. The attachment files included in the push notification are managed by the system. The system places these files in a separate location and manages them centrally.
6. One additional note: image attachments in push notifications can also include GIFs.


As you can see from the above, Media Attachments are very cool and provide us with much richer push notification content.

Next, let’s look at how to customize the push notification user interface.

##III. Customize user interface  

To create a custom user interface, you need to use a Notification content extension.

First, let’s talk about the use case for the following example:  

Suppose a friend sends me a party invitation in the calendar. At this point, a push notification arrives, and the content of the notification includes the time and location of the party. Below the notification are three buttons: Accept and Decline. The following examples are based on this scenario.

Notification content extension allows developers to add a custom interface. In this interface, you can draw anything you want. However, the most important limitation is that this custom interface is not interactive. It cannot receive tap events, and users cannot tap it. But push notifications can still continue to interact with users, because users can use notification actions. The extension can handle these actions.

Next, let’s discuss how to customize the interface.

### 1.   The four parts of a push notification

First, let’s look at an example of a calendar push notification:


![](http://upload-images.jianshu.io/upload_images/1194012-15b9cc813f3c40cf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As shown above, the entire push notification is divided into four sections. The user can tap the icon in the Header to open the app, or tap Cancel to dismiss the notification. The Header UI is a standard UI provided by the system. This UI is provided for all push notifications.  

Below the Header is the custom content, which is the displayed Notification content extension. Here, you can display anything you want to draw. You can show any additional useful information to the user.

Below the content extension is the default content. This is the system UI. The system UI here is the content included in the payload of the push notification above. This is also what push notifications looked like before iOS 9.

The bottom section is the notification action area. In this section, users can trigger certain operations. These operations are also reflected accordingly in the custom push notification interface above, the content extension.

### 2. Create Notification content extension  

Next, let’s look at how to create a Notification content extension.


![](http://upload-images.jianshu.io/upload_images/1194012-b8b69cdab7aee38e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The first thing to do is create a new target. After it is created, Xcode automatically generates a template for us. The template creates three files in the new target: a new ViewController, a main Interface storyboard, and an info.plist. The info.plist is where you can customize some target configuration.


![](http://upload-images.jianshu.io/upload_images/1194012-bffc21df9faf33e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Open the ViewController of the Notification content extension.
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
We can see that this `ViewController` is a subclass of `UIViewController`. In fact, it is just a regular `ViewController`, no different from the ones we normally use. After that is the `UNNotificationContentExtension` protocol, which is a protocol the system requires you to implement.

`UNNotificationContentExtension` has only one required method: `didReceive`. After a push notification arrives on your device, this `didReceive` method is called together with the `ViewController` lifecycle methods. When the developer adds `expands` to the push notification, once the push notification is delivered, all `ViewController` lifecycle methods and the `didReceive` method will be called. This allows us to receive the `notification object` and then update the UI.


### 3. Configure the target
Next, we need to tell the iOS system how to find your custom Notification content extension after the push notification is delivered.


![](http://upload-images.jianshu.io/upload_images/1194012-9cafc7af30c557d8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

A Notification content extension registers the same `category` as we do when registering notification actions. In this example, we use `event-invite`. One thing worth mentioning is that the extension here can be an array containing multiple categories. The purpose of this is to allow multiple categories to share the same UI.


![](http://upload-images.jianshu.io/upload_images/1194012-33d02a0c6572c81b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the image above, `event-invite` and `event-update` share the same UI. This allows us to package them into a single extension. However, different categories are independent, and they can correspond to different actions.

With the settings above, the iOS system now knows about our target.


### 4. Customize the user UI

Next, let’s customize the UI.
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
In the code above, we added some labels in the storyboard. When a push notification is received, we extract the content, get the data we want, then set that data on the labels and display it. We can also add some extra information to `userinfo` in the content—information that cannot be displayed by the standard payload, such as location data, and so on.


![](http://upload-images.jianshu.io/upload_images/1194012-c1962c798ad01273.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


After the code is complete, it looks like the above. The middle section is our custom `UIView`. However, there are two issues with this. The first is that this custom View is much too large. A lot of the empty space does not need to be displayed. The second is that our custom content duplicates the default push notification content below it. We need to remove one of them.


### 5. Improvements

Let’s first improve the second issue mentioned above.
This issue is very simple; it is really just a `plist` setting. We can hide the default content in the `plist`, as shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-b4dc0be29fdce509.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Now let’s talk about the first issue: the size of the UI.
We can resize this `ViewController` the same way we usually resize other `ViewController`s. Take a look at the code below.
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
Here we can also add constraints to implement Auto Layout.


![](http://upload-images.jianshu.io/upload_images/1194012-7f7cc4a4fc88a599.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After resolving the two issues above, the UI will look like this. It looks much better than before: the dimensions are normal, there is no extra whitespace, and there is no duplicated information. But this introduces another problem. After the notification is displayed, its size is not the normal size we expect. iOS will perform an animation to resize it. As shown below, the system first displays the first image, then immediately displays the second image. This results in a poor user experience.


![](http://upload-images.jianshu.io/upload_images/1194012-7d887c3b6ec3fe57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-20779263e0de3c19.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The reason the image above appears is that, at the moment the push notification is delivered, iOS needs to know the final size of our notification UI. However, our custom extension has not yet launched when the system is about to display the push notification. So at this point, before any of our code has run, we need to tell iOS what size our View will ultimately be displayed at.

Now there is another issue. These notifications will run on different devices, and different devices have different screen sizes. To solve this, we need to set a content size ratio.


![](http://upload-images.jianshu.io/upload_images/1194012-e7cd9adac20e2730.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This property defines the ratio between width and height. Of course, setting this ratio is not a silver bullet. You do not know how much content you will receive. If you only set the ratio, you still may not be able to display all the content completely. In some cases, if we can know the final size, using a fixed size is preferable.


###6. Further Polishing 

We can add Media Attachments to this extension. Once we add Media Attachments, we can use these assets in the content extension.
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
We can extract the attachments from the content. As mentioned earlier, attachments are managed by the system, and the system manages them separately, which means they are stored outside our sandbox. So before using an attachment here, we need to tell iOS that we want to use it, and after we are done, tell the system that we have finished using it. In the code above, this corresponds to the calls to `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`. Once we have obtained access to the attachment, we can use that file to retrieve the information we need.

In the example above, we get an image from the attachment and display it in a `UIImageView`. The notification then looks like this:


![](http://upload-images.jianshu.io/upload_images/1194012-4640a3c616c41b8e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## IV. Customize Actions  

At this point, we have to talk about how actions introduced in iOS 8 work:

By default, the system handles an action by passing the action to the app when the user taps a button, and at the same time the push notification disappears immediately. This approach is very convenient.

But there is another scenario: when the user taps a button, for example to accept a calendar invitation, we want to reflect that operation immediately in our custom UI. In this case, we can only use a Notification Content Extension to handle these user tap events. At that point, after the user taps the button, we pass the action directly to the extension instead of to the app. When actions are passed to the extension, it can delay the disappearance of the push notification. During this delay, we can handle the user’s button tap event and update the UI. Once everything has been handled, we then dismiss the push notification.

Here we can use the second method of the `UNNotificationContentExtension` protocol. This method is optional.
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
If you don’t use this method, you don’t need to declare it. But once you do declare it, you must handle all actions in the push notification inside this method. This means you can’t handle only one action and ignore the others.

In the code above, when the user taps the button, we synchronize the server information. After receiving the server’s response, we update the UI. When the user taps “accept”, it means they accept the party invitation, so we change the text color to green. When the user taps “decline”, it means they decline, so we change the text color to red. After the user taps and the UI has been updated, we dismiss the push notification.

One thing worth mentioning here is that if you also want to pass this action to the app, the final parameter should be as follows.
```
done(.dismissAndForwardAction)
```
After the parameters are configured this way, the user’s `action` will be passed back to the app.

If the user also wants to enter text to comment on this push notification at this point, what should we do?

This text input capability was introduced in iOS 9. Its usage is the same as in iOS 9.
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
We can create a `UNTextInputNotificationAction` and configure it under the `Category` in the `plist`. When the push notification arrives and the user taps the button, the text field will be displayed. The action-handling code is the same as follows:
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
At this point, when the user taps the comment button, a text field pops up.

There is another issue here: after the user taps the comment button, the previous Accept and Decline buttons disappear. At this point, the user may want to both leave a comment and accept or decline. So we need to add these two buttons to the keyboard, as shown below.

![](http://upload-images.jianshu.io/upload_images/1194012-68965591c8c9c0c6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

There is no new API here; we still use the original API. We can use the existing UIKit APIs to customize the input accessory view. This allows us, as developers, to add custom buttons.
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
Let's walk through the code above. First, we need to make the ViewController BecomeFirstResponder. This does two things: first, it tells the responder chain that I have become the first responder; second, it tells the iOS system that I do not want to use the system’s standard text field. We can then create a customized inputAccessoryView. As shown in the figure above, it includes two custom buttons. Then, when the extension receives the action triggered by the user tapping a button, the custom text field becomes the first responder, and the keyboard pops up along with it.

Note that two becomeFirstResponder calls are required here. The first becomeFirstResponder makes the viewController the first responder, so the text field appears. The second becomeFirstResponder makes our custom text field the first responder, so the keyboard is brought up.


## Summary  
That covers all the new notification features in iOS X. From the discussion above, we learned the following:
1. What an attachment is
2. How to use attachments in a service extension
3. How to define the user UI for a content extension
4. How to respond to user actions

Finally, feedback and suggestions are very welcome.


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/wwdc2016\_ios10\_notification\_new\_features/](https://halfrost.com/wwdc2016_ios10_notification_new_features/)