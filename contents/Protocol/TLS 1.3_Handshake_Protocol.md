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

## 一. Key Exchange Messages

密钥交换消息用于确保 Client 和 Server 的安全性和建立用于保护握手和数据的通信密钥的安全性。

### 1. Cryptographic Negotiation

在 TLS 协议中，密钥协商的过程中，Client 在 ClientHello 中可以提供以下 4 种 options。


-  Client 支持的加密套件列表。密码套件里面中能体现出 Client 支持的 AEAD 算法或者 HKDF 哈希对。
- “supported\_groups” 的扩展 和 "key\_share" 扩展。“supported\_groups” 这个扩展表明了 Client 支持的 (EC)DHE groups，"key\_share" 扩展表明了 Client 是否包含了一些或者全部的（EC）DHE共享。
- "signature\_algorithms" 签名算法和 "signature\_algorithms\_cert" 签名证书算法的扩展。"signature\_algorithms" 这个扩展展示了 Client 可以支持了签名算法有哪些。"signature\_algorithms\_cert" 这个扩展展示了具体证书的签名算法。
- "pre\_shared\_key" 预共享密钥和 "psk\_key\_exchange\_modes" 扩展。预共享密钥扩展包含了 Client 可以识别的对称密钥标识。"psk\_key\_exchange\_modes" 扩展表明了可能可以和 psk 一起使用的密钥交换模式。


如果 Server 不选择 PSK，那么上面 4 个 option 中的前 3 个是正交的， Server 独立的选择一个加密套件，独立的选择一个 (EC)DHE 组，独立的选择一个用于建立连接的密钥共享，独立的选择一个签名算法/证书对用于给 Client 验证 Server 。如果 Server 收到的 "supported\_groups" 中没有 Server 能支持的算法，那么就必须返回 "handshake\_failure" 或者 "insufficient\_security" 的 alert 消息。

如果 Server 选择了 PSK，它必须从 Client 的 "psk\_key\_exchange\_modes" 扩展消息中选择一个密钥建立模式。这个时候 PSK 和 (EC)DHE 是分开的。在 PSK 和 (EC)DHE 分开的基础上，即使，"supported\_groups" 中不存在 Server 和 Client 相同的算法，也不会终止握手。

如果 Server 选择了 (EC)DHE 组，并且 Client 在 ClientHello 中没有提供合适的 "key\_share" 扩展， Server 必须用 HelloRetryRequest 消息作为回应。


如果 Server 成功的选择了参数，也就不需要 HelloRetryRequest 消息了。 Server 将发送 ServerHello 消息，它包含以下几个参数：

- 如果正在使用 PSK， Server 将发送 "pre\_shared\_key" 扩展，里面包含了选择的密钥。
- 如果没有使用 PSK，选择的 (EC)DHE， Server 将会提供一个 "key\_share" 扩展。通常，如果 PSK 没有使用，就会使用 (EC)DHE 和基于证书的认证。
- 当通过证书进行认证的时候， Server 会发送 Certificate 和 CertificateVerify 消息。在 TLS 1.3 的官方规定中，PSK 和 证书通常被用到，但是不是一起使用，未来的文档可能会定义如何同时使用它们。

如果 Server 不能协商出可支持的参数集合，即在 Client 和 Server 各自支持的参数集合中没有重叠，那么 Server 必须发送 "handshake\_failure" 或者 "insufficient\_security" 消息来中止握手。

### 2. Client Hello

当一个 Client 第一次连接一个 Server 时，它需要在发送第一条 TLS 消息的时候，发送 ClientHello 消息。当 Server 发送 HelloRetryRequest 消息的时候，Client 收到了以后也需要回应一条 ClientHello 消息。在这种情况下，Client 必须发送相同的无修改的 ClientHello 消息，除非以下几种情况：

- 如果 HelloRetryRequest 消息中包含了 "key\_share" 扩展，则将共享列表用包含了单个来自表明的组中的 KeyShareEntry 代替。
- 如果存在 “early\_data” 扩展则将其移除。 “early\_data” 不允许出现在 HelloRetryRequest 之后。
- 如果 HelloRetryRequest 中包含了 cookie 扩展，则需要包含一个。
- 如果重新计算了 "obfuscated\_ticket\_age" 和绑定值，同时(可选地)删除了任何不兼容 Server 展示的密码族的 PSK，则更新 "pre\_shared\_key" 扩展。
- 选择性地增加，删除或更改 ”padding” 扩展[RFC 7685]()的长度。
- 可能被允许的一些其他的修改。例如未来指定的一些扩展定义和 HelloRetryRequest 。

由于 TLS 1.3 **严禁重协商**，如果 Server 已经完成了 TLS 1.3 的协商了，在未来某一时刻又收到了 ClientHello ，Server 不应该理会这条消息，必须立即断开连接，并发送 "unexpected\_message" alert 消息。

如果一个 Server 建立了一个 TLS 以前版本的 TLS 连接，并在重协商的时候收到了 TLS 1.3 的 ClientHello ，这个时候，Server 必须继续保持之前的版本，严禁协商 TLS 1.3 。

ClientHello 消息的结构是

```c
      uint16 ProtocolVersion;
      opaque Random[32];

      uint8 CipherSuite[2];    /* Cryptographic suite selector */

      struct {
          ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
          Random random;
          opaque legacy_session_id<0..32>;
          CipherSuite cipher_suites<2..2^16-2>;
          opaque legacy_compression_methods<1..2^8-1>;
          Extension extensions<8..2^16-1>;
      } ClientHello;
```

关于结构体的一些说明：

- legacy\_version：  
	在 TLS 以前的版本里，这个字段被用来版本协商和表示 Client 所能支持的 TLS 最高版本号。经验表明，**很多 Server 并没有正确的实现版本协商**，导致了 "version intolerance" —— Sever 拒绝了一些本来可以支持的 ClientHello 消息，只因为这些消息的版本号高于 Server 能支持的版本号。在 TLS 1.3 中，Client 在 "supported\_versions" 扩展中表明了它的版本。并且legacy\_version 字段必须设置成 0x0303，这是 TLS 1.2 的版本号。在 TLS 1.3 中的 ClientHello 消息中的 legacy\_version 都设置成 0x0303，supported\_versions 扩展设置成 0x0304。更加详细的信息见附录 D。

- random:  
	由一个安全随机数生成器产生的32字节随机数。额外信息见附录 C。
	
- legacy\_session\_id：  
	TLS 1.3 版本之前的版本支持会话恢复的特性。在 TLS 1.3 的这个版本中，这一特性已经和预共享密钥 PSK 合并了。如果 Client 有 TLS 1.3 版本之前的 Server 设置的缓存 Session ID，那么这个字段要填上这个 ID 值。在兼容模式下，这个值必须是非空的，所以一个 Client 要是不能提供 TLS 1.3 版本之前的 Session 的话，就必须生成一个新的 32 字节的值。这个值不要求是随机值，但必须是一个不可预测的值，防止实现上固定成了一个固定的值了。否则，这个字段必须被设置成一个长度为 0 的向量。（例如，一个0字节长度域）

- cipher\_suites:
	这个列表是 Client 所支持对称加密选项的列表，特别是记录保护算法(包括密钥长度) 和 HKDF 一起使用的 hash 算法。
	
	
	

------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()