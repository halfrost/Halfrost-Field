# TLS 1.3 Alert Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/110_0.png'>
</p>


TLS 提供 alert 内容类型用来表示关闭信息和错误。与其他消息一样，alert 消息也会根据当前连接状态的进行加密。

Alert 消息传达警报的描述以及在先前版本的 TLS 中传达消息严重性级别的遗留字段。警报分为两类：关闭警报和错误警报。在 TLS 1.3 中，错误的严重性隐含在正在发送的警报类型中，并且可以安全地忽略 "level" 字段。"close\_notify" alert 用于表示连接从一个方向开始有序的关闭。收到这样的警报后，TLS 实现方应该表明应用程序的数据结束。

错误警报表示关闭连接中断(参见[第6.2节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Alert_Protocol.md#%E4%BA%8C-error-alerts))。收到错误警报后，TLS 实现方应该向应用程序表示出现了错误，并且不允许在连接上发送或接收任何其他数据。Server 和 Client 必须忘记在失败的连接中建立的秘密值和密钥，但是与会话 ticket 关联的 PSK 除外，如果可能，应该丢弃它们。

第 6.2 节中列出的所有警报必须与 AlertLevel = fatal 一起发送，并且在收到时必须将其视为错误警报，而不管消息中的 AlertLevel 如何。未知的警报类型必须都应该被视为错误警报。

注意：TLS 定义了两个通用警报(请参阅[第6节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Alert_Protocol.md#tls-13-alert-protocol))，以便在解析消息失败时使用。对端接收到了语法无法解析的消息(例如，消息具有超出消息边界的长度或包含超出范围的长度)必须以 "decode\_error" 警报终止连接。对端接收到了语法正确，但是语义无效的消息(例如，p-1 的 DHE 共享或无效的枚举)必须使用 "illegal\_parameter" 警报终止连接。


```c
      enum { warning(1), fatal(2), (255) } AlertLevel;

      enum {
          close_notify(0),
          unexpected_message(10),
          bad_record_mac(20),
          record_overflow(22),
          handshake_failure(40),
          bad_certificate(42),
          unsupported_certificate(43),
          certificate_revoked(44),
          certificate_expired(45),
          certificate_unknown(46),
          illegal_parameter(47),
          unknown_ca(48),
          access_denied(49),
          decode_error(50),
          decrypt_error(51),
          protocol_version(70),
          insufficient_security(71),
          internal_error(80),
          inappropriate_fallback(86),
          user_canceled(90),
          missing_extension(109),
          unsupported_extension(110),
          unrecognized_name(112),
          bad_certificate_status_response(113),
          unknown_psk_identity(115),
          certificate_required(116),
          no_application_protocol(120),
          (255)
      } AlertDescription;

      struct {
          AlertLevel level;
          AlertDescription description;
      } Alert;
```

## 一. Closure Alerts

Client 和 Server 必须共享连接结束的状态，以避免截断攻击。


- close\_notify:
	此 alert 通知接收者，发送消息者不会在此连接上再发送消息了。收到关闭警报后收到的任何数据都必须被忽略。

- user\_canceled:
	此警报通知接收者，发送者由于与协议故障无关的某些原因而取消握手。如果用户在握手完成后取消操作，则通过发送 "close\_notify" 来关闭连接更为合适。这个警告跟在  "close\_notify" 后面。此警报通常具有 AlertLevel = warning。


任何一方都可以通过发送 "close\_notify" 警报来发起其连接写入端的关闭。收到关闭警报后收到的任何数据都必须被忽略。如果在 "close\_notify" 之前收到传输级别的关闭，则接收方无法知道，已收到了所有已发送的数据。


每一方必须在关闭连接的写入端之前发送 "close\_notify" 警报，除非它已经发送了一些错误警告。这对连接的读取端没有任何影响。请注意，这是对 TLS 1.3 之前版本的 TLS 的更改，其中实现方需要通过丢弃挂起的写入并立即发送它们自己 "close\_notify" 警报来对 "close\_notify" 作出反应。之前的要求可能会导致读取端的截断。在关闭连接的读取端之前，双方都不必等待接收 "close\_notify" 警报，但这样做会引入截断的可能性。


如果使用 TLS 的应用程序协议规定在 TLS 连接关闭后可以通过底层传输任何数据，则 TLS 实现方必须在指示应用程序层的数据结束之前收到 "close\_notify" 警报。不应采用此标准的任何部分来规定 TLS 的使用配置文件管理其数据传输的方式，包括何时打开或关闭连接。

注意：假设在销毁传输之前，关闭连接的写入端后仍可以可靠地发送未定的数据。



## 二. Error Alerts

TLS 中的错误处理非常简单。当检测到错误时，检测的这一方，向其对等方发送消息。在传输或收到致命警报消息时，双方必须立即关闭连接。

每当实现方遇到致命错误情况时，它应该发送适当的致命警报并且必须关闭连接，而不发送或接收任何其他数据。在本规范的其余部分中，当使用短语“终止连接”和“中止握手”而没有特定警报时，这意味着实现方应该发送由以下描述指示的警报。短语“使用 X 警报终止连接”和“使用 X 警报中止握手”意味着如果发送任何警报，则实现方必须发送警报 X。从 TLS 1.3 开始，本节下面定义的所有警报以及所有未知警报都被认为是致命的(参见[第6节](hhttps://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Alert_Protocol.md#tls-13-alert-protocol))。实现方应该提供一种方便日志记录发送和接收警报的方法。


定义以下错误警报：

1. unexpected\_message:  
	收到了不适当的消息(例如，错误的握手消息，过早的应用数据等)。在正确的实现之间的通信中绝不应该出现这个警报。

2. bad\_record\_mac:  
	如果收到无法去除保护的记录，则返回此警报。由于 AEAD 算法结合了解密和验证，并且还避免了侧信道攻击，因此该警报用于所有去保护失败的情况。除非消息在网络中被破坏，否则在正确实现之间的通信中永远不应该出现这个警报。

3. record\_overflow:  
	收到长度超过 2 ^ 14 + 256 字节的 TLSCiphertext 记录，或者解密为超过 2 ^ 14字节(或其他一些协商限制)的 TLSPlaintext 记录的记录。除非消息在网络中被破坏，否则在正确实现之间的通信中永远不应该出现这个警报。

4. handshake\_failure:  
	收到 "handshake\_failure" 警报消息表示发送方无法在可用选项的情况下协商一组可接受的安全参数。

5. bad\_certificate:  
	证书已损坏，包括未正确验证的签名等。

6. unsupported\_certificate:  
	不支持的证书的类型。

7. certificate\_revoked:  
	证书已经被其签名者撤销。
	
8. certificate\_expired:  
	证书已过期或当前无效。

9. certificate\_unknown:  
	处理证书时出现了一些其他(未指定的)问题，使其无法接受。

10. illegal\_parameter:  
	握手中的字段不正确或与其他字段不一致。此警报用于符合正式协议语法但在其他方面不正确的错误。

11. unknown\_ca:  
	收到了有效的证书链或部分链，但证书没有被接收，因为无法找到 CA 证书或无法与已知的信任锚匹配。

12. access\_denied:  
	收到了有效的证书或 PSK，但是当应用访问控制时，发送者却决定不继续协商了。

13. decode\_error:  
	无法解码消息，因为某些字段超出指定范围或消息长度不正确。此警报用于消息不符合正式协议语法的错误。除非消息在网络中被破坏，否则在正确实现之间的通信中永远不应该出现这个警报。

14. decrypt\_error:  
	握手(而不是记录层)加密操作失败，包括无法正确验证签名或验证 Finished 消息或 PSK binder。

15. protocol\_version：  
	对等方尝试协商的协议版本已被识别但不受支持(参见附录D)。

16. insufficient\_security:  
	当协商失败时返回 "insufficient\_security" 而不是 "handshake\_failure"，因为 Server 需要的参数比 Client 支持的参数更安全。

17. internal\_error:  
	与对等方无关的内部错误或与协议的正确性无关的内部错误(例如内存分配失败)使得连接无法继续下去。

18. applicable\_fallback:  
	由 Server 发送的，用来以响应来自 Client 无效连接的重试(参见[[RFC7507]](https://tools.ietf.org/html/rfc7507))。

19. missing\_extension:  
	由接收握手消息的端点发送，该握手消息不包含必须为提供的 TLS 版本发送的扩展，或不包含其他协商参数发送的扩展。

20. unsupported\_extension:  
	由接收任何握手消息的端点发送，该消息中包含了，已知禁止包含在给定握手消息中的扩展，或包含了 ServerHello 或者 Certificate 中的一些扩展，但是没有先在相应 ClientHello 或 CertificateRequest 中提供。

21. unrecognized\_name:  
	当 Client 通过 "server\_name" 扩展名提供的名称没有与之对应标识的 Server 的时候，由 Server 发送 "unrecognized\_name" alert 消息(请参阅[[RFC6066]](https://tools.ietf.org/html/rfc6066))。

22. bad\_certificate\_status\_response:  
	当 Server 通过 "status\_request" 扩展提供无效或不可接受的 OCSP 响应的时候，由 Client 发送 "bad\_certificate\_status\_response"(参见[[RFC6066]](https://tools.ietf.org/html/rfc6066))。

23. unknown\_psk\_identity:  
	当需要 PSK 密钥建立，但 Client 不能提供可接受的 PSK 标识的时候，由 Server 发送 "unknown\_psk\_identity"。发送此警报是可选的;Server 可以选择发送 "decrypt\_error" 警报，仅指示无效的 PSK 身份。

24. certificate\_required:  
	当需要 Client 证书但 Client 未提供任何证书的时候，由 Server 发送 "certificate\_required"。

25. no\_application\_protocol:  
	当 Client 的 "application\_layer\_protocol\_negotiation" 扩展中的协议，Server 也不支持的时候，由 Server 发送 "no\_application\_protocol"(请参阅[[RFC7301]](https://tools.ietf.org/html/rfc7301))。

新警报值由 IANA 分配，如[第 11 节](https://tools.ietf.org/html/rfc8446#section-11)所述。



------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Alert\_Protocol/](https://halfrost.com/tls_1-3_alert_protocol/)