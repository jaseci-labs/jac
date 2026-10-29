impl _dev_client_elsewhere -> JSONResponse {
    return JSONResponse(
        status_code=404,
        content={
            'error': 'Not found',
            'detail': 'in dev the client is served by the dev server on the web port'
        }
    );
}

impl _static_base(server: JacAPIServer) -> str {
    source_path = getattr(server.module, '__file__', '') or '';
    image_root = sealed_root_for(source_path) if source_path else None;
    if image_root is not None {
        return image_root;
    }
    fallback = Path(server.base_path) if server.base_path else None;
    return str(resolve_base_path(fallback=fallback));
}

impl _render(
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

impl _sibling_response(request: Request, dist: Path, rel: str) -> Response {
    return file_response(request, str(sibling_app_file(dist, rel)));
}

impl register_page_endpoints(server: JacAPIServer) {
    settings = server.resolved_settings();
    config = get_config();
    root_app = "" if settings.static_only else server.introspector.resolve_root_app();
    asset_dist = settings.client_dist;
    if not asset_dist {
        import from jaclang.client.artifact { client_output_dir }
        source_path = getattr(server.module, '__file__', '')
            or Jac.get_full_target_path()
            or '';
        built_dist = client_output_dir(Path(source_path)) if source_path else None;
        if built_dist is not None and built_dist.is_dir() {
            asset_dist = str(built_dist);
        }
    }
    if not asset_dist {
        default_dist = Path(_static_base(server)) / '.jac' / 'client' / 'dist';
        if default_dist.is_dir() {
            asset_dist = str(default_dist);
        }
    }
    asset_table: list[AssetRoot] = asset_root_table(
        Path(_static_base(server)), Path(asset_dist)
    );

    def render_page(
        request: Request, /, page_name: str, **kwargs: JsonValue
    ) -> Response {
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

    def root_index(request: Request, /, **kwargs: JsonValue) -> Response {
        index = client_dist_index(asset_dist);
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
        target = resolve_asset(asset_table, '/static/' + file_path);
        if target is None {
            return JSONResponse(
                content={'error': 'Static file not found'}, status_code=404
            );
        }
        return file_response(
            request, str(target), cache_control=asset_cache_policy(target)
        );
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
        target = resolve_asset(asset_table, '/' + file_path);
        if target is not None {
            return file_response(
                request, str(target), cache_control=asset_cache_policy(target)
            );
        }
        index = client_dist_index(asset_dist);
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

impl register_graph_endpoints(server: JacAPIServer) {
    if server.introspector.has_client_route('/graph') {
        return;
    }

    def graph_page(request: Request) -> Response {
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
            description='Interactive explorer of the graph reachable from the caller\'s root, one page of neighbors at a time.',
            include_in_schema=False
        )
    );

    def graph_scope(request: Request) -> (Response | None) {
        username = request.state?.username or Con.GUEST.value;
        root_id = server.user_manager.get_root_id(str(username));
        if not root_id {
            return JSONResponse(
                status_code=404, content={'error': 'User root not found'}
            );
        }
        Jac.get_context().set_user_root(root_id);
        return None;
    }

    def graph_target(request: Request) -> (NodeArchetype | Response) {
        denied = graph_scope(request);
        if denied is not None {
            return denied;
        }
        ref = request.query_params.get('id') or 'root';
        try {
            found = Jac.get_object(ref);
        } except ValueError {
            found = None;
        }
        if not isinstance(found, NodeArchetype) {
            return JSONResponse(status_code=404, content={'error': 'Node not found'});
        }
        return found;
    }

    def graph_node(request: Request) -> Response {
        target = graph_target(request);
        if isinstance(target, Response) {
            return target;
        }
        return JSONResponse(content=graph_node_view(target));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph/node',
            callback=graph_node,
            parameters=[],
            tags=['Graph Visualization'],
            summary='Graph node',
            description='One node the caller can read (`id`, or the caller\'s root): its type, a short field summary, and neighbor counts per node and edge type.',
            include_in_schema=False,
            forward_undeclared_query_params=False
        )
    );

    def graph_neighbors(request: Request) -> Response {
        target = graph_target(request);
        if isinstance(target, Response) {
            return target;
        }
        params = request.query_params;
        node_type: (type | None) = None;
        edge_type: (type | None) = None;
        if params.get('type') {
            node_type = graph_type_named(NodeArchetype, str(params.get('type')));
            if node_type is None {
                return JSONResponse(
                    status_code=400,
                    content={'error': 'Unknown node type', 'code': 'unknown_type'}
                );
            }
        }
        if params.get('edge') {
            edge_type = graph_type_named(EdgeArchetype, str(params.get('edge')));
            if edge_type is None {
                return JSONResponse(
                    status_code=400,
                    content={'error': 'Unknown edge type', 'code': 'unknown_type'}
                );
            }
        }
        try {
            page = graph_neighbors_view(
                target,
                direction=params.get('dir') or 'out',
                node_type=node_type,
                edge_type=edge_type,
                limit=int(params.get('limit') or 50),
                cursor=params.get('cursor')
            );
        } except ValueError as exc {
            return JSONResponse(status_code=400, content={'error': str(exc)});
        }
        return JSONResponse(content=page);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph/neighbors',
            callback=graph_neighbors,
            parameters=[],
            tags=['Graph Visualization'],
            summary='Graph neighbors',
            description='One page of a readable node\'s neighbors with the edges that reach them (`id`, `dir`, `type`, `edge`, `limit`, `cursor`), and the cursor of the next page.',
            include_in_schema=False,
            forward_undeclared_query_params=False
        )
    );
}

impl register_diagnostics_endpoints(server: JacAPIServer) {
    async def build_status(request: Request) -> JSONResponse {
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
