import from c {
    glob PyExc_UnicodeTranslateError: ptr[PyObject]; def strlen(text: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def _Py_normalize_encoding(
        encoding: ptr[u8], lower: ptr[u8], lower_len: u64
    ) -> i32;  def _PyErr_FormatNote(format: str, *args: any);  def PyUnicodeEncodeError_GetEncoding(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def PyUnicodeDecodeError_GetEncoding(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def PyStatus_Ok -> PyStatus;  def PyStatus_Error(
        err_msg: ptr[u8]
    ) -> PyStatus;  def PyStatus_NoMemory -> PyStatus;  obj CodecNameBuffer {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0),
            w20: u64 = u64(0),
            w21: u64 = u64(0),
            w22: u64 = u64(0),
            w23: u64 = u64(0),
            w24: u64 = u64(0),
            w25: u64 = u64(0),
            w26: u64 = u64(0),
            w27: u64 = u64(0),
            w28: u64 = u64(0),
            w29: u64 = u64(0),
            w30: u64 = u64(0),
            w31: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut CodecNameBuffer) -> int;  glob Py_hexdigits:
             ptr[u8] = ptr[u8]("0123456789abcdef"); glob:priv codecs_builtin_error_handlers:
             list[ptr[u8]] = [
             ptr[u8]("strict"),
             ptr[u8]("ignore"),
             ptr[u8]("replace"),
             ptr[u8]("xmlcharrefreplace"),
             ptr[u8]("backslashreplace"),
             ptr[u8]("namereplace"),
             ptr[u8]("surrogatepass"),
             ptr[u8]("surrogateescape")
         ],
         codecs_builtin_error_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("strict_errors"),
                 ml_meth=ptr(strict_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'strict' error handling, which "
                     "raises a UnicodeError on coding errors."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ignore_errors"),
                 ml_meth=ptr(ignore_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'ignore' error handling, which "
                     "ignores malformed data and continues."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("replace_errors"),
                 ml_meth=ptr(replace_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'replace' error handling, which "
                     "replaces malformed data with a replacement marker."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("xmlcharrefreplace_errors"),
                 ml_meth=ptr(xmlcharrefreplace_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'xmlcharrefreplace' error handling, "
                     "which replaces an unencodable character with the "
                     "appropriate XML character reference."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("backslashreplace_errors"),
                 ml_meth=ptr(backslashreplace_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'backslashreplace' error handling, "
                     "which replaces malformed data with a backslashed "
                     "escape sequence."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("namereplace_errors"),
                 ml_meth=ptr(namereplace_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Implements the 'namereplace' error handling, "
                     "which replaces an unencodable character with a "
                     "\\N{...} escape sequence."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("surrogatepass"),
                 ml_meth=ptr(surrogatepass_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("surrogateescape"),
                 ml_meth=ptr(surrogateescape_errors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             )
         ];
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     BUILTIN_ERROR_HANDLER_COUNT: Final[i64] = 8,
     NAME_BUFFER_SIZE: Final[i32] = 256,
     Py_UNICODE_REPLACEMENT_CHARACTER: Final[u32] = u32(0xFFFD),
     ENC_UNKNOWN: Final[i32] = -1,
     ENC_UTF8: Final[i32] = 0,
     ENC_UTF16BE: Final[i32] = 1,
     ENC_UTF16LE: Final[i32] = 2,
     ENC_UTF32BE: Final[i32] = 3,
     ENC_UTF32LE: Final[i32] = 4;

def codecs_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]];

def codecs_initialized(interp: ptr[u8]) -> ptr[i32];

def search_path(interp: ptr[u8]) -> ptr[PyObject];

def search_cache(interp: ptr[u8]) -> ptr[PyObject];

def error_registry(interp: ptr[u8]) -> ptr[PyObject];

def hexdigit(v: u32) -> u8;

def normalizestring(string: ptr[u8]) -> ptr[PyObject];

def args_tuple(object_: ptr[PyObject], errors: ptr[u8]) -> ptr[PyObject];

def codec_getitem(encoding: ptr[u8], index: i64) -> ptr[PyObject];

def codec_makeincrementalcodec(
    codec_info: ptr[PyObject], errors: ptr[u8], attrname: ptr[u8]
) -> ptr[PyObject];

def codec_getincrementalcodec(
    encoding: ptr[u8], errors: ptr[u8], attrname: ptr[u8]
) -> ptr[PyObject];

def codec_getstreamcodec(
    encoding: ptr[u8], stream: ptr[PyObject], errors: ptr[u8], index: i64
) -> ptr[PyObject];

def _PyCodec_EncodeInternal(
    object_: ptr[PyObject], encoder: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject];

def _PyCodec_DecodeInternal(
    object_: ptr[PyObject], decoder: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject];

def codec_getitem_checked(
    encoding: ptr[u8], alternate_command: ptr[u8], index: i64
) -> ptr[PyObject];

def _PyCodec_TextEncoder(encoding: ptr[u8]) -> ptr[PyObject];

def _PyCodec_TextDecoder(encoding: ptr[u8]) -> ptr[PyObject];

import from c {
    def PyCodec_Register(search_function: ptr[PyObject]) -> i32 {
        interp = current_interp();
        if not search_function {
            PyErr_BadArgument();
            return i32(-1);
        }
        if PyCallable_Check(search_function) == 0 {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("argument must be callable"));
            return i32(-1);
        }
        return PyList_Append(search_path(interp), search_function);
    }  def PyCodec_Unregister(search_function: ptr[PyObject]) -> i32 {
        interp = current_interp();
        if codecs_initialized(interp).view(1)[0] != 1 {
            return i32(0);
        }

        codec_search_path = search_path(interp);
        i: i64 = 0;
        while i < object_size(codec_search_path) {
            item = PyList_GetItemRef(codec_search_path, i);
            ret: i32 = 1;
            if item == search_function {
                ret = PyList_SetSlice(codec_search_path, i, i + 1, NULL);
            }
            object_decref(item);
            if ret != 1 {
                PyDict_Clear(search_cache(interp));
                return ret;
            }
            i += 1;
        }
        return i32(0);
    }  def _PyCodec_Lookup(encoding: ptr[u8]) -> ptr[PyObject] {
        if not encoding {
            PyErr_BadArgument();
            return NULL;
        }

        interp = current_interp();

        v = normalizestring(encoding);
        if not v {
            return NULL;
        }

        v = intern_common(interp, v, False);

        result: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(search_cache(interp), v, &mut result) < 0 {
            object_decref(v);
            return NULL;
        }
        if result {
            object_decref(v);
            return result;
        }

        len_ = PyList_Size(search_path(interp));
        if len_ < 0 {
            object_decref(v);
            return NULL;
        }
        if len_ == 0 {
            PyErr_SetString(
                PyExc_LookupError,
                ptr[u8]("no codec search functions registered: can't find encoding")
            );
            object_decref(v);
            return NULL;
        }

        i: i64 = 0;
        while i < len_ {
            func = PyList_GetItemRef(search_path(interp), i);
            if not func {
                object_decref(v);
                return NULL;
            }
            result = PyObject_CallOneArg(func, v);
            object_decref(func);
            if not result {
                object_decref(v);
                return NULL;
            }
            if result == Py_None {
                object_decref(result);
                result = NULL;
                i += 1;
                continue;
            }
            if not tuple_check(result) or object_size(result) != 4 {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("codec search functions must return 4-tuples")
                );
                object_decref(result);
                object_decref(v);
                return NULL;
            }
            break;
        }
        if not result {
            PyErr_Format(PyExc_LookupError, ptr[u8]("unknown encoding: %s"), encoding);
            object_decref(v);
            return NULL;
        }

        v = intern_common(interp, v, True);

        if PyDict_SetItem(search_cache(interp), v, result) < 0 {
            object_decref(result);
            object_decref(v);
            return NULL;
        }
        object_decref(v);
        return result;
    }  def PyCodec_KnownEncoding(encoding: ptr[u8]) -> i32 {
        codecs = _PyCodec_Lookup(encoding);
        if not codecs {
            PyErr_Clear();
            return i32(0);
        }
        object_decref(codecs);
        return i32(1);
    }  def _PyCodecInfo_GetIncrementalDecoder(
        codec_info: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_makeincrementalcodec(
            codec_info, errors, ptr[u8]("incrementaldecoder")
        );
    }  def _PyCodecInfo_GetIncrementalEncoder(
        codec_info: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_makeincrementalcodec(
            codec_info, errors, ptr[u8]("incrementalencoder")
        );
    }  def PyCodec_Encoder(encoding: ptr[u8]) -> ptr[PyObject] {
        return codec_getitem(encoding, 0);
    }  def PyCodec_Decoder(encoding: ptr[u8]) -> ptr[PyObject] {
        return codec_getitem(encoding, 1);
    }  def PyCodec_IncrementalEncoder(
        encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_getincrementalcodec(
            encoding, errors, ptr[u8]("incrementalencoder")
        );
    }  def PyCodec_IncrementalDecoder(
        encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_getincrementalcodec(
            encoding, errors, ptr[u8]("incrementaldecoder")
        );
    }  def PyCodec_StreamReader(
        encoding: ptr[u8], stream: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_getstreamcodec(encoding, stream, errors, 2);
    }  def PyCodec_StreamWriter(
        encoding: ptr[u8], stream: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return codec_getstreamcodec(encoding, stream, errors, 3);
    }  def PyCodec_Encode(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        encoder = PyCodec_Encoder(encoding);
        if not encoder {
            return NULL;
        }
        return _PyCodec_EncodeInternal(object_, encoder, encoding, errors);
    }  def PyCodec_Decode(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        decoder = PyCodec_Decoder(encoding);
        if not decoder {
            return NULL;
        }
        return _PyCodec_DecodeInternal(object_, decoder, encoding, errors);
    }  def _PyCodec_LookupTextEncoding(
        encoding: ptr[u8], alternate_command: ptr[u8]
    ) -> ptr[PyObject] {
        codec = _PyCodec_Lookup(encoding);
        if not codec {
            return NULL;
        }

        if not tuple_check_exact(codec) {
            attr: ptr[PyObject] = NULL;
            if PyObject_GetOptionalAttr(
                codec, py_id(_Py_ID__is_text_encoding), &mut attr
            )
                < 0 {
                object_decref(codec);
                return NULL;
            }
            if attr {
                is_text_codec = PyObject_IsTrue(attr);
                object_decref(attr);
                if is_text_codec <= 0 {
                    object_decref(codec);
                    if is_text_codec == 0 {
                        if alternate_command {
                            PyErr_Format(
                                PyExc_LookupError,
                                ptr[u8]("'%.400s' is not a text encoding; use %s to handle arbitrary codecs"),
                                encoding,
                                alternate_command
                            );
                        } else {
                            PyErr_Format(
                                PyExc_LookupError,
                                ptr[u8]("'%.400s' is not a text encoding"),
                                encoding
                            );
                        }
                    }
                    return NULL;
                }
            }
        }

        return codec;
    }  def _PyCodec_EncodeText(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        encoder = _PyCodec_TextEncoder(encoding);
        if not encoder {
            return NULL;
        }
        return _PyCodec_EncodeInternal(object_, encoder, encoding, errors);
    }  def _PyCodec_DecodeText(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        decoder = _PyCodec_TextDecoder(encoding);
        if not decoder {
            return NULL;
        }
        return _PyCodec_DecodeInternal(object_, decoder, encoding, errors);
    }  def PyCodec_RegisterError(name: ptr[u8], error: ptr[PyObject]) -> i32 {
        interp = current_interp();
        if PyCallable_Check(error) == 0 {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("handler must be callable"));
            return i32(-1);
        }
        return PyDict_SetItemString(error_registry(interp), name, error);
    }  def _PyCodec_UnregisterError(name: ptr[u8]) -> i32 {
        i: i64 = 0;
        while i < BUILTIN_ERROR_HANDLER_COUNT {
            if strcmp(name, (addressof(codecs_builtin_error_handlers) + i).view(1)[0])
                == 0 {
                PyErr_Format(
                    PyExc_ValueError,
                    ptr[u8]("cannot un-register built-in error handler '%s'"),
                    name
                );
                return i32(-1);
            }
            i += 1;
        }
        interp = current_interp();
        popped: ptr[PyObject] = NULL;
        res = PyDict_PopString(error_registry(interp), name, &mut popped);
        object_xdecref(popped);
        return res;
    }  def PyCodec_LookupError(name: ptr[u8]) -> ptr[PyObject] {
        interp = current_interp();

        handler_name = name;
        if not handler_name {
            handler_name = ptr[u8]("strict");
        }
        handler: ptr[PyObject] = NULL;
        if PyDict_GetItemStringRef(error_registry(interp), handler_name, &mut handler)
            < 0 {
            return NULL;
        }
        if not handler {
            PyErr_Format(
                PyExc_LookupError, ptr[u8]("unknown error handler name '%.400s'"), handler_name
            );
            return NULL;
        }
        return handler;
    }
}

def wrong_exception_type(exc: ptr[PyObject]);

def is_unicode_encode_error(exc: ptr[PyObject]) -> bool;

def is_unicode_decode_error(exc: ptr[PyObject]) -> bool;

def is_unicode_translate_error(exc: ptr[PyObject]) -> bool;

def reraise_exception(exc: ptr[PyObject]);

def codec_handler_unicode_hex_width(ch: u32) -> i64;

def codec_handler_write_unicode_hex(p: ptr[u8], ch: u32) -> ptr[u8];

def n_decimal_digits_for_codepoint(ch: u32) -> i64;

def codec_handler_unicode_replacement_character(count: i64) -> ptr[PyObject];

import from c {
    def PyCodec_StrictErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if type_has_feature(object_type(exc), Py_TPFLAGS_BASE_EXC_SUBCLASS) {
            reraise_exception(exc);
        } else {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("codec must pass exception instance"));
        }
        return NULL;
    }
}

def _PyCodec_IgnoreError(exc: ptr[PyObject], as_bytes: bool) -> ptr[PyObject];

import from c {
    def PyCodec_IgnoreErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if is_unicode_encode_error(exc) or is_unicode_translate_error(exc) {
            return _PyCodec_IgnoreError(exc, False);
        } elif is_unicode_decode_error(exc) {
            return _PyCodec_IgnoreError(exc, True);
        }
        wrong_exception_type(exc);
        return NULL;
    }
}

def _PyCodec_ReplaceUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_ReplaceUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_ReplaceUnicodeTranslateError(exc: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyCodec_ReplaceErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if is_unicode_encode_error(exc) {
            return _PyCodec_ReplaceUnicodeEncodeError(exc);
        } elif is_unicode_decode_error(exc) {
            return _PyCodec_ReplaceUnicodeDecodeError(exc);
        } elif is_unicode_translate_error(exc) {
            return _PyCodec_ReplaceUnicodeTranslateError(exc);
        }
        wrong_exception_type(exc);
        return NULL;
    }  def PyCodec_XMLCharRefReplaceErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if not is_unicode_encode_error(exc) {
            wrong_exception_type(exc);
            return NULL;
        }

        (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
        if status < 0 {
            return NULL;
        }

        if slen > PY_SSIZE_T_MAX // (2 + 7 + 1) {
            end = start + PY_SSIZE_T_MAX // (2 + 7 + 1);
            end = min(end, objlen);
            slen = max(0, end - start);
        }

        ressize: i64 = 0;
        i = start;
        while i < end {
            ch = uo_read_char(obj_, i);
            k = n_decimal_digits_for_codepoint(ch);
            ressize += 2 + k + 1;
            i += 1;
        }

        res = PyUnicode_New(ressize, u32(127));
        if not res {
            object_decref(obj_);
            return NULL;
        }
        outp = uo_data(res);

        i = start;
        while i < end {
            ch = uo_read_char(obj_, i);

            outp.view(2)[0] = u8(38);
            outp.view(2)[1] = u8(35);
            outp = outp + 2;
            ndigits = n_decimal_digits_for_codepoint(ch);
            d = ndigits - 1;
            while d >= 0 {
                (outp + d).view(1)[0] = u8(48) + u8(ch % u32(10));
                ch = ch // u32(10);
                d -= 1;
            }
            outp = outp + ndigits;
            outp.view(1)[0] = u8(59);
            outp = outp + 1;
            i += 1;
        }
        restuple = Py_BuildValue(ptr[u8]("(Nn)"), res, end);
        object_decref(obj_);
        return restuple;
    }
}

