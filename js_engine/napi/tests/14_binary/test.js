// Test: 14_binary — NAPI ops 86–97 (R1 of docs/ROLLUP_SUPPORT_PLAN.md).
// Validated against real Node first (the oracle); every assertion below is
// Node-verified behavior.
var m = require('./addon.node');

var failures = 0;
function assert(cond, msg) {
    if (!cond) { failures++; console.error('FAIL: ' + msg); }
}

// ── create_arraybuffer + shared backing store (C stamped 0..15) ─────────────
var ab = m.makeStampedAb();
assert(ab instanceof ArrayBuffer, 'create_arraybuffer returns ArrayBuffer');
assert(ab.byteLength === 16, 'byteLength 16, got ' + ab.byteLength);
var u8 = new Uint8Array(ab);
assert(u8[0] === 0 && u8[5] === 5 && u8[15] === 15,
    'JS view sees C-stamped bytes: ' + u8[0] + ',' + u8[5] + ',' + u8[15]);

// get_arraybuffer_info reads the same store
var abi = m.abInfo(ab);
assert(abi.len === 16, 'get_arraybuffer_info len, got ' + abi.len);
assert(abi.firstByte === 0, 'get_arraybuffer_info data[0], got ' + abi.firstByte);

// JS write → C read (aliasing direction 2)
u8[0] = 77;
assert(m.abInfo(ab).firstByte === 77, 'C sees JS write through shared store');

// ── external arraybuffer (zero-copy over addon malloc) ─────────────────────
var xab = m.makeExternalAb();
assert(xab instanceof ArrayBuffer, 'external ab is ArrayBuffer');
assert(xab.byteLength === 8, 'external ab byteLength 8, got ' + xab.byteLength);
var xu8 = new Uint8Array(xab);
assert(xu8[0] === 0xA0 && xu8[7] === 0xA7,
    'external ab bytes visible in JS: ' + xu8[0] + ',' + xu8[7]);

// ── typed arrays ────────────────────────────────────────────────────────────
var ta = m.makeU32Over(ab); // 4 x uint32 over the 16-byte ab
assert(ta instanceof Uint32Array, 'create_typedarray returns Uint32Array');
assert(ta.length === 4, 'ta length 4, got ' + ta.length);
assert(ta.buffer === ab, 'ta.buffer is the SAME ArrayBuffer object');

var ti = m.taInfo(ta);
assert(ti.type === 6, 'napi_uint32_array type enum 6, got ' + ti.type);
assert(ti.length === 4, 'info length 4, got ' + ti.length);
assert(ti.byteOffset === 0, 'info byteOffset 0, got ' + ti.byteOffset);
assert(ti.buffer === ab, 'info arraybuffer identity');

// info on a JS-created view with offset (rollup reads Buffer args this way)
var base = new ArrayBuffer(32);
var mid = new Uint16Array(base, 8, 4);
var mi = m.taInfo(mid);
assert(mi.type === 4, 'napi_uint16_array enum 4, got ' + mi.type);
assert(mi.length === 4, 'js view length, got ' + mi.length);
assert(mi.byteOffset === 8, 'js view byteOffset, got ' + mi.byteOffset);

// ── dataview ────────────────────────────────────────────────────────────────
var dvr = m.dvRoundtrip(base, 4, 12);
assert(dvr.isDataView === true, 'is_dataview true for created view');
assert(dvr.byteLength === 12, 'dv byteLength 12, got ' + dvr.byteLength);
assert(dvr.byteOffset === 4, 'dv byteOffset 4, got ' + dvr.byteOffset);
assert(dvr.sameBuffer === true, 'dv info returns same buffer');

// ── buffers ────────────────────────────────────────────────────────────────
var sb = m.makeStampedBuffer();
assert(Buffer.isBuffer(sb), 'create_buffer returns a real Buffer');
assert(sb.length === 8, 'buffer length 8, got ' + sb.length);
assert(sb[0] === 0x10 && sb[7] === 0x17, 'C-stamped buffer bytes visible');

