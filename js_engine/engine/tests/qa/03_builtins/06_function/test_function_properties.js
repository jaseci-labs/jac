// FUNCTION_COMPREHENSIVE_TEST_PLAN §3–8 — length, name, prototype, constructor, legacy accessors, displayName
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_properties.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── §3 length (FN-L-*) ─────────────────────────────────────────────────────

function plain0() {}
function plain2(a, b) {}
assertEq(plain0.length, 0, "FN-L-001: zero params");
assertEq(plain2.length, 2, "FN-L-001: two params");

assertEq(
    new Function("return (function (a, b = 1, c) {}).length")(),
    1,
    "FN-L-002: default param — only params before first default"
);
assertEq(
    new Function("return (function (...args) {}).length")(),
    0,
    "FN-L-003: rest not counted"
);
assertEq(
    new Function("return (function ({ a, b }, [c, d]) {}).length")(),
    2,
    "FN-L-004: destructuring counts as one each"
);

assertEq(Function.prototype.length, 0, "FN-L-005: Function.prototype.length");

var ld = Object.getOwnPropertyDescriptor(function (x, y) {}, "length");
if (ld) {
    assertEq(ld.writable, false, "FN-L-006: length non-writable");
    assertEq(ld.enumerable, false, "FN-L-006: length non-enumerable");
    assertEq(ld.configurable, true, "FN-L-006: length configurable");
}

function arity3(a, b, c) {}
var b1 = arity3.bind(null, 1);
assertEq(b1.length, 2, "FN-L-007: bind reduces length (3 - 1)");

// ── §4 name (FN-N-*) ───────────────────────────────────────────────────────

function declaredName() {}
assertEq(declaredName.name, "declaredName", "FN-N-001: declaration name");

var inferred = function () {};
assertEq(inferred.name, "inferred", "FN-N-001: inferred from variable");

var o = { meth: function () {} };
assertEq(o.meth.name, "meth", "FN-N-001: object method name");

assertEq(new Function("return 1").name, "anonymous", "FN-N-002: Function constructor name");

function namedForBind() {}
assertEq(namedForBind.bind({}).name, "bound namedForBind", "FN-N-003: bound name prefix");

var origName = declaredName.name;
declaredName.name = "hacked";
assertEq(declaredName.name, origName, "FN-N-004: name unchanged by assignment");
Object.defineProperty(declaredName, "name", { value: "viaDef", configurable: true });
assertEq(declaredName.name, "viaDef", "FN-N-004: defineProperty can set name");

var od = Object.getOwnPropertyDescriptor(function f() {}, "name");
if (od) {
    assertEq(od.enumerable, false, "FN-N-006: name non-enumerable");
    assertEq(od.configurable, true, "FN-N-006: name configurable");
}

// FN-N-005 getter/setter names
var descG = Object.getOwnPropertyDescriptor({ get foo() { return 1; } }, "foo");
if (descG && descG.get) {
    assert(descG.get.name.indexOf("foo") >= 0, "FN-N-005: getter name contains foo");
}

// ── §5 prototype (FN-P-*) ─────────────────────────────────────────────────

function Ctor() {}
var inst = new Ctor();
assert(Object.getPrototypeOf(inst) === Ctor.prototype, "FN-P-001: instance proto");
assertEq(Ctor.prototype.constructor, Ctor, "FN-P-002: prototype.constructor");

var bf = function () {}.bind(null);
assert(!("prototype" in bf), "FN-P-003: bound function has no prototype");

var arrFn = () => {};
assert(!("prototype" in arrFn), "FN-P-004: arrow no prototype");

assert(!("prototype" in { m() {} }.m), "FN-P-004: object method no prototype");

var asyncProto = new Function("return (async function(){})")();
assert(!("prototype" in asyncProto), "FN-P-004: async function no prototype");

function BadProto() {}
BadProto.prototype = 3;
var bp = new BadProto();
assert(Object.getPrototypeOf(bp) === Object.prototype, "FN-P-005: non-object prototype → Object.prototype");

// FN-P-006
try {
    var C6 = eval("(function () { class C {} return C; })()");
    var cw = Object.getOwnPropertyDescriptor(C6, "prototype");
    assert(cw && cw.writable === false, "FN-P-006: class prototype non-writable");
} catch (e) {
    /* no class */
}

// ── §6 constructor (FN-R-001) ──────────────────────────────────────────────

assertEq(
    (function () {}).constructor,
    Function,
    "FN-R-001: function instance constructor"
);

// ── §7 legacy arguments / caller (FN-G-*) ───────────────────────────────────

function strictFn() {
    "use strict";
}
var g1a = false;
try {
    void strictFn.arguments;
} catch (e) {
    g1a = e instanceof TypeError;
}
assert(g1a, "FN-G-001: strict .arguments throws TypeError");
var g1b = false;
try {
    void strictFn.caller;
} catch (e) {
    g1b = e instanceof TypeError;
}
assert(g1b, "FN-G-001: strict .caller throws TypeError");

var ar = () => {};
var g2a = false;
try {
    void ar.arguments;
} catch (e) {
    g2a = e instanceof TypeError;
}
assert(g2a, "FN-G-002: arrow .arguments throws");

var asyncFn = new Function("return (async function(){})")();
var g2b = false;
try {
    void asyncFn.arguments;
} catch (e) {
    g2b = e instanceof TypeError;
}
assert(g2b, "FN-G-002: async .arguments throws");

var genFn = new Function("return function*(){}")();
var g2c = false;
try {
    void genFn.arguments;
} catch (e) {
    g2c = e instanceof TypeError;
}
assert(g2c, "FN-G-002: generator .arguments throws");

// FN-G-003 sloppy — optional smoke (may read as null/undefined in modern engines)
function sloppy() {}
try {
    var _a = sloppy.arguments;
    var _c = sloppy.caller;
    assert(_a === null || typeof _a === "object", "FN-G-003: sloppy arguments accessor exists");
} catch (e) {
    /* some engines still restrict */
}

// ── §8 displayName (FN-D-001) optional ─────────────────────────────────────

function maybeDisplay() {}
if ("displayName" in maybeDisplay || typeof maybeDisplay.displayName === "string") {
    assertEq(typeof maybeDisplay.displayName, "string", "FN-D-001: displayName is string when present");
}

__jacDone();
