import from jaclang.cli.console { console }

"""Get the client build directory from project config."""
impl ViteCompiler._get_client_dir(self: ViteCompiler) -> Path {
    # Try to get from project config
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is not None {
            return config.get_client_dir();
        }
    } except ImportError { }
    # Fallback to default
    return self.project_dir / '.jac' / 'client';
}

"""Compile module and dependencies without bundling (for dev mode)."""
impl ViteCompiler.compile(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[list[str], list[str]] {
    (module_js, mod, module_manifest) = self.jac_compiler.compile_module(module_path);
    collected_exports: set[str] = set(
        self.jac_compiler.extract_exports(module_manifest)
    );
    client_globals_map = self.jac_compiler.extract_globals(module_manifest, module);
    collected_globals: dict[(str, Any)] = dict(client_globals_map);
    visited: set[Path] = set();
    self.compile_dependencies_recursively(
        module_path,
        visited=visited,
        collected_exports=collected_exports,
        collected_globals=collected_globals
    );
    # Scan pages/ directory for file-based routing (compiles page files too)
    self._has_pages = self._scan_and_compile_pages(
        visited=visited,
        collected_exports=collected_exports,
        collected_globals=collected_globals
    );
    # Compile runtime AFTER dependencies so it overwrites any dependency-compiled
    # version of client_runtime.js with the proper ES module exports
    self.compile_runtime_utils();
    # Compile PWA runtime if PWA is enabled
    import from jaclang.runtimelib.client.config_loader { JacClientConfig as PwaConfig }
    pwa_config = PwaConfig(self.project_dir);
    if pwa_config.is_pwa_enabled() {
        self.compile_pwa_runtime();
    }
    # Compile desktop SDK if @jac/desktop is resolvable (via jac.modules entry point)
    self.compile_desktop_sdk();
    self.copy_root_assets();
    self.create_entry_file(module_path);
    # Return exports and globals without bundling
    client_exports = sorted(collected_exports);
    client_globals = list(collected_globals.keys());
    return (client_exports, client_globals);
}

"""Compile module and dependencies, then bundle with Vite."""
impl ViteCompiler.compile_and_bundle(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[str, str, list[str], list[str]] {
    (client_exports, client_globals) = self.compile(module, module_path);
    # Vite handles JSX/TSX transpilation natively with Bun - no Babel needed
    # Vite builds directly from compiled/ directory
    entry_file = self.compiled_dir / '_entry.js';
    self.vite_bundler.build(entry_file=entry_file);
    (bundle_code, bundle_hash) = self.vite_bundler.read_bundle();
    # If the module carries an `na {}` codespace, compile it to a wasm module
    # and drop it in the served dist dir (AFTER the Vite build, which wipes
    # dist). Client code fetches it at `/static/<stem>.wasm`. The `na` externs
    # (raylib, libc, ...) stay as wasm imports the cl shim supplies.
    self._emit_na_wasm(module_path);
    return (bundle_code, bundle_hash, client_exports, client_globals);
}

"""Compile the module's native (`na {}`) codespace to a wasm module served at
`/static/<stem>.wasm`. No-op when the module has no native code."""
impl ViteCompiler._emit_na_wasm(self: ViteCompiler, module_path: Path) -> None {
    import re;
    import from jaclang.jac0core.ext_registry { is_native_module }
    try {
        src = module_path.read_text(encoding='utf-8');
    } except (FileNotFoundError, OSError) {
        return;
    }
    has_na = bool(
        re.search(r'(^|[\s;}])na\s*\{', src)
        or re.search(r'(^|\n)\s*to\s+na\s*:', src)
        or re.search(
            r'(^|[\s;])na\s+(def|can|impl|obj|node|walker|glob|class|enum)\b', src
        )
        or is_native_module(module_path.name)
    );
    if not has_na {
        return;
    }
    import from jaclang.compiler.passes.native.wasm_build { compile_to_wasm }
    try {
        wasm = compile_to_wasm(str(module_path));
    } except Exception as e {
        console.warning(f"Skipped na->wasm for '{module_path.name}': {e}");
        return;
    }
    if wasm is None {
        return;
    }
    dist = self._get_client_dir() / 'dist';
    dist.mkdir(parents=True, exist_ok=True);
    out_path = dist / f"{module_path.stem}.wasm";
    out_path.write_bytes(wasm);
    console.print(
        f"  Native wasm module: /static/{module_path.stem}.wasm ({len(wasm)} bytes)"
    );
}

"""Create the main entry file for Vite bundling."""
impl ViteCompiler.create_entry_file(self: ViteCompiler, module_path: Path) -> None {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    backend = resolve_active_backend();
    # Use _entry.js to avoid conflict with compiled modules that may be named main.js
    entry_file = self.compiled_dir / '_entry.js';
    if self._has_pages {
        # File-based routing mode: import from generated _routes.js
        entry_content = self._create_pages_entry_content(module_path);
    } else {
        # Explicit routing mode: import app from entry module (original behavior)
        entry_content = backend.build_entry_script(module_path.stem);
    }
    entry_file.write_text(entry_content, encoding='utf-8');
}

impl ViteCompiler._create_pages_entry_content(
    self: ViteCompiler, module_path: Path
) -> str {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    auth_redirect = "/login";
    try {
        import from jaclang.runtimelib.client.config_loader { JacClientConfig }
        config = JacClientConfig(project_dir=self.project_dir);
        routing = config.get_section('routing');
        if routing {
            auth_redirect = routing.get('auth_redirect', '/login');
        }
    } except Exception as e {
        console.warning(
            f"Failed to load routing config, using default auth_redirect='/login': {e}"
        );
    }
    # Check if the entry module (e.g. main.jac) exists and exports `app` (wrapper).
    app_module = self.compiled_dir / f"{module_path.stem}.js";
    has_app_wrapper = app_module.exists();
    # The JS body is framework-specific (React's `react-dom/client` route tree vs
    # Solid's `solid-js/web` render via the `@solidjs/router` shim adapters), so
    # delegate to the active backend. Both consume the same framework-neutral
    # `_routes.js` manifest (`routes`/`layouts`).
    backend = resolve_active_backend();
    return backend.build_pages_entry_script(
        module_path.stem, auth_redirect, has_app_wrapper
    );
}

"""Copy assets from root assets/ folder to compiled/assets/ for @jac-client/assets alias."""
impl ViteCompiler.copy_root_assets(self: ViteCompiler) -> None {
    root_assets_dir = self.project_dir / 'assets';
    compiled_assets_dir = self.compiled_dir / 'assets';
    if (root_assets_dir.exists() and root_assets_dir.is_dir()) {
        self.asset_processor.copy_assets(root_assets_dir, compiled_assets_dir);
        # Copy configured custom asset types to compiled/assets/
        self.asset_processor.copy_custom_asset_types(
            root_assets_dir, compiled_assets_dir
        );
    }
}

"""Copy an asset file to the compiled directory."""
impl ViteCompiler._copy_asset_file(
    self: ViteCompiler, asset_path: Path, source_root: Path
) -> None {
    if not asset_path.exists() {
        return;
    }
    try {
        relative_path = asset_path.relative_to(source_root);
        output_path = self.compiled_dir / relative_path;
    } except ValueError {
        output_path = self.compiled_dir / asset_path.name;
    }
    output_path.parent.mkdir(parents=True, exist_ok=True);
    try {
        output_path.write_text(
            asset_path.read_text(encoding='utf-8'), encoding='utf-8'
        );
    } except (FileNotFoundError, OSError) as e {
        console.warning(f"Failed to copy asset '{asset_path}' to '{output_path}': {e}");
    }
}

"""Copy a TypeScript file to the compiled directory."""
impl ViteCompiler._copy_ts_file(
    self: ViteCompiler, ts_path: Path, source_root: Path
) -> None {
    if not ts_path.exists() {
        return;
    }
    try {
        ts_code = ts_path.read_text(encoding='utf-8');
        try {
            relative_path = ts_path.relative_to(source_root);
            output_path = self.compiled_dir / relative_path;
        } except ValueError {
            output_path = self.compiled_dir / ts_path.name;
        }
        output_path.parent.mkdir(parents=True, exist_ok=True);
        output_path.write_text(ts_code, encoding='utf-8');
    } except (FileNotFoundError, OSError) { }
}

"""Copy a JavaScript file to the compiled directory."""
impl ViteCompiler._copy_js_file(
    self: ViteCompiler, js_path: Path, source_root: Path
) -> None {
    try {
        js_code = js_path.read_text(encoding='utf-8');
        try {
            relative_path = js_path.relative_to(source_root);
            output_path = self.compiled_dir / relative_path;
        } except ValueError {
            output_path = self.compiled_dir / js_path.name;
        }
        output_path.parent.mkdir(parents=True, exist_ok=True);
        output_path.write_text(js_code, encoding='utf-8');
    } except FileNotFoundError { }
}

"""Recursively compile/copy .jac/.js imports to temp, skipping bundling."""
impl ViteCompiler.compile_dependencies_recursively(
    self: ViteCompiler,
    module_path: Path,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None,
    source_root: (Path | None) = None
) -> None {
    if (visited is None) {
        visited = set();
    }
    if (collected_exports is None) {
        collected_exports = set();
    }
    if (collected_globals is None) {
        collected_globals = {};
    }
    module_path = module_path.resolve();
    if (module_path in visited) {
        return;
    }
    visited.add(module_path);
    if (source_root is None) {
        source_root = module_path.parent.resolve();
    }
    (module_js, mod, manifest) = self.jac_compiler.compile_module(module_path);
    exports_list = self.jac_compiler.extract_exports(manifest);
    collected_exports.update(exports_list);
    non_root_globals: dict[(str, Any)] = {};
    if manifest {
        for name in manifest.globals {
            non_root_globals[name] = manifest.globals_values.get(name);
        }
    }
    collected_globals.update(non_root_globals);
    combined_js = self.jac_compiler.add_runtime_imports(module_js);
    try {
        relative_path = module_path.relative_to(source_root);
        rel_str = self._jac_path_to_js(str(relative_path));
        output_path = self.compiled_dir / rel_str;
    } except ValueError {
        name = self._jac_path_to_js(module_path.name);
        output_path = self.compiled_dir / name;
    }
    output_path.parent.mkdir(parents=True, exist_ok=True);
    source_header = f"/* Source: {module_path} */\n";
    output_path.write_text(source_header + combined_js, encoding='utf-8');
    self._write_source_map(
        mod, str(module_path), output_path, source_header + combined_js
    );
    if (not manifest or not manifest.imports) {
        return;
    }
    for (_name, import_path) in manifest.imports.items() {
        path_obj = Path(import_path).resolve();
        if (path_obj in visited) {
            continue;
        }
        if (path_obj.suffix == '.jac') {
            self.compile_dependencies_recursively(
                path_obj,
                visited,
                collected_exports=collected_exports,
                collected_globals=collected_globals,
                source_root=source_root
            );
        } elif (path_obj.suffix == '.js') {
            self._copy_js_file(path_obj, source_root);
        } elif (path_obj.suffix in {'.ts', '.tsx'}) {
            self._copy_ts_file(path_obj, source_root);
        } elif path_obj.is_file() {
            self._copy_asset_file(path_obj, source_root);
        }
    }
}

"""Compile client runtime utilities."""
impl ViteCompiler.compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]] {
    if not self.runtime_path {
        raise ClientBundleError('Runtime path not set');
    }
    import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
    runtime_utils_path = Path(resolve_client_runtime_cl_path());
    (runtimeutils_js, mod, runtimeutils_manifest) = self.jac_compiler.compile_module(
        runtime_utils_path
    );
    runtimeutils_exports_list = self.jac_compiler.extract_exports(
        runtimeutils_manifest
    );
    glob_names = list(runtimeutils_manifest.globals) if runtimeutils_manifest else [];
    all_exports = sorted(
        set(runtimeutils_exports_list + self.ROUTER_EXPORTS + glob_names)
    );
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    # The per-framework runtime shim re-exports the framework-agnostic surface
    # from `client_runtime_core.cl.jac` (so `@jac/runtime` stays one module). The
    # shim's compiled import resolves the core by its dotted module path
    # (`./jaclang/runtimelib/client_runtime_core.js`); compile that sibling and
    # emit it flat alongside the shim, then rewrite the import to the sibling path
    # so Vite resolves it. Core symbols are already re-exported by the shim, so
    # `all_exports` needs no addition.
    core_path = runtime_utils_path.parent / 'client_runtime_core.cl.jac';
    if core_path.exists() {
        core_specifier = './jaclang/runtimelib/client_runtime_core.js';
        if core_specifier in runtimeutils_js {
            (core_js, core_mod, _) = self.jac_compiler.compile_module(core_path);
            runtimeutils_js = runtimeutils_js.replace(
                core_specifier, './client_runtime_core.js'
            );
            core_out = self.compiled_dir / 'client_runtime_core.js';
            core_out.write_text(core_js, encoding='utf-8');
            self._write_source_map(core_mod, str(core_path), core_out, core_js);
        }
    }
    runtime_out = self.compiled_dir / 'client_runtime.js';
    runtime_out.write_text(runtimeutils_js, encoding='utf-8');
    self._write_source_map(mod, str(runtime_utils_path), runtime_out, runtimeutils_js);
    return (runtimeutils_js, all_exports);
}

