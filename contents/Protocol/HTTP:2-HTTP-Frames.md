<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_0.png'>
</p>

# HTTP/2 中的 HTTP 帧和流的多路复用

上篇文章中讲的 HTTP/2 是如何建立连接的。这篇文章开始，我们来讨论讨论帧结构。一旦建立了 HTTP/2 连接后，端点就可以开始交换帧了。

## 一. Frame Format 帧格式

HTTP/2 会发送有着不同类型的二进制帧，但他们都有如下的公共字段：Type, Length, Flags, Stream Identifier 和 frame payload。本规范中一共定义了 10 种不同的帧，其中最基础的两种分别对应于 HTTP 1.1 的 DATA 和 HEADERS。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_2.png'>
</p>


所有帧都以固定的 9 字节大小的头作为帧开始，后跟可变长度的有效载荷 payload。

```c
    +-----------------------------------------------+
    |                 Length (24)                   |
    +---------------+---------------+---------------+
    |   Type (8)    |   Flags (8)   |
    +-+-------------+---------------+-------------------------------+
    |R|                 Stream Identifier (31)                      |
    +=+=============================================================+
    |                   Frame Payload (0...)                      ...
    +---------------------------------------------------------------+
```

帧头的字段定义如下：

- Length：  
  帧有效负载的长度表示为无符号的 24 位整数。除非接收方为 SETTINGS\_MAX\_FRAME\_SIZE 设置了较大的值(详情见[这里](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters))，否则不得发送大于2 ^ 14（16,384）的值。**帧头的 9 个八位字节不包含在此长度值中**。
  
- Type：  
  这 8 位用来表示帧类型的。帧类型确定帧的格式和语义。实现方必须忽略并丢弃任何类型未知的帧。
  
- Flags：  
  这个字段是为特定于帧类型的布尔标志保留的 8 位字段，为标志分配特定于指示帧类型的语义。没有为特定帧类型定义语义的标志必须被忽略，并且必须在发送时保持未设置 (0x0)。
  
>常用的标志位有 END\_HEADERS 表示头数据结束，相当于 HTTP/1 里头后的空行（“\r\n”），END\_STREAM 表示单方向数据发送结束（即 EOS，End of Stream），相当于 HTTP/1 里 Chunked 分块结束标志（“0\r\n\r\n”）。


  
- R：  
  保留的 1 位字段。该位的语义未定义，发送时必须保持未设置 (0x0)，接收时必须忽略。

- Stream Identifier：  
  流标识符 (参见 [第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6))，表示为无符号 31 位整数。值 0x0 保留用于与整个连接相关联的帧，而不是单个流。
  
帧有效载荷 payload 的结构和内容完全取决于帧类型。


抓包看看实际帧头部的样子，这里任取一个帧类型，比如 SETTINGS 帧：

![](https://img.halfrost.com/Blog/ArticleImage/124_3_0.png)

抓包显示的帧结构的头部结构确实是开头 9 字节大小。Length 是 18，Type 是 4，Flags 标记位是 ACK，R 是保留位，对应上图抓包图中的 Reserved。Stream Identifier 是 0 。

## 二. Frame Size 帧大小

帧有效负载 payload 的大小受接收方在 SETTINGS\_MAX\_FRAME\_SIZE 设置中建议的最大大小的限制。此设置可以包含 2^14(16,384) 和 2^24-1(16,777,215) 个八位字节之间的任何值。

所有实现必须能够接收并至少能处理长度为 2^14 个八位字节的帧，加上 9 个八位位组帧头。描述帧大小时不包括帧头的大小。

> 注意：某些帧类型(如 PING ([第 6.7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%83-ping-%E5%B8%A7)))对允许的有效负载数据量施加了额外限制。

如果帧超过 SETTINGS\_MAX\_FRAME\_SIZE 中定义的大小，超出了帧类型定义的任何限制，或者太小而不能包含强制帧数据，则端点必须发送错误代码 FRAME\_SIZE\_ERROR。可能会改变整个连接状态的帧中的帧大小的错误必须被视为连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))；这包括带有 header block 的任何帧([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))(即 HEADERS，PUSH\_PROMISE 和 CONTINUATION) SETTINGS 以及流标识符为 0 的任何帧。

端点没有义务使用帧中的所有可用空间。通过使用小于允许的最大大小的帧可以改善响应性。发送大帧可能导致发送时间敏感帧(例如 RST\_STREAM，WINDOW\_UPDATE 或 PRIORITY)的延迟，如果被大帧的传输 block 了，则会影响性能。


## 三. Header Compression and Decompression

就像在 HTTP/1 中一样，HTTP/2 中的 header 字段是具有一个或多个关联值的名称。header 字段用于 HTTP 请求和响应消息以及服务器推送操作(参见[第 8.2 节]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push)))。

