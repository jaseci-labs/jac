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

"""Compile module and dependencies, then bundle with Vite.

Uses upfront compilation: all source files are discovered and compiled
before Vite runs, ensuring import aliases work correctly.
"""
impl ViteCompiler.compile_and_bundle(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[str, str, list[str], list[str]] {
    # 1. Compile runtime utilities first
    self.compile_runtime_utils();

    # 2. Compile all source files upfront (replaces lazy compilation)
    (collected_exports, collected_globals) = self.compile_all_source_files(
        module, module_path
    );

    # 3. Copy root assets
    self.copy_root_assets();

    # 4. Create entry file
    self.create_entry_file(module_path);

    # 5. Run Babel transpilation
    self.babel_processor.compile();

    # 6. Copy assets to build directory
    client_dir = self._get_client_dir();
    self.babel_processor.copy_assets_after_compile(
        self.compiled_dir, (client_dir / 'build'), self.asset_processor
    );

    # 7. Run Vite bundler
    entry_file = client_dir / 'build' / '_entry.js';
    self.vite_bundler.build(entry_file=entry_file);

    # 8. Read and return bundle
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

# =============================================================================
# Phase 1: Source Discovery
# =============================================================================

"""Jac file extensions that should not be copied as-is (they get compiled or skipped)."""
glob JAC_EXTENSIONS: list[str] = ['.jac', '.cl.jac', '.impl.jac', '.test.jac', '.sv.jac'];

"""Check if a file is any type of Jac file."""
impl ViteCompiler._is_jac_file(self: ViteCompiler, file_path: Path) -> bool {
    name = file_path.name;
    return any(name.endswith(ext) for ext in JAC_EXTENSIONS);
}

"""Determine if a Jac file should be compiled based on companion detection rules."""
impl ViteCompiler._should_compile_jac_file(
    self: ViteCompiler, file_path: Path, all_jac_files: set[Path]
) -> bool {
    name = file_path.name;

    # Always skip impl, test, and server-only files (always companions or non-client)
    if (name.endswith('.impl.jac') or name.endswith('.test.jac') or name.endswith('.sv.jac')) {
        return False;
    }

    # Always compile plain .jac files (not .cl.jac)
    if (name.endswith('.jac') and not name.endswith('.cl.jac')) {
        return True;
    }

    # For .cl.jac, check if parent .jac exists (companion detection)
    if name.endswith('.cl.jac') {
        parent_name = name.replace('.cl.jac', '.jac');
        parent_path = file_path.parent / parent_name;
        # Compile only if standalone (no parent .jac exists)
        return parent_path.resolve() not in all_jac_files;
    }

    return False;
}

"""
Discover all files in source directory.

Returns a tuple of:
- files_to_compile: List of Jac files that should be compiled
- files_to_copy: List of non-Jac files that should be copied as-is
"""
impl ViteCompiler.discover_source_files(
    self: ViteCompiler,
    source_root: Path,
    exclude_patterns: (list[str] | None) = None
) -> tuple[list[Path], list[Path]] {
    if exclude_patterns is None {
        exclude_patterns = ['__pycache__', 'node_modules', '.jac', '.git', '__jac_gen__', 'jac.toml' ];
    }

    all_jac_files: set[Path] = set();
    other_files: list[Path] = [];

    # Walk the source directory recursively
    for item in source_root.rglob('*') {
        # Skip directories
        if item.is_dir() {
            continue;
        }

        # Check if any parent directory matches exclude patterns
        rel_parts = item.relative_to(source_root).parts;
        should_exclude = False;
        for part in rel_parts[:-1] {  # Check all parent directories
            if (part in exclude_patterns or part.startswith('.')) {
                should_exclude = True;
                break;
            }
        }
        if should_exclude {
            continue;
        }

        # Skip hidden files
        if item.name.startswith('.') {
            continue;
        }

        # Categorize the file
        if self._is_jac_file(item) {
            all_jac_files.add(item.resolve());
        } else {
            other_files.append(item);
        }
    }

    # Filter Jac files to determine which to compile
    files_to_compile = [
        f for f in all_jac_files
        if self._should_compile_jac_file(f, all_jac_files)
    ];

    return (sorted(files_to_compile), sorted(other_files));
}

# =============================================================================
# Phase 2: Alias Resolution
# =============================================================================

"""
Load aliases from jac.toml configuration.

Returns a dictionary mapping alias prefixes to resolved absolute paths.
Built-in aliases (@jac-client/utils, @jac-client/assets) are handled by Vite config.
This method loads user-defined aliases from [plugins.client.vite.resolve.alias].
"""
impl ViteCompiler.load_aliases(self: ViteCompiler, source_root: Path) -> dict[str, Path] {
    aliases: dict[str, Path] = {};

    # Load user-defined aliases from vite config
    vite_config = self.vite_bundler.config_loader.get_vite_config();
    resolve_config = vite_config.get('resolve', {});
    user_aliases = resolve_config.get('alias', {}) if isinstance(resolve_config, dict) else {};

    for (alias_key, alias_path) in user_aliases.items() {
        if isinstance(alias_path, str) {
            # Remove leading ./ if present
            clean_path = alias_path.lstrip('./');
            # Resolve relative to source_root
            resolved = (source_root / clean_path).resolve();
            aliases[alias_key] = resolved;
        }
    }

    return aliases;
}

# =============================================================================
# Phase 3: Upfront Compilation
# =============================================================================

"""
Compile all source files upfront before bundling.

This replaces the lazy/on-demand compilation approach.
All .jac files are discovered and compiled first, then all other files are copied.
This ensures aliases work because all files exist when Vite runs.

Returns:
    tuple of (collected_exports, collected_globals)
"""
impl ViteCompiler.compile_all_source_files(
    self: ViteCompiler,
    module: ModuleType,
    module_path: Path
) -> tuple[set[str], dict[str, Any]] {
    source_root = module_path.parent.resolve();

    # Load aliases for reference (not used during compilation, but logged)
    aliases = self.load_aliases(source_root);

    # Discover all files in source directory
    (files_to_compile, files_to_copy) = self.discover_source_files(source_root);

    collected_exports: set[str] = set();
    collected_globals: dict[str, Any] = {};

    # First, compile the entry module to get its exports/globals
    (entry_js, mod, entry_manifest) = self.jac_compiler.compile_module(module_path);
    exports_list = self.jac_compiler.extract_exports(entry_manifest);
    collected_exports.update(exports_list);
    client_globals_map = self.jac_compiler.extract_globals(entry_manifest, module);
    collected_globals.update(client_globals_map);

    # Write entry module
    combined_js = self.jac_compiler.add_runtime_imports(entry_js);
    output_name = module_path.stem + '.js';
    output_path = self.compiled_dir / output_name;
    output_path.parent.mkdir(parents=True, exist_ok=True);
    output_path.write_text(combined_js, encoding='utf-8');

    # Track compiled files to avoid duplicates
    compiled_files: set[Path] = {module_path.resolve()};

    # Compile all discovered Jac files
    for file_path in files_to_compile {
        resolved_path = file_path.resolve();
        if resolved_path in compiled_files {
            continue;
        }
        compiled_files.add(resolved_path);

        try {
            (module_js, mod, manifest) = self.jac_compiler.compile_module(file_path);

            # Collect exports
            exports_list = self.jac_compiler.extract_exports(manifest);
            collected_exports.update(exports_list);

            # Collect globals (non-root modules)
            if manifest {
                for name in manifest.globals {
                    collected_globals[name] = manifest.globals_values.get(name);
                }
            }

            # Add runtime imports and write
            combined_js = self.jac_compiler.add_runtime_imports(module_js);

            # Determine output path preserving directory structure
            try {
                relative_path = file_path.relative_to(source_root);
                # Handle compound extensions
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
                # File is outside source_root
                name = file_path.name;
                for compound_ext in ['.cl.jac', '.impl.jac', '.test.jac'] {
                    if name.endswith(compound_ext) {
                        name = name[:-len(compound_ext)] + '.js';
                        break;
                    }
                } else {
                    name = file_path.stem + '.js';
                }
                output_path = self.compiled_dir / name;
            }

            output_path.parent.mkdir(parents=True, exist_ok=True);
            output_path.write_text(combined_js, encoding='utf-8');
        } except Exception as e {
            # Log but continue - some files may fail to compile
            import logging;
            logger = logging.getLogger(__name__);
            logger.warning(f"Failed to compile {file_path}: {e}");
        }
    }

    # Copy all non-Jac files (js, ts, css, images, etc.)
    for file_path in files_to_copy {
        self.copy_file_to_compiled(file_path, source_root);
    }

    return (collected_exports, collected_globals);
}

# =============================================================================
# Phase 4: Unified File Copying
# =============================================================================

"""Copy any non-Jac file to the compiled directory, preserving relative path structure."""
impl ViteCompiler.copy_file_to_compiled(
    self: ViteCompiler, source_path: Path, source_root: Path
) -> None {
    import shutil;

    if not source_path.exists() {
        return;
    }

    try {
        rel_path = source_path.relative_to(source_root);
        dest_path = self.compiled_dir / rel_path;
    } except ValueError {
        # File is outside source_root, use just the filename
        dest_path = self.compiled_dir / source_path.name;
    }

    # Ensure parent directory exists
    dest_path.parent.mkdir(parents=True, exist_ok=True);

    # Copy the file preserving metadata
    shutil.copy2(source_path, dest_path);
}
