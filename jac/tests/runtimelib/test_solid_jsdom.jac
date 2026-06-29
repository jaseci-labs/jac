"""jsdom runtime test for the Solid framework backend.

The string-only backend tests (`tests/compiler/passes/ecmascript/test_solid_backend.jac`)
pin what the Solid backend *emits* but never execute it. This test closes that
gap: it compiles a Solid counter + the real `@jac/runtime` shim to JS, mounts it
in a real DOM (jsdom) via `solid-js/web`'s `render`, and asserts the initial
render plus that a click reactively updates the text -- exercising the live
`solid-js` runtime, the dom-expressions JSX path, the accessor-thunk read,
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
         "@tanstack/solid-form": "^1.33.0",
         "zod": "^4.3.6",
         # The Solid backend now emits JSX *syntax* (the dom-expressions path), so
         # the harness must run the babel transform `vite-plugin-solid` wraps
         # (`babel-preset-solid`) before mounting — mirroring `jac client build`'s
         # plugin. Test-only deps (distinct from the deps the compiler *emits* into
         # a generated project, which land with the Vite plugin wiring in Branch 5+).
         "@babel/core": "^7.24.0",
         "babel-preset-solid": "^1.9.12"
     },
     # Babel-transform step shared by both harnesses: the Solid backend emits JSX
     # *syntax*, so every emitted module is written as `<name>.src.jsx` and compiled
     # to `<name>.js` through `babel-preset-solid` (the transform `vite-plugin-solid`
     # applies) before any import. Plain JS modules (the entry, the route manifest)
     # carry no JSX, so the transform is a safe no-op. A plain (non-f) string.
     _BABEL_BUILD: str = """
import babelCore from "@babel/core";
import fs from "node:fs";
for (const f of fs.readdirSync(".")) {
  if (!f.endsWith(".src.jsx")) continue;
  const code = fs.readFileSync("./" + f, "utf8");
  const out = babelCore.transformSync(code, {
    presets: [["babel-preset-solid", { generate: "dom", hydratable: false }]],
    filename: f,
  });
  fs.writeFileSync("./" + f.replace(/\\.src\\.jsx$/, ".js"), out.code, "utf8");
}
""",
     # ES harness: babel-build every emitted module, build a jsdom DOM, publish the
     # browser globals solid's DOM build needs BEFORE importing it, mount the
     # compiled component via `solid-js/web`'s `render`, and assert render +
     # reactivity. A plain (non-f) string so the JS `${}` / `{}` need no escaping.
     _HARNESS: str = _BABEL_BUILD + """
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