header 列表是零个或多个标题字段的集合。当通过连接传输时，使用 HTTP 头压缩[COMPRESSION] 将 header 列表序列化为 header block 块。然后将序列化的 header block 块分成一个或多个八位字节序列，称为 header 块片段，并在 HEADERS([第 6.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7))，PUSH\_PROMISE([第 6.6 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)）或 CONTINUATION([第 6.10 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7))帧的有效载荷 payload 内发送。

header 中的 Cookie 字段[COOKIE]由 HTTP mapping 专门处理(参见[第 8.1.2.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#2-http-header-fields))。

接收端点通过连接其片段来重新组装 header 块，然后解压缩该块以重建 header 列表。完整的 header 块由两者组成:  

- 单个 HEADERS 或 PUSH\_PROMISE 帧，设置 END\_HEADERS 标志。

- 清除了 END\_HEADERS 标志的 HEADERS 或 PUSH\_PROMISE 帧以及一个或多个 CONTINUATION 帧，其中最后一个 CONTINUATION 帧设置了 END\_HEADERS 标志。

header 压缩是有状态的。一个压缩上下文和一个解压缩上下文用于整个连接。header 块中的解码错误必须被视为类型 COMPRESSION\_ERROR 的连接错误 ([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

每个 header 块作为离散单元处理。header 块必须作为连续的帧序列传输，没有任何其他类型的交错帧或任何其他的 stream 流。HEADERS 或 CONTINUATION 帧序列中的最后一帧设置了 END\_HEADERS 标志。PUSH\_PROMISE 或 CONTINUATION 帧序列中的最后一帧设置了 END\_HEADERS 标志。这允许 header 块在逻辑上等同于单个帧。

**header 块片段只能作为 HEADERS，PUSH\_PROMISE 或 CONTINUATION 帧的有效载荷 payload 发送**，因为这些帧携带的数据可以修改接收者维护的压缩上下文。接收 HEADERS，PUSH\_PROMISE 或 CONTINUATION 帧的端点需要重新组合报头块并执行解压缩，即使要丢弃的帧也是如此。如果没有解压缩 header 块，接收者必须用 COMPRESSION\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))终止连接。


## 四. stream 流状态机

![](https://img.halfrost.com/Blog/ArticleImage/125_1.png)

stream 流是在 HTTP/2 连接内在客户端和服务器之间交换的独立的双向帧序列。stream 流有几个重要的特征:     

- 单个 HTTP/2 连接可以包含多个并发打开的 stream 流，任一一个端点都可能交叉收到来自多个 stream 流的帧。
- stream 流可以单方面建立和使用，也可以由客户端或服务器共享。
- 任何一个端都可以关闭 stream 流。
- 在 stream 流上发送帧的顺序非常重要。收件人按照收到的顺序处理帧。特别是，HEADERS 和 DATA 帧的顺序在语义上是重要的。
- stream 流由整数标识。stream 流标识符是由发起流的端点分配给 stream 流的。

一个 stream 流的生命周期如下图：

```c
                                +--------+
                        send PP |        | recv PP
                       ,--------|  idle  |--------.
                      /         |        |         \
                     v          +--------+          v
              +----------+          |           +----------+
              |          |          | send H /  |          |
       ,------| reserved |          | recv H    | reserved |------.
       |      | (local)  |          |           | (remote) |      |
       |      +----------+          v           +----------+      |
       |          |             +--------+             |          |
       |          |     recv ES |        | send ES     |          |
       |   send H |     ,-------|  open  |-------.     | recv H   |
       |          |    /        |        |        \    |          |
       |          v   v         +--------+         v   v          |
       |      +----------+          |           +----------+      |
       |      |   half   |          |           |   half   |      |
       |      |  closed  |          | send R /  |  closed  |      |
       |      | (remote) |          | recv R    | (local)  |      |
       |      +----------+          |           +----------+      |
       |           |                |                 |           |
       |           | send ES /      |       recv ES / |           |
       |           | send R /       v        send R / |           |
       |           | recv R     +--------+   recv R   |           |
       | send R /  `----------->|        |<-----------'  send R / |
       | recv R                 | closed |               recv R   |
       `----------------------->|        |<----------------------'
                                +--------+

          send:   endpoint sends this frame
          recv:   endpoint receives this frame

          H:  HEADERS frame (with implied CONTINUATIONs)
          PP: PUSH_PROMISE frame (with implied CONTINUATIONs)
          ES: END_STREAM flag
          R:  RST_STREAM frame
```

请注意，此图显示了 stream 流状态转换以及仅影响这些转换的帧和标志。在这方面，CONTINUATION 帧不会导致状态转换；它们实际上是他们所遵循的 HEADERS 或 PUSH\_PROMISE 的一部分。


出于状态转换的目的，对于承载了 END\_STREAM 标志位的帧，这个标志位作为一个单独的事件; 设置了 END\_STREAM 标志的 HEADERS 帧可能导致两个状态转换。

两个端点都具有 stream 流的状态的主观视图，这 2 个视图在帧在传输中时可能不同。端点不协调 stream 流的创建; 流是由任一一个端点单方面创建的。状态不匹配的负面后果仅限于发送 RST\_STREAM 后的“关闭”状态，帧可能在关闭后的一段时间内又被接收了。

stream 流有以下几种状态：

### idle：    
  所有的 stream 流都是从空闲态开始的。以下过渡在此状态下有效：  
 - 发送或接收 HEADERS 帧会导致 stream 流变为 open 状态。如 [第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)中所述，流标识符被选中。相同的 HEADERS 帧也可以使流立即变为 half-closed “半关闭”状态。

 - 在另一个 stream 流上发送 PUSH\_PROMISE 帧保留了用于以后使用的空闲流。保留 stream 流的流状态转换为 "reserved (local)" 保留(本地)状态。

 - 在另一个 stream 流上接收 PUSH\_PROMISE 帧保留一个空闲流，该空闲流被标识以供以后使用。保留 stream 流的流状态转换为 "reserved (remote)" 保留(远程)状态。

 - 请注意，PUSH\_PROMISE 帧不是在空闲流上发送的，而是在 Promised Stream ID 字段中引用新保留的流。

在此状态下在流上接收到除了 HEADERS 或 PRIORITY 之外的任何帧必须被视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### reserved (local):   

"保留(本地)"状态的 stream 流是通过发送 PUSH\_PROMISE 帧的流。PUSH\_PROMISE 帧通过将流与远程对等方发起的开放流相关联来保留空闲流(参见[第 8.2 节]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push)))。在这个状态下，以下过渡在此状态下有效：  
 
- 端点可以发送 HEADERS 帧。这导致 strame 流以 "半关闭(远程)" 状态打开。
- 两个端点都可以发送 RST\_STREAM 帧以使 strame 流变为"关闭"。这将释放 strame 流的预留。
   
在此状态下，端点不得发送除 HEADERS，RST\_STREAM 或 PRIORITY 之外的任何类型的帧。可以在此状态下接收 PRIORITY 或 WINDOW\_UPDATE 帧。在此状态下在流上接收除 RST\_STREAM，PRIORITY 或 WINDOW\_UPDATE 之外的任何类型的帧必须被视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。



### reserved (remote):   

已经由远程对等方保留"保留(远程)"状态的流。在这个状态下，以下过渡在此状态下有效：  
 
- 接收 HEADERS 帧会导致 strame 流转换为"半关闭(本地)"。  
- 两个端点都可以发送 RST\_STREAM 帧以使 strame 流变为"关闭" 状态。这将释放 strame 流的预留。

端点可以在此状态下发送 PRIORITY 帧以重新设置保留流的优先级。在此状态下，端点不得发送除RST\_STREAM，WINDOW\_UPDATE 或 PRIORITY 之外的任何类型的帧。在此状态下在流上接收除HEADERS，RST\_STREAM 或 PRIORITY 之外的任何类型的帧必须被视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### open:    

两个通信的对端可以使用处于"打开"状态的流来发送任何类型的帧。在此状态下，发送方需要遵守约定的 strame 流级流量控制的限制([第 5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6))。

从该状态，任一端点都可以发送一个设置了 END\_STREAM 标志的帧，这会导致 stream 流转换为"半闭"状态之一。发送 END\_STREAM 标志的端点导致 stream 流状态变为 "半关闭闭(本地)"; 接收 END\_STREAM 标志的端点导致流状态变为 "半关闭(远程)"。

两个端点都可以从此状态发送 RST\_STREAM 帧，使其立即转换为 "已关闭"。



### half-closed (local):  

处于 "半关闭(本地)" 状态的流不能用于发送除 WINDOW\_UPDATE，PRIORITY 和 RST\_STREAM 之外的帧。

当接收到包含 END\_STREAM 标志的帧或任一对等体发送 RST\_STREAM 帧时，流从此状态转换为"关闭"。

端点可以在此状态下接收任何类型的帧。使用 WINDOW\_UPDATE 帧提供流量控制的 credit 是继续接收流量控制帧所必需的。在这种状态下，接收者可以忽略 WINDOW\_UPDATE 帧，因为这些帧可能在发送带有 END\_STREAM 标志的帧之后短时间到达。

在该状态下接收的 PRIORITY 帧用于重新确定依赖于所识别的 stream 流的优先级。



### half-closed (remote):   

对端不再使用 "半关闭(远程)" 流来发送帧。在这种状态下，端点不再有责任维护接收者流量控制的窗口。

如果端点接收除 WINDOW\_UPDATE，PRIORITY 或 RST\_STREAM 之外的其他帧，对于处于此状态的流，它必须以 STREAM\_CLOSED 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))进行响应。

