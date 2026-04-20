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
        # 1. .jac/client/dist/ — jac-client's Vite build output directory.
        #    Checked first because font packages (e.g. @fontsource-variable/outfit) installed
        #    via jac-client emit .woff2/.ttf files here, and CSS @font-face rules reference
        #    them with root-relative URLs (e.g. /assets/outfit.woff2). Without this candidate
        #    those requests return 404 even though the file exists on disk.
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
            return Response(
                content=str(exc), status_code=503, media_type='text/plain'
            );
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
                page_name, kwargs, Con.GUEST.value
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
                app_name, kwargs, Con.GUEST.value
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
        if (
            not file_ext and base_route_app and not file_path.startswith(api_prefixes)
        ) {
            try {
                render_payload = self.introspector.render_page(
                    base_route_app, {}, Con.GUEST.value
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

    # Project-level folders take priority to avoid shadowing user files
    candidates = [
        base_path / 'dist' / file_path,
        base_path / 'dist' / file_name,
        base_path / 'assets' / file_path,
        base_path / 'assets' / file_name,
        base_path / 'public' / file_path,
        base_path / 'src' / file_path,
        base_path / 'src' / file_name,
        (base_path / file_path),
        base_path / '.jac' / 'client' / 'dist' / file_path,
        base_path / '.jac' / 'client' / 'dist' / file_name
    ];
    # The above last two lines
    # .jac/client/dist/ — jac-client's Vite build output.
    # Font packages (e.g. @fontsource-variable/outfit) emit .woff2/.ttf files here.
    # CSS @font-face rules reference them with root-relative URLs (e.g. /assets/outfit.woff2),
    # so serve_root_asset must include this path or those requests return 404.
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
    import from importlib.resources { files }
    html_content = files('jac_scale').joinpath('templates/graph.html').read_text(
        encoding='utf-8'
    );
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
    username = username or Con.GUEST.value;
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
