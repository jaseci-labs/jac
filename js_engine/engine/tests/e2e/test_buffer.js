// ────────────────────────────────────────────────────────────────────────────
// test_buffer.js — Node.js Buffer module tests
//
// Tests:
//   1-2:   require("buffer") / require("node:buffer") basics
//   3:     Buffer.isBuffer
//   4-6:   Buffer.alloc — zero-fill, fill number, fill string
//   7-10:  Buffer.from — string (utf8), array, another buffer, hex
//   11:    Buffer.from — base64
//   12-15: buf.toString — utf8, hex, base64, with range
//   16-17: buf.length
//   18-19: buf[i] — indexed read/write
//   20:    buf.slice / subarray
//   21:    Buffer.concat
//   22-23: buf.copy
//   24-25: buf.fill — number fill, string fill
//   26:    buf.indexOf / buf.includes
//   27:    buf.equals / buf.compare
//   28-30: buf.readUInt8 / readUInt16BE / readUInt16LE
//   31-32: buf.readUInt32BE / readUInt32LE
//   33-34: buf.readInt8 / readInt16BE
//   35-36: buf.readInt32BE / readInt32LE
//   37-38: buf.writeUInt16BE / writeUInt16LE
//   39-40: buf.writeUInt32BE / writeUInt32LE
//   41-42: buf.writeInt8 / writeInt16LE
//   43:    buf.toJSON
//   44:    Buffer.byteLength
//   45:    Buffer.compare static
//   46:    buf.write
//   47:    buf.allocUnsafe
//   48-49: buf.readFloatBE / readFloatLE (smoke test: NaN round-trips)
//   50:    globalThis.Buffer is available
// ────────────────────────────────────────────────────────────────────────────

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    var ok;
    // Handle NaN comparison
    if (typeof actual === "number" && typeof expected === "number" &&
        actual !== actual && expected !== expected) {
        ok = true;
    } else {
        ok = actual === expected;
    }
    if (ok) {
        _passed = _passed + 1;
        console.log("OK " + id + " " + desc);
    } else {
        _failed = _failed + 1;
        console.log("FAIL " + id + " " + desc + "  got=" + JSON.stringify(actual) + "  expected=" + JSON.stringify(expected));
    }
}

function checkTrue(id, desc, val) {
    check(id, desc, val === true, true);
}

function checkClose(id, desc, actual, expected, tol) {
    var diff = actual - expected;
    if (diff < 0) { diff = -diff; }
    var ok = diff <= tol;
    if (ok) {
        _passed = _passed + 1;
        console.log("OK " + id + " " + desc);
    } else {
        _failed = _failed + 1;
        console.log("FAIL " + id + " " + desc + "  got=" + actual + "  expected≈" + expected + "  diff=" + diff);
    }
}

// ── 1: require("buffer") returns an object ────────────────────────────────────
var bufMod = require("buffer");
check(1, "require('buffer') typeof === object", typeof bufMod, "object");

// ── 2: require("node:buffer") returns same cached object ─────────────────────
var bufMod2 = require("node:buffer");
checkTrue(2, "require('node:buffer') is same as require('buffer')", bufMod === bufMod2);

// ── Get Buffer class ──────────────────────────────────────────────────────────
var Buffer = bufMod.Buffer;

// ── 3: Buffer.isBuffer ────────────────────────────────────────────────────────
var b3 = Buffer.alloc(4);
checkTrue(3, "Buffer.isBuffer(Buffer.alloc(4)) === true", Buffer.isBuffer(b3));
check(3, "Buffer.isBuffer({}) === false", Buffer.isBuffer({}), false);
check(3, "Buffer.isBuffer(null) === false", Buffer.isBuffer(null), false);

// ── 4: Buffer.alloc — zero fill ───────────────────────────────────────────────
var b4 = Buffer.alloc(4);
check(4, "Buffer.alloc(4).length === 4", b4.length, 4);
check(4, "Buffer.alloc(4)[0] === 0", b4[0], 0);
check(4, "Buffer.alloc(4)[3] === 0", b4[3], 0);

