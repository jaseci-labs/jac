"""Phase 1 tests: self-correcting tools and metadata persistence."""

import os;

import from jac_coder.tool.checked { write_code, edit_code }
import from jac_coder.permission { permission_engine }
import from jac_coder.nodes { Session }
import from jac_coder.walkers { _persist_response, _find_session }
import from datetime { datetime }


glob TMP_DIR = "/tmp/jaccoder_test_selfcorrect";


def setup() {
    permission_engine.init_defaults();
    os.environ["JACCODER_WEB_MODE"] = "1";
    os.makedirs(TMP_DIR, exist_ok=True);
}


def teardown() {
    import shutil;
    if os.path.exists(TMP_DIR) {
        shutil.rmtree(TMP_DIR);
    }
    if "JACCODER_WEB_MODE" in os.environ {
        del os.environ["JACCODER_WEB_MODE"];
    }
}


"""Test _enforce_check logic via inline replica (impl internals cannot be imported)."""
def test_enforce_check_logic() {
    def enforce_check(result: str, file_path: str) -> str {
        if "Error:" in result
        and (
            "Permission denied" in result
            or "File not found" in result
            or "old_string not found" in result
        ) {
            return result;
        }
        if not file_path.endswith(".jac") {
            return result;
        }
        if "VALIDATION ERRORS" in result {
            return result + "\n\n[ACTION REQUIRED: Fix the validation errors above before proceeding to the next file.]";
        }
        if "RUNTIME ERRORS" in result {
            return result + "\n\n[ACTION REQUIRED: Fix the runtime errors above before proceeding.]";
        }
        return result;
    }

    val_input = "Written 10 lines to /tmp/t.jac\n\nVALIDATION ERRORS:\nerror line 5";
    out = enforce_check(val_input, "/tmp/t.jac");
    assert "ACTION REQUIRED" in out;
    assert "VALIDATION ERRORS" in out;
    print("enforce_check VALIDATION ERRORS: OK");

    rt_input = "Written 5 lines to /tmp/t.cl.jac\n\nRUNTIME ERRORS:\nTypeError";
    out = enforce_check(rt_input, "/tmp/t.cl.jac");
    assert "ACTION REQUIRED" in out;
    assert "RUNTIME ERRORS" in out;
    print("enforce_check RUNTIME ERRORS: OK");

    perm_input = "Error: Permission denied: write_file on /etc/passwd";
    out = enforce_check(perm_input, "/tmp/t.jac");
    assert out == perm_input;
    assert "ACTION REQUIRED" not in out;
    print("enforce_check permission denied: OK");

    py_input = "Written 20 lines to /tmp/t.py";
    out = enforce_check(py_input, "/tmp/t.py");
    assert out == py_input;
    print("enforce_check non-jac: OK");

    clean_input = "Written 10 lines to /tmp/t.jac";
    out = enforce_check(clean_input, "/tmp/t.jac");
    assert out == clean_input;
    assert "ACTION REQUIRED" not in out;
    print("enforce_check clean passthrough: OK");
}


with entry {
    setup();

    # write_code tests
    valid_jac = 'import os;\n\nwith entry {\n    print("hello");\n}\n';
    jac_path = TMP_DIR + "/valid_test.jac";
    out = write_code(jac_path, valid_jac);
    assert "Written" in out , "Should report file written";
    assert os.path.exists(jac_path) , "File should exist on disk";
    print("write_code valid .jac: OK");

    broken_jac = 'def broken( {\n    x = ;\n}\n';
    broken_path = TMP_DIR + "/broken_test.jac";
    out = write_code(broken_path, broken_jac);
    assert "Written" in out , "File should still be written even if broken";
    assert os.path.exists(broken_path) , "Broken file should exist on disk";
    print("write_code broken .jac (graceful): OK");

    # edit_code tests
    edit_path = TMP_DIR + "/edit_test.jac";
    write_code(edit_path, 'glob x = 1;\nglob y = 2;\n');
    out = edit_code(edit_path, "glob x = 1", "glob x = 42");
    assert "Replaced" in out , "Should report replacement";
    with open(edit_path, "r") as f {
        file_content = f.read();
    }
    assert "glob x = 42" in file_content , "Edit should be applied on disk";
    print("edit_code valid .jac: OK");

    out = edit_code(edit_path, "this does not exist", "replacement");
    assert "Error" in out , "Should report error for non-matching old_string";
    assert "ACTION REQUIRED" not in out;
    print("edit_code bad old_string: OK");

    # Non-jac file tests
    py_path = TMP_DIR + "/test.py";
    out = write_code(py_path, "print('hello')\n");
    assert "Written" in out;
    assert "VALIDATION" not in out;
    assert "ACTION REQUIRED" not in out;
    print("write_code .py (no validation): OK");

    json_path = TMP_DIR + "/config.json";
    out = write_code(json_path, '{"key": "value"}\n');
    assert "Written" in out;
    assert "VALIDATION" not in out;
    assert "ACTION REQUIRED" not in out;
    print("write_code .json (no validation): OK");

    # _enforce_check logic tests
    test_enforce_check_logic();

    # Metadata persistence tests
    test_session = Session(
        id="test-meta-001",
        chat_history=[],
        created_at=datetime.now().isoformat(),
        updated_at=datetime.now().isoformat()
    );
    root() ++> test_session;

    _persist_response(
        "test-meta-001",
        "I wrote the file",
        "server",
        ["write_file", "jac_check"],
        ["auth.jac"]
    );

    session = _find_session("test-meta-001");
    assert session is not None , "Session should exist";
    last_msg = session.chat_history[-1];
    assert last_msg["role"] == "assistant";
    assert last_msg["content"] == "I wrote the file";
    assert last_msg["agent"] == "server";
    assert last_msg["tools_used"] == ["write_file", "jac_check"];
    assert last_msg["files_modified"] == ["auth.jac"];
    print("persist_response with metadata: OK");

    _persist_response("test-meta-001", "Just a message", "explore");
    last_msg = session.chat_history[-1];
    assert last_msg["role"] == "assistant";
    assert last_msg["content"] == "Just a message";
    assert "tools_used" not in last_msg;
    assert "files_modified" not in last_msg;
    print("persist_response without metadata: OK");

    teardown();
    print("\n=== All self-correction tests passed! ===");
}
