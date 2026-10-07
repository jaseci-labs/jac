// JSON-LONGSTR-*: JSON.parse builds each string value in linear time. Regression:
// the string scanner appended one character at a time (`result = result + ch`),
// O(n²) in a value's length — a 1.46 MB bundler sourcemap (sourcesContent holds
// whole files as single strings) took 15 s, and Vite's dev server re-parses the
// map on every transform of a pre-bundled dependency.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/09_json/test_json_parse_long_strings.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assert(cond, msg) { __reg.assert(cond, msg); }

var src = "line one\n\t\"quoted\" \\ back/slash é ☃ 😀 \u0001 end";
var round = JSON.parse(JSON.stringify({ s: src, k: [src, "", "x"] }));
assertEq(round.s, src, "JSON-LONGSTR-001: escapes, non-ASCII and astral chars round-trip");
assertEq(round.k.join("|"), src + "||x", "JSON-LONGSTR-001: strings inside arrays, empty string");
assertEq(JSON.parse('"\\u00e9\\u2603\\ud83d\\ude00"'), "é☃😀", "JSON-LONGSTR-002: \\u escapes incl. surrogate pair");
var threw = "none";
try { JSON.parse('"a\nb"'); } catch (e) { threw = e.name; }
assertEq(threw, "SyntaxError", "JSON-LONGSTR-003: raw control character is still rejected");
threw = "none";
try { JSON.parse('"abc'); } catch (e) { threw = e.name; }
assertEq(threw, "SyntaxError", "JSON-LONGSTR-003: unterminated string is still rejected");

var big = ("0123456789abcdef\\n\"é").repeat(40000);          // ~0.8 MB value with escapes + non-ASCII
var text = JSON.stringify({ sourcesContent: [big], mappings: "AAAA;".repeat(80000) });
var t0 = Date.now();
var parsed = JSON.parse(text);
var ms = Date.now() - t0;
assertEq(parsed.sourcesContent[0] === big && parsed.mappings.length === 400000, true, "JSON-LONGSTR-004: large sourcemap-shaped document parses exactly");
assert(ms < 5000, "JSON-LONGSTR-005: large string values parse in linear time (" + ms + " ms; quadratic took minutes)");

__jacDone();
