// CLS-020 through CLS-031: Static members and accessors
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/14_classes/test_classes_static_accessors.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CLS-020: static methods — on class, not instances
class MathUtils {
    static add(a, b) { return a + b; }
    static PI = 3.14159;
}
assertEq(MathUtils.add(2, 3), 5, "CLS-020: static method on class");
var mu = new MathUtils();
assertEq(mu.add, undefined, "CLS-020: static method not on instance");

// CLS-021: static fields
assertEq(MathUtils.PI, 3.14159, "CLS-021: static field readable on class");
var mu2 = new MathUtils();
assertEq(mu2.PI, undefined, "CLS-021: static field not on instance");

// CLS-022: static inheritance — subclass inherits statics
class Parent {
    static greet() { return "Hello from " + this.name; }
    static type = "parent";
}
class Child extends Parent {
    static type = "child";
}
assertEq(Child.greet(), "Hello from Child", "CLS-022: subclass inherits static method");
assertEq(Parent.type, "parent", "CLS-022: parent static field");
assertEq(Child.type,  "child",  "CLS-022: child overrides static field");
// inherited static through chain
assertEq(typeof Child.greet, "function", "CLS-022: inherited static is accessible on Child");

// CLS-030: get/set accessors in class body
class Temperature {
    constructor(celsius) { this._c = celsius; }
    get fahrenheit() { return this._c * 9 / 5 + 32; }
    set fahrenheit(f) { this._c = (f - 32) * 5 / 9; }
    get celsius() { return this._c; }
}
var temp = new Temperature(0);
assertEq(temp.fahrenheit, 32,   "CLS-030: getter converts to Fahrenheit (0°C = 32°F)");
temp.fahrenheit = 212;
assertEq(temp.celsius, 100,     "CLS-030: setter converts from Fahrenheit (212°F = 100°C)");

// Accessor descriptor verification
var desc = Object.getOwnPropertyDescriptor(Temperature.prototype, "fahrenheit");
assert(typeof desc.get === "function", "CLS-030: getter on prototype descriptor");
assert(typeof desc.set === "function", "CLS-030: setter on prototype descriptor");

// CLS-031: computed accessor names
var propName = "size";
class Sizable {
    constructor(n) { this._n = n; }
    get [propName]() { return this._n; }
    set [propName](v) { this._n = v; }
}
var sz = new Sizable(5);
assertEq(sz.size, 5,  "CLS-031: computed getter");
sz.size = 10;
assertEq(sz.size, 10, "CLS-031: computed setter");

// Well-known symbol computed method
class MyIterable {
    constructor(...vals) { this._vals = vals; }
    [Symbol.iterator]() {
        var idx = 0, vals = this._vals;
        return {
            next: function() {
                return idx < vals.length
                    ? { value: vals[idx++], done: false }
                    : { value: undefined, done: true };
            }
        };
    }
}
var mi = new MyIterable(10, 20, 30);
var collected = [];
for (var v of mi) { collected.push(v); }
assertEq(collected.join(","), "10,20,30", "CLS-031: [Symbol.iterator] computed method");

__jacDone();
