import from c {
    def memcpy(dest: ptr, src: ptr, n: u64) -> ptr;  def memchr(
        source: ptr, value: i32, n: u64
    ) -> ptr;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def _PyCodecInfo_GetIncrementalDecoder(
        codec_info: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyCodecInfo_GetIncrementalEncoder(
        codec_info: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyCodec_LookupTextEncoding(
        encoding: ptr[u8], alternate_command: ptr[u8]
    ) -> ptr[PyObject];  def _Py_GetConfig -> ptr[u8];  def jacpy_stack_address(
        slots: &mut IOStack
    ) -> int;  obj nldecoder_object {
        has ob_base: _object,
            decoder: ptr[PyObject],
            errors: ptr[PyObject],
            pendingcr: u8,
            translate: u8,
            seennl: u8;
    }  obj textio {
        has ob_base: _object,
            ok: i32,
            detached: i32,
            chunk_size: i64,
            buffer: ptr[PyObject],
            encoding: ptr[PyObject],
            encoder: ptr[PyObject],
            decoder: ptr[PyObject],
            readnl: ptr[PyObject],
            errors: ptr[PyObject],
            writenl: ptr[u8],
            line_buffering: i8,
            write_through: i8,
            readuniversal: i8,
            readtranslate: i8,
            writetranslate: i8,
            seekable: i8,
            has_read1: i8,
            telling: i8,
            finalizing: i8,
            encodefunc: i64,
            encoding_start_of_stream: i8,
            decoded_chars: ptr[PyObject],
            decoded_chars_used: i64,
            pending_bytes: ptr[PyObject],
            pending_bytes_count: i64,
            snapshot: ptr[PyObject],
            b2cratio: f64,
            raw: ptr[PyObject],
            weakreflist: ptr[PyObject],
            dict: ptr[PyObject],
            state: ptr[IOModuleState];
    }  obj TextIOFastCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }  glob:priv textiowrapper_read_glue: TextIOFastCall = TextIOFastCall(),
         textiowrapper_readline_glue: TextIOFastCall = TextIOFastCall();
}

glob NLDECODER_SIZE: Final[i64] = 40,
     NLDECODER_DECODER: Final[i64] = 16,
     NLDECODER_ERRORS: Final[i64] = 24,
     TEXTIO_SIZE: Final[i64] = 200,
     TEXTIO_BUFFER: Final[i64] = 32,
     TEXTIO_ENCODING: Final[i64] = 40,
     TEXTIO_ENCODER: Final[i64] = 48,
     TEXTIO_DECODER: Final[i64] = 56,
     TEXTIO_READNL: Final[i64] = 64,
     TEXTIO_ERRORS: Final[i64] = 72,
     TEXTIO_LINE_BUFFERING: Final[i64] = 88,
     TEXTIO_WRITE_THROUGH: Final[i64] = 89,
     TEXTIO_FINALIZING: Final[i64] = 96,
     TEXTIO_DECODED_CHARS: Final[i64] = 120,
     TEXTIO_PENDING_BYTES: Final[i64] = 136,
     TEXTIO_SNAPSHOT: Final[i64] = 152,
     TEXTIO_RAW: Final[i64] = 168,
     TEXTIO_WEAKREFLIST: Final[i64] = 176,
     TEXTIO_DICT: Final[i64] = 184,
     SEEN_CR: Final[u8] = 1,
     SEEN_LF: Final[u8] = 2,
     SEEN_CRLF: Final[u8] = 4,
     SEEN_ALL: Final[u8] = 7,
     ENCODE_NONE: Final[i64] = 0,
     ENCODE_ASCII: Final[i64] = 1,
     ENCODE_LATIN1: Final[i64] = 2,
     ENCODE_UTF8: Final[i64] = 3,
     ENCODE_UTF16BE: Final[i64] = 4,
     ENCODE_UTF16LE: Final[i64] = 5,
     ENCODE_UTF16: Final[i64] = 6,
     ENCODE_UTF32BE: Final[i64] = 7,
     ENCODE_UTF32LE: Final[i64] = 8,
     ENCODE_UTF32: Final[i64] = 9,
     COOKIE_BUF_LEN: Final[u64] = 21,
     OFF_DEC_FLAGS: Final[i64] = 8,
     OFF_BYTES_TO_FEED: Final[i64] = 12,
     OFF_CHARS_TO_SKIP: Final[i64] = 16,
     OFF_NEED_EOF: Final[i64] = 20,
     UCS1_KIND: Final[i64] = 1,
     INT_MAX: Final[i64] = 2147483647,
     INT_MIN: Final[i64] = -2147483648;

def:priv textio_record(op: ptr[PyObject]) -> ptr[textio];

def:priv nldecoder_record(op: ptr[PyObject]) -> ptr[nldecoder_object];

def:priv field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def:priv _unsupported(state: ptr[IOModuleState], message: ptr[u8]) -> ptr[PyObject];

def _io__TextIOBase_detach_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _io__TextIOBase_read_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject];

def _io__TextIOBase_readline_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject];

def _io__TextIOBase_write_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], s: str
) -> ptr[PyObject];

def _io__TextIOBase_encoding_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _io__TextIOBase_newlines_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _io__TextIOBase_errors_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _io_IncrementalNewlineDecoder___init___impl(
    op: ptr[PyObject], decoder: ptr[PyObject], translate: bool, errors: ptr[PyObject]
) -> i32;

