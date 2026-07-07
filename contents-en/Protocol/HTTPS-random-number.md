# The Root of Unpredictability—Random Numbers


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_0.png'>
</p>


## 1. Why Do We Need Random Numbers?

Previous articles mentioned many cryptographic techniques, and random numbers show up in all of them.

- Generating keys      
Used for symmetric ciphers and message authentication codes
- Generating public-key cryptography    
Used for public-key cryptography and digital signatures
- Generating initialization vectors (IVs)    
Used in the CBC, CFB, and OFB modes of block ciphers
- Generating nonces    
Used to defend against replay attacks and in the CTR mode of block ciphers
- Generating salts  
Used in password-based encryption (PBE), and so on


The purpose of using random numbers is to **increase the unpredictability of ciphertext so that attackers cannot see through it at a glance**.


## 2. What Are Random Numbers?

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_1.png'>
</p>

It is difficult to give a rigorous definition of random numbers. We can only distinguish different kinds of random numbers by their properties.

- Randomness — there is no statistical bias; the sequence is completely disordered
- Unpredictability — the next number cannot be inferred from the previous sequence
- Irreproducibility — the same sequence cannot be reproduced unless the sequence itself is saved

||Randomness|Unpredictability|Irreproducibility||Remarks|Generator|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|Weak pseudorandom numbers|✅|❌|❌|Only have randomness|Cannot be used in cryptographic techniques ❌|Pseudorandom Number Generator PRNG (Pseudo Random Number Generator)|
|Strong pseudorandom numbers|✅|✅|❌|Have unpredictability|Can be used in cryptographic techniques ✅|Cryptographically secure pseudorandom number generator CPRNG (Cryptography secure Pseudo Random Number Generator)|
|True random numbers|✅|✅|✅|Have irreproducibility|Can be used in cryptographic techniques ✅|True Random Number Generator TRNG (True Random Number Generator)|


Random numbers used in cryptographic techniques must reach at least the level of unpredictability; that is, they must be at least strong pseudorandom numbers, and ideally true random numbers.

>In everyday life, the sequence produced by rolling dice is a **true random number** sequence, because the sequence it produces cannot be reproduced and has all three properties: randomness, unpredictability, and irreproducibility.

### 1. Randomness

Although randomness may appear chaotic, attackers can still see through it. Therefore, it is called weak pseudorandomness.

A pseudorandom sequence generated using a linear congruential generator appears chaotic, but in reality it can be predicted.


### 2. Unpredictability

Unpredictability means that even if an attacker knows the pseudorandom sequence generated in the past, they still cannot predict the next pseudorandom number to be generated. Unpredictability is achieved by using other cryptographic techniques—for example, the one-wayness and confidentiality of one-way hash functions—to ensure that pseudorandom numbers are unpredictable.

### 3. Irreproducibility

Using the natural phenomenon of thermal noise, Intel developed hardware devices capable of generating irreproducible random sequences. CPUs have a built-in **Digital Random Number Generator** (Digital Random Number Generator, DRNG), and provide the RDSEED instruction for generating irreproducible random numbers, as well as the RDRAND instruction for generating unpredictable random numbers.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_5.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_3.png'>
</p>


## 3. Pseudorandom Number Generators


A pseudorandom number generator generates a pseudorandom sequence from both an externally provided seed and its internal state.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_6.png'>
</p>

Because the internal state determines the next pseudorandom number to be generated, attackers must not learn the internal state. The externally provided seed is used to initialize the internal state of the pseudorandom number generator. Therefore, attackers must not learn the seed either. For this reason, the seed must not be an easily predictable value; for example, the current time must not be used as the seed.


The comparison between cryptographic keys and random-number seeds is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_7.png'>
</p>

There are several algorithms for generating pseudorandom numbers:

- Ad hoc methods
- Linear congruential method
- One-way hash function method
- Cipher-based method
- ANSI X9.17

### 1. Linear Congruential Method

The linear congruential method **multiplies the current pseudorandom value by A, adds C, and then uses the remainder after division by M as the next pseudorandom number**. As follows.
```c
R0 = (A * seed + C) mod M
R1 = (A * R0 + C) mod M
R2 = (A * R1 + C) mod M
R3 = (A * R2 + C) mod M
R4 = (A * R3 + C) mod M

Rn = (A * R(n-1) + C) mod M
```
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_8.png'>
</p>

A linear congruential generator is periodic; given its period, future states can be predicted. Therefore, it does not provide unpredictability and cannot be used for cryptographic purposes.

Many pseudorandom-number-generator library functions are implemented using the linear congruential method. For example, the C library function rand and Java’s java.util.Random class both use the linear congruential method. Therefore, these functions cannot be used for cryptographic purposes.


### 2. One-Way Hash Function Method

One-way hash functions can also generate unpredictable pseudorandom numbers, and they are strong pseudorandom numbers because their one-way property provides unpredictability.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_9.png'>
</p>

1. Initialize the internal state, i.e., the counter value, with the pseudorandom-number seed
2. Compute the hash value of the counter using a one-way hash function
3. Output the hash value as the pseudorandom number
4. Increment the counter value by 1
5. Repeat steps 2 through 4 according to the required number of pseudorandom numbers

**The one-way property of the one-way hash function is the basis for the unpredictability of the pseudorandom number generator**.

### 3. Cipher Method

The cipher method can also be used to generate strong pseudorandom numbers. You can use either AES symmetric encryption or RSA public-key encryption.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_10.png'>
</p>

1. Initialize the internal state (counter)
2. Encrypt the counter value with the key
3. Output the ciphertext as the pseudorandom number
4. Increment the counter value by 1
5. Repeat steps 2 through 4 according to the required number of pseudorandom numbers

**The confidentiality of the cipher is the basis for the unpredictability of the pseudorandom number generator**.

### 4. ANSI X9.17

The ANSI X9.17 method can also be used to generate strong pseudorandom numbers.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_11.png'>
</p>

1. Initialize the internal state
2. Encrypt the current time to generate a key
3. XOR the internal state with the mask
4. Encrypt the result from step 3
5. Output the result from step 4 as the pseudorandom number
6. XOR the result from step 4 with the mask
7. Encrypt the result from step 6
8. Use the result from step 7 as the new internal state
9. Repeat steps 2 through 8 according to the required number of pseudorandom numbers


## IV. Other Algorithms

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_4.png'>
</p>

There is a pseudorandom number generation algorithm called the Mersenne Twister. It cannot be used for security-related purposes because, like the linear congruential algorithm, once its period is observed, the random sequence generated afterward can be predicted.

Java’s java.util.Random class also cannot be used for security-related purposes. If you need randomness for security-related use cases, use another class called java.security.SecureRandom.

Similarly, Ruby provides two corresponding classes: Random and SecureRandom. For security-related use cases, you should only use the SecureRandom class.


## V. Attacks on Pseudorandom Number Generators

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_2.png'>
</p>

- Attacking the seed  
The seed of a pseudorandom number is just as important as a cryptographic key. To prevent an attacker from learning the seed, use non-reproducible true random numbers as the seed.

- Attacking the random number pool  
In general, true random numbers are not generated only at the moment they are needed. Instead, random bit sequences are accumulated in advance in a **random number pool** file. When they are needed, the required length of random bit sequence can simply be taken from the pool and used. (The random number pool itself does not store any meaningful information, yet we still need to protect these meaningless bit sequences. This is somewhat contradictory, but necessary.)


------------------------------------------------------

Reference：
  
*Illustrated Cryptographic Technology*        

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/random\_number/](https://halfrost.com/random_number/)