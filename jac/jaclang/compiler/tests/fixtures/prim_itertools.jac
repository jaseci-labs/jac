"""Bundled native `itertools` cross-backend equivalence fixture (#8145).

The SAME `import from itertools { ... }` binds CPython 3.14's `itertools` on
the sv (Python) backend and the bundled `na_stdlib/itertools.jac`
Mechanism-B module on the na (native LLVM) backend. Every iterator is
materialized with `list(...)` before the digest helpers see it because a
boxed `any` only iterates as a list on na, and the helpers reduce rows to
order-preserving strings/lengths.

Every helper and callback exists twice (`_py` / `_na` suffixed): the sv lane
must never call a native-placed function (the call would dispatch through
ctypes and crash), while the na lane's pinned helpers must stay native or
they fall out of the JIT engine. Only the `_na` twins carry placement pins.

Known documented divergences stay out of the fixture: the
`chain.from_iterable` operation (na exposes `chain_from_iterable` as a
module function; the classmethod spelling does not typecheck against the
bundled module -- probed manually per lane and documented in README),
`zip_longest()` with zero iterables (legal at runtime on both backends, but
the stub requires `iter1`, so the row cannot be spelled for the sv lane),
`islice` with a float step / zero / five arguments (the sv checker
enforces the typeshed signature, and the float-through-Callable form does
not lower on na; the module's matching TypeErrors and ValueError are
probed standalone), `groupby` group objects
(materialized list snapshots on na, lazily invalidated iterators on
CPython), `tee` children (independent list copies on na -- re-iterable
where CPython's are one-shot iterators), `starmap` arity (exactly-2
callable on na), and row container type (`list` snapshots on na where
CPython yields tuples).
ES/JS opts out.
"""

import itertools;

import from itertools {
    count,
    cycle,
    repeat,
    accumulate,
    chain,
    compress,
    dropwhile,
    takewhile,
    filterfalse,
    groupby,
    islice,
    pairwise,
    starmap,
    product,
    permutations,
    combinations,
    combinations_with_replacement,
    zip_longest,
    batched,
    tee
}


def lt3_py(x: any) -> any {
    xi: int = x;
    return xi < 3;
}

def lt3_na(x: any) -> any {
    xi: int = x;
    return xi < 3;
}

def parity_py(x: any) -> any {
    xi: int = x;
    return xi % 2;
}

def parity_na(x: any) -> any {
    xi: int = x;
    return xi % 2;
}

def mypow_py(a: any, b: any) -> any {
    ai: int = a;
    bi: int = b;
    r = 1;
    for i in range(bi) {
        r *= ai;
    }
    return r;
}

def mypow_na(a: any, b: any) -> any {
    ai: int = a;
    bi: int = b;
    r = 1;
    for i in range(bi) {
        r *= ai;
    }
    return r;
}

def accsub_py(a: any, b: any) -> any {
    ai: int = a;
    bi: int = b;
    return ai - bi;
}

def accsub_na(a: any, b: any) -> any {
    ai: int = a;
    bi: int = b;
    return ai - bi;
}


def _jints_py(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for v in vals {
        if isinstance(v, int) {
            iv: int = v;
            s += str(iv) + ";";
        } elif isinstance(v, float) {
            fv: float = v;
            s += str(fv) + ";";
        } else {
            s += "N;";
        }
    }
    out[tag] = s;
}

def _jints_na(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for v in vals {
        if isinstance(v, int) {
            iv: int = v;
            s += str(iv) + ";";
        } elif isinstance(v, float) {
            fv: float = v;
            s += str(fv) + ";";
        } else {
            s += "N;";
        }
    }
    out[tag] = s;
}

def _jpairs2_py(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        a = t[0];
        b = t[1];
        if isinstance(a, int) {
            aa: int = a;
            s += str(aa);
        } else {
            s += str(a);
        }
        s += ",";
        if isinstance(b, int) {
            bb: int = b;
            s += str(bb);
        } else {
            s += str(b);
        }
        s += "|";
    }
    out[tag] = s;
}

def _jpairs2_na(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        a = t[0];
        b = t[1];
        if isinstance(a, int) {
            aa: int = a;
            s += str(aa);
        } else {
            s += str(a);
        }
        s += ",";
        if isinstance(b, int) {
            bb: int = b;
            s += str(bb);
        } else {
            s += str(b);
        }
        s += "|";
    }
    out[tag] = s;
}

