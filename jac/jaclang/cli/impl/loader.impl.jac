impl load_handler(name: str) -> Callable {
    import importlib;
    import from jaclang.cli.manifest { get_command_meta }

    meta = get_command_meta(name);
    if meta is None {
        raise KeyError(name);
    }

    mod = importlib.import_module(meta.handler_module);
    handler = getattr(mod, meta.handler_name, None);
    if handler is None {
        raise AttributeError(
            f"{meta.handler_module}.{meta.handler_name} missing for command {name!r}"
        );
    }
    return handler;
}
