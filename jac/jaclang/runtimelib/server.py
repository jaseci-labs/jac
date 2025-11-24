"""REST API Server for Jac Programs."""

from __future__ import annotations

import hashlib
import html
import inspect
import json
import os
import secrets
from contextlib import suppress
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Callable, Literal, TypeAlias, get_type_hints
from urllib.parse import parse_qs, urlparse

from jaclang.runtimelib.client_bundle import ClientBundleError
from jaclang.runtimelib.constructs import (
    Archetype,
    NodeArchetype,
    Root,
    WalkerArchetype,
)
from jaclang.runtimelib.machine import ExecutionContext, JacMachine as Jac

# Type Aliases
JsonValue: TypeAlias = (
    None | str | int | float | bool | list["JsonValue"] | dict[str, "JsonValue"]
)
StatusCode: TypeAlias = Literal[200, 201, 400, 401, 404, 500, 503]


# Response Models
@dataclass(frozen=True, slots=True)
class Response:
    """Base response container."""

    status: StatusCode
    body: JsonValue
    content_type: str = "application/json"


@dataclass(frozen=True, slots=True)
class UserData:
    """User authentication data."""

    username: str
    token: str
    root_id: str


# Core Serializer
class JacSerializer:
    """Type-safe serializer for Jac objects."""

    @staticmethod
    def serialize(obj: object) -> JsonValue:
        """Serialize objects to JSON-compatible format."""
        if obj is None or isinstance(obj, (str, int, float, bool)):
            return obj

        if isinstance(obj, (list, tuple)):
            return [JacSerializer.serialize(item) for item in obj]

        if isinstance(obj, dict):
            return {key: JacSerializer.serialize(value) for key, value in obj.items()}

        if isinstance(obj, Archetype):
            return JacSerializer._serialize_archetype(obj)

        if hasattr(obj, "__dict__"):
            with suppress(Exception):
                return JacSerializer.serialize(
                    {k: v for k, v in obj.__dict__.items() if not k.startswith("_")}
                )

        return str(obj)

    @staticmethod
    def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue]:
        """Serialize Archetype instances."""
        result: dict[str, JsonValue] = {
            "_jac_type": type(arch).__name__,
            "_jac_id": arch.__jac__.id.hex,
            "_jac_archetype": (
                "node"
                if isinstance(arch, NodeArchetype)
                else "walker" if isinstance(arch, WalkerArchetype) else "archetype"
            ),
        }

        for attr_name in dir(arch):
            if not attr_name.startswith("_") and attr_name != "__jac__":
                with suppress(Exception):
                    attr_value = getattr(arch, attr_name)
                    if not callable(attr_value):
                        result[attr_name] = JacSerializer.serialize(attr_value)

        return result


# User Management
@dataclass(slots=True)
class UserManager:
    """Manage users and their persistent roots."""

    session_path: str
    _users: dict[str, dict[str, str]] = field(default_factory=dict, init=False)
    _tokens: dict[str, str] = field(default_factory=dict, init=False)
    _db_path: str = field(init=False)

    def __post_init__(self) -> None:
        """Initialize user database."""
        self._db_path = f"{self.session_path}.users.json"
        self._load_db()

    def _load_db(self) -> None:
        """Load user data from persistent storage."""
        try:
            with open(self._db_path, encoding="utf-8") as fh:
                data = json.load(fh)
                self._users = data.get("__jac_users__", {})
                self._tokens = data.get("__jac_tokens__", {})
        except Exception:
            self._users, self._tokens = {}, {}

    def _persist(self) -> None:
        """Save user data to persistent storage."""
        with open(self._db_path, "w", encoding="utf-8") as fh:
            json.dump(
                {"__jac_users__": self._users, "__jac_tokens__": self._tokens}, fh
            )

    def create_user(self, username: str, password: str) -> dict[str, str]:
        """Create a new user with their own root node. Returns dict with user data or error."""
        if username in self._users:
            return {"error": "User already exists"}

        ctx = ExecutionContext(session=self.session_path)
        Jac.set_context(ctx)

        try:
            user_root = Root()
            root_anchor = user_root.__jac__
            Jac.save(root_anchor)
            Jac.commit(root_anchor)
            root_id = root_anchor.id.hex
        finally:
            ctx.mem.close()
            Jac.set_context(ExecutionContext())

        token = secrets.token_urlsafe(32)
        password_hash = hashlib.sha256(password.encode()).hexdigest()

        self._users[username] = {
            "password_hash": password_hash,
            "token": token,
            "root_id": root_id,
        }
        self._tokens[token] = username
        self._persist()

        return {"username": username, "token": token, "root_id": root_id}

    def authenticate(self, username: str, password: str) -> dict[str, str] | None:
        """Authenticate a user and return their data."""
        if username not in self._users:
            return None

        user = self._users[username]
        password_hash = hashlib.sha256(password.encode()).hexdigest()

        if user["password_hash"] == password_hash:
            return {
                "username": username,
                "token": user["token"],
                "root_id": user["root_id"],
            }
        return None

    def validate_token(self, token: str) -> str | None:
        """Validate token and return username."""
        return self._tokens.get(token)

    def get_root_id(self, username: str) -> str | None:
        """Get user's root node ID."""
        return self._users[username]["root_id"] if username in self._users else None

    def close(self) -> None:
        """Close and persist user data."""
        self._persist()