"""Compile PWA runtime utilities (only when PWA is enabled)."""
impl ViteCompiler.compile_pwa_runtime(self: ViteCompiler) -> tuple[str, list[str]] {
    runtime_path = self.runtime_path;
    if runtime_path is None {
        return ('', []);
    }
    pwa_runtime_path: Path = runtime_path.parent / 'pwa_runtime.cl.jac';
    if not pwa_runtime_path.exists() {
        return ('', []);
    }
    (pwa_js, mod, pwa_manifest) = self.jac_compiler.compile_module(pwa_runtime_path);
    pwa_exports_list = self.jac_compiler.extract_exports(pwa_manifest);
    glob_names = list(pwa_manifest.globals) if pwa_manifest else [];
    all_exports = sorted(set(pwa_exports_list + glob_names));
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    pwa_out = self.compiled_dir / 'pwa_runtime.js';
    pwa_out.write_text(pwa_js, encoding='utf-8');
    self._write_source_map(mod, str(pwa_runtime_path), pwa_out, pwa_js);
    return (pwa_js, all_exports);
}

"""Compile @jac/desktop SDK if it is resolvable.

Uses the modresolver's jac.modules entry point mechanism to find the
SDK source, compiles it to JS, and writes it into the compiled dir.
Returns silently if @jac/desktop is not installed (no entry point registered)."""
impl ViteCompiler.compile_desktop_sdk(self: ViteCompiler) {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }
    desktop_src = resolve_jac_virtual_module_path('@jac/desktop');
    if not desktop_src {
        return;
    }
    desktop_path = Path(desktop_src);
    if not desktop_path.exists() {
        return;
    }
    (desktop_js, mod, desktop_manifest) = self.jac_compiler.compile_module(
        desktop_path
    );
    if not desktop_js or not desktop_js.strip() {
        return;
    }
    # The desktop SDK uses obj types, not def:pub, so extract_exports may be empty.
    # Append an ES module export for all known SDK symbols.
    desktop_exports = self.jac_compiler.extract_exports(desktop_manifest);
    desktop_globals = self.jac_compiler.extract_globals(desktop_manifest, mod);
    all_names = sorted(set(desktop_exports + list(desktop_globals.keys())));
    # Fallback: the SDK is built from `obj` types, which the extractors above
    # don't surface. Ask the package that owns @jac/desktop for its export list
    # via the jac.module_exports entry point — the names live there, not here.
    if not all_names {
        import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_exports }
        all_names = sorted(resolve_jac_virtual_module_exports('@jac/desktop'));
    }
    if all_names {
        export_line = 'export {' + ', '.join(all_names) + '};';
        desktop_js = desktop_js + '\n' + export_line + '\n';
    }
    desktop_out = self.compiled_dir / 'desktop_api.js';
    desktop_out.write_text(desktop_js, encoding='utf-8');
    self._write_source_map(mod, str(desktop_path), desktop_out, desktop_js);
}

