// Binary type tests — js_engine engine
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── 1: ArrayBuffer(16).byteLength ─────────────────────────────────────────
var ab1 = new ArrayBuffer(16);
check(1, "ArrayBuffer(16).byteLength === 16", ab1.byteLength, 16);

// ── 2: ArrayBuffer(0).byteLength ──────────────────────────────────────────
var ab2 = new ArrayBuffer(0);
check(2, "ArrayBuffer(0).byteLength === 0", ab2.byteLength, 0);

// ── 3: ArrayBuffer.isView(Uint8Array) ─────────────────────────────────────
check(3, "isView(Uint8Array) === true", ArrayBuffer.isView(new Uint8Array(1)), true);

// ── 4: ArrayBuffer.isView({}) ─────────────────────────────────────────────
check(4, "isView({}) === false", ArrayBuffer.isView({}), false);

// ── 5: ArrayBuffer.slice byteLength ───────────────────────────────────────
var abSlice = new ArrayBuffer(8);
var abSliceView = new Uint8Array(abSlice);
abSliceView[0] = 10; abSliceView[1] = 20; abSliceView[2] = 30;
abSliceView[3] = 40; abSliceView[4] = 50;
var abSliced = abSlice.slice(1, 4);
check(5, "slice(1,4).byteLength === 3", abSliced.byteLength, 3);

// ── 6: ArrayBuffer.slice copies bytes ─────────────────────────────────────
var abSlicedView = new Uint8Array(abSliced);
check(6, "slice copies bytes [0] === 20", abSlicedView[0], 20);

// ── 7: ArrayBuffer.slice end byte ─────────────────────────────────────────
check(7, "slice end byte [2] === 40", abSlicedView[2], 40);

// ── 8: Uint8Array length ──────────────────────────────────────────────────
var u8 = new Uint8Array(4);
check(8, "Uint8Array(4).length === 4", u8.length, 4);

// ── 9: Uint8Array byteLength ──────────────────────────────────────────────
check(9, "Uint8Array(4).byteLength === 4", u8.byteLength, 4);

// ── 10: Uint8Array initial value ──────────────────────────────────────────
check(10, "Uint8Array initial [0] === 0", u8[0], 0);

// ── 11: Uint8Array write/read 255 ─────────────────────────────────────────
u8[0] = 255; u8[1] = 128; u8[2] = 0; u8[3] = 42;
check(11, "write/read 255", u8[0], 255);

// ── 12: Uint8Array write/read 128 ─────────────────────────────────────────
check(12, "write/read 128", u8[1], 128);

// ── 13: Uint8Array write/read 42 ──────────────────────────────────────────
check(13, "write/read 42", u8[3], 42);

// ── 14: Uint8Array from array length ──────────────────────────────────────
var u8arr = new Uint8Array([10, 20, 30]);
check(14, "from array length === 3", u8arr.length, 3);

// ── 15: Uint8Array from array [0] ─────────────────────────────────────────
check(15, "from array [0] === 10", u8arr[0], 10);

// ── 16: Uint8Array from array [2] ─────────────────────────────────────────
check(16, "from array [2] === 30", u8arr[2], 30);

// ── 17: Uint8Array .buffer reference ──────────────────────────────────────
var abBacking = new ArrayBuffer(8);
var u8view = new Uint8Array(abBacking);
check(17, ".buffer references same ArrayBuffer", u8view.buffer === abBacking, true);

// ── 18: Uint8Array byteOffset ─────────────────────────────────────────────
check(18, "byteOffset === 0", u8view.byteOffset, 0);

// ── 19: Uint8Array partial view length ────────────────────────────────────
var u8partial = new Uint8Array(abBacking, 2, 4);
check(19, "partial view length === 4", u8partial.length, 4);

// ── 20: Uint8Array partial view byteOffset ────────────────────────────────
check(20, "partial view byteOffset === 2", u8partial.byteOffset, 2);

// ── 21: Uint8Array partial view shares buffer ─────────────────────────────
check(21, "partial view shares buffer", u8partial.buffer === abBacking, true);

// ── 22: Uint8Array shared backing store ───────────────────────────────────
u8view[3] = 99;
check(22, "shared backing store write-through", u8partial[1], 99);

