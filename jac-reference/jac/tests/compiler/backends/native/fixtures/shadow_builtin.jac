# Regression: a user function named like a builtin must shadow the builtin.
# Before call-kind classification was centralized, the native backend matched
# `len` by name string and always emitted the builtin, ignoring this definition.

def len(x: int) -> int {
    return x + 99;
}

def call_shadowed_len() -> int {
    return len(1);
}
