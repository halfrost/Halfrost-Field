+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS", "Cryptography"]
date = 2018-09-01T12:01:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/103_0.png"
slug = "message_authentication_code"
tags = ["Protocol", "HTTPS", "Cryptography"]
title = "What Is a Message Authentication Code?"

+++


## 1. Why Do We Need Message Authentication Codes?

Let’s use the example of a bank transfer again: A transfers 1 million yuan to B. If an attacker interferes and tampers with this message, it could become “A transfers 10 million yuan to the attacker.” For a transfer message like this, two issues require attention: message “integrity” and “authentication”.

Message integrity, also called message consistency, can be determined using the message fingerprint discussed in the previous article. By comparing the hash values produced by a one-way hash function, we can determine whether the message is intact and whether it has been tampered with.

Message authentication refers to whether the message comes from the correct sender. If we can confirm that the transfer request really comes from A, then the message has been authenticated, meaning it has not been spoofed.

**If we need to detect both tampering and spoofing at the same time—that is, to confirm message integrity and authenticate the message—then we need a message authentication code**.

## 2. What Is a Message Authentication Code?

A **Message Authentication Code** (MAC) is a technique used to verify integrity and perform authentication. It is abbreviated as MAC.

Using a message authentication code allows you to confirm whether the message you received is exactly what the sender intended. In other words, it lets you determine whether the message has been tampered with and whether someone has impersonated the sender to send it.

>A message authentication code is also one of the six major tools in the cryptographer’s toolbox: symmetric ciphers, public-key cryptography, one-way hash functions, message authentication codes, digital signatures, and pseudorandom number generators.

The inputs to a message authentication code include a **message** of arbitrary length and a **shared key** between the sender and the receiver. The output is fixed-length data, and that output is the MAC value.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_1.png'>
</p>


The difference between a message authentication code and a one-way hash function is whether this **shared key** is involved. Therefore, a message authentication code performs authentication using a shared key. Like the hash value of a one-way hash function, if even 1 bit of the message changes, the MAC value will also change. This is exactly the property that message authentication codes use to provide integrity.

So a message authentication code can be understood as **a one-way hash function associated with a key**.


## 3. Steps for Using a Message Authentication Code

If banks use a message authentication code for transfers, the process would look like this:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_2_.png'>
</p>

The overall process is basically the same as verifying a one-way hash function, except that a message authentication code requires the shared key to derive the MAC value.

However, the shared key used by a message authentication code introduces a key distribution problem. The key must not be stolen by an eavesdropper during distribution. Solving the key distribution problem requires using public-key cryptography, Diffie-Hellman key exchange, or other secure key-distribution methods discussed two articles ago.

## 4. Current Use of Message Authentication Codes

 
* SWIFT (Society for Worldwide Interbank Financial Telecommunications) is an association whose purpose is to safeguard transactions between international banks. Banks exchange transaction messages through SWIFT, and SWIFT uses message authentication codes to verify message integrity and authenticate messages. The shared keys for message authentication codes are distributed by people.
 
* IPsec is a way to add security to the IP protocol. In IPsec, message authentication and integrity verification are also performed using message authentication codes.
 
* SSL/TLS also uses message authentication codes to authenticate communication content and verify its integrity.

## 5. Implementations of Message Authentication Codes

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_6.png'>
</p>

- One-way hash functions such as SHA-2 can be used to implement message authentication codes, for example HMAC.       


- Block ciphers such as AES can be used to implement message authentication codes. The block cipher key is used as the shared key, and CBC mode is used to encrypt the entire message. Since decryption is not needed in a message authentication code, only the final block can be kept and all other blocks discarded. The final block in CBC mode is affected by both the entire message and the key, so it can serve as the MAC value. AES-CMAC (RFC4493) is a message authentication code implemented based on AES.  


- Stream ciphers  


- Public-key cryptography  


After 2000, research based on authentication advanced further, producing **authenticated encryption** (AE: Authenticated Encryption, AEAD: Authenticated Encryption with Associated Data). Authenticated encryption is a technique that combines symmetric cryptography with message authentication, providing confidentiality, integrity, and authenticity at the same time.

There are several forms of authenticated encryption. For example: Encrypt-then-MAC first encrypts the plaintext with a symmetric cipher, then computes the MAC value of the ciphertext. Encrypt-and-MAC encrypts the plaintext with a symmetric cipher and also computes the MAC value over the plaintext. MAC-then-Encrypt first computes the MAC value of the plaintext, then encrypts both the plaintext and the MAC value with a symmetric cipher. **In HTTPS, MAC-then-Encrypt is generally used for processing**.

