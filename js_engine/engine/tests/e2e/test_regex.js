// test_regex.js — Phase 2.9: Regular Expressions
// 25 tests covering: literals, constructor, test, exec, flags, String methods

var passed = 0;
var failed = 0;

function assert(cond, msg) {
    if (cond) {
        passed++;
        console.log("  PASS: " + msg);
    } else {
        failed++;
        console.log("  FAIL: " + msg);
    }
}

function assertEq(a, b, msg) {
    if (a === b) {
        passed++;
        console.log("  PASS: " + msg);
    } else {
        failed++;
        console.log("  FAIL: " + msg + " — got " + String(a) + ", expected " + String(b));
    }
}

// ── 1. RegExp literal + test ────────────────────────────────────────────────
assertEq(/abc/.test("xabcx"), true,   "1. literal /abc/.test match");
assertEq(/abc/.test("xyz"),   false,  "2. literal /abc/.test no match");

// ── 2. Digit class \d ───────────────────────────────────────────────────────
assertEq(/\d+/.test("abc123"), true,  "3. \\d+ matches digits in string");
assertEq(/^\d+$/.test("123"), true,   "4. ^\\d+$ anchored digit match");
assertEq(/^\d+$/.test("12x"), false,  "5. ^\\d+$ no match with letter");

// ── 3. Case-insensitive flag ─────────────────────────────────────────────────
assertEq(/abc/i.test("ABC"), true,    "6. /abc/i case insensitive match");
assertEq(/abc/i.test("XYZ"), false,   "7. /abc/i no match");

// ── 4. RegExp constructor ────────────────────────────────────────────────────
var re1 = new RegExp("\\d+");
assertEq(re1.test("hello42"), true,   "8. new RegExp constructor test");
var re2 = new RegExp("^\\d+$", "i");
assertEq(re2.test("123"), true,       "9. new RegExp with flags");
assertEq(re2.test("abc"), false,      "10. new RegExp no match");

// ── 5. exec returns match array ──────────────────────────────────────────────
var m1 = /l+/.exec("hello");
assert(m1 !== null,                    "11. exec returns non-null on match");
assertEq(m1[0], "ll",                  "12. exec match[0] is full match");
assertEq(m1.index, 2,                  "13. exec match.index is correct");

var m2 = /xyz/.exec("hello");
assertEq(m2, null,                     "14. exec returns null on no match");

// ── 6. Capturing groups ──────────────────────────────────────────────────────
var m3 = /(\d+)-(\d+)/.exec("2024-04");
assert(m3 !== null,                    "15. capturing groups: non-null");
assertEq(m3[0], "2024-04",             "16. capturing groups: full match");
assertEq(m3[1], "2024",               "17. capturing groups: group 1");
assertEq(m3[2], "04",                 "18. capturing groups: group 2");

// ── 7. String.prototype.match ────────────────────────────────────────────────
var mr = "hello world".match(/\w+/);
assert(mr !== null,                    "19. String.match non-null");
assertEq(mr[0], "hello",               "20. String.match first word");

var mrg = "aababc".match(/a/g);
assert(mrg !== null,                   "21. String.match global returns all");
assertEq(mrg.length, 3,               "22. String.match global count");

// ── 8. String.prototype.replace ─────────────────────────────────────────────
assertEq("abc".replace(/b/, "X"),   "aXc",   "23. String.replace basic");
assertEq("abc abc".replace(/abc/g, "X"), "X X", "24. String.replace global");
assertEq("abc".replace(/[aeiou]/g, "*"), "*bc", "25. String.replace char class");

assertEq(
    "abc".replace(/b/, function (m) { return m.toUpperCase(); }),
    "aBc",
    "25b. String.replace callable (non-global)"
);
assertEq(
    "a-a-a".replace(/a/g, function () { return "x"; }),
    "x-x-x",
    "25c. String.replace callable (global)"
);

var sawGroups = false;
var outNamed = "abc".replace(/(?<g>b)/, function (m, g1, off, s, gr) {
    if (gr !== undefined && gr.g === "b") { sawGroups = true; }
    return "X";
});
assertEq(outNamed, "aXc", "25d. String.replace callable named groups result");
assert(sawGroups, "25e. String.replace callable receives groups object");

// 25f. str.replace(string, fn) — plain-string search with callable replacer
assertEq(
    "hello world".replace("world", function(m, off, s) { return "[" + m + "@" + off + "]"; }),
    "hello [world@6]",
    "25f. String.replace plain-string callable"
);

