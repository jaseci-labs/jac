"""Test client for Jac API servers without opening OS ports.

This module provides a test client similar to Flask's test_client(),
FastAPI's TestClient, and Django's Client. It allows testing server
endpoints without actual network I/O.

Example:
    ```python
    from jaclang.runtimelib.testing import JacTestClient

    def test_create_task(tmp_path):
        client = JacTestClient.from_file("app.jac", base_path=str(tmp_path))
        client.register_user("testuser", "password123")

        response = client.post("/walker/CreateTask", json={"title": "My Task"})

        assert response.status_code == 200
        assert "reports" in response.json()
        client.close()
    ```
"""

import io;
import json;
import re;
import from http.server { BaseHTTPRequestHandler }
import from pathlib { Path }
import from typing { Any }
import from urllib.parse { urlencode }
import type from jaclang.runtimelib.server { JacAPIServer }

"""HTTP response wrapper for test assertions."""
obj TestResponse {
    has status_code: int,
        headers: dict[str, str],
        text: str,
        _json_cache: (dict[str, Any] | None) = None;

    def json -> dict[str, Any];
    @property
    def ok -> bool;

    @property
    def data -> (dict[str, Any] | None);
}

"""Test client for JacAPIServer - no socket/port required.

Provides a simple interface for testing Jac API endpoints without
network I/O. Handles authentication, request building, and response parsing.
"""
obj JacTestClient {
    has _jac_file: str,
        _base_path: str,
        _server: (JacAPIServer | None) = None,
        _handler_class: (type | None) = None,
        _auth_token: (str | None) = None,
        _current_user: (str | None) = None,
        _hot_reloader: (Any | None) = None;

    static def from_file(
        jac_file: str, base_path: (str | None) = None, module_name: (str | None) = None
    ) -> JacTestClient;

    def _ensure_initialized -> None;
    def get(
        path: str,
        params: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def post(
        path: str,
        json: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def put(
        path: str,
        json: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    def request(
        method: str,
        path: str,
        json: (dict[str, Any] | None) = None,
        params: (dict[str, Any] | None) = None,
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

    def _parse_response(raw_response: bytes) -> TestResponse;
    @property
    def server -> JacAPIServer;

    @property
    def user_manager -> Any;

    def reload -> None;
    def close -> None;
}
