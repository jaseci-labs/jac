// GEN-XMOD-*: a generator body runs in ITS OWN module's function table, whichever
// module calls .next(). Regression: run_generator kept the caller's table, so a
// closure created inside the body (MAKE_CLOSURE <index>) became the function at that
// index in the DRIVER's module — Babel's chainWalker, stepped by gensync, created its
// `({ config: {...} }) => …` arrow as gensync's assertTypeof and every Vite
// plugin-react transform failed ("makeError is not a function"). Also covers
// Function.prototype.apply on a generator function (must return a generator object).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generator_cross_module_closures.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var driver = require("./gen_cross_module_driver.fixture.js");

function* walker(list, files = new Set()) {
    var picked = list.filter(function (x) { return x.keep; });
    var names = picked.map(({ cfg: { name } }) => name);
    for (var i = 0; i < names.length; i++) {
        var label = (function (n) { return function () { return "L:" + n; }; })(names[i]);
        yield label();
    }
    return names.length + files.size;
}
var input = [{ keep: true, cfg: { name: "a" } }, { keep: false, cfg: { name: "b" } }, { keep: true, cfg: { name: "c" } }];
assertEq(driver.drive(walker(input)).join(), "L:a,L:c,ret:2", "GEN-XMOD-001: closures in a generator stepped from another module");
assertEq(driver.driveApply(walker, [input]).join(), "L:a,L:c,ret:2", "GEN-XMOD-002: generator created via .apply in another module");

function* g(x) { yield x; }
var kind = function (v) { return Object.prototype.toString.call(v); };
assertEq(kind(g.apply(null, [1])), "[object Generator]", "GEN-XMOD-003: fn.apply on a generator function returns a generator");
assertEq(kind(g.bind(null).apply(null, [1])), "[object Generator]", "GEN-XMOD-003: bound generator via apply");
assertEq(g.apply(null, [7]).next().value, 7, "GEN-XMOD-003: apply passes the arguments");

__jacDone();
