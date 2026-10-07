"""ArrayBuffer native bridge — low-level byte alloc/read/write for JS binary types.

Exposes six operations via globalThis.__buf:
    __buf.alloc(byteLength)                    → int (pointer, zero-filled)
    __buf.free(ptr)                            → undefined
    __buf.getByte(ptr, offset)                 → int (0..255)
    __buf.setByte(ptr, offset, value)          → undefined
    __buf.copy(dstPtr, dstOff, srcPtr, srcOff, len) → undefined
    __buf.fill(ptr, offset, len, byte)         → undefined
    __buf.decodeUtf8(ptr, start, end)          → string | undefined (ASCII only)
    __buf.decodeLatin1(ptr, start, end)        → string | undefined

Multi-byte reads (Uint16, Uint32, Float64, etc.) are composed in JS from
single-byte getByte/setByte calls.  This keeps the native bridge minimal.
The one exception is bulk byte→string decode: rollup's binary-AST convertString
makes it the hottest primitive of a vite build, and a per-byte JS loop is
~10000x slower with heavy per-call allocation.

Bun reference: bun/src/bun.js/bindings/JSArrayBuffer.zig (backing store mgmt)
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_number,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_from_string_id,
    MATH_INF,
    MATH_NEG_INF
}
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_byte,
    write_byte,
    str_from_raw
}

import from engine.src.runtime.jsstring { str_heap }
import from engine.src.runtime.binary_state {
    binary_register_buffer,
    binary_register_typed_array,
    binary_register_data_view,
    binary_kind_of,
    binary_data_view_get_int,
    binary_data_view_set_int
}
import from engine.src.runtime.error { make_range_error, vm_throw_native }
import from engine.src.ffi.libc { memcpy, memset, free }

# Fail-fast under CI ~0.5 GiB host cap — match JS `_AB_ALLOC_LIMIT` (64 MiB).
glob _BUF_BYTE_LIMIT: int = 0x04000000;

"""A negative pointer can never be valid: it is the signature of a real
address (heap above the 2 GiB line) that was boxed through an int32 tag and
sign-extended back.  Throw a diagnosable RangeError — with the producer's JS
stack — instead of segfaulting on the wild write."""
def _buf_check_ptr(ptr: int, v: JSValue, who: str) -> bool {
    if ptr >= 0 {
        return True;
    }
    tag: str = "double";
    if jsv_is_int32(v) {
        tag = "int32";
    }
    vm_throw_native(
        make_range_error(
            "__buf."
                + who
                + ": negative data pointer ("
                + tag
                + " boxed, "
                + str(ptr)
                + ")"
        )
    );
    return False;
}


"""Allocate a zero-filled byte buffer.  args[0] = byteLength (int).
Returns the raw pointer as a JS float64 (preserves all 64 bits of the address)."""
def:pub buf_alloc(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    n: JSValue = args[0];
    byte_len: int = 0;
    if jsv_is_int32(n) {
        byte_len = jsv_to_int32(n);
    } elif jsv_is_double(n) {
        byte_len = int(jsv_to_double(n));
    }
    if byte_len <= 0 {
        return js_int(0);
    }
    if byte_len > _BUF_BYTE_LIMIT {
        vm_throw_native(make_range_error("ArrayBuffer allocation too large"));
        return js_undefined();
    }
    ptr: int = io_alloc(byte_len);
    return js_number(float(ptr));
}

"""Free a previously allocated buffer.  args[0] = ptr (int)."""
def:pub buf_free(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    p: JSValue = args[0];
    ptr: int = 0;
    if jsv_is_int32(p) {
        ptr = jsv_to_int32(p);
    } elif jsv_is_double(p) {
        ptr = int(jsv_to_double(p));
    }
    io_free(ptr);
    return js_undefined();
}

"""Read one unsigned byte.  args[0] = ptr, args[1] = offset.
Returns int 0..255."""
def:pub buf_get_byte(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    ptr: int = 0;
    off: int = 0;
    p: JSValue = args[0];
    o: JSValue = args[1];
    if jsv_is_int32(p) {
        ptr = jsv_to_int32(p);
    } elif jsv_is_double(p) {
        ptr = int(jsv_to_double(p));
    }
    if jsv_is_int32(o) {
        off = jsv_to_int32(o);
    } elif jsv_is_double(o) {
        off = int(jsv_to_double(o));
    }
    if ptr == 0 {
        return js_int(0);
    }
    if not _buf_check_ptr(ptr, p, "getByte") {
        return js_int(0);
    }
    return js_int(read_byte(ptr, off));
}

"""Write one byte.  args[0] = ptr, args[1] = offset, args[2] = value (0..255)."""
def:pub buf_set_byte(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    ptr: int = 0;
    off: int = 0;
    val: int = 0;
    p: JSValue = args[0];
    o: JSValue = args[1];
    v: JSValue = args[2];
    if jsv_is_int32(p) {
        ptr = jsv_to_int32(p);
    } elif jsv_is_double(p) {
        ptr = int(jsv_to_double(p));
    }
    if jsv_is_int32(o) {
        off = jsv_to_int32(o);
    } elif jsv_is_double(o) {
        off = int(jsv_to_double(o));
    }
    if jsv_is_int32(v) {
        val = jsv_to_int32(v);
    } elif jsv_is_double(v) {
        val = int(jsv_to_double(v));
    }
    if ptr != 0 {
        if not _buf_check_ptr(ptr, p, "setByte") {
            return js_undefined();
        }
        write_byte(ptr, off, val & 255);
    }
    return js_undefined();
}

"""Copy bytes.  args = [dstPtr, dstOff, srcPtr, srcOff, len]."""
def:pub buf_copy(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_undefined();
    }
    dst: int = 0;
    dst_off: int = 0;
    src: int = 0;
    src_off: int = 0;
    n: int = 0;
    a0: JSValue = args[0];
    a1: JSValue = args[1];
    a2: JSValue = args[2];
    a3: JSValue = args[3];
    a4: JSValue = args[4];
    if jsv_is_int32(a0) {
        dst = jsv_to_int32(a0);
    } elif jsv_is_double(a0) {
        dst = int(jsv_to_double(a0));
    }
    if jsv_is_int32(a1) {
        dst_off = jsv_to_int32(a1);
    } elif jsv_is_double(a1) {
        dst_off = int(jsv_to_double(a1));
    }
    if jsv_is_int32(a2) {
        src = jsv_to_int32(a2);
    } elif jsv_is_double(a2) {
        src = int(jsv_to_double(a2));
    }
    if jsv_is_int32(a3) {
        src_off = jsv_to_int32(a3);
    } elif jsv_is_double(a3) {
        src_off = int(jsv_to_double(a3));
    }
    if jsv_is_int32(a4) {
        n = jsv_to_int32(a4);
    } elif jsv_is_double(a4) {
        n_f: float = jsv_to_double(a4);
        # Non-finite / negative → no-op (never memcpy with garbage length).
        if not (n_f == n_f) or n_f == MATH_INF or n_f == MATH_NEG_INF or n_f < 0.0 {
            return js_undefined();
        }
        n = int(n_f);
    }
    if n < 0 {
        return js_undefined();
    }
    if n > _BUF_BYTE_LIMIT {
        vm_throw_native(make_range_error("TypedArray copy length too large"));
        return js_undefined();
    }
    if dst != 0 and src != 0 and n > 0 {
        if not _buf_check_ptr(dst, a0, "copy.dst") {
            return js_undefined();
        }
        if not _buf_check_ptr(src, a2, "copy.src") {
            return js_undefined();
        }
        memcpy(dst + dst_off, src + src_off, n);
    }
    return js_undefined();
}

"""Fill bytes with a value.  args = [ptr, offset, len, byte]."""
def:pub buf_fill(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    ptr: int = 0;
    off: int = 0;
    n: int = 0;
    val: int = 0;
    a0: JSValue = args[0];
    a1: JSValue = args[1];
    a2: JSValue = args[2];
    a3: JSValue = args[3];
    if jsv_is_int32(a0) {
        ptr = jsv_to_int32(a0);
    } elif jsv_is_double(a0) {
        ptr = int(jsv_to_double(a0));
    }
    if jsv_is_int32(a1) {
        off = jsv_to_int32(a1);
    } elif jsv_is_double(a1) {
        off = int(jsv_to_double(a1));
    }
    if jsv_is_int32(a2) {
        n = jsv_to_int32(a2);
    } elif jsv_is_double(a2) {
        n = int(jsv_to_double(a2));
    }
    if jsv_is_int32(a3) {
        val = jsv_to_int32(a3);
    } elif jsv_is_double(a3) {
        val = int(jsv_to_double(a3));
    }
    if n > _BUF_BYTE_LIMIT {
        vm_throw_native(make_range_error("TypedArray fill length too large"));
        return js_undefined();
    }
    if ptr != 0 and n > 0 {
        if not _buf_check_ptr(ptr, a0, "fill") {
            return js_undefined();
        }
        memset(ptr + off, i32(val & 255), n);
    }
    return js_undefined();
}

"""Coerce a JSValue argument (int32- or float64-tagged) to a native int."""
def _buf_arg_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

"""Bulk-decode bytes [start,end) at ptr as UTF-8 into a JS string.

