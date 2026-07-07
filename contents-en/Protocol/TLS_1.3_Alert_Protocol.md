# TLS 1.3 Alert Protocol


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/110_0.png'>
</p>


TLS provides the alert content type to indicate closure information and errors. As with other messages, alert messages are encrypted according to the current connection state.

Alert messages convey a description of the alert as well as a legacy field that, in earlier versions of TLS, conveyed the message severity level. Alerts fall into two categories: closure alerts and error alerts. In TLS 1.3, the severity of an error is implied by the type of alert being sent, and the "level" field can be safely ignored. The "close\_notify" alert is used to indicate an orderly shutdown of the connection in one direction. After receiving such an alert, a TLS implementation should signal end-of-data to the application.

Error alerts indicate that the connection has been aborted (see [Section 6.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Alert_Protocol.md#%E4%BA%8C-error-alerts)). After receiving an error alert, a TLS implementation should indicate an error to the application and must not allow any further data to be sent or received on the connection. The server and client must forget the secret values and keys established in the failed connection, except for PSKs associated with session tickets, which should be discarded if possible.

All alerts listed in Section 6.2 must be sent with AlertLevel = fatal and, when received, must be treated as error alerts regardless of the AlertLevel in the message. Unknown alert types must also be treated as error alerts.

Note: TLS defines two generic alerts (see [Section 6](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Alert_Protocol.md#tls-13-alert-protocol)) for use when message parsing fails. A peer that receives a syntactically invalid message (for example, a message with a length that extends beyond the message boundary or that contains an out-of-range length) must terminate the connection with a "decode\_error" alert. A peer that receives a syntactically valid but semantically invalid message (for example, a DHE share of p-1 or an invalid enumeration) must terminate the connection with an "illegal\_parameter" alert.
```c
      enum { warning(1), fatal(2), (255) } AlertLevel;

      enum {
          close_notify(0),
          unexpected_message(10),
          bad_record_mac(20),
          record_overflow(22),
          handshake_failure(40),
          bad_certificate(42),
          unsupported_certificate(43),
          certificate_revoked(44),
          certificate_expired(45),
          certificate_unknown(46),
          illegal_parameter(47),
          unknown_ca(48),
          access_denied(49),
          decode_error(50),
          decrypt_error(51),
          protocol_version(70),
          insufficient_security(71),
          internal_error(80),
          inappropriate_fallback(86),
          user_canceled(90),
          missing_extension(109),
          unsupported_extension(110),
          unrecognized_name(112),
          bad_certificate_status_response(113),
          unknown_psk_identity(115),
          certificate_required(116),
          no_application_protocol(120),
          (255)
      } AlertDescription;

      struct {
          AlertLevel level;
          AlertDescription description;
      } Alert;
```

## I. Closure Alerts

The Client and Server must share the state of connection termination to avoid truncation attacks.


- close\_notify:
	This alert notifies the recipient that the sender will not send any more messages on this connection. Any data received after a closure alert has been received must be ignored.

- user\_canceled:
	This alert notifies the recipient that the sender is canceling the handshake for some reason unrelated to a protocol failure. If the user cancels the operation after the handshake has completed, it is more appropriate to close the connection by sending "close\_notify". This warning follows "close\_notify". This alert typically has AlertLevel = warning.


Either party may initiate closure of its write side of the connection by sending a "close\_notify" alert. Any data received after a closure alert has been received must be ignored. If a transport-level close is received before "close\_notify", the recipient cannot know that it has received all data that was sent.


Each party must send a "close\_notify" alert before closing the write side of the connection, unless it has already sent some error alert. This has no effect on the read side of the connection. Note that this is a change from versions of TLS prior to TLS 1.3, where implementations were required to react to "close\_notify" by discarding pending writes and immediately sending their own "close\_notify" alert. The previous requirement could cause truncation on the read side. Neither party is required to wait to receive a "close\_notify" alert before closing the read side of the connection, but doing so introduces the possibility of truncation.


If an application protocol using TLS specifies that any data may be carried over the underlying transport after the TLS connection is closed, then the TLS implementation must receive a "close\_notify" alert before indicating end-of-data to the application layer. No part of this standard should be taken to prescribe how usage profiles of TLS manage their data transport, including when connections are opened or closed.

Note: This assumes that, after the write side of the connection is closed, pending data can still be sent reliably before the transport is destroyed.


## II. Error Alerts

Error handling in TLS is very simple. When an error is detected, the detecting party sends a message to its peer. Upon transmitting or receiving a fatal alert message, both parties must immediately close the connection.

Whenever an implementation encounters a fatal error condition, it should send an appropriate fatal alert and must close the connection without sending or receiving any other data. In the remainder of this specification, when the phrases "terminate the connection" and "abort the handshake" are used without a specific alert, this means the implementation should send the alert indicated by the following descriptions. The phrases "terminate the connection with an X alert" and "abort the handshake with an X alert" mean that, if any alert is sent, the implementation must send alert X. Starting with TLS 1.3, all alerts defined below in this section, as well as all unknown alerts, are considered fatal (see [Section 6](hhttps://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Alert_Protocol.md#tls-13-alert-protocol)). Implementations should provide a convenient way to log sent and received alerts.


The following error alerts are defined:

1. unexpected\_message:  
	An inappropriate message was received (for example, an incorrect handshake message, premature application data, etc.). This alert should never occur in communication between correct implementations.

2. bad\_record\_mac:  
	This alert is returned if a record is received that cannot be unprotected. Because AEAD algorithms combine decryption and verification and also avoid side-channel attacks, this alert is used for all deprotection failures. This alert should never occur in communication between correct implementations unless messages are corrupted in the network.

3. record\_overflow:  
	A TLSCiphertext record was received that has a length of more than 2 ^ 14 + 256 bytes, or a record decrypted to a TLSPlaintext record of more than 2 ^ 14 bytes (or some other negotiated limit). This alert should never occur in communication between correct implementations unless messages are corrupted in the network.

4. handshake\_failure:  
	Receipt of a "handshake\_failure" alert message indicates that the sender was unable to negotiate an acceptable set of security parameters given the available options.

5. bad\_certificate:  
	The certificate was corrupted, including signatures that did not verify correctly, and so on.

6. unsupported\_certificate:  
	The type of the certificate is unsupported.

7. certificate\_revoked:  
	The certificate has been revoked by its signer.
	
8. certificate\_expired:  
	The certificate has expired or is currently invalid.

9. certificate\_unknown:  
	Some other (unspecified) issue arose while processing the certificate, rendering it unacceptable.

10. illegal\_parameter:  
	A field in the handshake was incorrect or inconsistent with other fields. This alert is used for errors that conform to the formal protocol syntax but are otherwise incorrect.

11. unknown\_ca:  
	A valid certificate chain or partial chain was received, but the certificate was not accepted because the CA certificate could not be located or could not be matched with a known trust anchor.

12. access\_denied:  
	A valid certificate or PSK was received, but when access control was applied, the sender decided not to proceed with negotiation.

13. decode\_error:  
	A message could not be decoded because some field was out of the specified range or the message length was incorrect. This alert is used for errors where the message does not conform to the formal protocol syntax. This alert should never occur in communication between correct implementations unless messages are corrupted in the network.

14. decrypt\_error:  
	A handshake (rather than record layer) cryptographic operation failed, including failure to correctly verify a signature or validate a Finished message or PSK binder.

15. protocol\_version：  
	The protocol version that the peer attempted to negotiate was recognized but is not supported (see Appendix D).

16. insufficient\_security:  
	"insufficient\_security" is returned instead of "handshake\_failure" when negotiation fails because the Server requires parameters more secure than those supported by the Client.

17. internal\_error:  
	An internal error unrelated to the peer or to the correctness of the protocol (such as a memory allocation failure) made it impossible for the connection to continue.

18. applicable\_fallback:  
	Sent by the Server in response to a retry of an invalid connection from the Client (see [[RFC7507]](https://tools.ietf.org/html/rfc7507)).

19. missing\_extension:  
	Sent by an endpoint receiving a handshake message that does not contain an extension that must be sent for the offered TLS version, or that does not contain an extension required by other negotiated parameters.

20. unsupported\_extension:  
	Sent by an endpoint receiving any handshake message that contains an extension known to be prohibited in the given handshake message, or that contains certain extensions in ServerHello or Certificate that were not first offered in the corresponding ClientHello or CertificateRequest.

21. unrecognized\_name:  
	When the name provided by the Client through the "server\_name" extension does not correspond to a Server identified by that name, the Server sends an "unrecognized\_name" alert message (see [[RFC6066]](https://tools.ietf.org/html/rfc6066)).

22. bad\_certificate\_status\_response:  
	When the Server provides an invalid or unacceptable OCSP response through the "status\_request" extension, the Client sends "bad\_certificate\_status\_response" (see [[RFC6066]](https://tools.ietf.org/html/rfc6066)).

23. unknown\_psk\_identity:  
	When PSK key establishment is required but the Client cannot provide an acceptable PSK identity, the Server sends "unknown\_psk\_identity". Sending this alert is optional; the Server may choose to send a "decrypt\_error" alert, indicating only an invalid PSK identity.

24. certificate\_required:  
	When a Client certificate is required but the Client does not provide one, the Server sends "certificate\_required".

25. no\_application\_protocol:  
	When the protocols in the Client's "application\_layer\_protocol\_negotiation" extension are not supported by the Server, the Server sends "no\_application\_protocol" (see [[RFC7301]](https://tools.ietf.org/html/rfc7301)).

New alert values are assigned by IANA, as described in [Section 11](https://tools.ietf.org/html/rfc8446#section-11).


------------------------------------------------------

Reference:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Alert\_Protocol/](https://halfrost.com/tls_1-3_alert_protocol/)