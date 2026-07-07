# HTTPS: Reviewing the Old to Learn the New (III) —— An Intuitive Look at the TLS Handshake Process (Part 1)


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0_.png'>
</p>


In the opening article on HTTPS, I analyzed that the reason HTTPS is secure is the existence of the TLS protocol. The TLS protocol component that guarantees information security and integrity is the record layer protocol. (The record layer protocol was analyzed in detail in the previous article.) After reading the previous article, readers may wonder: where does the key used for encryption at the TLS protocol layer come from? How exactly do the client and server negotiate the Security Parameters? This article analyzes in detail the similarities and differences between TLS 1.2 and TLS 1.3 at the TLS handshake layer.

Compared with TLS 1.2, the biggest improvements TLS 1.3 makes to the TLS handshake protocol are speed and security. This article focuses on these two aspects.

## 1. The Impact of TLS on Network Request Latency

Because HTTPS is deployed, TLS is added at the transport layer, which adds some extra time to a complete request. How many RTTs does it add specifically?

First, let’s look at how many RTTs a complete request takes from scratch. Suppose a user visits an HTTPS website, starting from HTTP and ending when the first HTTPS Response is received. The process roughly involves the following steps (using the currently most mainstream TLS 1.2 as an example):


|Process | Time Cost | Total |
| --- | :---: | :---:|
|1. DNS resolution for the website domain | 1-RTT | |
|2. TCP handshake for accessing the HTTP page |  1-RTT | |
|3. HTTPS redirect 302 |  1-RTT | |
|4. TCP handshake for accessing the HTTPS page|  1-RTT | |
|5. TLS handshake phase 1: Say Hello| 1-RTT||
|6. 【Certificate validation】DNS resolution for the CA site| 1-RTT||
|7. 【Certificate validation】TCP handshake with the CA site| 1-RTT||
|8. 【Certificate validation】Request OCSP validation|1-RTT||
|9. TLS handshake phase 2: Encryption| 1-RTT||
|10. First HTTPS request| 1-RTT||
|||10-RTT|


Among the steps above, 1 and 10 definitely cannot be eliminated. Steps 6, 7, and 8 are optional if the browser has a local cache. The remaining steps are shown in the flowchart below:

