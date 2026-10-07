// RT-030 through RT-037: Global functions (synchronous checks)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/03_global_functions/test_global_functions.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-030: parseInt
assertEq(parseInt("42"), 42, "RT-030: parseInt decimal");
assertEq(parseInt("0xFF"), 255, "RT-030: parseInt hex 0x");
assertEq(parseInt("1010", 2), 10, "RT-030: parseInt radix 2");
assertEq(parseInt("  99  "), 99, "RT-030: parseInt leading whitespace");
assert(isNaN(parseInt("abc")), "RT-030: parseInt NaN for invalid");
assertEq(parseInt("FF", 16), 255, "RT-030: parseInt radix 16");

// RT-031: parseFloat
assertEq(parseFloat("3.14"), 3.14, "RT-031: parseFloat float string");
assertEq(parseFloat("3.14abc"), 3.14, "RT-031: parseFloat trailing non-digits");
assert(isNaN(parseFloat("abc")), "RT-031: parseFloat NaN for invalid");
assertEq(parseFloat("Infinity"), Infinity, "RT-031: parseFloat Infinity");

// RT-032: isNaN
assertEq(isNaN(NaN), true, "RT-032: isNaN(NaN) === true");
assertEq(isNaN(42), false, "RT-032: isNaN(number) === false");
assertEq(isNaN("hello"), true, "RT-032: isNaN coerces string");
assertEq(isNaN(undefined), true, "RT-032: isNaN(undefined) === true");

// RT-033: isFinite
assertEq(isFinite(42), true, "RT-033: isFinite(number) === true");
assertEq(isFinite(NaN), false, "RT-033: isFinite(NaN) === false");
assertEq(isFinite(Infinity), false, "RT-033: isFinite(Infinity) === false");
assertEq(isFinite(-Infinity), false, "RT-033: isFinite(-Infinity) === false");
assertEq(isFinite("42"), true, "RT-033: isFinite coerces string");

// RT-034: encodeURIComponent / decodeURIComponent
var encoded = encodeURIComponent("hello world&foo=bar");
assert(encoded.indexOf(" ") === -1, "RT-034: encodeURIComponent encodes spaces");
assert(encoded.indexOf("&") === -1, "RT-034: encodeURIComponent encodes &");
assertEq(decodeURIComponent(encoded), "hello world&foo=bar", "RT-034: decodeURIComponent roundtrip");
var threw = false;
try { decodeURIComponent("%GG"); } catch(e) { threw = true; }
assert(threw, "RT-034: decodeURIComponent throws URIError for malformed %XX");

// RT-035: encodeURI / decodeURI
var uri = "https://example.com/path?q=hello world";
var encodedURI = encodeURI(uri);
assert(encodedURI.indexOf("https://") === 0, "RT-035: encodeURI preserves scheme");
assert(encodedURI.indexOf(" ") === -1, "RT-035: encodeURI encodes spaces");
assertEq(decodeURI(encodedURI), uri, "RT-035: decodeURI roundtrip");

// RT-037: eval
// Standard: eval must be a function.
// In js_engine it is disabled (throws or is a no-op); in Node/browsers it is fully functional.
assertEq(typeof eval, "function", "RT-037: eval is a function");

__jacDone();
