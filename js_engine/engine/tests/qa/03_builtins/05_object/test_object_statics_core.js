// Object static methods: keys/values/entries/assign/create/fromEntries/is/hasOwn
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_statics_core.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ═══════════════════════════════════════════════════════════════════════════
// Object.keys()
// ═══════════════════════════════════════════════════════════════════════════

// Empty object
assertDeep(Object.keys({}), [], "keys: empty object");

// Multiple enumerable keys
var k1 = Object.keys({a:1, b:2, c:3});
assertEq(k1.length, 3,    "keys: 3 enumerable keys");
assert(k1.indexOf("a") >= 0, "keys: contains 'a'");
assert(k1.indexOf("b") >= 0, "keys: contains 'b'");
assert(k1.indexOf("c") >= 0, "keys: contains 'c'");

// Insertion order preserved
var ordered = {};
ordered.z = 1;
ordered.a = 2;
ordered.m = 3;
var k2 = Object.keys(ordered);
assertEq(k2[0], "z", "keys: insertion order first");
assertEq(k2[1], "a", "keys: insertion order second");
assertEq(k2[2], "m", "keys: insertion order third");

// Non-enumerable keys excluded
var ne = {};
Object.defineProperty(ne, "hidden", {value:42, enumerable:false, writable:true, configurable:true});
ne.visible = 1;
var k3 = Object.keys(ne);
assertEq(k3.length, 1,     "keys: non-enumerable excluded count");
assertEq(k3[0], "visible", "keys: only visible");

// Inherited keys excluded
var base = {inherited: 1};
var derived = Object.create(base);
derived.own = 2;
var k4 = Object.keys(derived);
assertEq(k4.length, 1,   "keys: inherited excluded count");
assertEq(k4[0], "own",   "keys: only own");

// Symbol keys excluded
var symObj = {};
symObj[Symbol("s")] = "sym";
symObj.str = "str";
var k5 = Object.keys(symObj);
assertEq(k5.length, 1,   "keys: symbol keys excluded");
assertEq(k5[0], "str",   "keys: only string keys");

// Array argument: index strings
var k6 = Object.keys([10, 20, 30]);
assert(k6.indexOf("0") >= 0, "keys: array index '0'");
assert(k6.indexOf("1") >= 0, "keys: array index '1'");
assert(k6.indexOf("2") >= 0, "keys: array index '2'");

// ═══════════════════════════════════════════════════════════════════════════
// Object.values()
// ═══════════════════════════════════════════════════════════════════════════

// Empty
assertDeep(Object.values({}), [], "values: empty object");

// Own enumerable only
var v1 = Object.values({x:10, y:20});
v1.sort();
assertDeep(v1, [10, 20], "values: own enumerable");

// Non-enumerable excluded
var vne = {};
Object.defineProperty(vne, "h", {value: 99, enumerable: false, writable:true, configurable:true});
vne.v = 1;
var v2 = Object.values(vne);
assertEq(v2.length, 1,  "values: non-enumerable excluded");
assertEq(v2[0], 1,      "values: only visible value");

// Inherited excluded
var vBase = {x:1};
var vChild = Object.create(vBase);
vChild.y = 2;
var v3 = Object.values(vChild);
assertEq(v3.length, 1, "values: inherited excluded");
assertEq(v3[0], 2,     "values: only own value");

// ═══════════════════════════════════════════════════════════════════════════
// Object.entries()
// ═══════════════════════════════════════════════════════════════════════════

// Empty
assertDeep(Object.entries({}), [], "entries: empty object");

// Basic
var e1 = Object.entries({x:1});
assertEq(e1.length, 1,       "entries: one pair");
assertEq(e1[0][0], "x",      "entries: key");
assertEq(e1[0][1], 1,        "entries: value");

// Only own enumerable
var eBase = {a:1};
var eChild = Object.create(eBase);
eChild.b = 2;
var e2 = Object.entries(eChild);
assertEq(e2.length, 1,       "entries: inherited excluded");
assertEq(e2[0][0], "b",      "entries: own key only");

