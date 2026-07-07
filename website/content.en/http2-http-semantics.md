+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-05-12T07:04:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/127_0.png"
slug = "http2-http-semantics"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "HTTP Semantics in HTTP/2"

+++


HTTP/2 was designed from the outset to be as compatible as possible with HTTP as it is currently used. This means that, from an application’s perspective, the protocol’s functionality is essentially unchanged. To achieve this, all request and response semantics are preserved, although the syntax used to convey those semantics has changed.

Therefore, the specifications and requirements for HTTP/1.1 semantics and content [[RFC7231]](https://tools.ietf.org/html/rfc7231), conditional requests [[RFC7232]](https://tools.ietf.org/html/rfc7232), range requests [[RFC7233]](https://tools.ietf.org/html/rfc7233), caching [[RFC7234]](https://tools.ietf.org/html/rfc7234), and authentication [[RFC7235]](https://tools.ietf.org/html/rfc7235) also apply to HTTP/2. Selected portions of HTTP/1.1 message syntax and routing [[RFC7230]](https://tools.ietf.org/html/rfc7230), such as the HTTP and HTTPS URI schemes, also apply to HTTP/2, but the representation of the protocol’s semantics is defined below.

## I. HTTP Request/Response Exchange

A client sends an HTTP request on a new stream using a previously unused stream identifier ([Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)). The server sends the HTTP response on the same stream as the request.

An HTTP message (request or response) consists of:

1. For responses only, zero or more HEADERS frames (each followed by zero or more CONTINUATION frames) containing the header fields of informational (1xx) HTTP responses (see [[RFC7230] Section 3.2](https://tools.ietf.org/html/rfc7230#section-3.2) and [[RFC7231] Section 6.2](https://tools.ietf.org/html/rfc7231#section-6.2)),
2. A HEADERS frame containing the header fields (followed by zero or more CONTINUATION frames) (see [[RFC7230] Section 3.2](https://tools.ietf.org/html/rfc7230#section-3.2))
3. Zero or more DATA frames containing the payload body (see [[RFC7230] Section 3.3](https://tools.ietf.org/html/rfc7230#section-3.3))
4. Optionally, a HEADERS frame followed by zero or more CONTINUATION frames containing the trailer-part, if present (see [[RFC7230] Section 4.1.2](https://tools.ietf.org/html/rfc7230#section-4.1.2)).

The final frame in the sequence carries the END\_STREAM flag. Note that a HEADERS frame carrying the END\_STREAM flag can be followed by CONTINUATION frames carrying the remainder of the header block. Other frames (from any stream) MUST NOT appear between a HEADERS frame and any CONTINUATION frames that might follow it.

HTTP/2 uses DATA frames to carry message payloads. The “chunked” transfer coding defined in [[RFC7230] Section 4.1](https://tools.ietf.org/html/rfc7230#section-4.1) is **prohibited** in HTTP/2.

Trailing header fields are carried in a header block that also terminates the stream. Such a header block is a sequence that starts with a HEADERS frame, followed by zero or more CONTINUATION frames, where the HEADERS frame carries the END\_STREAM flag. Header blocks after the first that do not terminate the stream are not part of an HTTP request or response.


HEADERS frames (and their associated CONTINUATION frames) can appear only at the beginning or end of a stream. After receiving a final (non-informational) status code, an endpoint that receives a HEADERS frame without the END\_STREAM flag set MUST treat the corresponding request or response as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).

An HTTP request/response exchange fully consumes a single stream. A request begins with a HEADERS frame, which places the stream in the “open” state. The request ends with a frame carrying END\_STREAM, which makes the stream “half-closed (local)” for the client and “half-closed (remote)” for the server. The response begins with a HEADERS frame and ends with a frame carrying END\_STREAM, which transitions the stream to the “closed” state.

An HTTP response is complete after the server sends, or the client receives, a frame with the END\_STREAM flag set, including any CONTINUATION frames needed to complete the header block. If the response does not depend on any portion of the request that has not yet been sent and received, the server can send a complete response before the client has sent the entire request. After sending a complete response, the server can request that the client abort transmission of a request without error by sending an RST\_STREAM with the NO\_ERROR error code. If this happens, the client MUST NOT discard the response solely because it received this RST\_STREAM, though the client can decide to discard the response for other reasons.


### 1. Upgrading from HTTP/2

HTTP/2 removes support for the 101 (Switching Protocols) informational status code ([[RFC7231], Section 6.2.2](https://tools.ietf.org/html/rfc7231#section-6.2.2)). The semantics of 101 (Switching Protocols) do not apply to a multiplexed protocol. Alternative protocols can use the same mechanisms as HTTP/2 to negotiate their use (see [Section 3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#1-http2-version-identification)).


### 2. HTTP Header Fields

HTTP header fields carry information as a series of key-value pairs. For a list of registered HTTP headers, see the “Message Header Fields” registry maintained at <https://www.iana.org/assignments/message-headers>. As in HTTP/1.x, header field names are ASCII strings compared in a case-insensitive manner. However, header field names MUST be converted to lowercase before being encoded in HTTP/2. A request or response containing an uppercase header field name MUST be treated as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).

#### (1) Pseudo-Header Fields

Where HTTP/1.x uses a message start-line (see [[RFC7230], Section 3.1](https://tools.ietf.org/html/rfc7230#section-3.1)) to convey the target URI, request method, and response status code, HTTP/2 uses special pseudo-header fields that begin with the ':' character (ASCII 0x3a) for the same purpose. Pseudo-header fields are not HTTP header fields. Endpoints MUST NOT generate pseudo-header fields that are not defined in this document.

Pseudo-header fields are valid only in the context in which they are defined. Pseudo-header fields defined for requests MUST NOT appear in responses; pseudo-header fields defined for responses MUST NOT appear in requests. Pseudo-header fields MUST NOT appear in trailers. An endpoint MUST treat a request or response containing an undefined or invalid pseudo-header field as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).

All pseudo-header fields MUST appear in the header block before regular header fields. Any request or response that contains a pseudo-header field in a header block where that pseudo-header field appears after a regular header field MUST be treated as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).


#### (2) Connection-Specific Header Fields

HTTP/2 does not use the Connection header field to identify connection-specific header fields. In this protocol, connection-specific metadata is conveyed through other means. Endpoints are prohibited from generating messages that contain connection-specific header fields. Any message containing connection-specific header fields is to be treated as malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).

The sole exception is the TE header field, which can appear in HTTP/2 requests. It MUST NOT contain any value other than trailers. This means that intermediaries converting an HTTP/1.x message to HTTP/2 need to remove any header fields named by the Connection header field, as well as the Connection header field itself. These intermediaries should also remove other connection-specific header fields, such as Keep-Alive, Proxy-Connection, Transfer-Encoding, and Upgrade, even if they are not named by the Connection header field.

**Note: HTTP/2 intentionally does not support upgrading to other protocols. The handshake methods described in [Section 3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#1-http2-version-identification) are considered sufficient for negotiating alternative protocols**.

#### (3) Request Pseudo-Header Fields

The following pseudo-header fields are defined for HTTP/2 requests:

- The ":method" pseudo-header field contains the HTTP method ([[RFC7231], Section 4](https://tools.ietf.org/html/rfc7231#section-4)).
- The ":scheme" pseudo-header field contains the scheme portion of the target URI ([[RFC3986], Section 3.1](https://tools.ietf.org/html/rfc3986#section-3.1)). ":scheme" is not restricted to URIs with the "http" and "https" schemes. A proxy or gateway can translate requests for non-HTTP schemes, enabling HTTP to interoperate with non-HTTP services.
- The ":authority" pseudo-header field contains the authority portion of the target URI ([[RFC3986], Section 3.2](https://tools.ietf.org/html/rfc3986#section-3.2)). The authority MUST NOT contain the deprecated "userinfo" subcomponent for "http" or "https" scheme URIs. To ensure that the HTTP/1.1 request-line can be reproduced accurately, this pseudo-header field MUST be omitted when translating from an HTTP/1.1 request that has an origin-form or asterisk-form request target ([see [RFC7230], Section 5.3](https://tools.ietf.org/html/rfc7230#section-5.3)). Clients that generate HTTP/2 requests directly should use the ":authority" pseudo-header field instead of the Host header field. An intermediary that converts an HTTP/2 request to HTTP/1.1 MUST create a Host header field by copying the value of the ":authority" pseudo-header field if the request does not already contain one.
- The ":path" pseudo-header field contains the path and query portions of the target URI: the absolute path and, optionally, the query portion after a "?" character (see [[RFC3986] Sections 3.3 and 3.4](https://tools.ietf.org/html/rfc3986)). An asterisk-form request includes the value '\*' in the ":path" pseudo-header field. For "http" or "https" URIs, this pseudo-header field MUST NOT be empty; an "http" or "https" URI that does not contain a path component MUST include the value "/". The exception to this rule is an OPTIONS request for an "http" or "https" URI that does not contain a path component; it MUST include a ":path" pseudo-header field with the value '\*' (see [[RFC7230], Section 5.3.4](https://tools.ietf.org/html/rfc7230#section-5.3.4)).
Except for CONNECT requests, all HTTP/2 requests MUST include valid values for the ":method", ":scheme", and ":path" pseudo-header fields ([Section 8.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%B8%89-the-connect-method)). An HTTP request that omits a mandatory pseudo-header field is malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). HTTP/2 does not define a way to carry the version identifier included in an HTTP/1.1 request line.

#### (4) Response Pseudo-Header Fields

For HTTP/2 responses, a ":status" pseudo-header field is defined to carry the HTTP status code field (see [[RFC7231], Section 6](https://tools.ietf.org/html/rfc7231#section-6)). This pseudo-header field MUST be included in all responses; otherwise, the response is malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). HTTP/2 does not define a way to carry the version or reason phrase included in an HTTP/1.1 status line.


#### (5) Compressing the Cookie Header Field

The Cookie header field [COOKIE] uses a semicolon (“;”) to delimit cookie pairs (or "crumbs"). This header field does not follow the list construction rules in HTTP (see [[RFC7230], Section 3.2.2](https://tools.ietf.org/html/rfc7230#section-3.2.2)), which prevents cookie pairs from being split into separate name-value pairs. This can significantly reduce compression efficiency, because only a single cookie pair is updated.

To improve compression efficiency, the Cookie header field MAY be split into separate header fields, each containing one or more cookie pairs. If there are multiple Cookie header fields after decompression, they MUST be concatenated into a single octet string using the two-octet delimiter 0x3B, 0x20 (the ASCII string “; ”) before being passed to a non-HTTP/2 context, such as an HTTP/1.1 connection or a generic HTTP server application.

Therefore, the following two lists of Cookie header fields are semantically equivalent.

cookie: a = b;c = d;e = f  
  
cookie: a = b  
cookie: c = d  
cookie: e = f  


#### (6) Malformed Requests and Responses

A malformed request or response is an otherwise valid sequence of HTTP/2 frames that is invalid due to the presence of extraneous frames, prohibited header fields, missing required header fields, or header field names containing uppercase characters.

A request or response that includes a valid payload body can include a Content-Length header field. If the value of the Content-Length header field does not equal the sum of the payload lengths of the DATA frames that form the body, the request or response is also considered malformed. As described in [[RFC7230], Section 3.3.2](https://tools.ietf.org/html/rfc7230#section-3.3.2), a response defined as having no payload can have a non-zero Content-Length header field even if no content is included in DATA frames.

An intermediary that processes HTTP requests or responses (that is, any intermediary that is not acting as a tunnel) MUST NOT forward a malformed request or response. A detected malformed request or response MUST be treated as a stream error of type PROTOCOL\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). For a malformed request, a server MAY send an HTTP response before closing or resetting the stream. A client MUST NOT accept a malformed response. Note that these requirements are intended to prevent several common classes of attacks against HTTP; they are deliberately strict because leniency can introduce vulnerabilities.


### 3. Examples

This section shows HTTP/1.1 requests and responses and provides descriptions of the equivalent HTTP/2 requests and responses. An HTTP GET request includes request header fields and no payload body, so it is sent as a single HEADERS frame followed by zero or more CONTINUATION frames containing the serialized request header field block. The HEADERS frame below has both the END\_HEADERS and END\_STREAM flags set; no CONTINUATION frames are sent.
```c
     GET /resource HTTP/1.1           HEADERS
     Host: example.org          ==>     + END_STREAM
     Accept: image/jpeg                 + END_HEADERS
                                          :method = GET
                                          :scheme = https
                                          :path = /resource
                                          host = example.org
                                          accept = image/jpeg
```
Similarly, a response containing only response header fields is sent as a HEADERS frame (again, followed by zero or more CONTINUATION frames) containing the serialized response header field block.
```c
     HTTP/1.1 304 Not Modified        HEADERS
     ETag: "xyzzy"              ==>     + END_STREAM
     Expires: Thu, 23 Jan ...           + END_HEADERS
                                          :status = 304
                                          etag = "xyzzy"
                                          expires = Thu, 23 Jan ...
```
An HTTP POST request containing request header fields and payload data is sent as a HEADERS frame, followed by zero or more CONTINUATION frames containing request header fields, followed by one or more DATA frames, with the last CONTINUATION (or HEADERS) frame carrying the END\_HEADERS flag and the final DATA frame carrying the END\_STREAM flag.
```c
     POST /resource HTTP/1.1          HEADERS
     Host: example.org          ==>     - END_STREAM
     Content-Type: image/jpeg           - END_HEADERS
     Content-Length: 123                  :method = POST
                                          :path = /resource
     {binary data}                        :scheme = https

                                      CONTINUATION
                                        + END_HEADERS
                                          content-type = image/jpeg
                                          host = example.org
                                          content-length = 123

                                      DATA
                                        + END_STREAM
                                      {binary data}
```
Note that the data contributing to any given header field can be spread across header block fragments. The assignment of header fields to frames in this example is illustrative only.

A response containing header fields and payload data is sent as a HEADERS frame, followed by zero or more CONTINUATION frames, followed by one or more DATA frames, with the last DATA frame in the sequence having the END\_STREAM flag set.
```c
     HTTP/1.1 200 OK                  HEADERS
     Content-Type: image/jpeg   ==>     - END_STREAM
     Content-Length: 123                + END_HEADERS
                                          :status = 200
     {binary data}                        content-type = image/jpeg
                                          content-length = 123

                                      DATA
                                        + END_STREAM
                                      {binary data}
```
Informational responses using 1xx status codes other than 101 are sent as HEADERS frames, followed by zero or more CONTINUATION frames.

After the request or response header block and all DATA frames have been sent, trailing header fields are sent as a header block. The HEADERS frame that begins the trailers header block has the END\_STREAM flag set. The following example includes the 100 (Continue) status code, which is sent in response to a request that includes the “100-continue” token in the Expect header field, as well as trailing header fields.
```c
     HTTP/1.1 100 Continue            HEADERS
     Extension-Field: bar       ==>     - END_STREAM
                                        + END_HEADERS
                                          :status = 100
                                          extension-field = bar

     HTTP/1.1 200 OK                  HEADERS
     Content-Type: image/jpeg   ==>     - END_STREAM
     Transfer-Encoding: chunked         + END_HEADERS
     Trailer: Foo                         :status = 200
                                          content-length = 123
     123                                  content-type = image/jpeg
     {binary data}                        trailer = Foo
     0
     Foo: bar                         DATA
                                        - END_STREAM
                                      {binary data}

                                      HEADERS
                                        + END_STREAM
                                        + END_HEADERS
                                          foo = bar
```

### 4. Request Reliability Mechanisms in HTTP/2


In HTTP/1.1, an HTTP client cannot retry non-idempotent requests when an error occurs, because it cannot determine the nature of the error. Some server-side processing might have occurred before the error, and retrying the request could cause undesirable effects.

HTTP/2 provides two mechanisms that give clients assurance that a request has not been processed:

- The GOAWAY frame indicates the highest-numbered stream that might have been processed. Therefore, requests on streams with higher numbers are guaranteed to be safe to retry.
- The REFUSED\_STREAM error code can be included in an RST\_STREAM frame to indicate that the stream is being closed before any processing has occurred. Any retry request sent on the reset stream can be safely retried.


An unprocessed request has not failed; clients can automatically retry it, even if it uses a non-idempotent method. A server cannot indicate that a stream has not been processed unless it can guarantee that fact. If frames on a stream have been delivered to the application layer for any stream, REFUSED\_STREAM cannot be used for that stream, and the GOAWAY frame must include a stream identifier greater than or equal to the given stream identifier.

In addition to these mechanisms, the PING frame gives clients an easy way to test a connection. Because some intermediaries, such as network address translators or load balancers, silently discard connection bindings, an idle connection can be broken. The PING frame allows a client to safely test whether the connection is still alive without sending a request.


## II. Server Push


![](https://img.halfrost.com/Blog/ArticleImage/129_2.jpg)

![](https://img.halfrost.com/Blog/ArticleImage/129_3.jpg)

![](https://img.halfrost.com/Blog/ArticleImage/129_4.jpg)


HTTP/2 allows a server to proactively send (or “push”) responses, along with their corresponding “promised” requests, to the client for a related request previously initiated by the client. Server Push can be useful when the server knows that the client will need these responses in order to fully process the response to the original request.

> After the client receives a PUSH\_PROMISE frame, it can choose to reject the stream based on its own circumstances by sending an RST\_STREAM frame. (For example, this might happen if the resource is already in the cache.) This is an important improvement over HTTP/1.x. By contrast, resource inlining, a popular HTTP/1.x “optimization,” is equivalent to “forced push”: the client has no way to reject, cancel, or separately process the inlined resource.
> 


A client can indicate that server push should be disabled when making a request, although this is negotiated independently on each hop. The SETTINGS\_ENABLE\_PUSH setting can be set to 0 to disable server push.

Promised requests must be cacheable (see [[RFC7231], Section 4.2.3](https://tools.ietf.org/html/rfc7231#section-4.2.3)), must be safe (see [[RFC7231], Section 4.2.1](https://tools.ietf.org/html/rfc7231#section-4.2.1)), and must not include a request body. If a client receives a promised request that is not cacheable, is unsafe, or indicates the presence of a request body, it must reset the promised stream with a stream error of type PROTOCOL\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Note that if the client cannot determine whether a newly defined method is safe, this can result in the promised stream being reset.

If the client implements an HTTP cache, cacheable pushed responses can be cached (see [[RFC7234], Section 3](https://tools.ietf.org/html/rfc7234#section-3)). While the stream identified by the promised stream ID remains open, the pushed response can be successfully validated with the origin server (for example, if a “no-cache” cache response directive is present ([[RFC7234], Section 5.2.2](https://tools.ietf.org/html/rfc7234#section-5.2.2))). Non-cacheable pushed responses must not be stored by any HTTP cache. They can be provided separately to the application.

If the server is authoritative, it needs to include a value in the ":authority" pseudo-header field (see [Section 10.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)). A client must treat a PUSH\_PROMISE from a server that is not authoritative as a stream error of type PROTOCOL\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

An intermediary can receive pushes from a server and choose not to forward them to the client. In other words, how pushed information is used is up to that intermediary. Similarly, an intermediary might choose to perform additional pushes to the client without taking any action on the server.

Clients cannot push. Therefore, a server must treat receipt of a PUSH\_PROMISE frame as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). A client must reject any attempt to change the SETTINGS\_ENABLE\_PUSH setting to a value other than 0; if this occurs, it can treat the message that changes the setting as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### 1. Push Requests

Server push is semantically equivalent to a server responding to a request; however, in this case, the request is also sent by the server as a PUSH\_PROMISE frame.

The PUSH\_PROMISE frame includes a header block containing the complete set of request header fields defined by the server for the request. A response cannot be pushed for a request that contains a request body.

A pushed response is always associated with an explicit request from the client. The PUSH\_PROMISE frame sent by the server is sent on the stream of that explicit request. The PUSH\_PROMISE frame also includes a promised stream identifier, selected from the stream identifiers available to the server (see [Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)).

The header fields in a PUSH\_PROMISE and any subsequent CONTINUATION frames must form a valid and complete set of request header fields ([Section 8.1.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). The server must include a safe and cacheable method in the “:method” pseudo-header field. If a client receives a PUSH\_PROMISE that does not contain a complete and valid header field set, or whose “:method” pseudo-header field identifies an unsafe method, it must respond with a stream error of type PROTOCOL\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

The server should send a PUSH\_PROMISE frame ([Section 6.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)) before sending any frame that references the promised response. This avoids a race in which the client issues a request before receiving any PUSH\_PROMISE frame.

For example, if a server receives a request for a document that contains embedded links to multiple image files, and the server chooses to push those additional images to the client, sending the PUSH\_PROMISE frames before the DATA frames that contain the image links ensures that the client can see the pushed resources before discovering the embedded links. Similarly, if a server-pushed response is referenced by a header block (for example, in a Link header field), sending the PUSH\_PROMISE before sending the header block ensures that the client does not request those resources.

**PUSH\_PROMISE frames must not be sent by clients**.

A PUSH\_PROMISE frame can be sent by a server in response to any client-initiated stream, but the stream must be in the "open" or "half-closed (remote)" state from the server’s perspective. PUSH\_PROMISE frames are interleaved with frames that contain the response, although they cannot be interleaved between HEADERS and CONTINUATION frames that contain a single header block.


Sending a PUSH\_PROMISE frame creates a new stream and places that stream in the "reserved (local)" state for the server and the "reserved (remote)" state for the client.


### 2. Push Responses


After sending the PUSH\_PROMISE frame, the server can begin sending the pushed response as a response ([Section 8.1.2.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)) on the stream that uses the promised stream identifier and is opened by the server. The server uses this stream to transmit the HTTP response, using the same frame sequence defined in [Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange). After the initial HEADERS frame is sent, the stream becomes "half-closed" for the client ([Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)). Once the client receives the PUSH\_PROMISE frame and chooses to accept the pushed response, it should not issue any request for the promised response before the promised stream is closed.
If, for special reasons, the client determines that it does not want to receive a pushed response from the server, or if the server takes too long to start sending the promised response, the client can send an RST\_STREAM frame using the CANCEL or REFUSED\_STREAM code and referencing the identifier of the pushed stream.


A client can use the SETTINGS\_MAX\_CONCURRENT\_STREAMS setting to limit the number of responses the server can push concurrently. To prevent the server from creating the necessary streams, server push can be disabled by setting SETTINGS\_MAX\_CONCURRENT\_STREAMS to zero. Doing so does not prohibit the server from sending PUSH\_PROMISE frames; the client needs to reset any unwanted promised streams.

A client that receives a pushed response must verify that the server is authoritative (see [Section 10.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)), or that it is providing a proxy capable of pushing responses for the corresponding requests. For example, a server with a certificate containing only the DNS-ID or Common Name "example.com" is not permitted to push a response for "https://www.example.org/doc".

The response on a PUSH\_PROMISE stream starts with a HEADERS frame, which immediately places the stream in the "half-closed (remote)" state on the server and the "half-closed (local)" state on the client, and ends with a frame carrying END\_STREAM, which places the stream in the "closed" state.

Note: A client never sends a frame with the END\_STREAM flag for server push.


## III. The CONNECT Method


In HTTP/1.x, the CONNECT pseudo-method ([ [RFC7231], Section 4.3.6](https://tools.ietf.org/html/rfc7231#section-4.3.6)) is used to convert an HTTP connection into a tunnel to a remote host. CONNECT is primarily used with HTTP proxies to establish a TLS session with an origin server in order to interact with "https" resources.

In HTTP/2, the CONNECT method can be used to establish a tunnel to a remote host over a single HTTP/2 stream, serving a purpose similar to that in HTTP/1.x. The mapping of HTTP header fields works as defined in [Section 8.1.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields) ("Request Pseudo-Header Fields"), with a few differences. In particular:


- The ":method" pseudo-header field is set to "CONNECT".  
- The ":scheme" and ":path" pseudo-header fields MUST be omitted.
- The ":authority" pseudo-header field contains the host and port of the host to connect to (equivalent to the authority form of the request-target of a CONNECT request; [see [RFC7230], Section 5.3](https://tools.ietf.org/html/rfc7230#section-5.3)).


A CONNECT request that does not conform to these restrictions is malformed ([Section 8.1.2.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). A proxy that supports CONNECT establishes a TCP connection [[TCP]](https://tools.ietf.org/html/rfc7540#ref-TCP) to the server identified by the ":authority" pseudo-header field. Once the connection has been successfully established, the proxy sends the client a HEADERS frame containing a 2xx series status code, as defined in [[RFC7231], Section 4.3.6](https://tools.ietf.org/html/rfc7231#section-4.3.6).

After each peer has sent its initial HEADERS frame, all subsequent DATA frames correspond to data sent on the TCP connection. The payload of any DATA frame sent by the client is forwarded by the proxy to the TCP server; data received from the TCP server is assembled by the proxy into DATA frames. Frame types other than DATA or stream management frames (RST\_STREAM, WINDOW\_UPDATE, and PRIORITY) MUST NOT be sent on a connected stream, and if received MUST be treated as a stream error ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


Either peer can close the TCP connection. The END\_STREAM flag on a DATA frame is treated as equivalent to the TCP FIN bit. Only after receiving a frame with the END\_STREAM flag can the client send a DATA frame with the END\_STREAM flag set. A proxy that receives a DATA frame with the END\_STREAM flag can send additional data and set the FIN bit on the final TCP segment. A proxy that receives a TCP segment with the FIN bit set sends a DATA frame with the END\_STREAM flag set. Note that the final TCP segment or DATA frame might be empty.


RST\_STREAM is used to indicate a TCP connection error. Any error on the proxied TCP connection is treated as a stream error of type CONNECT\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)), including receipt of a TCP segment with the RST bit set. Correspondingly, if the proxy detects an error on the stream or the HTTP/2 connection, the proxy MUST send a TCP segment with the RST bit set.


------------------------------------------------------

Reference:  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-http-semantics/](https://halfrost.com/http2-http-semantics/)
>