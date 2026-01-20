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
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
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

"""Build complete HTML head."""
impl HeaderBuilder.build_head -> str {
    lines: list = [];
    lines.extend(self._build_special_tags());  # charset, viewport, title
    lines.extend(self._build_meta_tags());  # description, robots, etc
    lines.extend(self._build_og_tags());  # Open Graph
    lines.extend(self._build_link_tags());  # canonical, icon, etc
    lines.extend(self._build_generic_meta_tags());  # custom meta_* tags
    return "\n            ".join(lines);
}

"""Build generic meta tags (meta_* prefix for any custom metadata)."""
impl HeaderBuilder._build_generic_meta_tags -> list[str] {
    lines: list = [];
    for (key, val) in self.meta_data.items() {
        if key.startswith("meta_") and val {
            # meta_custom_field → name="custom-field"
            name = key[5:].replace("_", "-");
            lines.append(f'<meta name={name} content={html.escape(str(val))} />');
        }
    }
    return lines;
}

"""Build link tags (link_* prefix or special cases)."""
impl HeaderBuilder._build_link_tags -> list[str] {
    lines: list = [];
    special_links = {
        "canonical": "canonical",
        "icon": "icon",
        "apple_touch_icon": "apple-touch-icon",
        "manifest": "manifest"
    };
    for (key, rel) in special_links.items() {
        if val := self._get_value(key) {
            lines.append(f'<link rel={rel} href={html.escape(str(val))} />');
        }
    }
    for (key, val) in self.meta_data.items() {
        if key.startswith("link_") and val {
            # link_preconnect_google → rel="preconnect"
            rel = key[5:].replace("_", "-");
            lines.append(f'<link rel={rel} href={html.escape(str(val))} />');
        }
    }
    return lines;
}

"""Build Open Graph tags (og_* prefix)."""
impl HeaderBuilder._build_og_tags -> list[str] {
    lines: list = [];
    for (key, val) in self.meta_data.items() {
        if key.startswith("og_") and val {
            property_name = key[3:].replace("_", ":");
            lines.append(
                f'<meta property=og:{property_name} content={html.escape(str(val))} />'
            );
        }
    }
    return lines;
}

"""Build standard meta tags (description, robots, keywords, author, etc)."""
impl HeaderBuilder._build_meta_tags -> list[str] {
    lines: list = [];
    for key in self.standard_tags {
        if val := self._get_value(key) {
            # Convert underscore to dash (theme_color → theme-color)
            name = key.replace("_", "-");
            lines.append(f'<meta name={name} content={html.escape(val)} />');
        }
    }
    return lines;
}

"""Build special tags (charset, viewport, title)."""
impl HeaderBuilder._build_special_tags -> list[str] {
    lines: list = [];
    if charset := self._get_value("charset") {
        lines.append(f'<meta charset={html.escape(charset)} />');
    }
    if viewport := self._get_value("viewport") {
        lines.append(f'<meta name="viewport" content={html.escape(viewport)} />');
    }
    title = self._get_value("title") or self.function_name;
    lines.append(f'<title>{html.escape(title)}</title>');
    return lines;
}

"""Get value with fallback to defaults."""
impl HeaderBuilder._get_value(key: str) -> str {
    return self.meta_data.get(key) or self.DEFAULTS.get(key);
}
