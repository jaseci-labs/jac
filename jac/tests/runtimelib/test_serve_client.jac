"""Tests for JacAPIServer using JacTestClient (port-free).

This file mirrors the tests in test_serve_client.py but uses native Jac test syntax.
"""

import io;
import json;
import logging;
import re;
import shutil;
import uuid;
import from pathlib { Path }
import from pickle { dumps, loads }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}

def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api.jac"), base_path=base_path
    );
}

def make_imports_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api_with_imports.jac"), base_path=base_path
    );
}

def make_access_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api_access.jac"), base_path=base_path
    );
}

def make_imported_access_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api_with_access_imports.jac"), base_path=base_path
    );
}

"""Create test client for client_app.jac with isolated fixtures."""
def make_client_app_client(tmp_path: str) -> JacTestClient {
    fixtures_src = Path(fixture_abs_path("")).resolve();
    unique_id = uuid.uuid4().hex[:8];
    module_name = f"client_app_{unique_id}";
    fixtures_dest = Path(tmp_path) / module_name;
    fixtures_dest.mkdir(parents=True, exist_ok=True);
    for f in fixtures_src.glob("*.jac") {
        if f.is_file() {
            dest_name = f.name;
            if f.name == "client_app.jac" {
                dest_name = f"{module_name}.jac";
            }
            shutil.copy(f, fixtures_dest / dest_name);
        }
    }
    return JacTestClient.from_file(
        str(fixtures_dest / f"{module_name}.jac"),
        base_path=str(fixtures_dest),
        module_name=module_name
    );
}

def make_fullstack_app_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("client_fullstack_app.jac"), base_path=base_path
    );
}

"""Create test client with base_route_app configured for SPA catch-all."""
def make_spa_client(tmp_path: str) -> JacTestClient {
    import from jaclang.project.config { JacConfig, ServeConfig, set_config }
    fixtures_src = Path(fixture_abs_path("")).resolve();
    unique_id = uuid.uuid4().hex[:8];
    module_name = f"spa_app_{unique_id}";
    fixtures_dest = Path(tmp_path) / module_name;
    fixtures_dest.mkdir(parents=True, exist_ok=True);
    for f in fixtures_src.glob("*.jac") {
        if f.is_file() {
            dest_name = f.name;
            if f.name == "client_app.jac" {
                dest_name = f"{module_name}.jac";
            }
            shutil.copy(f, fixtures_dest / dest_name);
        }
    }
    set_config(JacConfig(serve=ServeConfig(base_route_app="client_page")));
    return JacTestClient.from_file(
        str(fixtures_dest / f"{module_name}.jac"),
        base_path=str(fixtures_dest),
        module_name=module_name
    );
}

"""Attach a StringIO handler to logger and return (buf, handler, old_level)."""
def capture_log_start(logger: logging.Logger, level: int = logging.DEBUG) -> tuple {
    buf = io.StringIO();
    handler = logging.StreamHandler(buf);
    handler.setLevel(level);
    logger.addHandler(handler);
    old_level = logger.level;
    logger.setLevel(level);
    return (buf, handler, old_level);
}

"""Remove handler and restore logger level."""
def capture_log_stop(
    logger: logging.Logger, handler: logging.StreamHandler, old_level: int
) -> None {
    logger.removeHandler(handler);
    logger.setLevel(old_level);
}

# =============================================================================
# TestServerClientMigrated (27 tests)
# =============================================================================
test "serve user creation" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.post(
            "/user/register", json={"username": "alice", "password": "secret123"}
        );
        assert response.ok;
        data = response.data;
        assert "username" in data;
        assert "token" in data;
        assert "root_id" in data;
        assert data["username"] == "alice";
        client.close();
    }
}

test "serve user login" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Create user
        create_response = client.post(
            "/user/register", json={"username": "bob", "password": "pass456"}
        );
        create_data = create_response.data;
        # Login with correct credentials
        login_response = client.post(
            "/user/login", json={"username": "bob", "password": "pass456"}
        );
        assert login_response.ok;
        login_data = login_response.data;
        assert "token" in login_data;
        assert login_data["username"] == "bob";
        assert login_data["root_id"] == create_data["root_id"];
        # Login with wrong password
        client.clear_auth();
        fail_response = client.post(
            "/user/login", json={"username": "bob", "password": "wrongpass"}
        );
        assert not fail_response.ok or "error" in fail_response.json();
        client.close();
    }
}

