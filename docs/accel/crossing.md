---
description: The crossing ladder, which says by a value's type whether it may go to a device, be reached by several threads, or be sent to another thread or space - plain, shared and sendable - and the Shared interface.
keywords: sendable, Shared, crossing ladder, plain, shared value
---
# What crosses into a place

A value crosses into a place when a kernel is launched with it, when a parallel
loop's threads read it, or when a call sends it to another space. Whether it may
cross is decided by its type's rung on a ladder of three: plain, shared and
sendable. Every plain type is shared, and every shared type but a `Shared`
object is sendable.

Whether the code itself can run in the place is a separate question, answered by
what the code needs: see
[What code needs from the place it runs](requirements.md).

| Rung | What it means | Who asks for it |
|---|---|---|
| plain | bits alone, which may be copied anywhere | a kernel's launch |
| shared | what several threads may reach at once | a parallel `flow for`'s body |
| sendable | what may be moved or serialized, and reaches only what is its own | a call between spaces |

## Plain

Plain data is bits alone: numbers, bools, narrow floats, vectors, arrays,
128-bit ints, and structs of them. It may be copied anywhere: to a device,
another thread, another space, C or a file.

A kernel's launch passes plain data and tensors. Each plain argument arrives as
a copy of the numbers it holds, the kernel's own to change. What is not plain
needs what a device lacks, so a kernel with such a parameter is refused with
`E1540`:

```jac
# expect: E1540 x2
import from accel { tensor, kernel }

obj Box {
    has v: int = 0;
}

def takes_box(i: int, b: Box, y: tensor[f32, _]) {
    y[i] = f32(b.v);
}

with entry {
    kernel(takes_box).run(4, Box(v=1), tensor[f32, _](shape=4));
}
```

```text
main.jac:8:1: error[E1540]: parameter 'b' (Box) needs counted references, which a kernel run for each index does not provide (in takes_box)
main.jac:9:16: error[E1540]: 'b' needs counted references, which a kernel run for each index does not provide (in takes_box)
```

Declared as a `struct` (see [Structs](../language/structs.md)), `Box` is plain
and crosses.

## Shared

A value is shared when several threads may reach it at once:

- plain data, which each thread copies,
- what never changes: a str, bytes, `None`, an enum's member, and a tuple, a
  union or a struct of shared values,
- an object of a class that conforms to the runtime's `Shared` (below).

A parallel `flow for`'s body reads outer state only when it is shared, or is an
`imm` binding. Reading anything else is `E1308`:

```jac
# expect: E1308 x2
obj Total {
    has n: int = 0;

    def add(v: int) {
        self.n += v;
    }
}

def summed(xs: &list[int]) -> int {
    t = Total();
    names = ["a", "b"];
    flow for i in range(len(xs)) {
        t.add(xs[i] + len(names));
    }
    return t.n;
}
```

```text
main.jac:14:9: error[E1308]: 't' is not sendable across a concurrency boundary
main.jac:14:27: error[E1308]: 'names' is not sendable across a concurrency boundary
```

The same loop compiles with shared values in place of the two: here a str, a
tuple, an enum's member, a struct, a vector, an `imm` dict, and an `Atomic`,
which is a `Shared` object.

```jac
import from atomics { Atomic }

enum Color {
    RED = 1,
    BLUE = 2,
}

struct Weight {
    has x: f32 = 0.0;
}

def summed(xs: &list[int]) -> int {
    total = 0;
    label = "abc";
    pair = (1, "two");
    color = Color.BLUE;
    w = Weight(x=2.0);
    lanes = simd[i32, 4](1);
    table: imm dict[str, int] = {"a": 1, "bb": 2};
    hits = Atomic[int]();
    flow for i in range(len(xs)) {
        k = len(label) + pair[0] + color.value + int(w.x) + lanes[0] + table["bb"];
        hits.add(1);
        total += xs[i] * k;
    }
    return total + hits.load();
}

with entry {
    xs = [1, 2, 3];
    print(summed(&xs));
}
```

