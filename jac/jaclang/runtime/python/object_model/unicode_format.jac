import from c {
    def snprintf(buffer: ptr[u8], size: u64, format: ptr[u8], *args: any) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def strchr(text: ptr[u8], ch: i32) -> ptr[u8];  def memmove(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def wcslen(text: ptr[i32]) -> u64;
}

glob:priv MAX_UNICODE: Final[i64] = 0x10ffff,
     MAX_INTMAX_CHARS: Final[i64] = 26,
     F_LJUST: Final[i32] = 1,
     F_ALT: Final[i32] = 8,
     F_ZERO: Final[i32] = 16,
     F_LONG: Final[i32] = 1,
     F_LONGLONG: Final[i32] = 2,
     F_SIZE: Final[i32] = 3,
     F_PTRDIFF: Final[i32] = 4,
     F_INTMAX: Final[i32] = 5,
     CH_NUL: Final[u8] = u8(0),
     CH_PERCENT: Final[u8] = u8(37),
     CH_STAR: Final[u8] = u8(42),
     CH_MINUS: Final[u8] = u8(45),
     CH_DOT: Final[u8] = u8(46),
     CH_ZERO: Final[u8] = u8(48),
     CH_NINE: Final[u8] = u8(57),
     CH_HASH: Final[u8] = u8(35),
     CH_UPPER_A: Final[u8] = u8(65),
     CH_UPPER_N: Final[u8] = u8(78),
     CH_UPPER_R: Final[u8] = u8(82),
     CH_UPPER_S: Final[u8] = u8(83),
     CH_UPPER_T: Final[u8] = u8(84),
     CH_UPPER_U: Final[u8] = u8(85),
     CH_UPPER_V: Final[u8] = u8(86),
     CH_UPPER_X: Final[u8] = u8(88),
     CH_LOWER_C: Final[u8] = u8(99),
     CH_LOWER_D: Final[u8] = u8(100),
     CH_LOWER_I: Final[u8] = u8(105),
     CH_LOWER_J: Final[u8] = u8(106),
     CH_LOWER_L: Final[u8] = u8(108),
     CH_LOWER_O: Final[u8] = u8(111),
     CH_LOWER_P: Final[u8] = u8(112),
     CH_LOWER_S: Final[u8] = u8(115),
     CH_LOWER_T: Final[u8] = u8(116),
     CH_LOWER_U: Final[u8] = u8(117),
     CH_LOWER_X: Final[u8] = u8(120),
     CH_LOWER_Z: Final[u8] = u8(122),
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF;

def at(p: ptr[u8], i: i64) -> u8;

def is_digit(c: u8) -> bool;

def writer_fill(writer: ptr[UnicodeWriter], count: i64, fill: u32) -> i32;

def fromformat_write_str(
    writer: ptr[UnicodeWriter],
    text: ptr[PyObject],
    width: i64,
    precision: i64,
    flags: i32
) -> i32;

def fromformat_write_utf8(
    writer: ptr[UnicodeWriter], text: ptr[u8], width: i64, precision: i64, flags: i32
) -> i32;

def fromformat_write_wcstr(
    writer: ptr[UnicodeWriter], text: ptr[i32], width: i64, precision: i64, flags: i32
) -> i32;

def write_object_text(
    writer: ptr[UnicodeWriter],
    text: ptr[PyObject],
    width: i64,
    precision: i64,
    flags: i32
) -> bool;

def type_name_of(type: ptr[PyTypeObject], flags: i32) -> ptr[PyObject];

def print_integer(
    buffer: ptr[u8], conversion: u8, sizemod: i32, args: VaList
) -> tuple[i64, VaList];

def fromformat_invalid(p: ptr[u8]) -> ptr[u8];

def fromformat_arg(
    writer: ptr[UnicodeWriter], format: ptr[u8], args: VaList
) -> tuple[ptr[u8], VaList];

def unicode_from_format(
    writer: ptr[UnicodeWriter], format: ptr[u8], vargs: VaList
) -> i32;

def from_format_object(format: ptr[u8], vargs: VaList) -> ptr[PyObject];

import from c {
    def PyUnicode_FromFormatV(format: ptr[u8], vargs: VaList) -> ptr[PyObject] {
        return from_format_object(format, vargs);
    }  def PyUnicode_FromFormat(format: ptr[u8], *vargs: VaList) -> ptr[PyObject] {
        return from_format_object(format, vargs);
    }  def PyUnicodeWriter_Format(
        writer: ptr[PyUnicodeWriter], format: ptr[u8], *vargs: VaList
    ) -> i32 {
        target = ptr[UnicodeWriter](writer);
        old_pos = target.view(1)[0].pos;
        res = unicode_from_format(target, format, vargs);
        if res < i32(0) {
            target.view(1)[0].pos = old_pos;
        }
        return res;
    }
}

impl at(p: ptr[u8], i: i64) -> u8 {
    return (p + i).view(1)[0];
}

impl is_digit(c: u8) -> bool {
    return c >= CH_ZERO and c <= CH_NINE;
}

impl writer_fill(writer: ptr[UnicodeWriter], count: i64, fill: u32) -> i32 {
    if PyUnicode_Fill(writer.view(1)[0].buffer, writer.view(1)[0].pos, count, fill)
        == -1 {
        return i32(-1);
    }
    writer.view(1)[0].pos = writer.view(1)[0].pos + count;
    return i32(0);
}

impl fromformat_write_str(
    writer: ptr[UnicodeWriter],
    text: ptr[PyObject],
    width: i64,
    precision: i64,
    flags: i32
) -> i32 {
    length = uo_length(text);
    if (precision == -1 or precision >= length) and width <= length {
        return _PyUnicodeWriter_WriteStr(writer, text);
    }
    if precision != -1 and precision < length {
        length = precision;
    }
    arglen = length if length > width else width;
    maxchar = writer.view(1)[0].maxchar;
    if uo_max_char_value(text) > maxchar {
        maxchar = _PyUnicode_FindMaxChar(text, 0, length);
    }
    if writer_prepare(writer, arglen, maxchar) == i32(-1) {
        return i32(-1);
    }
    fill = width - length;
    if fill < 0 {
        fill = 0;
    }
    if fill != 0 and (flags & F_LJUST) == i32(0) {
        if writer_fill(writer, fill, u32(32)) < i32(0) {
            return i32(-1);
        }
    }
    _PyUnicode_FastCopyCharacters(
        writer.view(1)[0].buffer, writer.view(1)[0].pos, text, 0, length
    );
    writer.view(1)[0].pos = writer.view(1)[0].pos + length;
    if fill != 0 and (flags & F_LJUST) != i32(0) {
        if writer_fill(writer, fill, u32(32)) < i32(0) {
            return i32(-1);
        }
    }
    return i32(0);
}

impl fromformat_write_utf8(
    writer: ptr[UnicodeWriter], text: ptr[u8], width: i64, precision: i64, flags: i32
) -> i32 {
    consumed = ptr[i64]();
    length_slot = ptr[i64](__alloca(8));
    length: i64 = 0;
    if precision == -1 {
        length = i64(strlen(text));
    } else {
        while length < precision and at(text, length) != CH_NUL {
            length += 1;
        }
        if length == precision {
            consumed = length_slot;
        }
    }
    length_slot.view(1)[0] = length;
    if width < 0 {
        return PyUnicodeWriter_DecodeUTF8Stateful(
            ptr[PyUnicodeWriter](writer), text, length, ptr[u8]("replace"), consumed
        );
    }
    unicode = NULL;
    if consumed {
        consumed_length: i64 = length;
        unicode = PyUnicode_DecodeUTF8Stateful(
            text, length, ptr[u8]("replace"), &mut consumed_length
        );
    } else {
        unicode = PyUnicode_DecodeUTF8Stateful(text, length, ptr[u8]("replace"), None);
    }
    if not unicode {
        return i32(-1);
    }
    res = fromformat_write_str(writer, unicode, width, -1, flags);
    object_decref(unicode);
    return res;
}

impl fromformat_write_wcstr(
    writer: ptr[UnicodeWriter], text: ptr[i32], width: i64, precision: i64, flags: i32
) -> i32 {
    length: i64 = 0;
    if precision == -1 {
        length = i64(wcslen(text));
    } else {
        while length < precision and (text + length).view(1)[0] != i32(0) {
            length += 1;
        }
    }
    if width < 0 {
        return PyUnicodeWriter_WriteWideChar(
            ptr[PyUnicodeWriter](writer), text, length
        );
    }
    unicode = PyUnicode_FromWideChar(text, length);
    if not unicode {
        return i32(-1);
    }
    res = fromformat_write_str(writer, unicode, width, -1, flags);
    object_decref(unicode);
    return res;
}

impl write_object_text(
    writer: ptr[UnicodeWriter],
    text: ptr[PyObject],
    width: i64,
    precision: i64,
    flags: i32
) -> bool {
    if not text {
        return False;
    }
    failed = fromformat_write_str(writer, text, width, precision, flags) == i32(-1);
    object_decref(text);
    return not failed;
}

impl type_name_of(type: ptr[PyTypeObject], flags: i32) -> ptr[PyObject] {
    if (flags & F_ALT) != i32(0) {
        return _PyType_GetFullyQualifiedName(type, i8(58));
    }
    return PyType_GetFullyQualifiedName(type);
}

impl print_integer(
    buffer: ptr[u8], conversion: u8, sizemod: i32, args: VaList
) -> tuple[i64, VaList] {
    size = u64(MAX_INTMAX_CHARS);
    written: i32 = 0;
    if sizemod == i32(0) {
        if conversion == CH_LOWER_O {
            written = snprintf(buffer, size, ptr[u8]("%o"), args.arg(u32));
        } elif conversion == CH_LOWER_U {
            written = snprintf(buffer, size, ptr[u8]("%u"), args.arg(u32));
        } elif conversion == CH_LOWER_X {
            written = snprintf(buffer, size, ptr[u8]("%x"), args.arg(u32));
        } elif conversion == CH_UPPER_X {
            written = snprintf(buffer, size, ptr[u8]("%X"), args.arg(u32));
        } else {
            written = snprintf(buffer, size, ptr[u8]("%d"), args.arg(i32));
        }
    } elif conversion == CH_LOWER_O {
        written = snprintf(buffer, size, ptr[u8]("%llo"), args.arg(u64));
    } elif conversion == CH_LOWER_U {
        written = snprintf(buffer, size, ptr[u8]("%llu"), args.arg(u64));
    } elif conversion == CH_LOWER_X {
        written = snprintf(buffer, size, ptr[u8]("%llx"), args.arg(u64));
    } elif conversion == CH_UPPER_X {
        written = snprintf(buffer, size, ptr[u8]("%llX"), args.arg(u64));
    } else {
        written = snprintf(buffer, size, ptr[u8]("%lld"), args.arg(i64));
    }
    return (i64(written), args);
}

impl fromformat_invalid(p: ptr[u8]) -> ptr[u8] {
    PyErr_Format(PyExc_SystemError, ptr[u8]("invalid format string: %s"), p);
    return ptr[u8]();
}

impl fromformat_arg(
    writer: ptr[UnicodeWriter], format: ptr[u8], args: VaList
) -> tuple[ptr[u8], VaList] {
    p = format;
    f = format + 1;
    if at(f, 0) == CH_PERCENT {
        if _PyUnicodeWriter_WriteChar(writer, u32(37)) < i32(0) {
            return (ptr[u8](), args);
        }
        return (f + 1, args);
    }
    flags: i32 = 0;
    while True {
        c = at(f, 0);
        if c == CH_MINUS {
            flags = flags | F_LJUST;
        } elif c == CH_ZERO {
            flags = flags | F_ZERO;
        } elif c == CH_HASH {
            flags = flags | F_ALT;
        } else {
            break;
        }
        f = f + 1;
    }
    width: i64 = -1;
    if at(f, 0) == CH_STAR {
        width = i64(args.arg(i32));
        if width < 0 {
            flags = flags | F_LJUST;
            width = -width;
        }
        f = f + 1;
    } elif is_digit(at(f, 0)) {
        width = i64(at(f, 0) - CH_ZERO);
        f = f + 1;
        while is_digit(at(f, 0)) {
            digit = i64(at(f, 0) - CH_ZERO);
            if width > (PY_SSIZE_T_MAX - digit) // 10 {
                PyErr_SetString(PyExc_ValueError, ptr[u8]("width too big"));
                return (ptr[u8](), args);
            }
            width = width * 10 + digit;
            f = f + 1;
        }
    }
    precision: i64 = -1;
    if at(f, 0) == CH_DOT {
        f = f + 1;
        if at(f, 0) == CH_STAR {
            precision = i64(args.arg(i32));
            if precision < 0 {
                precision = -2;
            }
            f = f + 1;
        } elif is_digit(at(f, 0)) {
            precision = i64(at(f, 0) - CH_ZERO);
            f = f + 1;
            while is_digit(at(f, 0)) {
                digit = i64(at(f, 0) - CH_ZERO);
                if precision > (PY_SSIZE_T_MAX - digit) // 10 {
                    PyErr_SetString(PyExc_ValueError, ptr[u8]("precision too big"));
                    return (ptr[u8](), args);
                }
                precision = precision * 10 + digit;
                f = f + 1;
            }
        }
    }
    sizemod: i32 = 0;
    if at(f, 0) == CH_LOWER_L {
        if at(f, 1) == CH_LOWER_L {
            sizemod = F_LONGLONG;
            f = f + 2;
        } else {
            sizemod = F_LONG;
            f = f + 1;
        }
    } elif at(f, 0) == CH_LOWER_Z {
        sizemod = F_SIZE;
        f = f + 1;
    } elif at(f, 0) == CH_LOWER_T {
        sizemod = F_PTRDIFF;
        f = f + 1;
    } elif at(f, 0) == CH_LOWER_J {
        sizemod = F_INTMAX;
        f = f + 1;
    }
    if at(f, 0) != CH_NUL and at(f, 1) == CH_NUL {
        writer.view(1)[0].overallocate = u8(0);
    }
    conversion = at(f, 0);
    integer = conversion == CH_LOWER_D
        or conversion == CH_LOWER_I
        or conversion == CH_LOWER_O
        or conversion == CH_LOWER_U
        or conversion == CH_LOWER_X
        or conversion == CH_UPPER_X;
    if not integer {
        if conversion == CH_LOWER_C or conversion == CH_LOWER_P {
            if sizemod != i32(0) or width >= 0 or precision >= 0 {
                return (fromformat_invalid(p), args);
            }
        } elif conversion == CH_LOWER_S or conversion == CH_UPPER_V {
            if sizemod != i32(0) and sizemod != F_LONG {
                return (fromformat_invalid(p), args);
            }
        } elif sizemod != i32(0) {
            return (fromformat_invalid(p), args);
        }
    }
    if conversion == CH_LOWER_C {
        ordinal = args.arg(i32);
        if ordinal < i32(0) or i64(ordinal) > MAX_UNICODE {
            PyErr_SetString(
                PyExc_OverflowError,
                ptr[u8]("character argument not in range(0x110000)")
            );
            return (ptr[u8](), args);
        }
        if _PyUnicodeWriter_WriteChar(writer, u32(ordinal)) < i32(0) {
            return (ptr[u8](), args);
        }
    } elif integer {
        buffer = ptr[u8](__alloca(32));
        (printed, rest) = print_integer(buffer, conversion, sizemod, args);
        args = rest;
        sign: i64 = 1 if at(buffer, 0) == CH_MINUS else 0;
        digits = printed - sign;
        if precision < digits {
            precision = digits;
        }
        if width < precision + sign {
            width = precision + sign;
        }
        if (flags & F_ZERO) != i32(0) and (flags & F_LJUST) == i32(0) {
            precision = width - sign;
        }
        spacepad = width - precision - sign;
        if spacepad < 0 {
            spacepad = 0;
        }
        zeropad = precision - digits;
        if zeropad < 0 {
            zeropad = 0;
        }
        if writer_prepare(writer, width, u32(127)) == i32(-1) {
            return (ptr[u8](), args);
        }
        if spacepad != 0 and (flags & F_LJUST) == i32(0) {
            if writer_fill(writer, spacepad, u32(32)) < i32(0) {
                return (ptr[u8](), args);
            }
        }
        if sign != 0 {
            if _PyUnicodeWriter_WriteChar(writer, u32(45)) == i32(-1) {
                return (ptr[u8](), args);
            }
        }
        if zeropad != 0 {
            if writer_fill(writer, zeropad, u32(48)) < i32(0) {
                return (ptr[u8](), args);
            }
        }
        if _PyUnicodeWriter_WriteASCIIString(writer, buffer + sign, digits) < i32(0) {
            return (ptr[u8](), args);
        }
        if spacepad != 0 and (flags & F_LJUST) != i32(0) {
            if writer_fill(writer, spacepad, u32(32)) < i32(0) {
                return (ptr[u8](), args);
            }
        }
    } elif conversion == CH_LOWER_P {
        number = ptr[u8](__alloca(32));
        shown = i64(
            snprintf(number, u64(MAX_INTMAX_CHARS), ptr[u8]("%p"), args.arg(ptr))
        );
        if at(number, 1) == CH_UPPER_X {
            (number + 1).view(1)[0] = CH_LOWER_X;
        } elif at(number, 1) != CH_LOWER_X {
            memmove(ptr(number + 2), ptr(number), strlen(number) + u64(1));
            number.view(1)[0] = CH_ZERO;
            (number + 1).view(1)[0] = CH_LOWER_X;
            shown += 2;
        }
        if _PyUnicodeWriter_WriteASCIIString(writer, number, shown) < i32(0) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_LOWER_S {
        if sizemod != i32(0) {
            wide = args.arg(ptr[i32]);
            if fromformat_write_wcstr(writer, wide, width, precision, flags) < i32(0) {
                return (ptr[u8](), args);
            }
        } else {
            text = args.arg(ptr[u8]);
            if fromformat_write_utf8(writer, text, width, precision, flags) < i32(0) {
                return (ptr[u8](), args);
            }
        }
    } elif conversion == CH_UPPER_U {
        obj_ = args.arg(ptr[PyObject]);
        if fromformat_write_str(writer, obj_, width, precision, flags) == i32(-1) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_UPPER_V {
        obj_ = args.arg(ptr[PyObject]);
        wide = ptr[i32]();
        text = ptr[u8]();
        if sizemod != i32(0) {
            wide = args.arg(ptr[i32]);
        } else {
            text = args.arg(ptr[u8]);
        }
        if obj_ {
            if fromformat_write_str(writer, obj_, width, precision, flags) == i32(-1) {
                return (ptr[u8](), args);
            }
        } elif sizemod != i32(0) {
            if fromformat_write_wcstr(writer, wide, width, precision, flags) < i32(0) {
                return (ptr[u8](), args);
            }
        } else {
            if fromformat_write_utf8(writer, text, width, precision, flags) < i32(0) {
                return (ptr[u8](), args);
            }
        }
    } elif conversion == CH_UPPER_S {
        obj_ = args.arg(ptr[PyObject]);
        if not write_object_text(writer, PyObject_Str(obj_), width, precision, flags) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_UPPER_R {
        obj_ = args.arg(ptr[PyObject]);
        if not write_object_text(
            writer, PyObject_Repr(obj_), width, precision, flags
        ) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_UPPER_A {
        obj_ = args.arg(ptr[PyObject]);
        if not write_object_text(
            writer, PyObject_ASCII(obj_), width, precision, flags
        ) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_UPPER_T {
        obj_ = args.arg(ptr[PyObject]);
        type = object_type(obj_);
        object_incref(ptr[PyObject](type));
        type_name = type_name_of(type, flags);
        object_decref(ptr[PyObject](type));
        if not write_object_text(writer, type_name, width, precision, flags) {
            return (ptr[u8](), args);
        }
    } elif conversion == CH_UPPER_N {
        type_raw = args.arg(ptr[PyObject]);
        if not type_has_feature(object_type(type_raw), Py_TPFLAGS_TYPE_SUBCLASS) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("%N argument must be a type"));
            return (ptr[u8](), args);
        }
        type_name = type_name_of(ptr[PyTypeObject](type_raw), flags);
        if not write_object_text(writer, type_name, width, precision, flags) {
            return (ptr[u8](), args);
        }
    } else {
        return (fromformat_invalid(p), args);
    }
    return (f + 1, args);
}

impl unicode_from_format(
    writer: ptr[UnicodeWriter], format: ptr[u8], vargs: VaList
) -> i32 {
    total = i64(strlen(format));
    writer.view(1)[0].min_length = writer.view(1)[0].min_length + total + 100;
    writer.view(1)[0].overallocate = u8(1);
    i: i64 = 0;
    while i < total and at(format, i) <= u8(127) {
        i += 1;
    }
    if i < total {
        byte = i32(at(format, i));
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8](
                "PyUnicode_FromFormatV() expects an ASCII-encoded format string, got a non-ASCII byte: 0x%02x"
            ),
            byte
        );
        return i32(-1);
    }
    args = vargs;
    f = format;
    while at(f, 0) != CH_NUL {
        if at(f, 0) == CH_PERCENT {
            (next_f, rest) = fromformat_arg(writer, f, args);
            args = rest;
            if not next_f {
                return i32(-1);
            }
            f = next_f;
        } else {
            found = strchr(f, 37);
            n: i64 = 0;
            if found {
                n = int(found) - int(f);
            } else {
                n = i64(strlen(f));
                writer.view(1)[0].overallocate = u8(0);
            }
            if _PyUnicodeWriter_WriteASCIIString(writer, f, n) < i32(0) {
                return i32(-1);
            }
            f = f + n;
        }
    }
    return i32(0);
}

impl from_format_object(format: ptr[u8], vargs: VaList) -> ptr[PyObject] {
    writer = ptr[UnicodeWriter](__alloca(_PyUnicodeWriter_SIZE));
    _PyUnicodeWriter_Init(writer);
    if unicode_from_format(writer, format, vargs) < i32(0) {
        _PyUnicodeWriter_Dealloc(writer);
        return NULL;
    }
    return _PyUnicodeWriter_Finish(writer);
}
