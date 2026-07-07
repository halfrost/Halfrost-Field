+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS", "Cryptography"]
date = 2018-08-11T17:06:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/98_0.png"
slug = "symmetric_encryption"
tags = ["Protocol", "HTTPS", "Cryptography"]
title = "A Tour of Symmetric Encryption Algorithms"

+++


## 1. Introduction

Before introducing symmetric encryption, it is necessary to first introduce a bitwise operation: XOR. XOR stands for exclusive or, translated into Chinese as “yìhuò” (exclusive OR).
```c
0 XOR 0 = 0
0 XOR 1 = 1
1 XOR 0 = 1
1 XOR 1 = 0
```
XOR can be thought of as “if two numbers are the same, the XOR is 0; if they are different, the XOR is 1.”

XOR is also called a half-add operation. Its rules are equivalent to binary addition without carry: in binary, 1 represents true and 0 represents false, so the rules for XOR are:
```c
0 ⊕ 0 = 0
1 ⊕ 0 = 1
0 ⊕ 1 = 1
1 ⊕ 1 = 0
```
These rules are the same as addition, except without carrying, so XOR is often considered addition without carry. This property of XOR also leads to one of its commonly used characteristics: **the result of XOR-ing two identical numbers is always 0**.

Correspondingly, we can also derive the following operation rules:
```c
1. a ⊕ a = 0
2. a ⊕ b = b ⊕ a commutative law
3. a ⊕ b ⊕ c = a ⊕ (b ⊕ c) = (a ⊕ b) ⊕ c  associative law
4. d = a ⊕ b ⊕ c can derive a = d ⊕ b ⊕ c
5. a ⊕ b ⊕ a = b
```
I won’t belabor the derivation of the rules above; I trust readers can understand them.

The associativity of XOR can be used to implement simple symmetric encryption.

Imagine setting the XOR operand to a completely random binary sequence. After the value being XORed is XORed with it once, the result is like “ciphertext.” If an eavesdropper does not know what the XOR operand is, it is difficult to recover the original message in a short time.
```c
a ⊕ b ⊕ b = a ⊕ (b ⊕ b) = a ⊕ 0 = a
```
After the message recipient obtains the ciphertext, they XOR the ciphertext with the XOR operand again, and the original plaintext can be recovered. This property is the associativity of XOR.


## II. One-Time Pad

As long as brute force is used to traverse the key space, the ciphertext will inevitably be cracked someday. It is only a question of how large the key space is and how much time is required. However, there is one encryption method that has been proven to be forever unbreakable: even if the entire key space is exhaustively searched, it still cannot be cracked.

When I first encountered this encryption method, I found it fascinating. Such a powerful encryption method must surely have a very complex encryption process and a very rigorous mathematical proof. But after seeing how it works, I found that this is not the case. The encryption method of the one-time pad is very simple: it uses only the XOR operation mentioned in the previous chapter.


### (1) Encryption

For one-time pad encryption, take an example where the plaintext to be encrypted is midnight.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_1_.png'>
</p>

The key is a random binary stream. The encryption process of the one-time pad XORs the plaintext with the key.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_2.png'>
</p>


### (2) Decryption

The decryption process of the one-time pad XORs the ciphertext with the key to obtain the original plaintext.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_3.png'>
</p>

After seeing this encryption and decryption process, readers will certainly question whether this approach is easy to crack: if the random binary stream is 64 bits, then brute-forcing its key space should eventually reveal the original plaintext.

Now the mystery can be explained. It is true that brute force can traverse the entire key space. Suppose there is a super quantum computer that can traverse a key space as large as 2^64^ in one second, it still cannot crack the one-time pad. Its “magic” lies in the fact that, during continuous attempts, many possible plaintexts will be produced. For example, you might obtain plaintexts such as abcdefg, aaaaa, plus, or mine, but you cannot determine whether you have decrypted it correctly. This is why the one-time pad cannot be cracked; it has nothing to do with the size of the key space.

The unbreakability of the one-time pad was proven mathematically by C.E. Shannon in 1949. The one-time pad is **unconditionally secure and theoretically unbreakable**.

