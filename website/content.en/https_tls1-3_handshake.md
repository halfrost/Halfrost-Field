+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2019-02-02T23:58:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/120_0.png"
slug = "https_tls1-3_handshake"
tags = ["Protocol", "HTTPS"]
title = "HTTPS Refresher (4) —— An Intuitive Look at the TLS Handshake Process (Part 2)"

+++


In the opening article on HTTPS, I analyzed that HTTPS is secure because of the TLS protocol. The protocol in TLS that ensures information security and integrity is the record layer protocol. (The record layer protocol was analyzed in detail in the previous article.) Readers who have finished the previous article may be wondering: where do the keys used for encryption at the TLS protocol layer come from? How exactly do the client and server negotiate the Security Parameters? This article provides a detailed analysis of the similarities and differences between TLS 1.2 and TLS 1.3 at the TLS handshake layer.

Compared with TLS 1.2, the biggest improvements TLS 1.3 makes to the TLS handshake protocol are increased speed and improved security. This article focuses on these two areas.

First, here is a brief overview of some optimizations and improvements in TLS 1.3:

1. It reduces handshake latency, cutting the handshake time from 2-RTT to 1-RTT, and adds a 0-RTT mode.

2. It removes the RSA key exchange method, and static Diffie-Hellman cipher suites have also been removed, because RSA does not provide forward secrecy. TLS 1.3 only supports (EC)DHE key exchange algorithms. Removing RSA effectively helps prevent attacks such as [Heartbleed](https://en.wikipedia.org/wiki/Heartbleed). **All public-key-based key exchange algorithms now provide forward secrecy**. The TLS 1.3 specification supports only 5 cipher suites: TLS13-AES-256-GCM-SHA384, TLS13-CHACHA20-POLY1305-SHA256, TLS13-AES-128-GCM-SHA256, TLS13-AES-128-CCM-8-SHA256, and TLS13-AES-128-CCM-SHA256. The asymmetric encryption key agreement algorithm is hidden, because elliptic-curve key agreement is used by default.


3. It removes several risks caused by block encryption and MAC in symmetric encryption. In versions prior to TLS 1.3, the selected approach was MAC-then-Encrypt. However, this approach led to vulnerabilities such as [BEAST](https://www.youtube.com/watch?v=-_8-2pDFvmg), as well as a series of padding oracle vulnerabilities ([Lucky 13](http://www.isg.rhul.ac.uk/tls/Lucky13.html) and [Lucky Microseconds](https://eprint.iacr.org/2015/1129)). The interaction between CBC mode and padding was also the cause of the widely publicized [POODLE](https://blog.cloudflare.com/sslv3-support-disabled-by-default-due-to-vulnerability/) vulnerability in SSLv3 and some TLS implementations. In TLS 1.3, all insecure ciphers and cipher modes have been removed. You can no longer use CBC-mode ciphers or insecure stream ciphers such as RC4. The only type of symmetric encryption allowed in TLS 1.3 is a new construction called AEAD (authenticated encryption with additional data), which integrates confidentiality and integrity into a single seamless operation.

4. In TLS 1.3, support for PKCS＃1 v1.5 was removed in favor of the newer RSA-PSS design, improving security. Authentication is performed using asymmetric algorithms, such as RSA, the Elliptic Curve Digital Signature Algorithm (ECDSA), or the Edwards-curve Digital Signature Algorithm (EdDSA), or by using a symmetric pre-shared key (PSK).

5. In the TLS 1.2 handshake flow, only messages after ChangeCipherSpec are encrypted, such as Finished messages and NewSessionTicket; the other handshake submessages are not encrypted. TLS 1.3 addresses this issue by encrypting most submessages in the handshake. This effectively prevents downgrade attacks such as FREAK, LogJam, and CurveSwap (a downgrade attack is where a man-in-the-middle abuses negotiation to force both communicating parties to use the weakest supported encryption algorithm, then brute-forces the key and allows the attacker to forge the MAC during the handshake). In TLS 1.3, this type of downgrade attack is impossible, because the server now signs the entire handshake, including cipher negotiation.
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/120_1.png'>
</p>
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/120_2.png'>
</p>

6. TLS 1.3 completely prohibits renegotiation.
7. The key derivation function has been redesigned, replacing the PRF algorithm in TLS 1.2 with the more secure HKDF algorithm.
8. Session ID and Session Ticket session resumption are deprecated. Session resumption is unified through PSK, and the NewSessionTicket message adds an expiration time and an offset value used to obfuscate time.

For more important changes, see my previous article [“TLS 1.3 Introduction”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E4%B8%89tls-13-%E5%92%8C-tls-12-%E4%B8%BB%E8%A6%81%E7%9A%84%E4%B8%8D%E5%90%8C)

## VII. TLS 1.3 Initial Handshake Flow


>Because I have already analyzed the details of the TLS 1.3 handshake flow in a previous article, this article will not go into as much detail as the previous analysis of TLS 1.2. If you want to understand the details of TLS 1.3, please read [“TLS 1.3 Handshake Protocol”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md). This article mainly uses Wireshark to give readers an intuitive view of the TLS 1.3 handshake flow.

In TLS 1.3, there are four methods for key agreement:

- The list of cipher suites supported by the Client. The cipher suites indicate the AEAD algorithms or HKDF hash pairs supported by the Client.
- The "supported\_groups" extension and the "key\_share" extension. The “supported\_groups” extension indicates the (EC)DHE groups supported by the Client, and the "key\_share" extension indicates whether the Client includes some or all of the (EC)DHE shares.
- The "signature\_algorithms" signature algorithms extension and the "signature\_algorithms\_cert" certificate signature algorithms extension. The "signature\_algorithms" extension shows which signature algorithms the Client can support. The "signature\_algorithms\_cert" extension shows the signature algorithms for specific certificates.
- The "pre\_shared\_key" pre-shared key extension and the "psk\_key\_exchange\_modes" extension. The pre-shared key extension contains the identifiers of symmetric keys that the Client can recognize. The "psk\_key\_exchange\_modes" extension indicates the key exchange modes that may be used together with psk.

The first method already existed in TLS 1.2 and negotiates through Cipher Suites in ClientHello. The second method is new in TLS 1.3; a full handshake in TLS 1.3 is implemented using this method. The third method is also new in TLS 1.3, but it is not used as often as the second method. The fourth method is also new in TLS 1.3. After deprecating Session ID and Session Ticket from TLS 1.2, TLS 1.3 unifies session resumption through PSK. The 0-RTT mode in TLS 1.3 is also performed through PSK.

The flow of a full TLS 1.3 handshake is as follows:
```c
          Client                                               Server

          ClientHello
          + key_share               -------->
                                                          ServerHello
                                                          + key_share
                                                {EncryptedExtensions}
                                                {CertificateRequest*}
                                                       {Certificate*}
                                                 {CertificateVerify*}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Certificate*}
          {CertificateVerify*}
          {Finished}                -------->
                                    <--------      [NewSessionTicket]
          [Application Data]        <------->      [Application Data]
```
In the TLS 1.3 handshake, there are three main phases:

- Key exchange: establishes the shared keying material and selects the cryptographic parameters. After this phase, all data is encrypted.
- Server parameters: establishes the other handshake parameters (whether the Client is authenticated, application-layer protocol support, etc.).
- Authentication: authenticates the Server (and optionally the Client), providing key confirmation and handshake integrity.

The key exchange consists of ClientHello and ServerHello; Server parameters consist of the EncryptedExtensions and CertificateRequest messages. Authentication consists of Certificate, CertificateVerify, and Finished.


The Client initiates a full handshake flow starting with ClientHello:
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
In the ClientHello struct, legacy\_version = 0x0303. 0x0303 is the version number for TLS 1.2, and the specification requires this field to be set to this value. The other fields have the same meaning as in TLS 1.2, so we will not repeat them here.

In the Extension of a TLS 1.3 ClientHello, the supported\_versions field must be present. Without this field, the ClientHello will be interpreted as a TLS 1.2 ClientHello message. In TLS 1.3, the Server uses the supported\_versions field to decide whether to negotiate TLS 1.3.

The reason TLS 1.3 can reduce a full handshake by 1 RTT compared with TLS 1.2 is that the ClientHello already contains the key parameters required for (EC)DHE, so it does not need an additional second RTT, as TLS 1.2 does, to negotiate DH parameters. In the Extension of a TLS 1.3 ClientHello, there is a key\_share extension, which contains the key parameters for the (EC)DHE algorithms supported by the Client. The Extension also includes a supported\_groups extension, which indicates the named groups supported by the Client for key exchange, ordered from highest to lowest priority.

After receiving the ClientHello, the Server responds with a ServerHello message:
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
In the ServerHello message, legacy\_version = 0x0303. This is also mandated by the TLS 1.3 specification: this value must be fixed to 0x0303 (TLS 1.2). The Server reads the "supported\_versions" extension field in the ClientHello extensions. If the Client supports TLS 1.3, the Server indicates in the "supported\_versions" extension field of the ServerHello extensions that a TLS 1.3 handshake can be performed.

When the Server negotiates a version earlier than TLS 1.3, it must set ServerHello.version and must not send the "supported\_versions" extension. When the Server negotiates TLS 1.3, it must send the "supported\_versions" extension as the response, and the extension must contain the selected TLS 1.3 version number (0x0304). It must also set ServerHello.legacy\_version to 0x0303 (TLS 1.2). The Client must check this extension before processing ServerHello (although it needs to parse ServerHello first in order to read the extension names). If the "supported\_versions" extension is present, the Client must ignore the value of ServerHello.legacy\_version and use only the value in "supported\_versions" to determine the selected version. If the "supported\_versions" extension in ServerHello contains a version that the Client did not offer, or contains a version earlier than TLS 1.3 (the negotiation is for TLS 1.3, but it includes a pre-TLS 1.3 version), the Client must immediately send an "illegal\_parameter" alert message and abort the handshake.


The ServerHello Extension must include these two extensions: supported\_versions and key\_share (if PSK session resumption is used, it must also include pre\_shared\_key). The key\_share extension indicates which elliptic curve supported by the Client the Server has selected, as well as the corresponding parameters required for key agreement. There are two cases here: one is negotiation of Diffie-Hellman parameters, which is analyzed in detail in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-diffie-hellman-parameters); the other is negotiation of ECDHE parameters, which is analyzed in detail in [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-ecdhe-parameters).

The key\_share is not encrypted with the private key during transmission. Non-repudiation and tamper resistance for the entire process are ensured by CertificateVerify, which verifies that the Server holds the private key, and by the Finished message, which uses HMAC to verify the transcript of previous messages.

After sending the ServerHello message, the Server continues by sending EncryptedExtensions and CertificateRequest messages. If the Client is not authenticated, the CertificateRequest message does not need to be sent. Both of the above messages are encrypted with a key derived from server\_handshake\_traffic\_secret.

The early secret and ecdhe secret derive server\_handshake\_traffic\_secret. The key and iv are then derived from server\_handshake\_traffic\_secret, and that key and iv are used to encrypt the handshake messages after ServerHello. Similarly, client\_handshake\_traffic\_secret is computed, and the corresponding key and iv are used to decrypt subsequent handshake messages.
```c
       Early Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(0, PSK) = HKDF-Extract(0, 0)
       Handshake Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(Derive-Secret(Early Secret, "derived", ""), (EC)DHE)

       client_handshake_traffic_secret = Derive-Secret(Handshake Secret, "c hs traffic", ClientHello...ServerHello)
       server_handshake_traffic_secret = Derive-Secret(Handshake Secret, "s hs traffic", ClientHello...ServerHello)

       client_write_key = HKDF-Expand-Label(client_handshake_traffic_secret, "key", "", key_length)
       client_write_iv  = HKDF-Expand-Label(client_handshake_traffic_secret, "iv", "", iv_length)

       server_write_key = HKDF-Expand-Label(server_handshake_traffic_secret, "key", "", key_length)
       server_write_iv  = HKDF-Expand-Label(server_handshake_traffic_secret, "iv", "", iv_length)
```
The EncryptedExtensions message contains extensions that should be protected. That is, any extensions that are not needed to establish the cryptographic context and are not associated with individual certificates. For example, the ALPN extension. The Client MUST check whether the EncryptedExtensions message contains any prohibited extensions; if any prohibited extension is found, it MUST immediately abort the handshake with an "illegal\_parameter" alert message.
```c
   Structure of this message:

      struct {
          Extension extensions<0..2^16-1>;
      } EncryptedExtensions;
```
- extensions:      
	List of extensions.
	

For details on the CertificateRequest message, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-certificate-request)


