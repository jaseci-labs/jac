// Regression: a literal `[` inside a character class must be a LITERAL, not
// re-open/close the class. The pattern normalizer's []/[^] rewrites (and its
// class-opener tracking) previously had no in-class awareness, so `[[]` hit the
// empty-class rewrite on its inner `[]` pair and was mangled — making
// `/[<[]/` match every character. That broke vite's CLI routing (cac's
// removeBrackets `/[<[]/`), so `vite build` fell through to the dev/preview
// default. See VITE_ROADMAP.md 2026-09-14 update.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/18_regexp/test_regexp_literal_bracket_in_class.js");
var __jacOrigExit = process.exit.bind(process);
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RE-LBC-001 — class with a literal `[` must not match an unrelated char.
assertEq("b".search(/[<[]/), -1, "RE-LBC-001: [<[] does not match 'b'");
assertEq("[".search(/[<[]/), 0, "RE-LBC-001: [<[] matches '['");
assertEq("<".search(/[<[]/), 0, "RE-LBC-001: [<[] matches '<'");
assertEq("x[".search(/[<[]/), 1, "RE-LBC-001: [<[] matches '[' at idx 1, not 'x'");

// RE-LBC-002 — a class holding ONLY a literal `[`.
assertEq("a[".search(/[[]/), 1, "RE-LBC-002: [[] matches '[' at idx 1");
assertEq("a".search(/[[]/), -1, "RE-LBC-002: [[] does not match 'a'");

// RE-LBC-003 — the exact cac removeBrackets use: strip `[...]`/`<...>` suffix.
var removeBrackets = function (v) { return v.replace(/[<[].+/, "").trim(); };
assertEq(removeBrackets("build [root]"), "build", "RE-LBC-003: removeBrackets 'build [root]'");
assertEq(removeBrackets("preview [root]"), "preview", "RE-LBC-003: removeBrackets 'preview [root]'");
assertEq(removeBrackets("optimize [root]"), "optimize", "RE-LBC-003: removeBrackets 'optimize [root]'");
assertEq(removeBrackets("[root]"), "", "RE-LBC-003: removeBrackets '[root]' (pure default)");
assertEq(removeBrackets("cmd <arg>"), "cmd", "RE-LBC-003: removeBrackets angle-bracket form");

// RE-LBC-004 — a class with both `]` (via escape) and `[`; and a nested-looking
// literal `[` mid-class. `\]` must not close the class early.
assertEq("z]".search(/[\]a]/), 1, "RE-LBC-004: escaped ] inside class matches ']'");
assertEq("q[r".search(/[[r]/), 1, "RE-LBC-004: [ then r in class, matches '[' first");

// RE-LBC-005 — genuine empty-class rewrites must STILL work (not broken by the fix).
assertEq("\n".search(/[^]/), 0, "RE-LBC-005: [^] matches newline (any char)");
assertEq("a".search(/[]/), -1, "RE-LBC-005: [] matches nothing");

// RE-LBC-006 — \u escapes inside a class still normalize (fix preserved this):
// the fix fast-paths only NON-\u escapes, so A in a class must still work.
assertEq("A".search(/[A]/), 0, "RE-LBC-006: \\u0041 inside class matches 'A'");
assertEq("B".search(/[A]/), -1, "RE-LBC-006: \\u0041 inside class does not match 'B'");
assertEq("A".search(/[A[]/), 0, "RE-LBC-006: \\u0041 + literal '[' in same class");

__reg.finalize(__jacOrigExit);