def _PyCodec_BackslashReplaceUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_BackslashReplaceUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_BackslashReplaceUnicodeTranslateError(
    exc: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyCodec_BackslashReplaceErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if is_unicode_encode_error(exc) {
            return _PyCodec_BackslashReplaceUnicodeEncodeError(exc);
        } elif is_unicode_decode_error(exc) {
            return _PyCodec_BackslashReplaceUnicodeDecodeError(exc);
        } elif is_unicode_translate_error(exc) {
            return _PyCodec_BackslashReplaceUnicodeTranslateError(exc);
        }
        wrong_exception_type(exc);
        return NULL;
    }  def PyCodec_NameReplaceErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
        if not is_unicode_encode_error(exc) {
            wrong_exception_type(exc);
            return NULL;
        }

        ucnhash_capi = _PyUnicode_GetNameCAPI();
        if not ucnhash_capi {
            return NULL;
        }

        (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
        if status < 0 {
            return NULL;
        }

        slots: own CodecNameBuffer = CodecNameBuffer();
        buffer = ptr[u8](jacpy_stack_address(&mut slots));
        imax = start;
        ressize: i64 = 0;
        replsize: i64 = 0;
        while imax < end {
            c = uo_read_char(obj_, imax);
            if ucnhash_capi.view(1)[0].getname(c, buffer, NAME_BUFFER_SIZE, i32(1))
                != 0 {
                replsize = 1 + 1 + 1 + i64(strlen(buffer)) + 1;
            } else {
                replsize = codec_handler_unicode_hex_width(c);
            }
            if ressize > PY_SSIZE_T_MAX - replsize {
                break;
            }
            ressize += replsize;
            imax += 1;
        }

        res = PyUnicode_New(ressize, u32(127));
        if not res {
            object_decref(obj_);
            return NULL;
        }

        outp = uo_data(res);
        i = start;
        while i < imax {
            c = uo_read_char(obj_, i);
            if ucnhash_capi.view(1)[0].getname(c, buffer, NAME_BUFFER_SIZE, i32(1))
                != 0 {
                outp.view(3)[0] = u8(92);
                outp.view(3)[1] = u8(78);
                outp.view(3)[2] = u8(123);
                outp = outp + 3;
                name_len = strlen(buffer);
                memcpy(ptr(outp), ptr(buffer), name_len);
                outp = outp + i64(name_len);
                outp.view(1)[0] = u8(125);
                outp = outp + 1;
            } else {
                outp = codec_handler_write_unicode_hex(outp, c);
            }
            i += 1;
        }

        restuple = Py_BuildValue(ptr[u8]("(Nn)"), res, imax);
        object_decref(obj_);
        return restuple;
    }
}

