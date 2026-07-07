# Ubiquitous Digital Signatures


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_0.png'>
</p>


## 1. Why Do We Need Digital Signatures?

From the previous article, we know that message authentication codes can detect tampering or whether the sender's identity has been impersonated; that is, they verify message integrity and can also authenticate messages. However, the weakness of message authentication codes lies in their shared key. Because the key is shared, they cannot prevent repudiation.

Digital signatures are designed to solve the problem of repudiation. The way to solve it is to make the shared keys used by the two communicating parties different, so that the keys themselves can distinguish who is who.

## 2. What Is a Digital Signature?

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_2.png'>
</p>

A digital signature is a technology that implements, in the computer world, the equivalent of stamping or signing in the real world. Digital signatures can detect tampering and impersonation, and prevent repudiation.

In digital signatures, there are two actions:

- Generating a signature for a message
- Verifying a signature for a message

The person who **generates the message signature** is the sender of the message; this is also called "signing the message." Generating a signature means computing the value of the digital signature based on the message content.

The person who **verifies the digital signature** is a third party. The third party verifies whether the source of the message belongs to the sender. The verification result may be success or failure.

**Digital signatures distinguish between the signing key and the verification key; the verification key cannot be used to generate signatures**. The signing key can only be held by the signer, while the verification key can be held by anyone who needs to verify the signature.


||Private Key|Public Key|
|:------:|:-----:|:-----:|
|Public-key cryptography|Used by the receiver for decryption|Used by the sender for encryption|
|Digital signature|Used by the signer to generate a signature|Used by the verifier to verify a signature|
|Who holds the key?|Held by an individual|Anyone can hold it if needed|

Strictly speaking, in the RSA algorithm, public-key encryption and digital signatures are exactly inverse operations. However, in other public-key algorithms, digital signatures may not have such a strictly inverse relationship.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_3.png'>
</p>

In public-key algorithms, the public key is used for encryption, and the private key is used for decryption.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_4.png'>
</p>

In digital signatures, the public key is used for decryption (signature verification), and the private key is used for encryption (signature generation).

## 3. Generating and Verifying Digital Signatures

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_5.png'>
</p>

There are two methods for generating and verifying digital signatures:

- Signing the message directly
- Signing the hash value of the message

### 1. Signing the Message Directly

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_6.png'>
</p>


### 2. Signing the Hash Value of the Message

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_7.png'>
</p>


Comparing the two methods above, the second method is generally used. The reason is that the first method needs to encrypt the entire message, and since it uses a public-key algorithm, it is very time-consuming. Using a short one-way hash function value instead of the message itself, and then encrypting it (signing the message), is much faster.

For the two methods above, here are explanations of some common questions:

- Why can encrypted ciphertext carry the meaning of a signature?
	- Digital signatures are implemented using the property that "a person who does not have the private key cannot generate ciphertext produced with that private key." The generated ciphertext is not intended to ensure confidentiality, but to represent a piece of information that **only the holder of that key can generate**. Therefore, ciphertext produced by the private key is a kind of **authenticator**.

- In method 2 above, the message is sent directly without being encrypted. Doesn't that mean the confidentiality of the message cannot be guaranteed?
	- Digital signatures do not guarantee message confidentiality in the first place. If confidentiality is required, encryption and digital signatures can be used together.

- Can a signature be copied freely?
	- The meaning of a digital signature is that **a specific signer is bound to a specific message**. Although a digital signature can be copied arbitrarily, the meaning it represents remains unchanged.

- If someone extracts a signature and combines it with any arbitrary message, wouldn't that allow them to forge the signer's intent?
	- Digital signatures detect modification. During verification, the verifier will find that the hash values of the message and the signature do not match, causing verification to fail and the message to be discarded.

- Is it possible to perform a collision attack by modifying both the message and the signature to deceive the verifier?
	- In practice, this cannot be done. First, after the message is modified, the hash value changes. Attempting to piece together a valid signature afterward is not feasible, because without the private key, it is impossible to encrypt the new hash value.

- Can someone go back on a digital signature after signing?
	- Digital signatures are designed to prevent repudiation. Once signed, the signer cannot repudiate it or tear up the contract. The only option is to create another declaration message stating that the public key has been revoked, and add a digital signature to that message as well.

## 4. Examples of Digital Signature Applications

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_1.png'>
</p>

### 1. Security Advisories

Information security organizations publish warnings about security vulnerabilities on their websites. Since this information needs to be known by more people, there is no need to encrypt the message. However, it is necessary to prevent someone from impersonating the organization and publishing false information. In this case, simply adding a digital signature is sufficient. A signature applied to a plaintext message in this way is generally called a **clearsign** signature.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_8.png'>
</p>

### 2. Software Downloads

To ensure that downloaded software is safe and not a malicious virus, the software author adds a digital signature to the software. After the user finishes downloading it, verifying the digital signature can identify whether the downloaded software has been tampered with.

### 3. Public-Key Certificates

A valid public key is required when verifying a digital signature, but how can you know whether the public key you obtained is legitimate? In this case, the public key needs to be treated as information and digitally signed, producing a public-key certificate. Certificate-related issues will be analyzed in detail in the next article.

### 4. SSL/TLS

SSL/TLS uses a server certificate when authenticating the server's identity. A server certificate is the server's public key with a digital signature added to it.


## 5. Implementation of Digital Signatures

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_9.png'>
</p>

This section briefly discusses generating signatures using the RSA public-key algorithm and a one-way hash function.

### 1. Generating Signatures with RSA
```c
Signature = Message^D mod N (generate a signature with RSA)
```
The D and N above are the signer's private key. Signing is the result of raising the message to the D-th power modulo N.


