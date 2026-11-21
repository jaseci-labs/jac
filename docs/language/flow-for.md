---
description: The parallel loop flow for over lent lists, chunks and ranges - how its iterations are split across threads, how reductions fold, which exception it raises, when it runs in order, and what its body may touch.
keywords: flow for, parallel loop, reduction, chunks
---
# Parallel loops: `flow for`

`flow for` is the parallel loop. Its iterations are split into chunks that run
at once on a pool of threads, joined at the loop's closing brace. The compiler
checks that the body touches nothing another iteration touches, so the loop
leaves what a sequential run leaves, with one exception: a float sum or product
is added up chunk by chunk.

A `flow for` over a range whose body writes a tensor's items is a kernel, with
rules of its own: see [Parallel loops over tensors](../accel/parallel-loops.md)
(`jac docs flow for over tensors`). This page is the loop over lists and
ranges. `flow e` on an expression, which makes a task, is a different construct
([Async](async.md), `jac docs flow`).

## Syntax

`flow for` is the `for` statement with the `flow` marker
([Control flow](control-flow.md)):

```ebnf
for_stmt ::= "comptime"? "async"? "flow"? "for" atomic_chain ("=" expression "while" expression "with" atomic_chain assignment? | "in" expression) block else_stmt?
```

It takes three forms:

| Form | Each iteration gets |
|---|---|
| `flow for i in range(a, b, step)` | an index; `step` is a constant, negative allowed |
| `flow for x in &xs`, `flow for x in &mut xs` | an element of a list lent to the loop |
| `flow for part in &mut xs.chunks(k)` | a run of `k` elements to write in place, the last run shorter |

The list is lent with `&` when the body only reads its elements and `&mut` when
it changes them ([Borrows](ownership-borrows.md)). A list of scalars is not
lent `&mut` element by element (a scalar is copied, `E1330`): write it by index
over a range, or by chunks.

## An example

The body below writes each iteration's own element and keeps a total, a
reduction:

```jac
def squares(out: &mut list[int]) -> int {
    total = 0;
    flow for i in range(len(out)) {
        out[i] = i * i;
        total += out[i];
    }
    return total;
}

with entry {
    xs = [0 for _ in range(10)];
    print(squares(&mut xs), xs);
}
```

```output
285 [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
```

A `&mut` loop over objects changes each in place; a loop over chunks writes each
chunk back into the list:

```jac
obj Cell {
    has n: int = 0;

    def bump(step: int) {
        self.n += step;
    }
}

with entry {
    cells: list[own Cell] = [Cell(n=i) for i in range(4)];
    flow for c in &mut cells {
        c.bump(10);
    }
    print([c.n for c in cells]);
    ys = [i for i in range(10)];
    longest = 0;
    flow for part in &mut ys.chunks(4) {
        for i in range(len(part)) {
            part[i] *= 2;
        }
        longest = max(longest, len(part));
    }
    print(ys, longest);
}
```

```output
[10, 11, 12, 13]
[0, 2, 4, 6, 8, 10, 12, 14, 16, 18] 4
```

`continue` ends one iteration and is allowed. A range may step down by a
constant, `flow for i in range(len(out) - 1, -1, -3)`, each index writing its
own element.

## How the iterations are split

The loop runs `JAC_THREADS` wide, 4 when it is unset. The program reads the
digits the value starts with (`8x` is 8); a value that starts with none, or `0`,
is 1 ([Environment variables](../reference/environment.md)).

A loop of `n` iterations at width `w` runs as chunks of `ceil(n / min(w, n))`
iterations each, in index order, the last chunk what remains; a loop of no
iterations is one empty chunk. There is no smallest chunk: 10 iterations at
width 4 are chunks of 3, 3, 3 and 1, and 10007 at width 16 are chunks of 626.
Each chunk runs on a thread of its own, the first on the thread that runs the
loop. The chunking depends only on `n` and `w`, never on how the threads are
scheduled.

## Reductions

A body writes no outer variable except its reductions, each one of these four
statements on an outer `int` or float (`float`, `f32`, `f16`, `bf16`):

| Statement | Each chunk's partial starts from |
|---|---|
| `x += e` | `x` in the first chunk, `-0.0` (an int: `0`) in the others |
| `x *= e` | `x` in the first chunk, `1` in the others |
| `x = min(x, e)` | `x` in every chunk |
| `x = max(x, e)` | `x` in every chunk |

