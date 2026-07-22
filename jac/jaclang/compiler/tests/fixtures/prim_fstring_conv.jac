"""f-string !r conversions and dynamic format specs (#7593 item 6).

Cross-backend equivalence fixture. The Python reference pins CPython
semantics; the test blocks pass require=["na"] so a native compile
failure or value mismatch is a hard failure, not a silent skip.
"""

# --- !r conversion on scalars (conversion applies BEFORE the spec) ---
def fconv_py -> dict {
    s: str = chr(39) + "ab" + chr(10);
    return {
        "r_int": f"{42!r}",
        "r_neg": f"{-7!r}",
        "r_float": f"{3.14159!r}",
        "r_bool_t": f"{True!r}",
        "r_bool_f": f"{False!r}",
        "r_str": f"{s!r}",
        "r_str_plain": f"{'abc'!r}",
        "r_mixed": f"[{42!r}|{2.5!r}]",
        "r_spec": f"{3.14!r:>10}"
    };
}

na {
    def fconv_na -> dict[str, any] {
        s: str = chr(39) + "ab" + chr(10);
        return {
            "r_int": f"{42!r}",
            "r_neg": f"{-7!r}",
            "r_float": f"{3.14159!r}",
            "r_bool_t": f"{True!r}",
            "r_bool_f": f"{False!r}",
            "r_str": f"{s!r}",
            "r_str_plain": f"{'abc'!r}",
            "r_mixed": f"[{42!r}|{2.5!r}]",
            "r_spec": f"{3.14!r:>10}"
        };
    }
}

# --- dynamic format specs (spec text computed at runtime) ---
def fdyn_py -> dict {
    w: int = 8;
    p: int = 3;
    wd: int = 10;
    return {
        "dyn_wpf": f"{3.14159:{w}.{p}f}",
        "dyn_w_int": f"{42:{wd}d}",
        "dyn_hex": f"{255:{w}x}",
        "dyn_zero": f"{255:0{w}d}",
        "dyn_center": f"{42:*^{wd}}",
        "dyn_sign": f"{-7:+{wd}d}",
        "dyn_e": f"{3.14159:.{p}e}",
        "dyn_pct": f"{0.25:.{p}%}",
        "dyn_str": f"{'hi':{wd}}",
        "dyn_str_trunc": f"{'hello':.{p}}",
        "dyn_group": f"{1234567:{wd},d}"
    };
}

na {
    def fdyn_na -> dict[str, any] {
        w: int = 8;
        p: int = 3;
        wd: int = 10;
        return {
            "dyn_wpf": f"{3.14159:{w}.{p}f}",
            "dyn_w_int": f"{42:{wd}d}",
            "dyn_hex": f"{255:{w}x}",
            "dyn_zero": f"{255:0{w}d}",
            "dyn_center": f"{42:*^{wd}}",
            "dyn_sign": f"{-7:+{wd}d}",
            "dyn_e": f"{3.14159:.{p}e}",
            "dyn_pct": f"{0.25:.{p}%}",
            "dyn_str": f"{'hi':{wd}}",
            "dyn_str_trunc": f"{'hello':.{p}}",
            "dyn_group": f"{1234567:{wd},d}"
        };
    }
}

# --- !r conversion on containers (rides item #5's repr machinery) ---
def fcont_py -> dict {
    lst: list[int] = [1, 2, 3];
    sl: list[str] = ["a", "b"];
    d: dict[str, int] = {"k": 1};
    nested: list[list[int]] = [[1], [2, 3]];
    t: tuple[int, str] = (1, "a");
    return {
        "r_list": f"{lst!r}",
        "r_strlist": f"{sl!r}",
        "r_dict": f"{d!r}",
        "r_nested": f"{nested!r}",
        "r_tuple": f"{t!r}"
    };
}

na {
    def fcont_na -> dict[str, any] {
        lst: list[int] = [1, 2, 3];
        sl: list[str] = ["a", "b"];
        d: dict[str, int] = {"k": 1};
        nested: list[list[int]] = [[1], [2, 3]];
        t: tuple[int, str] = (1, "a");
        return {
            "r_list": f"{lst!r}",
            "r_strlist": f"{sl!r}",
            "r_dict": f"{d!r}",
            "r_nested": f"{nested!r}",
            "r_tuple": f"{t!r}"
        };
    }
}
