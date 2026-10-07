// OPERATORS_AND_EXPRESSIONS_COMPREHENSIVE_TEST_PLAN.md — OPE-* scenario coverage
// (unary through instanceof, precedence; excludes items explicitly out of scope in the plan)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_operators_expressions.js");
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
            console.error(
                "FAIL: " +
                    id +
                    ": wrong error type | expected " +
                    Ctor.name +
                    " | got " +
                    e
            );
            __reg.bump(); return;
        }
    }
}

// --- §1 Unary arithmetic and numeric coercion (OPE-U-*) ---

// OPE-U-001: unary + coerces to number
assertEq(+"42", 42, "OPE-U-001: unary + string numeric");
assertEq(+true, 1, "OPE-U-001: unary + true");
assertEq(+null, 0, "OPE-U-001: unary + null");
assertEq(
    +{ valueOf: function () { return 7; } },
    7,
    "OPE-U-001: unary + object via ToPrimitive"
);

// OPE-U-002: unary - after ToNumber; -0 and NaN
assertEq(1 / -0, -Infinity, "OPE-U-002: -0 via unary - on +0");
assert(isNaN(+"x"), "OPE-U-002: unary + non-numeric string is NaN");
assert(isNaN(-NaN), "OPE-U-002: -NaN is NaN");

// OPE-U-003: prefix/postfix on binding and member (distinct from OP-005 messages)
(function ope_u003_binding() {
    var v = 1;
    assertEq(++v, 2, "OPE-U-003: prefix ++ returns new value");
    assertEq(v, 2, "OPE-U-003: prefix ++ updates binding");
    assertEq(v++, 2, "OPE-U-003: postfix ++ returns old value");
    assertEq(v, 3, "OPE-U-003: postfix ++ updates binding");
    var o = { p: 10 };
    assertEq(o.p++, 10, "OPE-U-003: postfix ++ on member returns old");
    assertEq(o.p, 11, "OPE-U-003: postfix ++ updates member");
})();

// OPE-U-004: strict mode increment non-writable data property → TypeError
(function ope_u004() {
    "use strict";
    var o = {};
    Object.defineProperty(o, "x", { value: 1, writable: false, configurable: true });
    assertThrows(
        function () {
            o.x++;
        },
        TypeError,
        "OPE-U-004",
        "strict ++ on non-writable data property"
    );
    var o2 = {};
    Object.defineProperty(o2, "y", {
        get: function () {
            return 1;
        },
        configurable: true
    });
    assertThrows(
        function () {
            o2.y++;
        },
        TypeError,
        "OPE-U-004",
        "strict ++ on accessor without setter"
    );
})();

// OPE-U-005: ++ on const binding → TypeError at runtime (Node)
(function ope_u005() {
    "use strict";
    var err = false;
    try {
        eval("'use strict'; const c = 1; c++;");
    } catch (e) {
        err = e instanceof TypeError;
    }
    assert(err, "OPE-U-005: ++ on const throws TypeError");

    var err2 = false;
    try {
        eval("'use strict'; const d = 1; d--;");
    } catch (e) {
        err2 = e instanceof TypeError;
    }
    assert(err2, "OPE-U-005: -- on const throws TypeError");
})();

// --- §2 Additive, multiplicative, remainder, exponentiation (OPE-A-*) ---

assertEq(2.5 * 4, 10, "OPE-A-001: fractional multiplication");
assertEq(7 - 2.5, 4.5, "OPE-A-001: fractional subtraction");

assertEq("5" + 3, "53", "OPE-A-002: string + number concatenates");
assertEq(3 + "5", "35", "OPE-A-002: number + string concatenates");

assertEq(1 / -0, -Infinity, "OPE-A-003: positive / -0 → -Infinity");
assertEq(-1 / 0, -Infinity, "OPE-A-003: negative / +0 → -Infinity");

assert(isNaN(Infinity % 1), "OPE-A-004: Infinity % 1 is NaN");
assertEq(-7 % 4, -3, "OPE-A-004: remainder sign follows dividend");

