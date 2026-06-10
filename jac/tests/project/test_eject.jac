"""Tests for `jac eject` (standalone zero-jaclang `ejected/{backend,frontend}`
output). Runs eject in-process against tiny projects in TemporaryDirectory(),
completing in under a second on a warm cache as part of `pytest jac`."""

import ast;
import io;
import json;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.cli.commands { eject }


"""Run jac eject silencing console output. Returns the exit code."""
def _silent_eject(source: str, output: str = "", force: bool = False) -> int {
    buf = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = buf;
    sys.stderr = buf;
    try {
        rc = eject.eject(source=source, output=output, force=force);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
    }
    return rc;
}


"""Materialize a tiny fullstack Jac project (server walker + client UI)."""
def _write_project(src: Path, name: str = "test_app") {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nversion = "0.1.0"\nentry-point = "main.jac"\n' + '[dependencies.npm]\nreact = "^18.2.0"\nreact-dom = "^18.2.0"\n'
    );
    (src / "main.jac").write_text(
        'import from server { Greet }\n\n' + 'cl {\n' + '    import from .frontend { app as ClientApp }\n' + '    def:pub app -> JsxElement {\n' + '        return <ClientApp/>;\n' + '    }\n' + '}\n'
    );
    (src / "server.sv.jac").write_text(
        'walker:pub Greet {\n' + '    has name: str,\n' + '        reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report f"Hello, {self.name}!";\n' + '    }\n' + '}\n'
    );
    (src / "frontend.cl.jac").write_text(
        '"""Client UI."""\n' + 'sv import from server { Greet }\n\n' + 'def:pub app -> JsxElement {\n' + '    has msg: str = "hi";\n' + '    return <div>{msg}</div>;\n' + '}\n'
    );
}


"""Path to a backend file inside the default ejected/ output."""
def _backend(src: Path, rel: str) -> Path {
    return src / "ejected" / "backend" / rel;
}


"""Path to a frontend file inside the default ejected/ output."""
def _frontend(src: Path, rel: str) -> Path {
    return src / "ejected" / "frontend" / rel;
}


"""True if any line imports the jaclang runtime (the standalone smell test)."""
def _has_jaclang_import(py_text: str) -> bool {
    for line in py_text.splitlines() {
        stripped = line.strip();
        if stripped.startswith("import jaclang")
        or stripped.startswith("from jaclang") {
            return True;
        }
    }
    return False;
}


# ==================== output layout ====================
test "eject emits a project-internal ejected/{backend,frontend} layout" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src / "ejected";
        assert (out / "backend" / "main.py").exists();
        assert (out / "backend" / "_osp.py").exists();
        assert (out / "backend" / "requirements.txt").exists();
        assert (out / "frontend" / "package.json").exists();
        assert (out / "frontend" / "index.html").exists();
        assert (out / "frontend" / "vite.config.js").exists();
        assert (out / ".jac-ejected").exists();
        # No sibling -ejected directory (old default behavior is gone).
        assert not (src.parent / "myapp-ejected").exists();
    }
}


test "ejected output contains zero .jac files" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        leftover = [
            str(p.relative_to(src / "ejected"))
            for p in (src / "ejected").rglob("*.jac")
            if p.is_file()
        ];
        assert leftover == [] , f"Ejected output still has .jac files: {leftover}";
    }
}


# ==================== backend ====================
test "backend exposes the server walker and not the client app" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert "from server import Greet" in main_py;
        assert '@app.post("/walker/Greet")' in main_py;
        assert "class GreetIn(BaseModel)" in main_py;
        # The .cl.jac `app` component must never become a backend endpoint.
        assert "/function/app" not in main_py;
        assert "from frontend import" not in main_py;
    }
}


test "backend implements the @jac/runtime client contract envelope" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        # Walker responses are wrapped as {"data": {...reports...}}.
        assert '"data"' in main_py;
        assert '"reports"' in main_py;
        assert "_walker_data" in main_py;
    }
}


test "backend has zero jaclang imports" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        for py in (src / "ejected" / "backend").rglob("*.py") {
            assert not _has_jaclang_import(py.read_text());
        }
        # The compiled walker module imports the vendored runtime instead.
        assert "from _osp import" in _backend(src, "server.py").read_text();
    }
}


