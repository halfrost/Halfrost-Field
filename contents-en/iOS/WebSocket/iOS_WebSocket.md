# How IM Apps Like WeChat and QQ Are Built—A Discussion of WebSocket

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-324588e5f12ae955.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface
My connection with WebSocket: after first hearing about it from my teacher in a computer networking class during my sophomore year, I did not actually use it until my first job after graduation. Recently, after changing jobs and joining a company whose app includes IM-style social chat features, I feel I can now share some of my views on WebSocket/Socket. If you want to build an IM chat app, you have to understand the principles behind WebSocket and Socket. Let me walk through them one by one.


## Table of Contents
- 1.WebSocket use cases
- 2.How WebSocket came about
- 3.A discussion of the WebSocket protocol principles
- 4.Differences and relationships between WebSocket and Socket
- 5.Open-source WebSocket and Socket frameworks on iOS
- 6.How to implement the WebSocket protocol on iOS   


## I.WebSocket Use Cases

**1.Social chat**  

The most famous examples are WeChat, QQ, and similar social chat apps. The defining characteristics of these chat apps are low latency and high immediacy. Immediacy is the most important requirement here. If there is an urgent matter and you are notified through IM software, assuming the network environment is good, but the message still cannot be delivered to your client immediately, and you only receive it after the emergency is already over, then the software is undoubtedly a failure.

**2.Bullet comments**  
At this point, everyone is probably thinking of AcFun and Bilibili. Indeed, bullet comments have always been one of their signature features. For a video, the bullet comments may very well be the essence of the experience. Sending bullet comments requires real-time display, and just like chat, it requires immediacy.

**3.Multiplayer games**  

**4.Collaborative editing**  

Many open-source projects today are collaboratively developed by developers distributed around the world. In such cases, version control systems such as Git and SVN are used to merge conflicts. But if there is a document that supports real-time online collaborative editing by multiple people, then something like WebSocket comes into play. It can ensure that all editors are working on the same document. At that point, version control systems such as Git and SVN are not needed, because on the collaborative editing interface, you can see in real time what others are editing and who is modifying which paragraphs and text.

**5.Real-time stock and fund quotes**  
The financial world changes in an instant—almost every millisecond. If the adopted network architecture cannot satisfy real-time requirements, it can cause huge losses for customers. If a stock starts plunging a few milliseconds earlier but the data is not refreshed until several seconds later, within that one second the user may already have lost a substantial amount of assets.

**6.Live sports updates**  
There are many fans and sports enthusiasts around the world. Of course, when people care about their favorite sports events, real-time match updates are what they care about most. The best experience for this kind of news is to use WebSocket to achieve real-time updates!

**7.Video conferencing/chat**  
Video conferencing cannot replace meeting people in person, but it allows people distributed across every corner of the world to gather in front of their computers and hold meetings together. It saves the time spent traveling to meet in one place, avoids the hassle of deciding where to meet, and makes it possible to have a meeting anytime and anywhere as long as there is a network connection.

**8.Location-based applications**  
More and more developers are using the GPS capabilities of mobile devices to implement their location-based web applications. If you continuously record a user's location (for example, running an app to record a workout route), you can collect more fine-grained data.

**9.Online education**  
Online education has also developed rapidly in recent years. It has many advantages: it removes the constraints of physical venues and allows resources from excellent teachers to be reasonably distributed to students across the country who want to learn. WebSocket is a good choice here. It can support video chat, instant messaging, and collaborating with others to discuss problems online...

**10.Smart home**  
This is also the great IoT smart home company I joined right after graduation. Considering that the state of smart devices at home must be displayed on the mobile app client in real time, WebSocket was undoubtedly the choice.

**11.Summary**  
Looking at the scenarios listed above, they all have one thing in common: high real-time requirements!

## II.How WebSocket Came About

