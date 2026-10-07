// PROTO-001 through PROTO-010: Prototypes and inheritance
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/12_prototypes/test_prototypes.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// PROTO-001: prototype chain lookup
function Animal(name) { this.name = name; }
Animal.prototype.speak = function() { return this.name + " speaks"; };
var a = new Animal("Dog");
assertEq(a.speak(), "Dog speaks",   "PROTO-001: property found on prototype");
assertEq(a.name,    "Dog",          "PROTO-001: own property accessible");
// multi-level
function Mammal() {}
Mammal.prototype = Object.create(Animal.prototype);
Mammal.prototype.warm = true;
var m = Object.create(Mammal.prototype);
m.name = "Cat";
assertEq(m.speak(),   "Cat speaks", "PROTO-001: multi-level prototype lookup");
assertEq(m.warm,      true,         "PROTO-001: intermediate prototype property");

// PROTO-002: Object.getPrototypeOf
assertEq(Object.getPrototypeOf(a), Animal.prototype, "PROTO-002: getPrototypeOf returns proto");
var noProto = Object.create(null);
assertEq(Object.getPrototypeOf(noProto), null, "PROTO-002: null proto object");

// PROTO-003: Object.setPrototypeOf
var p3obj = { x: 1 };
var p3proto = { y: 2 };
Object.setPrototypeOf(p3obj, p3proto);
assertEq(p3obj.x, 1, "PROTO-003: own property still accessible");
assertEq(p3obj.y, 2, "PROTO-003: new prototype property accessible");

// PROTO-004: Object.create
var p4proto = { greet: function() { return "hi"; } };
var p4obj = Object.create(p4proto);
assertEq(p4obj.greet(), "hi", "PROTO-004: Object.create with proto");
var p4null = Object.create(null);
assertEq(Object.getPrototypeOf(p4null), null, "PROTO-004: Object.create(null) has null proto");
assert(!("toString" in p4null), "PROTO-004: null proto has no Object methods");

// PROTO-005: constructor.prototype — instances link to it
function P5Ctor() {}
P5Ctor.prototype.hello = "world";
var p5inst = new P5Ctor();
assertEq(p5inst.hello, "world", "PROTO-005: instance linked to constructor.prototype");
assert(Object.getPrototypeOf(p5inst) === P5Ctor.prototype,
    "PROTO-005: [[Prototype]] is constructor.prototype");

// PROTO-006: instanceof checks entire chain
function Base6() {}
function Mid6() {}
Mid6.prototype = Object.create(Base6.prototype);
function Leaf6() {}
Leaf6.prototype = Object.create(Mid6.prototype);
var leaf = new Leaf6();
assert(leaf instanceof Leaf6,  "PROTO-006: instanceof direct");
assert(leaf instanceof Mid6,   "PROTO-006: instanceof mid");
assert(leaf instanceof Base6,  "PROTO-006: instanceof base");
assert(leaf instanceof Object, "PROTO-006: instanceof Object (all objects)");

// PROTO-007: .constructor points back
function P7() {}
var p7 = new P7();
assertEq(p7.constructor, P7, "PROTO-007: .constructor points to constructor");

// PROTO-008: own shadows prototype, delete reveals prototype
function P8() {}
P8.prototype.color = "red";
var p8 = new P8();
p8.color = "blue";
assertEq(p8.color, "blue", "PROTO-008: own property shadows prototype");
delete p8.color;
assertEq(p8.color, "red", "PROTO-008: delete reveals prototype property");

// PROTO-009: method sharing — instances share via prototype
function P9() {}
P9.prototype.method = function() { return "shared"; };
var p9a = new P9();
var p9b = new P9();
assertEq(p9a.method, p9b.method, "PROTO-009: prototype methods shared (same reference)");
assertEq(p9a.method(), "shared", "PROTO-009: shared method callable");

// PROTO-010: hasOwnProperty vs in
function P10(x) { this.x = x; }
P10.prototype.y = 2;
var p10 = new P10(1);
assert(p10.hasOwnProperty("x"),   "PROTO-010: hasOwnProperty finds own");
assert(!p10.hasOwnProperty("y"),  "PROTO-010: hasOwnProperty misses prototype");
assert("y" in p10,                "PROTO-010: in finds prototype property");
assert("x" in p10,                "PROTO-010: in finds own property");

__jacDone();
