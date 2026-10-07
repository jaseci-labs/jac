// test_import_meta.js — Phase 1.1: import.meta (ESM)

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + String(expected));
        console.log("     actual:   " + String(actual));
        _failed = _failed + 1;
    }
}

function checkTruthy(id, desc, actual) {
    if (actual) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected truthy, got: " + String(actual));
        _failed = _failed + 1;
    }
}

// ── Group 1: import.meta object ───────────────────────────────────────────
check(1, "import.meta is an object", typeof import.meta, "object");
check(2, "import.meta.url is a string", typeof import.meta.url, "string");
checkTruthy(3, "import.meta.url starts with file://", import.meta.url.startsWith("file://"));
checkTruthy(4, "import.meta.url contains the filename", import.meta.url.includes("test_import_meta"));
check(5, "import.meta.env is object", typeof import.meta.env, "object");

// ── Group 2: property access chains ──────────────────────────────────────
var url = import.meta.url;
checkTruthy(6, "import.meta.url assigned to var is a string", typeof url === "string");
checkTruthy(7, "url.length > 0", url.length > 0);
checkTruthy(8, "url.includes works on assigned url", url.includes("file://"));

// ── Group 3: Vite's own check (the original failure case) ─────────────────
var viteCheckPassed = false;
if (!import.meta.url.includes("node_modules")) {
    viteCheckPassed = true;
}
check(9, "Vite node_modules guard passes", viteCheckPassed, true);

// ── Group 4: import.meta as expression statement ──────────────────────────
var m = import.meta;
check(10, "assigned import.meta.url matches direct", m.url, import.meta.url);

// ── Group 5: import.meta.url method calls ────────────────────────────────
checkTruthy(11, "url.slice works", import.meta.url.slice(0, 7) === "file://");
checkTruthy(12, "url.endsWith('.js')", import.meta.url.endsWith(".js"));

// ── Summary ───────────────────────────────────────────────────────────────
console.log("=== import.meta tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) { process.exit(1); }
