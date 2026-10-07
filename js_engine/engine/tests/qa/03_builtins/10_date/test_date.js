// DATE-001 through DATE-051: Date built-in
// UTC civil-calendar / getter cases fixed by int floor division (//) are also in
// tests/qa/05_integration/test_engine_correctness_fixes.js (ENG-DATE-*).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/10_date/test_date.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// DATE-001: new Date() — current timestamp
var now = new Date();
assert(now instanceof Date,              "DATE-001: instanceof Date");
assert(typeof now.getTime() === "number","DATE-001: getTime() returns number");
assert(now.getTime() > 0,               "DATE-001: current time is positive");

// DATE-002: new Date(ms)
var epoch = new Date(0);
assertEq(epoch.getTime(),    0,          "DATE-002: epoch = 0ms");
var ms1 = new Date(1000);
assertEq(ms1.getTime(),      1000,       "DATE-002: 1000ms");
var neg = new Date(-86400000); // 1 day before epoch
assert(neg.getTime() < 0,               "DATE-002: negative timestamp");

// DATE-003: new Date(string) — ISO 8601
var iso = new Date("2000-01-01T00:00:00.000Z");
assertEq(iso.getTime(),  946684800000,   "DATE-003: ISO 8601 parse");
var iso2 = new Date("2020-06-15");
assert(!isNaN(iso2.getTime()),           "DATE-003: date-only ISO parse");

// DATE-004: new Date(y, m, d, ...)
var d4 = new Date(2023, 0, 15); // month is 0-indexed
assertEq(d4.getFullYear(),  2023,        "DATE-004: getFullYear");
assertEq(d4.getMonth(),     0,           "DATE-004: getMonth 0=January");
assertEq(d4.getDate(),      15,          "DATE-004: getDate");
// overflow: month 12 = January next year
var overflow = new Date(2023, 12, 1);
assertEq(overflow.getFullYear(), 2024,   "DATE-004: month overflow rolls to next year");
assertEq(overflow.getMonth(),    0,      "DATE-004: overflowed month = 0");

// DATE-005: Date() without new — returns string
var ds = Date();
assertEq(typeof ds, "string",           "DATE-005: Date() without new returns string");

// DATE-010: Statics
assert(typeof Date.now() === "number",  "DATE-010: Date.now() returns number");
assert(Date.now() > 0,                  "DATE-010: Date.now() is positive");
// Date.UTC
var utcMs = Date.UTC(2000, 0, 1);
assertEq(utcMs, 946684800000,           "DATE-010: Date.UTC epoch");
// Date.parse
var parsedMs = Date.parse("2000-01-01T00:00:00.000Z");
assertEq(parsedMs, 946684800000,        "DATE-010: Date.parse ISO string");

// DATE-020: Getters — use a known UTC date to avoid timezone ambiguity
var known = new Date(Date.UTC(2023, 5, 15, 12, 30, 45, 500)); // 2023-06-15 12:30:45.500 UTC
assert(typeof known.getTime()          === "number", "DATE-020: getTime");
assert(typeof known.getTimezoneOffset() === "number","DATE-020: getTimezoneOffset returns number");
// Engine is UTC-only per spec, so offset should be 0; skip this assertion on non-UTC environments
var tzOffset = known.getTimezoneOffset();
if (tzOffset !== 0) {
    // Running in a non-UTC timezone (e.g. Node.js with local timezone set)
    // Only verify that UTC getters always return the UTC value
    assertEq(known.getUTCFullYear(), 2023,  "DATE-021: UTC getters correct year");
    assertEq(known.getUTCMonth(),    5,      "DATE-021: UTC month = June (0-indexed)");
    assertEq(known.getUTCDate(),     15,     "DATE-021: UTC date = 15");
    assertEq(known.getUTCHours(),    12,     "DATE-021: UTC hours = 12");
    assertEq(known.getUTCMinutes(),  30,     "DATE-021: UTC minutes = 30");
    assertEq(known.getUTCSeconds(),  45,     "DATE-021: UTC seconds = 45");
    assertEq(known.getUTCMilliseconds(), 500,"DATE-021: UTC ms = 500");
} else {
    // UTC-only engine: local getters must match UTC getters
    assertEq(known.getUTCFullYear(),   known.getFullYear(), "DATE-021: UTC getters match local");
    assertEq(known.getUTCMonth(),      known.getMonth(),    "DATE-021: UTC month matches");
    assertEq(known.getUTCDate(),       known.getDate(),     "DATE-021: UTC date matches");
    assertEq(known.getUTCHours(),      known.getHours(),    "DATE-021: UTC hours matches");
    assertEq(known.getUTCMinutes(),    known.getMinutes(),  "DATE-021: UTC minutes matches");
    assertEq(known.getUTCSeconds(),    known.getSeconds(),  "DATE-021: UTC seconds matches");
    assertEq(known.getUTCMilliseconds(),known.getMilliseconds(),"DATE-021: UTC ms matches");
    assertEq(known.getUTCDay(),        known.getDay(),      "DATE-021: UTC day matches");
}

