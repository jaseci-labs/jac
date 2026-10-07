// VIT-MOD-001: Vite V-07 smoke — module.builtinModules
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_module_builtin_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var m = require("module");
assert(Array.isArray(m.builtinModules), "VIT-MOD-001: builtinModules is array");
assert(m.builtinModules.indexOf("fs") !== -1, "VIT-MOD-001: includes fs");
assert(typeof m.isBuiltin === "function" && m.isBuiltin("fs") === true, "VIT-MOD-001: isBuiltin('fs')");

__jacDone();
