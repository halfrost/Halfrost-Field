+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2019-01-20T05:57:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/119_0.png"
slug = "https_record_layer"
tags = ["Protocol", "HTTPS"]
title = "HTTPS: Reviewing the Old, Learning the New (II) — TLS Record Layer Protocol"

+++


The TLS record protocol is a layered protocol. At each layer, messages may contain fields such as length, description, and content. The main functions of the record protocol include encapsulating the messages to be sent, fragmenting data into manageable blocks, optionally compressing data, applying a MAC, encrypting, and transmitting the final data. Received data is decrypted, verified, decompressed, reassembled, and then passed to higher-level applications.

It is particularly important to note that the type and length of a record message are not protected by encryption; they are in plaintext. If this information is sensitive, application designers may want to take measures such as padding and cover traffic to reduce information leakage.

In this article, we focus on the differences between TLS 1.2 and TLS 1.3 at the record layer. Let’s start with what they have in common.

## I. Connection State in the TLS Record Layer

The state of a TLS connection is the operating environment of the TLS record protocol. It specifies a compression algorithm, an encryption algorithm, and a MAC algorithm. In addition, the parameters for these algorithms must be known: the MAC keys and block cipher keys for the read and write directions of the connection. Logically, there are always four prominent states: the read and write states, and the pending read and write states. All record protocol processing is performed under the current read/write states. The security parameters of the pending states can be set through the TLS handshake protocol, while ChangeCipherSpec can optionally make the current state become the pending state. In that case, the appropriate current state is set and replaced by the pending state; the pending state is then reinitialized to an empty state. It is illegal to set a state as a current state before its security parameters have been initialized. The initial current state always specifies that no encryption, compression, or MAC is used.

> ChangeCipherSpec has been removed from the official TLS 1.3 specification, but for compatibility with older TLS 1.2 implementations or network middleboxes, this protocol may still exist.

Simply put, before establishing a connection, both Client and Server are in the following state:
```c
      pending read status pending read status
      pending write status pending write status
```
Once the peer's ChangeCipherSpec message is received, the Client and Server begin switching to:
```c
      current read status readable status
      current write status writable status
```
Before receiving the peer's ChangeCipherSpec, all TLS handshake messages are processed in plaintext, without confidentiality or integrity protection. Once all encryption parameters are ready, the connection transitions into a readable and writable state; after entering that state, encryption and integrity protection begin.

The security parameters for the read and write states of a TLS connection can be set by providing the following values:
```c
      enum { server, client } ConnectionEnd;
```
- Connection endpoint:    
  In this connection, this entity is considered the "client" or the "server".
```c
      enum { tls_prf_sha256 } PRFAlgorithm;
```
- PRF algorithm:    
  The algorithm used to derive keys from the master secret. **In TLS 1.2, the cryptographic primitive used by the PRF by default is SHA256**. In the TLS 1.2 handshake protocol, this function is used to convert the premaster secret into the master secret, and the master secret into the key block. **This changed significantly in TLS 1.3; the specific changes will be discussed in the handshake protocol section**.
```c
      enum { null, rc4, 3des, aes }
        BulkCipherAlgorithm;
        
      enum { stream, block, aead } CipherType;
```
- Block encryption algorithm:    
  The algorithm used for block encryption. It includes the algorithm’s key length, whether it is a block cipher, stream cipher, or AEAD cipher, the ciphertext block size (if applicable), and the lengths of the explicit and implicit initialization vectors (or nonces).
```c
      enum { null, hmac_md5, hmac_sha1, hmac_sha256,
           hmac_sha384, hmac_sha512} MACAlgorithm;
```
- MAC algorithm:  
  The algorithm used for message authentication. Includes the length of the value returned by the MAC algorithm.
```c
      enum { null(0), (255) } CompressionMethod;
      
      /* Algorithms specified by CompressionMethod, PRFAlgorithm,
         BulkCipherAlgorithm, and MACAlgorithm can be added */   
```
- Compression algorithm:  
  The algorithm used for data compression. The specification must include all information required for the algorithm to perform compression.

- Master secret:    
  A 48-byte secret shared between the two ends of the connection.
  
- Client random:  
  A 32-byte random value provided by the client.
               
- Server random:  
  A 32-byte random value provided by the server.