assertEq(0 ** 0, 1, "OPE-A-005: 0**0 === 1");
assertEq(2 ** 10, 1024, "OPE-A-005: 2**10");
assertEq(2 ** -1, 0.5, "OPE-A-005: 2**-1");
assert(isNaN((-2) ** 0.5), "OPE-A-005: negative base, non-integer exponent → NaN");

assertThrows(
    function () {
        return 1 + 1n;
    },
    TypeError,
    "OPE-A-006",
    "Number + BigInt without conversion"
);

// --- §3 Bitwise (OPE-B-*) ---

assertEq(6 & 3, 2, "OPE-B-001: & on small integers");
assertEq(6 | 3, 7, "OPE-B-001: |");
assertEq(6 ^ 3, 5, "OPE-B-001: ^");
assertEq(~0, -1, "OPE-B-001: ~0 === -1");
assertEq(~5, -6, "OPE-B-001: ~5 === -6");

assertEq((1 << 31) | 0, -2147483648, "OPE-B-002: large pattern fits 32-bit int model");

assertEq(3.9 & 0xff, 3, "OPE-B-003: non-integer truncated toward zero before bitwise");

assertEq(-1 >> 0, -1, "OPE-B-004: >> sign-propagating");
assertEq(-1 >>> 0, 0xffffffff, "OPE-B-004: -1 >>> 0 === 0xFFFFFFFF");

assertEq(1 << 32, 1, "OPE-B-005: shift count masked mod 32 (1 << 32 === 1 << 0)");

assertThrows(
    function () {
        return 1 & 1n;
    },
    TypeError,
    "OPE-B-006",
    "Number & BigInt without conversion"
);

// --- §4 Logical NOT, AND, OR (OPE-L-*) ---

assertEq(!0, true, "OPE-L-001: ! after ToBoolean");
assertEq(!!"hi", true, "OPE-L-001: !! idiom");

var l2 = 0;
assertEq(0 && (l2 = 1), 0, "OPE-L-002: && returns left when falsy");
assertEq(l2, 0, "OPE-L-002: && skips RHS when left falsy");
var l2b = 0;
assertEq(1 && (l2b = 2), 2, "OPE-L-002: && evaluates RHS when left truthy");
assertEq(l2b, 2, "OPE-L-002: && RHS ran");

var l3 = 0;
assertEq(1 || (l3 = 1), 1, "OPE-L-003: || returns left when truthy");
assertEq(l3, 0, "OPE-L-003: || skips RHS when left truthy");
assertEq(0 || 2, 2, "OPE-L-003: || returns right when left falsy");

assertEq(1 && 2 && 3, 3, "OPE-L-004: && chain to last truthy");
assertEq(0 && 2 && 3, 0, "OPE-L-004: && chain short-circuit at first falsy");
assertEq(0 || false || "last", "last", "OPE-L-004: || chain to last falsy then value");

assertEq(0 && "x", 0, "OPE-L-005: 0 && string → 0");
assertEq("" || "default", "default", "OPE-L-005: '' || string → default");

assertEq(new Boolean(false) && "y", "y", "OPE-L-006: boxed Boolean false is truthy in &&");

// --- §5 Nullish coalescing (OPE-N-*) ---

assert(isNaN(NaN ?? "n"), "OPE-N-001: NaN is not nullish, LHS kept (still NaN)");
var nSide = 0;
assertEq("ok" ?? (nSide++, "bad"), "ok", "OPE-N-002: RHS not evaluated when LHS not nullish");
assertEq(nSide, 0, "OPE-N-002: side effect counter unchanged");

(function ope_n003() {
    var a = null;
    a ??= 5;
    assertEq(a, 5, "OPE-N-003: ??= assigns when null");
    var b = undefined;
    b ??= 6;
    assertEq(b, 6, "OPE-N-003: ??= assigns when undefined");
    var c = 0;
    c ??= 99;
    assertEq(c, 0, "OPE-N-003: ??= leaves 0");
    var d = false;
    d ??= true;
    assertEq(d, false, "OPE-N-003: ??= leaves false");
    var e = "";
    e ??= "x";
    assertEq(e, "", "OPE-N-003: ??= leaves empty string");
})();

