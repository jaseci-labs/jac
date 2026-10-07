// Object.prototype methods: toString/valueOf/hasOwnProperty/isPrototypeOf/
// propertyIsEnumerable/constructor/toLocaleString
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_prototype.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.toString()
// ═══════════════════════════════════════════════════════════════════════════

// Direct call on plain object
assertEq({}.toString(), "[object Object]", "toString: plain object");

// Using .call to inspect internal [[Class]]
assertEq(Object.prototype.toString.call({}),          "[object Object]",    "toString.call: object");
assertEq(Object.prototype.toString.call([]),          "[object Array]",     "toString.call: array");
assertEq(Object.prototype.toString.call(null),        "[object Null]",      "toString.call: null");
assertEq(Object.prototype.toString.call(undefined),   "[object Undefined]", "toString.call: undefined");
assertEq(Object.prototype.toString.call(42),          "[object Number]",    "toString.call: number");
assertEq(Object.prototype.toString.call("str"),       "[object String]",    "toString.call: string");
assertEq(Object.prototype.toString.call(true),        "[object Boolean]",   "toString.call: boolean");
assertEq(Object.prototype.toString.call(function(){}), "[object Function]", "toString.call: function");

// RegExp
assertEq(Object.prototype.toString.call(/abc/),      "[object RegExp]",    "toString.call: regex");

// Date
assertEq(Object.prototype.toString.call(new Date()),  "[object Date]",     "toString.call: date");

// Custom Symbol.toStringTag
if (typeof Symbol !== "undefined" && Symbol.toStringTag) {
    var tagged = {};
    Object.defineProperty(tagged, Symbol.toStringTag, {value: "Custom", configurable: true});
    assertEq(Object.prototype.toString.call(tagged), "[object Custom]", "toString: Symbol.toStringTag");

    var tagged2 = {};
    Object.defineProperty(tagged2, Symbol.toStringTag, {value: "MyModule", configurable: true});
    assertEq(Object.prototype.toString.call(tagged2), "[object MyModule]", "toString: custom tag MyModule");
}

// Overridden toString on an instance
var overridden = {toString: function() { return "custom!"; }};
assertEq(overridden.toString(), "custom!", "toString: overridden on instance");
assertEq(Object.prototype.toString.call(overridden), "[object Object]", "toString.call: still reveals Object");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.valueOf()
// ═══════════════════════════════════════════════════════════════════════════

// Plain object — returns same object
var vo1 = {x: 1};
assertEq(vo1.valueOf(), vo1, "valueOf: plain object returns self");

// Number wrapper — valueOf returns primitive
var vo2 = Object(42);
assertEq(vo2.valueOf(), 42,           "valueOf: Number wrapper returns 42");
assertEq(typeof vo2.valueOf(), "number", "valueOf: Number wrapper type");

// String wrapper
var vo3 = Object("hi");
assertEq(vo3.valueOf(), "hi",            "valueOf: String wrapper returns 'hi'");
assertEq(typeof vo3.valueOf(), "string",  "valueOf: String wrapper type");

// Boolean wrapper
var vo4 = Object(false);
assertEq(vo4.valueOf(), false,           "valueOf: Boolean wrapper returns false");
assertEq(typeof vo4.valueOf(), "boolean", "valueOf: Boolean wrapper type");

// Custom valueOf override
var vo5 = {valueOf: function() { return 123; }};
assertEq(vo5.valueOf(), 123, "valueOf: custom override");
assertEq(+vo5, 123,          "valueOf: custom used in arithmetic");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.hasOwnProperty()
// ═══════════════════════════════════════════════════════════════════════════

// Own property
var hp1 = {a: 1, b: 2};
assert(hp1.hasOwnProperty("a"), "hasOwnProperty: own 'a'");
assert(hp1.hasOwnProperty("b"), "hasOwnProperty: own 'b'");

// Inherited property — false
var hp2 = Object.create({inherited: 1});
hp2.own = 2;
assert(hp2.hasOwnProperty("own"),        "hasOwnProperty: own prop");
assert(!hp2.hasOwnProperty("inherited"), "hasOwnProperty: inherited is false");

// Missing property — false
assert(!hp1.hasOwnProperty("missing"), "hasOwnProperty: missing is false");

// After delete — false
var hp3 = {x: 1};
delete hp3.x;
assert(!hp3.hasOwnProperty("x"), "hasOwnProperty: after delete is false");

