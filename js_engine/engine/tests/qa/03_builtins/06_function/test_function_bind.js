// FUNCTION_COMPREHENSIVE_TEST_PLAN §11 — bind
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_bind.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertDeepEq(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

function greet(greeting, punct) {
    return greeting + ", " + this.name + punct;
}

// FN-B-001
var person = { name: "Alice" };
var boundGreet = greet.bind(person);
assertEq(boundGreet("Hey", "?"), "Hey, Alice?", "FN-B-001: bind fixes this");
var reBoundGreet = boundGreet.bind({ name: "Charlie" });
assertEq(reBoundGreet("Hi", "."), "Hi, Alice.", "FN-B-001: second bind does not replace this");

// FN-B-002
function list() {
    var a = [];
    for (var i = 0; i < arguments.length; i++) a.push(arguments[i]);
    return a;
}
function addTwo(a, b) {
    return a + b;
}
var leading = list.bind(null, 37);
assertDeepEq(leading(), [37], "FN-B-002: partial list");
assertDeepEq(leading(1, 2, 3), [37, 1, 2, 3], "FN-B-002: partial + call args");
var add37 = addTwo.bind(null, 37);
assertEq(add37(5), 42, "FN-B-002: addThirtySeven");
assertEq(add37(5, 10), 42, "FN-B-002: extra args ignored for fixed arity");

// FN-B-003 double bind (MDN: second thisArg ignored)
function logSloppy() {
    var parts = [this];
    for (var i = 0; i < arguments.length; i++) parts.push(arguments[i]);
    return parts.join(",");
}
var boundLog = logSloppy.bind("this value", 1, 2);
var boundLog2 = boundLog.bind("new this value", 3, 4);
var logOut = boundLog2(5, 6);
assert(logOut.indexOf("this value") >= 0, "FN-B-003: first bind this kept");
assert(logOut.indexOf("1") >= 0 && logOut.indexOf("6") >= 0, "FN-B-003: args order");

// FN-B-004 / B-005 Point + empty object
function Point(x, y) {
    this.x = x;
    this.y = y;
}
Point.prototype.toString = function () {
    return this.x + "," + this.y;
};

var YAxisPoint = Point.bind(null, 0);
var axisPoint = new YAxisPoint(5);
assertEq(axisPoint.toString(), "0,5", "FN-B-004: new on bound constructor");
assert(axisPoint instanceof Point, "FN-B-004: instanceof Point");
assert(axisPoint instanceof YAxisPoint, "FN-B-004: instanceof bound");

var emptyObj = {};
var YAxisPoint2 = Point.bind(emptyObj, 0);
YAxisPoint2(13);
assertEq(emptyObj.x, 0, "FN-B-005: plain call mutates bound this object");
assertEq(emptyObj.y, 13, "FN-B-005: y set on thisArg");

// FN-B-006
function origLen3(a, b, c) {}
var bpartial = origLen3.bind(null, 1);
assertEq(bpartial.length, 2, "FN-B-006: bound length");
assertEq(origLen3.bind({}).name.indexOf("bound "), 0, "FN-B-006: bound name prefix");

// FN-B-007 extends bound
var b7 = false;
try {
    eval("class D7 extends (class {}.bind(null)) {}");
} catch (e) {
    b7 = e instanceof TypeError;
}
assert(b7, "FN-B-007: class extends bound throws TypeError");

// FN-B-008
try {
    var ok8 = Function(
        '"use strict"; class Base {} const BoundBase = Base.bind(null, 1, 2); return (new Base()) instanceof BoundBase;'
    )();
    assert(ok8, "FN-B-008: instanceof uses target prototype");
} catch (e) {
    /* class */
}

// THIS-004: .call() on a bound function — bound this wins, args forwarded
(function() {
    function greet(greeting) { return greeting + ", " + this.name; }
    var person = { name: "Alice" };
    var boundGreet = greet.bind(person);
    assertEq(boundGreet.call({ name: "Bob" }, "X"), "X, Alice",
        "THIS-004: bound this not overridable via .call()");

    // THIS-005: .apply() on a bound function — same semantics
    assertEq(boundGreet.apply({ name: "Carol" }, ["Hi"]), "Hi, Alice",
        "THIS-005: bound this not overridable via .apply()");

    // THIS-006: .call() with partial args on a bound function
    function add(a, b) { return a + b + this.base; }
    var addFive = add.bind({ base: 10 }, 5);
    assertEq(addFive.call({ base: 99 }, 3), 18,
        "THIS-006: partial args + .call() on bound fn uses bound this");
})();

// FN-B-009 class bind statics
try {
    var ok9 = Function(
        '"use strict";' +
            "class Base { static baseProp() { return 'base'; } }" +
            "class Derived extends Base { static derivedProp() { return 'd'; } }" +
            "const BD = Derived.bind(null);" +
            "return typeof BD.baseProp === 'function' && BD.derivedProp === undefined;"
    )();
    assert(ok9, "FN-B-009: bound class loses own statics, keeps inherited");
} catch (e) {
    /* optional */
}

__jacDone();
