"""Fixture for scalar `raise` cause boxing.

The raise ABI takes (obj ptr, i32, msg ptr); `raise SystemExit(128 + n)`
-- the signal-floor exit convention -- arrived as a raw i64 and failed to
lower. Scalar causes now box through the repr leaf functions.
"""

def:pub raise_int(code: int) -> int {
    result: int = 0;
    try {
        raise SystemExit(128 + code);
    } except SystemExit {
        result = 1;
    }
    return result;
}


def:pub raise_bool(flag: bool) -> int {
    result: int = 0;
    try {
        raise SystemExit(flag);
    } except SystemExit {
        result = 1;
    }
    return result;
}


def:pub raise_float(code: float) -> int {
    result: int = 0;
    try {
        raise SystemExit(code);
    } except SystemExit {
        result = 1;
    }
    return result;
}
