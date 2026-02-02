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
    return (bundle_code, bundle_hash, client_exports, client_globals);
}

"""Create the main entry file for Vite bundling."""
impl ViteCompiler.create_entry_file(self: ViteCompiler, module_path: Path) -> None {
    # Use _entry.js to avoid conflict with compiled modules that may be named main.js
    entry_file = self.compiled_dir / '_entry.js';
    if self._has_pages {
        # File-based routing mode: import from generated _routes.js
        entry_content = self._create_pages_entry_content(module_path);
    } else {
        # Explicit routing mode: import app from entry module (original behavior)
        app_module_name = module_path.stem;
        entry_content = f'import React from "react";\nimport {{ createRoot }} from "react-dom/client";\nimport {{ app as App }} from "./{app_module_name}.js";\nimport {{ JacClientErrorBoundary, ErrorFallback }} from "@jac/runtime";\n\nconst root = createRoot(document.getElementById("root"));\nroot.render(\n\tReact.createElement(\n\t\tJacClientErrorBoundary,{{ FallbackComponent: ErrorFallback }},\n\t\tReact.createElement(App, null)\n\t)\n);\n';
    }
    entry_file.write_text(entry_content, encoding='utf-8');
}

impl ViteCompiler._create_pages_entry_content(
    self: ViteCompiler, module_path: Path
) -> str {
    lines: list[str] = [];
    auth_redirect = "/login";
    try {
        import from ..config_loader { PluginConfig }
        config = PluginConfig.load(self.project_dir);
        if config and config?.routing and config.routing {
            auth_redirect = config.routing.get('auth_redirect', '/login');
        }
    } except Exception { }
    # Check if main.jac exists and exports app (used as wrapper)
    app_module = self.compiled_dir / f"{module_path.stem}.js";
    has_app_wrapper = app_module.exists();
    # --- Imports ---
    lines.append('import React from "react";');
    lines.append('import { createRoot } from "react-dom/client";');
    lines.append('import { BrowserRouter, Routes, Route } from "react-router-dom";');
    lines.append(
        'import { JacClientErrorBoundary, ErrorFallback, AuthGuard } from "@jac/runtime";'
    );
    lines.append('import { routes, layouts } from "./_routes.js";');
    if has_app_wrapper {
        lines.append(f'import {{ app as AppWrapper }} from "./{module_path.stem}.js";');
    }
    lines.append('');
    # --- Route helpers ---
    lines.append('const publicRoutes = routes.filter(r => !r.auth);');
    lines.append('const authRoutes = routes.filter(r => r.auth);');
    lines.append('const RootLayout = layouts["/"] || null;');
    lines.append('');
    lines.append('function renderRoutes(routeList) {');
    lines.append('\treturn routeList.map(r =>');
    lines.append(
        '\t\tReact.createElement(Route, { key: r.path, path: r.path, element: React.createElement(r.element, null) })'
    );
    lines.append('\t);');
    lines.append('}');
    lines.append('');
    # --- Auth guard routes (reused in both layout and non-layout paths) ---
    # AuthGuard is a runtime function compiled with plain parameters (not React props
    # destructuring), so we wrap it in a component that passes the redirect string directly.
    lines.append(
        f'function _AuthGuardRoute() {{ return AuthGuard("{auth_redirect}"); }}'
    );
    lines.append(
        'const authGuardElement = React.createElement(_AuthGuardRoute, null);'
    );
    lines.append('');
    # --- Single App component with one BrowserRouter ---
    lines.append('function App() {');
    lines.append('\tconst routeChildren = [');
    lines.append('\t\t...renderRoutes(publicRoutes),');
    lines.append(
        '\t\tReact.createElement(Route, { key: "__auth", element: authGuardElement },'
    );
    lines.append('\t\t\t...renderRoutes(authRoutes)');
    lines.append('\t\t),');
    lines.append('\t];');
    lines.append('');
    lines.append('\tconst routeTree = RootLayout');
    lines.append(
        '\t\t? React.createElement(Route, { element: React.createElement(RootLayout, null) }, ...routeChildren)'
    );
    lines.append('\t\t: routeChildren;');
    lines.append('');
    lines.append('\treturn React.createElement(BrowserRouter, null,');
    lines.append('\t\tReact.createElement(Routes, null,');
    lines.append('\t\t\t...(Array.isArray(routeTree) ? routeTree : [routeTree])');
    lines.append('\t\t)');
    lines.append('\t);');
    lines.append('}');
    lines.append('');
    # --- Root render ---
    if has_app_wrapper {
        lines.append(
            'const appElement = React.createElement(AppWrapper, null, React.createElement(App, null));'
        );
    } else {
        lines.append('const appElement = React.createElement(App, null);');
    }
    lines.append('');
    lines.append('const root = createRoot(document.getElementById("root"));');
    lines.append('root.render(');
    lines.append(
        '\tReact.createElement(JacClientErrorBoundary, { FallbackComponent: ErrorFallback }, appElement)'
    );
    lines.append(');');
    lines.append('');
    return "\n".join(lines);
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
    with contextlib.suppress(FileNotFoundError, OSError) {
        output_path.write_text(
            asset_path.read_text(encoding='utf-8'), encoding='utf-8'
        );
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
        } elif (path_obj.suffix in {'.ts','.tsx'}) {
            self._copy_ts_file(path_obj, source_root);
        } elif path_obj.is_file() {
            self._copy_asset_file(path_obj, source_root);
        }
    }
}

"""Compile client runtime utilities."""
impl ViteCompiler.compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]] {
    if not self.runtime_path {
        raise ClientBundleError('Runtime path not set') ;
    }
    runtime_utils_path = self.runtime_path.parent / 'client_runtime.cl.jac';
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
    (self.compiled_dir / 'client_runtime.js').write_text(
        runtimeutils_js, encoding='utf-8'
    );
    return (runtimeutils_js, all_exports);
}

"""Convert a .jac relative path string to .js, handling compound extensions."""
impl ViteCompiler._jac_path_to_js(self: ViteCompiler, rel_str: str) -> str {
    for compound_ext in self.COMPOUND_EXTENSIONS {
        if rel_str.endswith(compound_ext) {
            return rel_str[:-len(compound_ext)] + '.js';
        }
    }
    return str(Path(rel_str).with_suffix('.js'));
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
    # Use cached results from _scan_and_compile_pages — don't re-scan
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
    compile_to_js_func: (Callable[([Path], tuple[(str, (ModuleType | None))])] | None) = None,
    extract_exports_func: (Callable[([Any], list[str])] | None) = None,
    extract_globals_func: (Callable[([Any, ModuleType], dict[(str, Any)])] | None) = None
) {
    if (not vite_package_json or not vite_package_json.exists()) {
        raise ClientBundleError(
            'Vite package.json not found. Set vite_package_json when using ViteCompiler'
        ) ;
    }
    if (
        (compile_to_js_func is None)
        or (extract_exports_func is None)
        or (extract_globals_func is None)
    ) {
        raise ClientBundleError(
            'compile_to_js_func, extract_exports_func, and extract_globals_func are required'
        ) ;
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
