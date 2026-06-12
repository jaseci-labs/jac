"""PreactBackend — import sources and entry script differ from React."""

impl PreactBackend.name -> str {
    return "preact";
}

impl PreactBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl PreactBackend.import_source(symbol: str) -> str {
    if symbol in ["useState", "useEffect", "useRef"] {
        return "preact/hooks";
    }
    return "@jac/runtime";
}

impl PreactBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.preact_entry { build_simple_preact_entry_script }
    return build_simple_preact_entry_script(entry_module, install_global_handlers);
}
