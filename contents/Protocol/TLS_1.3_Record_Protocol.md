# TLS 1.3 Record Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/109_0.png'>
</p>


TLS 记录协议接收要传输的消息，将数据分段为可管理的块，保护记录并传输结果。收到的数据经过验证，解密，重新组装，然后交付给更上层的协议。


TLS 记录允许同一层记录层上复用多个更高层的协议。本文档指定了 4 种内容类型：handshake，application\_data，alert 和 change\_cipher\_spec。change\_cipher\_spec 记录仅用于兼容性目的。


实现方可能会在发送或接收第一个 ClientHello 消息之后，和，在接收到对等方的  Finished 消息之前的任何时间接收由单字节值 0x01 组成的未加密的类型 change\_cipher\_spec 的记录，如果接收到了这种记录，则必须简单地丢弃它而不进行进一步处理。请注意，此记录可能出现在握手中，这时候实现方是期望保护记录的，因此有必要在尝试对记录进行去除保护之前检测此情况。接收到任何其他 change\_cipher\_spec 值或接收到受保护的 change\_cipher\_spec 记录的实现方必须使用 "unexpected\_message" alert 消息中止握手。如果实现方检测到在第一个 ClientHello 消息之前或在对等方的 Finished 消息之后收到的 change\_cipher\_spec 记录，则必须将其视为意外记录类型(尽管无状态的 Server 可能无法将这些情况与允许的情况区分开)


除非协商了某些扩展，否则实现方绝不能发送本文档中未定义的记录类型。如果 TLS 实现方收到意外的记录类型，它必须使用 "unexpected\_message" alert 消息终止连接。新记录内容类型值由 IANA 在 TLS ContentType 注册表中分配，具体见第 11 节。


## 一. Record Layer

记录层将信息块分段为 TLSPlaintext 记录，TLSPlaintext 中包含 2^14 字节或更少字节块的数据。根据底层 ContentType 的不同，消息边界的处理方式也不同。任何未来的新增的内容类型必须指定适当的规则。请注意，这些规则比 TLS 1.2 中强制执行的规则更加严格。

握手消息可以合并为单个 TLSPlaintext 记录，或者在几个记录中分段，前提是：

- 握手消息不得与其他记录类型交错。也就是说，如果握手消息被分成两个或多个记录，则它们之间不能有任何其他记录。

- 握手消息绝不能跨越密钥更改。实现方必须验证密钥更改之前的所有消息是否与记录边界对齐; 如果没有，那么他们必须用 "unexpected\_message" alert 消息终止连接。因为 ClientHello，EndOfEarlyData，ServerHello，Finished 和 KeyUpdate 消息可以在密钥更改之前立即发生，所以实现方必须将这些消息与记录边界对齐。


实现方绝不能发送握手类型的零长度片段，即使这些片段包含填充。

Alert 消息禁止在记录之间进行分段，并且多条 alert 消息不得合并为单个 TLSPlaintext 记录。换句话说，具有 alert 类型的记录必须只包含一条消息。

应用数据消息包含对 TLS 不透明的数据。应用数据消息始终受到保护。可以发送应用数据的零长度片段，因为它们可能作为流量分析对策使用。应用数据片段可以拆分为多个记录，也可以合并为一个记录。


```c
      enum {
          invalid(0),
          change_cipher_spec(20),
          alert(21),
          handshake(22),
          application_data(23),
          (255)
      } ContentType;

      struct {
          ContentType type;
          ProtocolVersion legacy_record_version;
          uint16 length;
          opaque fragment[TLSPlaintext.length];
      } TLSPlaintext;
```

- type:  
	用于处理封闭片段的更高级协议。

- legacy\_record\_version:  
	对于除初始 ClientHello 之外的 TLS 1.3 实现生成的所有记录(即，在 HelloRetryRequest 之后未生成的记录)，必须将其设置为 0x0303，其中出于兼容性目的，它也可以是0x0301。该字段已弃用，必须忽略它。在某些情况下，以前版本的 TLS 将在此字段中使用其他值。


- length:  
	TLSPlaintext.fragment 的长度(以字节为单位)。长度不得超过 2 ^ 14 字节。接收超过此长度的记录的端点必须使用 "record\_overflow" alert 消息终止连接。


- fragment:  
	正在传输的数据。此字段的值是透明的，它并被视为一个独立的块，由类型字段指定的更高级别协议处理。


本文档描述了使用版本 0x0304 的 TLS 1.3。此版本的值是历史的，源自对 TLS 1.0 使用 0x0301 和对 SSL 3.0 使用 0x0300。为了最大化向后兼容性，包含初始 ClientHello 的记录应该具有版本 0x0301(对应 TLS 1.0)，包含第二个 ClientHello 或 ServerHello 的记录必须具有版本 0x0303(对应 TLS 1.2)。在协商 TLS 的早期版本时，端点需要遵循附录 D 中提供的过程和要求。


