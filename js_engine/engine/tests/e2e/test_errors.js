// Error / exception tests — js_engine engine
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── 1: try-catch catches thrown Error ─────────────────────────────────────
var caught1 = false;
try {
    throw new Error("boom");
} catch (e) {
    caught1 = true;
}
check(1, "try-catch catches Error", caught1, true);

// ── 2: catch receives error message ───────────────────────────────────────
var msg2 = "";
try {
    throw new Error("hello error");
} catch (e) {
    msg2 = e.message;
}
check(2, "e.message === 'hello error'", msg2, "hello error");

// ── 3: throw string ───────────────────────────────────────────────────────
var caughtStr = "";
try {
    throw "string error";
} catch (e) {
    caughtStr = e;
}
check(3, "catch thrown string", caughtStr, "string error");

// ── 4: throw number ───────────────────────────────────────────────────────
var caughtNum = 0;
try {
    throw 42;
} catch (e) {
    caughtNum = e;
}
check(4, "catch thrown number 42", caughtNum, 42);

// ── 5: finally always runs (no throw) ────────────────────────────────────
var fin5 = 0;
try {
    fin5 = fin5 + 1;
} finally {
    fin5 = fin5 + 10;
}
check(5, "finally runs: result === 11", fin5, 11);

// ── 6: finally runs on throw ─────────────────────────────────────────────
var fin6 = 0;
try {
    try {
        throw new Error("x");
    } finally {
        fin6 = fin6 + 5;
    }
} catch (e) {}
check(6, "finally runs on throw: fin6 === 5", fin6, 5);

// ── 7: try-catch-finally all run ─────────────────────────────────────────
var tcf = 0;
try {
    throw new Error("y");
} catch (e) {
    tcf = tcf + 1;
} finally {
    tcf = tcf + 10;
}
check(7, "try-catch-finally: tcf === 11", tcf, 11);

// ── 8: no exception → catch not entered ──────────────────────────────────
var nc = 0;
try {
    nc = nc + 1;
} catch (e) {
    nc = nc + 100;
}
check(8, "no throw → catch not entered: nc === 1", nc, 1);

// ── 9: TypeError caught ───────────────────────────────────────────────────
var typeErr = false;
try {
    null.property;
} catch (e) {
    typeErr = true;
}
check(9, "TypeError accessing null.prop is caught", typeErr, true);

// ── 10: TypeError message accessible ─────────────────────────────────────
var typeMsg = "";
try {
    null.property;
} catch (e) {
    typeMsg = typeof e.message;
}
check(10, "TypeError e.message is a string", typeMsg, "string");

// ── 11: rethrow ───────────────────────────────────────────────────────────
var rethrown = false;
try {
    try {
        throw new Error("rethrow me");
    } catch (e) {
        throw e;
    }
} catch (e) {
    rethrown = e.message === "rethrow me";
}
check(11, "rethrown error message matches", rethrown, true);

// ── 12: nested try-catch independent ─────────────────────────────────────
var inner = 0;
var outer = 0;
try {
    try {
        throw new Error("inner");
    } catch (e) {
        inner = 1;
    }
    outer = 1;
} catch (e) {
    outer = 2;
}
check(12, "inner catch, outer not triggered: outer === 1", outer, 1);

// ── 13: conditional catch ─────────────────────────────────────────────────
var condResult = "";
try {
    throw new Error("check me");
} catch (e) {
    if (e.message === "check me") {
        condResult = "matched";
    } else {
        condResult = "no match";
    }
}
check(13, "conditional catch message match", condResult, "matched");

// ── 14: error in loop caught ──────────────────────────────────────────────
var loopCaught = 0;
var li = 0;
while (li < 5) {
    try {
        if (li === 3) { throw new Error("loop"); }
    } catch (e) {
        loopCaught = loopCaught + 1;
    }
    li = li + 1;
}
check(14, "error caught once in loop", loopCaught, 1);

// ── 15: function that throws ──────────────────────────────────────────────
function risky(n) {
    if (n < 0) { throw new Error("negative"); }
    return n * 2;
}
var res15 = 0;
try {
    risky(-1);
} catch (e) {
    res15 = 99;
}
check(15, "function throw caught: res15 === 99", res15, 99);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Error tests: " + _passed + " passed, " + _failed + " failed ===");
