// _helper_async_module_fns.js
// Separate module required by test_async_module_fns_fix.js.
// Each exported function is async and creates inner functions after one or more
// await points, exercising the cross-module async resume path.

async function asyncArrowAfterAwait(n) {
    await Promise.resolve();
    var fn = function(x) { return x * 2; };
    return fn(n);
}

async function asyncChainedAfterAwait(a, b) {
    await Promise.resolve();
    var add = function(x, y) { return x + y; };
    var mul = function(x, y) { return x * y; };
    return add(mul(a, b), a);   // a*b + a
}

async function asyncNestedAwait() {
    await Promise.resolve(1);
    await Promise.resolve(2);
    var triple = function(x) { return x * 3; };
    return triple(14);
}

module.exports = { asyncArrowAfterAwait, asyncChainedAfterAwait, asyncNestedAwait };
