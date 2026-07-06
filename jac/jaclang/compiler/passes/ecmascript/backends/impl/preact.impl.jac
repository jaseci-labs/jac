impl PreactBackend.name -> str {
    return "preact";
}

impl PreactBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl PreactBackend.import_source(symbol: str) -> str {
    if symbol in self._hook_symbols() {
        return "preact/hooks";
    }
    return "@jac/runtime";
}

impl PreactBackend.runtime_source_basename -> str {
    return "client_runtime.cl.jac";
}

impl PreactBackend.vite_aliases -> dict[str, str] {
    return {"react": "preact/compat", "react-dom": "preact/compat"};
}

impl PreactBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.preact_entry { build_simple_preact_entry_script }
    return build_simple_preact_entry_script(entry_module, install_global_handlers);
}
