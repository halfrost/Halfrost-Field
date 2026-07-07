# TLS 1.3 Introduction


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/95_0.png'>
</p>


## I. Purpose of the TLS Protocol

The primary goal of TLS is to provide a secure channel between two communicating parties. The only requirement on the underlying transport is a reliable, ordered data stream.

- Authentication: The server side of the channel should always be authenticated; client authentication is optional. Authentication can be performed using asymmetric algorithms (for example, RSA, the Elliptic Curve Digital Signature Algorithm (ECDSA), or the Edwards-Curve Digital Signature Algorithm (EdDSA)), or by using a symmetric pre-shared key (PSK).

- Confidentiality: Data sent over an established channel is visible only to the endpoints. The TLS protocol cannot hide the length of the data it transmits, but endpoints can hide lengths by padding TLS records, thereby improving protection against traffic analysis techniques.

- Integrity: Data sent over an established channel cannot be tampered with without detection. In other words, once data is modified, the peer will immediately detect the tampering.

> These three properties must be guaranteed even if a network attacker has complete control of the network, as described in RFC 3552. TLS security issues will be discussed separately in a later article.

## II. Components of the TLS Protocol

The TLS protocol consists primarily of two major components:

- Handshake Protocol  
  The Handshake Protocol is mainly responsible for all processes involved in authenticating the communicating parties. This includes key negotiation, parameter negotiation, and establishing shared keys. The Handshake Protocol is designed to resist tampering; if a connection is not under attack, an active attacker should not be able to force peers to negotiate different parameters.

- Record Protocol  
  The Record Protocol uses the parameters established by the Handshake Protocol to protect traffic between the communicating parties. It divides traffic into a series of records, each of which is independently protected with keys to provide confidentiality.

TLS is an independent protocol; higher-level protocols can run transparently on top of TLS. However, the TLS standard does not specify how protocols should strengthen TLS security, how to initiate a TLS handshake, or how to interpret authentication certificate exchanges. These decisions are left to the designers and implementers of protocols that run on top of TLS.

This document defines TLS version 1.3. Although TLS 1.3 is not directly compatible with earlier versions, all versions of TLS include a versioning mechanism that allows clients and servers to negotiate which TLS version to use during communication.

