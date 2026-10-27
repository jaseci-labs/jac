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

`/wrapped` also runs with a JWT `jac_token`: an unexpired one renders as logged
in, and an expired one renders as logged out and is dropped from storage
(`jacIsLoggedIn` once trusted any stored token, so a stale one left the UI
"signed in" against a server that answered every call with 401).

Real `bun install`, so this runs only under `JAC_CLIENT_INTEGRATION`; the entry
(`test_react_backend.jac`) and react-native (`test_client_runtime_parity.jac`)
are covered ungated elsewhere.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.compiler.backends.es.backends.react { ReactBackend }
import from tests.support { js_runtime_or_none }
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
const jwtWithExp = (exp) =>
  "eyJhbGciOiJIUzI1NiJ9." +
  Buffer.from(JSON.stringify({ sub: "u", exp })).toString("base64url") +
  ".sig";
const TOKENS = {
  loggedIn: "test-token",
  jwtUnexpired: jwtWithExp(4102444800),
  jwtExpired: jwtWithExp(1000000000),
};
const expectState = { jwtUnexpired: "loggedIn", jwtExpired: "loggedOut" }[authState] || authState;
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

if (TOKENS[authState]) window.localStorage.setItem("jac_token", TOKENS[authState]);
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

const expect = EXPECT[`${startUrl}|${expectState}`];
if (!expect) {
  check(`known scenario ${startUrl}|${expectState}`, false, "no expectation row");
  finish();
}
assertExpectation(expect, () => mount.innerHTML);
if (authState === "jwtExpired") {
  check("drops the expired jac_token", !window.localStorage.getItem("jac_token"));
}
finish();
""";

"""One fresh process per scenario, so each starts at its own URL and auth state
with a clean module graph."""
def _run_scenarios(bun: str, work: Path, scenarios: list[any], label: str) {
    for sc in scenarios {
        run_harness(bun, work, [sc[0], sc[1]], f"{label} {sc}");
    }
}

test "react AuthGuard renders children, child routes, and nothing -- in jsdom" {
    require_client_integration("React AuthGuard");
    bun = js_runtime_or_none();
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
                ["/bare", "loggedOut"],
                ["/wrapped", "jwtUnexpired"],
                ["/wrapped", "jwtExpired"]
            ],
            "manual-routing"
        );
    }
}


glob _STALE_401_HARNESS: str = """
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>", { url: "http://localhost/" });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.localStorage = dom.window.localStorage;

const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};

const core = await import("./client_runtime_core.js");
let answer;
globalThis.fetch = () => new Promise((resolve) => {
  answer = () => resolve(new Response("unauthorized", { status: 401 }));
});
const call = (token) => {
  localStorage.setItem("jac_token", token);
  const pending = core.__doWalkerFetch("w", "", {}, { app: "svc" }).then(
    () => null,
    (e) => e
  );
  return pending;
};

// A request sent with the old token answers 401 after the user signed in again.
let pending = call("old-token");
await new Promise((r) => setTimeout(r, 0));
localStorage.setItem("jac_token", "new-token");
answer();
let err = await pending;
check("a stale 401 keeps the newer login", localStorage.getItem("jac_token") === "new-token",
  `jac_token=${localStorage.getItem("jac_token")}`);
check("the stale call still raises a 401 BridgeRejected", !!err && err.status === 401, String(err));

// A 401 for the token still in use drops it.
pending = call("current-token");
await new Promise((r) => setTimeout(r, 0));
answer();
err = await pending;
check("a 401 for the current token drops it", !localStorage.getItem("jac_token"),
  `jac_token=${localStorage.getItem("jac_token")}`);

console.log(failures.length ? `FAILED: ${failures.join(", ")}` : "OK");
process.exit(failures.length ? 1 : 0);
""";

"""A 401 only clears the token the failing request sent. A slow request that
went out before the user signed in again must not erase the new login."""
test "a delayed 401 from an old request keeps a newer login" {
    require_client_integration("stale 401");
    bun = js_runtime_or_none();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        write_runtime(work);
        (work / "harness.mjs").write_text(_STALE_401_HARNESS, encoding="utf-8");
        bun_install(bun, work, "react-stale-401-jsdom-test");
        run_harness(bun, work, [], "stale 401");
    }
}
