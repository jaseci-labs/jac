---
description: The memory model of native programs - the managed, rc and nogc profiles and how a program picks one, reference counting and when a value is freed, __del__, cycle collection, JAC_GC, and what del does.
keywords: memory, memory profile, managed, rc, nogc, --memory, reference counting, refcount, cycle collector, garbage collection, gc, __rc_collect_cycles, __rc_gc_disable, __rc_gc_enable, finalizer, drop
---
# Memory

A native program frees what it makes on the heap without a tracing garbage
collector. Every heap value is reference-counted and freed when its last
reference goes; the memory **profile** decides what happens to reference
cycles, and whether counting is used at all.

| Profile | Counting | Cycles | Use it for |
|---|---|---|---|
| `managed` (the default) | Every heap value is counted. | Collected by a cycle collector. | Programs written as Python is. |
| `rc` | Every heap value is counted. | Leak, unless the program breaks them. | Programs that avoid cycles, or break them with `del`, and want no collector pauses. |
| `nogc` | Nothing is counted. | Cannot form: every value has one owner. | Programs that keep the [ownership contract](ownership-contract.md), proved when they compile. |

## Choosing a profile

- `jac build --memory managed|rc|nogc` (and `jac check --memory ...`)
  picks the profile for that run.
- Without `--memory`, the project's `jac.toml` may pick it, for its builds
  and its tests:

  ```toml
  [memory]
  profile = "rc"
  ```

- Without either, the profile is `managed`.

A profile jac does not know is an error (`--memory arena`, or
`profile = "arena"`). So are `enforce` and `exempt` patterns under
`profile = "nogc"`, which holds every module to the contract already. Under
`managed` and `rc`, those patterns hold chosen modules to the contract: see
[The nogc contract](ownership-contract.md).

## What is counted

Under `managed` and `rc`, every value the program makes on the heap is
counted and freed when its last reference goes: objects (their `__del__`
runs then), the runtime's own objects among them (its exceptions, its
graph's edges), strings, bytes and bytearrays, lists, dicts, sets and tuples
of any length, boxes, closures, C records, generator frames, `flow` tasks
and the iterators the runtime makes.

Whatever holds a value counts it: a local, a field, a container, a
[struct](structs-storage.md)'s field, a generator's frame, a pending
exception, a `with` block's manager. What is never freed is what lives as
long as the program (the runtime's own globals, and the names a module
binds, its module code's included), besides what an owner drops (an `own`
binding, a [region](memory-regions.md)) and what C is given to keep.

## When a value is freed

Under `managed` and `rc` a value is freed as soon as nothing holds it:

- **A local gives up its value at its last use**, not at the end of its
  scope. A local never read again gives it up as soon as it is bound.
- **Rebinding a name, or assigning a field, gives up the old value** at
  once.
- **A container gives up what it lets go**: `pop()` whose result is unused,
  `del d[k]`, an item replaced, `clear()`; the rest goes with the
  container.
- **A temporary lives until its statement ends**: a value an argument makes
  survives the calls made after it in the same statement, and so does a
  value an argument reads from a field when a later argument replaces that
  field. A parameter's default, made for a call that leaves it out, goes
  when the statement of that call ends.
- **A value returned through `try` and `finally` is the one `return`
  evaluated**: a `finally` that rebinds the local it came from changes
  nothing the caller gets.
- **A closure keeps what it captures**, a bound method its receiver, a
  generator's frame its locals, and a `for` loop the iterable it was given,
  each until it goes. A loop that `break` leaves gives up its iterator
  there.
- **Freeing an object frees what only it holds**: its `__del__` runs first,
  then the same for each value it holds, in their order and depth first.
  For a tree, that is each node before its children.
- **What is still live when the program ends is not freed** and its
  `__del__` does not run.

```jac
obj Res {
    has n: int = 0;

    def __del__ {
        print("  drop", self.n);
    }
}

def main {
    a = Res(n=1);
    print("using", a.n);
    b = Res(n=2);
    r = Res(n=3);
    r = Res(n=4);
    print("rebound", r.n);
    xs = [Res(n=5), Res(n=6)];
    xs.pop();
    print("popped", len(xs));
}

with entry {
    main();
    print("returned");
}
```

```output
using 1
  drop 1
  drop 2
  drop 3
rebound 4
  drop 4
  drop 6
popped 1
  drop 5
returned
```