ASCII fast path only: any byte >= 0x80 returns undefined and the JS caller
(buffer.js _decodeUtf8 / text_codec.js) falls back to its per-byte decoder, so
multibyte and invalid-sequence semantics live in exactly one place. A 0x00
byte becomes the engine-wide 4-char NUL sentinel (see utf8_encode_scalar).
args = [ptr, start, end]."""
def:pub buf_decode_utf8(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    a0: JSValue = args[0];
    ptr: int = _buf_arg_int(a0);
    st: int = _buf_arg_int(args[1]);
    en: int = _buf_arg_int(args[2]);
    if ptr == 0 {
        return js_undefined();
    }
    if not _buf_check_ptr(ptr, a0, "decodeUtf8") {
        return js_undefined();
    }
    if st < 0 or en < st or (en - st) > _BUF_BYTE_LIMIT {
        return js_undefined();
    }
    n: int = en - st;
    if n == 0 {
        return jsv_from_string_id(str_heap(""));
    }
    # Pass 1: ASCII check + count NULs (each expands to the 4-byte sentinel).
    nuls: int = 0;
    i: int = st;
    while i < en {
        b: int = read_byte(ptr, i);
        if b >= 128 {
            return js_undefined();
        }
        if b == 0 {
            nuls += 1;
        }
        i += 1;
    }
    # Pass 2: copy into a NUL-terminated buffer and reinterpret as str — the
    # same headerless-buffer idiom (and lifetime semantics) as str_substr.
    slen: int = n + nuls * 3;
    out: int = io_alloc(slen + 33);  # 32-byte header region + slen chars + NUL
    data: int = out + 32;
    j: int = 0;
    i = st;
    while i < en {
        b2: int = read_byte(ptr, i);
        if b2 == 0 {
            write_byte(data, j, 92);  # `\`
            write_byte(data, j + 1, 120);  # `x`
            write_byte(data, j + 2, 48);  # `0`
            write_byte(data, j + 3, 48);  # `0`
            j += 4;
        } else {
            write_byte(data, j, b2);
            j += 1;
        }
        i += 1;
    }
    write_byte(data, slen, 0);
    # The refcounted copy is built INLINE into the heap table: a named
    # `result: str` local would never be released (leaked one copy per call).
    res_v: JSValue = jsv_from_string_id(str_heap(str_from_raw(data)));
    io_free(out);
    return res_v;
}

"""Bulk-decode bytes [start,end) at ptr as Latin-1 into a JS string.

