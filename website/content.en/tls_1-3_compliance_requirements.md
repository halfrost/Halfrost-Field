+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-11-25T00:49:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/113_0.png"
slug = "tls_1-3_compliance_requirements"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 Compliance Requirements"

+++


## I. Mandatory-to-Implement Cipher Suites

Some cipher suites are mandatory to implement in TLS 1.3.

> In the descriptions below, “must” means MUST, and “should” means SHOULD. Readers should pay attention to the wording.

Unless otherwise specified by an application profile standard, the following requirements apply:

TLS-compliant applications must implement the TLS\_AES\_128\_GCM\_SHA256 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) cipher suite, and should implement the TLS\_AES\_256\_GCM\_SHA384 [[GCM]](https://tools.ietf.org/html/rfc8446#ref-GCM) and TLS\_CHACHA20\_POLY1305\_SHA256 [[RFC8439]](https://tools.ietf.org/html/rfc8439) cipher suites (see [Appendix B.4](https://tools.ietf.org/html/rfc8446#appendix-B.4)).

TLS-compliant applications must support the digital signature schemes rsa\_pkcs1\_sha256 (for certificates), rsa\_pss\_rsae\_sha256 (for CertificateVerify and certificates), and ecdsa\_secp256r1\_sha256. A TLS-compliant application must support key exchange with secp256r1 (NIST P-256) and should support key exchange with X25519 [[RFC7748]](https://tools.ietf.org/html/rfc7748).


## II. Mandatory-to-Implement Extensions

Some extensions are mandatory to implement in TLS 1.3.

Unless otherwise specified by an application profile standard, TLS-compliant applications must implement the following TLS extensions:

- Supported Versions（"supported\_versions"; [Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions)）

- Cookie（"cookie";[Section 4.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-cookie)）

- Signature Algorithms（"signature\_algorithms"; [Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms)）

- Signature Algorithms for Certificates("signature\_algorithms\_cert"; [Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms))

- Supported Groups（"supported\_groups"; [Section 4.2.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups)）

- Key Share（"key\_share"; [Section 4.2.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)）

- Server Name Indication（"server\_name"; [Section 3 of [RFC6066]](https://tools.ietf.org/html/rfc6066#section-3)）

All implementations must send and use these extensions during negotiation:

- All ClientHello, ServerHello, and HelloRetryRequest messages require "supported\_versions".

- Certificate-based authentication requires "signature\_algorithms".

- For ClientHello messages using DHE or ECDHE key exchange, "supported\_groups" is required.

- DHE or ECDHE key exchange requires "key\_share".

- The PSK key agreement protocol requires "pre\_shared\_key".

- For the PSK key agreement protocol, "psk\_key\_exchange\_modes" is required.

If a ClientHello contains a "supported\_versions" extension whose body contains 0x0304, the client is considered to be attempting to negotiate using this specification. Such a ClientHello message must satisfy the following requirements:

- If it does not contain a "pre\_shared\_key" extension, it must contain both the "signature\_algorithms" extension and the "supported\_groups" extension.

- If it contains the "supported\_groups" extension, it must also contain the "key\_share" extension, and vice versa. An empty KeyShare.client\_shares vector is allowed.

If a Server receives a ClientHello message that does not satisfy the above requirements, it must immediately abort the handshake with a "missing\_extension" alert message.

In addition, all implementations must support the "server\_name" extension when it is used by applications that can use it. A Server may require the Client to send a valid "server\_name" extension. A Server that requires this extension should respond to a ClientHello that lacks the "server\_name" extension by terminating the connection with a "missing\_extension" alert message.

## III. Protocol Invariants

This section describes the invariants that TLS endpoints and middleboxes must follow. It also applies to earlier versions of TLS.


TLS is designed to be secure and compatibly extensible. When communicating with newer peers, newer Clients or Servers should negotiate the most preferred common parameters. The TLS handshake provides downgrade protection: a middlebox that forwards traffic between a newer Client and a newer Server without terminating TLS cannot influence the handshake (see Appendix E.1). At the same time, deployed protocols should be upgradable at different rates, so newer Clients or Servers can continue to support older parameters, allowing them to interoperate with older endpoints (backward compatibility).


To that end, implementations must correctly handle extensible fields:

- A Client that sends a ClientHello must support all parameters advertised in it. Otherwise, the Server might fail to interoperate by selecting one of those parameters.

- A Server that receives a ClientHello must correctly ignore all unrecognized cipher suites, extensions, and other parameters. Otherwise, it might fail to interoperate with newer Clients. In TLS 1.3, a Client that receives a CertificateRequest or NewSessionTicket must also ignore all unrecognized extensions.

- A middlebox that terminates a TLS connection must behave as a compliant TLS Server (to the original Client), including having a certificate that the Client is willing to accept, and as a compliant TLS Client (to the original Server), including validating the original Server’s certificate. In particular, it must generate its own ClientHello containing only parameters it understands, and it must generate a new ServerHello random value rather than forwarding the endpoint’s value.

Note that the protocol requirements and security analysis for TLS apply only to two separate connections. How to securely deploy a TLS terminator requires additional security considerations, which are outside the scope of this document.

- If a middlebox forwards ClientHello parameters that it does not understand, it is not permitted to process any messages beyond the ClientHello. It must forward all subsequent traffic unmodified. Otherwise, it might fail to interoperate with newer Clients and Servers.

Forwarded ClientHellos may contain features that the middlebox does not support, and therefore the response may include future TLS features that the middlebox cannot recognize. These new features may change any message other than ClientHello. In particular, values sent in ServerHello may change, the ServerHello format may change, and the TLSCiphertext format may also change.


The design of TLS 1.3 was constrained by widely deployed middleboxes that do not comply with the TLS specification (see Appendix D.4); however, it does not relax the invariants. These middleboxes remain non-compliant.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Compliance\_Requirements/](https://halfrost.com/tls_1-3_compliance_requirements/)