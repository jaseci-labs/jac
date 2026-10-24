import from c {
    glob PyType_Type: PyTypeObject; obj _PyBytesWriter;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def strlen(
        s: ptr[u8]
    ) -> u64;  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyObject_Bytes(v: ptr[PyObject]) -> ptr[PyObject];  def _PyUnicodeWriter_PrepareInternal(
        writer: ptr[_PyUnicodeWriter], length: i64, maxchar: u32
    ) -> i32;  def _PyUnicodeWriter_WriteStr(
        writer: ptr[_PyUnicodeWriter], s: ptr[PyObject]
    ) -> i32;  def _PyBytesWriter_Prepare(
        writer: ptr[_PyBytesWriter], s: ptr, size: i64
    ) -> ptr;  def _PyLong_FormatAdvancedWriter(
        writer: ptr[_PyUnicodeWriter],
        ob: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyStructSequence_InitBuiltinWithFlags(
        interp: ptr, type: ptr[PyObject], desc: ptr[PyStructSequence_Desc], flags: u64
    ) -> i32;  def _PyStructSequence_FiniBuiltin(interp: ptr, type: ptr[PyObject]);  def _PyObject_MakeTpCall(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        keywords: ptr[PyObject]
    ) -> ptr[PyObject];  glob _PyLong_DigitValue: list[u8] = [
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(0),
             u8(1),
             u8(2),
             u8(3),
             u8(4),
             u8(5),
             u8(6),
             u8(7),
             u8(8),
             u8(9),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(23),
             u8(24),
             u8(25),
             u8(26),
             u8(27),
             u8(28),
             u8(29),
             u8(30),
             u8(31),
             u8(32),
             u8(33),
             u8(34),
             u8(35),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(23),
             u8(24),
             u8(25),
             u8(26),
             u8(27),
             u8(28),
             u8(29),
             u8(30),
             u8(31),
             u8(32),
             u8(33),
             u8(34),
             u8(35),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37),
             u8(37)
         ];
}

glob:priv PyLong_SHIFT: i64 = 30,
     PyLong_BASE: u64 = u64(1073741824),
     PyLong_MASK: u64 = u64(1073741823),
     PyLong_MASK_SIGNED: i64 = 1073741823,
     PyLong_DECIMAL_SHIFT: i64 = 9,
     PyLong_DECIMAL_BASE: u64 = u64(1000000000),
     SIGN_MASK: u64 = u64(3),
     SIGN_ZERO: u64 = u64(1),
     SIGN_NEGATIVE: u64 = u64(2),
     NON_SIZE_BITS: i64 = 3,
     IMMORTALITY_BIT_MASK: u64 = u64(4),
     NON_SIZE_MASK: u64 = ~u64(7),
     _PY_NSMALLPOSINTS: i64 = 257,
     _PY_NSMALLNEGINTS: i64 = 5,
     MAX_LONG_DIGITS: i64 = 307445734561825860,
     _PY_LONG_DEFAULT_MAX_STR_DIGITS: i64 = 4300,
     _PY_LONG_MAX_STR_DIGITS_THRESHOLD: i64 = 640,
     KARATSUBA_CUTOFF: i64 = 70,
     KARATSUBA_SQUARE_CUTOFF: i64 = 140,
     EXP_WINDOW_SIZE: i64 = 5,
     EXP_TABLE_LEN: i64 = 16,
     HUGE_EXP_CUTOFF: i64 = 60,
     PYREFTRACER_DESTROY: i32 = 1;

def long_of(op: ptr[PyObject]) -> ptr[PyLongObject];

def as_object(v: ptr[PyLongObject]) -> ptr[PyObject];

def long_type -> ptr[PyTypeObject];

def long_check(op: ptr[PyObject]) -> bool;

def long_check_exact(op: ptr[PyObject]) -> bool;

def long_tag(v: ptr[PyLongObject]) -> u64;

def set_long_tag(v: ptr[PyLongObject], tag: u64);

def ob_digits(v: ptr[PyLongObject]) -> ptr[u32];

def digit_at(v: ptr[PyLongObject], i: i64) -> u32;

def set_digit(v: ptr[PyLongObject], i: i64, d: u32);

def dget(p: ptr[u32], i: i64) -> u32;

def dset(p: ptr[u32], i: i64, d: u32);

def long_is_compact(v: ptr[PyLongObject]) -> bool;

def compact_value(v: ptr[PyLongObject]) -> i64;

def long_is_nonnegative_compact(v: ptr[PyLongObject]) -> bool;

