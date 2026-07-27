# Gradual Borrow Checking

Jac's memory discipline is *gradual borrow checking*: a continuum within one
language rather than a divide between languages. Unannotated code retains
fully managed semantics, ownership annotations introduce affine values with
moves, borrows, deep immutability, and deterministic destruction, adoptable
one declaration at a time, and a closed, checked boundary (the *membrane*,
[below](#sealing-back-into-managed-storage-the-membrane)) mediates every
value that crosses between the two regimes. Adoption strengthens
monotonically, from fully managed code, through annotated declarations,
to [enforced modules and headerless native codegen](native-pathway.md#zero-rc-ownership-compilation)
with no reference counting and no collector in the artifact. The divide
between managed languages and systems languages is a discontinuity like the
others Jac dissolves ([The Two Ideas](../../quick-guide/ideas-behind-jac.md#synechic)),
rendered here as a gradient walked by degrees, never crossed.

Jac has an opt-in ownership and borrow-checking surface: `own` marks a local or parameter as the unique owner of a value, `&`/`&mut` take a shared or mutable borrow of an owned value, and `OwnershipCheckPass` statically verifies that owned values aren't used after they move and that borrows never outlive or conflict with their owner. Unannotated bindings are completely unaffected -- the checker only tracks names it sees tagged `own`, `imm`, or `borrow` (`&`/`&mut`), plus allocations under an `in <handle> {}` region open. (A `linear` must-use marker is planned but not yet implemented -- see below.)

The checker is one of the compiler's required analyses on the native pathway: it always runs there, its error-severity findings (E13xx) block native codegen, and a clean check is what makes the annotations trustworthy facts for lowering. Whether diagnostics are *displayed* is a compile-request property that never changes generated code -- builds with and without display are bit-identical. Reference-count move elision is proven by the core `RcFactsPass` (a backward-liveness proof on the compiler's shared dataflow framework, stamped as `Assignment.na_move_lowerable`), which serves annotated and unannotated code alike. See the [Ownership Fact Schema](../../internals/ownership-checker-spec.md) for the full facts contract.

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

(A planned [`linear` marker](#imm-and-linear-markers) will make dropping an error -- a `linear` binding must be consumed exactly once, and leaking it will be `E1305`. `linear` is not yet implemented.)

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

## `imm` and `linear` markers

Two further binding markers refine `own` at either end of the strictness spectrum.

`imm` declares a **deep-immutable** value: it may never be reassigned, have a field (or subscript) written through it, or be borrowed `&mut`. Violations are [`E1309`](../diagnostics.md#ownership-borrow-errors):

```jac
obj Buffer { has n: int = 0; }

with entry {
    v: imm Buffer = Buffer();
    print(v.n);   # OK: reads are unrestricted
    v.n = 5;      # error[E1309]: cannot mutate 'v' through a deep-immutable `imm` binding
}
```

!!! warning "`linear` is planned, not implemented"
    The `linear` marker described below **does not parse yet** -- there is no
    `linear` keyword, no checker support, and `E1305` is a reserved code that
    is not registered. It is tracked as a follow-up to the ownership-endgame
    plan ([#7453](https://github.com/jaseci-labs/jac/issues/7453)); this
    section documents the intended design.

`linear` will declare a **must-use** resource: move-checked exactly like `own`, but where `own` is affine (dropping is fine), a `linear` binding must be consumed -- moved to its final owner, passed on, or sealed into managed storage -- exactly once before its scope ends. Never consuming it will be `E1305` (reserved); consuming it twice is the usual use-after-move `E1301`:

<!-- jac-skip -->
```jac
obj File { has fd: int = 0; }

with entry {
    f: linear File = File();
    print("done");   # error[E1305]: linear resource 'f' is never consumed
}
```

## Regions: first-class `Region` handles and `in` opens

A **`Region`** is an ownable, sendable, escape-checked allocation extent. A
region is *opened* for allocation with the `in <handle> { ... }` statement:
everything constructed under an open lives in that region and is reclaimed
wholesale when the handle drops -- on the native backend a bump-allocating
arena is torn down with one dtor-log walk (LIFO) plus a bulk free at the
handle's static drop point; on the Python backend memory stays GC-managed
but `drop` hooks fire at the same points. `in Region() { ... }` opens an
anonymous region whose extent is exactly the block.

```jac
def plan() -> int {
    r: own Region = Region();
    total = 0;
    in r {
        a = Spot(v=1);
        b = Spot(v=2);
        a ++> b;                 # cycles and aliasing inside are free
        total = (a spawn Sum()).total;
    }
    return total;                # drop r: dtor log runs, one bulk free
}
```

Inside a region there is **no ownership discipline** -- alias and build
cycles freely. The checker's only job is the boundary:

- A reference rooted in a region may not be returned, stored where it
  outlives the handle, handed to an opaque callee, or sent across a
  `flow`/`wait` boundary: each is [`E1307`](../diagnostics.md#ownership-borrow-errors).
- A region-rooted value that flows to a binding which cannot outlive the
  handle becomes a **shared borrow of the handle**, and ordinary borrow
  discipline polices it from there. Helpers that receive the handle
  (`widen(&r, s)`) are legal carriers of region-rooted values.
- **Single-region elision**: a function with exactly one `&Region`
  parameter may return values rooted in an open of it -- the result is tied
  to that parameter at every call site. Two or more region parameters are
  ambiguous, so such returns stay rejected.
- Scalars copy by value at the boundary, and `own <expr>` **reboxes** a
  scalar or string into a fresh copy that legally exits the region.
- Wiring a region-resident node to managed topology (either direction) is
  rejected: region-internal edges are free, cross-extent edges dangle.
- Moving an `own Region` handle across a `flow` boundary transfers the
  whole subgraph, zero-copy; it is legal only while no borrows of the
  handle exist.

Handles have **dynamic extent**: return one from a helper, extend it
through a `Region`-typed parameter in another function, and drop it in the
caller at scope exit. A walker traversing a region may also *grow* it: a
node or edge created in an ability allocates into the region of the visited
node (`region_of(here)`) with no `&Region` field on the walker; anchored to
a managed node it stays managed.

```jac
def seed(r: &Region) -> Cand {
    in r {
        x = Cand();
        return x;        # ok: single-region elision ties x to r
    }
}
```

## Sendability across concurrency boundaries

Only payloads that are statically race-free may cross a `flow`/`wait`/`thread_run` boundary: a deep-immutable `imm` value, or an `own` value that is *moved* into the boundary (a planned `linear` value will cross the same way). Sending a live `&`/`&mut` borrow is [`E1308`](../diagnostics.md#ownership-borrow-errors):

```jac
obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    flow use1(v);   # error[E1308]: 'a' is not sendable across a concurrency boundary
}
```

## The `drop` hook

An archetype may declare a reserved ability named `drop` (undunderscored, like `postinit`). On the native backend it runs exactly once, when the object is destroyed, and before the object's own fields are torn down:

```jac
obj Res {
    has tag: int = 0;

    def drop {
        print(self.tag);   # runs when this Res is destroyed
    }
}
```

`drop` fires under every native gc mode, at the same program point for a uniquely-owned value:

- **[Enforced headerless modules](native-pathway.md#zero-rc-ownership-compilation)** (`--enforce-nogc --gc none`): the compiler calls the hook from the statically inserted `__drop_<T>` at each drop point.
- **Managed modes** (`rc` and the default `cycles`): the hook is invoked by the object's reference-count destructor when the last reference dies. For an unaliased local that is the same point the headerless build drops at, so program output is identical across modes.

**Drops happen after last use, and no later than scope exit.** Drops are scheduled by liveness: a binding whose value the program will never read again can be reclaimed early -- a value whose last use is its own initialization is dropped right away, before later statements run. This eager case is observable through `drop`:

```jac
def run {
    r: own Res = Res(tag=7);
    print("alive");
}
# prints 7, then "alive" -- r's last use is its declaration, so it drops first
```

The current native backend does not yet place every drop at the *statement* granularity a full non-lexical-lifetime scheme would: a binding that is read partway through a frame is observed to drop at frame exit rather than immediately after that last read. Rely on the guarantee the compiler actually provides today -- a uniquely-owned value drops after its last use and no later than scope exit, at the same program point under every native gc mode -- rather than on exact statement-level timing.

Two caveats:

- Under `cycles`, objects that die as members of a reference cycle are destroyed by the collector; each member's `drop` still runs, but the order within the cycle is unspecified and sibling objects may already be gone -- don't traverse other heap objects from a cyclic `drop`.
- There is no resurrection: `drop` must not store `self` anywhere; the object is freed as soon as the hook returns.

Outside regions, the Python backend does not invoke `def drop` automatically yet -- rely on it only in native modules. Values allocated under an [`in <handle> { }` open](#regions-first-class-region-handles-and-in-opens) are the exception: their hooks fire at portable points on both backends -- LIFO at the closing brace for an anonymous open, at the handle's death for a named one. (Named-handle timing on the Python backend rides CPython reference death, which approximates but does not exactly equal the native static drop point; the anonymous case is exactly portable.)

## Zero-RC native builds

On the native backend, full ownership coverage is what lets the memory-management runtime disappear from the artifact entirely. A **nogc-enforced** module (`jac nacompile --enforce-nogc`, or `jac.toml [gc.enforce]` patterns) must keep every heap-typed contract position -- parameter, return type, `has` field -- in the owned world, with violations reported as hard [`E1401`-`E1406`](../diagnostics.md#zero-rc-enforcement-errors) errors that block codegen. Compiled with `--gc none`, such a module gets **headerless owned codegen**: allocations and frees at statically determined points (a bare `malloc` at construction, a direct `__drop_<T>` call after last use), no reference counting, and no collector -- and `jac nacompile --assert-no-rc` fails the build if the emitted IR contains any RC/collector machinery, making the absence checkable in the binary. Heap values leave an enforced module only through the explicit `managed(...)` membrane builtin. The full model -- gc modes, the enforcement contract, and the `rc-stats` coverage report -- lives in [Zero-RC ownership compilation](native-pathway.md#zero-rc-ownership-compilation).

## What `&x` compiles to

On every backend the ownership annotations are compile-time-only. On the Python backend, `&x` and `&mut x` are **erased**: the expression compiles to exactly `x`, the same object reference an unannotated binding would produce. There is no runtime borrow object, no copy, and no indirection -- the annotation exists solely for `OwnershipCheckPass` to check. (Before the borrow-checker work, a prefix `&x` lowered to the archetype-lookup call `jobj(id=x)`; that legacy meaning is gone -- call `jobj(id=...)` explicitly if you want an id lookup.) The native backend likewise erases borrows; its reference-count optimizations consume the core-stamped move-elision and param-rebinding facts (`RcFactsPass`), computed once on the shared dataflow framework.

## See also

- [Ownership Checker Specification](../../internals/ownership-checker-spec.md) -- the authoritative statement of what each `E13xx` code guarantees, the checker's symbol-level granularity, and the facts contract backends consume.
- [Errors and Warnings](../diagnostics.md#ownership-borrow-errors) -- the full `E1301`-`E1309` code table (`E1305` is reserved for the planned `linear` marker and not yet registered).
- [Native Compilation Reference](native-pathway.md#memory-management) -- the emit-time `--gc` modes, zero-RC ownership compilation, and how the native backend proves [reference-count elision](native-pathway.md#reference-count-elision) independently of this checker.
