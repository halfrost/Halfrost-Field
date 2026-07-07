# TLS 1.3 Implementation Notes


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/114_0.png'>
</p>


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

Although TLS 1.3 uses the same cipher suite space as previous TLS versions, TLS 1.3 cipher suites are defined differently: TLS 1.3 specifies only symmetric cipher suites, and they cannot be used with TLS 1.2. Likewise, cipher suites from TLS 1.2 and earlier cannot be used with TLS 1.3.

New cipher suite values are assigned by IANA.

## II. Random Number Generation and Seeding

TLS requires a cryptographically secure pseudorandom number generator (CSPRNG). In most cases, the operating system provides appropriate facilities, such as /dev/urandom, which should be used unless there are other issues (for example, performance). It is recommended to use an existing CSPRNG implementation rather than developing a new one. Many suitable cryptographic libraries are already available under favorable licensing terms. If that is still not satisfactory, [[RFC4086]](https://tools.ietf.org/html/rfc4086) provides guidance on generating random values.

TLS uses random values in public protocol fields, such as (1) the public random values in ClientHello and ServerHello, and (2) generating keying material. With proper use of a CSPRNG, this does not pose a security problem, because it is infeasible to determine the CSPRNG state from its output. However, if the CSPRNG is compromised, an attacker might use public output to determine the CSPRNG’s internal state and thereby predict keying material, as described in [[CHECKOWAY]](https://tools.ietf.org/html/rfc8446#ref-CHECKOWAY). Implementations can provide additional security against this class of attacks by using separate CSPRNGs to generate public and private values.

## III. Certificates and Authentication

Implementations are responsible for validating certificate integrity and generally should support certificate revocation messages. In the absence of specific guidance from an application profile, certificates should always be validated to ensure that they are properly signed by a trusted certificate authority (CA). Trust anchors should be selected and added with great care. Users should be able to view information about certificates and trust anchors. 

Applications should also enforce minimum and maximum key-size limits. For example, if a certificate path contains keys or signatures weaker than 2048-bit RSA or 224-bit ECDSA, it is not suitable for applications with relatively high security requirements.


## IV. Implementation Pitfalls

Experience has shown that some parts of earlier TLS specifications were not easy to understand and were sources of interoperability and security issues. Many of these aspects have been clarified in this document, but this appendix contains a short list of important items to which implementers should pay particular attention.

TLS protocol issues:

- Do you correctly handle handshake messages split across multiple TLS records (see Section 5.1)? Do you correctly handle edge cases such as a ClientHello split into several small fragments? Do you fragment handshake messages that exceed the maximum fragment size? In particular, the Certificate and CertificateRequest handshake messages may be large enough to require fragmentation.

- Do you ignore the TLS record-layer version number in all unencrypted TLS records (see Appendix D)?

- Have you ensured that, in all possible configurations supporting TLS 1.3 or later, all support for SSL, RC4, EXPORT ciphers, and MD5 (via the "signature\_algorithms" extension) has been completely removed, and that attempts to use these obsolete features fail (see Appendix D)?

- Do you correctly handle TLS extensions in ClientHellos, including unknown extensions?

- When the Server requests a Client certificate but no suitable certificate is available, do you correctly send an empty Certificate message instead of omitting the entire message (see Section 4.4.2)?

- When processing a plaintext fragment produced by AEAD-Decrypt and scanning backward from the end for the ContentType, do you avoid scanning past the beginning of the plaintext if the peer sends a malformed plaintext consisting entirely of zeros?

- Do you correctly ignore unrecognized cipher suites ([Section 4.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello)), hello extensions ([Section 4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions)), named groups ([Section 4.2.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups)), key shares ([Section 4.2.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)), supported versions ([Section 4.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions)), and signature algorithms ([Section 4.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms)) in ClientHello?

- As a Server, do you send a HelloRetryRequest to a Client that supports compatible (EC)DHE groups but could not predict the group in the "key\_share" extension? As a Client, do you correctly handle a HelloRetryRequest sent by the Server?

Cryptographic details:

- What countermeasures do you use to prevent timing attacks [[TIMING]](https://tools.ietf.org/html/rfc8446#ref-TIMING)?

- When using Diffie-Hellman key exchange, do you correctly preserve leading zero bytes in the negotiated key (see Section 7.4.1)?

- Does your TLS Client check whether the Diffie-Hellman parameters sent by the Server are acceptable (see Section 4.2.8.1)?

- When generating Diffie-Hellman private values, the ECDSA "k" parameter, and other security-critical values, do you use a strong and, most importantly, correctly seeded random number generator (see [Appendix C.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Implementation_Notes.md#%E4%BA%8C-random-number-generation-and-seeding))? Implementations are advised to implement "deterministic ECDSA" as specified in [[RFC6979]](https://tools.ietf.org/html/rfc6979).

- Do you pad Diffie-Hellman public key values and shared keys with zeros to the size of the group (see [Section 4.2.8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#1-diffie-hellman-parameters) and [Section 7.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Cryptographic_Computations.md#1-finite-field-diffie-hellman))?

- Do you verify signatures after generating them to prevent RSA-CRT key leakage [FW15](https://tools.ietf.org/html/rfc8446#ref-FW15)?


## V. Client Tracking Prevention

Clients should not reuse a ticket across multiple connections. Reusing a ticket allows a passive observer to correlate different connections. A Server that issues tickets should provide at least as many tickets as the number of connections the Client might use; for example, a web browser using HTTP/1.1 [RFC7230](https://tools.ietf.org/html/rfc7230) might establish six connections to the Server. The Server should issue a new ticket for each connection. This ensures that the Client can always use a new ticket when creating a new connection.


## VI. Unauthenticated Operation

Previous versions of TLS provided explicitly unauthenticated cipher suites based on anonymous Diffie-Hellman algorithms. These modes have been deprecated in TLS 1.3. However, it is still possible to negotiate parameters that do not provide verifiable Server authentication in several ways, including:

- Raw public keys [[RFC7250]](https://tools.ietf.org/html/rfc7250).

- Using the public key contained in a certificate, but without validating the certificate chain or any of its contents.

Used by themselves, both of these techniques are susceptible to man-in-the-middle attacks, and therefore the practices above are insecure. However, these connections can also be bound to an external authentication mechanism by mechanisms such as out-of-band validation of the Server public key, trust on first use, or channel binding (although channel binding is described in [RFC5929](https://tools.ietf.org/html/rfc5929), it is not defined for TLS 1.3). If no such mechanism is used, the connection cannot protect against active man-in-the-middle attacks; applications must not use TLS in this way without explicit configuration or a specific application profile.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Implementation\_Notes/](https://halfrost.com/tls_1-3_implementation_notes/)