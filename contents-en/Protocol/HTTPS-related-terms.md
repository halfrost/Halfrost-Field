# HTTPS-Related Terms


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0.png'>
</p>


## EV
An EV certificate (Extended Validation Certificate) is an X.509 digital certificate issued according to a specific set of standards. Under these requirements, before issuing the certificate, the certificate authority (CA) must verify the applicant’s identity. Extended Validation certificates issued by different organizations according to the certificate standards do not differ significantly, but in some cases, depending on specific requirements, certificates issued by particular organizations can be recognized by specific software.

## OV
An OV certificate (Organization Validation SSL) is a standard SSL certificate that requires verification of the real identity of the organization that owns the website. This type of certificate not only encrypts website information, but also proves the website’s real identity to users.

## DV
A DV certificate (Domain Validation SSL) requires validation of the domain name’s validity. This type of certificate provides only basic encryption assurance and does not provide information about the domain owner.

## HPKP
Public key pinning is a security mechanism used by HTTPS websites to prevent man-in-the-middle attacks in which an attacker uses a certificate incorrectly issued by a CA. It is intended to prevent scenarios such as an attacker compromising a CA and issuing certificates fraudulently, or a browser trusting a CA-signed forged certificate. With this mechanism enabled, the server provides a list of public key hashes, and in subsequent communications the client accepts only one or more public keys from that list. HPKP is a response header.

> Public-Key-Pins:max-age=xxx;pin-sha256=xxxx;includeSubDomains;

Multiple pin-sha256 values can be used. The value of pin-sha256 is the SHA-256 value of the certificate’s public key. includeSubDomains determines whether all subdomains are included. During the time specified by max-age (in seconds), at least one public key in the certificate chain must match a pinned public key; only then will the client consider the certificate chain valid.

There is also another response header:

> Public-Key-Pins-Report-Only:max-age=xxx;pin-sha256=xxxx;includeSubDomains;report-uri=xxx

The report-uri in Public-Key-Pins-Report-Only determines whether events that violate the HTTP Public Key Pinning policy are reported. After HTTP public key pinning validation fails on the client, the client reports the details of the error in JSON format to the server specified by the report-uri parameter.

## CAA
CAA: DNS Certification Authority Authorization uses DNS to specify which CAs are allowed to issue certificates for a domain name. This does not provide security guarantees at the TLS layer, but is part of the CA’s certificate issuance process. CAA can help avoid cases where some CAs issue incorrect certificates.

## SNI
SNI (Server Name Indication) is an extension to the TLS protocol. In this protocol, during the TLS handshake the client can specify the server’s host name. This allows the server to deploy multiple certificates on the same IP and port, and allows multiple HTTPS websites or TLS-based services to be served from the same IP address.

## ALPN
ALPN (Application-Layer Protocol Negotiation) is a Transport Layer Security (TLS) extension for application-layer protocol negotiation. ALPN allows the application layer to negotiate which protocol should be used over a secure connection, avoiding additional round trips that are independent of the application-layer protocol. It has been adopted by HTTP/2.

## NPN
NPN (Next Protocol Negotiation) allows the application layer to negotiate which protocol to use over TLS. In RFC 7301, published on July 11, 2014, ALPN replaced NPN.

## h2
The protocol name for HTTP/2. The colloquial term HTTP2 is analogous to http/1.1 and is negotiated via ALPN.
HTTP/2 can use only TLSv1.2+.

## CSR
A CSR (Certificate Signing Request) must be created before applying for and purchasing an SSL certificate in a PKI system. That is, when a certificate applicant applies for a digital certificate, the CSP (Cryptographic Service Provider) generates the certificate request file at the same time as it generates the private key. The certificate applicant only needs to submit the CSR file to the certificate authority, and the certificate authority signs it with the private key of its root certificate to generate the certificate public key file.

## CT
CT (Certificate Transparency) aims to provide an open auditing and monitoring system that allows any domain owner or CA to determine whether a certificate has been misissued or used maliciously, thereby improving the security of HTTPS websites.

## RSA
The RSA encryption algorithm is an asymmetric encryption algorithm. RSA is widely used in public-key cryptography and electronic commerce. The difficulty of factoring very large integers determines the reliability of the RSA algorithm. It supports both signing and encryption.

