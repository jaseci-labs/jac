// Test: two closures sharing a local var from an outer timer callback
setTimeout(function() {
    var shared = 0;
    setTimeout(function() { shared = 42; }, 10);
    setTimeout(function() {
        console.log("shared = " + shared);
        if (shared === 42) {
            console.log("ok 1 - closure share works");
            console.log("=== closure_share tests: 1 passed, 0 failed ===");
        } else {
            console.log("FAIL 1 - shared=" + shared);
            console.log("=== closure_share tests: 0 passed, 1 failed ===");
        }
    }, 30);
}, 10);
