# Product-path facade for itertools (wave 12): count / cycle / repeat / chain.
# Staged ``jac-py/Modules/itertoolsmodule.{c,jac}`` remain the wave-12 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/itertoolsmodule.c``.
#
# Iterator types are stateful obj archetypes driven through ``__next__``
# (T7 na-clean forbids yield); StopIteration signals exhaustion exactly like
# the C tp_iternext returning NULL.

# Iterator-protocol helpers. Free functions keep the dynamic dispatch on
# plain ``any`` (obj-field access narrows to NoneType under the checker).
def _advance(it: any) -> any {
    return it.__next__();
}

def _get_iter(x: any) -> any {
    return x.__iter__();
}

obj _P2Count {
    # Fast mode: cnt carries an int counter, long_cnt is None.
    # Slow mode: counting goes through object arithmetic (long_cnt += long_step),
    # matching CPython's count_nextlong switch at PY_SSIZE_T_MAX.
    has cnt: int = 0,
        long_cnt: any = None,
        long_step: any = None;

    def __next__ -> any {
        cur: any = long_cnt;
        if cur is None {
            current: int = cnt;
            cnt = cnt + 1;
            return current;
        }
        long_cnt = cur + long_step;
        return cur;
    }

    def __repr__ -> str {
        if long_cnt is None {
            return "count(" + str(cnt) + ")";
        }
        if isinstance(long_step, int) and long_step == 1 {
            return "count(" + str(long_cnt) + ")";
        }
        return "count(" + str(long_cnt) + ", " + str(long_step) + ")";
    }
}

obj _P2Cycle {
    # it drains on the first pass (items saved); afterwards the saved list is
    # cycled forever. Mirrors cycle_next including firstpass/setstate restore.
    has it: any = None,
        saved: list = [],
        index: int = 0,
        firstpass: bool = False;

    def __next__ -> any {
        src: any = it;
        while src is not None {
            try {
                item: any = _advance(src);
                if not firstpass {
                    saved.append(item);
                }
                return item;
            } except StopIteration {
                it = None;
                src = None;
            }
        }
        if len(saved) == 0 {
            raise StopIteration();
        }
        item = saved[index];
        index = index + 1;
        if index >= len(saved) {
            index = 0;
        }
        return item;
    }
}

obj _P2Repeat {
    # remaining < 0 means unbounded (CPython keeps cnt == -1); the constructor
    # maps an explicitly-passed negative times to 0 (exhausted), like repeat_new.
    has element: any = None,
        remaining: int = -1;

    def __next__ -> any {
        if remaining == 0 {
            raise StopIteration();
        }
        if remaining > 0 {
            remaining = remaining - 1;
        }
        return element;
    }

    def __repr__ -> str {
        if remaining < 0 {
            return "repeat(" + str(element) + ")";
        }
        return "repeat(" + str(element) + ", " + str(remaining) + ")";
    }

    def __length_hint__ -> int {
        if remaining < 0 {
            raise TypeError("len() of unsized object");
        }
        return remaining;
    }
}

obj _P2Chain {
    # source walks the input iterables; active is the currently-drained one.
    # Mirrors chain_next: pull a fresh active iterator whenever needed, skip
    # exhausted ones, end when the source itself is exhausted.
    has source: any = None,
        active: any = None;

    def __next__ -> any {
        src: any = source;
        act: any = active;
        while src is not None {
            if act is None {
                try {
                    iterable: any = _advance(src);
                    act = _get_iter(iterable);
                } except StopIteration {
                    source = None;
                    break;
                }
            }
            try {
                item: any = _advance(act);
                active = act;
                return item;
            } except StopIteration {
                act = None;
                active = None;
            }
        }
        raise StopIteration();
    }
}

def _is_number(x: any) -> bool {
    return isinstance(x, int) or isinstance(x, float) or isinstance(x, complex);
}

def _p2_count(start: any = None, step: any = None) -> _P2Count {
    if start is not None and not _is_number(start) {
        raise TypeError("a number is required");
    }
    if step is not None and not _is_number(step) {
        raise TypeError("a number is required");
    }
    fast = (start is None or isinstance(start, int))
        and (step is None or isinstance(step, int));
    if fast and step is not None and (not isinstance(step, int) or step != 1) {
        fast = False;
    }
    counter = _P2Count();
    if fast {
        counter.cnt = 0 if start is None else start;
        counter.long_cnt = None;
        return counter;
    }
    counter.cnt = 0;
    counter.long_cnt = 0 if start is None else start;
    counter.long_step = 1 if step is None else step;
    return counter;
}

