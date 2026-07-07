# A Tour of Symmetric Encryption Algorithms


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_0.png'>
</p>


## 1. Introduction

Before introducing symmetric encryption, it is useful to first cover a bitwise operation: XOR. XOR stands for “exclusive or.”
```c
0 XOR 0 = 0
0 XOR 1 = 1
1 XOR 0 = 1
1 XOR 1 = 0
```
XOR can be understood as: “if two numbers are the same, their XOR is 0; if they are different, their XOR is 1.”

XOR is also called half-addition. Its operation rules are equivalent to binary addition without carry: in binary, 1 represents true and 0 represents false, so the rules for XOR are:
```c
0 ⊕ 0 = 0
1 ⊕ 0 = 1
0 ⊕ 1 = 1
1 ⊕ 1 = 0
```
These rules are the same as addition, except without carrying, so XOR is often regarded as carry-less addition. This property of XOR also leads to one of its commonly used characteristics: **the result of XORing two identical numbers is always 0**.

Correspondingly, we can also derive the following operational rules:
```c
1. a ⊕ a = 0
2. a ⊕ b = b ⊕ a commutative law
3. a ⊕ b ⊕ c = a ⊕ (b ⊕ c) = (a ⊕ b) ⊕ c  associative law
4. d = a ⊕ b ⊕ c can derive a = d ⊕ b ⊕ c
5. a ⊕ b ⊕ a = b
```
I won’t elaborate on the derivation of the above laws; I believe readers can understand them.

The associativity of XOR can be used to implement simple symmetric encryption.

Imagine setting the XOR operand to a completely random binary sequence. After the value being XORed is XORed with it once, the result is like “ciphertext.” If an eavesdropper does not know what the XOR operand is, it is very difficult to recover the original message in a short time.
```c
a ⊕ b ⊕ b = a ⊕ (b ⊕ b) = a ⊕ 0 = a
```
After receiving the ciphertext, the recipient XORs the ciphertext with the XOR value again to recover the original plaintext. This property is the associativity of XOR.


## II. One-Time Pad

As long as you can brute-force it by enumerating the key space, any ciphertext will eventually be decrypted someday. It is only a matter of how large the key space is and how much time it takes. However, there is one encryption method that has been proven to be unbreakable forever—even if you brute-force the entire key space, it still cannot be cracked.

When I first encountered this encryption method, I found it almost magical. Such a powerful encryption method must have a very complex encryption process, and its mathematical proof must be extremely rigorous, right? But after looking at its principle, I found that this was not the case. The one-time pad encryption method is very simple: it uses only the XOR operation mentioned in the previous section.


### (1) Encryption

For one-time pad encryption, consider an example where the plaintext to encrypt is midnight.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_1_.png'>
</p>

The key is a random binary stream. The encryption process of a one-time pad is to XOR the plaintext with the key.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_2.png'>
</p>


### (2) Decryption

The decryption process of a one-time pad is to XOR the ciphertext with the key, yielding the original plaintext.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_3.png'>
</p>

After seeing this encryption and decryption process, readers will certainly question that this method should be easy to crack: brute-force the key space of a 64-bit random binary stream, and you should eventually be able to determine the plaintext.

Now we can reveal the answer. It is indeed possible to traverse the entire key space by brute force. Suppose there were a super quantum computer that could enumerate a key space as large as 2^64^ in one second; it still would not be able to break a one-time pad. Its “magic” lies in the fact that, during repeated attempts, you will obtain many possible results—for example, plaintexts such as abcdefg, aaaaa, plus, and mine—but you cannot determine whether you have decrypted it correctly. This is why a one-time pad cannot be broken, and it has nothing to do with the size of the key space.

The unbreakability of the one-time pad was proven mathematically by C.E. Shannon in 1949. The one-time pad is **unconditionally secure and theoretically unbreakable**.

### (3) Disadvantages

Although the one-time pad is so powerful, in practice no one uses it for encryption. The reasons are as follows:

#### 1. How do you send the key to the other party?

