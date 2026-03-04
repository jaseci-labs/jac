"""Add runtime imports to compiled JS code."""

impl JacToJSCompiler.add_runtime_imports(js_code: str) -> str {
    # Skip adding import if this file IS the runtime (defines __jacJsx itself)
    if "function __jacJsx(" in js_code {
        return js_code;
    }
    jac_jsx_import = 'import {__jacJsx, __jacSpawn} from "@jac/runtime";';
    return f"{jac_jsx_import}\n{js_code}";
}

"""Extract client globals from manifest and module."""
impl JacToJSCompiler.extract_globals(
    manifest: (ClientManifest | None), module: ModuleType
) -> dict[str, Any] {
    return self._extract_client_globals(manifest, module);
}

"""Extract client exports from manifest."""
impl JacToJSCompiler.extract_exports(manifest: (ClientManifest | None)) -> list[str] {
    return self._extract_client_exports(manifest);
}

"""Compile a Jac module to JavaScript."""
impl JacToJSCompiler.compile_module(
    module_path: Path
) -> tuple[str, (ModuleType | None), (ClientManifest | None)] {
    (module_js, mod) = self._compile_to_js(module_path);
    manifest = mod.gen.client_manifest if mod else None;
    return (module_js, mod, manifest);
}
