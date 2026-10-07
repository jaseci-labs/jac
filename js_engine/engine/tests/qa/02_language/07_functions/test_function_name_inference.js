// FNAME-001 through FNAME-030: Function .name inference (A2 fix)
// Covers name inference for arrow, class, cover-grammar, function-expression,
// and generator defaults in array/object destructuring formal parameters.
// Pattern matches test262 dstr/ary-ptrn-elem-id-init-fn-name-* and
// dstr/obj-ptrn-id-init-fn-name-* tests that became passing after A2.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/07_functions/test_function_name_inference.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── Array destructuring param — arrow default (FNAME-001) ────────────────────
// f([]) triggers default; name must be inferred from the binding identifier
var fname001Called = 0;
function fname001([arrow = () => {}]) {
    assertEq(arrow.name, "arrow", "FNAME-001: ary-ptrn arrow default infers name from binding");
    fname001Called++;
}
fname001([]);
assertEq(fname001Called, 1, "FNAME-001: function invoked");

// ── Array destructuring param — class default (FNAME-002) ────────────────────
var fname002Called = 0;
function fname002([cls = class {}]) {
    assertEq(cls.name, "cls", "FNAME-002: ary-ptrn class default infers name from binding");
    fname002Called++;
}
fname002([]);
assertEq(fname002Called, 1, "FNAME-002: function invoked");

// ── Array destructuring param — cover-grammar default (FNAME-003) ────────────
// Parenthesised anonymous function expression
var fname003Called = 0;
function fname003([cover = (function() {})]) {
    assertEq(cover.name, "cover", "FNAME-003: ary-ptrn cover default infers name from binding");
    fname003Called++;
}
fname003([]);
assertEq(fname003Called, 1, "FNAME-003: function invoked");

// ── Array destructuring param — function-expression default (FNAME-004) ───────
var fname004Called = 0;
function fname004([fn = function() {}]) {
    assertEq(fn.name, "fn", "FNAME-004: ary-ptrn fn-expr default infers name from binding");
    fname004Called++;
}
fname004([]);
assertEq(fname004Called, 1, "FNAME-004: function invoked");

// ── Array destructuring param — generator default (FNAME-005) ────────────────
var fname005Called = 0;
function fname005([gen = function*() {}]) {
    assertEq(gen.name, "gen", "FNAME-005: ary-ptrn gen default infers name from binding");
    fname005Called++;
}
fname005([]);
assertEq(fname005Called, 1, "FNAME-005: function invoked");

// ── Object destructuring param — arrow default (FNAME-011) ───────────────────
var fname011Called = 0;
function fname011({ arrow = () => {} }) {
    assertEq(arrow.name, "arrow", "FNAME-011: obj-ptrn arrow default infers name from key");
    fname011Called++;
}
fname011({});
assertEq(fname011Called, 1, "FNAME-011: function invoked");

// ── Object destructuring param — class default (FNAME-012) ───────────────────
var fname012Called = 0;
function fname012({ cls = class {} }) {
    assertEq(cls.name, "cls", "FNAME-012: obj-ptrn class default infers name from key");
    fname012Called++;
}
fname012({});
assertEq(fname012Called, 1, "FNAME-012: function invoked");

// ── Object destructuring param — cover-grammar default (FNAME-013) ───────────
var fname013Called = 0;
function fname013({ cover = (function() {}) }) {
    assertEq(cover.name, "cover", "FNAME-013: obj-ptrn cover default infers name from key");
    fname013Called++;
}
fname013({});
assertEq(fname013Called, 1, "FNAME-013: function invoked");

// ── Object destructuring param — function-expression default (FNAME-014) ──────
var fname014Called = 0;
function fname014({ fn = function() {} }) {
    assertEq(fn.name, "fn", "FNAME-014: obj-ptrn fn-expr default infers name from key");
    fname014Called++;
}
fname014({});
assertEq(fname014Called, 1, "FNAME-014: function invoked");

// ── Object destructuring param — generator default (FNAME-015) ───────────────
var fname015Called = 0;
function fname015({ gen = function*() {} }) {
    assertEq(gen.name, "gen", "FNAME-015: obj-ptrn gen default infers name from key");
    fname015Called++;
}
fname015({});
assertEq(fname015Called, 1, "FNAME-015: function invoked");

// ── Regression: explicit name beats inferred binding name (FNAME-020) ─────────
var fname020Called = 0;
function fname020([x = function explicit() {}]) {
    assertEq(x.name, "explicit", "FNAME-020: explicit fn name is not overwritten by binding");
    fname020Called++;
}
fname020([]);
assertEq(fname020Called, 1, "FNAME-020: function invoked");

// ── Default is only applied when element/property is undefined (FNAME-021) ────
var fname021Called = 0;
function fname021([arrow = () => {}]) {
    assertEq(arrow.name, "", "FNAME-021: provided value keeps its own name, not binding name");
    fname021Called++;
}
fname021([() => {}]);
assertEq(fname021Called, 1, "FNAME-021: function invoked");

__jacDone();
