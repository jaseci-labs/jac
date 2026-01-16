"""Serialize objects to JSON-compatible format."""
impl JacSerializer.serialize(<>obj: object) -> JsonValue {
    import from jaclang.pycore.constructs { Archetype }
    if ((<>obj is None) or isinstance(<>obj, (str, int, float, bool))) {
        return <>obj;
    }
    if isinstance(<>obj, (<>list, <>tuple)) {
        return [JacSerializer.serialize(item) for item in <>obj];
    }
    if isinstance(<>obj, <>dict) {
        return {key: JacSerializer.serialize(value) for (key, value) in <>obj.items()};
    }
    if isinstance(<>obj, Archetype) {
        return JacSerializer._serialize_archetype(<>obj);
    }
    if <>obj?.__dict__ {
        with suppress(Exception) {
            return JacSerializer.serialize(
                {
                    k: v
                    for (k, v) in <>obj.__dict__.items()
                    if not k.startswith('_')
                }
            );
        }
    }
    return str(<>obj);
}

"""Serialize Archetype instances."""
impl JacSerializer._serialize_archetype(arch: Archetype) -> dict[str, JsonValue] {
    import from jaclang.pycore.constructs { NodeArchetype, WalkerArchetype }
    result: dict[(str, JsonValue)] = {
        '_jac_type': <>type(arch).__name__,
        '_jac_id': arch.__jac__.id.hex,
        '_jac_archetype': 'node'
        if isinstance(arch, NodeArchetype)
        else 'walker' if isinstance(arch, WalkerArchetype) else 'archetype'
    };
    for attr_name in dir(arch) {
        if (not attr_name.startswith('_') and (attr_name != '__jac__')) {
            with suppress(Exception) {
                attr_value = getattr(arch, attr_name);
                if not callable(attr_value) {
                    result[attr_name] = JacSerializer.serialize(attr_value);
                }
            }
        }
    }
    return result;
}

impl UserManager.postinit -> None {
    data_dir = os.path.join(self.base_path, ".jac", "data");
    os.makedirs(data_dir, exist_ok=True);
    self._db_path = os.path.join(data_dir, "users.json");
    self._load_db();
}

"""Load user data from persistent storage."""
impl UserManager._load_db -> None {
    try {
        with open(self._db_path, encoding='utf-8') as fh {
            data = json.load(fh);
            self._users = data.get('__jac_users__', {});
            self._tokens = data.get('__jac_tokens__', {});
        }
    } except Exception {
        (self._users, self._tokens) = ({}, {});
    }
}

"""Save user data to persistent storage."""
impl UserManager._persist -> None {
    with open(self._db_path, 'w', encoding='utf-8') as fh {
        json.dump({'__jac_users__': self._users, '__jac_tokens__': self._tokens}, fh);
    }
}

"""Create a new user with their own root node. Returns dict with user data or error."""
impl UserManager.create_user(username: str, password: str) -> dict[str, str] {
    import from jaclang.pycore.constructs { Root }
    if (username in self._users) {
        return {'error': 'User already exists'};
    }
    # Use existing context instead of creating new one (avoids shelf locking issues)
    ctx = Jac.get_context();
    user_root = Root();
    root_anchor = user_root.__jac__;
    Jac.save(root_anchor);
    Jac.commit(root_anchor);
    root_id = root_anchor.id.hex;
    token = secrets.token_urlsafe(32);
    password_hash = hashlib.sha256(password.encode()).hexdigest();
    self._users[username] = {
        'password_hash': password_hash,
        'token': token,
        'root_id': root_id
    };
    self._tokens[token] = username;
    self._persist();
    return {'username': username, 'token': token, 'root_id': root_id};
}

"""Authenticate a user and return their data."""
impl UserManager.authenticate(
    username: str, password: str
) -> (dict[(str, str)] | None) {
    if (username not in self._users) {
        return None;
    }
    user = self._users[username];
    password_hash = hashlib.sha256(password.encode()).hexdigest();
    if (user['password_hash'] == password_hash) {
        return {
            'username': username,
            'token': user['token'],
            'root_id': user['root_id']
        };
    }
    return None;
}

"""Validate token and return username."""
impl UserManager.validate_token(token: str) -> (str | None) {
    return self._tokens.get(token);
}

