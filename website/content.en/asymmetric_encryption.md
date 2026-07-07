+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS", "Cryptography"]
date = 2018-08-19T00:22:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/101_0.png"
slug = "asymmetric_encryption"
tags = ["Protocol", "HTTPS", "Cryptography"]
title = "Aoyou Public-Key Cryptographic Algorithm"

+++


## I. Introduction

In symmetric encryption, such as the one-time pad, there is the problem of key distribution. This problem also exists in DES and AES. Because the keys for encryption and decryption are the same, the key must be delivered to the recipient. If public-key cryptography is used, there is no need to deliver the decryption key to the recipient. This solves the key distribution problem, and public-key cryptography can be regarded as one of the greatest inventions in the history of cryptography.


## II. The Key Distribution Problem

To prevent a man-in-the-middle from intercepting the key, the key must be delivered securely to the communicating party. There are four approaches:

### 1. Pre-shared Keys

Although this method is effective, it has limitations. In the one-time pad example, we mentioned that hotlines between major powers are encrypted this way, but the keys are delivered by agents. If the communicating party is nearby, sharing a key in advance is relatively convenient. If the communicating parties are all over the world, this approach becomes limited.

In addition, as communication volume increases, the number of keys also grows sharply. For n people to communicate pairwise, n * (n-1) /2 keys are required. From this perspective, it is also impractical.

### 2. Key Distribution Center

To solve the problem of the increasing number of pre-shared keys, someone proposed the Key Distribution Center (KDC) approach. The encryption key for each session is distributed by the key center; each person only needs to share a key with the key center in advance.

Although this method solves the problem of too many keys, it introduces new problems.

The key center stores and records all keys. Once it fails or is compromised by an attack, all encryption will be paralyzed. This is also a drawback of centralized management.


### 3. Diffie-Hellman Key Exchange

To address the drawbacks of centralized management, key distribution should not rely on a centralized model. This led to the Diffie-Hellman key exchange method.

In Diffie-Hellman key exchange, the two parties in encrypted communication need to exchange some information, and even if this information is eavesdropped on, it does not cause any problem.

Based on the exchanged information, both parties independently generate the same key. An eavesdropper, however, cannot generate the same key. This approach is feasible. However, it is not considered asymmetric encryption, so it will not be discussed in detail in this article.

### 4. Public-Key Cryptography

Asymmetric encryption has a public key and a private key. The public key can be distributed online; it does not matter if an eavesdropper obtains it, because without the private key, they cannot decrypt the ciphertext. As long as the private key is held only by the recipient, the ciphertext will not be exposed to eavesdroppers.

For example: consider the baggage lockers in a supermarket. Any customer with a coin can store a bag. The coin is the “public key”; the customer puts the bag into the locker (encrypts the plaintext), and once the locker is locked, no one can open it. At this point, an eavesdropper cannot take the stored bag either. This plaintext (the bag) can only be opened with the private key. After the customer stores the bag, a private key is generated; as long as the customer has this key, they can open the locker and retrieve the bag at any time.


## III. Asymmetric Encryption

Asymmetric encryption generally refers to encryption algorithms with public-key cryptography. Keys are divided into two types: encryption keys and decryption keys. The sender encrypts the information with the encryption key, and the recipient decrypts the ciphertext with the decryption key. The key that can be made public is called the public key, while the key kept private and not disclosed is called the private key.

The public key and private key correspond one-to-one. A public key and a private key together are called a key pair. In terms of their mathematical relationship, the two cannot be generated independently.


## IV. Problems with Asymmetric Encryption

Although public-key cryptography solves the key distribution problem, that does not mean it solves every problem. Public-key cryptography has the following issues:

- Public-key authentication
- Processing speed is less than one-tenth that of symmetric encryption

## V. RSA Algorithm Workflow

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_3.png'>
</p>


RSA is a public-key cryptographic algorithm. Its name is formed from the initials of the surnames of its three developers: Ron Rivest, Adi Shamir, and Leonard Adleman (Rivest-Shamir-Adleman). In 1983, RSA obtained rights to the RSA algorithm in the United States, but that patent has now expired.

RSA can be used for public-key encryption and digital signatures.

### 1. RSA Encryption

In RSA, the plaintext, key, and ciphertext are all numbers. The encryption process can be represented by the following formula:
```c
Ciphertext = Plaintext^E mod N
```
The RSA ciphertext is the result of raising the number representing the plaintext to the power of E and taking mod N. E and N are the RSA encryption key; **the combination of E and N is the public key**. E is the first letter of Encryption, and N is the first letter of Number.


### 2. RSA Decryption

The RSA decryption process can be represented by the following formula:
```c
Plaintext = Ciphertext^D mod N
```
The decryption process computes the ciphertext number raised to the power of D modulo N to obtain the plaintext. **The combination of D and N is the private key**. D is the initial letter of Decryption, and N is the initial letter of Number.

What makes RSA remarkable is that the encryption and decryption processes are consistent. Encryption computes the plaintext raised to the power of E modulo N. Decryption computes the ciphertext raised to the power of D modulo N.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_2.png'>
</p>


### 3. Generating a Key Pair

E and N form the public key, while D and N form the private key. Therefore, deriving these three numbers—E, D, and N—is the process of **generating a key pair**. The specific workflow is mainly divided into four steps:

- Derive N
- Derive L (L is a number used only during the key pair generation process)
- Derive E
- Derive D

The main steps are shown in the figure below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_5.png'>
</p>

First, compute N.

To compute N, you need to prepare two very large prime numbers. If the primes are too small, the system is easy to break; if they are too large, computation takes a very long time. Both p and q are generated by a pseudorandom number generator, and p != q. N = p * q.

Next, compute L.

The number L is used only during the process of generating the key pair; it does not appear during encryption or decryption.
L is the least common multiple (lcm) of p - 1 and q - 1.

Next, derive the number E.

The number E must satisfy two conditions:
```c
1 < E < L

gcd(E,L) = 1 ， the greatest common divisor of E and L is 1 (E and L are coprime)
```
Condition 1 is generated using a pseudorandom spanning tree. Condition 2 ensures that the number D required for decryption must exist. The greatest common divisor can be computed using Euclid’s algorithm.

At this point, we have generated the public key {E, M} in the key pair.

Next, compute D.

The number D is computed from the number E. D, E, and L have the following relationship:
```c
1 < D < L

E * D mod L = 1
```
As long as D satisfies the conditions above, ciphertext encrypted with E and N can be decrypted with D and N. To guarantee that such a D exists, we must first ensure that the greatest common divisor of E and L is 1. The condition `E * D mod L = 1` ensures that decrypting the ciphertext yields the original plaintext.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_6_.png'>
</p>

To summarize the derivation process:
```c
Plaintext = Ciphertext^D mod N
	 = (Plaintext^E)^D mod N
	 = Plaintext^(E * D) mod N

E * D mod L = 1 ensures that the final transformation can be restored to the plaintext. For the detailed derivation, see Mr. Ruan's two RSA analysis articles in the Reference section at the end of the article.
```

## VI. Directly Attacking RSA

To directly attack RSA, that is, to derive the plaintext from the ciphertext. We know:
```c
Ciphertext = Plaintext^E mod N
```
An attacker can obtain the ciphertext and the public key `{E,N}`. The problem is then transformed into one of computing a discrete logarithm. At present, there is no efficient algorithm for this problem, so this approach is not viable.

Consider a different approach: derive the private key, then recover the plaintext by decrypting it in sequence. The public key already contains `N`; for the private key, we also need `D`. So can `D` be computed by brute force?

In general, both `p` and `q` are over 1024 bits in length, and `N` is over 2048 bits. The length of `D` is roughly the same as that of `N`, which means breaking it would require attacking a value of more than 2048 bits. Doing so within a realistic time frame is extremely difficult. (Unless quantum computers become available in the future; of course, once quantum computers arrive, existing encryption systems as we know them will be completely overturned.)

Since brute-forcing `D` is impossible, is it feasible to compute `D` from `E` and `N`? Let’s summarize the existing conditions that could be used to brute-force `D`:
```c
E * D mod L = 1

N = p * q

L = lcm( p-1 , q-1)

```
At this point, we know E and N. To compute D, we first need to compute L, and L is related to p and q. p * q happens to equal N. So the first step is to crack p and q.

Currently, factoring a large number N into its prime factors is difficult. **Once an efficient algorithm for prime factorization of large integers is discovered, RSA will also be breakable**. At present, no effective algorithm exists. It is also impossible to derive p and q by guessing. p and q generally have a large number of bits.

