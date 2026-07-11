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
  NA-7  bare `list = []` flow-infers its element type from mutations
  NA-8  str(True)/str(False) -> "True"/"False"
  NA-9  str.strip/lstrip/rstrip(chars)
  NA-10 empty-string truthiness in a ternary (`x if "" else y`)
  NA-11 None-valued `any` on consume: is None / truthiness / == None (#6957)
"""

# --- NA-1 / NA-8 / NA-9 / NA-10: scalar + string congruence with CPython ---
def congruence_py(s: str) -> str {
    # NA-10 pins the ternary construct itself; `s or "EMPTY"` segfaults na.
    return s if s else "EMPTY";  # jac:ignore[simplify-ternary]
}

def congruence_check_py -> dict {
    return {
        "s_none": str(None),  # NA-1
        "s_true": str(True),  # NA-8
        "s_false": str(False),  # NA-8
        "rstrip": "abc///".rstrip("/"),  # NA-9 trailing set
        "lstrip": "///abc".lstrip("/"),  # NA-9 leading set
        "strip": "xxabcyy".strip("xy"),  # NA-9 both-ends set
        "strip_ws": "  hi  ".strip(),  # NA-9 no-arg whitespace still works
        "tern_empty": congruence_py(""),  # NA-10 "" is falsy
        "tern_x": congruence_py("x")  # NA-10 non-empty is truthy
    };
}

na {
    def congruence_na(s: str) -> str {
        # NA-10 pins the ternary construct itself; `s or "EMPTY"` segfaults na.
        return s if s else "EMPTY";  # jac:ignore[simplify-ternary]
    }

    def congruence_check_na -> dict[str, any] {
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
def any_subscript_py(x: any) -> int {
    v: int = x["k"];
    return v;
}

def any_index_py(x: any) -> int {
    v: int = x[1];
    return v;
}

def any_iter_sum_py(x: any) -> int {
    s: int = 0;
    for e in x {
        v: int = e;
        s += v;
    }
    return s;
}

def any_len_py(x: any) -> int {
    return len(x);
}

def any_ops_check_py -> dict {
    dd: dict[str, any] = {};
    dd["k"] = 7;
    dda: any = dd;
    ll: list[any] = [];
    ll.append(10);
    ll.append(20);
    ll.append(30);
    lla: any = ll;
    sa: any = "hello";
    e6: list[any] = [];
    e6.append(1);
    e6.append("two");
    e6.append(3.0);  # NA-6
    return {
        "sub_dict": any_subscript_py(dda),  # NA-3 dict[str, any]
        "sub_list": any_index_py(lla),  # NA-3 list[any]
        "iter_sum": any_iter_sum_py(lla),  # NA-4
        "len_str": any_len_py(sa),  # NA-5 str
        "len_dict": any_len_py(dda),  # NA-5 dict
        "len_list": any_len_py(lla),  # NA-5 list
        "n6": len(e6)  # NA-6
    };
}

na {
    def any_subscript_na(x: any) -> int {
        v: int = x["k"];
        return v;
    }

    def any_index_na(x: any) -> int {
        v: int = x[1];
        return v;
    }

    def any_iter_sum_na(x: any) -> int {
        s: int = 0;
        for e in x {
            v: int = e;
            s += v;
        }
        return s;
    }

    def any_len_na(x: any) -> int {
        return len(x);
    }

    def any_ops_check_na -> dict[str, any] {
        dd: dict[str, any] = {};
        dd["k"] = 7;
        dda: any = dd;
        ll: list[any] = [];
        ll.append(10);
        ll.append(20);
        ll.append(30);
        lla: any = ll;
        sa: any = "hello";
        e6: list[any] = [];
        e6.append(1);
        e6.append("two");
        e6.append(3.0);
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
        for k in d {
            out += k;
        }
        return out;
    }
    return "?";
}

def guard_consume_plain_py(x: any) -> str {
    if isinstance(x, dict) {
        out: str = "";
        d: dict[str, any] = x;
        for k in d {
            out = out + k;
        }
        return out;
    }
    return "?";
}

def guard_consume_check_py -> dict {
    d: dict[str, any] = {};
    d["a"] = 1;
    d["b"] = 2;
    d["c"] = 3;
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
            for k in d {
                out += k;
            }
            return out;
        }
        return "?";
    }

    def guard_consume_plain_na(x: any) -> str {
        if isinstance(x, dict) {
            out: str = "";
            d: dict[str, any] = x;
            for k in d {
                out = out + k;
            }
            return out;
        }
        return "?";
    }

    def guard_consume_check_na -> dict[str, any] {
        d: dict[str, any] = {};
        d["a"] = 1;
        d["b"] = 2;
        d["c"] = 3;
        da: any = d;
        return {
            "aug": guard_consume_na(da),
            "plain": guard_consume_plain_na(da),
            "miss": guard_consume_na(5)
        };
    }
}

# --- NA-7: an empty bare `list = []` flow-infers its element type from the
#     mutations that follow (append / insert / extend / index-store), so a
#     later `List.ptr` consumer like `str.join` type-checks instead of
#     mismatching the defaulted `List.i64` layout. Int-only bare lists must
#     keep their unboxed layout, and mixed evidence collapses to the
#     heterogeneous `any` element rather than a union. ---
def bare_list_check_py -> dict {
    strs: list = [];
    strs.append("a");
    strs.append("b");
    ints: list = [];
    ints.append(10);
    ints.append(20);
    total: int = 0;
    for v in ints {
        iv: int = v;
        total += iv;
    }
    ext: list = [];
    ext.extend(["x", "y"]);
    ins: list = [];
    ins.insert(0, 2.5);
    ins[0] = 3.5;
    mixed: list = [];
    mixed.append(1);
    mixed.append("two");
    return {
        "joined": "/".join(strs),
        "sum": total,
        "ext": "-".join(ext),
        "ins0": ins[0],
        "mixed_n": len(mixed)
    };
}

na {
    def bare_list_check_na -> dict[str, any] {
        strs: list = [];
        strs.append("a");
        strs.append("b");
        ints: list = [];
        ints.append(10);
        ints.append(20);
        total: int = 0;
        for v in ints {
            iv: int = v;
            total += iv;
        }
        ext: list = [];
        ext.extend(["x", "y"]);
        ins: list = [];
        ins.insert(0, 2.5);
        ins[0] = 3.5;
        mixed: list = [];
        mixed.append(1);
        mixed.append("two");
        return {
            "joined": "/".join(strs),
            "sum": total,
            "ext": "-".join(ext),
            "ins0": ins[0],
            "mixed_n": len(mixed)
        };
    }
}

# --- NA-11 (#6957): a None-valued `any` on the consume side. `x is None`,
#     bare truthiness, and `x == None` must reduce the boxed value to i1
#     (they emitted invalid IR); isinstance against a None-any must fall
#     through as False (pinned; fixed by the dedicated None tag); and
#     `isinstance(x, type(None))` is the explicit detection route. The
#     recursive dumps with nulls is the issue's acceptance shape. ---
def none_probe_py(x: any) -> str {
    if x is None {
        return "null";
    }
    return "val";
}

def notnone_probe_py(x: any) -> int {
    if x is not None {
        return 1;
    }
    return 0;
}

def eqnone_probe_py(x: any) -> int {
    if x == None {
        return 1;
    }
    return 0;
}

def nenone_probe_py(x: any) -> int {
    if x != None {
        return 1;
    }
    return 0;
}

def truthy_probe_py(x: any) -> str {
    if x {
        return "T";
    }
    return "F";
}

def isint_probe_py(x: any) -> int {
    if isinstance(x, int) {
        return 1;
    }
    return 0;
}

def typenone_probe_py(x: any) -> int {
    if isinstance(x, type(None)) {
        return 1;
    }
    return 0;
}

def dumps_probe_py(val: any) -> str {
    if val is None {
        return "null";
    }
    if isinstance(val, bool) {
        bv: bool = val;
        if bv {
            return "true";
        }
        return "false";
    }
    if isinstance(val, int) {
        iv: int = val;
        return str(iv);
    }
    if isinstance(val, str) {
        sv: str = val;
        return "\"" + sv + "\"";
    }
    if isinstance(val, list) {
        lst: list[any] = val;
        out: str = "[";
        first: int = 1;
        for e in lst {
            if first == 0 {
                out += ",";
            }
            out += dumps_probe_py(e);
            first = 0;
        }
        return out + "]";
    }
    if isinstance(val, dict) {
        d: dict[str, any] = val;
        out2: str = "{";
        f2: int = 1;
        for k in d {
            if f2 == 0 {
                out2 += ",";
            }
            out2 += "\"" + k + "\":" + dumps_probe_py(d[k]);
            f2 = 0;
        }
        return out2 + "}";
    }
    return "?";
}

def none_consume_check_py -> dict {
    n: any = None;
    i0: any = 0;
    i5: any = 5;
    se: any = "";
    ss: any = "s";
    f0: any = 0.0;
    f2: any = 2.5;
    bt: any = True;
    bf: any = False;
    fnan: any = float("nan");
    le: list[any] = [];
    ln: list[any] = [];
    ln.append(1);
    la: any = le;
    lb: any = ln;
    de: dict[str, any] = {};
    dn: dict[str, any] = {};
    dn["a"] = 1;
    da: any = de;
    db: any = dn;
    arr: list[any] = [];
    arr.append(1);
    arr.append("two");
    arr.append(False);
    arr.append(None);
    payload: dict[str, any] = {};
    payload["name"] = "jac";
    payload["n"] = 42;
    payload["ok"] = True;
    payload["nil"] = None;
    payload["arr"] = arr;
    pa: any = payload;
    return {
        "is_none": none_probe_py(n),
        "is_val": none_probe_py(i5),
        "isnot_none": notnone_probe_py(n),
        "isnot_val": notnone_probe_py(i5),
        "eq_none": eqnone_probe_py(n),
        "eq_val": eqnone_probe_py(i5),
        "ne_none": nenone_probe_py(n),
        "ne_val": nenone_probe_py(i5),
        "t_none": truthy_probe_py(n),
        "t_i0": truthy_probe_py(i0),
        "t_i5": truthy_probe_py(i5),
        "t_se": truthy_probe_py(se),
        "t_ss": truthy_probe_py(ss),
        "t_f0": truthy_probe_py(f0),
        "t_f2": truthy_probe_py(f2),
        "t_bt": truthy_probe_py(bt),
        "t_bf": truthy_probe_py(bf),
        "t_fnan": truthy_probe_py(fnan),
        "t_le": truthy_probe_py(la),
        "t_ln": truthy_probe_py(lb),
        "t_de": truthy_probe_py(da),
        "t_dn": truthy_probe_py(db),
        "isinst_none_int": isint_probe_py(n),
        "tn_none": typenone_probe_py(n),
        "tn_val": typenone_probe_py(i5),
        "dumps": dumps_probe_py(pa)
    };
}

na {
    def none_probe_na(x: any) -> str {
        if x is None {
            return "null";
        }
        return "val";
    }

    def notnone_probe_na(x: any) -> int {
        if x is not None {
            return 1;
        }
        return 0;
    }

    def eqnone_probe_na(x: any) -> int {
        if x == None {
            return 1;
        }
        return 0;
    }

    def nenone_probe_na(x: any) -> int {
        if x != None {
            return 1;
        }
        return 0;
    }

    def truthy_probe_na(x: any) -> str {
        if x {
            return "T";
        }
        return "F";
    }

    def isint_probe_na(x: any) -> int {
        if isinstance(x, int) {
            return 1;
        }
        return 0;
    }

    def typenone_probe_na(x: any) -> int {
        if isinstance(x, type(None)) {
            return 1;
        }
        return 0;
    }

    def dumps_probe_na(val: any) -> str {
        if val is None {
            return "null";
        }
        if isinstance(val, bool) {
            bv: bool = val;
            if bv {
                return "true";
            }
            return "false";
        }
        if isinstance(val, int) {
            iv: int = val;
            return str(iv);
        }
        if isinstance(val, str) {
            sv: str = val;
            return "\"" + sv + "\"";
        }
        if isinstance(val, list) {
            lst: list[any] = val;
            out: str = "[";
            first: int = 1;
            for e in lst {
                if first == 0 {
                    out += ",";
                }
                out += dumps_probe_na(e);
                first = 0;
            }
            return out + "]";
        }
        if isinstance(val, dict) {
            d: dict[str, any] = val;
            out2: str = "{";
            f2: int = 1;
            for k in d {
                if f2 == 0 {
                    out2 += ",";
                }
                out2 += "\"" + k + "\":" + dumps_probe_na(d[k]);
                f2 = 0;
            }
            return out2 + "}";
        }
        return "?";
    }

    def none_consume_check_na -> dict[str, any] {
        n: any = None;
        i0: any = 0;
        i5: any = 5;
        se: any = "";
        ss: any = "s";
        f0: any = 0.0;
        f2: any = 2.5;
        bt: any = True;
        bf: any = False;
        fnan: any = float("nan");
        le: list[any] = [];
        ln: list[any] = [];
        ln.append(1);
        la: any = le;
        lb: any = ln;
        de: dict[str, any] = {};
        dn: dict[str, any] = {};
        dn["a"] = 1;
        da: any = de;
        db: any = dn;
        arr: list[any] = [];
        arr.append(1);
        arr.append("two");
        arr.append(False);
        arr.append(None);
        payload: dict[str, any] = {};
        payload["name"] = "jac";
        payload["n"] = 42;
        payload["ok"] = True;
        payload["nil"] = None;
        payload["arr"] = arr;
        pa: any = payload;
        return {
            "is_none": none_probe_na(n),
            "is_val": none_probe_na(i5),
            "isnot_none": notnone_probe_na(n),
            "isnot_val": notnone_probe_na(i5),
            "eq_none": eqnone_probe_na(n),
            "eq_val": eqnone_probe_na(i5),
            "ne_none": nenone_probe_na(n),
            "ne_val": nenone_probe_na(i5),
            "t_none": truthy_probe_na(n),
            "t_i0": truthy_probe_na(i0),
            "t_i5": truthy_probe_na(i5),
            "t_se": truthy_probe_na(se),
            "t_ss": truthy_probe_na(ss),
            "t_f0": truthy_probe_na(f0),
            "t_f2": truthy_probe_na(f2),
            "t_bt": truthy_probe_na(bt),
            "t_bf": truthy_probe_na(bf),
            "t_fnan": truthy_probe_na(fnan),
            "t_le": truthy_probe_na(la),
            "t_ln": truthy_probe_na(lb),
            "t_de": truthy_probe_na(da),
            "t_dn": truthy_probe_na(db),
            "isinst_none_int": isint_probe_na(n),
            "tn_none": typenone_probe_na(n),
            "tn_val": typenone_probe_na(i5),
            "dumps": dumps_probe_na(pa)
        };
    }
}
