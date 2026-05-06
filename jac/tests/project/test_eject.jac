"""Tests for the `jac eject` command.

These tests run eject in-process against tiny projects materialized in
TemporaryDirectory(), so the whole file completes in well under a
second on a warm cache and runs as part of the standard `pytest jac`
suite. The goal is to catch file-collection, codegen, and boilerplate
regressions on every push, without paying the cost of the wheel-build
/ HTTP smoke pipeline.
"""

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


"""Write a minimal valid jac.toml at the given source root."""
def _write_jac_toml(src: Path, name: str = "test_app") {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nversion = "0.1.0"\nentry-point = "main.jac"\n[dependencies]\n'
    );
}


"""Write a minimal main.jac that compiles cleanly."""
def _write_main_jac(src: Path) {
    (src / "main.jac").write_text('with entry { print("hi"); }\n');
}


"""Sorted list of all .jac files (relative paths) inside a directory."""
def _list_jac_files(d: Path) -> list[str] {
    files = [
        str(p.relative_to(d))
        for p in d.rglob("*.jac")
        if p.is_file()
    ];
    files.sort();
    return files;
}


# ==================== happy path ====================
test "eject produces expected output layout" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert out.exists();
        assert (out / "backend" / "main.py").exists();
        assert (out / "backend" / "serve.py").exists();
        assert (out / "backend" / "requirements.txt").exists();
        assert (out / "frontend" / "package.json").exists();
        assert (out / "frontend" / "vite.config.js").exists();
        assert (out / "frontend" / "index.html").exists();
        assert (out / "run.sh").exists();
        assert (out / "README.md").exists();
    }
}


test "ejected output contains zero .jac files" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "helper.jac").write_text('def hello() -> str { return "hi"; }\n');
        (src / "helper.impl.jac").write_text('impl hello() -> str { return "hi"; }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        leftover = _list_jac_files(out);
        assert leftover == [] , f"Ejected output still has .jac files: {leftover}";
    }
}


# ==================== codegen validity ====================
test "every emitted .py file parses as valid Python" {
    # The strongest cheap correctness check we have without booting a
    # server: round-trip every emitted backend module through ast.parse
    # so codegen regressions that produce broken Python fail loudly.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "users.sv.jac").write_text(
            'def get_user() -> str { return "alice"; }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        py_files = sorted((out / "backend").rglob("*.py"));
        assert len(py_files) >= 2 , f"Expected backend .py files, got {py_files}";
        for py in py_files {
            try {
                ast.parse(py.read_text());
            } except SyntaxError as e {
                raise AssertionError(f"Emitted invalid Python in {py.name}: {e}");
            }
        }
    }
}


test "emitted package.json is valid JSON with required keys" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        pkg_path = src.parent / "myapp-ejected" / "frontend" / "package.json";
        # json.loads raises if the file isn't valid JSON.
        pkg = json.loads(pkg_path.read_text());
        assert pkg["name"] == "myapp";
        assert "scripts" in pkg;
        assert "dev" in pkg["scripts"];
        # Vite is always added to devDependencies as a baseline so
        # `npm run dev` works out of the box.
        assert "vite" in pkg["devDependencies"];
    }
}


test "user code from main.jac survives the round-trip into main.py" {
    # Catches the "eject swallowed the function body" class of bug:
    # codegen runs, file is written, but the user's actual logic is
    # missing. A unique marker string flushed through `print(...)` is
    # the smallest signal that codegen actually ran end-to-end.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        (src / "main.jac").write_text('with entry { print("EJECT_MARKER_91A2F3"); }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = (src.parent / "myapp-ejected" / "backend" / "main.py").read_text();
        assert "EJECT_MARKER_91A2F3" in main_py;
    }
}


