"""Static files, pages, client JS, graph visualization implementations."""
import mimetypes;
import from collections.abc { Callable }
import from pathlib { Path }
import from typing { Any }
import from fastapi.responses { HTMLResponse, JSONResponse, Response }
import from jac_scale.jserver.jserver {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.server { JsonValue }
import from jaclang.cli.console { console }

# ============================================================================
# Static File Serving
# ============================================================================
"""Serve a static file given its path."""
impl JacAPIServerStatic.serve_static_file(file_path: str) -> Response {
    try {
        # Find project root (where jac.toml is) instead of using base_path_dir
        # base_path_dir might be src/ when serving src/app.jac, but we need project root
        import from jaclang.project.config { find_project_root }
        base_path_dir = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd();
        project_root_result = find_project_root(base_path_dir);
        if project_root_result {
            (base_path, _) = project_root_result;
        } else {
            # Fallback to base_path_dir if no project root found
            base_path = base_path_dir;
        }
        file_name = Path(file_path).name;
        # Check multiple locations for files
        # 1. .jac/client/dist/ (Jac-client build output)
        client_build_dist_file = base_path / '.jac' / 'client' / 'dist' / file_path;
        client_build_dist_file_simple = base_path / '.jac' / 'client' / 'dist' / file_name;
        # 2. dist/ (jac core build output)
        dist_file = base_path / 'dist' / file_path;
        dist_file_simple = base_path / 'dist' / file_name;
        # 3. assets/ (static assets)
        assets_file = base_path / 'assets' / file_path;
        assets_file_simple = base_path / 'assets' / file_name;
        if file_name.endswith('.css') {
            # Check .jac/client/dist/ first (jac-client)
            if client_build_dist_file.exists() {
                css_content = client_build_dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif client_build_dist_file_simple.exists() {
                css_content = client_build_dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file.exists() {
                css_content = dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file_simple.exists() {
                css_content = dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file.exists() {
                css_content = assets_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file_simple.exists() {
                css_content = assets_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } else {
                return Response(
                    status_code=404,
                    content='CSS file not found',
                    media_type='text/plain'
                );
            }
        }
        for candidate_file in [
            client_build_dist_file,
            client_build_dist_file_simple,
            dist_file,
            dist_file_simple,
            assets_file,
            assets_file_simple
        ] {
            if (candidate_file.exists() and candidate_file.is_file()) {
                file_content = candidate_file.read_bytes();
                (content_type, _) = mimetypes.guess_type(str(candidate_file));
                if (content_type is None) {
                    content_type = 'application/octet-stream';
                }
                return Response(content=file_content, media_type=content_type);
            }
        }
        return Response(
            status_code=404, content='Static file not found', media_type='text/plain'
        );
    } except Exception as exc {
        return Response(status_code=500);
    }
}

"""Register the static file serving endpoint using JEndPoint."""
impl JacAPIServerStatic.register_static_file_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/{file_path:path}',
            callback=self.serve_static_file,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Path of the static file to serve',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve static files',
            description='Endpoint to serve static files from the server.'
        )
    );
}

"""Register the client.js serving endpoint using JEndPoint."""
impl JacAPIServerStatic.register_client_js_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/client.js',
            callback=self.serve_client_js_callback(),
            parameters=[],
            response_model=None,
            tags=['Static Files'],
            summary='Serve client.js',
            description='Endpoint to serve the client-side JavaScript file.'
        )
    );
}

"""Create callback to serve the client.js file."""
impl JacAPIServerStatic.serve_client_js_callback -> Callable[..., Response] {
    def callback -> Response {
        try {
            return Response(
                content=Jac.get_client_js(self.introspector),
                media_type='application/javascript'
            );
        } except RuntimeError as exc {
            return Response(content=str(exc), status_code=503, media_type='text/plain');
        }
    }
    return callback;
}

