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


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()