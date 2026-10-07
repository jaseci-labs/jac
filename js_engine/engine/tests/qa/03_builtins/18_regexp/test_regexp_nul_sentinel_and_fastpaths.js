// RX-NUL-001..: regex escapes for U+0000 (\0, \x00, \u0000) match strings that
// contain a real U+0000 (vite/rollup strip "\0"-prefixed virtual ids with
// /\0/g). RX-FAST-001..: split/replace/match/search keep spec semantics through
// the native fast paths (pristine RegExp) and fall back correctly when the
// RegExp is not pristine (own exec / sticky / flags override). Expected values
// were produced with node.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/18_regexp/test_regexp_nul_sentinel_and_fastpaths.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(a, e, msg) { __reg.assertEq(a, e, msg); }
function J(v) { return JSON.stringify(v, function (k, x) { return x === undefined ? "__undef__" : x; }); }

var id = "\u0000commonjsHelpers.js";
assertEq(/^\0/.test(id), true, "RX-NUL-001: /^\\0/ matches a leading U+0000");
assertEq(/^\u0000/.test(id), true, "RX-NUL-001: /^\\u0000/ matches");
assertEq(/\x00/.test(id), true, "RX-NUL-001: /\\x00/ matches");
assertEq(id.replace(/\0/g, ""), "commonjsHelpers.js", "RX-NUL-002: replace(/\\0/g) strips U+0000");
assertEq("a\u0000b\u0000c".split(/\0/).length, 3, "RX-NUL-003: split(/\\0/)");
assertEq(id.startsWith("\0") && id.indexOf("\0") === 0 && id.charCodeAt(0) === 0, true, "RX-NUL-004: string-level U+0000 checks");
assertEq("ab\u0000c".replace(/\u0000/g, "0"), "ab0c", "RX-NUL-005: replace(/\\u0000/g)");
assertEq(/\01/.test("\u00011"), true, "RX-NUL-006: \\01 stays an octal escape (not rewritten)");

// split
assertEq(J("a1b2c".split(/\d/)), '["a","b","c"]', "RX-FAST-001: split by class");
assertEq(J("ab".split(/$/)), '["ab"]', "RX-FAST-002: split(/$/) keeps a single piece");
assertEq(J("ab".split(/(?:)/)), '["a","b"]', "RX-FAST-003: empty-match split");
assertEq(J("a,b".split(/(,)/)), '["a",",","b"]', "RX-FAST-004: captures are spliced in");
assertEq(J("a,b,c,d".split(/,/, 2)), '["a","b"]', "RX-FAST-005: limit");
assertEq(J("x1y22z".split(/(\d)(\d)?/)), '["x","1","__undef__","y","2","2","z"]', "RX-FAST-006: unmatched capture is undefined");
assertEq(J("A<B>bold</B>and<CODE>coded</CODE>E".split(/<(\/)?([^<>]+)>/)), '["A","__undef__","B","bold","/","B","and","__undef__","CODE","coded","/","CODE","E"]', "RX-FAST-007: multi-capture split");
assertEq(J("abc".split(/b/y)), '["a","c"]', "RX-FAST-008: sticky regexp split (slow path)");
(function () { var r = /,/; r.lastIndex = 5; var res = "a,b".split(r); assertEq(J([res, r.lastIndex]), '[["a","b"],5]', "RX-FAST-009: split leaves lastIndex alone"); })();
(function () { var r = /b/; r.exec = function () { return null; }; assertEq(J("abc".split(r)), '["a","c"]', "RX-FAST-010: split uses a fresh species splitter, so an own exec is not consulted (node parity)"); })();

// replace
assertEq("aXbXc".replace(/X/g, "-$&-"), "a-X-b-X-c", "RX-FAST-011: $& in global replace");
assertEq("abc".replace(/(b)/, "[$1$`$']"), "a[bac]c", "RX-FAST-012: $1 $` $'");
assertEq("abc".replace(/(?<n>b)/g, "<$<n>>"), "a<b>c", "RX-FAST-013: named group in replacement");
assertEq("aaa".replace(/a/g, "$$"), "$$$", "RX-FAST-014: $$");
assertEq("abc".replace(/(?:)/g, "-"), "-a-b-c-", "RX-FAST-015: empty matches");
assertEq("ab".replace(/(a)(b)/, "$2$1$3$10"), "ba$3a0", "RX-FAST-016: out-of-range $n stays literal");
assertEq("héllo wörld".replace(/l/g, "L"), "héLLo wörLd", "RX-FAST-017: non-ASCII subject, correct positions");
assertEq("𝒳a𝒳".replace(/a/gu, "-"), "𝒳-𝒳", "RX-FAST-018: /u with astral subject");
(function () { var r = /b/g; r.lastIndex = 2; var res = "abcb".replace(r, "-"); assertEq(J([res, r.lastIndex]), '["a-c-",0]', "RX-FAST-019: global replace resets lastIndex to 0"); })();
(function () { var r = /b/y; r.lastIndex = 1; var res = "abcb".replace(r, "-"); assertEq(J([res, r.lastIndex]), '["a-cb",2]', "RX-FAST-020: sticky replace (slow path) advances lastIndex"); })();
(function () { var r = /b/g; r.exec = function (s) { var m = RegExp.prototype.exec.call(this, s); if (m) m[0] = "B"; return m; }; assertEq("abcb".replace(r, "[$&]"), "a[B]c[B]", "RX-FAST-021: own exec drives functional semantics"); })();
assertEq("a1b22c333".replace(/\d+/g, function (m) { return "[" + m + "]"; }), "a[1]b[22]c[333]", "RX-FAST-022: functional replace, all matches");
assertEq("abc".replace(/(b)/, function (m, p1, off, s) { return "[" + p1 + off + s.length + "]"; }), "a[b13]c", "RX-FAST-023: functional replace args");

// match / search / exec
assertEq(J("xaybz".match(/[ab]/g)), '["a","b"]', "RX-FAST-024: global match array");
assert(Array.isArray("aa".match(/a/g)) && "aa".match(/a/g).map(function (x) { return x + "!"; }).join() === "a!,a!", "RX-FAST-025: global match returns a real Array");
(function () { var m = "xay".match(/a/); assertEq(J([m[0], m.index, m.input, m.length, Object.keys(m)]), '["a",1,"xay",1,["0","index","input","groups"]]', "RX-FAST-026: match array shape incl. groups"); })();
assertEq(J("aaa".match(/(?:)/g)), '["","","",""]', "RX-FAST-027: empty global matches");
assertEq("héllo".search(/l/), 2, "RX-FAST-028: search returns a code-unit index");
assertEq(/l/.exec("héllo").index, 2, "RX-FAST-029: exec index is a code-unit index");
(function () { var r = /b/g; r.lastIndex = 4; var res = "xxabc".search(r); assertEq(J([res, r.lastIndex]), '[3,4]', "RX-FAST-030: search restores lastIndex"); })();
(function () { var m = /(?<x>a)|(?<y>b)/d.exec("b"); assertEq(J([m.indices, m.indices.groups, m.groups]), '[[[0,1],"__undef__",[0,1]],{"x":"__undef__","y":[0,1]},{"x":"__undef__","y":"b"}]', "RX-FAST-031: /d indices"); })();
assertEq(J([].concat.apply([], ["a1b2".matchAll(/\d/g)].map(function (it) { return Array.from(it, function (m) { return [m[0], m.index, m.input]; }); }))), '[["1",1,"a1b2"],["2",3,"a1b2"]]', "RX-FAST-032: matchAll");
__jacDone();