assertThrows(
    function () {
        eval("0 ?? 1 || 2");
    },
    SyntaxError,
    "OPE-N-004",
    "?? mixed with || without parens"
);
assertThrows(
    function () {
        eval("0 || 1 ?? 2");
    },
    SyntaxError,
    "OPE-N-004",
    "?? mixed with || (other order)"
);
assertThrows(
    function () {
        eval("0 && 1 ?? 2");
    },
    SyntaxError,
    "OPE-N-004",
    "?? mixed with && without parens"
);

assertEq((null || undefined) ?? "c", "c", "OPE-N-005: (a || b) ?? c");
assertEq(null ?? (true && "d"), "d", "OPE-N-005: a ?? (b && c)");

// --- §6 Optional chaining (OPE-O-*) — spec-correct (no engine-gap relaxation) ---

var opeO = { x: { y: 42 }, m: function (a) { return a; } };
assertEq(opeO?.x?.y, 42, "OPE-O-001: non-nullish optional property chain");
assertEq(null?.x, undefined, "OPE-O-001: null?.prop → undefined");

var dead = 0;
var opeNull = null;
assertEq(
    opeNull?.[dead++, "nope"],
    undefined,
    "OPE-O-003: computed member not evaluated when base nullish"
);
assertEq(dead, 0, "OPE-O-003: index expression skipped");

var callDead = 0;
function opeFnMaybe() {
    return null;
}
assertEq(
    opeFnMaybe()?.(callDead++, 1),
    undefined,
    "OPE-O-004: args not evaluated when callee nullish"
);
assertEq(callDead, 0, "OPE-O-004: call args skipped");

var opeDeep = { a: null };
assertEq(opeDeep?.a?.b, undefined, "OPE-O-002: deep chain stops at first nullish link");

assertThrows(
    function () {
        eval("var o={}; o?.p = 1");
    },
    SyntaxError,
    "OPE-O-006",
    "optional chaining on assignment LHS"
);

assertThrows(
    function () {
        eval("class B extends Object { m(){ return super?.x; } }");
    },
    SyntaxError,
    "OPE-O-007: super?.",
    "invalid optional form with super"
);

assertThrows(
    function () {
        eval("import?.('fs')");
    },
    SyntaxError,
    "OPE-O-007: import?.",
    "import optional chain invalid in script goal"
);

// OPE-O-005: `new C?.()` is a SyntaxError in ECMAScript (invalid optional chain from new)
assertThrows(
    function () {
        eval("class C {}; new C?.()");
    },
    SyntaxError,
    "OPE-O-005",
    "new with invalid optional chain"
);

assertEq(opeNull?.x ?? "def", "def", "OPE-O-008: ?? after optional chain");

// --- §7 typeof (OPE-T-*) ---

assertEq(typeof 1, "number", "OPE-T-001: typeof number");
assertEq(typeof "s", "string", "OPE-T-001: typeof string");
assertEq(typeof true, "boolean", "OPE-T-001: typeof boolean");
assertEq(typeof undefined, "undefined", "OPE-T-001: typeof undefined");
assertEq(typeof null, "object", "OPE-T-002: typeof null === object");
assertEq(typeof {}, "object", "OPE-T-001: typeof plain object");
assertEq(typeof function () {}, "function", "OPE-T-001: typeof function");
assertEq(typeof Symbol("s"), "symbol", "OPE-T-001: typeof symbol");

if (typeof BigInt !== "undefined") {
    assertEq(typeof 1n, "bigint", "OPE-T-001: typeof bigint when supported");
}

assertEq(typeof notDeclaredAnywhere12345, "undefined", "OPE-T-003: typeof undeclared → undefined");

assertThrows(
    function () {
        (function () {
            return typeof inTdz;
            let inTdz = 1;
        })();
    },
    ReferenceError,
    "OPE-T-004",
    "typeof let binding in TDZ throws ReferenceError"
);

assertEq(typeof class C {}, "function", "OPE-T-005: typeof class expression");
assertEq(
    typeof function () {},
    "function",
    "OPE-T-005: typeof function declaration/expression"
);
assertEq(typeof (function () {}), "function", "OPE-T-005: typeof function value");
assertEq(typeof (() => {}), "function", "OPE-T-005: typeof arrow");
assertEq(
    typeof async function () {},
    "function",
    "OPE-T-005: typeof async function"
);

