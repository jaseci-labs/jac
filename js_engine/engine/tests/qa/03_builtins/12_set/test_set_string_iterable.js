// SET-STR-001 through SET-STR-006: new Set(iterable) — STRING primitives are
// iterable (String.prototype[@@iterator], code points). Regression for the VM's
// observable method lookup (obs_get) lacking string-primitive boxing and the
// Set constructor loop not driving the engine-internal {__I,__J} string
// iterator: `new Set('chars')` threw "object is not iterable" (broke Vite's
// bundled minimatch: new Set('().*{}+?[]^$\\!')).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/12_set/test_set_string_iterable.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// SET-STR-001: string argument iterates its characters
var s1 = new Set("abc");
assertEq(s1.size, 3, "SET-STR-001: new Set('abc') has 3 entries");
assert(s1.has("a") && s1.has("b") && s1.has("c"), "SET-STR-001: entries are the characters");

// SET-STR-002: duplicate characters dedupe
assertEq(new Set("aabbc").size, 3, "SET-STR-002: duplicate chars dedupe");

// SET-STR-003: empty string → empty set
assertEq(new Set("").size, 0, "SET-STR-003: empty string yields empty set");

// SET-STR-004: the minimatch pattern that originally failed
var reSpecials = new Set("().*{}+?[]^$\\!");
assert(reSpecials.has("*") && reSpecials.has("\\") && reSpecials.has("!"),
    "SET-STR-004: regex-specials charset builds");

// SET-STR-005: non-string iterables still work (regression guards)
assertEq(new Set(["x", "y"]).size, 2, "SET-STR-005: array arg");
assertEq(new Set(new Set([1, 2])).size, 2, "SET-STR-005: Set arg");
function* g() { yield 1; yield 1; yield 2; }
assertEq(new Set(g()).size, 2, "SET-STR-005: generator arg");

// SET-STR-006: WeakSet with a string still throws (strings are not valid weak values;
// engine reports its not-iterable/invalid-value TypeError — must be a TypeError).
var wsThrew = false;
try { new WeakSet("ab"); } catch (e) { wsThrew = e instanceof TypeError; }
assert(wsThrew, "SET-STR-006: new WeakSet(string) throws TypeError");

__jacDone();
