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

MD5 和 SHA1 可以说是目前应用最广泛的 Hash 算法，而它们都是以 MD4 为基础设计的。

MD4(RFC 1320) 是 MIT 的Ronald L. Rivest 在 1990 年设计的，MD 是 Message Digest（消息摘要） 的缩写。它适用在32位字长的处理器上用高速软件实现——它是基于 32位操作数的位操作来实现的。
MD5(RFC 1321) 是 Rivest 于1991年对 MD4 的改进版本。它对输入仍以512位分组，其输出是4个32位字的级联，与 MD4 相同。MD5 比 MD4 来得复杂，并且速度较之要慢一点，但更安全，在抗分析和抗差分方面表现更好。

SHA1 是由 NIST NSA 设计为同 DSA 一起使用的，它对长度小于264的输入，产生长度为160bit 的散列值，因此抗穷举 (brute-force)
性更好。SHA-1 设计时基于和 MD4 相同原理,并且模仿了该算法。




![](http://upload-images.jianshu.io/upload_images/1194012-a10436a5de50086a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)






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