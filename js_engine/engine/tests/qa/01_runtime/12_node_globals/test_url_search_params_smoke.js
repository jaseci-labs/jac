// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-U-001 (URL / URLSearchParams smoke)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_url_search_params_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof URL, "function", "NGL-U-001: URL constructor");
var u = new URL("https://example.com/path?q=1");
assertEq(u.hostname, "example.com", "NGL-U-001: URL parses host");
assertEq(typeof URLSearchParams, "function", "NGL-U-001: URLSearchParams");
var sp = new URLSearchParams("a=1&b=2");
assertEq(sp.get("a"), "1", "NGL-U-001: URLSearchParams get");

__jacDone();
