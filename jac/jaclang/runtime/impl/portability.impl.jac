impl py_root_module(name: str) -> str {
    return name.split('.')[0] if name else name;
}

impl supports(module: str, space: str, kind: str) -> bool {
    if space == 'server' {
        return True;
    }
    if space == 'native' {
        return native_supports_py_module(module);
    }
    allowed = PY_STDLIB_BY_KIND.get(kind, set());
    if allowed is None {
        return True;
    }
    return py_root_module(module) in allowed;
}

impl client_supports_py_module(name: str, kind: str = "web-app") -> bool {
    return supports(name, 'client', kind);
}

impl native_supports_py_module(name: str) -> bool {
    mod_root = py_root_module(name);
    return mod_root in NATIVE_SUPPORTED_STDLIB or is_bundled_native_module(mod_root);
}
