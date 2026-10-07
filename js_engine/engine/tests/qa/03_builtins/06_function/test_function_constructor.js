// FUNCTION_COMPREHENSIVE_TEST_PLAN §1–2, FN-C-008 (Function instance toString shape)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_constructor.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── §1 Constructor (FN-C-*) ─────────────────────────────────────────────────

// FN-C-001
assertEq(new Function("return 1")(), 1, "FN-C-001: new Function body returns value");
assertEq(Function("return 2")(), 2, "FN-C-001: Function() without new");

// FN-C-002
assertEq(
    new Function("a", "b", "return a + b")(2, 6),
    8,
    "FN-C-002: multiple params + body"
);

// FN-C-003
assertEq(new Function("return 99")(), 99, "FN-C-003: single string is body only");

// FN-C-004 valid parameter forms
assertEq(new Function("x", "return x")("ok"), "ok", "FN-C-004: simple param");
var fRest = new Function("...args", "return args.length");
assertEq(fRest(1, 2, 3), 3, "FN-C-004: rest param in constructor");
assertEq(
    new Function("a = 1", "return a")(),
    1,
    "FN-C-004: default param in constructor"
);

var c4bad = false;
try {
    new Function(")", "return 1");
} catch (e) {
    c4bad = e instanceof SyntaxError;
}
assert(c4bad, "FN-C-004: invalid param list throws SyntaxError");

// FN-C-005
var c5 = false;
try {
    new Function("return +++");
} catch (e) {
    c5 = e instanceof SyntaxError;
}
assert(c5, "FN-C-005: invalid body throws SyntaxError");

// FN-C-006 MDN injection-safe split parse
var c6 = false;
try {
    new Function("/*", "*/) {");
} catch (e) {
    c6 = e instanceof SyntaxError;
}
assert(c6, "FN-C-006: split parse does not splice into body");

// FN-C-007 — no closure over creator scope; globalThis visible
(function () {
    var closed = 123;
    var dyn = new Function("return closed");
    var ref = false;
    try {
        dyn();
    } catch (e) {
        ref = e instanceof ReferenceError;
    }
    assert(ref, "FN-C-007: outer const not visible in dynamic function");
})();

globalThis.__fnCtorGlob = 777;
try {
    assertEq(new Function("return globalThis.__fnCtorGlob")(), 777, "FN-C-007: globalThis visible in dynamic function");
} finally {
    delete globalThis.__fnCtorGlob;
}

// FN-C-008
var anonCtor = new Function("a", "b", "return a + b");
var ts = anonCtor.toString();
assert(ts.indexOf("anonymous") >= 0, "FN-C-008: toString contains anonymous");
assert(ts.indexOf("return a + b") >= 0, "FN-C-008: toString contains body");

// ── §2 Meta (FN-M-*) ───────────────────────────────────────────────────────

assertEq(Function.length, 1, "FN-M-001: Function.length === 1");
assertEq(typeof Function, "function", "FN-M-002: typeof Function");
// Function.prototype is itself a function object (callable empty function); typeof is "function" in spec engines
assert(
    typeof Function.prototype === "function",
    "FN-M-002: Function.prototype is callable function object"
);
var m2 = false;
try {
    new Function();
    m2 = true;
} catch (e) {
    m2 = false;
}
assert(m2, "FN-M-002: Function is constructable");

__jacDone();
