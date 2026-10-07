// Plan: testing_plans/03_ecmascript_language/PROTOTYPES_AND_INHERITANCE_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: ECG-PRT-MUT (PRT-M-*, PRT-V-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_prototypes/test_prototype_mutation.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

var mObj = { a: 1 };
var mProto = { b: 2 };
assertEq(Object.getPrototypeOf(mObj), Reflect.getPrototypeOf(mObj), "PRT-M-001: Object and Reflect agree");

var ret = Object.setPrototypeOf(mObj, mProto);
assert(ret === mObj, "PRT-M-002: setPrototypeOf returns receiver");
assertEq(mObj.b, 2, "PRT-M-002: lookup uses new prototype");

var same = Object.setPrototypeOf(mObj, mProto);
assert(same === mObj, "PRT-M-003: same prototype is no-op success");
assertEq(mObj.b, 2, "PRT-M-003: properties unchanged");

assertThrows(
    function () {
        Object.setPrototypeOf(null, {});
    },
    TypeError,
    "PRT-M-004: null receiver throws TypeError (RequireObjectCoercible)"
);

assertThrows(
    function () {
        Object.setPrototypeOf({}, 1);
    },
    TypeError,
    "PRT-M-005: primitive prototype throws TypeError"
);

var cycleA = {};
var cycleB = {};
Object.setPrototypeOf(cycleA, cycleB);
assertThrows(
    function () {
        Object.setPrototypeOf(cycleB, cycleA);
    },
    TypeError,
    "PRT-M-006: prototype cycle throws TypeError"
);

var locked = {};
Object.preventExtensions(locked);
assertThrows(
    function () {
        Object.setPrototypeOf(locked, {});
    },
    TypeError,
    "PRT-M-007: non-extensible cannot change prototype (Object API)"
);
assertEq(Reflect.setPrototypeOf(locked, {}), false, "PRT-M-007: Reflect returns false when blocked");

// PRT-M-008: __proto__ (Annex B)
var legacy = { x: 1 };
var legProto = { y: 2 };
legacy.__proto__ = legProto;
assertEq(Object.getPrototypeOf(legacy), legProto, "PRT-M-008: __proto__ setter matches setPrototypeOf");
assertEq(legacy.__proto__, legProto, "PRT-M-008: __proto__ getter matches getPrototypeOf");

// --- PRT-V-* ---
assertEq(Object.getPrototypeOf(Object.prototype), null, "PRT-V-001: Object.prototype has null proto");
assertEq(Object.getPrototypeOf(Function.prototype), Object.prototype, "PRT-V-002: Function.prototype chain");

assertThrows(
    function () {
        Object.setPrototypeOf(Object.prototype, {});
    },
    TypeError,
    "PRT-V-003: cannot setPrototypeOf Object.prototype"
);

function VF() {}
assertEq(Object.getPrototypeOf(VF), Function.prototype, "PRT-V-004: function object inherits Function.prototype");
assertEq(Object.getPrototypeOf(VF.prototype), Object.prototype, "PRT-V-004: .prototype object inherits Object.prototype");

var arr = [];
assert(arr instanceof Array, "PRT-V-005: array instanceof Array");
assert(arr instanceof Object, "PRT-V-005: array instanceof Object via chain");

__jacDone();
