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

"""Compile module and dependencies, then bundle with Vite."""
impl ViteCompiler.compile_and_bundle(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[str, str, list[str], list[str]] {
    self.compile_runtime_utils();
    (module_js, mod, module_manifest) = self.jac_compiler.compile_module(module_path);
    collected_exports: set[str] = set(
        self.jac_compiler.extract_exports(module_manifest)
    );
    client_globals_map = self.jac_compiler.extract_globals(module_manifest, module);
    collected_globals: dict[(str, Any)] = dict(client_globals_map);
    self.compile_dependencies_recursively(
        module_path,
        collected_exports=collected_exports,
        collected_globals=collected_globals
    );
    self.copy_root_assets();
    self.create_entry_file(module_path);
    self.babel_processor.compile();
    client_dir = self._get_client_dir();
    self.babel_processor.copy_assets_after_compile(
        self.compiled_dir, (client_dir / 'build'), self.asset_processor
    );
    entry_file = client_dir / 'build' / '_entry.js';
    self.vite_bundler.build(entry_file=entry_file);
    (bundle_code, bundle_hash) = self.vite_bundler.read_bundle();
    client_exports = sorted(collected_exports);
    client_globals = list(collected_globals.keys());
    return (bundle_code, bundle_hash, client_exports, client_globals);
}

"""Create the main entry file for Vite bundling."""
impl ViteCompiler.create_entry_file(self: ViteCompiler, module_path: Path) -> None {
    # Use _entry.js to avoid conflict with compiled modules that may be named main.js
    entry_file = self.compiled_dir / '_entry.js';
    # Derive the app module filename from the entry point (e.g., main.jac -> main.js, app.jac -> app.js)
    app_module_name = module_path.stem;
    entry_content = f'import React from "react";\nimport {{ createRoot }} from "react-dom/client";\nimport {{ app as App }} from "./{app_module_name}.js";\nimport {{ JacClientErrorBoundary, ErrorFallback }} from "@jac-client/utils";\n\nconst root = createRoot(document.getElementById("root"));\nroot.render(\n\tReact.createElement(\n\t\tJacClientErrorBoundary,{{ FallbackComponent: ErrorFallback }},\n\t\tReact.createElement(App, null)\n\t)\n);\n';
    entry_file.write_text(entry_content, encoding='utf-8');
}

"""Copy assets from root assets/ folder to compiled/assets/ for @jac-client/assets alias."""
impl ViteCompiler.copy_root_assets(self: ViteCompiler) -> None {
    root_assets_dir = self.project_dir / 'assets';
    compiled_assets_dir = self.compiled_dir / 'assets';
    if (root_assets_dir.exists() and root_assets_dir.is_dir()) {
        self.asset_processor.copy_assets(root_assets_dir, compiled_assets_dir);
    }
    # Copy configured_asset files from root assets/ to build assets/ (bypassing compiled)
    build_assets_dir = self._get_client_dir() / 'build' / 'assets';
    if (root_assets_dir.exists() and root_assets_dir.is_dir()) {
        self.asset_processor.copy_custom_asset_types(root_assets_dir, build_assets_dir);
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
        # Handle compound extensions like .cl.jac, .impl.jac -> .js
        rel_str = str(relative_path);
        for compound_ext in ['.cl.jac', '.impl.jac', '.test.jac'] {
            if rel_str.endswith(compound_ext) {
                rel_str = rel_str[:-len(compound_ext)] + '.js';
                break;
            }
        } else {
            rel_str = str(relative_path.with_suffix('.js'));
        }
        output_path = self.compiled_dir / rel_str;
    } except ValueError {
        # Handle compound extensions in filename
        name = module_path.name;
        for compound_ext in ['.cl.jac', '.impl.jac', '.test.jac'] {
            if name.endswith(compound_ext) {
                name = name[:-len(compound_ext)] + '.js';
                break;
            }
        } else {
            name = module_path.stem + '.js';
        }
        output_path = self.compiled_dir / name;
    }
    output_path.parent.mkdir(parents=True, exist_ok=True);
    output_path.write_text(combined_js, encoding='utf-8');
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
    all_exports = sorted(set((runtimeutils_exports_list + self.ROUTER_EXPORTS)));
    combined_runtime_utils_js = runtimeutils_js;
    self.compiled_dir.mkdir(parents=True, exist_ok=True);
    (self.compiled_dir / 'client_runtime.js').write_text(
        combined_runtime_utils_js, encoding='utf-8'
    );
    return (combined_runtime_utils_js, all_exports);
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
    self.babel_processor = BabelProcessor(self.project_dir);
    self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify);
}
