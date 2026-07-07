# HTTPS Refresher (VI) — Extensions in TLS

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_0.png'>
</p>

Extensions are an important topic in TLS. They allow the Client and Server to gain new capabilities without upgrading TLS itself. The official documentation for extensions is defined in [[RFC 6066]](https://tools.ietf.org/html/rfc6066). **Extensions are like a set of horizontally extensible plugins in TLS**.

The Client declares multiple Extensions it supports in ClientHello, indicating to the Server that it has these capabilities, or using them to negotiate certain protocols with the Server. After receiving ClientHello, the Server parses the Extensions in order. For some Extensions, if an immediate response is required, the Server responds in ServerHello. For others that do not require a response, or Extensions the Server does not support, the Server simply does not respond and ignores them.

Extensions in the TLS handshake have the following characteristics:

- Extensions do not affect whether the TLS handshake succeeds. If the Server does not support some Extensions in ClientHello, it can simply ignore them; this does not affect the handshake flow.

- Extensions returned by the Server in ServerHello must be a subset of the Extensions in ClientHello (less than or equal to it). ServerHello must not contain any Extension that did not appear in ClientHello. If a Client receives an extension type in ServerHello that it did not request in the corresponding ClientHello, it must abort the handshake with a fatal unsupported\_extension alert message.

- When multiple extensions of different types are present in ClientHello or ServerHello, these extensions may appear in any order. A given type must not have more than one extension.

- All Extensions must account for session resumption scenarios to ensure security.

> "Server-oriented" extensions may be provided in TLS in the future. Such an extension (for example, an extension of type X) might require the Client to first send an extension of type X in ClientHello, with extension\_data empty to indicate that it supports the extension type. In this example, the Client provides the ability to understand the extension type, and the Server communicates with it based on what the Client provides.


In this article, I intend to compare extensions in the TLS 1.2 and TLS 1.3 handshakes.

## I. Extensions in the TLS 1.2 Handshake

Many Extensions are defined in [[RFC 6066]](https://tools.ietf.org/html/rfc6066), and these Extensions are basically all used in TLS 1.2.

| Extension Type Name | Extension Type Number | Usage in TLS 1.3 | Recommended | RFC Reference |
| :----: | :----: | :----: |  :----: |  :----: |
| server_name |  0 |CH, EE	 | ✅ | RFC 6066 |
| max\_fragment\_length | 1 | CH, EE	 | ❌ | RFC 6066 |
| client\_certificate\_url | 2 |  | ✅ | RFC 6066 |
| trusted\_ca\_keys | 3 | | ✅ | RFC 6066 |
| truncated\_hmac | 4  | | ❌ | RFC 6066 | 
| status\_request | 5 | CH, CR, CT | ✅ | RFC 6066 |
| user\_mapping | 6 |  | ✅ | RFC 4681 |
| client\_authz | 7 |  | ❌ | RFC 5878 |
| server\_authz | 8 |  | ❌ | RFC 5878 |
| cert\_type | 9 |  | ❌ | RFC 6091 |
| supported\_groups(renamed from "elliptic_curves") | 10 | CH, EE | ✅ |  RFC 7919 |
| ec\_point\_formats | 11 | | ✅ | RFC 8422 |
| srp | 12 | | ❌ | RFC 5054 |
| signature\_algorithms | 13 | CH, CR | ✅ | RFC 5246 |
| use\_srtp | 14 | CH, EE | ✅ | RFC 5764 |
| heartbeat | 15 | CH, EE | ✅ | RFC 6520 |
| application\_layer\_protocol\_negotiation | 16 | CH, EE | ✅ | RFC 7301 |
| status\_request\_v2	 | 17 |  | ✅ | RFC 6961 |
| signed\_certificate\_timestamp | 18 |CH, CR, CT|❌|  RFC 6962 |
| client\_certificate\_type | 19 | CH, EE | ✅ | RFC7250 |
| server\_certificate\_type | 20 | CH, EE | ✅ | RFC7250 |
| padding | 21 |	CH	| ✅ |  RFC7685 |
| encrypt\_then\_mac | 22 | |✅ | RFC7366 |
| extended\_master\_secret | 23 | | ✅ | RFC 7627 |
| token\_binding	| 24 | |✅ | RFC8472 |
| cached\_info | 25 | 	| ✅	 | RFC7924 |
| tls\_lts | 26 |  | ❌	|  draft-gutmann-tls-lts |
| compress\_certificate (TEMPORARY - registered 2018-05-23, expires 2019-05-23) | 27 | CH, CR | ✅ | draft-ietf-tls-certificate-compression|
| record\_size\_limit | 28 |  CH, EE | ✅ | RFC8449|
| pwd\_protect | 29 |	CH	 | ❌	| RFC-harkins-tls-dragonfly-03 |
| pwd\_clear | 30 |	CH	| ❌|RFC-harkins-tls-dragonfly-03|
| password\_salt | 31 |	CH, SH, HRR|❌|RFC-harkins-tls-dragonfly-03|
| Unassigned	| 32 | | ❌ | |
| Unassigned	| 33 | | ❌ | | 
| Unassigned	| 34 | | ❌ |	 |	
| session\_ticket (renamed from "SessionTicket TLS") | 35 | | ✅ | RFC 4507 |
| Unassigned	| 36 | | ❌ |	 |	
| Unassigned	| 37 | | ❌ |	 |	
| Unassigned	| 38 | | ❌ |	 |	
| Unassigned	| 39 | | ❌ |	 |	
| Unassigned	| 40 | | ❌ |	 |	
| Unassigned	| 52-65279 | | ❌ |	 |		
| renegotiation\_info | 65281 | |✅ |  RFC 5746 |

> Abbreviation notes: CH: ClientHello, SH: ServerHello, CR: CertificateRequest, EE:EncryptedExtensions, HRR: HelloRetryRequest, CT: Certificate

The Extensions above also have corresponding ExtensionTypes. Here are only some commonly used ExtensionTypes, not all of them:  
```c
      enum {
          server_name(0), 
          max_fragment_length(1),
          client_certificate_url(2), 
          trusted_ca_keys(3),
          truncated_hmac(4), 
          status_request(5), 
          supported_groups(10),
          ec_point_formats(11),
          signature_algorithms(13),
          application_layer_protocol_negotiation(16),
          signed_certificate_timestamp(18),
          extended_master_secret(23),
          SessionTicket TLS(35),
          renegotiation_info(65281)
          (65535)
      } ExtensionType;
```
The data structure of each Extension is as follows:  
```c
      struct {
          ExtensionType extension_type;
          opaque extension_data<0..2^16-1>;
      } Extension;
```
An Extension consists of both `extension_type` and `extension_data`. Some Extensions do not have `extension_data`. Therefore, `extension_type` occupies 2 bytes, followed by `extension_data`, which is a variable-length field of <0..2^16-1>.


Typically, the specification for each extension type needs to describe the extension’s impact on the entire handshake flow and on session resumption. Most current TLS extensions are relevant only when a session is initialized: when an old session is resumed, the Server does not process the extensions in the Client Hello, nor does it include them in the Server Hello. However, some extensions can specify different behavior during session resumption.

There can be sensitive (and less sensitive) interactions between new features in this protocol and existing features, which may significantly reduce overall security. The following considerations should be taken into account when designing new extensions:

-  In some cases, it is an error if the Server does not negotiate an extension; in other cases, it is simply a refusal to support a particular feature. In general, an error alert should be used for the former, while a field in the Server extension should be used to respond to the latter.

-  Extensions should be designed, as much as possible, to prevent any attack that forces the use (or non-use) of a particular feature by manipulating handshake messages. This principle should be followed regardless of whether the feature is known to cause security issues. Extension fields are typically included in the hash input of the Finished message, but great care must be taken when an extension changes the meaning of messages sent during the handshake phase. Designers and implementers should be aware that, because the handshake is authenticated only later, an active attacker can modify messages and insert, move, or replace extensions.

-  It is technically possible to use extensions to change major aspects of the TLS design, such as the design of cipher suite negotiation. This practice is not recommended; a more appropriate approach is to define a new version of TLS -- in particular, the TLS handshake algorithm has specific protection mechanisms against version downgrade attacks based on version numbers, and the possibility of downgrade attacks should be a meaningful consideration in any major design change.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_1_.png'>
</p>

We know that in ClientHello, the Extension field comes immediately after the Compression Methods field, so we will examine the fields one by one starting after Compression Methods.


### 1. server\_name


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_2_.png'>
</p>

The server\_name extension is relatively simple: it stores the Server’s name.

TLS does not provide a mechanism for the Client to tell the Server the name of the Server it is establishing a connection with. The Client may want to provide this information to facilitate secure connections to a Server that hosts multiple “virtual” services at a single underlying network address.

When a Client connects to an HTTPS website, after resolving the IP address, it can create a TLS connection. Before the handshake is complete, the messages received by the Server do not contain the HTTP `Host` header. If this Server has multiple virtual services, and each service has its own certificate, then at this point the Server does not know which certificate to use.

Therefore, to solve this problem, the SNI extension was added. With this extension, the certificates corresponding to the different services can be distinguished.
```c
      struct {
          NameType name_type;
          select (name_type) {
              case host_name: HostName;
          } name;
      } ServerName;

      enum {
          host_name(0), (255)
      } NameType;

      opaque HostName<1..2^16-1>;

      struct {
          ServerName server_name_list<1..2^16-1>
      } ServerNameList;
```
Servers that support TLS 1.2 respond to this extension in ServerHello, as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_14.png'>
</p>

TLS 1.3 likewise responds to this extension in ServerHello, as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_30.png'>
</p>


It is sufficient to return an empty extension.

### 2. extended\_master\_secret

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_3_.png'>
</p>

This extension indicates that the client and server use the extended master secret computation method.   

The server responds to this extension in ServerHello, as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_19.png'>
</p>

The server returns an empty extended\_master\_secret extension, indicating that the extended master secret computation method will be used. For more on the extended master secret computation method, see [“HTTPS Refresher (Part 5) — Key Computation in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-key-cipher.md).
   
### 3. renegotiation\_info Renegotiation

In scenarios with higher security requirements, if the server determines that the current encryption algorithm is not secure enough, or needs to verify the client certificate, it must establish a new connection; this is where renegotiation is needed. The protocol design for renegotiation was well-intentioned, but because a renegotiation vulnerability, CVE-2009-3555, appeared in 2009, renegotiation initiated by either the server or the client became insecure. The vulnerability occurred because the identities of the client and server were not verified, since neither side could determine whether the peer of the renegotiated connection was the same as that of the original connection.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_4_.png'>
</p>

To address this issue, this extension was added in RFC 5746. With this extension in place, renegotiation becomes secure.

The data structure of this extension is very simple: 
```c
      struct {
          opaque renegotiated_connection<0...255>;
      }
```
The server responds to this extension in ServerHello, returning the following:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_13.png'>
</p>

### 4. supported\_groups

This extension was originally called "elliptic\_curves" and was later renamed to "supported\_groups". Its purpose is clear from the original name: it indicates the types of elliptic curves supported by the client.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_5.png'>
</p>

In this example, the client supports four elliptic curves: x25519, secp256r1, secp384r1, and secp521r1.

After receiving this extension, the server selects an appropriate elliptic curve based on this information.

All curves supported in TLS 1.3 are as follows:
```c
      enum {
          unallocated_RESERVED(0x0000),

          /* Elliptic Curve Groups (ECDHE) */
          obsolete_RESERVED(0x0001..0x0016),
          secp256r1(0x0017), secp384r1(0x0018), secp521r1(0x0019),
          obsolete_RESERVED(0x001A..0x001C),
          x25519(0x001D), x448(0x001E),

          /* Finite Field Groups (DHE) */
          ffdhe2048(0x0100), ffdhe3072(0x0101), ffdhe4096(0x0102),
          ffdhe6144(0x0103), ffdhe8192(0x0104),

          /* Reserved Code Points */
          ffdhe_private_use(0x01FC..0x01FF),
          ecdhe_private_use(0xFE00..0xFEFF),
          obsolete_RESERVED(0xFF01..0xFF02),
          (0xFFFF)
      } NamedGroup;

      struct {
          NamedGroup named_group_list<2..2^16-1>;
      } NamedGroupList;
```
Curves marked as "obsolete\_RESERVED" were used in earlier versions of TLS and MUST NOT be offered or negotiated by TLS 1.3 implementations. Because these obsolete curves have various known/theoretical weaknesses or are very rarely used, they are no longer considered suitable for general-purpose use and should be considered potentially insecure. The set of curves specified here is sufficient to interoperate with all currently deployed and correctly configured TLS implementations.

### 5. ec\_point\_formats 

This extension indicates whether elliptic curve parameters can be compressed. Compression is generally not enabled (uncompressed).

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_6.png'>
</p>

The Server responds with this extension in ServerHello as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_15.png'>
</p>


### 6. SessionTicket TLS

This extension indicates whether the Client has a SessionTicket saved from the previous session. If it does, it means the Client wants to perform session resumption based on the SessionTicket.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_7.png'>
</p>

The Server responds with this extension in ServerHello as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_16.png'>
</p>

The Server returns an empty extension in SessionTicket TLS, and sends a new session ticket to the Client in NewSessionTicket.


### 7. application\_layer\_protocol\_negotiation

Application Layer Protocol Negotiation, or the ALPN application-layer protocol extension. Because application-layer protocols may have multiple versions, the Client wants to know which application-layer protocol is being used during the TLS handshake. The ALPN protocol was introduced for this purpose. ALPN aims to negotiate an application-layer protocol supported by both sides, while the lower layer of the application layer is still based on the TLS/SSL protocol.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_8.png'>
</p>

The figure above shows that the Client wants to negotiate the HTTP/2 protocol. If no agreement can be reached, it then negotiates HTTP/1.1.

In addition to protocols such as HTTP, there are some other application-layer protocols, as shown in the following table.

| Application-layer protocol | Identifier | RFC reference|
| :-----: | :-----: | :-----: | 
|HTTP/0.9	 | 0x68 0x74 0x74 0x70 0x2f 0x30 0x2e 0x39 ("http/0.9") | RFC1945|
|HTTP/1.0	| 0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x30 ("http/1.0") |RFC1945|
|HTTP/1.1	| 0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x31 ("http/1.1") | RFC7230 |
| SPDY/1	|0x73 0x70 0x64 0x79 0x2f 0x31 ("spdy/1")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1|
| SPDY/2	|0x73 0x70 0x64 0x79 0x2f 0x32 ("spdy/2")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2|
|SPDY/3	|0x73 0x70 0x64 0x79 0x2f 0x33 ("spdy/3")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3|
|Traversal Using Relays around NAT (TURN)|0x73 0x74 0x75 0x6E 0x2E 0x74 0x75 0x72 0x6E ("stun.turn")	|RFC7443|
|NAT discovery using Session Traversal Utilities for NAT (STUN)|0x73 0x74 0x75 0x6E 0x2E 0x6e 0x61 0x74 0x2d 0x64 0x69 0x73 0x63 0x6f 0x76 0x65 0x72 0x79 ("stun.nat-discovery") |RFC7443|
|HTTP/2 over TLS	|0x68 0x32 ("h2")|RFC7540|
|HTTP/2 over TCP	|0x68 0x32 0x63 ("h2c")	|RFC7540|
|WebRTC Media and Data	|0x77 0x65 0x62 0x72 0x74 0x63 ("webrtc")|RFC-ietf-rtcweb-alpn-04|
|Confidential WebRTC Media and Data	|0x63 0x2d 0x77 0x65 0x62 0x72 0x74 0x63 ("c-webrtc")|RFC-ietf-rtcweb-alpn-04|
|FTP	|0x66 0x74 0x70 ("ftp")	|RFC959, RFC4217|
|IMAP	|0x69 0x6d 0x61 0x70 ("imap")	|RFC2595|
|POP3	|0x70 0x6f 0x70 0x33 ("pop3")	|RFC2595|
|ManageSieve	|0x6d 0x61 0x6e 0x61 0x67 0x65 0x73 0x69 0x65 0x76 0x65 ("managesieve")	|RFC5804|
|CoAP	|0x63 0x6f 0x61 0x70 ("coap")	|RFC8323|
|XMPP jabber:client namespace	|0x78 0x6d 0x70 0x70 0x2d 0x63 0x6c 0x69 0x65 0x6e 0x74 ("xmpp-client")	|https://xmpp.org/extensions/xep-0368.html|
|XMPP jabber:server namespace	|0x78 0x6d 0x70 0x70 0x2d 0x73 0x65 0x72 0x76 0x65 0x72 ("xmpp-server")	|https://xmpp.org/extensions/xep-0368.html|

A Server that supports TLS 1.2 responds with this extension in ServerHello as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_18.png'>
</p>


TLS 1.3 behaves the same way, also responding with this extension in ServerHello as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_31.png'>
</p>


From this example, we can see that HTTP/2 was negotiated successfully.

### 8. status\_request

After the Client receives the certificate sent by the Server, in addition to verifying the certificate identity, it also needs to verify whether the certificate is still valid. The certificate may have just been revoked by the CA. Therefore, the Client must use the CRL and OCSP mechanisms to verify whether the certificate is still within its validity period. Both the CRL and OCSP mechanisms send an additional request to validate the certificate status, and this request may block subsequent steps in the handshake. To avoid blocking, the usual approach is for the Server to send the OCSP request to the CA.

To use OCSP stapling, the status\_request extension is added to ClientHello. This extension contains the certificate status request.

The `extension_data` of this extension contains CertificateStatusRequest information. The corresponding data structure is as follows:
```c
      struct {
          CertificateStatusType status_type;
          select (status_type) {
              case ocsp: OCSPStatusRequest;
          } request;
      } CertificateStatusRequest;

      enum { ocsp(1), (255) } CertificateStatusType;

      struct {
          ResponderID responder_id_list<0..2^16-1>;
          Extensions  request_extensions;
      } OCSPStatusRequest;

      opaque ResponderID<1..2^16-1>;
      opaque Extensions<0..2^16-1>;
```
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_9.png'>
</p>

After receiving this extension, the server sends a CertificateStatus submessage. This newly added submessage is specifically intended for this extension.
```c
      struct {
          CertificateStatusType status_type;
          select (status_type) {
              case ocsp: OCSPResponse;
          } response;
      } CertificateStatus;

      opaque OCSPResponse<1..2^24-1>;
```
OCSPResponse contains a complete DER-encoded OCSP encapsulated response. **The CertificateStatus submessage can only return OCSP information for the server's own certificate**.

The server responds to this extension in ServerHello, as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_17.png'>
</p>

The server returns an empty status\_request extension.

The CertificateStatus submessage returned by a server that supports TLS 1.2 is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_20.png'>
</p>

For a server that supports TLS 1.3, this extension is instead handled in the Certificate submessage:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_33.png'>
</p>


### 9. signature\_algorithms

The client uses the "signature\_algorithms" extension to indicate to the server which signature/hash algorithm pairs may be used for digital signatures. The "extension\_data" field of this extension contains a "supported\_signature\_algorithms" value.
```c
      enum {
          none(0), md5(1), sha1(2), sha224(3), sha256(4), sha384(5),
          sha512(6), (255)
      } HashAlgorithm;

      enum { anonymous(0), rsa(1), dsa(2), ecdsa(3), (255) }
        SignatureAlgorithm;

      struct {
            HashAlgorithm hash;
            SignatureAlgorithm signature;
      } SignatureAndHashAlgorithm;

      SignatureAndHashAlgorithm
        supported_signature_algorithms<2..2^16-2>;
```
Each `SignatureAndHashAlgorithm` value lists a hash/signature pair that a Client is willing to use. These values are listed in descending order of preference.

Note: Because not all signature algorithms and hash algorithms are accepted by every implementation (for example: DSA accepts SHA-1 but not SHA-256), all algorithms are listed in pairs.

- hash:    
  This field indicates the hash algorithms that may be used. These values indicate support for no hash, MD5, SHA-1, SHA-224, SHA-256, SHA-384, and SHA-512, respectively. The `"none"` value is reserved for future extensibility, in case a signature algorithm does not require hashing before signing.

- signature:    
  This field indicates which signature algorithm is used. These values indicate anonymous signatures, RSASSA-PKCS1-v1\_5, DSA, and ECDSA, respectively. The `"anonymous"` value is meaningless in this context and must not appear in this extension.

The semantics of this extension are somewhat complex, because cipher suites specify the allowed signature algorithms rather than the hash algorithms.

If a Client supports only the default hash and signature algorithms (as listed in this section), it may omit the signature\_algorithms extension. If a Client does not support the default algorithms, or supports other hash and signature algorithms (and is willing to use them to verify messages sent by the Server, such as server certificates and server key exchange), it must send the signature\_algorithms extension, listing the algorithms it is willing to accept.

If the Client does not send the signature\_algorithms extension, the Server must behave as follows:  

-  If the negotiated key exchange algorithm is one of (RSA, DHE\_RSA, DH\_RSA, RSA\_PSK, ECDH\_RSA, ECDHE\_RSA), behave as if the Client had sent {sha1,rsa};

-  If the negotiated key exchange algorithm is one of (DHE\_DSS, DH\_DSS), behave as if the Client had sent {sha1,dsa}.

-  If the negotiated key exchange algorithm is one of (ECDH\_ECDSA,ECDHE\_ECDSA), behave as if the Client had sent {sha1,ecdsa}.

Note: This is a change for TLS 1.1, where there is no explicit rule, but implementations can assume that the peer supports MD5 and SHA-1.

Note: This extension has no meaning for TLS versions earlier than 1.2, and Clients must not send this extension for earlier versions. However, even if the Client provides this extension, the explicit rules in [TLSEXT] require the Server to ignore extensions it does not understand.

The Server must not send this extension. A TLS Server must support receiving this extension.

When performing session resumption, this extension must not be included in the Server Hello, and the Server ignores this extension in the Client Hello (if present).
  
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_10.png'>
</p>


  

## II. Extensions in the TLS 1.3 Handshake

The TLS 1.3 [[RFC 8446]](https://tools.ietf.org/html/rfc8447) specification defines many extensions. The following extensions are basically all used in TLS 1.3. Together with the extensions in the table from the previous section, this is the most complete set of extensions currently available.

| Extension Type Name | Extension Type Number | Usage in TLS 1.3 | Recommended | RFC Reference |
| :----: | :----: | :----: |  :----: |  :----: |
| pre\_shared\_key | 41 | CH, SH	| ✅ | RFC8446 |
| early\_data	| 42 | CH, EE, NST	|✅	 | RFC8446 |
| supported\_versions | 43 |	CH, SH, HRR | ✅|RFC8446|
| cookie| 44 | CH, HRR|	✅|RFC8446|
| psk\_key\_exchange\_modes |45| CH|	✅|	RFC8446|
| Unassigned |46| | ❌| |			
| certificate\_authorities | 47|	CH, CR |✅ | RFC8446|
| oid\_filters | 48 | CR| ✅|RFC8446|
| post\_handshake\_auth | 49 |CH |✅	| RFC8446|
| signature\_algorithms\_cert | 50 |CH, CR|✅|RFC8446|
| key\_share | 51 | CH, SH, HRR | ✅	| RFC8446|
| Unassigned	| 52-65279 | | ❌ |	 |		
| Reserved for Private Use	 | 65280 | | | RFC8446 |
| Reserved for Private Use	 | 65282-65535 | | | RFC8446 |

> Abbreviation notes: CH: ClientHello, SH: ServerHello, CR: CertificateRequest, EE:EncryptedExtensions, HRR: HelloRetryRequest, CT: Certificate, NST: NewSessionTicket


CH (ClientHello), SH (ServerHello), EE (EncryptedExtensions), CT (Certificate), CR (CertificateRequest), NST (NewSessionTicket), and HRR (HelloRetryRequest)
```c
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
        RESERVED(40),                               /* Used but never
                                                       assigned */
        pre_shared_key(41),                         /* RFC 8446 */
        early_data(42),                             /* RFC 8446 */
        supported_versions(43),                     /* RFC 8446 */
        cookie(44),                                 /* RFC 8446 */
        psk_key_exchange_modes(45),                 /* RFC 8446 */
        RESERVED(46),                               /* Used but never
                                                       assigned */
        certificate_authorities(47),                /* RFC 8446 */
        oid_filters(48),                            /* RFC 8446 */
        post_handshake_auth(49),                    /* RFC 8446 */
        signature_algorithms_cert(50),              /* RFC 8446 */
        key_share(51),                              /* RFC 8446 */
        (65535)
    } ExtensionType;
```
TLS 1.3 adds many extensions compared with TLS 1.2, and of course the TLS 1.2 extensions mentioned in the previous chapter continue to be used.
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
In TLS 1.3, extensions are generally structured in a request/response pattern, although some extensions are merely identifiers and do not have any response. A Client can send extension requests only in ClientHello, and a Server can send the corresponding extension responses only in ServerHello, EncryptedExtensions, HelloRetryRequest, and Certificate messages.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_21.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_22.png'>
</p>

The two figures above show all the extensions in ClientHello in TLS 1.3. Up to signature\_algorithms, the extensions above were already covered in the TLS 1.2 extensions section. I will not repeat them here; I am just including the Wireshark screenshots for reference.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_23.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_24.png'>
</p>

### 1. signed\_certificate\_timestamp 

This extension already existed in TLS 1.2. It is included here only because it appeared in the TLS 1.3 packet capture, but did not appear in the TLS 1.2 packet capture.

This extension is related to Certificate Transparency. Each server end-entity certificate can be submitted by a CA or by the server entity to a CT log server to obtain the certificate’s SCT information.

A large part of the security of HTTPS websites depends on the trustworthiness of the PKI infrastructure. If a CA mistakenly issues an incorrect certificate, that certificate can still pass certificate-chain validation, so such certificates are difficult to discover; even if they are discovered, it is difficult to quickly eliminate their impact.

Certificate Transparency was designed to solve these problems. It is led by Google and standardized by the IETF as RFC 6962. The goal of Certificate Transparency is to provide an open auditing and monitoring system that allows any domain owner or CA to determine whether a certificate has been misissued or maliciously used, thereby improving the security of HTTPS websites.


The complete Certificate Transparency system consists of three parts: 1) Certificate Logs; 2) Certificate Monitors; 3) Certificate Auditors. For the full operating principles, see the official documentation: [How Certificate Transparency Works](https://www.certificate-transparency.org/how-ct-works)

In simple terms, certificate owners or CAs can proactively submit certificates to Certificate Logs servers, and all certificate records are subject to auditing and monitoring. Browsers that support CT (currently only Chrome) will react differently based on the certificate status in Certificate Logs. CT is not intended to replace the existing CA infrastructure, but to complement it, making it more transparent and more real-time.

Certificate Logs servers are deployed by Google or CAs. [This page](https://www.certificate-transparency.org/known-logs) lists the currently known servers. After a valid certificate is submitted to a CT Logs server, the server returns a signed certificate timestamp (SCT). SCT information is required to enable CT.

There are three ways to enable Certificate Transparency:

- 1. Through an X.509v3 extension
- 2. Through the TLS `signed_certificate_timestamp` extension
- 3. Through OCSP Stapling

Method 2 here is the extension discussed in this section. SCT information can be embedded in a certificate through an X.509v3 extension; method 1 is the future direction.

Let's Encrypt already embeds CT information in certificates by default. The certificate for my blog was issued by Let's Encrypt, so CT information is also embedded in the certificate.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_24_0.png'>
</p>


### 2. key\_share

In TLS 1.3, one of the reasons it is faster than TLS 1.2 lies in the key\_share extension. The key\_share extension contains the key-agreement parameters required by (EC)DHE groups, so there is no need to spend another 1-RTT round trip on negotiation.


The "supported\_groups" extension is used together with the "key\_share" extension. The “supported\_groups” extension indicates the (EC)DHE groups supported by the Client, while the "key\_share" extension indicates whether the Client includes some or all of the (EC)DHE shared parameters.

The KeyShareEntry data structure is as follows: 
```c
    struct {
        NamedGroup group;
        opaque key_exchange<1..2^16-1>;
    } KeyShareEntry;

    struct {
        KeyShareEntry client_shares<0..2^16-1>;
    } KeyShareClientHello;
```
If the Server selects an (EC)DHE group and the Client did not provide a suitable "key\_share" extension in the ClientHello, the Server must respond with a HelloRetryRequest message.
```c
    struct {
        NamedGroup selected_group;
    } KeyShareHelloRetryRequest;
```
If the ClientHello provides a suitable "key_share" extension, respond with the Server’s parameters in the ServerHello.
```c
    struct {
        KeyShareEntry server_share;
    } KeyShareServerHello;
```
The entire flow is shown below:  

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_25.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_29.png'>
</p>


The two figures above show how the Server and Client negotiate their respective key parameters.

> This extension is crucial in TLS 1.3, and the official TLS 1.3 specification also devotes substantial coverage to it. See [this article](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share).


### 3. psk\_key\_exchange\_modes

To use PSK, the Client must also send a "psk\_key\_exchange\_modes" extension. The semantics of this extension are that the Client only supports using PSKs with these modes. This restricts the use of the PSKs offered in this ClientHello, and also restricts the use of PSKs provided by the Server via NewSessionTicket.

If the Client provides a "pre\_shared\_key" extension, it must also provide a "psk\_key\_exchange\_modes" extension. If the Client sends "pre\_shared\_key" without the "psk\_key\_exchange\_modes" extension, the Server must abort the handshake immediately. The Server must not select a key exchange mode that the Client did not list. This extension also restricts the modes used with PSK resumption. The Server also must not send a NewSessionTicket that is incompatible with the proposed modes. However, if the Server insists on doing so, the only impact is that the Client will fail when it attempts to resume the session.


The Server must not send the "psk\_key\_exchange\_modes" extension:
```c
      enum { psk_ke(0), psk_dhe_ke(1), (255) } PskKeyExchangeMode;

      struct {
          PskKeyExchangeMode ke_modes<1..255>;
      } PskKeyExchangeModes;
```
- psk\_ke:  
	PSK-only key establishment. In this mode, the Server must not provide a "key\_share" value.

- psk\_dhe\_ke:  
	PSK and (EC)DHE establishment. In this mode, both the Client and Server must provide "key\_share" values.

Any values assigned in the future must ensure that the protocol messages transmitted can unambiguously identify the mode selected by the Server. Currently, the value selected by the Server is indicated by the presence of "key\_share" in ServerHello.

The message in ClientHello that contains this extension is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_26.png'>
</p>

### 4. supported\_versions

In TLS 1.3, the supported\_versions extension in ClientHello is very important, because TLS 1.3 uses the value of this field to negotiate whether TLS 1.3 is supported. The TLS 1.3 specification states that legacy\_version in ClientHello must be set to 0x0303, which represents TLS 1.2. This requirement exists to maintain compatibility with certain network middleboxes. If ClientHello does not carry the supported\_versions extension at this point, negotiation is inevitably limited to TLS 1.2.
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
The Client sends the TLS versions it supports in the supported\_versions extension of the ClientHello.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_27.png'>
</p>

After receiving it, the Server responds to the Client with the supported\_versions extension in the ServerHello, telling the Client which TLS version will be used for the subsequent handshake.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_28_.png'>
</p>

The example above indicates that a TLS 1.3 handshake will be performed next, even though the version fields in both the ClientHello and ServerHello are TLS 1.2.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_28_0.png'>
</p>


### 5. early\_data


When using PSK, and when the PSK allows early\_data, the Client can send application data in its first message. If the Client chooses to do so, it must send the "pre\_shared\_key" and "early\_data" extensions.


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


The parameters for 0-RTT data (version, symmetric cipher suite, Application-Layer Protocol Negotiation protocol [[RFC7301]](https://tools.ietf.org/html/rfc7301), and so on) are associated with the PSK parameters in use. For externally configured PSKs, the associated values are provided by the key. For PSKs established via a NewSessionTicket message, the associated values are the values negotiated when the PSK connection was established. The PSK used to encrypt early data must be the first PSK listed by the Client in the "pre\_shared\_key" extension.


For PSKs provided via NewSessionTicket, the Server must verify that the ticket age in the selected PSK identity (obtained by subtracting ticket\_age\_add from PskIdentity.obfuscated\_ticket\_age modulo 2^32) is within a small tolerance of the time since the ticket was issued. If the time difference is large, the Server should continue the handshake, but reject 0-RTT, and should also assume that this ClientHello is fresh and take no other action.


0-RTT messages sent in the first flight have the same (encrypted) content type as messages of the same type sent in other flights (handshake and application data), but they are protected with different keys. If the Server has accepted early data, then after receiving the Server's Finished message, the Client sends an EndOfEarlyData message to indicate a key change. This message is encrypted using the 0-RTT traffic keys.

A Server receiving the "early\_data" extension must behave in one of the following three ways:

- Ignore the "early\_data" extension and return a normal 1-RTT response. The Server attempts to decrypt received records using the handshake traffic keys, and ignores the early data. Records that fail decryption are discarded (subject to the configured max\_early\_data\_size). Once a record is decrypted successfully, the Server treats it as the start of the Client's second flight and processes it as normal 1-RTT data.


- Request that the Client send another ClientHello by responding with a HelloRetryRequest. The Client must not include the "early\_data" extension in this ClientHello. The Server ignores early data by skipping all records with the external content type "application\_data" (indicating that they are encrypted), again subject to the configured max\_early\_data\_size.

- Return its own "early\_data" extension in EncryptedExtensions, indicating that it is prepared to process early data. The Server cannot accept only part of the early data messages. Even if the Server sends a message accepting early data, the early data may in fact already be in flight when the Server generates that message.

To accept early data, the Server must have accepted the PSK cipher suite and selected the first key offered in the Client's "pre\_shared\_key" extension. In addition, the Server needs to verify that the following values match the associated values for the selected PSK:

- TLS version
- Selected cipher suite
- Selected ALPN protocol, if one was selected

These requirements are a superset of those required to perform a 1-RTT handshake using the associated PSK. For externally established PSKs, the associated values are the values provided together with the key. For PSKs established via a NewSessionTicket message, the associated values are the values negotiated in the connection during which the ticket was established.

If any check fails, the Server must not include the extension in its response and must use one of the first two mechanisms listed above, discarding all first-flight data (thereby falling back to 1-RTT or 2-RTT). If the Client attempts a 0-RTT handshake but the Server rejects it, the Server usually will not have 0-RTT record protection keys, and must find the first non-0-RTT message by trial decryption (using the 1-RTT handshake keys, or by looking for a plaintext ClientHello when a HelloRetryRequest message is involved).

If the Server chooses to accept the early\_data extension, then when processing early data records, it must process all records according to the same criteria (with the same specified error-handling requirements). In particular, if the Server cannot decrypt a record in the accepted "early\_data" extension, it must send a "bad\_record\_mac" alert message and abort the handshake.

If the Server rejects the "early\_data" extension, the Client application may choose to resend the application data previously sent as early data after the handshake completes. Note that automatic retransmission of early data can lead to incorrect assumptions about the connection state. For example, when the negotiated connection selects a different ALPN protocol from the one used for early data, the application may need to construct a different message. Likewise, if the early data assumed anything about the connection state, that data might be sent incorrectly after the handshake completes.


TLS implementations should not automatically resend early data; the application is better positioned to decide when to retransmit. Unless the negotiated connection selects the same ALPN protocol, a TLS implementation must never automatically resend early data.

The following figure shows early\_data in NewSessionTicket, indicating that the Server can accept 0-RTT.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_32.png'>
</p>


### 6. pre\_shared\_key

The "pre\_shared\_key" pre-shared key extension is used together with the "psk\_key\_exchange\_modes" extension. The pre-shared key extension contains identifiers for symmetric keys that the Client can recognize. The "psk\_key\_exchange\_modes" extension indicates the key exchange modes that may be used with the PSK.

The "pre\_shared\_key" extension is used to negotiate the identity, which identifies the pre-shared key associated with the PSK key and used for the given handshake.


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
	A label for the key. For example, a ticket or the label of an externally established pre-shared key.
	
- obfuscated\_ticket\_age:  
	An obfuscated version of the age of the key. [This section](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-ticket-age) describes how this value is generated for identities established via the NewSessionTicket message. For externally established identities, obfuscated\_ticket\_age should be 0, and the Server must also ignore this value.


- identities:  
	The list of identities that the Client is willing to negotiate with the Server. If sent together with "early\_data", the first identity is used to identify the 0-RTT data.
	

- binders:  
	A series of HMAC values. Each value corresponds one-to-one with an entry in the identities list, in the same order.

- selected\_identity:  
	The identity selected by the Server, expressed as a zero-based index into the Client's list of identities.

Each PSK is associated with a single hash algorithm. For PSKs established via tickets, the hash algorithm used is the KDF hash algorithm in use when the ticket was established in the connection. For externally established PSKs, the hash algorithm must be set when the PSK is established; if it is not set, the default algorithm is SHA-256. The Server must ensure that it selects a compatible PSK (if any) and cipher suite.

Implementation note: session resumption is the primary use case for PSKs. The most straightforward way to implement the PSK/cipher suite matching requirement is to negotiate the cipher suite first, and then exclude any incompatible PSKs. Any unknown PSK (for example, one that is not in the PSK database, or one encoded with an unknown key) must be ignored. If no acceptable PSK can be found, the Server should perform a non-PSK handshake if possible. If backward compatibility is important, externally established PSKs offered by the Client should influence cipher suite selection.


Before accepting PSK key establishment, the Server must first verify the corresponding binder value. If this value is absent or cannot be verified, the Server must immediately abort the handshake. The Server should not attempt to verify multiple binders; instead, it should select a single PSK and verify only the binder corresponding to that PSK. To accept a PSK key establishment connection, the Server sends the "pre\_shared\_key" extension, indicating the identity it selected.


The Client must verify that the Server's selected\_identity is within the range provided by the Client. The cipher suite selected by the Server indicates the hash algorithm associated with the PSK, and if required by the ClientHello "psk\_key\_exchange\_modes", the Server should also send the "key\_share" extension. If these values are inconsistent, the Client must immediately abort the handshake with an "illegal\_parameter" alert message.


If the Server provides the "early\_data" extension, the Client must verify that the Server's selected\_identity is 0. If any other value is returned, the Client must abort the handshake with an "illegal\_parameter" alert message.


The "pre\_shared\_key" extension must be the last extension in ClientHello (this facilitates the implementation described below). The Server must check that it is the last extension; otherwise, it aborts the handshake with an "illegal\_parameter" alert message.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_38.png'>
</p>

The figure above shows the pre\_shared\_key extension in ClientHello.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_41.png'>
</p>

The figure above shows the pre\_shared\_key extension returned to the Client after the Server has made its selection. It identifies which set of key parameters the Server selected.

### 7. signature\_algorithms\_cert

The "signature\_algorithms" signature algorithms extension and the "signature\_algorithms\_cert" certificate signature algorithms extension are used together. The "signature\_algorithms" extension indicates which signature algorithms the Client can support. The "signature\_algorithms\_cert" extension indicates the signature algorithms for specific certificates.


### 8. cookie
```c
      struct {
          opaque cookie<1..2^16-1>;
      } Cookie;
```
Cookies have two primary purposes:

- They allow the Server to force the Client to demonstrate reachability at its network address (thereby providing a measure of protection against DoS), which is primarily intended for connectionless transports (see the example in [RFC 6347](https://tools.ietf.org/html/rfc6347)).


- They allow the Server to offload state, enabling the Server to avoid storing any state when sending a HelloRetryRequest message to the Client. To achieve this, the Server can store the hash of the ClientHello in the HelloRetryRequest cookie (protected with an appropriate integrity algorithm).


When sending a HelloRetryRequest message, the Server may provide a “cookie” extension to the Client (this is an exception to the usual rule that only extensions that may be sent can appear in ClientHello). When sending the new ClientHello message, the Client MUST copy the contents of the extension received in the HelloRetryRequest into the “cookie” extension in the new ClientHello. The Client MUST NOT use the Cookie from the initial ClientHello in subsequent connections.


When the Server is operating statelessly, it may receive unprotected change\_cipher\_spec messages between the first and second ClientHello. Because the Server has not stored any state, it will behave as if this were the first message to arrive. A stateless Server MUST ignore these records.

### 9. certificate\_authorities
	
The "certificate\_authorities" extension is used to indicate the CAs supported by the endpoint, and the receiving endpoint should use it to guide certificate selection.
	
The body of the "certificate\_authorities" extension contains a CertificateAuthoritiesExtension structure:
```c
      opaque DistinguishedName<1..2^16-1>;

      struct {
          DistinguishedName authorities<3..2^16-1>;
      } CertificateAuthoritiesExtension;
```
- authorities:  
	A list of distinguished names [X501](https://tools.ietf.org/html/rfc8446#ref-X501) of acceptable certificate authorities, represented in DER [X690](https://tools.ietf.org/html/rfc8446#ref-X690) encoding. These distinguished names specify the desired distinguished names for trust anchors or subordinate CAs. Thus, this message can be used to describe known trust anchors as well as the desired authorization space.
	
The Client MAY send the "certificate\_authorities" extension in the ClientHello message, and the Server MAY send the "certificate\_authorities" extension in the CertificateRequest message.


The "trusted\_ca\_keys" extension serves the same purpose as the "certificate\_authorities" extension, but is more complex. The "trusted\_ca\_keys" extension cannot be used in TLS 1.3, but in versions prior to TLS 1.3, it may appear in the Client's ClientHello message.


### 10. oid\_filters

The "oid\_filters" extension allows the Server to provide a set of OID/value pairs to match against the Client's certificate. If the Server wants to send this extension, it can do so only in the CertificateRequest message.
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
	A list of certificate extension OIDs with allowed values, as defined in [RFC 5280](https://tools.ietf.org/html/rfc5280), represented in DER-encoded [X690](https://tools.ietf.org/html/rfc8446#ref-X690) format. Some certificate extension OIDs allow multiple values (for example, Extended Key Usage). If the Server includes a non-empty filters list, the Client certificate included in the response must contain all of the specified extension OIDs recognized by the Client. For each extension OID recognized by the Client, all specified values must be present in the Client certificate (though the certificate may also have other values). However, the Client must ignore and skip any unrecognized certificate extension OIDs. If the Client ignores some required certificate extension OIDs and provides a certificate that does not satisfy the request, the Server may, at its own discretion, either continue the connection with the Client unauthenticated or abort the handshake with an "unsupported\_certificate" alert message. Any given OID must not appear more than once in the filters list.


The PKIX RFC defines various certificate extension OIDs and their corresponding value types. Depending on the type, matching certificate extension values are not necessarily bitwise equal. TLS implementations are expected to rely on their PKI libraries to select certificates using certificate extension OIDs.

The TLS 1.3 specification defines matching rules for two standard certificate extensions defined in [RFC5280](https://tools.ietf.org/html/rfc5280):


- The Key Usage extension in a certificate matches the request when all Key Usage bits asserted in the request are also asserted in the Key Usage certificate extension.

- The Extended Key Usage in a certificate matches the request when all key OIDs in the request are also present in the Extended Key Usage certificate extension. The special anyExtendedKeyUsage OID MUST NOT be used in the request.


Separate specifications may define matching rules for other certificate extensions.


### 11. post\_handshake\_auth


The "post\_handshake\_auth" extension is used to indicate that the Client is willing to authenticate after the handshake. The Server MUST NOT send a post-handshake CertificateRequest message to a Client that did not offer this extension. The Server MUST NOT send this extension.
```c
      struct {} PostHandshakeAuth;
```
The `extension_data` field in the `"post_handshake_auth"` extension is zero-length.

When the Client sends the `"post_handshake_auth"` extension, the Server may request client authentication at any time after the handshake completes by sending a CertificateRequest message. The Client must respond with the appropriate authentication messages. If the Client chooses to authenticate, it must send Certificate, CertificateVerify, and Finished messages. If the Client declines authentication, it must send a Certificate message containing no certificates, followed by a Finished message. All Client messages in response to the Server must appear consecutively on the wire, with no other types of messages in between.

A Client that receives a CertificateRequest message without having sent the `"post_handshake_auth"` extension must send an `"unexpected_message"` alert message.

Note: Because Client authentication may involve prompting the user, the Server must be prepared for some delay, including receiving any number of other messages between sending CertificateRequest and receiving the response. In addition, if the Client receives multiple CertificateRequest messages in succession, it may respond to them in an order different from the order in which they were received (the `certificate_request_context` value allows the server to disambiguate the responses).

### 12. signature_algorithms

This extension already existed in TLS 1.2, but its data structure changed in TLS 1.3, so it is still worth mentioning.
```c
      struct {
          SignatureScheme supported_signature_algorithms<2..2^16-2>;
      } SignatureSchemeList;
```
`SignatureScheme` has the following enum values:
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
          obsolete_RESERVED(0x0000..0x0200),
          dsa_sha1_RESERVED(0x0202),
          obsolete_RESERVED(0x0204..0x0400),
          dsa_sha256_RESERVED(0x0402),
          obsolete_RESERVED(0x0404..0x0500),
          dsa_sha384_RESERVED(0x0502),
          obsolete_RESERVED(0x0504..0x0600),
          dsa_sha512_RESERVED(0x0602),
          obsolete_RESERVED(0x0604..0x06FF),
          private_use(0xFE00..0xFFFF),
          (0xFFFF)
      } SignatureScheme;
```


------------------------------------------------------

Reference：

[RFC 6066](https://tools.ietf.org/html/rfc6066)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS-extensions/](https://halfrost.com/https-extensions/)