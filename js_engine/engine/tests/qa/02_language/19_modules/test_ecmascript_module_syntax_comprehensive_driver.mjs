// ECMASCRIPT_MODULE_SYNTAX_COMPREHENSIVE_TEST_PLAN.md — ASY-style ESM-* checks (driver .mjs)

function assert(cond, msg) {
    if (!cond) {
        console.error("FAIL: " + msg);
        process.exit(1);
    }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error(
            "FAIL: " +
                msg +
                " | expected: " +
                JSON.stringify(expected) +
                " | actual: " +
                JSON.stringify(actual)
        );
        process.exit(1);
    }
}

// ESM-I-005: see esm_syntax_i005_hoist_order.mjs (run separately in .sh)

import "./esm_syntax_side.mjs";
import libDef2, { counter, inc, double, C, af } from "./esm_syntax_lib.mjs";
import * as Star from "./esm_syntax_reexport_star.mjs";
import { renamedSym } from "./esm_syntax_reexport_named.mjs";
import { exposed } from "./esm_syntax_export_list.mjs";
import { aDone } from "./esm_syntax_circ_a.mjs";
import { bDone } from "./esm_syntax_circ_b.mjs";
import { afterTla } from "./esm_syntax_tla_dep.mjs";
import * as LibNs from "./esm_syntax_lib.mjs";

var g =
    typeof globalThis !== "undefined"
        ? globalThis
        : typeof global !== "undefined"
          ? global
          : null;
assert(g && g.__esm_syntax_side_runs === 1, "ESM-I-004: side-effect-only import ran once");

// ESM-X-002 / ESM-I-002 default + named
assertEq(libDef2, 99, "ESM-X-002: default export");
assertEq(LibNs.default, 99, "ESM-I-003: namespace includes default as .default");
assertEq(typeof LibNs.inc, "function", "ESM-I-003: namespace has named export");

// ESM-X-001
assertEq(double(3), 6, "ESM-X-001: export function");
var o = new C(4);
assertEq(o.n, 4, "ESM-X-001: export class");
assertEq(await af(), "af", "ESM-X-001: export async function");

// ESM-X-003
assertEq(exposed, 7, "ESM-X-003: export { internal as exposed }");

// ESM-I-001 named imports
assertEq(counter, 0, "ESM-I-001: named counter initial");
inc();
inc();
assertEq(counter, 2, "ESM-I-001: named imports share live binding");

// ESM-X-004 live bindings through re-exports
assertEq(Star.counter, 2, "ESM-X-004: export * from sees live counter");
assertEq(renamedSym, 2, "ESM-X-004: export { counter as renamedSym } tracks live");

// ESM-C-001
assertEq(aDone, 1, "ESM-C-001: circular graph completes (a)");
assertEq(bDone, 2, "ESM-C-001: circular graph completes (b)");

// ESM-A-001
assertEq(afterTla, 3, "ESM-A-001: top-level await in dependency before export");

// ESM-M-001
assert(
    typeof import.meta.url === "string" && import.meta.url.length > 0,
    "ESM-M-001: import.meta.url is non-empty string"
);

// ESM-M-002
try {
    new Function("return import.meta.url");
    assert(false, "ESM-M-002: import.meta in Function body should throw");
} catch (e) {
    assert(
        e instanceof SyntaxError,
        "ESM-M-002: import.meta in non-module function is SyntaxError"
    );
}

// ESM-I-006: import() is runtime Promise; not the same as static import hoisting
var pExpr = import("./esm_syntax_lib.mjs");
assert(pExpr instanceof Promise, "ESM-I-006: import() returns a Promise");

// ESM-D-001 / ESM-D-002 / ESM-D-003 / ESM-D-004 / ESM-A-005 / ESM-C-002 (top-level await)
const ns = await import("./esm_syntax_lib.mjs");
assertEq(ns.default, 99, "ESM-D-001: dynamic import resolves to module namespace");
assertEq(typeof ns.then, "undefined", "ESM-D-001: namespace object is not a thenable");

const nsStr = await import("./" + "esm_syntax_lib.mjs");
assertEq(nsStr.counter, 2, "ESM-D-002: computed relative specifier");

var caughtMissing = false;
await import("./esm_syntax_no_such_file_xyz.mjs").catch(function (e) {
    var m = e && e.message ? String(e.message) : "";
    caughtMissing =
        e &&
        (e.code === "ERR_MODULE_NOT_FOUND" ||
            m.indexOf("Cannot find module") !== -1 ||
            m.indexOf("not found") !== -1 ||
            m.indexOf("find module") !== -1 ||
            m.indexOf("Failed to resolve") !== -1 ||
            e.name === "TypeError");
});
assert(caughtMissing, "ESM-D-003: missing module rejects import() promise");

var caughtEval = false;
await import("./esm_syntax_throw_eval.mjs").catch(function (e) {
    caughtEval = e && e.message === "eval-throw";
});
assert(caughtEval, "ESM-C-002: throw during module evaluation rejects import()");

var par = await Promise.all([
    import("./esm_syntax_lib.mjs"),
    import("./esm_syntax_export_list.mjs")
]);
assertEq(par[0].default + par[1].exposed, 106, "ESM-A-005: Promise.all parallel await import");

assertEq(ns.default, 99, "ESM-D-004: await import() at module top-level");

if (typeof import.meta.resolve === "function") {
    var resolved = import.meta.resolve("./esm_syntax_lib.mjs");
    assert(
        typeof resolved === "string" && resolved.length > 0,
        "ESM-O-001: import.meta.resolve"
    );
}

process.exit(0);
