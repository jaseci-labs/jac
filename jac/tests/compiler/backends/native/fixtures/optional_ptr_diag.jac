"""E1121 vectors (#7871 A): un-narrowed optional use at native strict sites.

Each function uses a `T | None` value where the unwrapped `T` is required
without narrowing first; every one must be rejected at check time with
E1121, never lowered to runtime defined-behavior. On old main the dict-key
vector compiled and dereferenced NULL inside the hash core.
"""

obj Crate {
    has tag: str | None = None;
}

def order_bad -> int {
    c = Crate();
    if c.tag < "hi" {
        return 1;
    }
    return 0;
}

def dict_key_bad -> int {
    d: dict[str, int] = {"a": 1};
    c = Crate();
    d[c.tag] = 2;
    return len(d);
}

def scalar_order_bad(x: int | None) -> int {
    if x < 5 {
        return 1;
    }
    return 0;
}

def scalar_add_bad(x: int | None) -> int {
    return x + 1;
}

def scalar_radd_bad(x: int | None) -> int {
    return 1 + x;
}