In a one-time pad, the key is the same length as the original plaintext. Imagine that you have a way to securely deliver the ciphertext to the other party—could you not also use the same method to deliver the plaintext to the other party? So this is a contradiction.

#### 2. Key storage is a problem

The key in a one-time pad is as long as the plaintext. The key cannot be deleted or discarded. Discarding the key is equivalent to discarding the plaintext. Therefore, the problem of “encrypting to protect the plaintext” is transformed into the problem of “how to securely protect a key that is as long as the plaintext.” In practice, the problem has not really been solved.


#### 3. Keys cannot be reused

If the plaintext to encrypt is very long, then the key must be the same length, and the key must be different every time. Otherwise, if the same key is reused, once the key is leaked, all past plaintexts encrypted with that key will be decrypted.


#### 4. Key synchronization is difficult

If the key changes every time, then synchronizing the key is also a problem. There must not be any misalignment during key transmission; if there is, every bit after the point of misalignment can no longer be decrypted.

#### 5. Key generation is difficult

For a one-time pad to truly remain unbreakable forever, it must generate a large number of truly random numbers, not pseudorandom numbers generated by a computer.


It is said that hotlines between countries use one-time pads. But how do they avoid the five disadvantages listed above? Countries send dedicated agents to physically escort the keys and deliver them directly into the other party’s hands.

As you can see, although the one-time pad cannot be broken, the “cost” of using it for encryption is extremely high. Therefore, the one-time pad has essentially no practical value in everyday use. However, the idea behind the one-time pad gave rise to **stream ciphers**. Stream ciphers do not use truly random bit sequences; instead, they use binary bit sequences produced by pseudorandom number generators. Although stream ciphers are not unbreakable, using a high-performance pseudorandom number generator can still build a strong cryptosystem. Stream ciphers will be analyzed in detail in a later section.

## III. Symmetric Encryption Algorithm DES

DES (Data Encryption Standard) is a symmetric cipher adopted in the U.S. Federal Information Processing Standards (FIPS) in 1977 (FIPS 46-3). DES has long been used by the U.S. government, other governments, and banks.

In the 1997 DES Challenge I, the DES key was cracked in 96 days. In the 1998 DES Challenge II-1, the key was cracked in only 41 days. In the 1998 DES Challenge II-2, it took 56 hours, and in the 1999 DES Challenge III, it took only 22 hours and 15 minutes. Today, DES is no longer secure. Apart from decrypting old DES ciphertexts from the past, DES is no longer used for encryption.


### (1) Encryption

DES is a symmetric encryption algorithm that encrypts 64-bit plaintext into 64-bit ciphertext. Its key length is 64 bits, but because one bit is set aside for error detection every 7 binary bits, the effective key length is actually 56 bits. DES encrypts data in **blocks** of 64 bits. A cipher algorithm that processes data block by block is called a **block cipher**, and DES is one type of block cipher.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_4_.png'>
</p>

DES can encrypt only 64 bits of plaintext at a time. If the plaintext exceeds 64 bits, it must be encrypted in blocks. This repeated iteration is called a **mode**. A more detailed discussion of modes appears in the next section.

The basic structure of DES encryption is the **Feistel network, Feistel structure, or Feistel cipher**. This structure is used not only in DES, but also in other encryption algorithms.

In a Feistel network, each step of encryption is called a **round**, and the overall encryption process consists of multiple rounds. DES is a 16-round Feistel network.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_6.png'>
</p>

The figure above shows the process of encrypting 64 bits of plaintext at a time. The key used in each encryption step is different. Since it is used only in the current round and is a local key, it is also called a subkey.

The operations in each round are as follows:

- Split the 64-bit input into left and right halves of 32 bits each.
- Pass the 32 bits on the right side of the input directly down to the 32 bits on the right side of the output.
- Feed the right side of the input as an argument to the round function.
- The round function takes the 32 bits from the right side of the input and the subkey as two arguments, and produces a seemingly random bit sequence as output.
- XOR the output of the round function with the 32 bits on the left side of the input, and pass the result down to the 32 bits on the left side of the output.

