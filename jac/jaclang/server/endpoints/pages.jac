import logging;
import from pathlib { Path }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.serving.datatypes {
    HTMLResponse,
    JSONResponse,
    Request,
    Response
}
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.project.config { get_config }
import from jaclang.server.serving.files { file_response }
import from jaclang.server.server { JacAPIServer, JsonValue }
import from jaclang.server.static_files {
    find_root_asset,
    client_dist_index,
    find_static_candidate,
    sibling_app_dist,
    sibling_app_file
}

glob logger: logging.Logger = logging.getLogger('jaclang.serve'),
     CL_PREFIX: str = 'cl/',
     API_PREFIXES: tuple = ('walker/', 'function/', 'user/', 'static/', 'healthz'),
     ASSET_CACHE_CONTROL: str = 'public, max-age=31536000, immutable';


def _dev_client_elsewhere -> JSONResponse {
    return JSONResponse(
        status_code=404,
        content={
            'error': 'Not found',
            'detail': 'in dev the client is served by the dev server on the web port'
        }
    );
}


def _static_base(server: JacAPIServer) -> str {
    ctx = Jac.get_context();
    bp = (ctx.base_path_dir if ctx else '') or Jac.get_base_path_dir();
    return bp or server.base_path;
}


def _render(
    server: JacAPIServer, name: str, args: dict[str, any], status: int = 200
) -> Response {
    if server.introspector.dev_mode {
        return _dev_client_elsewhere();
    }
    try {
        payload = server.introspector.render_page(name, args, Con.GUEST.value);
        return HTMLResponse(content=payload['html'], status_code=status);
    } except ValueError {
        return HTMLResponse(content='<h1>404 Not Found</h1>', status_code=404);
    } except RuntimeError as exc {
        logger.error(f"rendering page {name!r} failed: {exc}");
        return HTMLResponse(
            content='<h1>503 Service Unavailable</h1>', status_code=503
        );
    }
}


def _sibling_response(request: Request, dist: Path, rel: str) -> Response {
    return file_response(request, str(sibling_app_file(dist, rel)));
}


def register_page_endpoints(server: JacAPIServer) {
    settings = server.resolved_settings();
    config = get_config();
    root_app = server.introspector.resolve_root_app();

    def render_page(request: Request, page_name: str, **kwargs: JsonValue) -> Response {
        sibling = sibling_app_dist(config, page_name, server.base_path);
        if sibling is not None {
            return _sibling_response(request, sibling, '');
        }
        return _render(server, page_name, kwargs);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/cl/{page_name}',
            callback=render_page,
            parameters=[
                APIParameter(
                    name='page_name',
                    data_type='string',
                    required=True,
                    description='Name of the client page to render, or a sibling app',
                    kind=ParameterType.PATH
                )
            ],
            tags=['Pages'],
            summary='Render a client page',
            description='Render the named client function as a page at /cl/{name}, or a workspace sibling app bundle at /cl/<app>/.',
            include_in_schema=False
        )
    );

    if config is not None and config.is_workspace {
        def sibling_asset(request: Request, app_name: str, file_path: str) -> Response {
            dist = sibling_app_dist(config, app_name, server.base_path);
            if dist is None {
                return JSONResponse(content={'error': 'Not found'}, status_code=404);
            }
            return _sibling_response(request, dist, file_path);
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/cl/{app_name}/{file_path:path}',
                callback=sibling_asset,
                parameters=[
                    APIParameter(
                        name='app_name',
                        data_type='string',
                        required=True,
                        description='Sibling app whose bundle lives at dist/<app>/',
                        kind=ParameterType.PATH
                    ),
                    APIParameter(
                        name='file_path',
                        data_type='string',
                        required=True,
                        description='Path inside the sibling app bundle',
                        kind=ParameterType.PATH
                    )
                ],
                tags=['Pages'],
                summary='Serve a sibling app bundle',
                description='Serves a workspace sibling client app from dist/<app>/ at /cl/<app>/.',
                include_in_schema=False,
                forward_undeclared_query_params=False
            )
        );
    }

    def root_index(request: Request, **kwargs: JsonValue) -> Response {
        index = client_dist_index(settings.client_dist);
        if index is not None {
            return file_response(request, str(index), cache_control='no-cache');
        }
        if root_app {
            return _render(
                server, root_app, kwargs, server.introspector.spa_fallback_status('/')
            );
        }
        return JSONResponse(
            content={
                'message': f"{server.module_name} API",
                'docs': '/docs' if settings.docs_enabled else None,
                'health': '/healthz/ready',
                'endpoints': {
                    'POST /user/register': 'Create a new user',
                    'POST /user/login': 'Authenticate and get a token',
                    'GET /user/me': 'The authenticated user (auth required)',
                    'GET /user/info': 'The user id, root id and session token (auth required)',
                    'GET /functions': 'List the functions',
                    'GET /walkers': 'List the walkers',
                    'GET /function/<name>': 'A function signature',
                    'GET /walker/<name>': 'A walker\'s fields',
                    'POST /function/<name>': 'Call a function',
                    'POST /walker/<name>': 'Spawn a walker',
                    'GET /cl/<name>': 'Render a client page',
                    'GET /cl/<app>/': 'A workspace sibling app bundle'
                }
            }
        );
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/',
            callback=root_index,
            parameters=[],
            tags=['Pages'],
            summary='Root',
            description=(
                f"Serves the {root_app} client app" if root_app else 'Service index'
            ),
            include_in_schema=False
        )
    );

    def client_js(request: Request) -> Response {
        if server.introspector.dev_mode {
            return _dev_client_elsewhere();
        }
        try {
            js_code = Jac.get_client_js(server.introspector);
        } except RuntimeError as exc {
            return JSONResponse(content={'error': str(exc)}, status_code=503);
        }
        resp = Response(content=js_code, media_type='text/javascript; charset=utf-8');
        resp.headers.set('Cache-Control', 'no-cache');
        return resp;
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/client.js',
            callback=client_js,
            parameters=[],
            tags=['Static Files'],
            summary='Client bundle',
            include_in_schema=False
        )
    );

    def static_file(request: Request, file_path: str) -> Response {
        candidate = find_static_candidate(
            _static_base(server), file_path, settings.client_dist
        );
        if candidate is None {
            return JSONResponse(
                content={'error': 'Static file not found'}, status_code=404
            );
        }
        return file_response(request, str(candidate));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/{file_path:path}',
            callback=static_file,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    description='Path of the static file, under the client dist, dist or assets directory',
                    kind=ParameterType.PATH
                )
            ],
            tags=['Static Files'],
            summary='Serve static files',
            include_in_schema=False,
            forward_undeclared_query_params=False
        )
    );

    def root_asset(request: Request, file_path: str) -> Response {
        if file_path.startswith(API_PREFIXES) or file_path.startswith(CL_PREFIX) {
            return JSONResponse(content={'error': 'Not found'}, status_code=404);
        }
        candidate = find_root_asset(
            _static_base(server), file_path, settings.client_dist
        );
        if candidate is not None {
            return file_response(
                request, str(candidate), cache_control=ASSET_CACHE_CONTROL
            );
        }
        index = client_dist_index(settings.client_dist);
        if index is not None and not Path(file_path).suffix {
            return file_response(request, str(index), cache_control='no-cache');
        }
        if not Path(file_path).suffix and root_app {
            if server.introspector.dev_mode {
                return _dev_client_elsewhere();
            }
            return _render(
                server, root_app, {}, server.introspector.spa_fallback_status(file_path)
            );
        }
        return JSONResponse(content={'error': 'Not found'}, status_code=404);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/{file_path:path}',
            callback=root_asset,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    description='Asset path (img.png, icons/logo.svg) or a client route',
                    kind=ParameterType.PATH
                )
            ],
            tags=['Static Files'],
            summary='Root assets and client routes',
            include_in_schema=False,
            forward_undeclared_query_params=False
        )
    );
}


