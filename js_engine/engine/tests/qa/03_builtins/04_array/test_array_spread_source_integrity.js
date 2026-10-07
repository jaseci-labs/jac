// ARR-S-001: SPREAD opcode must not corrupt the source array.
// See: TBD/commit_3f754f9_spread_corrupts_source_array.js
// Fix: vm/vm.na.jac _collect_iterable() must return a shallow copy for arrays.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_spread_source_integrity.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ARR-S-001: basic spread does not corrupt source isArray
var a = [1, 2, 3];
var b = [...a];
assert(Array.isArray(a), "ARR-S-001: Array.isArray(source) after spread");
assertEq(b.length, 3, "ARR-S-001: spread result length");

// ARR-S-002: source retains prototype methods after spread
var plugins = [{name: "p1"}, {name: "p2"}];
var copy = [...plugins];
assertEq(typeof plugins.entries, "function", "ARR-S-002: source.entries is function after spread");
assertEq(typeof plugins.filter, "function", "ARR-S-002: source.filter is function after spread");
assertEq(copy.length, 2, "ARR-S-002: spread copy length");

// ARR-S-003: multiple spreads of same source do not accumulate corruption
var x = [10, 20];
var _r = [...x, ...x, ...x];
assert(Array.isArray(x), "ARR-S-003: source isArray after multiple spreads");
assertEq(typeof x.map, "function", "ARR-S-003: source.map is function after multiple spreads");
assertEq(_r.length, 6, "ARR-S-003: merged result length");

// ARR-S-004: spread into merged array, source still intact
var inputPlugins = [{name: "vite:pre"}, {name: "vite:post"}];
var outputPlugins = [];
var merged = [...inputPlugins, ...outputPlugins];
assert(Array.isArray(inputPlugins), "ARR-S-004: inputPlugins isArray after spread into merged");
assertEq(typeof inputPlugins.entries, "function", "ARR-S-004: inputPlugins.entries is function");

// ARR-S-005: rolldown asyncFlatten scenario — spread then flat(Infinity)
var flattened = [inputPlugins].flat(Infinity);
assert(Array.isArray(inputPlugins), "ARR-S-005: inputPlugins isArray after flat(Infinity)");
assertEq(typeof inputPlugins.entries, "function", "ARR-S-005: inputPlugins.entries is function after flat");
assertEq(flattened.length, 2, "ARR-S-005: flat(Infinity) result length");

__jacDone();
