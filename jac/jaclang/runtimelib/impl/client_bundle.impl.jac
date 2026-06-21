"""Look up a module in one program's hub with cross-platform path normalization
(Windows case/separators).

NOTE: this is deliberately single-hub, unlike `JacProgram.find_module`. The
bundler produces output JS and must compile each module in its own (target)
program context; on a miss it recompiles fresh. It must NOT reuse a module the
router parked in the internal program (e.g. `@jac/runtime` under the jaclang
root), whose JS-generation state is not guaranteed to be the full client build.
"""
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

"""Run EsastGenPass if JS missing (Windows may skip ES pass during initial compile)."""
impl _ensure_js_generated(mod: Module, program: any) -> None {
    if mod and not mod.gen.js {
        import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
        EsastGenPass(ir_in=mod, prog=program);
    }
}

"""Initialise the builder with an optional override for the runtime path."""
impl ClientBundleBuilder.postinit -> None {
    if not self.runtime_path {
        self.runtime_path = Path(__file__).with_name('client_runtime.cl.jac');
    }
}

"""Build (or reuse) a client bundle for the supplied module."""
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

"""Extract client exports from manifest.

Args:
manifest: The client manifest, or None

Returns:
Sorted list of client export names
"""
impl ClientBundleBuilder._extract_client_exports(
    manifest: (ClientManifest | None)
) -> list[str] {
    return sorted(dict.fromkeys(manifest.exports)) if manifest else [];
}

"""Extract client globals from manifest and module.

Args:
manifest: The client manifest, or None
module: The Python module

Returns:
Dictionary of global names to their values
"""
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

"""Produce the browser-ready bundle. The base builder only compiles and
extracts; concrete bundling is the built-in client framework's Vite/Bun pipeline,
which overrides this. Invoked without that provider registered, it raises."""
impl ClientBundleBuilder._compile_bundle(
    module: ModuleType, module_path: Path
) -> ClientBundle {
    raise ClientBundleError(
        "Client bundling requires the built-in client framework (Vite/Bun pipeline), "
        "which ships with jaclang core; the base builder cannot bundle client "
        "(.cl.jac) code on its own."
    );
}

"""Compile the provided Jac file into JavaScript.

Returns:
Tuple of (js_code, compiled_module) where compiled_module contains the client_manifest
"""
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
    # Ensure JS is generated (may be skipped on Windows during initial compile)
    _ensure_js_generated(mod, program);
    return ((mod.gen.js or ''), mod) if mod else ('', mod);
}

"""Compute a cache signature based on file modification times."""
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
