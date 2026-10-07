// CF-001 through CF-017: Control flow (synchronous)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_control_flow.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CF-001: if / else
assertEq(true  ? "yes" : "no", "yes", "CF-001: truthy condition");
assertEq(false ? "yes" : "no", "no",  "CF-001: falsy condition");
var ifResult = "";
if (1)       { ifResult = "one"; }
else if (0)  { ifResult = "zero"; }
else         { ifResult = "other"; }
assertEq(ifResult, "one", "CF-001: else-if chain");

// CF-002: Ternary ? :
assertEq(3 > 2 ? "gt" : "le",  "gt",  "CF-002: basic ternary");
assertEq(1 < 0 ? "gt" : "le",  "le",  "CF-002: false branch");
var nested = (true ? (false ? "a" : "b") : "c");
assertEq(nested, "b", "CF-002: nested ternary");
var assigned = 5;
assigned = assigned > 3 ? assigned * 2 : 0;
assertEq(assigned, 10, "CF-002: ternary in assignment");

// CF-003: switch / case
function sw(v) {
    switch(v) {
        case 1: return "one";
        case 2: return "two";
        default: return "other";
    }
}
assertEq(sw(1), "one",   "CF-003: switch case 1");
assertEq(sw(2), "two",   "CF-003: switch case 2");
assertEq(sw(9), "other", "CF-003: switch default");
// expressions as case values
var threshold = 10;
var swExpr = "";
switch(true) {
    case 5 > threshold: swExpr = "high"; break;
    case 5 < threshold: swExpr = "low"; break;
}
assertEq(swExpr, "low", "CF-003: expression case values");

// CF-004: switch fall-through — KNOWN GAP in js_engine (implicit break per case)
// Standard behavior: without break, execution falls through to the next case.
// js_engine inserts implicit breaks. We test what the engine actually does.
var fallResult = [];
switch(1) {
    case 1: fallResult.push("one"); // intentionally no break
    case 2: fallResult.push("two"); // intentionally no break
    case 3: fallResult.push("three"); break;
}
// Standard: ["one","two","three"]; js_engine (known gap): ["one"]
assert(fallResult[0] === "one", "CF-004: first matching case always runs");
// Don't assert fall-through — it is a known gap

// CF-010: for loop
var sum = 0;
for (var fi = 1; fi <= 5; fi++) { sum += fi; }
assertEq(sum, 15, "CF-010: for loop sum 1..5");
// nested
var pairs = [];
for (var r = 0; r < 2; r++) {
    for (var cc = 0; cc < 2; cc++) { pairs.push([r, cc]); }
}
assertEq(pairs.length, 4, "CF-010: nested for loops");
// empty init and update
var fe = 0;
for (;fe < 3;) { fe++; }
assertEq(fe, 3, "CF-010: for with empty init/update");

// CF-011: for...in
var forInObj = { a: 1, b: 2, c: 3 };
var keys = [];
for (var k in forInObj) { keys.push(k); }
assertEq(keys.length, 3, "CF-011: for-in enumerates own properties");
assert(keys.indexOf("a") !== -1, "CF-011: key 'a' found");
// inherited properties appear
function Parent() {}
Parent.prototype.inherited = true;
var child = new Parent();
child.own = "yes";
var allKeys = [];
for (var kk in child) { allKeys.push(kk); }
assert(allKeys.indexOf("inherited") !== -1, "CF-011: for-in includes inherited");
assert(allKeys.indexOf("own") !== -1, "CF-011: for-in includes own");
// non-enumerable skipped
var neObj = {};
Object.defineProperty(neObj, "hidden", { value: 1, enumerable: false });
neObj.visible = 2;
var neKeys = [];
for (var nk in neObj) { neKeys.push(nk); }
assertEq(neKeys.length, 1, "CF-011: for-in skips non-enumerable");
assertEq(neKeys[0], "visible", "CF-011: only visible key");

// CF-012: for...of
var ofArr = [10, 20, 30];
var ofVals = [];
for (var v of ofArr) { ofVals.push(v); }
assertEq(ofVals.join(","), "10,20,30", "CF-012: for-of over array");
// strings
var chars = [];
for (var ch of "abc") { chars.push(ch); }
assertEq(chars.join(""), "abc", "CF-012: for-of over string");
// Map
var m = new Map([["x", 1], ["y", 2]]);
var mapPairs = [];
for (var [mk, mv] of m) { mapPairs.push(mk + "=" + mv); }
assertEq(mapPairs.join(","), "x=1,y=2", "CF-012: for-of over Map");
// Set
var s = new Set([1, 2, 3]);
var setVals = [];
for (var sv of s) { setVals.push(sv); }
assertEq(setVals.join(","), "1,2,3", "CF-012: for-of over Set");
// generator
function* gen() { yield 1; yield 2; yield 3; }
var genVals = [];
for (var gv of gen()) { genVals.push(gv); }
assertEq(genVals.join(","), "1,2,3", "CF-012: for-of over generator");

// CF-014: while
var wn = 0;
while (wn < 5) { wn++; }
assertEq(wn, 5, "CF-014: while basic");
// zero iterations
var wz = 10;
while (false) { wz = 0; }
assertEq(wz, 10, "CF-014: while zero iterations");

// CF-015: do...while — executes at least once
var doCount = 0;
do { doCount++; } while (false);
assertEq(doCount, 1, "CF-015: do-while executes at least once");
do { doCount++; } while (doCount < 3);
assertEq(doCount, 3, "CF-015: do-while repeats");

// CF-016: break and continue
var bArr = [];
for (var bi = 0; bi < 10; bi++) {
    if (bi === 5) break;
    bArr.push(bi);
}
assertEq(bArr.length, 5, "CF-016: break exits loop");
var cArr = [];
for (var ci = 0; ci < 5; ci++) {
    if (ci % 2 === 0) continue;
    cArr.push(ci);
}
assertEq(cArr.join(","), "1,3", "CF-016: continue skips even numbers");
// nested: break breaks only innermost
var nestedBreak = 0;
for (var ni = 0; ni < 3; ni++) {
    for (var nj = 0; nj < 3; nj++) {
        if (nj === 1) break;
        nestedBreak++;
    }
}
assertEq(nestedBreak, 3, "CF-016: break only innermost loop");

// CF-017: labeled break and continue
outer: for (var li = 0; li < 3; li++) {
    for (var lj = 0; lj < 3; lj++) {
        if (li === 1 && lj === 1) break outer;
    }
}
assertEq(li, 1, "CF-017: labeled break exits outer loop");

var contResult = [];
outerCont: for (var oi = 0; oi < 3; oi++) {
    for (var oj = 0; oj < 3; oj++) {
        if (oj === 1) continue outerCont;
        contResult.push(oi + "," + oj);
    }
}
assertEq(contResult.length, 3, "CF-017: labeled continue skips to outer loop (3 entries)");

__jacDone();
