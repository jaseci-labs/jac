---
description: Borrowing with & and &mut (shared and mutable borrows, how long a borrow lives, field splitting, reference loops, views) and places that own what they hold (owned fields and containers, take and swap).
keywords: &, &mut, borrow, borrowing, shared borrow, mutable borrow, reference loop, view, take, swap, owned field
---
# Borrows and owned places

A borrow lends a value without giving it up: `&x` lends it shared, to read,
and `&mut x` lends it mutably, to change. The owner keeps the value, and the
checker proves that no borrow outlives it. A field or a container may be the
owner of what it holds. See [Ownership](ownership.md) for the states and for
moves.

## Borrows

- **A borrow lives while it is used.** An owner may be moved once its
  borrows have ended, and is kept alive while a borrow of it lives.
- **A borrow cannot outlive its owner** (E1304): the owner going out of
  scope or being moved while a borrow of it is used later. A value that
  carries a borrow borrows as the borrow does: the result of a call that
  returns a borrow, a view (below), a container a borrow is put in, a
  closure that captures one.
- **A borrow of a local is not returned** (E1306). A function may return a
  borrow it was lent: `def lend_back(b: &Buffer) -> &Buffer`.
- **A borrow starts at a parameter, `self`, an `own` value or another
  borrow** (E1323): a managed local may be released while it is used.
- **One mutable borrow at a time** (E1302), and no change through the owner
  while a shared borrow is live (E1303).
- **A shared borrow only reads.** Through `&x`, a `self: &T` receiver or
  the element a shared `flow for` lends, assigning a field is E1320 and
  calling a method that changes the object is E1318. A method changes its
  object when it assigns the object's fields, changes a builtin container
  the object holds (`append`, `pop`, `clear`, ...), or calls a method that
  does.
- **What a borrow reads through stays put.** While `cur = &head.next` is
  live, writing or `del` of the field `next` is E1321: on `head`, on an
  alias of it, or on any other object of its type, which may be `head`.
  A call that may write that field is E1322. What a function writes is
  found from its body and the functions it calls; a call through a
  `Callable` may write anything, and a builtin method that removes items
  (`pop`) writes them.
- **Borrows split by field**: while `&p.name` is held, `p.score` may be
  written.
- **A borrow may walk through managed values**: `cur = &cur.next` in a
  loop, while another field of the managed root is written.
- **A borrowing parameter takes a borrow or a bare name**: `peek(&a)` and
  `peek(a)` both lend `a` to `def peek(b: &Buffer)`. Lending `&a` to a
  `&mut` parameter is E1328: write `&mut a`.
- **A mutable borrow reaches storage**: `&mut x` of an `int` local is E1330,
  since a scalar is copied. Lend what holds it (an object, a list, a struct
  variable).

```jac
obj Player {
    has name: str = "",
        score: int = 0;
}

obj Link {
    has v: int = 0,
        next: Link | None = None;
}

obj Chain {
    has head: Link | None = None,
        steps: int = 0;
}

def find(c: Chain, want: int) -> Link | None {
    cur: &Link | None = &c.head;
    while cur is not None {
        c.steps += 1;
        if cur.v == want {
            return cur;
        }
        cur = &cur.next;
    }
    return None;
}

def lend_back(b: &Player) -> &Player {
    return b;
}

with entry {
    p: own Player = Player(name="ada");
    name: &str = &p.name;
    p.score = 3;
    print(name, p.score, lend_back(&p).name);
    c = Chain(head=Link(v=1, next=Link(v=2, next=Link(v=3))));
    hit = find(c, 3);
    print(hit.v if hit is not None else None, c.steps);
}
```

```output
ada 3 ada
3 3
```

### Reference loops

`for x in &xs` lends each element shared and `for m in &mut xs` lends each
mutably, so a write through `m` changes the list's element. The list
cannot grow while it is lent mutably (E1302). For a list of
[structs](structs.md) the loop variable is the element itself; see
[Packed lists](packed-lists.md).

```jac
obj Buffer {
    has n: int = 0;
}

with entry {
    xs: own list[Buffer] = [Buffer(n=1), Buffer(n=2), Buffer(n=3)];
    t = 0;
    for x in &xs {
        t += x.n;
    }
    for m in &mut xs {
        m.n = m.n * 10;
    }
    print(t, [x.n for x in xs]);
}
```

```output
6 [10, 20, 30]
```

### Views

An archetype with a borrow field (`has position: &Position`) is a view. It
may be made from a borrowed parameter, returned while it borrows only
borrowed parameters, and kept in a local list. It cannot be bound `own`,
stored in a field, a module global or a container that is not a local of
its own, or returned while it borrows a local (E1315).

```jac
obj Position {
    has x: float = 0.0;
}

obj RenderView {
    has position: &Position;
}

def open_view(p: &Position) -> RenderView {
    return RenderView(position=p);
}

def settle_at(p: own Position) -> float {
    return p.x * 4.0;
}

with entry {
    p: own Position = Position(x=1.5);
    v = open_view(&p);
    views: list[RenderView] = [RenderView(position=&p)];
    print(v.position.x, len(views));
    print(settle_at(p));
}
```

