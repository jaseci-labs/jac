// testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — G1, G2
// NCJS-PRES-*, NCJS-PATH-* (excluding symlink optional NCJS-PATH-003)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/19_modules/test_cjs_pseudo_globals_presence.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var path = require("path");

// NCJS-PRES-001 .. NCJS-PRES-004
assertEq(typeof __dirname, "string", "NCJS-PRES-001: typeof __dirname === 'string'");
assertEq(typeof __filename, "string", "NCJS-PRES-002: typeof __filename === 'string'");
assertEq(typeof require, "function", "NCJS-PRES-003: typeof require === 'function'");
assert(typeof module === "object" && module !== null, "NCJS-PRES-004: module is non-null object");

// NCJS-PRES-005
assert(
    typeof exports === "object" || typeof exports === "function",
    "NCJS-PRES-005: typeof exports is object or function"
);

// NCJS-PATH-001
assert(path.isAbsolute(__filename), "NCJS-PATH-001: __filename is absolute");

// NCJS-PATH-002
assertEq(
    path.normalize(path.join(__dirname, path.basename(__filename))),
    path.normalize(__filename),
    "NCJS-PATH-002: __dirname + basename(__filename) normalizes to __filename"
);

// NCJS-PATH-004 — nested module has distinct paths
var child = require("./fixtures_cjs_globals/path_child.js");
assertEq(typeof child.dirname, "string", "NCJS-PATH-004: child __dirname is string");
assertEq(typeof child.filename, "string", "NCJS-PATH-004: child __filename is string");
assert(path.isAbsolute(child.filename), "NCJS-PATH-004: child __filename is absolute");
assert(child.dirname !== __dirname, "NCJS-PATH-004: nested __dirname differs from parent");
assert(child.filename !== __filename, "NCJS-PATH-004: nested __filename differs from parent");
assert(child.filename.indexOf("path_child") !== -1, "NCJS-PATH-004: child __filename names fixture");
assertEq(
    path.normalize(path.join(child.dirname, path.basename(child.filename))),
    path.normalize(child.filename),
    "NCJS-PATH-004: child dirname/basename relation"
);

// NCJS-PATH-005 — __filename extends __dirname (portable path relation)
assert(__filename.indexOf(__dirname) === 0, "NCJS-PATH-005: __filename starts with __dirname");

console.log("ok cjs pseudo globals presence (NCJS-PRES-*, NCJS-PATH-*)");
__jacDone();
