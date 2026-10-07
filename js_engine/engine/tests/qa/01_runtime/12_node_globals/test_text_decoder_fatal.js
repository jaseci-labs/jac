// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-T-003 (TextDecoder fatal mode)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_text_decoder_fatal.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

if (typeof TextDecoder === "undefined") {
    console.log("skip NGL-T-003: TextDecoder not available");
    __jacDone();
} else {
    var fatal = new TextDecoder("utf-8", { fatal: true });
    assertThrows(
        function () {
            fatal.decode(new Uint8Array([0xff, 0xfe, 0xfd]));
        },
        TypeError,
        "NGL-T-003: fatal decode on invalid UTF-8 throws TypeError"
    );
    __jacDone();
}