GCM (Galois/Counter Mode) is an authenticated encryption mode. GCM uses CTR mode with a 128-bit block cipher such as AES, and uses a hash function that repeatedly performs addition and multiplication operations to compute the MAC value. CTR-mode encryption and MAC computation use the same key, so key management is convenient. GCM used specifically for message authentication codes is called GMAC. **Both GCM and CCM (CBC Counter Mode) are recommended authenticated encryption modes**.

>ChaCha20-Poly1305 is an algorithm invented by Google. It uses the ChaCha20 stream cipher for encryption and the Poly1305 algorithm for MAC computation.


## 6. The HMAC Algorithm

HMAC is a method for constructing a message authentication code using a one-way hash function. The H in HMAC stands for Hash. See the official documentation: [RFC 2104](https://tools.ietf.org/html/rfc2104)

Any high-strength one-way hash function can be used in HMAC. For example, HMACs constructed with SHA-1, SHA-224, SHA-256, SHA-384, and SHA-512 are called HMAC-SHA1, HMAC-SHA-224, HMAC-SHA-256, HMAC-SHA-384, and HMAC-SHA-512, respectively.

The steps for computing an HMAC MAC value are as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_3__.png'>
</p>


### 1. Key Padding

If the key is shorter than the block length of the one-way hash function, append 0s to the end so that the final length is the same as the block length of the one-way hash function.

If the key is longer than the block length, compute the hash value of the key using the one-way hash function, and then use that hash value as the HMAC key.


### 2. Key Transformation I

Compute the XOR of the padded key and the bit sequence of ipad. ipad is the bit sequence 00110110 (0x36 in hexadecimal) repeated until its length is the same as the block length. The “i” in ipad means “inner”.

The final result of the XOR is a **bit sequence that has the same length as the block length of the one-way hash function and is related to the key**. This sequence is called ipadkey.

### 3. Combine with the Message

Prepend ipadkey to the message.


### 4. Compute the Hash Value

Input the result from step 3 into the one-way hash function and compute the hash value.

### 5. Key Transformation II


Compute the XOR of the padded key and the bit sequence of opad. opad is the bit sequence 01011100 (0x5C in hexadecimal) repeated until its length is the same as the block length. The “o” in opad means “outer”.

The final result of the XOR is a **bit sequence that has the same length as the block length of the one-way hash function and is related to the key**. This sequence is called opadkey.

### 6. Combine with the Hash Value

Prepend opadkey to the hash value.

### 7. Compute the Hash Value

Input the result from step 6 into the one-way hash function and compute the hash value. This hash value is the final MAC value.


The final MAC value must be a fixed-length bit sequence related to both the input message and the key.

HMAC expressed in pseudocode:
```c
HMAC = hash(opadkey || hash(ipadkey || message))
	 = hash( (key ⊕ opad) || hash( (key ⊕ ipad) || message) )

opadkey = key ⊕ opad
ipadkey = key ⊕ ipad

key is the secret key, message is the message, hash is computed as hash(), and A || B means A is placed before B
```
Here’s a concrete example of HMAC\_MD5:
```c
/*
** Function: hmac_md5
*/

void hmac_md5(text, text_len, key, key_len, digest)
unsigned char*  text;                /* pointer to data stream */
int             text_len;            /* length of data stream */
unsigned char*  key;                 /* pointer to authentication key */
int             key_len;             /* length of authentication key */
caddr_t         digest;              /* caller digest to be filled in */

{
        MD5_CTX context;
        unsigned char k_ipad[65];    /* inner padding -
                                      * key XORd with ipad
                                      */
        unsigned char k_opad[65];    /* outer padding -
                                      * key XORd with opad
                                      */
        unsigned char tk[16];
        int i;
        /* if key is longer than 64 bytes reset it to key=MD5(key) */
        if (key_len > 64) {

                MD5_CTX      tctx;

                MD5Init(&tctx);
                MD5Update(&tctx, key, key_len);
                MD5Final(tk, &tctx);

                key = tk;
                key_len = 16;
        }

        /*
         * the HMAC_MD5 transform looks like:
         *
         * MD5(K XOR opad, MD5(K XOR ipad, text))
         *
         * where K is an n byte key
         * ipad is the byte 0x36 repeated 64 times
         * opad is the byte 0x5c repeated 64 times
         * and text is the data being protected
         */

        /* start out by storing key in pads */
        bzero( k_ipad, sizeof k_ipad);
        bzero( k_opad, sizeof k_opad);
        bcopy( key, k_ipad, key_len);
        bcopy( key, k_opad, key_len);

        /* XOR key with ipad and opad values */
        for (i=0; i<64; i++) {
                k_ipad[i] ^= 0x36;
                k_opad[i] ^= 0x5c;
        }
        /*
         * perform inner MD5
         */
        MD5Init(&context);                   /* init context for 1st
                                              * pass */
        MD5Update(&context, k_ipad, 64)      /* start with inner pad */
        MD5Update(&context, text, text_len); /* then text of datagram */
        MD5Final(digest, &context);          /* finish up 1st pass */
        /*
         * perform outer MD5
         */
        MD5Init(&context);                   /* init context for 2nd
                                              * pass */
        MD5Update(&context, k_opad, 64);     /* start with outer pad */
        MD5Update(&context, digest, 16);     /* then results of 1st
                                              * hash */
        MD5Final(digest, &context);          /* finish up 2nd pass */
}

```
Output
```c
  key =         0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b
  key_len =     16 bytes
  data =        "Hi There"
  data_len =    8  bytes
  digest =      0x9294727a3638bb1c13f48ef8158bfc9d
  
  
  key =         "Jefe"
  data =        "what do ya want for nothing?"
  data_len =    28 bytes
  digest =      0x750c783e6ab0b503eaa86e310a5db738
  
  
  key =         0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  key_len       16 bytes
  data =        0xDDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD
  data_len =    50 bytes
  digest =      0x56be34521d144c88dbb8c733f0e8b3f6

```

## VII. Attacks on Message Authentication Codes

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_5.png'>
</p>

### 1. Replay Attacks

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_4_.png'>
</p>

An eavesdropper may not try to break the message authentication code directly, but instead save it and reuse it repeatedly. This kind of attack is called a **replay attack**.

There are three ways to prevent replay attacks:

- Sequence number  
Add an incrementing sequence number to each message, and include the sequence number in the message when computing the MAC value. This way, if an attacker cannot break the message authentication code, they cannot compute the correct MAC value. The downside of this approach is that the sequence number of the last message must be recorded for each message.

- Timestamp  
Include the current time when sending the message. If the received time does not match the current time, then even if the MAC value is correct, the message is still treated as invalid and discarded. This can also defend against replay attacks. The downside of this approach is that the sender’s and receiver’s clocks must be synchronized. Considering message latency, a certain amount of time tolerance must be allowed. This tolerance window can still leave room for replay attacks.

- nonce  
Before communication begins, the receiver first sends the sender a one-time random number, the nonce. The sender includes this nonce in the message and computes the MAC value. Because the nonce changes every time, replay attacks cannot be performed. The disadvantage of this approach is that it increases the amount of data exchanged.

### 2. Key Guessing Attacks

Message authentication codes can also be attacked via brute force and birthday attacks. A message authentication code must ensure that the key used by the communicating parties cannot be inferred from the MAC value. This can be guaranteed by the one-way property and collision resistance of a one-way hash function, making it impossible to infer the key.

## VIII. Problems That Message Authentication Codes Cannot Solve

Although a message authentication code can prove that the messages sent by both parties are consistent, intact, and have not been tampered with, and that there is no man-in-the-middle impersonation, it cannot provide “proof to a third party” or “prevent repudiation”.  

The reason it cannot provide “proof to a third party” is that the key used in a message authentication code is a shared key, and both communicating parties possess it. Therefore, it is impossible to prove to a third party which of the two parties the message actually came from.  
Solving the problem of “third-party proof” requires digital signatures.

The reason it cannot “prevent repudiation” is also that both parties share the key used in the message authentication code, making it impossible to determine which party sent the message. Therefore, a message authentication code cannot prevent nonrepudiation.  
Solving the problem of “preventing repudiation” requires digital signatures.

## IX. Summary


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/102_2.png'>
</p>

A one-way hash function guarantees message consistency and integrity, and ensures that the message has not been tampered with.  
A message authentication code guarantees message consistency and integrity, ensures that the message has not been tampered with, and ensures that there is no man-in-the-middle impersonation.  
A digital signature guarantees message consistency and integrity, ensures that the message has not been tampered with, ensures that there is no man-in-the-middle impersonation, and can prevent repudiation.  

------------------------------------------------------

Reference：
  
*Illustrated Cryptographic Technology*        

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/message\_authentication\_code/](https://halfrost.com/message_authentication_code/)