# Overview of Cryptography


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/96_0.png'>
</p>


## 1. Why Encryption Is Needed

![](https://img.halfrost.com/Blog/ArticleImage/96_3.png)

Everyone has secrets. Without encryption, data transmitted over the Internet can easily be eavesdropped on. If money is involved, leaked passwords can quickly lead to losses. Therefore, we use **encryption** cryptography to ensure the **confidentiality** confidentiality of information.

![](https://img.halfrost.com/Blog/ArticleImage/96_4.png)

After information is encrypted, it becomes ciphertext and is transmitted over the Internet. The receiver obtains the ciphertext and performs **decryption**; after decryption, the plaintext can be read.

![](https://img.halfrost.com/Blog/ArticleImage/96_5.png)

People who try to break ciphers are called cryptanalysts. Cryptanalysts are not necessarily bad actors; cryptography researchers also need to break ciphers in order to study their strength, and in that context researchers are cryptanalysts as well.

> What is the order of encryption and compression?  
> **Compression must always happen before encryption**. After encryption, the redundancy in the bit sequence disappears, making it essentially impossible to compress further. Compressing before encryption is not limited to hybrid cryptosystems; it applies to all cryptographic schemes.

## 2. Symmetric Encryption

**Symmetric cryptography** refers to the approach where the same key is used for both encryption and decryption. The corresponding encryption method is symmetric encryption. AES is widely used today.

Symmetric cryptography has several other names, including **common-key cryptography**, **conventional cryptography**, **secret-key cryptography**, and **shared-key cryptography**.

![](https://img.halfrost.com/Blog/ArticleImage/96_1.png)

**Symmetric cryptography** needs to solve the **key distribution** problem: how to deliver the decryption key to the receiver.


## 3. Asymmetric Encryption

**Public-key cryptography** refers to the approach where different keys are used for encryption and decryption. The corresponding encryption method is asymmetric encryption. RSA is widely used today. (RSA, ElGamal, Rabin, DH, ECDH)

![](https://img.halfrost.com/Blog/ArticleImage/96_2.png)

**Public-key cryptography** solves the key distribution problem, but it carries the risk of impersonation via man-in-the-middle attacks. Therefore, public keys need to be authenticated using digital signatures.

## 4. One-Way Hash Functions

For many free software downloads online, security-conscious publishers release the hash value hash of the software version alongside the software itself to prevent tampering. A hash value is computed using a one-way hash function. Today, SHA-2(SHA-224、SHA-356、SHA-384、SHA-512) and SHA-3(Keccak algorithm), which has a completely new structure, are widely used.

> A **hash value** hash is also called a **hash**, **cryptographic checksum**, **fingerprint**, or **message digest**.

One-way hash functions are not intended to guarantee message confidentiality, but rather **integrity**. Integrity means that the data is correct and has not been forged. A one-way hash function is a cryptographic technique for ensuring information integrity; it detects whether data has been tampered with.

A **one-way hash function** can be used on its own, or as a building block for technologies such as message authentication codes, digital signatures, and pseudorandom number generators.

## 5. Message Authentication Codes

To confirm whether a message comes from the expected communication peer, you can use a **message authentication code**. A message authentication code primarily provides an authentication mechanism, while also ensuring message integrity.

The most commonly used one-way hash function construction for message authentication codes is HMAC. The construction of HMAC does not depend on any specific one-way hash function algorithm.

A **message authentication code** can authenticate a communication peer, but it cannot authenticate to a third party. It also cannot prevent repudiation. Message authentication codes can be used to implement authenticated encryption.

## 6. Digital Signatures

Consider this scenario: A owes B one million dollars, so A writes B an IOU. A week later, after receiving the money, A denies that he wrote the IOU and repudiates the loan.

This is where the anti-repudiation technology in cryptography comes in — **digital signatures**. Digital signatures are analogous to signatures and seals in the real world. A digital signature is a cryptographic technique that prevents users from repudiating, impersonating, tampering with, or denying something. Widely used digital signature algorithms include RSA, ElGamal, DSA, elliptic curve DSA(ECDSA), Edwards-curve DSA(EDDSA), and others.

If user B can have A attach his own signature(digital signature) when writing the IOU, this can prevent A from repudiating it later.

Certificates used in public key infrastructure PKI are constructed by adding a certificate authority’s digital signature to a public key. To verify the digital signature on a public key, you need to obtain the certificate authority’s own legitimate public key through some channel.

## 7. Pseudorandom Number Generators

A **pseudorandom number generator**(Pseudo Random Number Generator，PRNG) is an algorithm capable of simulating the generation of a random sequence. Pseudorandom numbers are responsible for **key generation**. PRNGs are built from technologies such as ciphers and one-way hash functions, and are mainly used to generate keys, initialization vectors, nonce values, and so on.


## 8. Steganography and Digital Watermarks

Encryption is intended to make the message content itself unreadable. Steganography is intended to hide the existence of the message itself.

For example, you can hide an image inside a piece of music by inserting the binary bits of the image into specific bit positions. As long as you remember which bits belong to the image and which belong to the music, you can restore both the music and the image.

Another example: in iOS development, you can hide a local client certificate inside image resources. That way, even if a malicious actor unpacks the ipa installation package, they will not find the certificate file at first glance—unless they first reverse engineer the code and discover the steganographic algorithm, which would allow them to recover the real certificate file.

Digital watermarking uses steganographic methods. A digital watermark is a technique for embedding information about the copyright owner and purchaser into a file. However, digital watermarking alone cannot keep information confidential, so it must be combined with other techniques.


Encryption and steganography can be combined. This is similar to the example above where a certificate is hidden inside an image. The certificate is encrypted, so it hides the sensitive information, while steganography hides the certificate itself.


## 9. The Essence of Cryptographic Techniques

![](https://img.halfrost.com/Blog/ArticleImage/95_5.png)

The full contents of a cryptographer’s toolbox are summarized below:

![](https://img.halfrost.com/Blog/ArticleImage/96_6.png)

**Cryptographic techniques are essentially compression techniques**

![](https://img.halfrost.com/Blog/ArticleImage/96_7.png)

- Symmetric encryption and public-key cryptography are **compression of confidentiality**
- One-way hash functions are **compression of integrity**
- Message authentication codes and digital signatures are **compression of authentication**
- Pseudorandom number generators are **compression of unpredictability**

>In a message authentication code, the MAC value is the authentication symbol; in a digital signature, the signature is the authentication symbol. Both authenticate a longer message using a shorter authentication symbol.


- A key is the essence of confidentiality
- A hash value is the essence of integrity
- An authentication symbol(MAC value and signature) is the essence of authentication
- A seed is the essence of unpredictability

||Before compression||After compression||
|:----:|:----:|:----:|:----:|:----:|
|Symmetric cryptography|Plaintext|--->|Key|Compression of confidentiality|
|Public-key cryptography|Plaintext|--->|Key|Compression of confidentiality|
|One-way hash function|Message|--->|Hash value|Compression of integrity|
|Message authentication code|Message|--->|Authentication symbol(MAC value)|Compression of authentication|
|Digital signature|Message|--->|Authentication symbol(signature)|Compression of authentication|
|Pseudorandom number generator|Pseudorandom sequence|--->|Seed|Compression of unpredictability|

## 10. Common Sense About Information Security

1. Do not use secret or proprietary cipher algorithms
2. Using weak cryptography is more dangerous than not encrypting at all
3. Every cipher will be broken someday
4. Cryptography is only one part of information security


## 11. Famous Ciphers in History

Famous ciphers in history include the Caesar cipher, the simple substitution cipher, and Enigma.

The Caesar cipher simply shifts the plaintext by n positions to obtain the ciphertext. This cipher is weak and can be brute-forced; trying shifts from 0 to 25 is enough to break it.

A simple substitution cipher maps plaintext to ciphertext according to a mapping table. This cipher can also be broken using frequency analysis. The frequency with which letters appear in an article is basically fixed; by observing the frequency of letters in the ciphertext, the mapping table can be inferred.

Enigma was the cipher machine used by Germany during World War II. It generated keys using rotors and plugboard wiring. The process is somewhat complex. In 1940, Turing developed a machine for breaking Enigma.


## 12. PGP Software

### 1. Encryption

![](https://img.halfrost.com/Blog/ArticleImage/96_8.png)

### Generate and Encrypt the Session Key

1. Generate a session key using a pseudorandom number generator.
2. Encrypt the session key using public-key cryptography; the key used here is the receiver’s public key.

### Compress and Encrypt the Message

3. Compress the message
4. Encrypt the compressed message using a symmetric cipher; the key used here is the session key from step 1
5. Concatenate the encrypted session key from step 2 with the encrypted message from step 4
6. Convert the result of step 5 into text data; the converted result is the message data

> Use public-key cryptography to encrypt the session key, and use symmetric cryptography to encrypt the message.

### 2. Decryption

![](https://img.halfrost.com/Blog/ArticleImage/96_9.png)

### Decrypt the Private Key

1. The receiver enters the decryption passphrase to unlock password-based encryption(PBE)
2. Compute the hash value of the passphrase and generate the key used to decrypt the private key
3. Decrypt the encrypted private key in the keyring

### Decrypt the Session Key

4. Convert the message data(text data) into binary data
5. Split the binary data into two parts: the encrypted session key, and the compressed and encrypted message
6. Decrypt the session key using public-key cryptography; here, the receiver’s private key generated in step 3 is used


### Decrypt and Decompress the Message

7. Decrypt the compressed and encrypted message obtained in step 5 using a symmetric cipher. Use the session key generated in step 6
8. Decompress the compressed message obtained in step 7
9. Obtain the original message

### 3. Generate a Digital Signature

![](https://img.halfrost.com/Blog/ArticleImage/96_10.png)

### Decrypt the Private Key

1. The sender enters the passphrase used for signing(PBE)
2. Compute the hash value of the passphrase and generate the key used to decrypt the private key
3. Decrypt the encrypted private key in the keyring

### Generate the Digital Signature

4. Compute the message hash value using a one-way hash function
5. Sign the hash value obtained in step 4; this is equivalent to using the private key obtained in step 3.
6. Concatenate the digital signature generated in step 5 with the message
7. Compress the result from step 6
8. Convert the result from step 7 into text data
9. The result from step 8 is the message data

### 4. Verify the Digital Signature

![](https://img.halfrost.com/Blog/ArticleImage/96_11_.png)

### Recover the Hash Value Sent by the Sender

1. Convert the message data(text data) into binary data
2. Decompress the compressed data
3. Split the decompressed data into two parts: the signed hash value and the message
4. Decrypt the signed hash value(encrypted hash value) using the sender’s public key, recovering the hash value sent by the sender

### Compare the Hash Values

5. Input the message extracted in step 3 into a one-way hash function to compute its hash value
6. Compare the hash value obtained in step 4 with the hash value obtained in step 5
7. If the results in step 6 are equal, digital signature verification succeeds; if they are not equal, verification fails.
8. The message extracted in step 3 is the message sent by the sender


### 5. Generate a Digital Signature and Encrypt

![](https://img.halfrost.com/Blog/ArticleImage/96_12_.png)

This looks complicated, but it is really just a combination of the previous steps. First generate the digital signature, then perform encryption. The thing being encrypted is not just the message itself, but the data obtained by concatenating the digital signature and the message.


### 6. Decrypt and Verify the Digital Signature

![](https://img.halfrost.com/Blog/ArticleImage/96_13.png)

This is also a combination of the previous digital signature verification and decryption steps. During decryption, the data decrypted first is not just the message, but the data obtained by concatenating the digital signature and the message.

------------------------------------------------------

Reference：
  
Understanding Cryptography by Manga      


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/cryptography\_overview/](https://halfrost.com/cryptography_overview/)