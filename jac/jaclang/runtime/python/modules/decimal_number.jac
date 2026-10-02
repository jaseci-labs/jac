"""The decimal.Decimal type of the _decimal module.

Modules/_decimal/_decimal.c's Decimal implementation in native Jac: the
constructor, string conversion and formatting, the conversions to int, float,
tuple and integer ratio, the number protocol, the methods, comparison and
hashing. Arithmetic uses the current context unless a method takes one.
See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_is_dict,
    jacpy_is_long,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_release,
    jacpy_unicode_decode_bytes,
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    PyDict_GetItemWithError,
    PyDict_Size,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyErr_WarnEx,
    PyExc_DeprecationWarning,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFloat_AsDouble,
    PyFloat_FromString,
    PyImport_ImportModuleAttrString,
    PyLongWriter,
    PyLongWriter_Create,
    PyLongWriter_Finish,
    PyLong_AsSsize_t,
    PyLong_FromInt64,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLong,
    PyLong_GetNativeLayout,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_CallOneArg,
    PyObject_GC_UnTrack,
    PyObject_GenericHash,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Size,
    PyTuple_Pack,
    PyTuple_SetItem,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_AsUTF8String,
    PyUnicode_DecodeASCII,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_FromWideChar,
    _PyLong_GCD
}
import from jaclang.runtime.python.object_model.complex { PyComplex_FromDoubles }
import from jaclang.runtime.python.layouts { PyTypeObject }
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_length,
    c_string_text
}
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat, ArgumentValue }
import from jaclang.runtime.python.bindings.module { visit_reference }
import from jaclang.runtime.python.modules.mpdecimal {
    MPD_CONST_DATA,
    MPD_Malloc_error,
    MPD_POS,
    MPD_ROUND_CEILING,
    MPD_ROUND_DOWN,
    MPD_ROUND_FLOOR,
    MPD_ROUND_HALF_EVEN,
    MPD_SSIZE_MAX,
    MPD_SSIZE_MIN,
    MPD_STATIC,
    MPD_UINT_SIZE,
    mpd_adjexp,
    mpd_arith_sign,
    mpd_class,
    mpd_clear_flags,
    mpd_context_t,
    mpd_del,
    mpd_free_memory,
    mpd_isdynamic_data,
    mpd_isinfinite,
    mpd_isnan,
    mpd_isnegative,
    mpd_ispositive,
    mpd_isqnan,
    mpd_isspecial,
    mpd_issnan,
    mpd_iszero,
    mpd_parse_fmt_str,
    mpd_qcmp,
    mpd_qcopy,
    mpd_qcopy_abs,
    mpd_qcopy_negate,
    mpd_qcopy_sign,
    mpd_qdivmod,
    mpd_qexport_u16,
    mpd_qexport_u32,
    mpd_qformat_spec,
    mpd_qget_i64,
    mpd_qget_ssize,
    mpd_qmul,
    mpd_qncopy,
    mpd_qnew,
    mpd_qpow,
    mpd_qpowmod,
    mpd_qquantize,
    mpd_qrem,
    mpd_qround_to_int,
    mpd_qround_to_intx,
    mpd_qset_uint,
    mpd_qsetround,
    mpd_qsset_ssize,
    mpd_same_quantum,
    mpd_set_positive,
    mpd_sign,
    mpd_spec_t,
    mpd_t,
    mpd_to_eng_size,
    mpd_to_sci,
    mpd_to_sci_size,
    mpd_validate_lconv
}
import from jaclang.runtime.python.modules.decimal_ops {
    OP_ABS,
    OP_ADD,
    OP_DIV,
    OP_DIVINT,
    OP_MINUS,
    OP_MUL,
    OP_PLUS,
    OP_REM,
    OP_SUB,
    binary_op,
    bool_op,
    fma_op,
    total_op,
    unary_op
}
import from jaclang.runtime.python.modules.decimal_objects {
    PyDecObject,
    PyFloat_Type,
    PyLong_Type,
    Py_EQ_OP,
    Py_GE_OP,
    Py_GT_OP,
    Py_LE_OP,
    Py_LT_OP,
    Py_NE_OP,
    STATE_DECIMAL_TUPLE,
    STATE_PYDECIMAL,
    bool_object,
    context_or_current,
    ctx_caps,
    ctx_of,
    current_context_borrowed,
    dec_addstatus,
    dec_alloc,
    dec_type,
    free_work_context,
    getround,
    hash_context,
    internal_error_ptr,
    max_context,
    module_of,
    module_of_left_or_right,
    module_of_ternary,
    module_of_type,
    mpd,
    state_value,
    work_context
}
import from jaclang.runtime.python.modules.decimal_convert {
    convert_op,
    convert_op_cmp,
    dec_settriple,
    dec_type_from_float_exact,
    dec_type_from_number_exact,
    dec_type_from_object_exact,
    failed_operand
}
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_set }

import from c {
    def mbstowcs(dest: ptr[i32], src: ptr[u8], n: u64) -> u64;
    # The constants of the hash: the modulus 2**61 - 1, the inverse of 10
    # modulo it, and ten, as static constant mpd_t values.
    glob:priv hash_p_data: list[u64] = [u64(2305843009213693951)],
         hash_inv10_p_data: list[u64] = [u64(2075258708292324556)],
         hash_ten_data: list[u64] = [u64(10)]; glob:priv hash_p: mpd_t = mpd_t(
             flags=MPD_POS | MPD_STATIC | MPD_CONST_DATA,
             exp=0,
             digits=19,
             len=1,
             alloc=1,
             data=ptr[u64](addressof(hash_p_data))
         ),
         hash_inv10_p: mpd_t = mpd_t(
             flags=MPD_POS | MPD_STATIC | MPD_CONST_DATA,
             exp=0,
             digits=19,
             len=1,
             alloc=1,
             data=ptr[u64](addressof(hash_inv10_p_data))
         ),
         hash_ten: mpd_t = mpd_t(
             flags=MPD_POS | MPD_STATIC | MPD_CONST_DATA,
             exp=0,
             digits=2,
             len=1,
             alloc=1,
             data=ptr[u64](addressof(hash_ten_data))
         );
}

glob:priv PY_HASH_INF: Final[int] = 314159,
     INT_MAX: Final[int] = 2147483647,
     SIZE_MAX: Final[u64] = 0xFFFFFFFFFFFFFFFF;

# ---------------------------------------------------------------------------
# Argument parsing.

"""PyArg_ParseTupleAndKeywords() with `units` over `keywords`, or None with
the error set."""
def parse_keywords(
    args: ptr[PyObject], kwds: ptr[PyObject], units: str, keywords: list[str]
) -> (list[ArgumentValue] | None) {
    if not kwds or PyDict_Size(kwds) == 0 {
        fast = positional_objects(args, units);
        if fast is not None {
            return fast;
        }
    }
    try {
        return ArgumentFormat().parse_keywords(args, kwds, units, keywords);
    } except boundary_failure {
        return None;
    }
}

"""PyArg_ParseTuple() with `units`, or None with the error set."""
def parse_tuple(args: ptr[PyObject], units: str) -> (list[ArgumentValue] | None) {
    fast = positional_objects(args, units);
    if fast is not None {
        return fast;
    }
    try {
        return ArgumentFormat().parse(args, units);
    } except boundary_failure {
        return None;
    }
}

"""The common case of the object-only formats _decimal parses ("O", "|"):
positional arguments within the arity, taken without ArgumentFormat's
per-call format analysis. None (with no error set) for any other call,
which the caller hands to ArgumentFormat for Python/getargs.c's errors."""
def positional_objects(
    args: ptr[PyObject], units: str
) -> (list[ArgumentValue] | None) {
    maximum = len(units);
    minimum = maximum;
    bar = units.find("|");
    if bar >= 0 {
        minimum = bar;
        maximum -= 1;
    }
    count = int(PyTuple_Size(args));
    if count < minimum or count > maximum {
        return None;
    }
    values: list[ArgumentValue] = [];
    for i in range(maximum) {
        if i < count {
            values.append(
                ArgumentValue(given=True, object=PyTuple_GetItem(args, i64(i)))
            );
        } else {
            values.append(ArgumentValue());
        }
    }
    return values;
}

