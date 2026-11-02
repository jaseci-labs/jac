import from c {
    obj MarshalWriter {
        has fp: ptr = ptr(),
            error: i32 = 0,
            depth: i32 = 0,
            out: ptr[PyObject] = ptr[PyObject](),
            cur: ptr[u8] = ptr[u8](),
            end: ptr[u8] = ptr[u8](),
            buf: ptr[u8] = ptr[u8](),
            hashtable: ptr = ptr(),
            version: i32 = 0,
            allow_code: i32 = 0;
    }  obj MarshalReader {
        has fp: ptr = ptr(),
            depth: i32 = 0,
            readable: ptr[PyObject] = ptr[PyObject](),
            cur: ptr[u8] = ptr[u8](),
            end: ptr[u8] = ptr[u8](),
            buf: ptr[u8] = ptr[u8](),
            buf_size: i64 = 0,
            refs: ptr[PyObject] = ptr[PyObject](),
            allow_code: i32 = 0;
    }  obj MarshalStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0,
            w18: u64 = 0,
            w19: u64 = 0,
            w20: u64 = 0,
            w21: u64 = 0,
            w22: u64 = 0,
            w23: u64 = 0,
            w24: u64 = 0,
            w25: u64 = 0,
            w26: u64 = 0,
            w27: u64 = 0,
            w28: u64 = 0,
            w29: u64 = 0,
            w30: u64 = 0,
            w31: u64 = 0,
            w32: u64 = 0,
            w33: u64 = 0,
            w34: u64 = 0,
            w35: u64 = 0,
            w36: u64 = 0,
            w37: u64 = 0,
            w38: u64 = 0,
            w39: u64 = 0;
    }  def jacpy_stack_address(slots: &mut MarshalStack) -> int;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def fputs(text: ptr[u8], stream: ptr) -> i32;  def fwrite(
        data: ptr, size: u64, count: u64, stream: ptr
    ) -> u64;  def fread(buffer: ptr, size: u64, count: u64, stream: ptr) -> u64;  def getc(
        stream: ptr
    ) -> i32;  def fileno(stream: ptr) -> i32;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def strlen(text: ptr[u8]) -> u64;  def _Py_hashtable_hash_ptr(
        key: ptr
    ) -> u64;  def _Py_hashtable_compare_direct(key1: ptr, key2: ptr) -> i32;  def _Py_hashtable_new_full(
        hash_func: ptr,
        compare_func: ptr,
        key_destroy_func: ptr,
        value_destroy_func: ptr,
        allocator: ptr
    ) -> ptr;  def _Py_hashtable_set(ht: ptr, key: ptr, value: ptr) -> i32;  def _Py_hashtable_destroy(
        ht: ptr
    );  def PyFloat_Pack8(x: f64, data: ptr[u8], le: i32) -> i32;  def PyFloat_Unpack8(
        data: ptr[u8], le: i32
    ) -> f64;  def PyComplex_RealAsDouble(op: ptr[PyObject]) -> f64;  def PyComplex_ImagAsDouble(
        op: ptr[PyObject]
    ) -> f64;  def PyComplex_FromCComplex(cval: Py_complex) -> ptr[PyObject];  def PyLongWriter_Discard(
        writer: ptr[PyLongWriter]
    );  def PyUnicode_DecodeUTF8(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyUnicode_InternImmortal(
        interp: ptr[u8], p: &mut ptr[PyObject]
    );  def _PySet_NextEntryRef(
        set: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _PyCode_GetCode(co: ptr[PyObject]) -> ptr[PyObject];  def _PyCode_Validate(
        con: ptr[u8]
    ) -> i32;  def _PyCode_New(con: ptr[u8]) -> ptr[PyObject];  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len_: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyMemoryView_FromBuffer(info: ptr[Py_buffer]) -> ptr[PyObject];  def _PyObject_CallMethod(
        obj_: ptr[PyObject], name: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];
}

glob Py_MARSHAL_VERSION: Final[i32] = 5;

glob:priv MAX_MARSHAL_STACK_DEPTH: Final[i32] = 2000,
     TYPE_NULL: Final[i32] = 48,
     TYPE_NONE: Final[i32] = 78,
     TYPE_FALSE: Final[i32] = 70,
     TYPE_TRUE: Final[i32] = 84,
     TYPE_STOPITER: Final[i32] = 83,
     TYPE_ELLIPSIS: Final[i32] = 46,
     TYPE_BINARY_FLOAT: Final[i32] = 103,
     TYPE_BINARY_COMPLEX: Final[i32] = 121,
     TYPE_LONG: Final[i32] = 108,
     TYPE_STRING: Final[i32] = 115,
     TYPE_TUPLE: Final[i32] = 40,
     TYPE_LIST: Final[i32] = 91,
     TYPE_DICT: Final[i32] = 123,
     TYPE_CODE: Final[i32] = 99,
     TYPE_UNICODE: Final[i32] = 117,
     TYPE_UNKNOWN: Final[i32] = 63,
     TYPE_SET: Final[i32] = 60,
     TYPE_FROZENSET: Final[i32] = 62,
     TYPE_SLICE: Final[i32] = 58,
     TYPE_INTERNED: Final[i32] = 116,
     TYPE_ASCII: Final[i32] = 97,
     TYPE_ASCII_INTERNED: Final[i32] = 65,
     TYPE_SHORT_ASCII: Final[i32] = 122,
     TYPE_SHORT_ASCII_INTERNED: Final[i32] = 90,
     TYPE_INT: Final[i32] = 105,
     TYPE_SMALL_TUPLE: Final[i32] = 41,
     TYPE_COMPLEX: Final[i32] = 120,
     TYPE_FLOAT: Final[i32] = 102,
     TYPE_INT64: Final[i32] = 73,
     TYPE_REF: Final[i32] = 114,
     FLAG_REF: Final[i32] = 128,
     WFERR_OK: Final[i32] = 0,
     WFERR_UNMARSHALLABLE: Final[i32] = 1,
     WFERR_NESTEDTOODEEP: Final[i32] = 2,
     WFERR_NOMEMORY: Final[i32] = 3,
     WFERR_CODE_NOT_ALLOWED: Final[i32] = 4,
     SIZE32_MAX: Final[i64] = 0x7FFFFFFF,
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     PyLong_MARSHAL_SHIFT: Final[i64] = 15,
     PyLong_MARSHAL_BASE: Final[i32] = 32768,
     PyLong_MARSHAL_MASK: Final[i64] = 0x7FFF,
     PyUnicode_1BYTE_KIND: Final[i32] = 1,
     EOF: Final[i32] = -1,
     REASONABLE_FILE_LIMIT: Final[i64] = 262144,
     FILE_BUFFER_OFFSET: Final[i64] = 80,
     FILE_BUFFER_SIZE: Final[i64] = 240,
     STACK_SLOTS_SIZE: Final[i64] = 320;

def is_exact(op: ptr[PyObject], tp: ptr[PyObject]) -> bool;

def py_id(offset: i64) -> ptr[PyObject];

def bytes_data(op: ptr[PyObject]) -> ptr[u8];

def list_slot(op: ptr[PyObject], i: i64) -> ptr[ptr[PyObject]];

def unicode_state(op: ptr[PyObject]) -> u32;

def unicode_interned(op: ptr[PyObject]) -> bool;

def unicode_ascii(op: ptr[PyObject]) -> bool;

def unicode_latin1_data(op: ptr[PyObject]) -> ptr[u8];

def unicode_len(op: ptr[PyObject]) -> i64;

def code_int(co: ptr[PyObject], offset: i64) -> i64;

def code_obj(co: ptr[PyObject], offset: i64) -> ptr[PyObject];

def flag_of(value: bool) -> i32;

def w_flush(p: ptr[MarshalWriter]);

def w_reserve(p: ptr[MarshalWriter], needed: i64) -> i32;

def w_byte(c: i32, p: ptr[MarshalWriter]);

def w_string(s: ptr[u8], n: i64, p: ptr[MarshalWriter]);

def w_short(x: i64, p: ptr[MarshalWriter]);

def w_long(x: i64, p: ptr[MarshalWriter]);

def w_size(n: i64, p: ptr[MarshalWriter]) -> bool;

def w_pstring(s: ptr[u8], n: i64, p: ptr[MarshalWriter]);

def w_short_pstring(s: ptr[u8], n: i64, p: ptr[MarshalWriter]);

def _r_digits32(
    digits: ptr[u32], n: i64, negative: u8, marshal_ratio: i64, p: ptr[MarshalWriter]
);

def _r_digits16(
    digits: ptr[u16], n: i64, negative: u8, marshal_ratio: i64, p: ptr[MarshalWriter]
);

def w_PyLong(ob: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_float_bin(v: f64, p: ptr[MarshalWriter]);

def w_float_str(v: f64, p: ptr[MarshalWriter]);

def hashtable_entry(
    p: ptr[MarshalWriter], v: ptr[PyObject]
) -> ptr[_Py_hashtable_entry_t];

def w_ref(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) -> tuple[bool, i32];

def w_complete(v: ptr[PyObject], p: ptr[MarshalWriter]);

def w_object(v: ptr[PyObject], p: ptr[MarshalWriter]);

def w_long_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_unicode_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_set_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_code_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_buffer_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_complex_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]);

