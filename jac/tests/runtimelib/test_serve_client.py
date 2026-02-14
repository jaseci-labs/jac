"""Tests for JacAPIServer using JacTestClient (port-free).

This file mirrors the tests in test_serve.py but uses JacTestClient
instead of real HTTP connections, making tests faster and more reliable.
"""

from __future__ import annotations

import io
import logging
import shutil
import uuid
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path

import pytest

from jaclang.runtimelib.testing import JacTestClient
from tests.runtimelib.conftest import fixture_abs_path


@contextmanager
def _capture_log(
    logger: logging.Logger, level: int = logging.DEBUG
) -> Generator[io.StringIO, None, None]:
    """Temporarily attach a StringIO handler to *logger* and yield the buffer."""
    buf = io.StringIO()
    handler = logging.StreamHandler(buf)
    handler.setLevel(level)
    logger.addHandler(handler)
    old_level = logger.level
    logger.setLevel(level)
    try:
        yield buf
    finally:
        logger.removeHandler(handler)
        logger.setLevel(old_level)


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


class TestServerClientMigrated:
    """Migrated tests from test_serve.py using JacTestClient."""

    def test_user_creation(self, client: JacTestClient) -> None:
        """Test user creation endpoint (migrated from test_server_user_creation)."""
        response = client.post(
            "/user/register",
            json={"username": "alice", "password": "secret123"},
        )

        assert response.ok
        data = response.data
        assert "username" in data
        assert "token" in data
        assert "root_id" in data
        assert data["username"] == "alice"

    def test_user_login(self, client: JacTestClient) -> None:
        """Test user login endpoint (migrated from test_server_user_login)."""
        # Create user
        create_response = client.post(
            "/user/register",
            json={"username": "bob", "password": "pass456"},
        )
        create_data = create_response.data

        # Login with correct credentials
        login_response = client.post(
            "/user/login",
            json={"username": "bob", "password": "pass456"},
        )

        assert login_response.ok
        login_data = login_response.data
        assert "token" in login_data
        assert login_data["username"] == "bob"
        assert login_data["root_id"] == create_data["root_id"]

        # Login with wrong password
        client.clear_auth()
        fail_response = client.post(
            "/user/login",
            json={"username": "bob", "password": "wrongpass"},
        )

        assert not fail_response.ok or "error" in fail_response.json()

    def test_get_user_info_success(self, client: JacTestClient) -> None:
        """Test successfully getting user info after registration."""
        # Register a new user
        register_response = client.register_user("testuser", "testpass123")

        assert register_response.ok
        assert register_response.status_code == 201
        register_data = register_response.data
        assert "username" in register_data
        assert "token" in register_data
        assert "root_id" in register_data
        assert register_data["username"] == "testuser"

        # Store the expected values
        expected_username = register_data["username"]
        expected_token = register_data["token"]
        expected_root_id = register_data["root_id"]

        # Get user info (token should be auto-set by register_user)
        info_response = client.get("/user/info")

        assert info_response.ok
        assert info_response.status_code == 200
        info_data = info_response.data

        # Verify all fields match
        assert "username" in info_data
        assert "token" in info_data
        assert "root_id" in info_data
        assert info_data["username"] == expected_username
        assert info_data["token"] == expected_token
        assert info_data["root_id"] == expected_root_id

    def test_get_user_info_after_login(self, client: JacTestClient) -> None:
        """Test getting user info after login (not just registration)."""
        # Register a user using helper method
        register_response = client.register_user("loginuser", "loginpass456")

        assert register_response.ok
        register_data = register_response.data
        expected_username = register_data["username"]
        expected_root_id = register_data["root_id"]

        # Clear auth and login again using helper method
        client.clear_auth()
        login_response = client.login("loginuser", "loginpass456")

        assert login_response.ok
        login_data = login_response.data

        # Get user info with the login token
        info_response = client.get("/user/info")

        assert info_response.ok
        assert info_response.status_code == 200
        info_data = info_response.data

        # Verify the info matches both registration and login data
        assert info_data["username"] == expected_username
        assert info_data["username"] == login_data["username"]
        assert info_data["root_id"] == expected_root_id
        assert info_data["root_id"] == login_data["root_id"]
        assert info_data["token"] == login_data["token"]

    def test_get_user_info_requires_auth(self, client: JacTestClient) -> None:
        """Test that user info endpoint requires authentication."""
        # Try to get user info without authentication
        client.clear_auth()
        response = client.get("/user/info")

        assert not response.ok
        assert response.status_code == 401
        # Check response data if available, otherwise check text
        if response.data:
            assert "error" in response.data or "message" in response.data
        else:
            assert (
                "error" in response.text.lower()
                or "unauthorized" in response.text.lower()
            )

    def test_get_user_info_invalid_token(self, client: JacTestClient) -> None:
        """Test that user info endpoint rejects invalid token."""
        # Set invalid token
        client.set_auth_token("invalid_token_12345")
        response = client.get("/user/info")

        assert not response.ok
        assert response.status_code == 401
        # Check response data if available, otherwise check text
        if response.data:
            assert "error" in response.data or "message" in response.data
        else:
            assert (
                "error" in response.text.lower()
                or "unauthorized" in response.text.lower()
            )

    def test_get_user_info_different_users(self, client: JacTestClient) -> None:
        """Test that different users get their own info correctly."""
        # Register first user using helper method
        client.register_user("user1", "pass1")
        user1_info_response = client.get("/user/info")
        assert user1_info_response.ok
        user1_info = user1_info_response.data
        user1_token = user1_info["token"]

        # Register second user (this clears first user's auth)
        client.clear_auth()
        client.register_user("user2", "pass2")
        user2_info_response = client.get("/user/info")
        assert user2_info_response.ok
        user2_info = user2_info_response.data

        # Verify they are different users
        assert user1_info["username"] == "user1"
        assert user2_info["username"] == "user2"
        assert user1_info["root_id"] != user2_info["root_id"]
        assert user1_info["token"] != user2_info["token"]

        # Switch back to user1's token
        client.set_auth_token(user1_token)
        user1_info_again_response = client.get("/user/info")
        assert user1_info_again_response.ok
        user1_info_again = user1_info_again_response.data

        # Verify we get user1's info again
        assert user1_info_again["username"] == "user1"
        assert user1_info_again["root_id"] == user1_info["root_id"]
        assert user1_info_again["token"] == user1_info["token"]

    def test_authentication_required(self, client: JacTestClient) -> None:
        """Test that protected endpoints require authentication (migrated)."""
        response = client.get("/protected")

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_list_functions(self, client: JacTestClient) -> None:
        """Test listing functions endpoint (migrated from test_server_list_functions)."""
        # Create user and get token
        client.register_user("funcuser", "pass")

        # List functions
        response = client.get("/functions")

        assert response.ok
        data = response.data
        assert "functions" in data
        assert "add_numbers" in data["functions"]
        assert "greet" in data["functions"]

    def test_get_function_signature(self, client: JacTestClient) -> None:
        """Test getting function signature (migrated from test_server_get_function_signature)."""
        # Create user
        client.register_user("siguser", "pass")

        # Get signature
        response = client.get("/function/add_numbers")

        assert response.ok
        data = response.data
        assert "signature" in data
        sig = data["signature"]
        assert "parameters" in sig
        assert "a" in sig["parameters"]
        assert "b" in sig["parameters"]
        assert sig["parameters"]["a"]["required"] is True
        assert sig["parameters"]["b"]["required"] is True

    def test_call_function(self, client: JacTestClient) -> None:
        """Test calling a function endpoint (migrated from test_server_call_function)."""
        # Create user
        client.register_user("calluser", "pass")

        # Call add_numbers
        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 25},
        )

        assert response.ok
        data = response.data
        assert "result" in data
        assert data["result"] == 35

        # Call greet
        response2 = client.post(
            "/function/greet",
            json={"name": "World"},
        )

        assert response2.ok
        data2 = response2.data
        assert "result" in data2
        assert data2["result"] == "Hello, World!"

    def test_call_function_with_defaults(self, client: JacTestClient) -> None:
        """Test calling function with default parameters (migrated)."""
        # Create user
        client.register_user("defuser", "pass")

        # Call greet without name (should use default)
        response = client.post(
            "/function/greet",
            json={},
        )

        assert response.ok
        data = response.data
        assert "result" in data
        assert data["result"] == "Hello, World!"

    def test_list_walkers(self, client: JacTestClient) -> None:
        """Test listing walkers endpoint (migrated from test_server_list_walkers)."""
        # Create user
        client.register_user("walkuser", "pass")

        # List walkers
        response = client.get("/walkers")

        assert response.ok
        data = response.data
        assert "walkers" in data
        assert "CreateTask" in data["walkers"]
        assert "ListTasks" in data["walkers"]
        assert "CompleteTask" in data["walkers"]

    def test_get_walker_info(self, client: JacTestClient) -> None:
        """Test getting walker information (migrated from test_server_get_walker_info)."""
        # Create user
        client.register_user("infouser", "pass")

        # Get walker info
        response = client.get("/walker/CreateTask")

        assert response.ok
        data = response.data
        assert "info" in data
        info = data["info"]
        assert "fields" in info
        assert "title" in info["fields"]
        assert "priority" in info["fields"]
        assert "_jac_spawn_node" in info["fields"]

        # Check that priority has a default
        assert info["fields"]["priority"]["required"] is False
        assert info["fields"]["priority"]["default"] is not None

    def test_spawn_walker(self, client: JacTestClient) -> None:
        """Test spawning a walker (migrated from test_server_spawn_walker)."""
        # Create user
        client.register_user("spawnuser", "pass")

        # Spawn CreateTask walker
        response = client.post(
            "/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

        # Get jid from response for later use
        jid = data.get("reports", [{}])[0].get("_jac_id", "")

        # Spawn ListTasks walker to verify task was created
        response2 = client.post("/walker/ListTasks", json={})

        assert response2.ok
        data2 = response2.data
        assert "result" in data2 or "reports" in data2
        report = data2.get("reports", "")[0]
        assert "Test Task" in report[0].get("title", "")
        assert report[0].get("completed", False) is True

        # Get Task node using GetTask walker
        if jid:
            response3 = client.post(f"/walker/GetTask/{jid}", json={})
            assert response3.ok
            data3 = response3.data
            assert "result" in data3 or "reports" in data3

    def test_user_isolation(self, client: JacTestClient) -> None:
        """Test that users have isolated graph spaces (migrated from test_server_user_isolation)."""
        # Create two users
        user1_response = client.post(
            "/user/register",
            json={"username": "user1", "password": "pass1"},
        )
        user1_data = user1_response.data

        # Clear auth to register second user
        client.clear_auth()
        user2_response = client.post(
            "/user/register",
            json={"username": "user2", "password": "pass2"},
        )
        user2_data = user2_response.data

        # User1 creates a task
        client.set_auth_token(user1_data["token"])
        client.post(
            "/walker/CreateTask",
            json={"fields": {"title": "User1 Task", "priority": 1}},
        )

        # User2 creates a different task
        client.set_auth_token(user2_data["token"])
        client.post(
            "/walker/CreateTask",
            json={"fields": {"title": "User2 Task", "priority": 2}},
        )

        # Both users should have different root IDs
        assert user1_data["root_id"] != user2_data["root_id"]

    def test_invalid_function(self, client: JacTestClient) -> None:
        """Test calling nonexistent function (migrated from test_server_invalid_function)."""
        # Create user
        client.register_user("invaliduser", "pass")

        # Try to call nonexistent function
        response = client.post(
            "/function/nonexistent",
            json={},
        )

        # Should get error response
        assert not response.ok or "error" in response.json()

    def test_invalid_walker(self, client: JacTestClient) -> None:
        """Test spawning nonexistent walker (migrated from test_server_invalid_walker)."""
        # Create user
        client.register_user("invalidwalk", "pass")

        # Try to spawn nonexistent walker
        response = client.post(
            "/walker/NonExistentWalker",
            json={"fields": {}},
        )

        # Should get error response
        assert not response.ok or "error" in response.json()

    def test_server_root_endpoint(self, client: JacTestClient) -> None:
        """Test root endpoint returns API information (migrated)."""
        response = client.get("/")

        assert response.ok
        data = response.data
        assert "message" in data
        assert "endpoints" in data
        assert "POST /user/register" in data["endpoints"]
        assert "POST /user/login" in data["endpoints"]
        assert "GET /user/info" in data["endpoints"]
        assert "GET /functions" in data["endpoints"]
        assert "GET /walkers" in data["endpoints"]

    def test_update_username(self, client: JacTestClient) -> None:
        """Test update username endpoint."""
        # Create user
        create_response = client.post(
            "/user/register",
            json={"username": "olduser", "password": "pass123"},
        )
        assert create_response.ok
        token = create_response.data["token"]
        original_root_id = create_response.data["root_id"]

        # Update username
        client.set_auth_token(token)
        update_response = client.put(
            "/user/username",
            json={"current_username": "olduser", "new_username": "newuser"},
        )
        assert update_response.ok
        assert update_response.data["username"] == "newuser"
        assert update_response.data["root_id"] == original_root_id
        assert "token" in update_response.data

        # Login with new username should work
        client.clear_auth()
        login_response = client.login("newuser", "pass123")
        assert login_response.ok
        assert login_response.data["username"] == "newuser"

        # Login with old username should fail
        client.clear_auth()
        old_login_response = client.login("olduser", "pass123")
        assert not old_login_response.ok

    def test_update_username_requires_auth(self, client: JacTestClient) -> None:
        """Test that update username requires authentication."""
        # Create user
        client.post(
            "/user/register",
            json={"username": "authtest", "password": "pass123"},
        )

        # Clear auth and try to update without token
        client.clear_auth()
        response = client.put(
            "/user/username",
            json={"current_username": "authtest", "new_username": "newname"},
        )
        assert not response.ok
        assert response.status_code == 401

    def test_update_username_cannot_update_other_users(
        self, client: JacTestClient
    ) -> None:
        """Test that users cannot update other users' usernames."""
        # Create two users
        user1_response = client.post(
            "/user/register",
            json={"username": "user1", "password": "pass1"},
        )
        user1_token = user1_response.data["token"]

        client.clear_auth()
        client.post(
            "/user/register",
            json={"username": "user2", "password": "pass2"},
        )

        # User1 tries to update user2's username
        client.set_auth_token(user1_token)
        response = client.put(
            "/user/username",
            json={"current_username": "user2", "new_username": "hacked"},
        )
        assert not response.ok
        assert response.status_code == 403

    def test_update_username_already_exists(self, client: JacTestClient) -> None:
        """Test that updating to an existing username fails."""
        # Create first user and save token
        response1 = client.post(
            "/user/register",
            json={"username": "user_a", "password": "pass1"},
        )
        token = response1.data["token"]

        # Create second user
        client.clear_auth()
        client.post(
            "/user/register",
            json={"username": "user_b", "password": "pass2"},
        )

        # Try to update user_a to user_b (already exists) - MUST set token explicitly
        client.set_auth_token(token)
        response = client.put(
            "/user/username",
            json={"current_username": "user_a", "new_username": "user_b"},
        )

        # Should fail because user_b already exists
        assert not response.ok
        assert response.status_code == 400

    def test_update_password(self, client: JacTestClient) -> None:
        """Test update password endpoint."""
        # Create user
        create_response = client.post(
            "/user/register",
            json={"username": "passuser", "password": "oldpass"},
        )
        assert create_response.ok
        token = create_response.data["token"]

        # Update password
        client.set_auth_token(token)
        update_response = client.put(
            "/user/password",
            json={
                "username": "passuser",
                "current_password": "oldpass",
                "new_password": "newpass",
            },
        )
        assert update_response.ok
        assert update_response.data["username"] == "passuser"
        assert "message" in update_response.data

        # Login with new password should work
        client.clear_auth()
        login_response = client.login("passuser", "newpass")
        assert login_response.ok

        # Login with old password should fail
        client.clear_auth()
        old_login_response = client.login("passuser", "oldpass")
        assert not old_login_response.ok

    def test_update_password_requires_auth(self, client: JacTestClient) -> None:
        """Test that update password requires authentication."""
        # Create user
        client.post(
            "/user/register",
            json={"username": "noauthpass", "password": "pass123"},
        )

        # Try to update without token
        client.clear_auth()
        response = client.put(
            "/user/password",
            json={
                "username": "noauthpass",
                "current_password": "pass123",
                "new_password": "newpass",
            },
        )
        assert not response.ok
        assert response.status_code == 401

    def test_update_password_wrong_current(self, client: JacTestClient) -> None:
        """Test that update password fails with wrong current password."""
        # Create user
        create_response = client.post(
            "/user/register",
            json={"username": "wrongpass", "password": "correctpass"},
        )
        token = create_response.data["token"]

        # Try to update with wrong current password
        client.set_auth_token(token)
        response = client.put(
            "/user/password",
            json={
                "username": "wrongpass",
                "current_password": "wrongpassword",
                "new_password": "newpass",
            },
        )
        assert not response.ok
        assert response.status_code == 400

    def test_update_password_cannot_update_other_users(
        self, client: JacTestClient
    ) -> None:
        """Test that users cannot update other users' passwords."""
        # Create two users
        user1_response = client.post(
            "/user/register",
            json={"username": "pass_user1", "password": "pass1"},
        )
        user1_token = user1_response.data["token"]

        client.clear_auth()
        client.post(
            "/user/register",
            json={"username": "pass_user2", "password": "pass2"},
        )

        # User1 tries to update user2's password
        client.set_auth_token(user1_token)
        response = client.put(
            "/user/password",
            json={
                "username": "pass_user2",
                "current_password": "pass2",
                "new_password": "hacked",
            },
        )
        assert not response.ok
        assert response.status_code == 403


@pytest.fixture
def imports_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for serve_api_with_imports.jac."""
    from jaclang.runtimelib.testing import JacTestClient

    client = JacTestClient.from_file(
        fixture_abs_path("serve_api_with_imports.jac"),
        base_path=str(tmp_path),
    )
    yield client
    client.close()


class TestImportedFunctionsAndWalkers:
    """Tests for imported functions and walkers as API endpoints."""

    def test_imported_functions_and_walkers(
        self, imports_client: JacTestClient
    ) -> None:
        """Test that imported functions and walkers are available as API endpoints."""
        # Create user and get token
        imports_client.register_user("importuser", "pass")

        # Test listing functions - should include both local and imported
        functions_response = imports_client.get("/functions")
        assert functions_response.ok
        functions_data = functions_response.data
        assert "functions" in functions_data
        functions = functions_data["functions"]

        # Local functions should be available
        assert "local_add" in functions, "Local function 'local_add' not found"
        assert "local_greet" in functions, "Local function 'local_greet' not found"

        # Imported functions should also be available
        assert "multiply_numbers" in functions, (
            "Imported function 'multiply_numbers' not found"
        )
        assert "format_message" in functions, (
            "Imported function 'format_message' not found"
        )

        # Test listing walkers - should include both local and imported
        walkers_response = imports_client.get("/walkers")
        assert walkers_response.ok
        walkers_data = walkers_response.data
        assert "walkers" in walkers_data
        walkers = walkers_data["walkers"]

        # Local walker should be available
        assert "LocalCreateTask" in walkers, "Local walker 'LocalCreateTask' not found"

        # Imported walkers should also be available
        assert "ImportedWalker" in walkers, "Imported walker 'ImportedWalker' not found"
        assert "ImportedCounter" in walkers, (
            "Imported walker 'ImportedCounter' not found"
        )

        # Test calling local function
        local_add_response = imports_client.post(
            "/function/local_add",
            json={"x": 5, "y": 3},
        )
        assert local_add_response.ok
        local_add_data = local_add_response.data
        assert "result" in local_add_data
        assert local_add_data["result"] == 8

        # Test calling imported function
        multiply_response = imports_client.post(
            "/function/multiply_numbers",
            json={"a": 4, "b": 7},
        )
        assert multiply_response.ok
        multiply_data = multiply_response.data
        assert "result" in multiply_data
        assert multiply_data["result"] == 28

        # Test calling another imported function
        format_response = imports_client.post(
            "/function/format_message",
            json={"prefix": "INFO", "message": "test"},
        )
        assert format_response.ok
        format_data = format_response.data
        assert "result" in format_data
        assert format_data["result"] == "INFO: test"

        # Test spawning local walker
        local_walker_response = imports_client.post(
            "/walker/LocalCreateTask",
            json={"task_title": "My Local Task"},
        )
        assert local_walker_response.ok
        local_walker_data = local_walker_response.data
        assert "result" in local_walker_data or "reports" in local_walker_data

        # Test spawning imported walker
        imported_walker_response = imports_client.post(
            "/walker/ImportedWalker",
            json={"item_name": "Imported Item 1"},
        )
        assert imported_walker_response.ok
        imported_walker_data = imported_walker_response.data
        assert "result" in imported_walker_data or "reports" in imported_walker_data


@pytest.fixture
def access_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for serve_api_access.jac (access level tests)."""
    from jaclang.runtimelib.testing import JacTestClient

    client = JacTestClient.from_file(
        fixture_abs_path("serve_api_access.jac"),
        base_path=str(tmp_path),
    )
    yield client
    client.close()


class TestAccessLevels:
    """Tests for access level control (public, protected, private)."""

    def test_public_function_without_auth(self, access_client: JacTestClient) -> None:
        """Test that public functions can be called without authentication."""
        # Call public function without authentication
        response = access_client.post(
            "/function/public_function",
            json={"name": "Test"},
        )

        assert response.ok
        data = response.data
        assert "result" in data
        assert data["result"] == "Hello, Test! (public)"

    def test_public_function_get_info_without_auth(
        self, access_client: JacTestClient
    ) -> None:
        """Test that public function info can be retrieved without authentication."""
        # Get public function info without authentication
        response = access_client.get("/function/public_function")

        assert response.ok
        data = response.data
        assert "signature" in data
        assert "parameters" in data["signature"]

    def test_protected_function_requires_auth(
        self, access_client: JacTestClient
    ) -> None:
        """Test that protected functions require authentication."""
        # Try to call protected function without authentication - should fail
        response = access_client.post(
            "/function/protected_function",
            json={"message": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_protected_function_with_auth(self, access_client: JacTestClient) -> None:
        """Test that protected functions work with authentication."""
        # Create user and get token
        access_client.register_user("authuser", "pass123")

        # Call protected function with authentication
        response = access_client.post(
            "/function/protected_function",
            json={"message": "secret"},
        )

        assert response.ok
        data = response.data
        assert "result" in data
        assert data["result"] == "Protected: secret"

    def test_private_function_requires_auth(self, access_client: JacTestClient) -> None:
        """Test that private functions require authentication."""
        # Try to call private function without authentication - should fail
        response = access_client.post(
            "/function/private_function",
            json={"secret": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_private_function_with_auth(self, access_client: JacTestClient) -> None:
        """Test that private functions work with authentication."""
        # Create user and get token
        access_client.register_user("privuser", "pass456")

        # Call private function with authentication
        response = access_client.post(
            "/function/private_function",
            json={"secret": "topsecret"},
        )

        assert response.ok
        data = response.data
        assert "result" in data
        assert data["result"] == "Private: topsecret"

    def test_public_walker_without_auth(self, access_client: JacTestClient) -> None:
        """Test that public walkers can be spawned without authentication."""
        # Spawn public walker without authentication
        response = access_client.post(
            "/walker/PublicWalker",
            json={"message": "hello"},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

    def test_protected_walker_requires_auth(self, access_client: JacTestClient) -> None:
        """Test that protected walkers require authentication."""
        # Try to spawn protected walker without authentication - should fail
        response = access_client.post(
            "/walker/ProtectedWalker",
            json={"data": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_protected_walker_with_auth(self, access_client: JacTestClient) -> None:
        """Test that protected walkers work with authentication."""
        # Create user and get token
        access_client.register_user("walkuser", "pass789")

        # Spawn protected walker with authentication
        response = access_client.post(
            "/walker/ProtectedWalker",
            json={"data": "mydata"},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

    def test_private_walker_requires_auth(self, access_client: JacTestClient) -> None:
        """Test that private walkers require authentication."""
        # Try to spawn private walker without authentication - should fail
        response = access_client.post(
            "/walker/PrivateWalker",
            json={"secret": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_private_walker_with_auth(self, access_client: JacTestClient) -> None:
        """Test that private walkers work with authentication."""
        # Create user and get token
        access_client.register_user("privwalk", "pass000")

        # Spawn private walker with authentication
        response = access_client.post(
            "/walker/PrivateWalker",
            json={"secret": "verysecret"},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

    def test_introspection_list_requires_auth(
        self, access_client: JacTestClient
    ) -> None:
        """Test that introspection list endpoints require authentication."""
        # Try to access protected endpoint without authentication - should fail
        response = access_client.get("/protected")

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_mixed_access_levels(self, access_client: JacTestClient) -> None:
        """Test server with mixed access levels (public, protected, private)."""
        # Create authenticated user
        access_client.register_user("mixeduser", "mixedpass")
        token = access_client._auth_token

        # Public function without auth - should work
        access_client.clear_auth()
        result1 = access_client.post(
            "/function/public_add",
            json={"a": 5, "b": 10},
        )
        data1 = result1.data
        assert "result" in data1
        assert data1["result"] == 15

        # Protected function without auth - should fail
        result2 = access_client.post(
            "/function/protected_function",
            json={"message": "test"},
        )
        data2 = result2.data
        assert "error" in data2

        # Protected function with auth - should work
        access_client.set_auth_token(token)
        result3 = access_client.post(
            "/function/protected_function",
            json={"message": "test"},
        )
        data3 = result3.data
        assert "result" in data3

        # Private function with auth - should work
        result4 = access_client.post(
            "/function/private_function",
            json={"secret": "test"},
        )
        data4 = result4.data
        assert "result" in data4


@pytest.fixture
def client_app_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for client_app.jac with isolated fixtures.

    Copies fixtures to temp directory with unique module names to prevent
    parallel test interference with shared .jac cache.
    """
    fixtures_src = Path(fixture_abs_path("")).resolve()
    # Use unique module name to avoid parallel test conflicts
    unique_id = uuid.uuid4().hex[:8]
    module_name = f"client_app_{unique_id}"
    fixtures_dest = tmp_path / module_name
    fixtures_dest.mkdir(parents=True, exist_ok=True)

    # Copy .jac source files, renaming client_app.jac to unique module name
    for f in fixtures_src.glob("*.jac"):
        if f.is_file():
            dest_name = f.name
            if f.name == "client_app.jac":
                dest_name = f"{module_name}.jac"
            shutil.copy(f, fixtures_dest / dest_name)

    client = JacTestClient.from_file(
        str(fixtures_dest / f"{module_name}.jac"),
        base_path=str(fixtures_dest),
        module_name=module_name,
    )
    yield client
    client.close()


class TestClientRendering:
    """Tests for client-side rendering functionality."""

    def test_render_client_page_returns_html(
        self, client_app_client: JacTestClient
    ) -> None:
        """Test that client page endpoint returns proper HTML (migrated)."""
        import json
        import re

        # Create user for authentication
        client_app_client.register_user("tester", "pass")

        # Request the client page
        response = client_app_client.get("/cl/client_page")

        # The response should be HTML (not JSON), so we check the text directly
        html = response.text

        # Check basic HTML structure
        assert "<!DOCTYPE html>" in html
        assert '<div id="__jac_root">' in html
        assert "/static/client.js?hash=" in html

        # Check __jac_init__ script contains expected data
        init_match = re.search(
            r'<script id="__jac_init__" type="application/json">([^<]*)</script>',
            html,
        )
        assert init_match is not None
        payload = json.loads(init_match.group(1)) if init_match else {}
        assert payload.get("function") == "client_page"
        assert payload.get("globals", {}).get("API_LABEL") == "Runtime Test"

    def test_render_unknown_page_returns_error(
        self, client_app_client: JacTestClient
    ) -> None:
        """Test that rendering unknown page returns error (migrated)."""
        # Create user for authentication
        client_app_client.register_user("tester", "pass")

        # Request a non-existent client page
        response = client_app_client.get("/cl/missing")

        # Should get error response (404 or error message)
        assert not response.ok or "error" in response.text.lower()


# =============================================================================
# Fullstack Client App Test (has + async can with entry)
# =============================================================================


@pytest.fixture
def fullstack_app_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for client_fullstack_app.jac."""
    client = JacTestClient.from_file(
        fixture_abs_path("client_fullstack_app.jac"),
        base_path=str(tmp_path),
    )
    yield client
    client.close()


class TestFullstackClientApp:
    """Test a fullstack Jac app that uses has (useState) and async can with entry (useEffect)."""

    def test_client_page_html_and_bundle(
        self, fullstack_app_client: JacTestClient
    ) -> None:
        """Test that /cl/app serves correct HTML with hydration payload and a valid bundle."""
        import json
        import re

        response = fullstack_app_client.get("/cl/app")
        html = response.text

        # HTML skeleton
        assert "<!DOCTYPE html>" in html
        assert '<div id="__jac_root">' in html
        assert "/static/client.js?hash=" in html

        # Hydration payload targets the right function
        init_match = re.search(
            r'<script id="__jac_init__" type="application/json">([^<]*)</script>',
            html,
        )
        assert init_match is not None
        payload = json.loads(init_match.group(1))
        assert payload.get("function") == "app"

        # Fetch JS bundle
        hash_match = re.search(r"/static/client\.js\?hash=([a-f0-9]+)", html)
        assert hash_match is not None
        bundle_js = fullstack_app_client.get(
            f"/static/client.js?hash={hash_match.group(1)}"
        ).text

        # @jac/runtime inlined (not left as ES import)
        assert "// @jac/runtime" in bundle_js
        assert "import {" not in bundle_js

        # has → useState hook present
        assert "function useState(" in bundle_js
        assert "useState([])" in bundle_js

        # async can with entry → useEffect present
        assert "function useEffect(" in bundle_js
        assert "useEffect(" in bundle_js

        # Server function call wired up
        assert "__jacCallFunction" in bundle_js
        assert '"get_items"' in bundle_js

        # Module registered
        assert "__jacRegisterClientModule" in bundle_js
        assert "function app()" in bundle_js


# =============================================================================
# Imported Walker Access Level Tests (GitHub Issue #4145)
# =============================================================================


@pytest.fixture
def imported_access_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for serve_api_with_access_imports.jac.

    This tests that :pub access modifier is recognized on imported walkers.
    """
    from jaclang.runtimelib.testing import JacTestClient

    client = JacTestClient.from_file(
        fixture_abs_path("serve_api_with_access_imports.jac"),
        base_path=str(tmp_path),
    )
    yield client
    client.close()


class TestImportedWalkerAccessLevels:
    """Tests for access level control on imported walkers (GitHub Issue #4145).

    This tests the fix for the bug where :pub access modifier was not
    recognized on walkers imported from other modules.
    """

    def test_imported_public_walker_without_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that imported public walkers can be spawned without authentication.

        This is the core test for GitHub Issue #4145 - walkers marked with :pub
        in their source module should be accessible without authentication even
        when imported into another module.
        """
        # Spawn imported public walker without authentication
        response = imported_access_client.post(
            "/walker/PublicImportedWalker",
            json={"message": "test from imported public walker"},
        )

        assert response.ok, f"Expected success but got: {response.data}"
        data = response.data
        assert "result" in data or "reports" in data

    def test_imported_protected_walker_requires_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that imported protected walkers require authentication."""
        # Try to spawn imported protected walker without authentication
        response = imported_access_client.post(
            "/walker/ProtectedImportedWalker",
            json={"data": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_imported_protected_walker_with_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that imported protected walkers work with authentication."""
        # Create user and get token
        imported_access_client.register_user("importuser", "pass123")

        # Spawn imported protected walker with authentication
        response = imported_access_client.post(
            "/walker/ProtectedImportedWalker",
            json={"data": "authenticated data"},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

    def test_imported_default_walker_requires_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that imported walkers without access modifier require auth.

        Walkers without explicit :pub, :protect, or :priv should default
        to requiring authentication (secure by default).
        """
        # Try to spawn imported default walker without authentication
        response = imported_access_client.post(
            "/walker/DefaultImportedWalker",
            json={"value": 100},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_local_public_walker_without_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that local public walkers still work (baseline test)."""
        # Spawn local public walker without authentication
        response = imported_access_client.post(
            "/walker/LocalPublicWalker",
            json={"msg": "local test"},
        )

        assert response.ok
        data = response.data
        assert "result" in data or "reports" in data

    def test_local_default_walker_requires_auth(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test that local default walkers require auth (baseline test)."""
        # Try to spawn local default walker without authentication
        response = imported_access_client.post(
            "/walker/LocalDefaultWalker",
            json={"msg": "test"},
        )

        assert not response.ok
        data = response.data
        assert "error" in data
        assert "Unauthorized" in data["error"]

    def test_mixed_local_and_imported_access(
        self, imported_access_client: JacTestClient
    ) -> None:
        """Test server with mix of local and imported walkers with different access levels."""
        # Create authenticated user
        imported_access_client.register_user("mixeduser", "mixedpass")
        token = imported_access_client._auth_token

        # Imported public walker without auth - should work
        imported_access_client.clear_auth()
        result1 = imported_access_client.post(
            "/walker/PublicImportedWalker",
            json={"message": "public test"},
        )
        assert result1.ok, (
            f"Imported public walker should work without auth: {result1.data}"
        )

        # Local public walker without auth - should work
        result2 = imported_access_client.post(
            "/walker/LocalPublicWalker",
            json={"msg": "local public test"},
        )
        assert result2.ok, (
            f"Local public walker should work without auth: {result2.data}"
        )

        # Imported protected walker without auth - should fail
        result3 = imported_access_client.post(
            "/walker/ProtectedImportedWalker",
            json={"data": "test"},
        )
        assert not result3.ok, "Imported protected walker should require auth"

        # Local default walker without auth - should fail
        result4 = imported_access_client.post(
            "/walker/LocalDefaultWalker",
            json={"msg": "test"},
        )
        assert not result4.ok, "Local default walker should require auth"

        # With auth, all walkers should work
        imported_access_client.set_auth_token(token)

        result5 = imported_access_client.post(
            "/walker/ProtectedImportedWalker",
            json={"data": "auth test"},
        )
        assert result5.ok, (
            f"Imported protected walker should work with auth: {result5.data}"
        )

        result6 = imported_access_client.post(
            "/walker/DefaultImportedWalker",
            json={"value": 42},
        )
        assert result6.ok, (
            f"Imported default walker should work with auth: {result6.data}"
        )

        result7 = imported_access_client.post(
            "/walker/LocalDefaultWalker",
            json={"msg": "auth test"},
        )
        assert result7.ok, f"Local default walker should work with auth: {result7.data}"


# =============================================================================
# SPA Catch-All Tests (BrowserRouter support)
# =============================================================================


@pytest.fixture
def spa_client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client with base_route_app configured for SPA catch-all."""
    from jaclang.project.config import JacConfig, ServeConfig, set_config

    fixtures_src = Path(fixture_abs_path("")).resolve()
    unique_id = uuid.uuid4().hex[:8]
    module_name = f"spa_app_{unique_id}"
    fixtures_dest = tmp_path / module_name
    fixtures_dest.mkdir(parents=True, exist_ok=True)

    # Copy .jac source files, renaming client_app.jac to unique module name
    for f in fixtures_src.glob("*.jac"):
        if f.is_file():
            dest_name = f.name
            if f.name == "client_app.jac":
                dest_name = f"{module_name}.jac"
            shutil.copy(f, fixtures_dest / dest_name)

    set_config(JacConfig(serve=ServeConfig(base_route_app="client_page")))

    client = JacTestClient.from_file(
        str(fixtures_dest / f"{module_name}.jac"),
        base_path=str(fixtures_dest),
        module_name=module_name,
    )
    yield client
    client.close()
    # Reset config to defaults to avoid leaking into other tests
    set_config(JacConfig())


class TestSPACatchAll:
    """Tests for SPA catch-all routing (BrowserRouter support)."""

    def test_spa_catchall_serves_html_for_clean_urls(
        self, spa_client: JacTestClient
    ) -> None:
        """GET to unknown extensionless path should serve SPA HTML."""
        response = spa_client.get("/about")

        assert response.ok
        assert response.status_code == 200
        html = response.text
        assert "<!DOCTYPE html>" in html
        assert '<div id="__jac_root">' in html
        assert "/static/client.js?hash=" in html

    def test_spa_catchall_root_serves_html(self, spa_client: JacTestClient) -> None:
        """GET / should serve SPA HTML when base_route_app is configured."""
        response = spa_client.get("/")

        assert response.ok
        html = response.text
        assert "<!DOCTYPE html>" in html
        assert '<div id="__jac_root">' in html

    def test_spa_catchall_nested_path(self, spa_client: JacTestClient) -> None:
        """GET to nested path like /dashboard/settings should serve SPA HTML."""
        response = spa_client.get("/dashboard/settings")

        assert response.ok
        html = response.text
        assert "<!DOCTYPE html>" in html

    def test_spa_catchall_api_paths_unaffected(self, spa_client: JacTestClient) -> None:
        """API paths should still return JSON, not SPA HTML."""
        functions_response = spa_client.get("/functions")
        assert functions_response.ok
        data = functions_response.data
        assert "functions" in data

        walkers_response = spa_client.get("/walkers")
        assert walkers_response.ok
        data = walkers_response.data
        assert "walkers" in data

    def test_spa_catchall_cl_route_still_works(self, spa_client: JacTestClient) -> None:
        """Explicit /cl/ route should still render the page directly."""
        response = spa_client.get("/cl/client_page")

        assert response.ok
        html = response.text
        assert "<!DOCTYPE html>" in html
        assert '<div id="__jac_root">' in html

    def test_spa_catchall_static_files_unaffected(
        self, spa_client: JacTestClient
    ) -> None:
        """Static file paths should not be caught by SPA catch-all."""
        response = spa_client.get("/static/nonexistent.js")

        assert not response.ok

    def test_unknown_path_returns_404_without_base_route_app(
        self, client: JacTestClient
    ) -> None:
        """Without base_route_app configured, unknown paths should return 404."""
        from jaclang.project.config import JacConfig, set_config

        set_config(JacConfig())
        response = client.get("/some-unknown-path")

        assert not response.ok
        data = response.data
        assert "error" in data


class TestSyncAccessControl:
    """Tests for memory sync not producing spurious write access warnings."""

    def test_sync_skips_write_access_check_on_unchanged_anchors(
        self, client: JacTestClient
    ) -> None:
        """SqliteMemory.sync() must not call check_write_access() for anchors
        whose access and archetype fields have not changed since last persist.

        Regression test: sync() used to call check_write_access() unconditionally
        on every persistent anchor, even unchanged ones.  When the system root
        (owned by nobody / the super-root) was present in L3 memory — e.g. after
        a server restart that loaded it from the database — every authenticated
        user commit would log a spurious INFO warning:
            "Current root doesn't have write access to NodeAnchor Root[0000…]"
        """
        import logging

        # Register a user so subsequent requests run as a non-system root.
        client.register_user("syncuser", "pass")

        # -- Simulate server-restart conditions --
        # After a restart the system root is loaded from the DB into L3's
        # in-memory dict and marked persistent.  On a fresh test run neither
        # happens, so we replicate it manually.
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac

        ctx = Jac.get_context()
        sys_root = ctx.system_root

        # Simulate a DB round-trip: after a server restart the system root is
        # loaded from SQLite via pickle, which makes it persistent with a
        # non-zero hash (the access-level check short-circuits on hash==0).
        sys_root.persistent = True
        from pickle import dumps, loads

        sys_root_copy = loads(dumps(sys_root))  # round-trip sets hash
        sys_root.__dict__.update(sys_root_copy.__dict__)
        sys_root.persistent = True
        sys_root.hash = hash(dumps(sys_root))  # non-zero like after real DB load

        # Ensure it is present in L3's __mem__ (simulates DB read-through)
        l3 = ctx.mem.l3
        if l3 is not None:
            l3.put(sys_root)
            # Persist it so sync() finds a stored copy to compare against
            l3._ensure_connection()
            l3.__conn__.execute(
                "INSERT OR REPLACE INTO anchors (id, data) VALUES (?, ?)",
                (str(sys_root.id), dumps(sys_root)),
            )
            l3.__conn__.commit()

        # Capture logs from the runtime module where check_write_access logs
        logger = logging.getLogger("jaclang.jac0core.runtime")
        with _capture_log(logger) as log_output:
            # Spawn walkers that read/write the graph — each commit triggers sync()
            client.post(
                "/walker/CreateTask",
                json={"title": "Sync Test", "priority": 1},
            )
            client.post("/walker/ListTasks", json={})

        # The system root warning must NOT appear
        assert "Current root doesn't have write access" not in log_output.getvalue(), (
            "SqliteMemory.sync() should not check write access on unchanged anchors"
        )