```output
69
```

The lists and views a body reads or writes by index are lent around the loop
(`&xs`), which is the loop's own rule: see `jac docs "flow for"`.

## The Shared interface

A class conforms to `Shared` by listing it as a base, as `atomics.Atomic` does.
It promises that each of its methods, except its construction and its drop,
changes its object in one indivisible step. The compiler checks the promise
(`E1541`):

- no method writes the object's fields,
- no method needs, in itself or in anything it may call, what a parallel loop's
  threads lack.

So a `Shared` class keeps its state in `Atomic`s, or in other `Shared` objects,
and a `flow for` body may capture one of its objects and change it:

```jac
import from atomics { Atomic }

obj Tally(Shared) {
    has hits: Atomic[int] = Atomic[int](),
        total: Atomic[int] = Atomic[int]();

    def add(v: int) {
        self.hits.add(1);
        self.total.add(v);
    }
}

def tallied(xs: &list[int]) -> int {
    t = Tally();
    flow for i in range(len(xs)) {
        t.add(xs[i]);
    }
    return t.total.load();
}

with entry {
    xs = list(range(1000));
    print(tallied(&xs));
}
```

```output
499500
```

A method that writes a field is not one step, and a call of C is a call no
analysis follows:

```jac
# expect: E1541 x2
import from c {
    def getpid -> i32;
}

obj Racy(Shared) {
    has n: int = 0;

    def bump {
        self.n += 1;
    }

    def outside -> i32 {
        return getpid();
    }
}
```

```text
main.jac:9:5: error[E1541]: Racy conforms to Shared, so each of its methods changes its object in one indivisible step, and 'bump' writes its fields
main.jac:13:5: error[E1541]: Racy conforms to Shared, so each of its methods changes its object in one indivisible step, and 'outside' needs C code, which threads at once do not have
```

## Sendable

A value is sendable when it may be moved or serialized to another thread or
space, and everything it reaches is its own. Sendable are:

- shared values, except `Shared` objects,
- the lists, dicts, sets, tuples and unions of sendable values,
- an object, a node, an edge or a walker of a class of the program whose fields
  are all sendable. A class may hold itself among them:
  `obj Tree { has kids: list[Tree]; }` is sendable.

A generic class's fields are what its type's arguments say. With
`obj Box[T] { has item: T; }`, a `Box[int]` is sendable; a `Box[Atomic[int]]`
is not, and neither is a `Box` alone, which is a box of `any`.

Not sendable: an `any`, a function value, a `dyn`, a C record, a Python object,
a tensor and a pointer.

A call between spaces sends only sendable values, both the arguments and the
result (`E1308`). The module below is the entry of one native space and calls
functions another native space exports; `Slot` holds an `Atomic`, a `Shared`
object, which stays in its process:

<!-- example: not checked: needs a project of two spaces, the second exporting count, weigh, held and the classes -->
```jac
import from atomics { Atomic }

with entry {
    print(count(Tree(label="r", kids=[Tree(label="a", kids=[])])));
    print(weigh(Box[int](item=3)));
    print(held(Slot(hits=Atomic[int]())));
}
```

```text
main.jac:6:16: error[E1308]: 's: Slot' is not sendable across a concurrency boundary
```

The first two calls send a tree of objects and a `Box[int]`, and are accepted.
The exporting space is held to the same rule where `held` is declared. How
spaces are declared and call each other is with the spaces pages
(`jac docs space`).

A sendable value of plain data is serialized as its numbers: an `f32`, an array,
a vector, a 128-bit int and a struct of them all cross a call between spaces
and arrive equal.

## Diagnostics

| Code | Reported when |
|---|---|
| `E1308` | a parallel `flow for`'s body reads outer state that is neither shared nor `imm`, or a call between spaces sends a value that is not sendable |
| `E1540` | a kernel takes a parameter that is not plain data or a tensor |
| `E1541` | a method of a class conforming to `Shared` writes its fields or needs what a parallel loop's threads lack |
