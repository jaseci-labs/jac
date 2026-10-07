// WS-001 through WS-003: WeakSet built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/14_weakset/test_weakset.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// WS-001: Constructor
var emptyWS = new WeakSet();
assertEq(typeof emptyWS, "object",          "WS-001: WeakSet is an object");
var o1 = {}, o2 = {};
var wsFromIterable = new WeakSet([o1, o2]);
assert(wsFromIterable.has(o1),              "WS-001: from iterable has o1");
assert(wsFromIterable.has(o2),              "WS-001: from iterable has o2");
assert(!wsFromIterable.has({}),             "WS-001: from iterable has different ref = false");

// WS-002: add / has / delete
var ws = new WeakSet();
var val1 = {}, val2 = {}, val3 = {};
ws.add(val1);
ws.add(val2);
assert(ws.has(val1),                        "WS-002: has val1");
assert(ws.has(val2),                        "WS-002: has val2");
assertEq(ws.has(val3), false,               "WS-002: has missing = false");
assertEq(ws.delete(val1), true,             "WS-002: delete returns true");
assertEq(ws.has(val1), false,               "WS-002: after delete has = false");
assertEq(ws.delete(val3), false,            "WS-002: delete missing returns false");

// WS-003: Primitive value throws TypeError
var threw = false;
try { ws.add("string"); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WS-003: string value throws TypeError");
threw = false;
try { ws.add(42); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WS-003: number value throws TypeError");
threw = false;
try { ws.add(null); } catch(e) { threw = e instanceof TypeError; }
assert(threw, "WS-003: null value throws TypeError");

__jacDone();
