import from c {
    def strlen(text: ptr[u8]) -> u64;  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def Py_FatalError(message: str);  def PyComplex_AsCComplex(
        op: ptr[PyObject]
    ) -> Py_complex;  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        exporter: ptr[PyObject],
        buf: ptr,
        length: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def _PyUnicode_Equal(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32;  def _PyUnicode_InternImmortal(
        interp: ptr[u8], p: ptr[ptr[PyObject]]
    );  def _PyDict_HasOnlyStringKeys(dct: ptr[PyObject]) -> i32;  def PyThreadState_New(
        interp: ptr[PyInterpreterState]
    ) -> ptr[PyThreadState];  def PyThreadState_Clear(tstate: ptr[PyThreadState]);  def PyThreadState_Delete(
        tstate: ptr[PyThreadState]
    );  def _PyOnceFlag_CallOnceSlow(flag: ptr[u8], once_fn: ptr, arg: ptr) -> i32;  def jacpy_va_list(
        va: ptr
    ) -> VaList;  obj FreelistEntry {
        has item: ptr = ptr(),
            destructor: Callable[[ptr[PyObject], ptr], i32] = 0;
    }  obj Freelist {
        has entries: ptr[FreelistEntry] = ptr[FreelistEntry](),
            first_available: i32 = 0,
            entries_malloced: i32 = 0;
    }  obj GetargsCall {
        has converter: Callable[[ptr[PyObject], ptr], i32] = 0;
    }  obj ParseFrame {
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
            w39: u64 = 0,
            w40: u64 = 0,
            w41: u64 = 0,
            w42: u64 = 0,
            w43: u64 = 0,
            w44: u64 = 0,
            w45: u64 = 0,
            w46: u64 = 0,
            w47: u64 = 0,
            w48: u64 = 0,
            w49: u64 = 0,
            w50: u64 = 0,
            w51: u64 = 0,
            w52: u64 = 0,
            w53: u64 = 0,
            w54: u64 = 0,
            w55: u64 = 0,
            w56: u64 = 0,
            w57: u64 = 0,
            w58: u64 = 0,
            w59: u64 = 0,
            w60: u64 = 0,
            w61: u64 = 0,
            w62: u64 = 0,
            w63: u64 = 0,
            w64: u64 = 0,
            w65: u64 = 0,
            w66: u64 = 0,
            w67: u64 = 0,
            w68: u64 = 0,
            w69: u64 = 0,
            w70: u64 = 0,
            w71: u64 = 0,
            w72: u64 = 0,
            w73: u64 = 0,
            w74: u64 = 0,
            w75: u64 = 0,
            w76: u64 = 0,
            w77: u64 = 0,
            w78: u64 = 0,
            w79: u64 = 0,
            w80: u64 = 0,
            w81: u64 = 0,
            w82: u64 = 0,
            w83: u64 = 0,
            w84: u64 = 0,
            w85: u64 = 0,
            w86: u64 = 0,
            w87: u64 = 0,
            w88: u64 = 0,
            w89: u64 = 0,
            w90: u64 = 0,
            w91: u64 = 0,
            w92: u64 = 0,
            w93: u64 = 0,
            w94: u64 = 0,
            w95: u64 = 0,
            w96: u64 = 0,
            w97: u64 = 0,
            w98: u64 = 0,
            w99: u64 = 0,
            w100: u64 = 0,
            w101: u64 = 0,
            w102: u64 = 0,
            w103: u64 = 0,
            w104: u64 = 0,
            w105: u64 = 0,
            w106: u64 = 0,
            w107: u64 = 0;
    }  def jacpy_stack_address(slots: &mut ParseFrame) -> int;
}

glob:priv FRAME_ENTRIES: i64 = 16,
     FRAME_LEVELS: i64 = 144,
     FRAME_VIEW: i64 = 272,
     FRAME_MSGBUF: i64 = 352,
     FLAG_COMPAT: i32 = 1,
     STATIC_FREELIST_ENTRIES: i32 = 8,
     INT_MAX: i32 = 2147483647,
     INT_MIN: i32 = -2147483648,
     SHRT_MAX: i64 = 32767,
     SHRT_MIN: i64 = -32768,
     UCHAR_MAX: i64 = 255,
     ULONG_ALL: u64 = 0xFFFFFFFFFFFFFFFF,
     CH_NUL: u8 = 0,
     CH_BANG: u8 = 33,
     CH_HASH: u8 = 35,
     CH_DOLLAR: u8 = 36,
     CH_AMP: u8 = 38,
     CH_LPAREN: u8 = 40,
     CH_RPAREN: u8 = 41,
     CH_STAR: u8 = 42,
     CH_COLON: u8 = 58,
     CH_SEMI: u8 = 59,
     CH_BAR: u8 = 124,
     CH_B: u8 = 66,
     CH_C: u8 = 67,
     CH_D: u8 = 68,
     CH_H: u8 = 72,
     CH_I: u8 = 73,
     CH_K: u8 = 75,
     CH_L: u8 = 76,
     CH_O: u8 = 79,
     CH_S: u8 = 83,
     CH_U: u8 = 85,
     CH_Y: u8 = 89,
     CH_b: u8 = 98,
     CH_c: u8 = 99,
     CH_d: u8 = 100,
     CH_e: u8 = 101,
     CH_f: u8 = 102,
     CH_h: u8 = 104,
     CH_i: u8 = 105,
     CH_k: u8 = 107,
     CH_l: u8 = 108,
     CH_n: u8 = 110,
     CH_p: u8 = 112,
     CH_s: u8 = 115,
     CH_t: u8 = 116,
     CH_w: u8 = 119,
     CH_y: u8 = 121,
     CH_z: u8 = 122;

def frame_freelist(address: int) -> ptr[Freelist];

def frame_levels(freelist: ptr[Freelist]) -> ptr[i32];

def frame_view(freelist: ptr[Freelist]) -> ptr[Py_buffer];

def frame_msgbuf(freelist: ptr[Freelist]) -> ptr[u8];

def freelist_init(freelist: ptr[Freelist]);

def freelist_reserve(freelist: ptr[Freelist], count: i32) -> bool;

def char_at(p: ptr[u8]) -> u8;

def is_alpha(c: u8) -> bool;

def is_end_of_format(c: u8) -> bool;

def fname_or_function(fname: ptr[u8]) -> ptr[u8];

def fname_or_this(fname: ptr[u8]) -> ptr[u8];

def fname_parens(fname: ptr[u8]) -> ptr[u8];

def plural(n: i64) -> ptr[u8];

def type_name_or_none(arg: ptr[PyObject]) -> ptr[u8];

def dict_size(op: ptr[PyObject]) -> i64;

def min_i32(a: i32, b: i32) -> i32;

def max_i32(a: i32, b: i32) -> i32;

def set_error_text(exception: ptr[PyObject], text: ptr[u8]);

def cleanup_ptr(self_: ptr[PyObject], p: ptr) -> i32;

def cleanup_buffer(self_: ptr[PyObject], p: ptr) -> i32;

def addcleanup(p: ptr, freelist: ptr[Freelist], destructor: int) -> i32;

def cleanreturn(retval: i32, freelist: ptr[Freelist]) -> i32;

def convertitem(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    levels: ptr[i32],
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList);

def converttuple(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    levels: ptr[i32],
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList);

def convertsimple(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList);

def skip_format_item(format: ptr[u8]) -> (ptr[u8], ptr[u8], i64);

def vgetargs1_impl(
    compat_args: ptr[PyObject],
    stack: ptr[ptr[PyObject]],
    nargs: i64,
    format: ptr[u8],
    va: VaList,
    flags: i32
) -> i32;

def vgetargs1(args: ptr[PyObject], format: ptr[u8], va: VaList, flags: i32) -> i32;

def used(p: ptr[u8], buf: ptr[u8]) -> i64;

def seterror(
    iarg: i64, msg: ptr[u8], levels: ptr[i32], fname: ptr[u8], message: ptr[u8]
);

impl converttuple(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    levels: ptr[i32],
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList) {
    level: i32 = 0;
    n: i32 = 0;
    f = format;
    istuple = tuple_check(arg);
    mustbetuple = istuple;
    while True {
        c = char_at(f);
        f = f + 1;
        if c == CH_LPAREN {
            if level == 0 {
                n += 1;
            }
            level += 1;
        } elif c == CH_RPAREN {
            if level == 0 {
                break;
            }
            level -= 1;
        } elif c == CH_COLON or c == CH_SEMI or c == CH_NUL {
            break;
        } else {
            if level == 0 and is_alpha(c) {
                n += 1;
            }
            if c == CH_e and (char_at(f) == CH_s or char_at(f) == CH_t) {
                f = f + 1;
                continue;
            }
            if not mustbetuple {
                if c == CH_y or c == CH_s or c == CH_z {
                    if char_at(f) != CH_STAR {
                        mustbetuple = True;
                    }
                } elif c == CH_S or c == CH_Y or c == CH_U {
                    mustbetuple = True;
                } elif c == CH_O {
                    if char_at(f) != CH_AMP {
                        mustbetuple = True;
                    }
                }
            }
        }
    }
    seq = arg;
    if not istuple {
        if PySequence_Check(arg) == 0
            or unicode_check(arg)
            or bytes_check(arg)
            or bytearray_check(arg) {
            levels.view(1)[0] = 0;
            PyOS_snprintf(
                msgbuf,
                u64(bufsize),
                ptr[u8]("must be %d-item tuple, not %.50s"),
                n,
                type_name_or_none(arg)
            );
            return (msgbuf, format, va);
        }
        if mustbetuple {
            if PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                0,
                "argument must be %d-item tuple, not %T",
                n,
                arg
            )
                != 0 {
                return (msgbuf, format, va);
            }
        }
        size = PySequence_Size(arg);
        if size != i64(n) {
            levels.view(1)[0] = 0;
            PyOS_snprintf(
                msgbuf,
                u64(bufsize),
                ptr[u8]("must be %s of length %d, not %zd"),
                ptr[u8]("tuple") if mustbetuple else ptr[u8]("sequence"),
                n,
                size
            );
            return (msgbuf, format, va);
        }
        seq = PySequence_Tuple(arg);
        if not seq {
            return (msgbuf, format, va);
        }
    }
    count = object_size(seq);
    if count != i64(n) {
        levels.view(1)[0] = 0;
        PyOS_snprintf(
            msgbuf,
            u64(bufsize),
            ptr[u8]("must be tuple of length %d, not %zd"),
            n,
            count
        );
        if not istuple {
            object_decref(seq);
        }
        return (msgbuf, format, va);
    }
    f = format;
    i: i32 = 0;
    while i < n {
        item = tuple_get_item(seq, i64(i));
        (msg, f, va) = convertitem(
            item, f, va, flags, levels + 1, msgbuf, bufsize, freelist
        );
        if msg {
            levels.view(1)[0] = i + 1;
            if not istuple {
                object_decref(seq);
            }
            return (msg, format, va);
        }
        i += 1;
    }
    if not istuple {
        object_decref(seq);
    }
    return (ptr[u8](), f, va);
}

