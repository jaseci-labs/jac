"""Implementation of the `jac eject` command.

Eject takes a Jac project and produces a standalone, zero-jaclang app in a
project-internal `ejected/` folder: a FastAPI `backend/` (walkers and
functions compiled to Python that imports a vendored `_osp.py` runtime instead
of jaclang) and a `frontend/` (the `.cl.jac` UI compiled to JavaScript with a
Vite setup). The result runs with only fastapi + uvicorn (backend) and the
project's npm deps (frontend); no Jac toolchain or jaclang install is needed.

The FastAPI-specific emission lives in `eject_targets/backend.jac`; this module
orchestrates the compile pass and emits the frontend half.
"""

import shutil;
import json;
import from pathlib { Path }
import from jaclang.cli.console { console }

# File-suffix and skip-dir constants shared by the collection/compile pass.
glob _SV_SUFFIX: str = ".sv.jac",
     _CL_SUFFIX: str = ".cl.jac",
     _IMPL_SUFFIX: str = ".impl.jac",
     _TEST_SUFFIX: str = ".test.jac",
     # Directories never traversed when collecting source files.
     _SKIP_DIRS: set = {
         ".jac",
         ".git",
         ".venv",
         "venv",
         "node_modules",
         "__pycache__",
         ".mypy_cache",
         ".pytest_cache",
         "dist",
         "build"
     };


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
    import from jaclang.jac0core.helpers { read_toml_with_encoding }
    toml_data = read_toml_with_encoding(str(toml_path));
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


