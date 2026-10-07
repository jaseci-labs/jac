// FUNCTION_COMPREHENSIVE_TEST_PLAN §12–13 — toString, Symbol.hasInstance
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_tostring_hasinstance.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── §12 toString (FN-TS-*) ─────────────────────────────────────────────────

// FN-TS-001
function myFn() {
    return 1;
}
var ts1 = myFn.toString();
assertEq(typeof ts1, "string", "FN-TS-001: toString returns string");
assert(ts1.indexOf("myFn") >= 0 || ts1.indexOf("function") >= 0, "FN-TS-001: contains name or function keyword");

// FN-TS-002
var nativeStr = Math.abs.toString();
assert(nativeStr.indexOf("[native code]") >= 0, "FN-TS-002: builtin contains [native code]");

// FN-TS-003
var ts3 = false;
try {
    Function.prototype.toString.call("foo");
} catch (e) {
    ts3 = e instanceof TypeError;
}
assert(ts3, "FN-TS-003: toString on non-function throws TypeError");

// FN-TS-004
var boundTs = function fBound() {}.bind(null);
var bstr = boundTs.toString();
assert(bstr.indexOf("[native code]") >= 0, "FN-TS-004: bound function native-style string");

// FN-TS-005 (cross-ref §1)
var anonDyn = new Function("return 1");
var astr = anonDyn.toString();
assert(astr.indexOf("anonymous") >= 0, "FN-TS-005: Function constructor toString has anonymous");

// ── §13 Symbol.hasInstance (FN-H-*) ────────────────────────────────────────

function Foo() {}
var foo = new Foo();

// FN-H-001
assertEq(foo instanceof Foo, Foo[Symbol.hasInstance](foo), "FN-H-001: instanceof matches @@hasInstance");

// FN-H-002
assertEq(Foo[Symbol.hasInstance](1), false, "FN-H-002: primitive → false");
assertEq(Foo[Symbol.hasInstance]("x"), false, "FN-H-002: string primitive → false");

// FN-H-003
var BoundFoo = Foo.bind(null);
assertEq(foo instanceof BoundFoo, true, "FN-H-003: instanceof bound uses target");
assertEq(BoundFoo[Symbol.hasInstance](foo), true, "FN-H-003: bound @@hasInstance");

// FN-H-004
try {
    var h4 = Function(
        '"use strict";' +
            "class Q {" +
            "  static [Symbol.hasInstance](v) { return false; }" +
            "}" +
            "const q = new Q();" +
            "const def = Function.prototype[Symbol.hasInstance];" +
            "return (q instanceof Q) === false && def.call(Q, q) === true;"
    )();
    assert(h4, "FN-H-004: custom @@hasInstance; default call restores");
} catch (e) {
    /* class / symbol */
}

// FN-H-005 — constructor with non-object prototype
function BadH() {}
BadH.prototype = 1;
var h5 = false;
try {
    void (foo instanceof BadH);
} catch (e) {
    h5 = e instanceof TypeError;
}
assert(h5, "FN-H-005: instanceof throws when prototype not object");

// FN-H-006
if (typeof Symbol !== "undefined" && Symbol.hasInstance) {
    var hd = Object.getOwnPropertyDescriptor(Function.prototype, Symbol.hasInstance);
    if (hd) {
        assertEq(hd.writable, false, "FN-H-006: @@hasInstance non-writable");
        assertEq(hd.configurable, false, "FN-H-006: @@hasInstance non-configurable");
    }
}

__jacDone();
