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


test "requirements.txt has no jaclang pin, only stock PyPI packages" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        reqs = _backend(src, "requirements.txt").read_text();
        # The runtime is vendored, so the deprecated jaclang (and byllm)
        # packages must never appear as pip requirements.
        for line in reqs.splitlines() {
            assert not line.strip().startswith("jaclang");
            assert not line.strip().startswith("byllm");
        }
        assert "fastapi" in reqs;
        assert "uvicorn" in reqs;
    }
}


# ==================== vendored runtime (self-contained output) ====================
test "backend vendors the jaclang runtime with no compiler or CLI inside" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        vend = src / "ejected" / "backend" / "jaclang";
        assert "Vendored jaclang runtime" in (vend / "__init__.py").read_text();
        # The pieces the generated main.py and compiled modules import.
        assert (vend / "jac0core" / "jaclib.py").exists();
        assert (vend / "jac0core" / "runtime.py").exists();
        assert (vend / "runtimelib" / "server.py").exists();
        assert (vend / "runtimelib" / "memory.py").exists();
        # Compiler / tooling subtrees must stay out of the vendored runtime.
        assert not (vend / "compiler").exists();
        assert not (vend / "meta_importer.py").exists();
        assert not (vend / "langserve").exists();
        assert not (vend / "jac0core" / "unitree.py").exists();
        assert not (vend / "runtimelib" / "client").exists();
    }
}


test "byLLM projects vendor jaclang.byllm and pin the llm capability deps" {
    with TemporaryDirectory() as td {
        src = Path(td) / "llmapp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "llmapp"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text(
            'import from jaclang.byllm.lib { Model }\n\n' + 'glob llm = Model(model_name="mockllm", config={"outputs": ["ok"]});\n\n' + 'def:pub summarize(text: str) -> str by llm();\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        vend = src / "ejected" / "backend" / "jaclang";
        assert (vend / "byllm" / "lib.py").exists();
        # byLLM is folded into core, so its closure (e.g. the MTIR the runtime
        # calls into) is vendored directly -- no separate plugin registration.
        assert (vend / "byllm" / "mtir.py").exists();
        reqs = _backend(src, "requirements.txt").read_text();
        assert "litellm" in reqs;
        for line in reqs.splitlines() {
            assert not line.strip().startswith("jaclang");
            assert not line.strip().startswith("byllm");
        }
    }
}


test "plain projects do not vendor byllm or pin llm deps" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_project(src, "myapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        vend = src / "ejected" / "backend" / "jaclang";
        assert not (vend / "byllm").exists();
        reqs = _backend(src, "requirements.txt").read_text();
        assert "litellm" not in reqs;
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
        # Proxy must target IPv4 explicitly: uvicorn is IPv4-only, and a
        # "localhost" target stalls on the dead ::1 address (ETIMEDOUT).
        assert "127.0.0.1" in vite;
        assert "http://localhost:" not in vite;
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
test "[eject.db] sqlalchemy vendors the backend, provider wiring, and SQLAlchemy dep" {
    with TemporaryDirectory() as td {
        src = Path(td) / "dbapp";
        _write_project(src, "dbapp");
        # Opt into the SQLAlchemy persistence backend.
        toml = (src / "jac.toml").read_text();
        (src / "jac.toml").write_text(toml + '\n[eject.db]\ndriver = "sqlalchemy"\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        # The backend is the real runtime module, vendored like the rest.
        assert _backend(
            src, "jaclang/runtimelib/storage/sqlalchemy_memory.py"
        ).exists();
        main_py = _backend(src, "main.py").read_text();
        assert (
            "from jaclang.runtimelib.storage.sqlalchemy_memory "
            "import SqlAlchemyMemory"
        ) in main_py;
        assert "set_persistent_memory_provider" in main_py;
        assert "JAC_DB_URL" in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        # pinned via the central data.sql capability (canonical lowercase spec)
        assert "sqlalchemy" in reqs.lower();
        assert "capability:data.sql" in reqs;
    }
}


test "default eject does not vendor the SQLAlchemy backend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "plainapp";
        _write_project(src, "plainapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert not _backend(
            src, "jaclang/runtimelib/storage/sqlalchemy_memory.py"
        ).exists();
        main_py = _backend(src, "main.py").read_text();
        assert "get_persistent_memory" not in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "sqlalchemy" not in reqs.lower();
    }
}


