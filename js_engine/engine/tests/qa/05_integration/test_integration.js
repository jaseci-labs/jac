// XC-001 through XC-012: Cross-cutting integration tests
var fs   = require("fs");
var path = require("path");
var os   = require("os");

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_integration.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// XC-001: Methods on literals
assertEq("hello".toUpperCase(),          "HELLO",  "XC-001: string method on literal");
assertDeep([1,2].map(function(x){return x*2;}), [2,4], "XC-001: array method on literal");
assertEq((123).toString(16),             "7b",     "XC-001: number method on literal");

// XC-002: Method chaining — filter -> map -> join
var result2 = [1,2,3,4,5,6]
    .filter(function(x){ return x % 2 === 0; })
    .map(function(x){ return x * x; })
    .join("-");
assertEq(result2, "4-16-36", "XC-002: filter().map().join() chain");

// XC-003: Callbacks + built-ins
var sorted3 = [3,1,2].sort();
assertDeep(sorted3, [1,2,3], "XC-003: sort default");
var loggedItems = [];
[10,20,30].forEach(function(item) { loggedItems.push(item); });
assertDeep(loggedItems, [10,20,30], "XC-003: forEach with callback");

// XC-004: Error from built-in in try/catch
var caught4 = null;
try {
    JSON.parse("this is not json");
} catch(e) {
    caught4 = e;
}
assert(caught4 instanceof SyntaxError,  "XC-004: JSON.parse error is SyntaxError");
assert(caught4.message.length > 0,      "XC-004: error has message");

// XC-005: Symbol integration — for-of on Map via Symbol.iterator
var map5 = new Map([["a",1],["b",2],["c",3]]);
var keys5 = [];
for (var entry of map5) {
    keys5.push(entry[0]);
}
assertDeep(keys5, ["a","b","c"], "XC-005: for-of on Map via Symbol.iterator");

// ---- Async coordination (before XC-006 / XC-009 / XC-012 schedule doneAsync) ----
var asyncExpected = new Set(["XC-006", "XC-009", "XC-012"]);
var asyncDone = new Set();
function doneAsync(name) {
    asyncDone.add(name);
    if (asyncDone.size === asyncExpected.size) {
        for (var key of asyncExpected) {
            assert(asyncDone.has(key), "all async tests completed: " + key);
        }
        __jacDone();
    }
}

setTimeout(function() {
    var missing = [];
    for (var key of asyncExpected) {
        if (!asyncDone.has(key)) missing.push(key);
    }
    console.error("FAIL: XC integration async timeout. Not done: " + missing.join(", "));
    __reg.bump(); return;
}, 5000);

// XC-006: Promise + Timer
var resolved6 = false;
var p6 = new Promise(function(resolve) {
    setTimeout(function() {
        resolved6 = true;
        resolve("done");
    }, 10);
});
p6.then(function(val) {
    assert(resolved6 === true, "XC-006: timer should have fired");
    assertEq(val, "done",      "XC-006: resolved value");
    doneAsync("XC-006");
});

// XC-007: Class + built-ins (Map/Set fields)
class DataStore {
    constructor() {
        this.cache = new Map();
        this.tags  = new Set();
    }
    add(key, val, ...tags) {
        this.cache.set(key, val);
        tags.forEach(t => this.tags.add(t));
    }
    get(key) { return this.cache.get(key); }
    tagList() { return [...this.tags].sort(); }
}
var ds = new DataStore();
ds.add("x", 42, "foo", "bar");
ds.add("y", 99, "foo", "baz");
assertEq(ds.get("x"), 42,                        "XC-007: class+Map get");
assertDeep(ds.tagList(), ["bar","baz","foo"],     "XC-007: class+Set sorted tags");

// XC-008: Destructuring + Spread
var obj8a = {a:1, b:2};
var obj8b = {c:3, b:99};
var merged8 = {...obj8a, ...obj8b};
assertEq(merged8.a, 1,  "XC-008: spread object a");
assertEq(merged8.b, 99, "XC-008: spread object b override");
assertEq(merged8.c, 3,  "XC-008: spread object c");
// deduplicate with Set+spread
var deduped8 = [...new Set([1,1,2,3,3,4])];
assertDeep(deduped8, [1,2,3,4], "XC-008: spread Set deduplication");

// XC-009: Async + Error + Promise.all
async function failingTask() { throw new Error("task failed"); }
async function successTask() { return 42; }
async function xc009() {
    var results = await Promise.allSettled([successTask(), failingTask()]);
    assertEq(results[0].status, "fulfilled",  "XC-009: first task fulfilled");
    assertEq(results[0].value,  42,           "XC-009: first task value");
    assertEq(results[1].status, "rejected",   "XC-009: second task rejected");
    assertEq(results[1].reason.message, "task failed", "XC-009: rejection reason");
    doneAsync("XC-009");
}
xc009().catch(function(e) {
    console.error("FAIL: XC-009: " + e.message);
    __reg.bump(); __jacDone();
});

// XC-010: require + module — write and read a file with fs
var tmpFile10 = path.join(os.tmpdir(), "xc010_" + process.pid + ".txt");
fs.writeFileSync(tmpFile10, "integration test");
var content10 = fs.readFileSync(tmpFile10, "utf8");
assertEq(content10, "integration test", "XC-010: require(fs)+writeFileSync+readFileSync");
fs.unlinkSync(tmpFile10);
assert(!fs.existsSync(tmpFile10), "XC-010: file cleaned up");

// XC-011: Generator + Iterator — for-of, spread, Array.from
function* range(start, end) {
    for (var i = start; i < end; i++) yield i;
}
var forOfResult = [];
for (var n of range(1, 5)) forOfResult.push(n);
assertDeep(forOfResult, [1,2,3,4], "XC-011: generator for-of");
var spreadResult = [...range(10, 13)];
assertDeep(spreadResult, [10,11,12], "XC-011: generator spread");
var fromResult = Array.from(range(5, 8));
assertDeep(fromResult, [5,6,7], "XC-011: generator Array.from");

// XC-012: Event loop ordering — nextTick -> microtask -> setTimeout
var order12 = [];
process.nextTick(function() { order12.push("nextTick"); });
Promise.resolve().then(function() { order12.push("microtask"); });
setTimeout(function() {
    order12.push("setTimeout");
    assert(order12.indexOf("nextTick")  < order12.indexOf("setTimeout"),
        "XC-012: nextTick before setTimeout");
    assert(order12.indexOf("microtask") < order12.indexOf("setTimeout"),
        "XC-012: microtask before setTimeout");
    doneAsync("XC-012");
}, 0);
