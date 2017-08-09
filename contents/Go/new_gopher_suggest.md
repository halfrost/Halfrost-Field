# Go 的一些坑和经典代码总结

## 一. 提示

- 永远不要使用形如 `var p*a` 声明变量，这会混淆指针声明和乘法运算。
- 永远不要在`for`循环自身中改变计数器变量。
- 永远不要在`for-range`循环中使用一个值去改变自身的值。
- 永远不要将`goto`和前置标签一起使用。
- 永远不要忘记在函数名后加括号()，尤其调用一个对象的方法或者使用匿名函数启动一个协程时。
- 永远不要使用`new()`一个map，一直使用make。
- 当为一个类型定义一个String()方法时，不要使用`fmt.Print`或者类似的代码。
- 永远不要忘记当终止缓存写入时，使用`Flush`函数。
- 永远不要忽略错误提示，忽略错误会导致程序奔溃。
- 不要使用全局变量或者共享内存，这会使并发执行的代码变得不安全。
- `println`函数仅仅是用于调试的目的。

最佳实践：对比以下使用方式：

- 使用正确的方式初始化一个元素是切片的映射，例如`map[type]slice`。
- 一直使用逗号，ok或者checked形式作为类型断言。
- 使用一个工厂函数创建并初始化自己定义类型。
- 仅当一个结构体的方法想改变结构体时，使用结构体指针作为方法的接受者，否则使用一个结构体值类型。
 
 
 
## 二. 需要注意
 
 
### 0. 常见 Printf 打印

```go

%d          int变量
%x, %o, %b  分别为16进制，8进制，2进制形式的int
%f, %g, %e  浮点数： 3.141593 3.141592653589793 3.141593e+00
%t          布尔变量：true 或 false
%c          rune (Unicode码点)，Go语言里特有的Unicode字符类型
%s          string
%q          带双引号的字符串 "abc" 或 带单引号的 rune 'c'
%v          会将任意变量以易读的形式打印出来
%T          打印变量的类型
%%          字符型百分比标志（%符号本身，没有其他操作）


-------------------------------


\a      响铃
\b      退格
\f      换页
\n      换行
\r      回车
\t      制表符
\v      垂直制表符
\'      单引号 (只用在 '\'' 形式的rune符号面值中)
\"      双引号 (只用在 "..." 形式的字符串面值中)
\\      反斜杠



```


### 1. 误用短声明导致变量覆盖

```go
var remember bool = false
if something {
    remember := true //错误
}
// 使用remember
```

在此代码段中，`remember`变量永远不会在`if`语句外面变成`true`，如果`something`为`true`，由于使用了短声明`:=`，`if`语句内部的新变量`remember`将覆盖外面的`remember`变量，并且该变量的值为`true`，但是在`if`语句外面，变量`remember`的值变成了`false`，所以正确的写法应该是：

```go
if something {
    remember = true
}
```

此类错误也容易在`for`循环中出现，尤其当函数返回一个具名变量时难于察觉
，例如以下的代码段：

```go
func shadow() (err error) {
    x, err := check1() // x是新创建变量，err是被赋值
if err != nil {
    return // 正确返回err
}
if y, err := check2(x); err != nil { // y和if语句中err被创建
    return // if语句中的err覆盖外面的err，所以错误的返回nil！
} else {
    fmt.Println(y)
}
    return
}
```
 
### 2. 误用字符串

当需要对一个字符串进行频繁的操作时，谨记在go语言中字符串是不可变的（类似java和c#）。使用诸如`a += b`形式连接字符串效率低下，尤其在一个循环内部使用这种形式。这会导致大量的内存开销和拷贝。**应该使用一个字符数组代替字符串，将字符串内容写入一个缓存中。** 例如以下的代码示例：

```go
var b bytes.Buffer
...
for condition {
    b.WriteString(str) // 将字符串str写入缓存buffer
}
    return b.String()
```

注意：由于编译优化和依赖于使用缓存操作的字符串大小，当循环次数大于15时，效率才会更佳。


### 3. 发生错误时使用defer关闭一个文件

