// MOD-015: dynamic import() returns Promise
async function main() {
    function assert(cond, msg) {
        if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
    }
    function assertEq(actual, expected, msg) {
        if (actual !== expected) {
            console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
            process.exit(1);
        }
    }

    var mod = await import("./mod_esm_lib.fixture.mjs");
    assertEq(typeof mod, "object",   "MOD-015: dynamic import returns object");
    assertEq(mod.PI, 3.14159,        "MOD-015: dynamic import named export");
    assertEq(mod.double(4), 8,       "MOD-015: dynamic import function");

    process.exit(0);
}

main().catch(function(e) {
    console.error("FAIL: dynamic import error: " + e);
    process.exit(1);
});
