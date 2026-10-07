// LOOPS_AND_CONTROL_FLOW_COMPREHENSIVE_TEST_PLAN.md — LCF-* (aliases CND-*, CF-* where noted)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_loops_control_flow.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, Ctor, id, detail) {
    try {
        fn();
        console.error("FAIL: " + id + ": expected " + Ctor.name + " — " + detail);
        __reg.bump(); return;
    } catch (e) {
        if (!(e instanceof Ctor)) {
            console.error("FAIL: " + id + ": wrong error | expected " + Ctor.name + " | got " + e);
            __reg.bump(); return;
        }
    }
}

// ═══ §1 while (LCF-W-*) ═══

(function lcf_w001() {
    var body = 0;
    var n = 0;
    while (n > 0) {
        body++;
        n--;
    }
    assertEq(body, 0, "LCF-W-001: falsy initial condition — zero iterations (alias CND-W-001)");
})();

(function lcf_w002() {
    var n = 0;
    while (n < 3) {
        n++;
    }
    assertEq(n, 3, "LCF-W-002: truthy condition until falsy");
})();

(function lcf_w003() {
    var seq = [1, 2, 0, 3];
    var idx = 0;
    var acc = [];
    var cur;
    while ((cur = seq[idx++])) {
        acc.push(cur);
    }
    assertEq(acc.join(","), "1,2", "LCF-W-003: assignment as while condition (alias CND-W-005)");
})();

(function lcf_w004() {
    var x = 0;
    while (x < 2) x++;
    assertEq(x, 2, "LCF-W-004: single-statement while body");
    var y = 0;
    while (y < 2) {
        y++;
    }
    assertEq(y, 2, "LCF-W-004: block while body");
})();

(function lcf_w005() {
    var steps = 0;
    var i = 2;
    while (i--) steps++;
    assertEq(steps, 2, "LCF-W-005: empty while body — condition drives exit");
})();

// ═══ §2 do…while (LCF-D-*) ═══

(function lcf_d001() {
    var c = 0;
    do {
        c++;
    } while (false);
    assertEq(c, 1, "LCF-D-001: body at least once when condition falsy (alias CND-W-002)");
})();

(function lcf_d002() {
    var ran = 0;
    do {
        ran++;
        break;
    } while (false);
    assertEq(ran, 1, "LCF-D-002: do { break } while (false) one iteration (alias CND-W-003)");
})();

(function lcf_d003() {
    var list = [10, 20];
    var i = 0;
    var total = 0;
    var v;
    do {
        total += (v = list[i++]);
    } while (i < list.length && v);
    assertEq(total, 30, "LCF-D-003: assignment in do…while condition (alias CND-W-006)");
})();

// ═══ §3 for (classic) (LCF-F-*) ═══

(function lcf_f001() {
    var s = 0;
    for (var j = 1; j <= 3; j++) {
        s += j;
    }
    assertEq(s, 6, "LCF-F-001: init once, condition each time, increment after body (alias CND-F-001)");
})();

(function lcf_f002() {
    var k = 0;
    for (;; k++) {
        if (k === 3) {
            break;
        }
    }
    assertEq(k, 3, "LCF-F-002: omitted condition always true — exit via break (alias CND-F-002)");
})();

(function lcf_f003() {
    var fe = 0;
    for (; fe < 3; ) {
        fe++;
    }
    assertEq(fe, 3, "LCF-F-003: omitted init and increment (alias CF-010 partial)");
})();

(function lcf_f004() {
    var head = { v: 1, next: { v: 2, next: null } };
    var vals = [];
    for (var cur = head; cur; cur = cur.next) {
        vals.push(cur.v);
    }
    assertEq(vals.join(","), "1,2", "LCF-F-004: truth-walking for condition (alias CND-F-004)");
})();

(function lcf_f005() {
    (function () {
        for (var hv = 0; hv < 1; hv++) {}
        assertEq(typeof hv, "number", "LCF-F-005: var in for init visible in function scope after loop");
    })();
    (function () {
        for (let hl = 0; hl < 1; hl++) {}
        var refErr = false;
        try {
            void hl;
        } catch (e) {
            refErr = e instanceof ReferenceError;
        }
        assert(refErr, "LCF-F-005: let for-head binding not visible after loop (block scope)");
    })();
})();

(function lcf_f006() {
    var log = "";
    for (var a = (log += "i"), b = 0; b < 2; log += "u", b++) {}
    assertEq(log, "iuu", "LCF-F-006: comma in init once, then comma increment each iteration");
})();

