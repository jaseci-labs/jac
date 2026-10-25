glob:priv LT_NO_LOCALE: i32 = 0,
     LT_DEFAULT_LOCALE: i32 = 44,
     LT_UNDERSCORE_LOCALE: i32 = 95,
     LT_UNDER_FOUR_LOCALE: i32 = 96,
     LT_CURRENT_LOCALE: i32 = 97,
     Py_DTSF_ADD_DOT_0: i32 = 2,
     Py_DTSF_ALT: i32 = 4,
     Py_DTSF_NO_NEG_0: i32 = 8,
     PY_SSIZE_T_MAX: i64 = 9223372036854775807,
     INT_MAX: i64 = 2147483647;

import from c {
    def localeconv -> ptr[lconv];  def strlen(s: ptr[u8]) -> u64;  def copysign(
        x: f64, y: f64
    ) -> f64;  def PyComplex_RealAsDouble(op: ptr[PyObject]) -> f64;  def PyComplex_ImagAsDouble(
        op: ptr[PyObject]
    ) -> f64;  def _PyUnicode_FastFill(
        unicode: ptr[PyObject], start: i64, length: i64, fill_char: u32
    );  def _PyUnicode_FastCopyCharacters(
        to: ptr[PyObject],
        to_start: i64,
        from_obj: ptr[PyObject],
        from_start: i64,
        how_many: i64
    );  def _PyUnicode_FindMaxChar(
        unicode: ptr[PyObject], start: i64, end: i64
    ) -> u32;  def _PyUnicode_FromASCII(buffer: ptr[u8], size: i64) -> ptr[PyObject];  def _PyUnicode_InsertThousandsGrouping(
        writer: ptr[UnicodeWriter],
        n_buffer: i64,
        digits: ptr[PyObject],
        d_pos: i64,
        n_digits: i64,
        min_width: i64,
        grouping: ptr[u8],
        thousands_sep: ptr[PyObject],
        maxchar: &mut u32 | None,
        forward: i32
    ) -> i64;  def _PyUnicodeWriter_WriteStr(
        writer: ptr[UnicodeWriter], str_obj: ptr[PyObject]
    ) -> i32;  def _PyUnicodeWriter_WriteASCIIString(
        writer: ptr[UnicodeWriter], text: ptr[u8], len_in: i64
    ) -> i32;  def _PyLong_FormatWriter(
        writer: ptr[UnicodeWriter], ob: ptr[PyObject], base: i32, alternate: i32
    ) -> i32;  def _PyLong_Format(ob: ptr[PyObject], base: i32) -> ptr[PyObject];  glob:
        priv no_grouping: list[u8] = b"\x7f",
         group_by_three: list[u8] = b"\x03\x00",
         group_by_four: list[u8] = b"\x04\x00";
}

obj InternalFormatSpec {
    has fill_char: u32 = u32(32),
        align: u32 = u32(0),
        alternate: i32 = 0,
        no_neg_0: i32 = 0,
        sign: u32 = u32(0),
        width: i64 = -1,
        thousands_separators: i32 = 0,
        precision: i64 = -1,
        frac_thousands_separator: i32 = 0,
        type_: u32 = u32(0);
}

obj LocaleInfo {
    has decimal_point: ptr[PyObject] = ptr[PyObject](),
        thousands_sep: ptr[PyObject] = ptr[PyObject](),
        frac_thousands_sep: ptr[PyObject] = ptr[PyObject](),
        grouping: ptr[u8] = ptr[u8](),
        grouping_buffer: ptr[u8] = ptr[u8]();
}

obj NumberFieldWidths {
    has n_lpadding: i64 = 0,
        n_prefix: i64 = 0,
        n_spadding: i64 = 0,
        n_rpadding: i64 = 0,
        sign: u32 = u32(0),
        n_sign: i64 = 0,
        n_grouped_digits: i64 = 0,
        n_decimal: i64 = 0,
        n_remainder: i64 = 0,
        n_frac: i64 = 0,
        n_grouped_frac_digits: i64 = 0,
        n_digits: i64 = 0,
        n_min_width: i64 = 0;
}

def unknown_presentation_type(presentation_type: u32, type_name: ptr[u8]);

def invalid_thousands_separator_type(specifier: i32, presentation_type: u32);

def invalid_comma_and_underscore;

def get_integer(
    text: ptr[PyObject], pos_in: i64, end: i64, result_in: i64
) -> tuple[i32, i64, i64];

def is_alignment_token(c: u32) -> bool;

def is_sign_element(c: u32) -> bool;

def is_grouping_float_type(t: u32) -> bool;

def is_radix_type(t: u32) -> bool;

def parse_internal_render_format_spec(
    obj_: ptr[PyObject],
    format_spec: ptr[PyObject],
    start: i64,
    end: i64,
    fmt: InternalFormatSpec,
    default_type: u32,
    default_align: u32
) -> i32;

def calc_padding(nchars: i64, width: i64, align: u32) -> tuple[i64, i64, i64];

def fill_padding(
    writer: ptr[UnicodeWriter],
    nchars: i64,
    fill_char: u32,
    n_lpadding: i64,
    n_rpadding: i64
) -> i32;

def ascii_isdigit(c: u32) -> bool;

def ascii_toupper(c: u32) -> u32;

def parse_number(s: ptr[PyObject], pos_in: i64, end: i64) -> tuple[i64, i64, bool];

def calc_number_widths(
    spec: NumberFieldWidths,
    n_prefix: i64,
    sign_char: u32,
    n_start: i64,
    n_end: i64,
    n_remainder: i64,
    n_frac: i64,
    has_decimal: bool,
    locale: LocaleInfo,
    fmt: InternalFormatSpec,
    maxchar_in: u32
) -> tuple[i64, u32];

def fill_number(
    writer: ptr[UnicodeWriter],
    spec: NumberFieldWidths,
    digits: ptr[PyObject],
    d_start: i64,
    prefix: ptr[PyObject],
    p_start: i64,
    fill_char: u32,
    locale: LocaleInfo,
    toupper: bool
) -> i32;

