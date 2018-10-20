# TLS 1.3 Handshake Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/95_0.png'>
</p>


握手协议用于协商连接的安全参数。握手消息被提供给 TLS 记录层，在记录层它们被封装到一个或多个 TLSPlaintext 或 TLSCiphertext 中，它们按照当前活动连接状态进行处理和传输。

```c
      enum {
          client_hello(1),
          server_hello(2),
          new_session_ticket(4),
          end_of_early_data(5),
          encrypted_extensions(8),
          certificate(11),
          certificate_request(13),
          certificate_verify(15),
          finished(20),
          key_update(24),
          message_hash(254),
          (255)
      } HandshakeType;

      struct {
          HandshakeType msg_type;    /* handshake type */
          uint24 length;             /* remaining bytes in message */
          select (Handshake.msg_type) {
              case client_hello:          ClientHello;
              case server_hello:          ServerHello;
              case end_of_early_data:     EndOfEarlyData;
              case encrypted_extensions:  EncryptedExtensions;
              case certificate_request:   CertificateRequest;
              case certificate:           Certificate;
              case certificate_verify:    CertificateVerify;
              case finished:              Finished;
              case new_session_ticket:    NewSessionTicket;
              case key_update:            KeyUpdate;
          };
      } Handshake;
```

协议消息必须按照一定顺序发送(顺序见下文)。如果对端发现收到的握手消息顺序不对，必须使用 “unexpected\_message” alert 消息来中止握手。


另外 IANA 分配了新的握手消息类型，见[第5章]()

密钥交换消息用于确定安全性    客户端和服务器的功能以及建立共享    秘密，包括用于保护其余部分的交通密钥    握手和数据

## 一. Key Exchange Messages

密钥交换消息用于确保客户端和服务器的安全性和建立用于保护握手和数据的通信密钥的安全性。

### 1. Cryptographic Negotiation

在 TLS 协议中，密钥协商的过程中，client 在 ClientHello 中可以提供以下 4 种 options。


- 客户端支持的加密套件列表。密码套件里面中能体现出客户端支持的 AEAD 算法或者 HKDF 哈希对。
- “supported\_groups” 的扩展 和 "key\_share" 扩展。“supported\_groups” 这个扩展表明了客户端支持的 (EC)DHE groups，"key\_share" 扩展表明了客户端是否包含了一些或者全部的（EC）DHE共享。
- "signature\_algorithms" 签名算法和 "signature\_algorithms\_cert" 签名证书算法的扩展。"signature\_algorithms" 这个扩展展示了客户端可以支持了签名算法有哪些。"signature\_algorithms\_cert" 这个扩展展示了具体证书的签名算法。
- "pre\_shared\_key" 预共享密钥和 "psk\_key\_exchange\_modes" 扩展。预共享密钥扩展包含了客户端可以识别的对称密钥标识。"psk\_key\_exchange\_modes" 扩展表明了可能可以和 psk 一起使用的密钥交换模式。


如果服务端不选择 PSK，那么上面 4 个 option 中的前 3 个是正交的，服务端独立的选择一个加密套件，独立的选择一个 (EC)DHE 组，独立的选择一个用于建立连接的密钥共享，独立的选择一个签名算法/证书对用于给客户端验证服务端。如果服务端收到的 "supported\_groups" 中没有服务端能支持的算法，那么就必须返回 "handshake\_failure" 或者 "insufficient\_security" 的 alert 消息。

如果服务端选择了 PSK，它必须从客户端的 "psk\_key\_exchange\_modes" 扩展消息中选择一个密钥建立模式。这个时候 PSK 和 (EC)DHE 是分开的。在 PSK 和 (EC)DHE 分开的基础上，即使，"supported\_groups" 中不存在服务端和客户端相同的算法，也不会终止握手。

如果服务端选择了 (EC)DHE 组，并且客户端在 ClientHello 中没有提供合适的 "key\_share" 扩展，服务端必须用 HelloRetryRequest 消息作为回应。


如果服务端成功的选择了参数，也就不需要 HelloRetryRequest 消息了。服务端将发送 ServerHello 消息，它包含以下几个参数：

- 如果正在使用 PSK，服务端将发送 "pre\_shared\_key" 扩展，里面包含了选择的密钥。
- 如果没有使用 PSK，选择的 (EC)DHE，服务端将会提供一个 "key\_share" 扩展。通常，如果 PSK 没有使用，就会使用 (EC)DHE 和基于证书的认证。




------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()