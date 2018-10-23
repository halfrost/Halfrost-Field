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

- legacy\_version:    
	在 TLS 以前的版本里，这个字段被用来版本协商和表示 Client 所能支持的 TLS 最高版本号。经验表明，**很多 Server 并没有正确的实现版本协商**，导致了 "version intolerance" —— Sever 拒绝了一些本来可以支持的 ClientHello 消息，只因为这些消息的版本号高于 Server 能支持的版本号。在 TLS 1.3 中，Client 在 "supported\_versions" 扩展中表明了它的版本。并且legacy\_version 字段必须设置成 0x0303，这是 TLS 1.2 的版本号。在 TLS 1.3 中的 ClientHello 消息中的 legacy\_version 都设置成 0x0303，supported\_versions 扩展设置成 0x0304。更加详细的信息见附录 D。

- random:    
	由一个安全随机数生成器产生的32字节随机数。额外信息见附录 C。
	
- legacy\_session\_id:    
	TLS 1.3 版本之前的版本支持会话恢复的特性。在 TLS 1.3 的这个版本中，这一特性已经和预共享密钥 PSK 合并了。如果 Client 有 TLS 1.3 版本之前的 Server 设置的缓存 Session ID，那么这个字段要填上这个 ID 值。在兼容模式下，这个值必须是非空的，所以一个 Client 要是不能提供 TLS 1.3 版本之前的 Session 的话，就必须生成一个新的 32 字节的值。这个值不要求是随机值，但必须是一个不可预测的值，防止实现上固定成了一个固定的值了。否则，这个字段必须被设置成一个长度为 0 的向量。（例如，一个0字节长度域）

- cipher\_suites:  
	这个列表是 Client 所支持对称加密选项的列表，特别是记录保护算法(包括密钥长度) 和 HKDF 一起使用的 hash 算法。以 Client 的偏好降序排列。如果列表包含的密码套件是 Server 不能识别的或者是不能支持的，或者是希望使用的，Server 必须忽略这些密码套件，照常处理剩下来的密码套件。如果 Client 尝试建立 PSK 密钥，则它应该至少包含一个与 PSK 相关的哈希加密套件。
	
- legacy\_compression\_methods:     
	TLS 1.3 之前的 TLS 版本支持压缩，在这个字段中发送支持的压缩方法列表。对于每个 ClientHello，该向量必须包含一个设置为 0 的一个字节，它对应着 TLS 之前版本中的 null 压缩方法。如果 TLS 1.3 中的 ClientHello 中这个字段包含有值，Server 必须立即发送 “illegal\_parameter” alert 消息中止握手。注意，TLS 1.3 Server 可能接收到 TLS 1.2 或者之前更老版本的 ClientHellos，其中包含了其他压缩方法。如果正在协商这些之前的版本，那么必须遵循 TLS 之前版本的规定。
	
- extensions:      
	Client 通过在扩展字段中发送数据，向 Server 请求扩展功能。“Extension” 遵循格式定义。在 TLS 1.3 中，使用确定的扩展项是强制的。因为功能被移动到了扩展中以保持和之前 TLS 版本的 ClientHello 消息的兼容性。Server 必须忽略不能识别的 extensions。
	
所有版本的 TLS 都允许可选的带上 compression\_methods 这个扩展字段。TLS 1.3 ClientHello 消息通常包含扩展消息(至少包含 “supported\_versions”，否则这条消息会被解读成 TLS 1.2 的 ClientHello 消息)然而，TLS 1.3 Server 也有可能收到之前 TLS 版本发来的不带扩展字段的 ClientHello 消息。扩展是否存在，可以通过检测 ClientHello 结尾的 compression\_methods 字段内是否有字节来确定。请注意，这种检测可选数据的方法与具有可变长度字段的普通 TLS 方法不同，但是在扩展被定义之前，这种方法可以用来做兼容。TLS 1.3 Server 需要首先执行此项检查，并且仅当存在 “supported\_versions” 扩展时才尝试协商 TLS 1.3。如果协商的是 TLS 1.3 之前的版本，Server 必须做 2 项检查：legacy\_compression\_methods 字段后面是否还有数据；有效的 extensions block 后没有数据跟随。如果上面这 2 项检查都不通过，需要立即发送 "decode\_error" alert 消息中止握手。
	
	
如果 Client 通过扩展请求额外功能，但是这个功能 Server 并不提供，则 Client 可以中止握手。

发送 ClientHello 消息后，Client 等待 ServerHello 或者 HelloRetryRequest 消息。如果 early data 在使用中，Client 在等待下一条握手消息期间，可以先发送 early Application Data。