## ECC
A common name for ECDSA (Elliptic Curve Digital Signature Algorithm). Unlike RSA, which supports both signing and encryption, it can only perform signing. Its advantages are excellent performance, smaller size, and higher security.

## DH/DHE
Diffie-Hellman (DH) key exchange is a key exchange protocol. The trick behind DH is the use of a mathematical function that is easy to compute in the forward direction but difficult to reverse, even if some factors in the exchange are known. DH key exchange requires six parameters, two of which (dh_p and dh_g) are called domain parameters and are selected by the server. During negotiation, the client and server each generate two additional parameters and send one of them (dh_Ys and dh_Yc) to the peer. After computation, both sides ultimately obtain a shared key.

In ephemeral Diffie-Hellman (DHE) key exchange, no parameters are reused. By contrast, in some DH key exchange methods, certain parameters are static and embedded in the server and client certificates. In that case, the result of the key exchange is always the same shared key, so it cannot provide forward secrecy.

## ECDH/ECHDE
Elliptic curve Diffie-Hellman (ECDH) key exchange is similar in principle to DH, but its core uses a different mathematical foundation. ECHD is based on elliptic curve cryptography. ECDH key exchange occurs on an elliptic curve defined by the server, and this curve replaces the role of the domain parameters in DH. In theory, ECDH supports static key exchange.

Ephemeral elliptic curve Diffie-Hellman key exchange, similar to DHE, uses ephemeral parameters and provides forward secrecy.

## SRI
HTTPS can prevent data from being tampered with in transit, and a valid certificate can also verify the server’s identity. However, if a CDN server is compromised and static files on the server are modified, HTTPS cannot help.

The W3C SRI (Subresource Integrity) specification can be used to solve this problem. SRI enables the browser to verify whether a resource has been tampered with by specifying the resource’s digest signature when referencing it from the page. As long as the page itself is not tampered with, the SRI policy is reliable.

For more information about SRI, see Jerry Qu’s “Introduction to Subresource Integrity”. SRI is not specific to HTTPS, but if the main page is hijacked, an attacker can easily remove the resource digest, thereby disabling the browser’s SRI validation mechanism.

## CSP
CSP, short for Content Security Policy, has many directives that implement a wide variety of page-content security features. Here we introduce only two directives related to HTTPS. For more, see my previous article “Introduction to Content Security Policy Level 2”.

## block-all-mixed-content
As mentioned earlier, for optionally-blockable HTTP resources such as images in HTTPS pages, modern browsers load them by default. If image resources are hijacked, it usually does not cause major problems, but there are still risks. For example, many web page buttons are implemented as images; if a man-in-the-middle modifies those images, it can interfere with user interaction.

With the CSP block-all-mixed-content directive, a page can enter Strict Mixed Content Checking mode. In this mode, all non-HTTPS resources are disallowed. Like all other CSP rules, this directive can be enabled in the following two ways:

HTTP response header method:

> Content-Security-Policy: block-all-mixed-content

Tag method:
upgrade-insecure-requests
For long-established large websites, migrating to HTTPS often involves a huge amount of work. In particular, replacing all resources with HTTPS is a step where omissions are easy to make. Even if all code has been verified as correct, there may still be HTTP links in some fields read from the database.

With the `upgrade-insecure-requests` CSP directive, the browser can help perform this conversion. After this policy is enabled, two things change:

- All HTTP resources on the page are replaced with HTTPS URLs before requests are made;
- All same-site links on the page are replaced with HTTPS URLs before navigation after being clicked;
Like all other CSP rules, this directive can also be enabled in two ways. For the exact format, refer to the previous section. Note that `upgrade-insecure-requests` replaces only the protocol part, so it applies only when the HTTP/HTTPS domain name and path are exactly the same.

## HSTS
After a website has migrated fully to HTTPS, if a user manually enters the website’s HTTP address, or clicks an HTTP link to the site from somewhere else, HTTPS service can be used only by relying on a server-side 301/302 redirect. That first HTTP request may be hijacked, preventing the request from reaching the server and resulting in an HTTPS downgrade attack.

This problem can be solved with HSTS (HTTP Strict Transport Security, RFC6797). HSTS is a response header with the following format:

> Strict-Transport-Security: max-age=expireTime [; includeSubDomains] [; preload]

