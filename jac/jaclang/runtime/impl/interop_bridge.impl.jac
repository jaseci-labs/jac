impl native_callback_of(record: dict[str, any], product: str) -> NativeCallback {
    if not record.get('symbol') {
        raise RuntimeError(
            f"The native product {product} was built by an older jac: its Python "
            f"callback '{record.get('name', '?')}' records no interop symbol. "
            "Rebuild this product with the current jac."
        );
    }
    return NativeCallback(
        name=record['name'],
        symbol=record['symbol'],
        ret_type=record['ret_type'],
        param_types=list(record['param_types'])
    );
}

impl callback_ctype(type_name: str) -> (type | None) {
    if type_name == 'str' {
        return ctypes.c_char_p;
    }
    shape = shape_of(type_name);
    if shape is None {
        return None;
    }
    return shape_ctype(shape);
}

impl NativeLibrary.handle -> ctypes.CDLL {
    if self.library is None {
        self.library = ctypes.CDLL(self.path);
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
    registered: set[str] = set();
    for binding in bindings {
        if binding.symbol in registered {
            continue;
        }
        registered.add(binding.symbol);
        ret_void = binding.ret_type in CALLBACK_VOID_RETURNS;
        ret_ct = None if ret_void else callback_ctype(binding.ret_type);
        arg_cts = [callback_ctype(pt) for pt in binding.param_types];
        if (ret_ct is None and not ret_void) or None in arg_cts {
            raise RuntimeError(
                f"Native callback '{binding.name}' has a signature that cannot "
                f"cross from native code into Python (returns {binding.ret_type}, "
                f"takes {binding.param_types})."
            );
        }
        cb_type = ctypes.CFUNCTYPE(ret_ct, *arg_cts);
        def _make_callback(
            symbol: str, func_name: str, table: dict[(str, Callable[(..., object)])]
        ) -> Callable[(..., object)] {
            def callback(*args: object) -> object {
                fn = table.get(symbol);
                if fn is not None {
                    return fn(*args);
                }
                import os;
                import sys;
                sys.stderr.write(
                    f"Native code called the Python function '{func_name}' before "
                        + "the module defining it ran. A native call into Python "
                        + "cannot raise, so the process stops. Import the module "
                        + f"that defines '{func_name}' before native code calls it.\n"
                );
                sys.stderr.flush();
                os.abort();
            }
            return callback;
        }
        cb = cb_type(_make_callback(binding.symbol, binding.name, py_func_table));
        callbacks_list.append(cb);
        cb_addr = ctypes.cast(cb, ctypes.c_void_p).value;
        if cb_addr is None {
            raise RuntimeError(f'Cannot allocate native callback {binding.name!r}');
        }
        register_symbol(binding.symbol, cb_addr);
    }
}