def _jpairs3_py(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        for i in range(3) {
            e = t[i];
            if isinstance(e, int) {
                ee: int = e;
                s += str(ee);
            } else {
                s += str(e);
            }
            s += ",";
        }
        s += "|";
    }
    out[tag] = s;
}

def _jpairs3_na(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        for i in range(3) {
            e = t[i];
            if isinstance(e, int) {
                ee: int = e;
                s += str(ee);
            } else {
                s += str(e);
            }
            s += ",";
        }
        s += "|";
    }
    out[tag] = s;
}

def _gb_py(it: any) -> list[any] {
    # CPython's groupby yields lazy groupers that invalidate when the next
    # group starts; materialize each eagerly while it is still valid.
    rows: list[any] = [];
    for t in it {
        rows.append([t[0], list(t[1])]);
    }
    return rows;
}


def _jgrouped_py(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        k = t[0];
        if isinstance(k, int) {
            kk: int = k;
            s += str(kk);
        } else {
            s += str(k);
        }
        s += ":[";
        g = t[1];
        for v in g {
            if isinstance(v, int) {
                vv: int = v;
                s += str(vv) + " ";
            } else {
                s += str(v) + " ";
            }
        }
        s += "]|";
    }
    out[tag] = s;
}

def _jgrouped_na(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        k = t[0];
        if isinstance(k, int) {
            kk: int = k;
            s += str(kk);
        } else {
            s += str(k);
        }
        s += ":[";
        g = t[1];
        for v in g {
            if isinstance(v, int) {
                vv: int = v;
                s += str(vv) + " ";
            } else {
                s += str(v) + " ";
            }
        }
        s += "]|";
    }
    out[tag] = s;
}

def _jbatches_py(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        for i in range(len(t)) {
            e = t[i];
            if isinstance(e, int) {
                ee: int = e;
                s += str(ee);
            } else {
                s += str(e);
            }
            s += ",";
        }
        s += "|";
    }
    out[tag] = s;
}

def _jbatches_na(out: dict[str, any], tag: str, vals: any) {
    s = "";
    for t in vals {
        for i in range(len(t)) {
            e = t[i];
            if isinstance(e, int) {
                ee: int = e;
                s += str(ee);
            } else {
                s += str(e);
            }
            s += ",";
        }
        s += "|";
    }
    out[tag] = s;
}

def _err_py(out: dict[str, any], tag: str, f: Callable[[], any]) {
    try {
        f();
        out[tag] = "no-raise";
    } except ValueError {
        out[tag] = "ValueError";
    } except TypeError {
        out[tag] = "TypeError";
    }
}

def _collect_na[C: Iterable](src: C) -> list[any] {
    got: list[any] = [];
    for v in src {
        got.append(v);
    }
    return got;
}

def _err_na(out: dict[str, any], tag: str, f: Callable[[], any]) {
    try {
        f();
        out[tag] = "no-raise";
    } except ValueError {
        out[tag] = "ValueError";
    } except TypeError {
        out[tag] = "TypeError";
    }
}

