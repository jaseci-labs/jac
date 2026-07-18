impl JacToJSCompiler.add_runtime_imports(js_code: str) -> str {
    import from jaclang.runtimelib.client_surface { prepend_active_runtime_globals }
    return prepend_active_runtime_globals(js_code);
}

impl JacToJSCompiler.extract_globals(
    manifest: (ClientManifest | None), module: ModuleType
) -> dict[str, any] {
    return self._extract_client_globals(manifest, module);
}

impl JacToJSCompiler.extract_exports(manifest: (ClientManifest | None)) -> list[str] {
    return self._extract_client_exports(manifest);
}

impl JacToJSCompiler.compile_module(
    module_path: Path
) -> tuple[str, (ModuleType | None), (ClientManifest | None)] {
    (module_js, mod) = self._compile_to_js(module_path);
    manifest = mod.gen.client_manifest if mod else None;
    return (module_js, mod, manifest);
}