After one round, only half of the input data has been encrypted. In the example above, the right side has not been encrypted. We can use another subkey to encrypt the data on the right side.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_7.png'>
</p>

The figure above is a 3-round Feistel network. A 3-round network has 3 subkeys and 3 round functions, with 2 left-right swaps in between. **Note: an n-round Feistel network swaps only n-1 times; the final swap is not performed**.

### (2) Decryption

The DES decryption process is the reverse of the encryption process. Decryption also operates on 64-bit blocks. The effective decryption key is also 56 bits.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_5.png'>
</p>

Now let’s discuss the decryption process of a Feistel network.

Because XOR has the commutative property, performing XOR again restores the plaintext.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_8.png'>
</p>

From the figure above, we can see that **the encryption and decryption steps of a Feistel network are exactly the same**.

Similarly, let’s use the decryption process of a 3-round Feistel network as an example.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_9.png'>
</p>

The decryption steps are exactly the same as the encryption steps, except that the subkeys are used in reverse order. This is because they must align with the previous encryption order. Suppose it is an n-round network with subkeys 1 through n. To restore the plaintext, the order of XOR operations must be reversed, so that `a ⊕ a = 0` and the associativity of XOR can be used to recover the plaintext.


### (3) Advantages

Characteristics of Feistel networks:

- During encryption, no matter what function is used as the round function, decryption can be performed correctly, so there is no need to worry about being unable to decrypt. Even if the output of the round function cannot be inverted to recover the input, that is not a problem. A Feistel network encapsulates the core cryptographic essence of the encryption algorithm into this round function, allowing the algorithm designer to focus entirely on making the round function as complex as possible.
- Encryption and decryption can be implemented using exactly the same structure. Although each round encrypts only half of the plaintext, sacrificing encryption efficiency, it gains the ability to use the same structure, which also makes the design of encryption hardware devices easier.

Because of these advantages of Feistel networks, many block ciphers have chosen this structure. Examples include AES candidate algorithms such as MARS, RC6, and Twofish. However, the Rijndael algorithm that was ultimately selected as AES did not choose it; instead, it chose an SPN network.


## IV. Symmetric Encryption Algorithm 3DES


Triple DES (triple-DES) is an algorithm obtained by applying DES three times in order to increase the strength of DES. It is also called TDEA (Triple Data Encryption Algorithm), commonly abbreviated as 3DES.

### (1) Encryption

3DES encryption consists of three DES operations. Since the DES key length is 56 bits, the 3DES key length is 56 * 3 = 168 bits.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_10.png'>
</p>

However, 3DES has a “strange” aspect: it does not perform DES encryption three times. Instead, it performs encryption-decryption-encryption, with one decryption step in the middle. IBM designed it this way so that triple DES would be compatible with ordinary DES. If all keys in the triple operation are exactly the same, it degenerates into ordinary DES. (One encryption and one decryption cancel each other out.) Therefore, it provides backward compatibility.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_11.png'>
</p>

- If the same key is used all three times, it degenerates into DES.
- If the first and third operations use the same key, and the second operation uses a different key, this form of triple DES is called DES-EDE2. EDE stands for Encryption -> Decryption -> Encryption.
- If all three operations use different keys, it is called DES-EDE3.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_12.png'>
</p>

### (2) Decryption

The 3DES decryption process is exactly the reverse of the encryption process, decrypting with the keys in reverse order.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_13.png'>
</p>

### (3) Disadvantages

Because 3DES is not fast, apart from compatibility with previous DES systems, it is basically no longer used today.

## V. Symmetric Encryption Algorithm AES and Rijndael

AES (Advanced Encryption Standard) is a symmetric cipher algorithm that replaced the previous standard, DES, and became the new standard. AES encryption algorithms were solicited worldwide, and in 2000 the Rijndael algorithm was selected from the candidates and designated as the new AES.

