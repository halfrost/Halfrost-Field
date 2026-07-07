+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-10-13T23:58:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/95_0.png"
slug = "tls_1-3_introduction"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 Introduction"

+++


## 1. Purpose of the TLS Protocol

The primary goal of TLS is to provide a secure channel for the two communicating parties. The only requirement placed on the underlying transport is a reliable, ordered data stream.

- Authentication: The Server side of the channel should always be authenticated; Client authentication is optional. Authentication can be performed using asymmetric algorithms (for example, RSA, the Elliptic Curve Digital Signature Algorithm (ECDSA), or the Edwards-curve Digital Signature Algorithm (EdDSA)), or using a symmetric pre-shared key (PSK).

- Confidentiality: Data sent over an established channel is visible only to the endpoints. The TLS protocol cannot hide the length of the data it transports, but endpoints can hide lengths by padding TLS records, thereby improving protection against traffic analysis techniques.

- Integrity: For data sent over an established channel, it should not be possible for the data to be tampered with without being detected. That is, once data is modified, the peer will immediately detect the tampering.

> The three properties above must be guaranteed even if a network attacker has fully taken control of the network, as in the scenarios described in RFC 3552. TLS security issues are discussed separately in a dedicated article below.

## 2. Components of the TLS Protocol

The TLS protocol mainly consists of two major components:

- Handshake Protocol  
  The Handshake Protocol primarily handles all procedures for authentication between the communicating parties. This includes key negotiation, parameter negotiation, and establishing shared keys. The Handshake Protocol is designed to resist tampering; if the connection is not under attack, an active attacker should not be able to force peers to negotiate different parameters.

- Record Protocol  
  The Record Protocol uses the parameters established by the Handshake Protocol to protect traffic between the communicating parties. The Record Protocol divides traffic into a series of records, each independently protected for confidentiality using keys.

TLS is an independent protocol; higher-level protocols can sit transparently on top of TLS. However, the TLS standard does not specify how a protocol should enhance TLS security, how to initiate a TLS handshake, or how to interpret the exchange of authentication certificates. These are left to the designers and implementers of the protocols running on top of TLS.

This document defines TLS version 1.3. Although TLS 1.3 is not directly compatible with previous versions, all versions of TLS include a versioning mechanism that allows clients and servers to negotiate and select the TLS version used during communication.

