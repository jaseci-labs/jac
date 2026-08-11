"""jsdom behavioral tests: the client state read-your-writes contract on React.

The codegen tests (`tests/compiler/passes/ecmascript/test_state_store_lowering.jac`)
pin what the react/preact backends *emit*; this suite executes it. It compiles
the shared state-semantics fixture plus the real `@jac/runtime` shim to JS,
mounts the component with `react-dom/client` in a jsdom DOM, and asserts each
face of the contract live:

  Face A -- a `can with entry` ability that writes `flag` then branches on it
            renders the member path ("fresh"), not the stale one.
  Face B -- a helper method called after the write reads the new value (7).
  Face C -- `n += 1; n += 1;` in one click handler nets +2.
  Face D -- a callback created in the handler reads current state when it
            fires (102), not a render-time snapshot (100).

Integration test: real `bun install` of react + jsdom, so it runs only when
`JAC_CLIENT_INTEGRATION` is set (mirrors `test_solid_jsdom.jac`).
"""

import json;
import os;
import re;
import shutil;
import subprocess;
import pytest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.runtimelib.client_surface { with_runtime_globals }
import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
import from jaclang.runtimelib.client.bun_installer { get_bun }

glob FIXTURES = str(
         Path(__file__).parent.parent
             / "compiler"
             / "passes"
             / "ecmascript"
             / "fixtures"
     ),
     # Mirrors `_default_client_deps("react")` runtime deps; jsdom is test-only.
     _DEPS: dict[str, str] = {
         "jsdom": "^24.0.0",
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0",
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     # The react backend emits plain JS (`__jacJsx(...)` calls, no JSX syntax),
     # so no babel step is needed: build a jsdom DOM, publish browser globals,
     # mount with react-dom/client, flush, and assert each contract face.
     # A plain (non-f) string so JS `${}` / `{}` need no escaping.
     _HARNESS: str = """
import { JSDOM } from "jsdom";

const dom = new JSDOM(
  '<!DOCTYPE html><html><body><div id="__jac_root"></div></body></html>',
  { url: "http://localhost/", pretendToBeVisual: true }
);
const { window } = dom;
globalThis.window = window;
for (const k of [
  "document", "navigator", "HTMLElement", "Element", "SVGElement", "Node",
  "Text", "Comment", "DocumentFragment", "Event", "CustomEvent", "MouseEvent",
  "KeyboardEvent", "getComputedStyle", "DOMParser", "localStorage",
]) {
  if (window[k] === undefined) continue;
  try { globalThis[k] = window[k]; } catch {}
}
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;
globalThis.IS_REACT_ACT_ENVIRONMENT = false;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};
const text = (id) => {
  const el = document.querySelector(`[data-testid="${id}"]`);
  return el ? el.textContent.trim() : "<missing>";
};

let React, createRoot, app;
try {
  React = await import("react");
  ({ createRoot } = await import("react-dom/client"));
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import under jsdom", false, String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

const root = createRoot(document.getElementById("__jac_root"));
try {
  root.render(React.createElement(app));
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
}
await sleep(120);

check("face A: entry ability branches on its own write (label == fresh)",
  text("label") === "fresh", `got: ${text("label")}`);
check("face B: helper method reads the just-written value (seen == 7)",
  text("seen") === "7", `got: ${text("seen")}`);

const btn = document.querySelector('[data-testid="bump"]');
check("bump button present", !!btn);
if (btn) {
  btn.click();
  await sleep(120);
  check("face C: two augmented writes in one handler net +2 (n == 2)",
    text("n") === "2", `got: ${text("n")}`);
  check("face D: deferred callback reads current state (echo == 102)",
    text("echo") === "102", `got: ${text("echo")}`);
}

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

"""Skip unless the client toolchain integration flag is set."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        pytest.skip(
            "React state-semantics jsdom test does a real bun install; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

def _compile_react(path: str) -> str {
    prog = JacProgram();
    # type_check=True so typed builtin calls (e.g. `len(list)`) lower to
    # their JS forms, matching the production bundler pipeline.
    ir = prog.compile(
        file_path=str(path), options=CompileOptions(type_check=True, no_cgen=True)
    );
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , f"compile errors in {path}: {[str(e) for e in fatal]}";
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=ReactBackend());
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

"""Point the shim's dotted core import at a flat sibling (mirrors the bundler)."""
def _rewrite_core_specifier(runtime_js: str) -> str {
    m = re.search(r"""["'](\.[^"']*client_runtime_core\.js)["']""", runtime_js);
    if m {
        return runtime_js.replace(m.group(1), "./client_runtime_core.js");
    }
    return runtime_js;
}

def _wire_jac_runtime(js: str) -> str {
    for q in ['"', "'"] {
        js = js.replace(f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}");
    }
    return js;
}

test "react state semantics: all four contract faces hold live in jsdom" {
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = ReactBackend();
    component_js = _wire_jac_runtime(
        with_runtime_globals(
            _compile_react(os.path.join(FIXTURES, "state_semantics_component.jac")),
            backend
        )
    );
    runtime_path = resolve_client_runtime_cl_path("react");
    runtime_js = _rewrite_core_specifier(_compile_react(runtime_path));
    core_js = _compile_react(
        str(Path(runtime_path).parent / "client_runtime_core.jac")
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        (work / "jac_runtime.js").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.js").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "react-state-semantics-test",
                    "private": True,
                    "type": "module",
                    "dependencies": _DEPS
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
        node_bin = shutil.which("node");
        if node_bin {
            cmd = [node_bin, str(work / "harness.mjs")];
        } else {
            cmd = [bun, "run", str(work / "harness.mjs")];
        }
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        detail = (run.stdout or "") + "\n" + (run.stderr or "");
        assert run.returncode == 0 , (
            f"react state-semantics harness failed (exit {run.returncode}):\n{detail}"
        );
    }
}
