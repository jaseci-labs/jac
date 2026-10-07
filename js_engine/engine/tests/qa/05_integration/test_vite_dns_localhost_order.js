"use strict";
// Vite getLocalhostAddressIfDiffersFromDNS-style dual lookup

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_dns_localhost_order.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var dns = require("dns").promises;

if (typeof dns.getDefaultResultOrder === "function" &&
    dns.getDefaultResultOrder() === "verbatim") {
    __jacDone();
}

Promise.all([
    dns.lookup("localhost"),
    dns.lookup("localhost", { verbatim: true })
]).then(function (pair) {
    var a = pair[0];
    var b = pair[1];
    assert(a && b, "both lookups resolved");
    __jacDone();
}).catch(function (e) {
    console.error(String(e));
    __reg.bump();
    __jacDone();
});

setTimeout(function () {
    __reg.bump();
    __jacDone();
}, 5000);
