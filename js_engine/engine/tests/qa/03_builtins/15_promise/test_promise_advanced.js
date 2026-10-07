// PROM-020 through PROM-023: Advanced Promise patterns
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/15_promise/test_promise_advanced.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var passed = 0;
var total = 5;

function done() {
    passed++;
    if (passed === total) __jacDone();
}

// PROM-020: then chaining depth — 5+ levels
Promise.resolve(1)
    .then(function(x) { return x + 1; })
    .then(function(x) { return x + 1; })
    .then(function(x) { return x + 1; })
    .then(function(x) { return x + 1; })
    .then(function(x) { return x + 1; })
    .then(function(x) {
        assertEq(x, 6, "PROM-020: 5 levels of chaining yields 6");
        done();
    });

// PROM-021: catch recovery — return value from catch continues chain
Promise.reject(new Error("oops"))
    .catch(function(e) {
        assert(e.message === "oops", "PROM-021: catch receives rejection reason");
        return "recovered";
    })
    .then(function(val) {
        assertEq(val, "recovered", "PROM-021: value from catch continues chain");
        done();
    });

// PROM-022: finally pass-through — fulfilled value preserved
Promise.resolve("original")
    .finally(function() {
        // should NOT affect the value
        return "ignored";
    })
    .then(function(val) {
        assertEq(val, "original", "PROM-022: finally preserves fulfilled value");
        done();
    });

// PROM-022b: finally pass-through — rejected reason preserved
Promise.reject(new Error("fail"))
    .finally(function() { /* no-op */ })
    .catch(function(e) {
        assertEq(e.message, "fail", "PROM-022: finally preserves rejection reason");
        done();
    });

// PROM-023: Thenable resolution — object with .then method
var thenable = {
    then: function(resolve) { resolve(42); }
};
Promise.resolve(thenable).then(function(val) {
    assertEq(val, 42, "PROM-023: thenable is treated as a Promise");
    done();
});

// Timeout safety — if not all promises resolve, exit with error
setTimeout(function() {
    if (passed < total) {
        console.error("FAIL: only " + passed + "/" + total + " promise tests completed (timeout)");
        __reg.bump(); return;
    }
}, 2000);
