// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §10, RX-O-*, RX-ERR-006 — ECG-RX-VERSION-GATED
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_optional_features.js"
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
function assertThrows(fn, ErrType, msg) {
    __reg.assertThrows(fn, ErrType, msg);
}

// --- RX-O-001 hasIndices / .indices ---
try {
    var rd = new RegExp("a", "d");
    var md = rd.exec("xa");
    assert(md !== null, "RX-O-001: d exec match");
    assert(md.indices !== undefined, "RX-O-001: indices present");
    assertEq(Array.isArray(md.indices[0]), true, "RX-O-001: indices entry is tuple");
} catch (e) {
    assert(false, "RX-O-001: d flag / indices unsupported: " + e);
}

// --- RX-O-002 v / unicodeSets (subset; host must support v flag — e.g. Node 20+, modern Bun) ---
if ("unicodeSets" in RegExp.prototype) {
    var rv = new RegExp("[a-z]", "v");
    assertEq(rv.test("m"), true, "RX-O-002: v set matches member");
    assertEq(rv.unicodeSets, true, "RX-O-002: unicodeSets on");
}

// --- RX-O-003 lookbehind (optional surface already in core engines) ---
assertEq(/(?<=x)y/.exec("xy")[0], "y", "RX-O-003: lookbehind match");

// --- RX-O-004 named capture in replacement ---
assertEq("axb".replace(/(?<n>a)x(?<m>b)/, "$<m>$<n>"), "ba", "RX-O-004: $<name> replacement");

// --- RX-ERR-006 deterministic rejection of unsupported syntax in this host ---
// `q` flag remains invalid across supported Node lines.
assertThrows(
    function () {
        new RegExp("a", "q");
    },
    SyntaxError,
    "RX-ERR-006: invalid flag rejected"
);

__jacDone();