def w_decref_entry(key: ptr);

def w_init_refs(p: ptr[MarshalWriter], version: i32) -> i32;

def w_clear_refs(p: ptr[MarshalWriter]);

def write_object_to_string(
    x: ptr[PyObject], version: i32, allow_code: i32
) -> ptr[PyObject];

def r_readinto(p: ptr[MarshalReader], n: i64) -> i64;

def r_string_slow(n: i64, p: ptr[MarshalReader]) -> ptr[u8];

def r_string(n: i64, p: ptr[MarshalReader]) -> ptr[u8];

def r_byte(p: ptr[MarshalReader]) -> i32;

def r_short(p: ptr[MarshalReader]) -> i32;

def r_long(p: ptr[MarshalReader]) -> i64;

def r_long64(p: ptr[MarshalReader]) -> ptr[PyObject];

def bad_digit -> i32;

def _w_digits32(
    digits: ptr[u32],
    size: i64,
    marshal_ratio: i64,
    shorts_in_top_digit: i32,
    p: ptr[MarshalReader]
) -> i32;

def _w_digits16(
    digits: ptr[u16],
    size: i64,
    marshal_ratio: i64,
    shorts_in_top_digit: i32,
    p: ptr[MarshalReader]
) -> i32;

def r_PyLong(p: ptr[MarshalReader]) -> ptr[PyObject];

def r_float_bin(p: ptr[MarshalReader]) -> f64;

def r_float_str(p: ptr[MarshalReader]) -> f64;

def r_ref_reserve(flag: i32, p: ptr[MarshalReader]) -> i64;

def r_ref_insert(
    o: ptr[PyObject], idx: i64, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject];

def r_ref(o: ptr[PyObject], flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_float_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_complex_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_bytes_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_ascii_object(
    n: i64, is_interned: bool, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject];

def r_unicode_object(
    is_interned: bool, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject];

def r_tuple_object(n: i64, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_list_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_dict_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_set_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def con_set_int(con: ptr[u8], offset: i64, value: i32);

def con_set_obj(con: ptr[u8], offset: i64, value: ptr[PyObject]);

def con_obj(con: ptr[u8], offset: i64) -> ptr[PyObject];

def r_code_int(con: ptr[u8], offset: i64, p: ptr[MarshalReader]) -> bool;

def r_code_obj(con: ptr[u8], offset: i64, p: ptr[MarshalReader]) -> bool;

def r_code_fields(con: ptr[u8], p: ptr[MarshalReader]) -> bool;

def r_code_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_ref_object(p: ptr[MarshalReader]) -> ptr[PyObject];

def r_slice_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject];

def r_object(p: ptr[MarshalReader]) -> ptr[PyObject];

def read_object(p: ptr[MarshalReader]) -> ptr[PyObject];

def read_object_from(
    fp: ptr, readable: ptr[PyObject], data: ptr[u8], length: i64, allow_code: i32
) -> ptr[PyObject];

def read_from_file(fp: ptr) -> ptr[PyObject];

def read_from_string(data: ptr[u8], length: i64) -> ptr[PyObject];

def getfilesize(fp: ptr) -> i64;

import from c {
    def PyMarshal_WriteLongToFile(x: i64, fp: ptr, version: i32) {
        slots: own MarshalStack = MarshalStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        p = ptr[MarshalWriter](base);
        buf = base + FILE_BUFFER_OFFSET;
        p.view(1)[0].fp = fp;
        p.view(1)[0].buf = buf;
        p.view(1)[0].cur = buf;
        p.view(1)[0].end = buf + 4;
        p.view(1)[0].error = WFERR_OK;
        p.view(1)[0].version = version;
        w_long(x, p);
        w_flush(p);
    }  def PyMarshal_WriteObjectToFile(x: ptr[PyObject], fp: ptr, version: i32) {
        if PySys_Audit(ptr[u8]("marshal.dumps"), ptr[u8]("Oi"), x, version) < 0 {
            return;
        }
        slots: own MarshalStack = MarshalStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        p = ptr[MarshalWriter](base);
        buf = base + FILE_BUFFER_OFFSET;
        p.view(1)[0].fp = fp;
        p.view(1)[0].buf = buf;
        p.view(1)[0].cur = buf;
        p.view(1)[0].end = buf + FILE_BUFFER_SIZE;
        p.view(1)[0].error = WFERR_OK;
        p.view(1)[0].version = version;
        p.view(1)[0].allow_code = 1;
        if w_init_refs(p, version) != 0 {
            return;
        }
        w_object(x, p);
        w_clear_refs(p);
        w_flush(p);
    }  def PyMarshal_ReadShortFromFile(fp: ptr) -> i32 {
        slots: own MarshalStack = MarshalStack();
        p = ptr[MarshalReader](jacpy_stack_address(&mut slots));
        p.view(1)[0].fp = fp;
        res = r_short(p);
        if p.view(1)[0].buf {
            PyMem_Free(ptr(p.view(1)[0].buf));
        }
        return res;
    }  def PyMarshal_ReadLongFromFile(fp: ptr) -> i64 {
        slots: own MarshalStack = MarshalStack();
        p = ptr[MarshalReader](jacpy_stack_address(&mut slots));
        p.view(1)[0].fp = fp;
        res = r_long(p);
        if p.view(1)[0].buf {
            PyMem_Free(ptr(p.view(1)[0].buf));
        }
        return res;
    }  def PyMarshal_ReadLastObjectFromFile(fp: ptr) -> ptr[PyObject] {
        filesize = getfilesize(fp);
        if filesize > 0 and filesize <= REASONABLE_FILE_LIMIT {
            block = PyMem_Malloc(u64(filesize));
            if block {
                n = fread(block, u64(1), u64(filesize), fp);
                v = read_from_string(ptr[u8](block), i64(n));
                PyMem_Free(block);
                return v;
            }
        }
        return read_from_file(fp);
    }  def PyMarshal_ReadObjectFromFile(fp: ptr) -> ptr[PyObject] {
        return read_from_file(fp);
    }  def PyMarshal_ReadObjectFromString(data: ptr[u8], length: i64) -> ptr[PyObject] {
        return read_from_string(data, length);
    }  def PyMarshal_WriteObjectToString(
        x: ptr[PyObject], version: i32
    ) -> ptr[PyObject] {
        return write_object_to_string(x, version, i32(1));
    }
}

def marshal_dump_impl(
    module: ptr[PyObject],
    value: ptr[PyObject],
    file: ptr[PyObject],
    version: i32,
    allow_code: bool
) -> ptr[PyObject];

def marshal_load_impl(
    module: ptr[PyObject], file: ptr[PyObject], allow_code: bool
) -> ptr[PyObject];

def marshal_dumps_impl(
    module: ptr[PyObject], value: ptr[PyObject], version: i32, allow_code: bool
) -> ptr[PyObject];

def marshal_loads_impl(
    module: ptr[PyObject], bytes_: BufferArgument, allow_code: bool
) -> ptr[PyObject];

def marshal_module_exec(module: ptr[PyObject]) -> i32;

impl is_exact(op: ptr[PyObject], tp: ptr[PyObject]) -> bool {
    return ptr[PyObject](ptr[_object](op).view(1)[0].ob_type) == tp;
}

impl py_id(offset: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_GLOBAL_STRINGS + offset
    );
}

impl bytes_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl list_slot(op: ptr[PyObject], i: i64) -> ptr[ptr[PyObject]] {
    return ptr[PyListObject](op).view(1)[0].ob_item + i;
}

impl unicode_state(op: ptr[PyObject]) -> u32 {
    return ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0];
}

impl unicode_interned(op: ptr[PyObject]) -> bool {
    return (unicode_state(op) & u32(3)) != u32(0);
}

impl unicode_ascii(op: ptr[PyObject]) -> bool {
    return (unicode_state(op) & u32(0x40)) != u32(0);
}

impl unicode_latin1_data(op: ptr[PyObject]) -> ptr[u8] {
    if (unicode_state(op) & u32(0x20)) != u32(0) {
        return ptr[u8](op) + PyASCIIObject_SIZE;
    }
    return ptr[ptr[u8]](ptr[u8](op) + PyUnicodeObject_DATA).view(1)[0];
}

