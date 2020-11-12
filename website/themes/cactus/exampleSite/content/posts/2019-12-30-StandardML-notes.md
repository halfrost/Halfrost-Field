---
title: Standard ML notes
date: 2019-12-30 09:00:00
tags:
    - SML
categories:
- notes
keywords:
    - SML
---

## Basics

### Comments

```ML
(* SML comment *)
```

### Variable bindings and Expressions

```ML
val x = 34;
(* static environment: x : int *)
(* dynamic environment: x --> 34 *)
val y = x + 1;

(* Use tilde character instead of minus to reprsent negation *)
val z = ~1;

(* Integer Division *)
val w = y div x
```

Strings:

```ML
(* `\n`のようなエスケープシーケンスが利用できる *)
val x = "hello\n"; 
(* 文字列の連結には'^'を使う *)
val y = "hello " ^ "world";
```

An ML program is a sequence of bindings. Each binding gets **type-checked** and then **evaluated**. 
What type a binding has depends on a static environment. How a binding is evaluated depends on a dynamic environment.
Sometimes we use just `environment` to mean dynamic environment and use `context` as a synonym for static environment.

* Syntaxs : How to write it.
* Semantics: How it type-checks and evaluates
* Value: an expression that has no more computation to do

### Shadowing

**Bindings are immutable** in SML. Given `val x = 8 + 9;` we produce a dynamic environment where x maps to 17. 
In this environment x will always map to 17; there is no "assignment statement" in ML for changing what x maps to. 
You can have another binding later, say `val x = 19;`, but that just creates a differnt environment 
where the later binding for x **shadows** the earlier one.

### Function Bindings

```ML
fun pow (x:int, y:int) = (* correct only for y >= 0 *)
    if y = 0
    then 1
    else x * pow(x, y-1);

fun cube (x : int) = 
    pow(x, 3);

val ans = cube(4);
(* The parentheses are not necessary if there is only one argument
     val ans = cube 4; *)
```

* Syntax: `fun x0 (x1 : t1, ..., xn : tn) = e`
* Type-checking: 
    - `t1 * ... * tn -> t`
    - The type of a function is "argument types" -> "reslut types"
* Evaluation:
    - A function is a value
    - The environment we extends arguments with is that “was current” when the function was defined, not the one where it is being called.
    
### Pairs and other Tuples

```ML
fun swap (pr : int*bool) =
    (#2 pr, #1 pr);

fun sum_two_pairs (pr1 : int * int, pr2 : int * int) =
    (#1 pr1) + (#2 pr1 ) + (#1 pr2) + (#2 pr2);

fun div_mod (x : int, y: int) =
    (x div y, x mod y);

fun sort_pair(pr : int * int) =
    
    if (#1 pr) < (#2 pr) then
	pr
    else
	(#2 pr, #1 pr);
```

ML supportstuplesby allowing any number of parts. Pairs and tuples can be nested however you want. For example, a 3-tuple (i.e., a triple) of integers has type int*int*int. An example is (7,9,11) and you retrieve the parts with #1 e, #2 e, and #3 e where e is an expression that evaluates to a triple.

```ML
val a = (7, 9, 11) (* int * int * int *)
val x = (3, (4, (5,6))); (* int * (int * (int * int)) *)
val y = (#2 x, (#1 x, #2 (#2 x))); (* (int * (int * int)) * (int * (int * int)) *)
val ans = (#2 y, 4); (* (int * (int * int)) * int *)
```

### Lists

```ML
val x = [7,8,9];
5::x; (* 5 consed onto x *)
6::5::x;
[6]::[[1,2],[3,4];
```

