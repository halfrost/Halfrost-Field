# TLS 1.3 Compliance Requirements


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/113_0.png'>
</p>

## I. Mandatory-to-Implement Cipher Suites

TLS 1.3 has several cipher suites that are mandatory to implement.

> In the descriptions below, “must” means MUST, and “should” means SHOULD. Please pay attention to the wording.

Unless an application profile standard specifies otherwise, the following requirements apply:

TLS-compliant applications must implement the TLS\_AES\_128\_GCM\_SHA256 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) cipher suite, and should implement the TLS\_AES\_256\_GCM\_SHA384 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) and TLS\_CHACHA20\_POLY1305\_SHA256 [[RFC8439]](https://tools.ietf.org/html/rfc8439) cipher suites (see [Appendix B.4](https://tools.ietf.org/html/rfc8446#appendix-B.4)).

TLS-compliant applications must support the digital signature algorithms rsa\_pkcs1\_sha256 (for certificates), rsa\_pss\_rsae\_sha256 (for CertificateVerify and certificates), and ecdsa\_secp256r1\_sha256. A TLS-compliant application must support key exchange with secp256r1 (NIST P-256) and should support key exchange with X25519 [[RFC7748]](https://tools.ietf.org/html/rfc7748).


## II. Mandatory-to-Implement Extensions

TLS 1.3 has several extensions that are mandatory to implement.

Unless otherwise specified by an application profile standard, TLS-compliant applications must implement the following TLS extensions:

- Supported Versions ("supported\_versions"; [Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions))

- Cookie ("cookie";[Section 4.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-cookie))

- Signature Algorithms ("signature\_algorithms"; [Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms))

- Signature Algorithms Certificate ("signature\_algorithms\_cert"; [Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms))

- Supported Groups ("supported\_groups"; [Section 4.2.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups))

- Key Share ("key\_share"; [Section 4.2.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share))

- Server Name Indication ("server\_name"; [Section 3 of [RFC6066]](https://tools.ietf.org/html/rfc6066#section-3))

All implementations must send and use these extensions during negotiation:

- All ClientHello, ServerHello, and HelloRetryRequest messages require "supported\_versions".

- Certificate authentication requires "signature\_algorithms".

- For ClientHello messages using DHE or ECDHE key exchange, "supported\_groups" is required.

- DHE or ECDHE key exchange requires "key\_share".

- The PSK key agreement protocol requires "pre\_shared\_key".

- For the PSK key agreement protocol, "psk\_key\_exchange\_modes" is required.

If a ClientHello contains a "supported\_versions" extension whose body includes 0x0304, the client is considered to be attempting negotiation using this specification. Such a ClientHello message must satisfy the following requirements:

- If it does not contain the "pre\_shared\_key" extension, it must contain both the "signature\_algorithms" extension and the "supported\_groups" extension.

- If it contains the "supported\_groups" extension, it must also contain the "key\_share" extension, and vice versa. An empty KeyShare.client\_shares vector is allowed.

If a server receives a ClientHello message that does not satisfy these requirements, it must immediately abort the handshake with a "missing\_extension" alert message.

In addition, all implementations must support use of the "server\_name" extension by applications capable of using it. A server may require the client to send a valid "server\_name" extension. A server that requires this extension should respond to a ClientHello that lacks the "server\_name" extension by terminating the connection with a "missing\_extension" alert message.

## III. Protocol Invariants

This section describes the invariants that TLS endpoints and middleboxes must follow. It also applies to earlier versions of TLS.


TLS is designed to be secure and extensible in a compatible way. When communicating with newer peers, newer clients or servers should negotiate the most preferred common parameters. The TLS handshake provides downgrade protection: middleboxes that pass traffic between a newer client and a newer server without terminating TLS cannot influence the handshake (see Appendix E.1). At the same time, deployed protocols should be able to evolve at different rates, so newer clients or servers can continue to support older parameters, allowing interoperability with older endpoints (backward compatibility).


To achieve this, implementations must correctly handle extensible fields:

- A client that sends a ClientHello must support all parameters it advertises. Otherwise, the server may be unable to interoperate by selecting one of those parameters.

- A server that receives a ClientHello must correctly ignore all unrecognized cipher suites, extensions, and other parameters. Otherwise, it may be unable to interoperate with newer clients. In TLS 1.3, a client that receives a CertificateRequest or NewSessionTicket must also ignore all unrecognized extensions.

- A middlebox that terminates a TLS connection must behave as a compliant TLS server (to the original client), including having a certificate that the client is willing to accept; it must also behave as a compliant TLS client (to the original server), including validating the original server’s certificate. In particular, it must generate its own ClientHello containing only parameters it understands, and it must generate a new ServerHello random value rather than forwarding the endpoint’s value.

Note that TLS protocol requirements and security analyses apply only to the two separate connections. How to deploy a TLS terminator securely requires additional security considerations, which are outside the scope of this document.

- If a middlebox forwards ClientHello parameters that it does not understand, it is not allowed to process any messages other than the ClientHello. It must forward all subsequent traffic unmodified. Otherwise, it may be unable to interoperate with newer clients and servers.

Forwarded ClientHellos may contain features that the middlebox does not support, so the response may include future TLS features that the middlebox does not recognize. These newly added features may change any message other than the ClientHello. In particular, values sent in the ServerHello may change, the ServerHello format may change, and the TLSCiphertext format may change.


The design of TLS 1.3 was constrained by widely deployed middleboxes that do not comply with the TLS specification (see Appendix D.4); however, it does not relax the invariants. These middleboxes remain non-compliant.


------------------------------------------------------

Reference:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Compliance\_Requirements/](https://halfrost.com/tls_1-3_compliance_requirements/)