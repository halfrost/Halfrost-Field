<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/130_0.png'>
</p>

# HTTP/2 中的帧定义

在 HTTP/2 的规范中定义了许多帧类型，每个帧类型由唯一的 8 位类型代码标识。每种帧类型在建立和管理整个连接或单个 stream 流中起到不同的作用。

特定的帧类型的传输可以改变连接的状态。如果端点无法维持连接状态的同步视图，则无法在连接内继续成功通信。因此，重要的是端点必须共享的理解状态，在使用了任何给定帧的情况下，这些状态是如何受到它们影响的。


>Connection 连接:1 个 TCP 连接，包含 1 个或者多个 stream。所有通信都在一个 TCP 连接上完成，此连接可以承载任意数量的双向数据流。  
>  
>Stream 数据流：一个双向通信的数据流，包含 1 条或者多条 Message。每个数据流都有一个唯一的标识符和可选的优先级信息，用于承载双向消息。  
>
>Message 消息：对应 HTTP/1.1 中的请求 request 或者响应 response，包含 1 条或者多条 Frame。  
>
>Frame 数据帧：最小通信单位，以二进制压缩格式存放内容。来自不同数据流的帧可以交错发送，然后再根据每个帧头的数据流标识符重新组装。  
>  


![](https://img.halfrost.com/Blog/ArticleImage/130_1.svg)

在  HTTP/1.1 中的一个消息是由 Start Line + header + body 组成的，而 HTTP/2 中一个消息是由 HEADER frame + 若干个 DATA frame 组成的，如下图：

![](https://img.halfrost.com/Blog/ArticleImage/130_2.svg)

HTTP/2 所有性能增强的核心在于新的二进制分帧层，它定义了如何封装 HTTP 消息并在客户端与服务器之间传输。这里所谓的“层”，指的是位于套接字接口与应用可见的高级 HTTP API 之间一个经过优化的新编码机制：HTTP 的语义（包括各种动词、方法、标头）都不受影响，不同的是传输期间对它们的编码方式变了。 HTTP/1.x 协议以换行符作为纯文本的分隔符，而 HTTP/2 将所有传输的信息分割为更小的消息和帧，并采用二进制格式对它们编码。

这样一来，客户端和服务器为了相互理解，都必须使用新的二进制编码机制：HTTP/1.x 客户端无法理解只支持 HTTP/2 的服务器，反之亦然。不过不要紧，现有的应用不必担心这些变化，因为客户端和服务器会替我们完成必要的分帧工作。

## 一. DATA 帧

DATA 帧(类型 = 0x0)可以传输与流相关联的任意可变长度的八位字节序列。例如，使用一个或多个 DATA 帧来承载 HTTP 请求或响应有效载荷。DATA 帧也可以包含填充。可以将填充添加到 DATA 帧用来模糊消息的大小。填充是一种安全的功能；具体见[第 10.7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#7-%E4%BD%BF%E7%94%A8%E5%A1%AB%E5%85%85)。

DATA 帧结构如下：

```c
    +---------------+
    |Pad Length? (8)|
    +---------------+-----------------------------------------------+
    |                            Data (*)                         ...
    +---------------------------------------------------------------+
    |                           Padding (*)                       ...
    +---------------------------------------------------------------+
```

DATA 帧包含以下几个字段:

- Pad Length:    
  一个 8 位字段，包含以八位字节为单位的帧填充长度。该字段是有条件的(如图中的 "?" 所示)，仅在设置了 PADDED 标志时才存在。

- Data:    
  应用数据。在减去存在的其他字段的长度之后，data 的大小是帧有效载荷的剩余部分。

- Padding:    
  填充的八位字节，它不包含应用程序语义值。发送时，填充的八位字必须设置为零。接收方没有义务验证填充，但可以将非零填充视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))
  
DATA 帧定义了以下 flag 标识：

- END\_STREAM (0x1):      
  设置这个字段的时候，位 0 表示该帧是端点为将要发送的标识流的最后一帧。设置此标志会导致流进入"半关闭"状态或者"关闭"状态([第 5.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA))。

- PADDED (0x8):    
  设置这个字段的时候，位 3 表示存在 Pad Length 字段及其描述的任何填充。
  
DATA 帧必须与某一个流相互关联。如果接收到其流标识符字段为 0x0 的 DATA 帧，则接收方必须以 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。

DATA 帧会受到流量控制，只能在流处于“打开”或“半关闭(远程)”状态时发送。整个 DATA 帧有效载荷包含在流量控制中，包括 Pad Length 和 Padding 字段(如果存在)。如果收到的数据帧的流不是“打开”或“半关闭(本地)”状态，则接收方必须以 STREAM\_CLOSED 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。


填充八位字节的总数由填充长度字段的值确定。如果填充的长度是帧有效负载的长度或更长，则接收方必须将其视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

> 注意：通过包含值为零的 Pad Length 字段，可以将帧的大小增加一个八位字节。

data 帧比较简单，抓包看看它的内容：

![](https://img.halfrost.com/Blog/ArticleImage/130_14.png)

上图中可以看到两个 flag 标记位，END\_STREAM 和 PADDED。END\_STREAM 是 false。由于 PADDED 是 false，无填充，所以 Pad Length 是 0。

## 二. HEADERS 帧

HEADERS 帧 (类型 = 0x1) 用于打开一个流([第 5.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA))，另外还带有 header block fragment 头块片段。HEADERS 帧可以在“空闲”，“保留(本地)”，“打开”或“半关闭(远程)”状态的流上发送。此帧专门用来传递 **HTTP header(相当于 HTTP/1.1 中的 start line + header)** 的。

```c
    +---------------+
    |Pad Length? (8)|
    +-+-------------+-----------------------------------------------+
    |E|                 Stream Dependency? (31)                     |
    +-+-------------+-----------------------------------------------+
    |  Weight? (8)  |
    +-+-------------+-----------------------------------------------+
    |                   Header Block Fragment (*)                 ...
    +---------------------------------------------------------------+
    |                           Padding (*)                       ...
    +---------------------------------------------------------------+
```

HEADERS 帧包含以下几个字段:

- Pad Length:    
  一个 8 位字段，包含以八位字节为单位的帧填充长度。仅当设置了 PADDED 标志时，才会出现此字段。
  
- E:  
  一个单位标志，用来标识流依赖是独占的(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。仅当设置了 PRIORITY 标志时，才会出现此字段。

- Stream Dependency:  
  此流所依赖的流的 31 位流标识符(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。仅当设置了 PRIORITY 标志时，才会出现此字段。

- Weight:  
  一个无符号的 8 位整数，表示流的优先级权重(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。这个值代表获得 1 到 256 之间的权重。仅当设置了 PRIORITY 标志时，才会出现此字段。

- Header Block Fragment:  
  头块片段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))
  
- Padding:  
  填充的 8 位字节。
  
HEADERS 帧定义了以下 flag 标识：  

- END\_STREAM (0x1):  
  设置这个字段的时候，位 0 表示 header block ([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))是端点为将要发送的标识流的最后一帧。

HEADERS 帧携带了 END\_STREAM 标志，该标志表示流的结束。但是，设置了 END\_STREAM 标志的 HEADERS 帧后面可以跟着同一个流上的 CONTINUATION 帧。从逻辑上讲，CONTINUATION 帧是 HEADERS 帧的一部分。

- END\_HEADERS (0x4):  
  这个 flag 被设置的时候，位 2 表示该帧包含整个头块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))，并且后面没有任何 CONTINUATION 帧。
  
没有设置 END\_HEADERS 标志的 HEADERS 帧必须后跟相同流的 CONTINUATION 帧。接收方必须将接收任何其他类型的帧或不同流上的帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))


