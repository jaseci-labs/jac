import ctypes;
import logging;
import from collections.abc { Callable }
import type from jaclang.jac0core.codeinfo { InteropManifest }

glob logger = logging.getLogger(__name__),
     JAC_TO_CTYPES: dict[(str, type)] = {
         'int': ctypes.c_int64,
         'float': ctypes.c_double,
         'bool': ctypes.c_bool,
         'str': ctypes.c_char_p
     },
     JAC_TO_CTYPES_STR: dict[(str, str)] = {
         'int': 'ctypes.c_int64',
         'float': 'ctypes.c_double',
         'bool': 'ctypes.c_bool',
         'str': 'ctypes.c_char_p'
     },
     _pyb_shadows: dict[(int, object)] = {},
     _pyb_class_memo: dict[(tuple, type)] = {},
     _pyb_module_memo: dict[(str, object)] = {};

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
    import from jaclang.jac0core.runtime { JacModule }
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
    ns: dict = {"__module__": getattr(base, "__module__", "jac_native")};
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
    kwargs: dict,
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
    shadow: object, anchor_name: str, meth_names: tuple, args: tuple, kwargs: dict
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
    manifest: InteropManifest,
    py_func_table: dict[(str, Callable[(..., object)])],
    callbacks_list: list
) {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    for binding in manifest.native_imports {
        ret_ct = JAC_TO_CTYPES.get(binding.ret_type, ctypes.c_int64);
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
        llvm.add_symbol(binding.name, cb_addr);
    }
}