# ==================== sv/cl routing ====================
test "sv files route to backend, cl files route to frontend" {
    # The whole point of eject is that .sv.jac compiles to Python in
    # backend/ and .cl.jac compiles to JavaScript in frontend/src/.
    # Verifies _to_py_rel_path / _to_js_rel_path / _is_meaningful_python
    # actually segregate output by context tag.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "users.sv.jac").write_text(
            'def get_user() -> str { return "alice"; }\n'
        );
        (src / "widget.cl.jac").write_text(
            'cl { def:pub w() -> any { return <div></div>; } }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        # users.sv.jac must produce backend Python only.
        assert (out / "backend" / "users.py").exists();
        assert not (out / "frontend" / "src" / "users.js").exists();
        # widget.cl.jac must produce frontend JavaScript only. The
        # corresponding Python module is filtered out by
        # _is_meaningful_python (a .cl module's Python output is just
        # imports / a docstring with no behavior to ship server-side).
        assert (out / "frontend" / "src" / "widget.js").exists();
        assert not (out / "backend" / "widget.py").exists();
    }
}


# ==================== regression: .jac/ build cache ====================
test "eject succeeds when source contains a .jac build-cache directory" {
    # Regression: Path.rglob("*.jac") matches both files AND directories
    # whose name ends in .jac. Before the fix, the .jac/ build cache
    # directory itself was passed to JacProgram.compile and crashed with
    # "[Errno 21] Is a directory". Any project that had been built before
    # ejecting would fail.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        cache = src / ".jac";
        cache.mkdir();
        (cache / "cached.jac").write_text("garbage that must not be compiled {");
        (cache / "metadata.txt").write_text("cache metadata");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert (out / "backend" / "main.py").exists();
    }
}


# ==================== file collection rules ====================
test "eject excludes .impl.jac and .test.jac files" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "main.impl.jac").write_text("# impl shenanigans\n");
        (src / "stuff.test.jac").write_text('test "foo" { assert True; }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert not (out / "backend" / "main.impl.py").exists();
        assert not (out / "backend" / "stuff.test.py").exists();
    }
}


test "eject skips build, vendor, and hidden directories" {
    # Covers both branches of the exclusion logic in _collect_jac_files:
    # the well-known _SKIP_DIRS set and the generic startswith(".") check.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        excluded_dirs = [
            "node_modules",
            ".venv",
            "venv",
            "dist",
            "build",
            "__pycache__",
            ".hidden"
        ];
        for ex_dir in excluded_dirs {
            d = src / ex_dir;
            d.mkdir();
            (d / "junk.jac").write_text("garbage that must not compile {");
        }
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        leaked = [str(p.relative_to(out)) for p in out.rglob("junk*")];
        leaked.sort();
        assert leaked == [] , f"Excluded-dir junk leaked into output: {leaked}";
    }
}


# ==================== assets ====================
test "eject copies assets directory into frontend src" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        assets = src / "assets";
        assets.mkdir();
        (assets / "logo.txt").write_text("static asset content");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        copied = out / "frontend" / "src" / "assets" / "logo.txt";
        assert copied.exists();
        assert copied.read_text() == "static asset content";
    }
}


# ==================== output directory semantics ====================
test "eject refuses to overwrite existing output without force" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc1 = _silent_eject(str(src));
        assert rc1 == 0;
        rc2 = _silent_eject(str(src));
        assert rc2 == 1;
    }
}


test "eject force overwrites existing output directory" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc1 = _silent_eject(str(src));
        assert rc1 == 0;
        out = src.parent / "myapp-ejected";
        (out / "MARKER.txt").write_text("should be removed by force");
        rc2 = _silent_eject(str(src), force=True);
        assert rc2 == 0;
        assert not (out / "MARKER.txt").exists();
        assert (out / "backend" / "main.py").exists();
    }
}


test "eject explicit output path lands at the requested location" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        target = Path(td) / "elsewhere" / "ejected";
        rc = _silent_eject(str(src), output=str(target));
        assert rc == 0;
        assert target.exists();
        assert (target / "backend" / "main.py").exists();
        # Default sibling location must NOT have been created.
        assert not (src.parent / "myapp-ejected").exists();
    }
}


