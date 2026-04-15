"""Implementation of the `jac eject` command.

Eject takes a Jac project and produces a self-contained output directory
containing only Python and JavaScript files plus the small amount of
boilerplate (requirements.txt, package.json, vite.config.js, run scripts,
README) needed to run the project without the Jac toolchain. The ejected
backend still imports from the installed `jaclang` runtime at runtime; the
goal of this first version is "zero .jac files in the output", not "zero
jaclang dependency".
"""

import shutil;
import tomllib;
import json;
import from pathlib { Path }
import from typing { Any }
import from jaclang.cli.console { console }

# File suffixes that mark a Jac file as exclusively server- or client-side.
# Other .jac files (e.g. main.jac) may compile to both Python and JS.
glob _SV_SUFFIX: str = ".sv.jac",
     _CL_SUFFIX: str = ".cl.jac",
     _IMPL_SUFFIX: str = ".impl.jac",
     _TEST_SUFFIX: str = ".test.jac",
     # Directories never traversed when collecting source files.
     _SKIP_DIRS: set = {".jac",".git",".venv","venv","node_modules","__pycache__",".mypy_cache",".pytest_cache","dist","build"};


"""Resolve the output directory for `jac eject`.

Encodes the same fallback logic the eject command applies internally:
when `output` is empty, drop a sibling `<source>-ejected` directory next
to `src`. Plugins extending eject (pre or post hooks) should call this
helper so the directory they read or write to stays in sync with whatever
the default eject command would have produced, even if the resolution
logic changes in the future.
"""
def resolve_eject_output(src: Path, output: str) -> Path {
    if output {
        return Path(output).resolve();
    }
    return (src.parent / f"{src.name}-ejected").resolve();
}


"""Read jac.toml and return resolved project metadata for `jac eject`.

Returns a dict with the keys eject needs to drive its emit pipeline:

- `project_name`: the resolved project name (falls back to the source
  directory name when jac.toml has no name or still contains the
  unrendered `{{name}}` template placeholder).
- `entry_point`: the raw entry-point filename from jac.toml (default
  `"main.jac"`).
- `entry_module`: the entry-point stem with `.sv.jac` / `.cl.jac` / `.jac`
  suffixes stripped (e.g. `"main"`), suitable for use as a Python module
  name in the generated `serve.py`.
- `toml_data`: the raw parsed jac.toml so plugins can read other sections
  (e.g. `[plugins.scale]`, `[dependencies.npm]`) without re-parsing.

Raises `FileNotFoundError` if `src/jac.toml` does not exist, or
`RuntimeError` if it cannot be parsed.
"""
def load_eject_project_metadata(src: Path) -> dict {
    toml_path = src / "jac.toml";
    if not toml_path.exists() {
        raise FileNotFoundError(f"No jac.toml found in {src}");
    }
    try {
        with open(toml_path, "rb") as f {
            toml_data = tomllib.load(f);
        }
    } except Exception as e {
        raise RuntimeError(f"Failed to parse {toml_path}: {e}");
    }
    project_section = toml_data.get("project", {});
    raw_name = project_section.get("name", "") or "";
    # Fall back to the source directory name if jac.toml has the unrendered
    # template placeholder (`{{name}}`) or no name at all.
    if (not raw_name) or ("{{" in raw_name) {
        project_name = src.name;
    } else {
        project_name = raw_name;
    }
    entry_point = project_section.get("entry-point", "main.jac");
    entry_module = _strip_jac_suffix(Path(entry_point).name);
    return {
        "project_name": project_name,
        "entry_point": entry_point,
        "entry_module": entry_module,
        "toml_data": toml_data,

    };
}


"""Eject a Jac project to standalone Python + JavaScript."""
impl eject(source: str = ".", output: str = "", force: bool = False) -> int {
    src = Path(source).resolve();
    if not src.exists() or not src.is_dir() {
        console.error(f"Source directory does not exist: {src}");
        return 1;
    }

