"""Fixture: first assignment inside a nested block must bind function-wide.

Jac scoping is python-like: an untyped assignment anywhere in a function
binds one function-level symbol (the symbol table hoists it to the
enclosing Ability). The ES backend must therefore hoist `let` to the
scope that owns the symbol instead of block-scoping a fresh binding in
every branch (#7882 / #7922).
"""

def t_ifelse(neg: bool) -> str {
    if neg {
        result = "NEG";
    } else {
        result = "POS";
    }
    return result;
}

def t_while -> int {
    n = 3;
    while n > 0 {
        last = n;
        n -= 1;
    }
    return last;
}

def t_for -> int {
    for x in [1, 2, 3] {
        hit = x;
    }
    return hit;
}

def t_try -> str {
    try {
        outcome = "ok";
    } except Exception as e {
        outcome = "err";
    }
    return outcome;
}

def t_walrus(x: int) -> int {
    if (y := x + 1) > 0 {
        return y;
    }
    return 0 - y;
}

def t_destr -> int {
    a = 1;
    (a, b) = (10, 20);
    return a + b;
}

def t_impl(neg: bool) -> str;

impl t_impl(neg: bool) -> str {
    if neg {
        r2 = "A";
    } else {
        r2 = "B";
    }
    return r2;
}

def t_all -> dict {
    return {
        "ifelse": t_ifelse(True),
        "whl": t_while(),
        "fr": t_for(),
        "tr": t_try(),
        "wal": t_walrus(4),
        "des": t_destr(),
        "imp": t_impl(False)
    };
}