def get_locale_info(locale_type: i32, frac_type: i32, locale_info: LocaleInfo) -> i32;

def free_locale_info(locale_info: LocaleInfo);

def format_string_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32;

def number_done(tmp: ptr[PyObject], locale: LocaleInfo, result: i32) -> i32;

def format_long_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32;

def format_float_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32;

def copy_format_spec(fmt: InternalFormatSpec) -> InternalFormatSpec;

def complex_done(
    re_buf: ptr[u8],
    im_buf: ptr[u8],
    re_unicode_tmp: ptr[PyObject],
    im_unicode_tmp: ptr[PyObject],
    locale: LocaleInfo,
    result: i32
) -> i32;

def format_complex_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32;

def format_obj(obj_: ptr[PyObject], writer: ptr[UnicodeWriter]) -> i32;

import from c {
    def _PyUnicode_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32 {
        if start == end {
            if unicode_check_exact(obj_) {
                return _PyUnicodeWriter_WriteStr(writer, obj_);
            }
            return format_obj(obj_, writer);
        }

        fmt = InternalFormatSpec();
        if parse_internal_render_format_spec(
            obj_, format_spec, start, end, fmt, u32(115), u32(60)
        )
            == 0 {
            return -1;
        }

        if fmt.type_ == u32(115) {
            return format_string_internal(obj_, fmt, writer);
        }
        unknown_presentation_type(fmt.type_, object_type(obj_).view(1)[0].tp_name);
        return -1;
    }  def _PyLong_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32 {
        if start == end {
            if long_check_exact(obj_) {
                return _PyLong_FormatWriter(writer, obj_, 10, 0);
            }
            return format_obj(obj_, writer);
        }

        fmt = InternalFormatSpec();
        if parse_internal_render_format_spec(
            obj_, format_spec, start, end, fmt, u32(100), u32(62)
        )
            == 0 {
            return -1;
        }

        t = fmt.type_;
        if t == u32(98)
            or t == u32(99)
            or t == u32(100)
            or t == u32(111)
            or t == u32(120)
            or t == u32(88)
            or t == u32(110) {
            return format_long_internal(obj_, fmt, writer);
        }
        if t == u32(101)
            or t == u32(69)
            or t == u32(102)
            or t == u32(70)
            or t == u32(103)
            or t == u32(71)
            or t == u32(37) {
            tmp = PyNumber_Float(obj_);
            if not tmp {
                return -1;
            }
            result = format_float_internal(tmp, fmt, writer);
            object_decref(tmp);
            return result;
        }
        unknown_presentation_type(t, object_type(obj_).view(1)[0].tp_name);
        return -1;
    }  def _PyFloat_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32 {
        if start == end {
            return format_obj(obj_, writer);
        }

        fmt = InternalFormatSpec();
        if parse_internal_render_format_spec(
            obj_, format_spec, start, end, fmt, u32(0), u32(62)
        )
            == 0 {
            return -1;
        }

        t = fmt.type_;
        if t == u32(0)
            or t == u32(101)
            or t == u32(69)
            or t == u32(102)
            or t == u32(70)
            or t == u32(103)
            or t == u32(71)
            or t == u32(110)
            or t == u32(37) {
            return format_float_internal(obj_, fmt, writer);
        }
        unknown_presentation_type(t, object_type(obj_).view(1)[0].tp_name);
        return -1;
    }  def _PyComplex_FormatAdvancedWriter(
        writer: ptr[UnicodeWriter],
        obj_: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32 {
        if start == end {
            return format_obj(obj_, writer);
        }

        fmt = InternalFormatSpec();
        if parse_internal_render_format_spec(
            obj_, format_spec, start, end, fmt, u32(0), u32(62)
        )
            == 0 {
            return -1;
        }

        t = fmt.type_;
        if t == u32(0)
            or t == u32(101)
            or t == u32(69)
            or t == u32(102)
            or t == u32(70)
            or t == u32(103)
            or t == u32(71)
            or t == u32(110) {
            return format_complex_internal(obj_, fmt, writer);
        }
        unknown_presentation_type(t, object_type(obj_).view(1)[0].tp_name);
        return -1;
    }
}

impl unknown_presentation_type(presentation_type: u32, type_name: ptr[u8]) {
    if presentation_type > u32(32) and presentation_type < u32(128) {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Unknown format code '%c' for object of type '%.200s'"),
            i32(presentation_type),
            type_name
        );
    } else {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Unknown format code '\\x%x' for object of type '%.200s'"),
            i32(presentation_type),
            type_name
        );
    }
}

impl invalid_thousands_separator_type(specifier: i32, presentation_type: u32) {
    if presentation_type > u32(32) and presentation_type < u32(128) {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Cannot specify '%c' with '%c'."),
            specifier,
            i32(presentation_type)
        );
    } else {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Cannot specify '%c' with '\\x%x'."),
            specifier,
            i32(presentation_type)
        );
    }
}

impl invalid_comma_and_underscore {
    PyErr_Format(PyExc_ValueError, ptr[u8]("Cannot specify both ',' and '_'."));
}

impl get_integer(
    text: ptr[PyObject], pos_in: i64, end: i64, result_in: i64
) -> tuple[i32, i64, i64] {
    pos = pos_in;
    kind = uo_kind(text);
    data = uo_data(text);
    accumulator: i64 = 0;
    numdigits: i32 = 0;
    while pos < end {
        digitval = i64(_PyUnicode_ToDecimalDigit(ch_read(kind, data, pos)));
        if digitval < 0 {
            break;
        }
        if accumulator > (PY_SSIZE_T_MAX - digitval) // 10 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Too many decimal digits in format string"));
            return (i32(-1), pos, result_in);
        }
        accumulator = accumulator * 10 + digitval;
        pos += 1;
        numdigits += 1;
    }
    return (numdigits, pos, accumulator);
}

impl is_alignment_token(c: u32) -> bool {
    return c == u32(60) or c == u32(62) or c == u32(61) or c == u32(94);
}