test "serve get user info success" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Register a new user
        register_response = client.register_user("testuser", "testpass123");
        assert register_response.ok;
        assert register_response.status_code == 201;
        register_data = register_response.data;
        assert "username" in register_data;
        assert "token" in register_data;
        assert "root_id" in register_data;
        assert register_data["username"] == "testuser";
        expected_username = register_data["username"];
        expected_token = register_data["token"];
        expected_root_id = register_data["root_id"];
        # Get user info
        info_response = client.get("/user/info");
        assert info_response.ok;
        assert info_response.status_code == 200;
        info_data = info_response.data;
        assert "username" in info_data;
        assert "token" in info_data;
        assert "root_id" in info_data;
        assert info_data["username"] == expected_username;
        assert info_data["token"] == expected_token;
        assert info_data["root_id"] == expected_root_id;
        client.close();
    }
}

test "serve get user info after login" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        register_response = client.register_user("loginuser", "loginpass456");
        assert register_response.ok;
        register_data = register_response.data;
        expected_username = register_data["username"];
        expected_root_id = register_data["root_id"];
        # Clear auth and login again
        client.clear_auth();
        login_response = client.login("loginuser", "loginpass456");
        assert login_response.ok;
        login_data = login_response.data;
        # Get user info with the login token
        info_response = client.get("/user/info");
        assert info_response.ok;
        assert info_response.status_code == 200;
        info_data = info_response.data;
        assert info_data["username"] == expected_username;
        assert info_data["username"] == login_data["username"];
        assert info_data["root_id"] == expected_root_id;
        assert info_data["root_id"] == login_data["root_id"];
        assert info_data["token"] == login_data["token"];
        client.close();
    }
}

test "serve get user info requires auth" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.clear_auth();
        response = client.get("/user/info");
        assert not response.ok;
        assert response.status_code == 401;
        if response.data {
            assert "error" in response.data or "message" in response.data;
        } else {
            assert "error" in response.text.lower()
            or "unauthorized" in response.text.lower();
        }
        client.close();
    }
}

test "serve get user info invalid token" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.set_auth_token("invalid_token_12345");
        response = client.get("/user/info");
        assert not response.ok;
        assert response.status_code == 401;
        if response.data {
            assert "error" in response.data or "message" in response.data;
        } else {
            assert "error" in response.text.lower()
            or "unauthorized" in response.text.lower();
        }
        client.close();
    }
}

test "serve get user info different users" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Register first user
        client.register_user("user1", "pass1");
        user1_info_response = client.get("/user/info");
        assert user1_info_response.ok;
        user1_info = user1_info_response.data;
        user1_token = user1_info["token"];
        # Register second user
        client.clear_auth();
        client.register_user("user2", "pass2");
        user2_info_response = client.get("/user/info");
        assert user2_info_response.ok;
        user2_info = user2_info_response.data;
        # Verify they are different users
        assert user1_info["username"] == "user1";
        assert user2_info["username"] == "user2";
        assert user1_info["root_id"] != user2_info["root_id"];
        assert user1_info["token"] != user2_info["token"];
        # Switch back to user1's token
        client.set_auth_token(user1_token);
        user1_info_again_response = client.get("/user/info");
        assert user1_info_again_response.ok;
        user1_info_again = user1_info_again_response.data;
        assert user1_info_again["username"] == "user1";
        assert user1_info_again["root_id"] == user1_info["root_id"];
        assert user1_info_again["token"] == user1_info["token"];
        client.close();
    }
}

test "serve authentication required" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/protected");
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        client.close();
    }
}

test "serve list functions" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("funcuser", "pass");
        response = client.get("/functions");
        assert response.ok;
        data = response.data;
        assert "functions" in data;
        assert "add_numbers" in data["functions"];
        assert "greet" in data["functions"];
        client.close();
    }
}