def incrementalnewlinedecoder_traverse(
    op: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32;

def incrementalnewlinedecoder_clear(op: ptr[PyObject]) -> i32;

def incrementalnewlinedecoder_dealloc(op: ptr[PyObject]);

def:priv check_decoded(decoded: ptr[PyObject]) -> i32;

def:priv check_initialized_decoder(op: ptr[PyObject]) -> bool;

import from c {
    def _PyIncrementalNewlineDecoder_decode(
        myself: ptr[PyObject], input: ptr[PyObject], final: i32
    ) -> ptr[PyObject] {
        self_ = nldecoder_record(myself).view(1);
        output: ptr[PyObject] = NULL;

        if not check_initialized_decoder(myself) {
            return NULL;
        }

        if self_[0].decoder != Py_None {
            output = io_call_twoargs(
                self_[0].decoder, py_id(_Py_ID_decode), input, io_bool(final != 0)
            );
        } else {
            output = object_new_ref(input);
        }

        if check_decoded(output) < 0 {
            return NULL;
        }

        output_len = unicode_length(output);
        if self_[0].pendingcr != 0 and (final != 0 or output_len > 0) {
            modified = PyUnicode_New(output_len + 1, uo_max_char_value(output));
            if not modified {
                object_decref(output);
                return NULL;
            }
            kind = uo_kind(modified);
            out = uo_data(modified);
            ch_write(kind, out, 0, u32(13));
            memcpy(ptr(out + kind), ptr(uo_data(output)), u64(kind * output_len));
            object_decref(output);
            output = modified;
            self_[0].pendingcr = 0;
            output_len += 1;
        }

        if final == 0 {
            if output_len > 0 and uo_read_char(output, output_len - 1) == u32(13) {
                modified = PyUnicode_Substring(output, 0, output_len - 1);
                if not modified {
                    object_decref(output);
                    return NULL;
                }
                object_decref(output);
                output = modified;
                self_[0].pendingcr = 1;
            }
        }

        in_str = uo_data(output);
        len = unicode_length(output);
        kind = uo_kind(output);
        seennl = self_[0].seennl;
        only_lf = False;

        if len == 0 {
            return output;
        }

        if seennl == SEEN_LF or seennl == 0 {
            only_lf = not memchr(ptr(in_str), 13, u64(kind * len));
        }

        if only_lf {
            if seennl == 0 and memchr(ptr(in_str), 10, u64(kind * len)) {
                if kind == UCS1_KIND {
                    seennl |= SEEN_LF;
                } else {
                    i: i64 = 0;
                    while True {
                        while ch_read(kind, in_str, i) > u32(10) {
                            i += 1;
                        }
                        c = ch_read(kind, in_str, i);
                        i += 1;
                        if c == u32(10) {
                            seennl |= SEEN_LF;
                            break;
                        }
                        if i >= len {
                            break;
                        }
                    }
                }
            }
        } elif self_[0].translate == 0 {
            i: i64 = 0;
            if seennl != SEEN_ALL {
                while True {
                    while ch_read(kind, in_str, i) > u32(13) {
                        i += 1;
                    }
                    c = ch_read(kind, in_str, i);
                    i += 1;
                    if c == u32(10) {
                        seennl |= SEEN_LF;
                    } elif c == u32(13) {
                        if ch_read(kind, in_str, i) == u32(10) {
                            seennl |= SEEN_CRLF;
                            i += 1;
                        } else {
                            seennl |= SEEN_CR;
                        }
                    }
                    if i >= len {
                        break;
                    }
                    if seennl == SEEN_ALL {
                        break;
                    }
                }
            }
        } else {
            translated = ptr[u8](PyMem_Malloc(u64(kind * len)));
            if not translated {
                PyErr_NoMemory();
                object_decref(output);
                return NULL;
            }
            in_pos: i64 = 0;
            out_pos: i64 = 0;
            while True {
                c: u32 = 0;

                while True {
                    c = ch_read(kind, in_str, in_pos);
                    in_pos += 1;
                    if c <= u32(13) {
                        break;
                    }
                    ch_write(kind, translated, out_pos, c);
                    out_pos += 1;
                }
                if c == u32(10) {
                    ch_write(kind, translated, out_pos, c);
                    out_pos += 1;
                    seennl |= SEEN_LF;
                    continue;
                }
                if c == u32(13) {
                    if ch_read(kind, in_str, in_pos) == u32(10) {
                        in_pos += 1;
                        seennl |= SEEN_CRLF;
                    } else {
                        seennl |= SEEN_CR;
                    }
                    ch_write(kind, translated, out_pos, u32(10));
                    out_pos += 1;
                    continue;
                }
                if in_pos > len {
                    break;
                }
                ch_write(kind, translated, out_pos, c);
                out_pos += 1;
            }
            object_decref(output);
            output = PyUnicode_FromKindAndData(i32(kind), ptr(translated), out_pos);
            PyMem_Free(ptr(translated));
            if not output {
                return NULL;
            }
        }
        self_[0].seennl |= seennl;

        return output;
    }
}

def _io_IncrementalNewlineDecoder_decode_impl(
    op: ptr[PyObject], input: ptr[PyObject], final: bool
) -> ptr[PyObject];

def:priv parse_buffer_flag(
    state: ptr[PyObject], illegal_setstate: bool
) -> tuple[bool, ptr[PyObject], u64];

def _io_IncrementalNewlineDecoder_getstate_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_IncrementalNewlineDecoder_setstate_impl(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject];

def _io_IncrementalNewlineDecoder_reset_impl(op: ptr[PyObject]) -> ptr[PyObject];

def incrementalnewlinedecoder_newlines_get(
    op: ptr[PyObject], context: ptr
) -> ptr[PyObject];

def:priv encode_text(op: ptr[PyObject], text: ptr[PyObject]) -> ptr[PyObject];

def:priv is_asciicompat_encoding(func: i64) -> bool;

def:priv encodefunc_of(name: ptr[PyObject]) -> i64;

def:priv validate_newline(newline: ptr[u8]) -> i32;

def:priv set_newline(op: ptr[PyObject], newline: ptr[u8]) -> i32;

def:priv _textiowrapper_set_decoder(
    op: ptr[PyObject], codec_info: ptr[PyObject], errors: ptr[u8]
) -> i32;

def:priv _textiowrapper_decode(
    state: ptr[IOModuleState], decoder: ptr[PyObject], bytes: ptr[PyObject], eof: bool
) -> ptr[PyObject];

def:priv _textiowrapper_set_encoder(
    op: ptr[PyObject], codec_info: ptr[PyObject], errors: ptr[u8]
) -> i32;

def:priv _textiowrapper_fix_encoder_state(op: ptr[PyObject]) -> i32;

def:priv io_check_errors(errors: ptr[PyObject]) -> i32;

def _io_TextIOWrapper___init___impl(
    op: ptr[PyObject],
    buffer: ptr[PyObject],
    encoding: ptr[u8],
    errors: ptr[PyObject],
    newline: ptr[u8],
    line_buffering: bool,
    write_through: bool
) -> i32;

def:priv convert_optional_bool(obj_: ptr[PyObject], default_value: i32) -> i32;

def:priv textiowrapper_change_encoding(
    op: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    newline_changed: bool
) -> i32;

def _io_TextIOWrapper_reconfigure_impl(
    op: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    newline_obj: ptr[PyObject],
    line_buffering_obj: ptr[PyObject],
    write_through_obj: ptr[PyObject]
) -> ptr[PyObject];

def textiowrapper_clear(op: ptr[PyObject]) -> i32;

def textiowrapper_dealloc(op: ptr[PyObject]);

def textiowrapper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def:priv check_closed(op: ptr[PyObject]) -> bool;

def:priv check_initialized(op: ptr[PyObject]) -> bool;

def:priv check_attached(op: ptr[PyObject]) -> bool;

def _io_TextIOWrapper_detach_impl(op: ptr[PyObject]) -> ptr[PyObject];

def:priv _textiowrapper_writeflush(op: ptr[PyObject]) -> i32;

def _io_TextIOWrapper_write_impl(
    op: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject];

def:priv textiowrapper_set_decoded_chars(op: ptr[PyObject], chars: ptr[PyObject]);

def:priv textiowrapper_get_decoded_chars(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def:priv decoder_state_pair(
    state: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], ptr[PyObject]];

def:priv getargs_int(value: ptr[PyObject]) -> tuple[bool, i32];

def:priv read_chunk_failed(
    dec_buffer: ptr[PyObject], dec_flags: ptr[PyObject], input_chunk: ptr[PyObject]
) -> i32;

def:priv textiowrapper_read_chunk(op: ptr[PyObject], size_hint: i64) -> i32;

def:priv read_failed(result: ptr[PyObject], chunks: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_read_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def:priv find_control_char(kind: i64, s: ptr[u8], end: ptr[u8], ch: u32) -> ptr[u8];

def:priv char_distance(start: ptr[u8], stop: ptr[u8], kind: i64) -> i64;

import from c {
    def _PyIO_find_line_ending(
        translated: i32,
        universal: i32,
        readnl: ptr[PyObject],
        kind: i32,
        start: ptr[u8],
        end: ptr[u8],
        consumed: ptr[i64]
    ) -> i64 {
        k = i64(kind);
        len = char_distance(start, end, k);

        if translated != 0 {
            pos = find_control_char(k, start, end, u32(10));
            if pos {
                return char_distance(start, pos, k) + 1;
            }
            consumed.view(1)[0] = len;
            return -1;
        } elif universal != 0 {
            s = start;
            while True {
                while ch_read(k, s, 0) > u32(13) {
                    s = s + k;
                }
                if int(s) >= int(end) {
                    consumed.view(1)[0] = len;
                    return -1;
                }
                ch = ch_read(k, s, 0);
                s = s + k;
                if ch == u32(10) {
                    return char_distance(start, s, k);
                }
                if ch == u32(13) {
                    if ch_read(k, s, 0) == u32(10) {
                        return char_distance(start, s, k) + 1;
                    }
                    return char_distance(start, s, k);
                }
            }
        }

        readnl_len = unicode_length(readnl);
        nl = uo_data(readnl);

        if readnl_len == 1 {
            pos = find_control_char(k, start, end, u32(nl.view(1)[0]));
            if pos {
                return char_distance(start, pos, k) + 1;
            }
            consumed.view(1)[0] = len;
            return -1;
        }
        s = start;
        e = end - (readnl_len - 1) * k;
        if int(e) < int(s) {
            e = s;
        }
        while int(s) < int(e) {
            pos = find_control_char(k, s, end, u32(nl.view(1)[0]));
            if not pos or int(pos) >= int(e) {
                break;
            }
            i: i64 = 1;
            while i < readnl_len {
                if ch_read(k, pos, i) != u32(nl.view(readnl_len)[i]) {
                    break;
                }
                i += 1;
            }
            if i == readnl_len {
                return char_distance(start, pos, k) + readnl_len;
            }
            s = pos + k;
        }
        pos = find_control_char(k, e, end, u32(nl.view(1)[0]));
        if not pos {
            consumed.view(1)[0] = len;
        } else {
            consumed.view(1)[0] = char_distance(start, pos, k);
        }
        return -1;
    }
}

def:priv readline_failed(
    chunks: ptr[PyObject], remaining: ptr[PyObject], line: ptr[PyObject]
) -> ptr[PyObject];

def:priv _textiowrapper_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject];

def _io_TextIOWrapper_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def:priv textiowrapper_parse_cookie(
    cookieObj: ptr[PyObject]
) -> tuple[i32, i64, i32, i32, i32, u8];

def:priv textiowrapper_build_cookie(
    start_pos: i64, dec_flags: i32, bytes_to_feed: i32, chars_to_skip: i32, need_eof: u8
) -> ptr[PyObject];

def:priv _textiowrapper_decoder_setstate(
    op: ptr[PyObject], start_pos: i64, dec_flags: i32
) -> i32;

def:priv _textiowrapper_encoder_reset(op: ptr[PyObject], start_of_stream: bool) -> i32;

def:priv _textiowrapper_encoder_setstate(
    op: ptr[PyObject], start_pos: i64, dec_flags: i32
) -> i32;

def:priv seek_failed(cookieObj: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_seek_impl(
    op: ptr[PyObject], cookieObj: ptr[PyObject], whence: i32
) -> ptr[PyObject];

def:priv tell_failed(op: ptr[PyObject], saved_state: ptr[PyObject]) -> ptr[PyObject];

def:priv decoder_getstate(op: ptr[PyObject]) -> tuple[i32, i64, i32];

def:priv decoder_decode(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64;

def _io_TextIOWrapper_tell_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_truncate_impl(
    op: ptr[PyObject], pos: ptr[PyObject]
) -> ptr[PyObject];

def:priv repr_failed(
    res: ptr[PyObject], status: i32, op: ptr[PyObject]
) -> ptr[PyObject];

def textiowrapper_repr(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_readable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_writable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_flush_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_close_impl(op: ptr[PyObject]) -> ptr[PyObject];

def textiowrapper_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_name_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_newlines_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper_errors_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper__CHUNK_SIZE_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_TextIOWrapper__CHUNK_SIZE_set_impl(
    op: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def textiowrapper_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def textiowrapper_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

import from c {
    glob:priv textiobase_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob textiobase_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io._TextIOBase"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(textiobase_slots)
         ); glob:priv incrementalnewlinedecoder_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("newlines"), get=incrementalnewlinedecoder_newlines_get
             ),
             PyGetSetDef()
         ],
         nldecoder_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_dealloc, pfunc=ptr(incrementalnewlinedecoder_dealloc)
             ),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_getset,
                 pfunc=ptr(addressof(incrementalnewlinedecoder_getset))
             ),
             PyType_Slot(
                 slot=Py_tp_traverse, pfunc=ptr(incrementalnewlinedecoder_traverse)
             ),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(incrementalnewlinedecoder_clear)),
             PyType_Slot(
                 slot=Py_tp_init, pfunc=ptr(_io_IncrementalNewlineDecoder___init___init)
             ),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob nldecoder_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.IncrementalNewlineDecoder"),
             basicsize=i32(NLDECODER_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(nldecoder_slots)
         ); glob:priv textiowrapper_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("encoding"),
                 type_=_Py_T_OBJECT,
                 offset=TEXTIO_ENCODING,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("buffer"),
                 type_=_Py_T_OBJECT,
                 offset=TEXTIO_BUFFER,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("line_buffering"),
                 type_=Py_T_BOOL,
                 offset=TEXTIO_LINE_BUFFERING,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("write_through"),
                 type_=Py_T_BOOL,
                 offset=TEXTIO_WRITE_THROUGH,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("_finalizing"),
                 type_=Py_T_BOOL,
                 offset=TEXTIO_FINALIZING,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=TEXTIO_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=TEXTIO_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ]; glob textiowrapper_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(textiowrapper_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(textiowrapper_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(textiowrapper_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(textiowrapper_clear)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(textiowrapper_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(textiowrapper_members))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_TextIOWrapper___init___init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob textiowrapper_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.TextIOWrapper"),
             basicsize=i32(TEXTIO_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(textiowrapper_slots)
         );
}

def install_textio_tables -> bool;

impl textio_record(op: ptr[PyObject]) -> ptr[textio] {
    return ptr[textio](op);
}

impl nldecoder_record(op: ptr[PyObject]) -> ptr[nldecoder_object] {
    return ptr[nldecoder_object](op);
}

impl field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset);
}

impl _unsupported(state: ptr[IOModuleState], message: ptr[u8]) -> ptr[PyObject] {
    PyErr_SetString(state.view(1)[0].unsupported_operation, message);
    return NULL;
}

impl _io__TextIOBase_detach_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return _unsupported(get_io_state_by_cls(cls), ptr[u8]("detach"));
}

impl _io__TextIOBase_read_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject] {
    return _unsupported(get_io_state_by_cls(cls), ptr[u8]("read"));
}

impl _io__TextIOBase_readline_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject] {
    return _unsupported(get_io_state_by_cls(cls), ptr[u8]("readline"));
}

impl _io__TextIOBase_write_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], s: str
) -> ptr[PyObject] {
    return _unsupported(get_io_state_by_cls(cls), ptr[u8]("write"));
}

impl _io__TextIOBase_encoding_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl _io__TextIOBase_newlines_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl _io__TextIOBase_errors_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl _io_IncrementalNewlineDecoder___init___impl(
    op: ptr[PyObject], decoder: ptr[PyObject], translate: bool, errors: ptr[PyObject]
) -> i32 {
    self_ = nldecoder_record(op).view(1);
    if not errors {
        errors = py_id(_Py_ID_strict);
    } else {
        errors = object_new_ref(errors);
    }
    py_xsetref(field_slot(op, NLDECODER_ERRORS), errors);

    py_xsetref(field_slot(op, NLDECODER_DECODER), object_new_ref(decoder));
    self_[0].translate = u8(1) if translate else u8(0);
    self_[0].seennl = 0;
    self_[0].pendingcr = 0;

    return 0;
}

impl incrementalnewlinedecoder_traverse(
    op: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32 {
    self_ = nldecoder_record(op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].decoder, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(self_[0].errors, visitor, arg);
}

impl incrementalnewlinedecoder_clear(op: ptr[PyObject]) -> i32 {
    py_clear(field_slot(op, NLDECODER_DECODER));
    py_clear(field_slot(op, NLDECODER_ERRORS));
    return 0;
}

impl incrementalnewlinedecoder_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    object_gc_untrack(op);
    incrementalnewlinedecoder_clear(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl check_decoded(decoded: ptr[PyObject]) -> i32 {
    if not decoded {
        return -1;
    }
    if not unicode_check(decoded) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("decoder should return a string result, not '%.200s'"),
            object_type(decoded).view(1)[0].tp_name
        );
        object_decref(decoded);
        return -1;
    }
    return 0;
}

impl check_initialized_decoder(op: ptr[PyObject]) -> bool {
    if not nldecoder_record(op).view(1)[0].errors {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("IncrementalNewlineDecoder.__init__() not called")
        );
        return False;
    }
    return True;
}