def ascii_tolower(c: u8) -> u8;

def get_standard_encoding_impl(encoding_name: ptr[u8]) -> tuple[i32, i32];

def get_standard_encoding(encoding: ptr[PyObject]) -> tuple[i32, i32, i32];

def is_surrogate(ch: u32) -> bool;

def _PyCodec_SurrogatePassUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_SurrogatePassUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def PyCodec_SurrogatePassErrors(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_SurrogateEscapeUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def _PyCodec_SurrogateEscapeUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject];

def PyCodec_SurrogateEscapeErrors(exc: ptr[PyObject]) -> ptr[PyObject];

def strict_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def ignore_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def replace_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def xmlcharrefreplace_errors(
    self_: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def backslashreplace_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def namereplace_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def surrogatepass_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

def surrogateescape_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyCodec_InitRegistry(interp: ptr[u8]) -> PyStatus {
        path = PyList_New(0);
        codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_PATH).view(1)[0] = path;
        if not path {
            return PyStatus_NoMemory();
        }
        cache = PyDict_New();
        codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_CACHE).view(1)[0] = cache;
        if not cache {
            return PyStatus_NoMemory();
        }
        registry = PyDict_New();
        codecs_slot(interp, PyInterpreterState_CODECS_ERROR_REGISTRY).view(1)[0] = registry;
        if not registry {
            return PyStatus_NoMemory();
        }
        i: i64 = 0;
        while i < BUILTIN_ERROR_HANDLER_COUNT {
            func = PyCFunction_NewEx(
                addressof(codecs_builtin_error_methods) + i, NULL, NULL
            );
            if not func {
                return PyStatus_NoMemory();
            }

            res = PyDict_SetItemString(
                registry,
                (addressof(codecs_builtin_error_handlers) + i).view(1)[0],
                func
            );
            object_decref(func);
            if res < 0 {
                return PyStatus_Error(
                    ptr[u8]("Failed to insert into codec error registry")
                );
            }
            i += 1;
        }

        codecs_initialized(interp).view(1)[0] = 1;

        mod = PyImport_ImportModule("encodings");
        if not mod {
            return PyStatus_Error(ptr[u8]("Failed to import encodings module"));
        }
        object_decref(mod);

        return PyStatus_Ok();
    }  def _PyCodec_Fini(interp: ptr[u8]) {
        slot = codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_PATH);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
        slot = codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_CACHE);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
        slot = codecs_slot(interp, PyInterpreterState_CODECS_ERROR_REGISTRY);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
        codecs_initialized(interp).view(1)[0] = 0;
    }
}

