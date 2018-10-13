# TLS 1.3 —— 概述


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/95_0.png'>
</p>


## 一、TLS 协议的目的

TLS 的主要目标是为通信的双方提供一个安全的通道。对下层传输的唯一要求是一个可靠的有序的数据流。

- 认证： 通道的 server 端应该总是被认证的；client 端是可选的被认证。认证可以通过非对称算法（例如，RSA, 椭圆曲线数字签名算法(ECDSA)，或 Edwards 曲线数字签名算法(EdDSA)）完成，或通过一个对称的预共享密钥（PSK)。

- 机密性：在建立完成的通道上发送的数据只能对终端是可见的。TLS 协议并不能隐藏它传输的数据的长度，但是终端能够通过填充 TLS 记录来隐藏长度，以此来提升针对流量分析技术的防护。

- 完整性：在建立完成的通道上面发送数据，不可能存在数据被篡改还没有发现的情况。即数据一旦被修改，对端会立即发现这个篡改。

> 以上 3 点是必须要保证的，即使网络攻击者已经完全掌握了网络，发生了 RFC 3552 中发生的情况。关于 TLS 安全问题，下面有单独的文章专门再讨论。

## 二、TLS 协议的组成

TLS 协议主要由 2 大组件组成：

- 握手协议  
  握手协议主要需要处理在通信双方之间进行认证的所有流程。包括密钥协商，参数协商，建立共享密钥。握手协议被设计用来抵抗篡改；如果连接未受到攻击，则活动攻击者不应该强制对等方协商不同的参数。

- 记录协议  
  使用由握手协议建立的参数来保护通信双方的流量。记录协议将流量分为一系列记录，每个记录独立地使用密钥来保护机密性。

TLS 是一个独立的协议；高层协议可以透明地位于 TLS 之上。然而，TLS 标准并未指定协议如何增强 TLS 的安全，如何发起 TLS 握手以及如何理解认证证书交换，这些都留给运行在 TLS 之上的协议的设计者和实现者来判断。

本文档定义了 TLS 1.3 版。虽然 TLS 1.3 不是直接的与之前的版本兼容，所有版本的TLS都包含一个版本控制机制，即允许客户端和服务器通过协商，选出通信过程中采用的 TLS 版本。

TLS 1.3 的标准中取代和废除了以前版本的 TLS，包括 1.2 版本[RFC5246 The Transport Layer Security (TLS) Protocol Version 1.2](https://tools.ietf.org/html/rfc5246)。也废除了在 [RFC5077 Transport Layer Security (TLS) Session Resumption without Server-Side State](https://tools.ietf.org/html/rfc5077) 里面定义的 TLS ticket 机制，并用 Pre-Shared Key (PSK) 机制取代它。由于 TLS 1.3 改变了密钥的导出方式，它更新了[RFC5705 Keying Material Exporters for Transport Layer Security (TLS)](https://tools.ietf.org/html/rfc5705)。它也改变了在线证书状态协议（OCSP）消息的传输方式，因此更新了[RFC6066 https://tools.ietf.org/html/rfc6066](https://tools.ietf.org/html/rfc6066)，废除了[RFC6961 he Transport Layer Security (TLS) Multiple Certificate Status Request Extension](https://tools.ietf.org/html/rfc6961)，如 OCSP Status and SCT Extensions 这一章节所述。

------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()