    try {
        metadata = load_eject_project_metadata(src);
    } except FileNotFoundError as e {
        console.error(str(e));
        console.print(
            "  Eject requires a Jac project (a directory containing jac.toml).",
            style="muted"
        );
        return 1;
    } except RuntimeError as e {
        console.error(str(e));
        return 1;
    }
    project_name: str = metadata["project_name"];
    entry_point: str = metadata["entry_point"];
    entry_module: str = metadata["entry_module"];
    toml_data: dict = metadata["toml_data"];

    entry_path = src / entry_point;
    if not entry_path.exists() {
        console.warning(
            f"Entry point '{entry_point}' not found; serve.py will need manual editing."
        );
    }

    out = resolve_eject_output(src, output);
    if out == src {
        console.error("Output directory cannot be the same as the source directory.");
        return 1;
    }
    if out.exists() {
        if not force {
            console.error(f"Output directory already exists: {out}");
            console.print("  Use --force to overwrite.", style="muted");
            return 1;
        }
        try {
            shutil.rmtree(out);
        } except Exception as e {
            console.error(f"Failed to remove existing output directory: {e}");
            return 1;
        }
    }
    out.mkdir(parents=True);
    backend_dir = out / "backend";
    frontend_src_dir = out / "frontend" / "src";
    backend_dir.mkdir(parents=True);
    frontend_src_dir.mkdir(parents=True);

    console.print(f"\n📦 Ejecting Jac project '{project_name}'", style="bold cyan");
    console.print(f"  Source: {src}");
    console.print(f"  Output: {out}\n");

    # Collect every .jac file we should compile (skip impl/test files and
    # vendored / build directories).
    jac_files = _collect_jac_files(src);
    if not jac_files {
        console.error("No .jac source files found to eject.");
        return 1;
    }

    # Lazily import the compiler — eject is rarely invoked, so we avoid the
    # import cost during normal CLI startup.
    import from jaclang.jac0core.program { JacProgram }

    py_count = 0;
    js_count = 0;
    error_count = 0;
    for jac_file in jac_files {
        rel = jac_file.relative_to(src);
        try {
            prog = JacProgram();
            ir = prog.compile(file_path=str(jac_file));
        } except Exception as e {
            console.error(f"  ✗ {rel}: compile failed: {e}");
            error_count += 1;
            continue;
        }
        if prog.errors_had {
            for err in prog.errors_had {
                console.error(f"  ✗ {rel}: {err}");
            }
            error_count += 1;
            continue;
        }

        py_code = ir.gen.py or "";
        js_code = ir.gen.js or "";

        wrote_any = False;
        if _is_meaningful_python(py_code) {
            py_rel = _to_py_rel_path(rel);
            py_out = backend_dir / py_rel;
            py_out.parent.mkdir(parents=True, exist_ok=True);
            py_out.write_text(py_code, encoding="utf-8");
            py_count += 1;
            wrote_any = True;
        }
        if js_code.strip() {
            js_rel = _to_js_rel_path(rel);
            js_out = frontend_src_dir / js_rel;
            js_out.parent.mkdir(parents=True, exist_ok=True);
            js_out.write_text(js_code, encoding="utf-8");
            js_count += 1;
            wrote_any = True;
        }
        if wrote_any {
            console.print(f"  ✔ {rel}", style="success");
        } else {
            console.print(f"  · {rel} (no output)", style="muted");
        }
    }

    if error_count > 0 {
        console.error(
            f"\n{error_count} file(s) failed to compile. Output is incomplete."
        );
        return 1;
    }

    # Copy static assets if present.
    assets_src = src / "assets";
    if assets_src.exists() and assets_src.is_dir() {
        try {
            shutil.copytree(assets_src, frontend_src_dir / "assets");
            console.print("  ✔ assets/", style="success");
        } except Exception as e {
            console.warning(f"Failed to copy assets/: {e}");
        }
    }

    # Generate boilerplate.
    _emit_requirements_txt(backend_dir, toml_data);
    _emit_serve_py(backend_dir, entry_module);
    _emit_package_json(out / "frontend", project_name, toml_data);
    _emit_vite_config(out / "frontend");
    _emit_index_html(out / "frontend", project_name);
    _emit_run_script(out);
    _emit_readme(out, project_name, entry_module);

