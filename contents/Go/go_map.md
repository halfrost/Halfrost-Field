# 如何设计并实现一个线程安全的 Map ？

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-ae74a3ad86c9b3fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



Map 是一种很常见的数据结构，用于存储一些无序的键值对。在主流的编程语言中，默认就自带它的实现。C、C++ 中的 STL 就实现了 Map，JavaScript 中也有 Map，Java 中有 HashMap，Swift 和 Python 中有 Dictionary，Go 中有 Map，Objective-C 中有 NSDictionary、NSMutableDictionary。

上面这些 Map 都是线程安全的么？答案是否定的，并非全是线程安全的。那如何能实现一个线程安全的 Map 呢？想回答这个问题，需要先从如何实现一个 Map 说起。

## 一. 选用什么数据结构实现 Map ？

Map 是一个非常常用的数据结构，一个无序的 key/value 对的集合，其中 Map 所有的 key 都是不同的，然后通过给定的 key 可以在常数时间 O(1) 复杂度内查找、更新或删除对应的 value。

要想实现常数级的查找，应该用什么来实现呢？读者应该很快会想到哈希表。确实，Map 底层一般都是使用数组来实现，会借用哈希算法辅助。对于给定的 key，一般先进行 hash 操作，然后相对哈希表的长度取模，将 key 映射到指定的地方。


