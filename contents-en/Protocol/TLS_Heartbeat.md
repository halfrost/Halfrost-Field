# TLS & DTLS Heartbeat Extension


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/118_0.png'>
</p>


This article mainly discusses the Heartbeat extension in Transport Layer Security (TLS) and Datagram Transport Layer Security (DTLS).

The Heartbeat extension provides a new protocol for TLS/DTLS, enabling keep-alive functionality without requiring renegotiation. The Heartbeat extension also provides the basis for path MTU (PMTU) discovery.

## I. Introduction

This article describes the heartbeat extension for the Transport Layer Security (TLS) and Datagram Transport Layer Security (DTLS) protocols defined in [[RFC5246]](https://tools.ietf.org/html/rfc5246) and [[RFC6347]](https://tools.ietf.org/html/rfc6347), as well as their adaptation to the specific transport protocols described in [[RFC3436]](https://tools.ietf.org/html/rfc3436), [[RFC5238]](https://tools.ietf.org/html/rfc5238), and [[RFC6083]](https://tools.ietf.org/html/rfc6083).

The DTLS protocol is designed to protect traffic data running over unreliable transport protocols. Such protocols typically do not provide session management. The only mechanism the DTLS layer can use to determine whether the peer is still alive is the expensive renegotiation mechanism, especially when the application uses unidirectional traffic. In addition, DTLS needs to perform path MTU (PMTU) discovery, but without affecting the transmission of user messages, there is no specific message type for implementing PMTU discovery.

TLS is based on a reliable protocol, but it does not provide the necessary functionality to keep a connection alive in the absence of continuous data transmission.

The heartbeat extension described in this document overcomes these limitations. A user can use the new HeartbeatRequest message, which must be answered immediately by the peer with a HeartbeartResponse. To perform PMTU discovery, as described in [RFC4821](https://tools.ietf.org/html/rfc4821), a HeartbeatRequest message containing padding can be used as a probe packet.


## II. Heartbeat Hello Extension

Hello Extensions indicate support for Heartbeats. A peer can not only indicate that its implementation supports Heartbeats, but also choose whether it is willing to receive HeartbeatRequest messages and respond with HeartbeatResponse messages, or only send HeartbeatRequest messages. The former is indicated by using peer\_allowed\_to\_send as the HeartbeatMode; the latter is indicated by using peer\_not\_allowed\_to\_send as the heartbeat mode. This decision can be changed on each renegotiation. HeartbeatRequest messages must not be sent to a peer that has indicated peer\_not\_allowed\_to\_send. If an endpoint that has indicated peer\_not\_allowed\_to\_send receives a HeartbeatRequest message, the endpoint SHOULD silently discard the message and MAY send an unexpected\_message Alert message.

The format of the Heartbeat Hello extension is defined as follows:
```c
   enum {
      peer_allowed_to_send(1),
      peer_not_allowed_to_send(2),
      (255)
   } HeartbeatMode;

   struct {
      HeartbeatMode mode;
   } HeartbeatExtension;
```
Upon receiving an unknown mode, an error alert message using illegal\_parameter as its AlertDescription MUST be sent in response.

## III. Heartbeat Protocol

The Heartbeat protocol is a new protocol that runs on top of the record layer. The protocol itself consists of two message types: HeartbeatRequest and HeartbeatResponse.
```c
   enum {
      heartbeat_request(1),
      heartbeat_response(2),
      (255)
   } HeartbeatMessageType;
```
HeartbeatRequest messages may arrive at almost any time during the lifetime of a connection. Whenever a HeartbeatRequest message is received, it SHOULD be answered with a corresponding HeartbeatResponse message.

However, HeartbeatRequest messages MUST NOT be sent during the handshake. If a handshake is initiated while a HeartbeatRequest is still in flight, the sending peer MUST stop its DTLS retransmission timer for it. If one arrives during the handshake, the receiving peer SHOULD silently discard the message. In the case of DTLS, HeartbeatRequest messages from an older epoch SHOULD be discarded.

There MUST NOT be more than one HeartbeatRequest message in flight at a time. A HeartbeatRequest message is considered in flight until the corresponding HeartbeatResponse message is received, or until the retransmission timer expires.

When an unreliable transport protocol is used, such as Datagram Congestion Control Protocol (DCCP) or UDP, HeartbeatRequest messages MUST be retransmitted using the simple timeout and retransmission scheme that DTLS uses for in-flight messages, as described in [[RFC6347] Section 4.2.4](https://tools.ietf.org/html/rfc6347#section-4.2.4). In particular, if the corresponding HeartbeatResponse message with the expected payload is not received after several retransmission attempts, the DTLS connection SHOULD be terminated. The threshold used for this SHOULD be the same as the threshold used for DTLS handshake messages. Note that after the timer supervising the HeartbeatRequest message expires, the message is no longer considered in flight. Therefore, the HeartbeatRequest message is eligible for retransmission. The retransmission scheme, together with the restriction that only one HeartbeatRequest may be in flight, ensures that congestion control is handled appropriately when the transport protocol does not provide it, as in the case of DTLS over UDP.

When a reliable transport protocol is used, such as Stream Control Transmission Protocol (SCTP) or TCP, a HeartbeatRequest message only needs to be sent once. The transport layer will handle retransmission. If the corresponding HeartbeatResponse message is not received after some period of time, the DTLS/TLS connection may be terminated by the application that initiated the HeartbeatRequest message.


## 4. Heartbeat Request and Response Messages

Heartbeat protocol messages consist of their type, an arbitrary payload, and padding.
```c
   struct {
      HeartbeatMessageType type;
      uint16 payload_length;
      opaque payload[HeartbeatMessage.payload_length];
      opaque padding[padding_length];
   } HeartbeatMessage;
```
According to the definition in [[RFC6066]](https://tools.ietf.org/html/rfc6066), during negotiation, the total length of a HeartbeatMessage MUST NOT exceed 2 ^ 14 or max\_fragment\_length.

- type:   
	The message type: heartbeat\_request or heartbeat\_response.
	
- payload\_length:   
	The length of the payload.

- payload:  
	The payload consists of arbitrary content.

- padding:  
	The padding consists of random content and MUST be ignored by the receiver. The length of a HeartbeatMessage is the TLSPlaintext.length for TLS and the DTLSPlaintext.length for DTLS. In addition, the type field is 1 byte long, and payload\_length is 2 bytes long. Therefore, padding\_length is TLSPlaintext.length  -  payload\_length  -  3 for TLS, and DTLSPlaintext.length  -  payload\_length  -  3 for DTLS. padding\_length MUST be at least 16.

The sender of a HeartbeatMessage MUST use at least 16 bytes of random padding. The padding of a received HeartbeatMessage message MUST be ignored.


If the payload\_length of a received HeartbeatMessage is too large, the received HeartbeatMessage MUST be silently discarded.

When a HeartbeatRequest message is received and sending a HeartbeatResponse is not prohibited, as described elsewhere in this document, the receiver MUST send the corresponding HeartbeatResponse message, carrying a copy of the payload from the received HeartbeatRequest.

If a received HeartbeatResponse message does not contain the expected payload, the message MUST be silently discarded. If it does contain the expected payload, the retransmission timer MUST be stopped.


## V. Use Cases

Each endpoint sends HeartbeatRequest messages at a given rate and uses the padding required by the specific use case. An endpoint SHOULD NOT expect its peer to send HeartbeatRequests. The directions are independent.

### 1. Path MTU Discovery

DTLS performs Path MTU Discovery as described in [[RFC6347] Section 4.1.1.1](https://tools.ietf.org/html/rfc6347#section-4.1.1.1). [[RFC4821]](https://tools.ietf.org/html/rfc4821) provides a detailed description of how to perform Path MTU Discovery. The required probe packets are HeartbeatRequest messages.

This method of using HeartbeatRequest messages for DTLS is similar to the Stream Control Transmission Protocol (SCTP) method that uses the padding chunk (PAD-chunk) defined in [[RFC4820]](https://tools.ietf.org/html/rfc4820).


### 2. Liveliness Check

Sending HeartbeatRequest messages allows the sender to ensure that it can reach the peer and that the peer is alive. Even in the TLS/TCP case, this allows checks to be performed at a higher rate than the TCP keep-alive feature permits.

In addition to ensuring that the peer is still reachable, sending HeartbeatRequest messages also refreshes the NAT state of all relevant NATs.

HeartbeatRequest messages SHOULD be sent only after an idle period that is at least several round-trip times long. This idle period SHOULD be configurable up to a period of several minutes and can be reduced to a period of one second. The default value for the idle period SHOULD be configurable, but it SHOULD also be adjustable on a per-peer basis.


## VI. IANA Considerations

IANA has allocated the heartbeat content type (24) from the "TLS ContentType Registry" specified in [[RFC5246]](https://tools.ietf.org/html/rfc5246). The reference is [[RFC 6520]](https://tools.ietf.org/html/rfc6520).

IANA has created and now maintains a new registry for heartbeat message types. Message types are numbers in the range 0 to 255 (decimal). IANA has allocated the heartbeat\_request(1) and heartbeat\_response(2) message types. The values 0 and 255 SHOULD be reserved. This registry uses the Expert Review policy described in [[RFC5226]](https://tools.ietf.org/html/rfc5226). The reference is [RFC 6520](https://tools.ietf.org/html/rfc6520).

IANA has allocated the heartbeat extension type (15) from the TLS "ExtensionType Values" registry specified in [RFC5246](https://tools.ietf.org/html/rfc5246). The reference is [RFC 6520](https://tools.ietf.org/html/rfc6520).

IANA has created and now maintains a new registry for heartbeat modes. Modes are numbers in the range 0 to 255 (decimal). IANA has allocated the peer\_allowed\_to\_send(1) and peer\_not\_allowed\_to\_send(2) modes. The values 0 and 255 SHOULD be reserved. This registry uses the Expert Review policy described in [[RFC5226]](https://tools.ietf.org/html/rfc5226). The reference is [RFC 6520](https://tools.ietf.org/html/rfc6520).


## VII. Security Considerations

The security considerations of [[RFC5246]](https://tools.ietf.org/html/rfc5246) and [[RFC6347]](https://tools.ietf.org/html/rfc6347) apply to this document. This document introduces no new security considerations.


------------------------------------------------------

Reference：
  
[RFC 6520](https://tools.ietf.org/html/rfc6520)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_Heartbeat/](https://halfrost.com/tls_heartbeat/)