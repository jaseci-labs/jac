import from collections.abc { Callable }
import from pathlib { Path }
import from fastapi { Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response, FileResponse }
import from jaclang.runtimelib.transport { TransportResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jaclang.scale.config.config_loader { get_scale_config }

obj JacAPIServerAdmin {
    def register_admin_endpoints -> None;
    def bootstrap_admin -> None;
    def admin_login(username: str, password: str) -> TransportResponse;
    def validate_admin_token(Authorization: str | None) -> (str | None);
    def require_admin(Authorization: str | None) -> TransportResponse | None;
    def require_admin_json(Authorization: str | None) -> JSONResponse | None;
    def admin_list_users(
        limit: int = 100, offset: int = 0, Authorization: str | None = None
    ) -> TransportResponse;

    def admin_get_user(
        username: str, Authorization: str | None = None
    ) -> TransportResponse;

    def admin_create_user(
        username: str,
        password: str,
        role: str = 'user',
        Authorization: str | None = None
    ) -> TransportResponse;

    def admin_update_user(
        username: str,
        role: str | None = None,
        requires_password_reset: bool | None = None,
        Authorization: str | None = None
    ) -> TransportResponse;

    def admin_delete_user(
        username: str, Authorization: str | None = None
    ) -> TransportResponse;

    def admin_force_password_reset(
        username: str, Authorization: str | None = None
    ) -> TransportResponse;

    def reset_password(
        current_password: str, new_password: str, Authorization: str | None = None
    ) -> TransportResponse;

    def admin_list_sso_providers(
        Authorization: str | None = None
    ) -> TransportResponse;

    def admin_get_user_sso_accounts(
        username: str, Authorization: str | None = None
    ) -> TransportResponse;

    def admin_graph_data(
        username: str | None = None, Authorization: str | None = None
    ) -> JSONResponse;

    def admin_get_config(
        profile: str = "default", Authorization: str | None = None
    ) -> TransportResponse;

    def admin_update_config(
        content: str, profile: str = "default", Authorization: str | None = None
    ) -> TransportResponse;

    def admin_get_metrics(Authorization: str | None = None) -> TransportResponse;
    def serve_admin_page -> Response;
    def serve_admin_index -> Response;
    def serve_admin_asset(path: str) -> Response;
    def build_admin_client(force: bool = False) -> bool;
    def get_admin_dist_dir -> Path;
}