"""An optional object argument, or `fallback` when it was not given."""
def given_or(value: ArgumentValue, fallback: ptr[PyObject]) -> ptr[PyObject] {
    return value.object if value.given else fallback;
}

# ---------------------------------------------------------------------------
# Allocation.

def dec_traverse(dec: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(dec)), visitor, arg);
}

def dec_dealloc(dec: ptr[PyObject]) {
    tp = object_type(dec);
    PyObject_GC_UnTrack(ptr(dec));
    from_libmpdec = mpd(dec);
    mpd_del(from_libmpdec);
    tp.view(1)[0].tp_free(ptr(dec));
    jacpy_release(ptr[PyObject](tp));
}

"""Decimal(value="0", context=None)."""
def dec_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|OO", ["value", "context"]);
    if values is None {
        return NULL;
    }
    module = module_of_type(ptr[PyObject](type));
    context = context_or_current(module, given_or(values[1], Py_None));
    if not context {
        return NULL;
    }
    v = values[0].object if values[0].given else NULL;
    return dec_type_from_object_exact(ptr[PyObject](type), v, context);
}

"""Decimal.from_float(f) (class method)."""
def dec_from_float(type: ptr[PyObject], pyfloat: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_type(type);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    result = dec_type_from_float_exact(dec_type(module), pyfloat, context);
    if type != dec_type(module) and result {
        converted = PyObject_CallOneArg(type, result);
        jacpy_release(result);
        result = converted;
    }
    return result;
}

"""Decimal.from_number(number) (class method)."""
def dec_from_number(type: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_type(type);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    result = dec_type_from_number_exact(dec_type(module), number, context);
    if type != dec_type(module) and result {
        converted = PyObject_CallOneArg(type, result);
        jacpy_release(result);
        result = converted;
    }
    return result;
}

# ---------------------------------------------------------------------------
# Conversions from decimal.

"""A str of the `size` ASCII bytes at `s`."""
def unicode_fromascii(s: ptr[u8], size: i64) -> ptr[PyObject] {
    return PyUnicode_DecodeASCII(ptr(s), size, ptr[u8]());
}

"""str(): the default module context only gives the value of `capitals`."""
def dec_str(dec: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(dec));
    if not context {
        return NULL;
    }
    cp = ptr[u8]();
    size = mpd_to_sci_size(&mut cp, mpd(dec), ctx_caps(context));
    if size < 0 {
        PyErr_NoMemory();
        return NULL;
    }
    result = unicode_fromascii(cp, size);
    mpd_free_memory(ptr(cp));
    return result;
}

def dec_repr(dec: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(dec));
    if not context {
        return NULL;
    }
    cp = mpd_to_sci(mpd(dec), ctx_caps(context));
    if not cp {
        PyErr_NoMemory();
        return NULL;
    }
    result = PyUnicode_FromFormat("Decimal('%s')", cp);
    mpd_free_memory(ptr(cp));
    return result;
}

"""A copy of `size` bytes, NUL-terminated, in PyMem_Malloc memory."""
def dec_strdup(src: ptr[u8], size: i64) -> ptr[u8] {
    dest = ptr[u8](PyMem_Malloc(u64(size + 1)));
    if not dest {
        PyErr_NoMemory();
        return dest;
    }
    jacpy_memory_copy(ptr(dest), ptr(src), size);
    (dest + size).view(1)[0] = u8(0);
    return dest;
}

"""Put back the NUL fill characters that were replaced by 0xff."""
def dec_replace_fillchar(dest: ptr[u8], size: i64) {
    for i in range(int(size)) {
        if (dest + i).view(1)[0] == u8(0xff) {
            (dest + i).view(1)[0] = u8(0);
        }
    }
}

"""A decimal_point or thousands_sep that may be multibyte or in [128, 255]
as UTF-8 bytes (new reference)."""
def dotsep_as_utf8(s: ptr[u8]) -> ptr[PyObject] {
    buf = ptr[i32](PyMem_Malloc(8));
    if not buf {
        PyErr_NoMemory();
        return NULL;
    }
    n = mbstowcs(buf, s, 2);
    if n != u64(1) {
        # Issue #7442
        PyMem_Free(ptr(buf));
        PyErr_SetString(
            PyExc_ValueError,
            "invalid decimal point or unsupported combination of LC_CTYPE and LC_NUMERIC"
        );
        return NULL;
    }
    tmp = PyUnicode_FromWideChar(buf, i64(n));
    PyMem_Free(ptr(buf));
    if not tmp {
        return NULL;
    }
    utf8 = PyUnicode_AsUTF8String(tmp);
    jacpy_release(tmp);
    return utf8;
}