# ==================== error handling ====================
test "eject errors when jac.toml is missing" {
    with TemporaryDirectory() as td {
        src = Path(td) / "noproject";
        src.mkdir();
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 1;
    }
}


test "eject errors when output equals source" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src), output=str(src));
        assert rc == 1;
    }
}


test "eject errors when source contains a syntactically invalid .jac file" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "broken.jac").write_text("def hello -> int { return ; ");
        rc = _silent_eject(str(src));
        assert rc != 0;
    }
}


# ==================== metadata helpers ====================
test "load_eject_project_metadata falls back to source dir name on placeholder" {
    with TemporaryDirectory() as td {
        src = Path(td) / "actual_dir_name";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["project_name"] == "actual_dir_name";
        assert meta["entry_point"] == "main.jac";
        assert meta["entry_module"] == "main";
    }
}


test "load_eject_project_metadata uses jac.toml name when not a placeholder" {
    with TemporaryDirectory() as td {
        src = Path(td) / "wrong_dir_name";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "real_name"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["project_name"] == "real_name";
    }
}


test "load_eject_project_metadata strips sv context tag from entry_module" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "myapp"\nentry-point = "main.sv.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["entry_module"] == "main";
    }
}


test "resolve_eject_output defaults to sibling -ejected directory" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        out = eject.resolve_eject_output(src, "");
        assert out == (Path(td) / "myapp-ejected").resolve();
    }
}


test "resolve_eject_output honors explicit output argument" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        explicit = Path(td) / "elsewhere";
        out = eject.resolve_eject_output(src, str(explicit));
        assert out == explicit.resolve();
    }
}


# ==================== entry module always emitted ====================
test "entry module is emitted even when its python is import-only" {
    # Catches the regression where main.jac contains only a top-level
    # `import` and a `cl {}` block. The compiled python is just the
    # `from ... import ...` line — _is_meaningful_python rejects that as
    # not behavior-bearing, but serve.py imports the entry module by
    # name, so dropping it leaves the ejected backend unable to register
    # any walkers reached via that import.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        # Imports-only main.jac (the cl block produces JS, no python).
        (src / "main.jac").write_text(
            'import from os {path}\ncl { def:pub app() -> any { return 42; } }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = src.parent / "myapp-ejected" / "backend" / "main.py";
        assert main_py.exists();
        body = main_py.read_text();
        assert "from os import path" in body;
    }
}


# ==================== implicit plugin auto-detection ====================
test "byllm import is auto-added to requirements.txt" {
    # `byllm` is shipped as a separate pypi package and rarely appears in
    # jac.toml [dependencies] because the jaclang toolchain pulls it in
    # implicitly. Without auto-detection, the ejected backend ImportErrors
    # on the very first request — the plugin scan in eject reads emitted
    # python and adds known companion packages.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "ai.sv.jac").write_text(
            'import from byllm.lib {Model}\n'
            'def make_model() -> Model { return Model(); }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        req = (
            src.parent / "myapp-ejected" / "backend" / "requirements.txt"
        ).read_text();
        assert "byllm" in req , f"byllm missing from requirements.txt:\n{req}";
    }
}


test "requirements.txt always pins jaclang" {
    # Every ejected app needs jaclang at runtime (walker dispatch, HTTP
    # handler, auth). Pinning to the exact version used to eject keeps
    # `pip install` reproducible — leaving it unpinned has caused
    # PyPI/dev-install drift mismatches in the wild.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        req = (
            src.parent / "myapp-ejected" / "backend" / "requirements.txt"
        ).read_text();
        first_line = req.splitlines()[0];
        # Pin format `jaclang==X.Y.Z`, or bare `jaclang` if version
        # discovery failed (still acceptable but suboptimal).
        assert first_line == "jaclang" or first_line.startswith("jaclang==");
    }
}