impl _io_IncrementalNewlineDecoder_decode_impl(
    op: ptr[PyObject], input: ptr[PyObject], final: bool
) -> ptr[PyObject] {
    return _PyIncrementalNewlineDecoder_decode(op, input, i32(1) if final else i32(0));
}

impl parse_buffer_flag(
    state: ptr[PyObject], illegal_setstate: bool
) -> tuple[bool, ptr[PyObject], u64] {
    if object_size(state) != 2 {
        if illegal_setstate {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("setstate(): illegal state argument")
            );
        } else {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
        }
        return (False, NULL, u64(0));
    }
    buffer = tuple_get_item(state, 0);
    value = tuple_get_item(state, 1);
    if PyIndex_Check(value) == 0 {
        if illegal_setstate {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("setstate(): illegal state argument")
            );
        } else {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
        }
        return (False, NULL, u64(0));
    }
    flag = PyLong_AsUnsignedLongLongMask(value);
    if flag == u64.wrap(-1) and PyErr_Occurred() {
        return (False, NULL, u64(0));
    }
    return (True, buffer, flag);
}

impl _io_IncrementalNewlineDecoder_getstate_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = nldecoder_record(op).view(1);
    buffer: ptr[PyObject] = NULL;
    flag: u64 = 0;

    if not check_initialized_decoder(op) {
        return NULL;
    }

    if self_[0].decoder != Py_None {
        state = io_call_noargs(self_[0].decoder, py_id(_Py_ID_getstate));
        if not state {
            return NULL;
        }
        if not tuple_check(state) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
            object_decref(state);
            return NULL;
        }
        (parsed, item, value) = parse_buffer_flag(state, False);
        if not parsed {
            object_decref(state);
            return NULL;
        }
        buffer = object_new_ref(item);
        flag = value;
        object_decref(state);
    } else {
        buffer = object_new_ref(bytes_get_empty());
        flag = 0;
    }
    flag = (flag & u64(0x7FFFFFFFFFFFFFFF)) << 1;
    if self_[0].pendingcr != 0 {
        flag |= 1;
    }
    return Py_BuildValue(ptr[u8]("NK"), buffer, flag);
}

impl _io_IncrementalNewlineDecoder_setstate_impl(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = nldecoder_record(op).view(1);

    if not check_initialized_decoder(op) {
        return NULL;
    }

    if not tuple_check(state) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("state argument must be a tuple"));
        return NULL;
    }
    (parsed, buffer, flag) = parse_buffer_flag(state, True);
    if not parsed {
        return NULL;
    }

    self_[0].pendingcr = u8(flag & 1);
    flag = flag >> 1;

    if self_[0].decoder != Py_None {
        args = Py_BuildValue(ptr[u8]("(OK)"), buffer, flag);
        if not args {
            return NULL;
        }
        res = io_call_onearg(self_[0].decoder, py_id(_Py_ID_setstate), args);
        object_decref(args);
        return res;
    }
    return object_new_ref(Py_None);
}

impl _io_IncrementalNewlineDecoder_reset_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = nldecoder_record(op).view(1);
    if not check_initialized_decoder(op) {
        return NULL;
    }

    self_[0].seennl = 0;
    self_[0].pendingcr = 0;
    if self_[0].decoder != Py_None {
        return io_call_noargs(self_[0].decoder, py_id(_Py_ID_reset));
    }
    return object_new_ref(Py_None);
}

impl incrementalnewlinedecoder_newlines_get(
    op: ptr[PyObject], context: ptr
) -> ptr[PyObject] {
    if not check_initialized_decoder(op) {
        return NULL;
    }

    seennl = nldecoder_record(op).view(1)[0].seennl;
    if seennl == SEEN_CR {
        return PyUnicode_FromString(ptr[u8]("\r"));
    } elif seennl == SEEN_LF {
        return PyUnicode_FromString(ptr[u8]("\n"));
    } elif seennl == SEEN_CRLF {
        return PyUnicode_FromString(ptr[u8]("\r\n"));
    } elif seennl == (SEEN_CR | SEEN_LF) {
        return Py_BuildValue(ptr[u8]("ss"), ptr[u8]("\r"), ptr[u8]("\n"));
    } elif seennl == (SEEN_CR | SEEN_CRLF) {
        return Py_BuildValue(ptr[u8]("ss"), ptr[u8]("\r"), ptr[u8]("\r\n"));
    } elif seennl == (SEEN_LF | SEEN_CRLF) {
        return Py_BuildValue(ptr[u8]("ss"), ptr[u8]("\n"), ptr[u8]("\r\n"));
    } elif seennl == (SEEN_CR | SEEN_LF | SEEN_CRLF) {
        return Py_BuildValue(
            ptr[u8]("sss"), ptr[u8]("\r"), ptr[u8]("\n"), ptr[u8]("\r\n")
        );
    }
    return object_new_ref(Py_None);
}

impl encode_text(op: ptr[PyObject], text: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    errors = PyUnicode_AsUTF8(self_[0].errors);
    func = self_[0].encodefunc;
    if func == ENCODE_ASCII {
        return _PyUnicode_AsASCIIString(text, errors);
    } elif func == ENCODE_LATIN1 {
        return _PyUnicode_AsLatin1String(text, errors);
    } elif func == ENCODE_UTF8 {
        return _PyUnicode_AsUTF8String(text, errors);
    } elif func == ENCODE_UTF16BE {
        return _PyUnicode_EncodeUTF16(text, errors, 1);
    } elif func == ENCODE_UTF16LE {
        return _PyUnicode_EncodeUTF16(text, errors, -1);
    } elif func == ENCODE_UTF16 {
        if self_[0].encoding_start_of_stream == 0 {
            return _PyUnicode_EncodeUTF16(text, errors, -1);
        }
        return _PyUnicode_EncodeUTF16(text, errors, 0);
    } elif func == ENCODE_UTF32BE {
        return _PyUnicode_EncodeUTF32(text, errors, 1);
    } elif func == ENCODE_UTF32LE {
        return _PyUnicode_EncodeUTF32(text, errors, -1);
    }
    if self_[0].encoding_start_of_stream == 0 {
        return _PyUnicode_EncodeUTF32(text, errors, -1);
    }
    return _PyUnicode_EncodeUTF32(text, errors, 0);
}

impl is_asciicompat_encoding(func: i64) -> bool {
    return func == ENCODE_ASCII or func == ENCODE_LATIN1 or func == ENCODE_UTF8;
}

impl encodefunc_of(name: ptr[PyObject]) -> i64 {
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("ascii")) != 0 {
        return ENCODE_ASCII;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("iso8859-1")) != 0 {
        return ENCODE_LATIN1;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-8")) != 0 {
        return ENCODE_UTF8;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-16-be")) != 0 {
        return ENCODE_UTF16BE;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-16-le")) != 0 {
        return ENCODE_UTF16LE;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-16")) != 0 {
        return ENCODE_UTF16;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-32-be")) != 0 {
        return ENCODE_UTF32BE;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-32-le")) != 0 {
        return ENCODE_UTF32LE;
    }
    if _PyUnicode_EqualToASCIIString(name, ptr[u8]("utf-32")) != 0 {
        return ENCODE_UTF32;
    }
    return ENCODE_NONE;
}

impl validate_newline(newline: ptr[u8]) -> i32 {
    if newline and newline.view(1)[0] != u8(0) {
        legal = False;
        first = newline.view(1)[0];
        if first == u8(10) {
            legal = newline.view(2)[1] == u8(0);
        } elif first == u8(13) {
            second = newline.view(2)[1];
            legal = second == u8(0)
                or (second == u8(10) and newline.view(3)[2] == u8(0));
        }
        if not legal {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("illegal newline value: %s"), newline
            );
            return -1;
        }
    }
    return 0;
}

impl set_newline(op: ptr[PyObject], newline: ptr[u8]) -> i32 {
    self_ = textio_record(op).view(1);
    old = self_[0].readnl;
    if not newline {
        self_[0].readnl = NULL;
    } else {
        self_[0].readnl = PyUnicode_FromString(newline);
        if not self_[0].readnl {
            self_[0].readnl = old;
            return -1;
        }
    }
    universal = not newline or newline.view(1)[0] == u8(0);
    self_[0].readuniversal = i8(1) if universal else i8(0);
    self_[0].readtranslate = i8(1) if not newline else i8(0);
    writetranslate = not newline or newline.view(1)[0] != u8(0);
    self_[0].writetranslate = i8(1) if writetranslate else i8(0);
    if self_[0].readuniversal == 0 and self_[0].readnl {
        self_[0].writenl = uo_data(self_[0].readnl);
        if strcmp(self_[0].writenl, ptr[u8]("\n")) == 0 {
            self_[0].writenl = ptr[u8]();
        }
    } else {
        self_[0].writenl = ptr[u8]();
    }
    object_xdecref(old);
    return 0;
}

impl _textiowrapper_set_decoder(
    op: ptr[PyObject], codec_info: ptr[PyObject], errors: ptr[u8]
) -> i32 {
    self_ = textio_record(op).view(1);

    res = io_call_noargs(self_[0].buffer, py_id(_Py_ID_readable));
    if not res {
        return -1;
    }

    r = PyObject_IsTrue(res);
    object_decref(res);
    if r == -1 {
        return -1;
    }

    if r != 1 {
        return 0;
    }

    py_clear(field_slot(op, TEXTIO_DECODER));
    self_[0].decoder = _PyCodecInfo_GetIncrementalDecoder(codec_info, errors);
    if not self_[0].decoder {
        return -1;
    }

    if self_[0].readuniversal != 0 {
        state = self_[0].state.view(1);
        incrementalDecoder = io_call_function(
            ptr[PyObject](state[0].PyIncrementalNewlineDecoder_Type),
            self_[0].decoder,
            io_bool(self_[0].readtranslate != 0),
            NULL,
            NULL,
            2
        );
        if not incrementalDecoder {
            return -1;
        }
        py_xsetref(field_slot(op, TEXTIO_DECODER), incrementalDecoder);
    }

    return 0;
}

impl _textiowrapper_decode(
    state: ptr[IOModuleState], decoder: ptr[PyObject], bytes: ptr[PyObject], eof: bool
) -> ptr[PyObject] {
    chars: ptr[PyObject] = NULL;
    if object_is_type(decoder, state.view(1)[0].PyIncrementalNewlineDecoder_Type) {
        chars = _PyIncrementalNewlineDecoder_decode(
            decoder, bytes, i32(1) if eof else i32(0)
        );
    } else {
        chars = io_call_twoargs(decoder, py_id(_Py_ID_decode), bytes, io_bool(eof));
    }

    if check_decoded(chars) < 0 {
        return NULL;
    }

    return chars;
}

impl _textiowrapper_set_encoder(
    op: ptr[PyObject], codec_info: ptr[PyObject], errors: ptr[u8]
) -> i32 {
    self_ = textio_record(op).view(1);
    res = io_call_noargs(self_[0].buffer, py_id(_Py_ID_writable));
    if not res {
        return -1;
    }

    r = PyObject_IsTrue(res);
    object_decref(res);
    if r == -1 {
        return -1;
    }

    if r != 1 {
        return 0;
    }

    py_clear(field_slot(op, TEXTIO_ENCODER));
    self_[0].encodefunc = ENCODE_NONE;
    self_[0].encoder = _PyCodecInfo_GetIncrementalEncoder(codec_info, errors);
    if not self_[0].encoder {
        return -1;
    }

    name: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(codec_info, py_id(_Py_ID_name), &mut name) < 0 {
        return -1;
    }
    if name and unicode_check(name) {
        self_[0].encodefunc = encodefunc_of(name);
    }
    object_xdecref(name);
    return 0;
}

impl _textiowrapper_fix_encoder_state(op: ptr[PyObject]) -> i32 {
    self_ = textio_record(op).view(1);
    if self_[0].seekable == 0 or not self_[0].encoder {
        return 0;
    }

