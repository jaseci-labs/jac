// TYPED_ARRAYS_AND_BINARY_DATA_LANGUAGE_COMPREHENSIVE_TEST_PLAN.md — TAB-*

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_typed_arrays/test_typed_arrays_and_binary_data_language_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// Node 24+ returns undefined for indexed reads on detached views; others may throw TypeError.
function assertDetachedIndexInaccessible(getter, msg) {
    var threw = false;
    var val;
    try {
        val = getter();
    } catch (e) {
        threw = e instanceof TypeError;
    }
    if (!threw) {
        assert(val === undefined, msg + " (expected TypeError or undefined)");
    }
}

if (typeof Uint8Array === "undefined") {
    console.log("SKIP: no TypedArray support");
    __jacDone();
}

// --- §1 ArrayBuffer (TAB-B-*) ---

(function tabB001() {
    var b = new ArrayBuffer(8);
    assertEq(b.byteLength, 8, "TAB-B-001: byteLength from length");
    assertThrows(
        function () {
            new ArrayBuffer(-1);
        },
        RangeError,
        "TAB-B-001: negative length throws RangeError"
    );
    assertThrows(
        function () {
            new ArrayBuffer(Infinity);
        },
        RangeError,
        "TAB-B-001: non-finite length throws RangeError"
    );
})();

(function tabB002() {
    var b = new ArrayBuffer(4);
    new Uint8Array(b).set([10, 20, 30, 40]);
    var s = b.slice(1, 3);
    assertEq(s.byteLength, 2, "TAB-B-002: slice length");
    assertEq(new Uint8Array(s)[0], 20, "TAB-B-002: slice copies bytes");
    assertEq(new Uint8Array(s)[1], 30, "TAB-B-002: slice second byte");
    assert(s !== b, "TAB-B-002: slice is new buffer");
    if (typeof b.transfer === "function") {
        var b2 = new ArrayBuffer(2);
        new Uint8Array(b2).set([1, 2]);
        var u2 = new Uint8Array(b2);
        b2.transfer();
        assertThrows(
            function () {
                b2.slice(0, 1);
            },
            TypeError,
            "TAB-B-002: slice on detached buffer throws TypeError"
        );
        assertDetachedIndexInaccessible(
            function () {
                return u2[0];
            },
            "TAB-B-002: read typed array over detached buffer throws"
        );
    }
})();

(function tabB003() {
    if (typeof ArrayBuffer.prototype.transfer !== "function") {
        return;
    }
    var b = new ArrayBuffer(4);
    new Uint8Array(b).set([5, 6, 7, 8]);
    var b2 = b.transfer();
    assertEq(b.byteLength, 0, "TAB-B-003: original buffer detached (byteLength 0)");
    assertEq(b2.byteLength, 4, "TAB-B-003: transferred buffer length");
    assertEq(new Uint8Array(b2)[0], 5, "TAB-B-003: bytes moved");
})();

(function tabB004() {
    if (typeof ArrayBuffer.prototype.resize !== "function") {
        return;
    }
    var b = new ArrayBuffer(2, { maxByteLength: 8 });
    assertEq(b.byteLength, 2, "TAB-B-004: initial resizable length");
    b.resize(6);
    assertEq(b.byteLength, 6, "TAB-B-004: resize grows");
    b.resize(1);
    assertEq(b.byteLength, 1, "TAB-B-004: resize shrinks");
})();

(function tabB005() {
    assertEq(ArrayBuffer.isView(new Uint8Array(1)), true, "TAB-B-005: isView typed array");
    assertEq(ArrayBuffer.isView(new DataView(new ArrayBuffer(2))), true, "TAB-B-005: isView DataView");
    assertEq(ArrayBuffer.isView(new ArrayBuffer(1)), false, "TAB-B-005: isView false for ArrayBuffer");
    assertEq(ArrayBuffer.isView([]), false, "TAB-B-005: isView false for Array");
})();

// --- §2 SharedArrayBuffer / Atomics (TAB-S-*) optional ---

(function tabS001() {
    if (typeof SharedArrayBuffer === "undefined") {
        return;
    }
    var sab = new SharedArrayBuffer(16);
    assertEq(sab.byteLength, 16, "TAB-S-001: SharedArrayBuffer byteLength");
})();

