// STRING_COMPREHENSIVE_TEST_PLAN §13–14 — match, matchAll, search, replace, replaceAll, split
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_regexp_split.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// STR-RX-001
assertEq("hello".search(/l/), 2, "STR-RX-001: search found");
assertEq("hello".search(/z/), -1, "STR-RX-001: search not found");
var rx1 = false;
try { "x".search("["); } catch (e) { rx1 = e instanceof SyntaxError; }
assert(rx1, "STR-RX-001: search invalid pattern SyntaxError");

// STR-RX-002
var m1 = "hello".match(/l/);
assert(m1 !== null && m1[0] === "l", "STR-RX-002: match non-global");
assertDeep("hello".match(/l/g), ["l", "l"], "STR-RX-002: match global");
assertEq("hello".match(/z/), null, "STR-RX-002: match null");

// STR-RX-003
var rx3 = false;
try { "hello".matchAll(/l/); } catch (e) { rx3 = e instanceof TypeError; }
assert(rx3, "STR-RX-003: matchAll non-global TypeError");
var it = "hello".matchAll(/l/g);
var ma = it.next();
assertEq(ma.done, false, "STR-RX-003: matchAll first not done");
assertEq(ma.value[0], "l", "STR-RX-003: matchAll first match");
it.next();
var ma2 = it.next();
assertEq(ma2.done, true, "STR-RX-003: matchAll exhausted");

// STR-RX-004
assertEq("abc".replace("b", "X"), "aXc", "STR-RX-004: replace string");
assertEq("ab".replace(/b/, "$&"), "ab", "STR-RX-004: replace $&");
assertEq("a1b".replace(/\d/g, function (m) { return m + m; }), "a11b", "STR-RX-004: replace function");

// STR-RX-005
assertEq("aabb".replaceAll("a", "x"), "xxbb", "STR-RX-005: replaceAll string all");
var rx5 = false;
try { "a".replaceAll(/a/, "b"); } catch (e) { rx5 = e instanceof TypeError; }
assert(rx5, "STR-RX-005: replaceAll non-global RegExp TypeError");
assertEq("aa".replaceAll(/a/g, "b"), "bb", "STR-RX-005: replaceAll global");

// STR-SP-001
assertDeep("a,b,c".split(","), ["a", "b", "c"], "STR-SP-001: split string sep");
assertDeep("abc".split(""), ["a", "b", "c"], "STR-SP-001: split empty sep");
assertEq("a,b,c".split(",", 2).length, 2, "STR-SP-001: split limit");

// STR-SP-002
assertDeep("a1b2".split(/\d/), ["a", "b", ""], "STR-SP-002: split regexp");
assertDeep("a1b".split(/(\d)/), ["a", "1", "b"], "STR-SP-002: split capturing");

// STR-SP-003 — split("") yields code units; emoji is two units
var emoji = "\uD83D\uDE00";
var sp = emoji.split("");
assertEq(sp.length, 2, "STR-SP-003: split astral gives two UTF-16 strings");

__jacDone();