当尚未使用记录保护时，TLSPlaintext 结构是直接写入传输线路中的。一旦记录保护开始，TLSPlaintext 记录将受到保护并按照下节部分描述的那样进行发送。请注意，应用数据记录不得写入未受保护的连接中。(有关详细信息，请参阅[第 2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3.md#%E4%BA%94tls-13-%E5%8D%8F%E8%AE%AE%E6%A6%82%E8%A7%88))



## 二. Record Payload Protection

记录保护功能将 TLSPlaintext 结构转换为 TLSCiphertext 结构。去除保护功能和保护功能互为逆过程。在 TLS 1.3 中，与先前版本的 TLS 相反，所有密码都是“具有关联数据的认证加密”(AEAD)[[RFC5116]](https://tools.ietf.org/html/rfc5116)。 AEAD 功能提供统一的加密和认证操作，将明文转换为经过认证的密文，然后再返回。每个加密记录由一个明文标题后跟一个加密的主体组成，该主体本身包含一个类型和可选的填充。


```c
      struct {
          opaque content[TLSPlaintext.length];
          ContentType type;
          uint8 zeros[length_of_padding];
      } TLSInnerPlaintext;

      struct {
          ContentType opaque_type = application_data; /* 23 */
          ProtocolVersion legacy_record_version = 0x0303; /* TLS v1.2 */
          uint16 length;
          opaque encrypted_record[TLSCiphertext.length];
      } TLSCiphertext;
```

- content:  
	TLSPlaintext.fragment 值，包含握手或警报消息的字节编码，或要发送的应用数据的原始字节。
	
- type:  
	TLSPlaintext.type 值，包含记录的内容类型。

- zeros:  
	在类型字段之后的明文中可以出现任意长度的零值字节。只要总数保持在记录大小限制范围内，这个字段为发件人提供了按所选的量去填充任何 TLS 记录的机会。更多详细信息，请参见[[第 5.4 节]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E5%9B%9B-record-padding)

- opaque\_type:  
	TLSCiphertext 记录外部的 opaque\_type 字段始终设置为值23(application\_data)，以便与解析以前版本的 TLS 的中间件向外兼容。解密后，在 TLSInnerPlaintext.type 中找到记录的实际内容类型。


- legacy\_record\_version:  
	legacy\_record\_version 字段始终为 0x0303。TLS 1.3 TLSCiphertexts 在协商 TLS 1.3 之后才生成，因此没有历史兼容性问题可能会收到其他值。请注意，握手协议(包括 ClientHello 和 ServerHello 消息)会对协议版本进行身份验证，因此该值是多余的。

- length:  
	TLSCiphertext.encrypted\_record 的长度(以字节为单位)，它是内容和填充的长度之和，加上内部内容类型的长度加上 AEAD 算法添加的任何扩展。长度不得超过 2 ^ 14 + 256 字节。接收超过此长度的记录的端点必须使用 "record\_overflow" alert 消息终止连接。


- encrypted\_record:  
	AEAD 加密形式的序列化 TLSInnerPlaintext 结构。

AEAD 算法将单个密钥，随机数，明文和要包含在认证检查中的“附加数据”作为输入，如[[RFC5116的第2.1节]](https://tools.ietf.org/html/rfc5116#section-2.1)所述。key 是 client\_write\_key 或 server\_write\_key，nonce 是从序列号和 client\_write\_iv 或 server\_write\_iv 中派生出来的(参见[[第5.3节]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%89-per-record-nonce))，附加数据的输入是记录头，例如：

```c
      additional_data = TLSCiphertext.opaque_type ||
                        TLSCiphertext.legacy_record_version ||
                        TLSCiphertext.length
```

作为输入 AEAD 算法的明文是编码后的 TLSInnerPlaintext 结构。[第7.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%B8%89-traffic-key-calculation)定义了流量密钥的派生。

AEAD 输出包括 AEAD 加密操作的密文输出。由于包含 TLSInnerPlaintext.type 和发送方提供的任何填充，明文的长度大于相应的 TLSPlaintext.length。AEAD 输出的长度通常大于明文，但是其中一部分也会随着 AEAD 算法的变化而变化。

由于密码可能包含填充，因此开销量可能随着明文的不同长度而变化。

```c
      AEADEncrypted =
          AEAD-Encrypt(write_key, nonce, additional_data, plaintext)
```

TLSCiphertext 的 encrypted\_record 字段设置为 AEADEncrypted。

为了解密和验证，密码会把密钥，随机数，附加数据和 AEADEncrypted 值作为输入。输出的是明文或表示解密失败的错误。这里没有单独的完整性检查。

```c
      plaintext of encrypted_record =
          AEAD-Decrypt(peer_write_key, nonce,
                       additional_data, AEADEncrypted)
```

如果解密失败，接收方必须使用 "bad\_record\_mac" alert 消息终止连接。

TLS 1.3 中使用的 AEAD 算法不得产生大于 255 个八位字节的扩展。从对端的 TLSCiphertext.length 接收记录，如果 TLSCiphertext.length 大于 2 ^ 14 + 256 个八位字节，则必须用 "record\_overflow" 消息终止连接。这个限制源自于：TLSInnerPlaintext 长度的最大值是 2 ^ 14 个八位字节 + 1 个八字节的 ContentType + 255 个八位字节的最大 AEAD 扩展。


## 三. Per-Record Nonce

分别维护 64 位序列号以读取和写入记录。在读取或写入每个记录之后，适当的序列号加 1。每个序列号在连接开始时和每次更改密钥时都设置为零; 在特定流量密钥下传输的第一条记录必须使用序列号 0。

因为序列号的大小是 64 位，所以它们不应该 wrap。如果 TLS 实现方需要 wrap 序列号，它必须重新生成密钥([第4.6.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update))或终止连接。


每个 AEAD 算法将为 per-record 的随机数指定一系列可能的长度，从 N\_MIN 字节到输入的 N\_MAX 字节[[RFC5116]](https://tools.ietf.org/html/rfc5116)。 对于 AEAD 算法，TLS 的 per-record 随机数(iv\_length)的长度设置为 8 字节和 N\_MIN 中的较大者(参见[[RFC5116]](https://tools.ietf.org/html/rfc5116#section-4)，第4节)。 其中 N\_MAX 小于 8 个字节的 AEAD 算法不得与 TLS 一起使用。AEAD 结构的 per-record 随机数形成如下:


1. 64 位的记录序列号是按网络字节顺序编码，并在左边用零填充到 iv\_length。
2. 填充的序列号要和 client\_write\_iv 或者 server\_write\_iv 进行异或(取决于角色)

得到的值(长度为 iv\_length)被用作 per-record 的随机数。

注意：这与 TLS 1.2 中的结构不同了，TLS 1.2 指定了部分显式的随机数。


## 四. Record Padding

所有加密的 TLS 记录都可以被填充，从而扩大 TLSCiphertext 的大小。这种做法允许发送者隐藏来自观察者的流量大小。

生成 TLSCiphertext 记录时，实现方可以选择填充。未填充的记录只是填充长度为零的记录。填充是在加密之前附加到 ContentType 字段的一串零值字节。实现方必须在加密之前将填充的八位字节全部设置为零。


如果发送者需要，应用数据记录可以包含零长度 TLSInnerPlaintext.content。 这允许在对 activity 存在或者不存在敏感的情况下，产生合理大小的覆盖流量。实现方绝不能发送具有零长度 TLSInnerPlaintext.content 的握手和 alert 记录; 如果收到这样的消息，接收实现方必须用 "unexpected\_message" alert 消息终止连接。


发送的填充由记录保护机制自动验证;在成功解密 TLSCiphertext.encrypted\_record后，接收实现方从末端向前开始扫描字段，直到找到非零八位字节。该非零八位字节是消息的内容类型 type 字段。选择此填充方案是因为它允许以任意大小(从零到 TLS 记录大小限制)填充任何加密的 TLS 记录，而不引入新的内容类型。该设计还强制执行全零填充八位字节，以便快速检测填充错误。

实现方必须将扫描范围限制为只扫描从 AEAD 解密返回的明文。如果接收实现方在明文中没有找到非零八位字节，它必须以 "unexpected\_message" alert 消息终止连接。

填充并不会改变整体记录大小限制：完整编码的 TLSInnerPlaintext 不得超过 2 ^ 14 + 1 个八位字节。如果最大片段长度减少 - 例如，来自 [[RFC8449]](https://tools.ietf.org/html/rfc8449) 的 record\_size\_limit 扩展 - 那么减少的限制适用于完整的纯文本，包括内容类型和填充。



选择一个合理的填充策略，比如何时填充，填充多少，这是一个复杂的主题，超出了本规范的范围。如果 TLS 之上的应用层协议具有自己的填充，则最好在应用层内填充应用数据 TLS 记录。但是，加密握手或 alert 记录的填充仍必须在 TLS 层处理。稍后的文档可以定义填充选择算法或通过 TLS 扩展或一些其他手段定义填充策略的请求机制。


## 五. Limits on Key Usage

明文数量存在一些加密限制，这些限制可以在给定的一组密钥下安全加密。[[AEAD-LIMITS]](https://tools.ietf.org/html/rfc8446#ref-AEAD-LIMITS) 在假设基础原语(AES 或 ChaCha20)没有弱点的情况下提供了对这些限制的分析。在达到这些限制之前，实现方应该按照[第 4.6.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update)中的描述进行密钥更新。

对于 AES-GCM，在给定连接上可以加密多达 2 ^ 24.5 个全尺寸记录(大约 2400 万个)，同时为认证加密(AE)安全性保持大约 2 ^ -57 的安全余量。对于 ChaCha20 / Poly1305，记录序列号将在达到安全限制之前就会 wrap。



------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Record\_Protocol/](https://halfrost.com/tls_1-3_record_protocol/)