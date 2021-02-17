# 揭秘 Go interface 那些事

接口是高级语言中的一个规约，是一组方法签名的集合。Go 的 interface 是非侵入式的，具体类型实现 interface 不需要在语法上显式的声明，只需要具体类型的方法集合是 interface 方法集合的超集，就表示该类实现了这一 interface。编译器在编译时会进行 interface 校验。interface 和具体类型不同，它不能实现具体逻辑，也不能定义字段。

在 Go 语言中，interface 和函数一样，都是“第一公民”。interface 可以用在任何使用变量的地方。可以作为结构体内的字段，可以作为函数的形参和返回值，可以作为其他 interface 定义的内嵌字段。interface 在大型项目中常常用来解耦。在层与层之间用 interface 进行抽象和解耦。由于 Go interface 非侵入的设计，使得抽象出来的代码特别简洁，这也符合 Go 语言设计之初的哲学。除了解耦以外，还有一个非常重要的应用，就是利用 interface 实现伪泛型。利用空的 interface 作为函数或者方法参数能够用在需要泛型的场景里。

interface 作为 Go 语言类型系统的灵魂，Go 语言实现多态和反射的基础。新手对其理解不深刻的话，常常会犯下面这个错误：

```go
func main() {
	var x interface{} = nil
	var y *int = nil
	interfaceIsNil(x)
	interfaceIsNil(y)
}

func interfaceIsNil(x interface{}) {
	if x == nil {
		fmt.Println("empty interface")
		return
	}
	fmt.Println("non-empty interface")
}
```

本文将会详细分解 interface 所有底层实现。


## 一. 数据结构