**In RSA, p and q have the same status as the private key. Once p and q are leaked, it is equivalent to leaking the private key**.


## 7. Indirect Attacks on RSA

An indirect attack on RSA refers to using a man-in-the-middle attack.

For example, as shown below:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_7.png'>
</p>

The active attacker Mallory intercepts the public keys of both communicating parties. Then Mallory sends each party Mallory’s own public key. In this way, the attacker can intercept the ciphertext from both sides and decrypt it with their own private key. After decrypting it into plaintext, the attacker can arbitrarily tamper with the original message, ultimately achieving the attack objective.


RSA by itself cannot defend against this kind of attack. To defend against man-in-the-middle attacks, authentication-related algorithms are required. Authentication-related algorithms will be explained in detail in the next article.


## 8. Elliptic Curve Cryptography

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_16.webp'>
</p>

Elliptic Curve Cryptography (ECC) is a public-key cryptographic algorithm that has attracted significant attention recently. Its key characteristic is that it requires shorter keys than RSA. **Elliptic curve cryptography uses short keys while providing high strength**. An elliptic-curve key length of 224–255 bits provides the same security strength as a 2048-bit RSA key.

The correspondence is as follows:

|RSA Key Length (bit)	| ECC Key Length (bit)| AES Key Length (bit)|
|:-----:|:-----:|:-----:|
|1024	 |160|80 |
|2048	|224| 112|
|3072	|256| 128 |
|7680	|384| 192 |
|15360|	521| 256|


|Cryptographic Algorithm | Recommended Secure Key Length|
|:----:|:-----:|
|AES symmetric encryption algorithm | 128 bits|
|RSA encryption and signature algorithm | 2048 bits|
|DSA digital signature algorithm | 2048 bits|
|ECC elliptic curve algorithm | 256 bits|


Because ECC keys are very short, operations are relatively fast. So far, performing the inverse operation for ECC is still very difficult, and it has been mathematically proven to be unbreakable. The advantages of the ECC algorithm are high performance and strong security. In practical applications, it can be combined with other public-key algorithms to form faster and more secure public-key algorithms, such as combining it with DH keys to form the ECDH key agreement algorithm, or combining it with the DSA digital signature algorithm to form the ECDSA digital signature algorithm.

|Algorithm	| Encryption/Decryption| Digital Signature|Key Exchange |
|:-----:|:-----:|:-----:|:-----:|
|RSA	 |✅| ✅| ✅|
|Diffie-Hellman	|❌| ❌| ✅|
|DSS	|❌| ✅ |❌ |
|Elliptic Curve ECC|	✅|✅| ✅|

As shown in the table above, elliptic curves can be used in three areas:

- Elliptic-curve-based public-key cryptography
- Elliptic-curve-based digital signatures
- Elliptic-curve-based key exchange

>The name elliptic curve (EC) can easily make people think of an “ellipse.” In reality, however, the graph of an elliptic curve is not an ellipse. It is called an elliptic curve for historical reasons: elliptic curves originate from the inverse functions of elliptic integrals used to compute the arc length of an ellipse.


Elliptic curves originate from the inverse functions of elliptic integrals used to compute the arc length of an ellipse. In general, an elliptic curve can be represented by the following equation, where a, b, c, and d are coefficients:
```c
E: y^2 = ax^3 + bx^2 + cx+ d
```
For example,

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_8.png'>
</p>

The figure above is an elliptic curve, but it does not look like an ellipse.

### 1. Operations on Elliptic Curves

Addition: Given two points A and B on an elliptic curve, draw the line through them. The intersection of that line with the elliptic curve, reflected across the X-axis, is defined as A+B. As shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_9.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_17.gif'>
</p>

Of course, the two points may also coincide. In that case, it is equivalent to finding the double of a point. At a point A on the elliptic curve, draw the tangent line. The other intersection of this tangent with the elliptic curve, reflected across the X-axis, is the doubled point. This operation is called point doubling, as shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_10_.png'>
</p>

The point symmetric to point A with respect to the X-axis is called -A. This operation is called negation on the elliptic curve. As shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_11.png'>
</p>


### 2. The Essence of Elliptic Curve Cryptography

The essence of elliptic curve cryptography is the elliptic curve discrete logarithm problem (Elliptic Curve Discrete Logarithm Problem, ECDLP), which is essentially **the problem of finding the number x given the point xG**.

>Given:  
>Elliptic curve E  
>A point G on elliptic curve E (the base point)  
>A point xG on elliptic curve E (x times G)  
>
>Find:    
>The number x  
>

Over the real numbers, an elliptic curve is continuous and smooth. Suppose the elliptic curve is E2: y^2 = x^3 + x + 1, as shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_12.png'>
</p>

If it is over the finite field F23, then E2: y^2 ≡ x^3 + x + 1 (mod 23). At this point, the elliptic curve is no longer a continuous curve, but a set of discrete points. As shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_13.png'>
</p>

For each point in the figure above, the y-coordinate modulo 23 is equal to x^3 + x + 1 modulo 23. If we take the point G=(0,1) on E2 as the base point, then we can compute 2G, 3G, 4G, 5G, and so on according to the arithmetic rules of elliptic curves.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_14.png'>
</p>

This is the “problem of finding x given G and xG”. When p is sufficiently large, this problem is very hard to solve. **The reason elliptic curves cannot be broken is that solving the discrete logarithm problem on elliptic curves is extremely difficult**.

However, elliptic curve cryptographic algorithms are not defined over the real field R, but over **a finite field F(P)**. A finite field F(P) refers to the addition, subtraction, multiplication, and division operations defined over the set of integers consisting of p elements 0, 1, 2, ..., p-1 for a given prime p.

>In addition to using the prime field GF(P), whose characteristic is a prime number p, elliptic curve cryptographic algorithms can also use the extension field GF(2^m), whose characteristic is 2^m.


### 3. Elliptic Curve Diffie-Hellman Key Exchange (ECDH)

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_18.png'>
</p>

>Diffie-Hellman was invented very early:  
>In 1976, Diffie and Hellman proposed asymmetric encryption  
>In 1977, Rivest, Shamir, and Adleman proposed the RSA public-key algorithm  
>In 1977, the DES algorithm appeared  
>In the 1980s, algorithms such as IDEA and CAST appeared
>In the 1990s, symmetric-key cryptography matured further, with the emergence of Rijndael and RC6, as well as other public-key algorithms such as elliptic curves  
>In 2000, the Rijndael algorithm became the AES standard


Non-elliptic-curve Diffie-Hellman key exchange relies on:

**The complexity of finding x given G and G^x mod p, modulo p (the discrete logarithm problem over a finite field)**

Elliptic-curve Diffie-Hellman key exchange relies on:

**The complexity of finding x given G and xG on an elliptic curve (the discrete logarithm problem on elliptic curves)**

The biggest difference between the DH algorithm and the RSA algorithm is:

- In the DH algorithm, during **key agreement**, neither party can independently compute the session key. Each party keeps part of the key information private and sends another part to the other party. Only after both parties have all the required information can they jointly compute the complete session key.
- In the RSA algorithm, when transmitting a session key, the session key is generated and controlled entirely by the client, with no participation from the server. Strictly speaking, this should be called **RSA key transport**.


Here is an example showing how the ECDH algorithm generates a shared key.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_15.png'>
</p>

- Alice sends point G to Bob. It does not matter if point G is eavesdropped on.
- Alice generates a random number a. This number is known **only to Alice herself**. There is no need to tell Bob, and it must not be disclosed to any third party. This a is called Alice’s private key.
- Bob generates a random number b. This number is known **only to Bob himself**. There is no need to tell Alice, and it must not be disclosed to any third party. This b is called Bob’s private key.
- Alice sends point aG to Bob. It does not matter if point aG is eavesdropped on. It is Alice’s public key.
- Bob sends point bG to Alice. It does not matter if point bG is eavesdropped on. It is Bob’s public key.
- After Alice receives bG from Bob, she computes the point that is a times it on the elliptic curve, namely a(bG) = abG. This is the shared key between Alice and Bob.
- After Bob receives point aG from Alice, he computes the point that is b times it on the elliptic curve, namely b(aG) = baG = abG. This is the shared key between Alice and Bob.

An eavesdropper can obtain three pieces of valid information in total: G, aG, and bG. However, because “finding x given G and xG is very hard”, knowing G and aG does not allow a to be solved, and knowing G and bG does not allow b to be solved. Therefore, the private key abG ultimately cannot be derived.

