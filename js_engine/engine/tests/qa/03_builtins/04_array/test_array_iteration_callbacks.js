// ARRAY_COMPREHENSIVE_TEST_PLAN §9 — callback iteration methods
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_iteration_callbacks.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ARR-I-001 forEach — skips holes
var fe = [];
var h = ["a", , "c"];
h.forEach(function (v, i) {
    fe.push(i + ":" + v);
});
assertDeep(fe, ["0:a", "2:c"], "ARR-I-001: forEach skips empty slots");

// ARR-I-002 thisArg
var ctx = { mul: 3 };
var out = [];
[1, 2].forEach(function (x) {
    out.push(x * this.mul);
}, ctx);
assertDeep(out, [3, 6], "ARR-I-002: forEach thisArg");

// ARR-I-010 map — holes preserved in result
var mp = [1, , 3].map(function (x) {
    return x * 2;
});
assertEq(mp[0], 2, "ARR-I-010: map dense");
assertEq(mp[2], 6, "ARR-I-010: map index 2");
assert(!(1 in mp), "ARR-I-010: hole stays hole");

assertDeep(
    [1, 2, 3].filter(function (x) {
        return x % 2 === 0;
    }),
    [2],
    "ARR-I-010: filter"
);

// ARR-I-011
assertDeep(
    [1, 2, 3].filter(function () {
        return false;
    }),
    [],
    "ARR-I-011: filter empty"
);

// ARR-I-020 every / some empty
assert([].every(function () { return false; }), "ARR-I-020: every [] → true");
assert(![].some(function () { return true; }), "ARR-I-020: some [] → false");

// ARR-I-021 short-circuit
var cnt = 0;
[1, 2, 3, 4].some(function (x) {
    cnt++;
    return x === 2;
});
assertEq(cnt, 2, "ARR-I-021: some short-circuit");

cnt = 0;
[1, 2, 3, 4].every(function (x) {
    cnt++;
    return x < 3;
});
assertEq(cnt, 3, "ARR-I-021: every short-circuit");

// ARR-I-030 find / findIndex — holes seen as undefined (find* does not use `in` check)
assertEq([10, , 30].findIndex(function (x) { return x === undefined; }), 1, "ARR-I-030: findIndex at hole");
assertEq(
    [1, 2, 3].find(function (x) {
        return x > 2;
    }),
    3,
    "ARR-I-030: find value"
);

assertEq(
    [1, 2, 3].find(function (x) {
        return x > 10;
    }),
    undefined,
    "ARR-I-030: find miss"
);
assertEq(
    [1, 2, 3].findIndex(function (x) {
        return x > 10;
    }),
    -1,
    "ARR-I-030: findIndex miss"
);

// ARR-I-031 findLast*
if (typeof [].findLast === "function") {
    assertEq(
        [1, 2, 3, 2].findLast(function (x) {
            return x === 2;
        }),
        2,
        "ARR-I-031: findLast"
    );
    assertEq(
        [1, 2, 3, 2].findLastIndex(function (x) {
            return x === 2;
        }),
        3,
        "ARR-I-031: findLastIndex"
    );
}

// ARR-I-040 reduce
assertEq(
    [1, 2, 3, 4].reduce(function (a, x) {
        return a + x;
    }, 0),
    10,
    "ARR-I-040: reduce with initial"
);
assertEq(
    [1, 2, 3, 4].reduce(function (a, x) {
        return a + x;
    }),
    10,
    "ARR-I-041: reduce no initial multi"
);
assertEq([42].reduce(function () { return 0; }), 42, "ARR-I-041: reduce no initial single");

var r42 = false;
try {
    [].reduce(function () {});
} catch (e) {
    r42 = e instanceof TypeError;
}
assert(r42, "ARR-I-042: reduce empty throws TypeError");

assertEq(
    [1, 2, 3].reduceRight(function (a, x) {
        return a - x;
    }),
    0,
    "ARR-I-040: reduceRight"
);

// ARR-I-043 sparse reduce — skips holes
var seen = [];
[1, , 3].reduce(function (_, x, i) {
    seen.push(i);
    return 0;
}, 0);
assertDeep(seen, [0, 2], "ARR-I-043: reduce skips hole indices");

// ARR-I-050 flatMap — Vite recursiveReaddir uses Array.flat; flatMap for nested maps
assertDeep(
    [1, 2, 3].flatMap(function (x) { return [x, x * 2]; }),
    [1, 2, 2, 4, 3, 6],
    "ARR-I-050: flatMap doubles"
);
assertDeep(
    ["a", "b"].flatMap(function (x) { return x.split(""); }),
    ["a", "b"],
    "ARR-I-051: flatMap string split"
);
assertDeep(
    [[1], [2, 3]].flatMap(function (x) { return x; }),
    [1, 2, 3],
    "ARR-I-052: flatMap flatten one level"
);
var fmArgs = [];
[10, 20].flatMap(function (x, i, arr) {
    fmArgs.push(i + ":" + x + ":" + arr.length);
    return [x];
});
assertDeep(fmArgs, ["0:10:2", "1:20:2"], "ARR-I-053: flatMap callback args");
var fmCtx = { tag: "x" };
assertDeep(
    [1, 2].flatMap(function () { return [this.tag]; }, fmCtx),
    ["x", "x"],
    "ARR-I-054: flatMap thisArg"
);

__jacDone();
