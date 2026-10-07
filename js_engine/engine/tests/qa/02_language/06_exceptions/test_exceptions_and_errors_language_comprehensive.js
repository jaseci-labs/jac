// EXCEPTIONS_AND_ERRORS_LANGUAGE_COMPREHENSIVE_TEST_PLAN.md — full EXC-* coverage
// (try/catch/finally, throw, Error surface, subclasses, stack, propagation)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/06_exceptions/test_exceptions_and_errors_language_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §1 try / catch (EXC-T-*) ---

// EXC-T-001: throw in try → catch; binding is thrown value verbatim
(function excT001() {
    var saw = false;
    try {
        throw 42;
    } catch (e) {
        saw = true;
        assertEq(e, 42, "EXC-T-001: catch receives thrown primitive verbatim");
    }
    assert(saw, "EXC-T-001: catch block ran");
})();

// EXC-T-002: catch binding shadows outer var; no leak after catch
(function excT002() {
    var x = "outer";
    try {
        throw 1;
    } catch (x) {
        assertEq(x, 1, "EXC-T-002: catch param shadows outer var inside catch");
    }
    assertEq(x, "outer", "EXC-T-002: catch binding does not leak outer var");
})();

// EXC-T-003: optional catch binding (ES2019)
(function excT003() {
    var ran = false;
    try {
        throw "any";
    } catch {
        ran = true;
    }
    assert(ran, "EXC-T-003: optional catch runs without binding");
})();

// EXC-T-004: nested try/catch — inner handles inner; outer catches throw from inner catch
(function excT004() {
    var inner = false;
    var outer = false;
    try {
        try {
            throw new Error("inner");
        } catch (ei) {
            inner = true;
            assertEq(ei.message, "inner", "EXC-T-004: inner catch sees inner error");
            throw new Error("outer");
        }
    } catch (eo) {
        outer = true;
        assertEq(eo.message, "outer", "EXC-T-004: outer catch sees error from inner catch");
    }
    assert(inner, "EXC-T-004: inner catch ran");
    assert(outer, "EXC-T-004: outer catch ran");
})();

// EXC-T-005: no catch guard in JS — single catch + instanceof guard
(function excT005() {
    var out = "";
    try {
        throw new TypeError("t");
    } catch (e) {
        if (e instanceof TypeError) {
            out = "type";
        } else {
            out = "other";
        }
    }
    assertEq(out, "type", "EXC-T-005: instanceof guard inside catch mimics conditional catch");
})();

// EXC-T-006: no throw — catch skipped; execution continues
(function excT006() {
    var after = false;
    var caught = false;
    try {
        after = true;
    } catch (e) {
        caught = true;
    }
    assert(after, "EXC-T-006: try body ran");
    assert(!caught, "EXC-T-006: catch skipped when no throw");
})();

// EXC-T-007: catch param vs inner let — TDZ on RHS (ReferenceError)
(function excT007() {
    function f() {
        try {
            throw 1;
        } catch (e) {
            {
                let e = e + 1;
                return e;
            }
        }
    }
    assertThrows(f, ReferenceError, "EXC-T-007: inner let shadows catch param; RHS is TDZ");
})();

// --- §2 finally (EXC-F-*) ---

// EXC-F-001: finally runs when try completes without throw
(function excF001() {
    var fin = false;
    try {
        var x = 1;
        assertEq(x, 1, "EXC-F-001: try completes normally");
    } finally {
        fin = true;
    }
    assert(fin, "EXC-F-001: finally runs after normal try completion");
})();

// EXC-F-002: finally runs after catch when try threw
(function excF002() {
    var c = false;
    var f = false;
    try {
        throw new Error("f2");
    } catch (e) {
        c = true;
    } finally {
        f = true;
    }
    assert(c, "EXC-F-002: catch ran");
    assert(f, "EXC-F-002: finally ran after catch");
})();

// EXC-F-003: return from try; finally return overrides
(function excF003() {
    function g() {
        try {
            return 1;
        } finally {
            return 2;
        }
    }
    assertEq(g(), 2, "EXC-F-003: finally return overrides try return");
    function h() {
        try {
            throw new Error("x");
        } catch (e) {
            return 3;
        } finally {
            return 4;
        }
    }
    assertEq(h(), 4, "EXC-F-003: finally return overrides catch return");
})();

// EXC-F-004: throw from finally suppresses pending try/catch completion
(function excF004() {
    function fromTry() {
        try {
            return "try";
        } finally {
            throw new Error("fin");
        }
    }
    assertThrows(
        fromTry,
        Error,
        "EXC-F-004: throw from finally suppresses try return"
    );
    try {
        fromTry();
    } catch (e) {
        assertEq(e.message, "fin", "EXC-F-004: outer sees finally throw");
    }
    function fromCatch() {
        try {
            throw new Error("tryerr");
        } catch (e) {
            return "caught";
        } finally {
            throw new Error("fin2");
        }
    }
    try {
        fromCatch();
    } catch (e2) {
        assertEq(e2.message, "fin2", "EXC-F-004: finally throw suppresses catch return");
    }
})();

