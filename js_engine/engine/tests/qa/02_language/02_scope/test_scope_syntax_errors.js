// SCOPE_COMPREHENSIVE_TEST_PLAN — parse-time SyntaxError cases (SCP-L/C/FN/TC)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_syntax_errors.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertSyntaxError(src, msg) {
    try {
        new Function(src);
        assert(false, msg + " (expected SyntaxError)");
    } catch (ex) {
        assert(ex instanceof SyntaxError, msg + " (got " + ex + ")");
    }
}

// SCP-L-007 duplicate let
assertSyntaxError("function f(){ let a; let a; }", "SCP-L-007: duplicate let");
assertSyntaxError("function f(){ let a; const a = 1; }", "SCP-L-007: let then const same name");
assertSyntaxError("function f(){ let a; var a; }", "SCP-L-007: let then var");

// SCP-L-007 let outer + var inner same merged scope
assertSyntaxError("function f(){ let x = 1; { var x = 2; } }", "SCP-L-007: let + var same scope via block");

// SCP-L-008 let duplicates parameter
assertSyntaxError("function f(a){ let a = 1; }", "SCP-L-008: let same as parameter");

// SCP-L-009 catch + let same as binding
assertSyntaxError("function f(){ try{} catch(e){ let e; } }", "SCP-L-009: let duplicates catch binding");

// SCP-L-010 duplicate let in switch without inner blocks
assertSyntaxError(
    "function f(){ switch(1){ case 0: let x; break; case 1: let x; break; } }",
    "SCP-L-010: duplicate let in switch"
);

// SCP-L-012 lexical declaration not direct child of if
assertSyntaxError("function f(){ if (true) let x = 1; }", "SCP-L-012: if without block let");
assertSyntaxError("function f(){ if (true) const x = 1; }", "SCP-C-007: if without block const");

// SCP-C-002 missing initializer
assertSyntaxError("function f(){ const c; }", "SCP-C-002: const without initializer");

// SCP-C-006 inner var vs outer const (same scope)
assertSyntaxError(
    "function f(){ const MY = 7; if (true) { var MY = 8; } }",
    "SCP-C-006: var inner block merges with outer const"
);

// SCP-FN-005 function in catch same as binding
assertSyntaxError("function f(){ try{} catch(e){ function e(){} } }", "SCP-FN-005: function named like catch binding");

// SCP-TC-002 destructuring catch + duplicate let
assertSyntaxError(
    "function f(){ try{} catch({name,message}){ let name; } }",
    "SCP-TC-002: let duplicates catch destructure binding"
);

// SCP-TC-005 try without block braces
assertSyntaxError("function f(){ try 1 catch(e){} }", "SCP-TC-005: try requires block");

__jacDone();