max-age, in seconds, tells the browser that the website must be accessed via HTTPS for the specified period of time. In other words, for HTTP URLs of this website, the browser must first replace them locally with HTTPS before sending the request.

includeSubDomains is an optional parameter. If specified, it indicates that all subdomains of this website must also be accessed via HTTPS.

preload is an optional parameter; its purpose is introduced later.

The HSTS response header can be used only in HTTPS responses; the website must use the default port 443; and a domain name must be used, not an IP address. Also, after HSTS is enabled, if the website’s certificate has an error, the user cannot choose to ignore it.

## HSTS Preload List
As you can see, HSTS can effectively mitigate HTTPS downgrade attacks, but it still cannot prevent the very first HTTP request before HSTS takes effect from being hijacked. To solve this problem, browser vendors proposed the HSTS Preload List: a built-in list that can be updated periodically. For domains in this list, HTTPS is used even if the user has never visited them before.

This Preload List is currently maintained by Google Chrome, and is used by Chrome, Firefox, Safari, IE 11, and Microsoft Edge. To add your own domain to this list, you first need to meet the following requirements:

- Have a valid certificate (if using a SHA-1 certificate, its expiration date must be earlier than 2016);
- Redirect all HTTP traffic to HTTPS;
- Ensure that HTTPS is enabled for all subdomains;
- Send the HSTS response header:
max-age must be at least 18 weeks (10886400 seconds);
The includeSubdomains parameter must be specified;
The preload parameter must be specified;

Even if all the above requirements are met, entry into the HSTS Preload List is not guaranteed. More information is available here. With Chrome’s chrome://net-internals/#hsts tool, you can query whether a website is in the Preload List, and you can also manually add a domain to the local Preload List.

## PFS
PFS (perfect forward secrecy), also called FS (forward secrecy) in cryptography, is a property of secure communication protocols. It requires that a key can access only the data protected by that key, and that the elements used to generate keys are changed every time and cannot be used to generate other keys. If one key is compromised, the security of other keys is not affected.

## OCSP
OCSP (Online Certificate Status Protocol) is an Internet protocol used to obtain the revocation status of X.509 digital certificates. Defined in RFC 6960, it addresses several issues in public key infrastructure (PKI) caused by the use of certificate revocation lists, serving as an alternative to them. Protocol data is encoded using ASN.1 and is usually transported over HTTP.

## OCSP Stapling
OCSP stapling is a TLS certificate status request extension. It queries the status of X.509 certificates as an alternative method to the Online Certificate Status Protocol. The server sends a previously cached OCSP response during the TLS handshake, and the user only needs to verify the response’s freshness without sending another request to the certificate authority (CA), which can speed up the handshake.

## CRL
A CRL (Certificate Revocation List) is a list of digital certificates that have been revoked. Certificates on the certificate revocation list are no longer trusted, but today OCSP (Online Certificate Status Protocol) can replace CRLs for certificate status checking.

## Session ID
After the SSL handshake is completed, a Session ID is obtained. If the session is interrupted, the next time it reconnects, as long as the client provides this ID and the server has it in its cache, both parties can reuse the existing “session key” instead of generating a new one (the main cost of the handshake). Because the handshake parameters for each connection must be cached, server-side storage overhead can be relatively high.

## Session Ticket
A Session Ticket is obtained in a way similar to a Session ID, but when it is used, the server decrypts it during each handshake to obtain the encryption parameters. The server does not need to maintain handshake parameters, which can reduce memory overhead.

## POODLE
POODLE (Padding Oracle On Downgraded Legacy Encryption, CVE-2014-3566) is fundamentally caused by a design flaw in CBC mode: specifically, CBC authenticates only the plaintext but does not perform integrity checking on the padding bytes. This allows an attacker to modify the padding bytes and exploit padding oracles to recover encrypted content. What makes the POODLE attack possible is the overly loose padding structure and validation rules in SSL 3.

## TLS POODLE
TLS POODLE (CVE-2014-8730) works on the same principle as the POODLE vulnerability, but affects TLS rather than the SSL 3 protocol. The TLS protocol itself is not the problem; the issue lies in implementations. When some developers migrated from SSL 3 to TLS, they did not comply with the protocol’s padding requirements, making their implementations vulnerable to POODLE attacks.