// EXC-F-005: break / continue — finally still runs
(function excF005() {
    var fin = 0;
    outer: for (var i = 0; i < 5; i++) {
        try {
            if (i === 1) {
                break outer;
            }
        } finally {
            fin++;
        }
    }
    assertEq(fin, 2, "EXC-F-005: finally runs on labeled break out of try");
    var acc = 0;
    for (var j = 0; j < 3; j++) {
        try {
            if (j === 1) {
                continue;
            }
            acc++;
        } finally {
            acc += 10;
        }
    }
    assertEq(acc, 32, "EXC-F-005: finally runs on continue from try");
})();

// --- §3 throw (EXC-H-*) ---

// EXC-H-001: throw Error, string, number, object — caught verbatim
(function excH001() {
    function catchVal(v) {
        try {
            throw v;
        } catch (e) {
            return e;
        }
    }
    assert(catchVal(new Error("e")) instanceof Error, "EXC-H-001: throw Error");
    assertEq(catchVal("s"), "s", "EXC-H-001: throw string");
    assertEq(catchVal(7), 7, "EXC-H-001: throw number");
    assertEq(catchVal({ k: 2 }).k, 2, "EXC-H-001: throw object");
})();

// EXC-H-002: throw without expression — SyntaxError via dynamic compile
(function excH002() {
    assertThrows(
        function () {
            new Function("throw");
        },
        SyntaxError,
        "EXC-H-002: bare throw in Function body is syntax error"
    );
    var ok = new Function("throw 1");
    assert(typeof ok === "function", "EXC-H-002: throw with expression parses to function");
    var threw = false;
    try {
        ok();
    } catch (ev) {
        threw = true;
        assertEq(ev, 1, "EXC-H-002: dynamic throw 1 is caught value");
    }
    assert(threw, "EXC-H-002: body runs throw");
})();

// EXC-H-003: throw in catch caught by outer try
(function excH003() {
    var depth = 0;
    try {
        try {
            throw new Error("inner");
        } catch (e) {
            depth = 1;
            throw new Error("rethrow");
        }
    } catch (e2) {
        depth = 2;
        assertEq(e2.message, "rethrow", "EXC-H-003: outer catch sees throw from inner catch");
    }
    assertEq(depth, 2, "EXC-H-003: outer catch ran");
})();

// --- §4 Error constructor (EXC-E-*) ---

// EXC-E-001
(function excE001() {
    var err = new Error("msg");
    assertEq(err.message, "msg", "EXC-E-001: Error message");
    assertEq(err.name, "Error", "EXC-E-001: Error name");
    assert(err instanceof Error, "EXC-E-001: instanceof Error");
})();

// EXC-E-002: Error() without new
(function excE002() {
    var e = Error("no new");
    assertEq(e.message, "no new", "EXC-E-002: Error() message");
    assert(e instanceof Error, "EXC-E-002: Error() instanceof Error");
})();

// EXC-E-003: .stack string or undefined; non-empty when string after nested throw
(function excE003() {
    var plain = new Error("p");
    assert(
        typeof plain.stack === "string" || plain.stack === undefined,
        "EXC-E-003: stack is string or undefined on fresh Error"
    );
    function inner() {
        throw new Error("deep");
    }
    function outer() {
        inner();
    }
    var st = null;
    try {
        outer();
    } catch (ex) {
        st = ex;
    }
    assert(st !== null, "EXC-E-003: error thrown");
    if (typeof st.stack === "string") {
        assert(st.stack.length > 0, "EXC-E-003: stack string non-empty when present");
    }
})();

// EXC-E-004: Error cause (ES2022) — optional if engine lacks support
(function excE004() {
    var inner = new Error("cause-inner");
    var outer = new Error("cause-outer", { cause: inner });
    if (outer.cause !== inner) {
        return;
    }
    assertEq(outer.message, "cause-outer", "EXC-E-004: message with cause option");
    assertEq(outer.cause, inner, "EXC-E-004: new Error cause preserved");
    var bare = Error("bare", { cause: 99 });
    if (bare.cause === 99) {
        assertEq(bare.cause, 99, "EXC-E-004: Error() without new preserves cause");
    }
})();

// EXC-E-005: arbitrary own properties on Error instances
(function excE005() {
    var e = new Error("x");
    e.code = "E_TEST";
    e.detail = { n: 1 };
    assertEq(e.code, "E_TEST", "EXC-E-005: custom .code");
    assertEq(e.detail.n, 1, "EXC-E-005: custom object property");
})();

// EXC-E-006: Error.prototype.toString pattern
(function excE006() {
    assertEq(new Error("a").toString(), "Error: a", "EXC-E-006: toString with message");
    assertEq(new Error().toString(), "Error", "EXC-E-006: toString empty message");
})();

// --- §5 Built-in Error subclasses (EXC-S-*) ---

