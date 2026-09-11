"""Tests for admin portal API endpoints using ScaleTestClient."""

import logging;
import os;
import shutil;
import tempfile;
import uuid;
import from logging.handlers { MemoryHandler }
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.config.config_loader {
    get_scale_config,
    reset_scale_config,
    resolve_admin_enabled
}
import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    TEST_ADMIN_PASSWORD,
    make_client,
    extract_data
}
import from jaclang.server.identity.user_manager {
    PLACEHOLDER_ADMIN_PASSWORD,
    UserManager
}

# ============================================================================
# Admin Login Tests
# ============================================================================
test "admin login success" {
    client = make_client();
    try {
        response = client.post(
            "/admin/login", json={"username": "admin", "password": TEST_ADMIN_PASSWORD}
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

test "bootstrap token cannot reach admin endpoints before the password reset" {
    client = make_client();
    try {
        response = client.post(
            "/admin/login", json={"username": "admin", "password": TEST_ADMIN_PASSWORD}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data.get("requires_password_reset") is True;
        token = data["token"];

        blocked = client.get(
            "/admin/users", headers={"Authorization": f"Bearer {token}"}
        );
        assert blocked.status_code == 403;

        reset = client.post(
            "/admin/reset-password",
            json={
                "current_password": TEST_ADMIN_PASSWORD,
                "new_password": "TestAdmin123!"
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert reset.status_code == 200;
        rotated = extract_data(reset.json())["token"];

        allowed = client.get(
            "/admin/users", headers={"Authorization": f"Bearer {rotated}"}
        );
        assert allowed.status_code == 200;
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
                f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
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
                f"/admin/users/{username}", headers={"Authorization": f"Bearer {token}"}
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
    import jaclang.scale.admin;
    admin_dir = Path(jaclang.scale.admin.__file__).parent;
    ui_dir = admin_dir / "ui";

    assert ui_dir.exists() , "Admin UI directory should exist";
    assert (ui_dir / "main.jac").exists() , "main.jac should exist";
    assert (ui_dir / "jac.toml").exists() , "jac.toml must be packaged for admin build";
    assert (ui_dir / "styles" / "main.css").exists() , "styles/main.css must be packaged for Tailwind";
}

test "admin UI build emits admin based assets and keeps useEffect lambda" {
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from pathlib { Path }
    import jaclang.scale.admin;

    ui_dir = Path(jaclang.scale.admin.__file__).parent / "ui";
    assert (ui_dir / "main.jac").exists() , "admin UI source missing";

    import from jaclang.scale.runtime.context.util { jac_executable }
    jac_bin = jac_executable();

    tmp = tempfile.mkdtemp(prefix="admin_ui_build_");
    try {
        build_dir = os.path.join(tmp, "ui");
        shutil.copytree(str(ui_dir), build_dir);
        # never build against a stale copied-in artifact dir
        shutil.rmtree(os.path.join(build_dir, ".jac"), ignore_errors=True);

        result = subprocess.run(
            [jac_bin, "build", "--as", "client", "main.jac"],
            cwd=build_dir,
            capture_output=True,
            text=True,
            timeout=600
        );
        dist = Path(build_dir) / ".jac" / "client" / "dist";
        assert (dist / "index.html").exists() , (
            f"admin UI build produced no dist (rc={result.returncode}); "
            f"stdout={result.stdout[-600:]} stderr={result.stderr[-600:]}"
        );
        index_html = (dist / "index.html").read_text(encoding="utf-8");
        assert 'src="/admin/' in index_html , (
            f"admin assets not under /admin/ (base_path lost): {index_html}"
        );
        assert 'href="/admin/' in index_html;

        bundles = list(dist.`glob("client.*.js"));
        assert bundles , "no client bundle emitted";
        js = bundles[0].read_text(encoding="utf-8");
        assert ".useEffect([])" not in js , (
            "admin useEffect lambda was dropped during codegen"
        );
        assert "useEffect([])" not in js;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ============================================================================
# Opt-in defaults and bootstrap credential policy
# ============================================================================
def _admin_name -> str {
    return f"admin-{uuid.uuid4().hex[:8]}";
}


def _capture_warnings(fn: any) -> list[str] {
    capture = MemoryHandler(1000);
    root_logger = logging.getLogger();
    root_logger.addHandler(capture);
    try {
        fn();
        return [
            r.getMessage()
            for r in capture.buffer
            if r.levelno >= logging.WARNING
        ];
    } finally {
        root_logger.removeHandler(capture);
    }
}


# Loads the admin section under exactly `env`, leaving no config singleton behind.
def _admin_config(env: dict[str, str]) -> dict[str, any] {
    with patch.dict(os.environ, env, clear=True) {
        reset_scale_config();
        try {
            return get_scale_config().get_admin_config();
        } finally {
            reset_scale_config();
        }
    }
}


def _with_manager(fn: any) {
    tmp = tempfile.mkdtemp();
    try {
        fn(UserManager(base_path=tmp));
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# Runs `fn` against a temp project whose jac.toml carries `admin_section`
# under [scale.admin], with the env overrides out of the way.
def _with_project(admin_section: str, fn: any) {
    project_dir = tempfile.mkdtemp();
    (Path(project_dir) / "jac.toml").write_text(
        '[project]\nname = "admin-config"\n\n[scale.admin]\n' + admin_section
    );
    with patch.dict(os.environ) {
        os.environ.pop("JAC_ADMIN_ENABLED", None);
        os.environ.pop("JAC_ADMIN_PASSWORD", None);
        reset_scale_config();
        try {
            get_scale_config(project_dir=Path(project_dir));
            fn(UserManager(base_path=project_dir));
        } finally {
            reset_scale_config();
            shutil.rmtree(project_dir, ignore_errors=True);
        }
    }
}


def _pending_admin(manager: UserManager) -> str {
    result = manager.bootstrap_admin_user(_admin_name(), "boot-pass-1");
    assert "error" not in result;
    user_id = result["user_id"];
    assert manager.requires_password_reset(user_id);
    return user_id;
}


test "admin portal ships disabled with no default password" {
    admin_config = _admin_config({});
    assert admin_config["enabled"] is False;
    assert admin_config["default_password"] is None;
}


test "the env overrides reach get_admin_config" {
    admin_config = _admin_config(
        {"JAC_ADMIN_ENABLED": "true", "JAC_ADMIN_PASSWORD": "s3cret-boot"}
    );
    assert admin_config["enabled"] is True;
    assert admin_config["default_password"] == "s3cret-boot";
}


test "JAC_ADMIN_ENABLED is a tri-state override of jac.toml" {
    for (env, forced) in [
        ({}, None),
        ({"JAC_ADMIN_ENABLED": ""}, None),
        ({"JAC_ADMIN_ENABLED": "   "}, None),
        ({"JAC_ADMIN_ENABLED": "true"}, True),
        ({"JAC_ADMIN_ENABLED": "on"}, True),
        ({"JAC_ADMIN_ENABLED": " True "}, True),
        ({"JAC_ADMIN_ENABLED": "YES"}, True),
        ({"JAC_ADMIN_ENABLED": "1"}, True),
        ({"JAC_ADMIN_ENABLED": "false"}, False),
        ({"JAC_ADMIN_ENABLED": "off"}, False),
        ({"JAC_ADMIN_ENABLED": "no"}, False),
        ({"JAC_ADMIN_ENABLED": "0"}, False)
    ] {
        with patch.dict(os.environ, env, clear=True) {
            for configured in [True, False] {
                expected = configured if forced is None else forced;
                assert resolve_admin_enabled(configured) is expected , env;
            }
        }
    }
}


test "an unrecognized JAC_ADMIN_ENABLED warns once and stays disabled" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "ture"}, clear=True) {
        def attempt {
            assert not resolve_admin_enabled(True);
        }
        seen = _capture_warnings(attempt);
        assert len(
            [
                m
                for m in seen
                if "JAC_ADMIN_ENABLED" in m and "ture" in m
            ]
        )
            == 1 , seen;
    }
}


test "bootstrap honors require_password_reset = false" {
    def check(manager: UserManager) {
        result = manager.bootstrap_admin_user(
            _admin_name(), "boot-pass-1", require_password_reset=False
        );
        assert "error" not in result;
        assert manager.is_admin(result["user_id"]);
        assert not manager.requires_password_reset(result["user_id"]);
    }
    _with_manager(check);
}


test "bootstrap refuses an absent or placeholder password" {
    def check(manager: UserManager) {
        for (password, reason) in [
            ("", "bootstrap password"),
            (PLACEHOLDER_ADMIN_PASSWORD, PLACEHOLDER_ADMIN_PASSWORD)
        ] {
            username = _admin_name();
            result = manager.bootstrap_admin_user(username, password);
            assert "error" in result and reason in result["error"] , result;
            assert manager.find_user_by_identity(username) is None;
        }
    }
    _with_manager(check);
}


test "bootstrap_admin reads require_password_reset from jac.toml" {
    username = _admin_name();
    def check(manager: UserManager) {
        assert JacAPIServerAdmin(user_manager=manager).bootstrap_admin();
        user = manager.find_user_by_identity(username);
        assert user is not None;
        assert manager.is_admin(user["user_id"]);
        assert not manager.requires_password_reset(user["user_id"]);
    }
    _with_project(
        "enabled = true\n"
        f'username = "{username}"\n'
        'default_password = "boot-pass-1"\n'
        "require_password_reset = false\n",
        check
    );
}


test "a disabled portal warns when an admin account is dormant in the identity store" {
    username = _admin_name();
    def check(manager: UserManager) {
        portal = JacAPIServerAdmin(user_manager=manager);
        def register {
            assert not portal.register_admin_endpoints();
        }
        assert not [
            m
            for m in _capture_warnings(register)
            if username in m
        ];
        assert "error" not in manager.bootstrap_admin_user(username, "boot-pass-1");
        dormant = [
            m
            for m in _capture_warnings(register)
            if username in m
        ];
        assert len(dormant) == 1 , dormant;
    }
    _with_project("enabled = false\n" f'username = "{username}"\n', check);
}


test "a disabled portal still registers when the identity store is unreachable" {
    import from jaclang.data.store { ConnInfo, PgStore }

    def check(manager: UserManager) {
        storage: any = manager._identity_storage;
        storage.store = PgStore(conninfo=ConnInfo(host="127.0.0.1", port=1));
        assert JacAPIServerAdmin(user_manager=manager).register_admin_endpoints()
            is False;
    }
    _with_project("enabled = false\n", check);
}


test "rotating through update_password clears a pending reset only on success" {
    def check(manager: UserManager) {
        user_id = _pending_admin(manager);
        assert "error"
            in manager.update_password(user_id, "wrong-pass", "rotated-pass-1");
        assert manager.requires_password_reset(user_id);
        assert "error"
            not in manager.update_password(user_id, "boot-pass-1", "rotated-pass-1");
        assert not manager.requires_password_reset(user_id);
    }
    _with_manager(check);
}


test "recovering through reset_password_by_user_id clears a pending reset only on success" {
    def check(manager: UserManager) {
        user_id = _pending_admin(manager);
        assert "error"
            in manager.reset_password_by_user_id("no-such-user", "recovered-pass-1");
        assert manager.requires_password_reset(user_id);
        assert "error"
            not in manager.reset_password_by_user_id(user_id, "recovered-pass-1");
        assert not manager.requires_password_reset(user_id);
        assert manager.authenticate(
            manager.get_username(user_id) or "", "recovered-pass-1"
        )
            is not None;
    }
    _with_manager(check);
}