### 2. Verify Signatures with RSA
```c
message obtained from signature = signature^E mod N (verify signature with RSA)
```
The E and N above are the signer's public key. The verifier raises the signature to the E-th power and takes mod N, obtaining the “message derived from the signature.” This message is compared with the message sent directly by the sender. If they match, verification succeeds; otherwise, it fails.

## VI. Several Other Digital Signature Schemes

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_10.png'>
</p>

### 1. ElGamal Scheme

The ElGamal scheme is a public-key algorithm designed by Taher ElGamal, based on the difficulty of computing discrete logarithms modulo N. The ElGamal scheme can be used for both public-key encryption and digital signatures.


### 2. DSA

DSA (Digital Signature Algorithm) is a digital signature algorithm. It is a digital signature specification (Digital Signature Standard, DSS) established by NIST (National Institute of Standards and Technology) in 1991. DSA is a variant of the Schnorr algorithm and the ElGamal scheme. It can only be used for digital signatures, not for encryption and decryption.

Similar to the DH algorithm, the main thing to understand about DSA is also its parameters. A key pair is generated from a parameter file. p, q, and g are public parameters, and key pairs are generated from them. DSA’s public parameters are very similar to DH’s public parameters: an unlimited number of key pairs can be generated from the public parameters. This is a very important property.

p is a very large prime number. Its length is recommended to be at least 1024 bits (and must be a multiple of 64 bits). p-1 must be a multiple of q, and q must be 160 bits long. g is the result of a mathematical expression, and its value is derived from p and q.

The DSA algorithm uses the following parameters:

p: an L-bit prime number. L is a multiple of 64, in the range from 512 to 1024;  
q: a 160-bit prime factor of p – 1;  
g: g = h^((p-1)/q) mod p, where h satisfies h < p – 1, h^((p-1)/q) mod p > 1;  
x: x < q, where x is the private key;  
y: y = g^x mod p, where ( p, q, g, y ) is the public key;    
H( x ): a one-way hash function. DSS uses SHA (Secure Hash Algorithm).  

DSA key-pair generation depends on these three public parameters p, q, and g. Signature generation and signature verification also depend on the parameter file.

### Generating a DSA Key Pair

1. Choose a random number as the private key x, where 0 < x < q.
2. Generate the public key from the private key: g^x mod p

> The RSA, DH, and DSA algorithms are all based on discrete mathematics.

### Signature Generation

3. Generate a random number k, where 1 < k < q.
4. Compute r = (g^k mod p) mod q.
5. Compute s = (k^(-1)(H(m)+xr)) mod q, where H is a specific digest algorithm.
6. The signature value is (r, s), which is sent together with the original message m.

### Signature Verification

7. If r or s is greater than q or less than 0, verification fails immediately
8. Compute w = s^(-1) mod q
9. Compute u1 = H(m).w mod q
10. Compute u2 = r.w mod q
11. Compute v = (g^u1 * y^u2 mod p) mod q
12. If v equals r, signature verification succeeds; otherwise, it fails

### 3. ECDSA

ECDSA (Elliptic Curve Digital Signature Algorithm) is a digital signature algorithm implemented using elliptic-curve cryptography.

Just as the DH algorithm can be combined with ECC, the DSA algorithm can also be combined with ECC; this is called the ECDSA digital signature algorithm. Compared with DSA, ECDSA provides higher security.

In ECDSA, three parameters are important:

- The named curve selected by the ECDSA algorithm.
- G, the base point of the elliptic curve
- n, the order of the base point G, where n * G = 0

### Generating an ECDSA Key Pair

1. Choose a random number as the private key d\_{a}, where 1< d\_{a} < n -1 
2. Generate the public key from the private key: Q\_{a} = d\_{a} * G

### Signature Generation

3. Compute the digest value e = HASH(m)
4. Obtain z = the leftmost L\_{n} bits of e, where L\_{n} is the length of n
5. Generate a random number k, where 1 < k < n - 1
6. Compute (x,y) = k * G
7. Compute r = x mod n
8. Compute s = k\_{-1} (z + r * d\_{-1}) mod n
9. The signature value is (r, s)

### Signature Verification

10. If r or s is less than 1 or greater than n-1, verification fails immediately
11. Obtain z = the leftmost L\_{n} bits of e
12. Compute w = s^{-1} mod n
13. Compute u\_{1} = zw mod n
14. Compute u\_{2} = rw mod n
15. Compute (x,y) = u\_{1} * G + u\_{2} * Q\_{a}
16. If r == x\_{1} mod n, signature verification succeeds; otherwise, it fails

### 4. Rabin Scheme

The Rabin scheme is a public-key algorithm designed by M.O. Rabin, based on the difficulty of computing square roots modulo N. The Rabin scheme can be used for both public-key encryption and digital signatures.


## VII. Attacks on Digital Signatures

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/104_11.png'>
</p>

### 1. Man-in-the-Middle Attacks on Public Keys

The attack here mainly targets the public key. Public-key certificates are still needed to authenticate public keys.

### 2. Attacks on One-Way Hash Functions

A collision attack can be performed against a one-way hash function to generate a different message that has the same hash value as the message bound to the signature.

### 3. Attacking Public-Key Cryptography by Exploiting Digital Signatures

Because RSA and digital signatures are inverse operations of each other, this property can be used to attack RSA. If the sender is asked to sign an RSA ciphertext (encrypt it with the private key), that is equivalent to the decryption operation in RSA.

There are several ways to prevent this attack:

- Do not sign any message directly; signing the hash value is safer
- Use different key pairs for public-key encryption and digital signatures
- Never sign a message whose meaning is unclear, just as you would not casually stamp a contract you cannot understand

### 4. Existential Forgery

Even if the object being signed is a meaningless message, such as a random bit sequence, if an attacker can generate a valid digital signature (that is, a signature generated by the attacker can pass verification normally), this still constitutes a potential threat to the signature algorithm. In digital signature algorithms that use RSA to decrypt messages, existential forgery is possible. As long as the random bit sequence S is encrypted with the RSA public key to produce ciphertext M, then S is a valid digital signature for M. Since the attacker can obtain the public key, existential forgery of the digital signature is achieved.

