"""Server implementations."""
import json;
import from collections.abc { Callable }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { Any }
import from urllib.parse { parse_qs, urlparse }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.server.handlers {
    AuthHandler,
    IntrospectionHandler,
    ExecutionHandler
}
import from jaclang.runtimelib.server.infra { Infra }
import from jaclang.runtimelib.server.response_builder { ResponseBuilder }
import from jaclang.runtimelib.server.types { Response }
import from jaclang.runtimelib.server.user_manager { UserManager }
import from jaclang.runtimelib.server.execution_manager { ExecutionManager }
import from jaclang.runtimelib.server { JacAPIServer }
import from jaclang { JacRuntime as Jac }

import from jaclang.pycore.constructs { WalkerArchetype }

"""Initialize the API server."""
impl JacAPIServer.postinit -> None {
    # Get persistent data store from Infra (or use default file store)
    config = get_config();
    persistent_config = None;
    if config and config?.environments and config.environments {
        db_config = config.environments.get('database', {});
        if db_config {
            persistent_config = {
                'type': db_config.get('type', 'file'),
                'path': f"{self.session_path}.users.json"
                if db_config.get('type') == 'file'
                else None,
                'connection_string': db_config.get('connection_string'),
                'db_name': db_config.get('db_name'),
                'collection_name': db_config.get('collection_name', 'users')
            };
        }
    }
    # If no config, use default file store
    if not persistent_config {
        persistent_config = {'type': 'file', 'path': f"{self.session_path}.users.json"};
    }
    persistent_store = Infra.get_persistent_memory(persistent_config);
    # Initialize UserManager with data store
    self.user_manager = UserManager();
    self.user_manager.init(session_path=self.session_path, data_store=persistent_store);
    self.introspector = Jac.get_module_introspector(self.module_name, self.base_path);
    self.execution_manager = ExecutionManager(
        session_path=self.session_path, user_manager=self.user_manager
    );
    self.auth_handler = AuthHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
    self.introspection_handler = IntrospectionHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
    self.execution_handler = ExecutionHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
}

"""Create HTTP request handler."""
impl JacAPIServer.create_handler -> type[BaseHTTPRequestHandler] {
    server = self;
    """Handle HTTP requests.""";
    class JacRequestHandler(BaseHTTPRequestHandler) {
        """Extract auth token from Authorization header."""
        def _get_auth_token(self: JacRequestHandler) -> (str | None) {
            auth_header = self.headers.get('Authorization');
            return auth_header[7:]
            if (auth_header and auth_header.startswith('Bearer '))
            else None;
        }

        """Authenticate request and return username."""
        def _authenticate(self: JacRequestHandler) -> (str | None) {
            token = self._get_auth_token();
            return server.user_manager.validate_token(token) if token else None;
        }

        """Read and parse JSON from request body."""
        def _read_json(self: JacRequestHandler) -> dict[str, Any] {
            content_length = int(self.headers.get('Content-Length', 0));
            body = self.rfile.read(content_length).decode()
            if (content_length > 0)
            else '{}';
            return json.loads(body);
        }

        """Send response to client."""
        def _send_response(self: JacRequestHandler, response: Response) -> None {
            Jac.send_json(self, response.status, response.body);
        }

        """Handle OPTIONS requests (CORS preflight)."""
        def do_OPTIONS(self: JacRequestHandler) -> None {
            self.send_response(200);
            ResponseBuilder._add_cors_headers(self);
            ResponseBuilder._add_custom_headers(self);
            self.end_headers();
        }