// Order matches insertion
var eOrd = {};
eOrd.z = 3;
eOrd.a = 1;
var e3 = Object.entries(eOrd);
assertEq(e3[0][0], "z",      "entries: insertion order first");
assertEq(e3[1][0], "a",      "entries: insertion order second");

// Round-trip with Object.fromEntries
if (typeof Object.fromEntries === "function") {
    var rt = {p: 10, q: 20};
    var rtResult = Object.fromEntries(Object.entries(rt));
    assertEq(rtResult.p, 10, "entries: round-trip p");
    assertEq(rtResult.q, 20, "entries: round-trip q");
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.assign()
// ═══════════════════════════════════════════════════════════════════════════

// Single source
var at1 = {};
Object.assign(at1, {a:1, b:2});
assertEq(at1.a, 1, "assign: single source a");
assertEq(at1.b, 2, "assign: single source b");

// Multiple sources — later overrides earlier
var at2 = {};
Object.assign(at2, {a:1}, {a:99, b:2});
assertEq(at2.a, 99, "assign: later source overrides");
assertEq(at2.b, 2,  "assign: later source adds b");

// Returns target (same reference)
var at3 = {x:1};
var at3ret = Object.assign(at3, {y:2});
assertEq(at3ret, at3, "assign: returns target reference");

// Shallow copy — nested objects same reference
var nested = {inner: {v:1}};
var at4 = Object.assign({}, nested);
assertEq(at4.inner, nested.inner, "assign: shallow copy nested same ref");

// Non-enumerable NOT copied
var at5src = {};
Object.defineProperty(at5src, "hidden", {value:42, enumerable:false, writable:true, configurable:true});
at5src.visible = 1;
var at5 = Object.assign({}, at5src);
assertEq(at5.visible, 1,         "assign: enumerable copied");
assertEq(at5.hidden, undefined,  "assign: non-enumerable NOT copied");

// Inherited NOT copied
var at6Base = {fromProto: 1};
var at6Src = Object.create(at6Base);
at6Src.own = 2;
var at6 = Object.assign({}, at6Src);
assertEq(at6.own, 2,             "assign: own copied");
assertEq(at6.fromProto, undefined,"assign: inherited NOT copied");

// null/undefined source silently skipped
var at7 = Object.assign({a:1}, null, undefined, {b:2});
assertEq(at7.a, 1, "assign: null/undefined source skipped a");
assertEq(at7.b, 2, "assign: null/undefined source skipped b");

// Empty source — no-op
var at8 = {a:1};
Object.assign(at8, {});
assertEq(at8.a, 1, "assign: empty source no-op");

// String source — copies char indices
var at9 = Object.assign({}, "hi");
assertEq(at9["0"], "h", "assign: string source copies '0'");
assertEq(at9["1"], "i", "assign: string source copies '1'");

// ═══════════════════════════════════════════════════════════════════════════
// Object.create()
// ═══════════════════════════════════════════════════════════════════════════

// With prototype — inherits methods
var crProto = {greet: function() { return "hi"; }};
var crObj = Object.create(crProto);
assertEq(crObj.greet(), "hi",                         "create: inherits method");
assertEq(Object.getPrototypeOf(crObj), crProto,       "create: getPrototypeOf matches");
assert(crObj !== crProto,                             "create: new object, not same ref");

// null prototype — no inherited methods
var crNull = Object.create(null);
assertEq(Object.getPrototypeOf(crNull), null,         "create: null prototype");
assertEq(typeof crNull.toString, "undefined",          "create: null proto has no toString");
assertEq(typeof crNull.hasOwnProperty, "undefined",    "create: null proto has no hasOwnProperty");

// With property descriptors (2nd argument)
var crDesc = Object.create(null, {
    x: {value: 42, enumerable: true, writable: true, configurable: true},
    y: {value: 99, enumerable: true, writable: true, configurable: true}
});
assertEq(crDesc.x, 42, "create: 2nd arg defines x");
assertEq(crDesc.y, 99, "create: 2nd arg defines y");

// instanceof check
function Foo() {}
var crInst = Object.create(Foo.prototype);
assert(crInst instanceof Foo, "create: instanceof works with constructor.prototype");

// ═══════════════════════════════════════════════════════════════════════════
// Object.fromEntries()
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.fromEntries === "function") {
    // Array of pairs
    var fe1 = Object.fromEntries([["a",1],["b",2]]);
    assertEq(fe1.a, 1, "fromEntries: pair a");
    assertEq(fe1.b, 2, "fromEntries: pair b");

    // From a Map
    var feMap = new Map([["x",10],["y",20]]);
    var fe2 = Object.fromEntries(feMap);
    assertEq(fe2.x, 10, "fromEntries: from Map x");
    assertEq(fe2.y, 20, "fromEntries: from Map y");

    // Duplicate keys — last value wins
    var fe3 = Object.fromEntries([["k",1],["k",2],["k",3]]);
    assertEq(fe3.k, 3, "fromEntries: duplicate key last wins");

    // Empty iterable
    var fe4 = Object.fromEntries([]);
    assertEq(Object.keys(fe4).length, 0, "fromEntries: empty iterable → empty obj");

    // Round-trip
    var feRT = {m: "hello", n: 42};
    assertDeep(Object.fromEntries(Object.entries(feRT)), feRT, "fromEntries: round-trip");
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.is()
// ═══════════════════════════════════════════════════════════════════════════

// SameValue for NaN
assertEq(Object.is(NaN, NaN),     true,  "is: NaN === NaN");

// Distinguishes +0 and -0
assertEq(Object.is(+0, -0),       false, "is: +0 !== -0");
assertEq(Object.is(-0, -0),       true,  "is: -0 === -0");
assertEq(Object.is(0, 0),         true,  "is: 0 === 0");

// Primitives
assertEq(Object.is(1, 1),         true,  "is: 1 === 1");
assertEq(Object.is("a", "a"),     true,  "is: 'a' === 'a'");
assertEq(Object.is(null, null),   true,  "is: null === null");
assertEq(Object.is(undefined, undefined), true, "is: undefined === undefined");
assertEq(Object.is(true, true),   true,  "is: true === true");

// Cross-type
assertEq(Object.is(null, undefined), false, "is: null !== undefined");
assertEq(Object.is(true, 1),        false, "is: true !== 1");
assertEq(Object.is("", false),      false, "is: '' !== false");
assertEq(Object.is(0, ""),          false, "is: 0 !== ''");

// References
assertEq(Object.is({}, {}),         false, "is: different objects");
var isRef = {};
assertEq(Object.is(isRef, isRef),   true,  "is: same reference");

// ═══════════════════════════════════════════════════════════════════════════
// Object.hasOwn()
// ═══════════════════════════════════════════════════════════════════════════

// Own property
var hoObj = Object.create({inherited: 1});
hoObj.own = 2;
assertEq(Object.hasOwn(hoObj, "own"),       true,  "hasOwn: own property");
assertEq(Object.hasOwn(hoObj, "inherited"), false, "hasOwn: inherited is false");
assertEq(Object.hasOwn(hoObj, "missing"),   false, "hasOwn: missing is false");

// Non-enumerable own — still true
var hoNE = {};
Object.defineProperty(hoNE, "secret", {value:1, enumerable:false, writable:true, configurable:true});
assertEq(Object.hasOwn(hoNE, "secret"), true, "hasOwn: non-enumerable own is true");

// Symbol key
if (typeof Symbol === "function") {
    var hoSym = Symbol("k");
    var hoSymObj = {};
    hoSymObj[hoSym] = "val";
    assertEq(Object.hasOwn(hoSymObj, hoSym), true, "hasOwn: symbol key");
}

// Null prototype — still works
var hoNull = Object.create(null);
hoNull.x = 1;
assertEq(Object.hasOwn(hoNull, "x"), true,  "hasOwn: null proto own");
assertEq(Object.hasOwn(hoNull, "y"), false, "hasOwn: null proto missing");

__jacDone();
