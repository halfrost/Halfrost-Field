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


## 三、TLS 1.3 和 TLS 1.2 主要的不同

下面描述了 TLS 1.2 和 TLS 1.3 的主要的差异。除去这些主要的差别以外，还有很多细微的不同。

- 已支持的对称算法的列表已经去除了已经不再安全的算法了。列表保留了所有使用“带关联数据的认证加密”（AEAD）算法。 加密套件概念已经被改变，从记录保护算法（包括密钥长度）和一个用于密钥生成函数的 hash 和 HMAC 中分离为：认证、密钥交换机制。

- 增加了一个 0-RTT 模式，为一些应用数据在连接建立阶段节省了一次往返，这是以牺牲一定的安全特性为代价的。**关于 0-RTT 的安全问题，下面会专门讨论**。

- 静态 RSA 和 Diffie-Hellman 密码套件已经被删除；所有基于公钥的密钥交换算法现在都能提供前向安全。

- 所有 ServerHello 之后的握手消息现在都已经加密。新引入的 EncryptedExtension 消息允许之前在 ServerHello 中以明文发送的各种扩展同样享有保密性。

- 密钥导出函数被重新设计。新的设计使得密码学家能够通过改进的密钥分离特性进行更容易的分析。基于 HMAC 的提取 --- 扩展密钥导出函数（HMAC-based Extract-and-Expand Key Derivation Function，HKDF）被用作一个基础的原始组件（primitive）。

- **握手状态机已经进行了重大调整**，以便更具一致性，删除多余的消息如 ChangeCipherSpec (除了由于中间件兼容性被需要时)。

- 椭圆曲线算法已经属于基本的规范，且包含了新的签名算法，如 EdDSA。TLS 1.3 删除了点格式协商以利于每个曲线使用单点格式。

- 其它的密码学改进包括改变 RSA 填充以使用 RSA 概率签名方案（RSASSA-PSS），删除压缩，DSA，和定制 DHE 组。

- TLS1.2 的版本协商机制被废弃。支持在扩展中使用版本列表。这增加了与不正确地实现版本协商的 server 的兼容性。

- 带有和不带 server 端状态的会话恢复以及 TLS 早期版本的基于 PSK 密码套件已经被一个单独的新 PSK 交换所取代。

- 酌情更新引用以指向最新版本的 RFC（例如，RFC 5280 而不是 RFC 3280）。

## 四、对 TLS 1.2 产生影响的改进

TLS 1.3 规范中还定义了一些可选的针对 TLS 1.2 的实现，包括那些不支持 TLS 1.3 的实现。

- TLS 1.3 中定义的版本降级保护机制
- RSASSA-PSS 签名方案
- ClientHello 中 “supported_versions” 的扩展可以被用于协商 TLS 使用的版本，它优先于 ClientHello 中的 legacy\_version 域。
- "signature\_algorithms\_cert" 扩展允许一个 client 显示它使用哪种签名算法验证 X.509 证书。

## 五、TLS 1.3 协议概览

安全通道所使用的密码参数由 TLS 握手协议生成。这个 TLS 的子协议，握手协议在 client 和 server 第一次通信时使用。握手协议允许两端协商一个协议版本，选择密码算法，选择性互相认证，并建立共享的密钥数据。一旦握手完成，双方就会使用建立好的密钥保护应用层数据。

一个失败的握手或其它的协议错误会触发连接的中止，在这之前可以有选择地发送一个警报消息，遵循 Alert Protocol 协议。

TLS 1.3 支持 3 种基本密钥交换模式：

- (EC)DHE (基于有限域或椭圆曲线的 Diffie-Hellman)
-  PSK - only
-  PSK with (EC)DHE

下图显示了 TLS 握手的全部流程：

```c
       Client                                           Server

Key  ^ ClientHello
Exch | + key_share*
     | + signature_algorithms*
     | + psk_key_exchange_modes*
     v + pre_shared_key*       -------->
                                                  ServerHello  ^ Key
                                                 + key_share*  | Exch
                                            + pre_shared_key*  v
                                        {EncryptedExtensions}  ^  Server
                                        {CertificateRequest*}  v  Params
                                               {Certificate*}  ^
                                         {CertificateVerify*}  | Auth
                                                   {Finished}  v
                               <--------  [Application Data*]
     ^ {Certificate*}
Auth | {CertificateVerify*}
     v {Finished}              -------->
       [Application Data]      <------->  [Application Data]

```

\+  表示的是在以前标注的消息中发送的值得注意的扩展  
\*  表示可选的或者依赖一定条件的消息/扩展，它们不总是发送  
() 表示消息由从 client\_early\_traffic\_secret 导出的密钥保护  
{} 表示消息使用从一个 [sender]\_handshake\_traffic\_secret 导出的密钥保护  
[] 表示消息使用从 [sender]\_application\_traffic\_secret\_N 导出的密钥保护  

握手可以被认为有三个阶段（见上图）：

- 密钥交换：建立共享密钥数据并选择密码参数。在这个阶段之后所有的数据都会被加密。
- Server 参数：建立其它的握手参数（client 是否被认证，应用层协议支持等）。
- 认证：认证 server（并且选择性认证 client），提供密钥确认和握手完整性。

        

------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()