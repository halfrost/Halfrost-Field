# TLS 1.3 Compliance Requirements


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/113_0.png'>
</p>

## 一. Mandatory-to-Implement Cipher Suites

TLS 1.3 中有一些密码套件是强制必须实现的。

> 在本文下面的描述中，“必须” 代表 MUST，“应该”代表 SHOULD。请读者注意措辞。

在没有应用程序配置文件标准指定的情况下，除此以外都需要满足以下要求：

符合 TLS 标准的应用程序必须实现 TLS\_AES\_128\_GCM\_SHA256 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) 密码套件，应该实现TLS\_AES\_256\_GCM\_SHA384 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) 和 TLS\_CHACHA20\_POLY1305\_SHA256 [[RFC8439]](https://tools.ietf.org/html/rfc8439) 密码套件（请参阅 [附录 B.4](https://tools.ietf.org/html/rfc8446#appendix-B.4)）

符合 TLS 标准的应用程序必须支持数字签名 rsa\_pkcs1\_sha256(用于证书)，rsa\_pss\_rsae\_sha256（用于 CertificateVerify 和 证书）和ecdsa\_secp256r1\_sha256。一个符合 TLS 标准的应用程序必须支持与 secp256r1 的密钥交换(NIST P-256) 并且应该支持与 X25519 [[RFC7748]](https://tools.ietf.org/html/rfc7748) 的密钥交换。


## 二. Mandatory-to-Implement Extensions

TLS 1.3 中有一些扩展是强制必须实现的。

如果没有另外指定的应用程序配置文件标准，符合 TLS 标准的应用程序必须实现以下 TLS 扩展：

- 支持的版本（"supported\_versions"; [第 4.2.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions)）

- Cookie（"cookie";[第 4.2.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-cookie)）

- 签名算法（"signature\_algorithms"; [第 4.2.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms)）

- 签名算法证书("signature\_algorithms\_cert"; [第 4.2.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms))

- 协商组（"supported\_groups"; [第 4.2.7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups)）

- 密钥共享（"key\_share"; [第 4.2.8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)）

- 服务器名称标识（"server\_name"; [[RFC6066]的第 3 节](https://tools.ietf.org/html/rfc6066#section-3)）

所有的实现方必须在协商时发送和使用这些扩展：

- 所有 ClientHello，ServerHello，HelloRetryRequest 都需要 "supported\_versions"。

- 证书认证需要 "signature\_algorithms"。

- 对于使用 DHE 或 ECDHE 密钥交换的 ClientHello 消息，"supported\_groups" 是必需的。

- DHE 或 ECDHE 密钥交换需要 "key\_share"。

- PSK 密钥协议需要 "pre\_shared\_key"。

- 对于 PSK 密钥协议，"psk\_key\_exchange\_modes" 是必需的。

如果 ClientHello 包含其 body 中包含 0x0304 的 "supported\_versions" 扩展，则客户端被认为会尝试使用此规范进行协商。这样的 ClientHello 消息必须满足以下要求：

- 如果不包含 "pre\_shared\_key" 扩展名，则它必须包含 "signature\_algorithms" 扩展名和 "supported\_groups" 扩展名。

- 如果包含 "supported\_groups" 扩展名，则它必须还包含 "key\_share" 扩展，反之亦然。允许空的 KeyShare.client\_shares 向量。

Server 如果接收到不符合上述这些要求的 ClientHello 消息，必须立即使用 "missing\_extension" alert 消息中止握手。

此外，所有实现方必须支持，能够使用它的应用程序使用 "server\_name" 扩展。Server可能要求 Client 发送有效的 "server\_name" 扩展名。需要此扩展的 Server 应该通过使用 "missing\_extension" alert 消息终止连接来响应缺少 "server\_name"扩展名的 ClientHello。

## 三. Protocol Invariants

本节介绍 TLS 终端和中间件必须遵循的不变的东西。它也适用于早期版本的 TLS。


TLS 设计的宗旨是安全且能兼容性地扩展。较新的 Client 或 Server 在与较新的对等方通信时，应协商最优选的公共参数。TLS 握手提供降级保护: 中间件在较新的 Client 和较新的 Server 之间传递流量而不终止 TLS ，中间件不能影响握手(参见附录 E.1)。同时，部署协议应该以不同的速率去更新，因此较新的 Client 或 Server 可以继续支持较旧的参数，这将允许它与较旧的终端进行互操作(向下兼容)。


为此，实现方必须正确处理可扩展字段:

- 发送 ClientHello 的 Client 必须支持其中公布的所有参数。否则，Server 可能无法通过选择其中一个参数进行互操作。

- 接收 ClientHello 的 Server 必须正确地忽略所有无法识别的密码套件，扩展和其他参数。否则，它可能无法与较新的 Client 互操作。在 TLS 1.3 中，接收 CertificateRequest 或 NewSessionTicket 的 Client 也必须忽略所有无法识别的扩展。

- 能终止 TLS 连接的中间件必须表现为兼容的 TLS 的 Server(对原始的 Client 来说)，包括具有 Client 愿意接受的证书，这个中间件也能作为兼容的 TLS 的 Client(对原始的 Server 来说)，包括验证原始 Server 的证书。特别是，它必须生成自己的 ClientHello，其中只包含它理解的参数，它必须生成一个新的 ServerHello 随机值，而不是转发终端的值。

请注意，TLS 的协议要求和安全性分析仅适用于两个分开的连接。如何安全地部署 TLS terminator 需要额外的安全注意事项，这超出了本文档的讨论范围。

- 如果中间件转发了自己不能理解的 ClientHello 参数，它不允许处理 ClientHello 之外的任何消息。它必须转发所有的未经修改的后续流量。否则，它可能无法与较新的 Client 和 Server 进行互操作。

转发的 ClientHellos 可能包含中间件不支持的功能，因此响应体里面可能包括中间件无法识别的未来 TLS 新添加的特性。这些新添加的特性可能会改变 ClientHello 以外的任何消息。特别是，ServerHello 中发送的值可能会变，ServerHello 格式可能会变，TLSCiphertext 格式也可能会变。


TLS 1.3 的设计受到了广泛部署却不符合 TLS 规范的中间件的限制(见附录 D.4);但是，它并没有放松不变的东西。这些中间件继续不符合规范。


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Compliance\_Requirements/](https://halfrost.com/tls_1-3_compliance_requirements/)