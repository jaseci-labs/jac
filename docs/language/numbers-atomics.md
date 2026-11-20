---
description: atomics.Atomic[T], an integer that several threads read and change in one indivisible step each, its use from a parallel flow for, and the atomic intrinsics that work on an address.
keywords: atomics, Atomic, atomic, compare_exchange, fetch_min, fetch_max, __atomic_fence, __atomic_xchg_i64, memory order, memory_order
---
# Atomic integers

`atomics.Atomic[T]` is an int of type `T` that threads change in one step
each, at `T`'s width, so that no thread sees another's change half made. It
is the object a parallel `flow for` body uses to change something its
iterations share (see `jac docs "flow for"`).

```jac
import from atomics { Atomic }

def stats(xs: &list[int]) -> tuple[int, int] {
    hits = Atomic[i32]();
    most = Atomic[int](-1);
    flow for i in range(len(xs)) {
        if xs[i] % 3 == 0 {
            hits.add(1);
        }
        most.fetch_max(xs[i]);
    }
    return (hits.load(), most.load());
}

with entry {
    xs = [1, 2, 3, 4, 5, 6, 9];
    print(stats(&xs));
}
```

```output
(3, 9)
```

## The type

`Atomic` is a generic class whose parameter is bounded by `Int`
(see [Generic classes](generics-classes.md)):

- `T` is any int type of 64 bits or fewer: `Atomic[int]`, `Atomic[u8]`,
  `Atomic[i32]`. Each is its own instance of the class, holding a `T`.
- `Atomic[T]()` starts at 0, and `Atomic[T](v)` at `v`.
- A type that is not an int is refused (E1283): `Atomic[float]`,
  `Atomic[bool]`. `Atomic` alone is refused too (E1283), since its
  parameter would be `any`, which is no int. An `Atomic` of a float or a
  bool is not offered.
- A 128-bit int is refused (E1285).

## The operations

