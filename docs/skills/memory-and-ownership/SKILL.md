---
name: memory-and-ownership
description: Use when choosing how a native Jac program manages memory (the managed, rc or nogc profile), when writing code with own, &, &mut, imm or lin, regions, or jac.toml's [memory] enforce, and when fixing ownership and contract errors E13xx and E14xx such as E1301 use after move or E1401 missing ownership state.
---
# Memory profiles and ownership

## When to use this

Use it to free memory with no collector (`nogc`), avoid collector pauses (`rc`), hold modules
to the ownership contract, or fix an E13xx or E14xx code.

Load `writing-jac` first; for a code you do not know, `resolving-diagnostics`. Most programs need
none of this: the default profile, `managed`, frees everything, cycles included.

## Before you start

```sh
jac docs memory            # the three profiles, when a value is freed, del
jac docs ownership         # own, lin, imm, &, &mut, moves
jac docs borrow            # borrows, owned fields, take() and swap()
jac docs nogc contract     # what nogc and [memory] enforce demand
jac docs region            # in Region() { ... }
```

The project's `jac.toml` `[memory]` table, if any, decides the profile of its builds and tests.

## Steps

1. **Choose the profile.**

| Profile | Pick it when |
|---|---|
| `managed` (default) | Ordinary code. Counted, cycles collected. |
| `rc` | No collector wanted, and the code has no cycles or breaks them (`x.other = None`, `del` a node) |
| `nogc` | Nothing counted: every module proves where each heap value is freed |

Set it in `jac.toml`:

```toml
[memory]
profile = "nogc"     # or one build: jac build main.jac -o main --memory rc
```

To hold only some modules to the contract, stay on `managed` or `rc` and list them in
`[memory]`: `enforce = ["core_*"]` (`exempt` takes some back out; both are errors under `nogc`).

2. **Write contract-keeping code.** Every heap-typed parameter states how it is passed: `&T` to
   read, `&mut T` to change, `own T` to take, `imm T` for a value nothing changes. Scalars need
   none. Return fresh values as `own T`. Lend at the call: `&x`, `&mut x`.

```jac
obj Item {
    has name: str,
        qty: int = 0;
}

def total(items: &list[Item]) -> int {
    s = 0;
    for it in items {
        s += it.qty;
    }
    return s;
}

def restock(items: &mut list[Item], name: imm str, qty: int) {
    items.append(Item(name=name, qty=qty));
}

def names(items: &list[Item]) -> own list[str] {
    out: own list[str] = [];
    for it in items {
        out.append(it.name.upper());
    }
    return out;
}

def run {
    stock: own list[Item] = [];
    restock(&mut stock, "pen", 3);
    restock(&mut stock, "pad", 2);
    print(total(&stock), names(&stock));
}

with entry {
    run();
}
```

```output
5 ['PEN', 'PAD']
```

It prints the same under every profile; under `nogc` nothing in it is counted. Keep heap data
out of module globals, put work in functions the entry block calls, and catch in the entry
block every exception the calls can raise.

3. **Use a region** for many short-lived values: everything made in `in Region() { ... }` is
   freed together as the block closes. Only scalars leave by assignment; copy anything else out
   with `own (expr)` or `managed(expr)`:

```jac
obj Row {
    has cells: list[str] = [];
}

def widest(lines: &list[str]) -> int {
    best = 0;
    in Region() {
        for line in lines {
            row = Row(cells=line.split(","));
            best = max(best, len(row.cells));
        }
    }
    return best;
}

with entry {
    lines = ["a,b", "a,b,c", "x"];
    print(widest(&lines));
}
```

```output
3
```

Avoid, for now, a method that adds a region's value to an outer container (`out.append(Row())`
in the block): a known defect lets it compile, and it crashes. Stores (`xs[0] = ...`) are E1307.

4. **Check under the profile you ship** (`jac check main.jac` in the project applies its
   `[memory]` table), then `jac build main.jac -o main && ./main`.

## What a correct result looks like

`jac check` prints nothing under the chosen profile (`jac check main.jac --memory nogc`
to try one). `__del__` runs once per owned object, right after its owner's last use; printing
from `__del__` shows the order.

## Mistakes to expect

Ownership errors are reported under every profile:

```jac
# expect: E1301, E1302, E1306, E1328
obj Buffer {
    has n: int = 0;
}

def moved -> int {
    a: own Buffer = Buffer();
    b = a;
    return a.n + b.n;
}

def leak -> &Buffer {
    b: own Buffer = Buffer();
    return &b;
}

def twice {
    a: own Buffer = Buffer();
    m1 = &mut a;
    m2 = &mut a;
    m1.n = 1;
    m2.n = 2;
}

def grow(xs: &mut list[int]) {
    xs.append(1);
}

def lend {
    a: own list[int] = [];
    grow(&a);
}
```

| Code | Means | Fix |
|---|---|---|
| E1301 | An owner read after it was moved (`b = a` moves a fresh value) | Lend `&a` instead, or read `a` before the move |
| E1302 | Two live mutable borrows | Use one, then make the next |
| E1306 | A borrow of a local returned | Return `own T` |
| E1328 | `&x` lent to a `&mut` parameter | `&mut x` |
| E1307 | A region's value stored outside it or returned | `own (expr)` or `managed(expr)` |
| E1401 | A heap parameter with no state (contract) | `&T`, `&mut T`, `own T` or `imm T` |
| E1404 | `any` or a union parameter (contract) | One concrete type |
| E1405 | A closure captures a heap value (contract) | Pass it as an argument |
| E1406 | A heap global under `nogc`; a borrowed value appended to an owning container | Move the data into a function; append a fresh or moved value |
| E1403 | A heap value passed to a module not held to the contract | `managed(x)` (under `managed`/`rc` only) |
| E1407 | The entry block leaves an exception unhandled (contract) | `try`/`except` around the call |

Every contract error ends with what enforced it: `(enforced by the nogc profile)` or
`(enforced by jac.toml [memory] "core_*")`. Under `nogc`, `managed(x)` itself is E1406.

## Where to look things up

- `jac docs memory`: when each value is freed, cycles, `__rc_collect_cycles`, `JAC_GC`.
- `jac docs borrow`: borrows in loops, views, owned fields, `take()`, `swap()`.
- `jac docs nogc contract`: inferred states of unmarked locals, patterns, what a nogc build drops.
- `jac docs region`: named regions, `region_of`, partitions. `jac docs E1406`: any code.