impl unicode_len(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl code_int(co: ptr[PyObject], offset: i64) -> i64 {
    return i64(ptr[i32](ptr[u8](co) + offset).view(1)[0]);
}

impl code_obj(co: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](co) + offset).view(1)[0];
}

impl flag_of(value: bool) -> i32 {
    if value {
        return i32(1);
    }
    return i32(0);
}

impl w_flush(p: ptr[MarshalWriter]) {
    buf = p.view(1)[0].buf;
    fwrite(ptr(buf), u64(1), u64(int(p.view(1)[0].cur) - int(buf)), p.view(1)[0].fp);
    p.view(1)[0].cur = buf;
}

impl w_reserve(p: ptr[MarshalWriter], needed: i64) -> i32 {
    if not p.view(1)[0].cur {
        return i32(0);
    }
    if p.view(1)[0].fp {
        w_flush(p);
        if needed <= i64(int(p.view(1)[0].end) - int(p.view(1)[0].cur)) {
            return i32(1);
        }
        return i32(0);
    }
    pos = i64(int(p.view(1)[0].cur) - int(p.view(1)[0].buf));
    size = object_size(p.view(1)[0].out);
    delta: i64 = 0;
    if size > 16 * 1024 * 1024 {
        delta = size >> 3;
    } else {
        delta = size + 1024;
    }
    if needed > delta {
        delta = needed;
    }
    if delta > PY_SSIZE_T_MAX - size {
        p.view(1)[0].error = WFERR_NOMEMORY;
        return i32(0);
    }
    size += delta;
    out = p.view(1)[0].out;
    status = _PyBytes_Resize(&mut out, size);
    p.view(1)[0].out = out;
    if status != 0 {
        p.view(1)[0].buf = ptr[u8]();
        p.view(1)[0].cur = ptr[u8]();
        p.view(1)[0].end = ptr[u8]();
        return i32(0);
    }
    buf = bytes_data(out);
    p.view(1)[0].buf = buf;
    p.view(1)[0].cur = buf + pos;
    p.view(1)[0].end = buf + size;
    return i32(1);
}

impl w_byte(c: i32, p: ptr[MarshalWriter]) {
    if p.view(1)[0].cur != p.view(1)[0].end or w_reserve(p, 1) != 0 {
        cur = p.view(1)[0].cur;
        cur.view(1)[0] = u8.wrap(c);
        p.view(1)[0].cur = cur + 1;
    }
}

impl w_string(s: ptr[u8], n: i64, p: ptr[MarshalWriter]) {
    if n == 0 or not p.view(1)[0].cur {
        return;
    }
    m = i64(int(p.view(1)[0].end) - int(p.view(1)[0].cur));
    if p.view(1)[0].fp {
        if n <= m {
            memcpy(ptr(p.view(1)[0].cur), ptr(s), u64(n));
            p.view(1)[0].cur = p.view(1)[0].cur + n;
        } else {
            w_flush(p);
            fwrite(ptr(s), u64(1), u64(n), p.view(1)[0].fp);
        }
    } elif n <= m or w_reserve(p, n - m) != 0 {
        memcpy(ptr(p.view(1)[0].cur), ptr(s), u64(n));
        p.view(1)[0].cur = p.view(1)[0].cur + n;
    }
}

impl w_short(x: i64, p: ptr[MarshalWriter]) {
    w_byte(i32(x & 0xff), p);
    w_byte(i32((x >> 8) & 0xff), p);
}

impl w_long(x: i64, p: ptr[MarshalWriter]) {
    w_byte(i32(x & 0xff), p);
    w_byte(i32((x >> 8) & 0xff), p);
    w_byte(i32((x >> 16) & 0xff), p);
    w_byte(i32((x >> 24) & 0xff), p);
}

impl w_size(n: i64, p: ptr[MarshalWriter]) -> bool {
    if n > SIZE32_MAX {
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return False;
    }
    w_long(n, p);
    return True;
}

impl w_pstring(s: ptr[u8], n: i64, p: ptr[MarshalWriter]) {
    if not w_size(n, p) {
        return;
    }
    w_string(s, n, p);
}

impl w_short_pstring(s: ptr[u8], n: i64, p: ptr[MarshalWriter]) {
    w_byte(i32(n & 0xff), p);
    w_string(s, n, p);
}

impl _r_digits32(
    digits: ptr[u32], n: i64, negative: u8, marshal_ratio: i64, p: ptr[MarshalWriter]
) {
    l = (n - 1) * marshal_ratio;
    d = (digits + (n - 1)).view(1)[0];
    while True {
        d = d >> u32(15);
        l += 1;
        if d == u32(0) {
            break;
        }
    }
    if l > SIZE32_MAX {
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    if negative != u8(0) {
        w_long(-l, p);
    } else {
        w_long(l, p);
    }
    i: i64 = 0;
    while i < n - 1 {
        d = (digits + i).view(1)[0];
        j: i64 = 0;
        while j < marshal_ratio {
            w_short(i64(d) & PyLong_MARSHAL_MASK, p);
            d = d >> u32(15);
            j += 1;
        }
        i += 1;
    }
    d = (digits + (n - 1)).view(1)[0];
    while True {
        w_short(i64(d) & PyLong_MARSHAL_MASK, p);
        d = d >> u32(15);
        if d == u32(0) {
            break;
        }
    }
}

impl _r_digits16(
    digits: ptr[u16], n: i64, negative: u8, marshal_ratio: i64, p: ptr[MarshalWriter]
) {
    l = (n - 1) * marshal_ratio;
    d = (digits + (n - 1)).view(1)[0];
    while True {
        d = d >> u16(15);
        l += 1;
        if d == u16(0) {
            break;
        }
    }
    if l > SIZE32_MAX {
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    if negative != u8(0) {
        w_long(-l, p);
    } else {
        w_long(l, p);
    }
    i: i64 = 0;
    while i < n - 1 {
        d = (digits + i).view(1)[0];
        j: i64 = 0;
        while j < marshal_ratio {
            w_short(i64(d) & PyLong_MARSHAL_MASK, p);
            d = d >> u16(15);
            j += 1;
        }
        i += 1;
    }
    d = (digits + (n - 1)).view(1)[0];
    while True {
        w_short(i64(d) & PyLong_MARSHAL_MASK, p);
        d = d >> u16(15);
        if d == u16(0) {
            break;
        }
    }
}

impl w_PyLong(ob: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    w_byte(TYPE_LONG | flag, p);
    if (ptr[PyLongObject](ob).view(1)[0].long_value.lv_tag & u64(3)) == u64(1) {
        w_long(0, p);
        return;
    }
    long_export = PyLongExport();
    if PyLong_Export(ob, &mut long_export) < 0 {
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    if not long_export.digits {
        value = long_export.value;
        sign: i64 = 1;
        abs_value: u64 = 0;
        if value < 0 {
            sign = -1;
            abs_value = u64(-(value + 1)) + u64(1);
        } else {
            abs_value = u64(value);
        }
        d = abs_value;
        l: i64 = 0;
        while True {
            d = d >> u64(15);
            l += sign;
            if d == u64(0) {
                break;
            }
        }
        w_long(l, p);
        d = abs_value;
        while True {
            w_short(i64(d & u64(0x7FFF)), p);
            d = d >> u64(15);
            if d == u64(0) {
                break;
            }
        }
        return;
    }
    layout = PyLong_GetNativeLayout();
    marshal_ratio = i64(layout.view(1)[0].bits_per_digit) // PyLong_MARSHAL_SHIFT;
    if layout.view(1)[0].digit_size == u8(4) {
        _r_digits32(
            ptr[u32](long_export.digits),
            long_export.ndigits,
            long_export.negative,
            marshal_ratio,
            p
        );
    } else {
        _r_digits16(
            ptr[u16](long_export.digits),
            long_export.ndigits,
            long_export.negative,
            marshal_ratio,
            p
        );
    }
    PyLong_FreeExport(&mut long_export);
}

impl w_float_bin(v: f64, p: ptr[MarshalWriter]) {
    cur = p.view(1)[0].cur;
    if cur and i64(int(p.view(1)[0].end) - int(cur)) >= 8 {
        if PyFloat_Pack8(v, cur, i32(1)) < 0 {
            p.view(1)[0].error = WFERR_UNMARSHALLABLE;
            return;
        }
        p.view(1)[0].cur = cur + 8;
        return;
    }
    slots: own MarshalStack = MarshalStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    if PyFloat_Pack8(v, buf, i32(1)) < 0 {
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    w_string(buf, 8, p);
}

impl w_float_str(v: f64, p: ptr[MarshalWriter]) {
    buf = PyOS_double_to_string(v, i8(103), i32(17), i32(0), None);
    if not buf {
        p.view(1)[0].error = WFERR_NOMEMORY;
        return;
    }
    w_short_pstring(buf, i64(strlen(buf)), p);
    PyMem_Free(ptr(buf));
}

impl hashtable_entry(
    p: ptr[MarshalWriter], v: ptr[PyObject]
) -> ptr[_Py_hashtable_entry_t] {
    t = ptr[_Py_hashtable_t](p.view(1)[0].hashtable);
    return t.view(1)[0].get_entry_func(t, ptr(v));
}

impl w_ref(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) -> tuple[bool, i32] {
    if p.view(1)[0].version < 3 or not p.view(1)[0].hashtable {
        return (False, flag);
    }
    if object_refcount(v) == 1
        and not (is_exact(v, addressof(PyUnicode_Type)) and unicode_interned(v)) {
        return (False, flag);
    }
    ent = hashtable_entry(p, v);
    if ent {
        w = u64.wrap(int(ent.view(1)[0].value));
        if (w & u64(0x80000000)) != u64(0) {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("cannot marshal recursion %T objects"), v
            );
            p.view(1)[0].error = WFERR_UNMARSHALLABLE;
            return (True, flag);
        }
        w_byte(TYPE_REF, p);
        w_long(i64(w), p);
        return (True, flag);
    }
    t = ptr[_Py_hashtable_t](p.view(1)[0].hashtable);
    w = t.view(1)[0].nentries;
    if w >= u64(0x7fffffff) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("too many objects"));
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return (True, flag);
    }
    if is_exact(v, addressof(PyCode_Type)) or is_exact(v, addressof(PySlice_Type)) {
        w = w | u64(0x80000000);
    }
    if _Py_hashtable_set(ptr(t), ptr(object_new_ref(v)), ptr(i64(w))) < 0 {
        object_decref(v);
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return (True, flag);
    }
    return (False, flag | FLAG_REF);
}

impl w_complete(v: ptr[PyObject], p: ptr[MarshalWriter]) {
    if p.view(1)[0].version < 3 or not p.view(1)[0].hashtable {
        return;
    }
    if object_refcount(v) == 1 {
        return;
    }
    ent = hashtable_entry(p, v);
    if not ent {
        return;
    }
    w = u64.wrap(int(ent.view(1)[0].value)) & u64(0xFFFFFFFF7FFFFFFF);
    ent.view(1)[0].value = ptr(i64(w));
}

impl w_object(v: ptr[PyObject], p: ptr[MarshalWriter]) {
    if p.view(1)[0].error != WFERR_OK {
        return;
    }
    depth = p.view(1)[0].depth + 1;
    p.view(1)[0].depth = depth;
    if depth > MAX_MARSHAL_STACK_DEPTH {
        p.view(1)[0].error = WFERR_NESTEDTOODEEP;
    } elif v == NULL {
        w_byte(TYPE_NULL, p);
    } elif v == Py_None {
        w_byte(TYPE_NONE, p);
    } elif v == PyExc_StopIteration {
        w_byte(TYPE_STOPITER, p);
    } elif v == Py_Ellipsis {
        w_byte(TYPE_ELLIPSIS, p);
    } elif v == ptr[PyObject](addressof(_Py_FalseStruct)) {
        w_byte(TYPE_FALSE, p);
    } elif v == ptr[PyObject](addressof(_Py_TrueStruct)) {
        w_byte(TYPE_TRUE, p);
    } else {
        (handled, flag) = w_ref(v, i32(0), p);
        if not handled {
            w_complex_object(v, flag, p);
        }
    }
    p.view(1)[0].depth = p.view(1)[0].depth - 1;
}

impl w_long_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    overflow: i32 = 0;
    x = PyLong_AsLongAndOverflow(v, &mut overflow);
    if overflow != 0 {
        w_PyLong(v, flag, p);
        return;
    }
    y = x >> 31;
    if y != 0 and y != -1 {
        w_PyLong(v, flag, p);
    } else {
        w_byte(TYPE_INT | flag, p);
        w_long(x, p);
    }
}