impl is_sign_element(c: u32) -> bool {
    return c == u32(32) or c == u32(43) or c == u32(45);
}

impl is_grouping_float_type(t: u32) -> bool {
    return t == u32(100)
        or t == u32(101)
        or t == u32(102)
        or t == u32(103)
        or t == u32(69)
        or t == u32(71)
        or t == u32(37)
        or t == u32(70)
        or t == u32(0);
}

impl is_radix_type(t: u32) -> bool {
    return t == u32(98) or t == u32(111) or t == u32(120) or t == u32(88);
}

impl parse_internal_render_format_spec(
    obj_: ptr[PyObject],
    format_spec: ptr[PyObject],
    start: i64,
    end: i64,
    fmt: InternalFormatSpec,
    default_type: u32,
    default_align: u32
) -> i32 {
    pos = start;
    kind = uo_kind(format_spec);
    data = uo_data(format_spec);
    consumed: i32 = 0;
    align_specified = False;
    fill_char_specified = False;

    fmt.fill_char = u32(32);
    fmt.align = default_align;
    fmt.alternate = 0;
    fmt.no_neg_0 = 0;
    fmt.sign = u32(0);
    fmt.width = -1;
    fmt.thousands_separators = LT_NO_LOCALE;
    fmt.frac_thousands_separator = LT_NO_LOCALE;
    fmt.precision = -1;
    fmt.type_ = default_type;

    if end - pos >= 2 and is_alignment_token(ch_read(kind, data, pos + 1)) {
        fmt.align = ch_read(kind, data, pos + 1);
        fmt.fill_char = ch_read(kind, data, pos);
        fill_char_specified = True;
        align_specified = True;
        pos += 2;
    } elif end - pos >= 1 and is_alignment_token(ch_read(kind, data, pos)) {
        fmt.align = ch_read(kind, data, pos);
        align_specified = True;
        pos += 1;
    }

    if end - pos >= 1 and is_sign_element(ch_read(kind, data, pos)) {
        fmt.sign = ch_read(kind, data, pos);
        pos += 1;
    }

    if end - pos >= 1 and ch_read(kind, data, pos) == u32(122) {
        fmt.no_neg_0 = 1;
        pos += 1;
    }

    if end - pos >= 1 and ch_read(kind, data, pos) == u32(35) {
        fmt.alternate = 1;
        pos += 1;
    }

    if not fill_char_specified
        and end - pos >= 1
        and ch_read(kind, data, pos) == u32(48) {
        fmt.fill_char = u32(48);
        if not align_specified and default_align == u32(62) {
            fmt.align = u32(61);
        }
        pos += 1;
    }

    (consumed, pos, width) = get_integer(format_spec, pos, end, fmt.width);
    fmt.width = width;
    if consumed == -1 {
        return 0;
    }

    if consumed == 0 {
        fmt.width = -1;
    }

    if end - pos != 0 and ch_read(kind, data, pos) == u32(44) {
        fmt.thousands_separators = LT_DEFAULT_LOCALE;
        pos += 1;
    }
    if end - pos != 0 and ch_read(kind, data, pos) == u32(95) {
        if fmt.thousands_separators != LT_NO_LOCALE {
            invalid_comma_and_underscore();
            return 0;
        }
        fmt.thousands_separators = LT_UNDERSCORE_LOCALE;
        pos += 1;
    }
    if end - pos != 0 and ch_read(kind, data, pos) == u32(44) {
        if fmt.thousands_separators == LT_UNDERSCORE_LOCALE {
            invalid_comma_and_underscore();
            return 0;
        }
    }

    if end - pos != 0 and ch_read(kind, data, pos) == u32(46) {
        pos += 1;

        (consumed, pos, precision) = get_integer(format_spec, pos, end, fmt.precision);
        fmt.precision = precision;
        if consumed == -1 {
            return 0;
        }

        if end - pos != 0 and ch_read(kind, data, pos) == u32(44) {
            if consumed == 0 {
                fmt.precision = -1;
            }
            fmt.frac_thousands_separator = LT_DEFAULT_LOCALE;
            pos += 1;
            consumed += 1;
        }
        if end - pos != 0 and ch_read(kind, data, pos) == u32(95) {
            if fmt.frac_thousands_separator != LT_NO_LOCALE {
                invalid_comma_and_underscore();
                return 0;
            }
            if consumed == 0 {
                fmt.precision = -1;
            }
            fmt.frac_thousands_separator = LT_UNDERSCORE_LOCALE;
            pos += 1;
            consumed += 1;
        }
        if end - pos != 0 and ch_read(kind, data, pos) == u32(44) {
            if fmt.frac_thousands_separator == LT_UNDERSCORE_LOCALE {
                invalid_comma_and_underscore();
                return 0;
            }
        }

        if consumed == 0 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Format specifier missing precision"));
            return 0;
        }
    }

    if end - pos > 1 {
        actual_format_spec = PyUnicode_FromKindAndData(
            i32(kind), data + kind * start, end - start
        );
        if actual_format_spec {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("Invalid format specifier '%U' for object of type '%.200s'"),
                actual_format_spec,
                object_type(obj_).view(1)[0].tp_name
            );
            object_decref(actual_format_spec);
        }
        return 0;
    }

    if end - pos == 1 {
        fmt.type_ = ch_read(kind, data, pos);
        pos += 1;
    }

    if fmt.thousands_separators != 0 and not is_grouping_float_type(fmt.type_) {
        if is_radix_type(fmt.type_)
            and fmt.thousands_separators == LT_UNDERSCORE_LOCALE {
            fmt.thousands_separators = LT_UNDER_FOUR_LOCALE;
        } else {
            invalid_thousands_separator_type(fmt.thousands_separators, fmt.type_);
            return 0;
        }
    }

    if fmt.type_ == u32(110) and fmt.frac_thousands_separator != LT_NO_LOCALE {
        invalid_thousands_separator_type(fmt.frac_thousands_separator, fmt.type_);
        return 0;
    }

    return 1;
}

