// EX-001 through EX-008: Exception handling
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/06_exceptions/test_exceptions.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// EX-001: try...catch basic
var caught = false;
try {
    throw new Error("test");
} catch(e) {
    caught = true;
    assert(e instanceof Error, "EX-001: caught value is Error");
    assertEq(e.message, "test", "EX-001: error message correct");
}
assert(caught, "EX-001: catch block executed");

// EX-001: catch binding is block-scoped
var cbName = "outer";
try { throw new TypeError("inner"); } catch(cbName) {
    // cbName inside catch is the error, not "outer"
    assert(cbName instanceof TypeError, "EX-001: catch binding shadows outer");
}
assertEq(cbName, "outer", "EX-001: catch binding doesn't leak");

// EX-002: try...finally — KNOWN GAP in js_engine
// Standard: finally block ALWAYS runs, even without an error.
var finRan = false;
try {
    // no error
} finally {
    finRan = true;
}
assert(finRan, "EX-002: finally runs when no error (may be gap in js_engine)");

// EX-003: try...catch...finally — KNOWN GAP in js_engine
var catchRan = false;
var fin2Ran = false;
try {
    throw new Error("ex3");
} catch(e3) {
    catchRan = true;
} finally {
    fin2Ran = true;
}
assert(catchRan,  "EX-003: catch runs on error");
assert(fin2Ran,   "EX-003: finally also runs (may be gap in js_engine)");

// EX-004: throw various types
function throwAndCatch(val) {
    try { throw val; } catch(e) { return e; }
}
assert(throwAndCatch(new Error("e")) instanceof Error, "EX-004: throw Error");
assertEq(throwAndCatch("string"), "string", "EX-004: throw string");
assertEq(throwAndCatch(42), 42,             "EX-004: throw number");
assertEq(throwAndCatch({x:1}).x, 1,        "EX-004: throw object");

// EX-005: error propagation through call stack
function level3() { throw new RangeError("deep"); }
function level2() { level3(); }
function level1() { level2(); }
var propagated = false;
try { level1(); } catch(e) {
    propagated = true;
    assert(e instanceof RangeError, "EX-005: error propagates to caller's catch");
    assertEq(e.message, "deep", "EX-005: message preserved through propagation");
}
assert(propagated, "EX-005: catch block reached");

// EX-006: re-throw
function rethrow(val) {
    try {
        throw new TypeError(val);
    } catch(e) {
        if (e.message !== "rethrow-me") {
            return "caught-and-handled";
        }
        throw e; // re-throw
    }
}
assertEq(rethrow("not-me"), "caught-and-handled", "EX-006: conditional catch");
var rethrown = false;
try { rethrow("rethrow-me"); } catch(e) {
    rethrown = true;
    assert(e instanceof TypeError, "EX-006: re-thrown error preserved");
    assertEq(e.message, "rethrow-me", "EX-006: re-thrown message preserved");
}
assert(rethrown, "EX-006: re-thrown error caught at outer level");

// EX-007: catch without binding (ES2019)
var caught7 = false;
try { throw new Error("no-bind"); } catch {
    caught7 = true;
}
assert(caught7, "EX-007: catch without binding (omitted catch param)");

// EX-008: nested try/catch
var inner8 = false, outer8 = false;
try {
    try {
        throw new Error("inner");
    } catch(ei) {
        inner8 = true;
        assertEq(ei.message, "inner", "EX-008: inner catch gets inner error");
        throw new Error("outer"); // escalate a new error
    }
} catch(eo) {
    outer8 = true;
    assertEq(eo.message, "outer", "EX-008: outer catch gets re-thrown error");
}
assert(inner8, "EX-008: inner catch ran");
assert(outer8, "EX-008: outer catch ran");

__jacDone();
