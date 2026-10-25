impl JacToJSCompiler.add_runtime_imports(js_code: str) -> str {
    """The import prelude is a function of the module's JS and the active
    backend; a client rebuild re-emits every module, so unchanged ones reuse
    it instead of re-scanning their JS.""";
    key = (type(resolve_active_backend()).__name__, js_code);
    held = _RUNTIME_IMPORTS_MEMO.get(key);
    if held is not None {
        return held;
    }
    text = prepend_active_runtime_globals(js_code);
    if len(_RUNTIME_IMPORTS_MEMO) >= RUNTIME_IMPORTS_MEMO_CAP {
        _RUNTIME_IMPORTS_MEMO.clear();
    }
    _RUNTIME_IMPORTS_MEMO[key] = text;
    return text;
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