![](https://img.halfrost.com/Blog/ArticleImage/97_1.png)

Some notes on the steps above:

When a user visits a page for the first time, DNS resolution is required. After DNS resolution, the result is cached by the browser. As long as the TTL has not expired, all subsequent visits during that period no longer need to spend time on DNS resolution. In addition, if HTTPDNS is used, the resolved result will also be cached. Therefore, the first step does not necessarily cost 1-RTT every time.

If the website has enabled HSTS (HTTP Strict Transport Security), then step 3 above does not exist, because the browser directly replaces the HTTP request with an HTTPS request, preventing man-in-the-middle attacks during redirection.

If the browser has a cached domain resolution result for the mainstream CA, step 6 above is also unnecessary; it can access the site directly.

If the browser has disabled OCSP or has a local cache, steps 7 and 8 above are also unnecessary. 

The 10 steps above represent the most complete process. In general, various caches mean not every step above is executed. If various caches are present and an HSTS policy is in place, then the process that users must go through every time they visit a webpage is as follows:

|Process | Time Cost | Total |
|--- | :---: | :---: |
|1. TCP handshake for accessing the HTTPS page |  1-RTT | |
|2. TLS handshake phase 1: Say Hello| 1-RTT||
|3. TLS handshake phase 2: Encryption| 1-RTT||
|4. First HTTPS request| 1-RTT||
|||4-RTT|

Aside from step 4, which cannot be eliminated under any circumstances, the remaining costs are the TCP and TLS handshakes. Reducing TCP to 0-RTT currently looks somewhat difficult. What about TLS? A full TLS 1.2 handshake currently requires 2-RTT. Can it be reduced further? The answer is yes.


## 2. Overview of the TLS/SSL Protocol

The TLS handshake protocol runs on top of the TLS record layer. Its purpose is to let the server and client agree on the protocol version, choose encryption algorithms, optionally authenticate each other, and use public-key cryptography to generate a shared key—that is, to negotiate the Security Parameters required for encryption and integrity protection in the TLS record layer. During negotiation, it must also ensure that the information transmitted over the network cannot be tampered with or forged. Because negotiation requires several round trips over the network, a large portion of TLS network latency is spent on network RTTs.

The item most closely related to encryption parameters is the cipher suite. During negotiation, the client and server need to match their cipher suites. After the handshake succeeds, both sides negotiate all encryption parameters based on the cipher suite. The most important encryption parameter is the master secret.

The handshake protocol is mainly responsible for negotiating a session. This session consists of the following elements:

- session identifier:      
  An arbitrary byte sequence selected by the server to identify an active or resumable connection state.

- peer certificate:      
  The peer’s X509v3 [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX) certificate. This field may be empty.

- compression method:      
  The compression algorithm before encryption. This field is not used much in TLS 1.2. In TLS 1.3, this field was removed.

- cipher spec:      
  Specifies the pseudorandom function (PRF) used to generate key material, the block cipher algorithm (for example: null, AES, etc.), and the MAC algorithm (for example: HMAC-SHA1). It also defines cryptographic attributes such as mac\_length. This field has been removed from the TLS 1.3 specification, but for compatibility with older protocols before TLS 1.2, it may still exist in actual use. In TLS 1.3, key derivation uses the HKDF algorithm. The specific differences between PRF and HKDF will be analyzed in detail in a later article.

- master secret:      
  A 48-byte key shared between the client and server.
  
- is resumable:      
   A flag indicating whether the session can be used to initialize a new connection.

These fields are subsequently used to generate security parameters and are used by the record layer when protecting application data. By using the resumption feature of the TLS handshake protocol, many connections can be instantiated with the same session.

The TLS handshake protocol includes the following steps:

- Exchange Hello messages, exchange random numbers and supported cipher suite lists, negotiate the cipher suite and corresponding algorithms, and check whether the session can be resumed
- Exchange the necessary cryptographic parameters to allow the client and server to negotiate the premaster secret
- Exchange certificates and cryptographic information to allow the client and server to authenticate each other
- Generate the master secret from the premaster secret and the exchanged random numbers
- Provide security parameters (mainly cipher blocks) to the TLS record layer
- Allow the client and server to verify that their peer has computed the same security parameters and that the handshake process has not been tampered with by an attacker


The discussion below will follow the order of the initial TLS handshake and session resumption, comparing the differences between TLS 1.2 and TLS 1.3 in the handshake process, while analyzing and explaining real network packets captured with Wireshark. Finally, it will analyze what the new 0-RTT feature in TLS 1.3 is all about.


## 3. Initial TLS 1.2 Handshake Process

The main flow of the TLS 1.2 handshake protocol is as follows:

The Client sends a ClientHello message, and the Server must respond with a ServerHello message or generate a validation error and fail the connection. ClientHello and ServerHello are used to establish security-enhancing capabilities between the Client and Server. ClientHello and ServerHello establish the following properties: protocol version, session ID, cipher suite, and compression algorithm. In addition, two random values are generated and exchanged: ClientHello.random and ServerHello.random.

At most four messages are used in key exchange: Server Certificate, ServerKeyExchange, Client Certificate, and ClientKeyExchange. New key exchange methods can be created through these methods: specify a format for these messages and define how these messages are used so that the Client and Server can agree on a shared key. This key must be long; the currently defined key exchange methods exchange keys longer than 46 bytes.

After the hello messages, the Server sends its own certificate in the Certificate message if it is to be authenticated. In addition, if necessary, a ServerKeyExchange message is sent (for example, if the Server has no certificate, or if its certificate is only used for signing; RSA cipher suites do not have a ServerKeyExchange message). If the Server has been authenticated, and if appropriate for the selected cipher suite, it may request that the Client send a certificate. Next, the Server sends the ServerHelloDone message, which means the hello message phase of the handshake is complete. The Server then waits for the Client’s response. If the Server sent a CertificateRequest message, the Client must send a Certificate message. The ClientKeyExchange message now needs to be sent, and its contents depend on the public-key algorithm selected between ClientHello and ServerHello. If the Client sent a certificate with signing capability, it must send a CertificateVerify message with a digital signature to explicitly verify ownership of the private key in the certificate.

At this point, the Client sends a ChangeCipherSpec message and copies the pending Cipher Spec into the current Cipher Spec. Then, after the new algorithm and keys have been determined, the Client immediately sends the Finished message. In response, the Server sends its own ChangeCipherSpec message, converts the pending Cipher Spec into the current Cipher Spec, and sends the Finished message under the new Cipher Spec. At this point, the handshake is complete, and the Client and Server can begin exchanging application-layer data. Application data must not be sent before the first handshake is complete (before a cipher suite other than TLS\_NULL\_WITH\_NULL\_NULL has been established).

A classic diagram of a complete handshake is shown below:
```c
      Client                                               Server

      ClientHello                  -------->
                                                      ServerHello
                                                     Certificate*
                                               ServerKeyExchange*
                                              CertificateRequest*
                                   <--------      ServerHelloDone
      Certificate*
      ClientKeyExchange
      CertificateVerify*
      [ChangeCipherSpec]
      Finished                     -------->
                                               [ChangeCipherSpec]
                                   <--------             Finished
      Application Data             <------->     Application Data
```
\* denotes optional or condition-dependent messages that are not always sent.

**To prevent pipeline stalls, ChangeCipherSpec is a separate TLS protocol content type and, in fact, is not a TLS message**. Therefore, the "[]" in the diagram indicates that ChangeCipherSpec is not a TLS message.

The TLS handshake protocol is a defined higher-level client of the TLS record protocol. This protocol is used to negotiate the security attributes of a session. Handshake messages are passed to the TLS record layer, where they are encapsulated in one or more TLSPlaintext structures; these structures are processed and transmitted as specified by the current active session state.
```c
      enum {
          hello_request(0), 
          client_hello(1), 
          server_hello(2),
          certificate(11), 
          server_key_exchange (12),
          certificate_request(13), 
          server_hello_done(14),
          certificate_verify(15), 
          client_key_exchange(16),
          finished(20), 
          (255)
      } HandshakeType;

      struct {
          HandshakeType msg_type;    /* handshake type */
          uint24 length;             /* bytes in message */
          select (HandshakeType) {
              case hello_request:       HelloRequest;
              case client_hello:        ClientHello;
              case server_hello:        ServerHello;
              case certificate:         Certificate;
              case server_key_exchange: ServerKeyExchange;
              case certificate_request: CertificateRequest;
              case server_hello_done:   ServerHelloDone;
              case certificate_verify:  CertificateVerify;
              case client_key_exchange: ClientKeyExchange;
              case finished:            Finished;
          } body;
      } Handshake;
```
Handshake protocol messages are presented below in the order in which they are sent; sending handshake messages out of the expected order results in a fatal error and the handshake fails. However, unnecessary handshake messages are ignored. Note that the exceptional ordering is that the Certificate message is used twice during the handshake (from Server to Client, then from Client to Server). One message not constrained by this ordering is the HelloRequest message, which may be sent at any time, but if it is received in the middle of a handshake, it should be ignored by the Client.

### 1. Hello Submessages

Messages in the Hello phase are used to exchange security-enhancement capabilities between the Client and Server. When a new session starts, the record-layer connection-state encryption, hash, and compression algorithms are initialized to null. The current connection state is used for renegotiation messages.


### (1) Hello Request

The HelloRequest message may be sent by the Server at any time.

Meaning of this message: HelloRequest is a simple notification telling the Client that it should begin the renegotiation process. In response, the Client should send a ClientHello message when convenient. This message is not intended to determine which endpoint is the Client or Server; it merely initiates a new negotiation. The Server should not send a HelloRequest immediately after the Client initiates a connection.

If the Client is currently negotiating a session, the HelloRequest message is ignored by the Client. If the Client does not want to renegotiate a session, or if the Client wishes to respond with a no\_renegotiation alert message, it may also ignore the HelloRequest message. Because handshake messages are intended to be transmitted before application data, the expectation is that negotiation will begin before the Client receives a small number of record messages. If the Server sends a HelloRequest but does not receive a ClientHello response, it should close the connection with a fatal alert message. After sending a HelloRequest, the Server should not repeat the request until the subsequent handshake negotiation has completed.

Structure of the HelloRequest message:
```c
              struct { } HelloRequest;
```
This message must not be included in the message hash maintained for the handshake messages, nor used in the Finished message or the CertificateVerify message.

### (2) Client Hello

When a Client first connects to a Server, the first message it sends MUST be ClientHello. A Client can also send a ClientHello in response to a HelloRequest, or on its own initiative to renegotiate security parameters within an existing connection.
```c
         struct {
             uint32 gmt_unix_time;
             opaque random_bytes[28];
         } Random;
         
      struct {
          ProtocolVersion client_version;
          Random random;
          SessionID session_id;
          CipherSuite cipher_suites<2..2^16-2>;
          CompressionMethod compression_methods<1..2^8-1>;
          select (extensions_present) {
              case false:
                  struct {};
              case true:
                  Extension extensions<0..2^16-1>;
          };
      } ClientHello;         
```
- gmt\_unix\_time:    
  The current time and date according to the sender’s internal clock, represented in the standard UNIX 32-bit format (the number of seconds since midnight UTC on January 1, 1970, ignoring leap seconds). The base TLS protocol does not require the clock to be set correctly; higher-level or application-layer protocols may define additional requirements. Note that, for historical reasons, this field is named after Greenwich Mean Time rather than UTC.

- random\_bytes:    
  28 bytes of data generated by a secure random number generator.

- client\_version:    
  The TLS protocol version that the Client is willing to use for this session. This should be the latest version supported by the Client (the largest value): TLS 1.2 is 3.3, and TLS 1.3 is 3.4.

- random:    
  A `Random` structure generated by the Client. The `Random` struct is shown above. **The client random is very useful: it is used when generating the premaster secret, when deriving the master secret and key block with the PRF algorithm, and when verifying the integrity of the complete messages. Its main purpose is to prevent replay attacks**.

- session\_id:    
  The session ID that the Client wants to use for this connection. If there is no session\_id, or if the Client wants to generate new security parameters, this field is empty. **This field is primarily used for session resumption**.

- cipher\_suites:    
  The list of cipher suites supported by the Client, with the Client’s most preferred suites listed first. If the session\_id field is not empty (meaning this is a session resumption request), this vector must contain at least the cipher\_suite from that session. The possible values of the cipher\_suites field are as follows:
```c
      CipherSuite TLS_NULL_WITH_NULL_NULL               = { 0x00,0x00 };
      CipherSuite TLS_RSA_WITH_NULL_MD5                 = { 0x00,0x01 };
      CipherSuite TLS_RSA_WITH_NULL_SHA                 = { 0x00,0x02 };
      CipherSuite TLS_RSA_WITH_NULL_SHA256              = { 0x00,0x3B };
      CipherSuite TLS_RSA_WITH_RC4_128_MD5              = { 0x00,0x04 };
      CipherSuite TLS_RSA_WITH_RC4_128_SHA              = { 0x00,0x05 };
      CipherSuite TLS_RSA_WITH_3DES_EDE_CBC_SHA         = { 0x00,0x0A };
      CipherSuite TLS_RSA_WITH_AES_128_CBC_SHA          = { 0x00,0x2F };
      CipherSuite TLS_RSA_WITH_AES_256_CBC_SHA          = { 0x00,0x35 };
      CipherSuite TLS_RSA_WITH_AES_128_CBC_SHA256       = { 0x00,0x3C };
      CipherSuite TLS_RSA_WITH_AES_256_CBC_SHA256       = { 0x00,0x3D };
      CipherSuite TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA      = { 0x00,0x0D };
      CipherSuite TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA      = { 0x00,0x10 };
      CipherSuite TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA     = { 0x00,0x13 };
      CipherSuite TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA     = { 0x00,0x16 };
      CipherSuite TLS_DH_DSS_WITH_AES_128_CBC_SHA       = { 0x00,0x30 };
      CipherSuite TLS_DH_RSA_WITH_AES_128_CBC_SHA       = { 0x00,0x31 };
      CipherSuite TLS_DHE_DSS_WITH_AES_128_CBC_SHA      = { 0x00,0x32 };
      CipherSuite TLS_DHE_RSA_WITH_AES_128_CBC_SHA      = { 0x00,0x33 };
      CipherSuite TLS_DH_DSS_WITH_AES_256_CBC_SHA       = { 0x00,0x36 };
      CipherSuite TLS_DH_RSA_WITH_AES_256_CBC_SHA       = { 0x00,0x37 };
      CipherSuite TLS_DHE_DSS_WITH_AES_256_CBC_SHA      = { 0x00,0x38 };
      CipherSuite TLS_DHE_RSA_WITH_AES_256_CBC_SHA      = { 0x00,0x39 };
      CipherSuite TLS_DH_DSS_WITH_AES_128_CBC_SHA256    = { 0x00,0x3E };
      CipherSuite TLS_DH_RSA_WITH_AES_128_CBC_SHA256    = { 0x00,0x3F };
      CipherSuite TLS_DHE_DSS_WITH_AES_128_CBC_SHA256   = { 0x00,0x40 };
      CipherSuite TLS_DHE_RSA_WITH_AES_128_CBC_SHA256   = { 0x00,0x67 };
      CipherSuite TLS_DH_DSS_WITH_AES_256_CBC_SHA256    = { 0x00,0x68 };
      CipherSuite TLS_DH_RSA_WITH_AES_256_CBC_SHA256    = { 0x00,0x69 };
      CipherSuite TLS_DHE_DSS_WITH_AES_256_CBC_SHA256   = { 0x00,0x6A };
      CipherSuite TLS_DHE_RSA_WITH_AES_256_CBC_SHA256   = { 0x00,0x6B };
```  
- compression\_methods:    
  This is the list of compression algorithms supported by the Client, ordered by the Client's preference. If the session\_id field is not empty (meaning this is a session resumption request), it must include the compression\_method from that session. This vector must include, and all implementations must also support, CompressionMethod.null. Therefore, a Client and Server will be able to negotiate and agree on a compression algorithm.

- extensions:    
  Clients can request extended functionality from the Server by sending data in the extensions field. **Just like extensions in certificates, extensions are also supported in the TLS/SSL protocol, providing greater extensibility without modifying the protocol**.

If a Client uses an extension to request additional functionality and the Server does not support that functionality, the Client may abort the handshake. A Server must accept ClientHello messages with or without an extensions field, and (as with all other messages) it must verify that the amount of data in the message exactly matches one of the valid formats; otherwise, it must send a fatal "decode\_error" alert message.

After sending the ClientHello message, the Client waits for the ServerHello message. Any handshake message returned by the Server, other than HelloRequest, is treated as a fatal error.

TLS allows extensions to be added in the extensions block after the compression\_methods field. The presence of extensions can be detected by checking whether there are extra bytes after compression\_methods at the end of the ClientHello. Note that this method of detecting optional data differs from normal TLS variable-length fields, but it can be used to interoperate with TLS implementations from before extensions were defined.


The ClientHello message contains a variable-length Session ID session identifier. If non-empty, this value identifies a session between the same Client and Server that the Client wishes to reuse with the Server's security parameters from that session.

The Session ID session identifier may come from an earlier connection, from this connection, or from another currently active connection. The second option is useful if the Client only wants to update the random data structures and derive values from a connection; the third option makes it possible to establish several independent secure connections without repeating the full handshake protocol. These independent connections may be established sequentially or concurrently. A Session ID becomes valid when both parties have exchanged Finished messages and the handshake negotiation is complete, and remains valid until it is removed due to expiration or because a fatal error is encountered on a connection associated with the session. The actual contents of the Session ID are defined by the Server.
```c
       opaque SessionID<0..32>;
```
Because the Session ID is not encrypted or directly protected by a MAC during transmission, the server must never place confidential information in the Session ID session identifier, nor rely on the contents of a forged session identifier; doing so violates security principles. (Note that the handshake contents as a whole, including the Session ID, are protected by the Finished messages exchanged at the end of the handshake.)

The cipher suite list is passed from the client to the server in the ClientHello message. In the client’s order of preference (most preferred first), it contains the cryptographic algorithms supported by the client. Each cipher suite defines a key exchange algorithm, a block encryption algorithm (including key length), a MAC algorithm, and a pseudorandom function (PRF). The server selects a cipher suite; if there is no acceptable choice, it returns a handshake failure alert message and closes the connection. If the list contains cipher suites that the server does not recognize, support, or wish to use, the server must ignore them and process the remaining entries normally.
```c
      uint8 CipherSuite[2];    /* Cryptographic suite selector */
```
ClientHello contains the list of compression algorithms supported by the Client, ordered according to the Client’s preference.


### (3) Server Hello


When the Server can find an acceptable set of algorithms, it sends this message in response to the ClientHello message. If it cannot find such a set of algorithms, it sends a handshake failure alert message in response.

The structure of the Server Hello message is:
```c
      struct {
          ProtocolVersion server_version;
          Random random;
          SessionID session_id;
          CipherSuite cipher_suite;
          CompressionMethod compression_method;
          select (extensions_present) {
              case false:
                  struct {};
              case true:
                  Extension extensions<0..2^16-1>;
          };
      } ServerHello;
```
The presence of extensions can be detected by checking whether there are extra bytes after `compression_methods` at the end of `ServerHello`.

- server\_version:    
  This field contains the lower version proposed by the Client in the Client hello message and the highest version supported by the Server. TLS 1.2 is version 3.3, and TLS 1.3 is 3.4.


- random:      
  This structure is generated by the Server and must be independent of ClientHello.random. **Like the Client’s random value, this value is very useful: it is used when generating the premaster secret, when using the PRF algorithm to derive the master secret and key block, and when verifying the integrity of the complete messages. The main purpose of the random value is to prevent replay attacks**.

- session\_id:      
  This is the identifier of the session corresponding to this connection. If ClientHello.session\_id is non-empty, the Server will look for a match in its session cache. If a match is found, and the Server is willing to establish a new connection using the specified session state, the Server returns the same value provided by the Client. This means a session has been resumed, and both parties must continue communication after the Finished messages. Otherwise, this field contains a different value identifying a new session. The Server returns an empty session\_id to indicate that the session will not be cached and therefore cannot be resumed. If a session is resumed, it must use the originally negotiated cipher suite. Note that the Server is not required to resume any session, even if it previously provided a session\_id. The Client must be prepared to perform a full negotiation in any handshake, including negotiating a new cipher suite.
  
- cipher\_suite:    
  The single cipher suite selected by the Server from ClientHello.cipher\_suites. For a resumed session, the value of this field comes from the resumed session state. **For security reasons, the server configuration should take precedence**.

- compression\_method:    
  The single compression algorithm selected by the Server from ClientHello.compression\_methods. For a resumed session, the value of this field comes from the resumed session state.

- extensions:    
  The list of extensions. Note that only extensions provided by the Client may appear in the Server’s list.


### 2. Server Certificate

Whenever the negotiated key exchange algorithm requires certificate-based authentication, the Server must send a Certificate. **The Server Certificate message immediately follows ServerHello; typically, the two are in the same network packet, i.e., the same TLS record-layer message**.

If the negotiated cipher suite is DH\_anon or ECDH\_annon, the Server should not send this message, because it may be vulnerable to man-in-the-middle attacks. In other cases, as long as certificate-based authentication is not required, the Server may choose not to send this submessage.

The purpose of this message is:  

This message sends the Server’s certificate chain to the Client.

The certificate must be appropriate for the key exchange algorithm of the negotiated cipher suite and for any negotiated extensions.

The structure of this message is:  
```c
      opaque ASN.1Cert<1..2^24-1>;

      struct {
          ASN.1Cert certificate_list<0..2^24-1>;
      } Certificate;
```
- certificate\_list:    
  This is a sequence (chain) of certificates. **Each certificate must be an ASN.1Cert structure**. The sender's certificate must appear first in the list. Each subsequent certificate must directly certify the one preceding it. Because certificate validation requires root keys to be distributed independently, the self-signed certificate that identifies the root certificate authority can be omitted from the chain, on the assumption that the remote peer must already have it in order to validate the chain in any case. **The root certificate is integrated into the Client's root certificate list and does not need to be included in the Server Certificate message**.

The same message type and result are used for the Client's response to a certificate request message. Note that a Client may send no certificate if it does not have an appropriate certificate to send in response to the Server's authentication request.


The following rules apply to certificates sent by the Server:

-  The certificate type must be X.509v3, unless another type has been explicitly negotiated (such as [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP)).  
-  The end-entity certificate's public key (and associated restrictions) must be compatible with the selected key exchange algorithm.  
-  The "server\_name" and "trusted\_ca\_keys" extensions [[TLSEXT]](https://tools.ietf.org/html/rfc5246#ref-TLSEXT) are used to guide certificate selection.  

|Key Exchange Algorithm|Certificate Type|
|:------:|:-------:|
|RSA <br> RSA\_PSK |   The certificate contains an RSA public key that can be used for key exchange, i.e., with the RSA key exchange algorithm; the certificate must allow the key to be used for encryption (if the key usage extension is present, the keyEncipherment bit must be set, indicating that the server public key is allowed to be used for key exchange) <br>Note: RSA\_PSK is defined in [[TLSPSK]](https://tools.ietf.org/html/rfc5246#ref-TLSPSK)|
|DHE\_RSA<br>ECDHE\_RSA   | The certificate contains an RSA public key, and ECDHE or DHE can be used for key exchange; the certificate must allow the key to be used for signing with the signature scheme and hash algorithm in the Server Key Exchange message (if the key usage extension is present, the digitalSignature bit must be set, so the RSA public key can be used for digital signatures)<br>Note: ECDHE\_RSA is defined in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC)|
|DHE\_DSS    |  The certificate contains a DSA public key; the certificate must allow the key to be used for signing with the hash algorithm that will be used in the Server Key Exchange message|
|DH\_DSS<br> DH\_RSA   | The certificate contains a DSS or RSA public key, and Diffie-Hellman is used for key exchange; if the key usage extension is present, the keyAgreement bit must be set. **Such suites are now rarely seen**.|
|ECDH\_ECDSA <br>ECDH\_RSA |    The certificate contains an ECDSA or RSA public key, and ECDH-capable is used for key exchange. Because this is a static key exchange algorithm, the ECDH parameters and public key are included in the certificate; the public key must use a curve and point format supported by the Client, as described in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC). **Such suites are now rarely seen, because ECDH does not provide forward secrecy**|
|ECDHE\_ECDSA  | The certificate contains an ECDSA-capable public key, and the ECDHE algorithm is used to negotiate the premaster secret; the certificate must allow the key to be used for signing with the hash algorithm that will be used in the Server Key Exchange message; the public key must use a curve and point format supported by the Client. The Client specifies the supported named curves via the ec\_point\_formats extension in the Client Hello message, as described in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC). **This is the most secure and highest-performance cipher suite in TLS 1.2**.|