The TLS 1.3 standard replaces and deprecates earlier versions of TLS, including version 1.2 [RFC5246 The Transport Layer Security (TLS) Protocol Version 1.2](https://tools.ietf.org/html/rfc5246). It also deprecates the TLS ticket mechanism defined in [RFC5077 Transport Layer Security (TLS) Session Resumption without Server-Side State](https://tools.ietf.org/html/rfc5077) and replaces it with the Pre-Shared Key (PSK) mechanism. Because TLS 1.3 changes how keys are exported, it updates [RFC5705 Keying Material Exporters for Transport Layer Security (TLS)](https://tools.ietf.org/html/rfc5705). It also changes how Online Certificate Status Protocol (OCSP) messages are transmitted, and therefore updates [RFC6066 https://tools.ietf.org/html/rfc6066](https://tools.ietf.org/html/rfc6066), and deprecates [RFC6961 he Transport Layer Security (TLS) Multiple Certificate Status Request Extension](https://tools.ietf.org/html/rfc6961), as described in the section “OCSP Status and SCT Extensions”.


## 3. Major Differences Between TLS 1.3 and TLS 1.2

The following describes the major differences between TLS 1.2 and TLS 1.3. In addition to these major differences, there are many subtle differences.

- The list of supported symmetric algorithms has removed algorithms that are no longer secure. The list retains only algorithms that use “Authenticated Encryption with Associated Data” (AEAD). The concept of a cipher suite has changed: it has been separated from the record protection algorithm (including key length) and the hash and HMAC used for the key derivation function, leaving authentication and key exchange mechanisms separate.

- A 0-RTT mode has been added, saving one round trip for some application data during connection establishment, at the cost of certain security properties. **Security issues related to 0-RTT are discussed separately below**.

- Static RSA and Diffie-Hellman cipher suites have been removed; all public-key-based key exchange algorithms now provide forward secrecy.

- All handshake messages after ServerHello are now encrypted. The newly introduced EncryptedExtension message allows various extensions that were previously sent in cleartext in ServerHello to also enjoy confidentiality.

- The key export function has been redesigned. The new design makes it easier for cryptographers to analyze by improving key separation properties. The HMAC-based Extract-and-Expand Key Derivation Function (HKDF) is used as a basic primitive.

- **The handshake state machine has been significantly revised** to be more consistent and to remove redundant messages such as ChangeCipherSpec (except when required for middlebox compatibility).

- Elliptic curve algorithms are now part of the base specification and include new signature algorithms such as EdDSA. TLS 1.3 removes point format negotiation in favor of using a single point format for each curve.

- Other cryptographic improvements include changing RSA padding to use the RSA Probabilistic Signature Scheme (RSASSA-PSS), and removing compression, DSA, and custom DHE groups.

- The TLS 1.2 version negotiation mechanism has been deprecated. A version list in an extension is supported instead. This improves compatibility with Servers that incorrectly implement version negotiation.

- Session resumption with and without Server-side state, as well as PSK-based cipher suites from earlier versions of TLS, have been replaced by a single new PSK exchange.

- References have been updated as appropriate to point to the latest RFC versions (for example, RFC 5280 instead of RFC 3280).

## 4. Improvements Affecting TLS 1.2

The TLS 1.3 specification also defines several optional implementations for TLS 1.2, including implementations that do not support TLS 1.3.

- The downgrade protection mechanism defined in TLS 1.3
- The RSASSA-PSS signature scheme
- The “supported_versions” extension in ClientHello can be used to negotiate the TLS version in use; it takes precedence over the legacy\_version field in ClientHello.
- The "signature\_algorithms\_cert" extension allows a Client to indicate which signature algorithms it uses to verify X.509 certificates.

## 5. Overview of the TLS 1.3 Protocol

The cryptographic parameters used by the secure channel are generated by the TLS Handshake Protocol. This TLS subprotocol, the Handshake Protocol, is used when the Client and Server first communicate. The Handshake Protocol allows both endpoints to negotiate a protocol version, select cryptographic algorithms, optionally authenticate each other, and establish shared keying material. Once the handshake is complete, both parties use the established keys to protect application-layer data.

A failed handshake or other protocol error triggers termination of the connection, optionally preceded by sending an alert message, following the Alert Protocol.

TLS 1.3 supports three basic key exchange modes:

- (EC)DHE (Diffie-Hellman over finite fields or elliptic curves)
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
\+  Indicates noteworthy extensions sent in previously annotated messages  
\*  Indicates optional or condition-dependent messages/extensions; they are not always sent  
() Indicates messages protected with keys derived from Client\_early\_traffic\_secret  
{} Indicates messages protected with keys derived from a [sender]\_handshake\_traffic\_secret  
[] Indicates messages protected with keys derived from [sender]\_application\_traffic\_secret\_N  

The handshake can be viewed as having three phases (see the figure above):

- Key exchange: Establishes shared keying material and selects cryptographic parameters. After this phase, all data is encrypted.
- Server parameters: Establishes other handshake parameters (whether the Client is authenticated, application-layer protocol support, etc.).
- Authentication: Authenticates the Server (and optionally the Client), and provides key confirmation and handshake integrity.

During the key exchange phase, the Client sends a ClientHello message containing a random nonce (ClientHello.random); it provides the protocol version, a list of symmetric cipher/HKDF hash pairs, a set of Diffie-Hellman key shares or a set of pre-shared key identities (in the "key\_share" extension), or both; and possibly other extensions.

The Server processes the ClientHello and determines the appropriate cryptographic parameters for the connection. It then responds with its own ServerHello, indicating the negotiated connection parameters. The ClientHello and ServerHello together determine the shared keys. If an established (EC)DHE key is being used, the ServerHello contains a "key\_share" extension, along with the Server’s ephemeral Diffie-Hellman share, which must be in the same group as one of the Client’s shares. If a PSK key is being used, the ServerHello contains a "pre\_shared\_key" extension indicating which PSK offered by the Client was selected. Note that implementations can use (EC)DHE and PSK together, in which case both extensions need to be provided.

The Server then sends two messages to establish Server parameters:

- EncryptedExtensions: Responses to ClientHello extensions that are not needed to determine the cryptographic parameters, and that are not specific to individual certificates.  
- CertificateRequest: If certificate-based client authentication is required, the required parameters are the certificate. If client authentication is not required, this message is omitted.

Finally, the Client and Server exchange authentication messages. TLS uses the same set of messages for each certificate-based authentication (PSK-based authentication is a side effect of key exchange), specifically:

- Certificate: The endpoint’s certificate and extensions for each certificate. The server omits this message if it does not authenticate with a certificate, and the client omits this message if the server did not send CertificateRequest (thereby indicating that the client should not authenticate with a certificate). Note that if raw public keys [[RFC7250]](https://tools.ietf.org/html/rfc7250) or the cached information extension [[RFC7924]](https://tools.ietf.org/html/rfc7924) are used, this message will not contain certificates, but instead other values corresponding to the server’s long-term key.

- CertificateVerify: A signature over the entire handshake transcript using the private key paired with the public key in the Certificate message. This message is omitted if the endpoint is not authenticated with a certificate.
- Finished: A MAC (Message Authentication Code) over the entire handshake transcript. This message provides key confirmation and binds the endpoint identity to the exchanged keys, so that the handshake can also be authenticated in PSK mode.

After receiving the Server’s messages, the Client responds with its authentication messages: Certificate, CertificateVerify (if needed), and Finished.

At this point the handshake is complete, and the client and server extract keys for the record layer to exchange application data, which must be protected by authenticated encryption. Application data cannot be sent before the Finished message; it must wait until the record layer has started using the encryption keys. Note that the server can send application data before receiving the client’s authentication messages; any data sent at this point is, of course, being sent to an unauthenticated peer.

### 1. Incorrect DHE Share

If the client does not provide a sufficient "key\_share" extension (for example, it contains only DHE or ECDHE groups that the server does not accept or support), the server uses a HelloRetryRequest to correct this mismatch, and the client needs to restart the handshake with an appropriate "key\_share" extension, as shown below. If no common cryptographic parameters can be negotiated, the server must send an appropriate alert to abort the handshake.
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

> Note that this handshake includes the initial ClientHello/HelloRetryRequest exchange; it cannot be reset by a new ClientHello.

TLS also allows several optimized variants of the basic handshake, as described in the following sections.

### 2. Resumption and Pre-Shared Keys (PSK)

Although TLS pre-shared keys (PSKs) can be established out of band, they can also be established in a previous connection and then reused (session resumption). Once a handshake is complete, the server can send the client a PSK key corresponding to a unique key, derived from the initial handshake. The client can then use this PSK key in future handshakes to negotiate use of the associated PSK. If the server accepts it, the security context of the new connection is cryptographically associated with the initial connection, and keys derived from the initial handshake are used to bootstrap the cryptographic state instead of performing a full handshake. In TLS 1.2 and earlier versions, this functionality was provided by "session IDs" and "session tickets" [[RFC5077]](https://tools.ietf.org/html/rfc5077). Both mechanisms have been deprecated in TLS 1.3.

A PSK can be used together with an (EC)DHE key exchange algorithm so that the shared key has forward secrecy, or it can be used on its own, at the cost of losing forward secrecy for application data.

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
When a server authenticates with a PSK, it does not send a Certificate or CertificateVerify message. When a client wants to resume a session using a PSK, it should also provide a "key\_share" to the server, allowing the server to fall back to a full handshake if it rejects session resumption. The server responds with the "pre\_shared\_key" extension, establishing the connection using PSK key exchange, and also responds with the "key\_share" extension to perform (EC)DHE key establishment, thereby providing forward secrecy.

When the PSK is provisioned out of band, the PSK key and the KDF hash algorithm used with the PSK must also be provided.

> Note: When using an out-of-band pre-shared key, a critical consideration is using sufficient entropy during key generation, as discussed in [[RFC4086]](https://tools.ietf.org/html/rfc4086). A shared key derived from a password or another low-entropy source is not secure. A low-entropy password, or passphrase, is vulnerable to dictionary attacks based on the PSK binder. The specified PSK key is not a strong password-based authenticated key exchange, even when a Diffie-Hellman key establishment method is used. Specifically, it does not prevent an attacker who can observe the handshake from brute-forcing the password/pre-shared key.

### 3. 0-RTT Data

When the client and server share a PSK (obtained externally or from a previous handshake), TLS 1.3 allows the client to carry data ("early data") in the first message it sends. The client uses this PSK to authenticate the server and encrypt the early data.

As shown in the following figure, 0-RTT data is added to the 1-RTT handshake in the first message sent. The remaining handshake messages are the same as those in a 1-RTT handshake with PSK session resumption.
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

\+  Indicates noteworthy extensions sent in messages previously labeled  
\*  Indicates optional or condition-dependent messages/extensions; they are not always sent  
() Indicates that the message is protected with keys derived from `client_early_traffic_secret`  
{} Indicates that the message is protected with keys derived from a `[sender]_handshake_traffic_secret`    
[] Indicates that the message is protected with keys derived from a `[sender]_application_traffic_secret_N`  


0-RTT data has somewhat weaker security guarantees than other types of TLS data, in particular:

1. 0-RTT data does not provide forward secrecy; it is encrypted using keys derived from the offered PSK.
2. Replay protection across multiple connections is not guaranteed. For ordinary TLS 1.3 1-RTT data, replay protection relies on the random value sent by the server. Because 0-RTT does not depend on the ServerHello message, its protection is weaker. This security consideration is especially important if the data is authenticated together with TLS client authentication or within the application protocol. This warning applies to any use of `early_exporter_master_secret`.

0-RTT data cannot be duplicated within a connection (that is, the server will not process the same data twice for the same connection), and an attacker cannot make 0-RTT data masquerade as 1-RTT data (because it is protected with different keys).

The security of 0-RTT will be discussed separately in another article.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Introduction/](https://halfrost.com/tls_1-3_introduction/)