def _p2_cycle(iterable: any) -> _P2Cycle {
    lz = _P2Cycle();
    lz.it = _get_iter(iterable);
    lz.saved = [];
    lz.index = 0;
    lz.firstpass = False;
    return lz;
}

# Pickle/state-restoration surface: resume cycling without a first pass over
# the source (mirrors cycle.__setstate__).
def _p2_cycle_setstate(lz: _P2Cycle, saved: list, index: int) {
    lz.it = None;
    lz.saved = saved;
    lz.index = index;
    lz.firstpass = True;
}

def _p2_repeat(element: any, times: any = None) -> _P2Repeat {
    ro = _P2Repeat();
    ro.element = element;
    if times is None {
        ro.remaining = -1;
        return ro;
    }
    if not isinstance(times, int) {
        raise TypeError("an integer is required");
    }
    ro.remaining = 0 if times < 0 else times;
    return ro;
}

def _p2_chain(*iterables: list) -> _P2Chain {
    lz = _P2Chain();
    lz.source = _get_iter(iterables);
    lz.active = None;
    return lz;
}

obj _P2Product {
    # pools is a list of tuples; indices mirrors lz->indices. CPython reuses
    # or copies the previous result tuple and updates it in-place; rebuilding
    # from indices after each odometer advance is value-equivalent.
    has pools: list = [],
        indices: list = [],
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        npools = len(pools);
        if not started {
            started = True;
            out: list = [];
            for i in range(npools) {
                if len(pools[i]) == 0 {
                    stopped = True;
                    raise StopIteration();
                }
                out.append(pools[i][0]);
            }
            return tuple(out);
        }
        # Advance the odometer right-to-left; carry on roll-over.
        i = npools - 1;
        while i >= 0 {
            indices[i] = indices[i] + 1;
            if indices[i] < len(pools[i]) {
                break;
            }
            indices[i] = 0;
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        out = [];
        for k in range(npools) {
            out.append(pools[k][indices[k]]);
        }
        return tuple(out);
    }
}

obj _P2Combinations {
    # pool is the input tuple; indices[i] starts at i. Scan right-to-left for
    # an index below its maximum (i + n - r), increment it, reset the suffix.
    has pool: any = None,
        indices: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        i = r - 1;
        while i >= 0 and indices[i] == i + n - r {
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        indices[i] = indices[i] + 1;
        for j in range(i + 1, r) {
            indices[j] = indices[j - 1] + 1;
        }
        return _index_tuple(pool, indices, r);
    }
}

obj _P2Cwr {
    # combinations_with_replacement: indices[i] starts at 0; scan right-to-left
    # for an index below n-1, then set the whole suffix to the incremented index.
    has pool: any = None,
        indices: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        i = r - 1;
        while i >= 0 and indices[i] == n - 1 {
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        index = indices[i] + 1;
        for j in range(i, r) {
            indices[j] = index;
        }
        return _index_tuple(pool, indices, r);
    }
}

obj _P2Permutations {
    # Exact port of permutations_next: cycles decrement right-to-left with
    # rotation on zero (indices[i:] = indices[i+1:] + indices[i:i+1]); a
    # swap at cycles[i] > 0 fixes position i and yields.
    has pool: any = None,
        indices: list = [],
        cycles: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        if n == 0 {
            stopped = True;
            raise StopIteration();
        }
        i = r - 1;
        while i >= 0 {
            cycles[i] = cycles[i] - 1;
            if cycles[i] == 0 {
                index = indices[i];
                for j in range(i, n - 1) {
                    indices[j] = indices[j + 1];
                }
                indices[n - 1] = index;
                cycles[i] = n - i;
                i = i - 1;
            } else {
                j = cycles[i];
                index = indices[i];
                indices[i] = indices[n - j];
                indices[n - j] = index;
                break;
            }
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        return _index_tuple(pool, indices, r);
    }
}

def _index_tuple(pool: list, indices: list, r: int) -> any {
    out: list = [];
    for k in range(r) {
        out.append(pool[indices[k]]);
    }
    return tuple(out);
}

