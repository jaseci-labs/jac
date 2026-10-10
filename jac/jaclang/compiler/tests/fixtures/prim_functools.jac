"""Bundled native `functools` cross-backend equivalence fixture.

The SAME `import from functools { ... }` binds CPython's `functools` on the
sv (Python) backend and the bundled `na_stdlib/functools.jac` Mechanism-B
module on the na (native LLVM) backend. The py side exercises CPython's real
call shapes (`lru_cache(fn)` direct decoration, `p(5)`, `kf(1)`); the na side
spells the same operations with explicit `.__call__(...)` on the returned
wrapper objects, because the native call lowering has no general `__call__`
instance dispatch -- `sq(2)` on a `_Lru` object is not callable, but the
method call `sq.__call__(2)` resolves and runs (the same convention the
fixture already uses for `k1.__lt__(k2)` na / `k1 < k2` sv). `cmp_to_key`
results must be invoked INLINE (`cmp_to_key(f).__call__(x)`): the shared
import stamps the local as typeshed `Callable`, so a stored factory gets a
closure slot that wraps the `_KeyFactory` and defeats method dispatch,
while a call-result receiver recovers `_KeyFactory` via value-type
inference. Similarly `p.func(3, 4)` fails (typeshed `partial[Any]` hides
the `func` field from field-call dispatch); extracting `pf = p.func` first
yields a genuine `Callable` local whose `pf(3, 4)` closure call lowers.
Consequently
`lru_cache(fn)` is a TypeError on na -- a function passed through `any` is a
boxed value with no callable tag -- so `sqd`/`sqt` decorate through the
`maxsize=128` factory, which is CPython's default and produces identical
`cache_info`/`cache_parameters` rows. `wraps(f)(w)`/`update_wrapper(w, f)`
return the wrapper as a `Callable`, so `g(4)`/`uw(5)` are plain closure calls
on na. The `@` decorator spelling is NOT exercised: native decorators must
return a bare function pointer, so stateful wrappers
(lru_cache/contextmanager-style) are applied by explicit call on na.

Also kept out of both lanes: `reduce` with an explicit positional
initializer -- the implemented behavior matches CPython (verified by
standalone probes on each lane), but the sv checker resolves every call
spelled against `reduce` to its first overload, so the three-argument form
cannot appear in an equivalence fixture.
Waived on na (declared in test_prim_equivalence.jac `allow_missing`):
`cmp_sort` -- `sorted(key=cmp_to_key(...))` demotes the whole native program
(native sort compares only orderable primitive keys, never `__lt__` objects);
`wraps_name` -- na `wraps`/`update_wrapper` are attribute-copy-free (native
function values carry no attribute table), so the wrapper keeps its own
`__name__`. The `r_none_init` row (an explicit `initializer=None`, which is
indistinguishable from an omitted one natively) stays out of both lanes
entirely for the same reason.
ES/JS opts out.
"""

import from functools {
    reduce,
    partial,
    cmp_to_key,
    lru_cache,
    cache,
    wraps,
    update_wrapper,
    WRAPPER_ASSIGNMENTS,
    WRAPPER_UPDATES
}


def ft_add(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x + y;
}

def ft_sub(a: any, b: any) -> int {
    x: int = a;
    y: int = b;
    return x - y;
}

def ft_cat(a: any, b: any) -> any {
    x: str = a;
    y: str = b;
    return x + y;
}

def ft_mul(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x * y;
}

def ft_square(x: any) -> any {
    v: int = x;
    return v * v;
}

def ft_id(x: any) -> any {
    return x;
}

def ft_mycmp(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    if x < y {
        return -1;
    }
    if x > y {
        return 1;
    }
    return 0;
}

def ft_base(x: any) -> any {
    v: int = x;
    return v + 1;
}

def ft_wrapped(x: any) -> any {
    v: int = x;
    r: any = ft_base(v);
    ri: int = r;
    return ri * 10;
}


"""Helpers referenced ONLY by the na lane. A function name shared between an
sv-lane body and a na-lane body resolves to the sv binding in the na lane, so
passing `ft_*` as a `Callable` argument emits a null closure and the callee
jumps through a dead pointer. `ftn_*` copies keep the na lane's callables
native."""

def ftn_add(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x + y;
}

def ftn_cat(a: any, b: any) -> any {
    x: str = a;
    y: str = b;
    return x + y;
}

def ftn_mul(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x * y;
}

def ftn_square(x: any) -> any {
    v: int = x;
    return v * v;
}

def ftn_id(x: any) -> any {
    return x;
}

