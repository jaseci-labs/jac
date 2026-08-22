"""jsdom behavioral tests for `AuthGuard` on the React (web) backend.

React had no `AuthGuard` coverage -- only `test_solid_jsdom.jac`, and Solid was
already children-aware -- which is how two defects shipped: children discarded
(blank protected page) and `auth_redirect` dropped by the generated entry.

These assert the LOGGED-IN render, not just the logged-out redirect: a guard
rendering nothing still blocks anonymous users, so a redirect-only test passes on
the broken code. Every scenario runs in both auth states (logged out must land on
`/login`), against `fixtures/react_auth/manual_routing_app.jac`:

    /wrapped         guard wraps a page as a route `element` -> page renders
    /nested          pathless PARENT route -> child route renders
    /layout-guarded  layout wraps `<Outlet/>` in the guard -> child renders
    /bare            neither children nor child routes -> no crash

Real `bun install`, so this runs only under `JAC_CLIENT_INTEGRATION`; the entry
(`test_react_backend.jac`) and react-native (`test_client_runtime_parity.jac`)
are covered ungated elsewhere.
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

glob FIXTURES = str(Path(__file__).parent / "fixtures" / "react_auth"),
     _JSDOM_BOOT: str = """
import { JSDOM } from "jsdom";

const [startUrl, authState] = process.argv.slice(2);
const loggedIn = authState === "loggedIn";
const tag = `[${startUrl} ${authState}]`;

const dom = new JSDOM(
  `<!DOCTYPE html><html><body><div id="${mountId}"></div></body></html>`,
  { url: "http://localhost" + startUrl, pretendToBeVisual: true }
);
const { window } = dom;
globalThis.window = window;
for (const k of [
  "document", "navigator", "HTMLElement", "Element", "SVGElement", "Node",
  "Text", "Comment", "DocumentFragment", "Event", "CustomEvent", "MouseEvent",
  "KeyboardEvent", "getComputedStyle", "DOMParser", "localStorage", "history",
  "location",
]) {
  if (window[k] === undefined) continue;
  try { globalThis[k] = window[k]; } catch {}
}
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;
globalThis.IS_REACT_ACT_ENVIRONMENT = false;

if (loggedIn) window.localStorage.setItem("jac_token", "test-token");
else window.localStorage.removeItem("jac_token");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${tag} ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};
const present = (testid) => !!document.querySelector(`[data-testid="${testid}"]`);
const finish = () => {
  console.log(`\\n${tag} ${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
    (failures.length ? `: ${failures.join(", ")}` : ""));
  process.exit(failures.length ? 1 : 0);
};

/* Assert one scenario's expectation row against the mounted DOM. */
const assertExpectation = (expect, html) => {
  for (const id of expect.present) {
    check(`renders [data-testid="${id}"]`, present(id), `html=${html()}`);
  }
  for (const id of expect.absent) {
    check(`does not render [data-testid="${id}"]`, !present(id), `html=${html()}`);
  }
  check(`settles at ${expect.path}`, window.location.pathname === expect.path,
    `got: ${window.location.pathname}`);
};
""",
     _MANUAL_HARNESS: str = "const mountId = \"__jac_root\";\n"
         + _JSDOM_BOOT
         + """
const EXPECT = {
  // The documented wrapper form. Logged in, the wrapped page must render; a
  // guard that ignores its children renders an empty `<Outlet/>` here instead.
  "/wrapped|loggedIn": { present: ["chrome", "dashboard"], absent: ["login"], path: "/wrapped" },
  "/wrapped|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
  // Guard as a pathless parent route: no children, so the `<Outlet/>` fallback
  // must still resolve the matched child route.
  "/nested|loggedIn": { present: ["chrome", "nested"], absent: ["login"], path: "/nested" },
  "/nested|loggedOut": { present: ["chrome", "login"], absent: ["nested"], path: "/login" },
  // The file-based `(auth)/layout.jac` shape: children ARE present (the user's
  // own `<Outlet/>`), and resolve to the same matched child route.
  "/layout-guarded|loggedIn": { present: ["chrome", "dashboard"], absent: ["login"], path: "/layout-guarded" },
  "/layout-guarded|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
  // Neither children nor child routes: renders nothing, must not crash.
  "/bare|loggedIn": { present: ["chrome"], absent: ["dashboard", "nested", "login"], path: "/bare" },
  "/bare|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
};

let React, createRoot, app;
try {
  React = await import("react");
  ({ createRoot } = await import("react-dom/client"));
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import under jsdom", false, String((e && e.stack) || e));
  finish();
}

const mount = document.getElementById(mountId);
try {
  createRoot(mount).render(React.createElement(app));
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
  finish();
}
await sleep(150);

const expect = EXPECT[`${startUrl}|${authState}`];
if (!expect) {
  check(`known scenario ${startUrl}|${authState}`, false, "no expectation row");
  finish();
}
assertExpectation(expect, () => mount.innerHTML);
finish();
""";

"""One fresh process per scenario, so each starts at its own URL and auth state
with a clean module graph."""
def _run_scenarios(bun: str, work: Path, scenarios: list, label: str) {
    for sc in scenarios {
        run_harness(bun, work, [sc[0], sc[1]], f"{label} {sc}");
    }
}

test "react AuthGuard renders children, child routes, and nothing -- in jsdom" {
    require_client_integration("React AuthGuard");
    bun = get_bun();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }

    backend = ReactBackend();
    component_js = compile_page(
        os.path.join(FIXTURES, "manual_routing_app.jac"), backend
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        write_runtime(work);
        (work / "harness.mjs").write_text(_MANUAL_HARNESS, encoding="utf-8");
        bun_install(bun, work, "react-authguard-jsdom-test");
        _run_scenarios(
            bun,
            work,
            [
                ["/wrapped", "loggedIn"],
                ["/wrapped", "loggedOut"],
                ["/nested", "loggedIn"],
                ["/nested", "loggedOut"],
                ["/layout-guarded", "loggedIn"],
                ["/layout-guarded", "loggedOut"],
                ["/bare", "loggedIn"],
                ["/bare", "loggedOut"]
            ],
            "manual-routing"
        );
    }
}
