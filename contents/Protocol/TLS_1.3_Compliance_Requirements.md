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

- 支持的版本（"supported\_versions"; [第 4.2.1 节](https://tools.ietf.org/html/rfc8446#section-4.2.1)）

- Cookie（"cookie";[第 4.2.2 节](https://tools.ietf.org/html/rfc8446#section-4.2.2)）

- 签名算法（"signature\_algorithms"; [第 4.2.3 节](https://tools.ietf.org/html/rfc8446#section-4.2.3)）

- 签名算法证书("signature\_algorithms\_cert"; [第4.2.3节](https://tools.ietf.org/html/rfc8446#section-4.2.3))

- 协商组（"supported\_groups"; [第 4.2.7 节](https://tools.ietf.org/html/rfc8446#section-4.2.7)）

- 密钥共享（"key\_share"; [第 4.2.8 节](https://tools.ietf.org/html/rfc8446#section-4.2.8)）

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

------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()