test "serve get function signature" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("siguser", "pass");
        response = client.get("/function/add_numbers");
        assert response.ok;
        data = response.data;
        assert "signature" in data;
        sig = data["signature"];
        assert "parameters" in sig;
        assert "a" in sig["parameters"];
        assert "b" in sig["parameters"];
        assert sig["parameters"]["a"]["required"] is True;
        assert sig["parameters"]["b"]["required"] is True;
        client.close();
    }
}

test "serve call function" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("calluser", "pass");
        # Call add_numbers
        response = client.post("/function/add_numbers", json={"a": 10, "b": 25});
        assert response.ok;
        data = response.data;
        assert "result" in data;
        assert data["result"] == 35;
        # Call greet
        response2 = client.post("/function/greet", json={"name": "World"});
        assert response2.ok;
        data2 = response2.data;
        assert "result" in data2;
        assert data2["result"] == "Hello, World!";
        client.close();
    }
}

test "serve call function with defaults" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("defuser", "pass");
        response = client.post("/function/greet", json={});
        assert response.ok;
        data = response.data;
        assert "result" in data;
        assert data["result"] == "Hello, World!";
        client.close();
    }
}

test "serve list walkers" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("walkuser", "pass");
        response = client.get("/walkers");
        assert response.ok;
        data = response.data;
        assert "walkers" in data;
        assert "CreateTask" in data["walkers"];
        assert "ListTasks" in data["walkers"];
        assert "CompleteTask" in data["walkers"];
        client.close();
    }
}

test "serve get walker info" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("infouser", "pass");
        response = client.get("/walker/CreateTask");
        assert response.ok;
        data = response.data;
        assert "info" in data;
        info = data["info"];
        assert "fields" in info;
        assert "title" in info["fields"];
        assert "priority" in info["fields"];
        assert "_jac_spawn_node" in info["fields"];
        # Check that priority has a default
        assert info["fields"]["priority"]["required"] is False;
        assert info["fields"]["priority"]["default"] is not None;
        client.close();
    }
}

test "serve spawn walker" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("spawnuser", "pass");
        # Spawn CreateTask walker
        response = client.post(
            "/walker/CreateTask", json={"title": "Test Task", "priority": 2}
        );
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        # Get jid from response for later use
        jid = data.get("reports", [{}])[0].get("_jac_id", "");
        # Spawn ListTasks walker to verify task was created
        response2 = client.post("/walker/ListTasks", json={});
        assert response2.ok;
        data2 = response2.data;
        assert "result" in data2 or "reports" in data2;
        rpt = data2.get("reports", "")[0];
        assert "Test Task" in rpt[0].get("title", "");
        assert rpt[0].get("completed", False) is True;
        # Get Task node using GetTask walker
        if jid {
            response3 = client.post(f"/walker/GetTask/{jid}", json={});
            assert response3.ok;
            data3 = response3.data;
            assert "result" in data3 or "reports" in data3;
        }
        client.close();
    }
}

test "serve user isolation" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Create two users
        user1_response = client.post(
            "/user/register", json={"username": "user1", "password": "pass1"}
        );
        user1_data = user1_response.data;
        client.clear_auth();
        user2_response = client.post(
            "/user/register", json={"username": "user2", "password": "pass2"}
        );
        user2_data = user2_response.data;
        # User1 creates a task
        client.set_auth_token(user1_data["token"]);
        client.post(
            "/walker/CreateTask",
            json={"fields": {"title": "User1 Task", "priority": 1}}
        );
        # User2 creates a different task
        client.set_auth_token(user2_data["token"]);
        client.post(
            "/walker/CreateTask",
            json={"fields": {"title": "User2 Task", "priority": 2}}
        );
        # Both users should have different root IDs
        assert user1_data["root_id"] != user2_data["root_id"];
        client.close();
    }
}

test "serve invalid function" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("invaliduser", "pass");
        response = client.post("/function/nonexistent", json={});
        assert not response.ok or "error" in response.json();
        client.close();
    }
}