# ============================================================================
# Page Rendering
# ============================================================================
"""Register the page rendering endpoint using JEndPoint."""
impl JacAPIServerStatic.register_page_endpoint -> None {
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    base_route_app = config.serve.base_route_app if config else "";
    # Register the configurable cl route (e.g., /cl/{page_name})
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path=f'/{cl_route_prefix}/{{page_name}}',
            callback=self.render_page_callback(),
            parameters=[
                APIParameter(
                    name='page_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the page to render',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Pages'],
            summary='Render a page',
            description=f'Endpoint to render and retrieve a specific page by name at /{cl_route_prefix}/{{name}}.'
        )
    );
    # If base_route_app is configured, register it at /
    if base_route_app {
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/',
                callback=self.render_base_route_callback(base_route_app),
                parameters=[],
                response_model=None,
                tags=['Pages'],
                summary='Base route app',
                description=f'Serves the {base_route_app} client app at the root path.'
            )
        );
    }
}

"""Create callback that extracts all query parameters from FastAPI Request."""
impl JacAPIServerStatic.render_page_callback -> Callable[..., HTMLResponse] {
    """Render a page by name with all query parameters.""";
    def callback(page_name: str, **kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                page_name, kwargs, '__guest__'
            );
            return HTMLResponse(content=render_payload['html']);
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            console.print(f"Error rendering page '{page_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

"""Create callback for base route app rendering."""
impl JacAPIServerStatic.render_base_route_callback(
    app_name: str
) -> Callable[..., HTMLResponse] {
    """Render the base route app.""";
    def callback(**kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                app_name, kwargs, '__guest__'
            );
            return HTMLResponse(content=render_payload['html']);
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            console.print(f"Error rendering base route app '{app_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

# ============================================================================
# Root Asset Serving
# ============================================================================
"""Serve root-level assets like /img.png, /icons/logo.svg, etc.
Falls back to SPA HTML for extensionless paths when base_route_app is configured."""
impl JacAPIServerStatic.serve_root_asset(file_path: str) -> Response {
    allowed_extensions = {'.png','.jpg','.jpeg','.gif','.webp','.svg','.ico','.woff','.woff2','.ttf','.otf','.eot','.mp4','.webm','.mp3','.wav','.css','.js','.json','.pdf','.txt','.xml'};
    file_ext = Path(file_path).suffix.lower();
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    api_prefixes = (f'{cl_route_prefix}/', 'walker/', 'function/', 'user/', 'static/');
    if (not file_ext or (file_ext not in allowed_extensions)) {
        # SPA catch-all: serve base_route_app for extensionless paths
        base_route_app = config.serve.base_route_app if config else "";
        if (not file_ext and base_route_app and not file_path.startswith(api_prefixes)) {
            try {
                render_payload = self.introspector.render_page(
                    base_route_app, {}, '__guest__'
                );
                return HTMLResponse(content=render_payload['html']);
            } except ValueError {
                return HTMLResponse(content="<h1>404 Not Found</h1>", status_code=404);
            } except RuntimeError {
                return HTMLResponse(
                    content="<h1>503 Service Unavailable</h1>", status_code=503
                );
            }
        }
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    if file_path.startswith(api_prefixes) {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    # Find project root (where jac.toml is) instead of using base_path_dir
    # base_path_dir might be src/ when serving src/app.jac, but we need project root
    import from jaclang.project.config { find_project_root }
    base_path_dir = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd();
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        # Fallback to base_path_dir if no project root found
        base_path = base_path_dir;
    }
    file_name = Path(file_path).name;
    candidates = [
        base_path / 'dist' / file_path,
        base_path / 'dist' / file_name,
        base_path / 'assets' / file_path,
        base_path / 'assets' / file_name,
        base_path / 'public' / file_path,
        base_path / 'src' / file_path,
        base_path / 'src' / file_name,
        (base_path / file_path)
    ];
    for candidate_file in candidates {
        if (candidate_file.exists() and candidate_file.is_file()) {
            file_content = candidate_file.read_bytes();
            (content_type, _) = mimetypes.guess_type(str(candidate_file));
            if (content_type is None) {
                content_type = 'application/octet-stream';
            }
            headers = {'Cache-Control': 'public, max-age=31536000'};
            return Response(
                content=file_content, media_type=content_type, headers=headers
            );
        }
    }
    return Response(
        status_code=404,
        content=f"Asset not found: {file_path}",
        media_type='text/plain'
    );
}

"""Register root-level asset serving endpoint for files like /img.png, /logo.svg"""
impl JacAPIServerStatic.register_root_asset_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/{file_path:path}',
            callback=self.serve_root_asset,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Path to asset file (e.g., img.png, icons/logo.svg)',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve root-level assets',
            description='Endpoint to serve assets from root path with common extensions (.png, .jpg, .svg, etc.)'
        )
    );
}

# ============================================================================
# Graph Visualization
# ============================================================================
"""Register the /graph visualization endpoint and /graph/data API endpoint."""
impl JacAPIServerStatic.register_graph_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph',
            callback=self.serve_graph_page,
            parameters=[],
            response_model=None,
            tags=['Graph Visualization'],
            summary='Graph Visualizer',
            description='Interactive graph visualization UI for exploring the backend graph'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph/data',
            callback=self.graph_data,
            parameters=[
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=False,
                    default=None,
                    description='Bearer JWT token (optional - falls back to public/guest graph if not provided)',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Graph Visualization'],
            summary='Graph Data',
            description='Returns graph data (nodes and edges) as JSON. With auth: returns user graph. Without auth: returns public graph (super root).'
        )
    );
}

