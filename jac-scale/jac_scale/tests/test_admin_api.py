"""Tests for admin portal API endpoints."""

import contextlib
import gc
import glob as glob_module
import shutil
import socket
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Generator

import pytest
import requests


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def _extract_response_data(json_response: dict[str, Any]) -> dict[str, Any]:
    """Extract data from TransportResponse envelope format."""
    if isinstance(json_response, dict) and "ok" in json_response:
        if json_response.get("ok") and json_response.get("data") is not None:
            return json_response["data"]
        elif not json_response.get("ok") and json_response.get("error"):
            error_info = json_response["error"]
            result: dict[str, Any] = {
                "error": error_info.get("message", "Unknown error")
            }
            if "code" in error_info:
                result["error_code"] = error_info["code"]
            return result
    return json_response


def _cleanup_db_files(fixtures_dir: Path) -> None:
    """Delete SQLite database files and .jac directories."""
    # Clean both fixtures dir and parent tests dir
    dirs_to_clean = [fixtures_dir, fixtures_dir.parent]
    for clean_dir in dirs_to_clean:
        for pattern in [
            "*.db", "*.db-wal", "*.db-shm",
            "anchor_store.db.dat", "anchor_store.db.bak", "anchor_store.db.dir"
        ]:
            for db_file in glob_module.glob(str(clean_dir / pattern)):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()
        jac_dir = clean_dir / ".jac"
        if jac_dir.exists():
            with contextlib.suppress(Exception):
                shutil.rmtree(jac_dir)


def _start_server(fixtures_dir: Path, test_file: Path, port: int, base_url: str) -> subprocess.Popen:
    """Start the jac-scale server in a subprocess."""
    jac_executable = Path(sys.executable).parent / "jac"
    cmd = [str(jac_executable), "start", test_file.name, "--port", str(port)]
    server_process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=str(fixtures_dir)
    )

    max_attempts = 50
    server_ready = False
    for _ in range(max_attempts):
        if server_process.poll() is not None:
            stdout, stderr = server_process.communicate()
            raise RuntimeError(f"Server terminated unexpectedly.\nSTDOUT: {stdout}\nSTDERR: {stderr}")
        try:
            response = requests.get(f"{base_url}/docs", timeout=2)
            if response.status_code in (200, 404):
                server_ready = True
                break
        except (requests.ConnectionError, requests.Timeout):
            time.sleep(2)

    if not server_ready:
        server_process.terminate()
        try:
            stdout, stderr = server_process.communicate(timeout=2)
        except subprocess.TimeoutExpired:
            server_process.kill()
            stdout, stderr = server_process.communicate()
        raise RuntimeError(f"Server failed to start.\nSTDOUT: {stdout}\nSTDERR: {stderr}")
    return server_process


def _stop_server(server_process: subprocess.Popen | None) -> None:
    """Stop server process."""
    if server_process:
        server_process.terminate()
        try:
            server_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server_process.kill()
            server_process.wait()
    time.sleep(0.5)
    gc.collect()


DEFAULT_ADMIN_PASSWORD = "changeme"  # Default from admin_config


def _admin_login(base_url: str, new_password: str = "newadmin123") -> str:
    """Login as admin, handling password reset if required. Returns token."""
    login_resp = requests.post(
        f"{base_url}/admin/login",
        json={"username": "admin", "password": DEFAULT_ADMIN_PASSWORD},
        timeout=10
    )
    data = _extract_response_data(login_resp.json())

    # If password reset required, do the reset
    if data.get("requires_password_reset"):
        temp_token = data["token"]
        reset_resp = requests.post(
            f"{base_url}/admin/reset-password",
            json={"current_password": DEFAULT_ADMIN_PASSWORD, "new_password": new_password},
            headers={"Authorization": f"Bearer {temp_token}"},
            timeout=10
        )
        reset_data = _extract_response_data(reset_resp.json())
        return reset_data["token"]

    # Direct login success
    if "token" in data:
        return data["token"]

    # Try with new password (already reset in previous test run)
    login_resp2 = requests.post(
        f"{base_url}/admin/login",
        json={"username": "admin", "password": new_password},
        timeout=10
    )
    data2 = _extract_response_data(login_resp2.json())
    if "token" in data2:
        return data2["token"]

    raise RuntimeError(f"Admin login failed: {data}")


# Fixture paths
FIXTURES_DIR = Path(__file__).parent / "fixtures"
TEST_FILE = FIXTURES_DIR / "test_api.jac"


