"""Conversions to Decimal of the _decimal module.

Modules/_decimal/_decimal.c's conversions from str, int, float, tuple and
Decimal, the implicit conversions of arithmetic operands and the conversions
for comparison with rationals, in native Jac. Exact conversions use the
maximal context and signal InvalidOperation when the value does not fit.
See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_is_float,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_release,
    NULL,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyList_AsTuple,
    PyLongExport,
    PyLong_AsLong,
    PyLong_AsSsize_t,
    PyLong_Export,
    PyLong_FreeExport,
    PyLong_GetNativeLayout,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_IsInstance,
    PyTuple_GetItem,
    PyTuple_Size,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    _PyUnicode_IsWhitespace,
    _PyUnicode_ToDecimalDigit
}
import from jaclang.runtime.python.object_model.complex { PyComplex_AsCComplex }
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.modules.numeric { copysign, isinf, isnan }
import from jaclang.runtime.python.modules.mpdecimal {
    MPD_Clamped,
    MPD_Conversion_syntax,
    MPD_Errors,
    MPD_INF,
    MPD_Inexact,
    MPD_Invalid_operation,
    MPD_NAN,
    MPD_NEG,
    MPD_POS,
    MPD_Rounded,
    mpd_context_t,
    mpd_del,
    mpd_isnan,
    mpd_isspecial,
    mpd_qcopy,
    mpd_qfinalize,
    mpd_qimport_u16,
    mpd_qimport_u32,
    mpd_qmul,
    mpd_qncopy,
    mpd_qnew,
    mpd_qpow,
    mpd_qset_i64,
    mpd_qset_ssize,
    mpd_qset_string,
    mpd_qset_uint,
    mpd_set_flags,
    mpd_set_sign,
    mpd_setdigits,
    mpd_seterror,
    mpd_setspecial,
    mpd_t
}
import from jaclang.runtime.python.modules.decimal_objects {
    MPD_Float_operation,
    PyComplex_Type,
    PyFloat_Type,
    Py_EQ_OP,
    Py_NE_OP,
    STATE_RATIONAL,
    builtin_methods,
    context_or_current,
    ctx_of,
    current_context_borrowed,
    dec_addstatus,
    dec_alloc,
    dec_check,
    dec_check_exact,
    dec_type,
    dec_type_new,
    max_context,
    module_of_context,
    module_of_type,
    mpd,
    state_value,
    type_check
}

# ---------------------------------------------------------------------------
# From strings.

"""The ASCII form of a numeric str as a PyMem_Malloc'd C string: characters
in [1, 127] are kept, Unicode spaces become ' ' and Unicode digits their
ASCII digit. With `strip_ws`, leading and trailing whitespace is stripped;
with `ignore_underscores`, underscores are dropped. An empty string when an
invalid character is found (which triggers ConversionSyntax); NULL with
MemoryError."""
def numeric_as_ascii(
    u: ptr[PyObject], strip_ws: bool, ignore_underscores: bool
) -> ptr[u8] {
    length = PyUnicode_GetLength(u);
    result = ptr[u8](PyMem_Malloc(u64(length + 1)));
    if not result {
        PyErr_NoMemory();
        return result;
    }
    j: i64 = 0;
    if strip_ws {
        while length > 0
            and _PyUnicode_IsWhitespace(PyUnicode_ReadChar(u, length - 1)) != 0 {
            length -= 1;
        }
        while j < length and _PyUnicode_IsWhitespace(PyUnicode_ReadChar(u, j)) != 0 {
            j += 1;
        }
    }
    cp = 0;
    while j < length {
        ch = PyUnicode_ReadChar(u, j);
        j += 1;
        if ignore_underscores and ch == u32(95) {
            continue;
        }
        if u32(0) < ch and ch <= u32(127) {
            (result + cp).view(1)[0] = u8(ch);
            cp += 1;
            continue;
        }
        if _PyUnicode_IsWhitespace(ch) != 0 {
            (result + cp).view(1)[0] = u8(32);
            cp += 1;
            continue;
        }
        d = _PyUnicode_ToDecimalDigit(ch);
        if d < 0 {
            # empty string triggers ConversionSyntax
            result.view(1)[0] = u8(0);
            return result;
        }
        (result + cp).view(1)[0] = u8(48 + int(d));
        cp += 1;
    }
    (result + cp).view(1)[0] = u8(0);
    return result;
}

"""A new Decimal of `type` from a C string, using the context."""
def dec_type_from_cstring(
    type: ptr[PyObject], s: ptr[u8], context: ptr[PyObject]
) -> ptr[PyObject] {
    dec = dec_type_new(module_of_context(context), type);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_string(mpd(dec), s, ctx_of(context), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

"""A new Decimal of `type` from a C string, converted exactly or set to NaN
with InvalidOperation."""
def dec_type_from_cstring_exact(
    type: ptr[PyObject], s: ptr[u8], context: ptr[PyObject]
) -> ptr[PyObject] {
    dec = dec_type_new(module_of_context(context), type);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_string(mpd(dec), s, addressof(max_context), &mut status);
    if (status & (MPD_Inexact | MPD_Rounded | MPD_Clamped)) != u32(0) {
        # we want exact results
        mpd_seterror(mpd(dec), MPD_Invalid_operation, &mut status);
    }
    status = status & MPD_Errors;
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

def dec_type_from_unicode(
    type: ptr[PyObject], u: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    s = numeric_as_ascii(u, False, False);
    if not s {
        return NULL;
    }
    dec = dec_type_from_cstring(type, s, context);
    PyMem_Free(ptr(s));
    return dec;
}

"""Exact conversion of a str, which may have leading and trailing whitespace
and underscores."""
def dec_type_from_unicode_exact_ws(
    type: ptr[PyObject], u: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    s = numeric_as_ascii(u, True, True);
    if not s {
        return NULL;
    }
    dec = dec_type_from_cstring_exact(type, s, context);
    PyMem_Free(ptr(s));
    return dec;
}

# ---------------------------------------------------------------------------
# From integers.

"""_dec_settriple: set a Decimal to sign, a one-word coefficient and an
exponent without any error checking."""
def dec_settriple(dec: ptr[PyObject], sign: u8, v: u32, exp: i64) {
    record = mpd(dec).view(1);
    record[0].data.view(1)[0] = u64(v);
    record[0].len = 1;
    mpd_set_flags(mpd(dec), sign);
    mpd(dec).view(1)[0].exp = exp;
    mpd_setdigits(mpd(dec));
}

def dec_type_from_ssize(
    type: ptr[PyObject], v: i64, context: ptr[PyObject]
) -> ptr[PyObject] {
    dec = dec_type_new(module_of_context(context), type);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_ssize(mpd(dec), v, ctx_of(context), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

def dec_type_from_ssize_exact(
    type: ptr[PyObject], v: i64, context: ptr[PyObject]
) -> ptr[PyObject] {
    dec = dec_type_new(module_of_context(context), type);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_ssize(mpd(dec), v, addressof(max_context), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

"""A Decimal converted from an int and the flags the conversion raised,
which go to no Context yet."""
obj LongConversion {
    has dec: ptr[PyObject] = NULL,
        status: u32 = 0;
}

"""A new Decimal of `type` from an int through PyLong_Export(), in context
`ctx`."""
def dec_from_long(
    module: ptr[PyObject],
    type: ptr[PyObject],
    v: ptr[PyObject],
    ctx: ptr[mpd_context_t]
) -> LongConversion {
    result = LongConversion();
    dec = dec_type_new(module, type);
    if not dec {
        return result;
    }
    export_long = PyLongExport();
    if PyLong_Export(v, &mut export_long) == -1 {
        jacpy_release(dec);
        return result;
    }
    raised: u32 = 0;
    if export_long.digits {
        layout = PyLong_GetNativeLayout().view(1);
        base = u32(1) << u32(layout[0].bits_per_digit);
        sign = MPD_NEG if export_long.negative != 0 else MPD_POS;
        count = u64(export_long.ndigits);
        if layout[0].digit_size == 4 {
            mpd_qimport_u32(
                mpd(dec),
                ptr[u32](export_long.digits),
                count,
                sign,
                base,
                ctx,
                &mut raised
            );
        } else {
            mpd_qimport_u16(
                mpd(dec),
                ptr[u16](export_long.digits),
                count,
                sign,
                base,
                ctx,
                &mut raised
            );
        }
        PyLong_FreeExport(&mut export_long);
    } else {
        mpd_qset_i64(mpd(dec), export_long.value, ctx, &mut raised);
    }
    result.dec = dec;
    result.status = raised;
    return result;
}

"""A new Decimal of `type` from an int, in the context."""
def dec_type_from_long(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_long(v) == 0 {
        PyErr_SetString(PyExc_TypeError, "argument must be an integer");
        return NULL;
    }
    converted = dec_from_long(module_of_context(context), type, v, ctx_of(context));
    dec = converted.dec;
    if not dec {
        return NULL;
    }
    status = converted.status;
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

"""A new Decimal of `type` from an int, converted exactly or set to NaN with
InvalidOperation."""
def dec_type_from_long_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_long(v) == 0 {
        PyErr_SetString(PyExc_TypeError, "argument must be an integer");
        return NULL;
    }
    converted = dec_from_long(
        module_of_context(context), type, v, addressof(max_context)
    );
    dec = converted.dec;
    if not dec {
        return NULL;
    }
    status = converted.status;
    if (status & (MPD_Inexact | MPD_Rounded | MPD_Clamped)) != u32(0) {
        # we want exact results
        mpd_seterror(mpd(dec), MPD_Invalid_operation, &mut status);
    }
    status = status & MPD_Errors;
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

# ---------------------------------------------------------------------------
# From floats.

"""A new Decimal of `type` from an int or float, exactly: n * 5**k * 10**-k
for the float's ratio n / 2**k."""
def dec_type_from_float_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_context(context);
    if jacpy_is_long(v) != 0 {
        return dec_type_from_long_exact(type, v, context);
    }
    if jacpy_is_float(v) == 0 {
        PyErr_SetString(PyExc_TypeError, "argument must be int or float");
        return NULL;
    }
    x = PyFloat_AsDouble(v);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    sign = MPD_POS if copysign(1.0, x) == 1.0 else MPD_NEG;
    if isnan(x) or isinf(x) {
        dec = dec_type_new(module, type);
        if not dec {
            return NULL;
        }
        if isnan(x) {
            # decimal.py calls repr(float(+-nan)), which always gives a
            # positive result.
            mpd_setspecial(mpd(dec), MPD_POS, MPD_NAN);
        } else {
            mpd_setspecial(mpd(dec), sign, MPD_INF);
        }
        return dec;
    }
    # absolute value of the float
    tmp = addressof(PyFloat_Type).view(1)[0].tp_as_number.view(1)[0].nb_absolute(v);
    if not tmp {
        return NULL;
    }
    # float as integer ratio: numerator/denominator
    n_d = addressof(builtin_methods).view(1)[0].float_as_integer_ratio(tmp, NULL);
    jacpy_release(tmp);
    if not n_d {
        return NULL;
    }
    n = PyTuple_GetItem(n_d, 0);
    d = PyTuple_GetItem(n_d, 1);
    bits = addressof(builtin_methods).view(1)[0].long_bit_length(d, NULL);
    if not bits {
        jacpy_release(n_d);
        return NULL;
    }
    k = PyLong_AsSsize_t(bits);
    jacpy_release(bits);
    if k == -1 and PyErr_Occurred() {
        jacpy_release(n_d);
        return NULL;
    }
    k -= 1;
    dec = dec_type_from_long_exact(type, n, context);
    jacpy_release(n_d);
    if not dec {
        return NULL;
    }
    d1 = mpd_qnew();
    if not d1 {
        jacpy_release(dec);
        PyErr_NoMemory();
        return NULL;
    }
    d2 = mpd_qnew();
    if not d2 {
        mpd_del(d1);
        jacpy_release(dec);
        PyErr_NoMemory();
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_uint(d1, 5, addressof(max_context), &mut status);
    mpd_qset_ssize(d2, k, addressof(max_context), &mut status);
    mpd_qpow(d1, d1, d2, addressof(max_context), &mut status);
    if dec_addstatus(context, status) {
        mpd_del(d1);
        mpd_del(d2);
        jacpy_release(dec);
        return NULL;
    }
    # result = n * 5**k
    mpd_qmul(mpd(dec), mpd(dec), d1, addressof(max_context), &mut status);
    mpd_del(d1);
    mpd_del(d2);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    # result = +- n * 5**k * 10**-k
    mpd_set_sign(mpd(dec), sign);
    mpd(dec).view(1)[0].exp = -k;
    return dec;
}