Based on the parameters above, the data structure for the security parameters is as follows:
```c
      struct {
          ConnectionEnd          entity;
          PRFAlgorithm           prf_algorithm;
          BulkCipherAlgorithm    bulk_cipher_algorithm;
          CipherType             cipher_type;
          uint8                  enc_key_length;
          uint8                  block_length;
          uint8                  fixed_iv_length;
          uint8                  record_iv_length;
          MACAlgorithm           mac_algorithm;  /*mac algorithm*/
          uint8                  mac_length;     /*length of the mac value*/
          uint8                  mac_key_length; /*length of the mac algorithm key*/
          CompressionMethod      compression_algorithm;
          opaque                 master_secret[48];
          opaque                 client_random[32];
          opaque                 server_random[32];
      } SecurityParameters;
```
The TLS handshake protocol populates the encryption parameters above, and the TLS record layer then uses the security parameters to produce the following six entries (some of which are not required by all algorithms and are therefore left empty):
```c
      client write MAC key
      server write MAC key
      client write encryption key
      server write encryption key
      client write IV
      server write IV
```
Here are two sets of MAC keys, encryption keys, and initialization vectors. The reason is that the two communicating parties, the Client and the Server, each maintain their own SecurityParameters.

When the Server receives and processes records, it uses the Client write parameters, and vice versa. For example, the Client uses the client write MAC key, client write encryption key, and client write IV key block to encrypt a message. After the Server receives it, the Server also needs to use the Client’s client write MAC key, client write encryption key, and client write IV key block to decrypt it.


Once the security parameters have been set and the keys have been generated, the connection states can initialize them by setting them as the current states. These current states must be updated after each record is processed. Each connection state contains the following elements:

- Compression state:  
  The current state of the compression algorithm. **Compression is generally not enabled**, because compression may introduce security issues. The specific issues will be analyzed in detail in the article on TLS security.

- Cipher state:  
  The current state of the encryption algorithm, namely the encryption algorithm used by each connection and the key block used by that encryption algorithm. This state consists of the connection’s scheduled keys. For stream ciphers, this state also contains any necessary state information required to encrypt and decrypt the stream data.
        
- MAC key:  
  The MAC key for the current connection.

- Sequence number:  
  Each connection state contains a sequence number; the read state and the write state each maintain their own sequence number. When a connection state is activated, the sequence number must be set to 0. The sequence number type is uint64, so the sequence number value will not exceed 2^64-1. The sequence number must not wrap. If a TLS implementation needs to wrap the sequence number, it must renegotiate. A sequence number is automatically incremented after each record message is sent. In particular, the first record message sent under a given connection state must use sequence number 0. **The sequence number itself is not included in TLS record layer protocol messages**.


## II. TLS Record Layer Protocol Processing Steps

The TLS record layer protocol processes messages passed down from upper layers. The processing is mainly divided into 4 steps:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_1_1.png'>
</p>

- Data fragmentation
- Data compression/data padding (data compression in TLS 1.2, data padding in TLS 1.3; both compression and padding are optional)
- Encryption and integrity protection (in TLS 1.2, there are mainly three modes: stream cipher mode, block cipher mode, and AEAD mode; in TLS 1.3, there is **only** AEAD mode)
- Adding the message header

Next, let’s look at the details of these 4 processing steps in order:

### 1. Data Fragmentation

#### (1) TLS 1.2

The record layer fragments information blocks into TLSPlaintext records that store data in blocks of 2^14 bytes or less. **TLSPlaintext is the data structure after fragmentation by the TLS record layer**. Client message boundaries are not preserved in the record layer (that is, multiple Client messages of the same content type may be coalesced into a single TLSPlaintext, or a message may be fragmented into multiple records).
```c
      struct {
          uint8 major;
          uint8 minor;
      } ProtocolVersion;

      enum {
          change_cipher_spec(20), 
          alert(21), 
          handshake(22),
          application_data(23), 
          (255)
      } ContentType;

      struct {
          ContentType type;
          ProtocolVersion version;
          uint16 length;
          opaque fragment[TLSPlaintext.length];
      } TLSPlaintext;
```
- type:    
  The high-level protocol type used to process the encapsulated fragment.

- version:  
  The protocol version. The version for TLS 1.2 is {3,3}. The version value 3.3 is historical, because TLS 1.0 used {3,1}. Note that a Client supporting multiple TLS versions may not know the final version until it receives the ServerHello.

- length:  
  The length of TLSPlaintext.fragment (in bytes). This length must not exceed 2^14.

- fragment:  
  Application data. This data is transparent and is processed as an independent block by the high-level protocol specified by the type field.

Implementations must not send handshake, alert, or ChangeCipherSpec content types with fragments of length 0. Sending application data with a fragment length of 0 can be useful for traffic analysis mitigation.

Note: Data of different TLS record-layer content types may be interleaved. Application data usually has lower transmission priority than other content types. However, records must be transmitted to the network in the order in which the record layer can provide protection. The receiver must accept and process application-layer traffic interleaved after the first handshake message on a connection.