test "every emitted backend .py file parses as valid Python" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        for py in (src / "ejected" / "backend").rglob("*.py") {
            try {
                ast.parse(py.read_text());
            } except SyntaxError as e {
                raise AssertionError(f"Emitted invalid Python in {py.name}: {e}");
            }
        }
    }
}


test "requirements.txt is fastapi + uvicorn only (no jaclang)" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "fastapi" in reqs;
        assert "uvicorn" in reqs;
        assert "jaclang" not in reqs;
    }
}


test "_osp.py defines the runtime contract symbols and no jaclang import" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        osp = _backend(src, "_osp.py").read_text();
        tree = ast.parse(osp);
        names = set();
        for node in tree.body {
            if isinstance(node, ast.ClassDef) {
                names.add(node.name);
            } elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) {
                names.add(node.name);
            }
        }
        for required in [
            "Root",
            "Walker",
            "on_entry",
            "set_trigger",
            "spawn",
            "root",
            "log_report",
            "field"
        ] {
            assert required in names , f"_osp.py missing {required}";
        }
        assert not _has_jaclang_import(osp);
    }
}


# ==================== frontend ====================
test "frontend compiles .cl.jac pages to JavaScript" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert _frontend(src, "src/frontend.js").exists();
        assert _frontend(src, "src/main.js").exists();
        assert _frontend(src, "src/__jac_entry.js").exists();
    }
}


test "frontend package.json is valid JSON carrying the project's npm deps" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        pkg = json.loads(_frontend(src, "package.json").read_text());
        assert pkg["name"] == "myapp";
        assert "react" in pkg["dependencies"];
        assert "vite" in pkg["devDependencies"];
    }
}


test "vite.config.js proxies API routes to the backend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        vite = _frontend(src, "vite.config.js").read_text();
        assert "/walker" in vite;
        assert "/function" in vite;
        assert "BACKEND_PORT" in vite;
    }
}


# ==================== re-run / overwrite semantics ====================
test "re-running eject regenerates without --force" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        assert _silent_eject(str(src)) == 0;
        # Second run over our own output dir must succeed (marker present).
        assert _silent_eject(str(src)) == 0;
    }
}


test "eject refuses to overwrite a non-eject directory without --force" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        # Pre-create the output dir with foreign content and no marker.
        out = src / "ejected";
        out.mkdir(parents=True, exist_ok=True);
        (out / "keep.txt").write_text("important");
        assert _silent_eject(str(src)) == 1;
        # --force overwrites it.
        assert _silent_eject(str(src), force=True) == 0;
    }
}


test "eject honors an explicit output directory" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        dest = Path(td) / "custom_out";
        rc = _silent_eject(str(src), output=str(dest));
        assert rc == 0;
        assert (dest / "backend" / "main.py").exists();
        assert not (src / "ejected").exists();
    }
}


# ==================== errors ====================
test "eject errors when jac.toml is missing" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "main.jac").write_text('with entry { print("hi"); }\n');
        rc = _silent_eject(str(src));
        assert rc == 1;
    }
}


test "eject errors when source does not exist" {
    with TemporaryDirectory() as td {
        missing = Path(td) / "nope";
        rc = _silent_eject(str(missing));
        assert rc == 1;
    }
}


# ==================== metadata helper ====================
test "load_eject_project_metadata resolves name and entry module" {
    import from jaclang.cli.commands.eject { load_eject_project_metadata }
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        meta = load_eject_project_metadata(src);
        assert meta["project_name"] == "myapp";
        assert meta["entry_point"] == "main.jac";
        assert meta["entry_module"] == "main";
    }
}


test "load_eject_project_metadata falls back to source dir name on placeholder" {
    import from jaclang.cli.commands.eject { load_eject_project_metadata }
    with TemporaryDirectory() as td {
        src = Path(td) / "fallback_app";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\nentry-point = "main.jac"\n'
        );
        meta = load_eject_project_metadata(src);
        assert meta["project_name"] == "fallback_app";
    }
}