# Execution Context Manager
class ExecutionManager:
    """Manages execution contexts for user operations."""

    def __init__(self, session_path: str, user_manager: UserManager) -> None:
        """Initialize execution manager."""
        self.session_path = session_path
        self.user_manager = user_manager

    def execute_function(
        self, func: Callable[..., Any], args: dict[str, Any], username: str
    ) -> dict[str, JsonValue]:
        """Execute a function in user's context."""
        root_id = self.user_manager.get_root_id(username)
        if not root_id:
            return {"error": "User not found"}

        ctx = ExecutionContext(session=self.session_path, root=root_id)
        Jac.set_context(ctx)

        try:
            result = func(**args)
            Jac.commit()
            return {
                "result": JacSerializer.serialize(result),
                "reports": JacSerializer.serialize(ctx.reports),
            }
        except Exception as e:
            return {"error": str(e)}
        finally:
            ctx.mem.close()
            Jac.set_context(ExecutionContext())

    def spawn_walker(
        self, walker_cls: type[WalkerArchetype], fields: dict[str, Any], username: str
    ) -> dict[str, JsonValue]:
        """Spawn a walker in user's context."""
        root_id = self.user_manager.get_root_id(username)
        if not root_id:
            return {"error": "User not found"}

        target_node_id = fields.pop("_jac_spawn_node", None)
        ctx = ExecutionContext(session=self.session_path, root=root_id)
        Jac.set_context(ctx)

        try:
            walker = walker_cls(**fields)

            if target_node_id:
                target_node = Jac.get_object(target_node_id)
                if not isinstance(target_node, NodeArchetype):
                    return {"error": f"Invalid target node: {target_node_id}"}
            else:
                target_node = ctx.get_root()

            Jac.spawn(walker, target_node)
            Jac.commit()

            return {
                "result": JacSerializer.serialize(walker),
                "reports": JacSerializer.serialize(ctx.reports),
            }
        except Exception as e:
            import traceback

            return {"error": str(e), "traceback": traceback.format_exc()}
        finally:
            ctx.mem.close()
            Jac.set_context(ExecutionContext())