// EXC-S-001 TypeError
(function excS001() {
    var t = new TypeError("t");
    assertEq(t.name, "TypeError", "EXC-S-001: TypeError name");
    assert(t instanceof TypeError, "EXC-S-001: instanceof TypeError");
    assert(t instanceof Error, "EXC-S-001: instanceof Error");
})();

// EXC-S-002 ReferenceError
(function excS002() {
    var r = new ReferenceError("r");
    assertEq(r.name, "ReferenceError", "EXC-S-002: ReferenceError name");
    assert(r instanceof ReferenceError, "EXC-S-002: instanceof ReferenceError");
})();

// EXC-S-003 SyntaxError
(function excS003() {
    var s = new SyntaxError("s");
    assertEq(s.name, "SyntaxError", "EXC-S-003: SyntaxError name");
    assert(s instanceof SyntaxError, "EXC-S-003: instanceof SyntaxError");
})();

// EXC-S-004 RangeError
(function excS004() {
    var r = new RangeError("r");
    assertEq(r.name, "RangeError", "EXC-S-004: RangeError name");
    assert(r instanceof RangeError, "EXC-S-004: instanceof RangeError");
})();

// EXC-S-005 EvalError / URIError when present
(function excS005() {
    if (typeof EvalError === "function") {
        var ev = new EvalError("e");
        assertEq(ev.name, "EvalError", "EXC-S-005: EvalError name");
        assertEq(ev.toString().indexOf("EvalError"), 0, "EXC-S-005: EvalError toString prefix");
    }
    if (typeof URIError === "function") {
        var u = new URIError("u");
        assertEq(u.name, "URIError", "EXC-S-005: URIError name");
    }
})();

// EXC-S-006 AggregateError — constructor surface (Promise.any covered elsewhere)
(function excS006() {
    if (typeof AggregateError !== "function") {
        return;
    }
    var a = new Error("a");
    var b = new Error("b");
    var agg = new AggregateError([a, b], "both failed");
    assertEq(agg.message, "both failed", "EXC-S-006: AggregateError message");
    assert(Array.isArray(agg.errors), "EXC-S-006: errors is array");
    assertEq(agg.errors.length, 2, "EXC-S-006: errors length");
    assertEq(agg.errors[0], a, "EXC-S-006: first error preserved");
    assert(agg instanceof Error, "EXC-S-006: instanceof Error");
})();

// --- §6 Stack traces (EXC-K-*) ---

// EXC-K-001: nested named functions — stack string mentions names or is non-empty
(function excK001() {
    function outerName() {
        return innerName();
    }
    function innerName() {
        throw new Error("k1");
    }
    var err = null;
    try {
        outerName();
    } catch (e) {
        err = e;
    }
    assert(err !== null, "EXC-K-001: thrown");
    if (typeof err.stack === "string") {
        assert(err.stack.length > 0, "EXC-K-001: stack non-empty when string");
    }
})();

// EXC-K-002: thrown primitive — no .stack on caught value
(function excK002() {
    var ex = null;
    try {
        throw "primitive";
    } catch (e) {
        ex = e;
    }
    assertEq(typeof ex, "string", "EXC-K-002: caught primitive");
    assertEq(ex.stack, undefined, "EXC-K-002: primitive has no stack");
})();

// EXC-K-003: stack own vs inherited — neutral; only require readable .stack
(function excK003() {
    var e = new Error("k3");
    var s = e.stack;
    assert(
        s === undefined || typeof s === "string",
        "EXC-K-003: .stack is undefined or string (implementation-defined)"
    );
})();

// --- §7 Propagation / typing in catch (EXC-P-*) ---

// EXC-P-001: propagation through stack until caught
(function excP001() {
    function c() {
        throw new RangeError("deep");
    }
    function b() {
        c();
    }
    function a() {
        b();
    }
    var got = false;
    try {
        a();
    } catch (e) {
        got = true;
        assert(e instanceof RangeError, "EXC-P-001: propagated instanceof RangeError");
        assertEq(e.message, "deep", "EXC-P-001: message preserved");
    }
    assert(got, "EXC-P-001: caller catch reached");
})();

// EXC-P-002: instanceof TypeError vs RangeError in catch
(function excP002() {
    function pick(fn) {
        try {
            fn();
        } catch (e) {
            if (e instanceof TypeError) {
                return "T";
            }
            if (e instanceof RangeError) {
                return "R";
            }
            return "?";
        }
        return "none";
    }
    assertEq(
        pick(function () {
            throw new TypeError("x");
        }),
        "T",
        "EXC-P-002: instanceof TypeError in catch"
    );
    assertEq(
        pick(function () {
            throw new RangeError("y");
        }),
        "R",
        "EXC-P-002: instanceof RangeError in catch"
    );
})();

// EXC-P-003: constructor / Object.prototype.toString for builtins (neutral)
(function excP003() {
    var te = new TypeError("p3");
    assertEq(te.constructor, TypeError, "EXC-P-003: TypeError constructor");
    assertEq(
        Object.prototype.toString.call(te),
        "[object Error]",
        "EXC-P-003: Object.prototype.toString for TypeError"
    );
})();

__jacDone();
