# TLS 1.3 Introduction


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/95_0.png'>
</p>


## 一、TLS 协议的目的

TLS 的主要目标是为通信的双方提供一个安全的通道。对下层传输的唯一要求是一个可靠的有序的数据流。

- 认证： 通道的 Server 端应该总是被认证的；Client 端是可选的被认证。认证可以通过非对称算法（例如，RSA, 椭圆曲线数字签名算法(ECDSA)，或 Edwards 曲线数字签名算法(EdDSA)）完成，或通过一个对称的预共享密钥（PSK)。

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

- TLS1.2 的版本协商机制被废弃。支持在扩展中使用版本列表。这增加了与不正确地实现版本协商的 Server 的兼容性。

- 带有和不带 Server 端状态的会话恢复以及 TLS 早期版本的基于 PSK 密码套件已经被一个单独的新 PSK 交换所取代。

- 酌情更新引用以指向最新版本的 RFC（例如，RFC 5280 而不是 RFC 3280）。

## 四、对 TLS 1.2 产生影响的改进

TLS 1.3 规范中还定义了一些可选的针对 TLS 1.2 的实现，包括那些不支持 TLS 1.3 的实现。

- TLS 1.3 中定义的版本降级保护机制
- RSASSA-PSS 签名方案
- ClientHello 中 “supported_versions” 的扩展可以被用于协商 TLS 使用的版本，它优先于 ClientHello 中的 legacy\_version 域。
- "signature\_algorithms\_cert" 扩展允许一个 Client 显示它使用哪种签名算法验证 X.509 证书。

## 五、TLS 1.3 协议概览

安全通道所使用的密码参数由 TLS 握手协议生成。这个 TLS 的子协议，握手协议在 Client 和 Server 第一次通信时使用。握手协议允许两端协商一个协议版本，选择密码算法，选择性互相认证，并建立共享的密钥数据。一旦握手完成，双方就会使用建立好的密钥保护应用层数据。

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
() 表示消息由从 Client\_early\_traffic\_secret 导出的密钥保护  
{} 表示消息使用从一个 [sender]\_handshake\_traffic\_secret 导出的密钥保护  
[] 表示消息使用从 [sender]\_application\_traffic\_secret\_N 导出的密钥保护  

握手可以被认为有三个阶段（见上图）：

- 密钥交换：建立共享密钥数据并选择密码参数。在这个阶段之后所有的数据都会被加密。
- Server 参数：建立其它的握手参数（Client 是否被认证，应用层协议支持等）。
- 认证：认证 Server（并且选择性认证 Client），提供密钥确认和握手完整性。

在密钥交换阶段，Client 会发送 ClientHello 消息，其中包含了一个随机 nonce(ClientHello.random)；它提供了协议版本，一个对称密码/HKDF hash 对的列表；一个 Diffie-Hellman 密钥共享集合或一个预共享密钥标签（在 "key\_share" 扩展中）集合，或二者都有；和可能的其它扩展。

Server 处理 ClientHello 并为连接确定合适的密码参数。然后它会以自己的 ServerHello 作为响应，其中表明了协商好的连接参数。ClientHello 和 ServerHello 合在一起来确定共享密钥。如果已经建立的 (EC)DHE 密钥正在被使用，则 ServerHello 中会包含一个 ”key\_share” 扩展，和这个扩展一起的还有 Server 的临时 Diffie-Hellman 共享参数，这个共享参数必须与 Client 的一个共享参数在相同的组里。如果使用的是 PSK 密钥，则 ServerHello 中会包含一个 "pre\_shared\_key" 扩展以表明 Client 提供的哪一个 PSK 被选中。需要注意的是实现上可以将 (EC)DHE 和 PSK 一起使用，这种情况下两种扩展都需要提供。

随后 Server 会发送两个消息来建立 Server 参数：

- EncryptedExtensions: 对 ClientHello 扩展的响应，不需要确定加密参数，而不是特定于各个证书的加密参数。  
- CertificateRequest: 如果需要基于证书的客户端身份验证，则所需参数是证书。 如果不需要客户端认证，则省略此消息。

最后，Client 和 Server 交换认证消息。TLS 在每次基于证书的认证时使用相同的消息集，(基于 PSK 的认证是密钥交换中的一个副作用)特别是：

