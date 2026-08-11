"""Native exponentiation (`**`) semantics -- Python/Jac parity.

Covers literal & dynamic exponents, the builtin `pow`, `**=`, the
fixed-width integer kernel, float power, and the zero-base
`ZeroDivisionError` guard. Results are exposed as `def:pub` entry points
that the JIT test harness calls via ctypes.
"""

# int ** non-negative literal -> int
def:pub ipow_pos -> int {
    a: int = 2;
    return a ** 3;
}
def:pub ipow_sq -> int {
    a: int = 7;
    return a ** 2;
}
def:pub ipow_one -> int {
    a: int = 99;
    return a ** 0;
}

# int ** negative literal -> float
def:pub ipow_neg -> float {
    a: int = 4;
    return a ** -2;
}

# int ** dynamic exponent -> float (runtime sign of the exponent)
def:pub ipow_dyn(a: int, b: int) -> float {
    return a ** b;
}

# i32 ** i32 dynamic -> exercises the fixed-width kernel (no i64 widen),
# returning float per the dynamic-sign contract.
def:pub ipow_i32_dyn(a: i32, b: i32) -> float {
    return a ** b;
}

# float ** float -> float
def:pub fpow(a: float, b: float) -> float {
    return a ** b;
}

# builtin pow over floats
def:pub bpow(a: float, b: float) -> float {
    return pow(a, b);
}

# builtin pow(int, int) — constant exponent specialization
def:pub bpow_int(a: int, b: int) -> int {
    return pow(a, b);
}

# builtin pow(0.0, -1.0) -> ZeroDivisionError
def:pub bpow_zero_neg -> int {
    result: int = 0;
    try {
        x: float = pow(0.0, -1.0);
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# 0.0 ** runtime negative float -> ZeroDivisionError
def:pub fpow_zero_dyn -> int {
    result: int = 0;
    b: float = -1.0;
    try {
        x: float = 0.0 ** b;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

obj PowBox {
    has x: int = 2;
}

# field **= with literal exponent
def:pub field_ipow_aug -> int {
    box = PowBox();
    box.x **= 3;
    return box.x;
}

# list element **=
def:pub list_ipow_aug -> int {
    v = [2];
    v[0] **= 3;
    return v[0];
}

# dict element **=
def:pub dict_ipow_aug -> int {
    d: dict[int, int] = {};
    d[0] = 2;
    d[0] **= 3;
    return d[0];
}

# **= int (positive literal) stays int
def:pub ipow_aug(a: int) -> int {
    x: int = a;
    x **= 3;
    return x;
}

# **= float
def:pub fpow_aug(a: float) -> float {
    x: float = a;
    x **= 2.0;
    return x;
}

# 0 ** negative (literal exponent) -> ZeroDivisionError
def:pub ipow_zero_base_neg -> int {
    result: int = 0;
    try {
        x: float = 0 ** -1;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# 0 ** negative (dynamic exponent) -> ZeroDivisionError
def:pub ipow_zero_base_dyn -> int {
    result: int = 0;
    b: int = -1;
    try {
        x: float = 0 ** b;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

with entry { }