// ── 23: Uint8Array subarray length ────────────────────────────────────────
var u8sub = u8arr.subarray(1, 3);
check(23, "subarray length === 2", u8sub.length, 2);

// ── 24: Uint8Array subarray [0] ───────────────────────────────────────────
check(24, "subarray[0] === 20", u8sub[0], 20);

// ── 25: Uint8Array subarray [1] ───────────────────────────────────────────
check(25, "subarray[1] === 30", u8sub[1], 30);

// ── 26: Uint8Array subarray shares buffer ─────────────────────────────────
check(26, "subarray shares buffer", u8sub.buffer === u8arr.buffer, true);

// ── 27: Uint8Array slice length ───────────────────────────────────────────
var u8sliced = u8arr.slice(0, 2);
check(27, "slice length === 2", u8sliced.length, 2);

// ── 28: Uint8Array slice [0] ──────────────────────────────────────────────
check(28, "slice[0] === 10", u8sliced[0], 10);

// ── 29: Uint8Array slice is independent copy ──────────────────────────────
u8sliced[0] = 99;
check(29, "slice is independent copy", u8arr[0], 10);

// ── 30: Uint8Array set offset [0] unchanged ───────────────────────────────
var u8target = new Uint8Array(5);
u8target.set([1, 2, 3], 1);
check(30, "set offset: [0] unchanged", u8target[0], 0);

// ── 31: Uint8Array set offset [1] ─────────────────────────────────────────
check(31, "set offset: [1] === 1", u8target[1], 1);

// ── 32: Uint8Array set offset [3] ─────────────────────────────────────────
check(32, "set offset: [3] === 3", u8target[3], 3);

// ── 33: Uint8Array iterator count ─────────────────────────────────────────
var u8iter = new Uint8Array([10, 20, 30]);
var iterResult = [];
for (var b of u8iter) { iterResult.push(b); }
check(33, "iterator yields 3 values", iterResult.length, 3);

// ── 34: Uint8Array iterator values ────────────────────────────────────────
check(34, "iterator values correct", iterResult[0] === 10 && iterResult[1] === 20 && iterResult[2] === 30, true);

// ── 35: Uint8Array BYTES_PER_ELEMENT ──────────────────────────────────────
check(35, "Uint8Array.BYTES_PER_ELEMENT === 1", Uint8Array.BYTES_PER_ELEMENT, 1);

// ── 36: Uint8Array fill ───────────────────────────────────────────────────
var u8fill = new Uint8Array(4);
u8fill.fill(42);
check(36, "fill(42) works", u8fill[0] === 42 && u8fill[3] === 42, true);

// ── 37: Int8Array 127 stays 127 ───────────────────────────────────────────
var i8 = new Int8Array([127, 128, 255, 0]);
check(37, "Int8: 127 stays 127", i8[0], 127);

// ── 38: Int8Array 128 becomes -128 ────────────────────────────────────────
check(38, "Int8: 128 becomes -128", i8[1], -128);

// ── 39: Int8Array 255 becomes -1 ──────────────────────────────────────────
check(39, "Int8: 255 becomes -1", i8[2], -1);

// ── 40: Int8Array 0 stays 0 ───────────────────────────────────────────────
check(40, "Int8: 0 stays 0", i8[3], 0);

// ── 41: Int8Array BYTES_PER_ELEMENT ───────────────────────────────────────
check(41, "Int8Array.BYTES_PER_ELEMENT === 1", Int8Array.BYTES_PER_ELEMENT, 1);

// ── 42: Uint16Array write/read 0xABCD ─────────────────────────────────────
var u16 = new Uint16Array(2);
u16[0] = 0xABCD; u16[1] = 0xFFFF;
check(42, "Uint16 write/read 0xABCD", u16[0], 0xABCD);

// ── 43: Uint16Array write/read 0xFFFF ─────────────────────────────────────
check(43, "Uint16 write/read 0xFFFF", u16[1], 0xFFFF);

// ── 44: Uint16Array byteLength ────────────────────────────────────────────
check(44, "Uint16 byteLength === 4", u16.byteLength, 4);

// ── 45: Uint16Array BYTES_PER_ELEMENT ─────────────────────────────────────
check(45, "Uint16Array.BYTES_PER_ELEMENT === 2", Uint16Array.BYTES_PER_ELEMENT, 2);