To prevent this situation, RSA was improved and a new signature algorithm, RSA-PSS (Probabilistic Signature Scheme), was developed. RSA-PSS does not sign the message itself; instead, it signs the hash value. To improve security, it also salts the message when computing the hash value.

### 5. Other Attacks

Attacks against public-key cryptography can also be applied to digital signatures, such as brute-forcing the private key or attempting to factor RSA’s N into primes.

## VIII. Problems Digital Signatures Cannot Solve

The public key used in the public-key cryptography behind digital signatures must be authenticated separately to prevent man-in-the-middle attacks. The public key used to verify a signature must be certified as belonging to the real sender.

This seems to fall into a circular dependency. Digital signatures are used to detect message tampering, impersonation, and to prevent repudiation. But we must also obtain an untampered public key from a sender who has not been impersonated.

To verify whether the obtained public key is legitimate, a **certificate** must be used. A certificate is obtained by treating the public key as a message and having a trusted third party sign it.

We will continue the discussion of certificates in the next article.

## IX. RSA Digital Signatures in OpenSSL

Unlike RSA public-key encryption, digital signatures implemented with RSA involve digest computation, so a Hash algorithm must be specified. The following example uses the sha256 Hash algorithm.
```c
// Generate an RSA key pair with a 1024-bit key length
$ openssl genrsa -out rsaprivatekey.pem 1024
```
Output
```c

Generating RSA private key, 1024 bit long modulus (2 primes)
......++++++
.............................................++++++
e is 65537 (0x010001)

-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQDbaFOaGiDqwRe+nye9lmLy6mnQT33GGjV+vEDtTP/kog3W5jou
LKduc7Qy/iMDXxVyAddaUjRwkuX6mdVOtDzgbBY/nwOSwvTe9jCD89AM7z0il6iG
7m1JgEEq9zYzmRxO/yfkv8OrlZpfZ6/1jzUKVnjXlGdhkipJqBX19M9/kQIDAQAB
AoGBAM2st6oe0jqeNd8InR1ZK3qhif2vdqzNBta+LHMHGl4+F5EbEvEUBQRCTGr8
1t+jM5xC45iUtPnOiu3nZRE5XlIaGbsklPM3chu0/onBdbXsP5aRSZuIobHP01GV
LFqUsFmVOIAKPONRR8Zn5Ji9FQ5bs6meYBmawC23EWcB/cHRAkEA9AwOFZrIN3XG
0YXkoLTm0eGOWg6zRBUxt9ZwCjhciz/riDWnBqIwHxqourN4ss/XwyPJxmvYXMoW
2dl1KmjYBQJBAOYnVRWMraQSdbeSwTo27tGVME3I6RqJHrs0+4EDH/W79bL778fJ
VMRyTjKhZxbzb7xU0bl9it8rbxN+4yjUmx0CQQC31zDw83Vp2e4Yve05Zq0OZASR
MMu4OOMIIqCqAkUsnM04AXq+E4V+mN2ML1B4GvvlQ1tnfqwxUgceuqJ5fRtlAkAN
ouj0pOgo33sgDE7sjxKpUkiRY0UEcHlkqCf6pd+/5IoTN8AmOzSNiyQ89bkw7+1/
4Bqo/do7jMxBAHSfF7G1AkEAsAx6+LSQHRN8iD1Uno9/VJXkoXV5CMicZIO4OXYT
+z95tcREHgHRX4TmtF4Z9fTX5uQsk8oLgHqG9p4Y+RfJXw==
-----END RSA PRIVATE KEY-----
```
Extract the public key
```c
// Extract the public key from the key pair
$ openssl rsa -in rsaprivatekey.pem -pubout -out rsapublickey.pem  
```
Output
```c
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDbaFOaGiDqwRe+nye9lmLy6mnQ
T33GGjV+vEDtTP/kog3W5jouLKduc7Qy/iMDXxVyAddaUjRwkuX6mdVOtDzgbBY/
nwOSwvTe9jCD89AM7z0il6iG7m1JgEEq9zYzmRxO/yfkv8OrlZpfZ6/1jzUKVnjX
lGdhkipJqBX19M9/kQIDAQAB
-----END PUBLIC KEY-----
```
Generate a signature file
```c
// Use the sha256 hash algorithm and signing algorithm on plain.txt to generate the signature file signature.txt 

$ echo "hello" >> plain.txt
$ openssl dgst -sha256 -sign rsaprivatekey.pem -out signature.txt plain.txt

```
Open the `signature.txt` file; it contains the resulting signature.
```c
l^CãîE<9c><9f>>3^M^?&v{7P`<91> <9c>55g^E^@Ç¦ÈYþ _Ïc`=ÓçÖÄ^[^C¢^MgOÕÂ|^^»ÿ%ä:<92><8a>÷<87>f<89>^M.
¢aO<93>ÕÇÝ&xå[áÜ±ã=.À<82>ÙèEz^E(_^@spøZ9×<93>\©É^]ËIo^Z?(^^1*á¶%¯²©^Wñ¶f7iQKäC`
```
Verify the signature file
```c
// Use the same digest and signature algorithms to verify the signature file; compare the signature file with the original file
$ openssl dgst -sha256 -verify rsapublickey.pem -signature signature.txt plain.txt
```
Output
```c
Verified OK
```
If you doubt whether the verification above is genuine, we can use another file to verify the signature—for example, try a different `.txt` file.
```c
// Use a different txt file to verify the signature again
$ openssl dgst -sha256 -verify rsapublickey.pem -signature signature.txt signature.txt
```
Output
```c
Verification Failure
```
In addition to using the sha256 hash algorithm, you can also specify the RSASSA-PSS standard.
```c
// Generate an RSA key pair
$ openssl genrsa -out rsaprivatekey.pem 2048
```
Output
```c
Generating RSA private key, 2048 bit long modulus (2 primes)
..........................+++
............................+++
e is 65537 (0x010001)

