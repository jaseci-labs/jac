// Long slices of byte-clean strings are lazy views (jsstring.str_slice_cell): every
// read path must see the same text as an eager copy. Expected values are built from
// short pieces (< 1024 bytes, which are always copied) or from charCodeAt.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_lazy_slices.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var parts = [];
for (var i = 0; i < 3000; i++) parts.push("line " + i + ": " + "abcdefghij".repeat(i % 7) + "\n");
var base = parts.join("");
var L = base.length;

// Rebuild base[a, b) from short copied pieces, independent of the lazy path.
function eager(s, a, b) {
  var out = "";
  for (var p = a; p < b; p += 500) out += s.slice(p, Math.min(p + 500, b));
  return out;
}

// STR-LZ-001: argument forms give the same text as an eager copy.
var forms = [[0, undefined], [5, undefined], [-2000, undefined], [0, L], [0, -1], [1500, 9000], [100.9, 7000.2], ["10", "4000"], [NaN, 3000], [-Infinity, Infinity]];
for (var f = 0; f < forms.length; f++) {
  var a = forms[f][0], b = forms[f][1];
  var r = base.slice(a, b);
  var st = Math.trunc(Number(a)) || 0; if (st < 0) st = Math.max(L + st, 0); if (st > L) st = L;
  var en = b === undefined ? L : Math.trunc(Number(b)); if (en !== en) en = 0; if (en < 0) en = Math.max(L + en, 0); if (en > L) en = L;
  assertEq(r.length, Math.max(en - st, 0), "STR-LZ-001: slice length " + f);
  assert(r === eager(base, st, en), "STR-LZ-001: slice text " + f);
}
assert(base.substring(9000, 1500) === eager(base, 1500, 9000), "STR-LZ-001: substring swaps its bounds");
assert(base.slice(0) === base && base.substring(0, L) === base, "STR-LZ-001: whole-range slice equals the string");

// STR-LZ-002: slices of slices (including short pieces of long views).
var s = base;
for (var k = 0; k < 25; k++) s = s.slice(37, s.length - 11);
assert(s === eager(base, 25 * 37, L - 25 * 11), "STR-LZ-002: chained slices");
var t = base.slice(2048, 60000);
assert(t.slice(10, 30) === eager(base, 2058, 2078), "STR-LZ-002: short piece of a long view");
assert(t.slice(-3000).slice(100, 2500) === eager(base, 60000 - 3000 + 100, 60000 - 3000 + 2500), "STR-LZ-002: view of a view");

// STR-LZ-003: every read path sees the view's text.
var te = eager(base, 2048, 60000);
assertEq(t.indexOf("line 900"), te.indexOf("line 900"), "STR-LZ-003: indexOf");
assertEq(t.charCodeAt(12345), te.charCodeAt(12345), "STR-LZ-003: charCodeAt");
assertEq(t.split("\n").length, te.split("\n").length, "STR-LZ-003: split");
assertEq(/line (\d+): abc/.exec(t.slice(5000))[1], /line (\d+): abc/.exec(te.slice(5000))[1], "STR-LZ-003: RegExp exec");
assertEq(t.replace(/line/g, "L").length, te.replace(/line/g, "L").length, "STR-LZ-003: replace");
assertEq(t.toUpperCase().charCodeAt(7), te.toUpperCase().charCodeAt(7), "STR-LZ-003: toUpperCase");
assert(t === te && !(t < te) && !(t > te), "STR-LZ-003: equality and ordering");
assertEq(JSON.parse(JSON.stringify({ k: t })).k.length, te.length, "STR-LZ-003: JSON round trip");
assertEq((t + "|" + base.slice(-1500)).length, te.length + 1 + 1500, "STR-LZ-003: concatenation");
assertEq([t, "x"].join(",").length, te.length + 2, "STR-LZ-003: join");

// STR-LZ-004: views as property, Map and Set keys match equal text.
var o = {};
o[t.slice(0, 2000)] = 1;
assertEq(o[eager(base, 2048, 4048)], 1, "STR-LZ-004: object key");
var m = new Map([[t.slice(1, 3000), "v"]]);
assertEq(m.get(eager(base, 2049, 5048)), "v", "STR-LZ-004: Map key");
assertEq(new Set([t.slice(1, 3000), eager(base, 2049, 5048)]).size, 1, "STR-LZ-004: Set dedup");

// STR-LZ-005: non-ASCII and NUL-holding strings keep their own path.
var u = ("é€😀".repeat(400) + base).slice(7, 9000);   // 4 UTF-16 units per repeat
assertEq(u.length, 8993, "STR-LZ-005: non-ASCII slice length");
assertEq(u.charCodeAt(0), 0xde00, "STR-LZ-005: non-ASCII slice starts mid surrogate pair");
var z = "\u0000ab".repeat(500).slice(3, 1400);
assertEq(z.length, 1397, "STR-LZ-005: NUL slice length");
assertEq(z.charCodeAt(0), 0, "STR-LZ-005: NUL slice keeps the NUL");

__jacDone();
