+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS", "Cryptography"]
date = 2018-10-07T05:04:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/106_0.png"
slug = "cipherkey"
tags = ["Protocol", "HTTPS", "Cryptography"]
title = "The Essence of Secrets—Keys"

+++


## 1. Why Do We Need Keys?

>The essence of cryptography is turning a longer secret—the message—into a shorter secret—the key.  
>									—————Bruce Schneier, *Secrets and Lies: Digital Security in a Networked World*


In the previous articles, we learned that symmetric ciphers, public-key ciphers, message authentication codes, digital signatures, and public-key certificates all require a key. A key protects the confidentiality of information. The most important property of a key is the **size of its keyspace**. The length of the key determines the size of the keyspace. The larger the keyspace, the harder it is to brute-force.


## 2. What Is a Key?

A key is merely a sequence of bits, but its value is equivalent to that of the plaintext. Keys are mainly classified into the following types:

### 1. Keys for Symmetric Ciphers and Keys for Public-Key Ciphers

In symmetric encryption, the same key is used for both encryption and decryption; this is also called a shared-key cipher.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_1.png'>
</p>

In public-key cryptography, different keys are used for encryption and decryption. The key used for encryption and allowed to be public is called the public key. The key used for decryption and not allowed to be public is called the private key.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_2.png'>
</p>

### 2. Keys for Message Authentication Codes and Keys for Digital Signatures

In a message authentication code, the sender and receiver use a shared key for authentication. A message authentication code can only be computed by someone who holds the legitimate key. By comparing the message authentication code, you can determine whether a message has been tampered with or forged.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_3.png'>
</p>


In a digital signature, different keys are used for generating and verifying the signature. Only the person who holds the private key can generate the signature, but since the public key is used to verify the signature, anyone can verify it.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_4.png'>
</p>


### 3. Keys for Confidentiality and Keys for Authentication

- Symmetric keys and public-key cryptography keys are both **keys used to ensure confidentiality**. If someone does not know the legitimate key used for decryption, the plaintext can be kept confidential.

- The keys used by message authentication codes and digital signatures are **keys used for authentication**. Without the legitimate key, data cannot be tampered with, nor can identities be forged.


### 4. Session Keys and Master Keys

In the TLS handshake in HTTPS, a one-time key is used only for the current communication and cannot be used next time. A key that can only be used once per communication is called a **session key**.

Because a new session key is generated for each session, even if the key is eavesdropped on, only the current session is affected. If the same key is used every time, it is called a **master key**.


### 5. Keys for Encrypting Content and Keys for Encrypting Keys

When the object being encrypted is information directly used by the user (content), the key is called a **CEK (Contents Encrypting Key)**. A key used to encrypt another key is called a **KEK (Key Encrypting Key)**.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_5.png'>
</p>

A session key is used as a CEK. A master key is used as a KEK.


## 3. Generating, Distributing, and Updating Keys

### 1. Generating Keys

- Generate keys using random numbers. The best way to generate a key is to **use random numbers**.
- Generate keys from passwords. To prevent dictionary attacks, a random number string called a **salt** is usually appended to the password. This approach is called password-based cryptography.

### 2. Distributing Keys

- Share the key in advance
- Use a key distribution center
- Use public-key cryptography
- Diffie-Hellman key exchange

### 3. Updating Keys

This technique is usually used with shared keys. During communication using a shared key, the key is changed periodically (for example, every 1000 words sent). Of course, the sender and receiver must change keys in sync.

When updating the key, the sender and receiver compute the hash value of the current key using a one-way hash function, and use that hash value as the new key. **Use the hash value of the current key as the next key**.

The benefit of key update is that if an eavesdropper steals the key for a session, the content after that key can be decrypted, but the eavesdropper cannot decrypt the communication content before that key was updated. This is due to the one-way property of the one-way hash function. This mechanism that prevents past communication content from being decrypted is called **backward security**.


## 4. Diffie-Hellman Key Exchange

Diffie-Hellman key exchange is an algorithm jointly invented by Whitfield Diffie and Martin Hellman in 1976. With this algorithm, two communicating parties can generate a shared symmetric cipher key solely by exchanging information that may be made public.

Although this algorithm is called “key exchange,” no key is actually exchanged. Instead, the same shared key is generated through computation. More precisely, it should be called Diffie-Hellman key agreement.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_6.png'>
</p>

