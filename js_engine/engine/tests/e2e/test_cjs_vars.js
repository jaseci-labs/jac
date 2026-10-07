// CJS module-scope globals tests — js_engine engine
// Covers __filename, __dirname, module, exports, require in:
//   a) the top-level entry script
//   b) a CJS module loaded via require()
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

function checkTrue(id, desc, value) {
    check(id, desc, value, true);
}

// ── 1: __filename is a string ─────────────────────────────────────────────
check(1, "typeof __filename === 'string'", typeof __filename, "string");

// ── 2: __filename is non-empty ────────────────────────────────────────────
checkTrue(2, "__filename.length > 0", __filename.length > 0);

// ── 3: __filename contains this file's name ───────────────────────────────
checkTrue(3, "__filename contains 'test_cjs_vars'",
    __filename.indexOf("test_cjs_vars") !== -1);

// ── 4: __dirname is a string ──────────────────────────────────────────────
check(4, "typeof __dirname === 'string'", typeof __dirname, "string");

// ── 5: __dirname is non-empty ─────────────────────────────────────────────
checkTrue(5, "__dirname.length > 0", __dirname.length > 0);

// ── 6: __filename starts with __dirname ───────────────────────────────────
checkTrue(6, "__filename starts with __dirname",
    __filename.indexOf(__dirname) === 0);

// ── 7: module is an object ────────────────────────────────────────────────
check(7, "typeof module === 'object'", typeof module, "object");

// ── 8: module.exports is an object ───────────────────────────────────────
check(8, "typeof module.exports === 'object'", typeof module.exports, "object");

// ── 9: exports === module.exports initially ───────────────────────────────
checkTrue(9, "exports === module.exports", exports === module.exports);

// ── 10: require is available as a function ────────────────────────────────
check(10, "typeof require === 'function'", typeof require, "function");

// ── 11: mutating exports is visible via module.exports ────────────────────
exports.sentinel = 42;
checkTrue(11, "exports.sentinel visible via module.exports",
    module.exports.sentinel === 42);

// ── 12: reassigning module.exports decouples exports ─────────────────────
var oldExports = exports;
module.exports = { replaced: true };
checkTrue(12, "module.exports reassigned", module.exports.replaced === true);
checkTrue(13, "old exports ref still has sentinel", oldExports.sentinel === 42);

// ── Required-module CJS vars ──────────────────────────────────────────────
var h = require("./helper_cjs_vars.js");

// ── 14: helper __filename is a string ────────────────────────────────────
check(14, "helper: typeof filename === 'string'", typeof h.filename, "string");

// ── 15: helper __filename contains its own file name ─────────────────────
checkTrue(15, "helper: filename contains 'helper_cjs_vars'",
    h.filename.indexOf("helper_cjs_vars") !== -1);

// ── 16: helper __filename != entry __filename ─────────────────────────────
checkTrue(16, "helper: filename !== entry __filename",
    h.filename !== __filename);

// ── 17: helper __dirname is a string ─────────────────────────────────────
check(17, "helper: typeof dirname === 'string'", typeof h.dirname, "string");

// ── 18: helper __dirname equals entry __dirname (same directory) ──────────
checkTrue(18, "helper: dirname === entry __dirname",
    h.dirname === __dirname);

// ── 19: helper module is an object ───────────────────────────────────────
check(19, "helper: typeof moduleRef === 'object'", typeof h.moduleRef, "object");

// ── 20: helper exports === helper module.exports ─────────────────────────
checkTrue(20, "helper: exportsRef === moduleRef.exports",
    h.exportsRef === h.moduleRef.exports);

// ── 21: helper exports === returned value from require() ─────────────────
checkTrue(21, "helper: exportsRef === require() result",
    h.exportsRef === h);

// ── 22: helper exports !== entry exports ─────────────────────────────────
checkTrue(22, "helper: helper exports !== entry exports (different modules)",
    h.exportsRef !== exports);

// ── 23: helper reports exports === module.exports at load time  ───────────
checkTrue(23, "helper: exports === module.exports at load time",
    h.exportsSameAsModuleExports === true);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== CJS vars tests: " + _passed + " passed, " + _failed + " failed ===");
