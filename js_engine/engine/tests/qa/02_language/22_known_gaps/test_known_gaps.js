// GAP-001 through GAP-015: Known gaps — verify graceful failure (no crash, no hang)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/22_known_gaps/test_known_gaps.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// GAP-001: RegExp literals — no crash; js_engine may return string/object/undefined
var reType = typeof /abc/;
assert(reType === "object" || reType === "undefined" || reType === "string",
    "GAP-001: regex literal does not crash (type: " + reType + ")");

// GAP-002: eval() — must be accessible as a function; throws or is no-op in js_engine
assertEq(typeof eval, "function", "GAP-002: eval is typeof function");
var evalRan = false;
try { eval("evalRan = true;"); } catch(e) { /* eval disabled in js_engine */ }
// On node evalRan === true; on js_engine evalRan === false — both are valid, no crash

// GAP-003: Optional chaining ?. — returns undefined in js_engine, correct value in node
var obj3 = { a: { b: 42 } };
var nullRef = null;
assertEq(nullRef?.prop, undefined, "GAP-003: null?.prop === undefined (both engines)");
var deep = obj3?.a?.b;
assert(deep === 42 || deep === undefined,
    "GAP-003: obj?.a?.b is 42 (node) or undefined (js_engine gap), no crash");

// GAP-004: Switch fall-through — js_engine has implicit break, node has standard fall-through
var fallArr = [];
switch(1) {
    case 1: fallArr.push("one");  // no break
    case 2: fallArr.push("two");  // no break
    default: fallArr.push("def");
}
assert(fallArr.length >= 1, "GAP-004: at least first case ran, no crash");
// Standard: ["one","two","def"]; js_engine: ["one"] — both are non-empty, no crash

// GAP-005: finally blocks — may not execute in js_engine; catch still works
var caughtGap5 = false;
var finallyRan = false;
try {
    throw new Error("g5");
} catch(e) {
    caughtGap5 = true;
} finally {
    finallyRan = true;
}
assert(caughtGap5, "GAP-005: catch works (even if finally is a gap)");
// finally may or may not run in js_engine — no crash either way

// GAP-006: BigInt — no crash; operations may not work
var bigType = typeof 9007199254740993n;
assert(bigType === "bigint" || bigType === "undefined" || bigType === "number",
    "GAP-006: BigInt literal does not crash");

// GAP-007: Proxy / Reflect — may be undefined
assert(typeof Proxy === "undefined" || typeof Proxy === "function",
    "GAP-007: Proxy is undefined or function, no crash");
assert(typeof Reflect === "undefined" || typeof Reflect === "object",
    "GAP-007: Reflect is undefined or object, no crash");

// GAP-008: WeakRef / FinalizationRegistry — may be undefined
assert(typeof WeakRef === "undefined" || typeof WeakRef === "function",
    "GAP-008: WeakRef is undefined or function");
assert(typeof FinalizationRegistry === "undefined" || typeof FinalizationRegistry === "function",
    "GAP-008: FinalizationRegistry is undefined or function");

// GAP-009: SharedArrayBuffer / Atomics — may be undefined
assert(typeof SharedArrayBuffer === "undefined" || typeof SharedArrayBuffer === "function",
    "GAP-009: SharedArrayBuffer is undefined or function");
assert(typeof Atomics === "undefined" || typeof Atomics === "object",
    "GAP-009: Atomics is undefined or object");

// GAP-010: with statement — js_engine silently skips (tokenized, not parsed)
// Can't test directly (would be a syntax error in strict mode; parser may reject it)
// Just verify no crash by checking typeof with as a keyword (accessed in non-strict expression)
assert(true, "GAP-010: with statement presence acknowledged (no inline test possible)");

// GAP-011: new.target — construct vs ordinary call
function NewTargetTest() {
    return new.target;
}
assert(new NewTargetTest() === NewTargetTest,
    "GAP-011: new.target === constructor under `new`");
assert(NewTargetTest() === undefined,
    "GAP-011: new.target === undefined under ordinary call");

// GAP-012: import.meta — parsed but may not be populated; no crash
// Can't test import.meta in CJS context (it would be a syntax error or undefined)
// Just verify the engine doesn't crash when the surrounding code runs.
assert(true, "GAP-012: import.meta (not testable in CJS, no crash)");

// GAP-013: Unicode identifiers — ASCII-only; accessing non-ASCII names is still fine via []
var obj13 = {};
obj13["café"] = "coffee";
assertEq(obj13["café"], "coffee", "GAP-013: non-ASCII string key accessible via bracket notation");
// ASCII identifiers always work
var αVar = 1; // May or may not parse in js_engine
assert(true, "GAP-013: no crash from unicode identifier attempt");

// GAP-014: Array sort with compareFn — ignored in js_engine, default sort works
var arr14 = [3, 1, 4, 1, 5, 9, 2, 6];
arr14.sort();
// Default sort (lexicographic): 1,1,2,3,4,5,6,9
assertEq(arr14[0], 1, "GAP-014: default sort works");
// sort with compareFn — may be ignored in js_engine
var nums = [10, 9, 2, 1, 11];
nums.sort(function(a, b) { return a - b; });
// On node: [1,2,9,10,11]; on js_engine with ignored compareFn: lexicographic [1,10,11,2,9]
assert(nums.length === 5, "GAP-014: sort with compareFn doesn't crash");

// GAP-015: JSON reviver/replacer — largely ignored in js_engine; parse/stringify still work
var parsed = JSON.parse('{"a":1,"b":2}', function(k, v) { return typeof v === "number" ? v * 2 : v; });
// On node: {a:2, b:4}; on js_engine (reviver ignored): {a:1, b:2}
assert(parsed.a === 1 || parsed.a === 2, "GAP-015: JSON.parse with reviver works (may ignore reviver)");

var obj15 = { x: 1, y: 2, secret: "hide" };
var stringified = JSON.stringify(obj15, function(k, v) { return k === "secret" ? undefined : v; });
// On node: '{"x":1,"y":2}'; on js_engine (replacer ignored): '{"x":1,"y":2,"secret":"hide"}'
assert(typeof stringified === "string", "GAP-015: JSON.stringify with replacer doesn't crash");
assert(stringified.indexOf("x") !== -1, "GAP-015: JSON.stringify basic content present");

__jacDone();