def dec_type_from_float(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    dec = dec_type_from_float_exact(type, v, context);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qfinalize(mpd(dec), ctx_of(context), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

# ---------------------------------------------------------------------------
# From Decimals and tuples.

def dec_type_from_decimal_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_context(context);
    if type == dec_type(module) and dec_check_exact(module, v) {
        return Py_NewRef(v);
    }
    dec = dec_type_new(module, type);
    if not dec {
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy(mpd(dec), mpd(v), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(dec);
        return NULL;
    }
    return dec;
}

"""A tuple or a list as a tuple (new reference), else `mesg` as `ex`."""
def sequence_as_tuple(v: ptr[PyObject], ex: ptr[PyObject], mesg: str) -> ptr[PyObject] {
    if jacpy_is_tuple(v) != 0 {
        return Py_NewRef(v);
    }
    if jacpy_is_list(v) != 0 {
        return PyList_AsTuple(v);
    }
    PyErr_SetString(ex, mesg);
    return NULL;
}

"""The string form of a DecimalTuple (sign, digits, exponent) as a
PyMem_Malloc'd C string, or NULL with an error set."""
def dectuple_as_str(dectuple: ptr[PyObject]) -> ptr[u8] {
    if PyTuple_Size(dectuple) != 3 {
        PyErr_SetString(PyExc_ValueError, "argument must be a sequence of length 3");
        return ptr[u8]();
    }
    # sign
    tmp = PyTuple_GetItem(dectuple, 0);
    if jacpy_is_long(tmp) == 0 {
        PyErr_SetString(
            PyExc_ValueError, "sign must be an integer with the value 0 or 1"
        );
        return ptr[u8]();
    }
    sign = PyLong_AsLong(tmp);
    if sign == -1 and PyErr_Occurred() {
        return ptr[u8]();
    }
    if sign != 0 and sign != 1 {
        PyErr_SetString(
            PyExc_ValueError, "sign must be an integer with the value 0 or 1"
        );
        return ptr[u8]();
    }
    sign_special = "-" if sign != 0 else "+";
    is_infinite = False;
    is_special = False;
    exp: i64 = 0;
    # exponent or encoding for a special number
    tmp = PyTuple_GetItem(dectuple, 2);
    if jacpy_is_unicode(tmp) != 0 {
        # special
        code = unicode_code(tmp);
        is_special = True;
        if code == "F" {
            sign_special += "Inf";
            is_infinite = True;
        } elif code == "n" {
            sign_special += "NaN";
        } elif code == "N" {
            sign_special += "sNaN";
        } else {
            PyErr_SetString(
                PyExc_ValueError,
                "string argument in the third position must be 'F', 'n' or 'N'"
            );
            return ptr[u8]();
        }
    } else {
        # exponent
        if jacpy_is_long(tmp) == 0 {
            PyErr_SetString(PyExc_ValueError, "exponent must be an integer");
            return ptr[u8]();
        }
        exp = PyLong_AsSsize_t(tmp);
        if exp == -1 and PyErr_Occurred() {
            return ptr[u8]();
        }
    }
    # coefficient
    digits = sequence_as_tuple(
        PyTuple_GetItem(dectuple, 1),
        PyExc_ValueError,
        "coefficient must be a tuple of digits"
    );
    if not digits {
        return ptr[u8]();
    }
    tsize = int(PyTuple_Size(digits));
    # [sign][coeffdigits+1][E][-][expdigits+1]['\0']
    mem = 1 + tsize + 3 + 19 + 2;
    decstring = ptr[u8](PyMem_Malloc(u64(mem)));
    if not decstring {
        jacpy_release(digits);
        PyErr_NoMemory();
        return decstring;
    }
    cp = 0;
    for character in sign_special {
        (decstring + cp).view(1)[0] = u8(ord(character));
        cp += 1;
    }
    if tsize == 0 and not is_special {
        # empty tuple: zero coefficient, except for special numbers
        (decstring + cp).view(1)[0] = u8(48);
        cp += 1;
    }
    for i in range(tsize) {
        item = PyTuple_GetItem(digits, i64(i));
        if jacpy_is_long(item) == 0 {
            PyErr_SetString(PyExc_ValueError, "coefficient must be a tuple of digits");
            jacpy_release(digits);
            PyMem_Free(ptr(decstring));
            return ptr[u8]();
        }
        l = PyLong_AsLong(item);
        if l == -1 and PyErr_Occurred() {
            jacpy_release(digits);
            PyMem_Free(ptr(decstring));
            return ptr[u8]();
        }
        if l < 0 or l > 9 {
            PyErr_SetString(PyExc_ValueError, "coefficient must be a tuple of digits");
            jacpy_release(digits);
            PyMem_Free(ptr(decstring));
            return ptr[u8]();
        }
        if is_infinite {
            # accept but ignore any well-formed coefficient for compatibility
            # with decimal.py
            continue;
        }
        (decstring + cp).view(1)[0] = u8(48 + int(l));
        cp += 1;
    }
    if not is_special {
        # not a special number
        (decstring + cp).view(1)[0] = u8(69);
        cp += 1;
        for character in str(exp) {
            (decstring + cp).view(1)[0] = u8(ord(character));
            cp += 1;
        }
    }
    (decstring + cp).view(1)[0] = u8(0);
    jacpy_release(digits);
    return decstring;
}

"""The text of a one-character str (or "" for anything longer)."""
def unicode_code(value: ptr[PyObject]) -> str {
    if PyUnicode_GetLength(value) != 1 {
        return "";
    }
    return chr(int(PyUnicode_ReadChar(value, 0)));
}

def dec_type_from_sequence(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    dectuple = sequence_as_tuple(
        v, PyExc_TypeError, "argument must be a tuple or list"
    );
    if not dectuple {
        return NULL;
    }
    s = dectuple_as_str(dectuple);
    jacpy_release(dectuple);
    if not s {
        return NULL;
    }
    dec = dec_type_from_cstring(type, s, context);
    PyMem_Free(ptr(s));
    return dec;
}

def dec_type_from_sequence_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    dectuple = sequence_as_tuple(
        v, PyExc_TypeError, "argument must be a tuple or list"
    );
    if not dectuple {
        return NULL;
    }
    s = dectuple_as_str(dectuple);
    jacpy_release(dectuple);
    if not s {
        return NULL;
    }
    dec = dec_type_from_cstring_exact(type, s, context);
    PyMem_Free(ptr(s));
    return dec;
}

def unsupported_conversion(v: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_Format(
        PyExc_TypeError,
        "conversion from %s to Decimal is not supported",
        object_type(v).view(1)[0].tp_name
    );
    return NULL;
}

"""A Decimal, int or float `v` as a Decimal of `type`, exactly."""
def dec_type_from_number_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_type(type);
    if dec_check(module, v) {
        return dec_type_from_decimal_exact(type, v, context);
    } elif jacpy_is_long(v) != 0 {
        return dec_type_from_long_exact(type, v, context);
    } elif jacpy_is_float(v) != 0 {
        if dec_addstatus(context, MPD_Float_operation) {
            return NULL;
        }
        return dec_type_from_float_exact(type, v, context);
    }
    return unsupported_conversion(v);
}