"""Get user's root node ID."""
impl UserManager.get_root_id(username: str) -> (str | None) {
    return self._users[username]['root_id'] if (username in self._users) else None;
}

"""Get user data by username."""
impl UserManager.get_user(username: str) -> (dict[(str, str)] | None) {
    if (username not in self._users) {
        return None;
    }
    user = self._users[username];
    return {'email': username, 'token': user['token'], 'root_id': user['root_id']};
}

"""Close and persist user data."""
impl UserManager.close -> None {
    self._persist();
}

"""Execute a function in user's context."""
impl ExecutionManager.execute_function(
    func: Callable[(..., Any)], args: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return {'error': 'User not found'};
    }
    # Set user context for permission checks and ownership
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    ctx.reports = [];  # Clear reports for this request
    try {
        result = func(**args);
        Jac.commit();
        return {
            'result': JacSerializer.serialize(result),
            'reports': JacSerializer.serialize(ctx.reports)
        };
    } except Exception as e {
        return {'error': str(e)};
    }
}

"""Spawn a walker in user's context."""
impl ExecutionManager.spawn_walker(
    walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.pycore.constructs { NodeArchetype }
    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return {'error': 'User not found'};
    }
    target_node_id = fields.pop('_jac_spawn_node', None);
    # Set user context for permission checks and ownership
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    ctx.reports = [];  # Clear reports for this request
    try {
        <>walker = walker_cls(**fields);
        if target_node_id {
            target_node = Jac.get_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        Jac.spawn(<>walker, target_node);
        Jac.commit();  # Persist changes
        return {
            'result': JacSerializer.serialize(<>walker),
            'reports': JacSerializer.serialize(ctx.reports)
        };
    } except Exception as e {
        import traceback;
        return {'error': str(e), 'traceback': traceback.format_exc()};
    }
}

impl ModuleIntrospector.postinit -> None {
    self._bundle_builder = Jac.get_client_bundle_builder();
}

"""Load module and refresh caches."""
impl ModuleIntrospector.load(force_reload: bool = False) -> None {
    needs_import = force_reload or (self.module_name not in Jac.loaded_modules);
    if (needs_import and self.base_path) {
        Jac.jac_import(
            target=self.module_name,
            base_path=os.path.abspath(self.base_path),
            lng='jac',
            reload_module=force_reload
        );
    }
    module = Jac.loaded_modules.get(self.module_name);
    if (not module or ((self._module is module) and not needs_import)) {
        return;
    }
    self._module = module;
    self._load_manifest();
    self._extract_access_levels();
    self._functions = self._collect_functions();
    self._walkers = self._collect_walkers();
    self._bundle = None;
    self._bundle_error = None;
}

"""Load client manifest from module."""
impl ModuleIntrospector._load_manifest -> None {
    if not self._module {
        return;
    }
    mod_path = getattr(self._module, '__file__', None);
    if mod_path {
        mod = Jac.program.mod.hub.get(mod_path);
        # If module not in hub, compile it to get the manifest
        if not mod {
            mod = Jac.program.compile(mod_path);
        }
        if (mod and mod.gen.client_manifest) {
            manifest = mod.gen.client_manifest;
            self._client_manifest = {
                'exports': manifest.exports,
                'globals': manifest.globals,
                'params': manifest.params,
                'globals_values': manifest.globals_values,
                'has_client': manifest.has_client
            };
            return;
        }
    }
    self._client_manifest = {};
}

"""Extract access level information from module AST."""
impl ModuleIntrospector._extract_access_levels -> None {
    if not self._module {
        return;
    }
    import jaclang.pycore.unitree as uni;
    import from jaclang.pycore.constructs { WalkerArchetype }
    self._function_access = {};
    self._walker_access = {};
    mod_path = getattr(self._module, '__file__', None);
    if not mod_path {
        return;
    }
    mod_ast = Jac.program.mod.hub.get(mod_path);
    # If module not in hub, compile it to get the AST
    if not mod_ast {
        mod_ast = Jac.program.compile(mod_path);
    }
    if not mod_ast {
        return;
    }
    for item in mod_ast.body {
        if (isinstance(item, uni.Ability) and (item.name_ref is not None)) {
            func_name = item.name_ref.sym_name;
            self._function_access[func_name] = not item.public_access;
        } elif isinstance(item, uni.Archetype) {
            arch_name = item.name.sym_name;
            if hasattr(self._module, arch_name) {
                cls = getattr(self._module, arch_name);
                if (isinstance(cls, <>type) and issubclass(cls, WalkerArchetype)) {
                    self._walker_access[arch_name] = not item.public_access;
                }
            }
        }
    }
}

