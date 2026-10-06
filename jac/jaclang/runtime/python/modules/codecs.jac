"""Codec registry and builtin codecs; derived from CPython 3.14.6 Modules/_codecsmodule.c.

See ../LICENSE.cpython. The registry and the codecs themselves belong to the
interpreter (Python/codecs.c, Objects/unicodeobject.c); these functions expose
them with the (result, consumed length) interface the codecs module expects.
An `errors` or `encoding` argument is C's `const char *`, NULL when omitted.
The Windows-only mbcs, oem and code_page codecs are not built on POSIX.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_buffer_new,
    jacpy_bytes_from_memory,
    NULL,
    Py_NewRef,
    PyBytes_AsString,
    PyBytes_DecodeEscape,
    _PyBytes_Resize,
    PyBytes_Size,
    PyCodec_Decode,
    PyCodec_Encode,
    _PyCodec_Lookup,
    PyCodec_LookupError,
    PyCodec_Register,
    PyCodec_RegisterError,
    PyCodec_Unregister,
    _PyCodec_UnregisterError,
    PyExc_OverflowError,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyObject,
    _PyUnicode_AsASCIIString,
    _PyUnicode_AsLatin1String,
    PyUnicode_AsRawUnicodeEscapeString,
    PyUnicode_AsUnicodeEscapeString,
    _PyUnicode_AsUTF8String,
    PyUnicode_BuildEncodingMap,
    PyUnicode_DecodeASCII,
    PyUnicode_DecodeCharmap,
    PyUnicode_DecodeLatin1,
    _PyUnicode_DecodeRawUnicodeEscapeStateful,
    _PyUnicode_DecodeUnicodeEscapeStateful,
    PyUnicode_DecodeUTF16Stateful,
    PyUnicode_DecodeUTF32Stateful,
    PyUnicode_DecodeUTF7Stateful,
    PyUnicode_DecodeUTF8Stateful,
    _PyUnicode_EncodeCharmap,
    _PyUnicode_EncodeUTF16,
    _PyUnicode_EncodeUTF32,
    _PyUnicode_EncodeUTF7,
    PyUnicode_GetDefaultEncoding,
    PyUnicode_GetLength
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.bindings.references { owned_tuple }

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     HEX_DIGITS: str = "0123456789abcdef";

"""codec_tuple(): (decoded, length), consuming decoded."""
def:priv codec_tuple(decoded: ptr[PyObject], length: i64) -> ptr[PyObject] {
    if not decoded {
        return NULL;
    }
    return owned_tuple([decoded, PyLong_FromSsize_t(length)]);
}

def:priv none_to_null(mapping: ptr[PyObject]) -> ptr[PyObject] {
    return NULL if mapping == borrowed_none() else mapping;
}

# --- Registry ---

def _codecs_register_impl(
    module: ptr[PyObject], search_function: ptr[PyObject]
) -> ptr[PyObject] {
    if PyCodec_Register(search_function) != 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

def _codecs_unregister_impl(
    module: ptr[PyObject], search_function: ptr[PyObject]
) -> ptr[PyObject] {
    if PyCodec_Unregister(search_function) < 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

def _codecs_lookup_impl(module: ptr[PyObject], encoding: str) -> ptr[PyObject] {
    return _PyCodec_Lookup(encoding);
}

def _codecs_encode_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    # Encode via the codec registry
    return PyCodec_Encode(obj_, encoding or PyUnicode_GetDefaultEncoding(), errors);
}

def _codecs_decode_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    # Decode via the codec registry
    return PyCodec_Decode(obj_, encoding or PyUnicode_GetDefaultEncoding(), errors);
}

# --- String codecs ---

def _codecs_escape_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8]
) -> ptr[PyObject] {
    decoded = PyBytes_DecodeEscape(data.address(), data.size(), errors, 0, ptr[u8]());
    return codec_tuple(decoded, data.size());
}

def _codecs_escape_encode_impl(
    module: ptr[PyObject], data: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    size = PyBytes_Size(data);
    if size > PY_SSIZE_T_MAX // 4 {
        object_error(PyExc_OverflowError, "string is too large to encode");
        return NULL;
    }
    newsize = 4 * size;
    v = jacpy_buffer_new(newsize);
    if not v {
        return NULL;
    }
    written: i64 = 0;
    if size > 0 {
        source = PyBytes_AsString(data).view(int(size));
        target = PyBytes_AsString(v).view(int(newsize));
        for i in range(int(size)) {
            c = source[i];
            if c == u8(39) or c == u8(92) {
                # ' and \
                target[written] = u8(92);
                target[written + 1] = c;
                written += 2;
            } elif c == u8(9) {
                target[written] = u8(92);
                target[written + 1] = u8(116);
                written += 2;
            } elif c == u8(10) {
                target[written] = u8(92);
                target[written + 1] = u8(110);
                written += 2;
            } elif c == u8(13) {
                target[written] = u8(92);
                target[written + 1] = u8(114);
                written += 2;
            } elif c < u8(32) or c >= u8(127) {
                target[written] = u8(92);
                target[written + 1] = u8(120);
                target[written + 2] = u8(ord(HEX_DIGITS[int(c) >> 4]));
                target[written + 3] = u8(ord(HEX_DIGITS[int(c) & 15]));
                written += 4;
            } else {
                target[written] = c;
                written += 1;
            }
        }
    }
    if _PyBytes_Resize(&mut v, written) < 0 {
        return NULL;
    }
    return codec_tuple(v, size);
}

# --- Decoders ---
# A decoder that is not final consumes only complete sequences and reports
# how much it read; a final one (consumed NULL) treats a truncated tail as an
# error.

def _codecs_utf_7_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = PyUnicode_DecodeUTF7Stateful(
            data.address(), data.size(), errors, None
        );
    } else {
        decoded = PyUnicode_DecodeUTF7Stateful(
            data.address(), data.size(), errors, &mut consumed
        );
    }
    return codec_tuple(decoded, consumed);
}

def _codecs_utf_8_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = PyUnicode_DecodeUTF8Stateful(
            data.address(), data.size(), errors, None
        );
    } else {
        decoded = PyUnicode_DecodeUTF8Stateful(
            data.address(), data.size(), errors, &mut consumed
        );
    }
    return codec_tuple(decoded, consumed);
}

"""UTF-16 with the byte order in effect at the start (0 reads a BOM); returns
the decoded text, the length consumed and the byte order at the end."""
def:priv decode_utf16(
    data: BufferArgument, errors: ptr[u8], byteorder: i32, final: bool
) -> tuple[ptr[PyObject], i64, i32] {
    order = byteorder;
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = PyUnicode_DecodeUTF16Stateful(
            data.address(), data.size(), errors, &mut order, None
        );
    } else {
        decoded = PyUnicode_DecodeUTF16Stateful(
            data.address(), data.size(), errors, &mut order, &mut consumed
        );
    }
    return (decoded, consumed, order);
}

def:priv decode_utf32(
    data: BufferArgument, errors: ptr[u8], byteorder: i32, final: bool
) -> tuple[ptr[PyObject], i64, i32] {
    order = byteorder;
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = PyUnicode_DecodeUTF32Stateful(
            data.address(), data.size(), errors, &mut order, None
        );
    } else {
        decoded = PyUnicode_DecodeUTF32Stateful(
            data.address(), data.size(), errors, &mut order, &mut consumed
        );
    }
    return (decoded, consumed, order);
}

def _codecs_utf_16_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf16(data, errors, i32(0), final);
    return codec_tuple(decoded, consumed);
}

def _codecs_utf_16_le_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf16(data, errors, i32(-1), final);
    return codec_tuple(decoded, consumed);
}

def _codecs_utf_16_be_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf16(data, errors, i32(1), final);
    return codec_tuple(decoded, consumed);
}

"""This non-standard version also provides access to the byteorder
parameter of the builtin UTF-16 codec: it returns (unicode, bytesread,
byteorder) with byteorder being the value in effect at the end of data."""
def _codecs_utf_16_ex_decode_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    errors: ptr[u8],
    byteorder: i32,
    final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf16(data, errors, byteorder, final);
    if not decoded {
        return NULL;
    }
    return owned_tuple(
        [decoded, PyLong_FromSsize_t(consumed), PyLong_FromLong(i64(order))]
    );
}

def _codecs_utf_32_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf32(data, errors, i32(0), final);
    return codec_tuple(decoded, consumed);
}

def _codecs_utf_32_le_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf32(data, errors, i32(-1), final);
    return codec_tuple(decoded, consumed);
}

def _codecs_utf_32_be_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf32(data, errors, i32(1), final);
    return codec_tuple(decoded, consumed);
}

"""The UTF-32 counterpart of utf_16_ex_decode."""
def _codecs_utf_32_ex_decode_impl(
    module: ptr[PyObject],
    data: BufferArgument,
    errors: ptr[u8],
    byteorder: i32,
    final: bool
) -> ptr[PyObject] {
    (decoded, consumed, order) = decode_utf32(data, errors, byteorder, final);
    if not decoded {
        return NULL;
    }
    return owned_tuple(
        [decoded, PyLong_FromSsize_t(consumed), PyLong_FromLong(i64(order))]
    );
}

def _codecs_unicode_escape_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = _PyUnicode_DecodeUnicodeEscapeStateful(
            data.address(), data.size(), errors, None
        );
    } else {
        decoded = _PyUnicode_DecodeUnicodeEscapeStateful(
            data.address(), data.size(), errors, &mut consumed
        );
    }
    return codec_tuple(decoded, consumed);
}

def _codecs_raw_unicode_escape_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], final: bool
) -> ptr[PyObject] {
    consumed = data.size();
    decoded: ptr[PyObject] = NULL;
    if final {
        decoded = _PyUnicode_DecodeRawUnicodeEscapeStateful(
            data.address(), data.size(), errors, None
        );
    } else {
        decoded = _PyUnicode_DecodeRawUnicodeEscapeStateful(
            data.address(), data.size(), errors, &mut consumed
        );
    }
    return codec_tuple(decoded, consumed);
}

def _codecs_latin_1_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8]
) -> ptr[PyObject] {
    decoded = PyUnicode_DecodeLatin1(data.address(), data.size(), errors);
    return codec_tuple(decoded, data.size());
}

def _codecs_ascii_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8]
) -> ptr[PyObject] {
    decoded = PyUnicode_DecodeASCII(data.address(), data.size(), errors);
    return codec_tuple(decoded, data.size());
}

def _codecs_charmap_decode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8], mapping: ptr[PyObject]
) -> ptr[PyObject] {
    decoded = PyUnicode_DecodeCharmap(
        data.address(), data.size(), none_to_null(mapping), errors
    );
    return codec_tuple(decoded, data.size());
}

# --- Encoders ---

def _codecs_readbuffer_encode_impl(
    module: ptr[PyObject], data: BufferArgument, errors: ptr[u8]
) -> ptr[PyObject] {
    result = jacpy_bytes_from_memory(data.address(), data.size());
    return codec_tuple(result, data.size());
}

def _codecs_utf_7_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF7(str_, i32(0), i32(0), errors), length);
}

def _codecs_utf_8_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_AsUTF8String(str_, errors), length);
}

"""byteorder 0 means the native byte order, preceded by a BOM."""
def _codecs_utf_16_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8], byteorder: i32
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF16(str_, errors, byteorder), length);
}

def _codecs_utf_16_le_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF16(str_, errors, i32(-1)), length);
}

def _codecs_utf_16_be_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF16(str_, errors, i32(1)), length);
}

def _codecs_utf_32_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8], byteorder: i32
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF32(str_, errors, byteorder), length);
}

def _codecs_utf_32_le_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF32(str_, errors, i32(-1)), length);
}

def _codecs_utf_32_be_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_EncodeUTF32(str_, errors, i32(1)), length);
}

def _codecs_unicode_escape_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(PyUnicode_AsUnicodeEscapeString(str_), length);
}

def _codecs_raw_unicode_escape_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(PyUnicode_AsRawUnicodeEscapeString(str_), length);
}

def _codecs_latin_1_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_AsLatin1String(str_, errors), length);
}

def _codecs_ascii_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(_PyUnicode_AsASCIIString(str_, errors), length);
}

def _codecs_charmap_encode_impl(
    module: ptr[PyObject], str_: ptr[PyObject], errors: ptr[u8], mapping: ptr[PyObject]
) -> ptr[PyObject] {
    length = PyUnicode_GetLength(str_);
    return codec_tuple(
        _PyUnicode_EncodeCharmap(str_, none_to_null(mapping), errors), length
    );
}

def _codecs_charmap_build_impl(
    module: ptr[PyObject], map: ptr[PyObject]
) -> ptr[PyObject] {
    return PyUnicode_BuildEncodingMap(map);
}

# --- Error handler registry ---

def _codecs_register_error_impl(
    module: ptr[PyObject], errors: str, handler: ptr[PyObject]
) -> ptr[PyObject] {
    if PyCodec_RegisterError(errors, handler) != 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

"""Only custom error handlers can be un-registered: 1 when one was, 0 when
none is registered under errors, -1 with an exception for a built-in name."""
def _codecs__unregister_error_impl(module: ptr[PyObject], errors: str) -> i32 {
    return _PyCodec_UnregisterError(errors);
}

def _codecs_lookup_error_impl(module: ptr[PyObject], name: str) -> ptr[PyObject] {
    return PyCodec_LookupError(name);
}
