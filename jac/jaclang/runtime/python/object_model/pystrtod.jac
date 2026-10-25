import from c {
    def _Py_dg_strtod(s00: ptr[u8], se: &mut ptr[u8]) -> f64;  def _Py_dg_dtoa(
        dd: f64,
        mode: i32,
        ndigits: i32,
        decpt: &mut i32,
        sign: &mut i32,
        rve: &mut ptr[u8]
    ) -> ptr[u8];  def _Py_dg_freedtoa(s: ptr[u8]);  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def sprintf(target: ptr[u8], format: ptr[u8], *args: any) -> i32;  obj NumberParseCall {
        has inner: Callable[[ptr[u8], i64, ptr], ptr[PyObject]] = 0;
    }  def _Py_parse_inf_or_nan(p: ptr[u8], endptr: ptr[ptr[u8]]) -> f64 {
        (retval, end) = parse_inf_or_nan(p);
        endptr.view(1)[0] = end;
        return retval;
    }  def PyOS_string_to_double(
        s: ptr[u8], endptr: ptr[ptr[u8]], overflow_exception: ptr[PyObject]
    ) -> f64 {
        result: f64 = -1.0;

        jacpy_set_errno(0);
        (x, fail_pos) = ascii_strtod(s);
        errno = jacpy_errno();

        if errno == ENOMEM {
            PyErr_NoMemory();
            fail_pos = s;
        } elif not endptr
            and (int(fail_pos) == int(s) or fail_pos.view(1)[0] != u8(0)) {
            PyErr_Format(
                PyExc_ValueError, "could not convert string to float: '%.200s'", s
            );
        } elif int(fail_pos) == int(s) {
            PyErr_Format(
                PyExc_ValueError, "could not convert string to float: '%.200s'", s
            );
        } elif errno == ERANGE and fabs(x) >= 1.0 and overflow_exception {
            PyErr_Format(
                overflow_exception, "value too large to convert to float: '%.200s'", s
            );
        } else {
            result = x;
        }

        if endptr {
            endptr.view(1)[0] = fail_pos;
        }
        return result;
    }  def _Py_string_to_number_with_underscores(
        s: ptr[u8],
        orig_len: i64,
        what: ptr[u8],
        obj_: ptr[PyObject],
        arg: ptr,
        innerfunc: ptr
    ) -> ptr[PyObject] {
        calls = ptr[NumberParseCall](
            __thread_local_block("jac_object_model_pystrtod_call_slot", 8)
        );
        if not strchr(s, 95) {
            calls.view(1)[0].inner = int(innerfunc);
            return calls.view(1)[0].inner(s, orig_len, arg);
        }

        dup = ptr[u8](PyMem_Malloc(u64(orig_len + 1)));
        if not dup {
            return PyErr_NoMemory();
        }
        end = dup;
        prev = u8(0);
        last = s + orig_len;
        p = s;
        bad = False;
        while p.view(1)[0] != u8(0) {
            ch = p.view(1)[0];
            if ch == CH_UNDERSCORE {
                if not (prev >= CH_0 and prev <= CH_9) {
                    bad = True;
                    break;
                }
            } else {
                end.view(1)[0] = ch;
                end = end + 1;
                if prev == CH_UNDERSCORE and not (ch >= CH_0 and ch <= CH_9) {
                    bad = True;
                    break;
                }
            }
            prev = ch;
            p = p + 1;
        }
        if not bad and prev == CH_UNDERSCORE {
            bad = True;
        }
        if not bad and int(p) != int(last) {
            bad = True;
        }
        if bad {
            PyMem_Free(ptr(dup));
            PyErr_Format(
                PyExc_ValueError, "could not convert string to %s: %R", what, obj_
            );
            return NULL;
        }
        end.view(1)[0] = u8(0);
        calls.view(1)[0].inner = int(innerfunc);
        result = calls.view(1)[0].inner(dup, int(end) - int(dup), arg);
        PyMem_Free(ptr(dup));
        return result;
    }  def PyOS_double_to_string(
        val: f64, format_code: i8, precision: i32, flags: i32, type_: ptr[i32]
    ) -> ptr[u8] {
        upper = False;
        code = i32(format_code);
        prec = precision;
        mode: i32 = 0;

        if code == CODE_UPPER_E {
            upper = True;
            code = CODE_E;
        } elif code == CODE_UPPER_F {
            upper = True;
            code = CODE_F;
        } elif code == CODE_UPPER_G {
            upper = True;
            code = CODE_G;
        }
        if code == CODE_E {
            mode = 2;
            prec += 1;
        } elif code == CODE_F {
            mode = 3;
        } elif code == CODE_G {
            mode = 2;
            if prec == 0 {
                prec = 1;
            }
        } elif code == CODE_R {
            mode = 0;
            if prec != 0 {
                PyErr_BadInternalCall();
                return ptr[u8]();
            }
        } else {
            PyErr_BadInternalCall();
            return ptr[u8]();
        }

        return format_float_short(
            val,
            code,
            mode,
            prec,
            (flags & Py_DTSF_SIGN) != 0,
            (flags & Py_DTSF_ADD_DOT_0) != 0,
            (flags & Py_DTSF_ALT) != 0,
            (flags & Py_DTSF_NO_NEG_0) != 0,
            upper,
            type_
        );
    }
}

