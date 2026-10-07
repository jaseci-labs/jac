// CONDITIONALS_COMPREHENSIVE_TEST_PLAN §4 — CND-S-FT-* (fall-through hardening)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_conditionals_switch_fallthrough.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- CND-S-FT-001: long fall-through chain (case 1 through case 4 then break)
(function () {
    var acc = [];
    switch (1) {
        case 1: acc.push(1);
        case 2: acc.push(2);
        case 3: acc.push(3);
        case 4: acc.push(4);
        break;
        case 5: acc.push(5);
    }
    assertEq(acc.join(","), "1,2,3,4", "CND-S-FT-001: four-deep fall-through chain");
})();

// --- CND-S-FT-002: no match falls into mid-list default, then into following case
(function () {
    var acc = [];
    switch (99) {
        case 1: acc.push("one"); break;
        default: acc.push("def");
        case 2: acc.push("two");
    }
    assertEq(acc.join(","), "def,two", "CND-S-FT-002: no-match into default then fall into case");
})();

// --- CND-S-FT-003: matched case falls into mid-list default and onward
(function () {
    var acc = [];
    switch (1) {
        case 1: acc.push("one");
        default: acc.push("def");
        case 2: acc.push("two");
    }
    assertEq(acc.join(","), "one,def,two", "CND-S-FT-003: matched case into default then next case");
})();

// --- CND-S-FT-004: default last, reached only by fall-through from matched case
(function () {
    var acc = [];
    switch (1) {
        case 1: acc.push("one");
        default: acc.push("def");
    }
    assertEq(acc.join(","), "one,def", "CND-S-FT-004: fall-through into trailing default");
})();

// --- CND-S-FT-005: no match, no default — no body runs
(function () {
    var acc = [];
    switch (42) {
        case 1: acc.push(1); break;
        case 2: acc.push(2);
    }
    assertEq(acc.length, 0, "CND-S-FT-005: no match and no default");
})();

// --- CND-S-FT-006: nested switch with inner and outer fall-through
(function () {
    var acc = [];
    switch (1) {
        case 1:
            switch (2) {
                case 2: acc.push("inner2");
                case 3: acc.push("inner3");
                break;
            }
            acc.push("outer1");
        case 2:
            acc.push("outer2");
            break;
    }
    assertEq(acc.join(","), "inner2,inner3,outer1,outer2", "CND-S-FT-006: nested switch fall-through");
})();

// --- CND-S-FT-007: switch(true) predicate chain with fall-through between cases
(function () {
    var n = 5;
    var acc = [];
    switch (true) {
        case n < 0: acc.push("neg"); break;
        case n < 10: acc.push("small");
        case n < 20: acc.push("med");
        default: acc.push("large");
    }
    assertEq(acc.join(","), "small,med,large", "CND-S-FT-007: switch(true) fall-through chain");
})();

// --- CND-S-FT-008: continue in switch targets loop; break exits switch only
(function () {
    var acc = [];
    for (var i = 0; i < 3; i++) {
        switch (i) {
            case 0: acc.push("a"); continue;
            case 1: acc.push("b"); break;
            case 2: acc.push("c");
        }
        acc.push("after-" + i);
    }
    assertEq(acc.join(","), "a,b,after-1,c,after-2", "CND-S-FT-008: continue vs break in loop+switch");
})();

__jacDone();
