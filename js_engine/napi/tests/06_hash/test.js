// Test: 06_hash — FNV-1a32 and djb2 string hash functions
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

// FNV-1a32 known values (computed against reference implementation)
// empty string → 2166136261
assert(m.fnv1a32('') === 2166136261, 'fnv1a32("") = 2166136261');
// "a" → 0xe40c292c = 3826002220
assert(m.fnv1a32('a') === 3826002220, 'fnv1a32("a") = 3826002220');
// "foobar" → 0xbf9cf968 = 3214735720
assert(m.fnv1a32('foobar') === 3214735720, 'fnv1a32("foobar") = 3214735720');

// djb2 known values
// "" → 5381
assert(m.djb2('') === 5381, 'djb2("") = 5381');
// "a" → 5381*33 + 97 = 177670
assert(m.djb2('a') === 177670, 'djb2("a") = 177670');

// Both hashes should return numbers (uint32 range)
var h1 = m.fnv1a32('hello world');
var h2 = m.djb2('hello world');
assert(typeof h1 === 'number', 'fnv1a32 returns number');
assert(typeof h2 === 'number', 'djb2 returns number');
assert(h1 >= 0 && h1 <= 4294967295, 'fnv1a32 in uint32 range');
assert(h2 >= 0 && h2 <= 4294967295, 'djb2 in uint32 range');

// Determinism: same input → same output
assert(m.fnv1a32('jaseci') === m.fnv1a32('jaseci'), 'fnv1a32 deterministic');
assert(m.djb2('jaseci') === m.djb2('jaseci'), 'djb2 deterministic');

// Collision sensitivity: 'abc' and 'cba' should differ
assert(m.fnv1a32('abc') !== m.fnv1a32('cba'), 'fnv1a32 sensitive to order');
assert(m.djb2('abc') !== m.djb2('cba'), 'djb2 sensitive to order');

console.log('OK: 06_hash');