def core_py -> dict[str, any] {
    d: dict[str, any] = {};
    _jints_py(d, "count_int", list(islice(count(2, 3), 4)));
    _jints_py(d, "count_float", list(islice(count(1.0, 0.5), 3)));
    _jints_py(d, "count_neg", list(islice(count(10, -3), 3)));
    _jints_py(d, "cycle", list(islice(cycle([1, 2, 3]), 7)));
    _jints_py(d, "cycle_empty", list(islice(cycle([]), 3)));
    _jints_py(d, "repeat3", list(repeat(7, 3)));
    _jints_py(d, "repeat_inf", list(islice(repeat(9), 2)));
    _jints_py(d, "repeat_neg", list(repeat(5, -2)));
    _jints_py(d, "acc", list(accumulate([1, 2, 3, 4])));
    _jints_py(d, "acc_init", list(accumulate([1, 2, 3], initial=10)));
    _jints_py(d, "acc_func", list(accumulate([5, 3, 2], accsub_py)));
    _jints_py(d, "acc_empty", list(accumulate([])));
    _jints_py(d, "acc_init_empty", list(accumulate([], initial=42)));
    _jints_py(d, "chain", list(chain([1, 2], [3], [4, 5])));
    d["chain_none"] = len(list(chain()));
    _jints_py(d, "compress", list(compress([1, 2, 3, 4, 5, 6], [1, 0, 1, 1, 0, 1])));
    _jints_py(d, "compress_bool", list(compress([10, 20, 30], [True, False, True])));
    _jints_py(d, "compress_short", list(compress([1, 2, 3], [1, 0])));
    _jints_py(d, "dw", list(dropwhile(lt3_py, [1, 3, 2, 4, 0])));
    _jints_py(d, "tw", list(takewhile(lt3_py, [1, 3, 2, 4, 0])));
    _jints_py(d, "ff", list(filterfalse(lt3_py, [1, 3, 2, 4, 0])));
    _jints_py(d, "ff_none", list(filterfalse(None, [0, 1, 0, 2])));
    _jgrouped_py(d, "groupby", _gb_py(groupby("AAABBC")));
    _jgrouped_py(d, "groupby_key", _gb_py(groupby([2, 4, 6, 3, 9], key=parity_py)));
    _jgrouped_py(d, "groupby_empty", _gb_py(groupby([])));
    _jints_py(d, "islice_sn", list(islice([0, 1, 2, 3, 4, 5, 6], 2, None)));
    _jints_py(d, "islice_ab", list(islice([0, 1, 2, 3, 4, 5, 6], 2, 6)));
    _jints_py(d, "islice_step", list(islice([0, 1, 2, 3, 4, 5, 6], 0, None, 2)));
    _jints_py(d, "islice_def", list(islice([0, 1, 2, 3, 4, 5, 6], 3)));
    _jints_py(d, "islice_none", list(islice([0, 1, 2], None)));
    _jints_py(d, "islice_past", list(islice([0, 1], 5, 10)));
    _jints_py(d, "repeat0", list(repeat(3, 0)));
    _jpairs2_py(d, "pairwise", list(pairwise([1, 2, 3, 4])));
    _jpairs2_py(d, "pairwise_empty", list(pairwise([])));
    return d;
}


def core_na -> dict[str, any] {
    d: dict[str, any] = {};
    _jints_na(d, "count_int", _collect_na(islice(count(2, 3), 4)));
    _jints_na(d, "count_float", _collect_na(islice(count(1.0, 0.5), 3)));
    _jints_na(d, "count_neg", _collect_na(islice(count(10, -3), 3)));
    _jints_na(d, "cycle", _collect_na(islice(cycle([1, 2, 3]), 7)));
    _jints_na(d, "cycle_empty", _collect_na(islice(cycle([]), 3)));
    _jints_na(d, "repeat3", _collect_na(repeat(7, 3)));
    _jints_na(d, "repeat_inf", _collect_na(islice(repeat(9), 2)));
    _jints_na(d, "repeat_neg", _collect_na(repeat(5, -2)));
    _jints_na(d, "acc", _collect_na(accumulate([1, 2, 3, 4])));
    _jints_na(d, "acc_init", _collect_na(accumulate([1, 2, 3], initial=10)));
    _jints_na(d, "acc_func", _collect_na(accumulate([5, 3, 2], accsub_na)));
    _jints_na(d, "acc_empty", _collect_na(accumulate([])));
    _jints_na(d, "acc_init_empty", _collect_na(accumulate([], initial=42)));
    ch_a: list[any] = [1, 2];
    ch_b: list[any] = [3];
    ch_c: list[any] = [4, 5];
    _jints_na(d, "chain", _collect_na(chain(ch_a, ch_b, ch_c)));
    d["chain_none"] = len(_collect_na(chain()));
    _jints_na(
        d, "compress", _collect_na(compress([1, 2, 3, 4, 5, 6], [1, 0, 1, 1, 0, 1]))
    );
    _jints_na(
        d, "compress_bool", _collect_na(compress([10, 20, 30], [True, False, True]))
    );
    _jints_na(d, "compress_short", _collect_na(compress([1, 2, 3], [1, 0])));
    _jints_na(d, "dw", _collect_na(dropwhile(lt3_na, [1, 3, 2, 4, 0])));
    _jints_na(d, "tw", _collect_na(takewhile(lt3_na, [1, 3, 2, 4, 0])));
    _jints_na(d, "ff", _collect_na(filterfalse(lt3_na, [1, 3, 2, 4, 0])));
    _jints_na(d, "ff_none", _collect_na(filterfalse(None, [0, 1, 0, 2])));
    _jgrouped_na(d, "groupby", _collect_na(groupby("AAABBC")));
    _jgrouped_na(
        d, "groupby_key", _collect_na(groupby([2, 4, 6, 3, 9], key=parity_na))
    );
    _jgrouped_na(d, "groupby_empty", _collect_na(groupby([])));
    _jints_na(d, "islice_sn", _collect_na(islice([0, 1, 2, 3, 4, 5, 6], 2, None)));
    _jints_na(d, "islice_ab", _collect_na(islice([0, 1, 2, 3, 4, 5, 6], 2, 6)));
    _jints_na(d, "islice_step", _collect_na(islice([0, 1, 2, 3, 4, 5, 6], 0, None, 2)));
    _jints_na(d, "islice_def", _collect_na(islice([0, 1, 2, 3, 4, 5, 6], 3)));
    _jints_na(d, "islice_none", _collect_na(islice([0, 1, 2], None)));
    _jints_na(d, "islice_past", _collect_na(islice([0, 1], 5, 10)));
    _jints_na(d, "repeat0", _collect_na(repeat(3, 0)));
    _jpairs2_na(d, "pairwise", _collect_na(pairwise([1, 2, 3, 4])));
    _jpairs2_na(d, "pairwise_empty", _collect_na(pairwise([])));
    return d;
}