def both_compact(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> bool;

def long_is_zero(v: ptr[PyLongObject]) -> bool;

def long_is_negative(v: ptr[PyLongObject]) -> bool;

def long_is_positive(v: ptr[PyLongObject]) -> bool;

def long_is_small_int(v: ptr[PyLongObject]) -> bool;

def digit_count(v: ptr[PyLongObject]) -> i64;

def long_sign_of(v: ptr[PyLongObject]) -> i64;

def signed_digit_count(v: ptr[PyLongObject]) -> i64;

def same_sign(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> bool;

def tag_from_sign_and_size(sign: i64, size: i64) -> u64;

def set_sign_and_digit_count(v: ptr[PyLongObject], sign: i64, size: i64);

def set_digit_count(v: ptr[PyLongObject], size: i64);

def flip_sign(v: ptr[PyLongObject]);

def is_small_int(ival: i64) -> bool;

def is_small_uint(ival: u64) -> bool;

def get_small_int(ival: i64) -> ptr[PyObject];

def long_zero -> ptr[PyObject];

def long_one -> ptr[PyObject];

def is_medium_int(x: i64) -> bool;

def object_is_uniquely_referenced(op: ptr[PyObject]) -> bool;

def decref_int(v: ptr[PyLongObject]);

def maybe_small_long(v: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_normalize(v: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_alloc(size: i64) -> ptr[PyLongObject];

def long_from_medium(x: i64) -> ptr[PyObject];

def long_from_large(ival: i64) -> ptr[PyObject];

def long_from_stwodigits(x: i64) -> ptr[PyLongObject];

def long_negate(x: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_from_int(ival: i64) -> ptr[PyObject];

def long_from_uint(ival_in: u64) -> ptr[PyObject];

def max_str_digits -> i64;

def both_long(v: ptr[PyObject], w: ptr[PyObject]) -> bool;

import from c {
    def _PyLong_New(size: i64) -> ptr[PyLongObject] {
        return long_alloc(size);
    }  def _PyLong_FromDigits(
        negative: i32, digit_count: i64, digits: ptr[u32]
    ) -> ptr[PyLongObject] {
        if digit_count == 0 {
            return long_of(long_zero());
        }
        result = long_alloc(digit_count);
        if not result {
            return ptr[PyLongObject]();
        }
        set_sign_and_digit_count(result, -1 if negative != i32(0) else 1, digit_count);
        memcpy(
            ptr(ob_digits(result)), ptr(digits), u64(digit_count * PyLong_DIGIT_SIZE)
        );
        return result;
    }  def _PyLong_Copy(src: ptr[PyLongObject]) -> ptr[PyObject] {
        sign: i64 = 0;
        if long_is_compact(src) {
            ival = compact_value(src);
            if is_small_int(ival) {
                return get_small_int(ival);
            }
        }
        sign = long_sign_of(src);
        size = digit_count(src);
        result = long_alloc(size);
        if not result {
            return NULL;
        }
        set_sign_and_digit_count(result, sign, size);
        memcpy(
            ptr(ob_digits(result)), ptr(ob_digits(src)), u64(size * PyLong_DIGIT_SIZE)
        );
        return as_object(result);
    }  def PyLong_FromLong(ival: i64) -> ptr[PyObject] {
        return long_from_int(ival);
    }  def PyLong_FromUnsignedLong(ival: u64) -> ptr[PyObject] {
        return long_from_uint(ival);
    }  def PyLong_FromUnsignedLongLong(ival: u64) -> ptr[PyObject] {
        return long_from_uint(ival);
    }  def PyLong_FromSize_t(ival: u64) -> ptr[PyObject] {
        return long_from_uint(ival);
    }
}

glob:priv LONG_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     LONG_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     INT_MAX: i64 = 2147483647,
     INT_MIN: i64 = -2147483648,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     PY_SSIZE_T_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     PY_ABS_LONG_MIN: u64 = u64(1) << u64(63),
     PY_ABS_SSIZE_T_MIN: u64 = u64(1) << u64(63),
     LONG_MAX_PLUS_ONE: f64 = 9223372036854775808.0;

import from c {
    def PyLong_FromDouble(dval_in: f64) -> ptr[PyObject] {
        dval = dval_in;
        int_max = LONG_MAX_PLUS_ONE;
        if -int_max < dval and dval < int_max {
            return PyLong_FromLong(i64(dval));
        }
        neg = False;

        if dval == dval and dval - dval != 0.0 {
            PyErr_SetString(
                PyExc_OverflowError, "cannot convert float infinity to integer"
            );
            return NULL;
        }
        if dval != dval {
            PyErr_SetString(PyExc_ValueError, "cannot convert float NaN to integer");
            return NULL;
        }
        if dval < 0.0 {
            neg = True;
            dval = -dval;
        }

        expo = i32(0);
        frac = frexp(dval, &mut expo);
        e = i64(expo);

        ndig = (e - 1) // PyLong_SHIFT + 1;
        v = long_alloc(ndig);
        if not v {
            return NULL;
        }
        frac = ldexp(frac, i32((e - 1) % PyLong_SHIFT + 1));
        i = ndig;
        while i > 0 {
            i -= 1;
            bits = u32(i64(frac));
            set_digit(v, i, bits);
            frac = frac - f64(bits);
            frac = ldexp(frac, i32(PyLong_SHIFT));
        }
        if neg {
            flip_sign(v);
        }
        return as_object(v);
    }
}

def long_as_long_and_overflow(vv: ptr[PyObject]) -> tuple[i64, i32];

import from c {
    def PyLong_AsLongAndOverflow(vv: ptr[PyObject], overflow: ptr[i32]) -> i64 {
        (res, ovf) = long_as_long_and_overflow(vv);
        overflow.view(1)[0] = ovf;
        return res;
    }  def PyLong_AsLong(obj_: ptr[PyObject]) -> i64 {
        (result, overflow) = long_as_long_and_overflow(obj_);
        if overflow != i32(0) {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C long"
            );
        }
        return result;
    }  def PyLong_AsInt(obj_: ptr[PyObject]) -> i32 {
        (result, overflow) = long_as_long_and_overflow(obj_);
        if overflow != i32(0) or result > INT_MAX or result < INT_MIN {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C int"
            );
            return i32(-1);
        }
        return i32(result);
    }  def PyLong_AsSsize_t(vv: ptr[PyObject]) -> i64 {
        if not vv {
            PyErr_BadInternalCall();
            return -1;
        }
        if not long_check(vv) {
            PyErr_SetString(PyExc_TypeError, "an integer is required");
            return -1;
        }
        v = long_of(vv);
        if long_is_compact(v) {
            return compact_value(v);
        }
        i = digit_count(v);
        sign = long_sign_of(v);
        x = u64(0);
        lost_bits = False;
        while i > 0 {
            i -= 1;
            prev = x;
            x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
            if (x >> u64(PyLong_SHIFT)) != prev {
                lost_bits = True;
                break;
            }
        }

        if not lost_bits {
            if x <= u64(PY_SSIZE_T_MAX) {
                return i64(x) * sign;
            }
            if sign < 0 and x == PY_ABS_SSIZE_T_MIN {
                return PY_SSIZE_T_MIN;
            }
        }

        PyErr_SetString(
            PyExc_OverflowError, "Python int too large to convert to C ssize_t"
        );
        return -1;
    }  def PyLong_AsUnsignedLong(vv: ptr[PyObject]) -> u64 {
        if not vv {
            PyErr_BadInternalCall();
            return ~u64(0);
        }
        if not long_check(vv) {
            PyErr_SetString(PyExc_TypeError, "an integer is required");
            return ~u64(0);
        }
        v = long_of(vv);
        if long_is_nonnegative_compact(v) {
            return u64(compact_value(v));
        }
        if long_is_negative(v) {
            PyErr_SetString(
                PyExc_OverflowError, "can't convert negative value to unsigned int"
            );
            return ~u64(0);
        }
        i = digit_count(v);
        x = u64(0);
        while i > 0 {
            i -= 1;
            prev = x;
            x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
            if (x >> u64(PyLong_SHIFT)) != prev {
                PyErr_SetString(
                    PyExc_OverflowError,
                    "Python int too large to convert to C unsigned long"
                );
                return ~u64(0);
            }
        }
        return x;
    }  def PyLong_AsSize_t(vv: ptr[PyObject]) -> u64 {
        if not vv {
            PyErr_BadInternalCall();
            return ~u64(0);
        }
        if not long_check(vv) {
            PyErr_SetString(PyExc_TypeError, "an integer is required");
            return ~u64(0);
        }
        v = long_of(vv);
        if long_is_nonnegative_compact(v) {
            return u64(compact_value(v));
        }
        if long_is_negative(v) {
            PyErr_SetString(
                PyExc_OverflowError, "can't convert negative value to size_t"
            );
            return ~u64(0);
        }
        i = digit_count(v);
        x = u64(0);
        while i > 0 {
            i -= 1;
            prev = x;
            x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
            if (x >> u64(PyLong_SHIFT)) != prev {
                PyErr_SetString(
                    PyExc_OverflowError, "Python int too large to convert to C size_t"
                );
                return ~u64(0);
            }
        }
        return x;
    }
}

def long_as_unsigned_long_mask(vv: ptr[PyObject]) -> u64;

import from c {
    def PyLong_AsUnsignedLongMask(op: ptr[PyObject]) -> u64 {
        if not op {
            PyErr_BadInternalCall();
            return ~u64(0);
        }
        if long_check(op) {
            return long_as_unsigned_long_mask(op);
        }
        lo = _PyNumber_Index(op);
        if not lo {
            return ~u64(0);
        }
        val = long_as_unsigned_long_mask(lo);
        object_decref(lo);
        return val;
    }  def PyLong_IsPositive(obj_: ptr[PyObject]) -> i32 {
        if not long_check(obj_) {
            PyErr_Format(PyExc_TypeError, "expected int, got %T", obj_);
            return i32(-1);
        }
        return i32(1) if long_is_positive(long_of(obj_)) else i32(0);
    }  def PyLong_IsNegative(obj_: ptr[PyObject]) -> i32 {
        if not long_check(obj_) {
            PyErr_Format(PyExc_TypeError, "expected int, got %T", obj_);
            return i32(-1);
        }
        return i32(1) if long_is_negative(long_of(obj_)) else i32(0);
    }  def PyLong_IsZero(obj_: ptr[PyObject]) -> i32 {
        if not long_check(obj_) {
            PyErr_Format(PyExc_TypeError, "expected int, got %T", obj_);
            return i32(-1);
        }
        return i32(1) if long_is_zero(long_of(obj_)) else i32(0);
    }
}

def long_sign(vv: ptr[PyObject]) -> i32;

import from c {
    def _PyLong_Sign(vv: ptr[PyObject]) -> i32 {
        return long_sign(vv);
    }  def PyLong_GetSign(vv: ptr[PyObject], sign: ptr[i32]) -> i32 {
        if not long_check(vv) {
            PyErr_Format(PyExc_TypeError, "expect int, got %T", vv);
            return i32(-1);
        }
        sign.view(1)[0] = long_sign(vv);
        return i32(0);
    }
}

def bit_length_digit(x: u32) -> i64;

def as_byte_array_overflow(with_exceptions: i32) -> i32;

import from c {
    def _PyLong_NumBits(vv: ptr[PyObject]) -> i64 {
        v = long_of(vv);
        result: i64 = 0;
        ndigits = digit_count(v);
        if ndigits > 0 {
            msd = digit_at(v, ndigits - 1);
            result = (ndigits - 1) * PyLong_SHIFT;
            msd_bits = bit_length_digit(msd);
            result += msd_bits;
        }
        return result;
    }  def _PyLong_FromByteArray(
        bytes_: ptr[u8], n: u64, little_endian: i32, is_signed: i32
    ) -> ptr[PyObject] {
        if n == u64(0) {
            return PyLong_FromLong(0);
        }

        pstartbyte = bytes_;
        pendbyte = bytes_ + (i64(n) - 1);
        incr: i64 = 1;
        if little_endian == i32(0) {
            pstartbyte = bytes_ + (i64(n) - 1);
            pendbyte = bytes_;
            incr = -1;
        }
        signed = is_signed != i32(0) and pendbyte.view(1)[0] >= u8(0x80);

        i = u64(0);
        p = pendbyte;

        pincr = -incr;
        insignificant = u8(0xff) if signed else u8(0);
        while i < n {
            if p.view(1)[0] != insignificant {
                break;
            }
            i += u64(1);
            p = p + pincr;
        }
        numsignificantbytes = n - i;

        if signed and numsignificantbytes < n {
            numsignificantbytes += u64(1);
        }

        shift = u64(PyLong_SHIFT);
        ndigits = i64(
            (numsignificantbytes // shift) * u64(8)
                + ((numsignificantbytes % shift) * u64(8) + shift - u64(1)) // shift
        );
        v = long_alloc(ndigits);
        if not v {
            return NULL;
        }

        idigit: i64 = 0;

        carry = u64(1);

        accum = u64(0);
        accumbits = u64(0);
        p = pstartbyte;
        i = u64(0);
        while i < numsignificantbytes {
            thisbyte = u64(p.view(1)[0]);

            if signed {
                thisbyte = (u64(0xff) ^ thisbyte) + carry;
                carry = thisbyte >> u64(8);
                thisbyte = thisbyte & u64(0xff);
            }

            accum = accum | (thisbyte << accumbits);
            accumbits += u64(8);
            if accumbits >= shift {
                set_digit(v, idigit, u32.wrap(accum & PyLong_MASK));
                idigit += 1;
                accum = accum >> shift;
                accumbits -= shift;
            }
            i += u64(1);
            p = p + incr;
        }
        if accumbits != u64(0) {
            set_digit(v, idigit, u32.wrap(accum));
            idigit += 1;
        }
        sign: i64 = -1 if signed else 1;
        if idigit == 0 {
            sign = 0;
        }
        set_sign_and_digit_count(v, sign, idigit);
        return as_object(maybe_small_long(long_normalize(v)));
    }  def _PyLong_AsByteArray(
        vv: ptr[PyObject],
        bytes_: ptr[u8],
        n: u64,
        little_endian: i32,
        is_signed: i32,
        with_exceptions: i32
    ) -> i32 {
        v = long_of(vv);
        ndigits = digit_count(v);

        do_twos_comp = False;
        if long_is_negative(v) {
            if is_signed == i32(0) {
                if with_exceptions != i32(0) {
                    PyErr_SetString(
                        PyExc_OverflowError, "can't convert negative int to unsigned"
                    );
                }
                return i32(-1);
            }
            do_twos_comp = True;
        }

        p = bytes_;
        pincr: i64 = 1;
        if little_endian == i32(0) {
            p = bytes_ + (i64(n) - 1);
            pincr = -1;
        }

        mask = u32(PyLong_MASK);

        j = u64(0);
        accum = u64(0);
        accumbits = u64(0);

        carry = u32(1) if do_twos_comp else u32(0);
        for i in range(ndigits) {
            thisdigit = digit_at(v, i);
            if do_twos_comp {
                thisdigit = (thisdigit ^ mask) + carry;
                carry = thisdigit >> u32(PyLong_SHIFT);
                thisdigit = thisdigit & mask;
            }

            accum = accum | (u64(thisdigit) << accumbits);

            if i == ndigits - 1 {
                s = thisdigit ^ mask if do_twos_comp else thisdigit;
                while s != u32(0) {
                    s = s >> u32(1);
                    accumbits += u64(1);
                }
            } else {
                accumbits += u64(PyLong_SHIFT);
            }

            while accumbits >= u64(8) {
                if j >= n {
                    return as_byte_array_overflow(with_exceptions);
                }
                j += u64(1);
                p.view(1)[0] = u8(accum & u64(0xff));
                p = p + pincr;
                accumbits -= u64(8);
                accum = accum >> u64(8);
            }
        }

        if accumbits > u64(0) {
            if j >= n {
                return as_byte_array_overflow(with_exceptions);
            }
            j += u64(1);
            if do_twos_comp {
                accum = accum | wrapping_shl(~u64(0), accumbits);
            }
            p.view(1)[0] = u8(accum & u64(0xff));
            p = p + pincr;
        } elif j == n and is_signed != i32(0) {
            sign_bit_set = False;
            if n > u64(0) {
                msb = (p - pincr).view(1)[0];
                sign_bit_set = msb >= u8(0x80);
            }
            if sign_bit_set == do_twos_comp {
                return i32(0);
            }
            return as_byte_array_overflow(with_exceptions);
        }

        signbyte = u8(0xff) if do_twos_comp else u8(0);
        while j < n {
            p.view(1)[0] = signbyte;
            j += u64(1);
            p = p + pincr;
        }
        return i32(0);
    }
}

glob:priv Py_ASNATIVEBYTES_NATIVE_ENDIAN: i32 = 3,
     Py_ASNATIVEBYTES_UNSIGNED_BUFFER: i32 = 4,
     Py_ASNATIVEBYTES_REJECT_NEGATIVE: i32 = 8,
     Py_ASNATIVEBYTES_ALLOW_INDEX: i32 = 16,
     UNSIGNED_CONVERTER_FLAGS: i32 = 31,
     PY_LITTLE_ENDIAN: i32 = 1,
     SIZEOF_PY_SSIZE_T: i64 = 8,
     SIZEOF_LONG_LONG: i64 = 8,
     LLONG_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     LLONG_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     PY_ABS_LLONG_MIN: u64 = u64(1) << u64(63);

def _fits_in_n_bits(v: i64, n: i64) -> bool;

def _resolve_endianness(endianness_in: i32) -> tuple[i32, i32];

def ssize_t_byte(value: i64, i: i64) -> u8;

import from c {
    def PyLong_AsNativeBytes(
        vv: ptr[PyObject], buffer: ptr, n: i64, flags: i32
    ) -> i64 {
        v = ptr[PyLongObject]();
        do_decref = False;
        res: i64 = 0;
        if not vv or n < 0 {
            PyErr_BadInternalCall();
            return -1;
        }
        (status, little_endian) = _resolve_endianness(flags);
        if status < 0 {
            return -1;
        }
        if long_check(vv) {
            v = long_of(vv);
        } elif flags != -1 and (flags & Py_ASNATIVEBYTES_ALLOW_INDEX) != 0 {
            v = long_of(_PyNumber_Index(vv));
            if not v {
                return -1;
            }
            do_decref = True;
        } else {
            PyErr_Format(PyExc_TypeError, "expect int, got %T", vv);
            return -1;
        }
        if flags != -1
            and (flags & Py_ASNATIVEBYTES_REJECT_NEGATIVE) != 0
            and long_is_negative(v) {
            PyErr_SetString(PyExc_ValueError, "Cannot convert negative int");
            if do_decref {
                object_decref(as_object(v));
            }
            return -1;
        }
        b = ptr[u8](buffer);
        if long_is_compact(v) {
            cv = compact_value(v);

            res = SIZEOF_PY_SSIZE_T;

            if n > 0 and n <= SIZEOF_PY_SSIZE_T {
                if little_endian != 0 {
                    for i in range(n) {
                        (b + i).view(1)[0] = ssize_t_byte(cv, i);
                    }
                } else {
                    for i in range(n) {
                        (b + (n - i - 1)).view(1)[0] = ssize_t_byte(cv, i);
                    }
                }

                if _fits_in_n_bits(cv, n * 8) {
                    res = n;
                } elif cv > 0 and _fits_in_n_bits(cv, n * 8 + 1) {
                    if flags == -1 or (flags & Py_ASNATIVEBYTES_UNSIGNED_BUFFER) != 0 {
                        res = n;
                    } else {
                        res = n + 1;
                    }
                }
            } elif n > SIZEOF_PY_SSIZE_T {
                fill = u8(255) if cv < 0 else u8(0);
                if little_endian != 0 {
                    for i in range(SIZEOF_PY_SSIZE_T) {
                        (b + i).view(1)[0] = ssize_t_byte(cv, i);
                    }
                    memset(
                        ptr(b + SIZEOF_PY_SSIZE_T),
                        i32(fill),
                        u64(n - SIZEOF_PY_SSIZE_T)
                    );
                } else {
                    for i in range(n - SIZEOF_PY_SSIZE_T) {
                        (b + i).view(1)[0] = fill;
                    }
                    pos = n - SIZEOF_PY_SSIZE_T;
                    k = SIZEOF_PY_SSIZE_T;
                    while k > 0 {
                        (b + pos).view(1)[0] = ssize_t_byte(cv, k - 1);
                        pos += 1;
                        k -= 1;
                    }
                }
            }
        } else {
            if n > 0 {
                _PyLong_AsByteArray(as_object(v), b, u64(n), little_endian, 1, 0);
            }
            nb = _PyLong_NumBits(as_object(v));
            res = nb // 8 + 1;
            if n > 0 and res == n + 1 and nb % 8 == 0 {
                if long_is_negative(v) {
                    is_edge_case = True;
                    j: i64 = 0;
                    while j < n and is_edge_case {
                        c = (b + j).view(1)[0];
                        if j == 0 {
                            is_edge_case = c
                                == (u8(0) if little_endian != 0 else u8(128));
                        } elif j < n - 1 {
                            is_edge_case = c == u8(0);
                        } else {
                            is_edge_case = c
                                == (u8(128) if little_endian != 0 else u8(0));
                        }
                        j += 1;
                    }
                    if is_edge_case {
                        res = n;
                    }
                } else {
                    top: i64 = n - 1 if little_endian != 0 else 0;
                    if ((b + top).view(1)[0] & u8(128)) != u8(0) {
                        if flags == -1
                            or (flags & Py_ASNATIVEBYTES_UNSIGNED_BUFFER) != 0 {
                            res = n;
                        } else {
                            res = n + 1;
                        }
                    }
                }
            }
        }
        if do_decref {
            object_decref(as_object(v));
        }
        return res;
    }  def PyLong_FromNativeBytes(buffer: ptr, n: u64, flags: i32) -> ptr[PyObject] {
        if not buffer {
            PyErr_BadInternalCall();
            return NULL;
        }
        (status, little_endian) = _resolve_endianness(flags);
        if status < 0 {
            return NULL;
        }
        is_signed = i32(1)
            if flags == -1 or (flags & Py_ASNATIVEBYTES_UNSIGNED_BUFFER) == 0
            else i32(0);
        return _PyLong_FromByteArray(ptr[u8](buffer), n, little_endian, is_signed);
    }  def PyLong_FromUnsignedNativeBytes(
        buffer: ptr, n: u64, flags: i32
    ) -> ptr[PyObject] {
        if not buffer {
            PyErr_BadInternalCall();
            return NULL;
        }
        (status, little_endian) = _resolve_endianness(flags);
        if status < 0 {
            return NULL;
        }
        return _PyLong_FromByteArray(ptr[u8](buffer), n, little_endian, i32(0));
    }  def PyLong_FromVoidPtr(p: ptr) -> ptr[PyObject] {
        return PyLong_FromUnsignedLong(u64.wrap(int(p)));
    }  def PyLong_AsVoidPtr(vv: ptr[PyObject]) -> ptr {
        x: i64 = 0;
        if long_check(vv) and long_is_negative(long_of(vv)) {
            x = PyLong_AsLong(vv);
        } else {
            x = i64.wrap(PyLong_AsUnsignedLong(vv));
        }
        if x == -1 and PyErr_Occurred() {
            return ptr();
        }
        return ptr(x);
    }  def PyLong_FromLongLong(ival: i64) -> ptr[PyObject] {
        return long_from_int(ival);
    }  def PyLong_FromSsize_t(ival: i64) -> ptr[PyObject] {
        return long_from_int(ival);
    }  def PyLong_AsLongLong(vv: ptr[PyObject]) -> i64 {
        v = ptr[PyLongObject]();
        bytes_value: i64 = 0;
        res = i32(0);

        do_decref = False;
        if not vv {
            PyErr_BadInternalCall();
            return -1;
        }
        if long_check(vv) {
            v = long_of(vv);
        } else {
            v = long_of(_PyNumber_Index(vv));
            if not v {
                return -1;
            }
            do_decref = True;
        }
        if long_is_compact(v) {
            res = i32(0);
            bytes_value = compact_value(v);
        } else {
            slot = ptr[i64](PyMem_Calloc(1, 8));
            if not slot {
                if do_decref {
                    object_decref(as_object(v));
                }
                PyErr_NoMemory();
                return -1;
            }
            res = _PyLong_AsByteArray(
                as_object(v),
                ptr[u8](slot),
                u64(SIZEOF_LONG_LONG),
                PY_LITTLE_ENDIAN,
                1,
                1
            );
            bytes_value = slot.view(1)[0];
            PyMem_Free(ptr(slot));
        }
        if do_decref {
            object_decref(as_object(v));
        }
        if res < i32(0) {
            return -1;
        }
        return bytes_value;
    }  def PyLong_AsUnsignedLongLong(vv: ptr[PyObject]) -> u64 {
        bytes_value = u64(0);
        res = i32(0);
        if not vv {
            PyErr_BadInternalCall();
            return ~u64(0);
        }
        if not long_check(vv) {
            PyErr_SetString(PyExc_TypeError, "an integer is required");
            return ~u64(0);
        }
        v = long_of(vv);
        if long_is_nonnegative_compact(v) {
            res = i32(0);
            bytes_value = u64(compact_value(v));
        } else {
            slot = ptr[u64](PyMem_Calloc(1, 8));
            if not slot {
                PyErr_NoMemory();
                return ~u64(0);
            }
            res = _PyLong_AsByteArray(
                vv, ptr[u8](slot), u64(SIZEOF_LONG_LONG), PY_LITTLE_ENDIAN, 0, 1
            );
            bytes_value = slot.view(1)[0];
            PyMem_Free(ptr(slot));
        }
        if res < i32(0) {
            return u64.wrap(i64(res));
        }
        return bytes_value;
    }
}

def _PyLong_AsUnsignedLongLongMask(vv: ptr[PyObject]) -> u64;

def long_as_long_long_and_overflow(vv: ptr[PyObject]) -> tuple[i64, i32];

import from c {
    def PyLong_AsUnsignedLongLongMask(op: ptr[PyObject]) -> u64 {
        if not op {
            PyErr_BadInternalCall();
            return ~u64(0);
        }
        if long_check(op) {
            return _PyLong_AsUnsignedLongLongMask(op);
        }
        lo = _PyNumber_Index(op);
        if not lo {
            return ~u64(0);
        }
        val = _PyLong_AsUnsignedLongLongMask(lo);
        object_decref(lo);
        return val;
    }  def PyLong_AsLongLongAndOverflow(vv: ptr[PyObject], overflow: ptr[i32]) -> i64 {
        (res, ovf) = long_as_long_long_and_overflow(vv);
        overflow.view(1)[0] = ovf;
        return res;
    }  def _PyLong_UnsignedShort_Converter(obj_: ptr[PyObject], ptr_: ptr[u16]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 2, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 2 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large for C unsigned short"
            );
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UnsignedInt_Converter(obj_: ptr[PyObject], ptr_: ptr[u32]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 4, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 4 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large for C unsigned int"
            );
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UnsignedLong_Converter(obj_: ptr[PyObject], ptr_: ptr) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr_, 8, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 8 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large for C unsigned long"
            );
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UnsignedLongLong_Converter(obj_: ptr[PyObject], ptr_: ptr) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr_, 8, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 8 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large for C unsigned long long"
            );
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_Size_t_Converter(obj_: ptr[PyObject], ptr_: ptr) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr_, 8, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 8 {
            PyErr_SetString(PyExc_OverflowError, "Python int too large for C size_t");
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UInt8_Converter(obj_: ptr[PyObject], ptr_: ptr[u8]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 1, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 1 {
            PyErr_SetString(PyExc_OverflowError, "Python int too large for C uint8_t");
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UInt16_Converter(obj_: ptr[PyObject], ptr_: ptr[u16]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 2, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 2 {
            PyErr_SetString(PyExc_OverflowError, "Python int too large for C uint16_t");
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UInt32_Converter(obj_: ptr[PyObject], ptr_: ptr[u32]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 4, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 4 {
            PyErr_SetString(PyExc_OverflowError, "Python int too large for C uint32_t");
            return i32(0);
        }
        return i32(1);
    }  def _PyLong_UInt64_Converter(obj_: ptr[PyObject], ptr_: ptr[u64]) -> i32 {
        nbytes = PyLong_AsNativeBytes(obj_, ptr(ptr_), 8, UNSIGNED_CONVERTER_FLAGS);
        if nbytes < 0 {
            return i32(0);
        }
        if nbytes > 8 {
            PyErr_SetString(PyExc_OverflowError, "Python int too large for C uint64_t");
            return i32(0);
        }
        return i32(1);
    }
}

def v_iadd(x: ptr[u32], m: i64, y: ptr[u32], n: i64) -> u32;

def v_isub(x: ptr[u32], m: i64, y: ptr[u32], n: i64) -> u32;

def v_lshift(z: ptr[u32], a: ptr[u32], m: i64, d: i64) -> u32;

def v_rshift(z: ptr[u32], a: ptr[u32], m: i64, d: i64) -> u32;

def inplace_divrem1(pout: ptr[u32], pin: ptr[u32], size: i64, n: u32) -> u32;

def divrem1(a: ptr[PyLongObject], n: u32) -> tuple[ptr[PyLongObject], u32];

def inplace_rem1(pin: ptr[u32], size: i64, n: u32) -> u32;

def rem1(a: ptr[PyLongObject], n: u32) -> ptr[PyLongObject];

glob:priv PyUnicode_1BYTE_KIND: i64 = 1,
     PyUnicode_2BYTE_KIND: i64 = 2;

def writer_buffer(writer: ptr[_PyUnicodeWriter]) -> ptr[PyObject];

def writer_kind(writer: ptr[_PyUnicodeWriter]) -> i64;

def writer_maxchar(writer: ptr[_PyUnicodeWriter]) -> u32;

def writer_size(writer: ptr[_PyUnicodeWriter]) -> i64;

def writer_pos(writer: ptr[_PyUnicodeWriter]) -> i64;

def set_writer_pos(writer: ptr[_PyUnicodeWriter], pos: i64);

def unicode_writer_prepare(
    writer: ptr[_PyUnicodeWriter], length: i64, maxchar: u32
) -> i32;

def unicode_read(kind: i64, data: ptr[u8], i: i64) -> u32;

def unicode_put(data: ptr[u8], kind: i64, i: i64, ch: u32);

def pylong_int_to_decimal_string(
    aa: ptr[PyObject],
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]];

def write_decimal_digits(
    data: ptr[u8], kind: i64, end: i64, pout: ptr[u32], size: i64, negative: i64
) -> i64;

def long_to_decimal_string_internal(
    aa: ptr[PyObject],
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]];

def long_to_decimal_string(aa: ptr[PyObject]) -> ptr[PyObject];

def write_binary_digits(
    data: ptr[u8],
    kind: i64,
    end: i64,
    a: ptr[PyLongObject],
    size_a: i64,
    base: i32,
    bits: i64,
    alternate: i32,
    negative: i64
) -> i64;

def long_format_binary(
    aa: ptr[PyObject],
    base: i32,
    alternate: i32,
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]];

import from c {
    def _PyLong_Format(ob: ptr[PyObject], base: i32) -> ptr[PyObject] {
        if base == i32(10) {
            (err, text, unused) = long_to_decimal_string_internal(
                ob, ptr[_PyUnicodeWriter](), ptr[_PyBytesWriter](), ptr[u8]()
            );
            if err == i32(-1) {
                return NULL;
            }
            return text;
        }
        (berr, btext, bunused) = long_format_binary(
            ob, base, i32(1), ptr[_PyUnicodeWriter](), ptr[_PyBytesWriter](), ptr[u8]()
        );
        if berr == i32(-1) {
            return NULL;
        }
        return btext;
    }  def _PyLong_FormatWriter(
        writer: ptr[_PyUnicodeWriter], ob: ptr[PyObject], base: i32, alternate: i32
    ) -> i32 {
        if base == i32(10) {
            (err, text, unused) = long_to_decimal_string_internal(
                ob, writer, ptr[_PyBytesWriter](), ptr[u8]()
            );
            return err;
        }
        (berr, btext, bunused) = long_format_binary(
            ob, base, alternate, writer, ptr[_PyBytesWriter](), ptr[u8]()
        );
        return berr;
    }  def _PyLong_FormatBytesWriter(
        writer: ptr[_PyBytesWriter],
        s: ptr[u8],
        ob: ptr[PyObject],
        base: i32,
        alternate: i32
    ) -> ptr[u8] {
        if base == i32(10) {
            (res, text, str2) = long_to_decimal_string_internal(
                ob, ptr[_PyUnicodeWriter](), writer, s
            );
            if res < i32(0) {
                return ptr[u8]();
            }
            return str2;
        }
        (bres, btext, bstr2) = long_format_binary(
            ob, base, alternate, ptr[_PyUnicodeWriter](), writer, s
        );
        if bres < i32(0) {
            return ptr[u8]();
        }
        return bstr2;
    }
}

def is_space(c: u8) -> bool;

def digit_value(c: u8) -> i64;

def long_from_binary_base(
    start: ptr[u8], end: ptr[u8], digits: i64, base: i64
) -> tuple[i32, ptr[PyLongObject]];

def pylong_int_from_string(
    start: ptr[u8], end: ptr[u8]
) -> tuple[i32, ptr[PyLongObject]];

import from c {
    glob:priv log_base_BASE: list[f64] = [
             0.0,
             0.0,
             0.0,
             0.05283208335737188,
             0.0,
             0.07739760316291208,
             0.08616541669070521,
             0.09357849740192013,
             0.0,
             0.10566416671474375,
             0.11073093649624542,
             0.11531438728790992,
             0.11949875002403855,
             0.12334799060470308,
             0.12691183073525347,
             0.13022968652028397,
             0.0,
             0.13624876137501132,
             0.13899750004807707,
             0.14159758378145285,
             0.14406426982957873,
             0.14641058075929203,
             0.14864772062124326,
             0.15078539853523376,
             0.1528320833573719,
             0.15479520632582416,
             0.1566813239380364,
             0.15849625007211562,
             0.1602451640685868,
             0.16193269983758574,
             0.1635630198536173,
             0.16513987701289584,
             0.0,
             0.1681464706452818,
             0.16958209470834465,
             0.17097610056483223,
             0.17233083338141042
         ],
         convwidth_base: list[i32] = [
             i32(0),
             i32(0),
             i32(0),
             i32(18),
             i32(0),
             i32(12),
             i32(11),
             i32(10),
             i32(0),
             i32(9),
             i32(9),
             i32(8),
             i32(8),
             i32(8),
             i32(7),
             i32(7),
             i32(0),
             i32(7),
             i32(7),
             i32(7),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(6),
             i32(0),
             i32(5),
             i32(5),
             i32(5),
             i32(5)
         ],
         convmultmax_base: list[u64] = [
             u64(0),
             u64(0),
             u64(0),
             u64(387420489),
             u64(0),
             u64(244140625),
             u64(362797056),
             u64(282475249),
             u64(0),
             u64(387420489),
             u64(1000000000),
             u64(214358881),
             u64(429981696),
             u64(815730721),
             u64(105413504),
             u64(170859375),
             u64(0),
             u64(410338673),
             u64(612220032),
             u64(893871739),
             u64(64000000),
             u64(85766121),
             u64(113379904),
             u64(148035889),
             u64(191102976),
             u64(244140625),
             u64(308915776),
             u64(387420489),
             u64(481890304),
             u64(594823321),
             u64(729000000),
             u64(887503681),
             u64(0),
             u64(39135393),
             u64(45435424),
             u64(52521875),
             u64(60466176)
         ];
}

def long_from_non_binary_base(
    start: ptr[u8], end: ptr[u8], digits: i64, base: i64
) -> tuple[i32, ptr[PyLongObject]];

def long_from_string_base(
    s: ptr[u8], base: i64
) -> tuple[i32, ptr[u8], ptr[PyLongObject]];

def invalid_int_literal(orig_str: ptr[u8], base: i64) -> ptr[PyObject];

def long_from_string(orig_str: ptr[u8], base_in: i64) -> tuple[ptr[PyObject], ptr[u8]];

import from c {
    def PyLong_FromString(s: ptr[u8], pend: ptr[ptr[u8]], base: i32) -> ptr[PyObject] {
        (result, stop) = long_from_string(s, i64(base));
        if pend and stop != ptr[u8]() {
            pend.view(1)[0] = stop;
        }
        return result;
    }  def _PyLong_FromBytes(s: ptr[u8], length: i64, base: i32) -> ptr[PyObject] {
        (result, end) = long_from_string(s, i64(base));
        if not end or (result != NULL and end == s + length) {
            return result;
        }
        object_xdecref(result);
        shown: i64 = min(length, 200);
        strobj = PyBytes_FromStringAndSize(s, shown);
        if strobj {
            PyErr_Format(
                PyExc_ValueError,
                "invalid literal for int() with base %d: %.200R",
                base,
                strobj
            );
            object_decref(strobj);
        }
        return NULL;
    }  def PyLong_FromUnicodeObject(u: ptr[PyObject], base: i32) -> ptr[PyObject] {
        asciidig = _PyUnicode_TransformDecimalAndSpaceToASCII(u);
        if not asciidig {
            return NULL;
        }

        buflen: i64 = 0;
        buffer = PyUnicode_AsUTF8AndSize(asciidig, &mut buflen);
        (result, end) = long_from_string(buffer, i64(base));
        if not end or (result != NULL and end == buffer + buflen) {
            object_decref(asciidig);
            return result;
        }
        object_decref(asciidig);
        object_xdecref(result);
        PyErr_Format(
            PyExc_ValueError, "invalid literal for int() with base %d: %.200R", base, u
        );
        return NULL;
    }
}

def long_divrem(
    a: ptr[PyLongObject], b: ptr[PyLongObject]
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]];

def long_rem(
    a: ptr[PyLongObject], b: ptr[PyLongObject]
) -> tuple[i32, ptr[PyLongObject]];

glob:priv DBL_MANT_DIG: i64 = 53,
     DBL_MAX_EXP: i64 = 1024,
     EXP2_DBL_MANT_DIG: f64 = 9007199254740992.0,
     _PyHASH_BITS: i64 = 61,
     _PyHASH_MODULUS: u64 = u64(0x1FFFFFFFFFFFFFFF),
     HALF_EVEN_CORRECTION: list[i64] = [0, -1, -2, 1, 0, -1, 2, 1];

import from c { glob:priv frexp_digits: list[u32] = [u32(0), u32(0), u32(0)]; }

def x_divrem(
    v1: ptr[PyLongObject], w1: ptr[PyLongObject]
) -> tuple[ptr[PyLongObject], ptr[PyLongObject]];

def long_frexp(a: ptr[PyLongObject]) -> tuple[f64, i64];

import from c {
    def _PyLong_Frexp(a: ptr[PyObject], e: ptr[i64]) -> f64 {
        (x, exponent) = long_frexp(long_of(a));
        e.view(1)[0] = exponent;
        return x;
    }  def PyLong_AsDouble(v: ptr[PyObject]) -> f64 {
        if not v {
            PyErr_BadInternalCall();
            return -1.0;
        }
        if not long_check(v) {
            PyErr_SetString(PyExc_TypeError, "an integer is required");
            return -1.0;
        }
        if long_is_compact(long_of(v)) {
            return f64(compact_value(long_of(v)));
        }
        (x, exponent) = long_frexp(long_of(v));
        if exponent > DBL_MAX_EXP {
            PyErr_SetString(PyExc_OverflowError, "int too large to convert to float");
            return -1.0;
        }
        return ldexp(x, i32(exponent));
    }
}

def long_compare(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> i64;

def long_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

import from c {
    def _PyLong_ExactDealloc(self_: ptr[PyObject]) {
        if long_is_small_int(long_of(self_)) {
            _Py_SetImmortal(self_);
            return;
        }
        if long_is_compact(long_of(self_)) {
            if not freelist_push(_Py_freelists_INTS, self_, Py_ints_MAXFREELIST) {
                PyObject_Free(ptr(self_));
            }
            return;
        }
        PyObject_Free(ptr(self_));
    }
}

def long_dealloc(self_: ptr[PyObject]);

def long_hash(obj_: ptr[PyObject]) -> i64;

def x_add(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject];

def x_sub(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_add(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject];

import from c {
    def _PyLong_Add(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
        return as_object(long_add(a, b));
    }
}

def long_add_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_sub(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject];

import from c {
    def _PyLong_Subtract(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
        return as_object(long_sub(a, b));
    }
}

def long_sub_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def x_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject];

glob:priv DBL_MIN_EXP: i64 = -1021,
     MANT_DIG_DIGITS: i64 = 1,
     MANT_DIG_BITS: i64 = 23;

def kmul_split(
    n: ptr[PyLongObject], size: i64
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]];

def k_mul_fail(
    ret: ptr[PyLongObject],
    ah: ptr[PyLongObject],
    al: ptr[PyLongObject],
    bh: ptr[PyLongObject],
    bl: ptr[PyLongObject]
) -> ptr[PyLongObject];

def k_mul(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject];

def k_lopsided_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject];

import from c {
    def _PyLong_Multiply(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
        return as_object(long_mul(a, b));
    }
}

def long_mul_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def fast_mod(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject];

def fast_floor_div(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject];

def pylong_int_divmod(
    v: ptr[PyLongObject], w: ptr[PyLongObject], want_div: bool, want_mod: bool
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]];

def l_divmod(
    v: ptr[PyLongObject], w: ptr[PyLongObject], want_div: bool, want_mod: bool
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]];