    console.print();
    console.success(f"Ejected '{project_name}' → {out}");
    console.print(
        f"  {py_count} Python file(s), {js_count} JavaScript file(s)", style="muted"
    );
    console.print();
    console.print("Next steps:", style="bold");
    console.print(f"  cd {out}");
    console.print("  pip install -r backend/requirements.txt");
    console.print("  (cd frontend && npm install)");
    console.print("  ./run.sh");
    console.print();
    return 0;
}


"""Walk the source tree and return every .jac file that should be compiled.

Skips impl/test files (they merge into their declaration sibling at compile
time and have no standalone meaning), hidden directories, and well-known
build/vendor directories listed in _SKIP_DIRS.
"""
def _collect_jac_files(src: Path) -> list[Path] {
    results: list[Path] = [];
    all_files = list(src.rglob("*.jac"));
    all_files.sort();
    for path in all_files {
        # rglob("*.jac") matches both files AND directories whose name ends
        # in `.jac` (e.g. the `.jac/` build cache dir). Skip non-files so the
        # compile step never receives a directory path.
        if not path.is_file() {
            continue;
        }
        rel = path.relative_to(src);
        rel_parts = list(rel.parts);
        excluded = False;
        # Check parent directory parts (everything except the filename itself).
        for i in range(len(rel_parts) - 1) {
            part = rel_parts[i];
            if part in _SKIP_DIRS {
                excluded = True;
                break;
            }
            if part.startswith(".") {
                excluded = True;
                break;
            }
        }
        if excluded {
            continue;
        }
        name = path.name;
        if name.endswith(_IMPL_SUFFIX) or name.endswith(_TEST_SUFFIX) {
            continue;
        }
        results.append(path);
    }
    return results;
}


"""Strip the .sv.jac / .cl.jac / .jac suffix from a filename, returning the stem."""
def _strip_jac_suffix(name: str) -> str {
    if name.endswith(_SV_SUFFIX) {
        return name[:-len(_SV_SUFFIX)];
    }
    if name.endswith(_CL_SUFFIX) {
        return name[:-len(_CL_SUFFIX)];
    }
    if name.endswith(".jac") {
        return name[:-4];
    }
    return name;
}


"""Map a project-relative .jac path to its ejected .py path.

`endpoints.sv.jac` → `endpoints.py`, `frontend.cl.jac` → `frontend.py`,
`main.jac` → `main.py`. The .sv / .cl context tag is dropped because the
compiler emits clean Python imports without it (e.g. `from endpoints import ...`).
"""
def _to_py_rel_path(rel: Path) -> Path {
    return rel.parent / (_strip_jac_suffix(rel.name) + ".py");
}


"""Map a project-relative .jac path to its ejected .js path."""
def _to_js_rel_path(rel: Path) -> Path {
    return rel.parent / (_strip_jac_suffix(rel.name) + ".js");
}


"""Decide whether a unparsed Python module has any real content worth writing.

Files like `frontend.cl.jac` produce a Python module that contains only a
docstring and a couple of `from __future__` / runtime imports — there is no
behavior to ship to the backend. We skip those so the ejected backend
directory only contains modules that actually do something.
"""
def _is_meaningful_python(py_code: str) -> bool {
    if not py_code.strip() {
        return False;
    }
    for raw_line in py_code.splitlines() {
        line = raw_line.strip();
        if not line {
            continue;
        }
        if line.startswith("#") {
            continue;
        }
        if line.startswith('"""') or line.startswith("'''") {
            continue;
        }
        if line.startswith("from __future__") {
            continue;
        }
        if line.startswith("from ") or line.startswith("import ") {
            continue;
        }
        return True;
    }
    return False;
}