# Module Introspector
@dataclass(slots=True)
class ModuleIntrospector:
    """Introspects and caches module metadata."""

    module_name: str
    base_path: str | None
    _module: Any = field(default=None, init=False)
    _functions: dict[str, Callable[..., Any]] = field(default_factory=dict, init=False)
    _walkers: dict[str, type[WalkerArchetype]] = field(default_factory=dict, init=False)
    _client_functions: dict[str, Callable[..., Any]] = field(
        default_factory=dict, init=False
    )
    _client_manifest: dict[str, Any] = field(default_factory=dict, init=False)
    _bundle: Any = field(default=None, init=False)
    _bundle_error: str | None = field(default=None, init=False)
    _bundle_builder: Any = field(default=None, init=False)
    _function_access: dict[str, bool] = field(default_factory=dict, init=False)
    _walker_access: dict[str, bool] = field(default_factory=dict, init=False)

    def __post_init__(self) -> None:
        """Initialize bundle builder using plugin system."""
        # Use plugin system to get bundle builder (allows override)
        self._bundle_builder = Jac.get_client_bundle_builder()

    def load(self, force_reload: bool = False) -> None:
        """Load module and refresh caches."""
        needs_import = force_reload or self.module_name not in Jac.loaded_modules

        if needs_import and self.base_path:
            Jac.jac_import(
                target=self.module_name,
                base_path=os.path.abspath(self.base_path),
                lng="jac",
                reload_module=force_reload,
            )

        module = Jac.loaded_modules.get(self.module_name)
        if not module or self._module is module and not needs_import:
            return

        self._module = module
        self._load_manifest()
        self._extract_access_levels()
        self._functions = self._collect_functions()
        self._walkers = self._collect_walkers()
        self._bundle = None
        self._bundle_error = None

    def _load_manifest(self) -> None:
        """Load client manifest from module."""
        if not self._module:
            return

        mod_path = getattr(self._module, "__file__", None)
        if mod_path:
            mod = Jac.program.mod.hub.get(mod_path)
            if mod and mod.gen.client_manifest:
                manifest = mod.gen.client_manifest
                self._client_manifest = {
                    "exports": manifest.exports,
                    "globals": manifest.globals,
                    "params": manifest.params,
                    "globals_values": manifest.globals_values,
                    "has_client": manifest.has_client,
                }
                return
        self._client_manifest = {}

    def _extract_access_levels(self) -> None:
        """Extract access level information from module AST."""
        if not self._module:
            return

        import jaclang.compiler.unitree as uni

        self._function_access = {}
        self._walker_access = {}

        mod_path = getattr(self._module, "__file__", None)
        if not mod_path:
            return

        mod_ast = Jac.program.mod.hub.get(mod_path)
        if not mod_ast:
            return

        # Traverse AST body to find functions and walkers with access levels
        for item in mod_ast.body:
            # Top-level abilities (functions) - note: Ability uses 'name_ref' not 'name'
            if isinstance(item, uni.Ability) and item.name_ref is not None:
                func_name = item.name_ref.sym_name
                # Store whether auth is required: True for protected/private, False for public
                self._function_access[func_name] = not item.public_access

            # Walkers (which are archetypes)
            elif isinstance(item, uni.Archetype):
                # Check if it's a walker by checking if it's a subclass of WalkerArchetype
                arch_name = item.name.sym_name

                # Try to get the actual class from the module to check if it's a walker
                if hasattr(self._module, arch_name):
                    cls = getattr(self._module, arch_name)
                    if isinstance(cls, type) and issubclass(cls, WalkerArchetype):
                        # Store whether auth is required: True for protected/private, False for public
                        self._walker_access[arch_name] = not item.public_access

    def _collect_functions(self) -> dict[str, Callable[..., Any]]:
        """Collect callable functions from module."""
        if not self._module:
            return {}

        functions: dict[str, Callable[..., Any]] = {}
        export_names = set(self._client_manifest.get("exports", []))

        for name, obj in inspect.getmembers(self._module):
            if (
                inspect.isfunction(obj)
                and not name.startswith("_")
                and obj.__module__ == self._module.__name__
            ):
                functions[name] = obj
                if name in export_names:
                    self._client_functions[name] = obj

        # Ensure all manifest exports are included
        for name in export_names:
            if name not in self._client_functions and hasattr(self._module, name):
                attr = getattr(self._module, name)
                if callable(attr):
                    self._client_functions[name] = attr

        return functions

    def _collect_walkers(self) -> dict[str, type[WalkerArchetype]]:
        """Collect walker classes from module."""
        if not self._module:
            return {}

        walkers: dict[str, type[WalkerArchetype]] = {}
        for name, obj in inspect.getmembers(self._module):
            if (
                isinstance(obj, type)
                and issubclass(obj, WalkerArchetype)
                and obj is not WalkerArchetype
                and obj.__module__ == self._module.__name__
            ):
                walkers[name] = obj
        return walkers

    def get_functions(self) -> dict[str, Callable[..., Any]]:
        """Get all functions."""
        if not self._functions:
            self.load()
        return dict(self._functions)

    def get_walkers(self) -> dict[str, type[WalkerArchetype]]:
        """Get all walkers."""
        if not self._walkers:
            self.load()
        return dict(self._walkers)

    def get_client_functions(self) -> dict[str, Callable[..., Any]]:
        """Get client-exportable functions."""
        if not self._client_functions:
            self.load()
        return dict(self._client_functions)

    def introspect_callable(self, func: Callable[..., Any]) -> dict[str, Any]:
        """Get callable signature information."""
        try:
            sig = inspect.signature(func)
            type_hints = get_type_hints(func)
        except Exception:
            return {"parameters": {}, "return_type": "Any"}

        params = {
            name: {
                "type": str(type_hints.get(name, Any)),
                "required": param.default == inspect.Parameter.empty,
                "default": (
                    None
                    if param.default == inspect.Parameter.empty
                    else str(param.default)
                ),
            }
            for name, param in sig.parameters.items()
        }

        return {"parameters": params, "return_type": str(type_hints.get("return", Any))}

    def introspect_walker(self, walker_cls: type[WalkerArchetype]) -> dict[str, Any]:
        """Get walker field information."""
        try:
            sig = inspect.signature(walker_cls.__init__)
            type_hints = get_type_hints(walker_cls.__init__)
        except Exception:
            return {"fields": {}}

        fields = {
            name: {
                "type": str(type_hints.get(name, Any)),
                "required": param.default == inspect.Parameter.empty,
                "default": (
                    None
                    if param.default == inspect.Parameter.empty
                    else str(param.default)
                ),
            }
            for name, param in sig.parameters.items()
            if name not in ("self", "args", "kwargs")
        }

        fields["_jac_spawn_node"] = {
            "type": "str (node ID, optional)",
            "required": False,
            "default": "root",
        }

        return {"fields": fields}

    def ensure_bundle(self) -> str:
        """Ensure client bundle is available and return hash."""
        if not self._module:
            raise RuntimeError("Module not loaded")

        if self._bundle:
            return self._bundle.hash

        try:
            self._bundle = self._bundle_builder.build(self._module)
            self._bundle_error = None
            return self._bundle.hash
        except ClientBundleError as exc:
            self._bundle = None
            self._bundle_error = str(exc)
            raise RuntimeError(self._bundle_error) from exc

    def render_page(
        self, function_name: str, args: dict[str, Any], username: str
    ) -> dict[str, Any]:
        """Render HTML page for client function."""
        self.load()

        available_exports = set(self._client_manifest.get("exports", [])) or set(
            self.get_client_functions().keys()
        )
        if function_name not in available_exports:
            raise ValueError(f"Client function '{function_name}' not found")

        bundle_hash = self.ensure_bundle()
        arg_order = list(self._client_manifest.get("params", {}).get(function_name, []))

        globals_payload = {
            name: JacSerializer.serialize(value)
            for name, value in self._collect_client_globals().items()
        }

        initial_state = {
            "module": self._module.__name__ if self._module else self.module_name,
            "function": function_name,
            "args": {
                key: JacSerializer.serialize(value) for key, value in args.items()
            },
            "globals": globals_payload,
            "argOrder": arg_order,
        }

        safe_initial_json = json.dumps(initial_state).replace("</", "<\\/")

        page = (
            "<!DOCTYPE html>"
            '<html lang="en">'
            "<head>"
            '<meta charset="utf-8"/>'
            f"<title>{html.escape(function_name)}</title>"
            "</head>"
            "<body>"
            '<div id="__jac_root"></div>'
            f'<script id="__jac_init__" type="application/json">{safe_initial_json}</script>'
            f'<script src="/static/client.js?hash={bundle_hash}" defer></script>'
            "</body>"
            "</html>"
        )

        return {
            "html": page,
            "bundle_hash": bundle_hash,
            "bundle_code": self._bundle.code,
        }

    def is_auth_required_for_function(self, func_name: str) -> bool:
        """Check if authentication is required for a function based on its access level.

        Public functions: no authentication required
        Protected/Private functions: authentication required
        """
        # _function_access stores: True = auth required, False = public (no auth)
        return self._function_access.get(func_name, False)

    def is_auth_required_for_walker(self, walker_name: str) -> bool:
        """Check if authentication is required for a walker based on its access level.

        Public walkers: no authentication required
        Protected/Private walkers: authentication required
        """
        # _walker_access stores: True = auth required, False = public (no auth)
        return self._walker_access.get(walker_name, False)

    def _collect_client_globals(self) -> dict[str, Any]:
        """Collect client-exposed global values."""
        if not self._module:
            return {}

        result: dict[str, Any] = {}
        names = self._client_manifest.get("globals", [])
        values_map = self._client_manifest.get("globals_values", {})

        for name in names:
            if name in values_map:
                result[name] = values_map[name]
            elif hasattr(self._module, name):
                result[name] = getattr(self._module, name)
            else:
                result[name] = None

        return result