def comb_py -> dict[str, any] {
    d: dict[str, any] = {};
    _jints_py(d, "starmap", list(starmap(mypow_py, [[2, 3], [3, 2]])));
    _jpairs2_py(d, "prod2", list(product([1, 2], [3, 4])));
    d["prod0"] = len(list(product()));
    d["prod_empty"] = len(list(product([])));
    _jpairs2_py(d, "prod_rep", list(product("AB", repeat=2)));
    d["prod_rep0_len"] = len(list(product([1, 2], repeat=0)));
    d["prod_rep3_len"] = len(list(product([1, 2], repeat=3)));
    _jpairs3_py(d, "perm3", list(permutations("ABC")));
    _jpairs2_py(d, "perm_r2", list(permutations("ABC", 2)));
    d["perm_r0"] = len(list(permutations("ABC", 0)));
    d["perm_empty0"] = len(list(permutations([], 0)));
    d["perm_rbig"] = len(list(permutations("AB", 3)));
    _jpairs2_py(d, "comb", list(combinations("ABC", 2)));
    _jpairs3_py(d, "comb4", list(combinations([1, 2, 3, 4], 3)));
    d["comb_r0"] = len(list(combinations("AB", 0)));
    d["comb_rbig"] = len(list(combinations("AB", 3)));
    _jpairs3_py(d, "cwr", list(combinations_with_replacement("AB", 3)));
    d["cwr_r0"] = len(list(combinations_with_replacement("AB", 0)));
    d["cwr_empty"] = len(list(combinations_with_replacement([], 2)));
    _jpairs2_py(d, "zl", list(zip_longest([1, 2], [10, 20, 30, 40])));
    _jpairs2_py(d, "zl_fill", list(zip_longest("AB", "1234", fillvalue="-")));
    _jpairs2_py(d, "zl_oneside", list(zip_longest([], [1, 2])));
    _jbatches_py(d, "batched", list(batched([1, 2, 3, 4, 5], 2)));
    d["batched_lens"] = len(list(batched([1, 2, 3, 4, 5], 2)));
    t2 = tee([1, 2, 3]);
    _jints_py(d, "tee_a", t2[0]);
    _jints_py(d, "tee_b", t2[1]);
    d["tee3_len"] = len(tee([1, 2], 3));
    d["tee0_len"] = len(tee([1, 2], 0));
    return d;
}


