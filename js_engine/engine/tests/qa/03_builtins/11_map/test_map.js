// MAP-001 through MAP-007: Map built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/11_map/test_map.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// MAP-001: Constructor
var emptyMap = new Map();
assertEq(emptyMap.size, 0,                  "MAP-001: empty Map has size 0");
var fromIterable = new Map([["a",1],["b",2],["c",3]]);
assertEq(fromIterable.size, 3,              "MAP-001: from iterable size");
assertEq(fromIterable.get("b"), 2,          "MAP-001: from iterable get");

// MAP-002: set / get / has
var m = new Map();
var chainResult = m.set("key", "value");
assertEq(chainResult, m,                    "MAP-002: set returns the Map (chaining)");
assertEq(m.get("key"), "value",             "MAP-002: get string key");
assert(m.has("key"),                        "MAP-002: has returns true");
assert(!m.has("missing"),                   "MAP-002: has missing returns false");
assertEq(m.get("missing"), undefined,       "MAP-002: get missing returns undefined");
// number key
m.set(42, "fortyTwo");
assertEq(m.get(42), "fortyTwo",             "MAP-002: number key");
// object key
var objKey = {id:1};
m.set(objKey, "obj");
assertEq(m.get(objKey), "obj",              "MAP-002: object key");
var diffRef = {id:1};
assertEq(m.get(diffRef), undefined,         "MAP-002: different object ref = miss");

// MAP-003: delete / clear / size
var dm = new Map([["x",1],["y",2],["z",3]]);
assertEq(dm.size, 3,                        "MAP-003: size before delete");
assertEq(dm.delete("y"), true,              "MAP-003: delete returns true when found");
assertEq(dm.size, 2,                        "MAP-003: size after delete");
assertEq(dm.delete("missing"), false,       "MAP-003: delete returns false when missing");
dm.clear();
assertEq(dm.size, 0,                        "MAP-003: clear empties the map");

// MAP-004: forEach — insertion order
var order = new Map([["a",1],["b",2],["c",3]]);
var visited = [];
order.forEach(function(value, key, map) {
    visited.push([key, value]);
    assert(map === order,                   "MAP-004: forEach 3rd arg is map itself");
});
assertDeep(visited, [["a",1],["b",2],["c",3]], "MAP-004: forEach insertion order");

// MAP-005: keys / values / entries iterators
var iMap = new Map([["x",10],["y",20]]);
var keys = [], vals = [], ents = [];
for (var k of iMap.keys())    keys.push(k);
for (var v of iMap.values())  vals.push(v);
for (var e of iMap.entries()) ents.push(e);
assertDeep(keys, ["x","y"],            "MAP-005: keys()");
assertDeep(vals, [10,20],              "MAP-005: values()");
assertDeep(ents, [["x",10],["y",20]], "MAP-005: entries()");

// MAP-006: Symbol.iterator — same as entries
var itEntries = [], itDirect = [];
for (var e2 of iMap.entries()) itEntries.push(e2);
for (var e3 of iMap)           itDirect.push(e3);
assertDeep(itDirect, itEntries,        "MAP-006: Symbol.iterator same as entries");

// MAP-007: Key equality — SameValueZero
var svzMap = new Map();
svzMap.set(NaN, "nan");
assertEq(svzMap.get(NaN), "nan",       "MAP-007: NaN key (SameValueZero: NaN===NaN)");
svzMap.set(+0, "zero");
assertEq(svzMap.get(-0), "zero",       "MAP-007: -0 and +0 are same key");
assertEq(svzMap.size, 2,              "MAP-007: NaN and 0 are distinct keys");

__jacDone();
