def _tolist[C: Iterable](src: C) -> list[any];

def _tolist_any(src: any) -> list[any];

def _add_default(a: any, b: any) -> any;

def:pub count(start: int | float = 0, step: int | float = 1) -> Iterator[any];

def _count_gen(start: int | float, step: int | float) -> Iterator[any];

def:pub cycle[C: Iterable](iterable: C) -> Iterator[any];

def _cycle_gen[C: Iterable](src: C) -> Iterator[any];

def:pub repeat(object: any, times: int | None = None) -> Iterator[any];

def _repeat_gen(x: any, times: int | None) -> Iterator[any];

def:pub accumulate[C: Iterable](
    iterable: C, func: (Callable[[any, any], any] | None) = None, *, initial: any = None
) -> Iterator[any];

def _accumulate_gen[C: Iterable](
    src: C, func: (Callable[[any, any], any] | None), initial: any
) -> Iterator[any];

def _accumulate_default[C: Iterable](src: C, initial: any) -> Iterator[any];

def _accumulate_func[C: Iterable](
    src: C, func: Callable[[any, any], any], initial: any
) -> Iterator[any];

def:pub chain(*iterables: any) -> Iterator[any];

def chain_from_iterable[C: Iterable](iterable: C) -> Iterator[any];

def _chain_fi_gen[C: Iterable](src: C) -> Iterator[any];

def:pub compress[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any];

def _compress_gen[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any];

def:pub dropwhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any];

def _dropwhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any];

def:pub takewhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any];

def _takewhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any];

def:pub filterfalse[C: Iterable](
    predicate: (Callable[[any], any] | None), iterable: C
) -> Iterator[any];

def _filterfalse_gen[C: Iterable](
    pred: (Callable[[any], any] | None), src: C
) -> Iterator[any];

def _ff_none[C: Iterable](src: C) -> Iterator[any];

def _ff_pred[C: Iterable](src: C, pred: Callable[[any], any]) -> Iterator[any];

def:pub groupby[C: Iterable](
    iterable: C, key: (Callable[[any], any] | None) = None
) -> Iterator[any];

def _groupby_gen[C: Iterable](
    src: C, key: (Callable[[any], any] | None)
) -> Iterator[any];

def _grouped_nokey[C: Iterable](src: C) -> Iterator[any];

def _grouped_key[C: Iterable](src: C, key: Callable[[any], any]) -> Iterator[any];

def:pub islice[C: Iterable](iterable: C, *args: any) -> Iterator[any];

def _islice_gen[C: Iterable](
    src: C, start: int, stop: int, step: int
) -> Iterator[any];

def:pub pairwise[C: Iterable](iterable: C) -> Iterator[any];

def _pairwise_gen[C: Iterable](src: C) -> Iterator[any];

def:pub starmap[C: Iterable](
    func: Callable[[any, any], any], iterable: C
) -> Iterator[any];

def _starmap_gen[C: Iterable](
    func: Callable[[any, any], any], src: C
) -> Iterator[any];

def:pub product(*iterables: any, repeat: int = 1) -> Iterator[any];

def _product_gen(pools: list[list[any]]) -> Iterator[any];

def:pub permutations[C: Iterable](iterable: C, r: int | None = None) -> Iterator[any];

def _perm_gen(pool: list[any], r: int) -> Iterator[any];

def:pub combinations[C: Iterable](iterable: C, r: int) -> Iterator[any];

def _comb_gen(pool: list[any], r: int) -> Iterator[any];

def:pub combinations_with_replacement[C: Iterable](
    iterable: C, r: int
) -> Iterator[any];

def _cwr_gen(pool: list[any], r: int) -> Iterator[any];

def:pub batched[C: Iterable](
    iterable: C, n: int, *, strict: bool = False
) -> Iterator[any];

def _batched_gen[C: Iterable](src: C, n: int, strict: bool) -> Iterator[any];

def:pub zip_longest(*iterables: any, fillvalue: any = None) -> Iterator[any];

def _zip_longest_gen(pools: list[list[any]], fillvalue: any) -> Iterator[any];

def:pub tee[C: Iterable](iterable: C, n: int = 2) -> list[any];

impl _tolist[C: Iterable](src: C) -> list[any] {
    out: list[any] = [];
    for v in src {
        out.append(v);
    }
    return out;
}

impl cycle[C: Iterable](iterable: C) -> Iterator[any] {
    return _cycle_gen(iterable);
}

impl _cycle_gen[C: Iterable](src: C) -> Iterator[any] {
    saved: list[any] = [];
    for v in src {
        saved.append(v);
        yield v;
    }
    n = len(saved);
    i = 0;
    while n > 0 {
        yield saved[i];
        i += 1;
        if i >= n {
            i = 0;
        }
    }
}

impl accumulate[C: Iterable](
    iterable: C, func: (Callable[[any, any], any] | None) = None, *, initial: any = None
) -> Iterator[any] {
    return _accumulate_gen(iterable, func, initial);
}