def l_mod(v: ptr[PyLongObject], w: ptr[PyLongObject]) -> tuple[i32, ptr[PyLongObject]];

def long_div(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def true_divide_zero(negate: bool) -> ptr[PyObject];

def true_divide_overflow -> ptr[PyObject];

def long_true_divide(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def long_mod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_divmod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def invmod_fail(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    n: ptr[PyLongObject]
) -> ptr[PyLongObject];

def long_invmod(a_in: ptr[PyLongObject], n_in: ptr[PyLongObject]) -> ptr[PyLongObject];

def pow_reduce(x: ptr[PyLongObject], c: ptr[PyLongObject]) -> ptr[PyLongObject];

def pow_mult(
    x: ptr[PyLongObject],
    y: ptr[PyLongObject],
    result: ptr[PyLongObject],
    c: ptr[PyLongObject]
) -> ptr[PyLongObject];

def pow_done(
    z: ptr[PyLongObject],
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject]
) -> ptr[PyObject];

def pow_binary(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    z_in: ptr[PyLongObject],
    i_in: i64,
    bi_in: u32
) -> ptr[PyLongObject];

def pow_absorb(
    z_in: ptr[PyLongObject],
    table: ptr[ptr[PyLongObject]],
    pending_in: i64,
    blen_in: i64,
    c: ptr[PyLongObject]
) -> ptr[PyLongObject];

def pow_kary_exit(
    z: ptr[PyLongObject], table: ptr[ptr[PyLongObject]], n: i64, a2: ptr[PyLongObject]
) -> ptr[PyLongObject];

def pow_kary(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    z_in: ptr[PyLongObject]
) -> ptr[PyLongObject];

def long_pow(v: ptr[PyObject], w: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def long_invert(self_: ptr[PyObject]) -> ptr[PyObject];

def long_neg(v: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_neg_method(v: ptr[PyObject]) -> ptr[PyObject];

def long_abs(v: ptr[PyLongObject]) -> ptr[PyLongObject];

def long_abs_method(v: ptr[PyObject]) -> ptr[PyObject];

def long_bool(v: ptr[PyObject]) -> i32;

def long_rshift1(
    a: ptr[PyLongObject], wordshift_in: i64, remshift_in: u32
) -> ptr[PyObject];

def long_rshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_lshift1(a: ptr[PyLongObject], wordshift: i64, remshift: u32) -> ptr[PyObject];

def long_lshift_method(aa: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject];

def long_lshift_int64(a: ptr[PyLongObject], shiftby: i64) -> ptr[PyObject];

import from c {
    def _PyLong_Rshift(a: ptr[PyObject], shiftby: i64) -> ptr[PyObject] {
        if long_is_zero(long_of(a)) {
            return PyLong_FromLong(0);
        }

        wordshift = shiftby // PyLong_SHIFT;
        remshift = u32(shiftby % PyLong_SHIFT);
        return long_rshift1(long_of(a), wordshift, remshift);
    }  def _PyLong_Lshift(a: ptr[PyObject], shiftby: i64) -> ptr[PyObject] {
        return long_lshift_int64(long_of(a), shiftby);
    }
}

def v_complement(z: ptr[u32], a: ptr[u32], m: i64);

def long_bitwise(
    a_in: ptr[PyLongObject], op: u8, b_in: ptr[PyLongObject]
) -> ptr[PyObject];

def long_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_long(v: ptr[PyObject]) -> ptr[PyObject];

def gcd_simple(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject];

def gcd_error(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    d: ptr[PyLongObject]
) -> ptr[PyObject];

import from c {
    def _PyLong_GCD(aarg: ptr[PyObject], barg: ptr[PyObject]) -> ptr[PyObject] {
        a = long_of(aarg);
        b = long_of(barg);
        c = ptr[PyLongObject]();
        d = ptr[PyLongObject]();
        if digit_count(a) <= 2 and digit_count(b) <= 2 {
            object_incref(as_object(a));
            object_incref(as_object(b));
            return gcd_simple(a, b);
        }

        a = long_abs(a);
        if not a {
            return NULL;
        }
        b = long_abs(b);
        if not b {
            object_decref(as_object(a));
            return NULL;
        }
        if long_compare(a, b) < 0 {
            r = a;
            a = b;
            b = r;
        }

        alloc_a = digit_count(a);
        alloc_b = digit_count(b);

        while digit_count(a) > 2 {
            size_a = digit_count(a);
            nbits = bit_length_digit(digit_at(a, size_a - 1));

            size_b = digit_count(b);
            if size_b == 0 {
                r = a;
                if size_a < alloc_a {
                    r = long_of(_PyLong_Copy(a));
                    object_decref(as_object(a));
                }
                object_decref(as_object(b));
                object_xdecref(as_object(c));
                object_xdecref(as_object(d));
                return as_object(r);
            }

            x_bits = (u64(digit_at(a, size_a - 1)) << u64(2 * PyLong_SHIFT - nbits))
                | (u64(digit_at(a, size_a - 2)) << u64(PyLong_SHIFT - nbits))
                | u64(digit_at(a, size_a - 3) >> u32(nbits));
            y_bits = u64(0);
            if size_b >= size_a - 2 {
                y_bits = y_bits | u64(digit_at(b, size_a - 3) >> u32(nbits));
            }
            if size_b >= size_a - 1 {
                y_bits = y_bits
                    | (u64(digit_at(b, size_a - 2)) << u64(PyLong_SHIFT - nbits));
            }
            if size_b >= size_a {
                y_bits = y_bits
                    | (u64(digit_at(b, size_a - 1)) << u64(2 * PyLong_SHIFT - nbits));
            }
            x = i64(x_bits);
            y = i64(y_bits);

            A: i64 = 1;
            B: i64 = 0;
            C: i64 = 0;
            D: i64 = 1;
            k: i64 = 0;
            while True {
                if y - C == 0 {
                    break;
                }
                q = (x + (A - 1)) // (y - C);
                s = B + q * D;
                t = x - q * y;
                if s > t {
                    break;
                }
                x = y;
                y = t;
                t = A + q * C;
                A = D;
                B = C;
                C = s;
                D = t;
                k += 1;
            }
            if k == 0 {
                (status, r) = l_mod(a, b);
                if status < 0 {
                    return gcd_error(a, b, c, d);
                }
                object_decref(as_object(a));
                a = b;
                b = r;
                alloc_a = alloc_b;
                alloc_b = digit_count(b);
                continue;
            }

            if (k & 1) != 0 {
                T = -A;
                A = -B;
                B = T;
                T = -C;
                C = -D;
                D = T;
            }
            if c {
                set_sign_and_digit_count(c, 1, size_a);
            } elif object_is_uniquely_referenced(as_object(a)) {
                c = long_of(object_new_ref(as_object(a)));
            } else {
                alloc_a = size_a;
                c = long_alloc(size_a);
                if not c {
                    return gcd_error(a, b, c, d);
                }
            }
            if d {
                set_sign_and_digit_count(d, 1, size_a);
            } elif object_is_uniquely_referenced(as_object(b)) and size_a <= alloc_b {
                d = long_of(object_new_ref(as_object(b)));
                set_sign_and_digit_count(d, 1, size_a);
            } else {
                alloc_b = size_a;
                d = long_alloc(size_a);
                if not d {
                    return gcd_error(a, b, c, d);
                }
            }

            a_digit = ob_digits(a);
            b_digit = ob_digits(b);
            c_digit = ob_digits(c);
            d_digit = ob_digits(d);
            c_carry: i64 = 0;
            d_carry: i64 = 0;
            for n in range(size_b) {
                ad = i64(dget(a_digit, n));
                bd = i64(dget(b_digit, n));
                c_carry += (A * ad) - (B * bd);
                d_carry += (D * bd) - (C * ad);
                dset(c_digit, n, u32(c_carry & PyLong_MASK_SIGNED));
                dset(d_digit, n, u32(d_carry & PyLong_MASK_SIGNED));
                c_carry = c_carry >> PyLong_SHIFT;
                d_carry = d_carry >> PyLong_SHIFT;
            }
            for n in range(size_b, size_a) {
                ad = i64(dget(a_digit, n));
                c_carry += A * ad;
                d_carry -= C * ad;
                dset(c_digit, n, u32(c_carry & PyLong_MASK_SIGNED));
                dset(d_digit, n, u32(d_carry & PyLong_MASK_SIGNED));
                c_carry = c_carry >> PyLong_SHIFT;
                d_carry = d_carry >> PyLong_SHIFT;
            }
            object_incref(as_object(c));
            object_incref(as_object(d));
            object_decref(as_object(a));
            object_decref(as_object(b));
            a = long_normalize(c);
            b = long_normalize(d);
        }
        object_xdecref(as_object(c));
        object_xdecref(as_object(d));
        return gcd_simple(a, b);
    }
}

def long_float(v: ptr[PyObject]) -> ptr[PyObject];

glob:priv long_new_signature = CallSignature(
         "int", ["", "base"], 0, 2, 1, parser=PARSE_KEYWORDS
     ),
     int_to_bytes_signature = CallSignature(
         "to_bytes", ["length", "byteorder", "signed"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     int_from_bytes_signature = CallSignature(
         "from_bytes", ["bytes", "byteorder", "signed"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def long_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], obase: ptr[PyObject]
) -> ptr[PyObject];

def long_subtype_new(
    type: ptr[PyTypeObject], x: ptr[PyObject], obase: ptr[PyObject]
) -> ptr[PyObject];

def long_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def long_new_bound(args: BoundArguments) -> ptr[PyObject];

def int___getnewargs__(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def long_get0(_self: ptr[PyObject], _context: ptr) -> ptr[PyObject];

def long_get1(_self: ptr[PyObject], _ignored: ptr) -> ptr[PyObject];

def int___format__(self_: ptr[PyObject], format_spec: ptr[PyObject]) -> ptr[PyObject];

def divmod_near_fail(quo: ptr[PyLongObject], rem: ptr[PyLongObject]) -> ptr[PyObject];

import from c {
    def _PyLong_DivmodNear(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
        if not long_check(a) or not long_check(b) {
            PyErr_SetString(PyExc_TypeError, "non-integer arguments in division");
            return NULL;
        }

        quo_is_neg = long_is_negative(long_of(a)) != long_is_negative(long_of(b));
        (status, quo, rem) = long_divrem(long_of(a), long_of(b));
        if status < i32(0) {
            return divmod_near_fail(quo, rem);
        }

        twice_rem = long_lshift_int64(rem, 1);
        if not twice_rem {
            return divmod_near_fail(quo, rem);
        }
        if quo_is_neg {
            temp = as_object(long_neg(long_of(twice_rem)));
            object_decref(twice_rem);
            twice_rem = temp;
            if not twice_rem {
                return divmod_near_fail(quo, rem);
            }
        }
        cmp = long_compare(long_of(twice_rem), long_of(b));
        object_decref(twice_rem);
        quo_is_odd = (digit_at(quo, 0) & u32(1)) != u32(0);
        greater_than_half = cmp < 0 if long_is_negative(long_of(b)) else cmp > 0;
        if greater_than_half or (cmp == 0 and quo_is_odd) {
            one = long_of(long_one());
            fixed = ptr[PyLongObject]();
            if quo_is_neg {
                fixed = long_sub(quo, one);
            } else {
                fixed = long_add(quo, one);
            }
            object_decref(as_object(quo));
            quo = fixed;
            if not quo {
                return divmod_near_fail(quo, rem);
            }

            if quo_is_neg {
                fixed = long_add(rem, long_of(b));
            } else {
                fixed = long_sub(rem, long_of(b));
            }
            object_decref(as_object(rem));
            rem = fixed;
            if not rem {
                return divmod_near_fail(quo, rem);
            }
        }
        result = PyTuple_New(2);
        if not result {
            return divmod_near_fail(quo, rem);
        }

        tuple_set_item(result, 0, as_object(quo));
        tuple_set_item(result, 1, as_object(rem));
        return result;
    }
}

def int___round___impl(
    self_: ptr[PyObject], o_ndigits: ptr[PyObject]
) -> ptr[PyObject];

def int___round__(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def int___sizeof___impl(self_: ptr[PyObject]) -> i64;

def int___sizeof__(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def int_bit_length(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def popcount_digit(d: u32) -> i32;

def int_bit_count(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def int_as_integer_ratio(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def byteorder_little_endian(byteorder: ptr[PyObject]) -> i32;

def int_to_bytes_impl(
    self_: ptr[PyObject], length: i64, byteorder: ptr[PyObject], is_signed: i32
) -> ptr[PyObject];

def int_to_bytes_convert(
    self_: ptr[PyObject],
    length_arg: ptr[PyObject],
    byteorder_arg: ptr[PyObject],
    signed_arg: ptr[PyObject]
) -> ptr[PyObject];

def int_to_bytes(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def int_to_bytes_bound(args: BoundArguments) -> ptr[PyObject];

def int_from_bytes_impl(
    type: ptr[PyTypeObject],
    bytes_obj: ptr[PyObject],
    byteorder: ptr[PyObject],
    is_signed: i32
) -> ptr[PyObject];

def int_from_bytes_convert(
    type: ptr[PyObject],
    bytes_obj: ptr[PyObject],
    byteorder_arg: ptr[PyObject],
    signed_arg: ptr[PyObject]
) -> ptr[PyObject];

def int_from_bytes(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def int_from_bytes_bound(args: BoundArguments) -> ptr[PyObject];

def long_long_meth(self_: ptr[PyObject], _ignored: ptr[PyObject]) -> ptr[PyObject];

def long_long_getter(self_: ptr[PyObject], _ignored: ptr) -> ptr[PyObject];

def int_is_integer(_self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def long_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv long_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("conjugate"),
                 ml_meth=ptr(long_long_meth),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns self, the complex conjugate of any int.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("bit_length"),
                 ml_meth=ptr(int_bit_length),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "bit_length($self, /)\n--\n\n"
                     "Number of bits necessary to represent self in binary.\n\n"
                     ">>> bin(37)\n"
                     "'0b100101'\n"
                     ">>> (37).bit_length()\n"
                     "6"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("bit_count"),
                 ml_meth=ptr(int_bit_count),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "bit_count($self, /)\n--\n\n"
                     "Number of ones in the binary representation of the absolute value of self.\n\n"
                     "Also known as the population count.\n\n"
                     ">>> bin(13)\n"
                     "'0b1101'\n"
                     ">>> (13).bit_count()\n"
                     "3"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_bytes"),
                 ml_meth=ptr(int_to_bytes),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "to_bytes($self, /, length=1, byteorder='big', *, signed=False)\n--\n\n"
                     "Return an array of bytes representing an integer.\n\n"
                     "  length\n"
                     "    Length of bytes object to use.  An OverflowError is raised if\n"
                     "    the integer is not representable with the given number of bytes.\n"
                     "    Default is length 1.\n"
                     "  byteorder\n"
                     "    The byte order used to represent the integer.  If byteorder is\n"
                     "    'big', the most significant byte is at the beginning of the byte\n"
                     "    array.  If byteorder is 'little', the most significant byte is at\n"
                     "    the end of the byte array.  To request the native byte order of\n"
                     "    the host system, use sys.byteorder as the byte order value.\n"
                     "    Default is to use 'big'.\n"
                     "  signed\n"
                     "    Determines whether two's complement is used to represent the\n"
                     "    integer.  If signed is False and a negative integer is given,\n"
                     "    an OverflowError is raised."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("from_bytes"),
                 ml_meth=ptr(int_from_bytes),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8](
                     "from_bytes($type, /, bytes, byteorder='big', *, signed=False)\n--\n\n"
                     "Return the integer represented by the given array of bytes.\n\n"
                     "  bytes\n"
                     "    Holds the array of bytes to convert.  The argument must either\n"
                     "    support the buffer protocol or be an iterable object producing\n"
                     "    bytes.  Bytes and bytearray are examples of built-in objects that\n"
                     "    support the buffer protocol.\n"
                     "  byteorder\n"
                     "    The byte order used to represent the integer.  If byteorder is\n"
                     "    'big', the most significant byte is at the beginning of the byte\n"
                     "    array.  If byteorder is 'little', the most significant byte is at\n"
                     "    the end of the byte array.  To request the native byte order of\n"
                     "    the host system, use sys.byteorder as the byte order value.\n"
                     "    Default is to use 'big'.\n"
                     "  signed\n"
                     "    Indicates whether two's complement is used to represent the\n"
                     "    integer."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("as_integer_ratio"),
                 ml_meth=ptr(int_as_integer_ratio),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "as_integer_ratio($self, /)\n--\n\n"
                     "Return a pair of integers, whose ratio is equal to the original int.\n\n"
                     "The ratio is in lowest terms and has a positive denominator.\n\n"
                     ">>> (10).as_integer_ratio()\n"
                     "(10, 1)\n"
                     ">>> (-10).as_integer_ratio()\n"
                     "(-10, 1)\n"
                     ">>> (0).as_integer_ratio()\n"
                     "(0, 1)"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__trunc__"),
                 ml_meth=ptr(long_long_meth),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Truncating an Integral returns itself.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__floor__"),
                 ml_meth=ptr(long_long_meth),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Flooring an Integral returns itself.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__ceil__"),
                 ml_meth=ptr(long_long_meth),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Ceiling of an Integral returns itself.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__round__"),
                 ml_meth=ptr(int___round__),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__round__($self, ndigits=None, /)\n--\n\n"
                     "Rounding an Integral returns itself.\n\n"
                     "Rounding with an ndigits argument also returns an integer."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(int___getnewargs__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__getnewargs__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(int___format__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__format__($self, format_spec, /)\n--\n\n"
                     "Convert to a string according to format_spec."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(int___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\nReturns size in memory, in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_integer"),
                 ml_meth=ptr(int_is_integer),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_integer($self, /)\n--\n\n"
                     "Returns True. Exists for duck type compatibility with float.is_integer."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         long_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("real"),
                 get=long_long_getter,
                 doc=ptr[u8]("the real part of a complex number")
             ),
             PyGetSetDef(
                 name=ptr[u8]("imag"),
                 get=long_get0,
                 doc=ptr[u8]("the imaginary part of a complex number")
             ),
             PyGetSetDef(
                 name=ptr[u8]("numerator"),
                 get=long_long_getter,
                 doc=ptr[u8]("the numerator of a rational number in lowest terms")
             ),
             PyGetSetDef(
                 name=ptr[u8]("denominator"),
                 get=long_get1,
                 doc=ptr[u8]("the denominator of a rational number in lowest terms")
             ),
             PyGetSetDef()
         ],
         long_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=long_add_method,
             nb_subtract=long_sub_method,
             nb_multiply=long_mul_method,
             nb_remainder=long_mod,
             nb_divmod=long_divmod,
             nb_power=long_pow,
             nb_negative=long_neg_method,
             nb_positive=long_long,
             nb_absolute=long_abs_method,
             nb_bool=long_bool,
             nb_invert=long_invert,
             nb_lshift=long_lshift_method,
             nb_rshift=long_rshift,
             nb_and=long_and,
             nb_xor=long_xor,
             nb_or=long_or,
             nb_int=long_long,
             nb_float=long_float,
             nb_floor_divide=long_div,
             nb_true_divide=long_true_divide,
             nb_index=long_long
         ); glob PyLong_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("int"),
             tp_basicsize=PyLongObject_DIGIT,
             tp_itemsize=PyLong_DIGIT_SIZE,
             tp_dealloc=long_dealloc,
             tp_repr=long_to_decimal_string,
             tp_as_number=addressof(long_as_number),
             tp_hash=long_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_LONG_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF,
             tp_doc=ptr[u8](
                 "int([x]) -> integer\n"
                 "int(x, base=10) -> integer\n\n"
                 "Convert a number or string to an integer, or return 0 if no arguments\n"
                 "are given.  If x is a number, return x.__int__().  For floating-point\n"
                 "numbers, this truncates towards zero.\n\n"
                 "If x is not a number or if base is given, then x must be a string,\n"
                 "bytes, or bytearray instance representing an integer literal in the\n"
                 "given base.  The literal can be preceded by '+' or '-' and be surrounded\n"
                 "by whitespace.  The base defaults to 10.  Valid bases are 0 and 2-36.\n"
                 "Base 0 means to interpret the base from the string as an integer\n"
                 "iteral.\n"
                 ">>> int('0b100', base=0)\n"
                 "4"
             ),
             tp_richcompare=long_richcompare,
             tp_methods=addressof(long_methods),
             tp_getset=addressof(long_getset),
             tp_new=long_new,
             tp_free=PyObject_Free,
             tp_vectorcall=long_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_INT
         ); glob:priv Int_InfoType: PyTypeObject = PyTypeObject(),
         int_info_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("bits_per_digit"), doc=ptr[u8]("size of a digit in bits")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("sizeof_digit"),
                 doc=ptr[u8]("size in bytes of the C type used to represent a digit")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("default_max_str_digits"),
                 doc=ptr[u8]("maximum string conversion digits limitation")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("str_digits_check_threshold"),
                 doc=ptr[u8]("minimum positive value for int_max_str_digits")
             ),
             PyStructSequence_Field()
         ],
         int_info_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.int_info"),
             doc=ptr[u8](
                 "sys.int_info\n\n"
                 "A named tuple that holds information about Python's\n"
                 "internal representation of integers.  The attributes are read only."
             ),
             fields=addressof(int_info_fields),
             n_in_sequence=4
         ),
         PyLong_LAYOUT: PyLongLayout = PyLongLayout(
             bits_per_digit=u8(30),
             digit_size=u8(4),
             digits_order=i8(-1),
             digit_endianness=i8(-1)
         );
}

import from c {
    def PyLong_GetInfo -> ptr[PyObject] {
        int_info = PyStructSequence_New(ptr[PyObject](addressof(Int_InfoType)));
        if not int_info {
            return NULL;
        }
        tuple_set_item(int_info, 0, PyLong_FromLong(PyLong_SHIFT));
        tuple_set_item(int_info, 1, PyLong_FromLong(PyLong_DIGIT_SIZE));

        tuple_set_item(int_info, 2, PyLong_FromLong(_PY_LONG_DEFAULT_MAX_STR_DIGITS));
        tuple_set_item(int_info, 3, PyLong_FromLong(_PY_LONG_MAX_STR_DIGITS_THRESHOLD));
        if PyErr_Occurred() {
            object_decref(int_info);
            return NULL;
        }
        return int_info;
    }  def _PyLong_InitTypes(interp: ptr) -> PyStatus {
        if _PyStructSequence_InitBuiltinWithFlags(
            interp,
            ptr[PyObject](addressof(Int_InfoType)),
            addressof(int_info_desc),
            u64(0)
        )
            < 0 {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyLong_InitTypes"),
                err_msg=ptr[u8]("can't init int info type"),
                exitcode=0
            );
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def _PyLong_FiniTypes(interp: ptr) {
        _PyStructSequence_FiniBuiltin(interp, ptr[PyObject](addressof(Int_InfoType)));
    }  def PyUnstable_Long_IsCompact(op: ptr[PyLongObject]) -> i32 {
        return i32(1) if long_is_compact(op) else i32(0);
    }  def PyUnstable_Long_CompactValue(op: ptr[PyLongObject]) -> i64 {
        return compact_value(op);
    }  def PyLong_FromInt32(value: i32) -> ptr[PyObject] {
        return long_from_int(i64(value));
    }  def PyLong_FromUInt32(value: u32) -> ptr[PyObject] {
        return long_from_uint(u64(value));
    }  def PyLong_FromInt64(value: i64) -> ptr[PyObject] {
        return long_from_int(value);
    }  def PyLong_FromUInt64(value: u64) -> ptr[PyObject] {
        return long_from_uint(value);
    }  def PyLong_AsInt32(obj_: ptr[PyObject], value: ptr[i32]) -> i32 {
        flags = Py_ASNATIVEBYTES_NATIVE_ENDIAN | Py_ASNATIVEBYTES_ALLOW_INDEX;
        nbytes = PyLong_AsNativeBytes(obj_, ptr(value), 4, flags);
        if nbytes < 0 {
            return i32(-1);
        }

        if nbytes > 4 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C int32_t"
            );
            return i32(-1);
        }
        return i32(0);
    }  def PyLong_AsInt64(obj_: ptr[PyObject], value: ptr[i64]) -> i32 {
        flags = Py_ASNATIVEBYTES_NATIVE_ENDIAN | Py_ASNATIVEBYTES_ALLOW_INDEX;
        nbytes = PyLong_AsNativeBytes(obj_, ptr(value), 8, flags);
        if nbytes < 0 {
            return i32(-1);
        }
        if nbytes > 8 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C int64_t"
            );
            return i32(-1);
        }
        return i32(0);
    }  def PyLong_AsUInt32(obj_: ptr[PyObject], value: ptr[u32]) -> i32 {
        flags = Py_ASNATIVEBYTES_NATIVE_ENDIAN
            | Py_ASNATIVEBYTES_UNSIGNED_BUFFER
            | Py_ASNATIVEBYTES_REJECT_NEGATIVE
            | Py_ASNATIVEBYTES_ALLOW_INDEX;
        nbytes = PyLong_AsNativeBytes(obj_, ptr(value), 4, flags);
        if nbytes < 0 {
            return i32(-1);
        }
        if nbytes > 4 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C uint32_t"
            );
            return i32(-1);
        }
        return i32(0);
    }  def PyLong_AsUInt64(obj_: ptr[PyObject], value: ptr[u64]) -> i32 {
        flags = Py_ASNATIVEBYTES_NATIVE_ENDIAN
            | Py_ASNATIVEBYTES_UNSIGNED_BUFFER
            | Py_ASNATIVEBYTES_REJECT_NEGATIVE
            | Py_ASNATIVEBYTES_ALLOW_INDEX;
        nbytes = PyLong_AsNativeBytes(obj_, ptr(value), 8, flags);
        if nbytes < 0 {
            return i32(-1);
        }
        if nbytes > 8 {
            PyErr_SetString(
                PyExc_OverflowError, "Python int too large to convert to C uint64_t"
            );
            return i32(-1);
        }
        return i32(0);
    }  def PyLong_GetNativeLayout -> ptr[PyLongLayout] {
        return addressof(PyLong_LAYOUT);
    }  def PyLong_Export(obj_: ptr[PyObject], export_long: ptr[PyLongExport]) -> i32 {
        if not long_check(obj_) {
            memset(ptr(export_long), i32(0), u64(PyLongExport_SIZE));
            PyErr_Format(PyExc_TypeError, "expect int, got %T", obj_);
            return i32(-1);
        }

        (value, overflow) = long_as_long_and_overflow(obj_);
        if overflow == i32(0) {
            export_long.view(1)[0].value = value;
            export_long.view(1)[0].negative = u8(0);
            export_long.view(1)[0].ndigits = 0;
            export_long.view(1)[0].digits = ptr();
            export_long.view(1)[0]._reserved = u64(0);
        } else {
            self_ = long_of(obj_);
            export_long.view(1)[0].value = 0;
            export_long.view(1)[0].negative = u8(1)
                if long_is_negative(self_)
                else u8(0);
            ndigits = digit_count(self_);
            if ndigits == 0 {
                ndigits = 1;
            }
            export_long.view(1)[0].ndigits = ndigits;
            export_long.view(1)[0].digits = ptr(ob_digits(self_));
            export_long.view(1)[0]._reserved = u64.wrap(int(object_new_ref(obj_)));
        }
        return i32(0);
    }  def PyLong_FreeExport(export_long: ptr[PyLongExport]) {
        op = ptr[PyObject](i64.wrap(export_long.view(1)[0]._reserved));
        if op {
            export_long.view(1)[0]._reserved = u64(0);
            object_decref(op);
        }
    }  def PyLongWriter_Create(
        negative: i32, ndigits: i64, digits: ptr[ptr]
    ) -> ptr[PyLongWriter] {
        if ndigits <= 0 {
            PyErr_SetString(PyExc_ValueError, "ndigits must be positive");
            digits.view(1)[0] = ptr();
            return ptr[PyLongWriter]();
        }
        v = long_alloc(ndigits);
        if not v {
            digits.view(1)[0] = ptr();
            return ptr[PyLongWriter]();
        }
        if negative != i32(0) {
            flip_sign(v);
        }
        digits.view(1)[0] = ptr(ob_digits(v));
        return ptr[PyLongWriter](v);
    }  def PyLongWriter_Discard(writer: ptr[PyLongWriter]) {
        if not writer {
            return;
        }
        object_decref(ptr[PyObject](writer));
    }  def PyLongWriter_Finish(writer: ptr[PyLongWriter]) -> ptr[PyObject] {
        v = maybe_small_long(long_normalize(ptr[PyLongObject](writer)));
        return as_object(v);
    }
}

impl long_of(op: ptr[PyObject]) -> ptr[PyLongObject] {
    return ptr[PyLongObject](op);
}

impl as_object(v: ptr[PyLongObject]) -> ptr[PyObject] {
    return ptr[PyObject](v);
}

impl long_type -> ptr[PyTypeObject] {
    return addressof(PyLong_Type);
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl long_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, long_type());
}

impl long_tag(v: ptr[PyLongObject]) -> u64 {
    return v.view(1)[0].long_value.lv_tag;
}

impl set_long_tag(v: ptr[PyLongObject], tag: u64) {
    v.view(1)[0].long_value.lv_tag = tag;
}

impl ob_digits(v: ptr[PyLongObject]) -> ptr[u32] {
    return ptr[u32](ptr[u8](v) + PyLongObject_DIGIT);
}

impl digit_at(v: ptr[PyLongObject], i: i64) -> u32 {
    return (ob_digits(v) + i).view(1)[0];
}

impl set_digit(v: ptr[PyLongObject], i: i64, d: u32) {
    (ob_digits(v) + i).view(1)[0] = d;
}

impl dget(p: ptr[u32], i: i64) -> u32 {
    return (p + i).view(1)[0];
}

impl dset(p: ptr[u32], i: i64, d: u32) {
    (p + i).view(1)[0] = d;
}

impl long_is_compact(v: ptr[PyLongObject]) -> bool {
    return long_tag(v) < u64(16);
}

impl compact_value(v: ptr[PyLongObject]) -> i64 {
    sign = 1 - i64(long_tag(v) & SIGN_MASK);
    return sign * i64(digit_at(v, 0));
}

impl long_is_nonnegative_compact(v: ptr[PyLongObject]) -> bool {
    return (long_tag(v) & ~IMMORTALITY_BIT_MASK) <= u64(8);
}

impl both_compact(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> bool {
    return (long_tag(a) | long_tag(b)) < u64(16);
}

impl long_is_zero(v: ptr[PyLongObject]) -> bool {
    return (long_tag(v) & SIGN_MASK) == SIGN_ZERO;
}

impl long_is_negative(v: ptr[PyLongObject]) -> bool {
    return (long_tag(v) & SIGN_MASK) == SIGN_NEGATIVE;
}

impl long_is_positive(v: ptr[PyLongObject]) -> bool {
    return (long_tag(v) & SIGN_MASK) == u64(0);
}

impl long_is_small_int(v: ptr[PyLongObject]) -> bool {
    return (long_tag(v) & IMMORTALITY_BIT_MASK) != u64(0);
}

impl digit_count(v: ptr[PyLongObject]) -> i64 {
    return i64(long_tag(v) >> u64(NON_SIZE_BITS));
}

impl long_sign_of(v: ptr[PyLongObject]) -> i64 {
    return 1 - i64(long_tag(v) & SIGN_MASK);
}

impl signed_digit_count(v: ptr[PyLongObject]) -> i64 {
    return long_sign_of(v) * digit_count(v);
}

impl same_sign(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> bool {
    return (long_tag(a) & SIGN_MASK) == (long_tag(b) & SIGN_MASK);
}

impl tag_from_sign_and_size(sign: i64, size: i64) -> u64 {
    return u64(1 - sign) | (u64(size) << u64(NON_SIZE_BITS));
}

impl set_sign_and_digit_count(v: ptr[PyLongObject], sign: i64, size: i64) {
    set_long_tag(v, tag_from_sign_and_size(sign, size));
}

impl set_digit_count(v: ptr[PyLongObject], size: i64) {
    set_long_tag(v, (u64(size) << u64(NON_SIZE_BITS)) | (long_tag(v) & SIGN_MASK));
}

impl flip_sign(v: ptr[PyLongObject]) {
    flipped_sign = u64(2) - (long_tag(v) & SIGN_MASK);
    set_long_tag(v, (long_tag(v) & NON_SIZE_MASK) | flipped_sign);
}

impl is_small_int(ival: i64) -> bool {
    return -_PY_NSMALLNEGINTS <= ival and ival < _PY_NSMALLPOSINTS;
}

impl is_small_uint(ival: u64) -> bool {
    return ival < u64(_PY_NSMALLPOSINTS);
}

impl get_small_int(ival: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        int(addressof(_PyRuntime))
            + _PyRuntimeState_SMALL_INTS
            + (_PY_NSMALLNEGINTS + ival) * PyLongObject_SIZE
    );
}

impl long_zero -> ptr[PyObject] {
    return get_small_int(0);
}

impl long_one -> ptr[PyObject] {
    return get_small_int(1);
}

impl is_medium_int(x: i64) -> bool {
    x_plus_mask = wrapping_add(u64.wrap(x), PyLong_MASK);
    return x_plus_mask < PyLong_MASK + PyLong_BASE;
}

impl object_is_uniquely_referenced(op: ptr[PyObject]) -> bool {
    return object_refcount(op) == 1;
}

impl decref_int(v: ptr[PyLongObject]) {
    op = as_object(v);
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0x80000000) != 0 {
        return;
    }
    full -= 1;
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        reftracer_track(op, PYREFTRACER_DESTROY);
        _PyLong_ExactDealloc(op);
    }
}

impl maybe_small_long(v: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if v and long_is_compact(v) {
        ival = compact_value(v);
        if is_small_int(ival) {
            decref_int(v);
            return long_of(get_small_int(ival));
        }
    }
    return v;
}

impl long_normalize(v: ptr[PyLongObject]) -> ptr[PyLongObject] {
    j = digit_count(v);
    i = j;
    while i > 0 and digit_at(v, i - 1) == u32(0) {
        i -= 1;
    }
    if i != j {
        if i == 0 {
            set_sign_and_digit_count(v, 0, 0);
        } else {
            set_digit_count(v, i);
        }
    }
    return v;
}

impl long_alloc(size: i64) -> ptr[PyLongObject] {
    if size > MAX_LONG_DIGITS {
        PyErr_SetString(PyExc_OverflowError, "too many digits in integer");
        return ptr[PyLongObject]();
    }

    ndigits = size if size != 0 else 1;
    result = ptr[PyLongObject]();
    if ndigits == 1 {
        result = long_of(freelist_pop(_Py_freelists_INTS));
    }
    if not result {
        result = ptr[PyLongObject](
            PyObject_Malloc(u64(PyLongObject_DIGIT + ndigits * PyLong_DIGIT_SIZE))
        );
        if not result {
            PyErr_NoMemory();
            return ptr[PyLongObject]();
        }
        PyObject_Init(as_object(result), ptr[PyObject](long_type()));
    }
    set_sign_and_digit_count(result, 1 if size != 0 else 0, size);

    set_digit(result, 0, u32(0));
    return result;
}

impl long_from_medium(x: i64) -> ptr[PyObject] {
    v = long_of(freelist_pop(_Py_freelists_INTS));
    if not v {
        v = ptr[PyLongObject](PyObject_Malloc(u64(PyLongObject_SIZE)));
        if not v {
            return PyErr_NoMemory();
        }
        PyObject_Init(as_object(v), ptr[PyObject](long_type()));
    }
    abs_x = -x if x < 0 else x;
    set_sign_and_digit_count(v, -1 if x < 0 else 1, 1);
    set_digit(v, 0, u32.wrap(abs_x));
    return as_object(v);
}

impl long_from_large(ival: i64) -> ptr[PyObject] {
    abs_ival = u64(0);
    sign: i64 = 1;
    if ival < 0 {
        abs_ival = wrapping_sub(u64(0), u64.wrap(ival));
        sign = -1;
    } else {
        abs_ival = u64.wrap(ival);
    }

    t = abs_ival >> u64(PyLong_SHIFT * 2);
    ndigits: i64 = 2;
    while t != u64(0) {
        ndigits += 1;
        t = t >> u64(PyLong_SHIFT);
    }
    v = long_alloc(ndigits);
    if v {
        p = ob_digits(v);
        set_sign_and_digit_count(v, sign, ndigits);
        t = abs_ival;
        while t != u64(0) {
            p.view(1)[0] = u32.wrap(t & PyLong_MASK);
            p = p + 1;
            t = t >> u64(PyLong_SHIFT);
        }
    }
    return as_object(v);
}

impl long_from_stwodigits(x: i64) -> ptr[PyLongObject] {
    if is_small_int(x) {
        return long_of(get_small_int(x));
    }
    if is_medium_int(x) {
        return long_of(long_from_medium(x));
    }
    return long_of(long_from_large(x));
}

impl long_negate(x: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if object_is_uniquely_referenced(as_object(x)) {
        flip_sign(x);
        return x;
    }
    result = long_from_stwodigits(-compact_value(x));
    object_decref(as_object(x));
    return result;
}

impl long_from_int(ival: i64) -> ptr[PyObject] {
    if is_small_int(ival) {
        return get_small_int(ival);
    }
    if -PyLong_MASK_SIGNED <= ival and ival <= PyLong_MASK_SIGNED {
        return long_from_medium(ival);
    }
    abs_ival = wrapping_sub(u64(0), u64.wrap(ival)) if ival < 0 else u64.wrap(ival);

    t = (abs_ival >> u64(PyLong_SHIFT)) >> u64(PyLong_SHIFT);

    ndigits: i64 = 2;
    while t != u64(0) {
        ndigits += 1;
        t = t >> u64(PyLong_SHIFT);
    }

    v = long_alloc(ndigits);
    if not v {
        return NULL;
    }
    p = ob_digits(v);
    set_sign_and_digit_count(v, -1 if ival < 0 else 1, ndigits);
    t = abs_ival;
    while t != u64(0) {
        p.view(1)[0] = u32.wrap(t & PyLong_MASK);
        p = p + 1;
        t = t >> u64(PyLong_SHIFT);
    }
    return as_object(v);
}

impl long_from_uint(ival_in: u64) -> ptr[PyObject] {
    ival = ival_in;

    if is_small_uint(ival) {
        return get_small_int(i64(ival));
    }
    if ival <= PyLong_MASK {
        return long_from_medium(i64(ival));
    }

    t = (ival >> u64(PyLong_SHIFT)) >> u64(PyLong_SHIFT);

    ndigits: i64 = 2;
    while t != u64(0) {
        ndigits += 1;
        t = t >> u64(PyLong_SHIFT);
    }

    v = long_alloc(ndigits);
    if not v {
        return NULL;
    }
    p = ob_digits(v);
    while ival != u64(0) {
        p.view(1)[0] = u32.wrap(ival & PyLong_MASK);
        p = p + 1;
        ival = ival >> u64(PyLong_SHIFT);
    }
    return as_object(v);
}

impl max_str_digits -> i64 {
    slot = ptr[i32](current_interp() + PyInterpreterState_LONG_MAX_STR_DIGITS);
    return i64(slot.view(1)[0]);
}

impl both_long(v: ptr[PyObject], w: ptr[PyObject]) -> bool {
    return long_check(v) and long_check(w);
}

impl long_as_long_and_overflow(vv: ptr[PyObject]) -> tuple[i64, i32] {
    if not vv {
        PyErr_BadInternalCall();
        return (-1, i32(0));
    }

    do_decref = False;
    v = ptr[PyLongObject]();
    if long_check(vv) {
        v = long_of(vv);
    } else {
        v = long_of(_PyNumber_Index(vv));
        if not v {
            return (-1, i32(0));
        }
        do_decref = True;
    }
    res: i64 = -1;
    overflow = i32(0);
    if long_is_compact(v) {
        res = compact_value(v);
    } else {
        i = digit_count(v);
        sign = long_sign_of(v);
        x = u64(0);
        lost_bits = False;
        while i > 0 {
            i -= 1;
            prev = x;
            x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
            if (x >> u64(PyLong_SHIFT)) != prev {
                overflow = i32(sign);
                lost_bits = True;
                break;
            }
        }
        if not lost_bits {
            if x <= u64(LONG_MAX) {
                res = i64(x) * sign;
            } elif sign < 0 and x == PY_ABS_LONG_MIN {
                res = LONG_MIN;
            } else {
                overflow = i32(sign);
            }
        }
    }
    if do_decref {
        object_decref(as_object(v));
    }
    return (res, overflow);
}

impl long_as_unsigned_long_mask(vv: ptr[PyObject]) -> u64 {
    if not vv or not long_check(vv) {
        PyErr_BadInternalCall();
        return ~u64(0);
    }
    v = long_of(vv);
    if long_is_compact(v) {
        return u64.wrap(compact_value(v));
    }
    i = digit_count(v);
    sign = long_sign_of(v);
    x = u64(0);
    while i > 0 {
        i -= 1;
        x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
    }

    if sign < 0 {
        return wrapping_sub(u64(0), x);
    }
    return x;
}

impl long_sign(vv: ptr[PyObject]) -> i32 {
    return i32(long_sign_of(long_of(vv)));
}

impl bit_length_digit(x: u32) -> i64 {
    n = x;
    bits: i64 = 0;
    while n != u32(0) {
        bits += 1;
        n = n >> u32(1);
    }
    return bits;
}

impl as_byte_array_overflow(with_exceptions: i32) -> i32 {
    if with_exceptions != i32(0) {
        PyErr_SetString(PyExc_OverflowError, "int too big to convert");
    }
    return i32(-1);
}

impl _fits_in_n_bits(v: i64, n: i64) -> bool {
    if n >= SIZEOF_PY_SSIZE_T * 8 {
        return True;
    }

    v_extended = v >> (n - 1);
    return v_extended == 0 or v_extended == -1;
}

impl _resolve_endianness(endianness_in: i32) -> tuple[i32, i32] {
    endianness = endianness_in;
    if endianness == -1 or (endianness & 2) != 0 {
        endianness = PY_LITTLE_ENDIAN;
    } else {
        endianness = endianness & 1;
    }
    return (i32(0), endianness);
}

impl ssize_t_byte(value: i64, i: i64) -> u8 {
    return u8((value >> (8 * i)) & 0xFF);
}

impl _PyLong_AsUnsignedLongLongMask(vv: ptr[PyObject]) -> u64 {
    if not vv or not long_check(vv) {
        PyErr_BadInternalCall();
        return ~u64(0);
    }
    v = long_of(vv);
    if long_is_compact(v) {
        return u64.wrap(compact_value(v));
    }
    i = digit_count(v);
    sign = long_sign_of(v);
    x = u64(0);
    i -= 1;
    while i >= 0 {
        x = wrapping_shl(x, u64(PyLong_SHIFT)) | u64(digit_at(v, i));
        i -= 1;
    }
    return wrapping_mul(x, u64.wrap(sign));
}

impl long_as_long_long_and_overflow(vv: ptr[PyObject]) -> tuple[i64, i32] {
    v = ptr[PyLongObject]();
    res: i64 = 0;
    overflow = i32(0);

    do_decref = False;
    if not vv {
        PyErr_BadInternalCall();
        return (i64(-1), overflow);
    }
    if long_check(vv) {
        v = long_of(vv);
    } else {
        v = long_of(_PyNumber_Index(vv));
        if not v {
            return (i64(-1), overflow);
        }
        do_decref = True;
    }
    if long_is_compact(v) {
        res = compact_value(v);
    } else {
        i = digit_count(v);
        sign = long_sign_of(v);
        x = u64(0);
        lost_bits = False;
        i -= 1;
        while i >= 0 {
            prev = x;

            x = wrapping_shl(x, u64(PyLong_SHIFT)) + u64(digit_at(v, i));
            if (x >> u64(PyLong_SHIFT)) != prev {
                overflow = i32(sign);
                res = -1;
                lost_bits = True;
                break;
            }
            i -= 1;
        }
        if not lost_bits {
            if x <= u64(LLONG_MAX) {
                res = i64(x) * sign;
            } elif sign < 0 and x == PY_ABS_LLONG_MIN {
                res = LLONG_MIN;
            } else {
                overflow = i32(sign);
                res = -1;
            }
        }
    }
    if do_decref {
        object_decref(as_object(v));
    }
    return (res, overflow);
}

impl v_iadd(x: ptr[u32], m: i64, y: ptr[u32], n: i64) -> u32 {
    carry = u64(0);
    i: i64 = 0;
    while i < n {
        carry += u64(dget(x, i)) + u64(dget(y, i));
        dset(x, i, u32(carry & PyLong_MASK));
        carry = carry >> u64(PyLong_SHIFT);
        i += 1;
    }
    while carry != u64(0) and i < m {
        carry += u64(dget(x, i));
        dset(x, i, u32(carry & PyLong_MASK));
        carry = carry >> u64(PyLong_SHIFT);
        i += 1;
    }
    return u32(carry);
}

impl v_isub(x: ptr[u32], m: i64, y: ptr[u32], n: i64) -> u32 {
    borrow: i64 = 0;
    i: i64 = 0;
    while i < n {
        borrow = i64(dget(x, i)) - i64(dget(y, i)) - borrow;
        dset(x, i, u32(borrow & PyLong_MASK_SIGNED));
        borrow = borrow >> PyLong_SHIFT;

        borrow = borrow & 1;
        i += 1;
    }
    while borrow != 0 and i < m {
        borrow = i64(dget(x, i)) - borrow;
        dset(x, i, u32(borrow & PyLong_MASK_SIGNED));
        borrow = borrow >> PyLong_SHIFT;
        borrow = borrow & 1;
        i += 1;
    }
    return u32(borrow);
}

impl v_lshift(z: ptr[u32], a: ptr[u32], m: i64, d: i64) -> u32 {
    carry = u64(0);
    for i in range(m) {
        acc = (u64(dget(a, i)) << u64(d)) | carry;
        dset(z, i, u32(acc & PyLong_MASK));
        carry = acc >> u64(PyLong_SHIFT);
    }
    return u32(carry);
}

impl v_rshift(z: ptr[u32], a: ptr[u32], m: i64, d: i64) -> u32 {
    carry = u64(0);
    mask = (u64(1) << u64(d)) - u64(1);
    i = m - 1;
    while i >= 0 {
        acc = (carry << u64(PyLong_SHIFT)) | u64(dget(a, i));
        carry = acc & mask;
        dset(z, i, u32(acc >> u64(d)));
        i -= 1;
    }
    return u32(carry);
}

impl inplace_divrem1(pout: ptr[u32], pin: ptr[u32], size: i64, n: u32) -> u32 {
    remainder = u64(0);
    divisor = u64(n);
    i = size - 1;
    while i >= 0 {
        dividend = (remainder << u64(PyLong_SHIFT)) | u64(dget(pin, i));
        quotient = u32(dividend // divisor);
        remainder = dividend % divisor;
        dset(pout, i, quotient);
        i -= 1;
    }
    return u32(remainder);
}

impl divrem1(a: ptr[PyLongObject], n: u32) -> tuple[ptr[PyLongObject], u32] {
    size = digit_count(a);
    z = long_alloc(size);
    if not z {
        return (ptr[PyLongObject](), u32(0));
    }
    prem = inplace_divrem1(ob_digits(z), ob_digits(a), size, n);
    return (long_normalize(z), prem);
}

impl inplace_rem1(pin: ptr[u32], size: i64, n: u32) -> u32 {
    rem = u64(0);
    divisor = u64(n);
    i = size - 1;
    while i >= 0 {
        rem = ((rem << u64(PyLong_SHIFT)) | u64(dget(pin, i))) % divisor;
        i -= 1;
    }
    return u32(rem);
}

impl rem1(a: ptr[PyLongObject], n: u32) -> ptr[PyLongObject] {
    size = digit_count(a);
    return long_of(PyLong_FromLong(i64(inplace_rem1(ob_digits(a), size, n))));
}

impl writer_buffer(writer: ptr[_PyUnicodeWriter]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](writer) + _PyUnicodeWriter_BUFFER).view(1)[0];
}

impl writer_kind(writer: ptr[_PyUnicodeWriter]) -> i64 {
    return i64(ptr[i32](ptr[u8](writer) + _PyUnicodeWriter_KIND).view(1)[0]);
}

impl writer_maxchar(writer: ptr[_PyUnicodeWriter]) -> u32 {
    return ptr[u32](ptr[u8](writer) + _PyUnicodeWriter_MAXCHAR).view(1)[0];
}

impl writer_size(writer: ptr[_PyUnicodeWriter]) -> i64 {
    return ptr[i64](ptr[u8](writer) + _PyUnicodeWriter_SIZE_FIELD).view(1)[0];
}

impl writer_pos(writer: ptr[_PyUnicodeWriter]) -> i64 {
    return ptr[i64](ptr[u8](writer) + _PyUnicodeWriter_POS).view(1)[0];
}

impl set_writer_pos(writer: ptr[_PyUnicodeWriter], pos: i64) {
    ptr[i64](ptr[u8](writer) + _PyUnicodeWriter_POS).view(1)[0] = pos;
}

impl unicode_writer_prepare(
    writer: ptr[_PyUnicodeWriter], length: i64, maxchar: u32
) -> i32 {
    if maxchar <= writer_maxchar(writer)
        and length <= writer_size(writer) - writer_pos(writer) {
        return i32(0);
    }
    if length == 0 {
        return i32(0);
    }
    return _PyUnicodeWriter_PrepareInternal(writer, length, maxchar);
}

impl unicode_read(kind: i64, data: ptr[u8], i: i64) -> u32 {
    if kind == PyUnicode_1BYTE_KIND {
        return u32((data + i).view(1)[0]);
    }
    if kind == PyUnicode_2BYTE_KIND {
        return u32((ptr[u16](data) + i).view(1)[0]);
    }
    return (ptr[u32](data) + i).view(1)[0];
}

impl unicode_put(data: ptr[u8], kind: i64, i: i64, ch: u32) {
    if kind == PyUnicode_1BYTE_KIND {
        (data + i).view(1)[0] = u8.wrap(ch);
    } elif kind == PyUnicode_2BYTE_KIND {
        (ptr[u16](data) + i).view(1)[0] = u16.wrap(ch);
    } else {
        (ptr[u32](data) + i).view(1)[0] = ch;
    }
}

impl pylong_int_to_decimal_string(
    aa: ptr[PyObject],
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]] {
    bytes_str = bytes_str_in;
    output = NULL;
    mod = PyImport_ImportModule("_pylong");
    if not mod {
        return (i32(-1), NULL, bytes_str);
    }
    s = PyObject_CallMethod(mod, "int_to_decimal_string", "O", aa);
    if not s {
        object_decref(mod);
        return (i32(-1), NULL, bytes_str);
    }
    if not type_has_feature(object_type(s), Py_TPFLAGS_UNICODE_SUBCLASS) {
        PyErr_SetString(
            PyExc_TypeError, "_pylong.int_to_decimal_string did not return a str"
        );
        object_decref(mod);
        object_decref(s);
        return (i32(-1), NULL, bytes_str);
    }
    if writer {
        size = PyUnicode_GetLength(s);
        if unicode_writer_prepare(writer, size, u32(57)) == i32(-1)
            or _PyUnicodeWriter_WriteStr(writer, s) < i32(0) {
            object_decref(mod);
            object_decref(s);
            return (i32(-1), NULL, bytes_str);
        }
    } elif bytes_writer {
        size = PyUnicode_GetLength(s);
        data = ptr[u8](jacpy_unicode_data(s));
        kind = jacpy_unicode_kind(s);
        bytes_str = ptr[u8](_PyBytesWriter_Prepare(bytes_writer, ptr(bytes_str), size));
        if not bytes_str {
            object_decref(mod);
            object_decref(s);
            return (i32(-1), NULL, bytes_str);
        }
        p = bytes_str;
        for i in range(size) {
            ch = unicode_read(kind, data, i);
            p.view(1)[0] = u8.wrap(ch);
            p = p + 1;
        }
        bytes_str = p;
    } else {
        output = object_new_ref(s);
    }
    object_decref(mod);
    object_decref(s);
    return (i32(0), output, bytes_str);
}