### (3) Drawbacks

Although the one-time pad is so powerful, in practice no one uses it for encryption. There are several reasons:

#### 1. How is the key sent to the other party?

In a one-time pad, the key is the same length as the plaintext. Imagine that if there were a way to deliver the ciphertext securely to the other party, could the same method be used to deliver the plaintext to the other party? So this is a contradictory problem.

#### 2. Key storage is a problem

The key length of a one-time pad is the same as the plaintext length, and the key cannot be deleted or discarded. Discarding the key is equivalent to discarding the plaintext. Therefore, the problem of “encrypting to protect the plaintext” is transformed into the problem of “how to securely protect a key that is the same length as the plaintext”. In practice, the problem still has not been solved.


#### 3. The key cannot be reused

If the plaintext to be encrypted is very long, then the key must be the same length, and the key must be different every time. If it is the same, once the key is leaked, all past plaintexts encrypted with that key will be decrypted.


#### 4. Key synchronization is difficult

If the key changes every time, then how to synchronize the key is also a problem. There must not be any misalignment during key transmission. If there is a misalignment, every bit after the misaligned bit can no longer be decrypted.

#### 5. Key generation is difficult

For a one-time pad to truly be forever unbreakable, a large amount of truly random numbers must be generated; they cannot be pseudorandom numbers generated by a computer.


It is said that hotline telephones between countries use one-time pads. But how are the five drawbacks above avoided? Countries send dedicated agents to physically escort the keys and deliver them directly into the other party’s hands.

It is clear that although the one-time pad cannot be cracked, the “cost” of using it for encryption is very high. Thus, the one-time pad has essentially no practical value in everyday use. However, the idea behind the one-time pad gave rise to the **stream cipher**. A stream cipher does not use a truly random bit sequence, but instead uses a binary bit sequence generated by a pseudorandom number generator. Although stream ciphers are not unbreakable, a strong cryptosystem can be built as long as a high-performance pseudorandom number generator is used. Stream ciphers will be analyzed in detail in the following sections.

## III. Symmetric Encryption Algorithm DES

DES (Data Encryption Standard) is a symmetric cipher adopted in 1977 as a U.S. Federal Information Processing Standard (FIPS) (FIPS 46-3). DES has long been used by the U.S. government, other governments, and banks.

In the 1997 DES Challenge I competition, it took 96 days to crack a DES key. In the 1998 DES Challenge II-1 competition, it took only 41 days. In the 1998 DES Challenge II-2 competition, it took 56 hours. In the 1999 DES Challenge III competition, it took only 22 hours and 15 minutes. At present, DES is no longer secure. Except for decrypting old DES ciphertexts from the past, DES is no longer used for encryption.


### (1) Encryption

DES is a symmetric encryption algorithm that encrypts 64-bit plaintext into 64-bit ciphertext. Its key length is 64 bits, but after excluding one bit set aside for error detection every 7 bits, the actual key length is 56 bits. DES encrypts data in **blocks** of 64 bits. A cipher algorithm that processes data in block units is called a **block cipher**, and DES is one type of block cipher.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_4_.png'>
</p>

DES can encrypt only 64 bits of plaintext at a time. If the plaintext exceeds 64 bits, it must be encrypted in blocks. The way this repeated iteration is performed is called a **mode**. A more detailed discussion of modes appears in the next section.

The basic structure of DES encryption is the **Feistel network, Feistel structure, or Feistel cipher**. This structure is used not only in DES, but also in other encryption algorithms.

In a Feistel network, each step of encryption is called a **round**, and the entire encryption process consists of several repeated rounds. DES is a Feistel network with 16 rounds.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_6.png'>
</p>

The figure above shows the process of encrypting 64 bits of plaintext at a time. The key used for each encryption step is different. Because it is used only in the current round and is a local key, it is also called a subkey.

The operations in each round are as follows:

