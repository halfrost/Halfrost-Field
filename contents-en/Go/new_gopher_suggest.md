# Some Go Pitfalls and Classic Code Summary

## I. Tips

- Never declare variables in a form like `var p*a`; this confuses pointer declarations with multiplication.
- Never modify the counter variable inside the `for` loop itself.
- Never use a value in a `for-range` loop to modify that same value.
- Never use `goto` together with a preceding label.
- Never forget to add parentheses `()` after a function name, especially when calling an object's method or starting a goroutine with an anonymous function.
- Never use `new()` to create a map; always use `make`.
- When defining a `String()` method for a type, do not use `fmt.Print` or similar code.
- Never forget to use the `Flush` function when finishing buffered writes.
- Never ignore error messages; ignoring errors can cause the program to crash.
- Do not use global variables or shared memory; this makes concurrently executed code unsafe.
- The `println` function is only intended for debugging.

Best practices: compare the following usage patterns:

- Use the correct approach to initialize a map whose elements are slices, for example `map[type]slice`.
- Always use the comma, ok or checked form for type assertions.
- Use a factory function to create and initialize your custom types.
- Use a pointer to a struct as the method receiver only when the method needs to modify the struct; otherwise, use the struct value type.
 
 
 
## II. Points to Watch
 
 
### 0. Common Printf Printing
```go

%d          int variable
%x, %o, %b  int in hexadecimal，octal，binary respectively
%f, %g, %e  floating-point numbers： 3.141593 3.141592653589793 3.141593e+00
%t          boolean variable：true or false
%c          rune (Unicode code point)，Go-specific Unicode character type
%s          string
%q          double-quoted string "abc" or single-quoted rune 'c'
%v          prints any variable in a readable form
%T          prints the variable's type
%%          character percent marker（the % sign itself，no other operation）


-------------------------------


\a      bell
\b      backspace
\f      form feed
\n      newline
\r      carriage return
\t      tab
\v      vertical tab
\'      single quote (only used in rune literals of the '\'' form)
\"      double quote (only used in string literals of the "..." form)
\\      backslash


```

### 1. Misusing Short Declarations Causing Variable Shadowing
```go
var remember bool = false
if something {
    remember := true //error
}
// Use remember
```
In this code snippet, the `remember` variable will never become `true` outside the `if` statement. If `something` is `true`, because the short declaration `:=` is used, the new `remember` variable inside the `if` statement shadows the outer `remember` variable, and its value is `true`. However, outside the `if` statement, the value of `remember` remains `false`. Therefore, the correct way to write it should be:
```go
if something {
    remember = true
}
```
Such errors can also easily occur in a `for` loop, and are especially hard to spot when a function returns a named variable,
as in the following code snippet:
```go
func shadow() (err error) {
    x, err := check1() // x is newly created, err is assigned
if err != nil {
    return // correctly returns err
}
if y, err := check2(x); err != nil { // y and err in the if statement are created
    return // err in the if statement shadows the outer err, so nil is returned incorrectly!
} else {
    fmt.Println(y)
}
    return
}
```

### 2. Misusing strings

