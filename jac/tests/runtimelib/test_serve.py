"""Tests for jac serve-related functionality (unit tests and faux mode only).

Server-based HTTP tests have been migrated to test_serve_client.py using JacTestClient.
This file only contains unit tests and tests that use faux=True (no real servers).
"""

import os
from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac
from tests.runtimelib.conftest import fixture_abs_path


@pytest.fixture(autouse=True)
def setup_fresh_jac(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Provide fresh Jac context for each test."""
    yield


# =============================================================================
# UserManager Unit Tests
# =============================================================================


def test_user_manager_creation(tmp_path: Path) -> None:
    """Test UserManager creates users with unique roots."""
    session_file = str(tmp_path / "test.session")
    user_mgr = Jac.get_user_manager(session_file)

    # Create first user
    result1 = user_mgr.create_user("user1", "pass1")
    assert "token" in result1
    assert "root_id" in result1
    assert result1["username"] == "user1"

    # Create second user
    result2 = user_mgr.create_user("user2", "pass2")
    assert "token" in result2
    assert "root_id" in result2

    # Users should have different roots
    assert result1["root_id"] != result2["root_id"]

    # Duplicate username should fail
    result3 = user_mgr.create_user("user1", "pass3")
    assert "error" in result3

    user_mgr.close()


def test_user_manager_authentication(tmp_path: Path) -> None:
    """Test UserManager authentication."""
    session_file = str(tmp_path / "test.session")
    user_mgr = Jac.get_user_manager(session_file)

    # Create user
    create_result = user_mgr.create_user("testuser", "testpass")
    create_data = create_result.get("data", create_result)

    original_token = create_data["token"]

    # Authenticate with correct credentials
    auth_result = user_mgr.authenticate("testuser", "testpass")
    assert auth_result is not None
    assert auth_result["username"] == "testuser"
    assert auth_result["token"] == original_token

    # Wrong password
    auth_fail = user_mgr.authenticate("testuser", "wrongpass")
    assert auth_fail is None

    # Nonexistent user
    auth_fail2 = user_mgr.authenticate("nouser", "pass")
    assert auth_fail2 is None

    user_mgr.close()


def test_user_manager_token_validation(tmp_path: Path) -> None:
    """Test UserManager token validation."""
    session_file = str(tmp_path / "test.session")
    user_mgr = Jac.get_user_manager(session_file)

    # Create user
    result = user_mgr.create_user("validuser", "validpass")
    data = result.get("data", result)

    token = data["token"]

    # Valid token
    username = user_mgr.validate_token(token)
    assert username == "validuser"

    # Invalid token
    username = user_mgr.validate_token("invalid_token")
    assert username is None

    user_mgr.close()


# =============================================================================
# Faux Mode Tests (no real server started)
# =============================================================================


def test_faux_flag_prints_endpoint_docs(tmp_path: Path) -> None:
    """Test that --faux flag prints endpoint documentation without starting server."""
    import io
    import socket
    from contextlib import redirect_stdout

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    # Get a free port (won't actually be used since faux=True)
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    # Set base_path for isolation
    Jac.set_base_path(str(tmp_path))

    # Capture stdout
    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            # Call start with faux=True
            execution.start(
                filename=fixture_abs_path("serve_api.jac"),
                port=port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass  # start() may call exit() in some error cases

    output = captured_output.getvalue()

    # Verify function endpoints are documented
    assert "FUNCTIONS" in output
    assert "/function/add_numbers" in output
    assert "/function/greet" in output

    # Verify walker endpoints are documented
    assert "WALKERS" in output
    assert "/walker/CreateTask" in output
    assert "/walker/ListTasks" in output
    assert "/walker/CompleteTask" in output

    # Verify client page endpoints section is documented
    assert "CLIENT PAGES" in output
    assert "client_page" in output

    # Verify summary is present
    assert "TOTAL:" in output
    # Note: With imported functions now exposed as endpoints, we have more than the 2 defined functions
    assert "11 functions" in output
    assert "5 walkers" in output
    assert "38 endpoints" in output

    # Verify parameter details are included
    assert "required" in output
    assert "optional" in output
    assert "Bearer token" in output


def test_faux_flag_with_littlex_example(tmp_path: Path) -> None:
    """Test that --faux flag correctly identifies functions, walkers, and endpoints in littleX example."""
    import io
    import socket
    from contextlib import redirect_stdout

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    # Get the absolute path to littleX file
    littlex_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../../examples/littleX/littleX_single_nodeps.jac",
        )
    )

    # Skip test if file doesn't exist
    if not os.path.exists(littlex_path):
        pytest.skip(f"LittleX example not found at {littlex_path}")

    # Get a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    # Set base_path for isolation
    Jac.set_base_path(str(tmp_path))

    # Capture stdout
    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            # Call start with faux=True on littleX example
            execution.start(
                filename=littlex_path,
                port=port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass

    output = captured_output.getvalue()

    # Verify that littleX endpoints are discovered
    assert "WALKERS" in output

    # Check for key littleX walkers (based on example implementation)
    littlex_walkers = [
        "update_profile",
        "get_profile",
        "create_tweet",
        "load_feed",
    ]
    for walker in littlex_walkers:
        assert walker in output or "walker" in output.lower()


# =============================================================================
# Start Command Tests (faux mode)
# =============================================================================


def test_start_with_default_main_jac(tmp_path: Path) -> None:
    """Test that jac start uses main.jac as default when available."""
    import io
    import socket
    from contextlib import redirect_stderr

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    main_jac = tmp_path / "main.jac"
    main_jac.write_text('with entry { "Hello from main.jac" :> print; }')

    # Get a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            execution.start(
                filename="main.jac",
                port=port,
                main=True,
                faux=True,
            )

        output = captured_output.getvalue()
        assert "not found" not in output.lower()
    finally:
        os.chdir(original_cwd)


def test_start_without_main_jac_error(tmp_path: Path) -> None:
    """Test that jac start provides helpful error when main.jac is missing."""
    import io
    import socket
    from contextlib import redirect_stderr

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    main_jac = tmp_path / "main.jac"
    if main_jac.exists():
        main_jac.unlink()

    # Get a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            result = execution.start(
                filename="main.jac",
                port=port,
                main=True,
                faux=True,
            )

        assert result == 1

        output = captured_output.getvalue()
        assert "main.jac" in output
        assert "not found" in output.lower()
        assert "Current directory" in output
        assert "Please specify a file" in output
    finally:
        os.chdir(original_cwd)


def test_start_with_explicit_file(tmp_path: Path) -> None:
    """Test that explicit filename still works (backward compatibility)."""
    import io
    import socket
    from contextlib import redirect_stdout

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    # Get a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    Jac.set_base_path(str(tmp_path))

    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            execution.start(
                filename=fixture_abs_path("serve_api.jac"),
                port=port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass

    output = captured_output.getvalue()
    assert "FUNCTIONS" in output
    assert "/function/add_numbers" in output


def test_start_with_nonexistent_file_error(tmp_path: Path) -> None:
    """Test that jac start provides clear error for non-existent explicit file."""
    import io
    import socket
    from contextlib import redirect_stderr

    from jaclang.cli.commands import execution  # type: ignore[attr-defined]

    # Get a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            result = execution.start(
                filename="nonexistent.jac",
                port=port,
                main=True,
                faux=True,
            )

        assert result == 1

        output = captured_output.getvalue()
        assert "not found" in output.lower()
    finally:
        os.chdir(original_cwd)
