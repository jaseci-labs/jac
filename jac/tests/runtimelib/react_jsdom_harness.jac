"""Shared rig for the React jsdom behavioral suites.

`test_react_state_semantics.jac` and `test_react_auth_jsdom.jac` both compile
the real `@jac/runtime` shim to JS, mount it under jsdom, and assert the live
DOM. Everything up to "run the harness" is identical between them, so it lives
here rather than being copied per suite -- a third suite gets it for free.

Each suite still owns its own harness `.mjs`: the DOM bootstrap differs (the
auth suite starts at a per-scenario URL and seeds `jac_token`), and that is the
part that actually varies.
"""

import json;
import os;
import re;
import shutil;
import subprocess;
import from pathlib { Path }

import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { run_pass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.runtimelib.client_surface { with_runtime_globals }
import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }

# Mirrors `_default_client_deps("react")` runtime deps; jsdom is test-only.
glob REACT_JSDOM_DEPS: dict[str, str] = {
         "jsdom": "^24.0.0",
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0",
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     };

"""Skip unless the client toolchain integration flag is set."""
def require_client_integration(suite: str) {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        testskip(
            f"{suite} jsdom test does a real bun install; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

"""Compile a `.jac` to JS with the React backend; type errors are non-fatal.

`type_check=True` so typed builtin calls (e.g. `len(list)`) lower to their JS
forms, matching the production bundler pipeline."""
def compile_react(path: str) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(path), options=CompileOptions(type_check=True, no_cgen=True)
    );
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , f"compile errors in {path}: {[str(e) for e in fatal]}";
    es_pass = run_pass(EsastGenPass, ir, prog, backend=ReactBackend());
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

"""Point the shim's dotted core import at a flat sibling (mirrors the bundler)."""
def rewrite_core_specifier(runtime_js: str) -> str {
    m = re.search(r"""["'](\.[^"']*client_runtime_core\.js)["']""", runtime_js);
    if m {
        return runtime_js.replace(m.group(1), "./client_runtime_core.js");
    }
    return runtime_js;
}

"""Point `@jac/runtime` at the flat sibling the harness writes, as the bundler
resolves the virtual module."""
def wire_jac_runtime(js: str) -> str {
    for q in ['"', "'"] {
        js = js.replace(f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}");
    }
    return js;
}

"""Compile a page/layout/app `.jac`, prepend its `@jac/runtime` globals (the bare
`__jacJsx`), and wire the runtime specifier."""
def compile_page(path: str, backend: any) -> str {
    return wire_jac_runtime(with_runtime_globals(compile_react(path), backend));
}

"""Emit the compiled `@jac/runtime` shim + its core into the work dir."""
def write_runtime(work: Path) {
    runtime_path = resolve_client_runtime_cl_path("react");
    (work / "jac_runtime.js").write_text(
        rewrite_core_specifier(compile_react(runtime_path)), encoding="utf-8"
    );
    (work / "client_runtime_core.js").write_text(
        compile_react(str(Path(runtime_path).parent / "client_runtime_core.jac")),
        encoding="utf-8"
    );
}

"""`bun install` the shared dep set into `work`."""
def bun_install(bun: str, work: Path, name: str) {
    (work / "package.json").write_text(
        json.dumps(
            {
                "name": name,
                "private": True,
                "type": "module",
                "dependencies": REACT_JSDOM_DEPS
            }
        ),
        encoding="utf-8"
    );
    install = subprocess.run(
        [bun, "install"], cwd=str(work), capture_output=True, text=True, timeout=300
    );
    assert install.returncode == 0 , (
        f"bun install failed (exit {install.returncode}):\n"
        f"{install.stdout}\n{install.stderr}"
    );
}

"""Run `work/harness.mjs` once, with `args` appended, and assert it exited 0.

Prefers a real `node` when present; falls back to `bun run`."""
def run_harness(bun: str, work: Path, args: list, label: str) {
    node_bin = shutil.which("node");
    if node_bin {
        cmd = [node_bin, str(work / "harness.mjs")] + args;
    } else {
        cmd = [bun, "run", str(work / "harness.mjs")] + args;
    }
    run = subprocess.run(
        cmd, cwd=str(work), capture_output=True, text=True, timeout=120
    );
    detail = (run.stdout or "") + "\n" + (run.stderr or "");
    assert run.returncode == 0 , (
        f"{label} harness failed (exit {run.returncode}):\n{detail}"
    );
}