impl codecs_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](interp + offset);
}

impl codecs_initialized(interp: ptr[u8]) -> ptr[i32] {
    return ptr[i32](interp + PyInterpreterState_CODECS_INITIALIZED);
}

impl search_path(interp: ptr[u8]) -> ptr[PyObject] {
    return codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_PATH).view(1)[0];
}

impl search_cache(interp: ptr[u8]) -> ptr[PyObject] {
    return codecs_slot(interp, PyInterpreterState_CODECS_SEARCH_CACHE).view(1)[0];
}

impl error_registry(interp: ptr[u8]) -> ptr[PyObject] {
    return codecs_slot(interp, PyInterpreterState_CODECS_ERROR_REGISTRY).view(1)[0];
}

impl hexdigit(v: u32) -> u8 {
    return (addressof(Py_hexdigits).view(1)[0] + i64(v)).view(1)[0];
}

impl normalizestring(string: ptr[u8]) -> ptr[PyObject] {
    len_ = strlen(string);
    if len_ > u64(PY_SSIZE_T_MAX) {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("string is too large"));
        return NULL;
    }

    encoding = ptr[u8](PyMem_Malloc(len_ + u64(1)));
    if not encoding {
        return PyErr_NoMemory();
    }

    if _Py_normalize_encoding(string, encoding, len_ + u64(1)) == 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("_Py_normalize_encoding() failed"));
        PyMem_Free(ptr(encoding));
        return NULL;
    }

    v = PyUnicode_FromString(encoding);
    PyMem_Free(ptr(encoding));
    return v;
}

