"""`d[k] = d.get(k, c) op e` on unsigned values keeps unsigned arithmetic.

The single-probe update must add as the plain expression does: 2**63 - 1 + 1
fits a u64, and u64.MAX + 1 overflows.
"""

def bump(d: dict[str, u64], k: str, zero: u64, one: u64) -> str {
    try {
        d[k] = d.get(k, zero) + one;
    } except Exception as e {
        return f"raised {type(e).__name__}";
    }
    return str(d[k]);
}

glob zero: u64 = 0,
     one: u64 = 1;

with entry {
    d: dict[str, u64] = {"a": u64(9223372036854775807), "m": u64(18446744073709551615)};
    print(bump(d, "a", zero, one));
    print(bump(d, "m", zero, one));
}