1.**The initial Polling stage**
![](http://upload-images.jianshu.io/upload_images/1194012-ce4df238336909a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This approach is not suitable for retrieving real-time information. The client and server keep establishing connections, and the client asks once every certain interval. The client polls to check whether there are any new messages. This approach creates many connections—one for receiving and one for sending. In addition, every request carries an HTTP Header, which consumes a lot of bandwidth and also increases CPU utilization.

2.**The improved Long polling stage**

![](http://upload-images.jianshu.io/upload_images/1194012-6ca608d5a37095e6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Long polling is an improved version of polling. After the client sends an HTTP request to the server, the server checks whether there is a new message. If there is no new message, it keeps waiting. Only when a new message arrives does it return a response to the client. To some extent, this reduces network bandwidth and CPU utilization issues. However, this approach still has a drawback: for example, suppose the server-side data updates very quickly. After the server sends one data packet to the client, it must wait for the client's next Get request before it can deliver the second updated data packet to the client. In that case, the fastest time for the client to display real-time data is 2×RTT (round-trip time). If the network is congested, this delay is unacceptable to users, for example in stock market quotations. In addition, because the header data of HTTP packets is often large (usually over 400 bytes), while the data actually needed by the server is very small (sometimes only around 10 bytes), periodically transmitting such packets over the network inevitably wastes network bandwidth.

3.**The birth of WebSocket**

What was urgently needed was support for bidirectional communication between client and server, while keeping the protocol header much smaller than the HTTP Header. As a result, WebSocket was born!

![](http://upload-images.jianshu.io/upload_images/1194012-b88b2623a2e4a8ea.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The figure above shows the difference between WebSocket and Polling. As you can see, with Polling, the client sends many Requests, whereas in the figure below, there is only one Upgrade, which is very concise and efficient. As for the comparison of overhead, see the figure below.

![](http://upload-images.jianshu.io/upload_images/1194012-f1f91e25b9635701.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the figure above, first look at the blue bar chart, which shows the traffic consumed by Polling. In this test, the overhead of the HTTP request and response header information totals 871 bytes. Of course, different requests in different tests will have different header overhead. This test uses requests with 871 bytes of overhead.

**Use case A**: 1,000 clients polling every second: Network throughput is (871 x 1,000) = 871,000 bytes = 6,968,000 bits per second (6.6 Mbps)  
**Use case B**: 10,000 clients polling every second: Network throughput is (871 x 10,000) = 8,710,000 bytes = 69,680,000 bits per second (66 Mbps)  
**Use case C**: 100,000 clients polling every 1 second: Network throughput is (871 x 100,000) = 87,100,000 bytes = 696,800,000 bits per second (665 Mbps)  
By contrast, a WebSocket Frame has just two bytes of overhead instead of 871; just 2 bytes replace the 871 bytes used by polling!

**Use case A**: 1,000 clients receive 1 message per second: Network throughput is (2 x 1,000) = 2,000 bytes = 16,000 bits per second (0.015 Mbps)  
**Use case B**: 10,000 clients receive 1 message per second: Network throughput is (2 x 10,000) = 20,000 bytes = 160,000 bits per second (0.153 Mbps)  
**Use case C**: 100,000 clients receive 1 message per second: Network throughput is (2 x 100,000) = 200,000 bytes = 1,600,000 bits per second (1.526 Mbps)    

With the same number of client polls per second, when the frequency reaches 100K/s, Polling consumes 665 Mbps, whereas WebSocket consumes only 1.526 Mbps—nearly 435 times less!


## III.A Discussion of the WebSocket Protocol Principles
WebSocket is an application-layer protocol at layer 7. It must rely on the [HTTP protocol for an initial handshake](http://tools.ietf.org/html/rfc6455#section-4) . After the handshake succeeds, data is transmitted directly over the TCP channel and is no longer related to HTTP.

WebSocket transmits data in the form of frames. For example, it may split a message into several frames and transmit them in order. This has several benefits:

1 Large data transfers can be fragmented, so you do not need to worry about insufficient length flag bits caused by the data size.
2 Like HTTP chunking, data can be generated while messages are being transmitted, improving transmission efficiency.
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+


    FIN      1bit indicates the final frame of the message, flag, i.e. marker
    RSV 1-3  1bit each reserved for future use; default all 0
    Opcode   4bit frame type, detailed later
    Mask     1bit mask, whether to encrypt data; must be set to 1 by default (this is a pain)
    Payload  7bit data length
    Masking-key      1 or 4 bit mask
    Payload data     (x + y) bytes data
    Extension data   x bytes  extension data
    Application data y bytes  application data
```
For the specific specification, please refer to the detailed definition in the official [RFC 6455](https://tools.ietf.org/html/rfc6455) document. There is also a [translated version](https://www.gitbook.com/book/chenjianlong/rfc-6455-websocket-protocol-in-chinese/details)

## IV. Differences and Relationship Between WebSocket and Socket

First, [Socket](http://en.wikipedia.org/wiki/Network_socket) is not actually a protocol. It operates at the session layer of the OSI model (Layer 5) and exists as an abstraction layer to make it easier to use lower-level protocols directly—typically [TCP](http://en.wikipedia.org/wiki/Transmission_Control_Protocol) or [UDP](http://en.wikipedia.org/wiki/User_Datagram_Protocol). Socket is an encapsulation of the TCP/IP protocol suite. Socket itself is not a protocol, but rather a calling interface (API).


![](http://upload-images.jianshu.io/upload_images/1194012-d35653654be833ae.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

A Socket is also commonly referred to as a “socket.” It is used to describe an IP address and port, and serves as a handle for a communication link. Two programs on a network exchange data through a bidirectional communication connection; one endpoint of this bidirectional link is called a Socket. A Socket is uniquely determined by an IP address and a port number. Applications typically use “sockets” to send requests to the network or respond to network requests.

During Socket communication, the server listens on a port for connection requests, and the client sends a connection request to the server. After receiving the connection request, the server sends an acceptance message to the client, and the connection is established. Both the client and the server can then send messages to each other for communication until the connection is closed by either side.

Therefore, both WebSocket-based and Socket-based approaches can be used to develop IM/social chat apps.

## V. What Open-Source WebSocket and Socket Frameworks Are Available on iOS
Open-source Socket frameworks include: [CocoaAsync*Socket*](https://github.com/robbiehanson/CocoaAsyncSocket), [socketio/*socket*.io-client-swift](https://github.com/socketio/socket.io-client-swift)
Open-source WebSocket frameworks include: [facebook/*Socket*Rocket](https://github.com/facebook/SocketRocket), [tidwall/SwiftWeb*Socket*](https://github.com/tidwall/SwiftWebSocket)

## VI. How to Implement the WebSocket Protocol on iOS   

>Talk is cheap. Show me the code ——Linus Torvalds

Today we will look at the implementation approach used by [facebook/SocketRocket](https://github.com/facebook/SocketRocket)
First, here are some member variables defined by SRWebSocket.
```

@property (nonatomic, weak) id <SRWebSocketDelegate> delegate;
/**
 A dispatch queue for scheduling the delegate calls. The queue doesn't need be a serial queue.

 If `nil` and `delegateOperationQueue` is `nil`, the socket uses main queue for performing all delegate method calls.
 */
@property (nonatomic, strong) dispatch_queue_t delegateDispatchQueue;
/**
 An operation queue for scheduling the delegate calls.

 If `nil` and `delegateOperationQueue` is `nil`, the socket uses main queue for performing all delegate method calls.
 */
@property (nonatomic, strong) NSOperationQueue *delegateOperationQueue;
@property (nonatomic, readonly) SRReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;
@property (nonatomic, readonly) CFHTTPMessageRef receivedHTTPHeaders;
// Optional array of cookies (NSHTTPCookie objects) to apply to the connections
@property (nonatomic, copy) NSArray<NSHTTPCookie *> *requestCookies;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

```
The following are some methods of SRWebSocket.
```

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (instancetype)initWithURLRequest:(NSURLRequest *)request;
- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray<NSString *> *)protocols;
- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;

// Some helper constructors.
- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols;
- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;

// By default, it will schedule itself on +[NSRunLoop SR_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// SRWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;
- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

///--------------------------------------

#pragma mark Send
///--------------------------------------

//Below are 4 send methods
/**
 Send a UTF-8 string or binary data to the server.

 @param message UTF-8 String or Data to send.

 @deprecated Please use `sendString:` or `sendData` instead.
 */
- (void)send:(id)message __attribute__((deprecated("Please use `sendString:` or `sendData` instead.")));
- (void)sendString:(NSString *)string;
- (void)sendData:(NSData *)data;
- (void)sendPing:(NSData *)data;

@end
```
Proxy methods for the five states
```
///--------------------------------------

#pragma mark - SRWebSocketDelegate
///--------------------------------------
@protocol SRWebSocketDelegate <NSObject>

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;

@optional
- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;

// Return YES to convert messages sent as Text to an NSString. Return NO to skip NSData -> NSString conversion for Text messages. Defaults to YES.
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket;
@end
```
The `didReceiveMessage` method must be implemented; it is used to receive messages.

The following four `did` methods correspond to the delegate methods for the `Open`, `Fail`, `Close`, and `ReceivePong` states, respectively.

That’s all for the methods above. Now let’s take a look at how the code is actually written.

First, initialize the WebSocket connection. Note that there must be one and only one `ws://` or `wss://` connection here; this is required by the WebSocket protocol.
```
    self.ws = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@:%zd/ws", serverProto, serverIP, serverPort]]]];
    self.ws.delegate = delegate;
    [self.ws open];
```
Send a message
```
    [self.ws send:message];
```
Receiving Messages and Three Other Delegate Methods
```
//This is the delegate method for receiving messages; it receives data returned by the server, so data processing and storage should be handled here.
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSDictionary *data = [NetworkUtils decodeData:message];
    if (!data)
        return;
}

//This is the delegate method after the WebSocket has just opened. Like WeChat showing "Connecting" while connecting; once connected, it stops showing it, so the code to dismiss the connecting indicator should be written here.
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    // Open = silent ping
    [self.ws receivedPing];
}

//This is the delegate method for closing the WebSocket
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self failedConnection:NSLS(Disconnected)];
}

//This is the method called when the WebSocket connection fails; reconnection logic is usually written here
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self failedConnection:NSLS(Disconnected)];
}
```

## In Closing
That’s all I wanted to share about WebSocket. If there are any mistakes in this article, please feel free to point them out! For apps that don’t have a user base as large as WeChat or QQ, WebSocket should generally be sufficient for building IM/social chat features. Once the user base reaches the hundreds-of-millions level, there are likely many more things to optimize, such as performance and so on.

 
Finally, WeChat and QQ may not be implemented as simply as just using WebSocket and Socket. They may have developed their own solution—one that can support such a massive user base and large-scale data, with optimizations across the board. If any experts who have worked on WeChat or QQ happen to read this article, please leave a comment and share how you implemented it. You’re also welcome to share your experience with us so we can all learn together! Thanks in advance for your guidance!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_weixin\_qq\_websocket/](https://halfrost.com/ios_weixin_qq_websocket/)