def _p2_product(iterables: list, repeat: int = 1) -> _P2Product {
    if repeat < 0 {
        raise ValueError("repeat argument cannot be negative");
    }
    lz = _P2Product();
    base: list = [];
    for it in iterables {
        base.append(tuple(it));
    }
    for rep in range(repeat) {
        for t in base {
            lz.pools.append(t);
        }
    }
    npools = len(lz.pools);
    lz.indices = [0] * npools;
    lz.started = False;
    lz.stopped = False;
    return lz;
}

def _p2_combinations(iterable: any, r: int) -> _P2Combinations {
    co = _P2Combinations();
    co.pool = tuple(iterable);
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    co.indices = list(range(r));
    co.r = r;
    co.started = False;
    co.stopped = r > len(co.pool);
    return co;
}

def _p2_cwr(iterable: any, r: int) -> _P2Cwr {
    co = _P2Cwr();
    co.pool = tuple(iterable);
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    co.indices = [0] * r;
    co.r = r;
    co.started = False;
    co.stopped = len(co.pool) == 0 and r > 0;
    return co;
}

def _p2_permutations(iterable: any, r: any = None) -> _P2Permutations {
    po = _P2Permutations();
    po.pool = tuple(iterable);
    n = len(po.pool);
    if r is None {
        r = n;
    } else {
        if not isinstance(r, int) {
            raise TypeError("an integer is required");
        }
        if r < 0 {
            raise ValueError("r must be non-negative");
        }
    }
    po.indices = list(range(n));
    cyc: list = [];
    for c in range(n, n - r, -1) {
        cyc.append(c);
    }
    po.cycles = cyc;
    po.r = r;
    po.started = False;
    po.stopped = r > n;
    return po;
}

def _p2_chain_from_iterable(iterable: any) -> _P2Chain {
    lz = _P2Chain();
    lz.source = _get_iter(iterable);
    lz.active = None;
    return lz;
}

# ---- filtering / grouping / slicing types ---------------------------------

obj _P2Groupby {
    # Mirrors groupby_next + groupby_step. has_curr/has_tgt are explicit
    # data flags (CPython uses NULL sentinels, but None can be a real key).
    # currgrouper holds the serial of the live _P2Grouper; stale groupers
    # raise StopIteration like C's currgrouper != igo check.
    has it: any,
        keyfunc: any = None,
        tgtkey: any = None,
        currkey: any = None,
        currvalue: any = None,
        has_curr: bool = False,
        has_tgt: bool = False,
        currgrouper: int = -1,
        last_serial: int = 0;

    def step -> bool {
        try {
            newvalue: any = _advance(it);
        } except StopIteration {
            return False;
        }
        if keyfunc is None {
            newkey: any = newvalue;
        } else {
            newkey = keyfunc(newvalue);
        }
        currvalue = newvalue;
        currkey = newkey;
        has_curr = True;
        return True;
    }

    def __next__ -> any {
        currgrouper = -1;
        need_step: bool = True;
        while need_step {
            if not has_curr {
                need_step = True;
            } elif not has_tgt {
                need_step = False;
            } elif tgtkey == currkey {
                need_step = True;
            } else {
                need_step = False;
            }
            if need_step {
                ok: bool = self.step();
                if not ok {
                    raise StopIteration();
                }
            }
        }
        tk: any = currkey;
        tgtkey = tk;
        has_tgt = True;
        last_serial = last_serial + 1;
        serial: int = last_serial;
        currgrouper = serial;
        return tuple([tk, _P2Grouper(parent=self, tgtkey=tk, serial=serial)]);
    }
}

obj _P2Grouper {
    has parent: any = None,
        tgtkey: any = None,
        serial: int = 0;

    def __next__ -> any {
        gbo = parent;
        if gbo.currgrouper != serial {
            raise StopIteration();
        }
        if not gbo.has_curr {
            if not gbo.step() {
                raise StopIteration();
            }
        }
        if not (tgtkey == gbo.currkey) {
            raise StopIteration();
        }
        r: any = gbo.currvalue;
        gbo.currvalue = None;
        gbo.has_curr = False;
        gbo.currkey = None;
        return r;
    }
}

def _p2_groupby(iterable: any, keyfunc: any = None) -> _P2Groupby {
    gbo = _P2Groupby(it=_get_iter(iterable), keyfunc=keyfunc);
    return gbo;
}

