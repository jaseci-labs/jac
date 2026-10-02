obj:pub CacheInfo {
    has hits: int,
        misses: int,
        maxsize: any,
        currsize: int;
}


obj:pub _Partial {
    has func: Callable[[any, any], any],
        args: list[any],
        keywords: dict[str, any];

    def __call__(x: any) -> any {
        return self.func(self.args[0], x);
    }
}


obj:pub _KeyWrapper {
    has cmp: Callable[[any, any], any],
        `obj: any;

    def _cmpv(other: _KeyWrapper) -> int {
        r: any = self.cmp(self.obj, other.obj);
        return r;
    }

    def __lt__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) < 0;
    }

    def __gt__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) > 0;
    }

    def __le__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) <= 0;
    }

    def __ge__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) >= 0;
    }

    def __eq__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) == 0;
    }

    def __ne__(other: _KeyWrapper) -> bool {
        return self._cmpv(other) != 0;
    }
}


obj:pub _KeyFactory {
    has cmp: Callable[[any, any], any];

    def __call__(val: any) -> _KeyWrapper {
        return _KeyWrapper(self.cmp, val);
    }
}


obj:pub _Lru {
    has fn: Callable[[any], any],
        cap: (int | None),
        typed: bool,
        store_i: dict[int, any],
        store_s: dict[str, any],
        tick_i: dict[int, int],
        tick_s: dict[str, int],
        tick: int = 0,
        hits: int = 0,
        misses: int = 0;

    def _evict_over(cap: int) {
        while len(self.store_i) + len(self.store_s) > cap {
            best_t: int = 0;
            ki: int = 0;
            ks: str = "";
            bi = False;
            found = False;
            for k in self.tick_i {
                t: int = self.tick_i[k];
                if not found or t < best_t {
                    best_t = t;
                    found = True;
                    bi = True;
                    ki = k;
                }
            }
            for k in self.tick_s {
                t = self.tick_s[k];
                if not found or t < best_t {
                    best_t = t;
                    found = True;
                    bi = False;
                    ks = k;
                }
            }
            if not found {
                break;
            }
            if bi {
                self.store_i.pop(ki);
                self.tick_i.pop(ki);
            } else {
                self.store_s.pop(ks);
                self.tick_s.pop(ks);
            }
        }
    }

    def _hit_i(ik: int) -> any {
        v: any = self.store_i[ik];
        if self.cap is not None {
            self.tick += 1;
            self.tick_i[ik] = self.tick;
        }
        self.hits += 1;
        return v;
    }

    def _hit_s(sk: str) -> any {
        v: any = self.store_s[sk];
        if self.cap is not None {
            self.tick += 1;
            self.tick_s[sk] = self.tick;
        }
        self.hits += 1;
        return v;
    }

    def _miss(x: any, ik: int, use_i: bool, sk: str) -> any {
        self.misses += 1;
        r: any = self.fn(x);
        if self.cap is None {
            if use_i {
                self.store_i[ik] = r;
            } else {
                self.store_s[sk] = r;
            }
        } else {
            cap: int = self.cap;
            if cap > 0 {
                self.tick += 1;
                if use_i {
                    self.store_i[ik] = r;
                    self.tick_i[ik] = self.tick;
                } else {
                    self.store_s[sk] = r;
                    self.tick_s[sk] = self.tick;
                }
                self._evict_over(cap);
            }
        }
        return r;
    }

    def __call__(x: any) -> any {
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
                return self._hit_i(ik);
            }
            return self._miss(x, ik, True, sk);
        }
        if sk in self.store_s {
            return self._hit_s(sk);
        }
        return self._miss(x, 0, False, sk);
    }

    def cache_info -> CacheInfo {
        return CacheInfo(
            self.hits, self.misses, self.cap, len(self.store_i) + len(self.store_s)
        );
    }

    def cache_parameters -> dict[str, any] {
        return {"maxsize": self.cap, "typed": self.typed};
    }

    def cache_clear {
        self.store_i = {};
        self.store_s = {};
        self.tick_i = {};
        self.tick_s = {};
        self.tick = 0;
        self.hits = 0;
        self.misses = 0;
    }
}


obj:pub _LruDeco {
    has cap: (int | None),
        typed: bool = False;

    def __call__(fn: Callable[[any], any]) -> _Lru {
        return _Lru(fn, self.cap, self.typed, {}, {}, {}, {});
    }
}


obj:pub _WrapDeco {
    has wrapped: any;

    def __call__(wrapper: Callable[[any], any]) -> Callable[[any], any] {
        return wrapper;
    }
}


def:pub reduce(
    func: Callable[[any, any], any], data: list[any], initial: any = None
) -> any {
    n: int = len(data);
    i: int = 0;
    if isinstance(initial, type(None)) {
        if n == 0 {
            raise TypeError("reduce() of empty iterable with no initial value");
        }
        acc: any = data[0];
        i = 1;
    } else {
        acc: any = initial;
    }
    while i < n {
        acc = func(acc, data[i]);
        i += 1;
    }
    return acc;
}


def:pub partial(fn: Callable[[any, any], any], bound: any) -> _Partial {
    return _Partial(fn, [bound], {});
}


def:pub cmp_to_key(mycmp: Callable[[any, any], any]) -> _KeyFactory {
    return _KeyFactory(mycmp);
}


def:pub lru_cache(
    fn: any = None, maxsize: (int | None) = 128, typed: bool = False
) -> _LruDeco {
    ms: (int | None) = maxsize;
    if isinstance(fn, bool) or isinstance(fn, int) {
        mpos: int = fn;
        ms = mpos;
    } elif not isinstance(fn, type(None)) {
        raise TypeError(
            "Expected first argument to be an integer, a callable, or None"
        );
    }
    if isinstance(ms, int) {
        m: int = ms;
        if m < 0 {
            ms = 0;
        }
    }
    return _LruDeco(ms, typed);
}


def:pub cache(fn: Callable[[any], any]) -> _Lru {
    return _Lru(fn, None, False, {}, {}, {}, {});
}


glob WRAPPER_ASSIGNMENTS: list[str] = [
         "__module__",
         "__name__",
         "__qualname__",
         "__doc__",
         "__annotate__",
         "__type_params__"
     ],
     WRAPPER_UPDATES: list[str] = ["__dict__"];


def:pub update_wrapper(
    wrapper: Callable[[any], any],
    wrapped: any,
    assigned: any = None,
    updated: any = None
) -> Callable[[any], any] {
    return wrapper;
}


def:pub wraps(wrapped: any, assigned: any = None, updated: any = None) -> _WrapDeco {
    return _WrapDeco(wrapped);
}