impl w_unicode_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    if p.view(1)[0].version >= 4 and unicode_ascii(v) {
        length = unicode_len(v);
        if length < 256 {
            if unicode_interned(v) {
                w_byte(TYPE_SHORT_ASCII_INTERNED | flag, p);
            } else {
                w_byte(TYPE_SHORT_ASCII | flag, p);
            }
            w_short_pstring(unicode_latin1_data(v), length, p);
        } else {
            if unicode_interned(v) {
                w_byte(TYPE_ASCII_INTERNED | flag, p);
            } else {
                w_byte(TYPE_ASCII | flag, p);
            }
            w_pstring(unicode_latin1_data(v), length, p);
        }
        return;
    }
    utf8 = PyUnicode_AsEncodedString(v, ptr[u8]("utf8"), ptr[u8]("surrogatepass"));
    if not utf8 {
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    if p.view(1)[0].version >= 3 and unicode_interned(v) {
        w_byte(TYPE_INTERNED | flag, p);
    } else {
        w_byte(TYPE_UNICODE | flag, p);
    }
    w_pstring(bytes_data(utf8), object_size(utf8), p);
    object_decref(utf8);
}

impl w_set_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    if is_exact(v, addressof(PyFrozenSet_Type)) {
        w_byte(TYPE_FROZENSET | flag, p);
    } else {
        w_byte(TYPE_SET | flag, p);
    }
    n = ptr[PySetObject](v).view(1)[0].used;
    if not w_size(n, p) {
        return;
    }
    pairs = PyList_New(n);
    if not pairs {
        p.view(1)[0].error = WFERR_NOMEMORY;
        return;
    }
    i: i64 = 0;
    pos: i64 = 0;
    value = NULL;
    hash: i64 = 0;
    while _PySet_NextEntryRef(v, &mut pos, &mut value, &mut hash) != 0 {
        dump = write_object_to_string(
            value, p.view(1)[0].version, p.view(1)[0].allow_code
        );
        if not dump {
            p.view(1)[0].error = WFERR_UNMARSHALLABLE;
            object_decref(value);
            break;
        }
        pair = PyTuple_Pack(i64(2), dump, value);
        object_decref(dump);
        object_decref(value);
        if not pair {
            p.view(1)[0].error = WFERR_NOMEMORY;
            break;
        }
        list_slot(pairs, i).view(1)[0] = pair;
        i += 1;
    }
    error = p.view(1)[0].error;
    if error == WFERR_UNMARSHALLABLE or error == WFERR_NOMEMORY {
        object_decref(pairs);
        return;
    }
    if PyList_Sort(pairs) != 0 {
        p.view(1)[0].error = WFERR_NOMEMORY;
        object_decref(pairs);
        return;
    }
    k: i64 = 0;
    while k < n {
        pair_item = list_slot(pairs, k).view(1)[0];
        w_object(tuple_get_item(pair_item, 1), p);
        k += 1;
    }
    object_decref(pairs);
}

impl w_code_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    if p.view(1)[0].allow_code == 0 {
        p.view(1)[0].error = WFERR_CODE_NOT_ALLOWED;
        return;
    }
    co_code = _PyCode_GetCode(v);
    if not co_code {
        p.view(1)[0].error = WFERR_NOMEMORY;
        return;
    }
    w_byte(TYPE_CODE | flag, p);
    w_long(code_int(v, PyCodeObject_ARGCOUNT), p);
    w_long(code_int(v, PyCodeObject_POSONLYARGCOUNT), p);
    w_long(code_int(v, PyCodeObject_KWONLYARGCOUNT), p);
    w_long(code_int(v, PyCodeObject_STACKSIZE), p);
    w_long(code_int(v, PyCodeObject_FLAGS), p);
    w_object(co_code, p);
    w_object(code_obj(v, PyCodeObject_CONSTS), p);
    w_object(code_obj(v, PyCodeObject_NAMES), p);
    w_object(code_obj(v, PyCodeObject_LOCALSPLUSNAMES), p);
    w_object(code_obj(v, PyCodeObject_LOCALSPLUSKINDS), p);
    w_object(code_obj(v, PyCodeObject_FILENAME), p);
    w_object(code_obj(v, PyCodeObject_NAME), p);
    w_object(code_obj(v, PyCodeObject_QUALNAME), p);
    w_long(code_int(v, PyCodeObject_FIRSTLINENO), p);
    w_object(code_obj(v, PyCodeObject_LINETABLE), p);
    w_object(code_obj(v, PyCodeObject_EXCEPTIONTABLE), p);
    object_decref(co_code);
    w_complete(v, p);
}

impl w_buffer_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    slots: own MarshalStack = MarshalStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(v, view, PyBUF_SIMPLE) != 0 {
        w_byte(TYPE_UNKNOWN, p);
        p.view(1)[0].depth = p.view(1)[0].depth - 1;
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
        return;
    }
    w_byte(TYPE_STRING | flag, p);
    w_pstring(ptr[u8](view.view(1)[0].buf), view.view(1)[0].length, p);
    PyBuffer_Release(view);
}

