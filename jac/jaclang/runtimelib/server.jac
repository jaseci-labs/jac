"""REST API Server for Jac Programs."""
import hashlib;
import html;
import inspect;
import json;
import os;
import secrets;
import from collections.abc { Callable }
import from contextlib { suppress }
import from dataclasses { dataclass, field }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Any, Literal, TypeAlias, get_type_hints }
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang { JacRuntime as Jac }
with entry {
    if TYPE_CHECKING {
        import from jaclang.runtimelib.constructs { Archetype, WalkerArchetype }
    }
    JsonValue: TypeAlias = None | str | int | float | bool | <>list['JsonValue'] | <>dict[
        (str, 'JsonValue')
    ];
    StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];
}

"""Base response container."""
@dataclass(frozen=True, slots=True)
class Response {
    with entry {
        status: StatusCode;
        body: JsonValue;
        content_type: str = 'application/json';
    }
}

"""User authentication data."""
@dataclass(frozen=True, slots=True)
class UserData {
    with entry {
        username: str;
        token: str;
        root_id: str;
    }
}

"""Type-safe serializer for Jac objects."""
class JacSerializer {
    """Serialize objects to JSON-compatible format."""
    static def serialize(<>obj: object) -> JsonValue {
        import from jaclang.runtimelib.constructs { Archetype }
        if ((<>obj is None) or isinstance(<>obj, (str, int, float, bool))) {
            return <>obj;
        }
        if isinstance(<>obj, (<>list, <>tuple)) {
            return [JacSerializer.serialize(item) for item in <>obj];
        }
        if isinstance(<>obj, <>dict) {
            return {
                key: JacSerializer.serialize(value) for (key, value) in <>obj.items()
            };
        }
        if isinstance(<>obj, Archetype) {
            return JacSerializer._serialize_archetype(<>obj);
        }
        if hasattr(<>obj, '__dict__') {
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
    static def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue] {
        import from jaclang.runtimelib.constructs { NodeArchetype, WalkerArchetype }
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
}

"""Manage users and their persistent roots."""
@dataclass(slots=True)
class UserManager {
    with entry {
        session_path: str;
        _users: dict[(str, dict[(str, str)])] = field(
            default_factory=<>dict, <>init=False
        );
        _tokens: dict[(str, str)] = field(default_factory=<>dict, <>init=False);
        _db_path: str = field(<>init=False);
    }

    """Initialize user database."""
    def __post_init__(self: UserManager) -> None {
        self._db_path = f"{self.session_path}.users.json";
        self._load_db();
    }

    """Load user data from persistent storage."""
    def _load_db(self: UserManager) -> None {
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
    def _persist(self: UserManager) -> None {
        with open(self._db_path, 'w', encoding='utf-8') as fh {
            json.dump(
                {'__jac_users__': self._users, '__jac_tokens__': self._tokens}, fh
            );
        }
    }

    """Create a new user with their own root node. Returns dict with user data or error."""
    def create_user(self: UserManager, username: str, password: str) -> dict[str, str] {
        import from jaclang.runtimelib.constructs { Root }
        if (username in self._users) {
            return {'error': 'User already exists'};
        }
        ctx = Jac.create_j_context(session=self.session_path);
        Jac.set_context(ctx);
        try {
            user_root = Root();
            root_anchor = user_root.__jac__;
            Jac.save(root_anchor);
            Jac.commit(root_anchor);
            root_id = root_anchor.id.hex;
        } finally {
            ctx.mem.close();
            Jac.set_context(Jac.create_j_context());
        }
        token = secrets.token_urlsafe(32);
        password_hash = hashlib.sha256(password.encode()).hexdigest();
        self._users[username] = {
            'password_hash': password_hash,
            'token': token,
            'root_id': root_id
        };
        self._tokens[token] = username;
        self._persist();
        return {'email': username, 'token': token, 'root_id': root_id};
    }

    """Authenticate a user and return their data."""
    def authenticate(
        self: UserManager, username: str, password: str
    ) -> (dict[(str, str)] | None) {
        if (username not in self._users) {
            return None;
        }
        user = self._users[username];
        password_hash = hashlib.sha256(password.encode()).hexdigest();
        if (user['password_hash'] == password_hash) {
            return {
                'email': username,
                'token': user['token'],
                'root_id': user['root_id']
            };
        }
        return None;
    }

    """Validate token and return username."""
    def validate_token(self: UserManager, token: str) -> (str | None) {
        return self._tokens.get(token);
    }

    """Get user's root node ID."""
    def get_root_id(self: UserManager, username: str) -> (str | None) {
        return self._users[username]['root_id'] if (username in self._users) else None;
    }

    """Close and persist user data."""
    def close(self: UserManager) -> None {
        self._persist();
    }
}

"""Manages execution contexts for user operations."""
class ExecutionManager {
    """Initialize execution manager."""
    def __init__(
        self: ExecutionManager, session_path: str, user_manager: UserManager
    ) -> None {
        self.session_path = session_path;
        self.user_manager = user_manager;
    }

    """Execute a function in user's context."""
    def execute_function(
        self: ExecutionManager,
        func: Callable[(..., Any)],
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, JsonValue] {
        root_id = self.user_manager.get_root_id(username);
        if not root_id {
            return {'error': 'User not found'};
        }
        ctx = Jac.create_j_context(session=self.session_path, <>root=root_id);
        Jac.set_context(ctx);
        try {
            result = func(**args);
            Jac.commit();
            return {
                'result': JacSerializer.serialize(result),
                'reports': JacSerializer.serialize(ctx.reports)
            };
        } except Exception as e {
            return {'error': str(e)};
        } finally {
            ctx.mem.close();
            Jac.set_context(Jac.create_j_context());
        }
    }

    """Spawn a walker in user's context."""
    def spawn_walker(
        self: ExecutionManager,
        walker_cls: type[WalkerArchetype],
        fields: dict[(str, Any)],
        username: str
    ) -> dict[str, JsonValue] {
        import from jaclang.runtimelib.constructs { NodeArchetype }
        root_id = self.user_manager.get_root_id(username);
        if not root_id {
            return {'error': 'User not found'};
        }
        target_node_id = fields.pop('_jac_spawn_node', None);
        ctx = Jac.create_j_context(session=self.session_path, <>root=root_id);
        Jac.set_context(ctx);
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
            return {
                'result': JacSerializer.serialize(<>walker),
                'reports': JacSerializer.serialize(ctx.reports)
            };
        } except Exception as e {
            import traceback;
            return {'error': str(e), 'traceback': traceback.format_exc()};
        } finally {
            ctx.mem.close();
            Jac.set_context(Jac.create_j_context());
        }
    }
}

"""Introspects and caches module metadata."""
@dataclass(slots=True)
class ModuleIntrospector {
    with entry {
        module_name: str;
        base_path: (str | None);
        _module: Any = field(<>default=None, <>init=False);
        _functions: dict[(str, Callable[(..., Any)])] = field(
            default_factory=<>dict, <>init=False
        );
        _walkers: dict[(str, type[WalkerArchetype])] = field(
            default_factory=<>dict, <>init=False
        );
        _client_functions: dict[(str, Callable[(..., Any)])] = field(
            default_factory=<>dict, <>init=False
        );
        _client_manifest: dict[(str, Any)] = field(
            default_factory=<>dict, <>init=False
        );
        _bundle: Any = field(<>default=None, <>init=False);
        _bundle_error: (str | None) = field(<>default=None, <>init=False);
        _bundle_builder: Any = field(<>default=None, <>init=False);
        _function_access: dict[(str, bool)] = field(
            default_factory=<>dict, <>init=False
        );
        _walker_access: dict[(str, bool)] = field(default_factory=<>dict, <>init=False);
    }

    """Initialize bundle builder using plugin system."""
    def __post_init__(self: ModuleIntrospector) -> None {
        self._bundle_builder = Jac.get_client_bundle_builder();
    }

    """Load module and refresh caches."""
    def load(self: ModuleIntrospector, force_reload: bool = False) -> None {
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
    def _load_manifest(self: ModuleIntrospector) -> None {
        if not self._module {
            return;
        }
        mod_path = getattr(self._module, '__file__', None);
        if mod_path {
            mod = Jac.program.mod.hub.get(mod_path);
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
    def _extract_access_levels(self: ModuleIntrospector) -> None {
        if not self._module {
            return;
        }
        import jaclang.pycore.unitree as uni;
        import from jaclang.runtimelib.constructs { WalkerArchetype }
        self._function_access = {};
        self._walker_access = {};
        mod_path = getattr(self._module, '__file__', None);
        if not mod_path {
            return;
        }
        mod_ast = Jac.program.mod.hub.get(mod_path);
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
    def _collect_functions(self: ModuleIntrospector) -> dict[str, Callable[(..., Any)]] {
        if not self._module {
            return {};
        }
        functions: dict[(str, Callable[(..., Any)])] = {};
        export_names = <>set(self._client_manifest.get('exports', []));
        for (name, <>obj) in inspect.getmembers(self._module) {
            if (
                inspect.isfunction(<>obj)
                and not name.startswith('_')
                and (<>obj.__module__ == self._module.__name__)
            ) {
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
    def _collect_walkers(self: ModuleIntrospector) -> dict[str, type[WalkerArchetype]] {
        import from jaclang.runtimelib.constructs { WalkerArchetype }
        if not self._module {
            return {};
        }
        walkers: dict[(str, type[WalkerArchetype])] = {};
        for (name, <>obj) in inspect.getmembers(self._module) {
            if (
                isinstance(<>obj, <>type)
                and issubclass(<>obj, WalkerArchetype)
                and (<>obj is not WalkerArchetype)
                and (<>obj.__module__ == self._module.__name__)
            ) {
                walkers[name] = <>obj;
            }
        }
        return walkers;
    }

    """Get all functions."""
    def get_functions(self: ModuleIntrospector) -> dict[str, Callable[(..., Any)]] {
        if not self._functions {
            self.load();
        }
        return <>dict(self._functions);
    }

    """Get all walkers."""
    def get_walkers(self: ModuleIntrospector) -> dict[str, type[WalkerArchetype]] {
        if not self._walkers {
            self.load();
        }
        return <>dict(self._walkers);
    }

    """Get client-exportable functions."""
    def get_client_functions(
        self: ModuleIntrospector
    ) -> dict[str, Callable[(..., Any)]] {
        if not self._client_functions {
            self.load();
        }
        return <>dict(self._client_functions);
    }

    """Get callable signature information."""
    def introspect_callable(
        self: ModuleIntrospector, func: Callable[(..., Any)]
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
                    type_hints.get(name, Any),
                    '__name__',
                    str(type_hints.get(name, Any))
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
    def introspect_walker(
        self: ModuleIntrospector, walker_cls: type[WalkerArchetype]
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
                    type_hints.get(name, Any),
                    '__name__',
                    str(type_hints.get(name, Any))
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
    def ensure_bundle(self: ModuleIntrospector) -> str {
        if not self._module {
            raise RuntimeError('Module not loaded') ;
        }
        if self._bundle {
            return self._bundle.hash;
        }
        try {
            self._bundle = self._bundle_builder.build(self._module);
            self._bundle_error = None;
            return self._bundle.hash;
        } except ClientBundleError as exc {
            self._bundle = None;
            self._bundle_error = str(exc);
            raise exc from RuntimeError(self._bundle_error) ;
        }
    }

    """Render HTML page for client function."""
    def render_page(
        self: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, Any] {
        self.load();
        available_exports = (
            <>set(self._client_manifest.get('exports', []))
            or <>set(self.get_client_functions().keys())
        );
        if (function_name not in available_exports) {
            raise ValueError(f"Client function '{function_name}' not found") ;
        }
        bundle_hash = self.ensure_bundle();
        arg_order = <>list(
            self._client_manifest.get('params', {}).get(function_name, [])
        );
        globals_payload = {
            name: JacSerializer.serialize(value)
            for (name, value) in self._collect_client_globals().items()
        };
        initial_state = {
            'module': self._module.__name__ if self._module else self.module_name,
            'function': function_name,
            'args': {
                key: JacSerializer.serialize(value) for (key, value) in args.items()
            },
            'globals': globals_payload,
            'argOrder': arg_order
        };
        safe_initial_json = json.dumps(initial_state).replace('</', '<\\/');
        page = f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><title>{html.escape(
            function_name
        )}</title></head><body><div id="__jac_root"></div><script id="__jac_init__" type="application/json">{safe_initial_json}</script><script src="/static/client.js?hash={bundle_hash}" defer></script></body></html>';
        return {
            'html': page,
            'bundle_hash': bundle_hash,
            'bundle_code': self._bundle.code
        };
    }

    """Check if authentication is required for a function based on its access level.\n\n        Public functions: no authentication required\n        Protected/Private functions: authentication required\n        """
    def is_auth_required_for_function(self: ModuleIntrospector, func_name: str) -> bool {
        return self._function_access.get(func_name, False);
    }

    """Check if authentication is required for a walker based on its access level.\n\n        Public walkers: no authentication required\n        Protected/Private walkers: authentication required\n        """
    def is_auth_required_for_walker(self: ModuleIntrospector, walker_name: str) -> bool {
        return self._walker_access.get(walker_name, False);
    }

    """Collect client-exposed global values."""
    def _collect_client_globals(self: ModuleIntrospector) -> dict[str, Any] {
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
}

"""Build and send HTTP responses."""
class ResponseBuilder {
    """Send JSON response with CORS headers."""
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None {
        handler.send_response(status);
        handler.send_header('Content-Type', 'application/json');
        ResponseBuilder._add_cors_headers(handler);
        handler.end_headers();
        handler.wfile.write(json.dumps(data).encode());
    }

    """Send HTML response with CORS headers."""
    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None {
        payload = body.encode('utf-8');
        handler.send_response(status);
        handler.send_header('Content-Type', 'text/html; charset=utf-8');
        handler.send_header('Content-Length', str(len(payload)));
        ResponseBuilder._add_cors_headers(handler);
        handler.end_headers();
        handler.wfile.write(payload);
    }

    """Send JavaScript response."""
    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None {
        payload = code.encode('utf-8');
        handler.send_response(200);
        handler.send_header('Content-Type', 'application/javascript; charset=utf-8');
        handler.send_header('Content-Length', str(len(payload)));
        handler.send_header('Cache-Control', 'no-cache');
        ResponseBuilder._add_cors_headers(handler);
        handler.end_headers();
        handler.wfile.write(payload);
    }

    """Send CSS response."""
    static def send_css(handler: BaseHTTPRequestHandler, css: str) -> None {
        payload = css.encode('utf-8');
        handler.send_response(200);
        handler.send_header('Content-Type', 'text/css; charset=utf-8');
        handler.send_header('Content-Length', str(len(payload)));
        handler.send_header('Cache-Control', 'no-cache');
        ResponseBuilder._add_cors_headers(handler);
        handler.end_headers();
        handler.wfile.write(payload);
    }

    """Add CORS headers to response."""
    static def _add_cors_headers(handler: BaseHTTPRequestHandler) -> None {
        handler.send_header('Access-Control-Allow-Origin', '*');
        handler.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        handler.send_header(
            'Access-Control-Allow-Headers', 'Content-Type, Authorization'
        );
    }
}

"""Base route handler."""
class RouteHandler {
    """Initialize route handler."""
    def __init__(
        self: RouteHandler,
        introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager
    ) -> None {
        self.introspector = introspector;
        self.execution_manager = execution_manager;
        self.user_manager = user_manager;
    }
}

"""Handle authentication routes."""
class AuthHandler(RouteHandler) {
    """Create new user."""
    def create_user(self: AuthHandler, email: str, password: str) -> Response {
        if (not email or not password) {
            return Response(400, {'error': 'Email and password required'});
        }
        result = self.user_manager.create_user(email, password);
        if ('error' in result) {
            return Response(400, <>dict[(str, JsonValue)](result));
        }
        return Response(201, <>dict[(str, JsonValue)](result));
    }

    """Authenticate user."""
    def login(self: AuthHandler, email: str, password: str) -> Response {
        if (not email or not password) {
            return Response(400, {'error': 'Email and password required'});
        }
        result = self.user_manager.authenticate(email, password);
        if not result {
            return Response(401, {'error': 'Invalid credentials'});
        }
        return Response(200, <>dict[(str, JsonValue)](result));
    }
}

"""Handle introspection routes."""
class IntrospectionHandler(RouteHandler) {
    """List all functions."""
    def list_functions(self: IntrospectionHandler) -> Response {
        self.introspector.load();
        return Response(
            200, {'functions': <>list(self.introspector.get_functions().keys())}
        );
    }

    """List all walkers."""
    def list_walkers(self: IntrospectionHandler) -> Response {
        self.introspector.load();
        return Response(
            200, {'walkers': <>list(self.introspector.get_walkers().keys())}
        );
    }

    """Get function signature."""
    def get_function_info(self: IntrospectionHandler, name: str) -> Response {
        self.introspector.load();
        functions = self.introspector.get_functions();
        if (name not in functions) {
            return Response(404, {'error': f"Function '{name}' not found"});
        }
        signature = self.introspector.introspect_callable(functions[name]);
        return Response(200, {'name': name, 'signature': signature});
    }

    """Get walker info."""
    def get_walker_info(self: IntrospectionHandler, name: str) -> Response {
        self.introspector.load();
        walkers = self.introspector.get_walkers();
        if (name not in walkers) {
            return Response(404, {'error': f"Walker '{name}' not found"});
        }
        info = self.introspector.introspect_walker(walkers[name]);
        return Response(200, {'name': name, 'info': info});
    }
}

"""Handle execution routes."""
class ExecutionHandler(RouteHandler) {
    """Call a function."""
    def call_function(
        self: ExecutionHandler, name: str, args: dict[(str, Any)], username: str
    ) -> Response {
        self.introspector.load();
        functions = self.introspector.get_functions();
        if (name not in functions) {
            return Response(404, {'error': f"Function '{name}' not found"});
        }
        result = self.execution_manager.execute_function(
            functions[name], args, username
        );
        return Response(200, result);
    }

    """Spawn a walker."""
    def spawn_walker(
        self: ExecutionHandler, name: str, fields: dict[(str, Any)], username: str
    ) -> Response {
        self.introspector.load();
        walkers = self.introspector.get_walkers();
        if (name not in walkers) {
            return Response(404, {'error': f"Walker '{name}' not found"});
        }
        result = self.execution_manager.spawn_walker(walkers[name], fields, username);
        return Response(200, result);
    }
}

"""REST API Server for Jac programs."""
class JacAPIServer {
    """Initialize the API server."""
    def __init__(
        self: JacAPIServer,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: (str | None) = None
    ) -> None {
        self.module_name = module_name;
        self.session_path = session_path;
        self.port = port;
        self.base_path = base_path;
        self.user_manager = UserManager(session_path);
        self.introspector = Jac.get_module_introspector(module_name, base_path);
        self.execution_manager = ExecutionManager(session_path, self.user_manager);
        self.auth_handler = AuthHandler(
            self.introspector, self.execution_manager, self.user_manager
        );
        self.introspection_handler = IntrospectionHandler(
            self.introspector, self.execution_manager, self.user_manager
        );
        self.execution_handler = ExecutionHandler(
            self.introspector, self.execution_manager, self.user_manager
        );
    }

    """Create HTTP request handler."""
    def create_handler(self: JacAPIServer) -> type[BaseHTTPRequestHandler] {
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
                        Jac.send_json(self, 503, {'error': str(exc)});
                    }
                    return;
                }
                is_static_path = path.startswith('/static/');
                is_asset_file = (
                    not is_static_path
                    and (path != '/')
                    and not path.startswith('/page/')
                    and not path.startswith('/function/')
                    and not path.startswith('/walker/')
                    and not path.startswith('/user/')
                    and not path.startswith('/functions')
                    and not path.startswith('/walkers')
                    and not path.startswith('/protected')
                    and (
                        Path(path).suffix in {'.png','.jpg','.jpeg','.gif','.webp','.svg','.ico','.woff','.woff2','.ttf','.otf','.eot','.mp4','.webm','.mp3','.wav','.css'}
                    )
                );
                if (is_static_path or is_asset_file) {
                    try {
                        base_path = Path(Jac.base_path_dir)
                        if Jac.base_path_dir
                        else Path.cwd();
                        if is_static_path {
                            relative_path = path[8:];
                        } else {
                            relative_path = path[1:];
                        }
                        file_name = Path(relative_path).name;
                        dist_file = base_path / 'dist' / relative_path;
                        dist_file_simple = base_path / 'dist' / file_name;
                        assets_file = base_path / 'assets' / relative_path;
                        assets_file_simple = base_path / 'assets' / file_name;
                        if path.endswith('.css') {
                            if dist_file.exists() {
                                css_content = dist_file.read_text(encoding='utf-8');
                                Jac.send_css(self, css_content);
                                return;
                            } elif dist_file_simple.exists() {
                                css_content = dist_file_simple.read_text(
                                    encoding='utf-8'
                                );
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
                                Jac.send_json(
                                    self, 404, {'error': 'CSS file not found'}
                                );
                                return;
                            }
                        }
                        for candidate_file in [
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
                                'GET /page/<name>': 'Render HTML page for client function'
                            }
                        }
                    );
                    return;
                }
                if path.startswith('/page/') {
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
                            server.user_manager.create_user(
                                username, '__no_password__'
                            );
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
                        Jac.send_json(self, 503, {'error': str(exc)});
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
                    self._send_response(
                        server.introspection_handler.get_walker_info(name)
                    );
                    return;
                } elif (path == '/protected') {
                    username = self._authenticate();
                    if not username {
                        Jac.send_json(self, 401, {'error': 'Unauthorized'});
                        return;
                    }
                    self._send_response(Response(200, {'message': 'sucessful'}));
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
                        data.get('email', ''), data.get('password', '')
                    );
                    self._send_response(response);
                    return;
                }
                if (path == '/user/login') {
                    response = server.auth_handler.login(
                        data.get('email', ''), data.get('password', '')
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
            def log_message(
                self: JacRequestHandler, format: str, *args: object
            ) -> None {
                print(f"{self.address_string()} - {(format % args)}");
            }
        }
        return JacRequestHandler;
    }

    """Load the target module (backward compatibility)."""
    def load_module(self: JacAPIServer, force_reload: bool = False) -> None {
        self.introspector.load(force_reload);
    }

    """Get loaded module (backward compatibility)."""
    @property
    def module(self: JacAPIServer) -> object {
        return self.introspector._module;
    }

    """Get all functions (backward compatibility)."""
    def get_functions(self: JacAPIServer) -> dict[str, Callable[(..., Any)]] {
        return self.introspector.get_functions();
    }

    """Get all walkers (backward compatibility)."""
    def get_walkers(self: JacAPIServer) -> dict[str, type[WalkerArchetype]] {
        return self.introspector.get_walkers();
    }

    """Introspect callable (backward compatibility)."""
    def introspect_callable(
        self: JacAPIServer, func: Callable[(..., Any)]
    ) -> dict[str, Any] {
        return self.introspector.introspect_callable(func);
    }

    """Introspect walker (backward compatibility)."""
    def introspect_walker(
        self: JacAPIServer, walker_cls: type[WalkerArchetype]
    ) -> dict[str, Any] {
        return self.introspector.introspect_walker(walker_cls);
    }

    """Render client page (backward compatibility)."""
    def render_client_page(
        self: JacAPIServer, function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any] {
        return self.introspector.render_page(function_name, args, username);
    }

    """Get client bundle code (backward compatibility)."""
    def get_client_bundle_code(self: JacAPIServer) -> str {
        self.introspector.load();
        self.introspector.ensure_bundle();
        return self.introspector._bundle.code;
    }

    """Print comprehensive documentation for all endpoints that would be generated."""
    def print_endpoint_docs(self: JacAPIServer) -> None {
        print_endpoint_docs(self);
    }

    """Start the HTTP server."""
    def start(self: JacAPIServer) -> None {
        self.introspector.load();
        handler_class = self.create_handler();
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
            print('\nPress Ctrl+C to stop the server');
            try {
                httpd.serve_forever();
            } except KeyboardInterrupt {
                print('\nShutting down server...');
            }
        }
    }
}

"""Print comprehensive documentation for all endpoints that would be generated."""
def print_endpoint_docs(server: JacAPIServer) -> None {
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
        'Body: { "email": str, "password": str }'
    );
    endpoint(
        'POST',
        '/user/login',
        'Authenticate and get token',
        'Body: { "email": str, "password": str }'
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
    section('CLIENT PAGES', 'Public');
    if client_exports {
        funcs_list = ', '.join(sorted(client_exports)[:8]);
        if (len(client_exports) > 8) {
            funcs_list += f" (+{(len(client_exports) - 8)} more)";
        }
        print(f"Available ({len(client_exports)}): {funcs_list}");
        endpoint(
            'GET',
            '/page/<name>',
            'Render HTML for client function',
            'Example: /page/App?arg1=value1'
        );
    } else {
        print(
            "\nNo client functions. Define with 'cl def' for browser-side rendering."
        );
    }
    section('STATIC');
    endpoint('GET', '/', 'API information and endpoint list');
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