"""Write backend/requirements.txt mapping jac.toml [dependencies] to pip.

Always pins jaclang itself so the ejected backend can use the runtime
helpers it imports (jaclang.jac0core.jaclib, jaclang.runtimelib.server, ...).
"""
def _emit_requirements_txt(backend_dir: Path, toml_data: dict) {
    deps = toml_data.get("dependencies", {});
    # Filter out the npm subsection (it's a sibling key, not a python dep).
    py_deps: dict[str, str] = {};
    for (k, v) in deps.items() {
        if isinstance(v, str) {
            py_deps[k] = v;
        }
    }
    lines: list[str] = ["jaclang"];
    for (name, spec) in sorted(py_deps.items()) {
        if spec and spec != "*" {
            # tomllib gives version specs like ">=1.0" or "1.0.0".
            if any(
                spec.startswith(op) for op in ("==", ">=", "<=", "~=", "!=", ">", "<")
            ) {
                lines.append(f"{name}{spec}");
            } else {
                lines.append(f"{name}=={spec}");
            }
        } else {
            lines.append(name);
        }
    }
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}


"""Write the serve.py entry script for the ejected backend.

The script loads the entry module via importlib (no Jac compilation), stuffs
it into Jac.loaded_modules so the introspector skips its own jac_import, and
constructs a stdlib HTTPServer directly with the request handler from
JacAPIServer.create_handler() — bypassing the create_server plugin hook so
the ejected app is independent of which jaclang plugins happen to be
installed in the runtime environment.
"""
def _emit_serve_py(backend_dir: Path, entry_module: str) {
    lines: list[str] = [
        '"""Auto-generated entry point for ejected Jac application.',
        '',
        'Loads the ejected Python modules and serves them with the jaclang HTTP',
        'request handler. Requires `jaclang` to be installed in the active Python',
        'environment.',
        '',
        'This script deliberately bypasses two jaclang plugin hooks so the ejected',
        'app behaves consistently regardless of which plugins happen to be',
        'installed in the runtime environment:',
        '',
        '  1. `Jac.get_user_manager` is forced to the base SQLite-backed',
        '     `UserManager` so register/login/auth use the local backend/.jac/data',
        '     directory. Without this, plugins like jac-scale would substitute a',
        '     cloud-backed user store and reject the local tokens.',
        '  2. The HTTP transport is built directly with `http.server.HTTPServer`',
        '     instead of going through `Jac.create_server`, which plugins like',
        '     jac-scale override with their own (incompatible) FastAPI server.',
        '"""',
        'import os',
        'import sys',
        'import importlib.util',
        'from http.server import HTTPServer',
        '',
        'HERE = os.path.dirname(os.path.abspath(__file__))',
        'if HERE not in sys.path:',
        '    sys.path.insert(0, HERE)',
        '',
        'from jaclang.jac0core.runtime import JacRuntime as Jac',
        'from jaclang.runtimelib.server import JacAPIServer, UserManager',
        '',
        '# Force the base UserManager. Must happen BEFORE JacAPIServer is',
        '# constructed, because postinit calls Jac.get_user_manager().',
        'Jac.get_user_manager = lambda base_path: UserManager(base_path=base_path)',
        '',
        f'ENTRY_MODULE = "{entry_module}"',
        'PORT = int(os.environ.get("PORT", "8000"))',
        '',
        '',
        'def main() -> None:',
        '    entry_path = os.path.join(HERE, f"{ENTRY_MODULE}.py")',
        '    if not os.path.exists(entry_path):',
        '        raise SystemExit(f"Entry module not found: {entry_path}")',
        '',
        '    spec = importlib.util.spec_from_file_location(ENTRY_MODULE, entry_path)',
        '    module = importlib.util.module_from_spec(spec)',
        '    sys.modules[ENTRY_MODULE] = module',
        '    spec.loader.exec_module(module)',
        '',
        '    # Pre-populate Jac.loaded_modules so the introspector skips jac_import.',
        '    Jac.loaded_modules[ENTRY_MODULE] = module',
        '',
        '    server = JacAPIServer(module_name=ENTRY_MODULE, port=0, base_path=HERE)',
        '    server.port = PORT',
        '',
        '    # Build the HTTP server directly so we bypass create_server plugin hooks.',
        '    handler_class = server.create_handler()',
        '    httpd = HTTPServer(("0.0.0.0", PORT), handler_class)',
        '    server.server = httpd',
        '',
        '    server.introspector.load(force_reload=False)',
        '    walkers = list(server.get_walkers().keys())',
        '    functions = list(server.get_functions().keys())',
        '',
        '    print(f"Ejected Jac server listening on http://0.0.0.0:{PORT}")',
        '    print(f"  Module:    {ENTRY_MODULE}")',
        '    print(f"  Walkers:   {walkers}")',
        '    print(f"  Functions: {functions}")',
        '    print()',
        '    print("Press Ctrl+C to stop the server")',
        '',
        '    try:',
        '        httpd.serve_forever()',
        '    except KeyboardInterrupt:',
        '        print("\\nShutting down...")',
        '    finally:',
        '        httpd.server_close()',
        '',
        '',
        'if __name__ == "__main__":',
        '    main()',
        ''
    ];
    (backend_dir / "serve.py").write_text("\n".join(lines), encoding="utf-8");
}