The AES solicitation began in 1997. In 1998, 15 algorithms met the requirements and ultimately entered evaluation: CAST-256, Crypton, DEAL, DFC, E2, Frog, HPC, LOK197, Magenta, MARS, RC6, Rijndael, SAFER+, Serpent, and Twofish. On October 2, 2000, Rijndael was designated as the AES standard. AES can be used free of charge.

The block length and key length of Rijndael can each be selected in 32-bit increments within the range from 128 bits to 256 bits. However, in the AES specification, the block length is fixed at 128 bits, and the key length has only three options: 128, 192, and 256 bits.

### (1) Encryption

AES encryption is also composed of multiple rounds, consisting of four steps: SubBytes, ShiftRows, MixColumns, and AddRoundKey. This is an SPN network.

#### 1. SubBytes byte transformation

Rijndael’s input block defaults to 128 bits, which is 16 bytes. The first step is to perform SubBytes processing on each byte. Using each byte’s value (any value between 0 and 255) as an index, the corresponding value is looked up in a substitution table with 256 values, the S-Box, and used for processing.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_14.png'>
</p>

After the SubBytes transformation, the 16 bytes on the left (128 bits) are transformed into the 16 bytes on the right.

#### 2. ShiftRows row-shifting operation

This step performs a left shift on rows, with each row treated as a 4-byte unit, and each row shifted by a different number of bytes.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_15.png'>
</p>

After the shift, every row is “offset.”

#### 3. MixColumns column-mixing operation

This step performs matrix operations on columns, with each column treated as a 4-byte unit.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_16.png'>
</p>

After this transformation, every column is different from the previous column.

#### 4. AddRoundKey XOR operation

The output of the previous step is XORed with the round key; that is, AddRoundKey processing is performed.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_17.png'>
</p>

As shown above, each of the 16 bytes on the left is XORed with the byte at the corresponding position in the round key. After the computation is complete, the final ciphertext is obtained.

At this point, one round of Rijndael is complete.

A complete round of decryption is shown below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_21.png'>
</p>


In general, the entire algorithm performs 10–14 rounds of computation.

### (2) Decryption

Rijndael decryption is the inverse process of encryption.

During Rijndael encryption, the processing order in each round is:

SubBytes -> ShiftRows -> MixColumns -> AddRoundKey

During Rijndael decryption, the processing order in each round is:

AddRoundKey -> InvMixColumns -> InvShiftRows -> InvSubBytes 

During decryption, aside from the first step, which is exactly the same as encryption, the other three steps are the inverse processes of encryption.

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

### (3) Advantages

Compared with a Feistel network, an SPN network has higher encryption efficiency because one SPN round encrypts all bits. Therefore, fewer rounds are required for encryption.

Another advantage is that the four encryption steps can be computed in parallel.

At present, there is no effective attack that can break AES.

## VI. Block Modes

Because DES and AES can encrypt only fixed-length plaintext in a single encryption operation, encrypting plaintext of arbitrary length requires iterating a block cipher, and the iteration method of a block cipher is called a block cipher “mode.”

Block ciphers have many modes. If the selected mode is inappropriate, confidentiality cannot be sufficiently guaranteed.

A **block cipher** is a class of cipher algorithms that can process only a block of data of a specific length at a time; this “block” is called a block. The number of bits in a block is called the block length. For example, the block length of DES and 3DES is 64 bits. The block length of AES is 128 bits. After a block cipher finishes processing one block, it terminates and does not need to record additional state.

A **stream cipher** is a class of cipher algorithms that continuously processes a data stream. Stream ciphers generally encrypt and decrypt in units such as 1 bit, 8 bits, or 32 bits. For example, the one-time pad is a stream cipher. After a stream cipher finishes processing a sequence of data, it still needs to maintain internal state.

|Stream cipher algorithm|Key length|Description|
|:---:|:---:|:---:|
|One-time pad|Same length as the plaintext|Unbreakable forever|
|RC4|Variable key length; recommended length: 2048 bits|Has now been proven no longer secure|
|ChaCha|Variable key length; recommended length: 256 bits|A newer stream cipher algorithm|

