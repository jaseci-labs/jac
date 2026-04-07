"""Tests for project_manager helper functions: _safe_segment, env I/O, get_project_status."""

import os;
import shutil;
import tempfile;
import from services.project_manager { _safe_segment, read_project_env, write_project_env, get_project_status }

test "safe_segment converts spaces to underscores" {
    assert _safe_segment("hello world") == "hello_world";
}

test "safe_segment replaces special characters with underscores" {
    assert _safe_segment("test@user#1") == "test_user_1";
}

test "safe_segment strips leading and trailing underscores" {
    assert _safe_segment("  test  ") == "test";
}

test "safe_segment returns fallback for empty string" {
    assert _safe_segment("") == "item";
}

test "safe_segment returns fallback for all-punctuation string" {
    assert _safe_segment("@@@") == "item";
}

test "safe_segment returns fallback for all-underscore result" {
    assert _safe_segment("___") == "item";
}

test "safe_segment preserves alphanumeric and hyphens" {
    assert _safe_segment("my-project_123") == "my-project_123";
}

test "safe_segment accepts custom fallback" {
    assert _safe_segment("", "default") == "default";
}

test "read_project_env returns empty list for nonexistent file" {
    result = read_project_env("/nonexistent/path/xyz/.env");
    assert result == [];
}

test "read_project_env parses key=value pairs" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        with open(env_path, "w") as f {
            f.write("FOO=bar\n");
            f.write("BAZ=qux\n");
        }
        result = read_project_env(env_path);
        assert len(result) == 2;
        assert result[0]["key"] == "FOO";
        assert result[0]["value"] == "bar";
        assert result[1]["key"] == "BAZ";
        assert result[1]["value"] == "qux";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "read_project_env skips blank lines and comments" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        with open(env_path, "w") as f {
            f.write("KEY=value\n");
            f.write("# This is a comment\n");
            f.write("\n");
            f.write("OTHER=123\n");
        }
        result = read_project_env(env_path);
        assert len(result) == 2;
        keys = [e["key"] for e in result];
        assert "KEY" in keys;
        assert "OTHER" in keys;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "read_project_env handles value containing equals sign" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        with open(env_path, "w") as f {
            f.write("URL=http://example.com?foo=bar\n");
        }
        result = read_project_env(env_path);
        assert len(result) == 1;
        assert result[0]["key"] == "URL";
        assert result[0]["value"] == "http://example.com?foo=bar";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "write_project_env creates env file with correct content" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        env_list = [
            {"key": "API_KEY", "value": "secret123"},
            {"key": "DEBUG", "value": "true"}
        ];
        result = write_project_env(env_path, env_list);
        assert result["success"] == True;
        with open(env_path, "r") as f {
            content = f.read();
        }
        assert "API_KEY=secret123" in content;
        assert "DEBUG=true" in content;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "write_project_env skips entries with empty keys" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        env_list = [
            {"key": "VALID", "value": "yes"},
            {"key": "", "value": "ignored"}
        ];
        write_project_env(env_path, env_list);
        result = read_project_env(env_path);
        assert len(result) == 1;
        assert result[0]["key"] == "VALID";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "write and read env round-trip preserves all values" {
    tmp_dir = tempfile.mkdtemp();
    try {
        env_path = os.path.join(tmp_dir, ".env");
        env_list = [
            {"key": "FOO", "value": "bar"},
            {"key": "NUM", "value": "42"},
            {"key": "MULTI", "value": "a=b=c"}
        ];
        write_project_env(env_path, env_list);
        result = read_project_env(env_path);
        assert len(result) == 3;
        mapping: dict = {};
        for entry in result {
            mapping[entry["key"]] = entry["value"];
        }
        assert mapping["FOO"] == "bar";
        assert mapping["NUM"] == "42";
        assert mapping["MULTI"] == "a=b=c";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "write_project_env returns error for unwritable path" {
    result = write_project_env("/root/no_permission/test/.env", [{"key": "X", "value": "1"}]);
    assert result["success"] == False;
}

test "get_project_status returns error for nonexistent path" {
    result = get_project_status("/nonexistent/path/xyz");
    assert result["success"] == False;
    assert "error" in result;
}

test "get_project_status returns error for empty path" {
    result = get_project_status("");
    assert result["success"] == False;
}