    self_[0].encoding_start_of_stream = 1;

    cookieObj = io_call_noargs(self_[0].buffer, py_id(_Py_ID_tell));
    if not cookieObj {
        return -1;
    }

    cmp = PyObject_RichCompareBool(cookieObj, long_zero(), Py_EQ);
    object_decref(cookieObj);
    if cmp < 0 {
        return -1;
    }

    if cmp == 0 {
        self_[0].encoding_start_of_stream = 0;
        res = io_call_onearg(self_[0].encoder, py_id(_Py_ID_setstate), long_zero());
        if not res {
            return -1;
        }
        object_decref(res);
    }

    return 0;
}

impl io_check_errors(errors: ptr[PyObject]) -> i32 {
    interp = current_interp();

    if ptr[i32](_Py_GetConfig() + PyConfig_DEV_MODE).view(1)[0] == 0 {
        return 0;
    }

    if not fs_codec_encoding(interp) {
        return 0;
    }

    name = _PyUnicode_AsUTF8NoNUL(errors);
    if not name {
        return -1;
    }
    handler = PyCodec_LookupError(name);
    if handler {
        object_decref(handler);
        return 0;
    }
    return -1;
}

impl _io_TextIOWrapper___init___impl(
    op: ptr[PyObject],
    buffer: ptr[PyObject],
    encoding: ptr[u8],
    errors: ptr[PyObject],
    newline: ptr[u8],
    line_buffering: bool,
    write_through: bool
) -> i32 {
    self_ = textio_record(op).view(1);
    codec_info: ptr[PyObject] = NULL;

    self_[0].ok = 0;
    self_[0].detached = 0;

    if not encoding {
        if ptr[i32](_Py_GetConfig() + PyConfig_WARN_DEFAULT_ENCODING).view(1)[0] != 0 {
            if PyErr_WarnEx(
                PyExc_EncodingWarning, ptr[u8]("'encoding' argument not specified"), 1
            )
                != 0 {
                return -1;
            }
        }
    }

    if errors == Py_None {
        errors = py_id(_Py_ID_strict);
    } elif not unicode_check(errors) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("TextIOWrapper() argument 'errors' must be str or None, not %.50s"),
            object_type(errors).view(1)[0].tp_name
        );
        return -1;
    } elif io_check_errors(errors) != 0 {
        return -1;
    }
    errors_str = _PyUnicode_AsUTF8NoNUL(errors);
    if not errors_str {
        return -1;
    }

    if validate_newline(newline) < 0 {
        return -1;
    }

    py_clear(field_slot(op, TEXTIO_BUFFER));
    py_clear(field_slot(op, TEXTIO_ENCODING));
    py_clear(field_slot(op, TEXTIO_ENCODER));
    py_clear(field_slot(op, TEXTIO_DECODER));
    py_clear(field_slot(op, TEXTIO_READNL));
    py_clear(field_slot(op, TEXTIO_DECODED_CHARS));
    py_clear(field_slot(op, TEXTIO_PENDING_BYTES));
    py_clear(field_slot(op, TEXTIO_SNAPSHOT));
    py_clear(field_slot(op, TEXTIO_ERRORS));
    py_clear(field_slot(op, TEXTIO_RAW));
    self_[0].decoded_chars_used = 0;
    self_[0].pending_bytes_count = 0;
    self_[0].encodefunc = ENCODE_NONE;
    self_[0].b2cratio = 0.0;

    utf8_mode = ptr[i32](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_PRECONFIG_UTF8_MODE
    ).view(
        1
    )[0];
    if not encoding and utf8_mode != 0 {
        self_[0].encoding = py_id(_Py_STR_utf_8);
    } elif not encoding or strcmp(encoding, ptr[u8]("locale")) == 0 {
        self_[0].encoding = _Py_GetLocaleEncodingObject();
        if not self_[0].encoding {
            return -1;
        }
    }

    if self_[0].encoding {
        encoding = PyUnicode_AsUTF8(self_[0].encoding);
        if not encoding {
            return -1;
        }
    } elif encoding {
        self_[0].encoding = PyUnicode_FromString(encoding);
        if not self_[0].encoding {
            return -1;
        }
    } else {
        PyErr_SetString(PyExc_OSError, ptr[u8]("could not determine default encoding"));
        return -1;
    }

    codec_info = _PyCodec_LookupTextEncoding(encoding, ptr[u8]());
    if not codec_info {
        py_clear(field_slot(op, TEXTIO_ENCODING));
        return -1;
    }

    self_[0].errors = object_new_ref(errors);
    self_[0].chunk_size = 8192;
    self_[0].line_buffering = i8(1) if line_buffering else i8(0);
    self_[0].write_through = i8(1) if write_through else i8(0);
    if set_newline(op, newline) < 0 {
        object_decref(codec_info);
        return -1;
    }

    self_[0].buffer = object_new_ref(buffer);

    state = find_io_state_by_def(object_type(op));
    self_[0].state = state;
    if _textiowrapper_set_decoder(op, codec_info, errors_str) != 0 {
        object_decref(codec_info);
        return -1;
    }

    if _textiowrapper_set_encoder(op, codec_info, errors_str) != 0 {
        object_decref(codec_info);
        return -1;
    }

    object_decref(codec_info);

    st = state.view(1);
    if object_is_type(buffer, st[0].PyBufferedReader_Type)
        or object_is_type(buffer, st[0].PyBufferedWriter_Type)
        or object_is_type(buffer, st[0].PyBufferedRandom_Type) {
        raw: ptr[PyObject] = NULL;
        if PyObject_GetOptionalAttr(buffer, py_id(_Py_ID_raw), &mut raw) < 0 {
            return -1;
        }

        if raw {
            if object_is_type(raw, st[0].PyFileIO_Type) {
                self_[0].raw = raw;
            } else {
                object_decref(raw);
            }
        }
    }

    res = io_call_noargs(buffer, py_id(_Py_ID_seekable));
    if not res {
        return -1;
    }
    r = PyObject_IsTrue(res);
    object_decref(res);
    if r < 0 {
        return -1;
    }
    self_[0].seekable = i8.wrap(r);
    self_[0].telling = i8.wrap(r);

    r = PyObject_HasAttrWithError(buffer, py_id(_Py_ID_read1));
    if r < 0 {
        return -1;
    }
    self_[0].has_read1 = i8.wrap(r);

    self_[0].encoding_start_of_stream = 0;
    if _textiowrapper_fix_encoder_state(op) < 0 {
        return -1;
    }

    self_[0].ok = 1;
    return 0;
}

impl convert_optional_bool(obj_: ptr[PyObject], default_value: i32) -> i32 {
    v: i64 = 0;
    if obj_ == Py_None {
        v = i64(default_value);
    } else {
        v = PyLong_AsLong(obj_);
        if v == -1 and PyErr_Occurred() {
            return -1;
        }
    }
    return i32(1) if v != 0 else i32(0);
}

impl textiowrapper_change_encoding(
    op: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    newline_changed: bool
) -> i32 {
    self_ = textio_record(op).view(1);

    if encoding == Py_None and errors == Py_None and not newline_changed {
        return 0;
    }

    if encoding == Py_None {
        encoding = self_[0].encoding;
        if errors == Py_None {
            errors = self_[0].errors;
        }
        object_incref(encoding);
    } else {
        if _PyUnicode_EqualToASCIIString(encoding, ptr[u8]("locale")) != 0 {
            encoding = _Py_GetLocaleEncodingObject();
            if not encoding {
                return -1;
            }
        } else {
            object_incref(encoding);
        }
        if errors == Py_None {
            errors = py_id(_Py_ID_strict);
        }
    }
    object_incref(errors);

    c_encoding = PyUnicode_AsUTF8(encoding);
    if not c_encoding {
        object_decref(encoding);
        object_decref(errors);
        return -1;
    }
    c_errors = PyUnicode_AsUTF8(errors);
    if not c_errors {
        object_decref(encoding);
        object_decref(errors);
        return -1;
    }

    codec_info = _PyCodec_LookupTextEncoding(c_encoding, ptr[u8]());
    if not codec_info {
        object_decref(encoding);
        object_decref(errors);
        return -1;
    }
    if _textiowrapper_set_decoder(op, codec_info, c_errors) != 0
        or _textiowrapper_set_encoder(op, codec_info, c_errors) != 0 {
        object_decref(codec_info);
        object_decref(encoding);
        object_decref(errors);
        return -1;
    }
    object_decref(codec_info);

    py_xsetref(field_slot(op, TEXTIO_ENCODING), encoding);
    py_xsetref(field_slot(op, TEXTIO_ERRORS), errors);

    return _textiowrapper_fix_encoder_state(op);
}

impl _io_TextIOWrapper_reconfigure_impl(
    op: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject],
    newline_obj: ptr[PyObject],
    line_buffering_obj: ptr[PyObject],
    write_through_obj: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    newline = ptr[u8]();

    if encoding != Py_None and not unicode_check(encoding) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("reconfigure() argument 'encoding' must be str or None, not %s"),
            object_type(encoding).view(1)[0].tp_name
        );
        return NULL;
    }
    if errors != Py_None and not unicode_check(errors) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("reconfigure() argument 'errors' must be str or None, not %s"),
            object_type(errors).view(1)[0].tp_name
        );
        return NULL;
    }
    if newline_obj and newline_obj != Py_None and not unicode_check(newline_obj) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("reconfigure() argument 'newline' must be str or None, not %s"),
            object_type(newline_obj).view(1)[0].tp_name
        );
        return NULL;
    }

    if self_[0].decoded_chars {
        if encoding != Py_None or errors != Py_None or newline_obj {
            _unsupported(
                self_[0].state,
                ptr[u8](
                    "It is not possible to set the encoding or newline of stream after the first read"
                )
            );
            return NULL;
        }
    }

    if newline_obj and newline_obj != Py_None {
        newline = PyUnicode_AsUTF8(newline_obj);
        if not newline or validate_newline(newline) < 0 {
            return NULL;
        }
    }

    line_buffering = convert_optional_bool(
        line_buffering_obj, i32(self_[0].line_buffering)
    );
    if line_buffering < 0 {
        return NULL;
    }
    write_through = convert_optional_bool(
        write_through_obj, i32(self_[0].write_through)
    );
    if write_through < 0 {
        return NULL;
    }

    if _PyFile_Flush(op) < 0 {
        return NULL;
    }
    self_[0].b2cratio = 0.0;

    if newline_obj and set_newline(op, newline) < 0 {
        return NULL;
    }

    if textiowrapper_change_encoding(op, encoding, errors, bool(newline_obj)) < 0 {
        return NULL;
    }
    self_[0].line_buffering = i8.wrap(line_buffering);
    self_[0].write_through = i8.wrap(write_through);
    return object_new_ref(Py_None);
}

impl textiowrapper_clear(op: ptr[PyObject]) -> i32 {
    textio_record(op).view(1)[0].ok = 0;
    py_clear(field_slot(op, TEXTIO_BUFFER));
    py_clear(field_slot(op, TEXTIO_ENCODING));
    py_clear(field_slot(op, TEXTIO_ENCODER));
    py_clear(field_slot(op, TEXTIO_DECODER));
    py_clear(field_slot(op, TEXTIO_READNL));
    py_clear(field_slot(op, TEXTIO_DECODED_CHARS));
    py_clear(field_slot(op, TEXTIO_PENDING_BYTES));
    py_clear(field_slot(op, TEXTIO_SNAPSHOT));
    py_clear(field_slot(op, TEXTIO_ERRORS));
    py_clear(field_slot(op, TEXTIO_RAW));
    py_clear(field_slot(op, TEXTIO_DICT));
    return 0;
}