- Split the 64-bit input into left and right halves of 32 bits each.
- Let the 32 bits on the right side of the input fall directly down to the 32 bits on the right side of the output.
- Use the right side of the input as the input parameter to the round function.
- Based on the two input parameters—the 32 bits on the right side of the input and the subkey—the round function generates a bit sequence that appears random.
- XOR the output of the round function with the 32 bits on the left side of the input, and let the result fall down to the 32 bits on the left side of the output.

After one round, only half of the input data has been encrypted. In the example above, the right side has not been encrypted. We can use another subkey to encrypt the data on the right side.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_7.png'>
</p>

The figure above is a 3-round Feistel network. A 3-round network has 3 subkeys and 3 round functions, with 2 left-right swaps in between. **Note: an n-round Feistel network swaps only n-1 times; the final swap is not performed**.

### (2) Decryption

The DES decryption process is the reverse of the encryption process. Decryption is also performed in 64-bit blocks. The decryption key is also effectively 56 bits.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_5.png'>
</p>

Now let’s discuss the decryption process of the Feistel network.

Because XOR is commutative, performing the XOR operation again can restore the plaintext.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_8.png'>
</p>

From the figure above, we can see that **the encryption and decryption steps of a Feistel network are exactly the same**.

Again, take the decryption process of a 3-round Feistel network as an example.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_9.png'>
</p>

The decryption steps are exactly the same as the encryption steps, except that the subkeys are used in reverse order. This is because they must align with the previous encryption order. Suppose it is an n-round network with subkeys 1 through n. To restore the plaintext, the XOR order must be reversed so that `a ⊕ a = 0` and the associativity of XOR can be used to recover the plaintext.


### (3) Advantages

Characteristics of the Feistel network:

- During encryption, no matter what function is used as the round function, decryption can still be performed correctly, so there is no need to worry about being unable to decrypt. Even if the output of the round function cannot be inverted to compute the input, that is not a concern. The Feistel network encapsulates the core cryptographic essence of the encryption algorithm into this round function, allowing algorithm designers to focus all their effort on making the round function as complex as possible.
- Encryption and decryption can be implemented using exactly the same structure. Although only half of the plaintext is encrypted in each round, sacrificing encryption efficiency, the benefit is that the same structure can be used for both, which also makes the design of encryption hardware easier.

Because of these advantages of the Feistel network, many block ciphers have chosen it. Examples include AES candidate algorithms such as MARS, RC6, and Twofish. However, the Rijndael algorithm that was ultimately selected as AES did not choose it; instead, it chose an SPN network.


## IV. Symmetric Encryption Algorithm 3DES


Triple DES (triple-DES) is an algorithm obtained by applying DES three times in order to increase the strength of DES. It is also called TDEA (Triple Data Encryption Algorithm), usually abbreviated as 3DES.

### (1) Encryption

3DES encryption means performing DES encryption three times. The DES key length is 56 bits, so the 3DES key length is 56 * 3 = 168 bits.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_10.png'>
</p>

However, 3DES has a “strange” aspect: it does not encrypt with DES three times, but instead performs encryption-decryption-encryption, with a decryption step in the middle. IBM designed it this way so that triple DES would be compatible with ordinary DES. If the keys used in the three operations are all exactly the same, then it degenerates into ordinary DES. (One encryption and one decryption cancel each other out.) Therefore, it provides backward compatibility.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_11.png'>
</p>

- If the same key is used all 3 times, it degenerates into DES.
- If the first and third operations use the same key, and the second uses a different key, this type of triple DES is called DES-EDE2. EDE is short for Encryption -> Decryption -> Encryption.
- If all 3 operations use different keys, it is called DES-EDE3.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_12.png'>
</p>

### (II) Decryption

The 3DES decryption process is exactly the reverse of encryption: decrypt using the keys in reverse order.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_13.png'>
</p>

### (III) Drawbacks

Because 3DES is not very fast, it is now rarely used except for compatibility with legacy DES.

## V. Symmetric Encryption Algorithms: AES and Rijndael