let render, app;
try {
  ({ render } = await import("solid-js/web"));
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
  // The compiled component is a dom-expressions function component — mount it
  // directly (no hyperscript `h(app, {})` wrapper).
  render(() => app(), root);
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

"""Control-flow harness (Branch 4): mount the lifted `<For>`/`<Show>` component and
assert it actually renders + reacts through `babel-preset-solid` — the keyed
comprehension produces three ordered `<li>` with no stray `key` DOM attribute, and
the `show` signal toggle swaps the `<Show>` arm. A plain (non-f) string so the JS
`${}`/`{}` need no escaping; the leading `_BABEL_BUILD` builds `component.src.jsx`."""
glob _CONTROL_FLOW_HARNESS: str = _BABEL_BUILD + """
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

let render, app;
try {
  ({ render } = await import("solid-js/web"));
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import (jsdom + --conditions=browser)", false,
    String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

const root = document.getElementById("__jac_root");
try {
  render(() => app(), root);
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
}

// <For>: the keyed comprehension lowered to a native <For each={labels}> and
// rendered three ordered <li> children.
const items = () => Array.from(
  document.querySelectorAll('[data-testid="list"] > li')
).map((n) => n.textContent.trim());
check("For rendered three list items", items().length === 3,
  `got: ${JSON.stringify(items())}`);
check("For preserved item text/order",
  JSON.stringify(items()) === JSON.stringify(["alpha", "beta", "gamma"]),
  `got: ${JSON.stringify(items())}`);
// The lifted body must NOT carry the React-style `key` on the DOM node.
const firstLi = document.querySelector('[data-testid="list"] > li');
check("For body dropped the key attribute",
  !!firstLi && !firstLi.hasAttribute("key"),
  firstLi ? firstLi.outerHTML : "no <li>");

// <Show>: the view ternary lowered to <Show when={show()} fallback={...}>; the
// consequent renders initially and the fallback is absent.
const shown = () => document.querySelector('[data-testid="shown"]');
const hidden = () => document.querySelector('[data-testid="hidden"]');
check("Show renders the consequent initially", !!shown() && !hidden(),
  `root=${root.innerHTML}`);

const toggle = document.querySelector('[data-testid="toggle"]');
check("toggle button present", !!toggle);
if (toggle) {
  toggle.click();
  check("Show reactively swaps to the fallback after toggle",
    !shown() && !!hidden(), `root=${root.innerHTML}`);
  toggle.click();
  check("Show swaps back to the consequent",
    !!shown() && !hidden(), `root=${root.innerHTML}`);
}

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

"""Routing harness: build a jsdom DOM at a given start URL, optionally seed a
`jac_token` (so `jacIsLoggedIn()` is true), import the generated file-based-routing
`entry.js` (which renders itself), then assert per-scenario. `argv[2]` is the start
path, `argv[3]` is `loggedIn`/`loggedOut`. A plain (non-f) string so JS `${}`/`{}`
need no escaping. The leading `_BABEL_BUILD` step compiles every emitted
`*.src.jsx` (pages, layout, runtime shim) to `*.js` via `babel-preset-solid`; the
entry and route manifest carry no JSX, so their transform is a no-op."""
glob _ROUTING_HARNESS: str = _BABEL_BUILD + """
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
// `@solidjs/router` scrolls on navigation; jsdom has no `scrollTo`, so stub it.
window.scrollTo = () => {};
globalThis.scrollTo = () => {};

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

"""Form harness: mount a `JacForm` with email + checkbox + enum-select +
enum-radio fields compiled via the Solid backend, then assert (1) the form
structure renders in jsdom, (2) an invalid email shows a Jac error paragraph
after blur (onBlur validator fires), (3) fixing the email clears the error
without a second blur (onChange revalidation — end-to-end proof of the
`onTouched` approximation), (4) the checkbox input renders and accepts a change
event, (5) the select field renders the correct options and a change updates its
reflected value, (6) the radio field renders one input per option with none
checked initially and a click marks the chosen option checked, and (7) the full
submit flow: dirty → button enabled → click → onSubmit fires (sets
`globalThis.__jacFormSubmitted`). A plain (non-f) string so JS `${}`/`{}`
need no escaping; `_BABEL_BUILD` compiles every emitted `*.src.jsx` before any
import."""
glob _FORM_HARNESS: str = _BABEL_BUILD + """
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
  "KeyboardEvent", "FocusEvent", "getComputedStyle", "DOMParser",
]) {
  if (window[k] === undefined) continue;
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

let render, app;
try {
  ({ render } = await import("solid-js/web"));
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import (jsdom + --conditions=browser)", false,
    String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

const root = document.getElementById("__jac_root");
try {
  render(() => app(), root);
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
  console.log("\\nFAILED: mount error");
  process.exit(1);
}

// --- Structure checks ---
const formEl = document.querySelector("form");
check("form element rendered", !!formEl, `root.innerHTML=${root.innerHTML}`);

const emailInput = document.querySelector('input[type="email"]');
check("email input rendered", !!emailInput, `html=${root.innerHTML}`);

const checkboxInput = document.querySelector('input[type="checkbox"]');
check("checkbox input rendered", !!checkboxInput, `html=${root.innerHTML}`);

const selectEl = document.querySelector('select');
check("select input rendered", !!selectEl, `html=${root.innerHTML}`);
// The select branch renders a placeholder `<option value="">` plus one option per
// enum value (from `getEnumOptions` reading zod v4's `_def.entries`).
const selectValues = selectEl
  ? Array.from(selectEl.querySelectorAll('option')).map((o) => o.value)
  : [];
check("select lists the enum options (+ placeholder)",
  JSON.stringify(selectValues) === JSON.stringify(["", "free", "pro", "enterprise"]),
  `got: ${JSON.stringify(selectValues)}`);

const allRadios = Array.from(document.querySelectorAll('input[type="radio"]'));
check("radio inputs rendered (one per enum option)",
  allRadios.length === 2,
  `got: ${allRadios.length}, html=${root.innerHTML}`);
check("no radio checked initially",
  !allRadios.some((r) => r.checked),
  `checked: ${JSON.stringify(allRadios.filter((r) => r.checked).map((r) => r.value))}`);

const submitBtn = document.querySelector('button[type="submit"]');
check("submit button rendered", !!submitBtn, `html=${root.innerHTML}`);

if (submitBtn) {
  check("submit disabled initially (form not dirty)",
    submitBtn.disabled,
    `disabled=${submitBtn.disabled}`);
}

// --- onTouched validation: error on blur, clears on onChange (no second blur) ---
if (emailInput) {
  // Re-query each time: Solid may replace the input node on reactive updates.
  const emailError = () => {
    const input = document.querySelector('input[type="email"]');
    if (!input) return null;
    const wrapper = input.closest("div");
    return wrapper ? wrapper.querySelector("p") : null;
  };

  // 1. Enter an invalid email value and fire the change event (handleChange).
  emailInput.value = "not-an-email";
  emailInput.dispatchEvent(new window.Event("input", { bubbles: true }));
  emailInput.dispatchEvent(new window.Event("change", { bubbles: true }));
  // 2. Blur the field (handleBlur) — triggers the onBlur validator.
  emailInput.dispatchEvent(new window.Event("blur", { bubbles: false }));
  // Allow TanStack Form's async validation + Solid reactive DOM update to settle.
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();

  check("email error appears after invalid input + blur",
    !!emailError() && emailError().textContent.includes("Invalid email"),
    `errorText=${emailError() ? JSON.stringify(emailError().textContent) : "null"} html=${root.innerHTML}`);

  // 3. Fix the email — onChange validator should re-run and clear the error
  //    without requiring another blur. This is the critical onTouched proof.
  const emailLive = document.querySelector('input[type="email"]');
  if (emailLive) {
    emailLive.value = "test@example.com";
    emailLive.dispatchEvent(new window.Event("input", { bubbles: true }));
    emailLive.dispatchEvent(new window.Event("change", { bubbles: true }));
    emailLive.dispatchEvent(new window.Event("blur", { bubbles: false }));
  }
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await new Promise((r) => setTimeout(r, 0));
  await new Promise((r) => setTimeout(r, 0));
  await new Promise((r) => setTimeout(r, 10));

  check("email error clears after valid input without second blur",
    !emailError() || !emailError().textContent.includes("Invalid email"),
    `errorText=${emailError() ? JSON.stringify(emailError().textContent) : "null"}`);

  // Dirty the remaining required fields so the multi-field schema can validate.
  // Fire both `input` (delegated by Solid) and `change` (direct listener) so the
  // handleChange path is exercised regardless of which event Solid delegates.
  const agreeCb = document.querySelector('input[type="checkbox"]');
  if (agreeCb) {
    agreeCb.checked = true;
    agreeCb.dispatchEvent(new window.Event("input", { bubbles: true }));
    agreeCb.dispatchEvent(new window.Event("change", { bubbles: true }));
  }
  await Promise.resolve(); await Promise.resolve();

  const planSelect = document.querySelector("select");
  if (planSelect) {
    planSelect.value = "pro";
    planSelect.dispatchEvent(new window.Event("input", { bubbles: true }));
    planSelect.dispatchEvent(new window.Event("change", { bubbles: true }));
  }
  await Promise.resolve(); await Promise.resolve();

  const adminRadio = document.querySelector('input[type="radio"][value="admin"]');
  if (adminRadio) {
    adminRadio.checked = true;
    adminRadio.dispatchEvent(new window.Event("input", { bubbles: true }));
    adminRadio.dispatchEvent(new window.Event("change", { bubbles: true }));
  }
  // Allow microtask and macrotask rounds for the async Zod Standard Schema
  // validator and Solid's reactive re-render to settle.
  await Promise.resolve();
  await Promise.resolve();
  await new Promise((r) => setTimeout(r, 0));
  await new Promise((r) => setTimeout(r, 50));

  const submitLive = document.querySelector('button[type="submit"]');
  if (submitLive) {
    check("submit enabled after form is dirtied",
      !submitLive.disabled,
      `disabled=${submitLive.disabled} isDirty/isValid debug: form has ${document.querySelectorAll('[data-testid]').length} testid els`);
  }
}

// --- Checkbox: change event dispatches without error ---
if (checkboxInput) {
  let checkboxError = false;
  try {
    checkboxInput.checked = true;
    checkboxInput.dispatchEvent(new window.Event("change", { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();
  } catch (e) {
    checkboxError = true;
    check("checkbox change event dispatches without throwing", false, String(e));
  }
  if (!checkboxError) {
    check("checkbox change event dispatches without throwing", true);
  }
}

// --- Select: change event dispatches without error + value is reflected ---
if (selectEl) {
  let selectError = false;
  try {
    selectEl.value = "pro";
    selectEl.dispatchEvent(new window.Event("change", { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();
  } catch (e) {
    selectError = true;
    check("select change event dispatches without throwing", false, String(e));
  }
  if (!selectError) {
    check("select change event dispatches without throwing", true);
    check("select reflects the chosen value after handleChange",
      selectEl.value === "pro",
      `got: ${JSON.stringify(selectEl.value)}`);
  }
}

// --- Radio: click one option, verify it is marked checked after handleChange ---
const radioInputs = Array.from(document.querySelectorAll('input[type="radio"]'));
if (radioInputs.length > 0) {
  const adminRadio = radioInputs.find((r) => r.value === "admin");
  let radioError = false;
  try {
    if (adminRadio) {
      adminRadio.checked = true;
      adminRadio.dispatchEvent(new window.Event("change", { bubbles: true }));
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    }
  } catch (e) {
    radioError = true;
    check("radio change event dispatches without throwing", false, String(e));
  }
  if (!radioError) {
    check("radio change event dispatches without throwing", true);
    check("clicked radio reflects checked state",
      !!adminRadio && adminRadio.checked,
      adminRadio ? `value=${adminRadio.value} checked=${adminRadio.checked}` : "no admin radio");
  }
}

// --- Full submit flow: dirty → button enabled → onSubmit fires ---
globalThis.__jacFormSubmitted = false;
const submitLive = document.querySelector('button[type="submit"]');
if (submitLive && !submitLive.disabled) {
  let submitError = false;
  try {
    submitLive.click();
    // Give TanStack Form's async handleSubmit chain (validateAllFields, then
    // onSubmit callback) time to complete: a macrotask ensures all pending
    // microtasks (including Promise.all inside handleSubmit) are flushed first.
    await new Promise((r) => setTimeout(r, 0));
  } catch (e) {
    submitError = true;
    check("submit click fires onSubmit without throwing", false, String(e));
  }
  if (!submitError) {
    check("submit click fires onSubmit without throwing", true);
    check("onSubmit callback invoked (globalThis.__jacFormSubmitted)",
      globalThis.__jacFormSubmitted === true,
      `__jacFormSubmitted=${globalThis.__jacFormSubmitted}`);
  }
} else {
  check("submit button is enabled for the submit flow test",
    false,
    `disabled=${submitLive ? submitLive.disabled : "no button"}, isDirty check failed`);
}

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
  (failures.length ? `: ${failures.join(", ")}` : ""));
process.exit(failures.length ? 1 : 0);
""";

"""Combined harness for the P2 jsdom matrix (dynamic prop, ref e2e, callback prop).
Mounts three separate Solid apps in three root divs and asserts each scenario.
A plain (non-f) string so JS `${}`/`{}` need no escaping; `_BABEL_BUILD` compiles
every emitted `*.src.jsx` before any import."""
glob _P2_HARNESS: str = _BABEL_BUILD + """
import { JSDOM } from "jsdom";

const dom = new JSDOM(
  '<!DOCTYPE html><html><body></body></html>',
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

let render, dynpropApp, refApp, callbackApp;
try {
  ({ render } = await import("solid-js/web"));
  ({ app: dynpropApp } = await import("./dynprop.js"));
  ({ app: refApp } = await import("./ref_app.js"));
  ({ app: callbackApp } = await import("./callback.js"));
} catch (e) {
  check("runtime modules import (jsdom + --conditions=browser)", false,
    String((e && e.stack) || e));
  console.log("\\nFAILED: import error");
  process.exit(1);
}

// ---- P2.1: Dynamic prop / child reactivity ----------------------------------------
{
  const root = document.createElement("div");
  document.body.appendChild(root);
  try {
    render(() => dynpropApp(), root);
  } catch (e) {
    check("P2.1 dynprop: render mounts without throwing", false, String((e && e.stack) || e));
  }

  const display = () => root.querySelector('[data-testid="display"]');
  check("P2.1 dynprop: Display component renders",
    !!display(), `root=${root.innerHTML}`);

  if (display()) {
    check("P2.1 dynprop: initial value is 0",
      display().textContent.includes("0"),
      `got: ${JSON.stringify(display().textContent)}`);

    const btn = root.querySelector('[data-testid="inc"]');
    check("P2.1 dynprop: increment button present", !!btn);
    if (btn) {
      btn.click();
      await Promise.resolve();
      await Promise.resolve();
      check("P2.1 dynprop: value updates to 1 after click (reactive prop through child)",
        display().textContent.includes("1"),
        `got: ${JSON.stringify(display().textContent)}`);
    }
  }
}

// ---- P2.2: Explicit ref={...} end-to-end -----------------------------------------
{
  const root = document.createElement("div");
  document.body.appendChild(root);
  try {
    render(() => refApp(), root);
  } catch (e) {
    check("P2.2 ref: render mounts without throwing", false, String((e && e.stack) || e));
  }

  const target = root.querySelector('[data-testid="target"]');
  check("P2.2 ref: target button rendered", !!target, `root=${root.innerHTML}`);

  const statusEl = () => root.querySelector('[data-testid="ref-status"]');
  check("P2.2 ref: initial status is 'unset'",
    !!statusEl() && statusEl().textContent.includes("unset"),
    `got: ${statusEl() ? statusEl().textContent : "null"}`);

  const checkBtn = root.querySelector('[data-testid="check"]');
  check("P2.2 ref: check button rendered", !!checkBtn);
  if (checkBtn) {
    checkBtn.click();
    await Promise.resolve();
    await Promise.resolve();
    check("P2.2 ref: ref was populated (babel-preset-solid assigned the DOM element)",
      !!statusEl() && statusEl().textContent.includes("set"),
      `got: ${statusEl() ? statusEl().textContent : "null"}`);
  }
}

// ---- P2.3: Callback prop (plain fn, not reactive accessor) -----------------------
{
  const root = document.createElement("div");
  document.body.appendChild(root);
  try {
    render(() => callbackApp(), root);
  } catch (e) {
    check("P2.3 callback: render mounts without throwing", false, String((e && e.stack) || e));
  }

  const countEl = () => root.querySelector('[data-testid="click-count"]');
  check("P2.3 callback: click count element renders",
    !!countEl(), `root=${root.innerHTML}`);

  if (countEl()) {
    check("P2.3 callback: initial click count is 0",
      countEl().textContent.includes("0"),
      `got: ${JSON.stringify(countEl().textContent)}`);

    const childBtn = root.querySelector('[data-testid="child-btn"]');
    check("P2.3 callback: child button rendered", !!childBtn);
    if (childBtn) {
      childBtn.click();
      await Promise.resolve();
      await Promise.resolve();
      check("P2.3 callback: handler fires on click (count incremented to 1)",
        countEl().textContent.includes("1"),
        `got: ${JSON.stringify(countEl().textContent)}`);
      check("P2.3 callback: count is exactly 1 (fn not called spuriously as signal)",
        countEl().textContent.trim() === "Clicks: 1",
        `got: ${JSON.stringify(countEl().textContent)}`);
    }
  }
}

console.log(`\\n${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
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
        # Emitted JSX modules land as `*.src.jsx`; the harness babel-builds them to
        # `*.js` before mounting (cross-module imports already target `.js`).
        (work / "component.src.jsx").write_text(component_js, encoding="utf-8");
        (work / "jac_runtime.src.jsx").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.src.jsx").write_text(core_js, encoding="utf-8");
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

test "solid native control flow (<For>/<Show>) renders + reacts in jsdom (Branch 4)" {
    # End-to-end proof of Branch 4: the lifted keyed comprehension and view ternary
    # compile through `babel-preset-solid` and render as native `<For>`/`<Show>`
    # (not just emit plausible JSX strings — the unit tests pin the strings, this
    # pins the runtime behaviour). Same opt-in + toolchain as the counter test.
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = SolidBackend();
    component_js = with_runtime_globals(
        _compile_solid(os.path.join(FIXTURES, "solid_control_flow_app.cl.jac")), backend
    );
    runtime_path = resolve_client_runtime_cl_path("solid");
    runtime_js = _rewrite_core_specifier(_compile_solid(runtime_path));
    core_js = _compile_solid(
        str(Path(runtime_path).parent / "client_runtime_core.cl.jac")
    );
    for q in ['"', "'"] {
        component_js = component_js.replace(
            f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}"
        );
    }

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.src.jsx").write_text(component_js, encoding="utf-8");
        (work / "jac_runtime.src.jsx").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.src.jsx").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_CONTROL_FLOW_HARNESS, encoding="utf-8");
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
        # Pages/layout/runtime emit JSX → `*.src.jsx` (harness babel-builds them);
        # the entry and route manifest carry no JSX but ride the same `.src.jsx`
        # build path (a no-op transform) so every importable name ends in `.js`.
        (work / "home_page.src.jsx").write_text(home_js, encoding="utf-8");
        (work / "about_page.src.jsx").write_text(about_js, encoding="utf-8");
        (work / "dashboard_page.src.jsx").write_text(dash_js, encoding="utf-8");
        (work / "root_layout.src.jsx").write_text(layout_js, encoding="utf-8");
        (work / "_routes.src.jsx").write_text(manifest, encoding="utf-8");
        (work / "entry.src.jsx").write_text(entry_js, encoding="utf-8");
        (work / "jac_runtime.src.jsx").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.src.jsx").write_text(core_js, encoding="utf-8");
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

test "solid JacForm renders and validates in jsdom (TanStack Form end-to-end)" {
    # End-to-end proof of the TanStack Form migration for the Solid backend:
    # `JacForm` mounts correctly via `@tanstack/solid-form`, email validation
    # fires on blur (onBlur validator) and clears on onChange without a second
    # blur (`onTouched` approximation: onChange-only, error display gated on
    # isTouched), the checkbox and select branches render and accept change
    # events, the select value is reflected after handleChange, the radio branch
    # renders one input per enum option with correct initial state and marks the
    # clicked option checked, and the full submit flow (dirty → enabled →
    # onSubmit fires) is verified end-to-end. Same opt-in + toolchain as the
    # counter test.
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = SolidBackend();
    component_js = _wire_jac_runtime(
        with_runtime_globals(
            _compile_solid(os.path.join(FIXTURES, "solid_form_app.cl.jac")), backend
        )
    );
    runtime_path = resolve_client_runtime_cl_path("solid");
    runtime_js = _rewrite_core_specifier(_compile_solid(runtime_path));
    core_js = _compile_solid(
        str(Path(runtime_path).parent / "client_runtime_core.cl.jac")
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.src.jsx").write_text(component_js, encoding="utf-8");
        (work / "jac_runtime.src.jsx").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.src.jsx").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_FORM_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "solid-form-jsdom-test",
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
            cmd = [node_bin, "--conditions=browser", str(work / "harness.mjs")];
        } else {
            cmd = [bun, "--conditions=browser", "run", str(work / "harness.mjs")];
        }
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        detail = (run.stdout or "") + "\n" + (run.stderr or "");
        assert run.returncode == 0 , (
            f"form jsdom harness failed (exit {run.returncode}):\n{detail}"
        );
    }
}

test "solid P2 jsdom matrix: dynamic prop, ref e2e, and callback prop" {
    # End-to-end proof of the three remaining P2 jsdom matrix items:
    # 2.1 Dynamic prop / child reactivity: a parent's reactive signal flows
    #     through a component prop boundary and reactively updates the child DOM.
    # 2.2 Explicit ref={...}: babel-preset-solid assigns the DOM element to the
    #     let-bound ref variable; the handler reading it post-mount sees a truthy
    #     element, not null.
    # 2.3 Callback prop: a plain function passed as a component prop fires exactly
    #     once on click — Solid does NOT call it as a reactive accessor.
    # All three share one bun install (same _DEPS) for faster CI.
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = SolidBackend();
    runtime_path = resolve_client_runtime_cl_path("solid");
    runtime_js = _rewrite_core_specifier(_compile_solid(runtime_path));
    core_js = _compile_solid(
        str(Path(runtime_path).parent / "client_runtime_core.cl.jac")
    );

    dynprop_js = _wire_jac_runtime(
        with_runtime_globals(
            _compile_solid(os.path.join(FIXTURES, "solid_dynprop_app.cl.jac")), backend
        )
    );
    ref_js = _wire_jac_runtime(
        with_runtime_globals(
            _compile_solid(os.path.join(FIXTURES, "solid_ref_app.cl.jac")), backend
        )
    );
    callback_js = _wire_jac_runtime(
        with_runtime_globals(
            _compile_solid(os.path.join(FIXTURES, "solid_callback_app.cl.jac")), backend
        )
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "dynprop.src.jsx").write_text(dynprop_js, encoding="utf-8");
        (work / "ref_app.src.jsx").write_text(ref_js, encoding="utf-8");
        (work / "callback.src.jsx").write_text(callback_js, encoding="utf-8");
        (work / "jac_runtime.src.jsx").write_text(runtime_js, encoding="utf-8");
        (work / "client_runtime_core.src.jsx").write_text(core_js, encoding="utf-8");
        (work / "harness.mjs").write_text(_P2_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "solid-p2-jsdom-test",
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
            cmd = [node_bin, "--conditions=browser", str(work / "harness.mjs")];
        } else {
            cmd = [bun, "--conditions=browser", "run", str(work / "harness.mjs")];
        }
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        detail = (run.stdout or "") + "\n" + (run.stderr or "");
        assert run.returncode == 0 , (
            f"P2 jsdom harness failed (exit {run.returncode}):\n{detail}"
        );
    }
}
