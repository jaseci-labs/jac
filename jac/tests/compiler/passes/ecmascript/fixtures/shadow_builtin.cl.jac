"""Regression: a user function shadowing a builtin name must be called.

Before call-kind classification was centralized, the ES backend matched `len`
by name membership and always emitted the builtin, ignoring this definition.
"""

def len(x: int) -> int {
    return x + 99;
}

def call_shadowed_len() -> int {
    return len(1);
}