AES (Advanced Encryption Standard) is a symmetric cipher algorithm that replaced the previous standard, DES, as the new standard. AES algorithms were solicited worldwide, and in 2000 the Rijndael algorithm was ultimately selected from the candidates and designated as the new AES.

The AES selection process began in 1997. In 1998, 15 algorithms met the requirements and entered the final evaluation: CAST-256, Crypton, DEAL, DFC, E2, Frog, HPC, LOK197, Magenta, MARS, RC6, Rijndael, SAFER+, Serpent, and Twofish. On October 2, 2000, Rijndael was designated as the AES standard. AES can be used free of charge.

Rijndael’s block length and key length can each be selected in 32-bit increments within the range from 128 bits to 256 bits. However, in the AES specification, the block length is fixed at 128 bits, and the key length can only be one of 128, 192, or 256 bits.

### (I) Encryption

AES encryption is also composed of multiple rounds. Each round consists of 4 steps: SubBytes, ShiftRows, MixColumns, and AddRoundKey; that is, an SPN network.

#### 1. SubBytes Byte Substitution

Rijndael’s default input block is 128 bits, or 16 bytes. The first step is to apply SubBytes to each byte. Using the value of each byte (any value from 0 to 255) as an index, the corresponding value is looked up in a substitution table with 256 values, the S-Box, and used for the transformation.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_14.png'>
</p>

After the SubBytes transformation, the 16 bytes (128 bits) on the left are transformed into the 16 bytes on the right.

#### 2. ShiftRows Row Shifting

This step performs a left shift on rows, with each row consisting of 4 bytes, and each row is shifted by a different number of bytes.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_15.png'>
</p>

After the shift, every row is “offset.”

#### 3. MixColumns Column Mixing

This step performs matrix operations on columns, with each column consisting of 4 bytes.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_16.png'>
</p>

After this transformation, each column differs from its previous value.

#### 4. AddRoundKey XOR Operation

XOR the output of the previous step with the round key; that is, perform AddRoundKey.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_17.png'>
</p>

As shown above, each of the 16 bytes on the left is XORed with the byte at the corresponding position in the round key. After the computation is complete, the final ciphertext is obtained.

At this point, one round of Rijndael is complete.

A complete round of decryption is shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_21.png'>
</p>


In general, the full algorithm performs 10 to 14 rounds of computation.

### (II) Decryption

The Rijndael decryption process is the inverse of encryption.

In the Rijndael encryption process, the order of operations in each round is:

SubBytes -> ShiftRows -> MixColumns -> AddRoundKey

In the Rijndael decryption process, the order of operations in each round is:

AddRoundKey -> InvMixColumns -> InvShiftRows -> InvSubBytes 

During decryption, except for the first step, which is exactly the same as in encryption, the other three steps are the inverse operations of encryption.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_17.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_18.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_19.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_20.png'>
</p>

### (III) Advantages

Compared with a Feistel network, an SPN network is more efficient for encryption because one SPN round encrypts all bits. Therefore, fewer rounds are required for encryption.

Another advantage is that the four encryption steps can be computed in parallel.

There is currently no effective attack that can break AES.

## VI. Block Cipher Modes

Because DES and AES can encrypt only a fixed-length plaintext at a time, if you need to encrypt plaintext of arbitrary length, you must iterate the block cipher. The way a block cipher is iterated is called a block cipher “mode.”

There are many block cipher modes. If the mode is chosen improperly, confidentiality cannot be adequately guaranteed.

A **block cipher** is a type of cipher algorithm that can process only one block of data of a specific length at a time; this “block” is called a block. The number of bits in a block is called the block length. For example, the block length of both DES and 3DES is 64 bits. The block length of AES is 128 bits. After a block cipher processes one block, it is done and does not need to record any additional state.

A **stream cipher** is a type of cipher algorithm that continuously processes a data stream. Stream ciphers generally encrypt and decrypt in units such as 1 bit, 8 bits, or 32 bits. For example, the one-time pad is a stream cipher. After a stream cipher processes a sequence of data, it still needs to maintain internal state.