Taking the RC4 stream cipher algorithm as an example, the key point is that the algorithm internally generates a pseudorandom keystream. The keystream has the following characteristics:

- The length of the keystream is the same as the key length
- The keystream is a pseudorandom number sequence and is unpredictable
- Generating pseudorandom numbers requires a seed. The seed is the key of the RC4 algorithm. Based on the same key (or seed), the encryptor and decryptor can obtain the same keystream.

With the keystream, encryption and decryption become easy: they are just XOR operations.

>A stream cipher algorithm is called a stream cipher because, during each XOR operation, it continuously operates on a data stream. The size of the data stream processed each time is generally one byte. Stream cipher algorithms can be processed in parallel and are very fast. However, RC4 has now been proven insecure. Using a block cipher is recommended.

### 1. ECB Mode

ECB mode is the simplest block cipher mode, and also the least secure. As a result, it is rarely used.

ECB stands for “Electronic CodeBook”. In ECB mode, the result of encrypting a plaintext block is directly the ciphertext block, with no additional transformation in between.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_22.png'>
</p>

Encryption and decryption in ECB are both very straightforward. Because repeated patterns in the ciphertext can be used to infer the corresponding plaintext, the cipher can be broken. Therefore, ECB mode has security risks.

#### Attacks on ECB

There are many types of attacks against ECB. One of the simplest is to swap the positions of blocks. For example, suppose plaintext blocks 1 and 2 represent the messages payer A and payee B, and block 3 records the transfer amount. An attacker can reverse the order of blocks 1 and 2, completely reversing the meaning of the message. The attack succeeds.

### 2. CBC Mode

CBC stands for Cipher Block Chaining. The name also reveals its essence: blocks are linked together like a chain.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_23.png'>
</p>

The CBC encryption “chain” starts with an initialization vector, IV, which is a random bit sequence.

If we extract a single-block ECB encryption and compare it with CBC block processing, it looks like this:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_24.png'>
</p>

ECB mode only performs encryption, whereas CBC mode performs an XOR before encryption. This perfectly overcomes ECB’s weakness. For example, if ciphertext block 1 and ciphertext block 2 are the same, then after ECB encryption the two ciphertext blocks are still the same. But after CBC encryption, two identical ciphertext blocks will not occur, because of the XOR step.

CBC encryption must start from the head of the “chain”, so no block in the middle can independently generate its ciphertext.

During CBC decryption, what happens if one link in the middle of the decryption “chain” is “broken”?


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_25.png'>
</p>

If a link has a problem during CBC decryption—for example, due to a disk issue—but the total chain length remains unchanged, as shown above, then one bad link affects the decryption of two blocks.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_26.png'>
</p>

If the chain length also changes, or if one bit in a block is lost during network transmission, then more than two decrypted blocks may be affected. This is because the entire chain will be regrouped, making the original text impossible to decrypt (because the number of bits is less than what the block size requires, and decryption will not pad missing bits at the end block).

**This can be considered a “minor drawback” of CBC’s chaining behavior**. The loss of a single bit can make the entire ciphertext impossible to parse.

#### Attacks on CBC

Because CBC is chained, an attacker can consider attacking from the “head”, that is, attacking the initialization vector IV. For example, they can flip certain bits in the initialization vector between 0 and 1. In that case, when the recipient decrypts the message, plaintext block 1 will be affected by the initialization vector and become incorrect.

Another attack method is to directly attack the ciphertext. For example, if ciphertext block n is modified, it will affect the decryption of plaintext block n+1.

>There is another mode for block ciphers called CTS mode (Cipher Text Stealing mode). In block ciphers, when the plaintext length is not divisible by the block length, the final block needs to be padded. CTS mode uses data from the ciphertext block preceding the final block for padding. It is usually used together with ECB mode and CBC mode. Depending on the transmission order of the final block, CTS mode has several variants (CBC-CS1, CBC-CS2, CBC-CS3). The following is an example of CBC-CS3:
>
>
><p align='center'>
><img src='https://img.halfrost.com/Blog/ArticleImage/98_27.png'>
></p>


