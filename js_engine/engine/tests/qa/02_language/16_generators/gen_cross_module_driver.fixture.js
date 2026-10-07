// Driver module for test_generator_cross_module_closures.js: steps generators that
// were created in ANOTHER module (gensync's role for Babel). Its own functions give
// its compilation unit a function table that differs from the caller's.
function helperA() { return "driver-A"; }
function helperB() { return "driver-B"; }
function helperC() { return "driver-C"; }
function helperD() { return "driver-D"; }
function drive(gen) {
    var out = [];
    var step = gen.next();
    while (!step.done) { out.push(step.value); step = gen.next(step.value); }
    out.push("ret:" + step.value);
    return out;
}
function driveApply(genFn, args) { return drive(genFn.apply(null, args)); }
module.exports = { drive: drive, driveApply: driveApply, helpers: [helperA, helperB, helperC, helperD] };
