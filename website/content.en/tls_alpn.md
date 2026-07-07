+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-08-11T07:43:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/135_0.png"
slug = "tls_alpn"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "TLS Application-Layer Protocol Negotiation Extension"

+++


In this article, we mainly discuss the Application-Layer Protocol Negotiation extension in the Transport Layer Security (TLS) handshake. For instances that support multiple application protocols on the same TCP or UDP port, this extension allows the application layer to negotiate which protocol will be used in the TLS connection.

## I. Introduction

Application-layer protocols are increasingly being encapsulated in the TLS protocol [[RFC5246]](https://tools.ietf.org/html/rfc5246). This encapsulation allows applications to use port 443, an existing secure communication endpoint that is already present across almost the entire global IP infrastructure.

When multiple application protocols are supported on a single server-side port number, such as port 443, the client and server need to negotiate the application protocol to be used for each connection. Ideally, this negotiation should be completed without increasing the number of network round trips between the client and server, because each additional round trip degrades the end-user experience. In addition, it would be advantageous to allow certificate selection based on the negotiated application protocol.

This article specifies a TLS extension that allows the application layer to negotiate protocol selection during the TLS handshake. The HTTPbis WG requested this work to address negotiation of HTTP/2 over TLS ([[HTTP2]](https://tools.ietf.org/html/rfc7301#ref-HTTP2)). However, ALPN is useful for negotiating arbitrary application-layer protocols.

With ALPN, the client sends a list of supported application protocols as part of the TLS ClientHello message. The server selects one protocol and sends the selected protocol as part of the TLS ServerHello message. As a result, application protocol negotiation can be completed within the TLS handshake without adding any network round trips, while also allowing the server, if needed, to associate different certificates with each application protocol.


## II. Application-Layer Protocol Negotiation


### 1. The Application-Layer Protocol Negotiation Extension

A new extension type ("application\_layer\_protocol\_negotiation(16)") is defined, which the client may include in its “ClientHello” message.
```c
   enum {
       application_layer_protocol_negotiation(16), (65535)
   } ExtensionType;
```
The "extension\_data" field of the ("application\_layer\_protocol\_negotiation(16)") extension MUST contain a "ProtocolNameList" value.
```c
   opaque ProtocolName<1..2^8-1>;

   struct {
       ProtocolName protocol_name_list<2..2^16-1>
   } ProtocolNameList;
```
"ProtocolNameList" contains the list of protocols advertised by the client, in descending order of preference. Protocols are named by opaque, non-empty byte strings registered with IANA, as described in Section 6 ("IANA Considerations") of this document. Empty strings MUST NOT be included, and byte strings MUST NOT be truncated.

A server that receives a ClientHello containing the "application_layer_protocol_negotiation" extension may return an appropriate protocol selection to the client in response. The server will ignore any protocol names it does not recognize. A new ServerHello extension type ("application_layer_protocol_negotiation(16)") may be returned to the client in the ServerHello message extensions. The structure of the "extension_data" field of the ("application_layer_protocol_negotiation(16)") extension is the same as described above for the client's "extension_data", except that "ProtocolNameList" MUST contain exactly one "ProtocolName".

Therefore, a complete handshake with the "application_layer_protocol_negotiation" extension in the ClientHello and ServerHello messages has the following flow (compared with [Section 7.3 of [RFC5246]](https://tools.ietf.org/html/rfc5246#section-7.3)):
```c
   Client                                              Server

   ClientHello                     -------->       ServerHello
     (ALPN extension &                               (ALPN extension &
      list of protocols)                              selected protocol)
                                                   Certificate*
                                                   ServerKeyExchange*
                                                   CertificateRequest*
                                   <--------       ServerHelloDone
   Certificate*
   ClientKeyExchange
   CertificateVerify*
   [ChangeCipherSpec]
   Finished                        -------->
                                                   [ChangeCipherSpec]
                                   <--------       Finished
   Application Data                <------->       Application Data

                                 Figure 1

   * Indicates optional or situation-dependent messages that are not always sent.
```
A short handshake with the "application\_layer\_protocol\_negotiation" extension has the following flow:
```c
   Client                                              Server

   ClientHello                     -------->       ServerHello
     (ALPN extension &                               (ALPN extension &
      list of protocols)                              selected protocol)
                                                   [ChangeCipherSpec]
                                   <--------       Finished
   [ChangeCipherSpec]
   Finished                        -------->
   Application Data                <------->       Application Data
```
Unlike many other TLS extensions, this extension establishes properties of the connection, not properties of the session. When session resumption or session tickets [[RFC5077]](https://tools.ietf.org/html/rfc5077) are used, the previous contents of this extension are irrelevant, and only the values in the new handshake messages are considered.


### 2. Protocol Selection


The server is expected to have a preference-ordered list of supported protocols and to select a protocol only if it is supported by the client. In this case, the server should select the highest-priority protocol that it supports and that was also advertised by the client. If the server does not support any of the protocols sent by the client, it should respond with a "no\_application\_protocol" alert error.
```c
   enum {
       no_application_protocol(120),
       (255)
   } AlertDescription;
```
Before renegotiation, the protocol identified in ServerHello's "application\_layer\_protocol\_negotiation" extension type is definitive for this connection. The server will not respond with the selected protocol and then subsequently use a different protocol for application data exchange.

## III. Design Considerations

The ALPN extension is intended to follow the typical design of TLS protocol extensions. Specifically, consistent with the established TLS architecture, negotiation is performed entirely within the client/server hello exchange. The ServerHello extension "application\_layer\_protocol\_negotiation" is intended to determine the protocol selected for the connection (until the connection is renegotiated) and is sent in plaintext, allowing network elements to provide differentiated services for the connection when the application-layer protocol is not readily determined from the TCP or UDP port number. By placing ownership of protocol selection with the server, ALPN facilitates scenarios such as certificate selection or connection rerouting, both of which may be based on the negotiated protocol.

Ultimately, by managing protocol selection in plaintext during the handshake, ALPN avoids introducing errors caused by hiding the negotiated protocol before the connection is established. If the protocol needs to be hidden, the preferred approach is to renegotiate after the connection has been established (which provides the actual TLS security guarantees).


## IV. Security Considerations


The ALPN extension does not affect the security of TLS session establishment or application data exchange. ALPN is used to provide an externally visible label for the application-layer protocol associated with a TLS connection. Historically, the application-layer protocol associated with a connection could be determined from the TCP or UDP port number in use.

Implementers and document editors intending to extend the protocol identifier registry by adding new protocol identifiers should take into account that, in TLS version 1.2 and earlier, clients send these identifiers in plaintext. They should also consider that, for at least the next decade, browsers are generally expected to use these earlier versions of TLS in the initial ClientHello.

Particular care must be taken when such identifiers could disclose personally identifiable information, or when such disclosure could enable profiling or reveal sensitive information. If any of these concerns apply to a new protocol identifier, that identifier should not be used in TLS configurations where it is visible in cleartext, and documents specifying such protocol identifiers should recommend avoiding this insecure usage.

## V. IANA Considerations

IANA has updated its "ExtensionType Values" registry to include the following entry:
```c
      16 application_layer_protocol_negotiation
```
This document establishes a registry under the existing "Transport Layer Security (TLS) Extensions" heading for protocol identifiers titled "Application-Layer Protocol Negotiation (ALPN) Protocol IDs".

Entries in this registry require the following fields:

- Protocol: The protocol name.
- Identification Sequence: A precise set of octet values that identifies the protocol. This can be the UTF-8 encoding of the protocol name [[RFC3629]](https://tools.ietf.org/html/rfc3629).
- Reference: A reference to the specification that defines the protocol.


This registry operates under the "Expert Review" policy defined in [[RFC5226]](https://tools.ietf.org/html/rfc5226). Designated experts are encouraged to include references to permanent and readily available specifications that enable interoperable implementations of the identified protocol to be created.

The initial set of registrations for this registry is as follows:

Protocol:  HTTP/1.1  
Identification Sequence:  
      0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x31 ("http/1.1")  
Reference:  [[RFC7230]](https://tools.ietf.org/html/rfc7230)

Protocol:  SPDY/1  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x31 ("spdy/1")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1)

Protocol:  SPDY/2  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x32 ("spdy/2")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2)
      
Protocol:  SPDY/3  
Identification Sequence:  
      0x73 0x70 0x64 0x79 0x2f 0x33 ("spdy/3")  
Reference:  
      [http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3](http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3)

------------------------------------------------------

Reference:
  
[RFC 7301](https://tools.ietf.org/html/rfc7301)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/tls\_alpn/](https://halfrost.com/tls_alpn/)