"""Eject a Jac project to a standalone, zero-jaclang app.

Produces a project-internal `ejected/` folder split into `backend/` (a FastAPI
app compiled from the Jac walkers/functions, importing a vendored `_osp.py`
runtime instead of jaclang) and `frontend/` (the `.cl.jac` UI compiled to
JavaScript). Re-runnable without `--force` when the output carries our marker.
"""
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

    # Output lives inside the project (default `ejected/`, overridable via
    # `[eject].output` in jac.toml or the -o flag).
    eject_cfg = toml_data.get("eject", {});
    if output {
        out = Path(output).resolve();
    } else {
        out = (src / str(eject_cfg.get("output", "ejected"))).resolve();
    }
    if out == src {
        console.error("Output directory cannot be the same as the source directory.");
        return 1;
    }

    # Re-runnable: regenerate freely when the directory is ours (carries the
    # marker) or --force is given; never clobber a directory we did not create.
    marker = out / ".jac-ejected";
    if out.exists() {
        if force or marker.exists() {
            try {
                shutil.rmtree(out);
            } except Exception as e {
                console.error(f"Failed to remove existing output directory: {e}");
                return 1;
            }
        } else {
            console.error(f"Output directory already exists: {out}");
            console.print(
                "  It was not created by eject. Use --force to overwrite.",
                style="muted"
            );
            return 1;
        }
    }

    out.mkdir(parents=True);
    backend_dir = out / "backend";
    frontend_dir = out / "frontend";
    frontend_src_dir = frontend_dir / "src";
    backend_dir.mkdir(parents=True);
    frontend_src_dir.mkdir(parents=True);

    console.print(f"\n📦 Ejecting '{project_name}' → standalone app", style="bold cyan");
    console.print(f"  Source: {src}");
    console.print(f"  Output: {out}\n");

    # Collect sources, skipping anything inside the (project-internal) output.
    jac_files = [f for f in _collect_jac_files(src) if out not in Path(str(f)).parents];
    if not jac_files {
        console.error("No .jac source files found to eject.");
        return 1;
    }

    # Lazily import the compiler and AST surface — expensive at CLI startup.
    import from jaclang.jac0core.program { JacProgram }
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { SymbolType }

    js_count = 0;
    error_count = 0;
    reserved: set = {"main", "_osp"};
    compiled: list = [];
    remap: dict = {};
    walkers: list = [];
    functions: list = [];
    for jac_file in jac_files {
        rel = Path(str(jac_file)).relative_to(src);
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

        # Frontend half: compiled JavaScript (.cl.jac and cl {} blocks).
        if js_code.strip() {
            js_rel = _to_js_rel_path(rel);
            js_out = frontend_src_dir / js_rel;
            js_out.parent.mkdir(parents=True, exist_ok=True);
            js_out.write_text(_inject_runtime_imports(js_code), encoding="utf-8");
            js_count += 1;
        }

        # Backend half: server-side Python only. A `.cl.jac` file is
        # client-only — the compiler still emits Python for it, but that is a
        # frontend artifact (its `app`/components are not API endpoints), so it
        # never goes to the backend. Pick the emitted module name, renaming any
        # collision with a generated file (main/_osp).
        stem = str(_strip_jac_suffix(rel.name));
        bmod = stem;
        if stem in reserved {
            bmod = f"_jac_{stem}";
            remap[stem] = bmod;
        }
        is_client = rel.name.endswith(_CL_SUFFIX);
        server = _is_meaningful_python(py_code) and (not is_client);

        if server {
            for item in ir.body {
                if isinstance(item, uni.Archetype)
                and item.sym_category == SymbolType.WALKER_ARCH {
                    walkers.append({
                        "name": str(item.name.sym_name), "module": bmod
                    });
                } elif isinstance(item, uni.Ability) and item.name_ref is not None {
                    functions.append({
                        "name": str(item.name_ref.sym_name), "module": bmod
                    });
                }
            }
        }
        compiled.append({"module": bmod, "py": py_code, "server": server});
        console.print(f"  ✔ {rel}", style="success");
    }

    if error_count > 0 {
        console.error(
            f"\n{error_count} file(s) failed to compile. Output is incomplete."
        );
        return 1;
    }

    # Backend: FastAPI app + vendored runtime (delegated to the target emitter).
    import from jaclang.cli.commands.eject_targets.backend { emit_backend }
    rc = emit_backend(backend_dir, project_name, compiled, walkers, functions, remap);
    if rc != 0 {
        return rc;
    }

    # Frontend: vendor the client runtime and emit the Vite/React boilerplate
    # (the Vite dev server proxies /walker and /function to the FastAPI backend).
    runtime_copied = _copy_client_runtime(src, frontend_dir);
    _emit_package_json(frontend_dir, project_name, toml_data);
    _emit_vite_config(frontend_dir, runtime_copied);
    _emit_entry_js(frontend_src_dir, entry_module);
    _emit_index_html(frontend_dir, project_name);

    marker.write_text(
        "Generated by `jac eject`. Safe to delete.\n", encoding="utf-8"
    );

    console.print();
    console.success(f"Ejected '{project_name}' → {out}");
    console.print(
        f"  backend: {len(walkers)} walker(s), {len(functions)} function(s)"
        f"   frontend: {js_count} JS module(s)",
        style="muted"
    );
    console.print();
    console.print("Next steps:", style="bold");
    console.print(f"  cd {out}");
    console.print("  (cd frontend && npm install && npm run build)");
    console.print("  cd backend && pip install -r requirements.txt && uvicorn main:app");
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
"""Map a project-relative .jac path to its ejected .js path."""
def _to_js_rel_path(rel: Path) -> Path {
    return rel.parent / (_strip_jac_suffix(rel.name) + ".js");
}