Every byte maps 1:1 to code unit U+0000..U+00FF, so no fallback is needed:
0x00 → the 4-char NUL sentinel, 0x01-0x7F verbatim, 0x80-0xFF → the 2-byte
UTF-8 encoding (identical to utf8_encode_scalar for cp < 0x800).
args = [ptr, start, end]."""
def:pub buf_decode_latin1(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    a0: JSValue = args[0];
    ptr: int = _buf_arg_int(a0);
    st: int = _buf_arg_int(args[1]);
    en: int = _buf_arg_int(args[2]);
    if ptr == 0 {
        return js_undefined();
    }
    if not _buf_check_ptr(ptr, a0, "decodeLatin1") {
        return js_undefined();
    }
    if st < 0 or en < st or (en - st) > _BUF_BYTE_LIMIT {
        return js_undefined();
    }
    n: int = en - st;
    if n == 0 {
        return jsv_from_string_id(str_heap(""));
    }
    slen: int = 0;
    i: int = st;
    while i < en {
        b: int = read_byte(ptr, i);
        if b == 0 {
            slen += 4;
        } elif b < 128 {
            slen += 1;
        } else {
            slen += 2;
        }
        i += 1;
    }
    out: int = io_alloc(slen + 33);
    data: int = out + 32;
    j: int = 0;
    i = st;
    while i < en {
        b2: int = read_byte(ptr, i);
        if b2 == 0 {
            write_byte(data, j, 92);
            write_byte(data, j + 1, 120);
            write_byte(data, j + 2, 48);
            write_byte(data, j + 3, 48);
            j += 4;
        } elif b2 < 128 {
            write_byte(data, j, b2);
            j += 1;
        } else {
            write_byte(data, j, 192 + (b2 >> 6));
            write_byte(data, j + 1, 128 + (b2 & 63));
            j += 2;
        }
        i += 1;
    }
    write_byte(data, slen, 0);
    # The refcounted copy is built INLINE into the heap table: a named
    # `result: str` local would never be released (leaked one copy per call).
    res_v: JSValue = jsv_from_string_id(str_heap(str_from_raw(data)));
    io_free(out);
    return res_v;
}

"""Install/update opaque ArrayBufferData + BackingStore internal slots."""
def:pub buf_register_buffer(args: list[JSValue]) -> JSValue {
    return binary_register_buffer(args);
}

"""Install opaque TypedArrayData internal slots."""
def:pub buf_register_typed_array(args: list[JSValue]) -> JSValue {
    return binary_register_typed_array(args);
}

"""Install opaque DataViewData internal slots."""
def:pub buf_register_data_view(args: list[JSValue]) -> JSValue {
    return binary_register_data_view(args);
}

"""Return the opaque binary brand kind without consulting JS properties."""
def:pub buf_binary_kind(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    return js_int(binary_kind_of(args[0]));
}

"""DataView GetViewValue (int). args: [view, relOffset, size, littleEndian, signed]."""
def:pub buf_dv_get_int(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_undefined();
    }
    off: int = 0;
    size: int = 0;
    if jsv_is_int32(args[1]) {
        off = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        off = int(jsv_to_double(args[1]));
    }
    if jsv_is_int32(args[2]) {
        size = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        size = int(jsv_to_double(args[2]));
    }
    le: bool = False;
    if jsv_is_bool(args[3]) {
        le = jsv_to_bool(args[3]);
    } elif jsv_is_int32(args[3]) {
        le = jsv_to_int32(args[3]) != 0;
    }
    signed: bool = False;
    if jsv_is_bool(args[4]) {
        signed = jsv_to_bool(args[4]);
    } elif jsv_is_int32(args[4]) {
        signed = jsv_to_int32(args[4]) != 0;
    }
    return binary_data_view_get_int(args[0], off, size, le, signed);
}

"""DataView SetViewValue (int). args: [view, relOffset, size, littleEndian, number]."""
def:pub buf_dv_set_int(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_int(1);
    }
    off: int = 0;
    size: int = 0;
    num: float = 0.0;
    if jsv_is_int32(args[1]) {
        off = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        off = int(jsv_to_double(args[1]));
    }
    if jsv_is_int32(args[2]) {
        size = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        size = int(jsv_to_double(args[2]));
    }
    le: bool = False;
    if jsv_is_bool(args[3]) {
        le = jsv_to_bool(args[3]);
    } elif jsv_is_int32(args[3]) {
        le = jsv_to_int32(args[3]) != 0;
    }
    if jsv_is_int32(args[4]) {
        num = float(jsv_to_int32(args[4]));
    } elif jsv_is_double(args[4]) {
        num = jsv_to_double(args[4]);
    }
    return js_int(binary_data_view_set_int(args[0], off, size, le, num));
}