The TLS 1.3 standard replaces and deprecates earlier versions of TLS, including TLS 1.2 [RFC5246 The Transport Layer Security (TLS) Protocol Version 1.2](https://tools.ietf.org/html/rfc5246). It also deprecates the TLS ticket mechanism defined in [RFC5077 Transport Layer Security (TLS) Session Resumption without Server-Side State](https://tools.ietf.org/html/rfc5077), replacing it with the Pre-Shared Key (PSK) mechanism. Because TLS 1.3 changes how keys are exported, it updates [RFC5705 Keying Material Exporters for Transport Layer Security (TLS)](https://tools.ietf.org/html/rfc5705). It also changes how Online Certificate Status Protocol (OCSP) messages are transmitted, and therefore updates [RFC6066 https://tools.ietf.org/html/rfc6066](https://tools.ietf.org/html/rfc6066) and deprecates [RFC6961 The Transport Layer Security (TLS) Multiple Certificate Status Request Extension](https://tools.ietf.org/html/rfc6961), as described in the section on OCSP Status and SCT Extensions.


## III. Major Differences Between TLS 1.3 and TLS 1.2

The following describes the major differences between TLS 1.2 and TLS 1.3. In addition to these major differences, there are many subtle ones.

- Algorithms that are no longer secure have been removed from the list of supported symmetric algorithms. The list retains only algorithms that use Authenticated Encryption with Associated Data (AEAD). The concept of a cipher suite has changed: authentication and key exchange mechanisms have been separated from the record protection algorithm (including key length) and the hash/HMAC used for the key derivation function.

- A 0-RTT mode has been added, saving one round trip for some application data during connection establishment, at the cost of certain security properties. **The security issues around 0-RTT will be discussed separately below**.

- Static RSA and Diffie-Hellman cipher suites have been removed; all public-key-based key exchange algorithms now provide forward secrecy.

- All handshake messages after ServerHello are now encrypted. The newly introduced EncryptedExtension message allows various extensions that were previously sent in plaintext in ServerHello to also have confidentiality.

- The key derivation function has been redesigned. The new design enables cryptographers to analyze it more easily through improved key separation properties. The HMAC-based Extract-and-Expand Key Derivation Function (HKDF) is used as a fundamental primitive.

- **The handshake state machine has been significantly revised** to make it more consistent and to remove redundant messages such as ChangeCipherSpec (except where required for middlebox compatibility).

- Elliptic-curve algorithms are now part of the core specification, and new signature algorithms such as EdDSA are included. TLS 1.3 removes point format negotiation in favor of using a single point format for each curve.

- Other cryptographic improvements include changing RSA padding to use the RSA Probabilistic Signature Scheme (RSASSA-PSS), and removing compression, DSA, and custom DHE groups.

- The TLS 1.2 version negotiation mechanism has been deprecated. A version list in an extension is now supported. This improves compatibility with servers that implement version negotiation incorrectly.

- Session resumption with and without server-side state, as well as PSK-based cipher suites from earlier versions of TLS, have been replaced by a single new PSK exchange.

- References have been updated as appropriate to point to the latest versions of RFCs (for example, RFC 5280 instead of RFC 3280).

## IV. Improvements Affecting TLS 1.2

The TLS 1.3 specification also defines some optional implementations for TLS 1.2, including implementations that do not support TLS 1.3.

- The downgrade protection mechanism defined in TLS 1.3
- The RSASSA-PSS signature scheme
- The “supported_versions” extension in ClientHello can be used to negotiate the TLS version, and takes precedence over the legacy\_version field in ClientHello.
- The "signature\_algorithms\_cert" extension allows a client to indicate which signature algorithms it uses to verify X.509 certificates.

## V. Overview of the TLS 1.3 Protocol

The cryptographic parameters used by the secure channel are generated by the TLS Handshake Protocol. This TLS subprotocol, the Handshake Protocol, is used when the client and server communicate for the first time. The Handshake Protocol allows the two endpoints to negotiate a protocol version, select cryptographic algorithms, optionally authenticate each other, and establish shared keying material. Once the handshake is complete, both parties use the established keys to protect application-layer data.

A failed handshake or other protocol error triggers termination of the connection, optionally preceded by sending an alert message in accordance with the Alert Protocol.

TLS 1.3 supports three basic key exchange modes:

- (EC)DHE (finite-field- or elliptic-curve-based Diffie-Hellman)
-  PSK - only
-  PSK with (EC)DHE

The following diagram shows the complete TLS handshake flow:
```c
       Client                                           Server

Key  ^ ClientHello
Exch | + key_share*
     | + signature_algorithms*
     | + psk_key_exchange_modes*
     v + pre_shared_key*       -------->
                                                  ServerHello  ^ Key
                                                 + key_share*  | Exch
                                            + pre_shared_key*  v
                                        {EncryptedExtensions}  ^  Server
                                        {CertificateRequest*}  v  Params
                                               {Certificate*}  ^
                                         {CertificateVerify*}  | Auth
                                                   {Finished}  v
                               <--------  [Application Data*]
     ^ {Certificate*}
Auth | {CertificateVerify*}
     v {Finished}              -------->
       [Application Data]      <------->  [Application Data]

```
\+  Indicates notable extensions sent in the messages previously marked  
\*  Indicates optional or condition-dependent messages/extensions; they are not always sent  
() Indicates messages protected with keys derived from Client\_early\_traffic\_secret  
{} Indicates messages protected with keys derived from a [sender]\_handshake\_traffic\_secret  
[] Indicates messages protected with keys derived from [sender]\_application\_traffic\_secret\_N  

The handshake can be viewed as having three phases (see the figure above):

- Key exchange: establishes shared keying material and selects cryptographic parameters. After this phase, all data is encrypted.
- Server parameters: establishes other handshake parameters (whether the Client is authenticated, application-layer protocol support, etc.).
- Authentication: authenticates the Server (and optionally the Client), and provides key confirmation and handshake integrity.

During the key exchange phase, the Client sends a ClientHello message, which contains a random nonce (ClientHello.random); provides the protocol version; a list of symmetric cipher/HKDF hash pairs; a set of Diffie-Hellman key shares or a set of pre-shared key identities (in the "key\_share" extension), or both; and possibly other extensions.

The Server processes the ClientHello and determines the appropriate cryptographic parameters for the connection. It then responds with its own ServerHello, indicating the negotiated connection parameters. The ClientHello and ServerHello together determine the shared keys. If (EC)DHE key establishment is being used, the ServerHello contains a "key\_share" extension, along with the Server’s ephemeral Diffie-Hellman share, which must be in the same group as one of the Client’s shares. If PSK is being used, the ServerHello contains a "pre\_shared\_key" extension indicating which PSK offered by the Client was selected. Note that implementations may use (EC)DHE and PSK together, in which case both extensions must be provided.

The Server then sends two messages to establish the Server parameters:

- EncryptedExtensions: responses to ClientHello extensions that are not needed to determine the cryptographic parameters, other than cryptographic parameters specific to individual certificates.  
- CertificateRequest: if certificate-based client authentication is required, this message contains the required parameters. If client authentication is not required, this message is omitted.

Finally, the Client and Server exchange authentication messages. TLS uses the same set of messages for each certificate-based authentication (PSK-based authentication is a side effect of the key exchange), specifically:

- Certificate: the endpoint’s certificate and extensions for each certificate. The server omits this message if it does not authenticate with a certificate, and the client omits it if the server did not send CertificateRequest (thereby indicating that the client should not authenticate with a certificate). Note that if raw public keys [[RFC7250]](https://tools.ietf.org/html/rfc7250) or the cached information extension [[RFC7924]](https://tools.ietf.org/html/rfc7924) are used, this message will not contain certificates, but instead other values corresponding to the server’s long-term key.

- CertificateVerify: a signature over the entire handshake transcript using the private key paired with the public key in the Certificate message. This message is omitted if the endpoint is not authenticated with a certificate.
- Finished: a MAC (message authentication code) over the entire handshake transcript. This message provides key confirmation and binds the endpoint identity to the exchanged keys, thereby authenticating the handshake even in PSK mode.

After receiving the Server’s messages, the Client responds with its authentication messages: Certificate, CertificateVerify (if required), and Finished.

At this point the handshake is complete, and the client and server derive keys for the record layer to exchange application-layer data, which is protected with authenticated encryption. Application-layer data cannot be sent before the Finished message; it must wait until the record layer has begun using the encryption keys. Note that the server may send application data before receiving the client’s authentication messages; any data sent at that point is, of course, being sent to an unauthenticated peer.

### 1. Incorrect DHE Share

If the client does not provide a sufficient "key\_share" extension (for example, it contains only DHE or ECDHE groups that the server does not accept or support), the server uses a HelloRetryRequest to correct the mismatch, and the client must restart the handshake with an appropriate "key\_share" extension, as shown below. If no common cryptographic parameters can be negotiated, the server must abort the handshake with an appropriate alert.
```c
        Client                                               Server

        ClientHello
        + key_share             -------->
                                                  HelloRetryRequest
                                <--------               + key_share
        ClientHello
        + key_share             -------->
                                                        ServerHello
                                                        + key_share
                                              {EncryptedExtensions}
                                              {CertificateRequest*}
                                                     {Certificate*}
                                               {CertificateVerify*}
                                                         {Finished}
                                <--------       [Application Data*]
        {Certificate*}
        {CertificateVerify*}
        {Finished}              -------->
        [Application Data]      <------->        [Application Data]

```
As shown above, the message flow for a full handshake with mismatched parameters

> Note that this handshake includes the initial ClientHello/HelloRetryRequest exchange; it cannot be reset by the new ClientHello.

TLS also allows several optimized variants of the basic handshake, as described in the following sections.

### 2. Resumption and Pre-Shared Key (PSK)

Although TLS pre-shared keys (PSKs) can be established out of band, they can also be established in a previous connection and then reused (session resumption). Once a handshake completes, the server can send the client a PSK associated with a unique key derived from the initial handshake. The client can then use this PSK to negotiate use of the corresponding PSK in future handshakes. If the server accepts it, the security context of the new connection is cryptographically tied to the original connection, and keys derived from the initial handshake are used to install the cryptographic state instead of performing a full handshake. In TLS 1.2 and earlier, this functionality was provided by "session IDs" and "session tickets" [[RFC5077]](https://tools.ietf.org/html/rfc5077). Both mechanisms are deprecated in TLS 1.3.

A PSK can be used together with an (EC)DHE key exchange algorithm to provide forward secrecy for the shared key, or it can be used on its own, at the cost of losing forward secrecy for application data.

The following figure shows two handshakes: the first establishes a PSK, and the second uses it:
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
When a server authenticates using a PSK, it does not send a Certificate or CertificateVerify message. When a client wants to resume a session using a PSK, it should also provide a "key\_share" to the server, so that if the server rejects session resumption, it can fall back to a full handshake. The server responds with the "pre\_shared\_key" extension to establish the connection using PSK key exchange, and also responds with the "key\_share" extension to perform (EC)DHE key establishment, thereby providing forward secrecy.

When a PSK is provisioned out of band, the PSK key and the KDF hash algorithm used with the PSK must also be provided.

> Note: When using an out-of-band provisioned pre-shared key, a critical consideration is using sufficient entropy during key generation, as discussed in [[RFC4086]](https://tools.ietf.org/html/rfc4086). A shared key derived from a password or another low-entropy source is not secure. A low-entropy password, or passphrase, is vulnerable to dictionary attacks based on the PSK binder. The specified PSK key exchange is not a strong password-authenticated key exchange, even when a Diffie-Hellman key establishment method is used. Specifically, it does not prevent an attacker who can observe the handshake from brute-forcing the password/pre-shared key.

### 3. 0-RTT Data

When the client and server share a PSK (obtained externally or from a previous handshake), TLS 1.3 allows the client to carry data ("early data") in the first message it sends. The client uses this PSK to authenticate the server and encrypt the early data.

As shown in the figure below, 0-RTT data is added to the 1-RTT handshake in the first message sent. The remaining handshake messages are the same as those in a 1-RTT handshake with PSK session resumption.
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
The figure above shows the 0-RTT message flow.

\+  Indicates noteworthy extensions sent in the previously marked messages  
\*  Indicates optional or condition-dependent messages/extensions; they are not always sent  
() Indicates messages protected by keys derived from client\_early\_traffic\_secret  
{} Indicates messages protected by keys derived from a [sender]\_handshake\_traffic\_secret    
[] indicates messages protected by keys derived from [sender]\_application\_traffic\_secret\_N  


0-RTT data has somewhat weaker security than other types of TLS data, in particular:

1. 0-RTT data does not provide forward secrecy; it is encrypted using keys derived from the offered PSK.
2. Across multiple connections, protection against replay attacks cannot be guaranteed. Ordinary TLS 1.3 1-RTT data protects against replay attacks by using the random value sent by the server. Since 0-RTT does not depend on the ServerHello message, its protection is weaker. This security consideration is especially important if the data is authenticated together with TLS client authentication or within the application protocol. This warning applies to any use of early\_exporter\_master\_secret.

0-RTT data cannot be duplicated within a connection (that is, the server will not process the same data twice for the same connection), and an attacker cannot make 0-RTT data appear to be 1-RTT data (because it is protected by different keys).

The security of 0-RTT will be discussed in a separate article.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Introduction/](https://halfrost.com/tls_1-3_introduction/)