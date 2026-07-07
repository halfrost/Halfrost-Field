# TLS 1.3 Overview of Security Properties


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/116_0.png'>
</p>


A complete security analysis of TLS is beyond the scope of this article. In this appendix, we provide an informal description of the required properties, along with references to more detailed work in the research literature that gives more formal definitions.

We separate the properties of the handshake from those of the record layer.


## I. Handshake

The TLS handshake is an authenticated key exchange (AKE) protocol designed to provide both one-way authentication (Server only) and mutual authentication (Client and Server). Upon completion of the handshake, each side outputs the following values:


- A set of "session keys" (various keys derived from the master secret), from which a set of working keys can be derived.

- A set of cryptographic parameters (algorithms, etc.).

- The identities of the communicating parties.

We assume that the attacker is an active network attacker, meaning it has complete control over the network used for communication between the parties [[RFC3552]](https://tools.ietf.org/html/rfc3552). Even under these conditions, the handshake should provide the properties listed below. Note that these properties are not necessarily independent; rather, they reflect the requirements of protocol consumers.

Establishment of identical session keys: the handshake needs to output the same set of session keys on both sides of the handshake, provided that it completes successfully at each endpoint (see [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01), Definition 1, Part 1).


Secrecy of session keys: the shared session keys should be known only to the communicating parties, not to the attacker (see [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01), Definition 1, Part 2). Note that in a connection with unilateral authentication, an attacker can establish its own session keys with the Server, but those session keys are different from the session keys established with the Client.

Peer authentication: the Client's view of the peer identity should reflect the Server's identity. If the Client has been authenticated, then the Server's view of the peer identity should match the Client's identity.

Uniqueness of session keys: any two distinct handshakes should produce distinct, unrelated session keys. The individual session keys produced by a handshake should also be distinct and independent.

Downgrade protection: both parties' cryptographic parameters should be the same, and they should be the same as they would be if the parties communicated in the absence of an attack (see [[BBFGKZ16]](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16), Definitions 8 and 9).

Forward secrecy with respect to long-term keys: if long-term key material (in this case, the signing key in certificate-based authentication modes, or the external/resumption PSK in PSK modes with (EC)DHE) is compromised after the handshake has completed, this should not affect the security of the session keys, as long as the session keys themselves have been deleted (see [[DOW92]](https://tools.ietf.org/html/rfc8446#ref-DOW92)). When a PSK is used in the "psk\_ke" PskKeyExchangeMode, the forward-secrecy property cannot be satisfied.

Key Compromise Impersonation (KCI) resistance: in a connection with mutual authentication via certificates, compromise of one participant's long-term key should not break that participant's authentication of the peer in this specific connection (see [[HGFS15]](https://tools.ietf.org/html/rfc8446#ref-HGFS15)). For example, if the Client's signing key is compromised, it should not be possible in subsequent handshakes to impersonate arbitrary Servers to communicate with the Client.

Protection of endpoint identities: the Server's identity (certificate) should be protected against passive attackers. the Client's identity should be protected against both passive and active attackers.

Informally, the signature-based modes of TLS 1.3 provide a unique, secret shared key established by an (EC)DHE key exchange, and authenticate the handshake with the Server's signature, along with a MAC associated with the Server's identity. If the Client authenticates with a certificate, it also signs the handshake transcript and provides a MAC associated with both identities. [[SIGMA]](https://tools.ietf.org/html/rfc8446#ref-SIGMA) describes the design and analysis of this type of key exchange protocol. If a fresh (EC)DHE key is used for each connection, then the output keys are forward secret.

External PSKs and resumption PSKs convert a long-term shared key into a set of short-term session keys that are unique to each connection. This key may have been established in a previous handshake. If the PSK was established using an (EC)DHE key, then these session keys will also be forward secret. Resumption PSKs have been designed so that the resumption master secret computed from connection N and needed to form connection N + 1 is separate from the traffic keys used by connection N, thereby providing forward secrecy between connections. In addition, if multiple tickets are established on the same connection, they are associated with different keys, so compromise of the PSK associated with one ticket does not cause connections established with PSKs associated with other tickets to be compromised as well. This property is most interesting when tickets are stored in a database (and therefore can be deleted), rather than being self-encrypted.

The value of the PSK binder creates a binding between the PSK and the current handshake, as well as a binding between the session in which the PSK was established and the current session. This binding transitively includes the original handshake transcript, because that transcript is used to produce the value of the resumption master secret. This requires both the KDF used to produce the resumption master secret and the MAC used to compute the binder to be collision-resistant. For details, see [Appendix E.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Security_Properties.md#1-key-derivation-and-hkdf). Note: the binder does not include the values of the binders for other PSKs, but they are included in the Finished MAC.


TLS currently does not allow the Server to send a certificate\_request message in a non-certificate-based handshake (for example, PSK). If this restriction is relaxed in the future, the Client's signature will not directly cover the Server's certificate. However, if the PSK was established via NewSessionTicket, the Client's signature will transitively cover the Server's certificate through the PSK binder. [PSK-FINISHED](https://tools.ietf.org/html/rfc8446#ref-PSK-FINISHED) describes concrete attacks against constructions that are not bound to the Server certificate (see also [Kraw16](https://tools.ietf.org/html/rfc8446#ref-Kraw16)). When the Client shares the same PSK / key ID pair with two different endpoints, using certificate-based Client authentication in this situation is not secure. Implementations MUST NOT combine external PSKs with certificate-based Client or Server authentication unless this is negotiated via some extension.


If exporters are used, they generate unique and secret values (because they are generated from unique session keys). Exporters computed with different labels and different contexts are computationally independent, so it is infeasible to derive the session keys from an exporter, or to compute one exporter from another. Note: exporters can generate values of arbitrary length; if an exporter is to be used as a channel binding, the exported value must be large enough to provide collision resistance. The exporters provided in TLS 1.3 are derived from the same handshake contexts as the early traffic keys and application traffic keys, respectively, and therefore have similar security properties. Note that they do not include the Client's certificate; applications that want to bind to the Client's certificate in the future may need to define new exporters that include the full handshake transcript.


For all handshake modes, the Finished MAC (and signatures, when present) prevents downgrade attacks. In addition, as described in [Section 4.1.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-server-hello), the use of certain bytes in the random nonce can detect downgrades to earlier versions of TLS. For more detail on TLS 1.3 and downgrade attacks, see [BBFGKZ16](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16).

Once the Client and Server have exchanged enough information to establish a shared key, the remainder of the handshake is encrypted, providing protection against passive attackers even if the computed shared key has not been authenticated. Because the Server authenticates before the Client, the Client can ensure that, if it authenticates the Server, it reveals its identity only to a Server that has already been authenticated. Note that implementations must use the record padding mechanism provided during the handshake (which can obscure length information) to avoid leaking identity-related information through lengths. The PSK identity proposed by the Client is not encrypted, nor is the identity selected by the Server.


### 1. Key Derivation and HKDF

Key derivation in TLS 1.3 uses HKDF as defined in [[RFC5869]](https://tools.ietf.org/html/rfc5869) and its two components, HKDF-Extract and HKDF-Expand. The HKDF data structure can be found in [[Kraw10]](https://tools.ietf.org/html/rfc8446#ref-Kraw10), and [[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16) explains how it is used soundly in TLS 1.3. Throughout this document, each application of HKDF-Extract is followed by one or more invocations of HKDF-Expand. This order should always be followed (including in future revisions of this document); in particular, we should not use the output of HKDF-Extract directly as input to another application of HKDF-Extract without an intervening HKDF-Expand invocation. Multiple applications of HKDF-Expand are allowed to use the same input as long as those inputs can be distinguished by keys or labels.

Note that HKDF-Expand implements a pseudorandom function (PRF) with variable-length inputs and outputs. In this document, for some uses of HKDF (for example, generating exporters and resumption\_master\_secret), the application of HKDF-Expand must be collision-resistant; that is, it must be infeasible for two distinct input values to cause HKDF-Expand to output the same value. This requires the underlying hash function to be collision-resistant and the output length of HKDF-Expand to be at least 256 bits (or whatever length is required by the hash function to prevent finding collisions).

### 2. Client Authentication

During the handshake or during post-handshake authentication, a Client that has sent authentication data to the Server cannot determine whether the Server subsequently considers the Client authenticated. If the Client needs to determine whether the Server considers the connection unilaterally authenticated or mutually authenticated, this must be configured at the application layer. For details, see [[CHHSV17]](https://tools.ietf.org/html/rfc8446#ref-CHHSV17). In addition, the analysis of post-handshake authentication from [[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16) shows that the Client identified by the certificate sent in the post-handshake phase possesses the traffic keys. Therefore, that party is either the Client that participated in the original handshake, or a Client proxying the traffic keys for the original Client (assuming the traffic keys have not been compromised).


### 3. 0-RTT

The 0-RTT mode of operation generally provides security properties similar to those of 1-RTT data, with two exceptions: 0-RTT encryption keys do not provide full forward secrecy, and the Server cannot guarantee uniqueness (non-replayability) of the handshake without retaining excessive state. For mechanisms to limit replay risk, see [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay).


### 4. Exporter Independence

The derivation of exporter\_master\_secret and early\_exporter\_master\_secret is independent of the traffic keys, and therefore does not threaten the security of traffic encrypted with those keys. However, because these keys can be used to compute any exporter value, they should be deleted as soon as possible. If the complete set of exporter labels is known, implementations should precompute the internal Derive-Secret values for all of those labels during exporter computation, and then delete the [early\_] exporter\_master\_secret as soon as it is known to be no longer needed; each internal value that follows it can likewise be deleted as soon as it is no longer needed.


### 5. Post-Compromise Security

TLS does not provide security for handshakes that occur after a peer's long-term key (signing key or external PSK) has been compromised. Therefore, it does not provide post-compromise security [[CCG16]](https://tools.ietf.org/html/rfc8446#ref-CCG16), sometimes also called backward or future secrecy. This is the opposite of KCI resistance, which describes the security guarantees that one side of the communication has after its own long-term key has been compromised.


### 6. External References

Readers should consult the following references for analyses of the TLS handshake: [[DFGS15]](https://tools.ietf.org/html/rfc8446#ref-DFGS15), [[CHSV16]](https://tools.ietf.org/html/rfc8446#ref-CHSV16), [[DFGS16]](https://tools.ietf.org/html/rfc8446#ref-DFGS16), [[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16), [[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16), [[FGSW16]](https://tools.ietf.org/html/rfc8446#ref-FGSW16), [[LXZFH16]](https://tools.ietf.org/html/rfc8446#ref-LXZFH16), [[FG17]](https://tools.ietf.org/html/rfc8446#ref-FG17), and [[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17).


## II. Record Layer


The record layer relies on the handshake to produce strong traffic keys, which can be used to derive bidirectional encryption keys and nonces. Assuming this is true, and assuming keys are not used for more data than indicated in [Section 5.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Record_Protocol.md#%E4%BA%94-limits-on-key-usage), the record layer should provide the following guarantees:


- Confidentiality: an attacker should not be able to infer the plaintext contents of a given record.

- Integrity: an attacker should not be able to create a new message that can be accepted by the receiver, where that new message is a new record different from any existing record.

- Order protection/non-replayability: an attacker should not be able to make the receiver accept a record that it has already accepted (non-replayability), or make the receiver accept record N + 1 without first processing record N (ordering).

- Length hiding: for a record with a given external length, an attacker should not be able to determine how much of the record is content and how much is padding.

- Forward secrecy after key change: if the traffic key update mechanism described in [Section 4.6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update) is used and the previous-generation keys are deleted, an attacker that compromises an endpoint should not be able to decrypt ciphertext encrypted with old keys.


Informally, TLS 1.3 provides its security properties through AEAD: protecting plaintext with strong keys. AEAD encryption [[RFC5116]](https://tools.ietf.org/html/rfc5116) provides confidentiality and integrity for data. Non-replayability is provided by using a separate nonce for each record, where the nonce comes from the record sequence number ([Section 5.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%89-per-record-nonce)), and the sequence number is maintained independently on both sides; as a result, records delivered out of order cause AEAD deprotection to fail. When different users repeatedly encrypt the same plaintext under the same key (which is often the case for HTTP), to prevent large-scale cryptanalysis in this situation, the nonce is formed by mixing the sequence number with a per-connection initialization vector key derived together with the traffic keys. For an analysis of this construction, see [[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16).


The key update technique in TLS 1.3 (see [Section 7.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%BA%8C-updating-traffic-secrets)) follows the construction of serial generators discussed in [[REKEY]](https://tools.ietf.org/html/rfc8446#ref-REKEY), which shows that key updates can allow keys to be used for a large number of encryptions without rekeying. This relies on the security of HKDF-Expand-Label as a pseudorandom function (PRF). In addition, as long as this function is genuinely one-way, it is infeasible to compute the traffic keys from before the key change (forward secrecy).

After the traffic keys for a connection have been compromised, TLS does not provide security for data transmitted over that connection. That is, TLS does not provide post-compromise security/future secrecy/backward secrecy for traffic keys. In practice, an attacker who knows the traffic keys can compute all future traffic keys on that connection. Systems that need to defend against such attacks need to perform a new handshake and establish a new connection using an (EC)DHE exchange.

### 1. External References

Readers should consult the following references when analyzing the TLS record layer: [[BMMRT15]](https://tools.ietf.org/html/rfc8446#ref-BMMRT15), [[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16), [[BDFKPPRSZZ16]](https://tools.ietf.org/html/rfc8446#ref-BDFKPPRSZZ16), [[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17), and [[PS18]](https://tools.ietf.org/html/rfc8446#ref-PS18)

## III. Traffic Analysis

Based on observations of the length and timing of encrypted packets, TLS is vulnerable to various traffic analysis attacks [[CLINIC]](https://tools.ietf.org/html/rfc8446#ref-CLINIC) [[HCJC16]](https://tools.ietf.org/html/rfc8446#ref-HCJC16). This is particularly easy when there is a small set of possible messages to distinguish, such as a video server hosting a fixed set of content, and it can still provide useful information even in more complex scenarios.

TLS does not provide any specific defenses against such attacks, but it does provide a padding mechanism for applications to use: plaintext protected by AEAD consists of content plus variable-length padding, allowing applications to generate encrypted records of arbitrary length, and also allowing padding-only records, with the goal of providing cover traffic to hide the difference between transmission periods and idle periods. Because the padding is encrypted together with the actual content, an attacker cannot directly determine the length of the padding, but can measure it indirectly through timing channels exposed during record processing (i.e., by observing how long it takes to process the record, or by trickling the record in and seeing which parts elicit a response from the Server). In general, it is not known how to eliminate all such channels, because even a constant-time padding removal function may deliver content to data-dependent functionality. At a minimum, a fully constant-time Server or Client requires close cooperation with the application-layer protocol implementation, including making the construction of higher-level protocols constant-time.

Note: Due to increased packet delay and traffic volume, strong traffic analysis defenses may degrade performance.

## IV. Side-Channel Attacks

In general, TLS does not provide specific defenses against side-channel attacks (i.e., attacks on communication through auxiliary channels such as timing), but leaves these attacks to the implementers of the relevant cryptographic primitives. However, some TLS features are designed to make it easier to write code that defends against side-channel attacks:


- Unlike the composite MAC-then-encrypt construction used in previous TLS versions, TLS 1.3 uses only AEAD algorithms, allowing implementers to use the constant-time implementations that are self-contained within these primitives.

- TLS uses a uniform "bad\_record\_mac" alert message for all decryption errors, with the goal of preventing attackers from obtaining a partitioning oracle over message components. Terminating the connection on this error raises the bar for attackers; a new connection will have different cryptographic material, thereby preventing attacks on cryptographic primitives through repeated trials.


Information leakage through side channels may occur at layers above TLS, such as in application protocols and the applications that use them. Defenses against side-channel attacks depend on the application and the application protocol, both of which must separately ensure that confidential information is not inadvertently leaked.


## V. Replay Attacks on 0-RTT


Replayable 0-RTT data poses many security threats to applications that use TLS, unless those applications are specifically designed to be safe even when replayed (at a minimum, this means idempotence, but in many cases it may also require other stronger conditions, such as constant-time responses). Potential attacks include:

- Actions that cause side effects (for example, purchasing an item or transferring money) being duplicated, thereby harming the site or the user.

- An attacker can store and replay 0-RTT messages in order to reorder them with other messages (for example, changing an original delete-then-create sequence into create-then-delete).

- Cache-timing behavior can be exploited to discover the contents of 0-RTT messages by replaying a 0-RTT message to different cache nodes and then using separate connections to measure request latency; this can also reveal whether the two requests address the same resource.

If the data can be replayed many times, additional attacks may occur, such as repeatedly measuring the speed of cryptographic operations. In addition, they may overload systems that apply rate limiting. For further discussion of these attacks, see [[Mac17]](https://tools.ietf.org/html/rfc8446#ref-Mac17)


Ultimately, the Server is responsible for protecting itself against attacks that use copied 0-RTT data. The mechanisms described in [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay) are intended to prevent replay at the TLS layer, but they do not provide complete protection against receiving multiple copies of Client data. When the Server has no information about the Client, TLS 1.3 falls back to a 1-RTT handshake; for example, as described in [Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets), this can happen because the Client is in different clusters that do not share state, or because the ticket has been deleted. If the application-layer protocol retransmits data in this setting, an attacker may induce message duplication by sending the ClientHello to the original cluster (which will process the data immediately) and to another cluster that will fall back to 1-RTT, causing the data to be processed when the application layer replays it. The scale of this attack is limited by the Client's willingness to retry the transaction, so it permits only a limited amount of duplication, and the Server treats each duplicate copy as a new connection.

If implemented correctly, the mechanisms described in [Section 8.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets) and [Section 8.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording) prevent a ClientHello replay and its associated 0-RTT data from being accepted more than once by any cluster with consistent state; for Servers that restrict the use of 0-RTT to one ticket within one cluster, a given ClientHello and its associated 0-RTT data will be accepted only once. However, if the state is not fully consistent, an attacker may be able to have multiple copies of the data accepted during the replay window. Because Clients do not know the specific details of Server behavior, they must not send replay-unsafe messages in early data, and they should also be unwilling to retry such messages over multiple 1-RTT connections.


Application protocols must not use 0-RTT data unless a profile defining its use exists. That profile needs to determine which messages or interactions can be safely used with 0-RTT, and how to handle the case where the Server rejects 0-RTT and falls back to 1-RTT.


In addition, to avoid accidental misuse, TLS implementations must not enable 0-RTT (for either sending or receiving) unless the application specifically requests it. Unless the application provides the relevant indication, 0-RTT data must not be automatically resent if the Server rejects 0-RTT. Server-side applications may want to implement special handling for 0-RTT data for certain types of application traffic (for example, aborting the connection, requesting retransmission of the data at the application layer, or delaying processing until the handshake completes). To allow applications to implement such handling, TLS implementations must provide applications with a way to determine whether the handshake has completed.


### 1. Replay and Exporters

Replaying a ClientHello produces the same early exporters, so applications that use these exporters require additional care. In particular, if these exporters are used as authenticated channel bindings (for example, signing the output of an exporter), then an attacker who has compromised the PSK can transplant the authentication between connections without compromising the authentication key.

In addition, early exporters should not be used to generate encryption keys from the Server to the Client, because doing so would imply reuse of those keys. This is analogous to using early application traffic keys only in the Client-to-Server direction.


## VI. PSK Identity Exposure

Because implementations respond to invalid PSK binders by aborting the handshake, an attacker may be able to verify whether a given PSK identity is valid. Specifically, if a Server accepts both external PSK handshakes and certificate-based handshakes, a valid PSK identity will cause the handshake to fail, whereas an invalid identity that is merely skipped can allow the certificate handshake to succeed. Servers that support only PSK handshakes can resist this form of attack by treating the case where there is no valid PSK identity the same as the case where an identity is present but has an equally invalid binder.

## VII. Sharing PSKs

TLS 1.3 takes a conservative approach to PSKs by binding each PSK to a specific KDF. By contrast, TLS 1.2 allows PSKs to be used with any hash function and the TLS 1.2 PRF. Therefore, any PSK intended for use in both TLS 1.2 and TLS 1.3 must be used with only one hash in TLS 1.3, which is not ideal if the user wants to provide a single PSK. The constructions in TLS 1.2 and TLS 1.3 are different, even though both are based on HMAC. Although there is no known method for using the same PSK in both versions to produce related outputs, only limited analysis has been performed. By not reusing PSKs between TLS 1.3 and TLS 1.2, implementers can ensure security against cross-protocol related outputs.

## VIII. Attacks on Static RSA

Although TLS 1.3 does not use RSA key transport and is therefore not directly affected by Bleichenbacher-style attacks [[Blei98]](https://tools.ietf.org/html/rfc8446#ref-Blei98), if a TLS 1.3 Server also supports static RSA in earlier versions of TLS, impersonated Servers may arise for TLS 1.3 connections [[JSS15]](https://tools.ietf.org/html/rfc8446#ref-JSS15). TLS 1.3 implementers can prevent such attacks by disabling support for static RSA across all versions of TLS. In principle, implementers might also be able to use separate certificates with different keyUsage bits for static RSA decryption and RSA signatures, but this technique depends on Clients refusing to accept signatures made with keys from certificates that do not have the digitalSignature bit set, and many Clients do not enforce this restriction.


------------------------------------------------------

References:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Security\_Properties/](https://halfrost.com/tls_1-3_security_properties/)