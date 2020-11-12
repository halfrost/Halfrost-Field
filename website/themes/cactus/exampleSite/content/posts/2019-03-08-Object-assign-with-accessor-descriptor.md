---
title: Object.assign() with accessor descriptor
date: 2019-03-08 09:00:00
tags:
    - JavaScript
category: tech
keywords:
    - Javascript
    - ES2015
    - ES6
---
[MDN docs:](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign#Copying_accessors)
>The Object.assign() method only copies enumerable and own properties from a source object to a target object. It uses [[Get]] on the source and [[Set]] on the target, so it will invoke getters and setters. Therefore it assigns properties versus just copying or defining new properties. This may make it unsuitable for merging new properties into a prototype if the merge sources contain getters.

For example

```js
class Cat {
    constructor(name) {
        this._name = name;
    }

    get name() {
        return this._name;
    }
    set name(value) {
        this._name = value;
    }
}

let nyannko = new Cat("nyannko");
let copy = Object.assign({}, nyannko)

console.log(nyannko.name) // nyannko
console.log(copy.name) // undefined
```

The `name` property is lost. 

<!--more-->

To copy accessors, we can use `Object.getOwnPropertyDescriptor()` and `Object.defineProperty()` as the MDN docs recommend:

```js
var obj = {
  foo: 1,
  get bar() {
    return 2;
  }
};

var copy = Object.assign({}, obj); 
console.log(copy); 
// { foo: 1, bar: 2 }, the value of copy.bar is obj.bar's getter's return value.

// This is an assign function that copies full descriptors
function completeAssign(target, ...sources) {
  sources.forEach(source => {
    let descriptors = Object.keys(source).reduce((descriptors, key) => {
      descriptors[key] = Object.getOwnPropertyDescriptor(source, key);
      return descriptors;
    }, {});
    // by default, Object.assign copies enumerable Symbols too
    Object.getOwnPropertySymbols(source).forEach(sym => {
      let descriptor = Object.getOwnPropertyDescriptor(source, sym);
      if (descriptor.enumerable) {
        descriptors[sym] = descriptor;
      }
    });
    Object.defineProperties(target, descriptors);
  });
  return target;
}

var copy = completeAssign({}, obj);
console.log(copy);
// { foo:1, get bar() { return 2 } }
```

The other way is `Object.prototype.__proto__` (but **not recommended**): 

```js
let completeCopy = Object.assign({__proto__: nyannko.__proto__}, nyannko);
console.log(completeCopy.name); // nyannko
```

`Object.prototype.__proto__` is deprecated so be aware that this may cease to work at any time. 
[https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/proto](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/proto)