impl w_complex_object(v: ptr[PyObject], flag: i32, p: ptr[MarshalWriter]) {
    if is_exact(v, addressof(PyLong_Type)) {
        w_long_object(v, flag, p);
    } elif is_exact(v, addressof(PyFloat_Type)) {
        fval = ptr[PyFloatObject](v).view(1)[0].ob_fval;
        if p.view(1)[0].version > 1 {
            w_byte(TYPE_BINARY_FLOAT | flag, p);
            w_float_bin(fval, p);
        } else {
            w_byte(TYPE_FLOAT | flag, p);
            w_float_str(fval, p);
        }
    } elif is_exact(v, addressof(PyComplex_Type)) {
        if p.view(1)[0].version > 1 {
            w_byte(TYPE_BINARY_COMPLEX | flag, p);
            w_float_bin(PyComplex_RealAsDouble(v), p);
            w_float_bin(PyComplex_ImagAsDouble(v), p);
        } else {
            w_byte(TYPE_COMPLEX | flag, p);
            w_float_str(PyComplex_RealAsDouble(v), p);
            w_float_str(PyComplex_ImagAsDouble(v), p);
        }
    } elif is_exact(v, addressof(PyBytes_Type)) {
        w_byte(TYPE_STRING | flag, p);
        w_pstring(bytes_data(v), object_size(v), p);
    } elif is_exact(v, addressof(PyUnicode_Type)) {
        w_unicode_object(v, flag, p);
    } elif is_exact(v, addressof(PyTuple_Type)) {
        n = object_size(v);
        if p.view(1)[0].version >= 4 and n < 256 {
            w_byte(TYPE_SMALL_TUPLE | flag, p);
            w_byte(i32(n), p);
        } else {
            w_byte(TYPE_TUPLE | flag, p);
            if not w_size(n, p) {
                return;
            }
        }
        i: i64 = 0;
        while i < n {
            w_object(tuple_get_item(v, i), p);
            i += 1;
        }
    } elif is_exact(v, addressof(PyList_Type)) {
        w_byte(TYPE_LIST | flag, p);
        n = object_size(v);
        if not w_size(n, p) {
            return;
        }
        i: i64 = 0;
        while i < n {
            w_object(list_slot(v, i).view(1)[0], p);
            i += 1;
        }
    } elif is_exact(v, addressof(PyDict_Type)) {
        w_byte(TYPE_DICT | flag, p);
        pos: i64 = 0;
        key = NULL;
        value = NULL;
        while PyDict_Next(v, &mut pos, &mut key, &mut value) != 0 {
            w_object(key, p);
            w_object(value, p);
        }
        w_object(NULL, p);
    } elif is_exact(v, addressof(PySet_Type))
        or is_exact(v, addressof(PyFrozenSet_Type)) {
        w_set_object(v, flag, p);
    } elif is_exact(v, addressof(PyCode_Type)) {
        w_code_object(v, flag, p);
    } elif PyObject_CheckBuffer(v) != 0 {
        w_buffer_object(v, flag, p);
    } elif is_exact(v, addressof(PySlice_Type)) {
        if p.view(1)[0].version < 5 {
            w_byte(TYPE_UNKNOWN, p);
            p.view(1)[0].error = WFERR_UNMARSHALLABLE;
            return;
        }
        w_byte(TYPE_SLICE | flag, p);
        w_object(ptr[PySliceObject](v).view(1)[0].start, p);
        w_object(ptr[PySliceObject](v).view(1)[0].stop, p);
        w_object(ptr[PySliceObject](v).view(1)[0].step, p);
        w_complete(v, p);
    } else {
        w_byte(TYPE_UNKNOWN | flag, p);
        p.view(1)[0].error = WFERR_UNMARSHALLABLE;
    }
}

impl w_decref_entry(key: ptr) {
    object_xdecref(ptr[PyObject](key));
}

impl w_init_refs(p: ptr[MarshalWriter], version: i32) -> i32 {
    if version >= 3 {
        table = _Py_hashtable_new_full(
            ptr(_Py_hashtable_hash_ptr),
            ptr(_Py_hashtable_compare_direct),
            ptr(w_decref_entry),
            ptr(),
            ptr()
        );
        if not table {
            PyErr_NoMemory();
            return i32(-1);
        }
        p.view(1)[0].hashtable = table;
    }
    return i32(0);
}

impl w_clear_refs(p: ptr[MarshalWriter]) {
    if p.view(1)[0].hashtable {
        _Py_hashtable_destroy(p.view(1)[0].hashtable);
    }
}

impl write_object_to_string(
    x: ptr[PyObject], version: i32, allow_code: i32
) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("marshal.dumps"), ptr[u8]("Oi"), x, version) < 0 {
        return NULL;
    }
    slots: own MarshalStack = MarshalStack();
    p = ptr[MarshalWriter](jacpy_stack_address(&mut slots));
    out = PyBytes_FromStringAndSize(ptr[u8](), 50);
    if not out {
        return NULL;
    }
    buf = bytes_data(out);
    p.view(1)[0].out = out;
    p.view(1)[0].buf = buf;
    p.view(1)[0].cur = buf;
    p.view(1)[0].end = buf + object_size(out);
    p.view(1)[0].error = WFERR_OK;
    p.view(1)[0].version = version;
    p.view(1)[0].allow_code = allow_code;
    if w_init_refs(p, version) != 0 {
        object_decref(out);
        return NULL;
    }
    w_object(x, p);
    w_clear_refs(p);
    if p.view(1)[0].out {
        result = p.view(1)[0].out;
        base = bytes_data(result);
        status = _PyBytes_Resize(&mut result, i64(int(p.view(1)[0].cur) - int(base)));
        p.view(1)[0].out = result;
        if status < 0 {
            return NULL;
        }
    }
    error = p.view(1)[0].error;
    if error != WFERR_OK {
        object_xdecref(p.view(1)[0].out);
        if error == WFERR_NOMEMORY {
            PyErr_NoMemory();
        } elif error == WFERR_NESTEDTOODEEP {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("object too deeply nested to marshal")
            );
        } elif error == WFERR_CODE_NOT_ALLOWED {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("marshalling code objects is disallowed")
            );
        } else {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("unmarshallable object"));
        }
        return NULL;
    }
    return p.view(1)[0].out;
}

impl r_readinto(p: ptr[MarshalReader], n: i64) -> i64 {
    slots: own MarshalStack = MarshalStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyBuffer_FillInfo(
        view, NULL, ptr(p.view(1)[0].buf), n, i32(0), PyBUF_ND | PyBUF_WRITABLE
    )
        == -1 {
        return -1;
    }
    mview = PyMemoryView_FromBuffer(view);
    if not mview {
        return -1;
    }
    read: i64 = -1;
    res = _PyObject_CallMethod(
        p.view(1)[0].readable, py_id(_Py_ID_readinto), ptr[u8]("N"), mview
    );
    if res {
        read = PyNumber_AsSsize_t(res, PyExc_ValueError);
        object_decref(res);
    }
    return read;
}

impl r_string_slow(n: i64, p: ptr[MarshalReader]) -> ptr[u8] {
    if not p.view(1)[0].buf {
        fresh = ptr[u8](PyMem_Malloc(u64(n)));
        if not fresh {
            PyErr_NoMemory();
            return ptr[u8]();
        }
        p.view(1)[0].buf = fresh;
        p.view(1)[0].buf_size = n;
    } elif p.view(1)[0].buf_size < n {
        tmp = ptr[u8](PyMem_Realloc(ptr(p.view(1)[0].buf), u64(n)));
        if not tmp {
            PyErr_NoMemory();
            return ptr[u8]();
        }
        p.view(1)[0].buf = tmp;
        p.view(1)[0].buf_size = n;
    }
    read: i64 = -1;
    if not p.view(1)[0].readable {
        read = i64(fread(ptr(p.view(1)[0].buf), u64(1), u64(n), p.view(1)[0].fp));
    } else {
        read = r_readinto(p, n);
    }
    if read != n {
        if not PyErr_Occurred() {
            if read > n {
                PyErr_Format(
                    PyExc_ValueError,
                    ptr[u8](
                        "read() returned too much data: %zd bytes requested, %zd returned"
                    ),
                    n,
                    read
                );
            } else {
                PyErr_SetString(PyExc_EOFError, ptr[u8]("EOF read where not expected"));
            }
        }
        return ptr[u8]();
    }
    return p.view(1)[0].buf;
}

impl r_string(n: i64, p: ptr[MarshalReader]) -> ptr[u8] {
    res = p.view(1)[0].cur;
    if res {
        if i64(int(p.view(1)[0].end) - int(res)) < n {
            PyErr_SetString(PyExc_EOFError, ptr[u8]("marshal data too short"));
            return ptr[u8]();
        }
        p.view(1)[0].cur = res + n;
        return res;
    }
    return r_string_slow(n, p);
}

