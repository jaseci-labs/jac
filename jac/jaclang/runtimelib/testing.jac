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
import from typing { TYPE_CHECKING, Any }
import from urllib.parse { urlencode }

with entry {
    if TYPE_CHECKING {
        import from jaclang.runtimelib.server { JacAPIServer }
    }
}

"""HTTP response wrapper for test assertions."""
obj TestResponse {
    has status_code: int,
        headers: dict[str, str],
        text: str,
        _json_cache: (dict[str, Any] | None) = None;

    """Parse response body as JSON."""
    def json -> dict[str, Any];

    """Check if response indicates success (2xx status)."""
    @property
    def ok -> bool;

    """Get data from response, handling TransportResponse envelope."""
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
        _current_user: (str | None) = None;

    """Create test client from a .jac file path."""
    static def from_file(
        jac_file: str, base_path: (str | None) = None, module_name: (str | None) = None
    ) -> JacTestClient;

    """Initialize server and handler (lazy loading)."""
    def _ensure_initialized -> None;

    """Make a GET request."""
    def get(
        path: str,
        params: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    """Make a POST request with JSON body."""
    def post(
        path: str,
        json: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    """Make a PUT request with JSON body."""
    def put(
        path: str,
        json: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    """Make a request with specified method."""
    def request(
        method: str,
        path: str,
        json: (dict[str, Any] | None) = None,
        params: (dict[str, Any] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    """Set authentication token for subsequent requests."""
    def set_auth_token(token: str) -> None;

    """Clear authentication token."""
    def clear_auth -> None;

    """Register a new user and set auth token."""
    def register_user(username: str, password: str) -> TestResponse;

    """Login existing user and set auth token."""
    def login(username: str, password: str) -> TestResponse;

    """Internal: Execute request through mock handler."""
    def _execute_request(
        method: str,
        path: str,
        body: (bytes | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> TestResponse;

    """Internal: Parse raw HTTP response."""
    def _parse_response(raw_response: bytes) -> TestResponse;

    """Get the underlying server instance."""
    @property
    def server -> JacAPIServer;

    """Get the user manager for direct manipulation."""
    @property
    def user_manager -> Any;

    """Reload the module (for HMR testing).

    This simulates what the HotReloader does when a file changes,
    allowing HMR functionality to be tested without real servers.
    """
    def reload -> None;

    """Cleanup resources."""
    def close -> None;
}
