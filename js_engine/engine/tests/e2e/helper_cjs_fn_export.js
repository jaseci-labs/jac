// CJS module that exports a single function as module.exports.
// Used by test_cjs_esm_interop.js to verify that dynamic import()
// of a CJS-function-export module returns { default: <fn> }.
module.exports = function greet(name) {
    return "hello " + name;
};
module.exports.label = "greet";
