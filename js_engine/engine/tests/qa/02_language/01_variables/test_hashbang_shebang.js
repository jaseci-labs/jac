#!/usr/bin/env node
// HB-001: Unix hashbang must not be parsed as RegExp (vite.js entry uses #!/usr/bin/env node)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_hashbang_shebang.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(1 + 1, 2, "HB-001: script body runs after shebang strip");
__jacDone();
