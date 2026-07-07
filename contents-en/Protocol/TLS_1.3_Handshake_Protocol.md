# TLS 1.3 Handshake Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/108_0.png'>
</p>


The handshake protocol is used to negotiate the security parameters for a connection. Handshake messages are passed to the TLS record layer, where they are encapsulated into one or more TLSPlaintext or TLSCiphertext records, and processed and transmitted according to the currently active connection state.
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
Protocol messages must be sent in a specific order (described below). If a peer detects that the handshake messages it receives are out of order, it must abort the handshake with an “unexpected\_message” alert message.

In addition, IANA has assigned new handshake message types; see [Chapter 11](https://tools.ietf.org/html/rfc8446#section-11).

## I. Key Exchange Messages

Key exchange messages are used to ensure the security of the Client and Server and to securely establish the communication keys used to protect the handshake and data.

### 1. Cryptographic Negotiation

In the TLS protocol, during key negotiation, the Client can provide the following four options in the ClientHello.

- The list of cipher suites supported by the Client. The cipher suite indicates the AEAD algorithms or HKDF hash pairs supported by the Client.
- The “supported\_groups” extension and the "key\_share" extension. The “supported\_groups” extension indicates the (EC)DHE groups supported by the Client, while the "key\_share" extension indicates whether the Client includes some or all of the (EC)DHE shares.
- The "signature\_algorithms" signature algorithms extension and the "signature\_algorithms\_cert" certificate signature algorithms extension. The "signature\_algorithms" extension indicates which signature algorithms the Client supports. The "signature\_algorithms\_cert" extension indicates the signature algorithms for specific certificates.
- The "pre\_shared\_key" pre-shared key extension and the "psk\_key\_exchange\_modes" extension. The pre-shared key extension contains symmetric key identities that the Client can recognize. The "psk\_key\_exchange\_modes" extension indicates the key exchange modes that may be used with the PSK.

If the Server does not select a PSK, then the first three of the four options above are orthogonal: the Server independently selects a cipher suite, independently selects an (EC)DHE group, independently selects a key share for establishing the connection, and independently selects a signature algorithm/certificate pair for the Client to authenticate the Server. If none of the algorithms in the "supported\_groups" received by the Server is supported by the Server, it must return a "handshake\_failure" or "insufficient\_security" alert message.

If the Server selects a PSK, it must select a key establishment mode from the Client’s "psk\_key\_exchange\_modes" extension. At this point, PSK and (EC)DHE are separate. Because PSK and (EC)DHE are separate, the handshake will not be terminated even if there is no algorithm common to both the Server and Client in "supported\_groups".

If the Server selects an (EC)DHE group and the Client did not provide an appropriate "key\_share" extension in the ClientHello, the Server must respond with a HelloRetryRequest message.

If the Server successfully selects the parameters, a HelloRetryRequest message is not needed. The Server will send a ServerHello message containing the following parameters:

- If PSK is being used, the Server will send a "pre\_shared\_key" extension containing the selected key.
- If PSK is not being used and (EC)DHE is selected, the Server will provide a "key\_share" extension. Typically, if PSK is not used, (EC)DHE and certificate-based authentication are used.
- When authenticating with certificates, the Server sends Certificate and CertificateVerify messages. In the official TLS 1.3 specification, PSK and certificates are commonly used, but not together; future documents may define how to use them simultaneously.

If the Server cannot negotiate a supported set of parameters—that is, if there is no overlap between the parameter sets supported by the Client and the Server—then the Server must send a "handshake\_failure" or "insufficient\_security" message to abort the handshake.

### 2. Client Hello

When a Client connects to a Server for the first time, it needs to send a ClientHello message as the first TLS message. When the Server sends a HelloRetryRequest message, the Client must also respond with a ClientHello message after receiving it. In this case, the Client must send the same, unmodified ClientHello message, except in the following cases:

- If the HelloRetryRequest message contains a "key\_share" extension, replace the share list with a KeyShareEntry containing a single key share from the indicated group.
- If the “early\_data” extension is present, remove it. “early\_data” is not allowed after HelloRetryRequest.
- If the HelloRetryRequest contains a cookie extension, include one.
- If "obfuscated\_ticket\_age" and the binder value are recomputed, and any PSKs incompatible with the cipher suite presented by the Server are optionally removed, update the "pre\_shared\_key" extension.
- Optionally add, remove, or change the length of the ”padding” extension [RFC 7685](https://tools.ietf.org/html/rfc7685).
- Some other modifications may be allowed, such as extension definitions and HelloRetryRequest behavior specified in the future.

Because TLS 1.3 **strictly prohibits renegotiation**, if the Server has already completed TLS 1.3 negotiation and receives a ClientHello at some later point, the Server should not process that message; it must immediately close the connection and send an "unexpected\_message" alert message.

If a Server has established a TLS connection using a previous version of TLS and receives a TLS 1.3 ClientHello during renegotiation, the Server must continue using the previous version and must not negotiate TLS 1.3.

The structure of the ClientHello message is
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
Some notes on the structure:

- legacy\_version:    
	In versions prior to TLS 1.3, this field was used for version negotiation and to indicate the highest TLS version supported by the Client. Experience has shown that **many Servers did not implement version negotiation correctly**, resulting in "version intolerance" — Servers rejected some ClientHello messages they would otherwise have been able to support, simply because those messages carried a version number higher than the version supported by the Server. In TLS 1.3, the Client indicates its version in the "supported\_versions" extension. The legacy\_version field must be set to 0x0303, which is the version number for TLS 1.2. In TLS 1.3 ClientHello messages, legacy\_version is set to 0x0303, and the supported\_versions extension is set to 0x0304. See Appendix D for more details.

- random:    
	A 32-byte random value generated by a secure random number generator. See Appendix C for additional information.
	
- legacy\_session\_id:    
	Versions prior to TLS 1.3 supported the session resumption feature. In TLS 1.3, this feature has been merged with pre-shared keys (PSKs). If the Client has a cached Session ID set by a Server from a version prior to TLS 1.3, this field must be filled with that ID value. In compatibility mode, this value must be non-empty, so if a Client cannot provide a Session from a version prior to TLS 1.3, it must generate a new 32-byte value. This value is not required to be random, but it must be unpredictable, to prevent implementations from hard-coding it to a fixed value. Otherwise, this field must be set to a zero-length vector. (For example, a 0-byte length field.)

- cipher\_suites:  
	This list contains the symmetric encryption options supported by the Client, specifically the record protection algorithms (including key lengths) and the hash algorithms used with HKDF. It is ordered in descending order of the Client's preference. If the list contains cipher suites that the Server does not recognize, cannot support, or does not wish to use, the Server must ignore those cipher suites and process the remaining cipher suites as usual. If the Client attempts to establish a PSK key, it should include at least one PSK-related hash cipher suite.
	
- legacy\_compression\_methods:     
	TLS versions prior to TLS 1.3 supported compression, and this field carried the list of supported compression methods. For every ClientHello, this vector must contain a single byte set to 0, corresponding to the null compression method in earlier TLS versions. If this field in a TLS 1.3 ClientHello contains any other value, the Server must immediately abort the handshake by sending an “illegal\_parameter” alert message. Note that a TLS 1.3 Server may receive ClientHellos from TLS 1.2 or even older versions that contain other compression methods. If those earlier versions are being negotiated, the rules for earlier TLS versions must be followed.
	
- extensions:      
	The Client requests extended functionality from the Server by sending data in the extensions field. “Extension” follows the format definition. In TLS 1.3, the use of certain extensions is mandatory, because functionality has been moved into extensions to preserve compatibility with ClientHello messages from earlier TLS versions. The Server must ignore extensions it does not recognize.
	
All versions of TLS allow the optional inclusion of the compression\_methods extension field. TLS 1.3 ClientHello messages normally include extension messages (at least “supported\_versions”; otherwise, the message will be interpreted as a TLS 1.2 ClientHello message). However, a TLS 1.3 Server may also receive ClientHello messages from earlier TLS versions that do not include the extensions field. The presence of extensions can be determined by checking whether there are bytes after the compression\_methods field at the end of the ClientHello. Note that this method for detecting optional data differs from the usual TLS approach for fields with variable length, but it was used for compatibility before extensions were defined. A TLS 1.3 Server needs to perform this check first, and attempt to negotiate TLS 1.3 only if the “supported\_versions” extension is present. If a version prior to TLS 1.3 is negotiated, the Server must perform two checks: whether there is data after the legacy\_compression\_methods field; and whether no data follows a valid extensions block. If either of these two checks fails, the Server must immediately abort the handshake by sending a "decode\_error" alert message.
	
	
If the Client requests additional functionality through extensions but the Server does not provide it, the Client may abort the handshake.

After sending the ClientHello message, the Client waits for a ServerHello or HelloRetryRequest message. If early data is in use, the Client may send early Application Data while waiting for the next handshake message.

### 3. Server Hello

If the Server and Client can negotiate a set of mutually acceptable handshake parameters from the ClientHello message, the Server sends a Server Hello message in response to the ClientHello message.

The message structure is:
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
	In versions prior to TLS 1.3, this field was used for version negotiation and to identify the version selected by both parties when establishing the connection. Unfortunately, some middleboxes may fail when this field is assigned a new value. In TLS 1.3, the Server uses the "supported\_versions" extension field to indicate the versions it supports, and the legacy\_version field must be set to 0x0303 (the value representing TLS 1.2). (For details on backward compatibility, see Appendix D.)
	
- random:  
	A random 32-byte value generated by a secure random number generator. If TLS 1.1 or TLS 1.2 is negotiated, the last 8 bytes must be overwritten, and the remaining 24 bytes must be random. This structure is generated by the Server and must be independent of ClientHello.random.

- legacy\_session\_id\_echo:  
	The contents of the Client's legacy\_session\_id field. Note that even if the Server decides not to resume a pre-TLS 1.3 session, if the Client's legacy\_session\_id field contains a pre-TLS 1.3 value, the legacy\_session\_id\_echo field will still be echoed. If the legacy\_session\_id\_echo value received by the Client does not match the value it sent in ClientHello, it must immediately abort the handshake with an "illegal\_parameter" alert message.
	
- cipher\_suite:  
	A cipher suite selected by the Server from the cipher\_suites list in ClientHello. If the Client receives a cipher suite that it did not offer, it should immediately abort the handshake with an "illegal\_parameter" alert message.
	
	
- legacy\_compression\_method:  
	A single byte that must have the value 0.
	
- extensions:  
	A list of extensions. ServerHello must include only the extensions required to establish the cryptographic context and negotiate the protocol version. **All TLS 1.3 ServerHello messages must contain the "supported\_versions" extension**. The current ServerHello message additionally contains the "pre\_shared\_key" extension or the "key\_share" extension, or both extensions (when the connection is established using PSK and (EC)DHE). Other extensions are sent separately in the EncryptedExtensions message.
	
For backward compatibility with middleboxes, the HelloRetryRequest message uses the same structure as the ServerHello message, but the random field must be set to the specific SHA-256 value for HelloRetryRequest:
```c
     CF 21 AD 74 E5 9A 61 11 BE 1D 8C 02 1E 65 B8 91
     C2 A2 11 16 7A BB 8C 5E 07 9E 09 E2 C8 A8 33 9C
```
After receiving the server\_hello message, the implementation must first check whether this random value matches the value above. If it matches the value above, processing may continue.

TLS 1.3 includes a downgrade protection mechanism, implemented by embedding a value in the Server random. When a TLS 1.3 Server negotiates TLS 1.2 or an older version, in response to the ClientHello, the ServerHello message must include a specific random value in its last 8 bytes.

If TLS 1.2 is negotiated, the TLS 1.3 Server must set the last 8 bytes of the Random field in ServerHello to:
```c
44 4F 57 4E 47 52 44 01
D  O  W  N  G  R  D
```
If TLS 1.1 or an earlier version is negotiated, a TLS 1.3 server and a TLS 1.2 server MUST set the last 8 bytes of the `Random` field in `ServerHello` to:
```c
44 4F 57 4E 47 52 44 00
D  O  W  N  G  R  D
```
After a TLS 1.3 Client receives a ServerHello message for TLS 1.2 or an older TLS version, it must check that the last 8 bytes of the Random field in the ServerHello are not equal to either of the two values above. A TLS 1.2 Client also needs to check the last 8 bytes; if TLS 1.1 or an older version is negotiated, the Random value must not equal the second value above. If neither check matches, the Client must abort the handshake with an "illegal\_parameter" alert. This mechanism provides limited protection against downgrade attacks. The Finished exchange provides protection beyond the scope of this mechanism: in TLS 1.2 or earlier, the ServerKeyExchange message contains a signature over the two random values. As long as ephemeral cryptography is used, an attacker cannot modify the random values without being detected. Therefore, static RSA cannot provide protection against downgrade attacks.

>Please note that the changes above are described in [RFC5246](https://tools.ietf.org/html/rfc5246); in practice, many TLS 1.2 Clients and Servers do not follow the requirements above.

If a Client receives a TLS 1.3 ServerHello while renegotiating TLS 1.2 or an older version, the Client must immediately send a “protocol\_version” alert and abort the handshake. Note that **once TLS 1.3 negotiation has completed, renegotiation is no longer possible, because TLS 1.3 strictly prohibits renegotiation**.


### 4. Hello Retry Request

If the ClientHello sent by the Client contains a mutually supported set of parameters, but the Client cannot provide sufficient information for the subsequent handshake, the Server needs to respond to the ClientHello with a HelloRetryRequest message. In the previous section, we discussed that HelloRetryRequest and ServerHello messages share the same data structure, and that the legacy\_version, legacy\_session\_id\_echo, cipher\_suite, and legacy\_compression\_method fields have the same meanings. For convenience, in the following discussion we treat HelloRetryRequest as a distinct message.

The Server’s set of extensions must include "supported\_versions". In addition, it needs to include the minimal set of extensions that enables the Client to generate a correct ClientHello. Compared with ServerHello, HelloRetryRequest may contain only extensions that appeared in the first ClientHello, except for the optional "cookie" extension.


After receiving a HelloRetryRequest message, the Client must first validate the four parameters legacy\_version, legacy\_session\_id\_echo, cipher\_suite, and legacy\_compression\_method. It then determines the version to use for the connection with the Server starting from “supported\_versions”, and only after that processes the extensions. If the HelloRetryRequest would not cause any change to the ClientHello, the Client must abort the handshake with an “illegal\_parameter” alert. If the Client receives a second HelloRetryRequest message on a connection (where the ClientHello itself was already sent in response to a HelloRetryRequest), it must abort the handshake with an “unexpected\_message” alert.

Otherwise, the Client must process all extensions in the HelloRetryRequest and send a second, updated ClientHello. The HelloRetryRequest extension names defined in this specification are:

- supported\_versions
- cookie
- key\_share

If the Client receives a cipher suite that it did not offer, it must abort the handshake immediately. The Server must ensure that, upon receiving a valid and updated ClientHello, both sides are negotiating the same cipher suite (if the Server selects the cipher suite as the first step of negotiation, this step will be sent automatically). After receiving the ServerHello, the Client must check that the cipher suite offered in the ServerHello is the same as the cipher suite in the HelloRetryRequest; otherwise, it must abort the handshake with an “illegal\_parameter” alert.


In addition, in its updated ClientHello, the Client must not offer any pre-shared key associated with a hash other than the one for the selected cipher suite. This allows the Client to avoid computing partial transcript hashes for multiple hashes in the second ClientHello.

The value of the selected\_version field in the "support\_versions" extension of the HelloRetryRequest must be preserved in the ServerHello. If this value changes, the Client must abort the handshake with an “illegal\_parameter” alert.


## II. Extensions

Many TLS messages contain tag-length-value-encoded extension data structures:
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
Here:

- "extension\_type" identifies the specific extension type.
- "extension\_data" contains information specific to that particular extension type.

All extension types are maintained by IANA; see the appendix for details.

Extensions are typically structured as request/response, although some extensions are merely indicators and do not have any response. The Client sends its extension requests in ClientHello, and the Server sends the corresponding extension responses in ServerHello, EncryptedExtensions, HelloRetryRequest, and Certificate messages. The Server sends extension requests in the CertificateRequest message, and the Client may respond with a Certificate message. The Server may also send an unsolicited extension request directly in the NewSessionTicket message, and the Client does not need to directly respond to that message.

If the peer did not send the corresponding extension request, then, except for the “cookie” extension in the HelloRetryRequest message, implementations MUST NOT send an extension response. Upon receiving such an extension, the endpoint MUST abort the handshake with an "unsupported\_extension" alert message.


The following table lists the extension names for the messages in which they may appear, using the following notation: CH (ClientHello), SH (ServerHello), EE (EncryptedExtensions), CT (Certificate), CR (CertificateRequest), NST (NewSessionTicket), and HRR (HelloRetryRequest). When an implementation receives a message it recognizes, and the extension is not specified as allowed to appear in that message, it MUST abort the handshake with an "illegal\_parameter" alert message.
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
When multiple extension types are present, the ordering of extensions may be arbitrary, except that `"pre_shared_key"` MUST be the last extension in the ClientHello. (`"pre_shared_key"` may appear anywhere in the extension block in ServerHello.) There MUST NOT be more than one extension of the same type.

In TLS 1.3, unlike TLS 1.2, extensions must be negotiated in every handshake, even in PSK resumption mode. However, the parameters for 0-RTT are negotiated in the previous handshake. If the parameters do not match, 0-RTT must be rejected.

In TLS 1.3, there are subtle interactions between new features and legacy features that can significantly reduce the overall security. The following are factors to consider when designing new extensions:

- In some cases, the server’s refusal to agree to an extension is an error (for example, the handshake cannot continue); in others, it simply means that a particular feature is not supported. In general, the former should be handled with an error alert, and the latter should be handled with a field in the server’s extension response.

- Extensions should, as much as possible, be designed to prevent attacks that manipulate handshake messages to force the use (or non-use) of a particular feature. This principle must be followed regardless of whether the feature introduces a security issue. In general, extension fields included in the hash input to the Finished message are not a concern, but special care is required when an extension attempts to change the meaning of messages sent during the handshake phase. Designers and implementers should be aware that, until authentication is completed for the handshake, an attacker can modify messages and insert, delete, or replace extensions.

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
For the Client, “supported\_versions” is used to indicate the TLS versions it supports. For the Server, it is used to indicate the TLS version currently in use. This extension contains a list of supported versions ordered by preference. The most preferred version comes first. The TLS 1.3 specification requires this extension to be included when sending a ClientHello message, and the extension must contain all TLS versions that are intended for negotiation. (For this specification, that means at least 0x0304, but if earlier versions of TLS are to be negotiated, this extension must also be included.)


If the “supported\_versions” extension is absent, a Server that complies with TLS 1.3 and is also compatible with the TLS 1.2 specification needs to negotiate TLS 1.2 or an earlier version, even if ClientHello.legacy\_version is 0x0304 or higher. When the Server receives a ClientHello whose legacy\_version value is 0x0304 or higher, the Server may need to abort the handshake immediately.

If the “supported\_versions” extension is present in ClientHello, the Server is prohibited from using the value of ClientHello.legacy\_version for version negotiation, and must use only "supported\_versions" to determine the Client’s preferences. The Server must select only a TLS version present in this extension, and must ignore any unknown versions. Note that if one peer supports a sparse range, this mechanism makes it possible to negotiate versions earlier than TLS 1.2. TLS 1.3 implementations that choose to support earlier TLS versions should support TLS 1.2. The Server should be prepared to receive ClientHello messages that contain this extension but do not include 0x0304 in the versions list.

When negotiating a version earlier than TLS 1.3, the Server must set ServerHello.version and must not send the "supported\_versions" extension. When negotiating TLS 1.3, the Server must send the "supported\_versions" extension in response, and the extension must contain the selected TLS 1.3 version number (0x0304). It must also set ServerHello.legacy\_version to 0x0303 (TLS 1.2). The Client must check this extension before processing ServerHello (although it needs to parse ServerHello first in order to read the extension). If the "supported\_versions" extension is present, the Client must ignore the value of ServerHello.legacy\_version and use only the value in "supported\_versions" to determine the selected version. If the "supported\_versions" extension in ServerHello contains a version that the Client did not offer, or contains a version earlier than TLS 1.3 (i.e., TLS 1.3 was being negotiated but the extension contains a pre-TLS 1.3 version), the Client must immediately send an "illegal\_parameter" alert message and abort the handshake.


### 2. Cookie
```c
      struct {
          opaque cookie<1..2^16-1>;
      } Cookie;
```
Cookies have two primary purposes:

- To allow the Server to force the Client to demonstrate reachability at its network address (thereby providing a measure of DoS protection), primarily for connectionless transports (see the example in [RFC 6347](https://tools.ietf.org/html/rfc6347)).


- To allow the Server to offload state. This allows the Server to store no state when sending a HelloRetryRequest message to the Client. To achieve this, the Server can store the hash of the ClientHello in the cookie of the HelloRetryRequest (protected with an appropriate integrity algorithm).


When sending a HelloRetryRequest message, the Server can provide the “cookie” extension to the Client (this is an exception to the general rule that only extensions that might be sent are allowed to appear in the ClientHello). When sending a new ClientHello message, the Client MUST copy the contents of the extension received in the HelloRetryRequest into the “cookie” extension in the new ClientHello. The Client MUST NOT use the Cookie from the initial ClientHello in subsequent connections.


When the Server is operating statelessly, it may receive an unprotected change\_cipher\_spec message between the first and second ClientHello. Since the Server has not stored any state, it will behave as if this were the first message that arrived. A stateless Server MUST ignore these records.


### 3. Signature Algorithms


TLS 1.3 provides two extensions to indicate the signature algorithms that may be used in digital signatures. The "signature\_algorithms\_cert" extension provides the signature algorithms in certificates. The "signature\_algorithms" extension (which already existed in TLS 1.2) provides the signature algorithms in CertificateVerify messages. The key in the certificate MUST match the appropriate type for the signature algorithm used. This is a special issue for RSA keys and PSS signatures, as described below: If the "signature\_algorithms\_cert" extension is absent, the "signature\_algorithms" extension also applies to signatures in certificates. A Client that wants the Server to authenticate itself with a certificate MUST send the "signature\_algorithms" extension. If the Server is performing certificate authentication and the Client has not provided the "signature\_algorithms" extension, the Server MUST abort the handshake with a "missing\_extension" message.

The intent of adding the "signature\_algorithms\_cert" extension is to allow implementations that already support different sets of algorithms for certificates to explicitly advertise their capabilities. TLS 1.2 implementations should also process this extension. Implementations that have the same policy in both cases may omit the "signature\_algorithms\_cert" extension.

The "extension\_data" field in these extensions contains a SignatureSchemeList value:
```c
enum {
          /* RSASSA-PKCS1-v1_5 algorithms */
          rsa_pkcs1_sha256(0x0401),
          rsa_pkcs1_sha384(0x0501),
          rsa_pkcs1_sha512(0x0601),

          /* ECDSA algorithms */
          ecdsa_secp256r1_sha256(0x0403),
          ecdsa_secp384r1_sha384(0x0503),
          ecdsa_secp521r1_sha512(0x0603),

          /* RSASSA-PSS algorithms with public key OID rsaEncryption */
          rsa_pss_rsae_sha256(0x0804),
          rsa_pss_rsae_sha384(0x0805),
          rsa_pss_rsae_sha512(0x0806),

          /* EdDSA algorithms */
          ed25519(0x0807),
          ed448(0x0808),

          /* RSASSA-PSS algorithms with public key OID RSASSA-PSS */
          rsa_pss_pss_sha256(0x0809),
          rsa_pss_pss_sha384(0x080a),
          rsa_pss_pss_sha512(0x080b),

          /* Legacy algorithms */
          rsa_pkcs1_sha1(0x0201),
          ecdsa_sha1(0x0203),

          /* Reserved Code Points */
          private_use(0xFE00..0xFFFF),
          (0xFFFF)
      } SignatureScheme;

      struct {
          SignatureScheme supported_signature_algorithms<2..2^16-2>;
      } SignatureSchemeList;

```
Please note: this enum is named "SignatureScheme" because the "SignatureAlgorithm" type already existed in TLS 1.2 and is being replaced. In this article, we use the term "signature algorithm" throughout.

Each listed SignatureScheme value is a single signature algorithm that the Client is willing to verify. These values are listed in descending order of preference. Note that signature algorithms take a message of arbitrary length as input, rather than a digest. Algorithms traditionally used with digests should be defined in TLS as first hashing the input with the specified hash algorithm, and then performing the usual processing. The codes listed above have the following meanings:


- RSASSA-PKCS1-v1\_5 algorithms:  
	Indicates signature algorithms using RSASSA-PKCS1-v1\_5 [RFC8017](https://tools.ietf.org/html/rfc8017) and the corresponding hash algorithms defined in [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS). These values refer only to signatures that appear in certificates and are not defined for use in signing TLS handshake messages. These values appear in "signature\_algorithms" and "signature\_algorithms\_cert" because backward compatibility with TLS 1.2 is required.
	
- ECDSA algorithms:  
	Indicates that the signature algorithm uses ECDSA, with the corresponding curves defined in ANSI X9.62 [ECDSA](https://tools.ietf.org/html/rfc8446#ref-ECDSA) and FIPS 186-4 [DSS](https://tools.ietf.org/html/rfc8446#ref-DSS), and the corresponding hash algorithms defined in [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS). Signatures are represented as DER-encoded ECDSA-Sig-Value structures.
	
- RSASSA-PSS RSAE algorithms:  
	Indicates the use of the RSASSA-PSS signature algorithm with mask generation function 1. The digest used in the mask generation function and the digest being signed are both the corresponding hash algorithms defined in [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS). The salt length MUST be equal to the output length of the digest algorithm. If the public key is in an X.509 certificate, the rsaEncryption OID [RFC5280](https://tools.ietf.org/html/rfc5280) MUST be used.
	
- EdDSA algorithms:  
	Indicates the use of the EdDSA algorithms defined in [RFC 8032](https://tools.ietf.org/html/rfc8032), or their subsequent improved algorithms. Note that these corresponding algorithms are the "PureEdDSA" algorithms, not the "prehash" variants.

- RSASSA-PSS PSS algorithms:  
	Indicates the use of the RSASSA-PSS [RFC 8017](https://tools.ietf.org/html/rfc8017) signature algorithm with mask generation function 1. The digest used in the mask generation function and the digest being signed are both the corresponding hash algorithms defined in [SHS](https://tools.ietf.org/html/rfc8446#ref-SHS). The salt length MUST be equal to the length of the digest algorithm output. If the public key is in an X.509 certificate, the RSASSA-PSS OID [RFC5756](https://tools.ietf.org/html/rfc5756) MUST be used. When it is used in certificate signatures, the algorithm parameters MUST be DER-encoded. If corresponding public key parameters are present, the parameters in the signature MUST be the same as the parameters in the public key.
	
- Legacy algorithms:  
	Indicates the use of algorithms that are being deprecated because they have known weaknesses. In particular, SHA-1 is used together with the RSASSA-PKCS1-v1\_5 and ECDSA algorithms mentioned above. These values refer only to signatures that appear in certificates and are not defined for use in signing TLS handshake messages. These values appear in "signature\_algorithms" and "signature\_algorithms\_cert" because backward compatibility with TLS 1.2 is required. Endpoints SHOULD NOT negotiate these algorithms, but are permitted to do so solely for backward compatibility. Clients that offer these values MUST list them at the lowest priority (after all other algorithms in the SignatureSchemeList). A TLS 1.3 Server MUST NOT provide a SHA-1-signed certificate unless it is impossible to generate a valid certificate chain without it.

	
The signature on a self-signed certificate or the certificate of a trust anchor is not validated, because such certificates begin a certification path (see [RFC 5280](https://tools.ietf.org/html/rfc5280#section-3.2)). A certificate that begins a certification path may use a signature algorithm that is not advertised as supported in the "signature\_algorithms" extension.
	
Note that the definition of this extension in TLS 1.2 differs from its definition in TLS 1.3. When TLS 1.2 is negotiated, TLS 1.3 implementations that are willing to negotiate TLS 1.2 MUST comply with the requirements of [RFC5246](https://tools.ietf.org/html/rfc5246), in particular:

- TLS 1.2 ClientHellos may omit this extension.	

- In TLS 1.2, the extension contains hash/signature pairs. These pairs are encoded as two octets, so the allocated SignatureScheme values are aligned with the TLS 1.2 encoding. Some legacy pairs are reserved as unassigned. These algorithms have been deprecated by TLS 1.3. They MUST NOT be offered or negotiated by any implementation. In particular, MD5 [[SLOTH]](https://tools.ietf.org/html/rfc8446#ref-SLOTH), SHA-224, and DSA MUST NOT be used.

- The ECDSA signature schemes correspond to the TLS 1.2 hash/signature pairs. However, the legacy semantics did not restrict the signing curve. If TLS 1.2 is negotiated, implementations MUST be prepared to accept signatures using any curve in the "supported\_groups" extension.
	
- Even if TLS 1.2 is negotiated, implementations that support RSASSA-PSS (which is mandatory in TLS 1.3) MUST be prepared to accept signatures using that scheme. In TLS 1.2, RSASSA-PSS is used with RSA cipher suites.
	
	
	
	
### 4. Certificate Authorities
	
The "certificate\_authorities" extension is used to indicate the CAs supported by the endpoint, and the receiving endpoint should use it to guide certificate selection.
	
The body of the "certificate\_authorities" extension contains a CertificateAuthoritiesExtension structure:
```c
      opaque DistinguishedName<1..2^16-1>;

      struct {
          DistinguishedName authorities<3..2^16-1>;
      } CertificateAuthoritiesExtension;
```
	
- authorities:  
	A list of acceptable certificate authorities' distinguished names [X501](https://tools.ietf.org/html/rfc8446#ref-X501), represented in DER [X690](https://tools.ietf.org/html/rfc8446#ref-X690) encoding. These distinguished names specify the required distinguished names for trust anchors or subordinate CAs. Thus, this message can be used to describe known trust anchors as well as the desired authorization space.
	
A client MAY send the "certificate\_authorities" extension in the ClientHello message, and a server MAY send the "certificate\_authorities" extension in the CertificateRequest message.


The "trusted\_ca\_keys" extension serves the same purpose as the "certificate\_authorities" extension, but is more complex. The "trusted\_ca\_keys" extension cannot be used in TLS 1.3, but in versions prior to TLS 1.3, it may appear in the client's ClientHello message.


### 5. OID Filters

The "oid\_filters" extension allows the server to provide a set of OID/value pairs for matching the client's certificate. If the server wants to send this extension, it can only be sent in the CertificateRequest message.
```c
      struct {
          opaque certificate_extension_oid<1..2^8-1>;
          opaque certificate_extension_values<0..2^16-1>;
      } OIDFilter;

      struct {
          OIDFilter filters<0..2^16-1>;
      } OIDFilterExtension;
```
- filters:  
	A list of certificate extension OIDs [RFC 5280](https://tools.ietf.org/html/rfc5280) with allowed values, represented in DER-encoded [X690](https://tools.ietf.org/html/rfc8446#ref-X690) format. Some certificate extension OIDs allow multiple values (for example, Extended Key Usage). If the Server includes a non-empty filters list, the Client certificate included in the response must contain all specified extension OIDs recognized by the Client. For each extension OID recognized by the Client, all specified values must be present in the Client certificate (although the certificate may also contain other values). However, the Client must ignore and skip any certificate extension OIDs it does not recognize. If the Client ignores some required certificate extension OIDs and provides a certificate that does not satisfy the request, the Server may, at its discretion, either continue the connection with an unauthenticated Client or abort the handshake with an "unsupported\_certificate" alert message. Any given OID must not appear more than once in the filters list.


The PKIX RFCs define various certificate extension OIDs and their corresponding value types. Depending on the type, matching certificate extension values are not necessarily bitwise equal. TLS implementations are expected to rely on their PKI libraries to select certificates based on certificate extension OIDs.

This document defines matching rules for two standard certificate extensions defined in [RFC5280](https://tools.ietf.org/html/rfc5280):


- The Key Usage extension in a certificate matches the request when all Key Usage bits asserted in the request are also asserted in the Key Usage certificate extension.

- The Extended Key Usage extension in a certificate matches the request when all key OIDs in the request are also present in the Extended Key Usage certificate extension. The special anyExtendedKeyUsage OID must not be used in the request.


Separate specifications may define matching rules for other certificate extensions.


### 6. Post-Handshake Client Authentication


The "post\_handshake\_auth" extension is used to indicate that the Client is willing to authenticate after the handshake. The Server must not send a post-handshake CertificateRequest message to a Client that did not provide this extension. The Server must not send this extension.
```c
      struct {} PostHandshakeAuth;
```
The "extension\_data" field in the "post\_handshake\_auth" extension is zero length.


### 7. Supported Groups

When the Client sends the "supported\_groups" extension, this extension indicates the named groups supported by the Client for key exchange, in descending order of preference.


Note: In versions prior to TLS 1.3, this extension was originally called "elliptic\_curves" and contained only elliptic curve groups. For details, see [RFC8422](https://tools.ietf.org/html/rfc8422) and [RFC7919](https://tools.ietf.org/html/rfc7919). This extension can also be used to negotiate ECDSA curves. Signature algorithms are now negotiated independently.

The "extension\_data" field in this extension contains a "NamedGroupList" value:
```c
      enum {

          /* Elliptic Curve Groups (ECDHE) */
          secp256r1(0x0017), secp384r1(0x0018), secp521r1(0x0019),
          x25519(0x001D), x448(0x001E),

          /* Finite Field Groups (DHE) */
          ffdhe2048(0x0100), ffdhe3072(0x0101), ffdhe4096(0x0102),
          ffdhe6144(0x0103), ffdhe8192(0x0104),

          /* Reserved Code Points */
          ffdhe_private_use(0x01FC..0x01FF),
          ecdhe_private_use(0xFE00..0xFEFF),
          (0xFFFF)
      } NamedGroup;

      struct {
          NamedGroup named_group_list<2..2^16-1>;
      } NamedGroupList;
```
- Elliptic Curve Groups (ECDHE):  
	Indicates support for the corresponding named curves defined in FIPS 186-4 [[DSS]](https://tools.ietf.org/html/rfc8446#ref-DSS) or [[RFC7748]](https://tools.ietf.org/html/rfc7748). Values from 0xFE00 to 0xFEFF are reserved for use as specified in [[RFC8126]](https://tools.ietf.org/html/rfc8126).
	
	

- Finite Field Groups (DHE):  
	Indicates support for the corresponding finite field groups, whose definitions can be found in [[RFC7919]](https://tools.ietf.org/html/rfc7919). Values from 0x01FC to 0x01FF are reserved for use.

Entries in named\_group\_list are ordered according to the sender's preference (most preferred first).

In TLS 1.3, the Server is allowed to send a "supported\_groups" extension to the Client. The Client must not act on any information found in "supported\_groups" before the handshake has completed successfully, but it may use information obtained from a successfully completed handshake to change the groups used in the "key\_share" extension on subsequent connections. If the Server has a group that it would prefer to accept over the values in the "key\_share" extension, but is still willing to accept the ClientHello message, it should send "supported\_groups" to update the Client's view of its preferences. This extension should contain all groups supported by the Server, regardless of whether the Client supports them.


### 8. Key Share

The "key\_share" extension contains the endpoint's cryptographic parameters.

The Client may send an empty client\_shares vector to request that the Server select a group, at the cost of an additional round trip.
```c
      struct {
          NamedGroup group;
          opaque key_exchange<1..2^16-1>;
      } KeyShareEntry;
```
- group:  
	The named group of the key to be exchanged.
	
- key\_exchange:  
	Key exchange information. The contents of this field are determined by the specific group and the corresponding definition. Finite-field Diffie-Hellman parameters are described below. Elliptic-curve Diffie-Hellman parameters are also described below.


In the ClientHello message, the "extension\_data" in the "key\_share" extension contains a KeyShareClientHello value:
```c
      struct {
          KeyShareEntry client_shares<0..2^16-1>;
      } KeyShareClientHello;
```
- client\_shares:   
	A list of KeyShareEntry values provided in descending order of the Client's preference.

If the Client is requesting a HelloRetryRequest, this vector MAY be empty. Each KeyShareEntry value MUST correspond to a group offered in the "supported\_groups" extension, and MUST appear in the same order. However, when the highest-priority combinations are new and it is not feasible to provide pre-generated key shares for all of them, the values MAY be a non-contiguous subset of the "supported\_groups" extension and MAY omit the most preferred groups.

The Client MAY provide as many KeyShareEntry values as there are supported groups it offers. Each value represents a set of key exchange parameters. For example, the Client might provide shares for multiple elliptic curves or multiple FFDHE groups. The key\_exchange value in each KeyShareEntry MUST be generated independently. The Client MUST NOT provide more than one KeyShareEntry value for the same group. The Client MUST NOT provide any KeyShareEntry value for a group that is not listed in the Client's "supported\_group" extension. The Server checks these rules and, if they are violated, immediately aborts the handshake by sending an "illegal\_parameter" alert message.

In a HelloRetryRequest message, the "extension\_data" field of the "key\_share" extension contains a KeyShareHelloRetryRequest value.
```c
      struct {
          NamedGroup selected_group;
      } KeyShareHelloRetryRequest;
```
- selected\_group:  
	The group that the Server intends to negotiate, which is mutually supported and for which it is requesting a retry of the ClientHello / KeyShare.


After receiving this extension in a HelloRetryRequest message, the Client must validate two conditions. First, selected\_group must have appeared in "supported\_groups" in the original ClientHello. Second, selected\_group must not have appeared in "key\_share" in the original ClientHello. If either of the above checks fails, the Client must abort the handshake with an "illegal\_parameter" alert. Otherwise, when sending the new ClientHello, the Client must replace the original "key\_share" extension with one that contains only a new KeyShareEntry for the group indicated by the selected\_group field that triggered the HelloRetryRequest.


In a ServerHello message, the "extension\_data" field in the "key\_share" extension contains a KeyShareServerHello value.
```c
      struct {
          KeyShareEntry server_share;
      } KeyShareServerHello;
```
- server\_share:  
	A single KeyShareEntry value in the same group as the one shared with the Client.

If an (EC)DHE key is used to establish the connection, the Server provides only one KeyShareEntry in ServerHello. This value must be in the same group as the value selected by the Server from the KeyShareEntry values provided by the Client for negotiating the key exchange. The Server must not send a KeyShareEntry value for any group specified in the Client's "supported\_groups" extension. The Server also must not send a KeyShareEntry value when using the "psk\_ke" PskKeyExchangeMode. If an (EC)DHE key is used to establish the connection and the Client receives a HelloRetryRequest message containing the "key\_share" extension, the Client must verify that the NamedGroup selected in ServerHello is the same as the one in the HelloRetryRequest. If they are not the same, the Client must immediately abort the handshake by sending an "illegal\_parameter" alert message.


#### (1) Diffie-Hellman Parameters

The Diffie-Hellman [[DH76]](https://tools.ietf.org/html/rfc8446#ref-DH76) parameters for both the Client and the Server are encoded in the opaque `key_exchange` field of the KeyShare data structure in the KeyShareEntry. The opaque value contains the Diffie-Hellman public key (Y = g^X mod p) for the specified group, encoded as a big-endian integer. This value is p bytes in size; if there are not enough bytes, zeros must be added on the left.


Note: for a given Diffie-Hellman group, padding causes all public keys to have the same length.

Peers must validate each other's public keys to ensure 1 < Y < p-1. This check ensures that the remote peer is operating correctly and also prevents the local system from being forced into a smaller subgroup.


#### (2) ECDHE Parameters


The ECDHE parameters for both the Client and the Server are encoded in the opaque `key_exchange` field of the KeyShare data structure in the KeyShareEntry.

For secp256r1, secp384r1, and secp521r1, the contents are the serialized value of the following structure:
```c
      struct {
          uint8 legacy_form = 4;
          opaque X[coordinate_length];
          opaque Y[coordinate_length];
      } UncompressedPointRepresentation;
```
X and Y are the binary representations of the X and Y values, respectively, in network byte order. Because there is no internal length marker, each number occupies the number of octets implied by the curve parameters. For P-256, this means that each of X and Y occupies 32 octets, left-padded with zeros if necessary. For P-384, they each occupy 48 octets, and for P-521, they each occupy 66 octets.

For the curves secp256r1, secp384r1, and secp521r1, each peer must validate the other peer's public key Q to ensure that the point is a valid point on the elliptic curve. Suitable validation methods are defined in [[ECDSA]](https://tools.ietf.org/html/rfc8446#ref-ECDSA) or [[KEYAGREEMENT]](https://tools.ietf.org/html/rfc8446#ref-KEYAGREEMENT). This process consists of three steps. First, verify that Q is not the point at infinity (O). Second, verify that the two integers x and y in Q = (x, y) are in the correct ranges. Third, verify that (x, y) is a correct solution to the elliptic curve equation. For these curves, implementations do not need to further verify membership in the correct subgroup.


For X25519 and X448, the contents of the public value are the byte-string inputs and outputs of the corresponding functions defined in [[RFC7748]](https://tools.ietf.org/html/rfc7748): 32 bytes for X25519 and 56 bytes for X448.

Note: **Versions prior to TLS 1.3 allowed point format negotiation; TLS 1.3 removed this feature in favor of a separate point format for each curve**.


### 9. Pre-Shared Key Exchange Modes

To use a PSK, the Client must also send a "psk\_key\_exchange\_modes" extension. The semantics of this extension are that the Client supports using PSKs only with these modes. This restricts the use of the PSKs offered in this ClientHello, as well as the use of PSKs provided by the Server via NewSessionTicket.

If the Client offers a "pre\_shared\_key" extension, it must also offer a "psk\_key\_exchange\_modes" extension. If the Client sends "pre\_shared\_key" without a "psk\_key\_exchange\_modes" extension, the Server must abort the handshake immediately. The Server must not select a key exchange mode that the Client did not list. This extension also restricts the modes used with PSK resumption. The Server also must not send a NewSessionTicket that is incompatible with the proposed modes. However, if the Server does so anyway, the only consequence is that the Client will fail when it attempts to resume the session.


The Server must not send a "psk\_key\_exchange\_modes" extension:
```c
      enum { psk_ke(0), psk_dhe_ke(1), (255) } PskKeyExchangeMode;

      struct {
          PskKeyExchangeMode ke_modes<1..255>;
      } PskKeyExchangeModes;
```
- psk\_ke:  
	PSK-only key establishment. In this mode, the Server cannot provide a "key\_share" value.

- psk\_dhe\_ke:  
	PSK and (EC)DHE establishment. In this mode, the Client and Server must provide "key\_share" values.

Any values assigned in the future must ensure that the protocol messages sent can unambiguously identify the mode selected by the Server. Currently, the value selected by the Server is indicated by the presence of "key\_share" in ServerHello.

### 10. Early Data Indication

When using a PSK and the PSK permits the use of early\_data, the Client can send application data in its first message. If the Client chooses to do so, it must send the "pre\_shared\_key" and "early\_data" extensions.


The "extension\_data" field in the Early Data Indication extension contains an EarlyDataIndication value.
```c
      struct {} Empty;

      struct {
          select (Handshake.msg_type) {
              case new_session_ticket:   uint32 max_early_data_size;
              case client_hello:         Empty;
              case encrypted_extensions: Empty;
          };
      } EarlyDataIndication;
```
For the use of the max\_early\_data\_size field, see the [New Session Ticket Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message) section.


The parameters for 0-RTT data (version, symmetric cipher suite, Application-Layer Protocol Negotiation protocol [[RFC7301]](https://tools.ietf.org/html/rfc7301), etc.) are tied to the parameters of the PSK in use. For externally configured PSKs, the associated values are provided with the key. For PSKs established via a NewSessionTicket message, the associated values are the values negotiated when the PSK connection was established. The PSK used to encrypt early data must be the first PSK listed by the Client in the "pre\_shared\_key" extension.


For PSKs provided via NewSessionTicket, the Server must verify that the ticket age in the selected PSK identity (computed by subtracting ticket\_age\_add from PskIdentity.obfuscated\_ticket\_age modulo 2^32) is within a small tolerance of the time since the ticket was issued. If the time difference is large, the Server should continue the handshake, but reject 0-RTT, and must also assume that this ClientHello is fresh and take no other action.


0-RTT messages sent in the first flight have the same (encrypted) content type as messages of the same type sent in other flights (handshake and application data), but are protected with different keys. If the Server has accepted early data, after the Client receives the Server's Finished message, the Client sends an EndOfEarlyData message to indicate a key change. This message is encrypted using the 0-RTT traffic keys.

A Server that receives an "early\_data" extension must act in one of the following three ways:

- Ignore the "early\_data" extension and return a normal 1-RTT response. The Server attempts to decrypt the received records using the handshake traffic key and ignores the early data. Records that fail to decrypt are discarded (subject to the configured max\_early\_data\_size). Once a record is successfully decrypted, the Server treats it as the start of the Client's second flight and processes it as ordinary 1-RTT data.


- Request that the Client send another ClientHello by responding with a HelloRetryRequest. The Client must not include the "early\_data" extension in this ClientHello. The Server ignores the early data by skipping all records with an outer content type of "application\_data" (indicating that they are encrypted), again subject to the configured max\_early\_data\_size.

- Return its own "early\_data" extension in EncryptedExtensions, indicating that it is prepared to process early data. The Server cannot accept only part of the early data messages. Even if the Server sends a message accepting early data, the early data may in fact already have been in flight when the Server generated that message.

To accept early data, the Server must have accepted the PSK cipher suite and selected the first key offered in the Client's "pre\_shared\_key" extension. In addition, the Server needs to verify that the following values match the values associated with the selected PSK:

- TLS version
- Selected cipher suite
- Selected ALPN protocol, if one was selected

These requirements are a superset of what is required to perform a 1-RTT handshake using the associated PSK. For externally established PSKs, the associated values are the values provided along with the key. For PSKs established via a NewSessionTicket message, the associated values are the values negotiated on the connection during which the ticket was established.

Future extensions must define their interaction with 0-RTT.


If any check fails, the Server must not include the extension in its response, and must use one of the first two mechanisms listed above, discarding all first-flight data (thereby falling back to 1-RTT or 2-RTT). If the Client attempts a 0-RTT handshake but the Server rejects it, the Server typically will not have 0-RTT record protection keys, and must find the first non-0-RTT message using trial decryption (with the 1-RTT handshake keys, or by looking for a plaintext ClientHello in the case of a HelloRetryRequest message).


If the Server chooses to accept the early\_data extension, then when processing early data records, the Server must follow the same criteria for processing all records (with the same specified error-handling requirements). In particular, if the Server cannot decrypt a record in an accepted "early\_data" extension, it must send a "bad\_record\_mac" alert message and abort the handshake.

If the Server rejects the "early\_data" extension, the Client application may choose to resend, after the handshake completes, the application data that was previously sent in early data. Note that automatic retransmission of early data may lead to incorrect assumptions about the connection state. For example, when the negotiated connection selects a different ALPN protocol from the one used for early data, the application may need to construct different messages. Similarly, if the early data assumed anything about the connection state, that content may be sent incorrectly after the handshake completes.


TLS implementations should not automatically resend early data; the application is well positioned to decide when to retransmit. Unless the negotiated connection selects the same ALPN protocol, a TLS implementation must not automatically resend early data.


### 11. Pre-Shared Key Extension

The "pre\_shared\_key" extension is used to negotiate the identity associated with the pre-shared key used for a given handshake.


The "extension\_data" field in this extension contains a PreSharedKeyExtension value:
```c
      struct {
          opaque identity<1..2^16-1>;
          uint32 obfuscated_ticket_age;
      } PskIdentity;

      opaque PskBinderEntry<32..255>;

      struct {
          PskIdentity identities<7..2^16-1>;
          PskBinderEntry binders<33..2^16-1>;
      } OfferedPsks;

      struct {
          select (Handshake.msg_type) {
              case client_hello: OfferedPsks;
              case server_hello: uint16 selected_identity;
          };
      } PreSharedKeyExtension;
```
- identity:  
	The label for the key. For example, a ticket or the label of an externally established pre-shared key.
	
- obfuscated\_ticket\_age:  
	An obfuscated version of the age of the key. [This section](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-ticket-age) describes how this value is generated for identities established via the NewSessionTicket message. For externally established identities, obfuscated\_ticket\_age should be set to 0, and the Server MUST ignore this value.


- identities:  
	The list of identities that the Client is willing to negotiate with the Server. If sent together with "early\_data", the first identity is used to identify 0-RTT.
	

- binders:  
	A sequence of HMAC values. Each value corresponds one-to-one with an entry in the identities list, in the same order.

- selected\_identity:  
	The identity selected by the Server, expressed as a zero-based index into the Client's list of identities.

Each PSK is associated with a single hash algorithm. For PSKs established via tickets, the hash algorithm is the KDF hash algorithm used when the ticket was established in the connection. For externally established PSKs, the hash algorithm MUST be set when the PSK is established; if it is not set, the default algorithm is SHA-256. The Server MUST ensure that the PSK it selects, if any, is compatible with the cipher suite.


In versions prior to TLS 1.3, the Server Name Identification (SNI) value was intended to be associated with the session. The Server was required to ensure that the SNI value associated with the session matched the SNI value specified in the resumption handshake. In practice, however, implementations and their use of the two supplied SNI values were inconsistent, which forced the Client to enforce the consistency requirement. **In TLS 1.3, the SNI value is always explicitly indicated in the resumption handshake, and the Server does not need to associate the SNI value with the ticket**. However, the Client needs to store the SNI together with the PSK in order to satisfy the requirements of [[Section 4.6.1]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message).


Note to implementers: session resumption is the primary use case for PSKs. The most straightforward way to implement the PSK/cipher suite matching requirement is to negotiate the cipher suite first, and then exclude any incompatible PSKs. Any unknown PSK (for example, one that is not in the PSK database, or one encoded with an unknown key) MUST be ignored. If no acceptable PSK can be found, the Server should perform a non-PSK handshake if possible. If backward compatibility is important, externally established PSKs offered by the Client should influence cipher suite selection.


Before accepting PSK key establishment, the Server MUST first verify the corresponding binder value (see [[Section 4.2.11.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-psk-binder)). If this value is absent or fails verification, the Server MUST abort the handshake immediately. The Server SHOULD NOT attempt to verify multiple binders; instead, it should select a single PSK and verify only the binder corresponding to that PSK. See [Appendix E.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Security_Properties.md#%E5%85%AD-psk-identity-exposure) and [[Section 8.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording) for the security rationale behind this requirement. To accept a connection established with a PSK, the Server sends the "pre\_shared\_key" extension indicating the identity it selected.


The Client MUST verify that the Server's selected\_identity is within the range provided by the Client. The cipher suite selected by the Server indicates the hash algorithm associated with the PSK, and if required by the ClientHello "psk\_key\_exchange\_modes", the Server should also send the "key\_share" extension. If these values are inconsistent, the Client MUST abort the handshake immediately with an "illegal\_parameter" alert message.


If the Server provides the "early\_data" extension, the Client MUST verify that the Server's selected\_identity is 0. If any other value is returned, the Client MUST abort the handshake with an "illegal\_parameter" alert message.


The "pre\_shared\_key" extension MUST be the last extension in ClientHello (this facilitates the implementation described below). The Server MUST check that it is the last extension; otherwise, it MUST abort the handshake with an "illegal\_parameter" alert message.


#### (1) Ticket Age


From the Client's perspective, the age of a ticket is the time elapsed from receipt of the NewSessionTicket message to the current moment. The Client MUST NOT use a ticket whose age is greater than the "ticket\_lifetime" indicated by the ticket itself. The "obfuscated\_ticket\_age" field in each PskIdentity MUST contain an obfuscated version of the ticket age. The obfuscation is computed by adding the ticket age (in milliseconds) to the "ticket\_age\_add" field, then taking the result modulo 2^32. Unless the ticket is reused, this obfuscation prevents passive observers of related connections from correlating them. Note that the "ticket\_lifetime" field in the NewSessionTicket message is in seconds, whereas "obfuscated\_ticket\_age" is in milliseconds. Because the ticket lifetime is limited to one week, 32 bits is sufficient to represent any reasonable duration, even in milliseconds.


#### (2) PSK Binder

The PSK binder value creates two bindings: one between the PSK and the current handshake, and another between the handshake in which the PSK was generated (if generated via a NewSessionTicket message) and the current handshake. Each entry in the binder list is computed as an HMAC over a partial transcript hash of ClientHello, ending with the PreSharedKeyExtension.identities field. In other words, the HMAC covers all of ClientHello except the binder list. If binders of the correct length are present, the message length fields (including the total length, the extension block length, and the length of the "pre\_shared\_key" extension) are all set.


A PskBinderEntry is computed in the same way as the Finished message. However, the BaseKey is the derived binder\_key, which is derived from the corresponding provided PSK.

If the handshake includes a HelloRetryRequest message, then the initial ClientHello and the HelloRetryRequest are included in the transcript together with the new ClientHello. For example, if the Client sends ClientHello, its binder is computed as follows:
```c
      Transcript-Hash(Truncate(ClientHello1))
```
The purpose of the Truncate() function is to remove the binders list from the ClientHello.

If the Server responds with a HelloRetryRequest, the Client will send ClientHello2, whose binder is computed as follows:
```c
      Transcript-Hash(ClientHello1,
                      HelloRetryRequest,
                      Truncate(ClientHello2))
```
The complete ClientHello1/ClientHello2 is included in the other handshake hash computations. Note that, in the first transmission, `Truncate(ClientHello1)` is hashed directly, whereas in the second transmission, ClientHello1 is hashed, and a "message\_hash" message is also injected.


#### (3) Processing Order

The Client is allowed to stream 0-RTT data until it receives the Server's Finished message. After the Client receives the Finished message, it needs to send an EndOfEarlyData message at the end of the handshake. To prevent deadlock, when the Server receives the "early\_data" message, it must immediately process the Client's ClientHello message and immediately respond with ServerHello, rather than waiting until it has received the Client's EndOfEarlyData message before sending ServerHello.


## III. Server Parameters


The Server's next two messages, EncryptedExtensions and CertificateRequest, contain messages from the Server, and this Server determines the remainder of the handshake. These messages are encrypted using keys derived from server\_handshake\_traffic\_secret.


### 1. Encrypted Extensions


In all handshakes, the Server must send the EncryptedExtensions message immediately after the ServerHello message. This is the first message encrypted under keys derived from server\_handshake\_traffic\_secret.

The EncryptedExtensions message contains extensions that should be protected. That is, any extension that does not need to establish an encryption context but is not associated with individual certificates. The Client must check whether any prohibited extensions are present in the EncryptedExtensions message; if any prohibited extension is found, it must immediately abort the handshake with an "illegal\_parameter" alert message.
```c
   Structure of this message:

      struct {
          Extension extensions<0..2^16-1>;
      } EncryptedExtensions;
```
- extensions:   
	List of extensions。


### 2. Certificate Request

A Server that uses certificates for authentication may optionally request a certificate from the Client. This request message (if sent) must follow the EncryptedExtensions message.

Message structure:
```c
      struct {
          opaque certificate_request_context<0..2^8-1>;
          Extension extensions<2..2^16-1>;
      } CertificateRequest;
```
- certificate_request_context:  
	An opaque string used to identify the certificate request and echoed in the Client's Certificate message. certificate\_request\_context must be unique within this connection (thereby preventing replay attacks against the Client's CertificateVerify). This field is typically zero length, except when used for the post-handshake authentication exchange described in [[4.6.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-post-handshake-authentication). When requesting post-handshake authentication, the Server should send an unpredictable context to the Client (for example, generated with a random number) to prevent attackers from compromising it. An attacker could precompute valid CertificateVerify messages and thereby gain access to the temporary Client private key.


- extensions:  
	A set of extensions describing the parameters required for the requested certificate. The "signature\_algorithms" extension must be specified; if other extensions are defined for this message, those extensions may also be optionally included. The Client must ignore any extensions it does not recognize.


In versions prior to TLS 1.3, the CertificateRequest message carried a list of signature algorithms and a list of certificate authorities acceptable to the Server. In TLS 1.3, the signature algorithm list can be represented by the "signature\_algorithms" extension and the optional "signature_algorithms_cert" extension. The latter certificate authority list can be represented by sending the "certificate\_authorities" extension.


Servers authenticated via PSK cannot send a CertificateRequest message in the main handshake, but they may send a CertificateRequest message during post-handshake authentication, provided that the Client has sent the "post\_handshake\_auth" extension.


## IV. Authentication Messages

As discussed in [section-2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3.md#%E4%BA%94tls-13-%E5%8D%8F%E8%AE%AE%E6%A6%82%E8%A7%88), TLS uses a common set of messages for authentication, key confirmation, and handshake integrity: Certificate, CertificateVerify, and Finished. (PSK binders also provide key confirmation in a similar way.) These three messages are always the final three messages in the handshake. The Certificate and CertificateVerify messages, as described below, are sent only in certain cases. The Finished message is always sent as part of the authentication block. These messages are encrypted using keys derived from sender\_handshake\_traffic\_secret.

Authentication message computation consistently uses the following inputs:

- The certificate and signing key to use
- The handshake context, consisting of a set of messages in a copy of the hash
- The Base key used to compute the MAC key

Based on these inputs, the messages contain:

- Certificate:  
  The certificate used for authentication and any supporting certificates in the chain. Note that certificate-based Client authentication is not available in PSK handshake flows (including 0-RTT).

- CertificateVerify:   
  A signature derived from the value of Transcript-Hash(Handshake Context, Certificate).

- Finished:   
  A MAC derived from the value of Transcript-Hash(Handshake Context, Certificate, CertificateVerify). The MAC value is computed using the MAC key derived from the Base key.

For each scenario, the following table defines the handshake context and the MAC Base Key.
```c
   +-----------+-------------------------+-----------------------------+
   | Mode      | Handshake Context       | Base Key                    |
   +-----------+-------------------------+-----------------------------+
   | Server    | ClientHello ... later   | server_handshake_traffic_   |
   |           | of EncryptedExtensions/ | secret                      |
   |           | CertificateRequest      |                             |
   |           |                         |                             |
   | Client    | ClientHello ... later   | client_handshake_traffic_   |
   |           | of server               | secret                      |
   |           | Finished/EndOfEarlyData |                             |
   |           |                         |                             |
   | Post-     | ClientHello ... client  | client_application_traffic_ |
   | Handshake | Finished +              | secret_N                    |
   |           | CertificateRequest      |                             |
   +-----------+-------------------------+-----------------------------+
```

### 1. The Transcript Hash

Many cryptographic computations in TLS use a copy of the hash. This value is computed by hashing the concatenation of each included handshake message, including the handshake message type and length fields carried in the handshake message header, but excluding the record layer header. For example:
```c
Transcript-Hash(M1, M2, ... Mn) = Hash(M1 || M2 || ... || Mn)
```
As an exception to this general rule, when the Server responds to a ClientHello message with a HelloRetryRequest message, the value of ClientHello1 is replaced by a special synthetic handshake message whose handshake type is "message\_hash" and which contains Hash(ClientHello1). For example:
```c
  Transcript-Hash(ClientHello1, HelloRetryRequest, ... Mn) =
      Hash(message_hash ||        /* Handshake type */
           00 00 Hash.length  ||  /* Handshake message length (bytes) */
           Hash(ClientHello1) ||  /* Hash of ClientHello1 */
           HelloRetryRequest  || ... || Mn)
```
The reason for designing this structure is to allow the Server to perform a stateless HelloRetryRequest by storing only the hash of ClientHello1 in the cookie, rather than requiring it to export the entire intermediate hash state.

Specifically, the hash copy is always taken over the following sequence of handshake messages, starting with the first ClientHello and including only messages that have been sent: ClientHello, HelloRetryRequest, ClientHello, ServerHello, EncryptedExtensions, server CertificateRequest, server Certificate, server CertificateVerify, server Finished, EndOfEarlyData, client Certificate, client CertificateVerify, client Finished.

In general, implementations can create the hash copy as follows: maintain a running hash copy based on the negotiated hash. Note that subsequent post-handshake authentication does not include each other, but only the messages up to the end of the main handshake.


### 2. Certificate

This message sends the endpoint's certificate chain to the peer.

Whenever the agreed key exchange method uses certificates for authentication (this includes all key exchange methods defined in this document other than PSK), the Server MUST send a Certificate message.

The Client MUST send a Certificate message if and only if the Server requests Client authentication by sending a CertificateRequest message.


If the Server requests Client authentication but no suitable certificate is available, the Client MUST send a Certificate message containing no certificates (for example, with a "certificate\_list" field of length 0). The Finished message MUST be sent regardless of whether the Certificate message is empty.

The structure of the Certificate message is:
```c
      enum {
          X509(0),
          RawPublicKey(2),
          (255)
      } CertificateType;

      struct {
          select (certificate_type) {
              case RawPublicKey:
                /* From RFC 7250 ASN.1_subjectPublicKeyInfo */
                opaque ASN1_subjectPublicKeyInfo<1..2^24-1>;

              case X509:
                opaque cert_data<1..2^24-1>;
          };
          Extension extensions<0..2^16-1>;
      } CertificateEntry;

      struct {
          opaque certificate_request_context<0..2^8-1>;
          CertificateEntry certificate_list<0..2^24-1>;
      } Certificate;
```
- certificate\_request\_context:  
	If this message is in response to a CertificateRequest message, the value of certificate\_request\_context in this message is nonzero. Otherwise (in the case of Server authentication), this field MUST be zero length.


- certificate\_list:  
	This is a sequence (chain) of CertificateEntry structures, each containing a single certificate and a set of extensions.

- extensions:  
	A set of extension values for the CertificateEntry. The format of "Extension" is defined in [[Section 4.2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions). Valid extensions include the OCSP status extension [[RFC6066]](https://tools.ietf.org/html/rfc6066) and the SignedCertificateTimestamp [[RFC6962]](https://tools.ietf.org/html/rfc6962) extension. New extensions may be defined for this message in the future. Extensions in the Server's Certificate message MUST correspond to extensions in the ClientHello message. Extensions in the Client's Certificate message MUST correspond to extensions in the Server's CertificateRequest message. If an extension applies to the entire chain, it SHOULD be included in the first CertificateEntry.
	

If no corresponding certificate type extension ("server\_certificate\_type" or "client\_certificate\_type") was negotiated in EncryptedExtensions, or if the X.509 certificate type was negotiated, then each CertificateEntry contains a DER-encoded X.509 certificate. The sender's certificate MUST be in the first CertificateEntry in the list. Each subsequent certificate SHOULD directly certify the one immediately preceding it. Because certificate validation requires trust anchors to be distributed independently, the certificate that specifies the trust anchor MAY be omitted from the chain (provided that supported peers are known to possess the certificate that may be omitted).
	
Note: In versions prior to TLS 1.3, the ordering of "certificate\_list" required each certificate to certify the certificate immediately preceding it; however, some implementations allowed some flexibility. Servers sometimes send both current and deprecated intermediates for transition purposes, and other configurations are incorrect, but these cases can still validate correctly. For maximum compatibility, all implementations SHOULD be prepared to handle certificates that may be irrelevant and arbitrary ordering across TLS versions, but the end-entity certificate (the first certificate in the ordered sequence) MUST be first.

If the RawPublicKey certificate type was negotiated, then certificate\_list MUST contain no more than one CertificateEntry, and that CertificateEntry contains the ASN1\_subjectPublicKeyInfo value defined in [[RFC7250], Section 3](https://tools.ietf.org/html/rfc7250#section-3).
	

The OpenPGP certificate type is prohibited in TLS 1.3.

The Server's certificate\_list MUST always be non-empty. If the Client has no appropriate certificate to send in response to the Server's authentication request, it sends an empty certificate\_list.

#### (1) OCSP Status and SCT Extensions

[[RFC6066]](https://tools.ietf.org/html/rfc6066) and [[RFC6961]](https://tools.ietf.org/html/rfc6961) define extensions for negotiating that the Server sends OCSP responses to the Client. In TLS 1.2 and earlier, the Server replies with an empty extension to indicate negotiation of this extension, and carries OCSP information in the CertificateStatus message. In TLS 1.3, the Server's OCSP information is carried in an extension in the CertificateEntry that contains the relevant certificate. Specifically, the body of the "status\_request" extension from the Server MUST be the CertificateStatus structure defined in [[RFC6066]](https://tools.ietf.org/html/rfc6066) and [[RFC6960]](https://tools.ietf.org/html/rfc6960), respectively.


Note: The status\_request\_v2 extension [[RFC6961]](https://tools.ietf.org/html/rfc6961) has been deprecated, and TLS 1.3 cannot process ClientHello messages based on its presence or its contents. In particular, sending the status\_request\_v2 extension in EncryptedExtensions, CertificateRequest, and Certificate messages is prohibited. TLS 1.3 Servers MUST be able to handle ClientHello messages that contain it, because such messages may be sent by Clients that want to use it with earlier protocol versions.


The Server MAY request that the Client provide an OCSP response for its certificate by sending an empty "status\_request" extension in its CertificateRequest message. If the Client elects to send an OCSP response, the body of its "status\_request" extension MUST be the CertificateStatus structure defined in [[RFC6966]](https://tools.ietf.org/html/rfc6966).


Similarly, [[RFC6962]](https://tools.ietf.org/html/rfc6962) provides a mechanism for Servers to send Signed Certificate Timestamps (SCTs) in ServerHello in TLS 1.2 and earlier. In TLS 1.3, the Server's SCT information is carried in an extension in the CertificateEntry.


#### (2) Server Certificate Selection

The following rules apply to certificates sent by the Server:

- The certificate type MUST be X.509v3 [[RFC5280]](https://tools.ietf.org/html/rfc5280), unless explicitly negotiated otherwise (for example, [[RFC5081]](https://tools.ietf.org/html/rfc5081)).

- The public key (and associated restrictions) in the Server's end-entity certificate MUST be compatible with the selected authentication algorithm in the Client's "signature\_algorithms" extension (currently RSA, ECDSA, or EdDSA).

- The certificate MUST allow the key to be used for signing (that is, if the key usage extension is present, the digitalSignature bit MUST be set), and MUST indicate a signature scheme in the Client's "signature\_algorithms"/"signature\_algorithms\_cert" extension.


- The "server\_name" [[RFC6066]](https://tools.ietf.org/html/rfc6066) and "certificate\_authorities" extensions are used to guide certificate selection. Because the Server may require the "server\_name" extension to be present, the Client SHOULD send this extension when applicable.

If the Server can provide a certificate chain, all certificates in the Server's chain MUST be signed using signature algorithms provided by the Client. Self-signed certificates or certificates intended to be trust anchors are not validated as part of the chain, and therefore may be signed using any algorithm.


If the Server cannot produce a certificate chain signed only with the indicated supported algorithms, it SHOULD continue the handshake by sending the Client a certificate chain of its choice, which may include algorithms that the Client is not known to support. This fallback chain MAY use the deprecated SHA-1 hash algorithm only if permitted by the Client; otherwise, use of the SHA-1 hash algorithm MUST be prohibited.


If the Client cannot construct an acceptable certificate chain using the provided certificates, it MUST abort the handshake. It aborts the handshake and sends a certificate-related alert message (by default, the "unsupported\_certificate" alert message).


If the Server has multiple certificates, it selects one according to the criteria above (in addition to other criteria, such as the transport-layer endpoint, local configuration, and preferences).


#### (3) Client Certificate Selection

The following rules apply to certificates sent by the Client:

- The certificate type MUST be X.509v3 [[RFC5280]](https://tools.ietf.org/html/rfc5280), unless explicitly negotiated otherwise (for example, [[RFC5081]](https://tools.ietf.org/html/rfc5081)).

- If the "certificate\_authorities" extension in the CertificateRequest message is non-empty, at least one certificate in the certificate chain SHOULD have been issued by one of the listed CAs.

- The certificate MUST be signed using an acceptable signature algorithm, as described in Section 4.3.2. Note that this relaxes the constraints on certificate signature algorithms found in previous versions of TLS.

- If the CertificateRequest message contains a non-empty "oid\_filters" extension, the end-entity certificate MUST match an extension OID recognized by the Client, as described in Section 4.2.5.


#### (4) Receiving a Certificate Message


In general, detailed certificate validation procedures are outside the scope of TLS (see [[RFC5280]](https://tools.ietf.org/html/rfc5280)). This section provides TLS-specific requirements.

If the Server provides an empty Certificate message, the Client MUST abort the handshake with a "decode\_error" alert message.

If the Client does not send any certificates (that is, it sends an empty Certificate message), the Server may decide whether to continue the handshake without Client authentication or abort the handshake with a "certificate\_required" alert message. In addition, if some aspect of the certificate chain is unacceptable (for example, it is not signed by a known trusted CA), the Server may decide whether to continue the handshake (considering the Client unauthenticated) or abort the handshake.

Any endpoint that receives any certificate that would require verification using the MD5 hash with any signature algorithm MUST abort the handshake with a "bad\_certificate" alert message. SHA-1 is deprecated, and it is recommended that any endpoint receiving any certificate that would require verification using the SHA-1 hash with any signature algorithm abort the handshake with a "bad\_certificate" alert message. For clarity, this means that endpoints may accept these algorithms for certificates that are self-signed or are trust anchors.


It is recommended that all endpoints transition to SHA-256 or better algorithms as soon as possible to maintain interoperability with implementations that are currently phasing out SHA-1 support.


Note that a certificate containing a key for one signature algorithm may be signed using a different signature algorithm (for example, an RSA key signed with an ECDSA key).


### 3. Certificate Verify

This message is used to provide explicit evidence that an endpoint possesses the private key corresponding to its certificate. The CertificateVerify message also provides integrity for the handshake up to this point. The Server MUST send this message when authenticating with a certificate. The Client MUST send this message whenever it authenticates with a certificate (that is, when the Certificate message is non-empty). When sent, this message MUST appear immediately after the Certificate message and immediately before the Finished message.
The struct for this message is:
```c
      struct {
          SignatureScheme algorithm;
          opaque signature<0..2^16-1>;
      } CertificateVerify;
```
The algorithm field specifies the signature algorithm to use (see Section 4.2.3 for the definition of this type). The signature field is the digital signature produced using that algorithm. The content covered by the signature is the hash output described in Section 4.4.1, namely:
```c
      Transcript-Hash(Handshake Context, Certificate)
```
Computing the digital signature is a concatenated computation over:

- A string consisting of octet 32 (0x20) repeated 64 times
- The context string
- A single 0 byte used as a separator
- The content to be signed

This structure is designed to prevent attacks against earlier versions of TLS, where the ServerKeyExchange format meant that an attacker could obtain a signature over a message with a chosen 32-byte prefix (ClientHello.random). The initial 64-byte padding clears the prefix in the server-controlled ServerHello.random.

The context string for the Server signature is "TLS 1.3, Server CertificateVerify". The context string for the Client signature is "TLS 1.3, Client CertificateVerify". It is used to provide separation between signatures in different contexts, helping defend against potential cross-protocol attacks.

For example, if the hash copy is 32 bytes of 01 (a length that makes sense for SHA-256), the content covered by the digital signature for the Server’s CertificateVerify would be:
```c
      2020202020202020202020202020202020202020202020202020202020202020
      2020202020202020202020202020202020202020202020202020202020202020
      544c5320312e332c207365727665722043657274696669636174655665726966
      79
      00
      0101010101010101010101010101010101010101010101010101010101010101
```
At the sender, the procedure for computing the signature field of the CertificateVerify message takes as input:

- The content covered by the digital signature

- The private signing key corresponding to the certificate sent in the previous message


If the CertificateVerify message is sent by the Server, the signature algorithm MUST be one offered in the Client's "signature\_algorithms" extension, unless a valid certificate chain cannot be produced without using an unsupported algorithm (i.e., unless none of the currently supported algorithms can produce a valid certificate chain).

If it is sent by the Client, the signature algorithm used in the signature MUST be one of the signature algorithms present in the supported\_signature\_algorithms field of the "signature\_algorithms" extension in the CertificateRequest message.

In addition, the signature algorithm MUST be compatible with the key in the sender's end-entity certificate. RSA signatures MUST use the RSASSA-PSS algorithm, regardless of whether the RSASSA-PKCS1-v1\_5 algorithm appears in "signature\_algorithms". SHA-1 algorithms are prohibited for any signature in a CertificateVerify message.

All SHA-1 signature algorithms in this specification are defined only for legacy certificates and are not valid for CertificateVerify signatures.

The recipient of a CertificateVerify message MUST verify the signature field. The verification process takes as input:

- The content covered by the digital signature

- The public key contained in the end-entity certificate found in the associated Certificate message

- The digital signature received in the signature field of the CertificateVerify message

If verification fails, the receiver MUST terminate the handshake with a "decrypt\_error" alert.


### 4. Finished


The Finished message is the final message in the authentication block. It plays a critical role in authenticating the handshake and the computed keys.

The recipient of a Finished message MUST verify that its contents are correct; if they are not, it MUST terminate the connection with a "decrypt\_error" alert message.

Once an endpoint has sent its Finished message and has received and verified the Finished message from its peer, it can begin sending and receiving application data over the connection. There are two settings that allow data to be sent before receiving the peer's Finished:

1. As described in [Section 4.2.10](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#10-early-data-indication), the Client can send 0-RTT data.
2. The Server can send data after the first flight, but because the handshake has not yet completed, there is no guarantee of the peer's identity or even that the peer is still online. (The ClientHello might be replayed.)

The key used to compute the Finished message is derived using HKDF from the Base Key defined in Section 4.4 (see Section 7.1). Specifically:
```c
   finished_key =
       HKDF-Expand-Label(BaseKey, "finished", "", Hash.length)
```
The data structure of this message is:
```c
      struct {
          opaque verify_data[Hash.length];
      } Finished;
```
verify\_data is computed as follows:
```c
      verify_data =
          HMAC(finished_key,
               Transcript-Hash(Handshake Context,
                               Certificate*, CertificateVerify*))

      * Only included if present.
```
HMAC [[RFC2104]](https://tools.ietf.org/html/rfc2104) uses the hash algorithm for the handshake. As described above, the HMAC input is typically implemented using a running hash; that is, at this point it is just the handshake hash.

In previous versions of TLS, the length of verify\_data was always 12 octets. In TLS 1.3, it is the size of the HMAC output used to represent the handshake hash.

**Note: Alerts and any other non-handshake record types are not handshake messages and are not included in the hash computation**.

Any records after the Finished message MUST be encrypted under the appropriate client\_application\_traffic\_secret\_N, as described in Section 7.2. In particular, this includes any alert sent by the server in response to the client's Certificate and CertificateVerify messages.


### 5. End of Early Data
```c
      struct {} EndOfEarlyData;
```
If the Server sends the "early\_data" extension in EncryptedExtensions, the Client must send an EndOfEarlyData message after receiving the Server's Finished message. If the Server does not send the "early\_data" extension in EncryptedExtensions, the Client must never send an EndOfEarlyData message. This message indicates that all 0-RTT application\_data messages (if any) have been transmitted, and that subsequent records are protected with the handshake traffic keys. The Server must not send this message; if the Client receives it, it must terminate the connection with an "unexpected\_message" alert. This message is encrypted and protected using keys derived from client\_early\_traffic\_secret.


### 6. Post-Handshake Messages


TLS also allows additional messages to be sent after the main handshake. These messages use the handshake content type and are encrypted with the appropriate application traffic keys.


#### (1) New Session Ticket Message

At any time after the Server has received the Client's Finished message, it may send a NewSessionTicket message. This message creates a unique association between the ticket value and the PSK derived from the resumption master secret.


If the Client includes the "pre\_shared\_key" extension in its ClientHello message and includes the ticket in that extension, the Client may use the PSK in a future handshake. The Server may send multiple tickets on a single connection, either immediately one after another or after some specific event. For example, the Server might send a new ticket after post-handshake authentication to encapsulate additional Client authentication state. Multiple tickets can be used by the Client for various purposes, such as:

- Opening multiple parallel HTTP connections

- Racing connections across interfaces and address families via, for example, Happy Eyeballs [[RFC8305]](https://tools.ietf.org/html/rfc8305) or related techniques


Any ticket must only be used to resume a session with a cipher suite that uses the same KDF hash algorithm as the one used to establish the original connection.

The Client must resume only when the new SNI value is valid for the Server certificate provided in the original session, and should resume only when the SNI value matches the SNI value used in the original session. The latter is a performance optimization: in general, there is no reason to expect different Servers covered by a single certificate to accept each other's tickets; therefore, attempting session resumption in this case would waste a single-use ticket. If such an indication is provided (externally or by any other means), the Client may be able to resume the session with a different SNI value.


When resuming a session, if the SNI value is reported to the calling application, the implementation must use the value sent in the resumption ClientHello rather than the value sent in the previous session. Note that if the Server implementation rejects all PSK identities with different SNI values, these two values are always the same.

Note: Although the resumption master secret depends on the Client's second flight, a Server that does not request Client authentication can independently compute the remainder of the transcript hash and then send a NewSessionTicket immediately after sending its Finished message, rather than waiting for the Client's Finished message. This may be appropriate when the Client needs to open multiple TLS connections in parallel and can benefit from reducing the overhead of resumption handshakes.
```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```
- ticket\_lifetime：  
	This field indicates the lifetime of the ticket, in seconds, represented as a 32-bit unsigned integer in network byte order, measured from the time the ticket is issued. The Server MUST NOT use any value greater than 604800 seconds (7 days). A value of zero indicates that the ticket should be discarded immediately. Regardless of ticket\_lifetime, the Client MUST NOT cache a ticket for more than 7 days, and may delete the ticket earlier according to local policy. The Server may treat the ticket as valid for a shorter period than the period specified in ticket\_lifetime.

- ticket\_age\_add:   
	A securely generated random 32-bit value used to obfuscate the age of the ticket included by the Client in the "pre\_shared\_key" extension. The Client adds this value to the ticket age modulo 2 ^ 32 to compute the value it transmits. The Server MUST generate a fresh value for each ticket it issues.

- ticket\_nonce:  
	A per-ticket value that is unique across all tickets issued in this connection.

- ticket:  
	This value is used as the PSK identity. The ticket itself is an opaque label. It may be a database lookup key, or it may be a self-encrypted and self-authenticated value.

- extensions：  
	A set of extension values for the ticket. The extension format is defined in Section 4.2. The Client MUST ignore unrecognized extensions.
	
The only extension currently defined for NewSessionTicket is "early\_data", which indicates that the ticket can be used to send 0-RTT data (Section 4.2.10). It contains the following value:

- max\_early\_data\_size:    
	This field indicates the maximum amount of 0-RTT data (in bytes) that the Client is allowed to send when using the ticket. The amount counts only the application data payload (that is, the plaintext, excluding padding and the inner content type byte). If the Server receives 0-RTT data whose size exceeds max\_early\_data\_size bytes, it should immediately terminate the connection with an "unexpected\_message" alert. Note that a Server that rejects early data due to lack of cryptographic material will not be able to distinguish padding from content, so the Client should not rely on being able to send a large amount of padding in early data records.


The ticket associated with the PSK is computed as follows:
```c
       HKDF-Expand-Label(resumption_master_secret,
                        "resumption", ticket_nonce, Hash.length)
```
Because the `ticket_nonce` value is different for each NewSessionTicket message, each ticket derives a different PSK.

Note that, in principle, new tickets can continue to be issued, indefinitely extending the lifetime of the keying material originally derived from the initial non-PSK handshake (most likely associated with the peer certificate).
 

Implementations are advised to impose an overall lifetime limit on such keying material. These limits should take into account the lifetime of the peer certificate, the possibility of intervening revocation, and the time elapsed since the peer’s online CertificateVerify signature.


#### (2) Post-Handshake Authentication

When the Client has sent the "post_handshake_auth" extension (see Section 4.2.6), the Server may request client authentication at any time after the handshake completes by sending a CertificateRequest message. The Client must respond with the appropriate authentication messages (see Section 4.4). If the Client chooses to authenticate, it must send Certificate, CertificateVerify, and Finished messages. If the Client declines authentication, it must send a Certificate message containing no certificates, followed by a Finished message. All Client messages in response to the Server must appear consecutively on the wire, with no other types of messages interleaved.


A Client that receives a CertificateRequest message without having sent the "post_handshake_auth" extension must send an "unexpected_message" alert.


Note: Because Client authentication may involve prompting the user, the Server must be prepared for some delay, including receiving an arbitrary number of other messages between sending CertificateRequest and receiving the response. In addition, if the Client receives multiple CertificateRequest messages in succession, it may respond to them in an order different from the order in which they were received (the certificate_request_context value allows the server to disambiguate the responses).


#### (3) Key and Initialization Vector Update

The KeyUpdate handshake message is used to indicate that the sender is updating its own sending encryption keys. Either peer may send this message after sending its Finished message. An implementation that receives a KeyUpdate message before receiving the Finished message must terminate the connection with an "unexpected_message" alert. After sending a KeyUpdate message, the sender should send all of its traffic using the next generation of keys, computed as described in Section 7.2. Upon receiving a KeyUpdate, the receiver must update its receiving keys.
```c
      enum {
          update_not_requested(0), update_requested(1), (255)
      } KeyUpdateRequest;

      struct {
          KeyUpdateRequest request_update;
      } KeyUpdate;
```
- request\_update:  
	This field indicates whether the recipient of the KeyUpdate should respond with its own KeyUpdate. If an implementation receives any other value, it MUST terminate the connection with an "illegal\_parameter" alert.
	

If the request\_update field is set to "update\_requested", the recipient MUST send its own KeyUpdate, with request\_update set to "update\_not\_requested", before sending its next application data record. This mechanism allows either side to force an update of the entire connection, but causes an implementation that receives multiple KeyUpdates while it is silent to respond with a single update. Note that an implementation may receive any number of messages between sending a KeyUpdate (with request\_update set to "update\_requested") and receiving the peer's KeyUpdate, because those messages may already have been in transit. However, because the sending and receiving keys are derived from independent traffic keys, retaining the receiving traffic keys does not affect the forward secrecy of data sent before the sender changed keys.


If implementations independently send their own KeyUpdates with request\_update set to "update\_requested" and their messages cross in transit, both sides will respond and both sides will update their keys.


Both the sender and the receiver MUST encrypt their KeyUpdate messages with the old keys. In addition, before accepting any message encrypted with the new keys, both sides MUST enforce receipt of a KeyUpdate encrypted with the old keys. Failure to do so may enable message truncation attacks.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Handshake\_Protocol/](https://halfrost.com/tls_1-3_handshake_protocol/)