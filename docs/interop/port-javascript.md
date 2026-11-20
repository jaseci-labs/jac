---
description: What jac port makes of each JavaScript and TypeScript construct - the Jac it becomes, and what it refuses.
keywords: port javascript, porting JavaScript and TypeScript, JavaScript and TypeScript to Jac
---
# Porting JavaScript and TypeScript

`jac port` translates a JavaScript or TypeScript source file into a Jac module that behaves
as the file does on a `node` space, or refuses it ([port](../toolchain/port.md)). This page is
the mapping: each construct port translates and the Jac it becomes. It is printed from the table
the translation itself reads (`jac port --mapping javascript`).

The pinned TypeScript reads the file, a JavaScript file too, and gives every expression its
type. Port keeps those types, and translates an operator only where they say what it does: `+`
of two numbers is an addition and of two strings a concatenation, and of anything else it is
refused, since JavaScript would convert one operand and Jac would not.

| JavaScript and TypeScript | Jac |
|---|---|
| `const x = 1;` at the top, of a literal, before any other code | `glob x: float = 1.0;` |
| Any other statement at the top | A statement of the module's one `with entry { }` |
| `function f(a: number, b = 2, c?: string): number { }` | `def f(a: float, b: float = 2.0, c: str \| None = None) -> float { }` |
| `class C { x: number; constructor(x) { this.x = x; } m() { } }` | `obj C { has x: float; def init(x: float) { self.x = x; } def m { } }` |
| `let x = v;`, `const x: T = v;` | `x: T = v;`, with the type TypeScript gives `x` |
| `if (c) { } else if (d) { } else { }`, `while (c) { }`, of a boolean | `if c { } elif d { } else { }`, `while c { }` |
| `for (let i = 0; i < n; i++) { }` | `for i = 0.0 while i < n with i += 1.0 { }` |
| `for (const x of xs) { }`, of an array | `for x in xs { }` |
| `return v;`, `break;`, `continue;` | The same |
| `3`, `2.5`, `0xff` | `3.0`, `2.5`, `255.0`: a number is a float |
| `"a"`, `'a'`, `` `a${s}b` `` of strings | `"a"`, `"a" + s + "b"` |
| `true`, `false`, `undefined`, `this` | `True`, `False`, `None`, `self` |
| `a + b`, `a - b`, `a * b`, `a ** b` of numbers; `s + t` of strings | The same operators |
| `{ a: 1, "b": 2 }` typed `Record<string, number>`, `d[k]`, `d[k] = v;` | `{"a": 1.0, "b": 2.0}`, `d[k]`, `d[k] = v;` |
| The types `number`, `string`, `boolean`, `T[]`, `Record<string, T>`, a class, `T \| undefined` | `float`, `str`, `bool`, `list[T]`, `dict[str, T]`, the class, `T \| None`; anything else is `any` |
| `a / b` of numbers | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * (float("-inf") if Object.is(b, -0.0) else float("inf"))`, since Jac raises where JavaScript gives an infinity |
| `a < b`, `<=`, `>`, `>=` of numbers; `===`, `!==` of two numbers, strings or booleans | `a < b`, `<=`, `>`, `>=`; `==`, `!=` |
| `===`, `!==` of two objects or arrays; `x === undefined` | `is`, `is not`; `x is None` |
| `!c`, `c && d`, `c \\|\\| d` of booleans; `c ? a : b`; `-a` | `not c`, `c and d`, `c or d`; `a if c else b`; `-a` |
| `x = v;`, `x += v;`, `x -= v;`, `x *= v;`, `x++;`, `x--;` as statements | `x = v;`, `x += v;`, `x -= v;`, `x *= v;`, `x += 1.0;`, `x -= 1.0;` |
| `f(a)`, `o.m(a)`, `new C(a)`, `o.x` | `f(a)`, `o.m(a)`, `C(a)`, `o.x` |
| `console.log(a, b)`, `Math.sqrt(x)`, `Math.PI` | The same, on JavaScript's own `console` (`import from "node:console" { default as console }`) and `Math` |
| `[a, b]`, `xs[0]`, `xs.length`, `xs.push(v);` | `[a, b]`, `xs[0]`, `float(len(xs))`, `xs.append(v);` |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file. So is a
construct in the table whose Jac would mean something else (E4005):

- **An operator on operands TypeScript does not know the types of**, or of two different types.
  Annotate them, in TypeScript or in JSDoc comments.
- **`%`.** JavaScript's remainder has the dividend's sign and Jac's the divisor's.
- **A condition that is not a boolean.** An empty array is true in JavaScript and false in Jac.
- **An index that is not a whole number literal**, a string's `length` and its characters. A
  JavaScript number is a float and a string is UTF-16.
- **A variable declared again inside the block of another of its name.** A Jac function has one
  variable of a name.
- **A top-level variable that functions use, bound by anything but a literal before the file's
  code.**
- **A property a method binds that the constructor does not.**

## What differs in what is written

- **A missing element or key raises.** `xs[9]` past the end and `d[k]` of a key that is not there
  raise `IndexError` and `KeyError`, where JavaScript gives `undefined`.

It is a gap to close before JavaScript's port is complete.