impl calc_padding(nchars: i64, width: i64, align: u32) -> tuple[i64, i64, i64] {
    n_total: i64 = 0;
    n_lpadding: i64 = 0;
    if width >= 0 {
        if nchars > width {
            n_total = nchars;
        } else {
            n_total = width;
        }
    } else {
        n_total = nchars;
    }

    if align == u32(62) {
        n_lpadding = n_total - nchars;
    } elif align == u32(94) {
        n_lpadding = (n_total - nchars) // 2;
    } else {
        n_lpadding = 0;
    }

    return (n_lpadding, n_total - nchars - n_lpadding, n_total);
}

impl fill_padding(
    writer: ptr[UnicodeWriter],
    nchars: i64,
    fill_char: u32,
    n_lpadding: i64,
    n_rpadding: i64
) -> i32 {
    if n_lpadding != 0 {
        pos = writer.view(1)[0].pos;
        _PyUnicode_FastFill(writer.view(1)[0].buffer, pos, n_lpadding, fill_char);
    }

    if n_rpadding != 0 {
        pos = writer.view(1)[0].pos + nchars + n_lpadding;
        _PyUnicode_FastFill(writer.view(1)[0].buffer, pos, n_rpadding, fill_char);
    }

    writer.view(1)[0].pos = writer.view(1)[0].pos + n_lpadding;
    return 0;
}

impl ascii_isdigit(c: u32) -> bool {
    b = c & u32(0xff);
    return b >= u32(48) and b <= u32(57);
}

impl ascii_toupper(c: u32) -> u32 {
    b = c & u32(0xff);
    if b >= u32(97) and b <= u32(122) {
        return b - u32(32);
    }
    return b;
}

impl parse_number(s: ptr[PyObject], pos_in: i64, end: i64) -> tuple[i64, i64, bool] {
    pos = pos_in;
    kind = uo_kind(s);
    data = uo_data(s);

    while pos < end and ascii_isdigit(ch_read(kind, data, pos)) {
        pos += 1;
    }
    frac = pos;

    has_decimal = pos < end and ch_read(kind, data, frac) == u32(46);

    if has_decimal {
        frac += 1;
        pos += 1;
    }

    while pos < end and ascii_isdigit(ch_read(kind, data, pos)) {
        pos += 1;
    }

    return (end - pos, pos - frac, has_decimal);
}

impl calc_number_widths(
    spec: NumberFieldWidths,
    n_prefix: i64,
    sign_char: u32,
    n_start: i64,
    n_end: i64,
    n_remainder: i64,
    n_frac: i64,
    has_decimal: bool,
    locale: LocaleInfo,
    fmt: InternalFormatSpec,
    maxchar_in: u32
) -> tuple[i64, u32] {
    maxchar = maxchar_in;
    decimal_len: i64 = 0;
    if has_decimal {
        decimal_len = 1;
    }
    spec.n_digits = n_end - n_start - n_frac - n_remainder - decimal_len;
    spec.n_lpadding = 0;
    spec.n_prefix = n_prefix;
    if has_decimal {
        spec.n_decimal = uo_length(locale.decimal_point);
    } else {
        spec.n_decimal = 0;
    }
    spec.n_remainder = n_remainder;
    spec.n_frac = n_frac;
    spec.n_spadding = 0;
    spec.n_rpadding = 0;
    spec.sign = u32(0);
    spec.n_sign = 0;

    if fmt.sign == u32(43) {
        spec.n_sign = 1;
        if sign_char == u32(45) {
            spec.sign = u32(45);
        } else {
            spec.sign = u32(43);
        }
    } elif fmt.sign == u32(32) {
        spec.n_sign = 1;
        if sign_char == u32(45) {
            spec.sign = u32(45);
        } else {
            spec.sign = u32(32);
        }
    } elif sign_char == u32(45) {
        spec.n_sign = 1;
        spec.sign = u32(45);
    }

    if spec.n_frac == 0 {
        spec.n_grouped_frac_digits = 0;
    } else {
        frac_maxchar: u32 = 0;
        spec.n_grouped_frac_digits = _PyUnicode_InsertThousandsGrouping(
            ptr[UnicodeWriter](),
            0,
            NULL,
            0,
            spec.n_frac,
            spec.n_frac,
            locale.grouping,
            locale.frac_thousands_sep,
            &mut frac_maxchar,
            1
        );
        if spec.n_grouped_frac_digits == -1 {
            return (-1, maxchar);
        }
        if frac_maxchar > maxchar {
            maxchar = frac_maxchar;
        }
    }

    n_non_digit_non_padding = spec.n_sign
        + spec.n_prefix
        + spec.n_decimal
        + spec.n_frac
        + spec.n_remainder;

    if fmt.fill_char == u32(48) and fmt.align == u32(61) {
        spec.n_min_width = fmt.width - n_non_digit_non_padding + spec.n_frac
            - spec.n_grouped_frac_digits;
    } else {
        spec.n_min_width = 0;
    }

    if spec.n_digits == 0 {
        spec.n_grouped_digits = 0;
    } else {
        grouping_maxchar: u32 = 0;
        spec.n_grouped_digits = _PyUnicode_InsertThousandsGrouping(
            ptr[UnicodeWriter](),
            0,
            NULL,
            0,
            spec.n_digits,
            spec.n_min_width,
            locale.grouping,
            locale.thousands_sep,
            &mut grouping_maxchar,
            0
        );
        if spec.n_grouped_digits == -1 {
            return (-1, maxchar);
        }
        if grouping_maxchar > maxchar {
            maxchar = grouping_maxchar;
        }
    }

    n_padding = fmt.width
        - (
            n_non_digit_non_padding + spec.n_grouped_digits + spec.n_grouped_frac_digits
            - spec.n_frac
        );
    if n_padding > 0 {
        if fmt.align == u32(60) {
            spec.n_rpadding = n_padding;
        } elif fmt.align == u32(94) {
            spec.n_lpadding = n_padding // 2;
            spec.n_rpadding = n_padding - spec.n_lpadding;
        } elif fmt.align == u32(61) {
            spec.n_spadding = n_padding;
        } elif fmt.align == u32(62) {
            spec.n_lpadding = n_padding;
        }
    }

    if spec.n_lpadding != 0 or spec.n_spadding != 0 or spec.n_rpadding != 0 {
        if fmt.fill_char > maxchar {
            maxchar = fmt.fill_char;
        }
    }

    if spec.n_decimal != 0 {
        decimal_maxchar = uo_max_char_value(locale.decimal_point);
        if decimal_maxchar > maxchar {
            maxchar = decimal_maxchar;
        }
    }

    total = spec.n_lpadding
        + spec.n_sign
        + spec.n_prefix
        + spec.n_spadding
        + spec.n_grouped_digits
        + spec.n_decimal
        + spec.n_grouped_frac_digits
        + spec.n_remainder
        + spec.n_rpadding;
    return (total, maxchar);
}