"""Write the per-file source map for a freshly compiled module and chain the
compiled JS to it via a `//# sourceMappingURL` comment.

Maps the generated JS lines back to the original `.jac` source lines so a
client-side error stack resolves to the real source location -- not the
compiled-JS line. A no-op when the module produced no ES AST or no line map.

Crucially this uses `mod` -- the module the bundler just compiled and already
holds -- rather than re-fetching it from `Jac.program.mod.hub`: a fullstack /
interop build compiles client modules into a separate codespace, leaving the
hub empty, so a hub lookup would silently miss and skip the map. `full_output`
is the exact text written to disk (source header + runtime-import prefix + raw
JS); its prefix lines are counted so the map's output lines line up on disk.
"""
impl ViteCompiler._write_source_map(
    self: ViteCompiler, mod: Any, source_file: str, output_path: Path, full_output: str
) -> None {
    if (not mod or not mod.gen.es_ast) {
        return;
    }
    try {
        import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js_with_map }
        import from jaclang.runtimelib.source_mapping { generate_source_map_json }
        (_, line_map) = es_to_js_with_map(mod.gen.es_ast);
        if not line_map {
            return;
        }
        # The raw generated JS sits after whatever prefix the caller prepended
        # (source header + optional runtime-import line); shift the map's output
        # lines past it so they match the file on disk.
        raw_js = mod.gen.js or '';
        raw_start = full_output.find(raw_js) if raw_js else -1;
        header_lines = full_output[:raw_start].count('\n') if (raw_start > 0) else 0;
        if header_lines > 0 {
            line_map = [
                (out + header_lines, src_l, src_c) for (out, src_l, src_c) in line_map
            ];
        }
        map_json = generate_source_map_json(
            source_file=source_file, output_file=output_path.name, line_map=line_map
        );
        map_path = output_path.parent / f"{output_path.name}.map";
        map_path.write_text(map_json, encoding='utf-8');
        with open(output_path, 'a', encoding='utf-8') as f {
            f.write(f"\n//# sourceMappingURL={output_path.name}.map\n");
        }
    } except Exception as e {
        console.warning(f"Failed to generate source map for '{source_file}': {e}");
    }
}

