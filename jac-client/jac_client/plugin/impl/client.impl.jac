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
impl JacClient.render_page(
    introspector: ModuleIntrospector,
    function_name: str,
    args: dict[(str, Any)],
    username: str
) -> dict[str, Any] {
    introspector.load();
    available_exports = (
        set(introspector._client_manifest.get('exports', []))
        or set(introspector.get_client_functions().keys())
    );
    if (function_name not in available_exports) {
        raise ValueError(f"Client function '{function_name}' not found") ;
    }
    bundle_hash = introspector.ensure_bundle();
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
    css_file = dist_dir / 'styles.css';
    if css_file.exists() {
        css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
        css_link = f'<link rel="stylesheet" href="/static/styles.css?hash={css_hash}"/>';
    }
    # Get meta data from config
    client_cfg = config.get_plugin_config("client") if config else None;
    meta_data = client_cfg.get("app_meta_data", {}) if client_cfg else {};
    charset = meta_data.get("charset", "UTF-8");
    title = meta_data.get("title", function_name);
    viewport = meta_data.get("viewport", "width=device-width, initial-scale=1");
    description = meta_data.get("description", None);
    robots = meta_data.get("robots", "index, follow");
    canonical = meta_data.get("canonical", None);
    og_type = meta_data.get("og_type", "website");
    og_title = meta_data.get("og_title", title);
    og_description = meta_data.get("og_description", None);
    og_url = meta_data.get("og_url", None);
    og_image = meta_data.get("og_image", None);
    theme_color = meta_data.get("theme_color", "#ffffff");
    icon = meta_data.get("icon", None);
    # Build head content from TOML metadata
    head_content = f'<meta charset="{html.escape(charset)}"/>\n            <meta name="viewport" content="{html.escape(
        viewport
    )}"/>\n            <title>{html.escape(title)}</title>';
    head_content += f'\n            <meta name="robots" content="{html.escape(robots)}"/>';
    head_content += f'\n            <meta name="theme-color" content="{html.escape(
        theme_color
    )}"/>';
    head_content += f'\n            <meta property="og:type" content="{html.escape(
        og_type
    )}"/>';
    head_content += f'\n            <meta property="og:title" content="{html.escape(
        og_title
    )}"/>';
    if description {
        head_content += f'\n            <meta name="description" content="{html.escape(
            description
        )}"/>';
    }
    if canonical {
        head_content += f'\n            <link rel="canonical" href="{html.escape(
            canonical
        )}"/>';
    }
    if icon {
        head_content += f'\n            <link rel="icon" href="{html.escape(icon)}"/>';
    }
    if og_url {
        head_content += f'\n            <meta property="og:url" content="{html.escape(
            og_url
        )}"/>';
    }
    if og_image {
        head_content += f'\n            <meta property="og:image" content="{html.escape(
            og_image
        )}"/>';
    }
    if og_description {
        head_content += f'\n            <meta property="og:description" content="{html.escape(
            og_description
        )}"/>';
    }
    if css_link {
        head_content += f"\n            {css_link}";
    }
    page = f'<!DOCTYPE html><html lang="en"><head>{head_content}</head><body><div id="root"></div><script src="/static/client.js?hash={bundle_hash}" defer></script></body></html>';
    return {
        'html': page,
        'bundle_hash': bundle_hash,
        'bundle_code': introspector._bundle.code
    };
}
