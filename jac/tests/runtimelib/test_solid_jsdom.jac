"""jsdom runtime test for the Solid framework backend.

The string-only backend tests (`tests/compiler/passes/ecmascript/test_solid_backend.jac`)
pin what the Solid backend *emits* but never execute it. This test closes that
gap: it compiles a Solid counter + the real `@jac/runtime` shim to JS, mounts it
in a real DOM (jsdom) via `solid-js/web`'s `render`, and asserts the initial
render plus that a click reactively updates the text -- exercising the live
`solid-js` runtime, the `solid-js/h`-backed `__jacJsx`, the accessor-thunk read,
and the signal setter end to end.

This is the documented follow-up for Solid runtime exec: `@solidjs/router` calls a client-only `solid-js`
API at import time, so the shim can't load in bare `node` -- a jsdom DOM plus the
`browser` resolver condition (which selects solid's DOM build over its SSR build)
is what makes it runnable.

Integration test: it does a real `bun install` of jsdom + solid-js & friends, so
it runs only when `JAC_CLIENT_INTEGRATION` is set (mirrors `test_preact_e2e.jac`).
Core CI exercises it in a dedicated `test-solid-jsdom` job that sets that flag.
"""

import json;
import os;
import re;
import shutil;
import subprocess;
import pytest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.runtimelib.client_surface { with_runtime_globals }
import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
import from jaclang.runtimelib.client.bun_installer { get_bun }
import from jaclang.runtimelib.solid_entry { build_pages_solid_entry_script }

glob FIXTURES = str(Path(__file__).parent / "fixtures"),
     # Real npm deps. The solid-* / zod versions mirror the canonical Solid set in
     # `client/impl/client_deps.impl.jac` (`_default_client_deps("solid")`); jsdom is
     # the DOM simulator, test-only, so it lives here rather than in the runtime deps.
     _DEPS: dict[str, str] = {
         "jsdom": "^24.0.0",
         "solid-js": "^1.9.13",
         "@solidjs/router": "^0.16.1",
         "solid-hook-form": "^2.5.3",
         "zod": "^4.3.6"
     },
     # ES harness: build a jsdom DOM, publish the browser globals solid's DOM build
     # needs BEFORE importing it, mount the compiled component, and assert render +
     # reactivity. A plain (non-f) string so the JS `${}` / `{}` need no escaping.
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
  "KeyboardEvent", "getComputedStyle", "DOMParser",
]) {
  if (window[k] === undefined) continue;
  // Some of these (e.g. `navigator` on newer node) are read-only globals; the
  // DOM build reads them off `window` anyway, so skip what can't be assigned.
  try { globalThis[k] = window[k]; } catch {}
}
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;

const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};

