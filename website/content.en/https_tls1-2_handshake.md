+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2019-01-26T23:56:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/97_0_.png"
slug = "https_tls1-2_handshake"
tags = ["Protocol", "HTTPS"]
title = "HTTPS Refresher (III) —— An Intuitive Look at the TLS Handshake (Part 1)"

+++


In the opening article on HTTPS, I analyzed that HTTPS is secure because of the TLS protocol. The TLS protocol that guarantees information security and integrity is the Record Layer protocol. (The Record Layer protocol was analyzed in detail in the previous article.) Readers who finished the previous article may be wondering: where do the keys used for encryption at the TLS protocol layer come from? How exactly do the client and server negotiate the encryption Security Parameters? This article provides a detailed analysis of the similarities and differences between TLS 1.2 and TLS 1.3 at the TLS handshake layer.

Compared with TLS 1.2, the biggest improvements TLS 1.3 makes to the TLS handshake protocol are speed and security. This article focuses on these two aspects.

## I. The Impact of TLS on Network Request Latency

Because HTTPS is deployed, TLS is added at the transport layer, which adds some additional latency to a complete request. Specifically, how many RTTs does it add?

First, let’s look at how many RTTs a request takes from scratch, end to end. Suppose a user visits an HTTPS website, starting from HTTP, until receiving the first HTTPS Response. The request roughly goes through the following steps (using the currently most mainstream TLS 1.2 as an example):


|Process | Time Cost | Total |
| --- | :---: | :---:|
|1. DNS resolution for the website domain | 1-RTT | |
|2. TCP handshake to access the HTTP page |  1-RTT | |
|3. HTTPS redirect 302 |  1-RTT | |
|4. TCP handshake to access the HTTPS page|  1-RTT | |
|5. TLS handshake phase 1: Say Hello| 1-RTT||
|6. 【Certificate validation】DNS resolution for the CA site| 1-RTT||
|7. 【Certificate validation】TCP handshake with the CA site| 1-RTT||
|8. 【Certificate validation】Request OCSP validation|1-RTT||
|9. TLS handshake phase 2: encryption| 1-RTT||
|10. First HTTPS request| 1-RTT||
|||10-RTT|


Among the steps above, 1 and 10 definitely cannot be eliminated. Steps 6, 7, and 8 are optional if the browser has a local cache. The remaining steps are shown in the flowchart below:

