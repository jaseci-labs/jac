def _tolist[C: Iterable](src: C) -> list[any] {
    out: list[any] = [];
    for v in src {
        out.append(v);
    }
    return out;
}

def _tolist_any(src: any) -> list[any] {
    out: list[any] = [];
    if isinstance(src, str) {
        sv: str = src;
        for v in sv {
            out.append(v);
        }
        return out;
    }
    if not isinstance(src, list) {
        raise TypeError(
            "itertools: variadic arguments must be lists or str on the native pathway"
        );
    }
    for v in src {
        out.append(v);
    }
    return out;
}

def _add_default(a: any, b: any) -> any {
    if isinstance(a, int) {
        av_i: int = a;
        if isinstance(b, int) {
            bv_i: int = b;
            return av_i + bv_i;
        }
        if isinstance(b, float) {
            bv_f: float = b;
            return float(av_i) + bv_f;
        }
    } elif isinstance(a, float) {
        av_f: float = a;
        if isinstance(b, int) {
            bv_i2: int = b;
            return av_f + float(bv_i2);
        }
        if isinstance(b, float) {
            bv_f2: float = b;
            return av_f + bv_f2;
        }
    } elif isinstance(a, str) {
        av_s: str = a;
        if isinstance(b, str) {
            bv_s: str = b;
            return av_s + bv_s;
        }
    }
    raise TypeError(
        "accumulate(): unsupported operand types for + on the native pathway"
    );
}

def:pub count(start: int | float = 0, step: int | float = 1) -> Iterator[any] {
    return _count_gen(start, step);
}

def _count_gen(start: int | float, step: int | float) -> Iterator[any] {
    if isinstance(start, int) {
        s_i: int = start;
        if isinstance(step, int) {
            st_i: int = step;
            v_i: int = s_i;
            while True {
                yield v_i;
                v_i += st_i;
            }
        }
        if isinstance(step, float) {
            st_f: float = step;
            v_f: float = float(s_i);
            while True {
                yield v_f;
                v_f += st_f;
            }
        }
    }
    if isinstance(start, float) {
        s_f: float = start;
        if isinstance(step, int) {
            st_i2: int = step;
            v_f2: float = s_f;
            while True {
                yield v_f2;
                v_f2 += float(st_i2);
            }
        }
        if isinstance(step, float) {
            st_f2: float = step;
            v_f3: float = s_f;
            while True {
                yield v_f3;
                v_f3 += st_f2;
            }
        }
    }
}

def:pub cycle[C: Iterable](iterable: C) -> Iterator[any] {
    return _cycle_gen(iterable);
}