|Stream cipher algorithm|Key length|Description|
|:---:|:---:|:---:|
|One-time pad|Same length as the plaintext|Impossible to break|
|RC4|Variable key length; recommended length 2048 bits|Has now been proven no longer secure|
|ChaCha|Variable key length; recommended length 256 bits|A modern stream cipher algorithm|


Taking the RC4 stream cipher algorithm as an example, the key point is that the algorithm internally generates a pseudorandom keystream. The keystream has the following properties:

- The length of the keystream is the same as the key length
- The keystream is a pseudorandom number and is unpredictable
- Generating a pseudorandom number requires a seed. The seed is the key of the RC4 algorithm. Based on the same key (or seed), the encryptor and decryptor can obtain the same keystream.

Once the keystream is available, encryption and decryption are easy: just perform XOR operations.

>A stream cipher algorithm is called a stream cipher algorithm because each XOR operation continuously operates on a data stream. The amount of data processed each time is generally one byte. Stream cipher algorithms can process data in parallel and are very fast. However, RC4 has now been proven insecure. It is recommended to use block ciphers.

### 1. ECB Mode

ECB mode is the simplest block cipher mode, and also the least secure. Therefore, very few people use it.

ECB stands for “Electronic CodeBook” mode. In ECB mode, the result of encrypting a plaintext block is directly the ciphertext block, without any intermediate transformation.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_22.png'>
</p>

ECB encryption and decryption are both very straightforward. Based on how many repeated combinations exist in the ciphertext, the plaintext can be inferred and the cipher can be broken. Therefore, ECB mode has security risks.

#### Attacks Against ECB

There are many types of attacks against ECB. The simplest is to swap the positions of blocks. For example, suppose plaintext blocks 1 and 2 represent the messages payer A and payee B, while block 3 records the transfer amount. An attacker can reverse the order of blocks 1 and 2, completely reversing the meaning of the message. The attack succeeds.

### 2. CBC Mode

CBC stands for Cipher Block Chaining mode. Its name also reveals its essence: the blocks are linked together like a chain.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_23.png'>
</p>

The CBC encryption “chain” starts with an initialization vector, IV. This initialization vector IV is a random bit sequence.

If we isolate a single block of ECB encryption and compare it with CBC block encryption, it looks like this:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_24.png'>
</p>

ECB mode only performs encryption, whereas CBC mode performs an XOR before encryption. This perfectly overcomes ECB’s drawback. For example, if ciphertext block 1 and ciphertext block 2 are the same, then after ECB encryption the two ciphertext blocks are also the same. But after CBC encryption, there will not be two identical ciphertext blocks, because of the XOR step.

CBC encryption must start from the head of the “chain,” so no block in the middle can independently generate its ciphertext.

During CBC decryption, what happens if a link in the middle of the decryption “chain” is “broken”?


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_25.png'>
</p>

During CBC decryption, if one link has a problem, such as a disk error, but the overall chain length does not change, as shown above, then one bad link affects the decryption of 2 blocks.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_26.png'>
</p>

If the chain length also changes, or if 1 bit in some block is lost during network transmission, then the affected decrypted blocks may be more than just 2 blocks. This is because it causes the entire chain to be re-blocked, making the original plaintext impossible to decrypt (because the number of bits is less than the block requirement; during decryption, the missing bits at the end of the final block are not padded).

**This can be considered a “minor drawback” of CBC chaining**. The loss of a single bit can make the entire ciphertext impossible to parse.

#### Attacks Against CBC

Because CBC is chained, an attacker can consider attacking from the “head,” that is, attacking the initialization vector IV—for example, flipping certain bits in the initialization vector between 0 and 1. In that case, when the message recipient decrypts the message, plaintext block 1 will be affected by the initialization vector and become incorrect.

Another attack method is to attack the ciphertext directly. For example, if some ciphertext block n is modified, it will affect the decryption of plaintext block n+1.

