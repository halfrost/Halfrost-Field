![](https://img.halfrost.com/Blog/ArticleImage/146_0.png)

# LRU / LFU in Interviews: Bronze-Level vs. King-Level

It is already 2020, and hand-coding algorithm problems in big-tech interviews has become standard practice. The odds of running into a hand-coded LRU / LFU problem in the first round are still quite high. On LeetCode, [146. LRU Cache](https://leetcode.com/problems/lru-cache/) and [460. LFU Cache](https://leetcode.com/problems/lfu-cache/) are classified as Medium and Hard respectively, but in interviewers’ eyes, these two problems are among the most fundamental of the fundamentals. This article discusses the bronze-level and king-level approaches to LRU / LFU in interviews.

> Cache eviction algorithms are not limited to LRU / LFU. There are many others, including **TLRU** (Time aware least recently used), **PLRU** (Pseudo-LRU), **SLRU** (Segmented LRU), **LFRU** (Least frequent recently used), **LFUDA** (LFU with dynamic aging), **LIRS** (Low inter-reference recency set), **ARC** (Adaptive Replacement Cache), **FIFO** (First In First Out), **MRU** (Most recently used), **LIFO** (Last in first out), **FILO** (First in last out), **CAR** (Clock with adaptive replacement), and so on. If you are interested, you can implement every one of them in code.

## Stubborn Bronze

The interviewer may simply pull out these two LeetCode problems and ask you to solve them. Before presenting the standard solution, let’s briefly introduce the concepts of LRU and LFU.

![](https://img.halfrost.com/Blog/ArticleImage/146_1_.png)

LRU stands for Least Recently Used. It is a commonly used page replacement algorithm that evicts the page that has not been used for the longest time. As shown above, when inserting F, one of the existing pages must be evicted.

![](https://img.halfrost.com/Blog/ArticleImage/146_2_0.png)

According to the LRU policy, each eviction removes the page that has gone unused for the longest time, so page A is evicted first. When inserting C, we find that page C is already in the cache, so C must be moved to the front because it has just been used. And so on: when inserting page G, G is a new page and is not in the cache, so page B is evicted. When inserting page H, H is a new page and is not in the cache, so page D is evicted. When inserting E, we find that page E is already in the cache, so E must be moved to the front. When inserting page I, I is a new page and is not in the cache, so page F is evicted.

As you can see, **LRU updates and new-page insertions both happen at the head of the linked list, while page deletions happen at the tail**.

LRU requires lookups to be as efficient as possible, ideally O(1). So a map is the obvious choice for lookup. Updates and deletions should also be completed in O(1) as much as possible. Among common data structures—linked lists, stacks, queues, trees, and graphs—trees and graphs can be ruled out. Stacks and queues cannot query arbitrary elements in the middle, so they are ruled out as well. That leaves a linked list. However, if we use a singly linked list, deleting a node requires O(n) traversal to find its predecessor. Therefore, we use a doubly linked list, so deletion can also be completed in O(1).

Because the underlying implementation of `list` in Go’s `container` package is a doubly linked list, we can reuse this data structure directly. The data structure for `LRUCache` is defined as follows:
```go
import "container/list"

type LRUCache struct {
    Cap  int
    Keys map[int]*list.Element
    List *list.List
}

type pair struct {
    K, V int
}

func Constructor(capacity int) LRUCache {
    return LRUCache{
        Cap: capacity,
        Keys: make(map[int]*list.Element),
        List: list.New(),
    }
}

```
Two questions need to be explained here: what values are stored in `list`? What is the purpose of the `pair` struct?
```go
type Element struct {
	// Next and previous pointers in the doubly-linked list of elements.
	// To simplify the implementation, internally a list l is implemented
	// as a ring, such that &l.root is both the next element of the last
	// list element (l.Back()) and the previous element of the first list
	// element (l.Front()).
	next, prev *Element

	// The list to which this element belongs.
	list *List

	// The value stored with this element.
	Value interface{}
}
```
In `container/list`, each node in this doubly linked list is of type `Element`. An `Element` stores four values: the predecessor and successor nodes, the head node of the doubly linked list, and the `value`. The `value` here is an interface type. In this implementation, the author stores a `pair` struct in this `value`, which explains what data is stored in the list.

Why store a `pair`? Wouldn’t storing only `v` be enough? Why store an extra copy of the key? The reason is that when `LRUCache` performs a delete operation, it needs to maintain two data structures: a `map` and a doubly linked list. It deletes the evicted value from the doubly linked list, and deletes the key corresponding to that evicted value from the `map`. If the key is not stored in the doubly linked list’s `value`, deleting the key from the `map` becomes troublesome. To force an implementation, you would first need to obtain the address of the `Element` node in the doubly linked list. Then you would traverse the `map`, find the key whose value stores the address of that `Element`, and delete it. This has a time complexity of O(n), so it cannot be done in O(1). Therefore, the `Value` in the doubly linked list needs to store this `pair`.

The `Get` operation of `LRUCache` is straightforward: directly read the doubly linked list node from the `map`. If it exists in the `map`, move it to the head of the doubly linked list and return its `value`; if it does not exist in the `map`, return -1.
```go 
func (c *LRUCache) Get(key int) int {
	if el, ok := c.Keys[key]; ok {
		c.List.MoveToFront(el)
		return el.Value.(pair).V
	}
	return -1
}
```
The `Put` operation of `LRUCache` is also straightforward. First, check whether the key exists in the map. If it does, update its value and move the node to the head of the doubly linked list. If it does not exist in the map, create a new node and add it to both the doubly linked list and the map. Finally, remember to maintain the capacity of the doubly linked list. If it exceeds `cap`, evict the last node: remove it from the doubly linked list and delete the corresponding key from the map.
```go
func (c *LRUCache) Put(key int, value int) {
	if el, ok := c.Keys[key]; ok {
		el.Value = pair{K: key, V: value}
		c.List.MoveToFront(el)
	} else {
		el := c.List.PushFront(pair{K: key, V: value})
		c.Keys[key] = el
	}
	if c.List.Len() > c.Cap {
		el := c.List.Back()
		c.List.Remove(el)
		delete(c.Keys, el.Value.(pair).K)
	}
}

```
In summary, LRU is a data structure composed of a map and a doubly linked list. The value corresponding to each key in the map is a node in the doubly linked list. The doubly linked list stores key-value pairs. The head of the list is used to update the cache, and the tail is used to evict cache entries. As shown below:

![](https://img.halfrost.com/Blog/ArticleImage/146_9.png)

After submitting the code, it successfully passed all test cases.

![](https://img.halfrost.com/Blog/ArticleImage/146_4_.png)

LFU stands for Least Frequently Used. It is also a common page replacement algorithm: it selects the page with the smallest access counter for eviction. As shown below, each page in the cache has an access counter.

![](https://img.halfrost.com/Blog/ArticleImage/146_3.png)

According to the LFU policy, the access counter must be updated on every access. When inserting B, we find that B already exists in the cache, so we increment its access counter and move B to the appropriate position in descending order of access count. When inserting D, the same applies: first update the counter, then move it to its position after sorting. When inserting F, F does not exist in the cache, so we evict the page with the smallest counter, which is page A. At this point, F is placed at the bottom, with a count of 1.

![](https://img.halfrost.com/Blog/ArticleImage/146_8_.png)

There is one aspect here that is different from LRU. If multiple pages eligible for eviction have the same access count, choose the one closest to the tail. In the figure above, A, B, and C all have the same access count: 1. When F needs to be inserted and is not in the cache, page A should be evicted. F is the newly inserted page, with an access count of 1, and is placed before C. In other words, for the same access count, entries are ordered by recency, and the oldest page is evicted. This is the biggest difference from LRU.

We can see that **LFU updates and new-page insertions can occur at any position in the linked list, while page deletions always happen at the tail**.

LFU also requires lookups to be as efficient as possible: O(1) lookup. We still use a map for lookup. Updates and deletions also need to be completed in O(1), so we still use a doubly linked list, continuing to reuse the `list` data structure from the `container` package. LFU needs to record access counts, so each node must store not only the key and value, but also an additional `frequency` access count.

There is one more issue to consider: how do we sort by frequency? For identical frequencies, entries should be ordered by insertion/access recency. If you start thinking about sorting algorithms, your line of thought has already deviated from the optimal solution. Sorting takes at least O(nlogn). Looking back at how LFU works, you will find that it only cares about the minimum frequency. It does not care about the ordering among other frequencies. So sorting is unnecessary. Use a `min` variable to store the minimum frequency; during eviction, reading this minimum value lets us find the node to delete. The requirement that entries with the same frequency be ordered by recency is still implemented with a doubly linked list: the insertion order of the linked list represents the relative age of the nodes. Each frequency corresponds to one doubly linked list. Since there may be multiple frequencies, there may be multiple doubly linked lists. Use a map to maintain the relationship between access frequency and the corresponding doubly linked list. When deleting the minimum frequency, use `min` to find the minimum frequency, then find the doubly linked list for that frequency in this map, and delete the oldest node from that list. This solves the LFU deletion operation.

The LFU update operation is similar to LRU: it also needs a map to store the mapping from key to doubly linked list node. The node in this doubly linked list stores a tuple of three elements: key-value-frequency. This way, through the key and frequency in the node, we can in turn delete the key from the map.

Define the data structure of `LFUCache` as follows:
```go

import "container/list"

type LFUCache struct {
	nodes    map[int]*list.Element
	lists    map[int]*list.List
	capacity int
	min      int
}

type node struct {
	key       int
	value     int
	frequency int
}

func Constructor(capacity int) LFUCache {
	return LFUCache{nodes: make(map[int]*list.Element),
		lists:    make(map[int]*list.List),
		capacity: capacity,
		min:      0,
	}
}

```
The `Get` operation of `LFUCache` involves updating the `frequency` value and two maps. First, retrieve the node information by `key` from the `nodes` map. Then remove the node from the doubly linked list corresponding to its current `frequency` in `lists`. After removal, increment `frequency`. If the new `frequency` already exists in `lists`, add the node to the head of that doubly linked list; otherwise, create a new doubly linked list and add the current node to its head. Then update the map whose value is the doubly linked list node. Finally, update `min`: check whether the doubly linked list corresponding to the old `frequency` is now empty; if it is, increment `min`.
```go
func (this *LFUCache) Get(key int) int {
	value, ok := this.nodes[key]
	if !ok {
		return -1
	}
	currentNode := value.Value.(*node)
	this.lists[currentNode.frequency].Remove(value)
	currentNode.frequency++
	if _, ok := this.lists[currentNode.frequency]; !ok {
		this.lists[currentNode.frequency] = list.New()
	}
	newList := this.lists[currentNode.frequency]
	newNode := newList.PushFront(currentNode)
	this.nodes[key] = newNode
	if currentNode.frequency-1 == this.min && this.lists[currentNode.frequency-1].Len() == 0 {
		this.min++
	}
	return currentNode.value
}

```
The logic for LFU’s Put operation is slightly more involved. First, query the nodes map to check whether the key exists. If it does, retrieve the node, update its value, and then manually call the Get operation once, because the update logic below is the same as the Get operation. If it does not exist in the map, proceed with either insertion or eviction. Check whether capacity is full; if it is, perform an eviction. Remove the tail node from the doubly linked list corresponding to min, and also remove the corresponding key-value entry from the nodes map.

Since a newly inserted page always has an access count of 1, min is set to 1 at this point. Create a new node and insert it into the two maps.
```go

func (this *LFUCache) Put(key int, value int) {
	if this.capacity == 0 {
		return
	}
	// If it exists, update the access count
	if currentValue, ok := this.nodes[key]; ok {
		currentNode := currentValue.Value.(*node)
		currentNode.value = value
		this.Get(key)
		return
	}
	// If it doesn't exist and the cache is full, delete it
	if this.capacity == len(this.nodes) {
		currentList := this.lists[this.min]
		backNode := currentList.Back()
		delete(this.nodes, backNode.Value.(*node).key)
		currentList.Remove(backNode)
	}
	// Create a new node and insert it into 2 maps
	this.min = 1
	currentNode := &node{
		key:       key,
		value:     value,
		frequency: 1,
	}
	if _, ok := this.lists[1]; !ok {
		this.lists[1] = list.New()
	}
	newList := this.lists[1]
	newNode := newList.PushFront(currentNode)
	this.nodes[key] = newNode
}

```
In summary, LFU is a data structure composed of two maps and a `min` pointer. In one map, the key stores the access count, and the corresponding value is a set of doubly linked lists. The role of the doubly linked list here is to evict the oldest page at the tail when multiple pages have the same frequency. In the other map, the key’s corresponding value is a node in a doubly linked list. Compared with LRU, the node stores one additional value: the access count. In other words, the node stores a `key-value-frequency` tuple. The role of the doubly linked list here is similar to that in LRU: based on the key in the map, we can update the `value` and `frequency` in the doubly linked list node; and based on the `key` and `frequency` in the doubly linked list node, we can update the corresponding relationship in the map in reverse. As shown below:

![](https://img.halfrost.com/Blog/ArticleImage/146_10_1.png)

After submitting the code, it successfully passed all test cases.

![](https://img.halfrost.com/Blog/ArticleImage/146_5.png)


## Gold

If you give the Bronze answer above in an interview, you may be asked, “Are there any other solutions?” Although the Bronze answer is already the optimal solution, the interviewer may still want to evaluate whether you can provide multiple approaches.

First, consider LRU. I could not think of another approach in terms of data structure, but judging from the percentile beaten, it seems there is still room for constant-factor optimization. After thinking it over repeatedly, I felt that the place that might be increasing the runtime was `interface{}` type assertion; there was no room for optimization elsewhere. So I hand-wrote a doubly linked list and submitted it. The code is as follows:
```go

type LRUCache struct {
	head, tail *Node
	keys       map[int]*Node
	capacity   int
}

type Node struct {
	key, val   int
	prev, next *Node
}

func ConstructorLRU(capacity int) LRUCache {
	return LRUCache{keys: make(map[int]*Node), capacity: capacity}
}

func (this *LRUCache) Get(key int) int {
	if node, ok := this.keys[key]; ok {
		this.Remove(node)
		this.Add(node)
		return node.val
	}
	return -1
}

func (this *LRUCache) Put(key int, value int) {
	if node, ok := this.keys[key]; ok {
		node.val = value
		this.Remove(node)
		this.Add(node)
		return
	} else {
		node = &Node{key: key, val: value}
		this.keys[key] = node
		this.Add(node)
	}
	if len(this.keys) > this.capacity {
		delete(this.keys, this.tail.key)
		this.Remove(this.tail)
	}
}

func (this *LRUCache) Add(node *Node) {
	node.prev = nil
	node.next = this.head
	if this.head != nil {
		this.head.prev = node
	}
	this.head = node
	if this.tail == nil {
		this.tail = node
		this.tail.next = nil
	}
}

func (this *LRUCache) Remove(node *Node) {
	if node == this.head {
		this.head = node.next
		if node.next != nil {
			node.next.prev = nil
		}
		node.next = nil
		return
	}
	if node == this.tail {
		this.tail = node.prev
		node.prev.next = nil
		node.prev = nil
		return
	}
	node.prev.next = node.next
	node.next.prev = node.prev
}

```
After submitting it, it actually hit 100%.

![](https://img.halfrost.com/Blog/ArticleImage/146_6.png)

The LRU implemented by the code above is not optimized in essence; it is just written in a different style and does not use the container package.

Another approach to LFU is to use the [Index Priority Queue](https://algs4.cs.princeton.edu/24pq/) data structure. Don’t be intimidated by the name: Index Priority Queue = map + Priority Queue, that’s all.

Use a Priority Queue to maintain a min-heap, where the heap top is the element with the smallest access count. The value in the map stores the node in the priority queue.
```go
import "container/heap"

type LFUCache struct {
	capacity int
	pq       PriorityQueue
	hash     map[int]*Item
	counter  int
}

func Constructor(capacity int) LFUCache {
	lfu := LFUCache{
		pq:       PriorityQueue{},
		hash:     make(map[int]*Item, capacity),
		capacity: capacity,
	}
	return lfu
}

```
`Get` and `Put` operations need to be as fast as possible, and there are two issues to solve. When access counts are the same, how do we remove the oldest element? When an element’s access count changes, how do we quickly adjust the heap? To solve these two issues, define the following data structure:
```go
// An Item is something we manage in a priority queue.
type Item struct {
	value     int // The value of the item; arbitrary.
	key       int
	frequency int // The priority of the item in the queue.
	count     int // use for evicting the oldest element
	// The index is needed by update and is maintained by the heap.Interface methods.
	index int // The index of the item in the heap.
}

```
Nodes in the heap store these five values. The `count` value is used to determine which element is the oldest, similar to an operation timestamp. The `index` value is used to re-heapify the heap. Next, implement the methods of `PriorityQueue`.
```go
// A PriorityQueue implements heap.Interface and holds Items.
type PriorityQueue []*Item

func (pq PriorityQueue) Len() int { return len(pq) }

func (pq PriorityQueue) Less(i, j int) bool {
	// We want Pop to give us the highest, not lowest, priority so we use greater than here.
	if pq[i].frequency == pq[j].frequency {
		return pq[i].count < pq[j].count
	}
	return pq[i].frequency < pq[j].frequency
}

func (pq PriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *PriorityQueue) Push(x interface{}) {
	n := len(*pq)
	item := x.(*Item)
	item.index = n
	*pq = append(*pq, item)
}

func (pq *PriorityQueue) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	old[n-1] = nil  // avoid memory leak
	item.index = -1 // for safety
	*pq = old[0 : n-1]
	return item
}

// update modifies the priority and value of an Item in the queue.
func (pq *PriorityQueue) update(item *Item, value int, frequency int, count int) {
	item.value = value
	item.count = count
	item.frequency = frequency
	heap.Fix(pq, item.index)
}
```
In the `Less()` method, sort `frequency` in ascending order; when `frequency` is the same, sort `count` in ascending order. According to the heap construction rules for a priority queue, the item with the smallest `frequency` will be at the top of the heap; for items with the same `frequency`, the smaller the `count`, the closer it is to the top.

In the `Swap()` method, remember to update the `index` value. In the `Push()` method, when inserting an element, the current length of the queue is the element’s `index` value, so remember to update `index` here as well. The `update()` method calls the `Fix()` function. Calling `Fix()` is less expensive than first calling `Remove()` and then `Push()` with a new value. Therefore, `Fix()` is called here, and the time complexity of this operation is O(log n).

This maintains a min Index Priority Queue. The `Get` operation is very simple:
```go
func (this *LFUCache) Get(key int) int {
	if this.capacity == 0 {
		return -1
	}
	if item, ok := this.hash[key]; ok {
		this.counter++
		this.pq.update(item, item.value, item.frequency+1, this.counter)
		return item.value
	}
	return -1
}

```
Look up the key in the hashmap. If it exists, increment the counter timestamp and call the Priority Queue's update method to adjust the heap.
```go
func (this *LFUCache) Put(key int, value int) {
	if this.capacity == 0 {
		return
	}
	this.counter++
	// If it exists, increase frequency, then adjust the heap
	if item, ok := this.hash[key]; ok {
		this.pq.update(item, value, item.frequency+1, this.counter)
		return
	}
	// If it doesn't exist and the cache is full, delete it. Delete from hashmap and pq.
	if len(this.pq) == this.capacity {
		item := heap.Pop(&this.pq).(*Item)
		delete(this.hash, item.key)
	}
	// Create a new node and add it to hashmap and pq.
	item := &Item{
		value: value,
		key:   key,
		count: this.counter,
	}
	heap.Push(&this.pq, item)
	this.hash[key] = item
}
```
An LFU implemented with a min-heap has `Put` time complexity of O(capacity) and `Get` time complexity of O(capacity), which is inferior to the version implemented with 2 maps. Interestingly, the min-heap version still beat 100%.

![](https://img.halfrost.com/Blog/ArticleImage/146_7.png)

After submission, both LRU and LFU beat 100%. The code above has been fully encapsulated; the [complete code](https://github.com/halfrost/LeetCode-Go/tree/master/template) is in LeetCode-Go, and the explanations have also been updated in Chapter 3 of *LeetCode Cookbook*: [Section 3, LRUCache](https://books.halfrost.com/leetcode/ChapterThree/LRUCache/) and [Section 4, LFUCache](https://books.halfrost.com/leetcode/ChapterThree/LFUCache/). The optimal solution for LRU is a map + doubly linked list, while the optimal solution for LFU is 2 maps + multiple doubly linked lists. In fact, the warm-up has only just ended; what follows is the **main focus** of this article.

## Grandmaster

After a candidate answers the gold-level question, the interviewer may continue with a more advanced follow-up: “How would you implement a highly concurrent and thread-safe LRU?” When facing this question, the code templates discussed above no longer apply. To achieve high concurrency, two things must be considered. First, memory allocation and GC reclamation must be fast—ideally with zero GC overhead. Second, operations must take as little time as possible. More specifically, because high concurrency can mean very high instantaneous TPS, memory allocation and creation of new memory space must be as fast as possible. Garbage collection also cannot be slow; otherwise memory usage will surge. For the LRU / LFU problem, the operations being executed are get and set, and their latency must be minimized. If latency is high, system throughput will be severely affected, and TPS will not scale. In addition, in high-concurrency scenarios, thread safety must be guaranteed. This is where locks are needed. The simplest choice is a read-write lock. The following example uses LRUCache. The principle for LFUCache is similar. (The code below first shows only the newly modified parts, and then gives the full version at the end.)
```go
type LRUCache struct {
    sync.RWMutex
}

func (c *LRUCache) Get(key int) int {
	c.RLock()
	defer c.RUnlock()
	
	……
}

func (c *LRUCache) Put(key int, value int) {
	c.Lock()
  	defer c.Unlock()
  	
	……
}

```
Although the code above ensures thread safety, its concurrency is not very high. During a Put operation, the write lock blocks the read lock, so reads will be locked out here. The optimization direction is clear: split the large lock so that the write lock blocks the read lock as little as possible. In short, make the locks more fine-grained.

![](https://img.halfrost.com/Blog/ArticleImage/146_27.png)

As shown above, split one large critical section into multiple smaller critical sections. The code is as follows:
```go

type LRUCache struct {
    sync.RWMutex
    shards map[int]*LRUCacheShard
}

type LRUCacheShard struct {
  	Cap  int
	Keys map[int]*list.Element
	List *list.List
	sync.RWMutex
}

func (c *LRUCache) Get(key int) int {
	shard, ok := c.GetShard(key, false)
	if ok == false {
		return -1
	}
	shard.RLock()
	defer shard.RUnlock()
	
	……
}

func (c *LRUCache) Put(key int, value int) {
  	shard, _ := c.GetShard(key, true)
	shard.Lock()
	defer shard.Unlock()
	
	……
}

func (c *LRUCache) GetShard(key int, create bool) (shard *LRUCacheShard, ok bool) {
	hasher := sha1.New()
	hasher.Write([]byte(key))
	shardKey := fmt.Sprintf("%x", hasher.Sum(nil))[0:2]

	c.lock.RLock()
	shard, ok = c.shards[shardKey]
	c.lock.RUnlock()

	if ok || !create {
		return
	}

	//only time we need to write lock
	c.lock.Lock()
	defer c.lock.Unlock()
	//check again in case the group was created in this short time
	shard, ok = c.shards[shardKey]
	if ok {
		return
	}

	shard = &LRUCacheShard{
		Keys: make(map[int]*list.Element),
		List: list.New(),
	}
	c.shards[shardKey] = shard
	ok = true
	return
}

```
With the refactoring above, hashing is used to split the original `LRUCache` into 256 shards (2^8). The write lock is only acquired when a shard does not exist. Once a shard has been created, only the read lock is used thereafter. This is still a small bottleneck, so we can optimize further and eliminate this write lock. The optimized code is simple: create all shards during initialization.
```go

func New(capacity int) LRUCache {
	shards := make(map[string]*LRUCacheShard, 256)
	for i := 0; i < 256; i++ {
		shards[fmt.Sprintf("%02x", i)] = &LRUCacheShard{
			Cap:  capacity,
			Keys: make(map[int]*list.Element),
			List: list.New(),
		}
	}
	return LRUCache{
		shards: shards,
	}
}

func (c *LRUCache) Get(key int) int {
	shard := c.GetShard(key)
	shard.RLock()
	defer shard.RUnlock()
	
	……
}

func (c *LRUCache) Put(key int, value int) {
  	shard := c.GetShard(key)
	shard.Lock()
	defer shard.Unlock()
	
	……
}

func (c *LRUCache) GetShard(key int) (shard *LRUCacheShard) {
  hasher := sha1.New()
  hasher.Write([]byte(key))
  shardKey :=  fmt.Sprintf("%x", hasher.Sum(nil))[0:2]
  return c.shards[shardKey]
}

```
At this point, the large critical section has already been split into fine-grained ones. Inside the fine-grained locks, there are still operations on doubly linked list nodes, and those node operations involve lock contention. Mature cache systems such as memcached use a global LRU list lock, while Redis is single-threaded and therefore does not need to consider concurrency issues. Returning to LRU: each Get operation needs to read the value corresponding to a key, which requires a read lock. At the same time, a Get operation also involves moving the most recently used node, which requires a write lock. A Set operation only involves a write lock. One thing to note is that the execution order of Get and Set is critical. For example, if you first get a non-existent key, it returns nil, and then you set that key. If you set the key first and then get it, the result is no longer nil, but the corresponding value. Therefore, while ensuring lock safety (i.e., avoiding deadlocks), you also need to guarantee the correctness of the ordering of each operation. Nothing fits both requirements better than an unbuffered channel. First, let’s look at the logic for consuming data from the channel:
```go
func (c *CLRUCache) doMove(el *list.Element) bool {
	if el.Value.(Pair).cmd == MoveToFront {
		c.list.MoveToFront(el)
		return false
	}
	newel := c.list.PushFront(el.Value.(Pair))
	c.bucket(el.Value.(Pair).key).update(el.Value.(Pair).key, newel)
	return true
}
```
It is also worth mentioning that `get` and `set` write operations come in two types: one is `MoveToFront`; the other occurs when the node does not exist, in which case a new node must first be created and then moved to the head. This operation is `PushFront`. Here, the author adds a `cmd` flag to the node, whose default value is `MoveToFront`.

![](https://img.halfrost.com/Blog/ArticleImage/146_26.png)


So far, the next optimization direction has been decided: use buffered channels. How many? The answer is two. In addition to the write operations discussed above, `remove` operations also need to be managed. Due to the nature of LRU logic, it guarantees that moving nodes and removing nodes are always separated at the two ends of the doubly linked list. In other words, operations can be performed simultaneously on both ends of the doubly linked list without interfering with each other. The critical section of the doubly linked list can be narrowed further, down to the node level. The final approach is therefore settled: use two buffered channels to handle node movement and node deletion respectively. These two channels can be processed together in the same goroutine without affecting each other.
```go
func (c *CLRUCache) worker() {
	defer close(c.control)
	for {
		select {
		case el, ok := <-c.movePairs:
			if ok == false {
				goto clean
			}
			if c.doMove(el) && c.list.Len() > c.cap {
				el := c.list.Back()
				c.list.Remove(el)
				c.bucket(el.Value.(Pair).key).delete(el.Value.(Pair).key)
			}
		case el := <-c.deletePairs:
			c.list.Remove(el)
		case control := <-c.control:
			switch msg := control.(type) {
			case clear:
				for _, bucket := range c.buckets {
					bucket.clear()
				}
				c.list = list.New()
				msg.done <- struct{}{}
			}
		}
	}
clean:
	for {
		select {
		case el := <-c.deletePairs:
			c.list.Remove(el)
		default:
			close(c.deletePairs)
			return
		}
	}
}
```
The final complete code is available [here](https://github.com/halfrost/LeetCode-Go/blob/master/template/CLRUCache.go). Finally, let’s run a quick Benchmark to see how it performs.

> The following performance test was done by the author after the interview. During the interview, I wrote the code but did not run a Benchmark on the spot.
```go
go test -bench BenchmarkGetAndPut1 -run none -benchmem -cpuprofile cpuprofile.out -memprofile memprofile.out -cpu=8goos: darwin
goarch: amd64
pkg: github.com/halfrost/LeetCode-Go/template
BenchmarkGetAndPut1-8            368578              2474 ns/op             530 B/op         14 allocs/op
PASS
ok      github.com/halfrost/LeetCode-Go/template        1.022s

```
BenchmarkGetAndPut2 simply uses a global lock, which can lead to deadlocks. As you can see, the performance of approach one is acceptable: averaged over 368578 iterations, a single Get/Set takes 2474 ns on average, so TPS is roughly 300K/s, which can satisfy typical high-concurrency requirements.

Finally, let’s look at CPU consumption in this version; it matches expectations:

![](https://img.halfrost.com/Blog/ArticleImage/146_11_0.png)

Memory allocation also matches expectations:

![](https://img.halfrost.com/Blog/ArticleImage/146_12_0.png)


At this point, you are already a King.


## Glorious King

This is the bonus section. If the interviewer gets to this point, the topic is no longer directly related to LRU/LFU; it is more about evaluating how to design a high-concurrency Cache. The reason I mention it at the end of this article is to help readers broaden their thinking. The interviewer may continue from the high-concurrency LRU version you provided and ask, “Where do you think the weaknesses of this version are? Compared with a real Cache, what is still missing?”

In the previous section, “Strongest King,” we roughly implemented a high-concurrency LRU. However, this approach is still not perfect. When concurrency reaches a critical level—that is, when the rate of Get requests becomes hundreds or tens of thousands of times faster than Go’s memory reclamation speed—the bucket shard may be cleared, and goroutines attempting to access keys in that shard start allocating memory while the previous memory has not yet been fully released. This can cause memory usage to surge and lead to an OOM crash. Therefore, this method’s performance does not scale well with the number of cores.

Another issue with this rough approach is that it uses the number of cached entries as the Cap, without considering the size of each value. Using the number of cached entries as the baseline cannot constrain memory size. For a high-load service, if a large Cap is configured, then in an extreme case where every value is very large—tens of MB—the total memory consumption could reach hundreds of GB. For a low-load service, if a very small Cap is configured, then in the extreme case where each value is tiny, the total memory size may be only 1KB. From this perspective, the upper and lower bounds of memory fluctuate too much, making it impossible to set a balanced limit.

The missing pieces fall into two categories: functionality and performance. On the functionality side, TTL and persistence are missing. TTL is the expiration time; when the time is reached, the key needs to be deleted. Persistence means saving the data in the cache to a file, or loading it from a file at startup.

On the performance side, what is missing includes efficient hash algorithms, a high hit ratio, memory limits, and scalability.

Efficient hash algorithms refer to things like AES Hash, which checks whether the CPU supports the AES instruction set. When the CPU supports the AES instruction set, it selects the AES Hash algorithm. Some efficient hash algorithms are implemented in assembly.

For a high hit ratio, you can refer to the paper [BP-Wrapper: A System Framework Making Any
Replacement Algorithms (Almost) Lock Contention Free](https://dgraph.io/blog/refs/bp_wrapper.pdf). This paper proposes two approaches: prefetching and batching. Briefly, in the batching approach, the ring buffer is filled before waiting on the critical section. As described in the paper, using a ring buffer in this way has almost no overhead, thereby greatly reducing contention. To implement the ring buffer, you can consider using sync.Pool rather than other data structures (slices, striped mutexes, and so on), because the performance advantage mainly comes from the internal use of thread-local storage, while other data structures do not provide related APIs.

Memory limits. An infinitely large cache is not actually possible. A cache must have a size limit. How to design an efficient eviction policy becomes critical. Is LRU a good eviction policy? For different usage scenarios, LRU is not always the best; in some scenarios, LFU is more suitable. Here is a paper, [TinyLFU: A Highly Efficient Cache Admission Policy](https://dgraph.io/blog/refs/TinyLFU%20-%20A%20Highly%20Efficient%20Cache%20Admission%20Policy.pdf), which discusses an efficient cache admission policy. TinyLFU is an eviction-independent admission policy whose goal is to improve hit ratio with very little memory overhead. The main idea is to admit a new key into the Cache only when its estimated value is higher than that of the key about to be evicted. When the cache reaches capacity, each new key should replace one or more keys already present in the cache. In addition, the estimated value of the incoming key should be higher than that of the evicted key. Otherwise, the new key is not allowed into the cache. This is also done to ensure a high hit ratio.

![](https://img.halfrost.com/Blog/ArticleImage/146_25_0.png)


Before putting a new key into TinyLFU, you can also use a bloom filter to first check whether the key has been seen before. The key is inserted into TinyLFU only if it already exists in the bloom filter. This is to avoid polluting TinyLFU with long-tail keys that are not seen for a long time.

![](https://img.halfrost.com/Blog/ArticleImage/146_23.png)


As for whether to choose LRU, LFU, or LRU + LFU, this is a big topic; expanding on it could fill several more articles. Interested readers can read this paper, [Adaptive Software Cache Management](https://dgraph.io/blog/refs/Adaptive%20Software%20Cache%20Management.pdf). From the title—adaptive software cache management—you can tell that it explores this problem. The basic idea of the paper is to place an LRU “window” before the main cache segment and use hill-climbing techniques to adaptively adjust the window size to maximize hit ratio. [A high performance caching library for Java 8 — Caffeine](https://github.com/ben-manes/caffeine) has already achieved very good results.

![](https://img.halfrost.com/Blog/ArticleImage/146_22.png)


For scalability, choosing an appropriate cache size can avoid [False Sharing](https://dzone.com/articles/false-sharing). In multicore systems, different atomic counters (8 bytes each) may reside in the same cache line (typically 64 bytes). Any update to one of these counters causes the others to be marked invalid. This forces all other cores that own that cache line to reload it, creating write contention on the cache line. To achieve scalability, you should ensure that each atomic counter fully occupies an entire cache line. In this way, each core works on a different cache line. 


![](https://img.halfrost.com/Blog/ArticleImage/146_24.png)


Finally, let’s look at several open-source Cache libraries implemented in Go. This article will not dive into source-code analysis of these Cache libraries. (If there is time, I may write a separate article explaining them in detail.) Interested readers can inspect the source code themselves.

[bigcache](https://github.com/allegro/bigcache): BigCache divides data into shards based on the hash of the key. Each shard contains a map and a ring buffer. Whenever a new element is set, it appends the element to the ring buffer of the corresponding shard, and the offset in the buffer is stored in the map. If the same element is Set multiple times, the previous entry in the buffer is marked invalid. If the buffer is too small, it is expanded until it reaches the maximum capacity. In each map, the key is a uint32 hash, and the value is a uint32 pointer pointing to the offset in the buffer where the value is stored together with metadata. If a hash collision occurs, BigCache ignores the previous key and stores the current key in the map. Preallocating fewer, larger buffers and using map[uint32]uint32 is a good way to avoid paying GC scanning costs.

[freecache](https://github.com/coocood/freecache): FreeCache avoids GC overhead by reducing the number of pointers. No matter how many entries are stored in it, there are only 512 pointers. The dataset is split into 256 segments using the hash value of the key. When a new key is added to the cache, the lower eight bits of the key hash are used to identify the segment ID. Each segment has only two pointers: one to the ring buffer that stores keys and values, and one to the index slice used to look up entries. Data is appended to the ring buffer, and the offset is stored in a sorted slice. If the ring buffer does not have enough space, a modified LRU strategy is used to evict keys in that segment starting from the beginning of the ring buffer. If an entry’s last access time is less than the segment’s average access time, the entry is removed from the ring buffer. To find an entry in the cache during Get, a binary search is performed on the sorted array in the corresponding slot. There is also an acceleration optimization: using bits 9–16 of the LSB of the key’s hash to choose a slot. Dividing data into multiple slots helps reduce the search space when looking up keys in the cache. Each segment has its own lock, so it supports highly concurrent access.

[groupCache](https://github.com/golang/groupcache): groupcache is a distributed caching and cache-filling library that can replace memcached in many cases. In many cases, it can even be used as a replacement for a pool of in-memory cache nodes. The implementation principle of groupcache is exactly the same as the approach implemented in the previous chapter of this article.


[fastcache](https://github.com/VictoriaMetrics/fastcache): fastcache does not have the concept of cache expiration. Key-value pairs are evicted from the cache only when the cache size overflows. A key’s deadline can be stored inside the value to implement cache expiration. A fastcache cache consists of many buckets, and each bucket has its own lock. This helps scale performance on multicore CPUs, because multiple CPUs can access different buckets concurrently. Each bucket consists of a hash(key)->(key,value) map and 64KB byte slices (chunks); these byte slices store encoded (key,value) pairs. Each bucket contains only chunksCount pointers. For example, a 64GB cache contains about 1M pointers, whereas a similarly sized map[string][]byte would contain 1B pointers for small keys and values. This saves a huge amount of GC overhead. Compared with a single chunk in each bucket, 64KB chunks reduce memory fragmentation and total memory usage. If possible, large chunks are allocated off-heap. This reduces total memory usage because GC can collect unused memory more frequently without requiring GOGC tuning.

[ristretto](https://github.com/dgraph-io/ristretto): ristretto has an excellent cache hit ratio. Its eviction policy uses a simple LFU, whose performance is comparable to LRU and performs better on search and database traces. Its admission policy uses TinyLFU, which has almost no memory overhead (12 bits per counter). The eviction policy is based on cost: any key with a high cost can evict multiple keys with lower costs (cost can be a custom metric).

The following are the performance curves of these libraries:

References to a CODASYL database over one hour:

![](https://img.halfrost.com/Blog/ArticleImage/146_15.svg)

A database server running on a commercial site, running an ERP application on top of a commercial database:

![](https://img.halfrost.com/Blog/ArticleImage/146_16.svg)

Cyclic access pattern:

![](https://img.halfrost.com/Blog/ArticleImage/146_17.svg)

Disk-read accesses initiated by a large commercial search engine in response to various Web search requests:

![](https://img.halfrost.com/Blog/ArticleImage/146_18.svg)

Throughput:

![](https://img.halfrost.com/Blog/ArticleImage/146_19.svg)

![](https://img.halfrost.com/Blog/ArticleImage/146_20.svg)

![](https://img.halfrost.com/Blog/ArticleImage/146_21.svg)

## Recommended Reading

[BP-Wrapper: A System Framework Making Any
Replacement Algorithms (Almost) Lock Contention Free](https://dgraph.io/blog/refs/bp_wrapper.pdf)  
[Adaptive Software Cache Management](https://dgraph.io/blog/refs/Adaptive%20Software%20Cache%20Management.pdf)  
[TinyLFU: A Highly Efficient Cache Admission Policy](https://dgraph.io/blog/refs/TinyLFU%20-%20A%20Highly%20Efficient%20Cache%20Admission%20Policy.pdf)
[LIRS: An Efficient Low Inter-reference Recency Set Replacement Policy to Improve Buffer Cache Performance](http://web.cse.ohio-state.edu/hpcs/WWW/HTML/publications/papers/TR-02-6.pdf)
[ARC: A Self-Tuning, Low Overhead Replacement Cache](https://www.usenix.org/event/fast03/tech/full_papers/megiddo/megiddo.pdf)