+++
author = "一缕殇流化隐半边冰霜"
categories = ["HTTP", "HTTP/2", "Protocol"]
date = 2019-04-14T06:54:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/124_0.png"
slug = "http2_begin"
tags = ["HTTP", "HTTP/2", "Protocol"]
title = "Unveiling HTTP/2: How HTTP/2 Establishes Connections"

+++


Hypertext Transfer Protocol (HTTP) is a highly successful protocol. However, the way HTTP/1.1 uses the underlying transport ([[RFC7230], Section 6](https://tools.ietf.org/html/rfc7230#section-6)) has several characteristics that negatively impact the performance of today’s applications.

In particular, HTTP/1.0 allows only one outstanding request at a time on a given TCP connection. HTTP/1.1 added request pipelining, but this only partially addresses request concurrency and is still affected by **head-of-line blocking**. As a result, HTTP/1.0 and HTTP/1.1 clients that need to issue many requests use multiple connections to the server to achieve concurrency and reduce latency.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/124_4.jpg'>
</p>


In addition, HTTP header fields are often repetitive and verbose, causing unnecessary network traffic and causing the initial [TCP](https://tools.ietf.org/html/rfc7540#ref-TCP) congestion window to fill quickly. When multiple requests are issued on a new TCP connection, this can introduce excessive latency.

HTTP/2 addresses these issues by defining an optimized mapping of HTTP semantics onto the underlying connection. Specifically, it allows request and response messages to be interleaved on the same connection and uses efficient encoding for HTTP header fields. It also allows requests to be prioritized, enabling more important requests to complete sooner and further improving performance.

HTTP/2 is more network-friendly because it can use fewer TCP connections than HTTP/1.x. This means less competition with other traffic and long-lived connections, which in turn enables better utilization of available network capacity. Finally, HTTP/2 can also process messages more efficiently by using binary message framing.

>HTTP/2 is maximally compatible with the existing behavior of HTTP/1.1:  
>1. It changes the application layer, building on and fully exploiting TCP protocol performance.
>2. The model in which the client sends request requests to the server remains unchanged.
>3. The scheme has not changed; there is no http2://
>4. Clients and servers using HTTP/1.X can be seamlessly bridged to HTTP/2 through proxies.
>5. Proxy servers that do not recognize HTTP/2 can downgrade requests to HTTP/1.X.


## I. HTTP/2 Protocol Overview


![](https://img.halfrost.com/Blog/ArticleImage/129_5.png)


HTTP/2 provides an optimized transport for HTTP semantics. HTTP/2 supports all core features of HTTP/1.1, but is designed to improve efficiency in multiple ways.

The basic protocol unit in HTTP/2 is a frame ([Section 4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F)). Each frame type serves a different purpose. For example, HEADERS and DATA frames form the basis of HTTP requests and responses ([Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange)); other frame types, such as SETTINGS, WINDOW\_UPDATE, and PUSH\_PROMISE, are used to support other HTTP/2 features.

> HTTP/2 is a fully binary protocol: both header information and payload bodies are binary, collectively referred to as “frames”. Compared with HTTP/1.1, in HTTP/1.1 header information is text-encoded (ASCII encoding), while payload bodies can be either binary or text. The benefit of using binary as the protocol implementation format is greater flexibility. HTTP/2 defines 10 different types of frames.
>


Request multiplexing is achieved by associating each HTTP request/response exchange with its own stream ([Section 5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)). Streams are largely independent of one another, so a blocked or stalled request or response does not prevent communication on other streams.

>Because HTTP/2 packets are sent out of order, responses for different requests may be received on the same connection. Different packets carry different markers to identify which response they belong to.
>
>HTTP/2 refers to the packets for each request and response as a data stream (stream). Each data stream has its own globally unique identifier. During transmission, each packet must be marked with the stream ID it belongs to. By convention, streams initiated by the client always have odd-numbered IDs, while streams initiated by the server have even-numbered IDs.
>
>At any point while a stream is being sent, either the client or the server can send a signal (an RST\_STREAM frame) to cancel that stream. In HTTP/1.1, the only way to cancel a stream is to close the TCP connection. HTTP/2 can cancel a single request while keeping the TCP connection open so it can be used by other requests.
>

Flow control and prioritization ensure that multiplexed streams can be used effectively. Flow control ([Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)) helps ensure that only data the receiver can use is transmitted. Prioritization ([Section 5.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7)) ensures that limited resources are directed first to the most important streams.

HTTP/2 adds a new interaction mode in which the server can push responses to the client ([Section 8.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%BA%8C-server-push)). Server push allows the server to speculatively send data to a client that the server predicts will need it, trading some additional network traffic for potentially lower latency. The server does this by synthesizing a request and sending it as a PUSH\_PROMISE frame. The server can then send the response to the synthesized request on a separate stream.

Because the HTTP header fields used in a connection may contain a large amount of redundant data, the frames containing them are compressed ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)). The ability to compress many requests into a single packet has a particularly favorable effect on typical request sizes.


>HTTP is stateless, so every request must include all information. Therefore, many fields in requests are repetitive, such as Cookie and User Agent; even when the content is exactly the same, it still has to be carried every time, which wastes bandwidth and affects speed. Although HTTP/1.1 can compress request bodies, it cannot compress message headers. Sometimes message headers are large.
>
>HTTP/2 optimizes this by introducing a header compression mechanism. On the one hand, header information is compressed with gzip or compress before being sent; on the other hand, the client and server both maintain a header table, where all fields are stored and assigned an index number. Later, the same fields are no longer sent; only the index numbers are sent, improving performance. 
> 
>Header compression can likely deliver an improvement of around 95%. The average response header size measured for HTTP/1.1 is around 500 bytes, while the average response header size for HTTP/2 is only a little over 20 bytes, which is a significant improvement.


![](https://img.halfrost.com/Blog/ArticleImage/129_1.png)


Next, HTTP/2 is discussed in detail in 4 parts.

- Lifting the veil on HTTP/2: how HTTP/2 establishes a connection ([Chapter 3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#1-http2-version-identification))
- The frame ([Chapter 4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F)) and stream ([Chapter 5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)) layers describe the structure of HTTP/2 frames and how multiplexed streams are formed.
- Frames ([Chapter 6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7)) and errors ([Chapter 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)) define the details of the frame and error types used in HTTP/2.
- HTTP mapping ([Chapter 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange)) and additional requirements ([Chapter 9](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E7%AE%A1%E7%90%86)) describe how frames and streams are used to represent HTTP semantics.

Although some frame-layer and stream-layer concepts are isolated from HTTP, this specification does not define a fully generic frame layer. The frame layer and stream layer are tailored to the needs of the HTTP protocol and server push.

## II. Starting HTTP/2
HTTP/2 connections are an application-layer protocol that runs on top of a TCP connection ([TCP](https://tools.ietf.org/html/rfc7540#ref-TCP)). The client is the initiator of the TCP connection.

HTTP/2 uses the same "http" and "https" URI schemes used by HTTP/1.1. HTTP/2 shares the same default port numbers: 80 for "http" URIs and 443 for "https" URIs. Therefore, implementations that need to process requests for a target resource URI (for example, "[http://example.org/foo](http://example.org/foo)" or "[https://example.com/bar](https://example.com/bar)") first need to discover whether the upstream server (the immediate peer with which the client wants to establish a connection) supports HTTP/2.

The method for determining HTTP/2 support differs for "http" and "https" URIs. Discovery for "http" URIs is described in [Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#2-starting-http2-for-http-uris). [Section 3.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#4-starting-http2-for-https-uris) describes discovery for "https" URIs.


### 1. HTTP/2 Version Identification

The protocol defined in this document has two identifiers.

- The string "h2" identifies HTTP/2 when used with Transport Layer Security (TLS) [TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12). This identifier is used in the TLS Application-Layer Protocol Negotiation (ALPN) extension [TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN) field and anywhere HTTP/2 over TLS needs to be identified.

The "h2" string is serialized into an ALPN protocol identifier as the two-octet sequence: 0x68,0x32.

- The string "h2c" identifies HTTP/2 running over cleartext TCP. This identifier is used in the HTTP/1.1 Upgrade header field and anywhere HTTP/2 over TCP needs to be identified.

The "h2c" string is reserved from the ALPN identifier space, but it describes a protocol that does not use TLS. Negotiating "h2" or "h2c" implies the use of the transport, security, framing, and message semantics described in this document.

### 2. Starting HTTP/2 for "http" URIs

A client making a request for an "http" URI without prior knowledge that the next hop supports HTTP/2 uses the HTTP Upgrade mechanism ([Section 6.7 of [RFC7230]](https://tools.ietf.org/html/rfc7230#section-6.7)). The client does this by sending an HTTP/1.1 request that includes an Upgrade header field with the "h2c" token. Such an HTTP/1.1 request MUST include an HTTP2-Settings ([Section 3.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#3-http2-settings-header-field)) header field.

For example:
```c
     GET / HTTP/1.1
     Host: server.example.com
     Connection: Upgrade, HTTP2-Settings
     Upgrade: h2c
     HTTP2-Settings: <base64url encoding of HTTP/2 SETTINGS payload>
```
Before the client can send HTTP/2 frames, a request containing a payload body must be sent in its entirety. This means that a large request can block use of the connection until it has been fully sent.

If concurrency between the initial request and subsequent requests is important, an OPTIONS request can be used to perform the upgrade to HTTP/2, but this requires an additional round trip. A server that does not support HTTP/2 can respond to the request as if the Upgrade header field were not present:
```c
     HTTP/1.1 200 OK
     Content-Length: 243
     Content-Type: text/html

     ...
```
The server MUST ignore the "h2" token in the Upgrade header field. The presence of a token with "h2" implies HTTP/2 over TLS, which supersedes the negotiation process described in [Section 3.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#4-starting-http2-for-https-uris).


A server that supports HTTP/2 accepts the upgrade by responding with 101 (Switching Protocols). After the empty line at the end of the 101 response, the server can begin sending HTTP/2 frames. These frames MUST include a response to the request that initiated the upgrade.

For example:
```c
     HTTP/1.1 101 Switching Protocols
     Connection: Upgrade
     Upgrade: h2c

     [ HTTP/2 connection ...
```
The first HTTP/2 frame sent by the server MUST be the server connection preface ([Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)), consisting of a SETTINGS frame ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#6-http2-connection-preface)). After receiving the 101 response, the client MUST send the connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#6-http2-connection-preface)), which includes a SETTINGS frame.

The HTTP/1.1 request sent before the upgrade is assigned stream identifier 1 (see [Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)), with the default priority values ([Section 5.3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)). Stream 1 is implicitly "half-closed" from the client toward the server (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)), because the request was completed as an HTTP/1.1 request. After the HTTP/2 connection begins, stream 1 is used for the response.

### 3. HTTP2-Settings Header Field

A request that upgrades from HTTP/1.1 to HTTP/2 MUST include an "HTTP2-Settings" header field. The HTTP2-Settings header field is a connection-specific header field that contains parameters governing the HTTP/2 connection; these parameters are provided in case the server accepts the upgrade request.
```c
     HTTP2-Settings    = token68
```
If this header field is absent or if more than one connection exists, the server MUST NOT upgrade the connection to HTTP/2. The server MUST NOT send this header field.

The content of the HTTP2-Settings header field is the payload of a SETTINGS frame ([Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)), encoded as a base64url string (that is, the URL- and filename-safe Base64 encoding described in [Section 5 of [RFC4648]](https://tools.ietf.org/html/rfc4648#section-5), with any trailing '=' characters omitted). The ABNF [RFC5234](https://tools.ietf.org/html/rfc5234) production "token68" is defined in [Section 2.1 of [RFC7235]](https://tools.ietf.org/html/rfc7235#section-2.1).

Because the upgrade applies only to the immediate connection, a client that sends the HTTP2-Settings header field MUST also send "HTTP2-Settings" as a connection option in the Connection header field to prevent it from being forwarded (see [Section 6.1 of [RFC7230]](https://tools.ietf.org/html/rfc7230#section-6.1)).

The server decodes and interprets these values as it would any other SETTINGS frame. These settings do not need to be explicitly acknowledged ([Section 6.5.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#3-settings-synchronization)), because the 101 response serves as an implicit acknowledgment. These values are provided in the upgrade request to give the client an opportunity to provide parameters before receiving any frames from the server.


### 4. Starting HTTP/2 for "https" URIs

A client making a request to an "https" URI uses TLS [TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12) with the Application-Layer Protocol Negotiation (ALPN) extension [TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN).

HTTP/2 over TLS uses the "h2" protocol identifier. The "h2c" protocol identifier MUST NOT be sent by a client or selected by a server; the "h2c" protocol identifier describes a protocol that does not use TLS.

Once TLS negotiation is complete, both the client and the server MUST send the connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#6-http2-connection-preface)).


### 5. Starting HTTP/2 with Prior Knowledge

A client can learn by other means whether a particular server supports HTTP/2. For example, [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC) describes a mechanism by which support for HTTP/2 can be discovered.

The client MUST send the connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#6-http2-connection-preface)), after which it can immediately send HTTP/2 frames to the server; the server can identify these connections by the presence of the connection preface. This affects only HTTP/2 connections established over cleartext TCP; implementations that support HTTP/2 over TLS MUST use protocol negotiation in TLS [TLS-ALPN](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN). Likewise, the server MUST send the connection preface ([Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#6-http2-connection-preface)).

In the absence of other information, prior support for HTTP/2 is not a strong signal that a given server will support HTTP/2 for future connections. For example, server configuration can change, configuration can differ between instances in a server cluster, or network conditions can change.


### 6. HTTP/2 Connection Preface

> In some contexts, "connection preface" is also translated as "connection prologue."

In HTTP/2, each endpoint is required to send a connection preface as the final confirmation of the protocol in use and to establish the initial settings for the HTTP/2 connection. The client and the server each send a different connection preface.

The client connection preface begins with a sequence of 24 octets, represented in hexadecimal notation as:
```c
     0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
```
That is, the connection preface begins with the string "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n". This sequence must be followed by a SETTINGS frame ([Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)), which may be empty. The client sends the client connection preface immediately after receiving the 101 (Switching Protocols) response (indicating a successful upgrade), or as the first application-data octets of a TLS connection. If an HTTP/2 connection is initiated with prior knowledge of server support for the protocol, the client connection preface is sent when the connection is established.

>Note: The client connection preface was chosen so that most HTTP/1.1 or HTTP/1.0 servers and intermediaries will not attempt to process further frames. Note that this does not address the issue raised in [TALKING](https://tools.ietf.org/html/rfc7540#ref-TALKING).

>The string in the connection preface concatenates to PRISM. The word means “prism”, referring to the “PRISM program” exposed by Snowden in 2013.

The server connection preface consists of a SETTINGS frame ([Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)), which may be empty, and which must be the first frame the server sends in an HTTP/2 connection.

A SETTINGS frame received from a peer as part of the connection preface must be acknowledged after the connection preface is sent (see [Section 6.5.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#3-settings-synchronization)).

To avoid unnecessary latency, the client is allowed to send additional frames to the server immediately after sending the client connection preface, without waiting to receive the server connection preface. However, note that the server connection preface SETTINGS frame may contain parameters that the client must use when communicating with the server. After receiving the SETTINGS frame, the client should comply with any established parameters. In some configurations, the server can send SETTINGS before the client sends additional frames, providing an opportunity to avoid this issue.

Clients and servers must treat an invalid connection preface as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). In this case, the GOAWAY frame ([Section 6.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)) may be omitted, because an invalid connection preface indicates that the peer is not using HTTP/2.

Finally, let’s capture packets to see how HTTP/2 over TLS establishes a connection. After the TLS handshake completes (the TLS handshake flow is omitted here for now; readers who want to learn more can refer to this [series of articles](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md)), the client and server have negotiated via ALPN that the application layer will use HTTP/2 for subsequent communication. You will then see a packet capture similar to the following:

![](https://img.halfrost.com/Blog/ArticleImage/124_1.png)

As you can see, immediately after the TLS 1.3 Finished message comes the HTTP/2 connection preface, the Magic frame.

![](https://img.halfrost.com/Blog/ArticleImage/124_2_0.png)

The client connection preface begins with a sequence of 24 octets, shown in hexadecimal notation as:
```c
     0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
```
The connection preface starts with the string "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n". The Magic frame is immediately followed by a SETTINGS frame. Once the server successfully ACKs this message and no connection error occurs, the HTTP/2 connection is considered established.

------------------------------------------------------

Reference:  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2\_begin/](https://halfrost.com/http2_begin/)