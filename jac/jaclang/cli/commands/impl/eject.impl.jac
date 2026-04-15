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
import re;
import from pathlib { Path }
import from typing { Any }
import from jaclang.cli.console { console }

# Python imports in the ejected backend that pull in a jaclang "companion"
# package not covered by the user's jac.toml [dependencies]. Eject auto-adds
# these to requirements.txt so `pip install` produces a runnable backend.
glob _IMPLICIT_PY_DEPS: dict[str, str] = {
         "byllm": "byllm",
         "jac_cloud": "jac-cloud",
         "jac_client": "jac-client",

     };

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

    # Imports needed to classify walkers/defs as public vs private from the
    # AST. These modules are expensive to pull in at CLI-startup time, so
    # we defer them to the eject path.
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { Tokens as Tok, SymbolType }

    py_count = 0;
    js_count = 0;
    error_count = 0;
    entry_rel = Path(entry_point);
    emitted_py_files: list[Path] = [];
    public_walkers: set[str] = set();
    public_functions: set[str] = set();
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

        # The entry module must always be emitted even when its Python body
        # is nothing but imports (e.g. a root main.jac that only pulls in
        # walkers from sub-packages and declares a cl {} block): serve.py
        # imports it by name to register those walkers/functions.
        is_entry = rel == entry_rel;

        # Harvest access modifiers (`:pub` / default) for every walker and
        # module-level ability the file declares. The runtime's access-check
        # path (ModuleIntrospector._extract_access_levels) normally reads
        # these straight off the Jac AST at request time — but the ejected
        # backend only ships compiled Python, so we seed the sets here and
        # wire them into serve.py below.
        for item in ir.body {
            if isinstance(item, uni.Archetype)
            and item.sym_category == SymbolType.WALKER_ARCH
            and _has_pub_access(item) {
                public_walkers.add(item.name.sym_name);
            } elif isinstance(item, uni.Ability)
            and item.name_ref is not None
            and _has_pub_access(item) {
                public_functions.add(item.name_ref.sym_name);
            }
        }

        wrote_any = False;
        if _is_meaningful_python(py_code) or (is_entry and py_code.strip()) {
            py_rel = _to_py_rel_path(rel);
            py_out = backend_dir / py_rel;
            py_out.parent.mkdir(parents=True, exist_ok=True);
            py_out.write_text(py_code, encoding="utf-8");
            py_count += 1;
            emitted_py_files.append(py_out);
            wrote_any = True;
        }
        if js_code.strip() {
            js_rel = _to_js_rel_path(rel);
            js_out = frontend_src_dir / js_rel;
            js_out.parent.mkdir(parents=True, exist_ok=True);
            js_out.write_text(_inject_runtime_imports(js_code), encoding="utf-8");
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

    # Copy every non-.jac source file into both backend/ and frontend/src/
    # so paths referenced by the compiled Python (e.g. services/config/*.json,
    # services/docs/*.md) and by the compiled JavaScript (e.g. ./global.css,
    # ../styles/*.css) resolve at runtime without per-project bookkeeping.
    _copy_data_files(src, backend_dir, frontend_src_dir, out / "frontend");

    # Copy the client runtime emitted by the Jac client build so the ejected
    # frontend can resolve imports from "@jac/runtime" without depending on
    # the external `jac-client-node` meta-package or the Jac build toolchain.
    runtime_copied = _copy_client_runtime(src, out / "frontend");

    # Generate boilerplate.
    _emit_requirements_txt(backend_dir, toml_data, emitted_py_files);
    _emit_serve_py(backend_dir, entry_module, public_walkers, public_functions);
    _emit_package_json(out / "frontend", project_name, toml_data);
    _emit_vite_config(out / "frontend", runtime_copied);
    _emit_entry_js(frontend_src_dir, entry_module);
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


"""True iff the given AST node carries a `:pub` access modifier.

Matches the `is_public` helper inside the runtime's access-level extractor
(ModuleIntrospector._extract_access_levels in server.impl.jac) so eject's
pre-computed access sets classify walkers and abilities exactly the way
the normal `jac start` path would — otherwise a walker that's public in
source would end up gated at runtime.
"""
def _has_pub_access(ast_item: Any) -> bool {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { Tokens as Tok }
    if not isinstance(ast_item, uni.AstAccessNode) {
        return False;
    }
    access = getattr(ast_item, "access", None);
    if access is None {
        return False;
    }
    tag = getattr(access, "tag", None);
    if tag is None {
        return False;
    }
    return getattr(tag, "name", None) == Tok.KW_PUB;
}


"""Prepend the `@jac/runtime` import the Jac client compiler injects.

The raw JS code emitted by `JacProgram.compile(...).gen.js` uses `__jacJsx`
and `__jacSpawn` as free identifiers — the normal `jac-client` build path
injects `import {__jacJsx, __jacSpawn} from "@jac/runtime";` at the top
of every compiled module after codegen. Without that import the ejected
frontend boots but throws `__jacJsx is not defined` the moment it tries
to render any JSX, so eject replicates the same post-processing step.

The runtime itself defines `__jacJsx` — we detect that case by the
function definition signature and skip the injection to avoid a circular
import.
"""
def _inject_runtime_imports(js_code: str) -> str {
    if "function __jacJsx(" in js_code {
        return js_code;
    }
    return 'import {__jacJsx, __jacSpawn} from "@jac/runtime";\n' + js_code;
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
def _emit_requirements_txt(
    backend_dir: Path, toml_data: dict, emitted_py_files: list[Path]
) {
    deps = toml_data.get("dependencies", {});
    # Filter out the npm subsection (it's a sibling key, not a python dep).
    py_deps: dict[str, str] = {};
    for (k, v) in deps.items() {
        if isinstance(v, str) {
            py_deps[k] = v;
        }
    }
    lines: list[str] = [_jaclang_pin()];
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
    declared = {name for name in py_deps};
    for plugin_pkg in _detect_implicit_plugins(emitted_py_files) {
        # Normalise: both `jac-cloud` and `jac_cloud` should be considered
        # already-declared if the user happened to pin either spelling.
        if plugin_pkg in declared or plugin_pkg.replace("-", "_") in declared {
            continue;
        }
        lines.append(plugin_pkg);
    }
    (backend_dir / "requirements.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    );
}


"""Resolve the version spec to pin jaclang to in requirements.txt.

Reads `jaclang.__version__` from the running interpreter so the ejected
backend reinstalls the same jaclang the project was ejected against. Falls
back to an unpinned `jaclang` line if the version attribute is missing, so
eject still produces a working (if unreproducible) requirements.txt even
in edge cases where jaclang was imported via an unusual path.
"""
def _jaclang_pin -> str {
    version = "";
    try {
        import jaclang;
        version = getattr(jaclang, "__version__", "") or "";
    } except Exception {
        version = "";
    }
    if not version {
        try {
            import from importlib.metadata { version as _pkg_version }
            version = _pkg_version("jaclang") or "";
        } except Exception {
            version = "";
        }
    }
    if version {
        return f"jaclang=={version}";
    }
    return "jaclang";
}


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
def _detect_implicit_plugins(emitted_py_files: list[Path]) -> list[str] {
    pattern = re.compile(r"^\s*(?:from|import)\s+([A-Za-z_][A-Za-z0-9_]*)");
    found: set[str] = set();
    for py_path in emitted_py_files {
        text = "";
        try {
            text = py_path.read_text(encoding="utf-8");
        } except Exception {
            text = "";
        }
        for line in text.splitlines() {
            mo = pattern.match(line);
            if not mo {
                continue;
            }
            top = mo.group(1);
            if top in _IMPLICIT_PY_DEPS {
                found.add(_IMPLICIT_PY_DEPS[top]);
            }
        }
    }
    return sorted(list(found));
}


"""Write the serve.py entry script for the ejected backend.

The script loads the entry module via importlib (no Jac compilation), stuffs
it into Jac.loaded_modules so the introspector skips its own jac_import, and
constructs a stdlib HTTPServer directly with the request handler from
JacAPIServer.create_handler() — bypassing the create_server plugin hook so
the ejected app is independent of which jaclang plugins happen to be
installed in the runtime environment.
"""
def _emit_serve_py(
    backend_dir: Path,
    entry_module: str,
    public_walkers: set[str],
    public_functions: set[str]
) {
    # Sort for deterministic output — the sets would otherwise reorder
    # between eject runs, producing noisy diffs in the ejected serve.py.
    walker_literal = (
        "{" + ", ".join(f'"{n}"' for n in sorted(list(public_walkers))) + "}"
    );
    function_literal = (
        "{" + ", ".join(f'"{n}"' for n in sorted(list(public_functions))) + "}"
    );
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
        '',
        'PUBLIC_WALKERS / PUBLIC_FUNCTIONS are seeded from the original Jac AST',
        'by eject and used to rehydrate ModuleIntrospector._walker_access /',
        '_function_access after load(). The introspector normally recomputes',
        'these by re-parsing the Jac sources, but the ejected backend has none',
        'of those — without this step every `:pub` walker would return 401.',
        '"""',
        'import os',
        'import sys',
        'import json',
        'import types',
        'import asyncio',
        'import importlib.util',
        'from http.server import HTTPServer',
        '',
        'HERE = os.path.dirname(os.path.abspath(__file__))',
        'if HERE not in sys.path:',
        '    sys.path.insert(0, HERE)',
        '',
        '',
        'from jaclang.jac0core.runtime import JacRuntime as Jac',
        'from jaclang.runtimelib.server import JacAPIServer, UserManager',
        'from jaclang.runtimelib.transport import HTTPTransport',
        '',
        '# Walkers that stream (e.g. an LLM-backed RAG chat) return a',
        '# generator of SSE-formatted chunks. The base jaclang HTTPTransport',
        '# always json.dumps() the response body, which raises TypeError the',
        '# moment a generator lands inside `response.data`. In `jac start`',
        '# the jac-scale FastAPI plugin catches that and streams SSE; the',
        '# ejected backend runs on stdlib HTTPServer so we patch the',
        '# transport here to write SSE bytes straight to the socket when the',
        '# response data is a generator and fall through to the default',
        '# JSON path otherwise.',
        '_orig_http_send = HTTPTransport.send',
        'def _streaming_http_send(self, data):',
        '    inner = getattr(data, "data", None)',
        '    if isinstance(inner, (types.GeneratorType, types.AsyncGeneratorType)):',
        '        handler = self.handler',
        '        handler.send_response(200)',
        '        handler.send_header("Content-Type", "text/event-stream")',
        '        handler.send_header("Cache-Control", "no-cache")',
        '        handler.send_header("X-Accel-Buffering", "no")',
        '        handler.send_header("Access-Control-Allow-Origin", "*")',
        '        handler.end_headers()',
        '        def _write_chunk(chunk):',
        '            if isinstance(chunk, (bytes, bytearray)):',
        '                handler.wfile.write(bytes(chunk))',
        '            elif isinstance(chunk, str):',
        '                handler.wfile.write(chunk.encode("utf-8"))',
        '            else:',
        '                payload = json.dumps(chunk)',
        '                handler.wfile.write(f"data: {payload}\\n\\n".encode("utf-8"))',
        '            handler.wfile.flush()',
        '        if isinstance(inner, types.AsyncGeneratorType):',
        '            async def _pump():',
        '                async for chunk in inner:',
        '                    _write_chunk(chunk)',
        '            try:',
        '                loop = asyncio.get_event_loop()',
        '            except RuntimeError:',
        '                loop = asyncio.new_event_loop()',
        '            if loop.is_running():',
        '                asyncio.run_coroutine_threadsafe(_pump(), loop).result()',
        '            else:',
        '                loop.run_until_complete(_pump())',
        '        else:',
        '            for chunk in inner:',
        '                _write_chunk(chunk)',
        '        self.response_data = None',
        '        return',
        '    return _orig_http_send(self, data)',
        'HTTPTransport.send = _streaming_http_send',
        '',
        '# Force the base UserManager. Must happen BEFORE JacAPIServer is',
        '# constructed, because postinit calls Jac.get_user_manager().',
        'Jac.get_user_manager = lambda base_path: UserManager(base_path=base_path)',
        '',
        f'ENTRY_MODULE = "{entry_module}"',
        'PORT = int(os.environ.get("PORT", "8000"))',
        f'PUBLIC_WALKERS = {walker_literal}',
        f'PUBLIC_FUNCTIONS = {function_literal}',
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
        '',
        '    # Rehydrate auth-level classification from eject-time metadata.',
        '    # _walker_access / _function_access map name -> auth-required,',
        '    # so :pub entries are set to False and anything else stays True.',
        '    introspector = server.introspector',
        '    for walker_name in server.get_walkers().keys():',
        '        introspector._walker_access[walker_name] = (',
        '            walker_name not in PUBLIC_WALKERS',
        '        )',
        '    for func_name in server.get_functions().keys():',
        '        introspector._function_access[func_name] = (',
        '            func_name not in PUBLIC_FUNCTIONS',
        '        )',
        '',
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
def _copy_data_files(
    src: Path, backend_dir: Path, frontend_src_dir: Path, frontend_root: Path
) {
    copied_tree = False;
    for path in src.rglob("*") {
        if not path.is_file() {
            continue;
        }
        rel = path.relative_to(src);
        rel_parts = list(rel.parts);
        excluded = False;
        for i in range(len(rel_parts) - 1) {
            part = rel_parts[i];
            if part in _SKIP_DIRS or part.startswith(".") {
                excluded = True;
                break;
            }
        }
        if excluded {
            continue;
        }
        # Hidden file at any depth (e.g. `.DS_Store`) — skip.
        if path.name.startswith(".") {
            continue;
        }
        if path.suffix == ".jac" {
            continue;
        }
        if str(rel) == "jac.toml" {
            continue;
        }
        # Vite-convention public dir lands at frontend root, not frontend/src.
        if rel_parts and rel_parts[0] == "public" {
            dest = frontend_root / rel;
            dest.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(path, dest);
            copied_tree = True;
            continue;
        }
        dest_backend = backend_dir / rel;
        dest_backend.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(path, dest_backend);
        dest_frontend = frontend_src_dir / rel;
        dest_frontend.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(path, dest_frontend);
        copied_tree = True;
    }
    if copied_tree {
        console.print("  ✔ resources/", style="success");
    }
}


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
    lines: list[str] = [
        'import React from "react";',
        'import { createRoot } from "react-dom/client";',
        f'import {{ app as App }} from "./{entry_module}.js";',
        'import { JacClientErrorBoundary, ErrorFallback, __jacInstallErrorHandlers } from "@jac/runtime";',
        '',
        '__jacInstallErrorHandlers();',
        'const root = createRoot(document.getElementById("root"));',
        'root.render(',
        '  React.createElement(',
        '    JacClientErrorBoundary,',
        '    { FallbackComponent: ErrorFallback },',
        '    React.createElement(App, null)',
        '  )',
        ');',
        ''
    ];
    (frontend_src_dir / "__jac_entry.js").write_text(
        "\n".join(lines), encoding="utf-8"
    );
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
        '  (cd "$HERE/frontend" && BACKEND_PORT="$PORT" npm run dev -- --port "$FRONTEND_PORT") &',
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
        "- `@jac/runtime` is vendored as `frontend/src/__jac_runtime.js` and",
        "  wired up via a resolve.alias in `frontend/vite.config.js` — no extra",
        "  npm package is needed. Re-run `jac install` in the original project",
        "  and re-eject if the runtime API changes.",
        ""
    ];
    (out / "README.md").write_text("\n".join(lines), encoding="utf-8");
}
