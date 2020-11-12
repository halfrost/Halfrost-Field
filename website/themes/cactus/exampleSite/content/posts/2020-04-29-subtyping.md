---
title: Programming Language - Subtyping
date: 2020-04-29 09:00:00
tags:
    - programming language
category: tech
keywords:
    - subtyping
---

## Some Good Subtyping Rules

* Width subtyping: A supertype can have a subset of fields with the same types, i.e., a subtype can have extra fields.
* Permutation subtypings: A supertype can have the same set of fields with the same types in a different order.
* Transitivity: if t1 is subtype of t2, and t2 is subtype of t3, then t1 is subtype of t3.
* Reflexivity: Every type is a subtype of itself.

Given the three features of (1) setting a field, (2) letting depth
subtyping change the type of a field, and (3) having a sound type system actually prevent field-missing errors, we can have any two of the three, but not all of them.

## Function Subtyping

Function subtyping **contravariant** in argument(s) and **covariant** in results.
If t3 is subtype of t1, and t2 is a subtype of t4, then `t1 -> t2` is a subtype of `t3 -> t4`.
