// Phase 1C — extended Proxy trap invariants (PRT-T-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
  "regression/02_language/20_prototypes/test_proxy_trap_invariants_extended.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// PRT-T-001: has trap cannot hide non-configurable property
(function prt_t001() {
    var t = {};
    Object.defineProperty(t, "a", { value: 1, configurable: false });
    var p = new Proxy(t, {
        has: function () {
            return false;
        },
    });
    assertThrows(
        function () {
            return "a" in p;
        },
        TypeError,
        "PRT-T-001: has trap false on non-configurable"
    );
})();

// PRT-T-002: symbol keys reach get trap as symbols
(function prt_t002() {
    var s = Symbol("sym");
    var seen = "";
    var p = new Proxy({}, {
        get: function (_t, k) {
            seen = typeof k;
            return 42;
        },
    });
    assertEq(p[s], 42, "PRT-T-002: get trap return");
    assertEq(seen, "symbol", "PRT-T-002: get trap key type");
})();

// PRT-T-003: set trap cannot accept change to non-writable non-configurable data property
(function prt_t003() {
    var t = {};
    Object.defineProperty(t, "x", { value: 1, writable: false, configurable: false });
    var p = new Proxy(t, {
        set: function () {
            return true;
        },
    });
    assertThrows(
        function () {
            Reflect.set(p, "x", 2);
        },
        TypeError,
        "PRT-T-003: reflect set throws on invariant violation"
    );
    assertEq(t.x, 1, "PRT-T-003: target unchanged");
})();

// PRT-T-004: Reflect.defineProperty via proxy with defineProperty trap
(function prt_t004() {
    var t = {};
    var called = false;
    var p = new Proxy(t, {
        defineProperty: function (target, key, desc) {
            called = true;
            assertEq(key, "k", "PRT-T-004: trap key");
            return true;
        },
    });
    assert(
        Reflect.defineProperty(p, "k", { value: 9, writable: true, configurable: true }),
        "PRT-T-004: reflect defineProperty"
    );
    assert(called, "PRT-T-004: trap invoked");
})();

// PRT-T-005: preventExtensions trap + Object.preventExtensions
(function prt_t005() {
    var t = {};
    var p = new Proxy(t, {
        preventExtensions: function (target) {
            Object.preventExtensions(target);
            return true;
        },
    });
    Object.preventExtensions(p);
    assertEq(Object.isExtensible(p), false, "PRT-T-005: proxy not extensible");
})();

// PRT-T-006: isExtensible trap must match target
(function prt_t006() {
    var t = {};
    var p = new Proxy(t, {
        isExtensible: function (target) {
            return Object.isExtensible(target);
        },
    });
    assertEq(Object.isExtensible(p), true, "PRT-T-006: extensible");
})();

__jacDone();
