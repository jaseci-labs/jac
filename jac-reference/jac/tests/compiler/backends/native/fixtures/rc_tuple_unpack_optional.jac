"""Tuple-unpack ownership when an optional crosses the store (PR #7982).

Routing the unpack store through `_coerce_type` made two shapes compile
that previously raised at codegen, so their refcount accounting needs a
guard. A heap tuple box owns one reference per managed field and its
destructor releases them, so `_codegen_tuple_unpack` decides its retain by
provenance rather than by the tuple's representation: a field loaded out of
a box is always borrowed from the box's own reference, and a value-tuple
element is borrowed unless it was recorded as owned. Whatever the target
slot already held is released either way, reached through the optional
payload when the slot is an optional rather than a raw pointer:

  - `unpack_into_optional` binds two fields of a boxed tuple into
    `Res | None` locals. Each bind retains the field it borrows, releasing
    the `None` the local held is a no-op, the box release then runs the
    destructor that drops the box's own reference to each field, and scope
    exit releases each payload: one destruction per allocation. Dropping
    the retain, or letting the box abandon its fields again, turns that
    into an over-release or a leak respectively.
  - `unpack_optional_into_plain` overwrites two `Res` locals from optional
    elements of a value tuple, and the two overwritten originals are
    released at the store. `unpack_plain_into_plain` is the same shape with
    no optional anywhere and must account identically, which is what keeps
    the optional coercion from changing ownership on its own.

`def drop` bumps a module glob so the tests count destructions exactly
instead of reading freed memory.
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

def unpack_into_optional(a: int, b: int) -> int {
    x: Res | None = None;
    y: Res | None = None;
    (x, y) = make_pair(a, b);
    if x is None or y is None {
        return -1;
    }
    return x.tag * 10 + y.tag;
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

def unpack_plain_into_plain(a: int, b: int) -> int {
    ra = Res(tag=a);
    rb = Res(tag=b);
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (ra, rb);
    return p.tag * 10 + q.tag;
}

def drop_count -> int {
    return dropped;
}