>Strictly speaking, the complexity of the discrete logarithm problem on elliptic curves only proves that “given G, aG, and bG, it is hard to find a and b”; it does not prove that “given G, aG, and bG, it is hard to find abG”. The latter requires a separate proof, which is omitted here.

Combining the static DH algorithm with ECC gives the ECDH algorithm. This approach uses the same base point G every time. Its advantage is that it avoids the server frequently generating G whenever a connection is initialized. That process consumes a relatively large amount of CPU. However, its drawback is that once the random numbers a and b are leaked, all previous sessions can be decrypted.

To solve this problem, the DHE algorithm (Diffie-Hellman Ephemeral, an ephemeral DH algorithm) was introduced. When combined with ECC, it forms the ECDHE algorithm. It ensures that the shared key used for each communication is different. The DH key pair is stored only in memory, unlike an RSA private key, which is stored on disk. Even if an attacker extracts the private key from memory, only the current communication is affected, so there is no need to worry that previous communications will be decrypted. This property is called Forward Secrecy (FS), or Perfect Forward Secrecy (PFS). Even more securely, after the session key is negotiated, the two private keys a and b can be discarded, further improving security by generating the key pair within a limited time and effective space. The ECDHE\_ECDSA and ECDHE\_RSA key exchange algorithms are used in the TLS handshake.


### 4. Elliptic Curve DSA (ECDSA)

Elliptic curve cryptography can also be used to implement digital signatures.

Suppose Alice wants to add a digital signature to message m, and Bob needs to verify that signature. All “computations” below refer to modular arithmetic modulo p.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_19.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_20.png'>
</p>

### 5. Elliptic Curve ElGamal Cryptosystem

Suppose Alice wants to send a message to Bob. Alice can represent the message she wants to send as a point M on the elliptic curve (in practice, by using the x-coordinate of that point).

Encryption:

- Alice uses her private key a and Bob’s public key bG to compute the point M + abG for message M. This point M + abG is the ciphertext.
- Alice sends the ciphertext M + abG to Bob.

Decryption:

- Bob receives the ciphertext M + abG.
- Bob uses Alice’s public key aG and his own private key b to compute the shared key abG. Subtracting abG from the received ciphertext yields the original plaintext M.

This still relies on the fact that an eavesdropper cannot compute abG, thereby ensuring the security of the ciphertext.


## 9. Other Public-Key Encryption Algorithms

The ElGamal scheme is a public-key algorithm designed by Taher ElGamal. RSA relies on the difficulty of integer factorization, while ElGamal relies on the difficulty of computing discrete logarithms modulo N.


One drawback of the ElGamal scheme is that the encrypted ciphertext becomes twice as long as the plaintext. The cryptographic software GnuPG supports this scheme.

The Rabin scheme is a public-key algorithm designed by M.O.Rabin. Rabin relies on the difficulty of computing square roots modulo N. The difficulty of breaking the Rabin public-key cryptosystem is comparable to the difficulty of factoring N in RSA.


## 10. Hybrid Cryptosystems

Using symmetric encryption can solve the problem of information security, but when using symmetric encryption, the problem of key distribution must be solved.

Using public-key cryptography can solve the key distribution problem, but public-key cryptography introduces two new problems.

- Public-key cryptography is much slower than symmetric cryptography
- Public-key cryptography has difficulty resisting man-in-the-middle attacks

The first drawback can be solved using the hybrid cryptosystem discussed in this section. The second drawback requires the authentication-related algorithms covered in the next article.

A hybrid cryptosystem is a method that combines the advantages of symmetric cryptography and public-key cryptography. It encrypts the plaintext with a fast symmetric cipher, and encrypts the symmetric cipher’s key with a public-key cipher. Because a symmetric key is generally much shorter than the message itself, the slowness of public-key cryptography can be ignored.

- Encrypt the plaintext message with a symmetric cipher
- Generate the session key used for symmetric encryption with a pseudorandom generator
- Encrypt the session key with a public-key cipher
- Provide the key used for public-key encryption from outside the hybrid cryptosystem

A session key is a temporary key generated for the current communication. It is generally produced by a pseudorandom number generator. The session key generated by the pseudorandom generator is also used as the key for the symmetric cipher. **The session key is the key for the symmetric cipher, and at the same time it is the plaintext for the public-key cipher**.
The following diagram shows the encryption process in a hybrid cryptosystem:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_22.png'>
</p>

It is worth noting that the strength of the public-key cipher should be higher than that of the symmetric cipher. This is because if a symmetric session key is cracked, it only affects the local communication content; but if the public key is cracked, it affects all past communication content as well as all future communication content.

The following diagram shows the decryption process in a hybrid cryptosystem:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_21.png'>
</p>


## 11. RSA in OpenSSL

