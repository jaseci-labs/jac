// Regression guards for engine-correctness-fixes:
//   Jac int floor division (`//`) in Date civil math, URI percent-hex nibbles,
//   process.hrtime sec/ns split, fs stat mode bits, RegExp capture pair count.
// Full BMP Unicode in encodeURIComponent still depends on string storage (separate gap).
var fs = require("fs");
var path = require("path");
var os = require("os");

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_engine_correctness_fixes.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}

function assertIntComponents(pair, label) {
    assert(Array.isArray(pair), label + ": returns array");
    assertEq(pair.length, 2, label + ": [sec, ns] length");
    assert(typeof pair[0] === "number", label + ": sec is number");
    assert(typeof pair[1] === "number", label + ": ns is number");
    assert(pair[0] === (pair[0] | 0), label + ": sec is integral (floor division path)");
    assert(pair[1] === (pair[1] | 0), label + ": ns is integral");
    assert(pair[0] >= 0, label + ": sec non-negative");
    assert(pair[1] >= 0, label + ": ns non-negative");
}

function assertValidPercentHex(s, msg) {
    var i = 0;
    while (i < s.length) {
        if (s.charAt(i) !== "%") {
            i = i + 1;
            continue;
        }
        assert(i + 2 < s.length, msg + ": truncated % escape");
        var h1 = s.charAt(i + 1);
        var h2 = s.charAt(i + 2);
        assert(/^[0-9A-F]$/.test(h1), msg + ": bad hex high nibble");
        assert(/^[0-9A-F]$/.test(h2), msg + ": bad hex low nibble");
        i = i + 3;
    }
}

// --- ENG-DATE: civil calendar + UTC field extraction (date.na.jac `//`) ---

assertEq(Date.UTC(2024, 0, 15, 12, 30, 45, 500), 1705321845500, "ENG-DATE-001: Date.UTC");

var utcKnown = new Date(1705321845500);
assertEq(utcKnown.getUTCFullYear(), 2024, "ENG-DATE-002: getUTCFullYear");
assertEq(utcKnown.getUTCMonth(), 0, "ENG-DATE-003: getUTCMonth");
assertEq(utcKnown.getUTCDate(), 15, "ENG-DATE-004: getUTCDate");
assertEq(utcKnown.getUTCHours(), 12, "ENG-DATE-005: getUTCHours");
assertEq(utcKnown.getUTCMinutes(), 30, "ENG-DATE-006: getUTCMinutes");
assertEq(utcKnown.getUTCSeconds(), 45, "ENG-DATE-007: getUTCSeconds");
assertEq(utcKnown.getUTCMilliseconds(), 500, "ENG-DATE-008: getUTCMilliseconds");
assertEq(utcKnown.getUTCDay(), 1, "ENG-DATE-009: getUTCDay (Mon)");

assertEq(Date.UTC(1970, 0, 1), 0, "ENG-DATE-010: Date.UTC epoch");

var civil = new Date(Date.UTC(2023, 5, 15, 0, 0, 0, 0));
assertEq(civil.toISOString(), "2023-06-15T00:00:00.000Z", "ENG-DATE-011: toISOString civil roundtrip");

assert(typeof Date.now() === "number", "ENG-DATE-012: Date.now is number");
assert(Date.now() > 0, "ENG-DATE-013: Date.now positive");

// --- ENG-STR: percent-encoding nibble math (`b1 // 16`, etc.) ---

assertEq(encodeURIComponent(" "), "%20", "ENG-STR-001: space encodes with integral nibbles");
assertEq(encodeURIComponent("a@b"), "a%40b", "ENG-STR-002: @ encodes to %40");
assertValidPercentHex(encodeURIComponent("a\u007fb"), "ENG-STR-003: DEL uses valid %XX");
assertEq(decodeURIComponent("%C3%A9"), "\u00e9", "ENG-STR-004: decode UTF-8 sequence");
assertEq(
    encodeURI("https://example.com/x y"),
    "https://example.com/x%20y",
    "ENG-STR-005: encodeURI space"
);

// --- ENG-PROC: process.hrtime second/ns split (`//`) ---

assert(typeof process.hrtime === "function", "ENG-PROC-001: hrtime is function");
var ht0 = process.hrtime();
assertIntComponents(ht0, "ENG-PROC-002: hrtime()");
var ht1 = process.hrtime(ht0);
assertIntComponents(ht1, "ENG-PROC-003: hrtime(previous)");

if (typeof process.hrtime.bigint === "function") {
    var hb1 = process.hrtime.bigint();
    var hb2 = process.hrtime.bigint();
    assert(typeof hb1 === "bigint", "ENG-PROC-004: hrtime.bigint type");
    assert(hb2 >= hb1, "ENG-PROC-005: hrtime.bigint monotonic");
}

// --- ENG-RX: capture pair count (`len(ov) // 2`) ---

var engRx = /(a)(b)(c)(d)(e)/.exec("zzabcde");
assertEq(engRx[1], "a", "ENG-RX-001: fifth capture index 1");
assertEq(engRx[5], "e", "ENG-RX-002: fifth capture index 5");

var engNamed = /(?<w>aa)(?<x>bb)(?<y>cc)/.exec("aabbcc");
assert(engNamed.groups !== undefined, "ENG-RX-003: groups object");
assertEq(engNamed.groups.w, "aa", "ENG-RX-004: named group w");
assertEq(engNamed.groups.y, "cc", "ENG-RX-005: named group y");

// --- ENG-FS: stat mode type bits (`mode_val // 4096`) ---

var engTmp = path.join(os.tmpdir(), "jac_eng_correct_" + process.pid);
fs.mkdirSync(engTmp, { recursive: true });
var engFile = path.join(engTmp, "f.txt");
var engDir = path.join(engTmp, "d");
fs.writeFileSync(engFile, "x", "utf8");
fs.mkdirSync(engDir);

var engStatFile = fs.statSync(engFile);
assert(engStatFile.isFile(), "ENG-FS-001: statSync isFile");
assert(!engStatFile.isDirectory(), "ENG-FS-002: statSync !isDirectory for file");

var engStatDir = fs.statSync(engDir);
assert(engStatDir.isDirectory(), "ENG-FS-003: statSync isDirectory");
assert(!engStatDir.isFile(), "ENG-FS-004: statSync !isFile for dir");

function engFsFinish() {
    try {
        fs.rmSync(engTmp, { recursive: true, force: true });
    } catch (e) {}
    __jacDone();
}

if (fs.promises && typeof fs.promises.stat === "function") {
    fs.promises
        .stat(engFile)
        .then(function (st) {
            assert(st.isFile(), "ENG-FS-005: promises.stat isFile");
            engFsFinish();
        })
        .catch(function (e) {
            assert(false, "ENG-FS-005: promises.stat error: " + e);
            engFsFinish();
        });
} else {
    engFsFinish();
}
