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

应用程序数据消息包含对 TLS 不透明的数据。应用程序数据消息始终受到保护。可以发送应用程序数据的零长度片段，因为它们可能作为流量分析对策使用。应用程序数据片段可以拆分为多个记录，也可以合并为一个记录。


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


当尚未使用记录保护时，TLSPlaintext 结构是直接写入线路中的。一旦记录保护开始，TLSPlaintext 记录将受到保护并按照下节部分描述的那样进行发送。请注意，应用程序数据记录不得写入未受保护的连接中。(有关详细信息，请参阅[第2节](https://tools.ietf.org/html/rfc8446#section-2))



## 二. Record Payload Protection










------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()