impl fill_number(
    writer: ptr[UnicodeWriter],
    spec: NumberFieldWidths,
    digits: ptr[PyObject],
    d_start: i64,
    prefix: ptr[PyObject],
    p_start: i64,
    fill_char: u32,
    locale: LocaleInfo,
    toupper: bool
) -> i32 {
    d_pos = d_start;
    kind = i64(writer.view(1)[0].kind);
    data = writer.view(1)[0].data;

    if spec.n_lpadding != 0 {
        _PyUnicode_FastFill(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, spec.n_lpadding, fill_char
        );
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_lpadding;
    }
    if spec.n_sign == 1 {
        ch_write(kind, data, writer.view(1)[0].pos, spec.sign);
        writer.view(1)[0].pos = writer.view(1)[0].pos + 1;
    }
    if spec.n_prefix != 0 {
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer,
            writer.view(1)[0].pos,
            prefix,
            p_start,
            spec.n_prefix
        );
        if toupper {
            for t in range(spec.n_prefix) {
                c = ch_read(kind, data, writer.view(1)[0].pos + t);
                c = ascii_toupper(c);
                ch_write(kind, data, writer.view(1)[0].pos + t, c);
            }
        }
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_prefix;
    }
    if spec.n_spadding != 0 {
        _PyUnicode_FastFill(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, spec.n_spadding, fill_char
        );
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_spadding;
    }

    if spec.n_digits != 0 {
        r = _PyUnicode_InsertThousandsGrouping(
            writer,
            spec.n_grouped_digits,
            digits,
            d_pos,
            spec.n_digits,
            spec.n_min_width,
            locale.grouping,
            locale.thousands_sep,
            None,
            0
        );
        if r == -1 {
            return -1;
        }
        d_pos += spec.n_digits;
    }
    if toupper {
        for t in range(spec.n_grouped_digits) {
            c = ch_read(kind, data, writer.view(1)[0].pos + t);
            c = ascii_toupper(c);
            if c > u32(127) {
                PyErr_SetString(PyExc_SystemError, ptr[u8]("non-ascii grouped digit"));
                return -1;
            }
            ch_write(kind, data, writer.view(1)[0].pos + t, c);
        }
    }
    writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_grouped_digits;

    if spec.n_decimal != 0 {
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer,
            writer.view(1)[0].pos,
            locale.decimal_point,
            0,
            spec.n_decimal
        );
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_decimal;
        d_pos += 1;
    }

    if spec.n_frac != 0 {
        r = _PyUnicode_InsertThousandsGrouping(
            writer,
            spec.n_grouped_frac_digits,
            digits,
            d_pos,
            spec.n_frac,
            spec.n_frac,
            locale.grouping,
            locale.frac_thousands_sep,
            None,
            1
        );
        if r == -1 {
            return -1;
        }
        d_pos += spec.n_frac;
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_grouped_frac_digits;
    }

    if spec.n_remainder != 0 {
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer,
            writer.view(1)[0].pos,
            digits,
            d_pos,
            spec.n_remainder
        );
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_remainder;
    }

    if spec.n_rpadding != 0 {
        _PyUnicode_FastFill(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, spec.n_rpadding, fill_char
        );
        writer.view(1)[0].pos = writer.view(1)[0].pos + spec.n_rpadding;
    }
    return 0;
}

impl get_locale_info(locale_type: i32, frac_type: i32, locale_info: LocaleInfo) -> i32 {
    if locale_type == LT_CURRENT_LOCALE {
        lc = localeconv();
        decimal_point: ptr[PyObject] = NULL;
        thousands_sep: ptr[PyObject] = NULL;
        rc = _Py_GetLocaleconvNumeric(lc, &mut decimal_point, &mut thousands_sep);
        locale_info.decimal_point = decimal_point;
        locale_info.thousands_sep = thousands_sep;
        if rc < 0 {
            return -1;
        }

        locale_info.grouping_buffer = _PyMem_Strdup(lc.view(1)[0].grouping);
        if not locale_info.grouping_buffer {
            PyErr_NoMemory();
            return -1;
        }
        locale_info.grouping = locale_info.grouping_buffer;
    } elif locale_type == LT_DEFAULT_LOCALE
        or locale_type == LT_UNDERSCORE_LOCALE
        or locale_type == LT_UNDER_FOUR_LOCALE {
        locale_info.decimal_point = PyUnicode_FromOrdinal(46);
        if locale_type == LT_DEFAULT_LOCALE {
            locale_info.thousands_sep = PyUnicode_FromOrdinal(44);
        } else {
            locale_info.thousands_sep = PyUnicode_FromOrdinal(95);
        }
        if not locale_info.decimal_point or not locale_info.thousands_sep {
            return -1;
        }
        if locale_type != LT_UNDER_FOUR_LOCALE {
            locale_info.grouping = addressof(group_by_three);
        } else {
            locale_info.grouping = addressof(group_by_four);
        }
    } elif locale_type == LT_NO_LOCALE {
        locale_info.decimal_point = PyUnicode_FromOrdinal(46);
        locale_info.thousands_sep = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
        if not locale_info.decimal_point or not locale_info.thousands_sep {
            return -1;
        }
        locale_info.grouping = addressof(no_grouping);
    }
    if frac_type != LT_NO_LOCALE {
        if frac_type == LT_DEFAULT_LOCALE {
            locale_info.frac_thousands_sep = PyUnicode_FromOrdinal(44);
        } else {
            locale_info.frac_thousands_sep = PyUnicode_FromOrdinal(95);
        }
        if not locale_info.frac_thousands_sep {
            return -1;
        }
        if int(locale_info.grouping) == int(addressof(no_grouping)) {
            locale_info.grouping = addressof(group_by_three);
        }
    } else {
        locale_info.frac_thousands_sep = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    return 0;
}

impl free_locale_info(locale_info: LocaleInfo) {
    object_xdecref(locale_info.decimal_point);
    object_xdecref(locale_info.thousands_sep);
    object_xdecref(locale_info.frac_thousands_sep);
    PyMem_Free(locale_info.grouping_buffer);
}

impl format_string_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32 {
    length = uo_length(value);

