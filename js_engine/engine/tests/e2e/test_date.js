// Phase 2.6 — Date built-in
// Self-reporting pass/fail test suite for the built js_engine engine.

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

// ── 1: Date.now returns a number ──────────────────────────────────────────
var now = Date.now();
check(1, "Date.now() returns number", typeof now, "number");

// ── 2: Date.now is positive ──────────────────────────────────────────────
check(2, "Date.now() > 0", now > 0, true);

// ── 3: new Date() creates object ─────────────────────────────────────────
var d = new Date();
check(3, "new Date() typeof === object", typeof d, "object");

// ── 4: new Date(ms) ─────────────────────────────────────────────────────
var d2 = new Date(0);
check(4, "new Date(0).getTime() === 0", d2.getTime(), 0.0);

// ── 5: Date.UTC basic ───────────────────────────────────────────────────
var utc = Date.UTC(2024, 0, 15, 12, 30, 45, 500);
check(5, "Date.UTC(2024,0,15,12,30,45,500)", utc, 1705321845500);

// ── 6: getUTCFullYear ───────────────────────────────────────────────────
var d3 = new Date(1705321845500);
check(6, "getUTCFullYear", d3.getUTCFullYear(), 2024);

// ── 7: getUTCMonth ──────────────────────────────────────────────────────
check(7, "getUTCMonth (0-indexed)", d3.getUTCMonth(), 0);

// ── 8: getUTCDate ───────────────────────────────────────────────────────
check(8, "getUTCDate", d3.getUTCDate(), 15);

// ── 9: getUTCDay ────────────────────────────────────────────────────────
check(9, "getUTCDay (0=Sun)", d3.getUTCDay(), 1);

// ── 10: getUTCHours ─────────────────────────────────────────────────────
check(10, "getUTCHours", d3.getUTCHours(), 12);

// ── 11: getUTCMinutes ───────────────────────────────────────────────────
check(11, "getUTCMinutes", d3.getUTCMinutes(), 30);

// ── 12: getUTCSeconds ───────────────────────────────────────────────────
check(12, "getUTCSeconds", d3.getUTCSeconds(), 45);

// ── 13: getUTCMilliseconds ──────────────────────────────────────────────
check(13, "getUTCMilliseconds", d3.getUTCMilliseconds(), 500);

// ── 14: getFullYear (same as UTC since tz=0) ────────────────────────────
check(14, "getFullYear", d3.getFullYear(), 2024);

// ── 15: getMonth ────────────────────────────────────────────────────────
check(15, "getMonth", d3.getMonth(), 0);

// ── 16: getDate ─────────────────────────────────────────────────────────
check(16, "getDate", d3.getDate(), 15);

// ── 17: getDay ──────────────────────────────────────────────────────────
check(17, "getDay", d3.getDay(), 1);

// ── 18: getHours ────────────────────────────────────────────────────────
check(18, "getHours", d3.getHours(), 12);

// ── 19: getMinutes ──────────────────────────────────────────────────────
check(19, "getMinutes", d3.getMinutes(), 30);

// ── 20: getSeconds ──────────────────────────────────────────────────────
check(20, "getSeconds", d3.getSeconds(), 45);

// ── 21: getMilliseconds ─────────────────────────────────────────────────
check(21, "getMilliseconds", d3.getMilliseconds(), 500);

// ── 22: getTimezoneOffset ───────────────────────────────────────────────
check(22, "getTimezoneOffset", d3.getTimezoneOffset(), 0);

// ── 23: getTime ─────────────────────────────────────────────────────────
check(23, "getTime", d3.getTime(), 1705321845500);

// ── 24: valueOf ─────────────────────────────────────────────────────────
check(24, "valueOf === getTime", d3.valueOf(), 1705321845500);

// ── 25: toISOString ─────────────────────────────────────────────────────
check(25, "toISOString", d3.toISOString(), "2024-01-15T12:30:45.500Z");

// ── 26: toJSON ──────────────────────────────────────────────────────────
check(26, "toJSON === toISOString", d3.toJSON(), "2024-01-15T12:30:45.500Z");

// ── 27: toUTCString ─────────────────────────────────────────────────────
check(27, "toUTCString", d3.toUTCString(), "Mon, 15 Jan 2024 12:30:45 GMT");

// ── 28: toDateString ────────────────────────────────────────────────────
check(28, "toDateString", d3.toDateString(), "Mon Jan 15 2024");

