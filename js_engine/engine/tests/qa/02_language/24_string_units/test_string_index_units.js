// STR-UNIT-001..006: str[i], charAt, charCodeAt and at() index by UTF-16 code
// unit, not by UTF-8 byte, for non-ASCII, surrogate-pair and U+0000 strings.
// Regression: GET_INDEX read the raw byte at i and charAt used a byte-wise chr()
// ("a…b".charAt(1) was "&"). Vite's module code carries a real U+0000 (the
// "\0commonjsHelpers.js" import id), so rollup's `code.original[end - 1] !== ';'`
// read 3 positions early and doubled semicolons (1811 ";;" vs node's 8 →
// esbuild "Unexpected else"). Expected values below were generated with node.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/24_string_units/test_string_index_units.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(a, e, msg) { __reg.assertEq(a, e, msg); }

var table = [
  ["abc", [["a",97],["b",98],["c",99]]],
  ["a…b", [["a",97],["…",8230],["b",98]]],
  ["aéb", [["a",97],["é",233],["b",98]]],
  ["a😀b", [["a",97],["\ud83d",55357],["\ude00",56832],["b",98]]],
  ["a\u0000b", [["a",97],["\u0000",0],["b",98]]],
  ["x\u0000\u0000y…z", [["x",120],["\u0000",0],["\u0000",0],["y",121],["…",8230],["z",122]]],
  ["const a = \"\u0000commonjsHelpers.js\"; b = 1;", null]
];
table.forEach(function (row, ti) {
  var s = row[0], exp = row[1];
  if (exp) {
    assertEq(s.length, exp.length, "STR-UNIT-001: length of table[" + ti + "]");
    for (var i = 0; i < exp.length; i++) {
      assertEq(s[i], exp[i][0], "STR-UNIT-002: s[" + i + "] of table[" + ti + "]");
      assertEq(s.charAt(i), exp[i][0], "STR-UNIT-003: charAt(" + i + ") of table[" + ti + "]");
      assertEq(s.charCodeAt(i), exp[i][1], "STR-UNIT-004: charCodeAt(" + i + ") of table[" + ti + "]");
      assertEq(s.at(i), exp[i][0], "STR-UNIT-004: at(" + i + ") of table[" + ti + "]");
    }
    assertEq(s[exp.length], undefined, "STR-UNIT-002: s[length] is undefined for table[" + ti + "]");
    assertEq(s.charAt(exp.length), "", "STR-UNIT-003: charAt(length) is '' for table[" + ti + "]");
  }
  // Every index path must agree with slice(i, i + 1) (the canonical unit slice).
  for (var j = 0; j < s.length; j++) {
    assert(s[j] === s.charAt(j) && s[j] === s.slice(j, j + 1), "STR-UNIT-005: s[j]===charAt===slice at " + j + " of table[" + ti + "]");
  }
});

// Rollup's ExpressionStatement.render check on a NUL-bearing module string.
var code = "import h from \"\u0000commonjsHelpers.js\";\n" + "if (a) b(); else c();\n".repeat(200);
var stmtEnd = code.indexOf(";", code.indexOf("if (a) b();")) + 1;
assertEq(code[stmtEnd - 1], ";", "STR-UNIT-006: code[end-1] is ';' after a U+0000 earlier in the string");
var bad = 0;
for (var k = 0; k < code.length; k++) if (code[k] !== code.charAt(k)) bad++;
assertEq(bad, 0, "STR-UNIT-006: no index mismatch across a 4KB string with U+0000");
__jacDone();
