// Optional chaining with multi-step tail access
//
// When the root object is null or undefined the entire property chain that
// follows the ?. operator must evaluate to undefined — including any plain
// dot-accesses appended after the optional step.  When the root is non-null,
// all tail steps must execute normally, and an intermediate null in the tail
// throws a TypeError (because those accesses are not optional).

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/04_expressions/test_optional_chaining_tail.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

// OC-TAIL-001: null root short-circuits a single tail step
var n1 = null;
__reg.assertEq(n1?.foo.bar, undefined,  "OC-TAIL-001: null?.foo.bar === undefined");

// OC-TAIL-002: null root short-circuits two tail steps
var n2 = null;
__reg.assertEq(n2?.a.b.c, undefined,    "OC-TAIL-002: null?.a.b.c === undefined");

// OC-TAIL-003: undefined root short-circuits tail steps
var n3 = undefined;
__reg.assertEq(n3?.x.y, undefined,      "OC-TAIL-003: undefined?.x.y === undefined");

// OC-TAIL-004: non-null root traverses all tail steps
var o4 = { a: { b: { c: 99 } } };
__reg.assertEq(o4?.a.b.c, 99,           "OC-TAIL-004: non-null?.a.b.c returns leaf value");

// OC-TAIL-005: computed tail after null root short-circuits
var n5 = null;
__reg.assertEq(n5?.items[0], undefined, "OC-TAIL-005: null?.items[0] === undefined");

// OC-TAIL-006: intermediate null in tail throws (tail access is not optional)
var o6 = { a: null };
var threw6 = false;
try { o6?.a.b; } catch (e) { threw6 = true; }
__reg.assert(threw6,                    "OC-TAIL-006: non-null root with null intermediate throws");

// OC-TAIL-007: double optional — each ?. has its own short-circuit
var n7 = null;
__reg.assertEq(n7?.a?.b.c, undefined,  "OC-TAIL-007: null?.a?.b.c === undefined");

// OC-TAIL-008: nullish-coalescing with short-circuited chain
var n8 = null;
__reg.assertEq(n8?.settings.timeout ?? 30, 30, "OC-TAIL-008: null?.settings.timeout ?? 30 === 30");

// OC-TAIL-009: non-null root + nullish-coalescing
var o9 = { settings: { timeout: 5 } };
__reg.assertEq(o9?.settings.timeout ?? 30, 5,  "OC-TAIL-009: obj?.settings.timeout ?? 30 === 5");

__jacDone();