![](https://img.halfrost.com/Blog/ArticleImage/97_1.png)

A few notes on the steps above:

When a user visits a web page for the first time, DNS resolution is required. After DNS resolution, the result is cached by the browser. As long as the TTL has not expired, all visits during that period no longer need to spend time on DNS resolution. In addition, if HTTPDNS is used, it also caches the resolved result. Therefore, the first step does not necessarily cost 1-RTT every time.

If the website uses HSTS (HTTP Strict Transport Security), then step 3 above does not exist, because the browser will directly replace the HTTP request with an HTTPS request, preventing man-in-the-middle attacks via redirects.

If the browser has cached DNS resolution results for mainstream CAs, step 6 above is also unnecessary; it can access them directly.

If the browser has disabled OCSP or has a local cache, then steps 7 and 8 above are also unnecessary. 

The 10 steps above are the most complete possible flow. In practice, with various caches, not every step is experienced. If various caches exist and an HSTS policy is in place, the flow that a user must go through every time they visit the web page is as follows:

|Process | Time Cost | Total |
|--- | :---: | :---: |
|1. TCP handshake to access the HTTPS page |  1-RTT | |
|2. TLS handshake phase 1: Say Hello| 1-RTT||
|3. TLS handshake phase 2: encryption| 1-RTT||
|4. First HTTPS request| 1-RTT||
|||4-RTT|

Except for step 4, which cannot be eliminated under any circumstances, what remains is the TCP and TLS handshakes. Reducing TCP to 0-RTT seems somewhat difficult at present. What about TLS? A full TLS 1.2 handshake currently requires 2-RTT. Can it be reduced further? The answer is yes.


## II. Overview of the TLS/SSL Protocol

The TLS handshake protocol runs on top of the TLS Record Layer. Its purpose is to let the server and client agree on the protocol version, select encryption algorithms, optionally authenticate each other, and use public-key cryptography to generate a shared key—that is, to negotiate the Security Parameters needed by the TLS Record Layer for encryption and integrity protection. During negotiation, it must also ensure that information transmitted over the network cannot be tampered with or forged. Because negotiation requires several round trips over the network, a large portion of TLS latency is essentially spent on network RTT.

The component most closely related to encryption parameters is the cipher suite. During negotiation, the client and server need to match cipher suites supported by both sides. Then, after the handshake succeeds, both sides negotiate all encryption parameters based on the cipher suite. The most important encryption parameter is the master secret.

The handshake protocol is mainly responsible for negotiating a session, which consists of the following elements:

- session identifier:      
  An arbitrary sequence of bytes chosen by the server to identify an active or resumable connection state.

- peer certificate:      
  The peer’s X509v3 [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX) certificate. This field may be empty.

- compression method:      
  The compression algorithm used before encryption. This field is not used much in TLS 1.2. In TLS 1.3, this field has been removed.

- cipher spec:      
  Specifies the pseudorandom function (PRF) used to generate key material, the block cipher algorithm (such as null, AES, etc.), and the MAC algorithm (such as HMAC-SHA1). It also defines cryptographic attributes such as mac\_length. This field has been removed from the TLS 1.3 specification, but for compatibility with legacy protocols prior to TLS 1.2, it may still exist in actual use. In TLS 1.3, key derivation uses the HKDF algorithm. The specific differences between PRF and HKDF will be analyzed in detail in a later article.

- master secret:      
  A 48-byte secret shared between the client and server.
  
- is resumable:      
   A flag used to indicate whether the session can be used to initialize a new connection.

These fields are subsequently used to generate security parameters and are used by the Record Layer when protecting application data. By using the resumption capability of the TLS handshake protocol, many connections can be instantiated using the same session.

The TLS handshake protocol consists of the following steps:

- Exchange Hello messages, exchange random values and lists of supported cipher suites, negotiate the cipher suite and corresponding algorithms, and check whether the session is resumable
- Exchange the necessary cryptographic parameters to allow the client and server to negotiate the premaster secret
- Exchange certificates and cryptographic information to allow the client and server to authenticate each other
- Generate the master secret from the premaster secret and the exchanged random values
- Provide security parameters (mainly cipher blocks) to the TLS Record Layer
- Allow the client and server to verify that their peer has computed the same security parameters and that the handshake process has not been tampered with by an attacker


The discussion below follows the order of the initial TLS handshake and session resumption, comparing the differences between TLS 1.2 and TLS 1.3 in the handshake step by step, and using actual network packets captured with Wireshark for analysis and explanation. Finally, it analyzes what the new 0-RTT in TLS 1.3 is all about.


## III. Initial TLS 1.2 Handshake Flow

The main flow of the TLS 1.2 handshake protocol is as follows:

The Client sends a ClientHello message, and the Server must respond with a ServerHello message or generate a validation error and fail the connection. ClientHello and ServerHello are used to establish security-enhanced capabilities between the Client and Server. ClientHello and ServerHello establish the following attributes: protocol version, session ID, cipher suite, and compression algorithm. In addition, two random values are generated and exchanged: ClientHello.random and ServerHello.random.

Up to four messages are used in key exchange: Server Certificate, ServerKeyExchange, Client Certificate, and ClientKeyExchange. New key exchange methods can be produced through these methods: specify a format for these messages and define their usage to allow the Client and Server to agree on a shared key. This key must be long; currently defined key exchange methods exchange keys larger than 46 bytes.

After the hello messages, the Server sends its own certificate in the Certificate message if it is to be authenticated. In addition, if needed, a ServerKeyExchange message is sent (for example, if the Server has no certificate, or if its certificate is used only for signing, an RSA cipher suite will not have a ServerKeyExchange message). If the Server has been authenticated, it may request that the Client send a certificate if appropriate for the selected cipher suite. Next, the Server sends a ServerHelloDone message, which means the hello message phase of the handshake is complete. The Server then waits for the Client’s response. If the Server sent a CertificateRequest message, the Client must send a Certificate message. Now the ClientKeyExchange message needs to be sent; the contents of this message depend on the public-key algorithm selected between the ClientHello and ServerHello. If the Client sent a certificate with signing capability, it needs to send a digitally signed CertificateVerify message to explicitly verify possession of the private key corresponding to the certificate.

At this point, the Client sends a ChangeCipherSpec message and copies the pending Cipher Spec into the current Cipher Spec. Then the Client immediately sends the Finished message after the new algorithm and keys have been determined. In response, the Server sends its own ChangeCipherSpec message, converts the pending Cipher Spec to the current Cipher Spec, and sends the Finished message under the new Cipher Spec. At this point, the handshake is complete, and the Client and Server can begin exchanging application-layer data. Application data must not be sent before the first handshake is complete (before a cipher suite of a non-TLS\_NULL\_WITH\_NULL\_NULL type has been established).

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
\* indicates a conditional dependency message that is optional or not always sent.

**To prevent pipeline stalls, ChangeCipherSpec is a separate TLS protocol content type and, in fact, is not a TLS message**. Therefore, the "[]" in the diagram indicates that ChangeCipherSpec is not a TLS message.

The TLS handshake protocol is a defined higher-level client of the TLS record protocol. This protocol is used to negotiate the security attributes of a session. Handshake messages are encapsulated and passed to the TLS record layer, where they are encapsulated in one or more TLSPlaintext structures, which are processed and transmitted according to the currently active session state.
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
Handshake protocol messages are presented below in the order in which they are sent; sending handshake messages in an unexpected order results in a fatal error and handshake failure. However, unnecessary handshake messages are ignored. Note that the exception to this ordering is that the Certificate message is used twice during the handshake (from Server to Client, then from Client to Server). One message not constrained by this ordering is the HelloRequest message, which may be sent at any time, but if it is received in the middle of a handshake, it should be ignored by the Client.

### 1. Hello Submessages

Messages in the Hello phase are used to exchange security-enhancement capabilities between the Client and the Server. When a new session starts, the record-layer connection-state encryption, hash, and compression algorithms are initialized to null. The current connection state is used for renegotiation messages.


### (1) Hello Request

The HelloRequest message may be sent by the Server at any time.

Meaning of this message: HelloRequest is a simple notification telling the Client that it should begin the renegotiation process. In response, the Client should send a ClientHello message at its convenience. This message is not intended to determine which endpoint is the Client or the Server, but only to initiate a new negotiation. The Server should not send a HelloRequest immediately after the Client initiates a connection.

If the Client is currently negotiating a session, the HelloRequest message is ignored by the Client. If the Client does not want to renegotiate a session, or if the Client wishes to respond with a no\_renegotiation alert message, it may also ignore the HelloRequest message. Because handshake messages are intended to be transmitted before application data, the expectation is that negotiation will begin before a small number of record messages have been received by the Client. If the Server sends a HelloRequest but does not receive a ClientHello in response, it should close the connection with a fatal alert message. After sending a HelloRequest, the Server should not repeat the request until the subsequent handshake negotiation has completed.

Structure of the HelloRequest message:
```c
              struct { } HelloRequest;
```
This message must not be included in the message hash maintained for handshake messages, nor used for Finished messages or CertificateVerify messages.

### (2) Client Hello

When a Client first connects to a Server, the first message it sends must be ClientHello. A Client may also send a ClientHello in response to a HelloRequest, or initiate one itself in order to renegotiate security parameters on an existing connection.
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
  The current time and date according to the sender’s internal clock, represented in standard UNIX 32-bit format (the number of seconds since midnight UTC on January 1, 1970, ignoring leap seconds). The base TLS protocol does not require the clock to be set correctly; higher-level or application-layer protocols may define additional requirements. Note that, for historical reasons, this field is named after Greenwich Mean Time rather than UTC.

- random\_bytes:    
  28 bytes of data generated by a secure random number generator.

- client\_version:    
  The version of the TLS protocol that the Client is willing to use in this session. This should be the latest version supported by the Client (the highest value): TLS 1.2 is 3.3, and TLS 1.3 is 3.4.

- random:    
  A Random structure generated by the Client. The Random structure is shown above. **The client random is very useful: it is used when generating the pre-master secret, when deriving the master secret and key block using the PRF algorithm, and when verifying the complete handshake messages. The primary purpose of the random value is to prevent replay attacks**.

- session\_id:    
  The session ID that the Client wishes to use for this connection. If there is no session\_id, or if the Client wants to generate new security parameters, this field is empty. **This field is mainly used for session resumption**.

- cipher\_suites:    
  The list of cipher suites supported by the Client, ordered with the Client’s most preferred suite first. If the session\_id field is non-empty (meaning this is a session resumption request), this vector must contain at least the cipher\_suite from that session. The possible values of the cipher\_suites field are as follows:
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
  This is the list of compression algorithms supported by the Client, ordered by the Client’s preference. If the session\_id field is not empty (meaning this is a session resumption request), it must include the compression\_method from that session. This vector must include, and all implementations must also support, CompressionMethod.null. Therefore, a Client and Server will be able to agree on a compression algorithm.

- extensions:    
  Clients can request extended Server functionality by sending data in the extensions field. **As with extensions in certificates, the TLS/SSL protocol also supports extensions, enabling greater extensibility without modifying the protocol**.

If a Client uses an extension to request additional functionality, and the Server does not support that functionality, the Client may abort the handshake. A Server must accept ClientHello messages with or without the extensions field, and (as with all other messages) it must verify that the amount of data in the message exactly matches one of the valid formats; if not, it must send a fatal "decode\_error" alert message.

After sending the ClientHello message, the Client waits for the ServerHello message. Any handshake message returned by the Server, except HelloRequest, is treated as a fatal error.

TLS allows extensions to be added in the extensions block after the compression\_methods field. The presence of extensions can be detected by checking whether there are extra bytes after compression\_methods at the end of the ClientHello. Note that this method of detecting optional data differs from normal TLS variable-length fields, but it enables interoperability with TLS implementations from before extensions were defined.


The ClientHello message contains a variable-length Session ID session identifier. If non-empty, this value identifies a session between the same Client and Server whose Server security parameters the Client wishes to reuse.

The Session ID session identifier may come from an earlier connection, the current connection, or another currently active connection. The second option is useful if the Client simply wants to update the random data structures and derive values from a connection; the third option makes it possible to establish several independent secure connections without repeating the full handshake protocol. These independent connections may be established sequentially or concurrently. A Session ID becomes valid when both sides have exchanged Finished messages and the handshake negotiation is complete, and remains valid until it is removed due to expiration or because a fatal error is encountered on a connection associated with the session. The actual contents of the Session ID are defined by the Server.
```c
       opaque SessionID<0..32>;
```
Because the Session ID is not encrypted or directly protected by a MAC during transmission, the server must never place confidential information in the Session ID session identifier, nor rely on the contents of a forged session identifier; doing so would violate security principles. (Note that the handshake contents as a whole, including the Session ID, are protected by the Finished messages exchanged at the end of the handshake.)

The cipher suite list is passed from the client to the server in the ClientHello message. It contains the cipher algorithms supported by the client, in the client’s order of preference (most preferred first). Each cipher suite defines a key exchange algorithm, a block cipher algorithm (including key length), a MAC algorithm, and a pseudorandom function (PRF). The server selects one cipher suite. If there is no acceptable choice, it returns a handshake failure alert message and closes the connection. If the list contains cipher suites that the server does not recognize, support, or wish to use, the server must ignore them and process the remaining entries normally.
```c
      uint8 CipherSuite[2];    /* Cryptographic suite selector */
```
ClientHello contains the list of compression methods supported by the Client, ordered according to the Client’s preference.


### (3) Server Hello


When the Server can find an acceptable set of algorithms, it sends this message in response to the ClientHello message. If it cannot find such a set, it sends a handshake failure alert message in response.

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
  This field contains the lower version proposed by the Client in the ClientHello message and the highest version supported by the Server. TLS 1.2 is version 3.3, and TLS 1.3 is 3.4.


- random:      
  This structure is generated by the Server and must be independent of `ClientHello.random`. **Like the Client’s random value, this value is very useful. It is used when generating the pre-master secret, when using the PRF algorithm to derive the master secret and key block, and when verifying message integrity. The main purpose of the random value is to prevent replay attacks**.

- session\_id:      
  This is the identifier of the session corresponding to this connection. If `ClientHello.session_id` is non-empty, the Server will look for a match in its session cache. If a match is found and the Server is willing to use the specified session state to establish a new connection, the Server returns the same value provided by the Client. This means a session has been resumed and specifies that both parties must continue communication after the Finished messages. Otherwise, this field contains a different value to identify a new session. The Server returns an empty `session_id` to indicate that the session will not be cached and therefore cannot be resumed. If a session is resumed, it must use the originally negotiated cipher suite. Note that the Server is not required to resume any session, even if it previously provided a `session_id`. The Client must be prepared to perform a full negotiation in any handshake, including negotiating a new cipher suite.
  
- cipher\_suite:    
  The single cipher suite selected by the Server from `ClientHello.cipher_suites`. For a resumed session, the value of this field comes from the resumed session state. **For security reasons, the server configuration should take precedence**.

- compression\_method:    
  The single compression algorithm selected by the Server from `ClientHello.compression_methods`. For a resumed session, the value of this field comes from the resumed session state.

- extensions:    
  The list of extensions. Note that only extensions provided by the Client can appear in the Server’s list.


### 2. Server Certificate

Whenever the negotiated key exchange algorithm requires certificates for authentication, the Server must send a Certificate. **The Server Certificate message immediately follows ServerHello; typically, the two are in the same network packet, that is, in the same TLS record-layer message**.

If the negotiated cipher suite is `DH_anon` or `ECDH_annon`, the Server should not send this message, because it may be subject to man-in-the-middle attacks. In other cases, as long as certificate-based authentication is not required, the Server may choose not to send this submessage.

The purpose of this message is:  

This message passes the Server’s certificate chain to the Client.

The certificate must be appropriate for the key exchange algorithm of the negotiated cipher suite and for any negotiated extensions.

The structure of this message is:
```c
      opaque ASN.1Cert<1..2^24-1>;

      struct {
          ASN.1Cert certificate_list<0..2^24-1>;
      } Certificate;
```
- certificate\_list:    
  This is a sequence (chain) of certificates. **Each certificate must be an ASN.1Cert structure**. The sender's certificate must appear first in the list. Each subsequent certificate must directly certify the one preceding it. Under the assumption that the remote peer must already possess it in order to validate the chain in any case, and because certificate validation requires the root key to be distributed independently, the self-signed certificate that specifies the root certification authority may be omitted from the chain. **The root certificate is integrated into the Client's root certificate list, so it does not need to be included in the Server certificate message**.

The same message type and result are used for the Client's response to a certificate request message. Note that a Client may send no certificate if it does not have a suitable certificate to send in response to the Server's authentication request.


The following rules apply to certificates sent by the Server:

-  The certificate type must be X.509v3 unless another type has been explicitly negotiated (such as [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP)).  
-  The end-entity certificate's public key (and associated constraints) must be compatible with the selected key exchange algorithm.  
-  The "server\_name" and "trusted\_ca\_keys" extensions [[TLSEXT]](https://tools.ietf.org/html/rfc5246#ref-TLSEXT) are used to guide certificate selection.  

|Key exchange algorithm|Certificate type|
|:------:|:-------:|
|RSA <br> RSA\_PSK |   The certificate contains an RSA public key that can be used for key negotiation, i.e., with the RSA key exchange algorithm; the certificate must allow the key to be used for encryption (if the key usage extension is present, the keyEncipherment bit must be set, indicating that the server public key may be used for key negotiation) <br>Note: RSA\_PSK is defined in [[TLSPSK]](https://tools.ietf.org/html/rfc5246#ref-TLSPSK)|
|DHE\_RSA<br>ECDHE\_RSA   | The certificate contains an RSA public key, and ECDHE or DHE can be used for key agreement; the certificate must allow the key to be used for signing with the signature mechanism and hash algorithm in the Server Key Exchange message (if the key usage extension is present, the digitalSignature bit must be set, so the RSA public key can be used for digital signatures)<br>Note: ECDHE\_RSA is defined in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC)|
|DHE\_DSS    |  The certificate contains a DSA public key; the certificate must allow the key to be used for signing with the hash algorithm that will be used in the Server Key Exchange message|
|DH\_DSS<br> DH\_RSA   | The certificate contains a DSS or RSA public key, and Diffie-Hellman is used for key agreement; if the key usage extension is present, the keyAgreement bit must be set. **This type of suite is now very rare**.|
|ECDH\_ECDSA <br>ECDH\_RSA |    The certificate contains an ECDSA or RSA public key, and ECDH-capable is used for key agreement. Because this is a static key agreement algorithm, the ECDH parameters and public key are included in the certificate; the public key must use a curve and point format supported by the Client, as described in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC). **This type of suite is now very rare, because ECDH does not support forward secrecy**|
|ECDHE\_ECDSA  | The certificate contains an ECDSA-capable public key, and the ECDHE algorithm is used to negotiate the pre-master secret; the certificate must allow the key to be used for signing with the hash algorithm that will be used in the Server Key Exchange message; the public key must use a curve and point format supported by the Client. The Client specifies the supported named curves through the ec\_point\_formats extension in the Client Hello message, as described in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC). **This is the most secure and highest-performance cipher suite in TLS 1.2**.|


