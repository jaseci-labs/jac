"""Tests for terminal_manager — interactive PTY terminal sessions."""

import os;
import time;
import tempfile;

import from services.terminal_manager {
    start_terminal,
    stop_terminal,
    send_terminal_input,
    resize_terminal,
    drain_terminal_output,
    get_terminal_status,
    _term_registry,
    _term_key
}


test "test_start_stop_terminal" {
    user_id = "test_user_term_" + str(int(time.time() * 1000));
    project_id = "test_proj_term";
    cwd = tempfile.gettempdir();

    result = start_terminal(user_id, project_id, cwd);
    assert result["success"] == True, "start_terminal should succeed: " + str(result);
    assert result["status"] == "started" or result["status"] == "already_running";

    status = get_terminal_status(user_id, project_id);
    assert status["running"] == True, "Terminal should be running";

    stop_result = stop_terminal(user_id, project_id);
    assert stop_result["success"] == True, "stop_terminal should succeed";

    status_after = get_terminal_status(user_id, project_id);
    assert status_after["running"] == False, "Terminal should be stopped";
}

test "test_terminal_input_output" {
    user_id = "test_user_io_" + str(int(time.time() * 1000));
    project_id = "test_proj_io";
    cwd = tempfile.gettempdir();

    start_terminal(user_id, project_id, cwd);
    # Wait for shell to initialize
    time.sleep(0.5);

    # Drain any initial output (shell prompt, motd, etc.)
    drain_terminal_output(user_id, project_id);

    # Send a simple echo command
    send_terminal_input(user_id, project_id, "echo HELLO_TERM_TEST\n");
    time.sleep(0.3);

    chunks = drain_terminal_output(user_id, project_id);
    combined = "";
    import base64;
    for chunk in chunks {
        combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
    }
    assert "HELLO_TERM_TEST" in combined, "Should see echo output in terminal, got: " + combined[:200];

    stop_terminal(user_id, project_id);
}

test "test_resize_terminal" {
    user_id = "test_user_resize_" + str(int(time.time() * 1000));
    project_id = "test_proj_resize";
    cwd = tempfile.gettempdir();

    start_terminal(user_id, project_id, cwd);
    time.sleep(0.2);

    result = resize_terminal(user_id, project_id, 120, 40);
    assert result["success"] == True, "resize should succeed";

    stop_terminal(user_id, project_id);
}

test "test_terminal_cwd" {
    user_id = "test_user_cwd_" + str(int(time.time() * 1000));
    project_id = "test_proj_cwd";
    cwd = tempfile.gettempdir();

    start_terminal(user_id, project_id, cwd);
    time.sleep(0.5);
    drain_terminal_output(user_id, project_id);

    send_terminal_input(user_id, project_id, "pwd\n");
    time.sleep(0.3);

    chunks = drain_terminal_output(user_id, project_id);
    combined = "";
    import base64;
    for chunk in chunks {
        combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
    }
    real_cwd = os.path.realpath(cwd);
    assert real_cwd in combined, "pwd should show " + real_cwd + ", got: " + combined[:200];

    stop_terminal(user_id, project_id);
}

test "test_terminal_idempotency" {
    user_id = "test_user_idemp_" + str(int(time.time() * 1000));
    project_id = "test_proj_idemp";
    cwd = tempfile.gettempdir();

    result1 = start_terminal(user_id, project_id, cwd);
    assert result1["success"] == True;

    result2 = start_terminal(user_id, project_id, cwd);
    assert result2["success"] == True;
    assert result2["status"] == "already_running", "Second start should return already_running";

    stop_terminal(user_id, project_id);
}

test "test_terminal_cleanup" {
    user_id = "test_user_clean_" + str(int(time.time() * 1000));
    project_id = "test_proj_clean";
    cwd = tempfile.gettempdir();

    start_terminal(user_id, project_id, cwd);
    key = _term_key(user_id, project_id);
    assert key in _term_registry, "Registry should have entry";

    stop_terminal(user_id, project_id);
    assert key not in _term_registry, "Registry should be cleared after stop";
}

test "test_terminal_invalid_cwd" {
    user_id = "test_user_badcwd_" + str(int(time.time() * 1000));
    project_id = "test_proj_badcwd";

    result = start_terminal(user_id, project_id, "/nonexistent/path/xyz");
    assert result["success"] == False, "Should fail with invalid cwd";
}

test "test_stop_nonexistent_terminal" {
    result = stop_terminal("no_user", "no_proj");
    assert result["success"] == False, "Should fail for non-existent terminal";
}

test "test_input_nonexistent_terminal" {
    result = send_terminal_input("no_user", "no_proj", "test");
    assert result["success"] == False, "Should fail for non-existent terminal";
}
