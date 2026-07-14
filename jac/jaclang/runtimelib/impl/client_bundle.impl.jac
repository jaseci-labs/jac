impl _lookup_module_in_hub(path_key: str, hub: dict) -> (Module | None) {
    if path_key in hub {
        return hub[path_key];
    }
    normalized_key = os.path.normcase(path_key);
    for hub_path in hub.keys() {
        if os.path.normcase(hub_path) == normalized_key {
            return hub[hub_path];
        }
    }
    return None;
}

impl _ensure_js_generated(mod: Module, program: any) -> None {
    if mod and not mod.gen.js {
        import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
        EsastGenPass(ir_in=mod, prog=program);
    }
}

impl ClientBundleBuilder.postinit -> None {
    if not self.runtime_path {
        self.runtime_path = Path(__file__).with_name('client_runtime.cl.jac');
    }
}

impl _prebuilt_bundle(module: ModuleType, source_path: Path) -> (ClientBundle | None) {
    import from jaclang.runtimelib.sealed_serve { client_dist_for, serve_manifest_for }
    dist = client_dist_for(str(source_path));
    if dist is None {
        return None;
    }
    candidates = sorted(dist.glob('client.*.js'));
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
    mod = _lookup_module_in_hub(str(source_path), Jac.program.mod.hub);
    if not mod {
        (_, mod) = self._compile_to_js(source_path);
    }
    manifest = mod.gen.client_manifest if mod else None;
    bundle_paths = [source_path];
    if (manifest and manifest.imports) {
        for import_path in manifest.imports.values() {
            bundle_paths.append(Path(import_path));
        }
    }
    signature = self._signature(bundle_paths);
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
    manifest: (ClientManifest | None), module: ModuleType
) -> dict[str, any] {
    client_globals_map: dict[(str, Any)] = {};
    if manifest {
        for name in manifest.globals {
            if (name in manifest.globals_values) {
                client_globals_map[name] = manifest.globals_values[name];
            } elif hasattr(module, name) {
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
        "(.cl.jac) code on its own."
    );
}

impl ClientBundleBuilder._compile_to_js(source_path: Path) -> tuple[str, Module] {
    import from jaclang { JacRuntime as Jac }
    program = Jac.program;
    source_key = str(source_path);
    mod = _lookup_module_in_hub(source_key, program.mod.hub);
    if not mod {
        prev_error_count = len(program.errors_had);
        mod = program.compile(source_key);
        new_errors = program.errors_had[prev_error_count:];
        if new_errors {
            formatted = '\n'.join(str(err) for err in new_errors);
            raise ClientBundleError(
                f"Failed to compile '{source_path}' for client bundle:{formatted}"
            );
        }
    }

    _ensure_js_generated(mod, program);
    return ((mod.gen.js or ''), mod) if mod else ('', mod);
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