impl r_byte(p: ptr[MarshalReader]) -> i32 {
    cur = p.view(1)[0].cur;
    if cur {
        if int(cur) < int(p.view(1)[0].end) {
            p.view(1)[0].cur = cur + 1;
            return i32(cur.view(1)[0]);
        }
    } elif not p.view(1)[0].readable {
        c = getc(p.view(1)[0].fp);
        if c != EOF {
            return c;
        }
    } else {
        s = r_string(1, p);
        if s {
            return i32(s.view(1)[0]);
        }
        return EOF;
    }
    PyErr_SetString(PyExc_EOFError, ptr[u8]("EOF read where not expected"));
    return EOF;
}

impl r_short(p: ptr[MarshalReader]) -> i32 {
    x: i32 = -1;
    buffer = r_string(2, p);
    if buffer {
        b = buffer.view(2);
        x = i32(b[0]) | (i32(b[1]) << i32(8));
        x = x | -(x & i32(0x8000));
    }
    return x;
}

impl r_long(p: ptr[MarshalReader]) -> i64 {
    x: i64 = -1;
    buffer = r_string(4, p);
    if buffer {
        b = buffer.view(4);
        x = i64(b[0]) | (i64(b[1]) << 8) | (i64(b[2]) << 16) | (i64(b[3]) << 24);
        x = x | -(x & 0x80000000);
    }
    return x;
}

impl r_long64(p: ptr[MarshalReader]) -> ptr[PyObject] {
    buffer = r_string(8, p);
    if not buffer {
        return NULL;
    }
    return _PyLong_FromByteArray(buffer, u64(8), i32(1), i32(1));
}

impl bad_digit -> i32 {
    if not PyErr_Occurred() {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("bad marshal data (digit out of range in long)")
        );
    }
    return i32(-1);
}

impl _w_digits32(
    digits: ptr[u32],
    size: i64,
    marshal_ratio: i64,
    shorts_in_top_digit: i32,
    p: ptr[MarshalReader]
) -> i32 {
    i: i64 = 0;
    while i < size - 1 {
        d: u32 = 0;
        j: i64 = 0;
        while j < marshal_ratio {
            md = r_short(p);
            if md < 0 or md > PyLong_MARSHAL_BASE {
                return bad_digit();
            }
            d = wrapping_add(d, u32(md) << u32(j * PyLong_MARSHAL_SHIFT));
            j += 1;
        }
        (digits + i).view(1)[0] = d;
        i += 1;
    }
    d: u32 = 0;
    t: i32 = 0;
    while t < shorts_in_top_digit {
        md = r_short(p);
        if md < 0 or md > PyLong_MARSHAL_BASE {
            return bad_digit();
        }
        if md == 0 and t == shorts_in_top_digit - 1 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (unnormalized long data)")
            );
            return i32(-1);
        }
        d = wrapping_add(d, u32(md) << u32(i64(t) * PyLong_MARSHAL_SHIFT));
        t += 1;
    }
    (digits + (size - 1)).view(1)[0] = d;
    return i32(0);
}

impl _w_digits16(
    digits: ptr[u16],
    size: i64,
    marshal_ratio: i64,
    shorts_in_top_digit: i32,
    p: ptr[MarshalReader]
) -> i32 {
    i: i64 = 0;
    while i < size - 1 {
        d: u16 = 0;
        j: i64 = 0;
        while j < marshal_ratio {
            md = r_short(p);
            if md < 0 or md > PyLong_MARSHAL_BASE {
                return bad_digit();
            }
            d = u16.wrap(i64(d) + (i64(md) << (j * PyLong_MARSHAL_SHIFT)));
            j += 1;
        }
        (digits + i).view(1)[0] = d;
        i += 1;
    }
    d: u16 = 0;
    t: i32 = 0;
    while t < shorts_in_top_digit {
        md = r_short(p);
        if md < 0 or md > PyLong_MARSHAL_BASE {
            return bad_digit();
        }
        if md == 0 and t == shorts_in_top_digit - 1 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (unnormalized long data)")
            );
            return i32(-1);
        }
        d = u16.wrap(i64(d) + (i64(md) << (i64(t) * PyLong_MARSHAL_SHIFT)));
        t += 1;
    }
    (digits + (size - 1)).view(1)[0] = d;
    return i32(0);
}

impl r_PyLong(p: ptr[MarshalReader]) -> ptr[PyObject] {
    n = r_long(p);
    if n == -1 and PyErr_Occurred() {
        return NULL;
    }
    if n < -SIZE32_MAX or n > SIZE32_MAX {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("bad marshal data (long size out of range)")
        );
        return NULL;
    }
    layout = PyLong_GetNativeLayout();
    marshal_ratio = i64(layout.view(1)[0].bits_per_digit) // PyLong_MARSHAL_SHIFT;
    abs_n = n;
    negative: i32 = 0;
    if n < 0 {
        abs_n = -n;
        negative = 1;
    }
    size: i64 = 1;
    shorts_in_top_digit: i32 = 0;
    if abs_n > 0 {
        size = 1 + (abs_n - 1) // marshal_ratio;
        shorts_in_top_digit = i32(1 + (abs_n - 1) % marshal_ratio);
    }
    digits = ptr();
    writer = PyLongWriter_Create(negative, size, &mut digits);
    if not writer {
        return NULL;
    }
    ret: i32 = 0;
    if layout.view(1)[0].digit_size == u8(4) {
        ret = _w_digits32(
            ptr[u32](digits), size, marshal_ratio, shorts_in_top_digit, p
        );
    } else {
        ret = _w_digits16(
            ptr[u16](digits), size, marshal_ratio, shorts_in_top_digit, p
        );
    }
    if ret < 0 {
        PyLongWriter_Discard(writer);
        return NULL;
    }
    return PyLongWriter_Finish(writer);
}

impl r_float_bin(p: ptr[MarshalReader]) -> f64 {
    buf = r_string(8, p);
    if not buf {
        return -1.0;
    }
    return PyFloat_Unpack8(buf, i32(1));
}

impl r_float_str(p: ptr[MarshalReader]) -> f64 {
    n = r_byte(p);
    if n == EOF {
        return -1.0;
    }
    s = r_string(i64(n), p);
    if not s {
        return -1.0;
    }
    slots: own MarshalStack = MarshalStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    memcpy(ptr(buf), ptr(s), u64(n));
    (buf + i64(n)).view(1)[0] = u8(0);
    return PyOS_string_to_double(ptr(buf), ptr(), NULL);
}

impl r_ref_reserve(flag: i32, p: ptr[MarshalReader]) -> i64 {
    if flag != 0 {
        refs = p.view(1)[0].refs;
        idx = object_size(refs);
        if idx >= 0x7ffffffe {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (index list too large)")
            );
            return -1;
        }
        if PyList_Append(refs, Py_None) < 0 {
            return -1;
        }
        return idx;
    }
    return 0;
}

impl r_ref_insert(
    o: ptr[PyObject], idx: i64, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject] {
    if o and flag != 0 {
        slot = list_slot(p.view(1)[0].refs, idx);
        tmp = slot.view(1)[0];
        slot.view(1)[0] = object_new_ref(o);
        object_decref(tmp);
    }
    return o;
}

impl r_ref(o: ptr[PyObject], flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    if not o {
        return NULL;
    }
    if PyList_Append(p.view(1)[0].refs, o) < 0 {
        object_decref(o);
        return NULL;
    }
    return o;
}

impl r_float_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    x: f64 = 0.0;
    if type == TYPE_BINARY_FLOAT {
        x = r_float_bin(p);
    } else {
        x = r_float_str(p);
    }
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    retval = PyFloat_FromDouble(x);
    if flag != 0 {
        retval = r_ref(retval, flag, p);
    }
    return retval;
}

impl r_complex_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    real: f64 = 0.0;
    imag: f64 = 0.0;
    if type == TYPE_BINARY_COMPLEX {
        real = r_float_bin(p);
        if real == -1.0 and PyErr_Occurred() {
            return NULL;
        }
        imag = r_float_bin(p);
        if imag == -1.0 and PyErr_Occurred() {
            return NULL;
        }
    } else {
        real = r_float_str(p);
        if real == -1.0 and PyErr_Occurred() {
            return NULL;
        }
        imag = r_float_str(p);
        if imag == -1.0 and PyErr_Occurred() {
            return NULL;
        }
    }
    retval = PyComplex_FromCComplex(Py_complex(real=real, imag=imag));
    if flag != 0 {
        retval = r_ref(retval, flag, p);
    }
    return retval;
}

