"""Tests for file_watcher — filesystem change detection."""

import os;
import time;
import tempfile;
import shutil;

import from services.file_watcher {
    start_watcher,
    stop_watcher,
    drain_file_events,
    get_watcher_status
}


test "test_start_stop_watcher" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_start";
    watch_dir = tempfile.mkdtemp();

    try {
        result = start_watcher(user_id, project_id, watch_dir);
        assert result["success"] == True, "start should succeed: " + str(result);

        status = get_watcher_status(user_id, project_id);
        assert status["running"] == True, "watcher should be running";

        stop_result = stop_watcher(user_id, project_id);
        assert stop_result["success"] == True, "stop should succeed";

        status_after = get_watcher_status(user_id, project_id);
        assert status_after["running"] == False, "watcher should be stopped";
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_detects_file_create" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_create";
    watch_dir = tempfile.mkdtemp();

    try {
        start_watcher(user_id, project_id, watch_dir);
        time.sleep(0.3);

        # Drain any initial events
        drain_file_events(user_id, project_id);

        # Create a file
        test_file = os.path.join(watch_dir, "newfile.txt");
        with open(test_file, "w") as f {
            f.write("hello");
        }

        # Wait for watcher to detect
        time.sleep(0.5);

        events = drain_file_events(user_id, project_id);
        types = [e.get("type", "") for e in events];
        assert "file_created" in types or "file_modified" in types, "Should detect file creation, got: " + str(types);

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_detects_file_delete" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_delete";
    watch_dir = tempfile.mkdtemp();

    try {
        # Create file first
        test_file = os.path.join(watch_dir, "toremove.txt");
        with open(test_file, "w") as f {
            f.write("bye");
        }

        start_watcher(user_id, project_id, watch_dir);
        time.sleep(0.3);
        drain_file_events(user_id, project_id);

        # Delete it
        os.remove(test_file);
        time.sleep(0.5);

        events = drain_file_events(user_id, project_id);
        types = [e.get("type", "") for e in events];
        assert "file_deleted" in types, "Should detect file deletion, got: " + str(types);

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_detects_file_modify" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_modify";
    watch_dir = tempfile.mkdtemp();

    try {
        test_file = os.path.join(watch_dir, "existing.txt");
        with open(test_file, "w") as f {
            f.write("original");
        }

        start_watcher(user_id, project_id, watch_dir);
        time.sleep(0.3);
        drain_file_events(user_id, project_id);

        # Modify
        with open(test_file, "w") as f {
            f.write("modified content");
        }
        time.sleep(0.5);

        events = drain_file_events(user_id, project_id);
        types = [e.get("type", "") for e in events];
        assert "file_modified" in types, "Should detect file modification, got: " + str(types);

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_ignores_node_modules" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_ignore";
    watch_dir = tempfile.mkdtemp();

    try {
        nm_dir = os.path.join(watch_dir, "node_modules");
        os.makedirs(nm_dir);

        start_watcher(user_id, project_id, watch_dir);
        time.sleep(0.3);
        drain_file_events(user_id, project_id);

        # Create file inside node_modules
        with open(os.path.join(nm_dir, "pkg.json"), "w") as f {
            f.write("{}");
        }
        time.sleep(0.5);

        events = drain_file_events(user_id, project_id);
        paths = [e.get("path", "") for e in events];
        for p in paths {
            assert "node_modules" not in p, "Should ignore node_modules, got event for: " + p;
        }

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_detects_dir_create" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_dir";
    watch_dir = tempfile.mkdtemp();

    try {
        start_watcher(user_id, project_id, watch_dir);
        time.sleep(0.3);
        drain_file_events(user_id, project_id);

        os.makedirs(os.path.join(watch_dir, "newsubdir"));
        time.sleep(0.5);

        events = drain_file_events(user_id, project_id);
        types = [e.get("type", "") for e in events];
        assert "dir_created" in types, "Should detect dir creation, got: " + str(types);

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_idempotent_start" {
    user_id = "test_fw_" + str(int(time.time() * 1000));
    project_id = "proj_fw_idemp";
    watch_dir = tempfile.mkdtemp();

    try {
        r1 = start_watcher(user_id, project_id, watch_dir);
        assert r1["success"] == True;

        r2 = start_watcher(user_id, project_id, watch_dir);
        assert r2["success"] == True;
        assert r2["status"] == "already_running";

        stop_watcher(user_id, project_id);
    } finally {
        shutil.rmtree(watch_dir, ignore_errors=True);
    }
}

test "test_watcher_invalid_dir" {
    result = start_watcher("u", "p", "/nonexistent/dir/xyz");
    assert result["success"] == False;
}

test "test_stop_nonexistent_watcher" {
    result = stop_watcher("nouser", "noproj");
    assert result["success"] == False;
}

test "test_drain_empty" {
    events = drain_file_events("nouser", "noproj");
    assert len(events) == 0;
}
