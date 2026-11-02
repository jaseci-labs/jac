/**
 * binary_types.js — ECMAScript binary data primitives
 *
 * Implements ArrayBuffer (including resizable/transfer), eight numeric TypedArray
 * views, BigInt64Array, BigUint64Array, Uint8ClampedArray, and DataView.
 *
 * Backing store is a raw calloc'd block managed via globalThis.__buf:
 *   __buf.alloc(n)                      -> ptr (int, zero-filled)
 *   __buf.free(ptr)                     -> void
 *   __buf.getByte(ptr, offset)          -> int (0..255)
 *   __buf.setByte(ptr, offset, value)   -> void
 *   __buf.copy(dst, dstOff, src, srcOff, len) -> void
 *   __buf.fill(ptr, offset, len, byte)  -> void
 *
 * Multi-byte reads/writes are composed from getByte/setByte in JS.
 *
 * Phase 6.13 -- js_engine
 */

const buf = globalThis.__buf;
// Constructor-body natives (buffer_native.jac), resolved once: they set the
// instance fields and register the side-table record in one call instead of
// ~12 interpreted property sets (~1µs each).
const _initArrayBufferNative = (buf && typeof buf.initArrayBuffer === 'function') ? buf.initArrayBuffer : null;
const _initTypedArrayNative = (buf && typeof buf.initTypedArray === 'function') ? buf.initTypedArray : null;

// ─── Helpers ────────────────────────────────────────────────────────────────

const _MAX_SAFE_INDEX = 9007199254740991; // 2^53 - 1
const _AB_ALLOC_LIMIT = 0x04000000; // 64 MiB — fail-fast under host ~100 MiB runner cap

function _toIntegerOrInfinity(value) {
  // Observable ToNumber (@@toPrimitive / valueOf / toString) then truncate.
  const n = typeof value === 'number' ? value : _toNumberStrict(value);
  if (n !== n) return 0;
  if (n === Infinity || n === -Infinity) return n;
  const t = n < 0 ? Math.ceil(n) : Math.floor(n);
  // Canonicalize -0 → +0 for index start positions.
  return t === 0 ? 0 : t;
}

function _toIndex(value) {
  if (value === undefined) return 0;
  // ES ToIndex → ToIntegerOrInfinity → ToNumber: BigInt / Symbol must TypeError.
  if (typeof value === 'bigint') {
    throw new TypeError('Cannot convert a BigInt value to a number');
  }
  if (typeof value === 'symbol') {
    throw new TypeError('Cannot convert a Symbol value to a number');
  }
  const n = (typeof value === 'number') ? value : _toNumberStrict(value);
  const integerIndex = n !== n ? 0 : (n < 0 ? Math.ceil(n) : Math.floor(n));
  if (integerIndex < 0) throw new RangeError('Invalid index');
  if (integerIndex > _MAX_SAFE_INDEX) throw new RangeError('Invalid index');
  if (integerIndex === 0) return 0; // canonicalize -0
  return integerIndex;
}

/**
 * GetMethod(V, @@toPrimitive) + Call with hint "number", else OrdinaryToPrimitive.
 * If @@toPrimitive is present but not callable → TypeError (do not fall through).
 */
function _toPrimitiveHintNumber(value) {
  if (value === null || (typeof value !== 'object' && typeof value !== 'function')) {
    return value;
  }
  if (typeof Symbol !== 'undefined' && Symbol.toPrimitive !== undefined) {
    const exotic = value[Symbol.toPrimitive];
    if (exotic !== undefined && exotic !== null) {
      if (typeof exotic !== 'function') {
        throw new TypeError('Cannot convert object to primitive value');
      }
      const r = exotic.call(value, 'number');
      if (typeof r === 'object' && r !== null) {
        throw new TypeError('Cannot convert object to primitive value');
      }
      return r;
    }
  }
  if (typeof value.valueOf === 'function') {
    const vo = value.valueOf();
    if (vo === null || typeof vo !== 'object') {
      return vo;
    }
  }
  if (typeof value.toString !== 'function') {
    throw new TypeError('Cannot convert object to primitive value');
  }
  const ts = value.toString();
  if (typeof ts === 'object' && ts !== null) {
    throw new TypeError('Cannot convert object to primitive value');
  }
  return ts;
}

/** ToNumber that TypeErrors when OrdinaryToPrimitive cannot produce a number. */
function _toNumberStrict(value) {
  if (typeof value === 'number') return value;
  if (typeof value === 'bigint') {
    throw new TypeError('Cannot convert a BigInt value to a number');
  }
  const prim = _toPrimitiveHintNumber(value);
  if (typeof prim === 'bigint') {
    throw new TypeError('Cannot convert a BigInt value to a number');
  }
  return Number(prim);
}

/** ToBigInt — rejects Number (unlike the BigInt constructor on integers). */
function _toBigIntStrict(value) {
  // ToBigInt on Number → TypeError (BigInt(number) would use NumberToBigInt).
  if (typeof value === 'number') {
    throw new TypeError('Cannot convert a Number value to a BigInt');
  }
  if (typeof value === 'symbol') {
    throw new TypeError('Cannot convert a Symbol value to a BigInt');
  }
  if (value === null || value === undefined) {
    throw new TypeError('Cannot convert null or undefined to a BigInt');
  }
  // bigint / boolean / string / object: BigInt() matches ToBigInt + ToPrimitive.
  return BigInt(value);
}

function _toLength(value) {
  const integerIndex = _toIntegerOrInfinity(_toNumberStrict(value));
  if (integerIndex <= 0) return 0;
  if (integerIndex > _MAX_SAFE_INDEX) throw new RangeError('Invalid array length');
  return integerIndex;
}

/** ES LengthOfArrayLike — ToLength(length) with observable ToNumber on length. */
function _lengthOfArrayLike(obj) {
  if (obj === null || typeof obj !== 'object') {
    throw new TypeError('Invalid typed array length');
  }
  if (!('length' in obj)) return 0;
  return _toLength(obj.length);
}

/** Capture typed-array / DataView witness state before observable steps. */
function _binaryViewWitness(view) {
  if (!view || typeof buf.binaryKind !== 'function' || buf.binaryKind(view) !== 2) {
    return { valid: false, detached: true, oob: true, byteLength: 0, length: 0, generation: -1 };
  }
  const buffer = view._buffer;
  if (!buffer) {
    return { valid: false, detached: true, oob: true, byteLength: 0, length: 0, generation: -1 };
  }
  const oob = _taIsOutOfBounds(view);
  const length = oob ? 0 : _taLength(view);
  return {
    valid: true,
    detached: !!buffer._detached,
    oob: oob,
    immutable: !!buffer._immutable,
    byteLength: length * (view.BYTES_PER_ELEMENT || 1),
    length: length,
    generation: buffer._detachGen || 0,
    byteOffset: oob ? 0 : (view._byteOffset || 0),
    bpe: view.BYTES_PER_ELEMENT || 1
  };
}

/**
 * Revalidate witness after observable coercion/callback.
 * Policies:
 *   'throw'          — TypeError if detached or OOB (structural ops)
 *   'throwIfDetached'— TypeError only when detached
 *   'oobZero'        — return length 0 when detached/OOB (iteration stop)
 *   'soft'           — return current witness; caller decides
 */
function _revalidateWitness(view, witness, policy) {
  const cur = _binaryViewWitness(view);
  if (policy === 'throw' && (cur.detached || cur.oob || !cur.valid)) {
    throw new TypeError('Cannot perform TypedArray operation on a detached or out-of-bounds TypedArray');
  }
  if (policy === 'throwIfDetached' && cur.detached) {
    throw new TypeError('Attempted to access detached ArrayBuffer');
  }
  if (policy === 'oobZero' && (cur.detached || cur.oob || cur.length === 0)) {
    return { valid: cur.valid, length: 0, detached: cur.detached, oob: true };
  }
  return cur;
}

/**
 * Capture witness, run coerce(), then revalidate.
 * Policies (see _revalidateWitness):
 *   'throw'   — structural ops (set/fill/species)
 *   'soft'    — search ops (indexOf/includes): detach/OOB after coercion → soft witness
 *   'oobZero' — iteration stop
 */
function _coerceThenWitness(view, coerceFn, policy) {
  const before = _binaryViewWitness(view);
  const value = coerceFn();
  const after = _revalidateWitness(view, before, policy === undefined ? 'throw' : policy);
  return { value: value, witness: after };
}

function _checkAllocLimit(size) {
  // Reject non-finite / negative before native bulk (NaN > limit is false).
  if (typeof size !== 'number' || !(size >= 0) || size !== size || size === Infinity) {
    throw new RangeError('ArrayBuffer allocation size too large');
  }
  if (size > _AB_ALLOC_LIMIT) {
    throw new RangeError('ArrayBuffer allocation size too large');
  }
}

function _bufferNativeFlags(buffer) {
  return (buffer._detached ? 1 : 0) |
    (buffer._isSharedArrayBuffer ? 2 : 0) |
    (buffer._immutable ? 4 : 0) |
    (buffer._resizable || buffer._growable ? 8 : 0);
}

function _syncNativeBuffer(buffer, bumpGeneration) {
  if (typeof buf.registerBuffer !== 'function') return;
  buf.registerBuffer(
    buffer,
    buffer._ptr || 0,
    buffer._byteLength || 0,
    buffer._maxByteLength === undefined ? (buffer._byteLength || 0) : buffer._maxByteLength,
    bumpGeneration ? -1 : 0,
    _bufferNativeFlags(buffer)
  );
}

function _typedArrayElementKind(name) {
  switch (name) {
    case 'Int8Array': return 1;
    case 'Uint8Array': return 2;
    case 'Uint8ClampedArray': return 3;
    case 'Int16Array': return 4;
    case 'Uint16Array': return 5;
    case 'Int32Array': return 6;
    case 'Uint32Array': return 7;
    case 'Float32Array': return 8;
    case 'Float64Array': return 9;
    case 'BigInt64Array': return 10;
    case 'BigUint64Array': return 11;
    default: return 0;
  }
}

function _registerNativeTypedArray(view, name) {
  if (typeof buf.registerTypedArray !== 'function') return;
  buf.registerTypedArray(
    view,
    view._buffer,
    view._byteOffset || 0,
    view._length || 0,
    view.BYTES_PER_ELEMENT || 1,
    _typedArrayElementKind(name),
    view._fixedLength !== true
  );
}

function _registerNativeDataView(view) {
  if (typeof buf.registerDataView !== 'function') return;
  buf.registerDataView(
    view,
    view._buffer,
    view._byteOffset || 0,
    view._byteLength || 0,
    view._fixedLength !== true
  );
}

/** GetPrototypeFromConstructor (ES §9.1.15). */
function _getPrototypeFromConstructor(ctorTarget, intrinsicDefaultProto) {
  if (ctorTarget === undefined) return intrinsicDefaultProto;
  const proto = ctorTarget.prototype;
  if (typeof proto === 'object' && proto !== null) return proto;
  return intrinsicDefaultProto;
}

function _ordinaryCreateFromConstructor(ctorTarget, intrinsicDefaultProto) {
  return Object.create(_getPrototypeFromConstructor(ctorTarget, intrinsicDefaultProto));
}

function _installInstancePrototype(instance, ctorTarget, intrinsicDefaultProto) {
  const proto = _getPrototypeFromConstructor(ctorTarget, intrinsicDefaultProto);
  if (Object.getPrototypeOf(instance) !== proto) {
    Object.setPrototypeOf(instance, proto);
  }
}

/** Parse byteLength + options after instance proto is fixed; alloc follows separately. */
function _parseBufferCtorArgs(byteLength, options, toIndexFn, optionsNullError) {
  const len = toIndexFn(byteLength);
  let maxLen = len;
  let hasMaxByteLength = false;
  // GetArrayBufferMaxByteLengthOption: if Type(options) is not Object, return empty.
  if (options !== undefined && options !== null && typeof options === 'object') {
    if (options.maxByteLength !== undefined) {
      maxLen = toIndexFn(options.maxByteLength);
      if (maxLen < len) {
        throw new RangeError('maxByteLength must be >= byteLength');
      }
      hasMaxByteLength = true;
    }
  }
  return { len: len, maxLen: maxLen, hasMaxByteLength: hasMaxByteLength };
}

function _installBufferSpecies(Ctor) {
  if (typeof Symbol === 'undefined' || Symbol.species === undefined) return;
  const getter = function getSpecies() { return this; };
  try {
    Object.defineProperty(getter, 'name', {
      value: 'get [Symbol.species]',
      writable: false,
      enumerable: false,
      configurable: true
    });
  } catch (_) {}
  Object.defineProperty(Ctor, Symbol.species, {
    get: getter,
    configurable: true,
    enumerable: false
  });
  // Do not fall back to a data property — that would make @@species non-configurable
  // / wrong-shaped and break Symbol.species prop-desc tests.
}