| Method | What it does | Gives |
|---|---|---|
| `load()` | Reads the value. | the value |
| `store(v)` | Replaces the value. | nothing |
| `add(v)`, `sub(v)` | Adds or subtracts, wrapping at `T`'s width. | what it held before |
| `and_(v)`, `or_(v)`, `xor(v)` | Combines the bits with `v`'s. | what it held before |
| `exchange(v)` | Replaces the value. | what it held before |
| `fetch_min(v)`, `fetch_max(v)` | Leaves the lesser or the greater of the value and `v`, as `T` orders them (an unsigned type's order is unsigned). | what it held before |
| `compare_exchange(expected, new)` | Stores `new` only over the value `expected`. | what it held: it stored exactly when that is `expected` |

Every operation is sequentially consistent: all threads agree on one order
of the operations on an `Atomic`. `add` and `sub` wrap, as a processor's
atomic arithmetic does; they do not raise `OverflowError`.

```jac
import from atomics { Atomic }

with entry {
    a = Atomic[u8](250);
    print(a.add(10), a.load());
    print(a.exchange(7), a.compare_exchange(7, 9), a.load());
    print(a.compare_exchange(7, 1), a.load());
    print(a.fetch_min(2), a.fetch_max(200), a.load());
    a.store(3);
    print(a.and_(1), a.or_(6), a.xor(3), a.load());
}
```

```output
250 4
4 7 9
9 9
9 2 200
3 1 7 4
```

`add(10)` on 250 gives 250 and leaves 4: the sum wrapped at 8 bits. The
second `compare_exchange` gives 9, not 7, so it stored nothing. `str()` and
`print` of an `Atomic` show what it holds: `Atomic(4)`.

A retry loop over `compare_exchange` claims a value no other thread claims:

```jac
import from atomics { Atomic }

def claims(n: int) -> int {
    free = Atomic[int]();
    flow for i in range(n) {
        seen = free.load();
        while free.compare_exchange(seen, seen + 1) != seen {
            seen = free.load();
        }
    }
    return free.load();
}

with entry {
    print(claims(1000));
}
```

```output
1000
```

## In a parallel loop

A `flow for` body reads outer state only when it is shared or `imm`, and
changes none of it but its reductions. An `Atomic` is the exception that
lets a body change something from outside: its class conforms to `Shared`,
so a body may capture one and call its methods. A class of the program's
own may conform to `Shared` too, each of its methods changing its object
only through `Atomic`s:

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

def tallied(xs: &list[int]) -> tuple[int, int] {
    t = Tally();
    flow for i in range(len(xs)) {
        if xs[i] % 3 == 0 {
            t.add(xs[i]);
        }
    }
    return (t.hits.load(), t.total.load());
}

with entry {
    xs = [1, 2, 3, 4, 5, 6, 9];
    print(tallied(&xs));
}
```

```output
(3, 18)
```

Any other object of the caller's, one of no `Shared` class, stays refused
there (E1308).

## Atomics on an address

An `Atomic` owns its cell. Code that shares a cell with C, or lays its cells
out itself, works on an `int` address with the atomic intrinsics. A program
calls them by name, with no import.

| Call | What it does | Gives |
|---|---|---|
| `__atomic_load_<t>(addr, order)` | Reads the cell. | the value |
| `__atomic_store_<t>(addr, v, order)` | Writes it. | nothing |
| `__atomic_add_<t>`, `_sub_`, `_and_`, `_or_`, `_xor_`, `_swap_`, `_min_`, `_max_` `(addr, v, order)` | Changes it as the `Atomic` method of that meaning does (`swap` is `exchange`). | what it held before |
| `__atomic_cas_<t>(addr, expected, new, order)` | Stores `new` only over `expected`. | what it held |
| `__atomic_xchg_i64(addr, v)` | `__atomic_swap_i64` with order 5. | what it held before |
| `__atomic_fence(order)` | Orders the thread's memory operations before it against those after it. | nothing |

- **`<t>` is the cell's type**: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`,
  `u32` or `u64`. The value is of that type (an `int` for `i64`), a load
  of a signed cell sign-extends, and `min` and `max` order as the type
  does. Calls of several widths on one address work on the same bytes.
- **`order` is C's `memory_order`, as a constant**: 0 relaxed, 1 consume,
  2 acquire, 3 release, 4 acq_rel, 5 seq_cst. A load cannot use 3 or 4,
  and a store cannot use 1, 2 or 4.

```jac
import from c {
    def calloc(n: int, size: int) -> int;
    def free(p: int);
}

with entry {
    p = calloc(1, 8);
    __atomic_store_i64(p, 40, 5);
    print(__atomic_add_i64(p, 2, 5), __atomic_load_i64(p, 2));
    print(__atomic_cas_i64(p, 42, 7, 5), __atomic_cas_i64(p, 42, 9, 5));
    print(__atomic_max_i64(p, 10, 5), __atomic_xchg_i64(p, 3), __atomic_load_i64(p, 0));
    __atomic_store_u8(p, u8(255), 5);
    __atomic_fence(5);
    print(__atomic_load_u8(p, 5), __atomic_load_i8(p, 5));
    free(p);
}
```

```output
40 42
42 7
7 10 3
255 -1
```

A call that breaks these rules (an order that is not a constant from 0 to
5, or that its operation cannot use) is refused with E5095. An address is
native memory, so the atomic intrinsics are native code's: each is refused
in a `cpython` or JS space (E1540).

## What is rejected

```jac
# expect: E1283 x3, E1285, E1308, E5095 x2
import from atomics { Atomic }

obj Counter {
    has n: int = 0;
}

def count(xs: &list[int], c: Counter) {
    flow for i in range(len(xs)) {
        c.n += xs[i];
    }
}

with entry {
    a = Atomic[float]();
    b = Atomic();
    c = Atomic[bool]();
    d = Atomic[i128]();
    print(__atomic_load_i64(0, 3));
    __atomic_store_i64(0, 1, 2);
}
```

| Code | Meaning |
|---|---|
| E1283 | `Atomic`'s type argument is not an int type, or is missing. |
| E1285 | The type argument is wider than 64 bits. |
| E1308 | A `flow for` body changes an outer object that is not of a `Shared` class. |
| E1540 | An atomic intrinsic in a `cpython` or JS space, which has no native memory. |
| E5095 | An atomic intrinsic's order is not a constant from 0 to 5, or is one its operation cannot use: a load that releases, a store that acquires. |
