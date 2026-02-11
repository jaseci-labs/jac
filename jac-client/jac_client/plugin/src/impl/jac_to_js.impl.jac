"""Add runtime imports to compiled JS code."""

impl JacToJSCompiler.add_runtime_imports(self: JacToJSCompiler, js_code: str) -> str {
    # Skip adding import if this file IS the runtime (defines __jacJsx itself)
    if "function __jacJsx(" in js_code {
        return js_code;
    }
    jac_jsx_import = 'import {__jacJsx, __jacSpawn} from "@jac/runtime";';
    return f"{jac_jsx_import}\n{js_code}";
}

"""Extract client globals from manifest and module."""
impl JacToJSCompiler.extract_globals(
    self: JacToJSCompiler, manifest: (ClientManifest | None), module: ModuleType
) -> dict[str, Any] {
    return self._extract_client_globals(manifest, module);
}

"""Extract client exports from manifest."""
impl JacToJSCompiler.extract_exports(
    self: JacToJSCompiler, manifest: (ClientManifest | None)
) -> list[str] {
    return self._extract_client_exports(manifest);
}

"""Compile a Jac module to JavaScript."""
impl JacToJSCompiler.compile_module(
    self: JacToJSCompiler, module_path: Path
) -> tuple[str, (ModuleType | None), (ClientManifest | None)] {
    (module_js, mod) = self._compile_to_js(module_path);
    manifest = mod.gen.client_manifest if mod else None;
    return (module_js, mod, manifest);
}

"""Initialize the Jac to JS compiler."""
impl JacToJSCompiler.init(
    self: JacToJSCompiler,
    compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
    extract_exports_func: Callable[([Any], list[str])],
    extract_globals_func: Callable[([Any, ModuleType], dict[(str, Any)])]
) {
    self._compile_to_js = compile_to_js_func;
    self._extract_client_exports = extract_exports_func;
    self._extract_client_globals = extract_globals_func;
}
