// DESC-001 through DESC-010: Property descriptors
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/13_descriptors/test_descriptors.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// DESC-001: data descriptor defaults
var d1 = {};
Object.defineProperty(d1, "prop", { value: 42 });
var desc1 = Object.getOwnPropertyDescriptor(d1, "prop");
assertEq(desc1.value,        42,    "DESC-001: value");
assertEq(desc1.writable,     false, "DESC-001: writable defaults false");
assertEq(desc1.enumerable,   false, "DESC-001: enumerable defaults false");
assertEq(desc1.configurable, false, "DESC-001: configurable defaults false");

// DESC-002: accessor descriptor (get/set)
var d2 = { _x: 0 };
Object.defineProperty(d2, "x", {
    get: function() { return this._x; },
    set: function(v) { this._x = v * 2; },
    enumerable: true,
    configurable: true
});
assertEq(d2.x, 0,   "DESC-002: read triggers getter");
d2.x = 5;
assertEq(d2.x, 10,  "DESC-002: write triggers setter (x2)");
var desc2 = Object.getOwnPropertyDescriptor(d2, "x");
assert(typeof desc2.get === "function", "DESC-002: descriptor has get");
assert(typeof desc2.set === "function", "DESC-002: descriptor has set");

// DESC-003: writable: false — assignment silently fails (or throws in strict)
var d3 = {};
Object.defineProperty(d3, "readOnly", { value: 1, writable: false, configurable: true });
d3.readOnly = 999; // silent fail in non-strict
assertEq(d3.readOnly, 1, "DESC-003: writable:false prevents assignment");

// DESC-004: enumerable: false — hidden from for-in and Object.keys
var d4 = { visible: 1 };
Object.defineProperty(d4, "hidden", { value: 2, enumerable: false });
var d4keys = Object.keys(d4);
assertEq(d4keys.length, 1,       "DESC-004: Object.keys hides non-enumerable");
assertEq(d4keys[0], "visible",   "DESC-004: only visible key in Object.keys");
var d4forIn = [];
for (var k in d4) { d4forIn.push(k); }
assertEq(d4forIn.length, 1, "DESC-004: for-in hides non-enumerable");
// but property is still there
assertEq(d4.hidden, 2, "DESC-004: non-enumerable still readable by name");

// DESC-005: configurable: false — cannot delete or re-configure
var d5 = {};
Object.defineProperty(d5, "locked", { value: "x", configurable: false, writable: true });
assertEq(delete d5.locked, false, "DESC-005: delete non-configurable returns false");
assertEq(d5.locked, "x", "DESC-005: property still there after failed delete");
var redefineThrew = false;
try {
    Object.defineProperty(d5, "locked", { enumerable: true });
} catch(e) {
    redefineThrew = true;
}
assert(redefineThrew, "DESC-005: redefining non-configurable throws TypeError");

// DESC-006: defineProperty — new, redefine, multiple flags
var d6 = {};
Object.defineProperty(d6, "a", { value: 1, writable: true, enumerable: true, configurable: true });
assertEq(d6.a, 1, "DESC-006: new property via defineProperty");
Object.defineProperty(d6, "a", { value: 2 }); // redefine (configurable=true)
assertEq(d6.a, 2, "DESC-006: redefine value (configurable)");

// DESC-007: defineProperties
var d7 = {};
Object.defineProperties(d7, {
    x: { value: 10, writable: true, enumerable: true, configurable: true },
    y: { value: 20, writable: true, enumerable: true, configurable: true }
});
assertEq(d7.x, 10, "DESC-007: defineProperties x");
assertEq(d7.y, 20, "DESC-007: defineProperties y");

// DESC-008: getOwnPropertyDescriptor — undefined for missing
var d8 = { z: 99 };
var desc8 = Object.getOwnPropertyDescriptor(d8, "z");
assertEq(desc8.value, 99, "DESC-008: descriptor value");
var miss = Object.getOwnPropertyDescriptor(d8, "missing");
assertEq(miss, undefined, "DESC-008: undefined for missing property");

// DESC-009: getter/setter in object literals
var d9 = {
    _v: 0,
    get val() { return this._v; },
    set val(n) { this._v = n + 1; }
};
assertEq(d9.val, 0,  "DESC-009: getter in literal");
d9.val = 9;
assertEq(d9.val, 10, "DESC-009: setter in literal (+1)");

// DESC-010: Object.freeze
var d10 = { a: 1, b: 2 };
Object.freeze(d10);
d10.a = 99;    // silent fail
d10.c = 3;     // silent fail
delete d10.b;  // silent fail
assertEq(d10.a, 1,         "DESC-010: freeze prevents mutation");
assertEq(d10.b, 2,         "DESC-010: freeze prevents delete");
assertEq(d10.c, undefined, "DESC-010: freeze prevents addition");
var frozenDesc = Object.getOwnPropertyDescriptor(d10, "a");
assertEq(frozenDesc.writable,     false, "DESC-010: freeze sets writable:false");
assertEq(frozenDesc.configurable, false, "DESC-010: freeze sets configurable:false");

__jacDone();
