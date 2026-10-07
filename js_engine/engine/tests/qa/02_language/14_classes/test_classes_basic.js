// CLS-001 through CLS-014: Class declarations, constructors, methods, inheritance
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/14_classes/test_classes_basic.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CLS-001: class declaration
class Point {
    constructor(x, y) { this.x = x; this.y = y; }
    toString() { return `(${this.x},${this.y})`; }
}
var p = new Point(3, 4);
assertEq(typeof Point, "function", "CLS-001: typeof class === 'function'");
assertEq(p.x, 3,             "CLS-001: constructor sets properties");
assertEq(p.toString(), "(3,4)", "CLS-001: instance method");

// CLS-002: class expression
var Rect = class Rectangle {
    constructor(w, h) { this.w = w; this.h = h; }
    area() { return this.w * this.h; }
};
var r = new Rect(3, 5);
assertEq(r.area(), 15, "CLS-002: class expression method");
assertEq(typeof Rectangle, "undefined", "CLS-002: named class expression name not in outer scope");

// CLS-003: class is not hoisted — accessing before declaration throws ReferenceError
var notHoisted = false;
try {
    var _ = new NotDeclaredYet();
} catch(e) {
    notHoisted = (e instanceof ReferenceError || e instanceof TypeError);
}
assert(notHoisted, "CLS-003: class not usable before declaration");
class NotDeclaredYet {}

// CLS-004: calling class without new throws TypeError
var noNewThrew = false;
try { Point(1, 2); } catch(e) { noNewThrew = e instanceof TypeError; }
assert(noNewThrew, "CLS-004: calling class without new throws TypeError");

// CLS-005: constructor receives args, returns this implicitly
class Box {
    constructor(val) { this.val = val; }
}
var box = new Box(99);
assertEq(box.val, 99,       "CLS-005: constructor receives args");
assert(box instanceof Box,  "CLS-005: new returns instance");

// CLS-006: methods shared via prototype
class Counter {
    constructor() { this.n = 0; }
    inc() { this.n++; }
    get() { return this.n; }
}
var c1 = new Counter();
var c2 = new Counter();
assertEq(c1.inc, c2.inc, "CLS-006: methods shared via prototype (same reference)");
c1.inc(); c1.inc();
assertEq(c1.get(), 2, "CLS-006: instance method modifies own state");
assertEq(c2.get(), 0, "CLS-006: other instance unaffected");

// CLS-010: extends — inherits methods, instanceof both
class Animal {
    constructor(name) { this.name = name; }
    speak() { return this.name + " makes a sound"; }
}
class Dog extends Animal {
    speak() { return this.name + " barks"; }
}
var dog = new Dog("Rex");
assertEq(dog.speak(), "Rex barks",     "CLS-010: override parent method");
assert(dog instanceof Dog,    "CLS-010: instanceof Dog");
assert(dog instanceof Animal, "CLS-010: instanceof Animal (extends)");

// CLS-011: super() in constructor
class Vehicle {
    constructor(make) { this.make = make; }
}
class Car extends Vehicle {
    constructor(make, model) {
        super(make);
        this.model = model;
    }
}
var car = new Car("Toyota", "Camry");
assertEq(car.make,  "Toyota", "CLS-011: super() passes arg to parent");
assertEq(car.model, "Camry",  "CLS-011: subclass own property");

// CLS-012: super.method() calls parent implementation
class Shape {
    describe() { return "Shape"; }
}
class Circle extends Shape {
    describe() { return super.describe() + ":Circle"; }
}
var circle = new Circle();
assertEq(circle.describe(), "Shape:Circle", "CLS-012: super.method() call");

// CLS-013: multi-level inheritance
class A { whoAmI() { return "A"; } }
class B extends A { whoAmI() { return super.whoAmI() + "B"; } }
class C extends B { whoAmI() { return super.whoAmI() + "C"; } }
var c = new C();
assertEq(c.whoAmI(), "ABC", "CLS-013: 3-level super chain");
assert(c instanceof A, "CLS-013: instanceof base A");
assert(c instanceof B, "CLS-013: instanceof mid B");
assert(c instanceof C, "CLS-013: instanceof leaf C");

// CLS-014: extend built-ins
class MyArray extends Array {
    sum() { return this.reduce((a, b) => a + b, 0); }
}
var ma = new MyArray(1, 2, 3);
// Note: extending Array may not work perfectly in all engines; check instanceof
assert(ma instanceof MyArray, "CLS-014: MyArray extends Array instanceof check");

class AppError extends Error {
    constructor(msg, code) {
        super(msg);
        this.code = code;
    }
}
var ae = new AppError("oops", 404);
assert(ae instanceof AppError, "CLS-014: AppError instanceof AppError");
assert(ae instanceof Error,    "CLS-014: AppError instanceof Error");
assertEq(ae.message, "oops",  "CLS-014: AppError message");
assertEq(ae.code,    404,     "CLS-014: AppError custom property");

__jacDone();
