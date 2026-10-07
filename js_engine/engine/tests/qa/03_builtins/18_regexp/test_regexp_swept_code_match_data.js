// RE-SWEEP-001: a regexp compiled after the GC swept other regexps still matches.
// The matcher caches one PCRE2 match-data block per compiled-code POINTER; the GC
// frees swept regexps' codes and malloc hands those addresses to later compiles,
// so a new pattern inherited a dead one's block. A block with fewer ovector slots
// than the pattern's groups made pcre2_match return 0, read as "no match" —
// rollup's /\[(\w+)(:\d+)?]/g missed "assets/[name]-[hash].js" and Vite emitted
// chunks literally named "[name]-[hash].js". Needs --gc to reproduce.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/18_regexp/test_regexp_swept_code_match_data.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var miss = 0, total = 0, badGroups = 0;
for (var round = 0; round < 80; round++) {
    // Zero-group regexes, matched once (so their match data is cached), dropped.
    for (var i = 0; i < 50; i++) { new RegExp("q" + round + "x" + i + "[a-z]").test("q" + round + "x" + i + "b"); }
    var junk = [];
    for (var j = 0; j < 2000; j++) junk.push({ a: j, b: "s" + j });
    // Fresh two-group patterns: must match and report both groups.
    for (var k = 0; k < 20; k++) {
        var re = new RegExp("\\[(\\w+)(:\\d+)?\\]|zz" + round + "_" + k, "g");
        total++;
        var m = re.exec("assets/[name:8]-[hash].js");
        if (m === null) miss++;
        else if (m[1] !== "name" || m[2] !== ":8") badGroups++;
    }
}
assertEq(miss, 0, "RE-SWEEP-001: fresh regexps match after GC sweeps (" + total + " tried)");
assertEq(badGroups, 0, "RE-SWEEP-001: capture groups intact");
assertEq("assets/[name]-[hash].js".replace(/\[(\w+)(:\d+)?]/g, function (_m, t) { return t.toUpperCase(); }),
    "assets/NAME-HASH.js", "RE-SWEEP-002: rollup renderNamePattern shape");

__jacDone();
