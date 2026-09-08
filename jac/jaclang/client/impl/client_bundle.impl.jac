impl _client_target_module(source_key: str, program: any) -> (Module | None) {
    return program._get_compiler().client_codegen_target(source_key, program);
}

impl _ensure_js_generated(mod: Module, program: any) -> None {
    _err_mark = len(program.errors_had);
    if program._get_compiler().ensure_client_codegen(mod, program) {
        return;
    }
    _detail = '\n\n'.join(_e.pretty_print() for _e in program.errors_had[_err_mark:]);
    raise ClientBundleError(
        f"'{os.path.basename(mod.loc.mod_path or '')}' is used by client code "
        f"but does not lower to the client:\n\n{_detail}"
    );
}

impl ClientBundleBuilder.postinit -> None {
    if not self.runtime_path {
        self.runtime_path = Path(__file__).with_name('client_runtime.jac');
    }
}

impl _prebuilt_bundle(module: ModuleType, source_path: Path) -> (ClientBundle | None) {
    import from jaclang.server.sealed_serve { client_dist_for, serve_manifest_for }
    dist = client_dist_for(str(source_path));
    if dist is None {
        return None;
    }
    candidates = sorted(dist.`glob('client.*.js'));
    if not candidates {
        return None;
    }
    bundle_js = candidates[-1];
    parts = bundle_js.name.split('.');
    bundle_hash = parts[1] if len(parts) >= 3 else '';
    sm = serve_manifest_for(str(source_path)) or {};
    client_meta = sm.get('client', {}) or {};
    return ClientBundle(
        module_name=module.__name__,
        code=bundle_js.read_text(encoding='utf-8'),
        client_functions=list(client_meta.get('exports', []) or []),
        client_globals=list(client_meta.get('globals', []) or []),
        hash=bundle_hash
    );
}

impl ClientBundleBuilder.build(
    module: ModuleType, force: bool = False
) -> ClientBundle {
    if not module?.__file__ {
        raise ClientBundleError(
            f"Module '{module.__name__}' has no __file__ attribute"
        );
    }
    module_path = module.__file__.replace('.py', '.jac');
    source_path = Path(module_path).resolve();
    prebuilt = _prebuilt_bundle(module, source_path);
    if prebuilt is not None {
        self._cache[module.__name__] = _CachedBundle(
            signature='sealed', bundle=prebuilt
        );
        return prebuilt;
    }
    import from jaclang { JacRuntime as Jac }
    program = Jac.program;
    if program is None {
        raise ClientBundleError(
            f"No active Jac program; cannot build client bundle for '{source_path}'."
        );
    }
    mod = program.find_module(str(source_path));
    manifest = (
        mod.gen.client_manifest if mod else self._compile_to_js(source_path).manifest
    );
    bundle_paths = [source_path];
    if (manifest and manifest.imports) {
        for import_path in manifest.imports.values() {
            bundle_paths.append(Path(import_path));
        }
    }
    signature = self._signature(bundle_paths);
    emitted = self._emitted_digest();
    if emitted {
        signature = f"{signature}:{emitted}";
    }
    cached = self._cache.get(module.__name__);
    if (not force and cached and (cached.signature == signature)) {
        return cached.bundle;
    }
    bundle = self._compile_bundle(module, source_path);
    self._cache[module.__name__] = _CachedBundle(signature=signature, bundle=bundle);
    return bundle;
}

impl ClientBundleBuilder._extract_client_exports(
    manifest: (ClientManifest | None)
) -> list[str] {
    return sorted(dict.fromkeys(manifest.exports)) if manifest else [];
}

impl ClientBundleBuilder._extract_client_globals(
    manifest: (ClientManifest | None), module: (ModuleType | None)
) -> dict[str, any] {
    client_globals_map: dict[(str, any)] = {};
    if manifest {
        for name in manifest.globals {
            if (name in manifest.globals_values) {
                client_globals_map[name] = manifest.globals_values[name];
            } elif module is not None and hasattr(module, name) {
                client_globals_map[name] = getattr(module, name);
            } else {
                client_globals_map[name] = None;
            }
        }
    }
    return {key: client_globals_map[key] for key in sorted(client_globals_map)};
}

impl ClientBundleBuilder._compile_bundle(
    module: ModuleType, module_path: Path
) -> ClientBundle {
    raise ClientBundleError(
        "Client bundling requires the built-in client framework (Vite/Bun pipeline), "
        "which ships with jaclang core; the base builder cannot bundle client "
        "code on its own."
    );
}

impl ClientBundleBuilder._compile_to_js(source_path: Path) -> ClientArtifact {
    import from jaclang { JacRuntime as Jac }
    program = Jac.program;
    if program is None {
        raise ClientBundleError(
            f"No active Jac program; cannot compile '{source_path}' for client bundle."
        );
    }
    diagnostic_program = program._get_compiler().selfhost.resolve(
        str(source_path), program
    );
    prev_error_count = len(diagnostic_program.errors_had);
    artifact = program.get_client_artifact(str(source_path));
    if artifact is None {
        formatted = '\n'.join(
            str(err) for err in diagnostic_program.errors_had[prev_error_count:]
        );
        if not formatted {
            formatted = '\n'.join(str(err) for err in diagnostic_program.errors_had);
        }
        raise ClientBundleError(
            f"Failed to compile '{source_path}' for client bundle:{formatted}"
        );
    }
    return artifact;
}

impl ClientBundleBuilder._emitted_digest -> str {
    return '';
}

impl emitted_tree_digest(tree_root: Path) -> str {
    if not tree_root.is_dir() {
        return '';
    }
    hasher = hashlib.sha256();
    found = False;
    files = sorted(tree_root.rglob('*'));
    for p in files {
        if not p.is_file() or p.suffix not in ('.js', '.css') {
            continue;
        }
        found = True;
        hasher.update(str(p.relative_to(tree_root)).encode('utf-8'));
        try {
            hasher.update(p.read_bytes());
        } except OSError {
            hasher.update('?'.encode('utf-8'));
        }
    }
    if not found {
        return '';
    }
    return hasher.hexdigest();
}

impl ClientBundleBuilder._signature(paths: Iterable[Path]) -> str {
    parts: list[str] = [];
    for path in paths {
        try {
            stat = path.stat();
            parts.append(f"{path}:{stat.st_mtime_ns}");
        } except FileNotFoundError {
            parts.append(f"{path}:missing");
        }
    }
    return hashlib.sha256('|'.join(parts).encode('utf-8')).hexdigest();
}