"""One override of format(): dict[key] as UTF-8 bytes (new reference) whose
address replaces the spec field, NULL when the key is absent; `failed` on
error."""
obj OverrideValue {
    has value: ptr[PyObject] = NULL,
        failed: bool = False;
}

def dict_get_item_string(dict: ptr[PyObject], key: str) -> OverrideValue {
    result = OverrideValue();
    keyobj = PyUnicode_FromString(key);
    if not keyobj {
        result.failed = True;
        return result;
    }
    value = PyDict_GetItemWithError(dict, keyobj);
    jacpy_release(keyobj);
    if not value {
        result.failed = bool(PyErr_Occurred());
        return result;
    }
    result.value = PyUnicode_AsUTF8String(value);
    result.failed = not result.value;
    return result;
}

"""The _pydecimal fallback for format specifiers libmpdec does not support."""
def pydec_format(
    dec: ptr[PyObject],
    context: ptr[PyObject],
    fmt: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject] {
    pydecimal = state_value(module, STATE_PYDECIMAL);
    if not pydecimal {
        pydecimal = PyImport_ImportModuleAttrString("_pydecimal", "Decimal");
        if not pydecimal {
            return NULL;
        }
        jacpy_binding_state_set(module, i64(STATE_PYDECIMAL), pydecimal);
        jacpy_release(pydecimal);
    }
    u = dec_str(dec);
    if not u {
        return NULL;
    }
    pydec = PyObject_CallOneArg(pydecimal, u);
    jacpy_release(u);
    if not pydec {
        return NULL;
    }
    result = PyObject_CallMethod(pydec, "__format__", "(OO)", fmt, context);
    jacpy_release(pydec);
    if not result and PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
        # Do not confuse users with the _pydecimal exception
        PyErr_Clear();
        PyErr_SetString(PyExc_ValueError, "invalid format string");
    }
    return result;
}

"""Whether a C string needs converting to UTF-8: longer than one byte, or
one non-ASCII byte."""
def needs_utf8(s: ptr[u8]) -> bool {
    n = c_string_length(s);
    return n > 1 or (n == 1 and s.view(1)[0] >= u8(128));
}

"""__format__(format_spec, override=None)."""
def dec_format(dec: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(dec);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    values = parse_tuple(args, "O|O");
    if values is None {
        return NULL;
    }
    fmtarg = values[0].object;
    overrides = values[1].object if values[1].given else NULL;
    if jacpy_is_unicode(fmtarg) == 0 {
        PyErr_SetString(PyExc_TypeError, "format arg must be str");
        return NULL;
    }
    size: i64 = 0;
    fmt = PyUnicode_AsUTF8AndSize(fmtarg, &mut size);
    if not fmt {
        return NULL;
    }
    if size > 0 and (fmt + (size - 1)).view(1)[0] == u8(78) {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "Format specifier 'N' is deprecated and slated for removal in Python 3.18",
            1
        )
            < 0 {
            return NULL;
        }
    }
    replace_fillchar = False;
    if size > 0 and fmt.view(1)[0] == u8(0) {
        # NUL fill character: must be replaced with a valid UTF-8 char
        # before calling mpd_parse_fmt_str().
        replace_fillchar = True;
        fmt = dec_strdup(fmt, size);
        if not fmt {
            return NULL;
        }
        fmt.view(1)[0] = u8(95);
    }
    spec = mpd_spec_t();
    if mpd_parse_fmt_str(&mut spec, fmt, ctx_caps(context)) == 0 {
        if replace_fillchar {
            PyMem_Free(ptr(fmt));
        }
        return pydec_format(dec, context, fmtarg, module);
    }
    if replace_fillchar {
        # The placeholder must be an invalid UTF-8 byte, so reversing the
        # substitution cannot clobber a UTF-8 separator or decimal point.
        spec.fill_0 = u8(0xff);
        spec.fill_1 = u8(0);
    }
    result = format_with_spec(dec, context, spec, overrides);
    if replace_fillchar {
        PyMem_Free(ptr(fmt));
    }
    return result;
}

"""The formatting after the spec is parsed: the overrides or locale
separators, then mpd_qformat_spec()."""
def:priv format_with_spec(
    dec: ptr[PyObject],
    context: ptr[PyObject],
    spec: mpd_spec_t,
    overrides: ptr[PyObject]
) -> ptr[PyObject] {
    dot: ptr[PyObject] = NULL;
    sep: ptr[PyObject] = NULL;
    grouping: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    failed = False;
    if overrides {
        # Values for decimal_point, thousands_sep and grouping can be given
        # in the overrides dict; they take precedence over localeconv(). The
        # feature is not documented and is only used in test_decimal.
        if jacpy_is_dict(overrides) == 0 {
            PyErr_SetString(PyExc_TypeError, "optional argument must be a dict");
            return NULL;
        }
        found = dict_get_item_string(overrides, "decimal_point");
        dot = found.value;
        failed = found.failed;
        if dot {
            spec.dot = ptr[u8](jacpy_bytes_address(dot));
        }
        if not failed {
            found = dict_get_item_string(overrides, "thousands_sep");
            sep = found.value;
            failed = found.failed;
            if sep {
                spec.sep = ptr[u8](jacpy_bytes_address(sep));
            }
        }
        if not failed {
            found = dict_get_item_string(overrides, "grouping");
            grouping = found.value;
            failed = found.failed;
            if grouping {
                spec.grouping = ptr[u8](jacpy_bytes_address(grouping));
            }
        }
        if not failed and mpd_validate_lconv(&mut spec) < 0 {
            PyErr_SetString(PyExc_ValueError, "invalid override dict");
            failed = True;
        }
    } else {
        # fix locale dependent non-ascii characters
        if needs_utf8(spec.dot) {
            dot = dotsep_as_utf8(spec.dot);
            failed = not dot;
            if dot {
                spec.dot = ptr[u8](jacpy_bytes_address(dot));
            }
        }
        if not failed and needs_utf8(spec.sep) {
            sep = dotsep_as_utf8(spec.sep);
            failed = not sep;
            if sep {
                spec.sep = ptr[u8](jacpy_bytes_address(sep));
            }
        }
    }
    if not failed {
        status: u32 = 0;
        decstring = mpd_qformat_spec(mpd(dec), &spec, ctx_of(context), &mut status);
        if not decstring {
            if (status & MPD_Malloc_error) != u32(0) {
                PyErr_NoMemory();
            } else {
                PyErr_SetString(
                    PyExc_ValueError,
                    "format specification exceeds internal limits of _decimal"
                );
            }
        } else {
            size = i64(c_string_length(decstring));
            if spec.fill_0 == u8(0xff) and spec.fill_1 == u8(0) {
                dec_replace_fillchar(decstring, size);
            }
            payload = jacpy_bytes_from_memory(ptr(decstring), size);
            if payload {
                result = jacpy_unicode_decode_bytes(payload, "utf-8");
                jacpy_release(payload);
            }
            mpd_free_memory(ptr(decstring));
        }
    }
    jacpy_release(grouping);
    jacpy_release(sep);
    jacpy_release(dot);
    return result;
}

