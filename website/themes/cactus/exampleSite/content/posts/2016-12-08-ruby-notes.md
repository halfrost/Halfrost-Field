---
title: ruby学习笔记
date: 2016-12-08 22:54:49
category: notes
tags:
    - ruby
keywords:
   - ruby
---

## regular expressions

`=~`是用于正则表达式的匹配操作符。返回匹配到的字符串位置或nil。

```ruby
"abcdef" =~ /d/ # return 3
"aaaaaa" =~ /d/ # return nil
```

<!-- more -->

## !和?

The exclamation point (!, sometimes pronounced aloud as "bang!") indicates something potentially destructive, that is to say, something that can change the value of what it touches.
```
ruby> s1 = "forth"
  "forth"
ruby> s1.chop!       # This changes s1.
  "fort"
ruby> s2 = s1.chop   # This puts a changed copy in s2,
  "for"
ruby> s1             # ... without disturbing s1.
  "fort"
```

You'll also sometimes see chomp and chomp! used. These are more selective: the end of a string gets bit off only if it happens to be a newline.

The other method naming convention is the question mark (?, sometimes pronounced aloud as "huh?") indicates a "predicate" method, one that can return either true or false.

## 四种内部中断循环的方式

* `break`
* `next` 等同与continue
* `redo` restarts the current iteration
* `return`

## 迭代器 iterator

Ruby's String type has some useful iterators. `each_byte` is an iterator for each character in the string.

```shell
irb(main):001:0> "abc".each_byte{|c| printf "<%c>", c}; print "\n"
<a><b><c>
=> nil
```

Another iterator of String is `each_line`.

```shell
irb(main):002:0> "a\nb\nc\n".each_line{|l| print l}
a
b
c
=> "a\nb\nc\n"
```

ruby的 `for in` 也是一种迭代。We can use a control structure `retry` in conjunction with an iterated loop, and it will retry the loop from the beginning.

### yield

`yield` occurs sometimes in a definition of an iterator. `yield` moves control to the block of code that is passed to the iterator (this will be explored in more detail in the chapter about procedure objects). The following example defines an iterator repeat, which repeats a block of code the number of times specified in an argument.

```ruby
irb(main):003:0> def repeat(num)
irb(main):004:1>     while num > 0
irb(main):005:2>         yield
irb(main):006:2>         num -= 1
irb(main):007:2>     end
irb(main):008:1> end
=> :repeat
irb(main):009:0> repeat(3) { puts "foo" }
foo
foo
foo
=> nil
```

## class

### 继承

继承的格式为:
```ruby
class Superclass
    def breathe
        puts "inhale and exhale"
    end
    def identify
        puts "I'm super"
    end
    def speak(word)
        puts word
    end
end

class Subclass<Superclass
    # code...
end
```

可在在子类中重新声明基类方法，也可以使用`super`关键字来扩展基类方法。`super`也允许我们传递参数给基类方法。
```ruby
class Subclass<Superclass
    def identify
        super
        puts "I'm sub too"
    end
    def speak(word)
        super("this is from Superclass")
        puts "now it's from Subclass: #{word}"
    end
end
```

### 初始化（构造函数）

`ruby`使用`initialize`关键字来实现构造函数的功能。

```ruby
class Fruit
    def initialize( k="apple")
        @kind = k
        @condition = "ripe"
    end
end

apple = Fruit.new "apple"
```

## variables

* `[a-z] or _` 本地变量
* `$` 全局变量
* `@` 实例变量 instance variable
* `[A-Z]` 常量

### 全局变量

全局变量以 `$` 开头。初始化之前，全局变量的值为`nil`。可定义一段procedure来追踪全局变量。
```ruby
$x #return nil
trace_var :$x, proc{puts "$x is now #{$x}"}
$x = 5 #return $x is now 5
```

一些特殊的变量（不一定是全局作用域）：

* `$!`	latest error message
* `$@`	location of error
* `$_`	上一次由gets读入的字符串
* `$.`	line number last read by interpreter
* `$&`	string last matched by regexp
* `$~`	the last regexp match, as an array of subexpressions
* `$n`	the nth subexpression in the last match (same as $~[n])
* `$=`	case-insensitivity flag
* `$/`	input record separator
* `$\`	output record separator
* `$0`	the name of the ruby script file
* `$*`	命令行参数
* `$$`	当前解释器的进程id
* `$?`	上一次子进程的退出状态码

### 实例变量

An instance variable has a name beginning with `@`, and its scope is confined to whatever object __self__ refers to. Two different objects, even if they belong to the same class, are allowed to have different values for their instance variables. From outside the object, instance variables __cannot be altered or even observed__ (i.e., ruby's instance variables are never public) except by whatever methods are explicitly provided by the programmer. As with globals, instance variables have the nil value until they are initialized.

Instance variables do not need to be declared. This indicates a flexible object structure; in fact, each instance variable is dynamically appended to an object when it is first assigned.

### 常量

常量名以大写字母开头。给常量重新赋值会得到警告。
```shell
irb(main):009:0> Wzr=1222
=> 1222
irb(main):010:0> Wzr=1223
(irb):10: warning: already initialized constant Wzr
(irb):9: warning: previous definition of Wzr was here
=> 1223
```

常量可以在类和模块中定义，并允许外部访问。
```ruby
class ConstClass
   C1=120
end

ConstClass::C1 # return 120
```

## 访问器(accessor)


实例属性需要通过属性访问器访问。常规访问器有简化写法：
```ruby
class Fruit
   def kind=(k)
       @kind = k
   end
   def kind
       @kind
   end
 end
 ```

### inspect方法

当创建一个对象时解释器会返回一些信息：
```ruby
irb(main):009:0> apple = Fruit.new
=> #<Fruit:0x00000000a34f58>
irb(main):010:0>
```

可以通过`inspect`关键字来改变这种默认行为。
```ruby
class Fruit
    def inspect
        "a fruit is created"
    end
end
```

`inspect`方法常用来调试，可通过下面两种方式显示调用：
```ruby
p anObject
puts anObject.inspect
```

### shortcuts

`Ruby`提供了访问器的一些简写形式：

|缩写|效果|
| :------: | :------: |
|attr_reader :v|	def v; @v; end|
|attr_writer :v|	def v=(value); @v=value; end|
|attr_accessor :v|	attr_reader :v; attr_writer :v|
|attr_accessor :v, :w|	attr_accessor :v; attr_accessor :w|

## 注释

单行注释以`#`开头。
块注释可使用`=begin` `=end`来标记。
```ruby
=begin
这是一段注释块。This is a comment block.
Egg, I dreamed I was old.
=end
```

## Dynamic Dispatch

## Mixins

Ruby has no multiple inheritance. But it has mixins.

### Lookup rulres

When looking for receiver obj's method m, 
* look in obj's class
* look in mixins the class includes(later includes shadow)
* look in obj's superclass
* look in mixins the superclass inculdes
* ...
