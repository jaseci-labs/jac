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

Assigning an `own` binding elsewhere, or passing it into a function call, a `return`, or a field, **moves** the value. After a move the source binding is considered dead; reading it again is a use-after-move ([`E1301`](../diagnostics.md#ownership-borrow-errors)). Reassigning the binding revives it. Read-only builtin methods (`find`, `startswith`, `split`, `join`, `replace`, `get`, `write`, ...) and native stdlib calls (`os`/`sys`/`time`/`math`/`random`/`struct`) are the exception: they borrow their owned receivers and arguments, so `i = hay.find(pat)` leaves both `hay` and `pat` live, and a str slice (`piece = hay[0:2]`) is a fresh copy that does not consume `hay`:

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

**Own-typed fields are not the membrane.** A field declared `has ref: own Buffer` keeps its value in the owned world, owned by the parent object: storing into it still consumes the source binding (it is a move, `E1301` applies to later reads), but under [nogc enforcement](native-pathway.md#zero-rc-ownership-compilation) it is *not* an `E1402` seal -- the parent frees the field at its own drop point, and overwriting the field drops the old value first, at the same program points under every gc mode. Only stores into *unannotated* fields (and subscripts, graph objects, or module `glob` state) cross the membrane into managed storage. This is what lets ownership extend from stack frames into heap aggregates: an owned struct of owned fields is a single ownership tree with one statically placed drop for the whole shape.

Under headerless codegen (`--enforce-nogc --gc none`) the backend goes further and **flattens** own-typed fields of concrete, acyclic, non-OSP archetypes inline into the parent's allocation: the parent's LLVM struct embeds the field by value (no pointer slot, no separate `malloc`), a store copies the payload in and frees the source shell, reads yield the interior address, and the parent's drop tears the field down in place. Managed modes keep pointer fields; program output is identical either way.

The same rule decides the element layout of an owned list, and it is a decision about the **element type**, never about the annotation. A `list[T]` in a nogc-enforced module stores its elements inline when `T` is a closed-world leaf archetype (no archetype anywhere in the program derives from it), is not an OSP archetype, and has no heap-typed slots of its own; otherwise the list stores pointers. Because the type system erases `own`, `list[own T]` and `list[T]` are one type and lower to one layout, so a `&list[T]` parameter, a generic body instantiated at `T`, and a borrow return all agree with their caller. Subclass instances therefore never lose fields in a base-typed list, and `pop()`, `pop(i)`, `insert`, `del xs[i]`, and `extend` move payloads by value: `pop` reboxes the element into a fresh allocation the receiver owns, the tail shifts with one `memmove`, and `extend` from another owned list moves its elements in and retires the consumed source. `remove(x)` is not lowered for by-value elements, since identity equality has no meaning there.

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

Borrows split at field granularity: a borrow of exactly one field (`&p.name`, `&mut p.left`) records a loan on that field alone, so borrows and writes touching provably disjoint fields of one owner coexist:

```jac
obj Player { has name: str = "", score: int = 0; }

def use_name(x: str) {}

with entry {
    p: own Player = Player();
    v: &str = &p.name;
    p.score = 1;      # OK: disjoint field -- `v` only borrows `p.name`
    use_name(v);
}
```

Writing the *same* field (`p.name = ...`) or borrowing the whole object (`&p`) still conflicts, and anything deeper than one attribute level (`&p.left.n`) or through a subscript conservatively borrows the whole object. A field borrow also still pins the whole owner for destruction, escape, and sendability checks.

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

## Moving out of places: `take` and `swap`

An owned slot inside another value -- an own field, an optional own field, an element of an owned list -- is owned by that value. Reading it into an *owning* destination (an `own` binding, an own field, an `own` parameter, or an owned return) would leave two owners of one payload, so the checker rejects it: [`E1316`](../diagnostics.md#ownership-borrow-errors) for a field, [`E1317`](../diagnostics.md#ownership-borrow-errors) for a list element. Reading the same place into a borrow is always fine.

Two builtins are the sanctioned exits. `take(place)` moves the value out of an optional owned place and leaves `None` behind, which is what every linked structure is made of; `swap(&mut a, &mut b)` exchanges two places of one type in place, without a temporary that would have to own one of them. Both are ordinary calls, per the rule that the exit from a state is a call, and both lower on every backend (a read-then-clear on Python, a load-then-store on native):

```jac
obj Node { has v: int = 0, next: own Node | None = None; }
obj List { has head: own Node | None = None; }

def push_front(l: &mut List, v: int) {
    l.head = Node(v=v, next=take(l.head));   # take moves the old head out
}

def reverse(l: &mut List) {
    prev: own Node | None = None;
    cur: own Node | None = take(l.head);
    while cur is not None {
        nxt = take(cur.next);
        cur.next = prev;
        prev = cur;
        cur = nxt;
    }
    l.head = prev;
}

def exchange(a: &mut List, b: &mut List) { swap(&mut a.head, &mut b.head); }
```

List elements are moved out with `pop()` or `pop(i)`, which hand the element to the receiver; `take` and `swap` address locals and attributes.

## Receiver modes

A method reads, writes, or consumes its receiver, and the checker knows which. The mode is **inferred from the body**: a method that assigns a field of `self`, grows or mutates a container field of `self` (`append`, `insert`, `pop`, `remove`, `clear`, `extend`, `update`, `sort`, ...), takes `&mut self`, or calls another method that mutates `self` is `&mut self`; every other method is `&self`. Methods that call each other resolve to the least mode consistent with their bodies, so a cycle of read-only methods stays `&self`. The inferred mode is stamped on the method as a fact editors can show.

The **explicit form** reuses the typed `self` parameter the grammar already accepts. Writing `self` in an `obj`, `node`, `edge`, or `walker` method is admitted only to declare a mode: `self: own T` consumes the receiver, `self: &mut T` and `self: &T` pin the inferred modes. A consuming receiver cannot be inferred from intent, which is why it is the one worth writing:

```jac
obj Counter {
    has n: int = 0;

    def inc { self.n += 1; }                                    # inferred &mut self
    def get -> int { return self.n; }                           # inferred &self
    def into_total(self: own Counter) -> int { return self.n; } # consumes
}

def run -> int {
    c: own Counter = Counter();
    v = &c;
    c.inc();              # error[E1303]: cannot mutate 'c' while a shared borrow of it is live
    total = c.into_total();
    return c.get();       # error[E1301]: use of 'c' after it was moved
}
```

A mutating call is a write: [`E1303`](../diagnostics.md#ownership-borrow-errors) while a shared borrow of the receiver is live, [`E1309`](../diagnostics.md#ownership-borrow-errors) on an `imm` binding, and [`E1318`](../diagnostics.md#ownership-borrow-errors) when the call goes through a shared `&` borrow (take the borrow with `&mut`, or call on the owner). A `self: own` call moves the receiver exactly like passing it to an `own` parameter: the binding is dead afterwards, and under headerless codegen the method owns and drops it.

## Views and zero-copy: current state and direction

Two pieces of the immutable-view design (#7857 Phase C) are live today: a function may return a borrow it received as a parameter (the passthrough rule above -- the single-input case of Rust's lifetime elision, with no lifetime syntax), and `str` slices never consume their source. Slices are currently *owned copies* on every backend: the native string representation is a NUL-terminated buffer whose length-carrying variant (a fat `(data, len)` pointer that `print`, `len`, and the str runtime all honor) is the prerequisite for representing a mid-string view, so zero-copy slices of `imm`/borrowed receivers are deliberately fenced until that representation lands. The semantic direction is fixed and documented here so the fence is a representation gap, not a design gap: views of deep-frozen data need only extent-keeping (RC on the managed floor, owner-outlives under enforcement), never a named lifetime.

Ownership states also compose through higher-order signatures: `Callable[[own Buffer], None]` declares that the callable consumes its argument, and passing an owned binding through such a call consumes it under the ordinary rules.

## Affine walkers

A walker bound `own` is use-once computation: `spawn` moves it into the traversal, so a second spawn of the same binding is `E1301` and double-accumulation bugs become compile errors instead of subtle state carryover:

```jac
node Spot { has v: int = 0; }

walker Visitor {
    has total: int = 0;

    can tally with Spot entry {
        self.total += here.v;
    }
}

with entry {
    s = Spot(v=5);
    w: own Visitor = Visitor();
    res = w spawn s;      # `w` moves into the traversal
    print(res.total);
    # res2 = w spawn s;   # error[E1301]: use of 'w' after it was moved
}
```

Unannotated walkers keep the managed reuse semantics unchanged.

## The `imm` operator: promoting into the immutable world

The ownership surface follows one rule: **states are annotations, transitions are operators, and the exit is a call.** `own`/`imm`/`&`/`&mut` describe bindings; the prefix operators `&x`, `&mut x`, `own x` (the region rebox), and `imm x` perform transitions within the checked world; `managed(x)` is the single, loud way out of it.

`imm x` is the freeze transition: it moves a value across the membrane into the deep-immutable world. Its operand must be **statically unique** -- an `own` binding (which the operator consumes, `E1301` afterwards) or a fresh expression -- so no other handle can ever write the frozen value. That proof is what makes the operator erase to its operand on every backend:

```jac
obj Buffer { has n: int = 0; }

with entry {
    a: own Buffer = Buffer(n=7);
    d = imm a;        # `a` is consumed; `d` binds as deep-immutable (no annotation needed)
    print(d.n);       # reads fine; `d.n = 9` would be E1309
}
```

The binding infers `imm` from the operator, so `cfg = imm load_config();` is the whole idiom. Freezing a possibly-aliased managed binding is rejected ([`E1311`](../diagnostics.md#ownership-borrow-errors)) -- copy the value first or take ownership of it. The frozen result is the natural payload for `flow` boundaries: `imm` values cross freely under the sendability rule. This composes with regions: `fr = imm r` consumes the owned handle and transfers handle-ness, so one frozen subgraph can be shared with any number of parallel readers -- statically race-free from two existing rules -- while opening the frozen handle for allocation is `E1309` and reopening the consumed source is `E1301`.

## Reference-yielding loops

`for x in &xs` iterates shared per-element borrows of an owned container and `for m in &mut xs` iterates exclusive ones. The loop is lowered as an index loop -- no reified iterator object ever holds a borrow, so the loop itself is the borrow's extent, and no lifetime is needed to name it:

```jac
obj Res { has tag: int = 0; }

def work -> int {
    xs: own list[Res] = [];
    xs.append(Res(tag=1));
    t = 0;
    for x in &xs {
        t = t + x.tag;      # read through a shared element borrow
    }
    for m in &mut xs {
        m.tag = m.tag * 2;  # mutate in place through an exclusive borrow
    }
    return t + len(xs);     # owner fully usable after each loop
}
```

The loop variable is checked as a borrow of the iterated owner: storing it into a field or otherwise escaping the loop is `E1306`. Element mutation through the `&mut` form is visible after the loop at identical program points under every gc mode, including enforced headerless builds.

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
region is *opened* for allocation with the `in <handle> { ... }` statement.
The open has **dynamic, thread-scoped extent**: every archetype, node, and
edge constructed while the open is active on the current thread lives in
that region -- including allocations made inside helpers the open calls --
and is reclaimed wholesale when the handle drops. On the native backend a
bump-allocating arena is torn down with one dtor-log walk (LIFO) plus a bulk
free at the handle's static drop point; on the Python backend memory stays
GC-managed but `drop` hooks fire at the same points. `in Region() { ... }`
opens an anonymous region whose extent is exactly the block. A thread starts
with no current region, so a `flow`/`thread_run` body allocates on the
managed heap unless it opens a handle it was sent. `managed(T(...))`
constructs on the managed heap regardless of the current region: it is the
allocation-side exit, for bookkeeping that must outlive any open.

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
  Because extent is dynamic, the heap-typed result of a call made under
  the open is region-rooted too, unless the call receives the handle (the
  carrier idiom below); constructors and non-retaining builtins such as
  `print` and `len` are exempt.
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
caller at scope exit. A walker traversing a region *grows* it by the same
rule: ability dispatch makes `region_of(here)` the current region for the
ability body, so a node or edge created mid-traversal allocates into the
visited node's region with no `&Region` field on the walker; anchored to a
managed node it stays managed. `region_of(x)` is a builtin: the region a
value was allocated in, or `None` for a managed value.

```jac
def seed(r: &Region) -> Cand {
    in r {
        x = Cand();
        return x;        # ok: single-region elision ties x to r
    }
}
```

### Connect-as-seal: promoting a subgraph into the managed world

Root is to graphs what sealing is to values: the far side of the membrane.
Attaching region topology to a managed node -- a *directed* connect from a
managed anchor into a region-local node, under an open on an **owned
named** handle -- is therefore not an escape but the membrane **seal for
subgraphs**. It consumes the handle's ownership and promotes the topology:
the arena pages stay live, teardown never runs, `drop` hooks never fire
(managed graph nodes are immortal, and the promoted ones behave
identically), and the subgraph is traversable from the anchor after the
open closes.

```jac
with entry {
    anchor = City();
    r: own Region = Region();
    in r {
        a = City(name="a");
        b = City(name="b");
        a ++> b;
        anchor ++> a;    # the seal: consumes `r`, promotes {a, b} and their edges
    }
}
# `r` is dead here (E1301 on reuse); the graph lives on under `anchor`
```

The seal closes the region for graph operations: instantiating an
archetype or wiring a connect after it inside the open is
[`E1307`](../diagnostics.md#ownership-borrow-errors). And every non-seal
shape keeps the `E1307` rejection: a region edge wired *out* to a managed
node, undirected wiring, a seal attempt inside an anonymous open, or one
through a borrowed `&Region` parameter (consuming what you do not own is
never licensed). Adoption is O(objects) worth of bookkeeping in
principle and zero copies always; in the current runtime it is free --
region-allocated objects already carry region-marked headers whose
releases no-op, so retiring the handle without teardown *is* the
promotion.

### Sub-arenas: `partition()` and reabsorb

`r.partition()` on an owned handle yields a fresh **owned child handle**.
A child is a region in its own right -- open it, allocate under it, move
it across `flow` under the owned-handle sendability rule -- and ownership
of the children is the isolation proof for data-parallel building over
disjoint subgraphs. What makes a child a *sub*-arena is its death: a
child handle dropping **reabsorbs** into the parent -- its memory and its
`drop` log splice into the parent's, so every hook fires exactly once,
at the parent's death, child entries first. A parent dying before its
children defers its entire teardown to the last reabsorb (the runtime
zombie-counts live children), so no code shape can free pages a child
still draws on.

```jac
with entry {
    r: own Region = Region();
    c1: own Region = r.partition();
    c2: own Region = r.partition();
    in c1 { build_left(); }      # or: h = flow build(c1); ... wait h;
    in c2 { build_right(); }
    # c1, c2 drop -> reabsorbed; r drops -> one teardown for everything
}
```

Call `partition()` once per child (`partition(n)` sugar can layer on
later); the per-child bump-pointer page sharing is the regions-lane
allocator work -- the contract here (isolation while live, reabsorb on
death, single teardown) is what that work slots into.

### Inferred anonymous regions for unrooted spawns

A graph that never touches managed state does not need an explicit open to
get region semantics. When a code block builds a graph from fresh node
locals, connects them only among themselves, and consumes it with
expression-statement spawns, `RegionInferPass` proves the component
unrooted (a conservative may-reach-root scan over the connect operations)
and rewrites the extent into a real `in Region() { ... }` open in the tree:
the nodes, their edges, and an inline walker are arena-allocated, `drop`
hooks fire LIFO right after the last spawn, and teardown is one bulk free
-- the ephemeral-OSP fast path at zero annotation.

```jac
with entry {
    a = Item(v=1);
    b = Item(v=2);
    a ++> b;
    Sum() spawn a;    # implicit region closes here: drop 2, drop 1, bulk free
    print("done");
}
```

Any contact with `root` or `here` in the extent, a member passed to a call
or read after the spawn, a spawn whose result is consumed, or control flow
that could jump the close point declines the inference and the graph stays
managed -- conservative-only is the contract, so a declined graph is never
wrong, just unoptimized. Because the inference produces an ordinary open
in the tree, it is portable: the Python backend runs the same `drop` hooks
LIFO at the close. Traversals under `--enforce-nogc` still wait on the
walker engine's zero-RC factoring.

Only payloads that are statically race-free may cross a `flow`/`wait`/`thread_run` boundary: a deep-immutable `imm` value, or an `own` value that is *moved* into the boundary (a planned `linear` value will cross the same way). Sending a live `&`/`&mut` borrow is [`E1308`](../diagnostics.md#ownership-borrow-errors):

**Scoped lending is the exception.** An inline borrow may cross when the checker can see the matching `wait` barrier in the same block before any other use of the owner -- the join is the borrow's extent, and no annotation names it:

```jac
obj Buffer { has n: int = 0; }

def read_it(x: &Buffer) -> int {
    return x.n;
}

with entry {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a);   # lend: the task borrows `a`...
    r = wait h;             # ...and the join ends the lend
    a.n = 7;                # owner fully usable after the barrier
    print(r + a.n);
}
```

The lend is rejected (E1308 stays) when the flow result is not bound and joined in the same block, or when the owner is touched anywhere between the spawn and the `wait` -- the barrier must provably come first.

```jac
obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    flow use1(v);   # error[E1308]: 'a' is not sendable across a concurrency boundary
}
```

## `flow for`: the disjoint-partition loop

The existing `flow` modifier applied to the existing loop -- no new
keyword. `flow for x in &xs { }` declares a parallel read-only map;
`flow for m in &mut xs { }` fans out disjoint exclusive lends, one per
element; the loop's closing brace is the implicit join and the borrow's
extent. The checker enforces the shape that makes that meaning true:

- the collection must be lent (`&xs` or `&mut xs`) so disjointness is
  checkable ([`E1313`](../diagnostics.md#ownership-borrow-errors));
- control flow may not cross the join: `break` out of the body,
  `return`, `disengage`, and `yield` are `E1313`; `continue` (skip one
  element) is fine;
- body captures follow the sendability rule: reads of outer state must
  be scalar/immutable, and any write to an outer name -- an accumulator,
  an outer container -- is
  [`E1308`](../diagnostics.md#ownership-borrow-errors) (write through
  the `&mut` element instead);
- nesting `flow for` is rejected for now, and the element-space loan
  algebra already covers structural mutation of the collection during
  the loop.

```jac
with entry {
    flow for m in &mut ps {
        m.x = m.x * 10;    # disjoint per-element writes: race-free by construction
    }
    # join: every element write is visible here
}
```

Execution: in a **zero-RC enforced native build** (`--enforce-nogc --gc
none`), `flow for` runs genuinely parallel -- the body is outlined and
element ranges fan out over pthreads, joining at the closing brace
(`JAC_FLOW_THREADS` sets the width, default 4). This placement is the
point, not a limitation: an `--assert-no-rc` binary provably contains no
refcount operations and no shared runtime kernel, and the checker bans
every unsound capture, so threads are unconditionally safe --
parallelism arrives exactly where machinery absence is proven. `--gc
rc` builds fan out the same way: retain and release are atomic (the
free decision consumes the atomic RMW's returned old count, so racing
releases cannot double-free or leak), which makes values crossing task
boundaries safe at zero added single-thread cost -- the baseline
already paid the RMW on every retain/release. Measured ~7x on 8
threads for an element-map kernel hammering one shared string's
header. `--gc cycles` keeps the sequential lowering (the cycle
collector's global roots and color state are unsynchronized), as do
the Python backend and wasm, so post-join state is byte-identical
everywhere by the disjointness rule. A named follow-up: the chunked
form (`&mut xs.chunks(n)`), which waits on container views.

Post-join *state* is what the rule pins. Side effects raised from
inside the body -- a `print`, a log line -- are ordered against the
join, never against each other: one region's output all lands before
the next region's, but the interleaving within a region is unspecified
wherever the fan-out is live. Code that needs an ordered stream should
write elements through the `&mut` lend and emit after the join.

### The reduction idiom

An accumulator write in a `flow for` body is E1308 -- except in the
licensed reduction shapes. An outer `int` binding whose *only* uses in
the body are `acc += expr`, `acc = min(acc, expr)`, or `acc = max(acc,
expr)` (one consistent operation per accumulator, `expr` never
mentioning `acc`) is a reduction: each task folds its element range
into a private partial starting from the operation's identity, and the
join combines the partials with the accumulator's pre-loop value. The
result is exactly the sequential fold -- integer `+`, `min`, and `max`
are associative and commutative, so output is byte-identical across gc
modes and any thread width. Any other accumulator shape (the plain
`acc = acc + x` form, a float accumulator, a mid-loop read of the
accumulator, mixed operations) keeps E1308:

```jac
with entry {
    xs = [3, 1, 4, 1, 5];
    total = 0;
    lo = 1000000;
    flow for v in &xs {
        total += v;        # licensed: per-task partial + combine
        lo = min(lo, v);   # licensed
    }
    print(total);          # identical to the sequential fold
}
```

One target is permanently sequential for now: **wasm builds always run
`flow for` as the ordinary loop**. WebAssembly has no threads story in
the toolchain (no wasm-threads/shared-memory atomics in the linker or
the host shims), so the sequential lowering on the wasm triple is the
documented behavior, not a bug -- results are identical by the same
disjointness rule, and parallel fan-out remains a native-host property
until a wasm-threads story exists.

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

The native backend does hand the checked facts to the optimizer: heap-typed parameters in ownership contract positions carry LLVM parameter attributes -- `own` and `&mut` are exclusive (`noalias`), `&` is exclusive-read (`noalias readonly`), and `imm` is deep-frozen (`readonly`, no `noalias` since immutable handles may alias). These attributes never change semantics -- a checked-clean module means they are true by construction -- but they license load hoisting and vectorization the optimizer could not otherwise prove. Unannotated parameters carry nothing.

## See also

- [Ownership Checker Specification](../../internals/ownership-checker-spec.md) -- the authoritative statement of what each `E13xx` code guarantees, the checker's symbol-level granularity, and the facts contract backends consume.
- [Errors and Warnings](../diagnostics.md#ownership-borrow-errors) -- the full `E1301`-`E1309` code table (`E1305` is reserved for the planned `linear` marker and not yet registered).
- [Native Compilation Reference](native-pathway.md#memory-management) -- the emit-time `--gc` modes, zero-RC ownership compilation, and how the native backend proves [reference-count elision](native-pathway.md#reference-count-elision) independently of this checker.
