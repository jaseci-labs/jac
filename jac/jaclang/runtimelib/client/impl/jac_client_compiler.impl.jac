import from jaclang.cli.console { console }

"""Resolve the core client runtime directory (D9 runtime lives here)."""
def _jac_client_plugin_dir -> Path {
    import importlib;
    client_pkg = importlib.import_module("jaclang.runtimelib.client");
    paths = list(getattr(client_pkg, "__path__", []) or []);
    if not paths {
        raise ClientBundleError(
            "jaclang.runtimelib.client not found; cannot locate D9 client runtime"
        );
    }
    return Path(paths[0]);
}

"""Default web runtime path for the D9 split (core + platform)."""
def jac_client_runtime_path -> Path {
    return _jac_client_plugin_dir() / "client_runtime.cl.jac";
}

"""Get the client build directory from project config."""
impl JacClientCompiler._get_client_dir(self: JacClientCompiler) -> Path {
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is not None {
            return config.get_client_dir();
        }
    } except ImportError { }
    return self.project_dir / '.jac' / 'client';
}

"""Convert a .jac relative path string to .js, handling compound extensions."""
impl JacClientCompiler._jac_path_to_js(self: JacClientCompiler, rel_str: str) -> str {
    rel_str = rel_str.replace('\\', '/');
    for compound_ext in self.COMPOUND_EXTENSIONS {
        if rel_str.endswith(compound_ext) {
            return rel_str[:-len(compound_ext)] + '.js';
        }
    }
    result = str(Path(rel_str).with_suffix('.js'));
    return result.replace('\\', '/');
}

"""Compile module and dependencies into the compiled/ directory.

This is the platform-neutral half of what ``ViteCompiler.compile`` used to do —
it does *not* write the web ``_entry.js``. Bundler-specific orchestrators
(``ViteCompiler`` for web, future ``MetroCompiler`` for native) layer their
entry generation on top of this output.
"""
impl JacClientCompiler.compile(
    self: JacClientCompiler,
    module: ModuleType,
    module_path: Path,
    runtime_filename: str = "client_runtime.cl.jac",
    target_name: str = "web"
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
        collected_globals=collected_globals,
        target_name=target_name
    );
    self._has_pages = self._scan_and_compile_pages(
        visited=visited,
        collected_exports=collected_exports,
        collected_globals=collected_globals,
        target_name=target_name
    );
    self.compile_runtime_utils(runtime_filename);
    import from jaclang.runtimelib.client.config_loader { JacClientConfig as PwaConfig }
    pwa_config = PwaConfig(self.project_dir);
    if pwa_config.is_pwa_enabled() and target_name != "react-native" {
        self.compile_pwa_runtime();
    }
    self.copy_root_assets();
    client_exports = sorted(collected_exports);
    client_globals = list(collected_globals.keys());
    return (client_exports, client_globals);
}

"""Copy assets from root assets/ folder to compiled/assets/."""
impl JacClientCompiler.copy_root_assets(self: JacClientCompiler) -> None {
    root_assets_dir = self.project_dir / 'assets';
    compiled_assets_dir = self.compiled_dir / 'assets';
    if (root_assets_dir.exists() and root_assets_dir.is_dir()) {
        self.asset_processor.copy_assets(root_assets_dir, compiled_assets_dir);
        self.asset_processor.copy_custom_asset_types(
            root_assets_dir, compiled_assets_dir
        );
    }
}

