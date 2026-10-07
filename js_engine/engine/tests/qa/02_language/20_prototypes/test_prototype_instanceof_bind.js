// Plan: testing_plans/03_ecmascript_language/PROTOTYPES_AND_INHERITANCE_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: ECG-PRT-OPER (PRT-O-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_prototypes/test_prototype_instanceof_bind.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

function CO1() {}
var o1 = new CO1();
assert(o1 instanceof CO1, "PRT-O-001: instanceof direct constructor");
assert(o1 instanceof Object, "PRT-O-001: instanceof walks to Object");

var oldProto = CO1.prototype;
CO1.prototype = { marker: 1 };
var oAfter = new CO1();
assertEq(oAfter.marker, 1, "PRT-O-002: new instance uses replaced prototype");
assert(!(o1 instanceof CO1), "PRT-O-002: old instance not instanceof after prototype replace");
CO1.prototype = oldProto;

assertThrows(
    function () {
        void ({} instanceof {});
    },
    TypeError,
    "PRT-O-003: non-callable RHS instanceof throws TypeError"
);

function CO4() {}
// Non-writable inherited @@hasInstance on functions — must define own property
Object.defineProperty(CO4, Symbol.hasInstance, {
    value: function (inst) {
        return inst && inst.flag === 7;
    },
    configurable: true,
});
var tagged = { flag: 7 };
var notTagged = { flag: 0 };
assert(tagged instanceof CO4, "PRT-O-004: Symbol.hasInstance overrides default");
assert(!(notTagged instanceof CO4), "PRT-O-004: hasInstance can return false");

function CO5() {}
var bound = CO5.bind(null);
var inst5 = new CO5();
assert(inst5 instanceof bound, "PRT-O-005: new target instanceof bound constructor");

assertThrows(
    function () {
        void ({} instanceof (() => {}));
    },
    TypeError,
    "PRT-O-006: arrow function RHS — non-object prototype — instanceof throws TypeError"
);

__jacDone();
