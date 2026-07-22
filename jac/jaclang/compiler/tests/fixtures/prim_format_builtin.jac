"""format() builtin output wider than a fixed 64-byte buffer (#7593 item 6).

Lives apart from prim_builtins.jac because that fixture's native compile
produces no JIT engine (pre-existing), so keys added there can never be a
require=["na"] signal.
"""

def fmt_long_py -> dict {
    return {"fmt_long": format(10.0 / 3.0, ".70f")};
}

na {
    def fmt_long_na -> dict[str, any] {
        return {"fmt_long": format(10.0 / 3.0, ".70f")};
    }
}