Use the `genrsa` subcommand to generate a key pair. The key pair is stored in a single file.
```c
// Generate a 2048-bit key
$ openssl genrsa -out mykey.pem 2048
```
Output
```c
Generating RSA private key, 2048 bit long modulus (2 primes)
..................................................+++
...............................................................+++
e is 65537 (0x010001)


-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAvQuZaPWI47tMLufxTxlFUmVkvl3HCjo7WtxD7znK5TvbOtQN
N0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g8HcklgAM13k6ML47Vj1mEgl8M1Gh
ye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMxYI+J2Bp1wCq7dh1IHVkV1OQy2qo6
poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9iu+j1PliNG4I00+66JcVBlMCsYxX6
orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJgyofrFr/nYxp/ytfhwIsDTIfuGNES
9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWsPwIDAQABAoIBACe/zJ35IrNfqoEi
W+bZ1W2hzDEK3tMTs29DaTVf3X2dvFb+R1kbiIwNejZjtb8fNGmmVzGIsVR9A42H
0xkRlUl6g8LWd9zGrKmbFjbn6hJY1DimLXKccAgcUg/N0lowXXYH1nSVBKLjfKIM
+VtB0VwQUleSGLgzQ/9t4L/q/2AnztXe/LLyMxjsW1XNSlMREPjBoykygw6dk41/
Wou96UvUElJc9YiU+WwIL46yWfwf68C9qmlrkY32pj7q/q7FHLsgGeiSXpxRYSeo
bl99xHzBN/Kf3wHcw803JFSolZKb63VDt0p9P58Dg34M9NxqHKfnXW/+Ot4ryIaT
LNUe1IECgYEA3UiEUANv10WSmXQXuNOcCsTezwvNGrxERD6q7sGs4gEMDkjOy4eG
ENbT3OqISOpMjli9+m0XjG0Jdc6+WaAKbddAwwfHfq+e9qWHg88q1yHJFYLRMMgV
f5kV5sq2/b+eOLpPeOI4dRiU1J5dorab0SxpSMvLcu1krPpss3BoBDECgYEA2rRM
EH/gtT3uTGVfsF9WtFr+/AYExsLg8GK38HdwopVPhgNMhrIIvHSRBpGgPNZC7Q6z
pDreFZM5U0zCcLVpYdKSh0ag0uckOVwDoKcvOFEG+hE5N22LseiU2FXSDFPjk5wz
C5ZKZDh826n+28P7XN74HGDvF/usXEA8ibu5y28CgYAbidbNjl/wznu8FTKOkect
f+qqobFYzm1AgPwM0pWNWswBSxZRRgBtQA8FwzpKuL3mSSz7aXAwzbELtDsENGKX
4N3yZ5lwLrL9xwPiZ3nRZCb+QlV+WKg0RPzwx/GWCq7KKIWTabPU/sYm376PbWJe
2cQQhyw+lUSeMlwsyKRpQQKBgH1hyAndhjHh43Ag3g77WXXkhTJvMOXSa6rkrZdK
omRTPVgTJBhEkQWZvlsJudem7o+BUjPhG9k6oi7DXuXG2zedxSuQrjq7EOVhfyLn
NgcPTPSoUykXwHKqaEruSJGQtnO1pP4Ll3KFf+9fMiFD5iOEILIEUI5rVpE8sng0
C3w5AoGBAIRZ7BVKof069wdJRbCYWNcQ9wLpfbsDfJ1nB25aDlYsbiX+04dg30oY
63IQIuE1+uU+ucQhOn1ct8zQN8+neqRsfyAKfDr9pble8L2PeLdTlJiSnChXmctX
fR6ZxFL/ScnE2JiJ9EJeAvKVVRBWe4loSiz1LOjRXnNqTQK5VUdT
-----END RSA PRIVATE KEY-----
```
Encrypt Passwords with 3DES
```c
// Protect the key pair with a password and the 3DES algorithm
$ openssl genrsa -des3 -out mykey2.pem 2048
```
Output
```c
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,4F3848C3AF836C73

+TL2YDfcSZh3oCPUcUaKLHZBnnzSKSspZV5NwlDHbyokkigEeVaEn19nBEDdH5ph
Mv2afNfs5TNHe/uxun0OP99Z/QrWgkz75JRDQYjUEBilte0MHLS+W7bzJlYcYYhs
IK/8/x6X3A0T3lm13PV389RnuEJKl/x4JhhS7+AHUt/ceYxYAbW35dPVzBaVX8KL
1t67joBEasOxqFblDcVniOWLHhdn4aF+k4P4a3qs5ayzVNxB7+cQOK7ZFyRN7OOP
O/iu6Ha7kCqUi4NP8yJohfBoiLqmWAgl5nbyRs/ymjrI1Qu9Gne551cXY57SFJB1
YdtXanXcQodL9S9EZ9dSNrQLzDbQ2bpJNO7QdmxTxxUWn0Nw2SBeRcju+5HU//XV
FB90xc3abskjE/Dq8KCWY+TogEJmB8fLGBGnF3RDUkgOtQ93omGREcRgI3QSDt2O
KryYSwO/f0Rh+dbLs6OhenPgUEHFXteS0ETq5Q7lPAgH6xLGQdrdVHm2gkQ72IMt
JE4w68bC8x4qM7XSK9RublEjFWY7UKd93JWsaxbokozD7cYSi2SZO6eDiKZMUhOH
bV+7uSt6IT6KdvNTtO4hQFcttqjxApdwDf1GA8qRUmQ57PS6pbpGq07zGYtoGZ2o
Za1MUZtH/omi41smVPJWlB5YEQhVPclpw4BpGkVqYoI56QrmEuZWK8x8A8Fota0C
ZZvvbEFGO+wKlp3mmaKC0g3P0xXblKUVzpXhiEGEPxyxzMYu7vhS4gSEA8TvWyH3
YJBDDF2dSPYoJq0HQcnmeVKNG544ZSuJz/+Jfn6WcD6qx5zZ9NXsm6xaji5hHGoW
aJzWGZbk74WXpc+y/NFyJLhKpozr+Gsu8r40A+BCQXhkYUu58QAbtuWP48gfyn0+
fP0oLlBq3UGMga46JJgdMNbnNcbo5Qxzo0srHdwiYts4oBXEfED/NRQeecsKqrvk
qNxK9AR0MP3sKMshuBiS0nSgGovnAG5TwEzbwPgoiU09CWGWLQQOnRxZt4FNmVqz
kQg8t+U0JW8rKSH9FihRXpOeSDlVrk4L8It98v8KyczNWZjKxBszbO/AJeK8gPeY
hXZ6bU8/FljI+NMeA7gUgcNjXNSoNdHiJFMh5XbVN3AaUiUV9oOr5d/v1kWTYz+A
xaGw5rYKMe32Fs8ohMHnTydmO4iHGziKt5gchJwzAmY4k05tyyRF/VjJCb4bV0XA
VwGLUlhuNWzuvh2FGBXceEOf6eOzE1FDriTVQX2gFSBaE3olWtBvB7lzAEm+nyMJ
zL+aiSBDgBSKFkGRXe5i2Lq7/3600z4HWON3Ccc8gwuVVOsv927CDXdi33Ew+XqN
yKxG2PFHf2MoymRcp+YnyZqa2yGCQWXEOvzUgRRIlgH9BVbXxPKPigDwWqho5X+F
3ymDjsGp87x8RoE14GWImVpYjWx500fs/FweLoKzi+RRWvFFcc4izW7YvGY9yby7
zWKng2Wrqkc0NBExqkIxpcGsLay+1joa++lX/6V0/Rdq8DWrI2zalpw3LYsN1jCW
1iOD6CoOsAKsj3QpqFU4gh5RRXgPYQK1nq0ctonVsQ7Cv1929+TmMw==
-----END RSA PRIVATE KEY-----
```
Extract the public key from the key pair
```c
$ openssl rsa -in mykey.pem -pubout -out mypubkey.pem

// A passphrase is required to extract the public key
$ openssl rsa -in mykey2.pem -pubout -out mypubkey2.pem
```
Extract the public key without a passphrase
```c
writing RSA key

-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvQuZaPWI47tMLufxTxlF
UmVkvl3HCjo7WtxD7znK5TvbOtQNN0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g
8HcklgAM13k6ML47Vj1mEgl8M1Ghye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMx
YI+J2Bp1wCq7dh1IHVkV1OQy2qo6poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9i
u+j1PliNG4I00+66JcVBlMCsYxX6orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJg
yofrFr/nYxp/ytfhwIsDTIfuGNES9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWs
PwIDAQAB
-----END PUBLIC KEY-----
```
Extract the public key with a passphrase
```c
writing RSA key

-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn2AlBE0SzDjS4ITtV0KU
i7ZfpVaI7SaxhkVqgZNqTX8WsLQefXJipzcCR3aFNOyfRr/YtsUKKozD3qtQRckH
TkZdil80RB9im8IINIgUXWtOm1j6/ztptKtPoBlv556+cLY+zEJQWnSzB3N8g2py
26oewc6AeZiYtqpLEbuGBsBxGa8xNIp2/fnBKonA4stAI6b+3yCsDeEwgw3O7omt
AMTtYBJqd2Be9Np8CukXD4fBLdVRcRoTiIGxSp8GRJ+F5JBIr5THMAerVhNjdAeU
y15gc7B5OTJUfLmBXWo6gmq4hLcp4S5dCv7kapK7Zebyt1LkXAsrRCWGMVavy84y
fwIDAQAB
-----END PUBLIC KEY-----
```
Verify whether the password is correct for the file
```c
// The -noout parameter means not printing key pair information; if validation succeeds, the key pair file is valid
$ openssl rsa -in mykey.pem -check -noout
```
Output
```c
RSA key ok
```
Display public key information
```c
$ openssl rsa -pubin -in mypubkey.pem -text
```
Output
```c
RSA Public-Key: (2048 bit)
Modulus:
    00:bd:0b:99:68:f5:88:e3:bb:4c:2e:e7:f1:4f:19:
    45:52:65:64:be:5d:c7:0a:3a:3b:5a:dc:43:ef:39:
    ca:e5:3b:db:3a:d4:0d:37:44:2c:6e:17:73:2d:cf:
    a0:57:2f:1a:b1:81:3d:e5:fd:3a:ba:31:0b:b6:ca:
    e1:2d:7d:a0:f0:77:24:96:00:0c:d7:79:3a:30:be:
    3b:56:3d:66:12:09:7c:33:51:a1:c9:ef:d9:71:67:
    8e:15:8c:43:9f:72:5b:85:56:5b:a1:fc:c0:c2:8c:
    24:11:b7:3d:29:73:31:60:8f:89:d8:1a:75:c0:2a:
    bb:76:1d:48:1d:59:15:d4:e4:32:da:aa:3a:a6:84:
    74:a4:c8:d5:d6:a7:7e:03:3a:c1:17:25:6d:57:a0:
    ea:36:42:27:16:b3:cc:08:bf:62:bb:e8:f5:3e:58:
    8d:1b:82:34:d3:ee:ba:25:c5:41:94:c0:ac:63:15:
    fa:a2:b8:61:c0:35:7c:e4:d5:62:b4:0b:c4:5f:61:
    b0:45:dd:ef:eb:9f:fd:dd:9b:4e:39:32:60:ca:87:
    eb:16:bf:e7:63:1a:7f:ca:d7:e1:c0:8b:03:4c:87:
    ee:18:d1:12:f7:12:74:c7:81:0d:6c:42:fc:3c:e4:
    c7:ae:91:20:a5:ff:55:43:ff:66:75:5c:64:0a:d5:
    ac:3f
Exponent: 65537 (0x10001)
writing RSA key
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvQuZaPWI47tMLufxTxlF
UmVkvl3HCjo7WtxD7znK5TvbOtQNN0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g
8HcklgAM13k6ML47Vj1mEgl8M1Ghye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMx
YI+J2Bp1wCq7dh1IHVkV1OQy2qo6poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9i
u+j1PliNG4I00+66JcVBlMCsYxX6orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJg
yofrFr/nYxp/ytfhwIsDTIfuGNES9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWs
PwIDAQAB
-----END PUBLIC KEY-----
```
Modulus is N in the RSA encryption structure. Exponent is E in the public key. The content between -----BEGIN PUBLIC KEY----- and -----END PUBLIC KEY----- is the actual value of the public key.