## DROWN
In one sentence: “A cross-protocol attack against TLS using SSLv2”

DROWN (CVE-2016-0800) indicates that merely supporting SSL 2 is a threat to modern servers and clients. It allows an attacker to decrypt TLS connections between modern clients and servers by sending probes to servers that support SSLv2 and use the same private key. If a server is vulnerable to DROWN, there are two possible reasons:

- The server allows SSL2 connections
- The private key is used on another server that allows SSL2 connections, even if it is another SSL/TLS-enabled protocol. For example, if the same private key and certificate are used on both a web server and a mail server, and the mail server supports SSL2, then even if the web server does not support SSL2, an attacker can exploit
the mail server to compromise TLS connections to the web server.
With 40-bit export-restricted RSA cipher suites, a single PC can complete the attack in one minute; the general variant of the attack (which works against any SSL2 service) can also be completed within 8 hours.

## Logjam
Logjam (CVE-2015-4000) affects TLS connections that use the Diffie-Hellman key exchange protocol, especially when the public-key strength in the DH key is less than 1024 bits. A man-in-the-middle attacker can downgrade a vulnerable TLS connection to use 512-bit export-grade encryption. This attack affects all servers that support DHE_EXPORT ciphers. The attack can be performed by precomputing 512-bit primes for two sets of weak Diffie-Hellman parameters, particularly affecting Apache httpd versions 2.1.5 through 2.4.7, as well as all versions of OpenSSL.

## BEAST
BEAST (CVE-2011-3389) targets the CBC mode of symmetric encryption algorithms in TLS 1.0 and earlier. The initialization vector (IV) is predictable, which allows an attacker to effectively weaken CBC mode into ECB mode, and ECB mode is insecure.

## Downgrade
A downgrade attack is an attack against a computer system or communication protocol. In a downgrade attack, the attacker deliberately causes the system to abandon a newer, more secure mode of operation and instead use an older, less secure mode kept for backward compatibility. Downgrade attacks are often used in man-in-the-middle attacks to substantially weaken the security of encrypted communication protocols, enabling attacks that would otherwise be impossible. In modern fallback defenses, a separate signaling cipher suite is used to indicate voluntary downgrade behavior; servers that understand this signal and support higher protocol versions must terminate the negotiation. This suite is TLS_FALLBACK_SCSV (0x5600).

## MITM
MITM (Man-in-the-middle) refers to an attacker establishing separate connections with both endpoints of a communication and relaying all received data, making each endpoint believe it is communicating directly with the other over a private connection, while in fact the entire conversation is fully controlled by the attacker. In a man-in-the-middle attack, the attacker can intercept communications between the two parties and insert new content. A prerequisite for a successful man-in-the-middle attack is that the attacker can impersonate each endpoint participating in the session without being detected by the other endpoints.

## Openssl Padding Oracle
Openssl Padding Oracle (CVE-2016-2107): OpenSSL versions from 1.0.1t up to, but not including, 1.0.2h did not account for memory allocation during certain padding checks. This allows remote attackers to obtain sensitive plaintext information via a padding-oracle attack against AES CBC sessions.

## CCS
CCS (openssl MITM CCS injection attack, CVE-2014-0224): OpenSSL versions before 0.9.8za, before 1.0.0m, and before 1.0.1h did not properly restrict the processing of ChangeCipherSpec messages. This allows a man-in-the-middle attacker to use a zero-length master key in communications.

## FREAK
FREAK (CVE-2015-0204): during a full-strength RSA handshake, the client accepts a weak export-grade RSA key. The key point is that the client did not allow negotiation of any export-grade RSA cipher suites.

## Export-cipher
Before September 1998, the United States restricted the export of strong cryptographic algorithms. Specifically, symmetric encryption strength was limited to a maximum of 40 bits, and key exchange strength was limited to a maximum of 512 bits.

## CRIME
CRIME (Compression Ratio Info-leak Made Easy, CVE-2012-4929) is an attackable security weakness that can be used to steal private web cookies transmitted over HTTPS or SPDY when data compression is enabled. After successfully reading an authentication cookie, an attacker can perform session hijacking and launch further attacks.

