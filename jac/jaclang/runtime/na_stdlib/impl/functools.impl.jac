impl partial.init(fn: Callable[[any, any], any], bound: any) {
    self.func = fn;
    self.args = [bound];
    self.keywords = {};
}

impl partial.__call__(x: any) -> any {
    return self.func(self.args[0], x);
}


impl _KeyWrapper._cmpv(other: _KeyWrapper) -> float {
    r: any = self.cmp(self.obj, other.obj);
    if isinstance(r, float) {
        f: float = r;
        return f;
    }
    i: int = r;
    return float(i);
}

impl _KeyWrapper.__lt__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) < 0.0;
}

impl _KeyWrapper.__gt__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) > 0.0;
}

impl _KeyWrapper.__le__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) <= 0.0;
}

impl _KeyWrapper.__ge__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) >= 0.0;
}

impl _KeyWrapper.__eq__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) == 0.0;
}

impl _KeyWrapper.__ne__(other: _KeyWrapper) -> bool {
    return self._cmpv(other) != 0.0;
}


impl _KeyFactory.__call__(val: any) -> _KeyWrapper {
    return _KeyWrapper(self.cmp, val);
}


impl _lru_cache_wrapper._unlink(slot: int) {
    p: int = self.prev[slot];
    n: int = self.nxt[slot];
    if p < 0 {
        self.head = n;
    } else {
        self.nxt[p] = n;
    }
    if n < 0 {
        self.tail = p;
    } else {
        self.prev[n] = p;
    }
}

impl _lru_cache_wrapper._push(slot: int) {
    t: int = self.tail;
    self.prev[slot] = t;
    self.nxt[slot] = -1;
    if t < 0 {
        self.head = slot;
    } else {
        self.nxt[t] = slot;
    }
    self.tail = slot;
}

impl _lru_cache_wrapper._hit(slot: int) -> any {
    if self.cap is not None {
        if slot != self.tail {
            self._unlink(slot);
            self._push(slot);
        }
    }
    self.hits += 1;
    return self.vals[slot];
}

impl _lru_cache_wrapper._miss(x: any, ik: int, use_i: bool, sk: str) -> any {
    self.misses += 1;
    r: any = self.fn(x);
    bounded = False;
    cap: int = 0;
    if self.cap is not None {
        cap = self.cap;
        bounded = True;
        if cap <= 0 {
            return r;
        }
    }
    if use_i {
        if ik in self.store_i {
            return r;
        }
    } elif sk in self.store_s {
        return r;
    }
    slot: int = len(self.vals);
    if bounded and slot >= cap {
        slot = self.head;
        self._unlink(slot);
        if self.is_i[slot] {
            self.store_i.pop(self.key_i[slot]);
        } else {
            self.store_s.pop(self.key_s[slot]);
        }
        self.vals[slot] = r;
        self.key_i[slot] = ik;
        self.key_s[slot] = sk;
        self.is_i[slot] = use_i;
    } else {
        self.vals.append(r);
        self.key_i.append(ik);
        self.key_s.append(sk);
        self.is_i.append(use_i);
        self.prev.append(-1);
        self.nxt.append(-1);
    }
    if use_i {
        self.store_i[ik] = slot;
    } else {
        self.store_s[sk] = slot;
    }
    if bounded {
        self._push(slot);
    }
    return r;
}

impl _lru_cache_wrapper.__call__(x: any) -> any {
    ik: int = 0;
    sk: str = "";
    use_i = False;
    if isinstance(x, bool) {
        b: bool = x;
        sk = "b:" + str(b);
    } elif isinstance(x, int) {
        ik = x;
        use_i = True;
    } elif isinstance(x, float) {
        f: float = x;
        if f != f {
            self.misses += 1;
            return self.fn(x);
        }
        if f == 0.0 {
            sk = "f:0.0";
        } else {
            sk = "f:" + str(f);
        }
    } elif isinstance(x, str) {
        s: str = x;
        sk = "s" + str(len(s)) + ":" + s;
    } elif isinstance(x, type(None)) {
        sk = "n:";
    } elif isinstance(x, list) {
        raise TypeError("unhashable type: 'list'");
    } elif isinstance(x, dict) {
        raise TypeError("unhashable type: 'dict'");
    } elif isinstance(x, set) {
        raise TypeError("unhashable type: 'set'");
    } elif isinstance(x, tuple) {
        raise TypeError("unhashable type: 'tuple'");
    } else {
        raise TypeError("unhashable type");
    }
    if use_i {
        if ik in self.store_i {
            return self._hit(self.store_i[ik]);
        }
        return self._miss(x, ik, True, sk);
    }
    if sk in self.store_s {
        return self._hit(self.store_s[sk]);
    }
    return self._miss(x, 0, False, sk);
}

impl _lru_cache_wrapper.cache_info -> _CacheInfo {
    return _CacheInfo(
        self.hits, self.misses, self.cap, len(self.store_i) + len(self.store_s)
    );
}

impl _lru_cache_wrapper.cache_parameters -> dict[str, any] {
    return {"maxsize": self.cap, "typed": self.typed};
}

impl _lru_cache_wrapper.cache_clear {
    self.store_i = {};
    self.store_s = {};
    self.vals = [];
    self.key_i = [];
    self.key_s = [];
    self.is_i = [];
    self.prev = [];
    self.nxt = [];
    self.head = -1;
    self.tail = -1;
    self.hits = 0;
    self.misses = 0;
}


impl _LruDeco.__call__(fn: Callable[[any], any]) -> _lru_cache_wrapper {
    return _lru_cache_wrapper(fn, self.cap, self.typed, {}, {}, [], [], [], [], [], []);
}


impl _WrapDeco.__call__(wrapper: Callable[[any], any]) -> Callable[[any], any] {
    return wrapper;
}


impl reduce(
    function: Callable[[any, any], any], iterable: list[any], initial: any = _NO_INITIAL
) -> any {
    n: int = len(iterable);
    i: int = 0;
    if isinstance(initial, _NoInitial) {
        if n == 0 {
            raise TypeError("reduce() of empty iterable with no initial value");
        }
        acc: any = iterable[0];
        i = 1;
    } else {
        acc: any = initial;
    }
    while i < n {
        acc = function(acc, iterable[i]);
        i += 1;
    }
    return acc;
}


impl cmp_to_key(mycmp: Callable[[any, any], any]) -> _KeyFactory {
    return _KeyFactory(mycmp);
}


impl lru_cache(maxsize: (int | None) = 128, typed: bool = False) -> _LruDeco {
    ms: (int | None) = maxsize;
    if isinstance(ms, int) {
        m: int = ms;
        if m < 0 {
            ms = 0;
        }
    }
    return _LruDeco(ms, typed);
}


impl cache(fn: Callable[[any], any]) -> _lru_cache_wrapper {
    return _lru_cache_wrapper(fn, None, False, {}, {}, [], [], [], [], [], []);
}


impl update_wrapper(
    wrapper: Callable[[any], any],
    wrapped: any,
    assigned: any = None,
    updated: any = None
) -> Callable[[any], any] {
    return wrapper;
}


impl wraps(wrapped: any, assigned: any = None, updated: any = None) -> _WrapDeco {
    return _WrapDeco(wrapped);
}