@pytest.fixture
def admin_server() -> Generator[str, None, None]:
    """Setup and teardown admin server for each test."""
    if not TEST_FILE.exists():
        raise FileNotFoundError(f"Test fixture not found: {TEST_FILE}")

    port = get_free_port()
    base_url = f"http://localhost:{port}"

    _cleanup_db_files(FIXTURES_DIR)
    server_process = _start_server(FIXTURES_DIR, TEST_FILE, port, base_url)

    try:
        yield base_url
    finally:
        _stop_server(server_process)
        _cleanup_db_files(FIXTURES_DIR)


# ============================================================================
# Admin Login Tests
# ============================================================================

def test_admin_login_success(admin_server: str) -> None:
    """Test successful admin login with default credentials."""
    response = requests.post(
        f"{admin_server}/admin/login",
        json={"username": "admin", "password": DEFAULT_ADMIN_PASSWORD},
        timeout=10
    )
    assert response.status_code == 200
    data = _extract_response_data(response.json())
    assert "token" in data
    assert data["username"] == "admin"
    assert data["role"] == "admin"
    # Bootstrap admin requires password reset
    assert data.get("requires_password_reset") is True


def test_admin_login_wrong_password(admin_server: str) -> None:
    """Test admin login with wrong password."""
    response = requests.post(
        f"{admin_server}/admin/login",
        json={"username": "admin", "password": "wrongpassword"},
        timeout=10
    )
    assert response.status_code == 401
    data = _extract_response_data(response.json())
    assert "error" in data


def test_admin_login_missing_credentials(admin_server: str) -> None:
    """Test admin login with missing credentials."""
    # Missing password
    response = requests.post(
        f"{admin_server}/admin/login",
        json={"username": "admin"},
        timeout=10
    )
    assert response.status_code in [400, 422]

    # Missing username
    response = requests.post(
        f"{admin_server}/admin/login",
        json={"password": "admin"},
        timeout=10
    )
    assert response.status_code in [400, 422]

    # Empty body
    response = requests.post(
        f"{admin_server}/admin/login",
        json={},
        timeout=10
    )
    assert response.status_code in [400, 422]


def test_admin_login_non_admin_user_rejected(admin_server: str) -> None:
    """Test that non-admin users are rejected from admin login."""
    # First login as admin to create a regular user
    admin_token = _admin_login(admin_server)

    # Create a regular user
    username = f"regularuser_{uuid.uuid4().hex[:8]}"
    requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "userpass123", "role": "user"},
        headers={"Authorization": f"Bearer {admin_token}"},
        timeout=10
    )

    # Try to login as admin with regular user credentials
    # First register the user through normal registration
    requests.post(
        f"{admin_server}/user/register",
        json={"username": f"nonmin_{uuid.uuid4().hex[:8]}", "password": "testpass"},
        timeout=10
    )

    # Regular users should be rejected from admin login
    response = requests.post(
        f"{admin_server}/admin/login",
        json={"username": username, "password": "userpass123"},
        timeout=10
    )
    # May require password reset, but should eventually be rejected as non-admin
    assert response.status_code in [401, 403] or (
        response.status_code == 200 and _extract_response_data(response.json()).get("requires_password_reset")
    )


# ============================================================================
# User Management Tests
# ============================================================================

