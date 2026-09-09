import threading;
import weakref;

glob _region_tls: any = threading.local();

def _stack -> list {
    s = _region_tls?.stack;
    if s is None {
        s = [];
        _region_tls.stack = s;
    }
    return s;
}

obj JacRegion {
    has _drops: list[any] = [],
        _parent: any = None;

    def partition(n: int = 0) -> any {
        if n <= 0 {
            c = JacRegion();
            c._parent = self;
            return c;
        }
        out: list = [];
        for _i in range(n) {
            c = JacRegion();
            c._parent = self;
            out.append(c);
        }
        return tuple(out);
    }

    def _jac_open {
        _stack().append(self);
    }

    def _jac_close {
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

    def _jac_register(item: any) {
        self._drops.append(item);
    }

    def _jac_drop {
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

    def __del__ {
        self._jac_drop();
    }
}

def open_region(r: any) {
    if isinstance(r, JacRegion) {
        r._jac_open();
    }
}

def close_region(r: any) {
    if isinstance(r, JacRegion) {
        r._jac_close();
    }
}

def register_drop(item: any) {
    s = _stack();
    if s {
        s[-1]._jac_register(item);
        item._jac_region = weakref.ref(s[-1]);
    }
}

def region_of(item: any) -> any {
    ref = item?._jac_region;
    return ref() if ref is not None else None;
}

def instrument_drops(cls: any) {
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

def run_drop(item: any) {
    if getattr(item, "_jac_drop_done", False) {
        return;
    }
    drop = item?.drop;
    if not callable(drop) {
        return;
    }
    item._jac_drop_done = True;
    drop();
}