impl args_tuple(object_: ptr[PyObject], errors: ptr[u8]) -> ptr[PyObject] {
    size: i64 = 2 if errors else 1;
    args = PyTuple_New(size);
    if not args {
        return NULL;
    }
    tuple_set_item(args, 0, object_new_ref(object_));
    if errors {
        v = PyUnicode_FromString(errors);
        if not v {
            object_decref(args);
            return NULL;
        }
        tuple_set_item(args, 1, v);
    }
    return args;
}

impl codec_getitem(encoding: ptr[u8], index: i64) -> ptr[PyObject] {
    codecs = _PyCodec_Lookup(encoding);
    if not codecs {
        return NULL;
    }
    v = tuple_get_item(codecs, index);
    object_decref(codecs);
    return object_new_ref(v);
}

impl codec_makeincrementalcodec(
    codec_info: ptr[PyObject], errors: ptr[u8], attrname: ptr[u8]
) -> ptr[PyObject] {
    inccodec = PyObject_GetAttrString(codec_info, attrname);
    if not inccodec {
        return NULL;
    }
    ret = NULL;
    if errors {
        ret = PyObject_CallFunction(inccodec, "s", errors);
    } else {
        ret = PyObject_CallNoArgs(inccodec);
    }
    object_decref(inccodec);
    return ret;
}

impl codec_getincrementalcodec(
    encoding: ptr[u8], errors: ptr[u8], attrname: ptr[u8]
) -> ptr[PyObject] {
    codec_info = _PyCodec_Lookup(encoding);
    if not codec_info {
        return NULL;
    }
    ret = codec_makeincrementalcodec(codec_info, errors, attrname);
    object_decref(codec_info);
    return ret;
}

impl codec_getstreamcodec(
    encoding: ptr[u8], stream: ptr[PyObject], errors: ptr[u8], index: i64
) -> ptr[PyObject] {
    codecs = _PyCodec_Lookup(encoding);
    if not codecs {
        return NULL;
    }

    codeccls = tuple_get_item(codecs, index);
    streamcodec = NULL;
    if errors {
        streamcodec = PyObject_CallFunction(codeccls, "Os", stream, errors);
    } else {
        streamcodec = PyObject_CallOneArg(codeccls, stream);
    }
    object_decref(codecs);
    return streamcodec;
}

impl _PyCodec_EncodeInternal(
    object_: ptr[PyObject], encoder: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    args = args_tuple(object_, errors);
    if not args {
        object_xdecref(encoder);
        return NULL;
    }

    result = PyObject_Call(encoder, args, NULL);
    if not result {
        _PyErr_FormatNote("%s with '%s' codec failed", ptr[u8]("encoding"), encoding);
        object_decref(args);
        object_xdecref(encoder);
        return NULL;
    }

    if not tuple_check(result) or object_size(result) != 2 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("encoder must return a tuple (object, integer)")
        );
        object_decref(result);
        object_decref(args);
        object_xdecref(encoder);
        return NULL;
    }
    v = object_new_ref(tuple_get_item(result, 0));

    object_decref(args);
    object_decref(encoder);
    object_decref(result);
    return v;
}

impl _PyCodec_DecodeInternal(
    object_: ptr[PyObject], decoder: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    args = args_tuple(object_, errors);
    if not args {
        object_xdecref(decoder);
        return NULL;
    }

    result = PyObject_Call(decoder, args, NULL);
    if not result {
        _PyErr_FormatNote("%s with '%s' codec failed", ptr[u8]("decoding"), encoding);
        object_decref(args);
        object_xdecref(decoder);
        return NULL;
    }
    if not tuple_check(result) or object_size(result) != 2 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("decoder must return a tuple (object,integer)")
        );
        object_decref(args);
        object_xdecref(decoder);
        object_decref(result);
        return NULL;
    }
    v = object_new_ref(tuple_get_item(result, 0));

    object_decref(args);
    object_decref(decoder);
    object_decref(result);
    return v;
}

impl codec_getitem_checked(
    encoding: ptr[u8], alternate_command: ptr[u8], index: i64
) -> ptr[PyObject] {
    codec = _PyCodec_LookupTextEncoding(encoding, alternate_command);
    if not codec {
        return NULL;
    }

    v = object_new_ref(tuple_get_item(codec, index));
    object_decref(codec);
    return v;
}

impl _PyCodec_TextEncoder(encoding: ptr[u8]) -> ptr[PyObject] {
    return codec_getitem_checked(encoding, ptr[u8]("codecs.encode()"), 0);
}

impl _PyCodec_TextDecoder(encoding: ptr[u8]) -> ptr[PyObject] {
    return codec_getitem_checked(encoding, ptr[u8]("codecs.decode()"), 1);
}

impl wrong_exception_type(exc: ptr[PyObject]) {
    PyErr_Format(PyExc_TypeError, ptr[u8]("don't know how to handle %T in error callback"), exc);
}

