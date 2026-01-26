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

enum Platforms ( StrEnum ) { GOOGLE = 'google' }

enum Operations ( StrEnum ) { LOGIN = 'login', REGISTER = 'register' }

obj JacAPIServer(JServer) {
    # HMR (Hot Module Replacement) support fields
    has _hmr_pending: bool = False,
        _hot_reloader: Any | None = None;

    def postinit -> None;
    def login(username: str, password: str) -> TransportResponse;
    def register_login_endpoint -> None;
    def update_username(
        current_username: str, new_username: str, Authorization: (str | None) = None
    ) -> TransportResponse;

    def update_password(
        username: str,
        current_password: str,
        new_password: str,
        Authorization: (str | None) = None
    ) -> TransportResponse;

    def register_update_username_endpoint -> None;
    def register_update_password_endpoint -> None;
    def create_user(username: str, password: str) -> TransportResponse;
    def refresh_token(token: (str | None) = None) -> TransportResponse;
    def register_create_user_endpoint -> None;
    def register_refresh_token_endpoint -> None;
    def register_sso_endpoints -> None;
    def create_walker_callback(
        walker_name: str, has_node_param: bool = False
    ) -> Callable[..., TransportResponse];

    def create_walker_parameters(
        walker_name: str, invoke_on_root: bool
    ) -> list[APIParameter];

    def register_walkers_endpoints -> None;
    def create_function_callback(func_name: str) -> Callable[..., TransportResponse];
    def create_function_parameters(func_name: str) -> list[APIParameter];
    def register_functions_endpoints -> None;
    def render_page_callback -> Callable[..., HTMLResponse];
    def render_base_route_callback(app_name: str) -> Callable[..., HTMLResponse];
    def register_page_endpoint -> None;
    def serve_client_js_callback -> Callable[..., Response];
    def register_client_js_endpoint -> None;
    def register_static_file_endpoint -> None;
    def serve_static_file(file_path: str) -> Response;
    def register_root_asset_endpoint -> None;
    def serve_root_asset(file_path: str) -> Response;
    def _configure_openapi_security -> None;
    def start(dev: bool = False) -> None;
    # HMR (Hot Module Replacement) dynamic routing methods
    def enable_hmr(hot_reloader: Any) -> None;
    def register_dynamic_walker_endpoint -> None;
    def register_dynamic_function_endpoint -> None;
    def register_dynamic_introspection_endpoints -> None;
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