impl convertitem(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    levels: ptr[i32],
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList) {
    if char_at(format) == CH_LPAREN {
        (msg, f, va) = converttuple(
            arg, format + 1, va, flags, levels, msgbuf, bufsize, freelist
        );
        if not msg {
            return (msg, f + 1, va);
        }
        return (msg, format, va);
    }
    (msg, f, va) = convertsimple(arg, format, va, flags, msgbuf, bufsize, freelist);
    if msg {
        levels.view(1)[0] = 0;
        return (msg, format, va);
    }
    return (msg, f, va);
}

def converterr(
    expected: ptr[u8], arg: ptr[PyObject], msgbuf: ptr[u8], bufsize: i64
) -> ptr[u8];

def convertcharerr(
    expected: ptr[u8], what: ptr[u8], size: i64, msgbuf: ptr[u8], bufsize: i64
) -> ptr[u8];

def getbuffer(arg: ptr[PyObject], view: ptr[Py_buffer]) -> (i32, ptr[u8]);

def convertbuffer(arg: ptr[PyObject], freelist: ptr[Freelist]) -> (i64, ptr, ptr[u8]);

impl convertsimple(
    arg: ptr[PyObject],
    format: ptr[u8],
    va: VaList,
    flags: i32,
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList) {
    f = format;
    c = char_at(f);
    f = f + 1;
    ok = ptr[u8]();
    if c == CH_b {
        pu8 = va.arg(ptr[u8]);
        ival = PyLong_AsLong(arg);
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        } elif ival < 0 {
            PyErr_SetString(
                PyExc_OverflowError, "unsigned byte integer is less than minimum"
            );
            return (msgbuf, format, va);
        } elif ival > UCHAR_MAX {
            PyErr_SetString(
                PyExc_OverflowError, "unsigned byte integer is greater than maximum"
            );
            return (msgbuf, format, va);
        }
        pu8.view(1)[0] = u8.wrap(ival);
    } elif c == CH_B {
        pu8 = va.arg(ptr[u8]);
        uval = PyLong_AsUnsignedLongMask(arg);
        if uval == ULONG_ALL and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pu8.view(1)[0] = u8.wrap(uval);
    } elif c == CH_h {
        pi16 = va.arg(ptr[i16]);
        ival = PyLong_AsLong(arg);
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        } elif ival < SHRT_MIN {
            PyErr_SetString(
                PyExc_OverflowError, "signed short integer is less than minimum"
            );
            return (msgbuf, format, va);
        } elif ival > SHRT_MAX {
            PyErr_SetString(
                PyExc_OverflowError, "signed short integer is greater than maximum"
            );
            return (msgbuf, format, va);
        }
        pi16.view(1)[0] = i16(ival);
    } elif c == CH_H {
        pu16 = va.arg(ptr[u16]);
        uval = PyLong_AsUnsignedLongMask(arg);
        if uval == ULONG_ALL and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pu16.view(1)[0] = u16.wrap(uval);
    } elif c == CH_i {
        pi32 = va.arg(ptr[i32]);
        ival = PyLong_AsLong(arg);
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        } elif ival > i64(INT_MAX) {
            PyErr_SetString(
                PyExc_OverflowError, "signed integer is greater than maximum"
            );
            return (msgbuf, format, va);
        } elif ival < i64(INT_MIN) {
            PyErr_SetString(PyExc_OverflowError, "signed integer is less than minimum");
            return (msgbuf, format, va);
        }
        pi32.view(1)[0] = i32(ival);
    } elif c == CH_I {
        pu32 = va.arg(ptr[u32]);
        uval = PyLong_AsUnsignedLongMask(arg);
        if uval == ULONG_ALL and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pu32.view(1)[0] = u32.wrap(uval);
    } elif c == CH_n {
        pi64 = va.arg(ptr[i64]);
        ival: i64 = -1;
        iobj = _PyNumber_Index(arg);
        if iobj {
            ival = PyLong_AsSsize_t(iobj);
            object_decref(iobj);
        }
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pi64.view(1)[0] = ival;
    } elif c == CH_l {
        pi64 = va.arg(ptr[i64]);
        ival = PyLong_AsLong(arg);
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pi64.view(1)[0] = ival;
    } elif c == CH_k {
        pu64 = va.arg(ptr[u64]);
        if not index_check(arg) {
            return (converterr(ptr[u8]("int"), arg, msgbuf, bufsize), format, va);
        }
        uval = PyLong_AsUnsignedLongMask(arg);
        if uval == ULONG_ALL and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pu64.view(1)[0] = uval;
    } elif c == CH_L {
        pi64 = va.arg(ptr[i64]);
        ival = PyLong_AsLongLong(arg);
        if ival == -1 and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pi64.view(1)[0] = ival;
    } elif c == CH_K {
        pu64 = va.arg(ptr[u64]);
        if not index_check(arg) {
            return (converterr(ptr[u8]("int"), arg, msgbuf, bufsize), format, va);
        }
        uval = PyLong_AsUnsignedLongLongMask(arg);
        if uval == ULONG_ALL and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pu64.view(1)[0] = uval;
    } elif c == CH_f {
        pf32 = va.arg(ptr[f32]);
        dval = PyFloat_AsDouble(arg);
        if dval == -1.0 and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pf32.view(1)[0] = f32(dval);
    } elif c == CH_d {
        pf64 = va.arg(ptr[f64]);
        dval = PyFloat_AsDouble(arg);
        if dval == -1.0 and PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pf64.view(1)[0] = dval;
    } elif c == CH_D {
        pcx = va.arg(ptr[Py_complex]);
        cval = PyComplex_AsCComplex(arg);
        if PyErr_Occurred() {
            return (msgbuf, format, va);
        }
        pcx.view(1)[0] = cval;
    } elif c == CH_c {
        pu8 = va.arg(ptr[u8]);
        if bytes_check(arg) {
            if object_size(arg) != 1 {
                return (
                    convertcharerr(
                        ptr[u8]("a byte string of length 1"),
                        ptr[u8]("a bytes object"),
                        object_size(arg),
                        msgbuf,
                        bufsize
                    ),
                    format,
                    va
                );
            }
            pu8.view(1)[0] = char_at(bytes_data(arg));
        } elif bytearray_check(arg) {
            if object_size(arg) != 1 {
                return (
                    convertcharerr(
                        ptr[u8]("a byte string of length 1"),
                        ptr[u8]("a bytearray object"),
                        object_size(arg),
                        msgbuf,
                        bufsize
                    ),
                    format,
                    va
                );
            }
            pu8.view(1)[0] = char_at(PyByteArray_AsString(arg));
        } else {
            return (
                converterr(ptr[u8]("a byte string of length 1"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
    } elif c == CH_C {
        pi32 = va.arg(ptr[i32]);
        if not unicode_check(arg) {
            return (
                converterr(ptr[u8]("a unicode character"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
        if unicode_length(arg) != 1 {
            return (
                convertcharerr(
                    ptr[u8]("a unicode character"),
                    ptr[u8]("a string"),
                    unicode_length(arg),
                    msgbuf,
                    bufsize
                ),
                format,
                va
            );
        }
        pi32.view(1)[0] = i32(PyUnicode_ReadChar(arg, 0));
    } elif c == CH_p {
        pi32 = va.arg(ptr[i32]);
        val = PyObject_IsTrue(arg);
        if val > 0 {
            pi32.view(1)[0] = 1;
        } elif val == 0 {
            pi32.view(1)[0] = 0;
        } else {
            return (msgbuf, format, va);
        }
    } elif c == CH_y {
        pv = va.arg(ptr);
        if char_at(f) == CH_STAR {
            (rc, buf) = getbuffer(arg, ptr[Py_buffer](pv));
            if rc < 0 {
                return (converterr(buf, arg, msgbuf, bufsize), format, va);
            }
            f = f + 1;
            if addcleanup(pv, freelist, int(ptr(cleanup_buffer))) != 0 {
                return (
                    converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
            return (ok, f, va);
        }
        (count, data, buf) = convertbuffer(arg, freelist);
        ptr[ptr](pv).view(1)[0] = data;
        if count < 0 {
            return (converterr(buf, arg, msgbuf, bufsize), format, va);
        }
        if char_at(f) == CH_HASH {
            psize = va.arg(ptr[i64]);
            psize.view(1)[0] = count;
            f = f + 1;
        } elif i64(strlen(ptr[u8](data))) != count {
            PyErr_SetString(PyExc_ValueError, "embedded null byte");
            return (msgbuf, format, va);
        }
    } elif c == CH_s or c == CH_z {
        if char_at(f) == CH_STAR {
            view = ptr[Py_buffer](va.arg(ptr));
            if c == CH_z and arg == Py_None {
                PyBuffer_FillInfo(view, NULL, ptr(), 0, 1, 0);
            } elif unicode_check(arg) {
                size: i64 = 0;
                sarg = PyUnicode_AsUTF8AndSize(arg, &mut size);
                if not sarg {
                    return (
                        converterr(
                            ptr[u8]("(unicode conversion error)"), arg, msgbuf, bufsize
                        ),
                        format,
                        va
                    );
                }
                PyBuffer_FillInfo(view, arg, ptr(sarg), size, 1, 0);
            } else {
                (rc, buf) = getbuffer(arg, view);
                if rc < 0 {
                    return (converterr(buf, arg, msgbuf, bufsize), format, va);
                }
            }
            if addcleanup(ptr(view), freelist, int(ptr(cleanup_buffer))) != 0 {
                return (
                    converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
            f = f + 1;
        } elif char_at(f) == CH_HASH {
            pp = va.arg(ptr[ptr]);
            psize = va.arg(ptr[i64]);
            if c == CH_z and arg == Py_None {
                pp.view(1)[0] = ptr();
                psize.view(1)[0] = 0;
            } elif unicode_check(arg) {
                size: i64 = 0;
                sarg = PyUnicode_AsUTF8AndSize(arg, &mut size);
                if not sarg {
                    return (
                        converterr(
                            ptr[u8]("(unicode conversion error)"), arg, msgbuf, bufsize
                        ),
                        format,
                        va
                    );
                }
                pp.view(1)[0] = ptr(sarg);
                psize.view(1)[0] = size;
            } else {
                (count, data, buf) = convertbuffer(arg, freelist);
                pp.view(1)[0] = data;
                if count < 0 {
                    return (converterr(buf, arg, msgbuf, bufsize), format, va);
                }
                psize.view(1)[0] = count;
            }
            f = f + 1;
        } else {
            ps = va.arg(ptr[ptr[u8]]);
            if c == CH_z and arg == Py_None {
                ps.view(1)[0] = ptr[u8]();
            } elif unicode_check(arg) {
                size: i64 = 0;
                sarg = PyUnicode_AsUTF8AndSize(arg, &mut size);
                if not sarg {
                    return (
                        converterr(
                            ptr[u8]("(unicode conversion error)"), arg, msgbuf, bufsize
                        ),
                        format,
                        va
                    );
                }
                if i64(strlen(sarg)) != size {
                    PyErr_SetString(PyExc_ValueError, "embedded null character");
                    return (msgbuf, format, va);
                }
                ps.view(1)[0] = sarg;
            } else {
                return (
                    converterr(
                        ptr[u8]("str or None") if c == CH_z else ptr[u8]("str"),
                        arg,
                        msgbuf,
                        bufsize
                    ),
                    format,
                    va
                );
            }
        }
    } elif c == CH_e {
        return convert_encoded(arg, format, f, va, msgbuf, bufsize, freelist);
    } elif c == CH_S {
        po = va.arg(ptr[ptr[PyObject]]);
        if not bytes_check(arg) {
            return (converterr(ptr[u8]("bytes"), arg, msgbuf, bufsize), format, va);
        }
        po.view(1)[0] = arg;
    } elif c == CH_Y {
        po = va.arg(ptr[ptr[PyObject]]);
        if not bytearray_check(arg) {
            return (converterr(ptr[u8]("bytearray"), arg, msgbuf, bufsize), format, va);
        }
        po.view(1)[0] = arg;
    } elif c == CH_U {
        po = va.arg(ptr[ptr[PyObject]]);
        if not unicode_check(arg) {
            return (converterr(ptr[u8]("str"), arg, msgbuf, bufsize), format, va);
        }
        po.view(1)[0] = arg;
    } elif c == CH_O {
        if char_at(f) == CH_BANG {
            type = va.arg(ptr[PyTypeObject]);
            po = va.arg(ptr[ptr[PyObject]]);
            f = f + 1;
            if PyType_IsSubtype(ptr[PyObject](object_type(arg)), ptr[PyObject](type))
                == 0 {
                return (
                    converterr(type.view(1)[0].tp_name, arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
            po.view(1)[0] = arg;
        } elif char_at(f) == CH_AMP {
            convert = va.arg(ptr);
            addr = va.arg(ptr);
            f = f + 1;
            calls = ptr[GetargsCall](
                __thread_local_block("jac_object_model_getargs_call_slot", 8)
            );
            calls.view(1)[0].converter = int(convert);
            res = calls.view(1)[0].converter(arg, addr);
            if res == 0 {
                return (
                    converterr(ptr[u8]("(unspecified)"), arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
            if res == Py_CLEANUP_SUPPORTED
                and addcleanup(addr, freelist, int(convert)) == -1 {
                return (
                    converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
        } else {
            po = va.arg(ptr[ptr[PyObject]]);
            po.view(1)[0] = arg;
        }
    } elif c == CH_w {
        pv = va.arg(ptr);
        if char_at(f) != CH_STAR {
            return (
                converterr(
                    ptr[u8]("(invalid use of 'w' format character)"),
                    arg,
                    msgbuf,
                    bufsize
                ),
                format,
                va
            );
        }
        f = f + 1;
        if PyObject_GetBuffer(arg, ptr[Py_buffer](pv), PyBUF_WRITABLE) < 0 {
            PyErr_Clear();
            return (
                converterr(
                    ptr[u8]("read-write bytes-like object"), arg, msgbuf, bufsize
                ),
                format,
                va
            );
        }
        if addcleanup(pv, freelist, int(ptr(cleanup_buffer))) != 0 {
            return (
                converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
    } else {
        return (
            converterr(ptr[u8]("(impossible<bad format char>)"), arg, msgbuf, bufsize),
            format,
            va
        );
    }
    return (ok, f, va);
}

def convert_encoded(
    arg: ptr[PyObject],
    format: ptr[u8],
    f: ptr[u8],
    va: VaList,
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList);

def error_unexpected_keyword_arg(
    kwargs: ptr[PyObject],
    kwnames: ptr[PyObject],
    kwtuple: ptr[PyObject],
    fname: ptr[u8]
);

def new_kwtuple(keywords: ptr[ptr[u8]], total: i32, pos: i32) -> ptr[PyObject];

def vgetargskeywords(
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    format: ptr[u8],
    kwlist: ptr[ptr[u8]],
    va: VaList,
    flags: i32
) -> i32;

def scan_keywords(keywords: ptr[ptr[u8]]) -> (i32, i32, i32);

def parse_format(
    format: ptr[u8], total: i32, npos: i32
) -> (i32, ptr[u8], ptr[u8], i32, i32);

impl new_kwtuple(keywords: ptr[ptr[u8]], total: i32, pos: i32) -> ptr[PyObject] {
    nkw = total - pos;
    kwtuple = PyTuple_New(i64(nkw));
    if not kwtuple {
        return NULL;
    }
    names = keywords + i64(pos);
    items = tuple_items(kwtuple);
    i: i64 = 0;
    while i < i64(nkw) {
        text = PyUnicode_FromString((names + i).view(1)[0]);
        if not text {
            object_decref(kwtuple);
            return NULL;
        }
        interp = current_interp();
        (items + i).view(1)[0] = text;
        _PyUnicode_InternImmortal(interp, items + i);
        i += 1;
    }
    return kwtuple;
}

def static_parsers_slot -> ptr[ptr[_PyArg_Parser]];

def parser_once_flag(parser: ptr[_PyArg_Parser]) -> ptr[u8];

def _parser_init(arg: ptr) -> i32;

def parser_init(parser: ptr[_PyArg_Parser]) -> i32;

def parser_clear(parser: ptr[_PyArg_Parser]);

def find_keyword(
    kwnames: ptr[PyObject], kwstack: ptr[ptr[PyObject]], key: ptr[PyObject]
) -> ptr[PyObject];

def vgetargskeywordsfast_impl(
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwargs: ptr[PyObject],
    kwnames: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    va: VaList,
    flags: i32
) -> i32;

def vgetargskeywordsfast(
    args: ptr[PyObject],
    keywords: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    va: VaList,
    flags: i32
) -> i32;

impl skip_format_item(format: ptr[u8]) -> (ptr[u8], ptr[u8], i64) {
    f = format;
    c = char_at(f);
    f = f + 1;
    slots: i64 = 0;
    bad = ptr[u8]("impossible<bad format char>");
    if c == CH_b
        or c == CH_B
        or c == CH_h
        or c == CH_H
        or c == CH_i
        or c == CH_I
        or c == CH_l
        or c == CH_k
        or c == CH_L
        or c == CH_K
        or c == CH_n
        or c == CH_f
        or c == CH_d
        or c == CH_D
        or c == CH_c
        or c == CH_C
        or c == CH_p
        or c == CH_S
        or c == CH_Y
        or c == CH_U {
        slots = 1;
    } elif c == CH_e or c == CH_s or c == CH_z or c == CH_y or c == CH_w {
        if c == CH_e {
            slots += 1;
            if not (char_at(f) == CH_s or char_at(f) == CH_t) {
                return (bad, format, 0);
            }
            f = f + 1;
        }
        slots += 1;
        if c == CH_w and char_at(f) != CH_STAR {
            return (bad, format, 0);
        }
        if char_at(f) == CH_HASH {
            slots += 1;
            f = f + 1;
        } elif (c == CH_s or c == CH_z or c == CH_y or c == CH_w)
            and char_at(f) == CH_STAR {
            f = f + 1;
        }
    } elif c == CH_O {
        if char_at(f) == CH_BANG {
            f = f + 1;
            slots = 2;
        } elif char_at(f) == CH_AMP {
            slots = 2;
            f = f + 1;
        } else {
            slots = 1;
        }
    } elif c == CH_LPAREN {
        while True {
            if char_at(f) == CH_RPAREN {
                break;
            }
            if is_end_of_format(char_at(f)) {
                return (ptr[u8]("Unmatched left paren in format string"), format, 0);
            }
            (msg, nf, inner) = skip_format_item(f);
            if msg {
                return (msg, format, 0);
            }
            f = nf;
            slots += inner;
        }
        f = f + 1;
    } elif c == CH_RPAREN {
        return (ptr[u8]("Unmatched right paren in format string"), format, 0);
    } else {
        return (bad, format, 0);
    }
    return (ptr[u8](), f, slots);
}

def unpack_stack(
    args: ptr[ptr[PyObject]], nargs: i64, name: ptr[u8], min: i64, max: i64, va: VaList
) -> i32;

import from c {
    def PyArg_Parse(args: ptr[PyObject], format: ptr[u8], *vargs: VaList) -> i32 {
        return vgetargs1(args, format, vargs, FLAG_COMPAT);
    }  def _PyArg_Parse_SizeT(
        args: ptr[PyObject], format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return vgetargs1(args, format, vargs, FLAG_COMPAT);
    }  def PyArg_ParseTuple(
        args: ptr[PyObject], format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return vgetargs1(args, format, vargs, 0);
    }  def _PyArg_ParseTuple_SizeT(
        args: ptr[PyObject], format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return vgetargs1(args, format, vargs, 0);
    }  def _PyArg_ParseStack(
        args: ptr[ptr[PyObject]], nargs: i64, format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return vgetargs1_impl(NULL, args, nargs, format, vargs, 0);
    }  def PyArg_VaParse(args: ptr[PyObject], format: ptr[u8], va: ptr) -> i32 {
        return vgetargs1(args, format, jacpy_va_list(va), 0);
    }  def _PyArg_VaParse_SizeT(args: ptr[PyObject], format: ptr[u8], va: ptr) -> i32 {
        return vgetargs1(args, format, jacpy_va_list(va), 0);
    }  def _PyArg_BadArgument(
        fname: ptr[u8], displayname: ptr[u8], expected: ptr[u8], arg: ptr[PyObject]
    ) {
        PyErr_Format(
            PyExc_TypeError,
            "%.200s() %.200s must be %.50s, not %.50s",
            fname,
            displayname,
            expected,
            type_name_or_none(arg)
        );
    }  def PyArg_ParseTupleAndKeywords(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        format: ptr[u8],
        kwlist: ptr[ptr[u8]],
        *vargs: VaList
    ) -> i32 {
        if not args
            or not tuple_check(args)
            or (keywords and not dict_check(keywords))
            or not format
            or not kwlist {
            PyErr_BadInternalCall();
            return 0;
        }
        return vgetargskeywords(args, keywords, format, kwlist, vargs, 0);
    }  def _PyArg_ParseTupleAndKeywords_SizeT(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        format: ptr[u8],
        kwlist: ptr[ptr[u8]],
        *vargs: VaList
    ) -> i32 {
        if not args
            or not tuple_check(args)
            or (keywords and not dict_check(keywords))
            or not format
            or not kwlist {
            PyErr_BadInternalCall();
            return 0;
        }
        return vgetargskeywords(args, keywords, format, kwlist, vargs, 0);
    }  def PyArg_VaParseTupleAndKeywords(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        format: ptr[u8],
        kwlist: ptr[ptr[u8]],
        va: ptr
    ) -> i32 {
        if not args
            or not tuple_check(args)
            or (keywords and not dict_check(keywords))
            or not format
            or not kwlist {
            PyErr_BadInternalCall();
            return 0;
        }
        return vgetargskeywords(args, keywords, format, kwlist, jacpy_va_list(va), 0);
    }  def _PyArg_VaParseTupleAndKeywords_SizeT(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        format: ptr[u8],
        kwlist: ptr[ptr[u8]],
        va: ptr
    ) -> i32 {
        if not args
            or not tuple_check(args)
            or (keywords and not dict_check(keywords))
            or not format
            or not kwlist {
            PyErr_BadInternalCall();
            return 0;
        }
        return vgetargskeywords(args, keywords, format, kwlist, jacpy_va_list(va), 0);
    }  def _PyArg_ParseTupleAndKeywordsFast(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        *vargs: VaList
    ) -> i32 {
        return vgetargskeywordsfast(args, keywords, parser, vargs, 0);
    }  def _PyArg_ParseTupleAndKeywordsFast_SizeT(
        args: ptr[PyObject],
        keywords: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        *vargs: VaList
    ) -> i32 {
        return vgetargskeywordsfast(args, keywords, parser, vargs, 0);
    }  def _PyArg_ParseStackAndKeywords(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        *vargs: VaList
    ) -> i32 {
        return vgetargskeywordsfast_impl(args, nargs, NULL, kwnames, parser, vargs, 0);
    }  def _PyArg_ParseStackAndKeywords_SizeT(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        *vargs: VaList
    ) -> i32 {
        return vgetargskeywordsfast_impl(args, nargs, NULL, kwnames, parser, vargs, 0);
    }  def PyArg_ValidateKeywordArguments(kwargs: ptr[PyObject]) -> i32 {
        if not dict_check(kwargs) {
            PyErr_BadInternalCall();
            return 0;
        }
        if _PyDict_HasOnlyStringKeys(kwargs) == 0 {
            PyErr_SetString(PyExc_TypeError, "keywords must be strings");
            return 0;
        }
        return 1;
    }  def _PyArg_UnpackKeywords(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwargs: ptr[PyObject],
        kwnames: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        minpos: i32,
        maxpos: i32,
        minkw: i32,
        varpos: i32,
        buf: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]] {
        reqlimit = maxpos + minkw if minkw != 0 else minpos;
        if not parser {
            PyErr_BadInternalCall();
            return ptr[ptr[PyObject]]();
        }
        if kwnames and not tuple_check(kwnames) {
            PyErr_BadInternalCall();
            return ptr[ptr[PyObject]]();
        }
        if not args and nargs == 0 {
            args = buf;
        }
        if parser_init(parser) < 0 {
            return ptr[ptr[PyObject]]();
        }
        kwtuple = parser.view(1)[0].kwtuple;
        posonly = parser.view(1)[0].pos;
        minposonly = min_i32(posonly, minpos);
        maxargs = posonly + i32.wrap(object_size(kwtuple));
        kwstack = ptr[ptr[PyObject]]();
        nkwargs: i64 = 0;
        if kwargs {
            nkwargs = dict_size(kwargs);
        } elif kwnames {
            nkwargs = object_size(kwnames);
            kwstack = args + nargs;
        }
        if nkwargs == 0
            and minkw == 0
            and i64(minpos) <= nargs
            and (varpos != 0 or nargs <= i64(maxpos)) {
            return args;
        }
        fname = parser.view(1)[0].fname;
        if varpos == 0 and nargs + nkwargs > i64(maxargs) {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes at most %d %sargument%s (%zd given)",
                fname_or_function(fname),
                fname_parens(fname),
                maxargs,
                ptr[u8]("keyword ") if nargs == 0 else ptr[u8](""),
                plural(i64(maxargs)),
                nargs + nkwargs
            );
            return ptr[ptr[PyObject]]();
        }
        if varpos == 0 and nargs > i64(maxpos) {
            if maxpos == 0 {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s takes no positional arguments",
                    fname_or_function(fname),
                    fname_parens(fname)
                );
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s takes %s %d positional argument%s (%zd given)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    ptr[u8]("at most") if minpos < maxpos else ptr[u8]("exactly"),
                    maxpos,
                    plural(i64(maxpos)),
                    nargs
                );
            }
            return ptr[ptr[PyObject]]();
        }
        if nargs < i64(minposonly) {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes %s %d positional argument%s (%zd given)",
                fname_or_function(fname),
                fname_parens(fname),
                ptr[u8]("at least")
                    if varpos != 0 or minposonly < maxpos
                    else ptr[u8]("exactly"),
                minposonly,
                plural(i64(minposonly)),
                nargs
            );
            return ptr[ptr[PyObject]]();
        }
        if varpos != 0 and i64(maxpos) < nargs {
            nargs = i64(maxpos);
        }

        for k in range(nargs) {
            (buf + k).view(1)[0] = (args + k).view(1)[0];
        }

        i = max_i32(i32.wrap(nargs), posonly);
        while i < maxargs {
            current_arg = NULL;
            if nkwargs != 0 {
                keyword = tuple_get_item(kwtuple, i64(i - posonly));
                if kwargs {
                    if PyDict_GetItemRef(kwargs, keyword, &mut current_arg) < 0 {
                        return ptr[ptr[PyObject]]();
                    }
                } else {
                    current_arg = find_keyword(kwnames, kwstack, keyword);
                }
            } elif i >= reqlimit {
                break;
            }
            (buf + i64(i)).view(1)[0] = current_arg;
            if current_arg {
                object_decref(current_arg);
                nkwargs -= 1;
            } elif i < minpos or (maxpos <= i and i < reqlimit) {
                keyword = tuple_get_item(kwtuple, i64(i - posonly));
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s missing required argument '%U' (pos %d)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    keyword,
                    i + 1
                );
                return ptr[ptr[PyObject]]();
            }
            i += 1;
        }
        if nkwargs > 0 {
            k = i64(posonly);
            while k < nargs {
                current_arg = NULL;
                keyword = tuple_get_item(kwtuple, k - i64(posonly));
                if kwargs {
                    if PyDict_GetItemRef(kwargs, keyword, &mut current_arg) < 0 {
                        return ptr[ptr[PyObject]]();
                    }
                } else {
                    current_arg = find_keyword(kwnames, kwstack, keyword);
                }
                if current_arg {
                    object_decref(current_arg);

                    PyErr_Format(
                        PyExc_TypeError,
                        "argument for %.200s%s given by name ('%U') and position (%d)",
                        fname_or_function(fname),
                        fname_parens(fname),
                        keyword,
                        i32.wrap(k + 1)
                    );
                    return ptr[ptr[PyObject]]();
                }
                k += 1;
            }
            error_unexpected_keyword_arg(kwargs, kwnames, kwtuple, fname);
            return ptr[ptr[PyObject]]();
        }
        return buf;
    }  def _PyArg_CheckPositional(
        name: ptr[u8], nargs: i64, min: i64, max: i64
    ) -> i32 {
        if nargs < min {
            if name {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s expected %s%zd argument%s, got %zd",
                    name,
                    ptr[u8]("") if min == max else ptr[u8]("at least "),
                    min,
                    plural(min),
                    nargs
                );
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "unpacked tuple should have %s%zd element%s, but has %zd",
                    ptr[u8]("") if min == max else ptr[u8]("at least "),
                    min,
                    plural(min),
                    nargs
                );
            }
            return 0;
        }
        if nargs == 0 {
            return 1;
        }
        if nargs > max {
            if name {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s expected %s%zd argument%s, got %zd",
                    name,
                    ptr[u8]("") if min == max else ptr[u8]("at most "),
                    max,
                    plural(max),
                    nargs
                );
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "unpacked tuple should have %s%zd element%s, but has %zd",
                    ptr[u8]("") if min == max else ptr[u8]("at most "),
                    max,
                    plural(max),
                    nargs
                );
            }
            return 0;
        }
        return 1;
    }  def PyArg_UnpackTuple(
        args: ptr[PyObject], name: ptr[u8], min: i64, max: i64, *vargs: VaList
    ) -> i32 {
        if not tuple_check(args) {
            PyErr_SetString(
                PyExc_SystemError, "PyArg_UnpackTuple() argument list is not a tuple"
            );
            return 0;
        }
        return unpack_stack(
            tuple_items(args), object_size(args), name, min, max, vargs
        );
    }  def _PyArg_UnpackStack(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        name: ptr[u8],
        min: i64,
        max: i64,
        *vargs: VaList
    ) -> i32 {
        return unpack_stack(args, nargs, name, min, max, vargs);
    }  def _PyArg_NoKeywords(funcname: ptr[u8], kwargs: ptr[PyObject]) -> i32 {
        if not kwargs {
            return 1;
        }
        if not dict_check_exact(kwargs) {
            PyErr_BadInternalCall();
            return 0;
        }
        if dict_size(kwargs) == 0 {
            return 1;
        }
        PyErr_Format(PyExc_TypeError, "%.200s() takes no keyword arguments", funcname);
        return 0;
    }  def _PyArg_NoPositional(funcname: ptr[u8], args: ptr[PyObject]) -> i32 {
        if not args {
            return 1;
        }
        if not tuple_check_exact(args) {
            PyErr_BadInternalCall();
            return 0;
        }
        if object_size(args) == 0 {
            return 1;
        }
        PyErr_Format(
            PyExc_TypeError, "%.200s() takes no positional arguments", funcname
        );
        return 0;
    }  def _PyArg_NoKwnames(funcname: ptr[u8], kwnames: ptr[PyObject]) -> i32 {
        if not kwnames {
            return 1;
        }
        if object_size(kwnames) == 0 {
            return 1;
        }
        PyErr_Format(PyExc_TypeError, "%s() takes no keyword arguments", funcname);
        return 0;
    }  def _PyArg_Fini {
        slot = static_parsers_slot();
        s = slot.view(1)[0];
        while s {
            tmp = s.view(1)[0].next;
            s.view(1)[0].next = ptr[_PyArg_Parser]();
            parser_clear(s);
            s = tmp;
        }
        slot.view(1)[0] = ptr[_PyArg_Parser]();
    }
}

impl frame_freelist(address: int) -> ptr[Freelist] {
    return ptr[Freelist](address);
}

impl frame_levels(freelist: ptr[Freelist]) -> ptr[i32] {
    return ptr[i32](ptr[u8](freelist) + FRAME_LEVELS);
}

impl frame_view(freelist: ptr[Freelist]) -> ptr[Py_buffer] {
    return ptr[Py_buffer](ptr[u8](freelist) + FRAME_VIEW);
}

impl frame_msgbuf(freelist: ptr[Freelist]) -> ptr[u8] {
    return ptr[u8](freelist) + FRAME_MSGBUF;
}

impl freelist_init(freelist: ptr[Freelist]) {
    freelist.view(1)[0].entries = ptr[FreelistEntry](ptr[u8](freelist) + FRAME_ENTRIES);
    freelist.view(1)[0].first_available = 0;
    freelist.view(1)[0].entries_malloced = 0;
}

impl freelist_reserve(freelist: ptr[Freelist], count: i32) -> bool {
    if count > STATIC_FREELIST_ENTRIES {
        entries = ptr[FreelistEntry](PyMem_Malloc(u64(count) * u64(16)));
        if not entries {
            PyErr_NoMemory();
            return False;
        }
        freelist.view(1)[0].entries = entries;
        freelist.view(1)[0].entries_malloced = 1;
    }
    return True;
}

impl char_at(p: ptr[u8]) -> u8 {
    return p.view(1)[0];
}

impl is_alpha(c: u8) -> bool {
    return (c >= u8(97) and c <= u8(122)) or (c >= u8(65) and c <= u8(90));
}

impl is_end_of_format(c: u8) -> bool {
    return c == CH_NUL or c == CH_SEMI or c == CH_COLON;
}

impl fname_or_function(fname: ptr[u8]) -> ptr[u8] {
    return ptr[u8]("function") if not fname else fname;
}

impl fname_or_this(fname: ptr[u8]) -> ptr[u8] {
    return ptr[u8]("this function") if not fname else fname;
}

impl fname_parens(fname: ptr[u8]) -> ptr[u8] {
    return ptr[u8]("") if not fname else ptr[u8]("()");
}

impl plural(n: i64) -> ptr[u8] {
    return ptr[u8]("") if n == 1 else ptr[u8]("s");
}

impl type_name_or_none(arg: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8]("None") if arg == Py_None else object_type(arg).view(1)[0].tp_name;
}

impl dict_size(op: ptr[PyObject]) -> i64 {
    return ptr[PyDictObject](op).view(1)[0].ma_used;
}

impl min_i32(a: i32, b: i32) -> i32 {
    return a if a < b else b;
}

impl max_i32(a: i32, b: i32) -> i32 {
    return a if a > b else b;
}

impl set_error_text(exception: ptr[PyObject], text: ptr[u8]) {
    value = PyUnicode_FromString(text);
    if value {
        PyErr_SetObject(exception, value);
        object_decref(value);
    }
}

impl cleanup_ptr(self_: ptr[PyObject], p: ptr) -> i32 {
    pptr = ptr[ptr](p);
    PyMem_Free(pptr.view(1)[0]);
    pptr.view(1)[0] = ptr();
    return 0;
}

impl cleanup_buffer(self_: ptr[PyObject], p: ptr) -> i32 {
    buf = ptr[Py_buffer](p);
    if buf {
        PyBuffer_Release(buf);
    }
    return 0;
}

impl addcleanup(p: ptr, freelist: ptr[Freelist], destructor: int) -> i32 {
    index = freelist.view(1)[0].first_available;
    freelist.view(1)[0].first_available = index + 1;
    slot_entry = freelist.view(1)[0].entries + i64(index);
    slot_entry.view(1)[0].item = p;
    slot_entry.view(1)[0].destructor = destructor;
    return 0;
}

impl cleanreturn(retval: i32, freelist: ptr[Freelist]) -> i32 {
    entries = freelist.view(1)[0].entries;
    if retval == 0 {
        index: i32 = 0;
        while index < freelist.view(1)[0].first_available {
            slot_entry = entries + i64(index);
            slot_entry.view(1)[0].destructor(NULL, slot_entry.view(1)[0].item);
            index += 1;
        }
    }
    if freelist.view(1)[0].entries_malloced != 0 {
        PyMem_Free(ptr(entries));
    }
    return retval;
}

impl vgetargs1_impl(
    compat_args: ptr[PyObject],
    stack: ptr[ptr[PyObject]],
    nargs: i64,
    format: ptr[u8],
    va: VaList,
    flags: i32
) -> i32 {
    frame: own ParseFrame = ParseFrame();
    freelist = frame_freelist(jacpy_stack_address(&mut frame));
    freelist_init(freelist);
    levels = frame_levels(freelist);
    msgbuf = frame_msgbuf(freelist);
    fname = ptr[u8]();
    message = ptr[u8]();
    min: i32 = -1;
    max: i32 = 0;
    level: i32 = 0;
    endfmt = False;
    formatsave = format;
    compat = flags & FLAG_COMPAT;
    fl = flags & ~FLAG_COMPAT;
    f = format;
    while not endfmt {
        c = char_at(f);
        f = f + 1;
        if c == CH_LPAREN {
            if level == 0 {
                max += 1;
            }
            level += 1;
            if level >= 30 {
                Py_FatalError(
                    "too many tuple nesting levels in argument format string"
                );
            }
        } elif c == CH_RPAREN {
            if level == 0 {
                Py_FatalError("excess ')' in getargs format");
            } else {
                level -= 1;
            }
        } elif c == CH_NUL {
            endfmt = True;
        } elif c == CH_COLON {
            fname = f;
            endfmt = True;
        } elif c == CH_SEMI {
            message = f;
            endfmt = True;
        } elif c == CH_BAR {
            if level == 0 {
                min = max;
            }
        } elif level == 0 and is_alpha(c) and c != CH_e {
            max += 1;
        }
    }
    if level != 0 {
        Py_FatalError("missing ')' in getargs format");
    }
    if min < 0 {
        min = max;
    }
    f = formatsave;
    if not freelist_reserve(freelist, max) {
        return 0;
    }
    if compat != 0 {
        if max == 0 {
            if not compat_args {
                return 1;
            }
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes no arguments",
                fname_or_function(fname),
                fname_parens(fname)
            );
            return cleanreturn(0, freelist);
        } elif min == 1 and max == 1 {
            if not compat_args {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s takes at least one argument",
                    fname_or_function(fname),
                    fname_parens(fname)
                );
                return cleanreturn(0, freelist);
            }
            (msg, f, va) = convertitem(
                compat_args, f, va, fl, levels, msgbuf, 256, freelist
            );
            if not msg {
                return cleanreturn(1, freelist);
            }
            seterror(i64(levels.view(1)[0]), msg, levels + 1, fname, message);
            return cleanreturn(0, freelist);
        } else {
            PyErr_SetString(
                PyExc_SystemError, "old style getargs format uses new features"
            );
            return cleanreturn(0, freelist);
        }
    }
    if nargs < i64(min) or i64(max) < nargs {
        if not message {
            bound = min if nargs < i64(min) else max;
            how = ptr[u8]("exactly");
            if min != max {
                how = ptr[u8]("at least") if nargs < i64(min) else ptr[u8]("at most");
            }
            PyErr_Format(
                PyExc_TypeError,
                "%.150s%s takes %s %d argument%s (%zd given)",
                fname_or_function(fname),
                fname_parens(fname),
                how,
                bound,
                plural(i64(bound)),
                nargs
            );
        } else {
            set_error_text(PyExc_TypeError, message);
        }
        return cleanreturn(0, freelist);
    }
    for i in range(nargs) {
        if char_at(f) == CH_BAR {
            f = f + 1;
        }
        (msg, f, va) = convertitem(
            (stack + i).view(1)[0], f, va, fl, levels, msgbuf, 256, freelist
        );
        if msg {
            seterror(i + 1, msg, levels, fname, message);
            return cleanreturn(0, freelist);
        }
    }
    tail = char_at(f);
    if tail != CH_NUL
        and not is_alpha(tail)
        and tail != CH_LPAREN
        and tail != CH_BAR
        and tail != CH_COLON
        and tail != CH_SEMI {
        PyErr_Format(PyExc_SystemError, "bad format string: %.200s", formatsave);
        return cleanreturn(0, freelist);
    }
    return cleanreturn(1, freelist);
}

impl vgetargs1(args: ptr[PyObject], format: ptr[u8], va: VaList, flags: i32) -> i32 {
    stack = ptr[ptr[PyObject]]();
    nargs: i64 = 0;
    if (flags & FLAG_COMPAT) == 0 {
        if not tuple_check(args) {
            PyErr_SetString(
                PyExc_SystemError,
                "new style getargs format but argument is not a tuple"
            );
            return 0;
        }
        stack = tuple_items(args);
        nargs = object_size(args);
    }
    return vgetargs1_impl(args, stack, nargs, format, va, flags);
}

impl used(p: ptr[u8], buf: ptr[u8]) -> i64 {
    return i64(int(p) - int(buf));
}

impl seterror(
    iarg: i64, msg: ptr[u8], levels: ptr[i32], fname: ptr[u8], message: ptr[u8]
) {
    if PyErr_Occurred() {
        return;
    }
    if not message {
        frame: own ParseFrame = ParseFrame();
        buf = ptr[u8](jacpy_stack_address(&mut frame));
        bufsize: i64 = 512;
        p = buf;
        if fname {
            PyOS_snprintf(p, u64(bufsize), ptr[u8]("%.200s() "), fname);
            p = p + i64(strlen(p));
        }
        if iarg != 0 {
            PyOS_snprintf(
                p, u64(bufsize - used(p, buf)), ptr[u8]("argument %zd"), iarg
            );
            i: i64 = 0;
            p = p + i64(strlen(p));
            while i < 32 and (levels + i).view(1)[0] > 0 and used(p, buf) < 220 {
                PyOS_snprintf(
                    p,
                    u64(bufsize - used(p, buf)),
                    ptr[u8](", item %d"),
                    (levels + i).view(1)[0] - 1
                );
                p = p + i64(strlen(p));
                i += 1;
            }
        } else {
            PyOS_snprintf(p, u64(bufsize - used(p, buf)), ptr[u8]("argument"));
            p = p + i64(strlen(p));
        }
        PyOS_snprintf(p, u64(bufsize - used(p, buf)), ptr[u8](" %.256s"), msg);
        message = buf;
    }
    if char_at(msg) == CH_LPAREN {
        set_error_text(PyExc_SystemError, message);
    } else {
        set_error_text(PyExc_TypeError, message);
    }
}

impl converterr(
    expected: ptr[u8], arg: ptr[PyObject], msgbuf: ptr[u8], bufsize: i64
) -> ptr[u8] {
    if char_at(expected) == CH_LPAREN {
        PyOS_snprintf(msgbuf, u64(bufsize), ptr[u8]("%.100s"), expected);
    } else {
        PyOS_snprintf(
            msgbuf,
            u64(bufsize),
            ptr[u8]("must be %.50s, not %.50s"),
            expected,
            type_name_or_none(arg)
        );
    }
    return msgbuf;
}

impl convertcharerr(
    expected: ptr[u8], what: ptr[u8], size: i64, msgbuf: ptr[u8], bufsize: i64
) -> ptr[u8] {
    PyOS_snprintf(
        msgbuf,
        u64(bufsize),
        ptr[u8]("must be %.50s, not %.50s of length %zd"),
        expected,
        what,
        size
    );
    return msgbuf;
}

impl getbuffer(arg: ptr[PyObject], view: ptr[Py_buffer]) -> (i32, ptr[u8]) {
    if PyObject_GetBuffer(arg, view, PyBUF_SIMPLE) != 0 {
        return (i32(-1), ptr[u8]("bytes-like object"));
    }
    return (i32(0), ptr[u8]());
}

impl convertbuffer(arg: ptr[PyObject], freelist: ptr[Freelist]) -> (i64, ptr, ptr[u8]) {
    pb = object_type(arg).view(1)[0].tp_as_buffer;
    if pb and int(pb.view(1)[0].bf_releasebuffer) != 0 {
        return (i64(-1), ptr(), ptr[u8]("read-only bytes-like object"));
    }
    view = frame_view(freelist);
    (rc, errmsg) = getbuffer(arg, view);
    if rc < 0 {
        return (i64(-1), ptr(), errmsg);
    }
    count = view.view(1)[0].length;
    data = view.view(1)[0].buf;
    PyBuffer_Release(view);
    return (count, data, ptr[u8]());
}

impl convert_encoded(
    arg: ptr[PyObject],
    format: ptr[u8],
    f: ptr[u8],
    va: VaList,
    msgbuf: ptr[u8],
    bufsize: i64,
    freelist: ptr[Freelist]
) -> (ptr[u8], ptr[u8], VaList) {
    encoding = va.arg(ptr[u8]);
    if not encoding {
        encoding = PyUnicode_GetDefaultEncoding();
    }

    recode_strings = False;
    if char_at(f) == CH_s {
        recode_strings = True;
    } elif char_at(f) != CH_t {
        return (
            converterr(
                ptr[u8]("(unknown parser marker combination)"), arg, msgbuf, bufsize
            ),
            format,
            va
        );
    }
    buffer = va.arg(ptr[ptr[u8]]);
    f = f + 1;
    if not buffer {
        return (
            converterr(ptr[u8]("(buffer is NULL)"), arg, msgbuf, bufsize),
            format,
            va
        );
    }

    s = NULL;
    size: i64 = 0;
    data = ptr[u8]();
    if not recode_strings and (bytes_check(arg) or bytearray_check(arg)) {
        s = object_new_ref(arg);
        size = object_size(s);
        if bytes_check(arg) {
            data = bytes_data(s);
        } else {
            data = PyByteArray_AsString(s);
        }
    } elif unicode_check(arg) {
        s = PyUnicode_AsEncodedString(arg, encoding, ptr[u8]());
        if not s {
            return (
                converterr(ptr[u8]("(encoding failed)"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
        size = object_size(s);
        data = bytes_data(s);
        if not data {
            data = ptr[u8]("");
        }
    } else {
        return (
            converterr(
                ptr[u8]("str")
                    if recode_strings
                    else ptr[u8]("str, bytes or bytearray"),
                arg,
                msgbuf,
                bufsize
            ),
            format,
            va
        );
    }

    if char_at(f) == CH_HASH {
        psize = va.arg(ptr[i64]);
        f = f + 1;
        if not psize {
            object_decref(s);
            return (
                converterr(ptr[u8]("(buffer_len is NULL)"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
        if not buffer.view(1)[0] {
            buffer.view(1)[0] = ptr[u8](PyMem_Malloc(u64(size + 1)));
            if not buffer.view(1)[0] {
                object_decref(s);
                PyErr_NoMemory();
                return (msgbuf, format, va);
            }
            if addcleanup(ptr(buffer), freelist, int(ptr(cleanup_ptr))) != 0 {
                object_decref(s);
                return (
                    converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                    format,
                    va
                );
            }
        } elif size + 1 > psize.view(1)[0] {
            object_decref(s);
            PyErr_Format(
                PyExc_ValueError,
                "encoded string too long (%zd, maximum length %zd)",
                size,
                psize.view(1)[0] - 1
            );
            return (msgbuf, format, va);
        }
        memcpy(ptr(buffer.view(1)[0]), ptr(data), u64(size + 1));
        psize.view(1)[0] = size;
    } else {
        if i64(strlen(data)) != size {
            object_decref(s);
            return (
                converterr(
                    ptr[u8]("encoded string without null bytes"), arg, msgbuf, bufsize
                ),
                format,
                va
            );
        }
        buffer.view(1)[0] = ptr[u8](PyMem_Malloc(u64(size + 1)));
        if not buffer.view(1)[0] {
            object_decref(s);
            PyErr_NoMemory();
            return (msgbuf, format, va);
        }
        if addcleanup(ptr(buffer), freelist, int(ptr(cleanup_ptr))) != 0 {
            object_decref(s);
            return (
                converterr(ptr[u8]("(cleanup problem)"), arg, msgbuf, bufsize),
                format,
                va
            );
        }
        memcpy(ptr(buffer.view(1)[0]), ptr(data), u64(size + 1));
    }
    object_decref(s);
    return (ptr[u8](), f, va);
}

impl error_unexpected_keyword_arg(
    kwargs: ptr[PyObject],
    kwnames: ptr[PyObject],
    kwtuple: ptr[PyObject],
    fname: ptr[u8]
) {
    j: i64 = 0;
    while True {
        keyword = NULL;
        if kwargs {
            unused = NULL;
            if PyDict_Next(kwargs, &mut j, &mut keyword, &mut unused) == 0 {
                break;
            }
        } else {
            if j >= object_size(kwnames) {
                break;
            }
            keyword = tuple_get_item(kwnames, j);
            j += 1;
        }
        if not unicode_check(keyword) {
            PyErr_SetString(PyExc_TypeError, "keywords must be strings");
            return;
        }
        matched = PySequence_Contains(kwtuple, keyword);
        if matched <= 0 {
            if matched == 0 {
                kwlist = PySequence_List(kwtuple);
                if not kwlist {
                    return;
                }
                suggestion_keyword = _Py_CalculateSuggestions(kwlist, keyword);
                object_decref(kwlist);
                if suggestion_keyword {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s got an unexpected keyword argument '%S'. Did you mean '%S'?",
                        fname_or_this(fname),
                        fname_parens(fname),
                        keyword,
                        suggestion_keyword
                    );
                    object_decref(suggestion_keyword);
                } else {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s got an unexpected keyword argument '%S'",
                        fname_or_this(fname),
                        fname_parens(fname),
                        keyword
                    );
                }
            }
            return;
        }
    }

    PyErr_Format(
        PyExc_TypeError,
        "invalid keyword argument for %.200s%s",
        fname_or_this(fname),
        fname_parens(fname)
    );
}

impl vgetargskeywords(
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    format: ptr[u8],
    kwlist: ptr[ptr[u8]],
    va: VaList,
    flags: i32
) -> i32 {
    frame: own ParseFrame = ParseFrame();
    freelist = frame_freelist(jacpy_stack_address(&mut frame));
    freelist_init(freelist);
    levels = frame_levels(freelist);
    msgbuf = frame_msgbuf(freelist);
    min = INT_MAX;
    max = INT_MAX;
    skipping = False;

    custom_msg = ptr[u8]();
    fname = strchr(format, 58);
    if fname {
        fname = fname + 1;
    } else {
        custom_msg = strchr(format, 59);
        if custom_msg {
            custom_msg = custom_msg + 1;
        }
    }

    pos: i32 = 0;
    while (kwlist + i64(pos)).view(1)[0]
        and char_at((kwlist + i64(pos)).view(1)[0]) == CH_NUL {
        pos += 1;
    }

    len = pos;
    while (kwlist + i64(len)).view(1)[0] {
        if char_at((kwlist + i64(len)).view(1)[0]) == CH_NUL {
            PyErr_SetString(PyExc_SystemError, "Empty keyword parameter name");
            return cleanreturn(0, freelist);
        }
        len += 1;
    }
    if not freelist_reserve(freelist, len) {
        return 0;
    }
    nargs = object_size(args);
    nkwargs: i64 = 0 if not kwargs else dict_size(kwargs);
    if nargs + nkwargs > i64(len) {
        PyErr_Format(
            PyExc_TypeError,
            "%.200s%s takes at most %d %sargument%s (%zd given)",
            fname_or_function(fname),
            fname_parens(fname),
            len,
            ptr[u8]("keyword ") if nargs == 0 else ptr[u8](""),
            plural(i64(len)),
            nargs + nkwargs
        );
        return cleanreturn(0, freelist);
    }

    f = format;
    i: i32 = 0;
    while i < len {
        if char_at(f) == CH_BAR {
            if min != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string (| specified twice)"
                );
                return cleanreturn(0, freelist);
            }
            min = i;
            f = f + 1;
            if max != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string ($ before |)"
                );
                return cleanreturn(0, freelist);
            }
        }
        if char_at(f) == CH_DOLLAR {
            if max != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string ($ specified twice)"
                );
                return cleanreturn(0, freelist);
            }
            max = i;
            f = f + 1;
            if max < pos {
                PyErr_SetString(PyExc_SystemError, "Empty parameter name after $");
                return cleanreturn(0, freelist);
            }
            if skipping {
                break;
            }
            if i64(max) < nargs {
                if max == 0 {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s takes no positional arguments",
                        fname_or_function(fname),
                        fname_parens(fname)
                    );
                } else {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s takes %s %d positional argument%s (%zd given)",
                        fname_or_function(fname),
                        fname_parens(fname),
                        ptr[u8]("at most") if min != INT_MAX else ptr[u8]("exactly"),
                        max,
                        plural(i64(max)),
                        nargs
                    );
                }
                return cleanreturn(0, freelist);
            }
        }
        if is_end_of_format(char_at(f)) {
            PyErr_Format(
                PyExc_SystemError,
                "More keyword list entries (%d) than format specifiers (%d)",
                len,
                i
            );
            return cleanreturn(0, freelist);
        }
        if not skipping {
            current_arg = NULL;
            if i64(i) < nargs {
                current_arg = object_new_ref(tuple_get_item(args, i64(i)));
            } elif nkwargs != 0 and i >= pos {
                if PyDict_GetItemStringRef(
                    kwargs, (kwlist + i64(i)).view(1)[0], &mut current_arg
                )
                    < 0 {
                    return cleanreturn(0, freelist);
                }
                if current_arg {
                    nkwargs -= 1;
                }
            }
            if current_arg {
                (msg, f, va) = convertitem(
                    current_arg, f, va, flags, levels, msgbuf, 512, freelist
                );
                object_decref(current_arg);
                if msg {
                    seterror(i64(i) + 1, msg, levels, fname, custom_msg);
                    return cleanreturn(0, freelist);
                }
                i += 1;
                continue;
            }
            if i < min {
                if i < pos {
                    skipping = True;
                } else {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s missing required argument '%s' (pos %d)",
                        fname_or_function(fname),
                        fname_parens(fname),
                        (kwlist + i64(i)).view(1)[0],
                        i + 1
                    );
                    return cleanreturn(0, freelist);
                }
            }

            if nkwargs == 0 and not skipping {
                return cleanreturn(1, freelist);
            }
        }

        (msg, nf, count) = skip_format_item(f);
        if msg {
            PyErr_Format(PyExc_SystemError, "%s: '%s'", msg, f);
            return cleanreturn(0, freelist);
        }
        f = nf;
        for skipped in range(count) {
            va.arg(ptr);
        }
        i += 1;
    }
    if skipping {
        least = min_i32(pos, min);
        PyErr_Format(
            PyExc_TypeError,
            "%.200s%s takes %s %d positional argument%s (%zd given)",
            fname_or_function(fname),
            fname_parens(fname),
            ptr[u8]("at least") if least < i else ptr[u8]("exactly"),
            least,
            plural(i64(least)),
            nargs
        );
        return cleanreturn(0, freelist);
    }
    if not is_end_of_format(char_at(f))
        and char_at(f) != CH_BAR
        and char_at(f) != CH_DOLLAR {
        PyErr_Format(
            PyExc_SystemError,
            "more argument specifiers than keyword list entries (remaining format:'%s')",
            f
        );
        return cleanreturn(0, freelist);
    }
    if nkwargs > 0 {
        k = i64(pos);
        while k < nargs {
            current_arg = NULL;
            if PyDict_GetItemStringRef(
                kwargs, (kwlist + k).view(1)[0], &mut current_arg
            )
                < 0 {
                return cleanreturn(0, freelist);
            }
            if current_arg {
                object_decref(current_arg);

                PyErr_Format(
                    PyExc_TypeError,
                    "argument for %.200s%s given by name ('%s') and position (%d)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    (kwlist + k).view(1)[0],
                    i32.wrap(k + 1)
                );
                return cleanreturn(0, freelist);
            }
            k += 1;
        }

        j: i64 = 0;
        key = NULL;
        unused = NULL;
        while PyDict_Next(kwargs, &mut j, &mut key, &mut unused) != 0 {
            matched = False;
            if not unicode_check(key) {
                PyErr_SetString(PyExc_TypeError, "keywords must be strings");
                return cleanreturn(0, freelist);
            }
            m = pos;
            while m < len {
                if PyUnicode_EqualToUTF8(key, (kwlist + i64(m)).view(1)[0]) != 0 {
                    matched = True;
                    break;
                }
                m += 1;
            }
            if not matched {
                pykwtuple = new_kwtuple(kwlist, len, pos);
                if not pykwtuple {
                    return cleanreturn(0, freelist);
                }
                pykwlist = PySequence_List(pykwtuple);
                object_decref(pykwtuple);
                if not pykwlist {
                    return cleanreturn(0, freelist);
                }
                suggestion_keyword = _Py_CalculateSuggestions(pykwlist, key);
                object_decref(pykwlist);
                if suggestion_keyword {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s got an unexpected keyword argument '%S'. Did you mean '%S'?",
                        fname_or_this(fname),
                        fname_parens(fname),
                        key,
                        suggestion_keyword
                    );
                    object_decref(suggestion_keyword);
                } else {
                    PyErr_Format(
                        PyExc_TypeError,
                        "%.200s%s got an unexpected keyword argument '%S'",
                        fname_or_this(fname),
                        fname_parens(fname),
                        key
                    );
                }
                return cleanreturn(0, freelist);
            }
        }

        PyErr_Format(
            PyExc_TypeError,
            "invalid keyword argument for %.200s%s",
            fname_or_this(fname),
            fname_parens(fname)
        );
        return cleanreturn(0, freelist);
    }
    return cleanreturn(1, freelist);
}

impl scan_keywords(keywords: ptr[ptr[u8]]) -> (i32, i32, i32) {
    i: i32 = 0;
    while (keywords + i64(i)).view(1)[0]
        and char_at((keywords + i64(i)).view(1)[0]) == CH_NUL {
        i += 1;
    }
    posonly = i;
    while (keywords + i64(i)).view(1)[0] {
        if char_at((keywords + i64(i)).view(1)[0]) == CH_NUL {
            PyErr_SetString(PyExc_SystemError, "Empty keyword parameter name");
            return (i32(-1), i32(0), posonly);
        }
        i += 1;
    }
    return (i32(0), i, posonly);
}

impl parse_format(
    format: ptr[u8], total: i32, npos: i32
) -> (i32, ptr[u8], ptr[u8], i32, i32) {
    custommsg = ptr[u8]();
    fname = strchr(format, 58);
    if fname {
        fname = fname + 1;
    } else {
        custommsg = strchr(format, 59);
        if custommsg {
            custommsg = custommsg + 1;
        }
    }
    min = INT_MAX;
    max = INT_MAX;
    f = format;
    i: i32 = 0;
    while i < total {
        if char_at(f) == CH_BAR {
            if min != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string (| specified twice)"
                );
                return (i32(-1), fname, custommsg, min, max);
            }
            if max != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string ($ before |)"
                );
                return (i32(-1), fname, custommsg, min, max);
            }
            min = i;
            f = f + 1;
        }
        if char_at(f) == CH_DOLLAR {
            if max != INT_MAX {
                PyErr_SetString(
                    PyExc_SystemError, "Invalid format string ($ specified twice)"
                );
                return (i32(-1), fname, custommsg, min, max);
            }
            if i < npos {
                PyErr_SetString(PyExc_SystemError, "Empty parameter name after $");
                return (i32(-1), fname, custommsg, min, max);
            }
            max = i;
            f = f + 1;
        }
        if is_end_of_format(char_at(f)) {
            PyErr_Format(
                PyExc_SystemError,
                "More keyword list entries (%d) than format specifiers (%d)",
                total,
                i
            );
            return (i32(-1), fname, custommsg, min, max);
        }
        (msg, nf, _count) = skip_format_item(f);
        if msg {
            PyErr_Format(PyExc_SystemError, "%s: '%s'", msg, f);
            return (i32(-1), fname, custommsg, min, max);
        }
        f = nf;
        i += 1;
    }
    min = min_i32(min, total);
    max = min_i32(max, total);
    if not is_end_of_format(char_at(f))
        and char_at(f) != CH_BAR
        and char_at(f) != CH_DOLLAR {
        PyErr_Format(
            PyExc_SystemError,
            "more argument specifiers than keyword list entries (remaining format:'%s')",
            f
        );
        return (i32(-1), fname, custommsg, min, max);
    }
    return (i32(0), fname, custommsg, min, max);
}