        """Handle GET requests."""
        def do_GET(self: JacRequestHandler) -> None {
            parsed_path = urlparse(self.path);
            path = parsed_path.path;
            if (path == '/static/client.js') {
                try {
                    server.introspector.load();
                    server.introspector.ensure_bundle();
                    Jac.send_javascript(self, server.introspector._bundle.code);
                } except RuntimeError as exc {
                    Jac.send_json(self, 500, {'error': str(exc)});
                }
                return;
            }
            is_static_path = path.startswith('/static/');
            import from jaclang.project.config { get_config }

            config = get_config();
            client_cfg = config.get_plugin_config("client") if config else None;
            assets_config = client_cfg.get("assets", {}) if client_cfg else {};
            custom_asset_extensions = set(assets_config.get("custom_extensions", []));
            cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
            cl_route_path = f"/{cl_route_prefix}/";
            is_asset_file = (
                not is_static_path
                and (path != '/')
                and not path.startswith(cl_route_path)
                and not path.startswith('/function/')
                and not path.startswith('/walker/')
                and not path.startswith('/user/')
                and not path.startswith('/functions')
                and not path.startswith('/walkers')
                and not path.startswith('/protected')
                and (
                    Path(path).suffix in (
                        custom_asset_extensions
                        or {'.png','.jpg','.jpeg','.gif','.webp','.svg','.ico','.woff','.woff2','.ttf','.otf','.eot','.mp4','.webm','.mp3','.wav','.css'}
                    )
                )
            );
            if (is_static_path or is_asset_file) {
                try {
                    # Find project root (where jac.toml is) instead of using base_path_dir
                    # base_path_dir might be src/ when serving src/app.jac, but we need project root
                    import from jaclang.project.config { find_project_root }
                    base_path_dir = Path(Jac.base_path_dir)
                    if Jac.base_path_dir
                    else Path.cwd();
                    project_root_result = find_project_root(base_path_dir);
                    if project_root_result {
                        (base_path, _) = project_root_result;
                    } else {
                        # Fallback to base_path_dir if no project root found
                        base_path = base_path_dir;
                    }
                    if is_static_path {
                        relative_path = path[8:];
                    } else {
                        relative_path = path[1:];
                    }
                    file_name = Path(relative_path).name;
                    # Check multiple locations for CSS files
                    # 1. .jac/client/dist/ (standardized structure)
                    client_build_dist_file = base_path / '.jac' / 'client' / 'dist' / relative_path;
                    client_build_dist_file_simple = base_path / '.jac' / 'client' / 'dist' / file_name;
                    # 2. dist/ (legacy structure)
                    dist_file = base_path / 'dist' / relative_path;
                    dist_file_simple = base_path / 'dist' / file_name;
                    # 3. assets/ (static assets)
                    assets_file = base_path / 'assets' / relative_path;
                    assets_file_simple = base_path / 'assets' / file_name;
                    if path.endswith('.css') {
                        # Check .jac/client/dist/ first (jac-client)
                        if client_build_dist_file.exists() {
                            css_content = client_build_dist_file.read_text(
                                encoding='utf-8'
                            );
                            Jac.send_css(self, css_content);
                            return;
                        } elif client_build_dist_file_simple.exists() {
                            css_content = client_build_dist_file_simple.read_text(
                                encoding='utf-8'
                            );
                            Jac.send_css(self, css_content);
                            return;
                        } elif dist_file.exists() {
                            css_content = dist_file.read_text(encoding='utf-8');
                            Jac.send_css(self, css_content);
                            return;
                        } elif dist_file_simple.exists() {
                            css_content = dist_file_simple.read_text(encoding='utf-8');
                            Jac.send_css(self, css_content);
                            return;
                        } elif assets_file.exists() {
                            css_content = assets_file.read_text(encoding='utf-8');
                            Jac.send_css(self, css_content);
                            return;
                        } elif assets_file_simple.exists() {
                            css_content = assets_file_simple.read_text(
                                encoding='utf-8'
                            );
                            Jac.send_css(self, css_content);
                            return;
                        } else {
                            Jac.send_json(self, 404, {'error': 'CSS file not found'});
                            return;
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
                            Jac.send_static_file(self, candidate_file);
                            return;
                        }
                    }
                    Jac.send_json(self, 404, {'error': 'Static file not found'});
                } except Exception as exc {
                    Jac.send_json(self, 500, {'error': str(exc)});
                }
                return;
            }
            if (path == '/') {
                base_route_app = config.serve.base_route_app if config else "";
                if base_route_app {
                    # Serve the configured base route app at /
                    query_params = parse_qs(parsed_path.query, keep_blank_values=True);
                    args = {
                        key: values[0] if (len(values) == 1) else values
                        for (key, values) in query_params.items()
                        if (key != 'mode')
                    };
                    username = self._authenticate();
                    if not username {
                        username = '__guest__';
                        if (username not in server.user_manager._users) {
                            server.user_manager.create_user(
                                username, '__no_password__'
                            );
                        }
                    }
                    try {
                        render_payload = server.introspector.render_page(
                            base_route_app, args, username
                        );
                        Jac.send_html(self, 200, render_payload['html']);
                    } except ValueError as exc {
                        Jac.send_json(self, 404, {'error': str(exc)});
                    } except RuntimeError as exc {
                        Jac.send_json(self, 500, {'error': str(exc)});
                    }
                    return;
                }
                Jac.send_json(
                    self,
                    200,
                    {
                        'message': 'Jac API Server',
                        'endpoints': {
                            'POST /user/register': 'Create a new user',
                            'POST /user/login': 'Authenticate and get token',
                            'GET /functions': 'List all available functions',
                            'GET /walkers': 'List all available walkers',
                            'GET /function/<name>': 'Get function signature',
                            'GET /walker/<name>': 'Get walker fields',
                            'POST /function/<name>': 'Call a function',
                            'POST /walker/<name>': 'Spawn a walker',
                            f'GET /{cl_route_prefix}/<name>': 'Render HTML page for client function'
                        }
                    }
                );
                return;
            }
            if path.startswith(cl_route_path) {
                func_name = path.split('/')[-1];
                query_params = parse_qs(parsed_path.query, keep_blank_values=True);
                args = {
                    key: values[0] if (len(values) == 1) else values
                    for (key, values) in query_params.items()
                    if (key != 'mode')
                };
                username = self._authenticate();
                if not username {
                    username = '__guest__';
                    if (username not in server.user_manager._users) {
                        server.user_manager.create_user(username, '__no_password__');
                    }
                }
                try {
                    render_payload = server.introspector.render_page(
                        func_name, args, username
                    );
                    Jac.send_html(self, 200, render_payload['html']);
                } except ValueError as exc {
                    Jac.send_json(self, 404, {'error': str(exc)});
                } except RuntimeError as exc {
                    Jac.send_json(self, 500, {'error': str(exc)});
                }
                return;
            }
            if (path == '/functions') {
                self._send_response(server.introspection_handler.list_functions());
                return;
            } elif (path == '/walkers') {
                self._send_response(server.introspection_handler.list_walkers());
                return;
            } elif path.startswith('/function/') {
                name = path.split('/')[-1];
                server.introspector.load();
                if server.introspector.is_auth_required_for_function(name) {
                    username = self._authenticate();
                    if not username {
                        Jac.send_json(self, 401, {'error': 'Unauthorized'});
                        return;
                    }
                }
                self._send_response(
                    server.introspection_handler.get_function_info(name)
                );
                return;
            } elif path.startswith('/walker/') {
                name = path.split('/')[-1];
                server.introspector.load();
                if server.introspector.is_auth_required_for_walker(name) {
                    username = self._authenticate();
                    if not username {
                        Jac.send_json(self, 401, {'error': 'Unauthorized'});
                        return;
                    }
                }
                self._send_response(server.introspection_handler.get_walker_info(name));
                return;
            } elif (path == '/protected') {
                username = self._authenticate();
                if not username {
                    Jac.send_json(self, 401, {'error': 'Unauthorized'});
                    return;
                }
                self._send_response(
                    Response(status=200, body={'message': 'sucessful'})
                );
            } else {
                Jac.send_json(self, 404, {'error': 'Not found'});
            }
        }

