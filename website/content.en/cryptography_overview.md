+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS", "Cryptography"]
date = 2018-08-04T17:01:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/96_0.png"
slug = "cryptography_overview"
tags = ["Protocol", "HTTPS", "Cryptography"]
title = "Overview of Cryptography"

+++


## 1. Why Encryption Is Needed

![](https://img.halfrost.com/Blog/ArticleImage/96_3.png)

Everyone has their own secrets. Without encryption, data transmitted over the Internet can easily be eavesdropped on. If money is involved, leaked passwords can easily lead to losses. Therefore, we use **encryption** cryptography techniques to ensure the **confidentiality** of information.

![](https://img.halfrost.com/Blog/ArticleImage/96_4.png)

After information is encrypted, it becomes ciphertext and is transmitted over the Internet. The recipient obtains the ciphertext and performs **decryption** cryptanalysis; after decryption, the plaintext becomes visible.

![](https://img.halfrost.com/Blog/ArticleImage/96_5.png)

A person who cracks passwords is called a cryptanalyst. Cryptanalysts are not necessarily bad actors; cryptography researchers also need to break ciphers in order to study their strength, and in that context they are cryptanalysts as well.

> What is the order of encryption and compression?  
> **Compression must always come before encryption**. After encryption, the redundancy in the bit sequence disappears, making it essentially impossible to compress further. Compressing before encryption is not limited to hybrid cryptosystems; it applies to all cryptographic systems.

## 2. Symmetric Encryption

**Symmetric cryptography** refers to the approach where the same key is used for both encryption and decryption. The corresponding encryption method is symmetric encryption. AES is widely used today.

Symmetric cryptography has many aliases, including **common-key cryptography**, **conventional cryptography**, **secret-key cryptography**, and **shared-key cryptography**.

![](https://img.halfrost.com/Blog/ArticleImage/96_1.png)

**Symmetric cryptography** needs to solve the **key distribution** problem: delivering the decryption key to the recipient.


## 3. Asymmetric Encryption

**Public-key cryptography** refers to the approach where different keys are used for encryption and decryption. The corresponding encryption method is asymmetric encryption. RSA is widely used today. (RSA, ElGamal, Rabin, DH, ECDH)

![](https://img.halfrost.com/Blog/ArticleImage/96_2.png)

**Public-key cryptography** solves the key distribution problem, but it is vulnerable to impersonation via man-in-the-middle attacks. Therefore, public keys with digital signatures need to be authenticated.

## 4. One-Way Hash Functions

For many free software packages on the Internet, security-conscious publishers release the hash value of each software version when they publish it, in order to prevent tampering. A hash value is a value computed using a one-way hash function. SHA-2 (SHA-224, SHA-356, SHA-384, SHA-512) and SHA-3 (the Keccak algorithm), which has an entirely new structure, are widely used today.

> A **hash value** hash is also called a **hash**, **cryptographic checksum**, **fingerprint**, or **message digest**.

One-way hash functions are not intended to ensure the confidentiality of a message, but rather its **integrity**. Integrity means that data is correct and has not been forged. A one-way hash function is a cryptographic technique that ensures the integrity of information by detecting whether data has been tampered with.

**One-way hash functions** can be used independently, or as building blocks in technologies such as message authentication codes, digital signatures, and pseudorandom number generators.

## 5. Message Authentication Codes

To verify whether a message comes from the expected communication peer, you can use a **message authentication code**. A message authentication code primarily provides an authentication mechanism, while also ensuring message integrity.

The most commonly used one-way hash function construction for message authentication codes is HMAC. HMAC is not tied to any particular one-way hash function algorithm.

A **message authentication code** can authenticate a communication peer, but it cannot authenticate a third party. It also cannot prevent repudiation. Message authentication codes can be used to implement authenticated encryption.

## 6. Digital Signatures

Consider the following situation: A owes B one million US dollars, so A writes B an IOU. A week later, after A gets the money, A refuses to admit that the IOU was written by them and denies having borrowed the money.

This involves the non-repudiation technology in cryptography — **digital signatures**. A digital signature is similar to a signature or seal in the real world. It is a cryptographic technique that can prevent users from repudiating, impersonating, tampering, and denying. Widely used digital signature algorithms today include RSA, ElGamal, DSA, Elliptic Curve DSA (ECDSA), Edwards-curve DSA (EDDSA), and others.

If user B can have A sign their own signature (digital signature) when writing the IOU, this can prevent A from repudiating it later.

Certificates used in a public key infrastructure PKI are constructed by adding a certificate authority’s digital signature to a public key. To verify the digital signature on a public key, you need to obtain the certificate authority’s own legitimate public key through some channel.

## 7. Pseudorandom Number Generators

A **Pseudorandom Number Generator** (PRNG) is an algorithm capable of simulating the generation of a random number sequence. Pseudorandom numbers are responsible for **key generation**. A PRNG is built from technologies such as ciphers and one-way hash functions, and is mainly used to generate keys, initialization vectors, nonces, and so on.


## 8. Steganography and Digital Watermarking

Encryption technology is intended to make the message content itself unreadable. Steganography, however, is intended to hide the existence of the message itself.

For example, an image can be hidden inside a piece of music by inserting the binary bits of the image into specific bit positions. As long as you remember which bits belong to the image and which belong to the music, you can reconstruct both the music and the image.

Another example: in iOS development, a client-side local certificate can be hidden inside image assets. This way, even if a malicious actor unpacks the ipa installation package, they will not immediately find the certificate file at first glance. They would first need to reverse engineer the code and find the steganography algorithm before they could obtain the actual certificate file.

Digital watermarking uses steganographic methods. Digital watermarking is a technique for embedding information about the copyright owner and purchaser into a file. However, digital watermarking alone cannot keep information confidential, so it needs to be combined with other technologies.


Encryption and steganography can be used together, similar to the example above where a certificate is hidden inside an image. The certificate is encrypted, so it hides sensitive information; steganography further hides the certificate itself.


## 9. The Essence of Cryptographic Technology

![](https://img.halfrost.com/Blog/ArticleImage/95_5.png)

The complete contents of a cryptographer’s toolbox are summarized as follows:

![](https://img.halfrost.com/Blog/ArticleImage/96_6.png)

**The essence of cryptographic technology is compression technology**

![](https://img.halfrost.com/Blog/ArticleImage/96_7.png)

- Symmetric encryption and public-key cryptography are **compression of confidentiality**
- One-way hash functions are **compression of integrity**
- Message authentication codes and digital signatures are **compression of authentication**
- Pseudorandom number generators are **compression of unpredictability**

>In message authentication codes, the MAC value is the authentication symbol; in digital signatures, the signature is the authentication symbol. Both use a shorter authentication symbol to authenticate a longer message.


- A key is the essence of confidentiality
- A hash value is the essence of integrity
- An authentication symbol (MAC value and signature) is the essence of authentication
- A seed is the essence of unpredictability

||Before compression||After compression||
|:----:|:----:|:----:|:----:|:----:|
|Symmetric cryptography|Plaintext|--->|Key|Compression of confidentiality|
|Public-key cryptography|Plaintext|--->|Key|Compression of confidentiality|
|One-way hash function|Message|--->|Hash value|Compression of integrity|
|Message authentication code|Message|--->|Authentication symbol (MAC value)|Compression of authentication|
|Digital signature|Message|--->|Authentication symbol (signature)|Compression of authentication|
|Pseudorandom number generator|Pseudorandom number sequence|--->|Seed|Compression of unpredictability|

## 10. Common Sense About Information Security

1. Do not use secret cryptographic algorithms
2. Using weak cryptography is more dangerous than not encrypting at all
3. Every cipher will be broken someday
4. Cryptography is only one part of information security


## 11. Famous Ciphers in History

Famous ciphers in history include the Caesar cipher, the simple substitution cipher, and Enigma.

The Caesar cipher simply shifts the plaintext by n positions to obtain the ciphertext. This cipher is weak and can be brute-forced; shifting left and right and trying 0–25 positions is enough to break it.

A simple substitution cipher maps plaintext to ciphertext according to a mapping table. This cipher can also be broken using frequency analysis. The frequency of letters in an article is basically stable; by observing the frequency of letters in the ciphertext, you can infer the mapping table.

Enigma was a cipher machine used by Germany during World War II. It generated keys using rotors and plugboard wiring. The process is somewhat complex. In 1940, Turing developed a machine for breaking Enigma.


## 12. PGP Software

### 1. Encryption

![](https://img.halfrost.com/Blog/ArticleImage/96_8.png)

### Generate and encrypt the session key

1. Generate a session key using a pseudorandom number generator.
2. Encrypt the session key using public-key cryptography. The key used here is the recipient’s public key.

### Compress and encrypt the message

3. Compress the message
4. Encrypt the compressed message using symmetric cryptography. The key used here is the session key from step 1
5. Concatenate the encrypted session key from step 2 with the encrypted message from step 4
6. Convert the result from step 5 into text data; the converted result is the message data

> Use public-key cryptography to encrypt the session key, and symmetric cryptography to encrypt the message.

### 2. Decryption

![](https://img.halfrost.com/Blog/ArticleImage/96_9.png)

### Decrypt the private key

1. The recipient enters the decryption passphrase to unlock the passphrase-based encryption (PBE)
2. Compute the hash value of the passphrase and generate the key used to decrypt the private key
3. Decrypt the encrypted private key in the keyring

### Decrypt the session key

4. Convert the message data (text data) into binary data
5. Split the binary data into two parts: the encrypted session key and the compressed and encrypted message
6. Decrypt the session key using public-key cryptography. Here, the recipient’s private key generated in step 3 is used


### Decrypt and decompress the message

7. Decrypt the compressed and encrypted message obtained in step 5 using symmetric cryptography. Use the session key generated in step 6
8. Decompress the compressed message obtained in step 7
9. Obtain the original message

### 3. Generate a digital signature

![](https://img.halfrost.com/Blog/ArticleImage/96_10.png)

### Decrypt the private key

1. The sender enters the passphrase for signing (PBE)
2. Compute the hash value of the passphrase and generate the key used to decrypt the private key
3. Decrypt the encrypted private key in the keyring

### Generate a digital signature

4. Compute the hash value of the message using a one-way hash function
5. Sign the hash value obtained in step 4. This step is equivalent to encrypting with the private key obtained in step 3.
6. Concatenate the digital signature generated in step 5 with the message
7. Compress the result from step 6
8. Convert the result from step 7 into text data
9. The result from step 8 is the message data

### 4. Verify a digital signature

![](https://img.halfrost.com/Blog/ArticleImage/96_11_.png)

### Recover the hash value sent by the sender

1. Convert the message data (text data) into binary data
2. Decompress the compressed data
3. Split the decompressed data into two parts: the signed hash value and the message
4. Decrypt the signed hash value (the encrypted hash value) using the sender’s public key, recovering the hash value sent by the sender

### Compare hash values

5. Input the message split out in step 3 into a one-way hash function to compute its hash value
6. Compare the hash value obtained in step 4 with the hash value obtained in step 5
7. If the results in step 6 are equal, digital signature verification succeeds; if they are not equal, verification fails.
8. The message split out in step 3 is the message sent by the sender

### 5. Generate a Digital Signature and Encrypt

![](https://img.halfrost.com/Blog/ArticleImage/96_12_.png)

This looks complex, but it is actually just a combination of the previous steps. First generate the digital signature, and then encrypt. What gets encrypted is not just the message itself, but the data formed by concatenating the digital signature and the message.


### 6. Decrypt and Verify the Digital Signature

![](https://img.halfrost.com/Blog/ArticleImage/96_13.png)

This is also a combination of the earlier steps for verifying a digital signature and decrypting. What gets decrypted first is not just the message, but the data formed by concatenating the digital signature and the message.

------------------------------------------------------

Reference:
  
*Cryptography Technology Illustrated*      


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/cryptography\_overview/](https://halfrost.com/cryptography_overview/)