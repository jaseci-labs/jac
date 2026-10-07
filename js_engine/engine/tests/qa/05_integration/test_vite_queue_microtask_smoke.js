// VIT-QM-001: Vite V-18 smoke — queueMicrotask before macrotask (plugin async plumbing)
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_queue_microtask_smoke.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}

assert(typeof queueMicrotask === "function", "VIT-QM-001: queueMicrotask is function");

var order = [];
queueMicrotask(function () {
    order.push("microtask");
});
setTimeout(function () {
    order.push("timeout");
    assert(order.indexOf("microtask") < order.indexOf("timeout"), "VIT-QM-001: microtask before timeout");
    __jacDone();
}, 25);