        """Handle POST requests."""
        def do_POST(self: JacRequestHandler) -> None {
            parsed_path = urlparse(self.path);
            path = parsed_path.path;
            try {
                data = self._read_json();
            } except json.JSONDecodeError {
                Jac.send_json(self, 400, {'error': 'Invalid JSON'});
                return;
            }
            if (path == '/user/register') {
                response = server.auth_handler.create_user(
                    data.get('username', ''), data.get('password', '')
                );
                self._send_response(response);
                return;
            }
            if (path == '/user/login') {
                response = server.auth_handler.login(
                    data.get('username', ''), data.get('password', '')
                );
                self._send_response(response);
                return;
            }
            if path.startswith('/function/') {
                name = path.split('/')[-1];
                server.introspector.load();
                if server.introspector.is_auth_required_for_function(name) {
                    username = self._authenticate();
                    if not username {
                        Jac.send_json(self, 401, {'error': 'Unauthorized'});
                        return;
                    }
                } else {
                    username = self._authenticate();
                    if not username {
                        username = '__guest__';
                        if (username not in server.user_manager._users) {
                            server.user_manager.create_user(
                                username, '__no_password__'
                            );
                        }
                    }
                }
                response = server.execution_handler.call_function(
                    name, data.get('args', {}), username
                );
                self._send_response(response);
            } elif path.startswith('/walker/') {
                name_parts = path.split('/');
                name = name_parts[-2] if (len(name_parts) > 3) else name_parts[-1];
                node_id = name_parts[-1] if (len(name_parts) > 3) else '';
                server.introspector.load();
                if server.introspector.is_auth_required_for_walker(name) {
                    username = self._authenticate();
                    if not username {
                        Jac.send_json(self, 401, {'error': 'Unauthorized'});
                        return;
                    }
                } else {
                    username = self._authenticate();
                    if not username {
                        username = '__guest__';
                        if (username not in server.user_manager._users) {
                            server.user_manager.create_user(
                                username, '__no_password__'
                            );
                        }
                    }
                }
                fields = data | {'_jac_spawn_node': node_id};
                response = server.execution_handler.spawn_walker(
                    name, fields, username
                );
                self._send_response(response);
            } else {
                Jac.send_json(self, 404, {'error': 'Not found'});
            }
        }