One variable takes one of them, in as many places as the body needs (`p *= -1`
in one branch, `p *= 0` in another), and the body mentions it nowhere else: no
other operation, no read, no closure that captures it (`E1308` otherwise). Each chunk keeps a partial result, accumulated over its iterations
in order in the variable's own type, and after the join the partials are folded
into the first in chunk order.

Integer reductions, `min` and `max` give exactly what a sequential run gives at
every width, NaN and signed zeros included, as Python's `min` and `max` pick:

```jac
def extremes(xs: &list[float], lo: float, hi: float) -> tuple[float, float] {
    flow for i in range(len(xs)) {
        lo = min(lo, xs[i]);
        hi = max(hi, xs[i]);
    }
    return (lo, hi);
}

with entry {
    xs = [-0.0, 0.0, float("nan"), 0.5];
    print(extremes(&xs, float("inf"), float("-inf")));
    print(extremes(&xs, float("nan"), 0.75));
}
```

```output
(-0.0, 0.5)
(nan, 0.75)
```

One difference: an integer reduction overflows, raising `OverflowError`, where
the chunked order does: summing `[-5, 0, 9223372036854775807, 1]` raises at width 2, whose second
chunk adds the last two, and gives `9223372036854775803` at widths 1 and 4.

A float `+=` or `*=` is not added in a sequential run's order, so it may differ
from one in rounding. It is the same for the same width on every run, and
`JAC_THREADS=1` gives the sequential result:

```jac
def total(xs: &list[float]) -> float {
    s = 0.0;
    flow for i in range(len(xs)) {
        s += xs[i];
    }
    return s;
}

with entry {
    xs = [1e16, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
    print(total(&xs));
}
```

```text
$ ./total                    # width 4: chunks [1e16, 1] [1, 1] [1, 1] [1, 1]
1.0000000000000006e+16
$ JAC_THREADS=1 ./total      # one chunk: each 1.0 is lost against 1e16
1e+16
```

A count, sum, least or greatest kept in an [`Atomic`](numbers-atomics.md) is
also the sequential value at any width.

## Exceptions

When iterations raise, the loop raises what the lowest index raised, as a
sequential run would, after the join. A `try` around the loop catches it:

```jac
def checked(out: &mut list[int], src: &list[int]) {
    flow for i in range(len(src)) {
        if src[i] < 0 {
            raise ValueError(f"negative at {i}");
        }
        out[i] = src[i] * 2;
    }
}

with entry {
    src = [1 for _ in range(1000)];
    src[700] = -1;
    src[200] = -1;
    out = [0 for _ in range(1000)];
    try {
        checked(&mut out, &src);
    } except ValueError as e {
        print("caught:", e);
    }
}
```

```output
caught: negative at 200
```

Iterations of other chunks may have run and written their elements, and the
reduction variables keep their values from before the loop.

## What the body may touch

The body reads outer state only when it is shared or `imm`, and writes only the
iteration's own places (see [What crosses into a place](../accel/crossing.md),
`jac docs shared value`):

- its reductions;
- over a range, `w[i] = e`, `w[i] op= e` and reads of `w[i]`, where `i` is the
  loop's index, which the body never binds, and `w` a list of values (numbers,
  strs, tuples of them) lent `&mut` around the loop: a `&mut` parameter or a
  local declared `&mut`;
- a `&mut` loop's element and a chunk's elements;
- an `Atomic`, or another object of a class that conforms to `Shared`;
- what the body made itself.

It may read anywhere in the lists lent `&` around it, read plain data, strs,
tuples, enum members and `imm` bindings, call functions and methods (methods of
shared objects that change nothing included), and make and drop strs, lists,
dicts and objects of its own. Such a body fans out across the threads under
every memory profile:

```jac
import from atomics { Atomic }

obj Rect {
    has w: int = 0,
        h: int = 0;

    def area -> int {
        return self.w * self.h;
    }
}

def label(r: Rect) -> str {
    parts: list[str] = [];
    for k in range(r.w % 3 + 1) {
        parts.append(str(r.w + k));
    }
    return "-".join(parts) + f":{r.area() / 3.0:.2f}";
}

def summary(rects: &list[Rect]) -> tuple[int, int] {
    bonus: imm dict[str, int] = {"square": 100, "other": 0};
    evens = Atomic[int]();
    t = 0;
    flow for r in &rects {
        kind = "square" if r.w == r.h else "other";
        t += len(label(r)) + bonus[kind];
        if r.area() % 2 == 0 {
            evens.add(1);
        }
    }
    return (t, evens.load());
}

with entry {
    rects = [Rect(w=i, h=i % 4) for i in range(10)];
    print(summary(&rects));
}
```