- Certificate: 终端的证书和每个证书的扩展。 服务器如果不通过证书进行身份验证，并且如果服务器没有发送CertificateRequest（由此指示客户端不应该使用证书进行身份验证），客户端将忽略此消息。 请注意，如果使用原始公钥 [[RFC7250]](https://tools.ietf.org/html/rfc7250) 或缓存信息扩展 [[RFC7924]](https://tools.ietf.org/html/rfc7924)，则此消息将不包含证书，而是包含与服务器长期密钥相对应的其他值。

- CertificateVerify: 使用与证书消息中的公钥配对的私钥对整个握手消息进行签名。如果终端没有使用证书进行验证则此消息会被忽略。
- Finished: 对整个握手消息的 MAC(消息认证码)。这个消息提供了密钥确认，将终端身份与交换的密钥绑定在一起，这样在 PSK 模式下也能认证握手。

接收到 Server 的消息之后，Client 会响应它的认证消息，即 Certificate，CertificateVerify (如果需要), 和 Finished。

这时握手已经完成，client 和 server 会提取出密钥用于记录层交换应用层数据，这些数据需要通过认证的加密来保护。应用层数据不能在 Finished 消息之前发送数据，必须等到记录层开始使用加密密钥之后才可以发送。需要注意的是 server 可以在收到 client 的认证消息之前发送应用数据，任何在这个时间点发送的数据，当然都是在发送给一个未被认证的对端。

### 1. 错误的 DHE 共享

如果 client 没有提供一个充分的 ”key\_share” 扩展（例如，它只包含 server 不接受或不支持的 DHE 或 ECDHE 组），server 会使用一个 HelloRetryRequest 来纠正这个不匹配问题，client 需要使用一个合适的 ”key\_share” 扩展来重启握手，如下图所示。如果没有通用的密码参数能够协商，server 必须发出一个适当的警报来中止握手。

```c
        Client                                               Server

        ClientHello
        + key_share             -------->
                                                  HelloRetryRequest
                                <--------               + key_share
        ClientHello
        + key_share             -------->
                                                        ServerHello
                                                        + key_share
                                              {EncryptedExtensions}
                                              {CertificateRequest*}
                                                     {Certificate*}
                                               {CertificateVerify*}
                                                         {Finished}
                                <--------       [Application Data*]
        {Certificate*}
        {CertificateVerify*}
        {Finished}              -------->
        [Application Data]      <------->        [Application Data]

```

如上图，一个带有不匹配参数的完整握手过程的消息流程

> 注意，这个握手过程包含初始的 ClientHello/HelloRetryRequest 交换；它不能被新的 ClientHello 重置。

TLS还允许基本握手的几种优化变体，如以下部分所述。

### 2. 复用和预共享密钥（Pre-Shared Key，PSK）

虽然 TLS 预共享密钥（PSK）能够在带外建立，预共享密钥也能在一个之前的连接中建立然后重用（会话恢复）。一旦一次握手完成，server 就能给 client 发送一个与一个独特密钥对应的 PSK 密钥，这个密钥来自初次握手。然后 client 能够使用这个 PSK 密钥在将来的握手中协商相关 PSK 的使用。如果 server 接受它，新连接的安全上下文在密码学上就与初始连接关联在一起，从初次握手中得到的密钥就会用于装载密码状态来替代完整的握手。在 TLS 1.2 以及更低的版本中，这个功能由 "session IDs" 和 "session tickets" [[RFC5077]](https://tools.ietf.org/html/rfc5077)来提供。这两个机制在 TLS 1.3 中都被废除了。

PSK 可以与 (EC)DHE 密钥交换算法一同使用以便使共享密钥具备前向安全，或者 PSK 可以被单独使用，这样是以丢失了应用数据的前向安全为代价。

下图显示了两次握手，第一次建立了一个 PSK，第二次时使用它：


```c
          Client                                               Server

   Initial Handshake:
          ClientHello
          + key_share               -------->
                                                          ServerHello
                                                          + key_share
                                                {EncryptedExtensions}
                                                {CertificateRequest*}
                                                       {Certificate*}
                                                 {CertificateVerify*}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Certificate*}
          {CertificateVerify*}
          {Finished}                -------->
                                    <--------      [NewSessionTicket]
          [Application Data]        <------->      [Application Data]


   Subsequent Handshake:
          ClientHello
          + key_share*
          + pre_shared_key          -------->
                                                          ServerHello
                                                     + pre_shared_key
                                                         + key_share*
                                                {EncryptedExtensions}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Finished}                -------->
          [Application Data]        <------->      [Application Data]

```
          
当 server 通过一个 PSK 进行认证时，它不会发送一个 Certificate 或一个 CertificateVerify 消息。当一个 client 通过 PSK 想恢复会话的时候，它也应当提供一个 "key\_share" 给 server，以允许 server 拒绝恢复会话的时候降级到重新回答一个完整的握手流程中。Server 响应 "pre\_shared\_key" 扩展，使用 PSK 密钥协商建立连接，同时响应 "key\_share" 扩展来进行 (EC)DHE 密钥建立，由此提供前向安全。

当 PKS 在带外提供时，PSK 密钥和与 PSK 一起使用的 KDF hash 算法也必须被提供。

> 注意：当使用一个带外提供的预共享密钥时，一个关键的考虑是在密钥生成时使用足够的熵，就像 [[RFC4086]](https://tools.ietf.org/html/rfc4086) 中讨论的那样。从一个口令或其它低熵源导出的一个共享密钥并不安全。一个低熵密码，或口令，易遭受基于 PSK 绑定器的字典攻击。指定的 PSK 密钥并不是一个基于强口令的已认证的密钥交换，即使使用了 Diffie-Hellman 密钥建立方法。具体来说，它不会阻止可以观察到握手过程的攻击者对密码/预共享密钥进行暴力攻击。

### 3. 0-RTT 数据

当 client 和 server 共享一个 PSK（从外部获得或通过一个以前的握手获得）时，TLS 1.3 允许 client 在第一个发送出去的消息中携带数据（"early data"）。Client 使用这个 PSK 来认证 server 并加密 early data。

如下图所示，0-RTT 数据在第一个发送的消息中被加入到 1-RTT 握手过程中。握手的其余消息与带 PSK 会话恢复的 1-RTT 握手消息相同。

```c
         Client                                               Server

         ClientHello
         + early_data
         + key_share*
         + psk_key_exchange_modes
         + pre_shared_key
         (Application Data*)     -------->
                                                         ServerHello
                                                    + pre_shared_key
                                                        + key_share*
                                               {EncryptedExtensions}
                                                       + early_data*
                                                          {Finished}
                                 <--------       [Application Data*]
         (EndOfEarlyData)
         {Finished}              -------->
         [Application Data]      <------->        [Application Data]
```

上图是 0-RTT 的信息流

\+  标明是在以前标注的消息中发送的值得注意的扩展  
\*  表示可选的或者依赖一定条件的消息/扩展，它们不总是发送  
() 表示消息由从client\_early\_traffic\_secret导出的密钥保护  
{} 表示消息使用从一个[sender]\_handshake\_traffic\_secret导出的密钥保护    
[]表示消息使用从[sender]\_application\_traffic\_secret\_N导出的密钥保护  


0-RTT 数组安全性比其他类型的 TLS 数据要弱一些，特别是：

1. 0-RTT 的数据是没有前向安全性的，它使用的是被提供的 PSK 中导出的密钥进行加密的。
2. 在多个连接之间不能保证不存在重放攻击。普通的 TLS 1.3 1-RTT 数据为了防止重放攻击的保护方法是使用 server 下发的随机数，现在 0-RTT 不依赖于 ServerHello 消息，因此保护措施更差。如果数据与 TLS client 认证或与应用协议里一起验证，这一点安全性的考虑尤其重要。这个警告适用于任何使用 early\_exporter\_master\_secret 的情况。

0-RTT 数据不能在连接中被复制（即 server 不会为同一连接处理相同的数据两次），并且攻击者将无法使 0-RTT 数据伪装起来像 1-RTT数据（因为它受不同的密钥保护）。

关于 0-RTT 的安全性，会单独有一篇文章来讨论。


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Introduction/](https://halfrost.com/tls_1-3_introduction/)