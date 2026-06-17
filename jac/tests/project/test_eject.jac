"""Tests for `jac eject` (FastAPI `ejected/{backend,frontend}` output, walkers
on the jaclang runtime). Runs eject in-process against tiny projects in
TemporaryDirectory(), completing under a second as part of `pytest jac`."""

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
        'walker:pub Greet {\n' + '    has name: str,\n' + '        reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report f"Hello, {self.name}!";\n' + '    }\n' + '}\n\n' + 'walker Secret {\n' + '    has reports: list[str] = [];\n' + '    can g with Root entry {\n' + '        report "secret";\n' + '    }\n' + '}\n'
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


"""True if any line imports the jaclang runtime."""
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


test "backend runs walkers on the jaclang runtime via ExecutionManager" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        # Walkers run on the real runtime; responses use the {"data": ...} envelope.
        assert "from jaclang.runtimelib.server import UserManager, ExecutionManager" in main_py;
        assert "_em.spawn_walker(_W_Greet" in main_py;
        assert '"data"' in main_py;
        # The compiled module keeps its real jaclang runtime imports.
        assert _has_jaclang_import(_backend(src, "server.py").read_text());
    }
}


test "backend exposes login/register and gates secured walkers by :pub" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert '@app.post("/user/register")' in main_py;
        assert '@app.post("/user/login")' in main_py;
        # :pub walker is an open endpoint (not auth-required); the bare walker is.
        assert "_username(authorization, False)" in main_py;
        assert "_username(authorization, True)" in main_py;
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


test "requirements.txt pins jaclang and adds fastapi + uvicorn" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "jaclang" in reqs;
        assert "fastapi" in reqs;
        assert "uvicorn" in reqs;
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


# ==================== backend-only projects (no client app) ====================
"""Materialize a walker-only project: no `cl {}` block / `.cl.jac`, so no
client `app` component exists."""
def _write_backend_only_project(src: Path, name: str = "be_app") {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nentry-point = "main.jac"\n'
    );
    (src / "main.jac").write_text(
        'walker:pub Ping {\n' + '    has reports: list[str] = [];\n' + '    can run with `root entry {\n' + '        report "pong";\n' + '    }\n' + '}\n'
    );
}


test "walker-only project ejects a backend-only app with no frontend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "beapp";
        _write_backend_only_project(src, "beapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        # Backend is complete...
        assert _backend(src, "main.py").exists();
        assert '@app.post("/walker/Ping")' in _backend(src, "main.py").read_text();
        # ...and no half-built frontend scaffold is left behind.
        assert not (src / "ejected" / "frontend").exists();
    }
}


# ==================== inherited walker fields ====================
"""Field names of a Pydantic model class in the emitted main.py."""
def _model_fields(main_py: str, model: str) -> set {
    tree = ast.parse(main_py);
    names: set = set();
    for node in tree.body {
        if isinstance(node, ast.ClassDef) and (node.name == model) {
            for stmt in node.body {
                if isinstance(stmt, ast.AnnAssign)
                and isinstance(stmt.target, ast.Name) {
                    names.add(stmt.target.id);
                }
            }
        }
    }
    return names;
}


test "request model includes fields inherited from a base walker" {
    with TemporaryDirectory() as td {
        src = Path(td) / "inh";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "inh"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text(
            'walker:pub Base {\n' + '    has a: int,\n' + '        b: str = "def";\n' + '    has reports: list[int] = [];\n' + '}\n\n' + 'walker:pub Compute(Base) {\n' + '    has c: int;\n' + '    can run with `root entry {\n' + '        report self.a + self.c;\n' + '    }\n' + '}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        fields = _model_fields(main_py, "ComputeIn");
        # `a` and `b` come from Base; `c` is Compute's own field.
        assert "a" in fields , f"inherited field a missing from ComputeIn: {fields}";
        assert "b" in fields , f"inherited field b missing from ComputeIn: {fields}";
        assert "c" in fields , f"own field c missing from ComputeIn: {fields}";
    }
}


# ==================== [eject.db] SQLAlchemy persistence ====================
test "[eject.db] sqlalchemy emits the backend, hook, and SQLAlchemy dep" {
    with TemporaryDirectory() as td {
        src = Path(td) / "dbapp";
        _write_project(src, "dbapp");
        # Opt into the SQLAlchemy persistence backend.
        toml = (src / "jac.toml").read_text();
        (src / "jac.toml").write_text(toml + '\n[eject.db]\ndriver = "sqlalchemy"\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert _backend(src, "_jac_sqldb.py").exists();
        main_py = _backend(src, "main.py").read_text();
        assert "from _jac_sqldb import SqlAlchemyMemory" in main_py;
        assert "def get_persistent_memory" in main_py;
        assert "JAC_DB_URL" in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "SQLAlchemy" in reqs;
    }
}


test "default eject does not emit the SQLAlchemy backend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "plainapp";
        _write_project(src, "plainapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert not _backend(src, "_jac_sqldb.py").exists();
        main_py = _backend(src, "main.py").read_text();
        assert "get_persistent_memory" not in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "SQLAlchemy" not in reqs;
    }
}