def comb_na -> dict[str, any] {
    d: dict[str, any] = {};
    _jints_na(d, "starmap", _collect_na(starmap(mypow_na, [[2, 3], [3, 2]])));
    pr_a: list[any] = [1, 2];
    pr_b: list[any] = [3, 4];
    pr_e: list[any] = [];
    _jpairs2_na(d, "prod2", _collect_na(product(pr_a, pr_b)));
    d["prod0"] = len(_collect_na(product()));
    d["prod_empty"] = len(_collect_na(product(pr_e)));
    _jpairs2_na(d, "prod_rep", _collect_na(product("AB", repeat=2)));
    d["prod_rep0_len"] = len(_collect_na(product(pr_a, repeat=0)));
    d["prod_rep3_len"] = len(_collect_na(product(pr_a, repeat=3)));
    _jpairs3_na(d, "perm3", _collect_na(permutations("ABC")));
    _jpairs2_na(d, "perm_r2", _collect_na(permutations("ABC", 2)));
    d["perm_r0"] = len(_collect_na(permutations("ABC", 0)));
    d["perm_empty0"] = len(_collect_na(permutations([], 0)));
    d["perm_rbig"] = len(_collect_na(permutations("AB", 3)));
    _jpairs2_na(d, "comb", _collect_na(combinations("ABC", 2)));
    _jpairs3_na(d, "comb4", _collect_na(combinations([1, 2, 3, 4], 3)));
    d["comb_r0"] = len(_collect_na(combinations("AB", 0)));
    d["comb_rbig"] = len(_collect_na(combinations("AB", 3)));
    _jpairs3_na(d, "cwr", _collect_na(combinations_with_replacement("AB", 3)));
    d["cwr_r0"] = len(_collect_na(combinations_with_replacement("AB", 0)));
    d["cwr_empty"] = len(_collect_na(combinations_with_replacement([], 2)));
    zl_a: list[any] = [1, 2];
    zl_b: list[any] = [10, 20, 30, 40];
    zl_e: list[any] = [];
    zl_o: list[any] = [1, 2];
    _jpairs2_na(d, "zl", _collect_na(zip_longest(zl_a, zl_b)));
    _jpairs2_na(d, "zl_fill", _collect_na(zip_longest("AB", "1234", fillvalue="-")));
    _jpairs2_na(d, "zl_oneside", _collect_na(zip_longest(zl_e, zl_o)));
    _jbatches_na(d, "batched", _collect_na(batched([1, 2, 3, 4, 5], 2)));
    d["batched_lens"] = len(_collect_na(batched([1, 2, 3, 4, 5], 2)));
    t2 = tee([1, 2, 3]);
    _jints_na(d, "tee_a", t2[0]);
    _jints_na(d, "tee_b", t2[1]);
    d["tee3_len"] = len(tee([1, 2], 3));
    d["tee0_len"] = len(tee([1, 2], 0));
    return d;
}


def iter_err_py -> dict[str, any] {
    d: dict[str, any] = {};
    _err_py(d, "islice_neg", lambda() -> any { islice([1], -1); });
    _err_py(d, "islice_step0", lambda() -> any { islice([1], 0, 5, 0); });
    _err_py(d, "islice_float", lambda() -> any { islice([1], 1.5); });
    _err_py(d, "prod_neg", lambda() -> any { product([1], repeat=-1); });
    _err_py(d, "perm_neg", lambda() -> any { permutations("AB", -1); });
    _err_py(d, "comb_neg", lambda() -> any { combinations("AB", -1); });
    _err_py(d, "cwr_neg", lambda() -> any { combinations_with_replacement("AB", -1); });
    _err_py(
        d,
        "batched_strict",
        lambda() -> any { list(batched([1, 2, 3], 2, strict=True)); }
    );
    _err_py(d, "batched_n0", lambda() -> any { batched([1], 0); });
    _err_py(d, "tee_neg", lambda() -> any { tee([1], -1); });
    return d;
}


def iter_err_na -> dict[str, any] {
    d: dict[str, any] = {};
    _err_na(d, "islice_neg", lambda() -> any { islice([1], -1); });
    _err_na(d, "islice_step0", lambda() -> any { islice([1], 0, 5, 0); });
    _err_na(d, "islice_float", lambda() -> any { islice([1], 1.5); });
    pr_neg: list[any] = [1];
    _err_na(d, "prod_neg", lambda() -> any { product(pr_neg, repeat=-1); });
    _err_na(d, "perm_neg", lambda() -> any { permutations("AB", -1); });
    _err_na(d, "comb_neg", lambda() -> any { combinations("AB", -1); });
    _err_na(d, "cwr_neg", lambda() -> any { combinations_with_replacement("AB", -1); });
    _err_na(
        d,
        "batched_strict",
        lambda() -> any { _collect_na(batched([1, 2, 3], 2, strict=True)); }
    );
    _err_na(d, "batched_n0", lambda() -> any { batched([1], 0); });
    _err_na(d, "tee_neg", lambda() -> any { tee([1], -1); });
    return d;
}


def itertools_py -> dict[str, any] {
    d = core_py();
    c = comb_py();
    for k in c {
        d[k] = c[k];
    }
    e = iter_err_py();
    for k in e {
        d[k] = e[k];
    }
    return d;
}


def itertools_na -> dict[str, any] {
    d = core_na();
    c = comb_na();
    for k in c {
        d[k] = c[k];
    }
    e = iter_err_na();
    for k in e {
        d[k] = e[k];
    }
    return d;
}


def itertools_cl -> dict[str, any] {
    return {};
}
