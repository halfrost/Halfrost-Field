+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-12-09T01:02:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/115_0.png"
slug = "tls_1-3_backward_compatibility"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 Backward Compatibility"

+++


The TLS protocol provides a built-in mechanism for version negotiation between endpoints, making it possible to support different versions of TLS.

TLS 1.x and SSL 3.0 use compatible ClientHello messages. As long as the ClientHello message format remains compatible and the Client and Server have at least one protocol version in common, the Server can attempt to respond to the Client using a future version of TLS.

Earlier versions of TLS used the record-layer version numbers (TLSPlaintext.legacy\_record\_version and TLSCiphertext.legacy\_record\_version) for various purposes. Starting with TLS 1.3, this field is deprecated. All implementations must ignore the value of TLSPlaintext.legacy\_record\_version. The value of TLSCiphertext.legacy\_record\_version is included in the unprotected additional data, but it may be ignored or verified against a fixed constant value. Version negotiation must be performed only using the handshake versions (ClientHello.legacy\_version and ServerHello.legacy\_version, as well as the "supported\_versions" extension in ClientHello, HelloRetryRequest, and ServerHello). To maximize interoperability with legacy endpoints, implementations negotiating TLS 1.0-1.2 should set the record-layer version number to the negotiated version for ServerHello and all subsequent records.


To maximize compatibility with previous non-standard behavior and misconfigured deployments, all implementations should support the method of validating certificates based on the expectations in this document, even when processing handshakes for earlier TLS versions (see [Section 4.4.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-server-certificate-selection)).