If the Client provides a "signature\_algorithms" extension, then all certificates provided by the Server must be signed with a hash/signature algorithm pair that appears in this extension. Note that this means a certificate containing a key for one signature algorithm may be signed with a different signature algorithm (for example, an RSA key signed by a DSA key). This differs from TLS 1.1, where the algorithms were required to be the same. **Furthermore, this also shows that the public keys corresponding to the second half of the DH\_DSS, DH\_RSA, ECDH\_ECDSA, and ECDH\_RSA suite names are not used for encryption or digital signatures, so they are unnecessary; the second half also does not constrain the digital signature algorithm chosen by the CA when issuing the certificate**. Fixed DH certificates may be signed with any hash/signature algorithm pair that appears in the extension. DH\_DSS, DH\_RSA, ECDH\_ECDSA, and ECDH\_RSA are historical names.


If the Server has multiple certificates, it selects one based on the criteria above (as well as other criteria, such as the transport-layer endpoint, local configuration, and preferences). If the Server has only one certificate, it should try to make that certificate satisfy these criteria.

Note that many certificates use algorithms or combinations of algorithms that are not compatible with TLS. For example, a certificate that uses an RSASSA-PSS signing key (with the id-RSASSA-PSS OID in SubjectPublicKeyInfo) cannot be used because TLS does not define the corresponding signature algorithm.

Just as cipher suites specify new key exchange methods for the TLS protocol, they also specify the certificate formats and the required encoding of keying information.

At this point, we have covered the Client signature algorithm, the certificate signature algorithm, the cipher suite, and the Server public key. These four are related in some ways and unrelated in others.

- The Client signature algorithm must match the certificate signature algorithm. If the signature\_algorithms extension in Client Hello does not match the certificate signature algorithms in the certificate chain, the handshake fails.  

- The Server public key has no relationship to the certificate signature algorithm. The certificate contains the Server certificate, and the certificate signature algorithm signs the Server public key, but the encryption algorithm of the Server public key can be either RSA or ECDSA.  

- The cipher suite and the Server public key must match each other, because the authentication algorithm in the cipher suite refers to the Server public key type.  

For example, for the TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 cipher suite:

The key agreement algorithm is ECDHE, the authentication algorithm is ECDSA, and the encryption mode is AES\_256\_GCM. Because GCM is an AEAD encryption mode, the overall cipher suite does not require an additional HMAC; SHA384 refers to the PRF algorithm.

**The authentication here does not mean which digital signature algorithm was used to sign the certificate; it refers to the type of the Server public key contained in the certificate**.

Therefore, the signature\_algorithms extension in Client Hello must match the signature algorithms in the certificate chain. If it does not match, the Server public key in the certificate cannot be verified. It must also match the cipher suite negotiated by both sides; otherwise, the Server public key cannot be used.


### 3. Server Key Exchange Message

This message is sent immediately after the Server Certificate message (or, in the case of an anonymous negotiation, immediately after the Server Hello message);

The ServerKeyExchange message is sent by the Server, but only when the Server Certificate message (if sent) does not contain enough data to allow the Client to exchange a premaster secret. This restriction applies to the following key exchange algorithms:
```c
         DHE_DSS
         DHE_RSA
         ECDHE_ECDSA
         ECDHE_RSA
         DH_anon
         ECDH_anon
```
For the first 4 cipher suites above, because they use ephemeral DH/ECDH key exchange algorithms, the certificate does not contain this dynamic DH information (DH parameters and the DH public key), so a Server Key Exchange message is required to transmit this information. The transmitted dynamic DH information must be signed with the Server private key.

For the last 2 cipher suites above, they use anonymous negotiation and static DH/ECDH key exchange algorithms, and they also do not have a certificate message (Server Certificate message), so a Server Key Exchange message is likewise required to transmit this information. The transmitted static DH information must be signed with the Server private key.

Sending ServerKeyExchange is illegal for the following key exchange algorithms:
```c
         RSA
         DH_DSS
         DH_RSA
```
For RSA cipher suites, the client can compute the premaster secret without any additional parameters, then encrypt it with the server's public key and send it to the server. Therefore, the negotiation can be completed without Server Key Exchange.

For DH\_DSS and DH\_RSA, the certificate contains the static DH information, so Server Key Exchange does not need to be sent either. The client and server can each negotiate one half of the premaster secret, and the two halves together form the premaster secret. These two cipher suites are rarely used today. In general, CAs do not include static DH information in certificates, and doing so is not particularly secure.

Other key exchange algorithms, such as those defined in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC), must specify whether ServerKeyExchange is sent; if the message is sent, they must specify its contents.


The purpose of the ServerKeyExchange message is to convey the necessary cryptographic information so that the client can complete the communication of the premaster secret: obtaining a Diffie-Hellman public key that the client can use to complete a key exchange (whose result is the generation of the premaster secret), or a public key for another algorithm.


The structure of the DH parameters is:
    
```c
      enum { dhe_dss, dhe_rsa, dh_anon, rsa, dh_dss, dh_rsa,ec_diffie_hellman
            /* May be extended, e.g., for ECDH -- see [TLSECC] */
           } KeyExchangeAlgorithm;

      struct {
          opaque dh_p<1..2^16-1>;
          opaque dh_g<1..2^16-1>;
          opaque dh_Ys<1..2^16-1>;
      } ServerDHParams;     /* Ephemeral DH parameters */
```
- dh\_p:  
  The prime modulus used for Diffie-Hellman operations, i.e., a large prime number.

- dh\_g:  
  The generator used for Diffie-Hellman operations.

- dh\_Ys:  
  The server’s Diffie-Hellman public key (g^X mod p)

There are mainly six cipher suites for which the server needs to pass additional parameters, as mentioned earlier: DHE\_DSS, DHE\_RSA, ECDHE\_ECDSA, ECDHE\_RSA, DH\_anon, and ECDH\_anon. Other cipher suites cannot be used in the ServerKeyExchange message. **HTTPS deployments generally use these four cipher suites: ECDHE\_RSA, DHE\_RSA, ECDHE\_ECDSA, and RSA**.