def _cycle_gen[C: Iterable](src: C) -> Iterator[any] {
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

def:pub repeat(x: any, times: int | None = None) -> Iterator[any] {
    return _repeat_gen(x, times);
}

def _repeat_gen(x: any, times: int | None) -> Iterator[any] {
    if times is None {
        while True {
            yield x;
        }
    }
    if isinstance(times, int) {
        k: int = times;
        i = 0;
        while i < k {
            yield x;
            i += 1;
        }
    }
}

def:pub accumulate[C: Iterable](
    iterable: C, func: (Callable[[any, any], any] | None) = None, *, initial: any = None
) -> Iterator[any] {
    return _accumulate_gen(iterable, func, initial);
}

def _accumulate_gen[C: Iterable](
    src: C, func: (Callable[[any, any], any] | None), initial: any
) -> Iterator[any] {
    if func is None {
        return _accumulate_default(src, initial);
    }
    return _accumulate_func(src, func, initial);
}

def _accumulate_default[C: Iterable](src: C, initial: any) -> Iterator[any] {
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

def _accumulate_func[C: Iterable](
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

def:pub chain(*iterables: any) -> Iterator[any] {
    for it in iterables {
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

def:pub chain_from_iterable[C: Iterable](iterable: C) -> Iterator[any] {
    return _chain_fi_gen(iterable);
}

def _chain_fi_gen[C: Iterable](src: C) -> Iterator[any] {
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

def:pub compress[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any] {
    return _compress_gen(data, selectors);
}

def _compress_gen[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any] {
    for pair in zip(data, selectors) {
        s = pair[1];
        if bool(s) {
            yield pair[0];
        }
    }
}

def:pub dropwhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any] {
    return _dropwhile_gen(predicate, iterable);
}

def _dropwhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any] {
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

def:pub takewhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any] {
    return _takewhile_gen(predicate, iterable);
}

def _takewhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any] {
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

def:pub filterfalse[C: Iterable](
    predicate: (Callable[[any], any] | None), iterable: C
) -> Iterator[any] {
    return _filterfalse_gen(predicate, iterable);
}

def _filterfalse_gen[C: Iterable](
    pred: (Callable[[any], any] | None), src: C
) -> Iterator[any] {
    if pred is None {
        return _ff_none(src);
    }
    return _ff_pred(src, pred);
}

def _ff_none[C: Iterable](src: C) -> Iterator[any] {
    for v in src {
        if not bool(v) {
            yield v;
        }
    }
}

def _ff_pred[C: Iterable](src: C, pred: Callable[[any], any]) -> Iterator[any] {
    for v in src {
        keep = bool(pred(v));
        if not keep {
            yield v;
        }
    }
}

def:pub groupby[C: Iterable](
    iterable: C, key: (Callable[[any], any] | None) = None
) -> Iterator[any] {
    return _groupby_gen(iterable, key);
}

def _groupby_gen[C: Iterable](
    src: C, key: (Callable[[any], any] | None)
) -> Iterator[any] {
    if key is None {
        return _grouped_nokey(src);
    }
    return _grouped_key(src, key);
}

def _grouped_nokey[C: Iterable](src: C) -> Iterator[any] {
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

def _grouped_key[C: Iterable](src: C, key: Callable[[any], any]) -> Iterator[any] {
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

def:pub islice[C: Iterable](iterable: C, *args: any) -> Iterator[any] {
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

def _islice_gen[C: Iterable](
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

def:pub pairwise[C: Iterable](iterable: C) -> Iterator[any] {
    return _pairwise_gen(iterable);
}

def _pairwise_gen[C: Iterable](src: C) -> Iterator[any] {
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

def:pub starmap[C: Iterable](
    func: Callable[[any, any], any], iterable: C
) -> Iterator[any] {
    return _starmap_gen(func, iterable);
}

def _starmap_gen[C: Iterable](
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

def:pub product(*iterables: any, repeat: int = 1) -> Iterator[any] {
    if repeat < 0 {
        raise ValueError("repeat argument cannot be negative");
    }
    pools: list[list[any]] = [];
    for it in iterables {
        pools.append(_tolist_any(it));
    }
    reps = repeat;
    if reps != 1 {
        doubled: list[list[any]] = [];
        for ri in range(reps) {
            for p in pools {
                doubled.append(p);
            }
        }
        pools = doubled;
    }
    return _product_gen(pools);
}

def _product_gen(pools: list[list[any]]) -> Iterator[any] {
    np = len(pools);
    if np == 0 {
        empty: list[any] = [];
        yield empty;
        return;
    }
    lens: list[int] = [];
    for p in pools {
        l = len(p);
        if l == 0 {
            return;
        }
        lens.append(l);
    }
    idx: list[int] = [];
    for zi in range(np) {
        idx.append(0);
    }
    while True {
        row: list[any] = [];
        for i in range(np) {
            row.append(pools[i][idx[i]]);
        }
        yield row;
        i = np - 1;
        while i >= 0 {
            idx[i] += 1;
            if idx[i] < lens[i] {
                break;
            }
            idx[i] = 0;
            i -= 1;
        }
        if i < 0 {
            return;
        }
    }
}

def:pub permutations[C: Iterable](iterable: C, r: int | None = None) -> Iterator[any] {
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

def _perm_gen(pool: list[any], r: int) -> Iterator[any] {
    n = len(pool);
    if r > n {
        return;
    }
    indices: list[int] = [];
    cycles: list[int] = [];
    for i in range(n) {
        indices.append(i);
    }
    for i in range(r) {
        cycles.append(n - i);
    }
    head: list[any] = [];
    for i in range(r) {
        head.append(pool[i]);
    }
    yield head;
    while n > 0 {
        i = r - 1;
        advanced = False;
        while i >= 0 {
            cycles[i] -= 1;
            if cycles[i] == 0 {
                tmp = indices[i];
                for j in range(i, n - 1) {
                    indices[j] = indices[j + 1];
                }
                indices[n - 1] = tmp;
                cycles[i] = n - i;
                i -= 1;
            } else {
                j = n - cycles[i];
                tmp2 = indices[i];
                indices[i] = indices[j];
                indices[j] = tmp2;
                head2: list[any] = [];
                for k in range(r) {
                    head2.append(pool[indices[k]]);
                }
                yield head2;
                advanced = True;
                break;
            }
        }
        if not advanced {
            return;
        }
    }
}

def:pub combinations[C: Iterable](iterable: C, r: int) -> Iterator[any] {
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    pool = _tolist(iterable);
    return _comb_gen(pool, r);
}

def _comb_gen(pool: list[any], r: int) -> Iterator[any] {
    n = len(pool);
    if r > n {
        return;
    }
    indices: list[int] = [];
    for i in range(r) {
        indices.append(i);
    }
    row: list[any] = [];
    for i in range(r) {
        row.append(pool[i]);
    }
    yield row;
    while True {
        brk = -1;
        i = r - 1;
        while i >= 0 {
            if indices[i] != i + n - r {
                brk = i;
                break;
            }
            i -= 1;
        }
        if brk < 0 {
            return;
        }
        indices[brk] += 1;
        for j in range(brk + 1, r) {
            indices[j] = indices[j - 1] + 1;
        }
        row2: list[any] = [];
        for i in range(r) {
            row2.append(pool[indices[i]]);
        }
        yield row2;
    }
}

def:pub combinations_with_replacement[C: Iterable](
    iterable: C, r: int
) -> Iterator[any] {
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    pool = _tolist(iterable);
    return _cwr_gen(pool, r);
}

def _cwr_gen(pool: list[any], r: int) -> Iterator[any] {
    n = len(pool);
    if r == 0 {
        empty: list[any] = [];
        yield empty;
        return;
    }
    if n == 0 {
        return;
    }
    indices: list[int] = [];
    for i in range(r) {
        indices.append(0);
    }
    row: list[any] = [];
    for i in range(r) {
        row.append(pool[0]);
    }
    yield row;
    while True {
        brk = -1;
        i = r - 1;
        while i >= 0 {
            if indices[i] != n - 1 {
                brk = i;
                break;
            }
            i -= 1;
        }
        if brk < 0 {
            return;
        }
        nv = indices[brk] + 1;
        for j in range(brk, r) {
            indices[j] = nv;
        }
        row2: list[any] = [];
        for i in range(r) {
            row2.append(pool[indices[i]]);
        }
        yield row2;
    }
}

def:pub batched[C: Iterable](
    iterable: C, n: int, *, strict: bool = False
) -> Iterator[any] {
    if n < 1 {
        raise ValueError("n must be at least one");
    }
    return _batched_gen(iterable, n, strict);
}

def _batched_gen[C: Iterable](src: C, n: int, strict: bool) -> Iterator[any] {
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

def:pub zip_longest(*iterables: any, fillvalue: any = None) -> Iterator[any] {
    pools: list[list[any]] = [];
    for it in iterables {
        pools.append(_tolist_any(it));
    }
    return _zip_longest_gen(pools, fillvalue);
}

def _zip_longest_gen(pools: list[list[any]], fillvalue: any) -> Iterator[any] {
    max_len = 0;
    for p in pools {
        if len(p) > max_len {
            max_len = len(p);
        }
    }
    i = 0;
    while i < max_len {
        row: list[any] = [];
        for p in pools {
            if i < len(p) {
                row.append(p[i]);
            } else {
                row.append(fillvalue);
            }
        }
        yield row;
        i += 1;
    }
}

def:pub tee[C: Iterable](iterable: C, n: int = 2) -> list[any] {
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