# ==================== frontend bootstrap ====================
test "__jac_entry.js bootstraps the SPA into div#root" {
    # The compiled main.js exports the `app` component but does not call
    # createRoot — that's the role of __jac_entry.js. Without it, vite
    # serves the assets cleanly but the page renders blank.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        entry = src.parent / "myapp-ejected" / "frontend" / "src" / "__jac_entry.js";
        assert entry.exists();
        body = entry.read_text();
        assert 'import { app as App } from "./main.js";' in body;
        assert 'createRoot(document.getElementById("root"))' in body;
        assert 'JacClientErrorBoundary' in body;
    }
}


test "index.html mounts to div#root and loads __jac_entry.js" {
    # The mount node id and entry script tag must agree with what
    # __jac_entry.js targets — drift between these would silently leave
    # the page blank with no console error.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        html = (src.parent / "myapp-ejected" / "frontend" / "index.html").read_text();
        assert '<div id="root"></div>' in html;
        assert '/src/__jac_entry.js' in html;
    }
}


# ==================== runtime import injection ====================
test "compiled .cl.jac js gets a @jac/runtime import prepended" {
    # The Jac client compiler post-processes every compiled JS module by
    # injecting `import {__jacJsx, __jacSpawn} from "@jac/runtime";` —
    # without it, every component throws `__jacJsx is not defined` at
    # render time. Eject must replicate that step or the SPA crashes
    # behind the ErrorBoundary the moment it tries to render JSX.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "widget.cl.jac").write_text(
            'cl { def:pub Widget() -> any { return <div></div>; } }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        widget_js = (
            src.parent / "myapp-ejected" / "frontend" / "src" / "widget.js"
        ).read_text();
        assert widget_js.startswith(
            'import {__jacJsx, __jacSpawn} from "@jac/runtime";'
        );
    }
}


# ==================== vite proxy port wiring ====================
test "vite.config.js reads BACKEND_PORT for the proxy target" {
    # The proxy target was previously hardcoded to localhost:8000, so a
    # custom PORT in run.sh produced ECONNREFUSED in the browser. The
    # config now reads $BACKEND_PORT (set by run.sh from $PORT) so the
    # frontend's API calls follow the backend wherever it actually binds.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        vite = (
            src.parent / "myapp-ejected" / "frontend" / "vite.config.js"
        ).read_text();
        assert "process.env.BACKEND_PORT" in vite;
        # Proxy target should reference the env-derived backend, not a
        # hardcoded port.
        assert '"http://localhost:8000"' not in vite;
    }
}


# ==================== public walker access metadata ====================
test "serve.py seeds PUBLIC_WALKERS from :pub access modifiers" {
    # ModuleIntrospector._extract_access_levels reads :pub from the Jac
    # AST at request time — the ejected backend has no Jac sources so
    # every walker would default to auth-required (401). Eject scans
    # the AST at codegen time and bakes the result into serve.py.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "api.sv.jac").write_text(
            'walker :pub open_walker { '
            'can run with `root entry { report 1; } }\n'
            'walker closed_walker { '
            'can run with `root entry { report 2; } }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        serve = (src.parent / "myapp-ejected" / "backend" / "serve.py").read_text();
        assert '"open_walker"' in serve;
        # Non-:pub walkers must NOT be in the public set or auth bypass
        # would leak protected endpoints.
        assert '"closed_walker"' not in serve;
        assert "PUBLIC_WALKERS" in serve;
    }
}


test "serve.py rehydrates _walker_access after introspector.load()" {
    # The pre-computed sets are useless unless serve.py actually
    # installs them — check the wiring is present in the generated code.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        serve = (src.parent / "myapp-ejected" / "backend" / "serve.py").read_text();
        assert "introspector._walker_access[walker_name]" in serve;
        assert "PUBLIC_WALKERS" in serve;
    }
}