### 3. CFB Mode

CFB stands for Cipher FeedBack mode (ciphertext feedback mode). In CFB mode, the previous ciphertext block is fed into the input of the cipher algorithm. “Feedback” here means returning to the input.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_28.png'>
</p>

**Note that in the decryption process in the figure above, the middle operation is encryption, not decryption**! This is because the value XORed with the plaintext and ciphertext must remain unchanged. Only if it remains unchanged can XORing twice recover the plaintext.

If we extract a single-block CBC encryption and compare it with CFB block processing, it looks like this:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_29.png'>
</p>

From the figure above, we can see that in ECB and CBC modes, plaintext blocks are processed by the encryption algorithm, but in CFB mode plaintext blocks are not directly encrypted by the encryption algorithm. In CFB mode, the plaintext becomes a ciphertext block after being XORed with a bit sequence.

#### CFB and Stream Ciphers

The overall CFB process is very similar to a one-time pad. If the entire encryption portion before the plaintext block is viewed as a random bit sequence, then the process is the same as a one-time pad. This bit sequence generated by the algorithm is called the **keystream**. In CFB mode, the cipher algorithm is equivalent to a pseudorandom number generator used to generate the keystream, and the initialization vector is equivalent to the seed of that pseudorandom number generator. Because it is pseudorandom, CFB does not have the one-time pad’s property of being absolutely unbreakable. Therefore, **CFB is one way to implement a stream cipher using a block cipher**.

#### Attacks on CFB

A **replay attack** can be performed against CFB.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_30.png'>
</p>

For example, an attacker can take some blocks from the previous session and insert them at a random position in the next session. When the recipient receives the ciphertext and decrypts it, one of the blocks will be incorrect (in the figure above, plaintext block 2 fails to decrypt). At that point, it is impossible to determine whether the problem was caused by a communication error or by an attack. (Determining that requires a message authentication code; here we are only considering plain CFB.)

### 4. OFB Mode

OFB stands for Output-FeedBack mode (output feedback mode). In OFB mode, the output of the cipher algorithm is fed back into the input of the cipher algorithm. This can be compared to CFB mode.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_31.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_32.png'>
</p>

OFB also does not directly encrypt the plaintext. Instead, it obtains the ciphertext by XORing the plaintext with a bit sequence.

Also note that **in OFB decryption, encryption is used as well, not decryption**. The reason is the same as for CFB: with XOR, only XORing with the same value can recover the plaintext.

#### Comparison Between OFB and CFB

The only difference between OFB mode and CFB mode is the input to the cipher algorithm. In OFB mode, the input to the cipher algorithm is the previous output of the cipher algorithm, so it is called output feedback mode. In CFB mode, the previous ciphertext block is input into the cipher algorithm, so it is called input feedback mode. The following figure compares the two:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_33.png'>
</p>

From the figure above, we can see that in CFB mode, the encryption process cannot skip a block and encrypt later blocks. It must encrypt in order, because the ciphertext block is fed back into the encryption algorithm.

OFB mode is different: the encryption algorithm and the ciphertext blocks are completely separate. In other words, as long as the keystream required for each XOR operation has been generated, any block can be encrypted “out of order”. From this perspective, keystream generation and XOR operations can be parallelized.


### 5. CTR Mode

CTR stands for CounTeR mode. CTR mode is a stream cipher mode that generates a keystream by encrypting a counter that is incremented successively.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_34.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_35.png'>
</p>

**Note that in the decryption process in the figure above, the middle operation is encryption, not decryption**! This is because the value XORed with the plaintext and ciphertext must remain unchanged. Only if it remains unchanged can XORing twice recover the plaintext.

Each time, the counter generates a different nonce as its initial value. This ensures that the value is different every time. This method uses a block cipher to simulate the generation of a random bit sequence.

#### Comparison Between OFB and CTR