TLS 1.2 and earlier support the "Extended Master Secret" [RFC7627](https://tools.ietf.org/html/rfc7627) extension, which digests most of the handshake transcript into the master secret. Because TLS 1.3 always computes the hash from the start of the transcript through the Server Finished, implementations that support both TLS 1.3 and earlier versions should indicate the use of the Extended Master Secret extension in their APIs, regardless of whether TLS 1.3 is used.

## I. Negotiating with an Older Server

A TLS 1.3 Client that wants to negotiate with a Server that does not support TLS 1.3 will send a normal TLS 1.3 ClientHello containing 0x0303 (TLS 1.2) in ClientHello.legacy\_version, while using the correct versions in the "supported\_versions" extension. If the Server does not support TLS 1.3, it will respond with a ServerHello containing an older version number. If the Client agrees to use this version, negotiation proceeds according to the negotiated protocol. A Client resuming a session using a ticket should initiate the connection using the previously negotiated version.

Note that 0-RTT data is incompatible with older Servers and should not be sent unless the Server is known to support TLS 1.3. See [Appendix D.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%B8%89-0-rtt-backward-compatibility).

If the Client does not support the version selected by the Server (or finds it unacceptable), the Client must abort the handshake with a "protocol\_version" alert.

Some legacy Server implementations are known not to implement the TLS specification correctly and may abort the connection when they encounter a version or TLS extension they do not recognize. Interoperability with broken Servers is a complex topic outside the scope of this document. Multiple connection attempts may be required to negotiate a backward-compatible connection; however, this practice is vulnerable to downgrade attacks and is not recommended.

## II. Negotiating with an Older Client

A TLS Server may receive a ClientHello indicating a version number lower than the highest version it supports. If the "supported\_versions" extension is present, the Server must negotiate using that extension, as described in [Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions). If the "supported\_versions" extension is absent, the Server must negotiate the minimum of ClientHello.legacy\_version and TLS 1.2. For example, if the Server supports TLS 1.0, 1.1, and 1.2, and legacy\_version is TLS 1.0, the Server will use TLS 1.0 for ServerHello. If the "supported\_versions" extension is absent and the Server supports only versions greater than ClientHello.legacy\_version, the Server must abort the handshake with a "protocol\_version" alert.


Note that earlier versions of TLS did not explicitly specify the record-layer version number value (TLSPlaintext.legacy\_record\_version) in all cases. The Server will receive various TLS 1.x versions in this field, but must always ignore its value.


## III. 0-RTT Backward Compatibility

0-RTT data is incompatible with older Servers. An older Server will respond to the ClientHello with an older ServerHello, but it will not correctly skip the 0-RTT data and will be unable to complete the handshake. This can cause problems when the Client attempts to use 0-RTT, especially in multi-Server deployments. For example, a deployment may roll out TLS 1.3 gradually, with some Servers implementing TLS 1.3 and others implementing TLS 1.2, or a TLS 1.3 deployment may be downgraded to TLS 1.2.

A Client that attempts to send 0-RTT data must cause the connection to fail if it receives a TLS 1.2 or earlier ServerHello. It may then retry the connection with 0-RTT disabled. To avoid downgrade attacks, the Client should not disable TLS 1.3; it should disable only 0-RTT.

To avoid this failure mode, multi-Server deployments should ensure that TLS 1.3 is deployed uniformly and stably without 0-RTT before enabling 0-RTT.

## IV. Middlebox Compatibility Mode

Field testing [Ben17a](https://tools.ietf.org/html/rfc8446#ref-Ben17a) [Ben17b](https://tools.ietf.org/html/rfc8446#ref-Ben17b) [Res17a](https://tools.ietf.org/html/rfc8446#ref-Res17a) [Res17b](https://tools.ietf.org/html/rfc8446#ref-Res17b) found that many middleboxes behaved incorrectly when TLS client/server pairs negotiated TLS 1.3. Implementations increase the chances of successfully establishing connections through these middleboxes by making the TLS 1.3 handshake look more like a TLS 1.2 handshake.


- The Client always provides a non-empty session ID in ClientHello, as described in the legacy\_session\_id portion of [Section 4.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello).

- If early data is not provided, the Client sends a dummy change\_cipher\_spec record immediately before sending its second flight of data (see the third paragraph of Section 5). This may be before its second ClientHello or before its encrypted handshake data is sent. If early data is provided, the record is placed immediately after the first ClientHello.

- The Server sends a dummy change\_cipher\_spec record immediately after its first handshake message. This may be after ServerHello or HelloRetryRequest.

Taken together, these changes make the TLS 1.3 handshake resemble TLS 1.2 session resumption, which improves the likelihood of successfully establishing connections through middleboxes. This "compatibility mode" is partially negotiated: the Client
 may choose whether to provide a session ID, and the Server must echo it. Either side may send change\_cipher\_spec at any time during the handshake, because these messages must be ignored by the peer; however, once the Client has sent a non-empty session ID, the Server must send change\_cipher\_spec as described in this appendix.


## V. Security Restrictions Related to Backward Compatibility


Implementations negotiating older versions of TLS should prefer forward-secret and AEAD cipher suites, if available.

For the reasons cited in [RFC7465](https://tools.ietf.org/html/rfc7465), RC4 cipher suites are now considered insecure. Implementations must never offer or negotiate RC4 cipher suites for any version of TLS for any reason.

Older versions of TLS allowed the use of extremely low-strength ciphers. Ciphers with strength below 112 bits must no longer be offered or negotiated for any version of TLS for any reason.

For the reasons listed in [RFC7568](https://tools.ietf.org/html/rfc7568), SSL 3.0 [RFC6101](https://tools.ietf.org/html/rfc6101) is now considered insecure and therefore must not be negotiated for any reason.

For the reasons listed in [RFC6176](https://tools.ietf.org/html/rfc6176), SSL 2.0 [SSL2](https://tools.ietf.org/html/rfc8446#ref-SSL2) is now considered insecure and therefore must not be negotiated for any reason.

Implementations must never send an SSL 2.0-compatible CLIENT-HELLO. Implementations must not use an SSL 2.0-compatible CLIENT-HELLO to negotiate TLS 1.3 or later. Implementations are not recommended to accept an SSL 2.0-compatible CLIENT-HELLO to negotiate older versions of TLS.

Implementations must never set ClientHello.legacy\_version or ServerHello.legacy\_version to 0x0300 or lower. Any endpoint that receives a Hello message with ClientHello.legacy\_version or ServerHello.legacy\_version set to 0x0300 must abort the handshake with a "protocol\_version" alert.
Implementations MUST NOT send any record with a version lower than 0x0300. Implementations SHOULD NOT accept any record with a version lower than 0x0300 (though they may inadvertently do so if they completely ignore the record version number).

Implementations MUST NOT use the Truncated HMAC extension defined in [Section 7 of RFC6066](https://tools.ietf.org/html/rfc6066#section-7), because it is not applicable to AEAD algorithms and has been shown to be insecure in certain cases.


------------------------------------------------------

References：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Backward\_Compatibility/](https://halfrost.com/tls_1-3_backward_compatibility/)