obj _P2Tee {
    # Shared-lookahead model of the teedataobject chain: every clone reads
    # from one buffer; index tracks per-clone consumption.
    has src: any = None,
        buf: list = [],
        done: bool = False,
        index: int = 0;

    def __next__ -> any {
        while len(buf) <= index {
            if done {
                raise StopIteration();
            }
            try {
                buf.append(_advance(src));
            } except StopIteration {
                done = True;
                raise StopIteration();
            }
        }
        item: any = buf[index];
        index = index + 1;
        return item;
    }

    def copy -> _P2Tee {
        t = _P2Tee(src=src, buf=buf, done=done, index=index);
        return t;
    }
}

def _p2_tee(iterable: any, n: int = 2) -> any {
    if n < 0 {
        raise ValueError("n must be >= 0");
    }
    if n == 0 {
        return tuple([]);
    }
    base = _P2Tee(src=_get_iter(iterable));
    out: list = [base];
    for i in range(1, n) {
        out.append(base.copy());
    }
    return tuple(out);
}

obj _P2Islice {
    # stop == -1 means "no stop" (CPython sentinel). next_pos counts by step
    # from start; cnt is the absolute number of items consumed.
    has it: any = None,
        next_pos: int = 0,
        stop: int = -1,
        step: int = 1,
        cnt: int = 0;

    def __next__ -> any {
        if it is None {
            raise StopIteration();
        }
        while cnt < next_pos {
            try {
                skipped: any = _advance(it);
            } except StopIteration {
                it = None;
                raise StopIteration();
            }
            cnt = cnt + 1;
        }
        if stop != -1 and cnt >= stop {
            it = None;
            raise StopIteration();
        }
        try {
            item: any = _advance(it);
        } except StopIteration {
            it = None;
            raise StopIteration();
        }
        cnt = cnt + 1;
        next_pos = next_pos + step;
        if stop != -1 and next_pos > stop {
            it = None;
        }
        return item;
    }
}

def _p2_islice_stop(seq: any, stop: any) -> _P2Islice {
    lz = _P2Islice(it=_get_iter(seq));
    if stop is not None {
        if not isinstance(stop, int) or isinstance(stop, bool) or stop < 0 {
            raise ValueError(
                "Stop argument for islice() must be None or "
                + "an integer: 0 <= x <= sys.maxsize."
            );
        }
        lz.stop = stop;
    }
    return lz;
}

def _p2_islice_full(seq: any, start: any, stop: any, step: any) -> _P2Islice {
    lz = _P2Islice(it=_get_iter(seq));
    s: int = 0;
    e: int = -1;
    st: int = 1;
    if start is not None {
        if not isinstance(start, int) or isinstance(start, bool) or start < 0 {
            raise ValueError(
                "Indices for islice() must be None or "
                + "an integer: 0 <= x <= sys.maxsize."
            );
        }
        s = start;
    }
    if stop is not None {
        if not isinstance(stop, int) or isinstance(stop, bool) or stop < 0 {
            raise ValueError(
                "Indices for islice() must be None or "
                + "an integer: 0 <= x <= sys.maxsize."
            );
        }
        e = stop;
    }
    if step is not None {
        if not isinstance(step, int) or isinstance(step, bool) or step < 1 {
            raise ValueError("Step for islice() must be a positive integer or None.");
        }
        st = step;
    }
    lz.next_pos = s;
    lz.stop = e;
    lz.step = st;
    return lz;
}

obj _P2Starmap {
    has func: any = None,
        it: any = None;

    def __next__ -> any {
        args: any = _advance(it);
        return func(*args);
    }
}

def _p2_starmap(func: any, iterable: any) -> _P2Starmap {
    lz = _P2Starmap(func=func, it=_get_iter(iterable));
    return lz;
}

obj _P2Accumulate {
    has it: any = None,
        func: any = None,
        total: any = None,
        started: bool = False;

    def __next__ -> any {
        if not started {
            started = True;
            total = _advance(it);
            return total;
        }
        item: any = _advance(it);
        if func is None {
            total = total + item;
        } else {
            total = func(total, item);
        }
        return total;
    }
}