### 3. Server Hello

如果 Server 和 Client 可以在 ClientHello 消息中协商出一套双方都可以接受的握手参数的话，那么 Server 会发送 Server Hello 消息回应 ClientHello 消息。

消息的结构体是：

```c
      struct {
          ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
          Random random;
          opaque legacy_session_id_echo<0..32>;
          CipherSuite cipher_suite;
          uint8 legacy_compression_method = 0;
          Extension extensions<6..2^16-1>;
      } ServerHello;
```

- legacy\_version:  
	在 TLS 1.3 之前的版本，这个字段被用来版本协商和标识建立连接时候双方选择的版本号。不幸的是，一些中间件在给这个字段赋予新值的时候可能会失败。在 TLS 1.3 中，Server 用 "supported\_versions" 扩展字段来标识它支持的版本，legacy\_version 字段必须设置为 0x0303(这个值代表的 TLS 1.2)。（有关向后兼容性的详细信息，请参阅附录D.）
	
- random:  
	由安全随机数生成器生成的随机 32 字节。如果协商的是 TLS 1.1 或者 TLS 1.2 ，那么最后 8 字节必须被重写，其余的 24 字节必须是随机的。这个结构由 Server 生成并且必须独立于 ClientHello.random。

- legacy\_session\_id\_echo:  
	Client 的 legacy\_session\_id 字段的内容。请注意，即使 Server 决定不再恢复 TLS 1.3 之前的会话，Client 的 legacy\_session\_id 字段缓存的是 TLS 1.3  之前的值，这个时候 legacy\_session\_id\_echo 字段也会被 echoed。Client 收到的 legacy\_session\_id\_echo 值和它在 ClientHello 中发送的值不匹配的时候，必须立即用 "illegal\_parameter" alert 消息中止握手。
	
- cipher\_suite:  
	Server 从 ClientHello 中的 cipher\_suites 列表中选择的一个加密套件。Client 如果接收到并没有提供的密码套件，此时应该立即用 "illegal\_parameter" alert 消息中止握手。
	
	
- legacy\_compression\_method:  
	必须有 0 值的单一字节。
	
- extensions:  
	扩展列表。ServerHello 中必须仅仅只能包括建立加密上下文和协商协议版本所需的扩展。**所有 TLS 1.3 的 ServerHello 消息必须包含 "supported\_versions" 扩展**。当前的 ServerHello 消息还另外包含 "pre\_shared\_key" 扩展或者 "key\_share" 扩展，或者两个扩展都有(当使用 PSK 和 (EC)DHE 建立连接的时候)。其他的扩展会在 EncryptedExtensions 消息中分别发送。
	
出于向后兼容中间件的原因，HelloRetryRequest 消息和 ServerHello 消息采用相同的结构体，但需要随机设置 HelloRetryRequest 的 SHA-256 特定值：

```c
     CF 21 AD 74 E5 9A 61 11 BE 1D 8C 02 1E 65 B8 91
     C2 A2 11 16 7A BB 8C 5E 07 9E 09 E2 C8 A8 33 9C
```
	
当收到 server\_hello 消息以后，实现必须首先检查这个随机值是不是和上面这个值匹配。如果和上面这个值是一致的，再继续处理。


TLS 1.3 具有降级保护机制，这种机制是通过嵌入在服务器的随机值实现的。TLS 1.3 Server 协商 TLS 1.2 或者更老的版本，为了响应 ClientHello ，ServerHello 消息中必须在最后 8 个字节中填入特定的随机值。

如果协商的 TLS 1.2 ，TLS 1.3 Server 必须把 ServerHello 中的 Random 字段的最后 8 字节设置为：

```c
44 4F 57 4E 47 52 44 01
D  O  W  N  G  R  D
```

如果协商的 TLS 1.1 或者更老的版本，TLS 1.3 Server 和 TLS 1.2 Server 必须把 ServerHello 中的 Random 字段的最后 8 字节的值改为：

```c
44 4F 57 4E 47 52 44 00
D  O  W  N  G  R  D
```
	
TLS 1.3 Client 接收到 TLS 1.2 或者 TLS 更老的版本的 ServerHello 消息以后，必须要检查 ServerHello 中的 Random 字段的最后 8 字节不等于上面 2 个值猜对。TLS 1.2 的 Client 也需要检查最后 8 个字节，如果协商的是 TLS 1.1 或者是更老的版本，那么 Random 值也不应该等于上面第二个值。如果都没有匹配上，那么 Client 必须用 "illegal\_parameter" alert 消息中止握手。



------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()