// 25g. str.replace(string, fn) — no match returns original
assertEq(
    "hello".replace("xyz", function() { return "REPLACED"; }),
    "hello",
    "25g. String.replace plain-string callable no-match"
);

// ── 9. Regressions from qa_issues/regexp ────────────────────────────────────
var m4 = /(a)?b/.exec("b");
assert(m4 !== null,                    "26. optional capture exec non-null");
assertEq(m4[0], "b",                   "27. optional capture full match");
assertEq(m4[1], undefined,             "28. optional capture is undefined");

assertEq(new RegExp("a", "mgi").flags, "gim", "29. canonical flags ordering");

var splitCap = "a1b".split(/(\d)/);
assertEq(splitCap.length, 3,           "30. split capture includes group");
assertEq(splitCap[1], "1",             "31. split capture value");

var symMatch = RegExp.prototype[Symbol.match].call(/a/g, "aba");
assertEq(symMatch.length, 2,           "32. @@match global returns 2 entries");

var it = "hello".matchAll(/l/g);
var i1 = it.next();
assertEq(i1.done, false,               "33. matchAll iterator first done=false");
assertEq(i1.value[0], "l",             "34. matchAll iterator first value");

// Lookbehind + plain capture — group-names scan must not treat (?<= as (?<name>
var mLb = /(?<=x)(a)/.exec("xa");
assert(mLb !== null,                   "35. lookbehind + capture exec");
assertEq(mLb[1], "a",                  "36. capture after lookbehind");
assertEq(mLb.groups, undefined,        "37. no spurious named groups object");

// ── 10. for...of matchAll ────────────────────────────────────────────────────
var foResults = [];
for (var fm of "axbxc".matchAll(/x/g)) { foResults.push(fm[0]); }
assertEq(foResults.length, 2,          "38. for...of matchAll yields correct count");
assertEq(foResults[0], "x",            "39. for...of matchAll first value");

// ── 11. String.split regressions ─────────────────────────────────────────────
// B-1: '='.split('') must not append spurious empty string
var splitEq = "=".split("");
assertEq(splitEq.length, 1,            "40. '='.split('') length is 1");
assertEq(splitEq[0], "=",              "41. '='.split('')[0] is '='");

// B-2: split('') with explicit limit must not drop characters
var splitLim = "ab".split("", 2);
assertEq(splitLim.length, 2,           "42. split('',2) gives both chars");
assertEq(splitLim[1], "b",             "43. split('',2)[1] is 'b'");

// ── 12. Lexer: /= is a regex literal in regexp-expected position, not SlashEq ──
// Regression for: lexer bug where `/=/g` was tokenised as the compound-
// assignment operator `/=` followed by a broken second token `/g`.
var EQUAL_RE    = /=/g;           // pattern = "=", flags = "g"
var SLASH_RE    = /\//g;          // pattern = "/", flags = "g"
var EMPTY_RE    = /(?:)/g;        // pattern = empty alternation
var ASSIGN_STMT = "a=b;c=d";      // used for replace / match tests

assertEq(EQUAL_RE.test("a=b"), true,       "44. /=/g matches '=' in string");
assertEq(EQUAL_RE.test("abc"), false,      "45. /=/g does not match string without '='");
assertEq(EQUAL_RE.source, "=",             "46. /=/g .source is '='");
assertEq(EQUAL_RE.flags.indexOf("g") >= 0, true, "47. /=/g has global flag");

var equalMatches = ASSIGN_STMT.match(/=/g);
assertEq(equalMatches !== null, true,      "48. '='.match(/=/g) is non-null");
assertEq(equalMatches.length, 2,           "49. match(/=/g) finds both '=' signs");

var replaced = ASSIGN_STMT.replace(/=/g, ":");
assertEq(replaced, "a:b;c:d",             "50. replace(/=/g) replaces all '=' with ':'");

assertEq(SLASH_RE.test("a/b"), true,       "51. /\//g matches '/' in string");
assertEq(SLASH_RE.test("abc"), false,      "52. /\//g no match without '/'");

// /= inside a group (not at start — must also parse correctly)
var groupEq = /[=]/.test("x=y");
assertEq(groupEq, true,                   "53. /[=]/ matches '='");

// Division vs regex: after an expression, '/' is division (not regex start)
var divResult = 10 / 2;
assertEq(divResult, 5,                    "54. 10/2 is division, not regex start");

// /= as compound assignment (not in regex position)
var divAssign = 10;
divAssign /= 2;
assertEq(divAssign, 5,                    "55. /= compound assignment still works");

// ── Summary ──────────────────────────────────────────────────────────────────
console.log("=== Tests: " + passed + " passed, " + failed + " failed ===");
