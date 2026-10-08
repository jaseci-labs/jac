"""Native fast paths for the byte→string hot spots of Buffer and TextDecoder.

`Buffer.prototype.toString` and `TextDecoder.decode` are the hottest string
producers of a bundler (rollup's binary-AST `convertString` alone calls
toString per identifier). Their JS implementations cost ~32µs per call — one
exotic-object `.length` read (~10µs), a 5-deep JS call chain and a per-byte
decode loop — against ~1µs for the decode itself. Here the receiver's backing
store is read straight from the binary side-table (no property reads on the
exotic object), the encoding and range are validated once, and the bytes are
decoded natively into a refcounted JacStr.

Exposed via globalThis.__buf:
    __buf.toString(view, encoding, start, end) → string | undefined
    __buf.tdDecode(input, fatal)               → string | undefined
`undefined` means "not handled here" (non-utf8/latin1 encoding, DataView
input, non-binary receiver …) and the JS caller falls back to its own path,
so behaviour for the rare cases is unchanged.

Decode semantics mirror text_codec.js `_utf8DecodeBytes` (validated lead /
continuation bytes, U+FFFD per invalid lead byte, TypeError when `fatal`).
The engine stores JS strings as UTF-8 with two twists that the output honours:
code unit 0 is the 4-char sentinel `\\x00` (see jsstring.utf8_encode_scalar)
and astral characters are two 3-byte surrogate encodings (CESU-8), exactly
what the JS loop's `String.fromCharCode(hi) + String.fromCharCode(lo)` built.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_boolean,
    js_int,
    js_number,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_is_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE
}
import from engine.src.runtime.jsstring { str_heap, str_from_id, str_intern }
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_byte,
    read_u64,
    write_byte,
    str_from_raw
}
import from engine.src.runtime.binary_state {
    BinaryViewWitness,
    BackingStore,
    binary_view_witness,
    binary_typed_array_buffer,
    binary_backing_store,
    binary_is_array_buffer,
    binary_is_typed_array,
    binary_is_data_view,
    binary_data_view_buffer,
    binary_register_typed_array,
    binary_register_buffer,
    binary_typed_array_length,
    binary_typed_array_byte_offset,
    binary_typed_array_is_length_tracking,
    binary_typed_array_bytes_per_element,
    binary_typed_array_element_kind
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native
}
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.vm.vm_obs { js_call_observable, js_call_bridge_ready }
import from engine.src.runtime.jsobject {
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_set_flags,
    js_object_has_own,
    js_object_has_own_accessor,
    js_object_lookup_getter,
    js_object_get_own_accessor_getter,
    js_object_array_is_dataonly_fast
}
import from engine.src.runtime.jsobj_type { idx_protector_ok }
import from engine.src.builtins.array {
    js_is_array,
    js_array_get,
    _array_len_from_value
}
import from engine.src.runtime.wk_keys {
    WK_CONSTRUCTOR,
    WK_PROTOTYPE,
    WK_NOT_CTOR,
    WK_LENGTH
}
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { SYMBOL_SPECIES }
import from engine.src.runtime.realm { Realm }
import from engine.src.builtins.native_registry { is_native_val, get_native_kind }
import from engine.src.builtins.native_kinds { NATIVE_KIND_TA_SPECIES_GET }
import from engine.src.ffi.libc { memmove }


# Encoding selectors returned by _bn_encoding.
glob _ENC_UTF8: int = 1,
     _ENC_LATIN1: int = 2,
     _ENC_ASCII: int = 3,
     _ENC_OTHER: int = 0,
     _ENC_HEX: int = 4,
     _ENC_BASE64: int = 5,
     _ENC_BASE64URL: int = 6,
     _ENC_UTF16LE: int = 7;

"""Coerce a JSValue index argument: int32/float64 → int; undefined/null/other → dflt."""
def _bn_int_or(v: JSValue, dflt: int) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        f: float = jsv_to_double(v);
        if not (f == f) {
            return 0;
        }  # NaN → 0 (ToInteger)
        return int(f);
    }
    return dflt;
}

"""Case-insensitive equality of a Jac str against an ASCII lowercase literal."""
def _bn_eq_ci(s: str, lit: str) -> bool {
    n: int = len(s);
    if n != len(lit) {
        return False;
    }
    i: int = 0;
    while i < n {
        c: int = ord(s[i]);
        if c >= 65 and c <= 90 {
            c = c + 32;
        }
        if c != ord(lit[i]) {
            return False;
        }
        i += 1;
    }
    return True;
}

"""Map a Buffer encoding argument to a selector (mirrors buffer.js _normalizeEnc
for the encodings handled natively; everything else → _ENC_OTHER)."""
def _bn_encoding(v: JSValue) -> int {
    if jsv_is_undefined(v) or jsv_is_null(v) {
        return _ENC_UTF8;
    }
    if not jsv_is_string_cell(v) {
        return _ENC_OTHER;
    }
    e: str = str_from_id(jsv_to_table_id(v));
    if len(e) == 0 {
        return _ENC_UTF8;
    }
    if _bn_eq_ci(e, "utf8") or _bn_eq_ci(e, "utf-8") {
        return _ENC_UTF8;
    }
    if _bn_eq_ci(e, "latin1") or _bn_eq_ci(e, "binary") {
        return _ENC_LATIN1;
    }
    if _bn_eq_ci(e, "ascii") {
        return _ENC_ASCII;
    }
    if _bn_eq_ci(e, "hex") {
        return _ENC_HEX;
    }
    if _bn_eq_ci(e, "base64") {
        return _ENC_BASE64;
    }
    if _bn_eq_ci(e, "base64url") {
        return _ENC_BASE64URL;
    }
    if _bn_eq_ci(e, "utf16le")
        or _bn_eq_ci(e, "utf-16le")
        or _bn_eq_ci(e, "ucs2")
        or _bn_eq_ci(e, "ucs-2") {
        return _ENC_UTF16LE;
    }
    return _ENC_OTHER;
}

"""Emit `cp` (a UTF-16 code unit / BMP code point, or 0xFFFD) as the engine's
internal bytes at out[j]; returns the new j. cp == 0 → 4-char NUL sentinel."""
def _bn_put_unit(out: int, j: int, cp: int) -> int {
    if cp == 0 {
        write_byte(out, j, 92);
        write_byte(out, j + 1, 120);
        write_byte(out, j + 2, 48);
        write_byte(out, j + 3, 48);
        return j + 4;
    }
    if cp < 128 {
        write_byte(out, j, cp);
        return j + 1;
    }
    if cp < 2048 {
        write_byte(out, j, 192 + (cp >> 6));
        write_byte(out, j + 1, 128 + (cp & 63));
        return j + 2;
    }
    write_byte(out, j, 224 + (cp >> 12));
    write_byte(out, j + 1, 128 + ((cp >> 6) & 63));
    write_byte(out, j + 2, 128 + (cp & 63));
    return j + 3;
}

"""Decode UTF-8 bytes [s,e) at ptr into a refcounted JacStr. `fatal` → throw a
TypeError on the first malformed sequence (returns "" with the exception
pending). Output size ≤ 4 bytes per input byte (NUL sentinel / U+FFFD)."""
def _bn_decode_utf8(ptr: int, s: int, e: int, fatal: bool) -> str {
    n: int = e - s;
    if n <= 0 {
        return "";
    }
    out: int = io_alloc(n * 4 + 33);
    data: int = out + 32;
    j: int = 0;
    i: int = s;
    bad: bool = False;
    while i < e {
        b0: int = read_byte(ptr, i);
        if b0 < 128 {
            j = _bn_put_unit(data, j, b0);
            i += 1;
        } elif (b0 & 224) == 192 {
            if i + 1 >= e {
                bad = True;
                j = _bn_put_unit(data, j, 65533);
                i = e;
            } else {
                b1: int = read_byte(ptr, i + 1);
                if (b1 & 192) != 128 or (b0 & 254) == 192 {
                    bad = True;
                    j = _bn_put_unit(data, j, 65533);
                    i += 1;
                } else {
                    j = _bn_put_unit(data, j, ((b0 & 31) << 6) | (b1 & 63));
                    i += 2;
                }
            }
        } elif (b0 & 240) == 224 {
            if i + 2 >= e {
                bad = True;
                j = _bn_put_unit(data, j, 65533);
                i = e;
            } else {
                b1e: int = read_byte(ptr, i + 1);
                b2e: int = read_byte(ptr, i + 2);
                if (b1e & 192) != 128
                    or (b2e & 192) != 128
                    or (b0 == 224 and b1e < 160) {
                    bad = True;
                    j = _bn_put_unit(data, j, 65533);
                    i += 1;
                } else {
                    j = _bn_put_unit(
                        data, j, ((b0 & 15) << 12) | ((b1e & 63) << 6) | (b2e & 63)
                    );
                    i += 3;
                }
            }
        } elif (b0 & 248) == 240 {
            if i + 3 >= e {
                bad = True;
                j = _bn_put_unit(data, j, 65533);
                i = e;
            } else {
                b1f: int = read_byte(ptr, i + 1);
                b2f: int = read_byte(ptr, i + 2);
                b3f: int = read_byte(ptr, i + 3);
                if (b1f & 192) != 128
                    or (b2f & 192) != 128
                    or (b3f & 192) != 128
                    or b0 > 244
                    or (b0 == 240 and b1f < 144)
                    or (b0 == 244 and b1f > 143) {
                    bad = True;
                    j = _bn_put_unit(data, j, 65533);
                    i += 1;
                } else {
                    cp: int = ((b0 & 7) << 18)
                        | ((b1f & 63) << 12)
                        | ((b2f & 63) << 6)
                        | (b3f & 63);
                    cp = cp - 65536;
                    # Astral → surrogate pair, each half as a 3-byte sequence (CESU-8),
                    # matching String.fromCharCode(hi) + String.fromCharCode(lo).
                    j = _bn_put_unit(data, j, 55296 + (cp >> 10));
                    j = _bn_put_unit(data, j, 56320 + (cp & 1023));
                    i += 4;
                }
            }
        } else {
            bad = True;
            j = _bn_put_unit(data, j, 65533);
            i += 1;
        }
        if bad and fatal {
            io_free(out);
            vm_throw_native(make_type_error("Invalid UTF-8"));
            return "";
        }
    }
    write_byte(data, j, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

"""Decode Latin-1 bytes [s,e) at ptr: every byte is code unit U+0000..U+00FF.
`ascii7` masks each byte to 7 bits — node's 'ascii' decoding (0xE9 → 'i')."""
def _bn_decode_latin1(ptr: int, s: int, e: int, ascii7: bool) -> str {
    n: int = e - s;
    if n <= 0 {
        return "";
    }
    out: int = io_alloc(n * 4 + 33);
    data: int = out + 32;
    j: int = 0;
    i: int = s;
    while i < e {
        b: int = read_byte(ptr, i);
        if ascii7 {
            b = b & 127;
        }
        j = _bn_put_unit(data, j, b);
        i += 1;
    }
    write_byte(data, j, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

"""Data pointer (already offset) of a live in-bounds typed-array view, else 0."""
def _bn_view_ptr(view: JSValue) -> int {
    if not binary_is_typed_array(view) {
        return 0;
    }
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached or w.oob {
        return 0;
    }
    buffer: JSValue = binary_typed_array_buffer(view);
    if not binary_is_array_buffer(buffer) {
        return 0;
    }
    store: BackingStore = binary_backing_store(buffer);
    if store.ptr == 0 {
        return 0;
    }
    return store.ptr + w.byte_offset;
}

"""Byte length of a typed-array view (0 when invalid; pair with _bn_view_ptr)."""
def _bn_view_len(view: JSValue) -> int {
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached or w.oob {
        return 0;
    }
    return w.byte_length;
}

"""__buf.toString(view, encoding, start, end): Buffer.prototype.toString fast path.
Range semantics mirror buffer.js: defaults 0/len, negatives count from the end,
then clamp; empty range → "". Returns undefined for anything not handled here."""
def:pub buf_to_string(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    enc: int = _ENC_UTF8;
    if len(args) >= 2 {
        enc = _bn_encoding(args[1]);
    }
    if enc != _ENC_UTF8 and enc != _ENC_LATIN1 and enc != _ENC_ASCII {
        return js_undefined();
    }
    ptr: int = _bn_view_ptr(args[0]);
    if ptr == 0 {
        return js_undefined();
    }
    blen: int = _bn_view_len(args[0]);
    # Range semantics follow node's Buffer.prototype.toString: start <= 0 → 0,
    # start >= length → ""; end undefined or > length → length; a negative end is
    # kept as-is and yields "" via end <= start (node does NOT count from the end).
    s: int = 0;
    e: int = blen;
    if len(args) >= 3 {
        s = _bn_int_or(args[2], 0);
    }
    if len(args) >= 4 {
        e = _bn_int_or(args[3], blen);
    }
    if s < 0 {
        s = 0;
    }
    if e > blen {
        e = blen;
    }
    if e <= s or s >= blen {
        return jsv_from_string_id(str_heap(""));
    }
    if enc == _ENC_LATIN1 or enc == _ENC_ASCII {
        return jsv_from_string_id(
            str_heap(_bn_decode_latin1(ptr, s, e, enc == _ENC_ASCII))
        );
    }
    return jsv_from_string_id(str_heap(_bn_decode_utf8(ptr, s, e, False)));
}

"""__buf.tdDecode(input, fatal): TextDecoder.prototype.decode fast path (utf-8).
Accepts a typed array (any element type — decoded over its byte span) or an
ArrayBuffer; undefined for other inputs so the JS path keeps its TypeErrors."""
def:pub td_decode(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    input: JSValue = args[0];
    fatal: bool = False;
    if len(args) >= 2 and jsv_is_bool(args[1]) {
        fatal = jsv_to_bool(args[1]);
    }
    ptr: int = 0;
    blen: int = 0;
    if binary_is_typed_array(input) {
        ptr = _bn_view_ptr(input);
        if ptr == 0 {
            return js_undefined();
        }
        blen = _bn_view_len(input);
    } elif binary_is_array_buffer(input) {
        store: BackingStore = binary_backing_store(input);
        if store.detached {
            return js_undefined();
        }
        ptr = store.ptr;
        blen = store.byte_length;
        if blen == 0 {
            return jsv_from_string_id(str_heap(""));
        }
        if ptr == 0 {
            return js_undefined();
        }
    } else {
        return js_undefined();
    }
    if blen == 0 {
        return jsv_from_string_id(str_heap(""));
    }
    return jsv_from_string_id(str_heap(_bn_decode_utf8(ptr, 0, blen, fatal)));  # inline: named str locals leak
}


# ══════════════════════════════════════════════════════════════════════════════
# TypedArray exotic fast paths: the %TypedArray%.prototype getters, @@species,
# and native view construction for subarray.
#
# The JS getters cost ~12µs per `.length` read (a 5-deep JS call chain over
# ~15 property reads on the exotic object). They are natives here so that
# (a) invoking them is one native call and (b) the VM's GET_PROP can recognise
# the pristine getter by NATIVE_KIND on the prototype chain and answer from
# the binary side-table without any call at all (vm.jac _op_get_prop).
# `subarray` (~218µs: witness bookkeeping + a 55µs JS constructor) builds the
# result view natively when the species is the default.
# ══════════════════════════════════════════════════════════════════════════════

# Instance-property key ids of a typed-array view object (binary_types.js
# TypedArrayCtor). Interned once on first use.
glob _TAK_SEEDED: bool = False,
     _TAK_IS_INSTANCE: int = -1,
     _TAK_NAME: int = -1,
     _TAK_BPE: int = -1,
     _TAK_GETTER: int = -1,
     _TAK_SETTER: int = -1,
     _TAK_CTOR: int = -1,
     _TAK_READAT: int = -1,
     _TAK_WRITEAT: int = -1,
     _TAK_BUFFER: int = -1,
     _TAK_BYTEOFFSET: int = -1,
     _TAK_FIXEDLENGTH: int = -1,
     _TAK_LENGTH: int = -1,
     _TAK_ISBUF: int = -1;

# "_isTypedArrayInstance"
# "_typedArrayName"
# "BYTES_PER_ELEMENT"
# "_getter"
# "_setter"
# "_ctor"
# "_readAt"
# "_writeAt"
# "_buffer"
# "_byteOffset"
# "_fixedLength"
# "_length"
# "__isBuf" (buffer.js Buffer brand)
def _tak_seed -> None {
    if _TAK_SEEDED {
        return;
    }
    _TAK_IS_INSTANCE = str_intern("_isTypedArrayInstance");
    _TAK_NAME = str_intern("_typedArrayName");
    _TAK_BPE = str_intern("BYTES_PER_ELEMENT");
    _TAK_GETTER = str_intern("_getter");
    _TAK_SETTER = str_intern("_setter");
    _TAK_CTOR = str_intern("_ctor");
    _TAK_READAT = str_intern("_readAt");
    _TAK_WRITEAT = str_intern("_writeAt");
    _TAK_BUFFER = str_intern("_buffer");
    _TAK_BYTEOFFSET = str_intern("_byteOffset");
    _TAK_FIXEDLENGTH = str_intern("_fixedLength");
    _TAK_LENGTH = str_intern("_length");
    _TAK_ISBUF = str_intern("__isBuf");
    _TAK_SEEDED = True;
}

"""TypeError of a %TypedArray%.prototype getter invoked on a non-typed-array
(wording matches _taRequireInstance in binary_types.js / test262)."""
def _bn_getter_receiver_error(name: str) -> JSValue {
    vm_throw_native(
        make_type_error("Method get " + name + " called on incompatible receiver")
    );
    return js_undefined();
}

"""get %TypedArray%.prototype.length (ES §23.2.3.21): 0 when detached / OOB."""
def:pub ta_get_length(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if not binary_is_typed_array(this_val) {
        return _bn_getter_receiver_error("length");
    }
    return js_int(binary_typed_array_length(this_val));
}

"""get %TypedArray%.prototype.byteLength (ES §23.2.3.2)."""
def:pub ta_get_byte_length(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if not binary_is_typed_array(this_val) {
        return _bn_getter_receiver_error("byteLength");
    }
    return js_int(
        binary_typed_array_length(this_val)
            * binary_typed_array_bytes_per_element(this_val)
    );
}

"""get %TypedArray%.prototype.byteOffset (ES §23.2.3.3): 0 when detached / OOB."""
def:pub ta_get_byte_offset(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if not binary_is_typed_array(this_val) {
        return _bn_getter_receiver_error("byteOffset");
    }
    return js_int(binary_typed_array_byte_offset(this_val));
}

"""get %TypedArray%.prototype.buffer (ES §23.2.3.1)."""
def:pub ta_get_buffer(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if not binary_is_typed_array(this_val) {
        return _bn_getter_receiver_error("buffer");
    }
    return binary_typed_array_buffer(this_val);
}

"""get %TypedArray%[Symbol.species] (ES §23.2.2.4): returns `this`. A native so
the subarray fast path can recognise the pristine species getter by kind."""
def:pub ta_species_get(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    return this_val;
}

"""A closure (user/JS function) value: cell of kind NATIVE with table id below
the builtin base (mirrors vm.jac is_fn_val, which builtins cannot import)."""
def _bn_is_closure(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) < 1073741824;  # FN_BUILTIN_BASE (runtime/encoding.jac)
}

def _bn_copy_own(src: JSValue, dst: JSValue, key: int) {
    if js_object_has_own(src, key) {
        js_object_set(dst, key, js_object_get(src, key));
    }
}

"""Build a typed-array view object over `src`'s buffer natively — the fast
equivalent of `new C(buffer, byteOffset, length)` for the default species.
Mirrors the JS constructor's own-property order (shared shapes / ICs), the
frozen `_isTypedArrayInstance` brand, and registers the side-table record."""
def _bn_make_view(
    src: JSValue, proto: JSValue, byte_off: int, new_len: int, is_buf: bool
) -> JSValue {
    return _bn_make_view_on(
        src, binary_typed_array_buffer(src), proto, byte_off, new_len, is_buf
    );
}

"""As _bn_make_view, over an explicit `buffer` (slice: a fresh ArrayBuffer)."""
def _bn_make_view_on(
    src: JSValue,
    buffer: JSValue,
    proto: JSValue,
    byte_off: int,
    new_len: int,
    is_buf: bool
) -> JSValue {
    _tak_seed();
    if not binary_is_array_buffer(buffer) {
        return js_undefined();
    }
    bpe: int = binary_typed_array_bytes_per_element(src);
    ek: int = binary_typed_array_element_kind(src);
    view_obj: JSValue = js_object_create(proto);
    js_object_set_flags(view_obj, _TAK_IS_INSTANCE, js_true(), 0);
    _bn_copy_own(src, view_obj, _TAK_NAME);
    _bn_copy_own(src, view_obj, _TAK_BPE);
    _bn_copy_own(src, view_obj, _TAK_GETTER);
    _bn_copy_own(src, view_obj, _TAK_SETTER);
    _bn_copy_own(src, view_obj, _TAK_CTOR);
    _bn_copy_own(src, view_obj, _TAK_READAT);
    _bn_copy_own(src, view_obj, _TAK_WRITEAT);
    js_object_set(view_obj, _TAK_BUFFER, buffer);
    js_object_set(view_obj, _TAK_BYTEOFFSET, js_int(byte_off));
    js_object_set(view_obj, _TAK_FIXEDLENGTH, js_true());
    js_object_set(view_obj, _TAK_LENGTH, js_int(new_len));
    if is_buf {
        js_object_set(view_obj, _TAK_ISBUF, js_true());
    }
    reg_args: list[JSValue] = [
        view_obj,
        buffer,
        js_int(byte_off),
        js_int(new_len),
        js_int(bpe),
        js_int(ek),
        js_boolean(False)
    ];
    _ = binary_register_typed_array(reg_args);
    return view_obj;
}

"""A range argument node coerces with `|= 0`: undefined, a number, or a plain
decimal integer string (e.g. "12"); anything else goes to the JS path."""
def _bn_is_range_arg(v: JSValue) -> bool {
    if jsv_is_undefined(v) or jsv_is_int32(v) or jsv_is_double(v) {
        return True;
    }
    if not jsv_is_string_cell(v) {
        return False;
    }
    st: str = str_from_id(jsv_to_table_id(v));
    n: int = len(st);
    if n == 0 or n > 10 {
        return False;
    }
    i: int = 0;
    if ord(st[0]) == 45 {
        i = 1;
        if n == 1 {
            return False;
        }
    }
    while i < n {
        c: int = ord(st[i]);
        if c < 48 or c > 57 {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""Integer value of a range argument accepted by _bn_is_range_arg (undefined → dflt)."""
def _bn_range_int(v: JSValue, dflt: int) -> int {
    if jsv_is_undefined(v) {
        return dflt;
    }
    if not jsv_is_string_cell(v) {
        return _bn_int_or(v, dflt);
    }
    st: str = str_from_id(jsv_to_table_id(v));
    n: int = len(st);
    neg: bool = False;
    i: int = 0;
    if n > 0 and ord(st[0]) == 45 {
        neg = True;
        i = 1;
    }
    acc: int = 0;
    while i < n {
        acc = acc * 10 + (ord(st[i]) - 48);
        i = i + 1;
    }
    if neg {
        return -acc;
    }
    return acc;
}

"""begin/end argument acceptable without observable coercion: undefined or a number."""
def _bn_is_index_arg(v: JSValue) -> bool {
    return jsv_is_undefined(v) or jsv_is_int32(v) or jsv_is_double(v);
}

"""Relative index (ES §23.2.3.30 steps 7-10 / 15): ToIntegerOrInfinity, negatives
count from the end, clamped to [0, len]. `dflt` is used when `v` is undefined."""
def _bn_relative_index(v: JSValue, dflt: int, length: int) -> int {
    if jsv_is_undefined(v) {
        return dflt;
    }
    f: float = 0.0;
    if jsv_is_int32(v) {
        f = float(jsv_to_int32(v));
    } else {
        f = jsv_to_double(v);
    }
    if not (f == f) {
        return 0;
    }  # NaN → +0
    if f < 0.0 {
        if f <= -float(length) {
            return 0;
        }  # incl. -Infinity
        return length + int(f);  # int() truncates toward zero
    }
    if f >= float(length) {
        return length;
    }  # incl. +Infinity
    return int(f);
}

"""Default-species check for %TypedArray%.prototype.subarray (SpeciesConstructor,
ES §7.3.22): `constructor` must resolve by plain data lookup (no accessor on the
chain) to the receiver's intrinsic ctor (`_ctor`), and that ctor's @@species must
be the pristine native getter. Returns the ctor's `prototype` object, or
undefined when the JS path must run (user species / accessors / exotic ctor)."""
def _bn_default_species_proto(realm: Realm, view: JSValue) -> JSValue {
    if not jsv_is_undefined(js_object_lookup_getter(view, WK_CONSTRUCTOR)) {
        return js_undefined();
    }
    c: JSValue = js_object_get(view, WK_CONSTRUCTOR);
    dc: JSValue = js_object_get(view, _TAK_CTOR);
    if not _bn_is_closure(c) or c != dc {
        return js_undefined();
    }
    ci: int = jsv_to_table_id(c);
    if ci < 0 or ci >= len(realm.closures) {
        return js_undefined();
    }
    fp: JSValue = realm.closures[ci].fn_props;
    sk: int = SYMBOL_KEY_BASE + SYMBOL_SPECIES;
    g: JSValue = js_object_get_own_accessor_getter(fp, sk);
    if jsv_is_undefined(g) {
        # Own data / setter-only @@species shadows; otherwise inherit through the
        # ctor's [[Prototype]] chain (concrete ctor → %TypedArray%), one level.
        if js_object_has_own(fp, sk) or js_object_has_own_accessor(fp, sk) {
            return js_undefined();
        }
        op: JSValue = realm.closures[ci].object_proto;
        if not _bn_is_closure(op) {
            return js_undefined();
        }
        oi: int = jsv_to_table_id(op);
        if oi < 0 or oi >= len(realm.closures) {
            return js_undefined();
        }
        g = js_object_get_own_accessor_getter(realm.closures[oi].fn_props, sk);
    }
    if not is_native_val(g) or get_native_kind(g) != NATIVE_KIND_TA_SPECIES_GET {
        return js_undefined();
    }
    if js_object_has_own(fp, WK_NOT_CTOR) {
        return js_undefined();
    }
    proto: JSValue = realm.closures[ci].prototype_obj;
    if js_object_has_own(fp, WK_PROTOTYPE) {
        proto = js_object_get(fp, WK_PROTOTYPE);
    }
    if not jsv_is_object_cell(proto) or jsv_to_table_id(proto) <= 0 {
        return js_undefined();
    }
    return proto;
}

"""__buf.taSubarray(view, begin, end, endProvided): %TypedArray%.prototype.subarray
fast path. Handles the common case only — a live in-bounds fixed-length (or
length-tracking with an explicit end) view, numeric/undefined begin/end (no
observable coercion) and the default species — and returns undefined for
everything else so binary_types.js keeps its spec-complete slow path."""
def:pub ta_subarray(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    end_provided: bool = jsv_is_bool(args[3]) and jsv_to_bool(args[3]);
    return _bn_ta_subarray_impl(realm, args[0], args[1], args[2], end_provided);
}

def _bn_ta_subarray_impl(
    realm: Realm, view: JSValue, begin_v: JSValue, end_v: JSValue, end_provided: bool
) -> JSValue {
    _tak_seed();
    if not binary_is_typed_array(view) {
        return js_undefined();
    }
    if not _bn_is_index_arg(begin_v) or not _bn_is_index_arg(end_v) {
        return js_undefined();
    }
    # Length-tracking + no end → Construct(C, «buffer, byteOffset») keeps tracking
    # (and may RangeError on element-size alignment): leave that to the JS path.
    if binary_typed_array_is_length_tracking(view) and not end_provided {
        return js_undefined();
    }
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached or w.oob {
        return js_undefined();
    }
    proto: JSValue = _bn_default_species_proto(realm, view);
    if jsv_is_undefined(proto) {
        return js_undefined();
    }
    src_len: int = w.length;
    start: int = _bn_relative_index(begin_v, 0, src_len);
    fin: int = _bn_relative_index(end_v, src_len, src_len);
    new_len: int = fin - start;
    if new_len < 0 {
        new_len = 0;
    }
    return _bn_make_view(
        view, proto, w.byte_offset + start * w.bytes_per_element, new_len, False
    );
}

"""__buf.makeView(src, proto, startElem, newLen, isBuf): fixed-length view over
`src`'s buffer starting `startElem` elements into `src`, with the given
prototype (Buffer.prototype for buffer.js subarray/slice, which always yields a
Buffer regardless of species). `isBuf` also sets the `__isBuf` brand. Returns
undefined when src is not a live in-bounds view or the range does not fit."""
def:pub buf_make_view(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    src: JSValue = args[0];
    proto: JSValue = args[1];
    if not binary_is_typed_array(src) {
        return js_undefined();
    }
    if not jsv_is_object_cell(proto) or jsv_to_table_id(proto) <= 0 {
        return js_undefined();
    }
    w: BinaryViewWitness = binary_view_witness(src);
    if not w.valid or w.detached or w.oob {
        return js_undefined();
    }
    start: int = _bn_int_or(args[2], -1);
    new_len: int = _bn_int_or(args[3], -1);
    if start < 0 or new_len < 0 or start + new_len > w.length {
        return js_undefined();
    }
    is_buf: bool = len(args) >= 5 and jsv_is_bool(args[4]) and jsv_to_bool(args[4]);
    return _bn_make_view(
        src, proto, w.byte_offset + start * w.bytes_per_element, new_len, is_buf
    );
}


# ══════════════════════════════════════════════════════════════════════════════
# Construction and bulk byte operations.
#
# `new ArrayBuffer(n)` cost ~52µs and `new Uint8Array(n)` ~88µs — ~40 JS-level
# property sets / helper calls each, at ~1µs per interpreted operation — and
# every Buffer.alloc / Buffer.from(string) paid both, plus a per-character JS
# UTF-8 encode (Buffer.from("hello world") ≈ 290µs, buf.write ≈ 72µs).
# buf.copy / buf.equals were per-byte JS loops (~0.5µs per byte).
# The constructors keep their JS argument validation and prototype handling
# and hand the field initialisation + side-table registration to one native
# call; strings are encoded from the engine's internal UTF-8 (CESU-8 surrogate
# pairs, 4-char NUL sentinel) straight into the backing store.
# ══════════════════════════════════════════════════════════════════════════════

# ArrayBuffer instance-property key ids (binary_types.js `class ArrayBuffer`).
glob _ABK_SEEDED: bool = False,
     _ABK_PTR: int = -1,
     _ABK_BYTELENGTH: int = -1,
     _ABK_MAXBYTELENGTH: int = -1,
     _ABK_RESIZABLE: int = -1,
     _ABK_IMMUTABLE: int = -1,
     _ABK_DETACHED: int = -1,
     _ABK_IS_INSTANCE: int = -1;

# "_ptr"
# "_byteLength"
# "_maxByteLength"
# "_resizable"
# "_immutable"
# "_detached"
# "_isArrayBufferInstance"
def _abk_seed -> None {
    if _ABK_SEEDED {
        return;
    }
    _ABK_PTR = str_intern("_ptr");
    _ABK_BYTELENGTH = str_intern("_byteLength");
    _ABK_MAXBYTELENGTH = str_intern("_maxByteLength");
    _ABK_RESIZABLE = str_intern("_resizable");
    _ABK_IMMUTABLE = str_intern("_immutable");
    _ABK_DETACHED = str_intern("_detached");
    _ABK_IS_INSTANCE = str_intern("_isArrayBufferInstance");
    _ABK_SEEDED = True;
}

"""__buf.initArrayBuffer(ab, byteLength): the body of `new ArrayBuffer(n)` for a
plain (non-resizable) buffer whose arguments the JS constructor has already
validated — allocates the zeroed backing store, sets the instance fields in
constructor order (shared shape with the JS path) and registers the
side-table record. Returns true, or undefined when not applicable."""
def:pub buf_init_array_buffer(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    ab: JSValue = args[0];
    if not jsv_is_object_cell(ab) or jsv_to_table_id(ab) <= 0 {
        return js_undefined();
    }
    n: int = _bn_int_or(args[1], -1);
    if n < 0 {
        return js_undefined();
    }
    _abk_seed();
    ptr: int = 0;
    ptr_v: JSValue = js_int(0);
    if n > 0 {
        ptr = io_alloc(n);
        ptr_v = js_number(float(ptr));
    }
    js_object_set(ab, _ABK_PTR, ptr_v);
    js_object_set(ab, _ABK_BYTELENGTH, js_int(n));
    js_object_set(ab, _ABK_MAXBYTELENGTH, js_int(n));
    js_object_set(ab, _ABK_RESIZABLE, js_boolean(False));
    js_object_set(ab, _ABK_IMMUTABLE, js_boolean(False));
    js_object_set(ab, _ABK_DETACHED, js_boolean(False));
    js_object_set_flags(ab, _ABK_IS_INSTANCE, js_true(), 0);
    reg_ab: list[JSValue] = [ab, ptr_v, js_int(n), js_int(n), js_int(0), js_int(0)];
    _ = binary_register_buffer(reg_ab);
    return js_true();
}

"""__buf.initTypedArray(view, buffer, byteOffset, length, fixed, bpe, elemKind,
name, getter, setter, ctor): the body of the TypedArray constructor once the
JS side has validated the arguments and installed the prototype — sets the
instance fields in constructor order and registers the view record.
Returns true, or undefined when not applicable (JS path continues)."""
def:pub buf_init_typed_array(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 11 {
        return js_undefined();
    }
    view: JSValue = args[0];
    buffer: JSValue = args[1];
    if not jsv_is_object_cell(view) or jsv_to_table_id(view) <= 0 {
        return js_undefined();
    }
    if not binary_is_array_buffer(buffer) {
        return js_undefined();
    }
    byte_off: int = _bn_int_or(args[2], -1);
    length: int = _bn_int_or(args[3], -1);
    if byte_off < 0 or length < 0 {
        return js_undefined();
    }
    fixed: bool = jsv_is_bool(args[4]) and jsv_to_bool(args[4]);
    bpe: int = _bn_int_or(args[5], 1);
    ek: int = _bn_int_or(args[6], 0);
    if bpe <= 0 {
        return js_undefined();
    }
    # Spec validation (ES §23.2.5.1.5 InitializeTypedArrayFromArrayBuffer): the
    # JS constructor's fast paths rely on these — undefined sends them to the
    # full JS path, which throws the matching TypeError / RangeError.
    ab_store: BackingStore = binary_backing_store(buffer);
    if ab_store.detached {
        return js_undefined();
    }
    if byte_off % bpe != 0 {
        return js_undefined();
    }
    if byte_off + length * bpe > ab_store.byte_length {
        return js_undefined();
    }
    _tak_seed();
    js_object_set_flags(view, _TAK_IS_INSTANCE, js_true(), 0);
    js_object_set(view, _TAK_NAME, args[7]);
    js_object_set(view, _TAK_GETTER, args[8]);
    js_object_set(view, _TAK_SETTER, args[9]);
    js_object_set(view, _TAK_CTOR, args[10]);
    js_object_set(view, _TAK_BUFFER, buffer);
    js_object_set(view, _TAK_BYTEOFFSET, js_int(byte_off));
    js_object_set(view, _TAK_FIXEDLENGTH, js_boolean(fixed));
    js_object_set(view, _TAK_LENGTH, js_int(length));
    reg_ta: list[JSValue] = [
        view,
        buffer,
        js_int(byte_off),
        js_int(length),
        js_int(bpe),
        js_int(ek),
        js_boolean(not fixed)
    ];
    _ = binary_register_typed_array(reg_ta);
    return js_true();
}

# ── Engine string → wire UTF-8 / latin1 ──────────────────────────────────────
# Engine text is UTF-8 with two twists: an astral character is stored as a
# CESU-8 surrogate pair (two 3-byte ED xx xx sequences) and code unit 0 is the
# 4-char sentinel `\x00` (bytes 92 120 48 48). Lone surrogates become U+FFFD
# (EF BF BD), as node's utf8 encoder does.

"""True when s[i..] starts the 4-char NUL sentinel."""
def _bn_at_nul_sentinel(s: str, i: int, n: int) -> bool {
    return i + 3 < n
        and ord(s[i + 1]) == 120
        and ord(s[i + 2]) == 48
        and ord(s[i + 3]) == 48;
}

"""Wire UTF-8 byte length of engine string `s`."""
def _bn_wire_utf8_len(s: str) -> int {
    n: int = len(s);
    i: int = 0;
    out: int = 0;
    while i < n {
        b: int = ord(s[i]);
        if b < 128 {
            if b == 92 and _bn_at_nul_sentinel(s, i, n) {
                i = i + 4;
            } else {
                i = i + 1;
            }
            out = out + 1;
        } elif b == 237 and i + 2 < n and (ord(s[i + 1]) & 224) == 160 {
            if (ord(s[i + 1]) & 240) == 160
                and i + 5 < n
                and ord(s[i + 3]) == 237
                and (ord(s[i + 4]) & 240) == 176 {
                out = out + 4;  # high + low surrogate → one 4-byte scalar
                i = i + 6;
            } else {
                out = out + 3;  # lone surrogate → U+FFFD
                i = i + 3;
            }
        } else {
            l: int = 2;
            if b >= 240 {
                l = 4;
            } elif b >= 224 {
                l = 3;
            }
            if i + l > n {
                l = n - i;
            }
            out = out + l;
            i = i + l;
        }
    }
    return out;
}

"""Encode engine string `s` as wire UTF-8 into dst[off .. off+cap). Returns the
bytes written; never splits a character (node: a character that does not fit
is not written at all)."""
def _bn_wire_utf8_write(s: str, dst: int, off: int, cap: int) -> int {
    n: int = len(s);
    i: int = 0;
    w: int = 0;
    while i < n {
        b: int = ord(s[i]);
        if b < 128 {
            if w + 1 > cap {
                break;
            }
            if b == 92 and _bn_at_nul_sentinel(s, i, n) {
                write_byte(dst, off + w, 0);
                i = i + 4;
            } else {
                write_byte(dst, off + w, b);
                i = i + 1;
            }
            w = w + 1;
        } elif b == 237 and i + 2 < n and (ord(s[i + 1]) & 224) == 160 {
            b1: int = ord(s[i + 1]);
            b2: int = ord(s[i + 2]);
            if (b1 & 240) == 160
                and i + 5 < n
                and ord(s[i + 3]) == 237
                and (ord(s[i + 4]) & 240) == 176 {
                if w + 4 > cap {
                    break;
                }
                hi: int = ((b & 15) << 12) | ((b1 & 63) << 6) | (b2 & 63);
                lo: int = ((ord(s[i + 3]) & 15) << 12)
                    | ((ord(s[i + 4]) & 63) << 6)
                    | (ord(s[i + 5]) & 63);
                cp: int = 65536 + ((hi - 55296) << 10) + (lo - 56320);
                write_byte(dst, off + w, 240 | (cp >> 18));
                write_byte(dst, off + w + 1, 128 | ((cp >> 12) & 63));
                write_byte(dst, off + w + 2, 128 | ((cp >> 6) & 63));
                write_byte(dst, off + w + 3, 128 | (cp & 63));
                w = w + 4;
                i = i + 6;
            } else {
                if w + 3 > cap {
                    break;
                }
                write_byte(dst, off + w, 239);
                write_byte(dst, off + w + 1, 191);
                write_byte(dst, off + w + 2, 189);
                w = w + 3;
                i = i + 3;
            }
        } else {
            l: int = 2;
            if b >= 240 {
                l = 4;
            } elif b >= 224 {
                l = 3;
            }
            if i + l > n {
                l = n - i;
            }
            if w + l > cap {
                break;
            }
            k: int = 0;
            while k < l {
                write_byte(dst, off + w + k, ord(s[i + k]));
                k = k + 1;
            }
            w = w + l;
            i = i + l;
        }
    }
    return w;
}

"""latin1 / ascii write: the low byte of each UTF-16 code unit of `s` into
dst[off .. off+cap). Returns the bytes written."""
def _bn_latin1_write(s: str, dst: int, off: int, cap: int) -> int {
    n: int = len(s);
    i: int = 0;
    w: int = 0;
    while i < n and w < cap {
        b: int = ord(s[i]);
        unit: int = b;
        if b < 128 {
            if b == 92 and _bn_at_nul_sentinel(s, i, n) {
                unit = 0;
                i = i + 4;
            } else {
                i = i + 1;
            }
        } elif b < 224 and i + 1 < n {
            unit = ((b & 31) << 6) | (ord(s[i + 1]) & 63);
            i = i + 2;
        } elif b < 240 and i + 2 < n {
            unit = ((b & 15) << 12)
                | ((ord(s[i + 1]) & 63) << 6)
                | (ord(s[i + 2]) & 63);
            i = i + 3;
        } elif b >= 240 and i + 3 < n {
            # Real 4-byte scalar (not produced by the engine, handled for safety):
            # two UTF-16 units → two bytes.
            cp4: int = ((b & 7) << 18)
                | ((ord(s[i + 1]) & 63) << 12)
                | ((ord(s[i + 2]) & 63) << 6)
                | (ord(s[i + 3]) & 63);
            cp4 = cp4 - 65536;
            write_byte(dst, off + w, (55296 + (cp4 >> 10)) & 255);
            w = w + 1;
            unit = 56320 + (cp4 & 1023);
            i = i + 4;
            if w >= cap {
                break;
            }
        } else {
            i = i + 1;  # truncated sequence: emit the byte itself
        }
        write_byte(dst, off + w, unit & 255);
        w = w + 1;
    }
    return w;
}

"""__buf.utf8ByteLength(str) → wire UTF-8 byte count (undefined for non-strings)."""
def:pub buf_utf8_byte_length(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(args[0]));
    return js_int(_bn_wire_utf8_len(s));
}

"""__buf.writeString(view, str, offset, maxLength, encoding) → bytes written.
utf8 / latin1 / binary / ascii only; undefined when not handled (non-view or
detached/OOB receiver, non-string, offset out of range, other encodings) so
buffer.js keeps its own validation and errors."""
def:pub buf_write_string(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    enc: int = _ENC_UTF8;
    if len(args) >= 5 {
        enc = _bn_encoding(args[4]);
    }
    if enc != _ENC_UTF8
        and enc != _ENC_LATIN1
        and enc != _ENC_ASCII
        and enc != _ENC_BASE64
        and enc != _ENC_BASE64URL
        and enc != _ENC_HEX {
        return js_undefined();
    }
    view: JSValue = args[0];
    if not binary_is_typed_array(view) {
        return js_undefined();
    }
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached or w.oob {
        return js_undefined();
    }
    blen: int = w.byte_length;
    off: int = 0;
    if len(args) >= 3 {
        off = _bn_int_or(args[2], 0);
    }
    if off < 0 or off > blen {
        return js_undefined();
    }
    cap: int = blen - off;
    if len(args) >= 4 and not jsv_is_undefined(args[3]) and not jsv_is_null(args[3]) {
        max_len: int = _bn_int_or(args[3], cap);
        if max_len < 0 {
            return js_undefined();
        }
        if max_len < cap {
            cap = max_len;
        }
    }
    s: str = str_from_id(jsv_to_table_id(args[1]));
    if cap == 0 or len(s) == 0 {
        return js_int(0);
    }
    store: BackingStore = binary_backing_store(binary_typed_array_buffer(view));
    if store.ptr == 0 {
        return js_undefined();
    }
    dst: int = store.ptr + w.byte_offset;
    if enc == _ENC_UTF8 {
        return js_int(_bn_wire_utf8_write(s, dst, off, cap));
    }
    if enc == _ENC_BASE64 or enc == _ENC_BASE64URL {
        return js_int(_bn_b64_write(s, dst, off, cap));
    }
    if enc == _ENC_HEX {
        return js_int(_bn_hex_write(s, dst, off, cap));
    }
    return js_int(_bn_latin1_write(s, dst, off, cap));
}

"""__buf.copyBytes(src, target, targetStart, sourceStart, sourceEnd) → bytes
copied (Buffer.prototype.copy semantics: clamps to both views, overlapping
ranges safe via memmove). undefined when either side is not a live view."""
def:pub buf_copy_bytes(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 5 {
        return js_undefined();
    }
    src: JSValue = args[0];
    tgt: JSValue = args[1];
    if not binary_is_typed_array(src) or not binary_is_typed_array(tgt) {
        return js_undefined();
    }
    ws: BinaryViewWitness = binary_view_witness(src);
    wt: BinaryViewWitness = binary_view_witness(tgt);
    if not ws.valid or ws.detached or ws.oob or not wt.valid or wt.detached or wt.oob {
        return js_undefined();
    }
    ts: int = _bn_int_or(args[2], 0);
    ss: int = _bn_int_or(args[3], 0);
    se: int = _bn_int_or(args[4], ws.byte_length);
    if ts < 0 or ss < 0 {
        return js_undefined();
    }
    if se > ws.byte_length {
        se = ws.byte_length;
    }
    n: int = se - ss;
    if n <= 0 or ts >= wt.byte_length {
        return js_int(0);
    }
    if ts + n > wt.byte_length {
        n = wt.byte_length - ts;
    }
    sstore: BackingStore = binary_backing_store(binary_typed_array_buffer(src));
    tstore: BackingStore = binary_backing_store(binary_typed_array_buffer(tgt));
    if sstore.ptr == 0 or tstore.ptr == 0 {
        return js_int(0);
    }
    memmove(tstore.ptr + wt.byte_offset + ts, sstore.ptr + ws.byte_offset + ss, n);
    return js_int(n);
}

"""__buf.equalsBytes(a, b) → true/false when both are live views (byte-wise
compare over each view's byte span); undefined otherwise."""
def:pub buf_equals_bytes(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    a: JSValue = args[0];
    b: JSValue = args[1];
    if not binary_is_typed_array(a) or not binary_is_typed_array(b) {
        return js_undefined();
    }
    wa: BinaryViewWitness = binary_view_witness(a);
    wb: BinaryViewWitness = binary_view_witness(b);
    if not wa.valid or wa.detached or wa.oob or not wb.valid or wb.detached or wb.oob {
        return js_undefined();
    }
    if wa.byte_length != wb.byte_length {
        return js_boolean(False);
    }
    if wa.byte_length == 0 {
        return js_boolean(True);
    }
    astore: BackingStore = binary_backing_store(binary_typed_array_buffer(a));
    bstore: BackingStore = binary_backing_store(binary_typed_array_buffer(b));
    if astore.ptr == 0 or bstore.ptr == 0 {
        return js_undefined();
    }
    a_ptr: int = astore.ptr + wa.byte_offset;
    b_ptr: int = bstore.ptr + wb.byte_offset;
    # 8 bytes per step, byte tail. (libc memcmp returns a C int — i32 — which
    # the i64-typed FFI declaration mis-lowered to a stub; a native loop is
    # ABI-safe and fast enough: ~0.2ns/byte.)
    n: int = wa.byte_length;
    i: int = 0;
    while i + 8 <= n {
        if read_u64(a_ptr, i) != read_u64(b_ptr, i) {
            return js_boolean(False);
        }
        i = i + 8;
    }
    while i < n {
        if read_byte(a_ptr, i) != read_byte(b_ptr, i) {
            return js_boolean(False);
        }
        i = i + 1;
    }
    return js_boolean(True);
}


# ══════════════════════════════════════════════════════════════════════════════
# Fully native prototype methods.
#
# The JS wrappers that called the natives above still cost ~2.5µs each (class
# method call ≈0.9µs, `!== undefined` probe, argument shuffling): with the
# decode itself at ~1.2µs, the wrapper was two thirds of the call. These are
# installed directly as `TextDecoder.prototype.decode`,
# `Buffer.prototype.toString`, `Buffer.prototype.subarray`/`slice` and
# `%TypedArray%.prototype.subarray`. Every case that is not the plain hot path
# (exotic receivers, non-number ranges, unknown encodings, user species, …)
# is forwarded to the ORIGINAL JS implementation, registered once at load
# via __buf.set*Slow(fn), so error objects and spec corner cases are unchanged.
# ══════════════════════════════════════════════════════════════════════════════

# JS slow-path functions and Buffer.prototype (0 = not registered; pinned as
# GC roots when set — glob JSValues are invisible to the mark phase).
glob _BN_TD_DECODE_SLOW: JSValue = 0,
     _BN_BUF_TOSTRING_SLOW: JSValue = 0,
     _BN_BUF_SUBARRAY_SLOW: JSValue = 0,
     _BN_TA_SUBARRAY_SLOW: JSValue = 0,
     _BN_BUFFER_PROTO: JSValue = 0,
     _TDK_SEEDED: bool = False,
     _TDK_ENCODING: int = -1,
     _TDK_FATAL: int = -1;

# "_encoding"
# "_fatal"
def _tdk_seed -> None {
    if _TDK_SEEDED {
        return;
    }
    _TDK_ENCODING = str_intern("_encoding");
    _TDK_FATAL = str_intern("_fatal");
    _TDK_SEEDED = True;
}

"""__buf.setTdDecodeSlow(fn): register the JS TextDecoder.prototype.decode."""
def:pub set_td_decode_slow(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) >= 1 {
        _BN_TD_DECODE_SLOW = args[0];
        gc_pin_value(args[0]);
    }
    return js_undefined();
}

"""__buf.setBufSlow(toStringFn, subarrayFn, BufferPrototype)."""
def:pub set_buf_slow(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) >= 3 {
        _BN_BUF_TOSTRING_SLOW = args[0];
        gc_pin_value(args[0]);
        _BN_BUF_SUBARRAY_SLOW = args[1];
        gc_pin_value(args[1]);
        _BN_BUFFER_PROTO = args[2];
        gc_pin_value(args[2]);
    }
    return js_undefined();
}

"""__buf.setTaSubarraySlow(fn): register the JS %TypedArray%.prototype.subarray."""
def:pub set_ta_subarray_slow(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) >= 1 {
        _BN_TA_SUBARRAY_SLOW = args[0];
        gc_pin_value(args[0]);
    }
    return js_undefined();
}

"""Forward to a registered JS slow path (undefined when none / no VM bridge)."""
def _bn_call_slow(fn: JSValue, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if fn == 0 or not js_call_bridge_ready() {
        return js_undefined();
    }
    return js_call_observable(fn, this_val, args);
}

glob _BN_HEX_CHARS: str = "0123456789abcdef",
     _BN_B64_STD: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _BN_B64_URL: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

def _bn_decode_hex(ptr: int, s: int, e: int) -> str {
    n: int = e - s;
    if n <= 0 {
        return "";
    }
    out: int = io_alloc(n * 2 + 33);
    data: int = out + 32;
    j: int = 0;
    i: int = s;
    while i < e {
        b: int = read_byte(ptr, i);
        write_byte(data, j, ord(_BN_HEX_CHARS[b >> 4]));
        write_byte(data, j + 1, ord(_BN_HEX_CHARS[b & 15]));
        j = j + 2;
        i = i + 1;
    }
    write_byte(data, j, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

"""base64 (padded) / base64url (unpadded), as buffer.js _decodeBase64."""
def _bn_decode_base64(ptr: int, s: int, e: int, url_safe: bool) -> str {
    n: int = e - s;
    if n <= 0 {
        return "";
    }
    tbl: str = _BN_B64_STD;
    if url_safe {
        tbl = _BN_B64_URL;
    }
    out: int = io_alloc(((n + 2) // 3) * 4 + 33);
    data: int = out + 32;
    j: int = 0;
    i: int = s;
    while i < e {
        b0: int = read_byte(ptr, i);
        b1: int = 0;
        b2: int = 0;
        if i + 1 < e {
            b1 = read_byte(ptr, i + 1);
        }
        if i + 2 < e {
            b2 = read_byte(ptr, i + 2);
        }
        write_byte(data, j, ord(tbl[b0 >> 2]));
        write_byte(data, j + 1, ord(tbl[((b0 & 3) << 4) | (b1 >> 4)]));
        j = j + 2;
        if i + 1 < e {
            write_byte(data, j, ord(tbl[((b1 & 15) << 2) | (b2 >> 6)]));
            j = j + 1;
        } elif not url_safe {
            write_byte(data, j, 61);
            j = j + 1;
        }
        if i + 2 < e {
            write_byte(data, j, ord(tbl[b2 & 63]));
            j = j + 1;
        } elif not url_safe {
            write_byte(data, j, 61);
            j = j + 1;
        }
        i = i + 3;
    }
    write_byte(data, j, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

"""utf16le: each little-endian byte pair is one UTF-16 code unit (a trailing odd
byte is dropped, as node does)."""
def _bn_decode_utf16le(ptr: int, s: int, e: int) -> str {
    units: int = (e - s) // 2;
    if units <= 0 {
        return "";
    }
    out: int = io_alloc(units * 4 + 33);
    data: int = out + 32;
    j: int = 0;
    i: int = s;
    k: int = 0;
    while k < units {
        u: int = read_byte(ptr, i) | (read_byte(ptr, i + 1) << 8);
        j = _bn_put_unit(data, j, u);
        i = i + 2;
        k = k + 1;
    }
    write_byte(data, j, 0);
    result: str = str_from_raw(data);
    io_free(out);
    return result;
}

"""TextDecoder.prototype.decode(input) — native method. `this._encoding` must
be "utf-8" (anything else → the JS original, which throws its RangeError);
typed array / ArrayBuffer / DataView inputs decode straight off the backing
store; undefined/null → ""; other inputs → JS original (duck-typed sources,
its TypeError)."""
def:pub td_decode_method(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    _tdk_seed();
    enc_v: JSValue = js_object_get(this_val, _TDK_ENCODING);
    enc_ok: bool = False;
    if jsv_is_string_cell(enc_v) {
        es: str = str_from_id(jsv_to_table_id(enc_v));
        if es == "utf-8" {
            enc_ok = True;
        }
    }
    if not enc_ok {
        return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
    }
    fatal_v: JSValue = js_object_get(this_val, _TDK_FATAL);
    fatal: bool = jsv_is_bool(fatal_v) and jsv_to_bool(fatal_v);
    input: JSValue = js_undefined();
    if len(args) >= 1 {
        input = args[0];
    }
    if jsv_is_undefined(input) or jsv_is_null(input) {
        return jsv_from_string_id(str_heap(""));
    }
    ptr: int = 0;
    blen: int = 0;
    if binary_is_typed_array(input) {
        w: BinaryViewWitness = binary_view_witness(input);
        if not w.valid or w.detached or w.oob {
            return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
        }
        blen = w.byte_length;
        if blen == 0 {
            return jsv_from_string_id(str_heap(""));
        }
        ptr = _bn_view_ptr(input);
    } elif binary_is_array_buffer(input) {
        store: BackingStore = binary_backing_store(input);
        if store.detached {
            return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
        }
        blen = store.byte_length;
        if blen == 0 {
            return jsv_from_string_id(str_heap(""));
        }
        ptr = store.ptr;
    } elif binary_is_data_view(input) {
        wd: BinaryViewWitness = binary_view_witness(input);
        dv_buf: JSValue = binary_data_view_buffer(input);
        if not wd.valid or wd.detached or not binary_is_array_buffer(dv_buf) {
            return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
        }
        blen = wd.byte_length;
        if blen == 0 {
            return jsv_from_string_id(str_heap(""));
        }
        ptr = binary_backing_store(dv_buf).ptr + wd.byte_offset;
    } else {
        return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
    }
    if ptr == 0 {
        return _bn_call_slow(_BN_TD_DECODE_SLOW, this_val, args);
    }
    return jsv_from_string_id(str_heap(_bn_decode_utf8(ptr, 0, blen, fatal)));
}

"""Buffer.prototype.toString(encoding, start, end) — native method with node's
range semantics (start <= 0 → 0, start >= len → "", end undefined/> len → len,
end <= start → ""). Handles utf8 / latin1 / binary / ascii / hex / base64 /
base64url / utf16le; other encodings, non-view receivers and non-number
ranges go to the JS original (its ERR_UNKNOWN_ENCODING etc.)."""
def:pub buf_tostring_method(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if not binary_is_typed_array(this_val) {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    enc: int = _ENC_UTF8;
    if len(args) >= 1 {
        enc = _bn_encoding(args[0]);
    }
    if enc == _ENC_OTHER {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    if len(args) >= 2 and not _bn_is_range_arg(args[1]) {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    if len(args) >= 3 and not _bn_is_range_arg(args[2]) {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    w: BinaryViewWitness = binary_view_witness(this_val);
    if not w.valid or w.detached or w.oob {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    blen: int = w.byte_length;
    s: int = 0;
    e: int = blen;
    if len(args) >= 2 {
        s = _bn_range_int(args[1], 0);
    }
    if len(args) >= 3 {
        e = _bn_range_int(args[2], blen);
    }
    if s < 0 {
        s = 0;
    }
    if e > blen {
        e = blen;
    }
    if e <= s or s >= blen {
        return jsv_from_string_id(str_heap(""));
    }
    ptr: int = _bn_view_ptr(this_val);
    if ptr == 0 {
        return _bn_call_slow(_BN_BUF_TOSTRING_SLOW, this_val, args);
    }
    if enc == _ENC_UTF8 {
        return jsv_from_string_id(str_heap(_bn_decode_utf8(ptr, s, e, False)));
    }
    if enc == _ENC_LATIN1 or enc == _ENC_ASCII {
        return jsv_from_string_id(
            str_heap(_bn_decode_latin1(ptr, s, e, enc == _ENC_ASCII))
        );
    }
    if enc == _ENC_HEX {
        return jsv_from_string_id(str_heap(_bn_decode_hex(ptr, s, e)));
    }
    if enc == _ENC_BASE64 {
        return jsv_from_string_id(str_heap(_bn_decode_base64(ptr, s, e, False)));
    }
    if enc == _ENC_BASE64URL {
        return jsv_from_string_id(str_heap(_bn_decode_base64(ptr, s, e, True)));
    }
    return jsv_from_string_id(str_heap(_bn_decode_utf16le(ptr, s, e)));
}

"""%TypedArray%.prototype.subarray(begin, end) — native method: the default-
species fast path, else the JS original (species, coercion, detached errors)."""
def:pub ta_subarray_method(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    begin_v: JSValue = js_undefined();
    end_v: JSValue = js_undefined();
    if len(args) >= 1 {
        begin_v = args[0];
    }
    if len(args) >= 2 {
        end_v = args[1];
    }
    r: JSValue = _bn_ta_subarray_impl(realm, this_val, begin_v, end_v, len(args) > 1);
    if jsv_is_undefined(r) {
        return _bn_call_slow(_BN_TA_SUBARRAY_SLOW, this_val, args);
    }
    return r;
}

"""Buffer.prototype.subarray / slice (start, end) — native method with
buffer.js semantics (undefined/null → 0 / len; negatives count from the end;
clamped; end < start → empty). Result is always a Buffer (Buffer.prototype).
Non-number arguments / non-view receivers → JS original."""
def:pub buf_subarray_method(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if _BN_BUFFER_PROTO == 0 or not binary_is_typed_array(this_val) {
        return _bn_call_slow(_BN_BUF_SUBARRAY_SLOW, this_val, args);
    }
    start_v: JSValue = js_undefined();
    end_v: JSValue = js_undefined();
    if len(args) >= 1 {
        start_v = args[0];
    }
    if len(args) >= 2 {
        end_v = args[1];
    }
    if not (jsv_is_null(start_v) or _bn_is_index_arg(start_v))
        or not (jsv_is_null(end_v) or _bn_is_index_arg(end_v)) {
        return _bn_call_slow(_BN_BUF_SUBARRAY_SLOW, this_val, args);
    }
    w: BinaryViewWitness = binary_view_witness(this_val);
    if not w.valid or w.detached or w.oob {
        return _bn_call_slow(_BN_BUF_SUBARRAY_SLOW, this_val, args);
    }
    blen: int = w.length;
    s: int = 0;
    if not (jsv_is_undefined(start_v) or jsv_is_null(start_v)) {
        s = _bn_relative_index(start_v, 0, blen);
    }
    e: int = blen;
    if not (jsv_is_undefined(end_v) or jsv_is_null(end_v)) {
        e = _bn_relative_index(end_v, blen, blen);
    }
    if e < s {
        e = s;
    }
    return _bn_make_view(this_val, _BN_BUFFER_PROTO, w.byte_offset + s, e - s, True);
}


# ══════════════════════════════════════════════════════════════════════════════
# Bulk typed-array copies and binary string decoding.
#
# `%TypedArray%.prototype.set`, `.slice` and construct-from-typed-array copied
# ELEMENT BY ELEMENT through JS `_readAt`/`_writeAt` (~80µs per element:
# 10.6s for a 131KB source); esbuild's stdout reader calls `set` on every
# chunk of every transform response. `Buffer.from(str, "base64")` decoded per
# character in JS (4.1s for 131KB); the child_process bridge delivers every
# stdout chunk as base64.
# ══════════════════════════════════════════════════════════════════════════════

glob _BN_AB_PROTO: JSValue = 0;  # ArrayBuffer.prototype (pinned), for native allocation

"""__buf.setArrayBufferProto(ArrayBuffer.prototype)."""
def:pub set_ab_proto(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) >= 1 {
        _BN_AB_PROTO = args[0];
        gc_pin_value(args[0]);
    }
    return js_undefined();
}

"""A fresh plain ArrayBuffer of `n` zeroed bytes (as buf_init_array_buffer), or
undefined when ArrayBuffer.prototype is not registered."""
def _bn_new_array_buffer(n: int) -> JSValue {
    if _BN_AB_PROTO == 0 or n < 0 {
        return js_undefined();
    }
    _abk_seed();
    ab: JSValue = js_object_create(_BN_AB_PROTO);
    ptr: int = 0;
    ptr_v: JSValue = js_int(0);
    if n > 0 {
        ptr = io_alloc(n);
        ptr_v = js_number(float(ptr));
    }
    js_object_set(ab, _ABK_PTR, ptr_v);
    js_object_set(ab, _ABK_BYTELENGTH, js_int(n));
    js_object_set(ab, _ABK_MAXBYTELENGTH, js_int(n));
    js_object_set(ab, _ABK_RESIZABLE, js_boolean(False));
    js_object_set(ab, _ABK_IMMUTABLE, js_boolean(False));
    js_object_set(ab, _ABK_DETACHED, js_boolean(False));
    js_object_set_flags(ab, _ABK_IS_INSTANCE, js_true(), 0);
    reg_ab: list[JSValue] = [ab, ptr_v, js_int(n), js_int(n), js_int(0), js_int(0)];
    _ = binary_register_buffer(reg_ab);
    return ab;
}

"""Element size of an integer element kind 1..7 (Int8/Uint8/Uint8Clamped/Int16/Uint16/Int32/Uint32)."""
def _bn_kind_bpe(kind: int) -> int {
    if kind <= 3 {
        return 1;
    }
    if kind <= 5 {
        return 2;
    }
    return 4;
}

"""Load element i of an integer kind as a signed/unsigned int per the kind."""
def _bn_load_int(ptr: int, kind: int, i: int) -> int {
    bpe: int = _bn_kind_bpe(kind);
    off: int = i * bpe;
    v: int = read_byte(ptr, off);
    if bpe >= 2 {
        v = v | (read_byte(ptr, off + 1) << 8);
    }
    if bpe == 4 {
        v = v | (read_byte(ptr, off + 2) << 16) | (read_byte(ptr, off + 3) << 24);
    }
    if kind == 1 and v >= 128 {
        v = v - 256;
    } elif kind == 4 and v >= 32768 {
        v = v - 65536;
    } elif kind == 6 and v >= 2147483648 {
        v = v - 4294967296;
    }
    return v;
}

"""Store integer v as element i of an integer kind: modulo 2^bits (two's
complement) for the wrapping kinds, clamp to 0..255 for Uint8Clamped."""
def _bn_store_int(ptr: int, kind: int, i: int, v: int) {
    bpe: int = _bn_kind_bpe(kind);
    off: int = i * bpe;
    u: int = v;
    if kind == 3 {
        if u < 0 {
            u = 0;
        } elif u > 255 {
            u = 255;
        }
    } else {
        u = u & ((1 << (bpe * 8)) - 1);
    }
    write_byte(ptr, off, u & 255);
    if bpe >= 2 {
        write_byte(ptr, off + 1, (u >> 8) & 255);
    }
    if bpe == 4 {
        write_byte(ptr, off + 2, (u >> 16) & 255);
        write_byte(ptr, off + 3, (u >> 24) & 255);
    }
}

"""Element values of the last successful _bn_probe_int_array, consumed by
ta_fill_from_probe (_BN_PROBE_READY = 1 while unconsumed)."""
glob _BN_PROBE_VALS: list[int] = [];
glob _BN_PROBE_READY: int = 0;

"""Read every element of `src` into _BN_PROBE_VALS and return the count, or -1
(nothing stored) unless `src` is a genuine data-only Array — no accessors, not
a Proxy — while no prototype carries index properties, holding only int32
values with no holes. For such an array each Get(src, k) is a plain own-data
read with no side effects, so reading them all in one native pass is
indistinguishable from the spec's per-element reads."""
def _bn_probe_int_array(src: JSValue) -> int {
    _BN_PROBE_READY = 0;
    if not js_is_array(src)
        or not js_object_array_is_dataonly_fast(src)
        or not idx_protector_ok() {
        return -1;
    }
    n: int = _array_len_from_value(js_object_get(src, WK_LENGTH));
    vals: list[int] = [];
    i: int = 0;
    while i < n {
        v: JSValue = js_array_get(src, i);
        if not jsv_is_int32(v) {
            return -1;
        }
        vals.append(jsv_to_int32(v));
        i = i + 1;
    }
    _BN_PROBE_VALS = vals;
    _BN_PROBE_READY = 1;
    return n;
}

"""Write _BN_PROBE_VALS into integer-kind view `tgt` from element `off`.
False (nothing written) unless the view is live, writable, integer-kind and
the values fit."""
def _bn_store_probe(tgt: JSValue, off: int) -> bool {
    tk: int = binary_typed_array_element_kind(tgt);
    if tk < 1 or tk > 7 {
        return False;
    }
    wt: BinaryViewWitness = binary_view_witness(tgt);
    if not wt.valid or wt.detached or wt.oob {
        return False;
    }
    n: int = len(_BN_PROBE_VALS);
    if off < 0 or off + n > wt.length {
        return False;
    }
    if n == 0 {
        return True;
    }
    store: BackingStore = binary_backing_store(binary_typed_array_buffer(tgt));
    if store.ptr == 0 or store.immutable {
        return False;
    }
    tptr: int = store.ptr + wt.byte_offset + off * wt.bytes_per_element;
    i: int = 0;
    while i < n {
        _bn_store_int(tptr, tk, i, _BN_PROBE_VALS[i]);
        i = i + 1;
    }
    return True;
}

"""__buf.intArrayProbe(arr): IterableToList for a plain int32 Array without
driving the iterator — returns the element count and stages the values for
__buf.taFillFromProbe, or -1 when `arr` doesn't qualify (see
_bn_probe_int_array). The TypedArray constructor calls this only after checking
that arr's @@iterator and %ArrayIteratorPrototype%.next are the built-ins."""
def:pub array_int_probe(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 1 {
        return js_int(-1);
    }
    return js_int(_bn_probe_int_array(args[0]));
}

"""__buf.taFillFromProbe(view): write the values staged by the last
intArrayProbe into a freshly allocated integer-kind view of exactly that
length. True when done; undefined (nothing written) otherwise."""
def:pub ta_fill_from_probe(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if _BN_PROBE_READY == 0 or len(args) < 1 {
        return js_undefined();
    }
    _BN_PROBE_READY = 0;
    tgt: JSValue = args[0];
    ok: bool = (
        binary_is_typed_array(tgt)
        and binary_view_witness(tgt).length == len(_BN_PROBE_VALS)
        and _bn_store_probe(tgt, 0)
    );
    _BN_PROBE_VALS = [];
    if ok {
        return js_true();
    }
    return js_undefined();
}

"""__buf.taSet(target, source, offset): SetTypedArrayFromTypedArray (ES
§23.2.3.26.2) fast path — same element kind: one memmove (overlap-safe, so a
shared buffer is fine); integer→integer kinds on DIFFERENT buffers: native
convert loop. A plain int32 Array source into an integer kind (see
_bn_probe_int_array) is copied natively too. Returns true when done; undefined
for anything else (float / bigint conversions, other sources, out-of-range
offset → JS path & errors)."""
def:pub ta_set(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    tgt: JSValue = args[0];
    src: JSValue = args[1];
    off_v: JSValue = js_undefined();
    if len(args) >= 3 {
        off_v = args[2];
    }
    if not binary_is_typed_array(tgt) {
        return js_undefined();
    }
    if not _bn_is_index_arg(off_v) {
        return js_undefined();
    }
    if not binary_is_typed_array(src) {
        # SetTypedArrayFromArrayLike over a plain int32 Array.
        if _bn_probe_int_array(src) < 0 {
            return js_undefined();
        }
        _BN_PROBE_READY = 0;
        a_off: int = 0;
        if not jsv_is_undefined(off_v) {
            af: float = 0.0;
            if jsv_is_int32(off_v) {
                af = float(jsv_to_int32(off_v));
            } else {
                af = jsv_to_double(off_v);
            }
            if not (af == af) {
                af = 0.0;
            }
            if af < 0.0 or af > 2147483647.0 {
                _BN_PROBE_VALS = [];
                return js_undefined();
            }
            a_off = int(af);
        }
        a_ok: bool = _bn_store_probe(tgt, a_off);
        _BN_PROBE_VALS = [];
        if a_ok {
            return js_true();
        }
        return js_undefined();
    }
    off: int = 0;
    if not jsv_is_undefined(off_v) {
        f: float = 0.0;
        if jsv_is_int32(off_v) {
            f = float(jsv_to_int32(off_v));
        } else {
            f = jsv_to_double(off_v);
        }
        if not (f == f) {
            f = 0.0;
        }
        if f < 0.0 or f > 2147483647.0 {
            return js_undefined();
        }
        off = int(f);
    }
    wt: BinaryViewWitness = binary_view_witness(tgt);
    ws: BinaryViewWitness = binary_view_witness(src);
    if not wt.valid or wt.detached or wt.oob or not ws.valid or ws.detached or ws.oob {
        return js_undefined();
    }
    if off + ws.length > wt.length {
        return js_undefined();
    }
    tk: int = binary_typed_array_element_kind(tgt);
    sk: int = binary_typed_array_element_kind(src);
    tstore: BackingStore = binary_backing_store(binary_typed_array_buffer(tgt));
    sstore: BackingStore = binary_backing_store(binary_typed_array_buffer(src));
    if ws.length == 0 {
        return js_true();
    }
    if tstore.ptr == 0 or sstore.ptr == 0 {
        return js_undefined();
    }
    tptr: int = tstore.ptr + wt.byte_offset + off * wt.bytes_per_element;
    sptr: int = sstore.ptr + ws.byte_offset;
    if tk == sk {
        memmove(tptr, sptr, ws.length * ws.bytes_per_element);
        return js_true();
    }
    if tk < 1 or tk > 7 or sk < 1 or sk > 7 {
        return js_undefined();
    }
    if tstore.ptr == sstore.ptr {
        return js_undefined();
    }  # same buffer, different kinds → JS (clone semantics)
    i: int = 0;
    n: int = ws.length;
    while i < n {
        _bn_store_int(tptr, tk, i, _bn_load_int(sptr, sk, i));
        i = i + 1;
    }
    return js_true();
}

"""__buf.taSlice(view, begin, end): %TypedArray%.prototype.slice fast path for
the default species — a fresh ArrayBuffer + view of the same kind, bytes
memcpy'd. undefined → JS path (species, coercion, detached errors)."""
def:pub ta_slice(realm: Realm, this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    view: JSValue = args[0];
    begin_v: JSValue = js_undefined();
    end_v: JSValue = js_undefined();
    if len(args) >= 2 {
        begin_v = args[1];
    }
    if len(args) >= 3 {
        end_v = args[2];
    }
    if not binary_is_typed_array(view) {
        return js_undefined();
    }
    if not _bn_is_index_arg(begin_v) or not _bn_is_index_arg(end_v) {
        return js_undefined();
    }
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached or w.oob {
        return js_undefined();
    }
    proto: JSValue = _bn_default_species_proto(realm, view);
    if jsv_is_undefined(proto) {
        return js_undefined();
    }
    src_len: int = w.length;
    start: int = _bn_relative_index(begin_v, 0, src_len);
    fin: int = _bn_relative_index(end_v, src_len, src_len);
    n: int = fin - start;
    if n < 0 {
        n = 0;
    }
    ab: JSValue = _bn_new_array_buffer(n * w.bytes_per_element);
    if jsv_is_undefined(ab) {
        return js_undefined();
    }
    out: JSValue = _bn_make_view_on(view, ab, proto, 0, n, False);
    if jsv_is_undefined(out) {
        return js_undefined();
    }
    if n > 0 {
        sstore: BackingStore = binary_backing_store(binary_typed_array_buffer(view));
        dstore: BackingStore = binary_backing_store(ab);
        memmove(
            dstore.ptr,
            sstore.ptr + w.byte_offset + start * w.bytes_per_element,
            n * w.bytes_per_element
        );
    }
    return out;
}

# ── base64 / hex string decoding (node semantics: lenient base64 that accepts
#    both alphabets, skips non-alphabet chars and stops at '='; hex stops at
#    the first invalid pair) ────────────────────────────────────────────────

def _bn_b64_val(c: int) -> int {
    if c >= 65 and c <= 90 {
        return c - 65;
    }
    if c >= 97 and c <= 122 {
        return c - 97 + 26;
    }
    if c >= 48 and c <= 57 {
        return c - 48 + 52;
    }
    if c == 43 or c == 45 {
        return 62;
    }  # '+' / '-'
    if c == 47 or c == 95 {
        return 63;
    }  # '/' / '_'
    return -1;
}

def _bn_hex_val(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 102 {
        return c - 97 + 10;
    }
    if c >= 65 and c <= 70 {
        return c - 65 + 10;
    }
    return -1;
}

"""Decoded byte count of a base64 string (both alphabets; stops at '=')."""
def _bn_b64_byte_length(s: str) -> int {
    n: int = len(s);
    valid: int = 0;
    i: int = 0;
    while i < n {
        c: int = ord(s[i]);
        if c == 61 {
            break;
        }
        if _bn_b64_val(c) >= 0 {
            valid = valid + 1;
        }
        i = i + 1;
    }
    return (valid * 3) // 4;
}

"""Decode base64 `s` into dst[off .. off+cap); returns bytes written."""
def _bn_b64_write(s: str, dst: int, off: int, cap: int) -> int {
    n: int = len(s);
    acc: int = 0;
    bits: int = 0;
    w: int = 0;
    i: int = 0;
    while i < n and w < cap {
        c: int = ord(s[i]);
        i = i + 1;
        if c == 61 {
            break;
        }
        v: int = _bn_b64_val(c);
        if v < 0 {
            continue;
        }
        acc = ((acc << 6) | v) & 16777215;
        bits = bits + 6;
        if bits >= 8 {
            bits = bits - 8;
            write_byte(dst, off + w, (acc >> bits) & 255);
            w = w + 1;
        }
    }
    return w;
}

"""Decoded byte count of a hex string (valid leading pairs only)."""
def _bn_hex_byte_length(s: str) -> int {
    n: int = len(s);
    i: int = 0;
    cnt: int = 0;
    while i + 1 < n {
        if _bn_hex_val(ord(s[i])) < 0 or _bn_hex_val(ord(s[i + 1])) < 0 {
            break;
        }
        cnt = cnt + 1;
        i = i + 2;
    }
    return cnt;
}

def _bn_hex_write(s: str, dst: int, off: int, cap: int) -> int {
    n: int = len(s);
    i: int = 0;
    w: int = 0;
    while i + 1 < n and w < cap {
        hi: int = _bn_hex_val(ord(s[i]));
        lo: int = _bn_hex_val(ord(s[i + 1]));
        if hi < 0 or lo < 0 {
            break;
        }
        write_byte(dst, off + w, (hi << 4) | lo);
        w = w + 1;
        i = i + 2;
    }
    return w;
}

"""__buf.stringByteLength(str, encoding) → decoded byte count for base64 /
base64url / hex (undefined for other encodings or non-strings)."""
def:pub buf_string_byte_length(
    realm: Realm, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if len(args) < 2 or not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    enc: int = _bn_encoding(args[1]);
    st: str = str_from_id(jsv_to_table_id(args[0]));
    if enc == _ENC_BASE64 or enc == _ENC_BASE64URL {
        return js_int(_bn_b64_byte_length(st));
    }
    if enc == _ENC_HEX {
        return js_int(_bn_hex_byte_length(st));
    }
    return js_undefined();
}