// DATE-030: Setters
var setter = new Date(0);
setter.setTime(5000);
assertEq(setter.getTime(), 5000,        "DATE-030: setTime");
setter.setFullYear(2010);
assertEq(setter.getFullYear(), 2010,    "DATE-030: setFullYear");
setter.setMonth(5);
assertEq(setter.getMonth(), 5,          "DATE-030: setMonth");
setter.setDate(20);
assertEq(setter.getDate(), 20,          "DATE-030: setDate");
setter.setHours(9);
assertEq(setter.getHours(), 9,          "DATE-030: setHours");
setter.setMinutes(15);
assertEq(setter.getMinutes(), 15,       "DATE-030: setMinutes");
setter.setSeconds(30);
assertEq(setter.getSeconds(), 30,       "DATE-030: setSeconds");
setter.setMilliseconds(250);
assertEq(setter.getMilliseconds(), 250, "DATE-030: setMilliseconds");

// DATE-040: String methods
var strDate = new Date(Date.UTC(2023, 0, 1, 12, 0, 0, 0));
assertEq(typeof strDate.toISOString(),      "string", "DATE-040: toISOString");
assertEq(strDate.toISOString(), "2023-01-01T12:00:00.000Z", "DATE-040: toISOString value");
assertEq(typeof strDate.toJSON(),           "string", "DATE-040: toJSON");
assertEq(strDate.toJSON(), strDate.toISOString(), "DATE-040: toJSON = toISOString");
assertEq(typeof strDate.toString(),         "string", "DATE-040: toString");
assertEq(typeof strDate.toDateString(),     "string", "DATE-040: toDateString");
assertEq(typeof strDate.toTimeString(),     "string", "DATE-040: toTimeString");
assertEq(typeof strDate.toUTCString(),      "string", "DATE-040: toUTCString");
assertEq(typeof strDate.toLocaleString(),   "string", "DATE-040: toLocaleString");
assertEq(typeof strDate.toLocaleDateString(),"string","DATE-040: toLocaleDateString");
assertEq(typeof strDate.toLocaleTimeString(),"string","DATE-040: toLocaleTimeString");

// DATE-041: valueOf
var vDate = new Date(12345);
assertEq(vDate.valueOf(),    12345,      "DATE-041: valueOf = getTime");
assertEq(+vDate,             12345,      "DATE-041: coerce to number = getTime");

// DATE-050: setUTC* — NOT IMPLEMENTED — verify no crash (just check typeof)
var setUTCDate = new Date(0);
void (typeof setUTCDate.setUTCFullYear);
void (typeof setUTCDate.setUTCMonth);
void (typeof setUTCDate.setUTCDate);
void (typeof setUTCDate.setUTCHours);
void (typeof setUTCDate.setUTCMinutes);
void (typeof setUTCDate.setUTCSeconds);
void (typeof setUTCDate.setUTCMilliseconds);

// DATE-051: Invalid Date
var invalid = new Date("not a date");
assert(isNaN(invalid.getTime()),         "DATE-051: Invalid Date getTime = NaN");
assertEq(invalid.toISOString !== undefined ? (() => { try { return invalid.toISOString(); } catch(e) { return "threw"; } })() : "threw",
    "threw", "DATE-051: Invalid Date toISOString throws");

__jacDone();