"""An int from a Decimal, rounded with `round`; the context precision is not
observed."""
def dec_as_long(
    dec: ptr[PyObject], context: ptr[PyObject], round: i32
) -> ptr[PyObject] {
    if mpd_isspecial(mpd(dec)) != 0 {
        if mpd_isnan(mpd(dec)) != 0 {
            PyErr_SetString(PyExc_ValueError, "cannot convert NaN to integer");
        } else {
            PyErr_SetString(PyExc_OverflowError, "cannot convert Infinity to integer");
        }
        return NULL;
    }
    x = mpd_qnew();
    if not x {
        PyErr_NoMemory();
        return NULL;
    }
    workctx = work_context(context);
    if not workctx {
        mpd_del(x);
        return NULL;
    }
    workctx.view(1)[0].round = round;
    status: u32 = 0;
    mpd_qround_to_int(x, mpd(dec), workctx, &mut status);
    free_work_context(workctx);
    if dec_addstatus(context, status) {
        mpd_del(x);
        return NULL;
    }
    status = 0;
    val = mpd_qget_i64(x, &mut status);
    if status == u32(0) {
        mpd_del(x);
        return PyLong_FromInt64(val);
    }
    layout = PyLong_GetNativeLayout().view(1);
    base = u32(1) << u32(layout[0].bits_per_digit);
    digit_size = int(layout[0].digit_size);
    # A temporary buffer for the digits: libmpdec requires space it
    # allocated, or rlen exact, to export into (gh-127925).
    status = 0;
    n: u64 = 0;
    tmp_digits = ptr();
    if digit_size == 4 {
        digits32 = ptr[u32]();
        n = mpd_qexport_u32(&mut digits32, 0, base, x, &mut status);
        tmp_digits = ptr(digits32);
    } else {
        digits16 = ptr[u16]();
        n = mpd_qexport_u16(&mut digits16, 0, base, x, &mut status);
        tmp_digits = ptr(digits16);
    }
    if n == SIZE_MAX {
        PyErr_NoMemory();
        mpd_del(x);
        mpd_free_memory(tmp_digits);
        return NULL;
    }
    digits = ptr();
    writer = PyLongWriter_Create(mpd_isnegative(x), i64(n), &mut digits);
    mpd_del(x);
    if not writer {
        mpd_free_memory(tmp_digits);
        return NULL;
    }
    jacpy_memory_copy(digits, tmp_digits, i64(digit_size) * i64(n));
    mpd_free_memory(tmp_digits);
    return PyLongWriter_Finish(writer);
}

# int's number slots (PyLong_Type.tp_as_number), as the C module calls them.
def long_power(a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject] {
    return addressof(PyLong_Type).view(1)[0].tp_as_number.view(1)[0].nb_power(a, b, c);
}

def long_multiply(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return addressof(PyLong_Type).view(1)[0].tp_as_number.view(1)[0].nb_multiply(a, b);
}

def long_floor_divide(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return addressof(PyLong_Type).view(1)[0].tp_as_number.view(1)[0].nb_floor_divide(
        a, b
    );
}

"""as_integer_ratio(): the exact (numerator, denominator) in lowest terms."""
def dec_as_integer_ratio(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if mpd_isspecial(mpd(self)) != 0 {
        if mpd_isnan(mpd(self)) != 0 {
            PyErr_SetString(PyExc_ValueError, "cannot convert NaN to integer ratio");
        } else {
            PyErr_SetString(
                PyExc_OverflowError, "cannot convert Infinity to integer ratio"
            );
        }
        return NULL;
    }
    module = module_of(self);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    tmp = dec_alloc(module);
    if not tmp {
        return NULL;
    }
    status: u32 = 0;
    if mpd_qcopy(mpd(tmp), mpd(self), &mut status) == 0 {
        jacpy_release(tmp);
        PyErr_NoMemory();
        return NULL;
    }
    exp = 0 if mpd_iszero(mpd(tmp)) != 0 else mpd(tmp).view(1)[0].exp;
    mpd(tmp).view(1)[0].exp = 0;
    # context and rounding are unused here: the conversion is exact
    numerator = dec_as_long(tmp, context, MPD_ROUND_FLOOR);
    jacpy_release(tmp);
    if not numerator {
        return NULL;
    }
    exponent = PyLong_FromSsize_t(-exp if exp < 0 else exp);
    if not exponent {
        jacpy_release(numerator);
        return NULL;
    }
    ten = PyLong_FromLong(10);
    if not ten {
        jacpy_release(exponent);
        jacpy_release(numerator);
        return NULL;
    }
    power = long_power(ten, exponent, Py_None);
    jacpy_release(ten);
    jacpy_release(exponent);
    if not power {
        jacpy_release(numerator);
        return NULL;
    }
    denominator: ptr[PyObject] = NULL;
    if exp >= 0 {
        scaled = long_multiply(numerator, power);
        jacpy_release(numerator);
        jacpy_release(power);
        numerator = scaled;
        if not numerator {
            return NULL;
        }
        denominator = PyLong_FromLong(1);
    } else {
        denominator = power;
        gcd = _PyLong_GCD(numerator, denominator);
        if not gcd {
            jacpy_release(numerator);
            jacpy_release(denominator);
            return NULL;
        }
        reduced = long_floor_divide(numerator, gcd);
        jacpy_release(numerator);
        numerator = reduced;
        if not numerator {
            jacpy_release(gcd);
            jacpy_release(denominator);
            return NULL;
        }
        reduced = long_floor_divide(denominator, gcd);
        jacpy_release(gcd);
        jacpy_release(denominator);
        denominator = reduced;
    }
    if not denominator {
        jacpy_release(numerator);
        return NULL;
    }
    result = PyTuple_Pack(2, numerator, denominator);
    jacpy_release(denominator);
    jacpy_release(numerator);
    return result;
}

