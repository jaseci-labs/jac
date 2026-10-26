"""Unwind-record shapes: which locals a frame registers, and through what.

Each function owns a reference, so it registers an unwind record; the test
reads the generated IR to see what the record holds."""

obj Box {
    has v: int = 0;
}

"""One owned local among scalars: only `box` is registered, through its
shadow; `a`, `b`, `f` and `flag` stay out of the record."""
def scalars_and_one_owner(k: int) -> int {
    a: int = k;
    b: int = 0;
    f: float = 1.5;
    flag: bool = False;
    box: Box = Box(v=k);
    i: int = 0;
    while i < 4 {
        b = b + a * i;
        i = i + 1;
    }
    flag = b > 10;
    return b + box.v + (1 if flag else 0) + int(f);
}

"""An owned local assigned three times: every store is mirrored."""
def reassigned(k: int) -> int {
    box: Box = Box(v=1);
    box = Box(v=2);
    if k > 0 {
        box = Box(v=k);
    }
    return box.v;
}

"""A store inside an exception handler is mirrored too."""
def in_handler(k: int) -> int {
    box: Box = Box(v=1);
    try {
        if k > 0 {
            raise ValueError("boom");
        }
    } except ValueError {
        box = Box(v=7);
    }
    return box.v;
}

"""An owned tuple: its cleanup releases it field by field."""
def owned_tuple(k: int) -> int {
    t: tuple[Box, int] = (Box(v=k), k);
    return t[1] + t[0].v;
}

with entry {
    print(scalars_and_one_owner(3), reassigned(5), in_handler(1), owned_tuple(2));
}
