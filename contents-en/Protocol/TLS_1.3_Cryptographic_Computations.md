# TLS 1.3 Cryptographic Computations


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/111_0.png'>
</p>

The TLS handshake establishes one or more input secrets. As described below, these secrets are combined to create the actual working keying material. The key derivation process incorporates the input secrets and the handshake transcript. Note that because the handshake transcript includes the random values from the Hello messages, any given handshake will have distinct traffic secrets even when the same input secrets are used, as is the case when the same PSK is used for multiple connections.

## I. Key Schedule

The key derivation process uses the HKDF-Extract and HKDF-Expand functions defined by HKDF [[RFC5869]](https://tools.ietf.org/html/rfc5869), as well as the functions defined below:
```c
       HKDF-Expand-Label(Secret, Label, Context, Length) =
            HKDF-Expand(Secret, HkdfLabel, Length)

       Where HkdfLabel is specified as:

       struct {
           uint16 length = Length;
           opaque label<7..255> = "tls13 " + Label;
           opaque context<0..255> = Context;
       } HkdfLabel;

       Derive-Secret(Secret, Label, Messages) =
            HKDF-Expand-Label(Secret, Label,
                              Transcript-Hash(Messages), Hash.length)
```
The hash function used by Transcript-Hash and HKDF is the cipher suite hash algorithm. `Hash.length` is its output length (in bytes). The messages are the concatenation of the represented handshake messages, including the handshake message type and length fields, but excluding the record layer header. Note that in some cases, a zero-length context (represented by "") is passed to HKDF-Expand-Label. All labels specified in this document are ASCII strings and do not include a trailing NUL byte.

Note: For common hash functions, any label longer than 12 characters requires an additional iteration of the hash function to compute. All standard labels have been chosen to comply with this limit.

Keys are derived from two input secrets using the HKDF-Extract and Derive-Secret functions. The general pattern for adding a new secret is to use HKDF-Extract, where Salt is the current secret state, and the input keying material (IKM) is the new secret to be added. In this version of TLS 1.3, the two input secrets are:

- PSK (an externally established pre-shared key, or one derived from the `resumption_master_secret` value from a previous connection)

- The (EC)DHE shared secret ([Section 7.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Cryptographic_Computations.md#%E5%9B%9B-ecdhe-shared-secret-calculation))


This produces the complete key schedule shown in the figure below. In this figure, the following conventions are used:

- HKDF-Extract is drawn in the diagram as taking the Salt argument from the top and the IKM argument from the left; its output is at the bottom, with the name of the output on the right.

- The Secret argument to Derive-Secret is indicated by the incoming arrow. For example, Early Secret is the Secret used to generate `client_early_traffic_secret`.

- "0" denotes a string of `Hash.length` bytes set to zero.
```c
             0
             |
             v
   PSK ->  HKDF-Extract = Early Secret
             |
             +-----> Derive-Secret(., "ext binder" | "res binder", "")
             |                     = binder_key
             |
             +-----> Derive-Secret(., "c e traffic", ClientHello)
             |                     = client_early_traffic_secret
             |
             +-----> Derive-Secret(., "e exp master", ClientHello)
             |                     = early_exporter_master_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
   (EC)DHE -> HKDF-Extract = Handshake Secret
             |
             +-----> Derive-Secret(., "c hs traffic",
             |                     ClientHello...ServerHello)
             |                     = client_handshake_traffic_secret
             |
             +-----> Derive-Secret(., "s hs traffic",
             |                     ClientHello...ServerHello)
             |                     = server_handshake_traffic_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
   0 -> HKDF-Extract = Master Secret
             |
             +-----> Derive-Secret(., "c ap traffic",
             |                     ClientHello...server Finished)
             |                     = client_application_traffic_secret_0
             |
             +-----> Derive-Secret(., "s ap traffic",
             |                     ClientHello...server Finished)
             |                     = server_application_traffic_secret_0
             |
             +-----> Derive-Secret(., "exp master",
             |                     ClientHello...server Finished)
             |                     = exporter_master_secret
             |
             +-----> Derive-Secret(., "res master",
                                   ClientHello...client Finished)
                                   = resumption_master_secret
```
The general pattern here is that the secrets shown on the left side of the diagram are raw entropy without context, while the secrets on the right side include the handshake context and therefore can be used to derive working keys without additional context. Note that different invocations of Derive-Secret may use different Messages arguments, even with the same secret. In a 0-RTT exchange, Derive-Secret is called with four different transcripts; in a 1-RTT-only exchange, it is called with three different transcripts.

If a given secret is unavailable, a 0 value consisting of a Hash.length-byte string set to zero is used. Note that this does not mean skipping a round; therefore, if no PSK is used, the Early Secret is still HKDF-Extract(0,0). For the computation of binder\_key, the label is "ext binder" for external PSKs (those provided outside of TLS) and "res binder" for resumption PSKs (those provided as the resumption master secret from a previous handshake). The different labels prevent one PSK from being substituted for another.


There are multiple possible Early Secret values, depending on the PSK that the Server ultimately selects. The Client needs to compute a value for each potential PSK; if no PSK is selected, it needs to compute the Early Secret corresponding to a zero PSK.

Once all values derived from a given secret have been computed, that secret should be deleted.


## II. Updating Traffic Secrets

Once the handshake has completed, either side can update its sending traffic keys using the KeyUpdate handshake message defined in [Section 4.6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update). The next-generation traffic secret is computed by generating client\_ / server\_application\_traffic\_secret\_N + 1 from client\_ / server\_application\_traffic\_secret\_N as described in this section, and then re-deriving the traffic keys as described in [Section 7.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%B8%89-traffic-key-calculation).

The next-generation application\_traffic\_secret is computed as follows:
```c
       application_traffic_secret_N+1 =
           HKDF-Expand-Label(application_traffic_secret_N,
                             "traffic upd", "", Hash.length)
```
Once client\_ / server\_application\_traffic\_secret\_N + 1 and its associated traffic keys have been computed, implementations should delete client\_ / server\_application\_traffic\_secret\_N and its associated traffic keys.


## III. Traffic Key Calculation


Traffic keying material is generated from the following input values:

- the value of the secret

- a purpose value indicating the specific value being generated

- the length of the generated key


Traffic keying material is generated using the value of the input traffic secret:
```c
  [sender]_write_key = HKDF-Expand-Label(Secret, "key", "", key_length)
  [sender]_write_iv  = HKDF-Expand-Label(Secret, "iv", "", iv_length)
```
[sender] indicates the sender. The Secret values for each record type are shown in the table below:
```c
       +-------------------+---------------------------------------+
       | Record Type       | Secret                                |
       +-------------------+---------------------------------------+
       | 0-RTT Application | client_early_traffic_secret           |
       |                   |                                       |
       | Handshake         | [sender]_handshake_traffic_secret     |
       |                   |                                       |
       | Application Data  | [sender]_application_traffic_secret_N |
       +-------------------+---------------------------------------+
```
Whenever the underlying Secret changes (for example, when changing from handshake to application data keys, or during a key update), all traffic keying material is recomputed.

## IV. (EC)DHE Shared Secret Calculation

### 1. Finite Field Diffie-Hellman

For finite-field groups, the traditional Diffie-Hellman [[DH76]](https://tools.ietf.org/html/rfc8446#ref-DH76) computation is performed. The negotiated key (Z) is converted into a byte string, encoded in big-endian form and left-padded with zeros to the size of the prime. This byte string is used as the shared secret in the key schedule specified above.

Note that this construction differs from earlier versions of TLS, which stripped leading zeros.


### 2. Elliptic Curve Diffie-Hellman

For secp256r1, secp384r1, and secp521r1, the ECDH computation (including parameter and key generation, as well as shared secret computation) is performed according to [[IEEE1363]](https://tools.ietf.org/html/rfc8446#ref-IEEE1363) using the ECKAS-DH1 scheme, with the identity mapping as the key derivation function (KDF). Therefore, the shared secret is the x-coordinate of the ECDH shared secret elliptic curve point, represented as an octet string.
 
Note that this octet string output by FE2OSP (the Field Element to Octet String Conversion Primitive), referred to as “Z” in IEEE 1363 terminology, has a constant length for any given field; leading zeros found in this octet string MUST NOT be truncated.

(Note that using the identity KDF is a technicality. The complete formulation is to use ECDH together with a KDF, because TLS does not use this secret directly for anything other than computing other secrets.)

For X25519 and X448, the ECDH computation is as follows:

- The public key placed in the KeyShareEntry.key\_exchange structure is the result of applying the ECDH scalar multiplication function to a private key of the appropriate length (scalar input) and the standard public base point (u-coordinate point input).

- The ECDH shared secret is the result of applying the ECDH scalar multiplication function to the private key (scalar input) and the peer’s public key (u-coordinate point input). The output is used directly, without further processing.

For these curves, implementations should use the methods specified in [RFC7748](https://tools.ietf.org/html/rfc7748) to compute the Diffie-Hellman shared secret. Implementations MUST check whether the computed Diffie-Hellman shared secret is an all-zero value and abort if it is, as described in [[RFC7748] Section 6](https://tools.ietf.org/html/rfc7748#section-6). If implementers use alternative implementations of these elliptic curves, they should perform the additional checks specified in [[RFC7748] Section 7](https://tools.ietf.org/html/rfc7748#section-7).


## V. Exporters


[RFC5705](https://tools.ietf.org/html/rfc5705) defines TLS keying material exporters based on the TLS pseudorandom function (PRF). This document replaces the PRF with HKDF, and therefore requires a new construction. The exporter interface remains unchanged.

Exporter values are computed as follows:
```c
   TLS-Exporter(label, context_value, key_length) =
       HKDF-Expand-Label(Derive-Secret(Secret, label, ""),
                         "exporter", Hash(context_value), key_length)
```
The secret can be early\_exporter\_master\_secret or exporter\_master\_secret. Unless the application explicitly specifies otherwise, implementations MUST use exporter\_master\_secret. early\_exporter\_master\_secret is defined for use in settings where 0-RTT data requires exporters. It is RECOMMENDED to provide a separate interface for early exporters; this prevents exporter users from accidentally using an early exporter when they need a regular exporter, and vice versa.

If no context is provided, context\_value is zero length. Therefore, computing with no context produces the same result as computing with an empty context. This is a change from previous versions of TLS, where an empty context produced output different from the result with no context. As of this document, no allocated exporter label is used both with and without context. Future specifications MUST NOT define exporter usage that permits both an empty context and no context with the same label. New uses of exporters SHOULD provide a context in all exporter computations, although the value may be empty.

The requirements for the exporter label format are defined in [Section 4 of RFC5705](https://tools.ietf.org/html/rfc5705#section-4).

------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Cryptographic\_Computations/](https://halfrost.com/tls_1-3_cryptographic_computations/)