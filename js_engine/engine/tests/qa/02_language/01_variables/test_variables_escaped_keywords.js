// Escaped-keyword classification (ES § 12.7.1): an IdentifierName that contains
// a Unicode escape is NEVER a ReservedWord or contextual keyword — its decoded
// spelling matching a keyword is irrelevant. Regression coverage for the A13 lexer
// fix; previously the escaped spelling was reclassified as the keyword, breaking
// statements/let/syntax/escaped-let and labeled/value-await-non-module-escaped.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_escaped_keywords.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- § 1 escaped 'let' (l\u0065t) is a plain identifier, not a declaration ---
// 'l\u0065t a;' must parse as the expression statement 'let' (ASI) + 'a;', NOT as
// 'let a' — otherwise it would collide with the 'var a' below (early SyntaxError).
(function () {
    this.let = 0;
    l\u0065t
    a;
    var a;
    assert(true, "escaped 'let' is an identifier, not a let-declaration");
}());

// --- § 2 escaped 'await' (aw\u0061it) usable as a label (non-async, sloppy) ---
(function () {
    var ran = false;
    aw\u0061it: { ran = true; break aw\u0061it; }
    assert(ran, "escaped 'await' usable as a label in sloppy code");
}());

// --- § 3 escaped 'yield' (yi\u0065ld) usable as a label (outside generator) ---
(function () {
    var ran = false;
    yi\u0065ld: { ran = true; break yi\u0065ld; }
    assert(ran, "escaped 'yield' usable as a label outside a generator");
}());

// --- § 4 escaped contextual keyword 'static' (st\u0061tic) as a binding ---
(function () {
    var st\u0061tic = 7;
    assertEq(st\u0061tic, 7, "escaped 'static' is an ordinary identifier");
}());

// --- § 5 regression guard: real (unescaped) keywords still work ---
(function () {
    let x = 5;
    const y = 6;
    assertEq(x + y, 11, "unescaped let/const still work as keywords");
    var hit = false;
    if (true) { hit = true; }
    assert(hit, "unescaped if still works as a keyword");
}());

__jacDone();
