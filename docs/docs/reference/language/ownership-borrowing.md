# Ownership & Borrowing

Jac has an opt-in ownership and borrow-checking surface: `own` marks a local or parameter as the unique owner of a value, `&`/`&mut` take a shared or mutable borrow of an owned value, and `OwnershipCheckPass` statically verifies that owned values aren't used after they move and that borrows never outlive or conflict with their owner. Unannotated bindings are completely unaffected -- the checker only tracks names it sees tagged `own`, `val`, `linear`, or `borrow` (`&`/`&mut`), plus allocations inside a `region` block.

This is strictly diagnostics-only: running the checker can change diagnostics, never generated code. It writes no fact that any backend reads. The native (`nacompile`/JIT) backend still elides reference-count traffic for move assignments, but it proves that itself with a separate, unconditional [`RcElisionProofPass`](native-pathway.md#reference-count-elision) that never consults the checker -- so the elision is identical whether or not the ownership diagnostics ran (`nacompile` compiles with `type_check=False` and skips them entirely).

## Declaring an owner

```jac
obj Buffer { has n: int = 0; }

with entry {
    a: own Buffer = Buffer();
    b = a;       # moves the value out of `a`
    print(a);    # error[E1301]: use of 'a' after it was moved
}
```

Assigning an `own` binding elsewhere, or passing it into a function call, a `return`, or a field, **moves** the value. After a move the source binding is considered dead; reading it again is a use-after-move ([`E1301`](../diagnostics.md#ownership-borrow-errors)). Reassigning the binding revives it:

```jac
with entry {
    a: own Buffer = Buffer();
    b = a;
    a = Buffer();   # `a` is live again
    print(a);       # OK
}
```

Ownership is affine, not linear: an `own` binding that is never moved anywhere before its scope ends is simply dropped and reclaimed by the managed RC/GC floor -- this is not an error:

```jac
with entry {
    f: own File = File();
    print("done");   # OK: `f` is dropped here, no error
}
```

(If you *do* want dropping to be an error, use the [`linear` marker](#val-and-linear-markers) -- a `linear` binding must be consumed exactly once, and leaking it is [`E1305`](../diagnostics.md#ownership-borrow-errors).)

`own` also works on parameters (`def take(x: own Buffer) -> None`), and passing an owned local to a plain (non-`own`) parameter counts as a move.

## Sealing back into managed storage (the membrane)

Storing an owned value into a managed location -- a field, a subscript slot, or any graph object -- **moves** it across the membrane back into ordinary managed (RC/GC) storage. The source `own` binding is consumed, so it may not be read afterwards, and because it was handed off it does not leak:

```jac
obj Buffer { has n: int = 0; }
obj Holder { has ref: Buffer = Buffer(); }

with entry {
    a: own Buffer = Buffer();
    h = Holder();
    h.ref = a;    # `a` is sealed into managed storage -- moved, no leak
    print(a);     # error[E1301]: use of 'a' after it was moved
}
```

Reading `h.ref` back yields an ordinary managed value, not an `own` binding -- there is no way to take an `own`/`&` of a graph node or a managed field. Ownership is a property of the *binding*, and the membrane is one-way: values flow out of `own` into management by moving, and come back only as managed values. (This is why the borrow rules never need to reason about the graph; `node`/`edge`/`walker` stay fully managed.)

## Borrowing

`&` takes a shared (read-only) borrow of an owner; `&mut` takes a mutable borrow. Both are declared with the `borrow` type tag, most commonly written inline as `& expr` / `&mut expr`:

```jac
obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    a.n = 5;      # error[E1303]: cannot mutate 'a' while a shared borrow of it is live
    use1(v);
}
```

The borrow rules mirror Rust: an owner may have any number of live shared borrows, or exactly one live mutable borrow, never both:

```jac
def use2(x: Buffer, y: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    e1: &mut Buffer = &mut a;
    e2: &mut Buffer = &mut a;   # error[E1302]: conflicting mutable borrow of 'a'
    use2(e1, e2);
}
```

A borrow must not outlive the owner it points to -- if the owner's scope ends while the borrow is still live, that's [`E1304`](../diagnostics.md#ownership-borrow-errors):

```jac
with entry {
    v: &Buffer;
    if len("x") > 0 {
        a: own Buffer = Buffer();
        v = &a;   # `a` is destroyed at the end of this `if` block, while `v` still borrows it
    }
    use1(v);      # error[E1304]: 'a' is destroyed while still borrowed
}
```

## Escaping borrows

Borrows are second-class: a `&`/`&mut` value may not be `return`ed, stored into a field or subscript, or otherwise made to outlive the scope that created it ([`E1306`](../diagnostics.md#ownership-borrow-errors)):

```jac
def borrow_and_return() -> Buffer {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    return v;   # error[E1306]: borrow of 'a' escapes its scope
}
```

The one exception is a borrow *parameter* passed straight through and returned -- that's a legitimate passthrough, not an escape, because the borrow's lifetime is bounded by the caller:

```jac
def first(p: &Buffer) -> Buffer {
    return p;   # OK: passthrough of a borrowed parameter
}

with entry {
    a: own Buffer = Buffer();
    r = first(&a);
    take_final(a);
}
```

## `val` and `linear` markers

Two further binding markers refine `own` at either end of the strictness spectrum.

`val` declares a **deep-immutable** value: it may never be reassigned, have a field (or subscript) written through it, or be borrowed `&mut`. Violations are [`E1309`](../diagnostics.md#ownership-borrow-errors):

```jac
obj Buffer { has n: int = 0; }

with entry {
    v: val Buffer = Buffer();
    print(v.n);   # OK: reads are unrestricted
    v.n = 5;      # error[E1309]: cannot mutate 'v' through a deep-immutable `val` binding
}
```

`linear` declares a **must-use** resource: it is move-checked exactly like `own`, but where `own` is affine (dropping is fine), a `linear` binding must be consumed -- moved to its final owner, passed on, or sealed into managed storage -- exactly once before its scope ends. Never consuming it is [`E1305`](../diagnostics.md#ownership-borrow-errors); consuming it twice is the usual use-after-move `E1301`:

<!-- jac-skip -->
```jac
obj File { has fd: int = 0; }

with entry {
    f: linear File = File();
    print("done");   # error[E1305]: linear resource 'f' is never consumed
}
```

## `region` blocks

A `region { ... }` block is an arena scope: everything allocated inside it is owned by the region and conceptually freed all at once at the closing brace. The checker enforces that no reference rooted in the region survives the block -- returning one, storing it outside, or handing it to a concurrency boundary is [`E1307`](../diagnostics.md#ownership-borrow-errors), including when it escapes indirectly through a call:

```jac
obj Buffer { has n: int = 0; }

def wrap(b: Buffer) -> Buffer { return b; }

def make() -> Buffer {
    region {
        x = Buffer();
        return wrap(x);   # error[E1307]: reference to 'x' escapes its `region` block
    }
}
```

To get a value out of a region, move it out with `own` before the block ends.

## Sendability across concurrency boundaries

Only payloads that are statically race-free may cross a `flow`/`wait`/`thread_run` boundary: a deep-immutable `val` value, or an `own`/`linear` value that is *moved* into the boundary. Sending a live `&`/`&mut` borrow, or a `linear` binding without moving it, is [`E1308`](../diagnostics.md#ownership-borrow-errors):

```jac
obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    flow use1(v);   # error[E1308]: 'a' is not sendable across a concurrency boundary
}
```

## What `&x` compiles to

On every backend the ownership annotations are compile-time-only. On the Python backend, `&x` and `&mut x` are **erased**: the expression compiles to exactly `x`, the same object reference an unannotated binding would produce. There is no runtime borrow object, no copy, and no indirection -- the annotation exists solely for `OwnershipCheckPass` to check. (Before the borrow-checker work, a prefix `&x` lowered to the archetype-lookup call `jobj(id=x)`; that legacy meaning is gone -- call `jobj(id=...)` explicitly if you want an id lookup.) The native backend likewise erases borrows; its reference-count optimizations are proven independently by [`RcElisionProofPass`](native-pathway.md#reference-count-elision) and never read the checker's output.

## See also

- [Ownership Checker Specification](ownership-checker-spec.md) -- the authoritative statement of what each `E13xx` code guarantees, the checker's symbol-level granularity, and the diagnostics-only contract.
- [Errors and Warnings](../diagnostics.md#ownership-borrow-errors) -- the full `E1301`-`E1309` code table.
- [Native Compilation Reference](native-pathway.md#reference-count-elision) -- how the native backend proves reference-count elision independently of this checker.
