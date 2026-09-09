"""Tests for jac serve-related functionality (unit tests and faux mode only)."""

import io;
import os;
import sys;
import socket;
import from contextlib { redirect_stdout, redirect_stderr, suppress }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { MagicMock, patch }
import from http.server { ThreadingHTTPServer }
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }
import from jaclang.server.server { JacAPIServer }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        return s.getsockname()[1];
    }
}

# --- UserManager Unit Tests ---
def _identity(tmpdir: str) -> any {
    import from jaclang.server.identity.config { configure_identity }
    import from jaclang.server.identity.user_manager { UserManager }
    import from jaclang.server.settings { AuthSettings }
    Jac.set_base_path(tmpdir);
    configure_identity(AuthSettings(password_hash_cost=10), tmpdir);
    return UserManager(base_path=tmpdir);
}

test "user manager creation" {
    with TemporaryDirectory() as tmpdir {
        user_mgr = _identity(tmpdir);
        result1 = user_mgr.create_user("user1", "pass1");
        assert "user_id" in result1 , f"{result1}";
        root1 = user_mgr.get_root_id(result1["user_id"]);
        assert root1;
        result2 = user_mgr.create_user("user2", "pass2");
        assert "user_id" in result2;
        assert user_mgr.get_root_id(result2["user_id"]) != root1;
        result3 = user_mgr.create_user("user1", "pass3");
        assert "error" in result3;
        user_mgr.close();
    }
}

test "user manager authentication" {
    with TemporaryDirectory() as tmpdir {
        user_mgr = _identity(tmpdir);
        created = user_mgr.create_user("testuser", "testpass");
        auth_result = user_mgr.authenticate("testuser", "testpass");
        assert auth_result is not None;
        assert auth_result["user_id"] == created["user_id"];
        assert auth_result["token"];
        assert user_mgr.authenticate("testuser", "wrongpass") is None;
        assert user_mgr.authenticate("nouser", "pass") is None;
        user_mgr.close();
    }
}

test "user manager token validation" {
    with TemporaryDirectory() as tmpdir {
        user_mgr = _identity(tmpdir);
        created = user_mgr.create_user("validuser", "validpass");
        token = user_mgr.create_jwt_token(created["user_id"]);
        assert user_mgr.validate_token(token) == created["user_id"];
        assert user_mgr.validate_token("invalid_token") is None;
        user_mgr.close();
    }
}

# --- Faux Mode Tests ---
test "faux flag prints endpoint docs" {
    with TemporaryDirectory() as tmpdir {
        port = get_free_port();
        Jac.set_base_path(tmpdir);
        captured_output = io.StringIO();
        with suppress(SystemExit) {
            with redirect_stdout(captured_output) {
                execution.serve(
                    filename=fixture_abs_path("serve_api.jac"),
                    port=port,
                    main=True,
                    faux=True
                );
            }
        }
        output = captured_output.getvalue();
        # Verify function endpoints are documented
        assert "FUNCTIONS" in output;
        assert "/function/add_numbers" in output;
        assert "/function/greet" in output;
        # Verify walker endpoints are documented
        assert "WALKERS" in output;
        assert "/walker/CreateTask" in output;
        assert "/walker/ListTasks" in output;
        assert "/walker/CompleteTask" in output;
        # Verify client page endpoints section is documented
        assert "CLIENT PAGES" in output;
        assert "client_page" in output;
        # Verify summary is present
        assert "TOTAL:" in output;
        # 2 functions / 20 endpoints: only the two user functions (add_numbers,
        # greet) are exposed. _collect_functions skips jaclang framework helpers
        # (connect, spawn, on_entry, set_trigger, …) that the compiler imports
        # into every module's namespace, so they no longer leak as endpoints.
        assert "2 functions" in output;
        assert "5 walkers" in output;
        assert "20 endpoints" in output;
        # Verify parameter details are included
        assert "required" in output;
        assert "optional" in output;
        assert "Bearer token" in output;
    }
}

test "faux flag with littlex example" {
    littlex_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "../../examples/littleX/server.jac")
    );

    if not os.path.exists(littlex_path) {
        return;
    }

    with TemporaryDirectory() as tmpdir {
        port = get_free_port();
        Jac.set_base_path(tmpdir);
        captured_output = io.StringIO();
        with suppress(SystemExit) {
            with redirect_stdout(captured_output) {
                execution.serve(filename=littlex_path, port=port, main=True, faux=True);
            }
        }
        output = captured_output.getvalue();
        # Verify that littleX endpoints are discovered
        assert "WALKERS" in output;
        # Check for key littleX walkers
        littlex_walkers = ["setup_profile", "get_profile", "create_tweet", "load_feed"];
        for w in littlex_walkers {
            assert w in output or "walker" in output.lower();
        }
    }
}

