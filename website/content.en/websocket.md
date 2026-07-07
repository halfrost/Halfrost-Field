+++
author = "一缕殇流化隐半边冰霜"
categories = ["Websocket", "Protocol"]
date = 2018-05-19T15:30:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/83_0_1.png"
slug = "websocket"
tags = ["Websocket", "Protocol"]
title = "Full-Duplex Communication with WebSocket"

+++


## I. What Is WebSocket?

![](https://img.halfrost.com/Blog/ArticleImage/83_1.png)


WebSocket is a network communication protocol. It was introduced in 2009 and standardized by the IETF in 2011 as the RFC 6455 communication standard, with RFC 7936 providing supplementary specifications. The WebSocket API has also been standardized by the W3C.

WebSocket is a protocol introduced in HTML5 for **full-duplex communication over a single TCP connection**. There is no longer a Request/Response concept; both sides have completely equal status. Once the connection is established, a truly persistent connection is created, and either side can send data to the other at any time.


(HTML5 is the latest version of HTML and includes some new tags and entirely new APIs. HTTP is a protocol, whose latest version is currently HTTP/2. Therefore, WebSocket and HTTP overlap in some areas, but they also differ in many ways. Their overlap occurs during the HTTP handshake phase. After the handshake succeeds, data is transmitted directly over the TCP channel.)

## II. Why Was WebSocket Invented?


Before WebSocket existed, the Web used several approaches to implement real-time communication: from the earliest polling, to Long polling, then streaming-based approaches, and finally SSE. These went through several different stages of evolution.


## (1) The Initial Short Polling Stage

![](https://img.halfrost.com/Blog/ArticleImage/8_2.png)

This approach is not suitable for retrieving real-time information. The client and server continuously establish connections, and the client asks at regular intervals whether there are any new messages. The client keeps polling for new messages. This approach results in many connections—one for receiving and one for sending. In addition, every request carries an HTTP Header, which consumes a lot of traffic and also consumes CPU utilization.

At this stage, you can see that one Request corresponds to one Response, back and forth repeatedly.

On the Web, short polling is implemented using AJAX JSONP Polling.

Because HTTP cannot keep a connection open indefinitely, it cannot frequently push data for long periods between the server and the Web browser. Therefore, Web applications implement polling through frequent asynchronous JavaScript and XML (AJAX) requests.

![](https://img.halfrost.com/Blog/ArticleImage/83_2.png)


- Advantages: short-lived connections, simple server-side handling, supports cross-origin access, and has good browser compatibility.
- Disadvantages: some latency, significant server pressure, wasted bandwidth and traffic, and most requests are ineffective.


## (2) Improved Long Polling Stage (Comet Long polling)

![](https://img.halfrost.com/Blog/ArticleImage/8_3.png)

Long polling is an improved version of polling. After the client sends an HTTP request to the server, the server checks whether there are any new messages. If there are none, it keeps waiting. Only when a message arrives or the request times out does it return a response to the client. After receiving the message, the client establishes the connection again, and the process repeats. To some extent, this approach reduces issues such as network bandwidth usage and CPU utilization.

This approach also has certain drawbacks: its real-time performance is not high. A system with strict real-time requirements would certainly not use this method. Because a GET request round trip requires 2 RTTs, the data may have changed significantly during that interval, and by the time the client receives it, the data may already be far behind.

In addition, the problem of low network bandwidth utilization is not solved at the root. Every Request carries the same Header.

Correspondingly, the Web also has AJAX long polling, also called XHR long polling.

The client opens an AJAX request to the server and then waits for a response. The server needs specific capabilities to allow the request to remain pending. As soon as an event occurs, the server sends a response through the pending request and closes it. After the client processes the information returned by the server, it sends another request and re-establishes the connection, repeating the cycle.

![](https://img.halfrost.com/Blog/ArticleImage/83_3.png)


- Advantages: fewer polling requests, low latency, and good browser compatibility.
- Disadvantages: the server needs to maintain a large number of connections.

## (3) Stream-Based Approaches (Comet Streaming)

### 1. Iframe- and htmlfile-Based Streaming (Iframe Streaming)

The iframe streaming approach inserts a hidden iframe into the page and uses its src attribute to create a long-lived connection between the server and the client. The server transmits data to the iframe—usually HTML containing JavaScript responsible for inserting information—to update the page in real time. The advantage of iframe streaming is good browser compatibility.


![](https://img.halfrost.com/Blog/ArticleImage/83_4.png)

Using an iframe to request a long-lived connection has an obvious drawback: in IE and Mozilla Firefox, the progress bar indicates that loading has not completed, and the icon at the top of IE keeps spinning, indicating that loading is still in progress.

The geniuses at Google used an ActiveX object called “htmlfile” to solve the loading indicator problem in IE and applied this method in the gmail+gtalk product. Alex Russell introduced this approach in the article “What else is burried down in the depth's of Google's amazing JavaScript?”. The comet-iframe.tar.gz provided by the Zeitoun website encapsulates a JavaScript comet object based on iframe and htmlfile, supporting IE and Mozilla Firefox browsers, and can be used as a reference.


- Advantages: simple to implement, available in all browsers that support iframe, one client connection, multiple server pushes.
- Disadvantages: cannot accurately determine the connection state. During iframe requests in IE, the browser title remains in a loading state, and the bottom status bar also shows that it is loading, resulting in a poor user experience. (htmlfile can solve this problem by dynamically writing to memory through ActiveXObject.)


### 2. AJAX multipart streaming (XHR Streaming)

Implementation idea: the browser must support the multi-part flag. The client sends a Request via AJAX, and the server keeps this connection open. It can then continuously push data to the client through the HTTP/1.1 chunked encoding mechanism until timeout or manual disconnection.

- Advantages: one client connection, server data can be pushed multiple times.
- Disadvantages: not all browsers support the multi-part flag.


### 3. Flash Socket (Flash Streaming)

Implementation idea: embed a Flash program that uses the Socket class into the page. JavaScript communicates with the server-side Socket interface by calling the Socket interface provided by this Flash program. JavaScript receives data sent by the server through Flash Socket.

- Advantages: implements true instant communication rather than pseudo-real-time communication.
- Disadvantages: the client must install the Flash plugin; it is not an HTTP protocol and cannot automatically traverse firewalls.


### 4. Server-Sent Events

Server-Sent Events (SSE) is also a technology announced in HTML5 for servers to initiate data transmission to browser clients. Once the initial connection is created, the event stream remains open until the client closes it. This technology is sent over traditional HTTP and provides various capabilities that WebSockets lack, such as automatic reconnection, event IDs, and the ability to send arbitrary events.


SSE works by having the server declare to the client that what it is about to send is streaming information, which will be sent continuously. At this point, the client does not close the connection and keeps waiting for new data streams from the server, analogous to a video stream. SSE uses this mechanism to push information to the browser via streaming data. It is based on the HTTP protocol and is currently supported by all browsers except IE/Edge.

SSE is a one-way channel: only the server can send data to the browser, because streaming information is essentially a download.

The SSE data sent by the server to the browser must be UTF-8 encoded text and must have the following HTTP header information.
```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
```
Among the three lines above, the first line’s Content-Type must specify the MIME type as event-steam

![](https://img.halfrost.com/Blog/ArticleImage/83_5.png)


- Advantages: Suitable for frequent updates, low latency, and data that flows only from the server to the client.
- Disadvantages: Browser compatibility is difficult to handle.

![](https://img.halfrost.com/Blog/ArticleImage/83_6.png)

The above are four common stream-based approaches: Iframe Streaming, XHR Streaming, Flash Streaming, and Server-Sent Events.

In terms of browser compatibility difficulty — short polling/AJAX > long polling/Comet > persistent connection/SSE

## The Arrival of WebSocket

Looking at the evolutionary approaches above, this has also been a process of continuous improvement.

Short polling is inefficient and wastes a great deal of resources (network bandwidth and compute resources). It has some latency, puts considerable pressure on the server, and most requests are invalid.

Although long polling eliminates a large number of invalid requests and reduces server pressure and some network bandwidth usage, it still needs to maintain a large number of connections.

Finally, with stream-based approaches, the server pushes data to the client. In this direction, streaming has good real-time characteristics. But it is still one-way, and client requests to the server still require an HTTP request.

So people began to consider whether there was a perfect solution that could support bidirectional communication, reduce the network overhead of request headers, offer stronger extensibility, and ideally support binary frames, compression, and other features.

Thus, people invented what currently appears to be a “perfect” solution — WebSocket.

After the WebSocket standard was published in HTML5, it directly replaced Comet as the new method for server push.

> Comet is a push technology for the web that enables the server to deliver updated information to the client in real time without requiring the client to send a request. There are currently two implementation approaches: long polling and iframe streaming.


![](https://img.halfrost.com/Blog/ArticleImage/83_7.png)


- Advantages:
- Lower control overhead. After the connection is established, when the server and client exchange data, the packet header used for protocol control is relatively small. Without extensions, for server-to-client content, this header is only 2 to 10 bytes in size (depending on the packet length); for client-to-server content, this header also requires an additional 4-byte mask. Compared with HTTP requests, which must carry a complete header every time, this overhead is significantly reduced.
- Stronger real-time capability. Because the protocol is full-duplex, the server can proactively send data to the client at any time. Compared with HTTP requests, where the server can respond only after the client initiates a request, latency is clearly lower; even compared with long-polling approaches such as Comet, it can deliver data more frequently within a short period of time.
- Persistent connection, with connection state maintained. Unlike HTTP, WebSocket needs to establish a connection first, which makes it a stateful protocol. During subsequent communication, some state information can be omitted. HTTP requests, on the other hand, may need to carry state information (such as authentication) with every request.
- Bidirectional communication and better binary support. It has good compatibility with the HTTP protocol. The default ports are also 80 and 443, and the handshake phase uses the HTTP protocol, so it is not easily blocked during the handshake and can pass through various HTTP proxy servers.

- Disadvantages: Some browsers do not support it (the number of supported browsers will continue to grow).
Use cases: newer browser support, no framework constraints, and higher extensibility.

![](https://img.halfrost.com/Blog/ArticleImage/83_8.png)


To summarize WebSocket in one sentence:

WebSocket is a **stateful** protocol introduced in HTML5 that provides **full-duplex communication** **independently** over a single **TCP** connection (unlike stateless HTTP), and it can also support binary frames, extension protocols, partially customized subprotocols, compression, and other features.


**For now, WebSocket can perfectly replace AJAX polling and Comet. However, in some scenarios it still cannot replace SSE; WebSocket and SSE each have their own strengths!**


## 3. WebSocket Handshake

The RFC6455 standard for WebSocket defines two high-level components: an opening HTTP handshake for negotiating connection parameters, and a binary message framing mechanism for supporting low-overhead, message-oriented transmission of text and binary data. Next, let’s take a closer look at these two high-level components. This section discusses the details of the handshake, and the next section will cover the binary message framing mechanism.

First, RFC6455 includes the following passage:

>The WebSocket Protocol attempts to enable two-way HTTP communication over existing HTTP infrastructure, and therefore also uses HTTP ports 80 and 443......However, this design is not limited to implementing WebSocket communication over HTTP. Future implementations may use a simpler handshake on some dedicated port, without having to redefine such a protocol.
>										
>——WebSocket Protocol RFC 6455


From this passage, we can see how ambitious the people who designed the WebSocket protocol were—or how far ahead they were planning for the future. From the very beginning, WebSocket was designed to support handshakes on arbitrary ports, rather than relying solely on HTTP handshakes.

However, the most commonly used approach today still relies on HTTP for the handshake, because the HTTP infrastructure is already quite mature.


### Standard Handshake Flow

Next, let’s look at a concrete example of a WebSocket handshake, using the author’s own website [https://threes.halfrost.com/](https://threes.halfrost.com/) as an example.

Open this website, and as soon as the page is rendered, it initiates a wss handshake request. The handshake request is as follows:
```http
GET wss://threes.halfrost.com/sockjs/689/8x5nnke6/websocket HTTP/1.1
// The request method must be GET, and the HTTP version must be at least 1.1

Host: threes.halfrost.com
Connection: Upgrade
Pragma: no-cache
Cache-Control: no-cache
Upgrade: websocket
// Request an upgrade to the WebSocket protocol

Origin: https://threes.halfrost.com
Sec-WebSocket-Version: 13
// The WebSocket protocol version used by the client

User-Agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Mobile Safari/537.36
Accept-Encoding: gzip, deflate, br
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Cookie: _ga=GA1.2.00000006.14111111496; _gid=GA1.2.23232376.14343448247; Hm_lvt_d60c126319=1524898423,1525574369,1526206975,1526784803; Hm_lpvt_d606319=1526784803; _gat_53806_2=1
Sec-WebSocket-Key: wZgx0uTOgNUsHGpdWc0T+w==
// An automatically generated key to verify the server's protocol support; its value must be a randomly selected 16-byte nonce, base64-encoded

Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
// Optional list of protocol extensions supported by the client, indicating the protocol-level extensions the client wants to use

```
Compared with the regular HTTP protocol, there are several differences here:

The request URL starts with `ws://` or `wss://`, rather than `HTTP://` or `HTTPS://`. Because WebSocket may be used in scenarios outside the browser, a custom URI is used here. By analogy with HTTP, the `ws` protocol is for ordinary requests and uses the same port 80 as HTTP; the `wss` protocol is for secure transmission based on SSL and uses the same port 443 as TLS.
```http
Connection: Upgrade
Upgrade: websocket
```
These two fields are generally not present in ordinary HTTP messages. Here, `Upgrade` is used to perform a protocol upgrade, specifying an upgrade to the WebSocket protocol.
```http
Sec-WebSocket-Version: 13
Sec-WebSocket-Key: wZgx0uTOgNUsHGpdWc0T+w==
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
```
Sec-WebSocket-Version indicates the WebSocket version. Initially, there were too many WebSocket protocols, and different vendors each had their own protocol versions, but this has now been standardized. If the server does not support that version, it needs to return a Sec-WebSocket-Version containing the version numbers supported by the server. (For details, see the section [WebSocket handshakes with multiple versions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/WebSocket.md#%E5%A4%9A%E7%89%88%E6%9C%AC%E7%9A%84-websocket-%E6%8F%A1%E6%89%8B) below.)

The latest version is 13, though very early versions 7 and 8 may also exist. (At present, versions 7 and 8 are basically no longer encountered.)

**Note**: Although draft versions of this document (09, 10, 11, and 12) were published (they were mostly editorial changes and clarifications rather than changes to the wire protocol), the values 9, 10, 11, and 12 are not used as valid Sec-WebSocket-Version values. These values are reserved in the IANA registry, but will not be used.
```http
+--------+-----------------------------------------+----------+
|Version |                Reference                |  Status  |
| Number |                                         |          |
+--------+-----------------------------------------+----------+
| 0      + draft-ietf-hybi-thewebsocketprotocol-00 | Interim  |
+--------+-----------------------------------------+----------+
| 1      + draft-ietf-hybi-thewebsocketprotocol-01 | Interim  |
+--------+-----------------------------------------+----------+
| 2      + draft-ietf-hybi-thewebsocketprotocol-02 | Interim  |
+--------+-----------------------------------------+----------+
| 3      + draft-ietf-hybi-thewebsocketprotocol-03 | Interim  |
+--------+-----------------------------------------+----------+
| 4      + draft-ietf-hybi-thewebsocketprotocol-04 | Interim  |
+--------+-----------------------------------------+----------+
| 5      + draft-ietf-hybi-thewebsocketprotocol-05 | Interim  |
+--------+-----------------------------------------+----------+
| 6      + draft-ietf-hybi-thewebsocketprotocol-06 | Interim  |
+--------+-----------------------------------------+----------+
| 7      + draft-ietf-hybi-thewebsocketprotocol-07 | Interim  |
+--------+-----------------------------------------+----------+
| 8      + draft-ietf-hybi-thewebsocketprotocol-08 | Interim  |
+--------+-----------------------------------------+----------+
| 9      +                Reserved                 |          |
+--------+-----------------------------------------+----------+
| 10     +                Reserved                 |          |
+--------+-----------------------------------------+----------+
| 11     +                Reserved                 |          |
+--------+-----------------------------------------+----------+
| 12     +                Reserved                 |          |
+--------+-----------------------------------------+----------+
| 13     +                RFC 6455                 | Standard |
+--------+-----------------------------------------+----------+
```
>[RFC 6455]
>
>The |Sec-WebSocket-Key| header field is used in the WebSocket opening handshake.  It is sent from the client to the server to provide part of the information used by the server to prove that it received a valid WebSocket opening handshake.  This helps ensure that the server does not accept connections from non-WebSocket clients (e.g., HTTP clients) that are being abused to send data to unsuspecting WebSocket servers.
>
>The Sec-WebSocket-Key field is used during the handshake phase. It is sent from the client to the server to provide part of the information that the server uses to prove that it received the request and can successfully complete the WebSocket handshake. This helps ensure that the server does not accept connections from non-WebSocket clients (such as HTTP clients) that are being abused to send data to unsuspecting WebSocket servers.

Sec-WebSocket-Key is randomly generated by the browser and provides basic protection against malicious or accidental connections.

Sec-WebSocket-Extensions is part of the upgrade negotiation; it will be covered in detail in the next section.

Next, let's look at the Response:
```http
HTTP/1.1 101 Switching Protocols
// 101 HTTP response code confirms the upgrade to the WebSocket protocol
Server: nginx/1.12.1
Date: Sun, 20 May 2018 09:06:28 GMT
Connection: upgrade
Upgrade: websocket
Sec-WebSocket-Accept: 375guuMrnCICpulKbj7+JGkOhok=
// Signature key value verifies protocol support
Sec-WebSocket-Extensions: permessage-deflate
// WebSocket extension selected by the server

```
In the response, reply with the HTTP 101 status code to confirm the upgrade to the WebSocket protocol.

There are also two WebSocket headers:
```http
Sec-WebSocket-Accept: 375guuMrnCICpulKbj7+JGkOhok=
// Signed key value for verifying protocol support
Sec-WebSocket-Extensions: permessage-deflate
// WebSocket extension selected by the server
```
Sec-WebSocket-Accept is the Sec-WebSocket-Key after it has been validated by the server and encrypted.

Sec-WebSocket-Accept is computed as follows:

1. First, take the Sec-WebSocket-Key from the client request header and concatenate it with 258EAFA5-E914-47DA-95CA-C5AB0DC85B11. (258EAFA5-E914-47DA-95CA-C5AB0DC85B11, a Globally Unique Identifier (GUID, [RFC4122]), is unique, fixed, and immutable.)
2. Then compute the SHA-1 hash, and finally base64-encode the result to obtain Sec-WebSocket-Accept.

Pseudocode:
```javascript
> toBase64(sha1( Sec-WebSocket-Key + 258EAFA5-E914-47DA-95CA-C5AB0DC85B11 ))
```
Similarly, `Sec-WebSocket-Key`/`Sec-WebSocket-Accept` only ensures that the handshake succeeds during the handshake; it does not guarantee data security. Using `wss://` is slightly more secure.

### Subprotocols in the Handshake

A WebSocket handshake may involve subprotocols.

First, let’s look at the WebSocket object initialization function:
```javascript
WebSocket WebSocket(
in DOMString url, 
// The URL to connect to. This URL should be the address that responds to WebSocket.
in optional DOMString protocols 
// Can be a single protocol name string or an array containing multiple protocol name strings. Defaults to an empty string.
);
```
There is an optional value here, which is an array of protocols that can be negotiated.
```javascript
var ws = new WebSocket('wss://example.com/socket', ['appProtocol', 'appProtocol-v2']);

ws.onopen = function () {
if (ws.protocol == 'appProtocol-v2') { 
	...
	} else {
	... 
	}
}
```
When creating a WebSocket object, you can pass an optional array of subprotocols to tell the server which protocols the client can understand, or which protocols the client would like the server to accept. The server can select one or more supported protocols from this data and return them. If none are supported, the handshake will fail outright, triggering the `onerror` callback and closing the connection.

The subprotocol here can be a custom protocol.

### WebSocket Handshakes Across Multiple Versions

Using WebSocket version negotiation (the `Sec-WebSocket-Version` header field), the client can initially request the version of the WebSocket protocol it chooses. This does not necessarily have to be the latest version supported by the client. If the server supports the requested version and the handshake message is otherwise valid, the server will accept that version. If the server does not support the requested version, it must respond with a `Sec-WebSocket-Version` header field, or multiple `Sec-WebSocket-Version` header fields, containing all versions it is willing to use. At that point, if the client supports one of the advertised versions, it can retry the WebSocket handshake using the new version value.

For example:
```http
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
...
Sec-WebSocket-Version: 25
```
If the server does not support version 25, it returns:
```http
HTTP/1.1 400 Bad Request
...
Sec-WebSocket-Version: 13, 8, 7
```
If the client supports version 1.3, a new handshake is required:
```http
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
...
Sec-WebSocket-Version: 13
```

## IV. WebSocket Upgrade Negotiation

During the WebSocket handshake phase, there are five WebSocket-related headers. All five are related to upgrade negotiation.

- Sec-WebSocket-Version  
The client indicates the version it wants to use (typically version 13). If the server does not support this version, it must return the versions it does support. After receiving the response, the client needs to perform the handshake again with a version it supports. The client must send this header.

- Sec-WebSocket-Key  
A key automatically generated for the client request. The client must send this header.

- Sec-WebSocket-Accept  
The response value computed by the server from the client’s Sec-WebSocket-Key. The server must send this header.

- Sec-WebSocket-Protocol  
Used to negotiate the application subprotocol: the client sends a list of supported protocols, and the server must respond with exactly one protocol name. If the server cannot support any of the protocols, the handshake fails immediately. The client may choose not to send a subprotocol, but once it does, the handshake will fail if the server cannot support any of them. This header is optional for the client.

- Sec-WebSocket-Extensions  
Used to negotiate the WebSocket extensions to use for this connection: the client sends the extensions it supports, and the server confirms support for one or more extensions by returning the same header. This header is optional for the client. If the server does not support any of them, the handshake will not fail, but no extensions can be used for this connection.

Negotiation happens during the handshake phase. After the handshake is complete, HTTP communication ends, and all subsequent full-duplex communication is managed by the WebSocket protocol (over TCP).


## V. WebSocket Protocol Extensions

The HyBi Working Group, which was responsible for defining the WebSocket specification, introduced two Sec-WebSocket-Extensions extensions:

- A Multiplexing Extension for WebSockets  
  This extension can separate WebSocket logical connections, allowing them to share the underlying TCP connection.

- Compression Extensions for WebSocket   
  Adds compression support to the WebSocket protocol. (For example, the x-webkit-deflate-frame extension.)

Without the multiplexing extension, each WebSocket connection can only exclusively use a dedicated TCP connection. Also, when a very large message is split into multiple frames, head-of-line blocking can easily occur. Head-of-line blocking increases latency, so when splitting a message into multiple frames, keeping the frames as small as possible is key. However, even after enabling multiplexing, where multiple connections share a single TCP connection, each channel can still suffer from head-of-line blocking. In addition to multiplexing, messages also need to be sent in parallel across multiple paths.

If WebSocket is transported over HTTP/2, performance can be somewhat better, since HTTP/2 natively supports stream multiplexing. By leveraging HTTP/2’s framing mechanism for WebSocket framing, multiple WebSocket connections can be transmitted within the same session.


## VI. WebSocket Data Frames

Another advanced component of WebSocket is its binary message framing mechanism. WebSocket splits application messages into one or more frames. The receiver reassembles multiple received frames and notifies the receiving endpoint only after the complete message has been received.

### WebSocket Data Frame Structure

The WebSocket data frame format is as follows:
```http
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+
```
- FIN: 0 indicates this is not the final fragment; 1 indicates this is the final fragment.

- RSV1, RSV2, RSV3:

Under normal circumstances, all are 0. When the client and server have negotiated a WebSocket extension, these three flags may be non-
zero, and the meaning of their values is defined by the extension. If a non-zero value appears and no WebSocket extension is in use, the connection is in error.

- Opcode:

%x0: Indicates a continuation frame. When Opcode is 0, it means this data transmission uses fragmentation, and the currently received data frame is one of the data fragments;  
%x1: Indicates this is a text frame;  
%x2: Indicates this is a binary frame;  
%x3-7: Reserved opcodes for non-control frames to be defined later;  
%x8: Indicates connection close;  
%x9: Indicates this is a heartbeat request (ping);  
%xA: Indicates this is a heartbeat response (pong);  
%xB-F: Reserved opcodes for control frames to be defined later.  

- Mask:

Indicates whether the data payload should be subjected to a **masking XOR** operation. 1 means required, 0 means not required. (This applies only to messages sent from the client to the server; **when the client sends a message to the server, this must be 1**.)

- Payload len:

Indicates the length of the data payload. There are 3 cases:

If the data length is between 0 and 125, then 7 bits for Payload len are sufficient, and the represented value is the payload length;    
If the data length is equal to 126, then Payload len must be represented using 7 + 16 bits, and the 16-bit unsigned integer represented by the next 2 bytes is the length of this frame;    
If the data length is equal to 127, then Payload len must be represented using 7 + 64 bits, and the 64-bit unsigned integer represented by the next 8 bytes is the length of this frame.    

- Masking-key:

If Mask = 0, there is no Masking-key. If Mask = 1, the Masking-key is 4 bytes, 32 bits, in length.

The masking key is a 32-bit value randomly selected by the client. When preparing a masked frame, the client must choose a new masking key from the set of allowed 32-bit values. The masking key needs to be unpredictable; therefore, it must come from a strong source of entropy, and the masking key used for a given frame must not be easy for the server/proxy to predict as the masking key for subsequent frames. The unpredictability of the masking key is necessary to prevent authors of malicious applications from choosing the bytes that appear on the wire. RFC 4086 [RFC4086] discusses what is required for an appropriate source of entropy for security-sensitive applications.

Masking does not affect the length of the “Payload data”. To transform masked data into unmasked data, or vice versa, the following algorithm is applied. The same algorithm is applied regardless of the direction of transformation; that is, the same steps are applied to both masked data and unmasked data.

- original-octet-i: The i-th byte of the original data.
- transformed-octet-i: The i-th byte of the transformed data.
- j: The result of i mod 4.
- masking-key-octet-j: The j-th byte of the mask key.

Octet i of the transformed data ("transformed-octet-i") is octet i of the original data ("original-octet-i") XORed with the octet of the masking key at position i modulo 4 ("masking-key-octet-j"):
```c
j = i MOD 4
transformed-octet-i = original-octet-i XOR masking-key-octet-j
```
Algorithm, in simple terms: perform a cyclic XOR operation byte by byte. First take the index of the byte modulo the length of the Masking-key to obtain the corresponding value x in the Masking-key, then XOR that byte with x to recover the real byte data.  

Note: the purpose of masking is not to prevent data leakage, but to prevent malicious scripts running in the client from carrying out proxy cache poisoning attacks against intermediaries that do not support WebSocket.

>For details about this attack, refer to the W2SP 2011 paper [Talking to Yourself for Fun and Profit](http://www.adambarth.com/papers/2011/huang-chen-barth-rescorla-jackson.pdf).
>

The attack mainly consists of two steps.

First, establish a WebSocket connection. The attacker performs a WebSocket handshake with their own server through a proxy server. Because the WebSocket handshake is an HTTP message, when the proxy server forwards the response from the attacker’s server back to the attacker, it considers the HTTP request complete.

![](https://img.halfrost.com/Blog/ArticleImage/83_9.png)

Second, perform the “poisoning” attack on the proxy server. Since the WebSocket handshake has succeeded, the attacker can now send data to their own server, including a carefully crafted text message in HTTP format. The host in this data must be forged as the server that an ordinary user is about to visit, and the requested resource must be the resource that the ordinary user is about to request. The proxy server will treat this as a new request and send it to the attacker’s own server. At this point, the attacker’s server must also cooperate: after receiving this “poisoning” message, it immediately returns the “poison”, such as malicious script resources. At this point, the “poisoning” succeeds.

![](https://img.halfrost.com/Blog/ArticleImage/83_10.png)


When a user requests the intended secure resource through the proxy server, the host and URL have already been cached in the proxy server by the attacker using the HTTP-formatted text message, and the “poisoned” resource has also been cached. At this point, when the user requests a resource with the same host and URL, the proxy cache server finds that it has already cached it and immediately returns the “poisoned” malicious script or resource to the user. The user has now been attacked.

Therefore, **when the client sends data to the server, it must include the Masking-key here, which is used to mark the Payload data (including both extension data and application data)**.

- Payload Data: 

Payload data is divided into two types: extension data and application data.

Extension data: If no extensions have been negotiated, the extension data is 0 bytes. If extension data has a length, that length must be fixed during the handshake phase. The length of the payload data must also include the extension data.

Application data: If extension data exists, application data follows after it.


### WebSocket Control Frames

Control frames are identified by opcodes whose most significant bit is 1. The currently defined opcodes for control frames include 0x8 (Close), 0x9 (Ping), and 0xA (Pong). Opcodes 0xB–0xF are reserved for future, currently undefined control frames.

Control frames are used to communicate WebSocket state. Control frames may be inserted in the middle of a fragmented message.

All control frames must have a payload length of 125 bytes or less, and control frames must not be fragmented.

- After receiving a control frame with the 0x8 Close opcode, the underlying TCP connection may be closed. The client may also wait for the server to close first, and then close its own TCP connection after some time without a response.

RFC6455 provides recommended status codes for closure. They are not formally defined as normative semantics; rather, it provides a set of predefined status codes.

| Status Code | Description | Reserved ✔︎ or Must Not Be Used ✖︎|
| :---: | :---: | :---:|
|0-999 |Status codes in this range are not used.|✖︎|
| 1000 |Indicates a normal closure, meaning that the intended connection has completed. ||
| 1001 |Indicates that an endpoint is “going away”, for example because the server is shutting down or the browser is navigating to another page.||
| 1002 |Indicates that an endpoint is terminating the connection due to a protocol error. ||
| 1003 |Indicates that an endpoint is terminating the connection because it received a type of data it cannot accept (for example, an endpoint that only understands text data received a binary message). ||
| 1004 |Reserved. Its specific meaning may be defined in the future. |✔︎|
| 1005 |This is a reserved value and must not be set as a status code by an endpoint in a Close control frame. It is designated for use in applications that expect a status code to indicate that no status code was actually present. |✔︎|
| 1006 |This is a reserved value and must not be set as a status code by an endpoint in a Close control frame. It is designated for use in applications that expect a status code to indicate that the connection was closed abnormally. |✔︎|
| 1007 |Indicates that an endpoint is terminating the connection because the data received in a message is inconsistent with the message type (for example, non-UTF-8 [RFC3629] data in a text message). ||
| 1008 |Indicates that an endpoint is terminating the connection because the received message violates its policy. This is a generic status code that can be returned when no other suitable status code is available (for example, 1003 or 1009), or when the specific details of the policy need to be hidden.||
| 1009 |Indicates that an endpoint is terminating the connection because the received message is too large for it to process. ||
| 1010 |Indicates that an endpoint (the client) is terminating the connection because it expected the server to negotiate one or more extensions, but the server did not return them in the WebSocket handshake response. The list of required extensions should appear in the reason portion of the Close frame. ||
| 1011 |Indicates that the server is terminating the connection because it encountered an unexpected condition that prevented it from fulfilling the request. ||
| 1012 | ||
| 1013 | ||
| 1014 | ||
| 1015 |This is a reserved value and must not be set as a status code by an endpoint in a Close frame. It is designated for use in applications that expect a status code to indicate that the connection was closed because the TLS handshake failed (for example, the server certificate could not be verified). |✔︎|
|1000-2999| Status codes in this range are reserved for this protocol, future revisions of it, and extensions specified in a permanent and readily available public specification.|✔︎|
|3000-3999 |Status codes in this range are reserved for use by libraries, frameworks, and applications. These status codes are registered directly with IANA. This specification does not define the interpretation of these status codes.|✔︎|
|4000-4999 |Status codes in this range are reserved for private use and therefore cannot be registered. These status codes may be used by prior agreements between WebSocket applications. This specification does not define the interpretation of these status codes.|✔︎|

- After receiving a control frame with the 0x9 Ping opcode, an endpoint should immediately send a frame containing the Pong opcode in response, unless it has received a Close frame. Either side may send Ping frames at any time after the connection is established and before it is closed. A Ping frame may contain “application data”. A Ping frame can be used as a keepalive heartbeat packet.

- After receiving a control frame with the 0xA Pong opcode, the endpoint knows that the peer is still responsive. A Pong frame must contain exactly the same application data as the Ping frame to which it is responding. If an endpoint receives a Ping frame and has not yet sent a Pong response for a previous Ping frame, the endpoint may choose to send a Pong frame for the most recently processed Ping frame. A Pong frame may be sent proactively as a one-way heartbeat. Try not to proactively send Pong frames.

### WebSocket Fragmentation Rules

Fragmentation rules are defined by RFC6455, and applications are unaware of how fragmentation is performed. Fragmentation is handled by the client and the server.

Fragmentation can also make better use of multiplexing protocol extensions. Multiplexing requires messages to be split into smaller fragments so that the output channel can be shared more effectively.

The fragmentation rules specified by RFC 6455 are as follows:

- An unfragmented message consists of a single frame with the FIN bit set and a non-zero opcode.
- A fragmented message consists of a single frame with the FIN bit cleared and a non-zero opcode, followed by zero or more frames with the FIN bit cleared and the opcode set to 0, and terminated by a frame with the FIN bit set and the opcode set to 0. Conceptually, a fragmented message is equivalent to a single large message whose payload is equivalent to the concatenation of the fragment payloads in order; however, in the presence of extensions, this may not apply depending on the interpretation of “extension data” defined by the extension. For example, “extension data” may exist only at the start of the first fragment and apply to subsequent fragments, or “extension data” may exist in each fragment and apply only to that specific fragment. In the absence of “extension data”, the following example shows how fragmentation works.

Example: For a text message sent as three fragments, the first fragment has opcode 0x1 and the FIN bit cleared, the second fragment has opcode 0x0 and the FIN bit cleared, and the third fragment has opcode 0x0 and the FIN bit set. (The 0x0 opcode was explained above and indicates a continuation frame. When the opcode is 0x0, it means this data transfer uses data fragmentation, and the currently received data frame is one of the data fragments.)

- Control frames may be injected in the middle of a fragmented message. Control frames themselves must not be fragmented.
- Message fragments must be delivered to the recipient in the order in which they were sent by the sender.
- The fragments of one message must not be interleaved with the fragments of another message unless an extension capable of interpreting the interleaving has been negotiated.
- An endpoint must be able to handle control frames in the middle of a fragmented message.
- A sender may create fragments of any size for non-control messages.
- Clients and servers must support receiving both fragmented and unfragmented messages.
- Since control frames cannot be fragmented, an intermediary must not attempt to change the fragmentation of a control frame.
- If any reserved bit values are used and the meaning of those values is unknown to the intermediary, the intermediary must not change the fragmentation of a message.
- In the context of a connection where extensions have been negotiated and the intermediary does not know the semantics of the negotiated extensions, the intermediary must not change the fragmentation of any message. Likewise, an intermediary that did not see the WebSocket handshake (and was not informed of its contents) leading to a WebSocket connection must not change the fragmentation of any message on that connection.
- Because of these rules, all fragments of a message are of the same type, as determined by the opcode set in the first fragment. Since control frames cannot be fragmented, the type used for all fragments of a message must be either text, binary, or a reserved opcode.

Note: If control frames could not be inserted, the delay for a Ping, for example, would be very long if it followed a large message. Therefore, control frames must be processed in the middle of a fragmented message.

Implementation note: In the absence of any extensions, a receiver does not need to buffer the entire frame in order before processing it. For example, if a streaming API is used, part of a frame can be delivered to the application. However, note that this assumption may not hold for all future WebSocket extensions.

### WebSocket Fragmentation Overhead

A fragmented message consists of: starting with a single frame where FIN is set to 0 and opcode is non-zero; followed by 0 or more frames where FIN is set to 0 and opcode is set to 0; and ending with a single frame where FIN is set to 1 and opcode is set to 0. Conceptually, a fragmented message is equivalent to one large unfragmented message, whose payload length is the sum of the payload lengths of all frames. However, when extensions are present, this may not be true, because the extension defines the interpretation of the Extension data that appears. For example, Extension data may appear only in the first frame and apply to all subsequent frames, or Extension data may appear in every frame and apply only to that specific frame.

>Frame: the smallest unit of communication, consisting of a variable-length frame header and a payload portion; the payload may contain a complete or partial application message.
>
>Message: a sequence of frames, corresponding to an application message.

Generally speaking, server-side fragmentation has three types of frames: start frames, intermediate frames, and end frames. Start frames and end frames may or may not carry data. **The overhead of fragmentation is mainly incurred by the newly added frame header information**. The overhead size is 1 + 3 + 4 + 1 + 7 + 0 = 16 bits = 2 bytes. For an intermediate frame that carries data, the overhead size is 1 + 3 + 4 + 1 + 7 + 64 = 80 bits = 10 bytes (assuming the data length is 127 bits, so payload len needs to add 64 bits).

The server-side fragmentation overhead ranges from [2,10] bytes. The client needs to include the Masking-key in addition to what the server uses, which occupies 4 bytes (32 bits), so client-side fragmentation overhead ranges from [6,14] bytes.


## VII. WebSocket API and Data Formats

### 1. WebSocket API


The WebSocket API is extremely concise; there are only the following callable functions:

```javascript
var ws = new WebSocket('wss://example.com/socket');
ws.onerror = function (error) { ... }
ws.onclose = function () { ... }
ws.onopen = function () {
ws.send("Connection established. Hello server!");
}
ws.onmessage = function(msg) {
	if(msg.data instanceof Blob) {
   		processBlob(msg.data);
  	} else {
       processText(msg.data);
   }
}
```
Aside from creating a new WebSocket object and the `send()` method, the remaining pieces are the four callback methods.

Among the methods mentioned above, one thing to pay particular attention to with `send()` is that it is asynchronous, not synchronous. This means that when we pass the content to be sent into this function, the function returns asynchronously; at that point, **do not mistakenly assume that the data has already been sent**. WebSocket itself has a queuing mechanism: data is first placed into a data buffer, and then sent in queued order.

If a huge file is in the queue, and some messages with higher priority arrive afterward—for example, a system error that requires the connection to be closed immediately—then because those messages are queued behind the large file, they must wait until the large file has finished sending before they can be sent. This creates a head-of-line blocking problem, causing higher-priority messages to be delayed.

The designers of the WebSocket API took this issue into account, so they gave us two of the very few properties that can change the behavior of a WebSocket object: `bufferedAmount` and `binaryType`.
```javascript
if (ws.bufferedAmount == 0)
    ws.send(evt.data);
```
In the scenario described above, you can use bufferedAmount to monitor the amount of data in the buffer, thereby avoiding head-of-line blocking. Going a step further, you can also combine it with a Priority Queue to send messages according to priority.


### 2. Data Format

WebSocket imposes no restrictions on the format of transmitted data; it can be either text or binary. The protocol uses the Opcode field to distinguish between UTF-8 and binary data. The WebSocket API can accept UTF-8 encoded DOMString objects, as well as binary data such as ArrayBuffer, ArrayBufferView, or Blob.

For data received by the browser, if no other options are set manually, the default handling is as follows: text is converted to a DOMString object by default, while binary data or Blob objects are passed directly to the application without any intermediate processing.
```javascript
var ws = new WebSocket('wss://example.com/socket'); 
ws.binaryType = "arraybuffer";
```
The only place where you can intervene is to force all received binary data to be converted to the arraybuffer type rather than the Blob type. As for why it should be converted to arraybuffer, the W3C Candidate Recommendation gives the following guidance:

>User agents can use this option as a hint to decide how to handle received binary data: if it is set to “blob”, it is safe to spool it to disk; if it is set to “arraybuffer”, it is likely more efficient to process it in memory. Naturally, user agents are encouraged to use more subtle cues to decide whether incoming data should be kept in memory.
>
>——The WebSocket API W3C Candidate Recommendation


Simply put: if it is converted into a Blob object, it represents an immutable file object or raw data. If you do not need to modify it or split it, keeping it as a Blob object is a good choice. If you need to process this raw data, it is clearly more appropriate to put it in memory, so you should convert it to arraybuffer.


## VIII. WebSocket Performance and Use Cases

Here is a test from WebSocket.org comparing XHR polling with WebSocket:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/8_5.png'>
</p>

In the figure above, let’s first look at the blue bars, which represent the traffic consumed by Polling. In this test, the total overhead of the HTTP request and response headers is 871 bytes. Of course, different requests in different tests have different header overhead. This test uses requests with 871 bytes of overhead.

**Use case A**: 1,000 clients polling every second: Network throughput is (871 x 1,000) = 871,000 bytes = 6,968,000 bits per second (6.6 Mbps)  
**Use case B**: 10,000 clients polling every second: Network throughput is (871 x 10,000) = 8,710,000 bytes = 69,680,000 bits per second (66 Mbps)  
**Use case C**: 100,000 clients polling every 1 second: Network throughput is (871 x 100,000) = 87,100,000 bytes = 696,800,000 bits per second (665 Mbps)  
By contrast, a WebSocket frame has just two bytes of overhead instead of 871—only 2 bytes replace the 871 bytes required by polling!

**Use case A**: 1,000 clients receive 1 message per second: Network throughput is (2 x 1,000) = 2,000 bytes = 16,000 bits per second (0.015 Mbps)  
**Use case B**: 10,000 clients receive 1 message per second: Network throughput is (2 x 10,000) = 20,000 bytes = 160,000 bits per second (0.153 Mbps)  
**Use case C**: 100,000 clients receive 1 message per second: Network throughput is (2 x 100,000) = 200,000 bytes = 1,600,000 bits per second (1.526 Mbps)  

With the same number of client polling operations per second, when the frequency reaches as high as 100K/s, Polling consumes 665 Mbps, while WebSocket uses only 1.526 Mbps—nearly 435 times less!

Judging from the results, WebSocket is indeed much better than polling in both efficiency and network bandwidth consumption.


In terms of use cases, XHR, SSE, and WebSocket each have their own advantages and disadvantages.

XHR is simpler than the other two approaches and, relying on HTTP’s mature infrastructure, is easy to implement. However, it does not support request streams, and its support for response streams is not perfect either (it requires support for the Streams API to support response streams). In terms of data formats, it supports both text and binary, and also supports compression. HTTP is responsible for framing its messages.


SSE also does not support request streams. After a single handshake, the server can send data to the client as a response stream using the event source protocol. SSE supports only text data and cannot support binary data. Because SSE was not designed for transmitting binary data, if necessary, binary objects can be encoded as base64 and then transmitted via SSE. SSE also supports compression, and the event stream is responsible for framing it.

WebSocket is currently the only full-duplex protocol implemented over the same TCP connection, with excellent support for both request streams and response streams. It supports text and binary data, and has built-in binary framing. Its compression support is somewhat weaker, because some mechanisms are not supported—for example, the x-webkit-deflate-frame extension. In the ws request mentioned earlier in this article, the server did not support compression.

Of course, it would be best if every network environment supported WebSocket or SSE. But that is unrealistic. Network environments vary widely; some networks may block WebSocket communication, or a user’s device may not support the WebSocket protocol. That is where XHR still has a role to play.

If the client does not need to send messages to the server and only needs continuous real-time updates, then SSE is also a good option. However, SSE currently has poor support in IE and Edge. WebSocket is stronger than SSE in this respect.

Therefore, different protocols should be chosen for different scenarios, taking advantage of each one’s strengths.

------------------------------------------------------

Reference:  

[RFC6455](https://tools.ietf.org/html/rfc6455)    
[Server-Sent Events Tutorial](http://www.ruanyifeng.com/blog/2017/05/server-sent_events.html)    
[Comet: HTTP Long-Connection-Based “Server Push” Technology](https://www.ibm.com/developerworks/cn/web/wa-lo-comet/)    
[High Performance Browser Networking]()  
[What is Sec-WebSocket-Key for?](https://stackoverflow.com/questions/18265128/what-is-sec-websocket-key-for)     
[10.3. Attacks On Infrastructure (Masking)](https://tools.ietf.org/html/rfc6455#section-10.3)    
[Why are WebSockets masked?](https://stackoverflow.com/questions/33250207/why-are-websockets-masked)    
[How does websocket frame masking protect against cache poisoning?](https://security.stackexchange.com/questions/36930/how-does-websocket-frame-masking-protect-against-cache-poisoning)    
[What is the mask in a WebSocket frame?](https://stackoverflow.com/questions/14174184/what-is-the-mask-in-a-websocket-frame)     

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [www.halfrost.com/websocket/](www.halfrost.com/websocket/)