test "serve invalid walker" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("invalidwalk", "pass");
        response = client.post("/walker/NonExistentWalker", json={"fields": {}});
        assert not response.ok or "error" in response.json();
        client.close();
    }
}

test "serve root endpoint" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/");
        assert response.ok;
        data = response.data;
        assert "message" in data;
        assert "endpoints" in data;
        assert "POST /user/register" in data["endpoints"];
        assert "POST /user/login" in data["endpoints"];
        assert "GET /user/info" in data["endpoints"];
        assert "GET /functions" in data["endpoints"];
        assert "GET /walkers" in data["endpoints"];
        client.close();
    }
}

test "serve update username" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        create_response = client.post(
            "/user/register", json={"username": "olduser", "password": "pass123"}
        );
        assert create_response.ok;
        token = create_response.data["token"];
        original_root_id = create_response.data["root_id"];
        # Update username
        client.set_auth_token(token);
        update_response = client.put(
            "/user/username",
            json={"current_username": "olduser", "new_username": "newuser"}
        );
        assert update_response.ok;
        assert update_response.data["username"] == "newuser";
        assert update_response.data["root_id"] == original_root_id;
        assert "token" in update_response.data;
        # Login with new username should work
        client.clear_auth();
        login_response = client.login("newuser", "pass123");
        assert login_response.ok;
        assert login_response.data["username"] == "newuser";
        # Login with old username should fail
        client.clear_auth();
        old_login_response = client.login("olduser", "pass123");
        assert not old_login_response.ok;
        client.close();
    }
}

test "serve update username requires auth" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.post(
            "/user/register", json={"username": "authtest", "password": "pass123"}
        );
        client.clear_auth();
        response = client.put(
            "/user/username",
            json={"current_username": "authtest", "new_username": "newname"}
        );
        assert not response.ok;
        assert response.status_code == 401;
        client.close();
    }
}

test "serve update username cannot update other users" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        user1_response = client.post(
            "/user/register", json={"username": "user1", "password": "pass1"}
        );
        user1_token = user1_response.data["token"];
        client.clear_auth();
        client.post("/user/register", json={"username": "user2", "password": "pass2"});
        # User1 tries to update user2's username
        client.set_auth_token(user1_token);
        response = client.put(
            "/user/username",
            json={"current_username": "user2", "new_username": "hacked"}
        );
        assert not response.ok;
        assert response.status_code == 403;
        client.close();
    }
}

test "serve update username already exists" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response1 = client.post(
            "/user/register", json={"username": "user_a", "password": "pass1"}
        );
        token = response1.data["token"];
        client.clear_auth();
        client.post("/user/register", json={"username": "user_b", "password": "pass2"});
        # Try to update user_a to user_b (already exists)
        client.set_auth_token(token);
        response = client.put(
            "/user/username",
            json={"current_username": "user_a", "new_username": "user_b"}
        );
        assert not response.ok;
        assert response.status_code == 400;
        client.close();
    }
}

test "serve update password" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        create_response = client.post(
            "/user/register", json={"username": "passuser", "password": "oldpass"}
        );
        assert create_response.ok;
        token = create_response.data["token"];
        # Update password
        client.set_auth_token(token);
        update_response = client.put(
            "/user/password",
            json={
                "username": "passuser",
                "current_password": "oldpass",
                "new_password": "newpass"
            }
        );
        assert update_response.ok;
        assert update_response.data["username"] == "passuser";
        assert "message" in update_response.data;
        # Login with new password should work
        client.clear_auth();
        login_response = client.login("passuser", "newpass");
        assert login_response.ok;
        # Login with old password should fail
        client.clear_auth();
        old_login_response = client.login("passuser", "oldpass");
        assert not old_login_response.ok;
        client.close();
    }
}

test "serve update password requires auth" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.post(
            "/user/register", json={"username": "noauthpass", "password": "pass123"}
        );
        client.clear_auth();
        response = client.put(
            "/user/password",
            json={
                "username": "noauthpass",
                "current_password": "pass123",
                "new_password": "newpass"
            }
        );
        assert not response.ok;
        assert response.status_code == 401;
        client.close();
    }
}

