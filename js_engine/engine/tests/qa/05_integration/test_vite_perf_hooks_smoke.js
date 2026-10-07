// VIT-PHK-001: Vite V-14 smoke — node:perf_hooks for timing middleware paths
var ph = require("node:perf_hooks");
var performanceFromModule = ph.performance;

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_perf_hooks_smoke.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}

assert(typeof performanceFromModule === "object", "VIT-PHK-001: destructured performance");
assert(typeof performanceFromModule.now === "function", "VIT-PHK-001: performance.now");
assert(performanceFromModule === performance, "VIT-PHK-001: same object as global performance");
assert(performanceFromModule.now() > 0, "VIT-PHK-001: now() returns positive");

__jacDone();
