// RT-001 through RT-005: Global primitive values
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/01_globals/test_primitive_values.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-001: globalThis
assert(typeof globalThis === "object", "RT-001: typeof globalThis === 'object'");
assert(globalThis === globalThis.globalThis, "RT-001: globalThis === globalThis.globalThis");
assert("undefined" in globalThis || typeof globalThis.undefined === "undefined",
    "RT-001: globalThis.undefined accessible");

// RT-002: undefined
assertEq(typeof undefined, "undefined", "RT-002: typeof undefined === 'undefined'");
assertEq(void 0, undefined, "RT-002: void 0 === undefined");
// non-writable: silent assignment should not change it
undefined = 5;
assertEq(typeof undefined, "undefined", "RT-002: undefined not writable");

// RT-003: NaN
assertEq(typeof NaN, "number", "RT-003: typeof NaN === 'number'");
assert(NaN !== NaN, "RT-003: NaN !== NaN");
assertEq(isNaN(NaN), true, "RT-003: isNaN(NaN) === true");
NaN = 0;
assert(isNaN(NaN), "RT-003: NaN not writable");

// RT-004: Infinity
assertEq(typeof Infinity, "number", "RT-004: typeof Infinity === 'number'");
assert(Infinity > 1e308, "RT-004: Infinity > 1e308");
assert(-Infinity < -1e308, "RT-004: -Infinity < -1e308");
Infinity = 0;
assert(Infinity > 1e308, "RT-004: Infinity not writable");

// RT-005: null
assertEq(typeof null, "object", "RT-005: typeof null === 'object'");
assert(null == undefined, "RT-005: null == undefined");
assert(null !== undefined, "RT-005: null !== undefined");

__jacDone();
