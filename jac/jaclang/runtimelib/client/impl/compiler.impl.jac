import from jaclang.cli.console { console }

impl ViteCompiler.compile(
    self: ViteCompiler, module: ModuleType, module_path: Path
) -> tuple[list[str], list[str]] {
    (client_exports, client_globals) = self.jac_client_compiler.compile(
        module, module_path, target_name="web"
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

impl ViteCompiler._emit_na_wasm(self: ViteCompiler, module_path: Path) -> None {
    import from jaclang.jac0core.ext_registry { is_native_module }
    import from jaclang.jac0core.constant { CodeContext }
    import from jaclang { JacRuntime as Jac }
    has_na = is_native_module(module_path.name);
    if not has_na {
        compiled = Jac.program.mod.hub.get(str(module_path.resolve()));
        if compiled is None {
            console.warning(
                f"'{module_path.name}' not found in the compile hub; cannot " + "check for inferred-native code, so no wasm will be emitted " + "for it (explicit .na.jac modules are unaffected)."
            );
            return;
        }
        has_na = compiled.declares_codespace(CodeContext.NATIVE);
    }
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
    dist = self.jac_client_compiler._get_client_dir() / 'dist';
    dist.mkdir(parents=True, exist_ok=True);
    out_path = dist / f"{module_path.stem}.wasm";
    out_path.write_bytes(wasm);
    console.print(
        f"  Native wasm module: /static/{module_path.stem}.wasm ({len(wasm)} bytes)"
    );

    try {
        import json;
        import from jaclang.compiler.passes.native.wasm_build { wasm_import_map }
        import from jaclang.compiler.passes.native.wasm_host_abi { WASM_HOST_MODULE }
        imports = wasm_import_map(wasm);
        manifest_path = dist / f"{module_path.stem}.wasm.imports.json";
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
                f"    app FFI imports ({len(app_ffi)}): provide via the shim's" + " env at instantiation (see .wasm.imports.json)"
            );
        }
    } except Exception as e {
        console.warning(f"Could not write wasm import manifest: {e}");
    }
}

impl ViteCompiler.create_entry_file(self: ViteCompiler, module_path: Path) -> None {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    backend = resolve_active_backend();

    entry_file = self.compiled_dir / '_entry.js';
    if self._has_pages {
        entry_content = self._create_pages_entry_content(module_path);
    } else {
        entry_content = backend.build_entry_script(module_path.stem);
    }
    entry_file.parent.mkdir(parents=True, exist_ok=True);

    try {
        if entry_file.exists()
        and entry_file.read_text(encoding='utf-8') == entry_content {
            return;
        }
    } except OSError { }
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

    app_module = self.compiled_dir / f"{module_path.stem}.js";
    has_app_wrapper = app_module.exists();

    backend = resolve_active_backend();
    return backend.build_pages_entry_script(
        module_path.stem, auth_redirect, has_app_wrapper
    );
}

impl ViteCompiler.compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]] {
    if not self.runtime_path {
        raise ClientBundleError('Runtime path not set');
    }
    import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
    import from jaclang.runtimelib.client_surface { prepend_active_runtime_globals }
    runtime_utils_path = Path(resolve_client_runtime_cl_path());
    (runtimeutils_js, mod, runtimeutils_manifest) = self.jac_compiler.compile_module(
        runtime_utils_path
    );
    runtimeutils_exports_list = self.jac_compiler.extract_exports(
        runtimeutils_manifest
    );
    glob_names = list(runtimeutils_manifest.globals) if runtimeutils_manifest else [];
    all_exports = sorted(
        set(
            runtimeutils_exports_list + self.jac_client_compiler.ROUTER_EXPORTS + glob_names
        )
    );
    self.compiled_dir.mkdir(parents=True, exist_ok=True);

    core_path = runtime_utils_path.parent / 'client_runtime_core.cl.jac';
    if core_path.exists() {
        core_specifier = './jaclang/runtimelib/client_runtime_core.js';
        if core_specifier in runtimeutils_js {
            (core_js, core_mod, _) = self.jac_compiler.compile_module(core_path);
            core_js = prepend_active_runtime_globals(core_js);
            runtimeutils_js = runtimeutils_js.replace(
                core_specifier, './client_runtime_core.js'
            );
            core_out = self.compiled_dir / 'client_runtime_core.js';
            core_out.write_text(core_js, encoding='utf-8');
            self.jac_client_compiler._write_source_map(
                core_mod, str(core_path), core_out, core_js
            );
        }
    }
    runtime_out = self.compiled_dir / 'client_runtime.js';
    runtime_out.write_text(runtimeutils_js, encoding='utf-8');
    self.jac_client_compiler._write_source_map(
        mod, str(runtime_utils_path), runtime_out, runtimeutils_js
    );

    self.jac_client_compiler.compile_mobui_utils();
    return (runtimeutils_js, all_exports);
}

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

    desktop_exports = self.jac_compiler.extract_exports(desktop_manifest);
    desktop_globals = self.jac_compiler.extract_globals(desktop_manifest, mod);
    all_names = sorted(set(desktop_exports + list(desktop_globals.keys())));

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
    self.jac_client_compiler._write_source_map(
        mod, str(desktop_path), desktop_out, desktop_js
    );
}

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
    self.compiled_dir = self.jac_client_compiler.compiled_dir;
    self.jac_compiler = JacToJSCompiler(
        compile_to_js_func, extract_exports_func, extract_globals_func
    );
    self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify);
    self._has_pages = False;
}