        """Log HTTP requests."""
        def log_message(self: JacRequestHandler, format: str, *args: object) -> None {
            print(f"{self.address_string()} - {(format % args)}");
        }
    }
    return JacRequestHandler;
}

"""Load the target module (backward compatibility)."""
impl JacAPIServer.load_module(force_reload: bool = False) -> None {
    self.introspector.load(force_reload);
}

"""Get loaded module (backward compatibility)."""
impl JacAPIServer.module -> object {
    return self.introspector._module;
}

"""Get all functions (backward compatibility)."""
impl JacAPIServer.get_functions -> dict[str, Callable[(..., Any)]] {
    return self.introspector.get_functions();
}

"""Get all walkers (backward compatibility)."""
impl JacAPIServer.get_walkers -> dict[str, type[WalkerArchetype]] {
    return self.introspector.get_walkers();
}

"""Introspect callable (backward compatibility)."""
impl JacAPIServer.introspect_callable(func: Callable[(..., Any)]) -> dict[str, Any] {
    return self.introspector.introspect_callable(func);
}

"""Introspect walker (backward compatibility)."""
impl JacAPIServer.introspect_walker(
    walker_cls: type[WalkerArchetype]
) -> dict[str, Any] {
    return self.introspector.introspect_walker(walker_cls);
}

"""Render client page (backward compatibility)."""
impl JacAPIServer.render_client_page(
    function_name: str, args: dict[(str, Any)], username: str
) -> dict[str, Any] {
    return self.introspector.render_page(function_name, args, username);
}

"""Get client bundle code (backward compatibility)."""
impl JacAPIServer.get_client_bundle_code -> str {
    self.introspector.load();
    self.introspector.ensure_bundle();
    return self.introspector._bundle.code;
}

"""Print comprehensive documentation for all endpoints that would be generated."""
impl JacAPIServer.print_endpoint_docs -> None {
    print_endpoint_docs(self);
}

"""Start the HTTP server."""
impl JacAPIServer.start -> None {
    self.introspector.load();
    handler_class = self.create_handler();
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    base_route_app = config.serve.base_route_app if config else "";
    with HTTPServer(('0.0.0.0', self.port), handler_class) as httpd {
        print(f"Jac API Server running on http://0.0.0.0:{self.port}");
        print(f"Module: {self.module_name}");
        print(f"Session: {self.session_path}");
        print('\nAvailable endpoints:');
        print('  POST /user/register - Create a new user');
        print('  POST /user/login - Login and get auth token');
        print('  GET /functions - List all functions');
        print('  GET /walkers - List all walkers');
        print('  GET /function/<name> - Get function signature');
        print('  GET /walker/<name> - Get walker info');
        print('  POST /function/<name> - Call a function');
        print('  POST /walker/<name> - Spawn a walker');
        print(
            f'  GET /{cl_route_prefix}/<name> - Render HTML page for client function'
        );
        if base_route_app {
            print(f'\nBase route (/) configured to serve: {base_route_app}');
        }
        print('\nPress Ctrl+C to stop the server');
        try {
            httpd.serve_forever();
        } except KeyboardInterrupt {
            print('\nShutting down server...');
        }
    }
}

