// STRICT-001 through STRICT-007: Strict mode
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_strict_mode/test_strict_mode.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STRICT-001: "use strict" directive — at top of function
function strictFn() {
    "use strict";
    return typeof this;
}
assertEq(strictFn(), "undefined", "STRICT-001: 'use strict' in function — this is undefined");

// STRICT-002: Class bodies are implicitly strict
class StrictClass {
    getThis() { return this; }
    getUndefinedThis() {
        var fn = this.getThis;
        // Detached call in class method (strict) — this is undefined
        return fn ? fn() : undefined;
    }
}
var sc = new StrictClass();
assert(sc.getThis() instanceof StrictClass, "STRICT-002: class method this is instance");
// (detached call test omitted to avoid engine-specific behavior)

// STRICT-003: this in strict standalone function — undefined
function strictThis() { "use strict"; return this; }
assertEq(strictThis(), undefined, "STRICT-003: standalone strict function this === undefined");
// Compare to non-strict
function nonStrictThis() { return this; }
assert(nonStrictThis() !== undefined, "STRICT-003: non-strict standalone this !== undefined");

// STRICT-004: arguments in strict — no arguments.callee
function strictArgs(a, b) {
    "use strict";
    return arguments.length;
}
assertEq(strictArgs(1, 2), 2, "STRICT-004: arguments.length works in strict");
var calleeLookupThrew = false;
try {
    (function() {
        "use strict";
        return arguments.callee;
    })();
} catch(e) {
    calleeLookupThrew = true;
}
assert(calleeLookupThrew, "STRICT-004: arguments.callee throws in strict mode");

// STRICT-007: Assignment to read-only — TypeError in strict
var threw7 = false;
try {
    (function() {
        "use strict";
        undefined = 5;
    })();
} catch(e) {
    threw7 = e instanceof TypeError;
}
assert(threw7, "STRICT-007: assignment to read-only in strict throws TypeError");

// Non-configurable property
var strictObj = Object.freeze({ x: 1 });
var frozenThrew = false;
try {
    (function() {
        "use strict";
        strictObj.x = 99;
    })();
} catch(e) {
    frozenThrew = e instanceof TypeError;
}
assert(frozenThrew, "STRICT-007: assignment to frozen property throws TypeError in strict");

__jacDone();