impl textiowrapper_dealloc(op: ptr[PyObject]) {
    self_ = textio_record(op).view(1);
    tp = object_type(op);
    self_[0].finalizing = 1;
    if _PyIOBase_finalize(op) < 0 {
        return;
    }
    self_[0].ok = 0;
    object_gc_untrack(op);
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    textiowrapper_clear(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl textiowrapper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_BUFFER).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_ENCODING).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_ENCODER).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_DECODER).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_READNL).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(
        field_slot(op, TEXTIO_DECODED_CHARS).view(1)[0], visitor, arg
    );
    if status != 0 {
        return status;
    }
    status = visit_reference(
        field_slot(op, TEXTIO_PENDING_BYTES).view(1)[0], visitor, arg
    );
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_SNAPSHOT).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_ERRORS).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_RAW).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(field_slot(op, TEXTIO_DICT).view(1)[0], visitor, arg);
    if status != 0 {
        return status;
    }
    return 0;
}

impl check_closed(op: ptr[PyObject]) -> bool {
    self_ = textio_record(op).view(1);
    if object_is_type(op, self_[0].state.view(1)[0].PyTextIOWrapper_Type) {
        r: i32 = 0;
        if self_[0].raw {
            r = _PyFileIO_closed(self_[0].raw);
        } else {
            res = _io_TextIOWrapper_closed_get_impl(op);
            if not res {
                return False;
            }
            r = PyObject_IsTrue(res);
            object_decref(res);
            if r < 0 {
                return False;
            }
        }
        if r > 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file."));
            return False;
        }
    } elif not _PyIOBase_check_closed(op, io_true()) {
        return False;
    }
    return True;
}

impl check_initialized(op: ptr[PyObject]) -> bool {
    if textio_record(op).view(1)[0].ok <= 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("I/O operation on uninitialized object")
        );
        return False;
    }
    return True;
}

impl check_attached(op: ptr[PyObject]) -> bool {
    if not check_initialized(op) {
        return False;
    }
    if textio_record(op).view(1)[0].detached != 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("underlying buffer has been detached")
        );
        return False;
    }
    return True;
}

impl _io_TextIOWrapper_detach_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    if not check_attached(op) {
        return NULL;
    }
    if _PyFile_Flush(op) < 0 {
        return NULL;
    }
    buffer = self_[0].buffer;
    self_[0].buffer = NULL;
    self_[0].detached = 1;
    return buffer;
}

impl _textiowrapper_writeflush(op: ptr[PyObject]) -> i32 {
    self_ = textio_record(op).view(1);
    if not self_[0].pending_bytes {
        return 0;
    }

    pending = self_[0].pending_bytes;
    b: ptr[PyObject] = NULL;

    if bytes_check(pending) {
        b = object_new_ref(pending);
    } elif unicode_check(pending) {
        b = PyBytes_FromStringAndSize(uo_data(pending), unicode_length(pending));
        if not b {
            return -1;
        }
    } else {
        b = PyBytes_FromStringAndSize(ptr[u8](), self_[0].pending_bytes_count);
        if not b {
            return -1;
        }
        buf = bytes_data(b);
        pos: i64 = 0;
        count = object_size(pending);
        items = ptr[PyListObject](pending).view(1)[0].ob_item;
        for i in range(count) {
            item = items.view(count)[i];
            src = ptr[u8]();
            len: i64 = 0;
            if unicode_check(item) {
                src = uo_data(item);
                len = unicode_length(item);
            } else {
                if PyBytes_AsStringAndSize(item, &mut src, &mut len) < 0 {
                    object_decref(b);
                    return -1;
                }
            }
            memcpy(ptr(buf + pos), ptr(src), u64(len));
            pos += len;
        }
    }

    self_[0].pending_bytes_count = 0;
    self_[0].pending_bytes = NULL;
    object_decref(pending);

    ret: ptr[PyObject] = NULL;
    while True {
        ret = io_call_onearg(self_[0].buffer, py_id(_Py_ID_write), b);
        if ret or _PyIO_trap_eintr() == 0 {
            break;
        }
    }
    object_decref(b);

    if not ret {
        return -1;
    }
    object_decref(ret);
    return 0;
}

impl _io_TextIOWrapper_write_impl(
    op: ptr[PyObject], text: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    b: ptr[PyObject] = NULL;
    haslf = False;
    needflush = False;
    text_needflush = False;

    if not check_attached(op) {
        return NULL;
    }
    if not check_closed(op) {
        return NULL;
    }

    if not self_[0].encoder {
        return _unsupported(self_[0].state, ptr[u8]("not writable"));
    }

    object_incref(text);

    textlen = unicode_length(text);

    if (self_[0].writetranslate != 0 and self_[0].writenl)
        or self_[0].line_buffering != 0 {
        if PyUnicode_FindChar(text, u32(10), 0, unicode_length(text), 1) != -1 {
            haslf = True;
        }
    }

    if haslf and self_[0].writetranslate != 0 and self_[0].writenl {
        writenl = PyUnicode_FromString(self_[0].writenl);
        newtext: ptr[PyObject] = NULL;
        if writenl {
            newtext = io_call_twoargs(
                text, py_id(_Py_ID_replace), latin1_char(10), writenl
            );
            object_decref(writenl);
        }
        object_decref(text);
        if not newtext {
            return NULL;
        }
        text = newtext;
    }

    if self_[0].write_through != 0 {
        text_needflush = True;
    }
    if self_[0].line_buffering != 0
        and (
            haslf or PyUnicode_FindChar(text, u32(13), 0, unicode_length(text), 1) != -1
        ) {
        needflush = True;
    }

    if self_[0].encodefunc != ENCODE_NONE {
        if uo_is_ascii(text)
            and unicode_length(text) <= self_[0].chunk_size
            and is_asciicompat_encoding(self_[0].encodefunc) {
            b = object_new_ref(text);
        } else {
            b = encode_text(op, text);
        }
        self_[0].encoding_start_of_stream = 0;
    } else {
        b = io_call_onearg(self_[0].encoder, py_id(_Py_ID_encode), text);
    }

    object_decref(text);
    if not b {
        return NULL;
    }
    if b != text and not bytes_check(b) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("encoder should return a bytes object, not '%.200s'"),
            object_type(b).view(1)[0].tp_name
        );
        object_decref(b);
        return NULL;
    }

    bytes_len: i64 = 0;
    if b == text {
        bytes_len = unicode_length(b);
    } else {
        bytes_len = object_size(b);
    }

    if bytes_len >= self_[0].chunk_size {
        while self_[0].pending_bytes {
            if _textiowrapper_writeflush(op) < 0 {
                object_decref(b);
                return NULL;
            }
        }
    }

    if not self_[0].pending_bytes {
        self_[0].pending_bytes = b;
    } elif not object_is_type(
        self_[0].pending_bytes, ptr[PyTypeObject](addressof(PyList_Type))
    ) {
        lst = PyList_New(2);
        if not lst {
            object_decref(b);
            return NULL;
        }
        items = ptr[PyListObject](lst).view(1)[0].ob_item;
        items.view(2)[0] = self_[0].pending_bytes;
        items.view(2)[1] = b;
        self_[0].pending_bytes = lst;
    } else {
        if PyList_Append(self_[0].pending_bytes, b) < 0 {
            object_decref(b);
            return NULL;
        }
        object_decref(b);
    }

    self_[0].pending_bytes_count += bytes_len;
    if self_[0].pending_bytes_count >= self_[0].chunk_size
        or needflush
        or text_needflush {
        if _textiowrapper_writeflush(op) < 0 {
            return NULL;
        }
    }

    if needflush {
        if _PyFile_Flush(self_[0].buffer) < 0 {
            return NULL;
        }
    }

    if self_[0].snapshot {
        textiowrapper_set_decoded_chars(op, NULL);
        py_clear(field_slot(op, TEXTIO_SNAPSHOT));
    }

    if self_[0].decoder {
        ret = io_call_noargs(self_[0].decoder, py_id(_Py_ID_reset));
        if not ret {
            return NULL;
        }
        object_decref(ret);
    }

    return PyLong_FromSsize_t(textlen);
}

impl textiowrapper_set_decoded_chars(op: ptr[PyObject], chars: ptr[PyObject]) {
    py_xsetref(field_slot(op, TEXTIO_DECODED_CHARS), chars);
    textio_record(op).view(1)[0].decoded_chars_used = 0;
}

impl textiowrapper_get_decoded_chars(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    chars: ptr[PyObject] = NULL;

    if not self_[0].decoded_chars {
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }

    avail = unicode_length(self_[0].decoded_chars) - self_[0].decoded_chars_used;

    if n < 0 or n > avail {
        n = avail;
    }

    if self_[0].decoded_chars_used > 0 or n < avail {
        chars = PyUnicode_Substring(
            self_[0].decoded_chars,
            self_[0].decoded_chars_used,
            self_[0].decoded_chars_used + n
        );
        if not chars {
            return NULL;
        }
    } else {
        chars = object_new_ref(self_[0].decoded_chars);
    }

    self_[0].decoded_chars_used += n;
    return chars;
}

impl decoder_state_pair(
    state: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], ptr[PyObject]] {
    if object_size(state) != 2 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
        return (False, NULL, NULL);
    }
    return (True, tuple_get_item(state, 0), tuple_get_item(state, 1));
}

impl getargs_int(value: ptr[PyObject]) -> tuple[bool, i32] {
    ival = PyLong_AsLong(value);
    if ival == -1 and PyErr_Occurred() {
        return (False, i32(0));
    }
    if ival > INT_MAX {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is greater than maximum")
        );
        return (False, i32(0));
    }
    if ival < INT_MIN {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is less than minimum")
        );
        return (False, i32(0));
    }
    return (True, i32(ival));
}

impl read_chunk_failed(
    dec_buffer: ptr[PyObject], dec_flags: ptr[PyObject], input_chunk: ptr[PyObject]
) -> i32 {
    object_xdecref(dec_buffer);
    object_xdecref(dec_flags);
    object_xdecref(input_chunk);
    return -1;
}

impl textiowrapper_read_chunk(op: ptr[PyObject], size_hint: i64) -> i32 {
    self_ = textio_record(op).view(1);
    dec_buffer: ptr[PyObject] = NULL;
    dec_flags: ptr[PyObject] = NULL;
    input_chunk: ptr[PyObject] = NULL;

    if not self_[0].decoder {
        _unsupported(self_[0].state, ptr[u8]("not readable"));
        return -1;
    }

    if self_[0].telling != 0 {
        state = io_call_noargs(self_[0].decoder, py_id(_Py_ID_getstate));
        if not state {
            return -1;
        }

        if not tuple_check(state) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
            object_decref(state);
            return -1;
        }
        (parsed, first, second) = decoder_state_pair(state);
        if not parsed {
            object_decref(state);
            return -1;
        }

