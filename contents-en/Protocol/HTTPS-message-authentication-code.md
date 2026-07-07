# What Is a Message Authentication Code?


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_0.png'>
</p>


## 1. Why Do We Need Message Authentication Codes?

Let’s again use the example of a bank transfer: A transfers 1 million yuan to B. If an attacker interferes and tampers with the message, it could become “A transfers 10 million yuan to the attacker.” For this transfer message, there are two issues to pay attention to: the message’s “integrity” and “authentication.”

Message integrity, also called message consistency, can be determined using the message fingerprint discussed in the previous article: compare the hash values produced by a one-way hash function to determine whether the message is intact and whether it has been tampered with.

Message authentication refers to whether the message comes from the correct sender. If we can confirm that the transfer request really came from A, then the message has been authenticated, meaning it has not been forged.

**If you need to detect both tampering and impersonation—that is, confirm message integrity and authenticate the message—then you need a message authentication code**.

## 2. What Is a Message Authentication Code?

A **message authentication code** (Message Authentication Code) is a technique for confirming integrity and performing authentication, abbreviated as MAC.

Using a message authentication code allows you to confirm whether the message you received is exactly what the sender intended. In other words, it lets you determine whether the message has been tampered with and whether someone impersonated the sender to send it.

>A message authentication code is also one of the six major tools in a cryptographer’s toolbox: symmetric ciphers, public-key cryptography, one-way hash functions, message authentication codes, digital signatures, and pseudorandom number generators.

The inputs to a message authentication code are a **message** of arbitrary length and a **shared key** between the sender and receiver. The output is fixed-length data, and that output data is the MAC value.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_1.png'>
</p>


The difference between a message authentication code and a one-way hash function lies in whether this **shared key** is involved. So a message authentication code performs authentication using a shared key. Like the hash value of a one-way hash function, if the message changes by even 1 bit, the MAC value will also change. A message authentication code uses precisely this property to check integrity.

So a message authentication code can be understood as **a one-way hash function associated with a key**.


## 3. How to Use a Message Authentication Code

If banks use message authentication codes for transfers, the process is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_2_.png'>
</p>

The overall process is basically the same as verifying a one-way hash function, except that a message authentication code requires the shared key to compute the MAC value.

However, the shared key used by a message authentication code introduces a key distribution problem. The key must not be obtained by an eavesdropper during distribution. Solving the key distribution problem requires other secure methods for distributing keys, such as the public-key cryptography and Diffie-Hellman key exchange discussed two articles ago.

## 4. Current Uses of Message Authentication Codes

- SWIFT (Society for Worldwide Interbank Financial Telecommunications) is an association whose purpose is to safeguard transactions between international banks. Banks transmit transaction messages through SWIFT, and SWIFT uses message authentication codes to verify message integrity and authenticate messages. The shared keys used for message authentication codes are distributed manually.

- IPsec is a way to add security to the IP protocol. In IPsec, message authentication and integrity checks are also performed using message authentication codes.

- SSL/TLS also uses message authentication codes to authenticate communication content and verify its integrity.

## 5. Implementations of Message Authentication Codes

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_6.png'>
</p>

- Message authentication codes can be implemented using one-way hash functions such as SHA-2; HMAC is one example.  

- Message authentication codes can be implemented using block ciphers such as AES. The key of the block cipher serves as the shared key, and the entire message is encrypted using CBC mode. Since decryption is not needed in a message authentication code, only the last block can be retained and all other blocks discarded. The last block in CBC mode is affected by both the entire message and the key, so it can be used as the MAC value. AES-CMAC (RFC4493) is a message authentication code implemented based on AES.

- Stream ciphers

- Public-key cryptography

After 2000, research based on authentication advanced further, leading to **authenticated encryption** (AE: Authenticated Encryption; AEAD: Authenticated Encryption with Associated Data). Authenticated encryption is a technique that combines symmetric encryption and message authentication, providing confidentiality, integrity, and authentication at the same time.

There are several types of authenticated encryption. For example: Encrypt-then-MAC first encrypts the plaintext with a symmetric cipher and then computes the MAC value of the ciphertext. Encrypt-and-MAC encrypts the plaintext with a symmetric cipher and computes the MAC value of the plaintext. MAC-then-Encrypt first computes the MAC value of the plaintext, then encrypts both the plaintext and the MAC value with a symmetric cipher. **In HTTPS, MAC-then-Encrypt is generally used for processing**.

GCM (Galois/Counter Mode) is a form of authenticated encryption. GCM uses the CTR mode of 128-bit block ciphers such as AES, and uses a hash function that repeatedly performs addition and multiplication operations to compute the MAC value. CTR-mode encryption and MAC-value computation use the same key, so key management is very convenient. GCM used specifically for message authentication codes is called GMAC. **GCM and CCM (CBC Counter Mode) are both recommended authenticated encryption modes**.

>ChaCha20-Poly1305 is an algorithm invented by Google. It uses the ChaCha20 stream cipher for encryption and the Poly1305 algorithm for MAC computation.

## 6. The HMAC Algorithm

