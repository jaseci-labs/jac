// PROTO-IC-*: property reads served from the prototype chain are cached per
// call site (receiver shape + [[Prototype]] + prototype epoch). Every way the
// chain can change under a cached site must be seen by the next read.
// BRAND-*: builtin type checks read a per-object brand mirrored from hidden
// marker properties; only a real Map/Set/generator/String object carries one.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/12_prototypes/test_proto_read_cache.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// One call site per helper, so each is a single cached read site.
function readM(o) { return o.m; }
function callM(o) { return o.m(); }
function warm(f, o) { for (var i = 0; i < 5; i++) f(o); return f(o); }

// ── PROTO-IC-001: depth-1 and depth-2 hits, then shadowing and deletes ──
class A { m() { return "A"; } }
class B extends A {}
var b = new B();
assertEq(warm(callM, b), "A", "PROTO-IC-001: inherited method (depth 2)");
B.prototype.m = function () { return "B"; };
assertEq(callM(b), "B", "PROTO-IC-001: key added to an intermediate prototype shadows");
delete B.prototype.m;
assertEq(callM(b), "A", "PROTO-IC-001: delete on the intermediate unshadows");
A.prototype.m = function () { return "A2"; };
assertEq(callM(b), "A2", "PROTO-IC-001: value write on the holder is seen");
b.m = function () { return "own"; };
assertEq(callM(b), "own", "PROTO-IC-001: own property shadows");
delete b.m;
assertEq(callM(b), "A2", "PROTO-IC-001: own delete unshadows");

// ── PROTO-IC-002: [[Prototype]] changes, of the receiver and of a prototype ──
var p1 = { m: "p1" }, p2 = { m: "p2" };
var r = Object.create(p1);
assertEq(warm(readM, r), "p1", "PROTO-IC-002: read through p1");
Object.setPrototypeOf(r, p2);
assertEq(readM(r), "p2", "PROTO-IC-002: receiver re-linked to p2");
var mid = Object.create(p1);
var r2 = Object.create(mid);
assertEq(warm(readM, r2), "p1", "PROTO-IC-002: depth-2 read through mid → p1");
Object.setPrototypeOf(mid, p2);
assertEq(readM(r2), "p2", "PROTO-IC-002: intermediate re-linked to p2");

// ── PROTO-IC-003: same site, same shape, different prototypes ──
var q1 = Object.create({ m: 1 }), q2 = Object.create({ m: 2 });
var seen = [];
for (var i = 0; i < 6; i++) seen.push(readM(i % 2 ? q2 : q1));
assertEq(seen.join(","), "1,2,1,2,1,2", "PROTO-IC-003: polymorphic prototypes");

// ── PROTO-IC-004: data property replaced by an accessor, and back ──
var base = { m: "data" };
var viaBase = Object.create(base);
assertEq(warm(readM, viaBase), "data", "PROTO-IC-004: data read");
var getterCalls = 0;
Object.defineProperty(base, "m", { get: function () { getterCalls++; return "got"; }, configurable: true });
assertEq(readM(viaBase), "got", "PROTO-IC-004: getter installed over a cached data slot");
readM(viaBase);
assertEq(getterCalls, 2, "PROTO-IC-004: getter runs on every read (never cached)");
Object.defineProperty(base, "m", { value: "data2", writable: true, configurable: true });
assertEq(readM(viaBase), "data2", "PROTO-IC-004: back to data");

// ── PROTO-IC-005: prototype pushed into dictionary mode by deletes ──
var dp = { a: 1, b: 2, c: 3, m: "dp" };
var viaDp = Object.create(dp);
assertEq(warm(readM, viaDp), "dp", "PROTO-IC-005: read before");
delete dp.a; delete dp.b;
assertEq(readM(viaDp), "dp", "PROTO-IC-005: read after dict conversion");
dp.m = "dp2";
assertEq(readM(viaDp), "dp2", "PROTO-IC-005: write after dict conversion");

// ── PROTO-IC-006: builtin prototypes reached from Array / Map / Set receivers ──
function pushOne(a) { a.push(1); return a.length; }
var arr = [];
warm(pushOne, arr);
var origPush = Array.prototype.push;
Array.prototype.push = function () { return "patched"; };
assertEq([].push(), "patched", "PROTO-IC-006: replaced Array.prototype.push is seen");
Array.prototype.push = origPush;
assertEq(pushOne([7]), 2, "PROTO-IC-006: restored push");
function mapGet(m) { return m.get("k"); }
var mp = new Map([["k", "v"]]);
assertEq(warm(mapGet, mp), "v", "PROTO-IC-006: Map.prototype.get");
var origGet = Map.prototype.get;
Map.prototype.get = function () { return "patched"; };
assertEq(mapGet(mp), "patched", "PROTO-IC-006: replaced Map.prototype.get is seen");
Map.prototype.get = origGet;
function mapSize(m) { return m.size; }
assertEq(warm(mapSize, mp), 1, "PROTO-IC-006: Map size");
mp.set("k2", 1);
assertEq(mapSize(mp), 2, "PROTO-IC-006: Map size tracks the map");
var st = new Set([1]);
function setHas(s) { return s.has(1); }
assertEq(warm(setHas, st), true, "PROTO-IC-006: Set.prototype.has");

// ── PROTO-IC-007: receivers whose reads are exotic keep their behaviour ──
function readLen(o) { return o.length; }
assertEq(warm(readLen, new String("abcd")), 4, "PROTO-IC-007: String wrapper length");
(function () { assertEq(warm(readLen, arguments), 3, "PROTO-IC-007: arguments.length"); })(1, 2, 3);
assertEq(warm(readLen, new Uint8Array(5)), 5, "PROTO-IC-007: typed array length");
var ta = new Uint8Array(2);
function taSub(t) { return t.subarray; }
assertEq(warm(taSub, ta), Uint8Array.prototype.subarray, "PROTO-IC-007: typed array method");

// ── BRAND-001: only real builtin objects are branded ──
var fakeGen = { __gen__: 1 };
assertEq(fakeGen.next, undefined, "BRAND-001: an own __gen__ property does not make a generator");
function* g() { yield 1; }
var gen = g();
assertEq(gen.next().value, 1, "BRAND-001: a real generator still iterates");
assertEq(Object.getOwnPropertyNames(gen).length, 0, "BRAND-001: generator has no visible own keys");
assertEq(Object.prototype.toString.call(new String("x")), "[object String]", "BRAND-001: String wrapper");
assertEq(Object.prototype.toString.call(Object.create(String.prototype)), "[object Object]",
    "BRAND-001: inheriting from String.prototype is not a String object");
class MyStr extends String {}
assertEq(new MyStr("hey").length, 3, "BRAND-001: String subclass instance is a String object");
assertEq(new MyStr("hey").toUpperCase(), "HEY", "BRAND-001: String subclass method");
var mp2 = new Map(), notMap = Object.create(Map.prototype);
assertEq(mp2.size, 0, "BRAND-001: Map size");
var threw = false;
try { notMap.size; } catch (e) { threw = e instanceof TypeError; }
assert(threw, "BRAND-001: Map.prototype.size on a non-Map throws TypeError");

__jacDone();