>Block ciphers also have a mode called CTS mode (Cipher Text Stealing mode). In a block cipher, when the plaintext length is not divisible by the block length, the final block needs to be padded. CTS mode uses data from the ciphertext block preceding the final block for padding, and it is usually used together with ECB mode and CBC mode. Depending on the transmission order of the final block, CTS mode has several variants (CBC-CS1, CBC-CS2, CBC-CS3). The following is an example of CBC-CS3:
>
>
><p align='center'>
><img src='https://img.halfrost.com/Blog/ArticleImage/98_27.png'>
></p>

### 3. CFB Mode

CFB stands for Cipher FeedBack mode (ciphertext feedback mode). In CFB mode, the previous ciphertext block is fed into the input of the cipher algorithm. “Feedback” here means feeding the output back into the input.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_28.png'>
</p>

**Note that in the decryption process shown above, the operation in the middle is encryption, not decryption**! This is because the value XORed with the plaintext and ciphertext must remain unchanged. Only if it remains unchanged can XORing twice recover the plaintext.

If we extract the encryption of a single CBC block and compare it with a CFB block, it looks like this:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_29.png'>
</p>

As we can see from the figure above, in ECB and CBC modes, plaintext blocks are processed by the encryption algorithm. In CFB mode, however, plaintext blocks are not directly encrypted by the encryption algorithm. In CFB mode, the plaintext is XORed with a bit sequence to produce the ciphertext block.

#### CFB and Stream Ciphers

The overall CFB process is very similar to a one-time pad. If all the encryption steps before the plaintext block are regarded as producing a random bit sequence, then the process is the same as a one-time pad. This algorithm-generated bit sequence is called a **key stream**. In CFB mode, the cipher algorithm is essentially a pseudorandom number generator used to generate the key stream, and the initialization vector is equivalent to the seed of that pseudorandom number generator. Because it is pseudorandom, CFB does not have the one-time pad’s property of being absolutely unbreakable. Therefore, **CFB is one way to implement a stream cipher using a block cipher**.

#### Attacks on CFB

CFB is vulnerable to a **replay attack**.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_30.png'>
</p>

For example, an attacker can take some blocks from a previous session and insert them at a random position in the next session. After the message recipient receives the ciphertext and decrypts it, one of the blocks will be incorrect (in the figure above, plaintext block 2 fails to decrypt). At that point, it is impossible to determine whether this was caused by a communication error or by an attack. (To make that determination, a message authentication code is required; here we are considering only plain CFB.)

### 4. OFB Mode

OFB stands for Output-FeedBack mode (output feedback mode). In OFB mode, the output of the cipher algorithm is fed back into the input of the cipher algorithm. This is analogous to CFB mode.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_31.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_32.png'>
</p>

OFB also does not encrypt the plaintext directly; instead, it obtains the ciphertext by XORing the plaintext with a bit sequence.

Likewise, note that **during OFB decryption, encryption is used, not decryption**. The reason is the same as for CFB: XOR can recover the plaintext only when applied with the same value.

#### Comparing OFB and CFB

The only difference between OFB mode and CFB mode is the input to the cipher algorithm. In OFB mode, the input to the cipher algorithm is the previous output of the cipher algorithm, so it is called output feedback mode. In CFB mode, the previous ciphertext block is input into the cipher algorithm, so it is called input feedback mode. The following figure compares the two:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_33.png'>
</p>

As we can see from the figure above, the encryption process in CFB mode cannot skip a block and continue encrypting subsequent blocks. It must encrypt in order, because ciphertext blocks are fed back into the encryption algorithm.

CFB mode is different: the encryption algorithm and the ciphertext blocks are completely separate. In other words, as long as the key stream required for each XOR operation has been generated, any block can be encrypted “out of order.” From this perspective, the operation of generating the key stream and the operation of performing XOR can be parallelized.


### 5. CTR Mode

CTR stands for CounTeR mode (counter mode). CTR mode is a stream cipher mode that generates a key stream by encrypting a counter that is incremented each time.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_34.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_35.png'>
</p>

**Note that in the decryption process shown above, the operation in the middle is encryption, not decryption**! This is because the value XORed with the plaintext and ciphertext must remain unchanged. Only if it remains unchanged can XORing twice recover the plaintext.

