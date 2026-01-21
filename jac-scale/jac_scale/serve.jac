import logging;
import mimetypes;
import from collections.abc { Callable }
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }
import from pydantic { BaseModel, Field }
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
import from jaclang.runtimelib.transport { TransportResponse, Meta, MessageType }
import from enum { StrEnum }
import from fastapi_sso.sso.google { GoogleSSO }
import from jac_scale.utils { generate_random_password }
import from jac_scale.config_loader { get_scale_config }

# Load configuration from jac.toml with env var overrides
glob _jwt_config = get_scale_config().get_jwt_config(),
     _sso_config = get_scale_config().get_sso_config(),
     JWT_SECRET = _jwt_config['secret'],
     JWT_ALGORITHM = _jwt_config['algorithm'],
     JWT_EXP_DELTA_DAYS = _jwt_config['exp_delta_days'],
     SSO_HOST = _sso_config['host'],
     logger = logging.getLogger(__name__);

class Platforms(StrEnum) {
    has GOOGLE: str = 'google';
}

class Operations(StrEnum) {
    has LOGIN: str = 'login',
        REGISTER: str = 'register';
}

class JacAPIServer(JServer) {
    # HMR (Hot Module Replacement) support fields
    has _hmr_pending: bool = False,
        _hot_reloader: Any | None = None;

    static def create_jwt_token(username: str) -> str;
    static def validate_jwt_token(token: str) -> (str | None);
    static def refresh_jwt_token(token: str) -> (str | None);
    def init(
        self: JacAPIServer, module_name: str, port: int = 8000, base_path: str = ""
    ) -> None;

    def login(self: JacAPIServer, username: str, password: str) -> TransportResponse;
    def register_login_endpoint(self: JacAPIServer) -> None;
    def update_username(
        self: JacAPIServer,
        current_username: str,
        new_username: str,
        Authorization: (str | None) = None
    ) -> TransportResponse;

    def update_password(
        self: JacAPIServer,
        username: str,
        current_password: str,
        new_password: str,
        Authorization: (str | None) = None
    ) -> TransportResponse;

    def register_update_username_endpoint(self: JacAPIServer) -> None;
    def register_update_password_endpoint(self: JacAPIServer) -> None;
    def create_user(
        self: JacAPIServer, username: str, password: str
    ) -> TransportResponse;

    def refresh_token(
        self: JacAPIServer, token: (str | None) = None
    ) -> TransportResponse;

    def register_create_user_endpoint(self: JacAPIServer) -> None;
    def register_refresh_token_endpoint(self: JacAPIServer) -> None;
    def get_sso(
        self: JacAPIServer, platform: str, operation: str
    ) -> (GoogleSSO | None);

    async def sso_initiate(
        self: JacAPIServer, platform: str, operation: str
    ) -> (Response | TransportResponse);

    async def sso_callback(
        self: JacAPIServer, request: Request, platform: str, operation: str
    ) -> TransportResponse;

    def register_sso_endpoints(self: JacAPIServer) -> None;
    def create_walker_callback(
        self: JacAPIServer, walker_name: str, has_node_param: bool = False
    ) -> Callable[..., TransportResponse];

    def create_walker_parameters(
        self: JacAPIServer, walker_name: str, invoke_on_root: bool
    ) -> list[APIParameter];

    def register_walkers_endpoints(self: JacAPIServer) -> None;
    def create_function_callback(
        self: JacAPIServer, func_name: str
    ) -> Callable[..., TransportResponse];

    def create_function_parameters(
        self: JacAPIServer, func_name: str
    ) -> list[APIParameter];

    def register_functions_endpoints(self: JacAPIServer) -> None;
    def render_page_callback(self: JacAPIServer) -> Callable[..., HTMLResponse];
    def render_base_route_callback(
        self: JacAPIServer, app_name: str
    ) -> Callable[..., HTMLResponse];

    def register_page_endpoint(self: JacAPIServer) -> None;
    def serve_client_js_callback(self: JacAPIServer) -> Callable[..., Response];
    def register_client_js_endpoint(self: JacAPIServer) -> None;
    def register_static_file_endpoint(self: JacAPIServer) -> None;
    def serve_static_file(self: JacAPIServer, file_path: str) -> Response;
    def register_root_asset_endpoint(self: JacAPIServer) -> None;
    def serve_root_asset(self: JacAPIServer, file_path: str) -> Response;
    def _configure_openapi_security(self: JacAPIServer) -> None;
    def start(self: JacAPIServer, dev: bool = False) -> None;
    # HMR (Hot Module Replacement) dynamic routing methods
    def enable_hmr(self: JacAPIServer, hot_reloader: Any) -> None;
    def register_dynamic_walker_endpoint(self: JacAPIServer) -> None;
    def register_dynamic_function_endpoint(self: JacAPIServer) -> None;
    def register_dynamic_introspection_endpoints(self: JacAPIServer) -> None;
}

class UpdateUsernameRequest(BaseModel) {
    has current_username: str = Field(..., description='Current username'),
        new_username: str = Field(..., description='New username');
}

class UpdatePasswordRequest(BaseModel) {
    has username: str = Field(..., description='Username'),
        current_password: str = Field(..., description='Current password'),
        new_password: str = Field(..., description='New password');
}
