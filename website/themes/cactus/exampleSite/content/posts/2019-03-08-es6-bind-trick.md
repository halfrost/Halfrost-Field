---
title: Bind specific arguments of a function
date: 2019-03-08 09:00:00
tags:
    - JavaScript
category: tech
keywords:
    - Javascript
    - ES2015
    - ES6
---

To bind specific (nth) arguments of a function, we can write a decorator instead of using `Function.bind()`:

```js
function func(p1, p2, p3) {
    console.log(p1, p2, p3);
}
// the binding starts after however many are passed in.
function decorator(...bound_args) {
    return function(...args) {
        return func(...args, ...bound_args);
    };
}

// bind the last parameter
let f = decorator("3");
f("a", "b");  // a b 3

// bind the last two parameter
let f2 = decorator("2", "3")
f2("a");  // a 2 3
```

Even if we want to bind just the nth argument, we can do as follows:

```js
// bind a specific (nth) argument
function decoratorN(n, bound_arg) {
    return function(...args) {
        args[n-1] = bound_arg;
        return func(...args);
    }
}

let fN = decoratorN(2, "2");
fN("a","b","c"); // a 2 c
```

[https://stackoverflow.com/questions/27699493/javascript-partially-applied-function-how-to-bind-only-the-2nd-parameter](https://stackoverflow.com/questions/27699493/javascript-partially-applied-function-how-to-bind-only-the-2nd-parameter)