# HTTP Response Builder
class ResponseBuilder:
    """Build and send HTTP responses."""

    @staticmethod
    def send_json(
        handler: BaseHTTPRequestHandler, status: StatusCode, data: dict[str, JsonValue]
    ) -> None:
        """Send JSON response with CORS headers."""
        handler.send_response(status)
        handler.send_header("Content-Type", "application/json")
        ResponseBuilder._add_cors_headers(handler)
        handler.end_headers()
        handler.wfile.write(json.dumps(data).encode())

    @staticmethod
    def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None:
        """Send HTML response with CORS headers."""
        payload = body.encode("utf-8")
        handler.send_response(status)
        handler.send_header("Content-Type", "text/html; charset=utf-8")
        handler.send_header("Content-Length", str(len(payload)))
        ResponseBuilder._add_cors_headers(handler)
        handler.end_headers()
        handler.wfile.write(payload)

    @staticmethod
    def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None:
        """Send JavaScript response."""
        payload = code.encode("utf-8")
        handler.send_response(200)
        handler.send_header("Content-Type", "application/javascript; charset=utf-8")
        handler.send_header("Content-Length", str(len(payload)))
        handler.send_header("Cache-Control", "no-cache")
        ResponseBuilder._add_cors_headers(handler)
        handler.end_headers()
        handler.wfile.write(payload)

    @staticmethod
    def send_css(handler: BaseHTTPRequestHandler, css: str) -> None:
        """Send CSS response."""
        payload = css.encode("utf-8")
        handler.send_response(200)
        handler.send_header("Content-Type", "text/css; charset=utf-8")
        handler.send_header("Content-Length", str(len(payload)))
        handler.send_header("Cache-Control", "no-cache")
        ResponseBuilder._add_cors_headers(handler)
        handler.end_headers()
        handler.wfile.write(payload)

    @staticmethod
    def _add_cors_headers(handler: BaseHTTPRequestHandler) -> None:
        """Add CORS headers to response."""
        handler.send_header("Access-Control-Allow-Origin", "*")
        handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        handler.send_header(
            "Access-Control-Allow-Headers", "Content-Type, Authorization"
        )


# Route Handlers
class RouteHandler:
    """Base route handler."""

    def __init__(
        self,
        introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager,
    ) -> None:
        """Initialize route handler."""
        self.introspector = introspector
        self.execution_manager = execution_manager
        self.user_manager = user_manager