"""Write frontend/package.json mapping jac.toml [dependencies.npm] to npm."""
def _emit_package_json(frontend_dir: Path, project_name: str, toml_data: dict) {
    npm_deps_root = toml_data.get("dependencies", {}).get("npm", {});
    deps: dict[str, str] = {};
    dev_deps: dict[str, str] = {};
    for (k, v) in npm_deps_root.items() {
        if k == "dev" {
            if isinstance(v, dict) {
                for (dk, dv) in v.items() {
                    if isinstance(dv, str) {
                        dev_deps[dk] = dv;
                    }
                }
            }
        } elif isinstance(v, str) {
            deps[k] = v;
        }
    }
    # Always ensure vite is available so `npm run dev` works out of the box.
    if "vite" not in dev_deps and "vite" not in deps {
        dev_deps["vite"] = "^5.0.0";
    }
    pkg = {
        "name": project_name.lower().replace("_", "-").replace(" ", "-"),
        "version": "0.1.0",
        "private": True,
        "type": "module",
        "scripts": {"dev": "vite", "build": "vite build", "preview": "vite preview"},
        "dependencies": deps,
        "devDependencies": dev_deps
    };
    (frontend_dir / "package.json").write_text(
        json.dumps(pkg, indent=2) + "\n", encoding="utf-8"
    );
}


"""Write frontend/vite.config.js with a proxy to the backend API.

Vite serves the static frontend on its dev server port; all requests under
/walker, /function, /user, /cl, /functions, /walkers are forwarded to the
backend so the SPA can talk to the ejected serve.py without any CORS
plumbing in the user's code.
"""
def _emit_vite_config(frontend_dir: Path) {
    lines: list[str] = [
        '/** @type {import("vite").UserConfig} */',
        'export default {',
        '  server: {',
        '    proxy: {',
        '      "/walker":    "http://localhost:8000",',
        '      "/walkers":   "http://localhost:8000",',
        '      "/function":  "http://localhost:8000",',
        '      "/functions": "http://localhost:8000",',
        '      "/user":      "http://localhost:8000",',
        '      "/cl":        "http://localhost:8000"',
        '    }',
        '  }',
        '};',
        ''
    ];
    (frontend_dir / "vite.config.js").write_text("\n".join(lines), encoding="utf-8");
}


"""Write a minimal frontend/index.html that bootstraps src/main.js."""
def _emit_index_html(frontend_dir: Path, project_name: str) {
    lines: list[str] = [
        '<!doctype html>',
        '<html lang="en">',
        '  <head>',
        '    <meta charset="UTF-8" />',
        '    <meta name="viewport" content="width=device-width, initial-scale=1.0" />',
        f'    <title>{project_name}</title>',
        '  </head>',
        '  <body>',
        '    <div id="app"></div>',
        '    <script type="module" src="/src/main.js"></script>',
        '  </body>',
        '</html>',
        ''
    ];
    (frontend_dir / "index.html").write_text("\n".join(lines), encoding="utf-8");
}


