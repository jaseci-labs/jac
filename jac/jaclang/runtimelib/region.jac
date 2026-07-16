glob _region_stack: list = [];

obj JacRegion {
    has _drops: list[any] = [];

    def _jac_open {
        _region_stack.append(self);
    }

    def _jac_close {
        if _region_stack and _region_stack[-1] is self {
            _region_stack.pop();
        }
    }

    def _jac_register(item: any) {
        self._drops.append(item);
    }

    def _jac_drop {
        _pending = self._drops;
        self._drops = [];
        for o in reversed(_pending) {
            try {
                o.drop();
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
    if _region_stack {
        _region_stack[-1]._jac_register(item);
    }
}

def instrument_drops(cls: any) {
    _orig_init: any = getattr(cls, "__init__");
    def _region_init(inst: any, *args: any, **kwargs: any) {
        _orig_init(inst, *args, **kwargs);
        register_drop(inst);
    }
    setattr(cls, "__init__", _region_init);
}