Multiple submessages of the same protocol can be coalesced into a single TLS record-layer protocol data structure. For example, multiple submessages in the handshake protocol all have type handshake; only the data segment lengths differ, while the data structure can still be TLSPlaintext.


#### (2) TLS 1.3

In the TLS 1.2 specification, there are four high-level protocols: change\_cipher\_spec, alert, handshake, and application\_data. In the TLS 1.3 specification, there are also four high-level protocols: alert, handshake, application\_data, and heartbeat.
```c
      struct {
          ContentType type;
          ProtocolVersion legacy_record_version;
          uint16 length;
          opaque fragment[TLSPlaintext.length];
      } TLSPlaintext;
```
The `TLSPlaintext` data structure did not change in TLS 1.3, and the meanings of its fields remain exactly the same. However, several new field values were added.

In TLS 1.3, `ContentType` adds the new `heartbeat(24)` type.
```c
      enum {
          invalid(0),
          change_cipher_spec(20),
          alert(21),
          handshake(22),
          application_data(23),
          heartbeat(24),  /* RFC 6520 */
          (255)
      } ContentType;
```
ProtocolVersion exists for compatibility with versions prior to TLS 1.3; this field has been deprecated in TLS 1.3.

In TLS 1.3, version is 0x0304. The mapping between previous versions and version is as follows:

|Protocol Version|version|
|:---:|:---:|
|TLS 1.3 |0x0304 |
|TLS 1.2 |0x0303 |
|TLS 1.1 |0x0302 |
|TLS 1.0 |0x0301 |
|SSL 3.0 |0x0300 |


In TLS 1.3, multiple submessages of the same protocol can also be coalesced into a single TLSPlaintext, but the rules in TLS 1.3 are stricter than those enforced in TLS 1.2. For example, handshake messages can be coalesced into a single TLSPlaintext record or fragmented across several records, provided that:

- Handshake messages must not be interleaved with other record types. That is, if a handshake message is split across two or more records, there must not be any other records between them.

- Handshake messages must never span a key change. Implementations must verify that all messages before a key change are aligned with record boundaries; if they are not, they must terminate the connection with an "unexpected_message" alert. Because ClientHello, EndOfEarlyData, ServerHello, Finished, and KeyUpdate messages can occur immediately before a key change, implementations must align these messages with record boundaries.

In addition, in TLS 1.3, Alert messages are prohibited from being fragmented across records, and multiple alert messages must not be coalesced into a single TLSPlaintext record. In other words, a record of type alert must contain exactly one message.

The above describes the differences between TLS 1.3 and TLS 1.2 in how data is fragmented at the TLS record layer. General properties that exist in TLS 1.2 also apply in TLS 1.3. For example, implementations must never send zero-length fragments of handshake type, even if those fragments contain padding; application data fragments may be split across multiple records or coalesced into a single record. In the following sections, commonalities between TLS 1.3 and TLS 1.2 will not be repeated; only the differences between TLS 1.3 and TLS 1.2 will be compared.


### 2. Data Compression

#### (1) TLS 1.2

