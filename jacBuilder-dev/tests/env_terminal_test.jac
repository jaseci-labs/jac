"""Tests for env variable integration with terminal — sourcing, isolation, re-source on save."""

import os;
import time;
import tempfile;
import shutil;
import base64;

import from services.terminal_manager {
    start_terminal,
    stop_terminal,
    send_terminal_input,
    drain_terminal_output,
    _term_key
}
import from services.project_manager {
    write_project_env,
    read_project_env
}


test "test_terminal_sources_project_env_on_start" {
    user_id = "test_env_src_" + str(int(time.time() * 1000));
    project_id = "proj_env_src";
    cwd = tempfile.mkdtemp();

    try {
        # Write .env before starting terminal
        env_path = os.path.join(cwd, ".env");
        write_project_env(env_path, [{"key": "MY_TEST_VAR", "value": "hello123"}]);

        start_terminal(user_id, project_id, cwd);
        time.sleep(1.0);
        drain_terminal_output(user_id, project_id);

        # Echo the var
        send_terminal_input(user_id, project_id, "echo $MY_TEST_VAR\n");
        time.sleep(0.5);

        chunks = drain_terminal_output(user_id, project_id);
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "hello123" in combined, "Terminal should see env var from .env, got: " + combined[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_terminal_env_isolated_between_projects" {
    user_id = "test_env_iso_" + str(int(time.time() * 1000));
    proj_a = "proj_iso_a";
    proj_b = "proj_iso_b";
    cwd_a = tempfile.mkdtemp();
    cwd_b = tempfile.mkdtemp();

    try {
        # Project A has SECRET_A
        env_a = os.path.join(cwd_a, ".env");
        write_project_env(env_a, [{"key": "SECRET_A", "value": "only_in_a"}]);

        # Project B has no env vars
        # (no .env file)

        # Start terminal A
        start_terminal(user_id, proj_a, cwd_a);
        time.sleep(0.8);
        drain_terminal_output(user_id, proj_a);

        # Verify A has the var
        send_terminal_input(user_id, proj_a, "echo $SECRET_A\n");
        time.sleep(0.3);
        chunks_a = drain_terminal_output(user_id, proj_a);
        combined_a = "";
        for chunk in chunks_a {
            combined_a += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "only_in_a" in combined_a, "Project A should see SECRET_A";

        # Start terminal B
        start_terminal(user_id, proj_b, cwd_b);
        time.sleep(0.8);
        drain_terminal_output(user_id, proj_b);

        # Verify B does NOT have the var
        send_terminal_input(user_id, proj_b, "echo \"SECRET_A=[$SECRET_A]\"\n");
        time.sleep(0.3);
        chunks_b = drain_terminal_output(user_id, proj_b);
        combined_b = "";
        for chunk in chunks_b {
            combined_b += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "only_in_a" not in combined_b, "Project B should NOT see SECRET_A, got: " + combined_b[:300];

        stop_terminal(user_id, proj_a);
        stop_terminal(user_id, proj_b);
    } finally {
        shutil.rmtree(cwd_a, ignore_errors=True);
        shutil.rmtree(cwd_b, ignore_errors=True);
    }
}

test "test_terminal_picks_up_env_after_re_source" {
    user_id = "test_env_resrc_" + str(int(time.time() * 1000));
    project_id = "proj_env_resrc";
    cwd = tempfile.mkdtemp();

    try {
        # Start terminal with NO .env
        start_terminal(user_id, project_id, cwd);
        time.sleep(0.8);
        drain_terminal_output(user_id, project_id);

        # Verify var is empty
        send_terminal_input(user_id, project_id, "echo \"LATE_VAR=[$LATE_VAR]\"\n");
        time.sleep(0.3);
        chunks1 = drain_terminal_output(user_id, project_id);
        combined1 = "";
        for chunk in chunks1 {
            combined1 += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "late_value" not in combined1, "LATE_VAR should be empty initially";

        # Now write .env AFTER terminal started
        env_path = os.path.join(cwd, ".env");
        write_project_env(env_path, [{"key": "LATE_VAR", "value": "late_value"}]);

        # Re-source .env (simulates what env_ops save does)
        send_terminal_input(user_id, project_id, "set -a; source .env 2>/dev/null; set +a\n");
        time.sleep(0.3);
        drain_terminal_output(user_id, project_id);

        # Now verify the var is available
        send_terminal_input(user_id, project_id, "echo $LATE_VAR\n");
        time.sleep(0.3);
        chunks2 = drain_terminal_output(user_id, project_id);
        combined2 = "";
        for chunk in chunks2 {
            combined2 += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "late_value" in combined2, "LATE_VAR should be available after re-source, got: " + combined2[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_env_file_read_write_roundtrip" {
    cwd = tempfile.mkdtemp();
    try {
        env_path = os.path.join(cwd, ".env");
        # Write
        write_project_env(env_path, [
            {"key": "KEY1", "value": "val1"},
            {"key": "KEY2", "value": "val2"},
            {"key": "KEY_SPECIAL", "value": "has=equals"}
        ]);
        # Read back
        items = read_project_env(env_path);
        keys = [i["key"] for i in items];
        assert "KEY1" in keys, "Should have KEY1";
        assert "KEY2" in keys, "Should have KEY2";
        assert "KEY_SPECIAL" in keys, "Should have KEY_SPECIAL";

        # Check values
        for item in items {
            if item["key"] == "KEY1" { assert item["value"] == "val1"; }
            if item["key"] == "KEY2" { assert item["value"] == "val2"; }
            if item["key"] == "KEY_SPECIAL" { assert item["value"] == "has=equals"; }
        }
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_global_env_path_per_user" {
    import from pathlib { Path }
    user_id = "test_user_" + str(int(time.time() * 1000));
    expected_path = os.path.join(str(Path.home()), ".jac-ide", "users", user_id, "global.env");

    # Verify the terminal uses the per-user path
    cwd = tempfile.mkdtemp();
    try {
        # Create the global env dir and file
        os.makedirs(os.path.dirname(expected_path), exist_ok=True);
        write_project_env(expected_path, [{"key": "GLOBAL_TEST", "value": "global_val"}]);

        start_terminal(user_id, "proj_global", cwd);
        time.sleep(0.8);
        drain_terminal_output(user_id, "proj_global");

        send_terminal_input(user_id, "proj_global", "echo $GLOBAL_TEST\n");
        time.sleep(0.3);

        chunks = drain_terminal_output(user_id, "proj_global");
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "global_val" in combined, "Terminal should see global env var, got: " + combined[:300];

        stop_terminal(user_id, "proj_global");
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
        # Clean up global env
        try { os.remove(expected_path); } except Exception { }
        try { os.removedirs(os.path.dirname(expected_path)); } except Exception { }
    }
}
