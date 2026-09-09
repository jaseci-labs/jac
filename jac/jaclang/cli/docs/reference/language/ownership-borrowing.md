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

Jac has an opt-in ownership and borrow-checking surface: `own` marks a local or parameter as the unique owner of a value, `&`/`&mut` take a shared or mutable borrow of an owned value, and `OwnershipCheckPass` statically verifies that owned values aren't used after they move and that borrows never outlive or conflict with their owner. Managed code adopts contracts gradually. The checker follows explicit states and their derived moves, borrows, and views, plus allocations under a region open. `lin` adds an exactly-once consumption requirement; see the marker section below. Under nogc enforcement, local states are also inferred from expressions.

The checker is one of the compiler's required analyses on the native pathway: it always runs there, its error-severity findings (E13xx) block native codegen, and a clean check is what makes the annotations trustworthy facts for lowering. Whether diagnostics are *displayed* is a compile-request property that never changes generated code -- builds with and without display are bit-identical. Reference-count move elision is proven by the core `RcFactsPass` (a backward-liveness proof on the compiler's shared dataflow framework, stamped as `Assignment.na_move_lowerable`), which serves annotated and unannotated code alike. See the [Ownership Fact Schema](../../internals/ownership-checker-spec.md) for the full facts contract.

## Feature map

