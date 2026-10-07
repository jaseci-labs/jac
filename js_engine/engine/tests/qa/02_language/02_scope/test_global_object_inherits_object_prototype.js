// SCP-GP-*: the global object inherits from Object.prototype (Node, browsers), so a
// bare `hasOwnProperty` / `toString` resolves through it. Regression: globalThis
// had a null [[Prototype]] and an unbound global name never looked past its own
// properties — @babel/types' definitions/placeholders.js
// (`if (!hasOwnProperty.call(PLACEHOLDERS_FLIPPED_ALIAS, alias))`) threw
// "hasOwnProperty is not defined" and Babel (Vite + plugin-react) could not load.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_global_object_inherits_object_prototype.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var proto = Object.getPrototypeOf(globalThis);
var chain = false;
while (proto !== null) { if (proto === Object.prototype) { chain = true; } proto = Object.getPrototypeOf(proto); }
assertEq(chain, true, "SCP-GP-001: Object.prototype is on globalThis's prototype chain");
assertEq(typeof hasOwnProperty, "function", "SCP-GP-002: bare hasOwnProperty resolves");
assertEq(hasOwnProperty.call({ a: 1 }, "a"), true, "SCP-GP-002: bare hasOwnProperty.call works");
assertEq(typeof toString, "function", "SCP-GP-002: bare toString resolves");
assertEq(typeof isPrototypeOf, "function", "SCP-GP-002: bare isPrototypeOf resolves");
assertEq("hasOwnProperty" in globalThis, true, "SCP-GP-003: 'hasOwnProperty' in globalThis");
assertEq(globalThis.hasOwnProperty("globalThis"), true, "SCP-GP-003: globalThis.hasOwnProperty own-check");
assertEq(Object.prototype.hasOwnProperty.call(globalThis, "toString"), false, "SCP-GP-003: inherited, not own");
var threw = false;
try { notDefinedAnywhere_gp; } catch (e) { threw = e instanceof ReferenceError; }
assertEq(threw, true, "SCP-GP-004: a truly unbound name still throws ReferenceError");
assertEq(typeof notDefinedAnywhere_gp2, "undefined", "SCP-GP-004: typeof an unbound name is 'undefined'");

__jacDone();
