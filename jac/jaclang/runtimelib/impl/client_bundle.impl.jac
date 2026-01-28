"""Initialise the builder with an optional override for the runtime path."""

impl ClientBundleBuilder.postinit -> None {
    if not self.runtime_path {
        self.runtime_path = Path(__file__).with_name('client_runtime.cl.jac');
    }
}

"""Build (or reuse) a client bundle for the supplied module."""
impl ClientBundleBuilder.build(module: ModuleType, force: bool = False) -> ClientBundle {
    if not module?.__file__ {
        raise ClientBundleError(
            f"Module '{module.__name__}' has no __file__ attribute"
        ) ;
    }
    module_path = module.__file__.replace('.py', '.jac');
    source_path = Path(module_path).resolve();
    import from jaclang { JacRuntime as Jac }
    # Ensure module is compiled so we have the manifest for cache signature
    mod = Jac.program.mod.hub.get(str(source_path));
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

"""Process client imports and return import pieces and bundled module names.

Args:
manifest: The client manifest containing import information, or None
module_path: Path to the module being processed

Returns:
ProcessedImports containing JavaScript code pieces and bundled module names
"""
impl ClientBundleBuilder._process_imports(
    manifest: (ClientManifest | None), module_path: Path
) -> ProcessedImports {
    import_pieces: list[str] = [];
    bundled_module_names: set[str] = <>set();
    if (manifest and manifest.imports) {
        for (import_name, import_path) in manifest.imports.items() {
            import_path_obj = Path(import_path);
            # Handle @jac/ runtime imports - compile and inline
            if import_name.startswith('@jac/') {
                bundled_module_names.add(import_name);
                if import_path_obj.exists() and str(import_path_obj).endswith('.jac') {
                    try {
                        (runtime_js, _) = self._compile_to_js(import_path_obj);
                        import_pieces.append(f"// {import_name}");
                        import_pieces.append(runtime_js);
                        import_pieces.append('');
                    } except ClientBundleError as e {
                        import_pieces.append(
                            f"// Warning: Could not compile {import_name}: {e}"
                        );
                    }
                }
                continue;
            }
            # Only add local files (.jac or JS variants) to bundled_module_names.
            # NPM packages (like 'react') should NOT be bundled - they're external.
            if import_path_obj.suffix in [
                '.jac',
                '.js',
                '.jsx',
                '.ts',
                '.tsx',
                '.mjs',
                '.cjs'
            ] {
                bundled_module_names.add(import_name);
            }
            if (import_path_obj.suffix == '.js') {
                try {
                    with open(import_path_obj, encoding='utf-8') as f {
                        js_code = f.read();
                        import_pieces.append(f"// Imported .js module: {import_name}");
                        import_pieces.append(js_code);
                        import_pieces.append('');
                    }
                } except FileNotFoundError {
                    import_pieces.append(f"// Warning: Could not find {import_path}");
                }
            } elif (import_path_obj.suffix == '.jac') {
                try {
                    (compiled_js, imported_mod) = self._compile_to_js(import_path_obj);
                    transitive_imports: set[str] = <>set();
                    if (imported_mod and imported_mod.gen.client_manifest) {
                        for (sub_import_name, sub_import_path) in imported_mod.gen.client_manifest.imports.items() {
                            bundled_module_names.add(sub_import_name);
                            transitive_imports.add(sub_import_name);
                            sub_import_path_obj = Path(sub_import_path);
                            if (
                                (sub_import_path_obj.suffix == '.jac')
                                and sub_import_path_obj.exists()
                            ) {
                                try {
                                    (sub_compiled_js, _) = self._compile_to_js(
                                        sub_import_path_obj
                                    );
                                    import_pieces.append(
                                        f"// Imported .jac module: {sub_import_name}"
                                    );
                                    import_pieces.append(sub_compiled_js);
                                    import_pieces.append('');
                                } except ClientBundleError {
                                    ;
                                }
                            }
                        }
                    }
                    compiled_js = self._strip_import_statements(
                        compiled_js, transitive_imports
                    );
                    import_pieces.append(f"// Imported .jac module: {import_name}");
                    import_pieces.append(compiled_js);
                    import_pieces.append('');
                } except ClientBundleError {
                    import_pieces.append(
                        f"// Warning: Could not compile {import_path}"
                    );
                }
            }
        }
    }
    return ProcessedImports(import_pieces, bundled_module_names);
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
    return sorted(<>dict.fromkeys(manifest.exports)) if manifest else [];
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
) -> dict[str, Any] {
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

"""Compile bundle pieces and stitch them together."""
impl ClientBundleBuilder._compile_bundle(
    module: ModuleType, module_path: Path
) -> ClientBundle {
    import from jaclang { JacRuntime as Jac }
    # First compile to ensure module is in hub and get JS code + manifest
    (module_js, compiled_mod) = self._compile_to_js(module_path);
    manifest = compiled_mod.gen.client_manifest if compiled_mod else None;
    (import_pieces, bundled_module_names) = self._process_imports(
        manifest, module_path
    );
    module_js = self._strip_import_statements(module_js, bundled_module_names);
    client_exports = self._extract_client_exports(manifest);
    client_globals_map = self._extract_client_globals(manifest, module);
    registration_js = self._generate_registration_js(
        module.__name__, client_exports, client_globals_map
    );
    bundle_pieces = [];
    if import_pieces {
        bundle_pieces.extend(import_pieces);
    }
    bundle_pieces.extend(
        [f"// Client module: {module.__name__}", module_js, '', registration_js]
    );
    bundle_code = '\n'.join(
        piece
        for piece in bundle_pieces
        if (piece is not None)
    );
    bundle_hash = hashlib.sha256(bundle_code.encode('utf-8')).hexdigest();
    return ClientBundle(
        module_name=module.__name__,
        code=bundle_code,
        client_functions=client_exports,
        client_globals=<>list(client_globals_map.keys()),
        hash=bundle_hash
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
    if (source_key in program.mod.hub) {
        mod = program.mod.hub[source_key];
        return ((mod.gen.js or ''), mod);
    }
    mod = program.compile(source_key);
    if program.errors_had {
        formatted = '\n'.join(str(err) for err in program.errors_had);
        raise ClientBundleError(
            f"Failed to compile '{source_path}' for client bundle:{formatted}"
        ) ;
    }
    return ((mod.gen.js or ''), mod);
}

"""Remove ES6 import statements for modules that are bundled.

Args:
js_code: The JavaScript code
bundled_modules: Set of module names that are being bundled

Returns:
JavaScript code with bundled imports removed
"""
impl ClientBundleBuilder._strip_import_statements(
    js_code: str, bundled_modules: set[str]
) -> str {
    import re;
    bundled_js_paths = {convert_to_js_import_path(mod) for mod in bundled_modules};
    all_bundled = bundled_modules | bundled_js_paths;
    lines = js_code.split('\n');
    filtered_lines = [];
    for line in lines {
        import_match = re.match(
            '^\\s*import\\s+.*\\s+from\\s+["\\\']([^"\\\']+)["\\\'];?\\s*$', line
        );
        if import_match {
            module_name = import_match.group(1);
            if (module_name in all_bundled) {
                continue;
            }
        }
        filtered_lines.append(line);
    }
    return '\n'.join(filtered_lines);
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

"""Generate registration code that exposes client symbols globally."""
impl ClientBundleBuilder._generate_registration_js(
    module_name: str, client_functions: Sequence[str], client_globals: dict[(str, Any)]
) -> str {
    globals_entries: list[str] = [];
    for (name, value) in client_globals.items() {
        identifier = json.dumps(name);
        try {
            value_literal = json.dumps(value);
        } except TypeError {
            value_literal = 'null';
        }
        globals_entries.append(f"{identifier}: {value_literal}");
    }
    globals_literal = '{ ' + ', '.join(globals_entries) + ' }'
    if globals_entries
    else '{}';
    functions_literal = json.dumps(<>list(client_functions));
    module_literal = json.dumps(module_name);
    return f"__jacRegisterClientModule({module_literal}, {functions_literal}, {globals_literal});";
}
