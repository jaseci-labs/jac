"""Ownership accounting for every tuple-bind shape the native backend lowers.

Each function allocates a statically known number of `Res` and returns a
value that only decodes correctly if the bindings landed. `def drop` bumps
a module glob, so a test can count destructions exactly instead of reading
freed memory.

The shapes differ in two independent axes: where the incoming element comes
from (a value tuple built inline, a heap-boxed tuple the callee handed back,
or a single indexed field of such a box) and what the target slot is (a
fresh name, an already-bound plain pointer local, or an already-bound
optional local). Ownership of the incoming element and the fate of the
target's previous contents have to be decided per axis, so every
combination is pinned here.
"""

glob dropped = 0;

obj Res {
    has tag: int = 0;

    def drop {
        dropped += 1;
    }
}

def make_pair(a: int, b: int) -> tuple[Res, Res] {
    return (Res(tag=a), Res(tag=b));
}

def maybe_res(tag: int) -> Res | None {
    if tag > 0 {
        return Res(tag=tag);
    }
    return None;
}

def unpack_plain_into_plain(a: int, b: int) -> int {
    ra = Res(tag=a);
    rb = Res(tag=b);
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (ra, rb);
    return p.tag * 10 + q.tag;
}

def unpack_fresh_into_plain(a: int, b: int) -> int {
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (Res(tag=a), Res(tag=b));
    return p.tag * 10 + q.tag;
}

def unpack_optional_into_plain(a: int, b: int) -> int {
    oa = maybe_res(a);
    ob = maybe_res(b);
    if oa is None or ob is None {
        return -1;
    }
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (oa, ob);
    return p.tag * 10 + q.tag;
}

def unpack_boxed_into_optional(a: int, b: int) -> int {
    x: Res | None = None;
    y: Res | None = None;
    (x, y) = make_pair(a, b);
    if x is None or y is None {
        return -1;
    }
    return x.tag * 10 + y.tag;
}

def unpack_boxed_into_plain(a: int, b: int) -> int {
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = make_pair(a, b);
    return p.tag * 10 + q.tag;
}

def unpack_boxed_into_fresh(a: int, b: int) -> int {
    (p, q) = make_pair(a, b);
    return p.tag * 10 + q.tag;
}

def index_into_optional(a: int, b: int) -> int {
    pair = make_pair(a, b);
    x: Res | None = None;
    x = pair[0];
    if x is None {
        return -1;
    }
    return x.tag * 10 + pair[1].tag;
}

def index_into_plain(a: int, b: int) -> int {
    pair = make_pair(a, b);
    p: Res = Res(tag=0);
    p = pair[0];
    return p.tag * 10 + pair[1].tag;
}

def index_twice_into_optional(a: int, b: int) -> int {
    pair = make_pair(a, b);
    x: Res | None = None;
    y: Res | None = None;
    x = pair[0];
    y = pair[0];
    if x is None or y is None {
        return -1;
    }
    return x.tag * 10 + y.tag;
}

def drop_count -> int {
    return dropped;
}
