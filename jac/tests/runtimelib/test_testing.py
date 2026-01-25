"""Tests for JacTestClient - the port-free test client."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang.runtimelib.testing import JacTestClient
from tests.runtimelib.conftest import fixture_abs_path


@pytest.fixture
def client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client with isolated base path."""
    from jaclang.runtimelib.testing import JacTestClient

    client = JacTestClient.from_file(
        fixture_abs_path("serve_api.jac"),
        base_path=str(tmp_path),
    )
    yield client
    client.close()


class TestJacTestClientBasics:
    """Basic tests for JacTestClient functionality."""

    def test_client_creation(self, tmp_path: Path) -> None:
        """Test that JacTestClient can be created from a .jac file."""
        from jaclang.runtimelib.testing import JacTestClient

        client = JacTestClient.from_file(
            fixture_abs_path("serve_api.jac"),
            base_path=str(tmp_path),
        )
        assert client is not None
        assert client._jac_file.endswith("serve_api.jac")
        client.close()

    def test_client_file_not_found(self, tmp_path: Path) -> None:
        """Test that JacTestClient raises error for missing file."""
        from jaclang.runtimelib.testing import JacTestClient

        with pytest.raises(FileNotFoundError):
            JacTestClient.from_file(
                "nonexistent.jac",
                base_path=str(tmp_path),
            )

    def test_get_root_endpoint(self, client: JacTestClient) -> None:
        """Test GET request to root endpoint."""
        response = client.get("/")

        assert response.ok
        assert response.status_code == 200
        assert "endpoints" in response.data

    def test_register_user(self, client: JacTestClient) -> None:
        """Test user registration."""
        response = client.register_user("testuser", "testpass")

        assert response.ok
        assert response.status_code == 201
        assert response.data["username"] == "testuser"
        assert "token" in response.data
        assert "root_id" in response.data
        # Token should be auto-set
        assert client._auth_token == response.data["token"]

    def test_login_user(self, client: JacTestClient) -> None:
        """Test user login."""
        # First register
        client.register_user("loginuser", "loginpass")
        client.clear_auth()

        # Then login
        response = client.login("loginuser", "loginpass")

        assert response.ok
        assert response.data["username"] == "loginuser"
        assert client._auth_token is not None

    def test_auth_token_management(self, client: JacTestClient) -> None:
        """Test auth token set/clear."""
        assert client._auth_token is None

        client.set_auth_token("test-token")
        assert client._auth_token == "test-token"

        client.clear_auth()
        assert client._auth_token is None

    def test_authentication_required(self, client: JacTestClient) -> None:
        """Test that protected endpoints require auth."""
        response = client.get("/protected")

        assert not response.ok
        assert "Unauthorized" in str(response.data)

    def test_list_functions_with_auth(self, client: JacTestClient) -> None:
        """Test listing functions with authentication."""
        client.register_user("funcuser", "pass")

        response = client.get("/functions")

        assert response.ok
        assert "functions" in response.data
        assert "add_numbers" in response.data["functions"]

    def test_call_function(self, client: JacTestClient) -> None:
        """Test calling a function."""
        client.register_user("calluser", "pass")

        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 25},
        )

        assert response.ok
        assert response.data["result"] == 35

    def test_list_walkers(self, client: JacTestClient) -> None:
        """Test listing walkers."""
        client.register_user("walkuser", "pass")

        response = client.get("/walkers")

        assert response.ok
        assert "walkers" in response.data
        assert "CreateTask" in response.data["walkers"]

    def test_spawn_walker(self, client: JacTestClient) -> None:
        """Test spawning a walker."""
        client.register_user("spawnuser", "pass")

        response = client.post(
            "/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
        )

        assert response.ok
        assert "result" in response.data or "reports" in response.data


class TestTestResponse:
    """Tests for TestResponse helper methods."""

    def test_response_ok_for_2xx(self, client: JacTestClient) -> None:
        """Test that ok property works for 2xx status codes."""
        response = client.get("/")
        assert response.ok
        assert response.status_code == 200

    def test_response_not_ok_for_4xx(self, client: JacTestClient) -> None:
        """Test that ok property is False for 4xx status codes."""
        response = client.get("/nonexistent-endpoint")
        assert not response.ok

    def test_response_json_parsing(self, client: JacTestClient) -> None:
        """Test that json() method parses response body."""
        response = client.get("/")
        json_data = response.json()

        assert isinstance(json_data, dict)
        assert "data" in json_data or "endpoints" in json_data

    def test_response_data_unwraps_envelope(self, client: JacTestClient) -> None:
        """Test that data property unwraps TransportResponse envelope."""
        response = client.get("/")

        # data should return the inner data, not the envelope
        assert response.data is not None
        assert "endpoints" in response.data
