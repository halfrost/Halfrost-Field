# The Essence of Secrets—Keys


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_0.png'>
</p>


## 1. Why Do We Need Keys?

>The point of cryptography is to reduce long secrets—the message—to short secrets—the keys.  
>									—————Bruce Schneier, *Secrets and Lies: Digital Security in a Networked World*


In the previous articles, we learned that cryptographic techniques such as symmetric cryptography, public-key cryptography, message authentication codes, digital signatures, and public-key certificates all require keys. Keys protect the confidentiality of information. The most important property of a key is the **size of its key space**. The length of a key determines the size of the key space. The larger the key space, the harder it is to brute-force.


## 2. What Is a Key?

A key is merely a sequence of bits, but its value is equivalent to that of the plaintext. Keys can mainly be classified into the following categories:

### 1. Keys for Symmetric Cryptography and Keys for Public-Key Cryptography

In symmetric encryption, the same key is used for both encryption and decryption. This is also known as shared-key cryptography.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_1.png'>
</p>

In public-key cryptography, different keys are used for encryption and decryption. The key used for encryption and allowed to be made public is called the public key. The key used for decryption and not allowed to be made public is called the private key.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_2.png'>
</p>

### 2. Keys for Message Authentication Codes and Keys for Digital Signatures

In a message authentication code, the sender and receiver use a shared key for authentication. A message authentication code can only be computed by someone who holds the legitimate key. By comparing message authentication codes, it is possible to identify whether a message has been tampered with or spoofed.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_3.png'>
</p>


In a digital signature, different keys are used to generate and verify the signature. Only the person who holds the private key can generate the signature, but because the public key is used to verify the signature, anyone can verify it.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_4.png'>
</p>


### 3. Keys for Confidentiality and Keys for Authentication

- Symmetric keys and keys in public-key cryptography are **keys used to ensure confidentiality**. If the legitimate key used for decryption is unknown, the plaintext can be kept confidential.

- The keys used by message authentication codes and digital signatures are **keys used for authentication**. If the legitimate key is unknown, the data cannot be tampered with, nor can it be spoofed.


### 4. Session Keys and Master Keys

In HTTPS, the TLS handshake uses a one-time key that is limited to the current communication and cannot be reused next time. A key that can be used only once per communication is called a **session key**.

Because a new session key is generated for each session, even if the key is eavesdropped, only that session is affected. A key that is reused every time is called a **master key**.


### 5. Keys for Encrypting Content and Keys for Encrypting Keys

When the object being encrypted is information (content) directly used by the user, the key is called a **CEK(Contents Encrypting Key)**. A key used to encrypt keys is called a **KEK(Key Encrypting Key)**.

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

When updating the key, the sender and receiver compute the hash value of the current key using a one-way hash function and use that hash value as the new key. **Use the hash value of the current key as the next key**.

The benefit of key updating is that if an eavesdropper steals the key for a session, the content after that key can be decrypted, but the eavesdropper cannot decrypt the communication content before that key was updated. This is because of the one-way property of one-way hash functions. This mechanism for preventing past communication content from being decrypted is called **backward security**.


## 4. Diffie-Hellman Key Exchange

Diffie-Hellman key exchange is an algorithm invented in 1976 by Whitfield Diffie and Martin Hellman. Using this algorithm, two communicating parties can generate a shared symmetric-key-cryptography key merely by exchanging some information that can be made public.

Although this algorithm is called “key exchange,” no key is actually exchanged. Instead, the same shared key is generated through computation. More precisely, it should be called Diffie-Hellman key agreement.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_6.png'>
</p>

1. Alice sends Bob two prime numbers, P and G   
P is a very large prime number, and G is a smaller number called the generator. P and G can be public, and either party may generate P and G.

2. Alice generates a random number A    
A is an integer between 1~(P-2). Only Alice knows this number.

3. Bob generates a random number B  
B is an integer between 1~(P-2). Only Bob knows this number.