端点可以使用 "半关闭(远程)" 的流来发送任何类型的帧。在此状态下，端点继续遵守约定的 stream 流级别的流量控制限制([第 5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6))。

通过发送包含 END\_STREAM 标志的帧或者任一对端发送 RST\_STREAM 帧，流可以从此状态转换为“关闭”。


### closed:

"关闭"状态是最终状态。

端点绝不能在关闭流上发送 PRIORITY 以外的帧。接收到 RST\_STREAM 后接收除 PRIORITY 之外的任何帧的端点必须将其视为 STREAM\_CLOSED 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。类似地，在接收到具有 END\_STREAM 标志的帧之后接收任何帧的端点必须将其视为类型为 STREAM\_CLOSED 的连接错误（[第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)），除非如下所述允许该帧。

在发送包含 END\_STREAM 标志的 DATA 或 HEADERS 帧之后，可以在此状态下短时间内接收 WINDOW\_UPDATE 或 RST\_STREAM 帧。在远程对端接收并处理 RST\_STREAM 或带有 END\_STREAM 标志的帧之前，它可能会发送这些类型的帧。端点必须忽略在此状态下接收的 WINDOW\_UPDATE 或 RST\_STREAM 帧，尽管端点在处理发送 END\_STREAM 之后很长时间才到达的帧视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。