"""to_integral_value(rounding=None, context=None) and to_integral_exact."""
def dec_to_integral(
    dec: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], exact: bool
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|OO", ["rounding", "context"]);
    if values is None {
        return NULL;
    }
    module = module_of(dec);
    context = context_or_current(module, given_or(values[1], Py_None));
    if not context {
        return NULL;
    }
    workctx = work_context(context);
    if not workctx {
        return NULL;
    }
    rounding = given_or(values[0], Py_None);
    if rounding != Py_None {
        round = getround(module, rounding);
        if round < 0 {
            free_work_context(workctx);
            return NULL;
        }
        if mpd_qsetround(workctx, round) == 0 {
            free_work_context(workctx);
            return internal_error_ptr(
                "PyDec_ToIntegralExact" if exact else "PyDec_ToIntegralValue"
            );
        }
    }
    result = dec_alloc(module);
    if not result {
        free_work_context(workctx);
        return NULL;
    }
    status: u32 = 0;
    if exact {
        mpd_qround_to_intx(mpd(result), mpd(dec), workctx, &mut status);
    } else {
        mpd_qround_to_int(mpd(result), mpd(dec), workctx, &mut status);
    }
    free_work_context(workctx);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def dec_to_integral_value(
    dec: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_to_integral(dec, args, kwds, False);
}

def dec_to_integral_exact(
    dec: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_to_integral(dec, args, kwds, True);
}

"""float(): through the decimal string, so the result is correctly rounded."""
def dec_as_float(dec: ptr[PyObject]) -> ptr[PyObject] {
    s: ptr[PyObject] = NULL;
    if mpd_isnan(mpd(dec)) != 0 {
        if mpd_issnan(mpd(dec)) != 0 {
            PyErr_SetString(PyExc_ValueError, "cannot convert signaling NaN to float");
            return NULL;
        }
        s = PyUnicode_FromString("-nan" if mpd_isnegative(mpd(dec)) != 0 else "nan");
    } else {
        s = dec_str(dec);
    }
    if not s {
        return NULL;
    }
    f = PyFloat_FromString(s);
    jacpy_release(s);
    return f;
}

"""__round__(n=None): an int rounded half-even, or a Decimal quantized to n
places."""
def dec_round(dec: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(dec);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    values = parse_tuple(args, "|O");
    if values is None {
        return NULL;
    }
    if not values[0].given {
        return dec_as_long(dec, context, MPD_ROUND_HALF_EVEN);
    }
    x = values[0].object;
    if jacpy_is_long(x) == 0 {
        PyErr_SetString(PyExc_TypeError, "optional arg must be an integer");
        return NULL;
    }
    y = PyLong_AsSsize_t(x);
    if y == -1 and PyErr_Occurred() {
        return NULL;
    }
    result = dec_alloc(module);
    if not result {
        return NULL;
    }
    q = mpd_qnew();
    if not q {
        jacpy_release(result);
        PyErr_NoMemory();
        return NULL;
    }
    status: u32 = 0;
    mpd_qset_uint(q, 1, addressof(max_context), &mut status);
    q.view(1)[0].exp = MPD_SSIZE_MAX if y == MPD_SSIZE_MIN else -y;
    status = 0;
    mpd_qquantize(mpd(result), mpd(dec), q, ctx_of(context), &mut status);
    mpd_del(q);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""as_tuple(): the DecimalTuple (sign, digits, exponent)."""
def dec_as_tuple(dec: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    x = mpd_qncopy(mpd(dec));
    if not x {
        PyErr_NoMemory();
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    sign = PyLong_FromUnsignedLong(u64(mpd_sign(mpd(dec))));
    coeff: ptr[PyObject] = NULL;
    expt: ptr[PyObject] = NULL;
    if sign {
        if mpd_isinfinite(x) != 0 {
            expt = PyUnicode_FromString("F");
            # decimal.py has non-compliant infinity payloads.
            if expt {
                coeff = Py_BuildValue("(i)", i32(0));
            }
        } else {
            if mpd_isnan(x) != 0 {
                expt = PyUnicode_FromString("n" if mpd_isqnan(x) != 0 else "N");
            } else {
                expt = PyLong_FromSsize_t(mpd(dec).view(1)[0].exp);
            }
            if expt {
                coeff = coefficient_digits(x);
            }
        }
    }
    if coeff {
        call_args = PyTuple_Pack(3, sign, coeff, expt);
        if call_args {
            result = PyObject_Call(
                state_value(module_of(dec), STATE_DECIMAL_TUPLE), call_args, NULL
            );
            jacpy_release(call_args);
        }
    }
    mpd_del(x);
    jacpy_release(sign);
    jacpy_release(coeff);
    jacpy_release(expt);
    return result;
}

"""The coefficient digits of a finite or NaN value as a tuple of ints."""
def:priv coefficient_digits(x: ptr[mpd_t]) -> ptr[PyObject] {
    if x.view(1)[0].len <= 0 {
        return PyTuple_New(0);
    }
    # make an integer, and clear NaN and sign
    x.view(1)[0].exp = 0;
    mpd_clear_flags(x);
    intstring = mpd_to_sci(x, 1);
    if not intstring {
        PyErr_NoMemory();
        return NULL;
    }
    intlen = c_string_length(intstring);
    coeff = PyTuple_New(i64(intlen));
    if coeff {
        for i in range(intlen) {
            digit = PyLong_FromLong(int((intstring + i).view(1)[0]) - 48);
            if not digit {
                jacpy_release(coeff);
                coeff = NULL;
                break;
            }
            PyTuple_SetItem(coeff, i64(i), digit);
        }
    }
    mpd_free_memory(ptr(intstring));
    return coeff;
}

# ---------------------------------------------------------------------------
# Number methods, in the current context.

"""Dec_UnaryNumberMethod."""
def nm_unary(self: ptr[PyObject], op: int) -> ptr[PyObject] {
    module = module_of(self);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    result = dec_alloc(module);
    if not result {
        return NULL;
    }
    status = unary_op(op, mpd(result), mpd(self), ctx_of(context));
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""Dec_BinaryNumberMethod: NotImplemented for operands that do not
convert."""
def nm_binary(self: ptr[PyObject], other: ptr[PyObject], op: int) -> ptr[PyObject] {
    module = module_of_left_or_right(self, other);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    a = convert_op(False, self, context);
    if failed_operand(a) {
        return a;
    }
    b = convert_op(False, other, context);
    if failed_operand(b) {
        jacpy_release(a);
        return b;
    }
    result = dec_alloc(module);
    if not result {
        jacpy_release(a);
        jacpy_release(b);
        return NULL;
    }
    status = binary_op(op, mpd(result), mpd(a), mpd(b), ctx_of(context));
    jacpy_release(a);
    jacpy_release(b);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def nm_mpd_qminus(self: ptr[PyObject]) -> ptr[PyObject] {
    return nm_unary(self, OP_MINUS);
}

def nm_mpd_qplus(self: ptr[PyObject]) -> ptr[PyObject] {
    return nm_unary(self, OP_PLUS);
}

def nm_mpd_qabs(self: ptr[PyObject]) -> ptr[PyObject] {
    return nm_unary(self, OP_ABS);
}

def nm_mpd_qadd(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_ADD);
}

def nm_mpd_qsub(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_SUB);
}

