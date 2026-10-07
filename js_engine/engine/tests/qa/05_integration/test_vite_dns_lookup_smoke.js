// VIT-DNS-001: Vite V-13 smoke
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_dns_lookup_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}

var done = false;
require("dns").promises.lookup("localhost").then(function (r) {
    assertEq(r.address, "127.0.0.1", "VIT-DNS-001");
    done = true;
    __jacDone();
});
setTimeout(function () {
    if (!done) {
        assert(false, "VIT-DNS-001: timeout");
        __jacDone();
    }
}, 2000);
