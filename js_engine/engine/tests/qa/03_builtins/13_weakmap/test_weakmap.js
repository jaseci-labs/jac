// WM-001 through WM-003: WeakMap built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/13_weakmap/test_weakmap.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// WM-001: Constructor
var emptyWM = new WeakMap();
assertEq(typeof emptyWM, "object",          "WM-001: WeakMap is an object");
// from iterable of [key, value] pairs where keys are objects
var k1 = {}, k2 = {};
var wmFromIterable = new WeakMap([[k1, "val1"], [k2, "val2"]]);
assertEq(wmFromIterable.get(k1), "val1",    "WM-001: from iterable get k1");
assertEq(wmFromIterable.get(k2), "val2",    "WM-001: from iterable get k2");

// WM-002: set / get / has / delete
var wm = new WeakMap();
var key1 = {}, key2 = {}, key3 = {};
wm.set(key1, 100);
wm.set(key2, 200);
assertEq(wm.get(key1), 100,                 "WM-002: get key1");
assertEq(wm.get(key2), 200,                 "WM-002: get key2");
assert(wm.has(key1),                        "WM-002: has key1");
assertEq(wm.has(key3), false,               "WM-002: has missing key");
assertEq(wm.get(key3), undefined,           "WM-002: get missing = undefined");
// delete
assertEq(wm.delete(key1), true,             "WM-002: delete returns true");
assertEq(wm.has(key1), false,               "WM-002: after delete has = false");
assertEq(wm.delete(key3), false,            "WM-002: delete missing returns false");
// overwrite
wm.set(key2, 999);
assertEq(wm.get(key2), 999,                 "WM-002: overwrite value");

// WM-003: Primitive key throws TypeError
var threw = false;
try { wm.set("string", 1); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WM-003: string key throws TypeError");
threw = false;
try { wm.set(42, 1); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WM-003: number key throws TypeError");
threw = false;
try { wm.set(null, 1); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WM-003: null key throws TypeError");

__jacDone();