let render, h, app;
try {
  ({ render } = await import("solid-js/web"));
  h = (await import("solid-js/h")).default;
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import (jsdom + --conditions=browser)", false,
    String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

check("solid-js/web exposes a DOM render()", typeof render === "function",
  `typeof render = ${typeof render}`);

const root = document.getElementById("__jac_root");
try {
  render(() => h(app, {}), root);
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
}

const countEl = () => document.querySelector('[data-testid="count"]');
check("component mounted a [data-testid=count] node", !!countEl(),
  `root.innerHTML=${root.innerHTML}`);

if (countEl()) {
  check("initial render shows Count: 0",
    countEl().textContent.trim() === "Count: 0",
    `got: ${JSON.stringify(countEl().textContent)}`);
  const btn = document.querySelector('[data-testid="inc"]');
  check("increment button present", !!btn);
  if (btn) {
    btn.click();
    check("click increments to Count: 1",
      countEl().textContent.trim() === "Count: 1",
      `got: ${JSON.stringify(countEl().textContent)}`);
    btn.click();
    check("second click increments to Count: 2",
      countEl().textContent.trim() === "Count: 2",
      `got: ${JSON.stringify(countEl().textContent)}`);
  }
}

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

"""Routing harness: build a jsdom DOM at a given start URL, optionally seed a
`jac_token` (so `jacIsLoggedIn()` is true), import the generated file-based-routing
`entry.js` (which renders itself), then assert per-scenario. `argv[2]` is the start
path, `argv[3]` is `loggedIn`/`loggedOut`. A plain (non-f) string so JS `${}`/`{}`
need no escaping."""
glob _ROUTING_HARNESS: str = """
import { JSDOM } from "jsdom";

const startUrl = process.argv[2] || "/";
const loggedIn = process.argv[3] === "loggedIn";

const dom = new JSDOM(
  '<!DOCTYPE html><html><body><div id="__jac_root"></div></body></html>',
  { url: "http://localhost" + startUrl, pretendToBeVisual: true }
);
const { window } = dom;
globalThis.window = window;
for (const k of [
  "document", "navigator", "HTMLElement", "Element", "SVGElement", "Node",
  "Text", "Comment", "DocumentFragment", "Event", "CustomEvent", "MouseEvent",
  "KeyboardEvent", "getComputedStyle", "DOMParser", "history", "location",
]) {
  if (window[k] === undefined) continue;
  try { globalThis[k] = window[k]; } catch {}
}
// The runtime core reads `globalThis.localStorage`; jacIsLoggedIn keys off it.
globalThis.localStorage = window.localStorage;
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;

if (loggedIn) window.localStorage.setItem("jac_token", "test-token");
else window.localStorage.removeItem("jac_token");

const tag = `[${startUrl} ${loggedIn ? "loggedIn" : "loggedOut"}]`;
const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${tag} ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};

try {
  await import("./entry.js");
} catch (e) {
  check("entry.js imports + mounts via solid-js/web", false, String((e && e.stack) || e));
  console.log("\\nFAILED: entry import error");
  process.exit(1);
}

const root = document.getElementById("__jac_root");
const present = (testid) => !!document.querySelector(`[data-testid="${testid}"]`);

// `<Router root={Layout}>` wraps every matched route, so the layout chrome is
// always present -- this is the proof the `__JacOutletContext` bridge mounts.
check("layout chrome (root layout) present", present("chrome"), `html=${root.innerHTML}`);

if (startUrl === "/" && !loggedIn) {
  check("home page renders at /", present("home"), `html=${root.innerHTML}`);
  check("about not shown before navigating", !present("about"));
  const link = document.querySelector('[data-testid="to-about"]');
  check("home renders an About <Link>", !!link);
  if (link) {
    // @solidjs/router's <A> intercepts same-origin clicks; dispatch a real event.
    link.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
    await Promise.resolve();
    await Promise.resolve();
    check("clicking the Link swaps the <Outlet> to /about",
      present("about") && !present("home"), `html=${root.innerHTML}`);
    check("layout chrome persists across navigation", present("chrome"));
  }
}

if (startUrl === "/dashboard" && !loggedIn) {
  // AuthGuard redirects to /login (not a defined route), so the protected page
  // must NOT render; the root layout still mounts.
  check("auth route blocked when logged out", !present("dashboard"), `html=${root.innerHTML}`);
}

if (startUrl === "/dashboard" && loggedIn) {
  check("auth route renders the protected page when logged in",
    present("dashboard"), `html=${root.innerHTML}`);
}

console.log(`\\n${tag} ${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

"""Skip unless the bun/npm client toolchain is opted in (mirrors preact e2e)."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        pytest.skip(
            "Solid jsdom test needs bun + a real npm install; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

"""Compile a `.cl.jac` to JS with the Solid backend; type errors are non-fatal."""
def _compile_solid(path: str) -> str {
    prog = JacProgram();
    ir = prog.compile(file_path=str(path), no_cgen=True);
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , f"compile errors in {path}: {[str(e) for e in fatal]}";
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=SolidBackend());
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

"""Rewrite every `@jac/runtime` specifier in emitted JS to the flat sibling the
harness writes (`./jac_runtime.js`) -- mirrors how the bundler resolves the
virtual `@jac/runtime` module."""
def _wire_jac_runtime(js: str) -> str {
    for q in ['"', "'"] {
        js = js.replace(f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}");
    }
    return js;
}

"""Compile a page/layout `.cl.jac`, prepend its `@jac/runtime` globals (the bare
`__jacJsx`/`Link`/`Outlet` the compiler emits), and wire the runtime specifier."""
def _compile_page(path: str, backend: any) -> str {
    return _wire_jac_runtime(with_runtime_globals(_compile_solid(path), backend));
}

test "solid counter mounts and reacts in jsdom" {
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = SolidBackend();
    # Compiler emits bare `__jacJsx(...)` and expects the bundler to prepend the
    # `@jac/runtime` import -- do exactly that.
    component_js = with_runtime_globals(
        _compile_solid(os.path.join(FIXTURES, "solid_counter_app.cl.jac")), backend
    );
    runtime_path = resolve_client_runtime_cl_path("solid");
    runtime_js = _rewrite_core_specifier(_compile_solid(runtime_path));
    core_js = _compile_solid(
        str(Path(runtime_path).parent / "client_runtime_core.cl.jac")
    );
    # Wire the three emitted modules together by relative path inside the work dir.
    for q in ['"', "'"] {
        component_js = component_js.replace(
            f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}"
        );
    }

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        (work / "jac_runtime.js").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.js").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "solid-jsdom-test",
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
        # node with the `browser` condition selects solid's DOM build (not SSR);
        # fall back to bun if node is unavailable on the runner. (`node` is a Jac
        # keyword, so the binary path is held in `node_bin`.)
        node_bin = shutil.which("node");
        if node_bin {
            cmd = [node_bin, "--conditions=browser", str(work / "harness.mjs")];
        } else {
            cmd = [bun, "--conditions=browser", "run", str(work / "harness.mjs")];
        }
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        detail = (run.stdout or "") + "\n" + (run.stderr or "");
        assert run.returncode == 0 , (
            f"jsdom harness failed (exit {run.returncode}):\n{detail}"
        );
    }
}

