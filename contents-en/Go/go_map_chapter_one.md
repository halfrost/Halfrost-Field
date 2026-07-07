# How to Design and Implement a Thread-Safe Map? (Part 1)

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-ae74a3ad86c9b3fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


A map is a very common data structure used to store unordered key-value pairs. Mainstream programming languages typically provide a built-in implementation. C and C++ implement Map in the STL; JavaScript also has Map; Java has HashMap; Swift and Python have Dictionary; Go has Map; Objective-C has NSDictionary and NSMutableDictionary.

Are all of these maps thread-safe? The answer is no—not all of them are thread-safe. So how can we implement a thread-safe Map? To answer that question, we first need to start with how to implement a Map.

## 1. What Data Structure Should Be Used to Implement a Map?

Map is a very commonly used data structure: a collection of unordered key/value pairs, where all keys in the Map are distinct. Given a key, the corresponding value can be looked up, updated, or deleted in constant time, with O(1) complexity.

What should we use to achieve constant-time lookup? Readers will probably think of a hash table right away. Indeed, Map is generally implemented underneath using an array, with the help of a hashing algorithm. For a given key, we usually hash it first, then take the result modulo the length of the hash table to map the key to a specific location.


![](http://upload-images.jianshu.io/upload_images/1194012-204724b103dadb0e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There are many hashing algorithms. Which one is more efficient?

### 1. Hash Functions


![](http://upload-images.jianshu.io/upload_images/1194012-a6432423733b54a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


MD5 and SHA1 are arguably the most widely used hash algorithms today, and both were designed based on MD4.

MD4 (RFC 1320) was designed by Ronald L. Rivest of MIT in 1990. MD stands for Message Digest. It is suitable for high-speed software implementations on processors with a 32-bit word size—it is implemented using bit operations on 32-bit operands.
MD5 (RFC 1321) is an improved version of MD4, released by Rivest in 1991. It still processes input in 512-bit blocks, and its output is a concatenation of four 32-bit words, the same as MD4. MD5 is more complex than MD4 and slightly slower, but it is more secure and performs better against cryptanalysis and differential attacks.

SHA1 was designed by NIST and the NSA for use with DSA. For inputs with length less than 264, it produces a 160-bit hash value, so it has better resistance to brute-force attacks. SHA-1 was designed based on the same principles as MD4 and imitates that algorithm.


Common hash functions include SHA-1, SHA-256, SHA-512, and MD5. These are classic hash algorithms. In modern production systems, more modern hash algorithms are also used. Below we list several of them, compare their performance, and finally choose one to analyze its implementation from the source code.

#### (1) Jenkins Hash and SpookyHash


![](http://upload-images.jianshu.io/upload_images/1194012-764eab08d0749ad9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In 1997, [Bob Jenkins](http://burtleburtle.net/bob/) published an article about hash functions in *Dr. Dobb's Journal*: [“A hash function for hash Table lookup”](http://www.burtleburtle.net/bob/hash/doobs.html). In that article, Bob extensively collected many existing hash functions, including what he called “lookup2”. Then in 2006, Bob released [lookup3](http://burtleburtle.net/bob/c/lookup3.c). lookup3 is Jenkins Hash. For more about Bob’s hash functions, see Wikipedia: [Jenkins hash function](http://en.wikipedia.org/wiki/Jenkins_hash_function). memcached's hash algorithm supports two algorithms: jenkins and murmur3; the default is jenkins.

In 2011, Bob Jenkins released a new hash function of his own:
SpookyHash (so named because it was released on Halloween). Both are twice as fast as MurmurHash, but they use only 64-bit math functions and have no 32-bit version. SpookyHash produces a 128-bit output.

#### (2) MurmurHash


![](http://upload-images.jianshu.io/upload_images/1194012-d831141d81fdf7a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


MurmurHash is a non-[cryptographic](https://zh.wikipedia.org/wiki/%E5%8A%A0%E5%AF%86) [hash function](https://zh.wikipedia.org/wiki/%E5%93%88%E5%B8%8C%E5%87%BD%E6%95%B0) suitable for general hash-based lookup operations.
In 2008, Austin Appleby released a new hash function—[MurmurHash](https://en.wikipedia.org/wiki/MurmurHash). Its latest version is roughly twice as fast as lookup3 (about 1 byte/cycle), and it has both 32-bit and 64-bit versions. The 32-bit version uses only 32-bit math functions and produces a 32-bit hash value, while the 64-bit version uses 64-bit math functions and produces a 64-bit hash value. According to Austin’s analysis, MurmurHash has excellent performance, although Bob Jenkins claimed in *Dr. Dobb's article*, “I predict MurmurHash is weaker than lookup3, but I don’t know by how much because I haven’t tested it yet.” MurmurHash quickly became popular thanks to its outstanding speed and statistical properties. The current version is MurmurHash3, and it is used by Redis, Memcached, Cassandra, HBase, and Lucene.


Below is a version of MurmurHash implemented in C:
```c

uint32_t murmur3_32(const char *key, uint32_t len, uint32_t seed) {
        static const uint32_t c1 = 0xcc9e2d51;
        static const uint32_t c2 = 0x1b873593;
        static const uint32_t r1 = 15;
        static const uint32_t r2 = 13;
        static const uint32_t m = 5;
        static const uint32_t n = 0xe6546b64;

        uint32_t hash = seed;

        const int nblocks = len / 4;
        const uint32_t *blocks = (const uint32_t *) key;
        int i;
        for (i = 0; i < nblocks; i++) {
                uint32_t k = blocks[i];
                k *= c1;
                k = (k << r1) | (k >> (32 - r1));
                k *= c2;

                hash ^= k;
                hash = ((hash << r2) | (hash >> (32 - r2))) * m + n;
        }

        const uint8_t *tail = (const uint8_t *) (key + nblocks * 4);
        uint32_t k1 = 0;

        switch (len & 3) {
        case 3:
                k1 ^= tail[2] << 16;
        case 2:
                k1 ^= tail[1] << 8;
        case 1:
                k1 ^= tail[0];

                k1 *= c1;
                k1 = (k1 << r1) | (k1 >> (32 - r1));
                k1 *= c2;
                hash ^= k1;
        }

        hash ^= len;
        hash ^= (hash >> 16);
        hash *= 0x85ebca6b;
        hash ^= (hash >> 13);
        hash *= 0xc2b2ae35;
        hash ^= (hash >> 16);

        return hash;
}


```

#### (3) CityHash and FarmHash


![](http://upload-images.jianshu.io/upload_images/1194012-53235045a3fd8cb7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Both of these algorithms are string algorithms released by Google.

[CityHash](https://github.com/google/cityhash) is a string hashing algorithm released by Google in 2011. Like MurmurHash, it is a non-cryptographic hash algorithm. The development of CityHash was inspired by MurmurHash. Its main advantage is that most steps contain at least two independent mathematical operations. Modern CPUs can usually achieve optimal performance from this kind of code. CityHash also has its drawbacks: the code is more complex than other popular algorithms in the same category. Google wanted to optimize for speed rather than simplicity, so it did not add special handling for shorter inputs. Google released two algorithms: cityhash64 and cityhash128. They compute 64-bit and 128-bit hash values for strings, respectively. These algorithms are not suitable for cryptography, but they are suitable for use in hash tables and similar scenarios. CityHash's speed depends on the CRC32 instruction, currently SSE 4.2 (Intel Nehalem and later).

Compared with MurmurHash, which supports 32-, 64-, and 128-bit hashes, CityHash supports 64-, 128-, and 256-bit hashes.

In 2014, Google released [FarmHash](https://github.com/google/farmhash), a new family of hash functions for strings. FarmHash inherits many tricks and techniques from CityHash and is its successor. FarmHash has multiple goals and claims to improve upon CityHash in several respects. Compared with CityHash, another improvement in FarmHash is that it provides a single interface on top of multiple platform-specific implementations. This way, when developers simply want a fast, robust hash function for hash tables and do not need it to be identical on every platform, FarmHash can satisfy that requirement as well. Currently, FarmHash only includes hash functions for byte arrays on 32-, 64-, and 128-bit platforms. Future development plans include support for integers, tuples, and other data.


#### (4) xxHash


![](http://upload-images.jianshu.io/upload_images/1194012-06ad3c89ace5c525.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


xxHash is a non-cryptographic hash function created by Yann Collet. It was originally used in the LZ4 compression algorithm as the final error-checking signature. The speed of this hash algorithm approaches the limits of RAM. It provides both 32-bit and 64-bit versions. It is now widely used in databases such as [PrestoDB](http://prestodb.io/), [RocksDB](https://rocksdb.org/), [MySQL](https://www.mysql.com/), [ArangoDB](https://www.arangodb.org/), [PGroonga](https://pgroonga.github.io/), and [Spark](http://spark.apache.org/), and also in game frameworks such as [Cocos2D](http://www.cocos2d.org/), [Dolphin](https://dolphin-emu.org/), and [Cxbx-reloaded](http://cxbx-reloaded.co.uk/).


Below is a performance comparison experiment. The test environment is the [Open-Source SMHasher program by Austin Appleby](http://code.google.com/p/smhasher/wiki/SMHasher), compiled with Visual C on Windows 7, and it uses only a single thread. The CPU core is a Core 2 Duo @3.0GHz.

![](http://upload-images.jianshu.io/upload_images/1194012-a10436a5de50086a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The hash functions in the table above are not all existing hash functions; only some common algorithms are listed. The second column compares speed, and you can see that the fastest is xxHash. The third column is hash quality. There are five functions with the highest hash quality, all rated five stars: xxHash, MurmurHash 3a, CityHash64, MD5-32, and SHA1-32. Judging from the data in the table, the hash function with both the highest quality and the fastest speed is still xxHash.


#### (4) memhash

![](http://upload-images.jianshu.io/upload_images/1194012-5bc2312dd0da4536.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


I was unable to find clear author information for this hash algorithm online. I only found a few lines of comments in Google's Go documentation explaining its source of inspiration:
```go

// Hashing algorithm inspired by
//   xxhash: https://code.google.com/p/xxhash/
// cityhash: https://code.google.com/p/cityhash/

```
It says that `memhash` was inspired by `xxhash` and `cityhash`. Next, let’s take a look at how `memhash` hashes strings.
```go


const (
	// Constants for multiplication: four random odd 32-bit numbers.
	m1 = 3168982561
	m2 = 3339683297
	m3 = 832293441
	m4 = 2336365089
)

func memhash(p unsafe.Pointer, seed, s uintptr) uintptr {
	if GOARCH == "386" && GOOS != "nacl" && useAeshash {
		return aeshash(p, seed, s)
	}
	h := uint32(seed + s*hashkey[0])
tail:
	switch {
	case s == 0:
	case s < 4:
		h ^= uint32(*(*byte)(p))
		h ^= uint32(*(*byte)(add(p, s>>1))) << 8
		h ^= uint32(*(*byte)(add(p, s-1))) << 16
		h = rotl_15(h*m1) * m2
	case s == 4:
		h ^= readUnaligned32(p)
		h = rotl_15(h*m1) * m2
	case s <= 8:
		h ^= readUnaligned32(p)
		h = rotl_15(h*m1) * m2
		h ^= readUnaligned32(add(p, s-4))
		h = rotl_15(h*m1) * m2
	case s <= 16:
		h ^= readUnaligned32(p)
		h = rotl_15(h*m1) * m2
		h ^= readUnaligned32(add(p, 4))
		h = rotl_15(h*m1) * m2
		h ^= readUnaligned32(add(p, s-8))
		h = rotl_15(h*m1) * m2
		h ^= readUnaligned32(add(p, s-4))
		h = rotl_15(h*m1) * m2
	default:
		v1 := h
		v2 := uint32(seed * hashkey[1])
		v3 := uint32(seed * hashkey[2])
		v4 := uint32(seed * hashkey[3])
		for s >= 16 {
			v1 ^= readUnaligned32(p)
			v1 = rotl_15(v1*m1) * m2
			p = add(p, 4)
			v2 ^= readUnaligned32(p)
			v2 = rotl_15(v2*m2) * m3
			p = add(p, 4)
			v3 ^= readUnaligned32(p)
			v3 = rotl_15(v3*m3) * m4
			p = add(p, 4)
			v4 ^= readUnaligned32(p)
			v4 = rotl_15(v4*m4) * m1
			p = add(p, 4)
			s -= 16
		}
		h = v1 ^ v2 ^ v3 ^ v4
		goto tail
	}
	h ^= h >> 17
	h *= m3
	h ^= h >> 13
	h *= m4
	h ^= h >> 16
	return uintptr(h)
}

// Note: in order to get the compiler to issue rotl instructions, we
// need to constant fold the shift amount by hand.
// TODO: convince the compiler to issue rotl instructions after inlining.
func rotl_15(x uint32) uint32 {
	return (x << 15) | (x >> (32 - 15))
}


```
`m1`, `m2`, `m3`, and `m4` are four randomly selected odd numbers used as multipliers for the hash.
```go

// used in hash{32,64}.go to seed the hash function
var hashkey [4]uintptr

func alginit() {
	// Install aes hash algorithm if we have the instructions we need
	if (GOARCH == "386" || GOARCH == "amd64") &&
		GOOS != "nacl" &&
		cpuid_ecx&(1<<25) != 0 && // aes (aesenc)
		cpuid_ecx&(1<<9) != 0 && // sse3 (pshufb)
		cpuid_ecx&(1<<19) != 0 { // sse4.1 (pinsr{d,q})
		useAeshash = true
		algarray[alg_MEM32].hash = aeshash32
		algarray[alg_MEM64].hash = aeshash64
		algarray[alg_STRING].hash = aeshashstr
		// Initialize with random data so hash collisions will be hard to engineer.
		getRandomData(aeskeysched[:])
		return
	}
	getRandomData((*[len(hashkey) * sys.PtrSize]byte)(unsafe.Pointer(&hashkey))[:])
	hashkey[0] |= 1 // make sure these numbers are odd
	hashkey[1] |= 1
	hashkey[2] |= 1
	hashkey[3] |= 1
}

```
In this initialization function, two arrays are initialized, both filled with random hash keys. On 386, amd64, non-NaCl platforms, `aeshash` is used. Here, random keys are generated and stored in the `aeskeysched` array. Similarly, four random numbers are also generated for the `hashkey` array. Finally, each value is bitwise-ORed with `1`, to ensure that the generated random numbers are all odd.

Next, let’s look at an example to see exactly how `memhash` computes a hash value.
```go

func main() {
	r := [8]byte{'h', 'a', 'l', 'f', 'r', 'o', 's', 't'}
	pp := memhashpp(unsafe.Pointer(&r), 3, 7)
	fmt.Println(pp)
}

```
For simplicity, we use the author's name as an example to compute the hash value, and set the seed to a simple value of 3.

The first step is to compute the value of h.
```go

h := uint32(seed + s*hashkey[0])

```
Here, assume `hashkey[0] = 1`, then the value of `h` is `3 + 7 * 1 = 10`. Since `s < 8`, the following processing will be performed:
```go

    case s <= 8:
        h ^= readUnaligned32(p)
        h = rotl_15(h*m1) * m2
        h ^= readUnaligned32(add(p, s-4))
        h = rotl_15(h*m1) * m2

```
![](http://upload-images.jianshu.io/upload_images/1194012-0a25b88618395f81.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The `readUnaligned32()` function performs two conversions on the incoming `unsafe.Pointer`: first to the `*uint32` type, and then to the `*(*uint32)` type.

Next, it performs an XOR operation:

![](http://upload-images.jianshu.io/upload_images/1194012-a6a7036bde9a7b34.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Then in the second step: h * m1 = 1718378850 * 3168982561 = 3185867170

![](http://upload-images.jianshu.io/upload_images/1194012-2472408250264228.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Because this is 32-bit multiplication, the final result is 64 bits; the high 32 bits overflow and are discarded directly.

The multiplication result is used as the input to `rotl_15()`.
```go

func rotl_15(x uint32) uint32 {
	return (x << 15) | (x >> (32 - 15))
}


```
This function performs two shift operations on the input parameter.

![](http://upload-images.jianshu.io/upload_images/1194012-42eefade813defe5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-a9a2a8743786d0c5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Finally, it performs a logical OR on the results of the two shifts:

![](http://upload-images.jianshu.io/upload_images/1194012-74cf6924f7d79dcf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Next, it performs another `readUnaligned32()` conversion:

![](http://upload-images.jianshu.io/upload_images/1194012-82d46bb52ef8a8d7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After the conversion, it performs another XOR. At this point, h = 2615762644.

Then it applies another `rotl\_15()` transformation. I won’t illustrate that here. After the transformation completes, h = 2932930721.

Finally, execute the last step of the hash:
```go

    h ^= h >> 17
    h *= m3
    h ^= h >> 13
    h *= m4
    h ^= h >> 16

```
First shift right by 17 bits, then XOR, multiply by m3, shift right by 13 bits, XOR again, multiply by m4, shift right by 16 bits, and finally XOR again.

Through this series of operations, the hash value can be generated. The final result is h = 1870717864. Interested readers can verify the calculation themselves.


#### (5) AES Hash

In the analysis of Go’s hash algorithm above, we saw that it checks whether the CPU supports the AES instruction set. If the CPU supports the AES instruction set, it uses the AES Hash algorithm; otherwise, it falls back to the memhash algorithm.

The full name of the AES instruction set is the **Advanced Encryption Standard Instruction Set** (also known as Intel **Advanced Encryption Standard New Instructions**, abbreviated as **AES-NI**). It is an extension to the [x86](https://zh.wikipedia.org/wiki/X86) [instruction set architecture](https://zh.wikipedia.org/wiki/%E6%8C%87%E4%BB%A4%E9%9B%86%E6%9E%B6%E6%A7%8B), used in [Intel](https://zh.wikipedia.org/wiki/%E8%8B%B1%E7%89%B9%E5%B0%94) and [AMD](https://zh.wikipedia.org/wiki/%E8%B6%85%E5%A8%81%E5%8D%8A%E5%AF%BC%E4%BD%93) [microprocessors](https://zh.wikipedia.org/wiki/%E5%BE%AE%E5%A4%84%E7%90%86%E5%99%A8).

Using AES to implement a hash algorithm delivers excellent performance because it provides hardware acceleration.

The concrete implementation is shown below. It is assembly code, with comments included in the program below:
```asm

// aes hash algorithm is implemented using the AES hardware instruction set
TEXT runtime·aeshash(SB),NOSPLIT,$0-32
	MOVQ	p+0(FP), AX	// move ptr into the data segment
	MOVQ	s+16(FP), CX	// length
	LEAQ	ret+24(FP), DX
	JMP	runtime·aeshashbody(SB)

TEXT runtime·aeshashstr(SB),NOSPLIT,$0-24
	MOVQ	p+0(FP), AX	// move ptr into the string struct
	MOVQ	8(AX), CX	// string length
	MOVQ	(AX), AX	// string data
	LEAQ	ret+16(FP), DX
	JMP	runtime·aeshashbody(SB)

```
The actual hash implementation ultimately resides in `aeshashbody`:
```asm

// AX: data
// CX: length
// DX: return address
TEXT runtime·aeshashbody(SB),NOSPLIT,$0-0
	// Load our random seed into an SSE register
	MOVQ	h+8(FP), X0			// The hash seed in each table is 64 bits
	PINSRW	$4, CX, X0			// The length uses 16 bits
	PSHUFHW $0, X0, X0			// Shuffle high packed words, repeat the length 4 times
	MOVO	X0, X1				// Save the seed before encryption
	PXOR	runtime·aeskeysched(SB), X0	// XOR each seed being processed
	AESENC	X0, X0				// Encrypt the seed

	CMPQ	CX, $16
	JB	aes0to15
	JE	aes16
	CMPQ	CX, $32
	JBE	aes17to32
	CMPQ	CX, $64
	JBE	aes33to64
	CMPQ	CX, $128
	JBE	aes65to128
	JMP	aes129plus

// aes from 0 - 15
aes0to15:
	TESTQ	CX, CX
	JE	aes0

	ADDQ	$16, AX
	TESTW	$0xff0, AX
	JE	endofpage

	//The address of the 16 bytes loaded here won't cross a page boundary, so we can load it directly.
	MOVOU	-16(AX), X1
	ADDQ	CX, CX
	MOVQ	$masks<>(SB), AX
	PAND	(AX)(CX*8), X1
final1:
	PXOR	X0, X1	// XOR data and seed
	AESENC	X1, X1	// Encrypt 3 times in a row
	AESENC	X1, X1
	AESENC	X1, X1
	MOVQ	X1, (DX)
	RET

endofpage:
	// The address ends in 1111xxxx. This may cross a page boundary, so stop loading after the last byte. Then use pshufb to shift the bytes down.
	MOVOU	-32(AX)(CX*1), X1
	ADDQ	CX, CX
	MOVQ	$shifts<>(SB), AX
	PSHUFB	(AX)(CX*8), X1
	JMP	final1

aes0:
	// Return the input, already-encrypted seed
	AESENC	X0, X0
	MOVQ	X0, (DX)
	RET

aes16:
	MOVOU	(AX), X1
	JMP	final1

aes17to32:
	// Start processing the second initial seed
	PXOR	runtime·aeskeysched+16(SB), X1
	AESENC	X1, X1
	
	// Load data to be processed by the hash algorithm
	MOVOU	(AX), X2
	MOVOU	-16(AX)(CX*1), X3

	// XOR the seeds
	PXOR	X0, X2
	PXOR	X1, X3

	// Encrypt 3 times in a row
	AESENC	X2, X2
	AESENC	X3, X3
	AESENC	X2, X2
	AESENC	X3, X3
	AESENC	X2, X2
	AESENC	X3, X3

	// Combine and produce the result
	PXOR	X3, X2
	MOVQ	X2, (DX)
	RET

aes33to64:
	// Process the third and subsequent initial seeds
	MOVO	X1, X2
	MOVO	X1, X3
	PXOR	runtime·aeskeysched+16(SB), X1
	PXOR	runtime·aeskeysched+32(SB), X2
	PXOR	runtime·aeskeysched+48(SB), X3
	AESENC	X1, X1
	AESENC	X2, X2
	AESENC	X3, X3
	
	MOVOU	(AX), X4
	MOVOU	16(AX), X5
	MOVOU	-32(AX)(CX*1), X6
	MOVOU	-16(AX)(CX*1), X7

	PXOR	X0, X4
	PXOR	X1, X5
	PXOR	X2, X6
	PXOR	X3, X7
	
	AESENC	X4, X4
	AESENC	X5, X5
	AESENC	X6, X6
	AESENC	X7, X7
	
	AESENC	X4, X4
	AESENC	X5, X5
	AESENC	X6, X6
	AESENC	X7, X7
	
	AESENC	X4, X4
	AESENC	X5, X5
	AESENC	X6, X6
	AESENC	X7, X7

	PXOR	X6, X4
	PXOR	X7, X5
	PXOR	X5, X4
	MOVQ	X4, (DX)
	RET

aes65to128:
	// Process the seventh and subsequent initial seeds
	MOVO	X1, X2
	MOVO	X1, X3
	MOVO	X1, X4
	MOVO	X1, X5
	MOVO	X1, X6
	MOVO	X1, X7
	PXOR	runtime·aeskeysched+16(SB), X1
	PXOR	runtime·aeskeysched+32(SB), X2
	PXOR	runtime·aeskeysched+48(SB), X3
	PXOR	runtime·aeskeysched+64(SB), X4
	PXOR	runtime·aeskeysched+80(SB), X5
	PXOR	runtime·aeskeysched+96(SB), X6
	PXOR	runtime·aeskeysched+112(SB), X7
	AESENC	X1, X1
	AESENC	X2, X2
	AESENC	X3, X3
	AESENC	X4, X4
	AESENC	X5, X5
	AESENC	X6, X6
	AESENC	X7, X7

	// Load data
	MOVOU	(AX), X8
	MOVOU	16(AX), X9
	MOVOU	32(AX), X10
	MOVOU	48(AX), X11
	MOVOU	-64(AX)(CX*1), X12
	MOVOU	-48(AX)(CX*1), X13
	MOVOU	-32(AX)(CX*1), X14
	MOVOU	-16(AX)(CX*1), X15

	// XOR the seeds
	PXOR	X0, X8
	PXOR	X1, X9
	PXOR	X2, X10
	PXOR	X3, X11
	PXOR	X4, X12
	PXOR	X5, X13
	PXOR	X6, X14
	PXOR	X7, X15

	// Encrypt 3 times in a row
	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15

	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15

	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15

	// Assemble the result
	PXOR	X12, X8
	PXOR	X13, X9
	PXOR	X14, X10
	PXOR	X15, X11
	PXOR	X10, X8
	PXOR	X11, X9
	PXOR	X9, X8
	MOVQ	X8, (DX)
	RET

aes129plus:
	// Process the seventh and subsequent initial seeds
	MOVO	X1, X2
	MOVO	X1, X3
	MOVO	X1, X4
	MOVO	X1, X5
	MOVO	X1, X6
	MOVO	X1, X7
	PXOR	runtime·aeskeysched+16(SB), X1
	PXOR	runtime·aeskeysched+32(SB), X2
	PXOR	runtime·aeskeysched+48(SB), X3
	PXOR	runtime·aeskeysched+64(SB), X4
	PXOR	runtime·aeskeysched+80(SB), X5
	PXOR	runtime·aeskeysched+96(SB), X6
	PXOR	runtime·aeskeysched+112(SB), X7
	AESENC	X1, X1
	AESENC	X2, X2
	AESENC	X3, X3
	AESENC	X4, X4
	AESENC	X5, X5
	AESENC	X6, X6
	AESENC	X7, X7
	
	// Start in reverse order, processing from the last block, because overlap may occur
	MOVOU	-128(AX)(CX*1), X8
	MOVOU	-112(AX)(CX*1), X9
	MOVOU	-96(AX)(CX*1), X10
	MOVOU	-80(AX)(CX*1), X11
	MOVOU	-64(AX)(CX*1), X12
	MOVOU	-48(AX)(CX*1), X13
	MOVOU	-32(AX)(CX*1), X14
	MOVOU	-16(AX)(CX*1), X15

	// XOR the seeds
	PXOR	X0, X8
	PXOR	X1, X9
	PXOR	X2, X10
	PXOR	X3, X11
	PXOR	X4, X12
	PXOR	X5, X13
	PXOR	X6, X14
	PXOR	X7, X15
	
	// Calculate the number of remaining 128-byte blocks
	DECQ	CX
	SHRQ	$7, CX
	
aesloop:
	// Encrypt state
	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15

	// Encrypt the state in the same block and XOR
	MOVOU	(AX), X0
	MOVOU	16(AX), X1
	MOVOU	32(AX), X2
	MOVOU	48(AX), X3
	AESENC	X0, X8
	AESENC	X1, X9
	AESENC	X2, X10
	AESENC	X3, X11
	MOVOU	64(AX), X4
	MOVOU	80(AX), X5
	MOVOU	96(AX), X6
	MOVOU	112(AX), X7
	AESENC	X4, X12
	AESENC	X5, X13
	AESENC	X6, X14
	AESENC	X7, X15

	ADDQ	$128, AX
	DECQ	CX
	JNE	aesloop

	// Final step: do 3+ encryptions
	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15
	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15
	AESENC	X8, X8
	AESENC	X9, X9
	AESENC	X10, X10
	AESENC	X11, X11
	AESENC	X12, X12
	AESENC	X13, X13
	AESENC	X14, X14
	AESENC	X15, X15

	PXOR	X12, X8
	PXOR	X13, X9
	PXOR	X14, X10
	PXOR	X15, X11
	PXOR	X10, X8
	PXOR	X11, X9
	PXOR	X9, X8
	MOVQ	X8, (DX)
	RET


```

### 2. Handling Hash Collisions


#### (1) Array of Linked Lists

![](http://upload-images.jianshu.io/upload_images/1194012-d9b8c5a98a5fbb6f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The array-of-linked-lists method is relatively simple: take each key-value pair modulo the table length. If the result is the same, insert it sequentially into a linked list.


Assume the set of keys to be inserted is { 2, 3, 5, 7, 11, 13, 19 }, and the table length is MOD 8. Assume the hash function is uniformly distributed over [0,9). This is shown in the figure above.

Next, let’s focus on the performance analysis:

When looking up a key k, assume key k is not in the hash table, and h(k) is uniformly distributed over [0, M), that is, P(h(k) = i) = 1/M. Let Xi be the number of keys contained in ht[ i ]. If h(k) = i, then the number of key comparisons for an unsuccessful lookup of k is Xi. Therefore:


![](http://upload-images.jianshu.io/upload_images/1194012-4898c1e0daf1eaeb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The analysis of successful lookup is slightly more complicated. We need to consider the order in which elements are added to the hash table, without considering the case of duplicate keys. Assume K = {k1,k2,……kn}, and assume elements are added to the hash table from an empty hash table in this order. Introduce a random variable: if h(ki) = h(kj), then Xij = 1; if h(ki) != h(kj), then Xij = 0.

Because of the previous assumption that the hash table is uniformly distributed, P(Xij = i) = E(Xij) = 1/M, where E(X) denotes the mathematical expectation of the random variable X. Further assume that each time a key is added, it is appended to the end of the linked list. Let Ci be the number of key comparisons required to find Ki. Since the probability of looking up Ki cannot be determined in advance, assume the probabilities of looking up different keys are all the same, namely 1/n. Then we have:


![](http://upload-images.jianshu.io/upload_images/1194012-dd324acdf9229d16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From this we can see that the performance of a hash table is not strongly related to the number of elements in the table, but rather to the load factor α. **If the hash table length is proportional to the number of elements in the hash table, then the lookup complexity of the hash table is O(1).**


In summary, the average numbers of key comparisons for successful and unsuccessful lookups in an array of linked lists are as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-7d66287ec311dbd1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (2) Open Addressing — Linear Probing


The rule for linear probing is hi =  ( h(k) + i ) MOD M. For example, i = 1, M = 9.

With this conflict-resolution method, once a collision occurs, the position is incremented by 1 until an empty position is found.

For example, assume the set of keys to be inserted is {2, 3, 5, 7, 11, 13, 19}, and after a collision occurs in linear probing, the incremented value is 1. Then the final result is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-81e615f78ffac666.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The performance analysis of a linear-probing hash table is relatively complicated, so only the result is given here.


![](http://upload-images.jianshu.io/upload_images/1194012-abbf6eaba483f176.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


#### (3) Open Addressing — Quadratic Probing

The rule for linear probing is h0 = h(k), hi =  ( h0 + i * i ) MOD M.

For example, assume the set of keys to be inserted is {2, 3, 5, 7, 11, 13, 20}. In quadratic probing, after a collision occurs, the added value is the square of the number of probes. The final result is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-054d1e55317c2bd4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Quadratic probing adds a quadratic curve on top of linear probing. After a collision occurs, it no longer adds a linear parameter; instead, it adds the square of the probe count.


One thing to note about quadratic probing is that the size of M matters. If M is not an odd prime, the following problem may occur: even if there are still empty positions in the hash table, an element may not be able to find a position to insert into.

For example, assume M = 10 and the set of keys to be inserted is {0, 1, 4, 5, 6, 9, 10}. After the first 6 keys have been inserted into the hash table, 10 can no longer be inserted.

![](http://upload-images.jianshu.io/upload_images/1194012-1302823b3aa6d59c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Therefore, in quadratic probing, the following rule holds:

**If M is an odd prime, then the following ⌈M / 2⌉ positions h0, h1, h2 …… h⌊M/2⌋ are all distinct. Here, hi = (h0 + i * i ) MOD M.**


This rule can be proven by contradiction. Suppose hi = hj, i > j; 0<=i, j<= ⌊M/2⌋. Then h0 + i* i = ( h0 + j * j ) MOD M, so M can divide ( i + j )( i - j ). Since M is prime and 0 < i + j, i - j < M, this can be satisfied if and only if i = j.

The rule above also illustrates one point: **as long as M is an odd prime, quadratic probing can traverse at least half of the positions in the hash table. Therefore, as long as the load factor α <= 1 / 2, quadratic probing can always find an insertable position.**

In the example above, the reason key 10 cannot be inserted is also because α > 1 / 2, so it is no longer guaranteed that an insertable position exists.


#### (4) Open Addressing — Double Hashing

Double hashing is intended to solve the clustering problem. Whether with linear probing or quadratic probing, if h(k1) and h(k2) are adjacent, their probe sequences will also be adjacent. This is the so-called clustering phenomenon. To avoid this, a second hash function h2 is introduced so that the distance between two probes is h2(k). Thus the probe sequence is h0 = h1(k), hi = ( h0 + i * h2(k) ) MOD M. Experiments show that the performance of double hashing is similar to random probing.

Analyzing the average search length for double hashing and quadratic probing is more difficult than for linear probing. Therefore, the concept of random probing is introduced to approximate these two probing methods. Random probing means that the probe sequence { hi } is selected independently and uniformly at random from the interval [0, M], so P(hi = j) = 1/M.

Assume the probe sequence is h0, h1, ……, hi. The position hi in the hash table is empty, while the positions h0, h1, ……, hi-1 in the hash table are not empty; the number of key comparisons for this lookup is i. Let the random variable X be the number of key comparisons required for one unsuccessful lookup. Since the load factor of the hash table is α, the probability that a position in the hash table is empty is 1 - α, and the probability that it is non-empty is α. Therefore, P( X = i ) = α^i * ( 1 - α ).

In probability theory, the distribution above is called a geometric distribution.


![](http://upload-images.jianshu.io/upload_images/1194012-858876e348e64752.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Assume the insertion order of elements into the hash table is {k1, k2, …… , kn}. Let Xi be the number of key comparisons for an unsuccessful lookup when the hash table contains only {k1, k2, …… , ki}. Note that at this point the load factor of the hash table is i/M. Then the number of key comparisons for looking up k(i+1) is Yi = 1 + Xi. Assuming the probability of looking up any key is 1/n, the average number of key comparisons for a successful lookup is:


![](http://upload-images.jianshu.io/upload_images/1194012-3bebdc58321519b8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In summary, the average numbers of key comparisons for successful and unsuccessful lookups in quadratic probing and double hashing are as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-587fda4b6727fe64.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Overall, when the amount of data is very large, simple hash functions inevitably produce collisions. Even if an appropriate collision-resolution method is used, there is still a certain time complexity. Therefore, if you want to avoid collisions as much as possible, you should choose a high-performance hash function, or increase the number of hash bits, for example to 64 bits, 128 bits, or 256 bits, which makes the probability of collision much smaller.


### 3. Hash Table Expansion Strategy


As the load factor of a hash table increases, the number of collisions grows, and the hash table’s performance becomes worse and worse. For hash tables implemented with separate chaining, this may still be tolerable; but for open addressing, this performance degradation is unacceptable. Therefore, for open addressing, we need to find a way to solve this problem.

In real-world applications, the way to solve this problem is to dynamically increase the length of the hash table. When the load factor exceeds a certain threshold, the hash table length is increased automatically. After the length of the hash table changes, the corresponding index of every key in the hash table must be recomputed; entries cannot simply be copied from the old hash table to the new one. The hash value of each key in the original hash table must be computed one by one and inserted into the new hash table. This approach certainly does not meet production requirements, because its time complexity is too high: O(n). Once the data volume becomes large, performance will be poor. Redis came up with a method that allows insertion to complete in constant time, O(1), even when growth is triggered. The solution is to copy the old hash table to the new hash table incrementally over multiple steps, rather than completing the copy all at once.

Next, using Redis as an example, let’s discuss how its hash table performs expansion without significantly affecting performance.

Redis defines a dictionary as follows:
```c

/*
 * Dictionary
 *
 * Each dictionary uses two hash tables to implement incremental rehashing
 */
typedef struct dict {
    // Type-specific handler functions
    dictType *type;
    // Private data for the type handler functions
    void *privdata;
    // Hash tables (2)
    dictht ht[2];
    // Flag recording rehash progress; -1 means rehash is not in progress
    int rehashidx;
    // Number of safe iterators currently active
    int iterators;
} dict;


```
From the definition, we can see that a Redis dictionary holds two hash tables, and hash table ht[1] is used for rehashing.


![](http://upload-images.jianshu.io/upload_images/1194012-6a09f905e43451bb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Redis defines the hash table data structure as follows:
```c

/*
 * Hash table
 */
typedef struct dictht {
    // Hash table node pointer array (commonly called buckets)
    dictEntry **table;
    // Size of the pointer array
    unsigned long size;
    // Length mask of the pointer array, used to compute the index
    unsigned long sizemask;
    // Current number of nodes in the hash table
    unsigned long used;

} dictht;


```
The table attribute is an array, and each element in the array is a pointer to a dictEntry structure.


![](http://upload-images.jianshu.io/upload_images/1194012-42829b77869a9093.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Each dictEntry stores a key-value pair, as well as a pointer to another dictEntry structure:
```c
/*
 * Hash table node
 */
typedef struct dictEntry {
    // Key
    void *key;
    // Value
    union {
        void *val;
        uint64_t u64;
        int64_t s64;
    } v;
    // Link to the next node
    struct dictEntry *next;

} dictEntry;

```
The `next` attribute points to another `dictEntry` structure. Multiple `dictEntry` instances can be linked together into a linked list via the `next` pointer. From this, we can see that `dictht` uses separate chaining to handle key collisions.


![](http://upload-images.jianshu.io/upload_images/1194012-37c1df2950e1ffff.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Before adding a new key-value pair to the dictionary, `dictAdd` checks the hash table `ht[0]`. For the `size` and `used` attributes of `ht[0]`, if the ratio `ratio = used / size` satisfies either of the following conditions, the rehash process is activated:

Natural rehash: `ratio >= 1`, and the variable `dict_can_resize` is true.  
Forced rehash: `ratio` is greater than the variable `dict_force_resize_ratio` (in the current version, the value of `dict_force_resize_ratio` is `5`).


![](http://upload-images.jianshu.io/upload_images/1194012-fd357229d2076e83.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Suppose the current dictionary needs to be expanded and rehashed. Redis first sets the dictionary’s `rehashidx` to `0`, indicating the start of rehashing; then it allocates space for `ht[1]->table`, with a size of at least twice `ht[0]->used`.


![](http://upload-images.jianshu.io/upload_images/1194012-fb985fba7f7bbb74.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As shown above, space for `ht[1]->table` has already been allocated: 8 slots.

Next, rehashing begins. The key-value pairs in `ht[0]->table` are moved into `ht[1]->table`. This movement is not completed all at once; it is done in multiple steps.


![](http://upload-images.jianshu.io/upload_images/1194012-95b9667d19cd9401.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From the figure above, we can see that some of the key-value pairs in `ht[0]` have already been migrated to `ht[1]`. At this point, if new key-value pairs are inserted, they are inserted directly into `ht[1]` and will no longer be inserted into `ht[0]`. This ensures that `ht[0]` only decreases and never grows.

![](http://upload-images.jianshu.io/upload_images/1194012-df904e16494a54ac.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

During rehashing, new key-value pairs are continuously inserted, and the key-value pairs in `ht[0]` are continuously migrated over until all key-value pairs in `ht[0]` have been moved. Note that Redis uses head insertion: new values are always inserted at the first position of the linked list, so there is no need to traverse to the end of the list, avoiding `O(n)` time complexity. When the process reaches the state shown above, all nodes have been migrated.


Before rehashing finishes, cleanup is performed: release the space used by `ht[0]`; replace `ht[0]` with `ht[1]`, making the original `ht[1]` the new `ht[0]`; create a new empty hash table and set it as `ht[1]`; set the dictionary’s `rehashidx` attribute to `-1`, indicating that rehashing has stopped.

![](http://upload-images.jianshu.io/upload_images/1194012-95fa21ed1b642cf1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


After rehashing completes, the final state is as shown above. If rehashing is needed again later, the same process is repeated. This multi-step, incremental rehashing approach is one of the reasons behind Redis’s high performance.


It is worth mentioning that Redis also supports dictionary reshrinking. The procedure is simply the reverse of rehashing.


## II. Red-Black Tree Optimization

By this point, readers should understand how to control a map so that the probability of hash collisions remains low while the hash bucket array occupies little space. The answer is to choose a good hash algorithm and add an expansion mechanism.


Java further optimized the underlying implementation of `HashMap` in JDK 1.8.


![](http://upload-images.jianshu.io/upload_images/1194012-af15696dfb5cd3d2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above is from a summary on the Meituan tech blog. From it, we can see that:

At the Java implementation level, the initial number of buckets is 16, and the default load factor is 0.75. That is, when the number of key-value pairs first reaches 12, a resize is performed. The threshold for expansion is 64. Once the number of buckets exceeds 64, and the number of colliding nodes is 8 or more, conversion to a red-black tree is triggered. To prevent the underlying linked list from becoming too long, the list is converted into a red-black tree.

In other words, when the total number of buckets has not reached 64, even if the linked list length is 8, conversion to a red-black tree will not occur.

If the number of nodes becomes less than 6, the red-black tree degrades back into a linked list.

Of course, the reason for choosing a red-black tree for this optimization is to ensure that the worst case does not degrade to `O(n)`. A red-black tree can guarantee a worst-case time complexity of `O(log n)`.

The Meituan blog also mentions another optimization in Java JDK 1.8 that is worth learning from. During key-value node migration in Java’s rehash process, there is no need to recompute the hash!

Because expansion is by a power of two (meaning the length is doubled), an element’s position is either its original position or its original position plus a power-of-two offset. The figure below illustrates this. `n` is the length of the table. Figure (a) shows examples of how `key1` and `key2` determine their index positions before expansion, while figure (b) shows examples of how `key1` and `key2` determine their index positions after expansion. Here, `hash1` is the result of applying the high-bit operation to the hash corresponding to `key1`.


![](http://upload-images.jianshu.io/upload_images/1194012-b22e14d592cd3689.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After an element’s hash is recalculated, because `n` becomes twice as large, the mask range of `n-1` gains one more bit in the high position (shown in red). Therefore, the new `index` changes as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-2af3b52fd9efc168.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

So after expansion, you only need to check whether the bit corresponding to the expanded capacity is `0` or `1`. If it is `0`, the index remains unchanged. If it is `1`, the new index equals the original index plus `oldCap`. This eliminates the need to recompute the hash.


![](http://upload-images.jianshu.io/upload_images/1194012-3adf5faf9c793a2b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The figure above shows the case of expanding from 16 to 32.


## III. A Concrete Example of Map Implementation in Go

By this point, readers should have some ideas of their own about how to design a map. Choose an excellent hash algorithm, use a linked list plus an array as the underlying data structure, and understand how to expand and optimize it. Readers may think that this article is already more than halfway through, but everything so far has been fairly theoretical. The next part may be the real focus of this article — analyzing a complete map implementation from scratch.

Next, I will analyze the underlying implementation of `map` in Go. This also serves as a concrete example of how a map is implemented and how several important operations work: adding key-value pairs, deleting key-value pairs, and the expansion strategy.

Go’s `map` implementation is in the file `/src/runtime/hashmap.go`.

At the lowest level, a `map` is essentially still a hash table.

First, let’s look at some constants defined by Go.
```go


const (
	// Maximum number of key-value pairs a bucket can hold: 8.
	bucketCntBits = 3
	bucketCnt     = 1 << bucketCntBits

	// Threshold for the maximum load factor that triggers growth.
	loadFactor = 6.5

	// To keep things inline, keys and values are at most 128 bytes; if they exceed 128 bytes, store their pointers.
	maxKeySize   = 128
	maxValueSize = 128

	// The data offset should be a multiple of bmap, but must be properly aligned.
	dataOffset = unsafe.Offsetof(struct {
		b bmap
		v int64
	}{}.v)

	// Some tophash values.
	empty          = 0 // No key-value pairs.
	evacuatedEmpty = 1 // No key-value pairs, and the bucket's keys and values have been evacuated.
	evacuatedX     = 2 // Key-value pair is valid and has been evacuated to the first half of a table.
	evacuatedY     = 3 // Key-value pair is valid and has been evacuated to the second half of a table.
	minTopHash     = 4 // Minimum tophash.

	// Flags.
	iterator     = 1 // Iterator for current buckets.
	oldIterator  = 2 // Iterator for old buckets.
	hashWriting  = 4 // A goroutine is writing to the map.
	sameSizeGrow = 8 // The current map grows to a new map while keeping the same size.

	// Sentinel for iterator bucket ID checks.
	noCheck = 1<<(8*sys.PtrSize) - 1
)

```
One point worth explaining here is how the threshold value of 6.5 that triggers growth is derived. If this value is too large, it leads to too many overflow buckets and reduced lookup efficiency; if it is too small, it wastes storage space.

According to Google developers, this value is an empirically chosen value measured by a test program.


![](http://upload-images.jianshu.io/upload_images/1194012-9e7d2fb81496e474.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


%overflow:
Overflow rate: on average, how many key-value pairs in a bucket will cause it to overflow.

bytes/entry:
The average number of extra bytes needed to store one key-value pair.

hitprobe:
The average number of probes when looking up an existing key.

missprobe:
The average number of probes when looking up a non-existent key.

Based on these sets of test data, 6.5 was ultimately selected as the critical load factor.

Next, let’s look at the definition of the map header in Go:
```go


type hmap struct {
	count     int // length of the map
	flags     uint8
	B         uint8  // base-2 log of the number of buckets (can store 6.5 * 2^B elements in total)
	noverflow uint16 // approximate number of overflow buckets
	hash0     uint32 // hash seed

	buckets    unsafe.Pointer // array of 2^B buckets. when count==0, this array is nil.
	oldbuckets unsafe.Pointer // half the elements of the old bucket array
	nevacuate  uintptr        // counter during growth

	extra *mapextra // optional field
}


```
In Go’s map header structure, there are also two pointers to bucket arrays: `buckets` points to the new bucket array, and `oldbuckets` points to the old bucket array. This is similar to the two `dictht` arrays in a Redis dictionary.

![](http://upload-images.jianshu.io/upload_images/1194012-ace23e96311a9380.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The last field of `hmap` is a pointer to the `mapextra` structure, defined as follows:
```go

type mapextra struct {
	overflow [2]*[]*bmap
	nextOverflow *bmap
}

```
If a key-value pair cannot find a corresponding pointer, it is first stored in the overflow bucket `overflow`. In `mapextra`, there is also a pointer to the next available overflow bucket.

![](http://upload-images.jianshu.io/upload_images/1194012-882521bbb299d266.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The overflow bucket `overflow` is an array that stores two pointers to `\*bmap` arrays. `overflow[0]` holds `hmap.buckets`. `overflow[1]` holds `hmap.oldbuckets`.


Now let’s look at the definition of the bucket data structure. `bmap` is the struct type corresponding to a bucket in Go’s `map`.
```go


type bmap struct {
	tophash [bucketCnt]uint8
}

```
The definition of a bucket is relatively simple: it only contains an array of type uint8 with 8 elements. These 8 elements store the high 8 bits of the hash value.

After `tophash`, the memory layout contains two more parts. Immediately following `tophash` are 8 key-value pairs. They are arranged as 8 keys stored together, followed by 8 values stored together.

After the 8 key-value pairs comes an `overflow` pointer, which points to the next `bmap`. From this, we can also see that Go maps handle hash collisions using a linked-list approach.


![](http://upload-images.jianshu.io/upload_images/1194012-eeae466067c496fb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Why does Go not store key-value pairs in the ordinary key/value, key/value, key/value... layout? Instead, all keys are stored together, followed by all values. Why is it designed this way?


![](http://upload-images.jianshu.io/upload_images/1194012-03ba2d8b38fd1c7e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In Redis, when a hash table is encoded using REDIS\_ENCODING\_ZIPLIST, the program pushes keys and values into the ziplist together, thereby forming the key-value pair structure needed to store the hash table, as shown above. Newly added key\-value pairs are appended to the tail of the ziplist.

This structure has a drawback: if the stored keys and values have different types and occupy different numbers of bytes in the memory layout, alignment is required. For example, consider storing a dictionary of type `map[int64]int8`.

To reduce the memory overhead caused by alignment, Go designed it as shown in the figure above.

If the map stores trillions of data entries, the memory saved here can still be quite substantial.


### 1. Creating a Map


`makemap` creates a new Map. If the input parameter `h` is not nil, then the map’s `hmap` is this input `hmap`; if the input parameter `bucket` is not nil, then this `bucket` is used as the first bucket.
```go


func makemap(t *maptype, hint int64, h *hmap, bucket unsafe.Pointer) *hmap {
	// invalid hmap size
	if sz := unsafe.Sizeof(hmap{}); sz > 48 || sz != t.hmap.size {
		println("runtime: sizeof(hmap) =", sz, ", t.hmap.size =", t.hmap.size)
		throw("bad hmap size")
	}

	// Set out-of-range hint values to 0
	if hint < 0 || hint > int64(maxSliceCap(t.bucket.size)) {
		hint = 0
	}

	// The key type is not supported by Go
	if !ismapkey(t.key) {
		throw("runtime.makemap: unsupported map key type")
	}

	// Check via the compiler and reflection whether the key size is valid
	if t.key.size > maxKeySize && (!t.indirectkey || t.keysize != uint8(sys.PtrSize)) ||
		t.key.size <= maxKeySize && (t.indirectkey || t.keysize != uint8(t.key.size)) {
		throw("key size wrong")
	}
	// Check via the compiler and reflection whether the value size is valid
	if t.elem.size > maxValueSize && (!t.indirectvalue || t.valuesize != uint8(sys.PtrSize)) ||
		t.elem.size <= maxValueSize && (t.indirectvalue || t.valuesize != uint8(t.elem.size)) {
		throw("value size wrong")
	}

	// Although we don't rely on the following variables and can check these values at compile time,
	// we still check them here.

	// key alignment exceeds the bucket count
	if t.key.align > bucketCnt {
		throw("key align too big")
	}
	// value alignment exceeds the bucket count
	if t.elem.align > bucketCnt {
		throw("value align too big")
	}
	// key size is not a multiple of key alignment
	if t.key.size%uintptr(t.key.align) != 0 {
		throw("key size not a multiple of key align")
	}
	// value size is not a multiple of value alignment
	if t.elem.size%uintptr(t.elem.align) != 0 {
		throw("value size not a multiple of value align")
	}
	// bucket count is too small for proper alignment
	if bucketCnt < 8 {
		throw("bucketsize too small for proper alignment")
	}
	// data offset is not a multiple of key alignment, so padding is needed in the bucket for key
	if dataOffset%uintptr(t.key.align) != 0 {
		throw("need padding in bucket (key)")
	}
	// data offset is not a multiple of value alignment, so padding is needed in the bucket for value
	if dataOffset%uintptr(t.elem.align) != 0 {
		throw("need padding in bucket (value)")
	}

	B := uint8(0)
	for ; overLoadFactor(hint, B); B++ {
	}

	// Allocate memory and initialize the hash table
	// If B = 0 here, the buckets field in hmap is allocated later
	// If hint is large, initializing this memory takes some time.
	buckets := bucket
	var extra *mapextra
	if B != 0 {
		var nextOverflow *bmap
		// Initialize bucket and nextOverflow 
		buckets, nextOverflow = makeBucketArray(t, B)
		if nextOverflow != nil {
			extra = new(mapextra)
			extra.nextOverflow = nextOverflow
		}
	}

	// Initialize hmap
	if h == nil {
		h = (*hmap)(newobject(t.hmap))
	}
	h.count = 0
	h.B = B
	h.extra = extra
	h.flags = 0
	h.hash0 = fastrand()
	h.buckets = buckets
	h.oldbuckets = nil
	h.nevacuate = 0
	h.noverflow = 0

	return h
}


```
The most important part of creating a new map is allocating memory and initializing the hash table. When `B` is non-zero, `mapextra` is also initialized, and `buckets` are regenerated.
```go

func makeBucketArray(t *maptype, b uint8) (buckets unsafe.Pointer, nextOverflow *bmap) {
	base := uintptr(1 << b)
	nbuckets := base
	if b >= 4 {
		nbuckets += 1 << (b - 4)
		sz := t.bucket.size * nbuckets
		up := roundupsize(sz)
		// If requesting buckets of size sz, the system can only return memory of size up, so the number of buckets is up / t.bucket.size
		if up != sz {
			nbuckets = up / t.bucket.size
		}
	}
	buckets = newarray(t.bucket, int(nbuckets))
	// When b > 4 and the computed number of buckets is not equal to 1 << b,
	if base != nbuckets {
		// At this point nbuckets is larger than base, so nbuckets - base nextOverflow buckets are preallocated
		nextOverflow = (*bmap)(add(buckets, base*uintptr(t.bucketsize)))
		last := (*bmap)(add(buckets, (nbuckets-1)*uintptr(t.bucketsize)))
		last.setoverflow(t, (*bmap)(buckets))
	}
	return buckets, nextOverflow
}


```
Here, `newarray` is already `mallocgc`.

From the code above, we can see that only when `B >= 4` will `makeBucketArray` create a `nextOverflow` pointer that points to a `bmap`, and therefore `mapextra` will only be created when the `Map` creates the `hmap`.


When `B = 3` (`B < 4`), initializing the `hmap` creates only 8 buckets.

![](http://upload-images.jianshu.io/upload_images/1194012-86bcbb58845adaa2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


When `B = 4` (`B >= 4`), initializing the `hmap` also creates an additional `mapextra` and initializes `nextOverflow`. The `nextOverflow` pointer in `mapextra` points to the end of the 16th bucket, i.e., the start address of the 17th bucket. In the 17th bucket (counting from 0, that is, the bucket with index 16), a pointer is stored starting at the address `bucketsize - sys.PtrSize`. This pointer points to the start address of the current entire bucket. This pointer is the `overflow` pointer of `bmap`.


![](http://upload-images.jianshu.io/upload_images/1194012-d8c3208be625d211.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


When `B = 5` (`B >= 4`), initializing the `hmap` also creates an additional `mapextra` and initializes `nextOverflow`. At this point, a total of 34 buckets are created. Similarly, an `overflow` pointer is stored starting at the address equal to the size of the last bucket minus the size of one pointer.


![](http://upload-images.jianshu.io/upload_images/1194012-8024ec35514b8780.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


### 2. Looking Up a Key

In Go, when looking up a key that does not exist in a map, the lookup does not return `nil`; instead, it returns the zero value of the current type. For example, a string returns an empty string, and an `int` returns `0`.
```go


func mapaccess1(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer {
	if raceenabled && h != nil {
		// Get the caller's program counter
		callerpc := getcallerpc(unsafe.Pointer(&t))
		// Get mapaccess1's program counter
		pc := funcPC(mapaccess1)
		racereadpc(unsafe.Pointer(h), callerpc, pc)
		raceReadObjectPC(t.key, key, callerpc, pc)
	}
	if msanenabled && h != nil {
		msanread(key, t.key.size) 
	}
	if h == nil || h.count == 0 {
		return unsafe.Pointer(&zeroVal[0])
	}
	// If multiple threads read and write, throw immediately
	// Concurrency check: Go hashmap does not support concurrent access
	if h.flags&hashWriting != 0 {
		throw("concurrent map read and map write")
	}
	alg := t.key.alg
	// Compute the key's hash value
	hash := alg.hash(key, uintptr(h.hash0))
	m := uintptr(1)<<h.B - 1
	// hash % (1<<B - 1) finds which bucket the key is in
	b := (*bmap)(add(h.buckets, (hash&m)*uintptr(t.bucketsize)))
	// If oldbuckets buckets currently still exist
	if c := h.oldbuckets; c != nil {
		// The current grow is not same-size
		if !h.sameSizeGrow() {
			// If oldbuckets has not finished migrating, look for the corresponding bucket in oldbuckets (low B-1 bits)
			// Otherwise, use the bucket in buckets (low B bits)
			// Halve the mask
			m >>= 1
		}
		
		oldb := (*bmap)(add(c, (hash&m)*uintptr(t.bucketsize)))
		if !evacuated(oldb) {
			// If the oldbuckets bucket exists and has not been evacuated, look up the key in the old bucket 
			b = oldb
		}
	}
	// Take the high 8 bits of the hash value
	top := uint8(hash >> (sys.PtrSize*8 - 8))
	// If top is less than minTopHash, add the minTopHash offset to it.
	// Because numbers in the range 0 - minTopHash are already used as marker bits
	if top < minTopHash {
		top += minTopHash
	}
	for {
		for i := uintptr(0); i < bucketCnt; i++ {
			// If the high 8 bits of the hash differ from the current key record, look at the next one
			// This comparison is very efficient because it only compares the high 8 bits, not all hash values
			// If the high 8 bits differ, the hash values must differ; if they are the same, compare the full hash value
			if b.tophash[i] != top {
				continue
			}
			// Get the key value by offset: bmap base address + offset of i key-size units
			k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
			if t.indirectkey {
				k = *((*unsafe.Pointer)(k))
			}
			// Compare whether the key values are equal
			if alg.equal(key, k) {
				// If the key is found, get the value
				// Get the value by offset: bmap base address + offset of 8 key-size units + offset of i value-size units
				v := add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.valuesize))
				if t.indirectvalue {
					v = *((*unsafe.Pointer)(v))
				}
				return v
			}
		}
		// If the corresponding key is not found in the current bucket, go to the next bucket
		b = b.overflow(t)
		// If b == nil, all buckets have been searched; return the zero value of the corresponding type
		if b == nil {
			return unsafe.Pointer(&zeroVal[0])
		}
	}
}


```
The concrete implementation code is shown above; see the code for detailed explanations.


![](http://upload-images.jianshu.io/upload_images/1194012-d75a575d0ac21317.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown above, this is the complete process of looking up a key.

First, compute the hash value corresponding to the key, then take the hash value modulo B.

There is an optimization here. For the computation `m % n`, if n is a multiple of 2, the modulo operation can be eliminated.
```go

m % n = m & ( n - 1 ) 


```
This optimization avoids the expensive modulo operation. In this example, the computed value extracted is 0010, which is 2, so it corresponds to the 3rd bucket in the bucket array. Why the 3rd bucket? The base address points to bucket 0; offsetting downward by the size of 2 buckets brings us to the base address of the 3rd bucket. For the concrete implementation, see the code above.

The low B bits of the hash determine which bucket in the bucket array is used, while the high 8 bits of the hash determine which slot in the tophash array of this bucket array’s bmap the key may be in. As shown above, the high 8 bits of the hash are compared against each value in the tophash array. If the high 8 bits are not equal to tophash[i], it proceeds directly to the next one. If they are equal, it retrieves the corresponding full key from the bmap and compares it again to check whether it matches exactly.

The entire lookup process first searches in oldbucket (if lodbucket exists), and after that searches in the new bmap.

Some people may wonder: why add this extra comparison with tophash?

tophash is introduced to speed up lookups. Since it stores only the high 8 bits of the hash value, it is much faster than checking the full 64-bit value. By comparing the high 8 bits, it can quickly find an index whose hash value has matching high 8 bits. It then performs one full comparison; if that also matches, the key is considered found.

If the key is found, the corresponding value is returned. If it is not found, the lookup continues through the overflow buckets until the last bucket is reached. If it still is not found, the zero value of the corresponding type is returned.


### 3. Inserting a Key

The process of inserting a key is largely the same as the process of looking up a key.
```go

func mapassign(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer {
	if h == nil {
		panic(plainError("assignment to entry in nil map"))
	}
	if raceenabled {
		// Get the caller's program counter
		callerpc := getcallerpc(unsafe.Pointer(&t))
		// Get mapassign's program counter
		pc := funcPC(mapassign)
		racewritepc(unsafe.Pointer(h), callerpc, pc)
		raceReadObjectPC(t.key, key, callerpc, pc)
	}
	if msanenabled {
		msanread(key, t.key.size)
	}
	// If multiple threads read and write, throw an exception directly
	// Concurrency check: go hashmap does not support concurrent access
	if h.flags&hashWriting != 0 {
		throw("concurrent map writes")
	}
	alg := t.key.alg
	// Compute the hash value of the key
	hash := alg.hash(key, uintptr(h.hash0))

	// Set hashWriting immediately after computing the hash; if the write is not complete during hash computation, it may cause a panic
	h.flags |= hashWriting

	// If the hmap has zero buckets, create a new bucket
	if h.buckets == nil {
		h.buckets = newarray(t.bucket, 1)
	}

again:
    // Take the hash value modulo B to find the bucket
	bucket := hash & (uintptr(1)<<h.B - 1)
	// If still growing, continue growing
	if h.growing() {
		growWork(t, h, bucket)
	}
	// Use the low B bits of the hash to find the bucket
	b := (*bmap)(unsafe.Pointer(uintptr(h.buckets) + bucket*uintptr(t.bucketsize)))
	// Compute the high 8 bits of the hash
	top := uint8(hash >> (sys.PtrSize*8 - 8))
	if top < minTopHash {
		top += minTopHash
	}

	var inserti *uint8
	var insertk unsafe.Pointer
	var val unsafe.Pointer
	for {
		// Iterate over all key-values in the current bucket to find the value for key
		for i := uintptr(0); i < bucketCnt; i++ {
			if b.tophash[i] != top {
				if b.tophash[i] == empty && inserti == nil {
					// If nothing is found later, first record a marker here so it can be inserted here
					inserti = &b.tophash[i]
					// Compute the position offset by i key values
					insertk = add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
					// Compute the position of val: the bucket start address + size of 8 key values + size of i value values
					val = add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.valuesize))
				}
				continue
			}
			// Get each key value in turn
			k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
			// If the key value is a pointer, dereference it to get the corresponding key value
			if t.indirectkey {
				k = *((*unsafe.Pointer)(k))
			}
			// Compare whether the key values are equal
			if !alg.equal(key, k) {
				continue
			}
			// If an update is needed, copy t.key from k to key
			if t.needkeyupdate {
				typedmemmove(t.key, k, key)
			}
			// Compute the position of val: the bucket start address + size of 8 key values + size of i value values
			val = add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.valuesize))
			goto done
		}
		ovf := b.overflow(t)
		if ovf == nil {
			break
		}
		b = ovf
	}

	// The current key value was not found, and check the maximum load factor; if it reaches the maximum load factor or there are many overflow buckets
	if !h.growing() && (overLoadFactor(int64(h.count), h.B) || tooManyOverflowBuckets(h.noverflow, h.B)) {
		// Start growing
		hashGrow(t, h)
		goto again // Growing the table invalidates everything, so try again
	}
	// If no empty position can be found to insert the key value
	if inserti == nil {
		// all current buckets are full, allocate a new one.
		// This means the current bucket is completely full, so create a new one
		newb := h.newoverflow(t, b)
		inserti = &newb.tophash[0]
		insertk = add(unsafe.Pointer(newb), dataOffset)
		val = add(insertk, bucketCnt*uintptr(t.keysize))
	}

	// store new key/value at insert position
	if t.indirectkey {
		// If storing a key pointer, use insertk here to store the key's address
		kmem := newobject(t.key)
		*(*unsafe.Pointer)(insertk) = kmem
		insertk = kmem
	}
	if t.indirectvalue {
		// If storing a value pointer, use val here to store the key's address
		vmem := newobject(t.elem)
		*(*unsafe.Pointer)(val) = vmem
	}
	// Copy t.key from insertk to the key position
	typedmemmove(t.key, insertk, key)
	*inserti = top
	// Total number of key values stored in hmap + 1
	h.count++

done:
	// Disallow concurrent writes
	if h.flags&hashWriting == 0 {
		throw("concurrent map writes")
	}
	h.flags &^= hashWriting
	if t.indirectvalue {
		// If a pointer is stored in value, get the value pointed to by that pointer
		val = *((*unsafe.Pointer)(val))
	}
	return val
}


```
During key insertion, there are a few differences from key lookup that you need to be aware of:

- 1. If the key to be inserted is found, simply update the corresponding value.
- 2. If the key to be inserted is not found in the bmap, there are several possible cases.
Case 1: There is still an empty slot in the bmap. While traversing the bmap, record an empty slot in advance. If the traversal completes without finding the key, place the key into the previously recorded empty slot.
Case 2: There are no empty slots left in the bmap. At this point, the bmap is already very full. You need to check whether the maximum load factor has been reached. If it has, grow the map immediately. After growth, insert the key into the new bucket; the process is the same as described above. If the maximum load factor has not been reached, create a new bmap and point the previous bmap’s overflow pointer to the new bmap.
- 3. During growth, oldbucket is frozen. When looking up a key, the lookup will check
 oldbucket, but data will not be inserted into oldbucket. If the corresponding key is found in
oldbucket, it is migrated to the new bmap and then marked as
 evacuated.


The rest of the process is basically the same as key lookup, so it will not be repeated here.


### 3. Deleting a Key
```go

func mapdelete(t *maptype, h *hmap, key unsafe.Pointer) {
	if raceenabled && h != nil {
		// Get the caller's program counter
		callerpc := getcallerpc(unsafe.Pointer(&t))
		// Get mapdelete's program counter
		pc := funcPC(mapdelete)
		racewritepc(unsafe.Pointer(h), callerpc, pc)
		raceReadObjectPC(t.key, key, callerpc, pc)
	}
	if msanenabled && h != nil {
		msanread(key, t.key.size)
	}
	if h == nil || h.count == 0 {
		return
	}
	// If multiple threads read and write, throw immediately
	// Concurrency check: Go hashmap does not support concurrent access
	if h.flags&hashWriting != 0 {
		throw("concurrent map writes")
	}

	alg := t.key.alg
	// Compute the key's hash value
	hash := alg.hash(key, uintptr(h.hash0))

	// Set hashWriting immediately after computing the hash; if a write did not complete during hash computation, it may cause a panic
	h.flags |= hashWriting

	bucket := hash & (uintptr(1)<<h.B - 1)
	// If still growing, continue growing
	if h.growing() {
		growWork(t, h, bucket)
	}
	// Use the low B bits of the hash to find the bucket
	b := (*bmap)(unsafe.Pointer(uintptr(h.buckets) + bucket*uintptr(t.bucketsize)))
	// Compute the top 8 bits of the hash
	top := uint8(hash >> (sys.PtrSize*8 - 8))
	if top < minTopHash {
		top += minTopHash
	}
	for {
		// Iterate over all entries in the current bucket to find the value for key
		for i := uintptr(0); i < bucketCnt; i++ {
			if b.tophash[i] != top {
				continue
			}
			k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
			// If k is a pointer to the key, dereference it here
			k2 := k
			if t.indirectkey {
				k2 = *((*unsafe.Pointer)(k2))
			}
			if !alg.equal(key, k2) {
				continue
			}
			// Set the key pointer to nil
			if t.indirectkey {
				*(*unsafe.Pointer)(k) = nil
			} else {
			// Clear the key's memory
				typedmemclr(t.key, k)
			}
			v := unsafe.Pointer(uintptr(unsafe.Pointer(b)) + dataOffset + bucketCnt*uintptr(t.keysize) + i*uintptr(t.valuesize))
			// Set the value pointer to nil
			if t.indirectvalue {
				*(*unsafe.Pointer)(v) = nil
			} else {
			// Clear the value's memory
				typedmemclr(t.elem, v)
			}
			// Clear the value in tophash
			b.tophash[i] = empty
			// Decrement the total number of keys in the map by 1
			h.count--
			goto done
		}
		// If not found, continue searching overflow buckets until the last one
		b = b.overflow(t)
		if b == nil {
			goto done
		}
	}

done:
	if h.flags&hashWriting == 0 {
		throw("concurrent map writes")
	}
	h.flags &^= hashWriting
}

```
The main flow of deletion is also roughly the same as the key lookup flow. After finding the corresponding key, if it is a pointer to the original key, the pointer is set to nil. If it is a value, the memory where it resides is cleared. The value in `tophash` also needs to be cleaned up, and finally the map’s total key-count counter is decremented by 1.

If expansion is in progress, the delete operation will delete the key from the new `bmap` after the expansion step.

The lookup process still traverses all the way to the last `bmap` bucket in the linked list.

### 4. Incremental Doubling Expansion

This part can be considered one of the core pieces of the entire Map implementation. We all know that as a Map keeps loading key values, lookup efficiency becomes lower and lower. If expansion is not performed at this point, hash collisions will make the linked list longer and longer, and performance will continue to degrade. Expansion is inevitable.

However, if key-value writes are blocked during expansion, processing large amounts of data can lead to a period of unresponsiveness. In a highly real-time system, every expansion could cause the system to pause for several seconds, during which it cannot respond to any requests. This level of performance is clearly unacceptable. Therefore, expansion needs to proceed while writes continue unaffected. This is where incremental expansion comes in.

Incremental expansion is already widely used. Redis, mentioned earlier as an example, uses an incremental expansion strategy.

Next, let’s look at how Go performs incremental expansion.

When inserting key values in Go’s `mapassign` and deleting key values in `mapdelete`, Go checks whether expansion is currently in progress.
```go

func growWork(t *maptype, h *hmap, bucket uintptr) {
	// Ensure we've evacuated all oldbuckets
	evacuate(t, h, bucket&h.oldbucketmask())

	// Then evacuate one more marked bucket
	if h.growing() {
		evacuate(t, h, h.nevacuate)
	}
}

```
From this, we can see that each execution of `growWork` migrates two buckets. One is the current bucket, which counts as a local migration; the other is the bucket pointed to by `nevacuate` in `hmap`, which counts as an incremental migration.

When inserting a key, if the map is currently growing, `oldbucket` is frozen. Lookups will first search in `oldbucket`, but data will not be inserted into `oldbucket`. Only if the corresponding key is found in `oldbucket` will it be migrated to the new bucket and marked as evacuated.

When deleting a key, if the map is currently growing, the bucket—the new bucket—is searched first. Once the key is found, its corresponding key and value are both cleared. If it cannot be found in the bucket, only then will `oldbucket` be searched.

Each time a key is inserted, the current load factor is checked to see whether it exceeds 6.5. If it has reached this limit, the grow operation `hashGrow` is executed immediately. This is the preparation work before growing.
```go


func hashGrow(t *maptype, h *hmap) {
	// If the maximum load factor is reached, grow.
	// Otherwise, a bucket's linked list will be followed by many overflow buckets
	bigger := uint8(1)
	if !overLoadFactor(int64(h.count), h.B) {
		bigger = 0
		h.flags |= sameSizeGrow
	}
	// Point hmap's old bucket pointer to the current buckets
	oldbuckets := h.buckets
	// Create new buckets after growth; hmap's buckets pointer points to the grown buckets.
	newbuckets, nextOverflow := makeBucketArray(t, h.B+bigger)

	flags := h.flags &^ (iterator | oldIterator)
	if h.flags&iterator != 0 {
		flags |= oldIterator
	}
	// Add the new value to B
	h.B += bigger
	h.flags = flags
	// Point the old bucket pointer to the current buckets
	h.oldbuckets = oldbuckets
	// Point the new bucket pointer to the grown buckets
	h.buckets = newbuckets
	h.nevacuate = 0
	h.noverflow = 0

	if h.extra != nil && h.extra.overflow[0] != nil {
		if h.extra.overflow[1] != nil {
			throw("overflow is not nil")
		}
		// Swap what overflow[0] and overflow[1] point to
		h.extra.overflow[1] = h.extra.overflow[0]
		h.extra.overflow[0] = nil
	}
	if nextOverflow != nil {
		if h.extra == nil {
			// Create mapextra
			h.extra = new(mapextra)
		}
		h.extra.nextOverflow = nextOverflow
	}

	// The actual copying of key-value pairs happens in evacuate()
}


```
Represent its flow with a diagram:


![](http://upload-images.jianshu.io/upload_images/1194012-2f6ba465d8aed6ef.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The hashGrow operation is essentially the preparation work before growing the map; the actual copying happens in evacuate.

The hashGrow operation first creates the new bucket array after growth. The size of the new bucket array is twice the previous size. Then hmap's buckets points to this newly expanded bucket array, while oldbuckets points to the current bucket array.

After hmap is handled, mapextra is processed: nextOverflow is made to point to the original overflow pointer, and the overflow pointer is set to nil.

At this point, the preparation work before growing the map is complete.
```go

func evacuate(t *maptype, h *hmap, oldbucket uintptr) {
	b := (*bmap)(add(h.oldbuckets, oldbucket*uintptr(t.bucketsize)))
	// Number of buckets before preparing to grow
	newbit := h.noldbuckets()
	alg := t.key.alg
	if !evacuated(b) {
		// TODO: reuse overflow buckets instead of using new ones, if there
		// is no iterator using the old buckets.  (If !oldIterator.)

		var (
			x, y   *bmap          // Low and high buckets in the new bucket array
			xi, yi int            // Indices for key and value are xi and yi respectively
			xk, yk unsafe.Pointer // Pointers to key values in x and y
			xv, yv unsafe.Pointer // Pointers to values in x and y
		)
		// Low buckets in the new bucket array
		x = (*bmap)(add(h.buckets, oldbucket*uintptr(t.bucketsize)))
		xi = 0
		// First key in the low bucket after growing
		xk = add(unsafe.Pointer(x), dataOffset)
		// Value corresponding to the first key in the low bucket after growing
		xv = add(xk, bucketCnt*uintptr(t.keysize))
		// If this is not a same-size grow
		if !h.sameSizeGrow() {
			y = (*bmap)(add(h.buckets, (oldbucket+newbit)*uintptr(t.bucketsize)))
			yi = 0
			yk = add(unsafe.Pointer(y), dataOffset)
			yv = add(yk, bucketCnt*uintptr(t.keysize))
		}
		// Iterate over overflow buckets in order
		for ; b != nil; b = b.overflow(t) {
			k := add(unsafe.Pointer(b), dataOffset)
			v := add(k, bucketCnt*uintptr(t.keysize))
			// Iterate over key-value pairs
			for i := 0; i < bucketCnt; i, k, v = i+1, add(k, uintptr(t.keysize)), add(v, uintptr(t.valuesize)) {
				top := b.tophash[i]
				if top == empty {
					b.tophash[i] = evacuatedEmpty
					continue
				}
				if top < minTopHash {
					throw("bad map state")
				}
				k2 := k
				// If the key is a pointer, dereference it
				if t.indirectkey {
					k2 = *((*unsafe.Pointer)(k2))
				}
				useX := true
				if !h.sameSizeGrow() {
					// If not a same-size grow, recompute the hash to decide whether it goes to bucket x or y
					hash := alg.hash(k2, uintptr(h.hash0))
					if h.flags&iterator != 0 {
						if !t.reflexivekey && !alg.equal(k2, k2) {
							// If two keys are not equal, their old hash values are most likely also unequal.
							// tophash is not very meaningful for keys being evacuated, so use its low bit to help growing and mark state.
							// Recompute new random hash values for the next level so these keys remain evenly distributed across all buckets after multiple grows
							// Check whether the lowest bit of top is 1
							if top&1 != 0 {
								hash |= newbit
							} else {
								hash &^= newbit
							}
							top = uint8(hash >> (sys.PtrSize*8 - 8))
							if top < minTopHash {
								top += minTopHash
							}
						}
					}
					useX = hash&newbit == 0
				}
				if useX {
					// Mark in tophash that this goes to the low bucket
					b.tophash[i] = evacuatedX
					// If the key index reaches the end of the bucket, create a new overflow bucket
					if xi == bucketCnt {
						newx := h.newoverflow(t, x)
						x = newx
						xi = 0
						xk = add(unsafe.Pointer(x), dataOffset)
						xv = add(xk, bucketCnt*uintptr(t.keysize))
					}
					// Store the high 8 bits of the hash in tophash again
					x.tophash[xi] = top
					if t.indirectkey {
						// If the key is indirect, copy the pointer
						*(*unsafe.Pointer)(xk) = k2 // copy pointer
					} else {
						// If the key is direct, copy the value
						typedmemmove(t.key, xk, k) // copy value
					}
					// Copy the value similarly
					if t.indirectvalue {
						*(*unsafe.Pointer)(xv) = *(*unsafe.Pointer)(v)
					} else {
						typedmemmove(t.elem, xv, v)
					}
					// Continue migrating the next one
					xi++
					xk = add(xk, uintptr(t.keysize))
					xv = add(xv, uintptr(t.valuesize))
				} else {
					// This is high bucket y; migration is the same as low bucket x above, so no further details here
					b.tophash[i] = evacuatedY
					if yi == bucketCnt {
						newy := h.newoverflow(t, y)
						y = newy
						yi = 0
						yk = add(unsafe.Pointer(y), dataOffset)
						yv = add(yk, bucketCnt*uintptr(t.keysize))
					}
					y.tophash[yi] = top
					if t.indirectkey {
						*(*unsafe.Pointer)(yk) = k2
					} else {
						typedmemmove(t.key, yk, k)
					}
					if t.indirectvalue {
						*(*unsafe.Pointer)(yv) = *(*unsafe.Pointer)(v)
					} else {
						typedmemmove(t.elem, yv, v)
					}
					yi++
					yk = add(yk, uintptr(t.keysize))
					yv = add(yv, uintptr(t.valuesize))
				}
			}
		}
		// Unlink the overflow buckets & clear key/value to help GC.
		if h.flags&oldIterator == 0 {
			b = (*bmap)(add(h.oldbuckets, oldbucket*uintptr(t.bucketsize)))
			// Preserve b.tophash because the evacuation
			// state is maintained there.
			if t.bucket.kind&kindNoPointers == 0 {
				memclrHasPointers(add(unsafe.Pointer(b), dataOffset), uintptr(t.bucketsize)-dataOffset)
			} else {
				memclrNoHeapPointers(add(unsafe.Pointer(b), dataOffset), uintptr(t.bucketsize)-dataOffset)
			}
		}
	}

	// Advance evacuation mark
	if oldbucket == h.nevacuate {
		h.nevacuate = oldbucket + 1
		// Experiments suggest that 1024 is overkill by at least an order of magnitude.
		// Put it in there as a safeguard anyway, to ensure O(1) behavior.
		stop := h.nevacuate + 1024
		if stop > newbit {
			stop = newbit
		}
		for h.nevacuate != stop && bucketEvacuated(t, h, h.nevacuate) {
			h.nevacuate++
		}
		if h.nevacuate == newbit { // newbit == # of oldbuckets
			// Growing is all done. Free old main bucket array.
			h.oldbuckets = nil
			// Can discard old overflow buckets as well.
			// If they are still referenced by an iterator,
			// then the iterator holds a pointers to the slice.
			if h.extra != nil {
				h.extra.overflow[1] = nil
			}
			h.flags &^= sameSizeGrow
		}
	}
}


```
The function above is the core copy operation in the migration process.

The overall migration process is not difficult. What needs to be clarified here is what x and y represent. After growing, the new bucket array is twice the size of the original bucket array. x represents the lower half of the new bucket array, and y represents the upper half. The other variables are mostly markers, cursors, and markers indicating the original positions of key-value pairs. See the code comments for details.


![](http://upload-images.jianshu.io/upload_images/1194012-96e2683243dde73b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above shows the process after migration begins. You can see that buckets in the old bucket array are being migrated to the new buckets, while new key values are also continuously being written into the new buckets.


![](http://upload-images.jianshu.io/upload_images/1194012-000b0c6bc2c9bfb3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Key-value pairs are copied continuously until all key-value pairs in the old buckets have been copied into the new buckets.


![](http://upload-images.jianshu.io/upload_images/1194012-795dc0e1b66bd1e0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The final step is to release the old buckets and set the oldbuckets pointer to null. At this point, one migration process is completely finished.

### 5. Same-Size Growth

Strictly speaking, this approach cannot really be considered growth. But since the function name is Grow, let’s call it that for now.

Starting from Go 1.8, sameSizeGrow was added. When the number of overflow buckets
exceeds a certain threshold (2^B) but the load factor has not yet reached 6.5, there may be some partially empty buckets, meaning bucket utilization is low. In this case, sameSizeGrow is triggered: B remains unchanged, but the data migration process is performed to compactly rearrange the data from oldbuckets and improve bucket utilization. Of course, during sameSizeGrow, loadFactorGrow will not be triggered.


## IV. Some Optimizations in the Map Implementation

At this point, I believe readers should have a clear idea of how to design and implement a Map, including the implementation of the various Map operations. Before exploring how to implement a thread-safe Map, let’s briefly summarize some of the highlights and optimizations discussed earlier.


In Redis, incremental growth is used to handle hash collisions. When the average lookup length exceeds 5, incremental growth is triggered to ensure high performance of the hash table.

At the same time, Redis uses head insertion to ensure good performance when inserting key values.

In Java, when the number of buckets exceeds 64 and the number of colliding nodes is 8 or greater, conversion to a red-black tree is triggered. This ensures that even when the linked list becomes long, the lookup length does not remain too large; and the red-black tree guarantees O(log n) time complexity even in the worst case.

Java has a very good design after migration: it only needs to compare whether the highest bit of the bucket count after migration is 0. If it is 0, the key’s relative position in the new bucket remains unchanged; if it is 1, adding the old bucket count oldCap gives the new position.


There are many optimizations in Go:

1. The hash algorithm uses the efficient memhash algorithm and the CPU AES instruction set. The AES instruction set fully leverages CPU hardware characteristics, making hash computation extremely efficient.  
2. The layout of key-value pairs is designed so that keys are stored together and values are stored together, rather than arranging key and value pairs side by side. This makes memory alignment easier and, as the data volume grows, reduces some of the waste caused by memory alignment.  
3. When the memory size of a key or value exceeds 128 bytes, it is automatically converted to store a pointer.  
4. The design of the tophash array accelerates the key lookup process. tophash is also reused to mark state during growth operations.  
5. Bit operations are used to replace modulo operations. For m % n, when n = 1 << B, it can be converted to m & (1<<B - 1).  
6. Incremental growth.  
7. Same-size growth, i.e. compaction.  
8. After Go 1.9, Map natively supports thread safety. (This topic will be discussed in detail in the next chapter.)  

Of course, there are still some areas in Go that could be further optimized:

1. During migration, the current version does not reuse overflow buckets, but directly allocates new buckets. This could be optimized to preferentially reuse overflow buckets that no pointers point to, and only allocate new ones when none are available. The author has already written this in the TODO.
2. Dynamically merge multiple empty buckets.
3. The current version has no shrink operation; Map can only grow and cannot shrink. Redis has a related implementation for this.


(Given the length of a single article, the entire thread-safety section will be covered in the next article, which will be updated shortly.)


------------------------------------------------------

Reference:  
*Algorithms and Data Structures*  
*Redis Design and Implementation*    
[xxHash](http://cyan4973.github.io/xxHash/)  
[String hash functions](https://www.biaodianfu.com/hash.html)  
[General Purpose Hash Function Algorithms](http://www.partow.net/programming/hashfunctions/index.html)  
[Revisiting HashMap in the Java 8 Series](https://tech.meituan.com/java-hashmap.html)  

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map/](https://halfrost.com/go_map/)