"""Apply the context to a Decimal: a new rounded copy."""
def dec_apply(v: ptr[PyObject], context: ptr[PyObject]) -> ptr[PyObject] {
    result = dec_alloc(module_of_context(context));
    if not result {
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy(mpd(result), mpd(v), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    mpd_qfinalize(mpd(result), ctx_of(context), &mut status);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""Anything the Decimal constructor accepts (NULL for no value) as a Decimal
of `type`, exactly."""
def dec_type_from_object_exact(
    type: ptr[PyObject], v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_context(context);
    if not v {
        return dec_type_from_ssize_exact(type, 0, context);
    } elif dec_check(module, v) {
        return dec_type_from_decimal_exact(type, v, context);
    } elif jacpy_is_unicode(v) != 0 {
        return dec_type_from_unicode_exact_ws(type, v, context);
    } elif jacpy_is_long(v) != 0 {
        return dec_type_from_long_exact(type, v, context);
    } elif jacpy_is_tuple(v) != 0 or jacpy_is_list(v) != 0 {
        return dec_type_from_sequence_exact(type, v, context);
    } elif jacpy_is_float(v) != 0 {
        if dec_addstatus(context, MPD_Float_operation) {
            return NULL;
        }
        return dec_type_from_float_exact(type, v, context);
    }
    return unsupported_conversion(v);
}

"""context.create_decimal(v): the conversion rounds to the context."""
def dec_from_object(v: ptr[PyObject], context: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_context(context);
    type = dec_type(module);
    if not v {
        return dec_type_from_ssize(type, 0, context);
    } elif dec_check(module, v) {
        ctx = ctx_of(context).view(1);
        if mpd_isnan(mpd(v)) != 0
            and mpd(v).view(1)[0].digits > ctx[0].prec - i64(ctx[0].clamp) {
            # Special case: too many NaN payload digits
            if dec_addstatus(context, MPD_Conversion_syntax) {
                return NULL;
            }
            result = dec_alloc(module);
            if not result {
                return NULL;
            }
            mpd_setspecial(mpd(result), MPD_POS, MPD_NAN);
            return result;
        }
        return dec_apply(v, context);
    } elif jacpy_is_unicode(v) != 0 {
        return dec_type_from_unicode(type, v, context);
    } elif jacpy_is_long(v) != 0 {
        return dec_type_from_long(type, v, context);
    } elif jacpy_is_tuple(v) != 0 or jacpy_is_list(v) != 0 {
        return dec_type_from_sequence(type, v, context);
    } elif jacpy_is_float(v) != 0 {
        if dec_addstatus(context, MPD_Float_operation) {
            return NULL;
        }
        return dec_type_from_float(type, v, context);
    }
    return unsupported_conversion(v);
}

# ---------------------------------------------------------------------------
# Implicit conversions to Decimal.

"""convert_op: a Decimal operand as a new reference, an int converted
exactly, else NotImplemented (new reference) or, with `type_err`, NULL with
TypeError. Callers stop on NULL and NotImplemented and return them."""
def convert_op(
    type_err: bool, v: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_context(context);
    if dec_check(module, v) {
        return Py_NewRef(v);
    }
    if jacpy_is_long(v) != 0 {
        return dec_type_from_long_exact(dec_type(module), v, context);
    }
    if type_err {
        return unsupported_conversion(v);
    }
    return Py_NewRef(Py_NotImplemented);
}

"""Whether a converted operand stops the operation (NULL or
NotImplemented)."""
def failed_operand(operand: ptr[PyObject]) -> bool {
    return not operand or operand == Py_NotImplemented;
}

# ---------------------------------------------------------------------------
# Implicit conversions to Decimal for comparison.

"""v * denominator(r) for comparing a finite Decimal with a rational;
computed with the exponent dropped and put back, so it cannot overflow."""
def multiply_by_denominator(
    v: ptr[PyObject], r: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    tmp = PyObject_GetAttrString(r, "denominator");
    if not tmp {
        return NULL;
    }
    module = module_of_context(context);
    denom = dec_type_from_long_exact(dec_type(module), tmp, context);
    jacpy_release(tmp);
    if not denom {
        return NULL;
    }
    vv = mpd_qncopy(mpd(v));
    if not vv {
        jacpy_release(denom);
        PyErr_NoMemory();
        return NULL;
    }
    result = dec_alloc(module);
    if not result {
        jacpy_release(denom);
        mpd_del(vv);
        return NULL;
    }
    # Prevent Overflow in the multiplication; the result is only used in
    # mpd_qcmp, which handles values technically out of bounds.
    exp = vv.view(1)[0].exp;
    vv.view(1)[0].exp = 0;
    status: u32 = 0;
    mpd_qmul(mpd(result), vv, mpd(denom), addressof(max_context), &mut status);
    mpd(result).view(1)[0].exp = exp;
    jacpy_release(denom);
    mpd_del(vv);
    # Any status makes the result invalid (very unlikely).
    if status != u32(0) {
        PyErr_SetString(PyExc_ValueError, "exact conversion for comparison failed");
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def numerator_as_decimal(r: ptr[PyObject], context: ptr[PyObject]) -> ptr[PyObject] {
    tmp = PyObject_GetAttrString(r, "numerator");
    if not tmp {
        return NULL;
    }
    num = dec_type_from_long_exact(dec_type(module_of_context(context)), tmp, context);
    jacpy_release(tmp);
    return num;
}

"""The operands of a comparison: `v` a Decimal and `w` the other object,
both converted (a rational scales `v` by its denominator). `ok` with new
references in `v` and `w`; otherwise `w` is NULL (error) or NotImplemented
(new reference)."""
obj ComparisonOperands {
    has v: ptr[PyObject] = NULL,
        w: ptr[PyObject] = NULL,
        ok: bool = False;
}

def convert_op_cmp(
    v: ptr[PyObject], w: ptr[PyObject], op: int, context: ptr[PyObject]
) -> ComparisonOperands {
    result = ComparisonOperands(v=v);
    module = module_of_context(context);
    ctx = ctx_of(context).view(1);
    if dec_check(module, w) {
        result.w = Py_NewRef(w);
    } elif jacpy_is_long(w) != 0 {
        result.w = dec_type_from_long_exact(dec_type(module), w, context);
    } elif jacpy_is_float(w) != 0 {
        if op != Py_EQ_OP
            and op != Py_NE_OP
            and dec_addstatus(context, MPD_Float_operation) {
            result.w = NULL;
        } else {
            ctx[0].status = ctx[0].status | MPD_Float_operation;
            result.w = dec_type_from_float_exact(dec_type(module), w, context);
        }
    } elif type_check(w, ptr[PyObject](addressof(PyComplex_Type)))
        and (op == Py_EQ_OP or op == Py_NE_OP) {
        c = PyComplex_AsCComplex(w);
        if c.real == -1.0 and PyErr_Occurred() {
            result.w = NULL;
        } elif c.imag == 0.0 {
            tmp = PyFloat_FromDouble(c.real);
            if not tmp {
                result.w = NULL;
            } else {
                ctx[0].status = ctx[0].status | MPD_Float_operation;
                result.w = dec_type_from_float_exact(dec_type(module), tmp, context);
                jacpy_release(tmp);
            }
        } else {
            result.w = Py_NewRef(Py_NotImplemented);
        }
    } else {
        is_rational = PyObject_IsInstance(w, state_value(module, STATE_RATIONAL));
        if is_rational < 0 {
            result.w = NULL;
        } elif is_rational > 0 {
            result.w = numerator_as_decimal(w, context);
            if result.w and mpd_isspecial(mpd(v)) == 0 {
                result.v = multiply_by_denominator(v, w, context);
                if not result.v {
                    jacpy_release(result.w);
                    result.w = NULL;
                }
            }
        } else {
            result.w = Py_NewRef(Py_NotImplemented);
        }
    }
    if failed_operand(result.w) {
        return result;
    }
    if result.v == v {
        Py_NewRef(v);
    }
    result.ok = True;
    return result;
}
