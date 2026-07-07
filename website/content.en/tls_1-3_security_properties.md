+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-12-16T01:07:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/116_0.png"
slug = "tls_1-3_security_properties"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 Overview of Security Properties"

+++


A complete security analysis of TLS is beyond the scope of this document. In this appendix, we provide an informal description of the required properties, along with references to more detailed work in the research literature that gives more formal definitions.

We separate the properties of the handshake from those of the record layer.


## I. Handshake

The TLS handshake is an authenticated key exchange (AKE) protocol designed to provide both one-way authentication (Server only) and mutual authentication (Client and Server). When the handshake completes, each side outputs the following values:


- A set of "session keys" (various keys derived from the master secret), from which a set of working keys can be derived.

- A set of cryptographic parameters (algorithms, etc.).

- The identities of the communicating parties.

We assume that the attacker is an active network attacker, meaning that it can fully control the network over which the two parties communicate [[RFC3552]](https://tools.ietf.org/html/rfc3552). Even under these conditions, the handshake should provide the properties listed below. Note that these properties are not necessarily independent; rather, they reflect the needs of protocol consumers.

Establishment of the same session keys: The handshake needs to output the same set of session keys on both sides of the handshake, assuming it completes successfully at each endpoint (see [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01), Definition 1, Part 1).


Confidentiality of session keys: The shared session keys must be known only to the communicating parties, not to the attacker (see [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01), Definition 1, Part 2). Note that in a unilaterally authenticated connection, the attacker can establish its own session keys with Server, but those session keys are different from the ones established with Client.

Peer authentication: Client's view of the peer identity should reflect Server's identity. If Client has been authenticated, then Server's view of the peer identity should match Client's identity.

Uniqueness of session keys: Any two distinct handshakes should produce distinct, unrelated session keys. The individual session keys produced by a handshake should also be distinct and independent.

Downgrade protection: The cryptographic parameters on both sides should be the same, and should be the same as they would have been if the two parties had communicated in the absence of an attack (see [[BBFGKZ16]](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16), Definitions 8 and 9).

Forward secrecy with respect to long-term keys: If long-term key material (in this case, the signing key in the certificate-based authentication mode, or the external/resumption PSK in PSK modes with (EC)DHE) is disclosed after the handshake has completed, this does not affect the security of the session keys as long as the session keys themselves have been deleted (see [[DOW92]](https://tools.ietf.org/html/rfc8446#ref-DOW92)). When a PSK is used in the "psk\_ke" PskKeyExchangeMode, the forward secrecy property cannot be satisfied.

Key Compromise Impersonation (KCI) resistance: In connections with mutual authentication using certificates, compromise of one participant's long-term key should not compromise that participant's authentication of its peer in this particular connection (see [[HGFS15]](https://tools.ietf.org/html/rfc8446#ref-HGFS15)). For example, if Client's signing key is compromised, it should not be possible to impersonate arbitrary Servers to Client in subsequent handshakes.

Protection of endpoint identities: Server's identity (certificate) should be protected against passive attackers. Client's identity should be protected against both passive and active attackers.

Informally, the signature-based modes of TLS 1.3 provide a unique, confidential shared key established by an (EC)DHE key exchange and authenticated over the handshake by Server's signature, plus a MAC associated with Server's identity. If Client is authenticated with a certificate, it also signs the handshake transcript and provides a MAC associated with both identities. [[SIGMA]](https://tools.ietf.org/html/rfc8446#ref-SIGMA) describes the design and analysis of this type of key exchange protocol. If a fresh (EC)DHE key is used for each connection, the output keys are forward secret.

External PSKs and resumption PSKs convert a long-term shared key into a set of short-term session keys that are unique per connection. This key may have been established in a previous handshake. If the PSK was established using an (EC)DHE key, then these session keys will also be forward secret. Resumption PSKs are designed so that the resumption master secret computed by connection N and needed to form connection N + 1 is separate from the traffic keys used by connection N, thereby providing forward secrecy between connections. In addition, if multiple tickets are established on the same connection, they are associated with different keys, so disclosure of the PSK associated with one ticket does not cause connections established with PSKs associated with other tickets to be disclosed as well. This property is most interesting when tickets are stored in a database (and therefore can be deleted) rather than being self-encrypted.

The value of the PSK binder binds the PSK to the current handshake, and also binds the session in which the PSK was established to the current session. This binding transitively includes the original handshake transcript, because that transcript is used to produce the value of the resumption master secret. This requires that both the KDF used to produce the resumption master secret and the MAC used to compute the binder be collision resistant. For more details, see [Appendix E.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#1-key-derivation-and-hkdf). Note: the binder does not include the values of other PSK binders, but they are included in the Finished MAC.


TLS currently does not allow Server to send a certificate\_request message in a handshake that is not certificate-based (for example, PSK). If this restriction is relaxed in the future, Client's signature will not directly cover Server's certificate. However, if the PSK is established via NewSessionTicket, Client's signature will transitively cover Server's certificate through the PSK binder. [PSK-FINISHED](https://tools.ietf.org/html/rfc8446#ref-PSK-FINISHED) describes concrete attacks on constructions that are not bound to Server's certificate (see also [Kraw16](https://tools.ietf.org/html/rfc8446#ref-Kraw16)). When Client shares the same PSK / key ID pair with two different endpoints, using certificate-based Client authentication in this case is unsafe. Implementations MUST NOT combine external PSKs with certificate-based authentication of Client or Server unless this is negotiated through some extension.


If exporters are used, they generate unique and confidential values (because they are generated from unique session keys). Exporters computed with different labels and different contexts are computationally independent, so deriving the session keys from an exporter is infeasible, and computing one exporter from another exporter is also infeasible. Note: exporters can generate values of arbitrary length; if an exporter is to be used as a channel binding, the exported value must be large enough to provide collision resistance. The exporters provided in TLS 1.3 are derived from the same handshake contexts as the early traffic keys and the application traffic keys, respectively, and therefore have similar security properties. Note that they do not include Client's certificate; applications that want to bind to Client's certificate in the future may need to define a new exporter that includes the full handshake transcript.


For all handshake modes, the Finished MAC (and signatures, when present) prevents downgrade attacks. In addition, as described in [Section 4.1.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-server-hello), the use of certain bytes in the random nonce allows detection of downgrades to earlier versions of TLS. For more details on TLS 1.3 and downgrade attacks, see [BBFGKZ16](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16).

Once Client and Server have exchanged enough information to establish a shared key, the remainder of the handshake is encrypted, providing protection against passive attackers even if the computed shared key has not been authenticated. Because Server authenticates before Client, Client can ensure that if it authenticates Server, it reveals its identity only to an already-authenticated Server. Note that implementations must use the record padding mechanism provided during the handshake (which can obscure length information) to avoid leaking information about identities via length. The PSK identities proposed by Client are not encrypted, nor is the identity selected by Server.


### 1. Key Derivation and HKDF

Key derivation in TLS 1.3 uses HKDF, as defined in [[RFC5869]](https://tools.ietf.org/html/rfc5869), and its two components, HKDF-Extract and HKDF-Expand. The HKDF construction can be found in [[Kraw10]](https://tools.ietf.org/html/rfc8446#ref-Kraw10), and [[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16) explains how to use it soundly in TLS 1.3. Throughout this document, every application of HKDF-Extract is followed by one or more invocations of HKDF-Expand. This order should always be followed (including in future revisions of this document); in particular, we should not use the output of HKDF-Extract directly as the input to another application of HKDF-Extract without an intervening invocation of HKDF-Expand. Multiple applications of HKDF-Expand are allowed to use the same input, as long as those inputs can be distinguished by key or label.

Note that HKDF-Expand implements a pseudorandom function (PRF) with variable-length inputs and outputs. In this document, for some uses of HKDF (for example, generating exporters and resumption\_master\_secret), applications of HKDF-Expand must be collision resistant; that is, it should be infeasible for HKDF-Expand to produce the same output value for two different input values. This requires that the underlying hash function be collision resistant and that the output length of HKDF-Expand be at least 256 bits (or whatever other length is required for the hash function to prevent collision finding).

### 2. Client Authentication

A Client that has sent authentication data to Server during the handshake or during post-handshake authentication cannot determine whether Server subsequently considers Client authenticated. If Client needs to know whether Server considers the connection to be unilaterally authenticated or mutually authenticated, this must be configured at the application layer. For more details, see [[CHHSV17]](https://tools.ietf.org/html/rfc8446#ref-CHHSV17). In addition, the analysis of post-handshake authentication from [[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16) shows that the Client identified by a certificate sent in the post-handshake phase possesses the traffic keys. Therefore, that party is either the Client that participated in the original handshake, or a Client that is proxying the traffic keys for the original Client (assuming the traffic keys have not been compromised).

### 3. 0-RTT

The 0-RTT mode of operation generally provides security properties similar to 1-RTT data, with two exceptions: 0-RTT encryption keys do not provide full forward secrecy, and the Server cannot guarantee the uniqueness (non-replayability) of the handshake without retaining excessive state. For mechanisms that limit replay risk, see [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay).


### 4. Exporter Independence

The derivation of exporter\_master\_secret and early\_exporter\_master\_secret is independent of the traffic keys, and therefore does not pose a threat to the security of traffic encrypted with those keys. However, because these keys can be used to compute the value of any exporter, they should be deleted as soon as possible. If the complete set of known exporter labels is known, implementations should precompute the internal Derive-Secret values for all such labels while computing the exporters, and then immediately delete the [early\_] exporter\_master\_secret following each internal value as soon as it is known to no longer be needed.


### 5. Post-Compromise Security

TLS does not provide security for handshakes that occur after a peer’s long-term key (a signing key or external PSK) has been compromised. Therefore, it does not provide post-compromise security [[CCG16]](https://tools.ietf.org/html/rfc8446#ref-CCG16), sometimes also called backward or future secrecy. This is in contrast to KCI resistance, which describes the security guarantees that one party to the communication has after its own long-term key has been compromised.


### 6. External References

Readers should consult the following references for analysis of the TLS handshake: [[DFGS15]](https://tools.ietf.org/html/rfc8446#ref-DFGS15), [[CHSV16]](https://tools.ietf.org/html/rfc8446#ref-CHSV16), [[DFGS16]](https://tools.ietf.org/html/rfc8446#ref-DFGS16), [[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16), [[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16), [[FGSW16]](https://tools.ietf.org/html/rfc8446#ref-FGSW16), [[LXZFH16]](https://tools.ietf.org/html/rfc8446#ref-LXZFH16), [[FG17]](https://tools.ietf.org/html/rfc8446#ref-FG17), and [[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17).


## II. Record Layer


The record layer relies on the handshake to produce strong traffic keys, which can be used to derive bidirectional encryption keys and nonces. Assuming this is true, and that keys are not used for more data than indicated in [Section 5.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%BA%94-limits-on-key-usage), the record layer should provide the following guarantees:


- Confidentiality: An attacker should not be able to infer the plaintext contents of a given record.

- Integrity: An attacker should not be able to create a new message that can be accepted by the receiver and that is a new record different from any existing record.

- Order protection/non-replayability: An attacker should not be able to cause the receiver to accept a record that has already been accepted (non-replayability), or to cause the receiver to accept record N + 1 without first processing record N (ordering).

- Length hiding: For a record with a given external length, an attacker should not be able to determine the amount of record content versus padding.

- Forward secrecy after key changes: If the traffic key update mechanism described in [Section 4.6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update) is used and the previous generation of keys is deleted, an attacker who intends to compromise an endpoint should not be able to decrypt ciphertexts encrypted with old keys.


Informally, TLS 1.3 provides its security properties through AEAD: plaintexts are protected with strong keys. AEAD encryption [[RFC5116]](https://tools.ietf.org/html/rfc5116) provides confidentiality and integrity for data. Non-replayability is provided by using a distinct nonce for each record, where the nonce is derived from the record sequence number ([Section 5.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%89-per-record-nonce)), and sequence numbers are maintained independently on both sides; therefore, records delivered out of order cause AEAD deprotection to fail. When different users repeatedly encrypt the same plaintext under the same key (as is common with HTTP), to prevent large-scale cryptanalysis in this situation, the nonce is formed by mixing the sequence number with the key of the per-connection initialization vector derived along with the traffic keys. For analysis of this construction, see [[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16).


The key update technique in TLS 1.3 (see [Section 7.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%BA%8C-updating-traffic-secrets)) follows the construction of the serial generator discussed in [[REKEY]](https://tools.ietf.org/html/rfc8446#ref-REKEY), which shows that key updates can allow keys to be used for a large amount of encryption without requiring rekeying. This relies on the security of HKDF-Expand-Label as a pseudorandom function (PRF). In addition, as long as this function is truly one-way, it is not possible to compute traffic keys prior to a key change (forward secrecy).

After the traffic keys for the connection have been compromised, TLS provides no security for data transmitted over the connection. That is, TLS does not provide post-compromise security/future secrecy/backward secrecy for traffic keys. In practice, an attacker who knows the traffic keys can compute all future traffic keys on that connection. Systems that need to defend against such attacks need to perform a new handshake and establish a new connection using an (EC)DHE exchange.


### 1. External References

Readers should consult the following references for analysis of the TLS record layer: [[BMMRT15]](https://tools.ietf.org/html/rfc8446#ref-BMMRT15), [[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16), [[BDFKPPRSZZ16]](https://tools.ietf.org/html/rfc8446#ref-BDFKPPRSZZ16), [[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17), and [[PS18]](https://tools.ietf.org/html/rfc8446#ref-PS18)

## III. Traffic Analysis

Based on the lengths and timing of observed encrypted packets, TLS is vulnerable to a variety of traffic analysis attacks [[CLINIC]](https://tools.ietf.org/html/rfc8446#ref-CLINIC) [[HCJC16]](https://tools.ietf.org/html/rfc8446#ref-HCJC16). This is especially easy when there is a small set of possible messages to distinguish among. For example, a video server hosting a fixed set of content can still provide useful information even in more complex scenarios.

TLS does not provide any specific defenses against such attacks, but it does provide a padding mechanism for applications to use: the plaintext protected by the AEAD function consists of content and variable-length padding, allowing applications to generate encrypted records of arbitrary length and also to send padding only, with the goal of cover traffic to hide the distinction between transmission periods and silent periods. Because the padding is encrypted together with the actual content, an attacker cannot directly determine the length of the padding, but can indirectly measure the padding through timing channels exposed during record processing (i.e., by observing how long it takes to process the record, or by trickling data into the record and seeing which inputs elicit a Server response). In general, it is not known how to eliminate all of these channels, because even a constant-time padding removal function may pass content to functions that depend on the data. At a minimum, a fully constant-time Server or Client needs close cooperation with the application-layer protocol implementation, including making higher-level protocol creation constant-time.

Note: Strong traffic analysis defenses may degrade performance due to increased latency and traffic for transmitted packets.

## IV. Side-Channel Attacks

In general, TLS does not include specific defenses against side-channel attacks (that is, attacks against communication through auxiliary channels, such as timing), but instead leaves these attacks to the implementers of the relevant cryptographic primitives. However, some TLS features are intended to make it easier to write code that defends against side-channel attacks:


- Unlike the composite MAC-then-encrypt constructions used in earlier TLS versions, TLS 1.3 uses only AEAD algorithms, allowing implementers to use self-contained constant-time implementations of these primitives.

- TLS uses a uniform "bad\_record\_mac" alert message for all decryption errors, with the goal of preventing an attacker from obtaining an oracle on portions of a message. Terminating the connection on this error raises the bar for the attacker; a new connection will have different cryptographic material, thereby preventing attacks on the cryptographic primitives via repeated trials.


Information leakage through side channels can occur at layers above TLS, such as application protocols and the applications that use them. Defenses against side-channel attacks depend on the application and the application protocol, both of which must separately ensure that confidential information is not inadvertently leaked.


## V. Replay Attacks on 0-RTT


Replayable 0-RTT data poses many security threats to applications that use TLS unless those applications are specifically designed to remain safe even when replayed (at a minimum, this means being idempotent, but in many cases it may require other, stronger conditions, such as constant-time responses). Potential attacks include:

- Actions that cause side effects (for example, purchasing an item or transferring money) are duplicated, harming the site or the user.

- An attacker can store and replay 0-RTT messages in order to reorder them with respect to other messages (for example, changing an original delete-then-create sequence into create-then-delete).

- Cache timing behavior can be exploited to discover the contents of a 0-RTT message by replaying the 0-RTT message to different cache nodes and then using a separate connection to measure request latency; this can also reveal whether the two requests address the same resource.

If data can be replayed many times, additional attacks may occur, such as repeatedly measuring the speed of cryptographic operations. In addition, they may overload rate-limited systems. For further discussion of these attacks, see [[Mac17]](https://tools.ietf.org/html/rfc8446#ref-Mac17)


Ultimately, the Server is responsible for protecting itself against attacks that duplicate 0-RTT data. The mechanisms described in [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay) are intended to prevent replay at the TLS layer, but they do not provide complete protection against the receipt of multiple copies of Client data. When the Server has no information about the Client, TLS 1.3 falls back to a 1-RTT handshake; for example, as described in [Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets), this can happen because the Client is in a different cluster that does not share state, or because the ticket has been deleted. If the application-layer protocol retransmits data in this setting, an attacker may trigger message duplication by sending the ClientHello to the original cluster (which immediately processes the data) and to another cluster that falls back to 1-RTT, causing the data to be processed when the application layer replays it. The scale of this attack is limited by the Client’s willingness to retry the transaction, and therefore permits only a limited amount of duplication; the Server treats each duplicate copy as a new connection.
If implemented correctly, the mechanisms described in [Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets) and [Section 8.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording) prevent a ClientHello replay and its associated 0-RTT data from being accepted more than once by any cluster with consistent state; for a Server that limits 0-RTT usage to one ticket per cluster, a given ClientHello and its associated 0-RTT data will be accepted only once. However, if state is not fully consistent, an attacker may be able to have multiple copies of the data accepted during the replication window. Because Clients do not know the exact details of Server behavior, they must not send replay-unsafe messages in early data, and they also should not be willing to retry those messages across multiple 1-RTT connections.


Application protocols must not use 0-RTT data unless a profile defining its use exists. That profile needs to specify which messages or interactions are safe to use with 0-RTT, and how to handle cases where the Server rejects 0-RTT and falls back to 1-RTT.


In addition, to avoid unintended misuse, TLS implementations must not enable 0-RTT (for either sending or receiving) unless the application specifically requests it. Unless the application has indicated otherwise, if the Server rejects 0-RTT, the 0-RTT data must not be retransmitted automatically. Server-side applications may want to implement special handling for certain types of application traffic carried in 0-RTT data (for example, aborting the connection, requesting retransmission at the application layer, or delaying processing until the handshake completes). To allow applications to implement such handling, TLS implementations must provide applications with a way to determine whether the handshake has completed.


### 1. Replay and Exporters

Replaying the ClientHello produces the same early exporters, so applications that use these exporters require additional care. In particular, if these exporters are used as authenticated channel bindings (for example, by signing the exporter output), an attacker who has compromised the PSK can transplant the authentication across connections without compromising the authentication key.

In addition, early exporters should not be used to generate Server-to-Client encryption keys, because that would imply reuse of those keys. This is analogous to using early application traffic keys only in the Client-to-Server direction.


## VI. PSK Identity Exposure

Because implementations respond to an invalid PSK binder by aborting the handshake, an attacker may be able to test whether a given PSK identity is valid. Specifically, if a Server accepts both external PSK handshakes and certificate-based handshakes, a valid PSK identity will cause the handshake to fail, while an invalid identity that is simply skipped may allow the certificate handshake to succeed. Servers that support only PSK handshakes can resist this form of attack by handling the case where no valid PSK identity is present in the same way as the case where an identity is present but has an invalid binder.

## VII. Sharing PSKs

TLS 1.3 takes a conservative approach to PSKs by binding a PSK to a specific KDF. By contrast, TLS 1.2 allows a PSK to be used with any hash function and with the TLS 1.2 PRF. Therefore, any PSK intended for use with both TLS 1.2 and TLS 1.3 must be used with only one hash in TLS 1.3, which is not ideal if the user wants to provide a single PSK. The constructions in TLS 1.2 and TLS 1.3 are different, although both are HMAC-based. While there is no known method for producing related outputs from the same PSK in both versions, only limited analysis has been performed. By not reusing PSKs between TLS 1.3 and TLS 1.2, implementations can ensure security against cross-protocol related outputs.

## VIII. Attacks on Static RSA

Although TLS 1.3 does not use RSA key transport and therefore is not directly affected by Bleichenbacher-style attacks [[Blei98]](https://tools.ietf.org/html/rfc8446#ref-Blei98), if a TLS 1.3 Server also supports static RSA in earlier versions of TLS, Server impersonation may be possible for TLS 1.3 connections [[JSS15]](https://tools.ietf.org/html/rfc8446#ref-JSS15). TLS 1.3 implementations can prevent such attacks by disabling support for static RSA across all versions of TLS. In principle, implementations might also be able to separate certificates with different keyUsage bits for static RSA decryption and RSA signatures, but this technique relies on Clients rejecting signatures made with keys from certificates that do not have the digitalSignature bit set, and many Clients do not enforce this restriction.


------------------------------------------------------

References:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Security\_Properties/](https://halfrost.com/tls_1-3_security_properties/)