"""Convert a .jac relative path string to .js, handling compound extensions."""
impl ViteCompiler._jac_path_to_js(self: ViteCompiler, rel_str: str) -> str {
    # Convert Windows backslashes to forward slashes for JS imports
    rel_str = rel_str.replace('\\', '/');
    for compound_ext in self.COMPOUND_EXTENSIONS {
        if rel_str.endswith(compound_ext) {
            return rel_str[:-len(compound_ext)] + '.js';
        }
    }
    result = str(Path(rel_str).with_suffix('.js'));
    # Ensure forward slashes in the final result (Path may reintroduce backslashes on Windows)
    return result.replace('\\', '/');
}

"""Scan pages/ directory, compile page files, and generate _routes.js manifest.
Returns True if pages/ exists and routes were generated."""
impl ViteCompiler._scan_and_compile_pages(
    self: ViteCompiler,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None
) -> bool {
    scanner = RouteScanner(self.project_dir);
    if not scanner.has_pages_dir() {
        return False;
    }
    routes = scanner.scan();
    if not routes and not scanner.get_layouts() {
        return False;
    }
    self._route_scanner = scanner;
    # Compile each page file through the standard pipeline
    source_root = self.project_dir;
    for page_file in scanner.get_page_files() {
        self.compile_dependencies_recursively(
            page_file,
            visited=visited,
            collected_exports=collected_exports,
            collected_globals=collected_globals,
            source_root=source_root
        );
    }
    self._generate_routes_manifest();
    return True;
}

