"""Variadic parameter forms cross-backend equivalence fixture.

Pins the py (sv) semantics against native for *args / **kwargs binding:
positional extras collect into the pack, keyword extras collect into the
str-keyed pack, defaults compose, and len/index/iterate over the pack agree.
Stays inside the envelope where py-tuple vs native-list packs agree (no
isinstance(pack, tuple), no pack concatenation). ES/JS opts out.
"""

def sum_all_py(*nums: int) -> int {
    acc = 0;
    for n in nums {
        acc += n;
    }
    return acc;
}

def mixed_py(base: int, *nums: int) -> int {
    s = 0;
    for n in nums {
        s += n;
    }
    return base * 1000 + s;
}

def default_py(scale: int = 2, *nums: int) -> int {
    s = 0;
    for n in nums {
        s += n;
    }
    return scale * len(nums) + s;
}

def kw_bias_py(**opts: int) -> int {
    return opts["bias"] if "bias" in opts else -1;
}

def kw_sum_py(**opts: int) -> int {
    t = 0;
    for k in opts {
        t += opts[k];
    }
    return t;
}

def str_lens_py(*words: str) -> int {
    t = 0;
    for w in words {
        t += len(w);
    }
    return t;
}

def varargs_py -> dict {
    return {
        "sum_all": sum_all_py(1, 2, 3),
        "sum_empty": sum_all_py(),
        "mixed": mixed_py(7, 1, 2),
        "default_pack": default_py(3, 10, 20),
        "kw_bias": kw_bias_py(bias=4, other=9),
        "kw_miss": kw_bias_py(),
        "kw_sum": kw_sum_py(a=1, b=2, c=3),
        "str_lens": str_lens_py("ab", "cde")
    };
}

cl def varargs_cl -> dict {
    return {};
}

na {
    def sum_all_na(*nums: int) -> int {
        acc = 0;
        for n in nums {
            acc += n;
        }
        return acc;
    }

    def mixed_na(base: int, *nums: int) -> int {
        s = 0;
        for n in nums {
            s += n;
        }
        return base * 1000 + s;
    }

    def default_na(scale: int = 2, *nums: int) -> int {
        s = 0;
        for n in nums {
            s += n;
        }
        return scale * len(nums) + s;
    }

    def kw_bias_na(**opts: int) -> int {
        return opts["bias"] if "bias" in opts else -1;
    }

    def kw_sum_na(**opts: int) -> int {
        t = 0;
        for k in opts {
            t += opts[k];
        }
        return t;
    }

    def str_lens_na(*words: str) -> int {
        t = 0;
        for w in words {
            t += len(w);
        }
        return t;
    }

    def varargs_na -> dict[str, any] {
        return {
            "sum_all": sum_all_na(1, 2, 3),
            "sum_empty": sum_all_na(),
            "mixed": mixed_na(7, 1, 2),
            "default_pack": default_na(3, 10, 20),
            "kw_bias": kw_bias_na(bias=4, other=9),
            "kw_miss": kw_bias_na(),
            "kw_sum": kw_sum_na(a=1, b=2, c=3),
            "str_lens": str_lens_na("ab", "cde")
        };
    }
}