impl static_parsers_slot -> ptr[ptr[_PyArg_Parser]] {
    return ptr[ptr[_PyArg_Parser]](
        int(addressof(_PyRuntime)) + _PyRuntimeState_GETARGS_STATIC_PARSERS
    );
}

impl parser_once_flag(parser: ptr[_PyArg_Parser]) -> ptr[u8] {
    return ptr[u8](parser) + _PyArg_Parser_ONCE;
}

impl _parser_init(arg: ptr) -> i32 {
    parser = ptr[_PyArg_Parser](arg);
    keywords = parser.view(1)[0].keywords;
    (rc, len, pos) = scan_keywords(keywords);
    if rc < 0 {
        return -1;
    }
    fname = ptr[u8]();
    custommsg = ptr[u8]();
    min: i32 = 0;
    max: i32 = 0;
    if parser.view(1)[0].format {
        (rc, fname, custommsg, min, max) = parse_format(
            parser.view(1)[0].format, len, pos
        );
        if rc < 0 {
            return -1;
        }
    } else {
        fname = parser.view(1)[0].fname;
    }
    owned: i32 = 0;
    kwtuple = parser.view(1)[0].kwtuple;
    if not kwtuple {
        save_tstate = ptr[PyThreadState]();
        temp_tstate = ptr[PyThreadState]();
        if int(PyInterpreterState_Get()) != int(_PyInterpreterState_Main()) {
            temp_tstate = PyThreadState_New(_PyInterpreterState_Main());
            if not temp_tstate {
                return -1;
            }
            save_tstate = PyThreadState_Swap(temp_tstate);
        }
        kwtuple = new_kwtuple(keywords, len, pos);
        if temp_tstate {
            PyThreadState_Clear(temp_tstate);
            PyThreadState_Swap(save_tstate);
            PyThreadState_Delete(temp_tstate);
        }
        if not kwtuple {
            return -1;
        }
        owned = 1;
    }
    parser.view(1)[0].pos = pos;
    parser.view(1)[0].fname = fname;
    parser.view(1)[0].custom_msg = custommsg;
    parser.view(1)[0].min = min;
    parser.view(1)[0].max = max;
    parser.view(1)[0].kwtuple = kwtuple;
    parser.view(1)[0].is_kwtuple_owned = owned;
    head = int(static_parsers_slot());
    expected = __atomic_load_i64(head, 5);
    while True {
        parser.view(1)[0].next = ptr[_PyArg_Parser](expected);
        seen = __atomic_cas_i64(head, expected, i64(int(parser)), 5);
        if seen == expected {
            break;
        }
        expected = seen;
    }
    return 0;
}