The counter generates a different nonce each time as the counter’s initial value, ensuring that the value is different each time. This method uses a block cipher to simulate the generation of a random bit sequence.

#### Comparing OFB and CTR

CTR mode and OFB mode are both stream cipher modes. If we look only at their encryption processes, the difference lies in the value input into the encryption algorithm. In CTR mode, the input value is the incremented counter value, while in OFB mode, the input value is the previous output value.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_36.png'>
</p>

CTR mode uses exactly the same structure for encryption and decryption, which makes implementation much more convenient. Furthermore, because the keys in CTR mode have an incremental relationship, this relationship can be used to encrypt and decrypt any block. Once the initial key is determined, every subsequent key is determined as well. From this perspective, CTR also supports parallel computation.

#### Attacks on CTR

In terms of attacks, CTR is similar to OFB. If one bit in a CTR-mode ciphertext block is flipped, then after decryption, only the corresponding bit in the plaintext block will be flipped; the error does not propagate.

However, CTR mode has one advantage over OFB mode: in OFB mode, if encrypting a block of the key stream produces the same result as the previous one, then every subsequent key stream block after that will remain unchanged. CTR mode does not have this problem.

>For CTR mode, adding authentication on top of it yields GCM mode (Galois/Counter Mode). This mode can generate authentication information while CTR mode generates ciphertext, allowing us to determine “whether the ciphertext was generated through a legitimate encryption process.” With this mechanism, even if an active attacker sends forged ciphertext, we can recognize that “this ciphertext is forged.”


### 6. Summary

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_37.png'>
</p>


|Mode|Name|Characteristics|Notes|
|-----|-----|-----|-----|
|ECB mode|Electronic Codebook|Fast computation, supports parallel computation, requires padding|Not recommended|
|CBC mode|Cipher Block Chaining|Supports parallel computation, requires padding|Recommended|
|CFB mode|Cipher Feedback|Supports parallel computation, does not require padding|Not recommended|
|OFB mode|Output Feedback|Uses a stream cipher mode with iterative computation, does not require padding|Not recommended|
|CTR mode|Counter|Uses a stream cipher mode with iterative computation, supports parallel computation, does not require padding|Recommended|
|XTS mode|XEX-based tweaked-codebook|Does not require padding|Used in local hard disk storage solutions|


## VII. OpenSSL Encryption

### 1. Specify the Key and Initialization Vector
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -K 12345678901234567890 -iv 12345678
```
Encrypt the contents of the in.txt file and write the output to out.txt. Here, `-K` specifies the key, and `-iv` specifies the initialization vector. Note that both the key and initialization vector for the AES algorithm are 128 bits. The arguments following `-K` and `-iv` are represented in hexadecimal, with a maximum length of 32. That is, the initialization vector specified by `-iv` 1234567812345678 is stored in memory as | 12 34 56 78 12 34 56 78 00 00 00 00 00 00 00 00 |.

Use the `-d` option to indicate decryption, as follows:
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -K 12345678901234567890 -iv 12345678 -d
```
Indicates decrypting the encrypted in.txt and writing the output to out.txt

### 2. Encrypt/Decrypt with a String Password
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -pass pass:helloworld
```
At this point, the program generates the key and initialization vector from the string "helloworld" and a randomly generated salt. You can also use `-nosalt` to omit the salt.


## VIII. Performance

- RC4 is the stream-cipher symmetric encryption algorithm with the best computational performance.
- If AES can use the AES-NI instruction set, its performance is also quite good. The other encryption algorithms are rarely used in HTTPS and perform poorly.
- It is generally believed that AES-128-GCM performs better than AES-128-CBC.
- ChaCha20-poly1305 performs even better than AES-128-GCM. In most cases, mobile devices are considered better suited to the ChaCha20-poly1305 algorithm.

**Use ChaCha20-poly1305 on mobile devices, and AES-128-GCM on computers**.


------------------------------------------------------

References：
  
*Cryptography by Illustration*      


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/symmetric\_encryption/](https://halfrost.com/symmetric_encryption/)