        if not bytes_check(first) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "illegal decoder state: the first item should be a bytes object, not '%.200s'"
                ),
                object_type(first).view(1)[0].tp_name
            );
            object_decref(state);
            return -1;
        }

        dec_buffer = object_new_ref(first);
        dec_flags = object_new_ref(second);
        object_decref(state);
    }

    if size_hint > 0 {
        ratio = self_[0].b2cratio;
        if ratio < 1.0 {
            ratio = 1.0;
        }
        size_hint = i64(ratio * f64(size_hint));
    }
    wanted = self_[0].chunk_size;
    if size_hint > wanted {
        wanted = size_hint;
    }
    chunk_size = PyLong_FromSsize_t(wanted);
    if not chunk_size {
        return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
    }

    input_chunk = io_call_onearg(
        self_[0].buffer,
        py_id(_Py_ID_read1) if self_[0].has_read1 != 0 else py_id(_Py_ID_read),
        chunk_size
    );
    object_decref(chunk_size);
    if not input_chunk {
        return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
    }

    slots: own IOStack = IOStack();
    input_chunk_buf = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(input_chunk, input_chunk_buf, 0) != 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "underlying %s() should have returned a bytes-like object, not '%.200s'"
            ),
            ptr[u8]("read1") if self_[0].has_read1 != 0 else ptr[u8]("read"),
            object_type(input_chunk).view(1)[0].tp_name
        );
        return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
    }

    nbytes = input_chunk_buf.view(1)[0].length;
    eof = nbytes == 0;

    decoded_chars = _textiowrapper_decode(
        self_[0].state, self_[0].decoder, input_chunk, eof
    );
    PyBuffer_Release(input_chunk_buf);

    if not decoded_chars {
        return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
    }

    textiowrapper_set_decoded_chars(op, decoded_chars);
    nchars = unicode_length(decoded_chars);
    if nchars > 0 {
        self_[0].b2cratio = f64(nbytes) / f64(nchars);
    } else {
        self_[0].b2cratio = 0.0;
    }
    if nchars > 0 {
        eof = False;
    }

    if self_[0].telling != 0 {
        next_input = dec_buffer;
        PyBytes_Concat(&mut next_input, input_chunk);

        dec_buffer = NULL;
        if not next_input {
            return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
        }
        snapshot = Py_BuildValue(ptr[u8]("NN"), dec_flags, next_input);
        if not snapshot {
            dec_flags = NULL;
            return read_chunk_failed(dec_buffer, dec_flags, input_chunk);
        }
        py_xsetref(field_slot(op, TEXTIO_SNAPSHOT), snapshot);
    }
    object_decref(input_chunk);

    return i32(1) if not eof else i32(0);
}

impl read_failed(result: ptr[PyObject], chunks: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(result);
    object_xdecref(chunks);
    return NULL;
}

impl _io_TextIOWrapper_read_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    result: ptr[PyObject] = NULL;
    chunks: ptr[PyObject] = NULL;

    if not check_attached(op) {
        return NULL;
    }
    if not check_closed(op) {
        return NULL;
    }

    if not self_[0].decoder {
        return _unsupported(self_[0].state, ptr[u8]("not readable"));
    }

    if _textiowrapper_writeflush(op) < 0 {
        return NULL;
    }

    if n < 0 {
        bytes = io_call_noargs(self_[0].buffer, py_id(_Py_ID_read));
        decoded: ptr[PyObject] = NULL;
        if not bytes {
            return read_failed(result, chunks);
        }

        if bytes == Py_None {
            object_decref(bytes);
            PyErr_SetString(PyExc_BlockingIOError, ptr[u8]("Read returned None."));
            return NULL;
        }

        state = self_[0].state;
        if object_is_type(
            self_[0].decoder, state.view(1)[0].PyIncrementalNewlineDecoder_Type
        ) {
            decoded = _PyIncrementalNewlineDecoder_decode(self_[0].decoder, bytes, 1);
        } else {
            decoded = io_call_twoargs(
                self_[0].decoder, py_id(_Py_ID_decode), bytes, io_true()
            );
        }
        object_decref(bytes);
        if check_decoded(decoded) < 0 {
            return read_failed(result, chunks);
        }

        result = textiowrapper_get_decoded_chars(op, -1);

        if not result {
            object_decref(decoded);
            return NULL;
        }

        PyUnicode_AppendAndDel(&mut result, decoded);
        if not result {
            return read_failed(result, chunks);
        }

        if self_[0].snapshot {
            textiowrapper_set_decoded_chars(op, NULL);
            py_clear(field_slot(op, TEXTIO_SNAPSHOT));
        }
        return result;
    }

    res: i32 = 1;
    remaining = n;

    result = textiowrapper_get_decoded_chars(op, n);
    if not result {
        return read_failed(result, chunks);
    }
    remaining -= unicode_length(result);

    while remaining > 0 {
        res = textiowrapper_read_chunk(op, remaining);
        if res < 0 {
            if _PyIO_trap_eintr() != 0 {
                continue;
            }
            return read_failed(result, chunks);
        }
        if res == 0 {
            break;
        }
        if not chunks {
            chunks = PyList_New(0);
            if not chunks {
                return read_failed(result, chunks);
            }
        }
        if unicode_length(result) > 0 and PyList_Append(chunks, result) < 0 {
            return read_failed(result, chunks);
        }
        object_decref(result);
        result = textiowrapper_get_decoded_chars(op, remaining);
        if not result {
            return read_failed(result, chunks);
        }
        remaining -= unicode_length(result);
    }
    if chunks {
        if result and PyList_Append(chunks, result) < 0 {
            return read_failed(result, chunks);
        }
        joined = PyUnicode_Join(py_id(_Py_STR_empty), chunks);
        object_xdecref(result);
        result = joined;
        if not result {
            return read_failed(result, chunks);
        }
        object_decref(chunks);
    }
    return result;
}

impl find_control_char(kind: i64, s: ptr[u8], end: ptr[u8], ch: u32) -> ptr[u8] {
    if kind == UCS1_KIND {
        return ptr[u8](memchr(ptr(s), i32(ch), u64(int(end) - int(s))));
    }
    while True {
        while ch_read(kind, s, 0) > ch {
            s = s + kind;
        }
        if ch_read(kind, s, 0) == ch {
            return s;
        }
        if s == end {
            return ptr[u8]();
        }
        s = s + kind;
    }
    return ptr[u8]();
}

impl char_distance(start: ptr[u8], stop: ptr[u8], kind: i64) -> i64 {
    return i64(int(stop) - int(start)) // kind;
}

impl readline_failed(
    chunks: ptr[PyObject], remaining: ptr[PyObject], line: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(chunks);
    object_xdecref(remaining);
    object_xdecref(line);
    return NULL;
}

impl _textiowrapper_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    line: ptr[PyObject] = NULL;
    chunks: ptr[PyObject] = NULL;
    remaining: ptr[PyObject] = NULL;
    start: i64 = 0;
    endpos: i64 = 0;
    offset_to_buffer: i64 = 0;
    res: i32 = 0;

    if not check_closed(op) {
        return NULL;
    }

    if _textiowrapper_writeflush(op) < 0 {
        return NULL;
    }

    slots: own IOStack = IOStack();
    consumed = ptr[i64](jacpy_stack_address(&mut slots));
    chunked: i64 = 0;

    while True {
        consumed.view(1)[0] = 0;

        res = 1;
        while not self_[0].decoded_chars
            or unicode_length(self_[0].decoded_chars) == 0 {
            res = textiowrapper_read_chunk(op, 0);
            if res < 0 {
                if _PyIO_trap_eintr() != 0 {
                    continue;
                }
                return readline_failed(chunks, remaining, line);
            }
            if res == 0 {
                break;
            }
        }
        if res == 0 {
            textiowrapper_set_decoded_chars(op, NULL);
            py_clear(field_slot(op, TEXTIO_SNAPSHOT));
            start = 0;
            endpos = 0;
            offset_to_buffer = 0;
            break;
        }

        if not remaining {
            line = object_new_ref(self_[0].decoded_chars);
            start = self_[0].decoded_chars_used;
            offset_to_buffer = 0;
        } else {
            line = PyUnicode_Concat(remaining, self_[0].decoded_chars);
            start = 0;
            offset_to_buffer = unicode_length(remaining);
            object_decref(remaining);
            remaining = NULL;
            if not line {
                return readline_failed(chunks, remaining, line);
            }
        }

        data = uo_data(line);
        line_len = unicode_length(line);
        kind = uo_kind(line);

        endpos = _PyIO_find_line_ending(
            i32(self_[0].readtranslate),
            i32(self_[0].readuniversal),
            self_[0].readnl,
            i32(kind),
            data + kind * start,
            data + kind * line_len,
            consumed
        );
        if endpos >= 0 {
            endpos += start;
            if limit >= 0 and (endpos - start) + chunked >= limit {
                endpos = start + limit - chunked;
            }
            break;
        }

        endpos = consumed.view(1)[0] + start;
        if limit >= 0 and (endpos - start) + chunked >= limit {
            endpos = start + limit - chunked;
            break;
        }

        if endpos > start {
            if not chunks {
                chunks = PyList_New(0);
                if not chunks {
                    return readline_failed(chunks, remaining, line);
                }
            }
            s = PyUnicode_Substring(line, start, endpos);
            if not s {
                return readline_failed(chunks, remaining, line);
            }
            if PyList_Append(chunks, s) < 0 {
                object_decref(s);
                return readline_failed(chunks, remaining, line);
            }
            chunked += unicode_length(s);
            object_decref(s);
        }

        if endpos < line_len {
            remaining = PyUnicode_Substring(line, endpos, line_len);
            if not remaining {
                return readline_failed(chunks, remaining, line);
            }
        }
        object_decref(line);
        line = NULL;

        textiowrapper_set_decoded_chars(op, NULL);
    }

    if line {
        self_[0].decoded_chars_used = endpos - offset_to_buffer;
        if start > 0 or endpos < unicode_length(line) {
            s = PyUnicode_Substring(line, start, endpos);
            object_decref(line);
            line = NULL;
            if not s {
                return readline_failed(chunks, remaining, line);
            }
            line = s;
        }
    }
    if remaining {
        if not chunks {
            chunks = PyList_New(0);
            if not chunks {
                return readline_failed(chunks, remaining, line);
            }
        }
        if PyList_Append(chunks, remaining) < 0 {
            return readline_failed(chunks, remaining, line);
        }
        object_decref(remaining);
        remaining = NULL;
    }
    if chunks {
        if line {
            if PyList_Append(chunks, line) < 0 {
                return readline_failed(chunks, remaining, line);
            }
            object_decref(line);
        }
        line = PyUnicode_Join(py_id(_Py_STR_empty), chunks);
        if not line {
            return readline_failed(chunks, remaining, line);
        }
        object_decref(chunks);
        chunks = NULL;
    }
    if not line {
        line = py_id(_Py_STR_empty);
    }

    return line;
}

impl _io_TextIOWrapper_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return _textiowrapper_readline(op, size);
}

impl textiowrapper_parse_cookie(
    cookieObj: ptr[PyObject]
) -> tuple[i32, i64, i32, i32, i32, u8] {
    slots: own IOStack = IOStack();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));
    cookieLong = PyNumber_Long(cookieObj);
    if not cookieLong {
        return (i32(-1), i64(0), i32(0), i32(0), i32(0), u8(0));
    }

    if _PyLong_AsByteArray(cookieLong, buffer, COOKIE_BUF_LEN, 1, 0, 1) < 0 {
        object_decref(cookieLong);
        return (i32(-1), i64(0), i32(0), i32(0), i32(0), u8(0));
    }
    object_decref(cookieLong);

    return (
        i32(0),
        ptr[i64](buffer).view(1)[0],
        ptr[i32](buffer + OFF_DEC_FLAGS).view(1)[0],
        ptr[i32](buffer + OFF_BYTES_TO_FEED).view(1)[0],
        ptr[i32](buffer + OFF_CHARS_TO_SKIP).view(1)[0],
        (buffer + OFF_NEED_EOF).view(1)[0]
    );
}

impl textiowrapper_build_cookie(
    start_pos: i64, dec_flags: i32, bytes_to_feed: i32, chars_to_skip: i32, need_eof: u8
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));
    ptr[i64](buffer).view(1)[0] = start_pos;
    ptr[i32](buffer + OFF_DEC_FLAGS).view(1)[0] = dec_flags;
    ptr[i32](buffer + OFF_BYTES_TO_FEED).view(1)[0] = bytes_to_feed;
    ptr[i32](buffer + OFF_CHARS_TO_SKIP).view(1)[0] = chars_to_skip;
    (buffer + OFF_NEED_EOF).view(1)[0] = need_eof;

    return _PyLong_FromByteArray(buffer, COOKIE_BUF_LEN, 1, 0);
}

