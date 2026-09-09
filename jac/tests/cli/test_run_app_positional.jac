"""`jac run [target]`: the positional is an app name when it matches [apps],
else a file path. Bare `jac run` uses [project] default-app, then the sole
app, and errors listing the apps when the workspace is ambiguous; `--show`
with no target prints one plan row per app."""

import io;
import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { execution }
import from jaclang.cli.commands.execution { _is_file_target }
import from jaclang.cli.manifest_route { _workspace_app_names }
import from jaclang.project.config { set_config }

glob _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

def _mk_workspace(with_default: bool) -> str {
    d = tempfile.mkdtemp(prefix="jacws_");
    _tmp_dirs.append(d);
    header = "[project]\nname = \"acme\"\n";
    if with_default {
        header += "default-app = \"web\"\n";
    }
    toml = (
        header
        + "\n[apps.web]\nkind = \"cli\"\npath = \"web\"\n"
        + "\n[apps.tool]\nkind = \"cli\"\nentry-point = \"tools/tool.jac\"\n"
    );
    Path(d, "jac.toml").write_text(toml, encoding="utf-8");
    os.makedirs(os.path.join(d, "web"));
    os.makedirs(os.path.join(d, "tools"));
    Path(d, "web", "main.jac").write_text(
        "with entry { print(\"RAN_WEB\"); }\n", encoding="utf-8"
    );
    Path(d, "tools", "tool.jac").write_text(
        "with entry { print(\"RAN_TOOL\"); }\n", encoding="utf-8"
    );
    return d;
}

def _run_in(d: str, target: str, show: bool) -> tuple[int, str] {
    old = os.getcwd();
    os.chdir(d);
    set_config(None);
    captured = io.StringIO();
    sys.stdout = captured;
    sys.stderr = captured;
    try {
        rc = execution.run(target=target, show=show);
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
        os.chdir(old);
        set_config(None);
    }
    return (rc, captured.getvalue());
}

def _cleanup {
    os.chdir(_orig_cwd);
    set_config(None);
    for d in _tmp_dirs {
        shutil.rmtree(d, ignore_errors=True);
    }
    _tmp_dirs.clear();
}

test "file-shaped tokens are never app names" {
    assert not _is_file_target("web");
    assert not _is_file_target("");
    assert _is_file_target("web/main.jac");
    assert _is_file_target("main.jac");
    assert _is_file_target("app.jab");
    assert _is_file_target("script.py");
    assert _is_file_target("pkg\\main.jac");
}

test "jac run <app> resolves the [apps] entry" {
    d = _mk_workspace(True);
    (rc, out) = _run_in(d, "web", True);
    assert rc == 0 , out;
    assert "app          : web" in out , out;
    assert "kind         : cli" in out , out;
    assert os.path.join("web", "main.jac") in out , out;
    assert "RAN_WEB" not in out;
    _cleanup();
}

test "jac run <file> resolves the owning app" {
    d = _mk_workspace(True);
    (rc, out) = _run_in(d, os.path.join("tools", "tool.jac"), True);
    assert rc == 0 , out;
    assert "app          : tool" in out , out;
    assert "tool.jac" in out , out;
    _cleanup();
}

test "bare jac run uses default-app" {
    d = _mk_workspace(True);
    (rc, out) = _run_in(d, "", False);
    assert rc == 0 , out;
    assert "RAN_WEB" in out , out;
    assert "RAN_TOOL" not in out;
    _cleanup();
}

test "bare jac run --show prints one plan row per app" {
    d = _mk_workspace(True);
    (rc, out) = _run_in(d, "", True);
    assert rc == 0 , out;
    for column in ["app", "kind", "entry", "action", "ui", "route"] {
        assert column in out , f"missing column {column!r} in:\n{out}";
    }
    assert "web" in out and "tool" in out , out;
    assert "default-app  : web" in out , out;
    assert "RAN_WEB" not in out and "RAN_TOOL" not in out;
    _cleanup();
}

test "ambiguous workspace without default-app errors listing apps" {
    d = _mk_workspace(False);
    (rc, out) = _run_in(d, "", False);
    assert rc == 2 , out;
    assert "web" in out and "tool" in out , out;
    assert "RAN_WEB" not in out and "RAN_TOOL" not in out;
    _cleanup();
}

test "ambiguous workspace still shows the plan table" {
    d = _mk_workspace(False);
    (rc, out) = _run_in(d, "", True);
    assert rc == 0 , out;
    assert "web" in out and "tool" in out , out;
    assert "default-app" not in out , out;
    _cleanup();
}

test "unknown target that is neither app nor file errors" {
    d = _mk_workspace(True);
    (rc, out) = _run_in(d, "nope", False);
    assert rc == 2 , out;
    assert "No app named 'nope'" in out , out;
    _cleanup();
}

test "bare jac <app> routes to jac run" {
    d = _mk_workspace(True);
    old = os.getcwd();
    os.chdir(d);
    try {
        names = _workspace_app_names();
    } finally {
        os.chdir(old);
    }
    assert names == {"web", "tool"} , str(names);
    _cleanup();
}

test "outside any project bare jac <token> is not an app" {
    d = tempfile.mkdtemp(prefix="jacnows_");
    _tmp_dirs.append(d);
    old = os.getcwd();
    os.chdir(d);
    try {
        names = _workspace_app_names();
    } finally {
        os.chdir(old);
    }
    assert names == set() or "web" not in names , str(names);
    _cleanup();
}
