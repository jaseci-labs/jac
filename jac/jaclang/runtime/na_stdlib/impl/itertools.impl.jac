impl _tolist_any(src: any) -> list[any] {
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

impl _add_default(a: any, b: any) -> any {
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

impl count(start: int | float = 0, step: int | float = 1) -> Iterator[any] {
    return _count_gen(start, step);
}

impl _count_gen(start: int | float, step: int | float) -> Iterator[any] {
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

impl repeat(object: any, times: int | None = None) -> Iterator[any] {
    return _repeat_gen(object, times);
}

impl _repeat_gen(x: any, times: int | None) -> Iterator[any] {
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

impl chain(*iterables: any) -> Iterator[any] {
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

impl product(*iterables: any, repeat: int = 1) -> Iterator[any] {
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

impl _product_gen(pools: list[list[any]]) -> Iterator[any] {
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

impl _perm_gen(pool: list[any], r: int) -> Iterator[any] {
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

impl _comb_gen(pool: list[any], r: int) -> Iterator[any] {
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

impl _cwr_gen(pool: list[any], r: int) -> Iterator[any] {
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

impl zip_longest(*iterables: any, fillvalue: any = None) -> Iterator[any] {
    pools: list[list[any]] = [];
    for it in iterables {
        pools.append(_tolist_any(it));
    }
    return _zip_longest_gen(pools, fillvalue);
}

impl _zip_longest_gen(pools: list[list[any]], fillvalue: any) -> Iterator[any] {
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
