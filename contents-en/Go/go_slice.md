# In-Depth Analysis of Go Slice Internals

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b518b225f82815fa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


A slice is a fundamental data structure in Go that can be used to manage collections of data. The design of slices comes from the concept of dynamic arrays, making it more convenient for developers to use a data structure that can grow and shrink automatically. However, a slice itself is not a dynamic array or an array pointer. Common slice operations include reslice, append, and copy. At the same time, slices also have excellent properties such as being indexable and iterable.

## 1. Slices and Arrays


![](http://upload-images.jianshu.io/upload_images/1194012-168e0799620a2cdb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


How should you choose between slices and arrays? Let’s discuss this question in detail.

In Go, unlike C where array variables are implicitly used as pointers, Go arrays are value types. Assignment and passing arrays as function arguments both copy the entire array data.
```go

func main() {
	arrayA := [2]int{100, 200}
	var arrayB [2]int

	arrayB = arrayA

	fmt.Printf("arrayA : %p , %v\n", &arrayA, arrayA)
	fmt.Printf("arrayB : %p , %v\n", &arrayB, arrayB)

	testArray(arrayA)
}

func testArray(x [2]int) {
	fmt.Printf("func Array : %p , %v\n", &x, x)
}


```
Output:
```go

arrayA : 0xc4200bebf0 , [100 200]
arrayB : 0xc4200bec00 , [100 200]
func Array : 0xc4200bec30 , [100 200]

```
As you can see, all three memory addresses are different. This confirms that in Go, both array assignment and passing arrays to functions are value copies. So what problem does this cause?

Imagine using arrays for every function argument. Each time, the entire array would have to be copied. If the array has 1 million elements, on a 64-bit machine this would cost roughly 8 million bytes, or 8 MB of memory. That would consume a large amount of memory. So some people thought of passing pointers to arrays to functions instead.
```go

func main() {
	arrayA := [2]int{100, 200}
	testArrayPoint1(&arrayA) // 1.Pass array pointer
	arrayB := arrayA[:]
	testArrayPoint2(&arrayB) // 2.Pass slice
	fmt.Printf("arrayA : %p , %v\n", &arrayA, arrayA)
}

func testArrayPoint1(x *[2]int) {
	fmt.Printf("func Array : %p , %v\n", x, *x)
	(*x)[1] += 100
}

func testArrayPoint2(x *[]int) {
	fmt.Printf("func Array : %p , %v\n", x, *x)
	(*x)[1] += 100
}

```
Output:
```go

func Array : 0xc4200b0140 , [100 200]
func Array : 0xc4200b0180 , [100 300]
arrayA : 0xc4200b0140 , [100 400]

```
This also proves that the array pointer indeed achieves the effect we want. Now, even if an array of 1 billion elements is passed in, only 8 bytes of memory need to be allocated on the stack for the pointer. This uses memory more efficiently and performs better than before.

However, passing a pointer has one drawback. As the printed results show, the pointer addresses in the first and third lines are the same. If the pointer to the original array changes, the pointer inside the function will change along with it.

This is where the advantage of slices becomes apparent. Passing an array parameter as a slice both saves memory and properly handles shared memory. The second line of the printed results is the slice; the slice’s pointer is different from the original array’s pointer.

From this, we can conclude:

Passing the first large array to a function consumes a lot of memory. Passing parameters as slices can avoid the problem above. Slices are passed by reference, so they do not require additional memory and are more efficient than arrays.

However, there are still counterexamples.
```go

package main

import "testing"

func array() [1024]int {
	var x [1024]int
	for i := 0; i < len(x); i++ {
		x[i] = i
	}
	return x
}

func slice() []int {
	x := make([]int, 1024)
	for i := 0; i < len(x); i++ {
		x[i] = i
	}
	return x
}

func BenchmarkArray(b *testing.B) {
	for i := 0; i < b.N; i++ {
		array()
	}
}

func BenchmarkSlice(b *testing.B) {
	for i := 0; i < b.N; i++ {
		slice()
	}
}

```
Let's run a performance test with inlining and optimizations disabled to observe heap memory allocations for slices.
```go

  go test -bench . -benchmem -gcflags "-N -l"

```
The output is rather “surprising”:
```vim

BenchmarkArray-4          500000              3637 ns/op               0 B/op          0 alloc s/op
BenchmarkSlice-4          300000              4055 ns/op            8192 B/op          1 alloc s/op

```
Here’s an explanation of the result above. When testing Array, 4 cores were used, the loop count was 500000, the average execution time per operation was 3637 ns, the total amount of heap memory allocated per operation was 0, and the allocation count was also 0.

The result for slice is a bit “worse”. It also used 4 cores, with a loop count of 300000, and the average execution time per operation was 4055 ns. However, for each execution, the total amount of heap memory allocated on the heap was 8192, and the allocation count was 1.

From this comparison, it seems that it is not always appropriate to use slices instead of arrays, because the underlying array of a slice may be allocated on the heap, and the cost of copying small arrays on the stack is not necessarily greater than the cost of `make`.


## 2. Slice Data Structure

A slice itself is neither a dynamic array nor an array pointer. Its internal data structure references the underlying array through a pointer, and uses related attributes to restrict read and write operations to a specified region. **A slice itself is a read-only object, and its working mechanism is similar to a wrapper around an array pointer**.


A slice is a reference to a contiguous segment of an array, so a slice is a reference type (therefore more similar to the Vector type in C++, or the list type in Python). This segment can be the entire array, or a subset of items identified by start and end indices. Note that the item identified by the end index is not included in the slice. A slice provides a dynamic window into an array.

The slice index of a given item may be smaller than the index of the same element in the associated array. Unlike arrays, the length of a slice can be changed at runtime, with a minimum of 0 and a maximum of the length of the associated array: a slice is a variable-length array.


The data structure of Slice is defined as follows:
```go


type slice struct {
	array unsafe.Pointer
	len   int
	cap   int
}

```
![](http://upload-images.jianshu.io/upload_images/1194012-50696670e6dd60ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

A slice’s struct consists of three parts: `Pointer` is a pointer to an array, `len` represents the current length of the slice, and `cap` is the current capacity of the slice. `cap` is always greater than or equal to `len`.


![](http://upload-images.jianshu.io/upload_images/1194012-7bd2c2afe0cf630d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


If you want to obtain a memory address from a slice, you can do it like this:
```go

s := make([]byte, 200)
ptr := unsafe.Pointer(&s[0])

```
What about the other way around? Constructing a slice from a Go memory address.
```go


var ptr unsafe.Pointer
var s1 = struct {
    addr uintptr
    len int
    cap int
}{ptr, length, length}
s := *(*[]byte)(unsafe.Pointer(&s1))

```
Construct a virtual struct to piece together the data structure of a slice.

Of course, there is also a more direct approach: Go’s reflection package provides a corresponding data structure, `SliceHeader`, which we can use to construct a slice.
```go

var o []byte
sliceHeader := (*reflect.SliceHeader)((unsafe.Pointer(&o)))
sliceHeader.Cap = length
sliceHeader.Len = length
sliceHeader.Data = uintptr(ptr)

```

## 3. Creating Slices

The make function allows the array length to be specified dynamically at runtime, bypassing the restriction that array types must use compile-time constants.

There are two ways to create a slice: using make to create a slice, and creating an empty slice.

### 1. make and Slice Literals
```go

func makeslice(et *_type, len, cap int) slice {
	// Get the maximum capacity of the slice based on its element type
	maxElements := maxSliceCap(et.size)
    // Check the slice length; it should be in [0,maxElements]
	if len < 0 || uintptr(len) > maxElements {
		panic(errorString("makeslice: len out of range"))
	}
    // Check the slice capacity; it should be in [len,maxElements]
	if cap < len || uintptr(cap) > maxElements {
		panic(errorString("makeslice: cap out of range"))
	}
    // Allocate memory based on the slice capacity
	p := mallocgc(et.size*uintptr(cap), et, true)
    // Return the starting address of the slice with allocated memory
	return slice{p, len, cap}
}

```
There is also an `int64` version:
```go

func makeslice64(et *_type, len64, cap64 int64) slice {
	len := int(len64)
	if int64(len) != len64 {
		panic(errorString("makeslice: len out of range"))
	}

	cap := int(cap64)
	if int64(cap) != cap64 {
		panic(errorString("makeslice: cap out of range"))
	}

	return makeslice(et, len, cap)
}

```
The implementation principle is the same as above; it just adds the step of converting `int64` to `int`.

![](http://upload-images.jianshu.io/upload_images/1194012-f2ef58e1c51dbdca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The figure above shows a slice created with the `make` function, with `len = 4` and `cap = 6`. Memory space for 6 `int` values has been allocated. Since `len = 4`, the last 2 elements cannot be accessed for the time being, but the capacity is still there. At this point, every variable in the array is `0`.

In addition to the `make` function, slices can also be created using literals.


![](http://upload-images.jianshu.io/upload_images/1194012-a071b77f73cc1caf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here, a slice with `len = 6` and `cap = 6` is created using a literal. At this point, the value of every element in the array has been initialized. **One thing to note is that you should not specify the array capacity inside `[ ]`, because once you specify the number of elements, it becomes an array rather than a slice.**


![](http://upload-images.jianshu.io/upload_images/1194012-ca3efc461762e51a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There is another simple way to create a slice using a literal, as shown above. In the figure above, Slice A creates a slice with `len = 3` and `cap = 3`. It slices from the second element of the original array (`0` is the first element) up to the fourth element (not including the fifth element). Similarly, Slice B creates a slice with `len = 2` and `cap = 4`.


### 2. nil and Empty Slices


nil slices and empty slices are also commonly used.
```go

var slice []int

```
![](http://upload-images.jianshu.io/upload_images/1194012-171ae1a89c3b1579.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Nil slices are used in many standard libraries and built-in functions. When you need to represent a slice that does not exist, you use a nil slice. For example, when a function encounters an error, the slice it returns is a nil slice. The pointer of a nil slice points to nil.


Empty slices are generally used to represent an empty collection. For example, if a database query returns no results, you can return an empty slice.
```go

silce := make( []int , 0 )
slice := []int{ }

```
![](http://upload-images.jianshu.io/upload_images/1194012-c09c59f12e3bfedd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The difference between an empty slice and a nil slice is that the address an empty slice points to is not `nil`; it points to a memory address, but no memory space has been allocated for elements—in other words, the underlying array contains 0 elements.

One final point to note: whether you use a nil slice or an empty slice, calling the built-in functions `append`, `len`, and `cap` on it has the same effect.


## IV. Slice Capacity Growth

When a slice’s capacity is full, it needs to grow. How does it grow, and what is the strategy?
```go

func growslice(et *_type, old slice, cap int) slice {
	if raceenabled {
		callerpc := getcallerpc(unsafe.Pointer(&et))
		racereadrangepc(old.array, uintptr(old.len*int(et.size)), callerpc, funcPC(growslice))
	}
	if msanenabled {
		msanread(old.array, uintptr(old.len*int(et.size)))
	}

	if et.size == 0 {
		// If the new capacity to grow to is smaller than the original capacity, that means shrinking, so panic directly.
		if cap < old.cap {
			panic(errorString("growslice: cap out of range"))
		}

		// If the current slice size is 0 and growth is still requested, create and return a new slice with the new capacity.
		return slice{unsafe.Pointer(&zerobase), old.len, cap}
	}

    // This is the growth strategy.
	newcap := old.cap
	doublecap := newcap + newcap
	if cap > doublecap {
		newcap = cap
	} else {
		if old.len < 1024 {
			newcap = doublecap
		} else {
			// Check 0 < newcap to detect overflow
			// and prevent an infinite loop.
			for 0 < newcap && newcap < cap {
				newcap += newcap / 4
			}
			// Set newcap to the requested cap when
			// the newcap calculation overflowed.
			if newcap <= 0 {
				newcap = cap
			}
		}
	}

	// Calculate the new slice capacity and length.
	var lenmem, newlenmem, capmem uintptr
	const ptrSize = unsafe.Sizeof((*byte)(nil))
	switch et.size {
	case 1:
		lenmem = uintptr(old.len)
		newlenmem = uintptr(cap)
		capmem = roundupsize(uintptr(newcap))
		newcap = int(capmem)
	case ptrSize:
		lenmem = uintptr(old.len) * ptrSize
		newlenmem = uintptr(cap) * ptrSize
		capmem = roundupsize(uintptr(newcap) * ptrSize)
		newcap = int(capmem / ptrSize)
	default:
		lenmem = uintptr(old.len) * et.size
		newlenmem = uintptr(cap) * et.size
		capmem = roundupsize(uintptr(newcap) * et.size)
		newcap = int(capmem / et.size)
	}

	// Check for invalid values to ensure the capacity is increasing and does not exceed the maximum.
	if cap < old.cap || uintptr(newcap) > maxSliceCap(et.size) {
		panic(errorString("growslice: cap out of range"))
	}

	var p unsafe.Pointer
	if et.kind&kindNoPointers != 0 {
		// Continue expanding capacity after the old slice.
		p = mallocgc(capmem, nil, false)
		// Copy lenmem bytes from the old.array address to the address at p.
		memmove(p, old.array, lenmem)
		// First add the new capacity to address P to get the address of the new slice capacity, then initialize the capmem-newlenmem bytes after that address. This makes room for later append() operations.
		memclrNoHeapPointers(add(p, newlenmem), capmem-newlenmem)
	} else {
		// Allocate a new array for the new slice.
		// Reallocate a memory block of size capmen and initialize it to the zero value.
		p = mallocgc(capmem, et, true)
		if !writeBarrier.enabled {
			// If the write barrier cannot be enabled yet, only copy lenmem bytes from old.array to the address at p.
			memmove(p, old.array, lenmem)
		} else {
			// Copy the values of the old slice in a loop.
			for i := uintptr(0); i < lenmem; i += et.size {
				typedmemmove(et, add(p, i), add(old.array, i))
			}
		}
	}
	// Return the final new slice, with capacity updated to the latest expanded capacity.
	return slice{p, old.len, newcap}
}

```
The above is how expansion is implemented. There are two main points to focus on: one is the strategy used during expansion, and the other is whether expansion allocates a completely new memory address or appends after the original address.

#### 1. Expansion Strategy

First, let’s look at the expansion strategy.
```go

func main() {
	slice := []int{10, 20, 30, 40}
	newSlice := append(slice, 50)
	fmt.Printf("Before slice = %v, Pointer = %p, len = %d, cap = %d\n", slice, &slice, len(slice), cap(slice))
	fmt.Printf("Before newSlice = %v, Pointer = %p, len = %d, cap = %d\n", newSlice, &newSlice, len(newSlice), cap(newSlice))
	newSlice[1] += 10
	fmt.Printf("After slice = %v, Pointer = %p, len = %d, cap = %d\n", slice, &slice, len(slice), cap(slice))
	fmt.Printf("After newSlice = %v, Pointer = %p, len = %d, cap = %d\n", newSlice, &newSlice, len(newSlice), cap(newSlice))
}

```
Output result:
```go

Before slice = [10 20 30 40], Pointer = 0xc4200b0140, len = 4, cap = 4
Before newSlice = [10 20 30 40 50], Pointer = 0xc4200b0180, len = 5, cap = 8
After slice = [10 20 30 40], Pointer = 0xc4200b0140, len = 4, cap = 4
After newSlice = [10 30 30 40 50], Pointer = 0xc4200b0180, len = 5, cap = 8

```
Illustrate the above process with a diagram.


![](http://upload-images.jianshu.io/upload_images/1194012-4169615963b6e50a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From the diagram, we can easily see that the new slice is different from the previous slice: the new slice changed a value without affecting the original array. The array the new slice points to is a completely new array. Its cap has also changed. So what exactly happened here?

The slice growth strategy in Go is as follows:

- First, if the newly requested capacity (cap) is greater than twice the old capacity (old.cap), the final capacity (newcap) is the newly requested capacity (cap).  
- Otherwise, if the old slice length is less than 1024, the final capacity (newcap) is twice the old capacity (old.cap), i.e. (newcap=doublecap).  
- Otherwise, if the old slice length is greater than or equal to 1024, the final capacity (newcap) starts from the old capacity (old.cap) and repeatedly increases by 1/4 of itself, i.e. (newcap=old.cap,for {newcap += newcap/4}), until the final capacity (newcap) is greater than or equal to the newly requested capacity (cap), i.e. (newcap >= cap).  
- If the computed final capacity (cap) overflows, the final capacity (cap) is the newly requested capacity (cap).

~~If the slice capacity is less than 1024 elements, capacity is doubled during growth. The example above also verifies this: the total capacity doubled from the original 4 to 8.~~

~~Once the number of elements exceeds 1024, the growth factor becomes 1.25; that is, each growth increases capacity by one quarter of the previous capacity.~~

**Note: the capacity increase during growth is relative to the original capacity, not the length of the original array.**

#### 2. New array or old array?

Now let’s talk about whether the array after growth is necessarily a new one. Not always; there are two cases.

Case 1:
```go

func main() {
	array := [4]int{10, 20, 30, 40}
	slice := array[0:2]
	newSlice := append(slice, 50)
	fmt.Printf("Before slice = %v, Pointer = %p, len = %d, cap = %d\n", slice, &slice, len(slice), cap(slice))
	fmt.Printf("Before newSlice = %v, Pointer = %p, len = %d, cap = %d\n", newSlice, &newSlice, len(newSlice), cap(newSlice))
	newSlice[1] += 10
	fmt.Printf("After slice = %v, Pointer = %p, len = %d, cap = %d\n", slice, &slice, len(slice), cap(slice))
	fmt.Printf("After newSlice = %v, Pointer = %p, len = %d, cap = %d\n", newSlice, &newSlice, len(newSlice), cap(newSlice))
	fmt.Printf("After array = %v\n", array)
}

```
Print output:
```go

Before slice = [10 20], Pointer = 0xc4200c0040, len = 2, cap = 4
Before newSlice = [10 20 50], Pointer = 0xc4200c0060, len = 3, cap = 4
After slice = [10 30], Pointer = 0xc4200c0040, len = 2, cap = 4
After newSlice = [10 30 50], Pointer = 0xc4200c0060, len = 3, cap = 4
After array = [10 30 50 40]

```
Represent the process above with a diagram, as shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-f6d4f66850cf88c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


From the printed output, we can see that in this case, after the slice grows, no new array is created. The array before and after the growth is the same one. As a result, when the new slice modifies a value, it also affects the old slice. In addition, the `append()` operation also changes values in the original array. A single `append()` operation affects so many places. If there are multiple slices backed by the original array, all of them will be affected! This can inadvertently lead to obscure bugs!

In this case, because the original array still has spare capacity for growth, after the `append()` operation is executed, it operates directly on the original array. Therefore, in this case, the array after growth still points to the original array.


This situation is also very likely to occur when creating a slice literal with a third `cap` argument. If a slice is created using a literal and `cap` is not equal to the total capacity of the underlying array, this situation can occur.
```go

slice := array[1:2:3]

```
**The situation above is very dangerous and extremely prone to bugs.**


When creating a slice with a literal, you should be very mindful of the value of `cap` to avoid bugs caused by sharing the underlying array.


Scenario 2:

Scenario 2 is essentially the example given in the growth strategy section. In that example, a new slice was created because the capacity of the original array had already reached its maximum. To grow it further, Go by default first allocates a new memory region, copies the original values over, and then performs the `append()` operation. This situation does not affect the original array at all.

Therefore, it is recommended to avoid Scenario 1 as much as possible and use Scenario 2 instead, to prevent bugs.


## 5. Copying Slices

There are two ways to copy slices in Slice.
```go

func slicecopy(to, fm slice, width uintptr) int {
	// If either the source slice or destination slice has length 0, no copy is needed; return directly
	if fm.len == 0 || to.len == 0 {
		return 0
	}
	// n records the length of the shorter of the source slice and destination slice
	n := fm.len
	if to.len < n {
		n = to.len
	}
	// If the input width = 0, no copy is needed; return the length of the shorter slice
	if width == 0 {
		return n
	}
	// If race detection is enabled
	if raceenabled {
		callerpc := getcallerpc(unsafe.Pointer(&to))
		pc := funcPC(slicecopy)
		racewriterangepc(to.array, uintptr(n*int(width)), callerpc, pc)
		racereadrangepc(fm.array, uintptr(n*int(width)), callerpc, pc)
	}
	// If The memory sanitizer (msan) is enabled
	if msanenabled {
		msanwrite(to.array, uintptr(n*int(width)))
		msanread(fm.array, uintptr(n*int(width)))
	}

	size := uintptr(n) * width
	if size == 1 { 
		// TODO: is this still worth it with new memmove impl?
		// If there is only one element, the pointer can be converted directly
		*(*byte)(to.array) = *(*byte)(fm.array) // known to be a byte pointer
	} else {
		// If there is more than one element, copy size bytes starting at fm.array to to.array
		memmove(to.array, fm.array, size)
	}
	return n
}


```
In this method, the `slicecopy` method copies elements from the source slice value (that is, the fm Slice) into the target slice (that is, the to Slice), and returns the number of elements copied. The two operands passed to `copy` must have the same type. The final result of the `slicecopy` method depends on the shorter slice: once the shorter slice has been fully copied, the entire copy operation is complete.


![](http://upload-images.jianshu.io/upload_images/1194012-050f1ea8c98fd9ea.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


For example:
```go

func main() {
	array := []int{10, 20, 30, 40}
	slice := make([]int, 6)
	n := copy(slice, array)
	fmt.Println(n,slice)
}

```
There is another copy method as well. Its principle is similar to the `slicecopy` method, so I won’t go into it again; the comments are included in the code.
```go


func slicestringcopy(to []byte, fm string) int {
	// If either the source slice or the destination slice has length 0, no copy is needed; return directly 
	if len(fm) == 0 || len(to) == 0 {
		return 0
	}
	// n records the length of the shorter of the source slice and the destination slice
	n := len(fm)
	if len(to) < n {
		n = len(to)
	}
	// If race detection is enabled
	if raceenabled {
		callerpc := getcallerpc(unsafe.Pointer(&to))
		pc := funcPC(slicestringcopy)
		racewriterangepc(unsafe.Pointer(&to[0]), uintptr(n), callerpc, pc)
	}
	// If the memory sanitizer (msan) is enabled
	if msanenabled {
		msanwrite(unsafe.Pointer(&to[0]), uintptr(n))
	}
	// Copy the string to the byte array
	memmove(unsafe.Pointer(&to[0]), stringStructOf(&fm).str, uintptr(n))
	return n
}


```
To give another example:
```go

func main() {
	slice := make([]byte, 3)
	n := copy(slice, "abcdef")
	fmt.Println(n,slice)
}

```
Output:
```go

3 [97,98,99]

```
When it comes to copying, there is one issue with slices that you need to watch out for.
```go

func main() {
	slice := []int{10, 20, 30, 40}
	for index, value := range slice {
		fmt.Printf("value = %d , value-addr = %x , slice-addr = %x\n", value, &value, &slice[index])
	}
}

```
Output:
```go

value = 10 , value-addr = c4200aedf8 , slice-addr = c4200b0320
value = 20 , value-addr = c4200aedf8 , slice-addr = c4200b0328
value = 30 , value-addr = c4200aedf8 , slice-addr = c4200b0330
value = 40 , value-addr = c4200aedf8 , slice-addr = c4200b0338


```
From the results above, we can see that when iterating over a slice with `range`, the Value obtained is actually a copy of the value in the slice. Therefore, the address of Value remains the same each time it is printed.


![](http://upload-images.jianshu.io/upload_images/1194012-2c6325ccf25d5253.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Because Value is a value copy, not passed by reference, directly modifying Value will not achieve the goal of changing the original slice value. You need to use `&slice[index]` to obtain the actual address.


------------------------------------------------------

Reference:  
*Go in Action*  
*Go Language Study Notes*


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_slice/](https://halfrost.com/go_slice/)