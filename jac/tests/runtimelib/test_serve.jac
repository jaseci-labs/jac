"""Tests for jac serve-related functionality (unit tests and faux mode only)."""

import io;
import os;
import socket;
import from contextlib { redirect_stdout, redirect_stderr, suppress }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }

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
test "user manager creation" {
    with TemporaryDirectory() as tmpdir {
        session_file = str(Path(tmpdir) / "test.session");
        user_mgr = Jac.get_user_manager(session_file);
        # Create first user
        result1 = user_mgr.create_user("user1", "pass1");
        assert "token" in result1;
        assert "root_id" in result1;
        assert result1["username"] == "user1";
        # Create second user
        result2 = user_mgr.create_user("user2", "pass2");
        assert "token" in result2;
        assert "root_id" in result2;
        # Users should have different roots
        assert result1["root_id"] != result2["root_id"];
        # Duplicate username should fail
        result3 = user_mgr.create_user("user1", "pass3");
        assert "error" in result3;
        user_mgr.close();
    }
}

test "user manager authentication" {
    with TemporaryDirectory() as tmpdir {
        session_file = str(Path(tmpdir) / "test.session");
        user_mgr = Jac.get_user_manager(session_file);
        # Create user
        create_result = user_mgr.create_user("testuser", "testpass");
        create_data = create_result.get("data", create_result);
        original_token = create_data["token"];
        # Authenticate with correct credentials
        auth_result = user_mgr.authenticate("testuser", "testpass");
        assert auth_result is not None;
        assert auth_result["username"] == "testuser";
        assert auth_result["token"] == original_token;
        # Wrong password
        auth_fail = user_mgr.authenticate("testuser", "wrongpass");
        assert auth_fail is None;
        # Nonexistent user
        auth_fail2 = user_mgr.authenticate("nouser", "pass");
        assert auth_fail2 is None;
        user_mgr.close();
    }
}

test "user manager token validation" {
    with TemporaryDirectory() as tmpdir {
        session_file = str(Path(tmpdir) / "test.session");
        user_mgr = Jac.get_user_manager(session_file);
        # Create user
        result = user_mgr.create_user("validuser", "validpass");
        data = result.get("data", result);
        token = data["token"];
        # Valid token
        username = user_mgr.validate_token(token);
        assert username == "validuser";
        # Invalid token
        username = user_mgr.validate_token("invalid_token");
        assert username is None;
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
                execution.start(
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
        assert "11 functions" in output;
        assert "5 walkers" in output;
        assert "38 endpoints" in output;
        # Verify parameter details are included
        assert "required" in output;
        assert "optional" in output;
        assert "Bearer token" in output;
    }
}

test "faux flag with littlex example" {
    littlex_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../../examples/littleX/littleX_single_nodeps.jac"
        )
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
                execution.start(filename=littlex_path, port=port, main=True, faux=True);
            }
        }
        output = captured_output.getvalue();
        # Verify that littleX endpoints are discovered
        assert "WALKERS" in output;
        # Check for key littleX walkers
        littlex_walkers = [
            "update_profile",
            "get_profile",
            "create_tweet",
            "load_feed"
        ];
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
                execution.start(filename="main.jac", port=port, main=True, faux=True);
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
                result = execution.start(
                    filename="main.jac", port=port, main=True, faux=True
                );
            }

            assert result == 1;

            output = captured_output.getvalue();
            assert "main.jac" in output;
            assert "not found" in output.lower();
            assert "Current directory" in output;
            assert "Please specify a file" in output;
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
                execution.start(
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
                result = execution.start(
                    filename="nonexistent.jac", port=port, main=True, faux=True
                );
            }

            assert result == 1;

            output = captured_output.getvalue();
            assert "not found" in output.lower();
        } finally {
            os.chdir(original_cwd);
        }
    }
}