/** Install function `name` / `length` as own non-enumerable data properties. */
function _installMeta(fn, name, length) {
  Object.defineProperty(fn, 'name', {
    value: name, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(fn, 'length', {
    value: length, writable: false, enumerable: false, configurable: true
  });
  return fn;
}

/** Install a global binding as non-enumerable (ES intrinsic style). */
function _installGlobal(name, value) {
  Object.defineProperty(globalThis, name, {
    value: value, writable: true, enumerable: false, configurable: true
  });
}

function _rejectConstruct(fn) {
  if (typeof globalThis.__jacMarkNonConstructor === "function") {
    try { globalThis.__jacMarkNonConstructor(fn); } catch (_) {}
  }
  return fn;
}

/** IsConstructor (ES §7.2.4) — Proxy construct probe for JS-layer builtins. */
function _isConstructor(C) {
  if (typeof C !== 'function') return false;
  try {
    Reflect.construct(
      new Proxy(C, { construct() { return {}; } }),
      [],
      C
    );
    return true;
  } catch (_) {
    return false;
  }
}

function _isArrayBufferLike(buffer) {
  if (!buffer || typeof buffer !== 'object') return false;
  if (typeof buf.binaryKind !== 'function') return false;
  const kind = buf.binaryKind(buffer);
  return kind === 1 || kind === 4;
}

function _dvRequireDataView(self) {
  if (!self || typeof buf.binaryKind !== 'function' || buf.binaryKind(self) !== 3) {
    throw new TypeError('Method called on incompatible receiver');
  }
}

function _dvIsOutOfBounds(view) {
  const buffer = view._buffer;
  if (!buffer || buffer._detached) return true;
  const bufLen = buffer._byteLength || 0;
  const byteOffset = view._byteOffset || 0;
  if (byteOffset > bufLen) return true;
  // Fixed-length views become OOB when the buffer shrinks past their span.
  if (view._fixedLength === true) {
    return byteOffset + (view._byteLength || 0) > bufLen;
  }
  return false;
}

function _dvLiveByteLength(view) {
  if (_dvIsOutOfBounds(view)) return 0;
  const buffer = view._buffer;
  const byteOffset = view._byteOffset || 0;
  if (view._fixedLength === true) {
    return view._byteLength || 0;
  }
  return Math.max(0, (buffer._byteLength || 0) - byteOffset);
}

function _dvValidate(view, offset, size) {
  _dvRequireDataView(view);
  // Spec order: ToIndex first (may throw DummyError), then IsDetachedBuffer / OOB.
  const byteOffset = _toIndex(offset);
  if (!view._buffer || view._buffer._detached) {
    throw new TypeError('Cannot perform DataView operation on a detached ArrayBuffer');
  }
  if (_dvIsOutOfBounds(view)) {
    throw new TypeError('DataView is out of bounds');
  }
  const viewByteLen = _dvLiveByteLength(view);
  if (byteOffset + size > viewByteLen) {
    throw new RangeError('Offset is outside the bounds of the DataView');
  }
  return byteOffset;
}

function _dvValidateWrite(view, offset, size) {
  _dvRequireDataView(view);
  if (view._buffer && view._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  // Spec SetViewValue order: ToIndex → (caller ToNumber/ToBigInt) → IsDetachedBuffer.
  // This helper only does ToIndex + bounds; callers that coerce values must call
  // `_dvRequireAttached` after coercion (see `_dvWriteNumber` / `_dvWriteBigInt`).
  const byteOffset = _toIndex(offset);
  if (!view._buffer || view._buffer._detached) {
    throw new TypeError('Cannot perform DataView operation on a detached ArrayBuffer');
  }
  if (_dvIsOutOfBounds(view)) {
    throw new TypeError('DataView is out of bounds');
  }
  if (byteOffset + size > _dvLiveByteLength(view)) {
    throw new RangeError('Offset is outside the bounds of the DataView');
  }
  return byteOffset;
}

function _dvRequireAttached(view) {
  if (!view._buffer || view._buffer._detached) {
    throw new TypeError('Cannot perform DataView operation on a detached ArrayBuffer');
  }
}

/** SetViewValue for Number types: ToIndex → ToNumber → detach → bounds. */
function _dvWriteNumber(view, offset, size, value) {
  _dvRequireDataView(view);
  if (view._buffer && view._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  const byteOffset = _toIndex(offset);
  const num = _toNumberStrict(value);
  _dvRequireAttached(view);
  if (_dvIsOutOfBounds(view)) {
    throw new TypeError('DataView is out of bounds');
  }
  if (byteOffset + size > _dvLiveByteLength(view)) {
    throw new RangeError('Offset is outside the bounds of the DataView');
  }
  return { byteOffset: byteOffset, value: num };
}

/** SetViewValue for BigInt types: ToIndex → ToBigInt → detach → bounds. */
function _dvWriteBigInt(view, offset, size, value) {
  _dvRequireDataView(view);
  if (view._buffer && view._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  const byteOffset = _toIndex(offset);
  const bi = _toBigIntStrict(value);
  _dvRequireAttached(view);
  if (_dvIsOutOfBounds(view)) {
    throw new TypeError('DataView is out of bounds');
  }
  if (byteOffset + size > _dvLiveByteLength(view)) {
    throw new RangeError('Offset is outside the bounds of the DataView');
  }
  return { byteOffset: byteOffset, value: bi };
}

function _abRequireArrayBuffer(self, method) {
  if (!self || typeof buf.binaryKind !== 'function' || buf.binaryKind(self) !== 1) {
    throw new TypeError('ArrayBuffer.prototype.' + method + ' called on incompatible receiver');
  }
}

// ─── ArrayBuffer ────────────────────────────────────────────────────────────

class ArrayBuffer {
  constructor(byteLength, options) {
    // Native fast path: plain `new ArrayBuffer(n)` — non-negative integer n
    // within the limit, no options, direct construction — allocates, sets the
    // fields and registers in one native call (52µs → ~2µs).
    if (options === undefined && new.target === ArrayBuffer && typeof byteLength === 'number'
        && byteLength >= 0 && byteLength <= _AB_ALLOC_LIMIT && (byteLength | 0) === byteLength
        && _initArrayBufferNative !== null) {
      if (_initArrayBufferNative(this, byteLength) === true) return;
    }
    // Validate length/options BEFORE OrdinaryCreateFromConstructor side effects
    // (options-maxbytelength-compared-before-object-creation.js).
    const parsed = _parseBufferCtorArgs(
      byteLength,
      options,
      _toIndex,
      'ArrayBuffer options must be coercible to Object'
    );
    // OrdinaryCreateFromConstructor before CreateByteDataBlock (data-allocation-after-object-creation.js).
    _installInstancePrototype(this, new.target, ArrayBuffer.prototype);
    _checkAllocLimit(parsed.len);
    _checkAllocLimit(parsed.maxLen);
    this._ptr = buf.alloc(parsed.len);
    this._byteLength = parsed.len;
    this._maxByteLength = parsed.maxLen;
    this._resizable = parsed.hasMaxByteLength;
    this._immutable = false;
    this._detached = false;
    Object.defineProperty(this, '_isArrayBufferInstance', {
      value: true, writable: false, enumerable: false, configurable: false
    });
    _syncNativeBuffer(this, false);
  }

  get byteLength() {
    _abRequireArrayBuffer(this, 'byteLength');
    return this._detached ? 0 : this._byteLength;
  }

  get maxByteLength() {
    _abRequireArrayBuffer(this, 'maxByteLength');
    if (this._detached) return 0;
    return this._maxByteLength;
  }

  get resizable() {
    _abRequireArrayBuffer(this, 'resizable');
    // IsResizableArrayBuffer: ignore detach; keyed by [[ArrayBufferMaxByteLength]].
    return this._resizable === true;
  }

  get immutable() {
    _abRequireArrayBuffer(this, 'immutable');
    if (this._detached) return false;
    return this._immutable === true;
  }

  get detached() {
    _abRequireArrayBuffer(this, 'detached');
    return this._detached === true;
  }

  resize(newByteLength) {
    _abRequireArrayBuffer(this, 'resize');
    if (this._immutable) {
      throw new TypeError('Cannot resize an immutable ArrayBuffer');
    }
    if (!this._resizable) {
      throw new TypeError('ArrayBuffer is not resizable');
    }
    // Spec: ToIndex first (may detach during coercion), then IsDetachedBuffer.
    const newLen = _toIndex(newByteLength);
    if (this._detached) {
      throw new TypeError('Cannot resize a detached ArrayBuffer');
    }
    if (newLen > this._maxByteLength) {
      throw new RangeError('New byte length exceeds maxByteLength');
    }
    const oldLen = this._byteLength;
    if (newLen === oldLen) return;
    _checkAllocLimit(newLen);
    const oldPtr = this._ptr;
    const newPtr = buf.alloc(newLen);
    const copyLen = Math.min(oldLen, newLen);
    if (copyLen > 0) {
      buf.copy(newPtr, 0, oldPtr, 0, copyLen);
    }
    if (newLen > oldLen) {
      buf.fill(newPtr, oldLen, newLen - oldLen, 0);
    }
    buf.free(oldPtr);
    this._ptr = newPtr;
    this._byteLength = newLen;
    _syncNativeBuffer(this, true);
  }

  // mode: 'preserve-resizability' | 'fixed-length' | 'immutable'
  _transferTo(newLength, mode) {
    _abRequireArrayBuffer(this, mode === 'immutable' ? 'transferToImmutable' : 'transfer');
    const oldLen = this._byteLength;
    const targetLen = newLength === undefined ? oldLen : _toIndex(newLength);
    if (this._detached) {
      throw new TypeError('Cannot transfer a detached ArrayBuffer');
    }
    if (this._immutable) {
      throw new TypeError('Cannot transfer an immutable ArrayBuffer');
    }
    _checkAllocLimit(targetLen);
    if (mode === 'preserve-resizability' && this._resizable === true && targetLen > this._maxByteLength) {
      throw new RangeError('New byte length exceeds maxByteLength');
    }
    const result = Object.create(ArrayBuffer.prototype);
    result._ptr = buf.alloc(targetLen);
    result._byteLength = targetLen;
    result._detached = false;
    Object.defineProperty(result, '_isArrayBufferInstance', {
      value: true, writable: false, enumerable: false, configurable: false
    });

    if (mode === 'immutable') {
      result._maxByteLength = targetLen;
      result._resizable = false;
      result._immutable = true;
    } else if (mode === 'preserve-resizability' && this._resizable === true) {
      result._maxByteLength = this._maxByteLength;
      result._resizable = true;
      result._immutable = false;
    } else {
      result._maxByteLength = targetLen;
      result._resizable = false;
      result._immutable = false;
    }
    _syncNativeBuffer(result, false);

    const copyLen = Math.min(oldLen, targetLen);
    if (copyLen > 0) {
      buf.copy(result._ptr, 0, this._ptr, 0, copyLen);
    }
    _detachArrayBuffer(this);
    return result;
  }

  transfer(newLength) {
    return this._transferTo(newLength, 'preserve-resizability');
  }

  transferToFixedLength(newLength) {
    return this._transferTo(newLength, 'fixed-length');
  }

  transferToImmutable(newLength) {
    return this._transferTo(newLength, 'immutable');
  }

  slice(begin, end) {
    _abRequireArrayBuffer(this, 'slice');
    if (this._detached) {
      throw new TypeError('ArrayBuffer.prototype.slice called on a detached ArrayBuffer');
    }
    const len = this._byteLength;
    // Spec: ToIntegerOrInfinity for begin/end (defaults: 0 / len).
    const start = _taRelativeStart(begin === undefined ? 0 : begin, len);
    const fin = end === undefined ? len : _taRelativeEnd(end, len);
    if (this._detached) {
      throw new TypeError('ArrayBuffer.prototype.slice called on a detached ArrayBuffer');
    }
    const newLen = Math.max(fin - start, 0);
    _checkAllocLimit(newLen);
    const C = _abSpeciesConstructor(this);
    const result = new C(newLen);
    if (!_isArrayBufferLike(result) && !(result && result._isArrayBufferInstance)) {
      throw new TypeError('Species constructor did not return an ArrayBuffer');
    }
    if (typeof buf.binaryKind === 'function' && buf.binaryKind(result) !== 1) {
      throw new TypeError('Species constructor did not return an ArrayBuffer');
    }
    if (result === this) {
      throw new TypeError('Species constructor returned the same ArrayBuffer');
    }
    if (result._immutable) {
      throw new TypeError('Species constructor returned an immutable ArrayBuffer');
    }
    if (result._byteLength < newLen) {
      throw new TypeError('Species constructor returned a shorter ArrayBuffer');
    }
    if (result._detached) {
      throw new TypeError('Species constructor returned a detached ArrayBuffer');
    }
    if (newLen > 0) {
      buf.copy(result._ptr, 0, this._ptr, start, newLen);
    }
    return result;
  }

  sliceToImmutable(begin, end) {
    _abRequireArrayBuffer(this, 'sliceToImmutable');
    if (this._detached) {
      throw new TypeError('ArrayBuffer.prototype.sliceToImmutable called on a detached ArrayBuffer');
    }
    const len = this._byteLength;
    // Fail-fast before ToInteger side effects that could allocate huge temps.
    _checkAllocLimit(len);
    // ResolveBounds: ToIntegerOrInfinity + clamp to [0, len] before alloc.
    const start = _taRelativeStart(begin === undefined ? 0 : begin, len);
    const fin = end === undefined ? len : _taRelativeEnd(end, len);
    if (this._detached) {
      throw new TypeError('ArrayBuffer.prototype.sliceToImmutable called on a detached ArrayBuffer');
    }
    // Bounds are already clamped to len — newLen ≤ len ≤ alloc ceiling.
    const newLen = Math.max(fin - start, 0);
    _checkAllocLimit(newLen);
    if (newLen > len) {
      throw new RangeError('ArrayBuffer.prototype.sliceToImmutable bounds out of range');
    }
    const currentLen = this._byteLength;
    if (currentLen < fin) {
      throw new RangeError('ArrayBuffer.prototype.sliceToImmutable called on a shorter buffer');
    }
    const result = Object.create(ArrayBuffer.prototype);
    result._ptr = buf.alloc(newLen);
    result._byteLength = newLen;
    result._maxByteLength = newLen;
    result._resizable = false;
    result._immutable = true;
    result._detached = false;
    Object.defineProperty(result, '_isArrayBufferInstance', {
      value: true, writable: false, enumerable: false, configurable: false
    });
    _syncNativeBuffer(result, false);
    if (newLen > 0) {
      buf.copy(result._ptr, 0, this._ptr, start, newLen);
    }
    return result;
  }

  static isView(arg) {
    if (!arg || typeof arg !== 'object') return false;
    if (typeof buf.binaryKind !== 'function') return false;
    const kind = buf.binaryKind(arg);
    return kind === 2 || kind === 3;
  }
}

function _abSpeciesConstructor(O) {
  const defaultConstructor = ArrayBuffer;
  const C = O.constructor;
  if (C === undefined) return defaultConstructor;
  if (typeof C !== 'function' && (typeof C !== 'object' || C === null)) {
    throw new TypeError('ArrayBuffer species constructor is invalid');
  }
  if (typeof Symbol !== 'undefined' && Symbol.species !== undefined) {
    const S = C[Symbol.species];
    if (S === undefined || S === null) return defaultConstructor;
    if (typeof S !== 'function') {
      throw new TypeError('Symbol.species is not a constructor');
    }
    return S;
  }
  return typeof C === 'function' ? C : defaultConstructor;
}

_installBufferSpecies(ArrayBuffer);
if (typeof buf.setArrayBufferProto === 'function') buf.setArrayBufferProto(ArrayBuffer.prototype);
_installMeta(ArrayBuffer, 'ArrayBuffer', 1);
[
  ['resize', 1], ['slice', 2], ['sliceToImmutable', 2],
  ['transfer', 0], ['transferToFixedLength', 0], ['transferToImmutable', 0]
].forEach(function(pair) {
  const method = ArrayBuffer.prototype[pair[0]];
  _rejectConstruct(method);
  _installMeta(method, pair[0], pair[1]);
});
_rejectConstruct(ArrayBuffer.isView);
_installMeta(ArrayBuffer.isView, 'isView', 1);
if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
  // ES §25.1.5.4: data property, not an accessor.
  Object.defineProperty(ArrayBuffer.prototype, Symbol.toStringTag, {
    value: 'ArrayBuffer',
    writable: false,
    enumerable: false,
    configurable: true
  });
}
[
  ['byteLength', 'get byteLength'],
  ['maxByteLength', 'get maxByteLength'],
  ['resizable', 'get resizable'],
  ['immutable', 'get immutable'],
  ['detached', 'get detached']
].forEach(function(pair) {
  const desc = Object.getOwnPropertyDescriptor(ArrayBuffer.prototype, pair[0]);
  if (desc && typeof desc.get === 'function') {
    try {
      Object.defineProperty(desc.get, 'name', {
        value: pair[1], writable: false, enumerable: false, configurable: true
      });
    } catch (_) {}
  }
});

// ─── TypedArray base (function-prototype pattern — no class extends) ─────────

function _taRequireInstance(self, name) {
  if (!self || typeof buf.binaryKind !== 'function' || buf.binaryKind(self) !== 2) {
    // Match V8/SpiderMonkey wording used by test262 propertyNameCoverage helpers.
    const isGetter = name === 'byteLength' || name === 'byteOffset' ||
      name === 'buffer' || name === 'length' || name === '[Symbol.toStringTag]';
    throw new TypeError(
      (isGetter ? 'Method get ' : 'Method ') + name + ' called on incompatible receiver'
    );
  }
}

/** Uint8Array brand for fromBase64/toBase64/fromHex/toHex (not other TypedArrays). */
function _requireUint8Array(self, name) {
  _taRequireInstance(self, name);
  if (self._typedArrayName !== 'Uint8Array') {
    throw new TypeError('Method ' + name + ' called on incompatible receiver');
  }
}

function _taIsOutOfBounds(self) {
  // ES IsTypedArrayOutOfBounds — must match Jac binary_view_witness.
  const buffer = self._buffer;
  if (!buffer || buffer._detached) return true;
  const bufLen = buffer._byteLength >>> 0;
  const byteOffset = self._byteOffset || 0;
  const bpe = self.BYTES_PER_ELEMENT || 1;
  if (byteOffset > bufLen) return true;
  if (self._fixedLength) {
    // Fixed-length: entire [[ByteOffset]]..end must fit in buffer.
    return byteOffset + (self._length || 0) * bpe > bufLen;
  }
  // Length-tracking (ArrayLength = auto): only byteOffset > bufferByteLength is OOB.
  return false;
}

function _taValidate(self, name) {
  _taRequireInstance(self, name);
  if (self._buffer._detached) {
    throw new TypeError('Cannot perform TypedArray operation on a detached ArrayBuffer');
  }
  if (_taIsOutOfBounds(self)) {
    throw new TypeError('Cannot perform TypedArray operation on an out-of-bounds TypedArray');
  }
}

function _taLength(self) {
  if (!self || !self._buffer) return 0;
  const buffer = self._buffer;
  if (buffer._detached) return 0;
  const bufLen = buffer._byteLength;
  const byteOffset = self._byteOffset || 0;
  const bpe = self.BYTES_PER_ELEMENT || 1;
  if (byteOffset > bufLen) return 0;
  if (!self._fixedLength) {
    return Math.floor((bufLen - byteOffset) / bpe);
  }
  const viewByteLen = (self._length || 0) * bpe;
  if (byteOffset + viewByteLen > bufLen) return 0;
  return self._length;
}

function _sameValueZero(x, y) {
  return x === y || (x !== x && y !== y);
}

/**
 * SpeciesConstructor(O, defaultConstructor) for TypedArrays (ES §7.3.27 / §23.2.4.1).
 * When @@species is undefined or null, return the *default* TypedArray ctor —
 * not O.constructor (that was incorrectly species-aware for bare subclasses).
 */
function _taSpeciesConstructor(O) {
  const defaultConstructor = O._ctor;
  let C = O.constructor;
  if (C === undefined) return defaultConstructor;
  if (C === null || (typeof C !== 'object' && typeof C !== 'function')) {
    throw new TypeError('TypedArray constructor is not an object');
  }
  if (typeof Symbol !== 'undefined' && Symbol.species !== undefined) {
    const S = C[Symbol.species];
    if (S === undefined || S === null) return defaultConstructor;
    if (!_isConstructor(S)) {
      throw new TypeError('Symbol.species is not a constructor');
    }
    return S;
  }
  return defaultConstructor;
}

function _taSpeciesCreate(O, length) {
  _checkAllocLimit(length * (O.BYTES_PER_ELEMENT || 1));
  const C = _taSpeciesConstructor(O);
  const result = new C(length);
  if (typeof buf.binaryKind !== 'function' || buf.binaryKind(result) !== 2) {
    throw new TypeError('Species constructor did not produce a TypedArray');
  }
  if (_taLength(result) < length) {
    throw new TypeError('Species constructor produced a TypedArray with insufficient length');
  }
  return result;
}

/** TypedArrayCreateSameType — ignore species (toReversed/toSorted/with). */
function _taCreateSameType(O, length) {
  _checkAllocLimit(length * (O.BYTES_PER_ELEMENT || 1));
  const C = O._ctor || O.constructor;
  if (typeof C !== 'function') {
    throw new TypeError('TypedArray constructor is not available');
  }
  const result = new C(length);
  if (typeof buf.binaryKind !== 'function' || buf.binaryKind(result) !== 2) {
    throw new TypeError('TypedArrayCreate did not produce a TypedArray');
  }
  if (_taLength(result) < length) {
    throw new TypeError('TypedArrayCreate produced a TypedArray with insufficient length');
  }
  return result;
}

function _taMakeArrayIterator(self, kind) {
  // kind: 0=keys, 1=values, 2=entries — brand as Array Iterator via Array.prototype.
  const base = [][Symbol.iterator]();
  const proto = Object.getPrototypeOf(base);
  let index = 0;
  const it = Object.create(proto);
  it.next = function() {
    const len = _taLength(self);
    if (index < len) {
      const i = index++;
      if (kind === 0) return { value: i, done: false };
      if (kind === 1) return { value: self._readAt(i), done: false };
      return { value: [i, self._readAt(i)], done: false };
    }
    return { value: undefined, done: true };
  };
  return it;
}

function _taRelativeStart(start, len) {
  if (start === undefined) return 0;
  const rel = _toIntegerOrInfinity(start);
  if (rel === -Infinity) return 0;
  if (rel === Infinity) return len;
  return rel < 0 ? Math.max(len + rel, 0) : Math.min(rel, len);
}

function _taRelativeEnd(end, len) {
  if (end === undefined) return len;
  const rel = _toIntegerOrInfinity(end);
  if (rel === -Infinity) return 0;
  if (rel === Infinity) return len;
  return rel < 0 ? Math.max(len + rel, 0) : Math.min(rel, len);
}

/** IteratorClose (ES §7.4.11) — call return if present; prefer original abrupt completion. */
function _taIteratorClose(iter, err) {
  try {
    const ret = iter.return;
    if (typeof ret === 'function') {
      ret.call(iter);
    }
  } catch (closeErr) {
    if (err === undefined) throw closeErr;
  }
  if (err !== undefined) throw err;
}

// %Array.prototype.values% and %ArrayIteratorPrototype%.next as installed at
// engine init (before any user code): while an Array's @@iterator and the
// iterator's next are still these, iterating it reads exactly arr[0..length).
const _arrayValuesFn = Array.prototype[Symbol.iterator];
const _arrayIterProto = Object.getPrototypeOf([][Symbol.iterator]());
const _arrayIterNextFn = _arrayIterProto.next;

// `preMethod` / `hasPre`: the caller already did the GetMethod(@@iterator) Get
// (so it is not repeated — a getter there is observable).
function _iterableToList(obj, preMethod, hasPre) {
  if (obj == null || typeof obj !== 'object') return null;
  if (typeof Symbol === 'undefined' || Symbol.iterator === undefined) return null;
  // GetMethod(@@iterator): nullish → undefined; non-callable (incl. IsHTMLDDA) → TypeError.
  const method = hasPre === true ? preMethod : obj[Symbol.iterator];
  if (method === undefined || method === null) return null;
  if (typeof method !== 'function') {
    throw new TypeError('@@iterator is not a function');
  }
  const iter = method.call(obj);
  if (iter == null || typeof iter !== 'object') {
    throw new TypeError('Iterator must be an object');
  }
  const items = [];
  const nextMethod = iter.next;
  if (typeof nextMethod !== 'function') {
    _taIteratorClose(iter, new TypeError('Iterator next is not a function'));
  }
  try {
    while (true) {
      const step = nextMethod.call(iter);
      if (step == null || typeof step !== 'object') {
        throw new TypeError('Iterator result must be an object');
      }
      if (step.done) break;
      items.push(step.value);
    }
  } catch (err) {
    _taIteratorClose(iter, err);
  }
  return items;
}

function _taInitFromObjectArg(instance, arg0, bytesPerElement, setter) {
  if (globalThis.__JDBG_TA) {
    try {
      var _it = (arg0 != null && typeof arg0 === 'object' && typeof Symbol !== 'undefined') ? arg0[Symbol.iterator] : undefined;
      var _iter = (typeof _it === 'function') ? _it.call(arg0) : undefined;
      process.stderr.write("[TAINIT] type=" + (typeof arg0) + " isArr=" + Array.isArray(arg0)
        + " ctor=" + (arg0 && arg0.constructor && arg0.constructor.name)
        + " len=" + (arg0 && arg0.length) + " itType=" + (typeof _it)
        + " iterType=" + (typeof _iter) + " nextType=" + (_iter && typeof _iter.next) + "\n");
    } catch (e) { process.stderr.write("[TAINIT] probe-err " + e.message + "\n"); }
  }
  // ES InitializeTypedArrayFromTypedArray (§23.2.5.1.2): a TypedArray source is
  // handled by a dedicated copy path BEFORE the @@iterator / array-like paths.
  // It reads the source's live [[ArrayLength]] and copies element-by-element; it
  // must NOT drive the source's @@iterator (a length-tracking source on a
  // resizable buffer routed through the generic iterable path could allocate
  // unbounded and OOM). This mirrors real engines and matches _taLength here.
  if (arg0 !== null && typeof arg0 === 'object'
      && typeof buf.binaryKind === 'function' && buf.binaryKind(arg0) === 2) {
    _taValidate(arg0, 'construct');
    const srcLen = _taLength(arg0);
    _checkAllocLimit(srcLen * bytesPerElement);
    instance._length = srcLen;
    instance._fixedLength = true;
    instance._buffer = new ArrayBuffer(srcLen * bytesPerElement);
    instance._byteOffset = 0;
    _registerNativeTypedArray(instance, instance._typedArrayName);
    // Native bulk copy (same kind: memmove; int→int: convert loop); the
    // per-element _writeAt/_readAt loop below remains for float/bigint mixes.
    if (typeof buf.taSet === 'function' && buf.taSet(instance, arg0, 0) === true) return;
    var si = 0;
    for (; si < srcLen; si++) {
      // Live length: a resizable-backed source may shrink; stop past new length.
      if (si >= _taLength(arg0)) break;
      instance._writeAt(si, arg0._readAt(si));
    }
    return;
  }

  // Spec TypedArray(object): GetMethod(@@iterator) before LengthOfArrayLike.
  var fromIter;
  if (Array.isArray(arg0) && typeof buf.intArrayProbe === 'function') {
    const iterMethod = arg0[Symbol.iterator];
    // Built-in array iteration of a plain int32 Array: IterableToList natively
    // (no iterator objects, no per-element _writeAt), then allocate, then fill —
    // the spec's order. -1 means not eligible; the generic path takes over.
    if (iterMethod === _arrayValuesFn && _arrayIterProto.next === _arrayIterNextFn) {
      const kind = _typedArrayElementKind(instance._typedArrayName);
      const n = (kind >= 1 && kind <= 7) ? buf.intArrayProbe(arg0) : -1;
      if (n >= 0) {
        _checkAllocLimit(n * bytesPerElement);
        instance._length = n;
        instance._fixedLength = true;
        instance._buffer = new ArrayBuffer(n * bytesPerElement);
        instance._byteOffset = 0;
        _registerNativeTypedArray(instance, instance._typedArrayName);
        if (buf.taFillFromProbe(instance) === true) return;
        // Not expected: write the elements the ordinary way into this buffer.
        for (var pi = 0; pi < n; pi++) instance._writeAt(pi, arg0[pi]);
        return;
      }
    }
    fromIter = _iterableToList(arg0, iterMethod, true);
  } else {
    fromIter = _iterableToList(arg0);
  }
  if (fromIter !== null) {
    _checkAllocLimit(fromIter.length * bytesPerElement);
    instance._length = fromIter.length;
    instance._fixedLength = true;
    instance._buffer = new ArrayBuffer(fromIter.length * bytesPerElement);
    instance._byteOffset = 0;
    _registerNativeTypedArray(instance, instance._typedArrayName);
    // Use instance._writeAt so ToNumber/ToBigInt TypeErrors match IntegerIndexedElementSet.
    var idx = 0;
    for (; idx < fromIter.length; idx++) {
      instance._writeAt(idx, fromIter[idx]);
    }
    return;
  }

  // Array-like: LengthOfArrayLike — never ToIndex(object) for plain objects.
  if (arg0 !== null && typeof arg0 === 'object') {
    const srcLen = _lengthOfArrayLike(arg0);
    _checkAllocLimit(srcLen * bytesPerElement);
    instance._length = srcLen;
    instance._fixedLength = true;
    instance._buffer = new ArrayBuffer(srcLen * bytesPerElement);
    instance._byteOffset = 0;
    _registerNativeTypedArray(instance, instance._typedArrayName);
    var i = 0;
    for (; i < srcLen; i++) {
      instance._writeAt(i, arg0[i]);
    }
    return;
  }

  throw new TypeError('Invalid typed array length');
}

function _installTypedArraySpecies(Ctor) {
  if (typeof Symbol === 'undefined' || Symbol.species === undefined) return;
  // Native getter when available: the subarray fast path (buffer_native.jac
  // ta_subarray) recognises the pristine @@species by native kind.
  const getter = typeof buf.speciesGetter === 'function'
    ? buf.speciesGetter
    : function getSpecies() { return this; };
  try {
    Object.defineProperty(getter, 'name', {
      value: 'get [Symbol.species]',
      writable: false,
      enumerable: false,
      configurable: true
    });
  } catch (_) {
    // Function name metadata is best-effort in this engine.
  }
  Object.defineProperty(Ctor, Symbol.species, {
    get: getter,
    configurable: true,
    enumerable: false
  });
}

function _taInstallPrototypeMethods(proto) {
  function _nameGetter(fn, name) {
    try {
      Object.defineProperty(fn, 'name', {
        value: name, writable: false, enumerable: false, configurable: true
      });
    } catch (_) {}
    return fn;
  }
  // The four getters are natives when the engine provides them (buffer_native.jac):
  // one native call instead of a JS chain over ~15 exotic-object property reads,
  // and the VM's GET_PROP recognises the pristine native on the prototype chain
  // and answers `ta.length` etc. from the binary side-table with no call at all.
  Object.defineProperty(proto, 'length', {
    get: typeof buf.getLength === 'function' ? buf.getLength : _nameGetter(function() {
      _taRequireInstance(this, 'length');
      return _taLength(this);
    }, 'get length'),
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(proto, 'byteLength', {
    get: typeof buf.getByteLength === 'function' ? buf.getByteLength : _nameGetter(function() {
      _taRequireInstance(this, 'byteLength');
      if (_taIsOutOfBounds(this)) return 0;
      return _taLength(this) * this.BYTES_PER_ELEMENT;
    }, 'get byteLength'),
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(proto, 'byteOffset', {
    get: typeof buf.getByteOffset === 'function' ? buf.getByteOffset : _nameGetter(function() {
      _taRequireInstance(this, 'byteOffset');
      if (_taIsOutOfBounds(this)) return 0;
      return this._byteOffset;
    }, 'get byteOffset'),
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(proto, 'buffer', {
    get: typeof buf.getBuffer === 'function' ? buf.getBuffer : _nameGetter(function() {
      _taRequireInstance(this, 'buffer');
      return this._buffer;
    }, 'get buffer'),
    enumerable: false,
    configurable: true
  });
  if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
    const toStringTagGetter = function() {
      if (!this || typeof buf.binaryKind !== 'function' || buf.binaryKind(this) !== 2) return undefined;
      return this._typedArrayName || (this._ctor && this._ctor.name) || 'TypedArray';
    };
    try {
      Object.defineProperty(toStringTagGetter, 'name', {
        value: 'get [Symbol.toStringTag]',
        writable: false,
        enumerable: false,
        configurable: true
      });
    } catch (_) {
      // Function name metadata is best-effort in this engine.
    }
    Object.defineProperty(proto, Symbol.toStringTag, {
      get: toStringTagGetter,
      configurable: true,
      enumerable: false
    });
  }
  Object.defineProperty(proto, '_isTypedArray', {
    value: true, writable: false, enumerable: false, configurable: false
  });

  proto._readAt = function(idx) {
    // IntegerIndexedElementGet: detach/OOB → undefined (not TypeError).
    // HOT PATH: called per element by every indexed read fallback and every
    // JS-loop method. Must not allocate (the old _binaryViewWitness object per
    // read was ~GBs of garbage on an MB-sized Buffer scan) and must not make
    // extra native calls (_taRequireInstance did buf.binaryKind per read).
    // Internal callers always pass a real view; a foreign receiver simply has
    // no _buffer and returns undefined.
    const buffer = this._buffer;
    if (!buffer || buffer._detached || _taIsOutOfBounds(this)) return undefined;
    if (idx < 0 || idx >= _taLength(this)) return undefined;
    return this._getter(buffer._ptr, (this._byteOffset || 0) + idx * this.BYTES_PER_ELEMENT);
  };
  proto._writeAt = function(idx, v) {
    // IntegerIndexedElementSet: ToNumber/ToBigInt BEFORE IsValidIntegerIndex.
    // Invalid index / detach after coerce → silent success; conversion may throw.
    _taRequireInstance(this, '_writeAt');
    if (!this._buffer) return;
    const isBig = this._typedArrayName === 'BigInt64Array' || this._typedArrayName === 'BigUint64Array';
    var coerced;
    if (isBig) {
      coerced = _toBigIntStrict(v);
    } else {
      // Inline ToNumber with OrdinaryToPrimitive — must TypeError when valueOf/toString
      // both return objects (makePassthrough / throws-setting-obj-valueof-typeerror).
      if (typeof v === 'number') {
        coerced = v;
      } else if (typeof v === 'bigint') {
        throw new TypeError('Cannot convert a BigInt value to a number');
      } else if (v === null || (typeof v !== 'object' && typeof v !== 'function')) {
        coerced = Number(v);
      } else {
        // Prefer shared ToPrimitive (non-callable @@toPrimitive → TypeError).
        coerced = _toNumberStrict(v);
      }
    }
    // Revalidate after observable coercion (detach / RAB resize / OOB) —
    // inline, allocation-free (this is the per-element write hot path).
    const buffer2 = this._buffer;
    if (!buffer2 || buffer2._detached || _taIsOutOfBounds(this)) return;
    if (idx < 0 || idx >= _taLength(this)) return;
    if (buffer2._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    this._setter(buffer2._ptr, (this._byteOffset || 0) + idx * this.BYTES_PER_ELEMENT, coerced);
  };

  proto.subarray = function(begin, end) {
    // Native fast path (default species, numeric/undefined begin/end, live
    // in-bounds view): builds the result view natively. undefined → the
    // spec-complete path below (species, observable coercion, detached/OOB errors).
    if (typeof buf.taSubarray === 'function') {
      const fastView = buf.taSubarray(this, begin, end, arguments.length > 1);
      if (fastView !== undefined) return fastView;
    }
    _taValidate(this, 'subarray');
    const len = _taLength(this);
    const endProvided = arguments.length > 1;
    const coerced = _coerceThenWitness(this, function() {
      return {
        start: _taRelativeStart(begin, len),
        fin: endProvided ? _taRelativeEnd(end, len) : len
      };
    }, 'throw');
    // Revalidate after species getter (may detach / resize RAB).
    const C = _taSpeciesConstructor(this);
    _revalidateWitness(this, coerced.witness, 'throw');
    const start = coerced.value.start;
    const fin = Math.min(coerced.value.fin, _taLength(this));
    const newLen = Math.max(fin - start, 0);
    const byteOff = this._byteOffset + start * this.BYTES_PER_ELEMENT;
    // Length-tracking + end undefined → Construct(C, «buffer, byteOffset») only
    // so the result remains length-tracking over the remainder of the buffer.
    if (this._fixedLength !== true && !endProvided) {
      return new C(this._buffer, byteOff);
    }
    return new C(this._buffer, byteOff, newLen);
  };
  // Native `subarray` (buffer_native.jac ta_subarray_method): the JS method
  // above becomes its registered slow path (species, coercion, errors).
  if (typeof buf.taSubarrayMethod === 'function' && typeof buf.setTaSubarraySlow === 'function') {
    buf.setTaSubarraySlow(proto.subarray);
    proto.subarray = buf.taSubarrayMethod;
  }
  proto.slice = function(begin, end) {
    // Native copy for the default species (fresh ArrayBuffer + memcpy).
    if (typeof buf.taSlice === 'function') {
      const fastSlice = buf.taSlice(this, begin, end);
      if (fastSlice !== undefined) return fastSlice;
    }
    _taValidate(this, 'slice');
    const len = _taLength(this);
    const coerced = _coerceThenWitness(this, function() {
      return {
        start: _taRelativeStart(begin, len),
        fin: _taRelativeEnd(end, len)
      };
    }, 'throw');
    const newLen = Math.max(coerced.value.fin - coerced.value.start, 0);
    _checkAllocLimit(newLen * (this.BYTES_PER_ELEMENT || 1));
    const result = _taSpeciesCreate(this, newLen);
    // Zero-count / detach-during-species: soft revalidate (may succeed with empty copy).
    const w2 = _revalidateWitness(this, coerced.witness, newLen === 0 ? 'soft' : 'throw');
    const bpe = this.BYTES_PER_ELEMENT;
    if (!w2.valid || w2.detached || w2.oob) {
      return result;
    }
    const copyLen = Math.min(newLen, _taLength(this) - coerced.value.start);
    if (copyLen > 0) {
      buf.copy(result._buffer._ptr, 0, this._buffer._ptr, this._byteOffset + coerced.value.start * bpe, copyLen * bpe);
    }
    return result;
  };
  proto.set = function(array, offset) {
    // Native SetTypedArrayFromTypedArray (memmove / int convert loop); undefined
    // → the spec path below (array-likes, float/bigint conversions, errors).
    if (typeof buf.taSet === 'function' && buf.taSet(this, array, offset) === true) return;
    _taValidate(this, 'set');
    if (this._buffer && this._buffer._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    const coercedOff = _coerceThenWitness(this, function() {
      return offset === undefined ? 0 : _toIntegerOrInfinity(offset);
    }, 'throw');
    var rel = coercedOff.value;
    if (rel < 0 || rel === -Infinity || rel === Infinity || rel !== Math.floor(rel)) {
      throw new RangeError('Offset is out of bounds');
    }
    var off = rel;
    var len = coercedOff.witness.length;
    var srcIsTA = array && typeof buf.binaryKind === 'function' && buf.binaryKind(array) === 2;
    var srcLen;
    if (srcIsTA) {
      _taValidate(array, 'set');
      srcLen = _taLength(array);
    } else if (array != null && typeof array === 'object') {
      srcLen = _lengthOfArrayLike(array);
    } else {
      throw new TypeError('Invalid typed array / array-like');
    }
    // Fail-fast before element loops (coercion getters may report huge lengths).
    _checkAllocLimit(srcLen * (this.BYTES_PER_ELEMENT || 1));
    // Revalidate target after LengthOfArrayLike / source validation (observable).
    var live = _revalidateWitness(this, coercedOff.witness, 'throw');
    len = live.length;
    if (off + srcLen > len) {
      throw new RangeError('Offset is out of bounds');
    }
    if (srcIsTA) {
      var srcLive = _taLength(array);
      if (srcLive < srcLen) srcLen = srcLive;
      if (off + srcLen > len) {
        throw new RangeError('Offset is out of bounds');
      }
      // Same-buffer overlap: stage into a temporary copy (SetTypedArrayFromTypedArray).
      if (array._buffer === this._buffer) {
        _checkAllocLimit(srcLen * (this.BYTES_PER_ELEMENT || 1));
        var tmp = new this._ctor(srcLen);
        var ti = 0;
        for (; ti < srcLen; ti++) {
          if (ti > 0 && (ti & 0xffff) === 0) {
            _checkAllocLimit(srcLen * (this.BYTES_PER_ELEMENT || 1));
          }
          tmp._writeAt(ti, array._readAt(ti));
        }
        array = tmp;
      }
      var i = 0;
      for (; i < srcLen; i++) {
        // Live length: RAB may shrink mid-iteration; stop silently past new length.
        const curLen = _taLength(this);
        if (off + i >= curLen) break;
        this._writeAt(off + i, array._readAt(i));
      }
      return;
    }
    var j = 0;
    for (; j < srcLen; j++) {
      const curLen = _taLength(this);
      if (off + j >= curLen) break;
      this._writeAt(off + j, array[j]);
    }
  };
  proto.fill = function(value, start, end) {
    _taValidate(this, 'fill');
    if (this._buffer && this._buffer._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    // Coerce value first (observable), then start/end, revalidate between.
    const isBig = this._typedArrayName === 'BigInt64Array' || this._typedArrayName === 'BigUint64Array';
    var filled = isBig ? _toBigIntStrict(value) : _toNumberStrict(value);
    _revalidateWitness(this, null, 'throw');
    const len = _taLength(this);
    const s = _taRelativeStart(start, len);
    _revalidateWitness(this, null, 'throw');
    const e = _taRelativeEnd(end, len);
    const w = _revalidateWitness(this, null, 'throw');
    // Fast path: 1-byte integer kinds on a plain (non-resizable) buffer are a
    // memset. The per-element loop below re-validates the view on EVERY
    // element (a witness object each time): 22µs/element, 22s for a 1MB
    // Uint8Array.fill(65) (600 GC cycles under --gc).
    if (!isBig && typeof filled === 'number' && this.BYTES_PER_ELEMENT === 1 &&
        (this._typedArrayName === 'Uint8Array' || this._typedArrayName === 'Int8Array') &&
        !(this._buffer && (this._buffer._resizable || this._buffer._growable || this._buffer._immutable)) &&
        e > s && w.length > s && typeof buf.fill === 'function') {
      const n1 = Math.min(e, w.length) - s;
      buf.fill(this._buffer._ptr, this._byteOffset + s, n1, Math.trunc(filled) & 0xff);
      return this;
    }
    // Store the already-coerced value — do NOT re-enter ToNumber/ToBigInt via _writeAt
    // (fill-values-non-numeric stack overflow / double ToPrimitive).
    var i = s;
    for (; i < e && i < w.length; i++) {
      const cur = _revalidateWitness(this, w, 'oobZero');
      if (cur.length === 0) break;
      if (i < 0 || i >= cur.length) break;
      if (this._buffer && this._buffer._immutable) {
        throw new TypeError('Cannot modify an immutable ArrayBuffer');
      }
      this._setter(this._buffer._ptr, this._byteOffset + i * this.BYTES_PER_ELEMENT, filled);
    }
    return this;
  };
  proto.indexOf = function(searchElement, fromIndex) {
    _taValidate(this, 'indexOf');
    // Capture length before fromIndex coercion (may detach/resize).
    const before = _binaryViewWitness(this);
    const lenCap = before.length;
    if (lenCap === 0) return -1;
    const n = fromIndex === undefined ? 0 : _toIntegerOrInfinity(fromIndex);
    // Soft after coercion: detached/OOB → HasProperty false for all indices → -1.
    // Do not match `undefined === undefined` via _readAt on a detached buffer.
    const after = _revalidateWitness(this, before, 'soft');
    if (after.detached || after.oob || !after.valid) return -1;
    if (n === Infinity) return -1;
    var i = n === -Infinity ? 0 : (n < 0 ? Math.max(lenCap + n, 0) : Math.min(n, lenCap));
    if (i === 0) i = 0; // canonicalize -0
    for (; i < lenCap; i++) {
      if (this._buffer && this._buffer._detached) return -1;
      if (this._readAt(i) === searchElement) return i === 0 ? 0 : i;
    }
    return -1;
  };
  proto.lastIndexOf = function(searchElement, fromIndex) {
    _taValidate(this, 'lastIndexOf');
    const before = _binaryViewWitness(this);
    const lenCap = before.length;
    if (lenCap === 0) return -1;
    const n = fromIndex === undefined ? (lenCap - 1) : _toIntegerOrInfinity(fromIndex);
    const after = _revalidateWitness(this, before, 'soft');
    if (after.detached || after.oob || !after.valid) return -1;
    if (n === -Infinity) return -1;
    var i = n < 0 ? lenCap + n : Math.min(n, lenCap - 1);
    if (i === 0) i = 0; // canonicalize -0
    for (; i >= 0; i--) {
      if (this._buffer && this._buffer._detached) return -1;
      if (this._readAt(i) === searchElement) return i === 0 ? 0 : i;
    }
    return -1;
  };
  proto.includes = function(searchElement, fromIndex) {
    _taValidate(this, 'includes');
    const before = _binaryViewWitness(this);
    const lenCap = before.length;
    if (lenCap === 0) return false;
    const n = fromIndex === undefined ? 0 : _toIntegerOrInfinity(fromIndex);
    const after = _revalidateWitness(this, before, 'soft');
    if (after.detached || after.oob || !after.valid) return false;
    if (n === Infinity) return false;
    var i = n === -Infinity ? 0 : (n < 0 ? Math.max(lenCap + n, 0) : Math.min(n, lenCap));
    if (i === 0) i = 0;
    for (; i < lenCap; i++) {
      if (this._buffer && this._buffer._detached) return false;
      if (_sameValueZero(this._readAt(i), searchElement)) return true;
    }
    return false;
  };
  proto.join = function(separator) {
    _taValidate(this, 'join');
    // Capture length before separator coercion (may detach). Soft after ToString:
    // still emit sep between undefined slots rather than throw mid-build.
    const lenCap = _taLength(this);
    const sep = separator === undefined ? ',' : String(separator);
    let result = '';
    var i = 0;
    for (; i < lenCap; i++) {
      if (i > 0) result += sep;
      const v = this._readAt(i);
      if (v !== undefined && v !== null) result += String(v);
    }
    return result;
  };
  proto.toString = function() { return this.join(','); };

  proto.forEach = function(callback, thisArg) {
    _taValidate(this, 'forEach');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    // Spec captures len up front; detach mid-loop still visits all k < len
    // (Get returns undefined for detached IntegerIndexedElementGet).
    for (; i < len; i++) {
      callback.call(thisArg, this._readAt(i), i, this);
    }
  };
  proto.map = function(callback, thisArg) {
    _taValidate(this, 'map');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    _checkAllocLimit(len * (this.BYTES_PER_ELEMENT || 1));
    // SpeciesCreate before the callback loop (ES map).
    const result = _taSpeciesCreate(this, len);
    var i = 0;
    for (; i < len; i++) {
      result._writeAt(i, callback.call(thisArg, this._readAt(i), i, this));
    }
    return result;
  };
  proto.filter = function(callback, thisArg) {
    _taValidate(this, 'filter');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    const kept = [];
    var i = 0;
    for (; i < len; i++) {
      const v = this._readAt(i);
      if (callback.call(thisArg, v, i, this)) kept.push(v);
    }
    // SpeciesCreate after the callback loop (ES filter).
    const result = _taSpeciesCreate(this, kept.length);
    for (i = 0; i < kept.length; i++) result._writeAt(i, kept[i]);
    return result;
  };
  proto.reduce = function(callback, initialValue) {
    _taValidate(this, 'reduce');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    var acc;
    if (arguments.length >= 2) {
      acc = initialValue;
    } else {
      if (len === 0) throw new TypeError('Reduce of empty array with no initial value');
      acc = this._readAt(0);
      i = 1;
    }
    // Capture len up front; after detach Get returns undefined but loop continues.
    for (; i < len; i++) {
      acc = callback(acc, this._readAt(i), i, this);
    }
    return acc;
  };
  proto.reduceRight = function(callback, initialValue) {
    _taValidate(this, 'reduceRight');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = len - 1;
    var acc;
    if (arguments.length >= 2) {
      acc = initialValue;
    } else {
      if (len === 0) throw new TypeError('Reduce of empty array with no initial value');
      acc = this._readAt(i);
      i--;
    }
    for (; i >= 0; i--) {
      acc = callback(acc, this._readAt(i), i, this);
    }
    return acc;
  };
  proto.every = function(callback, thisArg) {
    _taValidate(this, 'every');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    for (; i < len; i++) {
      if (!callback.call(thisArg, this._readAt(i), i, this)) return false;
    }
    return true;
  };
  proto.some = function(callback, thisArg) {
    _taValidate(this, 'some');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    for (; i < len; i++) {
      if (callback.call(thisArg, this._readAt(i), i, this)) return true;
    }
    return false;
  };
  proto.find = function(callback, thisArg) {
    _taValidate(this, 'find');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    for (; i < len; i++) {
      const v = this._readAt(i);
      if (callback.call(thisArg, v, i, this)) return v;
    }
    return undefined;
  };
  proto.findIndex = function(callback, thisArg) {
    _taValidate(this, 'findIndex');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    for (; i < len; i++) {
      if (callback.call(thisArg, this._readAt(i), i, this)) return i;
    }
    return -1;
  };
  proto.findLast = function(callback, thisArg) {
    _taValidate(this, 'findLast');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = len - 1;
    for (; i >= 0; i--) {
      const v = this._readAt(i);
      if (callback.call(thisArg, v, i, this)) return v;
    }
    return undefined;
  };
  proto.findLastIndex = function(callback, thisArg) {
    _taValidate(this, 'findLastIndex');
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = len - 1;
    for (; i >= 0; i--) {
      if (callback.call(thisArg, this._readAt(i), i, this)) return i;
    }
    return -1;
  };
  proto.copyWithin = function(target, start, end) {
    _taValidate(this, 'copyWithin');
    if (this._buffer && this._buffer._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    // Capture length before ToInteger coercions (may detach/resize RAB).
    const lenBefore = _taLength(this);
    const coerced = _coerceThenWitness(this, function() {
      var relTarget = _toIntegerOrInfinity(target);
      if (relTarget === -Infinity) relTarget = 0;
      if (relTarget === Infinity) relTarget = lenBefore;
      var to0 = relTarget < 0 ? Math.max(lenBefore + relTarget, 0) : Math.min(relTarget, lenBefore);
      var s0 = _taRelativeStart(start, lenBefore);
      var e0 = end === undefined ? lenBefore : _taRelativeEnd(end, lenBefore);
      return { to: to0, s: s0, e: e0 };
    }, 'throw');
    var to = coerced.value.to;
    var s = coerced.value.s;
    var e = coerced.value.e;
    // Spec: count from captured length, then clamp to post-coercion live length.
    var count = Math.min(e - s, lenBefore - to);
    if (!(count > 0) || count !== count || count === Infinity) return this;
    const w = coerced.witness;
    if (w.detached || w.oob) {
      throw new TypeError('Cannot perform TypedArray operation on a detached or out-of-bounds TypedArray');
    }
    const liveLen = w.length;
    count = Math.min(count, liveLen - to, liveLen - s);
    if (!(count > 0) || count !== count) return this;
    const bpe = this.BYTES_PER_ELEMENT || 1;
    _checkAllocLimit(count * bpe);
    const w2 = _revalidateWitness(this, w, 'throw');
    count = Math.min(count, w2.length - to, w2.length - s);
    if (!(count > 0) || count !== count) return this;
    const byteCount = count * bpe;
    if (!(byteCount > 0) || byteCount !== byteCount || byteCount > _AB_ALLOC_LIMIT) {
      throw new RangeError('TypedArray copy length too large');
    }
    buf.copy(
      this._buffer._ptr, this._byteOffset + to * bpe,
      this._buffer._ptr, this._byteOffset + s * bpe,
      byteCount
    );
    return this;
  };
  proto.reverse = function() {
    _taValidate(this, 'reverse');
    if (this._buffer && this._buffer._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    var i = 0;
    var j = len - 1;
    for (; i < j; i++, j--) {
      const cur = _revalidateWitness(this, w0, 'oobZero');
      if (cur.length === 0) break;
      const tmp = this._readAt(i);
      this._writeAt(i, this._readAt(j));
      this._writeAt(j, tmp);
    }
    return this;
  };
  proto.sort = function(compareFn) {
    _taValidate(this, 'sort');
    if (this._buffer && this._buffer._immutable) {
      throw new TypeError('Cannot modify an immutable ArrayBuffer');
    }
    const w0 = _binaryViewWitness(this);
    const len = w0.length;
    if (len <= 1) return this;
    var arr = [];
    var i = 0;
    for (; i < len; i++) {
      const cur = _revalidateWitness(this, w0, 'oobZero');
      if (cur.length === 0 || i >= cur.length) break;
      arr.push(this._readAt(i));
    }
    if (compareFn !== undefined) {
      if (typeof compareFn !== 'function') throw new TypeError('Compare must be a function');
      arr.sort(compareFn);
    } else {
      arr.sort(function(a, b) {
        if (a === b) return 0;
        if (a !== a) return 1;
        if (b !== b) return -1;
        return a < b ? -1 : 1;
      });
    }
    i = 0;
    for (; i < arr.length; i++) {
      const cur = _revalidateWitness(this, w0, 'throw');
      if (i >= cur.length) break;
      this._writeAt(i, arr[i]);
    }
    return this;
  };
  proto.toReversed = function() {
    _taValidate(this, 'toReversed');
    const w0 = _revalidateWitness(this, null, 'throw');
    const len = w0.length;
    // TypedArrayCreateSameType — ignore species.
    const result = _taCreateSameType(this, len);
    var i = 0;
    for (; i < len; i++) {
      result._writeAt(i, this._readAt(len - 1 - i));
    }
    return result;
  };
  proto.toSorted = function(compareFn) {
    _taValidate(this, 'toSorted');
    const w0 = _revalidateWitness(this, null, 'throw');
    const len = w0.length;
    var arr = [];
    var i = 0;
    for (; i < len; i++) {
      arr.push(this._readAt(i));
    }
    if (compareFn !== undefined) {
      if (typeof compareFn !== 'function') throw new TypeError('Compare must be a function');
      arr.sort(compareFn);
    } else {
      arr.sort(function(a, b) {
        if (a === b) return 0;
        if (a !== a) return 1;
        if (b !== b) return -1;
        return a < b ? -1 : 1;
      });
    }
    const result = _taCreateSameType(this, len);
    i = 0;
    for (; i < arr.length; i++) result._writeAt(i, arr[i]);
    return result;
  };
  proto.with = function(index, value) {
    _taValidate(this, 'with');
    const coerced = _coerceThenWitness(this, function() {
      return _toIntegerOrInfinity(index);
    }, 'throw');
    const len = coerced.witness.length;
    const n = coerced.value;
    const k = n < 0 ? len + n : n;
    if (k < 0 || k >= len) throw new RangeError('Invalid index');
    // Coerce replacement value before allocate (IntegerIndexedElementSet order).
    const isBig = this._typedArrayName === 'BigInt64Array' || this._typedArrayName === 'BigUint64Array';
    const coercedVal = isBig ? _toBigIntStrict(value) : _toNumberStrict(value);
    const live = _revalidateWitness(this, coerced.witness, 'throw');
    const result = _taCreateSameType(this, live.length);
    var i = 0;
    for (; i < live.length; i++) {
      result._writeAt(i, i === k ? coercedVal : this._readAt(i));
    }
    return result;
  };
  proto.at = function(index) {
    _taValidate(this, 'at');
    // TypedArrayLength before ToIntegerOrInfinity (index coercion may resize/detach).
    const before = _binaryViewWitness(this);
    const len = before.length;
    const n = _toIntegerOrInfinity(index);
    const cur = _revalidateWitness(this, before, 'soft');
    if (!cur.valid || cur.detached || cur.oob) return undefined;
    const k = n < 0 ? len + n : n;
    // Bounds check uses pre-coercion len for relative index; Get uses live state.
    if (k < 0 || k >= len) return undefined;
    if (k >= cur.length) return undefined;
    return this._readAt(k);
  };
  proto.entries = function() {
    _taValidate(this, 'entries');
    return _taMakeArrayIterator(this, 2);
  };
  proto.keys = function() {
    _taValidate(this, 'keys');
    return _taMakeArrayIterator(this, 0);
  };
  proto.values = function() {
    _taValidate(this, 'values');
    return _taMakeArrayIterator(this, 1);
  };
  // Spec: %TypedArray%.prototype[@@iterator] is the same function as .values.
  proto[Symbol.iterator] = proto.values;

  // Builtin methods must not implement [[Construct]] and must be non-enumerable.
  // Spec length ignores optional trailing params (thisArg, compareFn, etc.).
  const _taMethodMeta = [
    ['subarray', 2], ['slice', 2], ['set', 1], ['fill', 1],
    ['indexOf', 1], ['lastIndexOf', 1], ['includes', 1],
    ['join', 1], ['toString', 0], ['toLocaleString', 0],
    ['forEach', 1], ['map', 1], ['filter', 1], ['reduce', 1], ['reduceRight', 1],
    ['every', 1], ['some', 1], ['find', 1], ['findIndex', 1],
    ['findLast', 1], ['findLastIndex', 1],
    ['copyWithin', 2], ['reverse', 0], ['sort', 1],
    ['toReversed', 0], ['toSorted', 1], ['with', 2], ['at', 1],
    ['entries', 0], ['keys', 0], ['values', 0]
  ];
  proto.toLocaleString = function() {
    // Array.prototype.toLocaleString applied to this TypedArray (ES §23.2.3.28):
    // for each element Invoke(element, "toLocaleString") — which for numbers goes
    // through Number.prototype.toLocaleString / ToObject. Use join-like String(v)
    // only as fallback when toLocaleString is missing.
    _taValidate(this, 'toLocaleString');
    const sep = ',';
    _revalidateWitness(this, null, 'throw');
    let result = '';
    const len = _taLength(this);
    var i = 0;
    for (; i < len; i++) {
      if (i > 0) result += sep;
      const v = this._readAt(i);
      if (v === undefined || v === null) continue;
      // Invoke(v, "toLocaleString") — prefer Number/BigInt boxed path via value's method.
      const fn = (typeof v === 'object' || typeof v === 'function')
        ? v.toLocaleString
        : (typeof v === 'bigint'
          ? BigInt.prototype.toLocaleString
          : Number.prototype.toLocaleString);
      if (typeof fn === 'function') {
        result += String(fn.call(v));
      } else {
        result += String(v);
      }
    }
    return result;
  };
  var _tmi = 0;
  for (; _tmi < _taMethodMeta.length; _tmi++) {
    const _name = _taMethodMeta[_tmi][0];
    const _len = _taMethodMeta[_tmi][1];
    const _tm = proto[_name];
    if (typeof _tm === 'function') {
      _rejectConstruct(_tm);
      _installMeta(_tm, _name, _len);
      Object.defineProperty(proto, _name, {
        value: _tm, writable: true, enumerable: false, configurable: true
      });
    }
  }
  if (typeof Symbol !== 'undefined' && Symbol.iterator !== undefined) {
    Object.defineProperty(proto, Symbol.iterator, {
      value: proto.values, writable: true, enumerable: false, configurable: true
    });
  }
}

// ─── Byte-level get/set functions for each element type ─────────────────────
// Platform is little-endian (x86-64). TypedArrays use platform byte order.

function _getU8(ptr, off)       { return buf.getByte(ptr, off); }
function _setU8(ptr, off, v)    { buf.setByte(ptr, off, v & 0xFF); }

function _clampU8(v) {
  // ToUint8Clamp — IEEE round half to even (ties-to-even).
  v = +v;
  if (v !== v || v <= 0) return 0;
  if (v >= 255) return 255;
  const f = Math.floor(v);
  const frac = v - f;
  if (frac > 0.5) return f + 1;
  if (frac < 0.5) return f;
  return (f & 1) === 0 ? f : f + 1;
}

function _setU8Clamped(ptr, off, v) { buf.setByte(ptr, off, _clampU8(v)); }

function _getI8(ptr, off)       { const b = buf.getByte(ptr, off); return b > 127 ? b - 256 : b; }
function _setI8(ptr, off, v)    { buf.setByte(ptr, off, v & 0xFF); }

function _getU16(ptr, off)      { return buf.getByte(ptr, off) | (buf.getByte(ptr, off + 1) << 8); }
function _setU16(ptr, off, v)   { buf.setByte(ptr, off, v & 0xFF); buf.setByte(ptr, off + 1, (v >>> 8) & 0xFF); }

function _getI16(ptr, off)      { const u = _getU16(ptr, off); return u > 32767 ? u - 65536 : u; }
function _setI16(ptr, off, v)   { _setU16(ptr, off, v); }

function _getU32(ptr, off) {
  return (buf.getByte(ptr, off) | (buf.getByte(ptr, off+1) << 8) |
          (buf.getByte(ptr, off+2) << 16) | (buf.getByte(ptr, off+3) << 24)) >>> 0;
}
function _setU32(ptr, off, v) {
  buf.setByte(ptr, off,   v & 0xFF);
  buf.setByte(ptr, off+1, (v >>> 8)  & 0xFF);
  buf.setByte(ptr, off+2, (v >>> 16) & 0xFF);
  buf.setByte(ptr, off+3, (v >>> 24) & 0xFF);
}

function _getI32(ptr, off) {
  return buf.getByte(ptr, off) | (buf.getByte(ptr, off+1) << 8) |
         (buf.getByte(ptr, off+2) << 16) | (buf.getByte(ptr, off+3) << 24);
}
function _setI32(ptr, off, v) { _setU32(ptr, off, v); }

// Float get/set -- IEEE 754 encoding/decoding in pure JS.

function _getF32(ptr, off) {
  const bits = (buf.getByte(ptr, off) | (buf.getByte(ptr, off+1) << 8) |
                (buf.getByte(ptr, off+2) << 16) | (buf.getByte(ptr, off+3) << 24)) >>> 0;
  return _f32BitsToNumber(bits);
}
function _setF32(ptr, off, v) {
  const bits = _numberToF32Bits(v);
  buf.setByte(ptr, off,   bits & 0xFF);
  buf.setByte(ptr, off+1, (bits >>> 8)  & 0xFF);
  buf.setByte(ptr, off+2, (bits >>> 16) & 0xFF);
  buf.setByte(ptr, off+3, (bits >>> 24) & 0xFF);
}

function _getF16(ptr, off) {
  const bits = (buf.getByte(ptr, off) | (buf.getByte(ptr, off + 1) << 8)) & 0xFFFF;
  return _f16BitsToF64(bits);
}
function _setF16(ptr, off, v) {
  const bits = _f64ToF16Bits(v);
  buf.setByte(ptr, off, bits & 0xFF);
  buf.setByte(ptr, off + 1, (bits >>> 8) & 0xFF);
}

function _getF64(ptr, off) {
  const lo = (buf.getByte(ptr, off)   | (buf.getByte(ptr, off+1) << 8) |
              (buf.getByte(ptr, off+2) << 16) | (buf.getByte(ptr, off+3) << 24)) >>> 0;
  const hi = (buf.getByte(ptr, off+4) | (buf.getByte(ptr, off+5) << 8) |
              (buf.getByte(ptr, off+6) << 16) | (buf.getByte(ptr, off+7) << 24)) >>> 0;
  return _f64BitsToNumber(hi, lo);
}
function _setF64(ptr, off, v) {
  const parts = _numberToF64Bits(v);
  const lo = parts[0];
  const hi = parts[1];
  buf.setByte(ptr, off,   lo & 0xFF);
  buf.setByte(ptr, off+1, (lo >>> 8)  & 0xFF);
  buf.setByte(ptr, off+2, (lo >>> 16) & 0xFF);
  buf.setByte(ptr, off+3, (lo >>> 24) & 0xFF);
  buf.setByte(ptr, off+4, hi & 0xFF);
  buf.setByte(ptr, off+5, (hi >>> 8)  & 0xFF);
  buf.setByte(ptr, off+6, (hi >>> 16) & 0xFF);
  buf.setByte(ptr, off+7, (hi >>> 24) & 0xFF);
}

// ─── IEEE 754 float <-> bits conversion (pure JS) ───────────────────────────

var _mathFround = Math.fround;
function _f32BitsToNumber(bits) {
  const sign = (bits >>> 31) ? -1 : 1;
  const exp  = (bits >>> 23) & 0xFF;
  const frac =  bits & 0x7FFFFF;
  if (exp === 0xFF) return frac ? NaN : sign * Infinity;
  // Preserve IEEE-754 signed zero — engine arithmetic may collapse `-1 * 0` to +0.
  if (exp === 0) {
    if (frac === 0) return sign < 0 ? -0 : 0;
    return sign * frac * 1.401298464324817e-45; // 2^-149
  }
  return sign * Math.pow(2, exp - 127) * (1 + frac / 0x800000);
}

/**
 * Bit-exact IEEE754 binary32 encoding (round ties to even).
 * Pure arithmetic — must not construct Float32Array (ctors write via these helpers).
 */
function _numberToF32Bits(v) {
  if (v !== v) return 0x7FC00000; // canonical qNaN
  // Round to binary32 first (native, ties to even): every step below is then
  // exact (the Math.round mantissa step rounded half-way cases up).
  v = _mathFround(v);
  if (v === Infinity) return 0x7F800000;
  if (v === -Infinity) return 0xFF800000;
  if (v === 0) return (1 / v === -Infinity) ? 0x80000000 : 0;

  var sign = 0;
  if (v < 0) { sign = 0x80000000; v = -v; }
  if (v >= 3.4028234663852886e+38) return (sign | 0x7F800000) >>> 0;

  var exp = Math.floor(Math.log(v) / Math.LN2);
  var e2 = Math.pow(2, exp);
  // Correct exp when log is slightly off (common near powers of two).
  while (v < e2) { exp--; e2 = Math.pow(2, exp); }
  while (v >= e2 * 2) { exp++; e2 = Math.pow(2, exp); }

  if (exp > 127) return (sign | 0x7F800000) >>> 0;

  var mant;
  if (exp < -126) {
    // Subnormal
    mant = Math.round(v / Math.pow(2, -149));
    if (mant >= 0x800000) return (sign | 0x00800000) >>> 0; // round up to min normal
    return (sign | mant) >>> 0;
  }

  mant = Math.round((v / e2 - 1) * 0x800000);
  if (mant === 0x800000) {
    mant = 0;
    exp++;
    if (exp > 127) return (sign | 0x7F800000) >>> 0;
  }
  // Ties-to-even already approximated by Math.round; refine half-way cases.
  return (sign | ((exp + 127) << 23) | (mant & 0x7FFFFF)) >>> 0;
}

function _roundTiesToEven(value) {
  const floor = Math.floor(value);
  const fraction = value - floor;
  if (fraction < 0.5) return floor;
  if (fraction > 0.5) return floor + 1;
  return (floor % 2 === 0) ? floor : floor + 1;
}

function _f64ToF16Bits(value) {
  const number = Number(value);
  if (number !== number) return 0x7E00;
  const negative = number < 0 || (number === 0 && 1 / number === -Infinity);
  const sign = negative ? 0x8000 : 0;
  const magnitude = negative ? -number : number;
  if (magnitude === Infinity || magnitude >= 65520) return sign | 0x7C00;
  if (magnitude === 0) return sign;

  if (magnitude < Math.pow(2, -14)) {
    const fraction = _roundTiesToEven(magnitude / Math.pow(2, -24));
    return sign | fraction;
  }

  let exponent = Math.floor(Math.log(magnitude) / Math.LN2);
  while (magnitude < Math.pow(2, exponent)) exponent--;
  while (magnitude >= Math.pow(2, exponent + 1)) exponent++;
  let fraction = _roundTiesToEven(
    (magnitude / Math.pow(2, exponent) - 1) * 1024
  );
  if (fraction === 1024) {
    fraction = 0;
    exponent++;
  }
  if (exponent > 15) return sign | 0x7C00;
  return sign | ((exponent + 15) << 10) | fraction;
}

function _f16BitsToF64(bits) {
  bits = bits & 0xFFFF;
  const sign = (bits & 0x8000) ? -1 : 1;
  const exponent = (bits >>> 10) & 0x1F;
  const fraction = bits & 0x03FF;
  if (exponent === 0x1F) return fraction ? NaN : sign * Infinity;
  if (exponent === 0) {
    if (fraction === 0) return sign < 0 ? -0 : 0;
    return sign * fraction * Math.pow(2, -24);
  }
  return sign * Math.pow(2, exponent - 15) * (1 + fraction / 1024);
}

if (typeof Math !== 'undefined' && typeof Math.f16round !== 'function') {
  const f16round = function(value) {
    return _f16BitsToF64(_f64ToF16Bits(value));
  };
  _rejectConstruct(f16round);
  _installMeta(f16round, 'f16round', 1);
  Object.defineProperty(Math, 'f16round', {
    value: f16round, writable: true, enumerable: false, configurable: true
  });
}

function _f64BitsToNumber(hi, lo) {
  const sign   = (hi >>> 31) ? -1 : 1;
  const exp    = (hi >>> 20) & 0x7FF;
  const fracHi = hi & 0xFFFFF;
  if (exp === 0x7FF) return (fracHi || lo) ? NaN : sign * Infinity;
  // Preserve IEEE-754 signed zero — engine arithmetic may collapse `-1 * 0` to +0.
  if (exp === 0) {
    if (fracHi === 0 && lo === 0) return sign < 0 ? -0 : 0;
    return sign * (fracHi * 4294967296 + lo) * 5e-324;
  }
  return sign * Math.pow(2, exp - 1023) * (1 + (fracHi * 4294967296 + lo) / 4503599627370496);
}

/**
 * Bit-exact IEEE754 binary64 encoding → [lo, hi] little-endian words.
 * Pure arithmetic — must not construct Float64Array (ctors write via these helpers).
 */
function _numberToF64Bits(v) {
  if (v !== v) return [0, 0x7FF80000]; // canonical qNaN
  if (v === Infinity) return [0, 0x7FF00000];
  if (v === -Infinity) return [0, 0xFFF00000];
  if (v === 0) return (1 / v === -Infinity) ? [0, 0x80000000] : [0, 0];

  var signBit = 0;
  if (v < 0) { signBit = 0x80000000; v = -v; }
  if (v >= 1.7976931348623157e+308) return [0, (signBit | 0x7FF00000) >>> 0];

  var exp = Math.floor(Math.log(v) / Math.LN2);
  var e2 = Math.pow(2, exp);
  while (v < e2) { exp--; e2 = Math.pow(2, exp); }
  while (v >= e2 * 2) { exp++; e2 = Math.pow(2, exp); }

  if (exp > 1023) return [0, (signBit | 0x7FF00000) >>> 0];

  var mant;
  if (exp < -1022) {
    mant = Math.round(v / Math.pow(2, -1074));
    if (mant >= 4503599627370496) {
      // Round up to min normal
      return [0, (signBit | 0x00100000) >>> 0];
    }
    var loS = mant % 4294967296;
    if (loS < 0) loS += 4294967296;
    var hiS = Math.floor(mant / 4294967296);
    return [loS >>> 0, (signBit | hiS) >>> 0];
  }

  mant = Math.round((v / e2 - 1) * 4503599627370496);
  if (mant === 4503599627370496) {
    mant = 0;
    exp++;
    if (exp > 1023) return [0, (signBit | 0x7FF00000) >>> 0];
  }
  var lo = mant % 4294967296;
  if (lo < 0) lo += 4294967296;
  var hi = Math.floor(mant / 4294967296);
  return [lo >>> 0, (signBit | ((exp + 1023) << 20) | hi) >>> 0];
}

// ─── BigInt64 / BigUint64 byte composition ──────────────────────────────────

const _B32 = 4294967296n;

function _toBigInt(value) {
  if (typeof value === 'bigint') return value;
  return BigInt(value);
}

function _uint32PairToBigInt(hi, lo) {
  return _toBigInt(hi >>> 0) * _B32 + _toBigInt(lo >>> 0);
}

function _unsigned64ToSignedBigInt(u) {
  if (u === 18446744073709551615n) return -1n;
  if (u >= 9223372036854775808n) {
    return u - 18446744073709551616n;
  }
  return u;
}

function _bigintToUint32Number(bi) {
  // Number(bigint) is a TypeError (ES ToNumber). Split via decimal string instead.
  const n = Number(String(bi));
  return n >>> 0;
}

function _bigIntToHiLo(v) {
  if (typeof v !== 'bigint') v = _toBigInt(v);
  // Normalize into [0, 2^64) before splitting (handles large negatives / overflow).
  const MOD = 18446744073709551616n;
  let u = v % MOD;
  if (u < 0n) u = u + MOD;
  const lo = _bigintToUint32Number(u % 4294967296n);
  const hi = _bigintToUint32Number(u / 4294967296n);
  return { hi: hi, lo: lo };
}

function _getBigUint64(ptr, base, littleEndian) {
  // Read 8 raw bytes; do not reuse LE-only _getU32 for BE word halves.
  // Avoid BigInt bitwise ops (engine rejects them); use * / + only.
  const b0 = buf.getByte(ptr, base) & 0xFF;
  const b1 = buf.getByte(ptr, base + 1) & 0xFF;
  const b2 = buf.getByte(ptr, base + 2) & 0xFF;
  const b3 = buf.getByte(ptr, base + 3) & 0xFF;
  const b4 = buf.getByte(ptr, base + 4) & 0xFF;
  const b5 = buf.getByte(ptr, base + 5) & 0xFF;
  const b6 = buf.getByte(ptr, base + 6) & 0xFF;
  const b7 = buf.getByte(ptr, base + 7) & 0xFF;
  let lo;
  let hi;
  if (littleEndian) {
    lo = (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) >>> 0;
    hi = (b4 | (b5 << 8) | (b6 << 16) | (b7 << 24)) >>> 0;
  } else {
    hi = ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) >>> 0;
    lo = ((b4 << 24) | (b5 << 16) | (b6 << 8) | b7) >>> 0;
  }
  return _uint32PairToBigInt(hi, lo);
}

function _getBigInt64(ptr, base, littleEndian) {
  return _unsigned64ToSignedBigInt(_getBigUint64(ptr, base, littleEndian));
}

function _setBigUint64(ptr, base, value, littleEndian) {
  const parts = _bigIntToHiLo(value);
  if (littleEndian) {
    buf.setByte(ptr, base, parts.lo & 0xFF);
    buf.setByte(ptr, base + 1, (parts.lo >>> 8) & 0xFF);
    buf.setByte(ptr, base + 2, (parts.lo >>> 16) & 0xFF);
    buf.setByte(ptr, base + 3, (parts.lo >>> 24) & 0xFF);
    buf.setByte(ptr, base + 4, parts.hi & 0xFF);
    buf.setByte(ptr, base + 5, (parts.hi >>> 8) & 0xFF);
    buf.setByte(ptr, base + 6, (parts.hi >>> 16) & 0xFF);
    buf.setByte(ptr, base + 7, (parts.hi >>> 24) & 0xFF);
  } else {
    buf.setByte(ptr, base, (parts.hi >>> 24) & 0xFF);
    buf.setByte(ptr, base + 1, (parts.hi >>> 16) & 0xFF);
    buf.setByte(ptr, base + 2, (parts.hi >>> 8) & 0xFF);
    buf.setByte(ptr, base + 3, parts.hi & 0xFF);
    buf.setByte(ptr, base + 4, (parts.lo >>> 24) & 0xFF);
    buf.setByte(ptr, base + 5, (parts.lo >>> 16) & 0xFF);
    buf.setByte(ptr, base + 6, (parts.lo >>> 8) & 0xFF);
    buf.setByte(ptr, base + 7, parts.lo & 0xFF);
  }
}

function _setBigInt64(ptr, base, value, littleEndian) {
  _setBigUint64(ptr, base, _toBigInt(value), littleEndian);
}

function _getBigInt64TA(ptr, off) { return _getBigInt64(ptr, off, true); }
function _getBigUint64TA(ptr, off) { return _getBigUint64(ptr, off, true); }
function _setBigInt64TA(ptr, off, v) {
  if (typeof v === 'number') throw new TypeError('Cannot convert number to BigInt');
  if (typeof v !== 'bigint') v = _toBigInt(v);
  _setBigInt64(ptr, off, v, true);
}
function _setBigUint64TA(ptr, off, v) {
  if (typeof v === 'number') throw new TypeError('Cannot convert number to BigInt');
  if (typeof v !== 'bigint') v = _toBigInt(v);
  _setBigUint64(ptr, off, v, true);
}

// ─── TypedArray constructor factory ─────────────────────────────────────────

function TypedArray() {
  throw new TypeError('Abstract class TypedArray not directly callable');
}
TypedArray.prototype = Object.create(Object.prototype);
_taInstallPrototypeMethods(TypedArray.prototype);
Object.defineProperty(TypedArray.prototype, 'constructor', {
  value: TypedArray, writable: true, enumerable: false, configurable: true
});
Object.defineProperty(TypedArray, 'name', {
  value: 'TypedArray', writable: false, enumerable: false, configurable: true
});
Object.defineProperty(TypedArray, 'length', {
  value: 0, writable: false, enumerable: false, configurable: true
});
Object.defineProperty(TypedArray, 'prototype', {
  value: TypedArray.prototype, writable: false, enumerable: false, configurable: false
});
_installTypedArraySpecies(TypedArray);

function _typedArrayCreate(C, length) {
  const result = new C(length);
  if (typeof buf.binaryKind !== 'function' || buf.binaryKind(result) !== 2) {
    throw new TypeError('TypedArrayCreate did not produce a TypedArray');
  }
  if (_taLength(result) < length) {
    throw new TypeError('TypedArrayCreate produced a TypedArray with insufficient length');
  }
  return result;
}

TypedArray.from = function(source, mapfn, thisArg) {
  const C = this;
  if (!_isConstructor(C)) {
    throw new TypeError('%TypedArray%.from called on non-constructor');
  }
  let mapping = false;
  if (mapfn !== undefined) {
    if (typeof mapfn !== 'function') {
      throw new TypeError('%TypedArray%.from mapfn is not callable');
    }
    mapping = true;
  }

  let items;
  const fromIter = source != null ? _iterableToList(source) : null;
  if (fromIter !== null) {
    items = fromIter;
  } else {
    if (source == null) {
      throw new TypeError('%TypedArray%.from requires an array-like or iterable');
    }
    // LengthOfArrayLike — observable ToNumber on length (not >>> 0).
    const len = _lengthOfArrayLike(source);
    _checkAllocLimit(len);
    items = [];
    var i = 0;
    for (; i < len; i++) items.push(source[i]);
  }

  _checkAllocLimit(items.length);
  const result = _typedArrayCreate(C, items.length);
  // Unmapped int32 items into an integer-kind view: one native copy.
  if (!mapping && typeof buf.taSet === 'function' && buf.taSet(result, items, 0) === true) {
    return result;
  }
  var k = 0;
  for (; k < items.length; k++) {
    const mapped = mapping ? mapfn.call(thisArg, items[k], k) : items[k];
    // Prefer IntegerIndexedElementSet via exotic Set / _writeAt.
    if (typeof result._writeAt === 'function') {
      result._writeAt(k, mapped);
    } else {
      result[k] = mapped;
    }
  }
  return result;
};

TypedArray.of = function() {
  const C = this;
  if (!_isConstructor(C)) {
    throw new TypeError('%TypedArray%.of called on non-constructor');
  }
  const arr = _typedArrayCreate(C, arguments.length);
  var idx = 0;
  for (; idx < arguments.length; idx++) {
    if (typeof arr._writeAt === 'function') {
      arr._writeAt(idx, arguments[idx]);
    } else {
      arr[idx] = arguments[idx];
    }
  }
  return arr;
};

_rejectConstruct(TypedArray.from);
_rejectConstruct(TypedArray.of);
_installMeta(TypedArray.from, 'from', 1);
_installMeta(TypedArray.of, 'of', 0);
Object.defineProperty(TypedArray, 'from', {
  value: TypedArray.from, writable: true, enumerable: false, configurable: true
});
Object.defineProperty(TypedArray, 'of', {
  value: TypedArray.of, writable: true, enumerable: false, configurable: true
});

const TypedArrayPrototype = TypedArray.prototype;

function _finalizeTypedArrayCtor(Ctor, name, bytesPerElement) {
  const proto = Ctor.prototype;
  Object.setPrototypeOf(proto, TypedArrayPrototype);
  Object.defineProperty(proto, 'constructor', {
    value: Ctor, writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(proto, 'BYTES_PER_ELEMENT', {
    value: bytesPerElement, writable: false, enumerable: false, configurable: false
  });
  Object.setPrototypeOf(Ctor, TypedArray);
  // Concrete ctors must inherit from/of from %TypedArray% only (no own props).
  Object.defineProperty(Ctor, 'name', {
    value: name, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(Ctor, 'length', {
    value: 3, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(Ctor, 'BYTES_PER_ELEMENT', {
    value: bytesPerElement, writable: false, enumerable: false, configurable: false
  });
  Object.defineProperty(Ctor, 'prototype', {
    value: proto, writable: false, enumerable: false, configurable: false
  });
  // Concrete @@toStringTag data property so Object.prototype.toString works even
  // when the inherited %TypedArray% accessor cannot be invoked from native paths.
  if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
    Object.defineProperty(proto, Symbol.toStringTag, {
      value: name, writable: false, enumerable: false, configurable: true
    });
  }
  _installTypedArraySpecies(Ctor);
}

function _createTypedArrayClass(name, bytesPerElement, getter, setter) {
  const elemKind = _typedArrayElementKind(name);
  // Named via finalize; never use arguments.callee (forbidden in strict mode /
  // test262 modules and breaks _ctor / species / Reflect.construct).
  function TypedArrayCtor(arg0, byteOffset, length) {
    if (typeof new.target === 'undefined' || new.target === undefined) {
      throw new TypeError('TypedArray constructor requires new');
    }
    var _nt = new.target;
    // Fast paths for the two common argument shapes — `new TA(n)` with a
    // non-negative integer n, and `new TA(arrayBuffer, off, len)` with integer
    // off/len. buf_init_typed_array (buffer_native.jac) validates alignment,
    // detachment and range natively and returns undefined when anything is
    // off, in which case the full path below produces the spec error.
    if (_initTypedArrayNative !== null) {
      var _fastShape = 0;
      if (typeof arg0 === 'number') {
        if (arg0 >= 0 && (arg0 | 0) === arg0 && arg0 * bytesPerElement <= _AB_ALLOC_LIMIT) _fastShape = 1;
      } else if (arg0 !== null && typeof arg0 === 'object' && typeof byteOffset === 'number'
                 && typeof length === 'number' && (byteOffset | 0) === byteOffset
                 && (length | 0) === length && byteOffset >= 0 && length >= 0) {
        _fastShape = 2;
      }
      if (_fastShape !== 0) {
        var _fastOk = true;
        if (_nt !== TypedArrayCtor) {
          _installInstancePrototype(this, _nt, TypedArrayCtor.prototype);
          _fastOk = typeof this._readAt === 'function';
        }
        if (_fastOk) {
          var _fastRes = _fastShape === 1
            ? _initTypedArrayNative(this, new ArrayBuffer(arg0 * bytesPerElement), 0, arg0, true,
                                    bytesPerElement, elemKind, name, getter, setter, TypedArrayCtor)
            : _initTypedArrayNative(this, arg0, byteOffset, length, true,
                                    bytesPerElement, elemKind, name, getter, setter, TypedArrayCtor);
          if (_fastRes === true) return;
        }
      }
    }
    // Validate/coerce args BEFORE OrdinaryCreateFromConstructor side effects
    // (prototype getters) where ToIndex / alignment / detach can throw.
    var _buf = null;
    var _off = 0;
    var _len = 0;
    var _fixed = true;
    var _fromObject = false;
    if (arg0 && typeof arg0 === 'object' && (
        arg0 instanceof ArrayBuffer ||
        (typeof SharedArrayBuffer !== 'undefined' && arg0 instanceof SharedArrayBuffer) ||
        arg0._isSharedArrayBuffer === true ||
        (typeof arg0._ptr === 'number' && arg0._byteLength !== undefined))) {
      _off = byteOffset === undefined ? 0 : _toIndex(byteOffset);
      if (arg0._detached) {
        throw new TypeError('Cannot construct TypedArray from detached ArrayBuffer');
      }
      if (_off % bytesPerElement !== 0) {
        throw new RangeError('byteOffset must be aligned');
      }
      if (_off > arg0._byteLength) {
        throw new RangeError('byteOffset out of range');
      }
      _fixed = length !== undefined;
      if (_fixed) {
        _len = _toIndex(length);
        if (arg0._detached) {
          throw new TypeError('Cannot construct TypedArray from detached ArrayBuffer');
        }
        if (_off + _len * bytesPerElement > arg0._byteLength) {
          throw new RangeError('Invalid typed array length');
        }
      } else {
        // Spec: if length undefined, (bufferByteLength - offset) % elementSize ≠ 0 → RangeError.
        var remBytes = arg0._byteLength - _off;
        if (remBytes % bytesPerElement !== 0) {
          throw new RangeError('byte length of ArrayBuffer is not a multiple of element size');
        }
        if (arg0._detached) {
          throw new TypeError('Cannot construct TypedArray from detached ArrayBuffer');
        }
        _len = remBytes / bytesPerElement;
      }
      _buf = arg0;
    } else if (typeof arg0 === 'number') {
      _len = _toIndex(arg0);
      _fixed = true;
      _off = 0;
    } else if (arg0 === undefined || arg0 === null) {
      _len = 0;
      _fixed = true;
      _off = 0;
    } else if (typeof arg0 === 'object') {
      _fromObject = true;
    } else {
      throw new TypeError('Invalid typed array length');
    }

    _installInstancePrototype(this, _nt, TypedArrayCtor.prototype);
    // Native field init for the validated (buffer, byteOffset, length) and
    // (length) forms: one call sets every instance field and registers the
    // view (88µs → a few µs). Object / iterable sources keep the JS path.
    if (!_fromObject && _initTypedArrayNative !== null && typeof this._readAt === 'function') {
      var _fastBuf = _buf ? _buf : new ArrayBuffer(_len * bytesPerElement);
      if (_initTypedArrayNative(this, _fastBuf, _off, _len, _fixed, bytesPerElement, elemKind,
                                name, getter, setter, TypedArrayCtor) === true) {
        return;
      }
    }
    Object.defineProperty(this, '_isTypedArrayInstance', {
      value: true, writable: false, enumerable: false, configurable: false
    });
    this._typedArrayName = name;
    this.BYTES_PER_ELEMENT = bytesPerElement;
    this._getter = getter;
    this._setter = setter;
    this._ctor = TypedArrayCtor;
    if (typeof this._readAt !== 'function') {
      this._readAt = TypedArrayPrototype._readAt;
    }
    if (typeof this._writeAt !== 'function') {
      this._writeAt = TypedArrayPrototype._writeAt;
    }
    if (_fromObject) {
      _taInitFromObjectArg(this, arg0, bytesPerElement, setter);
    } else if (_buf) {
      this._buffer = _buf;
      this._byteOffset = _off;
      this._fixedLength = _fixed;
      this._length = _len;
    } else {
      this._length = _len;
      this._fixedLength = _fixed;
      this._buffer = new ArrayBuffer(_len * bytesPerElement);
      this._byteOffset = 0;
    }
    if (typeof buf.binaryKind !== 'function' || buf.binaryKind(this) !== 2) {
      _registerNativeTypedArray(this, name);
    }
  }

  const proto = Object.create(TypedArrayPrototype);
  Object.defineProperty(proto, 'BYTES_PER_ELEMENT', {
    value: bytesPerElement, writable: false, enumerable: false, configurable: false
  });
  TypedArrayCtor.prototype = proto;

  _finalizeTypedArrayCtor(TypedArrayCtor, name, bytesPerElement);
  return TypedArrayCtor;
}

// ─── Concrete TypedArray types ──────────────────────────────────────────────

const Uint8Array    = _createTypedArrayClass('Uint8Array',    1, _getU8,  _setU8);
const Int8Array     = _createTypedArrayClass('Int8Array',     1, _getI8,  _setI8);
const Uint16Array   = _createTypedArrayClass('Uint16Array',   2, _getU16, _setU16);
const Int16Array    = _createTypedArrayClass('Int16Array',    2, _getI16, _setI16);
const Uint32Array   = _createTypedArrayClass('Uint32Array',   4, _getU32, _setU32);
const Int32Array    = _createTypedArrayClass('Int32Array',    4, _getI32, _setI32);
const Float32Array  = _createTypedArrayClass('Float32Array',  4, _getF32, _setF32);
const Float64Array  = _createTypedArrayClass('Float64Array',  8, _getF64, _setF64);
const Uint8ClampedArray = _createTypedArrayClass('Uint8ClampedArray', 1, _getU8, _setU8Clamped);

const BigInt64Array  = _createTypedArrayClass('BigInt64Array',  8, _getBigInt64TA, _setBigInt64TA);
const BigUint64Array = _createTypedArrayClass('BigUint64Array', 8, _getBigUint64TA, _setBigUint64TA);
const Float16Array   = _createTypedArrayClass('Float16Array',   2, _getF16, _setF16);

// ─── Uint8Array base64 / hex (Uint8Array base64 proposal) ───────────────────

// Build alphabets in short chunks — a single 64-char literal + === compare
// corrupts locals in this engine's bytecode (see Group B base64 residuals).
function _b64Alphabet(kind) {
  const a = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const b = 'abcdefghijklmnopqrstuvwxyz';
  const c = '0123456789';
  return kind === 1 ? (a + b + c + '-_') : (a + b + c + '+/');
}

function _b64Lookup(kind) {
  const alphabet = _b64Alphabet(kind);
  const lookup = Object.create(null);
  var ai = 0;
  while (ai < 64) {
    lookup[alphabet.charAt(ai)] = ai;
    ai = ai + 1;
  }
  return lookup;
}

function _b64Options(options) {
  // alphabetKind: 0 = base64, 1 = base64url
  let alphabetKind = 0;
  let lastChunkHandling = 'loose';
  let omitPadding = false;
  if (options !== undefined && options !== null) {
    if (typeof options !== 'object' && typeof options !== 'function') {
      throw new TypeError('Options must be an object');
    }
    // Get (not `in`) so inherited getters run; undefined / null fields are skipped.
    const a = options.alphabet;
    if (a !== undefined && a !== null) {
      const as = String(a);
      if (as === 'base64url') alphabetKind = 1;
      else if (as === 'base64') alphabetKind = 0;
      else throw new TypeError('Invalid base64 alphabet');
    }
    const h = options.lastChunkHandling;
    if (h !== undefined && h !== null) {
      const hs = String(h);
      if (hs !== 'loose' && hs !== 'strict' && hs !== 'stop-before-partial') {
        throw new TypeError('Invalid lastChunkHandling');
      }
      lastChunkHandling = hs;
    }
    if (options.omitPadding !== undefined && options.omitPadding !== null) {
      omitPadding = !!options.omitPadding;
    }
  }
  return {
    alphabetKind: alphabetKind,
    lastChunkHandling: lastChunkHandling,
    omitPadding: omitPadding
  };
}

function _isAsciiWsCode(code) {
  return code === 0x20 || code === 0x09 || code === 0x0A || code === 0x0D || code === 0x0C;
}

function _b64StripWs(string) {
  // Returns { s, indexMap } where indexMap[cleanedIdx] = originalIdx.
  // Isolated helper — keeps decode locals away from strip loop pressure.
  const indexMap = [];
  let cleaned = '';
  const rawLen = string.length;
  var idx = 0;
  while (idx < rawLen) {
    const code = string.charCodeAt(idx);
    if (code !== 0x20 && code !== 0x09 && code !== 0x0A && code !== 0x0D && code !== 0x0C) {
      indexMap.push(idx);
      cleaned += string.charAt(idx);
    }
    idx = idx + 1;
  }
  return { s: cleaned, indexMap: indexMap };
}

function _decodeBase64(string, alphabetKind, lastChunkHandling) {
  if (typeof string !== 'string') string = String(string);
  const handling = lastChunkHandling === undefined ? 'loose' : String(lastChunkHandling);
  let s = string;
  let indexMap = null;
  if (handling !== 'strict') {
    const stripped = _b64StripWs(string);
    s = stripped.s;
    indexMap = stripped.indexMap;
  }
  const lookup = _b64Lookup(alphabetKind === 1 ? 1 : 0);

  const len = s.length;
  // Fail-fast: decoded size ≤ 3/4 of cleaned length.
  _checkAllocLimit(Math.floor(len * 3 / 4) + 3);
  const bytes = [];
  let i = 0;
  let stoppedEarly = false;
  while (i < len) {
    if ((bytes.length & 0xffff) === 0 && bytes.length > 0) {
      _checkAllocLimit(bytes.length + 4);
    }
    if (s.charAt(i) === '=') break;
    const c0 = s.charAt(i);
    const c1 = i + 1 < len ? s.charAt(i + 1) : '';
    const c2 = i + 2 < len ? s.charAt(i + 2) : '';
    const c3 = i + 3 < len ? s.charAt(i + 3) : '';
    const remaining = len - i;

    if (remaining === 1) {
      if (handling === 'stop-before-partial') { stoppedEarly = true; break; }
      // Loose/strict: a single leftover alphabet char is invalid.
      throw new SyntaxError('Invalid base64 string');
    }
    const v0 = lookup[c0];
    const v1 = lookup[c1];
    if (v0 === undefined || v1 === undefined) {
      throw new SyntaxError('Invalid base64 character');
    }
    if (remaining === 2 || (remaining >= 3 && c2 === '=')) {
      if (handling === 'stop-before-partial' && remaining === 2 && c2 !== '=') {
        stoppedEarly = true;
        break;
      }
      // Strict requires padding for a final 2-char chunk (even with zero leftover bits).
      if (handling === 'strict' && remaining === 2 && c2 !== '=') {
        throw new SyntaxError('Invalid base64 string');
      }
      // Partial padding "xx=" (only one '=') is invalid except stop-before-partial.
      if (c2 === '=' && c3 !== '=') {
        if (handling === 'stop-before-partial') { stoppedEarly = true; break; }
        throw new SyntaxError('Invalid base64 padding');
      }
      // Strict leftover-bits: low 4 bits of second sextet must be zero.
      if (handling === 'strict' && (v1 & 0x0F) !== 0) {
        throw new SyntaxError('Invalid base64 leftover bits');
      }
      bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF);
      if (c2 === '=') {
        i += (c3 === '=' ? 4 : 3);
      } else {
        i += 2;
      }
      break;
    }
    if (remaining === 3 || (remaining >= 4 && c3 === '=')) {
      // Partial padding window "xx=" (only one '='): stop-before-partial stops; else SyntaxError.
      if (c2 === '=') {
        if (handling === 'stop-before-partial') { stoppedEarly = true; break; }
        throw new SyntaxError('Invalid base64 padding');
      }
      if (remaining === 3) {
        // Exactly 3 alphabet chars, no pad: stop-before-partial stops; loose decodes 2 bytes; strict throws.
        const v2partial = lookup[c2];
        if (v2partial === undefined) throw new SyntaxError('Invalid base64 character');
        if (handling === 'stop-before-partial') { stoppedEarly = true; break; }
        if (handling === 'strict') throw new SyntaxError('Invalid base64 string');
        if ((v2partial & 0x03) !== 0) {
          // loose ignores leftover bits
        }
        bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF);
        bytes.push((((v1 & 15) << 4) | (v2partial >> 2)) & 0xFF);
        i += 3;
        break;
      }
      const v2 = lookup[c2];
      if (v2 === undefined) throw new SyntaxError('Invalid base64 character');
      // Strict leftover-bits: low 2 bits of third sextet must be zero.
      if (handling === 'strict' && (v2 & 0x03) !== 0) {
        throw new SyntaxError('Invalid base64 leftover bits');
      }
      bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF);
      bytes.push((((v1 & 15) << 4) | (v2 >> 2)) & 0xFF);
      i += (c3 === '=' ? 4 : 3);
      break;
    }
    const v2 = lookup[c2];
    const v3 = lookup[c3];
    if (v2 === undefined || v3 === undefined) {
      throw new SyntaxError('Invalid base64 character');
    }
    bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF);
    bytes.push((((v1 & 15) << 4) | (v2 >> 2)) & 0xFF);
    bytes.push((((v2 & 3) << 6) | v3) & 0xFF);
    i += 4;
  }
  // Trailing garbage / excess padding after a finished chunk must SyntaxError
  // (unless stop-before-partial stopped early before consuming them).
  if (!stoppedEarly && i < len) {
    // Only ASCII whitespace is ignorable; it was already stripped for non-strict.
    // Any remaining character (including extra '=') is illegal.
    throw new SyntaxError('Invalid base64 trailing garbage');
  }
  let read = string.length;
  if (stoppedEarly) {
    if (indexMap && i < indexMap.length) read = indexMap[i];
    else read = i;
  } else if (indexMap && i > 0) {
    const last = i - 1;
    if (last < indexMap.length) {
      read = indexMap[last] + 1;
      while (read < string.length) {
        if (!_isAsciiWsCode(string.charCodeAt(read))) break;
        read = read + 1;
      }
    }
  } else if (!indexMap) {
    read = i < len ? i : string.length;
  }
  return { bytes: bytes, read: read };
}

function _encodeBase64(u8, alphabetKind, omitPadding) {
  const alphabet = _b64Alphabet(alphabetKind === 1 ? 1 : 0);
  const len = (typeof buf.binaryKind === 'function' && buf.binaryKind(u8) === 2)
    ? _taLength(u8)
    : (u8.length >>> 0);
  let out = '';
  var i = 0;
  function byteAt(pos) {
    return (u8._readAt ? u8._readAt(pos) : u8[pos]) & 0xFF;
  }
  while (i + 2 < len) {
    const n = (byteAt(i) << 16) | (byteAt(i + 1) << 8) | byteAt(i + 2);
    out += alphabet.charAt((n >> 18) & 63);
    out += alphabet.charAt((n >> 12) & 63);
    out += alphabet.charAt((n >> 6) & 63);
    out += alphabet.charAt(n & 63);
    i = i + 3;
  }
  const rem = len - i;
  if (rem === 1) {
    const n = byteAt(i) << 16;
    out += alphabet.charAt((n >> 18) & 63);
    out += alphabet.charAt((n >> 12) & 63);
    if (!omitPadding) out += '==';
  } else if (rem === 2) {
    const n = (byteAt(i) << 16) | (byteAt(i + 1) << 8);
    out += alphabet.charAt((n >> 18) & 63);
    out += alphabet.charAt((n >> 12) & 63);
    out += alphabet.charAt((n >> 6) & 63);
    if (!omitPadding) out += '=';
  }
  return out;
}

function _decodeHex(string) {
  if (typeof string !== 'string') string = String(string);
  if (string.length % 2 !== 0) {
    throw new SyntaxError('Hex string must have even length');
  }
  _checkAllocLimit(string.length / 2);
  const bytes = [];
  var i = 0;
  for (; i < string.length; i += 2) {
    const hex = string.substring(i, i + 2);
    if (!/^[0-9a-fA-F]{2}$/.test(hex)) {
      throw new SyntaxError('Invalid hex character');
    }
    bytes.push(parseInt(hex, 16));
  }
  return bytes;
}

function _encodeHex(u8) {
  const hex = '0123456789abcdef';
  let out = '';
  const len = (typeof buf.binaryKind === 'function' && buf.binaryKind(u8) === 2)
    ? _taLength(u8)
    : (u8.length >>> 0);
  var i = 0;
  for (; i < len; i++) {
    const b = (u8._readAt ? u8._readAt(i) : u8[i]) & 0xFF;
    out += hex.charAt(b >> 4);
    out += hex.charAt(b & 15);
  }
  return out;
}

Uint8Array.fromBase64 = function(string, options) {
  // RequireString before GetOptions (string-coercion: no toString, no options getters).
  if (typeof string !== 'string') {
    throw new TypeError('Uint8Array.fromBase64 requires a string');
  }
  const opts = _b64Options(options);
  const decoded = _decodeBase64(string, opts.alphabetKind, opts.lastChunkHandling);
  return new Uint8Array(decoded.bytes);
};

Uint8Array.prototype.toBase64 = function(options) {
  // Brand before options getters (receiver-not-uint8array / makePassthrough).
  _requireUint8Array(this, 'toBase64');
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform toBase64 on a detached ArrayBuffer');
  }
  if (_taIsOutOfBounds(this)) {
    throw new TypeError('Cannot perform toBase64 on an out-of-bounds TypedArray');
  }
  const opts = _b64Options(options);
  return _encodeBase64(this, opts.alphabetKind, opts.omitPadding);
};

Uint8Array.prototype.setFromBase64 = function(string, options) {
  _requireUint8Array(this, 'setFromBase64');
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform setFromBase64 on a detached ArrayBuffer');
  }
  if (this._buffer && this._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  if (_taIsOutOfBounds(this)) {
    throw new TypeError('Cannot perform setFromBase64 on an out-of-bounds TypedArray');
  }
  // RequireString before options getters.
  if (typeof string !== 'string') {
    throw new TypeError('Uint8Array.prototype.setFromBase64 requires a string');
  }
  const opts = _b64Options(options);
  // Decode after options coercion; re-check detach (options getters may detach).
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform setFromBase64 on a detached ArrayBuffer');
  }
  if (this._buffer && this._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  const destLen = _taLength(this);
  const decoded = _decodeBase64(string, opts.alphabetKind, opts.lastChunkHandling);
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform setFromBase64 on a detached ArrayBuffer');
  }
  const bytes = decoded.bytes;
  const writeLen = Math.min(bytes.length, destLen);
  var i = 0;
  for (; i < writeLen; i++) this._writeAt(i, bytes[i]);
  var read = decoded.read;
  // Truncated write: report how many input code units produce `writeLen` bytes.
  if (writeLen < bytes.length && opts.lastChunkHandling === 'stop-before-partial') {
    const fullChunks = Math.floor(writeLen / 3);
    const rem = writeLen % 3;
    var need = fullChunks * 4;
    if (rem === 1) need = need + 2;
    else if (rem === 2) need = need + 3;
    if (need < read) read = need;
  }
  return { read: read, written: writeLen };
};

Uint8Array.fromHex = function(string) {
  if (typeof string !== 'string') {
    throw new TypeError('Uint8Array.fromHex requires a string');
  }
  const bytes = _decodeHex(string);
  return new Uint8Array(bytes);
};

Uint8Array.prototype.toHex = function() {
  _requireUint8Array(this, 'toHex');
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform toHex on a detached ArrayBuffer');
  }
  if (_taIsOutOfBounds(this)) {
    throw new TypeError('Cannot perform toHex on an out-of-bounds TypedArray');
  }
  return _encodeHex(this);
};

Uint8Array.prototype.setFromHex = function(string) {
  _requireUint8Array(this, 'setFromHex');
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform setFromHex on a detached ArrayBuffer');
  }
  if (this._buffer && this._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  if (_taIsOutOfBounds(this)) {
    throw new TypeError('Cannot perform setFromHex on an out-of-bounds TypedArray');
  }
  if (typeof string !== 'string') {
    throw new TypeError('Uint8Array.prototype.setFromHex requires a string');
  }
  const bytes = _decodeHex(string);
  if (this._buffer && this._buffer._detached) {
    throw new TypeError('Cannot perform setFromHex on a detached ArrayBuffer');
  }
  const writeLen = Math.min(bytes.length, _taLength(this));
  var i = 0;
  for (; i < writeLen; i++) this._writeAt(i, bytes[i]);
  return { read: typeof string === 'string' ? string.length : String(string).length, written: writeLen };
};

_rejectConstruct(Uint8Array.fromBase64);
_rejectConstruct(Uint8Array.prototype.toBase64);
_rejectConstruct(Uint8Array.prototype.setFromBase64);
_rejectConstruct(Uint8Array.fromHex);
_rejectConstruct(Uint8Array.prototype.toHex);
_rejectConstruct(Uint8Array.prototype.setFromHex);
_installMeta(Uint8Array.fromBase64, 'fromBase64', 1);
_installMeta(Uint8Array.prototype.toBase64, 'toBase64', 0);
_installMeta(Uint8Array.prototype.setFromBase64, 'setFromBase64', 1);
_installMeta(Uint8Array.fromHex, 'fromHex', 1);
_installMeta(Uint8Array.prototype.toHex, 'toHex', 0);
_installMeta(Uint8Array.prototype.setFromHex, 'setFromHex', 1);
[
  [Uint8Array, 'fromBase64'], [Uint8Array, 'fromHex'],
  [Uint8Array.prototype, 'toBase64'], [Uint8Array.prototype, 'setFromBase64'],
  [Uint8Array.prototype, 'toHex'], [Uint8Array.prototype, 'setFromHex']
].forEach(function(pair) {
  const obj = pair[0];
  const key = pair[1];
  Object.defineProperty(obj, key, {
    value: obj[key], writable: true, enumerable: false, configurable: true
  });
});

// ─── DataView ───────────────────────────────────────────────────────────────

class DataView {
  constructor(buffer, byteOffset, byteLength) {
    if (!_isArrayBufferLike(buffer)) {
      throw new TypeError('First argument to DataView constructor must be an ArrayBuffer or SharedArrayBuffer');
    }
    // Spec order: ToIndex(byteOffset) then validate against buffer length BEFORE
    // OrdinaryCreateFromConstructor (byteOffset-validated-against-initial-buffer-length.js).
    const offset = byteOffset === undefined ? 0 : _toIndex(byteOffset);
    if (buffer._detached) {
      throw new TypeError('Cannot construct DataView with a detached ArrayBuffer');
    }
    let bufLen = buffer._byteLength;
    if (offset > bufLen) {
      throw new RangeError('byteOffset out of range');
    }
    let viewLen;
    let fixedLength = byteLength !== undefined;
    if (byteLength === undefined) {
      viewLen = bufLen - offset;
    } else {
      viewLen = _toIndex(byteLength);
      if (buffer._detached) {
        throw new TypeError('Cannot construct DataView with a detached ArrayBuffer');
      }
      bufLen = buffer._byteLength;
      if (offset + viewLen > bufLen) {
        throw new RangeError('byteLength out of range');
      }
    }
    _installInstancePrototype(this, new.target, DataView.prototype);
    // Proto getter (OrdinaryCreateFromConstructor) may detach/resize — re-validate.
    if (buffer._detached) {
      throw new TypeError('Cannot construct DataView with a detached ArrayBuffer');
    }
    bufLen = buffer._byteLength;
    if (offset > bufLen) {
      throw new RangeError('byteOffset out of range');
    }
    if (fixedLength && offset + viewLen > bufLen) {
      throw new RangeError('byteLength out of range');
    }
    if (!fixedLength) {
      viewLen = bufLen - offset;
    }
    this._buffer = buffer;
    this._byteOffset = offset;
    this._fixedLength = fixedLength;
    this._byteLength = viewLen;
    Object.defineProperty(this, '_isDataViewInstance', {
      value: true, writable: false, enumerable: false, configurable: false
    });
    _registerNativeDataView(this);
  }

  get buffer()     { _dvRequireDataView(this); return this._buffer; }
  get byteOffset() {
    _dvRequireDataView(this);
    if (_dvIsOutOfBounds(this)) {
      throw new TypeError('DataView is out of bounds or has a detached ArrayBuffer');
    }
    return this._byteOffset;
  }
  get byteLength() {
    _dvRequireDataView(this);
    if (_dvIsOutOfBounds(this)) {
      throw new TypeError('DataView is out of bounds or has a detached ArrayBuffer');
    }
    return _dvLiveByteLength(this);
  }
  get _isDataView() { return true; }

  getUint8(offset) {
    const off = _dvValidate(this, offset, 1);
    return buf.getByte(this._buffer._ptr, this._byteOffset + off);
  }
  setUint8(offset, value) {
    const w = _dvWriteNumber(this, offset, 1, value);
    buf.setByte(this._buffer._ptr, this._byteOffset + w.byteOffset, w.value & 0xFF);
  }

  getInt8(offset) {
    const off = _dvValidate(this, offset, 1);
    const b = buf.getByte(this._buffer._ptr, this._byteOffset + off);
    return b > 127 ? b - 256 : b;
  }
  setInt8(offset, value) {
    const w = _dvWriteNumber(this, offset, 1, value);
    buf.setByte(this._buffer._ptr, this._byteOffset + w.byteOffset, w.value & 0xFF);
  }

  getUint16(offset, littleEndian) {
    const off = _dvValidate(this, offset, 2);
    const base = this._byteOffset + off;
    const ptr  = this._buffer._ptr;
    const b0 = buf.getByte(ptr, base);
    const b1 = buf.getByte(ptr, base + 1);
    return littleEndian ? (b0 | (b1 << 8)) : ((b0 << 8) | b1);
  }
  setUint16(offset, value, littleEndian) {
    const w = _dvWriteNumber(this, offset, 2, value);
    const base = this._byteOffset + w.byteOffset;
    const ptr  = this._buffer._ptr;
    const v = w.value;
    if (littleEndian) {
      buf.setByte(ptr, base,     v & 0xFF);
      buf.setByte(ptr, base + 1, (v >>> 8) & 0xFF);
    } else {
      buf.setByte(ptr, base,     (v >>> 8) & 0xFF);
      buf.setByte(ptr, base + 1, v & 0xFF);
    }
  }

  getInt16(offset, littleEndian) {
    const u = this.getUint16(offset, littleEndian);
    return u > 32767 ? u - 65536 : u;
  }
  setInt16(offset, value, littleEndian) { this.setUint16(offset, value, littleEndian); }

  getUint32(offset, littleEndian) {
    const off = _dvValidate(this, offset, 4);
    const base = this._byteOffset + off;
    const ptr  = this._buffer._ptr;
    const b0 = buf.getByte(ptr, base);
    const b1 = buf.getByte(ptr, base + 1);
    const b2 = buf.getByte(ptr, base + 2);
    const b3 = buf.getByte(ptr, base + 3);
    if (littleEndian) { return (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) >>> 0; }
    return ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) >>> 0;
  }
  setUint32(offset, value, littleEndian) {
    const w = _dvWriteNumber(this, offset, 4, value);
    const base = this._byteOffset + w.byteOffset;
    const ptr  = this._buffer._ptr;
    const v = w.value;
    if (littleEndian) {
      buf.setByte(ptr, base,     v & 0xFF);
      buf.setByte(ptr, base + 1, (v >>> 8)  & 0xFF);
      buf.setByte(ptr, base + 2, (v >>> 16) & 0xFF);
      buf.setByte(ptr, base + 3, (v >>> 24) & 0xFF);
    } else {
      buf.setByte(ptr, base,     (v >>> 24) & 0xFF);
      buf.setByte(ptr, base + 1, (v >>> 16) & 0xFF);
      buf.setByte(ptr, base + 2, (v >>> 8)  & 0xFF);
      buf.setByte(ptr, base + 3, v & 0xFF);
    }
  }

  getInt32(offset, littleEndian) {
    const off = _dvValidate(this, offset, 4);
    if (typeof buf.dvGetInt === 'function' && typeof buf.binaryKind === 'function' && buf.binaryKind(this) === 3) {
      const nv = buf.dvGetInt(this, off, 4, !!littleEndian, true);
      if (nv !== undefined) return nv | 0;
    }
    const base = this._byteOffset + off;
    const ptr  = this._buffer._ptr;
    const b0 = buf.getByte(ptr, base);
    const b1 = buf.getByte(ptr, base + 1);
    const b2 = buf.getByte(ptr, base + 2);
    const b3 = buf.getByte(ptr, base + 3);
    return littleEndian ? (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) : ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3);
  }
  setInt32(offset, value, littleEndian) { this.setUint32(offset, value, littleEndian); }

  getFloat32(offset, littleEndian) {
    const off = _dvValidate(this, offset, 4);
    const base = this._byteOffset + off;
    const ptr  = this._buffer._ptr;
    let b0, b1, b2, b3;
    if (littleEndian) {
      b0 = buf.getByte(ptr, base); b1 = buf.getByte(ptr, base+1);
      b2 = buf.getByte(ptr, base+2); b3 = buf.getByte(ptr, base+3);
    } else {
      b3 = buf.getByte(ptr, base); b2 = buf.getByte(ptr, base+1);
      b1 = buf.getByte(ptr, base+2); b0 = buf.getByte(ptr, base+3);
    }
    return _f32BitsToNumber((b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) >>> 0);
  }
  setFloat32(offset, value, littleEndian) {
    const w = _dvWriteNumber(this, offset, 4, value);
    const bits = _numberToF32Bits(w.value);
    const base = this._byteOffset + w.byteOffset;
    const ptr  = this._buffer._ptr;
    if (littleEndian) {
      buf.setByte(ptr, base,     bits & 0xFF);
      buf.setByte(ptr, base + 1, (bits >>> 8)  & 0xFF);
      buf.setByte(ptr, base + 2, (bits >>> 16) & 0xFF);
      buf.setByte(ptr, base + 3, (bits >>> 24) & 0xFF);
    } else {
      buf.setByte(ptr, base,     (bits >>> 24) & 0xFF);
      buf.setByte(ptr, base + 1, (bits >>> 16) & 0xFF);
      buf.setByte(ptr, base + 2, (bits >>> 8)  & 0xFF);
      buf.setByte(ptr, base + 3, bits & 0xFF);
    }
  }

  getFloat16(offset, littleEndian) {
    const off = _dvValidate(this, offset, 2);
    const base = this._byteOffset + off;
    const ptr = this._buffer._ptr;
    const first = buf.getByte(ptr, base);
    const second = buf.getByte(ptr, base + 1);
    const bits = littleEndian ? (first | (second << 8)) : ((first << 8) | second);
    return _f16BitsToF64(bits);
  }
  setFloat16(offset, value, littleEndian) {
    const w = _dvWriteNumber(this, offset, 2, value);
    const bits = _f64ToF16Bits(w.value);
    const base = this._byteOffset + w.byteOffset;
    const ptr = this._buffer._ptr;
    if (littleEndian) {
      buf.setByte(ptr, base, bits & 0xFF);
      buf.setByte(ptr, base + 1, (bits >>> 8) & 0xFF);
    } else {
      buf.setByte(ptr, base, (bits >>> 8) & 0xFF);
      buf.setByte(ptr, base + 1, bits & 0xFF);
    }
  }

  getFloat64(offset, littleEndian) {
    const off = _dvValidate(this, offset, 8);
    var base = this._byteOffset + off;
    var ptr  = this._buffer._ptr;
    var bytes = [];
    var i = 0;
    for (; i < 8; i++) bytes.push(buf.getByte(ptr, base + i));
    if (!littleEndian) bytes.reverse();
    var lo = (bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)) >>> 0;
    var hi = (bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24)) >>> 0;
    return _f64BitsToNumber(hi, lo);
  }
  setFloat64(offset, value, littleEndian) {
    const w = _dvWriteNumber(this, offset, 8, value);
    var parts = _numberToF64Bits(w.value);
    var lo = parts[0];
    var hi = parts[1];
    var base = this._byteOffset + w.byteOffset;
    var ptr  = this._buffer._ptr;
    var bytes = [
      lo & 0xFF, (lo >>> 8) & 0xFF, (lo >>> 16) & 0xFF, (lo >>> 24) & 0xFF,
      hi & 0xFF, (hi >>> 8) & 0xFF, (hi >>> 16) & 0xFF, (hi >>> 24) & 0xFF
    ];
    if (!littleEndian) bytes.reverse();
    var wi = 0;
    for (; wi < 8; wi++) buf.setByte(ptr, base + wi, bytes[wi]);
  }

  getBigInt64(offset, littleEndian) {
    const off = _dvValidate(this, offset, 8);
    return _getBigInt64(this._buffer._ptr, this._byteOffset + off, !!littleEndian);
  }
  setBigInt64(offset, value, littleEndian) {
    const w = _dvWriteBigInt(this, offset, 8, value);
    _setBigInt64(this._buffer._ptr, this._byteOffset + w.byteOffset, w.value, !!littleEndian);
  }
  getBigUint64(offset, littleEndian) {
    const off = _dvValidate(this, offset, 8);
    return _getBigUint64(this._buffer._ptr, this._byteOffset + off, !!littleEndian);
  }
  setBigUint64(offset, value, littleEndian) {
    const w = _dvWriteBigInt(this, offset, 8, value);
    _setBigUint64(this._buffer._ptr, this._byteOffset + w.byteOffset, w.value, !!littleEndian);
  }
}

[
  ['getInt8', 1], ['getUint8', 1], ['getInt16', 1], ['getUint16', 1],
  ['getInt32', 1], ['getUint32', 1], ['getFloat16', 1], ['getFloat32', 1],
  ['getFloat64', 1], ['getBigInt64', 1], ['getBigUint64', 1],
  ['setInt8', 2], ['setUint8', 2], ['setInt16', 2], ['setUint16', 2],
  ['setInt32', 2], ['setUint32', 2], ['setFloat16', 2], ['setFloat32', 2],
  ['setFloat64', 2], ['setBigInt64', 2], ['setBigUint64', 2]
].forEach(function(pair) {
  const method = DataView.prototype[pair[0]];
  _rejectConstruct(method);
  _installMeta(method, pair[0], pair[1]);
});
_installMeta(DataView, 'DataView', 1);
if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
  // ES §25.3.5.4: data property "DataView".
  Object.defineProperty(DataView.prototype, Symbol.toStringTag, {
    value: 'DataView',
    writable: false,
    enumerable: false,
    configurable: true
  });
}

globalThis.__jacGetPrototypeFromConstructor = _getPrototypeFromConstructor;
globalThis.__jacInstallInstancePrototype = _installInstancePrototype;
globalThis.__jacOrdinaryCreateFromConstructor = _ordinaryCreateFromConstructor;
globalThis.__jacParseBufferCtorArgs = _parseBufferCtorArgs;
globalThis.__jacInstallBufferSpecies = _installBufferSpecies;

// ─── Register on globalThis ─────────────────────────────────────────────────

_installGlobal('ArrayBuffer', ArrayBuffer);
_installGlobal('TypedArray', TypedArray);
_installGlobal('Uint8Array', Uint8Array);
_installGlobal('Int8Array', Int8Array);
_installGlobal('Uint16Array', Uint16Array);
_installGlobal('Int16Array', Int16Array);
_installGlobal('Uint32Array', Uint32Array);
_installGlobal('Int32Array', Int32Array);
_installGlobal('Float32Array', Float32Array);
_installGlobal('Float64Array', Float64Array);
_installGlobal('Uint8ClampedArray', Uint8ClampedArray);
_installGlobal('BigInt64Array', BigInt64Array);
_installGlobal('BigUint64Array', BigUint64Array);
_installGlobal('Float16Array', Float16Array);
_installGlobal('DataView', DataView);

// test262 host hook — detach backing store (ArrayBuffer/DataView detach tests).
function _detachArrayBuffer(buffer) {
  if (!buffer || typeof buffer !== 'object' || buffer._byteLength === undefined) {
    throw new TypeError('detachArrayBuffer called with non-ArrayBuffer');
  }
  if (buffer._detached) return;
  if (buffer._ptr) {
    // Externally-owned backing stores (Wasmtime linear memory, napi external
    // buffers) must not be freed by the engine — only unbind the pointer.
    if (!buffer._external) {
      buf.free(buffer._ptr);
    }
    buffer._ptr = 0;
  }
  buffer._byteLength = 0;
  buffer._detached = true;
  buffer._detachGen = (buffer._detachGen || 0) + 1;
  _syncNativeBuffer(buffer, true);
}

if (globalThis.$262 && typeof globalThis.$262 === 'object') {
  globalThis.$262.detachArrayBuffer = _detachArrayBuffer;
}
globalThis.__detachArrayBuffer = _detachArrayBuffer;

// ── NAPI construction helpers (napi/src/napi_binary.na.jac) ─────────────────
// The NAPI binary ops (napi_create_arraybuffer/typedarray/buffer/...) build
// their objects HERE, through the real JS classes, because instances carry
// JS-side hidden state (_ptr/_byteLength/_buffer/...) that native code cannot
// replicate. Called from native via the shim VM-call bridge with plain
// number/object args. Contract: NEVER throw — return 0 on any failure; the
// native side maps a non-object result to napi_generic_failure.
const _NAPI_TA_CTORS = [
  Int8Array, Uint8Array, Uint8ClampedArray, Int16Array, Uint16Array,
  Int32Array, Uint32Array, Float32Array, Float64Array,
  BigInt64Array, BigUint64Array  // napi_typedarray_type 0..10
];

function _napiBufferCtor() {
  if (typeof globalThis.Buffer === 'function') return globalThis.Buffer;
  try { return require('buffer').Buffer; } catch (_) { return null; }
}

globalThis.__napiBinary = {
  createArrayBuffer: function (len) {
    try { return new ArrayBuffer(len); } catch (_) { return 0; }
  },
  // Zero-copy ArrayBuffer over externally-owned memory (napi external
  // buffers): allocate a zero-length buffer (no data block), then point it
  // at the external bytes and re-sync the native BackingStore mirror.
  wrapExternal: function (ptr, len) {
    try {
      const ab = new ArrayBuffer(0);
      ab._ptr = ptr;
      ab._byteLength = len;
      ab._maxByteLength = len;
      // External backing store is owned by the caller (napi addon / Wasmtime
      // linear memory) — the engine must NEVER buf.free() it. Marking it lets
      // _detachArrayBuffer skip the free (freeing a Wasmtime ptr corrupts the
      // heap / crashes; freeing a napi ptr double-frees addon memory).
      ab._external = true;
      _syncNativeBuffer(ab, false);
      return ab;
    } catch (_) { return 0; }
  },
  createTypedArray: function (kind, buffer, byteOffset, length) {
    try {
      const Ctor = _NAPI_TA_CTORS[kind];
      if (!Ctor) return 0;
      return new Ctor(buffer, byteOffset, length);
    } catch (_) { return 0; }
  },
  createDataView: function (buffer, byteOffset, byteLength) {
    try { return new DataView(buffer, byteOffset, byteLength); } catch (_) { return 0; }
  },
  detach: function (ab) {
    try { _detachArrayBuffer(ab); return 1; } catch (_) { return 0; }
  },
  viewBuffer: function (view) {
    try { return (view && view._buffer) || 0; } catch (_) { return 0; }
  },
  bufferAllocUnsafe: function (len) {
    try {
      const B = _napiBufferCtor();
      return B ? B.allocUnsafe(len) : 0;
    } catch (_) { return 0; }
  },
  bufferFromArrayBuffer: function (ab, byteOffset, length) {
    try {
      const B = _napiBufferCtor();
      return B ? B.from(ab, byteOffset, length) : 0;
    } catch (_) { return 0; }
  }
};