```output
(479, 5)
```

A body may `print`. The lines come in no fixed order, and as with Python's
threads, the text of one `print` and its line end are written apart, so lines
of different iterations can run together.

## When it runs in order

Some loops are accepted but do not fan out. Two kinds:

**The loop runs as a plain `for`**, its reductions sequential, when its target
is a name bound before the loop, when it binds more than one name
(`flow for (k, v) in &pairs`), when the list is not a local (`&self.items`),
when it walks the chunks of a list whose length the body may change, or when it
is `&mut` over a list whose elements may alias: only a `list[own T]` holds each
object once. A list may hold one object twice, so both changes land:

```jac
obj Cell {
    has n: int = 0;
}

with entry {
    k = Cell();
    cells = [k, k, Cell()];
    flow for c in &mut cells {
        c.n += 1;
    }
    print(k.n, cells[2].n);
}
```

```output
2 1
```

**The chunks run one after another on the calling thread**, each with the
partials a parallel run keeps, so every result is the parallel run's, when a
list the body writes by index may be the one it reads, when a `flow for` runs
inside another's body, or when something the body may run changes what another
thread may reach: it assigns a module global or a captured name, writes a
shared object through another name (`alias = c; alias.n += 1`), grows a
container a field holds (`self.items.append(v)`), calls `random`, `re` or
`math`, or needs what a loop's threads lack (a call no analysis follows, a
graph's change, a task). The full list is in
[Where code runs](../accel/requirements.md) (`jac docs requirements`).

```jac
def shift(out: &mut list[int], src: &list[int]) {
    flow for i in range(len(out) - 1) {
        out[i] = src[i + 1];
    }
}

def shifted(a: list[int], b: list[int]) {
    shift(&mut a, &b);
}

with entry {
    zs = list(range(10));
    shifted(zs, zs);
    print(zs);
}
```

```output
[1, 2, 3, 4, 5, 6, 7, 8, 9, 9]
```

A chunk that raises in such a loop ends it there.

## What is rejected

`E1313` is a form a parallel loop cannot take:

```jac
# expect: E1313 x5
def first_negative(xs: &list[int]) -> int {
    found = -1;
    flow for i in range(len(xs)) {
        if xs[i] < 0 {
            break;
        }
    }
    return found;
}

def every(out: &mut list[float], k: int) {
    flow for i in range(0, len(out), k) {
        out[i] = 1.0;
    }
}

def pairs(xs: &mut list[int]) {
    flow for (a, b) in &mut xs.chunks(2) {
        a += b;
    }
}

with entry {
    xs = [1, 2, 3];
    flow for x in xs {
        print(x);
    }
    flow for y in &xs {
        print(y);
    } else {
        print("done");
    }
}
```

`E1308` is a body that reaches what is not its iteration's own: another
iteration's element (`out[i + 1]`), an element after rebinding the index, a list
not lent `&mut`, a list lent `&`, a variable with two operations or one a
closure captures, an outer list it grows, an object of the caller's whose class
is not `Shared`:

```jac
# expect: E1308 x3
def shift(out: &mut list[float], src: &list[float]) {
    flow for i in range(len(src) - 1) {
        out[i + 1] = src[i];
    }
}

def mixed(src: &list[float]) -> float {
    s = 0.0;
    flow for i in range(len(src)) {
        s += src[i];
        s *= 2.0;
    }
    return s;
}

def collected(xs: &list[int]) -> list[int] {
    seen: list[int] = [];
    flow for i in range(len(xs)) {
        seen.append(xs[i]);
    }
    return seen;
}
```

| Code | Reported when |
|---|---|
| `E1308` | the body reads outer state that is neither shared nor `imm`, or writes a place not its iteration's own |
| `E1313` | `break`, `return` or `yield` leaves the body; an `else`; a step not a constant; a list not lent; a chunk bound to more than one name |
| `E1330` | `&mut` over a list of scalars |
| `E1541` | a class conforming to `Shared` has a method that writes its fields or needs what the threads lack |

## Differences from Python

Python has no parallel loop statement. Its threads share every object and
nothing checks what they touch; here the compiler holds the body to the rules
above, and runs a loop in order where its body may change what another
thread reaches.
