---
description: Ownership states on parameters, fields and bindings (own, lin, imm, & and &mut), moves, borrows and what the borrow checker refuses, take and swap, and owned fields and containers.
keywords: ownership, own, lin, imm, mut, move, moved, owner, linear
grammar: ownership_prefix, ref
---
# Ownership

An ownership state says who is responsible for a value on the heap. A
binding marked `own` is the value's one owner, and assigning it elsewhere
moves the value; `&` and `&mut` lend a value without giving it up; `lin` is
an owner that must be passed on; `imm` is a value that never changes. The
checker proves the rules when the program compiles, and the compiler drops
an owned value at its owner's last use.

A binding with no state is managed: the program holds a counted reference,
as Python does (see [Memory](memory.md)). States are optional under the
`managed` and `rc` memory profiles, where a program uses them where they
help, and required under `nogc` (see
[The nogc contract](ownership-contract.md)).

```jac
obj Buffer {
    has n: int = 0;
}

def consume(b: own Buffer) -> int {
    return b.n;
}

def peek(b: &Buffer) -> int {
    return b.n;
}

def bump(b: &mut Buffer) {
    b.n += 1;
}

with entry {
    a: own Buffer = Buffer(n=1);
    b = a;
    a = Buffer(n=2);
    print("move and revive:", a.n, b.n);
    v1 = &a;
    v2 = &a;
    print("shared borrows:", peek(v1) + peek(v2));
    bump(&mut a);
    bump(&mut a);
    print("after two bumps:", a.n);
    print("consumed:", consume(a));
}
```

```output
move and revive: 2 1
shared borrows: 4
after two bumps: 4
consumed: 4
```

## Syntax

A state is written before a type, on a parameter, a field, a local or a
global:

```ebnf
ownership_prefix ::= ("own" | "lin" | "imm" | "&" "mut"?)?
```

In an expression, `&x` and `&mut x` lend a value, `imm x` freezes one, and
`own (x)` makes an owner of a value leaving a region (see
[Regions](memory-regions.md)):

```ebnf
ref ::=
    dyn_type
    | ("own" | "imm") await_expr
    | "&" ("mut" await_expr | await_expr)
```

A prefix `&` is a borrow however it is spaced: `&x`, `& x` and `&(x)` are
one borrow. A binary `&` is the bitwise and.

## The states

| State | Written | Meaning |
|---|---|---|
| owned | `own T` | The binding is the value's one owner. Assigning it to another binding, or passing it to an `own` parameter, moves the value: the first binding holds nothing until it is assigned again. The value is dropped at the owner's last use. |
| linear | `lin T` | An owner that must be consumed on every path: returned as `own`, or given to an `own` or `lin` parameter (E1305 otherwise). |
| immutable | `imm T` | A value nothing changes, deeply: a field written through it is E1309. `imm a` freezes an owner into one; a value something else may still write, such as a parameter its caller may alias, cannot be frozen (E1311). |
| shared borrow | `&T`, `&x` | Reads the value while its owner keeps it. Any number may be live at once. |
| mutable borrow | `&mut T`, `&mut x` | Reads and writes the value while its owner keeps it. Exclusive: no other borrow of it is live at the same time. |
| managed | no prefix | A counted reference, as in Python. |

A struct is a value its place holds, not a reference, so `own`, `lin` and
`imm` mark no binding of one (E1507); see [Structs](structs.md).

## Moves

- **Assigning an owner moves it**: after `b = a`, reading `a` is E1301
  until `a` is assigned again, which revives it.
- **Passing an owner to an `own` parameter consumes it.** A function that
  only reads takes a borrow (`&T`) instead.
- **A builtin that only reads borrows**: `hay.find("x")`, a slice,
  `hay.startswith(...)` and `len` leave an `own str` usable.
- **A function value may consume its argument**: `Callable[[own Buffer],
  int]`.
- **A method may consume its receiver**: `def into_total(self: own
  Counter)`. Its other methods are called through a borrow.
- **A walker owner is consumed by `spawn`**, which gives it back:
  `res = w spawn s`.

