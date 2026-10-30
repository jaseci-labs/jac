"""Generic methods on archetypes monomorphize per call site (#7626 A4).

`Box.pick[T]` registers as a method template (keyed Arch.method) instead
of hitting the declaration-time unlowerable-type error; each call site
stamps a specialization with `self` prepended to the specialized
signature and dispatches it directly.
"""

obj Box {
    has val: int = 0;

    def pick[T](a: T, b: T) -> T {
        return a if self.val > 0 else b;
    }
}

def pick_int(v: int) -> int {
    return Box(val=v).pick(7, 9);
}

def pick_str_len(v: int) -> int {
    a: str = "xx";
    b: str = "yyy";
    return len(Box(val=v).pick(a, b));
}

# A generic method on a generic archetype keeps the archetype's `V` boxed,
# like its other methods; the caller unboxes against the receiver's type
# arguments, on a plain call and through a `**` spread alike.
obj Holder[V] {
    has val: V;

    def first[K](key: K, alt: V) -> V {
        return self.val;
    }

    def echo[K](key: K, alt: V) -> V {
        return alt;
    }

    def get[K](key: K) -> V {
        return self.val;
    }
}

def holder_first_int(v: int) -> int {
    return Holder[int](val=v).first("k", 7);
}

def holder_echo_int(v: int) -> int {
    return Holder[int](val=5).echo("k", v);
}

def holder_get_int(v: int) -> int {
    return Holder[int](val=v).get("k");
}

def holder_first_float(v: int) -> float {
    return Holder[float](val=v + 0.5).first("k", 7);
}

def holder_first_str_len(n: int) -> int {
    return len(Holder[str](val="x" * n).first(1, "y"));
}

def holder_echo_beside_spread(v: int) -> int {
    extra: dict[str, int] = {};
    return Holder[int](val=5).echo("k", v, **extra);
}

def holder_echo_from_spread(v: int) -> int {
    extra: dict[str, int] = {"alt": v};
    return Holder[int](val=5).echo("k", **extra);
}

def holder_float_echo_from_int_spread(v: int) -> float {
    extra: dict[str, int] = {"alt": v};
    return Holder[float](val=1.5).echo("k", **extra);
}

def holder_optional_echo_from_spread(v: int) -> int {
    extra: dict[str, int | None] = {"alt": v if v > 0 else None};
    got = Holder[int | None](val=5).echo("k", **extra);
    return got if got is not None else -1;
}

def holder_float_echo_from_optional_int_spread(v: int) -> float {
    extra: dict[str, int | None] = {"alt": v};
    got = Holder[float | None](val=1.5).echo("k", **extra);
    return got if got is not None else -1.0;
}

def holder_str_echo_rejects_int_spread(v: int) -> int {
    extra: dict[str, int] = {"alt": v};
    try {
        return len(Holder[str](val="x").echo("k", **extra));
    } except TypeError {
        return -1;
    }
}

def holder_int_echo_rejects_str_spread(n: int) -> int {
    extra: dict[str, str] = {"alt": "s" * n};
    try {
        return Holder[int](val=1).echo("k", **extra);
    } except TypeError {
        return -1;
    }
}
