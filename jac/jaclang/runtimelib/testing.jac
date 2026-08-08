import io;
import json;
import re;
import from pathlib { Path }
import from typing { Any }
import from urllib.parse { urlencode }
import type from jaclang.project.config { JacConfig }
import type from jaclang.runtimelib.server { JacAPIServer }
import from jaclang.runtimelib.serving.client { run_blocking }
import from jaclang.runtimelib.serving.datatypes {
    Headers,
    QueryParams,
    Request,
    Response,
    URL,
    parse_query_string
}
import from jaclang.runtimelib.serving.testing { dispatch_and_collect }

obj TestResponse {
    has status_code: int,
        headers: dict[str, str],
        text: str,
        _json_cache: (dict[str, any] | None) = None;

    def json -> dict[str, any];

    has ok: bool { getter; }
    has data: (dict[str, any] | None) { getter; }
}

obj JacTestClient {
    has _jac_file: str,
        _base_path: str,
        _server: (JacAPIServer | None) = None,
        _app: any = None,
        _auth_token: (str | None) = None,
        _hot_reloader: (Any | None) = None,
        _config: (JacConfig | None) = None;

    static def from_file(
        jac_file: str,
        base_path: (str | None) = None,
        module_name: (str | None) = None,
        config: (JacConfig | None) = None
    ) -> JacTestClient;

    def _ensure_initialized -> None;
    def get(
        path: str,
        params: (dict[str, any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def post(
        path: str,
        json: (dict[str, any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def put(
        path: str,
        json: (dict[str, any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def request(
        method: str,
        path: str,
        json: (dict[str, any] | None) = None,
        params: (dict[str, any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def set_auth_token(token: str) -> None;
    def clear_auth -> None;
    def register_user(username: str, password: str) -> TestResponse;
    def login(username: str, password: str) -> TestResponse;
    def _execute_request(
        method: str,
        path: str,
        body: (bytes | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    has server: JacAPIServer { getter; }
    has user_manager: any { getter; }

    def reload -> None;
    def close -> None;
}