1. Alice sends Bob two prime numbers, P and G   
P is a very large prime number, and G is a smaller number called a generator. P and G can be public, and either party can generate P and G.


2. Alice generates a random number A    
A is an integer between 1 and (P-2). Only Alice knows this number.


3. Bob generates a random number B  
B is an integer between 1 and (P-2). Only Bob knows this number.


4. Alice sends the result of (G^A mod P) to Bob  
It does not matter if this number is eavesdropped on.


5. Bob sends the result of (G^B mod P) to Alice  
It does not matter if this number is eavesdropped on.


6. Alice uses the number sent by Bob to compute the A-th power and then takes mod P  
This number is the final shared key.
```c
(G^B mod P)^A mod P = G^(B*A) mod P 
                    = G^(A*B) mod P
```
7. Bob raises the number sent by Alice to the power of B and computes it mod P  
This number is the final shared key.
```c
(G^A mod P)^B mod P = G^(A*B) mod P
```
At this point, the keys computed by A and B are identical.

The information an eavesdropper can obtain is: P, G, G^A mod P, and G^B mod P. Computing G^(A*B) mod P from these four values is extremely difficult.

If either A or B were known, all of the steps above could be broken and the final shared key could be computed. However, the eavesdropper can only obtain G^A mod P and G^B mod P. The mod P here is the key point: if G^A were known directly, A could be computed, but in this case A and B cannot be derived, because this is the **discrete logarithm problem** over a finite field.

>The hardness of the discrete logarithm problem over finite fields is the foundation that supports Diffie-Hellman key exchange.


Although DH key exchange can prevent key cracking, it cannot defend against man-in-the-middle attacks.

A man in the middle can sit between Alice and Bob and perform DH key exchange separately with each party, thereby intercepting their communications. DH defends against man-in-the-middle attacks in the same way as public-key cryptography does: by using digital signatures and certificates.

The Diffie-Hellman key exchange used in IPSec has been improved and extended specifically to address this man-in-the-middle attack.


## V. Password-Based Encryption PBE

Password-Based Encryption (PBE) is a method that generates a key from a password and uses that key for encryption. The same key is used for encryption and decryption.

The reasons for using PBE are:

1. How do we keep a message secret? If we store it directly on disk, it may be discovered, so let’s encrypt it. This generates a CEK key.
2. How do we safely store the CEK key? Encrypt the CEK with another key. This generates a KEK key.
3. How do we safely store the KEK key? This leads to an infinite loop, so use a PBE password to generate the KEK.
4. Passwords are vulnerable to dictionary attacks. Add a salt first, then store it together with the encrypted CEK on disk, and the KEK can be discarded.
5. In the end, you only need to remember the password.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_7.png'>
</p>


### 1. PBE Encryption

PBE encryption mainly consists of three steps:

1. Generate the KEK
2. Generate a session key and encrypt it
3. Encrypt the message

After PBE encryption, three items are output:

- Salt
- The session key encrypted with the KEK
- The message encrypted with the session key

The salt and session key need to be stored in a secure location, while the message is sent to the other party.


### 2. PBE Decryption

PBE decryption mainly consists of three steps:

1. Reconstruct the KEK
2. Decrypt the session key
3. Decrypt the message


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_8.png'>
</p>

Compared with the PBE encryption process, you can see that the encryption process uses a pseudorandom number generator twice, while the decryption process does not use one at all.

**The primary purpose of the salt is to prevent dictionary attacks**.


## VI. Improved PBE

Because the KEK generated from a password is not as strong as the session key CEK generated by a pseudorandom number generator, it is like storing the key to a secure safe in an insecure place. Therefore, when using password-based encryption PBE, the salt and the encrypted CEK need to be protected by physical means. Here is an improved approach.


When generating the KEK, security can be improved by repeatedly applying a one-way hash function. A good method is to input the salt and password into the one-way hash function, then input the resulting value into the one-way hash function again, and repeat this process 1000 times, using the final hash value as the KEK.

For a user, computing the one-way hash value 1000 times does not consume much time, but for an attacker, it becomes a significant obstacle. This method of iterating a one-way hash function many times is called stretching.


------------------------------------------------------

Reference:
  
"Illustrated Cryptographic Technology"        

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/cipherkey/](https://halfrost.com/cipherkey/)