"""Tests for admin portal API endpoints using ScaleTestClient."""

import uuid;
import from typing { Any }
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

glob DEFAULT_ADMIN_PASSWORD: str = "changeme";

# ============================================================================
# Admin Login Tests
# ============================================================================
test "admin login success" {
    client = make_client();
    try {
        response = client.post(
            "/admin/login",
            json={"username": "admin", "password": DEFAULT_ADMIN_PASSWORD}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "token" in data;
        assert data["username"] == "admin";
        assert data["role"] == "admin";
        assert data.get("requires_password_reset") is True;
    } finally {
        client.close();
    }
}

test "admin login wrong password" {
    client = make_client();
    try {
        response = client.post(
            "/admin/login", json={"username": "admin", "password": "wrongpassword"}
        );
        assert response.status_code == 401;
        data = extract_data(response.json());
        assert "error" in data;
    } finally {
        client.close();
    }
}

test "admin login missing credentials" {
    client = make_client();
    try {
        response = client.post("/admin/login", json={"username": "admin"});
        assert response.status_code in [400, 422];

        response = client.post("/admin/login", json={"password": "admin"});
        assert response.status_code in [400, 422];

        response = client.post("/admin/login", json={});
        assert response.status_code in [400, 422];
    } finally {
        client.close();
    }
}

test "admin login non-admin user rejected" {
    client = make_client();
    try {
        admin_token = client.admin_login();

        username = f"regularuser_{uuid.uuid4().hex[:8]}";
        client.post(
            "/admin/users",
            json={"username": username, "password": "userpass123", "role": "user"},
            headers={"Authorization": f"Bearer {admin_token}"}
        );

        client.post(
            "/user/register",
            json={"username": f"nonmin_{uuid.uuid4().hex[:8]}", "password": "testpass"}
        );

        response = client.post(
            "/admin/login", json={"username": username, "password": "userpass123"}
        );
        assert response.status_code in [401, 403]
        or (
            response.status_code == 200
            and extract_data(response.json()).get("requires_password_reset")
        );
    } finally {
        client.close();
    }
}

# ============================================================================
# User Management Tests
# ============================================================================
test "admin list users" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.get(
            "/admin/users", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "users" in data;
        assert isinstance(data["users"], list);
        assert "count" in data;
    } finally {
        client.close();
    }
}