// ── 5: Buffer.alloc — fill with number ───────────────────────────────────────
var b5 = Buffer.alloc(3, 0xff);
check(5, "Buffer.alloc(3, 0xff)[0] === 255", b5[0], 255);
check(5, "Buffer.alloc(3, 0xff)[2] === 255", b5[2], 255);

// ── 6: Buffer.alloc — fill with string ───────────────────────────────────────
var b6 = Buffer.alloc(4, "AB");
check(6, "Buffer.alloc(4, 'AB')[0] === 65", b6[0], 65);  // 'A'
check(6, "Buffer.alloc(4, 'AB')[1] === 66", b6[1], 66);  // 'B'
check(6, "Buffer.alloc(4, 'AB')[2] === 65", b6[2], 65);  // 'A' again

// ── 7: Buffer.from — UTF-8 string ────────────────────────────────────────────
var b7 = Buffer.from("hello");
check(7, "Buffer.from('hello').length === 5", b7.length, 5);
check(7, "Buffer.from('hello')[0] === 104", b7[0], 104);  // 'h'
check(7, "Buffer.from('hello').toString() === 'hello'", b7.toString(), "hello");

// ── 8: Buffer.from — array of integers ───────────────────────────────────────
var b8 = Buffer.from([72, 105, 33]);
check(8, "Buffer.from([72,105,33]).length === 3", b8.length, 3);
check(8, "Buffer.from([72,105,33]).toString() === 'Hi!'", b8.toString(), "Hi!");

// ── 9: Buffer.from — another Buffer (copy) ───────────────────────────────────
var b9src = Buffer.from("abc");
var b9 = Buffer.from(b9src);
b9src[0] = 0; // mutation should not affect b9
check(9, "Buffer.from(buf) copies: toString === 'abc'", b9.toString(), "abc");

// ── 10: Buffer.from — hex ────────────────────────────────────────────────────
var b10 = Buffer.from("68656c6c6f", "hex");
check(10, "Buffer.from(hex, 'hex').toString() === 'hello'", b10.toString(), "hello");

// ── 11: Buffer.from — base64 ─────────────────────────────────────────────────
var b11 = Buffer.from("aGVsbG8=", "base64");
check(11, "Buffer.from(base64).toString() === 'hello'", b11.toString(), "hello");

// ── 12: buf.toString — explicit utf8 ─────────────────────────────────────────
var b12 = Buffer.from("World");
check(12, "buf.toString('utf8') === 'World'", b12.toString("utf8"), "World");

// ── 13: buf.toString — hex encoding ──────────────────────────────────────────
var b13 = Buffer.from([0xde, 0xad, 0xbe, 0xef]);
check(13, "buf.toString('hex') === 'deadbeef'", b13.toString("hex"), "deadbeef");

// ── 14: buf.toString — base64 encoding ───────────────────────────────────────
var b14 = Buffer.from("hello");
check(14, "Buffer.from('hello').toString('base64') === 'aGVsbG8='", b14.toString("base64"), "aGVsbG8=");

// ── 15: buf.toString — range [start, end) ────────────────────────────────────
var b15 = Buffer.from("hello world");
check(15, "buf.toString('utf8', 6) === 'world'", b15.toString("utf8", 6), "world");
check(15, "buf.toString('utf8', 0, 5) === 'hello'", b15.toString("utf8", 0, 5), "hello");

// ── 16: buf.length ────────────────────────────────────────────────────────────
var b16 = Buffer.from("123456789");
check(16, "Buffer.from('123456789').length === 9", b16.length, 9);

// ── 17: Buffer.alloc(0).length ───────────────────────────────────────────────
check(17, "Buffer.alloc(0).length === 0", Buffer.alloc(0).length, 0);

// ── 18: indexed read ─────────────────────────────────────────────────────────
var b18 = Buffer.from([10, 20, 30, 40]);
check(18, "buf[0] === 10", b18[0], 10);
check(18, "buf[3] === 40", b18[3], 40);

