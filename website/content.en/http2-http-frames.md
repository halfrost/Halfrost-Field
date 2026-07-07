+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-04-21T06:57:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/125_0.png"
slug = "http2-http-frames"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "HTTP Frames and Stream Multiplexing in HTTP/2"

+++


In the previous article, we covered how HTTP/2 establishes a connection. Starting with this article, we will discuss the frame structure. Once an HTTP/2 connection has been established, endpoints can begin exchanging frames.

## I. Frame Format

HTTP/2 sends binary frames of different types, but they all share the following common fields: Type, Length, Flags, Stream Identifier, and frame payload. The specification defines a total of 10 different frame types, with the two most fundamental ones corresponding to DATA and HEADERS in HTTP/1.1.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_2.png'>
</p>


All frames begin with a fixed 9-byte header, followed by a variable-length payload.
```c
    +-----------------------------------------------+
    |                 Length (24)                   |
    +---------------+---------------+---------------+
    |   Type (8)    |   Flags (8)   |
    +-+-------------+---------------+-------------------------------+
    |R|                 Stream Identifier (31)                      |
    +=+=============================================================+
    |                   Frame Payload (0...)                      ...
    +---------------------------------------------------------------+
```
The fields in the frame header are defined as follows:

- Length：  
  The length of the frame payload, represented as an unsigned 24-bit integer. Unless the receiver has set a larger value for SETTINGS\_MAX\_FRAME\_SIZE (see [here](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) for details), values greater than 2 ^ 14 (16,384) MUST NOT be sent. **The 9 octets of the frame header are not included in this length value**.
  
- Type：  
  These 8 bits indicate the frame type. The frame type determines the frame’s format and semantics. Implementations MUST ignore and discard frames of any unknown type.
  
- Flags：  
  This field is an 8-bit field reserved for boolean flags specific to the frame type. Flags are assigned semantics specific to the indicated frame type. Flags for which no semantics are defined for a particular frame type MUST be ignored, and MUST remain unset (0x0) when sent.
  
>Commonly used flags include END\_HEADERS, which indicates the end of header data and is equivalent to the blank line after headers in HTTP/1 (“\r\n”), and END\_STREAM, which indicates the end of data transmission in one direction (that is, EOS, End of Stream), equivalent to the end marker for Chunked transfer encoding in HTTP/1 (“0\r\n\r\n”).


  
- R：  
  A reserved 1-bit field. The semantics of this bit are undefined; it MUST remain unset (0x0) when sent and MUST be ignored when received.

- Stream Identifier：  
  The stream identifier (see [Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)), represented as an unsigned 31-bit integer. The value 0x0 is reserved for frames associated with the connection as a whole, rather than with an individual stream.
  
The structure and content of a frame payload depend entirely on the frame type.


Let’s inspect what an actual frame header looks like in a packet capture. Here we pick an arbitrary frame type, for example a SETTINGS frame:

![](https://img.halfrost.com/Blog/ArticleImage/124_3_0.png)

The frame structure shown in the packet capture confirms that the header is indeed the first 9 bytes. Length is 18, Type is 4, the Flags field is marked ACK, R is the reserved bit, corresponding to Reserved in the capture above, and Stream Identifier is 0.

## II. Frame Size

The size of a frame payload is limited by the maximum size advertised by the receiver in the SETTINGS\_MAX\_FRAME\_SIZE setting. This setting can contain any value between 2^14 (16,384) and 2^24-1 (16,777,215) octets.

All implementations MUST be able to receive and at least process frames with a payload length of 2^14 octets, plus the 9-octet frame header. The frame header size is not included when describing frame size.

> Note: Some frame types, such as PING ([Section 6.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%83-ping-%E5%B8%A7)), impose additional restrictions on the amount of payload data allowed.

If a frame exceeds the size defined by SETTINGS\_MAX\_FRAME\_SIZE, exceeds any limit defined for the frame type, or is too small to contain mandatory frame data, the endpoint MUST send the error code FRAME\_SIZE\_ERROR. A frame size error in a frame that could change the state of the entire connection MUST be treated as a connection error ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)); this includes any frame carrying a header block ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)) (that is, HEADERS, PUSH\_PROMISE, and CONTINUATION), SETTINGS, and any frame with a stream identifier of 0.

Endpoints are not obligated to use all available space in a frame. Responsiveness can be improved by using frames smaller than the permitted maximum size. Sending large frames can delay the transmission of time-sensitive frames, such as RST\_STREAM, WINDOW\_UPDATE, or PRIORITY; if those frames are blocked by transmission of a large frame, performance is affected.


## III. Header Compression and Decompression

As in HTTP/1, header fields in HTTP/2 are names with one or more associated values. Header fields are used in HTTP request and response messages, as well as in server push operations (see [Section 8.2]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%BA%8C-server-push))).