All records must be compressed using the compression algorithm defined in the current session state. The compression algorithm here must always be active; however, initially it is defined as CompressionMethod.null. The compression algorithm transforms a TLSPlaintext structure into a TLSCompressed structure. When the connection state is activated, the compression function is initialized using default state information. For details, see the compression algorithms for TLS described in [RFC3749](https://tools.ietf.org/html/rfc3749).

Compression must be lossless and must not increase the content length by more than 1024 bytes. If the decompression function encounters a TLSCompressed.fragment whose decompressed length exceeds 2^14 bytes, it must report a fatal decompression failure error.

After compression, the resulting message structure is as follows:
```c
      struct {
          ContentType type;       /* same as TLSPlaintext.type */
          ProtocolVersion version;/* same as TLSPlaintext.version */
          uint16 length;
          opaque fragment[TLSCompressed.length];
      } TLSCompressed;
```
- length:  
  The length of TLSCompressed.fragment (in bytes). This length must not exceed 2^14 + 1024.

- fragment:  
  The compressed form of TLSPlaintext.fragment.

Note: A CompressionMethod.null operation is an identity operation and does not change any fields. That is, if no compression is performed, a TLSPlaintext record and a TLSCompressed record are equivalent.

In addition, the decompression function must also ensure that messages do not cause internal buffer overflows.

**Due to security issues, compression algorithms are generally not enabled in TLS 1.2**.


#### (2) TLS 1.3

In TLS 1.3, data compression was removed entirely because of prior security issues. In TLS 1.3, a new optional operation, data padding, was added before encryption and integrity protection at the TLS record layer.

Data padding allows all TLS records to be padded, thereby increasing the size of TLSCiphertext. This approach allows the sender to hide traffic sizes from observers.

When generating TLSCiphertext records, implementations may choose to pad them. **An unpadded record is simply a record with a padding length of zero**. Padding is a sequence of zero-valued bytes appended to the ContentType field before encryption. Implementations must set all padding octets to zero before encryption.

If the sender needs to, application data records may contain zero-length TLSInnerPlaintext.content. This allows reasonably sized cover traffic to be generated when the presence or absence of activity is sensitive. Implementations must never send handshake or alert records with zero-length TLSInnerPlaintext.content; if such a message is received, the receiving implementation must terminate the connection with an "unexpected\_message" alert message.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_5_.png'>
</p>
```c
      struct {
          opaque content[TLSPlaintext.length];
          ContentType type;
          uint8 zeros[length_of_padding];
      } TLSInnerPlaintext;
```
- content:  
	TLSPlaintext.fragment value, containing the byte encoding of a handshake or alert message, or the raw bytes of the application data to be sent.
	
- type:  
	TLSPlaintext.type value, containing the content type of the record.

- zeros:  
	Any number of zero-valued bytes may appear in the plaintext after the type field. As long as the total remains within the record size limit, this field gives the sender an opportunity to pad any TLS record by an amount of its choosing.
	

The padding sent is automatically verified by the record protection mechanism; after successfully decrypting TLSCiphertext.encrypted\_record, the receiving implementation scans the field backward from the end until it finds a non-zero octet. That non-zero octet is the message’s content type field, type. This padding scheme was chosen because it allows any encrypted TLS record to be padded to an arbitrary size (from zero up to the TLS record size limit) without introducing a new content type. The design also enforces all-zero padding octets so that padding errors can be detected quickly. **The step of removing Padding is the main process for restoring TLSInnerPlaintext to TLSPlaintext**.

Implementations MUST limit the scan to the plaintext returned by AEAD decryption. If the receiving implementation does not find a non-zero octet in the plaintext, it MUST terminate the connection with an "unexpected\_message" alert message.

Padding does not change the overall record size limit: the fully encoded TLSInnerPlaintext MUST NOT exceed 2 ^ 14 + 1 octets. If the maximum fragment length is reduced—for example, by the record\_size\_limit extension from [RFC8449]—then the reduced limit applies to the complete plaintext, including the content type and padding.


### 3. Encryption and Integrity Protection

After the data has been compressed (if compression is used), the next step is encryption and integrity protection. In TLS 1.2, TLSCompressed is converted into TLSCiphertext through encryption and MAC computation. In TLS 1.3, TLSInnerPlaintext is converted into TLSCiphertext.

#### (1) TLS 1.2

First, let’s look at how the record protocol in TLS 1.2 performs encryption and integrity protection. In TLS 1.2, the record layer protocol supports three encryption modes:
```c
      struct {
          ContentType type;
          ProtocolVersion version;
          uint16 length;
          select (SecurityParameters.cipher_type) {
              case stream: GenericStreamCipher;
              case block:  GenericBlockCipher;
              case aead:   GenericAEADCipher;
          } fragment;
      } TLSCiphertext;
```
- type:  
  The `type` value here is the same as `TLSCompressed.type`.

- version:  
  The `version` value here is the same as `TLSCompressed.version`.

- length:  
  `length` represents the length, in bytes, of the following `TLSCiphertext.fragment`. This length must not exceed 2^14 + 2048.

- fragment:  
  The encrypted form of `TLSCompressed.fragment`; after encryption, a MAC must be appended to the end.
  
One point to clarify here is what is included in the MAC value appended at the end. **The record MAC includes a sequence number, which is used to detect lost, inserted, and duplicate messages**.


#### I. Standard Stream Encryption or Null Encryption

Stream encryption (including `BulkCipherAlgorithm.null`) converts the `TLSCompressed.fragment` structure into a stream-oriented `TLSCiphertext.fragment` structure.
```c
        stream-ciphered struct {
          opaque content[TLSCompressed.length];
          opaque MAC[SecurityParameters.mac_length];
      } GenericStreamCipher;
```
The MAC value is generated as follows:
```c
        MAC(MAC_write_key, seq_num +
                            TLSCompressed.type +
                            TLSCompressed.version +
                            TLSCompressed.length +
                            TLSCompressed.fragment);
```
The “+” above denotes concatenation.


- seq\_num:  
  The sequence number of this record.

- MAC:  
  The MAC algorithm specified by SecurityParameters.mac\_algorithm.

Note that the MAC value is computed before encryption. A stream cipher encrypts the entire block, including the MAC. For stream ciphers that do not use a synchronization vector (such as RC4), the stream cipher state at the end of one record can simply be used for subsequent packets. If the cipher suite is TLS\_NULL\_WITH\_NULL\_NULL, encryption consists of the identity operation (that is, the data is not encrypted, and the MAC size is 0, meaning no MAC is used). For null encryption and stream encryption, TLSCiphertext.length is equal to TLSCompressed.length plus SecurityParameters.mac\_length. In other words, the MAC length is determined by the encryption parameter SecurityParameters.

The complete flow for stream encryption is shown below:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_2.png'>
</p>

In stream cipher or null-encryption mode, the MAC value is computed first. The MAC takes five input parameters: the sequence number, the type, the protocol version, the fragment length, and the fragment. After the MAC value is computed, the encryption algorithm encrypts it to produce the final ciphertext. This is the MAC-then-encrypt mode. (**Note: the message header is not encrypted**)

When computing the MAC value, one of the inputs is the seq num sequence number. **The primary purpose of the sequence number is to prevent replay attacks**. The client records client\_send and client\_recv in memory. Each time the client sends a message, client\_send is incremented by one; each time it receives a message from the server, client\_recv is incremented by one. The server also records server\_send and server\_recv in memory, serving the same purpose as on the client. Each time the server sends a message, server\_send is incremented by one; each time it receives a message from the client, server\_recv is incremented by one. If sending and receiving are both normal, then client\_send = server\_recv and client\_recv = server\_send. The default values of client\_send, server\_recv, client\_recv, and server\_send are all 0.

The relationship between the sequence number and the MAC value is that the actual sequence number of the message being sent or received is one greater than the sequence number used to compute the MAC value. Why is that? For example, when sending the 5th message, the message reaches the TLS record layer. Since this send has not yet completed successfully, the current client\_send = 4. When computing the MAC value, the sequence number is 4. After the send succeeds, client\_send ++ becomes 5. Similarly, when receiving the 9th message, the current client\_recv = 8. When verifying the MAC, the current value of client\_recv is used for verification. After the message is confirmed to be valid, client\_recv ++ becomes 9.

#### II. Block Encryption

In TLS 1.2, block encryption mainly refers to CBC block encryption.

For block encryption algorithms (such as 3DES or AES), the encryption and MAC functions transform TLSCompressed.fragment into the TLSCiphertext.fragment structure block.
```c
   struct {
          opaque IV[SecurityParameters.record_iv_length];
          block-ciphered struct {
              opaque content[TLSCompressed.length];
              opaque MAC[SecurityParameters.mac_length];
              uint8 padding[GenericBlockCipher.padding_length];
              uint8 padding_length;
          };
      } GenericBlockCipher;
```
The MAC generation method is the same as the MAC generation method used in stream encryption.
```c
        MAC(MAC_write_key, seq_num +
                            TLSCompressed.type +
                            TLSCompressed.version +
                            TLSCompressed.length +
                            TLSCompressed.fragment);
```
- IV:  
  The initialization vector (IV) should be generated randomly and must be unpredictable. Note that TLS versions prior to TLS 1.1 do not have an IV field. The last ciphertext block of the previous record (the remainder of the final CBC block) was used as the IV. A random IV is used to prevent the attack described in [[CBCATT]](https://tools.ietf.org/html/rfc5246#ref-CBCATT). For block ciphers, the length of the IV is the value of SecurityParameters.record\_iv\_length, which is equal to SecurityParameters.block\_size.

- padding:  
  Padding is used to force the length of the plaintext to be an integer multiple of the block cipher's block length. It may be of arbitrary length, up to 255 bytes, as long as it makes TLSCiphertext.length an integer multiple of the block length. It may need to be longer than strictly required to prevent attacks against protocols based on analyzing the lengths of exchanged messages. Each uint8 in the padding data vector must be filled with the padding length value. The receiver must check this padding and must use a bad\_record\_mac alert message to indicate a padding error.

- padding\_length:  
  The length of the padding must make the total length of the GenericBlockCipher an integer multiple of the cipher block length. Legal values range from 0 to 255, inclusive. This length specifies the length of the padding field, excluding the length of the padding\_length field.

The length of the ciphertext data (TLSCiphertext.length) is greater than the sum of SecurityParameters.block\_length, TLSCompressed.length, SecurityParameters.mac\_length, and padding\_length.
For example: if the block length is 8 bytes, the content length (TLSCompressed.length) is 61 bytes, and the MAC length is 20 bytes, then the length before padding is 81 bytes (excluding the IV). To make the total length an even multiple of 8 bytes (the block length), the padding length modulo 8 must be 7. In other words, the padding length may be 7, 15, 23, and so on, up to 255. If the padding length must be minimized, it is 7; then the padding must be 7 bytes. Since the last byte of the padding indicates the length of the padding, each padding byte should actually be 6. Therefore, the last 8 bytes of the GenericBlockCipher before block encryption might be xx 06 06 06 06 06 06 06, where xx is the last byte of the MAC. The final 06 is padding\_length, representing the length of the padding field, namely 6 bytes.
```c
        TLSCiphertext.length >= SecurityParameters.block_length 
        					+ TLSCompressed.length
        					+ SecurityParameters.mac_length
        					+ padding_length
```
Note: For block ciphers in CBC mode (Cipher Block Chaining mode), it is critical that the entire plaintext of a record be known before any ciphertext is transmitted. Otherwise, an attacker may be able to mount the attack described in [[CBCATT]](https://tools.ietf.org/html/rfc5246#ref-CBCATT). [[CBCTIME]](https://tools.ietf.org/html/rfc5246#ref-CBCTIME) describes a timing attack against CBC padding based on the time required to compute the MAC. To defend against such attacks, implementations must ensure that record processing time is essentially the same regardless of whether the padding is correct. In general, the best way to do this is to compute the MAC even if the padding is incorrect, and only then reject the packet. For example, if the padding appears to be incorrect, an implementation may assume zero-length padding and then compute the MAC. This leaves a small timing channel, because MAC computation performance depends to some extent on the length of the data fragment; however, it is not clear that this signal would be large enough to exploit, due to the large block size of existing MACs and the small size of the timing signal.


The complete block encryption process is illustrated below:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_3.png'>
</p>

Compared with stream encryption, block encryption adds padding and an IV.

#### III. AEAD Mode

Compared with the previous two encryption methods, AEAD encryption is easier to use and more secure. This is because it does not require the user to consider the HMAC algorithm, nor does it require an initialization vector or padding.

There are mainly three AEAD cipher suites:

|AEAD Mode | Encryption | Cipher Suite|
|:----:|:-----:|:-----:|
|GCM|AES-128-GCM|TLS\_DHE\_RSA\_WITH\_AES\_128\_GCM\_SHA256|
|CCM|AES-128-CCM|TLS\_RSA\_WITH\_AES\_128\_CCM|
|ChaCha20-Poly1305|ChaCha20-Poly1305|ECDHE-ECDSA-CHACHA20-POLY1305|

In the TLS protocol, CCM is used relatively rarely, while GCM is used more often, especially on CPUs with AES acceleration. ChaCha20-Poly1305 is an encryption algorithm invented by Google that combines the ChaCha20 stream cipher with the Poly1305 message authentication code, and it is used more often on mobile clients.

For AEAD [[AEAD]](https://tools.ietf.org/html/rfc5246#ref-AEAD) encryption (such as [[CCM]](https://tools.ietf.org/html/rfc5246#ref-CCM) or [[GCM]](https://tools.ietf.org/html/rfc5246#ref-GCM)), the AEAD function converts the TLSCompressed.fragment structure into an AEAD TLSCiphertext.fragment structure.
```c
        struct {
         opaque nonce_explicit[SecurityParameters.record_iv_length];
         aead-ciphered struct {
             opaque content[TLSCompressed.length];
         };
      } GenericAEADCipher;
```
The inputs to AEAD encryption are: a single key, a nonce, a block of plaintext (that is, `TLSCompressed.fragment`), and the “additional data” included in the authentication check (described in Section 2.1 of [[AEAD]](https://tools.ietf.org/html/rfc5246#ref-AEAD)). The key is either `client_write_key` or `server_write_key`. MAC keys are not used.

Each AEAD cipher suite must specify how the nonce provided to the AEAD operation is constructed, and what the length of the `GenericAEADCipher.nonce_explicit` field is. In many cases, it is appropriate to use the partially implicit nonce technique described in Section 3.2.1 of [[AEAD]](https://tools.ietf.org/html/rfc5246#ref-AEAD); `record_iv_length` is the length of `GenericAEADCipher.nonce_explicit`. In this case, the implicit part should be derived from the `key_block` (described in Section 6.3) as `client_write_iv` and `server_write_iv`, and the explicit part is included in `GenericAEAEDCipher.nonce_explicit`.

The plaintext is `TLSCompressed.fragment`.

The additional authenticated data (which we denote as `additional_data`) is defined as follows:
```c
        additional_data = seq_num + TLSCompressed.type +
                        TLSCompressed.version + TLSCompressed.length;
```
Here, “+” denotes concatenation.

The AEAD output consists of the ciphertext output produced by the AEAD encryption operation. Its length is generally greater than `TLSCompressed.length`, by an amount that varies depending on the AEAD cipher. Because encryption may include padding, the amount of overhead may vary with the value of `TLSCompressed.length`. Each AEAD cipher must not produce an expansion greater than 1024 bytes.
```c
        AEADEncrypted = AEAD-Encrypt(write_key, nonce, plaintext,
                                   additional_data)
```
To decrypt and verify, the encryption algorithm takes the key, nonce, “additional data”, and the value of AEADEncrypted as inputs. The output is either the plaintext or an error caused by decryption failure. There is no separate integrity check here. That is:
```c
        TLSCompressed.fragment = AEAD-Decrypt(write_key, nonce,
                                            AEADEncrypted,
                                            additional_data)
```
If decryption fails, a bad\_record\_mac alert message is generated.

The complete AEAD encryption process is shown in the following figure:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_4_0.png'>
</p>

Compared with stream encryption, AEAD encryption only adds a Nonce.

#### (2) TLS 1.3

In TLS 1.3, there is only one method for encryption and integrity protection: “Authenticated Encryption with Associated Data” (AEAD)[[RFC5116]](https://tools.ietf.org/html/rfc5116). AEAD provides a unified encryption and authentication operation, converting plaintext into authenticated ciphertext and then returning it. Each encrypted record consists of a plaintext header followed by an encrypted body, which itself contains a type and optional padding.
```c
      struct {
          ContentType opaque_type = application_data; /* 23 */
          ProtocolVersion legacy_record_version = 0x0303; /* TLS v1.2 */
          uint16 length;
          opaque encrypted_record[TLSCiphertext.length];
      } TLSCiphertext;
```
- opaque\_type:  
	The external opaque\_type field of a TLSCiphertext record is always set to the value 23(application\_data) to maintain outward compatibility with middleboxes that parse earlier versions of TLS. After decryption, the actual content type of the record is found in TLSInnerPlaintext.type.


- legacy\_record\_version:  
	The legacy\_record\_version field is always 0x0303. TLS 1.3 TLSCiphertexts are generated only after TLS 1.3 has been negotiated, so there is no historical compatibility concern that other values might be received. Note that the handshake protocol (including the ClientHello and ServerHello messages) authenticates the protocol version, so this value is redundant.

- length:  
	The length of TLSCiphertext.encrypted\_record in bytes, which is the sum of the lengths of the content and padding, plus the length of the inner content type, plus any expansion added by the AEAD algorithm. The length MUST NOT exceed 2 ^ 14 + 256 bytes. An endpoint that receives a record exceeding this length MUST terminate the connection with a "record\_overflow" alert message.


- encrypted\_record:  
  The serialized TLSInnerPlaintext structure in AEAD-encrypted form.

The complete AEAD encryption flow is illustrated in the following diagram:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/119_6.png'>
</p>

In TLS 1.3, the AEAD algorithm takes as input a single key, a nonce, the plaintext, and “additional data” to be included in the authentication check. The key is client\_write\_key or server\_write\_key, the nonce is derived from the sequence number and client\_write\_iv or server\_write\_iv, and the input for the additional data is the record header:
```c
      additional_data = TLSCiphertext.opaque_type ||
                        TLSCiphertext.legacy_record_version ||
                        TLSCiphertext.length
```
The plaintext input to the AEAD algorithm is the encoded TLSInnerPlaintext structure.

**The biggest difference between AEAD in TLS 1.2 and AEAD in TLS 1.3 is how the nonce is generated. In TLS 1.2, the sequence number is included in the additional\_data, whereas in TLS 1.3 it is incorporated into the nonce. In addition, the two fields in TLS 1.3 additional\_data that participate in the computation have fixed values (opaque\_type = 23, legacy\_record\_version = 0x0303)**.

In TLS 1.3, the per-record nonce for the AEAD structure is formed as follows:

1. The 64-bit record sequence number is encoded in network byte order and left-padded with zeros to iv\_length.
2. The padded sequence number is XORed with client\_write\_iv or server\_write\_iv (depending on the role).

The resulting value (with length iv\_length) is used as the per-record nonce.

>Note: This differs from the structure in TLS 1.2, where TLS 1.2 specifies a partially explicit nonce.


The AEAD output consists of the ciphertext output of the AEAD encryption operation. Because it includes TLSInnerPlaintext.type and any padding provided by the sender, the plaintext length is greater than the corresponding TLSPlaintext.length. The AEAD output length is usually greater than the plaintext length, but part of that overhead also varies depending on the AEAD algorithm.

Because a cipher may include padding, the overhead can vary with different plaintext lengths.
```c
      AEADEncrypted =
          AEAD-Encrypt(write_key, nonce, additional_data, plaintext)
```
The `encrypted_record` field of TLSCiphertext is set to AEADEncrypted.

To decrypt and verify, the cipher takes the key, nonce, additional data, and the AEADEncrypted value as input. The output is either the plaintext or an error indicating decryption failure. There is no separate integrity check here.
```c
      plaintext of encrypted_record =
          AEAD-Decrypt(peer_write_key, nonce,
                       additional_data, AEADEncrypted)
```
If decryption fails, the receiver MUST terminate the connection with a "bad\_record\_mac" alert message.

The AEAD algorithms used in TLS 1.3 MUST NOT produce an expansion greater than 255 octets. When receiving a record from the peer with TLSCiphertext.length, if TLSCiphertext.length is greater than 2 ^ 14 + 256 octets, the connection MUST be terminated with a "record\_overflow" message. This limit comes from the fact that the maximum length of TLSInnerPlaintext is 2 ^ 14 octets, plus 1 octet for ContentType, plus the maximum AEAD expansion of 255 octets.


### 4. Adding the Message Header

After encryption, the TLSCiphertext data structure is obtained. Once the message header is added, it is passed uniformly to the TCP/UDP layer. In TLS 1.2 and TLS 1.3, the added message header is the same.

In TLS 1.2, the message header has the following three fields.
```c
          ContentType type;
          ProtocolVersion version;
          uint16 length;
```
For compatibility with versions prior to TLS 1.3, `ProtocolVersion` still needs to be retained, but it is no longer used in the TLS 1.3 specification. In TLS 1.3, the message header fields also include the following three.
```c
          ContentType type;
          ProtocolVersion legacy_record_version;
          uint16 length;
```

## 3. Key Calculation in the TLS Record Layer Protocol

### 1. Key Calculation in TLS 1.2

The TLS Record Protocol requires an algorithm to generate the keys needed for the current connection state from the security parameters provided by the handshake protocol.

The master secret is expanded into a secure byte sequence, which is split into a client write MAC key, a server write MAC key, a client write encryption key, and a server write encryption key. Each of these is generated from the byte sequence in the order listed above. Unused values are empty. Some AEAD ciphers may additionally require a client write IV and a server write IV.

When generating encryption keys and MAC keys, the master secret is used as a source of entropy.

To generate the key data, compute
```c
            key_block = PRF(SecurityParameters.master_secret,
                      "key expansion",
                      SecurityParameters.server_random +
                      SecurityParameters.client_random);
```
> The PRF algorithm is used here. The author will write a separate article comparing the differences between TLS 1.2 and TLS 1.3 in this algorithm.

until enough output has been produced. Then, key\_block is split as follows:
```c
      client_write_MAC_key[SecurityParameters.mac_key_length]
      server_write_MAC_key[SecurityParameters.mac_key_length]
      client_write_key[SecurityParameters.enc_key_length]
      server_write_key[SecurityParameters.enc_key_length]
      client_write_IV[SecurityParameters.fixed_iv_length]
      server_write_IV[SecurityParameters.fixed_iv_length]
```
Currently, client\_write\_IV and server\_write\_IV can only be generated using the implicit nonce technique described in Section 3.2.1 of [[AEAD]](https://tools.ietf.org/html/rfc5246#ref-AEAD).

Implementation note: Among the currently defined cipher suites, AES\_256\_CBC\_SHA256 requires the most key material. It requires 2 x 32-byte encryption keys and 2 x 32-byte MAC keys, all derived from 128 bytes of keying material.


### 2. Key Calculation in TLS 1.3


Key calculation in TLS 1.3 is relatively complex because it also involves 0-RTT. I plan to write a dedicated article to explain this topic. TLS 1.2/1.1/1.0 all use the PRF algorithm for key calculation, but in TLS 1.3 this part was completely changed and replaced with the HKDF algorithm.

For key calculation in TLS 1.2 and TLS 1.3, after finishing the article on 0-RTT, I will write a separate article comparing their similarities and differences.


------------------------------------------------------

References:  
     
[TLS 1.3 The TLS Record Protocol](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%80-record-layer)  
[TLS 1.2 The TLS Record Protocol](https://tools.ietf.org/html/rfc5246#page-15)


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS\_record\_layer/](https://halfrost.com/https_record_layer/)