def register_graph_endpoints(server: JacAPIServer) {
    if server.introspector.has_client_route('/graph') {
        return;
    }

    def graph_page(request: Request) -> Response {
        import jaclang.scale as scale_mod;
        try {
            template = Path(scale_mod.__file__).parent / 'templates' / 'graph.html';
            return HTMLResponse(content=template.read_text(encoding='utf-8'));
        } except OSError as exc {
            return JSONResponse(
                status_code=503,
                content={'error': f"Graph visualizer template unavailable ({exc})"}
            );
        }
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph',
            callback=graph_page,
            parameters=[],
            tags=['Graph Visualization'],
            summary='Graph visualizer',
            description='Interactive visualization of the graph reachable from the caller\'s root.',
            include_in_schema=False
        )
    );

    def graph_data(request: Request) -> Response {
        import from jaclang.runtime.graph_utils { collect_node_connections }
        username = request.state?.username or Con.GUEST.value;
        root_id = server.user_manager.get_root_id(str(username));
        if not root_id {
            return JSONResponse(
                status_code=404, content={'error': 'User root not found'}
            );
        }
        ctx = Jac.get_context();
        ctx.set_user_root(root_id);
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict] = [];
        edges: list[dict] = [];
        collect_node_connections(user_root, visited_nodes, connections, edge_ids);
        nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
        for node_arch in visited_nodes {
            if node_arch != user_root {
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
            if repr(edge_arch) != 'GenericEdge()' {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }
        return JSONResponse(content={'version': '1.0', 'nodes': nodes, 'edges': edges});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph/data',
            callback=graph_data,
            parameters=[],
            tags=['Graph Visualization'],
            summary='Graph data',
            description='Nodes and edges reachable from the caller\'s root as JSON (the guest root without a token).',
            include_in_schema=False
        )
    );
}


def register_diagnostics_endpoints(server: JacAPIServer) {
    async def build_status(request: Request) -> JSONResponse {
        import from jaclang.server.hmr { get_build_status }
        return JSONResponse(content=get_build_status());
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/__build_status',
            callback=build_status,
            parameters=[],
            tags=['Health'],
            summary='Dev build health',
            description='Hot-reload build status: ok, compiling, error (with diagnostics), or unavailable outside dev mode.',
            include_in_schema=False
        )
    );

    async def client_error(request: Request) -> JSONResponse {
        try {
            data = await request.json();
        } except Exception {
            return JSONResponse(status_code=400, content={'error': 'Invalid JSON'});
        }
        if not isinstance(data, dict) or not data.get('message') {
            return JSONResponse(
                status_code=400, content={'error': 'Missing required field: message'}
            );
        }
        import from jaclang.client.source_mapping { _error_rate_limiter }
        import from jaclang.client.client_diagnostics { log_client_error }
        import from jaclang.project.config { get_config }
        if not _error_rate_limiter.should_log(str(data.get('message'))) {
            return JSONResponse(content={'ok': True, 'throttled': True});
        }
        cfg = get_config();
        verbose = cfg.client_errors.verbose if cfg else False;
        diag = log_client_error(server.base_path or '', data, verbose);
        logger.error(diag.render());
        return JSONResponse(content={'ok': True});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/cl/__error__',
            callback=client_error,
            parameters=[],
            tags=['Client'],
            summary='Report a client-side error',
            include_in_schema=False,
            forward_undeclared_query_params=False
        )
    );
}