# ==================== streaming response support ====================
test "serve.py patches HTTPTransport for streaming generators" {
    # Walkers backed by an LLM stream chunks via a generator. The base
    # transport json.dumps()-es the response and crashes on generators;
    # serve.py monkey-patches HTTPTransport.send to write SSE bytes
    # instead. This only checks the patch is wired in — actual stream
    # behaviour is exercised in the integration suite.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        serve = (src.parent / "myapp-ejected" / "backend" / "serve.py").read_text();
        assert "from jaclang.runtimelib.transport import HTTPTransport" in serve;
        assert "HTTPTransport.send = _streaming_http_send" in serve;
        assert "text/event-stream" in serve;
        assert "GeneratorType" in serve;
    }
}


# ==================== resource files copied ====================
test "non-jac source files mirror into backend and frontend/src" {
    # services/config/*.json, services/docs/*.md, *.css and other data
    # the compiled python or JS opens at runtime are not part of the
    # codegen pipeline — eject must copy them or the app blows up at
    # first read. Mirrored into both halves so we don't have to guess
    # which side will reach for the file.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        cfg_dir = src / "services" / "config";
        cfg_dir.mkdir(parents=True);
        (cfg_dir / "rerank.json").write_text('{"k": 5}');
        (src / "global.css").write_text("body { color: red; }");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert (out / "backend" / "services" / "config" / "rerank.json").exists();
        assert (
            out / "frontend" / "src" / "services" / "config" / "rerank.json"
        ).exists();
        assert (out / "backend" / "global.css").exists();
        assert (out / "frontend" / "src" / "global.css").exists();
    }
}


test "public/ lands at frontend/public, not frontend/src/public" {
    # Vite expects a project-root `public/` directory for unprocessed
    # static assets. Mirroring into `frontend/src/public/` would put it
    # in the wrong place and break served paths like `/logo.png`.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        public = src / "public";
        public.mkdir();
        (public / "logo.png").write_text("fake png contents");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert (out / "frontend" / "public" / "logo.png").exists();
        # Must not be duplicated under src/.
        assert not (out / "frontend" / "src" / "public" / "logo.png").exists();
    }
}


# ==================== client runtime vendoring ====================
test "client_runtime.js is vendored and aliased when present in source" {
    # The Jac build emits the client runtime under
    # `<src>/.jac/client/compiled/client_runtime.js` and aliases
    # `@jac/runtime` to it. Eject vendors that file so the ejected
    # frontend can resolve `@jac/runtime` without depending on the
    # external jac-client-node package or a re-run of the Jac build.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        compiled = src / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True);
        (compiled / "client_runtime.js").write_text(
            "// fake runtime\nexport function __jacJsx() {}\n"
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        runtime_dest = out / "frontend" / "src" / "__jac_runtime.js";
        assert runtime_dest.exists();
        assert "// fake runtime" in runtime_dest.read_text();
        vite = (out / "frontend" / "vite.config.js").read_text();
        assert '"@jac/runtime": path.resolve(__dirname, "src/__jac_runtime.js")' in vite;
    }
}


test "vite.config.js omits @jac/runtime alias when no runtime is present" {
    # Conversely: don't write a dangling alias to a file we never
    # produced — that would surface as an unhelpful Vite error instead
    # of the explicit eject-time warning the user already got.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        vite = (out / "frontend" / "vite.config.js").read_text();
        assert '"@jac/runtime"' not in vite;
        assert not (out / "frontend" / "src" / "__jac_runtime.js").exists();
    }
}


# ==================== run.sh threads PORT into BACKEND_PORT ====================
test "run.sh exports BACKEND_PORT to the vite subshell" {
    # The Vite proxy target depends on $BACKEND_PORT being in the
    # frontend process env. run.sh sets PORT for the backend; this
    # check makes sure that value is also forwarded to vite.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        run = (src.parent / "myapp-ejected" / "run.sh").read_text();
        assert 'BACKEND_PORT="$PORT"' in run;
    }
}