- PADDED (0x8):  
  这个 flag 被设置的时候，位 3 表示 Pad Length 字段及其描述的任何填充都存在。

- PRIORITY (0x20):  
  这个 flag 被设置的时候，位 5 表示存在 Exclusive Flag(E)，Stream Dependency 和 Weight 字段。
  

HEADERS 帧的有效负载包含一个头块片段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。一个 header block 头块如果大于一个 HEADERS 帧，将会在 CONTINUATION 帧中继续传输([第 6.10 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7))。

HEADERS 帧必须与某一个流相关联。如果接收到其流标识符字段为 0x0 的 HEADERS 帧，则接收方必须以 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。HEADERS 帧会更改连接状态，如[第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)所述。

HEADERS 帧可以包含填充段。填充字段和标志与为 DATA 帧定义的字段和标志相同([第 6.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7))。超过头块片段剩余大小的填充必须被视为 PROTOCOL\_ERROR。

HEADERS 帧中的优先级信息在逻辑上等同于单独的 PRIORITY 帧，但是优先级信息包含在 HEADERS 中可避免在创建新流时流优先级流失的可能性。HEADERS 帧中的优先级字段在 stream 流上的第一个 HEADERS 帧之后会重新确定流的优先级([第 5.3.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#3-%E4%BC%98%E5%85%88%E7%BA%A7%E8%B0%83%E6%95%B4))。


抓取一个实际的包看看 HEADERS 帧中有哪些内容。

![](https://img.halfrost.com/Blog/ArticleImage/130_7_0.png)

Flag 里面包含了上面提到的 END\_STREAM、END\_HEADERS、PADDED、PRIORITY 标识。再看看其他字段，Pad Length 由于 PADDED 设置是 false，所以这里没有填充。PRIORITY 设置了值，所以 E 这个单位标志位存在。Stream Dependency 是 0，Stream Indentifer 是 1。Weight 是 255，没有 Padding。 剩下的部分全部都是 Header Block Fragment。如下图：

![](https://img.halfrost.com/Blog/ArticleImage/130_8.png)

在图中可以看到，HTTP/2 中对 HTTP 1.X 中的首部字段的名字做了一些变更。例如 HTTP 1.X 中的 HOST，对应 HTTP/2 中的 :authority:。HTTP 1.X 中的请求行变成了 HTTP/2 中的 :method:、:scheme:、:path:。其他的字段例如 user-agent 虽然名字没有变化，但是存储方式都发生了变化。具体变化在 HPACK 中细讲。

![](https://img.halfrost.com/Blog/ArticleImage/130_9.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_10.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_11.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_12.png)


![](https://img.halfrost.com/Blog/ArticleImage/130_13.png)

上面这连续的 5 张图展示了 HTTP/2 中的 Header Block Fragment 存储方式。从头部字段中可以看出 HTTP/2 全新的存储方式和更高的压缩率。更加详细的分析见 HPACK 详解。

上面的抓包是一个 request 的 HEADERS 帧，再举一个 response 的例子。

![](https://img.halfrost.com/Blog/ArticleImage/130_17.png)

上图中可以看到，HTTP 1.X 中的 response 中的状态行转变成了 HTTP/2 中的 :status:，其他 HTTP 1.X 中的首部字段也相应的在 HEADERS 帧中。

HEADERS 帧会经常使用 Weight 权重字段，例如，不同文件感觉重要性不同，有不同的权重：

![](https://img.halfrost.com/Blog/ArticleImage/130_20_.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_26.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_21_.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_27.png)

上面图中这个例子，html 文件和 woff 字体文件的权重就比 js 文件和 jpg 图片文件的权重高。

同一种类型的文件，也会有权重的高低不同，例如都是 CSS 文件：

![](https://img.halfrost.com/Blog/ArticleImage/130_25.png)

![](https://img.halfrost.com/Blog/ArticleImage/130_28.png)

上面图中这个例子，同样是 css 文件，权重也有不同。


## 三. PRIORITY 帧

PRIORITY 帧(类型 = 0x2)指定了 stream 流的发送方的建议优先级([第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。它可以在任何流的状态下发送，包括空闲或关闭的流。


```c
    +-+-------------------------------------------------------------+
    |E|                  Stream Dependency (31)                     |
    +-+-------------+-----------------------------------------------+
    |   Weight (8)  |
    +-+-------------+
```

PRIORITY 帧包含以下几个字段:

- E:  
  一个单位标志，指示流依赖是独占的(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。
  
- Stream Dependency:  
  此流所依赖的流的 31 位流标识符(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。
  
- Weight:  
  无符号的 8 位整数，表示流的优先级权重(参见[第 5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7))。这个值代表获得 1 到 256 之间的权重。默认权重 16。
  
**PRIORITY 不包含任何 flag 标识**。


PRIORITY 帧始终标识一个流。如果接收到流标识符为 0x0 的 PRIORITY 帧，则接收方必须以 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。

PRIORITY 帧可以在任何状态下在 stream 流上发送，但不能在包含单个头块的连续帧之间发送([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。请注意，此帧可能在处理中或者在帧发送完成后到达，这会导致它对标识的流没有影响。对于处于 "半关闭(远程)" 或 "关闭" 状态的流，该帧只能影响标识的流的处理和它依赖流的处理；它不会影响该流上的帧传输。

可以针对 "空闲" 或 "关闭" 状态的流发送 PRIORITY 帧。这允许通过改变未使用或关闭的父流的优先级来重新确定一组依赖流的优先级。然而，关闭流上发送的优先级帧可能存在被对端忽略的风险，因为对端可能已经丢弃了这个流的优先级状态信息。

长度不超过 5 个八位字节的 PRIORITY 帧必须被视为 FRAME\_SIZE\_ERROR 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)）

![](https://img.halfrost.com/Blog/ArticleImage/130_22_.png)

在上面抓包截图中可以看到，PRIORITY 帧的 Exclusive = true，代表该流的依赖是独占的。Stream Dependency = 49，依赖第 49 号的流。Weight 权重是 219。

## 四. RST\_STREAM 帧

> 在 HTTP 1.X 中，一个连接同一时间内只发送一个请求，如果需要中途中止，直接关闭连接即可。但是在 HTTP/2 中，多个 Stream 会共享同一个连接。如果关闭连接会影响其他的 Stream 流，RST\_STREAM 帧也就出现了，它允许立刻中止一个未完成的流。

RST\_STREAM帧(类型 = 0x3)允许立即终止一个 stream 流。发送 RST\_STREAM 以请求取消一个流或指示已发生错误的情况。

```c
    +---------------------------------------------------------------+
    |                        Error Code (32)                        |
    +---------------------------------------------------------------+
```

RST\_STREAM 帧包含一个无符号的 32 位整数，用于标识错误代码([第 7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes))。错误代码表明了流被终止的原因。

**RST\_STREAM 帧没有定义任何 flag 标志**。

RST\_STREAM 帧完全终止引用的流并使其进入"关闭"状态。在流上接收到 RST\_STREAM 后，接收方不得为该流发送额外的帧，但 PRIORITY 帧除外。但是，在发送 RST\_STREAM 之后，发送端点必须准备好接收和处理在 RST\_STREAM 帧到达之前，可能已经由对端在发送的流上发送的附加帧。

RST\_STREAM 帧必须与流相关联。如果接收到具有流标识符 0x0 的 RST\_STREAM 帧，则接收方必须将其视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

不得为“空闲”状态的流发送 RST\_STREAM 帧。如果接收到标识空闲流的 RST\_STREAM 帧，则接收方必须将其视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。长度不超过 4 个八位字节的 RST\_STREAM 帧必须被视为 FRAME\_SIZE\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


![](https://img.halfrost.com/Blog/ArticleImage/130_15.png)

RST\_STREAM 帧由于没有 flag 标志，是十种帧类型里面比较简单的类型。这里的 Error Code 是 CANCEL (0x8)。

## 五. SETTINGS 帧

SETTINGS 帧(类型 = 0x4)传递影响端点通信方式的配置参数，例如设置对端行为的首选项和约束。SETTINGS 帧还用于确认收到这些参数。单独地，SETTINGS 参数也可以称为"设置"。

**SETTINGS 参数不是通过协商来确定的**；它们描述了发送对端的特征，它们由接收对端使用。相同的参数对不同的对等端设置可能不同。例如，客户端可能会设置较高的初始流量控制窗口，而服务器可能会设置较低的值以节省资源。

SETTINGS 帧必须由两个端点在连接开始时发送，并且可以在任何其他时间由任一端点在连接的生命周期内发送。实现方必须支持 HTTP/2 规范定义的所有参数。

SETTINGS 帧中的每个参数都会替换该参数的任何现有值。参数按它们出现的顺序处理，并且 SETTINGS 帧的接收方不需要保持除其参数的当前值之外的任何状态。因此，SETTINGS 参数的值是接收方看到的最后一个值。

SETTINGS 参数由接收对端确认。要启用此功能，SETTINGS 帧将定义以下标志：

- ACK (0x1):    
  设置这个字段的时候，位 0 表示该帧已经被对等的 SETTINGS 帧的接收和应用。设置此位后，SETTINGS 帧的有效负载必须为空。收到设置了 ACK 标志且长度字段值不为 0 的 SETTINGS 帧必须被视为 FRAME\_SIZE\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。有关更多信息，请参见[第 6.5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-settings-synchronization)(“设置同步”)。

SETTINGS 帧始终适用于连接，而不是作用于单个流。SETTINGS 帧的流标识符必须为零(0x0)。如果端点收到其流标识符字段不是 0x0 的 SETTINGS 帧，则端点必须响应 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

SETTINGS 帧影响连接状态。一个格式错误或不完整的 SETTINGS 帧必须被视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

长度不是 6 个八位字节的 SETTINGS 帧必须被视为 FRAME\_SIZE\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

### 1. SETTINGS Format

SETTINGS 帧的有效负载由零个或多个参数组成，每个参数由无符号 16 位设置标识符和无符号 32 位值组成。

```c
    +-------------------------------+
    |       Identifier (16)         |
    +-------------------------------+-------------------------------+
    |                        Value (32)                             |
    +---------------------------------------------------------------+
```

### 2. Defined SETTINGS Parameters

定义了以下参数：

- SETTINGS\_HEADER\_TABLE\_SIZE(0x1):       
  允许发送方以八位字节通知远程端点用于解码头块的头压缩表的最大大小。编码器可以通过使用特定于报头块内的报头压缩格式的信号来选择等于或小于该值的任何大小(参见[COMPRESSION](https://tools.ietf.org/html/rfc7540#ref-COMPRESSION))。初始值为 4,096 个八位字节。

- SETTINGS\_ENABLE\_PUSH(0x2):    
  此设置可用于禁用服务器推送([第 8.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push))。如果端点接收到此参数设置为 0，则端点绝不能发送 PUSH\_PROMISE 帧。既将该参数设置为 0 并且已将其确认的端点必须将 PUSH\_PROMISE 帧的接收视为 PROTOCOL\_ERROR类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。初始值为 1，表示允许服务器推送。除 0 或 1 以外的任何值必须视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

- SETTINGS\_MAX\_CONCURRENT\_STREAMS(0x3):      
  表示发送方允许的最大并发流数。此限制是有方向性的：它适用于发送方允许接收方创建的流的数量。初始化的时候，此值没有限制。建议此值不小于 100，以免不必要地限制并行性。当 SETTINGS\_MAX\_CONCURRENT\_STREAMS 的值 0 不应被端点视为特殊值。零值确实会阻止创建新流；但是，另外它也适用于被激活的流用尽的任何限制。服务器应该只为短连接设置零值；如果服务器不希望接受请求，则关闭连接更合适。

>SETTINGS\_MAX\_CONCURRENT\_STREAMS 仅统计 open 和 half-close 状态的流，不包含用于推送状态的 reserved 状态的流。

- SETTINGS\_INITIAL\_WINDOW\_SIZE(0x4):    
  表示发送方的初始窗口大小(以八位字节为单位)，用于 stream 流级别流量控制。初始值为 2^16-1（65,535）个八位字节。此设置会影响所有流的窗口大小(请参阅[第 6.9.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-initial-flow-control-window-size))。高于最大流量控制窗口大小 2^31-1 的值必须被视为 FLOW\_CONTROL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

- SETTINGS\_MAX\_FRAME\_SIZE(0x5):    
  表示发送方愿意接收的最大帧有效负载的大小(以八位字节为单位)。初始值为 2^14（16,384）个八位字节。端点广播的值必须在此初始值与允许的最大帧大小（2^24-1 或 16,777,215个八位字节）之间(包括两者)。超出此范围的值必须视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

- SETTINGS\_MAX\_HEADER\_LIST\_SIZE(0x6):  
  此通知设置以八位字节的形式通知对端，发送方准备接受的头列表的最大大小。该值基于头字段的未压缩大小，包括八位字节的名称和值的长度加上每个头字段的32个八位字节的开销。对于任何给定的请求，可以强制执行低于建议值的下限。此设置的初始值无限制。

接收端如果接收到具有任何未知或不支持的标识符的 SETTINGS 帧，必须忽略该设置。


### 3. Settings Synchronization

SETTINGS 中的大多数值受益于或要求了解对端何时接收并应用更改的参数值。为了提供这样的同步时间点，其中未设置 ACK 标志的 SETTINGS 帧的接收者必须在接收时尽快使更新的参数生效。

SETTINGS 帧中的值必须按照它们出现的顺序进行处理，而值之间不需要进行其他帧处理。必须忽略不支持的参数。一旦处理完所有值，接收方必须立即发出设置了 ACK 标志的 SETTINGS 帧。在接收到设置了 ACK 标志的 SETTINGS 帧时，改变的参数的发送者可以认为参数已经生效。

如果 SETTINGS 帧的发送方在合理的时间内没有收到确认，则可能会发出 SETTINGS\_TIMEOUT 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### 4. For Example

举个例子，SETTINGS 帧的有效负载有多个参数的情况：

![](https://img.halfrost.com/Blog/ArticleImage/130_18.png)

在上图中，上面一个 SETTINGS 帧的 ACK 的值是 false，表示该帧已经被对等的 SETTINGS 帧的接收和应用。这个 SETTINGS 帧带了 3 个参数，SETTINGS\_MAX\_CONCURRENT\_STREAMS(0x3) = 128、SETTINGS\_INITIAL\_WINDOW\_SIZE(0x4) = 65536、SETTINGS\_MAX\_FRAME\_SIZE(0x5) = 16777215 。下面的 SETTINGS 帧一个参数也没有携带，ACK 标记位是 true。


## 六. PUSH_PROMISE 帧

![](https://img.halfrost.com/Blog/ArticleImage/130_4.svg)

PUSH\_PROMISE帧(类型 = 0x5) 用于在发送方打算发起的流之前提前通知对端。PUSH\_PROMISE 帧包括端点计划创建的流的无符号 31 位标识符以及为流提供附加上下文的一组头。[8.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push)详细描述了 PUSH\_PROMISE 帧的使用。此帧是服务端推送资源时描述请求的帧。

```c
    +---------------+
    |Pad Length? (8)|
    +-+-------------+-----------------------------------------------+
    |R|                  Promised Stream ID (31)                    |
    +-+-----------------------------+-------------------------------+
    |                   Header Block Fragment (*)                 ...
    +---------------------------------------------------------------+
    |                           Padding (*)                       ...
    +---------------------------------------------------------------+
```

PUSH\_PROMISE 帧包含以下几个字段:

- Pad Length:   
  一个 8 位字段，包含以八位字节为单位的帧填充长度。仅当设置了 PADDED 标志时，才会出现此字段。
  
- R:   
  一个保留位。
    
- Promised Stream ID:  
  无符号的 31 位整数，用于标识 PUSH\_PROMISE 保留的流。promised 流标识符必须是发送方发送的下一个流的有效选择(参见 [5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)中的"新流标识符")。

- Header Block Fragment:  
  包含请求标头字段的头块片段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。

- Padding:  
  填充的八位字节。
  
PUSH\_PROMISE 帧定义了以下 flag 标识：

- END\_HEADERS (0x4):  
  设置这个字段的时候，位 2 表示该帧包含整个 header 块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))，并且后面没有任何 CONTINUATION 帧。没有设置 END\_HEADERS 标志的 PUSH\_PROMISE 帧必须后跟相同流的 CONTINUATION 帧。接收方必须将接收到任何其他类型的帧或不同流上的帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。
  
  
- PADDED (0x8):  
  设置这个字段的时候，位 3 表示存在 Pad Length 字段及其描述的任何填充。


PUSH\_PROMISE 帧必须仅在处于 "打开" 或 "半关闭(远程)" 状态的对端初始化发起的流上发送。 PUSH\_PROMISE 帧的流标识符表明了与其关联的流。如果流标识符字段指定值 0x0，则接收方必须响应类型为 PROTOCOL\_ERROR的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。Promised 流不需要按承诺的顺序使用。PUSH\_PROMISE 仅保留流标识符以供以后使用。

如果对端的 SETTINGS\_ENABLE\_PUSH 设置设置为 0，则不能发送 PUSH\_PROMISE。已设置此设置并已收到确认的端点必须将 PUSH\_PROMISE 帧的接收视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

PUSH\_PROMISE 帧的接收者可以通过引用 promised 流标识符的 RST\_STREAM 帧返回给 PUSH\_PROMISE 的发送者来选择拒绝 promised 流。

PUSH\_PROMISE 帧以两种方式修改连接状态。首先，包含头块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))可能会修改为维护头部压缩的状态。其次，PUSH\_PROMISE 还保留一个流供以后使用，使得 promised 流进入"保留"状态。发送方不得在流上发送 PUSH\_PROMISE，除非该流是 "打开" 或 "半关闭(远程)" 状态；发送方必须确保 promised 流是新流标识符的有效选择([第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6))(即，promised 流必须处于 "空闲" 状态)。


由于 PUSH\_PROMISE 保留一个流，忽略 PUSH\_PROMISE 帧会导致流状态变得不确定。接收方必须将既不 "打开" 也不 "半关闭(本地)" 的流上的 PUSH\_PROMISE 接收视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。 但是，在关联流上发送 RST\_STREAM 的端点必须处理可能在接收和处理 RST\_STREAM 帧之前创建的 PUSH\_PROMISE 帧。

接收方必须将接收到 promise 非法流标识符([第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6))的 PUSH\_PROMISE 帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。注意，非法流标识符是当前未处于 "空闲" 状态的流的标识符。

PUSH\_PROMISE 帧可以包括填充。填充字段和 flag 标志与为 DATA 帧定义的字段和标志相同([第 6.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7))。

>客户端会从 1 开始设置 stream ID，之后每开启一个流，都会增加 2，并且之后一直用奇数。服务器开启在 PUSH\_PROMISE 中标明的流时，设置的 stream ID 从 2 开始，并且之后一直用偶数。这样设计避免了客户端和服务器之间的 stream ID 冲突，也可以轻松的判断哪些对象是由服务端推送的。0 是保留数字，用于连接控制消息，不能用于创建新的 stream 流。

举个 PUSH\_PROMISE 帧的例子：

![](https://img.halfrost.com/Blog/ArticleImage/130_29.png)

上图的例子中，Promised Stream ID = 2，偶数开始的。END\_HEADERS 是 true，R 保留位是 0。padded 是 false，所以 pad length 也是 0，之后紧接着是 Header Block Fragment。

## 七. PING 帧

PING 帧(类型 = 0x6)是用于测量来自发送方的最小往返时间以及确定空闲连接是否仍然起作用的机制。 PING 帧可以从任何端点发送。可用作**心跳检测，兼具计算 RTT 往返时间的功能**。

```c
    +---------------------------------------------------------------+
    |                                                               |
    |                      Opaque Data (64)                         |
    |                                                               |
    +---------------------------------------------------------------+
```

除了帧头之外，PING 帧必须在有效载荷中包含 8 个八位字节的不透明数据。发送方可以包含它选择的任何值，并以任何方式使用这些八位字节。

接收到不包含 ACK 标志的 PING 帧的接收方必须发送 PING 帧，其中 ACK 标志在响应时必须设置，并且要具有相同的有效载荷。PING 响应应该优先于任何其他帧。

PING 帧定义了如下的 flag 标识：

- ACK (0x1):  
  设置这个字段的时候，位 0 表示该 PING 帧是 PING 响应。端点必须在 PING 响应中设置此标志。 端点不得响应包含此标志的 PING 帧。

PING 帧不与任何单个流相关联。如果接收到具有除 0x0 以外的流标识符字段值的 PING 帧，则接收方必须以 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。接收到长度字段值不是 8 的 PING 帧必须被视为 FRAME\_SIZE\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

举个 HTTP/2 PING 帧的例子：

![](https://img.halfrost.com/Blog/ArticleImage/130_23_.png)

ping 里面的 ACK 标识位是 false。

![](https://img.halfrost.com/Blog/ArticleImage/130_24_.png)

pong 里面的 ACK 标识位是 true。

## 八. GOAWAY 帧

GOAWAY 帧(类型 = 0x7) 用于启动连接关闭或发出严重错误信号。GOAWAY 允许端点优雅地停止接受新流，同时仍然完成先前建立的流的处理。这可以实现管理员的操作，例如服务器维护。GOAWAY 帧用来**优雅的终止连接或者通知错误**。

在开始新流的端点和远程发送 GOAWAY 帧之间存在固有的竞争条件。为了处理这种情况，GOAWAY 包含在此连接中已经或可能在发送端点上处理的最后一个流标识符。例如，如果服务器发送 GOAWAY 帧，则标识的流是客户端发起的流编号最高的流。GOAWAY 帧一旦发送，如果这个流具有高于所包括的最后流标识符的标识符，则发送方将忽略由接收方发起的流上发送的帧。尽管可以为新流建立新连接，但 GOAWAY 帧的接收者不得在这个连接上打开其他流。

如果 GOAWAY 的接收方已经在具有比 GOAWAY 帧中指示的流标识符更高的流标识符的流上发送数据，那么这些流不被处理或将不被处理。GOAWAY 帧的接收方可以将流视为从未创建它们，从而允许稍后在新连接上重试这些流。

端点应该在关闭连接之前始终发送 GOAWAY 帧，以便远程对端可以知道流是否已被部分处理或者没有处理。例如，如果 HTTP 客户端在服务器关闭连接的同时发送 POST，如果服务器没有发送 GOAWAY 帧以指示它可能具有哪些流，则客户端无法知道服务器是否开始处理该 POST 请求。

端点可能选择关闭连接而不为行为不端的对端发送 GOAWAY 帧。GOAWAY 帧可能不会立即关闭连接；GOAWAY 帧的接收者不再使用该连接，应该在终止连接之前先发送 GOAWAY 帧。

```c
    +-+-------------------------------------------------------------+
    |R|                  Last-Stream-ID (31)                        |
    +-+-------------------------------------------------------------+
    |                      Error Code (32)                          |
    +---------------------------------------------------------------+
    |                  Additional Debug Data (*)                    |
    +---------------------------------------------------------------+
```

**GOAWAY 帧没有定义任何 flag 标识**：


GOAWAY 帧适用于连接，而不是特定的流。端点必须将具有除 0x0 以外的流标识符的 GOAWAY 帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

GOAWAY 帧中的最后一个流标识符包含最高编号的流标识符，GOAWAY 帧的发送者可能已对其采取某些操作或可能尚未采取操作。所有小于或等于此指定标识符的流都可能通过某种方式被处理。如果没有流被处理，最后流的标识符设置为0。

> 注意：这个案例中，“已处理”表示流中的某些数据已经被传到软件的更高的层并可能被进行某些处理。

如果连接在没有 GOAWAY 帧的情况下终止，则最后一个流标识符实际上是有效的最高的流标识符。在具有较低或相等编号的标识符的流上，在连接关闭之前未完全关闭的时候，不可能再重新尝试请求，事务或任何协议活动，但 HTTP GET，PUT 或 DELETE 等幂等操作除外。可以使用新连接安全地重试使用更高编号的流的任何协议活动。

编号低于或等于最后一个流标识符的流上的活动可能仍然成功完成。GOAWAY 帧的发送者可以通过发送 GOAWAY 帧优雅地关闭连接，保持连接处于"打开"状态，直到所有正在进行的流都处理完成。

如果情况发生变化，端点可以发送多个 GOAWAY 帧。例如，在正常关闭期间发送带有 NO\_ERROR 的 GOAWAY 的端点可能随后遇到需要立即终止连接的情况。来自最后一个 GOAWAY 帧的最后一个流标识符指示这些流已经被成功处理了。端点不得增加它们在最后一个流标识符中发送的值，因为对端可能已经在另一个连接上重试了未处理的请求。

当服务器关闭连接时，无法重试请求的客户端将丢失所有正在传输的请求。对于可能不使用 HTTP/2 为客户提供服务的中间件尤其如此。尝试正常关闭连接的服务器应该发送一个初始 GOAWAY 帧，最后一个流标识符设置为 2^31-1 和 NO\_ERROR code。这向客户端发出即将关闭的信号，并禁止发起进一步的请求。在允许任何传输中流创建的时间(至少一个往返时间)之后，服务器可以发送具有更新的最后流标识符的另一个 GOAWAY 帧。这可确保在不丢失请求的情况下彻底关闭连接。

在发送 GOAWAY 帧之后，发送端能丢弃流标识符大于最终流标识的流的帧。但是，任何改变连接状态的帧都不能完全忽略。例如，必须对 HEADERS，PUSH\_PROMISE 和 CONTINUATION 帧进行最低限度的处理，以确保为头压缩保持的状态是一致的(参见[第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))；类似地，DATA 帧必须被计算入连接的流量控制窗口中。如果无法处理这些帧可能会导致流量控制或报头压缩状态变得不同步。

GOAWAY 帧还包含一个 32 位错误代码([第 7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes))，其中包含关闭连接的原因。端点可以将不透明数据附加到任何 GOAWAY 帧的有效载荷中。其他调试数据仅用于诊断目的，不带语义值。调试信息可能包含安全或隐私敏感数据。记录或以其他方式持久存储的调试数据必须有足够的安全措施来防止未经授权的访问。


![](https://img.halfrost.com/Blog/ArticleImage/130_16.png)

GOAWAY 帧也比较简单。R 是保留标志位。这个帧的 Stream ID 是 0，说明它即将要关闭连接，promised 流标识符必须是发送方发送的下一个流的有效选择，promised-stream-ID 是 3 。这里的 Error Code 是 NO_ERROR (0x0)。


## 九. WINDOW\_UPDATE 帧

WINDOW\_UPDATE帧(类型 = 0x8) 用于实现流量控制；有关概述，请参见[第 5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)。

流量控制在两个级别上运行：在每个单独的流上和整个连接上。

所有类型的流量控制都是逐跳的，即仅在两个端点之间。中间件不在依赖的连接之间转发 WINDOW\_UPDATE 帧。但是，任何接收方对数据传输的限制都可能间接导致流量控制信息向原始发送方传播。

>流量控制仅针对直接建立 TCP 连接的两端。如果对端是代理服务器，代理服务器不需要向上游转发 WINDOW\_UPDATE 帧。不过接收端缩小流量控制的窗口会最终传递到源发送端。

流量控制仅适用于被识别为受流量控制的帧。在 HTTP/2 中定义的帧类型中，这仅包括 DATA 帧。除非接收方无法为处理帧分配资源，否则必须接受和处理免于流量控制的帧。如果接收方无法接受帧，则可以使用 FLOW\_CONTROL\_ERROR 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))或连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。


```c
    +-+-------------------------------------------------------------+
    |R|              Window Size Increment (31)                     |
    +-+-------------------------------------------------------------+
```

WINDOW\_UPDATE 帧的有效负载是一个保留位加上无符号 31 位整数，表示除现有流量控制窗口外，发送方可以发送的八位字节数。流量控制窗口增量的合法范围是 1 到 2^31-1 (2,147,483,647) 个八位字节。

**WINDOW\_UPDATE 帧没有定义任何 flag 标志**。WINDOW\_UPDATE 帧可以特定于流或整个连接。在前一种情况下，帧的流标识符指示受影响的流; 在后者中，值 "0" 表示整个连接都受这个帧的影响。

接收方必须将流量控制窗口增量为 0 的 WINDOW\_UPDATE 帧的接收视为 PROTOCOL\_ERROR 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))；连接的流量控制窗口上的错误必须被视为连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

WINDOW\_UPDATE 可以由已经发送带有 END\_STREAM 标志的帧的对端发送。这意味着接收方可以在 "半封闭(远程)" 或 "关闭" 流上接收 WINDOW\_UPDATE 帧。接收方不得将此视为错误(参见[第 5.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)）。

接收到流量控制帧的接收方必须始终考虑其对连接的流量控制窗口的影响，除非接收方将其视为连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。即使帧出错，这也是必要的。因为发送方将这个帧计入了流量控制窗口，如果接收方没有这样做，发送方和接收方的流量控制就会不相同了。长度不是 4 个八位字节的 WINDOW\_UPDATE 帧必须被视为 FRAME\_SIZE\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### 1. The Flow-Control Window

HTTP/2 中的流量控制是通过每个流上每个发送者保留一个窗口来实现的。流量控制窗口是一个简单的整数值，表示允许发送方传输多少个八位字节的数据；因此，它的大小是接收方缓冲容量的能力。

流量控制窗口对流和连接的流量控制窗口都适用。发送方不得发送长度超过接收方公布的任一流量控制窗口中的可用空间长度的流量控制帧。如果在任一流量控制窗口中没有可用空间，则可以发送设置了 END\_STREAM 标志的长度为零的帧(即，空的 DATA 帧)。**对于流量控制计算，不计算9个八位字节的帧头**。在发送流量控制帧之后，发送方通过发送帧的长度，来减少两个窗口中可用的空间。

帧的接收方发送 WINDOW\_UPDATE 帧，当它消耗数据并释放流量控制窗口中的空间。为流级和连接级的流量控制窗口发送单独的 WINDOW\_UPDATE 帧。接收到 WINDOW\_UPDATE 帧的发送方按帧中指定的量更新相应的窗口。

发送方应该禁止使流量控制窗口超过 2^31-1 个八位字节。如果发送方收到导致流量控制窗口超过此最大值的 WINDOW\_UPDATE，则必须根据需要终止流或连接。对于流，发送方发送 RST\_STREAM，错误代码为 FLOW\_CONTROL\_ERROR; 对于连接，发送错误代码为 FLOW\_CONTROL\_ERROR 的 GOAWAY 帧。

来自发送方的流量控制帧和来自接收方的 WINDOW\_UPDATE 帧相互完全异步。此属性允许接收方积极更新发送方保留的窗口大小，以防止流停止运转。


### 2. Initial Flow-Control Window Size

首次建立 HTTP/2 连接时，将创建新流，初始流量控制窗口大小为 65,535 个八位字节。连接的流量控制窗口也是 65,535 个八位字节。两个端点都可以通过在 SETTINGS 帧中包含 SETTINGS\_INITIAL\_WINDOW\_SIZE 的值来调整新流的初始窗口大小，该帧构成连接前奏的一部分。只能使用 WINDOW\_UPDATE 帧更改连接的流量控制窗口。

**在接收为 SETTINGS\_INITIAL\_WINDOW\_SIZE 设置值的 SETTINGS 帧之前，端点在发送流控帧时只能使用默认的初始窗口大小。类似地，连接的流量控制窗口设置为默认初始窗口大小，直到收到 WINDOW\_UPDATE 帧**。

除了更改尚未激活的流的流量控制窗口之外，SETTINGS 帧还可以更改具有活动流量控制窗口的流的初始流量控制窗口大小（即，"打开" 或 "半关闭(远程)" 状态)。当 SETTINGS\_INITIAL\_WINDOW\_SIZE 的值发生变化时，接收方必须通过新值和旧值之间的差异来调整它维护的所有流量控制窗口的大小。

对 SETTINGS\_INITIAL\_WINDOW\_SIZE 的更改可能导致流量控制窗口中的可用空间变为负数。发送方必须跟踪负流量控制窗口并且不得发送新的流量控制帧，直到它收到使流量控制窗口变为正的 WINDOW\_UPDATE 帧。例如，如果客户端在建立连接时立即发送 60 KB，并且服务器将初始窗口大小设置为 16 KB，则客户端将在收到 SETTINGS 帧时重新计算可用的流量控制窗口为 -44 KB。客户端保留负流量控制窗口，直到 WINDOW\_UPDATE 帧将窗口恢复为正值，之后客户端可以恢复发送。

**SETTINGS 帧不能改变连接的流量控制窗口**。

端点必须将因为处理对 SETTINGS\_INITIAL\_WINDOW\_SIZE 的更改而导致任何流量控制窗口超过最大大小的这种情况视为 FLOW\_CONTROL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### 3. Reducing the Stream Window Size

希望使用比当前大小更小的流量控制窗口的接收方可以发送新的 SETTINGS 帧。但是，接收方必须准备接收超过此窗口大小的数据，因为发送方可能会在处理 SETTINGS 帧之前发送超过下限的数据。

在发送减少初始流量控制窗口大小的 SETTINGS 帧之后，接收方可以继续处理超过流量控制限制的流。 允许流继续禁止接收方立即减少它为流量控制窗口预留的空间。由于需要 WINDOW\_UPDATE 帧以允许发送方继续发送，因此这些流的进度也会停滞。接收方也可以为受影响的流发送一个错误代码为FLOW\_CONTROL\_ERROR 的 RST\_STREAM。

### 4. For Example

![](https://img.halfrost.com/Blog/ArticleImage/130_19.png)

在上图的抓包中可以看到，WINDOW\_UPDATE 帧的 R 位是 0，Window Size Increment 是 2147418112 。

## 十. CONTINUATION 帧

CONTINUATION 帧(类型 = 0x9) 用于继续一系列 header block fragments 头块片段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。只要前一帧在同一个流上并且是没有设置 END\_HEADERS 标志的 HEADERS，PUSH\_PROMISE 或 CONTINUATION 帧，就可以发送任意数量的 CONTINUATION 帧。此帧专门用于**传递较大 HTTP 头部时的持续帧**。
 
 
```c
    +---------------------------------------------------------------+
    |                   Header Block Fragment (*)                 ...
    +---------------------------------------------------------------+
```

CONTINUATION 帧的有效载荷中包含一个 header block fragments 头块片段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。
 
CONTINUATION 帧中定义了如下的 flag:  

- END\_HEADERS (0x4):  
  当这个字段被设置的时候，位 2 表示该帧结束一个头块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))。如果未设置 END\_HEADERS 位，则此帧必须后跟另一个 CONTINUATION 帧。接收方必须将接收任何其他类型的帧或不同流上的帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。
 

CONTINUATION 帧改变了([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))中定义的连接状态。CONTINUATION 帧必须与一个流相关联。如果接收到其流标识符字段为 0x0 的 CONTINUATION 帧，则接收方必须以 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。

一个 CONTINUATION 帧必须在 HEADERS，PUSH\_PROMISE 或 CONTINUATION 帧之前，并且没有设置 END\_HEADERS 标志。观察到有违反此规则的接收方必须响应 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。
  
>可以把 CONTINUATION 帧当做特殊的 HEADERAS 帧。那么为什么要设计这个新的类型的帧呢？而不是直接使用 HEADERAS 帧？如果重复使用 HEADERAS 帧，那么后续的 HEADERAS 帧的负载就需要经过特殊处理才能和之前的拼接起来，这些帧首部是否需要重复？如果帧之间存在分歧该怎么办？协议制定者觉得这些都是模棱两可的问题，在未来可能还会引起麻烦，所以工作组决定增加一个明确的帧类型，以避免实现混淆。
>
>由于 HEADERAS 帧和 CONTINUATION 帧必须是有序的，所以使用 CONTINUATION 帧会破坏或者减少多路复用的好处。CONTINUATION 帧是解决重要场景(大首部)的工具，但只能在必要时使用。
>


## 十一. Error Codes

错误代码是在 RST\_STREAM 和 GOAWAY 帧中使用的 32 位字段，用于表示流或连接错误的原因。错误代码共享公共代码空间。某些错误代码仅适用于流或整个连接，并且在其他上下文中没有定义的语义。

定义了以下错误代码：  

- NO\_ERROR (0x0):    
  关联条件不是错误的结果。例如，GOAWAY 可能包含此代码以指示正常关闭连接。

- PROTOCOL\_ERROR (0x1):    
  端点检测到非特定协议错误。当更具体的错误代码不可用时，将使用此错误。

- INTERNAL\_ERROR (0x2):   
  端点遇到意外的内部错误。

- FLOW\_CONTROL\_ERROR (0x3):    
  端点检测到其对端违反了流量控制协议。

- SETTINGS\_TIMEOUT (0x4):  
  端点发送了 SETTINGS 帧，但没有及时收到响应。请参见[第 6.5.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-settings-synchronization) ("设置同步")。

- STREAM\_CLOSED (0x5):    
  端点在流半关闭后收到一帧。stream 已经处于半关闭状态不再接收 frame 帧的时候，又接收到了 frame 帧。

- FRAME\_SIZE\_ERROR (0x6):  
  端点收到的帧大小无效。

- REFUSED\_STREAM (0x7):  
  端点在执行任何应用程序处理之前拒绝了流(有关详细信息，请参见[第 8.1.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2))。

- CANCEL (0x8):    
  端点用于指示不再需要该流。

- COMPRESSION\_ERROR (0x9):  
  端点无法维护连接的头压缩上下文。

- CONNECT\_ERROR (0xa):    
  为响应 CONNECT 请求而建立的连接([第 8.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%89-the-connect-method))被重置或异常关闭。

- ENHANCE\_YOUR\_CALM (0xb):    
  端点检测到其对端正在表现出可能产生过多负载的行为。提醒对方"冷静"点。

- INADEQUATE\_SECURITY (0xc):  
  底层传输具有不满足最低安全要求的属性(参见[第 9.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E4%BD%BF%E7%94%A8-tls-%E7%89%B9%E6%80%A7))。

- HTTP\_1\_1\_REQUIRED (0xd):  
  端点要求使用 HTTP/1.1 而不是 HTTP/2。

未知或不支持的错误代码不得触发任何特殊行为。这些可以被实现视为等同于 INTERNAL\_ERROR。



------------------------------------------------------

Reference：  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-http-frames-definitions/](https://halfrost.com/http2-http-frames-definitions/)
> 