# ==================== project [dependencies] harvest ====================
test "requirements.txt carries the project's Python [dependencies]" {
    with TemporaryDirectory() as td {
        src = Path(td) / "depapp";
        _write_project(src, "depapp");
        toml = (src / "jac.toml").read_text();
        (src / "jac.toml").write_text(
            toml + '\n[dependencies]\npymupdf = ">=1.28"\nrequests = "*"\n' + 'pillow = "12.0"\nrapidocr = "latest"\n' + 'byllm = ">=0.6"\njaclang = ">=0.30"\nBYLLM = "*"\n' + 'fastapi = ">=0.100"\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        reqs = _backend(src, "requirements.txt").read_text();
        req_lines = [line.strip() for line in reqs.splitlines()];
        assert "pymupdf>=1.28" in req_lines;
        # "*" means any version: emitted as a bare package name.
        assert "requests" in req_lines;
        # A bare version (no operator) becomes an == pin, matching what
        # `jac` itself installs; "latest" degrades to a bare name.
        assert "pillow==12.0" in req_lines;
        assert "rapidocr" in req_lines;
        assert "pillow12.0" not in req_lines;
        # The generated app's own fastapi pin wins over the project's.
        assert "fastapi>=0.110" in req_lines;
        assert "fastapi>=0.100" not in req_lines;
        # Vendored packages must never become pip requirements, even when
        # the jac.toml key differs in case (BYLLM, Jaclang, ...).
        for line in req_lines {
            assert not line.lower().startswith("jaclang");
            assert not line.lower().startswith("byllm");
        }
    }
}


# ==================== .env handling ====================
test "eject copies .env files and wires dotenv loading" {
    with TemporaryDirectory() as td {
        src = Path(td) / "envapp";
        _write_project(src, "envapp");
        (src / ".env").write_text("MY_KEY=secret\n");
        (src / ".env.example").write_text("MY_KEY=\n");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src / "ejected";
        assert (out / ".env").read_text() == "MY_KEY=secret\n";
        assert (out / ".env.example").exists();
        main_py = _backend(src, "main.py").read_text();
        assert "load_dotenv" in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "python-dotenv" in reqs;
    }
}


test "projects without env files get no dotenv wiring" {
    with TemporaryDirectory() as td {
        src = Path(td) / "noenvapp";
        _write_project(src, "noenvapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert not (src / "ejected" / ".env").exists();
        main_py = _backend(src, "main.py").read_text();
        assert "load_dotenv" not in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "python-dotenv" not in reqs;
    }
}


# ==================== Makefile / README scaffold ====================
test "eject emits a Makefile and README at the output root" {
    with TemporaryDirectory() as td {
        src = Path(td) / "makeapp";
        _write_project(src, "makeapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src / "ejected";
        mk = (out / "Makefile").read_text();
        assert "install:" in mk;
        assert "dev-backend:" in mk;
        assert "dev-frontend:" in mk;
        assert "uvicorn main:app" in mk;
        assert "npm run dev" in mk;
        # Recipe lines must be tab-indented or make rejects the file.
        for line in mk.splitlines() {
            if line.startswith("    ") {
                raise AssertionError(f"space-indented Makefile recipe: {line!r}");
            }
        }
        readme = (out / "README.md").read_text();
        assert "make install" in readme;
        assert "make dev" in readme;
    }
}


test "backend-only Makefile has no frontend targets" {
    with TemporaryDirectory() as td {
        src = Path(td) / "bemake";
        _write_backend_only_project(src, "bemake");
        rc = _silent_eject(str(src));
        assert rc == 0;
        mk = (src / "ejected" / "Makefile").read_text();
        assert "npm" not in mk;
        assert "uvicorn main:app" in mk;
        readme = (src / "ejected" / "README.md").read_text();
        assert "frontend" not in readme;
    }
}


# ==================== entry-module reachability ====================
test "script modules not imported by the entry module get no endpoints" {
    with TemporaryDirectory() as td {
        src = Path(td) / "scriptapp";
        _write_project(src, "scriptapp");
        # A standalone CLI script: module-level `with entry` side effects
        # must never run inside the generated server.
        (src / "tool.jac").write_text(
            'def cli_main() {\n' + '    print("cli");\n' + '}\n\n' + 'with entry {\n' + '    cli_main();\n' + '}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert "from tool import" not in main_py;
        assert "/function/cli_main" not in main_py;
        # The module is still emitted for standalone use (python tool.py).
        assert _backend(src, "tool.py").exists();
        # Reachable modules keep their endpoints.
        assert '@app.post("/walker/Greet")' in main_py;
    }
}


test "modules transitively imported by the entry module keep endpoints" {
    with TemporaryDirectory() as td {
        src = Path(td) / "chainapp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "chainapp"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text('import from api { ping }\n');
        (src / "api.jac").write_text(
            'import from util { double }\n\n' + 'def:pub ping(x: int) -> int {\n' + '    return double(x);\n' + '}\n'
        );
        (src / "util.jac").write_text(
            'def double(x: int) -> int {\n' + '    return x * 2;\n' + '}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert '@app.post("/function/ping")' in main_py;
        # util is reachable through api, so its functions stay exposed.
        assert '@app.post("/function/double")' in main_py;
    }
}


test "entry module with server-side entry code is imported by main.py" {
    with TemporaryDirectory() as td {
        src = Path(td) / "bootapp";
        _write_project(src, "bootapp");
        (src / "main.jac").write_text(
            'import from server { Greet }\n\n' + 'with entry {\n' + '    print("boot");\n' + '}\n\n' + 'cl {\n' + '    import from .frontend { app as ClientApp }\n' + '    def:pub app -> JsxElement {\n' + '        return <ClientApp/>;\n' + '    }\n' + '}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        # main.jac is remapped to _jac_main; its entry side effects must run
        # at server boot like they would under `jac start`.
        assert "import _jac_main" in main_py;
    }
}


# ==================== client runtime chunks + compiled entry ====================
test "client runtime sibling chunks are copied alongside __jac_runtime.js" {
    with TemporaryDirectory() as td {
        src = Path(td) / "chunkapp";
        _write_project(src, "chunkapp");
        compiled = src / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True, exist_ok=True);
        (compiled / "client_runtime.js").write_text(
            'import { x } from "./client_runtime_core.js";\n' + 'export const runtime = x;\n'
        );
        (compiled / "client_runtime_core.js").write_text("export const x = 1;\n");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert _frontend(src, "src/__jac_runtime.js").exists();
        assert _frontend(src, "src/client_runtime_core.js").exists();
    }
}


test "compiled _entry.js and _routes.js are preferred over the synthesized entry" {
    with TemporaryDirectory() as td {
        src = Path(td) / "routedapp";
        _write_project(src, "routedapp");
        compiled = src / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True, exist_ok=True);
        (compiled / "client_runtime.js").write_text("export const runtime = 1;\n");
        (compiled / "_entry.js").write_text(
            'import { routes } from "./_routes.js";\nexport const boot = routes;\n'
        );
        (compiled / "_routes.js").write_text("export const routes = [];\n");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert _frontend(src, "src/_entry.js").exists();
        assert _frontend(src, "src/_routes.js").exists();
        html = _frontend(src, "index.html").read_text();
        assert "/src/_entry.js" in html;
        assert "__jac_entry.js" not in html;
    }
}


test "index.html falls back to the synthesized entry without a compiled entry" {
    with TemporaryDirectory() as td {
        src = Path(td) / "fallbackapp";
        _write_project(src, "fallbackapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert _frontend(src, "src/__jac_entry.js").exists();
        html = _frontend(src, "index.html").read_text();
        assert "/src/__jac_entry.js" in html;
    }
}


# ==================== @restspec custom paths ====================
test "@restspec functions get their declared paths mounted" {
    with TemporaryDirectory() as td {
        src = Path(td) / "restapp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "restapp"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text(
            'import from jaclang.runtimelib.builtin { restspec }\n' + 'import from jaclang.scale.jserver.jserver { HTTPMethod }\n\n' + '@restspec(method=HTTPMethod.POST, path="/api/v1/hello")\n' + 'def:pub hello(name: str = "") -> dict {\n' + '    return {"hi": name};\n' + '}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert "add_api_route" in main_py;
        # The module jserver (HTTPMethod's home) must be vendored so the
        # compiled module imports cleanly without jac-scale installed.
        assert _backend(src, "jaclang/scale/jserver/jserver.py").exists();
    }
}


# ==================== file upload (multipart) endpoints ====================
"""A project whose entry imports a `:pub` function taking an UploadFile."""
def _write_upload_project(src: Path, name: str = "up_app") {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nentry-point = "main.jac"\n'
    );
    (src / "main.jac").write_text('import from up { ingest }\n');
    (src / "up.jac").write_text(
        'import from fastapi { UploadFile }\n\n' + 'def:pub ingest(file: UploadFile) -> dict {\n' + '    return {"name": file.filename};\n' + '}\n'
    );
}


test "a function taking UploadFile becomes a multipart File() endpoint" {
    with TemporaryDirectory() as td {
        src = Path(td) / "upapp";
        _write_upload_project(src, "upapp");
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        # The upload param binds to File(), not a JSON body model.
        assert "file: UploadFile = File(...)" in main_py;
        assert "File, Form, UploadFile" in main_py;
        assert "class IngestFnIn" not in main_py;
        # python-multipart is required for File()/Form() parsing.
        reqs = _backend(src, "requirements.txt").read_text();
        assert "python-multipart" in reqs;
    }
}


test "non-upload functions keep their JSON body model" {
    with TemporaryDirectory() as td {
        src = Path(td) / "jsonapp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "jsonapp"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text('import from api { greet }\n');
        (src / "api.jac").write_text(
            'def:pub greet(name: str) -> str {\n    return "hi " + name;\n}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = _backend(src, "main.py").read_text();
        assert "class GreetFnIn" in main_py;
        assert "File, Form, UploadFile" not in main_py;
        reqs = _backend(src, "requirements.txt").read_text();
        assert "python-multipart" not in reqs;
    }
}


# ==================== data-file routing (assets vs backend data) ====================
test "web assets go to the frontend only; other data to the backend only" {
    with TemporaryDirectory() as td {
        src = Path(td) / "resapp";
        _write_project(src, "resapp");
        (src / "assets").mkdir();
        (src / "assets" / "logo.svg").write_text("<svg/>");
        (src / "schemas").mkdir();
        (src / "schemas" / "doc.yaml").write_text("a: 1\n");
        (src / "docs").mkdir();
        (src / "docs" / "guide.md").write_text("# guide\n");
        rc = _silent_eject(str(src));
        assert rc == 0;
        # Image asset: frontend only.
        assert _frontend(src, "src/assets/logo.svg").exists();
        assert not _backend(src, "assets/logo.svg").exists();
        # yaml/md data: backend only, never duplicated into the UI bundle.
        assert _backend(src, "schemas/doc.yaml").exists();
        assert not _frontend(src, "src/schemas/doc.yaml").exists();
        assert _backend(src, "docs/guide.md").exists();
        assert not _frontend(src, "src/docs/guide.md").exists();
    }
}


# ==================== docstring-only modules are not backend servers ====================
test "a module that is only a docstring is not emitted as a backend module" {
    with TemporaryDirectory() as td {
        src = Path(td) / "docmod";
        _write_project(src, "docmod");
        # A multi-line docstring module with no real statements (mirrors a
        # compiled client page): it must not become a backend .py module.
        (src / "notes.jac").write_text(
            '"""First line of the module docstring\n' + 'that wraps onto a second line."""\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert not _backend(src, "notes.py").exists();
    }
}


# ==================== prior eject output is not swept into a new eject ====================
test "a prior eject output is excluded from a re-eject to a different dir" {
    with TemporaryDirectory() as td {
        src = Path(td) / "reapp";
        _write_project(src, "reapp");
        # First eject to the default ./ejected.
        assert _silent_eject(str(src)) == 0;
        assert (src / "ejected" / ".jac-ejected").exists();
        # Now eject to a sibling dir: the earlier ./ejected (marked output)
        # must not be pulled in as source data.
        dest = Path(td) / "dist";
        assert _silent_eject(str(src), output=str(dest)) == 0;
        assert not (dest / "backend" / "ejected").exists();
        assert not (dest / "frontend" / "src" / "ejected").exists();
    }
}


# ==================== byLLM config (backend/jac.toml) ====================
test "byLLM plugin config is emitted into backend/jac.toml" {
    with TemporaryDirectory() as td {
        src = Path(td) / "llmcfg";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "llmcfg"\nversion = "0.2.0"\nentry-point = "main.jac"\n' + '\n[byllm.model]\n' + 'default_model = "${BYLLM_MODEL:-openai/google/gemma-4-12B-it}"\n' + 'api_key = "${BYLLM_API_KEY:-EMPTY}"\n' + '\n[byllm.call_params]\ntemperature = 0.0\nmax_tokens = 1024\n'
        );
        (src / "main.jac").write_text(
            'import from jaclang.byllm.lib { Model }\n\n' + 'def:pub ask(q: str) -> str by Model()(query=q);\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        toml_out = _backend(src, "jac.toml");
        assert toml_out.exists();
        text = toml_out.read_text();
        # The byLLM model section is carried over, interpolation preserved so
        # the runtime resolves it from .env (not baked at eject time).
        assert "[byllm.model]" in text;
        assert "${BYLLM_MODEL:-openai/google/gemma-4-12B-it}" in text;
        assert "[byllm.call_params]" in text;
        assert "max_tokens = 1024" in text;
        # The project section is present so the config loader finds the root.
        assert 'name = "llmcfg"' in text;
    }
}


test "projects without byLLM config get no backend jac.toml" {
    with TemporaryDirectory() as td {
        src = Path(td) / "nollm";
        _write_project(src, "nollm");
        rc = _silent_eject(str(src));
        assert rc == 0;
        assert not _backend(src, "jac.toml").exists();
    }
}


# ==================== test annexes stripped from backend modules ====================
test "compiled test code and dev-path decorators are stripped from the backend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "tst";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "tst"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text('import from core { compute }\n');
        (src / "core.jac").write_text('def:pub compute(x: int) -> int;\n');
        # An impl annex: its function carries an @impl_patch_filename decorator
        # naming the annex's absolute path.
        (src / "core.impl.jac").write_text(
            'impl compute(x: int) -> int {\n    return x * 2;\n}\n'
        );
        # A test annex: compiles to an @jac_test function merged into core.
        (src / "core.test.jac").write_text(
            'test "doubles" {\n    assert compute(2) == 4;\n}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        core_py = _backend(src, "core.py").read_text();
        # Real code survives.
        assert "def compute" in core_py;
        # Test code and the dev-path decorators do not.
        assert "def test_" not in core_py;
        assert "jac_test" not in core_py;
        assert "impl_patch_filename" not in core_py;
        assert str(src) not in core_py;
    }
}


test "a user import named jac_test is not stripped (only jaclib imports are)" {
    with TemporaryDirectory() as td {
        src = Path(td) / "uimp";
        src.mkdir(parents=True, exist_ok=True);
        (src / "jac.toml").write_text(
            '[project]\nname = "uimp"\nentry-point = "main.jac"\n'
        );
        (src / "main.jac").write_text('import from helper { run }\n');
        (src / "userlib.jac").write_text(
            'def jac_test() -> str {\n    return "custom";\n}\n'
        );
        (src / "helper.jac").write_text(
            'import from userlib { jac_test }\n\n' + 'def:pub run() -> str {\n    return jac_test();\n}\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        helper_py = _backend(src, "helper.py").read_text();
        # The project's own jac_test import must survive; only jaclib's is pruned.
        assert "from userlib import jac_test" in helper_py;
    }
}


test "no impl_patch_filename decorators survive anywhere in the ejected backend" {
    with TemporaryDirectory() as td {
        src = Path(td) / "vend";
        _write_project(src, "vend");
        rc = _silent_eject(str(src));
        assert rc == 0;
        # The app modules and the vendored jaclang runtime alike must ship no
        # @impl_patch_filename decorators (they name .jac sources the ejected
        # Python app does not contain).
        offenders: list = [];
        for py in (src / "ejected" / "backend").rglob("*.py") {
            if "@impl_patch_filename(" in py.read_text() {
                offenders.append(str(py.name));
            }
        }
        assert offenders == [] , f"impl_patch_filename left in: {offenders}";
    }
}
