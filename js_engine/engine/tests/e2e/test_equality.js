// Equality tests — js_engine engine
// Covers abstract equality (==) and strict equality (===)
// ECMAScript §7.2.15 (Abstract) and §7.2.16 (Strict)

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

// ── Strict equality (===): same type, same value ──────────────────────────

check(1,  "1 === 1",            1 === 1,            true);
check(2,  "0 === 0",            0 === 0,            true);
check(3,  "-1 === -1",          -1 === -1,          true);
check(4,  "1.5 === 1.5",        1.5 === 1.5,        true);
check(5,  "\"a\" === \"a\"",    "a" === "a",         true);
check(6,  "true === true",      true === true,       true);
check(7,  "false === false",    false === false,     true);
check(8,  "null === null",      null === null,       true);
check(9,  "undefined === undefined", undefined === undefined, true);

// ── Strict equality (===): different types → always false ────────────────

check(10, "1 === \"1\"",        1 === "1",           false);
check(11, "0 === \"\"",         0 === "",            false);
check(12, "0 === false",        0 === false,         false);
check(13, "1 === true",         1 === true,          false);
check(14, "null === undefined", null === undefined,  false);
check(15, "\"\" === false",     "" === false,        false);
check(16, "0 === null",         0 === null,          false);
check(17, "0 === undefined",    0 === undefined,     false);

// ── Strict inequality (!==) ───────────────────────────────────────────────

check(18, "1 !== 2",            1 !== 2,             true);
check(19, "1 !== \"1\"",        1 !== "1",           true);
check(20, "null !== undefined", null !== undefined,  true);
check(21, "NaN !== NaN",        NaN !== NaN,         true);

// ── NaN: not equal to anything, including itself ──────────────────────────

check(22, "NaN === NaN is false",  NaN === NaN,  false);
check(23, "NaN == NaN is false",   NaN == NaN,   false);

// ── Abstract equality (==): same types (behaves like ===) ─────────────────

check(24, "1 == 1",           1 == 1,            true);
check(25, "\"x\" == \"x\"",  "x" == "x",         true);
check(26, "true == true",     true == true,       true);
check(27, "null == null",     null == null,       true);
check(28, "0 == 0",           0 == 0,             true);

// ── Abstract equality (==): null/undefined cross-coercion ────────────────

check(29, "null == undefined",  null == undefined,   true);
check(30, "undefined == null",  undefined == null,   true);
check(31, "null == 0",          null == 0,           false);
check(32, "null == \"\"",       null == "",          false);
check(33, "undefined == 0",     undefined == 0,      false);
check(34, "undefined == \"\"",  undefined == "",     false);
check(35, "undefined == false", undefined == false,  false);

// ── Abstract equality (==): number vs string ──────────────────────────────

check(36, "1 == \"1\"",         1 == "1",           true);
check(37, "\"1\" == 1",         "1" == 1,           true);
check(38, "0 == \"0\"",         0 == "0",           true);
check(39, "0 == \"\"",          0 == "",            true);
check(40, "0.5 == \"0.5\"",     0.5 == "0.5",       true);
check(41, "\"0.5\" == 0.5",     "0.5" == 0.5,       true);
check(42, "2 == \"2\"",         2 == "2",           true);
check(43, "3.14 == \"3.14\"",   3.14 == "3.14",     true);
check(44, "0 == \"1\"",         0 == "1",           false);
check(45, "1 == \"0\"",         1 == "0",           false);
check(46, "1 == \"\"",          1 == "",            false);

// ── Abstract equality (==): boolean coercion ──────────────────────────────

check(47, "true == 1",          true == 1,           true);
check(48, "false == 0",         false == 0,          true);
check(49, "true == \"1\"",      true == "1",         true);
check(50, "false == \"\"",      false == "",         true);
check(51, "false == \"0\"",     false == "0",        true);  // false→0, "0"→0, 0==0
check(52, "true == 2",          true == 2,           false);
check(53, "false == null",      false == null,       false);
check(54, "false == undefined", false == undefined,  false);

// ── Abstract inequality (!=) ──────────────────────────────────────────────

check(55, "1 != 2",           1 != 2,            true);
check(56, "1 != \"1\"",       1 != "1",          false);
check(57, "null != undefined", null != undefined, false);
check(58, "0 != false",       0 != false,        false);
check(59, "1 != true",        1 != true,         false);
check(60, "NaN != NaN",       NaN != NaN,        true);

// ── Mixed Int32/Float64 strict equality ───────────────────────────────────

check(61, "1 === 1.0",        1 === 1.0,          true);
check(62, "0 === 0.0",        0 === 0.0,          true);
check(63, "2 === 2.0",        2 === 2.0,          true);
check(64, "1 === 1.5",        1 === 1.5,          false);

// ── Object reference equality ─────────────────────────────────────────────

var objA = {};
var objB = {};
var objC = objA;

check(65, "{} !== {} (different refs)",  objA === objB, false);
check(66, "same ref ===",                objA === objC, true);
check(67, "{} != {} (abstract)",         objA == objB,  false);
check(68, "same ref == ",                objA == objC,  true);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Equality tests: " + _passed + " passed, " + _failed + " failed ===");
