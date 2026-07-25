import from collections.abc { Callable }
import from fastapi { Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response }
import from jaclang.scale.jserver.jserver {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.server { JsonValue }
import from jaclang.runtimelib.client.assets { AssetResolution, AssetResolver }
import from jaclang.cli.console { console }

impl JacAPIServerStatic.asset_response(
    resolution: AssetResolution, request: Request
) -> Response {
    import from jaclang.runtimelib.client.assets { parse_byte_range }
    if not resolution.is_served() {
        return Response(
            status_code=resolution.status,
            content=resolution.message or 'Not found',
            media_type='text/plain; charset=utf-8',
            headers={'Cache-Control': 'no-store'}
        );
    }
    headers = resolution.headers();
    headers['Accept-Ranges'] = 'bytes';
    if resolution.is_fresh(
        request.headers.get('if-none-match'), request.headers.get('if-modified-since')
    ) {
        return Response(status_code=304, headers=headers);
    }
    try {
        payload = resolution.read_bytes();
    } except OSError as exc {
        console.print(f"Error reading asset {resolution.path}: {exc}");
        return Response(
            status_code=500, content='Internal server error', media_type='text/plain'
        );
    }
    window = parse_byte_range(request.headers.get('range'), len(payload));
    if window is not None {
        (start, end) = window;
        headers['Content-Range'] = f"bytes {start}-{end}/{len(payload)}";
        return Response(
            status_code=206,
            content=payload[start:end + 1],
            media_type=resolution.media_type,
            headers=headers
        );
    }
    return Response(content=payload, media_type=resolution.media_type, headers=headers);
}

impl JacAPIServerStatic.serve_asset(file_path: str, request: Request) -> Response {
    import from jaclang.runtimelib.client.assets { AssetOutcome, is_reserved_url }
    url_path = request.url.path;
    resolution = self.asset_resolver().resolve(url_path, request.url.query);
    if resolution.outcome != AssetOutcome.NOT_AN_ASSET.value {
        return self.asset_response(resolution, request);
    }
    rel = url_path.lstrip('/');
    if is_reserved_url(rel, self.asset_resolver().policy.reserved_prefixes) {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    import from jaclang.project.config { get_config }
    config = get_config();
    configured_root = config.serve.base_route_app if config else "";
    base_route_app = self.introspector.resolve_root_app(configured_root);
    if not base_route_app {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    try {
        render_payload = self.introspector.render_page(
            base_route_app, {}, Con.GUEST.value
        );
    } except ValueError {
        return HTMLResponse(content="<h1>404 Not Found</h1>", status_code=404);
    } except RuntimeError {
        return HTMLResponse(
            content="<h1>503 Service Unavailable</h1>", status_code=503
        );
    }
    return HTMLResponse(
        content=render_payload['html'],
        status_code=self.introspector.spa_fallback_status(url_path)
    );
}

impl JacAPIServerStatic.asset_resolver -> AssetResolver {
    if self._asset_resolver is None {
        self._asset_resolver = AssetResolver.build(dev=False);
    }
    return self._asset_resolver;
}

impl JacAPIServerStatic.register_static_file_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/{file_path:path}',
            callback=self.serve_asset,
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

impl JacAPIServerStatic.register_page_endpoint -> None {
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    configured_root = config.serve.base_route_app if config else "";
    base_route_app = self.introspector.resolve_root_app(configured_root);

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

impl JacAPIServerStatic.render_page_callback -> Callable[..., HTMLResponse] {
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

impl JacAPIServerStatic.render_base_route_callback(
    app_name: str
) -> Callable[..., HTMLResponse] {
    def callback(**kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                app_name, kwargs, Con.GUEST.value
            );
            return HTMLResponse(
                content=render_payload['html'],
                status_code=self.introspector.spa_fallback_status('/')
            );
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

impl JacAPIServerStatic.register_root_asset_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/{file_path:path}',
            callback=self.serve_asset,
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
            description='Serves assets from the configured asset roots, falling back to the base route app for client-side routes.'
        )
    );
}

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

impl JacAPIServerStatic.serve_graph_page -> HTMLResponse {
    import jaclang.scale;
    import from pathlib { Path }

    html_content = (
        Path(jaclang.scale.__file__).parent / 'templates' / 'graph.html'
    ).read_text(
        encoding='utf-8'
    );
    return HTMLResponse(content=html_content, status_code=200);
}


impl JacAPIServerStatic.graph_data(Authorization: (str | None) = None) -> JSONResponse {
    import from jaclang.runtimelib.utils { collect_node_connections }

    token: (str | None) = None;
    if (
        Authorization
        and isinstance(Authorization, str)
        and Authorization.startswith('Bearer ')
    ) {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;

    username = username or Con.GUEST.value;

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

        nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
        for node_arch in visited_nodes {
            if (node_arch != user_root) {
                nodes.append(
                    {'id': Jac.object_ref(node_arch), 'label': repr(node_arch)}
                );
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict = {
                'from': Jac.object_ref(source_node),
                'to': Jac.object_ref(target_node)
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