var bc = m.makeBufferCopy();
assert(Buffer.isBuffer(bc), 'create_buffer_copy returns Buffer');
assert(bc.toString() === 'rollup!', 'buffer copy content, got ' + bc.toString());

var xb = m.makeExternalBuffer();
assert(Buffer.isBuffer(xb), 'create_external_buffer returns Buffer');
assert(xb.length === 12, 'external buffer length 12, got ' + xb.length);
assert(xb[0] === 0x40 && xb[11] === 0x4B, 'external buffer bytes visible');
// THE rollup pattern: Uint32Array over an external buffer's .buffer
assert(xb.buffer instanceof ArrayBuffer, 'external buffer .buffer is ArrayBuffer');
var xw = new Uint32Array(xb.buffer, xb.byteOffset, 3);
assert(xw[0] === 0x43424140, 'u32 view over external buffer LE word, got 0x' + xw[0].toString(16));

// ── get_buffer_info on JS-created buffers (xxhash input direction) ─────────
var jsb = Buffer.from([1, 2, 3, 4, 5]);
var bi = m.bufferInfo(jsb);
assert(bi.len === 5, 'get_buffer_info len, got ' + bi.len);
assert(bi.sum === 15, 'C read JS buffer bytes, sum ' + bi.sum);

// C mutation → JS observation
m.mutateBytes(jsb, 10);
assert(jsb[0] === 11 && jsb[4] === 15, 'JS sees C mutation: ' + jsb[0] + ',' + jsb[4]);

// ── predicates across all kinds ─────────────────────────────────────────────
function predStr(p) { return p.ab + ',' + p.buf + ',' + p.ta + ',' + p.dv + ',' + p.detached; }
assert(predStr(m.preds(ab)) === 'true,false,false,false,false', 'preds(ArrayBuffer): ' + predStr(m.preds(ab)));
assert(predStr(m.preds(jsb)) === 'false,true,true,false,false', 'preds(Buffer): ' + predStr(m.preds(jsb)));
assert(predStr(m.preds(new Uint8Array(4))) === 'false,true,true,false,false', 'preds(Uint8Array): ' + predStr(m.preds(new Uint8Array(4))));
// Node oracle: napi_is_buffer is IsArrayBufferView() — true for ANY
// TypedArray and for DataView, not just Uint8Array.
assert(predStr(m.preds(new Uint32Array(2))) === 'false,true,true,false,false', 'preds(Uint32Array): ' + predStr(m.preds(new Uint32Array(2))));
assert(predStr(m.preds(new DataView(new ArrayBuffer(4)))) === 'false,true,false,true,false', 'preds(DataView): ' + predStr(m.preds(new DataView(new ArrayBuffer(4)))));
assert(predStr(m.preds({})) === 'false,false,false,false,false', 'preds(plain object): ' + predStr(m.preds({})));

// ── R1.2 external-buffer finalizer: must NOT fire while the buffer is live.
// (It fires exactly once at GC or process teardown — the EXT_FINALIZED
// stderr marker after the OK line is the observational proof.)
var counted = m.makeCountedExternal();
assert(counted.length === 4, 'counted external buffer created');
assert(m.extFinalizeCount() === 0, 'finalizer not fired while buffer live, count=' + m.extFinalizeCount());

// ── detach ─────────────────────────────────────────────────────────────────
var dab = new ArrayBuffer(4);
assert(m.detachAb(dab) === true, 'detach_arraybuffer + is_detached true');
assert(dab.byteLength === 0, 'detached byteLength 0, got ' + dab.byteLength);
assert(predStr(m.preds(dab)) === 'true,false,false,false,true', 'preds(detached ab): ' + predStr(m.preds(dab)));

if (failures > 0) { process.exit(1); }
console.log('OK: 14_binary');
