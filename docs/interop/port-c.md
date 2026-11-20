---
description: What jac port makes of each C construct - the Jac it becomes, and what it refuses.
keywords: port c, porting C, C to Jac
---
# Porting C

`jac port` translates a C source file into a Jac module that behaves as the file does, or
refuses it ([port](../toolchain/port.md)). This page is the mapping: each C construct port
translates and the Jac it becomes. It is printed from the table the translation itself reads
(`jac port --mapping c`).

Clang reads the file once for each target jac builds C for, with its module's flags, and
port translates each reading. Where they agree the Jac is written once. A statement that
differs by target is written under `comptime if` on `target()`, and a declaration that differs
goes to the module's target variant files (`x.windows.jac`).

A source file is ported with the header of its name, if it has one: `geom.c` and `geom.h` are
the module `geom`.

| C | Jac |
|---|---|
| `int`, `unsigned`, `long long`, `char`, `short`, `double`, `float`, `_Bool` | `i32`, `u32`, `i64`, `i8` or `u8`, `i16`, `float`, `f32`, `bool`: an integer by its width on each target |
| `int f(int a, double b) { }`, `void g(void) { }` | `def f(a: i32, b: float) -> i32 { }`, `def g { }` |
| `int main(void) { }` | `def main -> i32 { }` and `with entry { sys.exit(int(main())); }` |
| `int total = 0;` at file scope, `int x = 1;` in a function, `int x;` | `glob total: i32 = 0;`, `x: i32 = 1;`, `x: i32 = 0;` |
| `struct point { double x; int n; };`, `struct point p = {1.5, 2};`, `p.x` | `struct point { has x: float = 0.0, n: i32 = 0; }`, `p: point = point(x=1.5, n=2);`, `p.x` |
| `enum { RED, GREEN = 5 };` | `comptime RED: i32 = 0;`, `comptime GREEN: i32 = 5;` |
| `typedef struct { } point;`, `typedef int count;` | The record by its typedef's name; any other typedef is the type it names |
| `if (c) { } else if (d) { } else { }`, `while (c) { }` | `if c { } elif d { } else { }`, `while c { }`; a condition that is a number is `c != 0` |
| `for (int i = 0; i < n; i++) { }` | `for i = i32(0) while i < n with i += 1 { }` |
| `do { } while (c);`, with no `continue` of its own | `while True { ... if not c { break; } }` |
| `return v;`, `break;`, `continue;` | The same |
| `a + b`, `a - b`, `a * b` of signed integers and of floats | `a + b`, `a - b`, `a * b`: C leaves a signed overflow undefined, and Jac raises OverflowError |
| `a + b`, `a - b`, `a * b`, `a << k` of unsigned integers | `a +% b`, `a -% b`, `a *% b`, `wrapping_shl(a, k)`: they wrap, as C defines |
| `a / b`, `a % b` of signed integers | `(a // b + 1) if (a % b != 0 and (a < 0) != (b < 0)) else (a // b)`, and the like for `%`: C rounds toward zero and Jac toward negative infinity |
| `a / b`, `a % b` of unsigned integers | `a // b`, `a % b` |
| `a / b` of floats | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * math.copysign(float("inf"), b)`, since Jac raises where C gives an infinity |
| `a < b`, `<=`, `>`, `>=`, `==`, `!=`, `a && b`, `a \\|\\| b`, `!a` | The same comparisons, `a and b`, `a or b`, `not a`; where C takes the result as a number, `i32(a < b)` |
| `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a`, `c ? a : b` | `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a` (`-%a` of an unsigned), `a if c else b` |
| `x = v;`, `x += v;` and the other compound assignments, `x++;`, `x--;` as statements | `x = v;`, `x += v;` (`x +%= v;` of an unsigned), `x += 1;`, `x -= 1;` |
| `5`, `5u`, `'a'`, `1.5`, `1.5f` | `5` where its type is given by what takes it, else `i32(5)`, `u32(5)`, `i32(97)`; `1.5`, `f32(1.5)` |
| A conversion, written `(long long)x` or made by C: to a type that holds every value | `i64(x)`, `float(x)` |
| A conversion to an integer type that does not hold every value; of a float to an integer | `u8.wrap(x)`: it keeps the low bits, as Clang defines; `i32(x)`: toward zero |
| `f(a, b)`; `printf("%d\n", n)` of the C library | `f(a, b)`; `printf("%d\n", n)`, with `import from c { def printf(format: str, *args: any) -> i32; }` |
| `sizeof(int)` | Its value on each target, `u64(4)` |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file: pointers
and arrays, strings other than a literal passed to a C library function, unions and bit-fields,
`switch` and `goto`, `static` locals, a function defined with `...`. So is a construct in the
table whose Jac would mean something else (E4005):

- **A division whose operands have side effects.** Port tests the operands, and would evaluate
  them twice.
- **A local declared inside the block of another of its name, or with the name of a file-scope
  variable.** A Jac function has one variable of a name, and assigning a global's name assigns
  the global.
- **An assignment, `++` or `--` used for its value.**

A function another file of the module still calls is refused with E4002, until a C module can
take a Jac module's functions.
