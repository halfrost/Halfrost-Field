<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/128_0.jpg'>
</p>

# Considerations in HTTP/2


## I. HTTP Issues Worth Considering

This section outlines properties of the HTTP protocol that can improve interoperability, reduce the risk of known security vulnerabilities, or reduce the likelihood of ambiguity for implementers when writing code.

### 1. Connection Management

HTTP/2 connections are persistent. For optimal performance, clients are advised not to proactively close connections. A connection should be closed only when it is certain that no further communication with the server is needed (for example, when the user navigates away from a particular web page), or when the server closes the connection.

A client should not open multiple HTTP/2 connections to a given host and port pair, where the host is derived from a URI, a selected alternative service [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC), or a configured proxy.

A client may create an additional connection as a replacement for a connection whose available stream identifier space is about to be exhausted ([Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)), to refresh the keying material of a TLS connection, or to replace a connection that has encountered an error ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

A client may open multiple connections to a single IP address, and the TCP port may use different server identities [TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) or present different TLS client certificates, but it should avoid creating multiple connections with the same configuration.

Servers are encouraged to keep connections open for as long as possible, but they are allowed to terminate idle connections if necessary. When either endpoint chooses to close the transport-layer TCP connection, the endpoint initiating termination should first send a GOAWAY frame ([Section 6.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)). Doing so enables both endpoints to reliably determine whether previously sent frames have been processed and completed normally, or to terminate any necessary remaining work.


### (1). Connection Reuse