impl is_unicode_encode_error(exc: ptr[PyObject]) -> bool {
    return object_type_check(exc, ptr[PyTypeObject](PyExc_UnicodeEncodeError));
}

impl is_unicode_decode_error(exc: ptr[PyObject]) -> bool {
    return object_type_check(exc, ptr[PyTypeObject](PyExc_UnicodeDecodeError));
}

impl is_unicode_translate_error(exc: ptr[PyObject]) -> bool {
    return object_type_check(exc, ptr[PyTypeObject](PyExc_UnicodeTranslateError));
}

impl reraise_exception(exc: ptr[PyObject]) {
    PyErr_SetObject(ptr[PyObject](object_type(exc)), exc);
}

impl codec_handler_unicode_hex_width(ch: u32) -> i64 {
    if ch >= u32(0x10000) {
        return 1 + 1 + 8;
    } elif ch >= u32(0x100) {
        return 1 + 1 + 4;
    }

    return 1 + 1 + 2;
}

impl codec_handler_write_unicode_hex(p: ptr[u8], ch: u32) -> ptr[u8] {
    out = p;
    out.view(1)[0] = u8(92);
    out = out + 1;
    if ch >= u32(0x10000) {
        out.view(8)[0] = u8(85);
        out.view(8)[1] = hexdigit((ch >> u32(28)) & u32(0xf));
        out.view(8)[2] = hexdigit((ch >> u32(24)) & u32(0xf));
        out.view(8)[3] = hexdigit((ch >> u32(20)) & u32(0xf));
        out.view(8)[4] = hexdigit((ch >> u32(16)) & u32(0xf));
        out.view(8)[5] = hexdigit((ch >> u32(12)) & u32(0xf));
        out.view(8)[6] = hexdigit((ch >> u32(8)) & u32(0xf));
        out = out + 7;
    } elif ch >= u32(0x100) {
        out.view(4)[0] = u8(117);
        out.view(4)[1] = hexdigit((ch >> u32(12)) & u32(0xf));
        out.view(4)[2] = hexdigit((ch >> u32(8)) & u32(0xf));
        out = out + 3;
    } else {
        out.view(1)[0] = u8(120);
        out = out + 1;
    }
    out.view(2)[0] = hexdigit((ch >> u32(4)) & u32(0xf));
    out.view(2)[1] = hexdigit(ch & u32(0xf));
    return out + 2;
}

impl n_decimal_digits_for_codepoint(ch: u32) -> i64 {
    if ch < u32(10) {
        return 1;
    }
    if ch < u32(100) {
        return 2;
    }
    if ch < u32(1000) {
        return 3;
    }
    if ch < u32(10000) {
        return 4;
    }
    if ch < u32(100000) {
        return 5;
    }
    if ch < u32(1000000) {
        return 6;
    }

    return 7;
}

impl codec_handler_unicode_replacement_character(count: i64) -> ptr[PyObject] {
    res = PyUnicode_New(count, Py_UNICODE_REPLACEMENT_CHARACTER);
    if not res {
        return NULL;
    }
    outp = ptr[u16](uo_data(res));
    i: i64 = 0;
    while i < count {
        (outp + i).view(1)[0] = u16(0xFFFD);
        i += 1;
    }
    return res;
}

impl _PyCodec_IgnoreError(exc: ptr[PyObject], as_bytes: bool) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, as_bytes);
    if status < 0 {
        return NULL;
    }
    object_decref(obj_);
    return Py_BuildValue(ptr[u8]("(Nn)"), Py_GetConstant(Py_CONSTANT_EMPTY_STR), end);
}

impl _PyCodec_ReplaceUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
    if status < 0 {
        return NULL;
    }
    object_decref(obj_);
    res = PyUnicode_New(slen, u32(63));
    if not res {
        return NULL;
    }
    memset(ptr(uo_data(res)), i32(63), u64(slen));
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_ReplaceUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, True);
    if status < 0 {
        return NULL;
    }
    object_decref(obj_);
    res = codec_handler_unicode_replacement_character(1);
    if not res {
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_ReplaceUnicodeTranslateError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
    if status < 0 {
        return NULL;
    }
    object_decref(obj_);
    res = codec_handler_unicode_replacement_character(slen);
    if not res {
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_BackslashReplaceUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
    if status < 0 {
        return NULL;
    }

    if slen > PY_SSIZE_T_MAX // (1 + 1 + 8) {
        end = start + PY_SSIZE_T_MAX // (1 + 1 + 8);
        end = min(end, objlen);
        slen = max(0, end - start);
    }

    ressize: i64 = 0;
    i = start;
    while i < end {
        c = uo_read_char(obj_, i);
        ressize += codec_handler_unicode_hex_width(c);
        i += 1;
    }
    res = PyUnicode_New(ressize, u32(127));
    if not res {
        object_decref(obj_);
        return NULL;
    }
    outp = uo_data(res);
    i = start;
    while i < end {
        c = uo_read_char(obj_, i);
        outp = codec_handler_write_unicode_hex(outp, c);
        i += 1;
    }
    object_decref(obj_);
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_BackslashReplaceUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, True);
    if status < 0 {
        return NULL;
    }

    res = PyUnicode_New(4 * slen, u32(127));
    if not res {
        object_decref(obj_);
        return NULL;
    }

    outp = uo_data(res);
    p = PyBytes_AsString(obj_);
    i = start;
    while i < end {
        ch = u32((p + i).view(1)[0]);
        outp.view(4)[0] = u8(92);
        outp.view(4)[1] = u8(120);
        outp.view(4)[2] = hexdigit((ch >> u32(4)) & u32(0xf));
        outp.view(4)[3] = hexdigit(ch & u32(0xf));
        outp = outp + 4;
        i += 1;
    }
    object_decref(obj_);
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_BackslashReplaceUnicodeTranslateError(
    exc: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyCodec_BackslashReplaceUnicodeEncodeError(exc);
}