```jac
obj Counter {
    has n: int = 0;

    def inc {
        self.n += 1;
    }

    def into_total(self: own Counter) -> int {
        return self.n * 100;
    }
}

def apply(f: Callable[[own str], int], s: own str) -> int {
    return f(s);
}

def size(s: own str) -> int {
    return len(s);
}

with entry {
    hay: own str = "ownership";
    print(hay.find("ship"), hay[0:3], hay.startswith("own"), hay);
    print(apply(size, hay));
    c: own Counter = Counter();
    c.inc();
    c.inc();
    print(c.into_total());
}
```

```output
5 own True ownership
9
200
```

## Borrows and owned places

`&x` and `&mut x` lend a value; a field or a container may own what it
holds, emptied with `take()` and exchanged with `swap()`. Both are on
[Borrows and owned places](ownership-borrows.md) (`jac docs borrow`).

## lin and imm

```jac
obj Ticket {
    has id: int = 0;
}

obj Buffer {
    has n: int = 0;
}

def redeem(t: own Ticket) -> int {
    return t.id;
}

def issue(id: int) -> own Ticket {
    t: lin Ticket = Ticket(id=id);
    return t;
}

def settle(t: lin Ticket) -> int {
    return redeem(t) + 1;
}

with entry {
    t: lin Ticket = issue(7);
    print(settle(t));
    frozen: imm Buffer = Buffer(n=8);
    a: own Buffer = Buffer(n=9);
    d = imm a;
    print(frozen.n, d.n);
}
```

```output
8
8 9
```

An `imm` value may be read from a `flow for` body and sent to a `flow` task
(see `jac docs "flow for"`).

## Drops

An owned value is dropped right after its owner's last use, not at the end
of its scope, and an owner never read again is dropped as soon as it is
made. (A name bound in module code, a `with entry` block, is a module
global, which lives as long as the program.) A borrow of it keeps it alive while the borrow lives. An owner is
dropped too when an exception leaves its scope, before a handler outside
it runs. Its `__del__` runs when it is dropped (see [Memory](memory.md)).

```jac
obj Guard {
    has name: str = "";

    def __del__ {
        print("  release", self.name);
    }
}

def parse_port(s: &str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(s: &str) -> int {
    _guard: own Guard = Guard(name="[" + s + "]");
    return parse_port(s) + 1;
}

def load_or_default(s: &str) -> int {
    try {
        return load(s);
    } except ValueError {
        return 8080;
    }
}

with entry {
    good: own str = "80";
    print(load_or_default(&good));
    bad: own str = "";
    print(load_or_default(&bad));
}
```

```output
  release [80]
81
  release []
8080
```

## What is rejected

```jac
# expect: E1301, E1305, E1309, E1311
obj Buffer {
    has n: int = 0;
}

def finish(b: own Buffer) {
    print(b.n);
}

def use_after_move {
    a: own Buffer = Buffer();
    b = a;
    print(a.n, b.n);
}

def lin_dropped(flag: bool) {
    f: lin Buffer = Buffer();
    if flag {
        finish(f);
    }
}

def imm_written {
    v: imm Buffer = Buffer();
    v.n = 5;
}

def frozen_param(b: Buffer) {
    d = imm b;
    print(d.n);
}
```

| Code | Meaning |
|---|---|
| E1301 | An owner is read after its value was moved. |
| E1305 | A `lin` binding is not consumed on every path. |
| E1308 | A live borrow is sent across a `flow` boundary. |
| E1309 | A field is written through an `imm` binding. |
| E1311 | `imm` of a value that may be aliased, such as a parameter. |
| E1507 | A struct binding is marked `own`, `lin` or `imm`. |

The errors of borrows and owned places (E1302 to E1304, E1306, E1315 to
E1323, E1328, E1330) are on
[Borrows and owned places](ownership-borrows.md).

## On other hosts

The checks run for every host. A `cpython`, `node`, `browser` or `hermes`
space then erases the states: its host frees an owned value when its last
reference goes, as its garbage collector does, not right after its owner's
last use, so `__del__` may run later there.

## Differences from Python and the reference design

- Python has no ownership: every binding is a counted reference, which is
  what an unmarked binding is here.
- A prefix `&` is always a borrow, however it is spaced (`& x`, `&(x)`).
