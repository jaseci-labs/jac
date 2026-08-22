"""Optional payloads inside tuple slots keep their value and their None.

A tuple slot declared `T | None` is a JacOpt in the box the callee hands
back, so the constructor has to store that representation and the reader
has to find it there. Building the box from the bare payload pointer and
bitcasting to the declared type shears the layout: the reader decodes the
pointer's low byte as the presence tag and the neighbouring slot as the
payload, which segfaults when present and silently drops the payload when
it does not.

Every function here returns a plain int that only decodes correctly if the
payload survived AND the None arm stayed None -- "did not crash" proves
nothing for this class of defect. `def drop` counts destructions so the
tests can also assert nothing leaked or died twice. The `(Box | None, bool)`
shape is `parse_from_path` in the sealed parser; `append_payload` is the
`from_loc` kid-append that made #8091 visible.
"""

glob dropped = 0;

obj Box {
    has v: int = 0;

    def drop {
        dropped += 1;
    }
}

def drop_count -> int {
    return dropped;
}

def mk_first(n: int) -> tuple[(Box | None, bool)] {
    if n >= 0 {
        return (Box(v=n), True);
    }
    return (None, False);
}

def read_first(n: int) -> int {
    r = mk_first(n);
    b = r[0];
    if b is not None {
        return b.v;
    }
    return -1;
}

def read_first_flag(n: int) -> int {
    r = mk_first(n);
    if r[1] {
        return 1;
    }
    return 0;
}

def mk_last(n: int) -> tuple[(int, Box | None)] {
    if n >= 0 {
        return (n * 10, Box(v=n));
    }
    return (n * 10, None);
}

def read_last(n: int) -> int {
    r = mk_last(n);
    b = r[1];
    if b is not None {
        return r[0] + b.v;
    }
    return r[0];
}

def mk_pair(a: int, b: int) -> tuple[(Box | None, Box | None)] {
    x: Box | None = None;
    if a >= 0 {
        x = Box(v=a);
    }
    if b >= 0 {
        return (x, Box(v=b));
    }
    return (x, None);
}

def read_pair(a: int, b: int) -> int {
    r = mk_pair(a, b);
    total = 0;
    p = r[0];
    q = r[1];
    if p is not None {
        total += p.v;
    } else {
        total -= 1000;
    }
    if q is not None {
        total += q.v * 100;
    } else {
        total -= 100000;
    }
    return total;
}

def unpack_first(n: int) -> int {
    (b, ok) = mk_first(n);
    if b is None {
        if ok {
            return -2;
        }
        return -1;
    }
    if not ok {
        return -3;
    }
    return b.v;
}

def append_payload(n: int) -> int {
    kid: list[Box] = [];
    r = mk_first(n);
    b = r[0];
    if b is not None {
        kid.append(b);
    }
    if len(kid) == 0 {
        return -1;
    }
    total = 0;
    for k in kid {
        total += k.v;
    }
    return total;
}
