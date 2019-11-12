<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/124_0.png'>
</p>

# 解开 HTTP/2 的面纱：HTTP/2 是如何建立连接的


超文本传输协议(HTTP)是一种非常成功的协议。 但是，HTTP/1.1 使用底层传输的方式([[RFC7230]，第 6 节](https://tools.ietf.org/html/rfc7230#section-6))，其中有几个特性对今天的应用程序性能有负面影响。

特别是，HTTP/1.0 在给定的 TCP 连接上一次只允许一个请求未完成。HTTP/1.1 添加了请求流水线操作(request pipelining)，但这只是部分地解决了请求并发性，并且仍然受到**队首阻塞**的影响。因此，需要发出许多请求的 HTTP/1.0 和 HTTP/1.1 客户端使用多个连接到服务器以实现并发，从而减少延迟。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/124_4.jpg'>
</p>


此外，HTTP 头字段通常是重复且冗长的，导致不必要的网络流量以及导致初始 [TCP](https://tools.ietf.org/html/rfc7540#ref-TCP) 拥塞窗口被快速的填满。当在新的 TCP 连接上发出多个请求时，这可能导致过多的延迟。

HTTP/2 通过定义了一个优化过的 HTTP 语义，它与底层连接映射，用这种方式来解决这些问题。具体而言，它允许在同一连接上交错请求和响应消息，并使用 HTTP 头字段的有效编码。它还允许对请求进行优先级排序，使更多重要请求更快地完成，从而进一步提高性能。

HTTP/2 对网络更友好，因为与 HTTP/1.x 相比，可以使用更少的 TCP 连接。这意味着与其他流量和长连接的竞争减少，反过来可以更好地利用可用网络容量。最后，HTTP/2 还可以通过使用二进制消息帧来更有效地处理消息。

>HTTP/2 最大限度的兼容 HTTP/1.1 原有行为：  
>1. 在应用层上修改，基于并充分挖掘 TCP 协议性能。
>2. 客户端向服务端发送 request 请求的模型没有变化。
>3. scheme 没有发生变化，没有 http2://
>4. 使用 HTTP/1.X 的客户端和服务器可以无缝的通过代理方式转接到 HTTP/2 上。
>5. 不识别 HTTP/2 的代理服务器可以将请求降级到 HTTP/1.X。



## 一. HTTP/2 Protocol Overview


![](https://img.halfrost.com/Blog/ArticleImage/129_5.png)


HTTP/2 为 HTTP 语义提供了优化的传输。 HTTP/2 支持 HTTP/1.1 的所有核心功能，但旨在通过多种方式提高效率。

HTTP/2 中的基本协议单元是一个帧([第 4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F))。每种帧类型都有不同的用途。例如，HEADERS 和 DATA 帧构成了 HTTP 请求和响应的基础([第 8.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange))；其他帧类型(如 SETTINGS，WINDOW\_UPDATE 和 PUSH\_PROMISE)用于支持其他 HTTP/2 功能。

> HTTP/2 是一个彻彻底底的二进制协议，头信息和数据包体都是二进制的，统称为“帧”。对比 HTTP/1.1 ，在 HTTP/1.1 中，头信息是文本编码(ASCII编码)，数据包体可以是二进制也可以是文本。使用二进制作为协议实现方式的好处，更加灵活。在 HTTP/2 中定义了 10 种不同类型的帧。
>



通过使每个 HTTP 请求/响应交换与其自己的 stream 流相关联来实现请求的多路复用([第 5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA))。stream 流在很大程度上是彼此独立的，因此阻塞或停止的请求或响应不会阻止其他 stream 流的通信。

>由于 HTTP/2 的数据包是乱序发送的，因此在同一个连接里会收到不同请求的 response。不同的数据包携带了不同的标记，用来标识它属于哪个 response。
>
>HTTP/2 把每个 request 和 response 的数据包称为一个数据流(stream)。每个数据流都有自己全局唯一的编号。每个数据包在传输过程中都需要标记它属于哪个数据流 ID。规定，客户端发出的数据流，ID 一律为奇数，服务器发出的，ID 为偶数。
>
>数据流在发送中的任意时刻，客户端和服务器都可以发送信号(RST\_STREAM 帧)，取消这个数据流。HTTP/1.1 中想要取消数据流的唯一方法，就是关闭 TCP 连接。而 HTTP/2 可以取消某一次请求，同时保证 TCP 连接还打开着，可以被其他请求使用。
>

流量控制和优先级确保可以有效地使用多路复用流。流量控制([第 5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6))有助于确保只传输接收者可以使用的数据。确定优先级([第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))可确保首先将有限的资源定向到最重要的流。

HTTP/2 添加了一种新的交互模式，服务器可以将响应推送到客户端([第 8.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push))。服务器推送允许服务器推测性地将数据发送到服务器预测客户端将需要这些数据的客户端，通过牺牲一些网络流量来抵消潜在的延迟。服务器通过合成请求来完成此操作，并将其作为 PUSH\_PROMISE 帧发送。然后，服务器能够在单独的流上发送对合成请求的响应。

由于连接中使用的 HTTP 头字段可能包含大量冗余数据，因此压缩包含它们的帧([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。允许将许多请求压缩成一个分组的做法对于通常情况下的请求大小具有特别有利的影响。


>HTTP 协议不带有状态，每次请求都必须附上所有信息。所以，请求的很多字段都是重复的，比如 Cookie 和 User Agent，每次请求即使是完全一样的内容，依旧必须每次都携带，这会浪费很多带宽，也影响速度。HTTP/1.1 虽然可以压缩请求体，但是不能压缩消息头。有时候消息头部很大。
>
>HTTP/2 对这一点做了优化，引入了头信息压缩机制(header compression)。一方面，头信息使用 gzip 或 compress 压缩后再发送；另一方面，客户端和服务器同时维护一张头信息表，所有字段都会存入这个表，生成一个索引号，以后就不发送同样字段了，只发送索引号，这样就提高速度了。 
> 
>头部压缩大概可能有 95% 左右的提升，HTTP/1.1 统计的平均响应头大小有 500 个字节左右，而 HTTP/2 的平均响应头大小只有 20 多个字节，提升比较大。



![](https://img.halfrost.com/Blog/ArticleImage/129_1.png)



接下来分 4 部分详细讨论 HTTP/2。

- 解开 HTTP/2 的面纱：HTTP/2 是如何建立连接的([第三章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#1-http2-version-identification))
- 帧([第四章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F))和流([第五章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA))层描述了 HTTP/2 帧的结构和形成多路复用流的方式。
- 帧([第六章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7))和错误([第七章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes))定义了包括 HTTP/2 中使用的帧和错误类型的详细信息。
- HTTP 映射([第八章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange))和附加要求([第九章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E7%AE%A1%E7%90%86))描述了如何使用帧和流表示 HTTP 语义。

虽然一些帧层和流层概念与 HTTP 隔离，但是该规范没有定义完全通用的帧层。帧层和流层是根据 HTTP 协议和服务器推送的需要而定制的。

## 二. Starting HTTP/2

HTTP/2 连接是在 TCP 连接([TCP](https://tools.ietf.org/html/rfc7540#ref-TCP))之上运行的应用层协议。客户端是 TCP 连接发起者。

HTTP/2 使用 HTTP/1.1 使用的相同 "http" 和 "https" URI scheme。HTTP/2 共享相同的默认端口号: "http" URI 为 80，"https" URI 为 443。因此，需要处理对目标资源 URI (例如 "[http://example.org/foo](http://example.org/foo)" 或 "[https://example.com/bar](https://example.com/bar)")的请求的实现，首先需要发现上游服务器(客户端希望建立连接的直接对等方)是否支持 HTTP/2。

对于 "http" 和 "https" URI，确定支持 HTTP/2 的方式是不同的。"http" URI 的发现在 [3.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#2-starting-http2-for-http-uris)中描述。[第 3.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#4-starting-http2-for-https-uris)描述了 "https" URI 的发现。


### 1. HTTP/2 Version Identification

本文档中定义的协议有两个标识符。

- 字符串 "h2" 标识 HTTP/2 使用传输层安全性(TLS)[TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12)的协议。该标识符用于 TLS 应用层协议协商(ALPN)扩展[TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN)字段以及识别 HTTP/2 over TLS 的任何地方。

"h2"字符串被序列化为 ALPN 协议标识符，作为两个八位字节序列：0x68,0x32。

- 字符串 "h2c" 标识通过明文 TCP 运行 HTTP/2 的协议。此标识符用于 HTTP/1.1 升级标头字段以及标识 HTTP/2 over TCP 的任何位置。

"h2c" 字符串是从 ALPN 标识符空间保留的，但描述了不使用 TLS 的协议。协商 "h2" 或 "h2c" 意味着使用本文档中描述的传输，安全性，成帧和消息语义。

### 2. Starting HTTP/2 for "http" URIs

在没有关于下一跳支持 HTTP/2 的 prior knowledge 的情况下请求 "http" URI 的客户端使用 HTTP 升级机制([[RFC7230]的第 6.7 节](https://tools.ietf.org/html/rfc7230#section-6.7))。客户端通过发出包含带有 "h2c" 标记的 Upgrade 头字段的HTTP/1.1 请求来完成此操作。这样的 HTTP/1.1 请求必须包含一个 HTTP2-Settings([第 3.2.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#3-http2-settings-header-field))头字段。

例如：

```c
     GET / HTTP/1.1
     Host: server.example.com
     Connection: Upgrade, HTTP2-Settings
     Upgrade: h2c
     HTTP2-Settings: <base64url encoding of HTTP/2 SETTINGS payload>
```

在客户端可以发送 HTTP/2 帧之前，必须完整地发送包含有效负载主体的请求。这意味着大型请求可以阻止连接的使用，直到完全发送为止。

如果初始请求与后续请求的并发性很重要，则可以使用 OPTIONS 请求执行升级到 HTTP/2，但需要额外的往返。不支持 HTTP/2 的服务器可以响应请求，就像没有 Upgrade 头字段一样：

```c
     HTTP/1.1 200 OK
     Content-Length: 243
     Content-Type: text/html

     ...
```

服务器必须忽略 Upgrade 头字段中的 "h2" 标记。具有 "h2" 的令牌的存在意味着 HTTP/2 over TLS，这种方式替代[ 3.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#4-starting-http2-for-https-uris)中所述协商过程。


支持 HTTP/2 的服务器通过 101(交换协议)响应接受升级。在响应 101 末尾的空行之后，服务器可以开始发送 HTTP/2 帧。这些帧必须包括对启动升级的请求的响应。

例如：

```c
     HTTP/1.1 101 Switching Protocols
     Connection: Upgrade
     Upgrade: h2c

     [ HTTP/2 connection ...
```

服务器发送的第一个 HTTP/2 帧必须是由 SETTINGS 帧([第 6.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7))组成的服务器连接前奏([第 3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))。收到 101 响应后，客户端必须发送连接前奏([第3.5节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))，其中包括 SETTINGS 帧。

在升级之前发送的 HTTP/1.1 请求被赋予 stream 流标识符 1 (参见[第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6))，它是默认优先级值([第 5.3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7))。Stream 流 1 从客户端隐式"半封闭"的流向服务器(参见[第5.1节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA))，因为请求是作为 HTTP/1.1 请求完成的。在开始 HTTP/2 连接之后，stream 流 1 用于响应。

### 3. HTTP2-Settings Header Field

从 HTTP/1.1 升级到 HTTP/2 的请求必须包含一个 "HTTP2-Settings" 头字段。HTTP2-Settings 标头字段是一个特定于连接的 header 字段，其中包含管理 HTTP/2 连接的参数，这个参数在服务器接受升级请求的情况下提供的。


```c
     HTTP2-Settings    = token68
```

如果此 header 字段不存在或存在多个连接，则服务器不得升级到 HTTP/2 的连接。服务器不得发送此 header 字段。

HTTP2-Settings 头字段的内容是 SETTINGS 帧的有效负载([第 6.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7))，编码为 base64url 字符串(即[[RFC4648]第 5 节](https://tools.ietf.org/html/rfc4648#section-5)中描述的 URL 和文件名安全的 Base64 编码，省略任何尾随的 '=' 字符)。ABNF [RFC5234](https://tools.ietf.org/html/rfc5234) 生成 "token68" 在 [[RFC7235]的第 2.1 节](https://tools.ietf.org/html/rfc7235#section-2.1)中定义。

由于升级仅用于立即连接，因此发送 HTTP2-Settings header 字段的客户端也必须在 Connection 头字段中发送 "HTTP2-Settings" 作为连接选项，以防止它被转发(参见[[RFC7230]中的第 6.1 节](https://tools.ietf.org/html/rfc7230#section-6.1)）。

服务器解码并解释这些值，就像任何其他 SETTINGS 帧一样。不必明确确认这些设置([第 6.5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-settings-synchronization)），因为 101 响应用作隐式确认。在升级请求中提供这些值，目的的为了使客户端有机会在从服务器接收任何帧之前提供参数。


### 4. Starting HTTP/2 for "https" URIs

向 "https" URI发出请求的客户端使用 TLS [TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12) 和应用层协议协商(ALPN)扩展 [TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN)。

HTTP/2 over TLS 使用 "h2" 协议标识符。"h2c" 协议标识符不得由客户端发送或由服务器选择; "h2c" 协议标识符描述了一个不使用 TLS 的协议。

一旦 TLS 协商完成，客户端和服务器都必须发送连接前奏([第 3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))。


### 5. Starting HTTP/2 with Prior Knowledge

客户端可以通过其他方式了解特定服务器是否支持 HTTP/2。例如，[ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC) 描述了一种可以获得服务器是否支持 HTTP/2 的机制。

客户端必须发送连接前奏([第 3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))，然后可以立即将 HTTP/2 帧发送到服务器; 服务器可以通过连接前奏的存在来识别这些连接。这只影响通过明文 TCP 建立 HTTP/2 连接; 通过 TLS 支持 HTTP/2 的实现必须在 TLS [TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN) 中使用协议协商。同样，服务器必须发送连接前奏([第3.5节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))。

如果没有其他信息，先前对 HTTP/2 的支持并不是一个强信号，即给定服务器将支持 HTTP/2 以用于将来的连接。例如，可以更改服务器配置，使群集服务器中的实例之间的配置不同，或者更改网络条件。


### 6. HTTP/2 Connection Preface

> "连接前奏" 有些地方也会翻译成 "连接序言"。

在 HTTP/2 中，每个端点都需要发送连接前奏作为正在使用的协议的最终确认，并建立 HTTP/2 连接的初始设置。客户端和服务器各自发送不同的连接前奏。

客户端连接前奏以 24 个八位字节的序列开始，以十六进制表示法为：

```c
     0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
```

也就是说，连接前奏以字符串 "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n" 开头。该序列必须后跟 SETTINGS 帧([第 6.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7))，该帧可以为空。客户端在收到 101 (交换协议)响应(指示成功升级)或作为 TLS 连接的第一个应用程序数据八位字节后立即发送客户端连接前奏。如果启动具有服务器对协议支持的 prior knowledge 的 HTTP/2 连接，则在建立连接时发送客户端连接前奏。

>注意：选择客户端连接前奏，以便大部分 HTTP/1.1 或 HTTP/1.0 服务器和中间件不会尝试处理更多帧。请注意，这并未解决 [TALKING](https://tools.ietf.org/html/rfc7540#ref-TALKING) 中提出的问题。

>连接前奏里面的字符串连起来是 PRISM ，这个单词的意思是“棱镜”，就是 2013 年斯诺登爆出的“棱镜计划”。

服务器连接前奏包含一个可能为空的 SETTINGS 帧([第 6.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7))，该帧必须是服务器在 HTTP/2 连接中发送的第一帧。

作为连接前奏的一部分从对等端收到的 SETTINGS 帧，必须在发送连接前奏后得到确认(参见[6.5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-settings-synchronization))。

为避免不必要的延迟，允许客户端在发送客户端连接前奏后立即向服务器发送其他帧，而无需等待接收服务器连接前奏。但是，需要注意的是，服务器连接前奏 SETTINGS 帧可能包含参数，这些参数是客户端希望与服务器通信时必须的参数。在接收到 SETTINGS 帧后，客户端应该遵守所建立的任何参数。在某些配置中，服务器可以在客户端发送附加帧之前发送 SETTINGS，从而提供避免此问题的机会。

客户端和服务器必须将无效的连接前奏视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。在这种情况下可以省略 GOAWAY 帧([第 6.8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7))，因为无效的连接前奏表明对等方没有使用 HTTP/2。

最后，我们抓包看一下 HTTP/2 over TLS 是如何建立连接的。当 TLS 握手结束以后(TLS 握手的流程这里暂时省略，想要了解的同学可以看这里的[系列文章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md))，客户端和服务端已经通过 ALPN 协商出了接下来应用层使用 HTTP/2 协议进行通信，于是会见到类似如下的抓包图：

![](https://img.halfrost.com/Blog/ArticleImage/124_1.png)

可以看到在 TLS 1.3 Finished 消息之后，紧接着就是 HTTP/2 的连接序言，Magic 帧。

![](https://img.halfrost.com/Blog/ArticleImage/124_2_0.png)

客户端连接前奏以 24 个八位字节的序列开始，以十六进制表示法为：

```c
     0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
```

连接前奏就是字符串 "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n" 开头。Magic 帧之后紧跟着 SETTINGS 帧。当服务端成功 ack 了这条消息，并且没有连接报错，那么 HTTP/2 协议就算连接建立完成了。

------------------------------------------------------

Reference：  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2\_begin/](https://halfrost.com/http2_begin/)