import from jaclang.cli.console { console }

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

impl JacClientCompiler._native_variant(self: JacClientCompiler, path: Path) -> Path {
    import from jaclang.jac0core.ext_registry { base_stem }
    name = path.name;
    if ".native." in name {
        return path;
    }
    stem = base_stem(name);
    for suffix in (".native.cl.jac", ".native.jac") {
        candidate = path.with_name(stem + suffix);
        if candidate.exists() {
            return candidate.resolve();
        }
    }
    return path;
}

impl JacClientCompiler.compile(
    self: JacClientCompiler,
    module: ModuleType,
    module_path: Path,
    target_name: str = "web"
) -> tuple[list[str], list[str]] {
    (module_js, mod, module_manifest) = self.jac_compiler.compile_module(module_path);
    collected_exports: set[str] = set(
        self.jac_compiler.extract_exports(module_manifest)
    );
    client_globals_map = self.jac_compiler.extract_globals(module_manifest, module);
    collected_globals: dict[(str, Any)] = dict(client_globals_map);
    visited: set[Path] = set();
    project_root = self.project_dir.resolve();
    entry_root = module_path.resolve().parent;
    source_root = (
        project_root if entry_root.is_relative_to(project_root) else entry_root
    );
    self.compile_dependencies_recursively(
        module_path,
        visited=visited,
        collected_exports=collected_exports,
        collected_globals=collected_globals,
        source_root=source_root,
        target_name=target_name
    );
    self._has_pages = self._scan_and_compile_pages(
        visited=visited,
        collected_exports=collected_exports,
        collected_globals=collected_globals,
        target_name=target_name
    );
    runtime_filename = self.PLATFORM_RUNTIME_FILES.get(target_name);
    if runtime_filename {
        self.compile_runtime_utils(runtime_filename);
    }
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
    } except (FileNotFoundError, OSError) as e {
        console.warning(f"Failed to copy TS dependency '{ts_path}': {e}");
    }
}

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
    } except (FileNotFoundError, OSError) as e {
        console.warning(f"Failed to copy JS dependency '{js_path}': {e}");
    }
}

impl JacClientCompiler._output_path_for(
    self: JacClientCompiler, module_path: Path, source_root: Path
) -> Path {
    try {
        relative_path = module_path.relative_to(source_root);
        return self.compiled_dir / self._jac_path_to_js(str(relative_path));
    } except ValueError {
        return self.compiled_dir / self._jac_path_to_js(module_path.name);
    }
}