impl write_decimal_digits(
    data: ptr[u8], kind: i64, end: i64, pout: ptr[u32], size: i64, negative: i64
) -> i64 {
    p = end;

    for i in range(size - 1) {
        rem = dget(pout, i);
        for j in range(PyLong_DECIMAL_SHIFT) {
            p -= 1;
            unicode_put(data, kind, p, u32(48) + rem % u32(10));
            rem = rem // u32(10);
        }
    }

    last = dget(pout, size - 1);
    while True {
        p -= 1;
        unicode_put(data, kind, p, u32(48) + last % u32(10));
        last = last // u32(10);
        if last == u32(0) {
            break;
        }
    }

    if negative != 0 {
        p -= 1;
        unicode_put(data, kind, p, u32(45));
    }
    return p;
}

impl long_to_decimal_string_internal(
    aa: ptr[PyObject],
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]] {
    bytes_str = bytes_str_in;
    if not aa or not long_check(aa) {
        PyErr_BadInternalCall();
        return (i32(-1), NULL, bytes_str);
    }
    a = long_of(aa);
    size_a = digit_count(a);
    negative: i64 = 1 if long_is_negative(a) else 0;

    if size_a >= 10 * _PY_LONG_MAX_STR_DIGITS_THRESHOLD // (3 * PyLong_SHIFT) + 2 {
        max_digits = max_str_digits();
        if max_digits > 0 and max_digits // (3 * PyLong_SHIFT) <= (size_a - 11) // 10 {
            limit = i32(max_digits);
            PyErr_Format(
                PyExc_ValueError,
                "Exceeds the limit (%d digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
                limit
            );
            return (i32(-1), NULL, bytes_str);
        }
    }
    if size_a > 1000 {
        return pylong_int_to_decimal_string(aa, writer, bytes_writer, bytes_str);
    }

    d = (33 * PyLong_DECIMAL_SHIFT) // (10 * PyLong_SHIFT - 33 * PyLong_DECIMAL_SHIFT);
    size = 1 + size_a + size_a // d;
    scratch = long_alloc(size);
    if not scratch {
        return (i32(-1), NULL, bytes_str);
    }

    pin = ob_digits(a);
    pout = ob_digits(scratch);
    size = 0;
    i = size_a - 1;
    while i >= 0 {
        hi = dget(pin, i);
        for j in range(size) {
            z = (u64(dget(pout, j)) << u64(PyLong_SHIFT)) | u64(hi);
            hi = u32(z // PyLong_DECIMAL_BASE);
            dset(pout, j, u32(z - u64(hi) * PyLong_DECIMAL_BASE));
        }
        while hi != u32(0) {
            dset(pout, size, u32(u64(hi) % PyLong_DECIMAL_BASE));
            size += 1;
            hi = u32(u64(hi) // PyLong_DECIMAL_BASE);
        }

        if PyErr_CheckSignals() != i32(0) {
            object_decref(as_object(scratch));
            return (i32(-1), NULL, bytes_str);
        }
        i -= 1;
    }

    if size == 0 {
        dset(pout, 0, u32(0));
        size = 1;
    }

    str_len = negative + 1 + (size - 1) * PyLong_DECIMAL_SHIFT;
    tenpow = u32(10);
    rem = dget(pout, size - 1);
    while rem >= tenpow {
        tenpow = tenpow * u32(10);
        str_len += 1;
    }
    if str_len > _PY_LONG_MAX_STR_DIGITS_THRESHOLD {
        max_digits = max_str_digits();
        strlen_nosign = str_len - negative;
        if max_digits > 0 and strlen_nosign > max_digits {
            object_decref(as_object(scratch));
            limit = i32(max_digits);
            PyErr_Format(
                PyExc_ValueError,
                "Exceeds the limit (%d digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
                limit
            );
            return (i32(-1), NULL, bytes_str);
        }
    }
    text = NULL;
    if writer {
        if unicode_writer_prepare(writer, str_len, u32(57)) == i32(-1) {
            object_decref(as_object(scratch));
            return (i32(-1), NULL, bytes_str);
        }
    } elif bytes_writer {
        bytes_str = ptr[u8](
            _PyBytesWriter_Prepare(bytes_writer, ptr(bytes_str), str_len)
        );
        if not bytes_str {
            object_decref(as_object(scratch));
            return (i32(-1), NULL, bytes_str);
        }
    } else {
        text = PyUnicode_New(str_len, u32(57));
        if not text {
            object_decref(as_object(scratch));
            return (i32(-1), NULL, bytes_str);
        }
    }

    data = bytes_str;
    kind = PyUnicode_1BYTE_KIND;
    if not bytes_writer {
        if writer {
            kind = writer_kind(writer);
            data = ptr[u8](jacpy_unicode_data(writer_buffer(writer)))
                + writer_pos(writer) * kind;
        } else {
            kind = jacpy_unicode_kind(text);
            data = ptr[u8](jacpy_unicode_data(text));
        }
    }
    write_decimal_digits(data, kind, str_len, pout, size, negative);
    decref_int(scratch);
    if writer {
        set_writer_pos(writer, writer_pos(writer) + str_len);
    } elif bytes_writer {
        bytes_str = bytes_str + str_len;
    }
    return (i32(0), text, bytes_str);
}

impl long_to_decimal_string(aa: ptr[PyObject]) -> ptr[PyObject] {
    (status, v, unused) = long_to_decimal_string_internal(
        aa, ptr[_PyUnicodeWriter](), ptr[_PyBytesWriter](), ptr[u8]()
    );
    if status == i32(-1) {
        return NULL;
    }
    return v;
}

impl write_binary_digits(
    data: ptr[u8],
    kind: i64,
    end: i64,
    a: ptr[PyLongObject],
    size_a: i64,
    base: i32,
    bits: i64,
    alternate: i32,
    negative: i64
) -> i64 {
    p = end;
    if size_a == 0 {
        p -= 1;
        unicode_put(data, kind, p, u32(48));
    } else {
        accum = u64(0);
        accumbits: i64 = 0;
        for i in range(size_a) {
            accum = accum | (u64(digit_at(a, i)) << u64(accumbits));
            accumbits += PyLong_SHIFT;
            while True {
                cdigit = i64(accum & u64(base - i32(1)));
                if cdigit < 10 {
                    cdigit += 48;
                } else {
                    cdigit += 87;
                }
                p -= 1;
                unicode_put(data, kind, p, u32(cdigit));
                accumbits -= bits;
                accum = accum >> u64(bits);
                more = accumbits >= bits if i < size_a - 1 else accum > u64(0);
                if not more {
                    break;
                }
            }
        }
    }
    if alternate != i32(0) {
        p -= 1;
        if base == i32(16) {
            unicode_put(data, kind, p, u32(120));
        } elif base == i32(8) {
            unicode_put(data, kind, p, u32(111));
        } else {
            unicode_put(data, kind, p, u32(98));
        }
        p -= 1;
        unicode_put(data, kind, p, u32(48));
    }
    if negative != 0 {
        p -= 1;
        unicode_put(data, kind, p, u32(45));
    }
    return p;
}

impl long_format_binary(
    aa: ptr[PyObject],
    base: i32,
    alternate: i32,
    writer: ptr[_PyUnicodeWriter],
    bytes_writer: ptr[_PyBytesWriter],
    bytes_str_in: ptr[u8]
) -> tuple[i32, ptr[PyObject], ptr[u8]] {
    bytes_str = bytes_str_in;
    v = NULL;
    if not aa or not long_check(aa) {
        PyErr_BadInternalCall();
        return (i32(-1), NULL, bytes_str);
    }
    a = long_of(aa);
    size_a = digit_count(a);
    negative: i64 = 1 if long_is_negative(a) else 0;

    bits: i64 = 1;
    if base == i32(16) {
        bits = 4;
    } elif base == i32(8) {
        bits = 3;
    }

    sz: i64 = 0;
    if size_a == 0 {
        sz = 1;
    } else {
        if size_a > (0x7FFFFFFFFFFFFFFF - 3) // PyLong_SHIFT {
            PyErr_SetString(PyExc_OverflowError, "int too large to format");
            return (i32(-1), NULL, bytes_str);
        }
        size_a_in_bits = (size_a - 1) * PyLong_SHIFT
            + bit_length_digit(digit_at(a, size_a - 1));
        sz = negative + (size_a_in_bits + (bits - 1)) // bits;
    }
    if alternate != i32(0) {
        sz += 2;
    }
    if writer {
        if unicode_writer_prepare(writer, sz, u32(120)) == i32(-1) {
            return (i32(-1), NULL, bytes_str);
        }
    } elif bytes_writer {
        bytes_str = ptr[u8](_PyBytesWriter_Prepare(bytes_writer, ptr(bytes_str), sz));
        if not bytes_str {
            return (i32(-1), NULL, bytes_str);
        }
    } else {
        v = PyUnicode_New(sz, u32(120));
        if not v {
            return (i32(-1), NULL, bytes_str);
        }
    }

    data = bytes_str;
    kind = PyUnicode_1BYTE_KIND;
    if not bytes_writer {
        if writer {
            kind = writer_kind(writer);
            data = ptr[u8](jacpy_unicode_data(writer_buffer(writer)))
                + writer_pos(writer) * kind;
        } else {
            kind = jacpy_unicode_kind(v);
            data = ptr[u8](jacpy_unicode_data(v));
        }
    }
    write_binary_digits(data, kind, sz, a, size_a, base, bits, alternate, negative);
    if writer {
        set_writer_pos(writer, writer_pos(writer) + sz);
    } elif bytes_writer {
        bytes_str = bytes_str + sz;
    }
    return (i32(0), v, bytes_str);
}