| Task | Language mechanisms | Read next |
|---|---|---|
| Own and transfer state | `own`, owned fields, generic containers, consuming returns/callbacks | [Owners](#declaring-an-owner), [containers](#containers-take-ownership) |
| Borrow state safely | `&`, `&mut`, field splitting, inferred/explicit receivers, local views and borrowed results | [Borrowing](#borrowing), [receivers](#receiver-modes), [views](#views-and-zero-copy-current-state-and-direction) |
| Update ownership in place | Optional `take`, same-typed `swap`, container `pop` | [Places](#moving-out-of-places-take-and-swap) |
| Require consumption or prevent writes | `lin`, `imm` annotations, `imm` freeze operator | [Markers](#imm-and-lin-markers), [freezing](#the-imm-operator-promoting-into-the-immutable-world) |
| Scope allocation and graph lifetime | Named/anonymous Region, `in`, `region_of`, elision, reboxing, seal, partition/reabsorb, inferred regions | [Regions](#regions-first-class-region-handles-and-in-opens) |
| Traverse or parallelize borrowed data | Reference loops, affine walkers, moved/frozen payloads, join-bounded lends, `flow for`, chunks, reductions | [Reference loops](#reference-yielding-loops), [walkers](#affine-walkers), [parallel loops](#flow-for-the-disjoint-partition-loop) |
| Control cleanup and memory policy | `drop`, local inference, exception cleanup, managed/RC/nogc profiles | [Cleanup](#the-drop-hook), [inference](#local-inference-under-enforcement), [errors](#errors-without-unwinding), [zero-RC](#zero-rc-native-builds) |

The checker is gradual and conservative, not a proof of arbitrary aliases hidden in managed storage or opaque foreign handles. Shared views prevent mutation through checked loans; an `imm` annotation alone cannot prevent writes through a separately obtained managed alias. Use the freeze operator when uniqueness is needed. See the [checker contract](../../internals/ownership-checker-spec.md) for analysis boundaries.

## Declaring an owner

```jac
obj Buffer { has n: int = 0; }

with entry {
    a: own Buffer = Buffer();
    b = a;       # moves the value out of `a`
    print(a);    # error[E1301]: use of 'a' after it was moved
}
```

Assigning an `own` binding to another owner, passing it to a consuming parameter, returning it as owned, or storing it in an owned field **moves** the value. Borrow parameters lend it instead. After a move the source binding is considered dead; reading it again is a use-after-move ([`E1301`](../diagnostics.md#ownership-borrow-errors)). Reassigning the binding revives it. Read-only builtin methods (`find`, `startswith`, `split`, `join`, `replace`, `get`, `write`, ...) and native stdlib calls (`os`/`sys`/`time`/`math`/`random`/`struct`) are the exception: they borrow their owned receivers and arguments, so `i = hay.find(pat)` leaves both `hay` and `pat` live, and a str slice (`piece = hay[0:2]`) does not consume `hay` (under enforcement a step-free slice carries a view dependency):

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

The [`lin` marker](#imm-and-lin-markers) requires consumption on every path before scope exit (`E1305`). The keyword is `lin`; `linear` describes the discipline, not a keyword.

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

Reading `h.ref` back yields an ordinary managed value, not an `own` binding -- there is no way to take an `own`/`&` of a graph node or a managed field. Ownership is a property of the *binding*, and the membrane is one-way: values flow out of `own` into management by moving, and come back only as managed values. Graph topology uses managed or region lifetimes; separately, an `own` walker is consumed by spawn, as described below.

**Own-typed fields are not the membrane.** A field declared `has ref: own Buffer` keeps its value in the owned world, owned by the parent object: storing into it still consumes the source binding (it is a move, `E1301` applies to later reads), but under [nogc enforcement](native-pathway.md#zero-rc-ownership-compilation) it is *not* an `E1402` seal -- the parent frees the field at its own drop point, and overwriting the field drops the old value first, at the same program points under every gc mode. Stores into ordinary managed fields, containers, graph objects, or module state cross the membrane; stores into ownership-qualified fields and container elements preserve the owned contract. This is what lets ownership extend from stack frames into heap aggregates: an owned struct of owned fields is a single ownership tree with one statically placed drop for the whole shape.

Under headerless codegen (`--memory nogc`) the backend goes further and **flattens** own-typed fields of concrete, acyclic, non-OSP archetypes inline into the parent's allocation: the parent's LLVM struct embeds the field by value (no pointer slot, no separate `malloc`), a store copies the payload in and frees the source shell, reads yield the interior address, and the parent's drop tears the field down in place. Managed modes keep pointer fields; program output is identical either way.

The same rule decides the element layout of an owned list, and it is a decision about the **element type**, never about the annotation. A `list[T]` in a nogc-enforced module stores its elements inline when `T` is a closed-world leaf archetype (no archetype anywhere in the program derives from it), is not an OSP archetype, and has no heap-typed slots of its own; otherwise the list stores pointers. Because the type system erases `own`, `list[own T]` and `list[T]` are one type and lower to one layout, so a `&list[T]` parameter, a generic body instantiated at `T`, and a borrow return all agree with their caller. Subclass instances therefore never lose fields in a base-typed list, and `pop()`, `pop(i)`, `insert`, `del xs[i]`, and `extend` move payloads by value: `pop` reboxes the element into a fresh allocation the receiver owns, the tail shifts with one `memmove`, and `extend` from another owned list moves its elements in and retires the consumed source. `remove(x)` is not lowered for by-value elements, since identity equality has no meaning there.

## Borrowing

`&` takes a shared (read-only) borrow of an owner; `&mut` takes a mutable borrow. Use `&T` / `&mut T` in type positions and `&x` / `&mut x` in expressions. Keep `&` adjacent to the operand for a shared borrow: spaced `& expr` and parenthesized `&(expr)` are the legacy graph UUID lookup forms, not ownership borrows:

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

Borrows cannot escape their owners: a `&`/`&mut` value may not be returned from a local owner or stored into longer-lived storage. Borrow-containing local views and borrowed-parameter returns follow the rules below; other escapes are rejected ([`E1306`](../diagnostics.md#ownership-borrow-errors)):

```jac
def borrow_and_return() -> Buffer {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    return v;   # error[E1306]: borrow of 'a' escapes its scope
}
```

A borrow *parameter* may be passed straight through and returned -- that's a legitimate passthrough, not an escape, because the borrow's lifetime is bounded by the caller:

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

List elements are moved out with `pop()` or `pop(i)`, which hand the element to the receiver; `take` and `swap` address locals and attributes. `take` requires optional storage, and `swap` requires two explicit mutable borrows with the same storage type; invalid places are E1319. Each field receiver is evaluated once, from left to right. `swap` returns `None`.

### Containers take ownership

A container store is a move. Appending or inserting a named `own` archetype binding into a list, storing one as a dict value (by subscript or in a literal), or placing one in a list literal moves it into the container, which drops it with its other elements; the source binding is consumed, so a later read is `E1301`. Strings are the exception: a named owned `str` is copied in and stays live. Taking an element back out (`pop()`, or a dict `pop(key)`) hands ownership to the receiver; overwriting a dict value or `del` on a key drops the old value at that point.

```jac
obj Box { has tag: int = 0; def drop { print("drop", self.tag); } }

def run -> int {
    xs: list[own Box] = [];
    b: own Box = Box(tag=1);
    xs.append(b);                 # b is moved; `b.tag` here would be E1301
    d: dict[str, own Box] = {};
    d["k"] = Box(tag=2);
    d["k"] = Box(tag=3);          # prints "drop 2"
    got: own Box = d.pop("k");    # the receiver now owns tag 3
    return xs[0].tag + got.tag;   # xs drops tag 1; got drops tag 3
}
```

Sets of archetypes stay outside this rule (they hash by identity), and a borrowed value or a field read cannot enter a container; both remain `E1406` under enforcement.

## Receiver modes

A method reads, writes, or consumes its receiver, and the checker knows which. The mode is **inferred from the body**: a method that assigns a field of `self`, grows or mutates a container field of `self` (`append`, `insert`, `pop`, `remove`, `clear`, `extend`, `update`, `sort`, ...), takes `&mut self`, uses `take` on a field, or calls another method that mutates `self` or one of its fields is `&mut self`; every other method is `&self`. Methods that call each other resolve to the least mode consistent with their bodies, so a cycle of read-only methods stays `&self`. The inferred mode is stamped on the method as a fact editors can show.

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

A mutating call is a write: [`E1303`](../diagnostics.md#ownership-borrow-errors) while a shared borrow of the receiver is live, [`E1309`](../diagnostics.md#ownership-borrow-errors) on an `imm` binding, and [`E1318`](../diagnostics.md#ownership-borrow-errors) when the call goes through a shared `&` borrow (take the borrow with `&mut`, or call on the owner). The builtin container mutators (`append`, `insert`, `pop`, `remove`, `clear`, `extend`, `update`, `sort`, ...) are `&mut self` methods under the same rule, so `c.tags.append(1)` through `c: &Cfg`, or through a local that borrowed `c.tags`, is `E1318` as well. A `self: own` call moves the receiver exactly like passing it to an `own` parameter: the binding is dead afterwards, and under headerless codegen the method owns and drops it.

## Views and zero-copy: current state and direction

A view carries a borrow rather than owning its referent. This includes objects with `&`/`&mut` fields, inherited or nested borrow-containing types, containers declared over borrowed elements, and step-free string slices under nogc enforcement. A local view may collect several loans:

```jac
obj Position { has x: float = 0.0; }
obj RenderView { has position: &Position; }

def draw(p: &Position) -> float {
    view = RenderView(position=p);
    return view.position.x;
}
```

The view keeps its owners borrowed through its last use. It may not be bound `own`, stored in a field, container, or module global, or sent across `flow`. Returning a view is allowed when its borrow roots derive from the function's borrowed parameters or a method's receiver; the result retains those dependencies at the call site. A view over a local owner cannot be returned. Borrow containment is checked through inheritance and generic type arguments, so wrapping a view does not erase its lifetime (`E1315`, sometimes alongside `E1306`). Materialize a fresh owned value when data must escape.

Under nogc enforcement, a step-free string slice `s[a:b]` is treated as a view for lifetime checking. An explicit stepped slice `s[a:b:1]` materializes an owned string when independence is needed. Neither consumes the source. The native backend emits zero-copy data/length descriptors for eligible step-free slices: managed profiles retain the root, while headerless builds rely on the proven owner lifetime. Explicit stepped slices take the materialization path. Python and JavaScript can copy substrings; the borrow contract does not promise zero-copy execution on those backends.

Ownership states also compose through generic and higher-order signatures: `def remove_at[T](items: &mut list[own T], i: int)` borrows a container of owned elements, and `Callable[[own Buffer], None]` declares a consuming callback argument. Calling through that signature consumes the argument under the same move rules as a direct call.

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

Do not structurally mutate the borrowed container during the loop: append, pop, clear, and similar operations conflict with the element loan. The owner is reusable after the loop.

The loop variable is checked as a borrow of the iterated owner: storing it into a field or otherwise escaping the loop is `E1306`. Element mutation through the `&mut` form is visible after the loop at identical program points under every gc mode, including enforced headerless builds.

## `imm` and `lin` markers

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

`lin` declares a **must-consume** resource. A `lin` binding is an `own` binding in every other respect (it moves, it borrows, it drops, and it lowers identically on every backend), but where `own` is affine (dropping an unconsumed value is fine), a `lin` binding must be consumed on every path before its scope ends: passed to an `own` parameter, stored in an owned place, or returned. A path that lets it go out of scope unconsumed is [`E1305`](../diagnostics.md#ownership-borrow-errors); consuming it twice is the usual use-after-move `E1301`. `lin` is accepted wherever `own` is, and the must-consume check covers locals and parameters:

<!-- jac-skip -->
```jac
obj File { has fd: int = 0; def drop { close_fd(self.fd); } }

def finish(f: own File) -> None { print("closing", f.fd); }

def run(flag: bool) -> None {
    f: lin File = File(fd=3);
    if flag {
        finish(f);
    }                 # error[E1305]: Linear binding 'f' is never consumed (the `flag == False` path)
}

def ok -> None {
    g: lin File = File(fd=4);
    finish(g);        # consumed exactly once: clean
}
```

The check is a must-analysis over the control-flow graph: a `lin` value consumed inside a loop body or on one arm of a branch is not consumed on the paths that skip it, so those paths report. Pair `lin` with a [`drop` hook](#the-drop-hook) when the resource must be released explicitly rather than by falling out of scope.

## Local inference under enforcement

Under nogc enforcement, heap-typed contract positions (parameters, returns, and fields) need ownership states such as `own`, `&`, `&mut`, `imm`, or `lin`. Managed code can adopt these contracts gradually. Unmarked locals in enforced modules infer their state:

| Right-hand side | Inferred state |
|---|---|
| a call, constructor, container literal, f-string, concatenation (`a + b`, `s * n`, `fmt % x`) or `own <expr>` copy | `own` |
| a string literal | `imm` (a literal that is later rebound, `s = ""; s = s + x`, is `own`) |
| a field or element read of a place (`c.name`, `xs[i]`, `self.head`) | a borrow of the root: `&mut` when the root is owned or `&mut` and the local is written through, `&` otherwise |
| a step-free string slice `s[a:b]` | view tied to its source |
| an explicit stepped string slice `s[a:b:1]` | owned materialization |
| `&place` / `&mut place` | that borrow |
| another borrow | a reborrow tied to the same owner |
| a conditional whose arms agree | the arms' state |

```jac
obj Cfg { has name: str = "svc", tags: list[int] = []; }

def summarize(c: &Cfg, flag: bool) -> int {        # contract: written
    lit = "a,b,c";                                 # imm str
    cat = "a" + str(1);                            # own str
    label = "y" if flag else "n";                  # imm str
    n = c.name;                                    # &str, borrows c
    t = c.tags;                                    # &list[int], borrows c
    return len(lit) + len(cat) + len(label) + len(n) + len(t);
}

def rename_first(xs: &mut list[Item]) {
    it = xs[0];                                    # &mut Item: the root is &mut and `it` is written through
    it.name = "z";
}
```

A conditional whose arms disagree (`s = "lit" if f else build()`) has no single state and stays [`E1401`](../diagnostics.md#zero-rc-enforcement-errors): write the binding out. An inferred borrow obeys every borrow rule, so mutating through a borrow of a shared root, or returning it as `own`, is rejected the same way an explicit `&` local would be. The inlay hints below show every inferred state.

## Seeing what was inferred

The profile leans on inference, so the editor shows it. The language server publishes inlay hints for every inferred fact: the ownership state of a local that carries no marker (`: own`, `: &`, `: &mut`, `: imm`, `: lin`), a binding that is a view over a borrow (`view`), the receiver mode of a method that names no `self` (`(&self)`, `(&mut self)`, `(own self)`), and the raises effect of a function (`raises ValueError`). The same facts drive the diagnostics, so a hint and an error never disagree.

## Errors without unwinding

Under the nogc profile there is no unwinder, so `raise`, `try`, and `except` keep their syntax and change their lowering. Every function carries an inferred *raises* effect: the exception types it raises itself outside a handling `try`, plus those of the functions it calls without handling them. A raising function returns through a hidden error slot; the caller checks the slot after the call and either dispatches to its own `except` clause, runs its `finally` and propagates, or, with no handler, drops its owned locals at their static points and returns. Nothing about this is written in the source; `jac check` reports the inferred effect through the language server's inlay hints.

An entry block has no caller to propagate to, so a raising call it does not handle is a compile-time error, [`E1407`](../diagnostics.md#ownership-borrow-errors):

```jac
def parse_port(s: &str) -> int {          # raises ValueError
    if len(s) == 0 { raise ValueError("empty port"); }
    return int(s);
}

def load(cfg: &Cfg) -> int {              # raises ValueError, propagated from parse_port
    g: own Guard = Guard();               # dropped on both the value path and the error path
    return parse_port(&cfg.port_text) + 1;
}

def load_or_default(cfg: &Cfg) -> int {   # raises nothing
    try { return load(cfg); } except ValueError { return 8080; }
}

with entry {
    c: own Cfg = Cfg();
    print(load_or_default(&c));           # clean
    print(load(&c));                      # error[E1407]: 'load' raises ValueError, and the entry block does not handle it
}
```

Managed and `rc` builds keep the setjmp-based runtime; the identity contract holds, so a program prints the same output under every profile, including the order of `drop` hooks on the error path.

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
- Cross-extent graph edges are rejected except for the directed managed-anchor-to-region connect-as-seal described below. Region-internal edges are permitted.
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

For a fixed number of children, `(left, right) = r.partition(2)` creates independently owned handles. The count must be an integer literal, the receiver an owned Region, and the result must be immediately unpacked into exactly that many plain names (`E1314` otherwise). Use individual `partition()` calls for dynamic counts. Both forms use the same reabsorption and deferred-parent-teardown rules.

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
LIFO at the close. Traversals under `--memory nogc` still wait on the
walker engine's zero-RC factoring.

Only payloads that are statically race-free may cross a `flow`/`wait`/`thread_run` boundary: a deep-immutable `imm` value, or an `own` value that is *moved* into the boundary (`lin` values transfer under the same move rule). Sending a live `&`/`&mut` borrow is [`E1308`](../diagnostics.md#ownership-borrow-errors):

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
  [`E1308`](../diagnostics.md#ownership-borrow-errors), except the supported integer reductions described below (otherwise write through the `&mut` element);
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

Execution: in a **zero-RC enforced native build** (`--memory nogc`), `flow for` runs genuinely parallel -- the body is outlined and
element ranges fan out over pthreads, joining at the closing brace
(`[native] threads` sets the width, default 4; `JAC_THREADS` overrides it at run time). This placement is the
point, not a limitation: a `nogc` binary provably contains no
refcount operations and no shared runtime kernel, and the checker bans
every unsound capture, so threads are unconditionally safe --
parallelism arrives exactly where machinery absence is proven. `--memory rc` builds fan out the same way: retain and release are atomic (the
free decision consumes the atomic RMW's returned old count, so racing
releases cannot double-free or leak), which makes values crossing task
boundaries safe at zero added single-thread cost -- the baseline
already paid the RMW on every retain/release. Measured ~7x on 8
threads for an element-map kernel hammering one shared string's
header. `--memory managed` keeps the sequential lowering (the cycle
collector's global roots and color state are unsynchronized), as do
the Python backend and wasm, so post-join state is byte-identical
everywhere by the disjointness rule. Chunked loops are also supported; see below.

Post-join *state* is what the rule pins. Side effects raised from
inside the body -- a `print`, a log line -- are ordered against the
join, never against each other: one region's output all lands before
the next region's, but the interleaving within a region is unspecified
wherever the fan-out is live. Code that needs an ordered stream should
write elements through the `&mut` lend and emit after the join.

### Chunked views

`flow for chunk in &mut xs.chunks(n)` lends disjoint contiguous chunks; `&xs.chunks(n)` lends shared chunks. The final chunk can be shorter. Use the chunk locally and mutate existing elements only:

```jac
def scale(xs: &mut list[int]) {
    flow for chunk in &mut xs.chunks(3) {
        for i in range(len(chunk)) {
            chunk[i] *= 2;
        }
    }
}
```

`chunks` is supported in this lent `flow for` position, not as a general iterator to bind, store, or return. Growing a chunk or its source is rejected. Join, capture, reduction, and backend execution rules are the same as for element-wise `flow for`.

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

`drop` fires under every native memory profile, at the same program point for a uniquely-owned value:

- **[Enforced headerless modules](native-pathway.md#zero-rc-ownership-compilation)** (`--memory nogc`): the compiler calls the hook from the statically inserted `__drop_<T>` at each drop point.
- **Reference-counted profiles** (`rc` and the default `managed`): the hook is invoked by the object's reference-count destructor when the last reference dies. For an unaliased local that is the same point the headerless build drops at, so program output is identical across modes.

**Drops happen after last use, and no later than scope exit.** Drops are scheduled by liveness: a binding whose value the program will never read again can be reclaimed early -- a value whose last use is its own initialization is dropped right away, before later statements run. This eager case is observable through `drop`:

```jac
def run {
    r: own Res = Res(tag=7);
    print("alive");
}
# prints 7, then "alive" -- r's last use is its declaration, so it drops first
```

The current native backend does not yet place every drop at the *statement* granularity a full non-lexical-lifetime scheme would: a binding that is read partway through a frame is observed to drop at frame exit rather than immediately after that last read. Rely on the guarantee the compiler actually provides today -- a uniquely-owned value drops after its last use and no later than scope exit, at the same program point under every native memory profile -- rather than on exact statement-level timing.

At scope exit, remaining owned bindings are released in reverse declaration order. List destruction releases elements from the last index to the first on both native and Python backends. Explicit `del` invokes an archetype's drop hook once, even when graph metadata keeps the object reachable.

Two caveats:

- Under `managed`, objects that die as members of a reference cycle are destroyed by the collector; each member's `drop` still runs, but the order within the cycle is unspecified and sibling objects may already be gone -- don't traverse other heap objects from a cyclic `drop`.
- There is no resurrection: `drop` must not store `self` anywhere; the object is freed as soon as the hook returns.

Outside regions, the Python backend does not invoke `def drop` automatically yet -- rely on it only in native modules. Values allocated under an [`in <handle> { }` open](#regions-first-class-region-handles-and-in-opens) are the exception: their hooks fire at portable points on both backends -- LIFO at the closing brace for an anonymous open, at the handle's death for a named one. (Named-handle timing on the Python backend rides CPython reference death, which approximates but does not exactly equal the native static drop point; the anonymous case is exactly portable.)

## Zero-RC native builds

On the native backend, full ownership coverage is what lets the memory-management runtime disappear from the artifact entirely. A **nogc-enforced** module (`jac build --native --memory nogc`, or `jac.toml [memory]` patterns) must keep every heap-typed contract position -- parameter, return type, `has` field -- in the owned world, with violations reported as hard [`E1401`-`E1407`](../diagnostics.md#zero-rc-enforcement-errors) errors that block codegen. Compiled with `--memory nogc`, such a module gets **headerless owned codegen**: allocations and frees at statically determined points (a bare `malloc` at construction, a direct `__drop_<T>` call after last use), no reference counting, and no collector -- and a build with `--memory nogc` fails if the emitted IR contains any RC/collector machinery, making the absence checkable in the binary. When incrementally enforcing modules under managed/RC profiles, `managed(...)` marks transfers into managed storage. A whole-artifact nogc build rejects managed allocation; preserve owned/borrowed contracts throughout that artifact. The full model -- memory profiles, the enforcement contract, and the `rc-stats` coverage report -- lives in [Zero-RC ownership compilation](native-pathway.md#zero-rc-ownership-compilation).

## What `&x` compiles to

On every backend the ownership annotations are compile-time-only. On the Python backend, `&x` and `&mut x` are **erased**: the expression compiles to exactly `x`, the same object reference an unannotated binding would produce. There is no runtime borrow object, no copy, and no indirection -- the annotation exists solely for `OwnershipCheckPass` to check. (The adjacent form `&x` is an ownership borrow. Legacy spaced `& expr` and parenthesized `&(expr)` still perform graph UUID lookup; `jobj(id=...)` is the explicit lookup spelling.) The native backend likewise erases borrows; its reference-count optimizations consume the core-stamped move-elision and param-rebinding facts (`RcFactsPass`), computed once on the shared dataflow framework.

The native backend does hand the checked facts to the optimizer: heap-typed parameters in ownership contract positions carry LLVM parameter attributes -- `own` and `&mut` are exclusive (`noalias`), `&` is exclusive-read (`noalias readonly`), and `imm` is deep-frozen (`readonly`, no `noalias` since immutable handles may alias). These attributes never change semantics -- a checked-clean module means they are true by construction -- but they license load hoisting and vectorization the optimizer could not otherwise prove. Unannotated parameters carry nothing.

## See also

- [Ownership Checker Specification](../../internals/ownership-checker-spec.md) -- the authoritative statement of what each `E13xx` code guarantees, the checker's symbol-level granularity, and the facts contract backends consume.
- [Errors and Warnings](../diagnostics.md#ownership-borrow-errors) -- ownership, view, place, and zero-RC enforcement diagnostics.
- [Native Compilation Reference](native-pathway.md#memory-management) -- the `--memory` profiles, zero-RC ownership compilation, and how the native backend proves [reference-count elision](native-pathway.md#reference-count-elision) independently of this checker.
