// Plan: testing_plans/03_ecmascript_language/JSON_PARSE_STRINGIFY_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// Exit criteria: EC-JSON-3 (JSON-012..018), EC-JSON-4 (JSON-019..023)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/09_json/test_json_stringify_core_and_hooks.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertTypeError(fn, msg) {
    var ok = false;
    try {
        fn();
    } catch (e) {
        ok = e instanceof TypeError;
    }
    assert(ok, msg);
}

// --- EC-JSON-3: JSON-012..018 ---

// JSON-012 primitives + wrappers
assertEq(JSON.stringify("hello"), '"hello"', "JSON-012: stringify string");
assertEq(JSON.stringify(42), "42", "JSON-012: stringify number");
assertEq(JSON.stringify(true), "true", "JSON-012: stringify true");
assertEq(JSON.stringify(false), "false", "JSON-012: stringify false");
assertEq(JSON.stringify(null), "null", "JSON-012: stringify null");
assertEq(JSON.stringify(new String("x")), '"x"', "JSON-012: String object unwraps");
assertEq(JSON.stringify(new Number(7)), "7", "JSON-012: Number object unwraps");
assertEq(JSON.stringify(new Boolean(false)), "false", "JSON-012: Boolean object unwraps");

// JSON-013 top-level undefined / function / symbol -> undefined; array -> null; object omitted
assertEq(JSON.stringify(undefined), undefined, "JSON-013: top-level undefined");
assertEq(JSON.stringify(function () {}), undefined, "JSON-013: top-level function");
var sym = typeof Symbol !== "undefined" ? Symbol("s") : null;
if (sym !== null) {
    assertEq(JSON.stringify(sym), undefined, "JSON-013: top-level symbol");
    assertEq(JSON.stringify([sym]), "[null]", "JSON-013: symbol in array becomes null");
    assertEq(JSON.stringify({ a: sym }), "{}", "JSON-013: symbol-valued property omitted");
}

var withUndef = { a: 1, b: undefined, c: function () {} };
var su = JSON.stringify(withUndef);
var pu = JSON.parse(su);
assertEq(typeof pu.b, "undefined", "JSON-013: undefined object property omitted");
assertEq(typeof pu.c, "undefined", "JSON-013: function object property omitted");
assertEq(JSON.stringify([undefined, 1]), "[null,1]", "JSON-013: undefined array element -> null");

// JSON-014 non-finite numbers and -0
assertEq(JSON.stringify(NaN), "null", "JSON-014: NaN -> null");
assertEq(JSON.stringify(Infinity), "null", "JSON-014: Infinity -> null");
assertEq(JSON.stringify(-Infinity), "null", "JSON-014: -Infinity -> null");
assertEq(JSON.stringify(-0), "0", "JSON-014: -0 serializes as 0");

// JSON-015 enumerable own string keys; symbol keys skipped
var o = { a: 1 };
Object.defineProperty(o, "b", { value: 2, enumerable: false });
if (typeof Symbol !== "undefined") {
    o[Symbol("h")] = 3;
}
assertEq(JSON.stringify(o), '{"a":1}', "JSON-015: only enumerable own string keys");

// JSON-016 array order and holes -> null
assertEq(JSON.stringify([1, , 3]), "[1,null,3]", "JSON-016: sparse array holes serialize as null");

// JSON-017 circular
var circular = {};
circular.self = circular;
assertTypeError(
    function () {
        JSON.stringify(circular);
    },
    "JSON-017: circular reference throws TypeError"
);

// JSON-018 BigInt
if (typeof BigInt !== "undefined") {
    assertTypeError(
        function () {
            JSON.stringify(1n);
        },
        "JSON-018: stringify BigInt throws TypeError"
    );
    assertTypeError(
        function () {
            JSON.stringify({ x: 1n });
        },
        "JSON-018: stringify object with BigInt value throws TypeError"
    );
}

// --- EC-JSON-4: JSON-019..023 ---

// JSON-019 toJSON return value is what serialization sees
var tj = {
    toJSON: function () {
        return { k: 9 };
    },
    ignored: 1
};
assertEq(JSON.stringify(tj), '{"k":9}', "JSON-019: toJSON return replaces object");

// JSON-020 Date toJSON / invalid date
var d0 = new Date(0);
assertEq(typeof JSON.stringify(d0), "string", "JSON-020: Date stringifies to string");
assertEq(JSON.stringify(new Date(NaN)), "null", "JSON-020: invalid Date serializes as null");

// JSON-021 replacer runs after toJSON; root and nested keys
var log21 = [];
var o21 = {
    a: 1,
    toJSON: function () {
        return { b: 2 };
    }
};
JSON.stringify(o21, function (k, v) {
    log21.push("k=" + k + ",v=" + JSON.stringify(v));
    return v;
});
assert(log21[0].indexOf("k=") === 0, "JSON-021: replacer invoked");
assert(log21.indexOf("k=,v={\"b\":2}") !== -1, "JSON-021: root replacer sees toJSON output");
assert(log21.indexOf("k=b,v=2") !== -1, "JSON-021: nested replacer sees property b");

// JSON-022 replacer array whitelist + numeric key coercion
assertEq(
    JSON.stringify({ 1: "one", 10: "ten", z: "z" }, [1, 10]),
    '{"1":"one","10":"ten"}',
    "JSON-022: replacer array whitelists string keys after number coercion"
);
assertEq(JSON.stringify({ a: 1, b: 2 }, ["b", "a", "b"]), '{"b":2,"a":1}', "JSON-022: replacer order and dedupe");

// JSON-023 errors from toJSON / replacer propagate
var threwTo = false;
try {
    JSON.stringify({
        toJSON: function () {
            throw new Error("tojson");
        }
    });
} catch (e) {
    threwTo = e instanceof Error && e.message === "tojson";
}
assert(threwTo, "JSON-023: exception from toJSON propagates");

var threwRep = false;
try {
    JSON.stringify({ a: 1 }, function () {
        throw new Error("rep");
    });
} catch (e) {
    threwRep = e instanceof Error && e.message === "rep";
}
assert(threwRep, "JSON-023: exception from replacer propagates");

__jacDone();