impl ascii_tolower(c: u8) -> u8 {
    if c >= u8(65) and c <= u8(90) {
        return c + u8(32);
    }
    return c;
}

impl get_standard_encoding_impl(encoding_name: ptr[u8]) -> tuple[i32, i32] {
    encoding = encoding_name;
    if ascii_tolower(encoding.view(3)[0]) == u8(117)
        and ascii_tolower(encoding.view(3)[1]) == u8(116)
        and ascii_tolower(encoding.view(3)[2]) == u8(102) {
        encoding = encoding + 3;
        if encoding.view(1)[0] == u8(45) or encoding.view(1)[0] == u8(95) {
            encoding = encoding + 1;
        }
        if encoding.view(1)[0] == u8(56) and encoding.view(2)[1] == u8(0) {
            return (ENC_UTF8, i32(3));
        } elif encoding.view(1)[0] == u8(49) and encoding.view(2)[1] == u8(54) {
            encoding = encoding + 2;
            if encoding.view(1)[0] == u8(0) {
                return (ENC_UTF16LE, i32(2));
            }
            if encoding.view(1)[0] == u8(45) or encoding.view(1)[0] == u8(95) {
                encoding = encoding + 1;
            }
            if ascii_tolower(encoding.view(2)[1]) == u8(101)
                and encoding.view(3)[2] == u8(0) {
                if ascii_tolower(encoding.view(1)[0]) == u8(98) {
                    return (ENC_UTF16BE, i32(2));
                }
                if ascii_tolower(encoding.view(1)[0]) == u8(108) {
                    return (ENC_UTF16LE, i32(2));
                }
            }
            return (ENC_UNKNOWN, i32(2));
        } elif encoding.view(1)[0] == u8(51) and encoding.view(2)[1] == u8(50) {
            encoding = encoding + 2;
            if encoding.view(1)[0] == u8(0) {
                return (ENC_UTF32LE, i32(4));
            }
            if encoding.view(1)[0] == u8(45) or encoding.view(1)[0] == u8(95) {
                encoding = encoding + 1;
            }
            if ascii_tolower(encoding.view(2)[1]) == u8(101)
                and encoding.view(3)[2] == u8(0) {
                if ascii_tolower(encoding.view(1)[0]) == u8(98) {
                    return (ENC_UTF32BE, i32(4));
                }
                if ascii_tolower(encoding.view(1)[0]) == u8(108) {
                    return (ENC_UTF32LE, i32(4));
                }
            }
            return (ENC_UNKNOWN, i32(4));
        }
    } elif strcmp(encoding, ptr[u8]("cp65001")) == 0 {
        return (ENC_UTF8, i32(3));
    }
    return (ENC_UNKNOWN, i32(0));
}

impl get_standard_encoding(encoding: ptr[PyObject]) -> tuple[i32, i32, i32] {
    encoding_cstr = PyUnicode_AsUTF8(encoding);
    if not encoding_cstr {
        return (i32(-1), ENC_UNKNOWN, i32(0));
    }
    (code, bytelength) = get_standard_encoding_impl(encoding_cstr);
    return (i32(0), code, bytelength);
}

impl is_surrogate(ch: u32) -> bool {
    return ch >= u32(0xD800) and ch <= u32(0xDFFF);
}

impl _PyCodec_SurrogatePassUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    encoding = PyUnicodeEncodeError_GetEncoding(exc);
    if not encoding {
        return NULL;
    }
    (rc, code, bytelength) = get_standard_encoding(encoding);
    object_decref(encoding);
    if rc < 0 {
        return NULL;
    }
    if code == ENC_UNKNOWN {
        reraise_exception(exc);
        return NULL;
    }

    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
    if status < 0 {
        return NULL;
    }

    width = i64(bytelength);
    if slen > PY_SSIZE_T_MAX // width {
        end = start + PY_SSIZE_T_MAX // width;
        end = min(end, objlen);
        slen = max(0, end - start);
    }

    res = PyBytes_FromStringAndSize(ptr[u8](), width * slen);
    if not res {
        object_decref(obj_);
        return NULL;
    }

    outp = PyBytes_AsString(res);
    i = start;
    while i < end {
        ch = uo_read_char(obj_, i);
        if not is_surrogate(ch) {
            object_decref(obj_);
            object_decref(res);
            reraise_exception(exc);
            return NULL;
        }
        if code == ENC_UTF8 {
            outp.view(3)[0] = u8.wrap(u32(0xe0) | (ch >> u32(12)));
            outp.view(3)[1] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            outp.view(3)[2] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            outp = outp + 3;
        } elif code == ENC_UTF16LE {
            outp.view(2)[0] = u8.wrap(ch);
            outp.view(2)[1] = u8.wrap(ch >> u32(8));
            outp = outp + 2;
        } elif code == ENC_UTF16BE {
            outp.view(2)[0] = u8.wrap(ch >> u32(8));
            outp.view(2)[1] = u8.wrap(ch);
            outp = outp + 2;
        } elif code == ENC_UTF32LE {
            outp.view(4)[0] = u8.wrap(ch);
            outp.view(4)[1] = u8.wrap(ch >> u32(8));
            outp.view(4)[2] = u8.wrap(ch >> u32(16));
            outp.view(4)[3] = u8.wrap(ch >> u32(24));
            outp = outp + 4;
        } elif code == ENC_UTF32BE {
            outp.view(4)[0] = u8.wrap(ch >> u32(24));
            outp.view(4)[1] = u8.wrap(ch >> u32(16));
            outp.view(4)[2] = u8.wrap(ch >> u32(8));
            outp.view(4)[3] = u8.wrap(ch);
            outp = outp + 4;
        }
        i += 1;
    }

    object_decref(obj_);
    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_SurrogatePassUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    encoding = PyUnicodeDecodeError_GetEncoding(exc);
    if not encoding {
        return NULL;
    }
    (rc, code, bytelength) = get_standard_encoding(encoding);
    object_decref(encoding);
    if rc < 0 {
        return NULL;
    }
    if code == ENC_UNKNOWN {
        reraise_exception(exc);
        return NULL;
    }

    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, True);
    if status < 0 {
        return NULL;
    }

    ch = u32(0);
    p = PyBytes_AsString(obj_) + start;

    if objlen - start >= i64(bytelength) {
        if code == ENC_UTF8 {
            if (p.view(3)[0] & u8(0xf0)) == u8(0xe0)
                and (p.view(3)[1] & u8(0xc0)) == u8(0x80)
                and (p.view(3)[2] & u8(0xc0)) == u8(0x80) {
                ch = ((u32(p.view(3)[0]) & u32(0x0f)) << u32(12))
                    + ((u32(p.view(3)[1]) & u32(0x3f)) << u32(6))
                    + (u32(p.view(3)[2]) & u32(0x3f));
            }
        } elif code == ENC_UTF16LE {
            ch = (u32(p.view(2)[1]) << u32(8)) | u32(p.view(2)[0]);
        } elif code == ENC_UTF16BE {
            ch = (u32(p.view(2)[0]) << u32(8)) | u32(p.view(2)[1]);
        } elif code == ENC_UTF32LE {
            ch = (u32(p.view(4)[3]) << u32(24))
                | (u32(p.view(4)[2]) << u32(16))
                | (u32(p.view(4)[1]) << u32(8))
                | u32(p.view(4)[0]);
        } elif code == ENC_UTF32BE {
            ch = (u32(p.view(4)[0]) << u32(24))
                | (u32(p.view(4)[1]) << u32(16))
                | (u32(p.view(4)[2]) << u32(8))
                | u32(p.view(4)[3]);
        }
    }
    object_decref(obj_);
    if not is_surrogate(ch) {
        reraise_exception(exc);
        return NULL;
    }

    res = PyUnicode_FromOrdinal(i32(ch));
    if not res {
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("(Nn)"), res, start + i64(bytelength));
}