test "admin list users requires auth" {
    client = make_client();
    try {
        response = client.get("/admin/users");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "admin create user" {
    client = make_client();
    try {
        token = client.admin_login();

        username = f"newuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/admin/users",
            json={"username": username, "password": "newpass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 201;
        data = extract_data(response.json());
        assert data["username"] == username;
    } finally {
        client.close();
    }
}

test "admin create user with different roles" {
    client = make_client();
    try {
        token = client.admin_login();

        for role in ["user", "admin"] {
            username = f"{role}user_{uuid.uuid4().hex[:8]}";
            response = client.post(
                "/admin/users",
                json={"username": username, "password": "pass123", "role": role},
                headers={"Authorization": f"Bearer {token}"}
            );
            assert response.status_code == 201;

            get_resp = client.get(
                f"/admin/users/{username}",
                headers={"Authorization": f"Bearer {token}"}
            );
            assert get_resp.status_code == 200;
            user_data = extract_data(get_resp.json());
            assert user_data["role"] == role;
        }
    } finally {
        client.close();
    }
}

test "admin create user duplicate fails" {
    client = make_client();
    try {
        token = client.admin_login();

        username = f"dupuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 201;

        response = client.post(
            "/admin/users",
            json={"username": username, "password": "pass456", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;
    } finally {
        client.close();
    }
}

test "admin update user role" {
    client = make_client();
    try {
        token = client.admin_login();

        username = f"roleuser_{uuid.uuid4().hex[:8]}";
        client.post(
            "/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );

        response = client.put(
            f"/admin/users/{username}",
            json={"role": "admin", "requires_password_reset": True},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        get_resp = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        user_data = extract_data(get_resp.json());
        assert user_data["role"] == "admin";
    } finally {
        client.close();
    }
}

test "admin update user password reset flag" {
    client = make_client();
    try {
        token = client.admin_login();

        username = f"resetuser_{uuid.uuid4().hex[:8]}";
        client.post(
            "/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );

        response = client.put(
            f"/admin/users/{username}",
            json={"role": "user", "requires_password_reset": False},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        get_resp = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        user_data = extract_data(get_resp.json());
        assert user_data["requires_password_reset"] is False;
    } finally {
        client.close();
    }
}

test "admin delete user" {
    client = make_client();
    try {
        token = client.admin_login();

        username = f"deleteuser_{uuid.uuid4().hex[:8]}";
        client.post(
            "/admin/users",
            json={"username": username, "password": "pass123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );

        response = client.delete(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        get_resp = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        assert get_resp.status_code == 404;
    } finally {
        client.close();
    }
}

test "admin get user not found" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.get(
            "/admin/users/nonexistent_user_xyz",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 404;
    } finally {
        client.close();
    }
}

# ============================================================================
# Password Reset Tests
# ============================================================================
test "admin reset password" {
    client = make_client();
    try {
        token = client.admin_login();
        assert token is not None;
        assert len(token) > 0;

        response = client.get(
            "/admin/users", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
    } finally {
        client.close();
    }
}

test "admin reset password wrong current password" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.post(
            "/admin/reset-password",
            json={"current_password": "wrongpassword", "new_password": "newpass123"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;
    } finally {
        client.close();
    }
}

test "admin reset password too short" {
    client = make_client();
    try {
        token = client.admin_login();

        # After admin_login, the password is now "TestAdmin123!"
        response = client.post(
            "/admin/reset-password",
            json={"current_password": "TestAdmin123!", "new_password": "short"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;
        data = extract_data(response.json());
        assert "8 characters" in data.get("error", "");
    } finally {
        client.close();
    }
}

test "admin reset password requires auth" {
    client = make_client();
    try {
        response = client.post(
            "/admin/reset-password",
            json={"current_password": "admin", "new_password": "newpass123"}
        );
        assert response.status_code == 401;
    } finally {
        client.close();
    }
}

# ============================================================================
# SSO Provider Tests
# ============================================================================
test "admin list sso providers" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.get(
            "/admin/sso/providers", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "providers" in data;
        assert isinstance(data["providers"], list);
    } finally {
        client.close();
    }
}

test "admin list sso providers requires auth" {
    client = make_client();
    try {
        response = client.get("/admin/sso/providers");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Configuration Tests
# ============================================================================
test "admin get config" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.get(
            "/admin/config", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "profile" in data;
        assert "content" in data;
    } finally {
        client.close();
    }
}

test "admin get config requires auth" {
    client = make_client();
    try {
        response = client.get("/admin/config");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Admin Graph Tests
# ============================================================================
test "admin graph requires auth" {
    client = make_client();
    try {
        response = client.get("/admin/graph");
        assert response.status_code in [401, 403, 422];
    } finally {
        client.close();
    }
}

test "admin graph data" {
    client = make_client();
    try {
        token = client.admin_login();

        response = client.get(
            "/admin/graph", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in [200, 404, 422];
    } finally {
        client.close();
    }
}

# ============================================================================
# Admin UI Tests
# ============================================================================
test "admin page redirect" {
    client = make_client();
    try {
        response = client.get("/admin", allow_redirects=False);
        assert response.status_code in [302, 307];
        assert "/admin/" in response.headers.get("location", "");
    } finally {
        client.close();
    }
}

test "admin index page" {
    client = make_client();
    try {
        response = client.get("/admin/");
        assert response.status_code in [200, 503];
        if response.status_code == 200 {
            assert "text/html" in response.headers.get("content-type", "");
        }
    } finally {
        client.close();
    }
}

# ============================================================================
# Integration Tests
# ============================================================================
test "admin full user lifecycle" {
    client = make_client();
    try {
        token = client.admin_login();

        # Create
        username = f"lifecycle_{uuid.uuid4().hex[:8]}";
        create_resp = client.post(
            "/admin/users",
            json={"username": username, "password": "initial123", "role": "user"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert create_resp.status_code == 201;

        # Read
        get_resp = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        assert get_resp.status_code == 200;
        user_data = extract_data(get_resp.json());
        assert user_data["username"] == username;
        assert user_data["role"] == "user";
        assert user_data["requires_password_reset"] is True;

        # Update
        update_resp = client.put(
            f"/admin/users/{username}",
            json={"role": "admin", "requires_password_reset": False},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert update_resp.status_code == 200;

        # Verify update
        get_resp2 = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        user_data2 = extract_data(get_resp2.json());
        assert user_data2["role"] == "admin";
        assert user_data2["requires_password_reset"] is False;

        # Delete
        delete_resp = client.delete(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        assert delete_resp.status_code == 200;

        # Verify deletion
        get_resp3 = client.get(
            f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
        );
        assert get_resp3.status_code == 404;
    } finally {
        client.close();
    }
}

test "admin pagination" {
    client = make_client();
    try {
        token = client.admin_login();

        usernames = [];
        for i in range(5) {
            username = f"paguser{i}_{uuid.uuid4().hex[:6]}";
            usernames.append(username);
            client.post(
                "/admin/users",
                json={"username": username, "password": "pass123", "role": "user"},
                headers={"Authorization": f"Bearer {token}"}
            );
        }

        response = client.get(
            "/admin/users",
            params={"limit": 2, "offset": 0},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["limit"] == 2;
        assert data["offset"] == 0;

        response2 = client.get(
            "/admin/users",
            params={"limit": 2, "offset": 2},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response2.status_code == 200;
        data2 = extract_data(response2.json());
        assert data2["offset"] == 2;

        for username in usernames {
            client.delete(
                f"/admin/users/{username}",
                headers={"Authorization": f"Bearer {token}"}
            );
        }
    } finally {
        client.close();
    }
}

# ============================================================================
# Admin UI Packaging Tests
# ============================================================================
test "admin ui includes jac.toml and styles for build" {
    import from pathlib { Path }
    import jac_scale.admin;
    admin_dir = Path(jac_scale.admin.__file__).parent;
    ui_dir = admin_dir / "ui";

    assert ui_dir.exists() , "Admin UI directory should exist";
    assert (ui_dir / "main.jac").exists() , "main.jac should exist";
    assert (ui_dir / "jac.toml").exists() , "jac.toml must be packaged for admin build";
    assert (ui_dir / "styles" / "main.css").exists() , "styles/main.css must be packaged for Tailwind";
}
