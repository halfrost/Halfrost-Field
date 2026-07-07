+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-12-02T00:58:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/114_0.png"
slug = "tls_1-3_implementation_notes"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 Implementation Notes"

+++


## 1. Cipher Suites

A symmetric cipher suite defines a pair consisting of an AEAD algorithm and a hash algorithm used with HKDF. Cipher suite names follow the    naming convention:
```c
      CipherSuite TLS_AEAD_HASH = VALUE;

      +-----------+------------------------------------------------+
      | Component | Contents                                       |
      +-----------+------------------------------------------------+
      | TLS       | The string "TLS"                               |
      |           |                                                |
      | AEAD      | The AEAD algorithm used for record protection  |
      |           |                                                |
      | HASH      | The hash algorithm used with HKDF              |
      |           |                                                |
      | VALUE     | The two-byte ID assigned for this cipher suite |
      +-----------+------------------------------------------------+
```
This specification defines the following cipher suites for TLS 1.3:
```c
              +------------------------------+-------------+
              | Description                  | Value       |
              +------------------------------+-------------+
              | TLS_AES_128_GCM_SHA256       | {0x13,0x01} |
              |                              |             |
              | TLS_AES_256_GCM_SHA384       | {0x13,0x02} |
              |                              |             |
              | TLS_CHACHA20_POLY1305_SHA256 | {0x13,0x03} |
              |                              |             |
              | TLS_AES_128_CCM_SHA256       | {0x13,0x04} |
              |                              |             |
              | TLS_AES_128_CCM_8_SHA256     | {0x13,0x05} |
              +------------------------------+-------------+

```
The corresponding AEAD algorithms AEAD\_AES\_128\_GCM, AEAD\_AES\_256\_GCM, and AEAD\_AES\_128\_CCM are defined in [[RFC5116]](https://tools.ietf.org/html/rfc5116). AEAD\_CHACHA20\_POLY1305 is defined in [[RFC8439]](https://tools.ietf.org/html/rfc8439). AEAD\_AES\_128\_CCM\_8 is defined in [[RFC6655]](https://tools.ietf.org/html/rfc6655). The corresponding hash algorithms are defined in [[SHS]](https://tools.ietf.org/html/rfc8446#ref-SHS).

Although TLS 1.3 uses the same cipher suite space as previous versions of TLS, TLS 1.3 cipher suites are defined differently: TLS 1.3 specifies only symmetric cipher suites, and they cannot be used with TLS 1.2. Likewise, cipher suites for TLS 1.2 and earlier cannot be used with TLS 1.3.

New cipher suite values are assigned by IANA.

## II. Random Number Generation and Seeding

TLS requires a cryptographically secure pseudorandom number generator (CSPRNG). In most cases, the operating system provides suitable facilities, such as /dev/urandom, and these should be used unless there are other issues, such as performance. It is recommended to use an existing CSPRNG implementation rather than develop a new one. Many suitable cryptographic libraries are already available under favorable license terms. If these are still not satisfactory, [[RFC4086]](https://tools.ietf.org/html/rfc4086) provides guidance on generating random values.

TLS uses random values in public protocol fields: (1) public random values such as those in ClientHello and ServerHello, and (2) for generating keying material. When a CSPRNG is used correctly, this does not create a security problem, because it is infeasible to determine the state of the CSPRNG from its output. However, if the CSPRNG is broken, an attacker may be able to use public output to determine the internal state of the CSPRNG and thereby predict keying material, as described in [[CHECKOWAY]](https://tools.ietf.org/html/rfc8446#ref-CHECKOWAY). Implementations can provide additional security against this class of attack by using separate CSPRNGs to generate public and private values.

## III. Certificates and Authentication

Implementations are responsible for validating certificate integrity and generally ought to support certificate revocation messages. In the absence of specific guidance from an application profile, certificates should always be validated to ensure that they are correctly signed by a trusted Certificate Authority (CA). Trust anchors should be selected and added with great care. Users should be able to view information about certificates and trust anchors. 

Applications should also enforce minimum and maximum key-size limits. For example, if a certificate path contains keys or signatures weaker than 2048-bit RSA or 224-bit ECDSA, it is not suitable for applications with relatively high security requirements.


## IV. Implementation Pitfalls

Experience has shown that certain parts of earlier TLS specifications were not easy to understand and have been a source of interoperability and security problems. Many of these aspects have been clarified in this document, but this appendix contains a short list of important items that require particular attention from implementers.

TLS protocol issues:

- Do you correctly handle handshake messages that are spread across multiple TLS records (see Section 5.1)? Do you correctly handle edge cases such as a ClientHello split into several small fragments? Do you fragment handshake messages that exceed the maximum fragment size? In particular, Certificate and CertificateRequest handshake messages may be large enough to require fragmentation.

- Do you ignore the TLS record layer version number in all unencrypted TLS records (see Appendix D)?

- Have you ensured that, in all possible configurations supporting TLS 1.3 or later, all support for SSL, RC4, EXPORT ciphers, and MD5 (via the "signature\_algorithms" extension) has been completely removed, and that attempts to use these obsolete features fail (see Appendix D)?

- Do you correctly handle TLS extensions in ClientHellos, including unknown extensions?

- When the Server requests a Client certificate but no suitable certificate is available, do you correctly send an empty certificate message rather than omitting the message entirely (see Section 4.4.2)?

- When processing a plaintext fragment produced by AEAD-Decrypt and scanning from the end for the ContentType, do you avoid scanning past the beginning of the plaintext if the peer sends malformed plaintext consisting entirely of zeros?

- Do you correctly ignore unrecognized cipher suites ([Section 4.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello)), hello extensions ([Section 4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions)), named groups ([Section 4.2.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups)), key shares ([Section 4.2.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)), supported versions ([Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions)), and signature algorithms ([Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms)) in ClientHello?

- As a Server, do you send HelloRetryRequest to a Client that supports a compatible (EC)DHE group but did not predict it in the "key\_share" extension? As a Client, do you correctly handle HelloRetryRequest sent by the Server?

Cryptographic details:

- What countermeasures do you use to prevent timing attacks [[TIMING]](https://tools.ietf.org/html/rfc8446#ref-TIMING)?

- When using Diffie-Hellman key exchange, do you correctly preserve leading zero bytes in the negotiated key (see Section 7.4.1)?

- Does your TLS Client check whether the Diffie-Hellman parameters sent by the Server are acceptable (see Section 4.2.8.1)?

- When generating Diffie-Hellman private values, ECDSA "k" parameters, and other security-critical values, do you use a strong and, most importantly, correctly seeded random number generator (see [Appendix C.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E4%BA%8C-random-number-generation-and-seeding))? Implementers are advised to implement the "deterministic ECDSA" specified in [[RFC6979]](https://tools.ietf.org/html/rfc6979).

- Do you pad Diffie-Hellman public key values and shared secrets with zeros to the size of the group (see [Section 4.2.8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-diffie-hellman-parameters) and [Section 7.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#1-finite-field-diffie-hellman))?

- Do you verify signatures after creating them to prevent RSA-CRT key leakage [FW15](https://tools.ietf.org/html/rfc8446#ref-FW15)?


## V. Client Tracking Prevention

Clients should not reuse a ticket for multiple connections. Reusing a ticket allows a passive observer to correlate different connections. A Server that issues tickets should provide at least as many tickets as the number of connections the Client might use; for example, a web browser using HTTP/1.1 [RFC7230](https://tools.ietf.org/html/rfc7230) might open six connections to the Server. The Server should issue a new ticket for each connection. This ensures that the Client can always use a fresh ticket when creating a new connection.


## VI. Unauthenticated Operation

Earlier versions of TLS provided explicitly unauthenticated cipher suites based on anonymous Diffie-Hellman algorithms. These modes have been deprecated in TLS 1.3. However, it is still possible to negotiate parameters that do not provide verifiable Server authentication in several ways, including:

- Raw public keys [RFC7250](https://tools.ietf.org/html/rfc7250).

- Using the public key contained in a certificate, but not validating the certificate chain or any of its contents.

Either of these techniques used alone is vulnerable to man-in-the-middle attacks, so the practices above are insecure. However, these connections can also be bound to an external authentication mechanism through mechanisms such as out-of-band validation of the Server public key, trust on first use, or channel binding (although channel binding is described in [RFC5929](https://tools.ietf.org/html/rfc5929), it is not defined for TLS 1.3). If no such mechanism is used, the connection cannot protect against active man-in-the-middle attacks; applications are prohibited from using TLS in this manner without explicit configuration or a specific application profile.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Implementation\_Notes/](https://halfrost.com/tls_1-3_implementation_notes/)