// ── 46: Int16Array 32767 stays positive ───────────────────────────────────
var i16 = new Int16Array([32767, 32768, 65535]);
check(46, "Int16: 32767 stays positive", i16[0], 32767);

// ── 47: Int16Array 32768 becomes -32768 ───────────────────────────────────
check(47, "Int16: 32768 becomes -32768", i16[1], -32768);

// ── 48: Int16Array 65535 becomes -1 ───────────────────────────────────────
check(48, "Int16: 65535 becomes -1", i16[2], -1);

// ── 49: Uint32Array write/read 0x12345678 ─────────────────────────────────
var u32 = new Uint32Array(2);
u32[0] = 0x12345678; u32[1] = 0xFFFFFFFF;
check(49, "Uint32 write/read 0x12345678", u32[0], 0x12345678);

// ── 50: Uint32Array write/read 0xFFFFFFFF ─────────────────────────────────
check(50, "Uint32 write/read 0xFFFFFFFF", u32[1], 0xFFFFFFFF);

// ── 51: Uint32Array byteLength ────────────────────────────────────────────
check(51, "Uint32 byteLength === 8", u32.byteLength, 8);

// ── 52: Uint32Array BYTES_PER_ELEMENT ─────────────────────────────────────
check(52, "Uint32Array.BYTES_PER_ELEMENT === 4", Uint32Array.BYTES_PER_ELEMENT, 4);

// ── 53: Int32Array max stays positive ─────────────────────────────────────
var i32 = new Int32Array([2147483647, 2147483648]);
check(53, "Int32: max stays positive", i32[0], 2147483647);

// ── 54: Int32Array overflow wraps ─────────────────────────────────────────
check(54, "Int32: overflow wraps to -2147483648", i32[1], -2147483648);

// ── 55: DataView buffer reference ─────────────────────────────────────────
var dvBuf = new ArrayBuffer(16);
var dv = new DataView(dvBuf);
check(55, "DataView buffer reference", dv.buffer === dvBuf, true);

// ── 56: DataView byteOffset ───────────────────────────────────────────────
check(56, "DataView byteOffset === 0", dv.byteOffset, 0);

// ── 57: DataView byteLength ───────────────────────────────────────────────
check(57, "DataView byteLength === 16", dv.byteLength, 16);

// ── 58: DataView setUint8/getUint8 ────────────────────────────────────────
dv.setUint8(0, 0xAB);
check(58, "setUint8/getUint8 0xAB", dv.getUint8(0), 0xAB);

// ── 59: DataView setInt8/getInt8 negative ─────────────────────────────────
dv.setInt8(1, -42);
check(59, "setInt8/getInt8 -42", dv.getInt8(1), -42);

// ── 60: DataView Uint16 big-endian round-trip ─────────────────────────────
dv.setUint16(2, 0x1234);
check(60, "Uint16 BE round-trip", dv.getUint16(2), 0x1234);

// ── 61: DataView Uint16 BE MSB at lower offset ───────────────────────────
check(61, "Uint16 BE: MSB at lower offset", dv.getUint8(2), 0x12);

// ── 62: DataView Uint16 BE LSB at higher offset ──────────────────────────
check(62, "Uint16 BE: LSB at higher offset", dv.getUint8(3), 0x34);

// ── 63: DataView Uint16 little-endian round-trip ──────────────────────────
dv.setUint16(4, 0x5678, true);
check(63, "Uint16 LE round-trip", dv.getUint16(4, true), 0x5678);

// ── 64: DataView Uint16 LE LSB at lower offset ───────────────────────────
check(64, "Uint16 LE: LSB at lower offset", dv.getUint8(4), 0x78);

// ── 65: DataView Uint16 LE MSB at higher offset ──────────────────────────
check(65, "Uint16 LE: MSB at higher offset", dv.getUint8(5), 0x56);

// ── 66: DataView Uint32 BE round-trip ─────────────────────────────────────
dv.setUint32(8, 0x12345678);
check(66, "Uint32 BE round-trip", dv.getUint32(8), 0x12345678);

// ── 67: DataView Uint32 BE first byte ─────────────────────────────────────
check(67, "Uint32 BE: first byte", dv.getUint8(8), 0x12);

