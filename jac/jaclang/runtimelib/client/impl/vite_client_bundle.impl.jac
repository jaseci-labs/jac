import from jaclang.cli.console { console }

impl make_client_bundle_builder(
    base_path: (Path | None) = None
) -> ViteClientBundleBuilder {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    if base_path is None {
        import from jaclang.runtimelib.runtime { JacRuntime as Jac }
        import from jaclang.project.config { find_project_root }
        base_path_dir = Path(Jac.get_base_path_dir());
        project_root_result = find_project_root(base_path_dir);
        if project_root_result {
            (base_path, _) = project_root_result;
        } else {
            base_path = base_path_dir;
        }
    }
    bundler = ViteBundler(base_path);
    client_dir = bundler._get_client_dir();
    generated_package_json = client_dir / 'configs' / 'package.json';
    if not generated_package_json.exists() {
        generated_path = bundler.create_package_json();
        if not generated_path.exists() {
            raise ClientBundleError(
                f'Failed to generate package.json at {generated_path}'
            );
        }
        package_json_path = generated_path.resolve();
    } else {
        package_json_path = generated_package_json.resolve();
    }
    return ViteClientBundleBuilder(
        vite_package_json=package_json_path,
        vite_output_dir=client_dir / 'dist',
        vite_minify=False
    );
}

impl ViteClientBundleBuilder._compile_bundle(
    self: ViteClientBundleBuilder, module: ModuleType, module_path: Path
) -> ClientBundle {
    compiler = self._get_compiler();
    (bundle_code, bundle_hash, client_exports, client_globals) = compiler.compile_and_bundle(
        module, module_path
    );
    return ClientBundle(
        module_name=module.__name__,
        code=bundle_code,
        client_functions=client_exports,
        client_globals=client_globals,
        hash=bundle_hash
    );
}

impl ViteClientBundleBuilder._get_compiler(
    self: ViteClientBundleBuilder
) -> ViteCompiler {
    if (self._compiler is None) {
        if (not self.vite_package_json or not self.vite_package_json.exists()) {
            raise ClientBundleError(
                'Vite package.json not found. Set vite_package_json when using ViteClientBundleBuilder'
            );
        }
        compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])] = cast(
            Callable[([Path], tuple[(str, (ModuleType | None))])], self._compile_to_js
        );
        self._compiler = ViteCompiler(
            vite_package_json=self.vite_package_json,
            vite_output_dir=self.vite_output_dir,
            vite_minify=self.vite_minify,
            runtime_path=self.runtime_path,
            compile_to_js_func=compile_to_js_func,
            extract_exports_func=self._extract_client_exports,
            extract_globals_func=self._extract_client_globals
        );
    }
    return self._compiler;
}

impl ViteClientBundleBuilder.init(
    self: ViteClientBundleBuilder,
    runtime_path: (Path | None) = None,
    vite_output_dir: (Path | None) = None,
    vite_package_json: (Path | None) = None,
    vite_minify: bool = False
) -> None {
    super.init(runtime_path);
    self.vite_output_dir = vite_output_dir;
    self.vite_package_json = vite_package_json;
    self.vite_minify = vite_minify;
    self._compiler: (ViteCompiler | None) = None;
}