>Descriptions related to ECC in TLS are covered in [RFC4492](https://tools.ietf.org/html/rfc4492).

|Key exchange algorithm |  Description  |
|:------|:-----|
|ECDH\_ECDSA | Static ECDH + ECDSA-signed certificate|
|ECDHE\_ECDSA  |   Ephemeral ECDH + ECDSA-signed certificate|
|ECDH\_RSA     |   Static ECDH + RSA-signed certificate|
|ECDHE\_RSA    |   Ephemeral ECDH + RSA-signed certificate |
|ECDH\_anon    |   Anonymous ECDH + no signed certificate |


The structure of the ECDHE parameters is:
```c
        struct {
            ECParameters    curve_params;
            ECPoint         public;
        } ServerECDHParams;
```
The data structure of an ECC public key is as follows:
```c
        struct {
            opaque point <1..2^8-1>;
        } ECPoint;
```
Types of ECC elliptic curves:
```c
        enum { 
            explicit_prime (1), 
            explicit_char2 (2),
            named_curve (3), 
            reserved(248..255) 
        } ECCurveType;
         
        struct {
            opaque a <1..2^8-1>;
            opaque b <1..2^8-1>;
        } ECCurve;  
        
        enum { ec_basis_trinomial, ec_basis_pentanomial } ECBasisType;     
```
All supported named curves:
```c
        enum {
            sect163k1 (1), sect163r1 (2), sect163r2 (3),
            sect193r1 (4), sect193r2 (5), sect233k1 (6),
            sect233r1 (7), sect239k1 (8), sect283k1 (9),
            sect283r1 (10), sect409k1 (11), sect409r1 (12),
            sect571k1 (13), sect571r1 (14), secp160k1 (15),
            secp160r1 (16), secp160r2 (17), secp192k1 (18),
            secp192r1 (19), secp224k1 (20), secp224r1 (21),
            secp256k1 (22), secp256r1 (23), secp384r1 (24),
            secp521r1 (25),
            reserved (0xFE00..0xFEFF),
            arbitrary_explicit_prime_curves(0xFF01),
            arbitrary_explicit_char2_curves(0xFF02),
            (0xFFFF)
        } NamedCurve;
```
Data structure for ECDH parameters:
```c
        struct {
            ECCurveType    curve_type;
            select (curve_type) {
                case explicit_prime:
                    opaque      prime_p <1..2^8-1>;
                    ECCurve     curve;
                    ECPoint     base;
                    opaque      order <1..2^8-1>;
                    opaque      cofactor <1..2^8-1>;
                case explicit_char2:
                    uint16      m;
                    ECBasisType basis;
                    select (basis) {
                        case ec_trinomial:
                            opaque  k <1..2^8-1>;
                        case ec_pentanomial:
                            opaque  k1 <1..2^8-1>;
                            opaque  k2 <1..2^8-1>;
                            opaque  k3 <1..2^8-1>;
                    };
                    ECCurve     curve;
                    ECPoint     base;
                    opaque      order <1..2^8-1>;
                    opaque      cofactor <1..2^8-1>;
                case named_curve:
                    NamedCurve namedcurve;
            };
        } ECParameters;
```
ECCurveType indicates the ECC type. In principle, anyone can define their own elliptic curve formula, base point, and other parameters, but in the TLS/SSL protocol, pre-defined named curves (`NamedCurve`) are generally used, which is also more secure.

`ServerECDHParams` contains the `ECParameters` parameters and the `ECPoint` public key.

Finally, let’s look at the data structure of the `ServerKeyExchange` message:
```c
      struct {
          select (KeyExchangeAlgorithm) {
              case dh_anon:
                  ServerDHParams params;
              case dhe_dss:
              case dhe_rsa:
                  ServerDHParams params;
                  digitally-signed struct {
                      opaque client_random[32];
                      opaque server_random[32];
                      ServerDHParams params;
                  } signed_params;
              case rsa:
              case dh_dss:
              case dh_rsa:
                  struct {} ;
                 /* Message omitted for rsa, dh_dss, and dh_rsa */
              case ec_diffie_hellman:
                  ServerECDHParams    params;
                  Signature           signed_params;
          };
      } ServerKeyExchange;
```
- params:  
  Parameters required for server key exchange.

- signed\_params:  
  For non-anonymous key exchange, this is a signature over the server key exchange parameters.

ServerKeyExchange includes different parameters depending on the KeyExchangeAlgorithm type. For anonymous key exchange, no certificate is required, so no authentication is needed and no certificate is present. For key exchange algorithms starting with DHE, the server needs to send the client the ephemeral DH parameters ServerDHParams and a digital signature. This digital signature includes the random value sent by the client, the random value generated by the server, and ServerDHParams.

RSA, DH\_DSS, and DH\_RSA do not require a ServerKeyExchange message.

For ephemeral ECDH key exchange algorithms, the server needs to send the ServerECDHParams parameters and a signature to the client. The signed data structure is as follows:
```c
          enum { ecdsa } SignatureAlgorithm;

          select (SignatureAlgorithm) {
              case ecdsa:
                  digitally-signed struct {
                      opaque sha_hash[sha_size];
                  };
          } Signature;
          
        ServerKeyExchange.signed_params.sha_hash
            SHA(ClientHello.random + ServerHello.random +
                                              ServerKeyExchange.params);
```
Here, the signature contains the SHA hash of the Client random, the Server random, and `ServerKeyExchange.params`.

If the Client has provided the `"signature_algorithms"` extension, the signature algorithm and hash algorithm must appear in the extension as a pair. Note that inconsistencies are possible here. For example, the Client might offer the `DHE_DSS` key exchange algorithm but omit any combinations paired with DSA in the `"signature_algorithms"` extension. To achieve correct cipher negotiation, the Server must check for cipher suites that may conflict with the `"signature_algorithms"` extension before selecting a cipher suite. This is not an elegant solution; it is only a compromise that minimizes changes to the original cipher suite design.

In addition, the hash and signature algorithms must be compatible with the key in the Server’s end-entity certificate. An RSA key can be used with any permitted hash algorithm, while satisfying any certificate constraints (if any).

### 4. Certificate Request

A non-anonymous Server may optionally request a certificate from the Client, if the mutually selected cipher suite is appropriate. If the ServerKeyExchange message is sent, this message immediately follows the ServerKeyExchange message. If the ServerKeyExchange message is not sent, it follows the Server Certificate message.

The structure of this message is:
```c
        enum {
          rsa_sign(1), 
          dss_sign(2), 
          rsa_fixed_dh(3), 
          dss_fixed_dh(4),
          rsa_ephemeral_dh_RESERVED(5), 
          dss_ephemeral_dh_RESERVED(6),
          fortezza_dms_RESERVED(20), 
          ecdsa_sign(64), 
          rsa_fixed_ecdh(65),
          ecdsa_fixed_ecdh(66),
          (255)
      } ClientCertificateType;
      
      opaque DistinguishedName<1..2^16-1>;

      struct {
          ClientCertificateType certificate_types<1..2^8-1>;
          SignatureAndHashAlgorithm
            supported_signature_algorithms<2^16-1>;
          DistinguishedName certificate_authorities<0..2^16-1>;
      } CertificateRequest;
```
- certificate\_types:      
  A list of certificate types that the client can provide.  
  rsa\_sign: a certificate containing an RSA key  
  dss\_sign: a certificate containing a DSA key  
  rsa\_fixed\_dh: a certificate containing a static DH key  
  dss\_fixed\_dh: a certificate containing a static DH key  

- supported\_signature\_algorithms:  
  A list of hash/signature algorithm pairs for the Server to choose from, in descending order of preference.

- certificate\_authorities:    
  A list of acceptable certificate\_authorities [[X501]](https://tools.ietf.org/html/rfc5246#ref-X501) names, represented in DER-encoded form. These names may specify a desired name for a root CA or a subordinate CA; therefore, this message can be used to describe known roots and the desired authentication space. If the certificate\_authorities list is empty, the Client may send any certificate of the types listed in ClientCertificateType, unless there are external settings to the contrary.

The interaction between the certificate\_types and supported\_signature\_algorithms fields is somewhat complex. certificate\_type has existed in TLS since SSLv3, but it is somewhat underspecified. Much of its functionality has been superseded by supported\_signature\_algorithms. The following three rules should be followed:

- Any certificate provided by the Client must be signed using a hash/signature algorithm pair present in supported\_signature\_algorithms.

- The end-entity certificate provided by the Client must contain a key compatible with certificate\_types. If this key is a signing key, it must be usable with one of the hash/signature algorithm pairs in supported\_signature\_algorithms.

- For historical reasons, the names of some Client certificate types include the algorithm used to sign the certificate. For example, in earlier versions of TLS, rsa\_fixed\_dh meant a certificate signed with RSA that also contained a static DH key. In TLS 1.2, this function is deprecated in favor of supported\_signature\_algorithms, and the certificate type no longer restricts the algorithm used to sign the certificate. For example, if the Server sends the dss\_fixed\_dh certificate type and the {{sha1, dsa}, {sha1, rsa}} signature types, the Client may respond with a certificate containing a static DH key, signed with RSA-SHA1.

>Note: An anonymous Server requesting Client authentication will result in a fatal handshake\_failure alert error.


### 5. Server Hello Done

The ServerHelloDone message has been sent by the Server to indicate the end of the ServerHello and its associated messages. After sending this message, the Server will wait for the response from the Client.

This message means that the Server has finished sending all messages supporting key exchange, and the Client can proceed with its key negotiation, certificate validation, and other steps.

After receiving the ServerHelloDone message, the Client should verify whether the certificate provided by the Server is valid and, if required, further check whether the Server hello parameters are acceptable.

The structure of this message:
```c
        struct { } ServerHelloDone;
```    
  


### 6. Client Certificate

This is the first message sent by the Client after receiving a ServerHelloDone message. This message may only be sent when the Server requests a certificate. If no suitable certificate is available, the Client MUST send a certificate message containing no certificates. That is, the length of the certificate\_list structure is 0. If the Client does not send any certificates, the Server may decide at its discretion whether to continue the handshake without authenticating the Client, or to respond with a fatal handshake\_failure alert message. In addition, if some aspect of the certificate chain is unacceptable (for example, it is not signed by a well-known trusted CA), the Server may decide at its discretion whether to continue the handshake (treating the Client as unauthenticated) or send a fatal alert message.

The data structure of the Client certificate is the same as that of the Server Certificate.

The purpose of the Client Certificate message is to convey the Client’s certificate chain to the Server; the Server uses it to verify the CertificateVerify message (when Client authentication is signature-based) or to compute the premaster secret (for static Diffie-Hellman). The certificate must be appropriate for the key exchange algorithm of the negotiated cipher suite and for any negotiated extensions.

In particular:

- The certificate type must be X.509v3, unless another type has been explicitly negotiated (for example, [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP)).  

- The public key (and associated restrictions) in the end-entity certificate should be compatible with the certificate types listed in CertificateRequest:  

|Client certificate type | Certificate key type |
|:-----:|:-----:|
|rsa\_sign   |  The certificate contains an RSA public key; the certificate must allow this key to be used for signing, and it is used together with the signature scheme and hash algorithm for the certificate verification message.|
|dss\_sign    | The certificate contains a DSA public key; the certificate must allow this key to be used for signing, and it is used together with the hash algorithm for the certificate verification message.|
|ecdsa\_sign   | The certificate contains an ECDSA public key; the certificate must allow this key to be used for signing, and it is used together with the hash algorithm for the certificate verification message; this public key must use a curve and point format supported by the Server.|
|rsa\_fixed\_dh <br>dss\_fixed\_dh  |    The certificate contains a Diffie-Hellman public key; it must use the same parameters as the Server’s key|
| rsa\_fixed\_ecdh <br> ecdsa\_fixed\_ecdh | The certificate contains an ECDH public key; it must use the same curve as the Server’s key and must use a point format supported by the Server|

- If the certificate\_authorities listed in the certificate request is non-empty, one of the certificates in the certificate chain should be issued by one of the listed CAs.  

- The certificate must be signed with an acceptable hash/signature algorithm pair, as described in the [Certificate Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.2_handshake.md#4-certificate-request) section. Note that this relaxes the restrictions on certificate signature algorithms in earlier versions of TLS.  

Note that, as with Server certificates, some certificates use algorithms/algorithm combinations that currently cannot be used with the current TLS.

### 7. Client Key Exchange Message

This message is always sent by the Client. If there is a Client Certificate message, the Client Key Exchange is sent immediately after the Client Certificate message. If there is no Client Certificate message, it must be the first message sent after the Client receives ServerHelloDone.

The meaning of this message is that the premaster secret is established in this message, either transmitted directly after RSA encryption or by transmitting Diffie-Hellman parameters to allow both parties to agree on the same premaster secret.

When the Client uses an ephemeral Diffie-Hellman exponent, this message contains the Client’s Diffie-Hellman public key. If the Client is sending a certificate that contains a static DH exponent (for example, it is performing fixed_dh Client authentication), this message must be sent but must be empty.

The structure of this message:

The options for this message depend on which key exchange method was selected. For the definition of KeyExchangeAlgorithm, see the [Server Key Exchange Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.2_handshake.md#3-server-key-exchange-message) section.


The data structure of the ClientKeyExchange message is as follows:
```c

        enum { implicit, explicit } PublicValueEncoding;
        
        struct {
            select (PublicValueEncoding) {
                case implicit: struct { };
                case explicit: ECPoint ecdh_Yc;
            } ecdh_public;
        } ClientECDiffieHellmanPublic;
        
      struct {
          select (KeyExchangeAlgorithm) {
              case rsa:
                  EncryptedPreMasterSecret;
              case dhe_dss:
              case dhe_rsa:
              case dh_dss:
              case dh_rsa:
              case dh_anon:
                  ClientDiffieHellmanPublic;
              case ec_diffie_hellman: 
                  ClientECDiffieHellmanPublic;
          } exchange_keys;
      } ClientKeyExchange;
```
From the `exchange_keys` cases, we can see that there are mainly three handling paths: `EncryptedPreMasterSecret`, `ClientDiffieHellmanPublic`, and `ClientECDiffieHellmanPublic`. Next, we will analyze the differences among these three handling paths one by one.

### (1) RSA/ECDSA Encrypted Premaster Secret

If RSA is used for key agreement and authentication (an RSA cipher suite), the Client generates a 48-byte premaster secret, encrypts it with the public key in the Server certificate, and sends it as an encrypted premaster secret message. This struct is a variable of the `ClientKeyExchange` message; it is not itself a message.

The structure of this message is:
```c
   struct {
       ProtocolVersion client_version;
       opaque random[46];
   } PreMasterSecret;
```
- client\_version:  
  client\_version is the highest TLS protocol version supported by the Client. This version number is used to prevent downgrade attacks.
  
- random:    
  Immediately following it is a 46-byte random number.
  
After encrypting this 48-byte pre-master secret with the Server’s RSA public key, the Client generates EncryptedPreMasterSecret and sends it back to the Server.

The data structure of EncryptedPreMasterSecret is as follows:
```c
   struct {
       public-key-encrypted PreMasterSecret pre_master_secret;
   } EncryptedPreMasterSecret;
```
- The client\_version field in PreMasterSecret is not the negotiated TLS version, but the version sent in ClientHello. This is done to prevent downgrade attacks. Unfortunately, some older TLS implementations use the negotiated version, so checking the version number can cause interoperability failures with these incorrect Client implementations.  
- The EncryptedPreMasterSecret generated by the Client is only the encrypted result and has no integrity protection; the message may be tampered with. There are two encryption methods: RSAES-PKCS1-v1\_5 and RSAES-OAEP. The latter is more secure, but in TLS 1.2 the former is commonly used.  


After the Server obtains the EncryptedPreMasterSecret, it decrypts it with its own RSA private key. After decryption, it must again verify that the ProtocolVersion in the PreMasterSecret matches the ProtocolVersion sent in ClientHello. If they are not equal, verification fails, and the Server will regenerate the PreMasterSecret according to the rules described below and continue the handshake.

If ClientHello.client\_version is TLS 1.1 or later, the Server implementation must check the version number as described below. If the version number is TLS 1.0 or earlier, the Server implementation should check the version number, but may provide a configurable option to disable this check. Note that if the check fails, the PreMasterSecret should be re-randomized and generated as described below.


Attacks discovered by Bleichenbacher [[BLEI]](https://tools.ietf.org/html/rfc5246#ref-BLEI) and Klima et al. [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) can be used to attack TLS Servers. These attacks indicate whether a particular message, when decrypted, has been formatted as PKCS#1 and contains a valid PreMasterSecret structure, or whether it has the correct version number.

As described by Klima [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03), these weaknesses can be avoided by handling incorrectly formatted message blocks, or by not distinguishing an incorrect version number in a correctly formatted RSA block. In other words:

- 1. Generate a 46-byte random string R;  
- 2. Decrypt the message to recover the plaintext M;  
- 3. If the PKCS#1 padding is incorrect, or the length of message M is not exactly 48 bytes: `pre_master_secret = ClientHello.client_version || R`; otherwise, if `ClientHello.client_version <= TLS 1.0` and version-number checking is explicitly disabled: `pre_master_secret = M`. If neither of the above two cases applies, then `pre_master_secret = ClientHello.client_version || M[2..47]`.  


Note that if the Client used an incorrect version in the original pre\_master\_secret, then the pre\_master\_secret explicitly constructed with ClientHello.client\_version will produce an invalid master\_secret.

Another possible approach is to treat a version-number mismatch as a PKCS#1 formatting error and completely randomize the premaster secret:

- 1. Generate a 46-byte random string R;  
- 2. Decrypt the message to recover the plaintext M;  
- 3. If the PKCS#1 padding is incorrect, or the length of message M is not exactly 48 bytes: `pre_master_secret = R`; otherwise, if `ClientHello.client_version <= TLS 1.0` and version-number checking is explicitly disabled: `pre_master_secret = M`. Otherwise, if the first two bytes of M, M[0..1], are not equal to `ClientHello.client_version`: `premaster secret = R`; if none of the above three cases applies, then `pre_master_secret = M`.  

Although there are no known attacks against this structure, Klima et al. [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) describe some theoretical attacks, so the first structure described is recommended for handling this case.


In all cases, if processing an RSA-encrypted premaster secret message fails, or if the version number is not the expected one, a TLS Server must not generate an alert. Instead, it must continue the handshake with a randomly generated premaster secret. It may be useful for troubleshooting to log the true reason for the failure. However, care must be taken to avoid leaking information to an attacker (for example, through timing, log files, or other channels).

The RSAES-OAEP encryption scheme defined in [[PKCS1]](https://tools.ietf.org/html/rfc5246#ref-PKCS1) is more secure against Bleichenbacher attacks. However, for maximum compatibility with earlier TLS versions, the TLS 1.2 specification uses the RSAES-PKCS1-v1\_5 scheme. If the recommendations above are adopted, few known Bleichenbacher attacks can be effective.

Public-key-encrypted data is represented as a non-transparent vector <0..2^16-1>. Therefore, an RSA-encrypted premaster secret in a ClientKeyExchange message is preceded by two length bytes. These bytes are redundant for RSA because EncryptedPreMasterSecret is the only data in ClientKeyExchange, and its length can be determined unambiguously. The SSLv3 specification does not explicitly specify the encoding of public-key-encrypted data, so many SSLv3 implementations do not include the length bytes; they encode the RSA-encrypted data directly into the ClientKeyExchange message.

TLS 1.2 requires EncryptedPreMasterSecret to be correctly encoded together with the length bytes. The resulting PDU is incompatible with many SSLv3 implementations. Implementers upgrading from SSLv3 must modify their implementations to generate and accept the correct encoding. Implementers who want compatibility with both SSLv3 and TLS must make their implementation behavior depend on the version number.

It is now known that timing-based attacks against TLS are possible, at least when the Client and Server are on the same LAN. Accordingly, implementations that use static RSA keys must use RSA blinding or other techniques resistant to timing attacks, as described in [[TIMING]](https://tools.ietf.org/html/rfc5246#ref-TIMING).


### (2) Computing the Premaster Secret from a Static DH Public Key

If this value is not included in the Client’s certificate, this structure carries the Client’s Diffie-Hellman public key (Yc). The encoding used for Yc is enumerated by PublicValueEncoding. This structure is a variable of the Client key exchange message; it is not itself a message.

The structure of this message is:
```c
        enum { implicit, explicit } PublicValueEncoding;
```
- implicit:  
  If the Client has sent a certificate containing a suitable Diffie-Hellman key (for `fixed_dh` Client authentication), then Yc is implicit and does not need to be sent again. In this case, the Client key exchange message is sent, but it must be empty.

- explicit:  
  Yc needs to be sent.
```c
        struct {
          select (PublicValueEncoding) {
              case implicit: struct {};
              case explicit: opaque dh_Yc<1..2^16-1>;
          } dh_public;
      } ClientDiffieHellmanPublic;
```
- dh\_Yc:   
  The client's Diffie-Hellman public key (Yc). **The DH public key is transmitted in plaintext**. Even if it is transmitted in plaintext and intercepted by a man-in-the-middle, the final master secret still cannot be obtained. For the specific reason, see the analysis in the author's earlier cryptography [article](https://halfrost.com/cipherkey/#diffiehellman).


### (3) Compute the Premaster Secret from the Ephemeral DH Public Key

If the negotiated cipher suite's key exchange algorithm is ECDHE, the Client needs to send the ECDH public key. The struct is as follows:
```c

        struct {
            opaque point <1..2^8-1>;
        } ECPoint;
        
        struct {
            select (PublicValueEncoding) {
                case implicit: struct {};
                case explicit: ECPoint ecdh_Yc;
            } ecdh_public;
        } ClientECDiffieHellmanPublic;                  
```
- ecdh\_Yc:  
  The Client’s ECDH public key (Yc). **The ECDH public key is also transmitted in plaintext**. Even if it is transmitted in plaintext and intercepted by a man-in-the-middle, the attacker still cannot derive the final master secret. For the specific reason, see the analysis in [this cryptography article](https://halfrost.com/asymmetric_encryption/#3diffiehellmanecdh) I wrote previously.
  
For all operations involving ECC, the Server and Client must choose a named curve supported by both sides. The ecc\_curve extension in the Client Hello message specifies the ECC named curves supported by the Client.

### 8. Certificate Verify


This message is used to explicitly verify a Client certificate. It can only be sent when a Client certificate has signing capability (for example, all certificates except those containing fixed Diffie-Hellman parameters). When sent, it must immediately follow the client key exchange message.

The structure of this message is:
```c
   struct {
        digitally-signed struct {
            opaque handshake_messages[handshake_messages_length];
        }
   } CertificateVerify;
```
Here, handshake\_messages refers to all handshake messages sent or received, starting with client hello up to but not including this message, including the type and length fields of the handshake messages. This is the concatenation of all handshake structures (as defined in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B)) so far. Note that this requires both endpoints either to buffer the messages, or to compute running hash values with all available hash algorithms until the hash value for CertificateVerify is computed. The server can minimize this computational cost by providing a restricted set of digest algorithms in the supported\_signature\_algorithms field of the CertificateRequest message.

The hash and signature algorithms used in the signature must be one of the algorithms listed in the supported\_signature\_algorithms field of the CertificateRequest message. In addition, the hash and signature algorithms must be compatible with the client's end-entity certificate. RSA keys may be used with any permitted hash algorithm, subject to any restrictions in the certificate (if any).

Because DSA signatures do not include any secure method for indicating the hash algorithm, using multiple hashes with an arbitrary key introduces a hash substitution risk. Currently, DSA [[DSS]](https://tools.ietf.org/html/rfc5246#ref-DSS) may be used with SHA-1. Future versions of DSS [[DSS-3]](https://tools.ietf.org/html/rfc5246#ref-DSS-3) are expected to allow other digest algorithms to be used with DSA, and to provide guidance on which digest algorithms should be used with each key size. In addition, future versions of [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX) may specify mechanisms that allow certificates to indicate which digest algorithms can be used with DSA.


### 9. Finished

A Finished message is always sent immediately after a change cipher spec message to prove that the key exchange and authentication processes were successful. A change cipher spec message must be received between the other handshake messages and the Finished message.

The Finished message is the first message protected with the newly negotiated algorithms, keys, and secrets. The recipient of the Finished message must verify that its contents are correct. Once a party has sent its Finished message and has received and verified the Finished message from its peer, it may begin sending and receiving application data on the connection.

Structure of the Finished message:
```c
      struct {
          opaque verify_data[verify_data_length];
      } Finished;

      verify_data = 
         PRF(master_secret, finished_label, Hash(handshake_messages))
            [0..verify_data_length-1];
```
- finished\_label:  
  For Finished messages sent by the Client, the string is "client finished". For Finished messages sent by the Server, the string is "server finished".

Hash indicates a hash of the handshake messages. The hash MUST be used as the basis for the PRF. Any cipher suite that defines a different PRF MUST define the Hash used to compute the Finished message.

In versions prior to TLS 1.2, verify\_data was always 12 bytes long. In TLS 1.2, the length of verify\_data depends on the cipher suite. Any cipher suite that does not explicitly specify verify\_data\_length defaults verify\_data\_length to 12. Note that the encoding of this representation is the same as in earlier versions. Future cipher suites may specify other lengths, but the length MUST be at least 12 bytes.

- handshake\_messages:    
  The data from all messages in this handshake (excluding any HelloRequest messages) up to, but not including, this message. This is data visible only at the handshake layer and does not include record-layer headers. It is the concatenation of all handshake structures defined so far in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B).

If a Finished message is not preceded by a ChangeCipherSpec at the appropriate point in the handshake, it is a fatal error.

The value of handshake\_messages includes all handshake messages from ClientHello up to, but not including, the Finished message. The handshake\_messages in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.2_handshake.md#8-certificate-verify) is different because it includes the CertificateVerify message (if sent). Similarly, the handshake\_messages for the Finished message sent by the Client is different from the one sent by the Server, because the second one sent must include the previous one. The Server's Finished message includes the Client's Finished submessage.

Note: ChangeCipherSpec messages, alerts, and any other record types are not handshake messages and are not included in the hash computation. Similarly, HelloRequest messages are also ignored by the handshake hash.


The Finished submessage is the first message protected by TLS record-layer encryption. What is the purpose of the Finished submessage?

In all handshake protocols, none of the submessages are encrypted or protected for integrity. Messages can be easily tampered with, and if such tampering is not checked, insecure attacks can occur. To prevent message tampering during the handshake, both the Client and the Server need to verify the peer's Finished submessage.

If a man-in-the-middle modifies the maximum TLS version supported in the ClientHello to TLS 1.0 during the handshake in an attempt to perform a downgrade attack and exploit vulnerabilities in older TLS versions, the Server receives the tampered ClientHello without knowing whether it has been modified, and therefore negotiates according to TLS 1.0. When the handshake reaches the final step and the Finished submessage is verified, the verification fails: in the ClientHello originally sent by the Client, the maximum supported TLS version was TLS 1.2, so the verify\_data generated from it will certainly differ from the verify\_data computed by the Server using the tampered ClientHello. At this point, the tampering is detected, and the handshake fails.


## IV. An Intuitive Look at the Initial TLS 1.2 Handshake Flow

At this point, we have analyzed all details of the initial TLS 1.2 handshake. In this section, let's summarize the flow above and use Wireshark to get an intuitive feel for the TLS 1.2 protocol.

First, the initial handshake based on the RSA key exchange algorithm:

![](https://img.halfrost.com/Blog/ArticleImage/97_2_3.png)

The handshake begins with the Client sending ClientHello. In this message, the Client reports all the "capabilities" it supports. client\_version indicates the highest TLS version supported by the Client; random indicates the random value generated by the Client, used to generate the pre-master secret, master secret, and key block. Its total length is 32 bytes: the first 4 bytes are a timestamp, and the following 28 bytes are random bytes; cipher\_suites indicates the cipher suites supported by the Client. extensions indicates all extensions supported by the Client.

> This article touches only briefly on extensions, because I plan to organize the extensions involved in TLS 1.2 and TLS 1.3 into a separate article. They are not analyzed in detail in this handshake flow. For a more detailed analysis of extensions, see [“HTTPS: Reviewing the Fundamentals (VI) — Extensions in TLS”]()

After receiving ClientHello, if the Server can continue negotiation, it sends ServerHello; otherwise, it sends Hello Request to renegotiate. In ServerHello, the Server combines the Client's capabilities and selects a protocol version and cipher suite supported by both sides for the next step of the handshake. server\_version indicates the protocol version selected by the Server after negotiation and supported by both sides. random indicates the random value generated by the Server, used to generate the pre-master secret, master secret, and key block. Its total length is 32 bytes: the first 4 bytes are a timestamp, and the following 28 bytes are random bytes; cipher\_suites indicates the cipher suite selected by the Server after negotiation and supported by both sides. extensions indicates the result after the Server processes the Client's extensions.

Once a cipher suite that both sides can satisfy has been negotiated, the Server sends a Certificate message as needed. The Certificate message carries the Server's certificate chain. The purposes of the Certificate message are, first, to verify the Server's identity, and second, to allow the Client to obtain the Server's public key from the certificate according to the negotiated cipher suite. The Client uses the Server's public key and the server's random to generate the pre-master secret.

Because the key exchange algorithm is RSA, after sending the Certificate message, the Server directly sends the ServerHelloDone message.

After receiving ServerHelloDone, the Client starts computing the pre-master secret. The computed pre-master secret is encrypted using the RSA/ECDSA algorithm and sent to the Server via the ClientKeyExchange message. For RSA cipher suites, the pre-master secret is 48 bytes: the first 2 bytes are client\_version, and the remaining 46 bytes are random bytes. After receiving the ClientKeyExchange message, the Server starts computing the master secret and the key block. At the same time, the Client also computes the master secret and key block locally.
 
> Some people say "master secret and session key"; here, the session key and key block mean the same thing. The master secret is generated from the pre-master secret, the client random, and the server random via the PRF function; the session key is generated from the master secret, the client random, and the server random via the PRF function.
>
>session key = key_block = key block. These three mean the same thing; they are just different translations.

Immediately after sending the ClientKeyExchange message, the Client also sends the ChangeCipherSpec message and the Finished message. The Server responds with a ChangeCipherSpec message and a Finished message as well. Once the Finished messages have been verified successfully, the handshake is ultimately successful.

Next, let's look at the initial handshake based on the DH key exchange algorithm:

![](https://img.halfrost.com/Blog/ArticleImage/97_3_0_.png)

The difference between the DH-based key exchange algorithm and RSA-based cipher negotiation lies in the negotiation of DH parameters between the Server and the Client. Here we only cover the additional steps in the DH key exchange process compared with RSA; the rest of the flow is basically the same as the RSA flow.

After the Server sends the Certificate message, it also sends a ServerKeyExchange message, which carries the DH parameters.

Another difference is that the length of the pre-master secret sent to the Server in the ClientKeyExchange message is not 48 bytes. For key agreement based on DH/ECDH algorithms, the key length depends on the public key of the DH/ECDH algorithm.

To help readers understand the TLS 1.2 flow more intuitively, I used Wireshark to capture packets from the TLS handshake between Chrome and my blog. By analyzing the Wireshark capture, let's gain a deeper understanding of the TLS 1.2 handshake. The following example uses the TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 cipher suite:

![](https://img.halfrost.com/Blog/ArticleImage/97_6.png)

The above shows a complete process from the start of the TLS handshake to the TCP four-way connection teardown. Here we focus on all messages where protocol = TLS 1.2. The overall flow is consistent with the DH-based key exchange algorithm analyzed above. Before the TCP four-way teardown, the TLS layer first receives a Close Notify Alert message.

> Some readers may wonder at this point: why is the upper-layer data, after TLS encryption, displayed in plaintext in the packet capture? Is HTTPS insecure? This needs some explanation. I used `export SSLKEYLOGFILE=/Users/XXXX/sslkeylog.log` to save the keys negotiated by ECDHE into a log file. When parsing encrypted upper-layer HTTP/2 packets, the TLS key in the log can be used for decryption. The green area in the figure above is the decrypted HTTP/2 content. I will mention this in HTTP/2-related articles; for now, readers can simply assume that I used certain techniques to parse the encrypted HTTPS content.

Next, let's look at how the data packets are transmitted over the network one by one, starting with ClientHello.

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake message in the TLS record layer is 512 bytes long, of which the ClientHello message occupies 508 bytes. ClientHello indicates that the highest TLS version supported by the Client is TLS 1.2 (0x0303). The Client supports 17 cipher suites, with TLS\_AES\_128\_GCM\_SHA256 preferred. The Session ID length is 32 bytes and is not empty here. The compression algorithm is null. signature\_algorithms indicates that the Client supports 9 pairs of digital signature algorithms.

>By default, TLS compression is disabled, because the CRIME attack can use TLS compression to recover encrypted authentication cookies and achieve session hijacking. In addition, after content compression such as gzip is typically configured, compressing TLS fragments again provides little benefit and consumes extra resources, so TLS compression is generally disabled.

![](https://img.halfrost.com/Blog/ArticleImage/97_8.png)

ClientHello sends the status\_request extension to query OCSP stapling information. It sends the signed\_certificate\_timestamp extension to query SCT information. It sends the application\_layer\_protocol\_negotiation (ALPN) extension to ask whether the server supports the HTTP/2 protocol. The supported\_group extension indicates the elliptic curves supported by the Client. The SessionTicket TLS extension indicates that the Client supports session resumption based on Session Tickets.

Now let's look at the ServerHello message.

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message in the TLS record layer is 82 bytes long, of which the ServerHello message occupies 78 bytes. The Server chooses TLS 1.2 as the version to use for the subsequent handshake flow with the Client. The cipher suite negotiated between the Server and the Client is TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384.

The Server supports HTTP/2 and responds in the ALPN extension.

![](https://img.halfrost.com/Blog/ArticleImage/97_10.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake message in the TLS record layer is 2544 bytes long, of which the Certificate message occupies 2540 bytes. The Certificates certificate chain contains 2 certificates: the Server end-entity certificate is 1357 bytes, and the intermediate certificate is 1174 bytes. The intermediate certificate was issued by Let's Encrypt. Both certificates are signed using the sha256WithRSAEncryption signature algorithm.

![](https://img.halfrost.com/Blog/ArticleImage/97_11.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message in the TLS record layer is 535 bytes long, of which the Certificate Status message occupies 531 bytes. The Server sends the OCSP response to the Client.

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message in the TLS record layer is 116 bytes long, of which the ServerKeyExchange message occupies 112 bytes. Because the negotiated algorithm is ECDHE key exchange, the Server needs to send the ECDH parameters and public key to the Client through the ServerKeyExchange message. Here, the ECC named curve used by ECDHE is x25519. The Server's public key is (62761b5……), the signature algorithm is ECDSA\_secp256r1\_SHA256, and the signature value is (3046022……).

The ServerHelloDone message structure is very simple, as shown above.

![](https://img.halfrost.com/Blog/ArticleImage/97_12.png)

Because this is the ECDHE negotiation algorithm, the Client needs to send an ECC DH public key; the corresponding public key value is (1e58cf……). The public key length is 32 bytes.

The ChangeCipherSpec message structure is very simple. This message is sent to tell the Server that the Client can now use the TLS record-layer protocol for cryptographic protection. The first message to receive cryptographic protection is the Finished message.

The Finished message structure is very simple, as shown above.

![](https://img.halfrost.com/Blog/ArticleImage/97_13.png)

If the Server is using SessionTicket, it generates a new NewSessionTicket and returns it to the Client, then likewise returns the ChangeCipherSpec message and the Finished message.

![](https://img.halfrost.com/Blog/ArticleImage/97_14.png)

When the page is closed, the Server sends a TLS Alert message to the Client; the description in this message is Close Notify. At the same time, the Server sends a FIN packet to start the four-way teardown.


## V. TLS 1.2 Session Resumption


As soon as the Client and Server close the connection, if the HTTPS site is accessed again within a short time, a new connection is required. A new connection introduces network latency and consumes computation on both sides. Is there a way to reuse a previous TLS connection? Yes—this is the TLS session resumption mechanism.

When the Client and Server decide to continue a previous session or duplicate an existing session (instead of negotiating new security parameters), the message flow is as follows:

The Client sends a ClientHello using the ID of the current session to be resumed. The Server checks its session cache for a match. If a match is found and the Server is willing to reestablish the connection under the specified session state, it sends a ServerHello message with the same session ID value. At this point, both the Client and Server must send ChangeCipherSpec messages and then immediately send Finished messages. Once reestablishment is complete, the Client and Server can begin exchanging application-layer data (see the flowchart below). If the session ID does not match, the Server generates a new session ID, and the TLS Client and Server need to perform a full handshake.
```c
      Client                                                Server

      ClientHello                   -------->
                                                       ServerHello
                                                [ChangeCipherSpec]
                                    <--------             Finished
      [ChangeCipherSpec]
      Finished                      -------->
      Application Data              <------->     Application Data
      
```
Session ID is supported by the server and is a standard field in the protocol, so essentially all servers support it. The server stores the session ID along with the negotiated communication information, which consumes relatively more server resources.

### 1. Session Resumption Based on Session ID

When the Client establishes a complete Session with the Server through a full handshake, the Server records information about this Session for use when resuming the session:

- Session identifier:      
  A unique identifier for each session
- Peer certificate:   
  The peer’s certificate, usually empty
- Compression method:   
  Generally not enabled
- Cipher spec:  
  The cipher suite jointly negotiated by the Client and Server
- Master secret:    
  Each session stores a copy of the master secret, **note that this is not the premaster secret**. (Readers can think about why; if you still cannot figure it out, see [“HTTPS Refresher (Part 5) — Key Calculation in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-key-cipher.md))
- Is resumable: 
  Indicates whether the session can be resumed
  
Once the Server has stored the information above, it can recompute the security parameters required by the TLS record layer to encrypt application data.

The process for session resumption based on Session ID is as follows:
```c
      Client                                                Server

      ClientHello                   -------->
                                                       ServerHello
                                                [ChangeCipherSpec]
                                    <--------             Finished
      [ChangeCipherSpec]
      Finished                      -------->
      Application Data              <------->     Application Data
      
```
![](https://img.halfrost.com/Blog/ArticleImage/97_4_.png)

The client detects that the requested website has been requested before; that is, a Session ID exists in memory. When establishing the connection again, it includes the Session ID corresponding to the website in the ClientHello. The server keeps a Session Cache dictionary in memory, where the key is the Session ID and the value is the session information. After receiving the ClientHello, the server checks whether there is related session information based on the Session ID that was passed in. If there is, it allows the client to resume the session and directly sends ChangeCipherSpec and Finished messages. If there is no related session information, it starts a full handshake and generates a new Session ID in the ServerHello to return to the client. When the client receives the ChangeCipherSpec and Finished messages from the server, it means session resumption has succeeded, and it also sends ChangeCipherSpec and Finished messages in response.

Sources of the Session ID:  

- The Session ID generated by the previous full handshake  
- The Session ID from another connection  
- The Session ID of the current connection directly  

Why each parameter in the ClientHello is necessary for session resumption:

- The cipher suite negotiated by the server through the ClientHello must be consistent with the cipher suite in the session; otherwise, session resumption fails and a full handshake is performed.
- The random value in the ClientHello is different from the random value used to resume the previous session. Therefore, even if the session is resumed, because the random value in the ClientHello is different, the key block (session key) generated again through the PRF is also different. This improves security.
- The Session ID in the ClientHello is transmitted in plaintext, so sensitive information should not be included in the Session ID. In addition, the Finished verification in the final step of the handshake is essential to prevent the Session ID from being tampered with.

Finally, note that session resumption depends on the server. Even if the Session ID is correct and the related session information exists in the server’s memory, the server can still require the client to perform a full handshake. In other words, session resumption is not mandatory.

The **advantages** of Session ID-based session resumption are:  

- Reduced network latency: handshake time goes from 2-RTT -> 1-RTT
- Reduced load on both the client and server, and reduced CPU resource consumption for cryptographic operations

The **disadvantages** of Session ID-based session resumption are:  

- The server stores session information, which limits the server’s scalability.
- In a distributed system, if the Session Cache is simply stored in the server’s memory, synchronizing data across multiple machines is also a problem.

Nginx does not officially provide an implementation of a Session Cache that supports distributed servers. Third-party patches can be used, but they also increase security and maintenance costs.

Because of the two disadvantages above, Session Ticket-based session resumption was introduced.


### 2. Session Ticket-based Session Resumption

The alternative to Session ID-based session resumption is to use session tickets. With this approach, except that all state is stored on the client (similar to how HTTP Cookies work), the message flow is the same as with a server-side session cache.

The idea is that the server takes all of its session data (state), encrypts it (the key is known only to the server), and sends it back to the client as a ticket. On subsequent connections, when the client resumes the session, it carries the encrypted information in the session\_ticket extension field of the ClientHello and submits the ticket back to the server. The server checks the integrity of the ticket, decrypts its contents, and then uses the information inside to resume the session.

**For the server, decrypting the ticket yields the master secret**. (Note that this differs from SessionID, where having the Session ID allows the server to obtain the master secret information.) For the client, during the full handshake, when it receives the NewSessionTicket submessage issued by the server, the client stores the Ticket and the corresponding premaster secret locally. During the abbreviated handshake, once the server verifies the ticket and allows the abbreviated handshake, the client uses the locally stored premaster secret to generate the master secret, and ultimately generates the session keys (key block).

This approach can make scaling a server cluster simpler, because without it the Session Cache must be synchronized across nodes in the service cluster. Session tickets require support from both the server and the client. They are an extension field and consume very few server resources.

The advantages of Session Tickets make them especially suitable for the following scenarios:

- Large HTTPS websites with very high traffic, where storing Session information on the server would consume a large amount of memory
- HTTPS website owners want the lifetime of session information to be long enough so that clients use abbreviated handshakes as much as possible
- HTTPS website owners want users to be able to access the site across regions and hosts


The Session Ticket-based session resumption flow is as follows: 


### (1). Obtaining a SessionTicket

The client can obtain a SessionTicket only after performing a full handshake.
```c
      Client                                               Server

      ClientHello
      (empty SessionTicket extension)-------->
                                                      ServerHello
                                   (empty SessionTicket extension)
                                                     Certificate*
                                               ServerKeyExchange*
                                              CertificateRequest*
                                   <--------      ServerHelloDone
      Certificate*
      ClientKeyExchange
      CertificateVerify*
      [ChangeCipherSpec]
      Finished                     -------->
      											         NewSessionTicket
                                               [ChangeCipherSpec]
                                   <--------             Finished
      Application Data             <------->     Application Data
```
The Client includes an empty SessionTicket extension in the extensions of the ClientHello. If the Server supports SessionTicket-based session resumption, it replies with an empty SessionTicket extension in the ServerHello. The Server encrypts and protects the session information, generates a ticket, and sends it to the Client via the NewSessionTicket submessage. **Note that although the NewSessionTicket submessage appears before the ChangeCipherSpec message, it is also an encrypted message**.

After encrypting the session information and sending it to the Client as a ticket, the Server no longer stores any information. The Client stores the received ticket in memory and sends it to the Server whenever it wants to resume the session. If the Server decrypts it and verifies that everything is correct, a shortened handshake can proceed.

### (2). SessionTicket-Based Session Resumption

After the Client obtains the SessionTicket locally, it can use this SessionTicket the next time it wants to perform a shortened handshake.
```c
      Client                                                Server

      ClientHello
      (SessionTicket extension)     -------->
                                                       ServerHello
                                    (empty SessionTicket extension)
                                                  NewSessionTicket
                                                [ChangeCipherSpec]
                                    <--------             Finished
      [ChangeCipherSpec]
      Finished                      -------->
      Application Data              <------->     Application Data
      
```
The Client includes a non-empty SessionTicket extension in the extensions of ClientHello. If the Server supports SessionTicket session resumption, it replies with an empty SessionTicket extension in ServerHello. The Server encrypts and protects the session information, generates a new ticket, and sends it to the Client via the NewSessionTicket submessage. After sending the NewSessionTicket message, it immediately sends the ChangeCipherSpec and Finished messages. After the Client receives these messages, it responds with the ChangeCipherSpec and Finished messages, and session resumption succeeds.

### (3). Server Does Not Support SessionTicket

Some readers may ask: since the Client sent a non-empty SessionTicket extension, why must the Server reply with an empty SessionTicket extension in ServerHello? Because when the Server does not support SessionTicket, ServerHello does not contain a SessionTicket extension. Therefore, whether ServerHello contains a SessionTicket extension distinguishes whether the Server supports SessionTicket.
```c
         Client                                               Server

         ClientHello
         (SessionTicket extension)    -------->
                                                         ServerHello
                                                        Certificate*
                                                  ServerKeyExchange*
                                                 CertificateRequest*
                                      <--------      ServerHelloDone
         Certificate*
         ClientKeyExchange
         CertificateVerify*
         [ChangeCipherSpec]
         Finished                     -------->
                                                  [ChangeCipherSpec]
                                      <--------             Finished
         Application Data             <------->     Application Data
```
If the server does not support SessionTicket, it does not include the SessionTicket TLS extension in the ServerHello response, nor does it send the NewSessionTicket submessage.

### (4). Server Fails to Validate the SessionTicket

If the server fails to validate the SessionTicket, the handshake falls back to a full handshake.
```c
         Client                                               Server

         ClientHello
         (SessionTicket extension) -------->
                                                         ServerHello
                                     (empty SessionTicket extension)
                                                        Certificate*
                                                  ServerKeyExchange*
                                                 CertificateRequest*
                                  <--------          ServerHelloDone
         Certificate*
         ClientKeyExchange
         CertificateVerify*
         [ChangeCipherSpec]
         Finished                 -------->
                                                    NewSessionTicket
                                                  [ChangeCipherSpec]
                                  <--------                 Finished
         Application Data         <------->         Application Data
```
If the Server accepts the ticket but the handshake ultimately fails, the Client should delete the ticket.

The normal SessionTicket-based session resumption flow is shown below:

![](https://img.halfrost.com/Blog/ArticleImage/97_5_.png)


### (5). NewSessionTicket Submessage

This section is mainly based on [[RFC5077]](https://tools.ietf.org/html/rfc5077).

If the ServerHello message contains the Session Ticket TLS extension, an **encrypted NewSessionTicket submessage** must be sent before ChangeCipherSpec. If the ServerHello message does not contain the Session Ticket TLS extension, it indicates that the Server or Client does not want to use the SessionTicket session resumption mechanism.

Because the NewSessionTicket submessage is also considered part of the handshake, it must also be verified in the Finished submessage. **If the Server successfully verifies the ticket sent by the Client, it must also generate a brand-new ticket and send it to the Client via the NewSessionTicket submessage; the Client will use this new SessionTicket next time**.

In the handshake protocol, the introduction of extensions also adds several new handshake messages:  
```c
      struct {
          HandshakeType msg_type;
          uint24 length;
          select (HandshakeType) {
              case hello_request:       HelloRequest;
              case client_hello:        ClientHello;
              case server_hello:        ServerHello;
              case certificate:         Certificate;
              case certificate_url:     CertificateURL;    /* NEW */
              case certificate_status:  CertificateStatus; /* NEW */
              case server_key_exchange: ServerKeyExchange;
              case certificate_request: CertificateRequest;
              case server_hello_done:   ServerHelloDone;
              case certificate_verify:  CertificateVerify;
              case client_key_exchange: ClientKeyExchange;
              case finished:            Finished;
              case session_ticket:      NewSessionTicket; /* NEW */
          } body;
      } Handshake;
```
CertificateURL, CertificateStatus, and NewSessionTicket are three new handshake submessages introduced by extensions.

The data structure of the NewSessionTicket message is as follows:
```c

      struct {
          uint32 ticket_lifetime_hint;
          opaque ticket<0..2^16-1>;
      } NewSessionTicket;
```
One of the most important fields in NewSessionTicket is `ticket_lifetime_hint`. It indicates whether the ticket has expired. The Server validates this field; if it has expired, session resumption cannot be performed. Ticket generation and validation are handled entirely by the Server; the Client merely receives and stores it.

There is no fixed specification for how the Server generates tickets, and different Servers may generate them differently. One important point to keep in mind is forward secrecy, to prevent compromise. RFC5077 recommends generating them as follows:
```c
      struct {
          opaque key_name[16];
          opaque iv[16];
          opaque encrypted_state<0..2^16-1>;
          opaque mac[32];
      } ticket;
```
- key\_name:  
  The key file used to encrypt the ticket
  
- iv:  
  The initialization vector, required by the AES encryption algorithm
  
- encrypted\_state:  
  The ticket details; this stores the session information
  
- mac:  
  The integrity and security protection required by the ticket
  
  
The data structure of the session information is as follows:
```c
      struct {
          ProtocolVersion protocol_version;
          CipherSuite cipher_suite;
          CompressionMethod compression_method;
          opaque master_secret[48];
          ClientIdentity client_identity;
          uint32 timestamp;
      } StatePlaintext;
```
In StatePlaintext, `client_identity` is the Client identifier, and `timestamp` is the ticket expiration time. The data structure of ClientIdentity is as follows:
```c
      enum {
         anonymous(0),
         certificate_based(1),
         psk(2)
     } ClientAuthenticationType;

      struct {
          ClientAuthenticationType client_authentication_type;
          select (ClientAuthenticationType) {
              case anonymous: struct {};
              case certificate_based:
                  ASN.1Cert certificate_list<0..2^24-1>;
              case psk:
                  opaque psk_identity<0..2^16-1>;   /* from [RFC4279] */
          };
       } ClientIdentity;
```
ClientIdentity supports two authentication methods: one based on `certificate_based` certificates, and the other based on `psk` PSK.

Using the given IV, encrypt the actual state information in encrypted\_state with 128-bit AES in CBC mode. Use HMAC-SHA-256 to compute the message authentication code (MAC) over key\_name (16 bytes) and the IV (16 bytes), followed by the length of the encrypted\_state field (2 bytes) and its contents (variable length). This produces the ticket.

## VI. Getting an Intuitive Feel for TLS 1.2 Session Resumption


In this section, I use Wireshark to demonstrate TLS 1.2 session resumption and help readers deepen their understanding.

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

In ServerHello, SessionID is empty, and the SessionTicket TLS extension is also empty. This indicates that the Server will send a NewSessionTicket message in a subsequent sub-message.

The example used here is somewhat special. During the previous handshake, the ClientHello sent by the Client contained a SessionID and an empty SessionTicket TLS extension. After the Server received this extension, it found the session information corresponding to this Session ID in its in-memory Session Cache, responded to the Client with the same SessionID in ServerHello, and also returned an empty SessionTicket TLS extension. With this as the background, what will the result be when performing session resumption?

The final packet-capture screenshot is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/97_23.png)

In the screenshot above, no NewSessionTicket message is visible. Does this mean the session resumption is not based on SessionTicket? Let’s continue looking at the details.

![](https://img.halfrost.com/Blog/ArticleImage/97_24.png)

In ClientHello, we can see that the Client includes both a Session ID and a non-empty SessionTicket TLS extension.

![](https://img.halfrost.com/Blog/ArticleImage/97_25.png)

The Server responds with the same Session ID in ServerHello, which indicates that the corresponding session information can be found in the Session Cache. The ClientHello also sent a SessionTicket here, so why did the Server not respond with any extension message? Could it be because the Server does not support the SessionTicket TLS extension? The Server sent a NewSessionTicket message in the previous handshake, which shows that it does support the SessionTicket TLS extension. So why is there no response here with any SessionTicket-related information? The reason is that the ClientHello contains a SessionID that can be used for session resumption. [[RFC 5077 3.4.  Interaction with TLS Session ID]](https://tools.ietf.org/html/rfc5077) **specifies** that if the Client sends both a Session ID and a SessionTicket TLS extension in ClientHello, the Server must respond using the same Session ID from the ClientHello. However, when validating the SessionTicket, the Server must not rely on this particular Session ID; that is, it must not use the Session ID in ClientHello for session resumption. The Server gives priority to using SessionTicket for session resumption (SessionTicket has higher priority than Session ID). If the Session validation succeeds, it continues by sending ChangeCipherSpec and Finished messages. It does not send a NewSessionTicket message.


![](https://img.halfrost.com/Blog/ArticleImage/97_26.png)

After the Client receives the ChangeCipherSpec and Finished messages sent by the Server, it responds by sending ChangeCipherSpec and Finished messages as well.

![](https://img.halfrost.com/Blog/ArticleImage/97_33_.png)

The figure above summarizes the case where, during session resumption, the Client includes both a Session ID and a SessionTicket TLS extension.


At this point, the first part of this intuitive walkthrough of the TLS handshake process comes to an end. This first part has provided a detailed analysis of all handshake flows in TLS 1.2. The second part, [“HTTPS Refresher (Part 4) — An Intuitive Look at the TLS Handshake Process (Part 2)”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-TLS1.3_handshake.md), focuses on analyzing the TLS 1.3 handshake process and comparing it with the TLS 1.2 handshake process. It also explains what the newly added 0-RTT in TLS 1.3 is all about.

Of course, all content related to key calculation in the TLS 1.2 and TLS 1.3 handshake processes is covered in [“HTTPS Refresher (Part 5) — Key Calculation in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-key-cipher.md), and all content related to extensions in the TLS 1.2 and TLS 1.3 handshake processes is covered in [“HTTPS Refresher (Part 6) — Extensions in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTPS-extensions.md).

------------------------------------------------------

References:

[RFC 5247](https://tools.ietf.org/html/rfc5077)  
[RFC 5077](https://tools.ietf.org/html/rfc5077)    
[RFC 8466](https://tools.ietf.org/html/rfc8466)   
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)        
[HTTPS Practices for Large Websites (Part 2) -- The Impact of HTTPS on Performance](https://developer.baidu.com/resources/online/doc/security/https-pratice-2.html)  

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS-TLS1.2\_handshake/](https://halfrost.com/https_tls1-2_handshake/)