def _p2_accumulate(iterable: any, func: any = None) -> _P2Accumulate {
    lz = _P2Accumulate(it=_get_iter(iterable), func=func);
    return lz;
}

obj _P2Compress {
    has data_it: any = None,
        sel_it: any = None;

    def __next__ -> any {
        while True {
            selector: any = _advance(sel_it);
            datum: any = _advance(data_it);
            if selector {
                return datum;
            }
        }
    }
}

def _p2_compress(data: any, selectors: any) -> _P2Compress {
    lz = _P2Compress(data_it=_get_iter(data), sel_it=_get_iter(selectors));
    return lz;
}

obj _P2Dropwhile {
    has func: any = None,
        it: any = None,
        started: bool = False;

    def __next__ -> any {
        if not started {
            while True {
                item: any = _advance(it);
                if not func(item) {
                    started = True;
                    return item;
                }
            }
        }
        return _advance(it);
    }
}

def _p2_dropwhile(predicate: any, iterable: any) -> _P2Dropwhile {
    lz = _P2Dropwhile(func=predicate, it=_get_iter(iterable));
    return lz;
}

obj _P2Takewhile {
    has func: any = None,
        it: any = None,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        item: any = _advance(it);
        if not func(item) {
            stopped = True;
            raise StopIteration();
        }
        return item;
    }
}

def _p2_takewhile(predicate: any, iterable: any) -> _P2Takewhile {
    lz = _P2Takewhile(func=predicate, it=_get_iter(iterable));
    return lz;
}

obj _P2Filterfalse {
    has func: any = None,
        it: any = None;

    def __next__ -> any {
        while True {
            item: any = _advance(it);
            if func is None {
                if not item {
                    return item;
                }
            } elif not func(item) {
                return item;
            }
        }
    }
}

def _p2_filterfalse(predicate: any, iterable: any) -> _P2Filterfalse {
    lz = _P2Filterfalse(func=predicate, it=_get_iter(iterable));
    return lz;
}

obj _P2Pairwise {
    has it: any = None,
        prev: any = None,
        started: bool = False;

    def __next__ -> any {
        if not started {
            prev = _advance(it);
            started = True;
        }
        item: any = _advance(it);
        oldprev: any = prev;
        prev = item;
        return tuple([oldprev, item]);
    }
}

def _p2_pairwise(iterable: any) -> _P2Pairwise {
    lz = _P2Pairwise(it=_get_iter(iterable));
    return lz;
}

obj _P2Batched {
    has it: any = None,
        n: int = 1,
        strict: bool = False;

    def __next__ -> any {
        batch: list = [];
        while len(batch) < n {
            try {
                batch.append(_advance(it));
            } except StopIteration {
                if len(batch) > 0 {
                    if strict and len(batch) < n {
                        raise ValueError("batched(): incomplete batch");
                    }
                    return tuple(batch);
                }
                raise StopIteration();
            }
        }
        return tuple(batch);
    }
}

def _p2_batched(iterable: any, n: int, strict: bool = False) -> _P2Batched {
    if n < 1 {
        raise ValueError("n must be at least one");
    }
    bo = _P2Batched(it=_get_iter(iterable), n=n, strict=strict);
    return bo;
}

obj _P2ZipLongest {
    # iterators[i] becomes None once exhausted (numactive decrements); a row
    # where the LAST active iterator dies returns StopIteration immediately,
    # dropping partially collected items exactly like C zip_longest_next.
    has iterators: list = [],
        fillvalue: any = None,
        numactive: int = 0;

    def __next__ -> any {
        if numactive == 0 {
            raise StopIteration();
        }
        out: list = [];
        i = 0;
        while i < len(iterators) {
            src: any = iterators[i];
            if src is None {
                out.append(fillvalue);
            } else {
                try {
                    out.append(_advance(src));
                } except StopIteration {
                    iterators[i] = None;
                    numactive = numactive - 1;
                    if numactive == 0 {
                        raise StopIteration();
                    }
                    out.append(fillvalue);
                }
            }
            i = i + 1;
        }
        return tuple(out);
    }
}

def _p2_zip_longest(iterables: list, fillvalue: any = None) -> _P2ZipLongest {
    lz = _P2ZipLongest(fillvalue=fillvalue, numactive=len(iterables));
    for seq in iterables {
        lz.iterators.append(_get_iter(seq));
    }
    return lz;
}