When you need to perform frequent operations on a string, remember that strings in Go are immutable (similar to Java and C#). Concatenating strings using forms such as `a += b` is inefficient, especially when used inside a loop. This can lead to substantial memory overhead and copying. **Use a byte slice instead of a string, and write the string contents into a buffer.** For example, consider the following code:
```go
var b bytes.Buffer
...
for condition {
    b.WriteString(str) // Write string str to the buffer
}
    return b.String()
```
Note: Due to compiler optimizations and the string size depending on cache operations, efficiency only improves when the number of loop iterations is greater than 15.


### 3. Use `defer` to close a file when an error occurs

If you are processing a series of files inside a `for` loop, you need to use `defer` to ensure each file is closed after it has been processed, for example:
```go
for _, file := range files {
    if f, err = os.Open(file); err != nil {
        return
    }
    // This is the wrong way; the file is not closed when the loop ends
    defer f.Close()
    // Operate on the file
    f.Process(data)
}
```
However, the `defer` at the end of the loop is not executed, so the file never gets closed! The garbage collector may close the file automatically, but that would result in an error. A better approach is:
```go
for _, file := range files {
    if f, err = os.Open(file); err != nil {
        return
    }
    // Operate on the file
    f.Process(data)
    // Close the file
    f.Close()
 }
```
**`defer` is executed only when the function returns; it is not executed at the end of a loop or within some other limited-scope block of code.**

### 4. When to Use new() and make()
 
- For slices, maps, and channels, use make
- For arrays, structs, and all value types, use new 


### 5. There Is No Need to Pass a Pointer to a Slice to a Function


A slice is effectively a pointer to an underlying array. We often need to pass a slice as an argument to a function because, in practice, we are passing a pointer to a variable, which can be modified inside the function, rather than passing a copy of the data.

So you should do this:

`func findBiggest( listOfNumbers []int ) int {}`

Instead of:

`func findBiggest( listOfNumbers *[]int ) int {}` 

**When passing a slice as an argument, remember not to dereference the slice.**


### 6. Using a Pointer to an Interface Type


Consider the following program: `nexter` is an interface type, and it defines a `next()` method for reading the next byte. The function `nextFew` takes the `nexter` interface as an argument, reads the next `num` bytes, and returns a slice; this is the correct approach. However, `nextFew2` takes a pointer to the `nexter` interface type as an argument: when the `next()` function is used, the system reports a compile-time error: **n.next undefined (type *nexter has no
field or method next)** (Translator’s note: n.next is undefined (*nexter type has no field or method next))

Example 16.1 pointer_interface.go (does not compile):
```go
package main
import (
    “fmt”
)
type nexter interface {
    next() byte
}
func nextFew1(n nexter, num int) []byte {
    var b []byte
    for i:=0; i < num; i++ {
        b[i] = n.next()
    }
    return b
}
func nextFew2(n *nexter, num int) []byte {
    var b []byte
    for i:=0; i < num; i++ {
        b[i] = n.next() // Compile error: n.next is undefined (*nexter type has no next member or next method)
    }
    return b
}
func main() {
    fmt.Println(“Hello World!”)
}
```
**Never use a pointer to an interface type, because it is already a pointer.**


### 7. Misusing Pointers with Value Types

Passing a value type to a function as an argument or using it as a method receiver may seem like a waste of memory, because value types are always passed by copy. On the other hand, memory for value types is allocated on the stack, where allocation is fast and inexpensive. If you pass a pointer instead of a value type, the Go compiler will often assume that an object needs to be created and moved to the heap, resulting in additional memory allocation. Therefore, when passing a pointer instead of a value type as an argument, we gain nothing.

### 8. Misusing Goroutines and Channels

In real-world applications, if you do not need concurrent execution, or if you do not need to worry about the overhead of goroutines and channels, passing parameters through the stack is more efficient in most cases.

However, if you use `break`, `return`, or `panic` to exit a loop, it is very likely to cause a memory leak, because a goroutine may be blocked while processing something. In real code, a simple procedural loop is usually sufficient. **Use goroutines and channels if and only if concurrent execution is critical to the code.**

### 9. Using Closures and Goroutines

Consider the following code:
```go
package main

import (
    "fmt"
    "time"
)

var values = [5]int{10, 11, 12, 13, 14}

func main() {
    // Version A:
    for ix := range values { // ix is the index
        func() {
            fmt.Print(ix, " ")
        }() // call the closure to print each index
    }
    fmt.Println()
    // Version B: similar to version A, but calls the closure as a goroutine
    for ix := range values {
        go func() {
            fmt.Print(ix, " ")
        }()
    }
    fmt.Println()
    time.Sleep(5e9)
    // Version C: the correct approach
    for ix := range values {
        go func(ix interface{}) {
            fmt.Print(ix, " ")
        }(ix)
    }
    fmt.Println()
    time.Sleep(5e9)
    // Version D: output values:
    for ix := range values {
        val := values[ix]
        go func() {
            fmt.Print(val, " ")
        }()
    }
    time.Sleep(1e9)
}

```

```
Output：    
            
            0 1 2 3 4

            4 4 4 4 4

            1 0 3 4 2

            10 11 12 13 14
```
Version A calls the closure 5 times and prints each index value. Version B does the same thing, but it calls each closure via a goroutine. In theory, this should run faster because the closures execute concurrently. If we block long enough for all goroutines to finish, the output of version B is: `4 4 4 4 4`. Why does this happen? In the loop in version B, the `ix` variable is actually a single variable representing the index of each array element. Because all of these closures are bound to only that one variable, this is a relatively good way to illustrate the issue: when you run this code, you will see the last index value, `4`, printed on every iteration, rather than the index of each element. This is because the goroutines may not have started executing before the loop finishes, at which point the value of `ix` is `4`.

The loop in version C is the correct way to write this: each closure is called with `ix` passed as an argument. `ix` is reassigned on each iteration, and each goroutine’s `ix` is placed on the stack, so when the goroutine eventually executes, its corresponding index value is available to it. Note that the output here might be `0 2 1 3 4`, `0 3 1 2 4`, or some other similar sequence, depending primarily on when each goroutine starts executing.

In version D, we print the values of the array. Why does this work in version D but not in version B?

Because the variable declarations in version D are inside the loop body, these variables are not shared across iterations. Therefore, each closure can use its own independent variables.


## III. Practical Code Snippets for Performance Considerations

### 1. Strings

(1) How to modify a character in a string:
```go
str:="hello"
c:=[]byte(str)
c[0]='c'
s2:= string(c) // s2 == "cello"
```
(2) How to get a substring from a string:
```go
substr := str[n:m]
```
(3) How to use `for` or `for-range` to iterate over a string:
```go
// gives only the bytes:
for i:=0; i < len(str); i++ {
… = str[i]
}
// gives the Unicode characters:
for ix, ch := range str {
…
}
```
(4) How to get the number of bytes in a string: `len(str)`

 How to get the number of characters in a string:

 Fastest: `utf8.RuneCountInString(str)` 

 `len([]int(str))` 

(5) How to concatenate strings:

 Fastest:
`with a bytes.Buffer`

`Strings.Join()`
    
Using `+=`:
 ```go
 str1 := "Hello " 
 str2 := "World!"
 str1 += str2 //str1 == "Hello World!"
 ```
(6) How to parse command-line arguments: using the `os` or `flag` package

### 2. Arrays and Slices

Creation:
```

arr1 := new([len]type)

slice1 := make([]type, len)

```
Initialization:
```

arr1 := [...]type{i1, i2, i3, i4, i5}

arrKeyValue := [len]type{i1: val1, i2: val2}

var slice1 []type = arr1[start:end]

```
(1) How to truncate the last element of an array or slice:

`line = line[:len(line)-1]`

(2) How to iterate over an array (or slice) using `for` or `for-range`:
```go
for i:=0; i < len(arr); i++ {
… = arr[i]
}
for ix, value := range arr {
…
}
```
(3) How to find a specified value `V` in a two-dimensional array or slice `arr2Dim`:
```go
found := false
Found: for row := range arr2Dim {
    for column := range arr2Dim[row] {
        if arr2Dim[row][column] == V{
            found = true
            break Found
        }
    }
}
```

### 3. Maps

Creation:    `map1 := make(map[keytype]valuetype)`

Initialization:   `map1 := map[string]int{"one": 1, "two": 2}`

(1) How to iterate over a map using `for` or `for-range`:
```go
for key, value := range map1 {
…
}
```
(2) How to check whether the key `key1` exists in a map:

`val1, isPresent = map1[key1]`

Return values: the value corresponding to the key `key1` or `0`, and `true` or `false`
    
(3) How to delete a key from a map:

`delete(map1, key1)`

### 4. Struct

Creation:
```go
type struct1 struct {
    field1 type1
    field2 type2
    …
}
ms := new(struct1)
```
Initialization:
```go
ms := &struct1{10, 15.5, "Chris"}
```
When a struct’s name begins with an uppercase letter, the struct is visible outside the package.
Typically, define a constructor function for each struct, and it is recommended to initialize structs using the constructor.
```go    
ms := Newstruct1{10, 15.5, "Chris"}
func Newstruct1(n int, f float32, name string) *struct1 {
    return &struct1{n, f, name} 
}
```

### 5. Interfaces

(1) How to check whether a value `v` implements the interface `Stringer`:
```go
if v, ok := v.(Stringer); ok {
    fmt.Printf("implements String(): %s\n", v.String())
}
```
(2) How to use interfaces to implement a type classification function:
```go
func classifier(items ...interface{}) {
    for i, x := range items {
        switch x.(type) {
        case bool:
            fmt.Printf("param #%d is a bool\n", i)
        case float64:
            fmt.Printf("param #%d is a float64\n", i)
        case int, int64:
            fmt.Printf("param #%d is an int\n", i)
        case nil:
            fmt.Printf("param #%d is nil\n", i)
        case string:
            fmt.Printf("param #%d is a string\n", i)
        default:
            fmt.Printf("param #%d’s type is unknown\n", i)
        }
    }
}
```

### 6. Functions

How to use the built-in function `recover` to stop the `panic` process:
```go
func protect(g func()) {
    defer func() {
        log.Println("done")
        // Println executes normally even if there is a panic
        if x := recover(); x != nil {
            log.Printf("run time panic: %v", x)
        }
    }()
    log.Println("start")
    g()
}
```

### 7. Files

(1) How to open and read a file:
```go    
file, err := os.Open("input.dat")
  if err != nil {
    fmt.Printf("An error occurred on opening the inputfile\n" +
      "Does the file exist?\n" +
      "Have you got acces to it?\n")
    return
  }
  defer file.Close()
  iReader := bufio.NewReader(file)
  for {
    str, err := iReader.ReadString('\n')
    if err != nil {
      return // error or EOF
    }
    fmt.Printf("The input was: %s", str)
  }
```
(2) How to read and write files using slices:
```go
func cat(f *file.File) {
  const NBUF = 512
  var buf [NBUF]byte
  for {
    switch nr, er := f.Read(buf[:]); true {
    case nr < 0:
      fmt.Fprintf(os.Stderr, "cat: error reading from %s: %s\n",
        f.String(), er.String())
      os.Exit(1)
    case nr == 0: // EOF
      return
    case nr > 0:
      if nw, ew := file.Stdout.Write(buf[0:nr]); nw != nr {
        fmt.Fprintf(os.Stderr, "cat: error writing from %s: %s\n",
          f.String(), ew.String())
      }
    }
  }
}
```

### 8. Goroutines and Channels


Performance-oriented recommendations:
    
Practical experience shows that if you achieve higher efficiency with parallel computation than with serial computation, most of the work already completed inside the goroutine has a higher cost than creating goroutines and communicating between them.

1 For performance reasons, use buffered channels:

Using buffered channels can very easily increase throughput severalfold; in some scenarios, performance can improve by 10x or more. By tuning the channel capacity, you can even try to optimize performance further.

2 Limit the number of data items sent over a channel and package them into an array:

If a channel is used to pass a large number of individual data items, the channel will become a performance bottleneck. However, by packaging blocks of data into arrays and unpacking them on the receiving end, performance can improve by up to 10x.

Creation: `ch := make(chan type,buf)`

(1) How to iterate over a channel using `for` or `for-range`:
```go
for v := range ch {
    // do something with v
}
```
(2) How to detect whether a channel `ch` is closed:
```go
//read channel until it closes or error-condition
for {
    if input, open := <-ch; !open {
        break
    }
    fmt.Printf("%s", input)
}
```
Alternatively, use (1) automatic detection.

(3) How to use a channel to make the main program wait until the goroutine completes:

(semaphore pattern):
```go
ch := make(chan int) // Allocate a channel.
// Start something in a goroutine; when it completes, signal on the channel.
go func() {
    // doSomething
    ch <- 1 // Send a signal; value does not matter.
}()
doSomethingElseForAWhile()
<-ch // Wait for goroutine to finish; discard sent value.
```
If you want the program to block indefinitely, simply omit `ch <- 1` from the anonymous function.

(4) Channel factory template: The following function is a channel factory that starts an anonymous function as a goroutine to produce a channel:
```go
func pump() chan int {
    ch := make(chan int)
    go func() {
        for i := 0; ; i++ {
            ch <- i
        }
    }()
    return ch
}
```
（5）Channel iterator template:
  
（6）How to limit the number of concurrently processed requests

（7）How to implement parallel computation on multi-core CPUs

（8）How to terminate a goroutine: `runtime.Goexit()`  

（9）Simple timeout template:
```go  
timeout := make(chan bool, 1)
go func() {
    time.Sleep(1e9) // one second  
    timeout <- true
}()
select {
    case <-ch:
    // a read from ch has occurred
    case <-timeout:
    // the read from ch has timed out
}
```
(10) How to use input and output channels instead of locks:
```go
func Worker(in, out chan *Task) {
    for {
        t := <-in
        process(t)
        out <- t
    }
}
```
(11) How to discard a synchronous call when it runs for too long

(12) How to use timers and tickers with channels

(13) Typical server backend models


### 9. Network and Web Applications


Creating, parsing, and executing templates:
```go        
var strTempl = template.Must(template.New("TName").Parse(strTemplateHTML))
```
In a web application, use the HTML filter to escape HTML special characters:
    
`{{html .}}` or via a field: `FieldName {{ .FieldName |html }}`

Use cached templates. 


How to terminate the program when an error occurs:
```go	
if err != nil {
   fmt.Printf(“Program stopping with error %v”, err)
   os.Exit(1)
}
```
Or:
```go

if err != nil { 
panic(“ERROR occurred: “ + err.Error())
}

```

### 10. Performance-Oriented Best Practices and Recommendations

(1) Use `:=` whenever possible to initialize and declare a variable (inside a function);

(2) Use characters instead of strings whenever possible;

(3) Use slices instead of arrays whenever possible;

(4) Use arrays and slices instead of maps whenever possible;

(5) If you only need to retrieve values from a slice and do not need their indices, use `for range` to iterate over the slice whenever possible; this is slightly faster than having to look up each element in the slice;

(6) When array elements are sparse (for example, many `0` values or empty `nil` values), using a map reduces memory consumption;

(7) Specify the capacity when initializing a map;

(8) When defining a method, use a pointer type as the method receiver;

(9) Use constants or flags in the code to extract constant values;

(10) Use caching whenever possible when allocating large amounts of memory;

(11) Use cached templates.


     
 ------------

Reference:    
Excerpted from [The Way to Go](https://github.com/Unknwon/the-way-to-go_ZH_CN/blob/master/eBook/directory.md)   


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()