glob:priv CH_0: Final[u8] = u8(48),
     CH_9: Final[u8] = u8(57),
     CH_PLUS: Final[u8] = u8(43),
     CH_MINUS: Final[u8] = u8(45),
     CH_DOT: Final[u8] = u8(46),
     CH_UNDERSCORE: Final[u8] = u8(95),
     CH_LOWER_I: Final[u8] = u8(105),
     CH_UPPER_I: Final[u8] = u8(73),
     CH_LOWER_N: Final[u8] = u8(110),
     CH_UPPER_N: Final[u8] = u8(78),
     CODE_E: Final[i32] = 101,
     CODE_F: Final[i32] = 102,
     CODE_G: Final[i32] = 103,
     CODE_R: Final[i32] = 114,
     CODE_UPPER_E: Final[i32] = 69,
     CODE_UPPER_F: Final[i32] = 70,
     CODE_UPPER_G: Final[i32] = 71,
     Py_DTSF_ALT: Final[i32] = 4,
     Py_DTSF_NO_NEG_0: Final[i32] = 8,
     Py_DTST_FINITE: Final[i32] = 0,
     Py_DTST_INFINITE: Final[i32] = 1,
     Py_DTST_NAN: Final[i32] = 2,
     INFINITY_BITS: Final[i64] = 0x7ff0000000000000,
     NEG_INFINITY_BITS: Final[i64] = -0x10000000000000,
     NAN_BITS: Final[i64] = 0x7ff8000000000000,
     NEG_NAN_BITS: Final[i64] = -0x8000000000000;

def pick_double(negate: bool, negative: i64, positive: i64) -> f64;

def fabs(x: f64) -> f64;

def case_insensitive_match(s: ptr[u8], t: ptr[u8]) -> bool;

def parse_inf_or_nan(p: ptr[u8]) -> tuple[f64, ptr[u8]];

def ascii_strtod(nptr: ptr[u8]) -> tuple[f64, ptr[u8]];

def format_float_short(
    d: f64,
    format_code: i32,
    mode: i32,
    precision: i32,
    always_add_sign: bool,
    add_dot_0_if_integer: bool,
    use_alt_formatting: bool,
    no_negative_zero: bool,
    upper: bool,
    type_: ptr[i32]
) -> ptr[u8];

impl pick_double(negate: bool, negative: i64, positive: i64) -> f64 {
    if negate {
        return __bits_float(negative);
    }
    return __bits_float(positive);
}

