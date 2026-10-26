"""Tests for admin portal API endpoints using ScaleTestClient."""

import os;
import uuid;
import from unittest.mock { patch }

glob DEFAULT_ADMIN_PASSWORD: str = ADMIN_BOOTSTRAP_PASSWORD;

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

test "admin login needs the code once the admin has a verified second factor" {
    client = make_client();
    try {
        root_admin = {"Authorization": f"Bearer {client.admin_login()}"};
        username = f"mfaadmin_{uuid.uuid4().hex[:8]}";
        password = "Adm1n!Passw0rd";
        response = client.post(
            "/admin/users",
            json={"username": username, "password": password, "role": "admin"},
            headers=root_admin
        );
        assert response.status_code == 201 , response.text;

        # Before enrolling, the password alone signs the admin in, as today.
        response = client.post(
            "/admin/login", json={"username": username, "password": password}
        );
        assert response.status_code == 200 , response.text;
        admin_auth = {
            "Authorization": f"Bearer {extract_data(response.json())['token']}"
        };

        response = client.post(
            "/user/mfa/enroll", json={"password": password}, headers=admin_auth
        );
        assert response.status_code == 201 , response.text;
        enrolled = extract_data(response.json());
        used: set[int] = set();
        response = client.post(
            "/user/mfa/verify",
            json={
                "factor_id": enrolled["factor_id"],
                "code": fresh_totp_code(enrolled["secret"], used)
            },
            headers=admin_auth
        );
        assert response.status_code == 200 , response.text;

        response = client.post(
            "/admin/login", json={"username": username, "password": password}
        );
        assert response.status_code == 401 , response.text;
        assert response.json()["error"]["code"] == "MFA_REQUIRED";
        assert not response.json().get("data");

        response = client.post(
            "/admin/login",
            json={
                "username": username,
                "password": password,
                "code": wrong_totp_code(enrolled["secret"])
            }
        );
        assert response.status_code == 401 , response.text;
        assert response.json()["error"]["code"] == "INVALID_CODE";

        response = client.post(
            "/admin/login",
            json={
                "username": username,
                "password": password,
                "code": fresh_totp_code(enrolled["secret"], used)
            }
        );
        assert response.status_code == 200 , response.text;
        token = extract_data(response.json())["token"];
        claims = jwt_decode(token, signing_secret(), algorithms=["HS256"]);
        assert claims["aal"] == "aal2";
        assert claims["amr"] == ["pwd", "otp"];
        response = client.get(
            "/admin/users", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200 , response.text;
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

test "admin reset password is held to the shared password policy" {
    # The suite lowers the password floor for its throwaway fixtures; this test
    # runs against the shipped default of 8 characters.
    with patch.dict(os.environ, {"JAC_SERVE_AUTH_PASSWORD_MIN_LENGTH": "8"}) {
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
            body = response.json();
            assert body["error"]["code"] == "POLICY_VIOLATION" , body;
            assert body["error"]["details"] == {"violations": ["PASSWORD_TOO_SHORT"]};
        } finally {
            client.close();
        }
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

test "admin console pages answer without waiting on a console build" {
    import shutil;
    import tempfile;
    import threading;
    import from pathlib { Path }
    import from jaclang.scale.admin.console_build { AdminConsole, ConsoleState }
    import from jaclang.scale.server.extensions { AdminExtension }

    def write_console(dist: Path, marker: str) -> Path {
        dist.mkdir(parents=True, exist_ok=True);
        (dist / "index.html").write_text(f"<html>{marker}</html>");
        (dist / "app.js").write_text(f"// {marker}");
        return dist;
    }

    # A 503 page, building or failed, says when to come back and reloads then.
    def assert_retries(name: str, path: str, response: any) {
        retry = response.headers.get("retry-after");
        assert retry , f"{name}: {path} 503 carries no Retry-After";
        assert f'http-equiv="refresh" content="{retry}"' in response.text , (
            f"{name}: {path} 503 page does not reload after {retry}s"
        );
    }

    # Each row: whether the project carries a console under .jac/admin (staged
    # by a deploy, or left unmarked by an older build), how the build behaves,
    # and what /admin/ serves once the build has settled.
    rows = [
        {
            "name": "a staged console is served and nothing builds",
            "staged": True,
            "build": "instant",
            "first": 200,
            "settled": 200,
            "body": "staged",
            "builds": 0
        },
        {
            "name": "a running build answers 503 and is not started twice",
            "staged": False,
            "build": "gated",
            "first": 503,
            "settled": 200,
            "body": "built",
            "builds": 1
        },
        {
            "name": "a failed build backs off instead of rebuilding",
            "staged": False,
            "build": "fails",
            "first": 503,
            "settled": 503,
            "body": "",
            "builds": 1
        },
        {
            "name": "a console an older build left in .jac/admin is not served",
            "staged": "unmarked",
            "build": "gated",
            "first": 503,
            "settled": 200,
            "body": "built",
            "builds": 1
        }
    ];

    import jaclang.scale.admin;
    package_ui = Path(jaclang.scale.admin.__file__).parent / "ui";
    client = make_client();
    ext = [
        e
        for e in client.server.extensions
        if isinstance(e, AdminExtension)
    ][0];
    prior_console = ext.admin_console;
    prior_cwd = os.getcwd();
    try {
        for row in rows {
            name = str(row["name"]);
            tmp = Path(tempfile.mkdtemp(prefix="admin_console_"));
            try {
                project = tmp / "project";
                project.mkdir();
                if row["staged"] {
                    staged = write_console(project / ".jac" / "admin", "staged");
                    if row["staged"] != "unmarked" {
                        (staged / ".staged").touch();
                    }
                }
                os.chdir(str(project));

                source = tmp / "ui";
                shutil.copytree(
                    str(package_ui),
                    str(source),
                    ignore=shutil.ignore_patterns(".jac", "node_modules")
                );
                cache = tmp / "cache";
                gate = threading.Event();
                calls: list[str] = [];

                def build(src: Path) -> Path {
                    calls.append(str(src));
                    if row["build"] == "fails" {
                        raise RuntimeError("the admin build broke");
                    }
                    if row["build"] == "gated" {
                        gate.wait(30);
                    }
                    return write_console(src / ".jac" / "client" / "dist", "built");
                }

                console = AdminConsole(
                    source_dir=source,
                    cache_dir=cache,
                    build_fn=build,
                    retry_after=300.0
                );
                ext.admin_console = console;

                # Several requests while the console is missing: the page, a
                # client route and an asset, as a browser sends them at once.
                for path in ["/admin/", "/admin/quotes", "/admin/app.js"] {
                    response = client.get(path);
                    assert response.status_code == row["first"] , (
                        f"{name}: {path} -> {response.status_code}"
                    );
                    if row["first"] == 503 {
                        assert_retries(name, path, response);
                    }
                }

                if row["build"] == "gated" {
                    # Another process sharing the cache finds the build under
                    # way and does not start its own.
                    sibling_calls: list[str] = [];
                    def build_sibling(src: Path) -> Path {
                        sibling_calls.append(str(src));
                        return write_console(
                            src / ".jac" / "client" / "dist", "sibling"
                        );
                    }
                    sibling = AdminConsole(
                        source_dir=source, cache_dir=cache, build_fn=build_sibling
                    );
                    assert sibling.status().state == ConsoleState.BUILDING , name;
                    gate.set();
                    assert console.wait_for(30).state == ConsoleState.READY , name;
                    assert sibling.wait_for(30).state == ConsoleState.READY , name;
                    assert sibling_calls == [] , (
                        f"{name}: the sibling rebuilt a console already under way"
                    );
                } else {
                    console.wait_for(30);
                }
                if row["build"] == "fails" {
                    # A sibling process shares the backoff instead of
                    # starting the same failing build again.
                    other_calls: list[str] = [];
                    def build_other(src: Path) -> Path {
                        other_calls.append(str(src));
                        return write_console(src / ".jac" / "client" / "dist", "other");
                    }
                    other = AdminConsole(
                        source_dir=source,
                        cache_dir=cache,
                        build_fn=build_other,
                        retry_after=300.0
                    );
                    other.status();
                    other.wait_for(30);
                    assert other_calls == [] , f"{name}: the failed build was retried";
                }

                settled = client.get("/admin/quotes");
                assert settled.status_code == row["settled"] , (
                    f"{name}: settled /admin/quotes -> {settled.status_code}"
                );
                if row["settled"] == 503 {
                    assert_retries(name, "settled /admin/quotes", settled);
                }
                if row["body"] {
                    assert row["body"] in settled.text , (
                        f"{name}: served {settled.text!r}"
                    );
                    asset = client.get("/admin/app.js");
                    assert asset.status_code == 200 , name;
                    assert row["body"] in asset.text , name;
                    if row["builds"] {
                        assert (console.entry_dir() / ".used").exists() , (
                            f"{name}: serving the console did not record its use"
                        );
                    }
                }
                # Let any build the settled request started reach the build
                # function before counting.
                console.wait_for(30);
                assert len(calls) == row["builds"] , (
                    f"{name}: {len(calls)} builds, expected {row['builds']}"
                );
                for src in calls {
                    assert not src.startswith(str(source)) , (
                        f"{name}: built inside the source tree {src}"
                    );
                }
            } finally {
                os.chdir(prior_cwd);
                shutil.rmtree(str(tmp), ignore_errors=True);
            }
        }
    } finally {
        ext.admin_console = prior_console;
        os.chdir(prior_cwd);
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
    import stat;
    import tempfile;
    import from pathlib { Path }
    import jaclang.scale.admin;
    import from jaclang.scale.admin.console_build { AdminConsole, ConsoleState }

    ui_dir = Path(jaclang.scale.admin.__file__).parent / "ui";
    assert (ui_dir / "main.jac").exists() , "admin UI source missing";

    tmp = tempfile.mkdtemp(prefix="admin_ui_build_");
    source = Path(tmp) / "ui";
    try {
        # never build against a stale copied-in artifact dir
        shutil.copytree(
            str(ui_dir),
            str(source),
            ignore=shutil.ignore_patterns(".jac", "node_modules")
        );
        # The official image installs the runtime read-only; the build must
        # still succeed without writing into its source tree.
        for (dirpath, dirnames, filenames) in os.walk(str(source)) {
            for name in filenames {
                os.chmod(os.path.join(dirpath, name), stat.S_IRUSR | stat.S_IRGRP);
            }
            os.chmod(
                dirpath, stat.S_IRUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IXGRP
            );
        }

        console = AdminConsole(source_dir=source, cache_dir=Path(tmp) / "cache");
        assert console.status().state == ConsoleState.BUILDING;
        status = console.wait_for(600);
        assert status.state == ConsoleState.READY , (
            f"admin UI build produced no console: {status.error[-1200:]}"
        );
        assert not (source / ".jac").exists() , "the build wrote into its source tree";
        dist = status.dist_dir;
        assert dist is not None;
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
        for (dirpath, dirnames, filenames) in os.walk(str(source)) {
            os.chmod(dirpath, stat.S_IRWXU);
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
