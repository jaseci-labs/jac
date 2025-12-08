import mimetypes
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import jwt
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response

from jac_scale.jserver.jfast_api import JFastApiServer
from jac_scale.jserver.jserver import APIParameter, HTTPMethod, JEndPoint, ParameterType
from jaclang.runtimelib.runtime import JacRuntime as Jac
from jaclang.runtimelib.server import JacAPIServer as JServer
from jaclang.runtimelib.server import JsonValue

JWT_SECRET = "supersecretkey"
JWT_ALGORITHM = "HS256"
JWT_EXP_DELTA_DAYS = 7


class JacAPIServer(JServer):
    @staticmethod
    def create_jwt_token(username: str) -> str:
        now = datetime.now(UTC)  # UTC time
        payload: dict[str, Any] = {
            "username": username,
            "exp": now + timedelta(days=JWT_EXP_DELTA_DAYS),
            "iat": now,
        }
        return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

    @staticmethod
    def validate_jwt_token(token: str) -> str | None:
        try:
            decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            return decoded["username"]
        except Exception:
            return None

    def __init__(
        self,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: str | None = None,
    ) -> None:
        super().__init__(module_name, session_path, port, base_path)
        self.server_impl = JFastApiServer([])

        # Configure CORS
        self.server_impl.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],  # Allows all origins
            allow_credentials=True,
            allow_methods=["*"],  # Allows all methods
            allow_headers=["*"],  # Allows all headers
        )

    def login(self, email: str, password: str) -> JSONResponse:
        if not email or not password:
            return JSONResponse(
                status_code=400, content={"error": "Email and password required"}
            )

        result = self.user_manager.authenticate(email, password)
        if not result:
            return JSONResponse(
                status_code=401, content={"error": "Invalid credentials"}
            )

        result["token"] = self.create_jwt_token(email)
        return JSONResponse(status_code=200, content=dict[str, JsonValue](result))

    def register_login_endpoint(self) -> None:
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path="/user/login",
                callback=self.login,
                parameters=[
                    APIParameter(
                        name="email",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Email for login",
                        type=ParameterType.BODY,
                    ),
                    APIParameter(
                        name="password",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Password for login",
                        type=ParameterType.BODY,
                    ),
                ],
                response_model=None,
                tags=["User APIs"],
                summary="User login",
                description="Endpoint for user authentication and token generation",
            )
        )

    def create_user(self, email: str, password: str) -> JSONResponse:
        res = self.user_manager.create_user(email, password)
        if "error" in res:
            return JSONResponse(content=res, status_code=400)

        res["token"] = self.create_jwt_token(email)
        return JSONResponse(content=res, status_code=201)

    def register_create_user_endpoint(self) -> None:
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path="/user/register",
                callback=self.create_user,
                parameters=[
                    APIParameter(
                        name="email",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Username for new user",
                        type=ParameterType.BODY,
                    ),
                    APIParameter(
                        name="password",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Password for new user",
                        type=ParameterType.BODY,
                    ),
                ],
                response_model=None,
                tags=["User APIs"],
                summary="Register user API.",
                description="Endpoint for creating a new user account",
            )
        )

    def create_walker_callback(
        self, walker_name: str, has_node_param: bool = False
    ) -> Callable[..., dict[str, JsonValue]]:
        requires_auth = self.introspector.is_auth_required_for_walker(walker_name)

        def callback(
            node: str | None = None, **kwargs: JsonValue
        ) -> dict[str, JsonValue]:
            username: str | None = None

            if requires_auth:
                authorization = kwargs.pop("Authorization", None)

                token: str | None = None
                if (
                    authorization
                    and isinstance(authorization, str)
                    and authorization.startswith("Bearer ")
                ):
                    token = authorization[7:]  # Remove "Bearer " prefix

                username = self.validate_jwt_token(token) if token else None
                if not username:
                    return {"error": "Unauthorized", "status": 401}

            if node:
                kwargs["_jac_spawn_node"] = node
            return self.execution_manager.spawn_walker(
                self.get_walkers()[walker_name], kwargs, username or "__guest__"
            )

        return callback

    def create_walker_parameters(
        self, walker_name: str, invoke_on_root: bool
    ) -> list[APIParameter]:
        parameters: list[APIParameter] = []

        # Only add Authorization header if walker requires authentication
        if self.introspector.is_auth_required_for_walker(walker_name):
            parameters.append(
                APIParameter(
                    name="Authorization",
                    data_type="string",
                    required=False,
                    default=None,
                    description="Bearer token for authentication",
                    type=ParameterType.HEADER,
                )
            )

        walker_fields = self.introspector.introspect_walker(
            self.get_walkers()[walker_name]
        )["fields"]

        for field_name in walker_fields:
            if field_name == "_jac_spawn_node" and invoke_on_root:
                continue

            parameters.append(
                APIParameter(
                    name="node" if field_name == "_jac_spawn_node" else field_name,
                    data_type=walker_fields[field_name]["type"],
                    required=walker_fields[field_name]["required"],
                    default=walker_fields[field_name]["default"],
                    description=f"Field {field_name} for walker {walker_name}",
                    type=(
                        ParameterType.BODY
                        if field_name != "_jac_spawn_node"
                        else ParameterType.PATH
                    ),
                )
            )
        return parameters

    def register_walkers_endpoints(self) -> None:
        for walker_name in self.get_walkers():
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/walker/{walker_name}/{{node}}",
                    callback=self.create_walker_callback(
                        walker_name, has_node_param=True
                    ),
                    parameters=self.create_walker_parameters(
                        walker_name, invoke_on_root=False
                    ),
                    response_model=None,
                    tags=["Walkers"],
                    summary="API Entry",
                    description="API Entry",
                )
            )
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/walker/{walker_name}",
                    callback=self.create_walker_callback(
                        walker_name, has_node_param=False
                    ),
                    parameters=self.create_walker_parameters(
                        walker_name, invoke_on_root=True
                    ),
                    response_model=None,
                    tags=["Walkers"],
                    summary="API Root",
                    description="API Root",
                )
            )

    def create_function_callback(
        self, func_name: str
    ) -> Callable[..., dict[str, JsonValue]]:
        requires_auth = self.introspector.is_auth_required_for_function(func_name)

        def callback(**kwargs: JsonValue) -> dict[str, JsonValue]:
            username: str | None = None

            if requires_auth:
                # Extract and validate authorization header
                authorization = kwargs.pop("Authorization", None)

                token: str | None = None
                if (
                    authorization
                    and isinstance(authorization, str)
                    and authorization.startswith("Bearer ")
                ):
                    token = authorization[7:]  # Remove "Bearer " prefix

                username = self.validate_jwt_token(token) if token else None
                if not username:
                    return {"error": "Unauthorized", "status": 401}

            print(f"Executing function '{func_name}' with params: {kwargs}")
            return self.execution_manager.execute_function(
                self.get_functions()[func_name], kwargs, username or "__guest__"
            )

        return callback

    def create_function_parameters(self, func_name: str) -> list[APIParameter]:
        parameters: list[APIParameter] = []

        # Only add Authorization header if function requires authentication
        if self.introspector.is_auth_required_for_function(func_name):
            parameters.append(
                APIParameter(
                    name="Authorization",
                    data_type="string",
                    required=False,
                    default=None,
                    description="Bearer token for authentication",
                    type=ParameterType.HEADER,
                )
            )

        func_fields = self.introspector.introspect_callable(
            self.get_functions()[func_name]
        )["parameters"]
        for field_name in func_fields:
            parameters.append(
                APIParameter(
                    name=field_name,
                    data_type=func_fields[field_name]["type"],
                    required=func_fields[field_name]["required"],
                    default=func_fields[field_name]["default"],
                    description=f"Field {field_name} for function {func_name}",
                )
            )
        return parameters

    def register_functions_endpoints(self) -> None:
        for func_name in self.get_functions():
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.GET,
                    path=f"/function/{func_name}",
                    callback=self.create_function_callback(func_name),
                    parameters=self.create_function_parameters(func_name),
                    response_model=None,
                    tags=["Functions"],
                    summary="This is a summary",
                    description="This is a description",
                )
            )

    def render_page_callback(self) -> Callable[..., HTMLResponse]:
        """Create callback that extracts all query parameters from FastAPI Request."""

        def callback(page_name: str, **kwargs: JsonValue) -> HTMLResponse:
            """Render a page by name with all query parameters."""
            render_payload = self.introspector.render_page(
                page_name, kwargs, "__guest__"
            )
            return HTMLResponse(content=render_payload["html"])

        return callback

    def register_page_endpoint(self) -> None:
        """Register the page rendering endpoint using JEndPoint."""
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path="/page/{page_name}",
                callback=self.render_page_callback(),
                parameters=[
                    APIParameter(
                        name="page_name",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Name of the page to render",
                        type=ParameterType.PATH,
                    )
                ],
                response_model=None,
                tags=["Pages"],
                summary="Render a page",
                description="Endpoint to render and retrieve a specific page by name. ",
            )
        )

    def serve_client_js_callback(self) -> Callable[..., Response]:
        """Create callback to serve the client.js file."""

        def callback() -> Response:
            try:
                self.introspector.load()
                self.introspector.ensure_bundle()
                return Response(
                    content=self.introspector._bundle.code,
                    media_type="application/javascript",
                )
            except RuntimeError as exc:
                return Response(
                    content=str(exc), status_code=503, media_type="text/plain"
                )

        return callback

    def register_client_js_endpoint(self) -> None:
        """Register the client.js serving endpoint using JEndPoint."""
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path="/static/client.js",
                callback=self.serve_client_js_callback(),
                parameters=[],
                response_model=None,
                tags=["Static Files"],
                summary="Serve client.js",
                description="Endpoint to serve the client-side JavaScript file.",
            )
        )

    def register_static_file_endpoint(self) -> None:
        """Register the static file serving endpoint using JEndPoint."""
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path="/static/{file_path:path}",
                callback=self.serve_static_file,
                parameters=[
                    APIParameter(
                        name="file_path",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Path of the static file to serve",
                        type=ParameterType.PATH,
                    )
                ],
                response_model=None,
                tags=["Static Files"],
                summary="Serve static files",
                description="Endpoint to serve static files from the server.",
            )
        )

    def serve_static_file(self, file_path: str) -> Response:
        """Serve a static file given its path."""

        base_path = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd()
        file_name = Path(file_path).name

        dist_file = base_path / "dist" / file_path
        dist_file_simple = base_path / "dist" / file_name
        assets_file = base_path / "assets" / file_path
        assets_file_simple = base_path / "assets" / file_name

        if file_name.endswith(".css"):
            if dist_file.exists():
                css_content = dist_file.read_text(encoding="utf-8")
                return Response(content=css_content, media_type="text/css")
            elif dist_file_simple.exists():
                css_content = dist_file_simple.read_text(encoding="utf-8")
                return Response(content=css_content, media_type="text/css")
            elif assets_file.exists():
                css_content = assets_file.read_text(encoding="utf-8")
                return Response(content=css_content, media_type="text/css")
            elif assets_file_simple.exists():
                css_content = assets_file_simple.read_text(encoding="utf-8")
                return Response(content=css_content, media_type="text/css")
            else:
                return Response(
                    status_code=404,
                    content="CSS file not found",
                    media_type="text/plain",
                )

        for candidate_file in [
            dist_file,
            dist_file_simple,
            assets_file,
            assets_file_simple,
        ]:
            if candidate_file.exists() and candidate_file.is_file():
                file_content = candidate_file.read_bytes()
                content_type, _ = mimetypes.guess_type(str(candidate_file))
                if content_type is None:
                    content_type = "application/octet-stream"
                return Response(
                    content=file_content,
                    media_type=content_type,
                )

        return Response(
            status_code=404, content="Static file not found", media_type="text/plain"
        )

    def register_root_asset_endpoint(self) -> None:
        """Register root-level asset serving endpoint for files like /img.png, /logo.svg"""
        # This endpoint matches any path with common asset file extensions
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path="/{file_path:path}",
                callback=self.serve_root_asset,
                parameters=[
                    APIParameter(
                        name="file_path",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Path to asset file (e.g., img.png, icons/logo.svg)",
                        type=ParameterType.PATH,
                    )
                ],
                response_model=None,
                tags=["Static Files"],
                summary="Serve root-level assets",
                description="Endpoint to serve assets from root path with common extensions (.png, .jpg, .svg, etc.)",
            )
        )

    def serve_root_asset(self, file_path: str) -> Response:
        """Serve root-level assets like /img.png, /icons/logo.svg, etc."""

        allowed_extensions = {
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
            ".js",
            ".json",
            ".pdf",
            ".txt",
            ".xml",
        }

        file_ext = Path(file_path).suffix.lower()

        if not file_ext or file_ext not in allowed_extensions:
            return Response(
                status_code=404,
                content="Not found",
                media_type="text/plain",
            )

        if file_path.startswith(("page/", "walker/", "function/", "user/", "static/")):
            return Response(
                status_code=404,
                content="Not found",
                media_type="text/plain",
            )

        base_path = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd()
        file_name = Path(file_path).name

        candidates = [
            base_path / "dist" / file_path,  # dist/img.png or dist/icons/img.png
            base_path / "dist" / file_name,  # dist/img.png (just filename)
            base_path / "assets" / file_path,  # assets/img.png or assets/icons/img.png
            base_path / "assets" / file_name,  # assets/img.png (just filename)
            base_path / "public" / file_path,  # public/img.png (common convention)
            base_path / file_path,  # ./img.png (project root)
        ]

        for candidate_file in candidates:
            if candidate_file.exists() and candidate_file.is_file():
                file_content = candidate_file.read_bytes()
                content_type, _ = mimetypes.guess_type(str(candidate_file))
                if content_type is None:
                    content_type = "application/octet-stream"

                # Add cache headers for static assets (1 year cache)
                headers = {"Cache-Control": "public, max-age=31536000"}

                return Response(
                    content=file_content,
                    media_type=content_type,
                    headers=headers,
                )

        return Response(
            status_code=404,
            content=f"Asset not found: {file_path}",
            media_type="text/plain",
        )

    def _configure_openapi_security(self) -> None:
        """Configure OpenAPI security scheme to only apply to walker endpoints that require auth."""
        from fastapi.openapi.utils import get_openapi

        def custom_openapi() -> dict[str, Any]:
            if self.server_impl.app.openapi_schema:
                return self.server_impl.app.openapi_schema

            openapi_schema = get_openapi(
                title=self.server_impl.app.title,
                version=self.server_impl.app.version,
                routes=self.server_impl.app.routes,
            )

            # Add Bearer token security scheme
            openapi_schema["components"] = openapi_schema.get("components", {})
            openapi_schema["components"]["securitySchemes"] = {
                "BearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT",
                    "description": "Enter your JWT token (without 'Bearer ' prefix)",
                }
            }

            # Apply security only to walker and function endpoints that require authentication
            for path, path_item in openapi_schema.get("paths", {}).items():
                if path.startswith("/walker/"):
                    # Extract walker name from path (e.g., /walker/MyWalker or /walker/MyWalker/{node})
                    path_parts = path.split("/")
                    if len(path_parts) >= 3:
                        walker_name = path_parts[2].split("{")[0].rstrip("/")
                        # Check if this walker requires authentication
                        if (
                            walker_name in self.get_walkers()
                            and self.introspector.is_auth_required_for_walker(
                                walker_name
                            )
                        ):
                            # Apply security to all methods in this path
                            for method in path_item:
                                if method in ["get", "post", "put", "patch", "delete"]:
                                    path_item[method]["security"] = [{"BearerAuth": []}]
                elif path.startswith("/function/"):
                    # Extract function name from path (e.g., /function/my_function)
                    path_parts = path.split("/")
                    if len(path_parts) >= 3:
                        func_name = path_parts[2]
                        # Check if this function requires authentication
                        if (
                            func_name in self.get_functions()
                            and self.introspector.is_auth_required_for_function(
                                func_name
                            )
                        ):
                            # Apply security to all methods in this path
                            for method in path_item:
                                if method in ["get", "post", "put", "patch", "delete"]:
                                    path_item[method]["security"] = [{"BearerAuth": []}]

            self.server_impl.app.openapi_schema = openapi_schema
            return openapi_schema

        self.server_impl.app.openapi = custom_openapi

    def start(self) -> None:
        self.introspector.load()

        self.register_create_user_endpoint()
        self.register_login_endpoint()
        self.register_page_endpoint()
        self.register_client_js_endpoint()
        self.register_static_file_endpoint()
        self.register_walkers_endpoints()
        self.register_functions_endpoints()

        # Register root asset endpoint LAST (catch-all for files like /img.png)
        # Must be registered after all other endpoints to avoid conflicts
        self.register_root_asset_endpoint()

        # Configure OpenAPI security scheme after all routes are registered
        self._configure_openapi_security()

        self.user_manager.create_user("__guest__", "__no_password__")

        self.server_impl.run_server()