impl PyCodec_SurrogatePassErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
    if is_unicode_encode_error(exc) {
        return _PyCodec_SurrogatePassUnicodeEncodeError(exc);
    } elif is_unicode_decode_error(exc) {
        return _PyCodec_SurrogatePassUnicodeDecodeError(exc);
    }
    wrong_exception_type(exc);
    return NULL;
}

impl _PyCodec_SurrogateEscapeUnicodeEncodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, False);
    if status < 0 {
        return NULL;
    }

    res = PyBytes_FromStringAndSize(ptr[u8](), slen);
    if not res {
        object_decref(obj_);
        return NULL;
    }

    outp = PyBytes_AsString(res);
    i = start;
    while i < end {
        ch = uo_read_char(obj_, i);
        if ch < u32(0xdc80) or ch > u32(0xdcff) {
            object_decref(obj_);
            object_decref(res);
            reraise_exception(exc);
            return NULL;
        }
        outp.view(1)[0] = u8(ch - u32(0xdc00));
        outp = outp + 1;
        i += 1;
    }
    object_decref(obj_);

    return Py_BuildValue(ptr[u8]("(Nn)"), res, end);
}

impl _PyCodec_SurrogateEscapeUnicodeDecodeError(exc: ptr[PyObject]) -> ptr[PyObject] {
    (status, obj_, objlen, start, end, slen) = unicode_error_params(exc, True);
    if status < 0 {
        return NULL;
    }

    slots: own CodecNameBuffer = CodecNameBuffer();
    ch = ptr[u16](jacpy_stack_address(&mut slots));
    consumed: i64 = 0;
    p = PyBytes_AsString(obj_);
    while consumed < 4 and consumed < slen {
        byte = (p + (start + consumed)).view(1)[0];
        if byte < u8(128) {
            break;
        }
        (ch + consumed).view(1)[0] = u16(0xdc00) + u16(byte);
        consumed += 1;
    }
    object_decref(obj_);

    if consumed == 0 {
        reraise_exception(exc);
        return NULL;
    }

    str_ = PyUnicode_FromKindAndData(PyUnicode_2BYTE_KIND, ptr(ch), consumed);
    if not str_ {
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("(Nn)"), str_, start + consumed);
}

impl PyCodec_SurrogateEscapeErrors(exc: ptr[PyObject]) -> ptr[PyObject] {
    if is_unicode_encode_error(exc) {
        return _PyCodec_SurrogateEscapeUnicodeEncodeError(exc);
    } elif is_unicode_decode_error(exc) {
        return _PyCodec_SurrogateEscapeUnicodeDecodeError(exc);
    }
    wrong_exception_type(exc);
    return NULL;
}

impl strict_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_StrictErrors(exc);
}

impl ignore_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_IgnoreErrors(exc);
}

impl replace_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_ReplaceErrors(exc);
}

impl xmlcharrefreplace_errors(
    self_: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    return PyCodec_XMLCharRefReplaceErrors(exc);
}

impl backslashreplace_errors(
    self_: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    return PyCodec_BackslashReplaceErrors(exc);
}

impl namereplace_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_NameReplaceErrors(exc);
}

impl surrogatepass_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_SurrogatePassErrors(exc);
}

impl surrogateescape_errors(self_: ptr[PyObject], exc: ptr[PyObject]) -> ptr[PyObject] {
    return PyCodec_SurrogateEscapeErrors(exc);
}