![](http://upload-images.jianshu.io/upload_images/1194012-204724b103dadb0e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


哈希算法有很多种，选哪一种更加高效呢？

### 1. 哈希函数




![](http://upload-images.jianshu.io/upload_images/1194012-a6432423733b54a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





MD5 和 SHA1 可以说是目前应用最广泛的 Hash 算法，而它们都是以 MD4 为基础设计的。

MD4(RFC 1320) 是 MIT 的Ronald L. Rivest 在 1990 年设计的，MD 是 Message Digest（消息摘要） 的缩写。它适用在32位字长的处理器上用高速软件实现——它是基于 32位操作数的位操作来实现的。
MD5(RFC 1321) 是 Rivest 于1991年对 MD4 的改进版本。它对输入仍以512位分组，其输出是4个32位字的级联，与 MD4 相同。MD5 比 MD4 来得复杂，并且速度较之要慢一点，但更安全，在抗分析和抗差分方面表现更好。

SHA1 是由 NIST NSA 设计为同 DSA 一起使用的，它对长度小于264的输入，产生长度为160bit 的散列值，因此抗穷举 (brute-force)
性更好。SHA-1 设计时基于和 MD4 相同原理,并且模仿了该算法。


常用的 hash 函数有 SHA-1，SHA-256，SHA-512，MD5 。这些都是经典的 hash 算法。在现代化生产中，还会用到现代的 hash 算法。下面列举几个，进行性能对比，最后再选其中一个源码分析一下实现过程。

#### （1） Jenkins Hash 和 SpookyHash





![](http://upload-images.jianshu.io/upload_images/1194012-764eab08d0749ad9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





1997年 [Bob Jenkins](http://burtleburtle.net/bob/) 在《 Dr. Dobbs Journal》杂志上发表了一片关于散列函数的文章[《A hash function for hash Table lookup》](http://www.burtleburtle.net/bob/hash/doobs.html)。这篇文章中，Bob 广泛收录了很多已有的散列函数，这其中也包括了他自己所谓的“lookup2”。随后在2006年，Bob 发布了 [lookup3](http://burtleburtle.net/bob/c/lookup3.c)。lookup3 即为 Jenkins Hash。更多有关 Bob’s 散列函数的内容请参阅维基百科：[Jenkins hash function](http://en.wikipedia.org/wiki/Jenkins_hash_function)。memcached的 hash 算法，支持两种算法：jenkins, murmur3，默认是 jenkins。

2011年 Bob Jenkins 发布了他自己的一个新散列函数
SpookyHash（这样命名是因为它是在万圣节发布的）。它们都拥有2倍于 MurmurHash 的速度，但他们都只使用了64位数学函数而没有32位版本，SpookyHash 给出128位输出。

#### （2） MurmurHash


![](http://upload-images.jianshu.io/upload_images/1194012-d831141d81fdf7a5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



MurmurHash 是一种非[加密](https://zh.wikipedia.org/wiki/%E5%8A%A0%E5%AF%86)型[哈希函数](https://zh.wikipedia.org/wiki/%E5%93%88%E5%B8%8C%E5%87%BD%E6%95%B0)，适用于一般的哈希检索操作。
Austin Appleby 在2008年发布了一个新的散列函数——[MurmurHash](https://en.wikipedia.org/wiki/MurmurHash)。其最新版本大约是 lookup3 速度的2倍（大约为1 byte/cycle），它有32位和64位两个版本。32位版本只使用32位数学函数并给出一个32位的哈希值，而64位版本使用了64位的数学函数，并给出64位哈希值。根据Austin的分析，MurmurHash具有优异的性能，虽然 Bob Jenkins 在《Dr. Dobbs article》杂志上声称“我预测 MurmurHash 比起lookup3要弱，但是我不知道具体值，因为我还没测试过它”。MurmurHash能够迅速走红得益于其出色的速度和统计特性。当前的版本是MurmurHash3，Redis、Memcached、Cassandra、HBase、Lucene都在使用它。


#### （3） CityHash 和 FramHash




![](http://upload-images.jianshu.io/upload_images/1194012-53235045a3fd8cb7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这两种算法都是 Google 发布的字符串算法。

[CityHash](https://github.com/google/cityhash) 是2011年 Google 发布的字符串散列算法，和 murmurhash 一样，属于非加密型 hash 算法。CityHash 算法的开发是受到了 MurmurHash 的启发。其主要优点是大部分步骤包含了至少两步独立的数学运算。现代 CPU 通常能从这种代码获得最佳性能。CityHash 也有其缺点：代码较同类流行算法复杂。Google 希望为速度而不是为了简单而优化，因此没有照顾较短输入的特例。Google发布的有两种算法：cityhash64 与 cityhash128。它们分别根据字串计算 64 和 128 位的散列值。这些算法不适用于加密，但适合用在散列表等处。CityHash 的速度取决于CRC32 指令，目前为SSE 4.2（Intel Nehalem及以后版本）。

相比 Murmurhash 支持32、64、128bit， Cityhash支持64、128、256bit 。

2014年 Google 又发布了 [FarmHash](https://github.com/google/farmhash)，一个新的用于字符串的哈希函数系列。FarmHash 从 CityHash 继承了许多技巧和技术，是它的后继。FarmHash 有多个目标，声称从多个方面改进了 CityHash。与 CityHash 相比，FarmHash 的另一项改进是在多个特定于平台的实现之上提供了一个接口。这样，当开发人员只是想要一个用于哈希表的、快速健壮的哈希函数，而不需要在每个平台上都一样时，FarmHash 也能满足要求。目前，FarmHash只包含在32、64和128位平台上用于字节数组的哈希函数。未来开发计划包含了对整数、元组和其它数据的支持。





#### （4） xxHash




![](http://upload-images.jianshu.io/upload_images/1194012-06ad3c89ace5c525.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





xxHash 是由 Yann Collet 创建的非加密哈希函数。它最初用于 LZ4 压缩算法，作为最终的错误检查签名的。该 hash 算法的速度接近于 RAM 的极限。并给出了32位和64位的两个版本。现在它被广泛使用在[PrestoDB](http://prestodb.io/)、[RocksDB](https://rocksdb.org/)、[MySQL](https://www.mysql.com/)、[ArangoDB](https://www.arangodb.org/)、[PGroonga](https://pgroonga.github.io/)、[Spark](http://spark.apache.org/) 这些数据库中，还用在了 [Cocos2D](http://www.cocos2d.org/)、[Dolphin](https://dolphin-emu.org/)、[Cxbx-reloaded](http://cxbx-reloaded.co.uk/) 这些游戏框架中，


下面这有一个性能对比的实验。测试环境是 [Open-Source SMHasher program by Austin Appleby](http://code.google.com/p/smhasher/wiki/SMHasher) ，它是在 Windows 7 上通过 Visual C 编译出来的，并且它只有唯一一个线程。CPU 内核是 Core 2 Duo @3.0GHz。

![](http://upload-images.jianshu.io/upload_images/1194012-a10436a5de50086a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




上表里面的 hash 函数并不是所有的，只列举了一些常见的。第二栏是速度的对比，可以看出来速度最快的是 xxHash 。第三栏是哈希的质量，哈希质量最高的有5个，全是5星，xxHash、MurmurHash 3a、CityHash64、MD5-32、SHA1-32 。从表里的数据看，哈希质量最高，速度最快的还是 xxHash。


#### （4） memhash

![](http://upload-images.jianshu.io/upload_images/1194012-5bc2312dd0da4536.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这个哈希算法笔者没有在网上找到很明确的作者信息。只在 Google 的 Go 的文档上有这么几行注释，说明了它的灵感来源：


```go

// Hashing algorithm inspired by
//   xxhash: https://code.google.com/p/xxhash/
// cityhash: https://code.google.com/p/cityhash/

```

它说 memhash 的灵感来源于 xxhash 和 cityhash。那么接下来就来看看 memhash 是怎么对字符串进行哈希的。


### 2. 哈希冲突处理

### 3. 哈希表的扩容策略


### 4. Map 的具体实现举例

## 二. 不用红黑树优化，性能一定差么？

## 三. 如何实现一个线程安全的 Map ？

### 1. Java

### 2. Redis

### 3. Go



------------------------------------------------------

Reference：  
《算法与数据结构》  
[xxHash](http://cyan4973.github.io/xxHash/)  
[字符串hash函数](https://www.biaodianfu.com/hash.html)  


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_map/](https://halfrost.com/go_map/)