If the Client provides a "signature\_algorithms" extension, all certificates provided by the Server must be signed by one of the hash/signature algorithm pairs that appears in this extension. Note that this means a certificate containing a key for one signature algorithm may be signed by a different signature algorithm (for example, an RSA key signed by a DSA key). This differs from TLS 1.1, which required the algorithms to be the same. **This further shows that the public keys corresponding to the second halves of the DH\_DSS, DH\_RSA, ECDH\_ECDSA, and ECDH\_RSA suites are not used for encryption or digital signatures, and therefore have no need to exist; the second half also does not constrain the digital signature algorithm selected by the CA when issuing the certificate**. Fixed DH certificates may be signed by any hash/signature algorithm pair that appears in the extension. DH\_DSS, DH\_RSA, ECDH\_ECDSA, and ECDH\_RSA are historical names.


If the Server has multiple certificates, it selects one based on the criteria above (as well as other criteria such as the transport-layer endpoint, local configuration and preferences, etc.). If the Server has only one certificate, it should attempt to make that certificate satisfy these criteria.

Note that many certificates use algorithms or combinations of algorithms that are not compatible with TLS. For example, a certificate using an RSASSA-PSS signing key (the id-RSASSA-PSS OID in SubjectPublicKeyInfo) cannot be used because TLS does not define the corresponding signature algorithm.

Just as cipher suites specify new key exchange methods for the TLS protocol, they also specify the certificate formats and the required encoding of keying information.

At this point, we have covered the Client signature algorithms, certificate signature algorithms, cipher suite, and Server public key. These four are related in some ways and unrelated in others.

- The Client signature algorithms must match the certificate signature algorithms. If the signature\_algorithms extension in the Client Hello does not match the certificate signature algorithms in the certificate chain, the handshake fails.  

- The Server public key has no relationship to the certificate signature algorithm. The certificate contains the Server certificate, and the certificate signature algorithm signs the Server public key, but the encryption algorithm of the Server public key may be RSA or ECDSA.  

- The cipher suite and the Server public key must match each other, because the authentication algorithm in the cipher suite refers to the Server public key type.  

For example, for the TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 cipher suite:

The key agreement algorithm is ECDHE, the authentication algorithm is ECDSA, and the encryption mode is AES\_256\_GCM. Because GCM is an AEAD encryption mode, the entire cipher suite does not require an additional HMAC; SHA384 refers to the PRF algorithm.

**The authentication here does not refer to which digital signature algorithm was used to sign the certificate, but rather to what type of public key the Server public key contained in the certificate is**.

Therefore, the signature\_algorithms extension in the Client Hello must match the signature algorithms in the certificate chain. If it does not match, the Server public key in the certificate cannot be verified. It must also match the cipher suite negotiated by both sides; if it does not match, the Server public key cannot be used.


### 3. Server Key Exchange Message

This message is sent immediately after the Server certificate message (or, in the case of anonymous negotiation, immediately after the Server Hello message);

The ServerKeyExchange message is sent by the Server, but only when the Server certificate message (if sent) does not contain enough data to allow the Client to exchange a pre-master secret. This restriction holds for the following key exchange algorithms:
```c
         DHE_DSS
         DHE_RSA
         ECDHE_ECDSA
         ECDHE_RSA
         DH_anon
         ECDH_anon
```
For the first 4 cipher suites above, because they use ephemeral DH/ECDH key agreement algorithms, the certificate does not contain this dynamic DH information (DH parameters and the DH public key), so the Server Key Exchange message must be used to convey this information. The dynamic DH information being conveyed must be signed with the Server’s private key.

For the last 2 cipher suites above, they use anonymous negotiation and static DH/ECDH key agreement algorithms, and they also do not have a certificate message (Server Certificate message), so the Server Key Exchange message is likewise required to convey this information. The static DH information being conveyed must be signed with the Server’s private key.

Sending ServerKeyExchange is illegal for the following key exchange algorithms:
```c
         RSA
         DH_DSS
         DH_RSA
```
For RSA cipher suites, the Client can compute the premaster secret without any additional parameters, then encrypt it with the Server's public key and send it to the Server. Therefore, negotiation can be completed without Server Key Exchange.

For DH\_DSS and DH\_RSA, the certificate contains static DH information, so there is likewise no need to send Server Key Exchange. The Client and Server can each negotiate one half of the premaster secret, and combining them yields the premaster secret. These two cipher suites are rarely used today; CAs generally do not include static DH information in certificates, and it is not very secure.

Other key exchange algorithms, such as those defined in [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC), must specify whether ServerKeyExchange is sent; if the message is sent, its contents must also be specified.


The purpose of the ServerKeyExchange message is to convey the necessary cryptographic information so that the Client can complete the premaster-secret exchange: obtaining a Diffie-Hellman public key that the Client can use to complete a key exchange (the result of which is generation of the premaster secret), or a public key for another algorithm.