def nm_mpd_qmul(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_MUL);
}

def nm_mpd_qdiv(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_DIV);
}

def nm_mpd_qrem(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_REM);
}

def nm_mpd_qdivint(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    return nm_binary(self, other, OP_DIVINT);
}

def nm_dec_as_long(dec: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(dec));
    if not context {
        return NULL;
    }
    return dec_as_long(dec, context, MPD_ROUND_DOWN);
}

def nm_nonzero(v: ptr[PyObject]) -> i32 {
    return i32(0 if mpd_iszero(mpd(v)) != 0 else 1);
}

def nm_mpd_qdivmod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_left_or_right(v, w);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    a = convert_op(False, v, context);
    if failed_operand(a) {
        return a;
    }
    b = convert_op(False, w, context);
    if failed_operand(b) {
        jacpy_release(a);
        return b;
    }
    return divmod_operands(module, a, b, context);
}

"""divmod of two converted operands, whose references it releases."""
def divmod_operands(
    module: ptr[PyObject], a: ptr[PyObject], b: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    q = dec_alloc(module);
    if not q {
        jacpy_release(a);
        jacpy_release(b);
        return NULL;
    }
    r = dec_alloc(module);
    if not r {
        jacpy_release(a);
        jacpy_release(b);
        jacpy_release(q);
        return NULL;
    }
    status: u32 = 0;
    mpd_qdivmod(mpd(q), mpd(r), mpd(a), mpd(b), ctx_of(context), &mut status);
    jacpy_release(a);
    jacpy_release(b);
    if dec_addstatus(context, status) {
        jacpy_release(r);
        jacpy_release(q);
        return NULL;
    }
    ret = PyTuple_Pack(2, q, r);
    jacpy_release(r);
    jacpy_release(q);
    return ret;
}

def nm_mpd_qpow(
    base: ptr[PyObject], exp: ptr[PyObject], mod: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_ternary(base, exp, mod);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    a = convert_op(False, base, context);
    if failed_operand(a) {
        return a;
    }
    b = convert_op(False, exp, context);
    if failed_operand(b) {
        jacpy_release(a);
        return b;
    }
    c: ptr[PyObject] = NULL;
    if mod != Py_None {
        c = convert_op(False, mod, context);
        if failed_operand(c) {
            jacpy_release(a);
            jacpy_release(b);
            return c;
        }
    }
    return power_operands(module, a, b, c, context);
}

"""a ** b, or pow(a, b, c) when c is given; releases the operands."""
def power_operands(
    module: ptr[PyObject],
    a: ptr[PyObject],
    b: ptr[PyObject],
    c: ptr[PyObject],
    context: ptr[PyObject]
) -> ptr[PyObject] {
    result = dec_alloc(module);
    if not result {
        jacpy_release(a);
        jacpy_release(b);
        jacpy_release(c);
        return NULL;
    }
    status: u32 = 0;
    if not c {
        mpd_qpow(mpd(result), mpd(a), mpd(b), ctx_of(context), &mut status);
    } else {
        mpd_qpowmod(mpd(result), mpd(a), mpd(b), mpd(c), ctx_of(context), &mut status);
        jacpy_release(c);
    }
    jacpy_release(a);
    jacpy_release(b);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

# ---------------------------------------------------------------------------
# Methods with an optional context argument.

"""The context argument of a method, or the current context (borrowed);
NULL with an error set."""
def method_context(self: ptr[PyObject], value: ArgumentValue) -> ptr[PyObject] {
    return context_or_current(module_of(self), given_or(value, Py_None));
}

"""Dec_UnaryFuncVA."""
def dec_unary_va(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], op: int
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|O", ["context"]);
    if values is None {
        return NULL;
    }
    context = method_context(self, values[0]);
    if not context {
        return NULL;
    }
    result = dec_alloc(module_of(self));
    if not result {
        return NULL;
    }
    status = unary_op(op, mpd(result), mpd(self), ctx_of(context));
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""The (other, context) arguments of a binary method, converted: `a` and `b`
new references, or `context` NULL on failure."""
obj BinaryOperands {
    has a: ptr[PyObject] = NULL,
        b: ptr[PyObject] = NULL,
        context: ptr[PyObject] = NULL;
}

def binary_operands(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> BinaryOperands {
    operands = BinaryOperands();
    values = parse_keywords(args, kwds, "O|O", ["other", "context"]);
    if values is None {
        return operands;
    }
    context = method_context(self, values[1]);
    if not context {
        return operands;
    }
    a = convert_op(True, self, context);
    if not a {
        return operands;
    }
    b = convert_op(True, values[0].object, context);
    if not b {
        jacpy_release(a);
        return operands;
    }
    operands.a = a;
    operands.b = b;
    operands.context = context;
    return operands;
}

"""Dec_BinaryFuncVA."""
def dec_binary_va(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], op: int
) -> ptr[PyObject] {
    operands = binary_operands(self, args, kwds);
    if not operands.context {
        return NULL;
    }
    result = dec_alloc(module_of(self));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    status = binary_op(
        op, mpd(result), mpd(operands.a), mpd(operands.b), ctx_of(operands.context)
    );
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    if dec_addstatus(operands.context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""Dec_BinaryFuncVA_NO_CTX: the context only records conversion errors."""
def dec_total_va(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], op: int
) -> ptr[PyObject] {
    operands = binary_operands(self, args, kwds);
    if not operands.context {
        return NULL;
    }
    result = dec_alloc(module_of(self));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    total_op(op, mpd(result), mpd(operands.a), mpd(operands.b));
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    return result;
}

