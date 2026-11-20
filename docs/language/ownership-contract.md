---
description: The nogc ownership contract: what a module held to it must state and must not do, how unmarked locals infer their state, which modules jac.toml's enforce and exempt patterns hold to it, and what a nogc build leaves out.
keywords: nogc contract, ownership contract, enforce, exempt, memory.enforce, memory.exempt, inferred ownership
---
# The nogc contract

A module held to the ownership contract proves, when it compiles, where
every heap value it makes is freed, so it needs no reference counts and no
cycle collector. `jac check` reports every place the contract is broken.
Two things hold a module to it:

- **The `nogc` memory profile** (`--memory nogc`, or `profile = "nogc"` in
  `jac.toml`) holds every module of the program to it, and builds the
  program with no reference counting.
- **A `jac.toml` `enforce` pattern** that matches the module's dotted name,
  under the `managed` or `rc` profile, holds that module to it while the
  rest of the program stays counted. An `exempt` pattern takes a matching
  module back out.

```toml
[memory]
enforce = ["strict_*"]       # modules held to the contract
exempt = ["strict_legacy"]   # taken back out
```

Under `nogc`, `enforce` and `exempt` are an error: the profile holds every
module already. See [Memory](memory.md) for the profiles, and
[Ownership](ownership.md) for the states the contract asks for.

Every diagnostic of the contract says what enforced it:
`(enforced by the nogc profile)` or
`(enforced by jac.toml [memory] "strict_*")`.

## A module that keeps the contract

<!-- example: not checked: needs a project whose jac.toml selects the nogc profile -->
```jac
obj Res {
    has tag: int = 0;

    def __del__ {
        print("drop", self.tag);
    }
}

def total(xs: &list[int]) -> int {
    s = 0;
    for v in xs {
        s += v;
    }
    return s;
}

def push(xs: &mut list[str], s: imm str) {
    xs.append(s + "!");
}

def early(flag: int) -> int {
    a: own Res = Res(tag=10);
    if flag > 0 {
        return 1;
    }
    b: own Res = Res(tag=20);
    return 2;
}

def run {
    nums = [1, 2, 3];
    names: own list[str] = [];
    push(&mut names, "a");
    push(&mut names, "b");
    print(total(&nums), names);
    print(early(1));
    print(early(0));
}

with entry {
    run();
}
```

Built in a project whose `jac.toml` has `[memory] profile = "nogc"`, it
prints:

```text
6 ['a!', 'b!']
drop 10
1
drop 10
drop 20
2
```

Each owner is dropped at its last use, on every path out of the function,
and its `__del__` runs exactly once.

## What the contract asks

| Rule | Code |
|---|---|
| Every heap-typed parameter states its ownership: `&T`, `&mut T`, `own T` or `imm T`. A scalar parameter and a node parameter need none. | E1401 |
| A parameter's type says whether it is on the heap: no `any`, no union (`int \| None`). | E1404 |
| A closure does not capture a heap value from outside it. | E1405 |
| Under `nogc`, a module global holds no heap storage (a scalar global is fine). Under `enforce` with a counted profile, a heap global is allowed and is managed storage. | E1406 |
| A container owns its elements: what enters it (a display, `append` and the other growing methods, an item store) is fresh or moved in, not a borrow and not an `imm` value. A set holds str or scalar members only. | E1406 |
| A builtin that would keep a raw reference to a heap argument (`iter(xs)`) is not called. Builtins and methods that only read (`len`, `str.count`, `str.upper`) are. | E1406 |
| An owned value is not stored into managed storage: a global container, a global's field. | E1402 |
| A heap value is not passed to a function of a module not held to the contract, unless `managed(x)` takes it across. | E1403 |
| The entry block handles every exception it can raise: a call whose callee raises (directly or through what it calls) sits in a `try` that catches that class, a base of it, `Exception` or `BaseException`. | E1407 |

A `try` and `except` whose `raise` is in the same function are allowed.
The contract is checked in what a `comptime for` unrolls too, each mistake
reported once.

## How an unmarked local gets its state

A local with no state written takes the state its bindings infer:

| Bound to | State |
|---|---|
| A fresh value: a display, a construction, a call's result | owned; binding it to another local moves it (E1301 to read the first after) |
| A read through a borrow (`p.items` of a `p: &Box`) | borrowed |
| A string literal | `imm` |
| A lambda, a module global, or values whose states disagree (owned, then borrowed) | none: E1401 |

A borrowing parameter takes an explicit borrow (`total(&nums)`) or a bare
local name (`total(nums)`).

## What is rejected

