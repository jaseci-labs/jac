# Ownership & Borrowing

Jac has an opt-in ownership and borrow-checking surface: `own` marks a local or parameter as the unique owner of a value, `&`/`&mut` take a shared or mutable borrow of an owned value, and `OwnershipCheckPass` statically verifies that owned values aren't used after they move and that borrows never outlive or conflict with their owner. Unannotated bindings are completely unaffected -- the checker only tracks names it sees tagged `own` or `borrow`.

This is diagnostics-only: it does not change what code is generated. On the native (`nacompile`/JIT) backend, an owned value that the checker proves is consumed exactly once and never borrowed is marked `is_proven_unique`, which lets the backend skip reference-count traffic for it.

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

(`E1305` is reserved for the optional `linear` resource marker, which does require an explicit move and is not yet implemented.)

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

## See also

- [Errors and Warnings](../diagnostics.md#ownership-borrow-errors) -- the full `E1301`-`E1306` code table.
- [Native Compilation Reference](native-pathway.md) -- how `is_proven_unique` feeds into reference-count elision on the native backend.