`a` is freed after its last use, `b` as soon as it is made, `r`'s first
value when `r` is rebound and its second after its last use, and the popped
item as soon as `pop()` gives it. `__del__` runs as its object is freed. A
`__del__` that stores `self` somewhere reachable keeps the object alive.

`__del__` runs once for an object. When the last reference to an object its
`__del__` kept alive goes, the object is freed and `__del__` does not run
again:

```jac
obj Riser {
    has n: int = 0;

    def __del__ {
        print("  finalize", self.n);
        keep.held = self;
    }
}

obj Keep {
    has held: Riser | None = None;
}

glob keep: Keep = Keep();

def rise {
    r = Riser(n=7);
    print("made", r.n);
}

with entry {
    rise();
    print("kept", keep.held is not None);
    keep.held = None;
    print("cleared");
}
```

```output
made 7
  finalize 7
kept True
cleared
```

An exception that escapes `__del__` does not reach the code whose release
freed the object: the runtime prints `Exception ignored in drop: ` and the
exception's `repr` (`ValueError('bad')`) to stderr, and the program goes on.

## Cycles

Objects that refer to each other keep each other's counts above zero, so
counting alone never frees a cycle.

- **Under `managed`, a cycle collector frees cycles** that nothing else
  reaches. It runs on its own once enough possible cycles wait, and
  `__rc_collect_cycles()` runs it at once. The order of `__del__` calls
  within one cycle is unspecified.
- **Under `rc`, cycles leak**, unless the program breaks them, for example
  by setting a field to `None`.
- **`JAC_GC=off`** in the environment of a `managed` program stops the
  collector from running on its own; `__rc_collect_cycles()` still runs it.
  `__rc_gc_disable()` and `__rc_gc_enable()` do the same from the program.

A value of a type no cycle can pass through (a number, a string, a
container of those, a class whose fields are of such types) is never
considered by the collector.

```jac
obj Res {
    has n: int = 0,
        other: Res | None = None;

    def __del__ {
        print("  drop", self.n);
    }
}

def cycle {
    x = Res(n=10);
    y = Res(n=11, other=x);
    x.other = y;
}

with entry {
    cycle();
    print("cycle made");
    __rc_collect_cycles();
    print("collected");
}
```

```output
cycle made
  drop 11
  drop 10
collected
```

Built with `--memory rc`, the same program prints `cycle made` and
`collected` and nothing else: the two objects are never freed.

### Graphs

An edge holds both its nodes, and each node its edges, so a connected graph
is a cycle. Under `managed` the collector frees it once nothing reaches it.
Under `rc` a program frees it with `del` on its nodes: deleting a node
detaches its edges, and the node is freed if nothing else holds it.

```jac
node Town {
    has v: int = 0;

    def __del__ {
        print("  drop town", self.v);
    }
}

def towns {
    a = Town(v=3);
    b = Town(v=4);
    a ++> b;
    del a;
    print("deleted a");
    del b;
    print("deleted b");
}

with entry {
    towns();
}
```

```output
  drop town 3
deleted a
  drop town 4
deleted b
```

## What del does

`del x` unbinds the name `x` (see [Variables](variables.md)), giving up its
reference: the value is freed if nothing else holds it. `del` of a node also
detaches the node's edges, as above. `del xs[i]` and `del d[k]` give up the
container's reference to the item.

## nogc

Under `nogc` nothing is counted. Every module is held to the
[ownership contract](ownership-contract.md), and each owner frees what it
owns at its last use, at a place the compiler decides. The contract is what
makes that safe: a program that breaks it is refused when it compiles. The
[ownership states](ownership.md) (`own`, `&`, `&mut`, `imm`, `lin`) are
optional under `managed` and `rc`, where they make an owner's drops
deterministic, and required under `nogc`.

## On other hosts

Profiles are native code's. A `cpython` space frees values as CPython does:
by reference counting with its own cycle collector, so a graph of nodes is
freed when that collector runs. A JavaScript host (`node`, `browser`,
`hermes`) frees values by its garbage collector, and never runs `__del__`.
The `__rc_*` functions are native code's: a `cpython` or JavaScript space
refuses them (E1540).

## Differences from Python and the reference design

- In CPython a local lives until its function returns or it is rebound.
  Here a local gives up its value at its last use, so `__del__` may run
  earlier than it would in CPython.
- CPython may run `__del__` of objects still alive when the interpreter
  exits; a native program does not.
- The reference design warns about a profile it does not know, or `enforce` and `exempt`
  patterns under `nogc`; jac refuses them.
