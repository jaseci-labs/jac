// CLS-040 through CLS-050: Instance fields, private, computed methods
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/14_classes/test_classes_fields.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CLS-040: public instance fields
class WithFields {
    x = 1;
    y = 2;
    label = "default";
    constructor(label) { this.label = label; }
}
var wf = new WithFields("custom");
assertEq(wf.x,     1,        "CLS-040: public instance field x");
assertEq(wf.y,     2,        "CLS-040: public instance field y");
assertEq(wf.label, "custom", "CLS-040: constructor overrides field default");
var wf2 = new WithFields("other");
// each instance gets own field
assertEq(wf2.x, 1, "CLS-040: each instance gets own field");
wf.x = 99;
assertEq(wf2.x, 1, "CLS-040: field mutation doesn't affect other instance");

// CLS-041: private fields — inaccessible outside
class WithPrivate {
    #secret = 42;
    getSecret() { return this.#secret; }
    setSecret(v) { this.#secret = v; }
}
var wp = new WithPrivate();
assertEq(wp.getSecret(), 42, "CLS-041: private field readable inside class");
wp.setSecret(99);
assertEq(wp.getSecret(), 99, "CLS-041: private field writable inside class");
assertEq(wp["#secret"],  undefined, "CLS-041: private field not accessible by string key");

// CLS-043: accessing private field outside class throws or returns undefined
var privateAccessThrew = false;
try {
    // Syntax: wp.#secret would be a SyntaxError at parse time,
    // so test via bracket notation (should return undefined, not the private value)
    var val = wp["#secret"];
    // If engine mangles #secret to __priv_secret, test that too
    assertEq(val, undefined, "CLS-043: bracket access of #field returns undefined");
} catch(e) {
    privateAccessThrew = true;
}
assert(privateAccessThrew || wp["#secret"] === undefined,
    "CLS-043: private field not accessible from outside");

// CLS-042: private methods
class WithPrivateMethod {
    #compute(x) { return x * 2; }
    run(n) { return this.#compute(n); }
}
var wpm = new WithPrivateMethod();
assertEq(wpm.run(5), 10, "CLS-042: private method callable from inside class");
assertEq(wpm["#compute"], undefined, "CLS-042: private method not accessible by string key");

// CLS-044: private static field
class WithPrivateStatic {
    static #count = 0;
    constructor() { WithPrivateStatic.#count++; }
    static getCount() { return WithPrivateStatic.#count; }
}
new WithPrivateStatic();
new WithPrivateStatic();
assertEq(WithPrivateStatic.getCount(), 2, "CLS-044: private static field tracks instances");

// CLS-050: computed method names
var methodName = "greet";
class Greeter {
    [methodName]() { return "hello"; }
    [Symbol.toPrimitive](hint) {
        return hint === "number" ? 42 : "Greeter";
    }
}
var g = new Greeter();
assertEq(g.greet(), "hello",   "CLS-050: computed method name from variable");
assertEq(+g,        42,        "CLS-050: [Symbol.toPrimitive] computed method (number hint)");
assertEq(`${g}`,    "Greeter", "CLS-050: [Symbol.toPrimitive] computed method (string hint)");

__jacDone();