"""Collect callable functions from module."""
impl ModuleIntrospector._collect_functions -> dict[str, Callable[(..., Any)]] {
    if not self._module {
        return {};
    }
    functions: dict[(str, Callable[(..., Any)])] = {};
    export_names = <>set(self._client_manifest.get('exports', []));
    for (name, <>obj) in inspect.getmembers(self._module) {
        if (inspect.isfunction(<>obj) and not name.startswith('_')) {
            functions[name] = <>obj;
            if (name in export_names) {
                self._client_functions[name] = <>obj;
            }
        }
    }
    for name in export_names {
        if ((name not in self._client_functions) and hasattr(self._module, name)) {
            attr = getattr(self._module, name);
            if callable(attr) {
                self._client_functions[name] = attr;
            }
        }
    }
    return functions;
}

"""Collect walker classes from module."""
impl ModuleIntrospector._collect_walkers -> dict[str, type[WalkerArchetype]] {
    import from jaclang.pycore.constructs { WalkerArchetype }
    if not self._module {
        return {};
    }
    walkers: dict[(str, type[WalkerArchetype])] = {};
    for (name, <>obj) in inspect.getmembers(self._module) {
        if (
            isinstance(<>obj, <>type)
            and issubclass(<>obj, WalkerArchetype)
            and (<>obj is not WalkerArchetype)
        ) {
            walkers[name] = <>obj;
        }
    }
    return walkers;
}

"""Check if the module has been reloaded (e.g., by HMR) and refresh if needed."""
impl ModuleIntrospector._check_module_freshness -> None {
    if not self._module {
        return;
    }
    # Check if any cached walker class is stale (different from what's in the module)
    # This handles the case where importlib.reload() updates the module in place
    needs_refresh = False;
    for (name, cached_cls) in self._walkers.items() {
        current_cls = getattr(self._module, name, None);
        if current_cls is not cached_cls {
            needs_refresh = True;
            break;
        }
    }
    if needs_refresh {
        # Module was reloaded, refresh our caches
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._bundle = None;
        self._bundle_error = None;
    }
}