Next, the Server continues sending the Certificate, CertificateVerify, and Finished messages. These three messages are the final three messages of the handshake. They are encrypted using keys derived from sender\_handshake\_traffic\_secret.

The Server sends its own Certificate to the Client. In the Certificate message, there are four cases. The first includes OCSP Status and SCT Extensions; for details, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-ocsp-status-and-sct-extensions). The second includes Server Certificate Selection; for details, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-server-certificate-selection). The third includes Client Certificate Selection; for details, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-client-certificate-selection). The last includes Receiving a Certificate Message; for details, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#4-receiving-a-certificate-message).

After the Server sends the Certificate message, the CertificateVerify message immediately follows. The Server signs all handshake messages sent so far. For the specific verification process, see [this section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-certificate-verify).


The final message is the Finished message. It plays a critical role in authenticating the handshake and the computed keys.

The key used to compute the Finished message is derived using HKDF, specifically:
```c
   finished_key =
       HKDF-Expand-Label(BaseKey, "finished", "", Hash.length)
```
BaseKey is handshake\_traffic\_secret.

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
HMAC [[RFC2104]](https://tools.ietf.org/html/rfc2104) uses a hash algorithm for the handshake. As described above, the HMAC input is typically implemented via a running hash; that is, at this point it is only the hash of the handshake.

In earlier versions of TLS, the length of verify\_data was always 12 octets. In TLS 1.3, it is the size of the HMAC output used to represent the handshake hash.


**Note: Alerts and any other non-handshake record types are not handshake messages and are not included in the hash calculation**.

Any record after the Finished message MUST be encrypted under the appropriate application traffic keys. In particular, this includes any alert sent by the Server in response to the Client's Certificate message and CertificateVerify message.

After the Finished message has been sent, the final symmetric encryption keys are exported. The master secret is derived from the Handshake Secret, and the symmetric keys `key` and `iv` for both directions are then derived from the master secret.
```c
       Master Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(Derive-Secret(Handshake Secret, "derived", ""), 0)
       client_application_traffic_secret_0 = Derive-Secret(Master Secret, "c ap traffic", ClientHello...server Finished)
       server_application_traffic_secret_0 = Derive-Secret(Master Secret, "s ap traffic", ClientHello...server Finished)
```
After the Finished message is sent, in a full handshake, once the Server receives the Client's Finished message and verifies it, it still needs to send a NewSessionTicket message. The final resumption secret is computed from the master secret and the digest of the entire handshake.

NewSessionTicket is encrypted using server\_application\_traffic\_secret. During ticket encryption, compared with TLS 1.2, TLS 1.3 also includes the current creation time, making it easy to configure and verify the ticket expiration time.

Note: Although the resumption master secret depends on the Client's second flight, a Server that does not request Client authentication can independently compute the remaining portion of the transcript hash, and then send NewSessionTicket immediately after sending its Finished message instead of waiting for the Client's Finished message. This may be useful when the Client needs to open multiple TLS connections in parallel and can benefit from the reduced cost of resumed handshakes.
```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```
- ticket\_lifetime:  
	This field indicates the lifetime of the ticket, expressed as a 32-bit unsigned integer in network byte order representing the number of seconds since the ticket was issued. Servers MUST NOT use any value greater than 604800 seconds (7 days). A value of zero indicates that the ticket should be discarded immediately. Regardless of ticket\_lifetime, clients MUST NOT cache tickets for more than 7 days, and MAY delete tickets earlier according to local policy. A server may treat a ticket as valid for a shorter period than the one indicated by ticket\_lifetime. **This is a difference between TLS 1.2 and TLS 1.3: TLS 1.2 does not include a ticket validity period (i.e., lifetime)**.

- ticket\_age\_add:  
	A securely generated random 32-bit value used to obfuscate the age of the ticket included by the client in the "pre\_shared\_key" extension. The client adds this value to the ticket age modulo 2 ^ 32 to compute the value it transmits. The server MUST generate a new value for each ticket it issues.

- ticket\_nonce:  
	The value of each ticket, which is unique among all tickets issued on this connection.

- ticket:  
	This value is used as the PSK identity. The ticket itself is an opaque label. It can be a database lookup key, or a self-encrypted and self-authenticated value.

- extensions:  
	A set of extension values for the ticket. The client MUST ignore unrecognized extensions.
	
	The only extension currently defined for NewSessionTicket is "early\_data", which indicates that the ticket can be used to send 0-RTT data. It contains the following value:

- max\_early\_data\_size:  
	This field indicates the maximum amount of 0-RTT data (in bytes) that the client is allowed to send when using the ticket. The amount of data counts only the application data payload (i.e., plaintext, excluding padding or the inner content type byte). If the server receives 0-RTT data whose size exceeds max\_early\_data\_size bytes, it should immediately terminate the connection with an "unexpected\_message" alert. Note that a server that rejects early data because of missing keying material will be unable to distinguish padding within the content, so clients should not rely on being able to send large amounts of padding in early data records.


The ticket associated with the PSK is computed as follows:
```c
       HKDF-Expand-Label(resumption_master_secret,
                        "resumption", ticket_nonce, Hash.length)
```
Because the ticket\_nonce value is different for each NewSessionTicket message, each ticket derives a different PSK.

Note that, in principle, new tickets can continue to be issued, indefinitely extending the lifetime of the keying material originally derived from the initial non-PSK handshake, which is most likely associated with the peer certificate.
 

Implementations are advised to impose an overall lifetime limit on such keying material. These limits should take into account the peer certificate’s lifetime, the possibility of intervening revocation, and the time elapsed since the peer’s online CertificateVerify signature.

The flowchart for a full handshake is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/122_54.png)