impl parser_init(parser: ptr[_PyArg_Parser]) -> i32 {
    flag = parser_once_flag(parser);
    if u8.wrap(__atomic_load_i8(int(flag), 5)) == _Py_ONCE_INITIALIZED {
        return 0;
    }
    return _PyOnceFlag_CallOnceSlow(flag, ptr(_parser_init), ptr(parser));
}

impl parser_clear(parser: ptr[_PyArg_Parser]) {
    if parser.view(1)[0].is_kwtuple_owned != 0 {
        old = parser.view(1)[0].kwtuple;
        parser.view(1)[0].kwtuple = NULL;
        object_xdecref(old);
    }
    if parser.view(1)[0].format {
        parser.view(1)[0].fname = ptr[u8]();
    }
    parser.view(1)[0].custom_msg = ptr[u8]();
    parser.view(1)[0].pos = 0;
    parser.view(1)[0].min = 0;
    parser.view(1)[0].max = 0;
    parser.view(1)[0].is_kwtuple_owned = 0;
    parser_once_flag(parser).view(1)[0] = 0;
}

impl find_keyword(
    kwnames: ptr[PyObject], kwstack: ptr[ptr[PyObject]], key: ptr[PyObject]
) -> ptr[PyObject] {
    nkwargs = object_size(kwnames);
    names = tuple_items(kwnames);
    for i in range(nkwargs) {
        if (names + i).view(1)[0] == key {
            return object_new_ref((kwstack + i).view(1)[0]);
        }
    }
    for i in range(nkwargs) {
        if _PyUnicode_Equal((names + i).view(1)[0], key) != 0 {
            return object_new_ref((kwstack + i).view(1)[0]);
        }
    }
    return NULL;
}