"""Get all functions."""
impl ModuleIntrospector.get_functions -> dict[str, Callable[(..., Any)]] {
    if not self._functions {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return <>dict(self._functions);
}

"""Get all walkers."""
impl ModuleIntrospector.get_walkers -> dict[str, type[WalkerArchetype]] {
    if not self._walkers {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return <>dict(self._walkers);
}

"""Get client-exportable functions."""
impl ModuleIntrospector.get_client_functions -> dict[str, Callable[(..., Any)]] {
    if not self._client_functions {
        self.load();
    }
    return <>dict(self._client_functions);
}

"""Get callable signature information."""
impl ModuleIntrospector.introspect_callable(
    func: Callable[(..., Any)]
) -> dict[str, Any] {
    try {
        sig = inspect.signature(func);
        type_hints = get_type_hints(func);
    } except Exception {
        return {'parameters': {}, 'return_type': 'Any'};
    }
    params = {
        name: {
            'type': getattr(
                type_hints.get(name, Any), '__name__', str(type_hints.get(name, Any))
            ),
            'required': (param.default == inspect.Parameter.empty),
            'default': None
            if (param.default == inspect.Parameter.empty)
            else str(param.default)
        } for (name, param) in sig.parameters.items()
    };
    return_type = type_hints.get('return', Any);
    return {
        'parameters': params,
        'return_type': getattr(return_type, '__name__', str(return_type))
    };
}

"""Get walker field information."""
impl ModuleIntrospector.introspect_walker(
    walker_cls: type[WalkerArchetype]
) -> dict[str, Any] {
    try {
        sig = inspect.signature(walker_cls.init);
        type_hints = get_type_hints(walker_cls.init);
    } except Exception {
        return {'fields': {}};
    }
    fields = {
        name: {
            'type': getattr(
                type_hints.get(name, Any), '__name__', str(type_hints.get(name, Any))
            ),
            'required': (param.default == inspect.Parameter.empty),
            'default': None
            if (param.default == inspect.Parameter.empty)
            else param.default
        }
        for (name, param) in sig.parameters.items()
        if (name not in ('self', 'args', 'kwargs'))
    };
    fields['_jac_spawn_node'] = {
        'type': 'str (node ID, optional)',
        'required': False,
        'default': 'root'
    };
    return {'fields': fields};
}

"""Ensure client bundle is available and return hash."""
impl ModuleIntrospector.ensure_bundle -> str {
    if not self._module {
        raise RuntimeError('Module not loaded') ;
    }
    if self._bundle {
        return self._bundle.hash;
    }
    # Don't retry if we already have a cached error
    if self._bundle_error {
        raise ClientBundleError(self._bundle_error) ;
    }
    try {
        self._bundle = self._bundle_builder.build(self._module);
        self._bundle_error = None;
        return self._bundle.hash;
    } except Exception as exc {
        self._bundle = None;
        self._bundle_error = str(exc);
        raise ClientBundleError(self._bundle_error) ;
    }
}

"""Render HTML page for client function."""
impl ModuleIntrospector.render_page(
    function_name: str, args: dict[(str, Any)], username: str
) -> dict[str, Any] {
    return Jac.render_page(self, function_name, args, username);
}

"""Check if authentication is required for a function based on its access level.

Public functions: no authentication required
Protected/Private functions: authentication required
"""
impl ModuleIntrospector.is_auth_required_for_function(func_name: str) -> bool {
    return self._function_access.get(func_name, False);
}

"""Check if authentication is required for a walker based on its access level.

Public walkers: no authentication required
Protected/Private walkers: authentication required
"""
impl ModuleIntrospector.is_auth_required_for_walker(walker_name: str) -> bool {
    return self._walker_access.get(walker_name, False);
}

"""Collect client-exposed global values."""
impl ModuleIntrospector._collect_client_globals -> dict[str, Any] {
    if not self._module {
        return {};
    }
    result: dict[(str, Any)] = {};
    names = self._client_manifest.get('globals', []);
    values_map = self._client_manifest.get('globals_values', {});
    for name in names {
        if (name in values_map) {
            result[name] = values_map[name];
        } elif hasattr(self._module, name) {
            result[name] = getattr(self._module, name);
        } else {
            result[name] = None;
        }
    }
    return result;
}

"""Send JSON response with CORS headers."""
impl ResponseBuilder.send_json(
    handler: BaseHTTPRequestHandler, status: StatusCode, data: dict[(str, JsonValue)]
) -> None {
    handler.send_response(status);
    handler.send_header('Content-Type', 'application/json');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(json.dumps(data).encode());
}

"""Send HTML response with CORS headers."""
impl ResponseBuilder.send_html(
    handler: BaseHTTPRequestHandler, status: StatusCode, body: str
) -> None {
    payload = body.encode('utf-8');
    handler.send_response(status);
    handler.send_header('Content-Type', 'text/html; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Send JavaScript response."""
impl ResponseBuilder.send_javascript(
    handler: BaseHTTPRequestHandler, code: str
) -> None {
    payload = code.encode('utf-8');
    handler.send_response(200);
    handler.send_header('Content-Type', 'application/javascript; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    handler.send_header('Cache-Control', 'no-cache');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Send CSS response."""
impl ResponseBuilder.send_css(handler: BaseHTTPRequestHandler, css: str) -> None {
    payload = css.encode('utf-8');
    handler.send_response(200);
    handler.send_header('Content-Type', 'text/css; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    handler.send_header('Cache-Control', 'no-cache');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Add CORS headers to response."""
impl ResponseBuilder._add_cors_headers(handler: BaseHTTPRequestHandler) -> None {
    handler.send_header('Access-Control-Allow-Origin', '*');
    handler.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    handler.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

"""Add security headers to response."""
impl ResponseBuilder._add_custom_headers(handler: BaseHTTPRequestHandler) -> None {
    config = get_config();
    if config
    and config.environments
    and "response" in config.environments
    and "headers" in config.environments["response"] {
        for (header_name, header_value) in config.environments["response"]["headers"].items() {
            handler.send_header(header_name, header_value);
        }
    }
}

"""Create new user."""
impl AuthHandler.create_user(username: str, password: str) -> TransportResponse {
    if (not username or not password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.create_user(username, password);
    if ('error' in result) {
        return TransportResponse.fail(
            code='USER_EXISTS',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
    );
}

"""Authenticate user."""
impl AuthHandler.login(username: str, password: str) -> TransportResponse {
    if (not username or not password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.authenticate(username, password);
    if not result {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid credentials',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

"""List all functions."""
impl IntrospectionHandler.list_functions -> TransportResponse {
    self.introspector.load();
    return TransportResponse.success(
        data={'functions': <>list(self.introspector.get_functions().keys())},
        meta=Meta(extra={'http_status': 200})
    );
}

"""List all walkers."""
impl IntrospectionHandler.list_walkers -> TransportResponse {
    self.introspector.load();
    return TransportResponse.success(
        data={'walkers': <>list(self.introspector.get_walkers().keys())},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Get function signature."""
impl IntrospectionHandler.get_function_info(name: str) -> TransportResponse {
    self.introspector.load();
    functions = self.introspector.get_functions();
    if (name not in functions) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Function '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    signature = self.introspector.introspect_callable(functions[name]);
    return TransportResponse.success(
        data={'name': name, 'signature': signature},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Get walker info."""
impl IntrospectionHandler.get_walker_info(name: str) -> TransportResponse {
    self.introspector.load();
    walkers = self.introspector.get_walkers();
    if (name not in walkers) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Walker '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    info = self.introspector.introspect_walker(walkers[name]);
    return TransportResponse.success(
        data={'name': name, 'info': info}, meta=Meta(extra={'http_status': 200})
    );
}

"""Call a function."""
impl ExecutionHandler.call_function(
    name: str, args: dict[(str, Any)], username: str
) -> TransportResponse {
    self.introspector.load();
    functions = self.introspector.get_functions();
    if (name not in functions) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Function '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    result = self.execution_manager.execute_function(functions[name], args, username);
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

"""Spawn a walker."""
impl ExecutionHandler.spawn_walker(
    name: str, fields: dict[(str, Any)], username: str
) -> TransportResponse {
    self.introspector.load();
    walkers = self.introspector.get_walkers();
    if (name not in walkers) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Walker '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    result = self.execution_manager.spawn_walker(walkers[name], fields, username);
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

"""Initialize the API server."""
impl JacAPIServer.postinit -> None {
    self.user_manager = UserManager(base_path=self.base_path);
    self.introspector = ModuleIntrospector(self.module_name, self.base_path);
    self.execution_manager = ExecutionManager(
        base_path=self.base_path, user_manager=self.user_manager
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
    self.server = Jac.create_server(self, '0.0.0.0', self.port);
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

        """Send response to client (supports both Response and TransportResponse).

        Uses HTTPTransport to demonstrate transport abstraction layer.
        """
        def _send_response(
            self: JacRequestHandler, response: (Response | TransportResponse)
        ) -> None {
            # Handle legacy Response objects for backward compatibility
            if isinstance(response, Response) {
                Jac.send_json(self, response.status, response.body);
            } else {
                transport = HTTPTransport(handler=self);
                transport.send(response);
            }
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
                    TransportResponse.success(
                        data={'message': 'sucessful'},
                        meta=Meta(extra={'http_status': 200})
                    )
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
    # Eagerly build client bundle if there are client exports
    client_exports = self.introspector._client_manifest.get('exports', []);
    if client_exports {
        import time;
        print("Building client bundle...", flush=True);
        start_time = time.time();
        try {
            self.introspector.ensure_bundle();
            elapsed = time.time() - start_time;
            print(f"Client bundle ready ({elapsed:.1f}s).");
        } except Exception as e {
            import sys;
            print(f"\n[ERROR] Failed to build client bundle:", file=sys.stderr);
            print(f"{e}", file=sys.stderr);
            print(
                f"\nClient pages will not be available until this is fixed.\n",
                file=sys.stderr
            );
        }
    }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    base_route_app = config.serve.base_route_app if config else "";
    with self.server as httpd {
        print(f"Jac API Server running on http://0.0.0.0:{self.port}");
        print(f"Module: {self.module_name}");
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