After the handshake is complete, a KeyUpdate sub-message may also be received. This sub-message is the Key Update (KU) message responsible for updating keys to ensure AEAD security.

The ultimate goal of the TLS protocol is to negotiate the symmetric key and encryption algorithm used during the session. Both parties ultimately use that key and symmetric encryption algorithm to encrypt messages. AEAD（Authenticated\_Encrypted\_with\_associated\_data）is the only encryption mode retained and supported in TLS 1.3. AEAD integrates integrity verification and data encryption into a single algorithm. TLS 1.2 also supports stream ciphers and block ciphers in CBC mode, using MACs for data integrity verification; both approaches have been shown to have certain security flaws.

However, even AEAD still has [research showing](http://link.zhihu.com/?target=http%3A//www.isg.rhul.ac.uk/~kp/TLS-AEbounds.pdf) that it has certain limitations: once the plaintext encrypted with the same key reaches a certain length, the security of the ciphertext can no longer be guaranteed. Therefore, TLS 1.3 introduces a key update mechanism. One side can (usually the server) send a Key Update (KU) message to the other side. After receiving the message, the peer applies HKDF once more to the current session key, computes a new session key, and uses that key for subsequent communication.

>If you want to learn more about Key Update messages, you can read the author’s earlier article [“Key and Initialization Vector Update”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update)

## 8. An Intuitive Look at the Initial TLS 1.3 Handshake Flow

In this chapter, the author uses Wireshark to capture packets from the TLS 1.3 handshake flow, giving readers an intuitive feel for the TLS 1.3 handshake process.

![](https://img.halfrost.com/Blog/ArticleImage/122_21.png)

The image above shows the ClientHello message in TLS 1.3. In the structure of this message, the main difference from TLS 1.2 lies in the extensions. TLS 1.3 includes the extensions that TLS 1.2 has, but it also adds several important extensions.

![](https://img.halfrost.com/Blog/ArticleImage/122_22.png)

The image above shows all extensions in the ClientHello for an initial full handshake in TLS 1.3.

![](https://img.halfrost.com/Blog/ArticleImage/122_23.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_24.png)

Expanding these extensions, you can see that TLS 1.3 includes all the extensions present in TLS 1.2. Their data structures have not changed either.

![](https://img.halfrost.com/Blog/ArticleImage/122_25.png)

This is the key\_share extension newly added in TLS 1.3. This extension contains the elliptic curve types supported by the Client and the corresponding (EC)DHE key agreement parameters.

![](https://img.halfrost.com/Blog/ArticleImage/122_26.png)

psk\_key\_exchange\_modes is also a new extension in TLS 1.3. The semantics of this extension are that the Client only supports PSKs used with these modes. This restricts the use of the PSKs offered in this ClientHello, and also restricts the use of PSKs offered by the Server via NewSessionTicket.

psk\_ke: Represents PSK-only key establishment. In this mode, the Server must not provide a "key\_share" value.

psk\_dhe\_ke: PSK plus (EC)DHE establishment. In this mode, both the Client and the Server must provide "key\_share" values.

![](https://img.halfrost.com/Blog/ArticleImage/122_27.png)

supported\_versions is a mandatory extension in TLS 1.3. If this extension is absent, the Server will assume that the Client only supports TLS 1.2, and the subsequent handshake will proceed using the TLS 1.2 handshake flow.

![](https://img.halfrost.com/Blog/ArticleImage/122_28_.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_28_0.png)

In ServerHello, the Server responds to the Client, and the supported\_versions extension contains the negotiated protocol version.

![](https://img.halfrost.com/Blog/ArticleImage/122_29.png)

ServerHello also carries the Server’s key agreement parameters, placed in the key\_share extension.

![](https://img.halfrost.com/Blog/ArticleImage/122_30.png)


![](https://img.halfrost.com/Blog/ArticleImage/122_31.png)

The EncryptedExtensions sub-message carries any extensions that are not needed to establish the cryptographic context and are not associated with individual certificates, such as the server\_name and ALPN extensions here.

![](https://img.halfrost.com/Blog/ArticleImage/122_33.png)

The Certificate message carries the OCSP Response extension.

![](https://img.halfrost.com/Blog/ArticleImage/97_20.png)

The ChangeCipherSpec and Finished messages are no different from those in TLS 1.2.

![](https://img.halfrost.com/Blog/ArticleImage/122_32.png)

After the initial full handshake is complete, a NewSessionTicket message is also sent. This message carries the early\_data extension. If this extension is present, it indicates that the Server supports 0-RTT. If this extension is not present, as shown below:  

![](https://img.halfrost.com/Blog/ArticleImage/97_21.png)

If this extension is not present, it indicates that the Server does not support 0-RTT, and the Client should not send the early\_data extension during the next session resumption.

## 9. TLS 1.3 Session Resumption


Many articles online misunderstand the second TLS 1.3 handshake. After practicing it myself, I discovered the “truth.”

TLS 1.3 was promoted primarily around 0-RTT, so people tend to think that TLS 1.3 always uses 0-RTT during the second handshake. This includes some online analysis articles that mention the latest PSK key agreement; PSK key agreement is not necessarily 0-RTT.

A subsequent TLS 1.3 handshake actually falls into two categories: session resumption mode and 0-RTT mode. Non-0-RTT session resumption mode does not improve latency compared with TLS 1.2; both are 1-RTT, although TLS 1.3 is more secure. TLS 1.3 only improves over TLS 1.2 in 0-RTT session resumption mode. The specific comparison is shown in the table below:  


||Initial HTTP/2 + TLS 1.2 Connection|HTTP/2 + TLS 1.2 Session Resumption|Initial HTTP/2 + TLS 1.3 Connection|HTTP/2 + TLS 1.3 Session Resumption|HTTP/2 + TLS 1.3 0-RTT|
|:---:|:---:|:---:|:---:|:---:|:---:|
|DNS Resolution| 1-RTT | 0-RTT | 1-RTT | 0-RTT | 0-RTT |
|TCP Handshake| 1-RTT | 1-RTT | 1-RTT | 1-RTT | 1-RTT |
|TLS Handshake| 2-RTT | 1-RTT | 1-RTT | 1-RTT | 0-RTT |
|HTTP Request| 1-RTT | 1-RTT | 1-RTT | 1-RTT | 1-RTT |
|Total| 5-RTT | 3-RTT | 4-RTT | 3-RTT | 2-RTT |

If TCP TFO is enabled, the time to receive the first HTTPS response packet can be reduced by one additional RTT on top of the table above.

In a full handshake, after the Client receives the Finished message, it also receives a NewSessionTicket message.
```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```
The server uses ticket\_nonce together with the resumption\_master\_secret computed after sending the Finished submessage as inputs to HKDF-Expand-Label to compute the ticket field in NewSessionTicket:
```c
     PskIdentity.identity = ticket 
     					  = HKDF-Expand-Label(resumption_master_secret, "resumption", ticket_nonce, Hash.length)
```
**Differences between TLS 1.2 and TLS 1.3: in TLS 1.2, NewSessionTicket contains the master secret, whereas in TLS 1.3, the ticket is merely a PSK**. After the client receives NewSessionTicket, it can generate a PskIdentity. If there are multiple PskIdentity values, they are all placed in the identities array. The binders array contains PskBinderEntry HMAC values that correspond one-to-one with identities in the same order.
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
How `PskBinderEntry` is computed:
```c
	PskBinderEntry = HMAC(binder_key, Transcript-Hash(Truncate(ClientHello1)))
				   = HMAC(Derive-Secret(HKDF-Extract(0, PSK), "ext binder" | "res binder", ""), Transcript-Hash(Truncate(ClientHello1)))
				   
where     binder_key = Derive-Secret(HKDF-Extract(0, PSK), "ext binder" | "res binder", "")				   
```
HMAC includes the `PreSharedKeyExtension.identities` field. In other words, HMAC covers the entire ClientHello, but excludes the binder list (otherwise it would create a chicken-and-egg circular dependency). The purpose of the Truncate() function is to remove the binders list from the ClientHello.

The client can store the PSK in a local cache, using serverName as the cache key.

### 1. Session resumption mode

TLS 1.3 changes the session resumption mechanism: it deprecates the original Session ID and Session Ticket approaches and uses the PSK mechanism instead. It also adds an expiration time to the New Session Ticket. In TLS 1.2, tickets do not include an expiration time; previously issued tickets can be invalidated by rotating the ticket key, or a custom expiration-checking policy can be added when generating the ticket.

After a full handshake has completed, a PSK is generated. The next handshake enters session resumption mode. In the ClientHello, the client first looks up the PSK corresponding to servername in the local cache. If found, it includes two parts in the pre\_shared\_key extension of the ClientHello:

- Identity: the encrypted ticket from NewSessionTicket
- Binder: derive binder\_key from the PSK, and use binder\_key to compute an HMAC over the ClientHello excluding the binder list portion.
```c
       Early Secret = HKDF-Extract(0, PSK)
       binder_key = Derive-Secret(Early Secret, "ext binder" | "res binder", "")
       client_early_traffic_secret = Derive-Secret(Early Secret, "c e traffic", ClientHello)
       early_exporter_master_secret = Derive-Secret(Early Secret, "e exp master", ClientHello)
```
Note: When there are multiple different types of extensions, except for "pre\_shared\_key", which must be the last extension in ClientHello, the order of all other extensions may be arbitrary. ("pre\_shared\_key" may appear at any position in the extension block of ServerHello.) There must not be multiple extensions of the same type.


The PSK is derived from the resumption secret. The PSK ultimately derives the encryption keys for earlyData, as well as the HMAC key for the binder in the pre\_shared\_key extension. After sending ClientHello, the client uses PskIdentity.identity derived from the resumption secret to generate the PSK, then derives the client\_early\_traffic\_secret, generates the Key and IV, encrypts the early data, and sends it.


After the Server receives a ClientHello containing a PSK, it generates the negotiated keyshare and checks the pre\_shared\_key extension in the ClientHello. It decrypts PskIdentity.identity (that is, the ticket), checks whether the ticket has expired, and, after all checks pass, derives the binder\_key from the PSK and computes the HMAC over the ClientHello to verify that the binder is correct. After verifying the ticket and binder, the Server includes the pre\_shared\_key extension in the ServerHello extensions to indicate which PSK is used for session resumption. As with the Client, it starts from the resumption secret to derive the PSK, and ultimately derives the key used for earlyData. The subsequent key derivation rules are the same as in a full handshake; the only difference is that session resumption has an additional PSK, which is used as the input keying material (IKM) for the early secret.

TLS 1.3 and TLS 1.2 differ significantly in key derivation for session resumption. TLS 1.2 session resumption directly reuses the previous master secret and then generates the session keys (key block). TLS 1.3 only uses the resumption secret to derive the input keying material (IKM) for the early data key — the PSK. The remaining key derivation rules are the same as in a full TLS 1.3 handshake.


After sending ServerHello, the Server still needs to continue sending the EncryptedExtensions and Finished messages. However, in session resumption mode, it no longer needs to send the Certificate and CertificateVerify messages. As long as both parties prove that they possess the same PSK, certificate-based authentication is no longer required to prove their identities. From this perspective, a PSK can also be considered an authentication mechanism.


The flowchart is as follows:
```c
          Client                                               Server

   Initial Handshake:
          ClientHello
          + key_share               -------->
                                                          ServerHello
                                                          + key_share
                                                {EncryptedExtensions}
                                                {CertificateRequest*}
                                                       {Certificate*}
                                                 {CertificateVerify*}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Certificate*}
          {CertificateVerify*}
          {Finished}                -------->
                                    <--------      [NewSessionTicket]
          [Application Data]        <------->      [Application Data]


   Subsequent Handshake:
          ClientHello
          + key_share*
          + pre_shared_key          -------->
                                                          ServerHello
                                                     + pre_shared_key
                                                         + key_share*
                                                {EncryptedExtensions}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Finished}                -------->
          [Application Data]        <------->      [Application Data]
```
I previously wrote an article analyzing the details of PSK. If you are interested, see [Pre-Shared Key Extension](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension). Here is a brief description of the PSK extension.

The "pre\_shared\_key" extension is used to negotiate an identity, which identifies the pre-shared key associated with the PSK key used for a given handshake.

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
	An obfuscated version of the age of the key. [This section](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-ticket-age) describes how this value is generated for identities established via the NewSessionTicket message. For externally established identities, obfuscated\_ticket\_age should be 0, and the Server must ignore this value.


- identities:  
	The list of identities that the Client is willing to negotiate with the Server. If sent together with "early\_data", the first identity is used to identify the 0-RTT data.
	

- binders:  
	A sequence of HMAC values. Each value corresponds one-to-one with an entry in the identities list, in the same order.

- selected\_identity:  
	The identity selected by the Server, expressed as a 0-based index into the Client's list of identities.

Each PSK is associated with a single hash algorithm. For PSKs established via tickets, when the ticket is established in the connection, the hash algorithm used is the KDF hash algorithm. For externally established PSKs, the hash algorithm must be set when the PSK is established; if it is not set, the default algorithm is SHA-256. The Server must ensure that the PSK it selects, if any, is compatible with the cipher suite.


Before accepting PSK key establishment, the Server must first verify the corresponding binder value. If this value is absent or cannot be verified, the Server must immediately abort the handshake. The Server should not attempt to verify multiple binders; instead, it should select a single PSK and verify only the binder corresponding to that PSK. To accept a connection using PSK key establishment, the Server sends the "pre\_shared\_key" extension, indicating the identity it selected.


The Client must verify that the Server's selected\_identity is within the range provided by the Client. The cipher suite selected by the Server indicates the hash algorithm associated with the PSK, and if required by the ClientHello "psk\_key\_exchange\_modes", the Server should also send the "key\_share" extension. If these values are inconsistent, the Client must immediately abort the handshake with an "illegal\_parameter" alert message.


If the Server provides the "early\_data" extension, the Client must verify that the Server's selected\_identity is 0. If any other value is returned, the Client must abort the handshake with an "illegal\_parameter" alert message.


The "pre\_shared\_key" extension must be the last extension in the ClientHello (this facilitates the implementation described below). The Server must check that it is the last extension; otherwise, it must abort the handshake with an "illegal\_parameter" alert message.


#### (1) Ticket Age


From the Client's perspective, the age of a ticket is the time elapsed from receiving the NewSessionTicket message to the current moment. The Client must never use a ticket whose age is greater than the "ticket\_lifetime" indicated by the ticket itself. The "obfuscated\_ticket\_age" field in each PskIdentity must contain an obfuscated version of the ticket age, computed by adding the ticket age (in milliseconds) to the "ticket\_age\_add" field and then reducing the result modulo 2^32. Unless the ticket is reused, this obfuscation can prevent passive observers from correlating connections. Note that the "ticket\_lifetime" field in the NewSessionTicket message is in seconds, while "obfuscated\_ticket\_age" is in milliseconds. Because the ticket lifetime is limited to one week, 32 bits are sufficient to represent any reasonable duration, even in milliseconds.


#### (2) PSK Binder

PSK binder values form two kinds of bindings: one between the PSK and the current handshake, and another between the handshake in which the PSK was generated (if it was generated via a NewSessionTicket message) and the current handshake. Each entry in the binder list computes an HMAC over the hash transcript of a portion of the ClientHello, and the final HMAC includes the PreSharedKeyExtension.identities field. In other words, the HMAC covers the entire ClientHello, but not the binder list. If binders of the correct length are present, the message length fields (including the total length, the extension block length, and the length of the "pre\_shared\_key" extension) are all set.


PskBinderEntry is computed in the same way as the Finished message. However, the BaseKey is the derived binder\_key, which is derived from the corresponding provided PSK.

If the handshake includes a HelloRetryRequest message, the initial ClientHello and the HelloRetryRequest are included in the transcript along with the new ClientHello. For example, if the Client sends a ClientHello, its binder is computed as follows：
```c
      Transcript-Hash(Truncate(ClientHello1))
```
The purpose of the `Truncate()` function is to remove the binders list from `ClientHello`.

If the Server responds with `HelloRetryRequest`, the Client sends `ClientHello2`, whose binder is computed as follows:
```c
      Transcript-Hash(ClientHello1,
                      HelloRetryRequest,
                      Truncate(ClientHello2))
```
The complete ClientHello1/ClientHello2 are included in the other handshake hash computations. Note that in the first transmission, `Truncate(ClientHello1)` is hashed directly, but in the second transmission, ClientHello1 is hashed, and an additional "message\_hash" message is injected.

Some of the computation flow for session resumption keys is shown below:
```c
             0
             |
             v
   PSK ->  HKDF-Extract = Early Secret
             |
             +-----> Derive-Secret(., "ext binder" | "res binder", "")
             |                     = binder_key
             |
             +-----> Derive-Secret(., "c e traffic", ClientHello)
             |                     = client_early_traffic_secret
             |
             +-----> Derive-Secret(., "e exp master", ClientHello)
             |                     = early_exporter_master_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
```
The flowchart for PSK session resumption is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/122_55_.png)

### 2. 0-RTT Mode

First, let’s look at the change history of 0-RTT across the drafts.

|    Draft    | Changes |
| ---------- | --- |
| draft-07   |  Basic support for 0-RTT was first added in draft-07 |
| draft-11   |  1. Removed the early\_handshake content type in draft-11<br>2. Used an alert to terminate 0-RTT data |
| draft-13   |  1. Removed 0-RTT client authentication<br>2. Removed (EC)DHE 0-RTT<br>3. Expanded the 0-RTT PSK mode and shrank EarlyDataIndication |
| draft-14   |  1. Removed 0-RTT EncryptedExtensions<br>2. Lowered the barrier to using 0-RTT<br>3. Clarified 0-RTT backward compatibility<br>4. Explained the relationship between 0-RTT and PSK key exchange |
| draft-15   |  Discussed the 0-RTT time window |
| draft-16   |  1. Forbid CertificateRequest when using 0-RTT and PSK<br>2. Relaxed the 0-RTT requirement to check SNI |
| draft-17   |  1. Removed 0-RTT Finished and resumption\_context, and replaced them with the psk\_binder field of the PSK itself<br>2. Harmonized cipher suite matching requirements: session resumption only needs to match the KDF, but 0-RTT needs to match the entire cipher suite. Allows the PSK to actually negotiate the cipher suite<br>3. Clarified the conditions under which PSK may be used for 0-RTT |
| draft-21   |  Discussed 0-RTT and replay, and recommended implementing anti-replay mechanisms |

Historically, the discussion moved from functional issues to performance issues, and finally to security issues.


According to Google’s statistics, 60% of website access traffic across the Internet comes from newly visited sites, or from sites that were visited before but are accessed again after some time. With the optimizations in TLS 1.3, this portion of traffic has already been reduced from 2-RTT to 1-RTT. The remaining 40% of website access traffic comes from session resumption. TLS 1.3 abolished the previous Session ID and Session Ticket approaches to session resumption and unified them under the PSK approach, making the original session resumption mechanism more secure. However, session resumption in TLS 1.3 does not reduce the RTT; it still remains at 1-RTT. To further reduce latency, the concept of 0-RTT was proposed. 0-RTT can give users a faster, smoother, and better user experience, especially on mobile networks.


A milestone feature of TLS 1.3 is the addition of the 0-RTT session resumption mode. That is, when the client and server share a PSK (obtained externally or through a previous handshake), TLS 1.3 allows the client to carry data ("early data") in the first message it sends. The client uses this PSK to generate client\_early\_traffic\_secret and uses it to encrypt the early data. After receiving this ClientHello, the server derives client\_early\_traffic\_secret from the PSK in the ClientHello extension and uses it to decrypt the early data.

The 0-RTT session resumption mode is as follows:
```c
         Client                                               Server

         ClientHello
         + early_data
         + key_share*
         + psk_key_exchange_modes
         + pre_shared_key
         (Application Data*)     -------->
                                                         ServerHello
                                                    + pre_shared_key
                                                        + key_share*
                                               {EncryptedExtensions}
                                                       + early_data*
                                                          {Finished}
                                 <--------       [Application Data*]
         (EndOfEarlyData)
         {Finished}              -------->
         [Application Data]      <------->        [Application Data]
```
There are also certain prerequisites for implementing 0-RTT, and they are fairly strict. If any one of them is not met, session resumption can only use the 1-RTT PSK session resumption mode.

The **conditions for enabling** 0-RTT are:

- 1. In the previous full handshake, the Server sent a NewSessionTicket, and the Session ticket contains the max\_early\_data\_size extension, indicating that it is willing to accept early data. Without this extension, 0-RTT cannot be enabled.
- 2. During PSK session resumption, the ClientHello extensions include the early data extension, indicating that the Client wants to enable 0-RTT mode.
- 3. The Server includes the early data extension in the Encrypted Extensions message, indicating that it agrees to read early data. 0-RTT mode is successfully enabled.

Only when all three conditions above are satisfied can 0-RTT session resumption mode be enabled. Otherwise, the handshake will use the 1-RTT session resumption mode.

>Although many browsers currently support the TLS 1.3 protocol, they still do not support sending early data, so they also cannot enable session resumption in 0-RTT mode.


The conditions for enabling 0-RTT already show how it differs from the 1-RTT session resumption described above. The ClientHello must include the early\_data extension, the Server must include the early\_data extension in the Encrypted Extensions message, and after the Client finishes sending early\_data, it also needs to send an EndOfEarlyData submessage.
```c
      struct {} EndOfEarlyData;
```
After the Client sends early\_data, it can continue sending early\_data. If the Server sends the "early\_data" extension in EncryptedExtensions, the Client must send an EndOfEarlyData message after receiving the Server's Finished message. If the Server does not send the "early\_data" extension in EncryptedExtensions, the Client is prohibited from sending the EndOfEarlyData submessage. This message indicates that all 0-RTT application\_data messages (if any) have been transmitted, and that subsequent records are protected by the handshake traffic keys. The Server must not send this message. If the Client receives this message, it must terminate the connection with an "unexpected\_message" alert. This message is encrypted and protected using keys derived from client\_early\_traffic\_secret.

**Note**: early data is not included in the final Finished verification computation. In addition, the EndOfEarlyData submessage is also not included in the computation of the final application traffic secret.

After receiving ClientHello, the Server should immediately send the ServerHello, ChangeCipherSpec, EncryptedExtensions, and Finished submessages.


If the Server wants to reject the Client's 0-RTT session resumption, it only needs to break one of the three enabling conditions:

- Reject PSK. If the Server does not include the pre\_shared\_key extension in ServerHello, the handshake falls back to a full handshake, thereby naturally rejecting 0-RTT.
- Reject only early\_data while accepting PSK. Include the pre\_shared\_key extension in ServerHello, but do not include the early\_data extension in the EncryptedExtension submessage.

Even though the Client still sends the handshake message with the early\_data extension, the keys derived by the Server are now server/client\_handshake\_traffic\_secret rather than client\_early\_traffic\_secret, so it cannot decrypt the early\_data content. When decryption fails with an error, the Server discards this extension and ignores it. As a result, 0-RTT is downgraded to 1-RTT.

The flowchart for the 0-RTT handshake is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/122_56_.png)


Although TLS 1.3 introduced the revolutionary 0-RTT session resumption mode, 0-RTT has security risks. The security of 0-RTT data is weaker than that of other types of TLS data, in particular:

1. 0-RTT data does not provide forward secrecy; it is encrypted using keys derived from the provided PSK.
2. There is no guarantee against replay attacks across multiple connections. Ordinary TLS 1.3 1-RTT data protects against replay attacks by using randomness sent by the server. Since 0-RTT does not depend on the ServerHello message, its protections are weaker. This security consideration is especially important if the data is authenticated together with TLS client authentication or within the application protocol. This warning applies to any use of early\_exporter\_master\_secret.


Replay attacks must be prevented in TLS 1.3 0-RTT. There are four measures for preventing replay of 0-RTT:

- The first measure is to check the expiration time in the PSK. If it has expired, the requests in early\_data are not processed, and the handshake is downgraded to 1-RTT.

- The second measure is to disallow non-idempotent requests in 0-RTT. If a non-idempotent request appears, the Server ignores it and does not process it. GET requests are idempotent, but even they must not be allowed to carry parameters; only GET requests without parameters can be allowed.

- The third measure is to record the value of the PSK binder or a random value in the request header. This value can guarantee global uniqueness of 0-RTT early\_data, thereby preventing replay attacks. When the Server receives ClientHello, it first verifies the PSK binder. It then computes expected\_arrival\_time. If it is outside the recording window, the Server rejects 0-RTT and falls back to a 1-RTT handshake. If expected\_arrival\_time is within the window, the Server checks whether it has recorded a matching ClientHello. If one is found, it aborts the handshake with an "illegal\_parameter" alert, or accepts the PSK but rejects 0-RTT. If no matching ClientHello is found, it accepts 0-RTT and stores the ClientHello as long as expected\_arrival\_time remains within the window. The Server can also implement a data store with false positives, such as a Bloom filter; in that case, it must respond to apparent replays by rejecting 0-RTT, but must never abort the handshake. For this measure, there may also be cases with multiple binders; in a distributed system, there may also be issues with multiple zones. For a detailed analysis, see my article [“TLS 1.3 0-RTT and Anti-Replay”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md).

- The fourth measure is to record all outstanding valid tickets in a database and delete a ticket after it is used once. If a replay attack occurs, that ticket will necessarily be absent from the database, so the handshake falls back to a full handshake.


> Regarding the security of 0-RTT, I wrote a dedicated article discussing this topic. See [“TLS 1.3 0-RTT and Anti-Replay”](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md)


## X. An Intuitive Look at TLS 1.3 Session Resumption

In this chapter, I use Wireshark to capture packets from TLS 1.3 session resumption, giving readers an intuitive view of the TLS 1.3 session resumption process.


### 1. PSK Session Resumption


![](https://img.halfrost.com/Blog/ArticleImage/122_34.png)

This is the complete flow of TLS 1.3 session resumption.

![](https://img.halfrost.com/Blog/ArticleImage/122_35.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_36.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_37.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_38.png)

The four extensions above are required in ClientHello for TLS 1.3 PSK session resumption: psk\_key\_exchange\_modes, pre\_shared\_key, key\_share, and supported\_versions.

![](https://img.halfrost.com/Blog/ArticleImage/122_39.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_40.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_41.png)

The three extensions above are required in ServerHello for TLS 1.3 PSK session resumption: pre\_shared\_key, key\_share, and supported\_versions.

![](https://img.halfrost.com/Blog/ArticleImage/122_42.png)

Once PSK verification is complete, the Server no longer needs to send the certificate again. It can complete session resumption by directly responding with ChangeCipherSpec, Encrypted Extensions, and Finished.

### 2. 0-RTT

As of the time I wrote this article, support for TLS 1.3 in current mainstream browsers was as shown below.

![](https://img.halfrost.com/Blog/ArticleImage/122_53.png)

The latest Google Chrome Canary 74.0.3702.0 still did not support 0-RTT mode. The latest Firefox Nightly 67.0a1 supported 0-RTT mode (set security.tls.enable\_0rtt\_data to true in about:config). The latest Safari 12.0.3 (14606.4.5) still did not support 0-RTT mode. Therefore, I could only use Firefox Nightly to capture 0-RTT packets.

Of course, the Client in the latest OpenSSL 1.1.1a does support sending early\_data, which means it supports 0-RTT; using it to debug TLS 1.3 0-RTT is also more convenient.

First, let's look at the packets captured from Firefox Nightly with 0-RTT support.


![](https://img.halfrost.com/Blog/ArticleImage/122_43_.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_44.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_45.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_46.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_47.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_48.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_49.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_50.png)

As you can see, the entire session resumption process satisfies the conditions for 0-RTT, so 0-RTT is successfully enabled.

Next, test 0-RTT with the OpenSSL Client.

First, export the necessary parameters, such as the negotiated keys and session information.
```c
$ openssl s_client -connect halfrost.com:443 -tls1_3 -keylogfile=/Users/ydz/Documents/sslkeylog.log -sess_out=/Users/ydz/Documents/tls13.sess
```
Output as follows:
```c
CONNECTED(00000006)
depth=1 C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
verify error:num=20:unable to get local issuer certificate
---
Certificate chain
 0 s:CN = halfrost.com
   i:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
 1 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
   i:O = Digital Signature Trust Co., CN = DST Root CA X3
 2 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
   i:O = Digital Signature Trust Co., CN = DST Root CA X3
---
Server certificate
-----BEGIN CERTIFICATE-----
MIIEljCCA36gAwIBAgISA9VdA6rPN6mIzBxEPL/3iAICMA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xOTAyMTAwMTQxMjJaFw0x
OTA1MTEwMTQxMjJaMBcxFTATBgNVBAMTDGhhbGZyb3N0LmNvbTBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABA7sYzIwq29BkT1mQ2TSZRPe34BlnuqN65xoLY+A87M8
PpblV0IvNyj4ZdcgiSmSZffocVF6wzck6TmsQ/j2/sujggJyMIICbjAOBgNVHQ8B
Af8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB
/wQCMAAwHQYDVR0OBBYEFOD4YIpf+PkD1Jvy+eayPn0csEi/MB8GA1UdIwQYMBaA
FKhKamMEfd265tE5t6ZFZe/zqOyhMG8GCCsGAQUFBwEBBGMwYTAuBggrBgEFBQcw
AYYiaHR0cDovL29jc3AuaW50LXgzLmxldHNlbmNyeXB0Lm9yZzAvBggrBgEFBQcw
AoYjaHR0cDovL2NlcnQuaW50LXgzLmxldHNlbmNyeXB0Lm9yZy8wKQYDVR0RBCIw
IIIMaGFsZnJv\ghfhjghjjbmd3cuaGFsZnJvc3QuY29tMEwGA1UdIARFMEMwCAYG
Z4EMAQIBMDcGCysGAQQBgt8TAQEBMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly9jcHMu
bGV0c2VuY3J5cHQub3JnMIIBAwYKKwYBBAHWeQIEAgSB9ASB8QDvAHUA4mlLribo
6UAJ6IYbtjuD1D7n/nSI+6SPKJMBnd3x2/4AAAFo1UfZTgAABAMARjBEAiAsXJLC
A5uO2R926Dba3fZpV/zvzG9tCPVtTKAeso5bAwIgMXoLRtLqhG5bEcXIpGXJcrd0
6S8tbUdS9YRAIWpMX1oAdgApPFGWVMg5ZbqqUPxYB9S3b79Yeily3KTDDPTlRUf0
eAAAAWjVR9lQAAAEAwBHMEUCIHv6NJ9MWMiL+AHxU8ilL3APMmPkUcc03SjBiDaW
Vm6JAiEA5YF/XHKuYH0S0+mqfB+YdT0FIey9wFQObkR4/Qvzla4wDQYJKoZIhvcN
AQELBQADggEBAHU7a+EgzdhrsyD+2ch7AGD1n1TjDfdxkEjmoitN0Tjh4q3jP/IK
7FPs0LBsDRusmtJVK3gZQc9cTEy/om86VQtcnV0LhK83GnFUIuLTEzeTZmnz6Qbs
3KznprZH0DRUbfpmZsDNIfBEOUOXiBR4DpLd3tPVfRkQowmO6o39vM4UOGlB0zIA
g977q97IT6wS9BCEiGmuF0HSjpLfiPhTy9bpl2VGcJVpIy2TS+d4+JWRI7K5BFSz
ncGDzHJ+zGsx4wS+dxuiwaS9hw4c0FG2V4kMFnA+orAa/oTnfwFlRIehTbDBO+rN
TNtjm4yh63M9gInoQEI1REl2EkGcWug6Ijs=
-----END CERTIFICATE-----
subject=CN = halfrost.com

issuer=C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3

---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: ECDSA
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 3912 bytes and written 316 bytes
Verification error: unable to get local issuer certificate
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 256 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 20 (unable to get local issuer certificate)
---
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: DECE5063ABC2D1162A5E767C55083FDFFA6A86B64082FE3AD990A213AE
    Session-ID-ctx:
    Resumption PSK: EACCC93ACB3DC420DF5027BEC576EE130D11BF546463034C1BB92B54806057E0C9F5C3DB557AD10D425E
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 86400 (seconds)
    TLS session ticket:
    0000 - 0b 8d e5 44 b2 62 71 9d-f9 0a ec da f0 d0 6a 0b   ...D.bq.......j.
    0010 - 97 5d 63 21 ea 1e 8a 69-01 52 a9 0a 19 bf 5c a3   .]c!...i.R....\.
    0020 - 67 45 a3 a0 28 65 ea 9c-c8 d4 cf df 5d c5 5a be   gE..(e......].Z.
    0030 - 32 45 0d 1e af f7 32 67-4a d8 66 cb b6 cb c8 0e   2E....QgJ.f.....
    0040 - 6b b8 53 a8 d2 d4 4b 7b-cc a6 cb 52 39 61 20 6d   k.S...K{...R9a m
    0050 - 75 f8 cb 43 11 1d 58 a2-de 2b 74 b0 ca 70 a2 9c   u..C..X..+t..p..
    0060 - 85 6b 1a 00 9a f1 bd 9b-8c b4 5a 41 aa 4b 64 5d   .k........ZA.Kd]
    0070 - 5a 48 23 a6 10 49 4f 61-c9 57 74 f4 56 50 83 1a   ZH#..IOa.Wt.VP..
    0080 - 1b 74 6c ea 09 99 42 f5-d6 3c 6d 4f 5b 98 ca b3   .tl...B..<mO....
    0090 - c7 72 56 5c 6c 67 71 77-8d 68 f7 54 e5 e3 7b d3   .rV\lgqw.h.T..{.
    00a0 - 24 ff 42 0c 3f 12 27 42-7f 9e 0a 4c c2 79 60 45   $.B.?.'B...L.y`E
    00b0 - 2d 77 a2 c8 2f f5 85 34-fa ce 79 ee 0b ea 00 c1   -w../..4..y.....
    00c0 - 74 33 f0 6c af 7a 1a 55-f8 35 bd 5e 49 66 6f 06   t3.l.z.U.5.^Ifo.
    00d0 - c6 38 ed a6 82 e2 c8 77-99 b7 34 9a 4a 9a 31 40   .8.....w..4.J.1@
    00e0 - f1 93 a0 94 7f 1e 8d e0-54 29 dc e3 6f 5c 93 21   ........T)..o\.!

    Start Time: 1549886406
    Timeout   : 7200 (sec)
    Verify return code: 20 (unable to get local issuer certificate)
    Extended master secret: no
    Max Early Data: 16384
---
read R BLOCK
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: B7E28DE5DF2C95F2E3DE43732E4F9A45A8943ED3856B73CAB5E7260E7
    Session-ID-ctx:
    Resumption PSK: BF2BA2304BEB2B948F7BF6617D0KDRNFB9CD5466DEC1EB9697D2543B7BB913BC7854359D7F5DF7559D67
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 86400 (seconds)
    TLS session ticket:
    0000 - 0b 8d e5 44 b2 62 71 9d-f9 0a ec da f0 d0 6a 0b   ...D.bq.......j.
    0010 - b4 9f cc 17 63 9a 70 c8-63 f8 2e c4 9f d4 a1 f8   ....c.p.c.......
    0020 - 22 34 22 03 d0 f9 78 66-a0 d4 2f 62 53 d3 d8 e3   "4"...xf../bS...
    0030 - 55 2c a5 7c 0b 19 b3 fc-77 55 8c de 0b 2d 00 bd   U,.|....wUL..-..
    0040 - b8 fa 2e 00 30 78 c8 dc-35 14 d3 61 f0 69 38 59   ...%0x..5..a.i8Y
    0050 - ee 2a 75 7e 50 34 3f e3-25 04 71 1c 6e c9 c8 20   .*u~P4?.%.q.n..
    0060 - d7 4e 44 b3 69 56 50 23-38 c2 f1 1e ac 10 a7 ff   .ND.iVP#8.......
    0070 - 96 cf fe ff 4d 07 7e 08-2d 37 49 78 ab 1d 78 6e   ....M.~.-7Ix..xn
    0080 - 62 4b 99 e7 37 03 3e a2-89 de 61 48 a1 c5 77 18   bK..7.>...aH..w.
    0090 - 6f 1c 95 8a 0d 1d 17 68-88 8a 01 5b f0 dc ea 06   o......h...[....
    00a0 - 98 dc 7e 94 f8 ef 4a 72-ff ba e5 03 07 c7 3d d0   ..~...Jr......=.
    00b0 - c8 91 a6 ae 9a df 92 25-05 63 77 03 b0 bc b4 ab   .......%.c......
    00c0 - 36 cb 0f 8c 5d ec 58 65-7c 97 2a 30 57 4a 96 b9   6...].Xe|.*0WJ..
    00d0 - 60 21 12 76 77 4c 6d 0d-12 0c 50 cc f5 da 54 4e   `!.vwLm...P...TN
    00e0 - 4b 27 5f 1b dd 11 b1 8d-7f e0 37 43 34 a3 88 34   K'_.......7C4..4

    Start Time: 1549886406
    Timeout   : 7200 (sec)
    Verify return code: 20 (unable to get local issuer certificate)
    Extended master secret: no
    Max Early Data: 16384
---
read R BLOCK
```
Next, reuse the connection just established. The command is as follows:
```c
$ openssl s_client -connect halfrost.com:443 -tls1_3 -keylogfile=/Users/ydz/Documents/sslkeylog.log -sess_in=/Users/ydz/Documents/tls13.sess -early_data=/Users/ydz/Documents/req.txt
```
In req.txt, simply write a GET request:
```c
GET / HTTP/1.1
HOST: halfrost.com
Early-Data: 657567765
```
After running s\_client, the output is as follows:
```c
CONNECTED(00000006)
---
Server certificate
-----BEGIN CERTIFICATE-----
MIIElzCCA3+gAwIBAgISA604VEs+7Wwch5cNQDshC4t+MA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xODEyMDgxMzQzMzhaFw0x
OTAzMDgxMzQzMzhaMBcxFTATBgNVBAMTDGhhbGZyb3N0LmNvbTBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABA7sYzIwq29BkT1mQ2TSZRPe34BlnuqN65xoLY+A87M8
PpblV0IvNyj4ZdcgiSmSZffocVF6wzck6TmsQ/j2/sujggJzMIICbzAOBgNVHQ8B
Af8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB
/wQCMAAwHQYDVR0OBBYEFOD4YIpf+PkD1Jvy+eayPn0csEi/MB8GA1UdIwQYMBaA
FKhKamMEfd265tE5t6ZFZe/zqOyhMG8GCCsGAQUFBwEBBGMwYTAuBggrBgEFBQcw
AYYiaHR0cDovL29jc3AuaW50LXgzLmxldHNlbmNyeXB0Lm9yZzAvBggrBgEFBQcw
AoYjaHR0cDovL2NlcnQuaW50LXgzLmxldHNlbmNyeXB0Lm9yZy8wKQYDVR0RBCIw
IIIMaGFsZnJvc3QuY29tghB3d3cuaGFsZnJvc3QuY29tMEwGA1UdIARFMEMwCAYG
Z4EMAQIBMDcGCysGAQQBgt8TAQEBMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly9jcHMu
bGV0c2VuY3J5cHQub3JnMIIBBAYKKwYBBAHWeQIEAgSB9QSB8gDwAHUA4mlLribo
73qkwe6lN9vZWu1dJV8+Q41cFLGYMJhDD56x7QIgL+V6g1CQst9UDXobdkAEnjah
KiJWihr/Qn3plzgzjiIAdwApPFGWVMg5ZbqqUPxYB9S3b79Yeily3KTDDPTlRUf0
eAAAAWeORhq2AAAEAwBIMEYCIQD1Mf1GtmegyTqIu0S3Q4afNDt0srIFyrtROtn0
jQAV1gIhAJwXIGyMj87kjHtRc/mHJOOCZRSUvoasvWrytCv2dPwXMA0GCSqGSIb3
DQEBCwUAA4IBAQB3sC7jKVGHR8MnAOWnECO/V5Z4oBqbahogwyhOSrbxuutijhyk
8kb3A73Q++Ey150Y+hlNUQStmG9JBGg9pyLG2Yug9p5L13a6VrNaL1VQ1Dq6YgS5
5J8ElsalUgr+9jvTJesdYzfXPdsc8IK67tBXhukqc0/cT3I1QHNwAVru/AKWrkne
H4AcadSeLGe5he2X9OV3JJg+gb/vE90UaVmqwUuSGMzluyBXPMuznTa/+7+31vWV
Q8aWE32X+E5qHSyeLU808mZHYjvKHvuDnNNu6I0KlNcVJf1s0jOQOjgo7hIP/OR4
OlW6ywk07IupV4w07xykP1/tWBsSCviXECcZ
-----END CERTIFICATE-----
subject=CN = halfrost.com

issuer=C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3

---
No client certificate CA names sent
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 245 bytes and written 649 bytes
Verification error: unable to get local issuer certificate
---
Reused, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 256 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was accepted
Verify return code: 20 (unable to get local issuer certificate)
---
```
From the output, you can see `Early data was accepted`. At this point, switch to Wireshark and see what the captured packets look like.

![](https://img.halfrost.com/Blog/ArticleImage/122_52.png)

You can see that the Client sends Application Data immediately after ClientHello.

In Wireshark preferences, uncheck the option shown in the figure below.

![](https://img.halfrost.com/Blog/ArticleImage/122_57.png)

After the configuration takes effect, you can see the request inside the Application Data.

![](https://img.halfrost.com/Blog/ArticleImage/122_51.png)

In a normal GET request, the header includes the Early-Data value. This value is then passed to the Server for processing.


## 11. The TLS 1.3 State Machine

Compared with TLS 1.2, the TLS 1.3 handshake flow has changed significantly, so the state machine has also changed significantly. Below are two state transition diagrams as a summary, which also capture the essence of this article.
```c
                              START <----+
               Send ClientHello |        | Recv HelloRetryRequest
          [K_send = early data] |        |
                                v        |
           /                 WAIT_SH ----+
           |                    | Recv ServerHello
           |                    | K_recv = handshake
       Can |                    V
      send |                 WAIT_EE
     early |                    | Recv EncryptedExtensions
      data |           +--------+--------+
           |     Using |                 | Using certificate
           |       PSK |                 v
           |           |            WAIT_CERT_CR
           |           |        Recv |       | Recv CertificateRequest
           |           | Certificate |       v
           |           |             |    WAIT_CERT
           |           |             |       | Recv Certificate
           |           |             v       v
           |           |              WAIT_CV
           |           |                 | Recv CertificateVerify
           |           +> WAIT_FINISHED <+
           |                  | Recv Finished
           \                  | [Send EndOfEarlyData]
                              | K_send = handshake
                              | [Send Certificate [+ CertificateVerify]]
    Can send                  | Send Finished
    app data   -->            | K_send = K_recv = application
    after here                v
                          CONNECTED
```
This diagram shows the client's state machine during the handshake process. If any step in the middle is still unclear, readers can refer back to the content above to fill in the gaps.
```c
                              START <-----+
               Recv ClientHello |         | Send HelloRetryRequest
                                v         |
                             RECVD_CH ----+
                                | Select parameters
                                v
                             NEGOTIATED
                                | Send ServerHello
                                | K_send = handshake
                                | Send EncryptedExtensions
                                | [Send CertificateRequest]
 Can send                       | [Send Certificate + CertificateVerify]
 app data                       | Send Finished
 after   -->                    | K_send = application
 here                  +--------+--------+
              No 0-RTT |                 | 0-RTT
                       |                 |
   K_recv = handshake  |                 | K_recv = early data
 [Skip decrypt errors] |    +------> WAIT_EOED -+
                       |    |       Recv |      | Recv EndOfEarlyData
                       |    | early data |      | K_recv = handshake
                       |    +------------+      |
                       |                        |
                       +> WAIT_FLIGHT2 <--------+
                                |
                       +--------+--------+
               No auth |                 | Client auth
                       |                 |
                       |                 v
                       |             WAIT_CERT
                       |        Recv |       | Recv Certificate
                       |       empty |       v
                       | Certificate |    WAIT_CV
                       |             |       | Recv
                       |             v       | CertificateVerify
                       +-> WAIT_FINISHED <---+
                                | Recv Finished
                                | K_recv = application
                                v
                            CONNECTED

```
This figure shows the server-side state machine for the handshake flow. If any intermediate step is still unclear, readers can refer back to the preceding sections to fill in the gaps. Once you fully understand the two state machines above, you will have a thorough grasp of TLS 1.3.

End.

------------------------------------------------------

Reference：
   
[RFC 8466](https://tools.ietf.org/html/rfc8446)     
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)    

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS\_handshake/](/https_tls1-3_handshake/)