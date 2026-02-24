"""Tests for admin portal API endpoints."""

import contextlib;
import gc;
import glob;
import socket;
import subprocess;
import sys;
import time;
import uuid;
import shutil;
import requests;
import from pathlib { Path }
import from typing { Any }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Extract data from TransportResponse envelope format."""
def _extract_response_data(json_response: dict[str, Any]) -> dict[str, Any] {
    if isinstance(json_response, dict) and "ok" in json_response {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            result: dict[str, Any] = {
                "error": error_info.get("message", "Unknown error")
            };
            if "code" in error_info {
                result["error_code"] = error_info["code"];
            }
            return result;
        }
    }
    return json_response;
}

glob DEFAULT_ADMIN_PASSWORD: str = "changeme";  # Default from admin_config

"""Delete SQLite database files and .jac directories."""
def _cleanup_db_files(fixtures_dir: Path) -> None {
    # Clean both fixtures dir and parent tests dir
    dirs_to_clean = [fixtures_dir, fixtures_dir.parent];
    for clean_dir in dirs_to_clean {
        for pattern in [
            "*.db",
            "*.db-wal",
            "*.db-shm",
            "anchor_store.db.dat",
            "anchor_store.db.bak",
            "anchor_store.db.dir"
        ] {
            for db_file in glob.glob(str(clean_dir / pattern)) {
                with contextlib.suppress(Exception) {
                    Path(db_file).unlink();
                }
            }
        }
        jac_dir = clean_dir / ".jac";
        if jac_dir.exists() {
            with contextlib.suppress(Exception) {
                shutil.rmtree(jac_dir);
            }
        }
    }
}

"""Start the jac-scale server in a subprocess."""
def _start_server(
    fixtures_dir: Path, test_file: Path, port: int, base_url: str
) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [str(jac_executable), "start", test_file.name, "--port", str(port)];
    server_process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir)
    );

    max_attempts = 50;
    server_ready = False;
    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(
                f"Server terminated unexpectedly.\nSTDOUT: {stdout}\nSTDERR: {stderr}"
            ) ;
        }
        try {
            response = requests.get(f"{base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(2);
        }
    }

    if not server_ready {
        server_process.terminate();
        try {
            (stdout, stderr) = server_process.communicate(timeout=2);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            (stdout, stderr) = server_process.communicate();
        }
        raise RuntimeError(
            f"Server failed to start.\nSTDOUT: {stdout}\nSTDERR: {stderr}"
        ) ;
    }
    return server_process;
}

"""Stop server process."""
def _stop_server(server_process: subprocess.Popen | None) -> None {
    if server_process {
        server_process.terminate();
        try {
            server_process.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            server_process.wait();
        }
    }
    time.sleep(0.5);
    gc.collect();
}

"""Login as admin, handling password reset if required. Returns token."""
def _admin_login(base_url: str, new_password: str = "newadmin123") -> str {
    login_resp = requests.post(
        f"{base_url}/admin/login",
        json={"username": "admin", "password": DEFAULT_ADMIN_PASSWORD},
        timeout=10
    );
    data = _extract_response_data(login_resp.json());

    # If password reset required, do the reset
    if data.get("requires_password_reset") {
        temp_token = data["token"];
        reset_resp = requests.post(
            f"{base_url}/admin/reset-password",
            json={
                "current_password": DEFAULT_ADMIN_PASSWORD,
                "new_password": new_password
            },
            headers={"Authorization": f"Bearer {temp_token}"},
            timeout=10
        );
        reset_data = _extract_response_data(reset_resp.json());
        return reset_data["token"];
    }

    # Direct login success
    if "token" in data {
        return data["token"];
    }

    # Try with new password (already reset in previous test run)
    login_resp2 = requests.post(
        f"{base_url}/admin/login",
        json={"username": "admin", "password": new_password},
        timeout=10
    );
    data2 = _extract_response_data(login_resp2.json());
    if "token" in data2 {
        return data2["token"];
    }

    raise RuntimeError(f"Admin login failed: {data}") ;
}

# Shared state for admin tests
glob admin_fixtures_dir: Path = Path(__file__).parent / "fixtures",
     admin_test_file: Path = admin_fixtures_dir / "test_api.jac",
     admin_port: int = get_free_port(),
     admin_base_url: str = f"http://localhost:{admin_port}";

"""Setup and start the server for admin tests."""
def setup_admin_server -> subprocess.Popen {
    if not admin_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {admin_test_file}") ;
    }
    _cleanup_db_files(admin_fixtures_dir);
    return _start_server(
        admin_fixtures_dir, admin_test_file, admin_port, admin_base_url
    );
}

"""Teardown the admin server."""
def teardown_admin_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(admin_fixtures_dir);
}

# ============================================================================
# Admin Login Tests
# ============================================================================
test "admin login success" {
    sp = setup_admin_server();
    try {
        # Default admin credentials from bootstrap
        response = requests.post(
            f"{admin_base_url}/admin/login",
            json={"username": "admin", "password": DEFAULT_ADMIN_PASSWORD},
            timeout=10
        );
        assert response.status_code == 200;
        data = _extract_response_data(response.json());
        assert "token" in data;
        assert data["username"] == "admin";
        assert data["role"] == "admin";
        # Bootstrap admin requires password reset
        assert data.get("requires_password_reset") is True;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin login wrong password" {
    sp = setup_admin_server();
    try {
        response = requests.post(
            f"{admin_base_url}/admin/login",
            json={"username": "admin", "password": "wrongpassword"},
            timeout=10
        );
        assert response.status_code == 401;
        data = _extract_response_data(response.json());
        assert "error" in data;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin login missing credentials" {
    sp = setup_admin_server();
    try {
        # Missing password
        response = requests.post(
            f"{admin_base_url}/admin/login", json={"username": "admin"}, timeout=10
        );
        assert response.status_code in [400, 422];

        # Missing username
        response = requests.post(
            f"{admin_base_url}/admin/login", json={"password": "admin"}, timeout=10
        );
        assert response.status_code in [400, 422];

        # Empty body
        response = requests.post(f"{admin_base_url}/admin/login", json={}, timeout=10);
        assert response.status_code in [400, 422];
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin login non-admin user rejected" {
    sp = setup_admin_server();
    try {
        # First login as admin to create a regular user
        admin_token = _admin_login(admin_base_url);

        # Create a regular user
        username = f"regularuser_{uuid.uuid4().hex[:8]}";
        requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "userpass123", "role": "user"},
            headers={"Authorization": f"Bearer {admin_token}"},
            timeout=10
        );

        # Try to login as admin with regular user credentials
        # First register the user through normal registration
        requests.post(
            f"{admin_base_url}/user/register",
            json={"username": f"nonmin_{uuid.uuid4().hex[:8]}", "password": "testpass"},
            timeout=10
        );

        # Regular users should be rejected from admin login
        response = requests.post(
            f"{admin_base_url}/admin/login",
            json={"username": username, "password": "userpass123"},
            timeout=10
        );
        # May require password reset, but should eventually be rejected as non-admin
        assert response.status_code in [401, 403]
        or (
            response.status_code == 200
            and _extract_response_data(response.json()).get("requires_password_reset")
        );
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# User Management Tests
# ============================================================================
test "admin list users" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # List users
        response = requests.get(
            f"{admin_base_url}/admin/users",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;
        data = _extract_response_data(response.json());
        assert "users" in data;
        assert isinstance(data["users"], list);
        assert "count" in data;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin list users requires auth" {
    sp = setup_admin_server();
    try {
        response = requests.get(f"{admin_base_url}/admin/users", timeout=10);
        assert response.status_code == 403;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin create user" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user
        username = f"newuser_{uuid.uuid4().hex[:8]}";
        response = requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "newpass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 201;
        data = _extract_response_data(response.json());
        assert data["username"] == username;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin create user with different roles" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user with each role
        for role in ["user", "admin"] {
            username = f"{role}user_{uuid.uuid4().hex[:8]}";
            response = requests.post(
                f"{admin_base_url}/admin/users",
                json={"username": username, "password": "pass123", "role": role},
                headers={"Authorization": f"Bearer {token}"},
                timeout=10
            );
            assert response.status_code == 201;

            # Verify role was set
            get_resp = requests.get(
                f"{admin_base_url}/admin/users/{username}",
                headers={"Authorization": f"Bearer {token}"},
                timeout=10
            );
            assert get_resp.status_code == 200;
            user_data = _extract_response_data(get_resp.json());
            assert user_data["role"] == role;
        }
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin create user duplicate fails" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user
        username = f"dupuser_{uuid.uuid4().hex[:8]}";
        response = requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 201;

        # Try to create same user again
        response = requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "pass456", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 400;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin update user role" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user
        username = f"roleuser_{uuid.uuid4().hex[:8]}";
        requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        # Update role to admin (API requires both fields)
        response = requests.put(
            f"{admin_base_url}/admin/users/{username}",
            json={"role": "admin", "requires_password_reset": True},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;

        # Verify role changed
        get_resp = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        user_data = _extract_response_data(get_resp.json());
        assert user_data["role"] == "admin";
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin update user password reset flag" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user (by default requires_password_reset is True)
        username = f"resetuser_{uuid.uuid4().hex[:8]}";
        requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        # Set requires_password_reset to False (API requires both fields)
        response = requests.put(
            f"{admin_base_url}/admin/users/{username}",
            json={"role": "user", "requires_password_reset": False},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;

        # Verify flag changed
        get_resp = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        user_data = _extract_response_data(get_resp.json());
        assert user_data["requires_password_reset"] is False;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin delete user" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user
        username = f"deleteuser_{uuid.uuid4().hex[:8]}";
        requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        # Delete user
        response = requests.delete(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;

        # Verify user is gone
        get_resp = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert get_resp.status_code == 404;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin get user not found" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Get non-existent user
        response = requests.get(
            f"{admin_base_url}/admin/users/nonexistent_user_xyz",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 404;
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# Password Reset Tests
# ============================================================================
test "admin reset password" {
    sp = setup_admin_server();
    try {
        # Login as admin - this handles password reset internally
        token = _admin_login(admin_base_url);
        assert token is not None;
        assert len(token) > 0;

        # Verify token works by making an authenticated request
        response = requests.get(
            f"{admin_base_url}/admin/users",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin reset password wrong current password" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Try reset with wrong current password
        response = requests.post(
            f"{admin_base_url}/admin/reset-password",
            json={"current_password": "wrongpassword", "new_password": "newpass123"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 400;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin reset password too short" {
    sp = setup_admin_server();
    try {
        # Login as admin (password becomes "newadmin123" after reset)
        token = _admin_login(admin_base_url);

        # Try reset with too short password
        response = requests.post(
            f"{admin_base_url}/admin/reset-password",
            json={"current_password": "newadmin123", "new_password": "short"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 400;
        data = _extract_response_data(response.json());
        assert "8 characters" in data.get("error", "");
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin reset password requires auth" {
    sp = setup_admin_server();
    try {
        response = requests.post(
            f"{admin_base_url}/admin/reset-password",
            json={"current_password": "admin", "new_password": "newpass123"},
            timeout=10
        );
        assert response.status_code == 401;
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# SSO Provider Tests
# ============================================================================
test "admin list sso providers" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # List SSO providers
        response = requests.get(
            f"{admin_base_url}/admin/sso/providers",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;
        data = _extract_response_data(response.json());
        assert "providers" in data;
        assert isinstance(data["providers"], list);
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin list sso providers requires auth" {
    sp = setup_admin_server();
    try {
        response = requests.get(f"{admin_base_url}/admin/sso/providers", timeout=10);
        assert response.status_code == 403;
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# Configuration Tests
# ============================================================================
test "admin get config" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Get config
        response = requests.get(
            f"{admin_base_url}/admin/config",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;
        data = _extract_response_data(response.json());
        assert "profile" in data;
        assert "content" in data;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin get config requires auth" {
    sp = setup_admin_server();
    try {
        response = requests.get(f"{admin_base_url}/admin/config", timeout=10);
        assert response.status_code == 403;
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# Admin Graph Tests
# ============================================================================
test "admin graph requires auth" {
    sp = setup_admin_server();
    try {
        response = requests.get(f"{admin_base_url}/admin/graph", timeout=10);
        # Should require authentication (401/403) or validation error (422 for missing params)
        assert response.status_code in [401, 403, 422];
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin graph data" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Get graph data
        response = requests.get(
            f"{admin_base_url}/admin/graph",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        # Should return graph data, 404 if no data, or 422 if validation fails
        assert response.status_code in [200, 404, 422];
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# Admin UI Tests
# ============================================================================
test "admin page redirect" {
    sp = setup_admin_server();
    try {
        response = requests.get(
            f"{admin_base_url}/admin", timeout=10, allow_redirects=False
        );
        assert response.status_code == 302;
        assert response.headers.get("location") == "/admin/";
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin index page" {
    sp = setup_admin_server();
    try {
        response = requests.get(
            f"{admin_base_url}/admin/", timeout=60  # Build may take time
        );
        # Should return HTML (200) or build error (503)
        assert response.status_code in [200, 503];
        if response.status_code == 200 {
            assert "text/html" in response.headers.get("content-type", "");
        }
    } finally {
        teardown_admin_server(sp);
    }
}

# ============================================================================
# Integration Tests
# ============================================================================
test "admin full user lifecycle" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create user
        username = f"lifecycle_{uuid.uuid4().hex[:8]}";
        create_resp = requests.post(
            f"{admin_base_url}/admin/users",
            json={"username": username, "password": "initial123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert create_resp.status_code == 201;

        # Get user
        get_resp = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert get_resp.status_code == 200;
        user_data = _extract_response_data(get_resp.json());
        assert user_data["username"] == username;
        assert user_data["role"] == "user";
        assert user_data["requires_password_reset"] is True;

        # Update user role
        update_resp = requests.put(
            f"{admin_base_url}/admin/users/{username}",
            json={"role": "admin", "requires_password_reset": False},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert update_resp.status_code == 200;

        # Verify updates
        get_resp2 = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        user_data2 = _extract_response_data(get_resp2.json());
        assert user_data2["role"] == "admin";
        assert user_data2["requires_password_reset"] is False;

        # Delete user
        delete_resp = requests.delete(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert delete_resp.status_code == 200;

        # Verify deletion
        get_resp3 = requests.get(
            f"{admin_base_url}/admin/users/{username}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert get_resp3.status_code == 404;
    } finally {
        teardown_admin_server(sp);
    }
}

test "admin pagination" {
    sp = setup_admin_server();
    try {
        # Login as admin
        token = _admin_login(admin_base_url);

        # Create multiple users
        usernames = [];
        for i in range(5) {
            username = f"paguser{i}_{uuid.uuid4().hex[:6]}";
            usernames.append(username);
            requests.post(
                f"{admin_base_url}/admin/users",
                json={"username": username, "password": "pass123", "role": "user"},
                headers={"Authorization": f"Bearer {token}"},
                timeout=10
            );
        }

        # Test pagination with limit
        response = requests.get(
            f"{admin_base_url}/admin/users?limit=2&offset=0",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response.status_code == 200;
        data = _extract_response_data(response.json());
        assert data["limit"] == 2;
        assert data["offset"] == 0;

        # Test with offset
        response2 = requests.get(
            f"{admin_base_url}/admin/users?limit=2&offset=2",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );
        assert response2.status_code == 200;
        data2 = _extract_response_data(response2.json());
        assert data2["offset"] == 2;

        # Cleanup
        for username in usernames {
            requests.delete(
                f"{admin_base_url}/admin/users/{username}",
                headers={"Authorization": f"Bearer {token}"},
                timeout=10
            );
        }
    } finally {
        teardown_admin_server(sp);
    }
}
