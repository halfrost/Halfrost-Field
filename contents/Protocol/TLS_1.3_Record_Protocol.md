# TLS 1.3 Record Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/109_0.png'>
</p>


TLS 记录协议接收要传输的消息，将数据分段为可管理的块，保护记录并传输结果。收到的数据经过验证，解密，重新组装，然后交付给更上层的协议。


TLS 记录允许同一层记录层上复用多个更高层的协议。本文档指定了 4 种内容类型：handshake，application\_data，alert 和 change\_cipher\_spec。change\_cipher\_spec 记录仅用于兼容性目的。


实现方可能会在发送或接收第一个 ClientHello 消息之后，和，在接收到对等方的  Finished 消息之前的任何时间接收由单字节值 0x01 组成的未加密的类型 change\_cipher\_spec 的记录，如果接收到了这种记录，则必须简单地丢弃它而不进行进一步处理。请注意，此记录可能出现在握手中，这时候实现方是期望保护记录的，因此有必要在尝试对记录进行去除保护之前检测此情况。接收到任何其他 change\_cipher\_spec 值或接收到受保护的 change\_cipher\_spec 记录的实现方必须使用 "unexpected\_message" alert 消息中止握手。如果实现方检测到在第一个 ClientHello 消息之前或在对等方的 Finished 消息之后收到的 change\_cipher\_spec 记录，则必须将其视为意外记录类型(尽管无状态的 Server 可能无法将这些情况与允许的情况区分开)


除非协商了某些扩展，否则实现放绝不能发送本文档中未定义的记录类型。 如果TLS实现收到意外的记录类型，它必须使用“unexpected_message”警报终止连接。 新记录内容类型值由IANA在TLS ContentType注册表中分配，如第11节中所述




























------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()