"""Dec_BoolFuncVA."""
def dec_bool_va(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], op: int
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|O", ["context"]);
    if values is None {
        return NULL;
    }
    context = method_context(self, values[0]);
    if not context {
        return NULL;
    }
    return bool_object(bool_op(op, mpd(self), ctx_of(context)));
}

"""Dec_BoolFunc: predicates without a context."""
def dec_bool(self: ptr[PyObject], op: int) -> ptr[PyObject] {
    return bool_object(bool_op(op, mpd(self), ptr[mpd_context_t]()));
}

"""fma(other, third, context=None)."""
def dec_mpd_qfma(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "OO|O", ["other", "third", "context"]);
    if values is None {
        return NULL;
    }
    context = method_context(self, values[2]);
    if not context {
        return NULL;
    }
    a = convert_op(True, self, context);
    if not a {
        return NULL;
    }
    b = convert_op(True, values[0].object, context);
    if not b {
        jacpy_release(a);
        return NULL;
    }
    c = convert_op(True, values[1].object, context);
    if not c {
        jacpy_release(a);
        jacpy_release(b);
        return NULL;
    }
    result = dec_alloc(module_of(self));
    if not result {
        jacpy_release(a);
        jacpy_release(b);
        jacpy_release(c);
        return NULL;
    }
    status = fma_op(mpd(result), mpd(a), mpd(b), mpd(c), ctx_of(context));
    jacpy_release(a);
    jacpy_release(b);
    jacpy_release(c);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""adjusted(): the adjusted exponent, 0 for special values."""
def dec_mpd_adjexp(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    retval: i64 = 0;
    if mpd_isspecial(mpd(self)) == 0 {
        retval = mpd_adjexp(mpd(self));
    }
    return PyLong_FromSsize_t(retval);
}

def dec_canonical(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def dec_conjugate(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

"""Decimal(10)."""
def dec_mpd_radix_of(module: ptr[PyObject]) -> ptr[PyObject] {
    result = dec_alloc(module);
    if not result {
        return NULL;
    }
    dec_settriple(result, MPD_POS, 10, 0);
    return result;
}

def dec_mpd_radix(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_mpd_radix_of(module_of(self));
}

def dec_mpd_qcopy_abs(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    result = dec_alloc(module_of(self));
    if not result {
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy_abs(mpd(result), mpd(self), &mut status);
    if (status & MPD_Malloc_error) != u32(0) {
        jacpy_release(result);
        PyErr_NoMemory();
        return NULL;
    }
    return result;
}

def dec_mpd_qcopy_negate(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    result = dec_alloc(module_of(self));
    if not result {
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy_negate(mpd(result), mpd(self), &mut status);
    if (status & MPD_Malloc_error) != u32(0) {
        jacpy_release(result);
        PyErr_NoMemory();
        return NULL;
    }
    return result;
}

"""number_class(context=None)."""
def dec_mpd_class(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|O", ["context"]);
    if values is None {
        return NULL;
    }
    context = method_context(self, values[0]);
    if not context {
        return NULL;
    }
    return c_string_text(mpd_class(mpd(self), ctx_of(context)));
}

"""to_eng_string(context=None)."""
def dec_mpd_to_eng(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "|O", ["context"]);
    if values is None {
        return NULL;
    }
    context = method_context(self, values[0]);
    if not context {
        return NULL;
    }
    s = ptr[u8]();
    size = mpd_to_eng_size(&mut s, mpd(self), ctx_caps(context));
    if size < 0 {
        PyErr_NoMemory();
        return NULL;
    }
    result = unicode_fromascii(s, size);
    mpd_free_memory(ptr(s));
    return result;
}

"""copy_sign(other, context=None)."""
def dec_mpd_qcopy_sign(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    operands = binary_operands(self, args, kwds);
    if not operands.context {
        return NULL;
    }
    result = dec_alloc(module_of(self));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy_sign(mpd(result), mpd(operands.a), mpd(operands.b), &mut status);
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    if dec_addstatus(operands.context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""same_quantum(other, context=None)."""
def dec_mpd_same_quantum(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    operands = binary_operands(self, args, kwds);
    if not operands.context {
        return NULL;
    }
    result = bool_object(mpd_same_quantum(mpd(operands.a), mpd(operands.b)) != 0);
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    return result;
}

"""quantize(exp, rounding=None, context=None)."""
def dec_mpd_qquantize(
    v: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "O|OO", ["exp", "rounding", "context"]);
    if values is None {
        return NULL;
    }
    module = module_of(v);
    context = context_or_current(module, given_or(values[2], Py_None));
    if not context {
        return NULL;
    }
    workctx = work_context(context);
    if not workctx {
        return NULL;
    }
    rounding = given_or(values[1], Py_None);
    if rounding != Py_None {
        round = getround(module, rounding);
        if round < 0 {
            free_work_context(workctx);
            return NULL;
        }
        if mpd_qsetround(workctx, round) == 0 {
            free_work_context(workctx);
            return internal_error_ptr("dec_mpd_qquantize");
        }
    }
    a = convert_op(True, v, context);
    if not a {
        free_work_context(workctx);
        return NULL;
    }
    b = convert_op(True, values[0].object, context);
    if not b {
        jacpy_release(a);
        free_work_context(workctx);
        return NULL;
    }
    result = dec_alloc(module);
    if not result {
        jacpy_release(a);
        jacpy_release(b);
        free_work_context(workctx);
        return NULL;
    }
    status: u32 = 0;
    mpd_qquantize(mpd(result), mpd(a), mpd(b), workctx, &mut status);
    free_work_context(workctx);
    jacpy_release(a);
    jacpy_release(b);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

