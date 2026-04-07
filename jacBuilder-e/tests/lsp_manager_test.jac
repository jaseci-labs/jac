"""Tests for LSP manager: start, send, receive, drain, stop."""

import os;
import time;
import shutil;
import tempfile;
import from services.lsp_manager {
    start_lsp,
    stop_lsp,
    send_lsp_message,
    wait_lsp_response,
    drain_lsp_notifications,
    get_lsp_status,
    _lsp_key,
    _lsp_registry,
    _read_content_length_message,
    _write_content_length_message
}
import from threading {Lock}
import from io {BytesIO}

test "lsp_key builds correct registry key" {
    key = _lsp_key("user1", "proj1");
    assert key == "user1::proj1";
}

test "get_lsp_status returns none for unknown project" {
    result = get_lsp_status("nonexistent_user_lsp", "nonexistent_proj_lsp");
    assert result["running"] == False;
    assert result["status"] == "none";
}

test "start_lsp fails for invalid workspace" {
    result = start_lsp("test_user_lsp", "test_proj_lsp", "/nonexistent/path/xyz_lsp");
    assert result["success"] == False;
    assert "Invalid" in result["error"];
}

test "stop_lsp returns error when not running" {
    result = stop_lsp("test_user_lsp_stop", "test_proj_lsp_stop");
    assert result["success"] == False;
    assert "not running" in result["error"];
}

test "send_lsp_message returns error when not running" {
    result = send_lsp_message("test_user_lsp_send", "test_proj_lsp_send", {"jsonrpc": "2.0", "id": 1, "method": "initialize"});
    assert result["success"] == False;
}

test "drain_lsp_notifications returns empty for unknown project" {
    result = drain_lsp_notifications("test_user_lsp_drain", "test_proj_lsp_drain");
    assert result == [];
}

test "wait_lsp_response returns None for unknown project" {
    result = wait_lsp_response("test_user_lsp_wait", "test_proj_lsp_wait", 1, 0.1);
    assert result is None;
}

test "content-length framing round trip" {
    import from io {BytesIO}
    lock = Lock();
    msg = {"jsonrpc": "2.0", "id": 1, "method": "test"};
    buf = BytesIO();
    buf.mode = "wb";
    _write_content_length_message(buf, lock, msg);
    buf.seek(0);
    buf.mode = "rb";
    parsed = _read_content_length_message(buf);
    assert parsed is not None;
    assert parsed["id"] == 1;
    assert parsed["method"] == "test";
}

test "start_lsp spawns subprocess and stop_lsp cleans up" {
    tmp_dir = tempfile.mkdtemp(prefix="lsp_test_");
    uid = "lsp_test_user_start";
    pid = "lsp_test_proj_start";
    try {
        result = start_lsp(uid, pid, tmp_dir);
        assert result["success"] == True;
        status = get_lsp_status(uid, pid);
        assert status["running"] == True;
        stop_result = stop_lsp(uid, pid);
        assert stop_result["success"] == True;
        status_after = get_lsp_status(uid, pid);
        assert status_after["running"] == False;
    } finally {
        try { stop_lsp(uid, pid); } except Exception { }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "start_lsp returns already_running for duplicate start" {
    tmp_dir = tempfile.mkdtemp(prefix="lsp_test_dup_");
    uid = "lsp_test_user_dup";
    pid = "lsp_test_proj_dup";
    try {
        result1 = start_lsp(uid, pid, tmp_dir);
        assert result1["success"] == True;
        result2 = start_lsp(uid, pid, tmp_dir);
        assert result2["success"] == True;
        assert result2["status"] == "already_running";
    } finally {
        try { stop_lsp(uid, pid); } except Exception { }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "send and wait lsp initialize request" {
    tmp_dir = tempfile.mkdtemp(prefix="lsp_test_init_");
    uid = "lsp_test_user_init";
    pid = "lsp_test_proj_init";
    try {
        start_result = start_lsp(uid, pid, tmp_dir);
        assert start_result["success"] == True;
        time.sleep(0.5);
        init_msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": "file://" + tmp_dir,
                "capabilities": {}
            }
        };
        send_result = send_lsp_message(uid, pid, init_msg);
        assert send_result["success"] == True;
        response = wait_lsp_response(uid, pid, 1, 10.0);
        assert response is not None;
        assert response.get("id") == 1;
        assert "result" in response;
    } finally {
        try { stop_lsp(uid, pid); } except Exception { }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "drain notifications after didOpen with errors" {
    tmp_dir = tempfile.mkdtemp(prefix="lsp_test_diag_");
    uid = "lsp_test_user_diag";
    pid = "lsp_test_proj_diag";
    try {
        bad_file = os.path.join(tmp_dir, "bad.jac");
        with open(bad_file, "w") as f {
            f.write("this is not valid jac syntax {{{}}}\n");
        }
        start_result = start_lsp(uid, pid, tmp_dir);
        assert start_result["success"] == True;
        time.sleep(0.5);
        init_msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": "file://" + tmp_dir,
                "capabilities": {}
            }
        };
        send_lsp_message(uid, pid, init_msg);
        wait_lsp_response(uid, pid, 1, 10.0);
        initialized_msg = {"jsonrpc": "2.0", "method": "initialized", "params": {}};
        send_lsp_message(uid, pid, initialized_msg);
        file_uri = "file://" + bad_file;
        with open(bad_file, "r") as f {
            file_content = f.read();
        }
        open_msg = {
            "jsonrpc": "2.0",
            "method": "textDocument/didOpen",
            "params": {
                "textDocument": {
                    "uri": file_uri,
                    "languageId": "jac",
                    "version": 1,
                    "text": file_content
                }
            }
        };
        send_lsp_message(uid, pid, open_msg);
        time.sleep(3);
        notifications = drain_lsp_notifications(uid, pid);
        assert isinstance(notifications, list);
    } finally {
        try { stop_lsp(uid, pid); } except Exception { }
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}
