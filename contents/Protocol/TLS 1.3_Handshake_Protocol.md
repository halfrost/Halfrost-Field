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
	
TLS 1.3 Client 接收到 TLS 1.2 或者 TLS 更老的版本的 ServerHello 消息以后，必须要检查 ServerHello 中的 Random 字段的最后 8 字节不等于上面 2 个值猜对。TLS 1.2 的 Client 也需要检查最后 8 个字节，如果协商的是 TLS 1.1 或者是更老的版本，那么 Random 值也不应该等于上面第二个值。如果都没有匹配上，那么 Client 必须用 "illegal\_parameter" alert 消息中止握手。这种机制提供了有限的保护措施，抵御降级攻击。通过 Finished exchange ，能超越保护机制的保护范围：因为在 TLS 1.2 或更低的版本上，ServerKeyExchange 消息包含 2 个随机值的签名。只要使用了临时的加密方式，攻击者就不可能在不被发现的情况下，修改随机值。所以对于静态的 RSA，是无法提供降级攻击的保护。

>请注意，上面这些改动在 [RFC5246]() 中说明的，实际上许多 TLS 1.2 的 Client 和 Server 都没有按照上面的规定来实践。

如果 Client 在重新协商 TLS 1.2 或者更老的版本的时候，协商过程中收到了 TLS 1.3 的 ServerHello，这个时候 Client 必须立即发送 “protocol\_version” alert 中止握手。请注意，**一旦 TLS 1.3 协商完成，就无法再重新协商了，因为 TLS 1.3 严禁重新协商**。


### 4. Hello Retry Request

如果在 Client 发来的 ClientHello 消息中能够找到一组可以相互支持的参数，但是 Client 又不能为接下来的握手提供足够的信息，这个时候 Server 就需要发送 HelloRetryRequest 消息来响应 ClientHello 消息。在上一节中，谈到 HelloRetryRequest 和 ServerHello 消息是有相同的数据结构，legacy\_version, legacy\_session\_id\_echo, cipher\_suite, legacy\_compression\_method 这些字段的含义也是一样的。为了讨论的方便，下文中，我们讨论 HelloRetryRequest 消息都当做不同的消息来对待。

Server 的扩展集中必须包含 "supported\_versions"。另外，它还需要包含最小的扩展集，能让 Client 生成正确的 ClientHello 对。相比 ServerHello 而言，HelloRetryRequest 只能包含任何在第一次 ClientHello 中出现过的扩展，除了可选的 "cookie" 以外。


Client 接收到 HelloRetryRequest 消息以后，必须要先校验 legacy\_version, legacy\_session\_id\_echo, cipher\_suite, legac\y_compression]_method 这四个参数。先从 “supported\_versions” 开始决定和 Server 建立连接的版本，然后再处理扩展。如果 HelloRetryRequest 不会导致 ClientHello 的任何更改，Client 必须用 “illegal\_parameter” alert 消息中止握手。如果 Client 在一个连接中收到了第 2 个 HelloRetryRequest 消息( ClientHello 本身就是响应 HelloRetryRequest 的)，那么必须用 “unexpected\_message” alert 消息中止握手。

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





------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()