// ── 68: DataView Int32 LE -1 round-trip ───────────────────────────────────
dv.setInt32(12, -1, true);
check(68, "Int32 LE: -1 round-trip", dv.getInt32(12, true), -1);

// ── 69: DataView Int32 LE -1 all bytes 0xFF ───────────────────────────────
check(69, "Int32 LE -1: all bytes 0xFF", dv.getUint8(12), 0xFF);

// ── 70: DataView with offset byteOffset ───────────────────────────────────
var dv2 = new DataView(dvBuf, 4, 8);
check(70, "offset DataView byteOffset === 4", dv2.byteOffset, 4);

// ── 71: DataView with offset byteLength ───────────────────────────────────
check(71, "offset DataView byteLength === 8", dv2.byteLength, 8);

// ── 72: Float32Array 1.5 round-trips ──────────────────────────────────────
var f32 = new Float32Array(2);
f32[0] = 1.5; f32[1] = -3.14;
check(72, "Float32 1.5 round-trips exactly", f32[0], 1.5);

// ── 73: Float32Array -3.14 within tolerance ───────────────────────────────
check(73, "Float32 -3.14 within tolerance", Math.abs(f32[1] - (-3.14)) < 0.001, true);

// ── 74: Float32Array BYTES_PER_ELEMENT ────────────────────────────────────
check(74, "Float32Array.BYTES_PER_ELEMENT === 4", Float32Array.BYTES_PER_ELEMENT, 4);

// ── 75: Float64Array Math.PI round-trips ──────────────────────────────────
var f64 = new Float64Array(2);
f64[0] = Math.PI; f64[1] = -1.23456789012345;
check(75, "Float64 Math.PI round-trips exactly", f64[0], Math.PI);

// ── 76: Float64Array negative double round-trips ──────────────────────────
check(76, "Float64 negative double round-trips", f64[1], -1.23456789012345);

// ── 77: Float64Array BYTES_PER_ELEMENT ────────────────────────────────────
check(77, "Float64Array.BYTES_PER_ELEMENT === 8", Float64Array.BYTES_PER_ELEMENT, 8);

// ── 78: DataView Float32 LE round-trip ────────────────────────────────────
var dvFloat = new ArrayBuffer(16);
var dvf = new DataView(dvFloat);
dvf.setFloat32(0, 1.5, true);
check(78, "Float32 LE round-trip", dvf.getFloat32(0, true), 1.5);

// ── 79: DataView Float32 BE round-trip ────────────────────────────────────
dvf.setFloat32(4, -42.5);
check(79, "Float32 BE round-trip", dvf.getFloat32(4), -42.5);

// ── 80: DataView Float64 LE Math.PI round-trip ────────────────────────────
dvf.setFloat64(8, Math.PI, true);
check(80, "Float64 LE Math.PI round-trip", dvf.getFloat64(8, true), Math.PI);

// ── 81: Cross-type U8 write → DV read LE ─────────────────────────────────
var interopBuf = new ArrayBuffer(4);
var interopU8 = new Uint8Array(interopBuf);
interopU8[0] = 0x78; interopU8[1] = 0x56; interopU8[2] = 0x34; interopU8[3] = 0x12;
var interopDV = new DataView(interopBuf);
check(81, "U8 write → DV read LE === 0x12345678", interopDV.getUint32(0, true), 0x12345678);

// ── 82: Cross-type U8 write → DV read BE ─────────────────────────────────
check(82, "U8 write → DV read BE === 0x78563412", interopDV.getUint32(0, false), 0x78563412);

// ── 83: Cross-type DV write LE → U16 read [0] ────────────────────────────
var interopBuf2 = new ArrayBuffer(4);
var interopDV2 = new DataView(interopBuf2);
interopDV2.setUint16(0, 0xAABB, true);
interopDV2.setUint16(2, 0xCCDD, true);
var interopU16 = new Uint16Array(interopBuf2);
check(83, "DV write LE → U16 read [0]", interopU16[0], 0xAABB);

// ── 84: Cross-type DV write LE → U16 read [1] ────────────────────────────
check(84, "DV write LE → U16 read [1]", interopU16[1], 0xCCDD);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Binary type tests: " + _passed + " passed, " + _failed + " failed ===");
