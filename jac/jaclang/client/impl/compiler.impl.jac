import from jaclang.cli.console { console }

impl ViteCompiler.compile(
    self: ViteCompiler, module: (ModuleType | None), module_path: Path
) -> tuple[list[str], list[str]] {
    (client_exports, client_globals) = self.jac_client_compiler.compile(
        module, module_path
    );
    self._has_pages = self.jac_client_compiler._has_pages;

    self.compile_runtime_utils();
    self.compile_desktop_sdk();
    self.create_entry_file(module_path);
    return (client_exports, client_globals);
}

impl ViteCompiler.compile_and_bundle(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[str, str, list[str], list[str]] {
    (client_exports, client_globals) = self.compile(module, module_path);

    entry_file = self.compiled_dir / '_entry.js';
    self.vite_bundler.build(entry_file=entry_file);
    (bundle_code, bundle_hash) = self.vite_bundler.read_bundle();

    self._emit_na_wasm(module_path);
    return (bundle_code, bundle_hash, client_exports, client_globals);
}

impl ViteCompiler._owes_wasm(self: ViteCompiler, module_path: Path) -> bool {
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang { JacRuntime as Jac }
    target = str(module_path.resolve());
    compiled = Jac.get_program().mod.hub.get(target);
    if compiled is not None {
        return bool(compiled.declares_codespace(CodeContext.NATIVE));
    }
    declared = self.jac_client_compiler?.na_wasm_modules or set();
    for known in declared {
        try {
            if str(Path(known).resolve()) == target {
                return True;
            }
        } except OSError {
            continue;
        }
    }
    console.warning(
        f"'{module_path.name}' not found in the compile hub and not recorded "
            + "as a client native import, so no wasm will be emitted for it."
    );
    return False;
}

impl ViteCompiler._emit_na_wasm(self: ViteCompiler, module_path: Path) -> None {
    if self._owes_wasm(module_path) {
        self._emit_wasm_module(module_path);
    }

    declared = sorted(
        getattr(self.jac_client_compiler, 'na_wasm_modules', set()) or set()
    );
    for path_str in declared {
        target = Path(path_str).resolve();
        if target == module_path.resolve() {
            continue;
        }
        if not target.exists() {
            console.warning(
                f"na import target '{path_str}' not found; no wasm emitted for it"
            );
            continue;
        }
        self._emit_wasm_module(target);
    }
}

impl ViteCompiler._emit_wasm_module(self: ViteCompiler, module_path: Path) -> bool {
    import from jaclang.compiler.backends.native.wasm_build { compile_to_wasm }
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    try {
        wasm = compile_to_wasm(str(module_path));
    } except Exception as e {
        console.error(f"na->wasm failed for '{module_path.name}': {e}");
        return False;
    }
    stem = native_wasm_stem(str(module_path));
    dist = self.vite_bundler.output_dir;
    dist.mkdir(parents=True, exist_ok=True);
    out_path = dist / f"{stem}.wasm";
    out_path.write_bytes(wasm);
    console.print(f"  Native wasm module: /static/{stem}.wasm ({len(wasm)} bytes)");

    try {
        import json;
        import from jaclang.compiler.backends.native.wasm_build { wasm_import_map }
        import from jaclang.compiler.backends.native.wasm_host_abi { WASM_HOST_MODULE }
        imports = wasm_import_map(wasm);
        manifest_path = dist / f"{stem}.wasm.imports.json";
        manifest_path.write_text(
            json.dumps({"abi": WASM_HOST_MODULE, "imports": imports}, indent=2),
            encoding='utf-8',
        );
        app_ffi = [];
        for mod_nm in imports {
            if mod_nm != WASM_HOST_MODULE {
                app_ffi.extend(imports[mod_nm]);
            }
        }
        if app_ffi {
            console.print(
                f"    app FFI imports ({len(app_ffi)}): provide via the shim's"
                    + " env at instantiation (see .wasm.imports.json)"
            );
        }
    } except Exception as e {
        console.warning(f"Could not write wasm import manifest: {e}");
    }
    return True;
}

impl ViteCompiler.create_entry_file(self: ViteCompiler, module_path: Path) -> None {
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    backend = resolve_active_backend();

    entry_file = self.compiled_dir / '_entry.js';
    if self._has_pages {
        entry_content = self._create_pages_entry_content(module_path);
    } else {
        entry_content = backend.build_entry_script(
            self._entry_module_name(module_path)
        );
    }
    entry_file.parent.mkdir(parents=True, exist_ok=True);

    try {
        if entry_file.exists()
            and entry_file.read_text(encoding='utf-8') == entry_content {
            return;
        }
    } except OSError {}
    entry_file.write_text(entry_content, encoding='utf-8');
}

impl ViteCompiler._create_pages_entry_content(
    self: ViteCompiler, module_path: Path
) -> str {
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    auth_redirect = "/login";
    try {
        import from jaclang.client.config_loader { JacClientConfig }
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

    entry_module = self._entry_module_name(module_path);
    has_app_wrapper = (self.compiled_dir / f"{entry_module}.js").exists();

    backend = resolve_active_backend();
    return backend.build_pages_entry_script(
        entry_module, auth_redirect, has_app_wrapper
    );
}

impl ViteCompiler._entry_module_name(self: ViteCompiler, module_path: Path) -> str {
    app_js = self.jac_client_compiler._output_path_for(module_path, self.project_dir);
    try {
        rel = app_js.relative_to(self.compiled_dir).as_posix();
    } except ValueError {
        rel = app_js.name;
    }
    return rel[:-3] if rel.endswith('.js') else rel;
}

impl ViteCompiler.compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]] {
    if not self.runtime_path {
        raise ClientBundleError('Runtime path not set');
    }
    import from jaclang.client.runtime_source { resolve_client_runtime_cl_path }
    import from jaclang.client.client_surface { prepend_active_runtime_globals }
    runtime_utils_path = Path(resolve_client_runtime_cl_path());
    runtime = self.jac_compiler.compile_module(runtime_utils_path);
    runtimeutils_js = runtime.js;
    runtimeutils_exports_list = self.jac_compiler.extract_exports(runtime.manifest);
    glob_names = list(runtime.manifest.globals);
    all_exports = sorted(
        set(
            runtimeutils_exports_list
                + self.jac_client_compiler.ROUTER_EXPORTS
                + glob_names
        )
    );
    self.compiled_dir.mkdir(parents=True, exist_ok=True);