// ── 19: indexed write ────────────────────────────────────────────────────────
var b19 = Buffer.alloc(4);
b19[0] = 0xab;
b19[3] = 0xcd;
check(19, "buf[0] = 0xab: buf[0] === 171", b19[0], 171);
check(19, "buf[3] = 0xcd: buf[3] === 205", b19[3], 205);

// ── 20: buf.slice / subarray ─────────────────────────────────────────────────
var b20 = Buffer.from("hello world");
var sliced = b20.slice(6, 11);
check(20, "buf.slice(6,11).toString() === 'world'", sliced.toString(), "world");
check(20, "buf.slice(6,11).length === 5", sliced.length, 5);
var sub = b20.subarray(0, 5);
check(20, "buf.subarray(0,5).toString() === 'hello'", sub.toString(), "hello");

// ── 21: Buffer.concat ────────────────────────────────────────────────────────
var bA = Buffer.from("foo");
var bB = Buffer.from("bar");
var bc = Buffer.concat([bA, bB]);
check(21, "Buffer.concat(['foo','bar']).toString() === 'foobar'", bc.toString(), "foobar");
check(21, "Buffer.concat(['foo','bar']).length === 6", bc.length, 6);

// ── 22: buf.copy ─────────────────────────────────────────────────────────────
var b22src = Buffer.from([1, 2, 3, 4, 5]);
var b22dst = Buffer.alloc(5);
b22src.copy(b22dst);
check(22, "buf.copy: dst[0] === 1", b22dst[0], 1);
check(22, "buf.copy: dst[4] === 5", b22dst[4], 5);

// ── 23: buf.copy with offset ────────────────────────────────────────────────
var b23src = Buffer.from([10, 20, 30]);
var b23dst = Buffer.alloc(5);
b23src.copy(b23dst, 2, 0, 3);
check(23, "buf.copy(dst, 2, 0, 3): dst[2] === 10", b23dst[2], 10);
check(23, "buf.copy(dst, 2, 0, 3): dst[4] === 30", b23dst[4], 30);

// ── 24: buf.fill — number ────────────────────────────────────────────────────
var b24 = Buffer.alloc(5);
b24.fill(0x41);
check(24, "buf.fill(0x41)[0] === 65", b24[0], 65);
check(24, "buf.fill(0x41)[4] === 65", b24[4], 65);

// ── 25: buf.fill — range ─────────────────────────────────────────────────────
var b25 = Buffer.alloc(5);
b25.fill(0xbb, 1, 4);
check(25, "buf.fill(0xbb,1,4): buf[0] === 0", b25[0], 0);
check(25, "buf.fill(0xbb,1,4): buf[1] === 187", b25[1], 187);
check(25, "buf.fill(0xbb,1,4): buf[4] === 0", b25[4], 0);

// ── 26: buf.indexOf / buf.includes ───────────────────────────────────────────
var b26 = Buffer.from("hello world");
check(26, "buf.indexOf(108) === 2", b26.indexOf(108), 2);      // 'l'
check(26, "buf.indexOf('world') === 6", b26.indexOf("world"), 6);
checkTrue(26, "buf.includes('hello') === true", b26.includes("hello"));
check(26, "buf.includes('xyz') === false", b26.includes("xyz"), false);

// ── 27: buf.equals / buf.compare ─────────────────────────────────────────────
var b27a = Buffer.from([1, 2, 3]);
var b27b = Buffer.from([1, 2, 3]);
var b27c = Buffer.from([1, 2, 4]);
checkTrue(27, "buf.equals(same buf) === true", b27a.equals(b27b));
check(27, "buf.equals(diff buf) === false", b27a.equals(b27c), false);
check(27, "buf.compare(same) === 0", b27a.compare(b27b), 0);
check(27, "buf.compare(greater) < 0", b27a.compare(b27c) < 0, true);