# ---------------------------------------------------------------------------
# Special methods.

def dec_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    module = module_of_left_or_right(v, w);
    context = current_context_borrowed(module);
    if not context {
        return NULL;
    }
    operands = convert_op_cmp(v, w, int(op), context);
    if not operands.ok {
        return operands.w;
    }
    a = operands.v;
    b = operands.w;
    a_issnan = mpd_issnan(mpd(a)) != 0;
    b_issnan = mpd_issnan(mpd(b)) != 0;
    status: u32 = 0;
    r = int(mpd_qcmp(mpd(a), mpd(b), &mut status));
    jacpy_release(a);
    jacpy_release(b);
    if r == INT_MAX {
        # sNaNs or op={le,ge,lt,gt} always signal.
        if a_issnan or b_issnan or (int(op) != Py_EQ_OP and int(op) != Py_NE_OP) {
            if dec_addstatus(context, status) {
                return NULL;
            }
        }
        # qNaN comparison with op={eq,ne} or comparison with
        # InvalidOperation disabled.
        return bool_object(int(op) == Py_NE_OP);
    }
    result = False;
    if int(op) == Py_EQ_OP {
        result = r == 0;
    } elif int(op) == Py_NE_OP {
        result = r != 0;
    } elif int(op) == Py_LE_OP {
        result = r <= 0;
    } elif int(op) == Py_GE_OP {
        result = r >= 0;
    } elif int(op) == Py_LT_OP {
        result = r == -1;
    } elif int(op) == Py_GT_OP {
        result = r == 1;
    }
    return PyBool_FromLong(1 if result else 0);
}

def dec_ceil(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(self));
    if not context {
        return NULL;
    }
    return dec_as_long(self, context, MPD_ROUND_CEILING);
}

def dec_complex(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    f = dec_as_float(self);
    if not f {
        return NULL;
    }
    x = PyFloat_AsDouble(f);
    jacpy_release(f);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    return PyComplex_FromDoubles(x, 0.0);
}

"""__copy__ (METH_NOARGS) and __deepcopy__ (METH_O)."""
def dec_copy(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def dec_floor(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(self));
    if not context {
        return NULL;
    }
    return dec_as_long(self, context, MPD_ROUND_FLOOR);
}

"""The hash, which agrees with int, float and Fraction for equal values:
(coefficient * 10**exponent) mod 2**61 - 1."""
def dec_hash_value(v: ptr[PyObject]) -> i64 {
    if mpd_isspecial(mpd(v)) != 0 {
        if mpd_issnan(mpd(v)) != 0 {
            PyErr_SetString(PyExc_TypeError, "Cannot hash a signaling NaN value");
            return -1;
        } elif mpd_isnan(mpd(v)) != 0 {
            return PyObject_GenericHash(v);
        }
        return i64(PY_HASH_INF) * i64(mpd_arith_sign(mpd(v)));
    }
    exp_hash = mpd_qnew();
    tmp = mpd_qnew();
    if not exp_hash or not tmp {
        if exp_hash {
            mpd_del(exp_hash);
        }
        if tmp {
            mpd_del(tmp);
        }
        PyErr_NoMemory();
        return -1;
    }
    status: u32 = 0;
    exp = mpd(v).view(1)[0].exp;
    if exp >= 0 {
        # 10**exp(v) % p
        mpd_qsset_ssize(tmp, exp, addressof(max_context), &mut status);
        mpd_qpowmod(
            exp_hash,
            addressof(hash_ten),
            tmp,
            addressof(hash_p),
            addressof(max_context),
            &mut status
        );
    } else {
        # inv10_p**(-exp(v)) % p
        mpd_qsset_ssize(tmp, -exp, addressof(max_context), &mut status);
        mpd_qpowmod(
            exp_hash,
            addressof(hash_inv10_p),
            tmp,
            addressof(hash_p),
            addressof(max_context),
            &mut status
        );
    }
    # hash = (int(v) * exp_hash) % p
    if mpd_qcopy(tmp, mpd(v), &mut status) == 0 {
        mpd_del(exp_hash);
        mpd_del(tmp);
        PyErr_NoMemory();
        return -1;
    }
    tmp.view(1)[0].exp = 0;
    mpd_set_positive(tmp);
    mpd_qmul(tmp, tmp, exp_hash, addressof(hash_context), &mut status);
    mpd_qrem(tmp, tmp, addressof(hash_p), addressof(hash_context), &mut status);
    result = mpd_qget_ssize(tmp, &mut status);
    result = result if mpd_ispositive(mpd(v)) != 0 else -result;
    result = -2 if result == -1 else result;
    mpd_del(exp_hash);
    mpd_del(tmp);
    if status != u32(0) {
        if (status & MPD_Malloc_error) != u32(0) {
            PyErr_NoMemory();
        } else {
            PyErr_SetString(
                PyExc_RuntimeError, "dec_hash: internal error: please report"
            );
        }
        return -1;
    }
    return result;
}

def dec_hash(op: ptr[PyObject]) -> i64 {
    record = ptr[PyDecObject](op).view(1);
    if record[0].hash == -1 {
        record[0].hash = dec_hash_value(op);
    }
    return record[0].hash;
}

"""__reduce__: (type(self), (str(self),))."""
def dec_reduce(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    text = dec_str(self);
    if not text {
        return NULL;
    }
    result = Py_BuildValue("O(O)", ptr[PyObject](object_type(self)), text);
    jacpy_release(text);
    return result;
}

"""__sizeof__: the object and a dynamically allocated coefficient."""
def dec_sizeof(v: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    res = u64(object_type(v).view(1)[0].tp_basicsize);
    if mpd_isdynamic_data(mpd(v)) != 0 {
        res += u64(mpd(v).view(1)[0].alloc) * u64(MPD_UINT_SIZE);
    }
    return PyLong_FromSize_t(res);
}

def dec_trunc(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context_borrowed(module_of(self));
    if not context {
        return NULL;
    }
    return dec_as_long(self, context, MPD_ROUND_DOWN);
}

def dec_real(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(self);
}

def dec_imag(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    result = dec_alloc(module_of(self));
    if not result {
        return NULL;
    }
    dec_settriple(result, MPD_POS, 0, 0);
    return result;
}