A header list is a collection of zero or more header fields. When transmitted over a connection, the header list is serialized into a header block using HTTP header compression [COMPRESSION]. The serialized header block is then split into one or more octet sequences, called header block fragments, and sent in the payload of HEADERS ([Section 6.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7)), PUSH\_PROMISE ([Section 6.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)）or CONTINUATION ([Section 6.10](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7)) frames.

The Cookie field [COOKIE] in headers is handled specially by the HTTP mapping (see [Section 8.1.2.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)).

The receiving endpoint reassembles a header block by concatenating its fragments, then decompresses the block to reconstruct the header list. A complete header block consists of either:  

- A single HEADERS or PUSH\_PROMISE frame with the END\_HEADERS flag set.

- A HEADERS or PUSH\_PROMISE frame with the END\_HEADERS flag cleared, followed by one or more CONTINUATION frames, where the last CONTINUATION frame has the END\_HEADERS flag set.

Header compression is stateful. One compression context and one decompression context are used for the entire connection. A decoding error in a header block MUST be treated as a connection error of type COMPRESSION\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

Each header block is processed as a discrete unit. A header block MUST be transmitted as a contiguous sequence of frames, with no interleaved frames of any other type and no frames from any other stream. The last frame in a HEADERS or CONTINUATION frame sequence has the END\_HEADERS flag set. The last frame in a PUSH\_PROMISE or CONTINUATION frame sequence has the END\_HEADERS flag set. This allows a header block to be logically equivalent to a single frame.

**Header block fragments can only be sent as the payload of HEADERS, PUSH\_PROMISE, or CONTINUATION frames**, because the data carried by these frames can modify the compression context maintained by the receiver. An endpoint receiving a HEADERS, PUSH\_PROMISE, or CONTINUATION frame needs to reassemble the header block and perform decompression, even if the frame is to be discarded. If the receiver does not decompress the header block, it MUST terminate the connection with a connection error of type COMPRESSION\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


## IV. Stream State Machine

![](https://img.halfrost.com/Blog/ArticleImage/125_1.png)

A stream is an independent, bidirectional sequence of frames exchanged between the client and server within an HTTP/2 connection. Streams have several important characteristics:     

- A single HTTP/2 connection can contain multiple concurrently open streams, and either endpoint may receive frames from multiple streams interleaved with one another.
- Streams can be established and used unilaterally, or they can be shared by the client and server.
- Either endpoint can close a stream.
- The order in which frames are sent on a stream is very important. Recipients process frames in the order in which they are received. In particular, the order of HEADERS and DATA frames is semantically significant.
- Streams are identified by integers. The stream identifier is assigned to the stream by the endpoint that initiates the stream.

The lifecycle of a stream is shown below:
```c
                                +--------+
                        send PP |        | recv PP
                       ,--------|  idle  |--------.
                      /         |        |         \
                     v          +--------+          v
              +----------+          |           +----------+
              |          |          | send H /  |          |
       ,------| reserved |          | recv H    | reserved |------.
       |      | (local)  |          |           | (remote) |      |
       |      +----------+          v           +----------+      |
       |          |             +--------+             |          |
       |          |     recv ES |        | send ES     |          |
       |   send H |     ,-------|  open  |-------.     | recv H   |
       |          |    /        |        |        \    |          |
       |          v   v         +--------+         v   v          |
       |      +----------+          |           +----------+      |
       |      |   half   |          |           |   half   |      |
       |      |  closed  |          | send R /  |  closed  |      |
       |      | (remote) |          | recv R    | (local)  |      |
       |      +----------+          |           +----------+      |
       |           |                |                 |           |
       |           | send ES /      |       recv ES / |           |
       |           | send R /       v        send R / |           |
       |           | recv R     +--------+   recv R   |           |
       | send R /  `----------->|        |<-----------'  send R / |
       | recv R                 | closed |               recv R   |
       `----------------------->|        |<----------------------'
                                +--------+

          send:   endpoint sends this frame
          recv:   endpoint receives this frame

          H:  HEADERS frame (with implied CONTINUATIONs)
          PP: PUSH_PROMISE frame (with implied CONTINUATIONs)
          ES: END_STREAM flag
          R:  RST_STREAM frame
```
Please note that this diagram shows stream state transitions and the frames and flags that affect only those transitions. In this respect, CONTINUATION frames do not cause state transitions; they are effectively part of the HEADERS or PUSH\_PROMISE they follow.


For the purposes of state transitions, for frames carrying the END\_STREAM flag, that flag is treated as a separate event; a HEADERS frame with the END\_STREAM flag set can cause two state transitions.

Both endpoints have a subjective view of the state of a stream, and these two views can differ while frames are in transit. Endpoints do not coordinate stream creation; streams are created unilaterally by either endpoint. The negative consequences of state mismatches are limited to the “closed” state after an RST\_STREAM has been sent, where frames might still be received for some time after closure.

A stream has the following states:

### idle:    
  All streams start in the idle state. The following transitions are valid in this state:  
 - Sending or receiving a HEADERS frame causes the stream to become open. The stream identifier is selected as described in [Section 5.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6). The same HEADERS frame can also cause the stream to immediately become half-closed.

 - Sending a PUSH\_PROMISE frame on another stream reserves an idle stream for later use. The reserved stream transitions to the "reserved (local)" state.

 - Receiving a PUSH\_PROMISE frame on another stream reserves an idle stream that is identified for later use. The reserved stream transitions to the "reserved (remote)" state.

 - Note that a PUSH\_PROMISE frame is not sent on the idle stream; instead, it references the newly reserved stream in the Promised Stream ID field.

Receiving any frame other than HEADERS or PRIORITY on a stream in this state MUST be treated as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### reserved (local):   

A stream in the "reserved (local)" state is one for which a PUSH\_PROMISE frame has been sent. The PUSH\_PROMISE frame reserves an idle stream by associating it with an open stream initiated by the remote peer (see [Section 8.2]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%BA%8C-server-push))). In this state, the following transitions are valid:  
 