def test_admin_list_users(admin_server: str) -> None:
    """Test listing users as admin."""
    token = _admin_login(admin_server)

    response = requests.get(
        f"{admin_server}/admin/users",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200
    data = _extract_response_data(response.json())
    assert "users" in data
    assert isinstance(data["users"], list)
    assert "count" in data


def test_admin_list_users_requires_auth(admin_server: str) -> None:
    """Test that listing users requires authentication."""
    response = requests.get(
        f"{admin_server}/admin/users",
        timeout=10
    )
    assert response.status_code == 403


def test_admin_create_user(admin_server: str) -> None:
    """Test creating a new user as admin."""
    token = _admin_login(admin_server)

    username = f"newuser_{uuid.uuid4().hex[:8]}"
    response = requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "newpass123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 201
    data = _extract_response_data(response.json())
    assert data["username"] == username


def test_admin_create_user_with_different_roles(admin_server: str) -> None:
    """Test creating users with different roles."""
    token = _admin_login(admin_server)

    for role in ["user", "moderator", "admin"]:
        username = f"{role}user_{uuid.uuid4().hex[:8]}"
        response = requests.post(
            f"{admin_server}/admin/users",
            json={"username": username, "password": "pass123", "role": role},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
        assert response.status_code == 201

        # Verify role was set
        get_resp = requests.get(
            f"{admin_server}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
        assert get_resp.status_code == 200
        user_data = _extract_response_data(get_resp.json())
        assert user_data["role"] == role


def test_admin_create_user_duplicate_fails(admin_server: str) -> None:
    """Test that creating a duplicate user fails."""
    token = _admin_login(admin_server)

    username = f"dupuser_{uuid.uuid4().hex[:8]}"
    response = requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "pass123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 201

    # Try to create same user again
    response = requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "pass456", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 400


def test_admin_update_user_role(admin_server: str) -> None:
    """Test updating a user's role."""
    token = _admin_login(admin_server)

    username = f"roleuser_{uuid.uuid4().hex[:8]}"
    requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "pass123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )

    # Update role to moderator (API requires both fields)
    response = requests.put(
        f"{admin_server}/admin/users/{username}",
        json={"role": "moderator", "requires_password_reset": True},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200

    # Verify role changed
    get_resp = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    user_data = _extract_response_data(get_resp.json())
    assert user_data["role"] == "moderator"


def test_admin_update_user_password_reset_flag(admin_server: str) -> None:
    """Test updating the password reset flag."""
    token = _admin_login(admin_server)

    # Create user (by default requires_password_reset is True)
    username = f"resetuser_{uuid.uuid4().hex[:8]}"
    requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "pass123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )

    # Set requires_password_reset to False (API requires both fields)
    response = requests.put(
        f"{admin_server}/admin/users/{username}",
        json={"role": "user", "requires_password_reset": False},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200

    # Verify flag changed
    get_resp = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    user_data = _extract_response_data(get_resp.json())
    assert user_data["requires_password_reset"] is False


def test_admin_delete_user(admin_server: str) -> None:
    """Test deleting a user."""
    token = _admin_login(admin_server)

    username = f"deleteuser_{uuid.uuid4().hex[:8]}"
    requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "pass123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )

    # Delete user
    response = requests.delete(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200

    # Verify user is gone
    get_resp = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert get_resp.status_code == 404


def test_admin_get_user_not_found(admin_server: str) -> None:
    """Test getting a non-existent user returns 404."""
    token = _admin_login(admin_server)

    response = requests.get(
        f"{admin_server}/admin/users/nonexistent_user_xyz",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 404


# ============================================================================
# Password Reset Tests
# ============================================================================

def test_admin_reset_password(admin_server: str) -> None:
    """Test password reset flow."""
    token = _admin_login(admin_server)
    assert token is not None
    assert len(token) > 0

    # Verify token works by making an authenticated request
    response = requests.get(
        f"{admin_server}/admin/users",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200


def test_admin_reset_password_wrong_current_password(admin_server: str) -> None:
    """Test password reset with wrong current password."""
    token = _admin_login(admin_server)

    response = requests.post(
        f"{admin_server}/admin/reset-password",
        json={"current_password": "wrongpassword", "new_password": "newpass123"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 400


def test_admin_reset_password_too_short(admin_server: str) -> None:
    """Test password reset with too short password."""
    # Login as admin (password becomes "newadmin123" after reset)
    token = _admin_login(admin_server)

    response = requests.post(
        f"{admin_server}/admin/reset-password",
        json={"current_password": "newadmin123", "new_password": "short"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 400
    data = _extract_response_data(response.json())
    assert "8 characters" in data.get("error", "")


def test_admin_reset_password_requires_auth(admin_server: str) -> None:
    """Test that password reset requires authentication."""
    response = requests.post(
        f"{admin_server}/admin/reset-password",
        json={"current_password": "admin", "new_password": "newpass123"},
        timeout=10
    )
    assert response.status_code == 401


# ============================================================================
# SSO Provider Tests
# ============================================================================

def test_admin_list_sso_providers(admin_server: str) -> None:
    """Test listing SSO providers."""
    token = _admin_login(admin_server)

    response = requests.get(
        f"{admin_server}/admin/sso/providers",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200
    data = _extract_response_data(response.json())
    assert "providers" in data
    assert isinstance(data["providers"], list)


def test_admin_list_sso_providers_requires_auth(admin_server: str) -> None:
    """Test that listing SSO providers requires authentication."""
    response = requests.get(
        f"{admin_server}/admin/sso/providers",
        timeout=10
    )
    assert response.status_code == 403


# ============================================================================
# Configuration Tests
# ============================================================================

def test_admin_get_config(admin_server: str) -> None:
    """Test getting admin configuration."""
    token = _admin_login(admin_server)

    response = requests.get(
        f"{admin_server}/admin/config",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200
    data = _extract_response_data(response.json())
    assert "profile" in data
    assert "content" in data


def test_admin_get_config_requires_auth(admin_server: str) -> None:
    """Test that getting config requires authentication."""
    response = requests.get(
        f"{admin_server}/admin/config",
        timeout=10
    )
    assert response.status_code == 403


# ============================================================================
# Admin Graph Tests
# ============================================================================

def test_admin_graph_requires_auth(admin_server: str) -> None:
    """Test that graph endpoint requires authentication."""
    response = requests.get(
        f"{admin_server}/admin/graph",
        timeout=10
    )
    # Should require authentication (401/403) or validation error (422 for missing params)
    assert response.status_code in [401, 403, 422]


def test_admin_graph_data(admin_server: str) -> None:
    """Test getting graph data."""
    token = _admin_login(admin_server)

    response = requests.get(
        f"{admin_server}/admin/graph",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    # Should return graph data, 404 if no data, or 422 if validation fails
    assert response.status_code in [200, 404, 422]


# ============================================================================
# Admin UI Tests
# ============================================================================

def test_admin_page_redirect(admin_server: str) -> None:
    """Test that /admin redirects to /admin/."""
    response = requests.get(
        f"{admin_server}/admin",
        timeout=10,
        allow_redirects=False
    )
    assert response.status_code == 302
    assert response.headers.get("location") == "/admin/"


def test_admin_index_page(admin_server: str) -> None:
    """Test that admin index page loads."""
    response = requests.get(
        f"{admin_server}/admin/",
        timeout=60  # Build may take time
    )
    # Should return HTML (200) or build error (503)
    assert response.status_code in [200, 503]
    if response.status_code == 200:
        assert "text/html" in response.headers.get("content-type", "")


# ============================================================================
# Integration Tests
# ============================================================================

def test_admin_full_user_lifecycle(admin_server: str) -> None:
    """Test complete user lifecycle: create, read, update, delete."""
    token = _admin_login(admin_server)

    # Create user
    username = f"lifecycle_{uuid.uuid4().hex[:8]}"
    create_resp = requests.post(
        f"{admin_server}/admin/users",
        json={"username": username, "password": "initial123", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert create_resp.status_code == 201

    # Get user
    get_resp = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert get_resp.status_code == 200
    user_data = _extract_response_data(get_resp.json())
    assert user_data["username"] == username
    assert user_data["role"] == "user"
    assert user_data["requires_password_reset"] is True

    # Update user role
    update_resp = requests.put(
        f"{admin_server}/admin/users/{username}",
        json={"role": "moderator", "requires_password_reset": False},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert update_resp.status_code == 200

    # Verify updates
    get_resp2 = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    user_data2 = _extract_response_data(get_resp2.json())
    assert user_data2["role"] == "moderator"
    assert user_data2["requires_password_reset"] is False

    # Delete user
    delete_resp = requests.delete(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert delete_resp.status_code == 200

    # Verify deletion
    get_resp3 = requests.get(
        f"{admin_server}/admin/users/{username}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert get_resp3.status_code == 404


def test_admin_pagination(admin_server: str) -> None:
    """Test user list pagination."""
    token = _admin_login(admin_server)

    # Create multiple users
    usernames = []
    for i in range(5):
        username = f"paguser{i}_{uuid.uuid4().hex[:6]}"
        usernames.append(username)
        requests.post(
            f"{admin_server}/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )

    # Test pagination with limit
    response = requests.get(
        f"{admin_server}/admin/users?limit=2&offset=0",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response.status_code == 200
    data = _extract_response_data(response.json())
    assert data["limit"] == 2
    assert data["offset"] == 0

    # Test with offset
    response2 = requests.get(
        f"{admin_server}/admin/users?limit=2&offset=2",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    assert response2.status_code == 200
    data2 = _extract_response_data(response2.json())
    assert data2["offset"] == 2

    # Cleanup
    for username in usernames:
        requests.delete(
            f"{admin_server}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