    if fmt.sign != u32(0) {
        if fmt.sign == u32(32) {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Space not allowed in string format specifier")
            );
        } else {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Sign not allowed in string format specifier")
            );
        }
        return -1;
    }

    if fmt.no_neg_0 != 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("Negative zero coercion (z) not allowed in string format specifier")
        );
        return -1;
    }

    if fmt.alternate != 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("Alternate form (#) not allowed in string format specifier")
        );
        return -1;
    }

    if fmt.align == u32(61) {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("'=' alignment not allowed in string format specifier")
        );
        return -1;
    }

    if (fmt.width == -1 or fmt.width <= length)
        and (fmt.precision == -1 or fmt.precision >= length) {
        return _PyUnicodeWriter_WriteStr(writer, value);
    }

    if fmt.precision >= 0 and length >= fmt.precision {
        length = fmt.precision;
    }

    (lpad, rpad, total) = calc_padding(length, fmt.width, fmt.align);

    maxchar = writer.view(1)[0].maxchar;
    if lpad != 0 or rpad != 0 {
        if fmt.fill_char > maxchar {
            maxchar = fmt.fill_char;
        }
    }
    if uo_max_char_value(value) > maxchar {
        valmaxchar = _PyUnicode_FindMaxChar(value, 0, length);
        if valmaxchar > maxchar {
            maxchar = valmaxchar;
        }
    }

    if writer_prepare(writer, total, maxchar) == -1 {
        return -1;
    }

    result = fill_padding(writer, length, fmt.fill_char, lpad, rpad);
    if result == -1 {
        return -1;
    }

    if length != 0 {
        _PyUnicode_FastCopyCharacters(
            writer.view(1)[0].buffer, writer.view(1)[0].pos, value, 0, length
        );
    }
    writer.view(1)[0].pos = writer.view(1)[0].pos + (length + rpad);
    return 0;
}

impl number_done(tmp: ptr[PyObject], locale: LocaleInfo, result: i32) -> i32 {
    object_xdecref(tmp);
    free_locale_info(locale);
    return result;
}

impl format_long_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32 {
    maxchar: u32 = u32(127);
    tmp: ptr[PyObject] = NULL;
    inumeric_chars: i64 = 0;
    sign_char: u32 = u32(0);
    n_digits: i64 = 0;
    n_remainder: i64 = 0;
    n_prefix: i64 = 0;
    prefix: i64 = 0;
    spec = NumberFieldWidths();
    locale = LocaleInfo();

    if fmt.precision != -1 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("Precision not allowed in integer format specifier")
        );
        return number_done(tmp, locale, -1);
    }
    if fmt.no_neg_0 != 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("Negative zero coercion (z) not allowed in integer format specifier")
        );
        return number_done(tmp, locale, -1);
    }

    if fmt.type_ == u32(99) {
        if fmt.sign != u32(0) {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Sign not allowed with integer format specifier 'c'")
            );
            return number_done(tmp, locale, -1);
        }
        if fmt.alternate != 0 {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("Alternate form (#) not allowed with integer format specifier 'c'")
            );
            return number_done(tmp, locale, -1);
        }

        x = PyLong_AsLong(value);
        if x == -1 and PyErr_Occurred() {
            return number_done(tmp, locale, -1);
        }
        if x < 0 or x > 0x10ffff {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("%c arg not in range(0x110000)"));
            return number_done(tmp, locale, -1);
        }
        tmp = PyUnicode_FromOrdinal(i32(x));
        inumeric_chars = 0;
        n_digits = 1;
        if u32(x) > maxchar {
            maxchar = u32(x);
        }

        n_remainder = 1;
    } else {
        base: i32 = 10;
        leading_chars_to_skip: i64 = 0;
        if fmt.type_ == u32(98) {
            base = 2;
            leading_chars_to_skip = 2;
        } elif fmt.type_ == u32(111) {
            base = 8;
            leading_chars_to_skip = 2;
        } elif fmt.type_ == u32(120) or fmt.type_ == u32(88) {
            base = 16;
            leading_chars_to_skip = 2;
        } else {
            base = 10;
        }
        if fmt.sign != u32(43)
            and fmt.sign != u32(32)
            and fmt.width == -1
            and fmt.type_ != u32(88)
            and fmt.type_ != u32(110)
            and fmt.thousands_separators == 0
            and long_check_exact(value) {
            return _PyLong_FormatWriter(writer, value, base, fmt.alternate);
        }
        if fmt.alternate != 0 {
            n_prefix = leading_chars_to_skip;
        }
        tmp = _PyLong_Format(value, base);
        if not tmp {
            return number_done(tmp, locale, -1);
        }
        inumeric_chars = 0;
        n_digits = uo_length(tmp);
        prefix = inumeric_chars;
        if uo_read_char(tmp, inumeric_chars) == u32(45) {
            sign_char = u32(45);
            prefix += 1;
            leading_chars_to_skip += 1;
        }
        n_digits -= leading_chars_to_skip;
        inumeric_chars += leading_chars_to_skip;
    }

    locale_type = fmt.thousands_separators;
    if fmt.type_ == u32(110) {
        locale_type = LT_CURRENT_LOCALE;
    }
    if get_locale_info(locale_type, 0, locale) == -1 {
        return number_done(tmp, locale, -1);
    }

    (n_total, maxchar) = calc_number_widths(
        spec,
        n_prefix,
        sign_char,
        inumeric_chars,
        inumeric_chars + n_digits,
        n_remainder,
        0,
        False,
        locale,
        fmt,
        maxchar
    );
    if n_total == -1 {
        return number_done(tmp, locale, -1);
    }

    if writer_prepare(writer, n_total, maxchar) == -1 {
        return number_done(tmp, locale, -1);
    }

    result = fill_number(
        writer,
        spec,
        tmp,
        inumeric_chars,
        tmp,
        prefix,
        fmt.fill_char,
        locale,
        fmt.type_ == u32(88)
    );
    return number_done(tmp, locale, result);
}

