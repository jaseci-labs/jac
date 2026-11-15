// Drives the client error reporters under a stub page and counts the reports
// that would reach POST /cl/__error__. Prints one JSON line of results.
//
//   node client_error_budget_harness.mjs runtime <client_runtime_core.js>
//   node client_error_budget_harness.mjs native <client_react_core.js>
//   node client_error_budget_harness.mjs inline <early-handler-script.js>
//   node client_error_budget_harness.mjs handoff <client_runtime_core.js> <early-handler-script.js>
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const [mode, target, inlineTarget] = process.argv.slice(2);
const START = 1_700_000_000_000;
const sent = [];
let now = START;
Date.now = () => now;
globalThis.fetch = (url, init) => {
  sent.push({ endpoint: url, ...JSON.parse(init.body) });
  return Promise.resolve({ ok: true });
};
// As in a browser, `window` is the global object, so `window.x` and
// `globalThis.x` are the same property.
globalThis.window = globalThis;

// The stack the jachammer flood carried (jacBuilder#2354).
const EXTENSION_STACK = [
  "TypeError: Cannot read properties of undefined (reading 'M_ID')",
  "    at Y (chrome-extension://eppiocemhmnlbhjplcgkofciiegomcon/executors/200.js:1:761)",
  "    at E (chrome-extension://eppiocemhmnlbhjplcgkofciiegomcon/executors/200.js:1:1442)",
].join("\n");
const FIREFOX_EXTENSION_STACK = [
  "Y@moz-extension://0a1b2c3d/content.js:1:761",
  "E@moz-extension://0a1b2c3d/content.js:1:1442",
].join("\n");
const SAFARI_EXTENSION_STACK = [
  "Y@safari-web-extension://0A1B2C3D/content.js:1:761",
  "global code@safari-web-extension://0A1B2C3D/content.js:3:4",
].join("\n");
// The message names an app URL; every frame is still the extension's.
const EXTENSION_STACK_WITH_URL_MESSAGE = [
  "Error: Request failed for https://app.test/api/data",
  "    at Y (chrome-extension://abc/inject.js:1:5)",
].join("\n");
// Engine-internal frames between the extension's own say nothing about whose
// code threw.
const EXTENSION_STACK_WITH_ENGINE_FRAMES = [
  "TypeError: Cannot read properties of undefined (reading 'M_ID')",
  "    at Y (chrome-extension://abc/inject.js:1:5)",
  "    at new Promise (<anonymous>)",
  "    at async Promise.all (index 0)",
  "    at Array.forEach (native)",
].join("\n");
const SAFARI_EXTENSION_STACK_WITH_NATIVE_FRAME = [
  "Y@safari-web-extension://0A1B2C3D/content.js:1:761",
  "forEach@[native code]",
  "global code@safari-web-extension://0A1B2C3D/content.js:3:4",
].join("\n");
const APP_STACK = "TypeError: boom\n    at render (https://app.test/static/client.js:1:200)";
const MIXED_STACK = [
  "TypeError: boom",
  "    at hook (chrome-extension://abc/inject.js:1:5)",
  "    at render (https://app.test/static/client.js:1:200)",
].join("\n");
// App frames whose location is not a scheme://host URL.
const MIXED_STACK_WITH_BLOB_FRAME = [
  "TypeError: boom",
  "    at hook (chrome-extension://abc/inject.js:1:5)",
  "    at render (blob:https://app.test/id:1:200)",
].join("\n");
const FIREFOX_MIXED_STACK_WITH_BLOB_FRAME = [
  "hook@moz-extension://0a1b2c3d/content.js:1:5",
  "render@blob:https://app.test/id:1:200",
].join("\n");

function errorWith(message, stack) {
  const err = new Error(message);
  err.stack = stack;
  return err;
}

function rejection(message, stack) {
  const event = new Event("unhandledrejection");
  event.reason = errorWith(message, stack);
  window.dispatchEvent(event);
}

function windowError(message, error, filename) {
  const event = new Event("error");
  Object.assign(event, { message, error, filename });
  window.dispatchEvent(event);
}

function times(n, fn) {
  for (let i = 0; i < n; i++) fn(i);
}

// A fresh page: new event target, no handlers installed, an empty budget.
function newPage() {
  const events = new EventTarget();
  window.addEventListener = events.addEventListener.bind(events);
  window.dispatchEvent = events.dispatchEvent.bind(events);
  window.location = { href: "https://app.test/project/p1" };
  delete globalThis.__jacErrorHandlersInstalled;
  delete globalThis.__jacErrorReportBudget;
  now = START;
  sent.length = 0;
}

const loadCore = async (path) => import(pathToFileURL(path).href);
const runInline = (path) => {
  const source = readFileSync(path, "utf8");
  return () => new Function(source)();
};

