// MOD-ISH-001: a function parameter / local / captured binding that shares a
// name with an ESM import must SHADOW the import (ES §8.2.1 — the module
// environment is the outermost scope). Regression: the bytecode compiler
// resolved import bindings before params/locals, so `new Promise((resolve) =>
// …)` under `import { resolve } from 'node:path'` invoked path.resolve — the
// root cause of `vite build` hanging with "Unexpected early exit".
import { resolve } from "node:path";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, b, msg) {
    if (a !== b) { console.error("FAIL: " + msg + " | expected " + JSON.stringify(b) + " got " + JSON.stringify(a)); process.exit(1); }
}

// A: a same-named PARAMETER shadows the import.
assertEq((function (resolve) { return resolve; })(42), 42, "MOD-ISH-001: param shadows import");

// B: the promise-executor case that broke vite — `resolve` is the executor's
// resolve fn, NOT path.resolve.
var pval = null;
var p = new Promise(function (resolve) { resolve("ok"); });
p.then(function (v) {
    pval = v;

    // C: a captured enclosing-function local shadows the import.
    function outer() { var resolve = function () { return "captured"; }; return function () { return resolve(); }; }
    assertEq(outer()(), "captured", "MOD-ISH-001: captured local shadows import");

    // D: assigning to a shadowing param is an ordinary write (not the bogus
    // "Assignment to import binding" TypeError).
    assertEq((function (resolve) { resolve = "reassigned"; return resolve; })(1), "reassigned",
             "MOD-ISH-001: assign to shadowing param is allowed");

    // E: the UNSHADOWED import still refers to path.resolve.
    assert(typeof resolve === "function", "MOD-ISH-001: unshadowed import is a function");
    assert(resolve("/a", "b").indexOf("/a") === 0, "MOD-ISH-001: unshadowed import is path.resolve");

    assertEq(pval, "ok", "MOD-ISH-001: shadowing executor resolve settled the promise");
    process.exit(0);
});