impl is_space(c: u8) -> bool {
    return c == u8(32) or (c >= u8(9) and c <= u8(13));
}

impl digit_value(c: u8) -> i64 {
    return i64((addressof(_PyLong_DigitValue) + i64(c)).view(1)[0]);
}

impl long_from_binary_base(
    start: ptr[u8], end: ptr[u8], digits: i64, base: i64
) -> tuple[i32, ptr[PyLongObject]] {
    n = base;
    bits_per_char: i64 = -1;
    while n != 0 {
        n = n >> 1;
        bits_per_char += 1;
    }

    if digits > (PY_SSIZE_T_MAX - (PyLong_SHIFT - 1)) // bits_per_char {
        PyErr_SetString(PyExc_ValueError, "int string too large to convert");
        return (i32(0), ptr[PyLongObject]());
    }
    n = (digits * bits_per_char + PyLong_SHIFT - 1) // PyLong_SHIFT;
    z = long_alloc(n);
    if not z {
        return (i32(0), ptr[PyLongObject]());
    }

    accum = u64(0);
    bits_in_accum: i64 = 0;
    pdigit = ob_digits(z);
    filled: i64 = 0;
    pos = (int(end) - int(start)) - 1;
    while pos >= 0 {
        c = (start + pos).view(1)[0];
        pos -= 1;
        if c == u8(95) {
            continue;
        }
        k = digit_value(c);
        accum = accum | (u64(k) << u64(bits_in_accum));
        bits_in_accum += bits_per_char;
        if bits_in_accum >= PyLong_SHIFT {
            dset(pdigit, filled, u32.wrap(accum & PyLong_MASK));
            filled += 1;
            accum = accum >> u64(PyLong_SHIFT);
            bits_in_accum -= PyLong_SHIFT;
        }
    }
    if bits_in_accum != 0 {
        dset(pdigit, filled, u32.wrap(accum));
        filled += 1;
    }
    while filled < n {
        dset(pdigit, filled, u32(0));
        filled += 1;
    }
    return (i32(0), z);
}

impl pylong_int_from_string(
    start: ptr[u8], end: ptr[u8]
) -> tuple[i32, ptr[PyLongObject]] {
    mod = PyImport_ImportModule("_pylong");
    if not mod {
        return (i32(0), ptr[PyLongObject]());
    }
    s = PyUnicode_FromStringAndSize(start, int(end) - int(start));
    if not s {
        object_decref(mod);
        return (i32(0), ptr[PyLongObject]());
    }
    result = PyObject_CallMethod(mod, "int_from_string", "O", s);
    object_decref(s);
    object_decref(mod);
    if not result {
        return (i32(0), ptr[PyLongObject]());
    }
    if not long_check(result) {
        object_decref(result);
        PyErr_SetString(
            PyExc_TypeError, "_pylong.int_from_string did not return an int"
        );
        return (i32(0), ptr[PyLongObject]());
    }
    return (i32(0), long_of(result));
}

impl long_from_non_binary_base(
    start: ptr[u8], end: ptr[u8], digits: i64, base: i64
) -> tuple[i32, ptr[PyLongObject]] {
    fsize_z = f64(digits) * (addressof(log_base_BASE) + base).view(1)[0] + 1.0;
    if fsize_z > f64(MAX_LONG_DIGITS) {
        PyErr_SetString(PyExc_OverflowError, "too many digits in integer");
        return (i32(0), ptr[PyLongObject]());
    }
    size_z = i64(fsize_z);
    z = long_alloc(size_z);
    if not z {
        return (i32(0), ptr[PyLongObject]());
    }
    set_sign_and_digit_count(z, 0, 0);

    convwidth = i64((addressof(convwidth_base) + base).view(1)[0]);
    convmultmax = (addressof(convmultmax_base) + base).view(1)[0];
    ubase = u64(base);
    c = u64(0);
    i: i64 = 0;
    p = start;
    while p < end {
        if p.view(1)[0] == u8(95) {
            p = p + 1;
            continue;
        }

        c = u64(digit_value(p.view(1)[0]));
        p = p + 1;
        i = 1;
        while i < convwidth and p != end {
            if p.view(1)[0] != u8(95) {
                i += 1;
                c = c * ubase + u64(digit_value(p.view(1)[0]));
            }
            p = p + 1;
        }
        convmult = convmultmax;

        if i != convwidth {
            convmult = ubase;
            while i > 1 {
                convmult *= ubase;
                i -= 1;
            }
        }

        pz = ob_digits(z);
        size = digit_count(z);
        for j in range(size) {
            c += u64(dget(pz, j)) * convmult;
            dset(pz, j, u32.wrap(c & PyLong_MASK));
            c = c >> u64(PyLong_SHIFT);
        }

        if c != u64(0) {
            if size < size_z {
                dset(pz, size, u32.wrap(c));
                set_sign_and_digit_count(z, 1, size + 1);
            } else {
                tmp = long_alloc(size_z + 1);
                if not tmp {
                    object_decref(as_object(z));
                    return (i32(0), ptr[PyLongObject]());
                }
                memcpy(
                    ptr(ob_digits(tmp)),
                    ptr(ob_digits(z)),
                    u64(PyLong_DIGIT_SIZE * size_z)
                );
                old = z;
                z = tmp;
                object_decref(as_object(old));
                set_digit(z, size_z, u32.wrap(c));
                size_z += 1;
            }
        }
    }
    return (i32(0), z);
}

impl long_from_string_base(
    s: ptr[u8], base: i64
) -> tuple[i32, ptr[u8], ptr[PyLongObject]] {
    prev = u8(0);
    digits: i64 = 0;
    is_binary_base = (base & (base - 1)) == 0;

    start = s;
    p = s;

    if start.view(1)[0] == u8(95) {
        return (i32(-1), s, ptr[PyLongObject]());
    }

    while digit_value(p.view(1)[0]) < base or p.view(1)[0] == u8(95) {
        if p.view(1)[0] == u8(95) {
            if prev == u8(95) {
                return (i32(-1), p - 1, ptr[PyLongObject]());
            }
        } else {
            digits += 1;
        }
        prev = p.view(1)[0];
        p = p + 1;
    }

    if prev == u8(95) {
        return (i32(-1), p - 1, ptr[PyLongObject]());
    }
    end = p;

    if start == end {
        return (i32(-1), end, ptr[PyLongObject]());
    }

    while p.view(1)[0] != u8(0) and is_space(p.view(1)[0]) {
        p = p + 1;
    }
    if p.view(1)[0] != u8(0) {
        return (i32(-1), p, ptr[PyLongObject]());
    }

    if is_binary_base {
        (status, z) = long_from_binary_base(start, end, digits, base);
        return (status, p, z);
    }

    if digits > _PY_LONG_MAX_STR_DIGITS_THRESHOLD {
        limit = i32(max_str_digits());
        if limit > i32(0) and digits > i64(limit) {
            PyErr_Format(
                PyExc_ValueError,
                "Exceeds the limit (%d digits) for integer string conversion: value has %zd digits; use sys.set_int_max_str_digits() to increase the limit",
                limit,
                digits
            );
            return (i32(0), p, ptr[PyLongObject]());
        }
    }
    if digits > 6000 and base == 10 {
        (status, z) = pylong_int_from_string(start, end);
        return (status, p, z);
    }

    (status, z) = long_from_non_binary_base(start, end, digits, base);
    return (status, p, z);
}