<!-- example: not checked: needs a project whose jac.toml selects the nogc profile -->
```jac
glob cache: list[int] = [];

def takes_list(xs: list[int]) -> int {
    return len(xs);
}

def takes_any(v: any) -> int {
    return 0;
}

def captures(data: &list[int]) -> int {
    return (lambda (x: int) -> int { return x + len(data); })(1);
}

def stores(xs: &list[int]) -> int {
    out: own list[list[int]] = [];
    out.append(xs);
    return len(out);
}

def moved -> int {
    a = [1, 2, 3];
    b = a;
    return len(a) + len(b);
}

def risky(n: int) -> int {
    if n < 0 {
        raise ValueError("negative");
    }
    return n;
}

with entry {
    print(risky(1));
}
```

Under `nogc`, `jac check` reports:

```text
error[E1406]: module global 'cache' would hold heap storage for the program's lifetime, which the owned world cannot free (enforced by the nogc profile)
error[E1401]: Heap-typed parameter 'xs' has no ownership state in a nogc-enforced module (enforced by the nogc profile)
error[E1404]: 'v' is `any`-typed and could be heap-allocated in a nogc-enforced module (enforced by the nogc profile)
error[E1405]: Closure capture of 'data' escapes its scope in a nogc-enforced module (enforced by the nogc profile)
error[E1406]: 'xs', a borrowed value, cannot enter 'out', which owns its elements (enforced by the nogc profile)
error[E1301]: Use of 'a' after it was moved
error[E1407]: 'risky' raises ValueError, and the entry block does not handle it
```

A module `strict_core` that an `enforce = ["strict_*"]` pattern holds, under
the default `managed` profile:

<!-- example: not checked: needs a project of two modules and a jac.toml with an enforce pattern -->
```jac
import from loose { consume }

glob cache: list[list[int]] = [];

def crosses -> int {
    data = [1, 2];
    return consume(data);
}

def explicit -> int {
    e = [4];
    return consume(managed(e));
}

def seals -> int {
    d = [3];
    cache.append(d);
    return 1;
}

with entry {
    print(crosses() + explicit() + seals());
}
```

```text
error[E1403]: Heap value 'data' crosses implicitly out of a nogc-enforced module (enforced by jac.toml [memory] "strict_*")
error[E1402]: Owned value 'd' is sealed into managed storage inside a nogc-enforced module (enforced by jac.toml [memory] "strict_*")
```

Here `loose` is a module no pattern matches, with
`def consume(xs: list[int]) -> int`. `explicit` passes its list with
`managed(e)`, which is allowed, and the heap global `cache` is allowed under
`managed`.

| Code | Meaning |
|---|---|
| E1401 | A heap-typed parameter, or a local, has no ownership state. |
| E1402 | An owned value is sealed into managed storage. |
| E1403 | A heap value crosses into a module not held to the contract without `managed()`. |
| E1404 | A parameter typed `any` or a union. |
| E1405 | A closure captures a heap value from outside it. |
| E1406 | A heap global under `nogc`; a borrowed or `imm` value entering an owning container; a builtin that would keep a raw reference. |
| E1407 | The entry block does not handle an exception it can raise. |

## Patterns

`enforce` and `exempt` are lists of patterns matched against a module's
dotted name (`strict_*`, `app.core.*`); the main module's name is its file
name without `.jac`. A pattern is a shell-style one: `*` matches any run of
characters, dots included, `?` one character, and `[abc]` or `[!abc]` one
character of a set or not of it. A module that matches an `enforce` pattern
and no `exempt` pattern is held to the contract; a module matching neither
is not. A module of the project whose name starts with `rt.` is the
project's own and is held when a pattern names it: only the toolchain's
runtime is exempt by where it is.

## What a nogc build leaves out

A `nogc` build of a program that keeps the contract counts nothing: owners
drop what they own at their last use, and the runtime's reference counting
is compiled out of the program. Its allocations keep their header, which
the allocator needs to free them.

Strings are owned like the rest:

- **An owner frees the `str` or `bytes` it owns when it drops**, and a
  container frees the strings it holds, nested ones too, as it drops.
- **A string a statement makes that nothing takes is freed when the
  statement ends**: a conditional expression's arm, an `or` operand, a
  method chain's step, a comprehension filter's or a `while` condition's
  temporary, a `raise`'s or an `assert`'s message, an f-string inside an
  f-string.
- **What keeps a string past its owner keeps a copy.** A method that may
  give back the very string it was called on (`s.removeprefix("zz")` when
  `s` has no such prefix) gives a copy to a list, a field, a dict's key or
  value, or an `own str` parameter that keeps it. `sorted(src)`,
  `list(src)`, `src.copy()` and a slice `src[0:2]` of a borrowed
  `list[str]` own copies of its strings.

Under `nogc` a [struct](structs.md) is still copied where it goes, and a
list of structs holding strs is packed and owns them.

## Differences from the reference design

The reference design reports a profile it does not know, or `enforce` and `exempt` under
`nogc`, as warnings. jac makes each an error.
