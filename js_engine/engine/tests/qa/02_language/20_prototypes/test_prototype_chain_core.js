// Plan: testing_plans/03_ecmascript_language/PROTOTYPES_AND_INHERITANCE_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: ECG-PRT-CORE (PRT-B-*, PRT-C-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_prototypes/test_prototype_chain_core.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

function hasOwn(o, p) {
    if (typeof Object.hasOwn === "function") {
        return Object.hasOwn(o, p);
    }
    return Object.prototype.hasOwnProperty.call(o, p);
}

// --- PRT-B-* ---
var b1 = {};
assertEq(Object.getPrototypeOf(b1), Object.prototype, "PRT-B-001: literal uses Object.prototype");
assertEq(Object.getPrototypeOf(Object.prototype), null, "PRT-B-001: chain ends at null");

function PB2() {}
PB2.prototype.k = "proto";
var b2 = new PB2();
b2.k = "own";
assertEq(b2.k, "own", "PRT-B-002: own shadows inherited");
delete b2.k;
assertEq(b2.k, "proto", "PRT-B-004: delete reveals inherited again");

assertEq(b1.missingPropFromPlan, undefined, "PRT-B-003: missing key is undefined");

assert("toString" in b1, "PRT-B-005: in sees inherited toString");
assert(!hasOwn(b1, "toString"), "PRT-B-005: hasOwn excludes inherited toString");

var mid = {};
Object.setPrototypeOf(mid, b1);
assert(Object.prototype.isPrototypeOf(mid), "PRT-B-006: Object.prototype isPrototypeOf mid");
assert(Object.prototype.isPrototypeOf(b1), "PRT-B-006: isPrototypeOf plain object");
assert(!mid.isPrototypeOf(Object.prototype), "PRT-B-006: reversed chain is false");

// --- PRT-C-* ---
function PC1() {}
PC1.prototype.tag = "proto";
var c1a = new PC1();
assertEq(Object.getPrototypeOf(c1a), PC1.prototype, "PRT-C-001: new links to constructor.prototype");
assertEq(c1a.tag, "proto", "PRT-C-001: instance reads prototype property");

var firstProto = PC1.prototype;
PC1.prototype = { tag: "second" };
var c1b = new PC1();
assertEq(c1a.tag, "proto", "PRT-C-002: old instance keeps old prototype chain");
assertEq(c1b.tag, "second", "PRT-C-002: new instance uses reassigned prototype");

function PC3() {
    return { returned: true };
}
var c3 = new PC3();
assertEq(c3.returned, true, "PRT-C-003: constructor may return object");
assert(!(c3 instanceof PC3), "PRT-C-003: returned object is not instanceof constructor");

var protoC4 = { z: 9 };
var c4 = Object.create(protoC4);
assertEq(Object.getPrototypeOf(c4), protoC4, "PRT-C-004: Object.create sets [[Prototype]]");
assertEq(Object.keys(c4).length, 0, "PRT-C-004: no own props by default");
assertEq(c4.z, 9, "PRT-C-004: inherited z");

var c5 = Object.create(null);
assertEq(Object.getPrototypeOf(c5), null, "PRT-C-005: null prototype object");
assert(!("toString" in c5), "PRT-C-005: no inherited Object methods");

assertThrows(
    function () {
        Object.create(undefined);
    },
    TypeError,
    "PRT-C-006: Object.create rejects non-object non-null prototype"
);

__jacDone();
