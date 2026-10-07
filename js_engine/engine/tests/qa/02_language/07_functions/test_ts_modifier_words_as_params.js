// FN-TSMOD-*: `public` / `private` / `protected` / `readonly` are ordinary JS
// identifiers. The parser's TypeScript support skipped them as parameter-property
// modifiers even when they WERE the parameter (`function f(node, readonly)`), so the
// parameter vanished and the body failed to parse — @babel/parser's
// tsParsePropertyOrMethodSignature(node, readonly), which Vite's plugin-react loads.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/07_functions/test_ts_modifier_words_as_params.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function sig(node, readonly) {
    var property = {};
    if (readonly) property.readonly = true;
    return [node, !!property.readonly].join();
}
assertEq(sig("n", true) + "|" + sig("m", false), "n,true|m,false", "FN-TSMOD-001: parameter named readonly");
function pp(public, private, protected) { return public + private + protected; }
assertEq(pp(1, 2, 3), 6, "FN-TSMOD-002: parameters named public/private/protected");
function dflt(readonly = 4, public) { return readonly + (public || 0); }
assertEq(dflt(undefined, 1), 5, "FN-TSMOD-003: readonly with a default");
var arrow = (readonly) => readonly * 2;
assertEq(arrow(3), 6, "FN-TSMOD-004: arrow parameter named readonly");
// (Class bodies are strict: public/private/protected are reserved there, readonly is not.)
class K { m(node, readonly) { return [node, readonly].join(); } }
assertEq(new K().m("n", "r"), "n,r", "FN-TSMOD-005: method parameter named readonly");
assertEq(sig.length + pp.length, 5, "FN-TSMOD-006: the words count as parameters (length)");

__jacDone();