"""Copy an asset file to the compiled directory."""
impl JacClientCompiler._copy_asset_file(
    self: JacClientCompiler, asset_path: Path, source_root: Path
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
impl JacClientCompiler._copy_ts_file(
    self: JacClientCompiler, ts_path: Path, source_root: Path
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
impl JacClientCompiler._copy_js_file(
    self: JacClientCompiler, js_path: Path, source_root: Path
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

"""Recursively compile/copy .jac/.js imports into compiled/."""
impl JacClientCompiler.compile_dependencies_recursively(
    self: JacClientCompiler,
    module_path: Path,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None,
    source_root: (Path | None) = None,
    target_name: str = "web"
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
    if (
        target_name == "react-native"
        and module_path.name.endswith(".cl.jac")
        and not module_path.name.endswith(".native.cl.jac")
    ) {
        native_candidate = module_path.with_name(
            module_path.name[:-len(".cl.jac")] + ".native.cl.jac"
        );
        if native_candidate.exists() {
            module_path = native_candidate.resolve();
        }
    }
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
    # Source map generation: matches the .jac → .js mapping the runtime expects.
    try {
        import from jaclang.runtimelib.source_mapping { generate_source_map_json }
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        hub_key = str(module_path);
        hub_mod = Jac.program.mod.hub.get(hub_key);
        if hub_mod and hub_mod.gen.es_ast {
            import from jaclang.compiler.passes.ecmascript.es_unparse {
                es_to_js_with_map
            }
            (_, line_map) = es_to_js_with_map(hub_mod.gen.es_ast);
            if line_map {
                raw_js = hub_mod.gen.js or '';
                full_output = source_header + combined_js;
                raw_start_idx = full_output.find(raw_js);
                if raw_start_idx > 0 {
                    prefix = full_output[:raw_start_idx];
                    header_lines = prefix.count('\n');
                } else {
                    header_lines = 0;
                }
                if header_lines > 0 {
                    line_map = [
                        (out + header_lines, src_l, src_c)
                        for (out, src_l, src_c) in line_map
                    ];
                }
                map_json = generate_source_map_json(
                    source_file=str(module_path),
                    output_file=output_path.name,
                    line_map=line_map
                );
                map_path = output_path.parent / f"{output_path.name}.map";
                map_path.write_text(map_json, encoding='utf-8');
                with open(output_path, 'a', encoding='utf-8') as f {
                    f.write(f"\n//# sourceMappingURL={output_path.name}.map\n");
                }
            }
        }
    } except Exception as e {
        console.warning(f"Failed to generate source map for '{module_path}': {e}");
    }
    if (not manifest or not manifest.imports) {
        return;
    }
    for (_name, import_path) in manifest.imports.items() {
        path_obj = Path(import_path).resolve();
        if (
            target_name == "react-native"
            and path_obj.name.endswith(".cl.jac")
            and not path_obj.name.endswith(".native.cl.jac")
        ) {
            native_candidate = path_obj.with_name(
                path_obj.name[:-len(".cl.jac")] + ".native.cl.jac"
            );
            if native_candidate.exists() {
                path_obj = native_candidate.resolve();
            }
        }
        if (path_obj in visited) {
            continue;
        }
        if (path_obj.suffix == '.jac') {
            self.compile_dependencies_recursively(
                path_obj,
                visited,
                collected_exports=collected_exports,
                collected_globals=collected_globals,
                source_root=source_root,
                target_name=target_name
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

"""Collect top-level ``import`` lines from compiled JS."""
def _extract_import_lines(js_code: str) -> list[str] {
    imports: list[str] = [];
    for line in js_code.split('\n') {
        trimmed = line.strip();
        if trimmed.startswith('import ') {
            imports.append(line);
        }
    }
    return imports;
}

"""Return the ``const _jac = { ... };`` preamble from compiled JS, if present."""
def _extract_jac_preamble(js_code: str) -> str {
    start = js_code.find('const _jac =');
    if start < 0 {
        return '';
    }
    depth = 0;
    i = js_code.find('{', start);
    if i < 0 {
        return '';
    }
    while i < len(js_code) {
        ch = js_code[i];
        if ch == '{' {
            depth += 1;
        } elif ch == '}' {
            depth -= 1;
            if depth == 0 {
                end = i + 1;
                if end < len(js_code) and js_code[end] == ';' {
                    end += 1;
                }
                return js_code[start:end];
            }
        }
        i += 1;
    }
    return '';
}

"""Drop imports, ``_jac`` preamble, and export from a compiled runtime module.

Important: keep *all* remaining top-level runtime declarations (``let``/``const``)
because native runtime helpers rely on them (e.g. tag maps and prop adapters).
Older logic sliced from the first ``function`` token and accidentally discarded
those declarations.
"""
def _extract_function_bodies(js_code: str) -> str {
    stripped = _strip_esm_export_line(js_code);

    # Remove all ESM imports; runtime imports are merged separately.
    body_lines: list[str] = [];
    for line in stripped.split('\n') {
        if line.strip().startswith('import ') {
            continue;
        }
        body_lines.append(line);
    }
    body = '\n'.join(body_lines);

    # Remove the Jac helper preamble from the body; we include exactly one
    # preamble via `_bundle_runtime_js`.
    jac_preamble = _extract_jac_preamble(body);
    if jac_preamble {
        body = body.replace(jac_preamble, '', 1);
    }

    return body;
}

"""Merge import lines from two modules, dropping core cross-imports."""
def _merge_runtime_imports(platform_js: str, core_js: str) -> str {
    seen: set[str] = set();
    merged: list[str] = [];
    for line in _extract_import_lines(platform_js) + _extract_import_lines(core_js) {
        if 'client_runtime_core' in line {
            continue;
        }
        if line in seen {
            continue;
        }
        seen.add(line);
        merged.append(line);
    }
    return '\n'.join(merged);
}

"""Remove the trailing ESM ``export { ... };`` line from compiled runtime JS."""
def _strip_esm_export_line(js_code: str) -> str {
    lines = js_code.split('\n');
    filtered: list[str] = [];
    for line in lines {
        trimmed = line.strip();
        if trimmed.startswith('export {') or trimmed.startswith('export{') {
            continue;
        }
        filtered.append(line);
    }
    return '\n'.join(filtered);
}

"""Bundle D9 core + platform runtime into a single ``client_runtime.js``."""
def _bundle_runtime_js(core_js: str, platform_js: str, export_names: list[str]) -> str {
    imports = _merge_runtime_imports(platform_js, core_js);
    jac_preamble = _extract_jac_preamble(platform_js);
    if not jac_preamble {
        jac_preamble = _extract_jac_preamble(core_js);
    }
    core_body = _extract_function_bodies(core_js);
    platform_body = _extract_function_bodies(platform_js);
    export_line = 'export {' + ', '.join(export_names) + '};';
    parts: list[str] = [];
    if imports {
        parts.append(imports);
    }
    if jac_preamble {
        parts.append(jac_preamble);
    }
    if core_body {
        parts.append(core_body);
    }
    if platform_body {
        parts.append(platform_body);
    }
    parts.append(export_line);
    parts.append('__jacWirePlatformAdapters();');
    return '\n'.join(parts) + '\n';
}

"""Compile client runtime utilities. ``runtime_filename`` controls which
platform sibling of ``client_runtime.cl.jac`` is compiled (web vs. RN).
Always bundles ``client_runtime_core.cl.jac`` first (D9).
"""
impl JacClientCompiler.compile_runtime_utils(
    self: JacClientCompiler, runtime_filename: str = "client_runtime.cl.jac"
) -> tuple[str, list[str]] {
    if not self.runtime_path {
        raise ClientBundleError('Runtime path not set');
    }
    plugin_dir = _jac_client_plugin_dir();
    core_path = plugin_dir / 'client_runtime_core.cl.jac';
    runtime_utils_path = plugin_dir / runtime_filename;
    if not core_path.exists() {
        raise ClientBundleError(
            f'Runtime core not found: {core_path}. Expected client_runtime_core.cl.jac.'
        );
    }
    if not runtime_utils_path.exists() {
        raise ClientBundleError(
            f'Runtime file not found: {runtime_utils_path}. '
            'Expected sibling of client_runtime.cl.jac.'
        );
    }
    (core_js, _core_mod, core_manifest) = self.jac_compiler.compile_module(core_path);
    (platform_js, mod, runtimeutils_manifest) = self.jac_compiler.compile_module(
        runtime_utils_path
    );
    core_exports = self.jac_compiler.extract_exports(core_manifest);
    platform_exports = self.jac_compiler.extract_exports(runtimeutils_manifest);
    glob_names = list(runtimeutils_manifest.globals) if runtimeutils_manifest else [];
    all_exports = sorted(
        set(core_exports + platform_exports + self.ROUTER_EXPORTS + glob_names)
    );
    runtimeutils_js = _bundle_runtime_js(core_js, platform_js, all_exports);
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    (self.compiled_dir / 'client_runtime.js').write_text(
        runtimeutils_js, encoding='utf-8'
    );
    # Stage plugin-relative runtime deps the bundle still imports. The runtime
    # bundle inlines only core + platform; a sibling import such as
    # ``html_tag_map`` (pulled in by the native runtime) would otherwise dangle
    # in the staged native ``jac-src`` tree (Metro: "Unable to resolve
    # ./.../html_tag_map.js"). Compile each to the exact relative path the
    # bundle imports so ``shutil.copytree`` stages it for Metro. No-op for the
    # web runtime, which does not import these siblings.
    import re;
    import json;
    import importlib;
    for _m in re.finditer(
        r'from\s+[\'"](\./[^\'"]*html_tag_map\.js)[\'"]', runtimeutils_js
    ) {
        rel = _m.group(1)[2:];
        # ``html_tag_map`` is a plain ``.jac`` module (constant string arrays);
        # the ES codegen only emits JS for ``.cl.jac`` client modules, so
        # ``compile_module`` returns empty here. Generate the ESM module from
        # the Python-imported values instead — robust and self-contained.
        htm = importlib.import_module(
            "jaclang.runtimelib.client.targets.react_native.html_tag_map"
        );
        dep_js = "";
        for const_name in [
            "RN_HTML_VIEW_TAGS",
            "RN_HTML_TEXT_TAGS",
            "RN_HTML_SPECIAL_TAGS"
        ] {
            vals = list(getattr(htm, const_name, []));
            dep_js += f"export const {const_name} = {json.dumps(vals)};\n";
        }
        dep_out = self.compiled_dir / rel;
        dep_out.parent.mkdir(parents=True, exist_ok=True);
        dep_out.write_text(dep_js, encoding='utf-8');
    }
    # Emit the JacSX ``@jac/ui`` primitive module alongside the runtime. Doing
    # it here (rather than in ``compile()``) covers BOTH the web ViteCompiler
    # path — which calls ``compile_runtime_utils`` directly — and the native
    # path, so ``compiled/client_ui.js`` always exists for the ``@jac/ui`` alias.
    self.compile_ui_utils();
    return (runtimeutils_js, all_exports);
}

"""Compile PWA runtime utilities (only when PWA is enabled)."""
impl JacClientCompiler.compile_pwa_runtime(
    self: JacClientCompiler
) -> tuple[str, list[str]] {
    runtime_path = self.runtime_path;
    if runtime_path is None {
        return ('', []);
    }
    import jaclang;
    pwa_runtime_path: Path = (
        Path(jaclang.__file__).parent / "runtimelib" / "pwa_runtime.cl.jac"
    );
    if not pwa_runtime_path.exists() {
        return ('', []);
    }
    (pwa_js, mod, pwa_manifest) = self.jac_compiler.compile_module(pwa_runtime_path);
    pwa_exports_list = self.jac_compiler.extract_exports(pwa_manifest);
    glob_names = list(pwa_manifest.globals) if pwa_manifest else [];
    all_exports = sorted(set(pwa_exports_list + glob_names));
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    (self.compiled_dir / 'pwa_runtime.js').write_text(pwa_js, encoding='utf-8');
    return (pwa_js, all_exports);
}

"""Compile the JacSX ``@jac/ui`` primitive module to ``compiled/client_ui.js``.

Emitted as a plain ESM re-export module so the bundler's ``@jac/ui`` alias
resolves to it directly. No-op if the source file is missing.
"""
impl JacClientCompiler.compile_ui_utils(
    self: JacClientCompiler
) -> tuple[str, list[str]] {
    plugin_dir = _jac_client_plugin_dir();
    ui_path = plugin_dir / 'client_ui.cl.jac';
    if not ui_path.exists() {
        return ('', []);
    }
    (ui_js, _mod, ui_manifest) = self.jac_compiler.compile_module(ui_path);
    glob_names = list(ui_manifest.globals) if ui_manifest else [];

    shims_path = plugin_dir / 'client_ui.shims.js';
    if shims_path.exists() {
        ui_js += '\n' + shims_path.read_text(encoding='utf-8');
    }
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    (self.compiled_dir / 'client_ui.js').write_text(ui_js, encoding='utf-8');
    return (ui_js, glob_names);
}

"""Scan pages/ directory, compile page files, generate _routes.js manifest."""
impl JacClientCompiler._scan_and_compile_pages(
    self: JacClientCompiler,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None,
    target_name: str = "web"
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
    source_root = self.project_dir;
    for page_file in scanner.get_page_files() {
        self.compile_dependencies_recursively(
            page_file,
            visited=visited,
            collected_exports=collected_exports,
            collected_globals=collected_globals,
            source_root=source_root,
            target_name=target_name
        );
    }
    self._generate_routes_manifest();
    return True;
}

"""Generate _routes.js manifest from previously scanned route entries."""
impl JacClientCompiler._generate_routes_manifest(self: JacClientCompiler) -> None {
    scanner = self._route_scanner;
    routes = scanner._routes;
    layouts = scanner.get_layouts();
    lines: list[str] = [];
    for route in routes {
        if route.is_layout {
            continue;
        }
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

"""Initialize the platform-neutral Jac client compiler."""
impl JacClientCompiler.init(
    self: JacClientCompiler,
    project_dir: Path,
    runtime_path: (Path | None),
    compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])],
    extract_exports_func: Callable[([any], list[str])],
    extract_globals_func: Callable[([any, ModuleType], dict[(str, Any)])],
    compiled_dir: (Path | None) = None
) {
    self.project_dir = project_dir;
    self.runtime_path = runtime_path;
    self.compiled_dir = compiled_dir
        if compiled_dir is not None
        else (self._get_client_dir() / 'compiled');
    self.jac_compiler = JacToJSCompiler(
        compile_to_js_func, extract_exports_func, extract_globals_func
    );
    self.import_processor = ImportProcessor();
    self.asset_processor = AssetProcessor();
    self._has_pages = False;
    self._route_scanner = None;
}