(function ope_t006() {
    function f() {}
    var p = new Proxy(f, {});
    assertEq(typeof p, "function", "OPE-T-006: typeof callable proxy is function");
})();

// --- §8 instanceof (OPE-I-*) ---

function Pe() {}
var peInst = new Pe();
Object.setPrototypeOf(peInst, Pe.prototype);
assert(peInst instanceof Pe, "OPE-I-001: instanceof true on prototype chain");

assertEq(3 instanceof Pe, false, "OPE-I-002: primitive left operand → false");

assertThrows(
    function () {
        return ({}) instanceof 1;
    },
    TypeError,
    "OPE-I-003",
    "non-object / non-callable right operand"
);

function HasInst() {}
Object.defineProperty(HasInst, Symbol.hasInstance, {
    value: function (v) {
        return v === 42;
    }
});
assertEq(42 instanceof HasInst, true, "OPE-I-004: Symbol.hasInstance custom true");
assertEq(41 instanceof HasInst, false, "OPE-I-004: Symbol.hasInstance custom false");

// OPE-I-005: cross-realm iframe not in this harness; same-realm instanceof covered by OPE-I-001

function CoerceHas() {}
Object.defineProperty(CoerceHas, Symbol.hasInstance, {
    value: function () {
        return "yes";
    }
});
assertEq({} instanceof CoerceHas, true, "OPE-I-006: @@hasInstance non-boolean coerced with ToBoolean");

// --- §9 Compound / logical assignment (OPE-S-*) ---

(function ope_s001() {
    var x = 2;
    assertEq((x += 3), 5, "OPE-S-001: += expression value is assigned value");
    assertEq(x, 5, "OPE-S-001: += updates binding");
    var y = 10;
    assertEq((y **= 2), 100, "OPE-S-001: **= expression value");
})();

(function ope_s002() {
    var b = 0b1111;
    b &= 0b1010;
    assertEq(b, 0b1010, "OPE-S-002: &=");
    b <<= 1;
    assertEq(b, 20, "OPE-S-002: <<=");
})();

(function ope_s003() {
    var rhs = 0;
    var a = null;
    a ||= (rhs++, "v");
    assertEq(rhs, 1, "OPE-S-003: ||= evaluates RHS when falsy");
    rhs = 0;
    var b = "keep";
    b ||= (rhs++, "v");
    assertEq(rhs, 0, "OPE-S-003: ||= skips RHS when truthy");

    rhs = 0;
    var c = "ok";
    c &&= (rhs++, "next");
    assertEq(rhs, 1, "OPE-S-003: &&= evaluates RHS when LHS truthy");
    rhs = 0;
    var d = null;
    d &&= (rhs++, "next");
    assertEq(rhs, 0, "OPE-S-003: &&= skips RHS when LHS falsy");

    rhs = 0;
    var e = null;
    e ??= (rhs++, 7);
    assertEq(rhs, 1, "OPE-S-003: ??= evaluates RHS when nullish");
    rhs = 0;
    var f = 1;
    f ??= (rhs++, 7);
    assertEq(rhs, 0, "OPE-S-003: ??= skips RHS when not nullish");
})();

// OPE-S-004: destructuring assignment covered under destructuring regression suites

// --- §10 Precedence (OPE-P-*) ---

assertEq(2 ** 3 ** 2, 512, "OPE-P-001: ** is right-associative (2**(3**2))");

assertThrows(
    function () {
        eval("-3**2");
    },
    SyntaxError,
    "OPE-P-002",
    "ambiguous unary vs ** requires explicit parens at parse time"
);
assertEq(-(3 ** 2), -9, "OPE-P-002: -(3**2) === -9");
assertEq((-3) ** 2, 9, "OPE-P-002: (-3)**2 === 9");

assertEq(true || false && false, true, "OPE-P-003: && tighter than ||");

var opeP4 = { b: { c: 2 } };
assertEq(opeP4?.b.c, 2, "OPE-P-004: a?.b.c — optional only on a, .c normal access");
var opeP4n = null;
assertEq(opeP4n?.b.c, undefined, "OPE-P-004: nullish a?.b.c short-circuits whole chain");

__jacDone();
