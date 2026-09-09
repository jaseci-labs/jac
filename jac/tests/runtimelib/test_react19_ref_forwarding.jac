"""jsdom behavioral test: a compiled `def:pub` component is a real ref target.

Radix positions a popper by taking a ref on the element its trigger renders.
With `asChild` that element is the child the trigger clones, so when the child
is a jac component the ref has to reach the component's host node. On React 18
a plain function component drops it (`Function components cannot be given
refs`), the popper gets no anchor, and it lands at the viewport origin -- the
jaclang.org sidebar's account dropdown rendered at a negative y.

React 19 delivers `ref` as an ordinary prop. This suite compiles the fixture
components to JS, mounts them under jsdom against the versions the client
pipeline itself pins, and reads the refs back off the live DOM -- once handed
straight to the component, once through the radix `Slot` an `asChild` trigger
renders, and once through the explicit `ref: Ref[...]` param lowering.

Integration test: real `bun install` of react + radix + jsdom, so it gates on
bun being present (mirrors `test_react_state_semantics.jac`).
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.cli.shadcn.shadcn_handler { load_registry }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.backends.es.backends.react { ReactBackend }
import from .react_jsdom_harness {
    REACT_JSDOM_DEPS,
    bun_install,
    compile_page,
    require_client_integration,
    run_harness,
    write_runtime
}

"""The radix version the shipped shadcn registry installs.

Read from the registry rather than pinned here, so the `Slot` this suite
mounts is the one a `jac install --shadcn` project actually gets."""
def radix_pin -> str {
    shared = load_registry().get("depVersions", {});
    pin = shared.get("radix-ui", "") if isinstance(shared, dict) else "";
    return str(pin) if pin else "^1.6.7";
}

glob FIXTURES: str = str(
         Path(__file__).parent.parent / "compiler" / "backends" / "es" / "fixtures"
     ),
     # The react backend emits plain JS (`__jacJsx(...)` calls, no JSX syntax),
     # so no babel step is needed: build a jsdom DOM, publish browser globals,
     # mount with react-dom/client, flush, and read the refs back. A plain
     # (non-f) string so JS `${}` / `{}` need no escaping.
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

const consoleErrors = [];
const baseError = console.error.bind(console);
console.error = (...args) => {
  consoleErrors.push(args.map((a) => String(a)).join(" "));
  baseError(...args);
};

let React, createRoot, Slot, Button, Badge;
try {
  React = await import("react");
  ({ createRoot } = await import("react-dom/client"));
  ({ Slot } = await import("radix-ui"));
  ({ Button, Badge } = await import("./component.js"));
} catch (e) {
  check("runtime modules import under jsdom", false, String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

check("the installed react is 19.x", String(React.version).startsWith("19."),
  `react ${React.version}`);

const directRef = React.createRef();
const slotRef = React.createRef();
const badgeRef = React.createRef();

const root = createRoot(document.getElementById("__jac_root"));
try {
  root.render(React.createElement(
    React.Fragment,
    null,
    React.createElement(Button, { ref: directRef, "data-testid": "direct" }, "Direct"),
    React.createElement(
      Slot.Root,
      { ref: slotRef, "data-testid": "anchored" },
      React.createElement(Button, null, "Anchored")
    ),
    React.createElement(Badge, { label: "forwarded", ref: badgeRef })
  ));
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
}
await sleep(150);

const byTestId = (id) => document.querySelector(`[data-testid="${id}"]`);
const describe = (r) => (r && r.current ? r.current.outerHTML : String(r && r.current));

check("a ref handed straight to a compiled component reaches its host node",
  !!directRef.current && directRef.current === byTestId("direct"),
  describe(directRef));
check("that host node is the <button> the component renders",
  !!directRef.current && directRef.current.tagName === "BUTTON",
  `tagName: ${directRef.current && directRef.current.tagName}`);

check("a radix Slot (what asChild renders) anchors on the compiled component",
  !!slotRef.current && slotRef.current === byTestId("anchored"),
  describe(slotRef));
check("the anchored ref is a live element a popper can measure",
  !!slotRef.current && typeof slotRef.current.getBoundingClientRect === "function",
  describe(slotRef));

check("a declared `ref: Ref[...]` param still reaches the DOM",
  !!badgeRef.current && badgeRef.current === byTestId("badge"),
  describe(badgeRef));

const refWarnings = consoleErrors.filter((m) => /cannot be given refs/i.test(m));
check("no `Function components cannot be given refs` warning",
  refWarnings.length === 0, refWarnings.join(" | "));

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

test "a compiled component is a ref target, live in jsdom" {
    require_client_integration("React 19 ref-as-prop");
    bun = get_bun();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }
    component_js = compile_page(
        os.path.join(FIXTURES, "react19_ref_components.jac"), ReactBackend()
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        write_runtime(work);
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        # REACT_JSDOM_DEPS is the pin the client pipeline itself ships, so
        # this suite fails the moment it drifts back off React 19. radix-ui
        # supplies the `Slot` an `asChild` trigger renders.
        bun_install(
            bun,
            work,
            "react19-ref-forwarding-test",
            deps={** REACT_JSDOM_DEPS, "radix-ui": radix_pin()}
        );
        run_harness(bun, work, [], "react 19 ref forwarding");
    }
}