如果你在一个for循环内部处理一系列文件，你需要使用defer确保文件在处理完毕后被关闭，例如：

```go
for _, file := range files {
    if f, err = os.Open(file); err != nil {
        return
    }
    // 这是错误的方式，当循环结束时文件没有关闭
    defer f.Close()
    // 对文件进行操作
    f.Process(data)
}
```

但是在循环结尾处的defer没有执行，所以文件一直没有关闭！垃圾回收机制可能会自动关闭文件，但是这会产生一个错误，更好的做法是：

```go
for _, file := range files {
    if f, err = os.Open(file); err != nil {
        return
    }
    // 对文件进行操作
    f.Process(data)
    // 关闭文件
    f.Close()
 }
```

**defer仅在函数返回时才会执行，在循环的结尾或其他一些有限范围的代码内不会执行。**

### 4. 何时使用new()和make()
 
- 切片、映射和通道，使用make
- 数组、结构体和所有的值类型，使用new 


### 5. 不需要将一个指向切片的指针传递给函数


切片实际是一个指向潜在数组的指针。我们常常需要把切片作为一个参数传递给函数是因为：实际就是传递一个指向变量的指针，在函数内可以改变这个变量，而不是传递数据的拷贝。

因此应该这样做：

`func findBiggest( listOfNumbers []int ) int {}`

而不是：

`func findBiggest( listOfNumbers *[]int ) int {}` 

**当切片作为参数传递时，切记不要解引用切片。**


### 6. 使用指针指向接口类型


查看如下程序：`nexter`是一个接口类型，并且定义了一个`next()`方法读取下一字节。函数`nextFew`将`nexter`接口作为参数并读取接下来的`num`个字节，并返回一个切片：这是正确做法。但是`nextFew2`使用一个指向`nexter`接口类型的指针作为参数传递给函数：当使用`next()`函数时，系统会给出一个编译错误：**n.next undefined (type *nexter has no
field or method next)** （译者注：n.next未定义（*nexter类型没有next成员或next方法））

例 16.1 pointer_interface.go (不能通过编译):

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
        b[i] = n.next() // 编译错误:n.next未定义（*nexter类型没有next成员或next方法）
    }
    return b
}
func main() {
    fmt.Println(“Hello World!”)
}
```

**永远不要使用一个指针指向一个接口类型，因为它已经是一个指针。**


### 7. 使用值类型时误用指针

将一个值类型作为一个参数传递给函数或者作为一个方法的接收者，似乎是对内存的滥用，因为值类型一直是传递拷贝。但是另一方面，值类型的内存是在栈上分配，内存分配快速且开销不大。如果你传递一个指针，而不是一个值类型，go编译器大多数情况下会认为需要创建一个对象，并将对象移动到堆上，所以会导致额外的内存分配：因此当使用指针代替值类型作为参数传递时，我们没有任何收获。

### 8. 误用协程和通道

在实际应用中，你不需要并发执行，或者你不需要关注协程和通道的开销，在大多数情况下，通过栈传递参数会更有效率。

但是，如果你使用`break`、`return`或者`panic`去跳出一个循环，很有可能会导致内存溢出，因为协程正处理某些事情而被阻塞。在实际代码中，通常仅需写一个简单的过程式循环即可。**当且仅当代码中并发执行非常重要，才使用协程和通道。**

### 9. 闭包和协程的使用

请看下面代码：

```go
package main

import (
    "fmt"
    "time"
)

var values = [5]int{10, 11, 12, 13, 14}

