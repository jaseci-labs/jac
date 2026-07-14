import from jaclang.project.config { get_config }

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

impl JacClient.render_page(
    introspector: ModuleIntrospector,
    function_name: str,
    args: dict[(str, Any)],
    username: str
) -> dict[str, any] {
    introspector.load();
    available_exports = (
        set(introspector._client_manifest.get('exports', []))
        or set(introspector.get_client_functions().keys())
    );
    if (function_name not in available_exports) {
        raise ValueError(f"Client function '{function_name}' not found");
    }
    import from jaclang.project.config { find_project_root, get_config }
    base_path_dir = Path(Jac.get_base_path_dir());
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        base_path = base_path_dir;
    }
    config = get_config();
    if config is not None {
        dist_dir = config.get_client_dir() / 'dist';
    } else {
        dist_dir = base_path / '.jac' / 'client' / 'dist';
    }
    is_pwa = (dist_dir / 'manifest.json').exists();
    if is_pwa {
        bundle_hash = introspector._bundle.hash if introspector._bundle else "pwa";
    } else {
        bundle_hash = introspector.ensure_bundle();
    }
    css_link = '';
    css_file = dist_dir / 'styles.css';
    if css_file.exists() {
        css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
        css_link = f'<link rel="stylesheet" href="/static/styles.css?hash={css_hash}"/>';
    }
    client_cfg = config.get_plugin_config("client") if config else None;
    meta_data = client_cfg.get("app_meta_data", {}) if client_cfg else {};
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
    if css_link {
        head_content += f"\n            {css_link}";
    }
    pwa_head = '';
    pwa_body = '';
    if is_pwa {
        pwa_cfg = client_cfg.get("pwa", {}) if client_cfg else {};
        pwa_theme_color = pwa_cfg.get("theme_color", "#000000");
        pwa_head = f'''
    <link rel="manifest" href="/static/manifest.json">
    <meta name="theme-color" content="{pwa_theme_color}">
    <link rel="apple-touch-icon" href="/static/pwa-192x192.png">''';
        pwa_body = '''
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
          navigator.serviceWorker.register('/static/sw.js')
            .then((reg) => console.log('SW registered:', reg.scope))
            .catch((err) => console.log('SW registration failed:', err));
        });
      }
    </script>''';
    }

    init_data = {
        'module': introspector._module.__name__
            if introspector._module
            else introspector.module_name,
        'function': function_name,
        'endpointEffects': introspector._client_manifest.get('endpoint_effects', {})
    };
    init_json = json.dumps(init_data).replace('</', '<\\/');
    init_script = f'<script id="__jac_init__" type="application/json">{init_json}</script>';
    prod_error_handler = '<script>(function(){function send(m,s){try{fetch("/cl/__error__",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:m,stack:s||"",url:window.location.href,source:"window.onerror",componentStack:"",timestamp:new Date().toISOString()})}).catch(function(){});}catch(e){}}window.addEventListener("error",function(e){if(window.__jacErrorHandlersInstalled)return;send(e.message||"",e.error?e.error.stack:"");});window.addEventListener("unhandledrejection",function(e){if(window.__jacErrorHandlersInstalled)return;var r=e.reason;send(r instanceof Error?r.message:String(r||""),r instanceof Error?r.stack:"");});}());</script>';
    page = f'<!DOCTYPE html><html lang="en"><head>{head_content}{pwa_head}</head><body><div id="root"></div>{init_script}{pwa_body}{prod_error_handler}<script type="module" src="/static/client.js?hash={bundle_hash}"></script></body></html>';
    return {
        'html': page,
        'bundle_hash': bundle_hash,
        'bundle_code': introspector._bundle.code if introspector._bundle else ""
    };
}

impl JacClient.get_client_js(introspector: ModuleIntrospector) -> str {
    import from jaclang.project.config { find_project_root, get_config }

    base_path_dir = Path(Jac.get_base_path_dir());
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        base_path = base_path_dir;
    }

    config = get_config();
    if config is not None {
        dist_dir = config.get_client_dir() / 'dist';
    } else {
        dist_dir = base_path / '.jac' / 'client' / 'dist';
    }

    is_pwa = dist_dir.exists() and (dist_dir / 'manifest.json').exists();
    if is_pwa {
        for client_js in dist_dir.glob('client.*.js') {
            return client_js.read_text(encoding='utf-8');
        }
    }

    introspector.load();
    introspector.ensure_bundle();
    return introspector._bundle.code;
}

impl HeaderBuilder.build_head -> str {
    lines: list = [];
    lines.extend(self._build_special_tags());
    lines.extend(self._build_meta_tags());
    lines.extend(self._build_og_tags());
    lines.extend(self._build_link_tags());
    lines.extend(self._build_generic_meta_tags());
    return "\n            ".join(lines);
}

impl HeaderBuilder._build_generic_meta_tags -> list[str] {
    lines: list = [];
    for (key, val) in self.meta_data.items() {
        if key.startswith("meta_") and val {
            name = key[5:].replace("_", "-");
            lines.append(f'<meta name={name} content={html.escape(str(val))} />');
        }
    }
    return lines;
}

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
            rel = key[5:].replace("_", "-");
            lines.append(f'<link rel={rel} href={html.escape(str(val))} />');
        }
    }
    return lines;
}

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

impl HeaderBuilder._build_meta_tags -> list[str] {
    lines: list = [];
    for key in self.standard_tags {
        if val := self._get_value(key) {
            name = key.replace("_", "-");
            lines.append(f'<meta name={name} content={html.escape(val)} />');
        }
    }
    return lines;
}

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

impl HeaderBuilder._get_value(key: str) -> str {
    return self.meta_data.get(key) or self.DEFAULTS.get(key);
}

impl JacClient.format_build_error(
    error_output: str, project_dir: Path, config: object = None
) -> str {
    import from jaclang.runtimelib.client.diagnostics { format_build_error }
    return format_build_error(
        error_output=error_output, project_dir=project_dir, config=config
    );
}
