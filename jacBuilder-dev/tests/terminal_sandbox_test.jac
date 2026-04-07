"""Tests for terminal sandbox guard — users cannot navigate outside project dir."""

import os;
import time;
import tempfile;
import shutil;
import base64;

import from services.terminal_manager {
    start_terminal,
    stop_terminal,
    send_terminal_input,
    drain_terminal_output
}


test "test_terminal_cd_parent_blocked" {
    user_id = "test_guard_" + str(int(time.time() * 1000));
    project_id = "proj_guard_cd";
    cwd = tempfile.mkdtemp();

    try {
        start_terminal(user_id, project_id, cwd);
        time.sleep(0.5);
        drain_terminal_output(user_id, project_id);

        # Try to cd ..
        send_terminal_input(user_id, project_id, "cd ..\n");
        time.sleep(0.5);

        chunks = drain_terminal_output(user_id, project_id);
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "restricted" in combined.lower() or "cannot navigate" in combined.lower(), "cd .. should be blocked, got: " + combined[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_terminal_cd_subdir_allowed" {
    user_id = "test_guard_" + str(int(time.time() * 1000));
    project_id = "proj_guard_sub";
    cwd = tempfile.mkdtemp();

    try {
        subdir = os.path.join(cwd, "mysubdir");
        os.makedirs(subdir);

        start_terminal(user_id, project_id, cwd);
        time.sleep(0.5);
        drain_terminal_output(user_id, project_id);

        send_terminal_input(user_id, project_id, "cd mysubdir && pwd\n");
        time.sleep(0.5);

        chunks = drain_terminal_output(user_id, project_id);
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "mysubdir" in combined, "cd to subdir should work, got: " + combined[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_terminal_cd_absolute_outside_blocked" {
    user_id = "test_guard_" + str(int(time.time() * 1000));
    project_id = "proj_guard_abs";
    cwd = tempfile.mkdtemp();

    try {
        start_terminal(user_id, project_id, cwd);
        time.sleep(0.5);
        drain_terminal_output(user_id, project_id);

        send_terminal_input(user_id, project_id, "cd /tmp\n");
        time.sleep(0.5);

        chunks = drain_terminal_output(user_id, project_id);
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        assert "restricted" in combined.lower() or "cannot navigate" in combined.lower(), "cd /tmp should be blocked, got: " + combined[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}

test "test_terminal_bare_cd_goes_to_project_root" {
    user_id = "test_guard_" + str(int(time.time() * 1000));
    project_id = "proj_guard_bare";
    cwd = tempfile.mkdtemp();

    try {
        subdir = os.path.join(cwd, "deep");
        os.makedirs(subdir);

        start_terminal(user_id, project_id, cwd);
        time.sleep(0.5);
        drain_terminal_output(user_id, project_id);

        # Go to subdir, then bare cd
        send_terminal_input(user_id, project_id, "cd deep && cd && pwd\n");
        time.sleep(0.5);

        chunks = drain_terminal_output(user_id, project_id);
        combined = "";
        for chunk in chunks {
            combined += base64.b64decode(chunk).decode("utf-8", errors="replace");
        }
        real_cwd = os.path.realpath(cwd);
        assert real_cwd in combined, "bare cd should go to project root, got: " + combined[:300];

        stop_terminal(user_id, project_id);
    } finally {
        shutil.rmtree(cwd, ignore_errors=True);
    }
}
