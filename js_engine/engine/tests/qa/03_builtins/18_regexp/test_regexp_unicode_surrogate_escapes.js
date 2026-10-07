// RE-SURR-*: a /u regexp may name surrogate code points (`/[\uD800-\uDFFF]/u` —
// @babel/parser's `loneSurrogate`). PCRE2's UTF-8 mode rejects such escapes by
// default, so the literal threw "Invalid regular expression" at module load and
// @babel/parser (and every Vite plugin-react transform) failed.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/18_regexp/test_regexp_unicode_surrogate_escapes.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var loneSurrogate = /[\uD800-\uDFFF]/u;
assertEq(loneSurrogate instanceof RegExp, true, "RE-SURR-001: surrogate class compiles under /u");
assertEq(loneSurrogate.test("plain ascii"), false, "RE-SURR-002: no match on ASCII");
assertEq(loneSurrogate.test("é★😀"), false, "RE-SURR-002: a well-formed astral pair is not a lone surrogate");
assertEq(new RegExp("[\\uD800-\\uDBFF]", "u").source, "[\\uD800-\\uDBFF]", "RE-SURR-003: RegExp constructor, lead range");
assertEq(/\uDC00/u.flags, "u", "RE-SURR-003: single surrogate escape");
// Under /u a high+low escape PAIR is one code point.
assertEq(/\uD83D\uDE00/u.test("x😀y"), true, "RE-SURR-004: escaped surrogate pair matches the astral char");
assertEq(/^[\uD83D\uDE00]$/u.test("😀"), true, "RE-SURR-004: escaped pair inside a class");
assertEq(/^\u{1F600}$/u.test("😀"), true, "RE-SURR-004: \\u{...} astral escape");

__jacDone();
