// TA-BIG-001..006: typed-array / Buffer operations on stores >= 128KB
// (mmap-backed allocations). Regression: the native compiler released the
// DISCARDED pointer result of memcpy/memmove/memset as if it were an owned
// object; the refcount probe read the header before the buffer and SIGSEGV'd
// for mmap-backed stores — Uint8Array.copyWithin on 256KB crashed, and with it
// esbuild's stdout reader on replies over 128KB.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_typed_arrays/test_typed_array_large_buffers.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }

[256, 1024, 4096].forEach(function (kb) {
    var n = kb * 1024;
    var a = new Uint8Array(n); for (var i = 0; i < n; i += 4096) a[i] = (i >> 12) & 255; a[n / 2] = 7;
    a.copyWithin(0, n / 2, n);
    assert(a[0] === 7 && a[4096] === ((n / 2 + 4096) >> 12 & 255), "TA-BIG-001: copyWithin " + kb + "KB (non-overlapping)");
    a.copyWithin(10, 0, n - 10);
    assert(a[10] === 7, "TA-BIG-002: overlapping copyWithin " + kb + "KB");
    var b = new Uint8Array(n * 2); b.set(a); b.set(a, n);
    assert(b[10] === 7 && b[n + 10] === 7, "TA-BIG-003: set/set@offset " + kb + "KB");
    var s = b.subarray(1000, n + 1000);
    assert(s.length === n && s[n - 990] === 7, "TA-BIG-004: subarray view " + kb + "KB");
    var buf = Buffer.alloc(n); Buffer.from(a.buffer, 0, n).copy(buf, 0, 0, n);
    assert(buf[10] === 7 && buf.equals(Buffer.from(a)), "TA-BIG-005: Buffer.copy/equals " + kb + "KB");
    var b64 = Buffer.from(a).toString("base64"); var back = Buffer.from(b64, "base64");
    assert(back.length === n && back.equals(Buffer.from(a)), "TA-BIG-006: base64 round trip " + kb + "KB");
});
var fu = new Uint8Array(400000); fu.fill(65, 100, 300100); fu.fill(-1, 300100, 300101); fu.fill(300.7, 300101, 300102);
assert(fu[99] === 0 && fu[100] === 65 && fu[300099] === 65 && fu[300100] === 255 && fu[300101] === 44 && fu[300102] === 0, "TA-BIG-007: Uint8Array.fill range + ToUint8 wrap (memset fast path)");
var fi = new Int8Array(1000); fi.fill(200); assert(fi[0] === -56 && fi[999] === -56, "TA-BIG-007: Int8Array.fill ToInt8 wrap");
var fc = new Uint8ClampedArray(10); fc.fill(300); assert(fc[0] === 255, "TA-BIG-007: Uint8ClampedArray.fill clamps (slow path)");
var cat = Buffer.concat([Buffer.alloc(300000, 1), Buffer.alloc(300000, 2)]);
assert(cat.length === 600000 && cat[299999] === 1 && cat[300000] === 2, "TA-BIG-006: Buffer.concat 600KB");
assert(new TextDecoder().decode(new Uint8Array(Buffer.alloc(1000000, 65).buffer, 0, 1000000).subarray(0, 700000)).length === 700000, "TA-BIG-006: TextDecoder on a 700KB view");
__jacDone();