-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAuvYWXiZ7esG+Vv/aiOSwoXV1bURTUimwUumQm1N0lOsy0BC4
yxxjhPxz5UNHCUIGFp39Ux6BRRKxAeD+J13AAte6Ge+hU3hS+b1TN55oVpdTX6Er
1GzpnL6bn/ZCGR7Rd4ml9H58+n6SKowDRecBYQkuOgMkInLl36dHCuvG65h3KYdT
Emhkb8IjUQAMGjGcbJpkAnjmP5k6RxY//sx9/o/kyPKiYSIJDRVJBShg+ADfkuyT
qD1jAYl7LSsN4w27KQIV0r606WZbTYcWzM4wPU30XFvTLDzp7frueSF8hprJiOA/
D6TDaCPbEx9QXeUCvsGCXhTUl7sKkNSSA9jW/wIDAQABAoIBAGVoMyuwHcuwqKgR
sJwNxsxcpGu24qavHAdszlWhh5t6kx4N492vMT+hms8glbgsypab7RqXcjBf+gh1
3ATIMeyYzEVjF5Lpsb/p8+g4EInfHIbDKb3XsUKmlEzISoPLlnwK+ivKK8nGu0s+
lEvnB3V1gFBRAdl5jrunxL3kswl3xAOTPUG7HN8SzhKbW2q15iXeIYdsrGDdNmCW
r4ijcW2xuaCAwRIDG9wMsaU+J0kVBoxqrFcN1t73HdhauDCdHqH7oBYYxCliMvmQ
MainlIcF3hfhS8fPbUm52mepIKjUAw+mpzlNnhPz6tuk5T1dUu/hafdIoBZ9yfK1
n6yw14ECgYEA7igQq/di+YE7XdV3jgqKCOlWFx68M14NRdNcYZhjPHw2F4waqur+
K0FDMLVP/lPfoI3BWIvjp3qSiMbplKVPokMAdJ0kkwiw/zSHaz8NYANTET5RQvs1
akhD/oHiktY/NKEWlpofKj09dzeALWzhvIz7q7b6sjXXTJVQL6DouMECgYEAyPgT
6w+yh1Orf8utnCgd2e7YInl+5RhIZqE4DKeJXjFUhxktimv2d7QJXP7KjAcdjel4
KzQ+nIDody59GZtibLRMU1p7tAHOFKpV7k7D3ZiDqzn9BsRs+GemKAjoY5BroL9b
+Cdc05ksRRSyd37A1C6sbLepbKyzvUmbzTUfv78CgYAqvRPo2HdxkSiHOVTAL9H/
sWgatBBQI5O8MScF+KPuadgHN8RdYdiFCKw3JIKbgI/EL0xASLJtDskXNKMcYuI8
m0uModq7bDbfRZz7uQ/8Z/xTPty0aYJ3dUqGdOalNT+YgUQdeMEZAm5yY4pkHIMS
JDbR5P9uVc0yWCVQts6swQKBgQC1QfKNDtJhddh3YdfKwO/zkJVFurj1nconLn9k
AnNGDk4Dr3TApRFd83aCdpduZjiEty8YIH3cH/QLElXok5nZG2C/yRtLRll9kAgC
8O19XsJa2+lXgjAadzmIYEhhDG/WQuGLVs1FV6BzCfDRD/SRKyt+vsPDbZyLO+mW
0rQ49wKBgQDhWlAtmZKN12tfvHWpnbhj4rfBaSFpYRh4AimgQJyPvjzy/9Edw7i5
YAJosFtocanOpnKbYaZCng5wFra9e9+vwd66Ab80o/ZzAtuNtyxh1+LP2c+XCl8W
dgF4cl4wkopwQ6f8dauG7dKGsP4NunUoXjJO/Ky+PcFgzrAeJ3Z8xA==
-----END RSA PRIVATE KEY-----
```
Extract the public key
```c
$ openssl rsa -in rsaprivatekey.pem -pubout -out rsapublickey.pem
```
Output
```c
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuvYWXiZ7esG+Vv/aiOSw
oXV1bURTUimwUumQm1N0lOsy0BC4yxxjhPxz5UNHCUIGFp39Ux6BRRKxAeD+J13A
Ate6Ge+hU3hS+b1TN55oVpdTX6Er1GzpnL6bn/ZCGR7Rd4ml9H58+n6SKowDRecB
YQkuOgMkInLl36dHCuvG65h3KYdTEmhkb8IjUQAMGjGcbJpkAnjmP5k6RxY//sx9
/o/kyPKiYSIJDRVJBShg+ADfkuyTqD1jAYl7LSsN4w27KQIV0r606WZbTYcWzM4w
PU30XFvTLDzp7frueSF8hprJiOA/D6TDaCPbEx9QXeUCvsGCXhTUl7sKkNSSA9jW
/wIDAQAB
-----END PUBLIC KEY-----
```
Specifying the RSASSA-PSS Standard
```c
// Specify the RSASSA-PSS standard
$ openssl dgst -sha256 -sign rsaprivatekey.pem -sigopt rsa_padding_mode:pss -out signature.txt plain.txt
```
Open the `signature.txt` file; it contains the signed result.
```c
¡°<8f>^W-ý0]ê^Qnà<90><97>N<9e>8^T²»<97>¢<8d>¤¯*S<98>ò.C·=^BñM¸bõ^[<99>Øã­p×V²Ð8vz#^Z}¹ÔO¨õò¬<85>^D<8c>¦C^W^K²$^P&BCô$Z4<8b>¢w<9c><91>þz@×<82>ùáÇ¶µ&8<97>Í<8a><95>4ºû7É¿#^X<95>SÜ_s<98>g<9a>lï<91><92>gý^Bm^Yw'1LJ7¹m3+<81>m©¥ë\<96>¼BÄØ<8d>vO»Ü<82><98>¨^K]7ØÖöP¿^F^_[Ñã÷Þ3^^}-´ý<84><9f>^E^[ÖA>^NF<8f>É!<8c>¿ÿÆ,º«õtãäV8ÿ<91><8b>Ã_Å<9f>ï<88>Q^õ<99>^Uê<9c><91>^E)Õ$H¶"ç:hDôU*_FÙ<8a>^LÝU<8f>^H©9%uè^_^C¨V<8d>+yB¨^ZR
```
Verify Signature
```c
// Verify signature
$ openssl dgst -sha256 -verify rsapublickey.pem -sigopt rsa_padding_mode:pss -signature signature.txt plain.txt
```
Output
```c
Verified OK
```
If you suspect whether the verification above is genuine, you can verify the signature with another file—for example, use a different txt file, or verify it without PSS mode. Both approaches will cause verification to fail.
```c
// Replace with another txt file to verify the signature again
$ openssl dgst -sha256 -verify rsapublickey.pem -sigopt rsa_padding_mode:pss -signature signature.txt signature.txt

// Verify the signature without PSS mode
$ openssl dgst -sha256 -verify rsapublickey.pem -signature signature.txt plain.txt
```
Both of the above methods will fail verification.


## 10. DSA Digital Signatures in OpenSSL

Use OpenSSL commands to understand the DSA algorithm.
```c
// Generate a parameter file, similar to a DH parameter file
$ openssl dsaparam -out dsaparam.pem 1024
```
Output
```c
Generating DSA parameters, 1024 bit long prime
This could take some time
..........+..+.............................+++++++++++++++++++++++++++++++++++++++++++++++++++*
..+..+....+....+.+....+..............+.....+...+.+...................+.+...........+.+..+...+++++++++++++++++++++++++++++++++++++++++++++++++++*

-----BEGIN DSA PARAMETERS-----
MIIBHgKBgQDbXt+UNxsM2KJGR5q76uqWDgmZKSV3vordjqdwirG/ukuRkBrg0p7y
Whhd8s+As+Q0erzE9mQfyKrqnQjAAxBOT/9rjH4hvYcgg0H/uSzWrkRIgZx7/8dF
dnOEH+ORwgQlbxZ+p1k/Le4rJh/dTARRbAjCa+YkAU9ZL8cGnsQvWQIVAJ8v+YVH
YjCApNnLjEBVRTF4kvSpAoGAearp5Wi8BtC77al/P+W/KfxTrp3TmMFwImWG+Fqd
GVa4poqhYEcFGSaZsrnFZGOwT0PgFLvFCzkz0sfn0OeT7haSIwr8lVcnXL3dexWY
ejEeWDa1nCERqAL9r/eO5QldwSgw6muCjNA/A7eghz1E5KQxjYkRQGLdYx+fbC1N
ge4=
-----END DSA PARAMETERS-----
```
Generate a key pair
```c
// Generate key pair dsaprivatekey.pem from the parameter file
$ openssl gendsa -out dsaprivatekey.pem dsaparam.pem
```
Output
```c
Generating DSA key, 1024 bits

-----BEGIN DSA PRIVATE KEY-----
MIIBuwIBAAKBgQDbXt+UNxsM2KJGR5q76uqWDgmZKSV3vordjqdwirG/ukuRkBrg
0p7yWhhd8s+As+Q0erzE9mQfyKrqnQjAAxBOT/9rjH4hvYcgg0H/uSzWrkRIgZx7
/8dFdnOEH+ORwgQlbxZ+p1k/Le4rJh/dTARRbAjCa+YkAU9ZL8cGnsQvWQIVAJ8v
+YVHYjCApNnLjEBVRTF4kvSpAoGAearp5Wi8BtC77al/P+W/KfxTrp3TmMFwImWG
+FqdGVa4poqhYEcFGSaZsrnFZGOwT0PgFLvFCzkz0sfn0OeT7haSIwr8lVcnXL3d
exWYejEeWDa1nCERqAL9r/eO5QldwSgw6muCjNA/A7eghz1E5KQxjYkRQGLdYx+f
bC1Nge4CgYB6o8lSB4HkznXMyVkByLeRo5IE+IQqKcFtM4kD6d4ZukcI2IUHp7bI
jYSjJNyalYTwPcCMgpWJEseC6Xcf90gR39Sz/P2+pWiyCzhJ1CXHlQzwpOIAKuOq
ojwlykrYBZuPuD0Bpo2kUJKyua/Te1b8cfElVMyr7OrCN0HIBIHovQIVAJbryCYW
7s9I2PGsiuz758FMjZ9Z
-----END DSA PRIVATE KEY-----
```
Encrypt the private key file
```c
// Encrypt the private key file using the des3 algorithm
$ openssl gendsa -out dsaprivatekey2.pem -des3 dsaparam.pem
```
Output
```c
Generating DSA key, 1024 bits
Enter PEM pass phrase:
Verifying - Enter PEM pass phrase:

----BEGIN DSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,E06226CA00C80472

xTbh4VYy44X/0sZMmUfuPua9VtunXtcdJ3soFHvjpjBaCgn64/nVbGQYBV1t6TY0
Poic5LmZ+ooVCAxC9EkUid+TzZ3qCWwI3Pdagj8YoNWrak6ayj6j00EZ2HQNs3eI
j2lyIpyetpJCziGvohveEnmFEU6k7DSKdgpJtZv2yayK4L19r8AIcGlgO/o125qH
VP4vJvoEAuFMrxXJP3NgJ0ZcF9fffAZz6sV+lHGVb6B8rWptWwP9QRNGNfdqa5T9
RJAbZrYpvyBlewljDXscB34eYo6PrlItlTWImvJ+KrVA8QLpYditIcjjdlNDYvRq
eC7sgyDGaKNBSk+DDQ5ZKQaI9MEPi34kAqp+esv083WbnXhCkkSzcu5sacxPJJQN
XK0nxP3YSWY7w0L/cDzxnsaT0gl+l3AFvUxDge97iq3hmDGt6BSqLzAQAcn4VDnx
Hc0OQKm3hZalej6iLNenf84SWxC7dc0cRgfReMOXhjik+PsN4eturhDkGzapiHW2
YLVG15f+/XEknnvW5RQ8ttTPB47O7UFxxt4JLw4KE3nsDkGYFweEOwffVWFo3MH8
+uYhp/Inu8Z0bTVUCm5bSA==
-----END DSA PRIVATE KEY-----
```
Extract the public key
```c
// Extract the public key from the key pair file
$ openssl dsa -in dsaprivatekey.pem -pubout -out dsapublickey.pem
```
Output
```c
read DSA key
writing DSA key

-----BEGIN PUBLIC KEY-----
MIIBtjCCASsGByqGSM44BAEwggEeAoGBANte35Q3GwzYokZHmrvq6pYOCZkpJXe+
it2Op3CKsb+6S5GQGuDSnvJaGF3yz4Cz5DR6vMT2ZB/IquqdCMADEE5P/2uMfiG9
hyCDQf+5LNauREiBnHv/x0V2c4Qf45HCBCVvFn6nWT8t7ismH91MBFFsCMJr5iQB
T1kvxwaexC9ZAhUAny/5hUdiMICk2cuMQFVFMXiS9KkCgYB5qunlaLwG0LvtqX8/
5b8p/FOundOYwXAiZYb4Wp0ZVrimiqFgRwUZJpmyucVkY7BPQ+AUu8ULOTPSx+fQ
55PuFpIjCvyVVydcvd17FZh6MR5YNrWcIRGoAv2v947lCV3BKDDqa4KM0D8Dt6CH
PUTkpDGNiRFAYt1jH59sLU2B7gOBhAACgYB6o8lSB4HkznXMyVkByLeRo5IE+IQq
KcFtM4kD6d4ZukcI2IUHp7bIjYSjJNyalYTwPcCMgpWJEseC6Xcf90gR39Sz/P2+
pWiyCzhJ1CXHlQzwpOIAKuOqojwlykrYBZuPuD0Bpo2kUJKyua/Te1b8cfElVMyr
7OrCN0HIBIHovQ==
-----END PUBLIC KEY-----
```
View information about the private key file
```c
// View the three public parameters, public key, and private key
$ openssl dsa -in dsaprivatekey.pem -text
```
Output
```c
read DSA key
Private-Key: (1024 bit)
priv:
    00:96:eb:c8:26:16:ee:cf:48:d8:f1:ac:8a:ec:fb:
    e7:c1:4c:8d:9f:59
pub:
    7a:a3:c9:52:07:81:e4:ce:75:cc:c9:59:01:c8:b7:
    91:a3:92:04:f8:84:2a:29:c1:6d:33:89:03:e9:de:
    19:ba:47:08:d8:85:07:a7:b6:c8:8d:84:a3:24:dc:
    9a:95:84:f0:3d:c0:8c:82:95:89:12:c7:82:e9:77:
    1f:f7:48:11:df:d4:b3:fc:fd:be:a5:68:b2:0b:38:
    49:d4:25:c7:95:0c:f0:a4:e2:00:2a:e3:aa:a2:3c:
    25:ca:4a:d8:05:9b:8f:b8:3d:01:a6:8d:a4:50:92:
    b2:b9:af:d3:7b:56:fc:71:f1:25:54:cc:ab:ec:ea:
    c2:37:41:c8:04:81:e8:bd
P:
    00:db:5e:df:94:37:1b:0c:d8:a2:46:47:9a:bb:ea:
    ea:96:0e:09:99:29:25:77:be:8a:dd:8e:a7:70:8a:
    b1:bf:ba:4b:91:90:1a:e0:d2:9e:f2:5a:18:5d:f2:
    cf:80:b3:e4:34:7a:bc:c4:f6:64:1f:c8:aa:ea:9d:
    08:c0:03:10:4e:4f:ff:6b:8c:7e:21:bd:87:20:83:
    41:ff:b9:2c:d6:ae:44:48:81:9c:7b:ff:c7:45:76:
    73:84:1f:e3:91:c2:04:25:6f:16:7e:a7:59:3f:2d:
    ee:2b:26:1f:dd:4c:04:51:6c:08:c2:6b:e6:24:01:
    4f:59:2f:c7:06:9e:c4:2f:59
Q:
    00:9f:2f:f9:85:47:62:30:80:a4:d9:cb:8c:40:55:
    45:31:78:92:f4:a9
G:
    79:aa:e9:e5:68:bc:06:d0:bb:ed:a9:7f:3f:e5:bf:
    29:fc:53:ae:9d:d3:98:c1:70:22:65:86:f8:5a:9d:
    19:56:b8:a6:8a:a1:60:47:05:19:26:99:b2:b9:c5:
    64:63:b0:4f:43:e0:14:bb:c5:0b:39:33:d2:c7:e7:
    d0:e7:93:ee:16:92:23:0a:fc:95:57:27:5c:bd:dd:
    7b:15:98:7a:31:1e:58:36:b5:9c:21:11:a8:02:fd:
    af:f7:8e:e5:09:5d:c1:28:30:ea:6b:82:8c:d0:3f:
    03:b7:a0:87:3d:44:e4:a4:31:8d:89:11:40:62:dd:
    63:1f:9f:6c:2d:4d:81:ee
writing DSA key
-----BEGIN DSA PRIVATE KEY-----
MIIBuwIBAAKBgQDbXt+UNxsM2KJGR5q76uqWDgmZKSV3vordjqdwirG/ukuRkBrg
0p7yWhhd8s+As+Q0erzE9mQfyKrqnQjAAxBOT/9rjH4hvYcgg0H/uSzWrkRIgZx7
/8dFdnOEH+ORwgQlbxZ+p1k/Le4rJh/dTARRbAjCa+YkAU9ZL8cGnsQvWQIVAJ8v
+YVHYjCApNnLjEBVRTF4kvSpAoGAearp5Wi8BtC77al/P+W/KfxTrp3TmMFwImWG
+FqdGVa4poqhYEcFGSaZsrnFZGOwT0PgFLvFCzkz0sfn0OeT7haSIwr8lVcnXL3d
exWYejEeWDa1nCERqAL9r/eO5QldwSgw6muCjNA/A7eghz1E5KQxjYkRQGLdYx+f
bC1Nge4CgYB6o8lSB4HkznXMyVkByLeRo5IE+IQqKcFtM4kD6d4ZukcI2IUHp7bI
jYSjJNyalYTwPcCMgpWJEseC6Xcf90gR39Sz/P2+pWiyCzhJ1CXHlQzwpOIAKuOq
ojwlykrYBZuPuD0Bpo2kUJKyua/Te1b8cfElVMyr7OrCN0HIBIHovQIVAJbryCYW
7s9I2PGsiuz758FMjZ9Z
-----END DSA PRIVATE KEY-----
```
`priv` and `pub` correspond to the private key and public key in a key pair, while `P`, `Q`, and `G` are the three key parameters in the parameter file. These are essential to the DSA algorithm.

Since you can inspect the information in the private key file, you can likewise inspect the information in the public key file.
```c
// View the public key and file information
$ openssl dsa -pubin -in dsapublickey.pem -text
```
Output
```c
read DSA key
pub:
    7a:a3:c9:52:07:81:e4:ce:75:cc:c9:59:01:c8:b7:
    91:a3:92:04:f8:84:2a:29:c1:6d:33:89:03:e9:de:
    19:ba:47:08:d8:85:07:a7:b6:c8:8d:84:a3:24:dc:
    9a:95:84:f0:3d:c0:8c:82:95:89:12:c7:82:e9:77:
    1f:f7:48:11:df:d4:b3:fc:fd:be:a5:68:b2:0b:38:
    49:d4:25:c7:95:0c:f0:a4:e2:00:2a:e3:aa:a2:3c:
    25:ca:4a:d8:05:9b:8f:b8:3d:01:a6:8d:a4:50:92:
    b2:b9:af:d3:7b:56:fc:71:f1:25:54:cc:ab:ec:ea:
    c2:37:41:c8:04:81:e8:bd
P:
    00:db:5e:df:94:37:1b:0c:d8:a2:46:47:9a:bb:ea:
    ea:96:0e:09:99:29:25:77:be:8a:dd:8e:a7:70:8a:
    b1:bf:ba:4b:91:90:1a:e0:d2:9e:f2:5a:18:5d:f2:
    cf:80:b3:e4:34:7a:bc:c4:f6:64:1f:c8:aa:ea:9d:
    08:c0:03:10:4e:4f:ff:6b:8c:7e:21:bd:87:20:83:
    41:ff:b9:2c:d6:ae:44:48:81:9c:7b:ff:c7:45:76:
    73:84:1f:e3:91:c2:04:25:6f:16:7e:a7:59:3f:2d:
    ee:2b:26:1f:dd:4c:04:51:6c:08:c2:6b:e6:24:01:
    4f:59:2f:c7:06:9e:c4:2f:59
Q:
    00:9f:2f:f9:85:47:62:30:80:a4:d9:cb:8c:40:55:
    45:31:78:92:f4:a9
G:
    79:aa:e9:e5:68:bc:06:d0:bb:ed:a9:7f:3f:e5:bf:
    29:fc:53:ae:9d:d3:98:c1:70:22:65:86:f8:5a:9d:
    19:56:b8:a6:8a:a1:60:47:05:19:26:99:b2:b9:c5:
    64:63:b0:4f:43:e0:14:bb:c5:0b:39:33:d2:c7:e7:
    d0:e7:93:ee:16:92:23:0a:fc:95:57:27:5c:bd:dd:
    7b:15:98:7a:31:1e:58:36:b5:9c:21:11:a8:02:fd:
    af:f7:8e:e5:09:5d:c1:28:30:ea:6b:82:8c:d0:3f:
    03:b7:a0:87:3d:44:e4:a4:31:8d:89:11:40:62:dd:
    63:1f:9f:6c:2d:4d:81:ee
writing DSA key
-----BEGIN PUBLIC KEY-----
MIIBtjCCASsGByqGSM44BAEwggEeAoGBANte35Q3GwzYokZHmrvq6pYOCZkpJXe+
it2Op3CKsb+6S5GQGuDSnvJaGF3yz4Cz5DR6vMT2ZB/IquqdCMADEE5P/2uMfiG9
hyCDQf+5LNauREiBnHv/x0V2c4Qf45HCBCVvFn6nWT8t7ismH91MBFFsCMJr5iQB
T1kvxwaexC9ZAhUAny/5hUdiMICk2cuMQFVFMXiS9KkCgYB5qunlaLwG0LvtqX8/
5b8p/FOundOYwXAiZYb4Wp0ZVrimiqFgRwUZJpmyucVkY7BPQ+AUu8ULOTPSx+fQ
55PuFpIjCvyVVydcvd17FZh6MR5YNrWcIRGoAv2v947lCV3BKDDqa4KM0D8Dt6CH
PUTkpDGNiRFAYt1jH59sLU2B7gOBhAACgYB6o8lSB4HkznXMyVkByLeRo5IE+IQq
KcFtM4kD6d4ZukcI2IUHp7bIjYSjJNyalYTwPcCMgpWJEseC6Xcf90gR39Sz/P2+
pWiyCzhJ1CXHlQzwpOIAKuOqojwlykrYBZuPuD0Bpo2kUJKyua/Te1b8cfElVMyr
7OrCN0HIBIHovQ==
-----END PUBLIC KEY-----
```
In the output, the four parameters `pub`, `P`, `Q`, and `G` are consistent with the private key output.

Finally, verify the DSA signature algorithm. This is similar to RSA.
```c
// DSA signing
$ openssl dgst -sha256 -sign dsaprivatekey.pem -out signature.txt plain.txt
```
Output
```c
0-^B^T^QÉ:wÇ^K^F^AÆ<88>Ê^C!0Hø>,$^W^B^U^@<8d>Ùy
^@H^W^W^Dàø'mqî_}^Y¹m
```
Verify Signature
```c
// Verify signature
$ openssl dgst -sha256 -verify dsapublickey.pem -signature signature.txt plain.txt
```
Output
```c
Verified OK
```
If you doubt whether the verification above is genuine, you can use another file to verify the signature—for example, switch to a different txt file.
```c
// Use another txt file to verify the signature again
$ openssl dgst -sha256 -verify dsapublickey.pem -signature signature.txt signature.txt
```
Output
```c
Verification Failure
```

## 10. ECDSA Digital Signatures in OpenSSL

Generate an ECDSA private key
```c
// Directly generate an ECDSA private key; no need to pre-generate an ECC parameter file
$ openssl ecparam -name secp256k1 -genkey -out ecdsa_priv.pem
```
Output
```c
// secp256k1.pem
-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----

// ecdsa_priv.pem
-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIAU0ftIIbLdCROYOZcGcc+4JjAsTvYI1pH9Ejbx57k1UoAcGBSuBBAAK
oUQDQgAEKNlv9Lyu406/hmj4r3ZfmtisJUvPThCasMGySrR4mST8LxLeO6NpsmKL
OVSNQgleZw6fu2ktLGFtObKTeu6z9w==
-----END EC PRIVATE KEY-----
```
Display private key information
```c
// Display private key information
$ openssl ec -in ecdsa_priv.pem -text -noout
```
Output
```c
read EC key
Private-Key: (256 bit)
priv:
    05:34:7e:d2:08:6c:b7:42:44:e6:0e:65:c1:9c:73:
    ee:09:8c:0b:13:bd:82:35:a4:7f:44:8d:bc:79:ee:
    4d:54
pub:
    04:28:d9:6f:f4:bc:ae:e3:4e:bf:86:68:f8:af:76:
    5f:9a:d8:ac:25:4b:cf:4e:10:9a:b0:c1:b2:4a:b4:
    78:99:24:fc:2f:12:de:3b:a3:69:b2:62:8b:39:54:
    8d:42:09:5e:67:0e:9f:bb:69:2d:2c:61:6d:39:b2:
    93:7a:ee:b3:f7
ASN1 OID: secp256k1
```
From the output, you can see the private key information and the named curve information. The key length is 256 bits.

Next, obtain the public key.
```c
// Extract the public key
$ openssl ec -in ecdsa_priv.pem -pubout -out ecdsa_pub.pem

// Display the public key
$ openssl ec -in ecdsa_pub.pem -pubin -text -noout
```
Output
```c
// ecdsa_pub.pem
-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEKNlv9Lyu406/hmj4r3ZfmtisJUvPThCa
sMGySrR4mST8LxLeO6NpsmKLOVSNQgleZw6fu2ktLGFtObKTeu6z9w==
-----END PUBLIC KEY-----


read EC key
Public-Key: (256 bit)
pub:
    04:28:d9:6f:f4:bc:ae:e3:4e:bf:86:68:f8:af:76:
    5f:9a:d8:ac:25:4b:cf:4e:10:9a:b0:c1:b2:4a:b4:
    78:99:24:fc:2f:12:de:3b:a3:69:b2:62:8b:39:54:
    8d:42:09:5e:67:0e:9f:bb:69:2d:2c:61:6d:39:b2:
    93:7a:ee:b3:f7
ASN1 OID: secp256k1
```
Generate a signature
```c
// Choose sha256 as the HASH algorithm
$ openssl dgst -sha256 -sign ecdsa_priv.pem -out signature.txt plain.txt
```
Output
```c
// signature.txt
0E^B JTH}Xi<88>)<8d>'È;þÆße<93>»Õ¦|?8^@<84>=gªA)F^K^B!^@°^U³<9d>F <83>ÐÄµb^^<81>ÿ<9b>b<92>Âæ½M0,"W$G,øÑRW
```
Verify Signature
```c
// Verify signature
$ openssl dgst -sha256 -verify ecdsa_pub.pem -signature signature.txt plain.txt
```
Output
```c
Verified OK
```
If you doubt whether the verification above is genuine, we can verify the signature with another file, such as a different .txt file.
```c
// Use another txt file to verify the signature again
$ openssl dgst -sha256 -verify ecdsa_pub.pem -signature signature.txt signature.txt
```
Output
```c
Verification Failure
```
**DSA signature operations are much slower than RSA signature operations, but ECDSA signature generation is much faster than RSA signature generation, while ECDSA signature verification is relatively somewhat slower than RSA signature verification**.

Considering both security and speed, when choosing between DSA and ECDSA, prefer ECDSA.


------------------------------------------------------

Reference:
  
*Illustrated Cryptography Techniques*        

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/digital\_signature/](https://halfrost.com/digital_signature/)