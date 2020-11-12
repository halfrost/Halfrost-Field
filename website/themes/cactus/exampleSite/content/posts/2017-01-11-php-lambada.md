---
title: php的闭包特性
date: 2017-01-11 18:39:17
category: notes
tags:
    - php
keywords:
    - php
    - 闭包
    - lambada
    - 匿名函数
---

闭包和匿名函数在`PHP 5.3.0`引入，并且PHP将两者视为相同的概念。闭包其实是伪装成函数的对象，它的实质其实是`Closure`实例。

创建闭包非常简单：

```php
$c = function($name) {
    return sprintf("Hello World! Hello %s!", $name);
};

echo $c('PHP');
```

使用`use`对闭包附加状态，多个参数使用`,`分隔：

```php
function callPerson($name) {
    return function($about) use ($name) {
        return sprintf("%s, %s", $name, $about);
    }
}

$triver = callPerson('Triver');
echo $triver("slow down, please!!");

```

附加的变量会被封装到闭包内，即使返回的闭包队形已经跳出了`callPerson()`的作用域也仍然会记住`$name`的值。

闭包有一个有趣的`bindTo()`方法，可以将闭包的内部状态绑定到其他对象上，第二个参数指定了绑定闭包的对象所属的类，从而实现在闭包中访问绑定对象的私有方法和属性。

```php
class Bind {
    protected $name = 'no name';
    public $change;

    public function addAction($action) {
        $this->change = $action->bindTo($this, __CLASS__);
    }
}

$bind = new Bind();
$bind->addAction(function() {
    $this->name = "php";
    return $this->name;
    });

$change = $bind->change;
echo $change();
```

使用这个特性可以方便的为类添加方法并绑定：

```php
trait MetaTrait
{
    //定义$methods数组,用于保存方法（函数）的名字和地址。
    private $methods = array();
    //定义addMethod方法，使用闭包类绑定匿名函数。
    public function addMethod($methodName, $methodCallable)
    {
        if (!is_callable($methodCallable)) {
            throw new InvalidArgumentException('Second param must be callable');
        }
        $this->methods[$methodName] = Closure::bind($methodCallable, $this, get_class());
    }
    //方法重载。为了避免当调用的方法不存在时产生错误，
    //可以使用 __call() 方法来避免。
    public function __call($methodName, array $args)
    {
        if (isset($this->methods[$methodName])) {
            return call_user_func_array($this->methods[$methodName], $args);
        }

        throw RunTimeException('There is no method with the given name to call');
    }
}

class HackThursday {
    use MetaTrait;

    private $dayOfWeek = 'Thursday';

}

$test = new HackThursday();
$test->addMethod('when', function () {
    return $this->dayOfWeek;
});

echo $test->when();
```

php7 中增加了 `Closure::call()` 方法，可以更高效的绑定对象作用域并调用。

```php
class A {private $x = 1;}

// Pre PHP 7 code
$getXCB = function() {return $this->x;};
$getX = $getXCB->bindTo(new A, 'A'); // intermediate closure
echo $getX();

// PHP 7+ code
$getX = function() {return $this->x;};
echo $getX->call(new A);
```