(function tabS002() {
    if (typeof SharedArrayBuffer === "undefined" || typeof Atomics === "undefined") {
        return;
    }
    var sab = new SharedArrayBuffer(4);
    var ia = new Int32Array(sab);
    ia[0] = 7;
    assertEq(Atomics.load(ia, 0), 7, "TAB-S-002: Atomics.load");
    Atomics.store(ia, 0, 9);
    assertEq(Atomics.load(ia, 0), 9, "TAB-S-002: Atomics.store");
    assertEq(Atomics.add(ia, 0, 3), 9, "TAB-S-002: Atomics.add returns old");
    assertEq(Atomics.load(ia, 0), 12, "TAB-S-002: Atomics.add result");
    assertEq(Atomics.compareExchange(ia, 0, 12, 99), 12, "TAB-S-002: compareExchange expected");
    assertEq(Atomics.load(ia, 0), 99, "TAB-S-002: compareExchange wrote");
})();

// --- §3 DataView (TAB-D-*) ---

(function tabD001() {
    var b = new ArrayBuffer(8);
    var d = new DataView(b);
    assertEq(d.byteOffset, 0, "TAB-D-001: default byteOffset");
    assertEq(d.byteLength, 8, "TAB-D-001: default byteLength");
    var d2 = new DataView(b, 2, 4);
    assertEq(d2.byteOffset, 2, "TAB-D-001: explicit byteOffset");
    assertEq(d2.byteLength, 4, "TAB-D-001: explicit byteLength");
    assertThrows(
        function () {
            new DataView(b, 10, 4);
        },
        RangeError,
        "TAB-D-001: byteOffset out of range throws RangeError"
    );
})();

(function tabD002() {
    var b = new ArrayBuffer(4);
    var d = new DataView(b);
    d.setUint32(0, 0xaabbccdd, true);
    assertEq(d.getUint32(0, true), 0xaabbccdd, "TAB-D-002: little-endian round-trip");
    assertEq(d.getUint32(0, false), 0xddccbbaa, "TAB-D-002: big-endian read differs");
})();

(function tabD003() {
    var b = new ArrayBuffer(4);
    var d = new DataView(b, 1, 2);
    d.setInt16(0, -2, true);
    assertEq(d.getInt16(0, true), -2, "TAB-D-003: unaligned offset Int16 access");
})();

// --- §4 Typed array constructors (TAB-T-*) ---

(function tabT001() {
    var z = new Uint8Array(3);
    assertEq(z[0] + z[1] + z[2], 0, "TAB-T-001: new(length) zero-filled");
    var w = new Uint8Array([256, -1, 257]);
    assertEq(w[0], 0, "TAB-T-001: uint8 overflow wraps");
    assertEq(w[1], 255, "TAB-T-001: negative clamps to uint8");
    assertEq(w[2], 1, "TAB-T-001: 257 mod 256");
    var i8 = new Int8Array([200]);
    assertEq(i8[0], -56, "TAB-T-001: int8 element conversion");
})();

(function tabT002() {
    var b = new ArrayBuffer(8);
    assertThrows(
        function () {
            new Int16Array(b, 1, 2);
        },
        RangeError,
        "TAB-T-002: misaligned byteOffset throws RangeError"
    );
})();

(function tabT003() {
    var b = new ArrayBuffer(16);
    var u = new Uint8Array(b, 4, 5);
    assertEq(u.buffer, b, "TAB-T-003: buffer accessor");
    assertEq(u.byteOffset, 4, "TAB-T-003: byteOffset");
    assertEq(u.byteLength, 5, "TAB-T-003: byteLength");
    assertEq(u.length, 5, "TAB-T-003: length elements");
    assertEq(Uint8Array.BYTES_PER_ELEMENT, 1, "TAB-T-003: BYTES_PER_ELEMENT");
    assertEq(Float64Array.BYTES_PER_ELEMENT, 8, "TAB-T-003: Float64 BYTES_PER_ELEMENT");
})();

(function tabT004() {
    if (typeof BigInt64Array === "undefined" || typeof BigInt === "undefined") {
        return;
    }
    var bi = new BigInt64Array(2);
    bi[0] = 1n;
    bi[1] = -5n;
    assertEq(bi[0], 1n, "TAB-T-004: BigInt64Array stores BigInt");
    assertThrows(
        function () {
            bi[0] = 1;
        },
        TypeError,
        "TAB-T-004: assigning Number to BigInt64Array throws TypeError"
    );
})();

