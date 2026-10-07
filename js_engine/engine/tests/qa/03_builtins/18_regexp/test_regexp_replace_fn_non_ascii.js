// RE-RFN-*: str.replace(regexp, fn) on a string with multi-byte characters splices
// at the match's UTF-16 index. Regression: the method-call fast path took
// match.index (UTF-16 units) and sliced the UTF-8 subject by bytes, so each
// replacement landed early by the number of extra bytes before it and the match
// text survived — rollup's hash-placeholder pass (code.replace(re, fn)) wrote
// every chunk hash 10 characters early in a chunk containing ★☆·…→, and Vite's
// build failed parsing its own output.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/18_regexp/test_regexp_replace_fn_non_ascii.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var PH = /!~\{\d{3}\}~/g;
var src = 'x★y·z→ import("./A-!~{001}~.js") "./B-!~{002}~.js"';
var hashes = { "!~{001}~": "AAAAAAAA", "!~{002}~": "BBBBBBBB" };
assertEq(src.replace(PH, function (p) { return hashes[p]; }),
    'x★y·z→ import("./A-AAAAAAAA.js") "./B-BBBBBBBB.js"', "RE-RFN-001: global fn replace after multi-byte chars");
assertEq(src.replace(/!~\{(\d{3})\}~/, function (m, d) { return "<" + d + ">"; }),
    'x★y·z→ import("./A-<001>.js") "./B-!~{002}~.js"', "RE-RFN-002: non-global fn replace with a capture");

var offsets = [];
"é-a-😀-a".replace(/a/g, function (m, off) { offsets.push(off); return "b"; });
assertEq(offsets.join(), "2,7", "RE-RFN-003: callback offset is a UTF-16 index (astral char = 2 units)");
assertEq("é-a-😀-a".replace(/a/g, function () { return "b"; }), "é-b-😀-b", "RE-RFN-003: splice after an astral char");

assertEq("★★".replace(/(?:)/g, function () { return "|"; }), "|★|★|", "RE-RFN-004: empty matches step over multi-byte chars");
assertEq("😀x".replace(/(?:)/gu, function () { return "|"; }), "|😀|x|", "RE-RFN-004: empty matches step over an astral char (u)");

assertEq(RegExp.prototype[Symbol.replace].call(PH, src, function (p) { return hashes[p]; }),
    'x★y·z→ import("./A-AAAAAAAA.js") "./B-BBBBBBBB.js"', "RE-RFN-005: RegExp.prototype[@@replace].call path");

var soff = -1;
assertEq("★★ab".replace("ab", function (m, off) { soff = off; return "X"; }), "★★X", "RE-RFN-006: string search + fn splice");
assertEq(soff, 2, "RE-RFN-006: string search callback offset is a UTF-16 index");

__jacDone();