test "serve update password wrong current" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        create_response = client.post(
            "/user/register", json={"username": "wrongpass", "password": "correctpass"}
        );
        token = create_response.data["token"];
        client.set_auth_token(token);
        response = client.put(
            "/user/password",
            json={
                "username": "wrongpass",
                "current_password": "wrongpassword",
                "new_password": "newpass"
            }
        );
        assert not response.ok;
        assert response.status_code == 400;
        client.close();
    }
}

test "serve update password cannot update other users" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        user1_response = client.post(
            "/user/register", json={"username": "pass_user1", "password": "pass1"}
        );
        user1_token = user1_response.data["token"];
        client.clear_auth();
        client.post(
            "/user/register", json={"username": "pass_user2", "password": "pass2"}
        );
        # User1 tries to update user2's password
        client.set_auth_token(user1_token);
        response = client.put(
            "/user/password",
            json={
                "username": "pass_user2",
                "current_password": "pass2",
                "new_password": "hacked"
            }
        );
        assert not response.ok;
        assert response.status_code == 403;
        client.close();
    }
}

# =============================================================================
# TestImportedFunctionsAndWalkers (1 test)
# =============================================================================
test "serve imported functions and walkers" {
    with TemporaryDirectory() as tmpdir {
        imports_client = make_imports_client(tmpdir);
        imports_client.register_user("importuser", "pass");
        # Test listing functions - should include both local and imported
        functions_response = imports_client.get("/functions");
        assert functions_response.ok;
        functions_data = functions_response.data;
        assert "functions" in functions_data;
        functions = functions_data["functions"];
        assert "local_add" in functions , "Local function 'local_add' not found";
        assert "local_greet" in functions , "Local function 'local_greet' not found";
        assert "multiply_numbers" in functions , "Imported function 'multiply_numbers' not found";
        assert "format_message" in functions , "Imported function 'format_message' not found";
        # Test listing walkers - should include both local and imported
        walkers_response = imports_client.get("/walkers");
        assert walkers_response.ok;
        walkers_data = walkers_response.data;
        assert "walkers" in walkers_data;
        wlkrs = walkers_data["walkers"];
        assert "LocalCreateTask" in wlkrs , "Local walker 'LocalCreateTask' not found";
        assert "ImportedWalker" in wlkrs , "Imported walker 'ImportedWalker' not found";
        assert "ImportedCounter" in wlkrs , "Imported walker 'ImportedCounter' not found";
        # Test calling local function
        local_add_response = imports_client.post(
            "/function/local_add", json={"x": 5, "y": 3}
        );
        assert local_add_response.ok;
        local_add_data = local_add_response.data;
        assert "result" in local_add_data;
        assert local_add_data["result"] == 8;
        # Test calling imported function
        multiply_response = imports_client.post(
            "/function/multiply_numbers", json={"a": 4, "b": 7}
        );
        assert multiply_response.ok;
        multiply_data = multiply_response.data;
        assert "result" in multiply_data;
        assert multiply_data["result"] == 28;
        # Test calling another imported function
        format_response = imports_client.post(
            "/function/format_message", json={"prefix": "INFO", "message": "test"}
        );
        assert format_response.ok;
        format_data = format_response.data;
        assert "result" in format_data;
        assert format_data["result"] == "INFO: test";
        # Test spawning local walker
        local_walker_response = imports_client.post(
            "/walker/LocalCreateTask", json={"task_title": "My Local Task"}
        );
        assert local_walker_response.ok;
        local_walker_data = local_walker_response.data;
        assert "result" in local_walker_data or "reports" in local_walker_data;
        # Test spawning imported walker
        imported_walker_response = imports_client.post(
            "/walker/ImportedWalker", json={"item_name": "Imported Item 1"}
        );
        assert imported_walker_response.ok;
        imported_walker_data = imported_walker_response.data;
        assert "result" in imported_walker_data or "reports" in imported_walker_data;
        imports_client.close();
    }
}