func main() {
    // 版本A:
    for ix := range values { // ix是索引值
        func() {
            fmt.Print(ix, " ")
        }() // 调用闭包打印每个索引值
    }
    fmt.Println()
    // 版本B: 和A版本类似，但是通过调用闭包作为一个协程
    for ix := range values {
        go func() {
            fmt.Print(ix, " ")
        }()
    }
    fmt.Println()
    time.Sleep(5e9)
    // 版本C: 正确的处理方式
    for ix := range values {
        go func(ix interface{}) {
            fmt.Print(ix, " ")
        }(ix)
    }
    fmt.Println()
    time.Sleep(5e9)
    // 版本D: 输出值:
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
输出：    
            
            0 1 2 3 4

            4 4 4 4 4

            1 0 3 4 2

            10 11 12 13 14
```

版本A调用闭包5次打印每个索引值，版本B也做相同的事，但是通过协程调用每个闭包。按理说这将执行得更快，因为闭包是并发执行的。如果我们阻塞足够多的时间，让所有协程执行完毕，版本B的输出是：`4 4 4 4 4`。为什么会这样？在版本B的循环中，`ix`变量
实际是一个单变量，表示每个数组元素的索引值。因为这些闭包都只绑定到一个变量，这是一个比较好的方式，当你运行这段代码时，你将看见每次循环都打印最后一个索引值`4`，而不是每个元素的索引值。因为协程可能在循环结束后还没有开始执行，而此时`ix`值是`4`。

版本C的循环写法才是正确的：调用每个闭包是将`ix`作为参数传递给闭包。`ix`在每次循环时都被重新赋值，并将每个协程的`ix`放置在栈中，所以当协程最终被执行时，每个索引值对协程都是可用的。注意这里的输出可能是`0 2 1 3 4`或者`0 3 1 2 4`或者其他类似的序列，这主要取决于每个协程何时开始被执行。

在版本D中，我们输出这个数组的值，为什么版本B不能而版本D可以呢？

因为版本D中的变量声明是在循环体内部，所以在每次循环时，这些变量相互之间是不共享的，所以这些变量可以单独的被每个闭包使用。



## 三. 出于性能考虑的实用代码片段

### 1. 字符串

（1）如何修改字符串中的一个字符：

```go
str:="hello"
c:=[]byte(str)
c[0]='c'
s2:= string(c) // s2 == "cello"
```

（2）如何获取字符串的子串：

```go
substr := str[n:m]
```

（3）如何使用`for`或者`for-range`遍历一个字符串：

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

（4）如何获取一个字符串的字节数：`len(str)`

 如何获取一个字符串的字符数：

 最快速：`utf8.RuneCountInString(str)` 

 `len([]int(str))` 

（5）如何连接字符串：

 最快速：
`with a bytes.Buffer`

`Strings.Join()`
    
使用`+=`：

 ```go
 str1 := "Hello " 
 str2 := "World!"
 str1 += str2 //str1 == "Hello World!"
 ```

（6）如何解析命令行参数：使用`os`或者`flag`包

### 2. 数组和切片

创建：

```

arr1 := new([len]type)

slice1 := make([]type, len)

```

初始化：

```

arr1 := [...]type{i1, i2, i3, i4, i5}

arrKeyValue := [len]type{i1: val1, i2: val2}

var slice1 []type = arr1[start:end]

```

（1）如何截断数组或者切片的最后一个元素：

`line = line[:len(line)-1]`

（2）如何使用`for`或者`for-range`遍历一个数组（或者切片）：

```go
for i:=0; i < len(arr); i++ {
… = arr[i]
}
for ix, value := range arr {
…
}
```

（3）如何在一个二维数组或者切片`arr2Dim`中查找一个指定值`V`：

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

### 3. 映射

创建：    `map1 := make(map[keytype]valuetype)`

初始化：   `map1 := map[string]int{"one": 1, "two": 2}`

（1）如何使用`for`或者`for-range`遍历一个映射：

```go
for key, value := range map1 {
…
}
```

（2）如何在一个映射中检测键`key1`是否存在：

`val1, isPresent = map1[key1]`

返回值：键`key1`对应的值或者`0`, `true`或者`false`
    
（3）如何在映射中删除一个键：

`delete(map1, key1)`

### 4. 结构体

创建：
```go
type struct1 struct {
    field1 type1
    field2 type2
    …
}
ms := new(struct1)
```

初始化：
```go
ms := &struct1{10, 15.5, "Chris"}
```

当结构体的命名以大写字母开头时，该结构体在包外可见。
通常情况下，为每个结构体定义一个构建函数，并推荐使用构建函数初始化结构体。

```go    
ms := Newstruct1{10, 15.5, "Chris"}
func Newstruct1(n int, f float32, name string) *struct1 {
    return &struct1{n, f, name} 
}
```

### 5. 接口

（1）如何检测一个值`v`是否实现了接口`Stringer`：

```go
if v, ok := v.(Stringer); ok {
    fmt.Printf("implements String(): %s\n", v.String())
}
```

（2）如何使用接口实现一个类型分类函数：
    
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

### 6. 函数

如何使用内建函数`recover`终止`panic`过程：
    
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

### 7. 文件

（1）如何打开一个文件并读取：
 
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

（2）如何通过切片读写文件：
    
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

### 8. 协程（goroutine）与通道（channel）


出于性能考虑的建议：
    
实践经验表明，如果你使用并行运算获得高于串行运算的效率：在协程内部已经完成的大部分工作，其开销比创建协程和协程间通信还高。

1 出于性能考虑建议使用带缓存的通道：

使用带缓存的通道可以很轻易成倍提高它的吞吐量，某些场景其性能可以提高至10倍甚至更多。通过调整通道的容量，甚至可以尝试着更进一步的优化其性能。

2 限制一个通道的数据数量并将它们封装成一个数组：

如果使用通道传递大量单独的数据，那么通道将变成性能瓶颈。然而，将数据块打包封装成数组，在接收端解压数据时，性能可以提高至10倍。

创建：`ch := make(chan type,buf)`

（1）如何使用`for`或者`for-range`遍历一个通道：

```go
for v := range ch {
    // do something with v
}
```

（2）如何检测一个通道`ch`是否关闭：

```go
//read channel until it closes or error-condition
for {
    if input, open := <-ch; !open {
        break
    }
    fmt.Printf("%s", input)
}
```

或者使用（1）自动检测。

（3）如何通过一个通道让主程序等待直到协程完成：

（信号量模式）：

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

如果希望程序一直阻塞，在匿名函数中省略 `ch <- 1`即可。

（4）通道的工厂模板：以下函数是一个通道工厂，启动一个匿名函数作为协程以生产通道：

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
       
（5）通道迭代器模板：
  
（6）如何限制并发处理请求的数量

（7）如何在多核CPU上实现并行计算

（8）如何终止一个协程：`runtime.Goexit()`  

（9）简单的超时模板：

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

（10）如何使用输入通道和输出通道代替锁：

```go
func Worker(in, out chan *Task) {
    for {
        t := <-in
        process(t)
        out <- t
    }
}
```

（11）如何在同步调用运行时间过长时将之丢弃

（12）如何在通道中使用计时器和定时器

（13）典型的服务器后端模型


### 9. 网络和网页应用


制作、解析并使模板生效：

```go        
var strTempl = template.Must(template.New("TName").Parse(strTemplateHTML))
```

在网页应用中使用HTML过滤器过滤HTML特殊字符：
    
`{{html .}}` 或者通过一个字段 `FieldName {{ .FieldName |html }}`

使用缓存模板。 


如何在程序出错时终止程序：

```go	
if err != nil {
   fmt.Printf(“Program stopping with error %v”, err)
   os.Exit(1)
}
```

或者：

```go

if err != nil { 
panic(“ERROR occurred: “ + err.Error())
}

```

### 10. 出于性能考虑的最佳实践和建议

（1）尽可能的使用`:=`去初始化声明一个变量（在函数内部）；

（2）尽可能的使用字符代替字符串；

（3）尽可能的使用切片代替数组；

（4）尽可能的使用数组和切片代替映射；

（5）如果只想获取切片中某项值，不需要值的索引，尽可能的使用`for range`去遍历切片，这比必须查询切片中的每个元素要快一些；

（6）当数组元素是稀疏的（例如有很多`0`值或者空值`nil`），使用映射会降低内存消耗；

（7）初始化映射时指定其容量；

（8）当定义一个方法时，使用指针类型作为方法的接受者；

（9）在代码中使用常量或者标志提取常量的值；

（10）尽可能在需要分配大量内存时使用缓存；

（11）使用缓存模板。


     
 ------------

Reference：    
摘录于[《Go入门指南》](https://github.com/Unknwon/the-way-to-go_ZH_CN/blob/master/eBook/directory.md)   



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()