let install;
if (mode === "runtime") {
  const core = await loadCore(target);
  install = () => core.__jacInstallErrorHandlers();
} else if (mode === "native") {
  const core = await loadCore(target);
  globalThis.__jacGetApiBaseUrl__ = () => "";
  // Stands in for the ErrorUtils global handler client_runtime_native installs.
  install = () => {
    const report = (err) => core.__jacReportError(err.message, err.stack, "", "ErrorUtils");
    window.addEventListener("unhandledrejection", (event) => report(event.reason));
    window.addEventListener("error", (event) => report(event.error ?? { message: event.message, stack: "" }));
  };
} else if (mode === "inline") {
  install = runInline(target);
} else if (mode === "handoff") {
  // The served page: the early handler runs first, then the bundle installs
  // the runtime's handlers, all inside one minute.
  const core = await loadCore(target);
  const installInline = runInline(inlineTarget);
  newPage();
  installInline();
  times(10, (i) => rejection(`early ${i}`, APP_STACK));
  const early = sent.length;
  core.__jacInstallErrorHandlers();
  times(10, (i) => rejection(`late ${i}`, APP_STACK));
  rejection("early 0", APP_STACK);
  const sameMinute = sent.length - early;
  now += 60_000;
  times(10, (i) => rejection(`later ${i}`, APP_STACK));
  const nextMinute = sent.length - early - sameMinute;
  console.log(JSON.stringify({ early, sameMinute, nextMinute }));
  process.exit(0);
} else {
  throw new Error(`unknown mode: ${mode}`);
}

function scenario(fire) {
  newPage();
  install();
  fire();
  return { sent: sent.length, first: sent[0] ?? null };
}

const results = {
  extensionRejections: scenario(() =>
    times(1000, () => rejection("Cannot read properties of undefined (reading 'M_ID')", EXTENSION_STACK)),
  ),
  firefoxExtensionRejections: scenario(() =>
    times(1000, () => rejection("x is undefined", FIREFOX_EXTENSION_STACK)),
  ),
  safariExtensionRejections: scenario(() =>
    times(1000, () => rejection("x is undefined", SAFARI_EXTENSION_STACK)),
  ),
  extensionStackWithEngineFrames: scenario(() =>
    times(1000, () => rejection("Cannot read properties of undefined (reading 'M_ID')", EXTENSION_STACK_WITH_ENGINE_FRAMES)),
  ),
  safariExtensionStackWithNativeFrame: scenario(() =>
    times(1000, () => rejection("x is undefined", SAFARI_EXTENSION_STACK_WITH_NATIVE_FRAME)),
  ),
  extensionStackWithUrlMessage: scenario(() =>
    times(100, () => rejection("Request failed for https://app.test/api/data", EXTENSION_STACK_WITH_URL_MESSAGE)),
  ),
  extensionScriptWithoutStack: scenario(() =>
    times(100, () => windowError("Script error.", null, "chrome-extension://abc/content.js")),
  ),
  identicalAppErrors: scenario(() => times(1000, () => rejection("boom", APP_STACK))),
  mixedStack: scenario(() => rejection("boom", MIXED_STACK)),
  mixedStackWithBlobFrame: scenario(() => rejection("boom", MIXED_STACK_WITH_BLOB_FRAME)),
  firefoxMixedStackWithBlobFrame: scenario(() => rejection("boom", FIREFOX_MIXED_STACK_WITH_BLOB_FRAME)),
  appWindowError: scenario(() =>
    windowError("boom", errorWith("boom", APP_STACK), "https://app.test/static/client.js"),
  ),
  distinctAppErrors: scenario(() => times(1000, (i) => rejection(`boom ${i}`, APP_STACK))),
  distinctAppErrorsOverTwoMinutes: scenario(() => {
    times(1000, (i) => rejection(`boom ${i}`, APP_STACK));
    now += 60_000;
    times(1000, (i) => rejection(`later ${i}`, APP_STACK));
  }),
  // One report at the start, nine at 59s, then ten more at 60s: only the
  // first has left the trailing minute by then.
  burstAcrossMinuteBoundary: scenario(() => {
    rejection("start", APP_STACK);
    now += 59_000;
    times(9, (i) => rejection(`edge ${i}`, APP_STACK));
    now += 1_000;
    times(10, (i) => rejection(`after ${i}`, APP_STACK));
  }),
  // Twenty new errors a minute for half an hour, then an early one again.
  distinctAppErrorsOverHalfAnHour: scenario(() => {
    times(30, (minute) => {
      times(20, (i) => rejection(`minute ${minute} error ${i}`, APP_STACK));
      now += 60_000;
    });
    times(5, () => rejection("minute 0 error 0", APP_STACK));
  }),
  afterRuntimeHandlersInstalled: scenario(() => {
    window.__jacErrorHandlersInstalled = true;
    times(10, (i) => rejection(`boom ${i}`, APP_STACK));
  }),
};

console.log(JSON.stringify(results));
