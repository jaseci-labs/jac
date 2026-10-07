// TL-001 through TL-008: Template literals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/10_template_literals/test_template_literals.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// TL-001: basic interpolation
var name = "world";
assertEq(`Hello ${name}`, "Hello world", "TL-001: basic interpolation");
var num = 42;
assertEq(`n=${num}`, "n=42", "TL-001: number interpolation (toString)");
assertEq(`${null}`, "null", "TL-001: null toString in template");
assertEq(`${undefined}`, "undefined", "TL-001: undefined toString in template");

// TL-002: multi-line preserves newlines
var ml = `line1
line2`;
assert(ml.indexOf("\n") !== -1, "TL-002: multi-line template contains newline");
assertEq(ml.split("\n").length, 2, "TL-002: two lines");

// TL-003: expressions in template
var a = 3, b = 4;
assertEq(`${a + b}`, "7",    "TL-003: expression ${a+b}");
function double(x) { return x * 2; }
assertEq(`${double(5)}`, "10", "TL-003: function call in template");
assertEq(`${a > b ? 'gt' : 'le'}`, "le", "TL-003: ternary in template");

// TL-004: nested templates
assertEq(`outer ${`inner ${1 + 1}`} end`, "outer inner 2 end", "TL-004: nested template literal");

// TL-005: tagged templates
function tag(strings, ...vals) {
    var result = "";
    strings.forEach(function(s, i) {
        result += s;
        if (i < vals.length) result += vals[i].toString().toUpperCase();
    });
    return result;
}
var x = "hello", y = "world";
assertEq(tag`${x} and ${y}!`, "HELLO and WORLD!", "TL-005: tagged template");
// .raw property on strings array
function rawTag(strings) { return strings.raw[0]; }
assertEq(rawTag`a\nb`, "a\\nb", "TL-005: strings.raw contains unprocessed escape");

// TL-006: String.raw
assertEq(String.raw`\n\t\\`, "\\n\\t\\\\", "TL-006: String.raw preserves escape sequences as text");
assertEq(String.raw`Hello\nWorld`, "Hello\\nWorld", "TL-006: String.raw no actual newline");

// TL-007: no interpolation = plain string
assertEq(`just a plain string`, "just a plain string", "TL-007: backtick with no interpolation");

// TL-008: special chars — $ without brace, backtick in expression
assertEq(`price: $100`, "price: $100", "TL-008: $ without { is literal");
var tick = "`";
assertEq(`contains ${tick}`, "contains `", "TL-008: backtick in interpolated expression");

__jacDone();
