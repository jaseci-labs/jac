// Plan: testing_plans/03_ecmascript_language/JSON_PARSE_STRINGIFY_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// Exit criteria: EC-JSON-1 (JSON-001..006), EC-JSON-2 (JSON-007..011)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/09_json/test_json_parse_core_and_reviver.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertSyntaxError(fn, msg) {
    var ok = false;
    try {
        fn();
    } catch (e) {
        ok = e instanceof SyntaxError;
    }
    assert(ok, msg);
}

// --- EC-JSON-1: JSON-001..006 (parse grammar / value decoding) ---

// JSON-001
assertEq(JSON.parse("42"), 42, "JSON-001: parse number");
assertEq(JSON.parse('"hello"'), "hello", "JSON-001: parse string");
assertEq(JSON.parse("true"), true, "JSON-001: parse true");
assertEq(JSON.parse("false"), false, "JSON-001: parse false");
assertEq(JSON.parse("null"), null, "JSON-001: parse null");

// JSON-002
assertDeep(JSON.parse("{}"), {}, "JSON-002: parse empty object");
assertDeep(JSON.parse("[]"), [], "JSON-002: parse empty array");
assertDeep(JSON.parse('{"a":1,"b":2}'), { a: 1, b: 2 }, "JSON-002: parse object");
assertDeep(JSON.parse("[1,2,3]"), [1, 2, 3], "JSON-002: parse array");
var nested = JSON.parse('{"a":{"b":{"c":42}}}');
assertEq(nested.a.b.c, 42, "JSON-002: parse nested");

// JSON-003
assertEq(JSON.parse('"\\""'), '"', "JSON-003: parse \\\" escape");
assertEq(JSON.parse('"\\\\"'), "\\", "JSON-003: parse \\\\ escape");
assertEq(JSON.parse('"\\/"'), "/", "JSON-003: parse \\/ escape");
// Use \\u0008/\\u000c — this engine's string literals do not treat \\b/\\f as control chars.
assertEq(JSON.parse('"\\b"'), "\u0008", "JSON-003: parse \\b escape");
assertEq(JSON.parse('"\\f"'), "\u000c", "JSON-003: parse \\f escape");
assertEq(JSON.parse('"\\n"'), "\n", "JSON-003: parse \\n escape");
assertEq(JSON.parse('"\\r"'), "\r", "JSON-003: parse \\r escape");
assertEq(JSON.parse('"\\t"'), "\t", "JSON-003: parse \\t escape");
assertEq(JSON.parse('"\\u0041"'), "A", "JSON-003: parse \\uXXXX");

// JSON-004
assertEq(JSON.parse("1.5"), 1.5, "JSON-004: float");
assertEq(JSON.parse("-42"), -42, "JSON-004: negative");
assertEq(JSON.parse("1e3"), 1000, "JSON-004: scientific notation");
assertSyntaxError(
    function () {
        JSON.parse("01");
    },
    "JSON-004: leading zero throws SyntaxError"
);

// JSON-005
var invalids = [
    "invalid",
    "{a:1}",
    "{'a':1}",
    "[1,2,]",
    "[1,2,",
    "undefined",
    "/*c*/null",
    "{]",
    ""
];
for (var i = 0; i < invalids.length; i++) {
    assertSyntaxError(
        function () {
            JSON.parse(invalids[i]);
        },
        "JSON-005: invalid JSON throws SyntaxError: " + invalids[i]
    );
}

// JSON-006
assertEq(JSON.parse("  null  \n"), null, "JSON-006: leading/trailing JSON whitespace allowed");
assertSyntaxError(
    function () {
        JSON.parse("nullx");
    },
    "JSON-006: trailing non-whitespace after document throws SyntaxError"
);

// --- EC-JSON-2: JSON-007..011 (reviver) ---

// JSON-007 bottom-up order + root key ""
var orderObj = [];
JSON.parse('{"a":1,"b":2}', function (k, v) {
    orderObj.push(k);
    return v;
});
assertDeep(orderObj, ["a", "b", ""], "JSON-007: object reviver order bottom-up with root key");

var orderArr = [];
JSON.parse("[1,2]", function (k, v) {
    orderArr.push(k);
    return v;
});
assertDeep(orderArr, ["0", "1", ""], "JSON-007: array reviver order bottom-up with root key");

// JSON-008 undefined from reviver: object property omitted; array slot becomes null
var delObj = JSON.parse('{"a":1,"b":2}', function (k, v) {
    if (k === "b") return undefined;
    return v;
});
assertDeep(delObj, { a: 1 }, "JSON-008: reviver undefined omits object property");
var delArr = JSON.parse("[0,1,2]", function (k, v) {
    if (k === "1") return undefined;
    return v;
});
assertDeep(delArr, [0, null, 2], "JSON-008: reviver undefined for array index yields null element");

// JSON-009 this binding and key types (string keys for array indices)
var rootThisOk = false;
var innerThisOk = false;
JSON.parse('{"x":{"y":1}}', function (k, v) {
    if (k === "") {
        rootThisOk = typeof this === "object" && this !== null;
    }
    if (k === "y") {
        innerThisOk =
            this &&
            typeof this === "object" &&
            this.y === 1 &&
            Object.prototype.hasOwnProperty.call(this, "y");
    }
    return v;
});
assert(rootThisOk, "JSON-009: reviver this for root key is object");
assert(innerThisOk, "JSON-009: reviver this for nested key y is inner holder {y:1}");

// JSON-010 non-callable reviver ignored
assertDeep(JSON.parse("[1]", null), [1], "JSON-010: null reviver ignored");
assertDeep(JSON.parse("[1]", undefined), [1], "JSON-010: undefined reviver ignored");
assertDeep(JSON.parse("[1]", 0), [1], "JSON-010: non-callable reviver ignored");

// JSON-011 exception from reviver propagates
var threwRev = false;
try {
    JSON.parse("1", function () {
        throw new Error("reviver boom");
    });
} catch (e) {
    threwRev = e instanceof Error && e.message === "reviver boom";
}
assert(threwRev, "JSON-011: exception from reviver propagates");

__jacDone();
