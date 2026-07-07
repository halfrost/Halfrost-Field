# Pitfall Diary of a JavaScript Beginner

![](https://img.halfrost.com/Blog/ArticleTitleImage/47_0_.png)


### Introduction

In May 1995, the legendary Eich wrote the first version of a scripting language in just 10 days. JavaScript’s first codename was Mocha, a name coined by Marc Andreesen. Due to trademark issues, and because many products were already using the Live prefix, Netscape’s marketing department renamed it LiveScript. At the end of November 1995, Navigator 2.0B3 was released, containing the prototype of the language. This version did not differ much from the previous one. In early December 1995, as the Java language was gaining momentum, Sun licensed the Java trademark to Netscape. The language was renamed again, becoming the final name—JavaScript. Later, in January 1997, after standardization, it became what is now ECMAScript.

Over the past year or two, JS has been used in more and more places on the client side. I recently spent some time with JS, and as a frontend beginner, I’m recording some of the “pitfalls” I’ve run into during my recent learning process.


### I. Primitive Values and Objects

In JavaScript, values are divided into only two categories:

1.Primitive values: BOOL, Number, String, null, undefined.
2.Objects: each object has a unique identity and is strictly equal ( = = = ) only to itself.

null and undefined have no properties, not even a toString( ) method.

false, 0, NaN, undefined, null, and ' ' are all false.

The typeof operator can distinguish primitive values from objects and detect the type of a primitive value.
The instanceof operator can detect whether an object is an instance of a specific constructor function or one of its subclasses.


![](https://img.halfrost.com/Blog/ArticleImage/47_1.png)

> Reference types: objects, arrays, functions   
> All remaining types are value types


null returns object. This is an unfixable bug; fixing it would break the existing code ecosystem. But that does not mean null is an object.

This is because, in the first-generation JavaScript engine, JavaScript values were represented as 32-bit words. The lowest 3 bits were used as a tag indicating whether the value was an object, integer, floating-point number, or boolean. The object tag was 000, and to represent null, the engine used the machine-language NULL pointer, whose bits are all 0. typeof checks exactly these tag bits, which is why it considers null to be an object.

Therefore, to determine whether a value is an object, you should use the following conditions:
```javascript

function isObject (value) {
  return ( value !== null 
    && (typeof value === 'object' 
    || typeof value === 'function'));
}

```
`null` is the topmost element of the prototype chain.
```javascript

Object.getPrototypeOf(Object.prototype)

< null

```
You can check for `undefined` and `null` using strict equality:
```javascript

if(x === null) {
  // Check whether it is null
}

if (x === undefined) {
  // Check whether it is undefined
}

if (x === void 0 ) {
  // Check whether it is undefined, void 0 === undefined
}

if (x != null ) {
 // Check that x is neither undefined nor null
 // This form is equivalent to if (x !== undefined && x !== null )
}

```
Among primitive values, there is one special case: although `NaN` is a primitive value, it is not equal to itself.
```javascript

NaN === NaN
<false

```
The primitive value constructors Boolean, Number, and String can convert primitive values into objects, and can also convert objects into primitive values.
```javascript

// Primitive values converted to objects
var object = new String('abc')


// Objects converted to primitive values
String(123)
<'123'

```
However, when converting an object to a primitive value, note one thing: if the conversion is performed with the `valueOf()` function, everything works correctly.
```javascript

new Boolean(true).valueOf()
<true

```
However, when using a constructor to convert a wrapper object into a primitive value, BOOL values cannot be converted correctly.
```javascript

Boolean(new Boolean(false))
<true

```
Constructors can only correctly extract numbers and strings from wrapper objects.


### II. Bugs Caused by Loose Equality

In JavaScript, there are two ways to determine whether two values are equal.

1. Strict equality ( === ) and strict inequality ( !== ) require the values being compared to be of the same type.
2. Loose equality ( == ) and loose inequality ( != ) first attempt to convert two values of different types, and then compare them using strict equality.

Loose equality can lead to some bugs:
```javascript

undefined == null // undefined and null are loosely equal
<true

2 == true  // Don't mistakenly think this is true
<false

1 == true 
<true

0 == false
<true 

' ' == false // An empty string equals false, but not all non-empty strings equal true
<true

'1' == true
<true

'2' == true
<false

'abc' == true // NaN === 1
<false

```
Regarding strict equality and loose equality, someone on GitHub summarized them in a diagram. It’s pretty good, so I’m sharing it here. The GitHub repo is [here](https://github.com/dorey/Javascript-Equality-Table/)

![](https://img.halfrost.com/Blog/ArticleImage/47_10.png)


Here is a more complete table, also in color. The original is [here](https://thomas-yang.me/projects/oh-my-dear-js/)


![](https://img.halfrost.com/Blog/ArticleImage/47_11_.png)


> Interview question: When should you use ===, and when should you use ==?  
> if ( obj.a == null ) {  
> //  The check above is equivalent to obj.a === null || obj.a === undefined  
> //  This shorthand form is recommended in jQuery  
>}  
>  
> Except for the case above where == is used, use === everywhere else.  


However, things are different when converting with Boolean( ):


![](https://img.halfrost.com/Blog/ArticleImage/47_2.png)


Why are objects always true here?
In ECMAScript 1, configurable conversion through objects was not supported (for example, a toBoolean() method). The reason is that the boolean operators || and && preserve the values of their operands. Therefore, when these operators are chained, the truthiness of the same value may be checked multiple times. Such checks are inexpensive for primitive types, but for objects, allowing configurable boolean conversion would be very costly. So starting with ECMAScript 1, objects are always true to avoid the cost of those conversions.


### III. Number 

All numbers in JavaScript have only one type and are treated as floating-point numbers. JavaScript performs internal optimizations to distinguish between floating-point numbers and integers. JavaScript numbers are double-precision (64-bit), based on the IEEE 754 standard.

Because all numbers are floating-point numbers, precision issues arise. Do you remember the robot comic that was circulating online some time ago?


![](https://img.halfrost.com/Blog/ArticleImage/47_3.png)


Precision issues can lead to some curious behavior.
```javascript

0.1 + 0.2 ;  // 0.300000000000004

( 0.1 + 0.2 ) + 0.3;    // 0.6000000000001
0.1 + ( 0.2 + 0.3 );    // 0.6

(0.8+0.7+0.6+0.5) / 4   // 0.65
(0.6+0.7+0.8+0.5) / 4   // 0.6499999999999999


```
Changing a position or adding a parenthesis can affect precision. To avoid this issue, it is still recommended to convert to integers.
```javascript

( 8 + 7 + 6 + 5) / 4 / 10 ;  // 0.65
( 6 + 8 + 5 + 7) / 4 / 10 ;  // 0.65

```
![](https://img.halfrost.com/Blog/ArticleImage/47_4.png)


Among numbers, there are four special values:

1. 2 error values: NaN and Infinity
2. 2 zeros: one +0 and one -0. 0 can have a positive or negative sign, because the sign and the numeric value are stored separately.
```javascript

typeof NaN
<"number"

```
(Aside: NaN is short for “not a number,” yet it is a number.)

NaN is the only value in JS that is not strictly equal to itself:
```javascript

NaN === NaN
<false

```
So you cannot use `Array.prototype.indexOf` to look up `NaN` (because the array `indexOf` method uses strict equality for comparison).
```javascript

[ NaN ].indexOf( NaN )
<-1

```
There are two correct approaches:

First:
```javascript

function realIsNaN( value ){
  return typeof value === 'number' && isNaN(value);
}

```
The reason the above needs a type check is that string conversion first converts the value to a number; if the conversion fails, the result is NaN. So it is equal to NaN.
```javascript

isNaN( 'halfrost' )
<true

```
The second method is to use the definition in the IEEE 754 standard: any comparison between NaN and any value, including itself, is unordered.
```javascript

function realIsNaN( value ){
  return value !== value ;
}

```
Another erroneous value, Infinity, represents infinity or is caused by division by 0.

To check for it, you can directly use loose equality == or strict equality ===.

However, the isFinite() function is not specifically for checking Infinity. It is used to determine whether a value is a valid number—that is, neither NaN nor Infinity, excluding both of these erroneous values.


ES6 introduced two functions specifically for checking Infinity and NaN: Number.isFinite() and Number.isNaN(). It is recommended to use these two functions for such checks going forward.


In JS, integers have a safe range between (-2^53, 2^53). Therefore, if a number exceeds the range of a 64-bit unsigned integer, it can only be stored as a string.

When using parseInt() to convert a value to a number, errors can occur, and the result may be unreliable:
```javascript

parseInt(1000000000000000000000000000.99999999999999999,10)
<1

```
parseInt( str , redix? ) first converts the first argument to a string:
```javascript

String(1000000000000000000000000000.99999999999999999)
<"1e+27"

```
`parseInt` does not consider `e` to be part of an integer, so it stops parsing after `e`, and the final output is `1`.

In JS, the `%` remainder operator is not the modulo operation we usually think of.
```javascript

-9%7
<-2

```
The remainder operator returns a result with the same sign as the first operand. Modulo arithmetic has the same sign as the second operand.

So a tricky issue is that the way we usually determine whether a number is odd or even can produce incorrect results:
```javascript

function isOdd( value ){
  return value % 2 === 1;
}

console.log(-3);  // false
console.log(-2);  // false

```
The correct approach is:
```javascript

function isOdd( value ){
  return Math.abs( value % 2 ) === 1;
}

console.log(-3);  // true
console.log(-2);  // false

```

### IV. String 

String comparison operators cannot compare diacritics and accent marks.
```javascript

'ä' < 'b'
<false

'á' < 'b'
<false

```

### V. Array

When creating an array, you cannot create an array with a single number.
```javascript

new Array(2)  // A single number here represents the length of the array
<[ , , ]

new Array(2,3,4)
<[2,3,4] 

```
Deleting an element leaves an empty slot, but does not change the length of the array.
```javascript

var array = [1,2,3,4]
array.length
<4
delete array[1]

array
<[1, ,3,4]
array.length
<4


```
So the deletion here isn't quite consistent with how we handled deletion before; the correct approach is to use `splice`.
```javascript

var array = [1,2,3,4,56,7,8,9]
array.splice(1,3)
array
<[1, 56, 7, 8, 9]
array.length
<5


```
Different iteration methods behave differently with holes in arrays


In ES5:


![](https://img.halfrost.com/Blog/ArticleImage/47_5.png)


In ES6: the specification states that holes are not skipped during traversal; all holes are converted to undefined

![](https://img.halfrost.com/Blog/ArticleImage/47_6.png)


### VI. Set, Map, WeakSet, WeakMap

![](https://img.halfrost.com/Blog/ArticleImage/47_7.png)


### VII. Loops


First, a pitfall of for-in:
```javascript

var scores = [ 11,22,33,44,55,66,77 ];
var total = 0;
for (var score in scores) {
  total += score;
}

var mean = total / scores.length;

mean;


```
Most people, upon seeing this problem, would probably start calculating right away: add everything up, then divide by 7. But that would be wrong for this problem. If the elements in the array were made more complex:
```javascript

var scores = [ 1242351,252352,32143,452354,51455,66125,74217 ];

```
In fact, the answer here has nothing to do with the values of the elements in the array. As long as the array has 7 elements, the final answer is always 17636.571428571428.

The reason is that `for-in` iterates over the array indices, so total = ‘00123456’, and then this string is divided by 7.


![](https://img.halfrost.com/Blog/ArticleImage/47_8.png)


There are 6 ways to traverse an object’s properties in ES6:

![](https://img.halfrost.com/Blog/ArticleImage/47_9.png)


### 8. Bugs Caused by Implicit Conversion / Type Coercion
```javascript

var formData = { width : '100'};

var w = formData.width;
var outer = w + 20;

console.log( outer === 120 ); // false;
console.log( outer === '10020'); // true

```

### 9. Operator Overloading

In JavaScript, operators cannot be overloaded or customized, including the equals sign.

### 10. Hoisting of Function Declarations and Variable Declarations

First, here is an example of function hoisting.
```javascript

function foo() {
  bar();
  function bar() {
    ……
  }
}


```
`var` variables are also hoisted. However, once a function is assigned to a variable, the effect of hoisting disappears.
```javascript

function foo() {
  bar(); // error！
  var bar = function () {
    ……
  }
}

```
The function above no longer benefits from hoisting.

**Function declarations are fully hoisted, whereas variable declarations are only partially hoisted. Only the variable declaration is hoisted; the assignment is not.**

JavaScript supports lexical scoping, meaning that, with very few exceptions, a reference to a variable `foo` is bound to the nearest scope in which `foo` is declared. ES5 does not support block scope: the scope of a variable definition is not the nearest enclosing statement or code block, but the function that contains it. All variable declarations are hoisted—the declarations are moved to the beginning of the function, while assignments still occur at their original locations.
```javascript

function foo() {
  var x = -10;
  if ( x < 0) {
    var tmp = -x;
    ……
 }
 console.log(tmp);  // 10
}


```
Here, tmp effectively has the effect of variable hoisting.

Another example:
```javascript

foo = 2;
var foo; 
console.log( foo );

```
The example above still outputs 2, not undefined.

After being compiled by the compiler, it actually becomes something like this:
```javascript

var foo; 
foo = 2;
console.log( foo );

```
**The variable declaration is hoisted, while the assignment remains in place.** To make this clearer, here’s another example:
```javascript

console.log( a ); 
var a = 2;

```
The code above will be compiled into the following:
```javascript

var foo;
console.log( foo ); 
foo = 2;

```
So the output is `undefined`.

If both variables and functions are hoisted, **function hoisting takes higher priority**.
```javascript

foo(); // 1
var foo;
function foo() { 
    console.log( 1 );
}
foo = function() { 
    console.log( 2 );
};

```
After compilation, the above becomes the following:
```javascript

function foo() { 
   console.log( 1 );
}
foo(); // 1
foo = function() { 
   console.log( 2 );
};


```
The final output is 1, not 2. This shows that function hoisting takes precedence over variable hoisting.


To avoid variable hoisting, ES6 introduced the let and const keywords. Variables declared with these two keywords are not subject to variable hoisting. The principle is that, within a code block, before a variable declared with the let command is reached, that variable is unavailable. This region is called the “temporal dead zone” (TDZ). With the TDZ approach, as soon as execution enters this region, the variable to be used already exists—the variable has still been “hoisted”—but it cannot be accessed. It can only be accessed and used once the line declaring the variable is reached.

This ES6 behavior also brought block scope to JS. (In ES5, there were only global scope and function scope.) As a result, immediately invoked function expressions (IIFEs) are no longer necessary.


### 11. arguments Is Not an Array

arguments is not an array; it is only array-like. It has a length property, and its elements can be accessed with square brackets. You cannot remove its elements, nor can you call array methods on it.

Do not use the arguments variable inside a function body; use the rest operator ( ... ) instead. The rest operator explicitly indicates which parameters you want to obtain, and arguments is merely array-like, whereas the rest operator provides a real array.


Here is an example of using arguments as an array:
```javascript

function callMethod(obj,method) {
  var shift = [].shift;
  shift.call(arguments);
  shift.call(arguments);
  return obj[method].apply(obj,arguments);
}

var obj = {
  add:function(x,y) { return x + y ;}
};

callMethod(obj,"add",18,38);


```
The code above immediately throws an error:
```javascript


Uncaught TypeError: Cannot read property 'apply' of undefined
    at callMethod (<anonymous>:5:21)
    at <anonymous>:12:1

```
The reason for the error is that arguments is not a copy of the function parameters; all named parameters are aliases for the corresponding indexes in the arguments object. Therefore, after elements are removed from the arguments object via the shift method, obj is still an alias for arguments[0], and method is still an alias for arguments[1]. It looks like obj[add] is being called, but in reality 17[25] is being called.


There is another issue when using an arguments reference.
```javascript

function values() {
  var i = 0 , n = arguments.length;
  return {
      hasNext: function() {
        return i < n;
      },
      next: function() {
        if (i >= n) {
            throw new Error("end of iteration");
        }
        return arguments[i++];
      }
  }
}

var it = values(1,24,53,253,26,326,);
it.next();   // undefined
it.next();   // undefined
it.next();   // undefined

```
The code above attempts to construct an iterator to traverse the elements of the `arguments` object. The reason it outputs `undefined` is that a new `arguments` variable is implicitly bound inside every function body. Each iterator `next` method has its own `arguments` variable, so when `it.next` is called, the arguments are no longer those of the `values` function.

The fix is also simple: declare a local variable, so that `next` can reference that variable when it runs.
```javascript

function values() {
  var i = 0 , n = arguments.length,a = arguments;
  return {
      hasNext: function() {
        return i < n;
      },
      next: function() {
        if (i >= n) {
            throw new Error("end of iteration");
        }
        return a[i++];
      }
  }
}

var it = values(1,24,53,253,26,326,);
it.next();   // 1
it.next();   // 24
it.next();   // 53


```

### 12. IIFEs Introduce a New Scope

In ES5, IIFEs were used to work around JavaScript’s lack of block scope, but in ES6, they are no longer necessary.

### 13. The Issue with `this` in Functions

Nested functions cannot access the `this` variable of the enclosing method.
```javascript

var halfrost = {
    name:'halfrost',
    friends: [ 'haha' , 'hehe' ],
    sayHiToFriends: function() {
      'use strict';
      this.friends.forEach(function (friend) {
          // 'this' is undefined here
          console.log(this.name + 'say hi to' + friend);
      });
    }
}

halfrost.sayHiToFriends()

```
At this point, a `TypeError: Cannot read property 'name' of undefined` will occur.

There are two ways to solve this problem:

First: save `this` in a variable.
```javascript

sayHiToFriends: function() {
  'use strict';
  var that = this;
  this.friends.forEach(function (friend) {
      console.log(that.name + 'say hi to' + friend);
  });
}

```
Second: Use the bind() Function

Use bind() to bind a fixed value to the callback function’s `this`, i.e., the function’s `this`.
```javascript

sayHiToFriends: function() {
  'use strict';
  this.friends.forEach(function (friend) {
      console.log(this.name + 'say hi to' + friend);
  }.bind(this));
}

```
Third approach: use the second argument of forEach to set this to a specific value.
```javascript

sayHiToFriends: function() {
  'use strict';
  this.friends.forEach(function (friend) {
      console.log(this.name + 'say hi to' + friend);
  }, this);
}

```
In ES6, it is recommended to use arrow functions wherever they are appropriate.

For simple, single-line functions that will not be reused, arrow functions are recommended. If the function body is complex and spans many lines, you should still use the traditional syntax.

The this object inside an arrow function is the object from the time it is defined, not the object from the time it is invoked. In other words, there is a “binding” relationship.

This “binding” mechanism is not introduced by arrow functions themselves. Rather, arrow functions do not have their own this at all, so the this inside them is the this of the outer code block. Because of this characteristic, arrow functions cannot be used in the following cases:
1. They cannot be used as constructors, and the new command cannot be used with them. Because they have no this, doing so will throw an error.
2. The argument object cannot be used; it does not exist inside the function body. If you need it, you can only use rest parameters instead. super and new.target also cannot be used.
3. The yield command cannot be used, so arrow functions cannot be used as Generator functions.
4. Methods such as call(), apply(), and bind() cannot be used to change the binding of this.


### 14. Asynchrony

There are several approaches to asynchronous programming:

1. Callback functions
2. Event listeners
3. Publish / Subscribe
4. Promise objects
5. Async / Await


(This journal may remain unfinished forever...)