# =============================================================================
# TestAccessLevels (13 tests)
# =============================================================================
test "serve public function without auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/function/public_function", json={"name": "Test"});
        assert response.ok;
        data = response.data;
        assert "result" in data;
        assert data["result"] == "Hello, Test! (public)";
        ac.close();
    }
}

test "serve public function get info without auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.get("/function/public_function");
        assert response.ok;
        data = response.data;
        assert "signature" in data;
        assert "parameters" in data["signature"];
        ac.close();
    }
}

test "serve protected function requires auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/function/protected_function", json={"message": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        ac.close();
    }
}

test "serve protected function with auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        ac.register_user("authuser", "pass123");
        response = ac.post("/function/protected_function", json={"message": "secret"});
        assert response.ok;
        data = response.data;
        assert "result" in data;
        assert data["result"] == "Protected: secret";
        ac.close();
    }
}

test "serve private function requires auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/function/private_function", json={"secret": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        ac.close();
    }
}

test "serve private function with auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        ac.register_user("privuser", "pass456");
        response = ac.post("/function/private_function", json={"secret": "topsecret"});
        assert response.ok;
        data = response.data;
        assert "result" in data;
        assert data["result"] == "Private: topsecret";
        ac.close();
    }
}

test "serve public walker without auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/walker/PublicWalker", json={"message": "hello"});
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        ac.close();
    }
}

test "serve protected walker requires auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/walker/ProtectedWalker", json={"data": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        ac.close();
    }
}

test "serve protected walker with auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        ac.register_user("walkuser", "pass789");
        response = ac.post("/walker/ProtectedWalker", json={"data": "mydata"});
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        ac.close();
    }
}

test "serve private walker requires auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.post("/walker/PrivateWalker", json={"secret": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        ac.close();
    }
}

test "serve private walker with auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        ac.register_user("privwalk", "pass000");
        response = ac.post("/walker/PrivateWalker", json={"secret": "verysecret"});
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        ac.close();
    }
}

test "serve introspection list requires auth" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        response = ac.get("/protected");
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        ac.close();
    }
}

test "serve mixed access levels" {
    with TemporaryDirectory() as tmpdir {
        ac = make_access_client(tmpdir);
        ac.register_user("mixeduser", "mixedpass");
        assert ac._auth_token is not None;
        token = str(ac._auth_token);
        # Public function without auth - should work
        ac.clear_auth();
        result1 = ac.post("/function/public_add", json={"a": 5, "b": 10});
        data1 = result1.data;
        assert "result" in data1;
        assert data1["result"] == 15;
        # Protected function without auth - should fail
        result2 = ac.post("/function/protected_function", json={"message": "test"});
        data2 = result2.data;
        assert "error" in data2;
        # Protected function with auth - should work
        ac.set_auth_token(token);
        result3 = ac.post("/function/protected_function", json={"message": "test"});
        data3 = result3.data;
        assert "result" in data3;
        # Private function with auth - should work
        result4 = ac.post("/function/private_function", json={"secret": "test"});
        data4 = result4.data;
        assert "result" in data4;
        ac.close();
    }
}

# =============================================================================
# TestClientRendering (2 tests)
# =============================================================================
test "serve render client page returns html" {
    with TemporaryDirectory() as tmpdir {
        client = make_client_app_client(tmpdir);
        client.register_user("tester", "pass");
        response = client.get("/cl/client_page");
        html = response.text;
        assert "<!DOCTYPE html>" in html;
        assert '<div id="__jac_root">' in html;
        assert "/static/client.js?hash=" in html;
        # Check __jac_init__ script contains expected data
        init_match = re.search(
            r'<script id="__jac_init__" type="application/json">([^<]*)</script>', html
        );
        assert init_match is not None;
        payload = json.loads(init_match.group(1)) if init_match else {};
        assert payload.get("function") == "client_page";
        assert payload.get("globals", {}).get("API_LABEL") == "Runtime Test";
        client.close();
    }
}

test "serve render unknown page returns error" {
    with TemporaryDirectory() as tmpdir {
        client = make_client_app_client(tmpdir);
        client.register_user("tester", "pass");
        response = client.get("/cl/missing");
        assert not response.ok or "error" in response.text.lower();
        client.close();
    }
}

