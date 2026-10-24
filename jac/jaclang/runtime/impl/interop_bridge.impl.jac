impl NativeLibrary.handle -> ctypes.CDLL {
    if self.library is None {
        import os;
        mode = (
            getattr(os, "RTLD_NOW", 0) if self.eager else getattr(os, "RTLD_LAZY", 0)
        )
            | getattr(os, "RTLD_LOCAL", 0);
        self.library = ctypes.CDLL(self.path, mode=mode);
    }
    return self.library;
}

impl NativeLibrary.get_function_address(name: str) -> int {
    address = ctypes.cast(getattr(self.handle(), name), ctypes.c_void_p).value;
    if address is None {
        raise RuntimeError(f'Native symbol {name!r} has no address in {self.path}');
    }
    return address;
}

impl NativeLibrary.register_symbol(name: str, address: int) {
    bind_function = getattr(self.handle(), '__jac_bind_' + name);
    bind_function.argtypes = [ctypes.c_void_p];
    bind_function.restype = None;
    bind_function(address);
}

impl NativeLibrary.initialize -> None {
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

impl resolve_sv_callbacks(
    callbacks: Iterable[dict[str, any]], img_root: str
) -> tuple[(dict[(str, Callable)], list[str])] {
    import os;
    functions: dict[(str, Callable)] = {};
    failures: list[str] = [];
    image_root = os.path.realpath(img_root);
    for cb in callbacks {
        symbol = str(cb.get("symbol") or cb.get("native_symbol") or "");
        name = str(cb.get("name") or "");
        src = str(cb.get("source") or "");
        if not symbol or not name or not src or os.path.isabs(src) {
            failures.append(
                f"{name or symbol or '?'}: invalid sealed callback path or names"
            );
            continue;
        }
        path = os.path.realpath(os.path.join(image_root, src));
        try {
            rel = os.path.relpath(path, image_root);
        } except ValueError {
            rel = "..";
        }
        if rel == ".." or rel.startswith(".." + os.sep) {
            failures.append(f"{name}: provider path escapes the sealed image");
            continue;
        }
        if not os.path.isfile(path) and "." in src and not src.endswith(".jac") {
            alt = os.path.realpath(
                os.path.join(image_root, src.replace(".", os.sep) + ".jac")
            );
            try {
                alt_rel = os.path.relpath(alt, image_root);
            } except ValueError {
                alt_rel = "..";
            }
            if alt_rel == ".." or alt_rel.startswith(".." + os.sep) {
                failures.append(f"{name}: provider path escapes the sealed image");
                continue;
            }
            if os.path.isfile(alt) {
                path = alt;
            }
        }
        try {
            fn = getattr(_pyb_import_module(path), name, None);
        } except Exception as e {
            failures.append(f"{name}: importing '{src}' failed ({e})");
            continue;
        }
        if not callable(fn) {
            failures.append(f"{name}: '{src}' defines no callable '{name}'");
            continue;
        }
        functions[symbol] = cast(Callable, fn);
    }
    return (functions, failures);
}

impl _pyb_import_module(mod_path: str) -> object {
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

impl _pyb_class_for(
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

impl _pyb_instantiate(
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

impl _pyb_shadow_of(owner_addr: int) -> object {
    shadow = _pyb_shadows.get(owner_addr);
    if shadow is None {
        raise RuntimeError(
            f"no Python shadow registered for native object 0x{owner_addr:x}"
        );
    }
    return shadow;
}

impl _pyb_drop_owner(owner_addr: int) {
    _pyb_shadows.pop(owner_addr, None);
}

impl _pyb_super_call(
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

impl register_py_callbacks(
    bindings: Iterable[CallbackSignature],
    py_func_table: dict[(str, Callable[(..., object)])],
    callbacks_list: list[object],
    register_symbol: Callable[[str, int], None]
) {
    for binding in bindings {
        ret_ct = (
            None
                if binding.ret_type in (None, "None", "void", "none")
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
        lookup_name = getattr(binding, "lookup_name", "") or binding.name;
        cb = cb_type(_make_callback(lookup_name, py_func_table));
        callbacks_list.append(cb);
        cb_addr = ctypes.cast(cb, ctypes.c_void_p).value;
        if cb_addr is None {
            raise RuntimeError(f'Cannot allocate native callback {binding.name!r}');
        }
        register_symbol(binding.native_symbol or binding.name, cb_addr);
    }
}

impl _sized_ctypes_tables -> dict[(str, type)] {
    types: dict[(str, type)] = {};
    for shape in numeric_shapes() {
        if not shape.sized {
            continue;
        }
        if shape.is_float {
            ct = ctypes.c_float if shape.width == 32 else ctypes.c_double;
        } else {
            sign = "int" if shape.signed else "uint";
            ct = getattr(ctypes, f"c_{sign}{shape.width}");
        }
        types[shape.name] = ct;
    }
    return types;
}