impl invalid_int_literal(orig_str: ptr[u8], base: i64) -> ptr[PyObject] {
    slen: i64 = min(i64(strlen(orig_str)), 200);
    strobj = PyUnicode_FromStringAndSize(orig_str, slen);
    if not strobj {
        return NULL;
    }
    base32 = i32(base);
    PyErr_Format(
        PyExc_ValueError,
        "invalid literal for int() with base %d: %.200R",
        base32,
        strobj
    );
    object_decref(strobj);
    return NULL;
}

impl long_from_string(
    orig_str: ptr[u8], base_in: i64
) -> tuple[ptr[PyObject], ptr[u8]] {
    sign: i64 = 1;
    error_if_nonzero = False;
    base = base_in;
    s = orig_str;
    if (base != 0 and base < 2) or base > 36 {
        PyErr_SetString(PyExc_ValueError, "int() arg 2 must be >= 2 and <= 36");
        return (NULL, ptr[u8]());
    }
    while s.view(1)[0] != u8(0) and is_space(s.view(1)[0]) {
        s = s + 1;
    }
    if s.view(1)[0] == u8(43) {
        s = s + 1;
    } elif s.view(1)[0] == u8(45) {
        s = s + 1;
        sign = -1;
    }
    c0 = s.view(1)[0];
    if base == 0 {
        c1 = (s + 1).view(1)[0];
        if c0 != u8(48) {
            base = 10;
        } elif c1 == u8(120) or c1 == u8(88) {
            base = 16;
        } elif c1 == u8(111) or c1 == u8(79) {
            base = 8;
        } elif c1 == u8(98) or c1 == u8(66) {
            base = 2;
        } else {
            error_if_nonzero = True;
            base = 10;
        }
    }
    if c0 == u8(48) {
        c1 = (s + 1).view(1)[0];
        if (base == 16 and (c1 == u8(120) or c1 == u8(88)))
            or (base == 8 and (c1 == u8(111) or c1 == u8(79)))
            or (base == 2 and (c1 == u8(98) or c1 == u8(66))) {
            s = s + 2;

            if s.view(1)[0] == u8(95) {
                s = s + 1;
            }
        }
    }

    (ret, stop, z) = long_from_string_base(s, base);
    s = stop;
    if ret == i32(-1) {
        return (invalid_int_literal(orig_str, base), s);
    }
    if not z {
        return (NULL, ptr[u8]());
    }
    if error_if_nonzero {
        base = 0;
        if not long_is_zero(z) {
            object_decref(as_object(z));
            return (invalid_int_literal(orig_str, base), s);
        }
    }

    long_normalize(z);
    z = maybe_small_long(z);
    if sign < 0 {
        z = long_negate(z);
    }
    return (as_object(z), s);
}

impl long_divrem(
    a: ptr[PyLongObject], b: ptr[PyLongObject]
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]] {
    size_a = digit_count(a);
    size_b = digit_count(b);
    if size_b == 0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
    }
    if size_a < size_b
        or (size_a == size_b and digit_at(a, size_a - 1) < digit_at(b, size_b - 1)) {
        small_rem = long_of(long_long(as_object(a)));
        if not small_rem {
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
        return (i32(0), long_of(long_zero()), small_rem);
    }
    z = ptr[PyLongObject]();
    rem = ptr[PyLongObject]();
    if size_b == 1 {
        (q1, r1) = divrem1(a, digit_at(b, 0));
        if not q1 {
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
        z = q1;
        rem = long_of(PyLong_FromLong(i64(r1)));
        if not rem {
            object_decref(as_object(z));
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
    } else {
        (qn, rn) = x_divrem(a, b);
        z = qn;
        rem = maybe_small_long(rn);
        if not z {
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
    }

    if long_is_negative(a) != long_is_negative(b) {
        z = long_negate(z);
        if not z {
            object_xdecref(as_object(rem));
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
    }
    if long_is_negative(a) and not long_is_zero(rem) {
        rem = long_negate(rem);
        if not rem {
            object_decref(as_object(z));
            return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
        }
    }
    return (i32(0), maybe_small_long(z), rem);
}

impl long_rem(
    a: ptr[PyLongObject], b: ptr[PyLongObject]
) -> tuple[i32, ptr[PyLongObject]] {
    size_a = digit_count(a);
    size_b = digit_count(b);
    if size_b == 0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return (i32(-1), ptr[PyLongObject]());
    }
    if size_a < size_b
        or (size_a == size_b and digit_at(a, size_a - 1) < digit_at(b, size_b - 1)) {
        small_rem = long_of(long_long(as_object(a)));
        if not small_rem {
            return (i32(-1), small_rem);
        }
        return (i32(0), small_rem);
    }
    rem = ptr[PyLongObject]();
    if size_b == 1 {
        rem = rem1(a, digit_at(b, 0));
        if not rem {
            return (i32(-1), ptr[PyLongObject]());
        }
    } else {
        (qn, rn) = x_divrem(a, b);
        object_xdecref(as_object(qn));
        rem = maybe_small_long(rn);
        if not rem {
            return (i32(-1), ptr[PyLongObject]());
        }
    }

    if long_is_negative(a) and not long_is_zero(rem) {
        rem = long_negate(rem);
        if not rem {
            return (i32(-1), ptr[PyLongObject]());
        }
    }
    return (i32(0), rem);
}

impl x_divrem(
    v1: ptr[PyLongObject], w1: ptr[PyLongObject]
) -> tuple[ptr[PyLongObject], ptr[PyLongObject]] {
    mask = u32(PyLong_MASK);

    size_v = digit_count(v1);
    size_w = digit_count(w1);
    v = long_alloc(size_v + 1);
    if not v {
        return (ptr[PyLongObject](), ptr[PyLongObject]());
    }
    w = long_alloc(size_w);
    if not w {
        object_decref(as_object(v));
        return (ptr[PyLongObject](), ptr[PyLongObject]());
    }

    d = PyLong_SHIFT - bit_length_digit(digit_at(w1, size_w - 1));
    carry = v_lshift(ob_digits(w), ob_digits(w1), size_w, d);
    carry = v_lshift(ob_digits(v), ob_digits(v1), size_v, d);
    if carry != u32(0) or digit_at(v, size_v - 1) >= digit_at(w, size_w - 1) {
        set_digit(v, size_v, carry);
        size_v += 1;
    }

    k = size_v - size_w;
    a = long_alloc(k);
    if not a {
        object_decref(as_object(w));
        object_decref(as_object(v));
        return (ptr[PyLongObject](), ptr[PyLongObject]());
    }
    v0 = ob_digits(v);
    w0 = ob_digits(w);
    wm1 = dget(w0, size_w - 1);
    wm2 = dget(w0, size_w - 2);

    j = k;
    while j > 0 {
        j -= 1;
        vk = v0 + j;

        if PyErr_CheckSignals() != 0 {
            object_decref(as_object(a));
            object_decref(as_object(w));
            object_decref(as_object(v));
            return (ptr[PyLongObject](), ptr[PyLongObject]());
        }

        vtop = dget(vk, size_w);
        vv = (u64(vtop) << PyLong_SHIFT) | u64(dget(vk, size_w - 1));

        q = u32(vv // u64(wm1));
        r = u32(vv % u64(wm1));
        while u64(wm2) * u64(q)
            > ((u64(r) << PyLong_SHIFT) | u64(dget(vk, size_w - 2))) {
            q -= u32(1);
            r += wm1;
            if u64(r) >= PyLong_BASE {
                break;
            }
        }

        zhi: i64 = 0;
        for i in range(size_w) {
            z = i64(dget(vk, i)) + zhi - i64(q) * i64(dget(w0, i));

            dset(vk, i, u32(z & PyLong_MASK_SIGNED));

            zhi = z >> PyLong_SHIFT;
        }

        if i64(vtop) + zhi < 0 {
            carry = u32(0);
            for i in range(size_w) {
                carry += dget(vk, i) + dget(w0, i);
                dset(vk, i, carry & mask);
                carry = carry >> PyLong_SHIFT;
            }
            q -= u32(1);
        }

        dset(ob_digits(a), j, q);
    }

    carry = v_rshift(w0, v0, size_w, d);
    object_decref(as_object(v));
    rem = long_normalize(w);
    return (long_normalize(a), rem);
}

impl long_frexp(a: ptr[PyLongObject]) -> tuple[f64, i64] {
    x_digits = ptr[u32](addressof(frexp_digits));
    dset(x_digits, 0, u32(0));
    dset(x_digits, 1, u32(0));
    dset(x_digits, 2, u32(0));
    a_size = digit_count(a);
    if a_size == 0 {
        return (0.0, 0);
    }
    a_bits = _PyLong_NumBits(as_object(a));

    x_size: i64 = 0;
    rem = u32(0);
    if a_bits <= DBL_MANT_DIG + 2 {
        shift_digits = (DBL_MANT_DIG + 2 - a_bits) // PyLong_SHIFT;
        shift_bits = (DBL_MANT_DIG + 2 - a_bits) % PyLong_SHIFT;
        x_size = shift_digits;
        rem = v_lshift(x_digits + x_size, ob_digits(a), a_size, shift_bits);
        x_size += a_size;
        dset(x_digits, x_size, rem);
        x_size += 1;
    } else {
        shift_digits = (a_bits - DBL_MANT_DIG - 2) // PyLong_SHIFT;
        shift_bits = (a_bits - DBL_MANT_DIG - 2) % PyLong_SHIFT;
        rem = v_rshift(
            x_digits, ob_digits(a) + shift_digits, a_size - shift_digits, shift_bits
        );
        x_size = a_size - shift_digits;
        if rem != u32(0) {
            dset(x_digits, 0, dget(x_digits, 0) | u32(1));
        } else {
            while shift_digits > 0 {
                shift_digits -= 1;
                if digit_at(a, shift_digits) != u32(0) {
                    dset(x_digits, 0, dget(x_digits, 0) | u32(1));
                    break;
                }
            }
        }
    }

    low = dget(x_digits, 0);
    dset(x_digits, 0, u32(i64(low) + HALF_EVEN_CORRECTION[i64(low & u32(7))]));
    x_size -= 1;
    dx = f64(dget(x_digits, x_size));
    while x_size > 0 {
        x_size -= 1;
        dx = dx * f64(PyLong_BASE) + f64(dget(x_digits, x_size));
    }

    dx /= 4.0 * EXP2_DBL_MANT_DIG;
    if dx == 1.0 {
        dx = 0.5;
        a_bits += 1;
    }
    return (-dx if long_is_negative(a) else dx, a_bits);
}

impl long_compare(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> i64 {
    if both_compact(a, b) {
        return compact_value(a) - compact_value(b);
    }
    sign = signed_digit_count(a) - signed_digit_count(b);
    if sign == 0 {
        i = digit_count(a) - 1;
        diff: i64 = 0;
        while i >= 0 {
            diff = i64(digit_at(a, i)) - i64(digit_at(b, i));
            if diff != 0 {
                break;
            }
            i -= 1;
        }
        sign = -diff if long_is_negative(a) else diff;
    }
    return sign;
}

impl long_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not both_long(self_, other) {
        return object_new_ref(Py_NotImplemented);
    }
    result: i64 = 0;
    if self_ != other {
        result = long_compare(long_of(self_), long_of(other));
    }
    return rich_compare_values(result, 0, op);
}

impl long_dealloc(self_: ptr[PyObject]) {
    if long_is_small_int(long_of(self_)) {
        _Py_SetImmortal(self_);
        return;
    }
    if long_check_exact(self_) and long_is_compact(long_of(self_)) {
        if not freelist_push(_Py_freelists_INTS, self_, Py_ints_MAXFREELIST) {
            PyObject_Free(ptr(self_));
        }
        return;
    }
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl long_hash(obj_: ptr[PyObject]) -> i64 {
    v = long_of(obj_);

    minus_one = ~u64(0);
    minus_two = ~u64(1);
    x = u64(0);
    if long_is_compact(v) {
        x = u64.wrap(compact_value(v));
        if x == minus_one {
            x = minus_two;
        }
        return i64.wrap(x);
    }
    i = digit_count(v) - 1;
    sign = long_sign_of(v);
    while i >= 0 {
        x = (wrapping_shl(x, u64(PyLong_SHIFT)) & _PyHASH_MODULUS)
            | (x >> u64(_PyHASH_BITS - PyLong_SHIFT));
        x += u64(digit_at(v, i));
        if x >= _PyHASH_MODULUS {
            x -= _PyHASH_MODULUS;
        }
        i -= 1;
    }

    x = wrapping_mul(x, u64.wrap(sign));
    if x == minus_one {
        x = minus_two;
    }
    return i64.wrap(x);
}

impl x_add(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject] {
    a = a_in;
    b = b_in;
    size_a = digit_count(a);
    size_b = digit_count(b);
    carry = u64(0);

    if size_a < size_b {
        a = b_in;
        b = a_in;
        size_temp = size_a;
        size_a = size_b;
        size_b = size_temp;
    }
    z = long_alloc(size_a + 1);
    if not z {
        return ptr[PyLongObject]();
    }
    i: i64 = 0;
    while i < size_b {
        carry += u64(digit_at(a, i)) + u64(digit_at(b, i));
        set_digit(z, i, u32.wrap(carry & PyLong_MASK));
        carry = carry >> PyLong_SHIFT;
        i += 1;
    }
    while i < size_a {
        carry += u64(digit_at(a, i));
        set_digit(z, i, u32.wrap(carry & PyLong_MASK));
        carry = carry >> PyLong_SHIFT;
        i += 1;
    }
    set_digit(z, i, u32.wrap(carry));
    return long_normalize(z);
}

impl x_sub(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject] {
    a = a_in;
    b = b_in;
    size_a = digit_count(a);
    size_b = digit_count(b);
    sign: i64 = 1;

    if size_a < size_b {
        sign = -1;
        a = b_in;
        b = a_in;
        size_temp = size_a;
        size_a = size_b;
        size_b = size_temp;
    } elif size_a == size_b {
        top = size_a - 1;
        while top >= 0 and digit_at(a, top) == digit_at(b, top) {
            top -= 1;
        }
        if top < 0 {
            return long_of(PyLong_FromLong(0));
        }
        if digit_at(a, top) < digit_at(b, top) {
            sign = -1;
            a = b_in;
            b = a_in;
        }
        size_a = top + 1;
        size_b = top + 1;
    }
    z = long_alloc(size_a);
    if not z {
        return ptr[PyLongObject]();
    }

    borrow: i64 = 0;
    i: i64 = 0;
    while i < size_b {
        borrow = i64(digit_at(a, i)) - i64(digit_at(b, i)) - borrow;
        set_digit(z, i, u32(borrow & PyLong_MASK_SIGNED));
        borrow = borrow >> PyLong_SHIFT;

        borrow &= 1;
        i += 1;
    }
    while i < size_a {
        borrow = i64(digit_at(a, i)) - borrow;
        set_digit(z, i, u32(borrow & PyLong_MASK_SIGNED));
        borrow = borrow >> PyLong_SHIFT;

        borrow &= 1;
        i += 1;
    }
    if sign < 0 {
        flip_sign(z);
    }
    return maybe_small_long(long_normalize(z));
}

impl long_add(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if both_compact(a, b) {
        return long_from_stwodigits(compact_value(a) + compact_value(b));
    }
    z = ptr[PyLongObject]();
    if long_is_negative(a) {
        if long_is_negative(b) {
            z = x_add(a, b);
            if z {
                flip_sign(z);
            }
        } else {
            z = x_sub(b, a);
        }
    } elif long_is_negative(b) {
        z = x_sub(a, b);
    } else {
        z = x_add(a, b);
    }
    return z;
}

impl long_add_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    return as_object(long_add(long_of(a), long_of(b)));
}

impl long_sub(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if both_compact(a, b) {
        return long_from_stwodigits(compact_value(a) - compact_value(b));
    }
    z = ptr[PyLongObject]();
    if long_is_negative(a) {
        if long_is_negative(b) {
            z = x_sub(b, a);
        } else {
            z = x_add(a, b);
            if z {
                flip_sign(z);
            }
        }
    } elif long_is_negative(b) {
        z = x_add(a, b);
    } else {
        z = x_sub(a, b);
    }
    return z;
}

impl long_sub_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    return as_object(long_sub(long_of(a), long_of(b)));
}

impl x_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject] {
    size_a = digit_count(a);
    size_b = digit_count(b);
    z = long_alloc(size_a + size_b);
    if not z {
        return ptr[PyLongObject]();
    }
    memset(ptr(ob_digits(z)), 0, u64(digit_count(z) * PyLong_DIGIT_SIZE));
    if a == b {
        paend = ob_digits(a) + size_a;
        for i in range(size_a) {
            f = u64(digit_at(a, i));
            pz = ob_digits(z) + (i << 1);
            pa = ob_digits(a) + i + 1;
            if PyErr_CheckSignals() != 0 {
                object_decref(as_object(z));
                return ptr[PyLongObject]();
            }
            carry = u64(dget(pz, 0)) + f * f;
            dset(pz, 0, u32.wrap(carry & PyLong_MASK));
            pz = pz + 1;
            carry = carry >> PyLong_SHIFT;

            f = f << u64(1);
            while pa < paend {
                carry += u64(dget(pz, 0)) + u64(dget(pa, 0)) * f;
                pa = pa + 1;
                dset(pz, 0, u32.wrap(carry & PyLong_MASK));
                pz = pz + 1;
                carry = carry >> PyLong_SHIFT;
            }
            if carry != u64(0) {
                carry += u64(dget(pz, 0));
                dset(pz, 0, u32.wrap(carry & PyLong_MASK));
                carry = carry >> PyLong_SHIFT;
                if carry != u64(0) {
                    dset(pz, 1, u32.wrap(carry));
                }
            }
        }
    } else {
        for i in range(size_a) {
            carry = u64(0);
            f = u64(digit_at(a, i));
            pz = ob_digits(z) + i;
            pb = ob_digits(b);
            pbend = ob_digits(b) + size_b;
            if PyErr_CheckSignals() != 0 {
                object_decref(as_object(z));
                return ptr[PyLongObject]();
            }
            while pb < pbend {
                carry += u64(dget(pz, 0)) + u64(dget(pb, 0)) * f;
                pb = pb + 1;
                dset(pz, 0, u32.wrap(carry & PyLong_MASK));
                pz = pz + 1;
                carry = carry >> PyLong_SHIFT;
            }
            if carry != u64(0) {
                dset(pz, 0, wrapping_add(dget(pz, 0), u32.wrap(carry & PyLong_MASK)));
            }
        }
    }
    return long_normalize(z);
}

impl kmul_split(
    n: ptr[PyLongObject], size: i64
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]] {
    size_n = digit_count(n);
    size_lo = min(size_n, size);
    size_hi = size_n - size_lo;
    hi = long_alloc(size_hi);
    if not hi {
        return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
    }
    lo = long_alloc(size_lo);
    if not lo {
        object_decref(as_object(hi));
        return (i32(-1), ptr[PyLongObject](), ptr[PyLongObject]());
    }
    memcpy(ptr(ob_digits(lo)), ptr(ob_digits(n)), u64(size_lo * PyLong_DIGIT_SIZE));
    memcpy(
        ptr(ob_digits(hi)),
        ptr(ob_digits(n) + size_lo),
        u64(size_hi * PyLong_DIGIT_SIZE)
    );
    return (i32(0), long_normalize(hi), long_normalize(lo));
}

impl k_mul_fail(
    ret: ptr[PyLongObject],
    ah: ptr[PyLongObject],
    al: ptr[PyLongObject],
    bh: ptr[PyLongObject],
    bl: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    object_xdecref(as_object(ret));
    object_xdecref(as_object(ah));
    object_xdecref(as_object(al));
    object_xdecref(as_object(bh));
    object_xdecref(as_object(bl));
    return ptr[PyLongObject]();
}

impl k_mul(a_in: ptr[PyLongObject], b_in: ptr[PyLongObject]) -> ptr[PyLongObject] {
    a = a_in;
    b = b_in;
    asize = digit_count(a);
    bsize = digit_count(b);
    nul = ptr[PyLongObject]();

    if asize > bsize {
        t1 = a;
        a = b;
        b = t1;
        i = asize;
        asize = bsize;
        bsize = i;
    }

    i = KARATSUBA_SQUARE_CUTOFF if a == b else KARATSUBA_CUTOFF;
    if asize <= i {
        if asize == 0 {
            return long_of(PyLong_FromLong(0));
        }
        return x_mul(a, b);
    }

    if 2 * asize <= bsize {
        return k_lopsided_mul(a, b);
    }

    shift = bsize >> 1;
    (split_a, ah, al) = kmul_split(a, shift);
    if split_a < 0 {
        return nul;
    }
    bh = nul;
    bl = nul;
    if a == b {
        bh = long_of(object_new_ref(as_object(ah)));
        bl = long_of(object_new_ref(as_object(al)));
    } else {
        (split_b, b_high, b_low) = kmul_split(b, shift);
        if split_b < 0 {
            return k_mul_fail(nul, ah, al, nul, nul);
        }
        bh = b_high;
        bl = b_low;
    }

    ret = long_alloc(asize + bsize);
    if not ret {
        return k_mul_fail(nul, ah, al, bh, bl);
    }
    rd = ob_digits(ret);

    t1 = k_mul(ah, bh);
    if not t1 {
        return k_mul_fail(ret, ah, al, bh, bl);
    }
    memcpy(
        ptr(rd + 2 * shift),
        ptr(ob_digits(t1)),
        u64(digit_count(t1) * PyLong_DIGIT_SIZE)
    );

    i = digit_count(ret) - 2 * shift - digit_count(t1);
    if i != 0 {
        memset(
            ptr(rd + 2 * shift + digit_count(t1)), i32(0), u64(i * PyLong_DIGIT_SIZE)
        );
    }

    t2 = k_mul(al, bl);
    if not t2 {
        object_decref(as_object(t1));
        return k_mul_fail(ret, ah, al, bh, bl);
    }
    memcpy(ptr(rd), ptr(ob_digits(t2)), u64(digit_count(t2) * PyLong_DIGIT_SIZE));

    i = 2 * shift - digit_count(t2);
    if i != 0 {
        memset(ptr(rd + digit_count(t2)), i32(0), u64(i * PyLong_DIGIT_SIZE));
    }

    i = digit_count(ret) - shift;
    v_isub(rd + shift, i, ob_digits(t2), digit_count(t2));
    decref_int(t2);
    v_isub(rd + shift, i, ob_digits(t1), digit_count(t1));
    decref_int(t1);

    t1 = x_add(ah, al);
    if not t1 {
        return k_mul_fail(ret, ah, al, bh, bl);
    }
    decref_int(ah);
    decref_int(al);
    if a == b {
        t2 = long_of(object_new_ref(as_object(t1)));
    } else {
        t2 = x_add(bh, bl);
        if not t2 {
            object_decref(as_object(t1));
            return k_mul_fail(ret, nul, nul, bh, bl);
        }
    }
    decref_int(bh);
    decref_int(bl);
    t3 = k_mul(t1, t2);
    decref_int(t1);
    decref_int(t2);
    if not t3 {
        return k_mul_fail(ret, nul, nul, nul, nul);
    }

    v_iadd(rd + shift, i, ob_digits(t3), digit_count(t3));
    decref_int(t3);
    return long_normalize(ret);
}

impl k_lopsided_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject] {
    asize = digit_count(a);
    bsize = digit_count(b);