4. Alice sends the result of (G^A mod P) to Bob  
It does not matter if this number is eavesdropped.


5. Bob sends the result of (G^B mod P) to Alice  
It does not matter if this number is eavesdropped.

6. Alice uses the number sent by Bob, raises it to the power of A, and computes mod P  
This number is the final shared key.
```c
(G^B mod P)^A mod P = G^(B*A) mod P 
                    = G^(A*B) mod P
```
7. Bob uses the number sent by Alice to compute its B-th power modulo P  
This number is the final shared key.
```c
(G^A mod P)^B mod P = G^(A*B) mod P
```
At this point, the keys computed by A and B are identical.

The information an eavesdropper can obtain includes: P, G, G^A mod P, and G^B mod P. Computing G^(A*B) mod P from these four values is extremely difficult.

If either A or B were known, all of the steps above could be broken and the final shared key could be computed. However, an eavesdropper can only obtain G^A mod P and G^B mod P. The `mod P` here is the key: if G^A were known directly, A could be computed, but in this case A and B cannot be derived, because this is the **discrete logarithm problem** over a finite field.

>The complexity of the discrete logarithm problem over finite fields is the foundation that supports Diffie-Hellman key exchange.


Although DH key exchange can prevent cryptographic cracking, it cannot defend against man-in-the-middle attacks.

A man-in-the-middle can sit between Alice and Bob and perform separate DH key exchanges with each party, thereby intercepting the communication between them. The way DH defends against man-in-the-middle attacks is the same as with public-key cryptography: digital signatures and certificates can be used to address the issue.

The Diffie-Hellman key exchange used in IPSec improves and extends the protocol specifically to address this man-in-the-middle attack.


## 5. Password-Based Encryption (PBE)

Password-Based Encryption (PBE) is a method that derives a key from a password and uses that key for encryption. The same key is used for encryption and decryption.

The reasons for using PBE are:

1. How do we keep a message confidential? If we store it directly on disk, it may be discovered, so we encrypt it. This produces a CEK.
2. How do we store the CEK securely? Encrypt the CEK with another key. This produces a KEK.
3. How do we store the KEK securely? This leads to an infinite loop, so use a PBE password to generate the KEK.
4. Passwords are vulnerable to dictionary attacks, so first add a salt, then store it together with the encrypted CEK on disk. The KEK can be discarded.
5. In the end, all you need to remember is the password.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_7.png'>
</p>


### 1. PBE Encryption

PBE encryption mainly consists of three steps:

1. Generate the KEK
2. Generate the session key and encrypt it
3. Encrypt the message

After PBE encryption, three items are output:

- Salt
- The session key encrypted with the KEK
- The message encrypted with the session key

The salt and session key need to be stored in a secure place, and the message is sent to the other party.


### 2. PBE Decryption

PBE decryption mainly consists of three steps:

1. Reconstruct the KEK
2. Decrypt the session key
3. Decrypt the message


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/106_8.png'>
</p>

Compared with the PBE encryption process, you can see that the encryption process uses the pseudorandom number generator twice, while the decryption process does not use it at all.

**Salt is primarily used to prevent dictionary attacks**.


## 6. Improved PBE

Because the KEK derived from a password is not as strong as a CEK generated by a pseudorandom number generator, it is like putting the key to a secure safe in an insecure place. Therefore, when using Password-Based Encryption (PBE), the salt and the encrypted CEK need to be protected by physical means. Here is an improved approach.


When generating the KEK, security can be improved by repeatedly applying a one-way hash function. A good method is to input the salt and password into a one-way hash function, then feed the resulting value back into the one-way hash function, and repeat this process 1,000 times, using the final hash value as the KEK.

Computing a one-way hash 1,000 times does not take much time for a user, but it creates significant difficulty for an attacker. This technique of iterating a one-way hash function multiple times is called stretching.


------------------------------------------------------

Reference:
  
《Illustrated Cryptography》        

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/cipherkey/](https://halfrost.com/cipherkey/)