// ── 29: toTimeString ────────────────────────────────────────────────────
check(29, "toTimeString", d3.toTimeString(), "12:30:45 GMT+0000");

// ── 30: Date.UTC epoch ──────────────────────────────────────────────────
check(30, "Date.UTC(1970,0,1) === 0", Date.UTC(1970, 0, 1), 0);

// ── 31: Date.UTC year 2000 ──────────────────────────────────────────────
check(31, "Date.UTC(2000,0,1)", Date.UTC(2000, 0, 1), 946684800000);

// ── 32: new Date(y,m,...) constructor ───────────────────────────────────
var d4 = new Date(2024, 0, 15, 12, 30, 45, 500);
check(32, "new Date(2024,0,15,...).getTime()", d4.getTime(), 1705321845500);

// ── 33: setTime ─────────────────────────────────────────────────────────
var d5 = new Date(0);
d5.setTime(1705321845500);
check(33, "setTime then getTime", d5.getTime(), 1705321845500);

// ── 34: setFullYear ─────────────────────────────────────────────────────
var d6 = new Date(1705321845500);
d6.setFullYear(2025);
check(34, "setFullYear(2025).getFullYear()", d6.getFullYear(), 2025);

// ── 35: setMonth ────────────────────────────────────────────────────────
var d7 = new Date(1705321845500);
d7.setMonth(5);
check(35, "setMonth(5).getMonth()", d7.getMonth(), 5);

// ── 36: setDate ─────────────────────────────────────────────────────────
var d8 = new Date(1705321845500);
d8.setDate(20);
check(36, "setDate(20).getDate()", d8.getDate(), 20);

// ── 37: setHours ────────────────────────────────────────────────────────
var d9 = new Date(1705321845500);
d9.setHours(18);
check(37, "setHours(18).getHours()", d9.getHours(), 18);

// ── 38: setMinutes ──────────────────────────────────────────────────────
var d10 = new Date(1705321845500);
d10.setMinutes(15);
check(38, "setMinutes(15).getMinutes()", d10.getMinutes(), 15);

// ── 39: setSeconds ──────────────────────────────────────────────────────
var d11 = new Date(1705321845500);
d11.setSeconds(30);
check(39, "setSeconds(30).getSeconds()", d11.getSeconds(), 30);

// ── 40: setMilliseconds ─────────────────────────────────────────────────
var d12 = new Date(1705321845500);
d12.setMilliseconds(999);
check(40, "setMilliseconds(999).getMilliseconds()", d12.getMilliseconds(), 999);

// ── 41: Date.parse ISO ──────────────────────────────────────────────────
var parsed = Date.parse("2024-01-15T12:30:45.500Z");
check(41, "Date.parse ISO", parsed, 1705321845500);

// ── 42: Date.parse date-only ────────────────────────────────────────────
var parsed2 = Date.parse("2024-01-15");
check(42, "Date.parse date-only", parsed2, 1705276800000);

// ── 43: new Date(string) ───────────────────────────────────────────────
var d13 = new Date("2024-01-15T12:30:45.500Z");
check(43, "new Date(string).getTime()", d13.getTime(), 1705321845500);

// ── 44: epoch edge case ─────────────────────────────────────────────────
var epoch = new Date(0);
check(44, "epoch getUTCFullYear", epoch.getUTCFullYear(), 1970);
check(45, "epoch getUTCMonth", epoch.getUTCMonth(), 0);
check(46, "epoch getUTCDate", epoch.getUTCDate(), 1);
check(47, "epoch getUTCHours", epoch.getUTCHours(), 0);
check(48, "epoch getUTCDay (Thu)", epoch.getUTCDay(), 4);

// ── 49: two-digit year in Date.UTC ──────────────────────────────────────
var old = Date.UTC(99, 0, 1);
var d99 = new Date(old);
check(49, "two-digit year 99 → 1999", d99.getUTCFullYear(), 1999);

// ── 50: toString format ─────────────────────────────────────────────────
var d14 = new Date(1705321845500);
var s = d14.toString();
check(50, "toString format", s, "Mon Jan 15 2024 12:30:45 GMT+0000");

// ── 51: new Date() uses same clock as Date.now() (issue E-1) ────────────
var before = Date.now();
var d15 = new Date();
var after = Date.now();
var t15 = d15.getTime();
check(51, "new Date() >= Date.now() snapshot before", t15 >= before, true);
check(52, "new Date() <= Date.now() snapshot after", t15 <= after, true);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Date tests: " + _passed + " passed, " + _failed + " failed ===");