HMAC is a method for constructing a message authentication code using a one-way hash function. The H in HMAC stands for Hash. See the official document: [RFC 2104](https://tools.ietf.org/html/rfc2104)

Any high-strength one-way hash function can be used in HMAC. For example, HMACs constructed with SHA-1, SHA-224, SHA-256, SHA-384, and SHA-512 are called HMAC-SHA1, HMAC-SHA-224, HMAC-SHA-256, HMAC-SHA-384, and HMAC-SHA-512, respectively.

The steps for computing a MAC value with HMAC are as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_3__.png'>
</p>


### 1. Key Padding

If the key is shorter than the block length of the one-way hash function, zeros need to be appended at the end so that the final length is the same as the block length of the one-way hash function.

If the key is longer than the block length, the one-way hash function is used to compute the hash value of the key, and this hash value is then used as the HMAC key.


### 2. Key Transformation I

Perform an XOR operation between the padded key and the bit sequence of ipad. ipad is the bit sequence 00110110 (36 in hexadecimal) repeated until its length is the same as the block length. The i in ipad means inner.

The final result of the XOR is a **bit sequence that has the same length as the block length of the one-way hash function and is related to the key**. This sequence is called ipadkey.

### 3. Combine with the Message

Append ipadkey to the beginning of the message.


### 4. Compute the Hash Value

Input the result of step 3 into the one-way hash function and compute the hash value.

### 5. Key Transformation II


Perform an XOR operation between the padded key and the bit sequence of opad. opad is the bit sequence 01011100 (5C in hexadecimal) repeated until its length is the same as the block length. The o in opad means outer.

The final result of the XOR is a **bit sequence that has the same length as the block length of the one-way hash function and is related to the key**. This sequence is called opadkey.

### 6. Combine with the Hash Value

Append opadkey to the beginning of the hash value.

### 7. Compute the Hash Value

Input the result of step 6 into the one-way hash function and compute the hash value. This hash value is the final MAC value.


The final MAC value must be a fixed-length bit sequence related to both the input message and the key.

HMAC expressed in pseudocode:
```c
HMAC = hash(opadkey || hash(ipadkey || message))
	 = hash( (key ⊕ opad) || hash( (key ⊕ ipad) || message) )

opadkey = key ⊕ opad
ipadkey = key ⊕ ipad

key is the key, message is the message, hash is computed as hash(), A || B means A is placed before B
```
Here is a concrete example of HMAC\_MD5:
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

### 1. Replay Attack

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_4_.png'>
</p>

An eavesdropper does not directly break the message authentication code, but instead saves it and reuses it repeatedly. This type of attack is called a **replay attack**.

There are three ways to prevent replay attacks:

- Sequence number  
Add an incrementing sequence number to each message, and include the sequence number in the message when computing the MAC value. This way, an attacker cannot compute the correct MAC value without breaking the message authentication code. The drawback of this approach is that each message requires keeping an additional record of the sequence number of the last message.

- Timestamp  
Include the current time when sending a message. If the received time does not match the current time, the message is treated as invalid and discarded even if the MAC value is correct. This can also defend against replay attacks. The drawback of this approach is that the sender’s and receiver’s clocks must be synchronized. Because message latency must be taken into account, a certain amount of time tolerance is required. This tolerance window can still leave an opportunity for replay attacks.

- nonce  
Before communication begins, the receiver first sends the sender a one-time random number, a nonce. The sender includes this nonce in the message and computes the MAC value. Since the nonce changes every time, replay attacks cannot be performed. The drawback of this approach is that it increases the amount of data transmitted.

### 2. Key Guessing Attack

Message authentication codes can also be attacked by brute force and birthday attacks. A message authentication code must ensure that the key used by the communicating parties cannot be inferred from the MAC value. This can be guaranteed by the one-way property and collision resistance of a one-way hash function, making it impossible to infer the key.

## VIII. Problems That Message Authentication Codes Cannot Solve

Although message authentication codes can prove that the messages sent by both parties are consistent, have not been tampered with, and are not the result of a man-in-the-middle impersonation, they cannot provide “proof to a third party” or “prevent repudiation.”

The reason they cannot provide “proof to a third party” is that the key used in a message authentication code is a shared key. Both communicating parties have this key, so it is impossible to prove to a third party which of the two parties the message actually came from.  
Solving the problem of “proof to a third party” requires digital signatures.

The reason they cannot “prevent repudiation” is also that both parties have the shared key used by the message authentication code, making it impossible to determine which party sent the message. Therefore, message authentication codes cannot prevent nonrepudiation.  
Solving the problem of “preventing repudiation” requires digital signatures.

## IX. Summary


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/102_2.png'>
</p>

A one-way hash function ensures message consistency and integrity, and that the message has not been tampered with.  
A message authentication code ensures message consistency and integrity, that the message has not been tampered with, and that there is no man-in-the-middle impersonation.  
A digital signature ensures message consistency and integrity, that the message has not been tampered with, that there is no man-in-the-middle impersonation, and that repudiation can be prevented.  

------------------------------------------------------

Reference：
  
*Illustrated Cryptographic Technology*        

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/message\_authentication\_code/](https://halfrost.com/message_authentication_code/)