/**
 * v8.js — Node.js `v8` / `node:v8` (stub / MVP)
 *
 * Heap statistics use process.memoryUsage() when available.
 * serialize/deserialize: JSON + Buffer MVP for primitives/plain objects
 * (not a V8 wire-format compatible serializer).
 */
'use strict';

function _mem() {
    try {
        if (typeof process !== 'undefined' && typeof process.memoryUsage === 'function') {
            return process.memoryUsage();
        }
    } catch (_e) { /* ignore */ }
    return { rss: 0, heapTotal: 0, heapUsed: 0, external: 0, arrayBuffers: 0 };
}

function getHeapStatistics() {
    var m = _mem();
    var heapTotal = m.heapTotal || 0;
    var heapUsed = m.heapUsed || 0;
    return {
        total_heap_size: heapTotal,
        total_heap_size_executable: 0,
        total_physical_size: heapTotal,
        total_available_size: Math.max(0, heapTotal - heapUsed),
        used_heap_size: heapUsed,
        heap_size_limit: Math.max(heapTotal * 2, 64 * 1024 * 1024),
        malloced_memory: 0,
        peak_malloced_memory: 0,
        does_zap_garbage: 0,
        number_of_native_contexts: 1,
        number_of_detached_contexts: 0,
        total_global_handles_size: 0,
        used_global_handles_size: 0,
        external_memory: m.external || 0
    };
}

var _HEAP_SPACES = [
    'read_only_space',
    'new_space',
    'old_space',
    'code_space',
    'large_object_space',
    'code_large_object_space',
    'new_large_object_space',
    'shared_space',
    'shared_large_object_space',
    'trusted_space',
    'trusted_large_object_space',
    'shared_trusted_space',
    'shared_trusted_large_object_space'
];

function getHeapSpaceStatistics() {
    var m = _mem();
    var used = m.heapUsed || 0;
    var total = m.heapTotal || 0;
    var out = [];
    for (var i = 0; i < _HEAP_SPACES.length; i++) {
        var name = _HEAP_SPACES[i];
        var isOld = name === 'old_space';
        out.push({
            space_name: name,
            space_size: isOld ? total : 0,
            space_used_size: isOld ? used : 0,
            space_available_size: isOld ? Math.max(0, total - used) : 0,
            physical_space_size: isOld ? total : 0
        });
    }
    return out;
}

function getHeapCodeStatistics() {
    return {
        code_and_metadata_size: 0,
        bytecode_and_metadata_size: 0,
        external_script_source_size: 0,
        cpu_profiler_metadata_size: 0
    };
}

function setFlagsFromString(/* flags */) {
    // no-op stub
}

function serialize(value) {
    var B = globalThis.Buffer || require('buffer').Buffer;
    var payload;
    try {
        payload = JSON.stringify(value, function (_k, v) {
            if (typeof v === 'bigint') return { __t: 'bigint', v: String(v) };
            if (typeof v === 'undefined') return { __t: 'undefined' };
            if (typeof Buffer !== 'undefined' && Buffer.isBuffer && Buffer.isBuffer(v)) {
                return { __t: 'Buffer', v: Array.prototype.slice.call(v) };
            }
            if (v && typeof v === 'object' && v.buffer instanceof ArrayBuffer &&
                typeof v.byteLength === 'number' && typeof v.BYTES_PER_ELEMENT === 'number') {
                return {
                    __t: 'TypedArray',
                    n: v.constructor && v.constructor.name,
                    v: Array.prototype.slice.call(new Uint8Array(v.buffer, v.byteOffset, v.byteLength))
                };
            }
            return v;
        });
    } catch (e) {
        // circular / unsupported — store as string tag
        payload = JSON.stringify({ __t: 'unserializable', v: String(value) });
    }
    return B.from('JBV1' + payload, 'utf8');
}

function deserialize(buffer) {
    var B = globalThis.Buffer || require('buffer').Buffer;
    if (!B.isBuffer(buffer) && !(buffer instanceof Uint8Array)) {
        var err = new TypeError('The "buffer" argument must be an instance of Buffer or Uint8Array.');
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
    var s = B.from(buffer).toString('utf8');
    if (s.indexOf('JBV1') !== 0) {
        // Attempt raw JSON for simple cases
        try { return JSON.parse(s); } catch (_e) {
            var e2 = new Error('Unable to deserialize buffer');
            e2.code = 'ERR_BUFFER_OUT_OF_BOUNDS';
            throw e2;
        }
    }
    var parsed = JSON.parse(s.slice(4));
    return _revive(parsed);
}

function _revive(v) {
    if (!v || typeof v !== 'object') return v;
    if (v.__t === 'undefined') return undefined;
    if (v.__t === 'bigint') return BigInt(v.v);
    if (v.__t === 'Buffer') {
        var B = globalThis.Buffer || require('buffer').Buffer;
        return B.from(v.v);
    }
    if (v.__t === 'TypedArray') {
        var bytes = new Uint8Array(v.v);
        var Ctors = {
            Int8Array: Int8Array, Uint8Array: Uint8Array, Uint8ClampedArray: Uint8ClampedArray,
            Int16Array: Int16Array, Uint16Array: Uint16Array,
            Int32Array: Int32Array, Uint32Array: Uint32Array,
            Float32Array: Float32Array, Float64Array: Float64Array
        };
        var C = Ctors[v.n] || Uint8Array;
        return new C(bytes.buffer, bytes.byteOffset, bytes.byteLength / (C.BYTES_PER_ELEMENT || 1));
    }
    if (Array.isArray(v)) {
        for (var i = 0; i < v.length; i++) v[i] = _revive(v[i]);
        return v;
    }
    var out = {};
    var keys = Object.keys(v);
    for (var k = 0; k < keys.length; k++) {
        out[keys[k]] = _revive(v[keys[k]]);
    }
    return out;
}

module.exports = {
    getHeapStatistics: getHeapStatistics,
    getHeapSpaceStatistics: getHeapSpaceStatistics,
    getHeapCodeStatistics: getHeapCodeStatistics,
    setFlagsFromString: setFlagsFromString,
    serialize: serialize,
    deserialize: deserialize
};
