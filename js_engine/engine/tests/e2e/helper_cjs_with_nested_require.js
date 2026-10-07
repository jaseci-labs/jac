// CJS module whose top-level code calls require() for a sub-dependency.
// Used to verify that nested CJS require() inside a dynamic import() target
// runs in CJS mode (not ESM mode), so the sub-dep's exports are not
// accidentally wrapped in a namespace object.
var sub = require("./helper_cjs_fn_export.js");

// Re-export the sub module's function under a known name so the test can
// check that nested require() returned the raw CJS exports (a function),
// not a namespace object.
module.exports = {
    subType: typeof sub,
    subIsFunction: typeof sub === "function",
    subLabel: sub.label,
    callSub: function(n) { return sub(n); }
};
