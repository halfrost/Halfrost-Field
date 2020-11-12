---
title: composer中的autoload
date: 2016-11-05 02:42:06
category: tech
tags:
    - php
keywords:
    - composer
    - autoload
    - psr-4
---

composer的autoload可以轻松的实现php的自动加载。在`composer.json`中添加`autoload`字段即可。当前支持 `PSR-0` `PSR-4` `classmap`解析和`files`包含。官方推荐PSR-4标准（添加类时不需要重新生成加载器）。

### PSR-4

Under the `psr-4` key you define a mapping from namespaces to paths, relative to the package root. When autoloading a class like `Foo\\Bar\\Baz` a namespace prefix `Foo\\` pointing to a directory `src/` means that the autoloader will look for a file named `src/Bar/Baz.php` and include it if present. Note that as opposed to the older PSR-0 style, the prefix (`Foo\\`) is not present in the file path.

<!-- more -->

Namespace prefixes must end in `\\` to avoid conflicts between similar prefixes. For example Foo would match classes in the FooBar namespace so the trailing backslashes solve the problem: `Foo\\` and `FooBar\\` are distinct.

The PSR-4 references are all combined, during install/update, into a single key => value array which may be found in the generated file `vendor/composer/autoload_psr4.php`.

实例：
```
{
    "autoload": {
        "psr-4": {
            "Monolog\\": "src/",
            "Vendor\\Namespace\\": ""
        }
    }
}
```

如果需要在多个目录下搜索相同前缀，可以以数组的形式指定。
```
{
    "autoload": {
        "psr-4": { "Monolog\\": ["src/", "lib/"] }
    }
}
```

也可为所有命名空间指定默认文件夹：
```
{
    "autoload": {
        "psr-4": { "": "src/" }
    }
}
```

### classmap

`classmap` 引用的所有组合，都会在 `install/update` 过程中生成，并存储到 `vendor/composer/autoload_classmap.php` 文件中。这个 `map` 是经过扫描指定目录（同样支持直接精确到文件）中所有的 `.php` 和 `.inc` 文件里内置的类而得到的。

你可以用 `classmap` 生成支持支持自定义加载的不遵循 `PSR-0/4` 规范的类库。要配置它指向需要的目录，以便能够准确搜索到类文件。

实例：
```
{
    "autoload": {
        "classmap": ["src/", "lib/", "Something.php"]
    }
}
```

__相关链接__

[Example Implementations of PSR-4](http://www.php-fig.org/psr/psr-4/examples/)

[The composer.json Schema](https://getcomposer.org/doc/04-schema.md#autoload)

[如何使用composer的autoload来自动加载自己编写的函数库与类库](http://drops.leavesongs.com/php/composer-autoload-class-and-function-written-myself.html)

[使用composer中的autoload](http://gywbd.github.io/posts/2014/12/composer-autoload.html)