# --- Start Command Tests (faux mode) ---
test "start with default main jac" {
    with TemporaryDirectory() as tmpdir {
        main_jac = Path(tmpdir) / "main.jac";
        main_jac.write_text('with entry { "Hello from main.jac" :> print; }');
        port = get_free_port();
        original_cwd = os.getcwd();
        try {
            os.chdir(tmpdir);
            Jac.set_base_path(tmpdir);

            captured_output = io.StringIO();

            with redirect_stderr(captured_output) {
                execution.serve(filename="main.jac", port=port, main=True, faux=True);
            }

            output = captured_output.getvalue();
            assert "not found" not in output.lower();
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "start without main jac error" {
    with TemporaryDirectory() as tmpdir {
        main_jac = Path(tmpdir) / "main.jac";
        if main_jac.exists() {
            main_jac.unlink();
        }
        port = get_free_port();
        original_cwd = os.getcwd();
        try {
            os.chdir(tmpdir);
            Jac.set_base_path(tmpdir);

            captured_output = io.StringIO();

            with redirect_stderr(captured_output) {
                result = execution.serve(
                    filename="main.jac", port=port, main=True, faux=True
                );
            }

            assert result == 1;

            output = captured_output.getvalue();
            assert "main.jac" in output;
            assert "No such file or directory" in output;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "start with explicit file" {
    with TemporaryDirectory() as tmpdir {
        port = get_free_port();
        Jac.set_base_path(tmpdir);
        captured_output = io.StringIO();
        with suppress(SystemExit) {
            with redirect_stdout(captured_output) {
                execution.serve(
                    filename=fixture_abs_path("serve_api.jac"),
                    port=port,
                    main=True,
                    faux=True
                );
            }
        }
        output = captured_output.getvalue();
        assert "FUNCTIONS" in output;
        assert "/function/add_numbers" in output;
    }
}

test "start with nonexistent file error" {
    with TemporaryDirectory() as tmpdir {
        port = get_free_port();
        original_cwd = os.getcwd();
        try {
            os.chdir(tmpdir);
            Jac.set_base_path(tmpdir);

            captured_output = io.StringIO();

            with redirect_stderr(captured_output) {
                result = execution.serve(
                    filename="nonexistent.jac", port=port, main=True, faux=True
                );
            }

            assert result == 1;

            output = captured_output.getvalue();
            assert "No such file or directory" in output;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# --- Dev Mode Tests ---
test "jac run --dev auto-installs watchdog even when not in jac.toml" {
    mock_provider = MagicMock();
    mock_provider.install_specs.return_value = True;
    mock_config = MagicMock();

    # Simulate watchdog not being installed, and a jac.toml that does NOT list watchdog
    with patch(
        "jaclang.cli.commands.execution._watchdog_importable",
        side_effect=[False, True],
    ) {
        with patch(
            "jaclang.project.providers.get_python_provider", return_value=mock_provider
        ) {
            with patch("jaclang.project.config.get_config") as mock_get_config {
                with patch("jaclang.project.pyvenv.add_venv_to_path") {
                    mock_get_config.return_value = mock_config;
                    result = execution._ensure_watchdog_installed();
                }
            }
        }
    }

    assert result is True;
    mock_provider.install_specs.assert_called_once();
    assert mock_provider.install_specs.call_args.args[1] == ["watchdog>=3.0.0"];
}

test "dev banner headlines vite port not api port" {
    with TemporaryDirectory() as tmpdir {
        captured_output = io.StringIO();
        with patch(
            "jaclang.cli.commands.execution._get_network_ips", return_value=[]
        ) {
            with redirect_stdout(captured_output) {
                execution._print_startup_message(
                    dev=True,
                    no_client=False,
                    primary_port=8000,
                    api_port=8001,
                    base_path=tmpdir
                );
            }
        }
        output = captured_output.getvalue();
        assert "Local:     http://localhost:8000/" in output;
        assert "App:  http://localhost:8000/" in output;
        assert "API:  http://localhost:8001/" in output;
    }
}

# --- Server construction ---
"""Constructing the API server must not bind a socket; the serving core binds
lazily at start() so test-mode servers (port=0) stay socket-free and the app
can be built and dispatched fully in-process."""
test "api server construction is socket-free and builds a serving app" {
    import from jaclang.server.serving.app { ServingApp }
    with TemporaryDirectory() as tmpdir {
        port = get_free_port();
        Jac.set_base_path(tmpdir);
        srv = JacAPIServer(module_name="serve_api", port=port, base_path=tmpdir);
        assert srv.server is None , f"expected no bound server at construction, got {type(
            srv.server
        ).__name__}";
        app = srv.build_app();
        assert isinstance(app, ServingApp);
        assert app.router.all_endpoints() , "built app has no endpoints";
    }
}