可以在关闭流上发送 PRIORITY 帧以优先化依赖于关闭流的流。端点应该处理 PRIORITY 帧，但是如果已从依赖树中删除了流，则可以忽略它们(参见[第 5.3.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#4-%E4%BC%98%E5%85%88%E7%BA%A7%E7%9A%84%E7%8A%B6%E6%80%81%E7%AE%A1%E7%90%86))。

如果由于发送 RST\_STREAM 帧而到达关闭状态，则接收 RST\_STREAM 的对端可能已经发送 - 或者在发送排队中 - 无法撤消的 stream 流上的帧。端点必须忽略它在发送 RST\_STREAM 帧后在关闭流上接收的帧。端点可以选择限制忽略帧的周期，并将在此时间之后到达的帧视为出错。

在发送 RST\_STREAM 之后接收的流量控制帧(例如，DATA)会被计数到连接流量控制窗口。即使这些帧可能被忽略，因为它们是在发送方收到 RST\_STREAM 之前发送的，因此发送方将根据流量控制窗口考虑帧数。

端点在发送 RST\_STREAM 后可能会收到 PUSH\_PROMISE 帧。即使关联的流已被重置，PUSH\_PROMISE 也会使流变为“保留”状态。因此，需要 RST\_STREAM 来关闭不需要的流。

如果本文档中其他地方没有更具体的指导，则实现应该将状态描述中未明确允许的帧的接收视为PROTOCOL\_ERROR类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。请注意，PRIORITY 帧可以在任何流状态下发送和接收。忽略未知类型的帧。


### 1. stream 标识符


stream 流使用无符号的 31 位整数标识。**由客户端发起的流必须使用奇数编号的流标识符**；**那些由服务器发起的必须使用偶数编号的流标识符**。**流标识符零(0x0)用于连接控制消息**；零流标识符不能用于建立新的 stream 流。

总结一下，stream ID 的作用：

- 实现多路复用的关键。接收端的实现可以根据这个 ID 并发组装消息。同一个 stream 内 frame 必须是有序的。SETTINGS\_MAX\_CONCURRENT\_STREAMS 控制着最大并发数。

![](https://img.halfrost.com/Blog/ArticleImage/130_3.svg)

websocket 原生协议由于没有这个 stream ID 类似的字段，所以它原生不支持多路复用。在同一个 stream 内部的 frame 由于没有其他的 ID 编号了，所以无法乱序，必须有序，无法并发(如果想要并发，可以再新启一个 stream)。

- 推送依赖性请求的关键。客户端发起的流是奇数编号，服务端发起的流是偶数编号。

![](https://img.halfrost.com/Blog/ArticleImage/130_4.svg)

- 流状态管理的约束性规定。规定见下面几段：

"h2c" 方式升级到 HTTP/2的 HTTP/1.1请求(参见[第 3.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#2-starting-http2-for-http-uris))用流标识符 1 (0x1) 进行响应。升级完成后，客户端的流 0x1 为 "half-closed (local)" 状态。因此，从 HTTP/1.1 升级的客户端不能选择流 0x1 作为新的流标识符。

新建立的流的标识符必须在数字上大于发起端点已打开或保留的所有流。这样就管理了使用 HEADERS 帧打开的流和使用 PUSH\_PROMISE 保留的流。接收到意料之外的流标识符的端点必须视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))

第一次使用新流标识符暗示关闭了可能已由具有较低值流标识符的对端发起的"空闲"状态中的所有流。例如，如果客户端在流 7 上发送 HEADERS 帧而没有在流 5 上发送帧，则当发送或接收流 7 的第一帧时，流 5 转换到“关闭”状态。

流标识符无法重用。长期连接可能导致端点耗尽可用的流标识符范围。无法建立新流标识符的客户端可以为新的 stream 流建立新连接。无法建立新流标识符的服务器可以发送 GOAWAY 帧，以便强制客户端为新的 stream 流打开新连接。


### 2. stream 并发

流的多路复用意味着在同一连接中来自各个流的数据包会被混合在一起。就好像两个（或者更多）独立的“数据列车”被拼凑到了一辆列车上，但它们最终会在终点站被分开。下图就是两列“数据火车”的示例

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_3.jpg'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_4.jpg'>
</p>

它们就是这样通过多路复用的方式被组装到了同一列火车上。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_5.jpg'>
</p>

对端可以使用 SETTINGS 帧内的 SETTINGS\_MAX\_CONCURRENT\_STREAMS 参数(参见[第 6.5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters))限制并发活动流的数量。每个端点有各自的最大并发流设置，并且这个设置仅适用于接收设置的对端。也就是说，客户端指定服务器可以启动的最大并发流数，服务器指定客户端可以启动的最大并发流数。

处于“打开”状态或处于“半封闭”状态之一的 stream 流参与计算允许端点打开的最大流数。这三种状态中的任何一种状态的流都会计入 SETTINGS\_MAX\_CONCURRENT\_STREAMS 设置中公布的限制。任何“保留”状态中的流都不计入流限制中。

端点不得超过其对端设置的限制。因为接收 HEADERS 帧而导致其超出了公布的并发流限制的端点必须将其视为 PROTOCOL\_ERROR 或 REFUSED\_STREAM 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。错误代码的选择决定了端点是否希望启用自动重试(详见[第 8.1.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2))。

希望将 SETTINGS\_MAX\_CONCURRENT\_STREAMS 的值减小到低于当前打开流数量的值的端点可以关闭超过新值的流或允许流自己完成后关闭。


## 五. 流量控制

使用 stream 流进行多路复用会引入使用 TCP 连接的争用，从而导致阻塞 stream 流。流量控制方案确保同一连接上的流不会破坏性地相互干扰。流量控制用于单个流和整个连接。

> 由于 HTTP/2 数据流在一个 TCP 连接内复用，TCP 流控制既不够精细，也无法提供必要的应用级 API 来调节各个数据流的传输。 为了解决这一问题，HTTP/2 提供了一组简单的构建块，这些构建块允许客户端和服务器实现其自己的数据流和连接级流控制。
> 
> 

HTTP/2 通过使用 WINDOW\_UPDATE 帧提供流量控制([第 6.9 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7))。

### 1. 流量控制原则

HTTP/2 流的流量控制旨在允许使用各种流量控制算法而无需协议改变。HTTP/2 中的流量控制具有以下特征：

1. 流量控制特定于某一个连接。两种类型的流量控制都在单跳的端点之间，而不是在整个端到端路径之间。即，可信的网络中间件可以使用它来控制资源使用，以及基于自身条件和启发式算法实现资源分配机制。
2. 流量控制基于 WINDOW\_UPDATE 帧。接收者通告他们准备在 stream 流以及整个连接上接收多少个八位字节。这是一种基于 credit 信用的方案。接收端设定上限，发送端应当遵循接收端发出的指令。
3. 流量控制是定向的，接收者提供整体控制。接收者可以选择为每个流和整个连接设置所需的任何窗口大小。发送者必须遵守接收者施加的流量控制的限制。客户端，服务器和中间件，作为接收者，都需要独立地将其流量控制窗口进行广播，并遵守其对端在发送时设置的流量控制限制。
4. 对于一个新的 strean 流和整体连接，流量控制窗口的初始值为 65,535 个八位字节。
5. 帧类型确定流量控制是否适用于帧。在本文档中指定的帧中，**只有 DATA 帧受流量控制**；所有其他帧类型在广播其流量控制窗口的时候，不占用空间。这确保了重要的控制帧不会被流量控制阻挡。
6. **无法禁用流量控制**。建立 HTTP/2 连接后，客户端将与服务器交换 SETTINGS 帧，这会在两个方向上设置流控制窗口。 流控制窗口的默认值设为 65,535 字节，但是接收方可以设置一个较大的最大窗口大小（2^31-1 字节），并在接收到任意数据时通过发送 WINDOW\_UPDATE 帧来维持这一大小。
7. HTTP/2 仅定义 WINDOW\_UPDATE 帧的格式和语义([第 6.9 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7))。本文档未规定接收方如何决定何时发送此帧或其发送的值，也未规定发送方如何选择发送数据包。实现方能够选择任何适合其需求的算法。


> 服务器和客户端都具备流量控制能力，发送和接收可以独立的设置流量控制。
> 


实现方还负责管理基于优先级发送请求和响应的方式，选择如何避免请求的队首阻塞以及管理新的流的创建。这些算法的选择可以与流量控制算法相互作用。


### 2. 适当的使用流量控制

> HTTP/2 未指定任何特定算法来实现流控制。 

流量控制目的是为了保护在资源约束下工作的端点。例如，proxy 需要在许多连接之间共享内存，并且还可能具有较慢的上游连接和较快的下游连接。流量控制解决了接收者无法在一个流上处理数据但又想继续处理同一连接中的其他流的情况。

不需要此功能的部署可以广播最大大小的流量控制窗口 (2^31-1)，并且可以在收到任何数据时通过发送 WINDOW\_UPDATE 帧来维护此窗口。这有效地禁用了该接收者的流量控制。相反，发送方始终服从接收方广播的流量控制窗口。

具有受限资源的部署（例如，内存）可以使用流量控制来限制对端可能消耗的内存大小。但请注意，如果在不知道带宽延迟的情况下启用流量控制，则可能导致可用网络资源的次优使用(参见[[RFC7323]](https://tools.ietf.org/html/rfc7323))。

即使完全了解当前的带宽延迟，流量控制的实现也很困难。使用流量控制时，接收者必须及时从 TCP 接收缓冲区读取。如果不读取并执行关键帧(例如 WINDOW\_UPDATE)，则不这样做可能会导致死锁。

## 六. stream 优先级

客户端可以通过在打开流的 HEADERS 帧([第 6.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7))中包含优先级信息来为新的流分配优先级。在任何其他时间，PRIORITY 帧([第 6.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%89-priority-%E5%B8%A7))可用于更改流的优先级。

确定优先级的目的是允许端点在管理并发流时表达它希望其对端如何分配资源。最重要的是，当发送容量有限时，可以使用优先级来选择用于发送帧的流。

可以通过将流标记为依赖其他流的完成，来确定流的优先级([第 5.3.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E4%BE%9D%E8%B5%96))。为每个依赖项分配一个相对权重，该数字用于确定分配给依赖于相同流的 stream 流的可用资源的相对比例。

显式设置流的优先级会参与到优先排序的过程中。但是它不保证流相对于任何其他流的任何特定处理或传输顺序。端点不能强制对端使用优先级以特定顺序处理并发流。因此，表达优先级只是一个建议。可以从消息中省略优先级信息。在提供任何显式值之前使用默认值([第 5.3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7))。

### 1. stream 依赖

可以为每个流提供对另一个流的显式依赖。包含依赖关系代表了一个偏好，将资源分配给所标识的流而不是所依赖的流。不依赖于任何其他流的流，它的流依赖性是 0x0。换句话说，不存在的流 0 形成树的根。

依赖于另一个流的流是依赖流。流依赖的流是父流。对当前不在树中的流的依赖性 - 例如处于“空闲”状态的流 - 导致该流被赋予默认优先级([第 5.3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7))。

在为另一个流分配依赖关系时，会将该流添加为父流的新依赖关系。共享相同父节点的从属流不是相互排序的。例如，如果流 B 和 C 依赖于流 A，并且如果流 D 创建时具有对流 A 的依赖性，则这导致依赖顺序为 A，后跟 B，C 和 D，B，C，D 的顺序是任意的。

```c
       A                 A
      / \      ==>      /|\
     B   C             B D C
```

独占标志允许插入新级别的依赖项。独占标志使流成为其父流的唯一依赖关系，从而导致其他依赖关系依赖于独占流。在前面的示例中，如果使用流 A 的独占依赖关系创建流 D，则会导致 D 成为 B 和 C 的依赖关系的父项。

```c
                         A
       A                 |
      / \      ==>       D
     B   C              / \
                       B   C
```

在依赖树内部，如果依赖于它所依赖的所有流(父流的链到达 0x0)都被关闭或者不可能在它们上继续工作，则依赖流应该仅被分配资源。流不能依赖于自身，端点必须将其视为 PROTOCOL\_ERROR 类型的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### 2. 依赖权重

所有依赖的流都被分配 [1,256] 之间的整数权重值。具有相同父级的流应该根据其权重按比例分配资源。因此，如果流 B 依赖于具有权重 4 的流 A，则流 C 依赖于具有权重 12 的流 A，并且不能在流 A 上进行，流 B 理想地接收分配给流 C 的资源的三分之一。

### 3. 优先级调整

使用 PRIORITY 帧更改流的优先级。设置依赖关系会导致流依赖于所标识的父流。如果重新设置父流优先级，则依赖流与其父流一起调整。使用独占标志重新调整优先级的流设置依赖性会导致新的父流的所有依赖关系依赖于重新调整过优先级的流。

如果一个流依赖于其自身的依赖者之一，则它依赖的流先移动到优先级调整完成以后父级流所在的位置上。依赖性的调整保持其权值不变。例如，考虑一个原始的依赖树，其中 B 和 C 依赖于 A，D 和 E 依赖于 C，而 F 依赖于 D。如果 A 依赖于 D，则 D 代替 A。所有其他依赖关系保持不变，但是 F 除外，如果重新优先级是独占的，F 还将依赖于 A。


```c
       x                x                x                 x
       |               / \               |                 |
       A              D   A              D                 D
      / \            /   / \            / \                |
     B   C     ==>  F   B   C   ==>    F   A       OR      A
        / \                 |             / \             /|\
       D   E                E            B   C           B C F
       |                                     |             |
       F                                     E             E
                  (intermediate)   (non-exclusive)    (exclusive)
```


共享相同父项的数据流（即，同级数据流）应按其权重比例分配资源。 例如，如果数据流 A 的权重为 12，其同级数据流 B 的权重为 4，那么要确定每个数据流应接收的资源比例，请执行以下操作：

![](https://img.halfrost.com/Blog/ArticleImage/130_5.svg)

1. 将所有权重求和：4 + 12 = 16
2. 将每个数据流权重除以总权重：A = 12/16, B = 4/16


因此，数据流 A 应获得四分之三的可用资源，数据流 B 应获得四分之一的可用资源；数据流 B 获得的资源是数据流 A 所获资源的三分之一。

我们来看一下上图中的其他几个操作示例。 从左到右依次为：

1. 数据流 A 和数据流 B 都没有指定父依赖项，依赖于显式“根数据流”；A 的权重为 12，B 的权重为 4。因此，根据比例权重：数据流 B 获得的资源是 A 所获资源的三分之一。
2. 数据流 D 依赖于根数据流；C 依赖于 D。 因此，D 应先于 C 获得完整资源分配。 权重不重要，因为 C 的依赖关系拥有更高的优先级。
3. 数据流 D 应先于 C 获得完整资源分配；C 应先于 A 和 B 获得完整资源分配；数据流 B 获得的资源是 A 所获资源的三分之一。
4. 数据流 D 应先于 E 和 C 获得完整资源分配；E 和 C 应先于 A 和 B 获得相同的资源分配；A 和 B 应基于其权重获得比例分配。

如上面的示例所示，数据流依赖关系和权重的组合明确表达了资源优先级，这是一种用于提升浏览性能的关键功能，网络中拥有多种资源类型，它们的依赖关系和权重各不相同。 不仅如此，HTTP/2 协议还允许客户端随时更新这些优先级，进一步优化了浏览器性能。 换句话说，我们可以根据用户互动和其他信号更改依赖关系和重新分配权重。

>注：数据流依赖关系和权重表示传输优先级，而不是要求，因此不能保证特定的处理或传输顺序。 即，客户端无法强制服务器通过数据流优先级以特定顺序处理数据流。 尽管这看起来违反直觉，但却是一种必要行为。 我们不希望在优先级较高的资源受到阻止时，还阻止服务器处理优先级较低的资源。


### 4. 优先级的状态管理

从依赖关系树中删除一个 stream 流时，可以将其依赖关系移动为依赖于关闭流的父级。新的依赖关系的权重会被重新计算，计算方式是基于依赖性的权重关系，按比例重新分配已经关闭的 stream 流依赖性的权重。

从依赖关系树中删除的流会导致某些优先级信息丢失。资源在具有相同父级的流之间共享，这意味着如果该集合中的某一个流被关闭或被 block，则分配给这个流的任何备用容量将分配给这个流的直接邻居。但是，如果从树中删除了公共依赖项，则这些流与下一个最高级别的流一起共享资源。

例如，假设流 A 和 B 共享一个父节点，并且流 C 和 D 都依赖于流 A。在移除流 A 之前，如果流 A 和 D 不能继续处理数据，则流 C 接收所有专用于流 A 的资源。如果从树中移除流 A，则在流 C 和 D 之间重新划分流 A 的权重。如果流 D 仍然不能继续处理数据，则这导致流 C 接收到的资源比例减少。对于相等的起始权重，C 接收到可用资源的三分之一而不是一半。

存在这样一种情况，在创建对某一个流的依赖的优先级信息正在网络传输过程中，这个流突然被关闭了。 如果依赖项中标识的流没有关联的优先级信息，则为依赖流分配默认的优先级([第 5.3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7))。这可能会产生次优的优先级，因为流可能会被赋予与预期不同的优先级。为了避免这些问题，端点应该在流关闭后的一段时间内保留这个流的优先级状态。保留的状态越长，为流分配不正确或默认优先级值的可能性就越小。

类似地，处于"空闲"状态的流可以被分配优先级或成为其他流的父级。这允许在依赖关系树中创建分组节点，这使得能够实现更灵活的优先级表达。空闲的流从默认优先级开始启动([第 5.3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7))。

保留未计入 SETTINGS\_MAX\_CONCURRENT\_STREAMS 设置的限制的流的优先级信息，可能会给端点带来很大的状态负担。因此，可以限制保留的优先级状态的量。

端点维持优先级的附加状态量可能取决于负载；在高负载下，可以丢弃优先级状态以限制资源的提交。在极端情况下，端点甚至可以丢弃活跃的流或者保留的流的优先级状态。如果遵守了限制，端点应该至少保持其设置为 SETTINGS\_MAX\_CONCURRENT\_STREAMS 这么多的流的状态。实现方应该也尝试保留优先级树中正在使用的流的状态。

如果它保留了足够的状态，那么接收到 PRIORITY 帧的端点在改变关闭流的优先级的时候，应该改变依赖于它的流的依赖性。

### 5. 默认优先级

所有的 stream 流默认都会在 0x0 流上分配一个非独占的依赖。推送流([第 8.2 节]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push)))最初取决于它们的相关联的流。在这两种情况下，都会为流分配默认权重 16。




## 七. 错误处理

HTTP/2 成帧允许两类错误：

- 使整个连接不可用的错误是连接错误。

- 单个流中的错误是流错误。

[第 7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)中包含错误代码列表。


### 1. 连接错误的错误处理

连接错误指的是阻止进一步处理帧层或者破坏任何连接状态的所有错误。

遇到连接错误的端点应首先发送 GOAWAY 帧([第 6.8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7))，其中包含从其对等方成功接收的最后一个流的流标识符。GOAWAY 帧包含一个错误代码，这个错误代码用于标识连接终止的原因。在发送错误条件的 GOAWAY 帧之后，端点必须关闭 TCP 连接。

接收端点可能无法可靠地接收 GOAWAY 帧([[RFC7230] 中的 第 6.6 节](https://tools.ietf.org/html/rfc7230#section-6.6)描述了立即连接关闭会导致数据丢失)。如果发生连接错误，GOAWAY 帧会尽力尝试与对端通信以提供连接终止的原因。

端点可以随时终止连接。特别是，端点可以选择将 stream 流错误视为连接错误。在情况允许的情况下，端点应该在结束连接时发送 GOAWAY 帧。


### 2. 流错误的错误处理

stream 流错误是与特定一个流相关的错误，它不会影响到其他流的处理。

检测到 stream 流错误的端点会发送一个 RST\_STREAM 帧([第 6.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%9B%9B-rst_stream-%E5%B8%A7))，该帧包含发生错误的流的流标识符。RST\_STREAM 帧包含指示错误类型的错误代码。

RST\_STREAM 是端点可以在 stream 流上发送的最后一帧。发送 RST\_STREAM 帧的对端必须准备好接收一些帧，这些帧是由远程对端发送或入队以供发送的任何帧。除非它们修改连接状态(例如为头压缩([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)或流量控制而维护的状态)，否则可以忽略这些帧。

通常，端点不应该为任何流发送多个 RST\_STREAM 帧。但是，如果端点在超过往返时间之后在关闭的流上接收帧，则端点可以发送额外的 RST\_STREAM 帧。这个行为可以用来处理一些不正确的实现。

为避免循环，端点不得发送 RST\_STREAM 用来响应 RST\_STREAM 帧。

### 3. 连接终止

如果在流保持 "打开" 或 "半关闭" 状态时关闭或重置 TCP 连接，则无法自动重试受影响的流（有关详细信息，请参阅[第 8.1.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2)）

## 八. HTTP/2 中的扩展

HTTP/2 允许扩展协议。在本章节描述的限制范围内，协议扩展可用于提供附加服务或更改协议的任何方面。扩展仅在单个 HTTP/2 连接的范围内有效。

这适用于 HTTP/2 规范中定义的协议元素。这不会影响扩展 HTTP 的现有选项，例如定义新方法，状态代码或标头字段。

允许扩展使用新的帧类型([第 4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F))，新设置([第 6.5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters))或新的错误代码([第 7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes))。建立注册管理机构来管理这些扩展点：frame 类型([第 11.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E5%B8%A7%E7%B1%BB%E5%9E%8B%E6%B3%A8%E5%86%8C))，设置([第 11.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#3-settings-%E6%B3%A8%E5%86%8C))和错误代码([第 11.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#4-%E9%94%99%E8%AF%AF%E7%A0%81%E6%B3%A8%E5%86%8C))。


实现方必须忽略所有可扩展协议元素中的未知值和不支持的值。实现方必须丢弃具有未知或不支持类型的帧。这意味着任何这些扩展点都可以被扩展安全的使用，无需事先安排或协商。但是，扩展帧不允许出现在 header block 标题块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))的中间，如果出现了这个情况，则必须被视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


有些扩展会改变现有协议组件的语义，这些扩展在使用前必须先协商。例如，在对端发出可接受的正信号之前，不能使用更改 HEADERS 帧布局的扩展。在这种情况下，也可能需要在修改后的布局生效的时候进行适配。注意，把除了 DATA 帧之外的任何帧都可以视为流量控制，这是语义上的改变，这种改变只能通过协商来完成。

HTTP/2 规范中没有规定谈判扩展使用的具体方法，但是设置帧([第 6.5.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters))可用于此目的。如果两个对端都设置了表示愿意使用扩展的值，则可以使用扩展。如果这个设置是用于扩展协商的，则必须以默认禁用扩展的方式来定义该初始值。




------------------------------------------------------

Reference：  

[RFC 7540](https://tools.ietf.org/html/rfc7540)    
[HTTP/2 简介](https://developers.google.com/web/fundamentals/performance/http2/?hl=zh-cn)    
[http2 讲解](https://legacy.gitbook.com/book/ye11ow/http2-explained/details)  

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
> 
> Source: [https://halfrost.com/http2-http-frames/](https://halfrost.com/http2-http-frames/)
> 