The structure of the DH parameters is:
    
```c
      enum { dhe_dss, dhe_rsa, dh_anon, rsa, dh_dss, dh_rsa,ec_diffie_hellman
            /* can be extended, e.g., for ECDH -- see [TLSECC] */
           } KeyExchangeAlgorithm;

      struct {
          opaque dh_p<1..2^16-1>;
          opaque dh_g<1..2^16-1>;
          opaque dh_Ys<1..2^16-1>;
      } ServerDHParams;     /* ephemeral DH parameters */
```
- dh\_p:  
  The prime modulus used for Diffie-Hellman operations, i.e., a large prime number.

- dh\_g:  
  The generator used for Diffie-Hellman operations.

- dh\_Ys:  
  The Server’s Diffie-Hellman public key (g^X mod p)

There are mainly six cipher suites for which the Server needs to pass additional parameters. As mentioned earlier, these are DHE\_DSS, DHE\_RSA, ECDHE\_ECDSA, ECDHE\_RSA, DH\_anon, and ECDH\_anon. Other cipher suites cannot be used in the ServerKeyExchange message. **HTTPS deployments generally use these four cipher suites: ECDHE\_RSA, DHE\_RSA, ECDHE\_ECDSA, and RSA**.

>Descriptions related to ECC in TLS can be found in [RFC4492](https://tools.ietf.org/html/rfc4492).

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
`ECCurveType` represents the ECC type. In principle, anyone can specify parameters such as the elliptic curve equation and base point themselves, but in the TLS/SSL protocol, pre-defined named curves (`NamedCurve`) are generally used, which is also more secure.

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
                 /* message omitted for rsa, dh_dss, and dh_rsa */
              case ec_diffie_hellman:
                  ServerECDHParams    params;
                  Signature           signed_params;
          };
      } ServerKeyExchange;
```
- params:  
  Parameters required for Server key exchange.

- signed\_params:  
  For non-anonymous key exchange, this is a signature over the Server key exchange parameters.

ServerKeyExchange includes different parameters depending on the KeyExchangeAlgorithm type. For anonymous negotiation, no certificate is required, so no authentication is needed and there is no certificate. For negotiation algorithms starting with DHE, the Server needs to send dynamic DH parameters, ServerDHParams, and a digital signature to the Client. This digital signature includes the random number sent by the Client, the random number generated by the Server, and ServerDHParams.

RSA, DH\_DSS, and DH\_RSA do not require a ServerKeyExchange message.

For a dynamic ECDH negotiation algorithm, the Server needs to send the ServerECDHParams parameters and the signature to the Client. The data structure of the signature is as follows:
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
The signature here contains the SHA hash of the Client random, the Server random, and `ServerKeyExchange.params`.

If the Client has already provided the "signature\_algorithms" extension, the signature algorithm and hash algorithm must appear as a pair in the extension. Note that inconsistencies are possible here. For example, the Client might offer the DHE\_DSS key exchange algorithm but omit any combinations paired with DSA in the "signature\_algorithms" extension. To achieve correct cipher negotiation, the Server must check for cipher suites that may conflict with the "signature\_algorithms" extension before selecting a cipher suite. This is not an elegant solution; it is only a compromise that minimizes changes to the original cipher suite design.

In addition, the hash and signature algorithms must be compatible with the key in the Server’s end-entity certificate. RSA keys can be used with any permitted hash algorithm, while satisfying any certificate constraints, if present.

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
  A list of acceptable certificate\_authorities [[X501]](https://tools.ietf.org/html/rfc5246#ref-X501) names, represented in DER-encoded form. These names may specify a desired name for a root CA or a subordinate CA; therefore, this message can be used to describe known roots and the desired authentication space. If the certificate\_authorities list is empty, the Client may send any certificate of the types listed in ClientCertificateType, unless there is some external arrangement to the contrary.

The interaction between the certificate\_types and supported\_signature\_algorithms fields is somewhat complex. certificate\_type has existed in TLS since SSLv3, but is somewhat underspecified. Much of its functionality has been superseded by supported\_signature\_algorithms. The following three rules should be followed:

- Any certificate provided by the Client must be signed using a hash/signature algorithm pair present in supported\_signature\_algorithms.

- The end-entity certificate provided by the Client must contain a key compatible with certificate\_types. If this key is a signing key, it must be usable with one of the hash/signature algorithm pairs in supported\_signature\_algorithms.

- For historical reasons, some Client certificate type names include the algorithm used to sign the certificate. For example, in earlier versions of TLS, rsa\_fixed\_dh meant a certificate signed with RSA that also contained a static DH key. In TLS 1.2, this functionality is superseded by supported\_signature\_algorithms, and the certificate type no longer constrains the algorithm used to sign the certificate. For example, if the Server sends the dss\_fixed\_dh certificate type and the {{sha1, dsa}, {sha1, rsa}} signature types, the Client may respond with a certificate containing a static DH key, signed with RSA-SHA1.

>Note: An anonymous Server requesting Client authentication will result in a fatal handshake\_failure alert.


### 5. Server Hello Done

The ServerHelloDone message is sent by the Server to indicate the end of the ServerHello and its associated messages. After sending this message, the Server will wait for a response from the Client.

This message means that the Server has finished sending all messages supporting the key exchange, and the Client can proceed with its key negotiation, certificate validation, and other steps.

After receiving the ServerHelloDone message, the Client should verify that the certificate provided by the Server is valid, if required, and should also further check whether the Server hello parameters are acceptable.

The structure of this message:
```c
        struct { } ServerHelloDone;
```    
  


### 6. Client Certificate

This is the first message sent by the Client after receiving a ServerHelloDone message. This message can be sent only when the Server requests a certificate. If no suitable certificate is available, the Client MUST send a certificate message containing no certificates. That is, the length of the certificate\_list structure is 0. If the Client sends no certificate, the Server may decide whether to continue the handshake without authenticating the Client, or to respond with a fatal handshake\_failure alert. In addition, if some aspect of the certificate chain is unacceptable (for example, it is not signed by a well-known trusted CA), the Server may decide whether to continue the handshake (treating the Client as unauthenticated) or send a fatal alert.

The data structure of the Client certificate is the same as that of the Server Certificate.

The purpose of the Client Certificate message is to convey the Client’s certificate chain to the Server; the Server uses it to verify the CertificateVerify message (when Client authentication is signature-based) or to compute the premaster secret (for static Diffie-Hellman). The certificate MUST be appropriate for the key exchange algorithm of the negotiated cipher suite and for any negotiated extensions.

In particular:

- The certificate type MUST be X.509v3, unless some other type has been explicitly negotiated (for example, [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP)).  

- The end-entity certificate’s public key (and associated constraints) SHOULD be compatible with the certificate types listed in CertificateRequest:  

|Client certificate type | Certificate key type |
|:-----:|:-----:|
|rsa\_sign   |  The certificate contains an RSA public key; the certificate MUST allow this key to be used for signing, and it is used together with the signature scheme and hash algorithm for the certificate verify message.|
|dss\_sign    | The certificate contains a DSA public key; the certificate MUST allow this key to be used for signing, and it is used together with the hash algorithm for the certificate verify message.|
|ecdsa\_sign   | The certificate contains an ECDSA public key; the certificate MUST allow this key to be used for signing, and it is used together with the hash algorithm for the certificate verify message; this public key MUST use a curve and point format supported by the Server.|
|rsa\_fixed\_dh <br>dss\_fixed\_dh  |    The certificate contains a Diffie-Hellman public key; it MUST use the same parameters as the Server’s key.|
| rsa\_fixed\_ecdh <br> ecdsa\_fixed\_ecdh | The certificate contains an ECDH public key; it MUST use the same curve as the Server’s key and MUST use a point format supported by the Server.|

- If the certificate\_authorities listed in the certificate request is non-empty, one certificate in the certificate chain SHOULD be issued by one of the listed CAs.  

- The certificate MUST be signed using an acceptable hash/signature algorithm pair, as described in the [Certificate Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#4-certificate-request) section. Note that this relaxes the restrictions on certificate signature algorithms in earlier versions of TLS.  

Note that, as with Server certificates, some certificates use algorithms or algorithm combinations that cannot currently be used with TLS.

### 7. Client Key Exchange Message

This message is always sent by the Client. If there is a Client Certificate message, the Client Key Exchange message is sent immediately after the Client Certificate message. If there is no Client Certificate message, it MUST be the first message sent after the Client receives ServerHelloDone.

The meaning of this message is that the premaster secret is established in it, either by being transmitted directly after RSA encryption, or by transmitting Diffie-Hellman parameters that allow both parties to agree on the same premaster secret.

When the Client uses an ephemeral Diffie-Hellman exponent, this message contains the Client’s Diffie-Hellman public key. If the Client is sending a certificate that contains a static DH exponent (for example, it is performing fixed_dh Client authentication), this message MUST be sent but MUST be empty.

The structure of this message:

The options for this message depend on which key exchange method was selected. For the definition of KeyExchangeAlgorithm, see the [Server Key Exchange Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#3-server-key-exchange-message) section.


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
From the cases in exchange\_keys, you can see that there are three main handling paths: EncryptedPreMasterSecret, ClientDiffieHellmanPublic, and ClientECDiffieHellmanPublic. Next, we will analyze the differences among these three handling paths in order.

### (1) RSA/ECDSA-encrypted premaster secret

If RSA is used for key agreement and authentication (an RSA cipher suite), the Client generates a 48-byte premaster secret, encrypts it with the public key in the Server certificate, and sends it as an encrypted premaster secret message. This struct is a variable in the ClientKeyExchange message; it is not itself a message.

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
  
After encrypting this 48-byte pre-master secret with the Server's RSA public key to generate EncryptedPreMasterSecret, the Client sends it back to the Server.

The data structure of EncryptedPreMasterSecret is as follows:
```c
   struct {
       public-key-encrypted PreMasterSecret pre_master_secret;
   } EncryptedPreMasterSecret;