test "solid file-based routing mounts, navigates, and guards in jsdom" {
    # Exercises the native `@solidjs/router` wiring end to end (TODO #2): the
    # generated entry's `<Router root={Layout}>` shell, `component`-based routes,
    # `<Link>`-driven navigation swapping the `<Outlet>`, and the pathless
    # `AuthGuard` route that blocks a protected page when logged out and renders it
    # when a `jac_token` is present. Same opt-in + toolchain as the counter test.
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = SolidBackend();
    rdir = os.path.join(FIXTURES, "solid_routing");
    home_js = _compile_page(os.path.join(rdir, "home_page.cl.jac"), backend);
    about_js = _compile_page(os.path.join(rdir, "about_page.cl.jac"), backend);
    dash_js = _compile_page(os.path.join(rdir, "dashboard_page.cl.jac"), backend);
    layout_js = _compile_page(os.path.join(rdir, "root_layout.cl.jac"), backend);

    runtime_path = resolve_client_runtime_cl_path("solid");
    runtime_js = _rewrite_core_specifier(_compile_solid(runtime_path));
    core_js = _compile_solid(
        str(Path(runtime_path).parent / "client_runtime_core.cl.jac")
    );
    # The entry is built exactly as the ViteCompiler builds it for `pages/` apps;
    # only its `@jac/runtime` specifier is rewired to the flat sibling.
    entry_js = _wire_jac_runtime(
        build_pages_solid_entry_script("main", "/login", False)
    );
    # Framework-neutral `_routes.js` manifest (the same shape compiler.impl emits).
    manifest = "\n".join(
        [
            'import { page as Home } from "./home_page.js";',
            'import { page as About } from "./about_page.js";',
            'import { page as Dashboard } from "./dashboard_page.js";',
            'import { layout as RootLayout } from "./root_layout.js";',
            '',
            'export const routes = [',
            '\t{ path: "/", element: Home, auth: false },',
            '\t{ path: "/about", element: About, auth: false },',
            '\t{ path: "/dashboard", element: Dashboard, auth: true },',
            '];',
            'export const layouts = { "/": RootLayout };',
            ''
        ]
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "home_page.js").write_text(home_js, encoding="utf-8");
        (work / "about_page.js").write_text(about_js, encoding="utf-8");
        (work / "dashboard_page.js").write_text(dash_js, encoding="utf-8");
        (work / "root_layout.js").write_text(layout_js, encoding="utf-8");
        (work / "_routes.js").write_text(manifest, encoding="utf-8");
        (work / "entry.js").write_text(entry_js, encoding="utf-8");
        (work / "jac_runtime.js").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.js").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_ROUTING_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "solid-routing-jsdom-test",
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
        # Each scenario is a fresh process so `entry.js` (and its one-time render)
        # re-runs at the scenario's start URL / auth state.
        scenarios = [
            ["/", "loggedOut"],
            ["/dashboard", "loggedOut"],
            ["/dashboard", "loggedIn"]
        ];
        for sc in scenarios {
            if node_bin {
                cmd = [
                    node_bin,
                    "--conditions=browser",
                    str(work / "harness.mjs"),
                    sc[0],
                    sc[1]
                ];
            } else {
                cmd = [
                    bun,
                    "--conditions=browser",
                    "run",
                    str(work / "harness.mjs"),
                    sc[0],
                    sc[1]
                ];
            }
            run = subprocess.run(
                cmd, cwd=str(work), capture_output=True, text=True, timeout=120
            );
            detail = (run.stdout or "") + "\n" + (run.stderr or "");
            assert run.returncode == 0 , (
                f"routing harness {sc} failed (exit {run.returncode}):\n{detail}"
            );
        }
    }
}