"""Write run.sh that boots both the backend and the frontend dev server."""
def _emit_run_script(out: Path) {
    lines: list[str] = [
        '#!/usr/bin/env bash',
        '# Auto-generated run script for ejected Jac project.',
        '# Starts the backend on PORT (default 8000) and the frontend Vite dev',
        '# server on FRONTEND_PORT (default 5173).',
        'set -e',
        '',
        'HERE="$(cd "$(dirname "$0")" && pwd)"',
        ': "${PORT:=8000}"',
        ': "${FRONTEND_PORT:=5173}"',
        '',
        'cleanup() {',
        '  if [[ -n "${BACKEND_PID:-}" ]]; then kill "$BACKEND_PID" 2>/dev/null || true; fi',
        '  if [[ -n "${FRONTEND_PID:-}" ]]; then kill "$FRONTEND_PID" 2>/dev/null || true; fi',
        '}',
        'trap cleanup EXIT',
        '',
        'echo "Starting backend on http://localhost:$PORT"',
        '(cd "$HERE/backend" && PORT="$PORT" python serve.py) &',
        'BACKEND_PID=$!',
        '',
        'if [[ -d "$HERE/frontend/node_modules" ]]; then',
        '  echo "Starting frontend on http://localhost:$FRONTEND_PORT"',
        '  (cd "$HERE/frontend" && npm run dev -- --port "$FRONTEND_PORT") &',
        '  FRONTEND_PID=$!',
        'else',
        '  echo "(frontend/node_modules missing - run \\"cd frontend && npm install\\" first)"',
        'fi',
        '',
        'wait',
        ''
    ];
    out_path = out / "run.sh";
    out_path.write_text("\n".join(lines), encoding="utf-8");
    try {
        import os;
        os.chmod(out_path, 0o755);
    } except Exception {
        pass;
    }
}


"""Write a README explaining how to run the ejected project."""
def _emit_readme(out: Path, project_name: str, entry_module: str) {
    lines: list[str] = [
        f"# {project_name} (ejected)",
        "",
        "This project was generated by `jac eject`. It contains zero `.jac` files -",
        "every Jac source has been compiled to plain Python (backend) or JavaScript",
        "(frontend). It still depends on the `jaclang` Python package at runtime for",
        "walker dispatch, the HTTP request handler, auth, and persistence.",
        "",
        "## Layout",
        "",
        "```",
        "backend/",
        "  serve.py            entry script (python serve.py)",
        "  requirements.txt    pip dependencies (includes jaclang)",
        f"  {entry_module}.py             ejected entry module",
        "  ...                 other ejected modules",
        "frontend/",
        "  package.json        npm dependencies",
        "  vite.config.js      Vite dev server with backend proxy",
        "  index.html          SPA shell",
        "  src/                ejected JavaScript modules",
        "run.sh                start backend + frontend dev server",
        "```",
        "",
        "## Run it",
        "",
        "```bash",
        "pip install -r backend/requirements.txt",
        "(cd frontend && npm install)",
        "./run.sh",
        "```",
        "",
        "Then open the URL printed by the Vite dev server (usually",
        "<http://localhost:5173>). API requests are proxied to the backend on",
        "port 8000.",
        "",
        "## Caveats",
        "",
        "- This first-version eject still requires `jaclang` to be installed -",
        "  the ejected Python imports `jaclang.jac0core.jaclib` (walker/node",
        "  primitives) and `jaclang.runtimelib.server` (HTTP handler, auth).",
        "- Persistent state (users, root nodes) lives wherever the jaclang",
        "  runtime puts it by default. Set the relevant environment variables",
        "  before running `serve.py` if you need to point it elsewhere.",
        "- The frontend uses `@jac/runtime` (from the `jac-client-node` npm",
        "  package). Make sure that dependency stays in `frontend/package.json`.",
        ""
    ];
    (out / "README.md").write_text("\n".join(lines), encoding="utf-8");
}
