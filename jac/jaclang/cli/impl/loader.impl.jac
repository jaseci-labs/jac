glob _loaded_features: set[str] = set();

def _load_feature_modules(command: str) {
    global _loaded_features;
    if command in _loaded_features {
        return;
    }
    import importlib;
    import from jaclang.cli.registry { FEATURE_COMMAND_MODULES }
    mod = FEATURE_COMMAND_MODULES.get(command);
    if mod {
        importlib.import_module(mod);
    }
    _loaded_features.add(command);
}

impl load_handler(name: str) -> Callable {
    import importlib;
    import from jaclang.cli.manifest { get_command_meta }

    meta = get_command_meta(name);
    if meta is None {
        raise KeyError(name);
    }

    _load_feature_modules(name);

    mod = importlib.import_module(meta.handler_module);
    handler = getattr(mod, meta.handler_name, None);
    if handler is None {
        raise AttributeError(
            f"{meta.handler_module}.{meta.handler_name} missing for command {name!r}"
        );
    }
    return handler;
}
