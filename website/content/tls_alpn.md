+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-08-11T07:43:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/135_0.png"
slug = "tls_alpn"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "TLS Application-Layer Protocol Negotiation Extension"

+++


这篇文章我们主要来讨论讨论 Transport Layer Security (TLS) 握手中的 Application-Layer Protocol Negotiation 扩展。对于在同一 TCP 或 UDP 端口上支持多个应用程序协议的实例，此扩展允许应用程序层去协商将在 TLS 连接中使用哪个协议。

## 一. Introduction

应用层协议越来越多地封装在 TLS 协议 [[RFC5246]](https://tools.ietf.org/html/rfc5246) 中。这种封装使应用程序可以使用几乎整个全球 IP 基础结构中已经存在的现有安全通信链路的 443 端口。

当单个服务器端端口号（例如端口 443）上支持多个应用程序协议时，客户端和服务器需要协商用于每个连接的应用程序协议。希望在不增加客户端和服务器之间的网络往返次数的情况下完成此协商，因为每次往返都会降低最终用户的体验。此外，允许基于协商的应用协议来选择证书将是有利的。

本文指定了 TLS 扩展，该扩展允许应用程序层在 TLS 握手中协商协议的选择。HTTPbis WG 要求进行这项工作，以解决通过 TLS 进行 HTTP/2（[[HTTP2]](https://tools.ietf.org/html/rfc7301#ref-HTTP2)）的协商。但是，ALPN 有助于协商任意应用程序层协议。

借助 ALPN，客户端会将支持的应用程序协议列表作为 TLS ClientHello 消息的一部分发送。服务器选择一个协议，并将所选协议作为 TLS ServerHello 消息的一部分发送。因此，可以在 TLS 握手中完成应用协议协商，而无需添加网络往返，并且允许服务器根据需要，将不同的证书与每个应用协议相关联。


## 二. Application-Layer Protocol Negotiation


### 1. The Application-Layer Protocol Negotiation Extension

定义了一个新的扩展类型("application\_layer\_protocol\_negotiation(16)")，客户端可以在其 “ClientHello” 消息中包含该扩展类型。

```c
   enum {
       application_layer_protocol_negotiation(16), (65535)
   } ExtensionType;
```

("application\_layer\_protocol\_negotiation(16)") 扩展名的 "extension\_data" 字段应包含 "ProtocolNameList" 值。

```c
   opaque ProtocolName<1..2^8-1>;

   struct {
       ProtocolName protocol_name_list<2..2^16-1>
   } ProtocolNameList;
```

"ProtocolNameList" 按优先级从高到低包含客户端发布的协议列表。 协议是由 IANA 注册的不透明非空字节串命名的，如本文档第 6 节("IANA 注意事项")中所述。不能包含空字符串，并且不能截断字节字符串。


接收到包含 "application\_layer\_protocol\_negotiation" 扩展名的 ClientHello 的服务器可以向客户端返回合适的协议选择作为响应。服务器将忽略它无法识别的任何协议名称。一个新的 ServerHello 扩展类型("application\_layer\_protocol\_negotiation(16)") 可以在 ServerHello 消息扩展中返回给客户端。("application\_layer\_protocol\_negotiation(16)") 扩展名的 "extension\_data" 字段的结构与上述针对客户端 "extension\_data" 的描述相同，只是 "ProtocolNameList" 必须包含一个 "ProtocolName"。

因此，ClientHello 和 ServerHello 消息中带有" application\_layer\_protocol\_negotiation" 扩展名的完整握手具有以下流程（与 [[RFC5246]的 7.3 节](https://tools.ietf.org/html/rfc5246#section-7.3)相比）：

```c
   Client                                              Server

   ClientHello                     -------->       ServerHello
     (ALPN extension &                               (ALPN extension &
      list of protocols)                              selected protocol)
                                                   Certificate*
                                                   ServerKeyExchange*
                                                   CertificateRequest*
                                   <--------       ServerHelloDone
   Certificate*
   ClientKeyExchange
   CertificateVerify*
   [ChangeCipherSpec]
   Finished                        -------->
                                                   [ChangeCipherSpec]
                                   <--------       Finished
   Application Data                <------->       Application Data

                                 Figure 1

   * Indicates optional or situation-dependent messages that are not always sent.
```

带有 "application\_layer\_protocol\_negotiation" 扩展名的简短握手具有以下流程：

```c
   Client                                              Server

   ClientHello                     -------->       ServerHello
     (ALPN extension &                               (ALPN extension &
      list of protocols)                              selected protocol)
                                                   [ChangeCipherSpec]
                                   <--------       Finished
   [ChangeCipherSpec]
   Finished                        -------->
   Application Data                <------->       Application Data
```

与许多其他 TLS 扩展不同，此扩展不建立会话的属性，仅建立连接的属性。当使用会话恢复或会话票证 [[RFC5077]](https://tools.ietf.org/html/rfc5077) 时，此扩展的先前内容无关紧要，并且只用考虑新握手消息中的值。



### 2. Protocol Selection


期望服务器将具有优先级支持的协议列表，并且仅在客户端支持的情况下才选择协议。在这种情况下，服务器应该选择它所支持的，并且也是由客户端发布的最优先的协议。如果服务器不支持客户端传过来的协议，则服务器应以 "no\_application\_protocol" alert 错误回应。

```c
   enum {
       no_application_protocol(120),
       (255)
   } AlertDescription;
```

在重新协商之前，ServerHello 的 "application\_layer\_protocol\_negotiation" 扩展类型中标识的协议将此连接是确定的。服务器不会响应所选协议，并随后使用其他协议进行应用程序数据交换。

## 三. Design Considerations

ALPN 扩展旨在遵循 TLS 协议扩展的典型设计。具体而言，根据已建立的 TLS 体系结构，协商完全在 client/server hello 交换中执行。 ServerHello 的扩展 "application\_layer\_protocol\_negotiation" 旨在确定连接中选择的协议(直到重新协商连接)，并以纯文本形式发送，以允许网络元素在应用程序还没确定应用层协议的情况下，导致的 TCP 或 UDP 端口号不确定时，为连接提供差异化​​服务。通过将协议选择的所有权放在服务器上， ALPN 促进以下场景：证书选择或连接重新路由，这两者可能会基于协商的协议。

最终，通过在握手过程中以明文方式管理协议选择，ALPN 避免了在建立连接之前就隐藏协商协议而引入错误。如果需要隐藏协议，则在建立连接后进行重新协商（这将提供真正的 TLS 安全保证）将是首选方法。


## 四. Security Considerations


ALPN 扩展不会影响 TLS 会话建立或应用程序数据交换的安全性。ALPN 用于为与 TLS 连接关联的应用程序层协议提供一个外部可见的标记。从历史上看，可以从使用中的 TCP 或 UDP 端口号确定与连接关联的应用程序层协议。

打算通过添加新协议标识符来扩展协议标识符注册表的实现方和文档编辑者，应考虑到在 TLS 版本 1.2 及以下版本中，客户端以明文形式发送这些标识符。他们还应该考虑到，至少在接下来的十年中，预计浏览器通常会在初始 ClientHello 中使用这些早期版本的 TLS。

当此类标识符可能泄露个人可识别信息时，或当此类泄露可能导致概要分析或泄露敏感信息时，必须格外小心。如果这些标识符中的任何一个适用于此新协议标识符，则该标识符不应在清晰可见的 TLS 配置中使用，并且指定此类协议标识符的文档应建议避免这种不安全使用。

## 五. IANA Considerations

IANA 已更新其 "ExtensionType 值" 注册表，以包括以下条目：

```c
      16 application_layer_protocol_negotiation
```

本文在现有的 "传输层安全性（TLS）扩展" 标题下为标题为“应用层协议协商（ALPN）协议 ID”的协议标识符建立了注册表。

此注册表中的条目需要以下字段：

- Protocol：协议名称。
- Identification Sequence：标识协议的一组精确的八位字节值。这可以是协议名称的 UTF-8 编码 [[RFC3629]](https://tools.ietf.org/html/rfc3629)。
- Reference：对定义协议的规范的参考。


该注册表在 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中定义的 "Expert Review" 策略下运行。建议指定的专家鼓励加入对永久性和易于获得的规范的引用，该规范能够创建所标识协议的可互操作的实现。

此注册表的初始注册集如下：

Protocol:  HTTP/1.1  
Identification Sequence:  
      0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x31 ("http/1.1")  
Reference:  [[RFC7230]](https://tools.ietf.org/html/rfc7230)

Protocol:  SPDY/1  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x31 ("spdy/1")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1)

Protocol:  SPDY/2  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x32 ("spdy/2")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2)
      
Protocol:  SPDY/3  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x33 ("spdy/3")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3)

------------------------------------------------------

Reference：
  
[RFC 7301](https://tools.ietf.org/html/rfc7301)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/tls\_alpn/](https://halfrost.com/tls_alpn/)



