"""The _multibytecodec module: Modules/cjkcodecs/multibytecodec.c in native Jac.

MultibyteCodec objects wrap a codec a _codecs_<locale> module defines;
the incremental encoder and decoder and the stream reader and writer keep the
codec's 8 bytes of state, their error handling and their pending input in
native state. The encode and decode loops, the error-callback protocol and
getstate()/setstate() follow the C. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_is_bytes,
    jacpy_is_long,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_data,
    jacpy_unicode_kind,
    jacpy_unicode_size,
    NULL,
    Py_GetConstant,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    PyCodec_LookupError,
    PyCodec_StrictErrors,
    PyErr_Clear,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetObject,
    PyExc_AttributeError,
    PyExc_IndexError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_UnicodeDecodeError,
    PyExc_UnicodeEncodeError,
    PyExc_UnicodeError,
    PyExc_ValueError,
    PyLong_AsSsize_t,
    PyLong_FromSsize_t,
    PyLong_Type,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_CallMethodObjArgs,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_Str,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Length,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Pack,
    PyTuple_SetItem,
    PyTuple_Size,
    PyType_GetModule,
    PyUnicode_Append,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FromOrdinal,
    PyUnicode_Splitlines,
    PyUnicode_Substring,
    PyUnicodeDecodeError_Create,
    PyUnicodeDecodeError_SetEnd,
    PyUnicodeDecodeError_SetReason,
    PyUnicodeDecodeError_SetStart,
    PyUnicodeEncodeError_SetEnd,
    PyUnicodeEncodeError_SetReason,
    PyUnicodeEncodeError_SetStart,
    PyUnicodeWriter,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteChar,
    PyUnicodeWriter_WriteStr,
    _PyBytes_Resize,
    _PyLong_AsByteArray,
    _PyLong_FromByteArray
}
import from jaclang.runtime.python.object_model.capsule {
    PyCapsule_GetPointer,
    PyCapsule_IsValid
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_text,
    object_error,
    text_value,
    type_name
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_owner
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.modules.cjkcodecs {
    CodecCapsule,
    DecodeWriter,
    MBENC_FLUSH,
    MBENC_MAX,
    MBERR_EXCEPTION,
    MBERR_INTERNAL,
    MBERR_TOOFEW,
    MBERR_TOOSMALL,
    MultibyteCodec,
    MultibyteCodec_State
}

import from c {
    # MultibyteEncodeBuffer. The codec advances `inpos` and `outbuf` through
    # their addresses, which are the record's first two words; `replpos` is
    # encerror()'s position in its one-character replacement.
    obj MultibyteEncodeBuffer {
        has inpos: i64,
            outbuf: ptr[u8],
            inobj: ptr[PyObject],
            inlen: i64,
            outbuf_end: ptr[u8],
            excobj: ptr[PyObject],
            outobj: ptr[PyObject],
            replpos: i64;
    }
    # MultibyteDecodeBuffer. The codec advances `inbuf` through its address,
    # the record's first word, and writes to `writer`, the next two.
    obj MultibyteDecodeBuffer {
        has inbuf: ptr[u8],
            writer: DecodeWriter,
            inbuf_top: ptr[u8],
            inbuf_end: ptr[u8],
            excobj: ptr[PyObject],
            min_length: i64;
    }
    # A stateful codec object's C memory: the codec state and, for a
    # decoder, its pending bytes (MAXDECPENDING of them).
    obj StatefulRecord {
        has state: MultibyteCodec_State,
            pending: u64,
            pendingsize: i64;
    }
}

glob MultibyteCodec_token = ClassToken(),
     MultibyteIncrementalEncoder_token = ClassToken(),
     MultibyteIncrementalDecoder_token = ClassToken(),
     MultibyteStreamReader_token = ClassToken(),
     MultibyteStreamWriter_token = ClassToken();

# The module state slots.
glob STATE_CODEC_TYPE: int = 0,
     STATE_ENCODER_TYPE: int = 1,
     STATE_DECODER_TYPE: int = 2,
     STATE_READER_TYPE: int = 3,
     STATE_WRITER_TYPE: int = 4,
     STATE_STR_WRITE: int = 5,
     STATE_COUNT: int = 6;

glob:priv ERROR_STRICT: int = 1,
     ERROR_IGNORE: int = 2,
     ERROR_REPLACE: int = 3,
     MAXENCPENDING: int = 2,
     MAXDECPENDING: int = 8,
     # reset after an encoding session
     MBENC_RESET: i32 = 2,
     PY_SSIZE_T_MAX: int = 0x7FFFFFFFFFFFFFFF,
     Py_CONSTANT_EMPTY_STR: u32 = 7;

def:priv error_code(errors: ptr[PyObject]) -> int {
    return int(errors);
}

# ERROR_ISCUSTOM: an error handler name rather than a built-in policy.
def:priv error_is_custom(errors: ptr[PyObject]) -> bool {
    code = error_code(errors);
    return code < ERROR_STRICT or code > ERROR_REPLACE;
}

# ERROR_DECREF.
def:priv error_release(errors: ptr[PyObject]) {
    if errors and error_is_custom(errors) {
        jacpy_release(errors);
    }
}

def:priv make_tuple(object: ptr[PyObject], length: i64) -> ptr[PyObject] {
    if not object {
        return NULL;
    }
    v = PyTuple_New(2);
    if not v {
        jacpy_release(object);
        return NULL;
    }
    PyTuple_SetItem(v, 0, object);
    w = PyLong_FromSsize_t(length);
    if not w {
        jacpy_release(v);
        return NULL;
    }
    PyTuple_SetItem(v, 1, w);
    return v;
}

# internal_error_callback: a built-in policy, or the handler's name as a
# new str; NULL with the exception set on failure.
def:priv internal_error_callback(errors: ptr[u8]) -> ptr[PyObject] {
    if errors.is_null() {
        return ptr[PyObject](ERROR_STRICT);
    }
    name = c_string_text(errors);
    if not name {
        return NULL;
    }
    text = text_value(name);
    if text == "strict" {
        jacpy_release(name);
        return ptr[PyObject](ERROR_STRICT);
    }
    if text == "ignore" {
        jacpy_release(name);
        return ptr[PyObject](ERROR_IGNORE);
    }
    if text == "replace" {
        jacpy_release(name);
        return ptr[PyObject](ERROR_REPLACE);
    }
    return name;
}

def:priv call_error_callback(
    errors: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    cb = PyCodec_LookupError(text_value(errors));
    if not cb {
        return NULL;
    }
    r = PyObject_CallOneArg(cb, exc);
    jacpy_release(cb);
    return r;
}

# PyBytes_AS_STRING.
def:priv bytes_data(value: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](jacpy_bytes_address(value));
}

def:priv copy_memory(target: ptr[u8], source: ptr[u8], size: int) {
    for i in range(size) {
        (target + i).view(1)[0] = (source + i).view(1)[0];
    }
}

def:priv encode_inpos(buf: ptr[MultibyteEncodeBuffer]) -> ptr[i64] {
    return ptr[i64](ptr(buf));
}

def:priv encode_outbuf(buf: ptr[MultibyteEncodeBuffer]) -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](ptr(buf)) + 1;
}

def:priv encode_replpos(buf: ptr[MultibyteEncodeBuffer]) -> ptr[i64] {
    return ptr[i64](ptr(buf)) + 7;
}

def:priv decode_inbuf(buf: ptr[MultibyteDecodeBuffer]) -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](ptr(buf));
}

def:priv decode_writer(buf: ptr[MultibyteDecodeBuffer]) -> ptr[DecodeWriter] {
    return ptr[DecodeWriter](ptr(buf) + 8);
}

def:priv expand_encodebuffer(buf: ptr[MultibyteEncodeBuffer], esize: int) -> int {
    b = buf.view(1)[0];
    orgpos = int(b.outbuf - bytes_data(b.outobj));
    orgsize = int(jacpy_bytes_length(b.outobj));
    incsize = ((orgsize >> 1) | 1) if esize < (orgsize >> 1) else esize;
    if orgsize > PY_SSIZE_T_MAX - incsize {
        PyErr_NoMemory();
        return -1;
    }
    outobj = b.outobj;
    resized = _PyBytes_Resize(&mut outobj, i64(orgsize + incsize));
    buf.view(1)[0].outobj = outobj;
    if resized == -1 {
        return -1;
    }
    start = bytes_data(outobj);
    buf.view(1)[0].outbuf = start + orgpos;
    buf.view(1)[0].outbuf_end = start + int(jacpy_bytes_length(outobj));
    return 0;
}

# REQUIRE_ENCODEBUFFER: False when growing the output failed.
def:priv require_encodebuffer(buf: ptr[MultibyteEncodeBuffer], s: int) -> bool {
    b = buf.view(1)[0];
    if s < 0 or s > int(b.outbuf_end - b.outbuf) {
        return expand_encodebuffer(buf, s) != -1;
    }
    return True;
}

# The (str, int) or (bytes, int) tuple an encoding error handler returns.
def:priv valid_encode_reply(retobj: ptr[PyObject]) -> bool {
    if jacpy_is_tuple(retobj) == 0 or PyTuple_Size(retobj) != 2 {
        return False;
    }
    tobj = PyTuple_GetItem(retobj, 0);
    if jacpy_is_unicode(tobj) == 0 and jacpy_is_bytes(tobj) == 0 {
        return False;
    }
    return jacpy_is_long(PyTuple_GetItem(retobj, 1)) != 0;
}

# MultibyteCodec object

def:priv multibytecodec_encerror(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    buf: ptr[MultibyteEncodeBuffer],
    errors: ptr[PyObject],
    e: i64
) -> int {
    reason = "";
    esize: i64 = 0;
    if e > 0 {
        reason = "illegal multibyte sequence";
        esize = e;
    } elif e == MBERR_TOOSMALL {
        return 0 if require_encodebuffer(buf, -1) else -1;
    } elif e == MBERR_TOOFEW {
        reason = "incomplete multibyte sequence";
        esize = buf.view(1)[0].inpos;
    } elif e == MBERR_INTERNAL {
        object_error(PyExc_RuntimeError, "internal codec error");
        return -1;
    } else {
        object_error(PyExc_RuntimeError, "unknown runtime error");
        return -1;
    }
    code = error_code(errors);
    if code == ERROR_REPLACE {
        replchar = PyUnicode_FromOrdinal(63);
        if not replchar {
            return -1;
        }
        kind = i32(jacpy_unicode_kind(replchar));
        data = jacpy_unicode_data(replchar);
        encode_replpos(buf).view(1)[0] = 0;
        r: i64 = 0;
        while True {
            outleft = i64(buf.view(1)[0].outbuf_end - buf.view(1)[0].outbuf);
            r = codec.view(1)[0].encode(
                state,
                codec,
                kind,
                data,
                encode_replpos(buf),
                1,
                encode_outbuf(buf),
                outleft,
                i32(0)
            );
            if r == MBERR_TOOSMALL {
                if not require_encodebuffer(buf, -1) {
                    jacpy_release(replchar);
                    return -1;
                }
                continue;
            }
            break;
        }
        jacpy_release(replchar);
        if r != 0 {
            if not require_encodebuffer(buf, 1) {
                return -1;
            }
            buf.view(1)[0].outbuf.view(1)[0] = u8(63);
            buf.view(1)[0].outbuf = buf.view(1)[0].outbuf + 1;
        }
    }
    if code == ERROR_IGNORE or code == ERROR_REPLACE {
        buf.view(1)[0].inpos = buf.view(1)[0].inpos + esize;
        return 0;
    }
    start = buf.view(1)[0].inpos;
    end = start + esize;
    # use cached exception object if available
    if not buf.view(1)[0].excobj {
        excobj = PyObject_CallFunction(
            PyExc_UnicodeEncodeError,
            "sOnns",
            codec.view(1)[0].encoding,
            buf.view(1)[0].inobj,
            start,
            end,
            reason
        );
        if not excobj {
            return -1;
        }
        buf.view(1)[0].excobj = excobj;
    } elif PyUnicodeEncodeError_SetStart(buf.view(1)[0].excobj, start) != 0
        or PyUnicodeEncodeError_SetEnd(buf.view(1)[0].excobj, end) != 0
        or PyUnicodeEncodeError_SetReason(buf.view(1)[0].excobj, reason) != 0 {
        return -1;
    }
    if code == ERROR_STRICT {
        PyCodec_StrictErrors(buf.view(1)[0].excobj);
        return -1;
    }
    retobj = call_error_callback(errors, buf.view(1)[0].excobj);
    if not retobj {
        return -1;
    }
    if not valid_encode_reply(retobj) {
        object_error(
            PyExc_TypeError, "encoding error handler must return (str, int) tuple"
        );
        jacpy_release(retobj);
        return -1;
    }
    tobj = PyTuple_GetItem(retobj, 0);
    retstr = NULL;
    if jacpy_is_unicode(tobj) != 0 {
        retstr = multibytecodec_encode(
            codec, state, tobj, ptr[i64](), ptr[PyObject](ERROR_STRICT), MBENC_FLUSH
        );
        if not retstr {
            jacpy_release(retobj);
            return -1;
        }
    } else {
        retstr = Py_NewRef(tobj);
    }
    retstrsize = int(jacpy_bytes_length(retstr));
    if retstrsize > 0 {
        if not require_encodebuffer(buf, retstrsize) {
            jacpy_release(retobj);
            jacpy_release(retstr);
            return -1;
        }
        copy_memory(buf.view(1)[0].outbuf, bytes_data(retstr), retstrsize);
        buf.view(1)[0].outbuf = buf.view(1)[0].outbuf + retstrsize;
    }
    newpos = PyLong_AsSsize_t(PyTuple_GetItem(retobj, 1));
    if newpos < 0 and not PyErr_Occurred() {
        newpos += buf.view(1)[0].inlen;
    }
    if newpos < 0 or newpos > buf.view(1)[0].inlen {
        PyErr_Clear();
        PyErr_Format(
            PyExc_IndexError, "position %zd from error handler out of bounds", newpos
        );
        jacpy_release(retobj);
        jacpy_release(retstr);
        return -1;
    }
    buf.view(1)[0].inpos = newpos;
    jacpy_release(retobj);
    jacpy_release(retstr);
    return 0;
}

# The decoder's input size (buf->inbuf_end - buf->inbuf_top).
def:priv decode_input_size(buf: ptr[MultibyteDecodeBuffer]) -> i64 {
    return i64(buf.view(1)[0].inbuf_end - buf.view(1)[0].inbuf_top);
}

# _PyUnicodeWriter_WriteChar / _PyUnicodeWriter_WriteStr on the buffer's
# writer, created on first use with the input size as its capacity.
def:priv decode_writer_ready(buf: ptr[MultibyteDecodeBuffer]) -> bool {
    if buf.view(1)[0].writer.writer.is_null() {
        writer = PyUnicodeWriter_Create(buf.view(1)[0].min_length);
        if writer.is_null() {
            return False;
        }
        decode_writer(buf).view(1)[0].writer = writer;
    }
    return True;
}

def:priv decode_write_str(
    buf: ptr[MultibyteDecodeBuffer], text: ptr[PyObject]
) -> bool {
    if not decode_writer_ready(buf) {
        return False;
    }
    if PyUnicodeWriter_WriteStr(buf.view(1)[0].writer.writer, text) < 0 {
        return False;
    }
    decode_writer(buf).view(1)[0].written = (
        buf.view(1)[0].writer.written + jacpy_unicode_size(text)
    );
    return True;
}

def:priv multibytecodec_decerror(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    buf: ptr[MultibyteDecodeBuffer],
    errors: ptr[PyObject],
    e: i64
) -> int {
    reason = "";
    esize: i64 = 0;
    if e > 0 {
        reason = "illegal multibyte sequence";
        esize = e;
    } elif e == MBERR_TOOSMALL {
        # retry it
        return 0;
    } elif e == MBERR_TOOFEW {
        reason = "incomplete multibyte sequence";
        esize = i64(buf.view(1)[0].inbuf_end - buf.view(1)[0].inbuf);
    } elif e == MBERR_INTERNAL {
        object_error(PyExc_RuntimeError, "internal codec error");
        return -1;
    } elif e == MBERR_EXCEPTION {
        return -1;
    } else {
        object_error(PyExc_RuntimeError, "unknown runtime error");
        return -1;
    }
    code = error_code(errors);
    if code == ERROR_REPLACE {
        if not decode_writer_ready(buf)
            or PyUnicodeWriter_WriteChar(buf.view(1)[0].writer.writer, u32(0xFFFD))
                < 0 {
            return -1;
        }
        decode_writer(buf).view(1)[0].written = buf.view(1)[0].writer.written + 1;
    }
    if code == ERROR_IGNORE or code == ERROR_REPLACE {
        buf.view(1)[0].inbuf = buf.view(1)[0].inbuf + esize;
        return 0;
    }
    start = i64(buf.view(1)[0].inbuf - buf.view(1)[0].inbuf_top);
    end = start + esize;
    # use cached exception object if available
    if not buf.view(1)[0].excobj {
        excobj = PyUnicodeDecodeError_Create(
            ptr(codec.view(1)[0].encoding),
            ptr(buf.view(1)[0].inbuf_top),
            decode_input_size(buf),
            start,
            end,
            reason
        );
        if not excobj {
            return -1;
        }
        buf.view(1)[0].excobj = excobj;
    } elif PyUnicodeDecodeError_SetStart(buf.view(1)[0].excobj, start) != 0
        or PyUnicodeDecodeError_SetEnd(buf.view(1)[0].excobj, end) != 0
        or PyUnicodeDecodeError_SetReason(buf.view(1)[0].excobj, reason) != 0 {
        return -1;
    }
    if code == ERROR_STRICT {
        PyCodec_StrictErrors(buf.view(1)[0].excobj);
        return -1;
    }
    retobj = call_error_callback(errors, buf.view(1)[0].excobj);
    if not retobj {
        return -1;
    }
    if jacpy_is_tuple(retobj) == 0
        or PyTuple_Size(retobj) != 2
        or jacpy_is_unicode(PyTuple_GetItem(retobj, 0)) == 0
        or jacpy_is_long(PyTuple_GetItem(retobj, 1)) == 0 {
        object_error(
            PyExc_TypeError, "decoding error handler must return (str, int) tuple"
        );
        jacpy_release(retobj);
        return -1;
    }
    if not decode_write_str(buf, PyTuple_GetItem(retobj, 0)) {
        jacpy_release(retobj);
        return -1;
    }
    newpos = PyLong_AsSsize_t(PyTuple_GetItem(retobj, 1));
    if newpos < 0 and not PyErr_Occurred() {
        newpos += decode_input_size(buf);
    }
    if newpos < 0 or buf.view(1)[0].inbuf_top + newpos > buf.view(1)[0].inbuf_end {
        PyErr_Clear();
        PyErr_Format(
            PyExc_IndexError, "position %zd from error handler out of bounds", newpos
        );
        jacpy_release(retobj);
        return -1;
    }
    buf.view(1)[0].inbuf = buf.view(1)[0].inbuf_top + newpos;
    jacpy_release(retobj);
    return 0;
}

def:priv release_encodebuffer(buf: ptr[MultibyteEncodeBuffer]) {
    jacpy_release(buf.view(1)[0].excobj);
    PyMem_Free(ptr(buf));
}

def multibytecodec_encode(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    text: ptr[PyObject],
    inpos_t: ptr[i64],
    errors: ptr[PyObject],
    flags: i32
) -> ptr[PyObject] {
    datalen = jacpy_unicode_size(text);
    if datalen == 0 and (flags & MBENC_RESET) == 0 {
        return jacpy_bytes_from_memory(ptr(), 0);
    }
    buf = ptr[MultibyteEncodeBuffer](PyMem_Calloc(u64(1), u64(64)));
    if buf.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    buf.view(1)[0].inobj = text;
    buf.view(1)[0].inpos = 0;
    buf.view(1)[0].inlen = datalen;
    kind = i32(jacpy_unicode_kind(text));
    data = jacpy_unicode_data(text);
    if datalen > (PY_SSIZE_T_MAX - 16) / 2 {
        PyErr_NoMemory();
        release_encodebuffer(buf);
        return NULL;
    }
    outobj = jacpy_bytes_from_memory(ptr(), datalen * 2 + 16);
    if not outobj {
        release_encodebuffer(buf);
        return NULL;
    }
    buf.view(1)[0].outobj = outobj;
    buf.view(1)[0].outbuf = bytes_data(outobj);
    buf.view(1)[0].outbuf_end = bytes_data(outobj) + int(jacpy_bytes_length(outobj));
    failed = False;
    r: i64 = 0;
    while buf.view(1)[0].inpos < buf.view(1)[0].inlen {
        # we don't reuse inleft and outleft here.
        # error callbacks can relocate the cursor anywhere on buffer
        outleft = i64(buf.view(1)[0].outbuf_end - buf.view(1)[0].outbuf);
        r = codec.view(1)[0].encode(
            state,
            codec,
            kind,
            data,
            encode_inpos(buf),
            buf.view(1)[0].inlen,
            encode_outbuf(buf),
            outleft,
            flags
        );
        if r == 0 or (r == MBERR_TOOFEW and (flags & MBENC_FLUSH) == 0) {
            break;
        } elif multibytecodec_encerror(codec, state, buf, errors, r) != 0 {
            failed = True;
            break;
        } elif r == MBERR_TOOFEW {
            break;
        }
    }
    if not failed and (flags & MBENC_RESET) != 0 {
        while True {
            outleft = i64(buf.view(1)[0].outbuf_end - buf.view(1)[0].outbuf);
            r = codec.view(1)[0].encreset(state, codec, encode_outbuf(buf), outleft);
            if r == 0 {
                break;
            } elif multibytecodec_encerror(codec, state, buf, errors, r) != 0 {
                failed = True;
                break;
            }
        }
    }
    result = buf.view(1)[0].outobj;
    if not failed {
        finalsize = i64(buf.view(1)[0].outbuf - bytes_data(result));
        if finalsize != jacpy_bytes_length(result) {
            if _PyBytes_Resize(&mut result, finalsize) == -1 {
                failed = True;
            }
        }
    }
    if failed {
        jacpy_release(result);
        release_encodebuffer(buf);
        return NULL;
    }
    if not inpos_t.is_null() {
        inpos_t.view(1)[0] = buf.view(1)[0].inpos;
    }
    release_encodebuffer(buf);
    return result;
}

# The state of a MultibyteCodec object: the codec and the module defining it.
obj CodecState(NativeState) {
    has codec: ptr[MultibyteCodec],
        cjk_module: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.cjk_module, visitor, context);
    }

    def clear {
        module = self.cjk_module;
        self.cjk_module = NULL;
        jacpy_release(module);
    }
}

def:priv codec_of(instance: ptr[PyObject]) -> ptr[MultibyteCodec] {
    if jacpy_binding_native_present(instance, MultibyteCodec_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, MultibyteCodec_token.handle);
        if isinstance(state, CodecState) {
            return state.codec;
        }
    }
    return ptr[MultibyteCodec]();
}

def _multibytecodec_MultibyteCodec_encode_impl(
    self: ptr[PyObject], input: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    codec = codec_of(self);
    ucvt = NULL;
    if jacpy_is_unicode(input) == 0 {
        ucvt = PyObject_Str(input);
        if not ucvt {
            return NULL;
        }
        if jacpy_is_unicode(ucvt) == 0 {
            object_error(PyExc_TypeError, "couldn't convert the object to unicode.");
            jacpy_release(ucvt);
            return NULL;
        }
        input = ucvt;
    }
    datalen = jacpy_unicode_size(input);
    errorcb = internal_error_callback(errors);
    if not errorcb {
        jacpy_release(ucvt);
        return NULL;
    }
    state = ptr[MultibyteCodec_State](PyMem_Calloc(u64(1), u64(8)));
    if state.is_null() {
        PyErr_NoMemory();
        error_release(errorcb);
        jacpy_release(ucvt);
        return NULL;
    }
    r = NULL;
    if codec.view(1)[0].encinit(state, codec) == 0 {
        r = multibytecodec_encode(
            codec, state, input, ptr[i64](), errorcb, MBENC_FLUSH | MBENC_RESET
        );
    }
    PyMem_Free(ptr(state));
    error_release(errorcb);
    jacpy_release(ucvt);
    if not r {
        return NULL;
    }
    return make_tuple(r, datalen);
}

def:priv new_decodebuffer -> ptr[MultibyteDecodeBuffer] {
    buf = ptr[MultibyteDecodeBuffer](PyMem_Calloc(u64(1), u64(56)));
    if buf.is_null() {
        PyErr_NoMemory();
    }
    return buf;
}

# _PyUnicodeWriter_Dealloc and the buffer's cached exception.
def:priv release_decodebuffer(buf: ptr[MultibyteDecodeBuffer]) {
    writer = buf.view(1)[0].writer.writer;
    if not writer.is_null() {
        PyUnicodeWriter_Discard(writer);
    }
    jacpy_release(buf.view(1)[0].excobj);
    PyMem_Free(ptr(buf));
}

# _PyUnicodeWriter_Finish: the decoded str; the buffer is released.
def:priv finish_decodebuffer(buf: ptr[MultibyteDecodeBuffer]) -> ptr[PyObject] {
    if not decode_writer_ready(buf) {
        release_decodebuffer(buf);
        return NULL;
    }
    writer = buf.view(1)[0].writer.writer;
    decode_writer(buf).view(1)[0].writer = ptr[PyUnicodeWriter]();
    res = PyUnicodeWriter_Finish(writer);
    release_decodebuffer(buf);
    return res;
}

# The codec's decode entry over the buffer: the writer exists first.
def:priv run_decode(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    buf: ptr[MultibyteDecodeBuffer]
) -> i64 {
    if not decode_writer_ready(buf) {
        return MBERR_EXCEPTION;
    }
    inleft = i64(buf.view(1)[0].inbuf_end - buf.view(1)[0].inbuf);
    return codec.view(1)[0].decode(
        state, codec, decode_inbuf(buf), inleft, decode_writer(buf)
    );
}

def _multibytecodec_MultibyteCodec_decode_impl(
    self: ptr[PyObject], input: BufferArgument, errors: ptr[u8]
) -> ptr[PyObject] {
    codec = codec_of(self);
    data = ptr[u8](input.address());
    datalen = input.size();
    errorcb = internal_error_callback(errors);
    if not errorcb {
        return NULL;
    }
    if datalen == 0 {
        error_release(errorcb);
        return make_tuple(Py_GetConstant(Py_CONSTANT_EMPTY_STR), 0);
    }
    buf = new_decodebuffer();
    if buf.is_null() {
        error_release(errorcb);
        return NULL;
    }
    state = ptr[MultibyteCodec_State](PyMem_Calloc(u64(1), u64(8)));
    if state.is_null() {
        PyErr_NoMemory();
        release_decodebuffer(buf);
        error_release(errorcb);
        return NULL;
    }
    buf.view(1)[0].min_length = datalen;
    buf.view(1)[0].inbuf = data;
    buf.view(1)[0].inbuf_top = data;
    buf.view(1)[0].inbuf_end = data + datalen;
    failed = codec.view(1)[0].decinit(state, codec) != 0;
    while not failed and buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end {
        r = run_decode(codec, state, buf);
        if r == 0 {
            break;
        }
        failed = multibytecodec_decerror(codec, state, buf, errorcb, r) != 0;
    }
    PyMem_Free(ptr(state));
    error_release(errorcb);
    if failed {
        release_decodebuffer(buf);
        return NULL;
    }
    res = finish_decodebuffer(buf);
    if not res {
        return NULL;
    }
    return make_tuple(res, datalen);
}

# Utility functions for stateful codec mechanism

# The state of the incremental encoder and decoder and the stream reader and
# writer (_MultibyteStatefulCodec_HEAD and its encoder, decoder and stream
# parts).
obj StatefulState(NativeState) {
    has codec: ptr[MultibyteCodec],
        record: ptr[StatefulRecord],
        errors: ptr[PyObject] = NULL,
        pending: ptr[PyObject] = NULL,
        stream: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        if self.errors and error_is_custom(self.errors) {
            result = visit_reference(self.errors, visitor, context);
            if result != 0 {
                return result;
            }
        }
        return visit_reference(self.stream, visitor, context);
    }

    def clear {}
    def drop {
        error_release(self.errors);
        jacpy_release(self.pending);
        jacpy_release(self.stream);
        if not self.record.is_null() {
            PyMem_Free(ptr(self.record));
        }
    }

    def state -> ptr[MultibyteCodec_State] {
        return ptr[MultibyteCodec_State](self.record);
    }

    # The decoder's pending bytes.
    def pending_bytes -> ptr[u8] {
        return ptr[u8](self.record) + 8;
    }

    def pendingsize -> int {
        return int(self.record.view(1)[0].pendingsize);
    }

    def set_pendingsize(size: int) {
        self.record.view(1)[0].pendingsize = i64(size);
    }
}

def:priv stateful_of(
    instance: ptr[PyObject], token: ClassToken
) -> (StatefulState | None) {
    if jacpy_binding_native_present(instance, token.handle) != 0 {
        state = jacpy_binding_native_get(instance, token.handle);
        if isinstance(state, StatefulState) {
            return state;
        }
    }
    object_error(PyExc_RuntimeError, "multibyte codec state is unavailable");
    return None;
}

# The four stateful codec types, by the context their "errors" property
# carries.
def:priv stateful_token(kind: u64) -> ClassToken {
    if kind == u64(0) {
        return MultibyteIncrementalEncoder_token;
    }
    if kind == u64(1) {
        return MultibyteIncrementalDecoder_token;
    }
    if kind == u64(2) {
        return MultibyteStreamReader_token;
    }
    return MultibyteStreamWriter_token;
}

# The "errors" attribute of every stateful codec object.
def codecctx_errors_get(instance: ptr[PyObject], kind: u64) -> ptr[PyObject] {
    ctx = stateful_of(instance, stateful_token(kind));
    if ctx is None {
        return NULL;
    }
    code = error_code(ctx.errors);
    if code == ERROR_STRICT {
        return c_string_text(ptr[u8]("strict"));
    }
    if code == ERROR_IGNORE {
        return c_string_text(ptr[u8]("ignore"));
    }
    if code == ERROR_REPLACE {
        return c_string_text(ptr[u8]("replace"));
    }
    return Py_NewRef(ctx.errors);
}

def codecctx_errors_set(
    instance: ptr[PyObject], value: ptr[PyObject], kind: u64
) -> i32 {
    ctx = stateful_of(instance, stateful_token(kind));
    if ctx is None {
        return i32(-1);
    }
    if not value {
        object_error(PyExc_AttributeError, "cannot delete attribute");
        return i32(-1);
    }
    if jacpy_is_unicode(value) == 0 {
        object_error(PyExc_TypeError, "errors must be a string");
        return i32(-1);
    }
    size: i64 = 0;
    str = PyUnicode_AsUTF8AndSize(value, &mut size);
    if str.is_null() {
        return i32(-1);
    }
    cb = internal_error_callback(str);
    if not cb {
        return i32(-1);
    }
    error_release(ctx.errors);
    ctx.errors = cb;
    return i32(0);
}

def:priv encoder_encode_stateful(
    ctx: StatefulState, unistr: ptr[PyObject], final: bool
) -> ptr[PyObject] {
    ucvt = NULL;
    if jacpy_is_unicode(unistr) == 0 {
        ucvt = PyObject_Str(unistr);
        if not ucvt {
            return NULL;
        }
        if jacpy_is_unicode(ucvt) == 0 {
            object_error(PyExc_TypeError, "couldn't convert the object to str.");
            jacpy_release(ucvt);
            return NULL;
        }
        unistr = ucvt;
    }
    origpending = NULL;
    inbuf = NULL;
    if ctx.pending {
        origpending = Py_NewRef(ctx.pending);
        inbuf_tmp = Py_NewRef(ctx.pending);
        PyUnicode_Append(&mut inbuf_tmp, unistr);
        if not inbuf_tmp {
            jacpy_release(ucvt);
            jacpy_release(origpending);
            return NULL;
        }
        pending = ctx.pending;
        ctx.pending = NULL;
        jacpy_release(pending);
        inbuf = inbuf_tmp;
    } else {
        inbuf = Py_NewRef(unistr);
    }
    inpos = ptr[i64](PyMem_Calloc(u64(1), u64(8)));
    if inpos.is_null() {
        PyErr_NoMemory();
        jacpy_release(ctx.pending);
        ctx.pending = origpending;
        jacpy_release(inbuf);
        jacpy_release(ucvt);
        return NULL;
    }
    datalen = jacpy_unicode_size(inbuf);
    r = multibytecodec_encode(
        ctx.codec,
        ctx.state(),
        inbuf,
        inpos,
        ctx.errors,
        (MBENC_FLUSH | MBENC_RESET) if final else i32(0)
    );
    consumed = inpos.view(1)[0];
    PyMem_Free(ptr(inpos));
    if not r {
        # recover the original pending buffer
        jacpy_release(ctx.pending);
        ctx.pending = origpending;
        jacpy_release(inbuf);
        jacpy_release(ucvt);
        return NULL;
    }
    jacpy_release(origpending);
    if consumed < datalen {
        if datalen - consumed > MAXENCPENDING {
            # normal codecs can't reach here
            excobj = PyObject_CallFunction(
                PyExc_UnicodeEncodeError,
                "sOnns",
                ctx.codec.view(1)[0].encoding,
                inbuf,
                consumed,
                datalen,
                "pending buffer overflow"
            );
            if excobj {
                PyErr_SetObject(PyExc_UnicodeEncodeError, excobj);
                jacpy_release(excobj);
            }
            jacpy_release(r);
            jacpy_release(inbuf);
            jacpy_release(ucvt);
            return NULL;
        }
        ctx.pending = PyUnicode_Substring(inbuf, consumed, datalen);
        if not ctx.pending {
            # normal codecs can't reach here
            jacpy_release(r);
            jacpy_release(inbuf);
            jacpy_release(ucvt);
            return NULL;
        }
    }
    jacpy_release(inbuf);
    jacpy_release(ucvt);
    return r;
}

def:priv decoder_append_pending(
    ctx: StatefulState, buf: ptr[MultibyteDecodeBuffer]
) -> int {
    npendings = int(buf.view(1)[0].inbuf_end - buf.view(1)[0].inbuf);
    if npendings + ctx.pendingsize() > MAXDECPENDING
        or npendings > PY_SSIZE_T_MAX - ctx.pendingsize() {
        bufsize = decode_input_size(buf);
        excobj = PyUnicodeDecodeError_Create(
            ptr(ctx.codec.view(1)[0].encoding),
            ptr(buf.view(1)[0].inbuf_top),
            bufsize,
            0,
            bufsize,
            "pending buffer overflow"
        );
        if not excobj {
            return -1;
        }
        PyErr_SetObject(PyExc_UnicodeDecodeError, excobj);
        jacpy_release(excobj);
        return -1;
    }
    copy_memory(
        ctx.pending_bytes() + ctx.pendingsize(), buf.view(1)[0].inbuf, npendings
    );
    ctx.set_pendingsize(ctx.pendingsize() + npendings);
    return 0;
}

def:priv decoder_prepare_buffer(
    buf: ptr[MultibyteDecodeBuffer], data: ptr[u8], size: int
) -> int {
    buf.view(1)[0].inbuf = data;
    buf.view(1)[0].inbuf_top = data;
    buf.view(1)[0].inbuf_end = data + size;
    buf.view(1)[0].min_length = buf.view(1)[0].min_length + size;
    return 0;
}

def:priv decoder_feed_buffer(
    ctx: StatefulState, buf: ptr[MultibyteDecodeBuffer]
) -> int {
    while buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end {
        r = run_decode(ctx.codec, ctx.state(), buf);
        if r == 0 or r == MBERR_TOOFEW {
            break;
        } elif multibytecodec_decerror(ctx.codec, ctx.state(), buf, ctx.errors, r)
            != 0 {
            return -1;
        }
    }
    return 0;
}

def _multibytecodec_MultibyteIncrementalEncoder_encode_impl(
    self: ptr[PyObject], input: ptr[PyObject], final: bool
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalEncoder_token);
    if ctx is None {
        return NULL;
    }
    return encoder_encode_stateful(ctx, input, final);
}

# The bytes a stateful encoder's state is made of: 1 byte for the pending
# buffer's size, up to MAXENCPENDING*4 bytes for its UTF-8, and the codec
# state.
glob:priv ENCODER_STATE_BYTES: int = 17;

def _multibytecodec_MultibyteIncrementalEncoder_getstate_impl(
    self: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalEncoder_token);
    if ctx is None {
        return NULL;
    }
    statebytes = ptr[u8](PyMem_Calloc(u64(1), u64(ENCODER_STATE_BYTES)));
    if statebytes.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    statesize = 0;
    if ctx.pending {
        pendingsize: i64 = 0;
        pendingbuffer = PyUnicode_AsUTF8AndSize(ctx.pending, &mut pendingsize);
        if pendingbuffer.is_null() {
            PyMem_Free(ptr(statebytes));
            return NULL;
        }
        if pendingsize > MAXENCPENDING * 4 {
            excobj = PyObject_CallFunction(
                PyExc_UnicodeEncodeError,
                "sOnns",
                ctx.codec.view(1)[0].encoding,
                ctx.pending,
                i64(0),
                jacpy_unicode_size(ctx.pending),
                "pending buffer too large"
            );
            if excobj {
                PyErr_SetObject(PyExc_UnicodeEncodeError, excobj);
                jacpy_release(excobj);
            }
            PyMem_Free(ptr(statebytes));
            return NULL;
        }
        statebytes.view(1)[0] = u8(pendingsize);
        copy_memory(statebytes + 1, pendingbuffer, int(pendingsize));
        statesize = 1 + int(pendingsize);
    } else {
        statebytes.view(1)[0] = u8(0);
        statesize = 1;
    }
    copy_memory(statebytes + statesize, ptr[u8](ctx.state()), 8);
    statesize += 8;
    result = _PyLong_FromByteArray(statebytes, u64(statesize), i32(1), i32(0));
    PyMem_Free(ptr(statebytes));
    return result;
}

def _multibytecodec_MultibyteIncrementalEncoder_setstate_impl(
    self: ptr[PyObject], statelong: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalEncoder_token);
    if ctx is None {
        return NULL;
    }
    statebytes = ptr[u8](PyMem_Calloc(u64(1), u64(ENCODER_STATE_BYTES)));
    if statebytes.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    if _PyLong_AsByteArray(
        statelong, statebytes, u64(ENCODER_STATE_BYTES), i32(1), i32(0), i32(1)
    )
        < 0 {
        PyMem_Free(ptr(statebytes));
        return NULL;
    }
    size = int(statebytes.view(1)[0]);
    if size > MAXENCPENDING * 4 {
        object_error(PyExc_UnicodeError, "pending buffer too large");
        PyMem_Free(ptr(statebytes));
        return NULL;
    }
    pending = PyUnicode_DecodeUTF8Stateful(
        ptr(statebytes + 1), i64(size), ptr[u8]("strict"), None
    );
    if not pending {
        PyMem_Free(ptr(statebytes));
        return NULL;
    }
    previous = ctx.pending;
    ctx.pending = pending;
    jacpy_release(previous);
    copy_memory(ptr[u8](ctx.state()), statebytes + 1 + size, 8);
    PyMem_Free(ptr(statebytes));
    return Py_NewRef(Py_None);
}

def _multibytecodec_MultibyteIncrementalEncoder_reset_impl(
    self: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalEncoder_token);
    if ctx is None {
        return NULL;
    }
    # Longest output: 4 bytes (b'\x0F\x1F(B') with ISO 2022
    cursor = ptr[ptr[u8]](PyMem_Calloc(u64(1), u64(16)));
    if cursor.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    cursor.view(1)[0] = ptr[u8](cursor + 1);
    r = ctx.codec.view(1)[0].encreset(ctx.state(), ctx.codec, cursor, 4);
    PyMem_Free(ptr(cursor));
    if r != 0 {
        return NULL;
    }
    pending = ctx.pending;
    ctx.pending = NULL;
    jacpy_release(pending);
    return Py_NewRef(Py_None);
}

# The codec object a stateful type's `codec` attribute names, borrowed from
# the reference the caller releases; NULL with the exception set.
def:priv type_codec(type: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
    codec = PyObject_GetAttrString(type, "codec");
    if not codec {
        return NULL;
    }
    module = jacpy_binding_owner(type, definition);
    if not module
        or Py_TYPE(codec) != jacpy_binding_state_get(module, i64(STATE_CODEC_TYPE)) {
        if module {
            object_error(PyExc_TypeError, "codec is unexpected type");
        }
        jacpy_release(codec);
        return NULL;
    }
    return codec;
}

# The native state of a new stateful codec object of `type`; its codec
# state is initialized by `init`. NULL with the exception set.
def stateful_new(
    type: ptr[PyObject],
    token: ClassToken,
    module_definition: ptr,
    errors: ptr[u8],
    stream: ptr[PyObject],
    encoder: bool
) -> ptr[PyObject] {
    self = jacpy_binding_allocate(type);
    if not self {
        return NULL;
    }
    codec = type_codec(type, module_definition);
    if not codec {
        jacpy_release(self);
        return NULL;
    }
    record = ptr[StatefulRecord](PyMem_Calloc(u64(1), u64(24)));
    if record.is_null() {
        PyErr_NoMemory();
        jacpy_release(codec);
        jacpy_release(self);
        return NULL;
    }
    ctx = StatefulState(codec=codec_of(codec), record=record);
    jacpy_release(codec);
    if stream {
        ctx.stream = Py_NewRef(stream);
    }
    if jacpy_binding_native_set(self, token.handle, ctx) < 0 {
        jacpy_release(self);
        return NULL;
    }
    ctx.errors = internal_error_callback(errors);
    if not ctx.errors {
        jacpy_release(self);
        return NULL;
    }
    status = ctx.codec.view(1)[0].encinit(ctx.state(), ctx.codec)
        if encoder
        else ctx.codec.view(1)[0].decinit(ctx.state(), ctx.codec);
    if status != 0 {
        jacpy_release(self);
        return NULL;
    }
    return self;
}

# The arguments of a stateful codec type's constructor.
obj NewArguments {
    has stream: ptr[PyObject] = NULL,
        errors: ptr[u8] = ptr[u8]();
}

# PyArg_ParseTupleAndKeywords(args, kwds, "|s:<name>", {"errors"}) or, for a
# stream type, "O|s:<name>" over {"stream", "errors"}: the errors name is the
# argument's UTF-8. None with the exception set.
def parse_new_arguments(
    args: ptr[PyObject], kwds: ptr[PyObject], name: str, stream: bool
) -> (NewArguments | None) {
    format = ArgumentFormat(name=name);
    parsed = NewArguments();
    size: i64 = 0;
    try {
        if stream {
            values = format.parse_keywords(args, kwds, "O|s", ["stream", "errors"]);
            parsed.stream = values[0].object;
            if values[1].given {
                parsed.errors = PyUnicode_AsUTF8AndSize(values[1].object, &mut size);
            }
            return parsed;
        }
        values = format.parse_keywords(args, kwds, "|s", ["errors"]);
        if values[0].given {
            parsed.errors = PyUnicode_AsUTF8AndSize(values[0].object, &mut size);
        }
        return parsed;
    } except boundary_failure {
        return None;
    }
}

def _multibytecodec_MultibyteIncrementalDecoder_decode_impl(
    self: ptr[PyObject], input: BufferArgument, final: bool
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalDecoder_token);
    if ctx is None {
        return NULL;
    }
    data = ptr[u8](input.address());
    size = int(input.size());
    buf = new_decodebuffer();
    if buf.is_null() {
        return NULL;
    }
    origpending = ctx.pendingsize();
    wdata = data;
    wsize = size;
    if ctx.pendingsize() != 0 {
        if size > PY_SSIZE_T_MAX - ctx.pendingsize() {
            PyErr_NoMemory();
            release_decodebuffer(buf);
            return NULL;
        }
        wsize = size + ctx.pendingsize();
        wdata = ptr[u8](PyMem_Malloc(u64(wsize)));
        if wdata.is_null() {
            PyErr_NoMemory();
            release_decodebuffer(buf);
            return NULL;
        }
        copy_memory(wdata, ctx.pending_bytes(), ctx.pendingsize());
        copy_memory(wdata + ctx.pendingsize(), data, size);
        ctx.set_pendingsize(0);
    }
    decoder_prepare_buffer(buf, wdata, wsize);
    failed = decoder_feed_buffer(ctx, buf) != 0;
    if not failed
        and final
        and buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end
        and multibytecodec_decerror(
            ctx.codec, ctx.state(), buf, ctx.errors, MBERR_TOOFEW
        )
            != 0 {
        # recover the original pending buffer
        copy_memory(ctx.pending_bytes(), wdata, origpending);
        ctx.set_pendingsize(origpending);
        failed = True;
    }
    # pending sequence still exists
    if not failed
        and buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end
        and decoder_append_pending(ctx, buf) != 0 {
        failed = True;
    }
    if wdata != data {
        PyMem_Free(ptr(wdata));
    }
    if failed {
        release_decodebuffer(buf);
        return NULL;
    }
    return finish_decodebuffer(buf);
}

def _multibytecodec_MultibyteIncrementalDecoder_getstate_impl(
    self: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalDecoder_token);
    if ctx is None {
        return NULL;
    }
    buffer = jacpy_bytes_from_memory(ptr(ctx.pending_bytes()), i64(ctx.pendingsize()));
    if not buffer {
        return NULL;
    }
    statelong = _PyLong_FromByteArray(ptr[u8](ctx.state()), u64(8), i32(1), i32(0));
    if not statelong {
        jacpy_release(buffer);
        return NULL;
    }
    result = PyTuple_Pack(2, buffer, statelong);
    jacpy_release(buffer);
    jacpy_release(statelong);
    return result;
}

def _multibytecodec_MultibyteIncrementalDecoder_setstate_impl(
    self: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalDecoder_token);
    if ctx is None {
        return NULL;
    }
    # PyArg_ParseTuple(state, "SO!;setstate(): illegal state argument",
    # &buffer, &PyLong_Type, &statelong)
    format = ArgumentFormat(
        message="setstate(): illegal state argument", types=[addressof(PyLong_Type)]
    );
    buffer = NULL;
    statelong = NULL;
    try {
        values = format.parse(state, "SO!");
        buffer = values[0].object;
        statelong = values[1].object;
    } except boundary_failure {
        return NULL;
    }
    statebytes = ptr[u8](PyMem_Calloc(u64(1), u64(8)));
    if statebytes.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    if _PyLong_AsByteArray(statelong, statebytes, u64(8), i32(1), i32(0), i32(1)) < 0 {
        PyMem_Free(ptr(statebytes));
        return NULL;
    }
    buffersize = int(jacpy_bytes_length(buffer));
    if buffersize > MAXDECPENDING {
        excobj = PyUnicodeDecodeError_Create(
            ptr(ctx.codec.view(1)[0].encoding),
            jacpy_bytes_address(buffer),
            i64(buffersize),
            0,
            i64(buffersize),
            "pending buffer too large"
        );
        if excobj {
            PyErr_SetObject(PyExc_UnicodeDecodeError, excobj);
            jacpy_release(excobj);
        }
        PyMem_Free(ptr(statebytes));
        return NULL;
    }
    ctx.set_pendingsize(buffersize);
    copy_memory(ctx.pending_bytes(), bytes_data(buffer), buffersize);
    copy_memory(ptr[u8](ctx.state()), statebytes, 8);
    PyMem_Free(ptr(statebytes));
    return Py_NewRef(Py_None);
}

def:priv decoder_reset(ctx: StatefulState) -> ptr[PyObject] {
    if ctx.codec.view(1)[0].decreset(ctx.state(), ctx.codec) != 0 {
        return NULL;
    }
    ctx.set_pendingsize(0);
    return Py_NewRef(Py_None);
}

def _multibytecodec_MultibyteIncrementalDecoder_reset_impl(
    self: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteIncrementalDecoder_token);
    if ctx is None {
        return NULL;
    }
    return decoder_reset(ctx);
}

# int(sizehint) as the "i" format reads a Py_ssize_t passed for it: the low
# 32 bits.
def:priv as_c_int(value: int) -> i32 {
    return i32(((value + 0x80000000) & 0xFFFFFFFF) - 0x80000000);
}

def:priv mbstreamreader_iread(
    ctx: StatefulState, method: str, sizehint: int
) -> ptr[PyObject] {
    if sizehint == 0 {
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    buf = new_decodebuffer();
    if buf.is_null() {
        return NULL;
    }
    while True {
        cres = PyObject_CallMethod(ctx.stream, method, "")
            if sizehint < 0
            else PyObject_CallMethod(ctx.stream, method, "i", as_c_int(sizehint));
        if not cres {
            release_decodebuffer(buf);
            return NULL;
        }
        if jacpy_is_bytes(cres) == 0 {
            object_error(
                PyExc_TypeError,
                f"stream function returned a non-bytes object ({type_name(cres)[:100]})"
            );
            jacpy_release(cres);
            release_decodebuffer(buf);
            return NULL;
        }
        endoffile = jacpy_bytes_length(cres) == 0;
        if ctx.pendingsize() > 0 {
            if jacpy_bytes_length(cres) > PY_SSIZE_T_MAX - ctx.pendingsize() {
                PyErr_NoMemory();
                jacpy_release(cres);
                release_decodebuffer(buf);
                return NULL;
            }
            rsize = int(jacpy_bytes_length(cres)) + ctx.pendingsize();
            ctr = jacpy_bytes_from_memory(ptr(), i64(rsize));
            if not ctr {
                jacpy_release(cres);
                release_decodebuffer(buf);
                return NULL;
            }
            ctrdata = bytes_data(ctr);
            copy_memory(ctrdata, ctx.pending_bytes(), ctx.pendingsize());
            copy_memory(
                ctrdata + ctx.pendingsize(),
                bytes_data(cres),
                int(jacpy_bytes_length(cres))
            );
            jacpy_release(cres);
            cres = ctr;
            ctx.set_pendingsize(0);
        }
        rsize = int(jacpy_bytes_length(cres));
        decoder_prepare_buffer(buf, bytes_data(cres), rsize);
        failed = rsize > 0 and decoder_feed_buffer(ctx, buf) != 0;
        if not failed
            and (endoffile or sizehint < 0)
            and buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end
            and multibytecodec_decerror(
                ctx.codec, ctx.state(), buf, ctx.errors, MBERR_TOOFEW
            )
                != 0 {
            failed = True;
        }
        # pending sequence exists
        if not failed
            and buf.view(1)[0].inbuf < buf.view(1)[0].inbuf_end
            and decoder_append_pending(ctx, buf) != 0 {
            failed = True;
        }
        jacpy_release(cres);
        if failed {
            release_decodebuffer(buf);
            return NULL;
        }
        if sizehint < 0 or buf.view(1)[0].writer.written != 0 or rsize == 0 {
            break;
        }
        # read 1 more byte and retry
        sizehint = 1;
    }
    return finish_decodebuffer(buf);
}

# sizeobj as read()'s size: -1 for None; None with the exception set.
def:priv reader_size(sizeobj: ptr[PyObject]) -> (int | None) {
    if sizeobj == Py_None {
        return -1;
    }
    if jacpy_is_long(sizeobj) == 0 {
        object_error(PyExc_TypeError, "arg 1 must be an integer");
        return None;
    }
    size = int(PyLong_AsSsize_t(sizeobj));
    if size == -1 and PyErr_Occurred() {
        return None;
    }
    return size;
}

def _multibytecodec_MultibyteStreamReader_read_impl(
    self: ptr[PyObject], sizeobj: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamReader_token);
    if ctx is None {
        return NULL;
    }
    size = reader_size(sizeobj);
    if size is None {
        return NULL;
    }
    return mbstreamreader_iread(ctx, "read", size);
}

def _multibytecodec_MultibyteStreamReader_readline_impl(
    self: ptr[PyObject], sizeobj: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamReader_token);
    if ctx is None {
        return NULL;
    }
    size = reader_size(sizeobj);
    if size is None {
        return NULL;
    }
    return mbstreamreader_iread(ctx, "readline", size);
}

def _multibytecodec_MultibyteStreamReader_readlines_impl(
    self: ptr[PyObject], sizehintobj: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamReader_token);
    if ctx is None {
        return NULL;
    }
    sizehint = reader_size(sizehintobj);
    if sizehint is None {
        return NULL;
    }
    r = mbstreamreader_iread(ctx, "read", sizehint);
    if not r {
        return NULL;
    }
    sr = PyUnicode_Splitlines(r, 1);
    jacpy_release(r);
    return sr;
}

def _multibytecodec_MultibyteStreamReader_reset_impl(
    self: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamReader_token);
    if ctx is None {
        return NULL;
    }
    return decoder_reset(ctx);
}

def:priv mbstreamwriter_iwrite(
    ctx: StatefulState, unistr: ptr[PyObject], str_write: ptr[PyObject]
) -> int {
    str = encoder_encode_stateful(ctx, unistr, False);
    if not str {
        return -1;
    }
    wr = PyObject_CallMethodObjArgs(ctx.stream, str_write, str, NULL);
    jacpy_release(str);
    if not wr {
        return -1;
    }
    jacpy_release(wr);
    return 0;
}

# PyType_GetModuleState(cls)->str_write.
def:priv str_write_of(cls: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_state_get(PyType_GetModule(cls), i64(STATE_STR_WRITE));
}

def _multibytecodec_MultibyteStreamWriter_write_impl(
    self: ptr[PyObject], cls: ptr[PyObject], strobj: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamWriter_token);
    if ctx is None {
        return NULL;
    }
    if mbstreamwriter_iwrite(ctx, strobj, str_write_of(cls)) != 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _multibytecodec_MultibyteStreamWriter_writelines_impl(
    self: ptr[PyObject], cls: ptr[PyObject], lines: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamWriter_token);
    if ctx is None {
        return NULL;
    }
    if PySequence_Check(lines) == 0 {
        object_error(PyExc_TypeError, "arg must be a sequence object");
        return NULL;
    }
    str_write = str_write_of(cls);
    i = 0;
    # length can be changed even within this loop
    while i < int(PySequence_Length(lines)) {
        strobj = PySequence_GetItem(lines, i64(i));
        if not strobj {
            return NULL;
        }
        r = mbstreamwriter_iwrite(ctx, strobj, str_write);
        jacpy_release(strobj);
        if r == -1 {
            return NULL;
        }
        i += 1;
    }
    # PySequence_Length() can fail
    if PyErr_Occurred() {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _multibytecodec_MultibyteStreamWriter_reset_impl(
    self: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = stateful_of(self, MultibyteStreamWriter_token);
    if ctx is None {
        return NULL;
    }
    if not ctx.pending {
        return Py_NewRef(Py_None);
    }
    pwrt = multibytecodec_encode(
        ctx.codec,
        ctx.state(),
        ctx.pending,
        ptr[i64](),
        ctx.errors,
        MBENC_FLUSH | MBENC_RESET
    );
    # some pending buffer can be truncated when UnicodeEncodeError is
    # raised on 'strict' mode. but, 'reset' method is designed to
    # reset the pending buffer or states so failed string sequence
    # ought to be missed
    pending = ctx.pending;
    ctx.pending = NULL;
    jacpy_release(pending);
    if not pwrt {
        return NULL;
    }
    if jacpy_bytes_length(pwrt) > 0 {
        wr = PyObject_CallMethodObjArgs(ctx.stream, str_write_of(cls), pwrt, NULL);
        if not wr {
            jacpy_release(pwrt);
            return NULL;
        }
        jacpy_release(wr);
    }
    jacpy_release(pwrt);
    return Py_NewRef(Py_None);
}

def _multibytecodec___create_codec_impl(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    if PyCapsule_IsValid(arg, ptr[u8]("multibytecodec.codec")) == 0 {
        object_error(PyExc_ValueError, "argument type invalid");
        return NULL;
    }
    data = ptr[CodecCapsule](
        PyCapsule_GetPointer(arg, ptr[u8]("multibytecodec.codec"))
    );
    codec = data.view(1)[0].codec;
    if codec.view(1)[0].codecinit(codec) != 0 {
        return NULL;
    }
    self = jacpy_binding_allocate(
        jacpy_binding_state_get(module, i64(STATE_CODEC_TYPE))
    );
    if not self {
        return NULL;
    }
    state = CodecState(codec=codec, cjk_module=Py_NewRef(data.view(1)[0].cjk_module));
    if jacpy_binding_native_set(self, MultibyteCodec_token.handle, state) < 0 {
        jacpy_release(self);
        return NULL;
    }
    return self;
}