- The endpoint can send a HEADERS frame. This causes the stream to open in the "half-closed (remote)" state.
- Either endpoint can send an RST\_STREAM frame to cause the stream to become "closed". This releases the stream reservation.
   
In this state, an endpoint MUST NOT send any type of frame other than HEADERS, RST\_STREAM, or PRIORITY. PRIORITY or WINDOW\_UPDATE frames can be received in this state. Receiving any type of frame other than RST\_STREAM, PRIORITY, or WINDOW\_UPDATE on a stream in this state MUST be treated as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### reserved (remote):   

A stream in the "reserved (remote)" state has been reserved by the remote peer. In this state, the following transitions are valid:  
 
- Receiving a HEADERS frame causes the stream to transition to "half-closed (local)".  
- Either endpoint can send an RST\_STREAM frame to cause the stream to become "closed". This releases the stream reservation.

An endpoint can send a PRIORITY frame in this state to reprioritize the reserved stream. In this state, an endpoint MUST NOT send any type of frame other than RST\_STREAM, WINDOW\_UPDATE, or PRIORITY. Receiving any type of frame other than HEADERS, RST\_STREAM, or PRIORITY on a stream in this state MUST be treated as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### open:    

Both communicating peers can use a stream in the "open" state to send any type of frame. In this state, the sender needs to observe the agreed stream-level flow-control limits ([Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)).

From this state, either endpoint can send a frame with the END\_STREAM flag set, which causes the stream to transition to one of the "half-closed" states. For the endpoint that sends the END\_STREAM flag, the stream state becomes "half-closed (local)"; for the endpoint that receives the END\_STREAM flag, the stream state becomes "half-closed (remote)".

Either endpoint can send an RST\_STREAM frame from this state, causing it to immediately transition to "closed".


### half-closed (local):  

A stream in the "half-closed (local)" state cannot be used to send frames other than WINDOW\_UPDATE, PRIORITY, and RST\_STREAM.

When a frame containing the END\_STREAM flag is received, or when either peer sends an RST\_STREAM frame, the stream transitions from this state to "closed".

An endpoint can receive any type of frame in this state. Providing flow-control credit using WINDOW\_UPDATE frames is necessary to continue receiving flow-controlled frames. In this state, the receiver can ignore WINDOW\_UPDATE frames because these frames may arrive shortly after a frame with the END\_STREAM flag has been sent.

A PRIORITY frame received in this state is used to reprioritize streams that depend on the identified stream.


### half-closed (remote):   

The peer no longer uses a "half-closed (remote)" stream to send frames. In this state, the endpoint is no longer responsible for maintaining the receiver flow-control window.

If an endpoint receives frames other than WINDOW\_UPDATE, PRIORITY, or RST\_STREAM for a stream in this state, it MUST respond with a stream error of type STREAM\_CLOSED ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

An endpoint can use a "half-closed (remote)" stream to send any type of frame. In this state, the endpoint continues to observe the agreed stream-level flow-control limits ([Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)).

By sending a frame containing the END\_STREAM flag, or when either peer sends an RST\_STREAM frame, the stream can transition from this state to "closed".


### closed:

The "closed" state is the terminal state.

An endpoint MUST NOT send frames other than PRIORITY on a closed stream. An endpoint that receives any frame other than PRIORITY after receiving RST\_STREAM MUST treat it as a stream error of type STREAM\_CLOSED ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Similarly, an endpoint that receives any frame after receiving a frame with the END\_STREAM flag MUST treat it as a connection error of type STREAM\_CLOSED ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)), unless that frame is permitted as described below.