CTR mode and OFB mode are both stream cipher modes. If we look only at their encryption processes, the difference is the value input into the encryption algorithm. In CTR mode, the input is the incremented counter value, while in OFB mode, the input is the previous output value.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_36.png'>
</p>

CTR mode uses exactly the same structure for encryption and decryption, which makes program implementation much easier. Furthermore, because each keystream block in CTR mode has an incremental relationship, any block can be encrypted or decrypted using that relationship. Once the initial key material is determined, every subsequent keystream block is determined. From this perspective, CTR also supports parallel computation.

#### Attacks on CTR

In terms of attacks, CTR is similar to OFB. If one bit in a CTR ciphertext block is flipped, then after decryption only the corresponding bit in the plaintext block will be flipped; the error will not propagate.

However, CTR mode has one advantage over OFB mode: in OFB mode, if the result generated after encrypting one keystream block is the same as the previous one, then every subsequent keystream block will remain unchanged. CTR mode does not have this problem.

>For CTR mode, adding authentication on top of it produces GCM mode (Galois/Counter Mode). This mode can generate authentication information while CTR mode generates the ciphertext, thereby determining whether “the ciphertext was generated through a legitimate encryption process”. Through this mechanism, even if an active attacker sends forged ciphertext, we can identify that “this ciphertext is forged”.


### 6. Summary

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_37.png'>
</p>

|Mode|Name|Characteristics|Notes|
|:---:|:---:|:---:|:---:|
|ECB mode|Electronic Codebook|Fast operations, supports parallel computation, requires padding|Not recommended|
|CBC mode|Cipher Block Chaining|Supports parallel computation, requires padding|Recommended|
|CFB mode|Cipher Feedback|Supports parallel computation, does not require padding|Not recommended|
|OFB mode|Output Feedback|Uses stream-cipher-style iterative operations, does not require padding|Not recommended|
|CTR mode|Counter|Uses stream-cipher-style iterative operations, supports parallel computation, does not require padding|Recommended|
|XTS mode|XEX-based tweaked-codebook|Does not require padding|Used in local disk storage solutions|


## 7. OpenSSL Symmetric Encryption

### 1. Specify the Key and Initialization Vector
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -K 12345678901234567890 -iv 12345678
```
Encrypt the contents of the in.txt file and write the output to out.txt. Here, `-K` specifies the key, and `-iv` specifies the initialization vector. Note that for this AES algorithm, both the key and initialization vector are 128 bits. The arguments following `-K` and `-iv` are hexadecimal strings, with a maximum length of 32. That is, the initialization vector specified by `-iv` 1234567812345678 is represented in memory as | 12 34 56 78 12 34 56 78 00 00 00 00 00 00 00 00 |.

Use the `-d` option to decrypt, as follows:
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -K 12345678901234567890 -iv 12345678 -d
```
This means decrypting the encrypted in.txt and writing the output to out.txt.

### 2. Encrypt/Decrypt with a String Password
```bash
$ openssl enc -aes-128-cbc -in in.txt -out out.txt -pass pass:helloworld
```
At this point, the program generates the key and initialization vector based on the string "helloworld" and a randomly generated salt. You can also use `-nosalt` to omit the salt.


## VIII. Performance

- RC4 is the stream-cipher symmetric encryption algorithm with the highest computational performance.
- If the AES algorithm can use the AES-NI instruction set, its performance is also quite good. The other encryption algorithms are rarely used in the HTTPS protocol and also perform poorly.
- It is generally believed that AES-128-GCM performs better than AEC-128-CBC.
- ChaCha20-Poly1305 performs even better than AES-128-GCM. In most cases, mobile devices are considered more suitable for the ChaCha20-Poly1305 algorithm.

**Use ChaCha20-Poly1305 on mobile phones and AES-128-GCM on computers**.

------------------------------------------------------

Reference:
  
*Cryptography Engineering in Pictures*      


> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/symmetric\_encryption/](https://halfrost.com/symmetric_encryption/)