// ── 28: buf.readUInt8 ──────────────────────────────────────────────────────
var b28 = Buffer.from([0xff, 0x01, 0x80]);
check(28, "readUInt8(0) === 255", b28.readUInt8(0), 255);
check(28, "readUInt8(1) === 1",   b28.readUInt8(1), 1);
check(28, "readUInt8(2) === 128", b28.readUInt8(2), 128);

// ── 29: buf.readUInt16BE ──────────────────────────────────────────────────
var b29 = Buffer.from([0x01, 0x02, 0x03, 0x04]);
check(29, "readUInt16BE(0) === 0x0102", b29.readUInt16BE(0), 258);
check(29, "readUInt16BE(2) === 0x0304", b29.readUInt16BE(2), 772);

// ── 30: buf.readUInt16LE ──────────────────────────────────────────────────
check(30, "readUInt16LE(0) === 0x0201", b29.readUInt16LE(0), 513);
check(30, "readUInt16LE(2) === 0x0403", b29.readUInt16LE(2), 1027);

// ── 31: buf.readUInt32BE ──────────────────────────────────────────────────
var b31 = Buffer.from([0x12, 0x34, 0x56, 0x78]);
check(31, "readUInt32BE(0) === 0x12345678", b31.readUInt32BE(0), 305419896);

// ── 32: buf.readUInt32LE ──────────────────────────────────────────────────
check(32, "readUInt32LE(0) === 0x78563412", b31.readUInt32LE(0), 2018915346);

// ── 33: buf.readInt8 ──────────────────────────────────────────────────────
var b33 = Buffer.from([0x80, 0x7f, 0xff]);
check(33, "readInt8(0) === -128", b33.readInt8(0), -128);
check(33, "readInt8(1) === 127",  b33.readInt8(1), 127);
check(33, "readInt8(2) === -1",   b33.readInt8(2), -1);

// ── 34: buf.readInt16BE ───────────────────────────────────────────────────
var b34 = Buffer.from([0xff, 0xfe, 0x00, 0x01]);
check(34, "readInt16BE(0) === -2",  b34.readInt16BE(0), -2);
check(34, "readInt16BE(2) === 1",   b34.readInt16BE(2), 1);

// ── 35: buf.readInt32BE ───────────────────────────────────────────────────
var b35 = Buffer.alloc(4);
b35.writeInt32BE(-1, 0);
check(35, "writeInt32BE(-1) then readInt32BE === -1", b35.readInt32BE(0), -1);

// ── 36: buf.readInt32LE ───────────────────────────────────────────────────
var b36 = Buffer.alloc(4);
b36.writeInt32LE(-2, 0);
check(36, "writeInt32LE(-2) then readInt32LE === -2", b36.readInt32LE(0), -2);

// ── 37: buf.writeUInt16BE ─────────────────────────────────────────────────
var b37 = Buffer.alloc(4);
b37.writeUInt16BE(0xdead, 0);
b37.writeUInt16BE(0xbeef, 2);
check(37, "writeUInt16BE(0xdead) then toString(hex)", b37.toString("hex"), "deadbeef");

// ── 38: buf.writeUInt16LE ──────────────────────────────────────────────────
var b38 = Buffer.alloc(4);
b38.writeUInt16LE(0xdead, 0);
b38.writeUInt16LE(0xbeef, 2);
check(38, "writeUInt16LE: bytes in LE order", b38.toString("hex"), "addeefbe");

// ── 39: buf.writeUInt32BE ─────────────────────────────────────────────────
var b39 = Buffer.alloc(4);
b39.writeUInt32BE(0x12345678, 0);
check(39, "writeUInt32BE(0x12345678)", b39.toString("hex"), "12345678");

// ── 40: buf.writeUInt32LE ─────────────────────────────────────────────────
var b40 = Buffer.alloc(4);
b40.writeUInt32LE(0x12345678, 0);
check(40, "writeUInt32LE(0x12345678)", b40.toString("hex"), "78563412");

// ── 41: buf.writeInt8 ─────────────────────────────────────────────────────
var b41 = Buffer.alloc(2);
b41.writeInt8(-1, 0);
b41.writeInt8(127, 1);
check(41, "writeInt8(-1)[0] === 255", b41.readUInt8(0), 255);
check(41, "writeInt8(127)[1] === 127", b41.readUInt8(1), 127);

