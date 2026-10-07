// Plan: testing_plans/03_ecmascript_language/PROTOTYPES_AND_INHERITANCE_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: ECG-PRT-PROXY (PRT-P-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_prototypes/test_proxy_prototype_invariants.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// PRT-P-001: extensible target — trap may report different prototype than target's internal slot
var target1 = {};
var fakeProto = { fake: true };
var p1 = new Proxy(target1, {
    getPrototypeOf: function () {
        return fakeProto;
    },
});
assertEq(Object.getPrototypeOf(p1), fakeProto, "PRT-P-001: proxy getPrototypeOf trap result when extensible");
assertEq(Object.getPrototypeOf(target1), Object.prototype, "PRT-P-001: target internal proto unchanged");

// PRT-P-002: trap returns non-object non-null
var p2 = new Proxy(
    {},
    {
        getPrototypeOf: function () {
            return 1;
        },
    }
);
assertThrows(
    function () {
        Object.getPrototypeOf(p2);
    },
    TypeError,
    "PRT-P-002: getPrototypeOf trap non-object throws TypeError"
);

// PRT-P-003: non-extensible target — trap must match actual prototype
var realP = {};
var target3 = Object.create(realP);
Object.preventExtensions(target3);
var p3 = new Proxy(target3, {
    getPrototypeOf: function () {
        return {};
    },
});
assertThrows(
    function () {
        Object.getPrototypeOf(p3);
    },
    TypeError,
    "PRT-P-003: wrong proto trap on non-extensible target throws TypeError"
);

// PRT-P-004: setPrototypeOf trap returns true but invariant violated on non-extensible target
var target4 = {};
Object.preventExtensions(target4);
var p4 = new Proxy(target4, {
    setPrototypeOf: function () {
        return true;
    },
});
assertThrows(
    function () {
        Reflect.setPrototypeOf(p4, {});
    },
    TypeError,
    "PRT-P-004: setPrototypeOf trap true when change impossible throws TypeError"
);

// PRT-P-005: Reflect.setPrototypeOf honors forwarding trap
var target5 = {};
var p5 = new Proxy(target5, {
    setPrototypeOf: function (t, newProto) {
        return Reflect.setPrototypeOf(t, newProto);
    },
});
var np = { k: 1 };
assertEq(Reflect.setPrototypeOf(p5, np), true, "PRT-P-005: Reflect returns true on successful set");
assertEq(Object.getPrototypeOf(target5), np, "PRT-P-005: target prototype updated");

__jacDone();
