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
    # Use ViteBundler to get the client directory
    bundler = ViteBundler(base_path);
    client_dir = bundler._get_client_dir();
    # package.json should only exist in .jac/client/configs/
    generated_package_json = client_dir / 'configs' / 'package.json';
    # Generate package.json if it doesn't exist
    if not generated_package_json.exists() {
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
    output_dir = client_dir / 'dist';
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
    import from jaclang.project.config { find_project_root, get_config }
    # Find project root by looking for jac.toml (base_path_dir might be src/ for entry files)
    base_path_dir = Path(Jac.base_path_dir);
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        # Fallback to base_path_dir if no project root found
        base_path = base_path_dir;
    }
    # Get client directory from config or use default
    config = get_config();
    if config is not None {
        dist_dir = config.get_client_dir() / 'dist';
    } else {
        dist_dir = base_path / '.jac' / 'client' / 'dist';
    }
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

"""Start the Vite dev server with HMR support."""
impl JacClient.start_dev_server(
    module_path: Path, host: str = 'localhost', port: int = 3000
) -> None {
    # Find project root
    project_dir = module_path.parent;
    if (project_dir / 'jac.toml').exists() {
        # Already at project root
        pass;
    } elif (project_dir.parent / 'jac.toml').exists() {
        # module_path is in src/
        project_dir = project_dir.parent;
    }
    # Create and start dev server
    dev_server = ViteDevServer(
        project_dir=project_dir,
        module_path=module_path,
        host=host,
        port=port,
        verbose=False
    );
    dev_server.start();
}

"""Hook called when the core dev server starts - starts Vite dev server for frontend HMR.
Returns True to indicate jac-client handles the frontend server."""
impl JacClient.on_dev_server_start(dev_server: Any) -> bool {
    import threading;

    # Get configuration from the core dev server
    # JacDevServer has: module_name, session_path, base_path, module_path, be_port, fe_port, fe_host, verbose
    project_dir = Path(dev_server.base_path) if hasattr(dev_server, 'base_path') else Path(Jac.base_path_dir);
    module_path = Path(dev_server.module_path) if hasattr(dev_server, 'module_path') and dev_server.module_path else None;
    fe_host = dev_server.fe_host if hasattr(dev_server, 'fe_host') else 'localhost';
    fe_port = dev_server.fe_port if hasattr(dev_server, 'fe_port') else 3000;
    be_port = dev_server.be_port if hasattr(dev_server, 'be_port') else 8000;
    verbose = dev_server.verbose if hasattr(dev_server, 'verbose') else False;

    if module_path is None {
        print("[jac-client] Warning: No module path provided, cannot start Vite dev server");
        return False;  # Let core handle FE
    }

    print(f"[jac-client] Initializing Vite dev server for {module_path.name}");

    # Create Vite dev server for frontend HMR
    vite_server = ViteDevServer(
        project_dir=project_dir,
        module_path=module_path,
        host=fe_host,
        port=fe_port,
        be_port=be_port,
        verbose=verbose
    );

    # Store reference on the dev server for cleanup
    dev_server._vite_server = vite_server;

    # Start Vite in a separate thread to not block the backend server
    # File watching is handled by core's file watcher + on_frontend_file_change hook
    def run_vite() -> None {
        try {
            vite_server.start();
        } except Exception as e {
            print(f"[jac-client] Vite server error: {e}");
        }
    }

    vite_thread = threading.Thread(target=run_vite, daemon=True);
    vite_thread.start();

    return True;  # jac-client handles frontend server
}

"""Hook called when a frontend file changes - triggers HMR recompilation."""
impl JacClient.on_frontend_file_change(file_path: Path, change_type: str) -> None {
    # Resolve file path to absolute
    file_path = file_path.resolve();
    
    # Find project root by looking for jac.toml
    project_dir = file_path.parent;
    search_dir = file_path.parent;
    while search_dir != search_dir.parent {
        if (search_dir / 'jac.toml').exists() {
            project_dir = search_dir;
            break;
        }
        search_dir = search_dir.parent;
    }

    # Get client directory
    client_dir = get_client_dir(project_dir);

    # Calculate source root - resolve to absolute path for proper comparison
    src_dir = (project_dir / 'src').resolve();
    source_root = src_dir if file_path.is_relative_to(src_dir) else project_dir.resolve();

    compiler = HMRCompiler(project_dir=project_dir, verbose=True);

    if change_type == 'deleted' {
        # Handle file deletion - remove compiled output
        output_path = calc_output_path(
            file_path.with_suffix('.js') if file_path.suffix == '.jac' else file_path,
            source_root,
            client_dir
        );
        if output_path.exists() {
            output_path.unlink();
            print(f"[HMR] Deleted: {output_path.name}");
        }
    } else {
        # Handle file modification/creation - recompile
        if file_path.suffix == '.jac' {
            (js_output, _) = compiler._compile_to_js(file_path);
            output_path = calc_output_path(file_path, source_root, client_dir, '.js');
            write_file(output_path, js_output);
            has_error = 'ErrorOverlay' in js_output;
            if has_error {
                print(f"[HMR] ❌ Error in {file_path.name} (see browser)");
            } else {
                print(f"[HMR] ✅ Recompiled: {file_path.name} -> {output_path}");
            }
            # Touch main.js to trigger Vite's file watcher and force browser reload
            main_js = client_dir / 'main.js';
            if main_js.exists() {
                main_js.touch();
            }
        } elif file_path.suffix in JS_EXTENSIONS {
            import shutil;
            try {
                output_path = calc_output_path(file_path, source_root, client_dir);
                output_path.parent.mkdir(parents=True, exist_ok=True);
                shutil.copy2(file_path, output_path);
                print(f"[HMR] ✅ Copied: {file_path.name}");
                # Touch main.js to trigger Vite reload
                main_js = client_dir / 'main.js';
                if main_js.exists() {
                    main_js.touch();
                }
            } except Exception as e {
                print(f"[HMR] ❌ Error copying {file_path.name}: {e}");
            }
        }
    }
}
