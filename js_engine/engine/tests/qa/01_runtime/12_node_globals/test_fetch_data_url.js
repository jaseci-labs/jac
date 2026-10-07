// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-F-* (fetch data URL)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_fetch_data_url.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function nglFetchDataUrl() {
    if (typeof fetch !== "function") {
        console.log("skip NGL-F-*: fetch not available");
        return;
    }
    assertEq(typeof fetch, "function", "NGL-F-001: typeof fetch");
    assertEq(typeof Request, "function", "NGL-F-002: Request");
    assertEq(typeof Response, "function", "NGL-F-002: Response");
    assertEq(typeof Headers, "function", "NGL-F-002: Headers");
    var res = await fetch("data:text/plain;charset=utf-8,hello-ngl");
    if (!res || typeof res.status !== "number") {
        console.log("skip NGL-F-003: fetch data URL response incomplete");
        return;
    }
    assertEq(res.status, 200, "NGL-F-003: data URL response status");
    var txt = await res.text();
    assertEq(txt, "hello-ngl", "NGL-F-003: data URL body");
}

nglFetchDataUrl()
    .then(function () {
        __jacDone();
    })
    .catch(function (e) {
        console.error("FAIL: NGL-F async: " + e);
        __reg.bump();
        __jacDone();
    });
