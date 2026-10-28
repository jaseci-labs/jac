impl _stack -> list[JacRegion] {
    s = _region_tls?.stack;
    if s is None {
        s = [];
        _region_tls.stack = s;
    }
    return s;
}

impl JacRegion.partition(n: int = 0) -> any {
    if n <= 0 {
        c = JacRegion();
        c._parent = self;
        return c;
    }
    out: list[JacRegion] = [];
    for _i in range(n) {
        c = JacRegion();
        c._parent = self;
        out.append(c);
    }
    return tuple(out);
}

impl JacRegion._jac_open {
    _stack().append(self);
}

impl JacRegion._jac_close {
    s = _stack();
    i = len(s) - 1;
    while i >= 0 {
        if s[i] is self {
            s.pop(i);
            return;
        }
        i -= 1;
    }
}

impl JacRegion._jac_register(item: any) {
    self._drops.append(item);
}

impl JacRegion._jac_drop {
    _pending = self._drops;
    self._drops = [];
    _p = self._parent;
    if _p is not None {
        self._parent = None;
        _p._drops.extend(_pending);
        return;
    }
    for o in reversed(_pending) {
        try {
            run_drop(o);
        } except Exception {
            continue;
        }
    }
}

impl JacRegion.__del__ {
    self._jac_drop();
}

impl escape_regions -> list[JacRegion] {
    s = _stack();
    saved = list(s);
    s.clear();
    return saved;
}

impl restore_regions(saved: list[JacRegion]) {
    s = _stack();
    s.clear();
    s.extend(saved);
}

impl open_region(r: any) {
    if isinstance(r, JacRegion) {
        r._jac_open();
    }
}

impl close_region(r: any) {
    if isinstance(r, JacRegion) {
        r._jac_close();
    }
}

impl register_drop(item: any) {
    s = _stack();
    if s {
        s[-1]._jac_register(item);
        item._jac_region = weakref.ref(s[-1]);
    }
}

impl region_of(item: any) -> any {
    ref = item?._jac_region;
    return ref() if ref is not None else None;
}

impl instrument_drops(cls: any) {
    _orig_init: any = getattr(cls, "__init__");
    def _region_init(inst: any, *args: any, **kwargs: any) {
        _orig_init(inst, *args, **kwargs);
        register_drop(inst);
    }
    setattr(cls, "__init__", _region_init);
    _orig_del: any = cls?.__del__;
    def _drop_on_release(inst: any) {
        try {
            run_drop(inst);
        } finally {
            if _orig_del is not None {
                _orig_del(inst);
            }
        }
    }
    setattr(cls, "__del__", _drop_on_release);
}

impl is_drop_hook(member: any) -> bool {
    if isinstance(member, (staticmethod, classmethod))
        or not callable(member)
        or getattr(member, "__jac_entry", False)
        or getattr(member, "__jac_exit", False) {
        return False;
    }
    import inspect;
    try {
        declared = len(inspect.signature(member).parameters);
    } except (TypeError, ValueError) {
        return True;
    }
    return declared == 1;
}

impl run_drop(item: any) {
    if item is None or getattr(item, "_jac_drop_done", False) {
        return;
    }
    import inspect;
    if not is_drop_hook(inspect.getattr_static(type(item), "drop", None)) {
        return;
    }
    item._jac_drop_done = True;
    item.drop();
}
