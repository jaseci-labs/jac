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
    write_runtime,
    write_runtime_core
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


glob _REJECTED_TOKEN_HARNESS: str = """
import { JSDOM } from "jsdom";

const [target] = process.argv.slice(2);
const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>", { url: "http://localhost/" });
const storage = dom.window.localStorage;
globalThis.document = dom.window.document;
globalThis.localStorage = storage;
globalThis.sessionStorage = dom.window.sessionStorage;

// The page reset: web reloads, native runs the unauthorized handler.
let resets = 0;
if (target === "native") {
  globalThis.__jacGetApiBaseUrl__ = () => "";
  globalThis.__jacGetLocalStorage__ = (key) => storage.getItem(key) || "";
  globalThis.__jacRemoveLocalStorage__ = (key) => storage.removeItem(key);
  globalThis.__jacHandleWalkerUnauthorized__ = () => { resets += 1; };
} else {
  globalThis.window = { location: { reload: () => { resets += 1; } } };
}

const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};

const core = await import(
  target === "native" ? "./native/client_react_core.js" : "./client_runtime_core.js"
);
const answers = [];
globalThis.fetch = () => new Promise((resolve) => {
  answers.push((status) => resolve(status === 200
    ? new Response(JSON.stringify({ ok: true, data: {} }), { status: 200 })
    : new Response("unauthorized", { status: 401 })));
});
const tick = () => new Promise((r) => setTimeout(r, 0));
const stored = () => storage.getItem("jac_token");
const seed = (token) => {
  if (token === null) storage.removeItem("jac_token");
  else storage.setItem("jac_token", token);
};

// Each sender, and whether it can call another app.
const senders = [
  ["__doWalkerFetch", (opts) => core.__doWalkerFetch("w", "", {}, opts), true],
  ["__doFuncFetch", (opts) => core.__doFuncFetch("f", {}, opts), true],
];
if (target === "web") {
  senders.push(["__jacAuthedJson",
    () => core.__jacAuthedJson("GET", "http://localhost/sso/connections"), false]);
}

// One page load: `calls` requests go out with `sent` stored and are answered
// with `status` once `landed` is stored. `left` is what must be stored after,
// `resets` how many times the page must have been reset.
const load = async (tag, send, bridges, c) => {
  const status = c.status || 401;
  resets = 0;
  seed(c.sent);
  const pending = Array.from({ length: c.calls || 1 }, () =>
    send(c.app ? { app: c.app, route: "/" + c.app } : {}).then(() => null, (e) => e));
  await tick();
  seed("landed" in c ? c.landed : c.sent);
  answers.splice(0).forEach((answer) => answer(status));
  const errors = await Promise.all(pending);
  const raises = bridges && c.app && status === 401;
  check(`${tag}: ${c.name}`,
    stored() === c.left && resets === c.resets
      && errors.every((e) => (raises ? !!e && e.status === 401 : e === null)),
    `jac_token=${stored()} resets=${resets} errors=${errors}`);
};

const CASES = [
  { name: "another app, current token", app: "svc", sent: "tok", left: null, resets: 1 },
  { name: "another app, six calls, current token", app: "svc", calls: 6, sent: "tok", left: null, resets: 1 },
  { name: "another app, newer login", app: "svc", sent: "old", landed: "new", left: "new", resets: 0 },
  { name: "another app, no token", app: "svc", sent: null, left: null, resets: 0 },
  { name: "own app, current token", sent: "tok", left: null, resets: 1 },
  { name: "own app, newer login", sent: "old", landed: "new", left: "new", resets: 0 },
  { name: "own app, no token", sent: null, left: null, resets: 1 },
];

// Desktop profiles: each row is a page load, with the token the host put back.
const EXPIRED = "eyJhbGciOiJIUzI1NiJ9." +
  Buffer.from(JSON.stringify({ sub: "u", exp: 1000000000 })).toString("base64url") +
  ".sig";
const PROFILE_LOADS = [
  { name: "first rejection resets", profile: "p1", app: "svc", sent: "tok-1", left: null, resets: 1 },
  { name: "put back and accepted", profile: "p1", app: "svc", sent: "tok-2", status: 200, left: "tok-2", resets: 0 },
  { name: "rejected again is left alone", profile: "p1", app: "svc", sent: "tok-2", left: "tok-2", resets: 0 },
  { name: "expired resets again", profile: "p1", app: "svc", sent: EXPIRED, left: null, resets: 1 },
  { name: "put back after that is left alone", profile: "p1", app: "svc", sent: "tok-3", left: "tok-3", resets: 0 },
  { name: "already dropped, own app resets", profile: "p1", sent: null, left: null, resets: 1 },
  { name: "put back after that is left alone", profile: "p1", sent: "tok-4", left: "tok-4", resets: 0 },
  { name: "another profile resets", profile: "p2", app: "svc", sent: "tok-5", left: null, resets: 1 },
];

for (const [fn, send, bridges] of senders) {
  for (const c of CASES) {
    if (bridges || (!c.app && c.sent !== null)) await load(`${target} ${fn}`, send, bridges, c);
  }
  if (target !== "web") continue;
  sessionStorage.clear();
  for (const c of PROFILE_LOADS) {
    globalThis.__JAC_PROFILES__ = { active: c.profile, profiles: [] };
    if (bridges || c.sent !== null) await load(`web ${fn}: profile`, send, bridges, c);
  }
  delete globalThis.__JAC_PROFILES__;
}

console.log(failures.length ? `FAILED: ${failures.join(", ")}` : "OK");
process.exit(failures.length ? 1 : 0);
""";

"""What a 401 does to the stored token and the page (#10800):

    the token changed while the call was out   nothing, the newer login stays
    another app, a token was sent              token dropped, page reset once
    another app, no token                      nothing, a visitor never reloads
    the page's own app, token or not           token dropped, page reset once
    desktop profile, token put back by the     one reset per profile, until that
      host and rejected again                    token expires or is gone

The web core reloads the page; the native core runs the unauthorized handler."""
test "a 401 drops only the token it was sent with and resets the page once" {
    require_client_integration("rejected token");
    bun = js_runtime_or_none();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        write_runtime(work);
        (work / "native").mkdir();
        write_runtime_core(work / "native", "client_react_core");
        (work / "harness.mjs").write_text(_REJECTED_TOKEN_HARNESS, encoding="utf-8");
        bun_install(bun, work, "react-rejected-token-jsdom-test");
        for target in ["web", "native"] {
            run_harness(bun, work, [target], f"rejected token {target}");
        }
    }
}
