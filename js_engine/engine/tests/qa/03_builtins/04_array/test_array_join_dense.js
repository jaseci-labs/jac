// ARR-JOIN-001..008: Array.prototype.join semantics after the dense fast path
// rewrite (pieces joined once instead of O(n^2) concat + a leaked intermediate
// per element + an interned result).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_join_dense.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assertEq(a, e, msg) { __reg.assertEq(a, e, msg); }
function assert(c, m) { __reg.assert(c, m); }

assertEq([1, "a", null, undefined, true, [2, 3]].join("-"), "1-a---true-2,3", "ARR-JOIN-001: mixed values, nested array");
assertEq([].join(), "", "ARR-JOIN-002: empty");
assertEq([1, 2, 3].join(), "1,2,3", "ARR-JOIN-003: default separator");
assertEq([1, 2, 3].join(""), "123", "ARR-JOIN-003: empty separator");
assertEq(Array(3).join("ab"), "abab", "ARR-JOIN-004: holes");
(function () { var a = [1, 2]; a.length = 4; assertEq(a.join("."), "1.2..", "ARR-JOIN-004: trailing holes"); })();
assertEq([{ toString() { return "T"; } }, Symbol.iterator.description].join("|"), "T|Symbol.iterator", "ARR-JOIN-005: toString on elements");
assertEq([1, 2].join({ toString() { return "S"; } }), "1S2", "ARR-JOIN-006: separator ToString");
var threw = false; try { [Symbol()].join(); } catch (e) { threw = e instanceof TypeError; } assert(threw, "ARR-JOIN-007: Symbol element throws TypeError");
var al = { length: 3, 0: "x", 2: "z" }; assertEq(Array.prototype.join.call(al, "+"), "x++z", "ARR-JOIN-008: array-like receiver with a hole");
var getterHit = 0; var arr = [1, 2, 3]; Object.defineProperty(arr, 1, { get: function () { getterHit++; return "g"; } });
assertEq(arr.join(), "1,g,3", "ARR-JOIN-008: accessor element goes through [[Get]]"); assertEq(getterHit, 1, "ARR-JOIN-008: getter called once");
var big = []; for (var i = 0; i < 20000; i++) big.push("item" + i);
assertEq(big.join("\n").length, 20000 * 4 + (0 + 10 * 1 + 90 * 2 + 900 * 3 + 9000 * 4 + 10000 * 5) + 19999, "ARR-JOIN-008: 20k-element join length");
__jacDone();