def ftn_mycmp(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    if x < y {
        return -1;
    }
    if x > y {
        return 1;
    }
    return 0;
}

def ftn_base(x: any) -> any {
    v: int = x;
    return v + 1;
}

def ftn_wrapped(x: any) -> any {
    v: int = x;
    r: any = ftn_base(v);
    ri: int = r;
    return ri * 10;
}


def functools_py -> dict[any, any] {
    r_empty = "no raise";
    try {
        reduce(ft_add, []);
    } except Exception as e {
        r_empty = type(e).__name__ + ": " + str(e);
    }
    p = partial(ft_mul, 10);
    kf = cmp_to_key(ft_mycmp);
    k1: any = kf(1);
    k2: any = kf(2);
    k1b: any = kf(1);
    sq = lru_cache(maxsize=2)(ft_square);
    sq(2);
    sq(3);
    sq(2);
    sq(3);
    sq(4);
    ci = sq.cache_info();
    sqd: any = lru_cache(ft_square);
    sqd(5);
    sqd(5);
    sqd(6);
    cid = sqd.cache_info();
    ub = cache(ft_square);
    ub(7);
    ub(7);
    ub(8);
    ciu = ub.cache_info();
    lru0 = lru_cache(maxsize=0)(ft_square);
    lru0(9);
    lru0(9);
    ci0 = lru0.cache_info();
    sq.cache_clear();
    cic = sq.cache_info();
    g = wraps(ft_base)(ft_wrapped);
    sq2 = lru_cache(4)(ft_square);
    sq2(1);
    ci2 = sq2.cache_info();
    sqn = lru_cache(maxsize=-3)(ft_square);
    sqn(1);
    cin = sqn.cache_info();
    sqt: any = lru_cache(ft_id);
    sqt(1);
    sqt(1.0);
    cit = sqt.cache_info();
    sqt2: any = lru_cache(ft_square, typed=True);
    uw = update_wrapper(ft_wrapped, ft_base);
    cp = sqd.cache_parameters();
    unhash = "no raise";
    try {
        sqd([1]);
    } except Exception as e {
        unhash = type(e).__name__ + ": " + str(e);
    }
    return {
        "r_sum": reduce(ft_add, [1, 2, 3, 4, 5]),
        "r_cat": reduce(ft_cat, ["a", "b", "c"]),
        "r_empty": r_empty,
        "partial": p(5),
        "partial_func": p.func(3, 4),
        "partial_args": p.args[0],
        "partial_kw": len(p.keywords),
        "ckey_obj": k1.obj,
        "ckey_lt": str(k1 < k2) + str(k2 < k1) + str(k1 < k1b),
        "ckey_eq": str(k1 == k1b) + str(k1 == k2),
        "ckey_ne": str(k1 != k2) + str(k1 != k1b),
        "lru_val": sq(3),
        "lru_info": str(ci.hits)
            + ","
            + str(ci.misses)
            + ","
            + str(ci.currsize)
            + ","
            + str(ci.maxsize),
        "lru_def": str(cid.hits)
            + ","
            + str(cid.misses)
            + ","
            + str(cid.currsize)
            + ","
            + str(cid.maxsize),
        "lru_pos_max": str(ci2.maxsize),
        "lru_neg": str(cin.maxsize),
        "lru_typed": sqt2(3),
        "lru_typed_eq": str(cit.hits),
        "cache_unb": str(ciu.hits)
            + ","
            + str(ciu.misses)
            + ","
            + str(ciu.currsize)
            + ","
            + str(ciu.maxsize),
        "lru_zero": str(ci0.hits) + "," + str(ci0.misses) + "," + str(ci0.currsize),
        "lru_clear": str(cic.hits) + "," + str(cic.misses) + "," + str(cic.currsize),
        "cp_def": str(cp["maxsize"]) + "," + str(cp["typed"]),
        "unhash": unhash,
        "wraps_call": g(4),
        "wraps_name": wraps(ft_base)(ft_wrapped).__name__,
        "uw_call": uw(5),
        "wa_len": len(WRAPPER_ASSIGNMENTS),
        "wa_first": WRAPPER_ASSIGNMENTS[0],
        "wu_len": len(WRAPPER_UPDATES),
        "cmp_sort": str(sorted([3, 1, 2], key=cmp_to_key(ft_mycmp)))
    };
}


def functools_cl -> dict[any, any] {
    return {};
}