To append a list t a list, use list-append operator `@`:
[Reference：# The Standard ML Basis Library]([http://sml-family.org/Basis/list.html](http://sml-family.org/Basis/list.html))
>Interface:
>  **val**  [@](http://sml-family.org/Basis/list.html#SIG:LIST.@:VAL)  **:**  _'a_ list *  _'a_ list **->**  _'a_ list

```
val x = [1,2] @ [3,4,5]; (* [1,2,3,4,5] *)
```
Accessing:
```ML
val x = [7,8,9];
null x; (* False *)
null []; (* True *)
hd x; (* 7 *)
tl x; (* [8, 9] *)
```

### List Functions

```ML
fun sum_list(xs : int list) =
    if null xs
    then 0
    else hd xs + sum_list(tl xs);

fun list_product(xs : int list) =
    if null xs
    then 1
    else hd xs * list_product(tl xs);

fun countdown(x : int) =
    if x = 0
    then []
    else x :: countdown(x - 1);

fun append (xs : int lisst, ys : int list) =
    if null xs
    then ys
    else (hd xs) :: append((tl xs), ys);

fun sum_pair_list(xs : (int * int) list) =
    if null xs
    then 0
    else #1 (hd xs) + #2 (hd xs) + sum_pair_list(tl xs);

fun firsts (xs : (int * int) list) =
    if null xs
    then []
    else (#1 (hd xs)) :: firsts(tl xs);

fun seconds (xs : (int * int) list) =
    if null xs
    then []
    else (#2 (hd xs)) :: seconds(tl xs);

fun sum_pair_list2 (xs : (int * int) list) =
    (sum_list(firsts xs)) + (sum_list(seconds xs));

```

Functions that make and us lists are almost always recursice becasue a list has an unknown length. To write a recursive function the thought process involves two steps:
* think about the _base case_	
* think about the _recursive case_

### Let Expressions

* Syntax: `let b1 b2 ... bn in e end`
    - Each `bi` is any binding an `e` is any expression
    
```ML
let val x = 1
in
    (let val x = 2 in x+1 end) + (let val y = x+2 in y+1 end)
end

fun countup_from1 (x:int) =
    let fun count (from:int) =
        if from=x
        then x::[]
        else from :: count(from+1)
    in
        count(1)
    end
```

### Options

An option value has either 0 or 1 thing: `None` is an option value carrying nothing whereas `SOME e` evaluates e to a value v and becomes the option carrying the one value v. The type of `NONE` is `'a option` and the type of `SOME e` is `t option` if e has type t.

We have:
* `isSome` which evaluates to false if its argument is NONE
* `valOf` to get the value carried by `SOME`(raising exception for `NONE`)

```ML
fun max1( xs : int list) =
    if null xs
    then NONE
    else
	let val tl_ans = max1(tl xs)
	in
	    if isSome tl_ans andalso valOf tl_ans > hd xs
	    then tl_ans
	    else SOME (hd xs)
	end;
```

## Some More Expressions

Boolean operations:
* `e1 andalso e2`
    - if result of e1 is false then false else result of e2
* `e1 orelse e2`
* `not e1`

**※Syntax `&&` and `||` don't exist in ML and `!` means something different.**

**※`andalso` and `orelse` are just keywords. `not` is a pre-defined function.**

Comparisons:
* `=` `<>` `>` `<` `>=` `<=`
    - `=` and `<>` can be used with any "equality type" but not with real

## Build New Types

To Create a compound type, there are really only three essential building blocks:

* **Each-of** : A compound type t describes values that contain each of values of type `t1` `t2` ... `tn`
* **One-of**: A compound type t describes values that contain a value of one of the types `t1` `t2` ... `tn`
* **Self-refenence**: A compound type t may refer to itself in its definition in order to describe recursive data structures like lists and trees.

### Records

Record types are "each-of" types where each component is a named field. The order of fields never matters.
```ML
val x = {bar = (1+2,true andalso true), foo = 3+4, baz = (false,9) }
#bar x (* (3, true) *)
```

Tupels are actually syntactic sugar for records. `#1 e`, `#2 e`, etc. mean: get the contents of the field named 1, 2, etc.
```ML
- val x = {1="a",2="b"};
val x = ("a","b") : string * string
- val y = {1="a", 3="b"};
val y = {1="a",3="b"} : {1:string, 3:string}
```


### Datatype bindings

```ML
datatype mytype = TwoInts of int*int
		                       | Str of string
                               | Pizza;
val a = Str "hi"; (* Str "hi" : mytype *)
val b = Str; (* fn : string -> mytype *)
val c = Pizza; (* Pizza : mytype *)
val d = TwoInts(1+2, 3+4); (* TwoInts (3,7) : mytype *)
val e = a; (* Str "hi" : mytype *)
```
The example above adds four things to the environment:
* A new type mytype that we can now use just like any other types
* Three constructors `TwoInts`, `Str`, `Pizza`

We can also create a type synonmy which is entirely interchangeable with the existing type.
```ML
type foo = int
(* we can write foo wherever we write int and vice-versa *)
```

## Case Expressions

To access to datatype values, we can use a case expression:
```ML
fun f (x : mytype) =
    case x of
	    Pizza => 3
      | Str s => 8
      | TwoInts(i1, i2) => i1 + i2;

f(Str("a")); (* val it = 8 : int *)
```
We separate the branches with the `|` character. Each branch has the form `p => e` where p is a pattern and e is an expression. Patterns are used to match against the result of evaluating the case's first expression. This is why evaluating a case-expression is called pattern-matching.

## Lists and Options are Datatypes too

`SOME` and `NONE` are actually constructors. So you can use them in a case like:
```ML
fun inc_or_zero intoption =
    case intoption of
	    NONE => 0
      | SOME i => i+1;
```

As for list, `[]` and `::` are also constructors. `::` is a little unusual because it is an infix operator so when in patterns:
```ML
fun sum_list xs =
    case xs of
	    [] => 0
      | x::xs' => x + sum_list xs';

fun append(xs, ys) =
    case xs of
	    [] => ys
      | x::xs' => x :: append(xs', ys);
```

## Pattern-matching

Val-bindings are actually using pattern-matching.
```ML
val (x, y, z) = (1,2,3);
(*
    val x = 1 : int
    val y = 2 : int
    val z = 3 : int
*)
```

When defining a function, we can also use pattern-matching
```ML
fun sum_triple (x, y, z) =
    x + y + z;
```
Actually, all functions in ML takes one tripple as an argument. There is no such thing as a mutli-argument function  or zero-argument function in ML.
The binding `fun () = e` is using the unit-pattern `()` to match against calls that pass the unit value `()`, which is the only value fo a pre-defined datatype `unit`.

The definition of patterns is recursive. We can use nested patterns instead of nested cae expressions.

We can use wildcard pattern `_` in patterns.
```ML
fun len xs =
    case xs of
	[] => 0
      | _::xs' => 1 + len xs';

```

### Function Patterns

In a function binding, we can use a syntactic sugar instead of using case expressions:

```ML
fun f p1 = e1
  | f p2 = e2
  ...
  | f pn = en
```

for example
```ML
fun append ([], ys) = ys
  | append (x::xs', ys) = x :: append(xs', ys);
```

## Exceptions

To create new kinds of exceptions we can use exception bindings.
```ML
exception MyUndesirableCondition;
exception MyOtherException of int * int;
```

Use `raise` to raise exceptions. Use `handle` to catch exceptions.
```ML
fun hd xs =
    case xs of
	[] => raise List.Empty
      | x::_ => x;

(* The type of maxlist will be int list * exn -> int *)
fun maxlist(xs, ex) =
    case xs of
	[] => raise ex
      | x::[] => x
      | x::xs' => Int.max(x, maxlist(xs', ex));

(* e1 handle ex => e2 *)
val y = maxlist([], MyUndesirableCondition)
	handle MyUndesirableCondition => 42;
```

## Tail Recursion

There is a situation in a recursive call called **tail call**:
>when f makes a recursive call to f, there is nothing more for the caller to do after the callee returns except return the callee's result.

Consider a sum function:
```ML
fun sum1 xs =
    case xs of
        [] => 0
      | i::xs' => i + sum1 xs'
```

When the function runs, it will keep a call-stack for each recursive call . But if we change a little bit using tail call :
```ML
fun sum2 xs =
    let fun f (xs,acc) =
        case xs of
            [] => acc
          | i::xs' => f(xs',i+acc)
    in
        f(xs,0)
    end
```

we use a local helper `f` and a accumulator `acc` so that the return value  of `f`  is just the return value of `sum2` . As a result, there is no need to keep every call in stack, just the current `f` is enough. And that's ML and most of other functional programming languages do.
Another example: when reversing a list:
```ML
fun rev1 lst =
    case lst of
        [] => []
      | x::xs => (rev1 xs) @ [x]

fun rev2 lst =
    let fun aux(lst,acc) =
	    case lst of
		[] => acc
	      | x::xs => aux(xs, x::acc)
    in
	aux(lst,[])
    end
```
`rev1` is `O(n^2)` but rev2 is almost as simple as `O(n)`.

To make sure which calls are tail calls, we can use a recursive defination of **tail position** like:
* In `fun f(x) = e`, `e` is in tail position.
* If an expression is not in tail position, then none of its subexpressions are
* If `if e1 then e2 else e3` is in tail position, then `e2` and `e3` are in tail position (but not `e1`). (Case-expressions are similar.)
* If `let b1 ... bn in e end` is in tail position, then e is in tail position (but no expressions in the bindings are).
* Function-call arguments are not in tail position.

## First-class Functions

The most common use of first class functions is passing them as arguments to other functions.

```ML
fun n_times (f, n, x) =
    if n=0
    then x
    else f (n_times(f, n-1,x))
```

The function `n_times` is called higher-order funciton.  Its type is:
```ML
fn : ('a -> 'a) * int * 'a -> 'a
```
`'a` means they can be any type. This is called _parametric polymorphism_ , or _generic types_ .

Instead, consider a function that is not polymorphic:
```ML
(* (int -> int) * int -> int *)
fun times_until_zero (f, x) =
    if x = 0
    then 0
    else 1 + times_until_zero(f, f x)
```

### Anonymous Functions

```ML
fun triple_n_times (n, x) =
    n_times((fn x => 3*x), n, x)
```

Maps:
```ML
(* ('a -> 'b) * 'a list -> 'b list *)
fun map (f, xs) =
    case xs of
	[] => []
      | x::xs' => (f x)::(map(f, xs'));
```

Filters:
```ML
(* ('a -> bool) * 'a list -> 'a list *)
fun filter (f, xs) =
    case xs of
	[] => []
      | x::xs' => if f x
		  then x::(filter (f, xs'))
		  else filter (f, xs');
```

### Lexical scope VS dynamic scope

### Combining Functions

```ML
 fun sqrt_of_abs i = (Math.sqrt o Real.fromInt o abs) i;
```

Use our own infix operator to define a left-to-right syntax.
```ML
infix |>
fun x |> f = f x;
fun sqrt_of_abs i = i |> abs |> Real.fromInt |> Math.sqrt;
```

### Currying

```ML
(* fun sorted(x, y z) = z >= y andalso y >= x *)
val sorted = fn x => fn y => fn z => z >= y andalso y >= x;

(* just syntactic sugar for code above *)
fun sorted_nicer x y z = z >= y andalso y >= x;
```
when calling curried the function:
```ML
(* ((sorted_nicer x) y) z *)
(* or just: *)
sorted_nicer x y z
```

```ML

```

## Type Inference
 
 Key steps in ML:
 * Determine types of bindings in order
 * For each val of fun binding:
	 * Analyze definition for all necessary facts
	 * Type erro if no way for all facts to hold
* Use type variables like `'a` for any unconstrained type
* Enforce the value restriction

One example:
```ML
(*
	compose : T1 * T2 -> T3
	f : T1
	g : T2
	x : T4
	body being a function has type T3=T4->T5
	from g being passed x, T2=T4->T6 for some T6
	from f being passed the result of g, T1=T6->T7
	from call to f being body of anonymous function, T7 = T5
	all together, (T6->T5) * (T4->T6) -> (T4->T5)
	so ('a->'b) * ('c->'a) -> ('c->'b) 
*)
fun compose (f, g) = fn x => f (g x)
```

### Value restriction

A variable-binding can have a polymorphic type only if the expression is a variable or value:
```ML
val r = ref NONE
val _ = r := SOME "hi"
val i - 1 + valOf (!r)
```
If there is is no value-restriction, the code above will type check, which shouldn't.
With value restriction, ML will give a warning when type-checking:
```
- val r = ref NONE;
stdIn:2.5-2.17 Warning: type vars not generalized because of
   value restriction are instantiated to dummy types (X1,X2,...)
val r = ref NONE : ?.X1 option ref
```

## Mutual Recursion

Mutual recursion allows `f` to call `g` and `g` to call `f`.
In ML, There is an `and` keyword to allow that:
```ML
fun p1 = e1
and p2 = e2
and p3 = p3
```

## Modules

```ML
structure MyMathLib =
struct
fun fact x = x
val half_pi = Math.pi / 2.0
fun doubler x = x * 2
end
```

### Signatures

A signature is a type for a module.
```ML
signature SIGNAME  =
sig types-for-bindings
end
```

Ascribing a signature to a module:
```ML
structure myModule :> SIGNAME =
struct bindings end;
```

Anything not in the signature cannot be used outside the module.

```ML
signature MATHLIB =
sig
    val fact : int -> int
    val half_pi : real
    (* make doubler unaccessable outside the MyMathLib *)
    (* val doubler : int -> int *)
end

structure MyMathLib :> MATHLIB =
struct
fun fact x = x
val half_pi = Math.pi / 2.0
fun doubler x = x * 2
end 
```

###  Signature matching

## Equivalence

* PL Equivalence
* Asymptotic equivalence
* System equivalence