After sending a DATA or HEADERS frame containing the END\_STREAM flag, WINDOW\_UPDATE or RST\_STREAM frames can be received in this state for a short period of time. The remote peer might send these types of frames before it receives and processes the RST\_STREAM or the frame with the END\_STREAM flag. An endpoint MUST ignore WINDOW\_UPDATE or RST\_STREAM frames received in this state, although an endpoint treats frames that arrive a long time after sending END\_STREAM has been processed as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).

PRIORITY frames can be sent on a closed stream to prioritize streams that depend on the closed stream. An endpoint SHOULD process PRIORITY frames, but it can ignore them if the stream has been removed from the dependency tree (see [Section 5.3.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#4-%E4%BC%98%E5%85%88%E7%BA%A7%E7%9A%84%E7%8A%B6%E6%80%81%E7%AE%A1%E7%90%86)).
If the closed state is reached as a result of sending an RST\_STREAM frame, the peer that receives the RST\_STREAM may already have sent—or have queued for sending—frames on the stream that cannot be withdrawn. An endpoint MUST ignore frames that it receives on a closed stream after sending an RST\_STREAM frame. An endpoint MAY choose to limit the period during which it ignores such frames and treat frames that arrive after that time as an error.

Flow-controlled frames (for example, DATA) received after sending RST\_STREAM are counted against the connection flow-control window. Even though these frames may be ignored, they were sent before the sender received the RST\_STREAM, so the sender will have accounted for them against the flow-control window.

An endpoint may receive a PUSH\_PROMISE frame after sending RST\_STREAM. Even if the associated stream has been reset, the PUSH\_PROMISE causes the promised stream to enter the “reserved” state. Therefore, an RST\_STREAM is required to close an unwanted stream.

If there is no more specific guidance elsewhere in this document, an implementation SHOULD treat the receipt of a frame that is not explicitly allowed in the state description as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). Note that PRIORITY frames can be sent and received in any stream state. Frames of unknown types are ignored.


### 1. Stream Identifiers


Streams are identified using unsigned 31-bit integers. **Streams initiated by the client MUST use odd-numbered stream identifiers**; **those initiated by the server MUST use even-numbered stream identifiers**. **Stream identifier zero (0x0) is used for connection control messages**; the zero stream identifier MUST NOT be used to establish a new stream.

In summary, the role of the stream ID is:

- It is the key to implementing multiplexing. The receiver’s implementation can use this ID to assemble messages concurrently. Frames within the same stream MUST be ordered. SETTINGS\_MAX\_CONCURRENT\_STREAMS controls the maximum concurrency.

![](https://img.halfrost.com/Blog/ArticleImage/130_3.svg)

Because the native WebSocket protocol does not have a field similar to this stream ID, it does not natively support multiplexing. Since frames within the same stream have no other ID number, they cannot be reordered; they must remain ordered and cannot be processed concurrently (if concurrency is desired, a new stream can be opened).

- It is the key to pushing dependent requests. Client-initiated streams are odd-numbered, while server-initiated streams are even-numbered.

![](https://img.halfrost.com/Blog/ArticleImage/130_4.svg)

- It imposes constraints for stream state management. The rules are described in the following paragraphs:

An HTTP/1.1 request upgraded to HTTP/2 using the "h2c" mechanism (see [Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-begin.md#2-starting-http2-for-http-uris)) is responded to on stream identifier 1 (0x1). After the upgrade is complete, the client’s stream 0x1 is in the "half-closed (local)" state. Therefore, a client upgraded from HTTP/1.1 cannot choose stream 0x1 as a new stream identifier.

The identifier of a newly established stream MUST be numerically greater than all streams that the initiating endpoint has opened or reserved. This governs streams opened with HEADERS frames and streams reserved with PUSH\_PROMISE. An endpoint that receives an unexpected stream identifier MUST treat it as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))

The first use of a new stream identifier implicitly closes all streams in the “idle” state that might have been initiated by the peer with lower-valued stream identifiers. For example, if a client sends a HEADERS frame on stream 7 without having sent any frames on stream 5, then stream 5 transitions to the “closed” state when the first frame for stream 7 is sent or received.

Stream identifiers cannot be reused. Long-lived connections can cause an endpoint to exhaust the available range of stream identifiers. A client that cannot establish a new stream identifier can establish a new connection for new streams. A server that cannot establish a new stream identifier can send a GOAWAY frame to force the client to open a new connection for new streams.


### 2. Stream Concurrency

Stream multiplexing means that packets from multiple streams in the same connection are interleaved. It is as if two (or more) independent “data trains” were spliced into a single train, but they will ultimately be separated again at the terminal station. The following diagram shows an example of two “data trains”:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_3.jpg'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_4.jpg'>
</p>

This is how they are assembled into the same train through multiplexing.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/125_5.jpg'>
</p>

A peer can use the SETTINGS\_MAX\_CONCURRENT\_STREAMS parameter in the SETTINGS frame (see [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)) to limit the number of concurrent active streams. Each endpoint has its own maximum concurrent streams setting, and this setting applies only to the peer that receives it. In other words, the client specifies the maximum number of concurrent streams that the server can initiate, and the server specifies the maximum number of concurrent streams that the client can initiate.

Streams in the “open” state or in either of the “half-closed” states count toward the maximum number of streams an endpoint is allowed to open. Streams in any of these three states count against the limit advertised in the SETTINGS\_MAX\_CONCURRENT\_STREAMS setting. Streams in any “reserved” state do not count against the stream limit.

An endpoint MUST NOT exceed the limit set by its peer. An endpoint that exceeds its advertised concurrent stream limit as a result of receiving a HEADERS frame MUST treat this as a stream error of type PROTOCOL\_ERROR or REFUSED\_STREAM ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)). The choice of error code determines whether the endpoint wishes to enable automatic retry (see [Section 8.1.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2) for details).

An endpoint that wishes to reduce the value of SETTINGS\_MAX\_CONCURRENT\_STREAMS below the current number of open streams can close streams that exceed the new value, or allow those streams to complete and close on their own.


## V. Flow Control

Using streams for multiplexing introduces contention for the TCP connection, which can cause streams to be blocked. The flow-control scheme ensures that streams on the same connection do not destructively interfere with each other. Flow control is used for both individual streams and the entire connection.

> Because HTTP/2 data streams are multiplexed within a single TCP connection, TCP flow control is neither fine-grained enough nor able to provide the necessary application-level APIs for regulating the transmission of individual data streams. To address this, HTTP/2 provides a simple set of building blocks that allow clients and servers to implement their own stream-level and connection-level flow control.
> 
> 

HTTP/2 provides flow control through the use of WINDOW\_UPDATE frames ([Section 6.9](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7)).

### 1. Flow-Control Principles

HTTP/2 stream flow control is designed to allow a variety of flow-control algorithms to be used without requiring protocol changes. Flow control in HTTP/2 has the following characteristics:

1. Flow control is specific to a single connection. Both types of flow control operate between endpoints on a single hop, not across the entire end-to-end path. That is, trusted network intermediaries can use it to control resource usage and implement resource allocation mechanisms based on their own conditions and heuristics.
2. Flow control is based on WINDOW\_UPDATE frames. Receivers advertise how many octets they are prepared to receive on a stream and on the entire connection. This is a credit-based scheme. The receiver sets the upper bound, and the sender should follow the receiver’s instructions.
3. Flow control is directional, and the receiver provides overall control. The receiver can choose any desired window size for each stream and for the entire connection. The sender MUST respect the flow-control limits imposed by the receiver. Clients, servers, and intermediaries, as receivers, all need to independently advertise their flow-control windows and comply with the flow-control limits set by their peers when sending.
4. For a new stream and for the overall connection, the initial value of the flow-control window is 65,535 octets.
5. The frame type determines whether flow control applies to the frame. Among the frames specified in this document, **only DATA frames are subject to flow control**; all other frame types do not consume space when their flow-control window is advertised. This ensures that important control frames are not blocked by flow control.
6. **Flow control cannot be disabled**. After an HTTP/2 connection is established, the client exchanges SETTINGS frames with the server, which sets the flow-control window in both directions. The default value of the flow-control window is 65,535 bytes, but the receiver can set a larger maximum window size (2^31-1 bytes) and maintain that size by sending WINDOW\_UPDATE frames whenever data is received.
7. HTTP/2 defines only the format and semantics of the WINDOW\_UPDATE frame ([Section 6.9](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7)). This document does not specify how a receiver decides when to send this frame or what value it sends, nor does it specify how a sender chooses to send data packets. Implementations can choose any algorithm that fits their needs.


> Both servers and clients have flow-control capabilities; flow control for sending and receiving can be configured independently.
> 


Implementations are also responsible for managing how requests and responses are sent based on priority, choosing how to avoid head-of-line blocking of requests, and managing the creation of new streams. The choice of these algorithms can interact with the flow-control algorithm.


### 2. Appropriate Use of Flow Control

> HTTP/2 does not specify any particular algorithm for implementing flow control.
Flow control is intended to protect endpoints operating under resource constraints. For example, a proxy needs to share memory across many connections, and it may also have slower upstream connections and faster downstream connections. Flow control addresses the case where a receiver cannot process data on one stream but wants to continue processing other streams on the same connection.

Deployments that do not need this capability can advertise the maximum flow-control window size (2^31-1), and can maintain this window by sending WINDOW\_UPDATE frames whenever any data is received. This effectively disables flow control for that receiver. Conversely, a sender always obeys the flow-control window advertised by the receiver.

Deployments with constrained resources (for example, memory) can use flow control to limit the amount of memory a peer might consume. Note, however, that enabling flow control without knowing the bandwidth-delay product can result in suboptimal use of available network resources (see [[RFC7323]](https://tools.ietf.org/html/rfc7323)).

Even with full knowledge of the current bandwidth-delay product, implementing flow control is difficult. When flow control is used, the receiver must read from the TCP receive buffer in a timely manner. Failing to read and process critical frames (such as WINDOW\_UPDATE) can result in deadlock.

## 6. Stream Priority

A client can assign a priority to a new stream by including priority information in the HEADERS frame ([Section 6.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7)) that opens the stream. At any other time, a PRIORITY frame ([Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E4%B8%89-priority-%E5%B8%A7)) can be used to change a stream's priority.

The purpose of prioritization is to allow an endpoint to express how it would like its peer to allocate resources when managing concurrent streams. Most importantly, when send capacity is limited, priority can be used to select the stream for sending frames.

A stream can be prioritized by marking it as dependent on the completion of other streams ([Section 5.3.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-stream-%E4%BE%9D%E8%B5%96)). Each dependency is assigned a relative weight, and that number is used to determine the relative proportion of available resources allocated to streams that depend on the same stream.

Explicitly setting a stream's priority participates in the prioritization process. However, it does not guarantee any particular processing or transmission order for that stream relative to any other stream. An endpoint cannot force its peer to use priority to process concurrent streams in a specific order. Therefore, expressed priority is only a suggestion. Priority information can be omitted from messages. Default values are used until any explicit values are provided ([Section 5.3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)).

### 1. Stream Dependencies

Each stream can be given an explicit dependency on another stream. Including a dependency represents a preference to allocate resources to the identified stream rather than to the dependent stream. A stream that does not depend on any other stream has a stream dependency of 0x0. In other words, the nonexistent stream 0 forms the root of the tree.

A stream that depends on another stream is a dependent stream. The stream on which it depends is the parent stream. A dependency on a stream that is not currently in the tree—for example, a stream in the “idle” state—causes that stream to be assigned the default priority ([Section 5.3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)).

When assigning a dependency on another stream, the stream is added as a new dependency of the parent stream. Dependent streams that share the same parent are not ordered relative to one another. For example, if streams B and C depend on stream A, and stream D is created with a dependency on stream A, this results in a dependency order of A, followed by B, C, and D, where the order of B, C, and D is arbitrary.
```c
       A                 A
      / \      ==>      /|\
     B   C             B D C
```
The exclusive flag allows inserting a new level of dependencies. The exclusive flag makes a stream the sole dependency of its parent stream, causing the other dependencies to depend on the exclusive stream. In the previous example, if stream D is created with an exclusive dependency on stream A, D becomes the parent of the dependencies B and C.
```c
                         A
       A                 |
      / \      ==>       D
     B   C              / \
                       B   C
```
Within the dependency tree, a dependent stream should be allocated resources only if all the streams it depends on (the chain of parent streams up to 0x0) are closed or it is no longer possible to make progress on them. A stream cannot depend on itself; an endpoint must treat this as a stream error of type PROTOCOL\_ERROR ([Section 5.4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


### 2. Dependency Weights

All dependent streams are assigned an integer weight value in the range [1,256]. Streams with the same parent should be allocated resources in proportion to their weights. Therefore, if stream B depends on stream A with a weight of 4, stream C depends on stream A with a weight of 12, and no progress can be made on stream A, stream B ideally receives one third of the resources allocated to stream C.

### 3. Reprioritization

A stream's priority is changed using a PRIORITY frame. Setting a dependency causes the stream to depend on the identified parent stream. If the parent stream is reprioritized, dependent streams are adjusted together with their parent. Setting a dependency with the exclusive flag for a reprioritized stream causes all dependencies of the new parent stream to depend on the reprioritized stream.

If a stream is made dependent on one of its own dependents, the stream it depends on is first moved to the position that the parent stream occupies after reprioritization is complete. The dependency adjustment preserves its weight. For example, consider an original dependency tree in which B and C depend on A, D and E depend on C, and F depends on D. If A depends on D, then D replaces A. All other dependencies remain unchanged, except for F, which will also depend on A if the reprioritization is exclusive.
```c
       x                x                x                 x
       |               / \               |                 |
       A              D   A              D                 D
      / \            /   / \            / \                |
     B   C     ==>  F   B   C   ==>    F   A       OR      A
        / \                 |             / \             /|\
       D   E                E            B   C           B C F
       |                                     |             |
       F                                     E             E
                  (intermediate)   (non-exclusive)    (exclusive)
```
Data streams that share the same parent (that is, sibling data streams) should be allocated resources in proportion to their weights. For example, if data stream A has a weight of 12 and its sibling data stream B has a weight of 4, determine the proportion of resources each stream should receive as follows:

![](https://img.halfrost.com/Blog/ArticleImage/130_5.svg)

1. Sum all weights: 4 + 12 = 16
2. Divide each stream’s weight by the total weight: A = 12/16, B = 4/16


Therefore, data stream A should receive three-quarters of the available resources, and data stream B should receive one-quarter; data stream B receives one-third of the resources received by data stream A.

Let’s look at several other examples in the figure above. From left to right:

1. Neither data stream A nor data stream B specifies a parent dependency; both depend on the explicit “root stream”. A has a weight of 12, and B has a weight of 4. Therefore, based on proportional weights, data stream B receives one-third of the resources received by A.
2. Data stream D depends on the root stream; C depends on D. Therefore, D should receive the full resource allocation before C. The weights do not matter, because C’s dependency has higher priority.
3. Data stream D should receive the full resource allocation before C; C should receive the full resource allocation before A and B; data stream B receives one-third of the resources received by A.
4. Data stream D should receive the full resource allocation before E and C; E and C should receive equal resource allocations before A and B; A and B should receive proportional allocations based on their weights.

As the examples above show, the combination of stream dependencies and weights clearly expresses resource priority. This is a key capability for improving browsing performance, where the network contains many resource types with different dependencies and weights. Moreover, the HTTP/2 protocol allows clients to update these priorities at any time, further optimizing browser performance. In other words, we can change dependencies and reassign weights based on user interactions and other signals.

>Note: Stream dependencies and weights express transport priority, not requirements, so a specific processing or transmission order is not guaranteed. That is, a client cannot force a server to process streams in a particular order through stream priority. Although this may seem counterintuitive, it is necessary behavior. We do not want to prevent the server from processing lower-priority resources when higher-priority resources are blocked.


### 4. Priority State Management

When a stream is removed from the dependency tree, its dependencies can be moved to depend on the closed stream’s parent. The weights of the new dependencies are recalculated by proportionally redistributing the weight of the closed stream’s dependencies based on the dependency weight relationships.

Removing a stream from the dependency tree causes some priority information to be lost. Resources are shared among streams with the same parent, which means that if one stream in that set is closed or blocked, any spare capacity allocated to that stream is assigned to its immediate neighbors. However, if the common dependency is removed from the tree, those streams share resources with streams at the next higher level.

For example, suppose streams A and B share a parent node, and streams C and D both depend on stream A. Before stream A is removed, if streams A and D cannot continue processing data, stream C receives all resources dedicated to stream A. If stream A is removed from the tree, stream A’s weight is redistributed between streams C and D. If stream D still cannot continue processing data, this reduces the proportion of resources received by stream C. With equal initial weights, C receives one-third of the available resources instead of one-half.

There is a situation where priority information that creates a dependency on a stream is in transit over the network, and that stream is suddenly closed. If the stream identified in the dependency has no associated priority information, the dependent stream is assigned the default priority ([Section 5.3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)). This can result in suboptimal priority, because the stream may be assigned a priority different from the intended one. To avoid these problems, endpoints should retain a stream’s priority state for some time after the stream is closed. The longer the state is retained, the lower the likelihood that an incorrect or default priority value will be assigned to the stream.

Similarly, a stream in the "idle" state can be assigned a priority or become the parent of other streams. This allows grouping nodes to be created in the dependency tree, enabling more flexible priority expression. Idle streams start with the default priority ([Section 5.3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)).

Retaining priority information for streams that do not count against the SETTINGS\_MAX\_CONCURRENT\_STREAMS limit can impose a significant state burden on endpoints. Therefore, the amount of retained priority state can be limited.

The additional amount of state an endpoint maintains for priorities can depend on load; under high load, priority state can be discarded to limit resource commitment. In extreme cases, an endpoint can even discard the priority state of active streams or retained streams. If the limit is respected, an endpoint should maintain state for at least as many streams as its SETTINGS\_MAX\_CONCURRENT\_STREAMS setting. Implementations should also try to retain the state of streams that are in use in the priority tree.

If it has retained enough state, an endpoint that receives a PRIORITY frame should, when changing the priority of a closed stream, change the dependencies of streams that depend on it.

### 5. Default Priority

All streams are assigned a non-exclusive dependency on stream 0x0 by default. Pushed streams ([Section 8.2]((https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#%E4%BA%8C-server-push))) initially depend on their associated stream. In both cases, streams are assigned the default weight of 16.


## VII. Error Handling

HTTP/2 framing allows two classes of errors:

- Errors that render the entire connection unusable are connection errors.

- Errors in an individual stream are stream errors.

[Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes) contains the list of error codes.


### 1. Error Handling for Connection Errors

A connection error is any error that prevents further processing of the frame layer or corrupts any connection state.

An endpoint that encounters a connection error should first send a GOAWAY frame ([Section 6.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)) containing the stream identifier of the last stream it successfully received from its peer. The GOAWAY frame contains an error code that identifies the reason for connection termination. After sending a GOAWAY frame for the error condition, the endpoint MUST close the TCP connection.

The receiving endpoint might not reliably receive the GOAWAY frame ([Section 6.6 of [RFC7230]](https://tools.ietf.org/html/rfc7230#section-6.6) describes how immediate connection closure can result in data loss). If a connection error occurs, the GOAWAY frame is a best-effort attempt to communicate the reason for connection termination to the peer.

An endpoint can terminate a connection at any time. In particular, an endpoint can choose to treat a stream error as a connection error. Where circumstances permit, an endpoint should send a GOAWAY frame when ending a connection.


### 2. Error Handling for Stream Errors

A stream error is an error associated with one specific stream; it does not affect processing of other streams.

An endpoint that detects a stream error sends an RST\_STREAM frame ([Section 6.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%9B%9B-rst_stream-%E5%B8%A7)) containing the stream identifier of the stream where the error occurred. The RST\_STREAM frame contains an error code indicating the type of error.

RST\_STREAM is the last frame an endpoint can send on a stream. The peer that sends an RST\_STREAM frame must be prepared to receive some frames that were sent by the remote peer or queued for sending. These frames can be ignored unless they modify connection state, such as state maintained for header compression ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression) or flow control).

In general, an endpoint should not send more than one RST\_STREAM frame for any stream. However, if an endpoint receives frames on a closed stream after more than one round-trip time has elapsed, it can send additional RST\_STREAM frames. This behavior can be used to handle some incorrect implementations.

To avoid loops, an endpoint MUST NOT send RST\_STREAM in response to an RST\_STREAM frame.

### 3. Connection Termination

If the TCP connection is closed or reset while streams remain in the "open" or "half-closed" state, the affected streams cannot be automatically retried (for details, see [Section 8.1.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2)).

## VIII. Extensions in HTTP/2

HTTP/2 allows the protocol to be extended. Within the limits described in this section, protocol extensions can be used to provide additional services or change any aspect of the protocol. Extensions are effective only within the scope of a single HTTP/2 connection.

This applies to protocol elements defined in the HTTP/2 specification. It does not affect existing options for extending HTTP, such as defining new methods, status codes, or header fields.

Extensions are allowed to use new frame types ([Section 4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F)), new settings ([Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)), or new error codes ([Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)). Registries are established to manage these extension points: frame types ([Section 11.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#2-%E5%B8%A7%E7%B1%BB%E5%9E%8B%E6%B3%A8%E5%86%8C)), settings ([Section 11.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#3-settings-%E6%B3%A8%E5%86%8C)), and error codes ([Section 11.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-Considerations.md#4-%E9%94%99%E8%AF%AF%E7%A0%81%E6%B3%A8%E5%86%8C)).
Implementations MUST ignore unknown or unsupported values in all extensible protocol elements. Implementations MUST discard frames with unknown or unsupported types. This means that any of these extension points can be used in an extension-safe way without prior arrangement or negotiation. However, extension frames are not permitted to appear in the middle of a header block ([Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)); if this occurs, it MUST be treated as a connection error of type PROTOCOL\_ERROR ([Section 5.4.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)).


Some extensions change the semantics of existing protocol components; these extensions MUST be negotiated before use. For example, an extension that changes the layout of HEADERS frames cannot be used until the peer has sent an acceptable positive signal. In such cases, it may also be necessary to adapt at the point when the modified layout takes effect. Note that treating any frame other than a DATA frame as subject to flow control is a semantic change, and such a change can only be made through negotiation.

The HTTP/2 specification does not define a specific method for negotiating the use of extensions, but SETTINGS frames ([Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)) can be used for this purpose. If both peers set values indicating their willingness to use an extension, the extension can be used. If a setting is used for extension negotiation, its initial value MUST be defined such that the extension is disabled by default.


------------------------------------------------------

Reference:  

[RFC 7540](https://tools.ietf.org/html/rfc7540)    
[Introduction to HTTP/2](https://developers.google.com/web/fundamentals/performance/http2/?hl=zh-cn)    
[http2 Explained](https://legacy.gitbook.com/book/ye11ow/http2-explained/details)  

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
> 
> Source: [https://halfrost.com/http2-http-frames/](https://halfrost.com/http2-http-frames/)
>