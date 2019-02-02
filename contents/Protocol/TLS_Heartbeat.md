# TLS & DTLS Heartbeat Extension


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/118_0.png'>
</p>


这篇文章我们主要来讨论讨论 Transport Layer Security (TLS) 和 Datagram Transport Layer Security (DTLS) 中的 Heartbeat 扩展。

Heartbeat 扩展为 TLS/DTLS 提供了一种新的协议，允许在不需要重协商的情况下，使用 keep-alive 功能。Heartbeat 扩展也为 path MTU (PMTU) 发现提供了基础。

## 一. Introduction

这篇文章描述了 [[RFC5246]](https://tools.ietf.org/html/rfc5246) 和 [[RFC6347]](https://tools.ietf.org/html/rfc6347) 中定义的传输层安全性 (TLS) 和数据报传输层安全性 (DTLS) 协议的心跳扩展，以及它们对 [[RFC3436]](https://tools.ietf.org/html/rfc3436)，[[RFC5238]](https://tools.ietf.org/html/rfc5238) 和 [[RFC6083]](https://tools.ietf.org/html/rfc6083) 中描述的特定传输协议的适应性。

DTLS 协议设计的目的是，保护在不可靠的传输协议之上运行的流量数据。通常，此类协议没有会话管理。DTLS 层可用于确定对等方是否仍然 alive 的唯一机制是昂贵的重新协商机制，尤其是当应用程序使用单向流量时。此外，DTLS 需要执行路径 MTU (PMTU) 发现，但在不影响用户消息的传输的情况下，没有特定的消息类型来实现 PMTU 发现。

TLS 是基于可靠的协议，但没有必要的功能可以在没有连续数据传输的情况下保持连接存活。

本文中描述的心跳扩展克服了这些限制。用户可以使用新的 HeartbeatRequest 消息，该消息必须由具有 HeartbeartResponse 的对端立即应答。要执行 PMTU 发现，如 [RFC4821](https://tools.ietf.org/html/rfc4821) 中所述，可以将包含填充的 HeartbeatRequest 消息用作探测包。


## 二. Heartbeat Hello Extension

Hello Extensions 表示支持 Heartbeats。对端不仅可以表明其实现支持Heartbeats，还可以选择是否愿意接收 HeartbeatRequest 消息并使用 HeartbeatResponse 消息进行响应或仅发送 HeartbeatRequest 消息。前者通过使用 peer\_allowed\_to\_send 作为 HeartbeatMode 来表示;后者通过使用 peer\_not\_allowed\_to\_send 作为心跳模式来表示。每次重新谈判都可以改变这一决定。HeartbeatRequest 消息禁止发送到已经表明了 peer\_not\_allowed\_to\_send 的对端。如果已经表明了 peer\_not\_allowed\_to\_send 的端点收到 HeartbeatRequest 消息，则端点应该以静默方式丢弃该消息，并且可以发送 unexpected\_message Alert 消息。

Heartbeat Hello 扩展的格式定义如下：

```c
   enum {
      peer_allowed_to_send(1),
      peer_not_allowed_to_send(2),
      (255)
   } HeartbeatMode;

   struct {
      HeartbeatMode mode;
   } HeartbeatExtension;
```

收到未知模式后，必须发送使用 illegal\_parameter 作为其 AlertDescription 的错误警报消息作为响应。

## 三. Heartbeat Protocol

Heartbeat 协议是在记录层之上运行的新协议。协议本身由两种消息类型组成：HeartbeatRequest 和 HeartbeatResponse。

```c
   enum {
      heartbeat_request(1),
      heartbeat_response(2),
      (255)
   } HeartbeatMessageType;
```

HeartbeatRequest 消息几乎可以在连接的生命周期内的任何时间到达。每当收到 HeartbeatRequest 消息时，应该使用相应的 HeartbeatResponse 消息回答它。

但是，在握手期间不应发送 HeartbeatRequest 消息。如果在 HeartbeatRequest 仍处于传输的途中状态中时启动握手，则发送对等方必须为其停止 DTLS 重传计时器。如果在握手期间到达，接收对等方应该默默地丢弃该消息。在 DTLS 的情况下，应该丢弃来自较旧时期的 HeartbeatRequest 消息。

一次消息传输途中不得有多个 HeartbeatRequest 消息。在收到相应的 HeartbeatResponse 消息之前，或者直到重新传输计时器到期为止，在此之间，HeartbeatRequest 消息被认为是在传输途中。

当使用不可靠的传输协议(如数据报拥塞控制协议 (DCCP) 或 UDP)时，处理方法要如 [[RFC6347] 第4.2.4节](https://tools.ietf.org/html/rfc6347#section-4.2.4) 中所述，必须使用 DTLS 用于传输途中的简单超时和重传方案进行重新传输 HeartbeatRequest 消息。特别是，在没有接收到相应的具有预期有效 payload 的 HeartbeatResponse 消息并尝试多次重传之后，应该终止 DTLS 连接。用于此的阈值应该与用于 DTLS 握手消息的阈值相同。请注意，在监督 HeartbeatRequest 消息的计时器到期后，此消息不再考虑在传输的途中。因此，HeartbeatRequest 消息有资格重新传输。重传方案需要结合仅允许一个 HeartbeatRequest 在传输的途中的限制，确保在传输协议不提供一个 HeartbeatRequest 的情况下适当地处理拥塞控制，如在 DTLS over UDP 的情况下。

当使用可靠的传输协议(如流控制传输协议 (SCTP)或 TCP)时，HeartbeatRequest 消息只需要发送一次。传输层将处理重传。如果在一段时间后没有收到相应的 HeartbeatResponse 消息，则 DTLS/TLS 连接可以由发起 HeartbeatRequest 消息的应用程序终止。


## 四. Heartbeat Request and Response Messages

Heartbeat 协议消息由它们的类型和任意有效 payload 和填充 padding 组成。

```c
   struct {
      HeartbeatMessageType type;
      uint16 payload_length;
      opaque payload[HeartbeatMessage.payload_length];
      opaque padding[padding_length];
   } HeartbeatMessage;
```

根据 [[RFC6066]](https://tools.ietf.org/html/rfc6066) 中的定义，在协商的时候，HeartbeatMessage 的总长度不得超过 2 ^ 14 或 max\_fragment\_length。

- type:   
	消息类型，heartbeat\_request 或 heartbeat\_response。
	
- payload\_length:   
	payload 的长度。

- payload:  
	payload 有效载荷由任意内容组成。

- padding:  
	padding 填充是随机内容，接收方必须忽略。HeartbeatMessage 的长度为 TLS 的 TLSPlaintext.length 和 DTLS 的 DTLSPlaintext.length。此外，类型 type 字段的长度是 1 个字节，并且 payload\_length 的长度是 2 个字节。因此，padding\_length 是TLSPlaintext.length  -  payload\_length  -  3 用于 TLS，DTLSPlaintext.length  -  payload\_length  -  3 用于 DTLS。padding\_length 必须至少为 16。

HeartbeatMessage 的发送方必须使用至少 16 个字节的随机填充。必须忽略收到的HeartbeatMessage 消息的填充。


如果收到的 HeartbeatMessage 的 payload\_length 太大，则必须静默丢弃收到的HeartbeatMessage。

当收到 HeartbeatRequest 消息并且发送 HeartbeatResponse 时不被禁止，如本文档中其他地方所述，接收方必须发送相应的 HeartbeatResponse 消息，该消息携带接收到的 HeartbeatRequest 的有效载荷的副本。

如果收到的 HeartbeatResponse 消息不包含预期的有效负载 payload，则必须以静默方式丢弃该消息。如果它确实包含预期的有效载荷 payload，则必须停止重传定时器。


## 五. Use Cases

每个端点以一定的速率发送 HeartbeatRequest 消息，并使用特定用例所需的填充。端点不应期望其对等方发送 HeartbeatRequests。方向是独立的。

### 1. Path MTU Discovery

DTLS 执行路径 MTU 发现，如 [[RFC6347]的第4.1.1.1节](https://tools.ietf.org/html/rfc6347#section-4.1.1.1) 所述。[[RFC4821]](https://tools.ietf.org/html/rfc4821) 中给出了如何执行路径 MTU 发现的详细描述。必要的探测包是 HeartbeatRequest 消息。

对于 DTLS 使用 HeartbeatRequest 消息的这种方法类似于使用 [[RFC4820]](https://tools.ietf.org/html/rfc4820) 中定义的填充块 (PAD-chunk) 的流控制传输协议(SCTP)的方法。


### 2. Liveliness Check

发送 HeartbeatRequest 消息允许发送方确保它可以到达对等方并且对端是活动的。即使在 TLS/TCP 的情况下，这也允许以比 TCP keep-alive 特征允许的更高的速率进行检查。

除了确保对等方仍可访问外，发送 HeartbeatRequest 消息还会刷新所有相关 NAT 的 NAT 状态。

HeartbeatRequest 消息应该仅在至少多个往返时间长的空闲时段之后发送。该空闲时段应该可以配置多达几分钟的时间段并且可以下降到一秒的时间段。空闲时段的默认值应该是可配置的，但它也应该在每个对等的基础上可调。


## 六. IANA Considerations

IANA 已根据 [[RFC5246]](https://tools.ietf.org/html/rfc5246) 中指定的 "TLS ContentType Registry" 分配了心跳内容类型(24)。参考是 [[RFC 6520]](https://tools.ietf.org/html/rfc6520)。

IANA 已创建并现在维护心跳消息类型的新注册表。消息类型是 0 到 255(十进制)范围内的数字。IANA 已分配 heartbeat\_request(1) 和 heartbeat\_response(2) 消息类型。应保留值 0 和 255。此注册表使用 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中所述的专家审阅策略。参考是 [RFC 6520](https://tools.ietf.org/html/rfc6520)。

IANA 已根据 [RFC5246](https://tools.ietf.org/html/rfc5246) 中指定的 TLS "ExtensionType Values" 注册表分配了心跳扩展类型(15)。参考是 [RFC 6520](https://tools.ietf.org/html/rfc6520)。

IANA 已创建并现在维护心跳模式的新注册表。模式的数字范围为 0 到 255(十进制)。 IANA 已分配 peer\_allowed\_to\_send(1) 和 peer\_not\_allowed\_to\_send(2) 模式。应保留值 0 和 255。此注册表使用 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中所述的专家审阅策略。参考是 [RFC 6520](https://tools.ietf.org/html/rfc6520)。


## 七. Security Considerations

[[RFC5246]](https://tools.ietf.org/html/rfc5246) 和 [[RFC6347]](https://tools.ietf.org/html/rfc6347) 的安全注意事项适用于本文档。本文档未介绍任何新的安全注意事项。


------------------------------------------------------

Reference：
  
[RFC 6520](https://tools.ietf.org/html/rfc6520)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_Heartbeat/](https://halfrost.com/tls_heartbeat/)