def functools_na -> dict[str, any] {
    r_empty = "no raise";
    try {
        reduce(ftn_add, []);
    } except TypeError as e {
        r_empty = "TypeError: " + str(e);
    } except Exception as e {
        r_empty = "WRONG-TYPE: " + str(e);
    }
    p = partial(ftn_mul, 10);
    k1 = cmp_to_key(ftn_mycmp).__call__(1);
    k2 = cmp_to_key(ftn_mycmp).__call__(2);
    k1b = cmp_to_key(ftn_mycmp).__call__(1);
    sq = lru_cache(maxsize=2).__call__(ftn_square);
    sq.__call__(2);
    sq.__call__(3);
    sq.__call__(2);
    sq.__call__(3);
    sq.__call__(4);
    ci = sq.cache_info();
    # `lru_cache(fn)` direct decoration raises TypeError on na (a function
    # passed through `any` cannot be recovered as a callable); the factory
    # form with CPython's default maxsize=128 is the equivalent shape.
    sqd = lru_cache(maxsize=128).__call__(ftn_square);
    sqd.__call__(5);
    sqd.__call__(5);
    sqd.__call__(6);
    cid = sqd.cache_info();
    ub = cache(ftn_square);
    ub.__call__(7);
    ub.__call__(7);
    ub.__call__(8);
    ciu = ub.cache_info();
    lru0 = lru_cache(maxsize=0).__call__(ftn_square);
    lru0.__call__(9);
    lru0.__call__(9);
    ci0 = lru0.cache_info();
    sq.cache_clear();
    cic = sq.cache_info();
    g = wraps(ftn_base).__call__(ftn_wrapped);
    sq2 = lru_cache(4).__call__(ftn_square);
    sq2.__call__(1);
    ci2 = sq2.cache_info();
    sqn = lru_cache(maxsize=-3).__call__(ftn_square);
    sqn.__call__(1);
    cin = sqn.cache_info();
    sqt = lru_cache(maxsize=128).__call__(ftn_id);
    sqt.__call__(1);
    sqt.__call__(1.0);
    cit = sqt.cache_info();
    sqt2 = lru_cache(maxsize=128, typed=True).__call__(ftn_square);
    uw = update_wrapper(ftn_wrapped, ftn_base);
    cp = sqd.cache_parameters();
    pf = p.func;
    unhash = "no raise";
    try {
        sqd.__call__([1]);
    } except TypeError as e {
        unhash = "TypeError: " + str(e);
    } except Exception as e {
        unhash = "WRONG-TYPE: " + str(e);
    }
    return {
        "r_sum": reduce(ftn_add, [1, 2, 3, 4, 5]),
        "r_cat": reduce(ftn_cat, ["a", "b", "c"]),
        "r_empty": r_empty,
        "partial": p.__call__(5),
        "partial_func": pf(3, 4),
        "partial_args": p.args[0],
        "partial_kw": len(p.keywords),
        "ckey_obj": k1.obj,
        "ckey_lt": str(k1.__lt__(k2)) + str(k2.__lt__(k1)) + str(k1.__lt__(k1b)),
        "ckey_eq": str(k1.__eq__(k1b)) + str(k1.__eq__(k2)),
        "ckey_ne": str(k1.__ne__(k2)) + str(k1.__ne__(k1b)),
        "lru_val": sq.__call__(3),
        "lru_info": str(ci.hits)
            + ","
            + str(ci.misses)
            + ","
            + str(ci.currsize)
            + ","
            + str(ci.maxsize),
        "lru_def": str(cid.hits)
            + ","
            + str(cid.misses)
            + ","
            + str(cid.currsize)
            + ","
            + str(cid.maxsize),
        "lru_pos_max": str(ci2.maxsize),
        "lru_neg": str(cin.maxsize),
        "lru_typed": sqt2.__call__(3),
        "lru_typed_eq": str(cit.hits),
        "cache_unb": str(ciu.hits)
            + ","
            + str(ciu.misses)
            + ","
            + str(ciu.currsize)
            + ","
            + str(ciu.maxsize),
        "lru_zero": str(ci0.hits) + "," + str(ci0.misses) + "," + str(ci0.currsize),
        "lru_clear": str(cic.hits) + "," + str(cic.misses) + "," + str(cic.currsize),
        "cp_def": str(cp["maxsize"]) + "," + str(cp["typed"]),
        "unhash": unhash,
        "wraps_call": g(4),
        "uw_call": uw(5),
        "wa_len": len(WRAPPER_ASSIGNMENTS),
        "wa_first": WRAPPER_ASSIGNMENTS[0],
        "wu_len": len(WRAPPER_UPDATES)
    };
}
