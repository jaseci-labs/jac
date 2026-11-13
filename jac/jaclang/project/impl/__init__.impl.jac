impl __getattr__(name: str) -> object {
    mod_path = _LAZY_EXPORTS.get(name);
    if mod_path is None {
        raise AttributeError(f"module 'jaclang.project' has no attribute {name!r}");
    }
    import importlib;
    value = getattr(importlib.import_module(mod_path), name);
    globals()[name] = value;
    return value;
}
