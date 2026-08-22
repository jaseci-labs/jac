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

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.runtimelib.client.bun_installer { get_bun }
import from .react_jsdom_harness {
    bun_install,
    compile_page,
    require_client_integration,
    run_harness,
    write_runtime
}

glob FIXTURES = str(
         Path(__file__).parent.parent
             / "compiler"
             / "passes"
             / "ecmascript"
             / "fixtures"
     ),
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

test "react state semantics: all four contract faces hold live in jsdom" {
    require_client_integration("React state-semantics");
    bun = get_bun();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }

    component_js = compile_page(
        os.path.join(FIXTURES, "state_semantics_component.jac"), ReactBackend()
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        write_runtime(work);
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        bun_install(bun, work, "react-state-semantics-test");
        run_harness(bun, work, [], "react state-semantics");
    }
}
