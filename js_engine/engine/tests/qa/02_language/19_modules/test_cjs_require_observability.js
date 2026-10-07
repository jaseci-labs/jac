// testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — G4
// NCJS-REQ-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/19_modules/test_cjs_require_observability.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var path = require("path");
var pathNode = require("node:path");

// NCJS-REQ-001
assert(typeof path.join === "function", "NCJS-REQ-001: require('path') exposes join");
assert(pathNode === path || typeof pathNode.join === "function", "NCJS-REQ-001: node:path usable");

// NCJS-REQ-002 — relative require from this file's directory
var rel = require("./fixtures_cjs_globals/path_child.js");
assertEq(typeof rel.dirname, "string", "NCJS-REQ-002: relative require resolves from module dir");

// NCJS-REQ-003 — JSON require
var j = require("./fixtures_cjs_globals/sample.json");
assertEq(j.x, 42, "NCJS-REQ-003: JSON require parses object");
assertEq(j.s, "ok", "NCJS-REQ-003: JSON string field");

// NCJS-REQ-004
var threw = false;
var code = "";
try {
    require("./fixtures_cjs_globals/does_not_exist_module_xyz");
} catch (e) {
    threw = true;
    code = e && e.code ? String(e.code) : "";
}
assert(threw, "NCJS-REQ-004: missing module throws");
assert(
    code === "MODULE_NOT_FOUND" || code.indexOf("MODULE") !== -1,
    "NCJS-REQ-004: error has module-not-found style code | actual: " + code
);

// NCJS-REQ-101
var resolvedChild = require.resolve("./fixtures_cjs_globals/path_child.js");
assert(path.isAbsolute(resolvedChild), "NCJS-REQ-101: require.resolve returns absolute path");
var loaded = require("./fixtures_cjs_globals/path_child.js");
assertEq(typeof loaded.dirname, "string", "NCJS-REQ-101: resolved path loads same module");

// NCJS-REQ-102
var key = require.resolve("./fixtures_cjs_globals/eval_counter.js");
var c1 = require("./fixtures_cjs_globals/eval_counter.js");
assert(require.cache[key] !== undefined, "NCJS-REQ-102: require.cache populated after load");
var c2 = require("./fixtures_cjs_globals/eval_counter.js");
assert(c1 === c2, "NCJS-REQ-102: second require returns same exports");
assertEq(c1.evalCount, c2.evalCount, "NCJS-REQ-102: same evalCount");

// NCJS-REQ-103
var keyCounter = require.resolve("./fixtures_cjs_globals/eval_counter.js");
var e1 = require("./fixtures_cjs_globals/eval_counter.js");
var countAfterFirst = e1.evalCount;
delete require.cache[keyCounter];
var e2 = require("./fixtures_cjs_globals/eval_counter.js");
assert(e2.evalCount > countAfterFirst, "NCJS-REQ-103: cache delete causes re-evaluation");

// NCJS-REQ-104 — entry script is main; transitive module is not
assert(require.main === module, "NCJS-REQ-104: require.main === module in entry CJS");
var sub = require("./fixtures_cjs_globals/child_for_parent.js");
assertEq(sub.isMain, false, "NCJS-REQ-104: transitive require.main !== module");
assertEq(sub.sameAsMain, false, "NCJS-REQ-104: transitive module !== require.main");

// NCJS-REQ-105 — require.resolve.paths (built-in vs local)
var pathsBuiltin = require.resolve.paths("path");
var pathsLocal = require.resolve.paths("./fixtures_cjs_globals/path_child.js");
assert(pathsBuiltin === null, "NCJS-REQ-105: resolve.paths(core) is null");
assert(pathsLocal !== null && typeof pathsLocal === "object", "NCJS-REQ-105: resolve.paths(local) is non-null object");
assert(typeof pathsLocal.length === "number", "NCJS-REQ-105: resolve.paths(local) is array-like");

console.log("ok cjs require observability (NCJS-REQ-*)");
__jacDone();