```
- The client\_version field in PreMasterSecret is not the negotiated TLS version, but the version passed in ClientHello. This is done to prevent downgrade attacks. Unfortunately, some older TLS implementations used the negotiated version, so checking the version number can cause interoperability failures with these incorrect Client implementations.  
- The EncryptedPreMasterSecret generated by the Client is merely the encrypted result and has no integrity protection, so the message may be tampered with. There are two encryption methods: RSAES-PKCS1-v1\_5 and RSAES-OAEP. The latter is more secure, but in TLS 1.2 the former is commonly used.  


After the Server obtains the EncryptedPreMasterSecret, it decrypts it with its own RSA private key. After decryption, it must again verify that the ProtocolVersion in the PreMasterSecret matches the ProtocolVersion passed in ClientHello. If they are not equal, validation fails, and the Server regenerates the PreMasterSecret according to the rules described below and continues the handshake.

If ClientHello.client\_version is TLS 1.1 or higher, the Server implementation must check the version number as described below. If the version number is TLS 1.0 or earlier, the Server implementation should check the version number, but may have a configurable option to disable this check. Note that if the check fails, the PreMasterSecret should be re-randomized and generated as described below.


Attacks discovered by Bleichenbacher [[BLEI]](https://tools.ietf.org/html/rfc5246#ref-BLEI) and Klima et al.[[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) can be used against TLS Servers. These attacks indicate whether a particular message, when decrypted, has been formatted as PKCS#1 and contains a valid PreMasterSecret structure, or whether it has the correct version number.

As described by Klima [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03), these weaknesses can be avoided by handling incorrectly formatted message blocks, or by not distinguishing an incorrect version number in a correctly formatted RSA block. In other words:

- 1. Generate a 46-byte random string R;  
- 2. Decrypt the message to recover the plaintext M;  
- 3. If the PKCS#1 padding is incorrect, or the length of message M is not exactly 48 bytes: `pre_master_secret = ClientHello.client_version || R`; otherwise, if `ClientHello.client_version <= TLS 1.0` and version checking is explicitly disabled: `pre_master_secret = M`. If neither of the above two cases applies, then `pre_master_secret = ClientHello.client_version || M[2..47]`.  


Note that if the Client used an incorrect version in the original pre\_master\_secret, then the pre\_master\_secret explicitly constructed using ClientHello.client\_version will produce an invalid master\_secret.

Another alternative is to treat a version mismatch as a PKCS-1 formatting error and fully randomize the premaster secret:

- 1. Generate a 46-byte random string R;  
- 2. Decrypt the message to recover the plaintext M;  
- 3. If the PKCS#1 padding is incorrect, or the length of message M is not exactly 48 bytes: `pre_master_secret = R`; otherwise, if `ClientHello.client_version <= TLS 1.0` and version checking is explicitly disabled: `pre_master_secret = M`. Otherwise, if the first two bytes of M, M[0..1], are not equal to `ClientHello.client_version`: `premaster secret = R`; if none of these three cases applies, then `pre_master_secret = M`.  

Although there are no known attacks against this construction, Klima et al. [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) describe some theoretical attacks, so the first construction described is recommended for handling this case.


In any case, when processing an RSA-encrypted premaster secret message fails, or when the version number is not the expected one, a TLS Server must not generate an alert. Instead, it must continue the handshake using a randomly generated premaster secret. It may be helpful for troubleshooting to log the real reason for the failure. However, care must be taken to avoid leaking information to an attacker (for example, through timing, log files, or other channels).

The RSAES-OAEP encryption scheme defined in [[PKCS1]](https://tools.ietf.org/html/rfc5246#ref-PKCS1) is more secure against Bleichenbacher attacks. However, to maximize compatibility with earlier TLS versions, the TLS 1.2 specification uses the RSAES-PKCS1-v1\_5 scheme. If the recommendations above are adopted, few known Bleichenbacher attacks are effective.

Public-key-encrypted data is represented as a non-opaque vector <0..2^16-1>. Therefore, an RSA-encrypted premaster secret in a ClientKeyExchange message is preceded by two length bytes. These bytes are redundant for RSA because EncryptedPreMasterSecret is the only data in ClientKeyExchange, and its length is unambiguously determined. The SSLv3 specification did not explicitly specify the encoding of public-key-encrypted data, so many SSLv3 implementations do not include the length bytes; they encode the RSA-encrypted data directly into the ClientKeyExchange message.

TLS 1.2 requires EncryptedPreMasterSecret to be encoded correctly together with the length bytes. The resulting PDU is incompatible with many SSLv3 implementations. Implementers upgrading from SSLv3 must modify their implementations to generate and accept the correct encoding. Implementers who want compatibility with both SSLv3 and TLS must make the behavior of their implementations depend on the version number.

It is now known that timing-based attacks against TLS are possible, at least when the Client and Server are on the same LAN. Accordingly, implementations that use static RSA keys must use RSA blinding or other timing-attack countermeasures, as described in [[TIMING]](https://tools.ietf.org/html/rfc5246#ref-TIMING).


### (2) Computing the premaster secret from a static DH public key

If this value is not included in the Client's certificate, this structure carries the Client's Diffie-Hellman public key (Yc). The encoding used for Yc is enumerated by PublicValueEncoding. This structure is a variable of the Client key exchange message; it is not itself a message.

The structure of this message is:
```c
        enum { implicit, explicit } PublicValueEncoding;
```
- implicit:  
  If the Client sends a certificate that contains an appropriate Diffie-Hellman key (for `fixed_dh` Client authentication), then Yc is implicit and does not need to be sent again. In this case, the Client key exchange message is sent, but it must be empty.

- explicit:  
  Yc must be sent.
```c
        struct {
          select (PublicValueEncoding) {
              case implicit: struct {};
              case explicit: opaque dh_Yc<1..2^16-1>;
          } dh_public;
      } ClientDiffieHellmanPublic;
```
- dh\_Yc:   
  The Client’s Diffie-Hellman public key (Yc). **The DH public key is transmitted in plaintext**. Even if it is transmitted in plaintext and eavesdropped on by a man-in-the-middle, they still cannot derive the final master secret. For the specific reason, see the analysis in [this article](https://halfrost.com/cipherkey/#diffiehellman) on cryptography that I wrote earlier.


### (3) Compute the Pre-Master Secret from the Ephemeral DH Public Key

If the negotiated cipher suite’s key agreement algorithm is ECDHE, the Client needs to send the ECDH public key. The struct is as follows:
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
  The Client's ECDH public key (Yc). **The ECDH public key is also transmitted in plaintext**. Even if it is transmitted in plaintext and intercepted by a man-in-the-middle, the attacker still cannot derive the final master secret. For the specific reason, see the analysis in my earlier cryptography [article](https://halfrost.com/asymmetric_encryption/#3diffiehellmanecdh).
  
For all operations involving ECC, the Server and Client must choose a named curve supported by both parties. The ecc\_curve extension in the Client Hello message specifies the ECC named curves supported by the Client.

### 8. Certificate Verify


This message is used to explicitly verify a Client certificate. It can be sent only when a Client certificate has signing capability (for example, all certificates except those containing fixed Diffie-Hellman parameters). When sent, it must immediately follow the client key exchange message.

The structure of this message is:
```c
   struct {
        digitally-signed struct {
            opaque handshake_messages[handshake_messages_length];
        }
   } CertificateVerify;