    ret = long_alloc(asize + bsize);
    if not ret {
        return ptr[PyLongObject]();
    }
    memset(ptr(ob_digits(ret)), i32(0), u64(digit_count(ret) * PyLong_DIGIT_SIZE));

    bslice = long_alloc(asize);
    if not bslice {
        object_decref(as_object(ret));
        return ptr[PyLongObject]();
    }

    nbdone: i64 = 0;
    while bsize > 0 {
        nbtouse = min(bsize, asize);

        memcpy(
            ptr(ob_digits(bslice)),
            ptr(ob_digits(b) + nbdone),
            u64(nbtouse * PyLong_DIGIT_SIZE)
        );
        set_sign_and_digit_count(bslice, 1, nbtouse);
        product = k_mul(a, bslice);
        if not product {
            object_decref(as_object(ret));
            object_xdecref(as_object(bslice));
            return ptr[PyLongObject]();
        }

        v_iadd(
            ob_digits(ret) + nbdone,
            digit_count(ret) - nbdone,
            ob_digits(product),
            digit_count(product)
        );
        decref_int(product);
        bsize -= nbtouse;
        nbdone += nbtouse;
    }
    decref_int(bslice);
    return long_normalize(ret);
}

impl long_mul(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if both_compact(a, b) {
        v = compact_value(a) * compact_value(b);
        return long_from_stwodigits(v);
    }
    z = k_mul(a, b);

    if not same_sign(a, b) and z {
        z = long_negate(z);
    }
    return z;
}

impl long_mul_method(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    return as_object(long_mul(long_of(a), long_of(b)));
}

impl fast_mod(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
    left = i64(digit_at(a, 0));
    right = i64(digit_at(b, 0));
    mod: i64 = 0;
    sign = long_sign_of(b);
    if same_sign(a, b) {
        mod = left % right;
    } else {
        mod = right - 1 - (left - 1) % right;
    }
    return PyLong_FromLong(mod * sign);
}

impl fast_floor_div(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
    left = i64(digit_at(a, 0));
    right = i64(digit_at(b, 0));
    div: i64 = 0;
    if same_sign(a, b) {
        div = left // right;
    } else {
        div = -1 - (left - 1) // right;
    }
    return PyLong_FromLong(div);
}

impl pylong_int_divmod(
    v: ptr[PyLongObject], w: ptr[PyLongObject], want_div: bool, want_mod: bool
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]] {
    nul = ptr[PyLongObject]();
    mod = PyImport_ImportModule("_pylong");
    if not mod {
        return (i32(-1), nul, nul);
    }
    result = PyObject_CallMethod(mod, "int_divmod", "OO", as_object(v), as_object(w));
    object_decref(mod);
    if not result {
        return (i32(-1), nul, nul);
    }
    if not type_has_feature(object_type(result), Py_TPFLAGS_TUPLE_SUBCLASS)
        or object_size(result) != 2 {
        object_decref(result);
        PyErr_SetString(
            PyExc_ValueError, "tuple of length 2 is required from int_divmod()"
        );
        return (i32(-1), nul, nul);
    }
    q = tuple_get_item(result, 0);
    r = tuple_get_item(result, 1);
    if not long_check(q) or not long_check(r) {
        object_decref(result);
        PyErr_SetString(PyExc_ValueError, "tuple of int is required from int_divmod()");
        return (i32(-1), nul, nul);
    }
    pdiv = nul;
    pmod = nul;
    if want_div {
        pdiv = long_of(object_new_ref(q));
    }
    if want_mod {
        pmod = long_of(object_new_ref(r));
    }
    object_decref(result);
    return (i32(0), pdiv, pmod);
}

impl l_divmod(
    v: ptr[PyLongObject], w: ptr[PyLongObject], want_div: bool, want_mod: bool
) -> tuple[i32, ptr[PyLongObject], ptr[PyLongObject]] {
    nul = ptr[PyLongObject]();
    if digit_count(v) == 1 and digit_count(w) == 1 {
        fast_div = nul;
        if want_div {
            fast_div = long_of(fast_floor_div(v, w));
            if not fast_div {
                return (i32(-1), nul, nul);
            }
        }
        fast_rem = nul;
        if want_mod {
            fast_rem = long_of(fast_mod(v, w));
            if not fast_rem {
                object_xdecref(as_object(fast_div));
                return (i32(-1), nul, nul);
            }
        }

        return (i32(0), fast_div, fast_rem);
    }

    size_v = digit_count(v);
    size_w = digit_count(w);
    if size_w > 300 and (size_v - size_w) > 150 {
        return pylong_int_divmod(v, w, want_div, want_mod);
    }
    (status, div, mod) = long_divrem(v, w);
    if status < 0 {
        return (i32(-1), nul, nul);
    }
    if (long_is_negative(mod) and long_is_positive(w))
        or (long_is_positive(mod) and long_is_negative(w)) {
        temp = long_add(mod, w);
        old_mod = mod;
        mod = temp;
        object_decref(as_object(old_mod));
        if not mod {
            object_decref(as_object(div));
            return (i32(-1), nul, nul);
        }
        temp = long_sub(div, long_of(long_one()));
        if not temp {
            object_decref(as_object(mod));
            object_decref(as_object(div));
            return (i32(-1), nul, nul);
        }
        old_div = div;
        div = temp;
        object_decref(as_object(old_div));
    }
    if not want_div {
        object_decref(as_object(div));
        div = nul;
    }
    if not want_mod {
        object_decref(as_object(mod));
        mod = nul;
    }
    return (i32(0), div, mod);
}

impl l_mod(
    v: ptr[PyLongObject], w: ptr[PyLongObject]
) -> tuple[i32, ptr[PyLongObject]] {
    if digit_count(v) == 1 and digit_count(w) == 1 {
        fast_rem = long_of(fast_mod(v, w));
        return (i32(-1) if not fast_rem else i32(0), fast_rem);
    }
    (status, mod) = long_rem(v, w);
    if status < 0 {
        return (i32(-1), ptr[PyLongObject]());
    }
    if (long_is_negative(mod) and long_is_positive(w))
        or (long_is_positive(mod) and long_is_negative(w)) {
        temp = long_add(mod, w);
        old_mod = mod;
        mod = temp;
        object_decref(as_object(old_mod));
        if not mod {
            return (i32(-1), ptr[PyLongObject]());
        }
    }
    return (i32(0), mod);
}

impl long_div(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    if digit_count(long_of(a)) == 1 and digit_count(long_of(b)) == 1 {
        return fast_floor_div(long_of(a), long_of(b));
    }
    (status, div, unwanted) = l_divmod(long_of(a), long_of(b), True, False);
    if status < 0 {
        return NULL;
    }
    return as_object(div);
}

impl true_divide_zero(negate: bool) -> ptr[PyObject] {
    return PyFloat_FromDouble(-0.0 if negate else 0.0);
}

impl true_divide_overflow -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_OverflowError, "integer division result too large for a float"
    );
    return NULL;
}

impl long_true_divide(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(v, w) {
        return object_new_ref(Py_NotImplemented);
    }
    a = long_of(v);
    b = long_of(w);

    a_size = digit_count(a);
    b_size = digit_count(b);
    negate = long_is_negative(a) != long_is_negative(b);
    if b_size == 0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    if a_size == 0 {
        return true_divide_zero(negate);
    }

    a_is_small = a_size <= MANT_DIG_DIGITS
        or (
            a_size == MANT_DIG_DIGITS + 1
            and (digit_at(a, MANT_DIG_DIGITS) >> MANT_DIG_BITS) == u32(0)
        );
    b_is_small = b_size <= MANT_DIG_DIGITS
        or (
            b_size == MANT_DIG_DIGITS + 1
            and (digit_at(b, MANT_DIG_DIGITS) >> MANT_DIG_BITS) == u32(0)
        );
    if a_is_small and b_is_small {
        a_size -= 1;
        da = f64(digit_at(a, a_size));
        while a_size > 0 {
            a_size -= 1;
            da = da * f64(PyLong_BASE) + f64(digit_at(a, a_size));
        }
        b_size -= 1;
        db = f64(digit_at(b, b_size));
        while b_size > 0 {
            b_size -= 1;
            db = db * f64(PyLong_BASE) + f64(digit_at(b, b_size));
        }
        quotient = da / db;
        return PyFloat_FromDouble(-quotient if negate else quotient);
    }

    diff = a_size - b_size;
    if diff > PY_SSIZE_T_MAX // PyLong_SHIFT - 1 {
        return true_divide_overflow();
    } elif diff < 1 - PY_SSIZE_T_MAX // PyLong_SHIFT {
        return true_divide_zero(negate);
    }

    diff = diff * PyLong_SHIFT + bit_length_digit(digit_at(a, a_size - 1))
        - bit_length_digit(digit_at(b, b_size - 1));

    if diff > DBL_MAX_EXP {
        return true_divide_overflow();
    } elif diff < DBL_MIN_EXP - DBL_MANT_DIG - 1 {
        return true_divide_zero(negate);
    }

    shift = max(diff, DBL_MIN_EXP) - DBL_MANT_DIG - 2;
    inexact = u32(0);
    x = ptr[PyLongObject]();

    if shift <= 0 {
        shift_digits = (-shift) // PyLong_SHIFT;

        if a_size >= PY_SSIZE_T_MAX - 1 - shift_digits {
            PyErr_SetString(
                PyExc_OverflowError, "intermediate overflow during division"
            );
            return NULL;
        }
        x = long_alloc(a_size + shift_digits + 1);
        if not x {
            return NULL;
        }
        for i in range(shift_digits) {
            set_digit(x, i, u32(0));
        }
        rem = v_lshift(
            ob_digits(x) + shift_digits, ob_digits(a), a_size, (-shift) % PyLong_SHIFT
        );
        set_digit(x, a_size + shift_digits, rem);
    } else {
        shift_digits = shift // PyLong_SHIFT;
        x = long_alloc(a_size - shift_digits);
        if not x {
            return NULL;
        }
        rem = v_rshift(
            ob_digits(x),
            ob_digits(a) + shift_digits,
            a_size - shift_digits,
            shift % PyLong_SHIFT
        );
        if rem != u32(0) {
            inexact = u32(1);
        }
        while inexact == u32(0) and shift_digits > 0 {
            shift_digits -= 1;
            if digit_at(a, shift_digits) != u32(0) {
                inexact = u32(1);
            }
        }
    }
    long_normalize(x);
    x_size = signed_digit_count(x);

    if b_size == 1 {
        rem = inplace_divrem1(ob_digits(x), ob_digits(x), x_size, digit_at(b, 0));
        long_normalize(x);
        if rem != u32(0) {
            inexact = u32(1);
        }
    } else {
        (div, rem_obj) = x_divrem(x, b);
        old_x = x;
        x = div;
        object_decref(as_object(old_x));
        if not x {
            return NULL;
        }
        if not long_is_zero(rem_obj) {
            inexact = u32(1);
        }
        object_decref(as_object(rem_obj));
    }
    x_size = digit_count(x);

    x_bits = (x_size - 1) * PyLong_SHIFT + bit_length_digit(digit_at(x, x_size - 1));

    extra_bits = max(x_bits, DBL_MIN_EXP - shift) - DBL_MANT_DIG;

    mask = u32(1) << (extra_bits - 1);
    low = digit_at(x, 0) | inexact;
    if (low & mask) != u32(0) and (low & (u32(3) * mask - u32(1))) != u32(0) {
        low += mask;
    }
    set_digit(x, 0, low & ~(u32(2) * mask - u32(1)));

    x_size -= 1;
    dx = f64(digit_at(x, x_size));
    while x_size > 0 {
        x_size -= 1;
        dx = dx * f64(PyLong_BASE) + f64(digit_at(x, x_size));
    }
    object_decref(as_object(x));

    if shift + x_bits >= DBL_MAX_EXP
        and (shift + x_bits > DBL_MAX_EXP or dx == ldexp(1.0, i32(x_bits))) {
        return true_divide_overflow();
    }
    result = ldexp(dx, i32(shift));
    return PyFloat_FromDouble(-result if negate else result);
}

impl long_mod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    (status, mod) = l_mod(long_of(a), long_of(b));
    if status < 0 {
        return NULL;
    }
    return as_object(mod);
}

impl long_divmod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    (status, div, mod) = l_divmod(long_of(a), long_of(b), True, True);
    if status < 0 {
        return NULL;
    }
    z = PyTuple_New(2);
    if z {
        tuple_set_item(z, 0, as_object(div));
        tuple_set_item(z, 1, as_object(mod));
    } else {
        object_decref(as_object(div));
        object_decref(as_object(mod));
    }
    return z;
}

impl invmod_fail(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    n: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    object_decref(as_object(a));
    object_decref(as_object(b));
    object_decref(as_object(c));
    object_decref(as_object(n));
    return ptr[PyLongObject]();
}

impl long_invmod(
    a_in: ptr[PyLongObject], n_in: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    a = a_in;
    n = n_in;
    object_incref(as_object(a));
    b = long_of(object_new_ref(long_one()));
    c = long_of(object_new_ref(long_zero()));
    object_incref(as_object(n));

    while not long_is_zero(n) {
        (status, q, r) = l_divmod(a, n, True, True);
        if status == -1 {
            return invmod_fail(a, b, c, n);
        }
        old_a = a;
        a = n;
        object_decref(as_object(old_a));
        n = r;
        t = long_mul(q, c);
        object_decref(as_object(q));
        if not t {
            return invmod_fail(a, b, c, n);
        }
        s = long_sub(b, t);
        object_decref(as_object(t));
        if not s {
            return invmod_fail(a, b, c, n);
        }
        old_b = b;
        b = c;
        object_decref(as_object(old_b));
        c = s;
    }

    object_decref(as_object(c));
    object_decref(as_object(n));
    if long_compare(a, long_of(long_one())) != 0 {
        object_decref(as_object(a));
        object_decref(as_object(b));
        PyErr_SetString(
            PyExc_ValueError, "base is not invertible for the given modulus"
        );
        return ptr[PyLongObject]();
    }

    object_decref(as_object(a));
    return b;
}

impl pow_reduce(x: ptr[PyLongObject], c: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if c {
        (status, temp) = l_mod(x, c);
        object_xdecref(as_object(x));
        if status < 0 {
            return ptr[PyLongObject]();
        }
        return temp;
    }
    return x;
}

impl pow_mult(
    x: ptr[PyLongObject],
    y: ptr[PyLongObject],
    result: ptr[PyLongObject],
    c: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    temp = long_mul(x, y);
    object_xdecref(as_object(result));
    if not temp {
        return ptr[PyLongObject]();
    }
    return pow_reduce(temp, c);
}

impl pow_done(
    z: ptr[PyLongObject],
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject]
) -> ptr[PyObject] {
    object_decref(as_object(a));
    object_xdecref(as_object(b));
    object_xdecref(as_object(c));
    return as_object(z);
}

impl pow_binary(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    z_in: ptr[PyLongObject],
    i_in: i64,
    bi_in: u32
) -> ptr[PyLongObject] {
    i = i_in;
    bi = bi_in;
    z = long_of(object_new_ref(as_object(a)));
    object_decref(as_object(z_in));

    bit = u32(2);
    while True {
        if bit > bi {
            bit = bit >> u32(1);
            break;
        }
        bit = bit << u32(1);
    }
    i -= 1;
    bit = bit >> u32(1);
    while True {
        while bit != u32(0) {
            z = pow_mult(z, z, z, c);
            if not z {
                return z;
            }
            if (bi & bit) != u32(0) {
                z = pow_mult(z, a, z, c);
                if not z {
                    return z;
                }
            }
            bit = bit >> u32(1);
        }
        i -= 1;
        if i < 0 {
            break;
        }
        bi = digit_at(b, i);
        bit = u32(1) << u32(PyLong_SHIFT - 1);
    }
    return z;
}

impl pow_absorb(
    z_in: ptr[PyLongObject],
    table: ptr[ptr[PyLongObject]],
    pending_in: i64,
    blen_in: i64,
    c: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    z = z_in;
    pending = pending_in;
    blen = blen_in;

    ntz: i64 = 0;
    while (pending & 1) == 0 {
        ntz += 1;
        pending = pending >> 1;
    }
    blen -= ntz;
    while True {
        z = pow_mult(z, z, z, c);
        if not z {
            return z;
        }
        blen -= 1;
        if blen == 0 {
            break;
        }
    }
    z = pow_mult(z, (table + (pending >> 1)).view(1)[0], z, c);
    if not z {
        return z;
    }
    while ntz > 0 {
        ntz -= 1;
        z = pow_mult(z, z, z, c);
        if not z {
            return z;
        }
    }
    return z;
}

impl pow_kary_exit(
    z: ptr[PyLongObject], table: ptr[ptr[PyLongObject]], n: i64, a2: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    for i in range(n) {
        object_decref(as_object((table + i).view(1)[0]));
    }
    PyMem_Free(ptr(table));
    object_xdecref(as_object(a2));
    return z;
}

impl pow_kary(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    z_in: ptr[PyLongObject]
) -> ptr[PyLongObject] {
    z = z_in;
    table = ptr[ptr[PyLongObject]](PyMem_Calloc(u64(EXP_TABLE_LEN), u64(8)));
    if not table {
        object_decref(as_object(z));
        PyErr_NoMemory();
        return ptr[PyLongObject]();
    }
    (table + 0).view(1)[0] = long_of(object_new_ref(as_object(a)));
    num_table_entries: i64 = 1;

    a2 = pow_mult(a, a, ptr[PyLongObject](), c);
    if not a2 {
        object_decref(as_object(z));
        return pow_kary_exit(ptr[PyLongObject](), table, num_table_entries, a2);
    }

    for k in range(1, EXP_TABLE_LEN) {
        power = pow_mult((table + (k - 1)).view(1)[0], a2, ptr[PyLongObject](), c);
        if not power {
            object_decref(as_object(z));
            return pow_kary_exit(ptr[PyLongObject](), table, num_table_entries, a2);
        }
        (table + k).view(1)[0] = power;

        num_table_entries += 1;
    }
    object_decref(as_object(a2));
    a2 = ptr[PyLongObject]();

    pending: i64 = 0;
    blen: i64 = 0;
    i = signed_digit_count(b) - 1;
    while i >= 0 {
        bi = digit_at(b, i);
        j = PyLong_SHIFT - 1;
        while j >= 0 {
            bit = i64((bi >> u32(j)) & u32(1));
            pending = (pending << 1) | bit;
            if pending != 0 {
                blen += 1;
                if blen == EXP_WINDOW_SIZE {
                    z = pow_absorb(z, table, pending, blen, c);
                    if not z {
                        return pow_kary_exit(z, table, num_table_entries, a2);
                    }
                    pending = 0;
                    blen = 0;
                }
            } else {
                z = pow_mult(z, z, z, c);
                if not z {
                    return pow_kary_exit(z, table, num_table_entries, a2);
                }
            }
            j -= 1;
        }
        i -= 1;
    }
    if pending != 0 {
        z = pow_absorb(z, table, pending, blen, c);
    }
    return pow_kary_exit(z, table, num_table_entries, a2);
}