"""Generate _routes.js manifest from previously scanned route entries."""
impl ViteCompiler._generate_routes_manifest(self: ViteCompiler) -> None {
    scanner = self._route_scanner;
    # Use cached results from _scan_and_compile_pages - don't re-scan
    routes = scanner._routes;
    layouts = scanner.get_layouts();
    lines: list[str] = [];
    # Import page components
    for route in routes {
        if route.is_layout {
            continue;
        }
        # Compute relative import path from pages/ to compiled/pages/
        try {
            rel_path = route.file_path.relative_to(self.project_dir);
        } except ValueError {
            rel_path = route.file_path.relative_to(scanner.pages_dir.parent);
        }
        rel_str = self._jac_path_to_js(str(rel_path));
        lines.append(
            f'import {{ page as {route.component_import} }} from "./{rel_str}";'
        );
    }
    # Import layout components
    for (prefix, layout) in layouts.items() {
        try {
            rel_path = layout.file_path.relative_to(self.project_dir);
        } except ValueError {
            rel_path = layout.file_path.relative_to(scanner.pages_dir.parent);
        }
        rel_str = self._jac_path_to_js(str(rel_path));
        lines.append(
            f'import {{ layout as {layout.component_import} }} from "./{rel_str}";'
        );
    }
    lines.append('');
    # Export routes array
    lines.append('export const routes = [');
    for route in routes {
        if route.is_layout {
            continue;
        }
        auth_str = "true" if route.auth_required else "false";
        lines.append(
            f'\t{{ path: "{route.path}", element: {route.component_import}, auth: {auth_str} }},'
        );
    }
    lines.append('];');
    lines.append('');
    # Export layouts object
    lines.append('export const layouts = {');
    for (prefix, layout) in layouts.items() {
        lines.append(f'\t"{prefix}": {layout.component_import},');
    }
    lines.append('};');
    lines.append('');
    manifest_path = self.compiled_dir / '_routes.js';
    manifest_path.parent.mkdir(parents=True, exist_ok=True);
    manifest_path.write_text("\n".join(lines), encoding='utf-8');
}