A connection established to an origin server, either directly or through a tunnel created using the CONNECT method ([Section 8.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Semantics.md#%E4%B8%89-the-connect-method)), can be reused for requests with multiple different URI authority components. The connection can be reused as long as the origin server is authoritative ([Section 10.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)). For TCP connections without TLS, this depends on the hosts resolving to the same IP address.

For "https" resources, connection reuse also depends on whether the certificate is valid for the host in the URI. The certificate presented by the server must pass any checks that the client would perform when establishing a new TLS connection to the host in the URI.

An origin server may present a certificate with multiple "subjectAltName" attributes or a wildcard name, one of which is valid for the authority in the URI. For example, a certificate whose "subjectAltName" is "* .example.com" may allow requests for URIs beginning with "https://a.example.com/" and "https://b.example.com/" to use the same connection.


In some deployments, reusing a connection for multiple origins can cause requests to be directed to the wrong origin server. For example, TLS might be terminated by network middleware, because the middleware uses the TLS Server Name Indication (SNI)[TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) extension to select the origin server. This means that the client could send confidential information to a server that might not be the intended target of the request, even if that server is otherwise authoritative.

A server that does not want clients to reuse a connection can indicate that it is not authoritative for a request by sending a 421 (Misdirected Request) status code in response to the request (see [Section 9.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#2-421-%E7%8A%B6%E6%80%81%E7%A0%81)).

A client configured to use an HTTP/2 proxy directs requests to that proxy over a single connection. That is, all requests sent through the proxy reuse the client’s connection to the proxy.


### (2). 421 Status Code

The 421 (Misdirected Request) status code indicates that the request was sent to a server that is unable to produce a response. This status code can be sent by a responding server that is not configured for the combination of scheme and authority in the request URI.

A client that receives a 421 (Misdirected Request) response from a server may retry the request on a different connection, regardless of whether the request method is idempotent. This may be because a connection was reused ([Section 9.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E9%87%8D%E7%94%A8)) or because [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC) was selected. Proxies MUST NOT generate this 421 status code.

By default, a 421 response is cacheable unless otherwise indicated by the method definition or explicit cache controls (see [Section 4.2.2 of [RFC7234]](https://tools.ietf.org/html/rfc7234#section-4.2.2)).


### 2. Use of TLS Features


HTTP/2 implementations MUST use TLS version 1.2 [TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12) or a later version of TLS when implementing HTTP/2. They should follow the TLS usage guidance specified in [TLSBCP](https://tools.ietf.org/html/rfc7540#ref-TLSBCP), as well as additional constraints specific to HTTP/2.

TLS implementations MUST support the Server Name Indication (SNI)[TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) extension for TLS. When negotiating TLS, an HTTP/2 client MUST indicate the target domain name.

When deploying HTTP/2, deployments that negotiate TLS 1.3 or later need only support and use the SNI extension; TLS 1.2 deployments must satisfy the requirements in the following sections. Implementers are encouraged to provide compliant defaults, but it must be recognized that deployments are ultimately responsible for compliance.


### (1). TLS 1.2 Features

This section describes several restrictions on TLS 1.2 when used with HTTP/2. Due to deployment constraints, it may not be possible to make TLS negotiation fail when these restrictions are not met. An endpoint may immediately terminate an HTTP/2 connection that does not satisfy these TLS requirements with a connection error of type INADEQUATE\_SECURITY ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

Deployments of HTTP/2 over TLS 1.2 **MUST** disable compression. TLS compression can lead to information disclosure that would not occur without compression [[RFC3749]](https://tools.ietf.org/html/rfc3749). Generic compression is unnecessary because HTTP/2 provides compression that is more context-aware, and HTTP/2 compression may be more appropriate for performance, security, or other reasons.

Deployments of HTTP/2 over TLS 1.2 **MUST** disable renegotiation. Endpoints MUST treat TLS renegotiation as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Note that because the number of messages that can be encrypted by the underlying cipher suite is limited, disabling renegotiation may make long-lived connections unusable.


An endpoint may use renegotiation to provide confidentiality protection for client certificates presented in the handshake, but any renegotiation must occur before the connection preface is sent. If a server receives a renegotiation request immediately after establishing the connection, it should request a client certificate. This effectively prevents renegotiation from being used in response to a request for a specific protected resource. Future specifications might provide a way to support this scenario. Alternatively, a server may use an error of type HTTP\_1\_1\_REQUIRED ([Section 5.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%83-%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)) to request that the client use a protocol that supports renegotiation.

For cipher suites using ephemeral finite-field Diffie-Hellman (DHE) [[TLS12]](https://tools.ietf.org/html/rfc7540#ref-TLS12), implementations MUST support an ephemeral key exchange size of at least 2048 bits. For cipher suites using ephemeral elliptic-curve Diffie-Hellman (ECDHE) [[RFC4492]](https://tools.ietf.org/html/rfc4492), implementers MUST support cipher suites with at least 224 bits. Clients MUST accept DHE sizes up to 4096 bits. Endpoints may treat negotiation below the minimum lower bound for key size as a connection error of type INADEQUATE\_SECURITY ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### (2). TLS 1.2 Cipher Suites


Deployments of HTTP/2 over TLS 1.2 should not use any cipher suite listed in the cipher suite blacklist ([Appendix A](https://tools.ietf.org/html/rfc7540#appendix-A)).

If a blacklisted cipher suite is negotiated, an endpoint may choose to generate a connection error of type INADEQUATE\_SECURITY ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Deployments that choose to use a blacklisted cipher suite might trigger connection errors unless the set of potential peers is known to accept that cipher suite. Implementations MUST NOT generate this error for negotiation of a cipher suite that is not blacklisted. Therefore, when clients offer cipher suites that are not on the blacklist, they MUST be prepared to use those cipher suites with HTTP/2.

The blacklist includes cipher suites that TLS 1.2 requires to be mandatory-to-implement, which means TLS 1.2 deployments may have disjoint sets of permitted cipher suites. To avoid TLS handshake failures caused by this issue, HTTP/2 deployments using TLS 1.2 MUST support TLS\_ECDHE\_RSA\_WITH\_AES\_128\_GCM\_SHA256 [[TLS-ECDHE]](https://tools.ietf.org/html/rfc7540#ref-TLS-ECDHE) with the P-256 elliptic curve [[FIPS186]](https://tools.ietf.org/html/rfc7540#ref-FIPS186).

Note that a client might advertise support for cipher suites on the blacklist to allow connections to servers that do not support HTTP/2. This lets the server use the HTTP/1.1 protocol and a cipher suite that is blacklisted for HTTP/2. However, if application protocol selection and cipher suite selection are independent, a blacklisted cipher suite might also be used when negotiating HTTP/2.

## II. Security Considerations

### 1. Server Authority

HTTP/2 relies on the HTTP/1.1 definition of authority to determine whether a server is authoritative for providing a given response (see [[RFC7230], Section 9.1](https://tools.ietf.org/html/rfc7230#section-9.1)). This relies on local name resolution for the "http" URI scheme and authenticated server identity for the "https" scheme (see [[RFC2818], Section 3](https://tools.ietf.org/html/rfc2818#section-3)).


### 2. Cross-Protocol Attacks


In a cross-protocol attack, an attacker causes a client to initiate a transaction using protocol A with a server that understands a different protocol B (and does not understand protocol A). The attacker may be able to make the transaction appear valid in the second protocol (protocol B). Combined with capabilities in a Web context, this can be used to interact with poorly protected servers on a private network. Completing the TLS handshake with the HTTP/2 ALPN identifier can be considered sufficient protection against cross-protocol attacks. ALPN explicitly indicates that the server is willing to proceed with HTTP/2, thereby preventing attacks against other TLS-based protocols. Encryption in TLS makes it difficult for an attacker to control data that could be used in plaintext protocols for cross-protocol attacks.

The plaintext version of HTTP/2 provides minimal protection against cross-protocol attacks. The connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#6-http2-connection-preface)) contains a string intended to confuse HTTP/1.1 servers, but it provides no special protection for other protocols. A server that is willing to ignore part of an HTTP/1.1 request containing an Upgrade header field in addition to the client connection preface could be vulnerable to cross-protocol attacks.


### 3. Intermediary Encapsulation Attacks

HTTP/2 header field encoding allows names to be expressed that are not valid field names in the Internet Message Syntax used by HTTP/1.1. Requests or responses containing invalid header field names MUST be treated as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). Therefore, intermediaries cannot translate HTTP/2 requests or responses containing invalid field names into HTTP/1.1 messages.

Similarly, HTTP/2 allows invalid header field values. Although most encodable values do not change how a header field is parsed, an attacker could still exploit carriage return (CR, ASCII 0xd), line feed (LF, ASCII 0xa), and null characters (NUL, ASCII 0x0) if they are translated literally. Any request or response containing characters not allowed in header field values MUST be treated as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). Valid characters are defined by the “field-content” ABNF rule in [Section 3.2 of [RFC7230]](https://tools.ietf.org/html/rfc7230#section-3.2).


### 4. Cacheability of Pushed Responses

A pushed response does not have an explicit request from the client; the request is provided by the server in a PUSH\_PROMISE frame.

Whether a pushed response can be cached can be determined based on the value provided by the origin server in the Cache-Control header field. However, this can cause problems if a server hosts multiple tenants. For example, a server might provide a small portion of its URI space to multiple users. If multiple tenants share space on the same server, that server MUST ensure that tenants cannot push resources for which they are not authoritative. If this is not enforced, a tenant can provide a representation that is used outside the cache, thereby overriding the authority of the actual representation provided by another tenant.

Pushed responses for which the origin server is not authoritative (see [Section 10.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)) MUST NOT be used or cached.


### 5. Denial-of-Service Considerations


Compared with HTTP/1.1 connections, HTTP/2 connections can require more resources to operate. The use of header compression and flow control depends on resource commitments for storing significant amounts of state. The settings for these features ensure that the memory commitment for them is strictly bounded.

The number of PUSH\_PROMISE frames is not limited in the same way. A client that accepts server push should limit the number of streams allowed to be in the “reserved (remote)” state. Excessive server-push streams can be treated as a stream error of type ENHANCE\_YOUR\_CALM ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Processing capacity cannot be protected as effectively as state capacity. SETTINGS frames can be abused, causing a peer to spend additional processing time. For example, changing SETTINGS parameters pointlessly, setting multiple undefined parameters, or changing the same setting multiple times in the same frame. WINDOW\_UPDATE or PRIORITY frames can also be abused, resulting in unnecessary resource consumption.

Large numbers of small frames or empty frames can be abused, causing a peer to spend more time processing frame headers. Note, however, that some uses are entirely legitimate, such as sending an empty DATA or CONTINUATION frame at the end of a stream. Header compression also provides opportunities to waste processing resources; see Section 7 of [[Compression]](https://tools.ietf.org/html/rfc7540#ref-COMPRESSION) for more details on potential abuse.

Limits in SETTINGS parameters cannot be reduced immediately, which exposes an endpoint to peer behavior that may exceed the new limits. In particular, after a connection is established, the client does not know the limits set by the server and can exceed the server’s limits without obviously violating the protocol. All of these features—SETTINGS changes, small frames, and header compression—have legitimate uses. These features become a burden only when used unnecessarily or excessively. An endpoint that does not monitor this behavior exposes itself to the risk of denial-of-service attacks. Implementers should track the use of these features and set limits on their use. An endpoint may treat suspicious activity as a connection error of type ENHANCE\_YOUR\_CALM ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

### (1). Limit Header Block Size

Large header blocks ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)) can cause implementations to commit a large amount of state. Header fields that are critical for routing might appear at the end of the header block, preventing the header fields from being streamed to their final destination. This ordering, and other reasons such as ensuring cache correctness, mean that an endpoint might need to buffer the entire header block. Because there is no hard limit on the size of a header block, some endpoints might be forced to make a large amount of memory available for header fields.

An endpoint can use SETTINGS\_MAX\_HEADER\_LIST\_SIZE to advertise to its peer a limit that might apply to the size of a header block. This setting is only advisory, so an endpoint can choose to send header blocks that exceed this limit, with the risk that the request or response will be treated as malformed. This setting is specific to a connection, so any request or response might encounter a hop with a lower, unknown limit. Intermediaries can try to avoid this problem by passing along the values provided by different peers, but they are not required to do so.

A server that receives a header block larger than it is willing to process can send the HTTP 431 (Request Header Fields Too Large) status code [[RFC6585]](https://tools.ietf.org/html/rfc6585). A client can discard a response that it cannot process. Unless the connection is closed, the header block must be processed to maintain a consistent connection state.


### (2). Connection Issues

The CONNECT method can be used to create disproportionate load on a proxy, because creating a stream is relatively cheap compared with creating and maintaining a TCP connection. Because the outgoing TCP connection remains in the TIME\_WAIT state, the proxy might also retain some resources for the TCP connection after the stream carrying the CONNECT request has been closed. Therefore, a proxy cannot rely solely on SETTINGS\_MAX\_CONCURRENT\_STREAMS to limit the resources consumed by CONNECT requests.


### 6. Use of Compression


Compression can allow an attacker to recover secret data when that data is compressed in the same context as data controlled by the attacker. HTTP/2 can compress header fields ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)); the following considerations also apply to the use of HTTP compression content codings ([[RFC7231], Section 3.1.2.1](https://tools.ietf.org/html/rfc7231#section-3.1.2.1)).

Research has shown that compression attacks exploit characteristics of the network, such as [[BREACH]](https://tools.ietf.org/html/rfc7540#ref-BREACH). An attacker induces multiple requests that contain different plaintexts and observes the length of the resulting ciphertext for each plaintext; when a guess about the ciphertext is correct, a shorter length is exposed.

Implementations communicating over a secure channel MUST NOT compress content that contains both confidential data and attacker-controlled data, unless separate compression dictionaries are used for each data source. If the data source cannot be reliably determined, compression MUST NOT be used. Generic stream compression, such as compression provided by TLS, MUST NOT be used with HTTP/2 (see [Section 9.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#2-%E4%BD%BF%E7%94%A8-tls-%E7%89%B9%E6%80%A7)). Additional considerations for header field compression are described in [[COMPRESSION]](https://tools.ietf.org/html/rfc7540#ref-COMPRESSION).


### 7. Use of Padding

Padding in HTTP/2 is not intended to replace generic padding, such as the padding provided by TLS [[TLS12]](https://tools.ietf.org/html/rfc7540#ref-TLS12). Excessive padding can even be counterproductive. Correct use by applications might require specific knowledge of the data being padded. To mitigate compression-based attacks, disabling or limiting compression can be preferable to padding.

Padding can be used to obscure the exact size of frame contents and to mitigate specific attacks in HTTP, such as attacks where compressed content contains both attacker-controlled plaintext and secret data (for example, [[BREACH]](https://tools.ietf.org/html/rfc7540#ref-BREACH)).

The protection provided by padding can be less than is immediately apparent. At best, padding only makes it more difficult for an attacker to infer length information by increasing the number of frames the attacker must observe. Poorly implemented padding schemes are easy to defeat. In particular, random padding with a predictable distribution provides little protection. Similarly, padding payloads to a fixed size leaks information when the payload size crosses a fixed-size boundary, which can occur when an attacker can control the plaintext.

Intermediaries SHOULD preserve padding on DATA frames, but MAY remove padding from HEADERS and PUSH\_PROMISE frames. A valid reason for an intermediary to change the amount of frame padding is to improve the protection that padding provides.


### 8. Privacy Considerations

Several characteristics of HTTP/2 provide observers with an opportunity to correlate the actions of a single client or server over time. These include the values of settings, the way flow-control windows are managed, how priorities are assigned to streams, the response time to stimuli, and the handling of any features controlled by SETTINGS frames. As long as they produce observable behavioral differences, these characteristics can be used as a basis for fingerprinting a particular client, as defined in Section 1.8 of [[HTML5]](https://tools.ietf.org/html/rfc7540#ref-HTML5).

HTTP/2's preference for using a single TCP connection allows a user's activity on a site to be correlated. Reusing a connection for different origins can allow those origins to be tracked. Because PING and SETTINGS frames request immediate responses, endpoints can use them to measure latency to their peers. In some cases, this can have privacy implications.


## III. IANA Considerations


This document registers strings that identify HTTP/2 in the "Application-Layer Protocol Negotiation (ALPN) Protocol IDs" registry established by [TLS-ALPN]. This document establishes registries for frame types, settings, and error codes. These new registries appear in the new "Hypertext Transfer Protocol version 2 (HTTP/2) Parameters" section. This document registers the HTTP2-Settings header field for use with HTTP; it also registers the 421 (Misdirected Request) status code. This document registers the "PRI" method for HTTP to avoid conflicts with the connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#6-http2-connection-preface)).

### 1. HTTP/2 Identification String Registration

This document registers two strings in the "Application-Layer Protocol Negotiation (ALPN) Protocol IDs" registry established by [[TLS-ALPN]](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN) to identify HTTP/2 (for details, see [Section 3.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#4-starting-http2-for-https-uris)),

The "h2" string identifies HTTP/2 over TLS. Identification sequence: 0x68 0x32 ("h2"). The "h2c" string identifies HTTP/2 over cleartext TCP. Identification sequence: 0x68 0x32 0x63 ("h2c").


### 2. Frame Type Registration

This document establishes a registry for HTTP/2 frame type codes. The "HTTP/2 Frame Type" registry manages an 8-bit space. The "HTTP/2 Frame Type" registry includes values between 0x00 and 0xef and follows the "IETF Review" or "IESG Approval" policies specified in [[RFC5226]](https://tools.ietf.org/html/rfc5226), with values between 0xf0 and 0xff reserved for experimental use.

Registration of new entries in this registry requires the following information:

Frame Type: the name or label of the frame type.  
Code: an 8-bit code identifying the frame type.  
Specification: a reference to the specification, including a description of the frame layout and the semantics and flags used by the frame (the types used by the frame type, including any conditional fields used by the frame).  

The values registered by this document are shown in the following table:

|Frame Type|Code|Section|
|:--------:|:--------:|:----------:|
| DATA |0x0|[Section 6.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7)|  
| HEADERS       | 0x1  | [Section 6.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7)  |  
| PRIORITY      | 0x2  | [Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%89-priority-%E5%B8%A7)  |  
| RST\_STREAM    | 0x3  | [Section 6.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%9B%9B-rst_stream-%E5%B8%A7)  |  
| SETTINGS      | 0x4  | [Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)  |  
| PUSH\_PROMISE  | 0x5  | [Section 6.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)  |  
| PING          | 0x6  | [Section 6.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%83-ping-%E5%B8%A7)  |  
| GOAWAY        | 0x7  | [Section 6.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)  |  
| WINDOW\_UPDATE | 0x8  | [Section 6.9](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7)  |  
| CONTINUATION  | 0x9  | [Section 6.10](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7) |  
 


### 3. Settings Registration


This document establishes a registry for HTTP/2 settings. The "HTTP/2 Settings" registry manages a 16-bit space. The "HTTP/2 Settings" registry includes values from 0x0000 to 0xefff and follows the "Expert Review" policy specified in [[RFC5226]](https://tools.ietf.org/html/rfc5226), with values between 0xf000 and 0xffff reserved for experimental use.


Registration of new entries in this registry requires the following information:

Name: the name of the setting; specifying a setting name is optional.  
Code: the 16-bit code assigned to the setting.  
Initial Value: the initial value of the setting.  
Specification: an optional reference to the specification that describes the use of the setting.  

The values registered by this document are shown in the following table:

       
| Name |Code|Initial Value| Specification |  
|:--------:|:--------:|:----------:|:----------:|  
| HEADER\_TABLE\_SIZE      | 0x1  | 4096          | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| ENABLE\_PUSH            | 0x2  | 1             | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_CONCURRENT\_STREAMS | 0x3  | (infinite)    | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| INITIAL\_WINDOW\_SIZE    | 0x4  | 65535         | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_FRAME\_SIZE         | 0x5  | 16384         | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_HEADER\_LIST\_SIZE   | 0x6  | (infinite)    | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |


### 4. Error Code Registration

This document establishes a registry for HTTP/2 error codes. The "HTTP/2 Error Code" registry manages a 32-bit space. The "HTTP/2 Error Code" registry follows the "Expert Review" policy specified in [[RFC5226]](https://tools.ietf.org/html/rfc5226).


Registration of an error code MUST include a description of the error code. Experts review new error codes to prevent duplication with existing error codes. Use of already-registered error codes is encouraged where possible, but is not mandatory.


Registration of new entries in this registry requires the following information:

Name: the name of the error code; specifying an error code name is optional.  
Code: the 32-bit error code.  
Description: a brief description of the semantics of the error code; if no more detailed specification is available, the description can be longer.  
Specification: an optional reference to the specification that defines the use of the error code.  

The values registered by this document are shown in the following table:


| Name |Code| Description | Specification |  
|:--------:|:--------:|:----------:|:----------:|  
| NO\_ERROR            | 0x0  | Graceful shutdown    | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| PROTOCOL\_ERROR      | 0x1  | Protocol error       | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | detected             |               |
| INTERNAL\_ERROR      | 0x2  | Implementation fault | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| FLOW\_CONTROL\_ERROR  | 0x3  | Flow-control limits  | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | exceeded             |               |
| SETTINGS\_TIMEOUT    | 0x4  | Settings not         | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | acknowledged         |               |
| STREAM\_CLOSED       | 0x5  | Frame received for   | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | closed stream        |               |
| FRAME\_SIZE\_ERROR    | 0x6  | Frame size incorrect | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| REFUSED\_STREAM      | 0x7  | Stream not processed | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| CANCEL              | 0x8  | Stream cancelled     | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| COMPRESSION\_ERROR   | 0x9  | Compression state    | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | not updated          |               |
| CONNECT\_ERROR       | 0xa  | TCP connection error | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | for CONNECT method   |               |
| ENHANCE\_YOUR\_CALM   | 0xb  | Processing capacity  | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | exceeded             |               |
| INADEQUATE\_SECURITY | 0xc  | Negotiated TLS       | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | parameters not       |               |
|                     |      | acceptable           |               |
| HTTP\_1\_1\_REQUIRED   | 0xd  | Use HTTP/1.1 for the | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | request              |               |

### 5. HTTP2-Settings Header Field Registration

This section registers the HTTP2-Settings header field in "Permanent Message Header Field Names" [[BCP90]](https://tools.ietf.org/html/rfc7540#ref-BCP90).

Header field name: HTTP2-Settings  
Applicable protocol: HTTP  
Status: standard  
Author/change controller: IETF  
Specification document: [Section 3.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#3-http2-settings-header-field)  
Related information: This header field is used only by HTTP/2 clients during upgrade negotiation.  


### 6. PRI Method Registration

This section registers the "PRI" method in the "HTTP Method Registry" [[RFC7231], Section 8.1](https://tools.ietf.org/html/rfc7231#section-8.1).

Method name: PRI  
Safe: yes  
Idempotent: yes  
Specification document: [Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#6-http2-connection-preface)  
Related information: This method is never actually used by clients. It appears when an HTTP/1.1 server or an intermediary attempts to parse the HTTP/2 connection preface.  

### 7. 421 HTTP Status Code

This section registers the 421 (Misdirected Request) HTTP status code in "HTTP Status Codes" [[RFC7231], Section 8.2](https://tools.ietf.org/html/rfc7231#section-8.2).

Status code: 421  
Short description: Misdirected Request  
Specification: [Section 9.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-Considerations.md#2-421-%E7%8A%B6%E6%80%81%E7%A0%81)  


### 8. About the h2c Upgrade Token

This section registers the "h2c" upgrade token in "HTTP Upgrade Tokens" [[RFC7230], Section 8.6](https://tools.ietf.org/html/rfc7230#section-8.6).  


Value: h2c  
Description: Hypertext Transfer Protocol version 2 (HTTP/2)   
Expected version tokens: none   
Reference: [Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-begin.md#2-starting-http2-for-http-uris)    


------------------------------------------------------

Reference:  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-considerations/](https://halfrost.com/http2-considerations/)
>