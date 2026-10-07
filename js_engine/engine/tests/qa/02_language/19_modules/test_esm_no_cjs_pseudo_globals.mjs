// testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NCJS-CTX-* (ESM)
function assert(cond, msg) {
    if (!cond) {
        console.error("FAIL: " + msg);
        process.exit(1);
    }
}
function assertRef(label, fn) {
    var ok = false;
    try {
        fn();
    } catch (e) {
        if (e && (e instanceof ReferenceError || e.name === "ReferenceError")) {
            ok = true;
        }
    }
    if (!ok) {
        console.error("FAIL: " + label + ": expected ReferenceError");
        process.exit(1);
    }
}

// NCJS-CTX-001
assertRef("NCJS-CTX-001: require", function () {
    return require;
});

// NCJS-CTX-002
assertRef("NCJS-CTX-002: module", function () {
    return module;
});
assertRef("NCJS-CTX-002: exports", function () {
    return exports;
});

// NCJS-CTX-003
assertRef("NCJS-CTX-003: __dirname", function () {
    return __dirname;
});
assertRef("NCJS-CTX-003: __filename", function () {
    return __filename;
});
assert(typeof import.meta.url === "string" && import.meta.url.length > 0, "NCJS-CTX-003: import.meta.url is string");

// NCJS-CTX-004
assert(typeof globalThis.require === "undefined", "NCJS-CTX-004: globalThis.require is undefined");
assert(typeof globalThis.module === "undefined", "NCJS-CTX-004: globalThis.module is undefined");
assert(typeof globalThis.exports === "undefined", "NCJS-CTX-004: globalThis.exports is undefined");

console.log("ok esm no cjs pseudo globals (NCJS-CTX-*)");