impl _accumulate_gen[C: Iterable](
    src: C, func: (Callable[[any, any], any] | None), initial: any
) -> Iterator[any] {
    if func is None {
        return _accumulate_default(src, initial);
    }
    return _accumulate_func(src, func, initial);
}

impl _accumulate_default[C: Iterable](src: C, initial: any) -> Iterator[any] {
    total: any = initial;
    started = not (initial is None);
    if started {
        yield total;
    }
    for v in src {
        if started {
            if isinstance(total, int) and isinstance(v, int) {
                ti: int = total;
                vi: int = v;
                total = ti + vi;
            } elif isinstance(total, float) {
                tf: float = total;
                if isinstance(v, float) {
                    vf: float = v;
                    total = tf + vf;
                } elif isinstance(v, int) {
                    vi2: int = v;
                    total = tf + float(vi2);
                } else {
                    total = _add_default(total, v);
                }
            } else {
                total = _add_default(total, v);
            }
        } else {
            total = v;
            started = True;
        }
        yield total;
    }
}

impl _accumulate_func[C: Iterable](
    src: C, func: Callable[[any, any], any], initial: any
) -> Iterator[any] {
    total: any = initial;
    started = not (initial is None);
    if started {
        yield total;
    }
    for v in src {
        if started {
            total = func(total, v);
        } else {
            total = v;
            started = True;
        }
        yield total;
    }
}

impl chain_from_iterable[C: Iterable](iterable: C) -> Iterator[any] {
    return _chain_fi_gen(iterable);
}

impl _chain_fi_gen[C: Iterable](src: C) -> Iterator[any] {
    for it in src {
        if isinstance(it, str) {
            sv: str = it;
            for v in sv {
                yield v;
            }
        } else {
            if not isinstance(it, list) {
                raise TypeError(
                    "itertools: variadic arguments must be lists or str on the native pathway"
                );
            }
            for v in it {
                yield v;
            }
        }
    }
}

impl compress[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any] {
    return _compress_gen(data, selectors);
}

impl _compress_gen[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any] {
    for pair in zip(data, selectors) {
        s = pair[1];
        if bool(s) {
            yield pair[0];
        }
    }
}

impl dropwhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any] {
    return _dropwhile_gen(predicate, iterable);
}

impl _dropwhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any] {
    skipping = True;
    for v in src {
        if skipping {
            if not bool(pred(v)) {
                skipping = False;
                yield v;
            }
        } else {
            yield v;
        }
    }
}

impl takewhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any] {
    return _takewhile_gen(predicate, iterable);
}

impl _takewhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any] {
    keeping = True;
    for v in src {
        if keeping {
            if bool(pred(v)) {
                yield v;
            } else {
                keeping = False;
            }
        }
    }
}

impl filterfalse[C: Iterable](
    predicate: (Callable[[any], any] | None), iterable: C
) -> Iterator[any] {
    return _filterfalse_gen(predicate, iterable);
}

impl _filterfalse_gen[C: Iterable](
    pred: (Callable[[any], any] | None), src: C
) -> Iterator[any] {
    if pred is None {
        return _ff_none(src);
    }
    return _ff_pred(src, pred);
}

impl _ff_none[C: Iterable](src: C) -> Iterator[any] {
    for v in src {
        if not bool(v) {
            yield v;
        }
    }
}

impl _ff_pred[C: Iterable](src: C, pred: Callable[[any], any]) -> Iterator[any] {
    for v in src {
        keep = bool(pred(v));
        if not keep {
            yield v;
        }
    }
}

impl groupby[C: Iterable](
    iterable: C, key: (Callable[[any], any] | None) = None
) -> Iterator[any] {
    return _groupby_gen(iterable, key);
}

impl _groupby_gen[C: Iterable](
    src: C, key: (Callable[[any], any] | None)
) -> Iterator[any] {
    if key is None {
        return _grouped_nokey(src);
    }
    return _grouped_key(src, key);
}

impl _grouped_nokey[C: Iterable](src: C) -> Iterator[any] {
    first = True;
    ck: any = None;
    grp: list[any] = [];
    for v in src {
        k: any = v;
        if first {
            first = False;
            ck = k;
            grp = [];
            grp.append(v);
        } elif k == ck {
            grp.append(v);
        } else {
            row: list[any] = [ck, grp];
            yield row;
            ck = k;
            grp = [];
            grp.append(v);
        }
    }
    if not first {
        row: list[any] = [ck, grp];
        yield row;
    }
}

impl _grouped_key[C: Iterable](src: C, key: Callable[[any], any]) -> Iterator[any] {
    first = True;
    ck: any = None;
    grp: list[any] = [];
    for v in src {
        k: any = key(v);
        if first {
            first = False;
            ck = k;
            grp = [];
            grp.append(v);
        } elif k == ck {
            grp.append(v);
        } else {
            row: list[any] = [ck, grp];
            yield row;
            ck = k;
            grp = [];
            grp.append(v);
        }
    }
    if not first {
        row: list[any] = [ck, grp];
        yield row;
    }
}

