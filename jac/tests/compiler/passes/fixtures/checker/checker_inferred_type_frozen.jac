"""Strict inferred-local typing.

An unannotated local variable is *frozen* to the type inferred at its
first binding. Reassigning a value of an incompatible type is a type
error (E1001) — exactly as if the inferred type had been written out as
an explicit annotation.

The one exception is the `None`-sentinel pattern (`x = None; ...; x = v`):
when the first binding infers `NoneType`, the variable's type is allowed
to evolve, matching TypeScript's strict-mode evolving locals.

A `for` target that reuses the name writes the same variable, so it is held
to the frozen type too (#9972), in the single and the unpacking form, and
an annotated local to its annotation. So is every other binder that writes
the local (#10405): unpacking, chained assignment, walrus, `with ... as` and
`except ... as`.
"""

with entry {
    # Frozen to `int` by the first binding — reassigning a `str` is an error.
    a = 90;
    a = "some str";  # <-- Error

    # Reassignment within the frozen type is fine.
    b = 1;
    b = 2;  # <-- Ok

    # None-sentinel: the inferred type evolves, so reassignment is allowed.
    found = None;
    found = 42;  # <-- Ok

    # A loop target rebinds the frozen local: an incompatible element is an
    # error, one within the frozen type is fine.
    for a in ["x", "y"] {  # <-- Error
        print(a);
    }
    for (kind, a) in [("k", "x")] {  # <-- Error
        print(kind);
    }
    for b in [3, 4] {  # <-- Ok
        print(b);
    }
    (q, _) = (7, 1);
    for (_, z) in [("k", 2.5)] {  # <-- Ok: `_` from an unpack is a throwaway
        print(q, z);
    }
}

glob
     # An annotated local is held to its annotation the same way.
     c: str = "s";

with entry {
    for c in [1, 2] {  # <-- Error
        print(c);
    }
}

impl rebinds_param(x: int) -> int {
    for x in ["bad"] {  # <-- Error
        print(x);
    }
    return 0;
}

def rebinds_param(x: int) -> int;

obj Label {
    has text: str = "";
}

def binder_rebinds {
    title = Label(text="a");
    (kind, title) = ("k", "x");  # <-- Error
    [kind, title] = ["k", "x"];  # <-- Error
    other = title="x";  # <-- Error
    if (title := "x") {  # <-- Error
        print(kind, other);
    }
    with open("x.txt") as title {  # <-- Error
        print(1);
    }
    try {
        print(1);
    } except ValueError as title {  # <-- Error
        print(2);
    }
    (kind, title) = ("k", Label());  # <-- Ok
    [first, second] = [Label(), Label()];  # <-- Ok: first binding
    pending = None;
    (kind, pending) = ("k", 3);  # <-- Ok: None-sentinel
    print(first, second, pending);
}

def for_unpack_rebinds {
    title = Label(text="a");
    for [kind, title] in [["k", "x"]] {  # <-- Error
        print(kind);
    }
    count = 0;
    # Iterating a dict yields its keys, so `count` gets a key's characters.
    for (key, count) in {"ab": 1} {  # <-- Error
        print(key);
    }
}
