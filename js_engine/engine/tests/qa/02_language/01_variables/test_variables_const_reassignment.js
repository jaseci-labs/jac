// VARIABLE_COMPREHENSIVE_TEST_PLAN §6 — VARP-C-RA-* (const reassignment hardening)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_const_reassignment.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function assertTypeError(fn, msg) {
    var threw = false;
    try {
        fn();
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, msg);
}

// --- VARP-C-RA-001: compound assignment operators
(function () {
    assertTypeError(function () {
        const x = 1;
        x += 2;
    }, "VARP-C-RA-001: const += throws TypeError");
    assertTypeError(function () {
        const x = 10;
        x -= 3;
    }, "VARP-C-RA-001: const -= throws TypeError");
    assertTypeError(function () {
        const x = 2;
        x *= 3;
    }, "VARP-C-RA-001: const *= throws TypeError");
    assertTypeError(function () {
        const x = 1;
        x &&= true;
    }, "VARP-C-RA-001: const &&= throws TypeError");
    assertTypeError(function () {
        const x = 0;
        x ||= 1;
    }, "VARP-C-RA-001: const ||= throws TypeError");
    assertTypeError(function () {
        const x = null;
        x ??= 1;
    }, "VARP-C-RA-001: const ??= throws TypeError");
})();

// --- VARP-C-RA-002: prefix and postfix ++ / --
(function () {
    assertTypeError(function () {
        const x = 1;
        ++x;
    }, "VARP-C-RA-002: prefix ++ on const");
    assertTypeError(function () {
        const x = 1;
        x++;
    }, "VARP-C-RA-002: postfix ++ on const");
    assertTypeError(function () {
        const x = 1;
        --x;
    }, "VARP-C-RA-002: prefix -- on const");
    assertTypeError(function () {
        const x = 1;
        x--;
    }, "VARP-C-RA-002: postfix -- on const");
})();

// --- VARP-C-RA-003: const captured in closure, reassigned in inner function
(function () {
    assertTypeError(function () {
        const x = 1;
        (function () {
            x = 2;
        }());
    }, "VARP-C-RA-003: closure capture const reassignment");
})();

// --- VARP-C-RA-004: destructuring assignment targets that are const
(function () {
    assertTypeError(function () {
        const x = 1;
        [x] = [2];
    }, "VARP-C-RA-004: array destructuring to const");
    assertTypeError(function () {
        const x = 1;
        ({ x: x } = { x: 2 });
    }, "VARP-C-RA-004: object destructuring to const");
})();

// --- VARP-C-RA-005: script-scope const reassignment
(function () {
    assertTypeError(function () {
        const G = 1;
        G = 2;
    }, "VARP-C-RA-005: script-scope const = throws");
    assertTypeError(function () {
        const H = 10;
        H++;
    }, "VARP-C-RA-005: script-scope const ++ throws");
})();

// --- VARP-C-RA-006: negative controls — mutation allowed, binding reassignment not
(function () {
    const obj = { key: "a" };
    obj.key = "b";
    assertEq(obj.key, "b", "VARP-C-RA-006: const object property mutation allowed");
    const arr = [1];
    arr.push(2);
    assertEq(arr.length, 2, "VARP-C-RA-006: const array push allowed");
})();

__jacDone();