(function lcf_f007() {
    var pairs = [];
    for (var r = 0; r < 2; r++) {
        for (var cc = 0; cc < 2; cc++) {
            pairs.push(r * 10 + cc);
        }
    }
    assertEq(pairs.join(","), "0,1,10,11", "LCF-F-007: nested for inner completes per outer (alias CF-010 nested)");
})();

(function lcf_f008() {
    var sum = 0;
    for (var i = 0, arr = [1, 2, 3]; i < arr.length; i++) {
        sum += arr[i];
    }
    assertEq(sum, 6, "LCF-F-008: for init with array pattern (not destructuring deep test)");
})();

// ═══ §4 break / continue unlabeled (LCF-J-*) ═══

(function lcf_j001() {
    var swHit = 0;
    switch (1) {
        case 1:
            swHit = 1;
            break;
        default:
            swHit = 9;
    }
    assertEq(swHit, 1, "LCF-J-001: break exits innermost switch");
    var w = 0;
    while (w < 5) {
        w++;
        if (w === 2) {
            break;
        }
    }
    assertEq(w, 2, "LCF-J-001: break exits innermost while");
})();

(function lcf_j002() {
    var out = [];
    for (var i = 0; i < 4; i++) {
        if (i === 2) {
            continue;
        }
        out.push(i);
    }
    assertEq(out.join(","), "0,1,3", "LCF-J-002: continue skips to next for iteration");
})();

(function lcf_j003() {
    var wi = 0;
    var wlog = "";
    while (wi < 3) {
        wi++;
        if (wi === 2) {
            continue;
        }
        wlog += wi;
    }
    assertEq(wlog, "13", "LCF-J-003: continue in while");

    var di = 0;
    var dlog = "";
    do {
        di++;
        if (di === 2) {
            continue;
        }
        dlog += di;
    } while (di < 3);
    assertEq(dlog, "13", "LCF-J-003: continue in do…while");

    var flog = "";
    for (var fi = 0; fi < 3; fi++) {
        if (fi === 1) {
            continue;
        }
        flog += fi;
    }
    assertEq(flog, "02", "LCF-J-003: continue in for — increment still runs");

    var inKeys = "";
    var o = { a: 1, b: 2 };
    for (var k in o) {
        if (k === "a") {
            continue;
        }
        inKeys += k;
    }
    assertEq(inKeys, "b", "LCF-J-003: continue in for…in");

    var ofLog = "";
    var arr = [1, 2, 3];
    for (var v of arr) {
        if (v === 2) {
            continue;
        }
        ofLog += v;
    }
    assertEq(ofLog, "13", "LCF-J-003: continue in for…of");
})();

(function lcf_j004() {
    var nestedBreak = 0;
    for (var ni = 0; ni < 3; ni++) {
        for (var nj = 0; nj < 3; nj++) {
            if (nj === 1) {
                break;
            }
            nestedBreak++;
        }
    }
    assertEq(nestedBreak, 3, "LCF-J-004: nested break inner loop only (alias CF-016)");
    var nestedCont = "";
    for (var ci = 0; ci < 2; ci++) {
        for (var cj = 0; cj < 2; cj++) {
            if (cj === 0) {
                continue;
            }
            nestedCont += ci + "" + cj;
        }
    }
    assertEq(nestedCont, "0111", "LCF-J-004: nested continue inner only");
})();

assertThrows(
    function () {
        new Function("break;");
    },
    SyntaxError,
    "LCF-J-005",
    "illegal break outside loop/switch"
);
assertThrows(
    function () {
        new Function("continue;");
    },
    SyntaxError,
    "LCF-J-006",
    "illegal continue outside loop"
);

(function lcf_j007() {
    var count = 0;
    for (var i = 0; i < 3; i++) {
        switch (i) {
            case 0:
                continue;
            default:
                count++;
        }
    }
    assertEq(count, 2, "LCF-J-007: continue in switch applies to enclosing loop (not switch cases)");
})();

// ═══ §5 Labels (LCF-L-*) ═══

(function lcf_l001() {
    var ok = false;
    quiet: ok = true;
    assert(ok, "LCF-L-001: label before statement without break is valid");
})();

(function lcf_l002() {
    var li = 0;
    var lj = 0;
    outer: for (li = 0; li < 3; li++) {
        for (lj = 0; lj < 3; lj++) {
            if (li === 1 && lj === 1) {
                break outer;
            }
        }
    }
    assertEq(li, 1, "LCF-L-002: labeled break exits named outer loop (alias CF-017)");
})();