impl fabs(x: f64) -> f64 {
    return __bits_float(__float_bits(x) & 0x7fffffffffffffff);
}

impl case_insensitive_match(s: ptr[u8], t: ptr[u8]) -> bool {
    p = s;
    q = t;
    while q.view(1)[0] != u8(0) and py_tolower(p.view(1)[0]) == q.view(1)[0] {
        p = p + 1;
        q = q + 1;
    }
    return q.view(1)[0] == u8(0);
}

impl parse_inf_or_nan(p: ptr[u8]) -> tuple[f64, ptr[u8]] {
    retval: f64 = 0.0;
    s = p;
    negate = False;
    if s.view(1)[0] == CH_MINUS {
        negate = True;
        s = s + 1;
    } elif s.view(1)[0] == CH_PLUS {
        s = s + 1;
    }
    if case_insensitive_match(s, ptr[u8]("inf")) {
        s = s + 3;
        if case_insensitive_match(s, ptr[u8]("inity")) {
            s = s + 5;
        }
        retval = pick_double(negate, NEG_INFINITY_BITS, INFINITY_BITS);
    } elif case_insensitive_match(s, ptr[u8]("nan")) {
        s = s + 3;
        retval = pick_double(negate, NEG_NAN_BITS, NAN_BITS);
    } else {
        s = p;
        retval = -1.0;
    }
    return (retval, s);
}

impl ascii_strtod(nptr: ptr[u8]) -> tuple[f64, ptr[u8]] {
    end = nptr;
    jacpy_set_errno(0);
    result = _Py_dg_strtod(nptr, &mut end);
    if int(end) == int(nptr) {
        (special, special_end) = parse_inf_or_nan(nptr);
        return (special, special_end);
    }
    return (result, end);
}

