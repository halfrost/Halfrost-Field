# 微信,QQ这类IM app怎么做——谈谈Websocket

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-324588e5f12ae955.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## 前言
关于我和WebSocket的缘：我从大二在计算机网络课上听老师讲过之后，第一次使用就到了毕业之后的第一份工作。直到最近换了工作，到了一家是含有IM社交聊天功能的app的时候，我觉得我现在可以谈谈我对WebSocket/Socket的一些看法了。要想做IM聊天app，就不得不理解WebSocket和Socket的原理了，听我一一道来。


## 目录
- 1.WebSocket使用场景
- 2.WebSocket诞生由来
- 3.谈谈WebSocket协议原理
- 4.WebSocket 和 Socket的区别与联系
- 5.iOS平台有哪些WebSocket和Socket的开源框架
- 6.iOS平台如何实现WebSocket协议   


## 一.WebSocket的使用场景

**1.社交聊天**  

最著名的就是微信，QQ，这一类社交聊天的app。这一类聊天app的特点是低延迟，高即时。即时是这里面要求最高的，如果有一个紧急的事情，通过IM软件通知你，假设网络环境良好的情况下，这条message还无法立即送达到你的客户端上，紧急的事情都结束了，你才收到消息，那么这个软件肯定是失败的。

**2.弹幕**  
说到这里，大家一定里面想到了A站和B站了。确实，他们的弹幕一直是一种特色。而且弹幕对于一个视频来说，很可能弹幕才是精华。发弹幕需要实时显示，也需要和聊天一样，需要即时。

**3.多玩家游戏**  

**4.协同编辑**  

现在很多开源项目都是分散在世界各地的开发者一起协同开发，此时就会用到版本控制系统，比如Git，SVN去合并冲突。但是如果有一份文档，支持多人实时在线协同编辑，那么此时就会用到比如WebSocket了，它可以保证各个编辑者都在编辑同一个文档，此时不需要用到Git，SVN这些版本控制，因为在协同编辑界面就会实时看到对方编辑了什么，谁在修改哪些段落和文字。

**5.股票基金实时报价**  
金融界瞬息万变——几乎是每毫秒都在变化。如果采用的网络架构无法满足实时性，那么就会给客户带来巨大的损失。几毫秒钱股票开始大跌，几秒以后才刷新数据，一秒钟的时间内，很可能用户就已经损失巨大财产了。

**6.体育实况更新**  
全世界的球迷，体育爱好者特别多，当然大家在关心自己喜欢的体育活动的时候，比赛实时的赛况是他们最最关心的事情。这类新闻中最好的体验就是利用Websocket达到实时的更新！

**7.视频会议/聊天**  
视频会议并不能代替和真人相见，但是他能让分布在全球天涯海角的人聚在电脑前一起开会。既能节省大家聚在一起路上花费的时间，讨论聚会地点的纠结，还能随时随地，只要有网络就可以开会。

**8.基于位置的应用**  
越来越多的开发者借用移动设备的GPS功能来实现他们基于位置的网络应用。如果你一直记录用户的位置(比如运行应用来记录运动轨迹)，你可以收集到更加细致化的数据。

**9.在线教育**  
在线教育近几年也发展迅速。优点很多，免去了场地的限制，能让名师的资源合理的分配给全国各地想要学习知识的同学手上，Websocket是个不错的选择，可以视频聊天、即时聊天以及其与别人合作一起在网上讨论问题...

**10.智能家居**  
这也是我一毕业加入的一个伟大的物联网智能家居的公司。考虑到家里的智能设备的状态必须需要实时的展现在手机app客户端上，毫无疑问选择了Websocket。

**11.总结**  
从上面我列举的这些场景来看，一个共同点就是，高实时性！

## 二.WebSocket诞生由来