impl islice[C: Iterable](iterable: C, *args: any) -> Iterator[any] {
    nargs = len(args);
    if nargs < 1 {
        raise TypeError("islice expected at least 2 arguments, got 1");
    }
    if nargs > 3 {
        raise TypeError("islice expected at most 4 arguments, got " + str(nargs + 1));
    }
    start: int = 0;
    stop: int = 0;
    has_stop: bool = False;
    step: int = 1;
    a0 = args[0];
    if nargs == 1 {
        if isinstance(a0, int) {
            sv: int = a0;
            if sv < 0 {
                raise ValueError(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
            stop = sv;
            has_stop = True;
        } else {
            if not isinstance(a0, type(None)) {
                raise ValueError(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
        }
    } else {
        if isinstance(a0, int) {
            sv0: int = a0;
            if sv0 < 0 {
                raise ValueError(
                    "Start argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
            start = sv0;
        } else {
            if not isinstance(a0, type(None)) {
                raise ValueError(
                    "Start argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
        }
        a1 = args[1];
        if isinstance(a1, int) {
            sv1: int = a1;
            if sv1 < 0 {
                raise ValueError(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
            stop = sv1;
            has_stop = True;
        } else {
            if not isinstance(a1, type(None)) {
                raise ValueError(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                );
            }
        }
        if nargs == 3 {
            a2 = args[2];
            if isinstance(a2, int) {
                sv2: int = a2;
                if sv2 <= 0 {
                    raise ValueError(
                        "Step for islice() must be a positive integer or None."
                    );
                }
                step = sv2;
            } else {
                if not isinstance(a2, type(None)) {
                    raise ValueError(
                        "Step for islice() must be a positive integer or None."
                    );
                }
            }
        }
    }
    limit: int = 9223372036854775807;
    if has_stop {
        limit = stop;
    }
    return _islice_gen(iterable, start, limit, step);
}

impl _islice_gen[C: Iterable](
    src: C, start: int, stop: int, step: int
) -> Iterator[any] {
    i = 0;
    nxt = start;
    for v in src {
        if i >= stop {
            return;
        }
        if i == nxt {
            yield v;
            nxt += step;
        }
        i += 1;
    }
}

impl pairwise[C: Iterable](iterable: C) -> Iterator[any] {
    return _pairwise_gen(iterable);
}

impl _pairwise_gen[C: Iterable](src: C) -> Iterator[any] {
    first = True;
    prev: any = None;
    for v in src {
        if first {
            first = False;
        } else {
            row: list[any] = [prev, v];
            yield row;
        }
        prev = v;
    }
}

impl starmap[C: Iterable](
    func: Callable[[any, any], any], iterable: C
) -> Iterator[any] {
    return _starmap_gen(func, iterable);
}

impl _starmap_gen[C: Iterable](
    func: Callable[[any, any], any], src: C
) -> Iterator[any] {
    for args in src {
        if len(args) != 2 {
            raise TypeError(
                "starmap(): argument rows must have exactly 2 elements on the native pathway"
            );
        }
        yield func(args[0], args[1]);
    }
}

impl permutations[C: Iterable](iterable: C, r: int | None = None) -> Iterator[any] {
    pool = _tolist(iterable);
    n = len(pool);
    rr = n;
    if r is not None {
        r0: int = r;
        rr = r0;
    }
    if rr < 0 {
        raise ValueError("r must be non-negative");
    }
    return _perm_gen(pool, rr);
}

impl combinations[C: Iterable](iterable: C, r: int) -> Iterator[any] {
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    pool = _tolist(iterable);
    return _comb_gen(pool, r);
}

impl combinations_with_replacement[C: Iterable](iterable: C, r: int) -> Iterator[any] {
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    pool = _tolist(iterable);
    return _cwr_gen(pool, r);
}

impl batched[C: Iterable](
    iterable: C, n: int, *, strict: bool = False
) -> Iterator[any] {
    if n < 1 {
        raise ValueError("n must be at least one");
    }
    return _batched_gen(iterable, n, strict);
}

impl _batched_gen[C: Iterable](src: C, n: int, strict: bool) -> Iterator[any] {
    cur: list[any] = [];
    for v in src {
        cur.append(v);
        if len(cur) == n {
            yield cur;
            cur = [];
        }
    }
    if len(cur) > 0 {
        if strict {
            raise ValueError("batched(): incomplete batch");
        }
        yield cur;
    }
}

impl tee[C: Iterable](iterable: C, n: int = 2) -> list[any] {
    if n < 0 {
        raise ValueError("n must be >= 0");
    }
    source: list[any] = _tolist(iterable);
    outs: list[any] = [];
    for i in range(n) {
        copy: list[any] = [];
        for v in source {
            copy.append(v);
        }
        outs.append(copy);
    }
    return outs;
}
