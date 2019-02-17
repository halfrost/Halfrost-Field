# TLS 1.3 Handshake Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/108_0.png'>
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


另外 IANA 分配了新的握手消息类型，见[第 11 章](https://tools.ietf.org/html/rfc8446#section-11)

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
- 选择性地增加，删除或更改 ”padding” 扩展[RFC 7685](https://tools.ietf.org/html/rfc7685)的长度。
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
	在 TLS 以前的版本里，这个字段被用来版本协商和表示 Client 所能支持的 TLS 最高版本号。经验表明，**很多 Server 并没有正确的实现版本协商**，导致了 "version intolerance" —— Sever 拒绝了一些本来可以支持的 ClientHello 消息，只因为这些消息的版本号高于 Server 能支持的版本号。在 TLS 1.3 中，Client 在 "supported\_versions" 扩展中表明了它的版本。并且 legacy\_version 字段必须设置成 0x0303，这是 TLS 1.2 的版本号。在 TLS 1.3 中的 ClientHello 消息中的 legacy\_version 都设置成 0x0303，supported\_versions 扩展设置成 0x0304。更加详细的信息见附录 D。

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


TLS 1.3 具有降级保护机制，这种机制是通过嵌入在 Server 的随机值实现的。TLS 1.3 Server 协商 TLS 1.2 或者更老的版本，为了响应 ClientHello ，ServerHello 消息中必须在最后 8 个字节中填入特定的随机值。

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
	
TLS 1.3 Client 接收到 TLS 1.2 或者 TLS 更老的版本的 ServerHello 消息以后，必须要检查 ServerHello 中的 Random 字段的最后 8 字节不等于上面 2 个值才对。TLS 1.2 的 Client 也需要检查最后 8 个字节，如果协商的是 TLS 1.1 或者是更老的版本，那么 Random 值也不应该等于上面第二个值。如果都没有匹配上，那么 Client 必须用 "illegal\_parameter" alert 消息中止握手。这种机制提供了有限的保护措施，抵御降级攻击。通过 Finished exchange ，能超越保护机制的保护范围：因为在 TLS 1.2 或更低的版本上，ServerKeyExchange 消息包含 2 个随机值的签名。只要使用了临时的加密方式，攻击者就不可能在不被发现的情况下，修改随机值。所以对于静态的 RSA，是无法提供降级攻击的保护。

>请注意，上面这些改动在 [RFC5246](https://tools.ietf.org/html/rfc5246) 中说明的，实际上许多 TLS 1.2 的 Client 和 Server 都没有按照上面的规定来实践。

如果 Client 在重新协商 TLS 1.2 或者更老的版本的时候，协商过程中收到了 TLS 1.3 的 ServerHello，这个时候 Client 必须立即发送 “protocol\_version” alert 中止握手。请注意，**一旦 TLS 1.3 协商完成，就无法再重新协商了，因为 TLS 1.3 严禁重新协商**。


### 4. Hello Retry Request

如果在 Client 发来的 ClientHello 消息中能够找到一组可以相互支持的参数，但是 Client 又不能为接下来的握手提供足够的信息，这个时候 Server 就需要发送 HelloRetryRequest 消息来响应 ClientHello 消息。在上一节中，谈到 HelloRetryRequest 和 ServerHello 消息是有相同的数据结构，legacy\_version, legacy\_session\_id\_echo, cipher\_suite, legacy\_compression\_method 这些字段的含义也是一样的。为了讨论的方便，下文中，我们讨论 HelloRetryRequest 消息都当做不同的消息来对待。

Server 的扩展集中必须包含 "supported\_versions"。另外，它还需要包含最小的扩展集，能让 Client 生成正确的 ClientHello 对。相比 ServerHello 而言，HelloRetryRequest 只能包含任何在第一次 ClientHello 中出现过的扩展，除了可选的 "cookie" 以外。


Client 接收到 HelloRetryRequest 消息以后，必须要先校验 legacy\_version, legacy\_session\_id\_echo, cipher\_suite, legacy\_compression\_method 这四个参数。先从 “supported\_versions” 开始决定和 Server 建立连接的版本，然后再处理扩展。如果 HelloRetryRequest 不会导致 ClientHello 的任何更改，Client 必须用 “illegal\_parameter” alert 消息中止握手。如果 Client 在一个连接中收到了第 2 个 HelloRetryRequest 消息( ClientHello 本身就是响应 HelloRetryRequest 的)，那么必须用 “unexpected\_message” alert 消息中止握手。

否则，Client 必须处理 HelloRetryRequest 中所有的扩展，并且发送第二个更新的 ClientHello。在本规范中定义的 HelloRetryRequest 扩展名是：

- supported\_versions
- cookie
- key\_share

Client 在接收到自己并没有提供的密码套件的时候必须立即中止握手。Server 必须确保在接收到合法并且更新过的 ClientHello 时，它们在协商相同的密码套件(如果 Server 把选择密码套件作为协商的第一步，那么这一步会自动发送)。Client 收到 ServerHello 后必须检查 ServerHello 中提供的密码套件是否与 HelloRetryRequest 中的密码套件相同，否则将以 “illegal\_parameter” alert 消息中止握手。


此外，Client 在其更新的 ClientHello 中，Client 不能提供任何与所选密码套件以外的预共享密钥(与哈希相关联的)。这允许 Client 避免在第二个 ClientHello 中计算多个散列的部分哈希转录。

在 HelloRetryRequest 的 "support\_versions" 扩展中的 selected\_version 字段的值必须被保留在 ServerHello 中，如果这个值变了，Client 必须用 “illegal\_parameter” alert 消息中止握手。


## 二. Extensions

许多 TLS 的消息都包含 tag-length-value 编码的扩展数据结构：

```c
    struct {
        ExtensionType extension_type;
        opaque extension_data<0..2^16-1>;
    } Extension;

    enum {
        server_name(0),                             /* RFC 6066 */
        max_fragment_length(1),                     /* RFC 6066 */
        status_request(5),                          /* RFC 6066 */
        supported_groups(10),                       /* RFC 8422, 7919 */
        signature_algorithms(13),                   /* RFC 8446 */
        use_srtp(14),                               /* RFC 5764 */
        heartbeat(15),                              /* RFC 6520 */
        application_layer_protocol_negotiation(16), /* RFC 7301 */
        signed_certificate_timestamp(18),           /* RFC 6962 */
        client_certificate_type(19),                /* RFC 7250 */
        server_certificate_type(20),                /* RFC 7250 */
        padding(21),                                /* RFC 7685 */
        pre_shared_key(41),                         /* RFC 8446 */
        early_data(42),                             /* RFC 8446 */
        supported_versions(43),                     /* RFC 8446 */
        cookie(44),                                 /* RFC 8446 */
        psk_key_exchange_modes(45),                 /* RFC 8446 */
        certificate_authorities(47),                /* RFC 8446 */
        oid_filters(48),                            /* RFC 8446 */
        post_handshake_auth(49),                    /* RFC 8446 */
        signature_algorithms_cert(50),              /* RFC 8446 */
        key_share(51),                              /* RFC 8446 */
        (65535)
    } ExtensionType;
```

这里：

- "extension\_type" 标识特定的扩展状态。
- "extension\_data" 包含特定于该特定扩展类型的信息。

所有的扩展类型由 IANA 维护，具体的见附录。

扩展通常以请求/响应方式构建，虽然有些扩展只是一些标识，并不会有任何响应。Client 在 ClientHello 中发送其扩展请求，Server 在 ServerHello, EncryptedExtensions, HelloRetryRequest,和 Certificate 消息中发送对应的扩展响应。Server 在 CertificateRequest 消息中发送扩展请求，Client 可能回应 Certificate 消息。Server 也有可能不请自来的在 NewSessionTicket 消息中直接发送扩展请求，Client 可以不用直接响应这条消息。

如果远端没有发送相应的扩展请求，除了 HelloRetryRequest 消息中的 “cookie” 扩展以外，实现方不得发送扩展响应。在接收到这样的扩展以后，端点必须用 "unsupported\_extension" alert 消息中止握手。


下表给出了可能出现的消息的扩展名，使用以下表示法：CH (ClientHello), SH (ServerHello), EE (EncryptedExtensions), CT (Certificate), CR (CertificateRequest), NST (NewSessionTicket), 和 HRR (HelloRetryRequest) 。当实现方在接收到它能识别的消息，并且并没有为出现的消息做规定的话，它必须用 "illegal\_parameter" alert 消息中止握手。

```c
   +--------------------------------------------------+-------------+
   | Extension                                        |     TLS 1.3 |
   +--------------------------------------------------+-------------+
   | server_name [RFC6066]                            |      CH, EE |
   |                                                  |             |
   | max_fragment_length [RFC6066]                    |      CH, EE |
   |                                                  |             |
   | status_request [RFC6066]                         |  CH, CR, CT |
   |                                                  |             |
   | supported_groups [RFC7919]                       |      CH, EE |
   |                                                  |             |
   | signature_algorithms (RFC 8446)                  |      CH, CR |
   |                                                  |             |
   | use_srtp [RFC5764]                               |      CH, EE |
   |                                                  |             |
   | heartbeat [RFC6520]                              |      CH, EE |
   |                                                  |             |
   | application_layer_protocol_negotiation [RFC7301] |      CH, EE |
   |                                                  |             |
   | signed_certificate_timestamp [RFC6962]           |  CH, CR, CT |
   |                                                  |             |
   | client_certificate_type [RFC7250]                |      CH, EE |
   |                                                  |             |
   | server_certificate_type [RFC7250]                |      CH, EE |
   |                                                  |             |
   | padding [RFC7685]                                |          CH |
   |                                                  |             |
   | key_share (RFC 8446)                             | CH, SH, HRR |
   |                                                  |             |
   | pre_shared_key (RFC 8446)                        |      CH, SH |
   |                                                  |             |
   | psk_key_exchange_modes (RFC 8446)                |          CH |
   |                                                  |             |
   | early_data (RFC 8446)                            | CH, EE, NST |
   |                                                  |             |
   | cookie (RFC 8446)                                |     CH, HRR |
   |                                                  |             |
   | supported_versions (RFC 8446)                    | CH, SH, HRR |
   |                                                  |             |
   | certificate_authorities (RFC 8446)               |      CH, CR |
   |                                                  |             |
   | oid_filters (RFC 8446)                           |          CR |
   |                                                  |             |
   | post_handshake_auth (RFC 8446)                   |          CH |
   |                                                  |             |
   | signature_algorithms_cert (RFC 8446)             |      CH, CR |
   +--------------------------------------------------+-------------+
```

当存在多种不同类型的扩展的时候，除了 "pre\_shared\_key" 必须是 ClientHello 的最后一个扩展，其他的扩展间的顺序可以是任意的。("pre\_shared\_key" 可以出现在 ServerHello 中扩展块中的任何位置)。不能存在多个同一个类型的扩展。

在 TLS 1.3 中，与 TLS 1.2 不同，即使是恢复 PSK 模式，每次握手都需要协商扩展。然而，0-RTT 的参数是在前一次握手中协商的。如果参数不匹配，需要拒绝 0-RTT。

在 TLS 1.3 中新特性和老特性之间存在微妙的交互，这可能会使得整体安全性显著下降。下面是设计新扩展的时候需要考虑的因素：

- Server 不同意扩展的某些情况是错误的(例如握手不能继续)，有些情况只是简单的不支持特定的功能。一般来说，前一种情况应该用错误的 alert，后一种情况应该用 Server 的扩展响应中的一个字段来处理。

- 扩展应尽可能设计为防止能通过人为操纵握手信息，从而强制使用（或不使用）特定功能的攻击。不管这个功能是否会引起安全问题，这个原则都必须遵守。通常，包含在 Finished 消息的哈希输入中的扩展字段是不用担心的，但是在握手阶段，扩展试图改变了发送消息的含义，这种情况需要特别小心。设计者和实现者应该意识到，在握手完成身份认证之前，攻击者都可以修改消息，插入、删除或者替换扩展。

### 1. Supported Versions

```c
      struct {
          select (Handshake.msg_type) {
              case client_hello:
                   ProtocolVersion versions<2..254>;

              case server_hello: /* and HelloRetryRequest */
                   ProtocolVersion selected_version;
          };
      } SupportedVersions;

```

“supported\_versions” 对于 Client 来说，Client 用它来标明它所能支持的 TLS 版本，对于 Server 来说，Server 用它来标明正在使用的 TLS 版本。这个扩展包含一个按照优先顺序排列的，能支持的版本列表。最优先支持的版本放在第一个。TLS 1.3 这个版本的规范是必须在发送 ClientHello 消息时候带上这个扩展，扩展中包含所有准备协商的 TLS 版本。(对于这个规范来说，这意味着最低是 0x0304，但是如果要协商 TLS 的以前的版本，那么这个扩展必须要带上)


如果不存在 “supported\_versions” 扩展，满足 TLS 1.3 并且也兼容 TLS 1.2 规范的 Server 需要协商 TLS 1.2 或者之前的版本，即使 ClientHello.legacy\_version 是 0x0304 或者更高的版本。Server 在接收到 ClientHello 中的 legacy\_version 的值是 0x0304 或者更高的版本的时候，Server 可能需要立刻中止握手。

如果 ClientHello 中存在 “supported\_versions” 扩展，Server 禁止使用 ClientHello.legacy\_version 的值作为版本协商的值，只能使用 "supported\_versions" 决定 Client 的偏好。Server 必须只选择该扩展中存在的 TLS 版本，并且必须要忽略任何未知版本。注意，如果通信的一方支持稀疏范围，这种机制使得可以在 TLS 1.2 之前的版本间进行协商。选择支持 TLS 的以前版本的 TLS 1.3 的实现应支持 TLS 1.2。Server 应准备好接收包含此扩展名的 ClientHellos 消息，但不要在 viersions 列表中包含 0x0304。

Server 在协商 TLS 1.3 之前的版本，必须要设置 ServerHello.version，不能发送 "supported\_versions" 扩展。Server 在协商 TLS 1.3 版本时候，必须发送 "supported\_versions" 扩展作为响应，并且扩展中要包含选择的 TLS 1.3 版本号(0x0304)。还要设置 ServerHello.legacy\_version 为 0x0303(TLS 1.2)。Client 必须在处理 ServerHello 之前检查此扩展(尽管需要先解析 ServerHello 以便读取扩展名)。如果 "supported\_versions" 扩展存在，Client 必须忽略 ServerHello.legacy\_version 的值，只使用 "supported\_versions" 中的值确定选择的版本。如果 ServerHello 中的 "supported\_versions" 扩展包含了 Client 没有提供的版本，或者是包含了 TLS 1.3 之前的版本(本来是协商 TLS 1.3 的，却又包含了 TLS 1.3 之前的版本)，Client 必须立即发送 "illegal\_parameter" alert 消息中止握手。


### 2. Cookie

```c
      struct {
          opaque cookie<1..2^16-1>;
      } Cookie;
```

Cookies 有 2 大主要目的：

- 允许 Server 强制 Client 展示网络地址的可达性(因此提供了一个保护 Dos 的度量方法)，这主要是面向无连接的传输(参考 [RFC 6347](https://tools.ietf.org/html/rfc6347) 中的例子)


- 允许 Server 卸载状态。从而允许 Server 在向 Client 发送 HelloRetryRequest 消息的时候，不存储任何状态。为了实现这一点，可以通过 Server 把 ClientHello 的哈希存储在 HelloRetryRequest 的 cookie 中(用一些合适的完整性算法保护)。


当发送 HelloRetryRequest 消息时，Server 可以向 Client 提供 “cookie” 扩展(这是常规中的一个例外，常规约定是：只能是可能被发送的扩展才可以出现在 ClientHello 中)。当发送新的 ClientHello 消息时，Client 必须将 HelloRetryRequest 中收到的扩展的内容复制到新 ClientHello 中的 “cookie” 扩展中。Client 不得在后续连接中使用首次 ClientHello 中的 Cookie。


当 Server 在无状态运行的时候，在第一个和第二个 ClientHello 之间可能会收到不受保护的 change\_cipher\_spec 消息。由于 Server 没有存储任何状态，它会表现出像到达的第一条消息一样。无状态的 Server 必须忽略这些记录。



### 3. Signature Algorithms


TLS 1.3 提供了 2 种扩展来标明在数字签名中可能用到的签名算法。"signature\_algorithms\_cert" 扩展提供了证书里面的签名算法。"signature\_algorithms" 扩展(TLS 1.2 中就有这个扩展了)，提供了 CertificateVerify 消息中的签名算法。证书中的密钥必须要根据所用的签名算法匹配合适的类型。对于 RSA 密钥和 PSS 签名，这是一个特殊问题，描述如下：如果没有 "signature\_algorithms\_cert" 扩展，则 "signature\_algorithms" 扩展同样适用于证书中的签名。Client 想要 Server 通过证书来认证自己，则必须发送 "signature\_algorithms" 扩展。如果 Server 正在进行证书的认证，这个时候 Client 又没有提供 "signature\_algorithms"扩展，Server 必须 发送 "missing\_extension" 消息中止握手。

加入 "signature\_algorithms\_cert" 扩展的意图是为了让已经支持了证书的不同算法集的实现方，能明确的标识他们的能力。TLS 1.2 实现应该也应该处理这个扩展。在两种情况下具有相同策略的实现可以省略 "signature\_algorithms\_cert" 扩展名。

这些扩展中的 "extension\_data" 字段包含一个 SignatureSchemeList 值：

```c
enum {
          /* RSASSA-PKCS1-v1_5 algorithms */
          rsa_pkcs1_sha256(0x0401),
          rsa_pkcs1_sha384(0x0501),
          rsa_pkcs1_sha512(0x0601),

          /* ECDSA algorithms */
          ecdsa_secp256r1_sha256(0x0403),
          ecdsa_secp384r1_sha384(0x0503),
          ecdsa_secp521r1_sha512(0x0603),

          /* RSASSA-PSS algorithms with public key OID rsaEncryption */
          rsa_pss_rsae_sha256(0x0804),
          rsa_pss_rsae_sha384(0x0805),
          rsa_pss_rsae_sha512(0x0806),

          /* EdDSA algorithms */
          ed25519(0x0807),
          ed448(0x0808),

          /* RSASSA-PSS algorithms with public key OID RSASSA-PSS */
          rsa_pss_pss_sha256(0x0809),
          rsa_pss_pss_sha384(0x080a),
          rsa_pss_pss_sha512(0x080b),

          /* Legacy algorithms */
          rsa_pkcs1_sha1(0x0201),
          ecdsa_sha1(0x0203),

          /* Reserved Code Points */
          private_use(0xFE00..0xFFFF),
          (0xFFFF)
      } SignatureScheme;

      struct {
          SignatureScheme supported_signature_algorithms<2..2^16-2>;
      } SignatureSchemeList;

```

请注意：这个枚举之所以名为 "SignatureScheme"，是因为在 TLS 1.2 中已经存在了 "SignatureAlgorithm" 类型，取而代之。在本篇文章中，我们都使用术语 "签名算法"。

每一个列出的 SignatureScheme 的值是 Client 想要验证的单一签名算法。这些值按照优先级降序排列。请注意，签名算法以任意长度的消息作为输入，而不是摘要作为输入。传统上用于摘要的算法应该在 TLS 中定义，首先使用指定的哈希算法对输入进行哈希计算，然后再进行常规处理。上面列出的代码具有以下含义：


- RSASSA-PKCS1-v1\_5 algorithms:  
	表示使用 RSASSA-PKCS1-v1\_5 [RFC8017](https://tools.ietf.org/html/rfc8017) 和定义在 [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS) 中对应的哈希算法的签名算法。这些值仅指，出现在证书中又没有被定义用于签名 TLS 握手消息的签名。这些值会出现在 "signature\_algorithms" 和 "signature\_algorithms\_cert" 中，因为需要向后兼容 TLS 1.2 。
	
- ECDSA algorithms:  
	表示签名算法使用 ECDSA，对应的曲线在 ANSI X9.62 [ECDSA](https://tools.ietf.org/html/rfc8446#ref-ECDSA) 和 FIPS 186-4 [DSS](https://tools.ietf.org/html/rfc8446#ref-DSS) 中定义了，对应的哈希算法在 [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS) 中定义了。签名被表示为 DER 编码的 ECDSA-Sig-Value 结构。
	
- RSASSA-PSS RSAE algorithms:  
	表示使用带有掩码生成函数 1 的 RSASSA-PSS 签名算法。在掩码生成函数中使用的摘要和被签名的摘要都是在 [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS) 中定义的相应的哈希算法。盐的长度必须等于摘要算法输出的长度。如果公钥在 X.509 证书中，则必须使用 rsaEncryption OID [RFC5280](https://tools.ietf.org/html/rfc5280)。
	
- EdDSA algorithms:  
	表示使用定义在 [RFC 8032](https://tools.ietf.org/html/rfc8032) 中的 EdDSA 算法或者其后续改进算法。请注意，这些相应算法是 "PureEdDSA" 算法，而不是 "prehash" 变种算法。

- RSASSA-PSS PSS algorithms:  
	表示使用带有掩码生成函数 1 的 RSASSA-PSS [RFC 8017](https://tools.ietf.org/html/rfc8017) 签名算法。在掩码生成函数中使用的摘要和被签名的摘要都是在 [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS) 中定义的相应的哈希算法。盐的长度必须等于摘要算法的长度。如果公钥在 X.509 证书中，则必须使用 RSASSA-PSS OID [RFC5756](https://tools.ietf.org/html/rfc5756)。当它被用在证书签名中，算法参数必须是 DER 编码。如果存在相应的公钥参数，则签名中的参数必须与公钥中的参数相同。
	
- Legacy algorithms:  
	表示使用正在被废弃中的算法，因为这些算法有已知的缺点。特别是 SHA-1 配合上文提到的 RSASSA-PKCS1-v1\_5 和 ECDSA 算法一起使用。这些值仅指，出现在证书中又没有被定义用于签名 TLS 握手消息的签名。这些值会出现在 "signature\_algorithms" 和 "signature\_algorithms\_cert" 中，因为需要向后兼容 TLS 1.2 。终端不应该协商这些算法，但允许这样做只是为了向后兼容。提供这些值的 Client 必须把他们列在最低优先级的位置上(在 SignatureSchemeList 中的所有其他算法之后列出)。TLS 1.3 Server 绝不能提供 SHA-1 签名证书，除非没有它就无法生成有效的证书链。

	
自签名证书上的签名或信任锚的证书不能通过校验，因为它们开始了一个认证路径(见 [RFC 5280](https://tools.ietf.org/html/rfc5280#section-3.2))。开始认证路径的证书可以使用 "signature\_algorithms" 扩展中不建议支持的签名算法。
	
请注意，TLS 1.2 中这个扩展的定义和 TLS 1.3 的定义不同。在协商 TLS 1.2 版本时，愿意协商 TLS 1.2 的 TLS 1.3 实现必须符合 [RFC5246](https://tools.ietf.org/html/rfc5246) 的要求，尤其是：

- TLS 1.2 ClientHellos 可以忽略此扩展。	

- 在 TLS 1.2 中，扩展包含 hash/signature pairs。这些 pairs 被编码为两个八位字节，所以已经分配空间的 SignatureScheme 值与 TLS 1.2 的编码对齐。 一些传统的 pairs 保留未分配。这些算法已被 TLS 1.3 弃用。它们不得在任何实现中被提供或被协商。 特别是，不得使用 MD5 [[SLOTH]](https://tools.ietf.org/html/rfc8446#ref-SLOTH) 、SHA-224 和 DSA。

- ECDSA 签名方案和 TLS 1.2 的 hash/signature pairs 一致。然而，旧的语义并没有限制签名曲线。如果 TLS 1.2 被协商了，实现方必须准备接受在 "supported\_groups" 扩展中使用任何曲线的签名。
	
- 即使协商了 TLS 1.2，支持了 RSASSA-PSS（在TLS 1.3中是强制性的）的实现方也准备接受该方案的签名。在TLS 1.2中，RSASSA-PSS 与 RSA 密码套件一起使用。
	
	
	
	
### 4. Certificate Authorities
	
"certificate\_authorities" 扩展用于表示终端支持的 CA, 并且接收的端点应该使用它来指导证书的选择。
	
"certificate\_authorities" 扩展的主体包含了一个 CertificateAuthoritiesExtension 结构：

```c
      opaque DistinguishedName<1..2^16-1>;

      struct {
          DistinguishedName authorities<3..2^16-1>;
      } CertificateAuthoritiesExtension;
```
	
- authorities:  
	可接受证书颁发机构的一个可分辨名字 [X501](https://tools.ietf.org/html/rfc8446#ref-X501) 的列表	，这个列表是以 DER [X690](https://tools.ietf.org/html/rfc8446#ref-X690) 编码格式表示的。这些可分辨的名称为，信任锚或从属的 CA 指定所需的可分辨的名称。因此，可以使用此消息描述已知的信任锚以及所需的授权空间。
	
Client 可能会在 ClientHello 消息中发送 "certificate\_authorities" 扩展，Server 可能会在 CertificateRequest 消息中发送 "certificate\_authorities" 扩展。


"trusted\_ca\_keys" 扩展和 "certificate\_authorities" 扩展有相同的目的，但是更加复杂。"trusted\_ca\_keys" 扩展不能在 TLS 1.3 中使用，但是它在 TLS 1.3 之前的版本中，可能出现在 Client 的 ClientHello 消息中。


### 5. OID Filters

"oid\_filters" 扩展允许 Server 提供一组 OID/value 对，用来匹配 Client 的证书。如果 Server 想要发送这个扩展，有且仅有在 CertificateRequest 消息中才能发送。

```c
      struct {
          opaque certificate_extension_oid<1..2^8-1>;
          opaque certificate_extension_values<0..2^16-1>;
      } OIDFilter;

      struct {
          OIDFilter filters<0..2^16-1>;
      } OIDFilterExtension;
```

- filters:  
	一个有允许值的证书扩展 OID [RFC 5280](https://tools.ietf.org/html/rfc5280) 列表，以 DER 编码 [X690](https://tools.ietf.org/html/rfc8446#ref-X690) 格式表示。一些证书扩展 OID 允许多个值(例如，Extended Key Usage)。如果 Server 包含非空的 filters 列表，则响应中包含的 Client 证书必须包含 Client 识别的所有指定的扩展 OID。对于 Client 识别的每个扩展 OID，所有指定的值必须存在于 Client 证书中（但是证书也可以具有其他值）。然而，Client 必须忽略并跳过任何无法识别的证书扩展 OID。如果 Client 忽略了一些所需的证书扩展 OID 并提供了不满足请求的证书。Server 可以自行决定是继续与没有身份认证的 Client 保持连接，还是用 "unsupported\_certificate" alert 消息中止握手。任何给定的 OID 都不能在 filters 列表中出现多次。


PKIX RFC 定义了各种证书扩展 OID 及其对应的值类型。根据类型，匹配的证书扩展值不一定是按位相等的。期望 TLS 实现将依靠它们的 PKI 库，使用证书扩展 OID 来做证书的选择。

本文档定义了 [RFC5280](https://tools.ietf.org/html/rfc5280) 中定义的两个标准证书扩展的匹配规则：


- 当请求中声明的所有 Key Usage 位也同样在 Key Usage 证书扩展声明了，那么证书中的 Key Usage 扩展匹配了请求。

- 当请求中所有的密钥 OIDs 在 Extended Key Usage 证书扩展中也存在，那么证书中的 Extended Key Usage 匹配了请求。特殊的 anyExtendedKeyUsage OID 一定不能在请求中使用。


单独的规范可以为其他证书扩展的规则定义匹配规则。



### 6. Post-Handshake Client Authentication


"post\_handshake\_auth" 扩展用于表明 Client 愿意握手后再认证。Server 不能向没有提供此扩展的 Client 发送握手后再认证的 CertificateRequest 消息。Server 不能发送此扩展。

```c
      struct {} PostHandshakeAuth;
```

"post\_handshake\_auth" 扩展名中的 "extension\_data" 字段为零长度。


### 7. Supported Groups

当 Client 发送 "supported\_groups" 扩展的时候，这个扩展表明了 Client 支持的用于密钥交换的命名组。按照优先级从高到低。


请注意：在 TLS 1.3 之前的版本中，这个扩展原来叫 "elliptic\_curves"，并且只包含椭圆曲线组。具体请参考 [RFC8422](https://tools.ietf.org/html/rfc8422) 和 [RFC7919](https://tools.ietf.org/html/rfc7919)。这个扩展同样可以用来协商 ECDSA 曲线。签名算法现在独立协商了。

这个扩展中的 "extension\_data" 字段包含一个 "NamedGroupList" 值：

```c
      enum {

          /* Elliptic Curve Groups (ECDHE) */
          secp256r1(0x0017), secp384r1(0x0018), secp521r1(0x0019),
          x25519(0x001D), x448(0x001E),

          /* Finite Field Groups (DHE) */
          ffdhe2048(0x0100), ffdhe3072(0x0101), ffdhe4096(0x0102),
          ffdhe6144(0x0103), ffdhe8192(0x0104),

          /* Reserved Code Points */
          ffdhe_private_use(0x01FC..0x01FF),
          ecdhe_private_use(0xFE00..0xFEFF),
          (0xFFFF)
      } NamedGroup;

      struct {
          NamedGroup named_group_list<2..2^16-1>;
      } NamedGroupList;
```

- Elliptic Curve Groups (ECDHE):  
	表示支持在 FIPS 186-4 [[DSS]](https://tools.ietf.org/html/rfc8446#ref-DSS) 或者 [[RFC7748]](https://tools.ietf.org/html/rfc7748) 中定义的对应命名的曲线。0xFE00 到 0xFEFF 的值保留使用[[RFC8126]](https://tools.ietf.org/html/rfc8126)。
	
	

- Finite Field Groups (DHE):  
	表示支持相应的有限域组，相关定义可以参考 [[RFC7919]](https://tools.ietf.org/html/rfc7919)。0x01FC 到 0x01FF 的值保留使用。

named\_group\_list 中的项根据发送者的优先级排序(最好是优先选择的)。

在 TLS 1.3 中，Server 允许向 Client 发送 "supported\_groups" 扩展。Client 不能在成功完成握手之前，在 "supported\_groups" 中找到的任何信息采取行动，但可以使用从成功完成的握手中获得的信息来更改在后续连接中的 "key\_share" 扩展中使用的组。如果 Server 中有一个组，它更想接受 "key\_share" 扩展中的那些值，但仍然愿意接受 ClientHello 消息，这时候它应该发送 "supported\_groups" 来更新 Client 的偏好视图。无论 Client 是否支持它，这个扩展名都应该包含 Server 支持的所有组。


### 8. Key Share

"key\_share" 扩展包含终端的加密参数。

Client 可能会发送空的 client\_shares 向量，以额外的往返代价，向 Server 请求选择的组。


```c
      struct {
          NamedGroup group;
          opaque key_exchange<1..2^16-1>;
      } KeyShareEntry;
```

- group:  
	要交换的密钥的命名组。
	
- key\_exchange:  
	密钥交换信息。这个字段的内容由特定的组和相应的定义确定。有限域的 Diffie-Hellman 参数在下面会描述。椭圆曲线 Diffie-Hellman 参数也会下面会描述。


在 ClientHello 消息中，"key\_share" 扩展中的 "extension\_data" 包含 KeyShareClientHello 值：

```c
      struct {
          KeyShareEntry client_shares<0..2^16-1>;
      } KeyShareClientHello;
```

- client\_shares:   
	按照 Client 偏好降序顺序提供的 KeyShareEntry 值列表。

如果 Client 正在请求 HelloRetryRequest， 则这个向量可以为空。每个 KeyShareEntry 值必须对应一个在 "supported\_groups" 扩展中提供的组，并且出现的顺序必须相同。然而，当优先级排名第一的组合是新的，并且不足以提供预生成 key shares 的时候，那么值可以是 "supported\_groups" 扩展的非连续子集，并且可以省略最优选的组，这种情况是可能会出现的。


Client 可以提供与其提供的 support groups 一样多数量的 KeyShareEntry 的值。每个值都代表了一组密钥交换参数。例如，Client 可能会为多个椭圆曲线或者多个 FFDHE 组提供 shares。每个 KeyShareEntry 中的 key\_exchange 值必须独立生成。Client 不能为相同的 group 提供多个 KeyShareEntry 值。Client 不能为，没有出现在 Client 的 "supported\_group" 扩展中列出的 group 提供任何 KeyShareEntry 值。Server 会检查这些规则，如果违反了规则，立即发送 "illegal\_parameter" alert 消息中止握手。

在 HelloRetryRequest 消息中，"key\_share" 扩展中的 "extension\_data" 字段包含 KeyShareHelloRetryRequest 值。

```c
      struct {
          NamedGroup selected_group;
      } KeyShareHelloRetryRequest;
```

- selected\_group:  
	Server 打算协商的相互支持并且正在请求重试 ClientHello / KeyShare 的 group。


在 HelloRetryRequest 消息中收到此扩展后，Client 必须要验证 2 点。第一点，selected\_group 必须在原始的 ClientHello 中的 "supported\_groups" 中出现过。第二点，selected\_group 没有在原始的 ClientHello 中的 "key\_share" 中出现过。如果上面 2 点检查都失败了，那么 Client 必须通过 "illegal\_parameter" alert 消息来中止握手。否则，在发送新的 ClientHello 时，Client 必须将原始的 "key\_share" 扩展替换为仅包含触发 HelloRetryRequest 的 selected\_group 字段中指示的组,这个组中只包含新的 KeyShareEntry。


在 ServerHello 消息中，"key\_share" 扩展中的 "extension\_data" 字段包含 KeyShareServerHello 值。

```c
      struct {
          KeyShareEntry server_share;
      } KeyShareServerHello;
```

- server\_share:  
	与 Client 共享的位于同一组的单个 KeyShareEntry 值。

如果使用 (EC)DHE 密钥建立链接，Server 在 ServerHello 中只提供了一个 KeyShareEntry。这个值必须与，Server 为了协商密钥交换在 Client 提供的 KeyShareEntry 值中选择的值，在同一组中。Server 不能为 Client 的 "supported\_groups" 扩展中指定的任何 group 发送 KeyShareEntry 值。Server 也不能在使用 "psk\_ke" PskKeyExchangeMode 时候发送 KeyShareEntry 值。如果使用 (EC)DHE 建立链接，Client 收到了包含在 "key\_share" 扩展中的 HelloRetryRequest 消息，Client 必须验证在 ServerHello 中选择的 NameGroup 与 HelloRetryRequest 中是否相同。如果不相同，Client 必须立即发送 "illegal\_parameter" alert 消息中止握手。


#### (1) Diffie-Hellman Parameters

Client 和 Server 两者的 Diffie-Hellman [[DH76]](https://tools.ietf.org/html/rfc8446#ref-DH76) 参数都编码在 KeyShareEntry 中的 KeyShare 数据结构中 opaque 类型的 key\_exchange 字段中。opaque 类型的值包含指定 group 的 Diffie-Hellman 公钥(Y = g^X mod p)，是用大端整数编码的。这个值大小为 p 字节，如果字节不够，需要在其左边添加 0 。


请注意：对于给定的 Diffie-Hellman 组，填充会导致所有的公钥具有相同的长度。

对端必须要相互验证对方的公钥，确保 1 < Y < p-1。此检查确保远程对端正常运行，也使得本地系统不会强制进入进入更小的 subgroup。


#### (2) ECDHE Parameters


Client 和 Server 两者的 ECDHE 参数都编码在 KeyShareEntry 中的 KeyShare 数据结构中 opaque 类型的 key\_exchange 字段中。

对于 secp256r1，secp384r1 和 secp521r1，内容是以下结构体的序列化值：

```c
      struct {
          uint8 legacy_form = 4;
          opaque X[coordinate_length];
          opaque Y[coordinate_length];
      } UncompressedPointRepresentation;
```

X 和 Y 分别是网络字节顺序中 X 和 Y 值的二进制表示。由于没有内部长度标记，所以每个数字占用曲线参数隐含的 8 位字节数。对于 P-256，这意味着 X 和 Y 中的每一个占用 32 个八位字节，如果需要，则在左侧填充零。对于 P-384，它们分别占用 48 个八位字节，对于 P-521，它们各占用 66 个八位字节。

对于曲线 secp256r1, secp384r1, 和 secp521r1，对端必须验证对方的的公钥 Q，以保证这个点是椭圆曲线上有效的点。合适的验证方法定义在 [[ECDSA]](https://tools.ietf.org/html/rfc8446#ref-ECDSA) 中或者 [[KEYAGREEMENT]](https://tools.ietf.org/html/rfc8446#ref-KEYAGREEMENT)。这个处理包括了 3 步。第一步：验证 Q 不是无穷大的点 (O)。第二步，验证 Q = (x, y) 中的两个整数 x，y 有正确的间隔。第三步，验证 (x, y) 是椭圆曲线方程的正确的解。对于这些曲线，实现方不需要再验证正确的 subgroup 中的成员身份。


对于 X25519 和 X448 来说，公共值的内容是 [[RFC7748]](https://tools.ietf.org/html/rfc7748) 中定义的相应函数的字节串输入和输出，X25519 的是 32 个字节， X448 的是 56 个字节。

请注意：**TLS 1.3 之前的版本允许 point format 协商，TLS 1.3 移除了这个功能，以利于每个曲线的单独 point format**。



### 9. Pre-Shared Key Exchange Modes

为了使用 PSK，Client 还必须发送一个 "psk\_key\_exchange\_modes" 扩展。这个扩展语意是 Client 仅支持使用具有这些模式的 PSK。这就限制了在这个 ClientHello 中提供的 PSK 的使用，也限制了 Server 通过 NewSessionTicket 提供的 PSK 的使用。

如果 Client 提供了 "pre\_shared\_key" 扩展，那么它必须也要提供 "psk\_key\_exchange\_modes" 扩展。如果 Client 发送不带 "psk\_key\_exchange\_modes" 扩展名的 "pre\_shared\_key"，Server 必须立即中止握手。Server 不能选择一个 Client 没有列出的密钥交换模式。此扩展还限制了与 PSK 恢复使用的模式。Server 也不能发送与建议的 modes 不兼容的 NewSessionTicket。不过如果 Server 一定要这样做，影响的只是 Client 在尝试恢复会话的时候会失败。


Server 不能发送 "psk\_key\_exchange\_modes" 扩展:

```c
      enum { psk_ke(0), psk_dhe_ke(1), (255) } PskKeyExchangeMode;

      struct {
          PskKeyExchangeMode ke_modes<1..255>;
      } PskKeyExchangeModes;
```

- psk\_ke:  
	仅 PSK 密钥建立。在这种模式下，Server 不能提供 "key\_share" 值。

- psk\_dhe\_ke:  
	PSK 和 (EC)DHE 建立。在这种模式下，Client 和 Server 必须提供 "key\_share" 值。

未来分配的任何值都必须要能保证传输的协议消息可以明确的标识 Server 选择的模式。目前 Server 选择的值由 ServerHello 中存在的 "key\_share" 表示。

### 10. Early Data Indication

当使用 PSK 并且 PSK 允许使用 early\_data 的时候，Client 可以在其第一个消息中发送应用数据。如果 Client 选择这么做，则必须发送 "pre\_shared\_key" 和 "early\_data" 扩展。


Early Data Indication 扩展中的 "extension\_data" 字段包含了一个 EarlyDataIndication 值。

```c
      struct {} Empty;

      struct {
          select (Handshake.msg_type) {
              case new_session_ticket:   uint32 max_early_data_size;
              case client_hello:         Empty;
              case encrypted_extensions: Empty;
          };
      } EarlyDataIndication;
```

有关 max\_early\_data\_size 字段的使用请看 [New Session Ticket Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message) 章节。


0-RTT 数据(版本，对称加密套件，应用层协议协商协议[[RFC7301]](https://tools.ietf.org/html/rfc7301)，等等)的参数与使用中的 PSK 参数相关。对于外部配置的 PSK，关联值是由密钥提供的。对于通过 NewSessionTicket 消息建立的 PSK，关联值是在建立 PSK 连接时协商的值。PSK 用来加密 early data 必须是 Client 在 "pre\_shared\_key" 扩展中列出的第一个 PSK。


对于通过 NewSessionTicket 提供的 PSK，Server 必须验证所选 PSK 标识中的 ticket age(从 PskIdentity.obfuscated\_ticket\_age 取 2^32 模中减去 ticket\_age\_add)距离 ticket 发出的时间是否有一个很小的公差。如果相差的时间很多，那么 Server 应该继续握手，但是要拒绝 0-RTT，并且还要假定这条 ClientHello 是新的，也不能采取任何其他措施。


在第一次 flight 中发送的 0-RTT 消息与其他 flight (握手和应用数据)中发送的相同类型的消息具有相同(加密)的内容类型，但受到不同密钥的保护。如果 Server 已经接收了 early data，Client 在收到 Server 的 Finished 消息以后，Client 则会发送 EndOfEarlyData 消息表示密钥更改。这条消息将会使用 0-RTT 的 traffic 密钥进行加密。

Server 接收 "early\_data" 扩展必须以下面三种方式之一操作：

- 忽略 "early\_data" 扩展，并返回常规的 1-RTT 响应。Server 尝试通过用握手中的流量密钥(traffic key)解密收到的记录，并忽略掉 early data。丢弃解密失败的记录(取决于配置的 max\_early\_data\_size)。一旦一个记录被解密成功，它将会被 Server 看做 Client 第二次 flight 的开始并且 Server 会把它当做普通的 1-RTT 来处理。


- 通过回应 HelloRetryRequest 来请求 Client 发送另外一个 ClientHello。Client 不能在这个 ClientHello 中包含 "early\_data" 扩展。Server 通过跳过具有外部内容类型的 "application\_data"(说明他们被加密了) 的所有记录来忽略 early data(同样取决于配置的 max\_early\_data\_size)。

- 在 EncryptedExtensions 中返回自己的 "early\_data" 扩展，表明它准备处理 early data。Server 不可能只接受 early data 消息中的一部分。即使 Server 发送了一条接收 early data 的消息，但是实际上 early data 可能在 Server 生成这条消息的时候已经在 flight 了。

为了接受 early data，Server 必须已经接受了 PSK 密码套件并且选择了 Client 的 "pre\_shared\_key" 扩展中提供的第一个密钥。此外，Server 还需要验证以下的值和选择的 PSK 关联值一样：

- TLS 版本号
- 选择的密码套件
- 选择的 ALPN 协议，如果选择了的话

这些要求是使用相关 PSK 执行 1-RTT 握手所需的超集。对于外部建立的 PSK，关联值是与密钥一起提供的值。对于通过 NewSessionTicket 消息建立的 PSK，关联值是在连接中协商的值，在这期间 ticket 被建立了。

未来的扩展必须定义它们与 0-RTT 的交互。


如果任何检查失败了，Server 不得在响应中附带扩展，并且必须使用上面列出的前两种机制中的一个，丢弃所有 first-flight 数据(因此回落到 1-RTT 或者 2-RTT)。如果 Client 尝试 0-RTT 握手但 Server 拒绝了它，则 Server 通常不会有 0-RTT 记录保护密钥，而必须使用试用解密（使用 1-RTT 握手密钥或者通过在有 HelloRetryRequest 消息的情况下查找明文 ClientHello）找到第一个非 0-RTT 消息。


如果 Server 选择接受 early\_data 扩展，那么在处理 early data 记录的时候，Server 必须遵守用相同的标准(指定的相同错误处理要求)来处理所有记录。具体来说，如果 Server 无法解密已经接受的 "early\_data" 扩展中的记录，则它必须发送 "bad\_record\_mac" alert 消息中止握手。

如果 Server 拒绝 "early\_data" 扩展，则 Client 应用程序可以选择在握手完成后重新发送先前在 early data 中发送的应用数据。请注意，early data 的自动重传可能会导致关于连接状态的误判。例如，当协商连接从用于 early data 的协议中选择不同的 ALPN 协议时，应用程序可能需要构造不同的消息。同样，如果 early data 假定包含有关连接状态的任何内容，则在握手完成后可能会错误地发送这些内容。


TLS 的实现不应该自动重新发送 early data；应用程序可以很好的决定何时重传。除非协商连接选择相同的 ALPN 协议，否则 TLS 实现绝不能自动重新发送 early data。



### 11. Pre-Shared Key Extension

"pre\_shared\_key" 扩展用来协商标识的，这个标识是与 PSK 密钥相关联的给定握手所使用的预共享密钥的标识。


这个扩展中的 "extension\_data" 字段包含一个 PreSharedKeyExtension 值:

```c
      struct {
          opaque identity<1..2^16-1>;
          uint32 obfuscated_ticket_age;
      } PskIdentity;

      opaque PskBinderEntry<32..255>;

      struct {
          PskIdentity identities<7..2^16-1>;
          PskBinderEntry binders<33..2^16-1>;
      } OfferedPsks;

      struct {
          select (Handshake.msg_type) {
              case client_hello: OfferedPsks;
              case server_hello: uint16 selected_identity;
          };
      } PreSharedKeyExtension;
```

- identity:  
	key 的标签。例如，一个 ticket 或者是一个外部建立的预共享密钥的标签。
	
- obfuscated\_ticket\_age:  
	age of the key 的混淆版本。[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-ticket-age)描述了通过 NewSessionTicket 消息建立，如何为标识(identities)生成这个值。对于外部建立的标识(identities)，应该使用 0 的 obfuscated\_ticket\_age，并且 Server 也必须忽略这个值。


- identities:  
	Client 愿意和 Server 协商的 identities 列表。如果和 "early\_data" 一起发送，第一个标识被用来标识 0-RTT 的。
	

- binders:  
	一系列的 HMAC 值。和 identities 列表中的每一个值都一一对应，并且顺序一致。

- selected\_identity:  
	Server 选择的标识，这个标识是以 Client 列表中标识表示为基于 0 的索引。

每一个 PSK 都和单个哈希算法相关联。对于通过 ticket 建立的 PSK，当 ticket 在连接中被建立，这时候用的哈希算法是 KDF 哈希算法。对于外部建立的 PSK，当 PSK 建立的时候，哈希算法必须设置，如果没有设置，默认算法是 SHA-256。Server 必须确保它选择的是兼容的 PSK (如果有的话) 和密钥套件。


在 TLS 1.3 之前的版本中，Server Name Identification (SNI) 的值旨在与会话相关联。Server 被强制要求，与会话关联的 SNI 值要和恢复握手中指定的 SNI 值相互匹配。然而事实上，实现方和他们使用的两个提供的 SNI 值是不一致的，这样就会导致 Client 需要执行一致性的要求。**在 TLS 1.3 版本中，SNI 的值始终在恢复握手中被明确的指出，并且 Server 不需要将 SNI 值和 ticket 相关联**。不过 Client 需要将 SNI 和 PSK 一起存储，以满足 [[4.6.1 章节]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message) 的要求。


实现者请注意：会话恢复是 PSK 最主要的用途，实现 PSK/密钥套件 匹配要求的最直接的方法是先协商密码套件，然后再排除任何不兼容的 PSK。任何未知的 PSK (例如：不在 PSK 数据库中，或者用未知的 key 进行编码的)都必须忽略。如果找不到可接受的 PSK，如果可能，Server 应该执行 non-PSK 握手。如果向后兼容性很重要，Client 提供的，外部建立的 PSK 应该影响密码套件的选择。


在接受PSK密钥建立之前，Server 必须先验证相应的 binder 值(见 [[4.2.11.2 节]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-psk-binder))。如果这个值不存在或者未验证，则 Server 必须立即中止握手。Server 不应该尝试去验证多个 binder，而应该选择单个 PSK 并且仅验证对应于该 PSK 的 binder。见 [Appendix E.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E5%85%AD-psk-identity-exposure) 和 [[8.2 节]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording) 描述了针对这个要求的安全性解释。为了接受 PSK 密钥建立连接，Server 发送 "pre\_shared\_key" 扩展，标明它所选择的 identity。


Client 必须验证 Server 的 selected\_identity 是否在 Client 提供的范围之内。Server 选择的加密套件标明了与 PSK 关联的哈希算法，如果 ClientHello "psk\_key\_exchange\_modes" 有需要，Server 还应该发送 "key\_share" 扩展。如果这些值不一致，Client 必须立即用 "illegal\_parameter" alert 消息中止握手。


如果 Server 提供了 "early\_data" 扩展，Client 必须验证 Server 的 selected\_identity 是否为 0。如果返回任何其他值，Client 必须使用 "illegal\_parameter" alert 消息中止握手。


"pre\_shared\_key" 扩展必须是 ClientHello 中的最后一个扩展(这有利于下面的描述的实现)。Server 必须检查它是最后一个扩展，否则用 "illegal\_parameter" alert 消息中止握手。


#### (1) Ticket Age


从 Client 的角度来看，ticket 的时间指的是，收到 NewSessionTicket 消息开始到当前时刻的这段时间。Client 决不能使用时间大于 ticket 自己标明的 "ticket\_lifetime" 这个时间的 ticket。每个 PskIdentity 中的 "obfuscated\_ticket\_age" 字段都必须包含 ticket 时间的混淆版本，混淆方法是用 ticket 时间(毫秒为单位)加上 "ticket\_age\_add" 字段，最后对 2^32 取模。除非这个 ticket 被重用了，否则这个混淆就可以防止一些相关联连接的被动观察者。注意，NewSessionTicket 消息中的 "ticket\_lifetime"  字段是秒为单位，但是 "obfuscated\_ticket\_age" 是毫秒为单位。因为 ticke lifetime 限制为一周，32 位就足够去表示任何合理的时间，即使是以毫秒为单位也可以表示。


#### (2) PSK Binder

PSK binder 的值形成了 2 种绑定关系，一种是 PSK 和当前握手的绑定，另外一种是 PSK 产生以后(如果是通过 NewSessionTicket 消息)的握手和当前握手的绑定。每一个在 binder 列表中的条目都会根据有一部分 ClientHello 的哈希副本计算 HMAC，最终 HMAC 会包含 PreSharedKeyExtension.identities 字段。也就是说，HMAC 包含所有的 ClientHello，但是不包含 binder list 。如果存在正确长度的 binders，消息的长度字段（包括总长度，扩展块的长度和 "pre\_shared\_key" 扩展的长度）都被设置。


PskBinderEntry 的计算方法和 Finished 消息一样。但是 BaseKey 是派生的 binder\_key，派生方式是通过提供的相应的 PSK 的密钥派生出来的。

如果握手包括 HelloRetryRequest 消息，则初始的 ClientHello 和 HelloRetryRequest 随着新的 ClientHello 一起被包含在副本中。例如，如果 Client 发送 ClientHello，则其 binder 将通过以下方式计算：

```c
      Transcript-Hash(Truncate(ClientHello1))
```

Truncate() 函数的作用是把 ClientHello 中的 binders list 移除。

如果 Server 响应了 HelloRetryRequest，那么 Client 会发送 ClientHello2，它的 binder 会通过以下方式计算：

```c
      Transcript-Hash(ClientHello1,
                      HelloRetryRequest,
                      Truncate(ClientHello2))
```

完整的 ClientHello1/ClientHello2 都会包含在其他的握手哈希计算中。请注意，在第一次发送中，`Truncate(ClientHello1)` 是直接计算哈希的，但是在第二次发送中，ClientHello1 计算哈希，并且还会再注入一条 "message\_hash" 消息。


#### (3) Processing Order

Client 被允许流式的发送 0-RTT 数据，直到它收到 Server 的 Finished 消息。Client 收到 Finished 消息以后，需要在握手的末尾，发送 EndOfEarlyData 消息。为了防止死锁，当 Server 接收 "early\_data" 消息的时候，Server 必须立即处理 Client 的 ClientHello 消息，然后立即回应 ServerHello，而不是等待收到 Client 的 EndOfEarlyData 消息以后再发送 ServerHello。


## 三. Server Parameters


Server 接下来的 2 条消息，EncryptedExtensions 和 CertificateRequest 消息，包含来自 Server 的消息，这个 Server 确定了握手的其余部分。这些消息是加密的，通过从 server\_handshake\_traffic\_secret 中派生的密钥加密的。


### 1. Encrypted Extensions


在所有的握手中，Server 必须在 ServerHello 消息之后立即发送 EncryptedExtensions 消息。这是在从 server\_handshake\_traffic\_secret 派生的密钥下加密的第一条消息。

EncryptedExtensions 消息包含应该被保护的扩展。即，任何不需要建立加密上下文但不与各个证书相互关联的扩展。Client 必须检查 EncryptedExtensions 消息中是否存在任何禁止的扩展，如果有发现禁止的扩展，必须立即用 "illegal\_parameter" alert 消息中止握手。


```c
   Structure of this message:

      struct {
          Extension extensions<0..2^16-1>;
      } EncryptedExtensions;
```

- extensions:   
	扩展列表。


### 2. Certificate Request

使用证书进行身份验证的 Server 可以选择性的向 Client 请求证书，这条请求消息(如果发送了)要跟在 EncryptedExtensions 消息后面。

消息的结构体：

```c
      struct {
          opaque certificate_request_context<0..2^8-1>;
          Extension extensions<2..2^16-1>;
      } CertificateRequest;
```


- certificate_request_context:  
	一个不透明的字符串，这个字符串用来标识证书请求，并在 Client 的 Certificate 消息中回显。certificate\_request\_context 必须在本次连接中必须是唯一的(从而防止 Client 的 CertificateVerify 重放攻击)。这个字段一般情况下都是 0 长度，除非用于 [[4.6.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-post-handshake-authentication) 中描述的握手后身份验证交换。当请求握手后身份验证以后，Server 应该发送不可预测的上下文给 Client (例如，用随机数生成)，这样是为了防止攻击者破解。攻击者可以预先计算有效的 CertificateVerify 消息，从而获取临时的 Client 私钥的权限。


- extensions:  
	一组描述正在请求的证书需要的参数扩展集。"signature\_algorithms" 扩展必须是特定的，如果其他的扩展被这个消息所定义，那么其他扩展也可能可选的被包含进来。Client 必须忽略不能识别的扩展。


在 TLS 1.3 之前的版本中，CertificateRequest 消息携带了签名算法列表和 Server 可接受的证书授权列表。在 TLS 1.3 中，签名算法列表可以通过 "signature\_algorithms" 和可选的 "signature_algorithms_cert" 扩展来表示。而后者证书授权列表可以通过发送 "certificate\_authorities" 扩展来表示。


通过 PSK 进行验证的 Server 不能在主握手中发送 CertificateRequest 消息，不过它们可能可以在握手后身份验证中发送 CertificateRequest 消息，前提是 Client 已经发送了 "post\_handshake\_auth" 扩展名。




## 四. Authentication Messages

正如我们在 [section-2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3.md#%E4%BA%94tls-13-%E5%8D%8F%E8%AE%AE%E6%A6%82%E8%A7%88) 中讨论的，TLS 使用一组通用的消息用于身份验证，密钥确认和握手的正确性：Certificate, CertificateVerify 和 Finished。(PSK binders 也以类似的方式进行密钥确认)。这三条消息总是作为握手消息的最后三条消息。Certificate 和 CertificateVerify 消息如下面描述的那样，只在某些情况才会发送。Finished 的消息总是作为认证块的一部分发送。这些消息使用从 sender\_handshake\_traffic\_secret 派生出来的密钥进行加密。

Authentication 消息的计算统一采用以下的输入方式：

- 要使用证书和签名密钥
- 握手上下文由哈希副本中的一段消息集组成
- Base key 用于计算 MAC 密钥

基于这些输入，消息包含：

- Certificate：  
  用于认证的证书和链中任何支持的证书。请注意，基于证书的 Client 身份验证在 PSK 握手流中不可用(包括 0-RTT)

- CertificateVerify:   
  根据 Transcript-Hash(Handshake Context, Certificate) 的值得出的签名

- Finished:   
  根据 Transcript-Hash(Handshake Context, Certificate, CertificateVerify) 的值得出的 MAC 。使用从 Base key 派生出来的 MAC key 计算的 MAC 值。

对于每个场景，下表定义了握手上下文和 MAC Base Key    

```c
   +-----------+-------------------------+-----------------------------+
   | Mode      | Handshake Context       | Base Key                    |
   +-----------+-------------------------+-----------------------------+
   | Server    | ClientHello ... later   | server_handshake_traffic_   |
   |           | of EncryptedExtensions/ | secret                      |
   |           | CertificateRequest      |                             |
   |           |                         |                             |
   | Client    | ClientHello ... later   | client_handshake_traffic_   |
   |           | of server               | secret                      |
   |           | Finished/EndOfEarlyData |                             |
   |           |                         |                             |
   | Post-     | ClientHello ... client  | client_application_traffic_ |
   | Handshake | Finished +              | secret_N                    |
   |           | CertificateRequest      |                             |
   +-----------+-------------------------+-----------------------------+
```


### 1. The Transcript Hash

TLS 中的许多加密计算都使用了哈希副本。这个值是通过级联每个包含的握手消息的方式进来哈希计算的，它包含握手消息头部携带的握手消息类型和长度字段，但是不包括记录层的头部。例如：

```c
Transcript-Hash(M1, M2, ... Mn) = Hash(M1 || M2 || ... || Mn)
```

作为此一般规则的例外，当 Server 用一条 HelloRetryRequest 消息来响应一条 ClientHello 消息时，ClientHello1 的值替换为包含 Hash(ClientHello1）的握手类型为 "message\_hash" 的特殊合成握手消息。例如：

```c
  Transcript-Hash(ClientHello1, HelloRetryRequest, ... Mn) =
      Hash(message_hash ||        /* Handshake type */
           00 00 Hash.length  ||  /* Handshake message length (bytes) */
           Hash(ClientHello1) ||  /* Hash of ClientHello1 */
           HelloRetryRequest  || ... || Mn)
```

设计这种结构的原因是允许 Server 通过在 cookie 中仅存储 ClientHello1 的哈希值来执行无状态 HelloRetryRequest，而不是要求它导出整个中间哈希状态。

具体而言，哈希副本始终取自于下列握手消息序列，从第一个 ClientHello 开始，仅包括已发送的消息：ClientHello, HelloRetryRequest, ClientHello, ServerHello, EncryptedExtensions, server CertificateRequest, server Certificate, server CertificateVerify, server Finished, EndOfEarlyData, client Certificate, client CertificateVerify, client Finished。

通常上，实现方可以下面的方法来实现哈希副本：根据协商的哈希来维持一个动态的哈希副本。请注意，随后的握手后认证不会相互包含，只是通过主握手结束的消息。


### 2. Certificate

此消息将端点的证书链发给对端。

每当约定的密钥交换方法是用证书进行认证(这包括本文档中除了 PSK 以外定义的所有密钥交换方法)的时候，Server 就必须发送 Certificate 消息。

当且仅当 Server 通过发送 CertificateRequest 消息请求 Client 认证时，Client 必须发送 Certificate 消息。


如果 Server 请求 Client 认证但没有合适的证书可用，则 Client 必须发送不包含证书的证书消息(例如，具有长度为 0 的 "certificate\_list" 字段)。Finished 消息必须发送，无论 Certificate 消息是否为空。

Certificate 消息的结构体是：


```c
      enum {
          X509(0),
          RawPublicKey(2),
          (255)
      } CertificateType;

      struct {
          select (certificate_type) {
              case RawPublicKey:
                /* From RFC 7250 ASN.1_subjectPublicKeyInfo */
                opaque ASN1_subjectPublicKeyInfo<1..2^24-1>;

              case X509:
                opaque cert_data<1..2^24-1>;
          };
          Extension extensions<0..2^16-1>;
      } CertificateEntry;

      struct {
          opaque certificate_request_context<0..2^8-1>;
          CertificateEntry certificate_list<0..2^24-1>;
      } Certificate;
```

- certificate\_request\_context:  
	如果此消息是响应 CertificateRequest 消息的，则该消息中的 certificate\_request\_context 的值不为 0。否则(在 Server 认证的情况下)，该字段应为零长度。


- certificate\_list:  
	这是一个 CertificateEntry 结构的序列(链)，每个结构包含单个证书和一组扩展。

- extensions:  
	CertificateEntry 的一组扩展值。"Extension" 的格式在 [[Section 4.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions) 中定义了。有效的扩展包括 OCSP 状态扩展 [[RFC6066]](https://tools.ietf.org/html/rfc6066) 和 SignedCertificateTimestamp [[RFC6962]](https://tools.ietf.org/html/rfc6962) 扩展。未来可以为此消息定义一些新的扩展。Server 的 Certificate 消息中的扩展必须对应于 ClientHello 消息中的扩展。Client 的 Certificate 消息中的扩展必须对应于 Server 的 CertificateRequest 消息中的扩展。如果一个扩展适应用于整个链，它应该被包括在第一个 CertificateEntry 中。
	

如果没有在 EncryptedExtensions 中协商相应的证书类型扩展名 ("server\_certificate\_type" 或 "client\_certificate\_type")，或者协商了 X.509 证书类型，则每个 CertificateEntry 都要包含 DER 编码的 X.509 证书。发件者的证书必须位于列表中的第一个 CertificateEntry 中。之后的每个证书都应该直接证明其前面的证书。由于证书验证要求信任锚独立分发，因此可以从链中省略指定信任锚的证书(前提是已知支持的对等方拥有可省略的证书)。
	
注意：TLS 1.3 之前的版本，"certificate\_list" 排序需要每个证书要证明紧接在其前面的证书，然而，一些实现允许一些灵活性。Server 有时为了过渡的目的而发送当前和已弃用的中间体，而其他的配置不正确，但这些情况仍然可以正确地验证。为了最大程度的兼容性，所有实现应该准备处理可能是无关紧要的证书和 TLS 版本的任意排序，但最终实体证书(排序的顺序)必须是第一个。

如果协商了 RawPublicKey 证书类型，则 certificate\_list 必须包含不超过一个CertificateEntry，CertificateEntry 中包含定义在 [[RFC7250], Section 3](https://tools.ietf.org/html/rfc7250#section-3) 中的 ASN1\_subjectPublicKeyInfo 值。
	

OpenPGP 证书类型禁止在 TLS 1.3 中使用。

Server 的 certificate\_list 必须始终是非空的。如果 Client 没有适当的证书要发送以响应 Server 的身份验证请求，则会发送空的 certificate\_list。

#### (1) OCSP Status and SCT Extensions

[[RFC6066]](https://tools.ietf.org/html/rfc6066) 和 [[RFC6961]](https://tools.ietf.org/html/rfc6961) 提供了协商 Server 向 Client 发送 OCSP 响应的扩展。 在 TLS 1.2 及以下版本中，Server 回复空的扩展名以表示对此扩展的协商，并且在 CertificateStatus 消息中携带 OCSP 信息。在 TLS 1.3 中，Server 的 OCSP 信息在包含相关证书的 CertificateEntry 中的扩展中。特别的，来自 Server 的 "status\_request" 扩展的主体必须是分别在 [[RFC6066]](https://tools.ietf.org/html/rfc6066) 和 [[RFC6960]](https://tools.ietf.org/html/rfc6960) 中定义的 CertificateStatus 结构。


注意：status\_request\_v2 扩展 [[RFC6961]](https://tools.ietf.org/html/rfc6961) 已经废弃了，TLS 1.3 不能根据它是否存在或者根据它的信息来出来 ClientHello 消息。特别是，禁止在 EncryptedExtensions, CertificateRequest 和 Certificate 消息中发送 status\_request\_v2 扩展。TLS 1.3 的 Server 必须要能够处理包含它的 ClientHello 消息，因为这条消息可能是由希望在早期协议版本中使用它的 Client 发送的。


Server 可以通过在其 CertificateRequest 消息中发送空的 "status\_request" 扩展来请求 Client 使用其证书来做 OCSP 的响应。如果 Client 选择性的发送 OCSP 响应，则其 "status\_request" 扩展的主体必须是在 [[RFC6966]](https://tools.ietf.org/html/rfc6966) 中定义的 CertificateStatus 结构。


类似地，[[RFC6962]](https://tools.ietf.org/html/rfc6962) 为 Server 提供了一种机制，用在 TLS 1.2 及更低版本中的，可在 ServerHello 中发送签名证书时间戳 (SCT) 的扩展。 在 TLS 1.3 中，Server 的 SCT 信息在 CertificateEntry 的扩展中。


#### (2) Server Certificate Selection

以下规则适用于 Server 发送的证书:

- 证书类型必须是 X.509v3 [[RFC5280]](https://tools.ietf.org/html/rfc5280)，除非另有明确协商（例如，[[RFC5081]](https://tools.ietf.org/html/rfc5081)）

- Server 的终端实体证书的公钥（和相关限制）必须与 Client的 "signature\_algorithms" 扩展(目前为RSA，ECDSA 或 EdDSA)中的所选认证算法兼容。

- 证书必须允许密钥用于签名（即，如果存在密钥用法扩展，则必须设置 digitalSignature 位），并在 Client 的"signature\_algorithms"/"signature\_algorithms\_cert" 扩展中指示签名方案。


- "server\_name" [[RFC6066]](https://tools.ietf.org/html/rfc6066) 和 "certificate\_authorities" 扩展用于指导证书选择。由于 Server 可能需要存在 "server\_name" 扩展名，因此 Client 应该在适用时发送此扩展名。

如果 Server 能够提供证书链，Server 所有的证书都必须由 Client 提供的签名算法签名。自签名的证书或预期为信任锚的证书不会作为链的一部分进行验证，因此可以使用任何算法进行签名。


如果 Server 不能产生只通过所指示的支持的算法签名的证书链，则它应当通过向 Client 发送其选择的证书链来继续握手，该证书链可能会包括 Client 不知道能否支持的算法。这个回退链可以只在 Client 允许的情况下才可以使用已弃用的 SHA-1 哈希算法，其他情况都必须禁止使用 SHA-1 哈希算法。


如果 Client 无法使用提供的证书构造可接受的证书链，那么必须中止握手。中止握手并发送证书相关的 alert 消息(默认的，发送 "unsupported\_certificate" alert 消息)


如果 Server 有多张证书，它会根据上述标准(除了其他标准以外，如传输层端点，本地配置和首选项)选择其中的一个证书。



#### (3) Client Certificate Selection

以下的规则适用于 Client 发送的证书:

- 证书类型必须是 X.509v3 [[RFC5280]](https://tools.ietf.org/html/rfc5280)，除非另有明确协商（例如，[[RFC5081]](https://tools.ietf.org/html/rfc5081)）

- 如果 CertificateRequest 消息中 "certificate\_authorities" 扩展不为空，则证书链中的至少一个证书应该由所列出的 CA 之一发布的。

- 证书必须使用可接受的签名算法签名，如第 4.3.2 节所述。注意，这放宽了在 TLS 的先前版本中发现的证书签名算法的约束。

- 如果 CertificateRequest 消息包含非空的 "oid\_filters" 扩展，则终端实体证书必须匹配 Client 识别的扩展 OID，如第 4.2.5 节中所述。



#### (4) Receiving a Certificate Message


通常，详细的证书验证程序超出了 TLS 的范围(参见[[RFC5280]](https://tools.ietf.org/html/rfc5280))。 本节提供特定于 TLS 的要求。

如果 Server 提供空的证书消息，则 Client 必须使用 "decode\_error" alert 消息中止握手。

如果 Client 没有发送任何证书(即，它发送一个空的证书消息)，Server 可以自行决定是否在没有 Client 认证的情况下继续握手，或者使用 "certificate\_required" alert 消息中止握手。此外，如果证书链的某些方面是不可接受的(例如，它未由已知的可信 CA 签名)，则 Server 可以自行决定是继续握手(考虑 Client 还没有经过身份验证)还是中止握手。

任何端点接收任何需要使用任何签名算法使用 MD5 哈希验证的证书都必须使用 "bad\_certificate" alert 消息中止握手。不推荐使用 SHA-1，并且建议任何接收任何使用 SHA-1 哈希使用任何签名算法验证的证书的端点都会使用 "bad\_certificate" alert 消息中止握手。为清楚起见，这意味着端点可以接受这些算法用于自签名或信任锚的证书。


建议所有端点尽快转换为 SHA-256 或更好的算法，以保持与当前正在逐步淘汰 SHA-1 支持的实现的互操作性。


请注意，包含一个签名算法的密钥的证书可以使用不同的签名算法进行签名(例如，使用 ECDSA 密钥签名的 RSA 密钥)。


### 3. Certificate Verify

此消息用于提供端点拥有与其证书对应的私钥的明确证据。CertificateVerify 消息还为到此为止的握手提供完整性。Server 必须在通过证书进行身份验证时发送此消息。每当通过证书进行身份验证时(即，当证书消息非空时)，Client 必须发送此消息。发送时，此消息必须在 Certificate 消息之后立即出现，并且紧接在 Finished 消息之前。


这条消息的结构体是:

```c
      struct {
          SignatureScheme algorithm;
          opaque signature<0..2^16-1>;
      } CertificateVerify;
```

algorithm 字段指定使用的签名算法(有关此类型的定义，请参见第 4.2.3 节)。signature 字段是使用该算法的数字签名。签名中涵盖的内容是第 4.4.1 节中描述的哈希输出，即：

```c
      Transcript-Hash(Handshake Context, Certificate)
```

计算数字签名是级联计算的：

- 由八位字节32(0x20)组成的字符串重复 64 次
- 上下文字符串
- 用作分隔符的单个0字节
- 要签名的内容


设计这个结构目的是为了防止对先前版本的 TLS 的攻击，其中 ServerKeyExchange 格式意味着攻击者可以获得具有所选 32 字节前缀(ClientHello.random)的消息的签名。 最初的 64 字节填充将清除 Server 控制的 ServerHello.random 中的前缀。

Server 签名的上下文字符串是 "TLS 1.3，Server CertificateVerify"。Client 签名的上下文字符串是 "TLS 1.3，Client CertificateVerify"。它用于在不同的上下文中提供签名之间的分离，帮助抵御潜在的跨协议攻击。

例如，如果 hash副本 是 32 字节 01(这个长度对 SHA-256 有意义)，Server 的 CertificateVerify 的数字签名所涵盖的内容将是：

```c
      2020202020202020202020202020202020202020202020202020202020202020
      2020202020202020202020202020202020202020202020202020202020202020
      544c5320312e332c207365727665722043657274696669636174655665726966
      79
      00
      0101010101010101010101010101010101010101010101010101010101010101
```

在发送方，用于计算 CertificateVerify 消息的签名字段的过程作为输入:

- 数字签名算涵盖的内容

- 与上一条消息中发送的证书对应的私有签名密钥


如果由 Server 发送 CertificateVerify 消息，则签名算法必须是 Client "signature\_algorithms" 扩展中提供的，除非在没有不支持的算法的情况下不能生成有效的证书链(除非当前支持的算法都不能生成有效的证书链)。

如果由 Client 发送，则签名中使用的签名算法必须是 CertificateRequest 消息中 "signature\_algorithms" 扩展的 supported\_signature\_algorithms 字段中存在的签名算法之一。

另外，签名算法必须与发送者的终端实体证书中的密钥兼容。无论 RSASSA-PKCS1-v1\_5 算法是否出现在 "signature\_algorithms" 中，RSA 签名都必须使用 RSASSA-PSS 算法。SHA-1 算法禁止用于 CertificateVerify 消息的任何签名。

本规范中的所有 SHA-1 签名算法仅定义用于旧证书，并且对 CertificateVerify 签名无效。

CertificateVerify 消息的接收者必须验证签名字段。验证过程作为输入：

- 数字签名所涵盖的内容

- 在关联的证书消息中找到的最终实体证书中包含的公钥

- 在 CertificateVerify 消息的签名字段中收到的数字签名

如果验证失败，接收方必须通过 "decrypt\_error" 警报终止握手。


### 4. Finished


Finished 消息是认证块中的最后一条消息。它对提供握手和计算密钥的身份验证起了至关重要的作用。

Finished 消息的收件人必须验证内容是否正确，如果不正确，必须使用 "decrypt\_error" alert 消息终止连接。

一旦一方已发送其 Finished 消息并已收到并验证来自其对端的 Finished 消息，它就可以开始通过该连接发送和接收应用数据。有两种设置允许在接收对端的 Finished 之前发送数据:

1. 如 [Section 4.2.10](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#10-early-data-indication) 中所述，Client 可以发送 0-RTT 数据。
2. Server 可以在第一个 flight 之后就发送数据，但是因为握手还没有完成，所以不能保证对端的身份正确性，以及对端是否还在线。(ClientHello 可能重播)

用于计算 Finished 消息的密钥是使用 HKDF，它是从第 4.4 节中定义的 Base Key 计算而来的(参见第7.1节)。特别的:

```c
   finished_key =
       HKDF-Expand-Label(BaseKey, "finished", "", Hash.length)
```


这条消息的数据结构是:

```c
      struct {
          opaque verify_data[Hash.length];
      } Finished;
```

verify\_data 按照如下方法计算:

```c
      verify_data =
          HMAC(finished_key,
               Transcript-Hash(Handshake Context,
                               Certificate*, CertificateVerify*))

      * Only included if present.
```


HMAC [[RFC2104]](https://tools.ietf.org/html/rfc2104) 使用哈希算法进行握手。如上所述，HMAC 输入通常是通过动态的哈希实现的，即，此时仅是握手的哈希。

在以前版本的 TLS 中，verify\_data 的长度总是 12 个八位字节。在 TLS 1.3 中，它是用来表示握手的哈希的 HMAC 输出的大小。

**注意：警报和任何其他非握手记录类型不是握手消息，并且不包含在哈希计算中**。

Finished 消息之后的任何记录都必须在适当的 client\_application\_traffic\_secret\_N 下加密，如第 7.2 节所述。特别是，这包括 Server 为了响应 Client 的 Certificate 消息和 CertificateVerify 消息而发送的任何 alert。




### 5. End of Early Data


```c
      struct {} EndOfEarlyData;
```

如果 Server 在 EncryptedExtensions 中发送了 "early\_data" 扩展，则 Client 必须在收到 Server 的 Finished 消息后发送 EndOfEarlyData 消息。 如果 Server 没有在 EncryptedExtensions中发送 "early\_data" 扩展，那么 Client 绝不能发送 EndOfEarlyData 消息。此消息表示已传输完了所有 0-RTT application\_data消息(如果有)，并且接下来的记录受到握手流量密钥的保护。Server 不能发送此消息，Client 如果收到了这条消息，那么必须使用 "unexpected\_message" alert 消息终止连接。这条消息使用从 client\_early\_traffic\_secret 中派生出来的密钥进行加密保护。


### 6. Post-Handshake Messages


TLS 还允许在主握手后发送其他的消息。这些消息使用握手内容类型，并使用适当的应用程序流量密钥进行加密。


#### (1) New Session Ticket Message

在 Server 接收到 Client 的 Finished 消息以后的任何时刻，它都可以发送 NewSessionTicket 消息。此消息在 ticket 值和从恢复主密钥派生出来的 PSK 之间创建了唯一的关联。


Client 在 ClientHello 消息中包含 "pre\_shared\_key" 扩展，并在扩展中包含 ticket ，那么 Client 就可能在未来的握手中使用 PSK。Server 可能在一个连接中发送多个 ticket，发送时机可能是一个接一个的立即发送，也可能是在某个特定事件以后发送。例如，Server 可能会在握手后身份验证之后发送新的 ticket，以封装其他 Client 身份验证状态。多个 ticket 对于 Client 来说，可用于各种目的，例如：

- 打开多个并行的 HTTP 连接

- 通过(例如) Happy Eyeballs [[RFC8305]](https://tools.ietf.org/html/rfc8305) 或相关的技术在接口和地址簇上进行连接竞争


任何 ticket 必须只能使用与用于建立原始连接的 KDF 哈希算法相同的密码套件来恢复会话。

Client 必须只有在新的 SNI 值对原始会话中提供的 Server 证书有效时才能恢复，并且只有在 SNI 值与原始会话中使用的 SNI 值匹配时才应恢复。后者是性能优化：通常，没有理由期望单个证书所涵盖的不同 Server 之间能够相互接受彼此的 ticket；因此，在这种情况下尝试恢复会话将会浪费一次性的 ticket。如果提供了这种指示(外部或通过任何其他方式)，则 Client 可能可以使用不同的 SNI 值进行恢复会话。


在恢复会话时，如果向调用的应用程序报告 SNI 值，则实现方必须使用在恢复 ClientHello 中发送的值而不是在先前会话中发送的值。请注意，如果 Server 的实现拒绝了不同 SNI 值的所有 PSK 标识，则这两个值总是相同。

注意：虽然恢复主密钥取决于 Client 的第二次 flight，但是不请求 Client 身份验证的 Server 可以独立计算转录哈希的剩余部分，然后在发送 Finished 消息后立即发送 NewSessionTicket 而不是等待 Client 的 Finished 消息。这可能适用于 Client 需要并行打开多个 TLS 连接并且可以从减少恢复握手的开销中受益的情况。

```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```


- ticket\_lifetime：  
	这个字段表示 ticket 的生存时间，这个时间是以 ticket 发布时间为网络字节顺序的 32 位无符号整数表示以秒为单位的时间。Server 禁止使用任何大于 604800秒(7 天)的值。值为零表示应立即丢弃 ticket。无论 ticket\_lifetime 如何，Client 都不得缓存超过 7 天的 ticket，并且可以根据本地策略提前删除 ticket。Server 可以将 ticket 视为有效的时间段短于 ticket\_lifetime 中所述的时间段。

- ticket\_age\_add:   
	安全的生成的随机 32 位值，用于模糊 Client 在 "pre\_shared\_key" 扩展中包含的 ticket 的时间。Client 的 ticket age 以模 2 ^ 32 的形式添加此值，以计算出 Client 要传输的值。Server 必须为它发出的每个 ticket 生成一个新值。

- ticket\_nonce:  
	每一个 ticket 的值，在本次连接中发出的所有的 ticket 中是唯一的。

- ticket:  
	这个值是被用作 PSK 标识的值。ticket 本身是一个不透明的标签。它可以是数据库查找键，也可以是自加密和自我验证的值。

- extensions：  
	ticket 的一组扩展值。扩展格式在 4.2 节中定义的。Client 必须忽略无法识别的扩展。
	
当前为 NewSessionTicket 定义的唯一扩展名是 "early\_data"，表示该 ticket 可用于发送 0-RTT 数据(第4.2.10节)。 它包含以下值：

- max\_early\_data\_size:    
	这个字段表示使用 ticket 时允许 Client 发送的最大 0-RTT 数据量(以字节为单位)。数据量仅计算应用数据有效载荷(即，明文但不填充或内部内容类型字节)。Server 如果接收的数据大小超过了 max\_early\_data\_size 字节的 0-RTT 数据，应该立即使用 "unexpected\_message" alert 消息终止连接。请注意，由于缺少加密材料而拒绝 early data 的 Server 将无法区分内容中的填充部分，因此 Client 不应该依赖于能够在 early data 记录中发送大量填充内容。


PSK 关联的 ticket 计算方法如下：

```c
       HKDF-Expand-Label(resumption_master_secret,
                        "resumption", ticket_nonce, Hash.length)
```

因为 ticket\_nonce 值对于每个 NewSessionTicket 消息都是不同的，所以每个 ticket 会派生出不同的 PSK。

请注意，原则上可以继续发布新 ticket，该 ticket 无限期地延长生命周期，这个生命周期是最初从初始非 PSK 握手中(最可能与对等证书相关联)派生得到的密钥材料的生命周期。
 

建议实现方对密钥材料这些加上总寿命时间的限制。这些限制应考虑到对等方证书的生命周期，干预撤销的可能性以及自从对等方在线 CertificateVerify 签名到当前时间的这段时间。


#### (2) Post-Handshake Authentication

当 Client 发送了 "post\_handshake\_auth" 扩展(参见第4.2.6节)时，Server 可以在握手完成后随时通过发送 CertificateRequest 消息来请求客户端身份验证。Client 必须使用适当的验证消息进行响应(参见第4.4节)。如果 Client 选择进行身份验证，则必须发送 Certificate，CertificateVerify，Finished 消息。如果 Client 拒绝身份验证，它必须发送一个 Certificate 证书消息，其中不包含证书，然后是 Finished 消息。响应 Server 的所有 Client 消息必须连续出现在线路上，中间不能有其他类型的消息。


在没有发送 "post\_handshake\_auth" 扩展的情况下接收 CertificateRequest 消息的 Client 必须发送 "unexpected\_message" alert 消息。


注意：由于 Client 身份验证可能涉及提示用户，因此 Server 必须做好一些延迟的准备，包括在发送 CertificateRequest 和接收响应之间接收任意数量的其他消息。此外，Client 如果连续接收到了多个 CertificateRequests 消息，Client 可能会以不同于它们的顺序响应它们(certificate\_request\_context 值允许服务器消除响应的歧义)



#### (3) Key and Initialization Vector Update

KeyUpdate 握手消息用于表示发送方正在更新其自己的发送加密密钥。任何对等方在发送 Finished 消息后都可以发送此消息。在接收 Finished 消息之前接收 KeyUpdate 消息的，实现方必须使用 "unexpected\_message" alert 消息终止连接。发送 KeyUpdate 消息后，如第 7.2 节所描述的计算方法，发送方应使用新一代的密钥发送其所有流量。收到 KeyUpdate 后，接收方必须更新其接收密钥。


```c
      enum {
          update_not_requested(0), update_requested(1), (255)
      } KeyUpdateRequest;

      struct {
          KeyUpdateRequest request_update;
      } KeyUpdate;
```

- request\_update:  
	这个字段表示 KeyUpdate 的收件人是否应使用自己的 KeyUpdate 进行响应。 如果实现接收到任何其他的值，则必须使用 "illegal\_parameter" alert 消息终止连接。
	

如果 request\_update 字段设置为 "update\_requested"，则接收方必须在发送其下一个应用数据记录之前发送自己的 KeyUpdate，其中 request\_update 设置为 "update\_not\_requested"。此机制允许任何一方强制更新整个连接，但会导致一个实现方接收多个 KeyUpdates，并且它还是静默的响应单个更新。请注意，实现方可能在发送 KeyUpdate (把 request\_update 设置为 "update\_requested") 与接收对等方的 KeyUpdate 之间接收任意数量的消息，因为这些消息可能早就已经在传输中了。但是，由于发送和接收密钥是从独立的流量密钥中导出的，因此保留接收流量密钥并不会影响到发送方更改密钥之前发送的数据的前向保密性。


如果实现方独立地发送它们自己的 KeyUpdates，其 request\_update 设置为 "update\_requested" 并且它们的消息都是传输中，结果是双方都会响应，双方都会更新密钥。


发送方和接收方都必须使用旧密钥加密其 KeyUpdate 消息。另外，在接受使用新密钥加密的任何消息之前，双方必须强制接收带有旧密钥的 KeyUpdate。如果不这样做，可能会引起消息截断攻击。














------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Handshake\_Protocol/](https://halfrost.com/tls_1-3_handshake_protocol/)