class AuthHandler(RouteHandler):
    """Handle authentication routes."""

    def create_user(self, username: str, password: str) -> Response:
        """Create new user."""
        if not username or not password:
            return Response(400, {"error": "Username and password required"})

        result = self.user_manager.create_user(username, password)
        if "error" in result:
            return Response(400, dict[str, JsonValue](result))

        return Response(201, dict[str, JsonValue](result))

    def login(self, username: str, password: str) -> Response:
        """Authenticate user."""
        if not username or not password:
            return Response(400, {"error": "Username and password required"})

        result = self.user_manager.authenticate(username, password)
        if not result:
            return Response(401, {"error": "Invalid credentials"})

        return Response(200, dict[str, JsonValue](result))


class IntrospectionHandler(RouteHandler):
    """Handle introspection routes."""

    def list_functions(self) -> Response:
        """List all functions."""
        self.introspector.load()
        return Response(
            200, {"functions": list(self.introspector.get_functions().keys())}
        )

    def list_walkers(self) -> Response:
        """List all walkers."""
        self.introspector.load()
        return Response(200, {"walkers": list(self.introspector.get_walkers().keys())})

    def get_function_info(self, name: str) -> Response:
        """Get function signature."""
        self.introspector.load()
        functions = self.introspector.get_functions()

        if name not in functions:
            return Response(404, {"error": f"Function '{name}' not found"})

        signature = self.introspector.introspect_callable(functions[name])
        return Response(200, {"name": name, "signature": signature})

    def get_walker_info(self, name: str) -> Response:
        """Get walker info."""
        self.introspector.load()
        walkers = self.introspector.get_walkers()

        if name not in walkers:
            return Response(404, {"error": f"Walker '{name}' not found"})

        info = self.introspector.introspect_walker(walkers[name])
        return Response(200, {"name": name, "info": info})


class ExecutionHandler(RouteHandler):
    """Handle execution routes."""

    def call_function(self, name: str, args: dict[str, Any], username: str) -> Response:
        """Call a function."""
        self.introspector.load()
        functions = self.introspector.get_functions()

        if name not in functions:
            return Response(404, {"error": f"Function '{name}' not found"})

        result = self.execution_manager.execute_function(
            functions[name], args, username
        )
        return Response(200, result)

    def spawn_walker(
        self, name: str, fields: dict[str, Any], username: str
    ) -> Response:
        """Spawn a walker."""
        self.introspector.load()
        walkers = self.introspector.get_walkers()

        if name not in walkers:
            return Response(404, {"error": f"Walker '{name}' not found"})

        result = self.execution_manager.spawn_walker(walkers[name], fields, username)
        return Response(200, result)