    core_path = runtime_utils_path.parent / 'client_runtime_core.jac';
    if core_path.exists() {
        import re;
        core_match = re.search(
            r'from\s+[\'\"]([^\'\"]*client_runtime_core\.js)[\'\"]', runtimeutils_js
        );
        if core_match {
            core = self.jac_compiler.compile_module(core_path);
            core_js = prepend_active_runtime_globals(core.js);
            runtimeutils_js = runtimeutils_js.replace(
                core_match.group(1), './client_runtime_core.js'
            );
            core_out = self.compiled_dir / 'client_runtime_core.js';
            core_out.write_text(core_js, encoding='utf-8');
            self.jac_client_compiler._write_source_map(
                core, str(core_path), core_out, core_js
            );
        }
    }
    runtime_out = self.compiled_dir / 'client_runtime.js';
    runtime_out.write_text(runtimeutils_js, encoding='utf-8');
    self.jac_client_compiler._write_source_map(
        runtime, str(runtime_utils_path), runtime_out, runtimeutils_js
    );

    self.jac_client_compiler.compile_mobui_utils();
    return (runtimeutils_js, all_exports);
}

impl ViteCompiler.compile_desktop_sdk(self: ViteCompiler) {
    import from jaclang.compiler.driver.modresolver { resolve_jac_virtual_module_path }
    desktop_src = resolve_jac_virtual_module_path('@jac/desktop');
    if not desktop_src {
        return;
    }
    desktop_path = Path(desktop_src);
    if not desktop_path.exists() {
        return;
    }
    desktop = self.jac_compiler.compile_module(desktop_path);
    desktop_js = desktop.js;
    if not desktop_js.strip() {
        return;
    }

    desktop_exports = self.jac_compiler.extract_exports(desktop.manifest);
    desktop_globals = self.jac_compiler.extract_globals(desktop.manifest, None);
    all_names = sorted(set(desktop_exports + list(desktop_globals.keys())));

    if not all_names {
        import from jaclang.compiler.driver.modresolver {
            resolve_jac_virtual_module_exports
        }
        all_names = sorted(resolve_jac_virtual_module_exports('@jac/desktop'));
    }
    if all_names {
        export_line = 'export {' + ', '.join(all_names) + '};';
        desktop_js = desktop_js + '\n' + export_line + '\n';
    }
    desktop_out = self.compiled_dir / 'desktop_api.js';
    desktop_out.write_text(desktop_js, encoding='utf-8');
    self.jac_client_compiler._write_source_map(
        desktop, str(desktop_path), desktop_out, desktop_js
    );
}

impl ViteCompiler.init(
    self: ViteCompiler,
    vite_package_json: Path,
    vite_output_dir: (Path | None) = None,
    vite_minify: bool = False,
    runtime_path: (Path | None) = None,
    compile_to_js_func: Callable[[Path], ClientArtifact],
    extract_exports_func: Callable[[ClientManifest | None], list[str]],
    extract_globals_func:
        Callable[[ClientManifest | None, ModuleType | None], dict[str, any]]
) {
    if (not vite_package_json or not vite_package_json.exists()) {
        raise ClientBundleError(
            'Vite package.json not found. Set vite_package_json when using ViteCompiler'
        );
    }
    self.vite_package_json = vite_package_json;

    if (
        vite_package_json.parent.name == 'configs'
        and vite_package_json.parent.parent.name == 'client'
        and vite_package_json.parent.parent.parent.name == '.jac'
    ) {
        self.project_dir = vite_package_json.parent.parent.parent.parent;
    } elif (vite_package_json.parent.name == 'configs') {
        self.project_dir = vite_package_json.parent.parent;
    } else {
        self.project_dir = vite_package_json.parent;
    }
    self.runtime_path = runtime_path;
    self.jac_client_compiler = JacClientCompiler(
        project_dir=self.project_dir,
        runtime_path=runtime_path,
        compile_to_js_func=compile_to_js_func,
        extract_exports_func=extract_exports_func,
        extract_globals_func=extract_globals_func
    );
    compiled_dir = self.jac_client_compiler.compiled_dir;
    if compiled_dir is None {
        raise ClientBundleError('Client compiled directory could not be resolved');
    }
    self.compiled_dir = compiled_dir;
    self.jac_compiler = self.jac_client_compiler.jac_compiler;
    self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify);
    self._has_pages = False;
}