// Non-enumerable own — still true
var hp4 = {};
Object.defineProperty(hp4, "hidden", {value: 42, enumerable: false, writable:true, configurable:true});
assert(hp4.hasOwnProperty("hidden"), "hasOwnProperty: non-enum own is true");

// Null-prototype object has no hasOwnProperty method
var hp5 = Object.create(null);
hp5.x = 1;
assertEq(typeof hp5.hasOwnProperty, "undefined", "hasOwnProperty: null-proto has no method");

// But we can call it via Object.prototype.hasOwnProperty.call
assert(Object.prototype.hasOwnProperty.call(hp5, "x"),    "hasOwnProperty.call: null-proto own");
assert(!Object.prototype.hasOwnProperty.call(hp5, "y"),   "hasOwnProperty.call: null-proto missing");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.isPrototypeOf()
// ═══════════════════════════════════════════════════════════════════════════

// Direct parent
var ip1 = {};
var ip2 = Object.create(ip1);
assert(ip1.isPrototypeOf(ip2), "isPrototypeOf: direct parent");

// Grandparent (transitive)
var ip3 = Object.create(ip2);
assert(ip1.isPrototypeOf(ip3), "isPrototypeOf: grandparent transitive");

// Not in chain
assert(!ip2.isPrototypeOf(ip1), "isPrototypeOf: not in chain");

// Self is not prototype of self
assert(!ip1.isPrototypeOf(ip1), "isPrototypeOf: self is false");

// Object.prototype is prototype of all normal objects
assert(Object.prototype.isPrototypeOf({}),  "isPrototypeOf: Object.prototype → {}");
assert(Object.prototype.isPrototypeOf([]),  "isPrototypeOf: Object.prototype → []");

// Null-prototype object
var ipNull = Object.create(null);
assert(!Object.prototype.isPrototypeOf(ipNull), "isPrototypeOf: null-proto is false");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.propertyIsEnumerable()
// ═══════════════════════════════════════════════════════════════════════════

// Enumerable own property
var pie1 = {a: 1, b: 2};
assert(pie1.propertyIsEnumerable("a"), "propertyIsEnumerable: enumerable own");

// Non-enumerable own — false
var pie2 = {};
Object.defineProperty(pie2, "hidden", {value: 1, enumerable: false, writable:true, configurable:true});
assert(!pie2.propertyIsEnumerable("hidden"), "propertyIsEnumerable: non-enum own is false");

// Inherited property (even if enumerable on proto) — false
var pie3base = {inherited: 1};
var pie3 = Object.create(pie3base);
assert(!pie3.propertyIsEnumerable("inherited"), "propertyIsEnumerable: inherited is false");

// Missing property — false
assert(!pie1.propertyIsEnumerable("missing"), "propertyIsEnumerable: missing is false");

// Array index property
var pie4 = [10, 20, 30];
assert(pie4.propertyIsEnumerable(0),    "propertyIsEnumerable: array index 0");
assert(pie4.propertyIsEnumerable(1),    "propertyIsEnumerable: array index 1");
assert(!pie4.propertyIsEnumerable("length"), "propertyIsEnumerable: array 'length' is false");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.constructor
// ═══════════════════════════════════════════════════════════════════════════

// Plain object
assertEq({}.constructor, Object, "constructor: {} is Object");

// After Object.create with a proto that has a constructor
function Foo() {}
var crFoo = Object.create(Foo.prototype);
assertEq(crFoo.constructor, Foo, "constructor: Object.create(Foo.prototype)");

// After setPrototypeOf to null
var cNull = {a: 1};
Object.setPrototypeOf(cNull, null);
assertEq(cNull.constructor, undefined, "constructor: after setPrototypeOf(null) is undefined");

// Constructor of built-in types
assertEq([].constructor, Array,   "constructor: [] is Array");
assertEq("".constructor, String,  "constructor: '' is String");
assertEq((0).constructor, Number, "constructor: 0 is Number");

// ═══════════════════════════════════════════════════════════════════════════
// Object.prototype.toLocaleString() — may be absent in js_engine
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.prototype.toLocaleString === "function") {
    var tls = {toString: function() { return "localized"; }};
    assertEq(tls.toLocaleString(), "localized", "toLocaleString: calls toString by default");

    var tls2 = {};
    assertEq(tls2.toLocaleString(), "[object Object]", "toLocaleString: plain object");
}

__jacDone();
