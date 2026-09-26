import ctypes;
import logging;
import from collections.abc { Callable, Iterable }
import from typing { Protocol }
class CallbackSignature(Protocol) {
    has name: str,
        ret_type: str,
        param_types: list[str];
}

obj NativeCallback {
    has name: str,
        ret_type: str,
        param_types: list[str];
}

obj NativeLibrary {
    has path: str,
        bindings: list[NativeCallback] = [],
        library: ctypes.CDLL | None = None,
        initialized: bool = False,
        callbacks: list[object] = [],
        functions: dict[str, Callable] = {};

    def handle -> ctypes.CDLL {
        import os;
        if self.library is None {
            mode = getattr(os, "RTLD_NOW", 0);
            self.library = ctypes.CDLL(self.path, mode=mode);
        }
        return self.library;
    }

    def get_function_address(name: str) -> int {
        address = ctypes.cast(getattr(self.handle(), name), ctypes.c_void_p).value;
        if address is None {
            raise RuntimeError(f'Native symbol {name!r} has no address in {self.path}');
        }
        return address;
    }

    def register_symbol(name: str, address: int) {
        bind_function = getattr(self.handle(), '__jac_bind_' + name);
        bind_function.argtypes = [ctypes.c_void_p];
        bind_function.restype = None;
        bind_function(address);
    }

    def initialize -> None {
        if self.initialized {
            return;
        }
        register_py_callbacks(
            self.bindings, self.functions, self.callbacks, self.register_symbol
        );
        initializer = getattr(self.handle(), '__jac_shared_init');
        initializer.argtypes = [];
        initializer.restype = None;
        initializer();
        self.initialized = True;
    }
}

def _sized_ctypes_tables -> tuple[dict[(str, type)], dict[(str, str)]] {
    import from jaclang.runtime.scalars { numeric_shapes }
    types: dict[(str, type)] = {};
    names: dict[(str, str)] = {};
    for shape in numeric_shapes() {
        if not shape.sized {
            continue;
        }
        if shape.is_float {
            ct = ctypes.c_float if shape.width == 32 else ctypes.c_double;
        } else {
            sign = 'int' if shape.signed else 'uint';
            ct = getattr(ctypes, f'c_{sign}{shape.width}');
        }
        types[shape.name] = ct;
        names[shape.name] = f'ctypes.{ct.__name__}';
    }
    return (types, names);
}

glob logger = logging.getLogger(__name__),
     _sized_tables = _sized_ctypes_tables(),
     JAC_TO_CTYPES: dict[(str, type)] = {
         'int': ctypes.c_int64,
         'float': ctypes.c_double,
         'bool': ctypes.c_bool,
         'str': ctypes.c_char_p
     }
         | _sized_tables[0],
     JAC_TO_CTYPES_STR: dict[(str, str)] = {
         'int': 'ctypes.c_int64',
         'float': 'ctypes.c_double',
         'bool': 'ctypes.c_bool',
         'str': 'ctypes.c_char_p'
     }
         | _sized_tables[1],
     _pyb_shadows: dict[(int, object)] = {},
     _pyb_class_memo: dict[(tuple[any, ...], type)] = {},
     _pyb_module_memo: dict[(str, object)] = {};

def resolve_sv_callbacks(
    callbacks: Iterable[dict], img_root: str
) -> dict[(str, Callable)] {
    import os;
    functions: dict[(str, Callable)] = {};
    for cb in callbacks {
        name = cb.get("name") or "";
        src = cb.get("source_module") or "";
        if not (name and src) {
            logger.warning(
                f"na->sv callback {name!r} has no recorded source module; "
                "calls into it return 0"
            );
            continue;
        }
        mod_path = src if os.path.isabs(src) else os.path.join(img_root, src);
        if (not os.path.exists(mod_path) and "." in src and not src.endswith(".jac")) {
            alt = os.path.join(img_root, src.replace(".", os.sep) + ".jac");
            if os.path.exists(alt) {
                mod_path = alt;
            }
        }
        try {
            mod = _pyb_import_module(mod_path);
            fn = getattr(mod, name, None);
        } except Exception as e {
            logger.warning(f"failed to load '{src}' for callback '{name}': {e}");
            continue;
        }
        if fn is None {
            logger.warning(f"'{name}' not found in {src}; calls into it return 0");
            continue;
        }
        functions[name] = fn;
    }
    return functions;
}