```output
1.5 1
6.0
```

## Owned fields and containers

- **A field may own its value**: `has next: own Cell | None`. A value is
  moved out of an owned field only by `take(place)`, which gives the value
  and leaves `None` there (E1316 otherwise), and two places are exchanged by
  `swap(&mut a, &mut b)`. The place `take` empties must be able to hold
  `None`: `take(c.v)` of an `int` field is E1319.
- **A container may own its elements**: `list[own T]`, `dict[str, own T]`.
  Overwriting an entry drops the old value at once, `pop` moves one out,
  and the rest drop with the container. An element cannot be moved into
  another owner in place (E1317).
- **Storing an owner into a managed object's field seals it** into managed
  storage: from there it is counted, as any managed value is.
- A [packed list](packed-lists.md) of structs or narrow numbers owns its
  elements by holding them, so `list[own P]` is E1521.

```jac
obj Cell {
    has v: int = 0,
        next: own Cell | None = None;
}

obj Stack {
    has head: own Cell | None = None;
}

def push(s: &mut Stack, v: int) {
    s.head = Cell(v=v, next=take(s.head));
}

def values(s: &Stack) -> list[int] {
    out: list[int] = [];
    cur: &Cell | None = &s.head;
    while cur is not None {
        out.append(cur.v);
        cur = &cur.next;
    }
    return out;
}

with entry {
    s: own Stack = Stack();
    for i in range(4) {
        push(&mut s, i);
    }
    t: own Stack = Stack();
    push(&mut t, 9);
    swap(&mut s.head, &mut t.head);
    print(values(&s), values(&t));
}
```

```output
[9] [3, 2, 1, 0]
```

`take` and `swap` work on any place, owned or not: `take(o.item)` of an
optional field, `swap(&mut p.a, &mut p.b)` of two fields,
`swap(&mut x, &mut y)` of two locals.

## What is rejected

```jac
# expect: E1302, E1304, E1306, E1316, E1318, E1319, E1320, E1321, E1322, E1323, E1328
obj Buffer {
    has n: int = 0;
}

obj Pair {
    has inner: own Buffer = Buffer();
}

obj Link {
    has v: int = 0,
        next: Link | None = None;
}

def finish(b: own Buffer) {
    print(b.n);
}

def bump(b: &mut Buffer) {
    b.n += 1;
}

def two_mutable {
    a: own Buffer = Buffer();
    e1: &mut Buffer = &mut a;
    e2: &mut Buffer = &mut a;
    print(e1.n, e2.n);
}

def moved_while_borrowed {
    a: own Buffer = Buffer();
    r = &a;
    finish(a);
    print(r.n);
}

def borrow_returned -> Buffer {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    return v;
}

def field_moved(p: own Pair) -> own Buffer {
    b: own Buffer = p.inner;
    return b;
}

def from_managed -> Link | None {
    head = Link(v=1);
    cur: &Link | None = &head.next;
    return cur;
}

def shared_to_mut {
    a: own Buffer = Buffer();
    bump(&a);
}

obj Counter {
    has n: int = 0;

    def inc {
        self.n += 1;
    }
}

def unlink(l: Link) {
    l.next = None;
}

def bumped(c: &Counter) {
    c.inc();
}

def taken(l: &mut Link) {
    v = take(l.v);
    print(v);
}

def assigned(l: &Link) {
    l.v = 3;
}

def cut(head: Link) -> Link | None {
    cur: &Link | None = &head.next;
    head.next = None;
    return cur;
}

def cut_by_call(head: Link, other: Link) -> Link | None {
    cur: &Link | None = &head.next;
    unlink(other);
    return cur;
}
```

| Code | Meaning |
|---|---|
| E1302 | A second mutable borrow while one is live, or a change to what a `&mut` loop lends. |
| E1303 | The owner is changed while a shared borrow of it is live. |
| E1304 | A borrow is used after its owner went out of scope or was moved. |
| E1306 | A borrow of a local escapes its scope (returned). |
| E1315 | A view is bound `own`, stored outside its function's locals, or returned while it borrows a local. |
| E1316 | An owned field is moved out without `take()`. |
| E1317 | An owned container element is moved into another owner in place. |
| E1318 | A method that changes its object is called through a shared borrow. |
| E1319 | `take()` of a place that cannot hold `None`. |
| E1320 | A field is assigned through a shared borrow. |
| E1321 | A field is written while a borrow reads through it. |
| E1322 | A call may write a field while a borrow reads through it. |
| E1323 | A borrow starts at a managed local. |
| E1328 | `&x` is lent to a `&mut` parameter. |
| E1330 | `&mut` of a scalar, which is copied. |

## Differences from Python and the reference design

- Python has no borrows: passing an object passes a counted reference, which
  is what passing an unmarked binding does here.
- A prefix `&` is always a borrow, however it is spaced (`& x`, `&(x)`).