"""True iff the given AST node carries a `:pub` access modifier.

Matches the `is_public` helper inside the runtime's access-level extractor
(ModuleIntrospector._extract_access_levels in server.impl.jac) so eject's
pre-computed access sets classify walkers and abilities exactly the way
the normal `jac start` path would — otherwise a walker that's public in
source would end up gated at runtime.
"""
"""Prepend the runtime-global import the client compiler relies on.

`gen.js` emits `__jacJsx` / `__jacSpawn` as free identifiers; without the
covering import the ejected frontend throws `__jacJsx is not defined` on first
render. Shares the one canonical prepend with the jac2js build, HMR, and the cl
test harness -- see `with_runtime_globals`.
"""
def _inject_runtime_imports(js_code: str) -> str {
    import from jaclang.runtimelib.client_surface { with_runtime_globals }
    return with_runtime_globals(js_code);
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

Pins jaclang to its current version so the ejected backend can use the
runtime helpers it imports (jaclang.jac0core.jaclib, jaclang.runtimelib.server,
...) and so a `pip install` produces the same runtime the project was
ejected against.

Also scans the emitted backend .py files for `from <pkg>` / `import <pkg>`
references to well-known jaclang companion packages (byllm, jac-cloud, ...)
that aren't declared in jac.toml because they're implicit plugin deps, and
adds them automatically so `python serve.py` doesn't ImportError.
"""
"""Resolve the version spec to pin jaclang to in requirements.txt.

Reads `jaclang.__version__` from the running interpreter so the ejected
backend reinstalls the same jaclang the project was ejected against. Falls
back to an unpinned `jaclang` line if the version attribute is missing, so
eject still produces a working (if unreproducible) requirements.txt even
in edge cases where jaclang was imported via an unusual path.
"""
"""Scan emitted backend .py files for imports of known jaclang plugins.

Jaclang ships some functionality as separate pypi packages (byllm for LLM
integration, jac-cloud for cloud persistence, ...). The compiled Python
just does `from byllm.types import ...` / `import byllm` — there is no
marker distinguishing these from any other Python import. The user's
jac.toml rarely lists them because they're pulled in implicitly by the
jaclang toolchain. We detect them post-codegen and add to requirements so
the ejected app runs without a follow-up `pip install byllm` step.

Returns a sorted list of pypi package names to add.
"""
"""Write the serve.py entry script for the ejected backend.

The script loads the entry module via importlib (no Jac compilation), stuffs
it into Jac.loaded_modules so the introspector skips its own jac_import, and
constructs a stdlib HTTPServer directly with the request handler from
JacAPIServer.create_handler() — bypassing the create_server plugin hook so
the ejected app is independent of which jaclang plugins happen to be
installed in the runtime environment.
"""
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

When `runtime_copied` is True, also emits a resolve.alias mapping the
"@jac/runtime" bare specifier (hardcoded throughout the compiled frontend
JS) to the local `src/__jac_runtime.js` we wrote alongside the frontend.
This is what allows the ejected SPA to load in the browser without
depending on the `jac-client-node` meta-package or the Jac build.
"""
def _emit_vite_config(frontend_dir: Path, runtime_copied: bool) {
    # Proxy target honours $BACKEND_PORT (set by run.sh from $PORT) so a
    # custom backend port flows through to the Vite proxy without the user
    # having to edit vite.config.js. Falls back to 8000 for parity with
    # run.sh's own default when neither env var is set.
    header: list[str] = [
        'import path from "path";',
        'import { fileURLToPath } from "url";',
        '',
        'const __dirname = path.dirname(fileURLToPath(import.meta.url));',
        'const _backendPort = process.env.BACKEND_PORT || "8000";',
        'const _backend = `http://localhost:${_backendPort}`;',
        '',
        '/** @type {import("vite").UserConfig} */',
        'export default {',

    ];
    resolve_block: list[str] = [];
    if runtime_copied {
        resolve_block = [
            '  resolve: {',
            '    alias: {',
            '      "@jac/runtime": path.resolve(__dirname, "src/__jac_runtime.js")',
            '    }',
            '  },',

        ];
    }
    server_block: list[str] = [
        '  server: {',
        '    proxy: {',
        '      "/walker":    _backend,',
        '      "/walkers":   _backend,',
        '      "/function":  _backend,',
        '      "/functions": _backend,',
        '      "/user":      _backend,',
        '      "/cl":        _backend',
        '    }',
        '  }',
        '};',
        ''
    ];
    lines: list[str] = header + resolve_block + server_block;
    (frontend_dir / "vite.config.js").write_text("\n".join(lines), encoding="utf-8");
}


"""Copy every non-.jac source file into backend/ and frontend/src/.

The ejected backend Python and the ejected frontend JavaScript both keep
reading files from the project tree at runtime (e.g. `services/config/*.json`
from the RAG engine, `./global.css` and `../styles/*.css` from components).
Eject's codegen only produces .py and .js files; without copying the rest,
every project with any config or static resource blows up the moment it
runs. Mirroring the tree into both halves is cheap and avoids having to
guess which file belongs to which half.

Exclusions: files in _SKIP_DIRS (jac build cache, node_modules, virtualenvs,
...), hidden directories (anything starting with "."), the .jac source
files themselves (compile handles those), and the project's jac.toml (not
needed at runtime).

`public/` is treated specially: Vite expects it at the frontend project
root, not under src/, so we copy `public/*` to `frontend/public/` rather
than duplicating into `frontend/src/public/`.
"""
"""Copy the Jac client runtime bundle produced by the Jac client build.

`@jac/runtime` is a bare-specifier import baked into every compiled .cl.jac
module (jacIsLoggedIn, __jacCallFunction, Router, useNavigate, ...). During
normal `jac start`, Vite resolves it via an alias pointing at
`.jac/client/compiled/client_runtime.js`. The ejected frontend cannot rely
on that build dir (it's excluded from the output by design), so we copy
the compiled runtime into the ejected tree and alias to it in vite.config.js.

Returns True if the runtime was copied. Callers use this to decide whether
to emit the resolve.alias in vite.config.js; projects that never built a
client (no `.jac/client/compiled/client_runtime.js`) still eject, they just
warn at build-time that `@jac/runtime` will be unresolved until the user
brings their own runtime or re-runs `jac install` before ejecting.
"""
def _copy_client_runtime(src: Path, frontend_root: Path) -> bool {
    runtime_src = src / ".jac" / "client" / "compiled" / "client_runtime.js";
    if not runtime_src.exists() {
        console.warning(
            "  No .jac/client/compiled/client_runtime.js found; "
            "@jac/runtime imports will be unresolved. "
            "Run `jac install` (or any `jac start`) before `jac eject` "
            "to build the client runtime."
        );
        return False;
    }
    dest = frontend_root / "src" / "__jac_runtime.js";
    dest.parent.mkdir(parents=True, exist_ok=True);
    try {
        shutil.copy2(runtime_src, dest);
    } except Exception as e {
        console.warning(f"Failed to copy client_runtime.js: {e}");
        return False;
    }
    # The client runtime sometimes emits a sibling .map file; copy it too.
    map_src = runtime_src.with_suffix(".js.map");
    if map_src.exists() {
        try {
            shutil.copy2(map_src, dest.with_suffix(".js.map"));
        } except Exception {
            # Best-effort; missing source map doesn't break the app.
            _ = 0;
        }
    }
    console.print("  ✔ @jac/runtime", style="success");
    return True;
}


"""Write a minimal frontend/index.html that bootstraps the ejected SPA.

Uses `<div id="root"></div>` to match the mount node the client runtime
and generated __jac_entry.js target. Loads __jac_entry.js (not main.js
directly) so eject controls the React bootstrap — main.js only exports
the `app` component.
"""
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
        '    <div id="root"></div>',
        '    <script type="module" src="/src/__jac_entry.js"></script>',
        '  </body>',
        '</html>',
        ''
    ];
    (frontend_dir / "index.html").write_text("\n".join(lines), encoding="utf-8");
}


"""Write the SPA bootstrap (__jac_entry.js) that mounts the ejected app.

The Jac client compiler emits a per-module main.js that *exports* an `app`
component but never renders it — the Jac build's auto-generated _entry.js
handles createRoot. Eject is that _entry.js' substitute: it imports the
entry module's `app`, wraps it in the runtime's ErrorBoundary, and calls
createRoot against <div id="root">. Without this, `vite dev` serves the
files and 200s cleanly, but the page stays blank.
"""
def _emit_entry_js(frontend_src_dir: Path, entry_module: str) {
    import from jaclang.runtimelib.react_entry { build_simple_react_entry_script }
    (frontend_src_dir / "__jac_entry.js").write_text(
        build_simple_react_entry_script(entry_module), encoding="utf-8"
    );
}


"""Write run.sh that boots both the backend and the frontend dev server."""
"""Write a README explaining how to run the ejected project."""