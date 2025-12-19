import mimetypes;
import from collections.abc { Callable }
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }
import from typing { Any }
import jwt;
import from os { getenv }
import from fastapi.middleware.cors { CORSMiddleware }
import from fastapi.responses { HTMLResponse, JSONResponse, Response, RedirectResponse }
import from jac_scale.jserver.jfast_api { JFastApiServer }
import from jac_scale.jserver.jserver {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.pycore.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.server { JacAPIServer as JServer }
import from jaclang.runtimelib.server { JsonValue }
import from jaclang.runtimelib.server { JsonValue }
import from enum { StrEnum }
import from fastapi_sso.sso.google { GoogleSSO }
import from jac_scale.utils { generate_random_password }

glob
    JWT_SECRET = getenv('JWT_SECRET', 'supersecretkey'),
    JWT_ALGORITHM = getenv('JWT_ALGORITHM', 'HS256'),
    JWT_EXP_DELTA_DAYS = getenv('JWT_EXP_DELTA_DAYS', 7),
    SSO_HOST = getenv("SSO_HOST", "http://localhost:8000/sso");

class Platforms(StrEnum) {
    has GOOGLE: str = 'google';
}

class Operations(StrEnum) {
    has LOGIN: str = 'login';
    has REGISTER: str = 'register';
}

class JacAPIServer(JServer) {
    static def create_jwt_token(username: str) -> str;
    static def validate_jwt_token(token: str) -> (str | None);
    static def refresh_jwt_token(token: str) -> (str | None);
    def init(
        self: JacAPIServer,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: (str | None) = None
    ) -> None;

    def login(self: JacAPIServer, email: str, password: str) -> JSONResponse;
    def register_login_endpoint(self: JacAPIServer) -> None;
    def create_user(self: JacAPIServer, email: str, password: str) -> JSONResponse;
    def refresh_token(self: JacAPIServer, token: (str | None) = None) -> JSONResponse;
    def register_create_user_endpoint(self: JacAPIServer) -> None;
    def register_refresh_token_endpoint(self: JacAPIServer) -> None;
    def get_sso(
        self: JacAPIServer, platform: str, operation: str
    ) -> (GoogleSSO | None);

    async def sso_initiate(
        self: JacAPIServer, platform: str, operation: str
    ) -> Response;

    async def sso_callback(
        self: JacAPIServer, request: Request, platform: str, operation: str
    ) -> JSONResponse;

    def register_sso_endpoints(self: JacAPIServer) -> None;
    def create_walker_callback(
        self: JacAPIServer, walker_name: str, has_node_param: bool = False
    ) -> Callable[..., dict[(str, JsonValue)]];

    def create_walker_parameters(
        self: JacAPIServer, walker_name: str, invoke_on_root: bool
    ) -> list[APIParameter];

    def register_walkers_endpoints(self: JacAPIServer) -> None;
    def create_function_callback(
        self: JacAPIServer, func_name: str
    ) -> Callable[..., dict[(str, JsonValue)]];

    def create_function_parameters(
        self: JacAPIServer, func_name: str
    ) -> list[APIParameter];

    def register_functions_endpoints(self: JacAPIServer) -> None;
    def render_page_callback(self: JacAPIServer) -> Callable[..., HTMLResponse];
    def register_page_endpoint(self: JacAPIServer) -> None;
    def serve_client_js_callback(self: JacAPIServer) -> Callable[..., Response];
    def register_client_js_endpoint(self: JacAPIServer) -> None;
    def register_static_file_endpoint(self: JacAPIServer) -> None;
    def serve_static_file(self: JacAPIServer, file_path: str) -> Response;
    def register_root_asset_endpoint(self: JacAPIServer) -> None;
    def serve_root_asset(self: JacAPIServer, file_path: str) -> Response;
    def _configure_openapi_security(self: JacAPIServer) -> None;
    def start(self: JacAPIServer) -> None;
}