```
Here, handshake\_messages refers to all handshake messages sent or received, starting with client hello up to but not including this message, including the type and length fields of the handshake messages. It is the concatenation of all handshake structures so far (as defined in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B)). Note that this requires both endpoints to either cache the messages or compute running hash values using all available hash algorithms until the hash value for CertificateVerify is computed. The server can minimize this computational cost by offering a restricted set of digest algorithms in the CertificateRequest message.

The hash and signature algorithms used in the signature must be one of the algorithms listed in the supported\_signature\_algorithms field of the CertificateRequest message. In addition, the hash and signature algorithms must be compatible with the client's end-entity certificate. RSA keys can be used with any permitted hash algorithm, subject to the restrictions in the certificate, if any.

Since DSA signatures do not include any secure way to indicate the hash algorithm, using multiple hashes with the same key would introduce a hash substitution risk. Currently, DSA [[DSS]](https://tools.ietf.org/html/rfc5246#ref-DSS) can be used with SHA-1. Future versions of DSS [[DSS-3]](https://tools.ietf.org/html/rfc5246#ref-DSS-3) are expected to allow other digest algorithms to be used with DSA, and to provide guidance on which digest algorithms should be used with each key size. In addition, future versions of [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX) may specify mechanisms that allow certificates to indicate which digest algorithms can be used with DSA.


### 9. Finished

A Finished message is always sent immediately after a change cipher spec message to prove that the key exchange and authentication processes were successful. A change cipher spec message must be received between the other handshake messages and the Finished message.

The Finished message is the first message protected with the newly negotiated algorithms, keys, and secrets. The recipient of the Finished message must verify that its contents are correct. Once one side has sent its Finished message and has received and verified the Finished message sent by the peer, it may begin sending and receiving application data on the connection.

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
  For a Finished message sent by the Client, the string is "client finished". For a Finished message sent by the Server, the string is "server finished".

Hash denotes a hash of the handshake messages. The hash must be used as the basis for the PRF. Any cipher suite that defines a different PRF must define the Hash used to compute the Finished message.

In versions prior to TLS 1.2, verify\_data was always 12 bytes long. In TLS 1.2, the length of verify\_data depends on the cipher suite. Any cipher suite that does not explicitly specify verify\_data\_length defaults verify\_data\_length to 12. Note that the encoding of this representation is the same as in previous versions. Future cipher suites may specify other lengths, but the length must be at least 12 bytes.

- handshake\_messages:    
  The data from all messages in this handshake, up to but not including this message, excluding any HelloRequest messages. This is data visible only at the handshake layer and does not include record-layer headers. It is the concatenation of all handshake structures defined so far in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B).

If a Finished message is not preceded by a ChangeCipherSpec at the appropriate point in the handshake, it is a fatal error.

The value of handshake\_messages includes all handshake messages starting from ClientHello up to, but not including, the Finished message. The handshake\_messages in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#8-certificate-verify) are different because they include the CertificateVerify message (if it was sent). Similarly, the handshake\_messages for the Finished message sent by the Client differ from those for the Finished message sent by the Server, because the second one sent must include the previous one. The Server's Finished message will include the Client's Finished submessage.

Note: ChangeCipherSpec messages, alerts, and any other record types are not handshake messages and are not included in the hash computation. Likewise, HelloRequest messages are ignored by the handshake hash.


The Finished submessage is the first message protected by TLS record-layer encryption. What is the purpose of the Finished submessage?

Across the entire handshake protocol, none of the preceding submessages have encryption or integrity protection. They can be tampered with easily; if such tampering is not checked, insecure attacks become possible. To prevent message tampering during the handshake, both the Client and Server need to verify each other's Finished submessage.

Suppose a man-in-the-middle modifies the maximum TLS version supported in the ClientHello to TLS 1.0 during the handshake, attempting a downgrade attack and exploiting vulnerabilities in older TLS versions. When the Server receives the man-in-the-middle's ClientHello, it does not know whether it has been tampered with, so it proceeds to negotiate using TLS 1.0. When the handshake reaches the final step and the Finished submessage is verified, the verification fails. This is because the original ClientHello sent by the Client indicated TLS 1.2 as the maximum supported TLS version, so the verify\_data produced for the Finished submessage must differ from the verify\_data computed by the Server from the tampered ClientHello. At this point, the tampering in the middle is detected and the handshake fails.


## IV. An Intuitive Look at the TLS 1.2 Initial Handshake Flow

At this point, all the details of the TLS 1.2 initial handshake have been analyzed. In this section, let's summarize the flow above and use Wireshark to get an intuitive feel for the TLS 1.2 protocol.

First, the initial handshake based on the RSA key exchange algorithm:

![](https://img.halfrost.com/Blog/ArticleImage/97_2_3.png)

The handshake begins with the Client sending ClientHello. In this message, the Client reports all the "capabilities" it supports. client\_version indicates the highest TLS version supported by the Client; random indicates the random value generated by the Client, used to generate the premaster secret, master secret, and key block. Its total length is 32 bytes: the first 4 bytes are a timestamp, and the remaining 28 bytes are random bytes. cipher\_suites indicates the cipher suites the Client can support. extensions indicates all extensions the Client can support.

> This article covers extensions only lightly, because I plan to consolidate the extensions involved in TLS 1.2 and TLS 1.3 into a separate article. They are not analyzed in detail in this handshake flow. For a more detailed analysis of extensions, see [“Refreshing HTTPS Fundamentals (Part 6) — Extensions in TLS”]()

After receiving ClientHello, if the Server can continue negotiation, it sends ServerHello; otherwise, it sends Hello Request to renegotiate. In ServerHello, the Server combines the Client's capabilities and selects a protocol version and cipher suite supported by both sides to proceed with the next steps of the handshake. server\_version indicates the protocol version selected by the Server after negotiation and supported by both sides. random indicates the random value generated by the Server, used to generate the premaster secret, master secret, and key block. Its total length is 32 bytes: the first 4 bytes are a timestamp, and the remaining 28 bytes are random bytes. cipher\_suites indicates the cipher suite selected by the Server after negotiation and supported by both sides. extensions indicates the result after the Server processes the Client's extensions.

After a cipher suite acceptable to both sides has been negotiated, the Server sends a Certificate message as needed. The Certificate message carries the Server's certificate chain. The Certificate message serves two purposes: first, to verify the Server's identity; second, to allow the Client to obtain the Server's public key from the certificate according to the negotiated cipher suite. The Client uses the Server's public key and the server's random to generate the premaster secret.

Because the key exchange algorithm is RSA, after sending the Certificate message, the Server directly sends the ServerHelloDone message.

After the Client receives the ServerHelloDone message, it begins computing the premaster secret. The computed premaster secret is encrypted using the RSA/ECDSA algorithm and sent to the Server through the ClientKeyExchange message. For an RSA cipher suite, the premaster secret is 48 bytes: the first 2 bytes are client\_version, and the remaining 46 bytes are random bytes. After the Server receives the ClientKeyExchange message, it begins computing the master secret and key block. At the same time, the Client also computes the master secret and key block locally.
 
> Some people refer to the "master secret and session keys"; here, session keys and the key block mean the same thing. The master secret is generated from the premaster secret, the client random, and the server random through the PRF function; the session keys are generated from the master secret, the client random, and the server random through the PRF function.
>
>session keys = key_block = key block; all three mean the same thing, just translated differently.

After sending the ClientKeyExchange message, the Client immediately continues by sending the ChangeCipherSpec message and the Finished message. The Server also responds with a ChangeCipherSpec message and a Finished message. If verification of the Finished message completes successfully, the handshake has ultimately succeeded.

Now let's look at the initial handshake based on the DH key exchange algorithm:

![](https://img.halfrost.com/Blog/ArticleImage/97_3_0_.png)

The difference between the DH-based key exchange algorithm and RSA-based key negotiation lies in how the Server and Client negotiate DH parameters. Here we only cover the additional steps in the DH key exchange process compared with RSA; the rest of the flow is basically the same as the RSA flow.

After the Server sends the Certificate message, it continues by sending the ServerKeyExchange message, which carries the DH parameters.

Another difference is that the premaster secret sent to the Server in the ClientKeyExchange message is not 48 bytes long. For DH/ECDH-based key negotiation, the negotiated key length depends on the public key of the DH/ECDH algorithm.

To help readers understand the TLS 1.2 flow more intuitively, I used Wireshark to capture the network packets during a TLS handshake between Chrome and my blog. Combined with Wireshark packet analysis, this will help us understand the TLS 1.2 handshake more deeply. The following example uses the TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 cipher suite:

![](https://img.halfrost.com/Blog/ArticleImage/97_6.png)

The screenshot above shows a complete process from the start of the TLS handshake to the TCP four-way connection termination. Here we mainly focus on all messages where protocol = TLS 1.2. The overall flow is consistent with the DH-based key exchange algorithm analyzed above. Before the TCP four-way termination, the TLS layer first receives a Close Notify Alert message.

> Some readers may wonder at this point: why is the application-layer data encrypted by TLS shown in plaintext in the packet capture? Is HTTPS insecure? This needs some explanation. I used `export SSLKEYLOGFILE=/Users/XXXX/sslkeylog.log` to save the ECDHE-negotiated keys into a log file, so when parsing encrypted packets from the upper-layer HTTP/2 traffic, the TLS keys in the log can be used to decrypt them. The green part in the figure above is the decrypted HTTP/2 content obtained this way. I will mention this topic in articles related to HTTP/2; for now, readers can simply assume that I used some means to parse the encrypted HTTPS content.

Next, let's examine one by one how the network transmits the packets, starting with ClientHello.

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

From the Length field of the TLS 1.2 Record Layer, we can see that this TLS handshake message at the TLS record layer is 512 bytes long, of which the ClientHello message accounts for 508 bytes. ClientHello indicates that the highest TLS version supported by the Client is TLS 1.2 (0x0303). The Client supports 17 cipher suites, with TLS\_AES\_128\_GCM\_SHA256 as the highest-priority one. The Session ID length is 32 bytes and is non-empty here. The compression algorithm is null. signature\_algorithms indicates that the Client supports 9 pairs of digital signature algorithms.

>By default, TLS compression is disabled, because the CRIME attack can exploit TLS compression to recover encrypted authentication cookies and achieve session hijacking. In addition, after content compression such as gzip is typically configured, compressing TLS fragments again provides little benefit while consuming additional resources. Therefore, TLS compression is usually disabled.
![](https://img.halfrost.com/Blog/ArticleImage/97_8.png)

The ClientHello sends the status\_request extension to request OCSP stapling information. It sends the signed\_certificate\_timestamp extension to request SCT information. It also sends the application\_layer\_protocol\_negotiation (ALPN) extension to ask whether the server supports HTTP/2. The supported\_group extension identifies the elliptic curves supported by the Client. The SessionTicket TLS extension indicates that the Client supports session resumption based on Session Tickets.

Now let’s look at the ServerHello message.

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message at the TLS record layer is 82 bytes long, of which the ServerHello message accounts for 78 bytes. The Server chooses TLS 1.2 for the subsequent handshake with the Client. The cipher suite negotiated by the Server and Client is TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384.

The Server supports HTTP/2 and responds in the ALPN extension.

![](https://img.halfrost.com/Blog/ArticleImage/97_10.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake message at the TLS record layer is 2544 bytes long, of which the Certificate message accounts for 2540 bytes. The Certificates certificate chain contains two certificates: the Server entity certificate is 1357 bytes, and the intermediate certificate is 1174 bytes. The intermediate certificate was issued by Let's Encrypt. Both certificates are signed using the sha256WithRSAEncryption signature algorithm.

![](https://img.halfrost.com/Blog/ArticleImage/97_11.png)

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message at the TLS record layer is 535 bytes long, of which the Certificate Status message accounts for 531 bytes. The Server sends the OCSP response to the Client.

From the Length field in the TLS 1.2 Record Layer, we can see that this TLS handshake protocol message at the TLS record layer is 116 bytes long, of which the ServerKeyExchange message accounts for 112 bytes. Because the negotiated key agreement algorithm is ECDHE, the Server needs to send the ECDH parameters and public key to the Client via the ServerKeyExchange message. Here, the ECC named curve used by ECDHE is x25519. The Server’s public key is (62761b5……), the signature algorithm is ECDSA\_secp256r1\_SHA256, and the signature value is (3046022……).

The ServerHelloDone message structure is very simple, as shown above.

![](https://img.halfrost.com/Blog/ArticleImage/97_12.png)

Because the negotiated algorithm is ECDHE, the Client needs to send the ECC DH public key; the corresponding public key value is (1e58cf……). The public key length is 32 bytes.

The ChangeCipherSpec message structure is very simple. This message is sent to tell the Server that the Client can now use cryptographic protection in the TLS record layer protocol. The first cryptographically protected message is the Finished message.

The Finished message structure is very simple, as shown above.

![](https://img.halfrost.com/Blog/ArticleImage/97_13.png)

If the Server is only using SessionTicket, it generates a new NewSessionTicket and returns it to the Client, then likewise returns the ChangeCipherSpec message and the Finished message.

![](https://img.halfrost.com/Blog/ArticleImage/97_14.png)

When the page is closed, the Server sends a TLS Alert message to the Client; the description in this message is Close Notify. At the same time, the Server sends a FIN packet to begin the four-way termination handshake.


## V. TLS 1.2 Session Resumption


As soon as the Client and Server close the connection, accessing the HTTPS site again shortly afterward requires establishing a new connection. A new connection introduces network latency and consumes compute resources on both sides. Is there a way to reuse the previous TLS connection? Yes—this is where the TLS session resumption mechanism comes in.

When the Client and Server decide to continue a previous session or duplicate an existing session (instead of negotiating new security parameters), the message flow is as follows:

The Client sends a ClientHello using the ID of the current session it wants to resume. The Server checks its session cache for a match. If a match is found and the Server is willing to re-establish the connection under the specified session state, it sends a ServerHello message with the same session ID value. At this point, both the Client and the Server must send ChangeCipherSpec messages and then directly send Finished messages. Once re-establishment is complete, the Client and Server can begin exchanging application-layer data (see the flowchart below). If the session ID does not match, the Server generates a new session ID, and the TLS Client and Server need to perform a full handshake.
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
Session ID is supported by the server side and is a standard field in the protocol, so basically all servers support it. The server stores the session ID and the negotiated communication information, which consumes more server resources.

### 1. Session Resumption Based on Session ID

After the Client establishes a complete Session with the Server through a full handshake, the Server records the information for this Session so it can be used when resuming the session:

- Session identifier:      
  A unique identifier for each session
- Peer certificate:   
  The peer's certificate, usually empty
- Compression method:   
  Usually not enabled
- Cipher spec:  
  The cipher suite jointly negotiated by the Client and Server
- Master secret:    
  Each session stores a copy of the master secret. **Note that this is not the premaster secret**. (Readers can think about why; if you still cannot figure it out, see [“HTTPS Refresher (Part 5) — Key Computation in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-key-cipher.md))
- Is resumable: 
  Indicates whether the session is resumable
  
Once the Server has stored the information above, it can recompute the security parameters required by the TLS record layer and use them to encrypt application data.

The flow for Session ID–based session resumption is as follows:  
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

The client discovers that the requested website has been requested before—that is, a Session ID exists in memory—so when establishing the connection again, it includes the Session ID corresponding to the website in the ClientHello. The server keeps a Session Cache dictionary in memory, where the key is the Session ID and the value is the session information. After receiving the ClientHello, the server checks whether there is relevant session information based on the transmitted Session ID. If there is, it allows the client to resume the session and directly sends ChangeCipherSpec and Finished messages. If there is no relevant session information, it starts a full handshake and generates a new Session ID in the ServerHello to return to the client. When the client receives the ChangeCipherSpec and Finished messages from the server, it means session resumption succeeded, and it also sends ChangeCipherSpec and Finished messages in response.

Sources of the Session ID:  

- The Session ID generated by the previous full handshake  
- The Session ID from another connection  
- The Session ID used directly for this connection  

The necessity of each parameter in the ClientHello during session resumption:

- The cipher suite negotiated by the server via the ClientHello must be the same as the cipher suite in the session; otherwise, session resumption fails and a full handshake is performed.
- The random value in the ClientHello is different from the random value used in the session being resumed. Therefore, even if the session is resumed, because the random value in the ClientHello is different, the key block (session keys) generated again through the PRF is also different. This improves security.
- The Session ID in the ClientHello is transmitted in plaintext, so sensitive information should not be included in the Session ID. In addition, the Finished verification in the final step of the handshake is essential to prevent the Session ID from being tampered with.

Finally, note that session resumption depends on the server. Even if the Session ID is correct and the relevant session information exists in the server’s memory, the server can still require the client to perform a full handshake. In other words, session resumption is not mandatory.

The **advantages** of Session ID-based session resumption are:  

- Reduces network latency, with handshake time reduced from 2-RTT -> 1-RTT
- Reduces load on both the client and server, lowering CPU resource consumption for cryptographic operations

The **disadvantages** of Session ID-based session resumption are:  

- The server stores session information, which limits server scalability.
- In a distributed system, if the Session Cache is simply stored in server memory, synchronizing data across multiple machines is also a problem.

Nginx does not officially provide an implementation of Session Cache that supports distributed servers. Third-party patches can be used, but security and maintenance costs also increase.

Because of the two disadvantages above, the Session Ticket-based session resumption scheme was introduced.


### 2. Session Ticket-Based Session Resumption

The scheme used to replace Session ID-based session resumption is session tickets. With this approach, except that all state is stored on the client side (similar to how HTTP Cookies work), the message flow is the same as with a server-side session cache.

The idea is that the server takes all of its session data (state), encrypts it (with a key known only to the server), and sends it back to the client as a ticket. In subsequent connections, when the client resumes the session, it carries the encrypted information in the session\_ticket extension field of the ClientHello and submits the ticket back to the server. The server checks the ticket’s integrity, decrypts its contents, and then uses the information inside to resume the session.

**For the server, decrypting the ticket yields the master secret**. (Note that this differs from SessionID, where the Session ID can be used to obtain the master secret information.) For the client, during a full handshake, when it receives the NewSessionTicket submessage issued by the server, the client stores the Ticket and the corresponding premaster secret locally. During an abbreviated handshake, once the server verifies the ticket and determines that an abbreviated handshake can proceed, the client generates the master secret from the locally stored premaster secret, and finally generates the session keys (key block).

This approach can make scaling a server cluster simpler, because without it, the Session Cache would need to be synchronized across all nodes in the service cluster. Session tickets require support from both the server and the client. They are an extension field and consume very few server resources.

The advantages of Session Ticket determine that it is especially suitable for the following scenarios:

- Large HTTPS websites with very high traffic, where storing Session information on the server would consume a large amount of memory
- HTTPS website owners who want the lifetime of session information to be long enough so that clients use abbreviated handshakes as much as possible
- HTTPS website owners who want users to access services across regions and hosts


The Session Ticket-based session resumption process is as follows: 


### (1). Obtaining a SessionTicket

The client can obtain a SessionTicket only after completing a full handshake.
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

After encrypting the session information and sending it to the Client as a ticket, the Server no longer stores any information. The Client stores the received ticket in memory and sends it to the Server whenever it wants to resume the session. If the Server successfully decrypts and verifies it, an abbreviated handshake can proceed.

### (2). SessionTicket-Based Session Resumption

Once the Client has obtained the SessionTicket locally, it can use this SessionTicket the next time it wants to perform an abbreviated handshake.
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
The Client includes a non-empty SessionTicket extension in the extensions of the ClientHello. If the Server supports SessionTicket session resumption, it replies with an empty SessionTicket extension in the ServerHello. The Server encrypts and protects the session information, generates a new ticket, and sends it to the Client via the NewSessionTicket submessage. After sending the NewSessionTicket message, it immediately sends the ChangeCipherSpec and Finished messages. After receiving these messages, the Client responds with ChangeCipherSpec and Finished messages, and session resumption succeeds.

### (3). Server Does Not Support SessionTicket

Some readers may ask: since the Client sent a non-empty SessionTicket extension, why must the Server reply with an empty SessionTicket extension in the ServerHello? Because when the Server does not support SessionTicket, the ServerHello does not contain the SessionTicket extension. Therefore, whether the SessionTicket extension is present distinguishes whether the Server supports SessionTicket.
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
If the Server does not support SessionTicket, it does not include the SessionTicket TLS extension in ServerHello, nor does it send the NewSessionTicket submessage.


### (4). Server Fails to Validate SessionTicket

If the Server fails to validate the SessionTicket, the handshake falls back to a full handshake.
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

This section is primarily based on [[RFC5077]](https://tools.ietf.org/html/rfc5077).

If the ServerHello message includes the Session Ticket TLS extension, an **encrypted NewSessionTicket submessage** must be sent before ChangeCipherSpec. If the ServerHello message does not include the Session Ticket TLS extension, it means that either the Server or the Client does not want to use the SessionTicket session resumption mechanism.

Because the NewSessionTicket submessage is also considered part of the handshake, it must also be verified in the Finished submessage. **If the Server successfully validates the ticket sent by the Client, it must also generate a brand-new ticket and send it to the Client via the NewSessionTicket submessage; the Client will use this new SessionTicket next time**.

In the handshake protocol, the addition of the extension also introduces several new handshake messages:
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
The three handshake submessages `CertificateURL`, `CertificateStatus`, and `NewSessionTicket` are all new submessages introduced by extensions.

The data structure of the `NewSessionTicket` message is as follows:
```c

      struct {
          uint32 ticket_lifetime_hint;
          opaque ticket<0..2^16-1>;
      } NewSessionTicket;