1.**最开始的轮询Polling阶段**
![](http://upload-images.jianshu.io/upload_images/1194012-ce4df238336909a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这种方式下，是不适合获取实时信息的，客户端和服务器之间会一直进行连接，每隔一段时间就询问一次。客户端会轮询，有没有新消息。这种方式连接数会很多，一个接受，一个发送。而且每次发送请求都会有Http的Header，会很耗流量，也会消耗CPU的利用率。

2.**改进版的长轮询Long polling阶段**

![](http://upload-images.jianshu.io/upload_images/1194012-6ca608d5a37095e6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

长轮询是对轮询的改进版，客户端发送HTTP给服务器之后，有没有新消息，如果没有新消息，就一直等待。当有新消息的时候，才会返回给客户端。在某种程度上减小了网络带宽和CPU利用率等问题。但是这种方式还是有一种弊端：例如假设服务器端的数据更新速度很快，服务器在传送一个数据包给客户端后必须等待客户端的下一个Get请求到来，才能传递第二个更新的数据包给客户端，那么这样的话，客户端显示实时数据最快的时间为2×RTT（往返时间），而且如果在网络拥塞的情况下，这个时间用户是不能接受的，比如在股市的的报价上。另外，由于http数据包的头部数据量往往很大（通常有400多个字节），但是真正被服务器需要的数据却很少（有时只有10个字节左右），这样的数据包在网络上周期性的传输，难免对网络带宽是一种浪费。

3.**WebSocket诞生**

现在急需的需求是能支持客户端和服务器端的双向通信，而且协议的头部又没有HTTP的Header那么大，于是，Websocket就诞生了！

![](http://upload-images.jianshu.io/upload_images/1194012-b88b2623a2e4a8ea.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图就是Websocket和Polling的区别，从图中可以看到Polling里面客户端发送了好多Request，而下图，只有一个Upgrade，非常简洁高效。至于消耗方面的比较就要看下图了

![](http://upload-images.jianshu.io/upload_images/1194012-f1f91e25b9635701.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上图中，我们先看蓝色的柱状图，是Polling轮询消耗的流量，这次测试，HTTP请求和响应头信息开销总共包括871字节。当然每次测试不同的请求，头的开销不同。这次测试都以871字节的请求来测试。

**Use case A**: 1,000 clients polling every second: Network throughput is (871 x 1,000) = 871,000 bytes = 6,968,000 bits per second (6.6 Mbps)  
**Use case B**: 10,000 clients polling every second: Network throughput is (871 x 10,000) = 8,710,000 bytes = 69,680,000 bits per second (66 Mbps)  
**Use case C**: 100,000 clients polling every 1 second: Network throughput is (871 x 100,000) = 87,100,000 bytes = 696,800,000 bits per second (665 Mbps)  
而Websocket的Frame是 just two bytes of overhead instead of 871，仅仅用2个字节就代替了轮询的871字节！

**Use case A**: 1,000 clients receive 1 message per second: Network throughput is (2 x 1,000) = 2,000 bytes = 16,000 bits per second (0.015 Mbps)  
**Use case B**: 10,000 clients receive 1 message per second: Network throughput is (2 x 10,000) = 20,000 bytes = 160,000 bits per second (0.153 Mbps)  
**Use case C**: 100,000 clients receive 1 message per second: Network throughput is (2 x 100,000) = 200,000 bytes = 1,600,000 bits per second (1.526 Mbps)    

相同的每秒客户端轮询的次数，当次数高达10W/s的高频率次数的时候，Polling轮询需要消耗665Mbps，而Websocket仅仅只花费了1.526Mbps，将近435倍！！



## 三.谈谈WebSocket协议原理
Websocket是应用层第七层上的一个应用层协议，它必须依赖 [HTTP 协议进行一次握手](http://tools.ietf.org/html/rfc6455#section-4) ，握手成功后，数据就直接从 TCP 通道传输，与 HTTP 无关了。

Websocket的数据传输是frame形式传输的，比如会将一条消息分为几个frame，按照先后顺序传输出去。这样做会有几个好处：

1 大数据的传输可以分片传输，不用考虑到数据大小导致的长度标志位不足够的情况。
2 和http的chunk一样，可以边生成数据边传递消息，即提高传输效率。

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



    FIN      1bit 表示信息的最后一帧，flag，也就是标记符
    RSV 1-3  1bit each 以后备用的 默认都为 0
    Opcode   4bit 帧类型，稍后细说
    Mask     1bit 掩码，是否加密数据，默认必须置为1 （这里很蛋疼）
    Payload  7bit 数据的长度
    Masking-key      1 or 4 bit 掩码
    Payload data     (x + y) bytes 数据
    Extension data   x bytes  扩展数据
    Application data y bytes  程序数据
```

具体的规范，还请看官网的[RFC 6455](https://tools.ietf.org/html/rfc6455)文档给出的详细定义。这里还有一个[翻译版本](https://www.gitbook.com/book/chenjianlong/rfc-6455-websocket-protocol-in-chinese/details)

## 四.WebSocket 和 Socket的区别与联系

首先，[Socket](http://en.wikipedia.org/wiki/Network_socket) 其实并不是一个协议。它工作在 OSI 模型会话层（第5层），是为了方便大家直接使用更底层协议（一般是 [TCP](http://en.wikipedia.org/wiki/Transmission_Control_Protocol) 或 [UDP](http://en.wikipedia.org/wiki/User_Datagram_Protocol) ）而存在的一个抽象层。Socket是对TCP/IP协议的封装，Socket本身并不是协议，而是一个调用接口(API)。


![](http://upload-images.jianshu.io/upload_images/1194012-d35653654be833ae.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Socket通常也称作”套接字”，用于描述IP地址和端口，是一个通信链的句柄。网络上的两个程序通过一个双向的通讯连接实现数据的交换，这个双向链路的一端称为一个Socket，一个Socket由一个IP地址和一个端口号唯一确定。应用程序通常通过”套接字”向网络发出请求或者应答网络请求。

Socket在通讯过程中，服务端监听某个端口是否有连接请求，客户端向服务端发送连接请求，服务端收到连接请求向客户端发出接收消息，这样一个连接就建立起来了。客户端和服务端也都可以相互发送消息与对方进行通讯，直到双方连接断开。

所以基于WebSocket和基于Socket都可以开发出IM社交聊天类的app

## 五.iOS平台有哪些WebSocket和Socket的开源框架
Socket开源框架有：[CocoaAsync*Socket*](https://github.com/robbiehanson/CocoaAsyncSocket)，[socketio/*socket*.io-client-swift](https://github.com/socketio/socket.io-client-swift)
WebSocket开源框架有:[facebook/*Socket*Rocket](https://github.com/facebook/SocketRocket)，[tidwall/SwiftWeb*Socket*](https://github.com/tidwall/SwiftWebSocket)

## 六.iOS平台如何实现WebSocket协议   

>Talk is cheap。Show me the code ——Linus Torvalds

我们今天来看看[facebook/SocketRocket](https://github.com/facebook/SocketRocket)的实现方法
首先这是SRWebSocket定义的一些成员变量

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


下面这些是SRWebSocket的一些方法

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

//下面是4个发送的方法
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

对应5种状态的代理方法

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

didReceiveMessage方法是必须实现的，用来接收消息的。
下面4个did方法分别对应着Open，Fail，Close，ReceivePong不同状态的代理方法


方法就上面这些了，我们实际来看看代码怎么写

先是初始化Websocket连接，注意此处ws://或者wss://连接有且最多只能有一个，这个是Websocket协议规定的

```
    self.ws = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@:%zd/ws", serverProto, serverIP, serverPort]]]];
    self.ws.delegate = delegate;
    [self.ws open];
```

发送消息

```
    [self.ws send:message];
```

接收消息以及其他3个代理方法

```
//这个就是接受消息的代理方法了，这里接受服务器返回的数据，方法里面就应该写处理数据，存储数据的方法了。
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSDictionary *data = [NetworkUtils decodeData:message];
    if (!data)
        return;
}

//这里是Websocket刚刚Open之后的代理方法。就想微信刚刚连接中，会显示连接中，当连接上了，就不显示连接中了，取消显示连接的方法就应该写在这里面
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    // Open = silent ping
    [self.ws receivedPing];
}

//这是关闭Websocket的代理方法
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self failedConnection:NSLS(Disconnected)];
}

//这里是连接Websocket失败的方法，这里面一般都会写重连的方法
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self failedConnection:NSLS(Disconnected)];
}
```

## 最后
以上就是我想分享的一些关于Websocket的心得，文中如果有错误的地方，欢迎大家指点！一般没有微信QQ那么大用户量的app，用Websocket应该都可以完成IM社交聊天的任务。当用户达到亿级别，应该还有很多需要优化，优化性能各种的吧。

 
最后，微信和QQ的实现方法也许并不是只用Websocket和Socket这么简单，也许是他们自己开发的一套能支持这么大用户，大数据的，各方面也都优化都最优的方法。如果有开发和微信和QQ的大神看到这篇文章，可以留言说说看你们用什么方式实现的，也可以和我们一起分享，我们一起学习！我先谢谢大神们的指点了！




> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_weixin\_qq\_websocket/](https://halfrost.com/ios_weixin_qq_websocket/)