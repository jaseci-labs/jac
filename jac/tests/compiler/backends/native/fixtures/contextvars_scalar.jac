"""ContextVar at scalar, str, optional and object type arguments.

Each group reads a variable through every rung of `get`'s ladder (a set value,
the call's own default, the constructor default, `LookupError`) and through
`set`/`reset`/`Token`. The awkward payloads are the point: `0`, `False`, `""`
and `0.0` are the values a null-is-None erasure would confuse with an unset
slot, and `default=None` / `get(None)` are the explicit Nones CPython tells
apart from an omitted default. `INF` has no annotation, so its type argument
is inferred from the constructor's `default=False`; `P` holds a by-value
tuple, which boxes like a scalar.
"""

import from contextvars { ContextVar }

obj Opts {
    has level: int = 0;
}

glob N: ContextVar[int] = ContextVar[int]("n", `default=7),
     Z: ContextVar[int] = ContextVar("z"),
     B: ContextVar[bool] = ContextVar("b"),
     S: ContextVar[str] = ContextVar("s"),
     OS: ContextVar[str | None] = ContextVar("os"),
     OO: ContextVar[Opts | None] = ContextVar("oo", `default=None),
     D: ContextVar[dict[str, Opts | None] | None] = ContextVar("d", `default=None),
     F: ContextVar[float] = ContextVar("f", `default=1.5),
     P: ContextVar[tuple[int, int]] = ContextVar[tuple[int, int]]("p", `default=(1, 2)),
     INF = ContextVar("inf", `default=False);

def scalar_int {
    print("int", N.get(), N.get(3));
    tok = N.set(0);
    print("int set0", N.get(), N.get(3));
    tok2 = N.set(42);
    print("int set42", N.get(), tok2.old_value);
    N.reset(tok2);
    print("int reset", N.get());
    N.reset(tok);
    print("int reset2", N.get());
    try {
        Z.get();
    } except LookupError {
        print("z unset: LookupError");
    }
    print("z fallback 0", Z.get(0));
    ztok = Z.set(-5);
    print("z", Z.get());
    Z.reset(ztok);
    try {
        Z.reset(ztok);
    } except RuntimeError {
        print("z reused: RuntimeError");
    }
    ftok = Z.set(1);
    try {
        N.reset(ftok);
    } except ValueError {
        print("z foreign: ValueError");
    }
}

def scalar_bool {
    print("bool fallback", B.get(False), B.get(True));
    prev = B.get(False);
    B.set(True);
    print("bool", B.get(), prev);
    B.set(prev);
    print("bool restored", B.get());
    print("inferred", INF.get());
    t = INF.set(True);
    print("inferred set", INF.get());
    INF.reset(t);
    print("inferred reset", INF.get());
}

def show(v: (str | None)) -> str {
    if v is None {
        return "None";
    }
    return v;
}

def scalar_str {
    print("str fallback", repr(S.get('')));
    S.set("");
    print("str empty", repr(S.get("x")));
    S.set("hello");
    print("str", S.get(), len(S.get()));
    print("ostr none", show(OS.get(None)));
    t = OS.set("triple");
    print("ostr", show(OS.get(None)));
    OS.set(None);
    print("ostr set none", show(OS.get("dflt")));
    OS.reset(t);
    print("ostr reset", show(OS.get(None)));
}

def optional_obj {
    print("oo default", OO.get() is None);
    t = OO.set(Opts(level=3));
    cur = OO.get();
    if cur is not None {
        print("oo level", cur.level);
    }
    OO.reset(t);
    print("oo reset", OO.get() is None);
    print("d default", D.get() is None);
    dt = D.set({});
    dd = D.get();
    if dd is not None {
        dd["a"] = Opts(level=9);
        dd["b"] = None;
    }
    again = D.get();
    if again is not None {
        a = again["a"];
        print("d len", len(again), a.level if a is not None else -1);
    }
    D.reset(dt);
    print("d reset", D.get() is None);
}

def scalar_float {
    print("float", F.get());
    t = F.set(0.0);
    print("float zero", F.get());
    F.reset(t);
    print("float reset", F.get());
}

def boxed_tuple {
    print("tuple", P.get()[0], P.get()[1]);
    t = P.set((5, 6));
    print("tuple set", P.get()[0] + P.get()[1]);
    P.reset(t);
    print("tuple reset", P.get()[1]);
}

def nested(depth: int) -> int {
    tok = N.set(N.get() + depth);
    total = N.get();
    if depth > 0 {
        total = total + nested(depth - 1);
    }
    N.reset(tok);
    return total;
}

with entry {
    scalar_int();
    scalar_bool();
    scalar_str();
    optional_obj();
    scalar_float();
    boxed_tuple();
    print("nested", nested(3), N.get());
    with N.set(100) {
        print("in with", N.get());
    }
    print("after with", N.get());
}