impl format_float_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32 {
    default_precision: i32 = 6;
    type_ = fmt.type_;
    add_pct = False;
    flags: i32 = 0;
    maxchar: u32 = u32(127);
    sign_char: u32 = u32(0);
    float_type: i32 = 0;
    unicode_tmp: ptr[PyObject] = NULL;
    spec = NumberFieldWidths();
    locale = LocaleInfo();

    if fmt.precision > INT_MAX {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("precision too big"));
        return number_done(unicode_tmp, locale, -1);
    }
    precision = i32(fmt.precision);

    if fmt.alternate != 0 {
        flags = flags | Py_DTSF_ALT;
    }
    if fmt.no_neg_0 != 0 {
        flags = flags | Py_DTSF_NO_NEG_0;
    }

    if type_ == u32(0) {
        flags = flags | Py_DTSF_ADD_DOT_0;
        type_ = u32(114);
        default_precision = 0;
    }

    if type_ == u32(110) {
        type_ = u32(103);
    }

    val = PyFloat_AsDouble(value);
    if val == -1.0 and PyErr_Occurred() {
        return number_done(unicode_tmp, locale, -1);
    }

    if type_ == u32(37) {
        type_ = u32(102);
        val = val * 100.0;
        add_pct = True;
    }

    if precision < 0 {
        precision = default_precision;
    } elif type_ == u32(114) {
        type_ = u32(103);
    }

    buf = PyOS_double_to_string(val, i8.wrap(type_), precision, flags, &mut float_type);
    if not buf {
        return number_done(unicode_tmp, locale, -1);
    }
    n_digits = i64(strlen(buf));

    if add_pct {
        (buf + n_digits).view(1)[0] = u8(37);
        n_digits += 1;
    }

    if fmt.sign != u32(43)
        and fmt.sign != u32(32)
        and fmt.width == -1
        and fmt.type_ != u32(110)
        and fmt.thousands_separators == 0
        and fmt.frac_thousands_separator == 0 {
        result = _PyUnicodeWriter_WriteASCIIString(writer, buf, n_digits);
        PyMem_Free(buf);
        return result;
    }

    unicode_tmp = _PyUnicode_FromASCII(buf, n_digits);
    PyMem_Free(buf);
    if not unicode_tmp {
        return number_done(unicode_tmp, locale, -1);
    }

    index: i64 = 0;
    if uo_read_char(unicode_tmp, index) == u32(45) {
        sign_char = u32(45);
        index += 1;
        n_digits -= 1;
    }

    (n_remainder, n_frac, has_decimal) = parse_number(
        unicode_tmp, index, index + n_digits
    );

    locale_type = fmt.thousands_separators;
    if fmt.type_ == u32(110) {
        locale_type = LT_CURRENT_LOCALE;
    }
    if get_locale_info(locale_type, fmt.frac_thousands_separator, locale) == -1 {
        return number_done(unicode_tmp, locale, -1);
    }

    (n_total, maxchar) = calc_number_widths(
        spec,
        0,
        sign_char,
        index,
        index + n_digits,
        n_remainder,
        n_frac,
        has_decimal,
        locale,
        fmt,
        maxchar
    );
    if n_total == -1 {
        return number_done(unicode_tmp, locale, -1);
    }

    if writer_prepare(writer, n_total, maxchar) == -1 {
        return number_done(unicode_tmp, locale, -1);
    }

    result = fill_number(
        writer, spec, unicode_tmp, index, NULL, 0, fmt.fill_char, locale, False
    );
    return number_done(unicode_tmp, locale, result);
}

impl copy_format_spec(fmt: InternalFormatSpec) -> InternalFormatSpec {
    return InternalFormatSpec(
        fill_char=fmt.fill_char,
        align=fmt.align,
        alternate=fmt.alternate,
        no_neg_0=fmt.no_neg_0,
        sign=fmt.sign,
        width=fmt.width,
        thousands_separators=fmt.thousands_separators,
        precision=fmt.precision,
        frac_thousands_separator=fmt.frac_thousands_separator,
        type_=fmt.type_
    );
}

impl complex_done(
    re_buf: ptr[u8],
    im_buf: ptr[u8],
    re_unicode_tmp: ptr[PyObject],
    im_unicode_tmp: ptr[PyObject],
    locale: LocaleInfo,
    result: i32
) -> i32 {
    PyMem_Free(re_buf);
    PyMem_Free(im_buf);
    object_xdecref(re_unicode_tmp);
    object_xdecref(im_unicode_tmp);
    free_locale_info(locale);
    return result;
}