"""Print comprehensive documentation for all endpoints that would be generated."""
impl print_endpoint_docs(server: JacAPIServer) -> None {
    server.introspector.load();
    functions = server.introspector.get_functions();
    walkers = server.introspector.get_walkers();
    client_exports = server.introspector._client_manifest.get('exports', []);
    """Print section header.""";
    def section(title: str, auth: str = '') -> None {
        print(f"{title}{f' ({auth})' if auth else ''}{('-' * 80)}");
    }
    """Print endpoint with description.""";
    def endpoint(method: str, path: str, desc: str, details: str = '') -> None {
        print(f"{method:6} {path}");
        print(f"       {desc}");
        if details {
            print(f"       {details}");
        }
    }
    """Format parameter info.""";
    def format_param(name: str, info: dict[(str, Any)]) -> str {
        req = 'required' if info['required'] else 'optional';
        <>default = f", default: {info['default']}" if info.get('default') else '';
        return f"{name}: {info['type']} ({req}{default})";
    }
    print(('\n' + ('=' * 80)));
    print(f"JAC API SERVER - {server.module_name}");
    print(('=' * 80));
    section('AUTHENTICATION');
    endpoint(
        'POST',
        '/user/register',
        'Create new user account',
        'Body: { "username": str, "password": str }'
    );
    endpoint(
        'POST',
        '/user/login',
        'Authenticate and get token',
        'Body: { "username": str, "password": str }'
    );
    section('INTROSPECTION', 'Authenticated');
    endpoint('GET', '/functions', 'List all functions → string[]');
    endpoint('GET', '/walkers', 'List all walkers → string[]');
    if functions {
        section('FUNCTIONS', 'Authenticated');
        for (name, func) in functions.items() {
            sig = server.introspector.introspect_callable(func);
            params = [format_param(n, i) for (n, i) in sig['parameters'].items()];
            params_str = ', '.join(params) if params else 'none';
            endpoint('GET', f"/function/{name}", 'Get signature');
            endpoint(
                'POST',
                f"/function/{name}",
                f"Call function → {sig['return_type']}",
                f"Args: {{ {params_str} }}" if params else 'No arguments'
            );
        }
    }
    if walkers {
        section('WALKERS', 'Authenticated');
        for (name, walker_cls) in walkers.items() {
            info = server.introspector.introspect_walker(walker_cls);
            fields = [format_param(n, i) for (n, i) in info['fields'].items()];
            fields_str = ', '.join(fields[:3]);
            if (len(fields) > 3) {
                fields_str += f", ... (+{(len(fields) - 3)} more)";
            }
            endpoint('GET', f"/walker/{name}", 'Get walker fields');
            endpoint(
                'POST',
                f"/walker/{name}",
                'Spawn walker',
                f"Fields: {{ {fields_str} }}" if fields else 'No fields'
            );
        }
    }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    base_route_app = config.serve.base_route_app if config else "";
    section('CLIENT PAGES', 'Public');
    if client_exports {
        funcs_list = ', '.join(sorted(client_exports)[:8]);
        if (len(client_exports) > 8) {
            funcs_list += f" (+{(len(client_exports) - 8)} more)";
        }
        print(f"Available ({len(client_exports)}): {funcs_list}");
        endpoint(
            'GET',
            f'/{cl_route_prefix}/<name>',
            'Render HTML for client function',
            f'Example: /{cl_route_prefix}/App?arg1=value1'
        );
    } else {
        print(
            "\nNo client functions. Define with 'cl def' for browser-side rendering."
        );
    }
    section('STATIC');
    if base_route_app {
        endpoint('GET', '/', f'Serves client app: {base_route_app}');
    } else {
        endpoint('GET', '/', 'API information and endpoint list');
    }
    endpoint('GET', '/static/client.js', 'Client JavaScript bundle');
    total = 2 + 2 + (len(functions) * 2) + (len(walkers) * 2) + 2;
    print(('\n' + ('=' * 80)));
    print(
        f"TOTAL: {len(functions)} functions · {len(walkers)} walkers · {len(
            client_exports
        )} client functions · {total} endpoints"
    );
    print(('=' * 80));
    print('\nAuth: Bearer token (Authorization: Bearer <token>)\n');
}
