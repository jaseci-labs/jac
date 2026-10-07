// regression: Object.prototype.toString.call(fn) must return "[object Function]"
// for user-defined closures (arrow, regular, async, generator).
// Before fix: user closures fell through to "[object Object]" in the
// NATIVE_KIND_OBJ_PROTO_TOSTRING handler in dispatch.na.jac because the
// jsv_is_cell + JS_CELL_KIND_NATIVE + table_id < NATIVE_BASE check was missing.

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/04_expressions/test_tostring_tag_functions");
var __jacOrigExit = process.exit.bind(process);

var ots = Object.prototype.toString;

// User-defined closures — core regression cases
__reg.assertEq(ots.call((x) => x), "[object Function]", "arrow fn");
__reg.assertEq(ots.call(function() {}), "[object Function]", "function expression");
(function() {
    function decl() {}
    __reg.assertEq(ots.call(decl), "[object Function]", "function declaration");
})();
(function() {
    async function af() {}
    __reg.assertEq(ots.call(af), "[object AsyncFunction]", "async function");
})();
(function() {
    function* gf() { yield 1; }
    __reg.assertEq(ots.call(gf), "[object GeneratorFunction]", "generator function");
})();

// Built-in native (must still work)
__reg.assertEq(ots.call(Math.abs), "[object Function]", "built-in Math.abs");

// Other types must not regress
__reg.assertEq(ots.call({}), "[object Object]", "plain object");
__reg.assertEq(ots.call(null), "[object Null]", "null");
__reg.assertEq(ots.call(undefined), "[object Undefined]", "undefined");
__reg.assertEq(ots.call([]), "[object Array]", "array");
__reg.assertEq(ots.call(42), "[object Number]", "number");
__reg.assertEq(ots.call("hi"), "[object String]", "string");
__reg.assertEq(ots.call(true), "[object Boolean]", "boolean");

// Async generator function
(function() {
    async function* agf() { yield 1; }
    __reg.assertEq(ots.call(agf), "[object AsyncGeneratorFunction]", "async generator function");
})();

__reg.finalize(__jacOrigExit);
