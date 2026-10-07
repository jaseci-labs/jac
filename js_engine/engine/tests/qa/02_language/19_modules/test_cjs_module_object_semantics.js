// testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — G5
// NCJS-MOD-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/19_modules/test_cjs_module_object_semantics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var path = require("path");

// NCJS-MOD-001
assertEq(module.filename, __filename, "NCJS-MOD-001: module.filename === __filename");
assert(path.isAbsolute(module.filename), "NCJS-MOD-001: module.filename is absolute");

// NCJS-MOD-002
assertEq(typeof module.id, "string", "NCJS-MOD-002: module.id is string");
assert(module.id.length > 0, "NCJS-MOD-002: module.id non-empty");

// NCJS-MOD-003 — during child eval first line, loaded is false; after load cache entry is loaded
var probePath = require.resolve("./fixtures_cjs_globals/loaded_probe.js");
var probe = require("./fixtures_cjs_globals/loaded_probe.js");
assertEq(probe.loadedAtFirstLine, false, "NCJS-MOD-003: module.loaded false during body eval start");
var cachedProbe = require.cache[probePath];
assert(cachedProbe !== undefined, "NCJS-MOD-003: probe in require.cache");
assertEq(cachedProbe.loaded, true, "NCJS-MOD-003: cache entry loaded after evaluation");

// NCJS-MOD-004 — parent lists required child
var childPath = require.resolve("./fixtures_cjs_globals/child_for_parent.js");
require("./fixtures_cjs_globals/child_for_parent.js");
var foundChild = false;
for (var i = 0; i < module.children.length; i++) {
    var ch = module.children[i];
    if (ch && ch.filename === childPath) {
        foundChild = true;
        break;
    }
}
assert(foundChild, "NCJS-MOD-004: module.children includes required child module");

// NCJS-MOD-005
var sub = require("./fixtures_cjs_globals/child_for_parent.js");
assertEq(path.normalize(String(sub.parentFilename)), path.normalize(__filename), "NCJS-MOD-005: child module.parent.filename is importer");

// NCJS-MOD-006
assert(Array.isArray(module.paths), "NCJS-MOD-006: module.paths is array");
assert(module.paths.length > 0, "NCJS-MOD-006: module.paths non-empty");

// NCJS-MOD-007
var viaMr = module.require("path");
var viaReq = require("path");
assert(viaMr === viaReq || typeof viaMr.join === "function", "NCJS-MOD-007: module.require('path') matches require");

// NCJS-MOD-008
assert(module === require.main, "NCJS-MOD-008: module === require.main when run as entry");
assert(require.main === module, "NCJS-MOD-008: require.main === module");

console.log("ok cjs module object semantics (NCJS-MOD-*)");
__jacDone();