impl format_float_short(
    d: f64,
    format_code: i32,
    mode: i32,
    precision: i32,
    always_add_sign: bool,
    add_dot_0_if_integer: bool,
    use_alt_formatting: bool,
    no_negative_zero: bool,
    upper: bool,
    type_: ptr[i32]
) -> ptr[u8] {
    decpt_as_int: i32 = 0;
    sign: i32 = 0;
    digits_end = ptr[u8]();
    digits = _Py_dg_dtoa(
        d, mode, precision, &mut decpt_as_int, &mut sign, &mut digits_end
    );
    decpt = i64(decpt_as_int);
    if not digits {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    digits_len = int(digits_end) - int(digits);
    first = digits.view(1)[0];

    if no_negative_zero
        and sign == 1
        and (digits_len == 0 or (digits_len == 1 and first == CH_0)) {
        sign = 0;
    }

    if digits_len != 0 and not (first >= CH_0 and first <= CH_9) {
        if first == CH_LOWER_N or first == CH_UPPER_N {
            sign = 0;
        }

        buf = ptr[u8](PyMem_Malloc(u64(5)));
        if not buf {
            PyErr_NoMemory();
            _Py_dg_freedtoa(digits);
            return buf;
        }
        p = buf;

        if sign == 1 {
            p.view(1)[0] = CH_MINUS;
            p = p + 1;
        } elif always_add_sign {
            p.view(1)[0] = CH_PLUS;
            p = p + 1;
        }
        if first == CH_LOWER_I or first == CH_UPPER_I {
            if upper {
                memcpy(ptr(p), ptr(ptr[u8]("INF")), u64(3));
            } else {
                memcpy(ptr(p), ptr(ptr[u8]("inf")), u64(3));
            }
            p = p + 3;
            if type_ {
                type_.view(1)[0] = Py_DTST_INFINITE;
            }
        } else {
            if upper {
                memcpy(ptr(p), ptr(ptr[u8]("NAN")), u64(3));
            } else {
                memcpy(ptr(p), ptr(ptr[u8]("nan")), u64(3));
            }
            p = p + 3;
            if type_ {
                type_.view(1)[0] = Py_DTST_NAN;
            }
        }
        p.view(1)[0] = u8(0);
        _Py_dg_freedtoa(digits);
        return buf;
    }

    if type_ {
        type_.view(1)[0] = Py_DTST_FINITE;
    }

    vdigits_end = digits_len;
    use_exp = False;
    exp: i32 = 0;
    if format_code == CODE_E {
        use_exp = True;
        vdigits_end = i64(precision);
    } elif format_code == CODE_F {
        vdigits_end = decpt + i64(precision);
    } elif format_code == CODE_G {
        limit = i64(precision) - 1 if add_dot_0_if_integer else i64(precision);
        if decpt <= -4 or decpt > limit {
            use_exp = True;
        }
        if use_alt_formatting {
            vdigits_end = i64(precision);
        }
    } elif format_code == CODE_R {
        if decpt <= -4 or decpt > 16 {
            use_exp = True;
        }
    } else {
        PyErr_BadInternalCall();
        _Py_dg_freedtoa(digits);
        return ptr[u8]();
    }

    if use_exp {
        exp = i32(decpt) - 1;
        decpt = 1;
    }
    vdigits_start = decpt - 1 if decpt <= 0 else 0;
    if not use_exp and add_dot_0_if_integer {
        if vdigits_end <= decpt {
            vdigits_end = decpt + 1;
        }
    } elif vdigits_end <= decpt {
        vdigits_end = decpt;
    }

    bufsize = 3 + (vdigits_end - vdigits_start);
    if use_exp {
        bufsize += 5;
    }

    buf = ptr[u8](PyMem_Malloc(u64(bufsize)));
    if not buf {
        PyErr_NoMemory();
        _Py_dg_freedtoa(digits);
        return buf;
    }
    p = buf;

    if sign == 1 {
        p.view(1)[0] = CH_MINUS;
        p = p + 1;
    } elif always_add_sign {
        p.view(1)[0] = CH_PLUS;
        p = p + 1;
    }

    if decpt <= 0 {
        memset(ptr(p), 48, u64(decpt - vdigits_start));
        p = p + (decpt - vdigits_start);
        p.view(1)[0] = CH_DOT;
        p = p + 1;
        memset(ptr(p), 48, u64(0 - decpt));
        p = p + (0 - decpt);
    } else {
        memset(ptr(p), 48, u64(0 - vdigits_start));
        p = p + (0 - vdigits_start);
    }

    if 0 < decpt and decpt <= digits_len {
        memcpy(ptr(p), ptr(digits), u64(decpt));
        p = p + decpt;
        p.view(1)[0] = CH_DOT;
        p = p + 1;
        memcpy(ptr(p), ptr(digits + decpt), u64(digits_len - decpt));
        p = p + (digits_len - decpt);
    } else {
        memcpy(ptr(p), ptr(digits), u64(digits_len));
        p = p + digits_len;
    }

    if digits_len < decpt {
        memset(ptr(p), 48, u64(decpt - digits_len));
        p = p + (decpt - digits_len);
        p.view(1)[0] = CH_DOT;
        p = p + 1;
        memset(ptr(p), 48, u64(vdigits_end - decpt));
        p = p + (vdigits_end - decpt);
    } else {
        memset(ptr(p), 48, u64(vdigits_end - digits_len));
        p = p + (vdigits_end - digits_len);
    }

    if (p - 1).view(1)[0] == CH_DOT and not use_alt_formatting {
        p = p - 1;
    }

    if use_exp {
        if upper {
            p.view(1)[0] = u8(69);
        } else {
            p.view(1)[0] = u8(101);
        }
        p = p + 1;
        exp_len = sprintf(p, ptr[u8]("%+.02d"), exp);
        p = p + i64(exp_len);
    }
    p.view(1)[0] = u8(0);
    _Py_dg_freedtoa(digits);
    return buf;
}