impl _textiowrapper_decoder_setstate(
    op: ptr[PyObject], start_pos: i64, dec_flags: i32
) -> i32 {
    decoder = textio_record(op).view(1)[0].decoder;
    res: ptr[PyObject] = NULL;

    if start_pos == 0 and dec_flags == 0 {
        res = io_call_noargs(decoder, py_id(_Py_ID_reset));
    } else {
        state = Py_BuildValue(ptr[u8]("(yi)"), ptr[u8](""), dec_flags);
        if not state {
            return -1;
        }
        res = io_call_onearg(decoder, py_id(_Py_ID_setstate), state);
        object_decref(state);
    }
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl _textiowrapper_encoder_reset(op: ptr[PyObject], start_of_stream: bool) -> i32 {
    self_ = textio_record(op).view(1);
    res: ptr[PyObject] = NULL;
    if start_of_stream {
        res = io_call_noargs(self_[0].encoder, py_id(_Py_ID_reset));
        self_[0].encoding_start_of_stream = 1;
    } else {
        res = io_call_onearg(self_[0].encoder, py_id(_Py_ID_setstate), long_zero());
        self_[0].encoding_start_of_stream = 0;
    }
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl _textiowrapper_encoder_setstate(
    op: ptr[PyObject], start_pos: i64, dec_flags: i32
) -> i32 {
    return _textiowrapper_encoder_reset(op, start_pos == 0 and dec_flags == 0);
}

impl seek_failed(cookieObj: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(cookieObj);
    return NULL;
}

impl _io_TextIOWrapper_seek_impl(
    op: ptr[PyObject], cookieObj: ptr[PyObject], whence: i32
) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    res: ptr[PyObject] = NULL;
    cmp: i32 = 0;

    if not check_attached(op) {
        return NULL;
    }
    if not check_closed(op) {
        return NULL;
    }

    object_incref(cookieObj);

    if self_[0].seekable == 0 {
        _unsupported(self_[0].state, ptr[u8]("underlying stream is not seekable"));
        return seek_failed(cookieObj);
    }

    zero = long_zero();

    if whence == SEEK_CUR {
        cmp = PyObject_RichCompareBool(cookieObj, zero, Py_EQ);
        if cmp < 0 {
            return seek_failed(cookieObj);
        }

        if cmp == 0 {
            _unsupported(
                self_[0].state, ptr[u8]("can't do nonzero cur-relative seeks")
            );
            return seek_failed(cookieObj);
        }

        object_decref(cookieObj);
        cookieObj = io_call_noargs(op, py_id(_Py_ID_tell));
        if not cookieObj {
            return seek_failed(cookieObj);
        }
    } elif whence == SEEK_END {
        cmp = PyObject_RichCompareBool(cookieObj, zero, Py_EQ);
        if cmp < 0 {
            return seek_failed(cookieObj);
        }
        if cmp == 0 {
            _unsupported(
                self_[0].state, ptr[u8]("can't do nonzero end-relative seeks")
            );
            return seek_failed(cookieObj);
        }
        if _PyFile_Flush(op) < 0 {
            return seek_failed(cookieObj);
        }
        textiowrapper_set_decoded_chars(op, NULL);
        py_clear(field_slot(op, TEXTIO_SNAPSHOT));
        if self_[0].decoder {
            res = io_call_noargs(self_[0].decoder, py_id(_Py_ID_reset));
            if not res {
                return seek_failed(cookieObj);
            }
            object_decref(res);
        }
        two = PyLong_FromLong(2);
        if not two {
            return seek_failed(cookieObj);
        }
        res = io_call_twoargs(self_[0].buffer, py_id(_Py_ID_seek), zero, two);
        object_decref(two);
        object_decref(cookieObj);
        cookieObj = NULL;
        if not res {
            return seek_failed(cookieObj);
        }
        if self_[0].encoder {
            cmp = PyObject_RichCompareBool(res, zero, Py_EQ);
            if cmp < 0 or _textiowrapper_encoder_reset(op, cmp != 0) != 0 {
                object_decref(res);
                return seek_failed(cookieObj);
            }
        }
        return res;
    } elif whence != SEEK_SET {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("invalid whence (%d, should be %d, %d or %d)"),
            whence,
            i32(SEEK_SET),
            i32(SEEK_CUR),
            i32(SEEK_END)
        );
        return seek_failed(cookieObj);
    }

    cmp = PyObject_RichCompareBool(cookieObj, zero, Py_LT);
    if cmp < 0 {
        return seek_failed(cookieObj);
    }

    if cmp == 1 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("negative seek position %R"), cookieObj);
        return seek_failed(cookieObj);
    }

    if _PyFile_Flush(op) < 0 {
        return seek_failed(cookieObj);
    }

    (parsed, start_pos, dec_flags, bytes_to_feed, chars_to_skip, need_eof) = textiowrapper_parse_cookie(
        cookieObj
    );
    if parsed < 0 {
        return seek_failed(cookieObj);
    }

    posobj = PyLong_FromSsize_t(start_pos);
    if not posobj {
        return seek_failed(cookieObj);
    }
    res = io_call_onearg(self_[0].buffer, py_id(_Py_ID_seek), posobj);
    object_decref(posobj);
    if not res {
        return seek_failed(cookieObj);
    }
    object_decref(res);

    textiowrapper_set_decoded_chars(op, NULL);
    py_clear(field_slot(op, TEXTIO_SNAPSHOT));

    if self_[0].decoder {
        if _textiowrapper_decoder_setstate(op, start_pos, dec_flags) < 0 {
            return seek_failed(cookieObj);
        }
    }

    if chars_to_skip != 0 {
        input_chunk = io_call_ssize(
            self_[0].buffer, py_id(_Py_ID_read), i64(bytes_to_feed)
        );
        if not input_chunk {
            return seek_failed(cookieObj);
        }

        if not bytes_check(input_chunk) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "underlying read() should have returned a bytes object, not '%.200s'"
                ),
                object_type(input_chunk).view(1)[0].tp_name
            );
            object_decref(input_chunk);
            return seek_failed(cookieObj);
        }

        snapshot = Py_BuildValue(ptr[u8]("iN"), dec_flags, input_chunk);
        if not snapshot {
            return seek_failed(cookieObj);
        }
        py_xsetref(field_slot(op, TEXTIO_SNAPSHOT), snapshot);

        decoded = io_call_twoargs(
            self_[0].decoder, py_id(_Py_ID_decode), input_chunk, io_bool(need_eof != 0)
        );

        if check_decoded(decoded) < 0 {
            return seek_failed(cookieObj);
        }

        textiowrapper_set_decoded_chars(op, decoded);

        if PyUnicode_GetLength(self_[0].decoded_chars) < i64(chars_to_skip) {
            PyErr_SetString(
                PyExc_OSError, ptr[u8]("can't restore logical file position")
            );
            return seek_failed(cookieObj);
        }
        self_[0].decoded_chars_used = i64(chars_to_skip);
    } else {
        snapshot = Py_BuildValue(ptr[u8]("iy"), dec_flags, ptr[u8](""));
        if not snapshot {
            return seek_failed(cookieObj);
        }
        py_xsetref(field_slot(op, TEXTIO_SNAPSHOT), snapshot);
    }

    if self_[0].encoder {
        if _textiowrapper_encoder_setstate(op, start_pos, dec_flags) < 0 {
            return seek_failed(cookieObj);
        }
    }
    return cookieObj;
}

impl tell_failed(op: ptr[PyObject], saved_state: ptr[PyObject]) -> ptr[PyObject] {
    if saved_state {
        exc = PyErr_GetRaisedException();
        res = io_call_onearg(
            textio_record(op).view(1)[0].decoder, py_id(_Py_ID_setstate), saved_state
        );
        _PyErr_ChainExceptions1(exc);
        object_decref(saved_state);
        object_xdecref(res);
    }
    return NULL;
}

impl decoder_getstate(op: ptr[PyObject]) -> tuple[i32, i64, i32] {
    state = io_call_noargs(
        textio_record(op).view(1)[0].decoder, py_id(_Py_ID_getstate)
    );
    if not state {
        return (i32(-1), i64(0), i32(0));
    }
    if not tuple_check(state) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
        object_decref(state);
        return (i32(-1), i64(0), i32(0));
    }
    (parsed, dec_buffer, flags_obj) = decoder_state_pair(state);
    if not parsed {
        object_decref(state);
        return (i32(-1), i64(0), i32(0));
    }
    (converted, dec_flags) = getargs_int(flags_obj);
    if not converted {
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal decoder state"));
        }
        object_decref(state);
        return (i32(-1), i64(0), i32(0));
    }
    if not bytes_check(dec_buffer) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "illegal decoder state: the first item should be a bytes object, not '%.200s'"
            ),
            object_type(dec_buffer).view(1)[0].tp_name
        );
        object_decref(state);
        return (i32(-1), i64(0), i32(0));
    }
    dec_buffer_len = object_size(dec_buffer);
    object_decref(state);
    return (i32(0), dec_buffer_len, dec_flags);
}