# =============================================================================
# TestFullstackClientApp (1 test)
# =============================================================================
test "serve client page html and bundle" {
    with TemporaryDirectory() as tmpdir {
        client = make_fullstack_app_client(tmpdir);
        response = client.get("/cl/app");
        html = response.text;
        # HTML skeleton
        assert "<!DOCTYPE html>" in html;
        assert '<div id="__jac_root">' in html;
        assert "/static/client.js?hash=" in html;
        # Hydration payload targets the right function
        init_match = re.search(
            r'<script id="__jac_init__" type="application/json">([^<]*)</script>', html
        );
        assert init_match is not None;
        payload = json.loads(init_match.group(1));
        assert payload.get("function") == "app";
        # Fetch JS bundle
        hash_match = re.search(r'/static/client\.js\?hash=([a-f0-9]+)', html);
        assert hash_match is not None;
        bundle_js = client.get(f"/static/client.js?hash={hash_match.group(1)}").text;
        # @jac/runtime inlined (not left as ES import)
        assert "// @jac/runtime" in bundle_js;
        assert "import {" not in bundle_js;
        # has -> useState hook present
        assert "function useState(" in bundle_js;
        assert "useState([])" in bundle_js;
        # async can with entry -> useEffect present
        assert "function useEffect(" in bundle_js;
        assert "useEffect(" in bundle_js;
        # Server function call wired up
        assert "__jacCallFunction" in bundle_js;
        assert '"get_items"' in bundle_js;
        # Module registered
        assert "__jacRegisterClientModule" in bundle_js;
        assert "function app()" in bundle_js;
        client.close();
    }
}

# =============================================================================
# TestImportedWalkerAccessLevels (7 tests)
# =============================================================================
test "serve imported public walker without auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        response = iac.post(
            "/walker/PublicImportedWalker",
            json={"message": "test from imported public walker"}
        );
        assert response.ok , f"Expected success but got: {response.data}";
        data = response.data;
        assert "result" in data or "reports" in data;
        iac.close();
    }
}

test "serve imported protected walker requires auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        response = iac.post("/walker/ProtectedImportedWalker", json={"data": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        iac.close();
    }
}

test "serve imported protected walker with auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        iac.register_user("importuser", "pass123");
        response = iac.post(
            "/walker/ProtectedImportedWalker", json={"data": "authenticated data"}
        );
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        iac.close();
    }
}

test "serve imported default walker requires auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        response = iac.post("/walker/DefaultImportedWalker", json={"value": 100});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        iac.close();
    }
}

test "serve local public walker without auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        response = iac.post("/walker/LocalPublicWalker", json={"msg": "local test"});
        assert response.ok;
        data = response.data;
        assert "result" in data or "reports" in data;
        iac.close();
    }
}

test "serve local default walker requires auth" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        response = iac.post("/walker/LocalDefaultWalker", json={"msg": "test"});
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        assert "Unauthorized" in data["error"];
        iac.close();
    }
}

test "serve mixed local and imported access" {
    with TemporaryDirectory() as tmpdir {
        iac = make_imported_access_client(tmpdir);
        iac.register_user("mixeduser", "mixedpass");
        assert iac._auth_token is not None;
        token = str(iac._auth_token);
        # Imported public walker without auth - should work
        iac.clear_auth();
        result1 = iac.post(
            "/walker/PublicImportedWalker", json={"message": "public test"}
        );
        assert result1.ok , f"Imported public walker should work without auth: {result1.data}";
        # Local public walker without auth - should work
        result2 = iac.post(
            "/walker/LocalPublicWalker", json={"msg": "local public test"}
        );
        assert result2.ok , f"Local public walker should work without auth: {result2.data}";
        # Imported protected walker without auth - should fail
        result3 = iac.post("/walker/ProtectedImportedWalker", json={"data": "test"});
        assert not result3.ok , "Imported protected walker should require auth";
        # Local default walker without auth - should fail
        result4 = iac.post("/walker/LocalDefaultWalker", json={"msg": "test"});
        assert not result4.ok , "Local default walker should require auth";
        # With auth, all walkers should work
        iac.set_auth_token(token);
        result5 = iac.post(
            "/walker/ProtectedImportedWalker", json={"data": "auth test"}
        );
        assert result5.ok , f"Imported protected walker should work with auth: {result5.data}";
        result6 = iac.post("/walker/DefaultImportedWalker", json={"value": 42});
        assert result6.ok , f"Imported default walker should work with auth: {result6.data}";
        result7 = iac.post("/walker/LocalDefaultWalker", json={"msg": "auth test"});
        assert result7.ok , f"Local default walker should work with auth: {result7.data}";
        iac.close();
    }
}

