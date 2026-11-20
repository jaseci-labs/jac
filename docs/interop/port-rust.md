---
description: What jac port makes of each Rust construct - the Jac it becomes, and what it refuses.
keywords: port rust, porting Rust, Rust to Jac
---
# Porting Rust

`jac port` translates a Rust crate into a Jac module that behaves as the crate does, or
refuses it ([port](../toolchain/port.md)). This page is the mapping: each Rust construct port
translates and the Jac it becomes. It is printed from the table the translation itself reads
(`jac port --mapping rust`).

rustc reads the crate, as it does to compile it, once for each target jac builds Rust for,
and port translates the typed tree rustc checks: macros expanded, every expression with its
type. Where the readings agree the Jac is written once; where they differ it is written as
[C's](port-c.md) is.

A crate is ported from its root file, `src/lib.rs`.

| Rust | Jac |
|---|---|
| `i32`, `u8`, `i64`, `usize`, `f64`, `f32`, `bool` | `i32`, `u8`, `i64`, `u64` (by the target's width), `float`, `f32`, `bool` |
| `fn f(a: i32, b: f64) -> i32 { ... a }` | `def f(a: i32, b: float) -> i32 { ... return a; }`: a body's last expression is what it returns |
| `struct P { x: f64, n: i32 }`, `P { x: 1.5, n: 2 }`, `p.x` | `struct P { has x: float = 0.0, n: i32 = 0; }`, `P(x=1.5, n=2)`, `p.x` |
| `impl P { fn area(&self) -> f64 { } fn new(x: f64) -> P { } }`, `p.area()`, `P::new(1.0)` | `def area -> float;` and `static def new(x: float) -> P;` in the struct, each with its `impl P.area -> float { }`; `p.area()`, `P.new(1.0)` |
| `#[derive(Clone, Copy)]` | Nothing: a Jac struct is copied where it is assigned or passed |
| `const N: i32 = 5;`, `static LIMIT: i32 = 9;` | `comptime N: i32 = 5;`, `glob LIMIT: i32 = 9;` |
| `let x = 1;`, `let mut x: i64 = 1;`, `let x = x + 1;` in the same block | `x: i32 = 1;`, `x: i64 = 1;`, `x: i32 = x + 1;` |
| `if c { } else if d { } else { }`; `let x = if c { a } else { b };` | `if c { } elif d { } else { }`; `x: T = a if c else b;` |
| `while c { }`, `loop { }`, `break`, `continue` | `while c { }`, `while True { }`, `break;`, `continue;` |
| `for i in a..b { }`, `for _ in 0..n { }` | `for i = a while i < b with i += 1 { }` |
| `return v;`, `x = v;`, `x += v;` and the other compound assignments | The same |
| `a + b`, `a - b`, `a * b` of integers and of floats | `a + b`, `a - b`, `a * b`: an overflow is an error in Rust, and Jac raises OverflowError |
| `a / b`, `a % b` of signed integers | `(a // b + 1) if (a % b != 0 and (a < 0) != (b < 0)) else (a // b)`, and the like for `%`: Rust rounds toward zero and Jac toward negative infinity |
| `a / b` of floats | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * math.copysign(float("inf"), b)` |
| `a << k`, `a >> k`, `a & b`, `a \\| b`, `a ^ b`, `!a` of integers | `wrapping_shl(a, k)`, `a >> k`, `a & b`, `a \\| b`, `a ^ b`, `~a` |
| `a < b`, `<=`, `>`, `>=`, `==`, `!=`, `a && b`, `a \\|\\| b`, `!a`, `-a` | The same comparisons, `a and b`, `a or b`, `not a`, `-a` |
| `x as i64`, `x as f64` (a type that holds every value); `x as u8` | `i64(x)`, `float(x)`; `u8.wrap(x)`: it keeps the low bits |
| `f(a, b)` | `f(a, b)` |
| `5`, `5u8`, `1.5`, `true` | `5` where its type is given by what takes it, else `i32(5)`, `u8(5)`; `1.5`, `True` |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the crate:
references other than a method's `self`, enums and `match`, traits and their impls, generics,
closures, tuples, arrays and slices, strings, modules, `use`, macros that expand to any of
these (`println!` among them), and every function of another crate, the standard library's
too, until Jac imports Rust's own items. So is a construct in the table whose Jac would
mean something else (E4005):

- **A `let` of a name inside the block of another of that name, or of another type.** A Jac
  function has one variable of a name, of one type.
- **A float converted to an integer.** Rust stops at the type's ends and Jac raises.
- **A `for` whose end is not a literal, a constant or an immutable variable**, which Jac would
  read again at each pass.
- **A division whose operands are more than names.** Port tests the operands, and would
  evaluate them twice.
