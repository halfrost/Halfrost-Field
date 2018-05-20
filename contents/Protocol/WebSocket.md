<p align='center'>
<img src='../images/websocket.png'>
</p>


# 全双工通信的 WebSocket


## 一. WebSocket 是什么？

WebSocket 是一种网络通信协议。2011年被 IETF 定为标准 RFC 6455 通信标准。并由  RFC7936 补充规范。WebSocket API 也被 W3C 定为标准。

WebSocket 是 HTML5 开始提供的一种在单个 TCP 连接上进行**全双工通讯的协议**。没有了  Request 和 Response 的概念，两者地位完全平等，连接一旦建立，就建立了真•持久性连接，双方可以随时向对方发送数据。


(HTML5 是 HTML 最新版本，包含一些新的标签和全新的 API。HTTP 是一种协议，目前最新版本是 HTTP/2 ，所以 WebSocket 和 HTTP 有一些交集，两者相异的地方还是很多。两者交集的地方在 HTTP 握手阶段，握手成功后，数据就直接从 TCP 通道传输。)

## 二. 为什么要发明 WebSocket ？


在没有 WebSocket 之前，Web 为了实现即时通信，有以下几种方案，最初的 polling ，到之后的 Long polling，最后的基于 streaming 方式，再到最后的 SSE，也是经历了几个不种的演进方式。


## (1) 最开始的短轮询 Polling 阶段 