def _pyb_import_module(mod_path: str) -> object {
    import os;
    key = os.path.abspath(mod_path);
    cached = _pyb_module_memo.get(key);
    if cached is not None {
        return cached;
    }
    import sys;
    stem = os.path.splitext(os.path.basename(key))[0];
    existing = sys.modules.get(stem);
    if (
        existing is not None
        and os.path.abspath(getattr(existing, "__file__", "") or "") == key
    ) {
        _pyb_module_memo[key] = existing;
        return existing;
    }
    import from jaclang.runtime.runtime { JacModule }
    mods = JacModule.jac_import(target=stem, base_path=os.path.dirname(key));
    mod = mods[0] if isinstance(mods, tuple) else mods;
    _pyb_module_memo[key] = mod;
    return mod;
}

def _pyb_class_for(
    mod_path: str, base_name: str, cls_name: str, suppress_postinit: bool
) -> type {
    key = (mod_path, base_name, cls_name, suppress_postinit, );
    cached = _pyb_class_memo.get(key);
    if cached is not None {
        return cached;
    }
    mod = _pyb_import_module(mod_path);
    base = getattr(mod, base_name);
    ns: dict[str, any] = {"__module__": getattr(base, "__module__", "jac_native")};
    if suppress_postinit {
        def _noop_post_init(self: object) -> None {
            return;
        }
        ns["__post_init__"] = _noop_post_init;
    }
    cls = type(cls_name, (base, ), ns);
    loose: any = cls;
    if loose.__abstractmethods__ {
        loose.__abstractmethods__ = frozenset();
    }
    _pyb_class_memo[key] = cls;
    return cls;
}

def _pyb_instantiate(
    mod_path: str,
    base_name: str,
    cls_name: str,
    kwargs: dict[str, any],
    suppress_postinit: bool,
    owner_addr: int
) -> object {
    cls = _pyb_class_for(mod_path, base_name, cls_name, bool(suppress_postinit));
    shadow = cls(**kwargs);
    _pyb_shadows[owner_addr] = shadow;
    return shadow;
}

def _pyb_shadow_of(owner_addr: int) -> object {
    shadow = _pyb_shadows.get(owner_addr);
    if shadow is None {
        raise RuntimeError(
            f"no Python shadow registered for native object 0x{owner_addr:x}"
        );
    }
    return shadow;
}

def _pyb_drop_owner(owner_addr: int) {
    _pyb_shadows.pop(owner_addr, None);
}

def _pyb_super_call(
    shadow: object,
    anchor_name: str,
    meth_names: tuple[str, ...],
    args: tuple[any, ...],
    kwargs: dict[str, any]
) -> object {
    anchor: (type | None) = None;
    for c in type(shadow).__mro__ {
        if c.__name__ == anchor_name {
            anchor = c;
            break;
        }
    }
    if anchor is None {
        raise AttributeError(
            f"{type(shadow).__name__} has no ancestor class {anchor_name}"
        );
    }
    for mn in meth_names {
        fn = getattr(anchor, mn, None);
        if fn is not None {
            return fn(shadow, *args, **(kwargs or {}));
        }
    }
    raise AttributeError(f"{anchor_name} defines none of {meth_names}");
}

def register_py_callbacks(
    bindings: Iterable[CallbackSignature],
    py_func_table: dict[(str, Callable[(..., object)])],
    callbacks_list: list[object],
    register_symbol: Callable[[str, int], None]
) {
    for binding in bindings {
        ret_ct = (
            None
                if binding.ret_type == 'None'
                else JAC_TO_CTYPES.get(binding.ret_type, ctypes.c_int64)
        );
        arg_cts = [JAC_TO_CTYPES.get(pt, ctypes.c_int64) for pt in binding.param_types];
        cb_type = ctypes.CFUNCTYPE(ret_ct, *arg_cts);
        def _make_callback(
            func_name: str, table: dict[(str, Callable[(..., object)])]
        ) -> Callable[(..., object)] {
            warned = [False];
            def callback(*args: object) -> object {
                fn = table.get(func_name);
                if (fn is not None) {
                    return fn(*args);
                }
                if not warned[0] {
                    logger.warning(
                        f"Native code called Python function '{func_name}' butit's not registered. Returning 0. Ensure Python code defining '{func_name}'executes before native code calls it."
                    );
                    warned[0] = True;
                }
                return 0;
            }
            return callback;
        }
        cb = cb_type(_make_callback(binding.name, py_func_table));
        callbacks_list.append(cb);
        cb_addr = ctypes.cast(cb, ctypes.c_void_p).value;
        if cb_addr is None {
            raise RuntimeError(f'Cannot allocate native callback {binding.name!r}');
        }
        register_symbol(binding.name, cb_addr);
    }
}
