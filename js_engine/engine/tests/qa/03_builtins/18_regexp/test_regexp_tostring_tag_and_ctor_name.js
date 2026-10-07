// ECMAScript §22.2 (RegExp) — [Symbol.toStringTag] / constructor.name
// Covers: Object.prototype.toString.call(re) === "[object RegExp]"
//         RegExp.name === "RegExp" and re.constructor.name === "RegExp"
// Regression: rolldown's napi binding identifies a RegExp filter payload via
// these; without them `vite build` fails with "Value is none of these types".
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_tostring_tag_and_ctor_name.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}

// --- RX-TAG-001: Object.prototype.toString tag (literal + constructed) ---
assertEq(
    Object.prototype.toString.call(/abc/),
    "[object RegExp]",
    "RX-TAG-001: literal RegExp toString tag"
);
assertEq(
    Object.prototype.toString.call(new RegExp("abc", "g")),
    "[object RegExp]",
    "RX-TAG-001: constructed RegExp toString tag"
);

// --- RX-TAG-002: non-RegExp objects keep their own tag ---
assertEq(
    Object.prototype.toString.call({}),
    "[object Object]",
    "RX-TAG-002: plain object still tags as Object"
);
assertEq(
    Object.prototype.toString.call([]),
    "[object Array]",
    "RX-TAG-002: array still tags as Array"
);

// --- RX-CTOR-001: constructor name ---
assertEq(RegExp.name, "RegExp", "RX-CTOR-001: RegExp.name");
assertEq(/abc/.constructor.name, "RegExp", "RX-CTOR-001: literal.constructor.name");
assertEq(
    new RegExp("abc").constructor.name,
    "RegExp",
    "RX-CTOR-001: constructed.constructor.name"
);
assert(/abc/.constructor === RegExp, "RX-CTOR-001: constructor identity is RegExp");

// --- RX-CTOR-002: `name` is non-enumerable on the constructor ---
assert(
    Object.keys(RegExp).indexOf("name") === -1,
    "RX-CTOR-002: RegExp.name is non-enumerable"
);

__jacDone();