![](https://ob6mci30g.qnssl.com/Blog/ArticleImage/8_2.png)

这种方式下，是不适合获取实时信息的，客户端和服务器之间会一直进行连接，每隔一段时间就询问一次。客户端会轮询，有没有新消息。这种方式连接数会很多，一个接受，一个发送。而且每次发送请求都会有 HTTP 的 Header，会很耗流量，也会消耗 CPU 的利用率。

这个阶段可以看到，一个 Request 对应一个 Response，一来一回一来一回。

在 Web 端，短轮询用 Ajax JSONP Polling 轮询实现。

由于 HTTP 无法无限时长的保持连接，所以不能在服务器和 Web 浏览器之间频繁的长时间进行数据推送，所以 Web 应用通过通过频繁的异步 JavaScript 和 XML (AJAX) 请求来实现轮循。


<p align='center'>
<img src='../images/ajax-polling.png'>
</p>

- 优点：短连接，服务器处理简单，支持跨域、浏览器兼容性较好。
- 缺点：有一定延迟、服务器压力较大，浪费带宽流量、大部分是无效请求。


## (2) 改进版的长轮询 Long polling 阶段（Comet Long polling）

![](https://ob6mci30g.qnssl.com/Blog/ArticleImage/8_3.png)

长轮询是对轮询的改进版，客户端发送 HTTP 给服务器之后，有没有新消息，如果没有新消息，就一直等待。直到有消息或者超时了，才会返回给客户端。消息返回后，客户端再次建立连接，如此反复。这种做法在某种程度上减小了网络带宽和 CPU 利用率等问题。

这种方式也有一定的弊端，实时性不高。如果是高实时的系统，肯定不会采用这种办法。因为一个 GET 请求来回需要 2个 RTT，很可能在这段时间内，数据变化很大，客户端拿到的数据已经延后很多了。

另外，网络带宽低利用率的问题也没有从根源上解决。每个 Request 都会带相同的 Header。

对应的，Web 也有 AJAX 长轮询，也叫 XHR 长轮询。

客户端打开一个到服务器端的 Ajax 请求，然后等待响应，服务器端需要一些特定的功能来允许请求被挂起，只要一有事件发生，服务器端就会在挂起的请求中送回响应并关闭该请求。客户端在处理完服务器返回的信息后，再次发出请求，重新建立连接，如此循环。

<p align='center'>
<img src='../images/ajax-long-polling.png'>
</p>

- 优点：减少轮询次数，低延迟，浏览器兼容性较好。
- 缺点：服务器需要保持大量连接。

## (3) 基于流（Comet Streaming）

### 1. 基于 Iframe 及 htmlfile 的流（Iframe Streaming）

iframe 流方式是在页面中插入一个隐藏的 iframe，利用其 src 属性在服务器和客户端之间创建一条长链接，服务器向 iframe 传输数据（通常是 HTML，内有负责插入信息的javascript），来实时更新页面。iframe 流方式的优点是浏览器兼容好。

<p align='center'>
<img src='../images/ifream.png'>
</p>

使用 iframe 请求一个长连接有一个很明显的不足之处：IE、Morzilla Firefox 下端的进度栏都会显示加载没有完成，而且 IE 上方的图标会不停的转动，表示加载正在进行。

Google 的天才们使用一个称为 “htmlfile” 的 ActiveX 解决了在 IE 中的加载显示问题，并将这种方法用到了 gmail+gtalk 产品中。Alex Russell 在 “What else is burried down in the depth's of Google's amazing JavaScript?”文章中介绍了这种方法。Zeitoun 网站提供的 comet-iframe.tar.gz，封装了一个基于 iframe 和 htmlfile 的 JavaScript comet 对象，支持 IE、Mozilla Firefox 浏览器，可以作为参考。


- 优点：实现简单，在所有支持 iframe 的浏览器上都可用、客户端一次连接、服务器多次推送。
- 缺点：无法准确知道连接状态，IE浏览器在 iframe 请求期间，浏览器 title 一直处于加载状态，底部状态栏也显示正在加载，用户体验不好（htmlfile 通过  ActiveXObject 动态写入内存可以解决此问题）。


### 2. AJAX multipart streaming（XHR Streaming）

实现思路：浏览器必须支持 multi-part 标志，客户端通过 AJAX 发出请求 Request，服务器保持住这个连接，然后可以通过 HTTP1.1 的 chunked encoding 机制（分块传输编码）不断 push 数据给客户端,直到 timeout 或者手动断开连接。

- 优点：客户端一次连接，服务器数据可多次推送。
- 缺点：并非所有的浏览器都支持 multi-part 标志。


### 3. Flash Socket（Flash Streaming）

实现思路：在页面中内嵌入一个使用了 Socket 类的 Flash 程序，JavaScript 通过调用此 Flash 程序提供的 Socket 接口与服务器端的 Socket 接口进行通信，JavaScript 通过 Flash Socket 接收到服务器端传送的数据。

- 优点：实现真正的即时通信，而不是伪即时。
- 缺点：客户端必须安装 Flash 插件；非 HTTP 协议，无法自动穿越防火墙。


### 4. Server-Sent Events

SSE 就是利用服务器向客户端申明，接下来要发送的是流信息（streaming），会连续不断地发送过来。这时，客户端不会关闭连接，会一直等着服务器发过来的新的数据流，可以类比视频流。SSE 就是利用这种机制，使用流信息向浏览器推送信息。它基于 HTTP 协议，目前除了 IE/Edge，其他浏览器都支持。

SSE 是单向通道，只能服务器向浏览器发送，因为流信息本质上就是下载。

服务器向浏览器发送的 SSE 数据，必须是 UTF-8 编码的文本，具有如下的 HTTP 头信息。

```
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

```

上面三行之中，第一行的Content-Type必须指定 MIME 类型为event-steam

<p align='center'>
<img src='../images/SSE.png'>
</p>

- 优点：适用于更新频繁、低延迟并且数据都是从服务端发到客户端。
- 缺点：浏览器兼容难度高。


<p align='center'>
<img src='../images/SSE_use.png'>
</p>

以上是常见的四种基于流的做法，Iframe Streaming、XHR Streaming、Flash Streaming、Server-Sent Events。

从浏览器兼容难度看 —— 短轮询/AJAX > 长轮询/Comet > 长连接/SSE

## WebSocket 的到来

从上面这几种演进的方式来看，也是不断改进的过程。

短轮询效率低，非常浪费资源（网络带宽和计算资源）。有一定延迟、服务器压力较大，并且大部分是无效请求。

长轮询虽然省去了大量无效请求，减少了服务器压力和一定的网络带宽的占用，但是还是需要保持大量的连接。

最后到了基于流的方式，在服务器往客户端推送，这个方向的流实时性比较好。但是依旧是单向的，客户端请求服务器依然还需要一次 HTTP 请求。

那么人们就在考虑了，有没有这样一个完美的方案，即能双向通信，又可以节约请求的 header 网络开销，并且有更强的扩展性，最好还可以支持二进制帧，压缩等特性呢？

于是人们就发明了这样一个目前看似“完美”的解决方案 —— WebSocket。

在 HTML5 中公布了 WebSocket 标准以后，直接取代了 Comet 成为服务器推送的新方法。

> Comet 是一种用于 web 的推送技术，能使服务器实时地将更新的信息传送到客户端，而无须客户端发出请求，目前有两种实现方式，长轮询和 iframe 流。




<p align='center'>
<img src='../images/websockets-flow-with-client-push.png'>
</p>

- 优点：
- 较少的控制开销，在连接创建后，服务器和客户端之间交换数据时，用于协议控制的数据包头部相对较小。在不包含扩展的情况下，对于服务器到客户端的内容，此头部大小只有2至10字节（和数据包长度有关）；对于客户端到服务器的内容，此头部还需要加上额外的4字节的掩码。相对于 HTTP 请求每次都要携带完整的头部，此项开销显著减少了。
- 更强的实时性，由于协议是全双工的，所以服务器可以随时主动给客户端下发数据。相对于HTTP请求需要等待客户端发起请求服务端才能响应，延迟明显更少；即使是和Comet等类似的长轮询比较，其也能在短时间内更多次地传递数据。
- 长连接，保持连接状态。与HTTP不同的是，Websocket需要先创建连接，这就使得其成为一种有状态的协议，之后通信时可以省略部分状态信息。而HTTP请求可能需要在每个请求都携带状态信息（如身份认证等）。
- 双向通信、更好的二进制支持。与 HTTP 协议有着良好的兼容性。默认端口也是 80 和 443，并且握手阶段采用 HTTP 协议，因此握手时不容易被屏蔽，能通过各种 HTTP 代理服务器。

- 缺点：部分浏览器不支持（支持的浏览器会越来越多）。
应用场景：较新浏览器支持、不受框架限制、较高扩展性。

<p align='center'>
<img src='../images/websocket_use.png'>
</p>

一句话总结一下 WebSocket：

WebSocket 是 HTML5 开始提供的一种**独立**在单个 **TCP** 连接上进行**全双工通讯**的**有状态**的协议(它不同于无状态的 HTTP)，并且还能支持二进制帧、扩展协议、部分自定义的子协议、压缩等特性。


## 三. WebSocket 数据帧


------------------------------------------------------

Reference：  

RFC6455  
[Server-Sent Events 教程](http://www.ruanyifeng.com/blog/2017/05/server-sent_events.html)  
[Comet：基于 HTTP 长连接的“服务器推”技术](https://www.ibm.com/developerworks/cn/web/wa-lo-comet/)


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()