impl format_complex_internal(
    value: ptr[PyObject], fmt: InternalFormatSpec, writer: ptr[UnicodeWriter]
) -> i32 {
    re_buf: ptr[u8] = ptr[u8]();
    im_buf: ptr[u8] = ptr[u8]();
    tmp_format = copy_format_spec(fmt);
    default_precision: i32 = 6;
    type_ = fmt.type_;
    re_spec = NumberFieldWidths();
    im_spec = NumberFieldWidths();
    flags: i32 = 0;
    maxchar: u32 = u32(127);
    re_sign_char: u32 = u32(0);
    im_sign_char: u32 = u32(0);
    re_float_type: i32 = 0;
    im_float_type: i32 = 0;
    add_parens: i64 = 0;
    skip_re = False;
    re_unicode_tmp: ptr[PyObject] = NULL;
    im_unicode_tmp: ptr[PyObject] = NULL;
    locale = LocaleInfo();

    if fmt.precision > INT_MAX {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("precision too big"));
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    precision = i32(fmt.precision);

    if fmt.fill_char == u32(48) {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("Zero padding is not allowed in complex format specifier")
        );
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    if fmt.align == u32(61) {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("'=' alignment flag is not allowed in complex format specifier")
        );
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    re_val = PyComplex_RealAsDouble(value);
    if re_val == -1.0 and PyErr_Occurred() {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    im_val = PyComplex_ImagAsDouble(value);
    if im_val == -1.0 and PyErr_Occurred() {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    if fmt.alternate != 0 {
        flags = flags | Py_DTSF_ALT;
    }
    if fmt.no_neg_0 != 0 {
        flags = flags | Py_DTSF_NO_NEG_0;
    }

    if type_ == u32(0) {
        type_ = u32(114);
        default_precision = 0;
        if re_val == 0.0 and copysign(1.0, re_val) == 1.0 {
            skip_re = True;
        } else {
            add_parens = 1;
        }
    }

    if type_ == u32(110) {
        type_ = u32(103);
    }

    if precision < 0 {
        precision = default_precision;
    } elif type_ == u32(114) {
        type_ = u32(103);
    }

    re_buf = PyOS_double_to_string(
        re_val, i8.wrap(type_), precision, flags, &mut re_float_type
    );
    if not re_buf {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    im_buf = PyOS_double_to_string(
        im_val, i8.wrap(type_), precision, flags, &mut im_float_type
    );
    if not im_buf {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    n_re_digits = i64(strlen(re_buf));
    n_im_digits = i64(strlen(im_buf));

    re_unicode_tmp = _PyUnicode_FromASCII(re_buf, n_re_digits);
    if not re_unicode_tmp {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    i_re: i64 = 0;

    im_unicode_tmp = _PyUnicode_FromASCII(im_buf, n_im_digits);
    if not im_unicode_tmp {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    i_im: i64 = 0;

    if uo_read_char(re_unicode_tmp, i_re) == u32(45) {
        re_sign_char = u32(45);
        i_re += 1;
        n_re_digits -= 1;
    }
    if uo_read_char(im_unicode_tmp, i_im) == u32(45) {
        im_sign_char = u32(45);
        i_im += 1;
        n_im_digits -= 1;
    }

    (n_re_remainder, n_re_frac, re_has_decimal) = parse_number(
        re_unicode_tmp, i_re, i_re + n_re_digits
    );
    (n_im_remainder, n_im_frac, im_has_decimal) = parse_number(
        im_unicode_tmp, i_im, i_im + n_im_digits
    );

    locale_type = fmt.thousands_separators;
    if fmt.type_ == u32(110) {
        locale_type = LT_CURRENT_LOCALE;
    }
    if get_locale_info(locale_type, fmt.frac_thousands_separator, locale) == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    tmp_format.fill_char = u32(0);
    tmp_format.align = u32(60);
    tmp_format.width = -1;

    (n_re_total, maxchar) = calc_number_widths(
        re_spec,
        0,
        re_sign_char,
        i_re,
        i_re + n_re_digits,
        n_re_remainder,
        n_re_frac,
        re_has_decimal,
        locale,
        tmp_format,
        maxchar
    );
    if n_re_total == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    if not skip_re {
        tmp_format.sign = u32(43);
    }
    (n_im_total, maxchar) = calc_number_widths(
        im_spec,
        0,
        im_sign_char,
        i_im,
        i_im + n_im_digits,
        n_im_remainder,
        n_im_frac,
        im_has_decimal,
        locale,
        tmp_format,
        maxchar
    );
    if n_im_total == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    if skip_re {
        n_re_total = 0;
    }

    (lpad, rpad, total) = calc_padding(
        n_re_total + n_im_total + 1 + add_parens * 2, fmt.width, fmt.align
    );

    if lpad != 0 or rpad != 0 {
        if fmt.fill_char > maxchar {
            maxchar = fmt.fill_char;
        }
    }

    if writer_prepare(writer, total, maxchar) == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    rkind = i64(writer.view(1)[0].kind);
    rdata = writer.view(1)[0].data;

    result = fill_padding(
        writer, n_re_total + n_im_total + 1 + add_parens * 2, fmt.fill_char, lpad, rpad
    );
    if result == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }

    if add_parens != 0 {
        ch_write(rkind, rdata, writer.view(1)[0].pos, u32(40));
        writer.view(1)[0].pos = writer.view(1)[0].pos + 1;
    }

    if not skip_re {
        result = fill_number(
            writer, re_spec, re_unicode_tmp, i_re, NULL, 0, u32(0), locale, False
        );
        if result == -1 {
            return complex_done(
                re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1
            );
        }
    }
    result = fill_number(
        writer, im_spec, im_unicode_tmp, i_im, NULL, 0, u32(0), locale, False
    );
    if result == -1 {
        return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, -1);
    }
    ch_write(rkind, rdata, writer.view(1)[0].pos, u32(106));
    writer.view(1)[0].pos = writer.view(1)[0].pos + 1;

    if add_parens != 0 {
        ch_write(rkind, rdata, writer.view(1)[0].pos, u32(41));
        writer.view(1)[0].pos = writer.view(1)[0].pos + 1;
    }

    writer.view(1)[0].pos = writer.view(1)[0].pos + rpad;

    return complex_done(re_buf, im_buf, re_unicode_tmp, im_unicode_tmp, locale, result);
}

impl format_obj(obj_: ptr[PyObject], writer: ptr[UnicodeWriter]) -> i32 {
    text = PyObject_Str(obj_);
    if not text {
        return -1;
    }
    err = _PyUnicodeWriter_WriteStr(writer, text);
    object_decref(text);
    return err;
}
