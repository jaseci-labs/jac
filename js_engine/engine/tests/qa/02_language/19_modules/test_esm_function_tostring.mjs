// MOD-FNSRC-001: Function.prototype.toString() on a user function defined inside
// an ESM module returns the real source text, not "[native code]". Regression:
// the ESM load path never set the compiler's source_text, so no function in an
// ESM module could reconstruct its source — vite's modulepreload polyfill does
// `${polyfill.toString()}` and emitted `function polyfill() { [native code] }`,
// producing invalid generated JS.

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}

function polyfill() {
    const marker = 12345;
    return marker;
}

const src = polyfill.toString();
assert(src.indexOf("[native code]") === -1, "MOD-FNSRC-001: no [native code] for a user fn in ESM");
assert(src.indexOf("marker") !== -1 && src.indexOf("12345") !== -1, "MOD-FNSRC-001: real body preserved");

// Interpolated form (the exact vite pattern) must also be real source.
const interp = `(${polyfill.toString()}())`;
assert(interp.indexOf("[native code]") === -1, "MOD-FNSRC-001: interpolated toString is real source");

// Arrow functions too.
const arrow = (x) => x + 1;
assert(arrow.toString().indexOf("=>") !== -1, "MOD-FNSRC-001: arrow toString preserved");

process.exit(0);
