---
description: What jac port makes of each Python construct - the Jac it becomes, and what it refuses.
keywords: port python, porting Python, Python to Jac
---
# Porting Python

`jac port` translates a Python source file into a Jac module that behaves as the file does,
or refuses it ([port](../toolchain/port.md)). This page is the mapping: each Python construct
port translates and the Jac it becomes. It is printed from the table the translation itself
reads (`jac port --mapping python`).

Every name is `any`, which is what a name in Python is: its operations are resolved as the
program runs, and raise `TypeError` where Python does. Annotations are not carried over yet.

| Python | Jac |
|---|---|
| A module's docstring | The module's docstring |
| `import m`, `import m as n` | `import m;`, `import m as n;` |
| `from m import a, b as c` | `import from m { a, b as c }` |
| `x = v` at module level, of a literal, before any module code | `glob x: any = v;` |
| Any other statement at module level | A statement of the module's one `with entry { }` |
| `if __name__ == "__main__":` at module level | `with entry:__main__ { }` |
| `def f(a, b=1):` with a docstring | The docstring, then `def f(a: any, b: any = 1) -> any { }` |
| `class C(B):` with `__init__` binding `self.x` | `obj C(B) { has x: any; def init(...) { } }`, with an `__eq__` and a `__hash__` of identity when the class defines no `__eq__` |
| `x = v`, `x: T = v` (a first binding) | `x: any = v;` |
| `x += v`, and the other augmented assignments | `x += v;` |
| `a, b = v`, `(a, b)`, `return a, b` | `(a, b) = v;`, `(a, b)`, `return (a, b);` |
| `if`/`elif`/`else`, `while`, a loop's `else` | The same, with braces |
| `for x in xs:`, `for k, v in d.items():` | `for x in xs { }`, `for (k, v) in d.items() { }` |
| `return`, `break`, `continue`, `assert c, m` | The same, each with its `;` |
| `pass` | Nothing: an empty block is `{}` |
| `raise E(...)`, `raise E`, `raise E(...) from c`, `raise` | `raise E(...);`, `raise E();` for a class, `raise E(...) from c;`, `raise;` |
| `global x` | Nothing: assigning a global's name assigns it |
| An int, a float, a str, `True`, `False`, `None` | The same literal |
| A name that is a Jac keyword, such as `by` | The name behind a backtick, `` `by `` |
| `+ - * / // % ** @ << >> & \| ^`, `- + ~ not`, `and`, `or` | The same operators |
| `== != < <= > >= in`, `not in`, `is`, `is not`, chained | The same comparisons |
| `f(a, k=v)`, `o.m(a)`, `C(a)` | The same call |
| `o.a`, `xs[i]`, `xs[a:b:c]` | The same |
| `[a, b]`, `{k: v}`, `{a, b}` | The same displays |
| `a if c else b` | `a if c else b` |
| `f"{x!r:>4} and {y}"` | The same f-string |
| `[e for x in xs if c]`, and the set, dict and generator forms | The same comprehension, a tuple of targets in parentheses |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file. So is a
construct in the table whose Jac would mean something else (E4005):

- **A default value that is not a constant.** Python makes a default once, when the function is
  defined; Jac makes it at each call that leaves it out.
- **A module-level name that functions use, bound by anything but a literal before the module's
  code.** A Jac global has its value from the start.
- **A local with the name of a module-level global, function, class or import.** Assigning it in
  Jac would assign the module's.
- **An attribute a method binds that `__init__` does not always bind.** A Jac object has exactly
  its declared fields.
- **A name mangled in its class (`self.__x`), a method named `init` or `postinit`, `x is 1`, an
  int literal past 64 bits.**

## What differs in what is written

- **An int is 64 bits.** Arithmetic past that raises `OverflowError` where Python grows the int.
- **An object with no `__repr__` prints as Jac prints it** (`Counter(count=3)`), where Python
  prints its class and address.
- **A module-level name is bound from the start.** Reading one before the statement that binds
  it gives its literal, where Python raises `NameError`.

Each is a gap to close before Python's port is complete.
