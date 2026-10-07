// EPG: a module-level `var` may legitimately bind a CJS pseudo-global name —
// Rollup emits `var exports = {…}` when inlining a package.json — and the
// binding must resolve instead of tripping the "not defined in ES module
// scope" guard. Prints FAIL: lines on error; "EPG-DECLARED OK" on success.
var exports = { a: 1 };
var pkg = { name: "x", exports: exports };
if (pkg.exports.a !== 1) console.log("FAIL: declared var exports did not resolve");
var module = { id: "m1" };
if (module.id !== "m1") console.log("FAIL: declared var module did not resolve");
console.log("EPG-DECLARED OK");