(function lcf_l003() {
    var contResult = [];
    outerCont: for (var oi = 0; oi < 3; oi++) {
        for (var oj = 0; oj < 3; oj++) {
            if (oj === 1) {
                continue outerCont;
            }
            contResult.push(oi + "," + oj);
        }
    }
    assertEq(contResult.length, 3, "LCF-L-003: labeled continue targets iteration statement (alias CF-017)");
})();

assertThrows(
    function () {
        new Function("a: { continue a; }");
    },
    SyntaxError,
    "LCF-L-004",
    "continue to non-iteration label"
);

assertThrows(
    function () {
        new Function("break unknown;");
    },
    SyntaxError,
    "LCF-L-005",
    "break unknown label"
);
assertThrows(
    function () {
        new Function("continue unknown;");
    },
    SyntaxError,
    "LCF-L-005",
    "continue unknown label"
);

assertThrows(
    function () {
        new Function("a: while(0){ a: while(0){} }");
    },
    SyntaxError,
    "LCF-L-006",
    "duplicate label in same label set"
);

(function lcf_l007() {
    var x = 0;
    foo: {
        break foo;
        x = 1;
    }
    assertEq(x, 0, "LCF-L-007: labeled block — break exits block");
})();

(function lcf_l008() {
    var hit = 0;
    outer: while (hit < 5) {
        switch (1) {
            case 1:
                hit++;
                break outer;
        }
    }
    assertEq(hit, 1, "LCF-L-008: break label on loop exits from switch inside loop");
    var swDone = false;
    sw: switch (1) {
        case 1:
            swDone = true;
            break sw;
        default:
            swDone = false;
    }
    assert(swDone, "LCF-L-008: break label on switch exits switch");
})();

// ═══ §6 for…in (LCF-I-*) ═══

(function lcf_i001() {
    function Par() {}
    Par.prototype.inherited = 1;
    var o = new Par();
    o.own = 2;
    var keys = {};
    for (var k in o) {
        keys[k] = true;
    }
    assert(keys.own && keys.inherited, "LCF-I-001: for…in own and inherited enumerable string keys");
})();

(function lcf_i002() {
    var neObj = {};
    Object.defineProperty(neObj, "hidden", { value: 1, enumerable: false, configurable: true });
    neObj.visible = 2;
    var ks = [];
    for (var nk in neObj) {
        ks.push(nk);
    }
    assertEq(ks.join(","), "visible", "LCF-I-002: skips non-enumerable own (alias CF-011)");
})();

(function lcf_i003() {
    var o = { a: 1, b: 2, c: 3 };
    var out = "";
    outerIn: for (var kk in o) {
        if (kk === "b") {
            break outerIn;
        }
        out += kk;
    }
    assertEq(out, "a", "LCF-I-003: labeled break in for…in");
    var out2 = "";
    for (var k2 in o) {
        if (k2 === "a") {
            continue;
        }
        out2 += k2;
    }
    assertEq(out2, "bc", "LCF-I-003: continue in for…in");
})();

(function lcf_i004() {
    var rhsCalls = 0;
    function rhs() {
        rhsCalls++;
        return { x: 1 };
    }
    var c = 0;
    for (var p in rhs()) {
        c++;
    }
    assertEq(rhsCalls, 1, "LCF-I-004: for…in RHS evaluated once");
    var nIter = 0;
    for (var q in null) {
        nIter++;
    }
    for (var r in undefined) {
        nIter++;
    }
    assertEq(nIter, 0, "LCF-I-004: nullish RHS — Node yields zero iterations (no throw)");
})();

(function lcf_i005() {
    var a = ["x", "y"];
    var keys = [];
    for (var k in a) {
        keys.push(k);
    }
    assert(keys.indexOf("0") >= 0 && keys.indexOf("1") >= 0, "LCF-I-005: array indices enumerable in for…in");
    assertEq(keys.indexOf("length") >= 0, false, "LCF-I-005: non-enumerable length not in for…in (typical)");
})();

(function lcf_i006() {
    var o = {};
    o.z = 1;
    o.a = 2;
    o.m = 3;
    var k1 = Object.keys(o);
    var k2 = [];
    for (var kk in o) {
        k2.push(kk);
    }
    assertEq(k1.join(","), k2.join(","), "LCF-I-006: for…in key order matches Object.keys (Node baseline)");
})();

// ═══ §7 Optional / deferred (LCF-O-*) ═══

assert(
    true,
    "LCF-O-001: for…of protocol — see test_control_flow.js CF-012 and iteration plan (optional)"
);
assert(
    true,
    "LCF-O-002: for await…of — see test_for_await.js and async plan (optional)"
);
assert(
    true,
    "LCF-O-003: break/continue with finally — deferred to exceptions plan (optional)"
);

__jacDone();
