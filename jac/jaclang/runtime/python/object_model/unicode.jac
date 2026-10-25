import from c {
    glob PyType_Type: PyTypeObject; obj UnicodeWriter {
        has buffer: ptr[PyObject],
            data: ptr[u8],
            kind: i32,
            maxchar: u32,
            size: i64,
            pos: i64,
            min_length: i64,
            min_char: u32,
            overallocate: u8,
            readonly: u8;
    }  obj BytesWriterFields {
        has buffer: ptr[PyObject],
            allocated: i64,
            min_size: i64,
            use_bytearray: i32,
            overallocate: i32,
            use_small_buffer: i32;
    }  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memmove(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcmp(
        left: ptr, right: ptr, size: u64
    ) -> i32;  def memchr(source: ptr, value: i32, size: u64) -> ptr;  def strlen(
        s: ptr[u8]
    ) -> u64;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def _PyBytesWriter_Init(
        writer: ptr[BytesWriterFields]
    );  def _PyBytesWriter_Dealloc(writer: ptr[BytesWriterFields]);  def _PyBytesWriter_Alloc(
        writer: ptr[BytesWriterFields], size: i64
    ) -> ptr;  def _PyBytesWriter_Prepare(
        writer: ptr[BytesWriterFields], data: ptr, size: i64
    ) -> ptr;  def _PyBytesWriter_Resize(
        writer: ptr[BytesWriterFields], data: ptr, size: i64
    ) -> ptr;  def _PyBytesWriter_Finish(
        writer: ptr[BytesWriterFields], data: ptr
    ) -> ptr[PyObject];  def _PyBytesWriter_WriteBytes(
        writer: ptr[BytesWriterFields], data: ptr, source: ptr, size: i64
    ) -> ptr;  def _PyUnicode_IsLowercase(ch: u32) -> i32;  def _PyUnicode_IsUppercase(
        ch: u32
    ) -> i32;  def _PyUnicode_IsTitlecase(ch: u32) -> i32;  def _PyUnicode_ToTitlecase(
        ch: u32
    ) -> u32;  def _PyUnicode_ToLowerFull(ch: u32, res: ptr[u32]) -> i32;  def _PyUnicode_ToTitleFull(
        ch: u32, res: ptr[u32]
    ) -> i32;  def _PyUnicode_ToUpperFull(ch: u32, res: ptr[u32]) -> i32;  def _PyUnicode_ToFoldedFull(
        ch: u32, res: ptr[u32]
    ) -> i32;  def _PyUnicode_IsCased(ch: u32) -> i32;  def _PyUnicode_IsCaseIgnorable(
        ch: u32
    ) -> i32;  def wcslen(s: ptr[i32]) -> u64;  def wmemchr(
        source: ptr, value: i32, size: u64
    ) -> ptr;  def wmemcmp(s1: ptr[i32], s2: ptr[i32], n: u64) -> i32;  def sprintf(
        target: ptr[u8], format: ptr[u8], *args: any
    ) -> i32;  def PyObject_Realloc(p: ptr, size: u64) -> ptr;  def _Py_NewReferenceNoTotal(
        op: ptr[PyObject]
    );  def _Py_GetConfig -> ptr[u8];  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyObject_AssertFailed(
        obj_: ptr[PyObject],
        expr: ptr[u8],
        msg: ptr[u8],
        file: ptr[u8],
        line: i32,
        function: ptr[u8]
    );  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def _PyStack_AsDict(
        values: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Format(
        obj_: ptr[PyObject], format_spec: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_ASCII(v: ptr[PyObject]) -> ptr[PyObject];  def PyOS_FSPath(
        path: ptr[PyObject]
    ) -> ptr[PyObject];  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len_: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyMemoryView_FromBuffer(info: ptr[Py_buffer]) -> ptr[PyObject];  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def PyModuleDef_Init(mdef: ptr[PyModuleDef]) -> ptr[PyObject];  def _PyMem_RawWcsdup(
        text: ptr[i32]
    ) -> ptr[i32];  def _Py_EncodeLocaleEx(
        text: ptr[i32],
        out: &mut ptr[u8],
        error_pos: &mut u64,
        reason: &mut ptr[u8],
        current_locale: i32,
        errors: i32
    ) -> i32;  def _Py_DecodeLocaleEx(
        arg: ptr[u8],
        wstr: &mut ptr[i32],
        wlen: &mut u64,
        reason: &mut ptr[u8],
        current_locale: i32,
        errors: i32
    ) -> i32;  def _Py_SetFileSystemEncoding(
        encoding: ptr[u8], errors: ptr[u8]
    ) -> i32;  def _Py_DumpPathConfig(tstate: ptr[u8]);  def _PyCodec_DecodeText(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyCodec_EncodeText(
        object_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyCodec_InitRegistry(interp: ptr[u8]) -> PyStatus;  def PyUnicodeDecodeError_GetObject(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyUnicodeTranslateError_Create(
        ob: ptr[PyObject], start: i64, end: i64, reason: ptr[u8]
    ) -> ptr[PyObject];  def PyUnicodeTranslateError_SetStart(
        exc: ptr[PyObject], start: i64
    ) -> i32;  def PyUnicodeTranslateError_SetEnd(
        exc: ptr[PyObject], end: i64
    ) -> i32;  def PyUnicodeTranslateError_SetReason(
        exc: ptr[PyObject], reason: ptr[u8]
    ) -> i32;  def _Py_hashtable_new_full(
        hash_func: ptr,
        compare_func: ptr,
        key_destroy_func: ptr,
        value_destroy_func: ptr,
        allocator: ptr
    ) -> ptr;  def _Py_hashtable_get(ht: ptr, key: ptr) -> ptr;  def _Py_hashtable_set(
        ht: ptr, key: ptr, value: ptr
    ) -> i32;  def _Py_hashtable_len(ht: ptr) -> u64;  def _Py_hashtable_destroy(
        ht: ptr
    );  def PyCodec_LookupError(name: ptr[u8]) -> ptr[PyObject];  def _PyCodec_Lookup(
        encoding: ptr[u8]
    ) -> ptr[PyObject];  def PyDict_Pop(
        dict_: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32;  def _PyUnicode_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyLong_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyFloat_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyComplex_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyLong_FormatWriter(
        writer: ptr[UnicodeWriter], ob: ptr[PyObject], base: i32, alternate: i32
    ) -> i32;  def _PyBytes_Repeat(
        dest: ptr[u8], len_dest: i64, src: ptr[u8], len_src: i64
    );  def _Py_bytes_lower(result: ptr[u8], cptr: ptr[u8], length: i64);  def _Py_bytes_upper(
        result: ptr[u8], cptr: ptr[u8], length: i64
    );  def PyCapsule_Import(name: ptr[u8], no_block: i32) -> ptr;  def jacpy_unicode_init_static_strings(
        interp: ptr[u8]
    );  glob _Py_ascii_whitespace: list[u8] = (
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x01\x01\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x01"
             b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
         ); glob:priv ascii_linebreak: list[u8] = (
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x01\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
         ),
         bloom_linebreak: u64 = u64(0xFFFFFFFFFFFFFFFF);
}

glob:priv MAX_UNICODE: u32 = u32(0x10ffff),
     PyUnicode_1BYTE_KIND: i64 = 1,
     PyUnicode_2BYTE_KIND: i64 = 2,
     PyUnicode_4BYTE_KIND: i64 = 4,
     SSTATE_NOT_INTERNED: u32 = u32(0),
     SSTATE_INTERNED_MORTAL: u32 = u32(1),
     SSTATE_INTERNED_IMMORTAL: u32 = u32(2),
     SSTATE_INTERNED_IMMORTAL_STATIC: u32 = u32(3),
     STATE_INTERNED_MASK: u32 = u32(3),
     STATE_KIND_SHIFT: u32 = u32(2),
     STATE_KIND_MASK: u32 = u32(0x1C),
     STATE_COMPACT: u32 = u32(0x20),
     STATE_ASCII: u32 = u32(0x40),
     STATE_STATIC: u32 = u32(0x80),
     _Py_ERROR_UNKNOWN: i32 = 0,
     _Py_ERROR_STRICT: i32 = 1,
     _Py_ERROR_SURROGATEESCAPE: i32 = 2,
     _Py_ERROR_REPLACE: i32 = 3,
     _Py_ERROR_IGNORE: i32 = 4,
     _Py_ERROR_BACKSLASHREPLACE: i32 = 5,
     _Py_ERROR_SURROGATEPASS: i32 = 6,
     _Py_ERROR_XMLCHARREFREPLACE: i32 = 7,
     _Py_ERROR_OTHER: i32 = 8,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     PY_SSIZE_T_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     INT_MAX: i64 = 0x7FFFFFFF,
     OVERALLOCATE_FACTOR: i64 = 4,
     BLOOM_WIDTH: u64 = u64(64),
     FAST_COUNT: i64 = 0,
     FAST_SEARCH: i64 = 1,
     FAST_RSEARCH: i64 = 2,
     MAX_CHAR_ASCII: u32 = u32(0x7f),
     MAX_CHAR_UCS1: u32 = u32(0xff),
     MAX_CHAR_UCS2: u32 = u32(0xffff),
     MAX_CHAR_UCS4: u32 = u32(0x10ffff),
     DO_LOWER: i64 = 0,
     DO_UPPER: i64 = 1,
     DO_CASEFOLD: i64 = 2,
     DO_TITLE: i64 = 3,
     DO_CAPITALIZE: i64 = 4,
     DO_SWAPCASE: i64 = 5,
     LEFTSTRIP: i32 = 0,
     RIGHTSTRIP: i32 = 1,
     BOTHSTRIP: i32 = 2,
     PYREFTRACER_DESTROY: i32 = 1;

def unicode_type -> ptr[PyTypeObject];

def unicode_check(op: ptr[PyObject]) -> bool;

def unicode_check_exact(op: ptr[PyObject]) -> bool;

def bytes_check(op: ptr[PyObject]) -> bool;

def bytes_check_exact(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def list_check(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def bytes_data(op: ptr[PyObject]) -> ptr[u8];

def list_get_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def list_set_item(op: ptr[PyObject], i: i64, item: ptr[PyObject]);

def uo_state(op: ptr[PyObject]) -> u32;

def uo_set_state(op: ptr[PyObject], state: u32);

def uo_interned(op: ptr[PyObject]) -> u32;

def uo_set_interned(op: ptr[PyObject], v: u32);

def uo_kind(op: ptr[PyObject]) -> i64;

def uo_is_compact(op: ptr[PyObject]) -> bool;

def uo_is_ascii(op: ptr[PyObject]) -> bool;

def uo_is_compact_ascii(op: ptr[PyObject]) -> bool;

def uo_is_static(op: ptr[PyObject]) -> bool;

def uo_length(op: ptr[PyObject]) -> i64;

def uo_set_length(op: ptr[PyObject], n: i64);

def uo_hash(op: ptr[PyObject]) -> i64;

def uo_set_hash(op: ptr[PyObject], h: i64);

def uo_utf8_field(op: ptr[PyObject]) -> ptr[u8];

def uo_utf8(op: ptr[PyObject]) -> ptr[u8];

def uo_set_utf8(op: ptr[PyObject], p: ptr[u8]);

def uo_utf8_length(op: ptr[PyObject]) -> i64;

def uo_set_utf8_length(op: ptr[PyObject], n: i64);

def uo_data_any(op: ptr[PyObject]) -> ptr[u8];

def uo_set_data_any(op: ptr[PyObject], p: ptr[u8]);

def uo_compact_data(op: ptr[PyObject]) -> ptr[u8];

def uo_data(op: ptr[PyObject]) -> ptr[u8];

def uo_share_utf8(op: ptr[PyObject]) -> bool;

def uo_has_utf8_memory(op: ptr[PyObject]) -> bool;

def uo_max_char_value(op: ptr[PyObject]) -> u32;

def ch_read(kind: i64, data: ptr[u8], i: i64) -> u32;

def ch_write(kind: i64, data: ptr[u8], i: i64, ch: u32);

def uo_read_char(op: ptr[PyObject], i: i64) -> u32;

def char_ptr(data: ptr[u8], kind: i64, i: i64) -> ptr[u8];

def kind_maxchar_limit(kind: i64) -> u32;

def max_char_kind(maxchar: u32) -> i64;

def unicode_fill(kind: i64, data: ptr[u8], value: u32, start: i64, length: i64);

def copy_chars(
    from_kind: i64, from_data: ptr[u8], to_kind: i64, to_data: ptr[u8], n: i64
);

def runtime_at(offset: i64) -> ptr[u8];

def interp_at(interp: ptr[u8], offset: i64) -> ptr[u8];

def unicode_get_empty -> ptr[PyObject];

def latin1_char(ch: u32) -> ptr[PyObject];

def get_latin1_char(ch: u8) -> ptr[PyObject];

def unicode_char(ch: u32) -> ptr[PyObject];

def unicode_result(unicode: ptr[PyObject]) -> ptr[PyObject];

def unicode_result_unchanged(unicode: ptr[PyObject]) -> ptr[PyObject];

def ensure_unicode(obj_: ptr[PyObject]) -> i32;

def findchar(s: ptr[u8], kind: i64, size: i64, ch: u32, direction: i32) -> i64;

def sl_new(kind: i64, is_ascii: bool, s: ptr[u8], n: i64) -> ptr[PyObject];

def unicode_eq(str1: ptr[PyObject], str2: ptr[PyObject]) -> bool;

def ascii_isspace(ch: u32) -> bool;

def uc_isspace(ch: u32) -> bool;

def uc_islower(ch: u32) -> bool;

def uc_isupper(ch: u32) -> bool;

def uc_istitle(ch: u32) -> bool;

def uc_islinebreak(ch: u32) -> bool;

def uc_isdecimal(ch: u32) -> bool;

def uc_isdigit(ch: u32) -> bool;

def uc_isnumeric(ch: u32) -> bool;

def uc_isprintable(ch: u32) -> bool;

def uc_isalpha(ch: u32) -> bool;

def uc_isalnum(ch: u32) -> bool;

def uc_tolower(ch: u32) -> u32;

def uc_toupper(ch: u32) -> u32;

def uc_totitle(ch: u32) -> u32;

def uc_todecimal(ch: u32) -> i32;

def uc_todigit(ch: u32) -> i32;

def uc_is_surrogate(ch: u32) -> bool;

def uc_is_high_surrogate(ch: u32) -> bool;

def uc_is_low_surrogate(ch: u32) -> bool;

def uc_join_surrogates(hi: u32, lo: u32) -> u32;

def uc_high_surrogate(ch: u32) -> u32;

def uc_low_surrogate(ch: u32) -> u32;

def bloom(mask: u64, ch: u32) -> bool;

def bloom_add(mask: u64, ch: u32) -> u64;

def bloom_linebreak_mask -> u64;

def set_bloom_linebreak(mask: u64);

def bloom_is_linebreak(ch: u32) -> bool;

def interned_dict(interp: ptr[u8]) -> ptr[PyObject];

def set_interned_dict(interp: ptr[u8], d: ptr[PyObject]);

def interned_strings_table -> ptr;

def set_interned_strings_table(t: ptr);

def fs_codec_encoding(interp: ptr[u8]) -> ptr[u8];

def set_fs_codec_encoding(interp: ptr[u8], v: ptr[u8]);

def fs_codec_utf8(interp: ptr[u8]) -> i32;

def set_fs_codec_utf8(interp: ptr[u8], v: i32);

def fs_codec_errors(interp: ptr[u8]) -> ptr[u8];

def set_fs_codec_errors(interp: ptr[u8], v: ptr[u8]);

def fs_codec_error_handler(interp: ptr[u8]) -> i32;

def set_fs_codec_error_handler(interp: ptr[u8], v: i32);

def writer_new -> ptr[UnicodeWriter];

def writer_free(writer: ptr[UnicodeWriter]);

def writer_update(writer: ptr[UnicodeWriter]);

def writer_init_with_buffer(writer: ptr[UnicodeWriter], buffer: ptr[PyObject]);

def writer_prepare(writer: ptr[UnicodeWriter], length: i64, maxchar: u32) -> i32;

def writer_prepare_kind(writer: ptr[UnicodeWriter], kind: i64) -> i32;

def writer_write_char_inline(writer: ptr[UnicodeWriter], ch: u32) -> i32;

def bytes_writer_new -> ptr[BytesWriterFields];

def bytes_writer_free(writer: ptr[BytesWriterFields]);

import from c {
    def PyUnicode_New(size: i64, maxchar: u32) -> ptr[PyObject] {
        if size == 0 {
            return unicode_get_empty();
        }
        is_ascii = False;
        struct_size = PyCompactUnicodeObject_SIZE;
        kind = PyUnicode_1BYTE_KIND;
        char_size: i64 = 1;
        if maxchar < u32(128) {
            is_ascii = True;
            struct_size = PyASCIIObject_SIZE;
        } elif maxchar < u32(256) {
            char_size = 1;
        } elif maxchar < u32(65536) {
            kind = PyUnicode_2BYTE_KIND;
            char_size = 2;
        } else {
            if maxchar > MAX_UNICODE {
                PyErr_SetString(
                    PyExc_SystemError,
                    "invalid maximum character passed to PyUnicode_New"
                );
                return NULL;
            }
            kind = PyUnicode_4BYTE_KIND;
            char_size = 4;
        }

        if size < 0 {
            PyErr_SetString(PyExc_SystemError, "Negative size passed to PyUnicode_New");
            return NULL;
        }
        if size > ((PY_SSIZE_T_MAX - struct_size) // char_size - 1) {
            return PyErr_NoMemory();
        }

        obj_ = ptr[PyObject](
            PyObject_Malloc(u64(struct_size + (size + 1) * char_size))
        );
        if not obj_ {
            return PyErr_NoMemory();
        }
        PyObject_Init(obj_, ptr[PyObject](unicode_type()));
        data = ptr[u8](obj_) + struct_size;
        uo_set_length(obj_, size);
        uo_set_hash(obj_, -1);

        state = (u32(kind) << STATE_KIND_SHIFT) | STATE_COMPACT;
        if is_ascii {
            state = state | STATE_ASCII;
        }
        uo_set_state(obj_, state);
        if is_ascii {
            (data + size).view(1)[0] = u8(0);
        } elif kind == PyUnicode_1BYTE_KIND {
            (data + size).view(1)[0] = u8(0);
            uo_set_utf8(obj_, ptr[u8]());
            uo_set_utf8_length(obj_, 0);
        } else {
            uo_set_utf8(obj_, ptr[u8]());
            uo_set_utf8_length(obj_, 0);
            if kind == PyUnicode_2BYTE_KIND {
                (ptr[u16](data) + size).view(1)[0] = u16(0);
            } else {
                (ptr[u32](data) + size).view(1)[0] = u32(0);
            }
        }
        return obj_;
    }
}

import from c {
    def _Py_GetErrorHandler(errors: ptr[u8]) -> i32 {
        if not errors or strcmp(errors, ptr[u8]("strict")) == i32(0) {
            return _Py_ERROR_STRICT;
        }
        if strcmp(errors, ptr[u8]("surrogateescape")) == i32(0) {
            return _Py_ERROR_SURROGATEESCAPE;
        }
        if strcmp(errors, ptr[u8]("replace")) == i32(0) {
            return _Py_ERROR_REPLACE;
        }
        if strcmp(errors, ptr[u8]("ignore")) == i32(0) {
            return _Py_ERROR_IGNORE;
        }
        if strcmp(errors, ptr[u8]("backslashreplace")) == i32(0) {
            return _Py_ERROR_BACKSLASHREPLACE;
        }
        if strcmp(errors, ptr[u8]("surrogatepass")) == i32(0) {
            return _Py_ERROR_SURROGATEPASS;
        }
        if strcmp(errors, ptr[u8]("xmlcharrefreplace")) == i32(0) {
            return _Py_ERROR_XMLCHARREFREPLACE;
        }
        return _Py_ERROR_OTHER;
    }  glob:priv dealloc_popped: ptr[PyObject] = ptr[PyObject]();
}

def wide_equals_ascii(w: ptr[i32], s: ptr[u8]) -> bool;

def get_error_handler_wide(errors: ptr[i32]) -> i32;

def unicode_check_encoding_errors(encoding: ptr[u8], errors: ptr[u8]) -> i32;

def consistency_check(op: ptr[PyObject], ok: bool, expr: ptr[u8], line: i32);

import from c {
    def _PyUnicode_CheckConsistency(op: ptr[PyObject], check_content: i32) -> i32 {
        consistency_check(
            op, unicode_check(op), ptr[u8]("PyUnicode_Check(op)"), i32(689)
        );
        kind = uo_kind(op);
        valid_kind = kind == PyUnicode_1BYTE_KIND
            or kind == PyUnicode_2BYTE_KIND
            or kind == PyUnicode_4BYTE_KIND;
        if uo_is_ascii(op) and uo_is_compact(op) {
            consistency_check(
                op,
                kind == PyUnicode_1BYTE_KIND,
                ptr[u8]("kind == PyUnicode_1BYTE_KIND"),
                i32(695)
            );
        } else {
            utf8 = uo_utf8_field(op);
            if uo_is_compact(op) {
                data = ptr[u8](op) + PyCompactUnicodeObject_SIZE;
                consistency_check(
                    op,
                    valid_kind,
                    ptr[u8](
                        "kind == PyUnicode_1BYTE_KIND || kind == PyUnicode_2BYTE_KIND || kind == PyUnicode_4BYTE_KIND"
                    ),
                    i32(703)
                );
                consistency_check(
                    op,
                    not uo_is_ascii(op),
                    ptr[u8]("ascii->state.ascii == 0"),
                    i32(706)
                );
                consistency_check(
                    op, utf8 != data, ptr[u8]("_PyUnicode_UTF8(op) != data"), i32(707)
                );
            } else {
                data = uo_data_any(op);
                consistency_check(
                    op,
                    valid_kind,
                    ptr[u8](
                        "kind == PyUnicode_1BYTE_KIND || kind == PyUnicode_2BYTE_KIND || kind == PyUnicode_4BYTE_KIND"
                    ),
                    i32(713)
                );
                consistency_check(
                    op,
                    not uo_is_compact(op),
                    ptr[u8]("ascii->state.compact == 0"),
                    i32(716)
                );
                consistency_check(
                    op, int(data) != 0, ptr[u8]("data != NULL"), i32(717)
                );
                if uo_is_ascii(op) {
                    consistency_check(
                        op,
                        utf8 == data,
                        ptr[u8]("_PyUnicode_UTF8(op) == data"),
                        i32(719)
                    );
                    consistency_check(
                        op,
                        uo_utf8_length(op) == uo_length(op),
                        ptr[u8]("compact->utf8_length == ascii->length"),
                        i32(720)
                    );
                } else {
                    consistency_check(
                        op,
                        utf8 != data,
                        ptr[u8]("_PyUnicode_UTF8(op) != data"),
                        i32(723)
                    );
                }
            }
            if not utf8 {
                consistency_check(
                    op,
                    uo_utf8_length(op) == 0,
                    ptr[u8]("compact->utf8_length == 0"),
                    i32(728)
                );
            }
        }

        if check_content != i32(0) {
            maxchar = u32(0);
            chars = uo_data(op);
            length = uo_length(op);
            for i in range(length) {
                ch = ch_read(kind, chars, i);
                if ch > maxchar {
                    maxchar = ch;
                }
            }
            if kind == PyUnicode_1BYTE_KIND {
                if not uo_is_ascii(op) {
                    consistency_check(
                        op, maxchar >= u32(128), ptr[u8]("maxchar >= 128"), i32(748)
                    );
                    consistency_check(
                        op, maxchar <= u32(255), ptr[u8]("maxchar <= 255"), i32(749)
                    );
                } else {
                    consistency_check(
                        op, maxchar < u32(128), ptr[u8]("maxchar < 128"), i32(752)
                    );
                }
            } elif kind == PyUnicode_2BYTE_KIND {
                consistency_check(
                    op, maxchar >= u32(0x100), ptr[u8]("maxchar >= 0x100"), i32(755)
                );
                consistency_check(
                    op, maxchar <= u32(0xFFFF), ptr[u8]("maxchar <= 0xFFFF"), i32(756)
                );
            } else {
                consistency_check(
                    op, maxchar >= u32(0x10000), ptr[u8]("maxchar >= 0x10000"), i32(759)
                );
                consistency_check(
                    op,
                    maxchar <= MAX_UNICODE,
                    ptr[u8]("maxchar <= MAX_UNICODE"),
                    i32(760)
                );
            }
            consistency_check(
                op,
                ch_read(kind, chars, length) == u32(0),
                ptr[u8]("PyUnicode_READ(kind, data, ascii->length) == 0"),
                i32(762)
            );
        }
        return i32(1);
    }
}

def hexdigit_of(x: u32) -> u8;

def emit_byte(p: ptr[u8], c: u8) -> ptr[u8];

def backslashreplace(
    writer: ptr[BytesWriterFields],
    s: ptr[u8],
    unicode: ptr[PyObject],
    collstart: i64,
    collend: i64
) -> ptr[u8];

def xmlcharrefreplace(
    writer: ptr[BytesWriterFields],
    s: ptr[u8],
    unicode: ptr[PyObject],
    collstart: i64,
    collend: i64
) -> ptr[u8];

def make_bloom_mask(kind: i64, data: ptr[u8], len: i64) -> u64;

def resize_copy(unicode: ptr[PyObject], length: i64) -> ptr[PyObject];

def resize_compact(unicode: ptr[PyObject], length: i64) -> ptr[PyObject];

def resize_inplace(unicode: ptr[PyObject], length: i64) -> i32;

def unicode_kind_name(unicode: ptr[PyObject]) -> ptr[u8];

def unicode_check_modifiable(unicode: ptr[PyObject]) -> i32;

def narrow_chars(
    from_kind: i64, from_data: ptr[u8], to_kind: i64, to_data: ptr[u8], n: i64
);

def _copy_characters(
    to: ptr[PyObject],
    to_start: i64,
    from_obj: ptr[PyObject],
    from_start: i64,
    how_many: i64,
    check_maxchar: bool
) -> i32;

import from c {
    def _PyUnicode_FastCopyCharacters(
        to: ptr[PyObject],
        to_start: i64,
        from_obj: ptr[PyObject],
        from_start: i64,
        how_many: i64
    ) {
        _copy_characters(to, to_start, from_obj, from_start, how_many, False);
    }  def PyUnicode_CopyCharacters(
        to: ptr[PyObject],
        to_start: i64,
        from_obj: ptr[PyObject],
        from_start: i64,
        how_many_arg: i64
    ) -> i64 {
        if not unicode_check(from_obj) or not unicode_check(to) {
            PyErr_BadInternalCall();
            return -1;
        }

        if u64.wrap(from_start) > u64(uo_length(from_obj)) {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return -1;
        }
        if u64.wrap(to_start) > u64(uo_length(to)) {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return -1;
        }
        if how_many_arg < 0 {
            PyErr_SetString(PyExc_SystemError, "how_many cannot be negative");
            return -1;
        }
        how_many = min(uo_length(from_obj) - from_start, how_many_arg);
        to_length = uo_length(to);
        if to_start + how_many > to_length {
            PyErr_Format(
                PyExc_SystemError,
                "Cannot write %zi characters at %zi in a string of %zi characters",
                how_many,
                to_start,
                to_length
            );
            return -1;
        }
        if how_many == 0 {
            return 0;
        }
        if unicode_check_modifiable(to) != i32(0) {
            return -1;
        }
        err = _copy_characters(to, to_start, from_obj, from_start, how_many, True);
        if err != i32(0) {
            PyErr_Format(
                PyExc_SystemError,
                "Cannot copy %s characters into a string of %s characters",
                unicode_kind_name(from_obj),
                unicode_kind_name(to)
            );
            return -1;
        }
        return how_many;
    }
}

def find_maxchar_surrogates(begin: ptr[i32], end: ptr[i32]) -> tuple[i32, u32, i64];

def unicode_set_refcnt(op: ptr[PyObject], refcnt: i64);

def unicode_dealloc(unicode: ptr[PyObject]);

def unicode_is_singleton(unicode: ptr[PyObject]) -> bool;

def unicode_modifiable(unicode: ptr[PyObject]) -> bool;

def unicode_resize(unicode: ptr[PyObject], length: i64) -> tuple[i32, ptr[PyObject]];

import from c {
    def PyUnicode_Resize(p_unicode: ptr[ptr[PyObject]], length: i64) -> i32 {
        if not p_unicode {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        unicode = p_unicode.view(1)[0];
        if not unicode or not unicode_check(unicode) or length < 0 {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        (status, resized) = unicode_resize(unicode, length);
        p_unicode.view(1)[0] = resized;
        return status;
    }
}

def unicode_write_cstr(unicode: ptr[PyObject], index: i64, s: ptr[u8], len: i64);

def unicode_write_widechar(
    kind: i64, data: ptr[u8], u: ptr[i32], size: i64, num_surrogates: i64
);

import from c {
    def PyUnicode_FromWideChar(u: ptr[i32], size_arg: i64) -> ptr[PyObject] {
        if not u and size_arg != 0 {
            PyErr_BadInternalCall();
            return NULL;
        }
        size = size_arg;
        if size == -1 {
            size = i64(wcslen(u));
        }

        if size == 0 {
            return unicode_get_empty();
        }

        if size == 1 {
            first = u.view(1)[0];
            if u32.wrap(first) < u32(256) {
                return get_latin1_char(u8.wrap(first));
            }
        }

        (status, maxchar, num_surrogates) = find_maxchar_surrogates(u, u + size);
        if status == i32(-1) {
            return NULL;
        }
        unicode = PyUnicode_New(size - num_surrogates, maxchar);
        if not unicode {
            return NULL;
        }
        unicode_write_widechar(
            uo_kind(unicode), uo_data(unicode), u, size, num_surrogates
        );
        return unicode_result(unicode);
    }  def PyUnicodeWriter_WriteWideChar(
        pub_writer: ptr[PyUnicodeWriter], s: ptr[i32], size_arg: i64
    ) -> i32 {
        writer = ptr[UnicodeWriter](pub_writer);
        size = size_arg;
        if size < 0 {
            size = i64(wcslen(s));
        }
        if size == 0 {
            return i32(0);
        }
        (status, maxchar, num_surrogates) = find_maxchar_surrogates(s, s + size);
        if status == i32(-1) {
            return i32(-1);
        }
        if writer_prepare(writer, size - num_surrogates, maxchar) < i32(0) {
            return i32(-1);
        }
        kind = i64(writer.view(1)[0].kind);
        data = writer.view(1)[0].data + writer.view(1)[0].pos * kind;
        unicode_write_widechar(kind, data, s, size, num_surrogates);
        writer.view(1)[0].pos += size - num_surrogates;
        return i32(0);
    }  def PyUnicode_FromStringAndSize(u: ptr[u8], size: i64) -> ptr[PyObject] {
        if size < 0 {
            PyErr_SetString(
                PyExc_SystemError, "Negative size passed to PyUnicode_FromStringAndSize"
            );
            return NULL;
        }
        if u {
            return unicode_decode_utf8(
                u, size, _Py_ERROR_STRICT, ptr[u8](), ptr[i64]()
            );
        }
        if size > 0 {
            PyErr_SetString(
                PyExc_SystemError,
                "NULL string with positive size with NULL passed to PyUnicode_FromStringAndSize"
            );
            return NULL;
        }
        return unicode_get_empty();
    }  def PyUnicode_FromString(u: ptr[u8]) -> ptr[PyObject] {
        size = strlen(u);
        if size > u64(PY_SSIZE_T_MAX) {
            PyErr_SetString(PyExc_OverflowError, "input too long");
            return NULL;
        }
        return unicode_decode_utf8(
            u, i64(size), _Py_ERROR_STRICT, ptr[u8](), ptr[i64]()
        );
    }  def _PyUnicode_FromId(id: ptr[u8]) -> ptr[PyObject] {
        id_mutex = ptr[PyMutex](id + _Py_Identifier_MUTEX);
        PyMutex_Lock(id_mutex);
        interp = current_interp();
        index_slot = ptr[i64](id + _Py_Identifier_INDEX);
        index = index_slot.view(1)[0];
        if index < 0 {
            rt_mutex = ptr[PyMutex](runtime_at(_PyRuntimeState_UNICODE_IDS_MUTEX));
            PyMutex_Lock(rt_mutex);

            index = index_slot.view(1)[0];
            if index < 0 {
                next_index = ptr[i64](
                    runtime_at(_PyRuntimeState_UNICODE_IDS_NEXT_INDEX)
                );
                index = next_index.view(1)[0];
                next_index.view(1)[0] = index + 1;
                index_slot.view(1)[0] = index;
            }
            PyMutex_Unlock(rt_mutex);
        }
        ids_size = ptr[i64](interp_at(interp, PyInterpreterState_UNICODE_IDS_SIZE));
        ids_array = ptr[ptr[ptr[PyObject]]](
            interp_at(interp, PyInterpreterState_UNICODE_IDS_ARRAY)
        );
        if index < ids_size.view(1)[0] {
            cached = (ids_array.view(1)[0] + index).view(1)[0];
            if cached {
                PyMutex_Unlock(id_mutex);
                return cached;
            }
        }
        text = ptr[ptr[u8]](id).view(1)[0];
        obj_ = unicode_decode_utf8(
            text, i64(strlen(text)), _Py_ERROR_STRICT, ptr[u8](), ptr[i64]()
        );
        if not obj_ {
            PyMutex_Unlock(id_mutex);
            return NULL;
        }

        obj_ = intern_common(interp, obj_, True);
        size = ids_size.view(1)[0];
        if index >= size {
            new_size = max(index * 2, 16);
            item_size: i64 = 8;
            new_array = ptr[ptr[PyObject]](
                PyMem_Realloc(ptr(ids_array.view(1)[0]), u64(new_size * item_size))
            );
            if not new_array {
                PyErr_NoMemory();
                PyMutex_Unlock(id_mutex);
                return NULL;
            }
            jacpy_memory_zero(ptr(new_array + size), (new_size - size) * item_size);
            ids_array.view(1)[0] = new_array;
            ids_size.view(1)[0] = new_size;
        }

        (ids_array.view(1)[0] + index).view(1)[0] = obj_;

        PyMutex_Unlock(id_mutex);
        return obj_;
    }
}

def unicode_clear_identifiers(interp: ptr[u8]);

import from c {
    def _PyUnicode_FromASCII(buffer: ptr[u8], size: i64) -> ptr[PyObject] {
        if size == 1 {
            return get_latin1_char(buffer.view(1)[0]);
        }
        unicode = PyUnicode_New(size, MAX_CHAR_ASCII);
        if not unicode {
            return NULL;
        }
        memcpy(ptr(uo_data(unicode)), ptr(buffer), u64(size));
        return unicode;
    }
}

def _PyUnicode_FromUCS1(u: ptr[u8], size: i64) -> ptr[PyObject];

def _PyUnicode_FromUCS2(u: ptr[u16], size: i64) -> ptr[PyObject];

def _PyUnicode_FromUCS4(u: ptr[u32], size: i64) -> ptr[PyObject];

import from c {
    def PyUnicodeWriter_WriteUCS4(
        pub_writer: ptr[PyUnicodeWriter], s: ptr[u32], size: i64
    ) -> i32 {
        writer = ptr[UnicodeWriter](pub_writer);
        if size < 0 {
            PyErr_SetString(PyExc_ValueError, "size must be positive");
            return i32(-1);
        }
        if size == 0 {
            return i32(0);
        }
        max_char = sl_find_max_char(PyUnicode_4BYTE_KIND, ptr[u8](s), size);
        if writer_prepare(writer, size, max_char) < i32(0) {
            return i32(-1);
        }
        kind = i64(writer.view(1)[0].kind);
        data = writer.view(1)[0].data + writer.view(1)[0].pos * kind;
        if kind == PyUnicode_1BYTE_KIND {
            narrow_chars(
                PyUnicode_4BYTE_KIND, ptr[u8](s), PyUnicode_1BYTE_KIND, data, size
            );
        } elif kind == PyUnicode_2BYTE_KIND {
            narrow_chars(
                PyUnicode_4BYTE_KIND, ptr[u8](s), PyUnicode_2BYTE_KIND, data, size
            );
        } else {
            memcpy(ptr(data), ptr(s), u64(size * 4));
        }
        writer.view(1)[0].pos += size;
        return i32(0);
    }  def PyUnicode_FromKindAndData(
        kind: i32, buffer: ptr[u8], size: i64
    ) -> ptr[PyObject] {
        if size < 0 {
            PyErr_SetString(PyExc_ValueError, "size must be positive");
            return NULL;
        }
        k = i64(kind);
        if k == PyUnicode_1BYTE_KIND {
            return _PyUnicode_FromUCS1(buffer, size);
        }
        if k == PyUnicode_2BYTE_KIND {
            return _PyUnicode_FromUCS2(ptr[u16](buffer), size);
        }
        if k == PyUnicode_4BYTE_KIND {
            return _PyUnicode_FromUCS4(ptr[u32](buffer), size);
        }
        PyErr_SetString(PyExc_SystemError, "invalid kind");
        return NULL;
    }  def _PyUnicode_FindMaxChar(unicode: ptr[PyObject], start: i64, end: i64) -> u32 {
        if start == 0 and end == uo_length(unicode) {
            return uo_max_char_value(unicode);
        }
        if start == end {
            return MAX_CHAR_ASCII;
        }
        if uo_is_ascii(unicode) {
            return MAX_CHAR_ASCII;
        }
        kind = uo_kind(unicode);
        startptr = char_ptr(uo_data(unicode), kind, start);
        return sl_find_max_char(kind, startptr, end - start);
    }
}

def unicode_adjust_maxchar(unicode: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyUnicode_Copy(unicode: ptr[PyObject]) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadInternalCall();
            return NULL;
        }
        length = uo_length(unicode);
        copy = PyUnicode_New(length, uo_max_char_value(unicode));
        if not copy {
            return NULL;
        }
        memcpy(
            ptr(uo_data(copy)), ptr(uo_data(unicode)), u64(length * uo_kind(unicode))
        );
        return copy;
    }
}

def mem_new_items(n: i64, item_size: i64) -> ptr[u8];

def unicode_askind(skind: i64, data: ptr[u8], len: i64, kind: i64) -> ptr[u8];

def as_ucs4(
    string: ptr[PyObject], target_arg: ptr[u32], targetsize: i64, copy_null: bool
) -> ptr[u32];

import from c {
    def PyUnicode_AsUCS4(
        string: ptr[PyObject], target: ptr[u32], targetsize: i64, copy_null: i32
    ) -> ptr[u32] {
        if not target or targetsize < 0 {
            PyErr_BadInternalCall();
            return ptr[u32]();
        }
        return as_ucs4(string, target, targetsize, copy_null != i32(0));
    }  def PyUnicode_AsUCS4Copy(string: ptr[PyObject]) -> ptr[u32] {
        return as_ucs4(string, ptr[u32](), 0, True);
    }
}

def unicode_get_widechar_size(unicode: ptr[PyObject]) -> i64;

def unicode_copy_as_widechar(unicode: ptr[PyObject], w: ptr[i32], size: i64);

def unicode_as_widechar_string(
    unicode: ptr[PyObject], reject_nul: bool
) -> tuple[ptr[i32], i64];

import from c {
    def PyUnicode_AsWideChar(unicode: ptr[PyObject], w: ptr[i32], size: i64) -> i64 {
        if not unicode {
            PyErr_BadInternalCall();
            return -1;
        }
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return -1;
        }
        res = unicode_get_widechar_size(unicode);
        if not w {
            return res + 1;
        }
        count = size;
        if count > res {
            count = res + 1;
        } else {
            res = count;
        }
        unicode_copy_as_widechar(unicode, w, count);
        return res;
    }  def PyUnicode_AsWideCharString(
        unicode: ptr[PyObject], size: ptr[i64]
    ) -> ptr[i32] {
        (buffer, buflen) = unicode_as_widechar_string(unicode, not size);
        if buffer and size {
            size.view(1)[0] = buflen;
        }
        return buffer;
    }  def _PyUnicode_WideCharString_Converter(obj_: ptr[PyObject], addr: ptr) -> i32 {
        p = ptr[ptr[i32]](addr);
        if not obj_ {
            PyMem_Free(ptr(p.view(1)[0]));
            p.view(1)[0] = ptr[i32]();
            return i32(1);
        }
        if unicode_check(obj_) {
            (buffer, buflen) = unicode_as_widechar_string(obj_, True);
            p.view(1)[0] = buffer;
            if not buffer {
                return i32(0);
            }
            return Py_CLEANUP_SUPPORTED;
        }
        PyErr_Format(
            PyExc_TypeError,
            "argument must be str, not %.50s",
            object_type(obj_).view(1)[0].tp_name
        );
        return i32(0);
    }  def _PyUnicode_WideCharString_Opt_Converter(
        obj_: ptr[PyObject], addr: ptr
    ) -> i32 {
        p = ptr[ptr[i32]](addr);
        if not obj_ {
            PyMem_Free(ptr(p.view(1)[0]));
            p.view(1)[0] = ptr[i32]();
            return i32(1);
        }
        if obj_ == Py_None {
            p.view(1)[0] = ptr[i32]();
            return i32(1);
        }
        if unicode_check(obj_) {
            (buffer, buflen) = unicode_as_widechar_string(obj_, True);
            p.view(1)[0] = buffer;
            if not buffer {
                return i32(0);
            }
            return Py_CLEANUP_SUPPORTED;
        }
        PyErr_Format(
            PyExc_TypeError,
            "argument must be str or None, not %.50s",
            object_type(obj_).view(1)[0].tp_name
        );
        return i32(0);
    }  def PyUnicode_FromOrdinal(ordinal: i32) -> ptr[PyObject] {
        if ordinal < i32(0) or i64(ordinal) > i64(MAX_UNICODE) {
            PyErr_SetString(PyExc_ValueError, "chr() arg not in range(0x110000)");
            return NULL;
        }
        return unicode_char(u32(ordinal));
    }  def PyUnicode_FromObject(obj_: ptr[PyObject]) -> ptr[PyObject] {
        if unicode_check_exact(obj_) {
            return object_new_ref(obj_);
        }
        if unicode_check(obj_) {
            return _PyUnicode_Copy(obj_);
        }
        PyErr_Format(
            PyExc_TypeError,
            "Can't convert '%.100s' object to str implicitly",
            object_type(obj_).view(1)[0].tp_name
        );
        return NULL;
    }  def PyUnicode_FromEncodedObject(
        obj_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not obj_ {
            PyErr_BadInternalCall();
            return NULL;
        }

        if bytes_check(obj_) {
            if object_size(obj_) == 0 {
                if unicode_check_encoding_errors(encoding, errors) < 0 {
                    return NULL;
                }
                return unicode_get_empty();
            }
            return PyUnicode_Decode(
                bytes_data(obj_), object_size(obj_), encoding, errors
            );
        }
        if unicode_check(obj_) {
            PyErr_SetString(PyExc_TypeError, "decoding str is not supported");
            return NULL;
        }

        buffer = ptr[Py_buffer](PyMem_Calloc(1, u64(Py_buffer_SIZE)));
        if not buffer {
            return PyErr_NoMemory();
        }
        if PyObject_GetBuffer(obj_, buffer, PyBUF_SIMPLE) < 0 {
            PyMem_Free(ptr(buffer));
            PyErr_Format(
                PyExc_TypeError,
                "decoding to str: need a bytes-like object, %.80s found",
                object_type(obj_).view(1)[0].tp_name
            );
            return NULL;
        }
        length = buffer.view(1)[0].length;
        if length == 0 {
            PyBuffer_Release(buffer);
            PyMem_Free(ptr(buffer));
            if unicode_check_encoding_errors(encoding, errors) < 0 {
                return NULL;
            }
            return unicode_get_empty();
        }
        v = PyUnicode_Decode(ptr[u8](buffer.view(1)[0].buf), length, encoding, errors);
        PyBuffer_Release(buffer);
        PyMem_Free(ptr(buffer));
        return v;
    }  def _Py_normalize_encoding(
        encoding: ptr[u8], lower: ptr[u8], lower_len: u64
    ) -> i32 {
        e = encoding;
        l = lower;
        l_end = lower + (i64(lower_len) - 1);
        punct = False;
        while True {
            c = e.view(1)[0];
            if c == u8(0) {
                break;
            }
            if py_isalnum(c) or c == u8(46) {
                if punct and l != lower {
                    if l == l_end {
                        return i32(0);
                    }
                    l.view(1)[0] = u8(95);
                    l = l + 1;
                }
                punct = False;
                if l == l_end {
                    return i32(0);
                }
                l.view(1)[0] = py_tolower(c);
                l = l + 1;
            } else {
                punct = True;
            }
            e = e + 1;
        }
        l.view(1)[0] = u8(0);
        return i32(1);
    }
}

glob:priv SHORTCUT_NONE: i64 = 0,
     SHORTCUT_UTF8: i64 = 1,
     SHORTCUT_UTF16: i64 = 2,
     SHORTCUT_UTF32: i64 = 3,
     SHORTCUT_ASCII: i64 = 4,
     SHORTCUT_LATIN1: i64 = 5,
     SHORTCUT_BUFLOWER: i64 = 11;

def codec_shortcut(encoding: ptr[u8]) -> tuple[i32, i64];

import from c {
    def PyUnicode_Decode(
        s: ptr[u8], size: i64, encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if unicode_check_encoding_errors(encoding, errors) < 0 {
            return NULL;
        }
        if size == 0 {
            return unicode_get_empty();
        }
        if not encoding {
            return PyUnicode_DecodeUTF8Stateful(s, size, errors, ptr[i64]());
        }

        (status, codec) = codec_shortcut(encoding);
        if status < 0 {
            return NULL;
        }
        if codec == SHORTCUT_UTF8 {
            return PyUnicode_DecodeUTF8Stateful(s, size, errors, ptr[i64]());
        }
        if codec == SHORTCUT_UTF16 {
            return PyUnicode_DecodeUTF16(s, size, errors, ptr[i32]());
        }
        if codec == SHORTCUT_UTF32 {
            return PyUnicode_DecodeUTF32(s, size, errors, ptr[i32]());
        }
        if codec == SHORTCUT_ASCII {
            return PyUnicode_DecodeASCII(s, size, errors);
        }
        if codec == SHORTCUT_LATIN1 {
            return PyUnicode_DecodeLatin1(s, size, errors);
        }

        info = ptr[Py_buffer](PyMem_Calloc(1, u64(Py_buffer_SIZE)));
        if not info {
            return PyErr_NoMemory();
        }
        if PyBuffer_FillInfo(info, NULL, ptr(s), size, 1, PyBUF_FULL_RO) < 0 {
            PyMem_Free(ptr(info));
            return NULL;
        }
        buffer = PyMemoryView_FromBuffer(info);
        PyMem_Free(ptr(info));
        if not buffer {
            return NULL;
        }
        unicode = _PyCodec_DecodeText(buffer, encoding, errors);
        if not unicode {
            object_decref(buffer);
            return NULL;
        }
        if not unicode_check(unicode) {
            PyErr_Format(
                PyExc_TypeError,
                "'%.400s' decoder returned '%.400s' instead of 'str'; use codecs.decode() to decode to arbitrary types",
                encoding,
                object_type(unicode).view(1)[0].tp_name
            );
            object_decref(unicode);
            object_decref(buffer);
            return NULL;
        }
        object_decref(buffer);
        return unicode_result(unicode);
    }  def PyUnicode_AsDecodedObject(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "PyUnicode_AsDecodedObject() is deprecated and will be removed in 3.15; use PyCodec_Decode() to decode from str",
            1
        )
            < 0 {
            return NULL;
        }
        enc = encoding;
        if not enc {
            enc = PyUnicode_GetDefaultEncoding();
        }

        return PyCodec_Decode(unicode, enc, errors);
    }  def PyUnicode_AsDecodedUnicode(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "PyUnicode_AsDecodedUnicode() is deprecated and will be removed in 3.15; use PyCodec_Decode() to decode from str to str",
            1
        )
            < 0 {
            return NULL;
        }
        enc = encoding;
        if not enc {
            enc = PyUnicode_GetDefaultEncoding();
        }

        v = PyCodec_Decode(unicode, enc, errors);
        if not v {
            return NULL;
        }
        if not unicode_check(v) {
            PyErr_Format(
                PyExc_TypeError,
                "'%.400s' decoder returned '%.400s' instead of 'str'; use codecs.decode() to decode to arbitrary types",
                enc,
                object_type(unicode).view(1)[0].tp_name
            );
            object_decref(v);
            return NULL;
        }
        return unicode_result(v);
    }  def PyUnicode_AsEncodedObject(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "PyUnicode_AsEncodedObject() is deprecated and will be removed in 3.15; use PyUnicode_AsEncodedString() to encode from str to bytes or PyCodec_Encode() for generic encoding",
            1
        )
            < 0 {
            return NULL;
        }
        enc = encoding;
        if not enc {
            enc = PyUnicode_GetDefaultEncoding();
        }

        return PyCodec_Encode(unicode, enc, errors);
    }
}

def unicode_encode_locale(
    unicode: ptr[PyObject], error_handler: i32, current_locale: i32
) -> ptr[PyObject];

def config_filesystem_errors(interp: ptr[u8]) -> ptr[i32];

import from c {
    def PyUnicode_EncodeLocale(
        unicode: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        error_handler = _Py_GetErrorHandler(errors);
        return unicode_encode_locale(unicode, error_handler, i32(1));
    }  def PyUnicode_EncodeFSDefault(unicode: ptr[PyObject]) -> ptr[PyObject] {
        interp = current_interp();
        if fs_codec_utf8(interp) != 0 {
            return unicode_encode_utf8(
                unicode, fs_codec_error_handler(interp), fs_codec_errors(interp)
            );
        }
        if _Py_FORCE_UTF8_FS_ENCODING == 0 and fs_codec_encoding(interp) {
            return PyUnicode_AsEncodedString(
                unicode, fs_codec_encoding(interp), fs_codec_errors(interp)
            );
        }
        errors = get_error_handler_wide(config_filesystem_errors(interp));
        if _Py_FORCE_UTF8_FS_ENCODING != 0 {
            return unicode_encode_utf8(unicode, errors, ptr[u8]());
        }
        return unicode_encode_locale(unicode, errors, i32(0));
    }  def PyUnicode_AsEncodedString(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if unicode_check_encoding_errors(encoding, errors) < 0 {
            return NULL;
        }
        if not encoding {
            return _PyUnicode_AsUTF8String(unicode, errors);
        }

        (status, codec) = codec_shortcut(encoding);
        if status < 0 {
            return NULL;
        }
        if codec == SHORTCUT_UTF8 {
            return _PyUnicode_AsUTF8String(unicode, errors);
        }
        if codec == SHORTCUT_UTF16 {
            return _PyUnicode_EncodeUTF16(unicode, errors, i32(0));
        }
        if codec == SHORTCUT_UTF32 {
            return _PyUnicode_EncodeUTF32(unicode, errors, i32(0));
        }
        if codec == SHORTCUT_ASCII {
            return _PyUnicode_AsASCIIString(unicode, errors);
        }
        if codec == SHORTCUT_LATIN1 {
            return _PyUnicode_AsLatin1String(unicode, errors);
        }

        v = _PyCodec_EncodeText(unicode, encoding, errors);
        if not v {
            return NULL;
        }

        if bytes_check(v) {
            return v;
        }

        if object_type_check(v, ptr[PyTypeObject](addressof(PyByteArray_Type))) {
            error = PyErr_WarnFormat(
                PyExc_RuntimeWarning,
                1,
                "encoder %s returned bytearray instead of bytes; use codecs.encode() to encode to arbitrary types",
                encoding
            );
            if error != 0 {
                object_decref(v);
                return NULL;
            }
            b = PyBytes_FromStringAndSize(PyByteArray_AsString(v), object_size(v));
            object_decref(v);
            return b;
        }
        PyErr_Format(
            PyExc_TypeError,
            "'%.400s' encoder returned '%.400s' instead of 'bytes'; use codecs.encode() to encode to arbitrary types",
            encoding,
            object_type(v).view(1)[0].tp_name
        );
        object_decref(v);
        return NULL;
    }  def PyUnicode_AsEncodedUnicode(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "PyUnicode_AsEncodedUnicode() is deprecated and will be removed in 3.15; use PyCodec_Encode() to encode from str to str",
            1
        )
            < 0 {
            return NULL;
        }
        enc = encoding;
        if not enc {
            enc = PyUnicode_GetDefaultEncoding();
        }

        v = PyCodec_Encode(unicode, enc, errors);
        if not v {
            return NULL;
        }
        if not unicode_check(v) {
            PyErr_Format(
                PyExc_TypeError,
                "'%.400s' encoder returned '%.400s' instead of 'str'; use codecs.encode() to encode to arbitrary types",
                enc,
                object_type(v).view(1)[0].tp_name
            );
            object_decref(v);
            return NULL;
        }
        return v;
    }
}

def unicode_decode_locale(
    s: ptr[u8], length: i64, errors: i32, current_locale: i32
) -> ptr[PyObject];

import from c {
    def PyUnicode_DecodeLocaleAndSize(
        str_: ptr[u8], length: i64, errors: ptr[u8]
    ) -> ptr[PyObject] {
        error_handler = _Py_GetErrorHandler(errors);
        return unicode_decode_locale(str_, length, error_handler, i32(1));
    }  def PyUnicode_DecodeLocale(str_: ptr[u8], errors: ptr[u8]) -> ptr[PyObject] {
        size = i64(strlen(str_));
        error_handler = _Py_GetErrorHandler(errors);
        return unicode_decode_locale(str_, size, error_handler, i32(1));
    }  def PyUnicode_DecodeFSDefault(s: ptr[u8]) -> ptr[PyObject] {
        size = i64(strlen(s));
        return PyUnicode_DecodeFSDefaultAndSize(s, size);
    }  def PyUnicode_DecodeFSDefaultAndSize(s: ptr[u8], size: i64) -> ptr[PyObject] {
        interp = current_interp();
        if fs_codec_utf8(interp) != 0 {
            return unicode_decode_utf8(
                s,
                size,
                fs_codec_error_handler(interp),
                fs_codec_errors(interp),
                ptr[i64]()
            );
        }
        if _Py_FORCE_UTF8_FS_ENCODING == 0 and fs_codec_encoding(interp) {
            return PyUnicode_Decode(
                s, size, fs_codec_encoding(interp), fs_codec_errors(interp)
            );
        }
        errors = get_error_handler_wide(config_filesystem_errors(interp));
        if _Py_FORCE_UTF8_FS_ENCODING != 0 {
            return unicode_decode_utf8(s, size, errors, ptr[u8](), ptr[i64]());
        }
        return unicode_decode_locale(s, size, errors, i32(0));
    }  def PyUnicode_FSConverter(arg: ptr[PyObject], addr: ptr) -> i32 {
        slot = ptr[ptr[PyObject]](addr);
        if not arg {
            object_decref(slot.view(1)[0]);
            slot.view(1)[0] = NULL;
            return i32(1);
        }
        path = PyOS_FSPath(arg);
        if not path {
            return i32(0);
        }
        output = NULL;
        if bytes_check(path) {
            output = path;
        } else {
            output = PyUnicode_EncodeFSDefault(path);
            object_decref(path);
            if not output {
                return i32(0);
            }
        }
        size = object_size(output);
        data = bytes_data(output);
        if i64(strlen(data)) != size {
            PyErr_SetString(PyExc_ValueError, "embedded null byte");
            object_decref(output);
            return i32(0);
        }
        slot.view(1)[0] = output;
        return Py_CLEANUP_SUPPORTED;
    }  def PyUnicode_FSDecoder(arg: ptr[PyObject], addr: ptr) -> i32 {
        slot = ptr[ptr[PyObject]](addr);
        if not arg {
            object_decref(slot.view(1)[0]);
            slot.view(1)[0] = NULL;
            return i32(1);
        }
        path = PyOS_FSPath(arg);
        if not path {
            return i32(0);
        }
        output = NULL;
        if unicode_check(path) {
            output = path;
        } elif bytes_check(path) {
            output = PyUnicode_DecodeFSDefaultAndSize(
                bytes_data(path), object_size(path)
            );
            object_decref(path);
            if not output {
                return i32(0);
            }
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "path should be string, bytes, or os.PathLike, not %.200s",
                object_type(arg).view(1)[0].tp_name
            );
            object_decref(path);
            return i32(0);
        }
        if findchar(uo_data(output), uo_kind(output), uo_length(output), u32(0), i32(1))
            >= 0 {
            PyErr_SetString(PyExc_ValueError, "embedded null character");
            object_decref(output);
            return i32(0);
        }
        slot.view(1)[0] = output;
        return Py_CLEANUP_SUPPORTED;
    }
}

def unicode_ensure_utf8(unicode: ptr[PyObject]) -> i32;

def unicode_as_utf8_and_size(unicode: ptr[PyObject]) -> tuple[ptr[u8], i64];

import from c {
    def PyUnicode_AsUTF8AndSize(unicode: ptr[PyObject], psize: ptr[i64]) -> ptr[u8] {
        (utf8, size) = unicode_as_utf8_and_size(unicode);
        if psize {
            psize.view(1)[0] = size;
        }
        return utf8;
    }  def PyUnicode_AsUTF8(unicode: ptr[PyObject]) -> ptr[u8] {
        (utf8, size) = unicode_as_utf8_and_size(unicode);
        return utf8;
    }  def _PyUnicode_AsUTF8NoNUL(unicode: ptr[PyObject]) -> ptr[u8] {
        (s, size) = unicode_as_utf8_and_size(unicode);
        if s and i64(strlen(s)) != size {
            PyErr_SetString(PyExc_ValueError, "embedded null character");
            return ptr[u8]();
        }
        return s;
    }  def PyUnicode_GetSize(unicode: ptr[PyObject]) -> i64 {
        PyErr_SetString(PyExc_RuntimeError, "PyUnicode_GetSize has been removed.");
        return -1;
    }  def PyUnicode_GetLength(unicode: ptr[PyObject]) -> i64 {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return -1;
        }
        return uo_length(unicode);
    }  def PyUnicode_ReadChar(unicode: ptr[PyObject], index: i64) -> u32 {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return u32(0xFFFFFFFF);
        }
        if index < 0 or index >= uo_length(unicode) {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return u32(0xFFFFFFFF);
        }
        return ch_read(uo_kind(unicode), uo_data(unicode), index);
    }  def PyUnicode_WriteChar(unicode: ptr[PyObject], index: i64, ch: u32) -> i32 {
        if not unicode_check(unicode) or not uo_is_compact(unicode) {
            PyErr_BadArgument();
            return i32(-1);
        }
        if index < 0 or index >= uo_length(unicode) {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return i32(-1);
        }
        if unicode_check_modifiable(unicode) != 0 {
            return i32(-1);
        }
        if ch > uo_max_char_value(unicode) {
            PyErr_SetString(PyExc_ValueError, "character out of range");
            return i32(-1);
        }
        ch_write(uo_kind(unicode), uo_data(unicode), index, ch);
        return i32(0);
    }  def PyUnicode_GetDefaultEncoding -> ptr[u8] {
        return ptr[u8]("utf-8");
    }
}

def make_decode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    input: ptr[u8],
    length: i64,
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject];

def decode_handler_result(restuple: ptr[PyObject]) -> tuple[bool, ptr[PyObject], i64];

def decode_errorhandler_failed(
    restuple: ptr[PyObject],
    error_handler: ptr[PyObject],
    exc: ptr[PyObject],
    input: ptr[u8],
    inend: ptr[u8],
    endinpos: i64
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[u8], ptr[u8], i64, ptr[u8]];

def unicode_decode_call_errorhandler_writer(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    encoding: ptr[u8],
    reason: ptr[u8],
    input: ptr[u8],
    inend: ptr[u8],
    startinpos: i64,
    endinpos: i64,
    exc: ptr[PyObject],
    writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[u8], ptr[u8], i64, ptr[u8]];

import from c {
    glob:priv utf7_category: list[u8] = (
             b"\x03\x03\x03\x03\x03\x03\x03\x03\x03\x02\x02\x03\x03\x02\x03\x03"
             b"\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03\x03"
             b"\x02\x01\x01\x01\x01\x01\x01\x00\x00\x00\x01\x03\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x01\x00"
             b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x03\x01\x01\x01"
             b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
             b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x01\x03\x03"
         ),
         utf7_base64_chars: list[u8] = (
             b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
         );
}

def is_base64(c: u32) -> bool;

def from_base64(c: u32) -> u64;

def to_base64(n: u64) -> u8;

def decode_direct(c: u32) -> bool;

def encode_direct(c: u32, direct_o: bool, direct_ws: bool) -> bool;

def utf7_decode_fail(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def unicode_decode_utf7(
    s_in: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
) -> ptr[PyObject];

import from c {
    def PyUnicode_DecodeUTF7(s: ptr[u8], size: i64, errors: ptr[u8]) -> ptr[PyObject] {
        return unicode_decode_utf7(s, size, errors, ptr[i64]());
    }  def PyUnicode_DecodeUTF7Stateful(
        s: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        return unicode_decode_utf7(s, size, errors, consumed);
    }  def _PyUnicode_EncodeUTF7(
        str_obj: ptr[PyObject], base64SetO: i32, base64WhiteSpace: i32, errors: ptr[u8]
    ) -> ptr[PyObject] {
        kind = uo_kind(str_obj);
        data = uo_data(str_obj);
        length = uo_length(str_obj);
        if length == 0 {
            return PyBytes_FromStringAndSize(ptr[u8](), 0);
        }

        if length > PY_SSIZE_T_MAX // 8 {
            return PyErr_NoMemory();
        }
        v = PyBytes_FromStringAndSize(ptr[u8](), length * 8);
        if not v {
            return NULL;
        }
        direct_o = base64SetO == i32(0);
        direct_ws = base64WhiteSpace == i32(0);
        in_shift = False;
        base64bits = u32(0);
        base64buffer = u64(0);
        start = bytes_data(v);
        out = start;
        for i in range(length) {
            ch = ch_read(kind, data, i);
            encode_char = False;
            if in_shift {
                if encode_direct(ch, direct_o, direct_ws) {
                    if base64bits != u32(0) {
                        out.view(1)[0] = to_base64(
                            wrapping_shl(base64buffer, u64(u32(6) - base64bits))
                        );
                        out = out + 1;
                        base64buffer = u64(0);
                        base64bits = u32(0);
                    }
                    in_shift = False;

                    if is_base64(ch) or ch == u32(45) {
                        out.view(1)[0] = u8(45);
                        out = out + 1;
                    }
                    out.view(1)[0] = u8.wrap(ch);
                    out = out + 1;
                } else {
                    encode_char = True;
                }
            } elif ch == u32(43) {
                out.view(1)[0] = u8(43);
                (out + 1).view(1)[0] = u8(45);
                out = out + 2;
            } elif encode_direct(ch, direct_o, direct_ws) {
                out.view(1)[0] = u8.wrap(ch);
                out = out + 1;
            } else {
                out.view(1)[0] = u8(43);
                out = out + 1;
                in_shift = True;
                encode_char = True;
            }
            if encode_char {
                if ch >= u32(0x10000) {
                    base64bits += u32(16);
                    base64buffer = wrapping_shl(base64buffer, u64(16))
                        | u64(uc_high_surrogate(ch));
                    while base64bits >= u32(6) {
                        out.view(1)[0] = to_base64(
                            base64buffer >> u64(base64bits - u32(6))
                        );
                        out = out + 1;
                        base64bits -= u32(6);
                    }

                    ch = uc_low_surrogate(ch);
                }
                base64bits += u32(16);
                base64buffer = wrapping_shl(base64buffer, u64(16)) | u64(ch);
                while base64bits >= u32(6) {
                    out.view(1)[0] = to_base64(
                        base64buffer >> u64(base64bits - u32(6))
                    );
                    out = out + 1;
                    base64bits -= u32(6);
                }
            }
        }
        if base64bits != u32(0) {
            out.view(1)[0] = to_base64(
                wrapping_shl(base64buffer, u64(u32(6) - base64bits))
            );
            out = out + 1;
        }
        if in_shift {
            out.view(1)[0] = u8(45);
            out = out + 1;
        }
        if _PyBytes_Resize(&mut v, int(out) - int(start)) < i32(0) {
            return NULL;
        }
        return v;
    }
}

import from c {
    def PyUnicode_DecodeUTF8(s: ptr[u8], size: i64, errors: ptr[u8]) -> ptr[PyObject] {
        handler = _Py_ERROR_STRICT;
        if errors {
            handler = _Py_ERROR_UNKNOWN;
        }
        return unicode_decode_utf8(s, size, handler, errors, ptr[i64]());
    }
}

glob:priv SIZEOF_SIZE_T: i64 = 8,
     ASCII_CHAR_MASK: u64 = u64(0x8080808080808080),
     VECTOR_0101: u64 = u64(0x0101010101010101),
     VECTOR_00FF: u64 = u64(0x00ff00ff00ff00ff);

def is_continuation_byte(ch: u32) -> bool;

def ucs1lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u8], outpos: i64, max_char: u32
) -> tuple[u32, ptr[u8], i64];

def ucs2lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u16], outpos: i64
) -> tuple[u32, ptr[u8], i64];

def ucs4lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u32], outpos: i64
) -> tuple[u32, ptr[u8], i64];

def utf8_encode_surrogates(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    kind: i64,
    data: ptr[u8],
    size: i64,
    max_char_size: i64,
    p_in: ptr[u8],
    i_in: i64,
    error_handler_in: i32,
    errors: ptr[u8],
    error_handler_obj_in: ptr[PyObject],
    exc_in: ptr[PyObject]
) -> tuple[ptr[u8], i64, i32, ptr[PyObject], ptr[PyObject]];

def ucs1lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8]
) -> ptr[u8];

def ucs2lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u16],
    size: i64,
    error_handler_in: i32,
    errors: ptr[u8]
) -> ptr[u8];

def ucs4lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u32],
    size: i64,
    error_handler_in: i32,
    errors: ptr[u8]
) -> ptr[u8];

def utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    kind: i64,
    data: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8]
) -> ptr[u8];

def ctz(v_in: u64) -> i64;

def load_unaligned(p: ptr[u8], size: i64) -> u64;

def find_first_nonascii(start: ptr[u8], end: ptr[u8]) -> i64;

def scalar_utf8_start_char(ch: u32) -> i64;

def vector_utf8_start_chars(v: u64) -> u64;

def utf8_count_codepoints(s_in: ptr[u8], end: ptr[u8]) -> i64;

def ascii_decode(start: ptr[u8], end: ptr[u8], dest: ptr[u8]) -> i64;

def utf8_decode_into_writer(
    writer: ptr[UnicodeWriter], s: ptr[u8], end: ptr[u8]
) -> tuple[u32, ptr[u8]];

def utf8_decode_fail(error_handler_obj: ptr[PyObject], exc: ptr[PyObject]) -> i32;

def unicode_decode_utf8_impl(
    writer: ptr[UnicodeWriter],
    starts_in: ptr[u8],
    s_in: ptr[u8],
    end_in: ptr[u8],
    error_handler_in: i32,
    errors: ptr[u8],
    consumed: ptr[i64]
) -> i32;

def unicode_decode_utf8(
    s_in: ptr[u8], size: i64, error_handler: i32, errors: ptr[u8], consumed: ptr[i64]
) -> ptr[PyObject];

def unicode_decode_utf8_writer(
    writer: ptr[UnicodeWriter],
    s_in: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8],
    consumed: ptr[i64]
) -> i32;

def decode_utf8_ex(
    s_in: ptr[u8], size: i64, errors: i32
) -> tuple[i32, ptr[i32], u64, ptr[u8]];

def encode_utf8_ex(
    text: ptr[i32], raw_malloc: i32, errors: i32
) -> tuple[i32, ptr[u8], bool, u64];

import from c {
    def PyUnicode_DecodeUTF8Stateful(
        s: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        handler = _Py_ERROR_STRICT;
        if errors {
            handler = _Py_ERROR_UNKNOWN;
        }
        return unicode_decode_utf8(s, size, handler, errors, consumed);
    }  def _Py_DecodeUTF8Ex(
        s: ptr[u8],
        size: i64,
        wstr: ptr[ptr[i32]],
        wlen: ptr[u64],
        reason: ptr[ptr[u8]],
        errors: i32
    ) -> i32 {
        (status, unicode, n, message) = decode_utf8_ex(s, size, errors);
        if status == i32(0) {
            if wlen {
                wlen.view(1)[0] = n;
            }
            wstr.view(1)[0] = unicode;
        } elif status == i32(-2) {
            if reason {
                reason.view(1)[0] = message;
            }
            if wlen {
                wlen.view(1)[0] = n;
            }
        }
        return status;
    }  def _Py_DecodeUTF8_surrogateescape(
        arg: ptr[u8], arglen: i64, wlen: ptr[u64]
    ) -> ptr[i32] {
        (res, wstr, n, unused) = decode_utf8_ex(arg, arglen, _Py_ERROR_SURROGATEESCAPE);
        if res != i32(0) {
            if wlen {
                wlen.view(1)[0] = u64.wrap(i64(res));
            }
            return ptr[i32]();
        }
        if wlen {
            wlen.view(1)[0] = n;
        }
        return wstr;
    }  def _Py_EncodeUTF8Ex(
        text: ptr[i32],
        out_str: ptr[ptr[u8]],
        error_pos: ptr[u64],
        reason: ptr[ptr[u8]],
        raw_malloc: i32,
        errors: i32
    ) -> i32 {
        (status, encoded, has_pos, pos) = encode_utf8_ex(text, raw_malloc, errors);
        if has_pos {
            if error_pos {
                error_pos.view(1)[0] = pos;
            }
        }
        if status == i32(-2) {
            if reason {
                reason.view(1)[0] = ptr[u8]("encoding error");
            }
        }
        if status == i32(0) {
            out_str.view(1)[0] = encoded;
        }
        return status;
    }
}

def unicode_encode_utf8(
    unicode: ptr[PyObject], error_handler: i32, errors: ptr[u8]
) -> ptr[PyObject];

def unicode_fill_utf8(unicode: ptr[PyObject]) -> i32;

import from c {
    def _PyUnicode_AsUTF8String(
        unicode: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return unicode_encode_utf8(unicode, _Py_ERROR_UNKNOWN, errors);
    }  def PyUnicode_AsUTF8String(unicode: ptr[PyObject]) -> ptr[PyObject] {
        return _PyUnicode_AsUTF8String(unicode, ptr[u8]());
    }
}

def codec_span(lo: ptr[u8], hi: ptr[u8]) -> i64;

def codec_writer_fail(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def codec_writer_finish(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def swab_units(value: u64) -> u64;

def swab2(ch: u32) -> u16;

def bswap32(word: u32) -> u32;

def any_surrogate4(a: u32, b: u32, c: u32, d: u32) -> bool;

def ucs1lib_utf16_decode(
    q_in: ptr[u8],
    e_in: ptr[u8],
    dest: ptr[u8],
    outpos: i64,
    native_ordering: bool,
    max_char: u32
) -> tuple[u32, ptr[u8], i64];

def ucs2lib_utf16_decode(
    q_in: ptr[u8], e_in: ptr[u8], dest: ptr[u16], outpos: i64, native_ordering: bool
) -> tuple[u32, ptr[u8], i64];

def ucs4lib_utf16_decode(
    q_in: ptr[u8], e_in: ptr[u8], dest: ptr[u32], outpos: i64, native_ordering: bool
) -> tuple[u32, ptr[u8], i64];

def ucs1lib_utf16_encode(
    inp_in: ptr[u8], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]];

def ucs2lib_utf16_encode(
    inp_in: ptr[u16], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]];

def ucs4lib_utf16_encode(
    inp_in: ptr[u32], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]];

def ucs1lib_utf32_encode(
    inp_in: ptr[u8], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]];

def ucs2_swab4(ch: u16) -> u32;

def ucs2lib_utf32_encode(
    inp_in: ptr[u16], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]];

def ucs4lib_utf32_encode(
    inp_in: ptr[u32], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]];

def make_encode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject];

def raise_encode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject];

def unicode_encode_call_errorhandler(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    encoding: ptr[u8],
    reason: ptr[u8],
    unicode: ptr[PyObject],
    exc: ptr[PyObject],
    startpos: i64,
    endpos: i64
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject], i64];

def encode_utf_fail(
    rep: ptr[PyObject],
    error_handler: ptr[PyObject],
    exc: ptr[PyObject],
    v: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyUnicode_DecodeUTF32(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32]
    ) -> ptr[PyObject] {
        return PyUnicode_DecodeUTF32Stateful(s, size, errors, byteorder, ptr[i64]());
    }  def PyUnicode_DecodeUTF32Stateful(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        starts = s;
        q = s;
        e = s + size;
        stateful = False;
        if consumed {
            stateful = True;
        }

        bo = i32(0);
        if byteorder {
            bo = byteorder.view(1)[0];
        }

        if bo == i32(0) and size >= 4 {
            head = q.view(4);
            bom = (u32(head[3]) << u32(24))
                | (u32(head[2]) << u32(16))
                | (u32(head[1]) << u32(8))
                | u32(head[0]);
            if bom == u32(0x0000FEFF) {
                bo = i32(-1);
                q = q + 4;
            } elif bom == u32(0xFFFE0000) {
                bo = i32(1);
                q = q + 4;
            }
            if byteorder {
                byteorder.view(1)[0] = bo;
            }
        }
        if q == e {
            if consumed {
                consumed.view(1)[0] = size;
            }
            return unicode_get_empty();
        }

        le = bo <= i32(0);
        encoding = ptr[u8]("utf-32-le") if le else ptr[u8]("utf-32-be");
        writer = writer_new();
        if not writer {
            return NULL;
        }
        error_handler = NULL;
        exc = NULL;
        writer.view(1)[0].min_length = (codec_span(q, e) + 3) // 4;
        if writer_prepare(writer, writer.view(1)[0].min_length, MAX_CHAR_ASCII)
            == i32(-1) {
            return codec_writer_fail(writer, error_handler, exc);
        }
        errmsg = ptr[u8]("");
        startinpos: i64 = 0;
        endinpos: i64 = 0;
        status = i32(0);
        while True {
            ch = u32(0);
            maxch = uo_max_char_value(writer.view(1)[0].buffer);
            if codec_span(q, e) >= 4 {
                kind = i64(writer.view(1)[0].kind);
                data = writer.view(1)[0].data;
                last = e - 4;
                pos = writer.view(1)[0].pos;
                if le {
                    while True {
                        word = q.view(4);
                        ch = (u32(word[3]) << u32(24))
                            | (u32(word[2]) << u32(16))
                            | (u32(word[1]) << u32(8))
                            | u32(word[0]);
                        if ch > maxch {
                            break;
                        }
                        if kind != PyUnicode_1BYTE_KIND and uc_is_surrogate(ch) {
                            break;
                        }
                        ch_write(kind, data, pos, ch);
                        pos += 1;
                        q = q + 4;
                        if q > last {
                            break;
                        }
                    }
                } else {
                    while True {
                        word = q.view(4);
                        ch = (u32(word[0]) << u32(24))
                            | (u32(word[1]) << u32(16))
                            | (u32(word[2]) << u32(8))
                            | u32(word[3]);
                        if ch > maxch {
                            break;
                        }
                        if kind != PyUnicode_1BYTE_KIND and uc_is_surrogate(ch) {
                            break;
                        }
                        ch_write(kind, data, pos, ch);
                        pos += 1;
                        q = q + 4;
                        if q > last {
                            break;
                        }
                    }
                }
                writer.view(1)[0].pos = pos;
            }
            if uc_is_surrogate(ch) {
                errmsg = ptr[u8](
                    "code point in surrogate code point range(0xd800, 0xe000)"
                );
                startinpos = codec_span(starts, q);
                endinpos = startinpos + 4;
            } elif ch <= maxch {
                if q == e or stateful {
                    break;
                }
                errmsg = ptr[u8]("truncated data");
                startinpos = codec_span(starts, q);
                endinpos = codec_span(starts, e);
            } else {
                if ch < u32(0x110000) {
                    if writer_write_char_inline(writer, ch) < i32(0) {
                        return codec_writer_fail(writer, error_handler, exc);
                    }
                    q = q + 4;
                    continue;
                }
                errmsg = ptr[u8]("code point not in range(0x110000)");
                startinpos = codec_span(starts, q);
                endinpos = startinpos + 4;
            }

            (status, error_handler, exc, starts, e, endinpos, q) = unicode_decode_call_errorhandler_writer(
                errors,
                error_handler,
                encoding,
                errmsg,
                starts,
                e,
                startinpos,
                endinpos,
                exc,
                writer
            );
            if status != i32(0) {
                return codec_writer_fail(writer, error_handler, exc);
            }
        }
        if consumed {
            consumed.view(1)[0] = codec_span(starts, q);
        }
        return codec_writer_finish(writer, error_handler, exc);
    }  def _PyUnicode_EncodeUTF32(
        str_obj: ptr[PyObject], errors: ptr[u8], byteorder: i32
    ) -> ptr[PyObject] {
        native_ordering = byteorder <= i32(0);
        error_handler = NULL;
        exc = NULL;
        rep = NULL;
        if not unicode_check(str_obj) {
            PyErr_BadArgument();
            return NULL;
        }
        kind = uo_kind(str_obj);
        data = uo_data(str_obj);
        length = uo_length(str_obj);
        bom: i64 = 1 if byteorder == i32(0) else 0;
        if length > PY_SSIZE_T_MAX // 4 - bom {
            return PyErr_NoMemory();
        }
        nsize = length + bom;
        v: ptr[PyObject] = PyBytes_FromStringAndSize(ptr[u8](), nsize * 4);
        if not v {
            return NULL;
        }

        out = ptr[u32](bytes_data(v));
        if byteorder == i32(0) {
            out.view(1)[0] = u32(0xFEFF);
            out = out + 1;
        }
        if length == 0 {
            return v;
        }
        encoding = ptr[u8]("utf-32");
        if byteorder == i32(-1) {
            encoding = ptr[u8]("utf-32-le");
        } elif byteorder == i32(1) {
            encoding = ptr[u8]("utf-32-be");
        }
        done: i64 = 0;
        if kind == PyUnicode_1BYTE_KIND {
            (done, out) = ucs1lib_utf32_encode(data, length, out, native_ordering);
            return v;
        }
        pos: i64 = 0;
        newpos: i64 = 0;
        repsize: i64 = 0;
        moreunits: i64 = 0;
        while pos < length {
            if kind == PyUnicode_2BYTE_KIND {
                (done, out) = ucs2lib_utf32_encode(
                    ptr[u16](data) + pos, length - pos, out, native_ordering
                );
            } else {
                (done, out) = ucs4lib_utf32_encode(
                    ptr[u32](data) + pos, length - pos, out, native_ordering
                );
            }
            pos += done;
            if pos == length {
                break;
            }
            (rep, error_handler, exc, newpos) = unicode_encode_call_errorhandler(
                errors,
                error_handler,
                encoding,
                ptr[u8]("surrogates not allowed"),
                str_obj,
                exc,
                pos,
                pos + 1
            );
            if not rep {
                return encode_utf_fail(rep, error_handler, exc, v);
            }
            if bytes_check(rep) {
                repsize = object_size(rep);
                if (repsize & 3) != 0 {
                    exc = raise_encode_exception(
                        exc,
                        encoding,
                        str_obj,
                        pos,
                        pos + 1,
                        ptr[u8]("surrogates not allowed")
                    );
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                moreunits = repsize // 4;
            } else {
                repsize = uo_length(rep);
                moreunits = repsize;
                if not uo_is_ascii(rep) {
                    exc = raise_encode_exception(
                        exc,
                        encoding,
                        str_obj,
                        pos,
                        pos + 1,
                        ptr[u8]("surrogates not allowed")
                    );
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
            }
            moreunits += pos - newpos;
            pos = newpos;

            if moreunits > 0 {
                outpos = codec_span(bytes_data(v), ptr[u8](out)) // 4;
                if moreunits >= (PY_SSIZE_T_MAX - object_size(v)) // 4 {
                    PyErr_NoMemory();
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                if _PyBytes_Resize(&mut v, object_size(v) + 4 * moreunits) < i32(0) {
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                out = ptr[u32](bytes_data(v)) + outpos;
            }
            if bytes_check(rep) {
                memcpy(ptr(out), ptr(bytes_data(rep)), u64(repsize));
                out = out + repsize // 4;
            } else {
                (done, out) = ucs1lib_utf32_encode(
                    uo_data(rep), repsize, out, native_ordering
                );
            }
            object_decref(rep);
            rep = NULL;
        }

        nsize = codec_span(bytes_data(v), ptr[u8](out));
        if nsize != object_size(v) {
            _PyBytes_Resize(&mut v, nsize);
        }
        object_xdecref(error_handler);
        object_xdecref(exc);
        return v;
    }  def PyUnicode_AsUTF32String(unicode: ptr[PyObject]) -> ptr[PyObject] {
        return _PyUnicode_EncodeUTF32(unicode, ptr[u8](), i32(0));
    }
}

import from c {
    def PyUnicode_DecodeUTF16(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32]
    ) -> ptr[PyObject] {
        return PyUnicode_DecodeUTF16Stateful(s, size, errors, byteorder, ptr[i64]());
    }  def PyUnicode_DecodeUTF16Stateful(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        starts = s;
        q = s;
        e = s + size;
        stateful = False;
        if consumed {
            stateful = True;
        }

        bo = i32(0);
        if byteorder {
            bo = byteorder.view(1)[0];
        }

        if bo == i32(0) and size >= 2 {
            bom = (u32((q + 1).view(1)[0]) << u32(8)) | u32(q.view(1)[0]);
            if bom == u32(0xFEFF) {
                q = q + 2;
                bo = i32(-1);
            } elif bom == u32(0xFFFE) {
                q = q + 2;
                bo = i32(1);
            }
            if byteorder {
                byteorder.view(1)[0] = bo;
            }
        }
        if q == e {
            if consumed {
                consumed.view(1)[0] = size;
            }
            return unicode_get_empty();
        }

        native_ordering = bo <= i32(0);
        encoding = ptr[u8]("utf-16-le") if bo <= i32(0) else ptr[u8]("utf-16-be");

        writer = writer_new();
        if not writer {
            return NULL;
        }
        error_handler = NULL;
        exc = NULL;
        writer.view(1)[0].min_length = (codec_span(q, e) + 1) // 2;
        if writer_prepare(writer, writer.view(1)[0].min_length, MAX_CHAR_ASCII)
            == i32(-1) {
            return codec_writer_fail(writer, error_handler, exc);
        }
        errmsg = ptr[u8]("");
        startinpos: i64 = 0;
        endinpos: i64 = 0;
        status = i32(0);
        while True {
            ch = u32(0);
            if codec_span(q, e) >= 2 {
                kind = i64(writer.view(1)[0].kind);
                pos = writer.view(1)[0].pos;
                if kind == PyUnicode_1BYTE_KIND {
                    if uo_is_ascii(writer.view(1)[0].buffer) {
                        (ch, q, pos) = ucs1lib_utf16_decode(
                            q,
                            e,
                            writer.view(1)[0].data,
                            pos,
                            native_ordering,
                            MAX_CHAR_ASCII
                        );
                    } else {
                        (ch, q, pos) = ucs1lib_utf16_decode(
                            q,
                            e,
                            writer.view(1)[0].data,
                            pos,
                            native_ordering,
                            MAX_CHAR_UCS1
                        );
                    }
                } elif kind == PyUnicode_2BYTE_KIND {
                    (ch, q, pos) = ucs2lib_utf16_decode(
                        q, e, ptr[u16](writer.view(1)[0].data), pos, native_ordering
                    );
                } else {
                    (ch, q, pos) = ucs4lib_utf16_decode(
                        q, e, ptr[u32](writer.view(1)[0].data), pos, native_ordering
                    );
                }
                writer.view(1)[0].pos = pos;
            }
            if ch == u32(0) {
                if q == e or stateful {
                    break;
                }
                errmsg = ptr[u8]("truncated data");
                startinpos = codec_span(starts, q);
                endinpos = codec_span(starts, e);
            } elif ch == u32(1) {
                q = q - 2;
                if stateful {
                    break;
                }
                errmsg = ptr[u8]("unexpected end of data");
                startinpos = codec_span(starts, q);
                endinpos = codec_span(starts, e);
            } elif ch == u32(2) {
                errmsg = ptr[u8]("illegal encoding");
                startinpos = codec_span(starts, q) - 2;
                endinpos = startinpos + 2;
            } elif ch == u32(3) {
                errmsg = ptr[u8]("illegal UTF-16 surrogate");
                startinpos = codec_span(starts, q) - 4;
                endinpos = startinpos + 2;
            } else {
                if writer_write_char_inline(writer, ch) < i32(0) {
                    return codec_writer_fail(writer, error_handler, exc);
                }
                continue;
            }

            (status, error_handler, exc, starts, e, endinpos, q) = unicode_decode_call_errorhandler_writer(
                errors,
                error_handler,
                encoding,
                errmsg,
                starts,
                e,
                startinpos,
                endinpos,
                exc,
                writer
            );
            if status != i32(0) {
                return codec_writer_fail(writer, error_handler, exc);
            }
        }
        if consumed {
            consumed.view(1)[0] = codec_span(starts, q);
        }
        return codec_writer_finish(writer, error_handler, exc);
    }  def _PyUnicode_EncodeUTF16(
        str_obj: ptr[PyObject], errors: ptr[u8], byteorder: i32
    ) -> ptr[PyObject] {
        native_ordering = byteorder <= i32(0);
        error_handler = NULL;
        exc = NULL;
        rep = NULL;
        if not unicode_check(str_obj) {
            PyErr_BadArgument();
            return NULL;
        }
        kind = uo_kind(str_obj);
        data = uo_data(str_obj);
        length = uo_length(str_obj);
        pairs: i64 = 0;
        if kind == PyUnicode_4BYTE_KIND {
            wide = ptr[u32](data);
            for k in range(length) {
                if (wide + k).view(1)[0] >= u32(0x10000) {
                    pairs += 1;
                }
            }
        }
        bom: i64 = 1 if byteorder == i32(0) else 0;
        if length > PY_SSIZE_T_MAX // 2 - pairs - bom {
            return PyErr_NoMemory();
        }
        nsize = length + pairs + bom;
        v: ptr[PyObject] = PyBytes_FromStringAndSize(ptr[u8](), nsize * 2);
        if not v {
            return NULL;
        }

        out = ptr[u16](bytes_data(v));
        if byteorder == i32(0) {
            out.view(1)[0] = u16(0xFEFF);
            out = out + 1;
        }
        if length == 0 {
            return v;
        }
        done: i64 = 0;
        if kind == PyUnicode_1BYTE_KIND {
            (done, out) = ucs1lib_utf16_encode(data, length, out, native_ordering);
            return v;
        }
        encoding = ptr[u8]("utf-16");
        if byteorder < i32(0) {
            encoding = ptr[u8]("utf-16-le");
        } elif byteorder > i32(0) {
            encoding = ptr[u8]("utf-16-be");
        }
        pos: i64 = 0;
        newpos: i64 = 0;
        repsize: i64 = 0;
        moreunits: i64 = 0;
        while pos < length {
            if kind == PyUnicode_2BYTE_KIND {
                (done, out) = ucs2lib_utf16_encode(
                    ptr[u16](data) + pos, length - pos, out, native_ordering
                );
            } else {
                (done, out) = ucs4lib_utf16_encode(
                    ptr[u32](data) + pos, length - pos, out, native_ordering
                );
            }
            pos += done;
            if pos == length {
                break;
            }
            (rep, error_handler, exc, newpos) = unicode_encode_call_errorhandler(
                errors,
                error_handler,
                encoding,
                ptr[u8]("surrogates not allowed"),
                str_obj,
                exc,
                pos,
                pos + 1
            );
            if not rep {
                return encode_utf_fail(rep, error_handler, exc, v);
            }
            if bytes_check(rep) {
                repsize = object_size(rep);
                if (repsize & 1) != 0 {
                    exc = raise_encode_exception(
                        exc,
                        encoding,
                        str_obj,
                        pos,
                        pos + 1,
                        ptr[u8]("surrogates not allowed")
                    );
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                moreunits = repsize // 2;
            } else {
                repsize = uo_length(rep);
                moreunits = repsize;
                if not uo_is_ascii(rep) {
                    exc = raise_encode_exception(
                        exc,
                        encoding,
                        str_obj,
                        pos,
                        pos + 1,
                        ptr[u8]("surrogates not allowed")
                    );
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
            }
            moreunits += pos - newpos;
            pos = newpos;

            if moreunits > 0 {
                outpos = codec_span(bytes_data(v), ptr[u8](out)) // 2;
                if moreunits >= (PY_SSIZE_T_MAX - object_size(v)) // 2 {
                    PyErr_NoMemory();
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                if _PyBytes_Resize(&mut v, object_size(v) + 2 * moreunits) < i32(0) {
                    return encode_utf_fail(rep, error_handler, exc, v);
                }
                out = ptr[u16](bytes_data(v)) + outpos;
            }
            if bytes_check(rep) {
                memcpy(ptr(out), ptr(bytes_data(rep)), u64(repsize));
                out = out + repsize // 2;
            } else {
                (done, out) = ucs1lib_utf16_encode(
                    uo_data(rep), repsize, out, native_ordering
                );
            }
            object_decref(rep);
            rep = NULL;
        }

        nsize = codec_span(bytes_data(v), ptr[u8](out));
        if nsize != object_size(v) {
            _PyBytes_Resize(&mut v, nsize);
        }
        object_xdecref(error_handler);
        object_xdecref(exc);
        return v;
    }  def PyUnicode_AsUTF16String(unicode: ptr[PyObject]) -> ptr[PyObject] {
        return _PyUnicode_EncodeUTF16(unicode, ptr[u8](), i32(0));
    }
}

import from c {
    obj UcnhashCAPI {
        has getname: Callable[[u32, ptr[u8], i32, i32], i32],
            getcode: Callable[[ptr[u8], i32, ptr[u32], i32], i32];
    }  glob:priv ucnhash_code_slot: u32 = u32(0); def _PyUnicode_GetNameCAPI -> ptr[
        UcnhashCAPI
    ] {
        slot = ptr[ptr](
            interp_at(current_interp(), PyInterpreterState_UNICODE_UCNHASH_CAPI)
        );
        ucnhash_capi = slot.view(1)[0];
        if not ucnhash_capi {
            ucnhash_capi = PyCapsule_Import(
                ptr[u8]("unicodedata._ucnhash_CAPI"), i32(1)
            );
            slot.view(1)[0] = ucnhash_capi;
        }
        return ptr[UcnhashCAPI](ucnhash_capi);
    }
}

def escape_write_char(writer: ptr[UnicodeWriter], ch: u32) -> i32;

def escape_write_ascii(writer: ptr[UnicodeWriter], ch: u32);

def decode_unicode_escape(
    s_in: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
) -> tuple[ptr[PyObject], i32, ptr[u8]];

import from c {
    def _PyUnicode_DecodeUnicodeEscapeInternal2(
        s: ptr[u8],
        size: i64,
        errors: ptr[u8],
        consumed: ptr[i64],
        first_invalid_escape_char: ptr[i32],
        first_invalid_escape_ptr: ptr[ptr[u8]]
    ) -> ptr[PyObject] {
        (result, first_char, first_ptr) = decode_unicode_escape(
            s, size, errors, consumed
        );
        first_invalid_escape_char.view(1)[0] = first_char;
        first_invalid_escape_ptr.view(1)[0] = first_ptr;
        return result;
    }  def _PyUnicode_DecodeUnicodeEscapeStateful(
        s: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        (result, first_char, first_ptr) = decode_unicode_escape(
            s, size, errors, consumed
        );
        if not result {
            return NULL;
        }
        if first_char != i32(-1) {
            warned = i32(0);
            if first_char > i32(0xff) {
                warned = PyErr_WarnFormat(
                    PyExc_DeprecationWarning,
                    1,
                    "\"\\%o\" is an invalid octal escape sequence. Such sequences will not work in the future. ",
                    first_char
                );
            } else {
                warned = PyErr_WarnFormat(
                    PyExc_DeprecationWarning,
                    1,
                    "\"\\%c\" is an invalid escape sequence. Such sequences will not work in the future. ",
                    first_char
                );
            }
            if warned < i32(0) {
                object_decref(result);
                return NULL;
            }
        }
        return result;
    }  def PyUnicode_DecodeUnicodeEscape(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject] {
        return _PyUnicode_DecodeUnicodeEscapeStateful(s, size, errors, ptr[i64]());
    }  def PyUnicode_AsUnicodeEscapeString(unicode: ptr[PyObject]) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        length = uo_length(unicode);
        if length == 0 {
            return PyBytes_FromStringAndSize(ptr[u8](), 0);
        }
        kind = uo_kind(unicode);
        data = uo_data(unicode);
        expandsize = kind * 2 + 2;
        if length > PY_SSIZE_T_MAX // expandsize {
            return PyErr_NoMemory();
        }
        result: ptr[PyObject] = PyBytes_FromStringAndSize(
            ptr[u8](), expandsize * length
        );
        if not result {
            return NULL;
        }
        p = bytes_data(result);
        for i in range(length) {
            ch = ch_read(kind, data, i);
            if ch < u32(0x100) {
                if ch >= u32(32) and ch < u32(127) {
                    if ch != u32(92) {
                        p = emit_byte(p, u8.wrap(ch));
                    } else {
                        p = emit_byte(p, u8(92));
                        p = emit_byte(p, u8(92));
                    }
                } elif ch == u32(9) {
                    p = emit_byte(p, u8(92));
                    p = emit_byte(p, u8(116));
                } elif ch == u32(10) {
                    p = emit_byte(p, u8(92));
                    p = emit_byte(p, u8(110));
                } elif ch == u32(13) {
                    p = emit_byte(p, u8(92));
                    p = emit_byte(p, u8(114));
                } else {
                    p = emit_byte(p, u8(92));
                    p = emit_byte(p, u8(120));
                    p = emit_byte(p, hexdigit_of((ch >> u32(4)) & u32(0xF)));
                    p = emit_byte(p, hexdigit_of(ch & u32(0xF)));
                }
            } elif ch < u32(0x10000) {
                p = emit_byte(p, u8(92));
                p = emit_byte(p, u8(117));
                p = emit_byte(p, hexdigit_of((ch >> u32(12)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(8)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(4)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of(ch & u32(0xF)));
            } else {
                p = emit_byte(p, u8(92));
                p = emit_byte(p, u8(85));
                p = emit_byte(p, u8(48));
                p = emit_byte(p, u8(48));
                p = emit_byte(p, hexdigit_of((ch >> u32(20)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(16)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(12)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(8)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(4)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of(ch & u32(0xF)));
            }
        }
        if _PyBytes_Resize(&mut result, codec_span(bytes_data(result), p)) < i32(0) {
            return NULL;
        }
        return result;
    }
}

import from c {
    def _PyUnicode_DecodeRawUnicodeEscapeStateful(
        s_in: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
    ) -> ptr[PyObject] {
        stateful = False;
        if consumed {
            stateful = True;
        }
        if size == 0 {
            if consumed {
                consumed.view(1)[0] = 0;
            }
            return unicode_get_empty();
        }

        writer = writer_new();
        if not writer {
            return NULL;
        }
        error_handler = NULL;
        exc = NULL;
        writer.view(1)[0].min_length = size;
        if writer_prepare(writer, size, MAX_CHAR_ASCII) < i32(0) {
            return codec_writer_fail(writer, error_handler, exc);
        }
        starts = s_in;
        s = s_in;
        end = s_in + size;
        message = ptr[u8]();
        ch = u32(0);
        count: i64 = 0;
        startinpos: i64 = 0;
        endinpos: i64 = 0;
        status = i32(0);
        while s < end {
            c = s.view(1)[0];
            s = s + 1;

            if c != u8(92) or (s >= end and not stateful) {
                if escape_write_char(writer, u32(c)) < i32(0) {
                    return codec_writer_fail(writer, error_handler, exc);
                }
                continue;
            }
            startinpos = codec_span(starts, s) - 1;
            incomplete = False;
            bad = False;

            if s >= end {
                message = ptr[u8]("\\ at end of string");
                incomplete = True;
            } else {
                c = s.view(1)[0];
                s = s + 1;
                if c == u8(117) {
                    count = 4;
                    message = ptr[u8]("truncated \\uXXXX escape");
                } elif c == u8(85) {
                    count = 8;
                    message = ptr[u8]("truncated \\UXXXXXXXX escape");
                } else {
                    escape_write_ascii(writer, u32(92));
                    if escape_write_char(writer, u32(c)) < i32(0) {
                        return codec_writer_fail(writer, error_handler, exc);
                    }
                    continue;
                }
                ch = u32(0);
                while count > 0 {
                    if s >= end {
                        incomplete = True;
                        break;
                    }
                    c = s.view(1)[0];
                    ch = ch << u32(4);
                    if c >= u8(48) and c <= u8(57) {
                        ch += u32(c) - u32(48);
                    } elif c >= u8(97) and c <= u8(102) {
                        ch += u32(c) - u32(87);
                    } elif c >= u8(65) and c <= u8(70) {
                        ch += u32(c) - u32(55);
                    } else {
                        bad = True;
                        break;
                    }
                    s = s + 1;
                    count -= 1;
                }
                if not incomplete and not bad {
                    if ch > MAX_UNICODE {
                        message = ptr[u8]("\\Uxxxxxxxx out of range");
                    } else {
                        if escape_write_char(writer, ch) < i32(0) {
                            return codec_writer_fail(writer, error_handler, exc);
                        }
                        continue;
                    }
                }
            }

            if incomplete and stateful {
                consumed.view(1)[0] = startinpos;
                break;
            }

            endinpos = codec_span(starts, s);
            writer.view(1)[0].min_length = codec_span(s, end) + writer.view(1)[0].pos;
            (status, error_handler, exc, starts, end, endinpos, s) = unicode_decode_call_errorhandler_writer(
                errors,
                error_handler,
                ptr[u8]("rawunicodeescape"),
                message,
                starts,
                end,
                startinpos,
                endinpos,
                exc,
                writer
            );
            if status != i32(0) {
                return codec_writer_fail(writer, error_handler, exc);
            }
        }
        return codec_writer_finish(writer, error_handler, exc);
    }  def PyUnicode_DecodeRawUnicodeEscape(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject] {
        return _PyUnicode_DecodeRawUnicodeEscapeStateful(s, size, errors, ptr[i64]());
    }  def PyUnicode_AsRawUnicodeEscapeString(unicode: ptr[PyObject]) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        kind = uo_kind(unicode);
        data = uo_data(unicode);
        length = uo_length(unicode);
        if kind == PyUnicode_1BYTE_KIND {
            return PyBytes_FromStringAndSize(data, length);
        }

        expandsize = kind * 2 + 2;
        if length > PY_SSIZE_T_MAX // expandsize {
            return PyErr_NoMemory();
        }
        result: ptr[PyObject] = PyBytes_FromStringAndSize(
            ptr[u8](), expandsize * length
        );
        if not result {
            return NULL;
        }
        if length == 0 {
            return result;
        }
        p = bytes_data(result);
        for pos in range(length) {
            ch = ch_read(kind, data, pos);
            if ch < u32(0x100) {
                p = emit_byte(p, u8.wrap(ch));
            } elif ch < u32(0x10000) {
                p = emit_byte(p, u8(92));
                p = emit_byte(p, u8(117));
                p = emit_byte(p, hexdigit_of((ch >> u32(12)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(8)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(4)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of(ch & u32(0xF)));
            } else {
                p = emit_byte(p, u8(92));
                p = emit_byte(p, u8(85));
                p = emit_byte(p, u8(48));
                p = emit_byte(p, u8(48));
                p = emit_byte(p, hexdigit_of((ch >> u32(20)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(16)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(12)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(8)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of((ch >> u32(4)) & u32(0xF)));
                p = emit_byte(p, hexdigit_of(ch & u32(0xF)));
            }
        }
        if _PyBytes_Resize(&mut result, codec_span(bytes_data(result), p)) < i32(0) {
            return NULL;
        }
        return result;
    }
}

import from c {
    def PyUnicode_DecodeLatin1(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject] {
        return _PyUnicode_FromUCS1(s, size);
    }
}

def encode_ucs1_fail(
    writer: ptr[BytesWriterFields],
    rep: ptr[PyObject],
    error_handler_obj: ptr[PyObject],
    exc: ptr[PyObject]
) -> ptr[PyObject];

def unicode_encode_ucs1(
    unicode: ptr[PyObject], errors: ptr[u8], limit: u32
) -> ptr[PyObject];

import from c {
    def _PyUnicode_AsLatin1String(
        unicode: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }

        if uo_kind(unicode) == PyUnicode_1BYTE_KIND {
            return PyBytes_FromStringAndSize(uo_data(unicode), uo_length(unicode));
        }

        return unicode_encode_ucs1(unicode, errors, u32(256));
    }  def PyUnicode_AsLatin1String(unicode: ptr[PyObject]) -> ptr[PyObject] {
        return _PyUnicode_AsLatin1String(unicode, ptr[u8]());
    }
}

import from c {
    def PyUnicode_DecodeASCII(s: ptr[u8], size: i64, errors: ptr[u8]) -> ptr[PyObject] {
        if size == 0 {
            return unicode_get_empty();
        }

        if size == 1 and s.view(1)[0] < u8(128) {
            return get_latin1_char(s.view(1)[0]);
        }

        u = PyUnicode_New(size, MAX_CHAR_ASCII);
        if not u {
            return NULL;
        }
        e = s + size;
        outpos = ascii_decode(s, e, uo_data(u));
        if outpos == size {
            return u;
        }
        writer = writer_new();
        if not writer {
            object_decref(u);
            return NULL;
        }
        writer_init_with_buffer(writer, u);
        writer.view(1)[0].pos = outpos;
        starts = s;
        p = s + outpos;
        kind = i64(writer.view(1)[0].kind);
        data = writer.view(1)[0].data;
        error_handler_obj = NULL;
        exc = NULL;
        error_handler = _Py_ERROR_UNKNOWN;
        startinpos: i64 = 0;
        endinpos: i64 = 0;
        status = i32(0);
        while p < e {
            c = p.view(1)[0];
            if c < u8(128) {
                ch_write(kind, data, writer.view(1)[0].pos, u32(c));
                writer.view(1)[0].pos += 1;
                p = p + 1;
                continue;
            }

            if error_handler == _Py_ERROR_UNKNOWN {
                error_handler = _Py_GetErrorHandler(errors);
            }
            if error_handler == _Py_ERROR_REPLACE
                or error_handler == _Py_ERROR_SURROGATEESCAPE {
                if writer_prepare_kind(writer, PyUnicode_2BYTE_KIND) < i32(0) {
                    return codec_writer_fail(writer, error_handler_obj, exc);
                }
                kind = i64(writer.view(1)[0].kind);
                data = writer.view(1)[0].data;
                if error_handler == _Py_ERROR_REPLACE {
                    ch_write(kind, data, writer.view(1)[0].pos, u32(0xfffd));
                } else {
                    ch_write(kind, data, writer.view(1)[0].pos, u32(c) + u32(0xdc00));
                }
                writer.view(1)[0].pos += 1;
                p = p + 1;
            } elif error_handler == _Py_ERROR_IGNORE {
                p = p + 1;
            } else {
                startinpos = codec_span(starts, p);
                endinpos = startinpos + 1;
                (status, error_handler_obj, exc, starts, e, endinpos, p) = unicode_decode_call_errorhandler_writer(
                    errors,
                    error_handler_obj,
                    ptr[u8]("ascii"),
                    ptr[u8]("ordinal not in range(128)"),
                    starts,
                    e,
                    startinpos,
                    endinpos,
                    exc,
                    writer
                );
                if status != i32(0) {
                    return codec_writer_fail(writer, error_handler_obj, exc);
                }
                kind = i64(writer.view(1)[0].kind);
                data = writer.view(1)[0].data;
            }
        }
        return codec_writer_finish(writer, error_handler_obj, exc);
    }  def _PyUnicode_AsASCIIString(
        unicode: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }

        if uo_is_ascii(unicode) {
            return PyBytes_FromStringAndSize(uo_data(unicode), uo_length(unicode));
        }
        return unicode_encode_ucs1(unicode, errors, u32(128));
    }  def PyUnicode_AsASCIIString(unicode: ptr[PyObject]) -> ptr[PyObject] {
        return _PyUnicode_AsASCIIString(unicode, ptr[u8]());
    }
}

glob:priv encoding_map_LEVEL1: Final[i64] = 16,
     encoding_map_COUNT2: Final[i64] = 48,
     encoding_map_COUNT3: Final[i64] = 52,
     encoding_map_LEVEL23: Final[i64] = 56,
     encoding_map_SIZE: Final[i64] = 64;

glob:priv enc_SUCCESS: i64 = 0,
     enc_FAILED: i64 = 1,
     enc_EXCEPTION: i64 = 2;

def charmap_decode_string(
    s_in: ptr[u8],
    size: i64,
    mapping: ptr[PyObject],
    errors: ptr[u8],
    writer: ptr[UnicodeWriter]
) -> i32;

def charmap_decode_mapping(
    s_in: ptr[u8],
    size: i64,
    mapping: ptr[PyObject],
    errors: ptr[u8],
    writer: ptr[UnicodeWriter]
) -> i32;

def charmap_decode_fail(
    item: ptr[PyObject], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> i32;

import from c {
    def PyUnicode_DecodeCharmap(
        s: ptr[u8], size: i64, mapping: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if not mapping {
            return PyUnicode_DecodeLatin1(s, size, errors);
        }
        if size == 0 {
            return unicode_get_empty();
        }
        writer = writer_new();
        if not writer {
            return NULL;
        }
        writer.view(1)[0].min_length = size;
        status = i32(0);
        if writer_prepare(writer, size, u32(127)) == -1 {
            status = i32(-1);
        } elif unicode_check_exact(mapping) {
            status = charmap_decode_string(s, size, mapping, errors, writer);
        } else {
            status = charmap_decode_mapping(s, size, mapping, errors, writer);
        }
        if status < 0 {
            _PyUnicodeWriter_Dealloc(writer);
            writer_free(writer);
            return NULL;
        }
        result = _PyUnicodeWriter_Finish(writer);
        writer_free(writer);
        return result;
    }
}

def encoding_map_type -> ptr[PyTypeObject];

def encoding_map_count2(op: ptr[PyObject]) -> i64;

def encoding_map_count3(op: ptr[PyObject]) -> i64;

def EncodingMap_size_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def EncodingMap_size(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv encoding_map_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("size"),
                 ml_meth=ptr(EncodingMap_size),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "size($self, /)\n--\n\nReturn the size (in bytes) of this object."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         EncodingMapType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT),
                 ob_size=0
             ),
             tp_name=ptr[u8]("EncodingMap"),
             tp_basicsize=encoding_map_SIZE,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_methods=addressof(encoding_map_methods)
         );
}

import from c {
    def PyUnicode_BuildEncodingMap(string: ptr[PyObject]) -> ptr[PyObject] {
        if not unicode_check(string) or uo_length(string) == 0 {
            PyErr_BadArgument();
            return NULL;
        }
        kind = uo_kind(string);
        data = uo_data(string);
        length = min(uo_length(string), 256);

        levels = ptr[u8](PyMem_Malloc(u64(32 + 512)));
        if not levels {
            return PyErr_NoMemory();
        }
        level1 = levels;
        level2 = levels + 32;
        memset(ptr(level1), i32(0xFF), u64(32));
        memset(ptr(level2), i32(0xFF), u64(512));
        need_dict = False;
        count2: i64 = 0;
        count3: i64 = 0;

        if ch_read(kind, data, 0) != u32(0) {
            need_dict = True;
        }
        i: i64 = 1;
        while i < length {
            ch = ch_read(kind, data, i);
            i += 1;
            if ch == u32(0) or ch > u32(0xFFFF) {
                need_dict = True;
                break;
            }
            if ch == u32(0xFFFE) {
                continue;
            }
            l1 = i64(ch >> 11);
            l2 = i64(ch >> 7);
            if (level1 + l1).view(1)[0] == u8(0xFF) {
                (level1 + l1).view(1)[0] = u8.wrap(count2);
                count2 += 1;
            }
            if (level2 + l2).view(1)[0] == u8(0xFF) {
                (level2 + l2).view(1)[0] = u8.wrap(count3);
                count3 += 1;
            }
        }
        if count2 >= 0xFF or count3 >= 0xFF {
            need_dict = True;
        }
        if need_dict {
            PyMem_Free(ptr(levels));
            dct = PyDict_New();
            if not dct {
                return NULL;
            }
            for idx in range(length) {
                c = ch_read(kind, data, idx);
                key = PyLong_FromLong(i64(c));
                if not key {
                    object_decref(dct);
                    return NULL;
                }
                value = PyLong_FromLong(idx);
                if not value {
                    object_decref(key);
                    object_decref(dct);
                    return NULL;
                }
                rc = PyDict_SetItem(dct, key, value);
                object_decref(key);
                object_decref(value);
                if rc < 0 {
                    object_decref(dct);
                    return NULL;
                }
            }
            return dct;
        }

        result = ptr[PyObject](
            PyObject_Malloc(u64(encoding_map_SIZE + 16 * count2 + 128 * count3 - 1))
        );
        if not result {
            PyMem_Free(ptr(levels));
            return PyErr_NoMemory();
        }
        PyObject_Init(result, ptr[PyObject](encoding_map_type()));
        ptr[i32](ptr[u8](result) + encoding_map_COUNT2).view(1)[0] = i32(count2);
        ptr[i32](ptr[u8](result) + encoding_map_COUNT3).view(1)[0] = i32(count3);
        mlevel1 = ptr[u8](result) + encoding_map_LEVEL1;
        mlevel2 = ptr[u8](result) + encoding_map_LEVEL23;
        mlevel3 = mlevel2 + 16 * count2;
        jacpy_memory_copy(ptr(mlevel1), ptr(level1), 32);
        memset(ptr(mlevel2), i32(0xFF), u64(16 * count2));
        memset(ptr(mlevel3), i32(0), u64(128 * count3));
        PyMem_Free(ptr(levels));
        count3 = 0;
        i = 1;
        while i < length {
            ch = ch_read(kind, data, i);
            if ch != u32(0xFFFE) {
                o1 = i64(ch >> 11);
                o2 = i64((ch >> 7) & 0xF);
                i2 = 16 * i64((mlevel1 + o1).view(1)[0]) + o2;
                if (mlevel2 + i2).view(1)[0] == u8(0xFF) {
                    (mlevel2 + i2).view(1)[0] = u8.wrap(count3);
                    count3 += 1;
                }
                o3 = i64(ch & 0x7F);
                i3 = 128 * i64((mlevel2 + i2).view(1)[0]) + o3;
                (mlevel3 + i3).view(1)[0] = u8.wrap(i);
            }
            i += 1;
        }
        return result;
    }
}

def encoding_map_lookup(c: u32, mapping: ptr[PyObject]) -> i64;

def charmapencode_lookup(c: u32, mapping: ptr[PyObject]) -> tuple[ptr[PyObject], u8];

def charmapencode_resize(
    outobj: ptr[PyObject], requiredsize_in: i64
) -> tuple[i32, ptr[PyObject]];

def charmapencode_output(
    c: u32, mapping: ptr[PyObject], outobj: ptr[PyObject], outpos: i64
) -> tuple[i64, ptr[PyObject], i64];

def charmap_output_charref(
    ch: u32, mapping: ptr[PyObject], outobj: ptr[PyObject], outpos: i64
) -> tuple[i64, ptr[PyObject], i64];

def charmap_encoding_error(
    unicode: ptr[PyObject],
    inpos_in: i64,
    mapping: ptr[PyObject],
    exc_in: ptr[PyObject],
    error_handler_in: i32,
    error_handler_obj_in: ptr[PyObject],
    errors: ptr[u8],
    res_in: ptr[PyObject],
    respos_in: i64
) -> tuple[i32, i64, ptr[PyObject], i32, ptr[PyObject], ptr[PyObject], i64];

import from c {
    def _PyUnicode_EncodeCharmap(
        unicode: ptr[PyObject], mapping: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        size = uo_length(unicode);
        data = uo_data(unicode);
        kind = uo_kind(unicode);

        if not mapping {
            return unicode_encode_ucs1(unicode, errors, u32(256));
        }

        res = PyBytes_FromStringAndSize(ptr[u8](), size);
        if not res {
            return NULL;
        }
        if size == 0 {
            return res;
        }

        inpos: i64 = 0;

        respos: i64 = 0;
        error_handler_obj = NULL;
        exc = NULL;
        error_handler = _Py_ERROR_UNKNOWN;
        x = enc_SUCCESS;
        status = i32(0);
        failed = False;
        while inpos < size {
            ch = ch_read(kind, data, inpos);

            (x, res, respos) = charmapencode_output(ch, mapping, res, respos);
            if x == enc_EXCEPTION {
                failed = True;
                break;
            }
            if x == enc_FAILED {
                (status, inpos, exc, error_handler, error_handler_obj, res, respos) = charmap_encoding_error(
                    unicode,
                    inpos,
                    mapping,
                    exc,
                    error_handler,
                    error_handler_obj,
                    errors,
                    res,
                    respos
                );
                if status != 0 {
                    failed = True;
                    break;
                }
            } else {
                inpos += 1;
            }
        }

        if not failed and respos < object_size(res) {
            if _PyBytes_Resize(&mut res, respos) < 0 {
                failed = True;
            }
        }
        if failed {
            object_xdecref(res);
            object_xdecref(exc);
            object_xdecref(error_handler_obj);
            return NULL;
        }
        object_xdecref(exc);
        object_xdecref(error_handler_obj);
        return res;
    }  def PyUnicode_AsCharmapString(
        unicode: ptr[PyObject], mapping: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) or not mapping {
            PyErr_BadArgument();
            return NULL;
        }
        return _PyUnicode_EncodeCharmap(unicode, mapping, ptr[u8]());
    }
}

def make_translate_exception(
    exc: ptr[PyObject],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject];

def unicode_translate_call_errorhandler(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    reason: ptr[u8],
    unicode: ptr[PyObject],
    exc: ptr[PyObject],
    startpos: i64,
    endpos: i64
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject], i64];

def charmaptranslate_lookup(
    c: u32, mapping: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32];

def charmaptranslate_output(
    ch: u32, mapping: ptr[PyObject], writer: ptr[UnicodeWriter]
) -> i32;

def unicode_fast_translate_lookup(
    mapping: ptr[PyObject], ch: u8, translate: ptr[u8]
) -> i32;

def unicode_fast_translate(
    input: ptr[PyObject],
    mapping: ptr[PyObject],
    writer: ptr[UnicodeWriter],
    ignore: bool
) -> tuple[i32, i64];

def charmap_translate_fail(
    writer: ptr[UnicodeWriter], exc: ptr[PyObject], error_handler: ptr[PyObject]
) -> ptr[PyObject];

def _PyUnicode_TranslateCharmap(
    input: ptr[PyObject], mapping: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject];

import from c {
    def PyUnicode_Translate(
        str_obj: ptr[PyObject], mapping: ptr[PyObject], errors: ptr[u8]
    ) -> ptr[PyObject] {
        if ensure_unicode(str_obj) < 0 {
            return NULL;
        }
        return _PyUnicode_TranslateCharmap(str_obj, mapping, errors);
    }  def _PyUnicode_TransformDecimalAndSpaceToASCII(
        unicode: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadInternalCall();
            return NULL;
        }
        if uo_is_ascii(unicode) {
            return object_new_ref(unicode);
        }
        length = uo_length(unicode);
        result = PyUnicode_New(length, u32(127));
        if not result {
            return NULL;
        }
        out = uo_data(result);
        kind = uo_kind(unicode);
        data = uo_data(unicode);
        for i in range(length) {
            ch = ch_read(kind, data, i);
            if ch < u32(127) {
                (out + i).view(1)[0] = u8(ch);
            } elif uc_isspace(ch) {
                (out + i).view(1)[0] = u8(32);
            } else {
                decimal = uc_todecimal(ch);
                if decimal < 0 {
                    (out + i).view(1)[0] = u8(63);
                    (out + i + 1).view(1)[0] = u8(0);
                    uo_set_length(result, i + 1);
                    break;
                }
                (out + i).view(1)[0] = u8(48 + i64(decimal));
            }
        }
        return result;
    }
}

def adjust_indices(start_in: i64, end_in: i64, length: i64) -> tuple[i64, i64];

def any_find_slice(
    s1: ptr[PyObject], s2: ptr[PyObject], start_in: i64, end_in: i64, direction: i32
) -> i64;

def grouping_char(grouping: ptr[u8], i: i64) -> i64;

def GroupGenerator_next(
    grouping: ptr[u8], previous: i64, i: i64
) -> tuple[i64, i64, i64];

def InsertThousandsGrouping_fill(
    writer: ptr[UnicodeWriter],
    buffer_pos: i64,
    digits: ptr[PyObject],
    digits_pos: i64,
    n_chars: i64,
    n_zeros: i64,
    thousands_sep: ptr[PyObject],
    thousands_sep_len: i64,
    maxchar: ptr[u32],
    forward: i32
) -> tuple[i64, i64];

import from c {
    def _PyUnicode_InsertThousandsGrouping(
        writer: ptr[UnicodeWriter],
        n_buffer: i64,
        digits: ptr[PyObject],
        d_pos: i64,
        n_digits: i64,
        min_width_in: i64,
        grouping: ptr[u8],
        thousands_sep: ptr[PyObject],
        maxchar: ptr[u32],
        forward: i32
    ) -> i64 {
        min_width = max(min_width_in, 0);
        count: i64 = 0;
        n_zeros: i64 = 0;
        n_chars: i64 = 0;
        glen: i64 = 0;
        loop_broken = False;

        use_separator = False;

        remaining = n_digits;

        previous: i64 = 0;
        gi: i64 = 0;
        thousands_sep_len = uo_length(thousands_sep);
        digits_pos = d_pos;
        if forward == 0 {
            digits_pos += n_digits;
        }
        buffer_pos: i64 = 0;
        if writer {
            buffer_pos = writer.view(1)[0].pos;
            if forward == 0 {
                buffer_pos += n_buffer;
            }
        } elif forward == 0 {
            buffer_pos = n_buffer;
        }
        if not writer {
            maxchar.view(1)[0] = u32(127);
        }
        while True {
            (glen, previous, gi) = GroupGenerator_next(grouping, previous, gi);
            if glen <= 0 {
                break;
            }
            glen = min(glen, max(max(remaining, min_width), 1));
            n_zeros = max(glen - remaining, 0);
            n_chars = max(min(remaining, glen), 0);

            if use_separator {
                count += thousands_sep_len;
            }
            count += n_zeros + n_chars;

            (buffer_pos, digits_pos) = InsertThousandsGrouping_fill(
                writer,
                buffer_pos,
                digits,
                digits_pos,
                n_chars,
                n_zeros,
                thousands_sep if use_separator else NULL,
                thousands_sep_len,
                maxchar,
                forward
            );

            use_separator = True;
            remaining -= n_chars;
            min_width -= glen;
            if remaining <= 0 and min_width <= 0 {
                loop_broken = True;
                break;
            }
            min_width -= thousands_sep_len;
        }
        if not loop_broken {
            glen = max(max(remaining, min_width), 1);
            n_zeros = max(glen - remaining, 0);
            n_chars = max(min(remaining, glen), 0);

            if use_separator {
                count += thousands_sep_len;
            }
            count += n_zeros + n_chars;

            (buffer_pos, digits_pos) = InsertThousandsGrouping_fill(
                writer,
                buffer_pos,
                digits,
                digits_pos,
                n_chars,
                n_zeros,
                thousands_sep if use_separator else NULL,
                thousands_sep_len,
                maxchar,
                forward
            );
        }
        return count;
    }  def PyUnicode_Count(
        str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
    ) -> i64 {
        if ensure_unicode(str_obj) < 0 or ensure_unicode(substr) < 0 {
            return -1;
        }
        return unicode_count_impl(str_obj, substr, start, end);
    }  def PyUnicode_Find(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        start: i64,
        end: i64,
        direction: i32
    ) -> i64 {
        if ensure_unicode(str_obj) < 0 or ensure_unicode(substr) < 0 {
            return -2;
        }
        return any_find_slice(str_obj, substr, start, end, direction);
    }  def PyUnicode_FindChar(
        str_obj: ptr[PyObject], ch: u32, start_in: i64, end_in: i64, direction: i32
    ) -> i64 {
        length = uo_length(str_obj);
        (start, end) = adjust_indices(start_in, end_in, length);
        if end - start < 1 {
            return -1;
        }
        kind = uo_kind(str_obj);
        result = findchar(
            uo_data(str_obj) + kind * start, kind, end - start, ch, direction
        );
        if result == -1 {
            return -1;
        }
        return start + result;
    }
}

def tailmatch(
    self_: ptr[PyObject],
    substring: ptr[PyObject],
    start_in: i64,
    end_in: i64,
    direction: i32
) -> i32;

import from c {
    def PyUnicode_Tailmatch(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        start: i64,
        end: i64,
        direction: i32
    ) -> i64 {
        if ensure_unicode(str_obj) < 0 or ensure_unicode(substr) < 0 {
            return -1;
        }
        return i64(tailmatch(str_obj, substr, start, end, direction));
    }
}

def ascii_upper_or_lower(self_: ptr[PyObject], lower: bool) -> ptr[PyObject];

def handle_capital_sigma(kind: i64, data: ptr[u8], length: i64, i: i64) -> u32;

def lower_ucs4(
    kind: i64, data: ptr[u8], length: i64, i: i64, c: u32, mapped: ptr[u32]
) -> i32;

def do_capitalize(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_swapcase(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_upper_or_lower(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    lower: bool,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_upper(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_lower(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_casefold(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def do_title(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32];

def case_operation(self_: ptr[PyObject], which: i64) -> ptr[PyObject];

glob:priv UCS2_MEMCHR_CUT_OFF: i64 = 40,
     UCS4_MEMCHR_CUT_OFF: i64 = 15,
     SL_TABLE_SIZE: i64 = 64,
     SL_TABLE_MASK: u32 = u32(63),
     SL_MAX_SHIFT: i64 = 255,
     MASK_ASCII: u32 = u32(0xFFFFFF80),
     MASK_UCS1: u32 = u32(0xFFFFFF00),
     MASK_UCS2: u32 = u32(0xFFFF0000);

def sl_table_shift(table: ptr[u8], c: u32) -> i64;

def u2_at(s: ptr[u16], i: i64) -> u16;

def u2_find_char(s: ptr[u16], n: i64, ch: u16) -> i64;

def u2_rfind_char(s: ptr[u16], n: i64, ch: u16) -> i64;

def u2_lex_search(
    needle: ptr[u16], len_needle: i64, invert_alphabet: bool
) -> tuple[i64, i64];

def u2_factorize(needle: ptr[u16], len_needle: i64) -> tuple[i64, i64];

def u2_preprocess(
    needle: ptr[u16], len_needle: i64, table: ptr[u8]
) -> tuple[i64, i64, i64, bool];

def u2_two_way(
    haystack: ptr[u16],
    len_haystack: i64,
    needle: ptr[u16],
    len_needle: i64,
    cut: i64,
    period_in: i64,
    gap: i64,
    is_periodic: bool,
    table: ptr[u8]
) -> i64;

def u2_two_way_find(
    haystack: ptr[u16], len_haystack: i64, needle: ptr[u16], len_needle: i64
) -> i64;

def u2_two_way_count(
    haystack: ptr[u16],
    len_haystack: i64,
    needle: ptr[u16],
    len_needle: i64,
    maxcount: i64
) -> i64;

def u2_default_find(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64;

def u2_adaptive_find(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64;

def u2_default_rfind(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64;

def u2_count_char(s: ptr[u16], n: i64, p0: u16, maxcount: i64) -> i64;

def u2_count_char_no_maxcount(s: ptr[u16], n: i64, p0: u16) -> i64;

def u2_fastsearch(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64;

def u2_find_max_char(begin: ptr[u16], n: i64) -> u32;

def u4_at(s: ptr[u32], i: i64) -> u32;

def u4_find_char(s: ptr[u32], n: i64, ch: u32) -> i64;

def u4_rfind_char(s: ptr[u32], n: i64, ch: u32) -> i64;

def u4_lex_search(
    needle: ptr[u32], len_needle: i64, invert_alphabet: bool
) -> tuple[i64, i64];

def u4_factorize(needle: ptr[u32], len_needle: i64) -> tuple[i64, i64];

def u4_preprocess(
    needle: ptr[u32], len_needle: i64, table: ptr[u8]
) -> tuple[i64, i64, i64, bool];

def u4_two_way(
    haystack: ptr[u32],
    len_haystack: i64,
    needle: ptr[u32],
    len_needle: i64,
    cut: i64,
    period_in: i64,
    gap: i64,
    is_periodic: bool,
    table: ptr[u8]
) -> i64;

def u4_two_way_find(
    haystack: ptr[u32], len_haystack: i64, needle: ptr[u32], len_needle: i64
) -> i64;

def u4_two_way_count(
    haystack: ptr[u32],
    len_haystack: i64,
    needle: ptr[u32],
    len_needle: i64,
    maxcount: i64
) -> i64;

def u4_default_find(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64;

def u4_adaptive_find(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64;

def u4_default_rfind(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64;

def u4_count_char(s: ptr[u32], n: i64, p0: u32, maxcount: i64) -> i64;

def u4_count_char_no_maxcount(s: ptr[u32], n: i64, p0: u32) -> i64;

def u4_fastsearch(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64;

def u4_find_max_char(begin: ptr[u32], n: i64) -> u32;

def sl_find_char(kind: i64, s: ptr[u8], n: i64, ch: u32) -> i64;

def sl_rfind_char(kind: i64, s: ptr[u8], n: i64, ch: u32) -> i64;

def sl_fastsearch(
    kind: i64, s: ptr[u8], n: i64, p: ptr[u8], m: i64, maxcount: i64, mode: i64
) -> i64;

def sl_find(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, offset: i64
) -> i64;

def sl_rfind(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, offset: i64
) -> i64;

def sl_find_slice(
    kind: i64,
    s: ptr[u8],
    str_len: i64,
    sub: ptr[u8],
    sub_len: i64,
    start: i64,
    end: i64
) -> i64;

def sl_rfind_slice(
    kind: i64,
    s: ptr[u8],
    str_len: i64,
    sub: ptr[u8],
    sub_len: i64,
    start: i64,
    end: i64
) -> i64;

def sl_count(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, maxcount: i64
) -> i64;

def sl_find_max_char(kind: i64, s: ptr[u8], n: i64) -> u32;

glob:priv MAX_PREALLOC: i64 = 12;

def sl_prealloc_size(maxsplit: i64) -> i64;

def sl_fix_prealloc_size(lst: ptr[PyObject], count: i64);

def sl_split_add(
    kind: i64,
    is_ascii: bool,
    lst: ptr[PyObject],
    count: i64,
    s: ptr[u8],
    left: i64,
    right: i64
) -> bool;

def sl_split_append(
    kind: i64, is_ascii: bool, lst: ptr[PyObject], s: ptr[u8], left: i64, right: i64
) -> bool;

def sl_split_failed(lst: ptr[PyObject]) -> ptr[PyObject];

def sl_split_whitespace(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_split_char(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    ch: u32,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_split(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep: ptr[u8],
    sep_len: i64,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_rsplit_whitespace(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_rsplit_char(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    ch: u32,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_rsplit(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep: ptr[u8],
    sep_len: i64,
    maxcount_in: i64
) -> ptr[PyObject];

def sl_splitlines(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    keepends: i32
) -> ptr[PyObject];

def sl_partition_found(
    kind: i64,
    is_ascii: bool,
    out: ptr[PyObject],
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep_len: i64,
    pos: i64
) -> ptr[PyObject];

def sl_partition(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep: ptr[u8],
    sep_len: i64
) -> ptr[PyObject];

def sl_rpartition(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep: ptr[u8],
    sep_len: i64
) -> ptr[PyObject];

def sl_replace_1char_inplace(
    kind: i64, data: ptr[u8], start: i64, end: i64, u1: u32, u2: u32, maxcount_in: i64
);

import from c {
    def PyUnicode_Join(separator: ptr[PyObject], seq: ptr[PyObject]) -> ptr[PyObject] {
        fseq = PySequence_Fast(seq, ptr[u8]("can only join an iterable"));
        if not fseq {
            return NULL;
        }

        res = _PyUnicode_JoinArray(separator, fast_items(fseq), object_size(fseq));
        object_decref(fseq);
        return res;
    }  def _PyUnicode_JoinArray(
        separator: ptr[PyObject], items: ptr[ptr[PyObject]], seqlen: i64
    ) -> ptr[PyObject] {
        if seqlen == 0 {
            return unicode_get_empty();
        }
        sep = NULL;
        seplen: i64 = 0;
        maxchar = u32(0);
        last_obj = NULL;
        if seqlen == 1 {
            if unicode_check_exact(items.view(1)[0]) {
                return object_new_ref(items.view(1)[0]);
            }
        } else {
            if not separator {
                sep = PyUnicode_FromOrdinal(i32(32));
                if not sep {
                    return NULL;
                }
                seplen = 1;
                maxchar = u32(32);
            } else {
                if not unicode_check(separator) {
                    PyErr_Format(
                        PyExc_TypeError,
                        "separator: expected str instance, %.80s found",
                        object_type(separator).view(1)[0].tp_name
                    );
                    return NULL;
                }
                sep = object_new_ref(separator);
                seplen = uo_length(separator);
                maxchar = uo_max_char_value(separator);
            }
            last_obj = sep;
        }

        sz: i64 = 0;
        use_memcpy = True;
        i: i64 = 0;
        while i < seqlen {
            item = (items + i).view(1)[0];
            if not unicode_check(item) {
                PyErr_Format(
                    PyExc_TypeError,
                    "sequence item %zd: expected str instance, %.80s found",
                    i,
                    object_type(item).view(1)[0].tp_name
                );
                object_xdecref(sep);
                return NULL;
            }
            add_sz = u64(uo_length(item));
            item_maxchar = uo_max_char_value(item);
            if item_maxchar > maxchar {
                maxchar = item_maxchar;
            }
            if i != 0 {
                add_sz += u64(seplen);
            }
            if add_sz > u64(PY_SSIZE_T_MAX - sz) {
                PyErr_SetString(
                    PyExc_OverflowError, "join() result is too long for a Python string"
                );
                object_xdecref(sep);
                return NULL;
            }
            sz += i64(add_sz);
            if use_memcpy and last_obj {
                if uo_kind(last_obj) != uo_kind(item) {
                    use_memcpy = False;
                }
            }
            last_obj = item;
            i += 1;
        }
        res = PyUnicode_New(sz, maxchar);
        if not res {
            object_xdecref(sep);
            return NULL;
        }

        if use_memcpy {
            res_data = uo_data(res);
            kind = uo_kind(res);
            sep_data = ptr[u8]();
            if seplen != 0 {
                sep_data = uo_data(sep);
            }
            i = 0;
            while i < seqlen {
                item = (items + i).view(1)[0];

                if i != 0 and seplen != 0 {
                    memcpy(ptr(res_data), ptr(sep_data), u64(kind * seplen));
                    res_data = res_data + kind * seplen;
                }
                itemlen = uo_length(item);
                if itemlen != 0 {
                    memcpy(ptr(res_data), ptr(uo_data(item)), u64(kind * itemlen));
                    res_data = res_data + kind * itemlen;
                }
                i += 1;
            }
        } else {
            res_offset: i64 = 0;
            i = 0;
            while i < seqlen {
                item = (items + i).view(1)[0];

                if i != 0 and seplen != 0 {
                    _PyUnicode_FastCopyCharacters(res, res_offset, sep, 0, seplen);
                    res_offset += seplen;
                }
                itemlen = uo_length(item);
                if itemlen != 0 {
                    _PyUnicode_FastCopyCharacters(res, res_offset, item, 0, itemlen);
                    res_offset += itemlen;
                }
                i += 1;
            }
        }
        object_xdecref(sep);
        return res;
    }  def _PyUnicode_FastFill(
        unicode: ptr[PyObject], start: i64, length: i64, fill_char: u32
    ) {
        unicode_fill(uo_kind(unicode), uo_data(unicode), fill_char, start, length);
    }  def PyUnicode_Fill(
        unicode: ptr[PyObject], start: i64, length: i64, fill_char: u32
    ) -> i64 {
        if not unicode_check(unicode) {
            PyErr_BadInternalCall();
            return -1;
        }
        if unicode_check_modifiable(unicode) != i32(0) {
            return -1;
        }
        if start < 0 {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return -1;
        }
        if fill_char > uo_max_char_value(unicode) {
            PyErr_SetString(
                PyExc_ValueError,
                "fill character is bigger than the string maximum character"
            );
            return -1;
        }
        maxlen = uo_length(unicode) - start;
        count = maxlen if maxlen < length else length;
        if count <= 0 {
            return 0;
        }
        _PyUnicode_FastFill(unicode, start, count, fill_char);
        return count;
    }
}

def pad(self_: ptr[PyObject], left_in: i64, right_in: i64, fill: u32) -> ptr[PyObject];

import from c {
    def PyUnicode_Splitlines(string: ptr[PyObject], keepends: i32) -> ptr[PyObject] {
        if ensure_unicode(string) < i32(0) {
            return NULL;
        }
        return sl_splitlines(
            string,
            uo_kind(string),
            uo_is_ascii(string),
            uo_data(string),
            uo_length(string),
            keepends
        );
    }
}

def split(
    self_: ptr[PyObject], substring: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject];

def rsplit(
    self_: ptr[PyObject], substring: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject];

def anylib_find(
    kind: i64,
    str1: ptr[PyObject],
    buf1: ptr[u8],
    len1: i64,
    str2: ptr[PyObject],
    buf2: ptr[u8],
    len2: i64,
    offset: i64
) -> i64;

def anylib_count(
    kind: i64,
    sstr: ptr[PyObject],
    sbuf: ptr[u8],
    slen: i64,
    str1: ptr[PyObject],
    buf1: ptr[u8],
    len1: i64,
    maxcount: i64
) -> i64;

def replace_1char_inplace(u: ptr[PyObject], pos: i64, u1: u32, u2: u32, maxcount: i64);

def replace_release(
    srelease: bool,
    sbuf: ptr[u8],
    release1: bool,
    buf1: ptr[u8],
    release2: bool,
    buf2: ptr[u8]
);

def replace(
    self_: ptr[PyObject], str1: ptr[PyObject], str2: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject];

glob:priv unicode_encode_signature = CallSignature(
         "encode", ["encoding", "errors"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     unicode_expandtabs_signature = CallSignature(
         "expandtabs", ["tabsize"], 0, 1, 0, parser=PARSE_KEYWORDS
     ),
     unicode_replace_signature = CallSignature(
         "replace", ["old", "new", "count"], 2, 3, 2, parser=PARSE_KEYWORDS
     );

def clinic_ssize_arg(value: ptr[PyObject]) -> tuple[bool, i64];

def clinic_slice_bounds(args: ptr[ptr[PyObject]], nargs: i64) -> tuple[bool, i64, i64];

def unicode_title_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_title(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_capitalize_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_capitalize(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_casefold_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_casefold(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def convert_uc(obj_: ptr[PyObject]) -> tuple[bool, u32];

def unicode_center_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject];

def unicode_center(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_compare(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32;

import from c {
    def _PyUnicode_Equal(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32 {
        if str1 == str2 {
            return i32(1);
        }
        return i32(1) if unicode_eq(str1, str2) else i32(0);
    }  def PyUnicode_Equal(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32 {
        if not unicode_check(str1) {
            PyErr_Format(PyExc_TypeError, "first argument must be str, not %T", str1);
            return i32(-1);
        }
        if not unicode_check(str2) {
            PyErr_Format(PyExc_TypeError, "second argument must be str, not %T", str2);
            return i32(-1);
        }
        return _PyUnicode_Equal(str1, str2);
    }  def PyUnicode_Compare(left: ptr[PyObject], right: ptr[PyObject]) -> i32 {
        if unicode_check(left) and unicode_check(right) {
            if left == right {
                return i32(0);
            }
            return unicode_compare(left, right);
        }
        PyErr_Format(
            PyExc_TypeError,
            "Can't compare %.100s and %.100s",
            object_type(left).view(1)[0].tp_name,
            object_type(right).view(1)[0].tp_name
        );
        return i32(-1);
    }  def PyUnicode_CompareWithASCIIString(uni: ptr[PyObject], s: ptr[u8]) -> i32 {
        kind = uo_kind(uni);
        data = uo_data(uni);
        if kind == PyUnicode_1BYTE_KIND {
            len1 = u64(uo_length(uni));
            len2 = strlen(s);
            n = len1 if len1 < len2 else len2;
            cmp = memcmp(ptr(data), ptr(s), n);
            if cmp != i32(0) {
                return i32(-1) if cmp < i32(0) else i32(1);
            }
            if len1 > len2 {
                return i32(1);
            }
            if len1 < len2 {
                return i32(-1);
            }
            return i32(0);
        }

        i: i64 = 0;
        uch = u32(0);
        while True {
            uch = ch_read(kind, data, i);
            if uch == u32(0) {
                break;
            }
            c = u32((s + i).view(1)[0]);
            if c == u32(0) {
                break;
            }
            if uch != c {
                return i32(-1) if uch < c else i32(1);
            }
            i += 1;
        }

        if uo_length(uni) != i or uch != u32(0) {
            return i32(1);
        }
        if (s + i).view(1)[0] != u8(0) {
            return i32(-1);
        }
        return i32(0);
    }  def PyUnicode_EqualToUTF8(unicode: ptr[PyObject], s: ptr[u8]) -> i32 {
        return PyUnicode_EqualToUTF8AndSize(unicode, s, i64(strlen(s)));
    }  def PyUnicode_EqualToUTF8AndSize(
        unicode: ptr[PyObject], s_in: ptr[u8], size: i64
    ) -> i32 {
        if uo_is_ascii(unicode) {
            ascii_len = uo_length(unicode);
            return i32(1)
                if size == ascii_len
                    and memcmp(ptr(uo_data(unicode)), ptr(s_in), u64(ascii_len))
                        == i32(0)
                else i32(0);
        }
        utf8 = uo_utf8(unicode);
        if utf8 {
            utf8_len = uo_length(unicode)
                if uo_is_compact_ascii(unicode)
                else uo_utf8_length(unicode);
            return i32(1)
                if size == utf8_len
                    and memcmp(ptr(utf8), ptr(s_in), u64(utf8_len)) == i32(0)
                else i32(0);
        }
        length = uo_length(unicode);
        if u64.wrap(length) >= u64.wrap(size)
            or u64.wrap(length) < u64.wrap(size) // u64(4) {
            return i32(0);
        }
        s = s_in;
        ends = s_in + size;
        kind = uo_kind(unicode);
        data = uo_data(unicode);

        for i in range(length) {
            ch = ch_read(kind, data, i);
            avail = int(ends) - int(s);
            if ch < u32(0x80) {
                if avail == 0 or u32(s.view(1)[0]) != ch {
                    return i32(0);
                }
                s = s + 1;
            } elif ch < u32(0x800) {
                if avail < 2
                    or u32(s.view(1)[0]) != (u32(0xc0) | (ch >> u32(6)))
                    or u32((s + 1).view(1)[0]) != (u32(0x80) | (ch & u32(0x3f))) {
                    return i32(0);
                }
                s = s + 2;
            } elif ch < u32(0x10000) {
                if uc_is_surrogate(ch)
                    or avail < 3
                    or u32(s.view(1)[0]) != (u32(0xe0) | (ch >> u32(12)))
                    or u32((s + 1).view(1)[0])
                        != (u32(0x80) | ((ch >> u32(6)) & u32(0x3f)))
                    or u32((s + 2).view(1)[0]) != (u32(0x80) | (ch & u32(0x3f))) {
                    return i32(0);
                }
                s = s + 3;
            } else {
                if avail < 4
                    or u32(s.view(1)[0]) != (u32(0xf0) | (ch >> u32(18)))
                    or u32((s + 1).view(1)[0])
                        != (u32(0x80) | ((ch >> u32(12)) & u32(0x3f)))
                    or u32((s + 2).view(1)[0])
                        != (u32(0x80) | ((ch >> u32(6)) & u32(0x3f)))
                    or u32((s + 3).view(1)[0]) != (u32(0x80) | (ch & u32(0x3f))) {
                    return i32(0);
                }
                s = s + 4;
            }
        }
        return i32(1) if s == ends else i32(0);
    }  def _PyUnicode_EqualToASCIIString(unicode: ptr[PyObject], s: ptr[u8]) -> i32 {
        if not uo_is_ascii(unicode) {
            return i32(0);
        }
        length = u64(uo_length(unicode));
        return i32(1)
            if strlen(s) == length
                and memcmp(ptr(uo_data(unicode)), ptr(s), length) == i32(0)
            else i32(0);
    }  def _PyUnicode_EqualToASCIIId(left: ptr[PyObject], right: ptr[u8]) -> i32 {
        if not uo_is_ascii(left) {
            return i32(0);
        }

        right_uni = _PyUnicode_FromId(right);
        if not right_uni {
            PyErr_Clear();
            return _PyUnicode_EqualToASCIIString(left, ptr[ptr[u8]](right).view(1)[0]);
        }
        if left == right_uni {
            return i32(1);
        }

        if uo_interned(left) != u32(0) {
            return i32(0);
        }
        right_hash = uo_hash(right_uni);
        left_hash = uo_hash(left);
        if left_hash != -1 and left_hash != right_hash {
            return i32(0);
        }
        return i32(1) if unicode_eq(left, right_uni) else i32(0);
    }  def PyUnicode_RichCompare(
        left: ptr[PyObject], right: ptr[PyObject], op: i32
    ) -> ptr[PyObject] {
        if not unicode_check(left) or not unicode_check(right) {
            return object_new_ref(Py_NotImplemented);
        }
        if left == right {
            if op == Py_EQ or op == Py_LE or op == Py_GE {
                return PyBool_FromLong(1);
            }
            if op == Py_NE or op == Py_LT or op == Py_GT {
                return PyBool_FromLong(0);
            }
            PyErr_BadArgument();
            return NULL;
        }
        if op == Py_EQ or op == Py_NE {
            result = unicode_eq(left, right);
            if op == Py_NE {
                result = not result;
            }
            return PyBool_FromLong(1 if result else 0);
        }
        return rich_compare_values(i64(unicode_compare(left, right)), 0, op);
    }  def PyUnicode_Contains(str_obj: ptr[PyObject], substr: ptr[PyObject]) -> i32 {
        if not unicode_check(substr) {
            PyErr_Format(
                PyExc_TypeError,
                "'in <string>' requires string as left operand, not %.100s",
                object_type(substr).view(1)[0].tp_name
            );
            return i32(-1);
        }
        if ensure_unicode(str_obj) < i32(0) {
            return i32(-1);
        }
        kind1 = uo_kind(str_obj);
        kind2 = uo_kind(substr);
        if kind1 < kind2 {
            return i32(0);
        }
        len1 = uo_length(str_obj);
        len2 = uo_length(substr);
        if len1 < len2 {
            return i32(0);
        }
        buf1 = uo_data(str_obj);
        buf2 = uo_data(substr);
        if len2 == 1 {
            ch = ch_read(kind2, buf2, 0);
            return i32(1) if findchar(buf1, kind1, len1, ch, i32(1)) != -1 else i32(0);
        }
        if kind2 != kind1 {
            buf2 = unicode_askind(kind2, buf2, len2, kind1);
            if not buf2 {
                return i32(-1);
            }
        }
        result = i32(1) if sl_find(kind1, buf1, len1, buf2, len2, 0) != -1 else i32(0);
        if kind2 != kind1 {
            PyMem_Free(ptr(buf2));
        }
        return result;
    }  def PyUnicode_Concat(
        left: ptr[PyObject], right: ptr[PyObject]
    ) -> ptr[PyObject] {
        if ensure_unicode(left) < i32(0) {
            return NULL;
        }
        if not unicode_check(right) {
            PyErr_Format(
                PyExc_TypeError,
                "can only concatenate str (not \"%.200s\") to str",
                object_type(right).view(1)[0].tp_name
            );
            return NULL;
        }

        empty = unicode_get_empty();
        if left == empty {
            return PyUnicode_FromObject(right);
        }
        if right == empty {
            return PyUnicode_FromObject(left);
        }
        left_len = uo_length(left);
        right_len = uo_length(right);
        if left_len > PY_SSIZE_T_MAX - right_len {
            PyErr_SetString(PyExc_OverflowError, "strings are too large to concat");
            return NULL;
        }
        new_len = left_len + right_len;
        maxchar = uo_max_char_value(left);
        maxchar2 = uo_max_char_value(right);
        if maxchar2 > maxchar {
            maxchar = maxchar2;
        }

        result = PyUnicode_New(new_len, maxchar);
        if not result {
            return NULL;
        }
        _PyUnicode_FastCopyCharacters(result, 0, left, 0, left_len);
        _PyUnicode_FastCopyCharacters(result, left_len, right, 0, right_len);
        return result;
    }  def PyUnicode_Append(p_left: ptr[ptr[PyObject]], right: ptr[PyObject]) {
        if not p_left {
            if not PyErr_Occurred() {
                PyErr_BadInternalCall();
            }
            return;
        }
        left = p_left.view(1)[0];
        if not right
            or not left
            or not unicode_check(left)
            or not unicode_check(right) {
            if not PyErr_Occurred() {
                PyErr_BadInternalCall();
            }
            append_clear(p_left);
            return;
        }

        empty = unicode_get_empty();
        if left == empty {
            object_decref(left);
            p_left.view(1)[0] = object_new_ref(right);
            return;
        }
        if right == empty {
            return;
        }
        left_len = uo_length(left);
        right_len = uo_length(right);
        if left_len > PY_SSIZE_T_MAX - right_len {
            PyErr_SetString(PyExc_OverflowError, "strings are too large to concat");
            append_clear(p_left);
            return;
        }
        new_len = left_len + right_len;

        if unicode_modifiable(left)
            and unicode_check_exact(right)
            and uo_kind(right) <= uo_kind(left)
            and not (uo_is_ascii(left) and not uo_is_ascii(right)) {
            (status, resized) = unicode_resize(left, new_len);
            p_left.view(1)[0] = resized;
            if status != i32(0) {
                append_clear(p_left);
                return;
            }

            _PyUnicode_FastCopyCharacters(resized, left_len, right, 0, right_len);
        } else {
            maxchar = uo_max_char_value(left);
            maxchar2 = uo_max_char_value(right);
            if maxchar2 > maxchar {
                maxchar = maxchar2;
            }
            res = PyUnicode_New(new_len, maxchar);
            if not res {
                append_clear(p_left);
                return;
            }
            _PyUnicode_FastCopyCharacters(res, 0, left, 0, left_len);
            _PyUnicode_FastCopyCharacters(res, left_len, right, 0, right_len);
            object_decref(left);
            p_left.view(1)[0] = res;
        }
    }  def PyUnicode_AppendAndDel(pleft: ptr[ptr[PyObject]], right: ptr[PyObject]) {
        PyUnicode_Append(pleft, right);
        object_xdecref(right);
    }
}

def append_clear(p_left: ptr[ptr[PyObject]]);

def unicode_count_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start_in: i64, end_in: i64
) -> i64;

def unicode_count(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_encode_impl(
    self_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject];

def encode_text_arg(value: ptr[PyObject], is_errors: bool) -> tuple[bool, ptr[u8]];

def unicode_encode_with(
    self_: ptr[PyObject], encoding_obj: ptr[PyObject], errors_obj: ptr[PyObject]
) -> ptr[PyObject];

def unicode_encode_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_encode(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_expandtabs_impl(self_: ptr[PyObject], tabsize_in: i32) -> ptr[PyObject];

def unicode_expandtabs_with(
    self_: ptr[PyObject], tabsize_obj: ptr[PyObject]
) -> ptr[PyObject];

def unicode_expandtabs_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_expandtabs(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_find_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64;

def unicode_find(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_getitem(self_: ptr[PyObject], index: i64) -> ptr[PyObject];

def unicode_hash(self_: ptr[PyObject]) -> i64;

def unicode_index_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64;

def unicode_index(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_isascii_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isascii(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_islower_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_islower(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isupper_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isupper(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_istitle_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_istitle(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isspace_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isspace(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isalpha_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isalpha(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isalnum_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isalnum(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isdecimal_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isdecimal(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isdigit_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isdigit(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_isnumeric_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isnumeric(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyUnicode_ScanIdentifier(self_: ptr[PyObject]) -> i64 {
        length = uo_length(self_);
        if length == 0 {
            return 0;
        }
        kind = uo_kind(self_);
        data = uo_data(self_);
        ch = ch_read(kind, data, 0);

        if _PyUnicode_IsXidStart(ch) == i32(0) and ch != u32(0x5F) {
            return 0;
        }
        i: i64 = 1;
        while i < length {
            ch = ch_read(kind, data, i);
            if _PyUnicode_IsXidContinue(ch) == i32(0) {
                return i;
            }
            i += 1;
        }
        return i;
    }  def PyUnicode_IsIdentifier(self_: ptr[PyObject]) -> i32 {
        i = _PyUnicode_ScanIdentifier(self_);
        length = uo_length(self_);

        return i32(1) if length != 0 and i == length else i32(0);
    }
}

def unicode_isidentifier_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isidentifier(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def unicode_isprintable_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_isprintable(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_join(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def unicode_length(self_: ptr[PyObject]) -> i64;

def unicode_ljust_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject];

def unicode_ljust(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_lower_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_lower(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyUnicode_XStrip(
        self_: ptr[PyObject], striptype: i32, sepobj: ptr[PyObject]
    ) -> ptr[PyObject] {
        kind = uo_kind(self_);
        data = uo_data(self_);
        length = uo_length(self_);
        seplen = uo_length(sepobj);
        sepmask = make_bloom_mask(uo_kind(sepobj), uo_data(sepobj), seplen);
        i: i64 = 0;
        if striptype != RIGHTSTRIP {
            while i < length {
                ch = ch_read(kind, data, i);
                if not bloom(sepmask, ch) {
                    break;
                }
                if PyUnicode_FindChar(sepobj, ch, 0, seplen, i32(1)) < 0 {
                    break;
                }
                i += 1;
            }
        }
        j = length;
        if striptype != LEFTSTRIP {
            j -= 1;
            while j >= i {
                c = ch_read(kind, data, j);
                if not bloom(sepmask, c) {
                    break;
                }
                if PyUnicode_FindChar(sepobj, c, 0, seplen, i32(1)) < 0 {
                    break;
                }
                j -= 1;
            }
            j += 1;
        }
        return PyUnicode_Substring(self_, i, j);
    }  def PyUnicode_Substring(
        self_: ptr[PyObject], start: i64, end_in: i64
    ) -> ptr[PyObject] {
        length = uo_length(self_);
        end = end_in if end_in < length else length;
        if start == 0 and end == length {
            return unicode_result_unchanged(self_);
        }
        if start < 0 or end < 0 {
            PyErr_SetString(PyExc_IndexError, "string index out of range");
            return NULL;
        }
        if start >= length or end < start {
            return unicode_get_empty();
        }
        length = end - start;
        if uo_is_ascii(self_) {
            return _PyUnicode_FromASCII(uo_data(self_) + start, length);
        }

        kind = uo_kind(self_);
        return sl_new(kind, False, char_ptr(uo_data(self_), kind, start), length);
    }
}

def do_strip(self_: ptr[PyObject], striptype: i32) -> ptr[PyObject];

def do_argstrip(
    self_: ptr[PyObject], striptype: i32, sep: ptr[PyObject]
) -> ptr[PyObject];

def unicode_strip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject];

def unicode_strip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_lstrip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject];

def unicode_lstrip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_rstrip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject];

def unicode_rstrip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_repeat(str_obj: ptr[PyObject], len_: i64) -> ptr[PyObject];

import from c {
    def PyUnicode_Replace(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        replstr: ptr[PyObject],
        maxcount: i64
    ) -> ptr[PyObject] {
        if ensure_unicode(str_obj) < i32(0)
            or ensure_unicode(substr) < i32(0)
            or ensure_unicode(replstr) < i32(0) {
            return NULL;
        }
        return replace(str_obj, substr, replstr, maxcount);
    }
}

def unicode_replace_impl(
    self_: ptr[PyObject], old: ptr[PyObject], new: ptr[PyObject], count: i64
) -> ptr[PyObject];

def unicode_replace_with(
    self_: ptr[PyObject],
    old: ptr[PyObject],
    new: ptr[PyObject],
    count_obj: ptr[PyObject]
) -> ptr[PyObject];

def unicode_replace_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_replace(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_removeprefix_impl(
    self_: ptr[PyObject], prefix: ptr[PyObject]
) -> ptr[PyObject];

def unicode_removeprefix(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def unicode_removesuffix_impl(
    self_: ptr[PyObject], suffix: ptr[PyObject]
) -> ptr[PyObject];

def unicode_removesuffix(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def py_hexdigit(x: u32) -> u32;

def unicode_repr_write(unicode: ptr[PyObject], quote: u32, okind: i64, odata: ptr[u8]);

def unicode_repr(unicode: ptr[PyObject]) -> ptr[PyObject];

def unicode_rfind_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64;

def unicode_rfind(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_rindex_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64;

def unicode_rindex(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_rjust_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject];

def unicode_rjust(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

import from c {
    def PyUnicode_Split(
        s: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
    ) -> ptr[PyObject] {
        if ensure_unicode(s) < i32(0) or (sep and ensure_unicode(sep) < i32(0)) {
            return NULL;
        }
        return split(s, sep, maxsplit);
    }
}

def unicode_split_impl(
    self_: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject];

glob:priv unicode_split_signature = CallSignature(
         "split", ["sep", "maxsplit"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     unicode_rsplit_signature = CallSignature(
         "rsplit", ["sep", "maxsplit"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     unicode_splitlines_signature = CallSignature(
         "splitlines", ["keepends"], 0, 1, 0, parser=PARSE_KEYWORDS
     );

def unicode_split_args(
    self_: ptr[PyObject],
    sep_obj: ptr[PyObject],
    maxsplit_obj: ptr[PyObject],
    reverse: bool
) -> ptr[PyObject];

def unicode_split_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_split(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyUnicode_Partition(
        str_obj: ptr[PyObject], sep_obj: ptr[PyObject]
    ) -> ptr[PyObject] {
        if ensure_unicode(str_obj) < i32(0) or ensure_unicode(sep_obj) < i32(0) {
            return NULL;
        }
        kind1 = uo_kind(str_obj);
        kind2 = uo_kind(sep_obj);
        len1 = uo_length(str_obj);
        len2 = uo_length(sep_obj);
        if kind1 < kind2 or len1 < len2 {
            empty = unicode_get_empty();
            return PyTuple_Pack(3, str_obj, empty, empty);
        }
        buf1 = uo_data(str_obj);
        buf2 = uo_data(sep_obj);
        if kind2 != kind1 {
            buf2 = unicode_askind(kind2, buf2, len2, kind1);
            if not buf2 {
                return NULL;
            }
        }

        out = sl_partition(
            str_obj,
            kind1,
            uo_is_ascii(str_obj) and uo_is_ascii(sep_obj),
            buf1,
            len1,
            sep_obj,
            buf2,
            len2
        );
        if kind2 != kind1 {
            PyMem_Free(ptr(buf2));
        }
        return out;
    }  def PyUnicode_RPartition(
        str_obj: ptr[PyObject], sep_obj: ptr[PyObject]
    ) -> ptr[PyObject] {
        if ensure_unicode(str_obj) < i32(0) or ensure_unicode(sep_obj) < i32(0) {
            return NULL;
        }
        kind1 = uo_kind(str_obj);
        kind2 = uo_kind(sep_obj);
        len1 = uo_length(str_obj);
        len2 = uo_length(sep_obj);
        if kind1 < kind2 or len1 < len2 {
            empty = unicode_get_empty();
            return PyTuple_Pack(3, empty, empty, str_obj);
        }
        buf1 = uo_data(str_obj);
        buf2 = uo_data(sep_obj);
        if kind2 != kind1 {
            buf2 = unicode_askind(kind2, buf2, len2, kind1);
            if not buf2 {
                return NULL;
            }
        }
        out = sl_rpartition(
            str_obj,
            kind1,
            uo_is_ascii(str_obj) and uo_is_ascii(sep_obj),
            buf1,
            len1,
            sep_obj,
            buf2,
            len2
        );
        if kind2 != kind1 {
            PyMem_Free(ptr(buf2));
        }
        return out;
    }
}

def unicode_partition(self_: ptr[PyObject], sep: ptr[PyObject]) -> ptr[PyObject];

def unicode_rpartition(self_: ptr[PyObject], sep: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyUnicode_RSplit(
        s: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
    ) -> ptr[PyObject] {
        if ensure_unicode(s) < i32(0) or (sep and ensure_unicode(sep) < i32(0)) {
            return NULL;
        }
        return rsplit(s, sep, maxsplit);
    }
}

def unicode_rsplit_impl(
    self_: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject];

def unicode_rsplit_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_rsplit(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_splitlines_impl(self_: ptr[PyObject], keepends: i32) -> ptr[PyObject];

def unicode_splitlines_args(
    self_: ptr[PyObject], keepends_obj: ptr[PyObject]
) -> ptr[PyObject];

def unicode_splitlines_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_splitlines(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_str(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_swapcase_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_swapcase(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_maketrans_from_dict(x: ptr[PyObject], newdict: ptr[PyObject]) -> i32;

def unicode_maketrans_impl(
    x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]
) -> ptr[PyObject];

def unicode_maketrans(
    null: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_translate(self_: ptr[PyObject], table: ptr[PyObject]) -> ptr[PyObject];

def unicode_upper_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_upper(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_zfill_impl(self_: ptr[PyObject], width: i64) -> ptr[PyObject];

def unicode_zfill(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def unicode_startswith_impl(
    self_: ptr[PyObject], subobj: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def unicode_startswith(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_endswith_impl(
    self_: ptr[PyObject], subobj: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def unicode_endswith(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def unicode_writers_pop -> ptr;

def unicode_writers_free(block: ptr);

import from c {
    def _PyUnicodeWriter_Init(writer: ptr[UnicodeWriter]) {
        memset(ptr(writer), i32(0), u64(_PyUnicodeWriter_SIZE));

        writer.view(1)[0].min_char = u32(127);
    }  def PyUnicodeWriter_Create(length: i64) -> ptr[PyUnicodeWriter] {
        if length < 0 {
            PyErr_SetString(PyExc_ValueError, "length must be positive");
            return ptr[PyUnicodeWriter]();
        }
        pub_writer = ptr[PyUnicodeWriter](unicode_writers_pop());
        if not pub_writer {
            pub_writer = ptr[PyUnicodeWriter](PyMem_Malloc(u64(_PyUnicodeWriter_SIZE)));
            if not pub_writer {
                PyErr_NoMemory();
                return ptr[PyUnicodeWriter]();
            }
        }
        writer = ptr[UnicodeWriter](pub_writer);
        _PyUnicodeWriter_Init(writer);
        if writer_prepare(writer, length, u32(127)) < i32(0) {
            PyUnicodeWriter_Discard(pub_writer);
            return ptr[PyUnicodeWriter]();
        }
        writer.view(1)[0].overallocate = u8(1);
        return pub_writer;
    }  def PyUnicodeWriter_Discard(writer: ptr[PyUnicodeWriter]) {
        if not writer {
            return;
        }
        _PyUnicodeWriter_Dealloc(ptr[UnicodeWriter](writer));
        unicode_writers_free(ptr(writer));
    }  def _PyUnicodeWriter_PrepareInternal(
        writer: ptr[UnicodeWriter], length: i64, maxchar_in: u32
    ) -> i32 {
        if length > PY_SSIZE_T_MAX - writer.view(1)[0].pos {
            PyErr_NoMemory();
            return i32(-1);
        }
        newlen = writer.view(1)[0].pos + length;
        maxchar = maxchar_in;
        if writer.view(1)[0].min_char > maxchar {
            maxchar = writer.view(1)[0].min_char;
        }
        if not writer.view(1)[0].buffer {
            if writer.view(1)[0].overallocate != u8(0)
                and newlen <= PY_SSIZE_T_MAX - newlen // OVERALLOCATE_FACTOR {
                newlen += newlen // OVERALLOCATE_FACTOR;
            }
            if newlen < writer.view(1)[0].min_length {
                newlen = writer.view(1)[0].min_length;
            }
            writer.view(1)[0].buffer = PyUnicode_New(newlen, maxchar);
            if not writer.view(1)[0].buffer {
                return i32(-1);
            }
        } elif newlen > writer.view(1)[0].size {
            if writer.view(1)[0].overallocate != u8(0)
                and newlen <= PY_SSIZE_T_MAX - newlen // OVERALLOCATE_FACTOR {
                newlen += newlen // OVERALLOCATE_FACTOR;
            }
            if newlen < writer.view(1)[0].min_length {
                newlen = writer.view(1)[0].min_length;
            }
            newbuffer = NULL;
            if maxchar > writer.view(1)[0].maxchar
                or writer.view(1)[0].readonly != u8(0) {
                if writer.view(1)[0].maxchar > maxchar {
                    maxchar = writer.view(1)[0].maxchar;
                }
                newbuffer = PyUnicode_New(newlen, maxchar);
                if not newbuffer {
                    return i32(-1);
                }
                _PyUnicode_FastCopyCharacters(
                    newbuffer, 0, writer.view(1)[0].buffer, 0, writer.view(1)[0].pos
                );
                object_decref(writer.view(1)[0].buffer);
                writer.view(1)[0].readonly = u8(0);
            } else {
                newbuffer = resize_compact(writer.view(1)[0].buffer, newlen);
                if not newbuffer {
                    return i32(-1);
                }
            }
            writer.view(1)[0].buffer = newbuffer;
        } elif maxchar > writer.view(1)[0].maxchar {
            newbuffer = PyUnicode_New(writer.view(1)[0].size, maxchar);
            if not newbuffer {
                return i32(-1);
            }
            _PyUnicode_FastCopyCharacters(
                newbuffer, 0, writer.view(1)[0].buffer, 0, writer.view(1)[0].pos
            );
            old = writer.view(1)[0].buffer;
            writer.view(1)[0].buffer = newbuffer;
            object_decref(old);
        }
        writer_update(writer);
        return i32(0);
    }  def _PyUnicodeWriter_PrepareKindInternal(
        writer: ptr[UnicodeWriter], kind: i32
    ) -> i32 {
        maxchar = MAX_UNICODE;
        if i64(kind) == PyUnicode_1BYTE_KIND {
            maxchar = u32(0xff);
        } elif i64(kind) == PyUnicode_2BYTE_KIND {
            maxchar = u32(0xffff);
        }
        return _PyUnicodeWriter_PrepareInternal(writer, 0, maxchar);
    }  def _PyUnicodeWriter_WriteChar(writer: ptr[UnicodeWriter], ch: u32) -> i32 {
        return writer_write_char_inline(writer, ch);
    }  def PyUnicodeWriter_WriteChar(writer: ptr[PyUnicodeWriter], ch: u32) -> i32 {
        if ch > MAX_UNICODE {
            PyErr_SetString(PyExc_ValueError, "character must be in range(0x110000)");
            return i32(-1);
        }
        return _PyUnicodeWriter_WriteChar(ptr[UnicodeWriter](writer), ch);
    }  def _PyUnicodeWriter_WriteStr(
        writer: ptr[UnicodeWriter], str_obj: ptr[PyObject]
    ) -> i32 {
        length = uo_length(str_obj);
        if length == 0 {
            return i32(0);
        }
        maxchar = uo_max_char_value(str_obj);
        if maxchar > writer.view(1)[0].maxchar
            or length > writer.view(1)[0].size - writer.view(1)[0].pos {
            if not writer.view(1)[0].buffer
                and writer.view(1)[0].overallocate == u8(0) {
                writer.view(1)[0].readonly = u8(1);
                writer.view(1)[0].buffer = object_new_ref(str_obj);
                writer_update(writer);
                writer.view(1)[0].pos += length;
                return i32(0);
            }
            if _PyUnicodeWriter_PrepareInternal(writer, length, maxchar) == i32(-1) {
                return i32(-1);
            }
        }
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, str_obj, 0, length
        );
        writer.view(1)[0].pos += length;
        return i32(0);
    }  def PyUnicodeWriter_WriteStr(
        writer: ptr[PyUnicodeWriter], obj_: ptr[PyObject]
    ) -> i32 {
        type = object_type(obj_);
        if type == unicode_type() {
            return _PyUnicodeWriter_WriteStr(ptr[UnicodeWriter](writer), obj_);
        }
        if type == ptr[PyTypeObject](addressof(PyLong_Type)) {
            return _PyLong_FormatWriter(
                ptr[UnicodeWriter](writer), obj_, i32(10), i32(0)
            );
        }
        text = PyObject_Str(obj_);
        if not text {
            return i32(-1);
        }
        res = _PyUnicodeWriter_WriteStr(ptr[UnicodeWriter](writer), text);
        object_decref(text);
        return res;
    }  def PyUnicodeWriter_WriteRepr(
        writer: ptr[PyUnicodeWriter], obj_: ptr[PyObject]
    ) -> i32 {
        if not obj_ {
            return _PyUnicodeWriter_WriteASCIIString(
                ptr[UnicodeWriter](writer), ptr[u8]("<NULL>"), 6
            );
        }
        if object_type(obj_) == ptr[PyTypeObject](addressof(PyLong_Type)) {
            return _PyLong_FormatWriter(
                ptr[UnicodeWriter](writer), obj_, i32(10), i32(0)
            );
        }
        text = PyObject_Repr(obj_);
        if not text {
            return i32(-1);
        }
        res = _PyUnicodeWriter_WriteStr(ptr[UnicodeWriter](writer), text);
        object_decref(text);
        return res;
    }  def _PyUnicodeWriter_WriteSubstring(
        writer: ptr[UnicodeWriter], str_obj: ptr[PyObject], start: i64, end: i64
    ) -> i32 {
        if start == 0 and end == uo_length(str_obj) {
            return _PyUnicodeWriter_WriteStr(writer, str_obj);
        }
        length = end - start;
        if length == 0 {
            return i32(0);
        }
        maxchar = u32(0);
        if uo_max_char_value(str_obj) > writer.view(1)[0].maxchar {
            maxchar = _PyUnicode_FindMaxChar(str_obj, start, end);
        } else {
            maxchar = writer.view(1)[0].maxchar;
        }
        if writer_prepare(writer, length, maxchar) < i32(0) {
            return i32(-1);
        }
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, str_obj, start, length
        );
        writer.view(1)[0].pos += length;
        return i32(0);
    }  def PyUnicodeWriter_WriteSubstring(
        writer: ptr[PyUnicodeWriter], str_obj: ptr[PyObject], start: i64, end: i64
    ) -> i32 {
        if not unicode_check(str_obj) {
            PyErr_Format(PyExc_TypeError, "expect str, not %T", str_obj);
            return i32(-1);
        }
        if start < 0 or start > end {
            PyErr_Format(PyExc_ValueError, "invalid start argument");
            return i32(-1);
        }
        if end > uo_length(str_obj) {
            PyErr_Format(PyExc_ValueError, "invalid end argument");
            return i32(-1);
        }
        return _PyUnicodeWriter_WriteSubstring(
            ptr[UnicodeWriter](writer), str_obj, start, end
        );
    }  def _PyUnicodeWriter_WriteASCIIString(
        writer: ptr[UnicodeWriter], text: ptr[u8], len_in: i64
    ) -> i32 {
        length = len_in;
        if length == -1 {
            length = i64(strlen(text));
        }
        if length == 0 {
            return i32(0);
        }
        if not writer.view(1)[0].buffer and writer.view(1)[0].overallocate == u8(0) {
            s = _PyUnicode_FromASCII(text, length);
            if not s {
                return i32(-1);
            }
            writer.view(1)[0].readonly = u8(1);
            writer.view(1)[0].buffer = s;
            writer_update(writer);
            writer.view(1)[0].pos += length;
            return i32(0);
        }
        if writer_prepare(writer, length, u32(127)) == i32(-1) {
            return i32(-1);
        }
        kind = i64(writer.view(1)[0].kind);
        data = writer.view(1)[0].data;
        pos = writer.view(1)[0].pos;
        if kind == PyUnicode_1BYTE_KIND {
            memcpy(ptr(data + pos), ptr(text), u64(length));
        } else {
            copy_chars(
                PyUnicode_1BYTE_KIND, text, kind, char_ptr(data, kind, pos), length
            );
        }
        writer.view(1)[0].pos += length;
        return i32(0);
    }  def PyUnicodeWriter_WriteASCII(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size: i64
    ) -> i32 {
        return _PyUnicodeWriter_WriteASCIIString(
            ptr[UnicodeWriter](writer), text, size
        );
    }  def PyUnicodeWriter_WriteUTF8(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size_in: i64
    ) -> i32 {
        size = size_in;
        if size < 0 {
            size = i64(strlen(text));
        }
        priv_writer = ptr[UnicodeWriter](writer);
        old_pos = priv_writer.view(1)[0].pos;
        res = unicode_decode_utf8_writer(
            priv_writer, text, size, _Py_ERROR_STRICT, ptr[u8](), ptr[i64]()
        );
        if res < i32(0) {
            priv_writer.view(1)[0].pos = old_pos;
        }
        return res;
    }  def PyUnicodeWriter_DecodeUTF8Stateful(
        writer: ptr[PyUnicodeWriter],
        text: ptr[u8],
        length_in: i64,
        errors: ptr[u8],
        consumed: ptr[i64]
    ) -> i32 {
        length = length_in;
        if length < 0 {
            length = i64(strlen(text));
        }
        priv_writer = ptr[UnicodeWriter](writer);
        old_pos = priv_writer.view(1)[0].pos;
        res = unicode_decode_utf8_writer(
            priv_writer, text, length, _Py_ERROR_UNKNOWN, errors, consumed
        );
        if res < i32(0) {
            priv_writer.view(1)[0].pos = old_pos;
            if consumed {
                consumed.view(1)[0] = 0;
            }
        }
        return res;
    }  def _PyUnicodeWriter_WriteLatin1String(
        writer: ptr[UnicodeWriter], text: ptr[u8], length: i64
    ) -> i32 {
        maxchar = sl_find_max_char(PyUnicode_1BYTE_KIND, text, length);
        if writer_prepare(writer, length, maxchar) == i32(-1) {
            return i32(-1);
        }
        unicode_write_cstr(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, text, length
        );
        writer.view(1)[0].pos += length;
        return i32(0);
    }  def _PyUnicodeWriter_Finish(writer: ptr[UnicodeWriter]) -> ptr[PyObject] {
        if writer.view(1)[0].pos == 0 {
            old = writer.view(1)[0].buffer;
            writer.view(1)[0].buffer = NULL;
            object_xdecref(old);
            return unicode_get_empty();
        }
        s = writer.view(1)[0].buffer;
        writer.view(1)[0].buffer = NULL;
        if writer.view(1)[0].readonly != u8(0) {
            return s;
        }
        if uo_length(s) != writer.view(1)[0].pos {
            s2 = resize_compact(s, writer.view(1)[0].pos);
            if not s2 {
                object_decref(s);
                return NULL;
            }
            s = s2;
        }
        return unicode_result(s);
    }  def PyUnicodeWriter_Finish(writer: ptr[PyUnicodeWriter]) -> ptr[PyObject] {
        s = _PyUnicodeWriter_Finish(ptr[UnicodeWriter](writer));
        unicode_writers_free(ptr(writer));
        return s;
    }  def _PyUnicodeWriter_Dealloc(writer: ptr[UnicodeWriter]) {
        old = writer.view(1)[0].buffer;
        writer.view(1)[0].buffer = NULL;
        object_xdecref(old);
    }
}

import from c {
    obj AutoNumber {
        has an_state: i32,
            an_field_number: i32;
    }  obj formatteriterobject {
        has ob_base: _object,
            str_obj: ptr[PyObject],
            it_markup_str: ptr[PyObject],
            it_markup_start: i64,
            it_markup_end: i64;
    }  obj fieldnameiterobject {
        has ob_base: _object,
            str_obj: ptr[PyObject],
            it_field_str: ptr[PyObject],
            it_field_start: i64,
            it_field_end: i64,
            it_field_index: i64;
    }
}

glob:priv AutoNumber_SIZE: i64 = 8,
     ANS_INIT: i32 = 0,
     ANS_AUTO: i32 = 1,
     ANS_MANUAL: i32 = 2,
     FORMAT_RECURSION_DEPTH: i64 = 2,
     FMT_BANG: u32 = 33,
     FMT_DOT: u32 = 46,
     FMT_COLON: u32 = 58,
     FMT_LBRACKET: u32 = 91,
     FMT_RBRACKET: u32 = 93,
     FMT_LBRACE: u32 = 123,
     FMT_RBRACE: u32 = 125,
     FMT_CONV_REPR: u32 = 114,
     FMT_CONV_STR: u32 = 115,
     FMT_CONV_ASCII: u32 = 97;

def AutoNumber_Init(auto_number: ptr[AutoNumber]);

def SubString_new_object(s: ptr[PyObject], start: i64, end: i64) -> ptr[PyObject];

def SubString_new_object_or_empty(
    s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def autonumber_state_error(state: i32, field_name_is_empty: bool) -> i32;

def get_integer(s: ptr[PyObject], start: i64, end: i64) -> i64;

def format_getattr(
    obj_: ptr[PyObject], s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def getitem_sequence(obj_: ptr[PyObject], idx: i64) -> ptr[PyObject];

def getitem_idx(obj_: ptr[PyObject], idx: i64) -> ptr[PyObject];

def getitem_str(
    obj_: ptr[PyObject], s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject];

def _FieldNameIterator_attr(s: ptr[PyObject], end: i64, index_in: i64) -> i64;

def _FieldNameIterator_item(
    s: ptr[PyObject], end: i64, index_in: i64
) -> tuple[i32, i64];

def FieldNameIterator_next(
    s: ptr[PyObject], end: i64, index_in: i64
) -> tuple[i32, i64, bool, i64, i64, i64];

def field_name_split(
    s: ptr[PyObject], start: i64, end: i64, auto_number: ptr[AutoNumber]
) -> tuple[i32, i64, i64];

def get_field_object(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    auto_number: ptr[AutoNumber]
) -> ptr[PyObject];

def render_field(
    fieldobj: ptr[PyObject],
    fs_str: ptr[PyObject],
    fs_start: i64,
    fs_end: i64,
    writer: ptr[UnicodeWriter]
) -> i32;

def parse_field(
    s: ptr[PyObject], pos_in: i64, end: i64
) -> tuple[i32, i64, i64, ptr[PyObject], i64, i64, u32, bool];

def markup_literal(
    status: i32, pos: i64, literal_start: i64, literal_end: i64
) -> tuple[
    i32,
    i64,
    i64,
    i64,
    bool,
    ptr[PyObject],
    i64,
    i64,
    ptr[PyObject],
    i64,
    i64,
    u32,
    bool
];

def MarkupIterator_next(
    s: ptr[PyObject], pos_in: i64, end: i64
) -> tuple[
    i32,
    i64,
    i64,
    i64,
    bool,
    ptr[PyObject],
    i64,
    i64,
    ptr[PyObject],
    i64,
    i64,
    u32,
    bool
];

def do_conversion(obj_: ptr[PyObject], conversion: u32) -> ptr[PyObject];

def output_markup(
    s: ptr[PyObject],
    field_name_start: i64,
    field_name_end: i64,
    fs_str: ptr[PyObject],
    fs_start: i64,
    fs_end: i64,
    format_spec_needs_expanding: bool,
    conversion: u32,
    writer: ptr[UnicodeWriter],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> i32;

def do_markup(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    writer: ptr[UnicodeWriter],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> i32;

def build_string(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> ptr[PyObject];

def do_string_format(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def do_string_format_map(self_: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def formatteriter_of(op: ptr[PyObject]) -> ptr[formatteriterobject];

def formatteriter_dealloc(op: ptr[PyObject]);

def formatteriter_next(op: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv formatteriter_methods: list[PyMethodDef] = [
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         PyFormatterIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("formatteriterator"),
             tp_basicsize=48,
             tp_dealloc=formatteriter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_iter=PyObject_SelfIter,
             tp_iternext=formatteriter_next,
             tp_methods=addressof(formatteriter_methods)
         );
}

def formatter_parser(ignored: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject];

def fieldnameiter_of(op: ptr[PyObject]) -> ptr[fieldnameiterobject];

def fieldnameiter_dealloc(op: ptr[PyObject]);

def fieldnameiter_next(op: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv fieldnameiter_methods: list[PyMethodDef] = [
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         PyFieldNameIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("fieldnameiterator"),
             tp_basicsize=56,
             tp_dealloc=fieldnameiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_iter=PyObject_SelfIter,
             tp_iternext=fieldnameiter_next,
             tp_methods=addressof(fieldnameiter_methods)
         );
}

def formatter_field_name_split(
    ignored: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject];

def unicode___format___impl(
    self_: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject];

def unicode___format__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def unicode_sizeof_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def unicode_sizeof(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicode_getnewargs(v: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def search_longest_common_leading_whitespace(
    src: ptr[u8], end: ptr[u8]
) -> tuple[i64, ptr[u8]];

import from c {
    def _PyUnicode_Dedent(unicode: ptr[PyObject]) -> ptr[PyObject] {
        if not unicode_check(unicode) {
            PyErr_BadArgument();
            return NULL;
        }
        if unicode_ensure_utf8(unicode) == i32(-1) {
            return NULL;
        }
        src = uo_utf8(unicode);
        src_len = uo_length(unicode)
            if uo_is_compact_ascii(unicode)
            else uo_utf8_length(unicode);
        if src_len == 0 {
            return object_new_ref(unicode);
        }
        end = src + src_len;

        (whitespace_len, whitespace_start) = search_longest_common_leading_whitespace(
            src, end
        );
        if whitespace_len == 0 {
            return object_new_ref(unicode);
        }

        dest = ptr[u8](PyMem_Malloc(u64(src_len)));
        if not dest {
            PyErr_NoMemory();
            return NULL;
        }
        dest_iter = dest;
        p = src;
        while p < end {
            line_start = p;
            in_leading_space = True;

            while p < end and p.view(1)[0] != u8(10) {
                if in_leading_space
                    and p.view(1)[0] != u8(32)
                    and p.view(1)[0] != u8(9) {
                    in_leading_space = False;
                }
                p = p + 1;
            }

            append_newline = p < end;
            if in_leading_space and append_newline {
                dest_iter.view(1)[0] = u8(10);
                dest_iter = dest_iter + 1;
            } else {
                new_line_len = i64(int(p) - int(line_start)) - whitespace_len;
                memcpy(
                    ptr(dest_iter), ptr(line_start + whitespace_len), u64(new_line_len)
                );
                dest_iter = dest_iter + new_line_len;
                if append_newline {
                    dest_iter.view(1)[0] = u8(10);
                    dest_iter = dest_iter + 1;
                }
            }
            p = p + 1;
        }
        res = PyUnicode_FromStringAndSize(dest, int(dest_iter) - int(dest));
        PyMem_Free(ptr(dest));
        return res;
    }
}

import from c {
    obj UnicodeFormatter {
        has args: ptr[PyObject],
            args_owned: i64,
            arglen: i64,
            argidx: i64,
            dct: ptr[PyObject],
            fmtkind: i64,
            fmtcnt: i64,
            fmtpos: i64,
            fmtdata: ptr[u8],
            fmtstr: ptr[PyObject],
            writer: ptr[UnicodeWriter];
    }  obj UnicodeFormatArg {
        has ch: u32,
            flags: i32,
            width: i64,
            prec: i32,
            sign: i32;
    }
}

glob:priv F_LJUST: i32 = 1,
     F_SIGN: i32 = 2,
     F_BLANK: i32 = 4,
     F_ALT: i32 = 8,
     F_ZERO: i32 = 16,
     PY_DTSF_ALT: i32 = 4,
     UNICODE_FORMATTER_SIZE: i64 = 88,
     UNICODE_FORMAT_ARG_SIZE: i64 = 24,
     PCT_SPACE: u32 = u32(32),
     PCT_HASH: u32 = u32(35),
     PCT_PERCENT: u32 = u32(37),
     PCT_LPAREN: u32 = u32(40),
     PCT_RPAREN: u32 = u32(41),
     PCT_STAR: u32 = u32(42),
     PCT_PLUS: u32 = u32(43),
     PCT_MINUS: u32 = u32(45),
     PCT_DOT: u32 = u32(46),
     PCT_ZERO: u32 = u32(48),
     PCT_NINE: u32 = u32(57),
     PCT_UPPER_E: u32 = u32(69),
     PCT_UPPER_F: u32 = u32(70),
     PCT_UPPER_G: u32 = u32(71),
     PCT_UPPER_L: u32 = u32(76),
     PCT_UPPER_X: u32 = u32(88),
     PCT_LOWER_A: u32 = u32(97),
     PCT_LOWER_C: u32 = u32(99),
     PCT_LOWER_D: u32 = u32(100),
     PCT_LOWER_E: u32 = u32(101),
     PCT_LOWER_F: u32 = u32(102),
     PCT_LOWER_G: u32 = u32(103),
     PCT_LOWER_H: u32 = u32(104),
     PCT_LOWER_I: u32 = u32(105),
     PCT_LOWER_L: u32 = u32(108),
     PCT_LOWER_O: u32 = u32(111),
     PCT_LOWER_R: u32 = u32(114),
     PCT_LOWER_S: u32 = u32(115),
     PCT_LOWER_U: u32 = u32(117),
     PCT_LOWER_X: u32 = u32(120);

def unicode_mod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def unicode_subscript(self_: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def unicode_slice_step(
    self_: ptr[PyObject], start: i64, step: i64, slicelength: i64
) -> ptr[PyObject];

def unicode_format_getnextarg(ctx: ptr[UnicodeFormatter]) -> ptr[PyObject];

def formatfloat(
    v: ptr[PyObject], arg: ptr[UnicodeFormatArg], writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject]];

import from c {
    def _PyUnicode_FormatLong(
        val: ptr[PyObject], alt: i32, prec: i32, type: i32
    ) -> ptr[PyObject] {
        numnondigits: i64 = 0;

        if i64(prec) > INT_MAX - 3 {
            PyErr_SetString(PyExc_OverflowError, "precision too large");
            return NULL;
        }

        conv = u32.wrap(type);
        result = NULL;
        if conv == PCT_LOWER_O {
            numnondigits = 2;
            result = PyNumber_ToBase(val, i32(8));
        } elif conv == PCT_LOWER_X or conv == PCT_UPPER_X {
            numnondigits = 2;
            result = PyNumber_ToBase(val, i32(16));
        } else {
            result = PyNumber_ToBase(val, i32(10));
        }
        if not result {
            return NULL;
        }

        if object_refcount(result) != 1 {
            object_decref(result);
            PyErr_BadInternalCall();
            return NULL;
        }
        buf = uo_data(result);
        length = uo_length(result);
        if length > INT_MAX {
            object_decref(result);
            PyErr_SetString(
                PyExc_ValueError, "string too large in _PyUnicode_FormatLong"
            );
            return NULL;
        }
        sign: i64 = 0;
        if u32(buf.view(1)[0]) == PCT_MINUS {
            sign = 1;
        }
        numnondigits += sign;
        numdigits = length - numnondigits;

        if alt == i32(0)
            and (conv == PCT_LOWER_O or conv == PCT_LOWER_X or conv == PCT_UPPER_X) {
            numnondigits -= 2;
            buf = buf + 2;
            length -= 2;
            if sign != 0 {
                buf.view(1)[0] = u8(45);
            }
        }

        if i64(prec) > numdigits {
            r1 = PyBytes_FromStringAndSize(ptr[u8](), numnondigits + i64(prec));
            if not r1 {
                object_decref(result);
                return NULL;
            }
            b1 = bytes_data(r1);
            for i in range(numnondigits) {
                (b1 + i).view(1)[0] = (buf + i).view(1)[0];
            }
            b1 = b1 + numnondigits;
            buf = buf + numnondigits;
            zeros = i64(prec) - numdigits;
            for i in range(zeros) {
                (b1 + i).view(1)[0] = u8(48);
            }
            b1 = b1 + zeros;
            for i in range(numdigits) {
                (b1 + i).view(1)[0] = (buf + i).view(1)[0];
            }
            (b1 + numdigits).view(1)[0] = u8(0);
            old = result;
            result = r1;
            object_decref(old);
            buf = bytes_data(result);
            length = numnondigits + i64(prec);
        }

        if conv == PCT_UPPER_X {
            for i in range(length) {
                b = (buf + i).view(1)[0];
                if b >= u8(97) and b <= u8(120) {
                    (buf + i).view(1)[0] = b - u8(32);
                }
            }
        }
        if not unicode_check(result) or buf != uo_data(result) {
            unicode = _PyUnicode_FromASCII(buf, length);
            old = result;
            result = unicode;
            object_decref(old);
        } elif length != uo_length(result) {
            (status, resized) = unicode_resize(result, length);
            result = resized;
            if status < i32(0) {
                object_xdecref(result);
                result = NULL;
            }
        }
        return result;
    }
}

def format_wants_index(conv: u32) -> bool;

def formatlong_wrongtype(v: ptr[PyObject], conv: u32) -> i32;

def mainformatlong(
    v: ptr[PyObject], arg: ptr[UnicodeFormatArg], writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject]];

def formatchar(v: ptr[PyObject]) -> u32;

def format_more(ctx: ptr[UnicodeFormatter]) -> bool;

def format_take(ctx: ptr[UnicodeFormatter]) -> u32;

def format_is_digit(ch: u32) -> bool;

def unicode_format_arg_parse(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]
) -> i32;

def unicode_format_arg_format(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]
) -> tuple[i32, ptr[PyObject]];

def format_put(writer: ptr[UnicodeWriter], ch: u32);

def unicode_format_arg_output(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg], str_obj: ptr[PyObject]
) -> i32;

def unicode_format_arg(ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]) -> i32;

import from c {
    def PyUnicode_Format(format: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
        if not format or not args {
            PyErr_BadInternalCall();
            return NULL;
        }
        if ensure_unicode(format) < i32(0) {
            return NULL;
        }
        block = ptr[u8](
            PyMem_Malloc(
                u64(
                    UNICODE_FORMATTER_SIZE
                        + UNICODE_FORMAT_ARG_SIZE
                        + _PyUnicodeWriter_SIZE
                )
            )
        );
        if not block {
            return PyErr_NoMemory();
        }
        ctx = ptr[UnicodeFormatter](block);
        arg = ptr[UnicodeFormatArg](block + UNICODE_FORMATTER_SIZE);
        writer = ptr[UnicodeWriter](
            block + UNICODE_FORMATTER_SIZE + UNICODE_FORMAT_ARG_SIZE
        );
        kind = uo_kind(format);
        data = uo_data(format);
        ctx.view(1)[0].fmtstr = format;
        ctx.view(1)[0].fmtdata = data;
        ctx.view(1)[0].fmtkind = kind;
        ctx.view(1)[0].fmtcnt = uo_length(format);
        ctx.view(1)[0].fmtpos = 0;
        ctx.view(1)[0].writer = writer;
        _PyUnicodeWriter_Init(writer);
        writer.view(1)[0].min_length = ctx.view(1)[0].fmtcnt + 100;
        writer.view(1)[0].overallocate = u8(1);
        if tuple_check(args) {
            ctx.view(1)[0].arglen = PyTuple_Size(args);
            ctx.view(1)[0].argidx = 0;
        } else {
            ctx.view(1)[0].arglen = -1;
            ctx.view(1)[0].argidx = -2;
        }
        ctx.view(1)[0].args_owned = 0;
        if PyMapping_Check(args) != i32(0)
            and not tuple_check(args)
            and not unicode_check(args) {
            ctx.view(1)[0].dct = args;
        } else {
            ctx.view(1)[0].dct = NULL;
        }
        ctx.view(1)[0].args = args;
        failed = False;
        while format_more(ctx) {
            pos = ctx.view(1)[0].fmtpos;
            if ch_read(kind, data, pos) != PCT_PERCENT {
                nonfmtpos = pos;

                cnt = ctx.view(1)[0].fmtcnt;
                found = findchar(
                    char_ptr(data, kind, pos + 1), kind, cnt, PCT_PERCENT, i32(1)
                );
                if found >= 0 {
                    ctx.view(1)[0].fmtpos = pos + 1 + found;
                    ctx.view(1)[0].fmtcnt = cnt - found;
                } else {
                    ctx.view(1)[0].fmtpos = pos + 1 + cnt;
                    ctx.view(1)[0].fmtcnt = -1;
                    writer.view(1)[0].overallocate = u8(0);
                }
                if _PyUnicodeWriter_WriteSubstring(
                    writer, format, nonfmtpos, ctx.view(1)[0].fmtpos
                )
                    < i32(0) {
                    failed = True;
                    break;
                }
            } else {
                ctx.view(1)[0].fmtpos = pos + 1;
                if unicode_format_arg(ctx, arg) == i32(-1) {
                    failed = True;
                    break;
                }
            }
        }
        if not failed
            and ctx.view(1)[0].argidx < ctx.view(1)[0].arglen
            and not ctx.view(1)[0].dct {
            PyErr_SetString(
                PyExc_TypeError, "not all arguments converted during string formatting"
            );
            failed = True;
        }
        if failed {
            _PyUnicodeWriter_Dealloc(writer);
            if ctx.view(1)[0].args_owned != 0 {
                object_decref(ctx.view(1)[0].args);
            }
            PyMem_Free(ptr(block));
            return NULL;
        }
        if ctx.view(1)[0].args_owned != 0 {
            object_decref(ctx.view(1)[0].args);
        }
        result = _PyUnicodeWriter_Finish(writer);
        PyMem_Free(ptr(block));
        return result;
    }
}

def status_ok -> PyStatus;

def status_err(func: ptr[u8], err_msg: ptr[u8]) -> PyStatus;

def interp_is_main(interp: ptr[u8]) -> bool;

def is_immortal_object(op: ptr[PyObject]) -> bool;

def set_mortal(op: ptr[PyObject], refcnt: i64);

import from c {
    def _PyUnicode_InternedSize -> i64 {
        dct = interned_dict(current_interp());
        return i64(_Py_hashtable_len(interned_strings_table()))
            + ptr[PyDictObject](dct).view(1)[0].ma_used;
    }  def _PyUnicode_InternedSize_Immortal -> i64 {
        dct = interned_dict(current_interp());
        pos: i64 = 0;
        key = NULL;
        value = NULL;
        count: i64 = 0;
        while PyDict_Next(dct, &mut pos, &mut key, &mut value) != 0 {
            if uo_interned(key) == SSTATE_INTERNED_IMMORTAL {
                count += 1;
            }
        }
        return i64(_Py_hashtable_len(interned_strings_table())) + count;
    }
}

def hashtable_unicode_hash(key: ptr) -> u64;

def hashtable_unicode_compare(key1: ptr, key2: ptr) -> i32;

def has_shared_intern_dict(interp: ptr[u8]) -> bool;

def init_interned_dict(interp: ptr[u8]) -> i32;

def clear_interned_dict(interp: ptr[u8]);

import from c {
    glob:priv hashtable_alloc: list[ptr] = [
             ptr(PyMem_RawMalloc),
             ptr(PyMem_RawFree)
         ];
}

def init_global_interned_strings(interp: ptr[u8]) -> PyStatus;

def clear_global_interned_strings;

import from c {
    glob:priv unicode_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("encode"),
                 ml_meth=ptr(unicode_encode),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "encode($self, /, encoding='utf-8', errors='strict')\n--\n\n"
                     "Encode the string using the codec registered for encoding.\n\n"
                     "  encoding\n"
                     "    The encoding in which to encode the string.\n"
                     "  errors\n"
                     "    The error handling scheme to use for encoding errors.\n"
                     "    The default is 'strict' meaning that encoding errors raise a\n"
                     "    UnicodeEncodeError.  Other possible values are 'ignore', 'replace'\n"
                     "    and 'xmlcharrefreplace' as well as any other name registered with\n"
                     "    codecs.register_error that can handle UnicodeEncodeErrors."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("replace"),
                 ml_meth=ptr(unicode_replace),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "replace($self, old, new, /, count=-1)\n--\n\n"
                     "Return a copy with all occurrences of substring old replaced by new.\n\n"
                     "  count\n"
                     "    Maximum number of occurrences to replace.\n"
                     "    -1 (the default value) means replace all occurrences.\n\n"
                     "If the optional argument count is given, only the first count occurrences are\n"
                     "replaced."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("split"),
                 ml_meth=ptr(unicode_split),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "split($self, /, sep=None, maxsplit=-1)\n--\n\n"
                     "Return a list of the substrings in the string, using sep as the separator string.\n\n"
                     "  sep\n"
                     "    The separator used to split the string.\n\n"
                     "    When set to None (the default value), will split on any\n"
                     "    whitespace character (including \\n \\r \\t \\f and spaces) and\n"
                     "    will discard empty strings from the result.\n"
                     "  maxsplit\n"
                     "    Maximum number of splits.\n"
                     "    -1 (the default value) means no limit.\n\n"
                     "Splitting starts at the front of the string and works to the end.\n\n"
                     "Note, str.split() is mainly useful for data that has been\n"
                     "intentionally delimited.  With natural text that includes\n"
                     "punctuation, consider using the regular expression module."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rsplit"),
                 ml_meth=ptr(unicode_rsplit),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "rsplit($self, /, sep=None, maxsplit=-1)\n--\n\n"
                     "Return a list of the substrings in the string, using sep as the separator string.\n\n"
                     "  sep\n"
                     "    The separator used to split the string.\n\n"
                     "    When set to None (the default value), will split on any\n"
                     "    whitespace character (including \\n \\r \\t \\f and spaces) and\n"
                     "    will discard empty strings from the result.\n"
                     "  maxsplit\n"
                     "    Maximum number of splits.\n"
                     "    -1 (the default value) means no limit.\n\n"
                     "Splitting starts at the end of the string and works to the front."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("join"),
                 ml_meth=ptr(unicode_join),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "join($self, iterable, /)\n--\n\n"
                     "Concatenate any number of strings.\n\n"
                     "The string whose method is called is inserted in between each given\n"
                     "string.  The result is returned as a new string.\n\n"
                     "Example: '.'.join(['ab', 'pq', 'rs']) -> 'ab.pq.rs'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("capitalize"),
                 ml_meth=ptr(unicode_capitalize),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "capitalize($self, /)\n--\n\n"
                     "Return a capitalized version of the string.\n\n"
                     "More specifically, make the first character have upper case and the\n"
                     "rest lower case."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("casefold"),
                 ml_meth=ptr(unicode_casefold),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "casefold($self, /)\n--\n\n"
                     "Return a version of the string suitable for caseless comparisons."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("title"),
                 ml_meth=ptr(unicode_title),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "title($self, /)\n--\n\n"
                     "Return a version of the string where each word is titlecased.\n\n"
                     "More specifically, words start with uppercased characters and all\n"
                     "remaining cased characters have lower case."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("center"),
                 ml_meth=ptr(unicode_center),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "center($self, width, fillchar=' ', /)\n--\n\n"
                     "Return a centered string of length width.\n\n"
                     "Padding is done using the specified fill character (default is\n"
                     "a space)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(unicode_count),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "count($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the number of non-overlapping occurrences of substring sub in string S[start:end].\n\n"
                     "Optional arguments start and end are interpreted as in slice\n"
                     "notation."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("expandtabs"),
                 ml_meth=ptr(unicode_expandtabs),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "expandtabs($self, /, tabsize=8)\n--\n\n"
                     "Return a copy where all tab characters are expanded using spaces.\n\n"
                     "If tabsize is not given, a tab size of 8 characters is assumed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("find"),
                 ml_meth=ptr(unicode_find),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "find($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the lowest index in S where substring sub is found, such that sub is contained within S[start:end].\n\n"
                     "Optional arguments start and end are interpreted as in slice\n"
                     "notation.  Return -1 on failure."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("partition"),
                 ml_meth=ptr(unicode_partition),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "partition($self, sep, /)\n--\n\n"
                     "Partition the string into three parts using the given separator.\n\n"
                     "This will search for the separator in the string.  If the separator\n"
                     "is found, returns a 3-tuple containing the part before the\n"
                     "separator, the separator itself, and the part after it.\n\n"
                     "If the separator is not found, returns a 3-tuple containing\n"
                     "the original string and two empty strings."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(unicode_index),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "index($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the lowest index in S where substring sub is found, such that sub is contained within S[start:end].\n\n"
                     "Optional arguments start and end are interpreted as in slice\n"
                     "notation.  Raises ValueError when the substring is not found."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ljust"),
                 ml_meth=ptr(unicode_ljust),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "ljust($self, width, fillchar=' ', /)\n--\n\n"
                     "Return a left-justified string of length width.\n\n"
                     "Padding is done using the specified fill character (default is\n"
                     "a space)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("lower"),
                 ml_meth=ptr(unicode_lower),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "lower($self, /)\n--\n\n"
                     "Return a copy of the string converted to lowercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("lstrip"),
                 ml_meth=ptr(unicode_lstrip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "lstrip($self, chars=None, /)\n--\n\n"
                     "Return a copy of the string with leading whitespace removed.\n\n"
                     "If chars is given and not None, remove characters in chars instead."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rfind"),
                 ml_meth=ptr(unicode_rfind),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rfind($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the highest index in S where substring sub is found, such that sub is contained within S[start:end].\n\n"
                     "Optional arguments start and end are interpreted as in slice\n"
                     "notation.  Return -1 on failure."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rindex"),
                 ml_meth=ptr(unicode_rindex),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rindex($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the highest index in S where substring sub is found, such that sub is contained within S[start:end].\n\n"
                     "Optional arguments start and end are interpreted as in slice\n"
                     "notation.  Raises ValueError when the substring is not found."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rjust"),
                 ml_meth=ptr(unicode_rjust),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rjust($self, width, fillchar=' ', /)\n--\n\n"
                     "Return a right-justified string of length width.\n\n"
                     "Padding is done using the specified fill character (default is\n"
                     "a space)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rstrip"),
                 ml_meth=ptr(unicode_rstrip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rstrip($self, chars=None, /)\n--\n\n"
                     "Return a copy of the string with trailing whitespace removed.\n\n"
                     "If chars is given and not None, remove characters in chars instead."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rpartition"),
                 ml_meth=ptr(unicode_rpartition),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "rpartition($self, sep, /)\n--\n\n"
                     "Partition the string into three parts using the given separator.\n\n"
                     "This will search for the separator in the string, starting at the\n"
                     "end.  If the separator is found, returns a 3-tuple containing the\n"
                     "part before the separator, the separator itself, and the part after\n"
                     "it.\n\n"
                     "If the separator is not found, returns a 3-tuple containing two\n"
                     "empty strings and the original string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("splitlines"),
                 ml_meth=ptr(unicode_splitlines),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "splitlines($self, /, keepends=False)\n--\n\n"
                     "Return a list of the lines in the string, breaking at line boundaries.\n\n"
                     "Line breaks are not included in the resulting list unless keepends\n"
                     "is given and true."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("strip"),
                 ml_meth=ptr(unicode_strip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "strip($self, chars=None, /)\n--\n\n"
                     "Return a copy of the string with leading and trailing whitespace removed.\n\n"
                     "If chars is given and not None, remove characters in chars instead."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("swapcase"),
                 ml_meth=ptr(unicode_swapcase),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "swapcase($self, /)\n--\n\n"
                     "Convert uppercase characters to lowercase and lowercase characters to uppercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("translate"),
                 ml_meth=ptr(unicode_translate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "translate($self, table, /)\n--\n\n"
                     "Replace each character in the string using the given translation table.\n\n"
                     "  table\n"
                     "    Translation table, which must be a mapping of Unicode ordinals\n"
                     "    to Unicode ordinals, strings, or None.\n\n"
                     "The table must implement lookup/indexing via __getitem__, for\n"
                     "instance a dictionary or list.  If this operation raises\n"
                     "LookupError, the character is left untouched.  Characters mapped to\n"
                     "None are deleted."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("upper"),
                 ml_meth=ptr(unicode_upper),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "upper($self, /)\n--\n\n"
                     "Return a copy of the string converted to uppercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("startswith"),
                 ml_meth=ptr(unicode_startswith),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "startswith($self, prefix[, start[, end]], /)\n--\n\n"
                     "Return True if the string starts with the specified prefix, False otherwise.\n\n"
                     "  prefix\n"
                     "    A string or a tuple of strings to try.\n"
                     "  start\n"
                     "    Optional start position. Default: start of the string.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("endswith"),
                 ml_meth=ptr(unicode_endswith),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "endswith($self, suffix[, start[, end]], /)\n--\n\n"
                     "Return True if the string ends with the specified suffix, False otherwise.\n\n"
                     "  suffix\n"
                     "    A string or a tuple of strings to try.\n"
                     "  start\n"
                     "    Optional start position. Default: start of the string.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("removeprefix"),
                 ml_meth=ptr(unicode_removeprefix),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "removeprefix($self, prefix, /)\n--\n\n"
                     "Return a str with the given prefix string removed if present.\n\n"
                     "If the string starts with the prefix string, return\n"
                     "string[len(prefix):].  Otherwise, return a copy of the original\n"
                     "string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("removesuffix"),
                 ml_meth=ptr(unicode_removesuffix),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "removesuffix($self, suffix, /)\n--\n\n"
                     "Return a str with the given suffix string removed if present.\n\n"
                     "If the string ends with the suffix string and that suffix is not\n"
                     "empty, return string[:-len(suffix)].  Otherwise, return a copy of\n"
                     "the original string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isascii"),
                 ml_meth=ptr(unicode_isascii),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isascii($self, /)\n--\n\n"
                     "Return True if all characters in the string are ASCII, False otherwise.\n\n"
                     "ASCII characters have code points in the range U+0000-U+007F.\n"
                     "Empty string is ASCII too."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("islower"),
                 ml_meth=ptr(unicode_islower),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "islower($self, /)\n--\n\n"
                     "Return True if the string is a lowercase string, False otherwise.\n\n"
                     "A string is lowercase if all cased characters in the string are\n"
                     "lowercase and there is at least one cased character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isupper"),
                 ml_meth=ptr(unicode_isupper),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isupper($self, /)\n--\n\n"
                     "Return True if the string is an uppercase string, False otherwise.\n\n"
                     "A string is uppercase if all cased characters in the string are\n"
                     "uppercase and there is at least one cased character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("istitle"),
                 ml_meth=ptr(unicode_istitle),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "istitle($self, /)\n--\n\n"
                     "Return True if the string is a title-cased string, False otherwise.\n\n"
                     "In a title-cased string, upper- and title-case characters may only\n"
                     "follow uncased characters and lowercase characters only cased ones."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isspace"),
                 ml_meth=ptr(unicode_isspace),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isspace($self, /)\n--\n\n"
                     "Return True if the string is a whitespace string, False otherwise.\n\n"
                     "A string is whitespace if all characters in the string are\n"
                     "whitespace and there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isdecimal"),
                 ml_meth=ptr(unicode_isdecimal),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isdecimal($self, /)\n--\n\n"
                     "Return True if the string is a decimal string, False otherwise.\n\n"
                     "A string is a decimal string if all characters in the string are\n"
                     "decimal and there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isdigit"),
                 ml_meth=ptr(unicode_isdigit),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isdigit($self, /)\n--\n\n"
                     "Return True if the string is a digit string, False otherwise.\n\n"
                     "A string is a digit string if all characters in the string are\n"
                     "digits and there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isnumeric"),
                 ml_meth=ptr(unicode_isnumeric),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isnumeric($self, /)\n--\n\n"
                     "Return True if the string is a numeric string, False otherwise.\n\n"
                     "A string is numeric if all characters in the string are numeric and\n"
                     "there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isalpha"),
                 ml_meth=ptr(unicode_isalpha),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isalpha($self, /)\n--\n\n"
                     "Return True if the string is an alphabetic string, False otherwise.\n\n"
                     "A string is alphabetic if all characters in the string are\n"
                     "alphabetic and there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isalnum"),
                 ml_meth=ptr(unicode_isalnum),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isalnum($self, /)\n--\n\n"
                     "Return True if the string is an alpha-numeric string, False otherwise.\n\n"
                     "A string is alpha-numeric if all characters in the string are\n"
                     "alpha-numeric and there is at least one character in the string."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isidentifier"),
                 ml_meth=ptr(unicode_isidentifier),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isidentifier($self, /)\n--\n\n"
                     "Return True if the string is a valid Python identifier, False otherwise.\n\n"
                     "Call keyword.iskeyword(s) to test whether string s is a reserved\n"
                     "identifier, such as \"def\" or \"class\"."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isprintable"),
                 ml_meth=ptr(unicode_isprintable),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isprintable($self, /)\n--\n\n"
                     "Return True if all characters in the string are printable, False otherwise.\n\n"
                     "A character is printable if repr() may use it in its output."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("zfill"),
                 ml_meth=ptr(unicode_zfill),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "zfill($self, width, /)\n--\n\n"
                     "Pad a numeric string with zeros on the left, to fill a field of the given width.\n\n"
                     "The string is never truncated."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("format"),
                 ml_meth=ptr(do_string_format),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "format($self, /, *args, **kwargs)\n--\n\n"
                     "Return a formatted version of the string, using substitutions from args and kwargs.\n"
                     "The substitutions are identified by braces ('{' and '}')."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("format_map"),
                 ml_meth=ptr(do_string_format_map),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "format_map($self, mapping, /)\n--\n\n"
                     "Return a formatted version of the string, using substitutions from mapping.\n"
                     "The substitutions are identified by braces ('{' and '}')."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(unicode___format__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__format__($self, format_spec, /)\n--\n\n"
                     "Return a formatted version of the string as described by format_spec."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("maketrans"),
                 ml_meth=ptr(unicode_maketrans),
                 ml_flags=METH_FASTCALL | METH_STATIC,
                 ml_doc=ptr[u8](
                     "maketrans(x, y=<unrepresentable>, z=<unrepresentable>, /)\n--\n\n"
                     "Return a translation table usable for str.translate().\n\n"
                     "If there is only one argument, it must be a dictionary mapping\n"
                     "Unicode ordinals (integers) or characters to Unicode ordinals,\n"
                     "strings or None.  Character keys will be then converted to ordinals.\n"
                     "If there are two arguments, they must be strings of equal length,\n"
                     "and in the resulting dictionary, each character in x will be mapped\n"
                     "to the character at the same position in y.  If there is a third\n"
                     "argument, it must be a string, whose characters will be mapped to\n"
                     "None in the result."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(unicode_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\n"
                     "Return the size of the string in memory, in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(unicode_getnewargs),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         unicode_as_number: PyNumberMethods = PyNumberMethods(nb_remainder=unicode_mod),
         unicode_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=unicode_length,
             sq_concat=PyUnicode_Concat,
             sq_repeat=unicode_repeat,
             sq_item=unicode_getitem,
             sq_contains=PyUnicode_Contains
         ),
         unicode_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=unicode_length, mp_subscript=unicode_subscript
         );
}

def unicode_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject];

glob:priv unicode_new_signature = CallSignature(
         "str", ["object", "encoding", "errors"], 0, 3, 0, parser=PARSE_KEYWORDS
     );

def unicode_new_args(
    type: ptr[PyTypeObject],
    x: ptr[PyObject],
    encoding_obj: ptr[PyObject],
    errors_obj: ptr[PyObject]
) -> ptr[PyObject];

def unicode_new_bound(args: BoundArguments) -> ptr[PyObject];

def unicode_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def arg_as_utf8(obj_: ptr[PyObject], name: ptr[u8]) -> ptr[u8];

def unicode_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def unicode_subtype_new(
    type: ptr[PyTypeObject], unicode: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def _PyUnicode_ExactDealloc(op: ptr[PyObject]) {
        unicode_dealloc(op);
    }
}

import from c {
    glob PyUnicode_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("str"),
             tp_basicsize=PyUnicodeObject_SIZE,
             tp_dealloc=unicode_dealloc,
             tp_repr=unicode_repr,
             tp_as_number=addressof(unicode_as_number),
             tp_as_sequence=addressof(unicode_as_sequence),
             tp_as_mapping=addressof(unicode_as_mapping),
             tp_hash=unicode_hash,
             tp_str=unicode_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_UNICODE_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF,
             tp_doc=ptr[u8](
                 "str(object='') -> str\n"
                 "str(bytes_or_buffer[, encoding[, errors]]) -> str\n\n"
                 "Create a new string object from the given object. If encoding or\n"
                 "errors is specified, then the object must expose a data buffer\n"
                 "that will be decoded using the given encoding and error handler.\n"
                 "Otherwise, returns the result of object.__str__() (if defined)\n"
                 "or repr(object).\n"
                 "encoding defaults to 'utf-8'.\n"
                 "errors defaults to 'strict'."
             ),
             tp_richcompare=PyUnicode_RichCompare,
             tp_iter=unicode_iter,
             tp_methods=addressof(unicode_methods),
             tp_new=unicode_new,
             tp_free=PyObject_Free,
             tp_vectorcall=unicode_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_STR
         ); glob:priv bloom_linebreak_chars: list[u16] = [
             u16(0x000A),
             u16(0x000D),
             u16(0x001C),
             u16(0x001D),
             u16(0x001E),
             u16(0x0085),
             u16(0x2028),
             u16(0x2029)
         ];
}

glob:priv unicode_global_state_initialized: bool = False;

def _init_global_state;

import from c {
    def _PyUnicode_InitState(interp: ptr[u8]) {
        if not interp_is_main(interp) {
            return;
        }
        _init_global_state();
    }  def _PyUnicode_InitGlobalObjects(interp: ptr[u8]) -> PyStatus {
        if interp_is_main(interp) {
            status = init_global_interned_strings(interp);
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
        }

        if init_interned_dict(interp) != i32(0) {
            PyErr_Clear();
            return status_err(
                ptr[u8]("_PyUnicode_InitGlobalObjects"),
                ptr[u8]("failed to create interned dict")
            );
        }
        return status_ok();
    }  def _PyUnicode_InitTypes(interp: ptr[u8]) -> PyStatus {
        state = ptr[PyInterpreterState](interp);
        if _PyStaticType_InitBuiltin(state, ptr[PyObject](addressof(EncodingMapType)))
            < 0
            or _PyStaticType_InitBuiltin(
                state, ptr[PyObject](addressof(PyFieldNameIter_Type))
            )
                < 0
            or _PyStaticType_InitBuiltin(
                state, ptr[PyObject](addressof(PyFormatterIter_Type))
            )
                < 0 {
            return status_err(
                ptr[u8]("_PyUnicode_InitTypes"),
                ptr[u8]("Can't initialize unicode types")
            );
        }
        return status_ok();
    }
}

def intern_static(interp: ptr[u8], s: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyUnicode_InternStatic(interp: ptr[u8], p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_static(interp, p.view(1)[0]);
    }
}

def immortalize_interned(s: ptr[PyObject]);

def intern_common(
    interp: ptr[u8], s: ptr[PyObject], immortalize: bool
) -> ptr[PyObject];

import from c {
    def _PyUnicode_InternImmortal(interp: ptr[u8], p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_common(interp, p.view(1)[0], True);
    }  def _PyUnicode_InternMortal(interp: ptr[u8], p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_common(interp, p.view(1)[0], False);
    }  def _PyUnicode_InternInPlace(interp: ptr[u8], p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_common(interp, p.view(1)[0], True);
    }  def PyUnicode_InternInPlace(p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_common(current_interp(), p.view(1)[0], False);
    }  def PyUnicode_InternImmortal(p: ptr[ptr[PyObject]]) {
        p.view(1)[0] = intern_common(current_interp(), p.view(1)[0], True);
    }  def PyUnicode_InternFromString(cp: ptr[u8]) -> ptr[PyObject] {
        s = PyUnicode_FromString(cp);
        if not s {
            return NULL;
        }
        return intern_common(current_interp(), s, False);
    }  def _PyUnicode_ClearInterned(interp: ptr[u8]) {
        interned = interned_dict(interp);
        if not interned {
            return;
        }
        if has_shared_intern_dict(interp) {
            clear_interned_dict(interp);
            return;
        }
        pos: i64 = 0;
        s = NULL;
        ignored_value = NULL;
        while PyDict_Next(interned, &mut pos, &mut s, &mut ignored_value) != 0 {
            shared = False;
            state = uo_interned(s);
            if state == SSTATE_INTERNED_IMMORTAL {
                set_mortal(s, 2);
            } elif state == SSTATE_INTERNED_IMMORTAL_STATIC {
                if not interp_is_main(interp) {
                    shared = True;
                }
            } elif state == SSTATE_INTERNED_MORTAL {
                refcnt_add(s, 2);
            }

            if not shared {
                uo_set_interned(s, SSTATE_NOT_INTERNED);
            }
        }
        ids_size = ptr[i64](
            interp_at(interp, PyInterpreterState_UNICODE_IDS_SIZE)
        ).view(
            1
        )[0];
        ids_array = ptr[ptr[ptr[PyObject]]](
            interp_at(interp, PyInterpreterState_UNICODE_IDS_ARRAY)
        ).view(
            1
        )[0];
        for i in range(ids_size) {
            item = (ids_array + i).view(1)[0];
            if item {
                object_incref(item);
            }
        }
        clear_interned_dict(interp);
        if interp_is_main(interp) {
            clear_global_interned_strings();
        }
    }
}

def uiter_of(op: ptr[PyObject]) -> ptr[seqiterobject];

def unicodeiter_dealloc(op: ptr[PyObject]);

def unicodeiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def unicodeiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def unicode_ascii_iter_next(op: ptr[PyObject]) -> ptr[PyObject];

def unicodeiter_len(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicodeiter_reduce(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unicodeiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv unicodeiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(unicodeiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(unicodeiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(unicodeiter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyUnicodeIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("str_iterator"),
             tp_basicsize=seqiterobject_SIZE,
             tp_dealloc=unicodeiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=unicodeiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=unicodeiter_next,
             tp_methods=addressof(unicodeiter_methods)
         ),
         _PyUnicodeASCIIIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("str_ascii_iterator"),
             tp_basicsize=seqiterobject_SIZE,
             tp_dealloc=unicodeiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=unicodeiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=unicode_ascii_iter_next,
             tp_methods=addressof(unicodeiter_methods)
         );
}

def unicode_iter(seq: ptr[PyObject]) -> ptr[PyObject];

def encode_wstr_utf8(wstr: ptr[i32], name: ptr[u8]) -> tuple[i32, ptr[u8]];

def config_get_codec_name(config_encoding: ptr[ptr[i32]]) -> i32;

def init_stdio_encoding(interp: ptr[u8]) -> PyStatus;

def init_fs_codec(interp: ptr[u8]) -> i32;

def init_fs_encoding(tstate: ptr[u8]) -> PyStatus;

import from c {
    def _PyUnicode_InitEncodings(tstate: ptr[u8]) -> PyStatus {
        interp = ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
        status = _PyCodec_InitRegistry(interp);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        status = init_fs_encoding(tstate);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        return init_stdio_encoding(interp);
    }
}

def _PyUnicode_FiniEncodings(interp: ptr[u8]);

import from c {
    def _PyUnicode_FiniTypes(interp: ptr[u8]) {
        state = ptr[PyInterpreterState](interp);
        _PyStaticType_FiniBuiltin(state, ptr[PyObject](addressof(EncodingMapType)));
        _PyStaticType_FiniBuiltin(
            state, ptr[PyObject](addressof(PyFieldNameIter_Type))
        );
        _PyStaticType_FiniBuiltin(
            state, ptr[PyObject](addressof(PyFormatterIter_Type))
        );
    }  def _PyUnicode_Fini(interp: ptr[u8]) {
        _PyUnicode_FiniEncodings(interp);

        ptr[ptr](interp_at(interp, PyInterpreterState_UNICODE_UCNHASH_CAPI)).view(1)[
            0
        ] = ptr();
        unicode_clear_identifiers(interp);
    }
}

import from c {
    glob:priv _string_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("formatter_field_name_split"),
                 ml_meth=ptr(formatter_field_name_split),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("split the argument as a field name")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("formatter_parser"),
                 ml_meth=ptr(formatter_parser),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("parse the argument as a format string")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         _string_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_string"),
             m_doc=ptr[u8]("string helper module"),
             m_size=0,
             m_methods=addressof(_string_methods),
             m_slots=addressof(module_slots)
         );
}

import from c {
    def PyInit__string -> ptr[PyObject] {
        return PyModuleDef_Init(ptr[PyModuleDef](addressof(_string_module)));
    }  def PyUnicode_KIND(op: ptr[PyObject]) -> i32 {
        if not unicode_check(op) {
            PyErr_Format(PyExc_TypeError, "expect str, got %T", op);
            return i32(-1);
        }
        return i32(uo_kind(op));
    }  def PyUnicode_DATA(op: ptr[PyObject]) -> ptr {
        if not unicode_check(op) {
            PyErr_Format(PyExc_TypeError, "expect str, got %T", op);
            return ptr();
        }
        return ptr(uo_data(op));
    }
}

impl unicode_type -> ptr[PyTypeObject] {
    return addressof(PyUnicode_Type);
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, unicode_type());
}

impl bytes_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl bytes_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyBytes_Type)));
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl list_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LIST_SUBCLASS);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl bytes_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl list_get_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    return (ptr[PyListObject](op).view(1)[0].ob_item + i).view(1)[0];
}

impl list_set_item(op: ptr[PyObject], i: i64, item: ptr[PyObject]) {
    (ptr[PyListObject](op).view(1)[0].ob_item + i).view(1)[0] = item;
}

impl uo_state(op: ptr[PyObject]) -> u32 {
    return ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0];
}

impl uo_set_state(op: ptr[PyObject], state: u32) {
    ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0] = state;
}

impl uo_interned(op: ptr[PyObject]) -> u32 {
    return uo_state(op) & STATE_INTERNED_MASK;
}

impl uo_set_interned(op: ptr[PyObject], v: u32) {
    uo_set_state(op, (uo_state(op) & ~STATE_INTERNED_MASK) | (v & STATE_INTERNED_MASK));
}

impl uo_kind(op: ptr[PyObject]) -> i64 {
    return i64((uo_state(op) & STATE_KIND_MASK) >> STATE_KIND_SHIFT);
}

impl uo_is_compact(op: ptr[PyObject]) -> bool {
    return (uo_state(op) & STATE_COMPACT) != u32(0);
}

impl uo_is_ascii(op: ptr[PyObject]) -> bool {
    return (uo_state(op) & STATE_ASCII) != u32(0);
}

impl uo_is_compact_ascii(op: ptr[PyObject]) -> bool {
    return (uo_state(op) & (STATE_ASCII | STATE_COMPACT))
        == (STATE_ASCII | STATE_COMPACT);
}

impl uo_is_static(op: ptr[PyObject]) -> bool {
    return (uo_state(op) & STATE_STATIC) != u32(0);
}

impl uo_length(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl uo_set_length(op: ptr[PyObject], n: i64) {
    ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0] = n;
}

impl uo_hash(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_HASH).view(1)[0];
}

impl uo_set_hash(op: ptr[PyObject], h: i64) {
    ptr[i64](ptr[u8](op) + PyASCIIObject_HASH).view(1)[0] = h;
}

impl uo_utf8_field(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](op) + PyCompactUnicodeObject_UTF8).view(1)[0];
}

impl uo_utf8(op: ptr[PyObject]) -> ptr[u8] {
    if uo_is_compact_ascii(op) {
        return ptr[u8](op) + PyASCIIObject_SIZE;
    }
    return uo_utf8_field(op);
}

impl uo_set_utf8(op: ptr[PyObject], p: ptr[u8]) {
    ptr[ptr[u8]](ptr[u8](op) + PyCompactUnicodeObject_UTF8).view(1)[0] = p;
}

impl uo_utf8_length(op: ptr[PyObject]) -> i64 {
    if uo_is_compact_ascii(op) {
        return uo_length(op);
    }
    return ptr[i64](ptr[u8](op) + PyCompactUnicodeObject_UTF8_LENGTH).view(1)[0];
}

impl uo_set_utf8_length(op: ptr[PyObject], n: i64) {
    ptr[i64](ptr[u8](op) + PyCompactUnicodeObject_UTF8_LENGTH).view(1)[0] = n;
}

impl uo_data_any(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](op) + PyUnicodeObject_DATA).view(1)[0];
}

impl uo_set_data_any(op: ptr[PyObject], p: ptr[u8]) {
    ptr[ptr[u8]](ptr[u8](op) + PyUnicodeObject_DATA).view(1)[0] = p;
}

impl uo_compact_data(op: ptr[PyObject]) -> ptr[u8] {
    if uo_is_ascii(op) {
        return ptr[u8](op) + PyASCIIObject_SIZE;
    }
    return ptr[u8](op) + PyCompactUnicodeObject_SIZE;
}

impl uo_data(op: ptr[PyObject]) -> ptr[u8] {
    if uo_is_compact(op) {
        return uo_compact_data(op);
    }
    return uo_data_any(op);
}

impl uo_share_utf8(op: ptr[PyObject]) -> bool {
    return uo_utf8_field(op) == uo_data(op);
}

impl uo_has_utf8_memory(op: ptr[PyObject]) -> bool {
    if uo_is_compact_ascii(op) {
        return False;
    }
    utf8 = uo_utf8_field(op);
    if not utf8 {
        return False;
    }
    return utf8 != uo_data(op);
}

impl uo_max_char_value(op: ptr[PyObject]) -> u32 {
    if uo_is_ascii(op) {
        return MAX_CHAR_ASCII;
    }
    kind = uo_kind(op);
    if kind == PyUnicode_1BYTE_KIND {
        return MAX_CHAR_UCS1;
    }
    if kind == PyUnicode_2BYTE_KIND {
        return MAX_CHAR_UCS2;
    }
    return MAX_CHAR_UCS4;
}

impl ch_read(kind: i64, data: ptr[u8], i: i64) -> u32 {
    if kind == PyUnicode_1BYTE_KIND {
        return u32((data + i).view(1)[0]);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u32((ptr[u16](data) + i).view(1)[0]);
    }
    return (ptr[u32](data) + i).view(1)[0];
}

impl ch_write(kind: i64, data: ptr[u8], i: i64, ch: u32) {
    if kind == PyUnicode_1BYTE_KIND {
        (data + i).view(1)[0] = u8.wrap(ch);
    } elif kind == PyUnicode_2BYTE_KIND {
        (ptr[u16](data) + i).view(1)[0] = u16.wrap(ch);
    } else {
        (ptr[u32](data) + i).view(1)[0] = ch;
    }
}

impl uo_read_char(op: ptr[PyObject], i: i64) -> u32 {
    return ch_read(uo_kind(op), uo_data(op), i);
}

impl char_ptr(data: ptr[u8], kind: i64, i: i64) -> ptr[u8] {
    return data + i * kind;
}

impl kind_maxchar_limit(kind: i64) -> u32 {
    if kind == PyUnicode_1BYTE_KIND {
        return u32(0x80);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u32(0x100);
    }
    return u32(0x10000);
}

impl max_char_kind(maxchar: u32) -> i64 {
    if maxchar < u32(256) {
        return PyUnicode_1BYTE_KIND;
    }
    if maxchar < u32(65536) {
        return PyUnicode_2BYTE_KIND;
    }
    return PyUnicode_4BYTE_KIND;
}

impl unicode_fill(kind: i64, data: ptr[u8], value: u32, start: i64, length: i64) {
    if kind == PyUnicode_1BYTE_KIND {
        memset(ptr(data + start), i32(value), u64(length));
    } elif kind == PyUnicode_2BYTE_KIND {
        to = ptr[u16](data) + start;
        ch = u16.wrap(value);
        for i in range(length) {
            (to + i).view(1)[0] = ch;
        }
    } else {
        wide = ptr[u32](data) + start;
        for i in range(length) {
            (wide + i).view(1)[0] = value;
        }
    }
}

impl copy_chars(
    from_kind: i64, from_data: ptr[u8], to_kind: i64, to_data: ptr[u8], n: i64
) {
    if from_kind == to_kind {
        memcpy(ptr(to_data), ptr(from_data), u64(n * to_kind));
        return;
    }
    unrolled = n - n % 4;
    i: i64 = 0;
    if from_kind == PyUnicode_1BYTE_KIND and to_kind == PyUnicode_2BYTE_KIND {
        src1 = from_data;
        dst2 = ptr[u16](to_data);
        while i < unrolled {
            (dst2 + i).view(1)[0] = u16((src1 + i).view(1)[0]);
            (dst2 + i + 1).view(1)[0] = u16((src1 + i + 1).view(1)[0]);
            (dst2 + i + 2).view(1)[0] = u16((src1 + i + 2).view(1)[0]);
            (dst2 + i + 3).view(1)[0] = u16((src1 + i + 3).view(1)[0]);
            i += 4;
        }
        while i < n {
            (dst2 + i).view(1)[0] = u16((src1 + i).view(1)[0]);
            i += 1;
        }
    } elif from_kind == PyUnicode_1BYTE_KIND {
        src = from_data;
        dst4 = ptr[u32](to_data);
        while i < unrolled {
            (dst4 + i).view(1)[0] = u32((src + i).view(1)[0]);
            (dst4 + i + 1).view(1)[0] = u32((src + i + 1).view(1)[0]);
            (dst4 + i + 2).view(1)[0] = u32((src + i + 2).view(1)[0]);
            (dst4 + i + 3).view(1)[0] = u32((src + i + 3).view(1)[0]);
            i += 4;
        }
        while i < n {
            (dst4 + i).view(1)[0] = u32((src + i).view(1)[0]);
            i += 1;
        }
    } else {
        src2 = ptr[u16](from_data);
        out4 = ptr[u32](to_data);
        while i < unrolled {
            (out4 + i).view(1)[0] = u32((src2 + i).view(1)[0]);
            (out4 + i + 1).view(1)[0] = u32((src2 + i + 1).view(1)[0]);
            (out4 + i + 2).view(1)[0] = u32((src2 + i + 2).view(1)[0]);
            (out4 + i + 3).view(1)[0] = u32((src2 + i + 3).view(1)[0]);
            i += 4;
        }
        while i < n {
            (out4 + i).view(1)[0] = u32((src2 + i).view(1)[0]);
            i += 1;
        }
    }
}

impl runtime_at(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl interp_at(interp: ptr[u8], offset: i64) -> ptr[u8] {
    return interp + offset;
}

impl unicode_get_empty -> ptr[PyObject] {
    return ptr[PyObject](runtime_at(_PyRuntimeState_STR_EMPTY));
}

impl latin1_char(ch: u32) -> ptr[PyObject] {
    if ch < u32(128) {
        return ptr[PyObject](
            runtime_at(
                _PyRuntimeState_STRINGS_ASCII
                    + i64(ch) * _PyRuntimeState_STRINGS_ASCII_SIZE
            )
        );
    }
    return ptr[PyObject](
        runtime_at(
            _PyRuntimeState_STRINGS_LATIN1
                + i64(ch - u32(128)) * _PyRuntimeState_STRINGS_LATIN1_SIZE
        )
    );
}

impl get_latin1_char(ch: u8) -> ptr[PyObject] {
    return latin1_char(u32(ch));
}

impl unicode_char(ch: u32) -> ptr[PyObject] {
    if ch < u32(256) {
        return latin1_char(ch);
    }
    unicode = PyUnicode_New(1, ch);
    if not unicode {
        return NULL;
    }
    if uo_kind(unicode) == PyUnicode_2BYTE_KIND {
        ptr[u16](uo_data(unicode)).view(1)[0] = u16.wrap(ch);
    } else {
        ptr[u32](uo_data(unicode)).view(1)[0] = ch;
    }
    return unicode;
}

impl unicode_result(unicode: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(unicode);
    if length == 0 {
        empty = unicode_get_empty();
        if unicode != empty {
            object_decref(unicode);
        }
        return empty;
    }
    if length == 1 and uo_kind(unicode) == PyUnicode_1BYTE_KIND {
        latin1 = latin1_char(u32(uo_data(unicode).view(1)[0]));
        if unicode != latin1 {
            object_decref(unicode);
        }
        return latin1;
    }
    return unicode;
}

impl unicode_result_unchanged(unicode: ptr[PyObject]) -> ptr[PyObject] {
    if unicode_check_exact(unicode) {
        return object_new_ref(unicode);
    }
    return _PyUnicode_Copy(unicode);
}

impl ensure_unicode(obj_: ptr[PyObject]) -> i32 {
    if not unicode_check(obj_) {
        PyErr_Format(
            PyExc_TypeError,
            "must be str, not %.100s",
            object_type(obj_).view(1)[0].tp_name
        );
        return i32(-1);
    }
    return i32(0);
}

impl findchar(s: ptr[u8], kind: i64, size: i64, ch: u32, direction: i32) -> i64 {
    if kind == PyUnicode_1BYTE_KIND and ch > u32(0xff) {
        return -1;
    }
    if kind == PyUnicode_2BYTE_KIND and ch > u32(0xffff) {
        return -1;
    }
    if direction > i32(0) {
        return sl_find_char(kind, s, size, ch);
    }
    return sl_rfind_char(kind, s, size, ch);
}

impl sl_new(kind: i64, is_ascii: bool, s: ptr[u8], n: i64) -> ptr[PyObject] {
    if kind == PyUnicode_1BYTE_KIND {
        if is_ascii {
            return _PyUnicode_FromASCII(s, n);
        }
        return _PyUnicode_FromUCS1(s, n);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return _PyUnicode_FromUCS2(ptr[u16](s), n);
    }
    return _PyUnicode_FromUCS4(ptr[u32](s), n);
}

impl unicode_eq(str1: ptr[PyObject], str2: ptr[PyObject]) -> bool {
    length = uo_length(str1);
    if uo_length(str2) != length {
        return False;
    }
    kind = uo_kind(str1);
    if uo_kind(str2) != kind {
        return False;
    }
    return memcmp(ptr(uo_data(str1)), ptr(uo_data(str2)), u64(length * kind)) == i32(0);
}

impl ascii_isspace(ch: u32) -> bool {
    return (addressof(_Py_ascii_whitespace) + i64(ch)).view(1)[0] != u8(0);
}

impl uc_isspace(ch: u32) -> bool {
    if ch < u32(128) {
        return ascii_isspace(ch);
    }
    return _PyUnicode_IsWhitespace(ch) != i32(0);
}

impl uc_islower(ch: u32) -> bool {
    return _PyUnicode_IsLowercase(ch) != i32(0);
}

impl uc_isupper(ch: u32) -> bool {
    return _PyUnicode_IsUppercase(ch) != i32(0);
}

impl uc_istitle(ch: u32) -> bool {
    return _PyUnicode_IsTitlecase(ch) != i32(0);
}

impl uc_islinebreak(ch: u32) -> bool {
    return _PyUnicode_IsLinebreak(ch) != i32(0);
}

impl uc_isdecimal(ch: u32) -> bool {
    return _PyUnicode_IsDecimalDigit(ch) != i32(0);
}

impl uc_isdigit(ch: u32) -> bool {
    return _PyUnicode_IsDigit(ch) != i32(0);
}

impl uc_isnumeric(ch: u32) -> bool {
    return _PyUnicode_IsNumeric(ch) != i32(0);
}

impl uc_isprintable(ch: u32) -> bool {
    return _PyUnicode_IsPrintable(ch) != i32(0);
}

impl uc_isalpha(ch: u32) -> bool {
    return _PyUnicode_IsAlpha(ch) != i32(0);
}

impl uc_isalnum(ch: u32) -> bool {
    return uc_isalpha(ch) or uc_isdecimal(ch) or uc_isdigit(ch) or uc_isnumeric(ch);
}

impl uc_tolower(ch: u32) -> u32 {
    return _PyUnicode_ToLowercase(ch);
}

impl uc_toupper(ch: u32) -> u32 {
    return _PyUnicode_ToUppercase(ch);
}

impl uc_totitle(ch: u32) -> u32 {
    return _PyUnicode_ToTitlecase(ch);
}

impl uc_todecimal(ch: u32) -> i32 {
    return _PyUnicode_ToDecimalDigit(ch);
}

impl uc_todigit(ch: u32) -> i32 {
    return _PyUnicode_ToDigit(ch);
}

impl uc_is_surrogate(ch: u32) -> bool {
    return u32(0xD800) <= ch and ch <= u32(0xDFFF);
}

impl uc_is_high_surrogate(ch: u32) -> bool {
    return u32(0xD800) <= ch and ch <= u32(0xDBFF);
}

impl uc_is_low_surrogate(ch: u32) -> bool {
    return u32(0xDC00) <= ch and ch <= u32(0xDFFF);
}

impl uc_join_surrogates(hi: u32, lo: u32) -> u32 {
    return u32(0x10000) + (((hi & u32(0x03FF)) << u32(10)) | (lo & u32(0x03FF)));
}

impl uc_high_surrogate(ch: u32) -> u32 {
    return u32(0xD800 - (0x10000 >> 10)) + (ch >> u32(10));
}

impl uc_low_surrogate(ch: u32) -> u32 {
    return u32(0xDC00) + (ch & u32(0x3FF));
}

impl bloom(mask: u64, ch: u32) -> bool {
    return (mask & (u64(1) << (u64(ch) & (BLOOM_WIDTH - u64(1))))) != u64(0);
}

impl bloom_add(mask: u64, ch: u32) -> u64 {
    return mask | (u64(1) << (u64(ch) & (BLOOM_WIDTH - u64(1))));
}

impl bloom_linebreak_mask -> u64 {
    return ptr[u64](addressof(bloom_linebreak)).view(1)[0];
}

impl set_bloom_linebreak(mask: u64) {
    ptr[u64](addressof(bloom_linebreak)).view(1)[0] = mask;
}

impl bloom_is_linebreak(ch: u32) -> bool {
    if ch < u32(128) {
        return (addressof(ascii_linebreak) + i64(ch)).view(1)[0] != u8(0);
    }
    return bloom(bloom_linebreak_mask(), ch) and uc_islinebreak(ch);
}

impl interned_dict(interp: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](interp + PyInterpreterState_INTERNED_STRINGS).view(1)[0];
}

impl set_interned_dict(interp: ptr[u8], d: ptr[PyObject]) {
    ptr[ptr[PyObject]](interp + PyInterpreterState_INTERNED_STRINGS).view(1)[0] = d;
}

impl interned_strings_table -> ptr {
    return ptr[ptr](runtime_at(_PyRuntimeState_INTERNED_STRINGS)).view(1)[0];
}

impl set_interned_strings_table(t: ptr) {
    ptr[ptr](runtime_at(_PyRuntimeState_INTERNED_STRINGS)).view(1)[0] = t;
}

impl fs_codec_encoding(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_UNICODE_FS_CODEC_ENCODING).view(1)[
        0
    ];
}

impl set_fs_codec_encoding(interp: ptr[u8], v: ptr[u8]) {
    ptr[ptr[u8]](interp + PyInterpreterState_UNICODE_FS_CODEC_ENCODING).view(1)[0] = v;
}

impl fs_codec_utf8(interp: ptr[u8]) -> i32 {
    return ptr[i32](interp + PyInterpreterState_UNICODE_FS_CODEC_UTF8).view(1)[0];
}

impl set_fs_codec_utf8(interp: ptr[u8], v: i32) {
    ptr[i32](interp + PyInterpreterState_UNICODE_FS_CODEC_UTF8).view(1)[0] = v;
}

impl fs_codec_errors(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_UNICODE_FS_CODEC_ERRORS).view(1)[0];
}

impl set_fs_codec_errors(interp: ptr[u8], v: ptr[u8]) {
    ptr[ptr[u8]](interp + PyInterpreterState_UNICODE_FS_CODEC_ERRORS).view(1)[0] = v;
}

impl fs_codec_error_handler(interp: ptr[u8]) -> i32 {
    return ptr[i32](interp + PyInterpreterState_UNICODE_FS_CODEC_ERROR_HANDLER).view(1)[
        0
    ];
}

impl set_fs_codec_error_handler(interp: ptr[u8], v: i32) {
    ptr[i32](interp + PyInterpreterState_UNICODE_FS_CODEC_ERROR_HANDLER).view(1)[0] = v;
}

impl writer_new -> ptr[UnicodeWriter] {
    writer = ptr[UnicodeWriter](PyMem_Malloc(u64(_PyUnicodeWriter_SIZE)));
    if not writer {
        PyErr_NoMemory();
        return writer;
    }
    _PyUnicodeWriter_Init(writer);
    return writer;
}

impl writer_free(writer: ptr[UnicodeWriter]) {
    PyMem_Free(ptr(writer));
}

impl writer_update(writer: ptr[UnicodeWriter]) {
    buffer = writer.view(1)[0].buffer;
    writer.view(1)[0].maxchar = uo_max_char_value(buffer);
    writer.view(1)[0].data = uo_data(buffer);
    if writer.view(1)[0].readonly == u8(0) {
        writer.view(1)[0].kind = i32(uo_kind(buffer));
        writer.view(1)[0].size = uo_length(buffer);
    } else {
        writer.view(1)[0].kind = i32(0);
        writer.view(1)[0].size = 0;
    }
}

impl writer_init_with_buffer(writer: ptr[UnicodeWriter], buffer: ptr[PyObject]) {
    memset(ptr(writer), i32(0), u64(_PyUnicodeWriter_SIZE));
    writer.view(1)[0].buffer = buffer;
    writer_update(writer);
    writer.view(1)[0].min_length = writer.view(1)[0].size;
}

impl writer_prepare(writer: ptr[UnicodeWriter], length: i64, maxchar: u32) -> i32 {
    if maxchar <= writer.view(1)[0].maxchar
        and length <= writer.view(1)[0].size - writer.view(1)[0].pos {
        return i32(0);
    }
    if length == 0 {
        return i32(0);
    }
    return _PyUnicodeWriter_PrepareInternal(writer, length, maxchar);
}

impl writer_prepare_kind(writer: ptr[UnicodeWriter], kind: i64) -> i32 {
    if kind <= i64(writer.view(1)[0].kind) {
        return i32(0);
    }
    return _PyUnicodeWriter_PrepareKindInternal(writer, i32(kind));
}

impl writer_write_char_inline(writer: ptr[UnicodeWriter], ch: u32) -> i32 {
    if writer_prepare(writer, 1, ch) < i32(0) {
        return i32(-1);
    }
    pos = writer.view(1)[0].pos;
    ch_write(i64(writer.view(1)[0].kind), writer.view(1)[0].data, pos, ch);
    writer.view(1)[0].pos = pos + 1;
    return i32(0);
}

impl bytes_writer_new -> ptr[BytesWriterFields] {
    writer = ptr[BytesWriterFields](PyMem_Malloc(u64(_PyBytesWriter_SIZE)));
    if not writer {
        PyErr_NoMemory();
        return writer;
    }
    _PyBytesWriter_Init(writer);
    return writer;
}

impl bytes_writer_free(writer: ptr[BytesWriterFields]) {
    PyMem_Free(ptr(writer));
}

impl wide_equals_ascii(w: ptr[i32], s: ptr[u8]) -> bool {
    i: i64 = 0;
    while True {
        c = i32((s + i).view(1)[0]);
        if (w + i).view(1)[0] != c {
            return False;
        }
        if c == i32(0) {
            return True;
        }
        i += 1;
    }
    return False;
}

impl get_error_handler_wide(errors: ptr[i32]) -> i32 {
    if not errors or wide_equals_ascii(errors, ptr[u8]("strict")) {
        return _Py_ERROR_STRICT;
    }
    if wide_equals_ascii(errors, ptr[u8]("surrogateescape")) {
        return _Py_ERROR_SURROGATEESCAPE;
    }
    if wide_equals_ascii(errors, ptr[u8]("replace")) {
        return _Py_ERROR_REPLACE;
    }
    if wide_equals_ascii(errors, ptr[u8]("ignore")) {
        return _Py_ERROR_IGNORE;
    }
    if wide_equals_ascii(errors, ptr[u8]("backslashreplace")) {
        return _Py_ERROR_BACKSLASHREPLACE;
    }
    if wide_equals_ascii(errors, ptr[u8]("surrogatepass")) {
        return _Py_ERROR_SURROGATEPASS;
    }
    if wide_equals_ascii(errors, ptr[u8]("xmlcharrefreplace")) {
        return _Py_ERROR_XMLCHARREFREPLACE;
    }
    return _Py_ERROR_OTHER;
}

impl unicode_check_encoding_errors(encoding: ptr[u8], errors: ptr[u8]) -> i32 {
    if not encoding and not errors {
        return i32(0);
    }
    interp = current_interp();

    if ptr[i32](_Py_GetConfig() + PyConfig_DEV_MODE).view(1)[0] == i32(0) {
        return i32(0);
    }

    if not fs_codec_encoding(interp) {
        return i32(0);
    }

    if ptr[ptr](interp + PyInterpreterState_FINALIZING).view(1)[0] {
        return i32(0);
    }

    if encoding
        and strcmp(encoding, ptr[u8]("utf-8")) != i32(0)
        and strcmp(encoding, ptr[u8]("utf8")) != i32(0)
        and strcmp(encoding, ptr[u8]("ascii")) != i32(0) {
        handler = _PyCodec_Lookup(encoding);
        if not handler {
            return i32(-1);
        }
        object_decref(handler);
    }

    if errors
        and strcmp(errors, ptr[u8]("strict")) != i32(0)
        and strcmp(errors, ptr[u8]("ignore")) != i32(0)
        and strcmp(errors, ptr[u8]("replace")) != i32(0)
        and strcmp(errors, ptr[u8]("surrogateescape")) != i32(0)
        and strcmp(errors, ptr[u8]("surrogatepass")) != i32(0) {
        error_handler = PyCodec_LookupError(errors);
        if not error_handler {
            return i32(-1);
        }
        object_decref(error_handler);
    }
    return i32(0);
}

impl consistency_check(op: ptr[PyObject], ok: bool, expr: ptr[u8], line: i32) {
    if not ok {
        _PyObject_AssertFailed(
            op,
            ptr[u8](),
            expr,
            ptr[u8]("Objects/unicodeobject.c"),
            line,
            ptr[u8]("_PyUnicode_CheckConsistency")
        );
    }
}

impl hexdigit_of(x: u32) -> u8 {
    return u8(48 + x) if x < u32(10) else u8(87 + x);
}

impl emit_byte(p: ptr[u8], c: u8) -> ptr[u8] {
    p.view(1)[0] = c;
    return p + 1;
}

impl backslashreplace(
    writer: ptr[BytesWriterFields],
    s: ptr[u8],
    unicode: ptr[PyObject],
    collstart: i64,
    collend: i64
) -> ptr[u8] {
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    size: i64 = 0;
    incr: i64 = 0;

    i = collstart;
    while i < collend {
        ch = ch_read(kind, data, i);
        if ch < u32(0x100) {
            incr = 2 + 2;
        } elif ch < u32(0x10000) {
            incr = 2 + 4;
        } else {
            incr = 2 + 8;
        }
        if size > PY_SSIZE_T_MAX - incr {
            PyErr_SetString(
                PyExc_OverflowError, "encoded result is too long for a Python string"
            );
            return ptr[u8]();
        }
        size += incr;
        i += 1;
    }
    out = ptr[u8](_PyBytesWriter_Prepare(writer, ptr(s), size));
    if not out {
        return out;
    }

    i = collstart;
    while i < collend {
        ch = ch_read(kind, data, i);
        out = emit_byte(out, u8(92));
        if ch >= u32(0x00010000) {
            out = emit_byte(out, u8(85));
            out = emit_byte(out, hexdigit_of((ch >> u32(28)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(24)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(20)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(16)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(12)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(8)) & u32(0xf)));
        } elif ch >= u32(0x100) {
            out = emit_byte(out, u8(117));
            out = emit_byte(out, hexdigit_of((ch >> u32(12)) & u32(0xf)));
            out = emit_byte(out, hexdigit_of((ch >> u32(8)) & u32(0xf)));
        } else {
            out = emit_byte(out, u8(120));
        }
        out = emit_byte(out, hexdigit_of((ch >> u32(4)) & u32(0xf)));
        out = emit_byte(out, hexdigit_of(ch & u32(0xf)));
        i += 1;
    }
    return out;
}

impl xmlcharrefreplace(
    writer: ptr[BytesWriterFields],
    s: ptr[u8],
    unicode: ptr[PyObject],
    collstart: i64,
    collend: i64
) -> ptr[u8] {
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    size: i64 = 0;
    incr: i64 = 0;

    i = collstart;
    while i < collend {
        ch = ch_read(kind, data, i);
        if ch < u32(10) {
            incr = 2 + 1 + 1;
        } elif ch < u32(100) {
            incr = 2 + 2 + 1;
        } elif ch < u32(1000) {
            incr = 2 + 3 + 1;
        } elif ch < u32(10000) {
            incr = 2 + 4 + 1;
        } elif ch < u32(100000) {
            incr = 2 + 5 + 1;
        } elif ch < u32(1000000) {
            incr = 2 + 6 + 1;
        } else {
            incr = 2 + 7 + 1;
        }
        if size > PY_SSIZE_T_MAX - incr {
            PyErr_SetString(
                PyExc_OverflowError, "encoded result is too long for a Python string"
            );
            return ptr[u8]();
        }
        size += incr;
        i += 1;
    }
    out = ptr[u8](_PyBytesWriter_Prepare(writer, ptr(s), size));
    if not out {
        return out;
    }

    i = collstart;
    while i < collend {
        written = sprintf(out, ptr[u8]("&#%d;"), i32(ch_read(kind, data, i)));
        if written < i32(0) {
            return ptr[u8]();
        }
        out = out + i64(written);
        i += 1;
    }
    return out;
}

impl make_bloom_mask(kind: i64, data: ptr[u8], len: i64) -> u64 {
    mask = u64(0);
    if kind == PyUnicode_1BYTE_KIND {
        for i in range(len) {
            mask = bloom_add(mask, u32((data + i).view(1)[0]));
        }
    } elif kind == PyUnicode_2BYTE_KIND {
        data2 = ptr[u16](data);
        for i in range(len) {
            mask = bloom_add(mask, u32((data2 + i).view(1)[0]));
        }
    } else {
        data4 = ptr[u32](data);
        for i in range(len) {
            mask = bloom_add(mask, (data4 + i).view(1)[0]);
        }
    }
    return mask;
}

impl resize_copy(unicode: ptr[PyObject], length: i64) -> ptr[PyObject] {
    copy = PyUnicode_New(length, uo_max_char_value(unicode));
    if not copy {
        return NULL;
    }
    copy_length = min(length, uo_length(unicode));
    _PyUnicode_FastCopyCharacters(copy, 0, unicode, 0, copy_length);
    return copy;
}

impl resize_compact(unicode: ptr[PyObject], length: i64) -> ptr[PyObject] {
    if not unicode_modifiable(unicode) {
        copy = resize_copy(unicode, length);
        if not copy {
            return NULL;
        }
        object_decref(unicode);
        return copy;
    }
    char_size = uo_kind(unicode);
    struct_size = PyASCIIObject_SIZE
        if uo_is_ascii(unicode)
        else PyCompactUnicodeObject_SIZE;
    if length > ((PY_SSIZE_T_MAX - struct_size) // char_size - 1) {
        PyErr_NoMemory();
        return NULL;
    }
    new_size = struct_size + (length + 1) * char_size;
    if uo_has_utf8_memory(unicode) {
        PyMem_Free(ptr(uo_utf8_field(unicode)));
        uo_set_utf8_length(unicode, 0);
        uo_set_utf8(unicode, ptr[u8]());
    }
    reftracer_track(unicode, PYREFTRACER_DESTROY);
    new_unicode = PyObject_Realloc(ptr(unicode), u64(new_size));
    if not new_unicode {
        _Py_NewReferenceNoTotal(unicode);
        PyErr_NoMemory();
        return NULL;
    }
    resized = ptr[PyObject](new_unicode);
    _Py_NewReferenceNoTotal(resized);
    uo_set_length(resized, length);
    ch_write(uo_kind(resized), uo_data(resized), length, u32(0));
    return resized;
}

impl resize_inplace(unicode: ptr[PyObject], length: i64) -> i32 {
    data = uo_data_any(unicode);
    char_size = uo_kind(unicode);
    share_utf8 = uo_share_utf8(unicode);
    if length > (PY_SSIZE_T_MAX // char_size - 1) {
        PyErr_NoMemory();
        return i32(-1);
    }
    new_size = (length + 1) * char_size;
    if not share_utf8 and uo_has_utf8_memory(unicode) {
        PyMem_Free(ptr(uo_utf8_field(unicode)));
        uo_set_utf8_length(unicode, 0);
        uo_set_utf8(unicode, ptr[u8]());
    }
    new_data = ptr[u8](PyObject_Realloc(ptr(data), u64(new_size)));
    if not new_data {
        PyErr_NoMemory();
        return i32(-1);
    }
    uo_set_data_any(unicode, new_data);
    if share_utf8 {
        uo_set_utf8_length(unicode, length);
        uo_set_utf8(unicode, new_data);
    }
    uo_set_length(unicode, length);
    ch_write(uo_kind(unicode), new_data, length, u32(0));

    if length > PY_SSIZE_T_MAX // 4 - 1 {
        PyErr_NoMemory();
        return i32(-1);
    }
    return i32(0);
}

impl unicode_kind_name(unicode: ptr[PyObject]) -> ptr[u8] {
    kind = uo_kind(unicode);
    if not uo_is_compact(unicode) {
        if kind == PyUnicode_1BYTE_KIND {
            if uo_is_ascii(unicode) {
                return ptr[u8]("legacy ascii");
            }
            return ptr[u8]("legacy latin1");
        }
        if kind == PyUnicode_2BYTE_KIND {
            return ptr[u8]("legacy UCS2");
        }
        if kind == PyUnicode_4BYTE_KIND {
            return ptr[u8]("legacy UCS4");
        }
        return ptr[u8]("<legacy invalid kind>");
    }
    if kind == PyUnicode_1BYTE_KIND {
        if uo_is_ascii(unicode) {
            return ptr[u8]("ascii");
        }
        return ptr[u8]("latin1");
    }
    if kind == PyUnicode_2BYTE_KIND {
        return ptr[u8]("UCS2");
    }
    if kind == PyUnicode_4BYTE_KIND {
        return ptr[u8]("UCS4");
    }
    return ptr[u8]("<invalid compact kind>");
}

impl unicode_check_modifiable(unicode: ptr[PyObject]) -> i32 {
    if not unicode_modifiable(unicode) {
        PyErr_SetString(PyExc_SystemError, "Cannot modify a string currently used");
        return i32(-1);
    }
    return i32(0);
}

impl narrow_chars(
    from_kind: i64, from_data: ptr[u8], to_kind: i64, to_data: ptr[u8], n: i64
) {
    if from_kind == PyUnicode_2BYTE_KIND {
        src2 = ptr[u16](from_data);
        for i in range(n) {
            (to_data + i).view(1)[0] = u8.wrap((src2 + i).view(1)[0]);
        }
    } elif to_kind == PyUnicode_1BYTE_KIND {
        src4 = ptr[u32](from_data);
        for i in range(n) {
            (to_data + i).view(1)[0] = u8.wrap((src4 + i).view(1)[0]);
        }
    } else {
        src = ptr[u32](from_data);
        dst2 = ptr[u16](to_data);
        for i in range(n) {
            (dst2 + i).view(1)[0] = u16.wrap((src + i).view(1)[0]);
        }
    }
}

impl _copy_characters(
    to: ptr[PyObject],
    to_start: i64,
    from_obj: ptr[PyObject],
    from_start: i64,
    how_many: i64,
    check_maxchar: bool
) -> i32 {
    if how_many == 0 {
        return i32(0);
    }
    from_kind = uo_kind(from_obj);
    from_data = uo_data(from_obj);
    to_kind = uo_kind(to);
    to_data = uo_data(to);
    if from_kind == to_kind {
        if check_maxchar and not uo_is_ascii(from_obj) and uo_is_ascii(to) {
            max_char = sl_find_max_char(PyUnicode_1BYTE_KIND, from_data, how_many);
            if max_char >= u32(128) {
                return i32(-1);
            }
        }
        memcpy(
            ptr(to_data + to_kind * to_start),
            ptr(from_data + from_kind * from_start),
            u64(to_kind * how_many)
        );
    } elif from_kind < to_kind {
        copy_chars(
            from_kind,
            char_ptr(from_data, from_kind, from_start),
            to_kind,
            char_ptr(to_data, to_kind, to_start),
            how_many
        );
    } elif not check_maxchar {
        narrow_chars(
            from_kind,
            char_ptr(from_data, from_kind, from_start),
            to_kind,
            char_ptr(to_data, to_kind, to_start),
            how_many
        );
    } else {
        to_maxchar = uo_max_char_value(to);
        for i in range(how_many) {
            ch = ch_read(from_kind, from_data, from_start + i);
            if ch > to_maxchar {
                return i32(-1);
            }
            ch_write(to_kind, to_data, to_start + i, ch);
        }
    }
    return i32(0);
}

impl find_maxchar_surrogates(begin: ptr[i32], end: ptr[i32]) -> tuple[i32, u32, i64] {
    num_surrogates: i64 = 0;
    maxchar = u32(0);
    it = begin;
    while it < end {
        ch = u32.wrap(it.view(1)[0]);
        it = it + 1;
        if ch > maxchar {
            maxchar = ch;
            if maxchar > MAX_UNICODE {
                PyErr_Format(
                    PyExc_ValueError,
                    "character U+%x is not in range [U+0000; U+%x]",
                    ch,
                    MAX_UNICODE
                );
                return (i32(-1), maxchar, num_surrogates);
            }
        }
    }
    return (i32(0), maxchar, num_surrogates);
}

impl unicode_set_refcnt(op: ptr[PyObject], refcnt: i64) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0x80000000) != 0 {
        return;
    }
    header.view(1)[0].ob_refcnt_full = (full - (full & 0xFFFFFFFF)) | refcnt;
}

impl unicode_dealloc(unicode: ptr[PyObject]) {
    if uo_is_static(unicode) {
        _Py_SetImmortal(unicode);
        return;
    }
    interned = uo_interned(unicode);
    if interned == SSTATE_INTERNED_MORTAL {
        unicode_set_refcnt(unicode, 2);
        interp = current_interp();
        interned_d = interned_dict(interp);
        popped_slot = addressof(dealloc_popped);
        r = PyDict_Pop(interned_d, unicode, popped_slot);
        popped_slot.view(1)[0] = ptr[PyObject]();
        if r == i32(-1) {
            PyErr_FormatUnraisable(
                "Exception ignored while removing an interned string %R", unicode
            );

            _Py_SetImmortal(unicode);
            uo_set_interned(unicode, SSTATE_INTERNED_IMMORTAL);
            return;
        }
        if r == i32(0) {
            _Py_SetImmortal(unicode);
            return;
        }

        unicode_set_refcnt(unicode, 0);
    } elif interned != SSTATE_NOT_INTERNED {
        _Py_SetImmortal(unicode);
        return;
    }
    if uo_has_utf8_memory(unicode) {
        PyMem_Free(ptr(uo_utf8_field(unicode)));
    }
    if not uo_is_compact(unicode) and uo_data_any(unicode) {
        PyMem_Free(ptr(uo_data_any(unicode)));
    }
    object_type(unicode).view(1)[0].tp_free(ptr(unicode));
}

impl unicode_is_singleton(unicode: ptr[PyObject]) -> bool {
    if unicode == unicode_get_empty() {
        return True;
    }
    if uo_length(unicode) == 1 {
        ch = uo_read_char(unicode, 0);
        if ch < u32(256) and latin1_char(ch) == unicode {
            return True;
        }
    }
    return False;
}

impl unicode_modifiable(unicode: ptr[PyObject]) -> bool {
    if object_refcount(unicode) != 1 {
        return False;
    }
    if uo_hash(unicode) != -1 {
        return False;
    }
    if uo_interned(unicode) != SSTATE_NOT_INTERNED {
        return False;
    }
    if not unicode_check_exact(unicode) {
        return False;
    }
    return True;
}

impl unicode_resize(unicode: ptr[PyObject], length: i64) -> tuple[i32, ptr[PyObject]] {
    old_length = uo_length(unicode);
    if old_length == length {
        return (i32(0), unicode);
    }
    if length == 0 {
        empty = unicode_get_empty();
        object_decref(unicode);
        return (i32(0), empty);
    }
    if not unicode_modifiable(unicode) {
        copy = resize_copy(unicode, length);
        if not copy {
            return (i32(-1), unicode);
        }
        object_decref(unicode);
        return (i32(0), copy);
    }
    if uo_is_compact(unicode) {
        new_unicode = resize_compact(unicode, length);
        if not new_unicode {
            return (i32(-1), unicode);
        }
        return (i32(0), new_unicode);
    }
    return (resize_inplace(unicode, length), unicode);
}

impl unicode_write_cstr(unicode: ptr[PyObject], index: i64, s: ptr[u8], len: i64) {
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    if kind == PyUnicode_1BYTE_KIND {
        memcpy(ptr(data + index), ptr(s), u64(len));
    } elif kind == PyUnicode_2BYTE_KIND {
        ucs2 = ptr[u16](data) + index;
        for i in range(len) {
            (ucs2 + i).view(1)[0] = u16((s + i).view(1)[0]);
        }
    } else {
        ucs4 = ptr[u32](data) + index;
        for i in range(len) {
            (ucs4 + i).view(1)[0] = u32((s + i).view(1)[0]);
        }
    }
}

impl unicode_write_widechar(
    kind: i64, data: ptr[u8], u: ptr[i32], size: i64, num_surrogates: i64
) {
    if kind == PyUnicode_1BYTE_KIND {
        for i in range(size) {
            (data + i).view(1)[0] = u8.wrap((u + i).view(1)[0]);
        }
    } elif kind == PyUnicode_2BYTE_KIND {
        data2 = ptr[u16](data);
        for i in range(size) {
            (data2 + i).view(1)[0] = u16.wrap((u + i).view(1)[0]);
        }
    } else {
        memcpy(ptr(data), ptr(u), u64(size * 4));
    }
}

impl unicode_clear_identifiers(interp: ptr[u8]) {
    ids_size = ptr[i64](interp_at(interp, PyInterpreterState_UNICODE_IDS_SIZE));
    ids_array = ptr[ptr[ptr[PyObject]]](
        interp_at(interp, PyInterpreterState_UNICODE_IDS_ARRAY)
    );
    array = ids_array.view(1)[0];
    for i in range(ids_size.view(1)[0]) {
        object_xdecref((array + i).view(1)[0]);
    }
    ids_size.view(1)[0] = 0;
    PyMem_Free(ptr(array));
    ids_array.view(1)[0] = ptr[ptr[PyObject]]();
}

impl _PyUnicode_FromUCS1(u: ptr[u8], size: i64) -> ptr[PyObject] {
    if size == 0 {
        return unicode_get_empty();
    }
    if size == 1 {
        return get_latin1_char(u.view(1)[0]);
    }
    max_char = sl_find_max_char(PyUnicode_1BYTE_KIND, u, size);
    res = PyUnicode_New(size, max_char);
    if not res {
        return NULL;
    }
    memcpy(ptr(uo_data(res)), ptr(u), u64(size));
    return res;
}

impl _PyUnicode_FromUCS2(u: ptr[u16], size: i64) -> ptr[PyObject] {
    if size == 0 {
        return unicode_get_empty();
    }
    if size == 1 {
        return unicode_char(u32(u.view(1)[0]));
    }
    max_char = sl_find_max_char(PyUnicode_2BYTE_KIND, ptr[u8](u), size);
    res = PyUnicode_New(size, max_char);
    if not res {
        return NULL;
    }
    if max_char >= u32(256) {
        memcpy(ptr(uo_data(res)), ptr(u), u64(2 * size));
    } else {
        narrow_chars(
            PyUnicode_2BYTE_KIND, ptr[u8](u), PyUnicode_1BYTE_KIND, uo_data(res), size
        );
    }
    return res;
}

impl _PyUnicode_FromUCS4(u: ptr[u32], size: i64) -> ptr[PyObject] {
    if size == 0 {
        return unicode_get_empty();
    }
    if size == 1 {
        return unicode_char(u.view(1)[0]);
    }
    max_char = sl_find_max_char(PyUnicode_4BYTE_KIND, ptr[u8](u), size);
    res = PyUnicode_New(size, max_char);
    if not res {
        return NULL;
    }
    if max_char < u32(256) {
        narrow_chars(
            PyUnicode_4BYTE_KIND, ptr[u8](u), PyUnicode_1BYTE_KIND, uo_data(res), size
        );
    } elif max_char < u32(0x10000) {
        narrow_chars(
            PyUnicode_4BYTE_KIND, ptr[u8](u), PyUnicode_2BYTE_KIND, uo_data(res), size
        );
    } else {
        memcpy(ptr(uo_data(res)), ptr(u), u64(4 * size));
    }
    return res;
}

impl unicode_adjust_maxchar(unicode: ptr[PyObject]) -> ptr[PyObject] {
    if uo_is_ascii(unicode) {
        return unicode;
    }
    length = uo_length(unicode);
    kind = uo_kind(unicode);
    max_char = sl_find_max_char(kind, uo_data(unicode), length);
    if kind == PyUnicode_1BYTE_KIND {
        if max_char >= u32(128) {
            return unicode;
        }
    } elif kind == PyUnicode_2BYTE_KIND {
        if max_char >= u32(256) {
            return unicode;
        }
    } elif max_char >= u32(0x10000) {
        return unicode;
    }
    copy = PyUnicode_New(length, max_char);
    if copy {
        _PyUnicode_FastCopyCharacters(copy, 0, unicode, 0, length);
    }
    object_decref(unicode);
    return copy;
}

impl mem_new_items(n: i64, item_size: i64) -> ptr[u8] {
    if u64.wrap(n) > u64(PY_SSIZE_T_MAX // item_size) {
        return ptr[u8]();
    }
    return ptr[u8](PyMem_Malloc(u64(n * item_size)));
}

impl unicode_askind(skind: i64, data: ptr[u8], len: i64, kind: i64) -> ptr[u8] {
    if kind == PyUnicode_2BYTE_KIND {
        result = mem_new_items(len, 2);
        if not result {
            PyErr_NoMemory();
            return result;
        }
        copy_chars(PyUnicode_1BYTE_KIND, data, PyUnicode_2BYTE_KIND, result, len);
        return result;
    }

    wide = mem_new_items(len, 4);
    if not wide {
        PyErr_NoMemory();
        return wide;
    }
    copy_chars(skind, data, PyUnicode_4BYTE_KIND, wide, len);
    return wide;
}

impl as_ucs4(
    string: ptr[PyObject], target_arg: ptr[u32], targetsize: i64, copy_null: bool
) -> ptr[u32] {
    kind = uo_kind(string);
    data = uo_data(string);
    length = uo_length(string);
    targetlen = length;
    if copy_null {
        targetlen += 1;
    }
    target = target_arg;
    if not target {
        target = ptr[u32](mem_new_items(targetlen, 4));
        if not target {
            PyErr_NoMemory();
            return target;
        }
    } elif targetsize < targetlen {
        PyErr_Format(PyExc_SystemError, "string is longer than the buffer");
        if copy_null and 0 < targetsize {
            target.view(1)[0] = u32(0);
        }
        return ptr[u32]();
    }
    copy_chars(kind, data, PyUnicode_4BYTE_KIND, ptr[u8](target), length);
    if copy_null {
        (target + length).view(1)[0] = u32(0);
    }
    return target;
}

impl unicode_get_widechar_size(unicode: ptr[PyObject]) -> i64 {
    return uo_length(unicode);
}

impl unicode_copy_as_widechar(unicode: ptr[PyObject], w: ptr[i32], size: i64) {
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    if kind == PyUnicode_4BYTE_KIND {
        memcpy(ptr(w), ptr(data), u64(size * 4));
        return;
    }
    if kind == PyUnicode_1BYTE_KIND {
        for i in range(size) {
            (w + i).view(1)[0] = i32((data + i).view(1)[0]);
        }
    } else {
        s = ptr[u16](data);
        for i in range(size) {
            (w + i).view(1)[0] = i32((s + i).view(1)[0]);
        }
    }
}

impl unicode_as_widechar_string(
    unicode: ptr[PyObject], reject_nul: bool
) -> tuple[ptr[i32], i64] {
    if not unicode {
        PyErr_BadInternalCall();
        return (ptr[i32](), i64(-1));
    }
    if not unicode_check(unicode) {
        PyErr_BadArgument();
        return (ptr[i32](), i64(-1));
    }
    buflen = unicode_get_widechar_size(unicode);

    if buflen + 1 > PY_SSIZE_T_MAX // 4 {
        PyErr_NoMemory();
        return (ptr[i32](), i64(-1));
    }
    buffer = ptr[i32](PyMem_Malloc(u64((buflen + 1) * 4)));
    if not buffer {
        PyErr_NoMemory();
        return (ptr[i32](), i64(-1));
    }
    unicode_copy_as_widechar(unicode, buffer, buflen + 1);
    if reject_nul and wcslen(buffer) != u64(buflen) {
        PyMem_Free(ptr(buffer));
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        return (ptr[i32](), i64(-1));
    }
    return (buffer, buflen);
}

impl codec_shortcut(encoding: ptr[u8]) -> tuple[i32, i64] {
    buflower = ptr[u8](PyMem_Malloc(u64(SHORTCUT_BUFLOWER)));
    if not buflower {
        PyErr_NoMemory();
        return (i32(-1), SHORTCUT_NONE);
    }
    codec = SHORTCUT_NONE;
    if _Py_normalize_encoding(encoding, buflower, u64(SHORTCUT_BUFLOWER)) != 0 {
        lower = buflower;
        if lower.view(1)[0] == u8(117)
            and (lower + 1).view(1)[0] == u8(116)
            and (lower + 2).view(1)[0] == u8(102) {
            lower = lower + 3;
            if lower.view(1)[0] == u8(95) {
                lower = lower + 1;
            }
            if lower.view(1)[0] == u8(56) and (lower + 1).view(1)[0] == u8(0) {
                codec = SHORTCUT_UTF8;
            } elif lower.view(1)[0] == u8(49)
                and (lower + 1).view(1)[0] == u8(54)
                and (lower + 2).view(1)[0] == u8(0) {
                codec = SHORTCUT_UTF16;
            } elif lower.view(1)[0] == u8(51)
                and (lower + 1).view(1)[0] == u8(50)
                and (lower + 2).view(1)[0] == u8(0) {
                codec = SHORTCUT_UTF32;
            }
        } elif strcmp(lower, ptr[u8]("ascii")) == 0
            or strcmp(lower, ptr[u8]("us_ascii")) == 0 {
            codec = SHORTCUT_ASCII;
        } elif strcmp(lower, ptr[u8]("latin1")) == 0
            or strcmp(lower, ptr[u8]("latin_1")) == 0
            or strcmp(lower, ptr[u8]("iso_8859_1")) == 0
            or strcmp(lower, ptr[u8]("iso8859_1")) == 0 {
            codec = SHORTCUT_LATIN1;
        }
    }
    PyMem_Free(ptr(buflower));
    return (i32(0), codec);
}

impl unicode_encode_locale(
    unicode: ptr[PyObject], error_handler: i32, current_locale: i32
) -> ptr[PyObject] {
    (wstr, wlen) = unicode_as_widechar_string(unicode, False);
    if not wstr {
        return NULL;
    }
    if u64(wlen) != wcslen(wstr) {
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        PyMem_Free(ptr(wstr));
        return NULL;
    }
    encoded = ptr[u8]();
    error_pos = u64(0);
    reason = ptr[u8]();
    res = _Py_EncodeLocaleEx(
        wstr, &mut encoded, &mut error_pos, &mut reason, current_locale, error_handler
    );
    PyMem_Free(ptr(wstr));
    if res != 0 {
        if res == -2 {
            pos = i64(error_pos);
            exc = PyObject_CallFunction(
                PyExc_UnicodeEncodeError,
                "sOnns",
                ptr[u8]("locale"),
                unicode,
                pos,
                pos + 1,
                reason
            );
            if exc {
                PyCodec_StrictErrors(exc);
                object_decref(exc);
            }
        } elif res == -3 {
            PyErr_SetString(PyExc_ValueError, "unsupported error handler");
        } else {
            PyErr_NoMemory();
        }
        return NULL;
    }
    bytes_obj = PyBytes_FromString(ptr(encoded));
    PyMem_RawFree(ptr(encoded));
    return bytes_obj;
}

impl config_filesystem_errors(interp: ptr[u8]) -> ptr[i32] {
    config = _PyInterpreterState_GetConfig(interp);
    return ptr[ptr[i32]](config + PyConfig_FILESYSTEM_ERRORS).view(1)[0];
}

impl unicode_decode_locale(
    s: ptr[u8], length: i64, errors: i32, current_locale: i32
) -> ptr[PyObject] {
    if (s + length).view(1)[0] != u8(0) or i64(strlen(s)) != length {
        PyErr_SetString(PyExc_ValueError, "embedded null byte");
        return NULL;
    }
    wstr = ptr[i32]();
    wlen = u64(0);
    reason = ptr[u8]();
    res = _Py_DecodeLocaleEx(
        s, &mut wstr, &mut wlen, &mut reason, current_locale, errors
    );
    if res != 0 {
        if res == -2 {
            pos = i64(wlen);
            exc = PyObject_CallFunction(
                PyExc_UnicodeDecodeError,
                "sy#nns",
                ptr[u8]("locale"),
                s,
                length,
                pos,
                pos + 1,
                reason
            );
            if exc {
                PyCodec_StrictErrors(exc);
                object_decref(exc);
            }
        } elif res == -3 {
            PyErr_SetString(PyExc_ValueError, "unsupported error handler");
        } else {
            PyErr_NoMemory();
        }
        return NULL;
    }
    unicode = PyUnicode_FromWideChar(wstr, i64(wlen));
    PyMem_RawFree(ptr(wstr));
    return unicode;
}

impl unicode_ensure_utf8(unicode: ptr[PyObject]) -> i32 {
    if not uo_utf8(unicode) {
        return unicode_fill_utf8(unicode);
    }
    return i32(0);
}

impl unicode_as_utf8_and_size(unicode: ptr[PyObject]) -> tuple[ptr[u8], i64] {
    if not unicode_check(unicode) {
        PyErr_BadArgument();
        return (ptr[u8](), i64(-1));
    }
    if unicode_ensure_utf8(unicode) == -1 {
        return (ptr[u8](), i64(-1));
    }
    if uo_is_compact_ascii(unicode) {
        return (uo_utf8(unicode), uo_length(unicode));
    }
    return (uo_utf8(unicode), uo_utf8_length(unicode));
}

impl make_decode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    input: ptr[u8],
    length: i64,
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject] {
    if not exc {
        return PyUnicodeDecodeError_Create(
            ptr(encoding), ptr(input), length, startpos, endpos, reason
        );
    }
    if PyUnicodeDecodeError_SetStart(exc, startpos) != 0
        or PyUnicodeDecodeError_SetEnd(exc, endpos) != 0
        or PyUnicodeDecodeError_SetReason(exc, reason) != 0 {
        object_decref(exc);
        return NULL;
    }
    return exc;
}

impl decode_handler_result(restuple: ptr[PyObject]) -> tuple[bool, ptr[PyObject], i64] {
    if object_size(restuple) != 2 {
        PyErr_SetString(
            PyExc_TypeError, "decoding error handler must return (str, int) tuple"
        );
        return (False, NULL, i64(0));
    }
    repunicode = tuple_get_item(restuple, 0);
    if not unicode_check(repunicode) {
        PyErr_SetString(
            PyExc_TypeError, "decoding error handler must return (str, int) tuple"
        );
        return (False, NULL, i64(0));
    }
    newpos: i64 = -1;
    index = _PyNumber_Index(tuple_get_item(restuple, 1));
    if index {
        newpos = PyLong_AsSsize_t(index);
        object_decref(index);
    }
    if newpos == -1 and PyErr_Occurred() {
        return (False, NULL, i64(0));
    }
    return (True, repunicode, newpos);
}

impl decode_errorhandler_failed(
    restuple: ptr[PyObject],
    error_handler: ptr[PyObject],
    exc: ptr[PyObject],
    input: ptr[u8],
    inend: ptr[u8],
    endinpos: i64
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[u8], ptr[u8], i64, ptr[u8]] {
    object_xdecref(restuple);
    return (i32(-1), error_handler, exc, input, inend, endinpos, input + endinpos);
}

impl unicode_decode_call_errorhandler_writer(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    encoding: ptr[u8],
    reason: ptr[u8],
    input: ptr[u8],
    inend: ptr[u8],
    startinpos: i64,
    endinpos: i64,
    exc: ptr[PyObject],
    writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[u8], ptr[u8], i64, ptr[u8]] {
    handler = error_handler;
    if not handler {
        handler = PyCodec_LookupError(errors);
        if not handler {
            return decode_errorhandler_failed(
                NULL, handler, exc, input, inend, endinpos
            );
        }
    }
    exc_obj = make_decode_exception(
        exc, encoding, input, i64(int(inend) - int(input)), startinpos, endinpos, reason
    );
    if not exc_obj {
        return decode_errorhandler_failed(
            NULL, handler, exc_obj, input, inend, endinpos
        );
    }
    restuple = PyObject_CallOneArg(handler, exc_obj);
    if not restuple {
        return decode_errorhandler_failed(
            NULL, handler, exc_obj, input, inend, endinpos
        );
    }
    if not tuple_check(restuple) {
        PyErr_SetString(
            PyExc_TypeError, "decoding error handler must return (str, int) tuple"
        );
        return decode_errorhandler_failed(
            restuple, handler, exc_obj, input, inend, endinpos
        );
    }
    (parsed, repunicode, newpos) = decode_handler_result(restuple);
    if not parsed {
        return decode_errorhandler_failed(
            restuple, handler, exc_obj, input, inend, endinpos
        );
    }

    inputobj = PyUnicodeDecodeError_GetObject(exc_obj);
    if not inputobj {
        return decode_errorhandler_failed(
            restuple, handler, exc_obj, input, inend, endinpos
        );
    }
    remain = i64(int(inend) - int(input)) - endinpos;
    new_input = bytes_data(inputobj);
    insize = object_size(inputobj);
    new_inend = new_input + insize;

    object_decref(inputobj);
    if newpos < 0 {
        newpos = insize + newpos;
    }
    if newpos < 0 or newpos > insize {
        PyErr_Format(
            PyExc_IndexError, "position %zd from error handler out of bounds", newpos
        );
        return decode_errorhandler_failed(
            restuple, handler, exc_obj, input, inend, endinpos
        );
    }
    replen = uo_length(repunicode);
    need_to_grow = False;
    if replen > 1 {
        writer.view(1)[0].min_length = writer.view(1)[0].min_length + (replen - 1);
        need_to_grow = True;
    }
    new_inptr = new_input + newpos;
    rest = i64(int(new_inend) - int(new_inptr));
    if rest > remain {
        writer.view(1)[0].min_length = writer.view(1)[0].min_length + (rest - remain);
        need_to_grow = True;
    }
    if need_to_grow {
        writer.view(1)[0].overallocate = u8(1);
        if writer_prepare(
            writer,
            writer.view(1)[0].min_length - writer.view(1)[0].pos,
            uo_max_char_value(repunicode)
        )
            == -1 {
            return decode_errorhandler_failed(
                restuple, handler, exc_obj, input, inend, endinpos
            );
        }
    }
    if _PyUnicodeWriter_WriteStr(writer, repunicode) == -1 {
        return decode_errorhandler_failed(
            restuple, handler, exc_obj, input, inend, endinpos
        );
    }
    object_decref(restuple);
    return (i32(0), handler, exc_obj, new_input, new_inend, newpos, new_inptr);
}

impl is_base64(c: u32) -> bool {
    return (c >= u32(65) and c <= u32(90))
        or (c >= u32(97) and c <= u32(122))
        or (c >= u32(48) and c <= u32(57))
        or c == u32(43)
        or c == u32(47);
}

impl from_base64(c: u32) -> u64 {
    if c >= u32(65) and c <= u32(90) {
        return u64(c - u32(65));
    }
    if c >= u32(97) and c <= u32(122) {
        return u64(c - u32(97) + u32(26));
    }
    if c >= u32(48) and c <= u32(57) {
        return u64(c - u32(48) + u32(52));
    }
    if c == u32(43) {
        return u64(62);
    }
    return u64(63);
}

impl to_base64(n: u64) -> u8 {
    return (addressof(utf7_base64_chars) + i64(n & u64(0x3f))).view(1)[0];
}

impl decode_direct(c: u32) -> bool {
    return c <= u32(127) and c != u32(43);
}

impl encode_direct(c: u32, direct_o: bool, direct_ws: bool) -> bool {
    if c >= u32(128) or c == u32(0) {
        return False;
    }
    category = (addressof(utf7_category) + i64(c)).view(1)[0];
    return category == u8(0)
        or (direct_ws and category == u8(2))
        or (direct_o and category == u8(1));
}

impl utf7_decode_fail(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(error_handler);
    object_xdecref(exc);
    _PyUnicodeWriter_Dealloc(writer);
    writer_free(writer);
    return NULL;
}

impl unicode_decode_utf7(
    s_in: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
) -> ptr[PyObject] {
    if size == 0 {
        if consumed {
            consumed.view(1)[0] = 0;
        }
        return unicode_get_empty();
    }

    writer = writer_new();
    if not writer {
        return NULL;
    }
    writer.view(1)[0].min_length = size;
    starts = s_in;
    s = s_in;
    e = s_in + size;
    startinpos: i64 = 0;
    endinpos: i64 = 0;
    errmsg = ptr[u8]("");
    in_shift = False;
    shift_out_start: i64 = 0;
    base64bits = u32(0);
    base64buffer = u64(0);
    surrogate = u32(0);
    error_handler = NULL;
    exc = NULL;

    while True {
        while s < e {
            ch = u32(s.view(1)[0]);

            utf7_error = False;
            if in_shift {
                if is_base64(ch) {
                    base64buffer = wrapping_shl(base64buffer, u64(6)) | from_base64(ch);
                    base64bits += u32(6);
                    s = s + 1;
                    if base64bits >= u32(16) {
                        out_ch = u32.wrap(base64buffer >> u64(base64bits - u32(16)));
                        base64bits -= u32(16);

                        base64buffer = base64buffer
                            & ((u64(1) << u64(base64bits)) - u64(1));
                        if surrogate != u32(0) {
                            if uc_is_low_surrogate(out_ch) {
                                ch2 = uc_join_surrogates(surrogate, out_ch);
                                if writer_write_char_inline(writer, ch2) < i32(0) {
                                    return utf7_decode_fail(writer, error_handler, exc);
                                }
                                surrogate = u32(0);
                                continue;
                            }
                            if writer_write_char_inline(writer, surrogate) < i32(0) {
                                return utf7_decode_fail(writer, error_handler, exc);
                            }
                            surrogate = u32(0);
                        }
                        if uc_is_high_surrogate(out_ch) {
                            surrogate = out_ch;
                        } elif writer_write_char_inline(writer, out_ch) < i32(0) {
                            return utf7_decode_fail(writer, error_handler, exc);
                        }
                    }
                } else {
                    in_shift = False;
                    if base64bits > u32(0) {
                        if base64bits >= u32(6) {
                            s = s + 1;
                            errmsg = ptr[u8]("partial character in shift sequence");
                            utf7_error = True;
                        } elif base64buffer != u64(0) {
                            s = s + 1;
                            errmsg = ptr[u8]("non-zero padding bits in shift sequence");
                            utf7_error = True;
                        }
                    }
                    if not utf7_error {
                        if surrogate != u32(0) and decode_direct(ch) {
                            if writer_write_char_inline(writer, surrogate) < i32(0) {
                                return utf7_decode_fail(writer, error_handler, exc);
                            }
                        }
                        surrogate = u32(0);
                        if ch == u32(45) {
                            s = s + 1;
                        }
                    }
                }
            } elif ch == u32(43) {
                startinpos = int(s) - int(starts);
                s = s + 1;
                if s < e and s.view(1)[0] == u8(45) {
                    s = s + 1;
                    if writer_write_char_inline(writer, u32(43)) < i32(0) {
                        return utf7_decode_fail(writer, error_handler, exc);
                    }
                } elif s < e and not is_base64(u32(s.view(1)[0])) {
                    s = s + 1;
                    errmsg = ptr[u8]("ill-formed sequence");
                    utf7_error = True;
                } else {
                    in_shift = True;
                    surrogate = u32(0);
                    shift_out_start = writer.view(1)[0].pos;
                    base64bits = u32(0);
                    base64buffer = u64(0);
                }
            } elif decode_direct(ch) {
                s = s + 1;
                if writer_write_char_inline(writer, ch) < i32(0) {
                    return utf7_decode_fail(writer, error_handler, exc);
                }
            } else {
                startinpos = int(s) - int(starts);
                s = s + 1;
                errmsg = ptr[u8]("unexpected special character");
                utf7_error = True;
            }
            if utf7_error {
                endinpos = int(s) - int(starts);
                (
                    status,
                    handler_out,
                    exc_out,
                    starts_out,
                    e_out,
                    endinpos_out,
                    s_out
                ) = unicode_decode_call_errorhandler_writer(
                    errors,
                    error_handler,
                    ptr[u8]("utf7"),
                    errmsg,
                    starts,
                    e,
                    startinpos,
                    endinpos,
                    exc,
                    writer
                );
                error_handler = handler_out;
                exc = exc_out;
                starts = starts_out;
                e = e_out;
                endinpos = endinpos_out;
                s = s_out;
                if status != i32(0) {
                    return utf7_decode_fail(writer, error_handler, exc);
                }
            }
        }

        restart = False;
        if in_shift {
            if not consumed {
                in_shift = False;
                if surrogate != u32(0)
                    or base64bits >= u32(6)
                    or (base64bits > u32(0) and base64buffer != u64(0)) {
                    endinpos = size;
                    (
                        status,
                        handler_out,
                        exc_out,
                        starts_out,
                        e_out,
                        endinpos_out,
                        s_out
                    ) = unicode_decode_call_errorhandler_writer(
                        errors,
                        error_handler,
                        ptr[u8]("utf7"),
                        ptr[u8]("unterminated shift sequence"),
                        starts,
                        e,
                        startinpos,
                        endinpos,
                        exc,
                        writer
                    );
                    error_handler = handler_out;
                    exc = exc_out;
                    starts = starts_out;
                    e = e_out;
                    endinpos = endinpos_out;
                    s = s_out;
                    if status != i32(0) {
                        return utf7_decode_fail(writer, error_handler, exc);
                    }
                    if s < e {
                        restart = True;
                    }
                }
            }
        }
        if not restart {
            break;
        }
    }

    if consumed {
        if in_shift {
            consumed.view(1)[0] = startinpos;
            if writer.view(1)[0].pos != shift_out_start
                and writer.view(1)[0].maxchar > u32(127) {
                result = PyUnicode_FromKindAndData(
                    writer.view(1)[0].kind,
                    ptr[u8](writer.view(1)[0].data),
                    shift_out_start
                );
                object_xdecref(error_handler);
                object_xdecref(exc);
                _PyUnicodeWriter_Dealloc(writer);
                writer_free(writer);
                return result;
            }

            writer.view(1)[0].pos = shift_out_start;
        } else {
            consumed.view(1)[0] = int(s) - int(starts);
        }
    }
    object_xdecref(error_handler);
    object_xdecref(exc);
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl is_continuation_byte(ch: u32) -> bool {
    return ch >= u32(0x80) and ch < u32(0xC0);
}

impl ucs1lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u8], outpos: i64, max_char: u32
) -> tuple[u32, ptr[u8], i64] {
    s = s_in;
    p = dest + outpos;
    result = u32(0);
    while s < end {
        ch = u32(s.view(1)[0]);
        if ch < u32(0x80) {
            if (int(s) & 7) == 0 {
                fast_s = s;
                fast_p = p;
                while fast_s + SIZEOF_SIZE_T <= end {
                    value = ptr[u64](fast_s).view(1)[0];
                    if (value & ASCII_CHAR_MASK) != u64(0) {
                        break;
                    }
                    out = fast_p.view(8);
                    out[0] = u8.wrap(value);
                    out[1] = u8.wrap(value >> u64(8));
                    out[2] = u8.wrap(value >> u64(16));
                    out[3] = u8.wrap(value >> u64(24));
                    out[4] = u8.wrap(value >> u64(32));
                    out[5] = u8.wrap(value >> u64(40));
                    out[6] = u8.wrap(value >> u64(48));
                    out[7] = u8.wrap(value >> u64(56));
                    fast_s = fast_s + SIZEOF_SIZE_T;
                    fast_p = fast_p + SIZEOF_SIZE_T;
                }
                s = fast_s;
                p = fast_p;
                if s == end {
                    break;
                }
                ch = u32(s.view(1)[0]);
            }
            if ch < u32(0x80) {
                s = s + 1;
                p.view(1)[0] = u8.wrap(ch);
                p = p + 1;
                continue;
            }
        }
        if ch < u32(0xE0) {
            if ch < u32(0xC2) {
                result = u32(1);
                break;
            }
            if int(end) - int(s) < 2 {
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            ch = (ch << u32(6)) + ch2 - ((u32(0xC0) << u32(6)) + u32(0x80));
            s = s + 2;
            if ch > max_char {
                result = ch;
                break;
            }
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
            continue;
        }
        if ch < u32(0xF0) {
            if int(end) - int(s) < 3 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xE0)) if ch2 < u32(0xA0) else (ch == u32(0xED))) {
                    result = u32(2);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xE0) {
                if ch2 < u32(0xA0) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xED) and ch2 >= u32(0xA0) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            ch = (ch << u32(12)) + (ch2 << u32(6)) + ch3
                - ((u32(0xE0) << u32(12)) + (u32(0x80) << u32(6)) + u32(0x80));
            s = s + 3;

            result = ch;
            break;
        }
        if ch < u32(0xF5) {
            if int(end) - int(s) < 4 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xF0)) if ch2 < u32(0x90) else (ch == u32(0xF4))) {
                    result = u32(2);
                    break;
                }
                if int(end) - int(s) < 3 {
                    break;
                }
                ch3 = u32((s + 2).view(1)[0]);
                if not is_continuation_byte(ch3) {
                    result = u32(3);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            ch4 = u32((s + 3).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xF0) {
                if ch2 < u32(0x90) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xF4) and ch2 >= u32(0x90) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            if not is_continuation_byte(ch4) {
                result = u32(4);
                break;
            }
            ch = (ch << u32(18)) + (ch2 << u32(12)) + (ch3 << u32(6)) + ch4
                - (
                    (u32(0xF0) << u32(18))
                    + (u32(0x80) << u32(12))
                    + (u32(0x80) << u32(6))
                    + u32(0x80)
                );
            s = s + 4;

            result = ch;
            break;
        }
        result = u32(1);
        break;
    }
    return (result, s, int(p) - int(dest));
}

impl ucs2lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u16], outpos: i64
) -> tuple[u32, ptr[u8], i64] {
    s = s_in;
    p = dest + outpos;
    result = u32(0);
    while s < end {
        ch = u32(s.view(1)[0]);
        if ch < u32(0x80) {
            if (int(s) & 7) == 0 {
                fast_s = s;
                fast_p = p;
                while fast_s + SIZEOF_SIZE_T <= end {
                    value = ptr[u64](fast_s).view(1)[0];
                    if (value & ASCII_CHAR_MASK) != u64(0) {
                        break;
                    }
                    out = fast_p.view(8);
                    out[0] = u16.wrap(value & u64(0xFF));
                    out[1] = u16.wrap((value >> u64(8)) & u64(0xFF));
                    out[2] = u16.wrap((value >> u64(16)) & u64(0xFF));
                    out[3] = u16.wrap((value >> u64(24)) & u64(0xFF));
                    out[4] = u16.wrap((value >> u64(32)) & u64(0xFF));
                    out[5] = u16.wrap((value >> u64(40)) & u64(0xFF));
                    out[6] = u16.wrap((value >> u64(48)) & u64(0xFF));
                    out[7] = u16.wrap((value >> u64(56)) & u64(0xFF));
                    fast_s = fast_s + SIZEOF_SIZE_T;
                    fast_p = fast_p + SIZEOF_SIZE_T;
                }
                s = fast_s;
                p = fast_p;
                if s == end {
                    break;
                }
                ch = u32(s.view(1)[0]);
            }
            if ch < u32(0x80) {
                s = s + 1;
                p.view(1)[0] = u16.wrap(ch);
                p = p + 1;
                continue;
            }
        }
        if ch < u32(0xE0) {
            if ch < u32(0xC2) {
                result = u32(1);
                break;
            }
            if int(end) - int(s) < 2 {
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            ch = (ch << u32(6)) + ch2 - ((u32(0xC0) << u32(6)) + u32(0x80));
            s = s + 2;
            p.view(1)[0] = u16.wrap(ch);
            p = p + 1;
            continue;
        }
        if ch < u32(0xF0) {
            if int(end) - int(s) < 3 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xE0)) if ch2 < u32(0xA0) else (ch == u32(0xED))) {
                    result = u32(2);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xE0) {
                if ch2 < u32(0xA0) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xED) and ch2 >= u32(0xA0) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            ch = (ch << u32(12)) + (ch2 << u32(6)) + ch3
                - ((u32(0xE0) << u32(12)) + (u32(0x80) << u32(6)) + u32(0x80));
            s = s + 3;
            p.view(1)[0] = u16.wrap(ch);
            p = p + 1;
            continue;
        }
        if ch < u32(0xF5) {
            if int(end) - int(s) < 4 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xF0)) if ch2 < u32(0x90) else (ch == u32(0xF4))) {
                    result = u32(2);
                    break;
                }
                if int(end) - int(s) < 3 {
                    break;
                }
                ch3 = u32((s + 2).view(1)[0]);
                if not is_continuation_byte(ch3) {
                    result = u32(3);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            ch4 = u32((s + 3).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xF0) {
                if ch2 < u32(0x90) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xF4) and ch2 >= u32(0x90) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            if not is_continuation_byte(ch4) {
                result = u32(4);
                break;
            }
            ch = (ch << u32(18)) + (ch2 << u32(12)) + (ch3 << u32(6)) + ch4
                - (
                    (u32(0xF0) << u32(18))
                    + (u32(0x80) << u32(12))
                    + (u32(0x80) << u32(6))
                    + u32(0x80)
                );
            s = s + 4;

            result = ch;
            break;
        }
        result = u32(1);
        break;
    }
    return (result, s, (int(p) - int(dest)) // 2);
}

impl ucs4lib_utf8_decode(
    s_in: ptr[u8], end: ptr[u8], dest: ptr[u32], outpos: i64
) -> tuple[u32, ptr[u8], i64] {
    s = s_in;
    p = dest + outpos;
    result = u32(0);
    while s < end {
        ch = u32(s.view(1)[0]);
        if ch < u32(0x80) {
            if (int(s) & 7) == 0 {
                fast_s = s;
                fast_p = p;
                while fast_s + SIZEOF_SIZE_T <= end {
                    value = ptr[u64](fast_s).view(1)[0];
                    if (value & ASCII_CHAR_MASK) != u64(0) {
                        break;
                    }
                    out = fast_p.view(8);
                    out[0] = u32.wrap(value & u64(0xFF));
                    out[1] = u32.wrap((value >> u64(8)) & u64(0xFF));
                    out[2] = u32.wrap((value >> u64(16)) & u64(0xFF));
                    out[3] = u32.wrap((value >> u64(24)) & u64(0xFF));
                    out[4] = u32.wrap((value >> u64(32)) & u64(0xFF));
                    out[5] = u32.wrap((value >> u64(40)) & u64(0xFF));
                    out[6] = u32.wrap((value >> u64(48)) & u64(0xFF));
                    out[7] = u32.wrap((value >> u64(56)) & u64(0xFF));
                    fast_s = fast_s + SIZEOF_SIZE_T;
                    fast_p = fast_p + SIZEOF_SIZE_T;
                }
                s = fast_s;
                p = fast_p;
                if s == end {
                    break;
                }
                ch = u32(s.view(1)[0]);
            }
            if ch < u32(0x80) {
                s = s + 1;
                p.view(1)[0] = ch;
                p = p + 1;
                continue;
            }
        }
        if ch < u32(0xE0) {
            if ch < u32(0xC2) {
                result = u32(1);
                break;
            }
            if int(end) - int(s) < 2 {
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            ch = (ch << u32(6)) + ch2 - ((u32(0xC0) << u32(6)) + u32(0x80));
            s = s + 2;
            p.view(1)[0] = ch;
            p = p + 1;
            continue;
        }
        if ch < u32(0xF0) {
            if int(end) - int(s) < 3 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xE0)) if ch2 < u32(0xA0) else (ch == u32(0xED))) {
                    result = u32(2);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xE0) {
                if ch2 < u32(0xA0) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xED) and ch2 >= u32(0xA0) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            ch = (ch << u32(12)) + (ch2 << u32(6)) + ch3
                - ((u32(0xE0) << u32(12)) + (u32(0x80) << u32(6)) + u32(0x80));
            s = s + 3;
            p.view(1)[0] = ch;
            p = p + 1;
            continue;
        }
        if ch < u32(0xF5) {
            if int(end) - int(s) < 4 {
                if int(end) - int(s) < 2 {
                    break;
                }
                ch2 = u32((s + 1).view(1)[0]);
                if not is_continuation_byte(ch2)
                    or ((ch == u32(0xF0)) if ch2 < u32(0x90) else (ch == u32(0xF4))) {
                    result = u32(2);
                    break;
                }
                if int(end) - int(s) < 3 {
                    break;
                }
                ch3 = u32((s + 2).view(1)[0]);
                if not is_continuation_byte(ch3) {
                    result = u32(3);
                }
                break;
            }
            ch2 = u32((s + 1).view(1)[0]);
            ch3 = u32((s + 2).view(1)[0]);
            ch4 = u32((s + 3).view(1)[0]);
            if not is_continuation_byte(ch2) {
                result = u32(2);
                break;
            }
            if ch == u32(0xF0) {
                if ch2 < u32(0x90) {
                    result = u32(2);
                    break;
                }
            } elif ch == u32(0xF4) and ch2 >= u32(0x90) {
                result = u32(2);
                break;
            }
            if not is_continuation_byte(ch3) {
                result = u32(3);
                break;
            }
            if not is_continuation_byte(ch4) {
                result = u32(4);
                break;
            }
            ch = (ch << u32(18)) + (ch2 << u32(12)) + (ch3 << u32(6)) + ch4
                - (
                    (u32(0xF0) << u32(18))
                    + (u32(0x80) << u32(12))
                    + (u32(0x80) << u32(6))
                    + u32(0x80)
                );
            s = s + 4;
            p.view(1)[0] = ch;
            p = p + 1;
            continue;
        }
        result = u32(1);
        break;
    }
    return (result, s, (int(p) - int(dest)) // 4);
}

impl utf8_encode_surrogates(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    kind: i64,
    data: ptr[u8],
    size: i64,
    max_char_size: i64,
    p_in: ptr[u8],
    i_in: i64,
    error_handler_in: i32,
    errors: ptr[u8],
    error_handler_obj_in: ptr[PyObject],
    exc_in: ptr[PyObject]
) -> tuple[ptr[u8], i64, i32, ptr[PyObject], ptr[PyObject]] {
    p = p_in;
    i = i_in;
    error_handler = error_handler_in;
    error_handler_obj = error_handler_obj_in;
    exc = exc_in;
    if error_handler == _Py_ERROR_UNKNOWN {
        error_handler = _Py_GetErrorHandler(errors);
    }
    startpos = i - 1;
    endpos = startpos + 1;
    while endpos < size and uc_is_surrogate(ch_read(kind, data, endpos)) {
        endpos += 1;
    }

    writer.view(1)[0].overallocate = i32(1) if endpos < size else i32(0);
    if error_handler == _Py_ERROR_REPLACE or error_handler == _Py_ERROR_IGNORE {
        if error_handler == _Py_ERROR_REPLACE {
            memset(ptr(p), i32(63), u64(endpos - startpos));
            p = p + (endpos - startpos);
        }
        i += endpos - startpos - 1;
        return (p, i, error_handler, error_handler_obj, exc);
    }
    if error_handler == _Py_ERROR_SURROGATEPASS {
        k = startpos;
        while k < endpos {
            ch = ch_read(kind, data, k);
            out3 = p.view(3);
            out3[0] = u8.wrap(u32(0xe0) | (ch >> u32(12)));
            out3[1] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out3[2] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 3;
            k += 1;
        }
        i += endpos - startpos - 1;
        return (p, i, error_handler, error_handler_obj, exc);
    }
    if error_handler == _Py_ERROR_BACKSLASHREPLACE {
        writer.view(1)[0].min_size -= max_char_size * (endpos - startpos);
        p = backslashreplace(writer, p, unicode, startpos, endpos);
        if p {
            i += endpos - startpos - 1;
        }
        return (p, i, error_handler, error_handler_obj, exc);
    }
    if error_handler == _Py_ERROR_XMLCHARREFREPLACE {
        writer.view(1)[0].min_size -= max_char_size * (endpos - startpos);
        p = xmlcharrefreplace(writer, p, unicode, startpos, endpos);
        if p {
            i += endpos - startpos - 1;
        }
        return (p, i, error_handler, error_handler_obj, exc);
    }
    if error_handler == _Py_ERROR_SURROGATEESCAPE {
        k = startpos;
        while k < endpos {
            ch = ch_read(kind, data, k);
            if not (ch >= u32(0xDC80) and ch <= u32(0xDCFF)) {
                break;
            }
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
            k += 1;
        }
        if k >= endpos {
            i += endpos - startpos - 1;
            return (p, i, error_handler, error_handler_obj, exc);
        }

        startpos = k;
    }
    (rep, handler_out, exc_out, newpos) = unicode_encode_call_errorhandler(
        errors,
        error_handler_obj,
        ptr[u8]("utf-8"),
        ptr[u8]("surrogates not allowed"),
        unicode,
        exc,
        startpos,
        endpos
    );
    error_handler_obj = handler_out;
    exc = exc_out;
    if not rep {
        return (ptr[u8](), i, error_handler, error_handler_obj, exc);
    }
    if newpos < startpos {
        writer.view(1)[0].overallocate = i32(1);
        p = ptr[u8](
            _PyBytesWriter_Prepare(writer, ptr(p), max_char_size * (startpos - newpos))
        );
        if not p {
            object_decref(rep);
            return (p, i, error_handler, error_handler_obj, exc);
        }
    } else {
        writer.view(1)[0].min_size -= max_char_size * (newpos - startpos);
        writer.view(1)[0].overallocate = i32(1) if newpos < size else i32(0);
    }
    if bytes_check(rep) {
        p = ptr[u8](
            _PyBytesWriter_WriteBytes(
                writer, ptr(p), ptr(bytes_data(rep)), object_size(rep)
            )
        );
    } else {
        if not uo_is_ascii(rep) {
            exc = raise_encode_exception(
                exc,
                ptr[u8]("utf-8"),
                unicode,
                startpos,
                endpos,
                ptr[u8]("surrogates not allowed")
            );
            object_decref(rep);
            return (ptr[u8](), i, error_handler, error_handler_obj, exc);
        }
        p = ptr[u8](
            _PyBytesWriter_WriteBytes(writer, ptr(p), ptr(uo_data(rep)), uo_length(rep))
        );
    }
    object_decref(rep);
    if not p {
        return (p, i, error_handler, error_handler_obj, exc);
    }
    i = newpos;
    return (p, i, error_handler, error_handler_obj, exc);
}

impl ucs1lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8]
) -> ptr[u8] {
    max_char_size: i64 = 2;
    if size > PY_SSIZE_T_MAX // max_char_size {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    _PyBytesWriter_Init(writer);
    p = ptr[u8](_PyBytesWriter_Alloc(writer, size * max_char_size));
    if not p {
        return p;
    }
    for i in range(size) {
        ch = u32((data + i).view(1)[0]);
        if ch < u32(0x80) {
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        } else {
            out2 = p.view(2);
            out2[0] = u8.wrap(u32(0xc0) | (ch >> u32(6)));
            out2[1] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 2;
        }
    }
    return p;
}

impl ucs2lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u16],
    size: i64,
    error_handler_in: i32,
    errors: ptr[u8]
) -> ptr[u8] {
    error_handler = error_handler_in;
    error_handler_obj = NULL;
    exc = NULL;
    max_char_size: i64 = 3;
    if size > PY_SSIZE_T_MAX // max_char_size {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    _PyBytesWriter_Init(writer);
    p = ptr[u8](_PyBytesWriter_Alloc(writer, size * max_char_size));
    if not p {
        return p;
    }
    i: i64 = 0;
    while i < size {
        ch = u32((data + i).view(1)[0]);
        i += 1;
        if ch < u32(0x80) {
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        } elif ch < u32(0x0800) {
            out2 = p.view(2);
            out2[0] = u8.wrap(u32(0xc0) | (ch >> u32(6)));
            out2[1] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 2;
        } elif uc_is_surrogate(ch) {
            (p_next, i_next, handler_next, obj_next, exc_next) = utf8_encode_surrogates(
                writer,
                unicode,
                PyUnicode_2BYTE_KIND,
                ptr[u8](data),
                size,
                max_char_size,
                p,
                i,
                error_handler,
                errors,
                error_handler_obj,
                exc
            );
            error_handler = handler_next;
            error_handler_obj = obj_next;
            exc = exc_next;
            if not p_next {
                object_xdecref(error_handler_obj);
                object_xdecref(exc);
                return p_next;
            }
            p = p_next;
            i = i_next;
        } else {
            out3 = p.view(3);
            out3[0] = u8.wrap(u32(0xe0) | (ch >> u32(12)));
            out3[1] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out3[2] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 3;
        }
    }
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    return p;
}

impl ucs4lib_utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    data: ptr[u32],
    size: i64,
    error_handler_in: i32,
    errors: ptr[u8]
) -> ptr[u8] {
    error_handler = error_handler_in;
    error_handler_obj = NULL;
    exc = NULL;
    max_char_size: i64 = 4;
    if size > PY_SSIZE_T_MAX // max_char_size {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    _PyBytesWriter_Init(writer);
    p = ptr[u8](_PyBytesWriter_Alloc(writer, size * max_char_size));
    if not p {
        return p;
    }
    i: i64 = 0;
    while i < size {
        ch = (data + i).view(1)[0];
        i += 1;
        if ch < u32(0x80) {
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        } elif ch < u32(0x0800) {
            out2 = p.view(2);
            out2[0] = u8.wrap(u32(0xc0) | (ch >> u32(6)));
            out2[1] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 2;
        } elif uc_is_surrogate(ch) {
            (p_next, i_next, handler_next, obj_next, exc_next) = utf8_encode_surrogates(
                writer,
                unicode,
                PyUnicode_4BYTE_KIND,
                ptr[u8](data),
                size,
                max_char_size,
                p,
                i,
                error_handler,
                errors,
                error_handler_obj,
                exc
            );
            error_handler = handler_next;
            error_handler_obj = obj_next;
            exc = exc_next;
            if not p_next {
                object_xdecref(error_handler_obj);
                object_xdecref(exc);
                return p_next;
            }
            p = p_next;
            i = i_next;
        } elif ch < u32(0x10000) {
            out3 = p.view(3);
            out3[0] = u8.wrap(u32(0xe0) | (ch >> u32(12)));
            out3[1] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out3[2] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 3;
        } else {
            out4 = p.view(4);
            out4[0] = u8.wrap(u32(0xf0) | (ch >> u32(18)));
            out4[1] = u8.wrap(u32(0x80) | ((ch >> u32(12)) & u32(0x3f)));
            out4[2] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out4[3] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 4;
        }
    }
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    return p;
}

impl utf8_encoder(
    writer: ptr[BytesWriterFields],
    unicode: ptr[PyObject],
    kind: i64,
    data: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8]
) -> ptr[u8] {
    if kind == PyUnicode_1BYTE_KIND {
        return ucs1lib_utf8_encoder(writer, unicode, data, size, error_handler, errors);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return ucs2lib_utf8_encoder(
            writer, unicode, ptr[u16](data), size, error_handler, errors
        );
    }
    return ucs4lib_utf8_encoder(
        writer, unicode, ptr[u32](data), size, error_handler, errors
    );
}

impl ctz(v_in: u64) -> i64 {
    v = v_in;
    n: i64 = 0;
    if (v & u64(0xFFFFFFFF)) == u64(0) {
        n += 32;
        v = v >> u64(32);
    }
    if (v & u64(0xFFFF)) == u64(0) {
        n += 16;
        v = v >> u64(16);
    }
    if (v & u64(0xFF)) == u64(0) {
        n += 8;
        v = v >> u64(8);
    }
    if (v & u64(0xF)) == u64(0) {
        n += 4;
        v = v >> u64(4);
    }
    if (v & u64(0x3)) == u64(0) {
        n += 2;
        v = v >> u64(2);
    }
    if (v & u64(0x1)) == u64(0) {
        n += 1;
    }
    return n;
}

impl load_unaligned(p: ptr[u8], size: i64) -> u64 {
    u = u64(0);
    k = size if size < SIZEOF_SIZE_T else SIZEOF_SIZE_T;
    while k > 0 {
        k -= 1;
        u = (u << u64(8)) | u64((p + k).view(1)[0]);
    }
    return u;
}

impl find_first_nonascii(start: ptr[u8], end: ptr[u8]) -> i64 {
    p = start;
    if int(end) - int(start) >= SIZEOF_SIZE_T {
        u = load_unaligned(p, SIZEOF_SIZE_T) & ASCII_CHAR_MASK;
        if u != u64(0) {
            return (ctz(u) - 7) // 8;
        }

        p = p + (SIZEOF_SIZE_T - (int(p) & 7));
        e = end - SIZEOF_SIZE_T;
        while p <= e {
            u = ptr[u64](p).view(1)[0] & ASCII_CHAR_MASK;
            if u != u64(0) {
                return int(p) - int(start) + (ctz(u) - 7) // 8;
            }
            p = p + SIZEOF_SIZE_T;
        }
    }

    u = load_unaligned(p, int(end) - int(p)) & ASCII_CHAR_MASK;
    if u != u64(0) {
        return int(p) - int(start) + (ctz(u) - 7) // 8;
    }
    return int(end) - int(start);
}

impl scalar_utf8_start_char(ch: u32) -> i64 {
    return i64(((~ch >> u32(7)) | (ch >> u32(6))) & u32(1));
}

impl vector_utf8_start_chars(v: u64) -> u64 {
    return ((~v >> u64(7)) | (v >> u64(6))) & VECTOR_0101;
}

impl utf8_count_codepoints(s_in: ptr[u8], end: ptr[u8]) -> i64 {
    s = s_in;
    length: i64 = 0;
    if int(end) - int(s) >= SIZEOF_SIZE_T {
        while (int(s) & 7) != 0 {
            length += scalar_utf8_start_char(u32(s.view(1)[0]));
            s = s + 1;
        }
        while s + SIZEOF_SIZE_T <= end {
            e = end;
            if int(e) - int(s) > SIZEOF_SIZE_T * 255 {
                e = s + SIZEOF_SIZE_T * 255;
            }
            vstart = u64(0);
            while s + SIZEOF_SIZE_T <= e {
                v = ptr[u64](s).view(1)[0];
                vstart += vector_utf8_start_chars(v);
                s = s + SIZEOF_SIZE_T;
            }
            vstart = (vstart & VECTOR_00FF) + ((vstart >> u64(8)) & VECTOR_00FF);
            vstart += vstart >> u64(16);
            vstart += vstart >> u64(32);
            length += i64(vstart & u64(0x7ff));
        }
    }
    while s < end {
        length += scalar_utf8_start_char(u32(s.view(1)[0]));
        s = s + 1;
    }
    return length;
}

impl ascii_decode(start: ptr[u8], end: ptr[u8], dest: ptr[u8]) -> i64 {
    if (int(start) & 7) == 0 and (int(dest) & 7) == 0 {
        p = start;
        q = dest;
        while p + SIZEOF_SIZE_T <= end {
            value = ptr[u64](p).view(1)[0];
            if (value & ASCII_CHAR_MASK) != u64(0) {
                break;
            }
            ptr[u64](q).view(1)[0] = value;
            p = p + SIZEOF_SIZE_T;
            q = q + SIZEOF_SIZE_T;
        }
        while p < end {
            if (p.view(1)[0] & u8(0x80)) != u8(0) {
                break;
            }
            q.view(1)[0] = p.view(1)[0];
            q = q + 1;
            p = p + 1;
        }
        return int(p) - int(start);
    }
    pos = find_first_nonascii(start, end);
    memcpy(ptr(dest), ptr(start), u64(pos));
    return pos;
}

impl utf8_decode_into_writer(
    writer: ptr[UnicodeWriter], s: ptr[u8], end: ptr[u8]
) -> tuple[u32, ptr[u8]] {
    kind = i64(writer.view(1)[0].kind);
    data = writer.view(1)[0].data;
    pos = writer.view(1)[0].pos;
    if kind == PyUnicode_1BYTE_KIND {
        max_char = MAX_CHAR_UCS1;
        if uo_is_ascii(writer.view(1)[0].buffer) {
            max_char = MAX_CHAR_ASCII;
        }
        (ch1, s1, pos1) = ucs1lib_utf8_decode(s, end, data, pos, max_char);
        writer.view(1)[0].pos = pos1;
        return (ch1, s1);
    }
    if kind == PyUnicode_2BYTE_KIND {
        (ch2, s2, pos2) = ucs2lib_utf8_decode(s, end, ptr[u16](data), pos);
        writer.view(1)[0].pos = pos2;
        return (ch2, s2);
    }
    (ch4, s4, pos4) = ucs4lib_utf8_decode(s, end, ptr[u32](data), pos);
    writer.view(1)[0].pos = pos4;
    return (ch4, s4);
}

impl utf8_decode_fail(error_handler_obj: ptr[PyObject], exc: ptr[PyObject]) -> i32 {
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    return i32(-1);
}

impl unicode_decode_utf8_impl(
    writer: ptr[UnicodeWriter],
    starts_in: ptr[u8],
    s_in: ptr[u8],
    end_in: ptr[u8],
    error_handler_in: i32,
    errors: ptr[u8],
    consumed: ptr[i64]
) -> i32 {
    starts = starts_in;
    s = s_in;
    end = end_in;
    error_handler = error_handler_in;
    startinpos: i64 = 0;
    endinpos: i64 = 0;
    errmsg = ptr[u8]("");
    error_handler_obj = NULL;
    exc = NULL;
    while s < end {
        (ch, s_next) = utf8_decode_into_writer(writer, s, end);
        s = s_next;
        if ch == u32(0) {
            if s == end {
                break;
            }
            if consumed {
                break;
            }
            errmsg = ptr[u8]("unexpected end of data");
            startinpos = int(s) - int(starts);
            endinpos = int(end) - int(starts);
        } elif ch == u32(1) {
            errmsg = ptr[u8]("invalid start byte");
            startinpos = int(s) - int(starts);
            endinpos = startinpos + 1;
        } elif ch <= u32(4) {
            if ch == u32(2) and int(end) - int(s) == 2 {
                if consumed {
                    lead = s.view(1)[0];
                    trail = (s + 1).view(1)[0];
                    if lead == u8(0xED) and trail >= u8(0xA0) and trail <= u8(0xBF) {
                        break;
                    }
                }
            }
            errmsg = ptr[u8]("invalid continuation byte");
            startinpos = int(s) - int(starts);
            endinpos = startinpos + i64(ch) - 1;
        } else {
            if writer_write_char_inline(writer, ch) < i32(0) {
                return utf8_decode_fail(error_handler_obj, exc);
            }
            continue;
        }
        if error_handler == _Py_ERROR_UNKNOWN {
            error_handler = _Py_GetErrorHandler(errors);
        }
        if error_handler == _Py_ERROR_IGNORE {
            s = s + (endinpos - startinpos);
        } elif error_handler == _Py_ERROR_REPLACE {
            if writer_write_char_inline(writer, u32(0xfffd)) < i32(0) {
                return utf8_decode_fail(error_handler_obj, exc);
            }
            s = s + (endinpos - startinpos);
        } elif error_handler == _Py_ERROR_SURROGATEESCAPE {
            if writer_prepare_kind(writer, PyUnicode_2BYTE_KIND) < i32(0) {
                return utf8_decode_fail(error_handler_obj, exc);
            }
            i = startinpos;
            while i < endinpos {
                byte = u32((starts + i).view(1)[0]);
                ch_write(
                    i64(writer.view(1)[0].kind),
                    writer.view(1)[0].data,
                    writer.view(1)[0].pos,
                    byte + u32(0xdc00)
                );
                writer.view(1)[0].pos += 1;
                i += 1;
            }
            s = s + (endinpos - startinpos);
        } else {
            (status, handler_out, exc_out, starts_out, end_out, endinpos_out, s_out) = unicode_decode_call_errorhandler_writer(
                errors,
                error_handler_obj,
                ptr[u8]("utf-8"),
                errmsg,
                starts,
                end,
                startinpos,
                endinpos,
                exc,
                writer
            );
            error_handler_obj = handler_out;
            exc = exc_out;
            starts = starts_out;
            end = end_out;
            endinpos = endinpos_out;
            s = s_out;
            if status != i32(0) {
                return utf8_decode_fail(error_handler_obj, exc);
            }
            if writer_prepare(writer, int(end) - int(s), MAX_CHAR_ASCII) < i32(0) {
                return i32(-1);
            }
        }
    }

    if consumed {
        consumed.view(1)[0] = int(s) - int(starts);
    }
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    return i32(0);
}

impl unicode_decode_utf8(
    s_in: ptr[u8], size: i64, error_handler: i32, errors: ptr[u8], consumed: ptr[i64]
) -> ptr[PyObject] {
    if size == 0 {
        if consumed {
            consumed.view(1)[0] = 0;
        }
        return unicode_get_empty();
    }

    if size == 1 and s_in.view(1)[0] < u8(128) {
        if consumed {
            consumed.view(1)[0] = 1;
        }
        return get_latin1_char(s_in.view(1)[0]);
    }

    if PY_SSIZE_T_MAX - PyCompactUnicodeObject_SIZE < size {
        PyErr_NoMemory();
        return NULL;
    }
    starts = s_in;
    end = s_in + size;
    s = s_in;
    pos = find_first_nonascii(starts, end);
    if pos == size {
        ascii = PyUnicode_New(size, MAX_CHAR_ASCII);
        if not ascii {
            return NULL;
        }
        memcpy(ptr(uo_data(ascii)), ptr(s), u64(size));
        if consumed {
            consumed.view(1)[0] = size;
        }
        return ascii;
    }
    maxchr = MAX_CHAR_ASCII;
    maxsize = size;
    ch = (s + pos).view(1)[0];

    if error_handler == _Py_ERROR_STRICT and ch >= u8(0xc2) {
        if not consumed {
            maxsize = utf8_count_codepoints(s, end);
            if ch < u8(0xc4) {
                maxchr = MAX_CHAR_UCS1;
            } elif ch < u8(0xf0) {
                maxchr = MAX_CHAR_UCS2;
            } else {
                maxchr = MAX_CHAR_UCS4;
            }
        }
    }
    u = PyUnicode_New(maxsize, maxchr);
    if not u {
        return NULL;
    }

    writer = writer_new();
    if not writer {
        object_decref(u);
        return NULL;
    }
    writer_init_with_buffer(writer, u);
    if maxchr <= u32(255) {
        memcpy(ptr(uo_data(u)), ptr(s), u64(pos));
        s = s + pos;
        writer.view(1)[0].pos = pos;
    }
    if unicode_decode_utf8_impl(writer, starts, s, end, error_handler, errors, consumed)
        < i32(0) {
        _PyUnicodeWriter_Dealloc(writer);
        writer_free(writer);
        return NULL;
    }
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl unicode_decode_utf8_writer(
    writer: ptr[UnicodeWriter],
    s_in: ptr[u8],
    size: i64,
    error_handler: i32,
    errors: ptr[u8],
    consumed: ptr[i64]
) -> i32 {
    if size == 0 {
        if consumed {
            consumed.view(1)[0] = 0;
        }
        return i32(0);
    }

    if writer_prepare(writer, size, MAX_CHAR_ASCII) < i32(0) {
        return i32(-1);
    }
    starts = s_in;
    end = s_in + size;
    s = s_in;
    decoded: i64 = 0;
    dest = writer.view(1)[0].data + writer.view(1)[0].pos * i64(writer.view(1)[0].kind);
    if i64(writer.view(1)[0].kind) == PyUnicode_1BYTE_KIND {
        decoded = ascii_decode(s, end, dest);
        writer.view(1)[0].pos += decoded;
        if decoded == size {
            if consumed {
                consumed.view(1)[0] = size;
            }
            return i32(0);
        }
        s = s + decoded;
    }
    return unicode_decode_utf8_impl(
        writer, starts, s, end, error_handler, errors, consumed
    );
}

impl decode_utf8_ex(
    s_in: ptr[u8], size: i64, errors: i32
) -> tuple[i32, ptr[i32], u64, ptr[u8]] {
    orig_s = s_in;
    s = s_in;
    surrogateescape = False;
    surrogatepass = False;
    if errors == _Py_ERROR_SURROGATEESCAPE {
        surrogateescape = True;
    } elif errors == _Py_ERROR_SURROGATEPASS {
        surrogatepass = True;
    } elif errors != _Py_ERROR_STRICT {
        return (i32(-3), ptr[i32](), u64(0), ptr[u8]());
    }

    if PY_SSIZE_T_MAX // 4 - 1 < size {
        return (i32(-1), ptr[i32](), u64(0), ptr[u8]());
    }
    unicode = ptr[i32](PyMem_RawMalloc(u64((size + 1) * 4)));
    if not unicode {
        return (i32(-1), ptr[i32](), u64(0), ptr[u8]());
    }

    e = s + size;
    outpos: i64 = 0;
    while s < e {
        (ch, s_next, outpos_next) = ucs4lib_utf8_decode(
            s, e, ptr[u32](unicode), outpos
        );
        s = s_next;
        outpos = outpos_next;
        if ch == u32(0) and s == e {
            break;
        }
        if surrogateescape {
            (unicode + outpos).view(1)[0] = i32(0xDC00) + i32(s.view(1)[0]);
            outpos += 1;
            s = s + 1;
            continue;
        }

        if surrogatepass
            and int(e) - int(s) >= 3
            and (s.view(1)[0] & u8(0xf0)) == u8(0xe0)
            and ((s + 1).view(1)[0] & u8(0xc0)) == u8(0x80)
            and ((s + 2).view(1)[0] & u8(0xc0)) == u8(0x80) {
            code = ((i32(s.view(1)[0]) & i32(0x0f)) << i32(12))
                + ((i32((s + 1).view(1)[0]) & i32(0x3f)) << i32(6))
                + (i32((s + 2).view(1)[0]) & i32(0x3f));
            s = s + 3;
            (unicode + outpos).view(1)[0] = code;
            outpos += 1;
            continue;
        }
        PyMem_RawFree(ptr(unicode));
        reason = ptr[u8]("invalid continuation byte");
        if ch == u32(0) {
            reason = ptr[u8]("unexpected end of data");
        } elif ch == u32(1) {
            reason = ptr[u8]("invalid start byte");
        }
        return (i32(-2), ptr[i32](), u64(int(s) - int(orig_s)), reason);
    }
    (unicode + outpos).view(1)[0] = i32(0);
    return (i32(0), unicode, u64(outpos), ptr[u8]());
}

impl encode_utf8_ex(
    text: ptr[i32], raw_malloc: i32, errors: i32
) -> tuple[i32, ptr[u8], bool, u64] {
    max_char_size: i64 = 4;
    length = i64(wcslen(text));
    surrogateescape = False;
    surrogatepass = False;
    if errors == _Py_ERROR_SURROGATEESCAPE {
        surrogateescape = True;
    } elif errors == _Py_ERROR_SURROGATEPASS {
        surrogatepass = True;
    } elif errors != _Py_ERROR_STRICT {
        return (i32(-3), ptr[u8](), False, u64(0));
    }
    if length > PY_SSIZE_T_MAX // max_char_size - 1 {
        return (i32(-1), ptr[u8](), False, u64(0));
    }
    nbytes = u64((length + 1) * max_char_size);
    buf = ptr[u8]();
    if raw_malloc != i32(0) {
        buf = ptr[u8](PyMem_RawMalloc(nbytes));
    } else {
        buf = ptr[u8](PyMem_Malloc(nbytes));
    }
    if not buf {
        return (i32(-1), ptr[u8](), False, u64(0));
    }
    p = buf;
    i: i64 = 0;
    while i < length {
        ch_pos = i;
        ch = u32.wrap(i64((text + i).view(1)[0]));
        i += 1;
        if ch < u32(0x80) {
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        } elif ch < u32(0x0800) {
            out2 = p.view(2);
            out2[0] = u8.wrap(u32(0xc0) | (ch >> u32(6)));
            out2[1] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 2;
        } elif uc_is_surrogate(ch) and not surrogatepass {
            if not surrogateescape or not (ch >= u32(0xDC80) and ch <= u32(0xDCFF)) {
                if raw_malloc != i32(0) {
                    PyMem_RawFree(ptr(buf));
                } else {
                    PyMem_Free(ptr(buf));
                }
                return (i32(-2), ptr[u8](), True, u64(ch_pos));
            }
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        } elif ch < u32(0x10000) {
            out3 = p.view(3);
            out3[0] = u8.wrap(u32(0xe0) | (ch >> u32(12)));
            out3[1] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out3[2] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 3;
        } else {
            out4 = p.view(4);
            out4[0] = u8.wrap(u32(0xf0) | (ch >> u32(18)));
            out4[1] = u8.wrap(u32(0x80) | ((ch >> u32(12)) & u32(0x3f)));
            out4[2] = u8.wrap(u32(0x80) | ((ch >> u32(6)) & u32(0x3f)));
            out4[3] = u8.wrap(u32(0x80) | (ch & u32(0x3f)));
            p = p + 4;
        }
    }
    p.view(1)[0] = u8(0);
    p = p + 1;
    final_size = u64(int(p) - int(buf));
    shrunk = ptr[u8]();
    if raw_malloc != i32(0) {
        shrunk = ptr[u8](PyMem_RawRealloc(ptr(buf), final_size));
    } else {
        shrunk = ptr[u8](PyMem_Realloc(ptr(buf), final_size));
    }
    if not shrunk {
        if raw_malloc != i32(0) {
            PyMem_RawFree(ptr(buf));
        } else {
            PyMem_Free(ptr(buf));
        }
        return (i32(-1), ptr[u8](), True, u64(0xFFFFFFFFFFFFFFFF));
    }
    return (i32(0), shrunk, False, u64(0));
}

impl unicode_encode_utf8(
    unicode: ptr[PyObject], error_handler: i32, errors: ptr[u8]
) -> ptr[PyObject] {
    if not unicode_check(unicode) {
        PyErr_BadArgument();
        return NULL;
    }
    utf8 = uo_utf8(unicode);
    if utf8 {
        return PyBytes_FromStringAndSize(utf8, uo_utf8_length(unicode));
    }
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    size = uo_length(unicode);
    writer = bytes_writer_new();
    if not writer {
        return NULL;
    }

    end = utf8_encoder(writer, unicode, kind, data, size, error_handler, errors);
    if not end {
        _PyBytesWriter_Dealloc(writer);
        bytes_writer_free(writer);
        return NULL;
    }
    result = _PyBytesWriter_Finish(writer, ptr(end));
    bytes_writer_free(writer);
    return result;
}

impl unicode_fill_utf8(unicode: ptr[PyObject]) -> i32 {
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    size = uo_length(unicode);
    writer = bytes_writer_new();
    if not writer {
        return i32(-1);
    }
    end = utf8_encoder(writer, unicode, kind, data, size, _Py_ERROR_STRICT, ptr[u8]());
    if not end {
        _PyBytesWriter_Dealloc(writer);
        bytes_writer_free(writer);
        return i32(-1);
    }
    start = ptr[u8]();
    if writer.view(1)[0].use_small_buffer != i32(0) {
        start = ptr[u8](writer) + _PyBytesWriter_SMALL_BUFFER;
    } else {
        start = bytes_data(writer.view(1)[0].buffer);
    }
    length = int(end) - int(start);
    cache = ptr[u8](PyMem_Malloc(u64(length + 1)));
    if not cache {
        _PyBytesWriter_Dealloc(writer);
        bytes_writer_free(writer);
        PyErr_NoMemory();
        return i32(-1);
    }
    memcpy(ptr(cache), ptr(start), u64(length));
    (cache + length).view(1)[0] = u8(0);
    uo_set_utf8_length(unicode, length);
    uo_set_utf8(unicode, cache);
    _PyBytesWriter_Dealloc(writer);
    bytes_writer_free(writer);
    return i32(0);
}

impl codec_span(lo: ptr[u8], hi: ptr[u8]) -> i64 {
    return int(hi) - int(lo);
}

impl codec_writer_fail(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    _PyUnicodeWriter_Dealloc(writer);
    writer_free(writer);
    object_xdecref(error_handler);
    object_xdecref(exc);
    return NULL;
}

impl codec_writer_finish(
    writer: ptr[UnicodeWriter], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(error_handler);
    object_xdecref(exc);
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl swab_units(value: u64) -> u64 {
    stripped = u64(0x00FF00FF00FF00FF);
    return ((value >> u64(8)) & stripped) | ((value & stripped) << u64(8));
}

impl swab2(ch: u32) -> u16 {
    return u16.wrap((ch << u32(8)) | (ch >> u32(8)));
}

impl bswap32(word: u32) -> u32 {
    return ((word & u32(0xFF)) << u32(24))
        | ((word & u32(0xFF00)) << u32(8))
        | ((word >> u32(8)) & u32(0xFF00))
        | (word >> u32(24));
}

impl any_surrogate4(a: u32, b: u32, c: u32, d: u32) -> bool {
    return (
        (a ^ u32(0xd800))
        & (b ^ u32(0xd800))
        & (c ^ u32(0xd800))
        & (d ^ u32(0xd800))
        & u32(0xf800)
    )
        == u32(0);
}

impl ucs1lib_utf16_decode(
    q_in: ptr[u8],
    e_in: ptr[u8],
    dest: ptr[u8],
    outpos: i64,
    native_ordering: bool,
    max_char: u32
) -> tuple[u32, ptr[u8], i64] {
    q = q_in;
    p = dest + outpos;

    ihi: i64 = 1 if native_ordering else 0;
    ilo: i64 = 0 if native_ordering else 1;

    fast_char_mask = u64(0x0001000100010001) * u64(u32(0xFFFF) & ~max_char);
    swabbed_mask = swab_units(fast_char_mask);
    e = e_in - 1;
    ch = u32(0);
    while q < e {
        if (int(q) & 7) == 0 {
            qq = q;
            while qq + 8 <= e {
                block = ptr[u64](qq).view(1)[0];
                if native_ordering {
                    if (block & fast_char_mask) != u64(0) {
                        break;
                    }
                } else {
                    if (block & swabbed_mask) != u64(0) {
                        break;
                    }
                    block = block >> u64(8);
                }
                units = p.view(4);
                units[0] = u8.wrap(block & u64(0xFFFF));
                units[1] = u8.wrap((block >> u64(16)) & u64(0xFFFF));
                units[2] = u8.wrap((block >> u64(32)) & u64(0xFFFF));
                units[3] = u8.wrap(block >> u64(48));
                qq = qq + 8;
                p = p + 4;
            }
            q = qq;
            if q >= e {
                break;
            }
        }
        ch = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_surrogate(ch) {
            if ch > max_char {
                return (ch, q, codec_span(dest, p));
            }
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
            continue;
        }

        if not uc_is_high_surrogate(ch) {
            return (u32(2), q, codec_span(dest, p));
        }
        if q >= e {
            return (u32(1), q, codec_span(dest, p));
        }
        ch2 = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_low_surrogate(ch2) {
            return (u32(3), q, codec_span(dest, p));
        }

        return (uc_join_surrogates(ch, ch2), q, codec_span(dest, p));
    }
    return (u32(0), q, codec_span(dest, p));
}

impl ucs2lib_utf16_decode(
    q_in: ptr[u8], e_in: ptr[u8], dest: ptr[u16], outpos: i64, native_ordering: bool
) -> tuple[u32, ptr[u8], i64] {
    q = q_in;
    p = dest + outpos;
    ihi: i64 = 1 if native_ordering else 0;
    ilo: i64 = 0 if native_ordering else 1;

    fast_char_mask = u64(0x8000800080008000);
    swabbed_mask = swab_units(fast_char_mask);
    e = e_in - 1;
    ch = u32(0);
    while q < e {
        if (int(q) & 7) == 0 {
            qq = q;
            while qq + 8 <= e {
                block = ptr[u64](qq).view(1)[0];
                if native_ordering {
                    if (block & fast_char_mask) != u64(0) {
                        break;
                    }
                } else {
                    if (block & swabbed_mask) != u64(0) {
                        break;
                    }
                    block = swab_units(block);
                }
                units = p.view(4);
                units[0] = u16.wrap(block & u64(0xFFFF));
                units[1] = u16.wrap((block >> u64(16)) & u64(0xFFFF));
                units[2] = u16.wrap((block >> u64(32)) & u64(0xFFFF));
                units[3] = u16.wrap(block >> u64(48));
                qq = qq + 8;
                p = p + 4;
            }
            q = qq;
            if q >= e {
                break;
            }
        }
        ch = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_surrogate(ch) {
            p.view(1)[0] = u16.wrap(ch);
            p = p + 1;
            continue;
        }
        if not uc_is_high_surrogate(ch) {
            return (u32(2), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 2);
        }
        if q >= e {
            return (u32(1), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 2);
        }
        ch2 = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_low_surrogate(ch2) {
            return (u32(3), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 2);
        }

        return (
            uc_join_surrogates(ch, ch2),
            q,
            codec_span(ptr[u8](dest), ptr[u8](p)) // 2
        );
    }
    return (u32(0), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 2);
}

impl ucs4lib_utf16_decode(
    q_in: ptr[u8], e_in: ptr[u8], dest: ptr[u32], outpos: i64, native_ordering: bool
) -> tuple[u32, ptr[u8], i64] {
    q = q_in;
    p = dest + outpos;
    ihi: i64 = 1 if native_ordering else 0;
    ilo: i64 = 0 if native_ordering else 1;
    fast_char_mask = u64(0x8000800080008000);
    swabbed_mask = swab_units(fast_char_mask);
    e = e_in - 1;
    ch = u32(0);
    while q < e {
        if (int(q) & 7) == 0 {
            qq = q;
            while qq + 8 <= e {
                block = ptr[u64](qq).view(1)[0];
                if native_ordering {
                    if (block & fast_char_mask) != u64(0) {
                        break;
                    }
                } else {
                    if (block & swabbed_mask) != u64(0) {
                        break;
                    }
                    block = swab_units(block);
                }
                units = p.view(4);
                units[0] = u32.wrap(block & u64(0xFFFF));
                units[1] = u32.wrap((block >> u64(16)) & u64(0xFFFF));
                units[2] = u32.wrap((block >> u64(32)) & u64(0xFFFF));
                units[3] = u32.wrap(block >> u64(48));
                qq = qq + 8;
                p = p + 4;
            }
            q = qq;
            if q >= e {
                break;
            }
        }
        ch = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_surrogate(ch) {
            p.view(1)[0] = ch;
            p = p + 1;
            continue;
        }
        if not uc_is_high_surrogate(ch) {
            return (u32(2), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 4);
        }
        if q >= e {
            return (u32(1), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 4);
        }
        ch2 = (u32((q + ihi).view(1)[0]) << u32(8)) | u32((q + ilo).view(1)[0]);
        q = q + 2;
        if not uc_is_low_surrogate(ch2) {
            return (u32(3), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 4);
        }
        p.view(1)[0] = uc_join_surrogates(ch, ch2);
        p = p + 1;
    }
    return (u32(0), q, codec_span(ptr[u8](dest), ptr[u8](p)) // 4);
}

impl ucs1lib_utf16_encode(
    inp_in: ptr[u8], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    unrolled_end = inp_in + (length // 4) * 4;
    if native_ordering {
        while inp < unrolled_end {
            src = inp.view(4);
            dst = out.view(4);
            dst[0] = u16(src[0]);
            dst[1] = u16(src[1]);
            dst[2] = u16(src[2]);
            dst[3] = u16(src[3]);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            out.view(1)[0] = u16(inp.view(1)[0]);
            inp = inp + 1;
            out = out + 1;
        }
    } else {
        while inp < unrolled_end {
            src = inp.view(4);
            dst = out.view(4);
            dst[0] = u16(src[0]) << u16(8);
            dst[1] = u16(src[1]) << u16(8);
            dst[2] = u16(src[2]) << u16(8);
            dst[3] = u16(src[3]) << u16(8);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            out.view(1)[0] = u16(inp.view(1)[0]) << u16(8);
            inp = inp + 1;
            out = out + 1;
        }
    }
    return (length, out);
}

impl ucs2lib_utf16_encode(
    inp_in: ptr[u16], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    unrolled_end = inp_in + (length // 4) * 4;
    if native_ordering {
        while inp < unrolled_end {
            src = inp.view(4);

            if any_surrogate4(u32(src[0]), u32(src[1]), u32(src[2]), u32(src[3])) {
                break;
            }
            dst = out.view(4);
            dst[0] = src[0];
            dst[1] = src[1];
            dst[2] = src[2];
            dst[3] = src[3];
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            ch = u32(inp.view(1)[0]);
            inp = inp + 1;
            if ch >= u32(0xd800) and ch < u32(0xe000) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 2 + 1),
                    out
                );
            }
            out.view(1)[0] = u16.wrap(ch);
            out = out + 1;
        }
    } else {
        while inp < unrolled_end {
            src = inp.view(4);
            if any_surrogate4(u32(src[0]), u32(src[1]), u32(src[2]), u32(src[3])) {
                break;
            }
            dst = out.view(4);
            dst[0] = swab2(u32(src[0]));
            dst[1] = swab2(u32(src[1]));
            dst[2] = swab2(u32(src[2]));
            dst[3] = swab2(u32(src[3]));
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            ch = u32(inp.view(1)[0]);
            inp = inp + 1;
            if ch >= u32(0xd800) and ch < u32(0xe000) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 2 + 1),
                    out
                );
            }
            out.view(1)[0] = swab2(ch);
            out = out + 1;
        }
    }
    return (length, out);
}

impl ucs4lib_utf16_encode(
    inp_in: ptr[u32], length: i64, out_in: ptr[u16], native_ordering: bool
) -> tuple[i64, ptr[u16]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    if native_ordering {
        while inp < end {
            ch = inp.view(1)[0];
            inp = inp + 1;
            if ch < u32(0xd800) {
                out.view(1)[0] = u16.wrap(ch);
                out = out + 1;
            } elif ch < u32(0xe000) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 4 + 1),
                    out
                );
            } elif ch >= u32(0x10000) {
                pair = out.view(2);
                pair[0] = u16.wrap(uc_high_surrogate(ch));
                pair[1] = u16.wrap(uc_low_surrogate(ch));
                out = out + 2;
            } else {
                out.view(1)[0] = u16.wrap(ch);
                out = out + 1;
            }
        }
    } else {
        while inp < end {
            ch = inp.view(1)[0];
            inp = inp + 1;
            if ch < u32(0xd800) {
                out.view(1)[0] = swab2(ch);
                out = out + 1;
            } elif ch < u32(0xe000) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 4 + 1),
                    out
                );
            } elif ch >= u32(0x10000) {
                pair = out.view(2);
                pair[0] = swab2(uc_high_surrogate(ch));
                pair[1] = swab2(uc_low_surrogate(ch));
                out = out + 2;
            } else {
                out.view(1)[0] = swab2(ch);
                out = out + 1;
            }
        }
    }
    return (length, out);
}

impl ucs1lib_utf32_encode(
    inp_in: ptr[u8], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    unrolled_end = inp_in + (length // 4) * 4;
    if native_ordering {
        while inp < unrolled_end {
            src = inp.view(4);
            dst = out.view(4);
            dst[0] = u32(src[0]);
            dst[1] = u32(src[1]);
            dst[2] = u32(src[2]);
            dst[3] = u32(src[3]);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            out.view(1)[0] = u32(inp.view(1)[0]);
            inp = inp + 1;
            out = out + 1;
        }
    } else {
        while inp < unrolled_end {
            src = inp.view(4);
            dst = out.view(4);
            dst[0] = u32(src[0]) << u32(24);
            dst[1] = u32(src[1]) << u32(24);
            dst[2] = u32(src[2]) << u32(24);
            dst[3] = u32(src[3]) << u32(24);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            out.view(1)[0] = u32(inp.view(1)[0]) << u32(24);
            inp = inp + 1;
            out = out + 1;
        }
    }
    return (length, out);
}

impl ucs2_swab4(ch: u16) -> u32 {
    word = u32(ch);
    return ((word & u32(0x00FF)) << u32(24)) | ((word & u32(0xFF00)) << u32(8));
}

impl ucs2lib_utf32_encode(
    inp_in: ptr[u16], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    unrolled_end = inp_in + (length // 4) * 4;
    if native_ordering {
        while inp < unrolled_end {
            src = inp.view(4);

            if any_surrogate4(u32(src[0]), u32(src[1]), u32(src[2]), u32(src[3])) {
                break;
            }
            dst = out.view(4);
            dst[0] = u32(src[0]);
            dst[1] = u32(src[1]);
            dst[2] = u32(src[2]);
            dst[3] = u32(src[3]);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            ch = u32(inp.view(1)[0]);
            inp = inp + 1;
            if uc_is_surrogate(ch) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 2 + 1),
                    out
                );
            }
            out.view(1)[0] = ch;
            out = out + 1;
        }
    } else {
        while inp < unrolled_end {
            src = inp.view(4);
            if any_surrogate4(u32(src[0]), u32(src[1]), u32(src[2]), u32(src[3])) {
                break;
            }
            dst = out.view(4);
            dst[0] = ucs2_swab4(src[0]);
            dst[1] = ucs2_swab4(src[1]);
            dst[2] = ucs2_swab4(src[2]);
            dst[3] = ucs2_swab4(src[3]);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            unit = inp.view(1)[0];
            inp = inp + 1;
            if uc_is_surrogate(u32(unit)) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 2 + 1),
                    out
                );
            }
            out.view(1)[0] = ucs2_swab4(unit);
            out = out + 1;
        }
    }
    return (length, out);
}

impl ucs4lib_utf32_encode(
    inp_in: ptr[u32], length: i64, out_in: ptr[u32], native_ordering: bool
) -> tuple[i64, ptr[u32]] {
    inp = inp_in;
    out = out_in;
    end = inp_in + length;
    unrolled_end = inp_in + (length // 4) * 4;
    if native_ordering {
        while inp < unrolled_end {
            src = inp.view(4);

            if any_surrogate4(src[0], src[1], src[2], src[3]) {
                break;
            }
            dst = out.view(4);
            dst[0] = src[0];
            dst[1] = src[1];
            dst[2] = src[2];
            dst[3] = src[3];
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            ch = inp.view(1)[0];
            inp = inp + 1;
            if uc_is_surrogate(ch) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 4 + 1),
                    out
                );
            }
            out.view(1)[0] = ch;
            out = out + 1;
        }
    } else {
        while inp < unrolled_end {
            src = inp.view(4);
            if any_surrogate4(src[0], src[1], src[2], src[3]) {
                break;
            }
            dst = out.view(4);
            dst[0] = bswap32(src[0]);
            dst[1] = bswap32(src[1]);
            dst[2] = bswap32(src[2]);
            dst[3] = bswap32(src[3]);
            inp = inp + 4;
            out = out + 4;
        }
        while inp < end {
            ch = inp.view(1)[0];
            inp = inp + 1;
            if uc_is_surrogate(ch) {
                return (
                    length - (codec_span(ptr[u8](inp), ptr[u8](end)) // 4 + 1),
                    out
                );
            }
            out.view(1)[0] = bswap32(ch);
            out = out + 1;
        }
    }
    return (length, out);
}

impl make_encode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject] {
    if not exc {
        return PyObject_CallFunction(
            PyExc_UnicodeEncodeError,
            "sOnns",
            encoding,
            unicode,
            startpos,
            endpos,
            reason
        );
    }
    if PyUnicodeEncodeError_SetStart(exc, startpos) != i32(0)
        or PyUnicodeEncodeError_SetEnd(exc, endpos) != i32(0)
        or PyUnicodeEncodeError_SetReason(exc, reason) != i32(0) {
        object_decref(exc);
        return NULL;
    }
    return exc;
}

impl raise_encode_exception(
    exc: ptr[PyObject],
    encoding: ptr[u8],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject] {
    cache = make_encode_exception(exc, encoding, unicode, startpos, endpos, reason);
    if cache {
        PyCodec_StrictErrors(cache);
    }
    return cache;
}

impl unicode_encode_call_errorhandler(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    encoding: ptr[u8],
    reason: ptr[u8],
    unicode: ptr[PyObject],
    exc: ptr[PyObject],
    startpos: i64,
    endpos: i64
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject], i64] {
    handler = error_handler;
    newpos: i64 = 0;
    if not handler {
        handler = PyCodec_LookupError(errors);
        if not handler {
            return (NULL, handler, exc, newpos);
        }
    }
    length = uo_length(unicode);
    cache = make_encode_exception(exc, encoding, unicode, startpos, endpos, reason);
    if not cache {
        return (NULL, handler, cache, newpos);
    }
    restuple = PyObject_CallOneArg(handler, cache);
    if not restuple {
        return (NULL, handler, cache, newpos);
    }

    if not tuple_check(restuple) or object_size(restuple) != 2 {
        PyErr_SetString(
            PyExc_TypeError, "encoding error handler must return (str/bytes, int) tuple"
        );
        object_decref(restuple);
        return (NULL, handler, cache, newpos);
    }
    resunicode = tuple_get_item(restuple, 0);
    index = _PyNumber_Index(tuple_get_item(restuple, 1));
    newpos = -1;
    if index {
        newpos = PyLong_AsSsize_t(index);
        object_decref(index);
    }
    if newpos == -1 and PyErr_Occurred() {
        object_decref(restuple);
        return (NULL, handler, cache, newpos);
    }
    if not unicode_check(resunicode) and not bytes_check(resunicode) {
        PyErr_SetString(
            PyExc_TypeError, "encoding error handler must return (str/bytes, int) tuple"
        );
        object_decref(restuple);
        return (NULL, handler, cache, newpos);
    }
    if newpos < 0 {
        newpos = length + newpos;
    }
    if newpos < 0 or newpos > length {
        PyErr_Format(
            PyExc_IndexError, "position %zd from error handler out of bounds", newpos
        );
        object_decref(restuple);
        return (NULL, handler, cache, newpos);
    }
    object_incref(resunicode);
    object_decref(restuple);
    return (resunicode, handler, cache, newpos);
}

impl encode_utf_fail(
    rep: ptr[PyObject],
    error_handler: ptr[PyObject],
    exc: ptr[PyObject],
    v: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(rep);
    object_xdecref(error_handler);
    object_xdecref(exc);
    object_xdecref(v);
    return NULL;
}

impl escape_write_char(writer: ptr[UnicodeWriter], ch: u32) -> i32 {
    if ch <= writer.view(1)[0].maxchar {
        pos = writer.view(1)[0].pos;
        ch_write(i64(writer.view(1)[0].kind), writer.view(1)[0].data, pos, ch);
        writer.view(1)[0].pos = pos + 1;
        return i32(0);
    }
    return writer_write_char_inline(writer, ch);
}

impl escape_write_ascii(writer: ptr[UnicodeWriter], ch: u32) {
    pos = writer.view(1)[0].pos;
    ch_write(i64(writer.view(1)[0].kind), writer.view(1)[0].data, pos, ch);
    writer.view(1)[0].pos = pos + 1;
}

impl decode_unicode_escape(
    s_in: ptr[u8], size: i64, errors: ptr[u8], consumed: ptr[i64]
) -> tuple[ptr[PyObject], i32, ptr[u8]] {
    first_char = i32(-1);
    first_ptr = ptr[u8]();
    stateful = False;
    if consumed {
        stateful = True;
    }
    if size == 0 {
        if consumed {
            consumed.view(1)[0] = 0;
        }
        return (unicode_get_empty(), first_char, first_ptr);
    }
    writer = writer_new();
    if not writer {
        return (NULL, first_char, first_ptr);
    }
    error_handler = NULL;
    exc = NULL;
    writer.view(1)[0].min_length = size;
    if writer_prepare(writer, size, MAX_CHAR_ASCII) < i32(0) {
        return (codec_writer_fail(writer, error_handler, exc), first_char, first_ptr);
    }
    starts = s_in;
    initial_starts = s_in;
    s = s_in;
    end = s_in + size;
    message = ptr[u8]();
    ch = u32(0);
    count: i64 = 0;
    startinpos: i64 = 0;
    endinpos: i64 = 0;
    namelen: i64 = 0;
    status = i32(0);
    while s < end {
        c = s.view(1)[0];
        s = s + 1;

        if c != u8(92) {
            if escape_write_char(writer, u32(c)) < i32(0) {
                return (
                    codec_writer_fail(writer, error_handler, exc),
                    first_char,
                    first_ptr
                );
            }
            continue;
        }
        startinpos = codec_span(starts, s) - 1;
        incomplete = False;
        bad = False;

        if s >= end {
            message = ptr[u8]("\\ at end of string");
            incomplete = True;
        } else {
            c = s.view(1)[0];
            s = s + 1;
            count = 0;
            if c == u8(10) {
                continue;
            } elif c == u8(92) or c == u8(39) or c == u8(34) {
                escape_write_ascii(writer, u32(c));
                continue;
            } elif c == u8(98) {
                escape_write_ascii(writer, u32(8));
                continue;
            } elif c == u8(102) {
                escape_write_ascii(writer, u32(12));
                continue;
            } elif c == u8(116) {
                escape_write_ascii(writer, u32(9));
                continue;
            } elif c == u8(110) {
                escape_write_ascii(writer, u32(10));
                continue;
            } elif c == u8(114) {
                escape_write_ascii(writer, u32(13));
                continue;
            } elif c == u8(118) {
                escape_write_ascii(writer, u32(11));
                continue;
            } elif c == u8(97) {
                escape_write_ascii(writer, u32(7));
                continue;
            } elif c >= u8(48) and c <= u8(55) {
                ch = u32(c) - u32(48);
                if s < end and s.view(1)[0] >= u8(48) and s.view(1)[0] <= u8(55) {
                    ch = (ch << u32(3)) + u32(s.view(1)[0]) - u32(48);
                    s = s + 1;
                    if s < end and s.view(1)[0] >= u8(48) and s.view(1)[0] <= u8(55) {
                        ch = (ch << u32(3)) + u32(s.view(1)[0]) - u32(48);
                        s = s + 1;
                    }
                }
                if ch > u32(255) and first_char == i32(-1) {
                    first_char = i32(ch);
                    if starts == initial_starts {
                        first_ptr = s - 3;
                    }
                }
                if escape_write_char(writer, ch) < i32(0) {
                    return (
                        codec_writer_fail(writer, error_handler, exc),
                        first_char,
                        first_ptr
                    );
                }
                continue;
            } elif c == u8(120) or c == u8(117) or c == u8(85) {
                if c == u8(120) {
                    count = 2;
                    message = ptr[u8]("truncated \\xXX escape");
                } elif c == u8(117) {
                    count = 4;
                    message = ptr[u8]("truncated \\uXXXX escape");
                } else {
                    count = 8;
                    message = ptr[u8]("truncated \\UXXXXXXXX escape");
                }
                ch = u32(0);
                while count > 0 {
                    if s >= end {
                        incomplete = True;
                        break;
                    }
                    c = s.view(1)[0];
                    ch = ch << u32(4);
                    if c >= u8(48) and c <= u8(57) {
                        ch += u32(c) - u32(48);
                    } elif c >= u8(97) and c <= u8(102) {
                        ch += u32(c) - u32(87);
                    } elif c >= u8(65) and c <= u8(70) {
                        ch += u32(c) - u32(55);
                    } else {
                        bad = True;
                        break;
                    }
                    s = s + 1;
                    count -= 1;
                }
                if not incomplete and not bad {
                    if ch > MAX_UNICODE {
                        message = ptr[u8]("illegal Unicode character");
                    } else {
                        if escape_write_char(writer, ch) < i32(0) {
                            return (
                                codec_writer_fail(writer, error_handler, exc),
                                first_char,
                                first_ptr
                            );
                        }
                        continue;
                    }
                }
            } elif c == u8(78) {
                ucnhash_capi = _PyUnicode_GetNameCAPI();
                if not ucnhash_capi {
                    PyErr_SetString(
                        PyExc_UnicodeError,
                        "\\N escapes not supported (can't load unicodedata module)"
                    );
                    return (
                        codec_writer_fail(writer, error_handler, exc),
                        first_char,
                        first_ptr
                    );
                }
                message = ptr[u8]("malformed \\N character escape");
                if s >= end {
                    incomplete = True;
                } elif s.view(1)[0] == u8(123) {
                    s = s + 1;
                    start = s;
                    while s < end and s.view(1)[0] != u8(125) {
                        s = s + 1;
                    }
                    if s >= end {
                        incomplete = True;
                    } else {
                        namelen = codec_span(start, s);
                        if namelen != 0 {
                            s = s + 1;
                            code = ptr[u32](addressof(ucnhash_code_slot));

                            code.view(1)[0] = u32(0xffffffff);
                            if namelen <= INT_MAX
                                and ucnhash_capi.view(1)[0].getcode(
                                    start, i32(namelen), code, i32(0)
                                )
                                    != i32(0) {
                                if escape_write_char(writer, code.view(1)[0])
                                    < i32(0) {
                                    return (
                                        codec_writer_fail(writer, error_handler, exc),
                                        first_char,
                                        first_ptr
                                    );
                                }
                                continue;
                            }
                            message = ptr[u8]("unknown Unicode character name");
                        }
                    }
                }
            } else {
                if first_char == i32(-1) {
                    first_char = i32(c);
                    if starts == initial_starts {
                        first_ptr = s - 1;
                    }
                }
                escape_write_ascii(writer, u32(92));
                if escape_write_char(writer, u32(c)) < i32(0) {
                    return (
                        codec_writer_fail(writer, error_handler, exc),
                        first_char,
                        first_ptr
                    );
                }
                continue;
            }
        }

        if incomplete and stateful {
            consumed.view(1)[0] = startinpos;
            break;
        }

        endinpos = codec_span(starts, s);
        writer.view(1)[0].min_length = codec_span(s, end) + writer.view(1)[0].pos;
        (status, error_handler, exc, starts, end, endinpos, s) = unicode_decode_call_errorhandler_writer(
            errors,
            error_handler,
            ptr[u8]("unicodeescape"),
            message,
            starts,
            end,
            startinpos,
            endinpos,
            exc,
            writer
        );
        if status != i32(0) {
            return (
                codec_writer_fail(writer, error_handler, exc),
                first_char,
                first_ptr
            );
        }
    }
    return (codec_writer_finish(writer, error_handler, exc), first_char, first_ptr);
}

impl encode_ucs1_fail(
    writer: ptr[BytesWriterFields],
    rep: ptr[PyObject],
    error_handler_obj: ptr[PyObject],
    exc: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(rep);
    _PyBytesWriter_Dealloc(writer);
    bytes_writer_free(writer);
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    return NULL;
}

impl unicode_encode_ucs1(
    unicode: ptr[PyObject], errors: ptr[u8], limit: u32
) -> ptr[PyObject] {
    pos: i64 = 0;
    encoding = ptr[u8]("latin-1") if limit == u32(256) else ptr[u8]("ascii");
    reason = ptr[u8]("ordinal not in range(256)")
        if limit == u32(256)
        else ptr[u8]("ordinal not in range(128)");
    error_handler_obj = NULL;
    exc = NULL;
    error_handler = _Py_ERROR_UNKNOWN;
    rep = NULL;
    size = uo_length(unicode);
    kind = uo_kind(unicode);
    data = uo_data(unicode);
    if size == 0 {
        return PyBytes_FromStringAndSize(ptr[u8](), 0);
    }
    writer = bytes_writer_new();
    if not writer {
        return NULL;
    }
    s = ptr[u8](_PyBytesWriter_Alloc(writer, size));
    if not s {
        bytes_writer_free(writer);
        return NULL;
    }
    newpos: i64 = 0;
    while pos < size {
        ch = ch_read(kind, data, pos);

        if ch < limit {
            s.view(1)[0] = u8.wrap(ch);
            s = s + 1;
            pos += 1;
            continue;
        }

        collstart = pos;
        collend = collstart + 1;
        while collend < size and ch_read(kind, data, collend) >= limit {
            collend += 1;
        }

        writer.view(1)[0].overallocate = i32(1) if collend < size else i32(0);

        if error_handler == _Py_ERROR_UNKNOWN {
            error_handler = _Py_GetErrorHandler(errors);
        }
        call_handler = False;
        if error_handler == _Py_ERROR_STRICT {
            exc = raise_encode_exception(
                exc, encoding, unicode, collstart, collend, reason
            );
            return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
        } elif error_handler == _Py_ERROR_REPLACE {
            memset(ptr(s), i32(63), u64(collend - collstart));
            s = s + (collend - collstart);
            pos = collend;
        } elif error_handler == _Py_ERROR_IGNORE {
            pos = collend;
        } elif error_handler == _Py_ERROR_BACKSLASHREPLACE {
            writer.view(1)[0].min_size -= collend - collstart;
            s = backslashreplace(writer, s, unicode, collstart, collend);
            if not s {
                return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
            }
            pos = collend;
        } elif error_handler == _Py_ERROR_XMLCHARREFREPLACE {
            writer.view(1)[0].min_size -= collend - collstart;
            s = xmlcharrefreplace(writer, s, unicode, collstart, collend);
            if not s {
                return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
            }
            pos = collend;
        } elif error_handler == _Py_ERROR_SURROGATEESCAPE {
            i = collstart;
            while i < collend {
                ch = ch_read(kind, data, i);
                if ch < u32(0xdc80) or u32(0xdcff) < ch {
                    break;
                }
                s.view(1)[0] = u8(ch - u32(0xdc00));
                s = s + 1;
                pos += 1;
                i += 1;
            }
            if i < collend {
                collstart = pos;
                call_handler = True;
            }
        } else {
            call_handler = True;
        }
        if call_handler {
            (rep, error_handler_obj, exc, newpos) = unicode_encode_call_errorhandler(
                errors,
                error_handler_obj,
                encoding,
                reason,
                unicode,
                exc,
                collstart,
                collend
            );
            if not rep {
                return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
            }
            if newpos < collstart {
                writer.view(1)[0].overallocate = i32(1);
                s = ptr[u8](_PyBytesWriter_Prepare(writer, ptr(s), collstart - newpos));
                if not s {
                    return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
                }
            } else {
                writer.view(1)[0].min_size -= newpos - collstart;
                writer.view(1)[0].overallocate = i32(1) if newpos < size else i32(0);
            }
            if bytes_check(rep) {
                s = ptr[u8](
                    _PyBytesWriter_WriteBytes(
                        writer, ptr(s), ptr(bytes_data(rep)), object_size(rep)
                    )
                );
            } else {
                not_encodable = uo_kind(rep) != PyUnicode_1BYTE_KIND
                    if limit == u32(256)
                    else not uo_is_ascii(rep);
                if not_encodable {
                    exc = raise_encode_exception(
                        exc, encoding, unicode, collstart, collend, reason
                    );
                    return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
                }
                s = ptr[u8](
                    _PyBytesWriter_WriteBytes(
                        writer, ptr(s), ptr(uo_data(rep)), uo_length(rep)
                    )
                );
            }
            if not s {
                return encode_ucs1_fail(writer, rep, error_handler_obj, exc);
            }
            pos = newpos;
            object_decref(rep);
            rep = NULL;
        }
    }
    object_xdecref(error_handler_obj);
    object_xdecref(exc);
    result = _PyBytesWriter_Finish(writer, ptr(s));
    bytes_writer_free(writer);
    return result;
}

impl charmap_decode_string(
    s_in: ptr[u8],
    size: i64,
    mapping: ptr[PyObject],
    errors: ptr[u8],
    writer: ptr[UnicodeWriter]
) -> i32 {
    starts = s_in;
    s = s_in;
    startinpos: i64 = 0;
    endinpos: i64 = 0;
    error_handler = NULL;
    exc = NULL;
    status = i32(0);
    x = u32(0);
    ch = u8(0);
    maplen = uo_length(mapping);
    mapdata = uo_data(mapping);
    mapkind = uo_kind(mapping);
    e = s + size;
    if mapkind == PyUnicode_1BYTE_KIND and maplen >= 256 {
        outdata = writer.view(1)[0].data;
        maxchar = writer.view(1)[0].maxchar;
        while s < e {
            ch = s.view(1)[0];
            x = u32((mapdata + i64(ch)).view(1)[0]);
            if x > maxchar {
                if writer_prepare(writer, 1, u32(0xff)) == -1 {
                    return i32(-1);
                }
                maxchar = writer.view(1)[0].maxchar;
                outdata = writer.view(1)[0].data;
            }
            pos = writer.view(1)[0].pos;
            (outdata + pos).view(1)[0] = u8.wrap(x);
            writer.view(1)[0].pos = pos + 1;
            s = s + 1;
        }
        return i32(0);
    }
    while s < e {
        jumped = False;
        if mapkind == PyUnicode_2BYTE_KIND and maplen >= 256 {
            outkind = i64(writer.view(1)[0].kind);
            mapdata_ucs2 = ptr[u16](mapdata);
            if outkind == PyUnicode_1BYTE_KIND {
                outdata1 = writer.view(1)[0].data;
                maxchar1 = writer.view(1)[0].maxchar;
                while s < e {
                    ch = s.view(1)[0];
                    x = u32((mapdata_ucs2 + i64(ch)).view(1)[0]);
                    if x > maxchar1 {
                        jumped = True;
                        break;
                    }
                    pos1 = writer.view(1)[0].pos;
                    (outdata1 + pos1).view(1)[0] = u8.wrap(x);
                    writer.view(1)[0].pos = pos1 + 1;
                    s = s + 1;
                }
                if not jumped {
                    break;
                }
            } elif outkind == PyUnicode_2BYTE_KIND {
                outdata2 = ptr[u16](writer.view(1)[0].data);
                while s < e {
                    ch = s.view(1)[0];
                    x = u32((mapdata_ucs2 + i64(ch)).view(1)[0]);
                    if x == u32(0xFFFE) {
                        jumped = True;
                        break;
                    }
                    pos2 = writer.view(1)[0].pos;
                    (outdata2 + pos2).view(1)[0] = u16.wrap(x);
                    writer.view(1)[0].pos = pos2 + 1;
                    s = s + 1;
                }
                if not jumped {
                    break;
                }
            }
        }
        if not jumped {
            ch = s.view(1)[0];
            if i64(ch) < maplen {
                x = ch_read(mapkind, mapdata, i64(ch));
            } else {
                x = u32(0xfffe);
            }
        }
        if x == u32(0xfffe) {
            startinpos = int(s) - int(starts);
            endinpos = startinpos + 1;
            (status, error_handler, exc, starts, e, endinpos, s) = unicode_decode_call_errorhandler_writer(
                errors,
                error_handler,
                ptr[u8]("charmap"),
                ptr[u8]("character maps to <undefined>"),
                starts,
                e,
                startinpos,
                endinpos,
                exc,
                writer
            );
            if status != 0 {
                object_xdecref(error_handler);
                object_xdecref(exc);
                return i32(-1);
            }
            continue;
        }
        if writer_write_char_inline(writer, x) < 0 {
            object_xdecref(error_handler);
            object_xdecref(exc);
            return i32(-1);
        }
        s = s + 1;
    }
    object_xdecref(error_handler);
    object_xdecref(exc);
    return i32(0);
}

impl charmap_decode_mapping(
    s_in: ptr[u8],
    size: i64,
    mapping: ptr[PyObject],
    errors: ptr[u8],
    writer: ptr[UnicodeWriter]
) -> i32 {
    starts = s_in;
    s = s_in;
    startinpos: i64 = 0;
    endinpos: i64 = 0;
    error_handler = NULL;
    exc = NULL;
    status = i32(0);
    item: ptr[PyObject] = NULL;
    limit = u64(MAX_UNICODE) + u64(1);
    e = s + size;
    while s < e {
        ch = s.view(1)[0];

        key = PyLong_FromLong(i64(ch));
        if not key {
            return charmap_decode_fail(item, error_handler, exc);
        }
        item = NULL;
        rc = PyMapping_GetOptionalItem(mapping, key, &mut item);
        object_decref(key);
        undefined = False;
        if rc == 0 {
            undefined = True;
        } elif not item {
            if PyErr_ExceptionMatches(PyExc_LookupError) != 0 {
                PyErr_Clear();
                undefined = True;
            } else {
                return charmap_decode_fail(item, error_handler, exc);
            }
        }
        if not undefined {
            if item == Py_None {
                undefined = True;
            } elif long_check(item) {
                value = PyLong_AsLong(item);
                if value == 0xFFFE {
                    undefined = True;
                } else {
                    if value < 0 or value > i64(MAX_UNICODE) {
                        PyErr_Format(
                            PyExc_TypeError,
                            "character mapping must be in range(0x%lx)",
                            limit
                        );
                        return charmap_decode_fail(item, error_handler, exc);
                    }
                    if writer_write_char_inline(writer, u32(value)) < 0 {
                        return charmap_decode_fail(item, error_handler, exc);
                    }
                }
            } elif unicode_check(item) {
                if uo_length(item) == 1 {
                    uvalue = uo_read_char(item, 0);
                    if uvalue == u32(0xFFFE) {
                        undefined = True;
                    } elif writer_write_char_inline(writer, uvalue) < 0 {
                        return charmap_decode_fail(item, error_handler, exc);
                    }
                } else {
                    writer.view(1)[0].overallocate = u8(1);
                    if _PyUnicodeWriter_WriteStr(writer, item) == -1 {
                        return charmap_decode_fail(item, error_handler, exc);
                    }
                }
            } else {
                PyErr_SetString(
                    PyExc_TypeError,
                    "character mapping must return integer, None or str"
                );
                return charmap_decode_fail(item, error_handler, exc);
            }
        }
        object_xdecref(item);
        item = NULL;
        if not undefined {
            s = s + 1;
            continue;
        }

        startinpos = int(s) - int(starts);
        endinpos = startinpos + 1;
        (status, error_handler, exc, starts, e, endinpos, s) = unicode_decode_call_errorhandler_writer(
            errors,
            error_handler,
            ptr[u8]("charmap"),
            ptr[u8]("character maps to <undefined>"),
            starts,
            e,
            startinpos,
            endinpos,
            exc,
            writer
        );
        if status != 0 {
            return charmap_decode_fail(item, error_handler, exc);
        }
    }
    object_xdecref(error_handler);
    object_xdecref(exc);
    return i32(0);
}

impl charmap_decode_fail(
    item: ptr[PyObject], error_handler: ptr[PyObject], exc: ptr[PyObject]
) -> i32 {
    object_xdecref(item);
    object_xdecref(error_handler);
    object_xdecref(exc);
    return i32(-1);
}

impl encoding_map_type -> ptr[PyTypeObject] {
    return addressof(EncodingMapType);
}

impl encoding_map_count2(op: ptr[PyObject]) -> i64 {
    return i64(ptr[i32](ptr[u8](op) + encoding_map_COUNT2).view(1)[0]);
}

impl encoding_map_count3(op: ptr[PyObject]) -> i64 {
    return i64(ptr[i32](ptr[u8](op) + encoding_map_COUNT3).view(1)[0]);
}

impl EncodingMap_size_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(
        (encoding_map_SIZE - 1)
            + 16 * encoding_map_count2(self_)
            + 128 * encoding_map_count3(self_)
    );
}

impl EncodingMap_size(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return EncodingMap_size_impl(self_);
}

impl encoding_map_lookup(c: u32, mapping: ptr[PyObject]) -> i64 {
    l1 = i64(c >> 11);
    l2 = i64((c >> 7) & 0xF);
    l3 = i64(c & 0x7F);
    if c > u32(0xFFFF) {
        return -1;
    }
    if c == u32(0) {
        return 0;
    }
    base = ptr[u8](mapping);
    level23 = base + encoding_map_LEVEL23;

    i = i64((base + encoding_map_LEVEL1 + l1).view(1)[0]);
    if i == 0xFF {
        return -1;
    }

    i = i64((level23 + (16 * i + l2)).view(1)[0]);
    if i == 0xFF {
        return -1;
    }

    i = i64((level23 + (16 * encoding_map_count2(mapping) + 128 * i + l3)).view(1)[0]);
    if i == 0 {
        return -1;
    }
    return i;
}

impl charmapencode_lookup(c: u32, mapping: ptr[PyObject]) -> tuple[ptr[PyObject], u8] {
    w = PyLong_FromLong(i64(c));
    if not w {
        return (NULL, u8(0));
    }
    x: ptr[PyObject] = NULL;
    rc = PyMapping_GetOptionalItem(mapping, w, &mut x);
    object_decref(w);
    if rc == 0 {
        return (object_new_ref(Py_None), u8(0));
    }
    if not x {
        if PyErr_ExceptionMatches(PyExc_LookupError) != 0 {
            PyErr_Clear();
            return (object_new_ref(Py_None), u8(0));
        }
        return (NULL, u8(0));
    }
    if x == Py_None {
        return (x, u8(0));
    }
    if long_check(x) {
        value = PyLong_AsLong(x);
        if value < 0 or value > 255 {
            PyErr_SetString(PyExc_TypeError, "character mapping must be in range(256)");
            object_decref(x);
            return (NULL, u8(0));
        }
        return (x, u8(value));
    }
    if bytes_check(x) {
        return (x, u8(0));
    }

    PyErr_Format(
        PyExc_TypeError,
        "character mapping must return integer, bytes or None, not %.400s",
        object_type(x).view(1)[0].tp_name
    );
    object_decref(x);
    return (NULL, u8(0));
}

impl charmapencode_resize(
    outobj: ptr[PyObject], requiredsize_in: i64
) -> tuple[i32, ptr[PyObject]] {
    outsize = object_size(outobj);
    requiredsize = requiredsize_in;
    if requiredsize < 2 * outsize {
        requiredsize = 2 * outsize;
    }
    resized = outobj;
    if _PyBytes_Resize(&mut resized, requiredsize) != 0 {
        return (i32(-1), resized);
    }
    return (i32(0), resized);
}

impl charmapencode_output(
    c: u32, mapping: ptr[PyObject], outobj: ptr[PyObject], outpos: i64
) -> tuple[i64, ptr[PyObject], i64] {
    out = outobj;
    pos = outpos;
    status = i32(0);
    outsize = object_size(out);
    if object_is_type(mapping, encoding_map_type()) {
        res = encoding_map_lookup(c, mapping);
        requiredsize = pos + 1;
        if res == -1 {
            return (enc_FAILED, out, pos);
        }
        if outsize < requiredsize {
            (status, out) = charmapencode_resize(out, requiredsize);
            if status != 0 {
                return (enc_EXCEPTION, out, pos);
            }
        }
        (bytes_data(out) + pos).view(1)[0] = u8.wrap(res);
        return (enc_SUCCESS, out, pos + 1);
    }
    (rep, replace) = charmapencode_lookup(c, mapping);
    if not rep {
        return (enc_EXCEPTION, out, pos);
    }
    if rep == Py_None {
        object_decref(rep);
        return (enc_FAILED, out, pos);
    }
    if long_check(rep) {
        required1 = pos + 1;
        if outsize < required1 {
            (status, out) = charmapencode_resize(out, required1);
            if status != 0 {
                object_decref(rep);
                return (enc_EXCEPTION, out, pos);
            }
        }
        (bytes_data(out) + pos).view(1)[0] = replace;
        pos += 1;
    } else {
        repchars = bytes_data(rep);
        repsize = object_size(rep);
        required2 = pos + repsize;
        if outsize < required2 {
            (status, out) = charmapencode_resize(out, required2);
            if status != 0 {
                object_decref(rep);
                return (enc_EXCEPTION, out, pos);
            }
        }
        jacpy_memory_copy(ptr(bytes_data(out) + pos), ptr(repchars), repsize);
        pos += repsize;
    }
    object_decref(rep);
    return (enc_SUCCESS, out, pos);
}

impl charmap_output_charref(
    ch: u32, mapping: ptr[PyObject], outobj: ptr[PyObject], outpos: i64
) -> tuple[i64, ptr[PyObject], i64] {
    out = outobj;
    pos = outpos;
    x = enc_SUCCESS;
    value = i64(ch);
    (x, out, pos) = charmapencode_output(u32(38), mapping, out, pos);
    if x != enc_SUCCESS {
        return (x, out, pos);
    }
    (x, out, pos) = charmapencode_output(u32(35), mapping, out, pos);
    if x != enc_SUCCESS {
        return (x, out, pos);
    }

    divisor: i64 = 1;
    while divisor * 10 <= value {
        divisor *= 10;
    }
    while divisor > 0 {
        digit = (value // divisor) % 10;
        (x, out, pos) = charmapencode_output(u32(48 + digit), mapping, out, pos);
        if x != enc_SUCCESS {
            return (x, out, pos);
        }
        divisor = divisor // 10;
    }
    (x, out, pos) = charmapencode_output(u32(59), mapping, out, pos);
    return (x, out, pos);
}

impl charmap_encoding_error(
    unicode: ptr[PyObject],
    inpos_in: i64,
    mapping: ptr[PyObject],
    exc_in: ptr[PyObject],
    error_handler_in: i32,
    error_handler_obj_in: ptr[PyObject],
    errors: ptr[u8],
    res_in: ptr[PyObject],
    respos_in: i64
) -> tuple[i32, i64, ptr[PyObject], i32, ptr[PyObject], ptr[PyObject], i64] {
    inpos = inpos_in;
    exc = exc_in;
    error_handler = error_handler_in;
    error_handler_obj = error_handler_obj_in;
    res = res_in;
    respos = respos_in;
    encoding = ptr[u8]("charmap");
    reason = ptr[u8]("character maps to <undefined>");
    x = enc_SUCCESS;
    status = i32(0);
    newpos: i64 = 0;
    repunicode = NULL;

    collstartpos = inpos;
    collendpos = inpos + 1;
    size = uo_length(unicode);

    while collendpos < size {
        if object_is_type(mapping, encoding_map_type()) {
            ch = uo_read_char(unicode, collendpos);
            val = encoding_map_lookup(ch, mapping);
            if val != -1 {
                break;
            }
            collendpos += 1;
            continue;
        }
        ch = uo_read_char(unicode, collendpos);
        (rep, replace) = charmapencode_lookup(ch, mapping);
        if not rep {
            return (i32(-1), inpos, exc, error_handler, error_handler_obj, res, respos);
        }
        if rep != Py_None {
            object_decref(rep);
            break;
        }
        object_decref(rep);
        collendpos += 1;
    }

    if error_handler == _Py_ERROR_UNKNOWN {
        error_handler = _Py_GetErrorHandler(errors);
    }
    if error_handler == _Py_ERROR_STRICT {
        exc = raise_encode_exception(
            exc, encoding, unicode, collstartpos, collendpos, reason
        );
        return (i32(-1), inpos, exc, error_handler, error_handler_obj, res, respos);
    }
    if error_handler == _Py_ERROR_REPLACE or error_handler == _Py_ERROR_IGNORE {
        if error_handler == _Py_ERROR_REPLACE {
            collpos = collstartpos;
            while collpos < collendpos {
                (x, res, respos) = charmapencode_output(u32(63), mapping, res, respos);
                if x == enc_EXCEPTION {
                    return (
                        i32(-1),
                        inpos,
                        exc,
                        error_handler,
                        error_handler_obj,
                        res,
                        respos
                    );
                }
                if x == enc_FAILED {
                    exc = raise_encode_exception(
                        exc, encoding, unicode, collstartpos, collendpos, reason
                    );
                    return (
                        i32(-1),
                        inpos,
                        exc,
                        error_handler,
                        error_handler_obj,
                        res,
                        respos
                    );
                }
                collpos += 1;
            }
        }

        return (i32(0), collendpos, exc, error_handler, error_handler_obj, res, respos);
    }
    if error_handler == _Py_ERROR_XMLCHARREFREPLACE {
        collpos = collstartpos;
        while collpos < collendpos {
            (x, res, respos) = charmap_output_charref(
                uo_read_char(unicode, collpos), mapping, res, respos
            );
            if x == enc_EXCEPTION {
                return (
                    i32(-1),
                    inpos,
                    exc,
                    error_handler,
                    error_handler_obj,
                    res,
                    respos
                );
            }
            if x == enc_FAILED {
                exc = raise_encode_exception(
                    exc, encoding, unicode, collstartpos, collendpos, reason
                );
                return (
                    i32(-1),
                    inpos,
                    exc,
                    error_handler,
                    error_handler_obj,
                    res,
                    respos
                );
            }
            collpos += 1;
        }
        return (i32(0), collendpos, exc, error_handler, error_handler_obj, res, respos);
    }
    (repunicode, error_handler_obj, exc, newpos) = unicode_encode_call_errorhandler(
        errors,
        error_handler_obj,
        encoding,
        reason,
        unicode,
        exc,
        collstartpos,
        collendpos
    );
    if not repunicode {
        return (i32(-1), inpos, exc, error_handler, error_handler_obj, res, respos);
    }
    if bytes_check(repunicode) {
        outsize = PyBytes_Size(res);
        repsize = PyBytes_Size(repunicode);
        requiredsize = respos + repsize;
        if requiredsize > outsize {
            (status, res) = charmapencode_resize(res, requiredsize);
            if status != 0 {
                object_decref(repunicode);
                return (
                    i32(-1),
                    inpos,
                    exc,
                    error_handler,
                    error_handler_obj,
                    res,
                    respos
                );
            }
        }
        jacpy_memory_copy(
            ptr(PyBytes_AsString(res) + respos),
            ptr(PyBytes_AsString(repunicode)),
            repsize
        );
        respos += repsize;
        object_decref(repunicode);
        return (i32(0), newpos, exc, error_handler, error_handler_obj, res, respos);
    }

    replen = uo_length(repunicode);
    data = uo_data(repunicode);
    kind = uo_kind(repunicode);
    for index in range(replen) {
        repch = ch_read(kind, data, index);
        (x, res, respos) = charmapencode_output(repch, mapping, res, respos);
        if x == enc_EXCEPTION {
            object_decref(repunicode);
            return (i32(-1), inpos, exc, error_handler, error_handler_obj, res, respos);
        }
        if x == enc_FAILED {
            object_decref(repunicode);
            exc = raise_encode_exception(
                exc, encoding, unicode, collstartpos, collendpos, reason
            );
            return (i32(-1), inpos, exc, error_handler, error_handler_obj, res, respos);
        }
    }
    object_decref(repunicode);
    return (i32(0), newpos, exc, error_handler, error_handler_obj, res, respos);
}

impl make_translate_exception(
    exc: ptr[PyObject],
    unicode: ptr[PyObject],
    startpos: i64,
    endpos: i64,
    reason: ptr[u8]
) -> ptr[PyObject] {
    if not exc {
        return _PyUnicodeTranslateError_Create(unicode, startpos, endpos, reason);
    }
    if PyUnicodeTranslateError_SetStart(exc, startpos) != 0
        or PyUnicodeTranslateError_SetEnd(exc, endpos) != 0
        or PyUnicodeTranslateError_SetReason(exc, reason) != 0 {
        object_decref(exc);
        return NULL;
    }
    return exc;
}

impl unicode_translate_call_errorhandler(
    errors: ptr[u8],
    error_handler: ptr[PyObject],
    reason: ptr[u8],
    unicode: ptr[PyObject],
    exc: ptr[PyObject],
    startpos: i64,
    endpos: i64
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject], i64] {
    handler = error_handler;
    ex = exc;
    if not handler {
        handler = PyCodec_LookupError(errors);
        if not handler {
            return (NULL, handler, ex, 0);
        }
    }
    ex = make_translate_exception(ex, unicode, startpos, endpos, reason);
    if not ex {
        return (NULL, handler, ex, 0);
    }
    restuple = PyObject_CallOneArg(handler, ex);
    if not restuple {
        return (NULL, handler, ex, 0);
    }
    if not tuple_check(restuple) {
        PyErr_SetString(
            PyExc_TypeError, "translating error handler must return (str, int) tuple"
        );
        object_decref(restuple);
        return (NULL, handler, ex, 0);
    }

    if object_size(restuple) != 2 or not unicode_check(tuple_get_item(restuple, 0)) {
        PyErr_SetString(
            PyExc_TypeError, "translating error handler must return (str, int) tuple"
        );
        object_decref(restuple);
        return (NULL, handler, ex, 0);
    }
    resunicode = tuple_get_item(restuple, 0);
    i_newpos: i64 = -1;
    iobj = _PyNumber_Index(tuple_get_item(restuple, 1));
    if iobj {
        i_newpos = PyLong_AsSsize_t(iobj);
        object_decref(iobj);
    }
    if i_newpos == -1 and PyErr_Occurred() {
        object_decref(restuple);
        return (NULL, handler, ex, 0);
    }
    newpos = i_newpos;
    if i_newpos < 0 {
        newpos = uo_length(unicode) + i_newpos;
    }
    if newpos < 0 or newpos > uo_length(unicode) {
        PyErr_Format(
            PyExc_IndexError, "position %zd from error handler out of bounds", newpos
        );
        object_decref(restuple);
        return (NULL, handler, ex, newpos);
    }
    object_incref(resunicode);
    object_decref(restuple);
    return (resunicode, handler, ex, newpos);
}

impl charmaptranslate_lookup(
    c: u32, mapping: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32] {
    w = PyLong_FromLong(i64(c));
    if not w {
        return (i32(-1), NULL, u32(0));
    }
    x: ptr[PyObject] = NULL;
    rc = PyMapping_GetOptionalItem(mapping, w, &mut x);
    object_decref(w);
    if rc == 0 {
        return (i32(0), NULL, u32(0));
    }
    if not x {
        if PyErr_ExceptionMatches(PyExc_LookupError) != 0 {
            PyErr_Clear();
            return (i32(0), NULL, u32(0));
        }
        return (i32(-1), NULL, u32(0));
    }
    if x == Py_None {
        return (i32(0), x, u32(0));
    }
    if long_check(x) {
        value = PyLong_AsLong(x);
        if value < 0 or value > i64(MAX_UNICODE) {
            limit = u64(MAX_UNICODE) + u64(1);
            PyErr_Format(
                PyExc_ValueError, "character mapping must be in range(0x%lx)", limit
            );
            object_decref(x);
            return (i32(-1), NULL, u32(0));
        }
        return (i32(0), x, u32(value));
    }
    if unicode_check(x) {
        return (i32(0), x, u32(0));
    }

    PyErr_SetString(
        PyExc_TypeError, "character mapping must return integer, None or str"
    );
    object_decref(x);
    return (i32(-1), NULL, u32(0));
}

impl charmaptranslate_output(
    ch: u32, mapping: ptr[PyObject], writer: ptr[UnicodeWriter]
) -> i32 {
    (status, item, replace) = charmaptranslate_lookup(ch, mapping);
    if status != 0 {
        return i32(-1);
    }
    if not item {
        if writer_write_char_inline(writer, ch) < 0 {
            return i32(-1);
        }
        return i32(1);
    }
    if item == Py_None {
        object_decref(item);
        return i32(0);
    }
    if long_check(item) {
        if writer_write_char_inline(writer, replace) < 0 {
            object_decref(item);
            return i32(-1);
        }
        object_decref(item);
        return i32(1);
    }
    if not unicode_check(item) {
        object_decref(item);
        return i32(-1);
    }
    if _PyUnicodeWriter_WriteStr(writer, item) < 0 {
        object_decref(item);
        return i32(-1);
    }
    object_decref(item);
    return i32(1);
}

impl unicode_fast_translate_lookup(
    mapping: ptr[PyObject], ch: u8, translate: ptr[u8]
) -> i32 {
    (status, item, replace) = charmaptranslate_lookup(u32(ch), mapping);
    if status != 0 {
        return i32(-1);
    }
    slot = translate + i64(ch);
    if item == Py_None {
        slot.view(1)[0] = u8(0xfe);
    } elif not item {
        slot.view(1)[0] = ch;
        return i32(1);
    } elif long_check(item) {
        if replace > u32(127) {
            object_decref(item);
            return i32(0);
        }
        slot.view(1)[0] = u8(replace);
    } elif unicode_check(item) {
        if uo_length(item) != 1 {
            object_decref(item);
            return i32(0);
        }
        uch = uo_read_char(item, 0);
        if uch > u32(127) {
            object_decref(item);
            return i32(0);
        }
        slot.view(1)[0] = u8(uch);
    } else {
        object_decref(item);
        return i32(0);
    }
    object_decref(item);
    return i32(1);
}

impl unicode_fast_translate(
    input: ptr[PyObject],
    mapping: ptr[PyObject],
    writer: ptr[UnicodeWriter],
    ignore: bool
) -> tuple[i32, i64] {
    length = uo_length(input);

    ascii_table = ptr[u8](PyMem_Malloc(u64(128)));
    if not ascii_table {
        PyErr_NoMemory();
        return (i32(-1), 0);
    }
    memset(ptr(ascii_table), i32(0xff), u64(128));
    in_start = uo_data(input);
    inp = in_start;
    end = inp + length;
    out_start = uo_data(writer.view(1)[0].buffer);
    out = out_start;
    stopped = False;
    while inp < end {
        ch = inp.view(1)[0];
        ch2 = (ascii_table + i64(ch)).view(1)[0];
        if ch2 == u8(0xff) {
            translate = unicode_fast_translate_lookup(mapping, ch, ascii_table);
            if translate < 0 {
                PyMem_Free(ptr(ascii_table));
                return (i32(-1), 0);
            }
            if translate == 0 {
                stopped = True;
                break;
            }
            ch2 = (ascii_table + i64(ch)).view(1)[0];
        }
        if ch2 == u8(0xfe) {
            if ignore {
                inp = inp + 1;
                continue;
            }
            stopped = True;
            break;
        }

        out.view(1)[0] = ch2;
        out = out + 1;
        inp = inp + 1;
    }
    PyMem_Free(ptr(ascii_table));
    writer.view(1)[0].pos = int(out) - int(out_start);
    input_pos: i64 = int(inp) - int(in_start);
    if stopped {
        return (i32(0), input_pos);
    }
    return (i32(1), input_pos);
}

impl charmap_translate_fail(
    writer: ptr[UnicodeWriter], exc: ptr[PyObject], error_handler: ptr[PyObject]
) -> ptr[PyObject] {
    _PyUnicodeWriter_Dealloc(writer);
    writer_free(writer);
    object_xdecref(exc);
    object_xdecref(error_handler);
    return NULL;
}

impl _PyUnicode_TranslateCharmap(
    input: ptr[PyObject], mapping: ptr[PyObject], errors: ptr[u8]
) -> ptr[PyObject] {
    reason = ptr[u8]("character maps to <undefined>");
    if not mapping {
        PyErr_BadArgument();
        return NULL;
    }
    data = uo_data(input);
    kind = uo_kind(input);
    size = uo_length(input);
    if size == 0 {
        return PyUnicode_FromObject(input);
    }

    writer = writer_new();
    if not writer {
        return NULL;
    }
    error_handler = NULL;
    exc = NULL;
    if writer_prepare(writer, size, u32(127)) == -1 {
        return charmap_translate_fail(writer, exc, error_handler);
    }
    ignore = False;
    if errors and strcmp(errors, ptr[u8]("ignore")) == 0 {
        ignore = True;
    }
    i: i64 = 0;
    res = i32(0);
    if uo_is_ascii(input) {
        (res, i) = unicode_fast_translate(input, mapping, writer, ignore);
        if res < 0 {
            _PyUnicodeWriter_Dealloc(writer);
            writer_free(writer);
            return NULL;
        }
        if res == 1 {
            done = _PyUnicodeWriter_Finish(writer);
            writer_free(writer);
            return done;
        }
    }
    status = i32(0);
    newpos: i64 = 0;
    repunicode = NULL;
    while i < size {
        ch = ch_read(kind, data, i);
        translate = charmaptranslate_output(ch, mapping, writer);
        if translate < 0 {
            return charmap_translate_fail(writer, exc, error_handler);
        }
        if translate != 0 {
            i += 1;
            continue;
        }

        collstart = i;
        collend = i + 1;

        while collend < size {
            ch = ch_read(kind, data, collend);
            (status, x, replace) = charmaptranslate_lookup(ch, mapping);
            if status != 0 {
                return charmap_translate_fail(writer, exc, error_handler);
            }
            object_xdecref(x);
            if x != Py_None {
                break;
            }
            collend += 1;
        }
        if ignore {
            i = collend;
        } else {
            (repunicode, error_handler, exc, newpos) = unicode_translate_call_errorhandler(
                errors, error_handler, reason, input, exc, collstart, collend
            );
            if not repunicode {
                return charmap_translate_fail(writer, exc, error_handler);
            }
            if _PyUnicodeWriter_WriteStr(writer, repunicode) < 0 {
                object_decref(repunicode);
                return charmap_translate_fail(writer, exc, error_handler);
            }
            object_decref(repunicode);
            i = newpos;
        }
    }
    object_xdecref(exc);
    object_xdecref(error_handler);
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl adjust_indices(start_in: i64, end_in: i64, length: i64) -> tuple[i64, i64] {
    start = start_in;
    end = end_in;
    if end > length {
        end = length;
    } elif end < 0 {
        end += length;
        if end < 0 {
            end = 0;
        }
    }
    if start < 0 {
        start += length;
        if start < 0 {
            start = 0;
        }
    }
    return (start, end);
}

impl any_find_slice(
    s1: ptr[PyObject], s2: ptr[PyObject], start_in: i64, end_in: i64, direction: i32
) -> i64 {
    kind1 = uo_kind(s1);
    kind2 = uo_kind(s2);
    if kind1 < kind2 {
        return -1;
    }
    len1 = uo_length(s1);
    len2 = uo_length(s2);
    (start, end) = adjust_indices(start_in, end_in, len1);
    if end - start < len2 {
        return -1;
    }
    buf1 = uo_data(s1);
    buf2 = uo_data(s2);
    if len2 == 1 {
        ch = ch_read(kind2, buf2, 0);
        found = findchar(buf1 + kind1 * start, kind1, end - start, ch, direction);
        if found == -1 {
            return -1;
        }
        return start + found;
    }
    if kind2 != kind1 {
        buf2 = unicode_askind(kind2, buf2, len2, kind1);
        if not buf2 {
            return -2;
        }
    }

    result: i64 = 0;
    if direction > 0 {
        result = sl_find_slice(kind1, buf1, len1, buf2, len2, start, end);
    } else {
        result = sl_rfind_slice(kind1, buf1, len1, buf2, len2, start, end);
    }
    if kind2 != kind1 {
        PyMem_Free(ptr(buf2));
    }
    return result;
}

impl grouping_char(grouping: ptr[u8], i: i64) -> i64 {
    c = i64((grouping + i).view(1)[0]);
    if c > 127 and jacpy_char_max() == 127 {
        return c - 256;
    }
    return c;
}

impl GroupGenerator_next(
    grouping: ptr[u8], previous: i64, i: i64
) -> tuple[i64, i64, i64] {
    c = grouping_char(grouping, i);
    if c == 0 {
        return (previous, previous, i);
    }
    if c == jacpy_char_max() {
        return (0, previous, i);
    }
    return (c, c, i + 1);
}

impl InsertThousandsGrouping_fill(
    writer: ptr[UnicodeWriter],
    buffer_pos: i64,
    digits: ptr[PyObject],
    digits_pos: i64,
    n_chars: i64,
    n_zeros: i64,
    thousands_sep: ptr[PyObject],
    thousands_sep_len: i64,
    maxchar: ptr[u32],
    forward: i32
) -> tuple[i64, i64] {
    bpos = buffer_pos;
    dpos = digits_pos;
    if not writer {
        if maxchar.view(1)[0] == u32(127) and thousands_sep {
            maxchar2 = uo_max_char_value(thousands_sep);
            if maxchar2 > maxchar.view(1)[0] {
                maxchar.view(1)[0] = maxchar2;
            }
        }
        return (bpos, dpos);
    }
    buffer = writer.view(1)[0].buffer;
    if thousands_sep {
        if forward == 0 {
            bpos -= thousands_sep_len;
        }

        _PyUnicode_FastCopyCharacters(
            buffer, bpos, thousands_sep, 0, thousands_sep_len
        );
        if forward != 0 {
            bpos += thousands_sep_len;
        }
    }
    if forward == 0 {
        bpos -= n_chars;
        dpos -= n_chars;
    }
    _PyUnicode_FastCopyCharacters(buffer, bpos, digits, dpos, n_chars);
    if forward != 0 {
        bpos += n_chars;
        dpos += n_chars;
    }
    if n_zeros != 0 {
        if forward == 0 {
            bpos -= n_zeros;
        }
        unicode_fill(uo_kind(buffer), uo_data(buffer), u32(48), bpos, n_zeros);
        if forward != 0 {
            bpos += n_zeros;
        }
    }
    return (bpos, dpos);
}

impl tailmatch(
    self_: ptr[PyObject],
    substring: ptr[PyObject],
    start_in: i64,
    end_in: i64,
    direction: i32
) -> i32 {
    (start, end) = adjust_indices(start_in, end_in, uo_length(self_));
    end -= uo_length(substring);
    if end < start {
        return i32(0);
    }
    if uo_length(substring) == 0 {
        return i32(1);
    }
    kind_self = uo_kind(self_);
    data_self = uo_data(self_);
    kind_sub = uo_kind(substring);
    data_sub = uo_data(substring);
    end_sub = uo_length(substring) - 1;
    offset = start;
    if direction > 0 {
        offset = end;
    }
    if ch_read(kind_self, data_self, offset) == ch_read(kind_sub, data_sub, 0)
        and ch_read(kind_self, data_self, offset + end_sub)
            == ch_read(kind_sub, data_sub, end_sub) {
        if kind_self == kind_sub {
            same = memcmp(
                ptr(data_self + offset * kind_sub),
                ptr(data_sub),
                u64(uo_length(substring) * kind_sub)
            );
            return i32(1) if same == 0 else i32(0);
        }

        i: i64 = 1;
        while i < end_sub {
            if ch_read(kind_self, data_self, offset + i)
                != ch_read(kind_sub, data_sub, i) {
                return i32(0);
            }
            i += 1;
        }
        return i32(1);
    }
    return i32(0);
}

impl ascii_upper_or_lower(self_: ptr[PyObject], lower: bool) -> ptr[PyObject] {
    length = uo_length(self_);
    data = uo_data(self_);
    res = PyUnicode_New(length, u32(127));
    if not res {
        return NULL;
    }
    resdata = uo_data(res);
    if lower {
        _Py_bytes_lower(resdata, data, length);
    } else {
        _Py_bytes_upper(resdata, data, length);
    }
    return res;
}

impl handle_capital_sigma(kind: i64, data: ptr[u8], length: i64, i: i64) -> u32 {
    c = u32(0);
    j = i - 1;
    while j >= 0 {
        c = ch_read(kind, data, j);
        if _PyUnicode_IsCaseIgnorable(c) == 0 {
            break;
        }
        j -= 1;
    }
    final_sigma = j >= 0 and _PyUnicode_IsCased(c) != 0;
    if final_sigma {
        j = i + 1;
        while j < length {
            c = ch_read(kind, data, j);
            if _PyUnicode_IsCaseIgnorable(c) == 0 {
                break;
            }
            j += 1;
        }
        final_sigma = j == length or _PyUnicode_IsCased(c) == 0;
    }
    return u32(0x3C2) if final_sigma else u32(0x3C3);
}

impl lower_ucs4(
    kind: i64, data: ptr[u8], length: i64, i: i64, c: u32, mapped: ptr[u32]
) -> i32 {
    if c == u32(0x3A3) {
        mapped.view(1)[0] = handle_capital_sigma(kind, data, length, i);
        return i32(1);
    }
    return _PyUnicode_ToLowerFull(c, mapped);
}

impl do_capitalize(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    k: i64 = 0;
    c = ch_read(kind, data, 0);
    n_res = _PyUnicode_ToTitleFull(c, mapped);
    for j in range(i64(n_res)) {
        m = (mapped + j).view(1)[0];
        if m > maxchar {
            maxchar = m;
        }
        (res + k).view(1)[0] = m;
        k += 1;
    }
    i: i64 = 1;
    while i < length {
        c = ch_read(kind, data, i);
        n_res = lower_ucs4(kind, data, length, i, c, mapped);
        for j in range(i64(n_res)) {
            m = (mapped + j).view(1)[0];
            if m > maxchar {
                maxchar = m;
            }
            (res + k).view(1)[0] = m;
            k += 1;
        }
        i += 1;
    }
    return (k, maxchar);
}

impl do_swapcase(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    k: i64 = 0;
    for i in range(length) {
        c = ch_read(kind, data, i);
        n_res = i32(0);
        if uc_isupper(c) {
            n_res = lower_ucs4(kind, data, length, i, c, mapped);
        } elif uc_islower(c) {
            n_res = _PyUnicode_ToUpperFull(c, mapped);
        } else {
            n_res = i32(1);
            mapped.view(1)[0] = c;
        }
        for j in range(i64(n_res)) {
            m = (mapped + j).view(1)[0];
            if m > maxchar {
                maxchar = m;
            }
            (res + k).view(1)[0] = m;
            k += 1;
        }
    }
    return (k, maxchar);
}

impl do_upper_or_lower(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    lower: bool,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    k: i64 = 0;
    for i in range(length) {
        c = ch_read(kind, data, i);
        n_res = i32(0);
        if lower {
            n_res = lower_ucs4(kind, data, length, i, c, mapped);
        } else {
            n_res = _PyUnicode_ToUpperFull(c, mapped);
        }
        for j in range(i64(n_res)) {
            m = (mapped + j).view(1)[0];
            if m > maxchar {
                maxchar = m;
            }
            (res + k).view(1)[0] = m;
            k += 1;
        }
    }
    return (k, maxchar);
}

impl do_upper(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    return do_upper_or_lower(kind, data, length, res, maxchar_in, False, mapped);
}

impl do_lower(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    return do_upper_or_lower(kind, data, length, res, maxchar_in, True, mapped);
}

impl do_casefold(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    k: i64 = 0;
    for i in range(length) {
        c = ch_read(kind, data, i);
        n_res = _PyUnicode_ToFoldedFull(c, mapped);
        for j in range(i64(n_res)) {
            m = (mapped + j).view(1)[0];
            if m > maxchar {
                maxchar = m;
            }
            (res + k).view(1)[0] = m;
            k += 1;
        }
    }
    return (k, maxchar);
}

impl do_title(
    kind: i64,
    data: ptr[u8],
    length: i64,
    res: ptr[u32],
    maxchar_in: u32,
    mapped: ptr[u32]
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    k: i64 = 0;
    previous_is_cased = False;
    for i in range(length) {
        c = ch_read(kind, data, i);
        n_res = i32(0);
        if previous_is_cased {
            n_res = lower_ucs4(kind, data, length, i, c, mapped);
        } else {
            n_res = _PyUnicode_ToTitleFull(c, mapped);
        }
        for j in range(i64(n_res)) {
            m = (mapped + j).view(1)[0];
            if m > maxchar {
                maxchar = m;
            }
            (res + k).view(1)[0] = m;
            k += 1;
        }
        previous_is_cased = _PyUnicode_IsCased(c) != 0;
    }
    return (k, maxchar);
}

impl case_operation(self_: ptr[PyObject], which: i64) -> ptr[PyObject] {
    kind = uo_kind(self_);
    data = uo_data(self_);
    length = uo_length(self_);
    if length > PY_SSIZE_T_MAX // 12 {
        PyErr_SetString(PyExc_OverflowError, "string is too long");
        return NULL;
    }
    tmp = ptr[u32](PyMem_Malloc(u64(12 * length)));
    if not tmp {
        return PyErr_NoMemory();
    }

    mapped = ptr[u32](PyMem_Malloc(u64(12)));
    if not mapped {
        PyMem_Free(ptr(tmp));
        return PyErr_NoMemory();
    }
    newlength: i64 = 0;
    maxchar = u32(0);
    if which == DO_LOWER {
        (newlength, maxchar) = do_lower(kind, data, length, tmp, maxchar, mapped);
    } elif which == DO_UPPER {
        (newlength, maxchar) = do_upper(kind, data, length, tmp, maxchar, mapped);
    } elif which == DO_CASEFOLD {
        (newlength, maxchar) = do_casefold(kind, data, length, tmp, maxchar, mapped);
    } elif which == DO_TITLE {
        (newlength, maxchar) = do_title(kind, data, length, tmp, maxchar, mapped);
    } elif which == DO_CAPITALIZE {
        (newlength, maxchar) = do_capitalize(kind, data, length, tmp, maxchar, mapped);
    } else {
        (newlength, maxchar) = do_swapcase(kind, data, length, tmp, maxchar, mapped);
    }
    PyMem_Free(ptr(mapped));
    res = PyUnicode_New(newlength, maxchar);
    if res {
        outdata = uo_data(res);
        outkind = uo_kind(res);
        if outkind == PyUnicode_1BYTE_KIND {
            for i in range(newlength) {
                (outdata + i).view(1)[0] = u8.wrap((tmp + i).view(1)[0]);
            }
        } elif outkind == PyUnicode_2BYTE_KIND {
            out16 = ptr[u16](outdata);
            for i in range(newlength) {
                (out16 + i).view(1)[0] = u16.wrap((tmp + i).view(1)[0]);
            }
        } else {
            jacpy_memory_copy(ptr(outdata), ptr(tmp), 4 * newlength);
        }
    }
    PyMem_Free(ptr(tmp));
    return res;
}

impl sl_table_shift(table: ptr[u8], c: u32) -> i64 {
    return i64((table + i64(c & SL_TABLE_MASK)).view(1)[0]);
}

impl u2_at(s: ptr[u16], i: i64) -> u16 {
    return (s + i).view(1)[0];
}

impl u2_find_char(s: ptr[u16], n: i64, ch: u16) -> i64 {
    p: i64 = 0;
    e = n;
    if n > UCS2_MEMCHR_CUT_OFF {
        needle = ch & u16(0xff);
        if needle != u16(0) {
            while True {
                candidate = memchr(ptr(s + p), i32(needle), u64((e - p) * 2));
                if candidate.is_null() {
                    return -1;
                }
                s1 = p;

                p = i64(int(ptr[u8](candidate)) - int(ptr[u8](s))) // 2;
                if u2_at(s, p) == ch {
                    return p;
                }

                p += 1;
                if p - s1 <= UCS2_MEMCHR_CUT_OFF {
                    if e - p <= UCS2_MEMCHR_CUT_OFF {
                        break;
                    }
                    e1 = p + UCS2_MEMCHR_CUT_OFF;
                    while p != e1 {
                        if u2_at(s, p) == ch {
                            return p;
                        }
                        p += 1;
                    }
                }
                if e - p <= UCS2_MEMCHR_CUT_OFF {
                    break;
                }
            }
        }
    }
    while p < e {
        if u2_at(s, p) == ch {
            return p;
        }
        p += 1;
    }
    return -1;
}

impl u2_rfind_char(s: ptr[u16], n: i64, ch: u16) -> i64 {
    i = n;
    while i > 0 {
        i -= 1;
        if u2_at(s, i) == ch {
            return i;
        }
    }
    return -1;
}

impl u2_lex_search(
    needle: ptr[u16], len_needle: i64, invert_alphabet: bool
) -> tuple[i64, i64] {
    max_suffix: i64 = 0;
    candidate: i64 = 1;
    k: i64 = 0;

    period: i64 = 1;
    while candidate + k < len_needle {
        a = u2_at(needle, candidate + k);
        b = u2_at(needle, max_suffix + k);

        fell_short = (b < a) if invert_alphabet else (a < b);
        if fell_short {
            candidate += k + 1;
            k = 0;

            period = candidate - max_suffix;
        } elif a == b {
            if k + 1 != period {
                k += 1;
            } else {
                candidate += period;
                k = 0;
            }
        } else {
            max_suffix = candidate;
            candidate += 1;
            k = 0;
            period = 1;
        }
    }
    return (max_suffix, period);
}

impl u2_factorize(needle: ptr[u16], len_needle: i64) -> tuple[i64, i64] {
    (cut1, period1) = u2_lex_search(needle, len_needle, False);
    (cut2, period2) = u2_lex_search(needle, len_needle, True);

    if cut1 > cut2 {
        return (cut1, period1);
    }
    return (cut2, period2);
}

impl u2_preprocess(
    needle: ptr[u16], len_needle: i64, table: ptr[u8]
) -> tuple[i64, i64, i64, bool] {
    (cut, period) = u2_factorize(needle, len_needle);
    is_periodic = memcmp(ptr(needle), ptr(needle + period), u64(cut * 2)) == i32(0);
    if not is_periodic {
        period = (cut if cut > len_needle - cut else len_needle - cut) + 1;
    }

    gap = len_needle;
    last = u32(u2_at(needle, len_needle - 1)) & SL_TABLE_MASK;
    i = len_needle - 2;
    while i >= 0 {
        if (u32(u2_at(needle, i)) & SL_TABLE_MASK) == last {
            gap = len_needle - 1 - i;
            break;
        }
        i -= 1;
    }

    not_found_shift = len_needle if len_needle < SL_MAX_SHIFT else SL_MAX_SHIFT;
    for t in range(SL_TABLE_SIZE) {
        (table + t).view(1)[0] = u8(not_found_shift);
    }
    for j in range(len_needle - not_found_shift, len_needle) {
        slot = i64(u32(u2_at(needle, j)) & SL_TABLE_MASK);
        (table + slot).view(1)[0] = u8(len_needle - 1 - j);
    }
    return (cut, period, gap, is_periodic);
}

impl u2_two_way(
    haystack: ptr[u16],
    len_haystack: i64,
    needle: ptr[u16],
    len_needle: i64,
    cut: i64,
    period_in: i64,
    gap: i64,
    is_periodic: bool,
    table: ptr[u8]
) -> i64 {
    period = period_in;

    window_last: i64 = len_needle - 1;
    window: i64 = 0;
    shift: i64 = 0;
    i: i64 = 0;
    gap_jump_end = len_needle if len_needle < cut + gap else cut + gap;
    if is_periodic {
        memory: i64 = 0;
        horspool = True;
        while True {
            if horspool {
                if window_last >= len_haystack {
                    return -1;
                }
                while True {
                    shift = sl_table_shift(table, u32(u2_at(haystack, window_last)));
                    window_last += shift;
                    if shift == 0 {
                        break;
                    }
                    if window_last >= len_haystack {
                        return -1;
                    }
                }
            }
            horspool = True;
            window = window_last - len_needle + 1;
            i = cut if cut > memory else memory;
            right_matched = True;
            while i < len_needle {
                if u2_at(needle, i) != u2_at(haystack, window + i) {
                    if i < gap_jump_end {
                        window_last += gap;
                    } else {
                        window_last += i - cut + 1;
                    }
                    memory = 0;
                    right_matched = False;
                    break;
                }
                i += 1;
            }
            if not right_matched {
                continue;
            }
            left_matched = True;
            i = memory;
            while i < cut {
                if u2_at(needle, i) != u2_at(haystack, window + i) {
                    left_matched = False;
                    window_last += period;
                    memory = len_needle - period;
                    if window_last >= len_haystack {
                        return -1;
                    }
                    shift = sl_table_shift(table, u32(u2_at(haystack, window_last)));
                    if shift != 0 {
                        mem_jump = (cut if cut > memory else memory) - cut + 1;
                        memory = 0;
                        window_last += shift if shift > mem_jump else mem_jump;
                    } else {
                        horspool = False;
                    }
                    break;
                }
                i += 1;
            }
            if left_matched {
                return window;
            }
        }
    }
    period = gap if gap > period else period;
    while window_last < len_haystack {
        while True {
            shift = sl_table_shift(table, u32(u2_at(haystack, window_last)));
            window_last += shift;
            if shift == 0 {
                break;
            }
            if window_last >= len_haystack {
                return -1;
            }
        }
        window = window_last - len_needle + 1;
        i = cut;
        right_matched = True;
        while i < len_needle {
            if u2_at(needle, i) != u2_at(haystack, window + i) {
                if i < gap_jump_end {
                    window_last += gap;
                } else {
                    window_last += i - cut + 1;
                }
                right_matched = False;
                break;
            }
            i += 1;
        }
        if not right_matched {
            continue;
        }
        left_matched = True;
        i = 0;
        while i < cut {
            if u2_at(needle, i) != u2_at(haystack, window + i) {
                window_last += period;
                left_matched = False;
                break;
            }
            i += 1;
        }
        if left_matched {
            return window;
        }
    }
    return -1;
}

impl u2_two_way_find(
    haystack: ptr[u16], len_haystack: i64, needle: ptr[u16], len_needle: i64
) -> i64 {
    table = ptr[u8](PyMem_Malloc(u64(SL_TABLE_SIZE)));
    if not table {
        return u2_default_find(
            haystack, len_haystack, needle, len_needle, -1, FAST_SEARCH
        );
    }
    (cut, period, gap, is_periodic) = u2_preprocess(needle, len_needle, table);
    result = u2_two_way(
        haystack, len_haystack, needle, len_needle, cut, period, gap, is_periodic, table
    );
    PyMem_Free(ptr(table));
    return result;
}

impl u2_two_way_count(
    haystack: ptr[u16],
    len_haystack: i64,
    needle: ptr[u16],
    len_needle: i64,
    maxcount: i64
) -> i64 {
    table = ptr[u8](PyMem_Malloc(u64(SL_TABLE_SIZE)));
    if not table {
        return u2_default_find(
            haystack, len_haystack, needle, len_needle, maxcount, FAST_COUNT
        );
    }
    (cut, period, gap, is_periodic) = u2_preprocess(needle, len_needle, table);
    index: i64 = 0;
    count: i64 = 0;
    while True {
        result = u2_two_way(
            haystack + index,
            len_haystack - index,
            needle,
            len_needle,
            cut,
            period,
            gap,
            is_periodic,
            table
        );
        if result == -1 {
            break;
        }
        count += 1;
        if count == maxcount {
            break;
        }
        index += result + len_needle;
    }
    PyMem_Free(ptr(table));
    return count;
}

impl u2_default_find(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64 {
    w = n - m;
    mlast = m - 1;
    count: i64 = 0;
    gap = mlast;
    last = u2_at(p, mlast);
    ss = s + mlast;
    mask = u64(0);
    for k in range(mlast) {
        mask = bloom_add(mask, u32(u2_at(p, k)));
        if u2_at(p, k) == last {
            gap = mlast - k - 1;
        }
    }
    mask = bloom_add(mask, u32(last));
    i: i64 = 0;
    j: i64 = 0;
    while i <= w {
        if u2_at(ss, i) == last {
            j = 0;
            while j < mlast and u2_at(s, i + j) == u2_at(p, j) {
                j += 1;
            }
            if j == mlast {
                if mode != FAST_COUNT {
                    return i;
                }
                count += 1;
                if count == maxcount {
                    return maxcount;
                }
                i = i + mlast;
            } elif i + 1 <= w and not bloom(mask, u32(u2_at(ss, i + 1))) {
                i = i + m;
            } else {
                i = i + gap;
            }
        } elif i + 1 <= w and not bloom(mask, u32(u2_at(ss, i + 1))) {
            i = i + m;
        }
        i += 1;
    }
    return count if mode == FAST_COUNT else -1;
}

impl u2_adaptive_find(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64 {
    w = n - m;
    mlast = m - 1;
    count: i64 = 0;
    gap = mlast;
    hits: i64 = 0;
    last = u2_at(p, mlast);
    ss = s + mlast;
    mask = u64(0);
    for k in range(mlast) {
        mask = bloom_add(mask, u32(u2_at(p, k)));
        if u2_at(p, k) == last {
            gap = mlast - k - 1;
        }
    }
    mask = bloom_add(mask, u32(last));
    i: i64 = 0;
    j: i64 = 0;
    while i <= w {
        if u2_at(ss, i) == last {
            j = 0;
            while j < mlast and u2_at(s, i + j) == u2_at(p, j) {
                j += 1;
            }
            if j == mlast {
                if mode != FAST_COUNT {
                    return i;
                }
                count += 1;
                if count == maxcount {
                    return maxcount;
                }
                i = i + mlast;
            } else {
                hits += j + 1;
                if hits > m // 4 and w - i > 2000 {
                    if mode == FAST_SEARCH {
                        res = u2_two_way_find(s + i, n - i, p, m);
                        return -1 if res == -1 else res + i;
                    }
                    res = u2_two_way_count(s + i, n - i, p, m, maxcount - count);
                    return res + count;
                }
                if i + 1 <= w and not bloom(mask, u32(u2_at(ss, i + 1))) {
                    i = i + m;
                } else {
                    i = i + gap;
                }
            }
        } elif i + 1 <= w and not bloom(mask, u32(u2_at(ss, i + 1))) {
            i = i + m;
        }
        i += 1;
    }
    return count if mode == FAST_COUNT else -1;
}

impl u2_default_rfind(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64 {
    mlast = m - 1;
    rskip = m - 1;
    w = n - m;
    first = u2_at(p, 0);

    mask = bloom_add(u64(0), u32(first));

    i = mlast;
    while i > 0 {
        mask = bloom_add(mask, u32(u2_at(p, i)));
        if u2_at(p, i) == first {
            rskip = i - 1;
        }
        i -= 1;
    }
    j: i64 = 0;
    i = w;
    while i >= 0 {
        if u2_at(s, i) == first {
            j = mlast;
            while j > 0 and u2_at(s, i + j) == u2_at(p, j) {
                j -= 1;
            }
            if j == 0 {
                return i;
            }

            if i > 0 and not bloom(mask, u32(u2_at(s, i - 1))) {
                i = i - m;
            } else {
                i = i - rskip;
            }
        } elif i > 0 and not bloom(mask, u32(u2_at(s, i - 1))) {
            i = i - m;
        }
        i -= 1;
    }
    return -1;
}

impl u2_count_char(s: ptr[u16], n: i64, p0: u16, maxcount: i64) -> i64 {
    count: i64 = 0;
    for i in range(n) {
        if u2_at(s, i) == p0 {
            count += 1;
            if count == maxcount {
                return maxcount;
            }
        }
    }
    return count;
}

impl u2_count_char_no_maxcount(s: ptr[u16], n: i64, p0: u16) -> i64 {
    count: i64 = 0;
    for i in range(n) {
        if u2_at(s, i) == p0 {
            count += 1;
        }
    }
    return count;
}

impl u2_fastsearch(
    s: ptr[u16], n: i64, p: ptr[u16], m: i64, maxcount: i64, mode: i64
) -> i64 {
    if n < m or (mode == FAST_COUNT and maxcount == 0) {
        return -1;
    }

    if m <= 1 {
        if m <= 0 {
            return -1;
        }

        if mode == FAST_SEARCH {
            return u2_find_char(s, n, u2_at(p, 0));
        }
        if mode == FAST_RSEARCH {
            return u2_rfind_char(s, n, u2_at(p, 0));
        }
        if maxcount == PY_SSIZE_T_MAX {
            return u2_count_char_no_maxcount(s, n, u2_at(p, 0));
        }
        return u2_count_char(s, n, u2_at(p, 0), maxcount);
    }
    if mode != FAST_RSEARCH {
        if n < 2500 or (m < 100 and n < 30000) or m < 6 {
            return u2_default_find(s, n, p, m, maxcount, mode);
        }
        if (m >> 2) * 3 < (n >> 2) {
            if mode == FAST_SEARCH {
                return u2_two_way_find(s, n, p, m);
            }
            return u2_two_way_count(s, n, p, m, maxcount);
        }

        return u2_adaptive_find(s, n, p, m, maxcount, mode);
    }
    return u2_default_rfind(s, n, p, m, maxcount, mode);
}

impl u2_find_max_char(begin: ptr[u16], n: i64) -> u32 {
    mask_limit = MASK_UCS1;
    max_char_limit = MAX_CHAR_UCS2;
    p: i64 = 0;

    unrolled_end = n - n % 4;
    max_char = MAX_CHAR_ASCII;
    mask = MASK_ASCII;
    while p < unrolled_end {
        bits = u32(
            u2_at(begin, p)
                | u2_at(begin, p + 1)
                | u2_at(begin, p + 2)
                | u2_at(begin, p + 3)
        );
        if (bits & mask) != u32(0) {
            if mask == mask_limit {
                return max_char_limit;
            }
            if mask == MASK_ASCII {
                max_char = MAX_CHAR_UCS1;
                mask = MASK_UCS1;
            } else {
                max_char = MAX_CHAR_UCS2;
                mask = MASK_UCS2;
            }

            continue;
        }
        p += 4;
    }
    while p < n {
        if (u32(u2_at(begin, p)) & mask) != u32(0) {
            if mask == mask_limit {
                return max_char_limit;
            }
            if mask == MASK_ASCII {
                max_char = MAX_CHAR_UCS1;
                mask = MASK_UCS1;
            } else {
                max_char = MAX_CHAR_UCS2;
                mask = MASK_UCS2;
            }

            continue;
        }
        p += 1;
    }
    return max_char;
}

impl u4_at(s: ptr[u32], i: i64) -> u32 {
    return (s + i).view(1)[0];
}

impl u4_find_char(s: ptr[u32], n: i64, ch: u32) -> i64 {
    if n > UCS4_MEMCHR_CUT_OFF {
        found = wmemchr(ptr(s), i32(ch), u64(n));
        if found.is_null() {
            return -1;
        }
        return i64(int(ptr[u8](found)) - int(ptr[u8](s))) // 4;
    }
    i: i64 = 0;
    while i < n {
        if u4_at(s, i) == ch {
            return i;
        }
        i += 1;
    }
    return -1;
}

impl u4_rfind_char(s: ptr[u32], n: i64, ch: u32) -> i64 {
    i = n;
    while i > 0 {
        i -= 1;
        if u4_at(s, i) == ch {
            return i;
        }
    }
    return -1;
}

impl u4_lex_search(
    needle: ptr[u32], len_needle: i64, invert_alphabet: bool
) -> tuple[i64, i64] {
    max_suffix: i64 = 0;
    candidate: i64 = 1;
    k: i64 = 0;

    period: i64 = 1;
    while candidate + k < len_needle {
        a = u4_at(needle, candidate + k);
        b = u4_at(needle, max_suffix + k);

        fell_short = (b < a) if invert_alphabet else (a < b);
        if fell_short {
            candidate += k + 1;
            k = 0;

            period = candidate - max_suffix;
        } elif a == b {
            if k + 1 != period {
                k += 1;
            } else {
                candidate += period;
                k = 0;
            }
        } else {
            max_suffix = candidate;
            candidate += 1;
            k = 0;
            period = 1;
        }
    }
    return (max_suffix, period);
}

impl u4_factorize(needle: ptr[u32], len_needle: i64) -> tuple[i64, i64] {
    (cut1, period1) = u4_lex_search(needle, len_needle, False);
    (cut2, period2) = u4_lex_search(needle, len_needle, True);

    if cut1 > cut2 {
        return (cut1, period1);
    }
    return (cut2, period2);
}

impl u4_preprocess(
    needle: ptr[u32], len_needle: i64, table: ptr[u8]
) -> tuple[i64, i64, i64, bool] {
    (cut, period) = u4_factorize(needle, len_needle);
    is_periodic = memcmp(ptr(needle), ptr(needle + period), u64(cut * 4)) == i32(0);
    if not is_periodic {
        period = (cut if cut > len_needle - cut else len_needle - cut) + 1;
    }

    gap = len_needle;
    last = u4_at(needle, len_needle - 1) & SL_TABLE_MASK;
    i = len_needle - 2;
    while i >= 0 {
        if (u4_at(needle, i) & SL_TABLE_MASK) == last {
            gap = len_needle - 1 - i;
            break;
        }
        i -= 1;
    }

    not_found_shift = len_needle if len_needle < SL_MAX_SHIFT else SL_MAX_SHIFT;
    for t in range(SL_TABLE_SIZE) {
        (table + t).view(1)[0] = u8(not_found_shift);
    }
    for j in range(len_needle - not_found_shift, len_needle) {
        slot = i64(u4_at(needle, j) & SL_TABLE_MASK);
        (table + slot).view(1)[0] = u8(len_needle - 1 - j);
    }
    return (cut, period, gap, is_periodic);
}

impl u4_two_way(
    haystack: ptr[u32],
    len_haystack: i64,
    needle: ptr[u32],
    len_needle: i64,
    cut: i64,
    period_in: i64,
    gap: i64,
    is_periodic: bool,
    table: ptr[u8]
) -> i64 {
    period = period_in;

    window_last: i64 = len_needle - 1;
    window: i64 = 0;
    shift: i64 = 0;
    i: i64 = 0;
    gap_jump_end = len_needle if len_needle < cut + gap else cut + gap;
    if is_periodic {
        memory: i64 = 0;
        horspool = True;
        while True {
            if horspool {
                if window_last >= len_haystack {
                    return -1;
                }
                while True {
                    shift = sl_table_shift(table, u4_at(haystack, window_last));
                    window_last += shift;
                    if shift == 0 {
                        break;
                    }
                    if window_last >= len_haystack {
                        return -1;
                    }
                }
            }
            horspool = True;
            window = window_last - len_needle + 1;
            i = cut if cut > memory else memory;
            right_matched = True;
            while i < len_needle {
                if u4_at(needle, i) != u4_at(haystack, window + i) {
                    if i < gap_jump_end {
                        window_last += gap;
                    } else {
                        window_last += i - cut + 1;
                    }
                    memory = 0;
                    right_matched = False;
                    break;
                }
                i += 1;
            }
            if not right_matched {
                continue;
            }
            left_matched = True;
            i = memory;
            while i < cut {
                if u4_at(needle, i) != u4_at(haystack, window + i) {
                    left_matched = False;
                    window_last += period;
                    memory = len_needle - period;
                    if window_last >= len_haystack {
                        return -1;
                    }
                    shift = sl_table_shift(table, u4_at(haystack, window_last));
                    if shift != 0 {
                        mem_jump = (cut if cut > memory else memory) - cut + 1;
                        memory = 0;
                        window_last += shift if shift > mem_jump else mem_jump;
                    } else {
                        horspool = False;
                    }
                    break;
                }
                i += 1;
            }
            if left_matched {
                return window;
            }
        }
    }
    period = gap if gap > period else period;
    while window_last < len_haystack {
        while True {
            shift = sl_table_shift(table, u4_at(haystack, window_last));
            window_last += shift;
            if shift == 0 {
                break;
            }
            if window_last >= len_haystack {
                return -1;
            }
        }
        window = window_last - len_needle + 1;
        i = cut;
        right_matched = True;
        while i < len_needle {
            if u4_at(needle, i) != u4_at(haystack, window + i) {
                if i < gap_jump_end {
                    window_last += gap;
                } else {
                    window_last += i - cut + 1;
                }
                right_matched = False;
                break;
            }
            i += 1;
        }
        if not right_matched {
            continue;
        }
        left_matched = True;
        i = 0;
        while i < cut {
            if u4_at(needle, i) != u4_at(haystack, window + i) {
                window_last += period;
                left_matched = False;
                break;
            }
            i += 1;
        }
        if left_matched {
            return window;
        }
    }
    return -1;
}

impl u4_two_way_find(
    haystack: ptr[u32], len_haystack: i64, needle: ptr[u32], len_needle: i64
) -> i64 {
    table = ptr[u8](PyMem_Malloc(u64(SL_TABLE_SIZE)));
    if not table {
        return u4_default_find(
            haystack, len_haystack, needle, len_needle, -1, FAST_SEARCH
        );
    }
    (cut, period, gap, is_periodic) = u4_preprocess(needle, len_needle, table);
    result = u4_two_way(
        haystack, len_haystack, needle, len_needle, cut, period, gap, is_periodic, table
    );
    PyMem_Free(ptr(table));
    return result;
}

impl u4_two_way_count(
    haystack: ptr[u32],
    len_haystack: i64,
    needle: ptr[u32],
    len_needle: i64,
    maxcount: i64
) -> i64 {
    table = ptr[u8](PyMem_Malloc(u64(SL_TABLE_SIZE)));
    if not table {
        return u4_default_find(
            haystack, len_haystack, needle, len_needle, maxcount, FAST_COUNT
        );
    }
    (cut, period, gap, is_periodic) = u4_preprocess(needle, len_needle, table);
    index: i64 = 0;
    count: i64 = 0;
    while True {
        result = u4_two_way(
            haystack + index,
            len_haystack - index,
            needle,
            len_needle,
            cut,
            period,
            gap,
            is_periodic,
            table
        );
        if result == -1 {
            break;
        }
        count += 1;
        if count == maxcount {
            break;
        }
        index += result + len_needle;
    }
    PyMem_Free(ptr(table));
    return count;
}

impl u4_default_find(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64 {
    w = n - m;
    mlast = m - 1;
    count: i64 = 0;
    gap = mlast;
    last = u4_at(p, mlast);
    ss = s + mlast;
    mask = u64(0);
    for k in range(mlast) {
        mask = bloom_add(mask, u4_at(p, k));
        if u4_at(p, k) == last {
            gap = mlast - k - 1;
        }
    }
    mask = bloom_add(mask, last);
    i: i64 = 0;
    j: i64 = 0;
    while i <= w {
        if u4_at(ss, i) == last {
            j = 0;
            while j < mlast and u4_at(s, i + j) == u4_at(p, j) {
                j += 1;
            }
            if j == mlast {
                if mode != FAST_COUNT {
                    return i;
                }
                count += 1;
                if count == maxcount {
                    return maxcount;
                }
                i = i + mlast;
            } elif i + 1 <= w and not bloom(mask, u4_at(ss, i + 1)) {
                i = i + m;
            } else {
                i = i + gap;
            }
        } elif i + 1 <= w and not bloom(mask, u4_at(ss, i + 1)) {
            i = i + m;
        }
        i += 1;
    }
    return count if mode == FAST_COUNT else -1;
}

impl u4_adaptive_find(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64 {
    w = n - m;
    mlast = m - 1;
    count: i64 = 0;
    gap = mlast;
    hits: i64 = 0;
    last = u4_at(p, mlast);
    ss = s + mlast;
    mask = u64(0);
    for k in range(mlast) {
        mask = bloom_add(mask, u4_at(p, k));
        if u4_at(p, k) == last {
            gap = mlast - k - 1;
        }
    }
    mask = bloom_add(mask, last);
    i: i64 = 0;
    j: i64 = 0;
    while i <= w {
        if u4_at(ss, i) == last {
            j = 0;
            while j < mlast and u4_at(s, i + j) == u4_at(p, j) {
                j += 1;
            }
            if j == mlast {
                if mode != FAST_COUNT {
                    return i;
                }
                count += 1;
                if count == maxcount {
                    return maxcount;
                }
                i = i + mlast;
            } else {
                hits += j + 1;
                if hits > m // 4 and w - i > 2000 {
                    if mode == FAST_SEARCH {
                        res = u4_two_way_find(s + i, n - i, p, m);
                        return -1 if res == -1 else res + i;
                    }
                    res = u4_two_way_count(s + i, n - i, p, m, maxcount - count);
                    return res + count;
                }
                if i + 1 <= w and not bloom(mask, u4_at(ss, i + 1)) {
                    i = i + m;
                } else {
                    i = i + gap;
                }
            }
        } elif i + 1 <= w and not bloom(mask, u4_at(ss, i + 1)) {
            i = i + m;
        }
        i += 1;
    }
    return count if mode == FAST_COUNT else -1;
}

impl u4_default_rfind(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64 {
    mlast = m - 1;
    rskip = m - 1;
    w = n - m;
    first = u4_at(p, 0);

    mask = bloom_add(u64(0), first);

    i = mlast;
    while i > 0 {
        mask = bloom_add(mask, u4_at(p, i));
        if u4_at(p, i) == first {
            rskip = i - 1;
        }
        i -= 1;
    }
    j: i64 = 0;
    i = w;
    while i >= 0 {
        if u4_at(s, i) == first {
            j = mlast;
            while j > 0 and u4_at(s, i + j) == u4_at(p, j) {
                j -= 1;
            }
            if j == 0 {
                return i;
            }

            if i > 0 and not bloom(mask, u4_at(s, i - 1)) {
                i = i - m;
            } else {
                i = i - rskip;
            }
        } elif i > 0 and not bloom(mask, u4_at(s, i - 1)) {
            i = i - m;
        }
        i -= 1;
    }
    return -1;
}

impl u4_count_char(s: ptr[u32], n: i64, p0: u32, maxcount: i64) -> i64 {
    count: i64 = 0;
    for i in range(n) {
        if u4_at(s, i) == p0 {
            count += 1;
            if count == maxcount {
                return maxcount;
            }
        }
    }
    return count;
}

impl u4_count_char_no_maxcount(s: ptr[u32], n: i64, p0: u32) -> i64 {
    count: i64 = 0;
    for i in range(n) {
        if u4_at(s, i) == p0 {
            count += 1;
        }
    }
    return count;
}

impl u4_fastsearch(
    s: ptr[u32], n: i64, p: ptr[u32], m: i64, maxcount: i64, mode: i64
) -> i64 {
    if n < m or (mode == FAST_COUNT and maxcount == 0) {
        return -1;
    }

    if m <= 1 {
        if m <= 0 {
            return -1;
        }

        if mode == FAST_SEARCH {
            return u4_find_char(s, n, u4_at(p, 0));
        }
        if mode == FAST_RSEARCH {
            return u4_rfind_char(s, n, u4_at(p, 0));
        }
        if maxcount == PY_SSIZE_T_MAX {
            return u4_count_char_no_maxcount(s, n, u4_at(p, 0));
        }
        return u4_count_char(s, n, u4_at(p, 0), maxcount);
    }
    if mode != FAST_RSEARCH {
        if n < 2500 or (m < 100 and n < 30000) or m < 6 {
            return u4_default_find(s, n, p, m, maxcount, mode);
        }
        if (m >> 2) * 3 < (n >> 2) {
            if mode == FAST_SEARCH {
                return u4_two_way_find(s, n, p, m);
            }
            return u4_two_way_count(s, n, p, m, maxcount);
        }

        return u4_adaptive_find(s, n, p, m, maxcount, mode);
    }
    return u4_default_rfind(s, n, p, m, maxcount, mode);
}

impl u4_find_max_char(begin: ptr[u32], n: i64) -> u32 {
    mask_limit = MASK_UCS2;
    max_char_limit = MAX_CHAR_UCS4;
    p: i64 = 0;

    unrolled_end = n - n % 4;
    max_char = MAX_CHAR_ASCII;
    mask = MASK_ASCII;
    while p < unrolled_end {
        bits = u4_at(begin, p)
            | u4_at(begin, p + 1)
            | u4_at(begin, p + 2)
            | u4_at(begin, p + 3);
        if (bits & mask) != u32(0) {
            if mask == mask_limit {
                return max_char_limit;
            }
            if mask == MASK_ASCII {
                max_char = MAX_CHAR_UCS1;
                mask = MASK_UCS1;
            } else {
                max_char = MAX_CHAR_UCS2;
                mask = MASK_UCS2;
            }

            continue;
        }
        p += 4;
    }
    while p < n {
        if (u4_at(begin, p) & mask) != u32(0) {
            if mask == mask_limit {
                return max_char_limit;
            }
            if mask == MASK_ASCII {
                max_char = MAX_CHAR_UCS1;
                mask = MASK_UCS1;
            } else {
                max_char = MAX_CHAR_UCS2;
                mask = MASK_UCS2;
            }

            continue;
        }
        p += 1;
    }
    return max_char;
}

impl sl_find_char(kind: i64, s: ptr[u8], n: i64, ch: u32) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_find_char(s, n, u8.wrap(ch));
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u2_find_char(ptr[u16](s), n, u16.wrap(ch));
    }
    return u4_find_char(ptr[u32](s), n, ch);
}

impl sl_rfind_char(kind: i64, s: ptr[u8], n: i64, ch: u32) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_rfind_char(s, n, u8.wrap(ch));
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u2_rfind_char(ptr[u16](s), n, u16.wrap(ch));
    }
    return u4_rfind_char(ptr[u32](s), n, ch);
}

impl sl_fastsearch(
    kind: i64, s: ptr[u8], n: i64, p: ptr[u8], m: i64, maxcount: i64, mode: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_fastsearch(s, n, p, m, maxcount, mode);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u2_fastsearch(ptr[u16](s), n, ptr[u16](p), m, maxcount, mode);
    }
    return u4_fastsearch(ptr[u32](s), n, ptr[u32](p), m, maxcount, mode);
}

impl sl_find(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, offset: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_find(s, str_len, sub, sub_len, offset);
    }
    if sub_len == 0 {
        return offset;
    }
    pos = sl_fastsearch(kind, s, str_len, sub, sub_len, -1, FAST_SEARCH);
    if pos >= 0 {
        pos += offset;
    }
    return pos;
}

impl sl_rfind(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, offset: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_rfind(s, str_len, sub, sub_len, offset);
    }
    if sub_len == 0 {
        return str_len + offset;
    }
    pos = sl_fastsearch(kind, s, str_len, sub, sub_len, -1, FAST_RSEARCH);
    if pos >= 0 {
        pos += offset;
    }
    return pos;
}

impl sl_find_slice(
    kind: i64,
    s: ptr[u8],
    str_len: i64,
    sub: ptr[u8],
    sub_len: i64,
    start: i64,
    end: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_find_slice(s, str_len, sub, sub_len, start, end);
    }
    return sl_find(kind, char_ptr(s, kind, start), end - start, sub, sub_len, start);
}

impl sl_rfind_slice(
    kind: i64,
    s: ptr[u8],
    str_len: i64,
    sub: ptr[u8],
    sub_len: i64,
    start: i64,
    end: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_rfind_slice(s, str_len, sub, sub_len, start, end);
    }
    return sl_rfind(kind, char_ptr(s, kind, start), end - start, sub, sub_len, start);
}

impl sl_count(
    kind: i64, s: ptr[u8], str_len: i64, sub: ptr[u8], sub_len: i64, maxcount: i64
) -> i64 {
    if kind == PyUnicode_1BYTE_KIND {
        return bl_count(s, str_len, sub, sub_len, maxcount);
    }
    if str_len < 0 {
        return 0;
    }
    if sub_len == 0 {
        return str_len + 1 if str_len < maxcount else maxcount;
    }
    count = sl_fastsearch(kind, s, str_len, sub, sub_len, maxcount, FAST_COUNT);
    if count < 0 {
        return 0;
    }
    return count;
}

impl sl_find_max_char(kind: i64, s: ptr[u8], n: i64) -> u32 {
    if kind == PyUnicode_1BYTE_KIND {
        return u32(bl_find_max_char(s, s + n));
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u2_find_max_char(ptr[u16](s), n);
    }
    return u4_find_max_char(ptr[u32](s), n);
}

impl sl_prealloc_size(maxsplit: i64) -> i64 {
    return MAX_PREALLOC if maxsplit >= MAX_PREALLOC else maxsplit + 1;
}

impl sl_fix_prealloc_size(lst: ptr[PyObject], count: i64) {
    ptr[PyVarObject](lst).view(1)[0].ob_size = count;
}

impl sl_split_add(
    kind: i64,
    is_ascii: bool,
    lst: ptr[PyObject],
    count: i64,
    s: ptr[u8],
    left: i64,
    right: i64
) -> bool {
    sub = sl_new(kind, is_ascii, char_ptr(s, kind, left), right - left);
    if not sub {
        return False;
    }
    if count < MAX_PREALLOC {
        list_set_item(lst, count, sub);
        return True;
    }
    if PyList_Append(lst, sub) != i32(0) {
        object_decref(sub);
        return False;
    }
    object_decref(sub);
    return True;
}

impl sl_split_append(
    kind: i64, is_ascii: bool, lst: ptr[PyObject], s: ptr[u8], left: i64, right: i64
) -> bool {
    sub = sl_new(kind, is_ascii, char_ptr(s, kind, left), right - left);
    if not sub {
        return False;
    }
    if PyList_Append(lst, sub) != i32(0) {
        object_decref(sub);
        return False;
    }
    object_decref(sub);
    return True;
}

impl sl_split_failed(lst: ptr[PyObject]) -> ptr[PyObject] {
    object_decref(lst);
    return NULL;
}

impl sl_split_whitespace(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    i: i64 = 0;
    j: i64 = 0;
    while maxcount > 0 {
        maxcount -= 1;
        while i < str_len and uc_isspace(ch_read(kind, s, i)) {
            i += 1;
        }
        if i == str_len {
            break;
        }
        j = i;
        i += 1;
        while i < str_len and not uc_isspace(ch_read(kind, s, i)) {
            i += 1;
        }
        if j == 0 and i == str_len and unicode_check_exact(str_obj) {
            list_set_item(lst, 0, object_new_ref(str_obj));
            count += 1;
            break;
        }
        if not sl_split_add(kind, is_ascii, lst, count, s, j, i) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    if i < str_len {
        while i < str_len and uc_isspace(ch_read(kind, s, i)) {
            i += 1;
        }
        if i != str_len {
            if not sl_split_add(kind, is_ascii, lst, count, s, i, str_len) {
                return sl_split_failed(lst);
            }
            count += 1;
        }
    }
    sl_fix_prealloc_size(lst, count);
    return lst;
}

impl sl_split_char(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    ch: u32,
    maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    i: i64 = 0;
    j: i64 = 0;
    while j < str_len and maxcount > 0 {
        maxcount -= 1;
        pos = sl_find_char(kind, char_ptr(s, kind, j), str_len - j, ch);
        if pos < 0 {
            j = str_len;
        } else {
            j += pos;
            if not sl_split_add(kind, is_ascii, lst, count, s, i, j) {
                return sl_split_failed(lst);
            }
            count += 1;
            j = j + 1;
            i = j;
        }
    }
    if count == 0 and unicode_check_exact(str_obj) {
        list_set_item(lst, 0, object_new_ref(str_obj));
        count += 1;
    } elif i <= str_len {
        if not sl_split_add(kind, is_ascii, lst, count, s, i, str_len) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    sl_fix_prealloc_size(lst, count);
    return lst;
}

impl sl_split(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep: ptr[u8],
    sep_len: i64,
    maxcount_in: i64
) -> ptr[PyObject] {
    if sep_len == 0 {
        PyErr_SetString(PyExc_ValueError, "empty separator");
        return NULL;
    }
    if sep_len == 1 {
        return sl_split_char(
            str_obj, kind, is_ascii, s, str_len, ch_read(kind, sep, 0), maxcount_in
        );
    }
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    i: i64 = 0;
    j: i64 = 0;
    while maxcount > 0 {
        maxcount -= 1;
        pos = sl_fastsearch(
            kind, char_ptr(s, kind, i), str_len - i, sep, sep_len, -1, FAST_SEARCH
        );
        if pos < 0 {
            break;
        }
        j = i + pos;
        if not sl_split_add(kind, is_ascii, lst, count, s, i, j) {
            return sl_split_failed(lst);
        }
        count += 1;
        i = j + sep_len;
    }
    if count == 0 and unicode_check_exact(str_obj) {
        list_set_item(lst, 0, object_new_ref(str_obj));
        count += 1;
    } else {
        if not sl_split_add(kind, is_ascii, lst, count, s, i, str_len) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    sl_fix_prealloc_size(lst, count);
    return lst;
}

impl sl_rsplit_whitespace(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    i = str_len - 1;
    j = str_len - 1;
    while maxcount > 0 {
        maxcount -= 1;
        while i >= 0 and uc_isspace(ch_read(kind, s, i)) {
            i -= 1;
        }
        if i < 0 {
            break;
        }
        j = i;
        i -= 1;
        while i >= 0 and not uc_isspace(ch_read(kind, s, i)) {
            i -= 1;
        }
        if j == str_len - 1 and i < 0 and unicode_check_exact(str_obj) {
            list_set_item(lst, 0, object_new_ref(str_obj));
            count += 1;
            break;
        }
        if not sl_split_add(kind, is_ascii, lst, count, s, i + 1, j + 1) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    if i >= 0 {
        while i >= 0 and uc_isspace(ch_read(kind, s, i)) {
            i -= 1;
        }
        if i >= 0 {
            if not sl_split_add(kind, is_ascii, lst, count, s, 0, i + 1) {
                return sl_split_failed(lst);
            }
            count += 1;
        }
    }
    sl_fix_prealloc_size(lst, count);
    if PyList_Reverse(lst) < i32(0) {
        return sl_split_failed(lst);
    }
    return lst;
}

impl sl_rsplit_char(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    ch: u32,
    maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    i = str_len - 1;
    j = str_len - 1;
    while i >= 0 and maxcount > 0 {
        maxcount -= 1;
        pos = sl_rfind_char(kind, s, i + 1, ch);
        if pos < 0 {
            i = -1;
        } else {
            i = pos;
            if not sl_split_add(kind, is_ascii, lst, count, s, i + 1, j + 1) {
                return sl_split_failed(lst);
            }
            count += 1;
            i = i - 1;
            j = i;
        }
    }
    if count == 0 and unicode_check_exact(str_obj) {
        list_set_item(lst, 0, object_new_ref(str_obj));
        count += 1;
    } elif j >= -1 {
        if not sl_split_add(kind, is_ascii, lst, count, s, 0, j + 1) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    sl_fix_prealloc_size(lst, count);
    if PyList_Reverse(lst) < i32(0) {
        return sl_split_failed(lst);
    }
    return lst;
}

impl sl_rsplit(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep: ptr[u8],
    sep_len: i64,
    maxcount_in: i64
) -> ptr[PyObject] {
    if sep_len == 0 {
        PyErr_SetString(PyExc_ValueError, "empty separator");
        return NULL;
    }
    if sep_len == 1 {
        return sl_rsplit_char(
            str_obj, kind, is_ascii, s, str_len, ch_read(kind, sep, 0), maxcount_in
        );
    }
    maxcount = maxcount_in;
    count: i64 = 0;
    lst = PyList_New(sl_prealloc_size(maxcount));
    if not lst {
        return NULL;
    }
    j = str_len;
    while maxcount > 0 {
        maxcount -= 1;
        pos = sl_fastsearch(kind, s, j, sep, sep_len, -1, FAST_RSEARCH);
        if pos < 0 {
            break;
        }
        if not sl_split_add(kind, is_ascii, lst, count, s, pos + sep_len, j) {
            return sl_split_failed(lst);
        }
        count += 1;
        j = pos;
    }
    if count == 0 and unicode_check_exact(str_obj) {
        list_set_item(lst, 0, object_new_ref(str_obj));
        count += 1;
    } else {
        if not sl_split_add(kind, is_ascii, lst, count, s, 0, j) {
            return sl_split_failed(lst);
        }
        count += 1;
    }
    sl_fix_prealloc_size(lst, count);
    if PyList_Reverse(lst) < i32(0) {
        return sl_split_failed(lst);
    }
    return lst;
}

impl sl_splitlines(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    keepends: i32
) -> ptr[PyObject] {
    lst = PyList_New(0);
    if not lst {
        return NULL;
    }
    i: i64 = 0;
    j: i64 = 0;
    while i < str_len {
        while i < str_len and not bloom_is_linebreak(ch_read(kind, s, i)) {
            i += 1;
        }

        eol = i;
        if i < str_len {
            if ch_read(kind, s, i) == u32(13)
                and i + 1 < str_len
                and ch_read(kind, s, i + 1) == u32(10) {
                i += 2;
            } else {
                i += 1;
            }
            if keepends != i32(0) {
                eol = i;
            }
        }
        if j == 0 and eol == str_len and unicode_check_exact(str_obj) {
            if PyList_Append(lst, str_obj) != i32(0) {
                return sl_split_failed(lst);
            }
            break;
        }
        if not sl_split_append(kind, is_ascii, lst, s, j, eol) {
            return sl_split_failed(lst);
        }
        j = i;
    }
    return lst;
}

impl sl_partition_found(
    kind: i64,
    is_ascii: bool,
    out: ptr[PyObject],
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep_len: i64,
    pos: i64
) -> ptr[PyObject] {
    tuple_set_item(out, 0, sl_new(kind, is_ascii, s, pos));
    tuple_set_item(out, 1, object_new_ref(sep_obj));
    after = pos + sep_len;
    tuple_set_item(
        out, 2, sl_new(kind, is_ascii, char_ptr(s, kind, after), str_len - after)
    );
    if PyErr_Occurred() {
        object_decref(out);
        return NULL;
    }
    return out;
}

impl sl_partition(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep: ptr[u8],
    sep_len: i64
) -> ptr[PyObject] {
    if sep_len == 0 {
        PyErr_SetString(PyExc_ValueError, "empty separator");
        return NULL;
    }
    out = PyTuple_New(3);
    if not out {
        return NULL;
    }
    pos = sl_fastsearch(kind, s, str_len, sep, sep_len, -1, FAST_SEARCH);
    if pos < 0 {
        tuple_set_item(out, 0, object_new_ref(str_obj));
        tuple_set_item(out, 1, object_new_ref(unicode_get_empty()));
        tuple_set_item(out, 2, object_new_ref(unicode_get_empty()));
        return out;
    }
    return sl_partition_found(kind, is_ascii, out, s, str_len, sep_obj, sep_len, pos);
}

impl sl_rpartition(
    str_obj: ptr[PyObject],
    kind: i64,
    is_ascii: bool,
    s: ptr[u8],
    str_len: i64,
    sep_obj: ptr[PyObject],
    sep: ptr[u8],
    sep_len: i64
) -> ptr[PyObject] {
    if sep_len == 0 {
        PyErr_SetString(PyExc_ValueError, "empty separator");
        return NULL;
    }
    out = PyTuple_New(3);
    if not out {
        return NULL;
    }
    pos = sl_fastsearch(kind, s, str_len, sep, sep_len, -1, FAST_RSEARCH);
    if pos < 0 {
        tuple_set_item(out, 0, object_new_ref(unicode_get_empty()));
        tuple_set_item(out, 1, object_new_ref(unicode_get_empty()));
        tuple_set_item(out, 2, object_new_ref(str_obj));
        return out;
    }
    return sl_partition_found(kind, is_ascii, out, s, str_len, sep_obj, sep_len, pos);
}

impl sl_replace_1char_inplace(
    kind: i64, data: ptr[u8], start: i64, end: i64, u1: u32, u2: u32, maxcount_in: i64
) {
    s = start;
    maxcount = maxcount_in;
    found: i64 = -1;
    ch_write(kind, data, s, u2);
    while True {
        maxcount -= 1;
        if maxcount == 0 {
            return;
        }
        s += 1;
        if s == end {
            return;
        }
        if ch_read(kind, data, s) != u1 {
            attempts = 10;

            while True {
                s += 1;
                if s == end {
                    return;
                }
                if ch_read(kind, data, s) == u1 {
                    break;
                }
                attempts -= 1;
                if attempts == 0 {
                    s += 1;
                    found = -1;
                    if kind == PyUnicode_1BYTE_KIND {
                        hit = memchr(ptr(data + s), i32(u1), u64(end - s));
                        if hit {
                            found = int(hit) - int(data + s);
                        }
                    } elif kind == PyUnicode_4BYTE_KIND {
                        at = char_ptr(data, kind, s);
                        hit4 = wmemchr(ptr(at), i32(u1), u64(end - s));
                        if hit4 {
                            found = (int(hit4) - int(at)) // 4;
                        }
                    } else {
                        found = sl_find_char(
                            kind, char_ptr(data, kind, s), end - s, u1
                        );
                    }
                    if found < 0 {
                        return;
                    }
                    s += found;

                    break;
                }
            }
        }
        ch_write(kind, data, s, u2);
    }
}

impl pad(
    self_: ptr[PyObject], left_in: i64, right_in: i64, fill: u32
) -> ptr[PyObject] {
    left = left_in;
    right = right_in;
    if left < 0 {
        left = 0;
    }
    if right < 0 {
        right = 0;
    }
    if left == 0 and right == 0 {
        return unicode_result_unchanged(self_);
    }
    length = uo_length(self_);
    if left > PY_SSIZE_T_MAX - length or right > PY_SSIZE_T_MAX - (left + length) {
        PyErr_SetString(PyExc_OverflowError, "padded string is too long");
        return NULL;
    }
    maxchar = uo_max_char_value(self_);
    if fill > maxchar {
        maxchar = fill;
    }
    u = PyUnicode_New(left + length + right, maxchar);
    if not u {
        return NULL;
    }
    kind = uo_kind(u);
    data = uo_data(u);
    if left != 0 {
        unicode_fill(kind, data, fill, 0, left);
    }
    if right != 0 {
        unicode_fill(kind, data, fill, left + length, right);
    }
    _PyUnicode_FastCopyCharacters(u, left, self_, 0, length);
    return u;
}

impl split(
    self_: ptr[PyObject], substring: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    len1 = uo_length(self_);
    kind1 = uo_kind(self_);
    if not substring {
        if maxcount < 0 {
            maxcount = 1;
            if len1 > 0 {
                maxcount = (len1 - 1) // 2 + 1;
            }
        }
        return sl_split_whitespace(
            self_, kind1, uo_is_ascii(self_), uo_data(self_), len1, maxcount
        );
    }
    kind2 = uo_kind(substring);
    len2 = uo_length(substring);
    if maxcount < 0 {
        maxcount = 0;
        if len2 != 0 {
            maxcount = wrapping_add(len1 // len2, 1);
        }

        if maxcount < 0 {
            maxcount = len1;
        }
    }
    if kind1 < kind2 or len1 < len2 {
        out = PyList_New(1);
        if not out {
            return NULL;
        }
        list_set_item(out, 0, object_new_ref(self_));
        return out;
    }
    buf1 = uo_data(self_);
    buf2 = uo_data(substring);
    if kind2 != kind1 {
        buf2 = unicode_askind(kind2, buf2, len2, kind1);
        if not buf2 {
            return NULL;
        }
    }

    is_ascii = uo_is_ascii(self_) and uo_is_ascii(substring);
    out = sl_split(self_, kind1, is_ascii, buf1, len1, buf2, len2, maxcount);
    if kind2 != kind1 {
        PyMem_Free(ptr(buf2));
    }
    return out;
}

impl rsplit(
    self_: ptr[PyObject], substring: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject] {
    maxcount = maxcount_in;
    len1 = uo_length(self_);
    kind1 = uo_kind(self_);
    if not substring {
        if maxcount < 0 {
            maxcount = 1;
            if len1 > 0 {
                maxcount = (len1 - 1) // 2 + 1;
            }
        }
        return sl_rsplit_whitespace(
            self_, kind1, uo_is_ascii(self_), uo_data(self_), len1, maxcount
        );
    }
    kind2 = uo_kind(substring);
    len2 = uo_length(substring);
    if maxcount < 0 {
        maxcount = 0;
        if len2 != 0 {
            maxcount = wrapping_add(len1 // len2, 1);
        }

        if maxcount < 0 {
            maxcount = len1;
        }
    }
    if kind1 < kind2 or len1 < len2 {
        out = PyList_New(1);
        if not out {
            return NULL;
        }
        list_set_item(out, 0, object_new_ref(self_));
        return out;
    }
    buf1 = uo_data(self_);
    buf2 = uo_data(substring);
    if kind2 != kind1 {
        buf2 = unicode_askind(kind2, buf2, len2, kind1);
        if not buf2 {
            return NULL;
        }
    }
    is_ascii = uo_is_ascii(self_) and uo_is_ascii(substring);
    out = sl_rsplit(self_, kind1, is_ascii, buf1, len1, buf2, len2, maxcount);
    if kind2 != kind1 {
        PyMem_Free(ptr(buf2));
    }
    return out;
}

impl anylib_find(
    kind: i64,
    str1: ptr[PyObject],
    buf1: ptr[u8],
    len1: i64,
    str2: ptr[PyObject],
    buf2: ptr[u8],
    len2: i64,
    offset: i64
) -> i64 {
    return sl_find(kind, buf1, len1, buf2, len2, offset);
}

impl anylib_count(
    kind: i64,
    sstr: ptr[PyObject],
    sbuf: ptr[u8],
    slen: i64,
    str1: ptr[PyObject],
    buf1: ptr[u8],
    len1: i64,
    maxcount: i64
) -> i64 {
    return sl_count(kind, sbuf, slen, buf1, len1, maxcount);
}

impl replace_1char_inplace(
    u: ptr[PyObject], pos: i64, u1: u32, u2: u32, maxcount: i64
) {
    sl_replace_1char_inplace(
        uo_kind(u), uo_data(u), pos, uo_length(u), u1, u2, maxcount
    );
}

impl replace_release(
    srelease: bool,
    sbuf: ptr[u8],
    release1: bool,
    buf1: ptr[u8],
    release2: bool,
    buf2: ptr[u8]
) {
    if srelease {
        PyMem_Free(ptr(sbuf));
    }
    if release1 {
        PyMem_Free(ptr(buf1));
    }
    if release2 {
        PyMem_Free(ptr(buf2));
    }
}

impl replace(
    self_: ptr[PyObject], str1: ptr[PyObject], str2: ptr[PyObject], maxcount_in: i64
) -> ptr[PyObject] {
    sbuf = uo_data(self_);
    buf1 = uo_data(str1);
    buf2 = uo_data(str2);
    srelease = False;
    release1 = False;
    release2 = False;
    skind = uo_kind(self_);
    kind1 = uo_kind(str1);
    kind2 = uo_kind(str2);
    slen = uo_length(self_);
    len1 = uo_length(str1);
    len2 = uo_length(str2);
    maxcount = maxcount_in;

    if slen < len1 {
        return unicode_result_unchanged(self_);
    }
    if maxcount < 0 {
        maxcount = PY_SSIZE_T_MAX;
    } elif maxcount == 0 {
        return unicode_result_unchanged(self_);
    }
    if str1 == str2 {
        return unicode_result_unchanged(self_);
    }
    maxchar = uo_max_char_value(self_);
    maxchar_str1 = uo_max_char_value(str1);
    if maxchar < maxchar_str1 {
        return unicode_result_unchanged(self_);
    }
    maxchar_str2 = uo_max_char_value(str2);

    mayshrink = maxchar_str2 < maxchar_str1 and maxchar == maxchar_str1;
    if maxchar_str2 > maxchar {
        maxchar = maxchar_str2;
    }
    u = NULL;
    rkind = skind;
    i: i64 = 0;
    if len1 == len2 {
        if len1 == 0 {
            return unicode_result_unchanged(self_);
        }
        if len1 == 1 {
            u1 = ch_read(kind1, buf1, 0);
            pos = findchar(sbuf, skind, slen, u1, i32(1));
            if pos < 0 {
                return unicode_result_unchanged(self_);
            }
            u2 = ch_read(kind2, buf2, 0);
            u = PyUnicode_New(slen, maxchar);
            if not u {
                return NULL;
            }
            _PyUnicode_FastCopyCharacters(u, 0, self_, 0, slen);
            replace_1char_inplace(u, pos, u1, u2, maxcount);
        } else {
            if kind1 < rkind {
                buf1 = unicode_askind(kind1, buf1, len1, rkind);
                if not buf1 {
                    return NULL;
                }
                release1 = True;
            }
            i = anylib_find(rkind, self_, sbuf, slen, str1, buf1, len1, 0);
            if i < 0 {
                replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                return unicode_result_unchanged(self_);
            }
            if rkind > kind2 {
                buf2 = unicode_askind(kind2, buf2, len2, rkind);
                if not buf2 {
                    replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                    return NULL;
                }
                release2 = True;
            } elif rkind < kind2 {
                rkind = kind2;
                if release1 {
                    PyMem_Free(ptr(buf1));
                    buf1 = uo_data(str1);
                    release1 = False;
                }
                sbuf = unicode_askind(skind, sbuf, slen, rkind);
                if not sbuf {
                    replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                    return NULL;
                }
                srelease = True;
                buf1 = unicode_askind(kind1, buf1, len1, rkind);
                if not buf1 {
                    replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                    return NULL;
                }
                release1 = True;
            }
            u = PyUnicode_New(slen, maxchar);
            if not u {
                replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                return NULL;
            }
            res = uo_data(u);
            memcpy(ptr(res), ptr(sbuf), u64(rkind * slen));
            memcpy(ptr(res + rkind * i), ptr(buf2), u64(rkind * len2));
            i += len1;
            while True {
                maxcount -= 1;
                if maxcount <= 0 {
                    break;
                }
                i = anylib_find(
                    rkind,
                    self_,
                    char_ptr(sbuf, rkind, i),
                    slen - i,
                    str1,
                    buf1,
                    len1,
                    i
                );
                if i == -1 {
                    break;
                }
                memcpy(ptr(res + rkind * i), ptr(buf2), u64(rkind * len2));
                i += len1;
            }
        }
    } else {
        if kind1 < rkind {
            buf1 = unicode_askind(kind1, buf1, len1, rkind);
            if not buf1 {
                return NULL;
            }
            release1 = True;
        }
        n = anylib_count(rkind, self_, sbuf, slen, str1, buf1, len1, maxcount);
        if n == 0 {
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return unicode_result_unchanged(self_);
        }
        if kind2 < rkind {
            buf2 = unicode_askind(kind2, buf2, len2, rkind);
            if not buf2 {
                replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                return NULL;
            }
            release2 = True;
        } elif kind2 > rkind {
            rkind = kind2;
            sbuf = unicode_askind(skind, sbuf, slen, rkind);
            if not sbuf {
                replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                return NULL;
            }
            srelease = True;
            if release1 {
                PyMem_Free(ptr(buf1));
                buf1 = uo_data(str1);
                release1 = False;
            }
            buf1 = unicode_askind(kind1, buf1, len1, rkind);
            if not buf1 {
                replace_release(srelease, sbuf, release1, buf1, release2, buf2);
                return NULL;
            }
            release1 = True;
        }
        if len1 < len2 and len2 - len1 > (PY_SSIZE_T_MAX - slen) // n {
            PyErr_SetString(PyExc_OverflowError, "replace string is too long");
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return NULL;
        }
        new_size = slen + n * (len2 - len1);
        if new_size == 0 {
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return unicode_get_empty();
        }
        if new_size > PY_SSIZE_T_MAX // rkind {
            PyErr_SetString(PyExc_OverflowError, "replace string is too long");
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return NULL;
        }
        u = PyUnicode_New(new_size, maxchar);
        if not u {
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return NULL;
        }
        res = uo_data(u);
        ires: i64 = 0;
        i = 0;
        if len1 > 0 {
            while n > 0 {
                n -= 1;

                j = anylib_find(
                    rkind,
                    self_,
                    char_ptr(sbuf, rkind, i),
                    slen - i,
                    str1,
                    buf1,
                    len1,
                    i
                );
                if j == -1 {
                    break;
                } elif j > i {
                    memcpy(
                        ptr(res + rkind * ires),
                        ptr(char_ptr(sbuf, rkind, i)),
                        u64(rkind * (j - i))
                    );
                    ires += j - i;
                }

                if len2 > 0 {
                    memcpy(ptr(res + rkind * ires), ptr(buf2), u64(rkind * len2));
                    ires += len2;
                }
                i = j + len1;
            }
            if i < slen {
                memcpy(
                    ptr(res + rkind * ires),
                    ptr(char_ptr(sbuf, rkind, i)),
                    u64(rkind * (slen - i))
                );
            }
        } else {
            while n > 0 {
                memcpy(ptr(res + rkind * ires), ptr(buf2), u64(rkind * len2));
                ires += len2;
                n -= 1;
                if n <= 0 {
                    break;
                }
                memcpy(
                    ptr(res + rkind * ires), ptr(char_ptr(sbuf, rkind, i)), u64(rkind)
                );
                ires += 1;
                i += 1;
            }
            memcpy(
                ptr(res + rkind * ires),
                ptr(char_ptr(sbuf, rkind, i)),
                u64(rkind * (slen - i))
            );
        }
    }
    if mayshrink {
        u = unicode_adjust_maxchar(u);
        if not u {
            replace_release(srelease, sbuf, release1, buf1, release2, buf2);
            return NULL;
        }
    }
    replace_release(srelease, sbuf, release1, buf1, release2, buf2);
    return u;
}

impl clinic_ssize_arg(value: ptr[PyObject]) -> tuple[bool, i64] {
    ival: i64 = -1;
    iobj = _PyNumber_Index(value);
    if iobj {
        ival = PyLong_AsSsize_t(iobj);
        object_decref(iobj);
    }
    if ival == -1 and PyErr_Occurred() {
        return (False, ival);
    }
    return (True, ival);
}

impl clinic_slice_bounds(
    args: ptr[ptr[PyObject]], nargs: i64
) -> tuple[bool, i64, i64] {
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return (False, start, end);
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return (False, start, end);
    }
    return (True, start, end);
}

impl unicode_title_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return case_operation(self_, DO_TITLE);
}

impl unicode_title(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_title_impl(self_);
}

impl unicode_capitalize_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if uo_length(self_) == 0 {
        return unicode_result_unchanged(self_);
    }
    return case_operation(self_, DO_CAPITALIZE);
}

impl unicode_capitalize(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_capitalize_impl(self_);
}

impl unicode_casefold_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if uo_is_ascii(self_) {
        return ascii_upper_or_lower(self_, True);
    }
    return case_operation(self_, DO_CASEFOLD);
}

impl unicode_casefold(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_casefold_impl(self_);
}

impl convert_uc(obj_: ptr[PyObject]) -> tuple[bool, u32] {
    if not unicode_check(obj_) {
        PyErr_Format(
            PyExc_TypeError,
            "The fill character must be a unicode character, not %.100s",
            object_type(obj_).view(1)[0].tp_name
        );
        return (False, u32(0));
    }
    if uo_length(obj_) != 1 {
        PyErr_SetString(
            PyExc_TypeError, "The fill character must be exactly one character long"
        );
        return (False, u32(0));
    }
    return (True, uo_read_char(obj_, 0));
}

impl unicode_center_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject] {
    length = uo_length(self_);
    if length >= width {
        return unicode_result_unchanged(self_);
    }
    marg = width - length;
    left = marg // 2 + (marg & width & 1);
    return pad(self_, left, marg - left, fillchar);
}

impl unicode_center(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and _PyArg_CheckPositional(ptr[u8]("center"), nargs, 1, 2) == i32(0) {
        return NULL;
    }
    (ok, width) = clinic_ssize_arg(args.view(1)[0]);
    if not ok {
        return NULL;
    }
    fillchar = u32(32);
    if nargs >= 2 {
        (converted, fillchar) = convert_uc((args + 1).view(1)[0]);
        if not converted {
            return NULL;
        }
    }
    return unicode_center_impl(self_, width, fillchar);
}

impl unicode_compare(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32 {
    kind1 = uo_kind(str1);
    kind2 = uo_kind(str2);
    data1 = uo_data(str1);
    data2 = uo_data(str2);
    len1 = uo_length(str1);
    len2 = uo_length(str2);
    n = len1 if len1 < len2 else len2;
    if kind1 == PyUnicode_1BYTE_KIND and kind2 == PyUnicode_1BYTE_KIND {
        cmp = memcmp(ptr(data1), ptr(data2), u64(n));

        if cmp < i32(0) {
            return i32(-1);
        }
        if cmp > i32(0) {
            return i32(1);
        }
    } elif kind1 == PyUnicode_4BYTE_KIND and kind2 == PyUnicode_4BYTE_KIND {
        wcmp = wmemcmp(ptr[i32](data1), ptr[i32](data2), u64(n));
        if wcmp < i32(0) {
            return i32(-1);
        }
        if wcmp > i32(0) {
            return i32(1);
        }
    } elif kind1 == PyUnicode_2BYTE_KIND and kind2 == PyUnicode_2BYTE_KIND {
        p1 = ptr[u16](data1);
        p2 = ptr[u16](data2);
        for i in range(n) {
            u1 = (p1 + i).view(1)[0];
            u2 = (p2 + i).view(1)[0];
            if u1 != u2 {
                return i32(-1) if u1 < u2 else i32(1);
            }
        }
    } else {
        for k in range(n) {
            c1 = ch_read(kind1, data1, k);
            c2 = ch_read(kind2, data2, k);
            if c1 != c2 {
                return i32(-1) if c1 < c2 else i32(1);
            }
        }
    }
    if len1 == len2 {
        return i32(0);
    }
    if len1 < len2 {
        return i32(-1);
    }
    return i32(1);
}

impl append_clear(p_left: ptr[ptr[PyObject]]) {
    old = p_left.view(1)[0];
    p_left.view(1)[0] = NULL;
    object_xdecref(old);
}

impl unicode_count_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start_in: i64, end_in: i64
) -> i64 {
    kind1 = uo_kind(str_obj);
    kind2 = uo_kind(substr);
    if kind1 < kind2 {
        return 0;
    }
    len1 = uo_length(str_obj);
    len2 = uo_length(substr);
    start = start_in;
    end = end_in;

    if end > len1 {
        end = len1;
    } elif end < 0 {
        end += len1;
        if end < 0 {
            end = 0;
        }
    }
    if start < 0 {
        start += len1;
        if start < 0 {
            start = 0;
        }
    }
    if end - start < len2 {
        return 0;
    }
    buf1 = uo_data(str_obj);
    buf2 = uo_data(substr);
    if kind2 != kind1 {
        buf2 = unicode_askind(kind2, buf2, len2, kind1);
        if not buf2 {
            return -1;
        }
    }
    result = sl_count(
        kind1, char_ptr(buf1, kind1, start), end - start, buf2, len2, PY_SSIZE_T_MAX
    );
    if kind2 != kind1 {
        PyMem_Free(ptr(buf2));
    }
    return result;
}

impl unicode_count(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("count"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    substr = args.view(1)[0];
    if not unicode_check(substr) {
        _PyArg_BadArgument(
            ptr[u8]("count"), ptr[u8]("argument 1"), ptr[u8]("str"), substr
        );
        return NULL;
    }
    (ok, start, end) = clinic_slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    result = unicode_count_impl(str_obj, substr, start, end);
    if result == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(result);
}

impl unicode_encode_impl(
    self_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    return PyUnicode_AsEncodedString(self_, encoding, errors);
}

impl encode_text_arg(value: ptr[PyObject], is_errors: bool) -> tuple[bool, ptr[u8]] {
    if not unicode_check(value) {
        if is_errors {
            _PyArg_BadArgument(
                ptr[u8]("encode"), ptr[u8]("argument 'errors'"), ptr[u8]("str"), value
            );
        } else {
            _PyArg_BadArgument(
                ptr[u8]("encode"), ptr[u8]("argument 'encoding'"), ptr[u8]("str"), value
            );
        }
        return (False, ptr[u8]());
    }
    (text, length) = unicode_as_utf8_and_size(value);
    if not text {
        return (False, text);
    }
    if i64(strlen(text)) != length {
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        return (False, ptr[u8]());
    }
    return (True, text);
}

impl unicode_encode_with(
    self_: ptr[PyObject], encoding_obj: ptr[PyObject], errors_obj: ptr[PyObject]
) -> ptr[PyObject] {
    encoding = ptr[u8]();
    errors = ptr[u8]();
    if encoding_obj {
        (ok, encoding) = encode_text_arg(encoding_obj, False);
        if not ok {
            return NULL;
        }
    }
    if errors_obj {
        (ok2, errors) = encode_text_arg(errors_obj, True);
        if not ok2 {
            return NULL;
        }
    }
    return unicode_encode_impl(self_, encoding, errors);
}

impl unicode_encode_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_encode_with(args.context, args.values[0], args.values[1]);
}

impl unicode_encode(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return unicode_encode_with(
            self_,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL
        );
    }
    return invoke_vector(
        unicode_encode_signature, args, nargs, kwnames, unicode_encode_bound, self_
    );
}

impl unicode_expandtabs_impl(self_: ptr[PyObject], tabsize_in: i32) -> ptr[PyObject] {
    tabsize = i64(tabsize_in);

    src_len = uo_length(self_);
    j: i64 = 0;
    line_pos: i64 = 0;
    incr: i64 = 0;
    kind = uo_kind(self_);
    src_data = uo_data(self_);
    found = False;
    for i in range(src_len) {
        ch = ch_read(kind, src_data, i);
        if ch == u32(9) {
            found = True;
            if tabsize > 0 {
                incr = tabsize - (line_pos % tabsize);
                if j > PY_SSIZE_T_MAX - incr {
                    PyErr_SetString(PyExc_OverflowError, "new string is too long");
                    return NULL;
                }
                line_pos += incr;
                j += incr;
            }
        } else {
            if j > PY_SSIZE_T_MAX - 1 {
                PyErr_SetString(PyExc_OverflowError, "new string is too long");
                return NULL;
            }
            line_pos += 1;
            j += 1;
            if ch == u32(10) or ch == u32(13) {
                line_pos = 0;
            }
        }
    }
    if not found {
        return unicode_result_unchanged(self_);
    }

    u = PyUnicode_New(j, uo_max_char_value(self_));
    if not u {
        return NULL;
    }
    dest_data = uo_data(u);
    j = 0;
    line_pos = 0;
    for k in range(src_len) {
        c = ch_read(kind, src_data, k);
        if c == u32(9) {
            if tabsize > 0 {
                incr = tabsize - (line_pos % tabsize);
                line_pos += incr;
                unicode_fill(kind, dest_data, u32(32), j, incr);
                j += incr;
            }
        } else {
            line_pos += 1;
            ch_write(kind, dest_data, j, c);
            j += 1;
            if c == u32(10) or c == u32(13) {
                line_pos = 0;
            }
        }
    }
    return unicode_result(u);
}

impl unicode_expandtabs_with(
    self_: ptr[PyObject], tabsize_obj: ptr[PyObject]
) -> ptr[PyObject] {
    tabsize = i32(8);
    if tabsize_obj {
        tabsize = PyLong_AsInt(tabsize_obj);
        if tabsize == i32(-1) and PyErr_Occurred() {
            return NULL;
        }
    }
    return unicode_expandtabs_impl(self_, tabsize);
}

impl unicode_expandtabs_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_expandtabs_with(args.context, args.values[0]);
}

impl unicode_expandtabs(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 1 {
        return unicode_expandtabs_with(self_, args.view(1)[0] if nargs >= 1 else NULL);
    }
    return invoke_vector(
        unicode_expandtabs_signature,
        args,
        nargs,
        kwnames,
        unicode_expandtabs_bound,
        self_
    );
}

impl unicode_find_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64 {
    result = any_find_slice(str_obj, substr, start, end, i32(1));
    if result < 0 {
        return -1;
    }
    return result;
}

impl unicode_find(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("find"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    substr = args.view(1)[0];
    if not unicode_check(substr) {
        _PyArg_BadArgument(
            ptr[u8]("find"), ptr[u8]("argument 1"), ptr[u8]("str"), substr
        );
        return NULL;
    }
    (ok, start, end) = clinic_slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    result = unicode_find_impl(str_obj, substr, start, end);
    if result == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(result);
}

impl unicode_getitem(self_: ptr[PyObject], index: i64) -> ptr[PyObject] {
    if not unicode_check(self_) {
        PyErr_BadArgument();
        return NULL;
    }
    if index < 0 or index >= uo_length(self_) {
        PyErr_SetString(PyExc_IndexError, "string index out of range");
        return NULL;
    }
    ch = ch_read(uo_kind(self_), uo_data(self_), index);
    return unicode_char(ch);
}

impl unicode_hash(self_: ptr[PyObject]) -> i64 {
    cached = uo_hash(self_);
    if cached != -1 {
        return cached;
    }
    x = Py_HashBuffer(ptr(uo_data(self_)), uo_length(self_) * uo_kind(self_));
    uo_set_hash(self_, x);
    return x;
}

impl unicode_index_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64 {
    result = any_find_slice(str_obj, substr, start, end, i32(1));
    if result == -1 {
        PyErr_SetString(PyExc_ValueError, "substring not found");
    } elif result < 0 {
        return -1;
    }
    return result;
}

impl unicode_index(
    str_obj: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("index"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    substr = args.view(1)[0];
    if not unicode_check(substr) {
        _PyArg_BadArgument(
            ptr[u8]("index"), ptr[u8]("argument 1"), ptr[u8]("str"), substr
        );
        return NULL;
    }
    (ok, start, end) = clinic_slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    result = unicode_index_impl(str_obj, substr, start, end);
    if result == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(result);
}

impl unicode_isascii_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(1 if uo_is_ascii(self_) else 0);
}

impl unicode_isascii(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isascii_impl(self_);
}

impl unicode_islower_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_islower(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    cased = False;
    for i in range(length) {
        ch = ch_read(kind, data, i);
        if uc_isupper(ch) or uc_istitle(ch) {
            return PyBool_FromLong(0);
        } elif not cased and uc_islower(ch) {
            cased = True;
        }
    }
    return PyBool_FromLong(1 if cased else 0);
}

impl unicode_islower(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_islower_impl(self_);
}

impl unicode_isupper_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isupper(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    cased = False;
    for i in range(length) {
        ch = ch_read(kind, data, i);
        if uc_islower(ch) or uc_istitle(ch) {
            return PyBool_FromLong(0);
        } elif not cased and uc_isupper(ch) {
            cased = True;
        }
    }
    return PyBool_FromLong(1 if cased else 0);
}

impl unicode_isupper(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isupper_impl(self_);
}

impl unicode_istitle_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        first = ch_read(kind, data, 0);
        return PyBool_FromLong(1 if uc_istitle(first) or uc_isupper(first) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    cased = False;
    previous_is_cased = False;
    for i in range(length) {
        ch = ch_read(kind, data, i);
        if uc_isupper(ch) or uc_istitle(ch) {
            if previous_is_cased {
                return PyBool_FromLong(0);
            }
            previous_is_cased = True;
            cased = True;
        } elif uc_islower(ch) {
            if not previous_is_cased {
                return PyBool_FromLong(0);
            }
            previous_is_cased = True;
            cased = True;
        } else {
            previous_is_cased = False;
        }
    }
    return PyBool_FromLong(1 if cased else 0);
}

impl unicode_istitle(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_istitle_impl(self_);
}

impl unicode_isspace_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isspace(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isspace(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isspace(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isspace_impl(self_);
}

impl unicode_isalpha_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isalpha(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isalpha(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isalpha(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isalpha_impl(self_);
}

impl unicode_isalnum_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    kind = uo_kind(self_);
    data = uo_data(self_);
    length = uo_length(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isalnum(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isalnum(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isalnum(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isalnum_impl(self_);
}

impl unicode_isdecimal_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isdecimal(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isdecimal(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isdecimal(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isdecimal_impl(self_);
}

impl unicode_isdigit_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isdigit(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isdigit(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isdigit(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isdigit_impl(self_);
}

impl unicode_isnumeric_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isnumeric(ch_read(kind, data, 0)) else 0);
    }

    if length == 0 {
        return PyBool_FromLong(0);
    }
    for i in range(length) {
        if not uc_isnumeric(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isnumeric(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_isnumeric_impl(self_);
}

impl unicode_isidentifier_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(PyUnicode_IsIdentifier(self_)));
}

impl unicode_isidentifier(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return unicode_isidentifier_impl(self_);
}

impl unicode_isprintable_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    length = uo_length(self_);
    kind = uo_kind(self_);
    data = uo_data(self_);

    if length == 1 {
        return PyBool_FromLong(1 if uc_isprintable(ch_read(kind, data, 0)) else 0);
    }
    for i in range(length) {
        if not uc_isprintable(ch_read(kind, data, i)) {
            return PyBool_FromLong(0);
        }
    }
    return PyBool_FromLong(1);
}

impl unicode_isprintable(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return unicode_isprintable_impl(self_);
}

impl unicode_join(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_Join(self_, arg);
}

impl unicode_length(self_: ptr[PyObject]) -> i64 {
    return uo_length(self_);
}

impl unicode_ljust_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject] {
    if uo_length(self_) >= width {
        return unicode_result_unchanged(self_);
    }
    return pad(self_, 0, width - uo_length(self_), fillchar);
}

impl unicode_ljust(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and _PyArg_CheckPositional(ptr[u8]("ljust"), nargs, 1, 2) == i32(0) {
        return NULL;
    }
    (ok, width) = clinic_ssize_arg(args.view(1)[0]);
    if not ok {
        return NULL;
    }
    fillchar = u32(32);
    if nargs >= 2 {
        (converted, fillchar) = convert_uc((args + 1).view(1)[0]);
        if not converted {
            return NULL;
        }
    }
    return unicode_ljust_impl(self_, width, fillchar);
}

impl unicode_lower_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if uo_is_ascii(self_) {
        return ascii_upper_or_lower(self_, True);
    }
    return case_operation(self_, DO_LOWER);
}

impl unicode_lower(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_lower_impl(self_);
}

impl do_strip(self_: ptr[PyObject], striptype: i32) -> ptr[PyObject] {
    length = uo_length(self_);
    data = uo_data(self_);
    i: i64 = 0;
    j: i64 = length;
    if uo_is_ascii(self_) {
        if striptype != RIGHTSTRIP {
            while i < length {
                if not ascii_isspace(u32((data + i).view(1)[0])) {
                    break;
                }
                i += 1;
            }
        }
        if striptype != LEFTSTRIP {
            j -= 1;
            while j >= i {
                if not ascii_isspace(u32((data + j).view(1)[0])) {
                    break;
                }
                j -= 1;
            }
            j += 1;
        }
    } else {
        kind = uo_kind(self_);
        if striptype != RIGHTSTRIP {
            while i < length {
                if not uc_isspace(ch_read(kind, data, i)) {
                    break;
                }
                i += 1;
            }
        }
        if striptype != LEFTSTRIP {
            j -= 1;
            while j >= i {
                if not uc_isspace(ch_read(kind, data, j)) {
                    break;
                }
                j -= 1;
            }
            j += 1;
        }
    }
    return PyUnicode_Substring(self_, i, j);
}

impl do_argstrip(
    self_: ptr[PyObject], striptype: i32, sep: ptr[PyObject]
) -> ptr[PyObject] {
    if sep != Py_None {
        if unicode_check(sep) {
            return _PyUnicode_XStrip(self_, striptype, sep);
        }

        name = ptr[u8]("strip");
        if striptype == LEFTSTRIP {
            name = ptr[u8]("lstrip");
        } elif striptype == RIGHTSTRIP {
            name = ptr[u8]("rstrip");
        }
        PyErr_Format(PyExc_TypeError, "%s arg must be None or str", name);
        return NULL;
    }
    return do_strip(self_, striptype);
}

impl unicode_strip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject] {
    return do_argstrip(self_, BOTHSTRIP, chars);
}

impl unicode_strip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional(ptr[u8]("strip"), nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return unicode_strip_impl(self_, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl unicode_lstrip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject] {
    return do_argstrip(self_, LEFTSTRIP, chars);
}

impl unicode_lstrip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional(ptr[u8]("lstrip"), nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return unicode_lstrip_impl(self_, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl unicode_rstrip_impl(self_: ptr[PyObject], chars: ptr[PyObject]) -> ptr[PyObject] {
    return do_argstrip(self_, RIGHTSTRIP, chars);
}

impl unicode_rstrip(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional(ptr[u8]("rstrip"), nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return unicode_rstrip_impl(self_, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl unicode_repeat(str_obj: ptr[PyObject], len_: i64) -> ptr[PyObject] {
    if len_ < 1 {
        return unicode_get_empty();
    }

    if len_ == 1 {
        return unicode_result_unchanged(str_obj);
    }
    length = uo_length(str_obj);
    if length > PY_SSIZE_T_MAX // len_ {
        PyErr_SetString(PyExc_OverflowError, "repeated string is too long");
        return NULL;
    }
    nchars = len_ * length;
    u = PyUnicode_New(nchars, uo_max_char_value(str_obj));
    if not u {
        return NULL;
    }

    if length == 1 {
        kind = uo_kind(str_obj);
        fill_char = ch_read(kind, uo_data(str_obj), 0);
        if kind == PyUnicode_1BYTE_KIND {
            memset(ptr(uo_data(u)), i32(fill_char), u64(len_));
        } elif kind == PyUnicode_2BYTE_KIND {
            ucs2 = ptr[u16](uo_data(u));
            unit = u16(fill_char);
            for n in range(len_) {
                (ucs2 + n).view(1)[0] = unit;
            }
        } else {
            ucs4 = ptr[u32](uo_data(u));
            for m in range(len_) {
                (ucs4 + m).view(1)[0] = fill_char;
            }
        }
    } else {
        char_size = uo_kind(str_obj);
        _PyBytes_Repeat(
            uo_data(u), nchars * char_size, uo_data(str_obj), length * char_size
        );
    }
    return u;
}

impl unicode_replace_impl(
    self_: ptr[PyObject], old: ptr[PyObject], new: ptr[PyObject], count: i64
) -> ptr[PyObject] {
    return replace(self_, old, new, count);
}

impl unicode_replace_with(
    self_: ptr[PyObject],
    old: ptr[PyObject],
    new: ptr[PyObject],
    count_obj: ptr[PyObject]
) -> ptr[PyObject] {
    if not unicode_check(old) {
        _PyArg_BadArgument(
            ptr[u8]("replace"), ptr[u8]("argument 1"), ptr[u8]("str"), old
        );
        return NULL;
    }
    if not unicode_check(new) {
        _PyArg_BadArgument(
            ptr[u8]("replace"), ptr[u8]("argument 2"), ptr[u8]("str"), new
        );
        return NULL;
    }
    count: i64 = -1;
    if count_obj {
        (ok, count) = clinic_ssize_arg(count_obj);
        if not ok {
            return NULL;
        }
    }
    return unicode_replace_impl(self_, old, new, count);
}

impl unicode_replace_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_replace_with(
        args.context, args.values[0], args.values[1], args.values[2]
    );
}

impl unicode_replace(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs >= 2 and nargs <= 3 {
        return unicode_replace_with(
            self_,
            args.view(1)[0],
            (args + 1).view(1)[0],
            (args + 2).view(1)[0] if nargs >= 3 else NULL
        );
    }
    return invoke_vector(
        unicode_replace_signature, args, nargs, kwnames, unicode_replace_bound, self_
    );
}

impl unicode_removeprefix_impl(
    self_: ptr[PyObject], prefix: ptr[PyObject]
) -> ptr[PyObject] {
    matched = tailmatch(self_, prefix, 0, PY_SSIZE_T_MAX, i32(-1));
    if matched == i32(-1) {
        return NULL;
    }
    if matched != i32(0) {
        return PyUnicode_Substring(self_, uo_length(prefix), uo_length(self_));
    }
    return unicode_result_unchanged(self_);
}

impl unicode_removeprefix(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(
            ptr[u8]("removeprefix"), ptr[u8]("argument"), ptr[u8]("str"), arg
        );
        return NULL;
    }
    return unicode_removeprefix_impl(self_, arg);
}

impl unicode_removesuffix_impl(
    self_: ptr[PyObject], suffix: ptr[PyObject]
) -> ptr[PyObject] {
    matched = tailmatch(self_, suffix, 0, PY_SSIZE_T_MAX, i32(1));
    if matched == i32(-1) {
        return NULL;
    }
    if matched != i32(0) {
        return PyUnicode_Substring(self_, 0, uo_length(self_) - uo_length(suffix));
    }
    return unicode_result_unchanged(self_);
}

impl unicode_removesuffix(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(
            ptr[u8]("removesuffix"), ptr[u8]("argument"), ptr[u8]("str"), arg
        );
        return NULL;
    }
    return unicode_removesuffix_impl(self_, arg);
}

impl py_hexdigit(x: u32) -> u32 {
    if x < u32(10) {
        return u32(48) + x;
    }
    return u32(87) + x;
}

impl unicode_repr_write(
    unicode: ptr[PyObject], quote: u32, okind: i64, odata: ptr[u8]
) {
    isize = uo_length(unicode);
    idata = uo_data(unicode);
    ikind = uo_kind(unicode);
    o: i64 = 0;
    ch_write(okind, odata, o, quote);
    o += 1;
    for i in range(isize) {
        ch = ch_read(ikind, idata, i);

        if ch == quote or ch == u32(92) {
            ch_write(okind, odata, o, u32(92));
            ch_write(okind, odata, o + 1, ch);
            o += 2;
            continue;
        }

        if ch == u32(9) {
            ch_write(okind, odata, o, u32(92));
            ch_write(okind, odata, o + 1, u32(116));
            o += 2;
        } elif ch == u32(10) {
            ch_write(okind, odata, o, u32(92));
            ch_write(okind, odata, o + 1, u32(110));
            o += 2;
        } elif ch == u32(13) {
            ch_write(okind, odata, o, u32(92));
            ch_write(okind, odata, o + 1, u32(114));
            o += 2;
        } elif ch < u32(32) or ch == u32(0x7F) {
            ch_write(okind, odata, o, u32(92));
            ch_write(okind, odata, o + 1, u32(120));
            ch_write(okind, odata, o + 2, py_hexdigit((ch >> u32(4)) & u32(0xF)));
            ch_write(okind, odata, o + 3, py_hexdigit(ch & u32(0xF)));
            o += 4;
        } elif ch < u32(0x7F) {
            ch_write(okind, odata, o, ch);
            o += 1;
        } elif not uc_isprintable(ch) {
            ch_write(okind, odata, o, u32(92));
            o += 1;
            if ch <= u32(0xff) {
                ch_write(okind, odata, o, u32(120));
                ch_write(okind, odata, o + 1, py_hexdigit((ch >> u32(4)) & u32(0xF)));
                ch_write(okind, odata, o + 2, py_hexdigit(ch & u32(0xF)));
                o += 3;
            } elif ch <= u32(0xffff) {
                ch_write(okind, odata, o, u32(117));
                ch_write(okind, odata, o + 1, py_hexdigit((ch >> u32(12)) & u32(0xF)));
                ch_write(okind, odata, o + 2, py_hexdigit((ch >> u32(8)) & u32(0xF)));
                ch_write(okind, odata, o + 3, py_hexdigit((ch >> u32(4)) & u32(0xF)));
                ch_write(okind, odata, o + 4, py_hexdigit(ch & u32(0xF)));
                o += 5;
            } else {
                ch_write(okind, odata, o, u32(85));
                ch_write(okind, odata, o + 1, py_hexdigit((ch >> u32(28)) & u32(0xF)));
                ch_write(okind, odata, o + 2, py_hexdigit((ch >> u32(24)) & u32(0xF)));
                ch_write(okind, odata, o + 3, py_hexdigit((ch >> u32(20)) & u32(0xF)));
                ch_write(okind, odata, o + 4, py_hexdigit((ch >> u32(16)) & u32(0xF)));
                ch_write(okind, odata, o + 5, py_hexdigit((ch >> u32(12)) & u32(0xF)));
                ch_write(okind, odata, o + 6, py_hexdigit((ch >> u32(8)) & u32(0xF)));
                ch_write(okind, odata, o + 7, py_hexdigit((ch >> u32(4)) & u32(0xF)));
                ch_write(okind, odata, o + 8, py_hexdigit(ch & u32(0xF)));
                o += 9;
            }
        } else {
            ch_write(okind, odata, o, ch);
            o += 1;
        }
    }
    ch_write(okind, odata, o, quote);
}

impl unicode_repr(unicode: ptr[PyObject]) -> ptr[PyObject] {
    isize = uo_length(unicode);
    idata = uo_data(unicode);

    osize: i64 = 0;
    maxch = u32(127);
    squote: i64 = 0;
    dquote: i64 = 0;
    ikind = uo_kind(unicode);
    for i in range(isize) {
        ch = ch_read(ikind, idata, i);
        incr: i64 = 1;
        if ch == u32(39) {
            squote += 1;
        } elif ch == u32(34) {
            dquote += 1;
        } elif ch == u32(92) or ch == u32(9) or ch == u32(13) or ch == u32(10) {
            incr = 2;
        } elif ch < u32(32) or ch == u32(0x7f) {
            incr = 4;
        } elif ch < u32(0x7f) {
            incr = 1;
        } elif uc_isprintable(ch) {
            if ch > maxch {
                maxch = ch;
            }
        } elif ch < u32(0x100) {
            incr = 4;
        } elif ch < u32(0x10000) {
            incr = 6;
        } else {
            incr = 10;
        }
        if osize > PY_SSIZE_T_MAX - incr {
            PyErr_SetString(PyExc_OverflowError, "string is too long to generate repr");
            return NULL;
        }
        osize += incr;
    }
    quote = u32(39);
    changed = osize != isize;
    if squote != 0 {
        changed = True;
        if dquote != 0 {
            osize += squote;
        } else {
            quote = u32(34);
        }
    }

    osize += 2;
    result = PyUnicode_New(osize, maxch);
    if not result {
        return NULL;
    }
    okind = uo_kind(result);
    odata = uo_data(result);
    if not changed {
        ch_write(okind, odata, 0, quote);
        _PyUnicode_FastCopyCharacters(result, 1, unicode, 0, isize);
        ch_write(okind, odata, osize - 1, quote);
    } else {
        unicode_repr_write(unicode, quote, okind, odata);
    }
    return result;
}

impl unicode_rfind_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64 {
    result = any_find_slice(str_obj, substr, start, end, i32(-1));
    if result < 0 {
        return -1;
    }
    return result;
}

impl unicode_rfind(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("rfind"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    substr = args.view(1)[0];
    if not unicode_check(substr) {
        _PyArg_BadArgument(
            ptr[u8]("rfind"), ptr[u8]("argument 1"), ptr[u8]("str"), substr
        );
        return NULL;
    }
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return NULL;
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return NULL;
    }
    result = unicode_rfind_impl(self_, substr, start, end);
    if result == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(result);
}

impl unicode_rindex_impl(
    str_obj: ptr[PyObject], substr: ptr[PyObject], start: i64, end: i64
) -> i64 {
    result = any_find_slice(str_obj, substr, start, end, i32(-1));
    if result == -1 {
        PyErr_SetString(PyExc_ValueError, "substring not found");
    } elif result < 0 {
        return -1;
    }
    return result;
}

impl unicode_rindex(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("rindex"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    substr = args.view(1)[0];
    if not unicode_check(substr) {
        _PyArg_BadArgument(
            ptr[u8]("rindex"), ptr[u8]("argument 1"), ptr[u8]("str"), substr
        );
        return NULL;
    }
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return NULL;
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return NULL;
    }
    result = unicode_rindex_impl(self_, substr, start, end);
    if result == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(result);
}

impl unicode_rjust_impl(
    self_: ptr[PyObject], width: i64, fillchar: u32
) -> ptr[PyObject] {
    if uo_length(self_) >= width {
        return unicode_result_unchanged(self_);
    }
    return pad(self_, width - uo_length(self_), 0, fillchar);
}

impl unicode_rjust(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and _PyArg_CheckPositional(ptr[u8]("rjust"), nargs, 1, 2) == i32(0) {
        return NULL;
    }
    ival: i64 = -1;
    iobj = _PyNumber_Index(args.view(1)[0]);
    if iobj {
        ival = PyLong_AsSsize_t(iobj);
        object_decref(iobj);
    }
    if ival == -1 and PyErr_Occurred() {
        return NULL;
    }
    fillchar = u32(32);
    if nargs >= 2 {
        (ok, converted) = convert_uc((args + 1).view(1)[0]);
        if not ok {
            return NULL;
        }
        fillchar = converted;
    }
    return unicode_rjust_impl(self_, ival, fillchar);
}

impl unicode_split_impl(
    self_: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject] {
    if sep == Py_None {
        return split(self_, NULL, maxsplit);
    }
    if unicode_check(sep) {
        return split(self_, sep, maxsplit);
    }
    PyErr_Format(
        PyExc_TypeError,
        "must be str or None, not %.100s",
        object_type(sep).view(1)[0].tp_name
    );
    return NULL;
}

impl unicode_split_args(
    self_: ptr[PyObject],
    sep_obj: ptr[PyObject],
    maxsplit_obj: ptr[PyObject],
    reverse: bool
) -> ptr[PyObject] {
    sep = sep_obj or Py_None;
    maxsplit: i64 = -1;
    if maxsplit_obj {
        ival: i64 = -1;
        iobj = _PyNumber_Index(maxsplit_obj);
        if iobj {
            ival = PyLong_AsSsize_t(iobj);
            object_decref(iobj);
        }
        if ival == -1 and PyErr_Occurred() {
            return NULL;
        }
        maxsplit = ival;
    }
    if reverse {
        return unicode_rsplit_impl(self_, sep, maxsplit);
    }
    return unicode_split_impl(self_, sep, maxsplit);
}

impl unicode_split_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_split_args(args.context, args.values[0], args.values[1], False);
}

impl unicode_split(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return unicode_split_args(
            self_,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL,
            False
        );
    }
    return invoke_vector(
        unicode_split_signature, args, nargs, kwnames, unicode_split_bound, self_
    );
}

impl unicode_partition(self_: ptr[PyObject], sep: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_Partition(self_, sep);
}

impl unicode_rpartition(self_: ptr[PyObject], sep: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_RPartition(self_, sep);
}

impl unicode_rsplit_impl(
    self_: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
) -> ptr[PyObject] {
    if sep == Py_None {
        return rsplit(self_, NULL, maxsplit);
    }
    if unicode_check(sep) {
        return rsplit(self_, sep, maxsplit);
    }
    PyErr_Format(
        PyExc_TypeError,
        "must be str or None, not %.100s",
        object_type(sep).view(1)[0].tp_name
    );
    return NULL;
}

impl unicode_rsplit_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_split_args(args.context, args.values[0], args.values[1], True);
}

impl unicode_rsplit(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return unicode_split_args(
            self_,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL,
            True
        );
    }
    return invoke_vector(
        unicode_rsplit_signature, args, nargs, kwnames, unicode_rsplit_bound, self_
    );
}

impl unicode_splitlines_impl(self_: ptr[PyObject], keepends: i32) -> ptr[PyObject] {
    return PyUnicode_Splitlines(self_, keepends);
}

impl unicode_splitlines_args(
    self_: ptr[PyObject], keepends_obj: ptr[PyObject]
) -> ptr[PyObject] {
    keepends = i32(0);
    if keepends_obj {
        keepends = PyObject_IsTrue(keepends_obj);
        if keepends < i32(0) {
            return NULL;
        }
    }
    return unicode_splitlines_impl(self_, keepends);
}

impl unicode_splitlines_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_splitlines_args(args.context, args.values[0]);
}

impl unicode_splitlines(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 1 {
        return unicode_splitlines_args(self_, args.view(1)[0] if nargs >= 1 else NULL);
    }
    return invoke_vector(
        unicode_splitlines_signature,
        args,
        nargs,
        kwnames,
        unicode_splitlines_bound,
        self_
    );
}

impl unicode_str(self_: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_result_unchanged(self_);
}

impl unicode_swapcase_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return case_operation(self_, DO_SWAPCASE);
}

impl unicode_swapcase(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_swapcase_impl(self_);
}

impl unicode_maketrans_from_dict(x: ptr[PyObject], newdict: ptr[PyObject]) -> i32 {
    key = NULL;
    value = NULL;
    i: i64 = 0;
    while PyDict_Next(x, &mut i, &mut key, &mut value) != i32(0) {
        if unicode_check(key) {
            if uo_length(key) != 1 {
                PyErr_SetString(
                    PyExc_ValueError,
                    "string keys in translatetable must be of length 1"
                );
                return i32(-1);
            }
            kind = uo_kind(key);
            data = uo_data(key);
            newkey = PyLong_FromLong(i64(ch_read(kind, data, 0)));
            if not newkey {
                return i32(-1);
            }
            res = PyDict_SetItem(newdict, newkey, value);
            object_decref(newkey);
            if res < i32(0) {
                return i32(-1);
            }
        } elif long_check(key) {
            if PyDict_SetItem(newdict, key, value) < i32(0) {
                return i32(-1);
            }
        } else {
            PyErr_SetString(
                PyExc_TypeError, "keys in translate table mustbe strings or integers"
            );
            return i32(-1);
        }
    }
    return i32(0);
}

impl unicode_maketrans_impl(
    x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]
) -> ptr[PyObject] {
    new_dict = PyDict_New();
    if not new_dict {
        return NULL;
    }
    if y {
        if not unicode_check(x) {
            PyErr_SetString(
                PyExc_TypeError,
                "first maketrans argument must be a string if there is a second argument"
            );
            object_decref(new_dict);
            return NULL;
        }
        if uo_length(x) != uo_length(y) {
            PyErr_SetString(
                PyExc_ValueError,
                "the first two maketrans arguments must have equal length"
            );
            object_decref(new_dict);
            return NULL;
        }

        x_kind = uo_kind(x);
        y_kind = uo_kind(y);
        x_data = uo_data(x);
        y_data = uo_data(y);
        for i in range(uo_length(x)) {
            key = PyLong_FromLong(i64(ch_read(x_kind, x_data, i)));
            if not key {
                object_decref(new_dict);
                return NULL;
            }
            value = PyLong_FromLong(i64(ch_read(y_kind, y_data, i)));
            if not value {
                object_decref(key);
                object_decref(new_dict);
                return NULL;
            }
            res = PyDict_SetItem(new_dict, key, value);
            object_decref(key);
            object_decref(value);
            if res < i32(0) {
                object_decref(new_dict);
                return NULL;
            }
        }

        if z {
            z_kind = uo_kind(z);
            z_data = uo_data(z);
            for i in range(uo_length(z)) {
                key = PyLong_FromLong(i64(ch_read(z_kind, z_data, i)));
                if not key {
                    object_decref(new_dict);
                    return NULL;
                }
                res = PyDict_SetItem(new_dict, key, Py_None);
                object_decref(key);
                if res < i32(0) {
                    object_decref(new_dict);
                    return NULL;
                }
            }
        }
    } else {
        if not object_is_type(x, ptr[PyTypeObject](addressof(PyDict_Type))) {
            PyErr_SetString(
                PyExc_TypeError,
                "if you give only one argument to maketrans it must be a dict"
            );
            object_decref(new_dict);
            return NULL;
        }
        if unicode_maketrans_from_dict(x, new_dict) < i32(0) {
            object_decref(new_dict);
            return NULL;
        }
    }
    return new_dict;
}

impl unicode_maketrans(
    null: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("maketrans"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    x = args.view(1)[0];
    y = NULL;
    z = NULL;
    if nargs >= 2 {
        y = (args + 1).view(1)[0];
        if not unicode_check(y) {
            _PyArg_BadArgument(
                ptr[u8]("maketrans"), ptr[u8]("argument 2"), ptr[u8]("str"), y
            );
            return NULL;
        }
    }
    if nargs >= 3 {
        z = (args + 2).view(1)[0];
        if not unicode_check(z) {
            _PyArg_BadArgument(
                ptr[u8]("maketrans"), ptr[u8]("argument 3"), ptr[u8]("str"), z
            );
            return NULL;
        }
    }
    return unicode_maketrans_impl(x, y, z);
}

impl unicode_translate(self_: ptr[PyObject], table: ptr[PyObject]) -> ptr[PyObject] {
    return _PyUnicode_TranslateCharmap(self_, table, ptr[u8]("ignore"));
}

impl unicode_upper_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if uo_is_ascii(self_) {
        return ascii_upper_or_lower(self_, False);
    }
    return case_operation(self_, DO_UPPER);
}

impl unicode_upper(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_upper_impl(self_);
}

impl unicode_zfill_impl(self_: ptr[PyObject], width: i64) -> ptr[PyObject] {
    if uo_length(self_) >= width {
        return unicode_result_unchanged(self_);
    }
    fill = width - uo_length(self_);
    u = pad(self_, fill, 0, u32(48));
    if not u {
        return NULL;
    }
    kind = uo_kind(u);
    data = uo_data(u);
    ch = ch_read(kind, data, fill);
    if ch == u32(43) or ch == u32(45) {
        ch_write(kind, data, 0, ch);
        ch_write(kind, data, fill, u32(48));
    }
    return u;
}

impl unicode_zfill(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    ival: i64 = -1;
    iobj = _PyNumber_Index(arg);
    if iobj {
        ival = PyLong_AsSsize_t(iobj);
        object_decref(iobj);
    }
    if ival == -1 and PyErr_Occurred() {
        return NULL;
    }
    return unicode_zfill_impl(self_, ival);
}

impl unicode_startswith_impl(
    self_: ptr[PyObject], subobj: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    if tuple_check(subobj) {
        for i in range(object_size(subobj)) {
            substring = tuple_get_item(subobj, i);
            if not unicode_check(substring) {
                PyErr_Format(
                    PyExc_TypeError,
                    "tuple for startswith must only contain str, not %.100s",
                    object_type(substring).view(1)[0].tp_name
                );
                return NULL;
            }
            result = tailmatch(self_, substring, start, end, i32(-1));
            if result < i32(0) {
                return NULL;
            }
            if result != i32(0) {
                return PyBool_FromLong(1);
            }
        }

        return PyBool_FromLong(0);
    }
    if not unicode_check(subobj) {
        PyErr_Format(
            PyExc_TypeError,
            "startswith first arg must be str or a tuple of str, not %.100s",
            object_type(subobj).view(1)[0].tp_name
        );
        return NULL;
    }
    result = tailmatch(self_, subobj, start, end, i32(-1));
    if result < i32(0) {
        return NULL;
    }
    return PyBool_FromLong(i64(result));
}

impl unicode_startswith(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("startswith"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return NULL;
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return NULL;
    }
    return unicode_startswith_impl(self_, args.view(1)[0], start, end);
}

impl unicode_endswith_impl(
    self_: ptr[PyObject], subobj: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    if tuple_check(subobj) {
        for i in range(object_size(subobj)) {
            substring = tuple_get_item(subobj, i);
            if not unicode_check(substring) {
                PyErr_Format(
                    PyExc_TypeError,
                    "tuple for endswith must only contain str, not %.100s",
                    object_type(substring).view(1)[0].tp_name
                );
                return NULL;
            }
            result = tailmatch(self_, substring, start, end, i32(1));
            if result < i32(0) {
                return NULL;
            }
            if result != i32(0) {
                return PyBool_FromLong(1);
            }
        }
        return PyBool_FromLong(0);
    }
    if not unicode_check(subobj) {
        PyErr_Format(
            PyExc_TypeError,
            "endswith first arg must be str or a tuple of str, not %.100s",
            object_type(subobj).view(1)[0].tp_name
        );
        return NULL;
    }
    result = tailmatch(self_, subobj, start, end, i32(1));
    if result < i32(0) {
        return NULL;
    }
    return PyBool_FromLong(i64(result));
}

impl unicode_endswith(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("endswith"), nargs, 1, 3) == i32(0) {
        return NULL;
    }
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return NULL;
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return NULL;
    }
    return unicode_endswith_impl(self_, args.view(1)[0], start, end);
}

impl unicode_writers_pop -> ptr {
    fl = freelist(_Py_freelists_UNICODE_WRITERS);
    block = fl.view(1)[0].freelist;
    if block {
        fl.view(1)[0].freelist = ptr[ptr](block).view(1)[0];
        fl.view(1)[0].size -= 1;
    }
    return block;
}

impl unicode_writers_free(block: ptr) {
    if not freelist_push(
        _Py_freelists_UNICODE_WRITERS,
        ptr[PyObject](block),
        Py_unicode_writers_MAXFREELIST
    ) {
        PyMem_Free(block);
    }
}

impl AutoNumber_Init(auto_number: ptr[AutoNumber]) {
    auto_number.view(1)[0].an_state = ANS_INIT;
    auto_number.view(1)[0].an_field_number = i32(0);
}

impl SubString_new_object(s: ptr[PyObject], start: i64, end: i64) -> ptr[PyObject] {
    if not s {
        return object_new_ref(Py_None);
    }
    return PyUnicode_Substring(s, start, end);
}

impl SubString_new_object_or_empty(
    s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    if not s {
        return object_new_ref(unicode_get_empty());
    }
    return SubString_new_object(s, start, end);
}

impl autonumber_state_error(state: i32, field_name_is_empty: bool) -> i32 {
    if state == ANS_MANUAL {
        if field_name_is_empty {
            PyErr_SetString(
                PyExc_ValueError,
                "cannot switch from manual field specification to automatic field numbering"
            );
            return i32(1);
        }
    } else {
        if not field_name_is_empty {
            PyErr_SetString(
                PyExc_ValueError,
                "cannot switch from automatic field numbering to manual field specification"
            );
            return i32(1);
        }
    }
    return i32(0);
}

impl get_integer(s: ptr[PyObject], start: i64, end: i64) -> i64 {
    accumulator: i64 = 0;

    if start >= end {
        return -1;
    }
    i = start;
    while i < end {
        digitval = i64(uc_todecimal(uo_read_char(s, i)));
        if digitval < 0 {
            return -1;
        }

        if accumulator > (PY_SSIZE_T_MAX - digitval) // 10 {
            PyErr_Format(PyExc_ValueError, "Too many decimal digits in format string");
            return -1;
        }
        accumulator = accumulator * 10 + digitval;
        i += 1;
    }
    return accumulator;
}

impl format_getattr(
    obj_: ptr[PyObject], s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    name = SubString_new_object(s, start, end);
    if not name {
        return NULL;
    }
    newobj = PyObject_GetAttr(obj_, name);
    object_decref(name);
    return newobj;
}

impl getitem_sequence(obj_: ptr[PyObject], idx: i64) -> ptr[PyObject] {
    return PySequence_GetItem(obj_, idx);
}

impl getitem_idx(obj_: ptr[PyObject], idx: i64) -> ptr[PyObject] {
    idx_obj = PyLong_FromSsize_t(idx);
    if not idx_obj {
        return NULL;
    }
    newobj = PyObject_GetItem(obj_, idx_obj);
    object_decref(idx_obj);
    return newobj;
}

impl getitem_str(
    obj_: ptr[PyObject], s: ptr[PyObject], start: i64, end: i64
) -> ptr[PyObject] {
    name = SubString_new_object(s, start, end);
    if not name {
        return NULL;
    }
    newobj = PyObject_GetItem(obj_, name);
    object_decref(name);
    return newobj;
}

impl _FieldNameIterator_attr(s: ptr[PyObject], end: i64, index_in: i64) -> i64 {
    index = index_in;
    while index < end {
        c = uo_read_char(s, index);
        index += 1;
        if c == FMT_LBRACKET or c == FMT_DOT {
            index -= 1;
            break;
        }
    }
    return index;
}

impl _FieldNameIterator_item(
    s: ptr[PyObject], end: i64, index_in: i64
) -> tuple[i32, i64] {
    index = index_in;
    bracket_seen = False;
    while index < end {
        c = uo_read_char(s, index);
        index += 1;
        if c == FMT_RBRACKET {
            bracket_seen = True;
            break;
        }
    }

    if not bracket_seen {
        PyErr_SetString(PyExc_ValueError, "Missing ']' in format string");
        return (i32(0), index);
    }
    return (i32(1), index);
}

impl FieldNameIterator_next(
    s: ptr[PyObject], end: i64, index_in: i64
) -> tuple[i32, i64, bool, i64, i64, i64] {
    index = index_in;

    if index >= end {
        return (i32(1), index, False, i64(-1), index, index);
    }
    c = uo_read_char(s, index);
    index += 1;
    is_attribute = False;
    name_idx: i64 = -1;
    name_start = index;
    name_end = index;
    if c == FMT_DOT {
        is_attribute = True;
        index = _FieldNameIterator_attr(s, end, index);
        name_end = index;
        name_idx = -1;
    } elif c == FMT_LBRACKET {
        is_attribute = False;
        (found, item_index) = _FieldNameIterator_item(s, end, index);
        index = item_index;
        if found == i32(0) {
            return (i32(0), index, is_attribute, name_idx, name_start, name_end);
        }
        name_end = index - 1;
        name_idx = get_integer(s, name_start, name_end);
        if name_idx == -1 and PyErr_Occurred() {
            return (i32(0), index, is_attribute, name_idx, name_start, name_end);
        }
    } else {
        PyErr_SetString(
            PyExc_ValueError, "Only '.' or '[' may follow ']' in format field specifier"
        );
        return (i32(0), index, is_attribute, name_idx, name_start, name_end);
    }

    if name_start == name_end {
        PyErr_SetString(PyExc_ValueError, "Empty attribute in format string");
        return (i32(0), index, is_attribute, name_idx, name_start, name_end);
    }
    return (i32(2), index, is_attribute, name_idx, name_start, name_end);
}

impl field_name_split(
    s: ptr[PyObject], start: i64, end: i64, auto_number: ptr[AutoNumber]
) -> tuple[i32, i64, i64] {
    i = start;

    while i < end {
        c = uo_read_char(s, i);
        i += 1;
        if c == FMT_LBRACKET or c == FMT_DOT {
            i -= 1;
            break;
        }
    }

    first_idx = get_integer(s, start, i);
    if first_idx == -1 and PyErr_Occurred() {
        return (i32(0), i, first_idx);
    }
    field_name_is_empty = start >= i;

    using_numeric_index = field_name_is_empty or first_idx != -1;

    if auto_number {
        if auto_number.view(1)[0].an_state == ANS_INIT and using_numeric_index {
            auto_number.view(1)[0].an_state = ANS_AUTO
                if field_name_is_empty
                else ANS_MANUAL;
        }

        if using_numeric_index {
            if autonumber_state_error(
                auto_number.view(1)[0].an_state, field_name_is_empty
            )
                != i32(0) {
                return (i32(0), i, first_idx);
            }
        }

        if field_name_is_empty {
            number = auto_number.view(1)[0].an_field_number;
            first_idx = i64(number);
            auto_number.view(1)[0].an_field_number = number + i32(1);
        }
    }
    return (i32(1), i, first_idx);
}

impl get_field_object(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    auto_number: ptr[AutoNumber]
) -> ptr[PyObject] {
    (split_ok, rest_index, index) = field_name_split(s, start, end, auto_number);
    if split_ok == i32(0) {
        return NULL;
    }
    obj_ = NULL;
    if index == -1 {
        key = SubString_new_object(s, start, rest_index);
        if not key {
            return NULL;
        }
        if not kwargs {
            PyErr_SetObject(PyExc_KeyError, key);
            object_decref(key);
            return NULL;
        }

        obj_ = PyObject_GetItem(kwargs, key);
        object_decref(key);
        if not obj_ {
            return NULL;
        }
    } else {
        if not args {
            PyErr_SetString(
                PyExc_ValueError, "Format string contains positional fields"
            );
            return NULL;
        }
        obj_ = PySequence_GetItem(args, index);
        if not obj_ {
            PyErr_Format(
                PyExc_IndexError,
                "Replacement index %zd out of range for positional args tuple",
                index
            );
            return NULL;
        }
    }

    pos = rest_index;
    ok = i32(2);
    while ok == i32(2) {
        (step, next_pos, is_attribute, name_idx, name_start, name_end) = FieldNameIterator_next(
            s, end, pos
        );
        ok = step;
        pos = next_pos;
        if ok == i32(2) {
            tmp = NULL;
            if is_attribute {
                tmp = format_getattr(obj_, s, name_start, name_end);
            } elif name_idx == -1 {
                tmp = getitem_str(obj_, s, name_start, name_end);
            } elif PySequence_Check(obj_) != i32(0) {
                tmp = getitem_sequence(obj_, name_idx);
            } else {
                tmp = getitem_idx(obj_, name_idx);
            }
            if not tmp {
                ok = i32(0);
            } else {
                old = obj_;
                obj_ = tmp;
                object_decref(old);
            }
        }
    }

    if ok == i32(1) {
        return obj_;
    }
    object_decref(obj_);
    return NULL;
}

impl render_field(
    fieldobj: ptr[PyObject],
    fs_str: ptr[PyObject],
    fs_start: i64,
    fs_end: i64,
    writer: ptr[UnicodeWriter]
) -> i32 {
    err = i32(0);
    known = True;
    if unicode_check_exact(fieldobj) {
        err = _PyUnicode_FormatAdvancedWriter(
            writer, fieldobj, fs_str, fs_start, fs_end
        );
    } elif object_is_type(fieldobj, ptr[PyTypeObject](addressof(PyLong_Type))) {
        err = _PyLong_FormatAdvancedWriter(writer, fieldobj, fs_str, fs_start, fs_end);
    } elif object_is_type(fieldobj, ptr[PyTypeObject](addressof(PyFloat_Type))) {
        err = _PyFloat_FormatAdvancedWriter(writer, fieldobj, fs_str, fs_start, fs_end);
    } elif object_is_type(fieldobj, ptr[PyTypeObject](addressof(PyComplex_Type))) {
        err = _PyComplex_FormatAdvancedWriter(
            writer, fieldobj, fs_str, fs_start, fs_end
        );
    } else {
        known = False;
    }
    if known {
        return i32(1) if err == i32(0) else i32(0);
    }

    format_spec_object = NULL;
    if fs_str {
        format_spec_object = PyUnicode_Substring(fs_str, fs_start, fs_end);
    } else {
        format_spec_object = object_new_ref(unicode_get_empty());
    }
    if not format_spec_object {
        return i32(0);
    }
    ok = i32(0);
    result = PyObject_Format(fieldobj, format_spec_object);
    if result and _PyUnicodeWriter_WriteStr(writer, result) != i32(-1) {
        ok = i32(1);
    }
    object_decref(format_spec_object);
    object_xdecref(result);
    return ok;
}

impl parse_field(
    s: ptr[PyObject], pos_in: i64, end: i64
) -> tuple[i32, i64, i64, ptr[PyObject], i64, i64, u32, bool] {
    pos = pos_in;
    ok = i32(1);
    c = u32(0);
    conversion = u32(0);
    expand = False;
    fs_str = NULL;
    fs_start: i64 = 0;
    fs_end: i64 = 0;

    while pos < end {
        c = uo_read_char(s, pos);
        pos += 1;
        if c == FMT_LBRACE {
            PyErr_SetString(PyExc_ValueError, "unexpected '{' in field name");
            ok = i32(0);
            break;
        }
        if c == FMT_LBRACKET {
            while pos < end {
                if uo_read_char(s, pos) == FMT_RBRACKET {
                    break;
                }
                pos += 1;
            }
            continue;
        }
        if c == FMT_RBRACE or c == FMT_COLON or c == FMT_BANG {
            break;
        }
    }
    fn_end = pos - 1;
    if ok == i32(0) {
        fn_end = pos_in;
    } elif c == FMT_BANG or c == FMT_COLON {
        finished = False;
        if c == FMT_BANG {
            if pos >= end {
                PyErr_SetString(
                    PyExc_ValueError,
                    "end of string while looking for conversion specifier"
                );
                ok = i32(0);
            } else {
                conversion = uo_read_char(s, pos);
                pos += 1;
                if pos < end {
                    c = uo_read_char(s, pos);
                    pos += 1;
                    if c == FMT_RBRACE {
                        finished = True;
                    } elif c != FMT_COLON {
                        PyErr_SetString(
                            PyExc_ValueError, "expected ':' after conversion specifier"
                        );
                        ok = i32(0);
                    }
                }
            }
        }
        if ok != i32(0) and not finished {
            fs_str = s;
            fs_start = pos;
            count = 1;
            while pos < end {
                c = uo_read_char(s, pos);
                pos += 1;
                if c == FMT_LBRACE {
                    expand = True;
                    count += 1;
                } elif c == FMT_RBRACE {
                    count -= 1;
                    if count == 0 {
                        fs_end = pos - 1;
                        finished = True;
                        break;
                    }
                }
            }
            if not finished {
                PyErr_SetString(PyExc_ValueError, "unmatched '{' in format spec");
                ok = i32(0);
            }
        }
    } elif c != FMT_RBRACE {
        PyErr_SetString(PyExc_ValueError, "expected '}' before end of string");
        ok = i32(0);
    }
    return (ok, pos, fn_end, fs_str, fs_start, fs_end, conversion, expand);
}

impl markup_literal(
    status: i32, pos: i64, literal_start: i64, literal_end: i64
) -> tuple[
    i32,
    i64,
    i64,
    i64,
    bool,
    ptr[PyObject],
    i64,
    i64,
    ptr[PyObject],
    i64,
    i64,
    u32,
    bool
] {
    return (
        status,
        pos,
        literal_start,
        literal_end,
        False,
        NULL,
        i64(0),
        i64(0),
        NULL,
        i64(0),
        i64(0),
        u32(0),
        False
    );
}

impl MarkupIterator_next(
    s: ptr[PyObject], pos_in: i64, end: i64
) -> tuple[
    i32,
    i64,
    i64,
    i64,
    bool,
    ptr[PyObject],
    i64,
    i64,
    ptr[PyObject],
    i64,
    i64,
    u32,
    bool
] {
    pos = pos_in;

    if pos >= end {
        return markup_literal(i32(1), pos, i64(0), i64(0));
    }
    start = pos;
    c = u32(0);
    markup_follows = False;

    while pos < end {
        c = uo_read_char(s, pos);
        pos += 1;
        if c == FMT_LBRACE or c == FMT_RBRACE {
            markup_follows = True;
            break;
        }
    }
    at_end = pos >= end;
    length = pos - start;
    if c == FMT_RBRACE and (at_end or c != uo_read_char(s, pos)) {
        PyErr_SetString(PyExc_ValueError, "Single '}' encountered in format string");
        return markup_literal(i32(0), pos, i64(0), i64(0));
    }
    if at_end and c == FMT_LBRACE {
        PyErr_SetString(PyExc_ValueError, "Single '{' encountered in format string");
        return markup_literal(i32(0), pos, i64(0), i64(0));
    }
    if not at_end {
        if c == uo_read_char(s, pos) {
            pos += 1;
            markup_follows = False;
        } else {
            length -= 1;
        }
    }

    literal_end = start + length;
    if not markup_follows {
        return markup_literal(i32(2), pos, start, literal_end);
    }

    (ok, field_pos, field_name_end, fs_str, fs_start, fs_end, conversion, expand) = parse_field(
        s, pos, end
    );
    return (
        i32(2) if ok != i32(0) else i32(0),
        field_pos,
        start,
        literal_end,
        True,
        s,
        pos,
        field_name_end,
        fs_str,
        fs_start,
        fs_end,
        conversion,
        expand
    );
}

impl do_conversion(obj_: ptr[PyObject], conversion: u32) -> ptr[PyObject] {
    if conversion == FMT_CONV_REPR {
        return PyObject_Repr(obj_);
    }
    if conversion == FMT_CONV_STR {
        return PyObject_Str(obj_);
    }
    if conversion == FMT_CONV_ASCII {
        return PyObject_ASCII(obj_);
    }
    if conversion > u32(32) and conversion < u32(127) {
        PyErr_Format(
            PyExc_ValueError, "Unknown conversion specifier %c", i32(conversion)
        );
    } else {
        PyErr_Format(
            PyExc_ValueError, "Unknown conversion specifier \\x%x", conversion
        );
    }
    return NULL;
}

impl output_markup(
    s: ptr[PyObject],
    field_name_start: i64,
    field_name_end: i64,
    fs_str: ptr[PyObject],
    fs_start: i64,
    fs_end: i64,
    format_spec_needs_expanding: bool,
    conversion: u32,
    writer: ptr[UnicodeWriter],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> i32 {
    fieldobj = get_field_object(
        s, field_name_start, field_name_end, args, kwargs, auto_number
    );
    if not fieldobj {
        return i32(0);
    }
    if conversion != u32(0) {
        tmp = do_conversion(fieldobj, conversion);
        if not tmp {
            object_decref(fieldobj);
            return i32(0);
        }

        old = fieldobj;
        fieldobj = tmp;
        object_decref(old);
    }
    result = i32(0);
    if format_spec_needs_expanding {
        expanded = build_string(
            fs_str, fs_start, fs_end, args, kwargs, recursion_depth - 1, auto_number
        );
        if not expanded {
            object_decref(fieldobj);
            return i32(0);
        }
        result = render_field(fieldobj, expanded, 0, uo_length(expanded), writer);
        object_decref(expanded);
    } else {
        result = render_field(fieldobj, fs_str, fs_start, fs_end, writer);
    }
    object_decref(fieldobj);
    return result;
}

impl do_markup(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    writer: ptr[UnicodeWriter],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> i32 {
    pos = start;
    result = i32(2);
    while result == i32(2) {
        (
            status,
            next_pos,
            literal_start,
            literal_end,
            field_present,
            field_name_str,
            field_name_start,
            field_name_end,
            fs_str,
            fs_start,
            fs_end,
            conversion,
            needs_expanding
        ) = MarkupIterator_next(s, pos, end);
        result = status;
        pos = next_pos;
        if result == i32(2) {
            if literal_end != literal_start {
                if not field_present and pos == end {
                    writer.view(1)[0].overallocate = u8(0);
                }
                if _PyUnicodeWriter_WriteSubstring(
                    writer, s, literal_start, literal_end
                )
                    < i32(0) {
                    return i32(0);
                }
            }
            if field_present {
                if pos == end {
                    writer.view(1)[0].overallocate = u8(0);
                }
                if output_markup(
                    field_name_str,
                    field_name_start,
                    field_name_end,
                    fs_str,
                    fs_start,
                    fs_end,
                    needs_expanding,
                    conversion,
                    writer,
                    args,
                    kwargs,
                    recursion_depth,
                    auto_number
                )
                    == i32(0) {
                    return i32(0);
                }
            }
        }
    }
    return result;
}

impl build_string(
    s: ptr[PyObject],
    start: i64,
    end: i64,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    recursion_depth: i64,
    auto_number: ptr[AutoNumber]
) -> ptr[PyObject] {
    if recursion_depth <= 0 {
        PyErr_SetString(PyExc_ValueError, "Max string recursion exceeded");
        return NULL;
    }
    writer = writer_new();
    if not writer {
        return NULL;
    }
    writer.view(1)[0].overallocate = u8(1);
    writer.view(1)[0].min_length = uo_length(s) + 100;
    if do_markup(s, start, end, args, kwargs, writer, recursion_depth, auto_number)
        == i32(0) {
        _PyUnicodeWriter_Dealloc(writer);
        writer_free(writer);
        return NULL;
    }
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl do_string_format(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    auto_number = ptr[AutoNumber](PyMem_Malloc(u64(AutoNumber_SIZE)));
    if not auto_number {
        PyErr_NoMemory();
        return NULL;
    }
    AutoNumber_Init(auto_number);
    result = build_string(
        self_, 0, uo_length(self_), args, kwargs, FORMAT_RECURSION_DEPTH, auto_number
    );
    PyMem_Free(ptr(auto_number));
    return result;
}

impl do_string_format_map(self_: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return do_string_format(self_, NULL, obj_);
}

impl formatteriter_of(op: ptr[PyObject]) -> ptr[formatteriterobject] {
    return ptr[formatteriterobject](op);
}

impl formatteriter_dealloc(op: ptr[PyObject]) {
    object_xdecref(formatteriter_of(op).view(1)[0].str_obj);
    PyObject_Free(ptr(op));
}

impl formatteriter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = formatteriter_of(op);
    s = it.view(1)[0].it_markup_str;
    (
        result,
        pos,
        literal_start,
        literal_end,
        field_present,
        field_name_str,
        field_name_start,
        field_name_end,
        fs_str,
        fs_start,
        fs_end,
        conversion,
        needs_expanding
    ) = MarkupIterator_next(
        s, it.view(1)[0].it_markup_start, it.view(1)[0].it_markup_end
    );
    it.view(1)[0].it_markup_start = pos;

    if result == i32(0) or result == i32(1) {
        return NULL;
    }
    tup = NULL;
    field_name_obj = NULL;
    format_spec_obj = NULL;
    conversion_obj = NULL;
    literal_obj = SubString_new_object(s, literal_start, literal_end);
    if literal_obj {
        field_name_obj = SubString_new_object(
            field_name_str, field_name_start, field_name_end
        );
    }
    if field_name_obj {
        if field_present {
            format_spec_obj = SubString_new_object_or_empty(fs_str, fs_start, fs_end);
        } else {
            format_spec_obj = SubString_new_object(fs_str, fs_start, fs_end);
        }
    }
    if format_spec_obj {
        if conversion == u32(0) {
            conversion_obj = object_new_ref(Py_None);
        } else {
            conversion_obj = unicode_char(conversion);
        }
    }
    if conversion_obj {
        tup = PyTuple_Pack(
            4, literal_obj, field_name_obj, format_spec_obj, conversion_obj
        );
    }
    object_xdecref(literal_obj);
    object_xdecref(field_name_obj);
    object_xdecref(format_spec_obj);
    object_xdecref(conversion_obj);
    return tup;
}

impl formatter_parser(ignored: ptr[PyObject], self_: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(self_) {
        PyErr_Format(
            PyExc_TypeError,
            "expected str, got %s",
            object_type(self_).view(1)[0].tp_name
        );
        return NULL;
    }
    op = _PyObject_New(ptr[PyObject](addressof(PyFormatterIter_Type)));
    if not op {
        return NULL;
    }
    it = formatteriter_of(op);

    it.view(1)[0].str_obj = object_new_ref(self_);

    it.view(1)[0].it_markup_str = self_;
    it.view(1)[0].it_markup_start = 0;
    it.view(1)[0].it_markup_end = uo_length(self_);
    return op;
}

impl fieldnameiter_of(op: ptr[PyObject]) -> ptr[fieldnameiterobject] {
    return ptr[fieldnameiterobject](op);
}

impl fieldnameiter_dealloc(op: ptr[PyObject]) {
    object_xdecref(fieldnameiter_of(op).view(1)[0].str_obj);
    PyObject_Free(ptr(op));
}

impl fieldnameiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = fieldnameiter_of(op);
    s = it.view(1)[0].it_field_str;
    (status, index, is_attr, idx, name_start, name_end) = FieldNameIterator_next(
        s, it.view(1)[0].it_field_end, it.view(1)[0].it_field_index
    );
    it.view(1)[0].it_field_index = index;
    if status == i32(0) or status == i32(1) {
        return NULL;
    }
    result = NULL;
    obj_ = NULL;
    is_attr_obj = PyBool_FromLong(1 if is_attr else 0);
    if is_attr_obj {
        if idx != -1 {
            obj_ = PyLong_FromSsize_t(idx);
        } else {
            obj_ = SubString_new_object(s, name_start, name_end);
        }
        if obj_ {
            result = PyTuple_Pack(2, is_attr_obj, obj_);
        }
    }
    object_xdecref(is_attr_obj);
    object_xdecref(obj_);
    return result;
}

impl formatter_field_name_split(
    ignored: ptr[PyObject], self_: ptr[PyObject]
) -> ptr[PyObject] {
    if not unicode_check(self_) {
        PyErr_Format(
            PyExc_TypeError,
            "expected str, got %s",
            object_type(self_).view(1)[0].tp_name
        );
        return NULL;
    }
    op = _PyObject_New(ptr[PyObject](addressof(PyFieldNameIter_Type)));
    if not op {
        return NULL;
    }
    it = fieldnameiter_of(op);

    it.view(1)[0].str_obj = object_new_ref(self_);
    end = uo_length(self_);

    (ok, rest_start, first_idx) = field_name_split(self_, 0, end, ptr[AutoNumber]());

    it.view(1)[0].it_field_str = self_;
    it.view(1)[0].it_field_start = rest_start;
    it.view(1)[0].it_field_end = end;
    it.view(1)[0].it_field_index = rest_start;
    first_obj = NULL;
    result = NULL;
    if ok != i32(0) {
        if first_idx != -1 {
            first_obj = PyLong_FromSsize_t(first_idx);
        } else {
            first_obj = SubString_new_object(self_, 0, rest_start);
        }
        if first_obj {
            result = PyTuple_Pack(2, first_obj, op);
        }
    }
    object_decref(op);
    object_xdecref(first_obj);
    return result;
}

impl unicode___format___impl(
    self_: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject] {
    writer = writer_new();
    if not writer {
        return NULL;
    }
    ret = _PyUnicode_FormatAdvancedWriter(
        writer, self_, format_spec, 0, uo_length(format_spec)
    );
    if ret == i32(-1) {
        _PyUnicodeWriter_Dealloc(writer);
        writer_free(writer);
        return NULL;
    }
    result = _PyUnicodeWriter_Finish(writer);
    writer_free(writer);
    return result;
}

impl unicode___format__(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(
            ptr[u8]("__format__"), ptr[u8]("argument"), ptr[u8]("str"), arg
        );
        return NULL;
    }
    return unicode___format___impl(self_, arg);
}

impl unicode_sizeof_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    size: i64 = 0;
    if uo_is_compact_ascii(self_) {
        size = PyASCIIObject_SIZE + uo_length(self_) + 1;
    } elif uo_is_compact(self_) {
        size = PyCompactUnicodeObject_SIZE + (uo_length(self_) + 1) * uo_kind(self_);
    } else {
        size = PyUnicodeObject_SIZE;
        if uo_data_any(self_) {
            size += (uo_length(self_) + 1) * uo_kind(self_);
        }
    }
    if uo_has_utf8_memory(self_) {
        size += uo_utf8_length(self_) + 1;
    }
    return PyLong_FromSsize_t(size);
}

impl unicode_sizeof(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return unicode_sizeof_impl(self_);
}

impl unicode_getnewargs(v: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    copy = _PyUnicode_Copy(v);
    if not copy {
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("(N)"), copy);
}

impl search_longest_common_leading_whitespace(
    src: ptr[u8], end: ptr[u8]
) -> tuple[i64, ptr[u8]] {
    common_start = ptr[u8]();
    common_len: i64 = 0;
    p = src;
    while p < end {
        line_start = p;
        leading_whitespace_end = ptr[u8]();

        while p < end and p.view(1)[0] != u8(10) {
            if not leading_whitespace_end
                and p.view(1)[0] != u8(32)
                and p.view(1)[0] != u8(9) {
                if p == line_start {
                    return (i64(0), ptr[u8]());
                }
                leading_whitespace_end = p;
            }
            p = p + 1;
        }

        if leading_whitespace_end {
            if not common_start {
                common_start = line_start;
                common_len = i64(int(leading_whitespace_end) - int(line_start));
            } else {
                new_len: i64 = 0;
                a = common_start;
                b = line_start;
                while a < common_start + common_len
                    and b < leading_whitespace_end
                    and a.view(1)[0] == b.view(1)[0] {
                    a = a + 1;
                    b = b + 1;
                    new_len += 1;
                }
                common_len = new_len;
                if common_len == 0 {
                    return (i64(0), ptr[u8]());
                }
            }
        }
        p = p + 1;
    }
    if common_len > 0 {
        return (common_len, common_start);
    }
    return (common_len, ptr[u8]());
}

impl unicode_mod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(v) {
        return object_new_ref(Py_NotImplemented);
    }
    return PyUnicode_Format(v, w);
}

impl unicode_subscript(self_: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != i32(0) {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += uo_length(self_);
        }
        return unicode_getitem(self_, i);
    }
    if object_is_type(item, ptr[PyTypeObject](addressof(PySlice_Type))) {
        start: i64 = 0;
        stop: i64 = 0;
        step: i64 = 0;
        if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < i32(0) {
            return NULL;
        }
        slicelength = PySlice_AdjustIndices(
            uo_length(self_), &mut start, &mut stop, step
        );
        if slicelength <= 0 {
            return unicode_get_empty();
        }
        if start == 0 and step == 1 and slicelength == uo_length(self_) {
            return unicode_result_unchanged(self_);
        }
        if step == 1 {
            return PyUnicode_Substring(self_, start, start + slicelength);
        }
        return unicode_slice_step(self_, start, step, slicelength);
    }
    PyErr_Format(
        PyExc_TypeError,
        "string indices must be integers, not '%.200s'",
        object_type(item).view(1)[0].tp_name
    );
    return NULL;
}

impl unicode_slice_step(
    self_: ptr[PyObject], start: i64, step: i64, slicelength: i64
) -> ptr[PyObject] {
    src_kind = uo_kind(self_);
    src_data = uo_data(self_);
    max_char = u32(127);
    cur = start;
    if not uo_is_ascii(self_) {
        kind_limit = kind_maxchar_limit(src_kind);
        max_char = u32(0);
        for i in range(slicelength) {
            ch = ch_read(src_kind, src_data, cur);
            if ch > max_char {
                max_char = ch;
                if max_char >= kind_limit {
                    break;
                }
            }
            cur = wrapping_add(cur, step);
        }
    }
    result = PyUnicode_New(slicelength, max_char);
    if not result {
        return NULL;
    }
    dest_kind = uo_kind(result);
    dest_data = uo_data(result);

    cur = start;
    if dest_kind != src_kind {
        for i in range(slicelength) {
            ch_write(dest_kind, dest_data, i, ch_read(src_kind, src_data, cur));
            cur = wrapping_add(cur, step);
        }
    } elif src_kind == PyUnicode_1BYTE_KIND {
        for i in range(slicelength) {
            (dest_data + i).view(1)[0] = (src_data + cur).view(1)[0];
            cur = wrapping_add(cur, step);
        }
    } elif src_kind == PyUnicode_2BYTE_KIND {
        src2 = ptr[u16](src_data);
        dest2 = ptr[u16](dest_data);
        for i in range(slicelength) {
            (dest2 + i).view(1)[0] = (src2 + cur).view(1)[0];
            cur = wrapping_add(cur, step);
        }
    } else {
        src4 = ptr[u32](src_data);
        dest4 = ptr[u32](dest_data);
        for i in range(slicelength) {
            (dest4 + i).view(1)[0] = (src4 + cur).view(1)[0];
            cur = wrapping_add(cur, step);
        }
    }
    return result;
}

impl unicode_format_getnextarg(ctx: ptr[UnicodeFormatter]) -> ptr[PyObject] {
    argidx = ctx.view(1)[0].argidx;
    if argidx < ctx.view(1)[0].arglen {
        ctx.view(1)[0].argidx = argidx + 1;
        if ctx.view(1)[0].arglen < 0 {
            return ctx.view(1)[0].args;
        }
        return PyTuple_GetItem(ctx.view(1)[0].args, argidx);
    }
    PyErr_SetString(PyExc_TypeError, "not enough arguments for format string");
    return NULL;
}

impl formatfloat(
    v: ptr[PyObject], arg: ptr[UnicodeFormatArg], writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject]] {
    x = PyFloat_AsDouble(v);
    if x == -1.0 and PyErr_Occurred() {
        return (i32(-1), NULL);
    }
    prec = arg.view(1)[0].prec;
    if prec < i32(0) {
        prec = i32(6);
    }
    dtoa_flags = i32(0);
    if (arg.view(1)[0].flags & F_ALT) != i32(0) {
        dtoa_flags = dtoa_flags | PY_DTSF_ALT;
    }
    p = PyOS_double_to_string(x, i8(arg.view(1)[0].ch), prec, dtoa_flags, None);
    if not p {
        return (i32(-1), NULL);
    }
    length = i64(strlen(p));
    output = NULL;
    if writer {
        if _PyUnicodeWriter_WriteASCIIString(writer, p, length) < i32(0) {
            PyMem_Free(ptr(p));
            return (i32(-1), NULL);
        }
    } else {
        output = _PyUnicode_FromASCII(p, length);
    }
    PyMem_Free(ptr(p));
    return (i32(0), output);
}

impl format_wants_index(conv: u32) -> bool {
    return conv == PCT_LOWER_O or conv == PCT_LOWER_X or conv == PCT_UPPER_X;
}

impl formatlong_wrongtype(v: ptr[PyObject], conv: u32) -> i32 {
    if format_wants_index(conv) {
        PyErr_Format(
            PyExc_TypeError,
            "%%%c format: an integer is required, not %.200s",
            i32(conv),
            object_type(v).view(1)[0].tp_name
        );
    } else {
        PyErr_Format(
            PyExc_TypeError,
            "%%%c format: a real number is required, not %.200s",
            i32(conv),
            object_type(v).view(1)[0].tp_name
        );
    }
    return i32(-1);
}

impl mainformatlong(
    v: ptr[PyObject], arg: ptr[UnicodeFormatArg], writer: ptr[UnicodeWriter]
) -> tuple[i32, ptr[PyObject]] {
    conv = arg.view(1)[0].ch;
    flags = arg.view(1)[0].flags;
    if PyNumber_Check(v) == i32(0) {
        return (formatlong_wrongtype(v, conv), NULL);
    }
    iobj = NULL;

    if not long_check(v) {
        if format_wants_index(conv) {
            iobj = _PyNumber_Index(v);
        } else {
            iobj = PyNumber_Long(v);
        }
        if not iobj {
            if PyErr_ExceptionMatches(PyExc_TypeError) != i32(0) {
                return (formatlong_wrongtype(v, conv), NULL);
            }
            return (i32(-1), NULL);
        }
    } else {
        iobj = object_new_ref(v);
    }
    if object_is_type(v, ptr[PyTypeObject](addressof(PyLong_Type)))
        and arg.view(1)[0].width == -1
        and arg.view(1)[0].prec == i32(-1)
        and (flags & (F_SIGN | F_BLANK)) == i32(0)
        and conv != PCT_UPPER_X {
        alternate = flags & F_ALT;
        base = i32(10);
        if conv == PCT_LOWER_O {
            base = i32(8);
        } elif conv == PCT_LOWER_X {
            base = i32(16);
        }
        if _PyLong_FormatWriter(writer, v, base, alternate) == i32(-1) {
            object_decref(iobj);
            return (i32(-1), NULL);
        }
        object_decref(iobj);
        return (i32(1), NULL);
    }
    res = _PyUnicode_FormatLong(iobj, flags & F_ALT, arg.view(1)[0].prec, i32(conv));
    object_decref(iobj);
    if not res {
        return (i32(-1), NULL);
    }
    return (i32(0), res);
}

impl formatchar(v: ptr[PyObject]) -> u32 {
    if unicode_check(v) {
        if uo_length(v) == 1 {
            return uo_read_char(v, 0);
        }
        PyErr_Format(
            PyExc_TypeError,
            "%%c requires an int or a unicode character, not a string of length %zd",
            uo_length(v)
        );
        return u32(0xFFFFFFFF);
    }
    overflow = i32(0);
    x = PyLong_AsLongAndOverflow(v, &mut overflow);
    if x == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_TypeError) != i32(0) {
            PyErr_Format(
                PyExc_TypeError, "%%c requires an int or a unicode character, not %T", v
            );
        }
        return u32(0xFFFFFFFF);
    }
    if x < 0 or x > i64(MAX_UNICODE) {
        PyErr_SetString(PyExc_OverflowError, "%c arg not in range(0x110000)");
        return u32(0xFFFFFFFF);
    }
    return u32(x);
}

impl format_more(ctx: ptr[UnicodeFormatter]) -> bool {
    ctx.view(1)[0].fmtcnt -= 1;
    return ctx.view(1)[0].fmtcnt >= 0;
}

impl format_take(ctx: ptr[UnicodeFormatter]) -> u32 {
    pos = ctx.view(1)[0].fmtpos;
    ch = ch_read(ctx.view(1)[0].fmtkind, ctx.view(1)[0].fmtdata, pos);
    ctx.view(1)[0].fmtpos = pos + 1;
    return ch;
}

impl format_is_digit(ch: u32) -> bool {
    return ch >= PCT_ZERO and ch <= PCT_NINE;
}

impl unicode_format_arg_parse(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]
) -> i32 {
    ch = arg.view(1)[0].ch;
    flags = arg.view(1)[0].flags;
    width = arg.view(1)[0].width;
    prec = arg.view(1)[0].prec;
    v = NULL;
    if ch == PCT_LPAREN {
        if not ctx.view(1)[0].dct {
            PyErr_SetString(PyExc_TypeError, "format requires a mapping");
            return i32(-1);
        }
        ctx.view(1)[0].fmtpos += 1;
        ctx.view(1)[0].fmtcnt -= 1;
        keystart = ctx.view(1)[0].fmtpos;
        pcount = 1;

        while pcount > 0 and format_more(ctx) {
            ch = format_take(ctx);
            if ch == PCT_RPAREN {
                pcount -= 1;
            } elif ch == PCT_LPAREN {
                pcount += 1;
            }
        }
        keylen = ctx.view(1)[0].fmtpos - keystart - 1;
        if ctx.view(1)[0].fmtcnt < 0 or pcount > 0 {
            PyErr_SetString(PyExc_ValueError, "incomplete format key");
            return i32(-1);
        }
        key = PyUnicode_Substring(ctx.view(1)[0].fmtstr, keystart, keystart + keylen);
        if not key {
            return i32(-1);
        }
        if ctx.view(1)[0].args_owned != 0 {
            ctx.view(1)[0].args_owned = 0;
            object_decref(ctx.view(1)[0].args);
        }
        ctx.view(1)[0].args = PyObject_GetItem(ctx.view(1)[0].dct, key);
        object_decref(key);
        if not ctx.view(1)[0].args {
            return i32(-1);
        }
        ctx.view(1)[0].args_owned = 1;
        ctx.view(1)[0].arglen = -1;
        ctx.view(1)[0].argidx = -2;
    }

    while format_more(ctx) {
        ch = format_take(ctx);
        if ch == PCT_MINUS {
            flags = flags | F_LJUST;
        } elif ch == PCT_PLUS {
            flags = flags | F_SIGN;
        } elif ch == PCT_SPACE {
            flags = flags | F_BLANK;
        } elif ch == PCT_HASH {
            flags = flags | F_ALT;
        } elif ch == PCT_ZERO {
            flags = flags | F_ZERO;
        } else {
            break;
        }
    }

    if ch == PCT_STAR {
        v = unicode_format_getnextarg(ctx);
        if not v {
            return i32(-1);
        }
        if not long_check(v) {
            PyErr_SetString(PyExc_TypeError, "* wants int");
            return i32(-1);
        }
        width = PyLong_AsSsize_t(v);
        if width == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        if width < 0 {
            flags = flags | F_LJUST;

            width = wrapping_sub(i64(0), width);
        }
        if format_more(ctx) {
            ch = format_take(ctx);
        }
    } elif format_is_digit(ch) {
        width = i64(ch - PCT_ZERO);
        while format_more(ctx) {
            ch = format_take(ctx);
            if not format_is_digit(ch) {
                break;
            }
            if width > (PY_SSIZE_T_MAX - i64(ch - PCT_ZERO)) // 10 {
                PyErr_SetString(PyExc_ValueError, "width too big");
                return i32(-1);
            }
            width = width * 10 + i64(ch - PCT_ZERO);
        }
    }

    if ch == PCT_DOT {
        prec = i32(0);
        if format_more(ctx) {
            ch = format_take(ctx);
        }
        if ch == PCT_STAR {
            v = unicode_format_getnextarg(ctx);
            if not v {
                return i32(-1);
            }
            if not long_check(v) {
                PyErr_SetString(PyExc_TypeError, "* wants int");
                return i32(-1);
            }
            prec = PyLong_AsInt(v);
            if prec == i32(-1) and PyErr_Occurred() {
                return i32(-1);
            }
            if prec < i32(0) {
                prec = i32(0);
            }
            if format_more(ctx) {
                ch = format_take(ctx);
            }
        } elif format_is_digit(ch) {
            prec = i32(ch - PCT_ZERO);
            while format_more(ctx) {
                ch = format_take(ctx);
                if not format_is_digit(ch) {
                    break;
                }
                if i64(prec) > (INT_MAX - i64(ch - PCT_ZERO)) // 10 {
                    PyErr_SetString(PyExc_ValueError, "precision too big");
                    return i32(-1);
                }
                prec = i32(i64(prec) * 10 + i64(ch - PCT_ZERO));
            }
        }
    }

    if ctx.view(1)[0].fmtcnt >= 0 {
        if ch == PCT_LOWER_H or ch == PCT_LOWER_L or ch == PCT_UPPER_L {
            if format_more(ctx) {
                ch = format_take(ctx);
            }
        }
    }
    if ctx.view(1)[0].fmtcnt < 0 {
        PyErr_SetString(PyExc_ValueError, "incomplete format");
        return i32(-1);
    }
    arg.view(1)[0].ch = ch;
    arg.view(1)[0].flags = flags;
    arg.view(1)[0].width = width;
    arg.view(1)[0].prec = prec;
    return i32(0);
}

impl unicode_format_arg_format(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]
) -> tuple[i32, ptr[PyObject]] {
    writer = ctx.view(1)[0].writer;
    if ctx.view(1)[0].fmtcnt == 0 {
        writer.view(1)[0].overallocate = u8(0);
    }
    v = unicode_format_getnextarg(ctx);
    if not v {
        return (i32(-1), NULL);
    }
    ch = arg.view(1)[0].ch;
    flags = arg.view(1)[0].flags;
    out = NULL;
    if ch == PCT_LOWER_S or ch == PCT_LOWER_R or ch == PCT_LOWER_A {
        if object_is_type(v, ptr[PyTypeObject](addressof(PyLong_Type)))
            and arg.view(1)[0].width == -1
            and arg.view(1)[0].prec == i32(-1) {
            if _PyLong_FormatWriter(writer, v, i32(10), flags & F_ALT) == i32(-1) {
                return (i32(-1), NULL);
            }
            return (i32(1), NULL);
        }
        if unicode_check_exact(v) and ch == PCT_LOWER_S {
            out = object_new_ref(v);
        } elif ch == PCT_LOWER_S {
            out = PyObject_Str(v);
        } elif ch == PCT_LOWER_R {
            out = PyObject_Repr(v);
        } else {
            out = PyObject_ASCII(v);
        }
    } elif ch == PCT_LOWER_I
        or ch == PCT_LOWER_D
        or ch == PCT_LOWER_U
        or ch == PCT_LOWER_O
        or ch == PCT_LOWER_X
        or ch == PCT_UPPER_X {
        (ret, out) = mainformatlong(v, arg, writer);
        if ret != i32(0) {
            return (ret, NULL);
        }
        arg.view(1)[0].sign = i32(1);
    } elif ch == PCT_LOWER_E
        or ch == PCT_UPPER_E
        or ch == PCT_LOWER_F
        or ch == PCT_UPPER_F
        or ch == PCT_LOWER_G
        or ch == PCT_UPPER_G {
        if arg.view(1)[0].width == -1
            and arg.view(1)[0].prec == i32(-1)
            and (flags & (F_SIGN | F_BLANK)) == i32(0) {
            (fast, unused) = formatfloat(v, arg, writer);
            if fast == i32(-1) {
                return (i32(-1), NULL);
            }
            return (i32(1), NULL);
        }
        arg.view(1)[0].sign = i32(1);
        (status, out) = formatfloat(v, arg, ptr[UnicodeWriter]());
        if status == i32(-1) {
            return (i32(-1), NULL);
        }
    } elif ch == PCT_LOWER_C {
        cch = formatchar(v);
        if cch == u32(0xFFFFFFFF) {
            return (i32(-1), NULL);
        }
        if arg.view(1)[0].width == -1 and arg.view(1)[0].prec == i32(-1) {
            if writer_write_char_inline(writer, cch) < i32(0) {
                return (i32(-1), NULL);
            }
            return (i32(1), NULL);
        }
        out = PyUnicode_FromOrdinal(i32(cch));
    } else {
        shown = i32(63);
        if ch >= u32(31) and ch <= u32(126) {
            shown = i32(ch);
        }
        PyErr_Format(
            PyExc_ValueError,
            "unsupported format character '%c' (0x%x) at index %zd",
            shown,
            i32(ch),
            ctx.view(1)[0].fmtpos - 1
        );
        return (i32(-1), NULL);
    }
    if not out {
        return (i32(-1), NULL);
    }
    return (i32(0), out);
}

impl format_put(writer: ptr[UnicodeWriter], ch: u32) {
    pos = writer.view(1)[0].pos;
    ch_write(i64(writer.view(1)[0].kind), writer.view(1)[0].data, pos, ch);
    writer.view(1)[0].pos = pos + 1;
}

impl unicode_format_arg_output(
    ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg], str_obj: ptr[PyObject]
) -> i32 {
    writer = ctx.view(1)[0].writer;
    ch = arg.view(1)[0].ch;
    flags = arg.view(1)[0].flags;
    width = arg.view(1)[0].width;
    prec = i64(arg.view(1)[0].prec);
    sign = arg.view(1)[0].sign != i32(0);
    fill = PCT_SPACE;
    if sign and (flags & F_ZERO) != i32(0) {
        fill = PCT_ZERO;
    }
    length = uo_length(str_obj);
    if (width == -1 or width <= length)
        and (prec == -1 or prec >= length)
        and (flags & (F_SIGN | F_BLANK)) == i32(0) {
        if _PyUnicodeWriter_WriteStr(writer, str_obj) == i32(-1) {
            return i32(-1);
        }
        return i32(0);
    }

    if ch == PCT_LOWER_S or ch == PCT_LOWER_R or ch == PCT_LOWER_A {
        if prec >= 0 and length > prec {
            length = prec;
        }
    }

    kind = uo_kind(str_obj);
    pbuf = uo_data(str_obj);
    pindex: i64 = 0;
    signchar = u32(0);
    if sign {
        first = ch_read(kind, pbuf, pindex);
        if first == PCT_MINUS or first == PCT_PLUS {
            signchar = first;
            length -= 1;
            pindex += 1;
        } elif (flags & F_SIGN) != i32(0) {
            signchar = PCT_PLUS;
        } elif (flags & F_BLANK) != i32(0) {
            signchar = PCT_SPACE;
        } else {
            sign = False;
        }
    }
    if width < length {
        width = length;
    }

    maxchar = writer.view(1)[0].maxchar;
    if (flags & F_LJUST) == i32(0) {
        if sign {
            if width - 1 > length and fill > maxchar {
                maxchar = fill;
            }
        } elif width > length and fill > maxchar {
            maxchar = fill;
        }
    }
    if uo_max_char_value(str_obj) > maxchar {
        strmaxchar = _PyUnicode_FindMaxChar(str_obj, 0, pindex + length);
        if strmaxchar > maxchar {
            maxchar = strmaxchar;
        }
    }
    buflen = width;
    if sign and length == width {
        buflen += 1;
    }
    if writer_prepare(writer, buflen, maxchar) == i32(-1) {
        return i32(-1);
    }

    if sign {
        if fill != PCT_SPACE {
            format_put(writer, signchar);
        }
        if width > length {
            width -= 1;
        }
    }

    alt_prefix = (flags & F_ALT) != i32(0)
        and (ch == PCT_LOWER_X or ch == PCT_UPPER_X or ch == PCT_LOWER_O);
    if alt_prefix {
        if fill != PCT_SPACE {
            format_put(writer, PCT_ZERO);
            format_put(writer, ch);
            pindex += 2;
        }
        width -= 2;
        if width < 0 {
            width = 0;
        }
        length -= 2;
    }

    if width > length and (flags & F_LJUST) == i32(0) {
        sublen = width - length;
        unicode_fill(
            i64(writer.view(1)[0].kind),
            writer.view(1)[0].data,
            fill,
            writer.view(1)[0].pos,
            sublen
        );
        writer.view(1)[0].pos += sublen;
        width = length;
    }

    if fill == PCT_SPACE {
        if sign {
            format_put(writer, signchar);
        }
        if alt_prefix {
            format_put(writer, PCT_ZERO);
            format_put(writer, ch);
            pindex += 2;
        }
    }

    if length != 0 {
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, str_obj, pindex, length
        );
        writer.view(1)[0].pos += length;
    }

    if width > length {
        sublen = width - length;
        unicode_fill(
            i64(writer.view(1)[0].kind),
            writer.view(1)[0].data,
            PCT_SPACE,
            writer.view(1)[0].pos,
            sublen
        );
        writer.view(1)[0].pos += sublen;
    }
    return i32(0);
}

impl unicode_format_arg(ctx: ptr[UnicodeFormatter], arg: ptr[UnicodeFormatArg]) -> i32 {
    ch = ch_read(ctx.view(1)[0].fmtkind, ctx.view(1)[0].fmtdata, ctx.view(1)[0].fmtpos);
    if ch == PCT_PERCENT {
        ctx.view(1)[0].fmtpos += 1;
        ctx.view(1)[0].fmtcnt -= 1;
        if writer_write_char_inline(ctx.view(1)[0].writer, PCT_PERCENT) < i32(0) {
            return i32(-1);
        }
        return i32(0);
    }
    arg.view(1)[0].ch = ch;
    arg.view(1)[0].flags = i32(0);
    arg.view(1)[0].width = -1;
    arg.view(1)[0].prec = i32(-1);
    arg.view(1)[0].sign = i32(0);
    if unicode_format_arg_parse(ctx, arg) == i32(-1) {
        return i32(-1);
    }
    (ret, str_obj) = unicode_format_arg_format(ctx, arg);
    if ret == i32(-1) {
        return i32(-1);
    }
    if ret != i32(1) {
        ret = unicode_format_arg_output(ctx, arg, str_obj);
        object_decref(str_obj);
        if ret == i32(-1) {
            return i32(-1);
        }
    }
    if ctx.view(1)[0].dct and ctx.view(1)[0].argidx < ctx.view(1)[0].arglen {
        PyErr_SetString(
            PyExc_TypeError, "not all arguments converted during string formatting"
        );
        return i32(-1);
    }
    return i32(0);
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_err(func: ptr[u8], err_msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=err_msg, exitcode=0);
}

impl interp_is_main(interp: ptr[u8]) -> bool {
    return interp == ptr[u8](_PyInterpreterState_Main());
}

impl is_immortal_object(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl set_mortal(op: ptr[PyObject], refcnt: i64) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    header.view(1)[0].ob_refcnt_full = (full - (full & 0xFFFFFFFF)) | refcnt;
}

impl hashtable_unicode_hash(key: ptr) -> u64 {
    return u64.wrap(unicode_hash(ptr[PyObject](key)));
}

impl hashtable_unicode_compare(key1: ptr, key2: ptr) -> i32 {
    obj1 = ptr[PyObject](key1);
    obj2 = ptr[PyObject](key2);
    if obj1 and obj2 {
        return i32(1) if unicode_eq(obj1, obj2) else i32(0);
    }
    return i32(1) if obj1 == obj2 else i32(0);
}

impl has_shared_intern_dict(interp: ptr[u8]) -> bool {
    flags = ptr[u64](interp_at(interp, PyInterpreterState_FEATURE_FLAGS)).view(1)[0];
    return not interp_is_main(interp)
        and (flags & Py_RTFLAGS_USE_MAIN_OBMALLOC) != u64(0);
}

impl init_interned_dict(interp: ptr[u8]) -> i32 {
    interned = NULL;
    if has_shared_intern_dict(interp) {
        interned = interned_dict(ptr[u8](_PyInterpreterState_Main()));
        object_incref(interned);
    } else {
        interned = PyDict_New();
        if not interned {
            return i32(-1);
        }
    }
    set_interned_dict(interp, interned);
    return i32(0);
}

impl clear_interned_dict(interp: ptr[u8]) {
    interned = interned_dict(interp);
    if interned {
        if not has_shared_intern_dict(interp) {
            PyDict_Clear(interned);
        }
        object_decref(interned);
        set_interned_dict(interp, NULL);
    }
}

impl init_global_interned_strings(interp: ptr[u8]) -> PyStatus {
    table = _Py_hashtable_new_full(
        ptr(hashtable_unicode_hash),
        ptr(hashtable_unicode_compare),
        ptr(),
        ptr(),
        ptr(addressof(hashtable_alloc))
    );
    set_interned_strings_table(table);
    if not table {
        PyErr_Clear();
        return status_err(
            ptr[u8]("init_global_interned_strings"),
            ptr[u8]("failed to create global interned dict")
        );
    }

    jacpy_unicode_init_static_strings(interp);
    for i in range(256) {
        intern_static(interp, latin1_char(u32(i)));
    }
    return status_ok();
}

impl clear_global_interned_strings {
    table = interned_strings_table();
    if table {
        _Py_hashtable_destroy(table);
        set_interned_strings_table(ptr());
    }
}

impl unicode_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    unicode = NULL;
    if not x {
        unicode = unicode_get_empty();
    } elif not encoding and not errors {
        unicode = PyObject_Str(x);
    } else {
        unicode = PyUnicode_FromEncodedObject(x, encoding, errors);
    }
    if unicode and type != unicode_type() {
        subtyped = unicode_subtype_new(type, unicode);
        object_decref(unicode);
        unicode = subtyped;
    }
    return unicode;
}

impl unicode_new_args(
    type: ptr[PyTypeObject],
    x: ptr[PyObject],
    encoding_obj: ptr[PyObject],
    errors_obj: ptr[PyObject]
) -> ptr[PyObject] {
    encoding = ptr[u8]();
    errors = ptr[u8]();
    if encoding_obj {
        if not unicode_check(encoding_obj) {
            _PyArg_BadArgument(
                ptr[u8]("str"),
                ptr[u8]("argument 'encoding'"),
                ptr[u8]("str"),
                encoding_obj
            );
            return NULL;
        }
        encoding = _PyUnicode_AsUTF8NoNUL(encoding_obj);
        if not encoding {
            return NULL;
        }
    }
    if errors_obj {
        if not unicode_check(errors_obj) {
            _PyArg_BadArgument(
                ptr[u8]("str"), ptr[u8]("argument 'errors'"), ptr[u8]("str"), errors_obj
            );
            return NULL;
        }
        errors = _PyUnicode_AsUTF8NoNUL(errors_obj);
        if not errors {
            return NULL;
        }
    }
    return unicode_new_impl(type, x, encoding, errors);
}

impl unicode_new_bound(args: BoundArguments) -> ptr[PyObject] {
    return unicode_new_args(
        ptr[PyTypeObject](args.context), args.values[0], args.values[1], args.values[2]
    );
}

impl unicode_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(args);
    if not kwargs and nargs <= 3 {
        return unicode_new_args(
            type,
            tuple_get_item(args, 0) if nargs >= 1 else NULL,
            tuple_get_item(args, 1) if nargs >= 2 else NULL,
            tuple_get_item(args, 2) if nargs >= 3 else NULL
        );
    }
    return invoke(
        unicode_new_signature, args, kwargs, unicode_new_bound, ptr[PyObject](type)
    );
}

impl arg_as_utf8(obj_: ptr[PyObject], name: ptr[u8]) -> ptr[u8] {
    if not unicode_check(obj_) {
        PyErr_Format(
            PyExc_TypeError, "str() argument '%s' must be str, not %T", name, obj_
        );
        return ptr[u8]();
    }
    return _PyUnicode_AsUTF8NoNUL(obj_);
}

impl unicode_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if kwnames and object_size(kwnames) != 0 {
        tup = _PyTuple_FromArray(args, nargs);
        if not tup {
            return NULL;
        }
        dct = _PyStack_AsDict(args + nargs, kwnames);
        if not dct {
            object_decref(tup);
            return NULL;
        }
        ret = unicode_new(ptr[PyTypeObject](type), tup, dct);
        object_decref(tup);
        object_decref(dct);
        return ret;
    }
    if nargs > 3 and _PyArg_CheckPositional(ptr[u8]("str"), nargs, 0, 3) == 0 {
        return NULL;
    }
    if nargs == 0 {
        return unicode_get_empty();
    }
    x = args.view(1)[0];
    if nargs == 1 {
        return PyObject_Str(x);
    }
    encoding = arg_as_utf8((args + 1).view(1)[0], ptr[u8]("encoding"));
    if not encoding {
        return NULL;
    }
    errors = ptr[u8]();
    if nargs == 3 {
        errors = arg_as_utf8((args + 2).view(1)[0], ptr[u8]("errors"));
        if not errors {
            return NULL;
        }
    }
    return PyUnicode_FromEncodedObject(x, encoding, errors);
}

impl unicode_subtype_new(
    type: ptr[PyTypeObject], unicode: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = type.view(1)[0].tp_alloc(type, 0);
    if not self_ {
        return NULL;
    }
    kind = uo_kind(unicode);
    length = uo_length(unicode);
    uo_set_length(self_, length);
    uo_set_hash(self_, uo_hash(unicode));

    st = uo_state(self_)
        & ~(
            STATE_INTERNED_MASK
            | STATE_KIND_MASK
            | STATE_COMPACT
            | STATE_ASCII
            | STATE_STATIC
        );
    st = st | (u32(kind) << STATE_KIND_SHIFT);
    if uo_is_ascii(unicode) {
        st = st | STATE_ASCII;
    }
    uo_set_state(self_, st);
    uo_set_utf8_length(self_, 0);
    uo_set_utf8(self_, ptr[u8]());
    uo_set_data_any(self_, ptr[u8]());
    share_utf8 = False;
    char_size: i64 = 4;
    if kind == PyUnicode_1BYTE_KIND {
        char_size = 1;
        if uo_max_char_value(unicode) < u32(128) {
            share_utf8 = True;
        }
    } elif kind == PyUnicode_2BYTE_KIND {
        char_size = 2;
    }

    if length > PY_SSIZE_T_MAX // char_size - 1 {
        PyErr_NoMemory();
        object_decref(self_);
        return NULL;
    }
    data = ptr[u8](PyMem_Malloc(u64((length + 1) * char_size)));
    if not data {
        PyErr_NoMemory();
        object_decref(self_);
        return NULL;
    }
    uo_set_data_any(self_, data);
    if share_utf8 {
        uo_set_utf8_length(self_, length);
        uo_set_utf8(self_, data);
    }
    jacpy_memory_copy(ptr(data), ptr(uo_data(unicode)), kind * (length + 1));
    return self_;
}

impl _init_global_state {
    if unicode_global_state_initialized {
        return;
    }
    unicode_global_state_initialized = True;

    set_bloom_linebreak(
        make_bloom_mask(
            PyUnicode_2BYTE_KIND, ptr[u8](addressof(bloom_linebreak_chars)), 8
        )
    );
}

impl intern_static(interp: ptr[u8], s: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyObject](_Py_hashtable_get(interned_strings_table(), ptr(s)));
    if r and r != s {
        object_decref(s);
        return object_new_ref(r);
    }

    if _Py_hashtable_set(interned_strings_table(), ptr(s), ptr(s)) < -1 {
        _Py_FatalErrorFunc(
            ptr[u8]("intern_static"), ptr[u8]("failed to intern static string")
        );
    }
    uo_set_interned(s, SSTATE_INTERNED_IMMORTAL_STATIC);
    return s;
}

impl immortalize_interned(s: ptr[PyObject]) {
    _Py_SetImmortal(s);
    uo_set_interned(s, SSTATE_INTERNED_IMMORTAL);
}

impl intern_common(
    interp: ptr[u8], s: ptr[PyObject], immortalize: bool
) -> ptr[PyObject] {
    if not s or not unicode_check(s) {
        return s;
    }

    if not unicode_check_exact(s) {
        return s;
    }

    state = uo_interned(s);
    if state == SSTATE_INTERNED_MORTAL {
        if immortalize {
            immortalize_interned(s);
        }
        return s;
    }
    if state != SSTATE_NOT_INTERNED {
        return s;
    }

    immortal = immortalize or is_immortal_object(s);

    if uo_length(s) == 1 and uo_kind(s) == PyUnicode_1BYTE_KIND {
        r = latin1_char(u32(uo_data(s).view(1)[0]));
        object_decref(s);
        return r;
    }

    r = ptr[PyObject](_Py_hashtable_get(interned_strings_table(), ptr(s)));
    if r {
        object_decref(s);
        return object_new_ref(r);
    }

    interned = interned_dict(interp);
    t = NULL;
    res = PyDict_SetDefaultRef(interned, s, s, &mut t);
    if res < i32(0) {
        PyErr_Clear();
        return s;
    }
    if res == i32(1) {
        object_decref(s);
        if immortal and uo_interned(t) == SSTATE_INTERNED_MORTAL {
            immortalize_interned(t);
        }
        return t;
    }

    object_decref(t);

    if not is_immortal_object(s) {
        object_decref(s);
        object_decref(s);
    }
    uo_set_interned(s, SSTATE_INTERNED_MORTAL);

    if immortal {
        immortalize_interned(s);
    }
    return s;
}

impl uiter_of(op: ptr[PyObject]) -> ptr[seqiterobject] {
    return ptr[seqiterobject](op);
}

impl unicodeiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(uiter_of(op).view(1)[0].it_seq);
    PyObject_GC_Del(ptr(op));
}

impl unicodeiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(uiter_of(op).view(1)[0].it_seq, visitor, arg);
}

impl unicodeiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = uiter_of(op);
    seq = it.view(1)[0].it_seq;
    if not seq {
        return NULL;
    }
    index = it.view(1)[0].it_index;
    if index < uo_length(seq) {
        ch = ch_read(uo_kind(seq), uo_data(seq), index);
        it.view(1)[0].it_index = index + 1;
        return unicode_char(ch);
    }
    it.view(1)[0].it_seq = NULL;
    object_decref(seq);
    return NULL;
}

impl unicode_ascii_iter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = uiter_of(op);
    seq = it.view(1)[0].it_seq;
    if not seq {
        return NULL;
    }
    index = it.view(1)[0].it_index;
    if index < uo_length(seq) {
        data = ptr[u8](seq) + PyASCIIObject_SIZE;
        ch = (data + index).view(1)[0];
        it.view(1)[0].it_index = index + 1;
        return latin1_char(u32(ch));
    }
    it.view(1)[0].it_seq = NULL;
    object_decref(seq);
    return NULL;
}

impl unicodeiter_len(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    it = uiter_of(op);
    length: i64 = 0;
    if it.view(1)[0].it_seq {
        length = uo_length(it.view(1)[0].it_seq) - it.view(1)[0].it_index;
    }
    return PyLong_FromSsize_t(length);
}

impl unicodeiter_reduce(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    it = uiter_of(op);

    iter_builtin = eval_builtin("iter");
    seq = it.view(1)[0].it_seq;
    if seq {
        return Py_BuildValue(
            ptr[u8]("N(O)n"), iter_builtin, seq, it.view(1)[0].it_index
        );
    }
    u = unicode_get_empty();
    return Py_BuildValue(ptr[u8]("N(N)"), iter_builtin, u);
}

impl unicodeiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    it = uiter_of(op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    seq = it.view(1)[0].it_seq;
    if seq {
        if index < 0 {
            index = 0;
        } elif index > uo_length(seq) {
            index = uo_length(seq);
        }
        it.view(1)[0].it_index = index;
    }
    return object_new_ref(Py_None);
}

impl unicode_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(seq) {
        PyErr_BadInternalCall();
        return NULL;
    }
    op = NULL;
    if uo_is_compact_ascii(seq) {
        op = _PyObject_GC_New(ptr[PyObject](addressof(_PyUnicodeASCIIIter_Type)));
    } else {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyUnicodeIter_Type)));
    }
    if not op {
        return NULL;
    }
    it = uiter_of(op);
    it.view(1)[0].it_index = 0;
    it.view(1)[0].it_seq = object_new_ref(seq);
    object_gc_track(op);
    return op;
}

impl encode_wstr_utf8(wstr: ptr[i32], name: ptr[u8]) -> tuple[i32, ptr[u8]] {
    (res, text, has_pos, error_pos) = encode_utf8_ex(wstr, i32(1), _Py_ERROR_STRICT);
    if res == i32(-2) {
        PyErr_Format(PyExc_RuntimeError, "cannot encode %s", name);
        return (i32(-1), ptr[u8]());
    }
    if res < i32(0) {
        PyErr_NoMemory();
        return (i32(-1), ptr[u8]());
    }
    return (i32(0), text);
}

impl config_get_codec_name(config_encoding: ptr[ptr[i32]]) -> i32 {
    (res, encoding) = encode_wstr_utf8(
        config_encoding.view(1)[0], ptr[u8]("stdio_encoding")
    );
    if res < i32(0) {
        return i32(-1);
    }
    codec = _PyCodec_Lookup(encoding);
    PyMem_RawFree(ptr(encoding));
    if not codec {
        return i32(-1);
    }
    name_obj = PyObject_GetAttrString(codec, ptr[u8]("name"));
    object_decref(codec);
    if not name_obj {
        return i32(-1);
    }
    wname = PyUnicode_AsWideCharString(name_obj, ptr[i64]());
    object_decref(name_obj);
    if not wname {
        object_decref(name_obj);
        return i32(-1);
    }
    raw_wname = _PyMem_RawWcsdup(wname);
    if not raw_wname {
        PyMem_Free(ptr(wname));
        PyErr_NoMemory();

        object_decref(name_obj);
        return i32(-1);
    }
    PyMem_RawFree(ptr(config_encoding.view(1)[0]));
    config_encoding.view(1)[0] = raw_wname;
    PyMem_Free(ptr(wname));
    return i32(0);
}

impl init_stdio_encoding(interp: ptr[u8]) -> PyStatus {
    config = _PyInterpreterState_GetConfig(interp);
    if config_get_codec_name(ptr[ptr[i32]](config + PyConfig_STDIO_ENCODING))
        < i32(0) {
        return status_err(
            ptr[u8]("init_stdio_encoding"),
            ptr[u8]("failed to get the Python codec name of the stdio encoding")
        );
    }
    return status_ok();
}

impl init_fs_codec(interp: ptr[u8]) -> i32 {
    config = _PyInterpreterState_GetConfig(interp);
    filesystem_errors = ptr[ptr[i32]](config + PyConfig_FILESYSTEM_ERRORS).view(1)[0];
    error_handler = get_error_handler_wide(filesystem_errors);
    if error_handler == _Py_ERROR_UNKNOWN {
        PyErr_SetString(PyExc_RuntimeError, "unknown filesystem error handler");
        return i32(-1);
    }
    (res, encoding) = encode_wstr_utf8(
        ptr[ptr[i32]](config + PyConfig_FILESYSTEM_ENCODING).view(1)[0],
        ptr[u8]("filesystem_encoding")
    );
    if res < i32(0) {
        return i32(-1);
    }
    (res2, errors) = encode_wstr_utf8(filesystem_errors, ptr[u8]("filesystem_errors"));
    if res2 < i32(0) {
        PyMem_RawFree(ptr(encoding));
        return i32(-1);
    }
    PyMem_RawFree(ptr(fs_codec_encoding(interp)));
    set_fs_codec_encoding(interp, encoding);

    set_fs_codec_utf8(
        interp, i32(1) if strcmp(encoding, ptr[u8]("utf-8")) == i32(0) else i32(0)
    );
    PyMem_RawFree(ptr(fs_codec_errors(interp)));
    set_fs_codec_errors(interp, errors);
    set_fs_codec_error_handler(interp, error_handler);

    if interp_is_main(interp) {
        if _Py_SetFileSystemEncoding(fs_codec_encoding(interp), fs_codec_errors(interp))
            < i32(0) {
            PyErr_NoMemory();
            return i32(-1);
        }
    }
    return i32(0);
}

impl init_fs_encoding(tstate: ptr[u8]) -> PyStatus {
    interp = ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
    config = _PyInterpreterState_GetConfig(interp);
    if config_get_codec_name(ptr[ptr[i32]](config + PyConfig_FILESYSTEM_ENCODING))
        < i32(0) {
        _Py_DumpPathConfig(tstate);
        return status_err(
            ptr[u8]("init_fs_encoding"),
            ptr[u8]("failed to get the Python codec of the filesystem encoding")
        );
    }
    if init_fs_codec(interp) < i32(0) {
        return status_err(
            ptr[u8]("init_fs_encoding"), ptr[u8]("cannot initialize filesystem codec")
        );
    }
    return status_ok();
}

impl _PyUnicode_FiniEncodings(interp: ptr[u8]) {
    PyMem_RawFree(ptr(fs_codec_encoding(interp)));
    set_fs_codec_encoding(interp, ptr[u8]());
    set_fs_codec_utf8(interp, i32(0));
    PyMem_RawFree(ptr(fs_codec_errors(interp)));
    set_fs_codec_errors(interp, ptr[u8]());
    set_fs_codec_error_handler(interp, _Py_ERROR_UNKNOWN);
}
