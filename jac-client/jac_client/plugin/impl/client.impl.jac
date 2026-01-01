import from jaclang.project.config { get_config }

"""Send static file response (images, fonts, etc.)."""
impl JacClient.send_static_file(
    handler: BaseHTTPRequestHandler, file_path: Path, content_type: (str | None) = None
) -> None {
    import from jaclang.runtimelib.server { ResponseBuilder }
    if (not file_path.exists() or not file_path.is_file()) {
        ResponseBuilder.send_json(handler, 404, {'error': 'File not found'});
        return;
    }
    try {
        file_content = file_path.read_bytes();
        if (content_type is None) {
            (content_type, _) = mimetypes.guess_type(str(file_path));
            if (content_type is None) {
                content_type = 'application/octet-stream';
            }
        }
        handler.send_response(200);
        handler.send_header('Content-Type', content_type);
        handler.send_header('Content-Length', str(len(file_content)));
        handler.send_header('Cache-Control', 'public, max-age=3600');
        ResponseBuilder._add_cors_headers(handler);
        ResponseBuilder._add_custom_headers(handler);
        handler.end_headers();
        handler.wfile.write(file_content);
    } except Exception as exc {
        ResponseBuilder.send_json(handler, 500, {'error': str(exc)});
    }
}

"""Get a module introspector for the supplied module."""
impl JacClient.get_module_introspector(
    module_name: str, base_path: (str | None)
) -> ModuleIntrospector {
    return JacClientModuleIntrospector(module_name, base_path);
}

"""Build a client bundle for the supplied module."""
impl JacClient.build_client_bundle(
    module: types.ModuleType, force: bool = False
) -> ClientBundle {
    builder = JacClient.get_client_bundle_builder();
    return builder.build(module, force=force);
}

"""Get the client bundle builder instance."""
impl JacClient.get_client_bundle_builder -> ViteClientBundleBuilder {
    import from jaclang.project.config { find_project_root }
    # Find project root by looking for jac.toml (base_path_dir might be src/ for entry files)
    base_path_dir = Path(Jac.base_path_dir);
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        # Fallback to base_path_dir if no project root found
        base_path = base_path_dir;
    }
    # package.json should only exist in .client-build/.jac-client.configs/
    generated_package_json = base_path / '.client-build' / '.jac-client.configs' / 'package.json';
    # Generate package.json if it doesn't exist
    if not generated_package_json.exists() {
        # Use ViteBundler to generate package.json from config.json
        bundler = ViteBundler(base_path);
        generated_path = bundler.create_package_json();
        # Verify the file was created and resolve to absolute path
        if not generated_path.exists() {
            raise ClientBundleError(
                f'Failed to generate package.json at {generated_path}'
            ) ;
        }
        package_json_path = generated_path.resolve();
    } else {
        package_json_path = generated_package_json.resolve();
    }
    # Final verification that package.json exists before creating builder
    if not package_json_path.exists() {
        raise ClientBundleError(
            f'package.json not found at {package_json_path}. Expected at {generated_package_json}'
        ) ;
    }
    output_dir = base_path / '.client-build' / 'dist';
    runtime_path = Path(__file__).with_name('client_runtime.cl.jac');
    return ViteClientBundleBuilder(
        runtime_path=runtime_path,
        vite_package_json=package_json_path,
        vite_output_dir=output_dir,
        vite_minify=False
    );
}

"""Render HTML page for client function using the Vite bundle."""
impl JacClientModuleIntrospector.render_page(
    self: JacClientModuleIntrospector,
    function_name: str,
    args: dict[(str, Any)],
    username: str
) -> dict[str, Any] {
    self.load();
    available_exports = (
        set(self._client_manifest.get('exports', []))
        or set(self.get_client_functions().keys())
    );
    if (function_name not in available_exports) {
        raise ValueError(f"Client function '{function_name}' not found") ;
    }
    bundle_hash = self.ensure_bundle();
    import from jaclang.project.config { find_project_root }
    # Find project root by looking for jac.toml (base_path_dir might be src/ for entry files)
    base_path_dir = Path(Jac.base_path_dir);
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        # Fallback to base_path_dir if no project root found
        base_path = base_path_dir;
    }
    dist_dir = base_path / '.client-build' / 'dist';
    css_link = '';
    css_file = dist_dir / 'main.css';
    if css_file.exists() {
        css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
        css_link = f'<link rel="stylesheet" href="/static/main.css?hash={css_hash}"/>';
    }
    head_content = f'<meta charset="utf-8"/>\n            <title>{html.escape(
        function_name
    )}</title>';
    if css_link {
        head_content += f"\n            {css_link}";
    }
    page = f'<!DOCTYPE html><html lang="en"><head>{head_content}</head><body><div id="root"></div><script src="/static/client.js?hash={bundle_hash}" defer></script></body></html>';
    return {'html': page, 'bundle_hash': bundle_hash, 'bundle_code': self._bundle.code};
}
