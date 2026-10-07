// Plan: testing_plans/03_ecmascript_language/JSON_PARSE_STRINGIFY_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// Exit criteria: EC-JSON-5 (JSON-024..027), EC-JSON-6 (JSON-028..030)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/09_json/test_json_formatting_and_api_invariants.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- EC-JSON-5: JSON-024..027 ---

// JSON-024 numeric space clamps to 10; string space truncates to 10 code units
var s99 = JSON.stringify({ a: 1 }, null, 99);
assert(s99.indexOf("\n") >= 0, "JSON-024: space 99 still pretty-prints (clamped to 10)");
var sStr = JSON.stringify({ b: 1 }, null, "12345678901");
assertEq(sStr.split("\n")[1].indexOf("1234567890"), 0, "JSON-024: indent prefix is first 10 code units of space string");

// JSON-025 pretty output round-trips
var pretty = JSON.stringify({ x: [1, { y: 2 }] }, null, 2);
var round = JSON.parse(pretty);
assertEq(round.x[0], 1, "JSON-025: pretty JSON round-trip preserves data");
assertEq(round.x[1].y, 2, "JSON-025: nested pretty round-trip");

// JSON-026 control chars and quotes escaped in output
var esc026 = JSON.stringify("\u0000\n\"");
var expected026 = '"' + "\\u0000\\n\\\"" + '"';
assertEq(esc026, expected026, "JSON-026: control chars and quotes escaped");

// JSON-027 lone surrogate + non-BMP (round-trip / escape shape)
assertEq(JSON.stringify("\uD800"), '"\\ud800"', "JSON-027: lone high surrogate escaped lowercase \\u");
var emoji = "\uD83D\uDE00";
assertEq(JSON.parse(JSON.stringify(emoji)), emoji, "JSON-027: emoji string round-trips through stringify/parse");

// --- EC-JSON-6: JSON-028..030 ---

// JSON-028 parse SyntaxError catchable
var caught = null;
try {
    JSON.parse("{bad}");
} catch (e) {
    caught = e;
}
assert(caught instanceof SyntaxError, "JSON-028: JSON.parse malformed throws instanceof SyntaxError");
assert(caught.message.length > 0, "JSON-028: SyntaxError has non-empty message");

// JSON-029 length / callability
assertEq(typeof JSON.parse, "function", "JSON-029: JSON.parse is function");
assertEq(typeof JSON.stringify, "function", "JSON-029: JSON.stringify is function");
assertEq(JSON.parse.length, 2, "JSON-029: JSON.parse.length");
assertEq(JSON.stringify.length, 3, "JSON-029: JSON.stringify.length");

// JSON-030 namespace surface
assertEq(typeof JSON, "object", "JSON-030: typeof JSON is object");
assert(JSON !== null, "JSON-030: JSON is not null");
assertEq(JSON.parse, JSON.parse, "JSON-030: JSON.parse stable");
assertEq(JSON.stringify, JSON.stringify, "JSON-030: JSON.stringify stable");

__jacDone();
