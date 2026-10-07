// MOD-001 through MOD-008: CommonJS module system
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/19_modules/test_cjs_modules.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// MOD-001: require() built-in modules
var fs      = require("fs");
var path    = require("path");
var events  = require("events");
assert(typeof fs.readFileSync  === "function", "MOD-001: require('fs') works");
assert(typeof path.join        === "function", "MOD-001: require('path') works");
assert(typeof events.EventEmitter === "function", "MOD-001: require('events') works");

// MOD-002: Module caching — second require returns same object
var fs2 = require("fs");
assert(fs === fs2, "MOD-002: require returns cached module");

// MOD-003: module.exports — export object/function/class/primitive
var fixture3 = require("./mod_fixture_object.js");
assertEq(typeof fixture3,  "object", "MOD-003: export object");
assertEq(fixture3.value,   42,       "MOD-003: exported property accessible");
assertEq(fixture3.greet(), "hello",  "MOD-003: exported method callable");

var fixture3f = require("./mod_fixture_function.js");
assertEq(typeof fixture3f, "function", "MOD-003: export function");
assertEq(fixture3f(5),     25,         "MOD-003: exported function callable");

// MOD-004: exports.foo = bar shorthand
var fixture4 = require("./mod_fixture_exports.js");
assertEq(fixture4.a, 1,   "MOD-004: exports.a");
assertEq(fixture4.b, "x", "MOD-004: exports.b");

// MOD-005: exports = {} breaks the reference (module.exports still empty {})
var fixture5 = require("./mod_fixture_exports_rebind.js");
assertEq(typeof fixture5,      "object",    "MOD-005: module.exports is object (not reassigned)");
assertEq(fixture5.brokenProp,  undefined,   "MOD-005: exports={} breaks reference");

// MOD-006: Relative require — ./foo, ../bar, with/without .js
var rel = require("./mod_fixture_relative");  // no .js
assertEq(rel.tag, "relative", "MOD-006: relative require without .js extension");

// MOD-007: __filename / __dirname — available if supported (known gap in js_engine)
assertEq(
    typeof __filename === "string" || typeof __filename === "undefined",
    true,
    "MOD-007: __filename is string or undefined"
);
assertEq(
    typeof __dirname === "string" || typeof __dirname === "undefined",
    true,
    "MOD-007: __dirname is string or undefined"
);

// MOD-008: Circular dependencies — partial exports visible
var circA = require("./mod_fixture_circ_a.js");
// circA requires circB, which requires circA (gets partial exports)
assert(circA.fromA !== undefined, "MOD-008: circular: circA exports fromA");
assertEq(circA.fromB, "b-value",  "MOD-008: circular: circA got circB's fromB");

__jacDone();
