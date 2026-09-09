impl JacToJSCompiler.add_runtime_imports(js_code: str) -> str {
    import from jaclang.client.client_surface { prepend_active_runtime_globals }
    return prepend_active_runtime_globals(js_code);
}

impl JacToJSCompiler.extract_globals(
    manifest: (ClientManifest | None), module: (ModuleType | None)
) -> dict[str, any] {
    return self._extract_client_globals(manifest, module);
}

impl JacToJSCompiler.extract_exports(manifest: (ClientManifest | None)) -> list[str] {
    return self._extract_client_exports(manifest);
}

impl JacToJSCompiler.compile_module(module_path: Path) -> ClientArtifact {
    artifact = self._compile_to_js(module_path);
    self.boundary_contracts[str(module_path)] = artifact.boundary_contracts;
    return artifact;
}