# Main Server
class JacAPIServer:
    """REST API Server for Jac programs."""

    def __init__(
        self,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: str | None = None,
    ) -> None:
        """Initialize the API server."""
        self.module_name = module_name
        self.session_path = session_path
        self.port = port
        self.base_path = base_path

        # Core components
        self.user_manager = UserManager(session_path)
        self.introspector = Jac.get_module_introspector(module_name, base_path)
        self.execution_manager = ExecutionManager(session_path, self.user_manager)

        # Route handlers
        self.auth_handler = AuthHandler(
            self.introspector, self.execution_manager, self.user_manager
        )
        self.introspection_handler = IntrospectionHandler(
            self.introspector, self.execution_manager, self.user_manager
        )
        self.execution_handler = ExecutionHandler(
            self.introspector, self.execution_manager, self.user_manager
        )

    def create_handler(self) -> type[BaseHTTPRequestHandler]:
        """Create HTTP request handler."""
        server = self

        class JacRequestHandler(BaseHTTPRequestHandler):
            """Handle HTTP requests."""

            def _get_auth_token(self) -> str | None:
                """Extract auth token from Authorization header."""
                auth_header = self.headers.get("Authorization")
                return (
                    auth_header[7:]
                    if auth_header and auth_header.startswith("Bearer ")
                    else None
                )

            def _authenticate(self) -> str | None:
                """Authenticate request and return username."""
                token = self._get_auth_token()
                return server.user_manager.validate_token(token) if token else None

            def _read_json(self) -> dict[str, Any]:
                """Read and parse JSON from request body."""
                content_length = int(self.headers.get("Content-Length", 0))
                body = (
                    self.rfile.read(content_length).decode()
                    if content_length > 0
                    else "{}"
                )
                return json.loads(body)

            def _send_response(self, response: Response) -> None:
                """Send response to client."""
                Jac.send_json(self, response.status, response.body)  # type: ignore[arg-type]

            def do_OPTIONS(self) -> None:  # noqa: N802
                """Handle OPTIONS requests (CORS preflight)."""
                self.send_response(200)
                ResponseBuilder._add_cors_headers(self)
                self.end_headers()

            def do_GET(self) -> None:  # noqa: N802
                """Handle GET requests."""
                parsed_path = urlparse(self.path)
                path = parsed_path.path

                # Static assets
                if path == "/static/client.js":
                    try:
                        server.introspector.load()
                        server.introspector.ensure_bundle()
                        Jac.send_javascript(self, server.introspector._bundle.code)
                    except RuntimeError as exc:
                        Jac.send_json(self, 503, {"error": str(exc)})
                    return

                # Static files (CSS, images, fonts, etc.) from dist or assets directories
                # Handle both /static/ paths and direct asset paths (from Vite bundles)
                is_static_path = path.startswith("/static/")
                is_asset_file = (
                    not is_static_path
                    and path != "/"
                    and not path.startswith("/page/")
                    and not path.startswith("/function/")
                    and not path.startswith("/walker/")
                    and not path.startswith("/user/")
                    and not path.startswith("/functions")
                    and not path.startswith("/walkers")
                    and not path.startswith("/protected")
                    and Path(path).suffix
                    in {
                        ".png",
                        ".jpg",
                        ".jpeg",
                        ".gif",
                        ".webp",
                        ".svg",
                        ".ico",
                        ".woff",
                        ".woff2",
                        ".ttf",
                        ".otf",
                        ".eot",
                        ".mp4",
                        ".webm",
                        ".mp3",
                        ".wav",
                        ".css",
                    }
                )

                if is_static_path or is_asset_file:
                    try:
                        base_path = (
                            Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd()
                        )

                        if is_static_path:
                            # Remove /static/ prefix to get the relative file path
                            relative_path = path[8:]  # Remove "/static/"
                        else:
                            # Direct asset path (e.g., /burger.png from Vite)
                            relative_path = path[1:]  # Remove leading "/"

                        file_name = Path(relative_path).name

                        # Try dist directory first (for Vite-bundled assets)
                        dist_file = base_path / "dist" / relative_path
                        # Also try just the filename in dist (for CSS files and direct assets)
                        dist_file_simple = base_path / "dist" / file_name
                        # Try assets directory (for user-provided static assets)
                        assets_file = base_path / "assets" / relative_path
                        # Also try just the filename in assets
                        assets_file_simple = base_path / "assets" / file_name

                        # CSS files - try to read as text first
                        if path.endswith(".css"):
                            if dist_file.exists():
                                css_content = dist_file.read_text(encoding="utf-8")
                                Jac.send_css(self, css_content)
                                return
                            elif dist_file_simple.exists():
                                css_content = dist_file_simple.read_text(
                                    encoding="utf-8"
                                )
                                Jac.send_css(self, css_content)
                                return
                            elif assets_file.exists():
                                css_content = assets_file.read_text(encoding="utf-8")
                                Jac.send_css(self, css_content)
                                return
                            elif assets_file_simple.exists():
                                css_content = assets_file_simple.read_text(
                                    encoding="utf-8"
                                )
                                Jac.send_css(self, css_content)
                                return
                            else:
                                Jac.send_json(
                                    self, 404, {"error": "CSS file not found"}
                                )
                                return

                        # Other static files (images, fonts, etc.) - serve as binary
                        for candidate_file in [
                            dist_file,
                            dist_file_simple,
                            assets_file,
                            assets_file_simple,
                        ]:
                            if candidate_file.exists() and candidate_file.is_file():
                                Jac.send_static_file(self, candidate_file)
                                return

                        Jac.send_json(self, 404, {"error": "Static file not found"})
                    except Exception as exc:
                        Jac.send_json(self, 500, {"error": str(exc)})
                    return

                # Root endpoint
                if path == "/":
                    Jac.send_json(
                        self,
                        200,
                        {
                            "message": "Jac API Server",
                            "endpoints": {
                                "POST /user/create": "Create a new user",
                                "POST /user/login": "Authenticate and get token",
                                "GET /functions": "List all available functions",
                                "GET /walkers": "List all available walkers",
                                "GET /function/<name>": "Get function signature",
                                "GET /walker/<name>": "Get walker fields",
                                "POST /function/<name>": "Call a function",
                                "POST /walker/<name>": "Spawn a walker",
                                "GET /page/<name>": "Render HTML page for client function",
                            },
                        },
                    )
                    return

                # Client page rendering (public or authenticated)
                if path.startswith("/page/"):
                    func_name = path.split("/")[-1]
                    query_params = parse_qs(parsed_path.query, keep_blank_values=True)
                    args = {
                        key: values[0] if len(values) == 1 else values
                        for key, values in query_params.items()
                        if key != "mode"
                    }

                    username = self._authenticate()
                    if not username:
                        username = "__guest__"
                        if username not in server.user_manager._users:
                            server.user_manager.create_user(username, "__no_password__")

                    try:
                        render_payload = server.introspector.render_page(
                            func_name, args, username
                        )
                        Jac.send_html(self, 200, render_payload["html"])
                    except ValueError as exc:
                        Jac.send_json(self, 404, {"error": str(exc)})
                    except RuntimeError as exc:
                        Jac.send_json(self, 503, {"error": str(exc)})
                    return

                # Route to introspection handlers
                if path == "/functions":
                    self._send_response(server.introspection_handler.list_functions())
                    return
                elif path == "/walkers":
                    # # List walkers - always require auth for introspection
                    # username = self._authenticate()
                    # if not username:
                    #     Jac.send_json(self, 401, {"error": "Unauthorized"})
                    #     return
                    self._send_response(server.introspection_handler.list_walkers())
                    return
                elif path.startswith("/function/"):
                    name = path.split("/")[-1]
                    # Check if this function requires authentication
                    server.introspector.load()
                    if server.introspector.is_auth_required_for_function(name):
                        username = self._authenticate()
                        if not username:
                            Jac.send_json(self, 401, {"error": "Unauthorized"})
                            return
                    self._send_response(
                        server.introspection_handler.get_function_info(name)
                    )
                    return
                elif path.startswith("/walker/"):
                    name = path.split("/")[-1]
                    # Check if this walker requires authentication
                    server.introspector.load()
                    if server.introspector.is_auth_required_for_walker(name):
                        username = self._authenticate()
                        if not username:
                            Jac.send_json(self, 401, {"error": "Unauthorized"})
                            return
                    self._send_response(
                        server.introspection_handler.get_walker_info(name)
                    )
                    return
                elif path == "/protected":
                    username = self._authenticate()
                    if not username:
                        Jac.send_json(self, 401, {"error": "Unauthorized"})
                        return
                    self._send_response(Response(200, {"message": "sucessful"}))
                else:
                    Jac.send_json(self, 404, {"error": "Not found"})
                # # Protected endpoints

            def do_POST(self) -> None:  # noqa: N802
                """Handle POST requests."""
                parsed_path = urlparse(self.path)
                path = parsed_path.path

                try:
                    data = self._read_json()
                except json.JSONDecodeError:
                    Jac.send_json(self, 400, {"error": "Invalid JSON"})
                    return

                # Public auth endpoints
                if path == "/user/create":
                    response = server.auth_handler.create_user(
                        data.get("username", ""), data.get("password", "")
                    )
                    self._send_response(response)
                    return

                if path == "/user/login":
                    response = server.auth_handler.login(
                        data.get("username", ""), data.get("password", "")
                    )
                    self._send_response(response)
                    return

                # Execution endpoints - check access levels for authentication
                if path.startswith("/function/"):
                    name = path.split("/")[-1]
                    # Check if this function requires authentication
                    server.introspector.load()
                    if server.introspector.is_auth_required_for_function(name):
                        # Protected/Private function - require authentication
                        username = self._authenticate()
                        if not username:
                            Jac.send_json(self, 401, {"error": "Unauthorized"})
                            return
                    else:
                        # Public function - allow guest access
                        username = self._authenticate()
                        if not username:
                            username = "__guest__"
                            if username not in server.user_manager._users:
                                server.user_manager.create_user(
                                    username, "__no_password__"
                                )

                    response = server.execution_handler.call_function(
                        name, data.get("args", {}), username
                    )
                    self._send_response(response)
                elif path.startswith("/walker/"):
                    name_parts = path.split("/")
                    name = name_parts[-2] if len(name_parts) > 3 else name_parts[-1]
                    node_id = name_parts[-1] if len(name_parts) > 3 else ""
                    # Check if this walker requires authentication
                    server.introspector.load()
                    if server.introspector.is_auth_required_for_walker(name):
                        # Protected/Private walker - require authentication
                        username = self._authenticate()
                        if not username:
                            Jac.send_json(self, 401, {"error": "Unauthorized"})
                            return
                    else:
                        # Public walker - allow guest access
                        username = self._authenticate()
                        if not username:
                            username = "__guest__"
                            if username not in server.user_manager._users:
                                server.user_manager.create_user(
                                    username, "__no_password__"
                                )
                    # add two dict to fields to include _jac_spawn_node
                    fields = data.get("fields", {}) | {"_jac_spawn_node": node_id}
                    response = server.execution_handler.spawn_walker(
                        name, fields, username
                    )
                    self._send_response(response)
                else:
                    Jac.send_json(self, 404, {"error": "Not found"})

            def log_message(self, format: str, *args: object) -> None:
                """Log HTTP requests."""
                print(f"{self.address_string()} - {format % args}")

        return JacRequestHandler

    def load_module(self, force_reload: bool = False) -> None:
        """Load the target module (backward compatibility)."""
        self.introspector.load(force_reload)

    @property
    def module(self) -> object:
        """Get loaded module (backward compatibility)."""
        return self.introspector._module

    def get_functions(self) -> dict[str, Callable[..., Any]]:
        """Get all functions (backward compatibility)."""
        return self.introspector.get_functions()

    def get_walkers(self) -> dict[str, type[WalkerArchetype]]:
        """Get all walkers (backward compatibility)."""
        return self.introspector.get_walkers()

    def introspect_callable(self, func: Callable[..., Any]) -> dict[str, Any]:
        """Introspect callable (backward compatibility)."""
        return self.introspector.introspect_callable(func)

    def introspect_walker(self, walker_cls: type[WalkerArchetype]) -> dict[str, Any]:
        """Introspect walker (backward compatibility)."""
        return self.introspector.introspect_walker(walker_cls)

    def render_client_page(
        self, function_name: str, args: dict[str, Any], username: str
    ) -> dict[str, Any]:
        """Render client page (backward compatibility)."""
        return self.introspector.render_page(function_name, args, username)

    def get_client_bundle_code(self) -> str:
        """Get client bundle code (backward compatibility)."""
        self.introspector.load()
        self.introspector.ensure_bundle()
        return self.introspector._bundle.code

    def print_endpoint_docs(self) -> None:
        """Print comprehensive documentation for all endpoints that would be generated."""
        print_endpoint_docs(self)

    def start(self) -> None:
        """Start the HTTP server."""
        self.introspector.load()
        handler_class = self.create_handler()

        with HTTPServer(("0.0.0.0", self.port), handler_class) as httpd:
            print(f"Jac API Server running on http://0.0.0.0:{self.port}")
            print(f"Module: {self.module_name}")
            print(f"Session: {self.session_path}")
            print("\nAvailable endpoints:")
            print("  POST /user/create - Create a new user")
            print("  POST /user/login - Login and get auth token")
            print("  GET /functions - List all functions")
            print("  GET /walkers - List all walkers")
            print("  GET /function/<name> - Get function signature")
            print("  GET /walker/<name> - Get walker info")
            print("  POST /function/<name> - Call a function")
            print("  POST /walker/<name> - Spawn a walker")
            print("\nPress Ctrl+C to stop the server")

            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\nShutting down server...")


