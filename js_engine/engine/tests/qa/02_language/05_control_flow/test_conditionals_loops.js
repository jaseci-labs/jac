// CONDITIONALS_COMPREHENSIVE_TEST_PLAN §5–6 — CND-W-*, CND-F-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_conditionals_loops.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- CND-W-001: while — zero iterations if condition initially falsy
(function () {
    var n = 0;
    var body = 0;
    while (n > 0) {
        body++;
        n--;
    }
    assertEq(body, 0, "CND-W-001: body not entered");
})();

// --- CND-W-002: do...while at least once
(function () {
    var c = 0;
    do { c++; } while (false);
    assertEq(c, 1, "CND-W-002: runs once on false");
})();

// --- CND-W-003: do while false + break idiom
(function () {
    var ran = 0;
    do {
        ran++;
        break;
    } while (false);
    assertEq(ran, 1, "CND-W-003: break after one iteration");
})();

// --- CND-W-004: break / continue in while
(function () {
    var i = 0;
    var sum = 0;
    while (i < 10) {
        i++;
        if (i === 5) break;
        sum += i;
    }
    assertEq(sum, 1 + 2 + 3 + 4, "CND-W-004: break");
    i = 0;
    var arr = [];
    while (i < 5) {
        i++;
        if (i % 2 === 0) continue;
        arr.push(i);
    }
    assertEq(arr.join(","), "1,3,5", "CND-W-004: continue");
})();

// --- CND-W-005: assignment as while condition (synthetic iterator)
(function () {
    var seq = [1, 2, 0, 3];
    var idx = 0;
    var acc = [];
    var cur;
    while ((cur = seq[idx++])) {
        acc.push(cur);
    }
    assertEq(acc.join(","), "1,2", "CND-W-005: while assigns until falsy");
})();

// --- CND-W-006: do...while with assignment condition
(function () {
    var list = [10, 20];
    var i = 0;
    var total = 0;
    var v;
    do {
        total += (v = list[i++]);
    } while (i < list.length && v);
    assertEq(total, 30, "CND-W-006: do-while assignment condition");
})();

// --- CND-F-001: for condition each iteration; falsy exits
(function () {
    var s = 0;
    for (var j = 1; j <= 3; j++) { s += j; }
    assertEq(s, 6, "CND-F-001: condition gates iterations");
})();

// --- CND-F-002: omitted condition is always true — break required
(function () {
    var k = 0;
    for (;; k++) {
        if (k === 3) break;
    }
    assertEq(k, 3, "CND-F-002: infinite for broken by break");
})();

// --- CND-F-003: for (;;) with break
(function () {
    var n = 0;
    for (;;) {
        n++;
        break;
    }
    assertEq(n, 1, "CND-F-003: for(;;) break");
})();

// --- CND-F-004: condition uses truthy iterator (linked list style)
(function () {
    var head = { v: 1, next: { v: 2, next: null } };
    var vals = [];
    for (var cur = head; cur; cur = cur.next) {
        vals.push(cur.v);
    }
    assertEq(vals.join(","), "1,2", "CND-F-004: for with truthy link walk");

    var emptyHead = null;
    var emptyVals = 0;
    for (var c2 = emptyHead; c2; c2 = c2.next) {
        emptyVals++;
    }
    assertEq(emptyVals, 0, "CND-F-004: null head — zero iterations");
})();

__jacDone();
