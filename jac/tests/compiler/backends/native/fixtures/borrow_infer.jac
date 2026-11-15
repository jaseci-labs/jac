"""Locals that borrow (no refcount) and locals that must not.

Each `keep_*` function binds a local that only names something its source
keeps alive, so the ownership pass infers it a borrow. Each `must_*`
function would read a freed object if its local were a borrow: the element
or field it names is replaced, or the list is emptied, while the local is
still used afterwards. Building a fresh `Box` for the read after the change
reuses the freed block, so a wrong borrow prints that box's value. The
`must_remove_eq` and `must_aug_op` changes happen in user code a list
comparison or an augmented operator runs. `keep_owner_alive` borrows from a
local whose last use is the bind: the local is released only at scope exit.
`must_reused_loop_name` binds two loop variables of one name, which share a
slot, and `must_own_root` moves its root into an `own` parameter.
"""

obj Box {
    has v: int = 0;
}

obj Holder {
    has item: Box = Box(),
        items: list[Box] = [];

    def reset {
        self.items.clear();
    }
}

glob SHARED: list[Box] = [],
     SWAP: Holder = Holder(item=Box(v=11));

obj Needle {
    has k: int = 0;

    def __eq__(other: object) -> bool {
        SWAP.item = Box(v=-1);
        return False;
    }
}

obj Counter {
    has n: int = 0;

    def __add__(other: int) -> Counter {
        SWAP.item = Box(v=-2);
        return Counter(n=self.n + other);
    }
}

def fresh(n: int) -> list[Box] {
    out: list[Box] = [];
    for i in range(n) {
        out.append(Box(v=i * 10 + 7));
    }
    return out;
}

def empty(xs: list[Box]) {
    xs.clear();
}

def keep_elem(xs: list[Box]) -> int {
    total: int = 0;
    for i in range(len(xs)) {
        b = xs[i];
        total += b.v;
    }
    return total;
}

def keep_loop(xs: list[Box]) -> int {
    total: int = 0;
    for b in xs {
        total += b.v;
    }
    return total;
}

def keep_field(h: Holder) -> int {
    it = h.item;
    return it.v + 1;
}

def must_elem_overwrite(xs: list[Box]) -> int {
    b = xs[0];
    xs[0] = Box(v=1000);
    filler = Box(v=-1);
    return b.v + filler.v;
}

def must_field_overwrite(h: Holder) -> int {
    it = h.item;
    h.item = Box(v=2000);
    filler = Box(v=-1);
    return it.v + filler.v;
}

def must_call_clear(xs: list[Box]) -> int {
    b = xs[1];
    empty(xs);
    filler = Box(v=-1);
    return b.v + filler.v;
}

def must_method_clear(h: Holder) -> int {
    b = h.items[0];
    h.reset();
    filler = Box(v=-1);
    return b.v + filler.v;
}

def must_loop_overwrite(xs: list[Box]) -> int {
    total: int = 0;
    for b in xs {
        xs[0] = Box(v=3000);
        filler = Box(v=-1);
        total += b.v + filler.v;
    }
    return total;
}

def must_global_root -> int {
    b = SHARED[0];
    SHARED.clear();
    filler = Box(v=-1);
    return b.v + filler.v;
}

def must_copied_root(hs: list[Holder]) -> int {
    h = hs.pop();
    it = h.item;
    other = h;
    other = hs.pop();
    return it.v;
}

def must_remove_eq(h: Holder, xs: list[Needle]) -> int {
    b = h.item;
    xs.remove(xs[1]);
    filler = Box(v=-3);
    return b.v + filler.v;
}

def must_aug_op(h: Holder, c: Counter) -> int {
    b = h.item;
    c += 1;
    filler = Box(v=-4);
    return b.v + c.n + filler.v;
}

def keep_owner_alive(n: int) -> int {
    xs = [[n, n + 1, n + 2]];
    b = xs[0];
    pad = [[n * 1000, n * 1000, n * 1000]];
    return len(b) + b[2] + len(pad);
}

def must_reused_loop_name(xs: list[Box]) -> int {
    total = 0;
    for b in xs {
        total += b.v;
    }
    for b in xs {
        SWAP.reset();
        total += b.v * 10;
    }
    SWAP.items.append(Box(v=-5));
    return total + xs[-1].v;
}

def consume(h: own Holder) -> int {
    return h.item.v;
}

def must_own_root(h: own Holder) -> int {
    b = h.item;
    got = consume(h);
    return b.v + got;
}

with entry {
    print(keep_elem(fresh(4)), keep_loop(fresh(4)));
    print(keep_field(Holder(item=Box(v=5))));
    print(must_elem_overwrite(fresh(2)));
    print(must_field_overwrite(Holder(item=Box(v=6))));
    print(must_call_clear(fresh(3)));
    print(must_method_clear(Holder(items=fresh(2))));
    print(must_loop_overwrite(fresh(5)));
    SHARED.append(Box(v=42));
    print(must_global_root());
    print(must_copied_root([Holder(item=Box(v=8)), Holder(item=Box(v=9))]));
    print(must_remove_eq(SWAP, [Needle(k=1), Needle(k=2)]));
    SWAP.item = Box(v=12);
    print(must_aug_op(SWAP, Counter(n=1)));
    print(keep_owner_alive(10));
    print(must_reused_loop_name(fresh(3)));
    print(must_own_root(Holder(item=Box(v=13))));
}