Encrypt with a key pair
```c
// The rsautl command's default padding scheme is PKCS#1 v1.5
$ openssl rsautl -encrypt -inkey mykey.pem -in plain.txt -out cipher.txt

// Specify the rsautl padding scheme as PKCS#1 OAEP
$ openssl rsautl -encrypt -inkey mykey.pem -in plain.txt -out cipher.txt -oaep
```
Suppose the plaintext in the file we encrypt is "hello world". After encryption, the ciphertext becomes:
```c
�1Au�&.�rzC��7��6:
+��٠P�?��|��~İ���}'x�������X�IkBx��V2��~�/��$�N�(5m�s�#�m�0����s�ɜ+jėއ(!E�t��??�{���Y�W�a��tȈp���uUlzk�I9W����[���/�l!J��ө��-v�O_h����b~ ��Y
```
When using public-key encryption, be sure to include the `-pubin` option to indicate that the `-inkey` option is receiving a public key file.
```c
$ openssl rsautl -encrypt -pubin -inkey mypubkey.pem -in plain.txt -out cipher2.txt
```
Similarly, the plaintext to be encrypted is "hello world", and after encryption the ciphertext becomes:
```c
�
�P�C��)���>e{�}�QK���N2At�T�XSF�P�cFO2āFbj��G0�c���Kg�G+�Q�qߊ�'
       ~;�`DF{�ϭa&i����?�3l��!	�w��&q���Q���z�f��Κ�!�u�ʩ��j�U�Y
```
Decryption
```c
$ openssl rsautl -decrypt -inkey mykey.pem -in cipher.txt
```
Output
```c
hello world
```

## 12. ECC in OpenSSL

### 1. DH Key Agreement

Unlike RSA key pair generation, DH key pair generation is divided into two steps: first generate a parameter file, then generate the key pair from that parameter file. **The same parameter file can be used to generate an unlimited number of unique key pairs**.

Step 1: generate the DH key pair
```c
// Generate a 2048-bit parameter file
$ openssl dhparam -out dhparam.pem -2 2048

$ openssl dhparam -in dhparam.pem -noout -C
```
Output
```c
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
......................+..........................................................................+..............................................................................................................................................................................................+.......................................................+

#ifndef HEADER_DH_H

# include <openssl/dh.h>

#endif

DH *get_dh2048()
{
    static unsigned char dhp_2048[] = {
	0xBD, 0x70, 0xDB, 0x2E, 0xF9, 0x0B, 0x89, 0x37, 0xC4, 0x31,
	0x93, 0x48, 0x47, 0xEF, 0xD5, 0xEA, 0x7E, 0xBC, 0xDA, 0xC8,
	0x14, 0x0E, 0x82, 0xDD, 0xF6, 0xC6, 0x07, 0x2A, 0xD4, 0x97,
	0xC3, 0x02, 0xA1, 0x9B, 0x02, 0xCB, 0xE4, 0xC0, 0xB9, 0x33,
	0xD1, 0xBB, 0x69, 0xF0, 0xBA, 0x8C, 0x7A, 0x57, 0x1F, 0xDF,
	0xD3, 0xB5, 0x2F, 0x87, 0x1E, 0xA8, 0x35, 0xE4, 0xC0, 0x94,
	0xED, 0x20, 0x04, 0x26, 0x58, 0x50, 0x27, 0xFC, 0xF6, 0xE1,
	0xBE, 0xC7, 0xB8, 0x7A, 0x14, 0xC1, 0x08, 0x16, 0x06, 0xC6,
	0xB8, 0x09, 0xDC, 0x34, 0xEA, 0xA0, 0xD1, 0x3E, 0x88, 0xBD,
	0xB3, 0xBB, 0x05, 0xFE, 0x4D, 0xCB, 0x62, 0x05, 0x9A, 0xC7,
	0x00, 0xA2, 0x0B, 0x73, 0xAD, 0xDD, 0x39, 0x18, 0x9A, 0xD8,
	0x2A, 0x95, 0xCE, 0xF4, 0x10, 0x6A, 0xB2, 0x5C, 0x0F, 0x9E,
	0x99, 0xE5, 0xE6, 0x0D, 0x6C, 0x19, 0xF5, 0xF5, 0xDC, 0x07,
	0x2D, 0xF0, 0xDE, 0xB5, 0x58, 0xEC, 0x35, 0x33, 0xEF, 0x65,
	0x70, 0xC3, 0x8C, 0xBF, 0x14, 0x40, 0x4C, 0xC3, 0x47, 0x77,
	0xE0, 0x5F, 0xF6, 0x61, 0x5F, 0x49, 0x35, 0xCC, 0x39, 0x75,
	0x8E, 0x31, 0xA3, 0x99, 0x43, 0x61, 0xD7, 0xE3, 0xB7, 0xB8,
	0x0F, 0x79, 0xF3, 0x66, 0x50, 0x95, 0x0D, 0x95, 0xB2, 0x5F,
	0x1B, 0x2C, 0x9D, 0x64, 0xE0, 0x54, 0xCB, 0x27, 0xE9, 0x4A,
	0x23, 0x96, 0xA0, 0x7E, 0x55, 0xD4, 0xA9, 0x93, 0x43, 0xB0,
	0x69, 0xB2, 0xF5, 0xB4, 0x9D, 0x41, 0x5B, 0xD3, 0x5D, 0x4B,
	0x91, 0x48, 0x9F, 0xAA, 0x54, 0xA4, 0xA1, 0x81, 0xF1, 0x59,
	0xF6, 0xB3, 0x44, 0x8C, 0xE7, 0x83, 0x8F, 0x57, 0x63, 0x52,
	0x58, 0x70, 0x2F, 0x0A, 0xC1, 0xC0, 0xE5, 0xDD, 0x6F, 0x4D,
	0xFD, 0xC1, 0x5D, 0x61, 0x6E, 0xD0, 0xA4, 0xBD, 0x15, 0xA1,
	0xA6, 0xDE, 0x61, 0xC9, 0xF4, 0x4B
    };
    static unsigned char dhg_2048[] = {
	0x02
    };
    DH *dh = DH_new();
    BIGNUM *dhp_bn, *dhg_bn;

    if (dh == NULL)
        return NULL;
    dhp_bn = BN_bin2bn(dhp_2048, sizeof(dhp_2048), NULL);
    dhg_bn = BN_bin2bn(dhg_2048, sizeof(dhg_2048), NULL);
    if (dhp_bn == NULL || dhg_bn == NULL
            || !DH_set0_pqg(dh, dhp_bn, NULL, dhg_bn)) {
        DH_free(dh);
        BN_free(dhp_bn);
        BN_free(dhg_bn);
        return NULL;
    }
    return dh;
}
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAvXDbLvkLiTfEMZNIR+/V6n682sgUDoLd9sYHKtSXwwKhmwLL5MC5
M9G7afC6jHpXH9/TtS+HHqg15MCU7SAEJlhQJ/z24b7HuHoUwQgWBsa4Cdw06qDR
Poi9s7sF/k3LYgWaxwCiC3Ot3TkYmtgqlc70EGqyXA+emeXmDWwZ9fXcBy3w3rVY
7DUz72Vww4y/FEBMw0d34F/2YV9JNcw5dY4xo5lDYdfjt7gPefNmUJUNlbJfGyyd
ZOBUyyfpSiOWoH5V1KmTQ7BpsvW0nUFb011LkUifqlSkoYHxWfazRIzng49XY1JY
cC8KwcDl3W9N/cFdYW7QpL0VoabeYcn0SwIBAg==
-----END DH PARAMETERS-----
```
Step 2: Generate a key pair based on the parameter file
```c
$ openssl genpkey -paramfile dhparam.pem -out dhkey.pem

// View key pair file contents
$ openssl pkey -in dhkey.pem -text -noout
```
Output
```c
DH Private-Key: (2048 bit)
    private-key:
        53:7c:d5:88:80:13:49:b0:c0:00:79:62:fd:4b:8d:
        54:c6:b2:f3:49:45:fa:3c:f7:d8:49:cf:b2:b2:cd:
        b6:45:be:b8:de:54:9b:07:7e:dc:e5:f1:92:0c:7c:
        7d:b9:6e:aa:db:3e:a0:b0:e1:e8:aa:b6:6e:71:c8:
        59:30:b7:75:cb:79:c8:44:25:18:36:2f:22:c2:6b:
        fb:19:f6:31:7e:c8:6d:df:5f:46:cf:b9:df:41:53:
        1c:5e:42:9f:46:77:29:c0:09:a0:a2:4d:e8:f7:44:
        43:1a:f8:43:18:d1:2d:7f:56:75:dc:62:4f:84:93:
        26:c6:fc:ca:a6:5f:50:73:d8:bc:ee:2b:1c:65:22:
        4c:ab:0b:a3:a0:ce:d3:cd:1d:d9:21:3f:b3:32:f0:
        74:fd:3d:98:1d:43:3b:a4:ed:e0:d2:7e:eb:27:64:
        c7:64:54:e7:12:19:5d:f8:f0:a5:fc:15:50:ee:20:
        8f:81:84:b5:e6:ba:64:9a:e0:36:bc:61:09:b3:b3:
        ea:24:63:92:66:13:50:2d:5b:f5:db:2f:15:3d:6b:
        e3:63:99:61:70:8e:b1:12:a1:c1:bb:c0:fa:57:90:
        ae:47:7a:78:35:ce:dc:47:2a:63:b4:30:4a:9d:49:
        4f:2b:ac:a0:8e:47:44:dc:a5:29:68:cd:c6:e0:74:
        50
    public-key:
        00:81:0a:3e:3b:29:8a:e9:1e:26:47:e0:cc:a0:40:
        e9:2d:03:c4:55:64:b0:73:2c:6e:39:6f:5a:95:de:
        a3:44:6a:d1:20:f4:69:68:3c:58:8f:f5:86:94:39:
        13:bf:c7:66:1f:af:7b:1e:0e:15:cd:0e:f9:65:d4:
        d4:70:37:63:50:f7:7b:93:6c:bf:e2:9a:de:fa:41:
        13:20:8b:23:0c:f7:b3:94:00:19:6d:65:f2:30:6a:
        50:88:8f:5e:7e:40:79:fa:14:0f:73:3b:51:ed:24:
        06:5d:29:f9:6e:34:7a:21:6e:b0:cf:6a:7e:c3:26:
        31:3f:f5:42:47:f6:2f:45:c4:89:67:90:b4:69:0e:
        73:92:57:90:32:63:be:77:9f:f1:a8:c5:e3:cd:4d:
        b8:2f:13:4f:88:78:9a:09:1b:04:fa:ab:6d:0c:a7:
        b8:b4:6e:76:05:42:d2:50:b7:a3:6b:0c:94:53:9f:
        fa:eb:9e:20:df:e7:91:a3:08:fa:a8:be:85:6d:75:
        41:89:e9:ae:1d:e4:e1:65:bc:17:f3:b3:a2:ab:45:
        31:eb:9e:21:dc:45:66:0d:8b:2c:70:ea:c2:1d:ac:
        27:9d:0d:d4:06:9c:b0:3d:0b:34:9e:05:2d:9c:55:
        28:f4:63:7f:61:96:da:e7:09:0b:40:b4:d6:0a:5c:
        aa:df
    prime:
        00:bd:70:db:2e:f9:0b:89:37:c4:31:93:48:47:ef:
        d5:ea:7e:bc:da:c8:14:0e:82:dd:f6:c6:07:2a:d4:
        97:c3:02:a1:9b:02:cb:e4:c0:b9:33:d1:bb:69:f0:
        ba:8c:7a:57:1f:df:d3:b5:2f:87:1e:a8:35:e4:c0:
        94:ed:20:04:26:58:50:27:fc:f6:e1:be:c7:b8:7a:
        14:c1:08:16:06:c6:b8:09:dc:34:ea:a0:d1:3e:88:
        bd:b3:bb:05:fe:4d:cb:62:05:9a:c7:00:a2:0b:73:
        ad:dd:39:18:9a:d8:2a:95:ce:f4:10:6a:b2:5c:0f:
        9e:99:e5:e6:0d:6c:19:f5:f5:dc:07:2d:f0:de:b5:
        58:ec:35:33:ef:65:70:c3:8c:bf:14:40:4c:c3:47:
        77:e0:5f:f6:61:5f:49:35:cc:39:75:8e:31:a3:99:
        43:61:d7:e3:b7:b8:0f:79:f3:66:50:95:0d:95:b2:
        5f:1b:2c:9d:64:e0:54:cb:27:e9:4a:23:96:a0:7e:
        55:d4:a9:93:43:b0:69:b2:f5:b4:9d:41:5b:d3:5d:
        4b:91:48:9f:aa:54:a4:a1:81:f1:59:f6:b3:44:8c:
        e7:83:8f:57:63:52:58:70:2f:0a:c1:c0:e5:dd:6f:
        4d:fd:c1:5d:61:6e:d0:a4:bd:15:a1:a6:de:61:c9:
        f4:4b
    generator: 2 (0x2)
```
`prime` is a large prime number, and `generator` is a generator.

Next, here is a complete example of DH key agreement.
```c
// One communicating party generates a DH parameter file, which can be public
$ openssl genpkey -genparam -algorithm DH -out dhp.pem

// View the parameter file contents, including the p and g parameters
$ openssl pkeyparam -in dhp.pem -text
```
Output
```c
-----BEGIN DH PARAMETERS-----
MIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DMr1r1xNk9d/qTGczGi52olR96
XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0uI2WviyPKG4eHqu7gID/6+pil
RBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q9+tGiZKhowZDAgEC
-----END DH PARAMETERS-----
DH Parameters: (1024 bit)
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```
Sender Alice generates a key pair using the parameter file.
```c
$ openssl genpkey -paramfile dhp.pem -out akey.pem

// View key pair contents
$ openssl pkey -in akey.pem -text -noout
```
Output
```c
DH Private-Key: (1024 bit)
    private-key:
        79:1f:07:19:83:8d:34:db:4a:ea:d6:7b:16:4f:7e:
        11:cd:39:78:75:ea:4f:c3:f7:09:48:91:3c:96:cf:
        6b:8d:85:56:48:9e:1a:83:fb:13:0a:28:c5:f6:eb:
        74:13:ff:a4:2e:ae:29:df:b5:92:2a:af:25:11:cf:
        02:b6:09:d5:c8:a1:71:78:86:dd:26:6a:d1:55:52:
        33:ce:65:57:22:3f:f4:df:a6:df:80:c2:cc:c6:98:
        de:67:09:05:e2:68:09:d1:43:7f:42:03:37:99:88:
        cc:5f:78:e6:22:b0:fa:5c:c9:5f:0f:2d:de:b6:33:
        42:05:f4:45:58:b8:fb:93
    public-key:
        4d:90:d3:5f:df:13:fb:17:32:55:6c:3b:17:67:cb:
        51:8f:42:1c:88:10:ef:7b:90:69:2c:e6:97:92:10:
        92:4f:16:8d:d5:9b:4f:d5:97:fa:71:3b:28:12:99:
        1f:86:0d:ee:b2:ca:7e:4f:96:ae:46:73:1d:14:b5:
        0e:1a:0c:e6:41:fa:97:d4:0c:50:a2:17:5d:a9:e8:
        7e:c0:33:fd:dc:59:ca:13:90:f7:1b:79:ee:88:5e:
        39:70:4f:c0:a8:a7:0b:0e:6e:e8:27:29:43:1b:af:
        56:72:0a:aa:a1:06:1d:0d:78:f8:6d:1a:1e:bd:b5:
        3b:20:55:76:bc:9c:1a:d3
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```
The recipient, Bob, also generates a key pair based on the parameter file.
```c
$ openssl genpkey -paramfile dhp.pem -out bkey.pem

// View key pair contents
$ openssl pkey -in bkey.pem -text -noout
```
Output
```c
PKCS#3 DH Private-Key: (1024 bit)
    private-key:
        7b:00:1e:c9:12:62:3a:82:69:58:03:5c:f5:23:ef:
        c2:20:10:27:f5:a7:e3:c9:14:57:76:ea:94:4c:68:
        e5:17:c2:38:36:e1:82:9d:fb:d2:97:04:44:4a:0c:
        9f:81:d3:4a:33:c8:8f:64:50:79:6c:cd:a6:3a:26:
        d0:2b:55:7d:78:b0:e7:1e:12:d8:a3:89:da:61:53:
        1e:d0:9a:9f:f6:c0:ce:7d:c9:25:50:01:cf:c2:cb:
        0d:e2:74:78:3c:58:28:71:38:f0:d3:d2:91:f4:28:
        ec:da:f2:f9:75:e6:c4:13:8c:97:2a:f9:a3:fd:c0:
        0e:cb:d0:17:7d:62:01:c4
    public-key:
        00:8c:ad:e1:2f:42:85:4f:f8:07:7e:15:d0:f9:c5:
        84:b4:a3:be:9d:b2:fb:57:86:b8:c7:0c:d3:d5:92:
        c1:7b:db:e6:e6:b2:7e:ff:db:95:d9:8b:10:1a:10:
        4d:59:ac:b2:00:43:6f:23:f6:aa:13:b6:e4:f4:04:
        92:f1:23:88:13:21:c9:f7:d2:f3:dc:0e:a6:75:20:
        ed:4c:61:29:55:a2:36:55:d3:04:9f:7d:c3:96:7d:
        be:62:44:83:bf:9e:b3:f8:e7:ac:88:c5:3e:9b:b7:
        01:52:63:1a:30:5f:5d:90:46:5b:06:06:f3:b4:f8:
        c4:4b:16:45:43:da:d5:6d:1e
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```
Alice extracts the public key file akey\_pub.pem and keeps the private key herself.
```c
$ openssl pkey -in akey.pem -pubout -out akey_pub.pem
```
Output
```c
-----BEGIN PUBLIC KEY-----
MIIBHzCBlQYJKoZIhvcNAQMBMIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DM
r1r1xNk9d/qTGczGi52olR96XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0u
I2WviyPKG4eHqu7gID/6+pilRBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q
9+tGiZKhowZDAgECA4GEAAKBgE2Q01/fE/sXMlVsOxdny1GPQhyIEO97kGks5peS
EJJPFo3Vm0/Vl/pxOygSmR+GDe6yyn5Plq5Gcx0UtQ4aDOZB+pfUDFCiF12p6H7A
M/3cWcoTkPcbee6IXjlwT8CopwsObugnKUMbr1ZyCqqhBh0NePhtGh69tTsgVXa8
nBrT
-----END PUBLIC KEY-----
```
Bob extracts the public key file bkey\_pub.pem and keeps the private key to himself.
```c
$ openssl pkey -in bkey.pem -pubout -out bkey_pub.pem
```
Output
```c
-----BEGIN PUBLIC KEY-----
MIIBIDCBlQYJKoZIhvcNAQMBMIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DM
r1r1xNk9d/qTGczGi52olR96XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0u
I2WviyPKG4eHqu7gID/6+pilRBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q
9+tGiZKhowZDAgECA4GFAAKBgQCMreEvQoVP+Ad+FdD5xYS0o76dsvtXhrjHDNPV
ksF72+bmsn7/25XZixAaEE1ZrLIAQ28j9qoTtuT0BJLxI4gTIcn30vPcDqZ1IO1M
YSlVojZV0wSffcOWfb5iRIO/nrP456yIxT6btwFSYxowX12QRlsGBvO0+MRLFkVD
2tVtHg==
-----END PUBLIC KEY-----
```
Alice receives Bob's public key and saves the negotiated key to data\_a.txt.
```c
$ openssl pkeyutl -derive -inkey akey.pem -peerkey bkey_pub.pem -out data_a.txt
```
Output
```c

b;[nQ?�!zX^m��4���Է�M<{|1X?�M3�NT�Łm�Ϧ\��X+<����(L�(�F��l5Yl��N���/o���v�#7���J`>�?R�,���!>G������
                                                                                                   ��>B�����$�-��Y
                                                                                                   
```
Corresponding binary
```c   
$ od -d data_a.txt
                                                                                          0000000     25098   23355   20846   16134    8602   32634   24152   59757
0000020     59416   57652   52209   47060   19942   31548   12668   16216
0000040     19901   56883   21582   50641   28033   53186   23718   55494
0000060     11096   35644   61385   10435   33612   54568   51014   27841
0000100     22837   44908    5587   49486   61576   12198   57967   64511
0000120     60534   56867   14088   38019   19100   15968   16283   57938
0000140     60972   57071   15905     583   49404   47506   61861   47628
0000160      5292   16958   38029   62234   57799   39460   43821   38391
0000200
```
Bob receives Alice’s public key and saves the negotiated key to data\_b.txt.
```c
$ openssl pkeyutl -derive -inkey bkey.pem -peerkey akey_pub.pem -out data_b.txt
```
Output
```c

b;[nQ?�!zX^m��4���Է�M<{|1X?�M3�NT�Łm�Ϧ\��X+<����(L�(�F��l5Yl��N���/o���v�#7���J`>�?R�,���!>G������
                                                                                                   ��>B�����$�-��Y
```
Corresponding binary
```c
$ od -d data_b.txt

0000000     25098   23355   20846   16134    8602   32634   24152   59757
0000020     59416   57652   52209   47060   19942   31548   12668   16216
0000040     19901   56883   21582   50641   28033   53186   23718   55494
0000060     11096   35644   61385   10435   33612   54568   51014   27841
0000100     22837   44908    5587   49486   61576   12198   57967   64511
0000120     60534   56867   14088   38019   19100   15968   16283   57938
0000140     60972   57071   15905     583   49404   47506   61861   47628
0000160      5292   16958   38029   62234   57799   39460   43821   38391
0000200
```
We can see that the keys ultimately negotiated by the two parties are exactly the same.

### 2. ECC Encryption

OpenSSL supports many named curves. Let’s first take a look at which curves are supported.
```c
$ openssl ecparam -list_curves
```
Output
```c
  secp112r1 : SECG/WTLS curve over a 112 bit prime field
  secp112r2 : SECG curve over a 112 bit prime field
  secp128r1 : SECG curve over a 128 bit prime field
  secp128r2 : SECG curve over a 128 bit prime field
  secp160k1 : SECG curve over a 160 bit prime field
  secp160r1 : SECG curve over a 160 bit prime field
  secp160r2 : SECG/WTLS curve over a 160 bit prime field
  secp192k1 : SECG curve over a 192 bit prime field
  secp224k1 : SECG curve over a 224 bit prime field
  secp224r1 : NIST/SECG curve over a 224 bit prime field
  secp256k1 : SECG curve over a 256 bit prime field
  secp384r1 : NIST/SECG curve over a 384 bit prime field
  secp521r1 : NIST/SECG curve over a 521 bit prime field
  prime192v1: NIST/X9.62/SECG curve over a 192 bit prime field
  prime192v2: X9.62 curve over a 192 bit prime field
  prime192v3: X9.62 curve over a 192 bit prime field
  prime239v1: X9.62 curve over a 239 bit prime field
  prime239v2: X9.62 curve over a 239 bit prime field
  prime239v3: X9.62 curve over a 239 bit prime field
  prime256v1: X9.62/SECG curve over a 256 bit prime field
  sect113r1 : SECG curve over a 113 bit binary field
  sect113r2 : SECG curve over a 113 bit binary field
  sect131r1 : SECG/WTLS curve over a 131 bit binary field
  sect131r2 : SECG curve over a 131 bit binary field
  sect163k1 : NIST/SECG/WTLS curve over a 163 bit binary field
  sect163r1 : SECG curve over a 163 bit binary field
  sect163r2 : NIST/SECG curve over a 163 bit binary field
  sect193r1 : SECG curve over a 193 bit binary field
  sect193r2 : SECG curve over a 193 bit binary field
  sect233k1 : NIST/SECG/WTLS curve over a 233 bit binary field
  sect233r1 : NIST/SECG/WTLS curve over a 233 bit binary field
  sect239k1 : SECG curve over a 239 bit binary field
  sect283k1 : NIST/SECG curve over a 283 bit binary field
  sect283r1 : NIST/SECG curve over a 283 bit binary field
  sect409k1 : NIST/SECG curve over a 409 bit binary field
  sect409r1 : NIST/SECG curve over a 409 bit binary field
  sect571k1 : NIST/SECG curve over a 571 bit binary field
  sect571r1 : NIST/SECG curve over a 571 bit binary field
  c2pnb163v1: X9.62 curve over a 163 bit binary field
  c2pnb163v2: X9.62 curve over a 163 bit binary field
  c2pnb163v3: X9.62 curve over a 163 bit binary field
  c2pnb176v1: X9.62 curve over a 176 bit binary field
  c2tnb191v1: X9.62 curve over a 191 bit binary field
  c2tnb191v2: X9.62 curve over a 191 bit binary field
  c2tnb191v3: X9.62 curve over a 191 bit binary field
  c2pnb208w1: X9.62 curve over a 208 bit binary field
  c2tnb239v1: X9.62 curve over a 239 bit binary field
  c2tnb239v2: X9.62 curve over a 239 bit binary field
  c2tnb239v3: X9.62 curve over a 239 bit binary field
  c2pnb272w1: X9.62 curve over a 272 bit binary field
  c2pnb304w1: X9.62 curve over a 304 bit binary field
  c2tnb359v1: X9.62 curve over a 359 bit binary field
  c2pnb368w1: X9.62 curve over a 368 bit binary field
  c2tnb431r1: X9.62 curve over a 431 bit binary field
  wap-wsg-idm-ecid-wtls1: WTLS curve over a 113 bit binary field
  wap-wsg-idm-ecid-wtls3: NIST/SECG/WTLS curve over a 163 bit binary field
  wap-wsg-idm-ecid-wtls4: SECG curve over a 113 bit binary field
  wap-wsg-idm-ecid-wtls5: X9.62 curve over a 163 bit binary field
  wap-wsg-idm-ecid-wtls6: SECG/WTLS curve over a 112 bit prime field
  wap-wsg-idm-ecid-wtls7: SECG/WTLS curve over a 160 bit prime field
  wap-wsg-idm-ecid-wtls8: WTLS curve over a 112 bit prime field
  wap-wsg-idm-ecid-wtls9: WTLS curve over a 160 bit prime field
  wap-wsg-idm-ecid-wtls10: NIST/SECG/WTLS curve over a 233 bit binary field
  wap-wsg-idm-ecid-wtls11: NIST/SECG/WTLS curve over a 233 bit binary field
  wap-wsg-idm-ecid-wtls12: WTLS curve over a 224 bit prime field
  Oakley-EC2N-3:
	IPSec/IKE/Oakley curve #3 over a 155 bit binary field.
	Not suitable for ECDSA.
	Questionable extension field!
  Oakley-EC2N-4:
	IPSec/IKE/Oakley curve #4 over a 185 bit binary field.
	Not suitable for ECDSA.
	Questionable extension field!
  brainpoolP160r1: RFC 5639 curve over a 160 bit prime field
  brainpoolP160t1: RFC 5639 curve over a 160 bit prime field
  brainpoolP192r1: RFC 5639 curve over a 192 bit prime field
  brainpoolP192t1: RFC 5639 curve over a 192 bit prime field
  brainpoolP224r1: RFC 5639 curve over a 224 bit prime field
  brainpoolP224t1: RFC 5639 curve over a 224 bit prime field
  brainpoolP256r1: RFC 5639 curve over a 256 bit prime field
  brainpoolP256t1: RFC 5639 curve over a 256 bit prime field
  brainpoolP320r1: RFC 5639 curve over a 320 bit prime field
  brainpoolP320t1: RFC 5639 curve over a 320 bit prime field
  brainpoolP384r1: RFC 5639 curve over a 384 bit prime field
  brainpoolP384t1: RFC 5639 curve over a 384 bit prime field
  brainpoolP512r1: RFC 5639 curve over a 512 bit prime field
  brainpoolP512t1: RFC 5639 curve over a 512 bit prime field
  SM2       : SM2 curve over a 256 bit prime field
```
Generate a parameter file, using -name to specify the named curve
```c
$ openssl ecparam -name secp256k1 -out secp256k1.pem

// View the parameter file; the following command prints only the curve name by default
$ openssl ecparam -in secp256k1.pem -text -noout
```
Output
```c
ASN1 OID: secp256k1

-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----
```
Display the specific parameters in the parameter file
```c
// Show specific parameters in the parameter file
$ openssl ecparam -in secp256k1.pem -text -param_enc explicit -noout
```
Output
```c
Field Type: prime-field
Prime:
    00:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:
    ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:fe:ff:
    ff:fc:2f
A:    0
B:    7 (0x7)
Generator (uncompressed):
    04:79:be:66:7e:f9:dc:bb:ac:55:a0:62:95:ce:87:
    0b:07:02:9b:fc:db:2d:ce:28:d9:59:f2:81:5b:16:
    f8:17:98:48:3a:da:77:26:a3:c4:65:5d:a4:fb:fc:
    0e:11:08:a8:fd:17:b4:48:a6:85:54:19:9c:47:d0:
    8f:fb:10:d4:b8
Order:
    00:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:
    ff:fe:ba:ae:dc:e6:af:48:a0:3b:bf:d2:5e:8c:d0:
    36:41:41
Cofactor:  1 (0x1)
```
Parameter explanations:

- A and B are the parameters of the elliptic curve equation.
- P is a large prime that constrains all ECC points to a finite field. Almost all ECC operations are performed modulo P.
- Generator is the base point G, represented by the pair (gx,gy).
- Order corresponds to n for the base point; that is, the number of times the base point can be added to itself. Most ECC operations do not need this value, except that ECDSA computes signatures modulo Order rather than modulo P.
- Cofactor is equal to the total number of points on the elliptic curve divided by n.

>In ECC, k is the private key, g is the base point, and kg is computed according to the curve operations to obtain the public key. It is very difficult to compute the private key k from the public key; the underlying mathematical basis is the discrete logarithm problem.

Next, let’s walk through a complete example of ECDH key agreement.
```c
// Generate parameter file
$ openssl ecparam -name secp256k1 -out secp256k1.pem
```
Output
```c
-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----
```
Alice generates an EDCH private key pair file
```c
$ openssl genpkey -paramfile secp256k1.pem -out akey.pem
```
Output
```c
-----BEGIN PRIVATE KEY-----
MIGEAgEAMBAGByqGSM49AgEGBSuBBAAKBG0wawIBAQQgXVTzOp6aEkAeC2ICiPTi
bmAZkr1RYtzprh3Larg4n/yhRANCAATbDBxnW/pTc6fS1Rk/bJEZZLp0fBGfn+H8
hYJILjrQu7ZORRlQqe+o2le1+OV2t/l3bEGOYAI8nvHOhT6weN/e
-----END PRIVATE KEY-----
```
Bob generates the EDCH private key pair file
```c
$ openssl genpkey -paramfile secp256k1.pem -out bkey.pem
```
Output
```c
-----BEGIN PRIVATE KEY-----
MIGEAgEAMBAGByqGSM49AgEGBSuBBAAKBG0wawIBAQQgjhUWgm7C3tcXTUcqX9RG
aHCJQ5BqF0OzCBYntGnhJwahRANCAARPI4E54N3VfbHTfcvoUXNGJrIcMHAEhj6t
TkKrpEYMCbPkM0g57C2DWcOIqvb9ImD8OYQ+N27LlVNhYt6ncD/v
-----END PRIVATE KEY-----
```
Alice extracts the public key and sends it to Bob.
```c
$ openssl pkey -in akey.pem -pubout -out akey_pub.pem
```
Output
```c
-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE2wwcZ1v6U3On0tUZP2yRGWS6dHwRn5/h
/IWCSC460Lu2TkUZUKnvqNpXtfjldrf5d2xBjmACPJ7xzoU+sHjf3g==
-----END PUBLIC KEY-----
```
Bob extracts the public key and sends it to Alice.
```c
$ openssl pkey -in bkey.pem -pubout -out bkey_pub.pem
```
Output
```c
-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAETyOBOeDd1X2x033L6FFzRiayHDBwBIY+
rU5Cq6RGDAmz5DNIOewtg1nDiKr2/SJg/DmEPjduy5VTYWLep3A/7w==
-----END PUBLIC KEY-----
```
Alice receives Bob's public key and saves the negotiated key to data\_a.txt.
```c
$ openssl pkeyutl -derive -inkey akey.pem -peerkey bkey_pub.pem -out data_a.txt
```
Output
```c
��tR�"��g����_������]�Vn�Uɺ
```
Corresponding binary
```c
$ od -d data_a.txt

0000000     38303   21108    8888   49924   26595   54407   63697   57439
0000020     61643   63942   37357   63837   28246    3817    5973   47817
0000040
```
Bob receives Alice's public key and saves the negotiated key to data\_b.txt.
```c
$ openssl pkeyutl -derive -inkey bkey.pem -peerkey akey_pub.pem -out data_b.txt
```
Output
```c
��tR�"��g����_������]�Vn�Uɺ
```
Corresponding binary
```c
$ od -d data_a.txt

0000000     38303   21108    8888   49924   26595   54407   63697   57439
0000020     61643   63942   37357   63837   28246    3817    5973   47817
0000040
```
It can be seen that the keys ultimately negotiated by the two parties are exactly the same


------------------------------------------------------

References:
  
*Cryptography Technology Illustrated*     
[Principles of the RSA Algorithm (Part 1)](http://www.ruanyifeng.com/blog/2013/06/rsa_algorithm_part_one.html)    
[Principles of the RSA Algorithm (Part 2)](http://www.ruanyifeng.com/blog/2013/07/rsa_algorithm_part_two.html)         


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/asymmetric\_encryption/](https://halfrost.com/asymmetric_encryption/)