impl JacClientCompiler.compile_dependencies_recursively(
    self: JacClientCompiler,
    module_path: Path,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None,
    source_root: (Path | None) = None,
    target_name: str = "web",
    skip_existing: bool = False
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
    if target_name == "react-native" {
        module_path = self._native_variant(module_path);
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
    self._write_source_map(
        mod, str(module_path), output_path, source_header + combined_js
    );
    if (not manifest or not manifest.imports) {
        return;
    }
    for (_name, import_path) in manifest.imports.items() {
        path_obj = Path(import_path).resolve();
        if target_name == "react-native" {
            path_obj = self._native_variant(path_obj);
        }
        if (path_obj in visited) {
            continue;
        }
        if (path_obj.suffix == '.jac') {
            if skip_existing
            and self._output_path_for(path_obj, source_root).exists() {
                continue;
            }
            self.compile_dependencies_recursively(
                path_obj,
                visited,
                collected_exports=collected_exports,
                collected_globals=collected_globals,
                source_root=source_root,
                target_name=target_name,
                skip_existing=skip_existing
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

def _extract_function_bodies(js_code: str) -> str {
    stripped = _strip_esm_export_line(js_code);

    body_lines: list[str] = [];
    for line in stripped.split('\n') {
        if line.strip().startswith('import ') {
            continue;
        }
        body_lines.append(line);
    }
    body = '\n'.join(body_lines);

    jac_preamble = _extract_jac_preamble(body);
    if jac_preamble {
        body = body.replace(jac_preamble, '', 1);
    }

    return body;
}

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

impl JacClientCompiler.compile_runtime_utils(
    self: JacClientCompiler, runtime_filename: str
) -> tuple[str, list[str]] {
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
            'Expected a platform runtime beside client_runtime_core.cl.jac.'
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

    import re;
    import json;
    import importlib;

    for _m in re.finditer(
        r'from\s+[\'"]((?:\./)?[^\'"]*html_tag_map\.js)[\'"]', runtimeutils_js
    ) {
        rel = _m.group(1);
        if rel.startswith('./') {
            rel = rel[2:];
        }
        if '..' in Path(rel).parts {
            console.warning(
                f"Skipping html_tag_map re-export for specifier outside the "
                f"compiled dir: {_m.group(1)}"
            );
            continue;
        }
        htm = importlib.import_module(
            "jaclang.runtimelib.client.targets.react_native.html_tag_map"
        );
        dep_js = "";
        for const_name in sorted(dir(htm)) {
            vals = getattr(htm, const_name, None);
            if const_name.startswith("RN_") and isinstance(vals, list) {
                dep_js += f"export const {const_name} = {json.dumps(vals)};\n";
            }
        }
        dep_out = self.compiled_dir / rel;
        dep_out.parent.mkdir(parents=True, exist_ok=True);
        dep_out.write_text(dep_js, encoding='utf-8');
    }

    self.compile_mobui_utils();
    return (runtimeutils_js, all_exports);
}

impl JacClientCompiler.compile_pwa_runtime(
    self: JacClientCompiler
) -> tuple[str, list[str]] {
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
    pwa_out = self.compiled_dir / 'pwa_runtime.js';
    pwa_out.write_text(pwa_js, encoding='utf-8');
    self._write_source_map(mod, str(pwa_runtime_path), pwa_out, pwa_js);
    return (pwa_js, all_exports);
}

impl JacClientCompiler._write_source_map(
    self: JacClientCompiler,
    mod: Any,
    source_file: str,
    output_path: Path,
    full_output: str
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

        raw_js = mod.gen.js or '';
        raw_start = full_output.find(raw_js) if raw_js else -1;
        if raw_start < 0 {
            return;
        }
        header_lines = full_output[:raw_start].count('\n');
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

impl JacClientCompiler.compile_mobui_utils(
    self: JacClientCompiler
) -> tuple[str, list[str]] {
    plugin_dir = _jac_client_plugin_dir();
    ui_path = plugin_dir / 'client_mobui.cl.jac';
    if not ui_path.exists() {
        return ('', []);
    }
    (ui_js, _mod, ui_manifest) = self.jac_compiler.compile_module(ui_path);
    glob_names = list(ui_manifest.globals) if ui_manifest else [];

    shims_path = plugin_dir / 'client_mobui.shims.js';
    if shims_path.exists() {
        ui_js += '\n' + shims_path.read_text(encoding='utf-8');
    }
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    (self.compiled_dir / 'client_mobui.js').write_text(ui_js, encoding='utf-8');
    return (ui_js, glob_names);
}

impl JacClientCompiler._scan_and_compile_pages(
    self: JacClientCompiler,
    visited: (set[Path] | None) = None,
    collected_exports: (set[str] | None) = None,
    collected_globals: (dict[(str, Any)] | None) = None,
    target_name: str = "web"
) -> bool {
    scanner = RouteScanner(self.project_dir, route_exports_of=resolve_route_exports);
    if not scanner.has_pages_dir() {
        return False;
    }
    routes = scanner.scan();
    if not routes and not scanner.get_layouts() {
        self._warn_pages_without_routes(scanner);
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

impl JacClientCompiler._warn_pages_without_routes(
    self: JacClientCompiler, scanner: RouteScanner
) -> None {
    import from jaclang.runtimelib.client.route_scanner {
        describe_pages_without_routes
    }
    for line in describe_pages_without_routes(scanner.pages_dir) {
        console.error(line);
    }
}

impl JacClientCompiler.rescan_pages(self: JacClientCompiler) -> bool {
    scanner = RouteScanner(self.project_dir, route_exports_of=resolve_route_exports);
    if not scanner.has_pages_dir() {
        return False;
    }
    routes = scanner.scan();
    if not routes and not scanner.get_layouts() {
        self._warn_pages_without_routes(scanner);
        return False;
    }
    self._route_scanner = scanner;

    for page_file in scanner.get_page_files() {
        if self._output_path_for(page_file, self.project_dir).exists() {
            continue;
        }
        try {
            self.compile_dependencies_recursively(
                page_file, source_root=self.project_dir, skip_existing=True
            );
        } except Exception as e {
            console.warning(f"Could not compile page {page_file}: {e}");
        }
    }
    self._generate_routes_manifest();
    return True;
}

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
            f'import {{ {route.source_export} as {route.component_import} }} '
            f'from "./{rel_str}";'
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
            f'import {{ {layout.source_export} as {layout.component_import} }} '
            f'from "./{rel_str}";'
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
    new_content = "\n".join(lines);

    try {
        if manifest_path.exists()
        and manifest_path.read_text(encoding='utf-8') == new_content {
            return;
        }
    } except OSError { }
    manifest_path.write_text(new_content, encoding='utf-8');
}

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