impl r_bytes_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    n = r_long(p);
    if n < 0 or n > SIZE32_MAX {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("bad marshal data (bytes object size out of range)")
            );
        }
        return NULL;
    }
    v = PyBytes_FromStringAndSize(ptr[u8](), n);
    if not v {
        return NULL;
    }
    s = r_string(n, p);
    if not s {
        object_decref(v);
        return NULL;
    }
    memcpy(ptr(bytes_data(v)), ptr(s), u64(n));
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    return v;
}

impl r_ascii_object(
    n: i64, is_interned: bool, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject] {
    s = r_string(n, p);
    if not s {
        return NULL;
    }
    v = PyUnicode_FromKindAndData(PyUnicode_1BYTE_KIND, ptr(s), n);
    if not v {
        return NULL;
    }
    if is_interned {
        _PyUnicode_InternImmortal(current_interp(), &mut v);
    }
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    return v;
}

impl r_unicode_object(
    is_interned: bool, flag: i32, p: ptr[MarshalReader]
) -> ptr[PyObject] {
    n = r_long(p);
    if n < 0 or n > SIZE32_MAX {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (string size out of range)")
            );
        }
        return NULL;
    }
    v = NULL;
    if n != 0 {
        buffer = r_string(n, p);
        if not buffer {
            return NULL;
        }
        v = PyUnicode_DecodeUTF8(buffer, n, ptr[u8]("surrogatepass"));
    } else {
        v = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    if not v {
        return NULL;
    }
    if is_interned {
        _PyUnicode_InternImmortal(current_interp(), &mut v);
    }
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    return v;
}

impl r_tuple_object(n: i64, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    v = PyTuple_New(n);
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    if not v {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        v2 = r_object(p);
        if not v2 {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("NULL object in marshal data for tuple")
                );
            }
            object_decref(v);
            return NULL;
        }
        tuple_set_item(v, i, v2);
        i += 1;
    }
    return v;
}

impl r_list_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    n = r_long(p);
    if n < 0 or n > SIZE32_MAX {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (list size out of range)")
            );
        }
        return NULL;
    }
    v = PyList_New(n);
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    if not v {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        v2 = r_object(p);
        if not v2 {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("NULL object in marshal data for list")
                );
            }
            object_decref(v);
            return NULL;
        }
        list_slot(v, i).view(1)[0] = v2;
        i += 1;
    }
    return v;
}

impl r_dict_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    v = PyDict_New();
    if flag != 0 {
        v = r_ref(v, flag, p);
    }
    if not v {
        return NULL;
    }
    while True {
        key = r_object(p);
        if not key {
            break;
        }
        val = r_object(p);
        if not val {
            object_decref(key);
            break;
        }
        if PyDict_SetItem(v, key, val) < 0 {
            object_decref(key);
            object_decref(val);
            break;
        }
        object_decref(key);
        object_decref(val);
    }
    if PyErr_Occurred() {
        object_decref(v);
        return NULL;
    }
    return v;
}

impl r_set_object(type: i32, flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    n = r_long(p);
    if n < 0 or n > SIZE32_MAX {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (set size out of range)")
            );
        }
        return NULL;
    }
    if n == 0 and type == TYPE_FROZENSET {
        empty = PyObject_CallNoArgs(ptr[PyObject](addressof(PyFrozenSet_Type)));
        if not empty {
            return NULL;
        }
        if flag != 0 {
            empty = r_ref(empty, flag, p);
        }
        return empty;
    }
    v = NULL;
    idx: i64 = 0;
    if type == TYPE_SET {
        v = PySet_New(NULL);
        if flag != 0 {
            v = r_ref(v, flag, p);
        }
    } else {
        v = PyFrozenSet_New(NULL);
        idx = r_ref_reserve(flag, p);
        if idx < 0 {
            object_xdecref(v);
            v = NULL;
        }
    }
    if not v {
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        v2 = r_object(p);
        if not v2 {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("NULL object in marshal data for set")
                );
            }
            object_decref(v);
            v = NULL;
            break;
        }
        if PySet_Add(v, v2) == -1 {
            object_decref(v);
            object_decref(v2);
            v = NULL;
            break;
        }
        object_decref(v2);
        i += 1;
    }
    if type != TYPE_SET {
        v = r_ref_insert(v, idx, flag, p);
    }
    return v;
}

impl con_set_int(con: ptr[u8], offset: i64, value: i32) {
    ptr[i32](con + offset).view(1)[0] = value;
}

impl con_set_obj(con: ptr[u8], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](con + offset).view(1)[0] = value;
}

impl con_obj(con: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](con + offset).view(1)[0];
}

impl r_code_int(con: ptr[u8], offset: i64, p: ptr[MarshalReader]) -> bool {
    value = i32.wrap(r_long(p));
    if value == -1 and PyErr_Occurred() {
        return False;
    }
    con_set_int(con, offset, value);
    return True;
}

impl r_code_obj(con: ptr[u8], offset: i64, p: ptr[MarshalReader]) -> bool {
    value = r_object(p);
    if not value {
        return False;
    }
    con_set_obj(con, offset, value);
    return True;
}

impl r_code_fields(con: ptr[u8], p: ptr[MarshalReader]) -> bool {
    return r_code_int(con, _PyCodeConstructor_ARGCOUNT, p)
        and r_code_int(con, _PyCodeConstructor_POSONLYARGCOUNT, p)
        and r_code_int(con, _PyCodeConstructor_KWONLYARGCOUNT, p)
        and r_code_int(con, _PyCodeConstructor_STACKSIZE, p)
        and r_code_int(con, _PyCodeConstructor_FLAGS, p)
        and r_code_obj(con, _PyCodeConstructor_CODE, p)
        and r_code_obj(con, _PyCodeConstructor_CONSTS, p)
        and r_code_obj(con, _PyCodeConstructor_NAMES, p)
        and r_code_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES, p)
        and r_code_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS, p)
        and r_code_obj(con, _PyCodeConstructor_FILENAME, p)
        and r_code_obj(con, _PyCodeConstructor_NAME, p)
        and r_code_obj(con, _PyCodeConstructor_QUALNAME, p)
        and r_code_int(con, _PyCodeConstructor_FIRSTLINENO, p)
        and r_code_obj(con, _PyCodeConstructor_LINETABLE, p)
        and r_code_obj(con, _PyCodeConstructor_EXCEPTIONTABLE, p);
}

impl r_code_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    if p.view(1)[0].allow_code == 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("unmarshalling code objects is disallowed")
        );
        return NULL;
    }
    idx = r_ref_reserve(flag, p);
    if idx < 0 {
        return NULL;
    }
    slots: own MarshalStack = MarshalStack();
    con = ptr[u8](jacpy_stack_address(&mut slots));
    v = NULL;
    if r_code_fields(con, p) and _PyCode_Validate(con) >= 0 {
        v = _PyCode_New(con);
        if v {
            v = r_ref_insert(v, idx, flag, p);
        }
    }
    if not v and not PyErr_Occurred() {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("NULL object in marshal data for code object")
        );
    }
    object_xdecref(con_obj(con, _PyCodeConstructor_CODE));
    object_xdecref(con_obj(con, _PyCodeConstructor_CONSTS));
    object_xdecref(con_obj(con, _PyCodeConstructor_NAMES));
    object_xdecref(con_obj(con, _PyCodeConstructor_LOCALSPLUSNAMES));
    object_xdecref(con_obj(con, _PyCodeConstructor_LOCALSPLUSKINDS));
    object_xdecref(con_obj(con, _PyCodeConstructor_FILENAME));
    object_xdecref(con_obj(con, _PyCodeConstructor_NAME));
    object_xdecref(con_obj(con, _PyCodeConstructor_QUALNAME));
    object_xdecref(con_obj(con, _PyCodeConstructor_LINETABLE));
    object_xdecref(con_obj(con, _PyCodeConstructor_EXCEPTIONTABLE));
    return v;
}

impl r_ref_object(p: ptr[MarshalReader]) -> ptr[PyObject] {
    n = r_long(p);
    refs = p.view(1)[0].refs;
    if n < 0 or n >= object_size(refs) {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("bad marshal data (invalid reference)")
            );
        }
        return NULL;
    }
    v = list_slot(refs, n).view(1)[0];
    if v == Py_None {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("bad marshal data (invalid reference)")
        );
        return NULL;
    }
    return object_new_ref(v);
}

impl r_slice_object(flag: i32, p: ptr[MarshalReader]) -> ptr[PyObject] {
    idx = r_ref_reserve(flag, p);
    if idx < 0 {
        return NULL;
    }
    retval = NULL;
    stop = NULL;
    step = NULL;
    start = r_object(p);
    if start {
        stop = r_object(p);
        if stop {
            step = r_object(p);
            if step {
                retval = PySlice_New(start, stop, step);
                r_ref_insert(retval, idx, flag, p);
            }
        }
    }
    object_xdecref(start);
    object_xdecref(stop);
    object_xdecref(step);
    return retval;
}