impl vgetargskeywordsfast_impl(
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwargs: ptr[PyObject],
    kwnames: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    va: VaList,
    flags: i32
) -> i32 {
    if not parser {
        PyErr_BadInternalCall();
        return 0;
    }
    if kwnames and not tuple_check(kwnames) {
        PyErr_BadInternalCall();
        return 0;
    }
    if parser_init(parser) < 0 {
        return 0;
    }
    frame: own ParseFrame = ParseFrame();
    freelist = frame_freelist(jacpy_stack_address(&mut frame));
    freelist_init(freelist);
    levels = frame_levels(freelist);
    msgbuf = frame_msgbuf(freelist);
    kwtuple = parser.view(1)[0].kwtuple;
    pos = parser.view(1)[0].pos;
    len = pos + i32.wrap(object_size(kwtuple));
    fname = parser.view(1)[0].fname;
    if not freelist_reserve(freelist, len) {
        return 0;
    }
    kwstack = ptr[ptr[PyObject]]();
    nkwargs: i64 = 0;
    if kwargs {
        nkwargs = dict_size(kwargs);
    } elif kwnames {
        nkwargs = object_size(kwnames);
        kwstack = args + nargs;
    }
    if nargs + nkwargs > i64(len) {
        PyErr_Format(
            PyExc_TypeError,
            "%.200s%s takes at most %d %sargument%s (%zd given)",
            fname_or_function(fname),
            fname_parens(fname),
            len,
            ptr[u8]("keyword ") if nargs == 0 else ptr[u8](""),
            plural(i64(len)),
            nargs + nkwargs
        );
        return cleanreturn(0, freelist);
    }
    pmin = parser.view(1)[0].min;
    pmax = parser.view(1)[0].max;
    if i64(pmax) < nargs {
        if pmax == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes no positional arguments",
                fname_or_function(fname),
                fname_parens(fname)
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes %s %d positional argument%s (%zd given)",
                fname_or_function(fname),
                fname_parens(fname),
                ptr[u8]("at most") if pmin < pmax else ptr[u8]("exactly"),
                pmax,
                plural(i64(pmax)),
                nargs
            );
        }
        return cleanreturn(0, freelist);
    }
    f = parser.view(1)[0].format;

    i: i64 = 0;
    while i < i64(len) {
        if char_at(f) == CH_BAR {
            f = f + 1;
        }
        if char_at(f) == CH_DOLLAR {
            f = f + 1;
        }
        current_arg = NULL;
        if i < nargs {
            current_arg = object_new_ref((args + i).view(1)[0]);
        } elif nkwargs != 0 and i >= i64(pos) {
            keyword = tuple_get_item(kwtuple, i - i64(pos));
            if kwargs {
                if PyDict_GetItemRef(kwargs, keyword, &mut current_arg) < 0 {
                    return cleanreturn(0, freelist);
                }
            } else {
                current_arg = find_keyword(kwnames, kwstack, keyword);
            }
            if current_arg {
                nkwargs -= 1;
            }
        }
        if current_arg {
            (msg, f, va) = convertitem(
                current_arg, f, va, flags, levels, msgbuf, 512, freelist
            );
            object_decref(current_arg);
            if msg {
                seterror(i + 1, msg, levels, fname, parser.view(1)[0].custom_msg);
                return cleanreturn(0, freelist);
            }
            i += 1;
            continue;
        }
        if i < i64(pmin) {
            if i < i64(pos) {
                least = min_i32(pos, pmin);
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s takes %s %d positional argument%s (%zd given)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    ptr[u8]("at least") if least < pmax else ptr[u8]("exactly"),
                    least,
                    plural(i64(least)),
                    nargs
                );
            } else {
                keyword = tuple_get_item(kwtuple, i - i64(pos));
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s missing required argument '%U' (pos %zd)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    keyword,
                    i + 1
                );
            }
            return cleanreturn(0, freelist);
        }

        if nkwargs == 0 {
            return cleanreturn(1, freelist);
        }

        (_msg, nf, count) = skip_format_item(f);
        f = nf;
        for skipped in range(count) {
            va.arg(ptr);
        }
        i += 1;
    }
    if nkwargs > 0 {
        k = i64(pos);
        while k < nargs {
            current_arg = NULL;
            keyword = tuple_get_item(kwtuple, k - i64(pos));
            if kwargs {
                if PyDict_GetItemRef(kwargs, keyword, &mut current_arg) < 0 {
                    return cleanreturn(0, freelist);
                }
            } else {
                current_arg = find_keyword(kwnames, kwstack, keyword);
            }
            if current_arg {
                object_decref(current_arg);

                PyErr_Format(
                    PyExc_TypeError,
                    "argument for %.200s%s given by name ('%U') and position (%zd)",
                    fname_or_function(fname),
                    fname_parens(fname),
                    keyword,
                    k + 1
                );
                return cleanreturn(0, freelist);
            }
            k += 1;
        }
        error_unexpected_keyword_arg(kwargs, kwnames, kwtuple, fname);
        return cleanreturn(0, freelist);
    }
    return cleanreturn(1, freelist);
}

impl vgetargskeywordsfast(
    args: ptr[PyObject],
    keywords: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    va: VaList,
    flags: i32
) -> i32 {
    if not args or not tuple_check(args) or (keywords and not dict_check(keywords)) {
        PyErr_BadInternalCall();
        return 0;
    }
    return vgetargskeywordsfast_impl(
        tuple_items(args), object_size(args), keywords, NULL, parser, va, flags
    );
}

impl unpack_stack(
    args: ptr[ptr[PyObject]], nargs: i64, name: ptr[u8], min: i64, max: i64, va: VaList
) -> i32 {
    if _PyArg_CheckPositional(name, nargs, min, max) == 0 {
        return 0;
    }
    for i in range(nargs) {
        o = va.arg(ptr[ptr[PyObject]]);
        o.view(1)[0] = (args + i).view(1)[0];
    }
    return 1;
}
