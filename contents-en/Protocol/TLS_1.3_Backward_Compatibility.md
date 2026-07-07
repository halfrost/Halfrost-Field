# TLS 1.3 Backward Compatibility


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/115_0.png'>
</p>


The TLS protocol provides a built-in mechanism for version negotiation between endpoints, making it possible to support different versions of TLS.

TLS 1.x and SSL 3.0 use compatible ClientHello messages. As long as the ClientHello message format remains compatible and the Client and Server have at least one mutually supported protocol version, the Server can attempt to respond to the Client using a future version of TLS.

Earlier versions of TLS used the record-layer version number (TLSPlaintext.legacy\_record\_version and TLSCiphertext.legacy\_record\_version) for various purposes. Starting with TLS 1.3, this field is deprecated. All implementations must ignore the value of TLSPlaintext.legacy\_record\_version. The value of TLSCiphertext.legacy\_record\_version is included in the unprotected additional data, but it may be ignored or validated against a fixed constant value. Version negotiation must be performed only using the handshake versions (ClientHello.legacy\_version and ServerHello.legacy\_version, as well as the "supported\_versions" extension in ClientHello, HelloRetryRequest, and ServerHello). To maximize interoperability with older endpoints, implementations negotiating TLS 1.0–1.2 should set the record-layer version number to the negotiated version for ServerHello and all subsequent records.


To maximize compatibility with previous non-standard behavior and misconfigured deployments, all implementations should support the authentication validation method expected in this document, even when processing handshakes for earlier TLS versions (see [Section 4.4.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-server-certificate-selection)).