"""Initialize the Vite compiler."""
impl ViteCompiler.init(
    self: ViteCompiler,
    vite_package_json: Path,
    vite_output_dir: (Path | None) = None,
    vite_minify: bool = False,
    runtime_path: (Path | None) = None,
    compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
    extract_exports_func: Callable[([any], list[str])],
    extract_globals_func: Callable[([any, ModuleType], dict[(str, Any)])]
) {
    if (not vite_package_json or not vite_package_json.exists()) {
        raise ClientBundleError(
            'Vite package.json not found. Set vite_package_json when using ViteCompiler'
        );
    }
    self.vite_package_json = vite_package_json;
    # Detect project root: package.json may be in .jac/client/configs/ or project root
    if (
        vite_package_json.parent.name == 'configs'
        and vite_package_json.parent.parent.name == 'client'
        and vite_package_json.parent.parent.parent.name == '.jac'
    ) {
        # .jac/client/configs/package.json -> go up 3 levels to project root
        self.project_dir = vite_package_json.parent.parent.parent.parent;
    } elif (vite_package_json.parent.name == 'configs') {
        self.project_dir = vite_package_json.parent.parent;
    } else {
        self.project_dir = vite_package_json.parent;
    }
    self.runtime_path = runtime_path;
    self.compiled_dir = self._get_client_dir() / 'compiled';
    self.jac_compiler = JacToJSCompiler(
        compile_to_js_func, extract_exports_func, extract_globals_func
    );
    self.import_processor = ImportProcessor();
    self.asset_processor = AssetProcessor();
    self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify);
    self._has_pages = False;
    self._route_scanner = None;
}