impl long_pow(v: ptr[PyObject], w: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    negative_output = False;

    if not both_long(v, w) {
        return object_new_ref(Py_NotImplemented);
    }
    a = long_of(object_new_ref(v));
    b = long_of(object_new_ref(w));
    c = ptr[PyLongObject]();
    if long_check(x) {
        c = long_of(object_new_ref(x));
    } elif x == Py_None {
        c = ptr[PyLongObject]();
    } else {
        object_decref(as_object(a));
        object_decref(as_object(b));
        return object_new_ref(Py_NotImplemented);
    }
    if long_is_negative(b) and not c {
        object_decref(as_object(a));
        object_decref(as_object(b));
        float_number = ptr[PyTypeObject](addressof(PyFloat_Type)).view(1)[
            0
        ].tp_as_number;
        return float_number.view(1)[0].nb_power(v, w, x);
    }
    if c {
        if long_is_zero(c) {
            PyErr_SetString(PyExc_ValueError, "pow() 3rd argument cannot be 0");
            return pow_done(ptr[PyLongObject](), a, b, c);
        }

        if long_is_negative(c) {
            negative_output = True;
            temp = long_of(_PyLong_Copy(c));
            if not temp {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
            object_decref(as_object(c));
            c = long_negate(temp);
            if not c {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
        }

        if long_is_nonnegative_compact(c) and digit_at(c, 0) == u32(1) {
            return pow_done(long_of(PyLong_FromLong(0)), a, b, c);
        }

        if long_is_negative(b) {
            temp = long_of(_PyLong_Copy(b));
            if not temp {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
            object_decref(as_object(b));
            b = long_negate(temp);
            if not b {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
            temp = long_invmod(a, c);
            if not temp {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
            object_decref(as_object(a));
            a = temp;
        }

        if long_is_negative(a) or digit_count(a) > digit_count(c) {
            (status, temp) = l_mod(a, c);
            if status < 0 {
                return pow_done(ptr[PyLongObject](), a, b, c);
            }
            object_decref(as_object(a));
            a = temp;
        }
    }

    z = long_of(PyLong_FromLong(1));
    if not z {
        return pow_done(z, a, b, c);
    }
    i = signed_digit_count(b);
    bi = digit_at(b, i - 1) if i != 0 else u32(0);
    if i <= 1 and bi <= u32(3) {
        if bi >= u32(2) {
            z = pow_mult(a, a, z, c);
            if z and bi == u32(3) {
                z = pow_mult(z, a, z, c);
            }
        } elif bi == u32(1) {
            z = pow_mult(a, z, z, c);
        }
    } elif i <= HUGE_EXP_CUTOFF // PyLong_SHIFT {
        z = pow_binary(a, b, c, z, i, bi);
    } else {
        z = pow_kary(a, b, c, z);
    }
    if not z {
        return pow_done(z, a, b, c);
    }
    if negative_output and not long_is_zero(z) {
        temp = long_sub(z, c);
        object_decref(as_object(z));
        z = temp;
    }
    return pow_done(z, a, b, c);
}

impl long_invert(self_: ptr[PyObject]) -> ptr[PyObject] {
    v = long_of(self_);

    if long_is_compact(v) {
        return as_object(long_from_stwodigits(-compact_value(v) - 1));
    }
    x = long_add(v, long_of(long_one()));
    if not x {
        return NULL;
    }
    x = long_negate(x);

    return as_object(x);
}

impl long_neg(v: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if long_is_compact(v) {
        return long_from_stwodigits(-compact_value(v));
    }
    z = long_of(_PyLong_Copy(v));
    if z {
        flip_sign(z);
    }
    return z;
}

impl long_neg_method(v: ptr[PyObject]) -> ptr[PyObject] {
    return as_object(long_neg(long_of(v)));
}

impl long_abs(v: ptr[PyLongObject]) -> ptr[PyLongObject] {
    if long_is_negative(v) {
        return long_neg(v);
    }
    return long_of(long_long(as_object(v)));
}

impl long_abs_method(v: ptr[PyObject]) -> ptr[PyObject] {
    return as_object(long_abs(long_of(v)));
}

impl long_bool(v: ptr[PyObject]) -> i32 {
    return i32(0) if long_is_zero(long_of(v)) else i32(1);
}

impl long_rshift1(
    a: ptr[PyLongObject], wordshift_in: i64, remshift_in: u32
) -> ptr[PyObject] {
    wordshift = wordshift_in;
    remshift = remshift_in;

    if long_is_compact(a) {
        m = compact_value(a);
        shift = remshift if wordshift == 0 else u32(PyLong_SHIFT);

        x = -((-m - 1) >> shift) - 1 if m < 0 else m >> shift;
        return as_object(long_from_stwodigits(x));
    }
    a_negative = long_is_negative(a);
    size_a = digit_count(a);
    if a_negative {
        if remshift == u32(0) {
            if wordshift == 0 {
                return long_long(as_object(a));
            }
            remshift = u32(PyLong_SHIFT);
            wordshift -= 1;
        }
    }
    newsize = size_a - wordshift;
    if newsize <= 0 {
        result: i64 = -1 if a_negative else 0;
        return PyLong_FromLong(result);
    }
    z = long_alloc(newsize);
    if not z {
        return NULL;
    }
    hishift = PyLong_SHIFT - i64(remshift);
    accum = u64(digit_at(a, wordshift));
    if a_negative {
        set_sign_and_digit_count(z, -1, newsize);
        sticky = u32(0);
        for j in range(wordshift) {
            sticky = sticky | digit_at(a, j);
        }
        accum += (PyLong_MASK >> u64(hishift))
            + (u64(1) if sticky != u32(0) else u64(0));
    }
    accum = accum >> u64(remshift);
    i: i64 = 0;
    j = wordshift + 1;
    while j < size_a {
        accum += u64(digit_at(a, j)) << u64(hishift);
        set_digit(z, i, u32.wrap(accum & PyLong_MASK));
        accum = accum >> u64(PyLong_SHIFT);
        i += 1;
        j += 1;
    }
    set_digit(z, newsize - 1, u32.wrap(accum));
    z = maybe_small_long(long_normalize(z));
    return as_object(z);
}

impl long_rshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    if long_is_negative(long_of(b)) {
        PyErr_SetString(PyExc_ValueError, "negative shift count");
        return NULL;
    }
    if long_is_zero(long_of(a)) {
        return PyLong_FromLong(0);
    }

    (shiftby, overflow) = long_as_long_long_and_overflow(b);
    if overflow != i32(0) {
        if long_is_negative(long_of(a)) {
            return PyLong_FromLong(-1);
        }
        return PyLong_FromLong(0);
    }
    if shiftby == -1 and PyErr_Occurred() {
        return NULL;
    }
    return _PyLong_Rshift(a, shiftby);
}

impl long_lshift1(
    a: ptr[PyLongObject], wordshift: i64, remshift: u32
) -> ptr[PyObject] {
    if wordshift == 0 and long_is_compact(a) {
        m = compact_value(a);

        x = -((-m) << remshift) if m < 0 else m << remshift;
        return as_object(long_from_stwodigits(x));
    }
    oldsize = digit_count(a);
    newsize = oldsize + wordshift;
    if remshift != u32(0) {
        newsize += 1;
    }
    z = long_alloc(newsize);
    if not z {
        return NULL;
    }
    if long_is_negative(a) {
        flip_sign(z);
    }
    for k in range(wordshift) {
        set_digit(z, k, u32(0));
    }
    accum = u64(0);
    i = wordshift;
    for j in range(oldsize) {
        accum = accum | (u64(digit_at(a, j)) << u64(remshift));
        set_digit(z, i, u32.wrap(accum & PyLong_MASK));
        accum = accum >> u64(PyLong_SHIFT);
        i += 1;
    }
    if remshift != u32(0) {
        set_digit(z, newsize - 1, u32.wrap(accum));
    }
    z = long_normalize(z);
    return as_object(maybe_small_long(z));
}

impl long_lshift_method(aa: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(aa, bb) {
        return object_new_ref(Py_NotImplemented);
    }
    a = long_of(aa);
    b = long_of(bb);
    if long_is_negative(b) {
        PyErr_SetString(PyExc_ValueError, "negative shift count");
        return NULL;
    }
    if long_is_zero(a) {
        return PyLong_FromLong(0);
    }

    (shiftby, overflow) = long_as_long_long_and_overflow(bb);
    if overflow != i32(0) {
        PyErr_SetString(PyExc_OverflowError, "too many digits in integer");
        return NULL;
    }
    if shiftby == -1 and PyErr_Occurred() {
        return NULL;
    }
    return long_lshift_int64(a, shiftby);
}

impl long_lshift_int64(a: ptr[PyLongObject], shiftby: i64) -> ptr[PyObject] {
    if long_is_zero(a) {
        return PyLong_FromLong(0);
    }

    wordshift = shiftby // PyLong_SHIFT;
    remshift = u32(shiftby % PyLong_SHIFT);
    return long_lshift1(a, wordshift, remshift);
}

impl v_complement(z: ptr[u32], a: ptr[u32], m: i64) {
    mask = u32(PyLong_MASK);
    carry = u32(1);
    for i in range(m) {
        carry += dget(a, i) ^ mask;
        dset(z, i, carry & mask);
        carry = carry >> u32(PyLong_SHIFT);
    }
}

impl long_bitwise(
    a_in: ptr[PyLongObject], op: u8, b_in: ptr[PyLongObject]
) -> ptr[PyObject] {
    a = a_in;
    b = b_in;

    size_a = digit_count(a);
    nega = long_is_negative(a);
    if nega {
        z = long_alloc(size_a);
        if not z {
            return NULL;
        }
        v_complement(ob_digits(z), ob_digits(a), size_a);
        a = z;
    } else {
        object_incref(as_object(a));
    }

    size_b = digit_count(b);
    negb = long_is_negative(b);
    if negb {
        z = long_alloc(size_b);
        if not z {
            object_decref(as_object(a));
            return NULL;
        }
        v_complement(ob_digits(z), ob_digits(b), size_b);
        b = z;
    } else {
        object_incref(as_object(b));
    }

    if size_a < size_b {
        swap = a;
        a = b;
        b = swap;
        size_swap = size_a;
        size_a = size_b;
        size_b = size_swap;
        neg_swap = nega;
        nega = negb;
        negb = neg_swap;
    }

    negz = False;
    size_z: i64 = 0;
    if op == u8(94) {
        negz = nega != negb;
        size_z = size_a;
    } elif op == u8(38) {
        negz = nega and negb;
        size_z = size_a if negb else size_b;
    } else {
        negz = nega or negb;
        size_z = size_b if negb else size_a;
    }

    z = long_alloc(size_z + (1 if negz else 0));
    if not z {
        object_decref(as_object(a));
        object_decref(as_object(b));
        return NULL;
    }

    if op == u8(38) {
        for i in range(size_b) {
            set_digit(z, i, digit_at(a, i) & digit_at(b, i));
        }
    } elif op == u8(124) {
        for i in range(size_b) {
            set_digit(z, i, digit_at(a, i) | digit_at(b, i));
        }
    } else {
        for i in range(size_b) {
            set_digit(z, i, digit_at(a, i) ^ digit_at(b, i));
        }
    }

    if op == u8(94) and negb {
        for i in range(size_b, size_z) {
            set_digit(z, i, digit_at(a, i) ^ u32(PyLong_MASK));
        }
    } elif size_b < size_z {
        memcpy(
            ptr(ob_digits(z) + size_b),
            ptr(ob_digits(a) + size_b),
            u64((size_z - size_b) * PyLong_DIGIT_SIZE)
        );
    }

    if negz {
        flip_sign(z);
        set_digit(z, size_z, u32(PyLong_MASK));
        v_complement(ob_digits(z), ob_digits(z), size_z + 1);
    }
    object_decref(as_object(a));
    object_decref(as_object(b));
    return as_object(maybe_small_long(long_normalize(z)));
}

impl long_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    x = long_of(a);
    y = long_of(b);
    if long_is_compact(x) and long_is_compact(y) {
        return as_object(long_from_stwodigits(compact_value(x) & compact_value(y)));
    }

    return long_bitwise(x, u8(38), y);
}

impl long_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    x = long_of(a);
    y = long_of(b);
    if long_is_compact(x) and long_is_compact(y) {
        return as_object(long_from_stwodigits(compact_value(x) ^ compact_value(y)));
    }

    return long_bitwise(x, u8(94), y);
}

impl long_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not both_long(a, b) {
        return object_new_ref(Py_NotImplemented);
    }
    x = long_of(a);
    y = long_of(b);
    if long_is_compact(x) and long_is_compact(y) {
        return as_object(long_from_stwodigits(compact_value(x) | compact_value(y)));
    }

    return long_bitwise(x, u8(124), y);
}

impl long_long(v: ptr[PyObject]) -> ptr[PyObject] {
    if long_check_exact(v) {
        return object_new_ref(v);
    }
    return _PyLong_Copy(long_of(v));
}

impl gcd_simple(a: ptr[PyLongObject], b: ptr[PyLongObject]) -> ptr[PyObject] {
    x = PyLong_AsLong(as_object(a));
    y = PyLong_AsLong(as_object(b));

    if x < 0 {
        x = -x;
    }
    if y < 0 {
        y = -y;
    }
    object_decref(as_object(a));
    object_decref(as_object(b));
    while y != 0 {
        t = y;
        y = x % y;
        x = t;
    }
    return PyLong_FromLong(x);
}

impl gcd_error(
    a: ptr[PyLongObject],
    b: ptr[PyLongObject],
    c: ptr[PyLongObject],
    d: ptr[PyLongObject]
) -> ptr[PyObject] {
    object_decref(as_object(a));
    object_decref(as_object(b));
    object_xdecref(as_object(c));
    object_xdecref(as_object(d));
    return NULL;
}

impl long_float(v: ptr[PyObject]) -> ptr[PyObject] {
    result = PyLong_AsDouble(v);
    if result == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    return PyFloat_FromDouble(result);
}

impl long_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], obase: ptr[PyObject]
) -> ptr[PyObject] {
    if type != long_type() {
        return long_subtype_new(type, x, obase);
    }
    if not x {
        if obase {
            PyErr_SetString(PyExc_TypeError, "int() missing string argument");
            return NULL;
        }
        return PyLong_FromLong(0);
    }

    if not obase {
        return PyNumber_Long(x);
    }
    base = PyNumber_AsSsize_t(obase, NULL);
    if base == -1 and PyErr_Occurred() {
        return NULL;
    }
    if (base != 0 and base < 2) or base > 36 {
        PyErr_SetString(PyExc_ValueError, "int() base must be >= 2 and <= 36, or 0");
        return NULL;
    }
    if type_has_feature(object_type(x), Py_TPFLAGS_UNICODE_SUBCLASS) {
        return PyLong_FromUnicodeObject(x, i32(base));
    }
    is_bytearray = object_type_check(x, ptr[PyTypeObject](addressof(PyByteArray_Type)));
    if is_bytearray or type_has_feature(object_type(x), Py_TPFLAGS_BYTES_SUBCLASS) {
        s = ptr[u8]();
        if is_bytearray {
            s = PyByteArray_AsString(x);
        } else {
            s = PyBytes_AsString(x);
        }
        return _PyLong_FromBytes(s, object_size(x), i32(base));
    }
    PyErr_SetString(
        PyExc_TypeError, "int() can't convert non-string with explicit base"
    );
    return NULL;
}

impl long_subtype_new(
    type: ptr[PyTypeObject], x: ptr[PyObject], obase: ptr[PyObject]
) -> ptr[PyObject] {
    tmp = long_of(long_new_impl(long_type(), x, obase));
    if not tmp {
        return NULL;
    }
    n = digit_count(tmp);

    if n == 0 {
        n = 1;
    }
    newobj = long_of(type.view(1)[0].tp_alloc(type, n));
    if not newobj {
        object_decref(as_object(tmp));
        return NULL;
    }
    set_long_tag(newobj, long_tag(tmp) & ~IMMORTALITY_BIT_MASK);
    for i in range(n) {
        set_digit(newobj, i, digit_at(tmp, i));
    }
    object_decref(as_object(tmp));
    return as_object(newobj);
}

impl long_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwargs {
        nargs = object_size(args);
        if nargs <= 2 {
            x = tuple_get_item(args, 0) if nargs >= 1 else NULL;
            obase = tuple_get_item(args, 1) if nargs >= 2 else NULL;
            return long_new_impl(type, x, obase);
        }
    }
    return invoke(
        long_new_signature, args, kwargs, long_new_bound, ptr[PyObject](type)
    );
}

impl long_new_bound(args: BoundArguments) -> ptr[PyObject] {
    return long_new_impl(
        ptr[PyTypeObject](args.context), args.values[0], args.values[1]
    );
}

impl int___getnewargs__(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(N)", _PyLong_Copy(long_of(self_)));
}

impl long_get0(_self: ptr[PyObject], _context: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

impl long_get1(_self: ptr[PyObject], _ignored: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(1);
}

impl int___format__(self_: ptr[PyObject], format_spec: ptr[PyObject]) -> ptr[PyObject] {
    if not type_has_feature(object_type(format_spec), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument("__format__", "argument", "str", format_spec);
        return NULL;
    }
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return NULL;
    }
    ret = _PyLong_FormatAdvancedWriter(
        ptr[_PyUnicodeWriter](writer),
        self_,
        format_spec,
        0,
        PyUnicode_GetLength(format_spec)
    );
    if ret == i32(-1) {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl divmod_near_fail(quo: ptr[PyLongObject], rem: ptr[PyLongObject]) -> ptr[PyObject] {
    object_xdecref(as_object(quo));
    object_xdecref(as_object(rem));
    return NULL;
}

impl int___round___impl(
    self_: ptr[PyObject], o_ndigits: ptr[PyObject]
) -> ptr[PyObject] {
    if o_ndigits == Py_None {
        return long_long(self_);
    }
    ndigits = _PyNumber_Index(o_ndigits);
    if not ndigits {
        return NULL;
    }

    if not long_is_negative(long_of(ndigits)) {
        object_decref(ndigits);
        return long_long(self_);
    }

    temp = as_object(long_neg(long_of(ndigits)));
    object_decref(ndigits);
    ndigits = temp;
    if not ndigits {
        return NULL;
    }
    result = PyLong_FromLong(10);
    if not result {
        object_decref(ndigits);
        return NULL;
    }
    temp = long_pow(result, ndigits, Py_None);
    object_decref(ndigits);
    object_decref(result);
    result = temp;
    if not result {
        return NULL;
    }
    temp = _PyLong_DivmodNear(self_, result);
    object_decref(result);
    result = temp;
    if not result {
        return NULL;
    }
    temp = as_object(long_sub(long_of(self_), long_of(tuple_get_item(result, 1))));
    object_decref(result);
    return temp;
}

impl int___round__(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("__round__", nargs, 0, 1) == 0 {
        return NULL;
    }
    o_ndigits = args.view(1)[0] if nargs >= 1 else Py_None;
    return int___round___impl(self_, o_ndigits);
}

impl int___sizeof___impl(self_: ptr[PyObject]) -> i64 {
    ndigits = digit_count(long_of(self_));
    if ndigits < 1 {
        ndigits = 1;
    }
    tp = object_type(self_);
    return tp.view(1)[0].tp_basicsize + tp.view(1)[0].tp_itemsize * ndigits;
}

impl int___sizeof__(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    size = int___sizeof___impl(self_);
    if size == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(size);
}

impl int_bit_length(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    nbits = _PyLong_NumBits(self_);
    return PyLong_FromInt64(nbits);
}

impl popcount_digit(d: u32) -> i32 {
    x = d;

    x = x - ((x >> 1) & u32(0x55555555));

    x = (x & u32(0x33333333)) + ((x >> 2) & u32(0x33333333));

    x = (x + (x >> 4)) & u32(0x0F0F0F0F);

    return i32(wrapping_mul(x, u32(0x01010101)) >> 24);
}

impl int_bit_count(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    z = long_of(self_);
    ndigits = digit_count(z);
    bit_count: i64 = 0;
    for i in range(ndigits) {
        bit_count += i64(popcount_digit(digit_at(z, i)));
    }
    return PyLong_FromInt64(bit_count);
}

impl int_as_integer_ratio(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    numerator = long_long(self_);
    if not numerator {
        return NULL;
    }
    ratio_tuple = PyTuple_Pack(2, numerator, long_one());
    object_decref(numerator);
    return ratio_tuple;
}

impl byteorder_little_endian(byteorder: ptr[PyObject]) -> i32 {
    if not byteorder {
        return i32(0);
    }
    if _PyUnicode_EqualToASCIIString(byteorder, ptr[u8]("little")) != 0 {
        return i32(1);
    }
    if _PyUnicode_EqualToASCIIString(byteorder, ptr[u8]("big")) != 0 {
        return i32(0);
    }
    PyErr_SetString(PyExc_ValueError, "byteorder must be either 'little' or 'big'");
    return i32(-1);
}

impl int_to_bytes_impl(
    self_: ptr[PyObject], length: i64, byteorder: ptr[PyObject], is_signed: i32
) -> ptr[PyObject] {
    little_endian = byteorder_little_endian(byteorder);
    if little_endian < i32(0) {
        return NULL;
    }
    if length < 0 {
        PyErr_SetString(PyExc_ValueError, "length argument must be non-negative");
        return NULL;
    }
    as_bytes = PyBytes_FromStringAndSize(ptr[u8](), length);
    if not as_bytes {
        return NULL;
    }
    if _PyLong_AsByteArray(
        self_, PyBytes_AsString(as_bytes), u64(length), little_endian, is_signed, 1
    )
        < i32(0) {
        object_decref(as_bytes);
        return NULL;
    }
    return as_bytes;
}

impl int_to_bytes_convert(
    self_: ptr[PyObject],
    length_arg: ptr[PyObject],
    byteorder_arg: ptr[PyObject],
    signed_arg: ptr[PyObject]
) -> ptr[PyObject] {
    length: i64 = 1;
    byteorder = NULL;
    is_signed = i32(0);
    if length_arg {
        ival: i64 = -1;
        iobj = _PyNumber_Index(length_arg);
        if iobj {
            ival = PyLong_AsSsize_t(iobj);
            object_decref(iobj);
        }
        if ival == -1 and PyErr_Occurred() {
            return NULL;
        }
        length = ival;
    }
    if byteorder_arg {
        if not type_has_feature(
            object_type(byteorder_arg), Py_TPFLAGS_UNICODE_SUBCLASS
        ) {
            _PyArg_BadArgument(
                "to_bytes", "argument 'byteorder'", "str", byteorder_arg
            );
            return NULL;
        }
        byteorder = byteorder_arg;
    }
    if signed_arg {
        is_signed = PyObject_IsTrue(signed_arg);
        if is_signed < i32(0) {
            return NULL;
        }
    }
    return int_to_bytes_impl(self_, length, byteorder, is_signed);
}

impl int_to_bytes(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        length_arg = args.view(1)[0] if nargs >= 1 else NULL;
        byteorder_arg = (args + 1).view(1)[0] if nargs >= 2 else NULL;
        return int_to_bytes_convert(self_, length_arg, byteorder_arg, NULL);
    }
    return invoke_vector(
        int_to_bytes_signature, args, nargs, kwnames, int_to_bytes_bound, self_
    );
}

impl int_to_bytes_bound(args: BoundArguments) -> ptr[PyObject] {
    return int_to_bytes_convert(
        args.context, args.values[0], args.values[1], args.values[2]
    );
}

impl int_from_bytes_impl(
    type: ptr[PyTypeObject],
    bytes_obj: ptr[PyObject],
    byteorder: ptr[PyObject],
    is_signed: i32
) -> ptr[PyObject] {
    little_endian = byteorder_little_endian(byteorder);
    if little_endian < i32(0) {
        return NULL;
    }
    as_bytes = PyObject_Bytes(bytes_obj);
    if not as_bytes {
        return NULL;
    }
    long_obj = _PyLong_FromByteArray(
        PyBytes_AsString(as_bytes), u64(object_size(as_bytes)), little_endian, is_signed
    );
    object_decref(as_bytes);
    if long_obj and type != long_type() {
        converted = PyObject_CallOneArg(ptr[PyObject](type), long_obj);
        object_decref(long_obj);
        long_obj = converted;
    }
    return long_obj;
}

impl int_from_bytes_convert(
    type: ptr[PyObject],
    bytes_obj: ptr[PyObject],
    byteorder_arg: ptr[PyObject],
    signed_arg: ptr[PyObject]
) -> ptr[PyObject] {
    byteorder = NULL;
    is_signed = i32(0);
    if byteorder_arg {
        if not type_has_feature(
            object_type(byteorder_arg), Py_TPFLAGS_UNICODE_SUBCLASS
        ) {
            _PyArg_BadArgument(
                "from_bytes", "argument 'byteorder'", "str", byteorder_arg
            );
            return NULL;
        }
        byteorder = byteorder_arg;
    }
    if signed_arg {
        is_signed = PyObject_IsTrue(signed_arg);
        if is_signed < i32(0) {
            return NULL;
        }
    }
    return int_from_bytes_impl(
        ptr[PyTypeObject](type), bytes_obj, byteorder, is_signed
    );
}

impl int_from_bytes(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs >= 1 and nargs <= 2 {
        byteorder_arg = (args + 1).view(1)[0] if nargs >= 2 else NULL;
        return int_from_bytes_convert(type, args.view(1)[0], byteorder_arg, NULL);
    }
    return invoke_vector(
        int_from_bytes_signature, args, nargs, kwnames, int_from_bytes_bound, type
    );
}

impl int_from_bytes_bound(args: BoundArguments) -> ptr[PyObject] {
    return int_from_bytes_convert(
        args.context, args.values[0], args.values[1], args.values[2]
    );
}

impl long_long_meth(self_: ptr[PyObject], _ignored: ptr[PyObject]) -> ptr[PyObject] {
    return long_long(self_);
}

impl long_long_getter(self_: ptr[PyObject], _ignored: ptr) -> ptr[PyObject] {
    return long_long(self_);
}

impl int_is_integer(_self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(1);
}

impl long_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if kwnames {
        tstate = current_tstate();
        return _PyObject_MakeTpCall(tstate, type, args, nargs, kwnames);
    }
    if nargs == 0 {
        return long_zero();
    }
    if nargs == 1 {
        return PyNumber_Long(args.view(1)[0]);
    }
    if nargs == 2 {
        return long_new_impl(
            ptr[PyTypeObject](type), args.view(1)[0], (args + 1).view(1)[0]
        );
    }
    PyErr_Format(PyExc_TypeError, "int expected at most 2 arguments, got %zd", nargs);
    return NULL;
}