// --- §5 prototype methods (TAB-M-*) ---

(function tabM001() {
    var u = new Uint8Array(4);
    u.set([9, 8], 1);
    assertEq(u[1], 9, "TAB-M-001: set from array with offset");
    assertThrows(
        function () {
            u.set([1, 2, 3, 4, 5], 2);
        },
        RangeError,
        "TAB-M-001: set overflow throws RangeError"
    );
    var src = new Uint8Array([1, 2, 3]);
    var dst = new Uint8Array(5);
    dst.set(src, 1);
    assertEq(dst[1], 1, "TAB-M-001: set from typed array");
})();

(function tabM002() {
    var u = new Uint8Array([1, 2, 3, 4]);
    var sub = u.subarray(1, 3);
    assertEq(sub.length, 2, "TAB-M-002: subarray length");
    assertEq(sub.buffer, u.buffer, "TAB-M-002: subarray shares buffer");
    sub[0] = 99;
    assertEq(u[1], 99, "TAB-M-002: mutating subarray affects base");
})();

(function tabM003() {
    var a = new Uint8Array([1, 2, 3, 4]);
    a.copyWithin(0, 2, 4);
    assertEq([a[0], a[1], a[2], a[3]].join(","), "3,4,3,4", "TAB-M-003: copyWithin");
    var f = new Uint8Array([2, 2, 2]);
    f.fill(7, 1, 3);
    assertEq(f[0] + f[1] + f[2], 2 + 7 + 7, "TAB-M-003: fill range");
    var r = new Uint8Array([1, 2, 3]);
    r.reverse();
    assertEq([r[0], r[1], r[2]].join(","), "3,2,1", "TAB-M-003: reverse");
    var s = new Uint8Array([3, 1, 2]);
    s.sort();
    assertEq(s[0], 1, "TAB-M-003: sort ascending");
})();

(function tabM004() {
    var u = new Uint8Array([10, 20, 30]);
    var sl = u.slice();
    assertEq(sl[0], 10, "TAB-M-004: slice copies values");
    assert(sl.buffer !== u.buffer, "TAB-M-004: slice uses new buffer");
})();

(function tabM005() {
    var u = new Uint8Array([7, 8, 9]);
    assertEq(u.join("-"), "7-8-9", "TAB-M-005: join");
    assertEq(u.indexOf(8), 1, "TAB-M-005: indexOf");
    assertEq(u.includes(9), true, "TAB-M-005: includes");
    assertEq(u.includes(5), false, "TAB-M-005: includes false");
})();

// --- Cross-cutting: detached read (TAB theme) ---
(function tabDetachedRead() {
    if (typeof ArrayBuffer.prototype.transfer !== "function") {
        return;
    }
    var b = new ArrayBuffer(2);
    new Uint8Array(b).set([1, 2]);
    var u = new Uint8Array(b);
    b.transfer();
    assertDetachedIndexInaccessible(
        function () {
            return u[0];
        },
        "TAB detached: indexed get on typed array over detached buffer throws TypeError"
    );
})();

// --- SameValue / float (TAB theme) ---
(function tabFloatNegZero() {
    var f = new Float64Array(1);
    f[0] = -0;
    assert(Object.is(f[0], -0), "TAB float: stores negative zero");
    f[0] = NaN;
    assert(f[0] !== f[0], "TAB float: NaN round-trip");
})();

// --- §6 iteration (TAB-I-*) ---

(function tabI001() {
    var u = new Uint8Array([5, 6, 7]);
    var acc = [];
    for (var x of u) {
        acc.push(x);
    }
    assertEq(acc.join(","), "5,6,7", "TAB-I-001: for…of yields elements");
})();

(function tabI002() {
    var u = new Uint8Array([1, 2, 3]);
    assertEq(Array.from(u).join(","), "1,2,3", "TAB-I-002: Array.from dense copy");
    var sp = [].slice.call([...u]);
    assertEq(sp.join(","), "1,2,3", "TAB-I-002: spread into array literal");
})();

__jacDone();