```
One of the most important fields in NewSessionTicket is `ticket_lifetime_hint`. It indicates whether the ticket has expired. The Server checks this field, and if it has expired, session resumption cannot be performed. Ticket generation and validation are both handled entirely by the Server; the Client merely receives and stores it.

There is no fixed specification for how the Server generates a ticket, and different Servers may generate it differently. One important point to keep in mind is forward secrecy, to prevent it from being compromised. RFC5077 recommends generating it as follows:
```c
      struct {
          opaque key_name[16];
          opaque iv[16];
          opaque encrypted_state<0..2^16-1>;
          opaque mac[32];
      } ticket;
```
- key\_name:  
  The key file used for ticket encryption
  
- iv:  
  The initialization vector required by the AES encryption algorithm
  
- encrypted\_state:  
  The ticket details; what is stored is the session information
  
- mac:  
  Provides the integrity and security protection required by the ticket
  
  
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

## VI. An Intuitive Look at TLS 1.2 Session Resumption


In this section, the author uses Wireshark to demonstrate TLS 1.2 session resumption, helping readers deepen their understanding.

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

In ServerHello, the SessionID is empty, and the SessionTicket TLS extension is also empty. This indicates that the Server will send a NewSessionTicket submessage in a subsequent submessage.

The example used here is somewhat special. During the previous handshake, the ClientHello from the Client carried a SessionID and an empty SessionTicket TLS extension. After receiving this extension, the Server found the session information corresponding to this Session ID in its in-memory Session Cache, responded to the Client in ServerHello with the same SessionID, and also returned an empty SessionTicket TLS extension. With this as the background, what will the result be when performing session resumption?

The final packet capture screenshot is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/97_23.png)

Looking at the screenshot above, we do not see a NewSessionTicket submessage. Does this mean that session resumption is not based on SessionTicket? Let’s continue looking at the details.

![](https://img.halfrost.com/Blog/ArticleImage/97_24.png)

In ClientHello, we can see that the Client includes both a Session ID and a non-empty SessionTicket TLS extension.

![](https://img.halfrost.com/Blog/ArticleImage/97_25.png)

The Server responds with the same Session ID in ServerHello, indicating that the corresponding session information can be found in the Session Cache. The ClientHello also sent a SessionTicket, so why did the Server not respond with any extension message? Is it because the Server does not support the SessionTicket TLS extension? The Server sent a NewSessionTicket submessage in the previous handshake, which indicates that the Server does support the SessionTicket TLS extension. So why did it not reply with any information related to SessionTicket here? The reason is that the ClientHello contains a SessionID that can be used for session resumption. [[RFC 5077 3.4.  Interaction with TLS Session ID]](https://tools.ietf.org/html/rfc5077) **specifies**: if the Client sends both a Session ID and a SessionTicket TLS extension in ClientHello, the Server must respond with the same Session ID from the ClientHello. However, when validating the SessionTicket, the Server must not depend on this particular Session ID; that is, it must not use the Session ID from ClientHello for session resumption. The Server gives priority to SessionTicket for session resumption (SessionTicket has higher priority than Session ID). If the Session validation succeeds, it continues by sending ChangeCipherSpec and Finished messages. It does not send a NewSessionTicket message.


![](https://img.halfrost.com/Blog/ArticleImage/97_26.png)

After the Client receives the ChangeCipherSpec and Finished messages sent by the Server, it also sends ChangeCipherSpec and Finished messages in response.

![](https://img.halfrost.com/Blog/ArticleImage/97_33_.png)

The figure above summarizes the case where the Client includes both a Session ID and a SessionTicket TLS extension during session resumption.


At this point, the first part of the intuitive look at the TLS handshake process comes to an end. This first part has completed a detailed analysis of all handshake flows in TLS 1.2. The second part, [“HTTPS Revisited (4) — An Intuitive Look at the TLS Handshake Process (Part 2)”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.3_handshake.md), will focus on analyzing the TLS 1.3 handshake process and comparing it with the TLS 1.2 handshake process. It will also explain what the newly added 0-RTT in TLS 1.3 is all about.

Of course, all content related to key computation in the TLS 1.2 and TLS 1.3 handshake processes has been placed in [“HTTPS Revisited (5) — Key Computation in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-key-cipher.md), and all content related to extensions in the TLS 1.2 and TLS 1.3 handshake processes has been placed in [“HTTPS Revisited (6) — Extensions in TLS”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-extensions.md).

------------------------------------------------------

Reference:

[RFC 5247](https://tools.ietf.org/html/rfc5077)  
[RFC 5077](https://tools.ietf.org/html/rfc5077)    
[RFC 8466](https://tools.ietf.org/html/rfc8466)   
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)        
[HTTPS Practices for Large Websites (2) -- The Impact of HTTPS on Performance](https://developer.baidu.com/resources/online/doc/security/https-pratice-2.html)  

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS-TLS1.2\_handshake/](https://halfrost.com/https_tls1-2_handshake/)