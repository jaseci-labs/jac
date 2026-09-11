import from jaclang.cli.console { console }

impl make_client_bundle_builder(
    base_path: (Path | None) = None
) -> ViteClientBundleBuilder {
    import from jaclang.client.vite_bundler { ViteBundler }
    if base_path is None {
        import from jaclang.runtime.runtime { JacRuntime as Jac }
        import from jaclang.project.config { find_project_root }
        base_path_str = Jac.get_base_path_dir();
        base_path_dir = Path(base_path_str) if base_path_str else Path.cwd();
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
        vite_output_dir=bundler._client_app_dir() / 'dist',
        vite_minify=False
    );
}

impl ViteClientBundleBuilder._emitted_digest(self: ViteClientBundleBuilder) -> str {
    import from jaclang.client.client_bundle { emitted_tree_digest }
    if not self.vite_package_json {
        return '';
    }
    return emitted_tree_digest(self.vite_package_json.parent / 'compiled');
}

impl ViteClientBundleBuilder.prepare(
    self: ViteClientBundleBuilder, module: ModuleType
) -> ClientBuildInputs {
    if not module.__file__ {
        raise ClientBundleError(
            f"Module '{module.__name__}' has no __file__ attribute"
        );
    }
    return self._get_compiler().prepare_bundle(module, Path(module.__file__).resolve());
}

impl ViteClientBundleBuilder.bundle(
    self: ViteClientBundleBuilder, inputs: ClientBuildInputs
) -> ClientBundle {
    return self._get_compiler().bundle(inputs);
}

impl ViteClientBundleBuilder._compile_bundle(
    self: ViteClientBundleBuilder, module: ModuleType, module_path: Path
) -> ClientBundle {
    compiler = self._get_compiler();
    return compiler.bundle(compiler.prepare_bundle(module, module_path));
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
        compile_to_js_func: Callable[[Path], ClientArtifact] = cast(
            Callable[[Path], ClientArtifact], self._compile_to_js
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
    self._compiler = None;
}
