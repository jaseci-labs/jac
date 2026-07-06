"""Native (`na`) `any`/`str()` stdlib gaps closed for #6943.

These are the produce/consume operations a pure-Jac `json` (the Mechanism-B
tier) needs: code that produces `any` (loads -> dict/list/scalars boxed as
`any`) and consumes `any` (dumps -> walk an arbitrary value, dispatch on runtime
type). The Python reference pins CPython semantics; `require=["na"]` makes the
native backend a hard regression guard (a backend that fails to compile/run or
mismatches fails the test instead of being silently skipped).

Each NA id below is from the issue's catalog. The `any`-container helpers assume
the canonical heterogeneous layout `loads()` produces (`list[any]` /
`dict[str, any]`), which is exactly what the Mechanism-B tier round-trips.

  NA-1  str(None) -> "None"            (was a SIGSEGV on a null deref)
  NA-2  isinstance-guarded any->dict consume + str += (was a SIGSEGV / UAF)
  NA-3  subscript an `any`             (x["k"] / x[i])
  NA-4  iterate an `any`               (for e in x)
  NA-5  len()/builtin on an `any`      (len of a boxed list/dict/str)
  NA-6  empty `list[any] = []` literal
  NA-8  str(True)/str(False) -> "True"/"False"
  NA-9  str.strip/lstrip/rstrip(chars)
  NA-10 empty-string truthiness in a ternary (`x if "" else y`)
"""

# --- NA-1 / NA-8 / NA-9 / NA-10: scalar + string congruence with CPython ---
def congruence_py(s: str) -> str { return s if s else "EMPTY"; }

def congruence_check_py() -> dict {
    return {
        "s_none": str(None),                    # NA-1
        "s_true": str(True),                    # NA-8
        "s_false": str(False),                  # NA-8
        "rstrip": "abc///".rstrip("/"),         # NA-9 trailing set
        "lstrip": "///abc".lstrip("/"),         # NA-9 leading set
        "strip": "xxabcyy".strip("xy"),         # NA-9 both-ends set
        "strip_ws": "  hi  ".strip(),           # NA-9 no-arg whitespace still works
        "tern_empty": congruence_py(""),        # NA-10 "" is falsy
        "tern_x": congruence_py("x")            # NA-10 non-empty is truthy
    };
}

na {
    def congruence_na(s: str) -> str { return s if s else "EMPTY"; }

    def congruence_check_na() -> dict[str, any] {
        return {
            "s_none": str(None),
            "s_true": str(True),
            "s_false": str(False),
            "rstrip": "abc///".rstrip("/"),
            "lstrip": "///abc".lstrip("/"),
            "strip": "xxabcyy".strip("xy"),
            "strip_ws": "  hi  ".strip(),
            "tern_empty": congruence_na(""),
            "tern_x": congruence_na("x")
        };
    }
}

# --- NA-3 / NA-4 / NA-5 / NA-6: produce + consume `any` containers ---
def any_subscript_py(x: any) -> int { v: int = x["k"]; return v; }

def any_index_py(x: any) -> int { v: int = x[1]; return v; }

def any_iter_sum_py(x: any) -> int {
    s: int = 0;
    for e in x { v: int = e; s += v; }
    return s;
}

def any_len_py(x: any) -> int { return len(x); }

def any_ops_check_py() -> dict {
    dd: dict[str, any] = {}; dd["k"] = 7;
    dda: any = dd;
    ll: list[any] = []; ll.append(10); ll.append(20); ll.append(30);
    lla: any = ll;
    sa: any = "hello";
    e6: list[any] = []; e6.append(1); e6.append("two"); e6.append(3.0);  # NA-6
    return {
        "sub_dict": any_subscript_py(dda),      # NA-3 dict[str, any]
        "sub_list": any_index_py(lla),          # NA-3 list[any]
        "iter_sum": any_iter_sum_py(lla),       # NA-4
        "len_str": any_len_py(sa),              # NA-5 str
        "len_dict": any_len_py(dda),            # NA-5 dict
        "len_list": any_len_py(lla),            # NA-5 list
        "n6": len(e6)                           # NA-6
    };
}

na {
    def any_subscript_na(x: any) -> int { v: int = x["k"]; return v; }

    def any_index_na(x: any) -> int { v: int = x[1]; return v; }

    def any_iter_sum_na(x: any) -> int {
        s: int = 0;
        for e in x { v: int = e; s += v; }
        return s;
    }

    def any_len_na(x: any) -> int { return len(x); }

    def any_ops_check_na() -> dict[str, any] {
        dd: dict[str, any] = {}; dd["k"] = 7;
        dda: any = dd;
        ll: list[any] = []; ll.append(10); ll.append(20); ll.append(30);
        lla: any = ll;
        sa: any = "hello";
        e6: list[any] = []; e6.append(1); e6.append("two"); e6.append(3.0);
        return {
            "sub_dict": any_subscript_na(dda),
            "sub_list": any_index_na(lla),
            "iter_sum": any_iter_sum_na(lla),
            "len_str": any_len_na(sa),
            "len_dict": any_len_na(dda),
            "len_list": any_len_na(lla),
            "n6": len(e6)
        };
    }
}

# --- NA-2: the json.dumps object branch shape — isinstance-guarded any->dict
#     narrow + dict-key iteration + `str +=` (this exact combination used to
#     use-after-free a clean-compiling binary). Both an accumulator mutated via
#     `+=` and via plain `out = out + k` are exercised. ---
def guard_consume_py(x: any) -> str {
    if isinstance(x, dict) {
        out: str = "";
        d: dict[str, any] = x;
        for k in d { out += k; }
        return out;
    }
    return "?";
}

def guard_consume_plain_py(x: any) -> str {
    if isinstance(x, dict) {
        out: str = "";
        d: dict[str, any] = x;
        for k in d { out = out + k; }
        return out;
    }
    return "?";
}

def guard_consume_check_py() -> dict {
    d: dict[str, any] = {}; d["a"] = 1; d["b"] = 2; d["c"] = 3;
    da: any = d;
    return {
        "aug": guard_consume_py(da),
        "plain": guard_consume_plain_py(da),
        "miss": guard_consume_py(5)
    };
}

na {
    def guard_consume_na(x: any) -> str {
        if isinstance(x, dict) {
            out: str = "";
            d: dict[str, any] = x;
            for k in d { out += k; }
            return out;
        }
        return "?";
    }

    def guard_consume_plain_na(x: any) -> str {
        if isinstance(x, dict) {
            out: str = "";
            d: dict[str, any] = x;
            for k in d { out = out + k; }
            return out;
        }
        return "?";
    }

    def guard_consume_check_na() -> dict[str, any] {
        d: dict[str, any] = {}; d["a"] = 1; d["b"] = 2; d["c"] = 3;
        da: any = d;
        return {
            "aug": guard_consume_na(da),
            "plain": guard_consume_plain_na(da),
            "miss": guard_consume_na(5)
        };
    }
}
