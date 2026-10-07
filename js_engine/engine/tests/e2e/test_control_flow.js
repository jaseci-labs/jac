// Control flow tests — js_engine engine
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

// ── 1: if true branch ────────────────────────────────────────────────────
var r1 = 0;
if (true) { r1 = 1; } else { r1 = 2; }
check(1, "if true → 1", r1, 1);

// ── 2: if false branch ───────────────────────────────────────────────────
var r2 = 0;
if (false) { r2 = 1; } else { r2 = 2; }
check(2, "if false → else 2", r2, 2);

// ── 3: else-if chain ─────────────────────────────────────────────────────
var x = 5;
var r3 = "";
if (x > 10) { r3 = "big"; } else if (x > 3) { r3 = "mid"; } else { r3 = "small"; }
check(3, "else-if: 5 > 3 → 'mid'", r3, "mid");

// ── 4: ternary operator ───────────────────────────────────────────────────
var r4 = (10 > 5) ? "yes" : "no";
check(4, "ternary: 10>5 → 'yes'", r4, "yes");

// ── 5: while loop ────────────────────────────────────────────────────────
var i = 0;
var sum = 0;
while (i < 5) { sum = sum + i; i = i + 1; }
check(5, "while sum 0..4 === 10", sum, 10);

// ── 6: do-while executes at least once ───────────────────────────────────
var dw = 0;
do { dw = dw + 1; } while (false);
check(6, "do-while runs once === 1", dw, 1);

// ── 7: do-while loop ─────────────────────────────────────────────────────
var dw2 = 0;
var j = 0;
do { dw2 = dw2 + 1; j = j + 1; } while (j < 3);
check(7, "do-while 3 iterations === 3", dw2, 3);

// ── 8: for loop ───────────────────────────────────────────────────────────
var fsum = 0;
for (var fi = 1; fi <= 5; fi = fi + 1) { fsum = fsum + fi; }
check(8, "for sum 1..5 === 15", fsum, 15);

// ── 9: break in while ────────────────────────────────────────────────────
var cnt = 0;
var bi = 0;
while (bi < 10) {
    if (bi === 5) { break; }
    cnt = cnt + 1;
    bi = bi + 1;
}
check(9, "break at 5 → cnt === 5", cnt, 5);

// ── 10: continue in for ───────────────────────────────────────────────────
var skip = 0;
for (var ci = 0; ci < 10; ci = ci + 1) {
    if (ci % 2 === 0) { continue; }
    skip = skip + 1;
}
check(10, "continue skips evens → count odd === 5", skip, 5);

// ── 11: switch default ────────────────────────────────────────────────────
var sv = "z";
var sr = "";
switch (sv) {
    case "a": sr = "A"; break;
    case "b": sr = "B"; break;
    default: sr = "other";
}
check(11, "switch default → 'other'", sr, "other");

// ── 12: switch match ──────────────────────────────────────────────────────
var sv2 = "b";
var sr2 = "";
switch (sv2) {
    case "a": sr2 = "A"; break;
    case "b": sr2 = "B"; break;
    default: sr2 = "other";
}
check(12, "switch 'b' → 'B'", sr2, "B");

// ── 13: nested loops ─────────────────────────────────────────────────────
var npairs = 0;
for (var ni = 0; ni < 3; ni = ni + 1) {
    for (var nj = 0; nj < 3; nj = nj + 1) {
        npairs = npairs + 1;
    }
}
check(13, "nested 3x3 loops === 9", npairs, 9);

// ── 14: break in nested loop ─────────────────────────────────────────────
var nbcnt = 0;
for (var nbi = 0; nbi < 5; nbi = nbi + 1) {
    for (var nbj = 0; nbj < 5; nbj = nbj + 1) {
        if (nbj === 2) { break; }
        nbcnt = nbcnt + 1;
    }
}
check(14, "break inner at 2 → 5*2 === 10", nbcnt, 10);

// ── 15: logical AND short-circuit ─────────────────────────────────────────
var and_result = false && (1/0 > 0);
check(15, "false && ... short-circuits → false", and_result, false);

// ── 16: logical OR short-circuit ─────────────────────────────────────────
var or_result = true || false;
check(16, "true || false → true", or_result, true);

// ── 17: compound comparison ───────────────────────────────────────────────
var cv = 7;
check(17, "5 < 7 && 7 < 10 === true", cv > 5 && cv < 10, true);

// ── 18: strict equality ───────────────────────────────────────────────────
check(18, "1 === 1 → true", 1 === 1, true);

// ── 19: strict inequality ─────────────────────────────────────────────────
check(19, "1 !== 2 → true", 1 !== 2, true);

// ── 20: null checks ──────────────────────────────────────────────────────
var maybe = null;
var r20 = "";
if (maybe === null) { r20 = "null"; } else { r20 = "not null"; }
check(20, "null === null → 'null'", r20, "null");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Control-flow tests: " + _passed + " passed, " + _failed + " failed ===");