# =============================================================================
# TestSPACatchAll (7 tests)
# =============================================================================
test "serve spa catchall serves html for clean urls" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        response = spa.get("/about");
        assert response.ok;
        assert response.status_code == 200;
        html = response.text;
        assert "<!DOCTYPE html>" in html;
        assert '<div id="__jac_root">' in html;
        assert "/static/client.js?hash=" in html;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve spa catchall root serves html" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        response = spa.get("/");
        assert response.ok;
        html = response.text;
        assert "<!DOCTYPE html>" in html;
        assert '<div id="__jac_root">' in html;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve spa catchall nested path" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        response = spa.get("/dashboard/settings");
        assert response.ok;
        html = response.text;
        assert "<!DOCTYPE html>" in html;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve spa catchall api paths unaffected" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        functions_response = spa.get("/functions");
        assert functions_response.ok;
        data = functions_response.data;
        assert "functions" in data;
        walkers_response = spa.get("/walkers");
        assert walkers_response.ok;
        data = walkers_response.data;
        assert "walkers" in data;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve spa catchall cl route still works" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        response = spa.get("/cl/client_page");
        assert response.ok;
        html = response.text;
        assert "<!DOCTYPE html>" in html;
        assert '<div id="__jac_root">' in html;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve spa catchall static files unaffected" {
    with TemporaryDirectory() as tmpdir {
        spa = make_spa_client(tmpdir);
        response = spa.get("/static/nonexistent.js");
        assert not response.ok;
        spa.close();
        import from jaclang.project.config { JacConfig, set_config }
        set_config(JacConfig());
    }
}

test "serve unknown path returns 404 without base route app" {
    import from jaclang.project.config { JacConfig, set_config }
    set_config(JacConfig());
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/some-unknown-path");
        assert not response.ok;
        data = response.data;
        assert "error" in data;
        client.close();
    }
}

# =============================================================================
# TestSyncAccessControl (1 test)
# =============================================================================
test "serve sync skips write access check on unchanged anchors" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("syncuser", "pass");
        # Simulate server-restart conditions
        import from jaclang.jac0core.runtime { JacRuntimeInterface as Jac }
        ctx = Jac.get_context();
        sys_root = ctx.system_root;
        sys_root.persistent = True;
        sys_root_copy = loads(dumps(sys_root));
        sys_root.__dict__.update(sys_root_copy.__dict__);
        sys_root.persistent = True;
        sys_root.hash = hash(dumps(sys_root));
        # Ensure it is present in L3's __mem__
        l3 = ctx.mem.l3;
        if l3 is not None {
            l3.put(sys_root);
            l3._ensure_connection();
            l3.__conn__.execute(
                "INSERT OR REPLACE INTO anchors (id, data) VALUES (?, ?)",
                (str(sys_root.id), dumps(sys_root))
            );
            l3.__conn__.commit();
        }
        # Capture logs
        logger = logging.getLogger("jaclang.jac0core.runtime");
        cap = capture_log_start(logger);
        buf = cap[0];
        handler = cap[1];
        old_level = cap[2];
        try {
            client.post(
                "/walker/CreateTask", json={"title": "Sync Test", "priority": 1}
            );
            client.post("/walker/ListTasks", json={});
        } finally {
            capture_log_stop(logger, handler, old_level);
        }
        assert "Current root doesn't have write access" not in buf.getvalue() , "SqliteMemory.sync() should not check write access on unchanged anchors";
        client.close();
    }
}