"""Serve the graph visualization HTML page."""
impl JacAPIServerStatic.serve_graph_page -> HTMLResponse {
    html_content = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Jac Graph Visualizer</title>
    <script src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, \'Helvetica Neue\', sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            height: 100vh;
            overflow: hidden;
        }
        .header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 20px;
            background: #1e293b;
            border-bottom: 1px solid #334155;
            z-index: 100;
        }
        .header-left { display: flex; align-items: center; gap: 12px; }
        .logo {
            font-size: 16px;
            font-weight: 700;
            color: #f8fafc;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .logo svg { color: #f59e0b; }
        .mode-badge {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            padding: 3px 10px;
            border-radius: 4px;
        }
        .mode-badge.public { background: #1e3a5f; color: #38bdf8; border: 1px solid #0ea5e9; }
        .mode-badge.user { background: #14532d; color: #4ade80; border: 1px solid #22c55e; }
        .stats {
            font-size: 12px;
            color: #94a3b8;
            padding: 3px 10px;
            background: #0f172a;
            border-radius: 4px;
        }
        .header-right { display: flex; align-items: center; gap: 6px; }
        .btn {
            padding: 5px 12px;
            border-radius: 5px;
            border: 1px solid #334155;
            background: #1e293b;
            color: #e2e8f0;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.15s;
            display: flex;
            align-items: center;
            gap: 5px;
        }
        .btn:hover { background: #334155; border-color: #475569; }
        .btn-logout { border-color: #ef4444; color: #ef4444; }
        .btn-logout:hover { background: #ef4444; color: #fff; }
        #graph-container {
            width: 100%;
            height: calc(100vh - 49px);
            background: #0f172a;
        }
        .tooltip {
            position: absolute;
            z-index: 50;
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 8px;
            padding: 12px;
            max-width: 320px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.4);
            pointer-events: none;
            display: none;
            font-size: 13px;
        }
        .tooltip-title { font-weight: 600; color: #f8fafc; margin-bottom: 4px; }
        .tooltip-label { color: #94a3b8; font-family: monospace; font-size: 12px; word-break: break-all; }
        .tooltip-id { color: #64748b; font-size: 11px; margin-top: 6px; padding-top: 6px; border-top: 1px solid #334155; }
        .loading {
            display: flex; flex-direction: column; align-items: center;
            justify-content: center; height: 100%; color: #94a3b8; gap: 12px;
        }
        .spinner {
            width: 32px; height: 32px; border: 3px solid #334155;
            border-top-color: #3b82f6; border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .empty-state {
            display: flex; flex-direction: column; align-items: center;
            justify-content: center; height: 100%; color: #64748b; gap: 8px;
        }
        .legend {
            position: absolute; bottom: 16px; left: 16px;
            background: #1e293b; border: 1px solid #334155;
            border-radius: 8px; padding: 12px; font-size: 12px; z-index: 10;
        }
        .legend-title { color: #94a3b8; margin-bottom: 8px; font-weight: 600; }
        .legend-item { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
        .legend-color { width: 12px; height: 12px; border-radius: 50%; border: 2px solid rgba(255,255,255,0.2); }

        /* Login modal overlay */
        .login-overlay {
            display: none;
            position: fixed; top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.6);
            align-items: center; justify-content: center;
            z-index: 300;
        }
        .login-overlay.open { display: flex; }
        .login-card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 12px;
            padding: 32px;
            width: 360px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.4);
            position: relative;
        }
        .login-card .logo { justify-content: center; font-size: 20px; margin-bottom: 24px; }
        .login-card label { display: block; font-size: 13px; color: #94a3b8; margin-bottom: 6px; }
        .login-card input {
            width: 100%; padding: 10px 12px; border-radius: 6px;
            border: 1px solid #334155; background: #0f172a;
            color: #e2e8f0; font-size: 14px; outline: none;
            margin-bottom: 16px;
        }
        .login-card input:focus { border-color: #3b82f6; }
        .login-card .login-btn {
            width: 100%; padding: 10px; border-radius: 6px; border: none;
            background: #3b82f6; color: #fff; font-size: 14px;
            font-weight: 600; cursor: pointer; transition: background 0.15s;
        }
        .login-card .login-btn:hover { background: #2563eb; }
        .login-card .login-btn:disabled { background: #334155; cursor: not-allowed; }
        .login-close {
            position: absolute; top: 12px; right: 12px; background: none;
            border: none; color: #64748b; cursor: pointer; font-size: 18px;
        }
        .login-close:hover { color: #e2e8f0; }
        .login-error {
            color: #ef4444; font-size: 13px; margin-bottom: 12px;
            display: none; text-align: center;
        }
        .btn-login { background: #3b82f6; color: #fff; border-color: #3b82f6; }
        .btn-login:hover { background: #2563eb; border-color: #2563eb; }
    </style>
</head>
<body>
    <!-- Login modal -->
    <div class="login-overlay" id="login-overlay">
        <div class="login-card">
            <button class="login-close" onclick="closeLogin()">&times;</button>
            <div class="logo">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="3"/><line x1="12" y1="8" x2="12" y2="16"/><circle cx="6" cy="19" r="3"/><circle cx="18" cy="19" r="3"/><line x1="12" y1="16" x2="6" y2="16.5"/><line x1="12" y1="16" x2="18" y2="16.5"/></svg>
                Jac Graph
            </div>
            <div class="login-error" id="login-error"></div>
            <label>Username</label>
            <input type="text" id="login-username" placeholder="Enter username" />
            <label>Password</label>
            <input type="password" id="login-password" placeholder="Enter password" />
            <button class="login-btn" id="login-btn" onclick="doLogin()">Sign In</button>
        </div>
    </div>

    <!-- Graph page (always visible) -->
    <div class="header">
        <div class="header-left">
            <div class="logo">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="3"/><line x1="12" y1="8" x2="12" y2="16"/><circle cx="6" cy="19" r="3"/><circle cx="18" cy="19" r="3"/><line x1="12" y1="16" x2="6" y2="16.5"/><line x1="12" y1="16" x2="18" y2="16.5"/></svg>
                Jac Graph
            </div>
            <div class="mode-badge" id="mode-badge">Loading</div>
            <div class="stats" id="stats"></div>
        </div>
        <div class="header-right">
            <button class="btn" onclick="refreshGraph()" title="Refresh">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2v6h-6"/><path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 22v-6h6"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/></svg>
                Refresh
            </button>
            <button class="btn" onclick="fitGraph()">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 3h6v6"/><path d="M9 21H3v-6"/><path d="M21 3l-7 7"/><path d="M3 21l7-7"/></svg>
                Fit
            </button>
            <button class="btn" onclick="togglePhysics()" id="physics-btn">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 1v4m0 14v4M4.22 4.22l2.83 2.83m9.9 9.9l2.83 2.83M1 12h4m14 0h4M4.22 19.78l2.83-2.83m9.9-9.9l2.83-2.83"/></svg>
                Physics
            </button>
            <button class="btn btn-login" id="auth-btn" onclick="openLogin()" style="display:none">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                Login
            </button>
            <button class="btn btn-logout" id="logout-btn" onclick="doLogout()" style="display:none">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                Logout
            </button>
        </div>
    </div>
    <div id="graph-container"></div>
    <div class="tooltip" id="tooltip"></div>

    <script>
        let network = null;
        let graphData = null;
        let physicsEnabled = true;
        let authToken = localStorage.getItem('jac_token') || null;
        const baseUrl = window.location.origin;

        // Load graph immediately and update header buttons
        updateHeaderButtons();
        loadGraphData();

        // Enter key submits login
        document.getElementById('login-password').addEventListener('keydown', function(e) {
            if (e.key === 'Enter') doLogin();
        });

        function updateHeaderButtons() {
            document.getElementById('auth-btn').style.display = authToken ? 'none' : 'flex';
            document.getElementById('logout-btn').style.display = authToken ? 'flex' : 'none';
            const badge = document.getElementById('mode-badge');
            badge.textContent = authToken ? 'User Graph' : 'Public Graph';
            badge.className = 'mode-badge ' + (authToken ? 'user' : 'public');
        }

        function openLogin() {
            document.getElementById('login-error').style.display = 'none';
            document.getElementById('login-username').value = '';
            document.getElementById('login-password').value = '';
            document.getElementById('login-overlay').classList.add('open');
        }

        function closeLogin() {
            document.getElementById('login-overlay').classList.remove('open');
        }

        async function doLogin() {
            const username = document.getElementById('login-username').value.trim();
            const password = document.getElementById('login-password').value;
            const errEl = document.getElementById('login-error');
            const btn = document.getElementById('login-btn');
            errEl.style.display = 'none';
            if (!username || !password) {
                errEl.textContent = 'Username and password required';
                errEl.style.display = 'block';
                return;
            }
            btn.disabled = true;
            btn.textContent = 'Signing in...';
            try {
                const resp = await fetch(baseUrl + '/user/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, password })
                });
                const result = await resp.json();
                if (result.ok && result.data && result.data.token) {
                    authToken = result.data.token;
                    localStorage.setItem('jac_token', authToken);
                    closeLogin();
                    updateHeaderButtons();
                    loadGraphData();
                } else {
                    errEl.textContent = (result.error && result.error.message) || 'Invalid credentials';
                    errEl.style.display = 'block';
                }
            } catch (err) {
                errEl.textContent = 'Connection failed: ' + err.message;
                errEl.style.display = 'block';
            }
            btn.disabled = false;
            btn.textContent = 'Sign In';
        }

        function doLogout() {
            authToken = null;
            localStorage.removeItem('jac_token');
            updateHeaderButtons();
            loadGraphData();
        }

        async function loadGraphData() {
            document.getElementById('graph-container').innerHTML = '<div class="loading"><div class="spinner"></div><div>Loading graph data...</div></div>';
            try {
                const headers = {};
                if (authToken) {
                    headers['Authorization'] = 'Bearer ' + authToken;
                }
                const resp = await fetch(baseUrl + '/graph/data', { headers });
                const data = await resp.json();
                if (data.nodes && data.edges) {
                    graphData = data;
                    renderGraph(data);
                } else {
                    document.getElementById('graph-container').innerHTML = '<div class="empty-state"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="5" r="3"/><line x1="12" y1="8" x2="12" y2="16"/><circle cx="6" cy="19" r="3"/><circle cx="18" cy="19" r="3"/></svg><div>No graph data available</div><div style="font-size:13px">Run your Jac program to create graph nodes</div></div>';
                }
            } catch (err) {
                document.getElementById('graph-container').innerHTML = '<div class="empty-state"><div style="color:#ef4444">Failed to load graph: ' + err.message + '</div></div>';
            }
        }

        function getNodeColor(label, isRoot) {
            if (isRoot || label === 'root') return { background: '#ff7743', border: '#e05a2a' };
            const match = label.match(/^([a-zA-Z0-9_]+)\\(/);
            if (match) {
                let hash = 0;
                for (let c of match[1]) hash = c.charCodeAt(0) + ((hash << 5) - hash);
                const hue = Math.abs(hash % 360);
                return { background: `hsl(${hue}, 60%, 50%)`, border: `hsl(${hue}, 60%, 35%)` };
            }
            return { background: '#3b82f6', border: '#374151' };
        }

        function getDisplayLabel(label) {
            if (label === 'root') return 'root';
            const nameMatch = label.match(/name=\'([^\']+)\'/);
            if (nameMatch) return nameMatch[1];
            const typeMatch = label.match(/^([a-zA-Z0-9_]+)\\(/);
            if (typeMatch) return typeMatch[1];
            return label.length > 20 ? label.substring(0, 17) + '...' : label;
        }

        function getEdgeLabel(label) {
            if (!label) return '';
            const m = label.match(/=\'([a-zA-Z0-9_]+)\'/);
            return m ? m[1] : '';
        }

        function renderGraph(data) {
            const container = document.getElementById('graph-container');
            container.innerHTML = '';

            const nodeTypes = new Map();
            const nodes = new vis.DataSet(data.nodes.map(n => {
                const isRoot = n.label === 'root';
                const colors = getNodeColor(n.label, isRoot);
                const display = getDisplayLabel(n.label);
                // Track node types for legend
                const typeMatch = n.label.match(/^([a-zA-Z0-9_]+)\\(/);
                const typeName = isRoot ? 'root' : (typeMatch ? typeMatch[1] : 'other');
                if (!nodeTypes.has(typeName)) nodeTypes.set(typeName, colors.background);
                return {
                    id: n.id,
                    label: display,
                    color: {
                        background: colors.background,
                        border: colors.border,
                        highlight: { background: '#f59e0b', border: '#f59e0b' }
                    },
                    font: { color: '#ffffff', size: 13 },
                    _rawLabel: n.label,
                    _rawId: n.id
                };
            }));

            const edges = new vis.DataSet(data.edges.map((e, i) => ({
                id: 'edge_' + i,
                from: e.from,
                to: e.to,
                label: getEdgeLabel(e.label),
                title: e.label || 'connection',
                arrows: 'to',
                color: { color: '#64748b', opacity: 0.8 },
                font: { color: '#94a3b8', size: 11, strokeWidth: 2, strokeColor: '#0f172a', align: 'top' }
            })));

            const options = {
                autoResize: true,
                nodes: {
                    shape: 'dot',
                    size: 25,
                    borderWidth: 2,
                    shadow: { enabled: true, color: 'rgba(0,0,0,0.3)', size: 8 }
                },
                edges: {
                    width: 2,
                    smooth: { type: 'continuous', forceDirection: 'none' },
                    arrows: { to: { enabled: true, scaleFactor: 0.5 } }
                },
                physics: {
                    enabled: true,
                    solver: 'forceAtlas2Based',
                    forceAtlas2Based: {
                        gravitationalConstant: -50,
                        centralGravity: 0.01,
                        springLength: 120,
                        springConstant: 0.08,
                        damping: 0.4,
                        avoidOverlap: 0.8
                    },
                    stabilization: { enabled: true, iterations: 200, updateInterval: 25, fit: true }
                },
                interaction: {
                    hover: true,
                    tooltipDelay: 200,
                    zoomView: true,
                    dragView: true,
                    dragNodes: true
                },
                layout: { improvedLayout: true }
            };

            network = new vis.Network(container, { nodes, edges }, options);

            // Tooltip handling
            const tooltip = document.getElementById('tooltip');
            network.on('hoverNode', function(e) {
                const nodeData = nodes.get(e.node);
                if (!nodeData) return;
                const pos = e.event.center || { x: e.pointer.DOM.x, y: e.pointer.DOM.y };
                tooltip.innerHTML = '<div class="tooltip-title">' + getDisplayLabel(nodeData._rawLabel) + '</div>'
                    + '<div class="tooltip-label">' + nodeData._rawLabel + '</div>'
                    + '<div class="tooltip-id">ID: ' + nodeData._rawId + '</div>';
                tooltip.style.left = Math.min(pos.x + 15, window.innerWidth - 340) + 'px';
                tooltip.style.top = (pos.y + 60) + 'px';
                tooltip.style.display = 'block';
                container.style.cursor = 'pointer';
            });
            network.on('blurNode', function() {
                tooltip.style.display = 'none';
                container.style.cursor = 'grab';
            });
            network.on('dragStart', function() { container.style.cursor = 'grabbing'; });
            network.on('dragEnd', function() { container.style.cursor = 'grab'; });
            network.on('stabilized', function() {
                network.fit({ animation: { duration: 300, easingFunction: 'easeInOutQuad' } });
            });

            // Stats
            document.getElementById('stats').textContent = data.nodes.length + ' nodes, ' + data.edges.length + ' edges';
            container.style.cursor = 'grab';

            // Add legend
            if (nodeTypes.size > 0) {
                let legendEl = document.getElementById('graph-legend');
                if (!legendEl) {
                    legendEl = document.createElement('div');
                    legendEl.id = 'graph-legend';
                    legendEl.className = 'legend';
                    container.appendChild(legendEl);
                }
                let html = '<div class="legend-title">Node Types</div>';
                nodeTypes.forEach((color, type) => {
                    html += '<div class="legend-item"><div class="legend-color" style="background:' + color + '"></div>' + type + '</div>';
                });
                legendEl.innerHTML = html;
            }
        }

        function refreshGraph() { loadGraphData(); }
        function fitGraph() { if (network) network.fit({ animation: { duration: 500, easingFunction: 'easeInOutQuad' } }); }
        function togglePhysics() {
            physicsEnabled = !physicsEnabled;
            if (network) network.setOptions({ physics: { enabled: physicsEnabled } });
            document.getElementById('physics-btn').style.borderColor = physicsEnabled ? '#334155' : '#f59e0b';
        }
    </script>
</body>
</html>''';
    return HTMLResponse(content=html_content, status_code=200);
}

"""Return graph data as JSON. Uses authenticated user's root if token provided, otherwise falls back to __guest__ (super root)."""
impl JacAPIServerStatic.graph_data(Authorization: (str | None) = None) -> JSONResponse {
    import from jaclang.runtimelib.utils { collect_node_connections }
    # Try to validate JWT token; fall back to __guest__ if not provided
    token: (str | None) = None;
    if (
        Authorization
        and isinstance(Authorization, str)
        and Authorization.startswith('Bearer ')
    ) {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;
    # Fall back to __guest__ (super root) when no auth provided
    username = username or '__guest__';
    # Get user's root node and collect graph data
    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return JSONResponse(
            status_code=404,
            content={'error': 'Not found', 'message': 'User root not found'}
        );
    }
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    try {
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict] = [];
        edges: list[dict] = [];

        collect_node_connections(user_root, visited_nodes, connections, edge_ids);

        nodes.append({'id': str(id(user_root)), 'label': 'root'});
        for node_arch in visited_nodes {
            if (node_arch != user_root) {
                nodes.append({'id': str(id(node_arch)), 'label': repr(node_arch)});
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict = {
                'from': str(id(source_node)),
                'to': str(id(target_node))
            };
            if (repr(edge_arch) != 'GenericEdge()') {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }

        return JSONResponse(
            status_code=200, content={'version': '1.0', 'nodes': nodes, 'edges': edges}
        );
    } except Exception as e {
        return JSONResponse(
            status_code=500, content={'error': 'Internal error', 'message': str(e)}
        );
    }
}