## Heartbleed
Heartbleed (CVE-2014-0160) is a vulnerability in OpenSSL. If a vulnerable version of OpenSSL is used, both servers and clients may be exposed to attacks. The issue was caused by insufficient validation of input when implementing the TLS heartbeat extension (missing bounds checks). This programming error is a buffer over-read, meaning it can read more data than should be allowed.

## RC4
RC4 is a stream cipher with symmetric encryption and a variable key length. Because the RC4 algorithm has known weaknesses, RFC 7465, published in February 2015, prohibits the use of RC4 cipher suites in TLS.
Starting with Chrome 48, Chrome refuses to establish TLS connections with cipher suites that use RC4 as the symmetric encryption algorithm.

## 3DES
Many cipher suites use ciphers of the `3DES_EDE_CBC` type. Wikipedia lists the key size provided by 3DES as 192 bits (168+24), but due to the impact of meet-in-the-middle attacks, it only provides 112 bits of security. Therefore, 192 bits is used for rating the key size, while 112 bits is used for the suite’s security strength.

## PSK
PSK stands for “Pre-Shared Key”. It means that the communicating parties share some keys in advance (usually symmetric encryption keys).
This algorithm is not used very often. Its advantages are:

1. It does not depend on a public-key infrastructure and does not require deploying CA certificates.
2. It does not involve asymmetric encryption, so TLS protocol handshake (initialization) performance is better than RSA and DH.
During key exchange, the communicating parties have already pre-deployed several shared keys. To identify multiple keys, each key is assigned a unique ID, and the client communicates with the server using that ID.

## SRP
TLS-SRP (Secure Remote Password) cipher suites fall into two categories: the first category uses only SRP authentication. The second uses SRP authentication together with public-key certificates to improve security.

## TLS GREASE
To preserve extensibility, servers must ignore unknown values.
This is a probing mechanism introduced by Chrome.

1. GREASE for TLS
2. https://tools.ietf.org/html/draft-davidben-tls-grease-01

## AEAD
The full name is Authenticated Encryption with Associated Data (AEAD) algorithms.
AEAD uses a single algorithm to internally implement both cipher + MAC. It is the modern encryption algorithm used in TLS 1.2 and TLS 1.3.

Related cipher suites:
```
TLS_RSA_WITH_AES_128_CCM = {0xC0,0x9C}
TLS_RSA_WITH_AES_256_CCM = {0xC0,0x9D)
TLS_DHE_RSA_WITH_AES_128_CCM = {0xC0,0x9E}
TLS_DHE_RSA_WITH_AES_256_CCM = {0xC0,0x9F}
TLS_RSA_WITH_AES_128_CCM_8 = {0xC0,0xA0}
TLS_RSA_WITH_AES_256_CCM_8 = {0xC0,0xA1)
TLS_DHE_RSA_WITH_AES_128_CCM_8 = {0xC0,0xA2}
TLS_DHE_RSA_WITH_AES_256_CCM_8 = {0xC0,0xA3}
```
https://tools.ietf.org/html/rfc6655

## AES-GCM
AES-GCM is an AEAD and is currently the dominant algorithm used in TLS. Most HTTPS traffic on the Internet relies on AES-GCM.

## ChaCha20-poly1305
ChaCha20-Poly1305 is an AEAD proposed by Professor Daniel J. Bernstein. It is optimized for the mobile Internet, and Google currently uses ChaCha20-Poly1305 for all traffic from mobile clients.

## AES-CBC
Regarding AES-CBC: before AES-GCM became popular, TLS primarily relied on AES-CBC. For historical reasons, TLS fixed on a MAC-then-Encrypt construction in its initial design. The combination of AES-CBC and MAC-then-Encrypt created favorable conditions for chosen-ciphertext attacks (CCA), and several vulnerabilities in TLS history have been related to CBC mode.

## STARTTLS
STARTTLS is an extension to plaintext communication protocols (SMTP/POP3/IMAP). It provides a way to upgrade a plaintext connection to an encrypted connection (TLS or SSL), rather than using a separate port for encrypted communication.
RFC 2595 defines STARTTLS for IMAP and POP3; RFC 3207 defines it for SMTP.


------------------------------------------------------

Reference:
  
*HTTP Explained*    
*HTTP: The Definitive Guide*  
*HTTPS: From Beginner to Advanced*   
[MySSL Terminology](https://blog.myssl.com/myssl-term/)


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()