impl decoder_decode(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64 {
    chunk = PyBytes_FromStringAndSize(start, len);
    if not chunk {
        return -1;
    }
    decoded = io_call_onearg(
        textio_record(op).view(1)[0].decoder, py_id(_Py_ID_decode), chunk
    );
    object_decref(chunk);
    if check_decoded(decoded) < 0 {
        return -1;
    }
    res = unicode_length(decoded);
    object_decref(decoded);
    return res;
}

impl _io_TextIOWrapper_tell_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    start_pos: i64 = 0;
    dec_flags: i32 = 0;
    bytes_to_feed: i32 = 0;
    need_eof: u8 = 0;
    saved_state: ptr[PyObject] = NULL;
    chars_decoded: i64 = 0;

    if not check_attached(op) {
        return NULL;
    }
    if not check_closed(op) {
        return NULL;
    }

    if self_[0].seekable == 0 {
        _unsupported(self_[0].state, ptr[u8]("underlying stream is not seekable"));
        return tell_failed(op, saved_state);
    }
    if self_[0].telling == 0 {
        PyErr_SetString(
            PyExc_OSError, ptr[u8]("telling position disabled by next() call")
        );
        return tell_failed(op, saved_state);
    }

    if _textiowrapper_writeflush(op) < 0 {
        return NULL;
    }
    if _PyFile_Flush(op) < 0 {
        return tell_failed(op, saved_state);
    }

    posobj = io_call_noargs(self_[0].buffer, py_id(_Py_ID_tell));
    if not posobj {
        return tell_failed(op, saved_state);
    }

    if not self_[0].decoder or not self_[0].snapshot {
        return posobj;
    }

    start_pos = PyLong_AsLongLong(posobj);
    object_decref(posobj);
    if PyErr_Occurred() {
        return tell_failed(op, saved_state);
    }

    snapshot = self_[0].snapshot;
    if object_size(snapshot) != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("function takes exactly 2 arguments (%zd given)"),
            object_size(snapshot)
        );
        return tell_failed(op, saved_state);
    }
    (converted, snapshot_flags) = getargs_int(tuple_get_item(snapshot, 0));
    if not converted {
        return tell_failed(op, saved_state);
    }
    dec_flags = snapshot_flags;
    next_input = tuple_get_item(snapshot, 1);

    start_pos -= object_size(next_input);

    if self_[0].decoded_chars_used == 0 {
        return textiowrapper_build_cookie(start_pos, dec_flags, 0, 0, 0);
    }

    chars_to_skip = self_[0].decoded_chars_used;

    saved_state = io_call_noargs(self_[0].decoder, py_id(_Py_ID_getstate));
    if not saved_state {
        return tell_failed(op, saved_state);
    }

    skip_bytes = i64(self_[0].b2cratio * f64(chars_to_skip));
    skip_back: i64 = 1;
    input = bytes_data(next_input);
    while skip_bytes > 0 {
        if _textiowrapper_decoder_setstate(op, start_pos, dec_flags) < 0 {
            return tell_failed(op, saved_state);
        }
        chars_decoded = decoder_decode(op, input, skip_bytes);
        if chars_decoded < 0 {
            return tell_failed(op, saved_state);
        }
        if chars_decoded <= chars_to_skip {
            (status, dec_buffer_len, state_flags) = decoder_getstate(op);
            if status < 0 {
                return tell_failed(op, saved_state);
            }
            if dec_buffer_len == 0 {
                dec_flags = state_flags;
                chars_to_skip -= chars_decoded;
                break;
            }

            skip_bytes -= dec_buffer_len;
            skip_back = 1;
        } else {
            skip_bytes -= skip_back;
            skip_back *= 2;
        }
    }
    if skip_bytes <= 0 {
        skip_bytes = 0;
        if _textiowrapper_decoder_setstate(op, start_pos, dec_flags) < 0 {
            return tell_failed(op, saved_state);
        }
    }

    start_pos += skip_bytes;
    if chars_to_skip != 0 {
        chars_decoded = 0;
        input = bytes_data(next_input);
        input_end = input + object_size(next_input);
        input = input + skip_bytes;
        while int(input) < int(input_end) {
            n = decoder_decode(op, input, 1);
            if n < 0 {
                return tell_failed(op, saved_state);
            }

            chars_decoded += n;
            bytes_to_feed += 1;
            (status, dec_buffer_len, state_flags) = decoder_getstate(op);
            if status < 0 {
                return tell_failed(op, saved_state);
            }

            if dec_buffer_len == 0 and chars_decoded <= chars_to_skip {
                start_pos += i64(bytes_to_feed);
                chars_to_skip -= chars_decoded;
                dec_flags = state_flags;
                bytes_to_feed = 0;
                chars_decoded = 0;
            }
            if chars_decoded >= chars_to_skip {
                break;
            }
            input = input + 1;
        }
        if input == input_end {
            decoded = io_call_twoargs(
                self_[0].decoder, py_id(_Py_ID_decode), bytes_get_empty(), io_true()
            );
            if check_decoded(decoded) < 0 {
                return tell_failed(op, saved_state);
            }
            chars_decoded += unicode_length(decoded);
            object_decref(decoded);
            need_eof = 1;
            if chars_decoded < chars_to_skip {
                PyErr_SetString(
                    PyExc_OSError, ptr[u8]("can't reconstruct logical file position")
                );
                return tell_failed(op, saved_state);
            }
        }
    }

    res = io_call_onearg(self_[0].decoder, py_id(_Py_ID_setstate), saved_state);
    object_decref(saved_state);
    if not res {
        return NULL;
    }
    object_decref(res);

    return textiowrapper_build_cookie(
        start_pos, dec_flags, bytes_to_feed, i32.wrap(chars_to_skip), need_eof
    );
}

impl _io_TextIOWrapper_truncate_impl(
    op: ptr[PyObject], pos: ptr[PyObject]
) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }

    if _PyFile_Flush(op) < 0 {
        return NULL;
    }

    return io_call_onearg(
        textio_record(op).view(1)[0].buffer, py_id(_Py_ID_truncate), pos
    );
}

impl repr_failed(res: ptr[PyObject], status: i32, op: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(res);
    if status == 0 {
        Py_ReprLeave(op);
    }
    return NULL;
}

impl textiowrapper_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    nameobj: ptr[PyObject] = NULL;
    modeobj: ptr[PyObject] = NULL;
    type_name = object_type(op).view(1)[0].tp_name;

    if not check_initialized(op) {
        return NULL;
    }

    res = PyUnicode_FromFormat("<%.100s", type_name);
    if not res {
        return NULL;
    }

    status = Py_ReprEnter(op);
    if status != 0 {
        if status > 0 {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8]("reentrant call inside %.100s.__repr__"),
                type_name
            );
        }
        return repr_failed(res, status, op);
    }
    if PyObject_GetOptionalAttr(op, py_id(_Py_ID_name), &mut nameobj) < 0 {
        if PyErr_ExceptionMatches(PyExc_ValueError) == 0 {
            return repr_failed(res, status, op);
        }

        PyErr_Clear();
    }
    if nameobj {
        s = PyUnicode_FromFormat(" name=%R", nameobj);
        object_decref(nameobj);
        if not s {
            return repr_failed(res, status, op);
        }
        PyUnicode_AppendAndDel(&mut res, s);
        if not res {
            return repr_failed(res, status, op);
        }
    }
    if PyObject_GetOptionalAttr(op, py_id(_Py_ID_mode), &mut modeobj) < 0 {
        return repr_failed(res, status, op);
    }
    if modeobj {
        s = PyUnicode_FromFormat(" mode=%R", modeobj);
        object_decref(modeobj);
        if not s {
            return repr_failed(res, status, op);
        }
        PyUnicode_AppendAndDel(&mut res, s);
        if not res {
            return repr_failed(res, status, op);
        }
    }
    s = PyUnicode_FromFormat("%U encoding=%R>", res, self_[0].encoding);
    object_decref(res);
    if status == 0 {
        Py_ReprLeave(op);
    }
    return s;
}

impl _io_TextIOWrapper_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return io_call_noargs(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_fileno));
}

impl _io_TextIOWrapper_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return io_call_noargs(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_seekable));
}

impl _io_TextIOWrapper_readable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return io_call_noargs(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_readable));
}

impl _io_TextIOWrapper_writable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return io_call_noargs(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_writable));
}

impl _io_TextIOWrapper_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return io_call_noargs(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_isatty));
}

impl _io_TextIOWrapper_flush_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    if not check_attached(op) {
        return NULL;
    }
    if not check_closed(op) {
        return NULL;
    }
    self_[0].telling = self_[0].seekable;
    if _textiowrapper_writeflush(op) < 0 {
        return NULL;
    }
    return io_call_noargs(self_[0].buffer, py_id(_Py_ID_flush));
}

impl _io_TextIOWrapper_close_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);

    if not check_attached(op) {
        return NULL;
    }

    res = _io_TextIOWrapper_closed_get_impl(op);
    if not res {
        return NULL;
    }
    r = PyObject_IsTrue(res);
    object_decref(res);
    if r < 0 {
        return NULL;
    }

    if r > 0 {
        return object_new_ref(Py_None);
    }
    if self_[0].detached != 0 {
        return object_new_ref(Py_None);
    }
    exc: ptr[PyObject] = NULL;
    if self_[0].finalizing != 0 {
        res = io_call_onearg(self_[0].buffer, py_id(_Py_ID__dealloc_warn), op);
        if res {
            object_decref(res);
        } else {
            PyErr_Clear();
        }
    }
    if _PyFile_Flush(op) < 0 {
        exc = PyErr_GetRaisedException();
    }

    res = io_call_noargs(self_[0].buffer, py_id(_Py_ID_close));
    if exc {
        _PyErr_ChainExceptions1(exc);
        object_xdecref(res);
        res = NULL;
    }
    return res;
}

impl textiowrapper_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = textio_record(op).view(1);
    line: ptr[PyObject] = NULL;

    if not check_attached(op) {
        return NULL;
    }

    self_[0].telling = 0;
    if object_is_type(op, self_[0].state.view(1)[0].PyTextIOWrapper_Type) {
        line = _textiowrapper_readline(op, -1);
    } else {
        line = io_call_noargs(op, py_id(_Py_ID_readline));
        if line and not unicode_check(line) {
            PyErr_Format(
                PyExc_OSError,
                ptr[u8]("readline() should have returned a str object, not '%.200s'"),
                object_type(line).view(1)[0].tp_name
            );
            object_decref(line);
            return NULL;
        }
    }

    if not line {
        return NULL;
    }

    if unicode_length(line) == 0 {
        object_decref(line);
        py_clear(field_slot(op, TEXTIO_SNAPSHOT));
        self_[0].telling = self_[0].seekable;
        return NULL;
    }

    return line;
}

impl _io_TextIOWrapper_name_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return PyObject_GetAttr(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_name));
}

impl _io_TextIOWrapper_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return PyObject_GetAttr(textio_record(op).view(1)[0].buffer, py_id(_Py_ID_closed));
}

impl _io_TextIOWrapper_newlines_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    res: ptr[PyObject] = NULL;
    if not check_attached(op) {
        return NULL;
    }
    decoder = textio_record(op).view(1)[0].decoder;
    if not decoder
        or PyObject_GetOptionalAttr(decoder, py_id(_Py_ID_newlines), &mut res) == 0 {
        return object_new_ref(Py_None);
    }
    return res;
}

impl _io_TextIOWrapper_errors_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return object_new_ref(textio_record(op).view(1)[0].errors);
}

impl _io_TextIOWrapper__CHUNK_SIZE_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_attached(op) {
        return NULL;
    }
    return PyLong_FromSsize_t(textio_record(op).view(1)[0].chunk_size);
}

impl _io_TextIOWrapper__CHUNK_SIZE_set_impl(
    op: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not check_attached(op) {
        return -1;
    }
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    n = PyNumber_AsSsize_t(value, PyExc_ValueError);
    if n == -1 and PyErr_Occurred() {
        return -1;
    }
    if n <= 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("a strictly positive integer is required")
        );
        return -1;
    }
    textio_record(op).view(1)[0].chunk_size = n;
    return 0;
}

impl textiowrapper_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_TextIOWrapper_read_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(textiowrapper_read_glue).view(1)[0].call(receiver, args, nargs);
}

impl textiowrapper_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs == 0 {
        return _io_TextIOWrapper_readline_impl(receiver, -1);
    }
    return addressof(textiowrapper_readline_glue).view(1)[0].call(
        receiver, args, nargs
    );
}

impl install_textio_tables -> bool {
    base_methods = io_select_methods(
        _TextIOBase_methods, ["detach", "read", "readline", "write"]
    );
    base_getset = io_select_properties(
        _TextIOBase_getset, ["encoding", "newlines", "errors"]
    );
    _TextIOBase_token.handle = ptr(addressof(textiobase_spec));
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(textiobase_slots)),
        base_methods,
        base_getset,
        textiobase_doc
    ) {
        return False;
    }

    decoder_methods = io_select_methods(
        IncrementalNewlineDecoder_methods, ["decode", "getstate", "setstate", "reset"]
    );
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(nldecoder_slots)),
        decoder_methods,
        [],
        IncrementalNewlineDecoder_doc
    ) {
        return False;
    }

    methods: list[MethodDefinition] = [];
    for method in io_select_methods(
        TextIOWrapper_methods,
        [
            "detach",
            "reconfigure",
            "write",
            "read",
            "readline",
            "flush",
            "close",
            "fileno",
            "seekable",
            "readable",
            "writable",
            "isatty",
            "seek",
            "tell",
            "truncate"
        ]
    ) {
        callbacks = method.callbacks;
        if method.name == "read" {
            addressof(textiowrapper_read_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=textiowrapper_read_fast);
        } elif method.name == "readline" {
            addressof(textiowrapper_readline_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=textiowrapper_readline_fast);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    methods.append(
        MethodDefinition(
            "__getstate__",
            MethodCallbacks(positional=_PyIOBase_cannot_pickle),
            "",
            i64(METH_NOARGS)
        )
    );
    getset = io_select_properties(
        TextIOWrapper_getset, ["name", "closed", "newlines", "errors", "_CHUNK_SIZE"]
    );
    return io_fill_slots(
        ptr[PyType_Slot](addressof(textiowrapper_slots)),
        methods,
        getset,
        TextIOWrapper_doc
    );
}