TLS 1.2 and earlier versions support the "Extended Master Secret" [RFC7627](https://tools.ietf.org/html/rfc7627) extension, which digests most of the handshake transcript into the master secret. Because TLS 1.3 always computes the hash from the start of the transcript through Server Finished, implementations that support both TLS 1.3 and earlier versions should indicate in their APIs that the Extended Master Secret extension is being used, regardless of whether TLS 1.3 is used.

## I. Negotiating with an Older Server

A TLS 1.3 Client that wants to negotiate with a Server that does not support TLS 1.3 sends a normal TLS 1.3 ClientHello with 0x0303 (TLS 1.2) in ClientHello.legacy\_version, while using the correct version in the "supported\_versions" extension. If the Server does not support TLS 1.3, it responds with a ServerHello containing an older version number. If the Client agrees to use that version, negotiation proceeds according to the negotiated protocol. A Client resuming a session using a ticket should initiate the connection using the previously negotiated version.

Note that 0-RTT data is incompatible with older Servers and should not be sent unless it is known that the Server supports TLS 1.3. See [Appendix D.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%B8%89-0-rtt-backward-compatibility).

If the Client does not support the version selected by the Server (or finds it unacceptable), the Client must abort the handshake with a "protocol\_version" alert.

Some legacy Server implementations are known not to implement the TLS specification correctly and may abort the connection when they encounter a version or TLS extension they do not recognize. Interoperability with broken Servers is a complex topic outside the scope of this document. Multiple connection attempts may be required to negotiate a backward-compatible connection; however, this practice is susceptible to downgrade attacks and is not recommended.

## II. Negotiating with an Older Client

A TLS Server may receive a ClientHello that indicates a version number lower than the highest version it supports. If the "supported\_versions" extension is present, the Server must negotiate using that extension, as described in [Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions). If the "supported\_versions" extension is not present, the Server must negotiate the minimum of ClientHello.legacy\_version and TLS 1.2. For example, if the Server supports TLS 1.0, 1.1, and 1.2, and legacy\_version is TLS 1.0, the Server will use TLS 1.0 in ServerHello. If the "supported\_versions" extension is not present and the Server supports only versions greater than ClientHello.legacy\_version, the Server must abort the handshake with a "protocol\_version" alert.


Note that earlier versions of TLS did not explicitly specify the record-layer version number value (TLSPlaintext.legacy\_record\_version) in all cases. The Server will receive various TLS 1.x versions in this field, but must always ignore its value.


## III. 0-RTT Backward Compatibility

0-RTT data is incompatible with older Servers. An older Server will respond to the ClientHello with an older ServerHello, but it will not correctly skip the 0-RTT data and will be unable to complete the handshake. This can cause problems when a Client attempts to use 0-RTT, especially in multi-Server deployments. For example, a deployment may roll out TLS 1.3 gradually, with some Servers implementing TLS 1.3 and others implementing TLS 1.2, or a TLS 1.3 deployment may be downgraded to TLS 1.2.

A Client that attempts to send 0-RTT data and receives a TLS 1.2 or earlier ServerHello must cause the connection to fail. It may then retry the connection with 0-RTT disabled. To avoid downgrade attacks, the Client should not disable TLS 1.3; it should disable only 0-RTT.

To avoid this failure mode, multi-Server deployments should ensure that TLS 1.3 is deployed uniformly and stably without 0-RTT before enabling 0-RTT.

## IV. Middlebox Compatibility Mode

Field tests [Ben17a](https://tools.ietf.org/html/rfc8446#ref-Ben17a) [Ben17b](https://tools.ietf.org/html/rfc8446#ref-Ben17b) [Res17a](https://tools.ietf.org/html/rfc8446#ref-Res17a) [Res17b](https://tools.ietf.org/html/rfc8446#ref-Res17b) found that a significant number of middleboxes behave incorrectly when a TLS client/server pair negotiates TLS 1.3. Implementations increase the chance of establishing connections through these middleboxes by making the TLS 1.3 handshake look more like a TLS 1.2 handshake.


- The Client always provides a non-empty session ID in ClientHello, as described in the legacy\_session\_id portion of [Section 4.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello).

- If early data is not offered, the Client sends a dummy change\_cipher\_spec record immediately before sending its second flight of data (see Section 5, paragraph 3). This may occur before its second ClientHello or before its encrypted handshake data is sent. If early data is offered, the record is placed immediately after the first ClientHello.

- The Server sends a dummy change\_cipher\_spec record immediately after its first handshake message. This may be after ServerHello or HelloRetryRequest.

Taken together, these changes make the TLS 1.3 handshake resemble TLS 1.2 session resumption, which improves the chance of successfully establishing connections through middleboxes. This "compatibility mode" is partially negotiated: the Client
 can choose whether to provide a session ID, and the Server must echo it. Either side may send change\_cipher\_spec at any time during the handshake, because they must be ignored by the peer; however, once the Client sends a non-empty session ID, the Server must send change\_cipher\_spec as described in this appendix.


## V. Security Restrictions Related to Backward Compatibility


Implementations negotiating older versions of TLS should prefer forward-secret and AEAD cipher suites, if available.

For the reasons cited in [RFC7465](https://tools.ietf.org/html/rfc7465), RC4 cipher suites are now considered insecure. Implementations must not offer or negotiate RC4 cipher suites for any version of TLS for any reason.

Older versions of TLS allowed the use of extremely weak ciphers. Ciphers with strength below 112 bits must not be offered or negotiated for any version of TLS for any reason.

For the reasons listed in [RFC7568](https://tools.ietf.org/html/rfc7568), SSL 3.0 [RFC6101](https://tools.ietf.org/html/rfc6101) is now considered insecure, and therefore must not be negotiated for any reason.

For the reasons listed in [RFC6176](https://tools.ietf.org/html/rfc6176), SSL 2.0 [SSL2](https://tools.ietf.org/html/rfc8446#ref-SSL2) is now considered insecure, and therefore must not be negotiated for any reason.

Implementations must never send an SSL 2.0-compatible CLIENT-HELLO. Implementations must not negotiate TLS 1.3 or later using an SSL 2.0-compatible CLIENT-HELLO. Implementations are discouraged from accepting an SSL version 2.0-compatible CLIENT-HELLO to negotiate older versions of TLS.

Implementations must never set ClientHello.legacy\_version or ServerHello.legacy\_version to 0x0300 or lower. Any endpoint that receives a Hello message with ClientHello.legacy\_version or ServerHello.legacy\_version set to 0x0300 must abort the handshake with a "protocol\_version" alert.

Implementations must never send any record with a version lower than 0x0300. Implementations should not accept any record with a version lower than 0x0300 (though they might do so inadvertently if they ignore record version numbers entirely).

Implementations must never use the Truncated HMAC extension defined in [RFC6066 Section 7](https://tools.ietf.org/html/rfc6066#section-7), because it is not applicable to AEAD algorithms and has been shown to be insecure in some cases.


------------------------------------------------------

References:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Backward\_Compatibility/](https://halfrost.com/tls_1-3_backward_compatibility/)