def print_endpoint_docs(server: JacAPIServer) -> None:
    """Print comprehensive documentation for all endpoints that would be generated."""
    server.introspector.load()
    functions = server.introspector.get_functions()
    walkers = server.introspector.get_walkers()
    client_exports = server.introspector._client_manifest.get("exports", [])

    def section(title: str, auth: str = "") -> None:
        """Print section header."""
        print(f"\n{title}{f' ({auth})' if auth else ''}\n{'-' * 80}")

    def endpoint(method: str, path: str, desc: str, details: str = "") -> None:
        """Print endpoint with description."""
        print(f"\n{method:6} {path}")
        print(f"       {desc}")
        if details:
            print(f"       {details}")

    def format_param(name: str, info: dict[str, Any]) -> str:
        """Format parameter info."""
        req = "required" if info["required"] else "optional"
        default = f", default: {info['default']}" if info.get("default") else ""
        return f'{name}: {info["type"]} ({req}{default})'

    # Header
    print("\n" + "=" * 80)
    print(f"JAC API SERVER - {server.module_name}")
    print("=" * 80)

    # Auth endpoints
    section("AUTHENTICATION")
    endpoint(
        "POST",
        "/user/create",
        "Create new user account",
        'Body: { "username": str, "password": str }',
    )
    endpoint(
        "POST",
        "/user/login",
        "Authenticate and get token",
        'Body: { "username": str, "password": str }',
    )

    # Introspection
    section("INTROSPECTION", "Authenticated")
    endpoint("GET", "/functions", "List all functions → string[]")
    endpoint("GET", "/walkers", "List all walkers → string[]")

    # Functions
    if functions:
        section("FUNCTIONS", "Authenticated")
        for name, func in functions.items():
            sig = server.introspector.introspect_callable(func)
            params = [format_param(n, i) for n, i in sig["parameters"].items()]
            params_str = ", ".join(params) if params else "none"

            endpoint("GET", f"/function/{name}", "Get signature")
            endpoint(
                "POST",
                f"/function/{name}",
                f"Call function → {sig['return_type']}",
                f"Args: {{ {params_str} }}" if params else "No arguments",
            )

    # Walkers
    if walkers:
        section("WALKERS", "Authenticated")
        for name, walker_cls in walkers.items():
            info = server.introspector.introspect_walker(walker_cls)
            fields = [format_param(n, i) for n, i in info["fields"].items()]
            fields_str = ", ".join(fields[:3])
            if len(fields) > 3:
                fields_str += f", ... (+{len(fields) - 3} more)"

            endpoint("GET", f"/walker/{name}", "Get walker fields")
            endpoint(
                "POST",
                f"/walker/{name}",
                "Spawn walker",
                f"Fields: {{ {fields_str} }}" if fields else "No fields",
            )

    # Client pages
    section("CLIENT PAGES", "Public")
    if client_exports:
        funcs_list = ", ".join(sorted(client_exports)[:8])
        if len(client_exports) > 8:
            funcs_list += f" (+{len(client_exports) - 8} more)"
        print(f"\nAvailable ({len(client_exports)}): {funcs_list}")
        endpoint(
            "GET",
            "/page/<name>",
            "Render HTML for client function",
            "Example: /page/App?arg1=value1",
        )
    else:
        print("\nNo client functions. Define with 'cl def' for browser-side rendering.")

    # Static
    section("STATIC")
    endpoint("GET", "/", "API information and endpoint list")
    endpoint("GET", "/static/client.js", "Client JavaScript bundle")

    # Summary
    total = 2 + 2 + len(functions) * 2 + len(walkers) * 2 + 2
    print("\n" + "=" * 80)
    print(
        f"TOTAL: {len(functions)} functions · {len(walkers)} walkers · "
        f"{len(client_exports)} client functions · {total} endpoints"
    )
    print("=" * 80)
    print("\nAuth: Bearer token (Authorization: Bearer <token>)\n")