impl r_object(p: ptr[MarshalReader]) -> ptr[PyObject] {
    code = r_byte(p);
    if code == EOF {
        if PyErr_ExceptionMatches(PyExc_EOFError) != 0 {
            PyErr_SetString(PyExc_EOFError, ptr[u8]("EOF read where object expected"));
        }
        return NULL;
    }
    depth = p.view(1)[0].depth + 1;
    p.view(1)[0].depth = depth;
    if depth > MAX_MARSHAL_STACK_DEPTH {
        p.view(1)[0].depth = depth - 1;
        PyErr_SetString(PyExc_ValueError, ptr[u8]("recursion limit exceeded"));
        return NULL;
    }
    flag = code & FLAG_REF;
    type = code & i32(0x7F);
    retval = NULL;
    if type == TYPE_REF {
        retval = r_ref_object(p);
    } elif type == TYPE_SHORT_ASCII_INTERNED or type == TYPE_SHORT_ASCII {
        short_n = r_byte(p);
        if short_n != EOF {
            retval = r_ascii_object(
                i64(short_n), type == TYPE_SHORT_ASCII_INTERNED, flag, p
            );
        }
    } elif type == TYPE_SMALL_TUPLE {
        small_n = r_byte(p);
        if small_n != EOF {
            retval = r_tuple_object(i64(small_n), flag, p);
        }
    } elif type == TYPE_NONE {
        retval = Py_None;
    } elif type == TYPE_CODE {
        retval = r_code_object(flag, p);
    } elif type == TYPE_INT {
        n = r_long(p);
        if not (n == -1 and PyErr_Occurred()) {
            retval = PyLong_FromLong(n);
            if flag != 0 {
                retval = r_ref(retval, flag, p);
            }
        }
    } elif type == TYPE_STRING {
        retval = r_bytes_object(flag, p);
    } elif type == TYPE_ASCII_INTERNED or type == TYPE_ASCII {
        ascii_n = r_long(p);
        if ascii_n < 0 or ascii_n > SIZE32_MAX {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_ValueError,
                    ptr[u8]("bad marshal data (string size out of range)")
                );
            }
        } else {
            retval = r_ascii_object(ascii_n, type == TYPE_ASCII_INTERNED, flag, p);
        }
    } elif type == TYPE_INTERNED or type == TYPE_UNICODE {
        retval = r_unicode_object(type == TYPE_INTERNED, flag, p);
    } elif type == TYPE_TUPLE {
        tuple_n = r_long(p);
        if tuple_n < 0 or tuple_n > SIZE32_MAX {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_ValueError,
                    ptr[u8]("bad marshal data (tuple size out of range)")
                );
            }
        } else {
            retval = r_tuple_object(tuple_n, flag, p);
        }
    } elif type == TYPE_FALSE {
        retval = ptr[PyObject](addressof(_Py_FalseStruct));
    } elif type == TYPE_TRUE {
        retval = ptr[PyObject](addressof(_Py_TrueStruct));
    } elif type == TYPE_LONG {
        retval = r_PyLong(p);
        if flag != 0 {
            retval = r_ref(retval, flag, p);
        }
    } elif type == TYPE_BINARY_FLOAT or type == TYPE_FLOAT {
        retval = r_float_object(type, flag, p);
    } elif type == TYPE_BINARY_COMPLEX or type == TYPE_COMPLEX {
        retval = r_complex_object(type, flag, p);
    } elif type == TYPE_NULL {
        retval = NULL;
    } elif type == TYPE_STOPITER {
        retval = object_new_ref(PyExc_StopIteration);
    } elif type == TYPE_ELLIPSIS {
        retval = Py_Ellipsis;
    } elif type == TYPE_INT64 {
        retval = r_long64(p);
        if flag != 0 {
            retval = r_ref(retval, flag, p);
        }
    } elif type == TYPE_LIST {
        retval = r_list_object(flag, p);
    } elif type == TYPE_DICT {
        retval = r_dict_object(flag, p);
    } elif type == TYPE_SET or type == TYPE_FROZENSET {
        retval = r_set_object(type, flag, p);
    } elif type == TYPE_SLICE {
        retval = r_slice_object(flag, p);
    } else {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("bad marshal data (unknown type code)")
        );
    }
    p.view(1)[0].depth = p.view(1)[0].depth - 1;
    return retval;
}

impl read_object(p: ptr[MarshalReader]) -> ptr[PyObject] {
    if PyErr_Occurred() {
        fputs(
            ptr[u8]("XXX readobject called with exception set\n"),
            jacpy_stdio_stream(i32(2))
        );
        return NULL;
    }
    cur = p.view(1)[0].cur;
    if cur and p.view(1)[0].end {
        length = i64(int(p.view(1)[0].end) - int(cur));
        if PySys_Audit(ptr[u8]("marshal.loads"), ptr[u8]("y#"), cur, length) < 0 {
            return NULL;
        }
    } elif p.view(1)[0].fp or p.view(1)[0].readable {
        if PySys_AuditTuple(ptr[u8]("marshal.load"), NULL) < 0 {
            return NULL;
        }
    }
    v = r_object(p);
    if not v and not PyErr_Occurred() {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("NULL object in marshal data for object")
        );
    }
    return v;
}

impl read_object_from(
    fp: ptr, readable: ptr[PyObject], data: ptr[u8], length: i64, allow_code: i32
) -> ptr[PyObject] {
    slots: own MarshalStack = MarshalStack();
    p = ptr[MarshalReader](jacpy_stack_address(&mut slots));
    p.view(1)[0].allow_code = allow_code;
    p.view(1)[0].fp = fp;
    p.view(1)[0].readable = readable;
    p.view(1)[0].depth = 0;
    if data {
        p.view(1)[0].cur = data;
        p.view(1)[0].end = data + length;
    }
    refs = PyList_New(0);
    if not refs {
        return NULL;
    }
    p.view(1)[0].refs = refs;
    result = read_object(p);
    object_decref(refs);
    if p.view(1)[0].buf {
        PyMem_Free(ptr(p.view(1)[0].buf));
    }
    return result;
}

impl read_from_file(fp: ptr) -> ptr[PyObject] {
    return read_object_from(fp, NULL, ptr[u8](), 0, i32(1));
}

impl read_from_string(data: ptr[u8], length: i64) -> ptr[PyObject] {
    return read_object_from(ptr(), NULL, data, length, i32(1));
}

impl getfilesize(fp: ptr) -> i64 {
    st = _Py_stat_struct();
    if _Py_fstat_noraise(fileno(fp), &mut st) != 0 {
        return -1;
    }
    return st.st_size;
}

impl marshal_dump_impl(
    module: ptr[PyObject],
    value: ptr[PyObject],
    file: ptr[PyObject],
    version: i32,
    allow_code: bool
) -> ptr[PyObject] {
    s = write_object_to_string(value, version, flag_of(allow_code));
    if not s {
        return NULL;
    }
    slots: own MarshalStack = MarshalStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = file;
    stack.view(2)[1] = s;
    res = PyObject_VectorcallMethod(
        py_id(_Py_ID_write), stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
    object_decref(s);
    return res;
}

impl marshal_load_impl(
    module: ptr[PyObject], file: ptr[PyObject], allow_code: bool
) -> ptr[PyObject] {
    data = _PyObject_CallMethod(file, py_id(_Py_ID_read), ptr[u8]("i"), i32(0));
    if not data {
        return NULL;
    }
    result = NULL;
    data_type = ptr[_object](data).view(1)[0].ob_type;
    if (data_type.view(1)[0].tp_flags & Py_TPFLAGS_BYTES_SUBCLASS) == u64(0) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("file.read() returned not bytes but %.100s"),
            data_type.view(1)[0].tp_name
        );
    } else {
        result = read_object_from(ptr(), file, ptr[u8](), 0, flag_of(allow_code));
    }
    object_decref(data);
    return result;
}

impl marshal_dumps_impl(
    module: ptr[PyObject], value: ptr[PyObject], version: i32, allow_code: bool
) -> ptr[PyObject] {
    return write_object_to_string(value, version, flag_of(allow_code));
}

impl marshal_loads_impl(
    module: ptr[PyObject], bytes_: BufferArgument, allow_code: bool
) -> ptr[PyObject] {
    view = bytes_.view;
    return read_object_from(
        ptr(),
        NULL,
        ptr[u8](view.view(1)[0].buf),
        view.view(1)[0].length,
        flag_of(allow_code)
    );
}

impl marshal_module_exec(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(module, ptr[u8]("version"), i64(Py_MARSHAL_VERSION))
        < 0 {
        return i32(-1);
    }
    return i32(0);
}