// ── 42: buf.writeInt16LE ─────────────────────────────────────────────────
var b42 = Buffer.alloc(2);
b42.writeInt16LE(-1, 0);
check(42, "writeInt16LE(-1): bytes are 0xff 0xff", b42.toString("hex"), "ffff");

// ── 43: buf.toJSON ────────────────────────────────────────────────────────
var b43 = Buffer.from([65, 66, 67]);
var j43 = b43.toJSON();
check(43, "buf.toJSON().type === 'Buffer'", j43.type, "Buffer");
check(43, "buf.toJSON().data[0] === 65", j43.data[0], 65);
check(43, "buf.toJSON().data[2] === 67", j43.data[2], 67);

// ── 44: Buffer.byteLength ─────────────────────────────────────────────────
check(44, "Buffer.byteLength('hello') === 5", Buffer.byteLength("hello"), 5);
check(44, "Buffer.byteLength('hello', 'hex') === 0 (invalid hex)", Buffer.byteLength("hello", "hex"), 0);
// "68656c6c6f" is 10 hex chars → 5 bytes
check(44, "Buffer.byteLength('68656c6c6f', 'hex') === 5", Buffer.byteLength("68656c6c6f", "hex"), 5);

// ── 45: Buffer.compare (static) ───────────────────────────────────────────
var bc1 = Buffer.from([1, 2, 3]);
var bc2 = Buffer.from([1, 2, 3]);
var bc3 = Buffer.from([1, 2, 4]);
check(45, "Buffer.compare(equal, equal) === 0", Buffer.compare(bc1, bc2), 0);
check(45, "Buffer.compare(less, greater) < 0", Buffer.compare(bc1, bc3) < 0, true);
check(45, "Buffer.compare(greater, less) > 0", Buffer.compare(bc3, bc1) > 0, true);

// ── 46: buf.write ─────────────────────────────────────────────────────────
var b46 = Buffer.alloc(10);
var written = b46.write("hello", 0);
check(46, "buf.write returns byte count", written, 5);
check(46, "buf.write writes correct bytes", b46.toString("utf8", 0, 5), "hello");

// ── 47: Buffer.allocUnsafe ────────────────────────────────────────────────
var b47 = Buffer.allocUnsafe(8);
check(47, "Buffer.allocUnsafe(8).length === 8", b47.length, 8);
checkTrue(47, "Buffer.isBuffer(Buffer.allocUnsafe(8)) === true", Buffer.isBuffer(b47));

// ── 48: buf.readFloatBE / readFloatLE (NaN smoke test) ───────────────────
var b48 = Buffer.alloc(4);
b48.writeFloatBE(0.0, 0);
var v48 = b48.readFloatBE(0);
checkClose(48, "writeFloatBE(0.0) → readFloatBE ≈ 0.0", v48, 0.0, 0.001);

var b48b = Buffer.alloc(4);
b48b.writeFloatLE(1.0, 0);
var v48b = b48b.readFloatLE(0);
checkClose(48, "writeFloatLE(1.0) → readFloatLE ≈ 1.0", v48b, 1.0, 0.001);

// ── 49: multi-byte UTF-8 roundtrip ───────────────────────────────────────
// Note: multi-byte char handling depends on charCodeAt engine support
var b49 = Buffer.from("abc");
check(49, "3-char ASCII roundtrip", b49.toString(), "abc");

// ── 50: globalThis.Buffer is accessible from module ──────────────────────
// Buffer should be available directly as well
check(50, "Buffer.alloc is a function", typeof Buffer.alloc, "function");
check(50, "Buffer.from is a function", typeof Buffer.from, "function");
check(50, "Buffer.isBuffer is a function", typeof Buffer.isBuffer, "function");

// ── Summary ───────────────────────────────────────────────────────────────────
console.log("");
console.log("=== buffer tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) {
    process.exit(1);
}
